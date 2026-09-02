//
//  AudioCampioni.swift
//  cattura riunione
//
//  Passaggi audio della post-elaborazione: decodifica qualunque file in
//  campioni mono Float alla frequenza voluta (48 kHz per l'archivio,
//  16 kHz per i modelli), miscela microfono e audio di sistema, scrive
//  l'm4a d'archivio.
//

import Accelerate
import AVFoundation

nonisolated enum AudioCampioni {

    enum Errore: LocalizedError {
        case formatoNonValido
        case conversioneFallita
        var errorDescription: String? {
            switch self {
            case .formatoNonValido: "Formato audio non gestibile."
            case .conversioneFallita: "Conversione audio fallita."
            }
        }
    }

    /// Decodifica `url` (wav, caf, m4a, mp3, aiff…) in campioni mono
    /// Float32 alla frequenza richiesta.
    static func carica(_ url: URL, frequenza: Double) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let destinazione = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: frequenza,
            channels: 1, interleaved: false
        ), let convertitore = AVAudioConverter(from: file.processingFormat, to: destinazione) else {
            throw Errore.formatoNonValido
        }

        var campioni: [Float] = []
        campioni.reserveCapacity(Int(Double(file.length) * frequenza / file.processingFormat.sampleRate) + 4096)
        let blocco = AVAudioFrameCount(8192)
        var finita = false
        // Un solo buffer d'uscita riusato per tutta la conversione: su
        // registrazioni lunghe le allocazioni per blocco pesano.
        guard let uscita = AVAudioPCMBuffer(pcmFormat: destinazione, frameCapacity: blocco) else {
            throw Errore.conversioneFallita
        }

        while true {
            uscita.frameLength = 0
            var erroreConversione: NSError?
            let stato = convertitore.convert(to: uscita, error: &erroreConversione) { richiesti, statoIngresso in
                if finita {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                guard let ingresso = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: richiesti) else {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                do {
                    try file.read(into: ingresso)
                } catch {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                if ingresso.frameLength == 0 {
                    finita = true
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                statoIngresso.pointee = .haveData
                return ingresso
            }
            if let erroreConversione { throw erroreConversione }
            if uscita.frameLength > 0, let dati = uscita.floatChannelData {
                campioni.append(contentsOf: UnsafeBufferPointer(start: dati[0], count: Int(uscita.frameLength)))
            }
            if stato == .endOfStream || (stato == .inputRanDry && finita) { break }
            if uscita.frameLength == 0 { break }
        }
        return campioni
    }

    /// Riporta il picco a −1 dBFS (0.891) amplificando soltanto: un
    /// segnale già pieno resta com'è e sotto la soglia di rumore
    /// (−60 dBFS) non si amplifica il nulla. Le registrazioni parlate
    /// arrivano spesso molto basse (visto −11 dBFS dal microfono
    /// integrato) e all'ascolto risultano flebili.
    static func normalizza(_ campioni: [Float]) -> [Float] {
        let piccoDestinazione: Float = 0.891
        guard !campioni.isEmpty else { return campioni }
        let picco = vDSP.maximumMagnitude(campioni)
        guard picco > 0.001, picco < piccoDestinazione else { return campioni }
        return vDSP.multiply(piccoDestinazione / picco, campioni)
    }

    /// Somma due tracce campione per campione (lunghezze diverse ammesse)
    /// con limitazione morbida del fondo scala.
    static func miscela(_ a: [Float], _ b: [Float]) -> [Float] {
        let (lunga, corta) = a.count >= b.count ? (a, b) : (b, a)
        guard !corta.isEmpty else { return lunga }
        var esito = lunga
        esito.withUnsafeMutableBufferPointer { somma in
            corta.withUnsafeBufferPointer { addendo in
                vDSP_vadd(somma.baseAddress!, 1, addendo.baseAddress!, 1,
                          somma.baseAddress!, 1, vDSP_Length(corta.count))
            }
        }
        vDSP.clip(esito, to: -1...1, result: &esito)
        return esito
    }

    /// Scrive i campioni mono in un m4a (AAC) alla frequenza data.
    static func scriviM4A(_ campioni: [Float], frequenza: Double, in url: URL) throws {
        guard let formato = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: frequenza,
            channels: 1, interleaved: false
        ) else { throw Errore.formatoNonValido }

        let impostazioni: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: frequenza,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96000,
        ]
        let file = try AVAudioFile(forWriting: url, settings: impostazioni,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)

        let blocco = 8192
        var indice = 0
        while indice < campioni.count {
            let quanti = min(blocco, campioni.count - indice)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(quanti)) else {
                throw Errore.conversioneFallita
            }
            buffer.frameLength = AVAudioFrameCount(quanti)
            campioni.withUnsafeBufferPointer { sorgente in
                buffer.floatChannelData![0].update(from: sorgente.baseAddress! + indice, count: quanti)
            }
            try file.write(from: buffer)
            indice += quanti
        }
    }
}
