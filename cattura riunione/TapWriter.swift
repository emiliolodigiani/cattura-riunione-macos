//
//  TapWriter.swift
//  cattura riunione
//
//  Riusato da cattura brano: scrittura su file del tap di AVAudioEngine
//  e misura dei picchi per il misuratore di livello.
//

import AVFoundation

nonisolated enum RecorderError: LocalizedError {
    case deviceSelectionFailed(OSStatus)
    case invalidFormat
    case emptyRecording
    case separationFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceSelectionFailed(let status):
            "Impossibile selezionare l'interfaccia audio (codice \(status))."
        case .invalidFormat:
            "L'interfaccia selezionata non fornisce audio (formato non valido). Potrebbe essere in uso esclusivo da un'altra app: chiudi le app che la usano, scollegala e ricollegala, o riavvia il Mac."
        case .emptyRecording:
            "La registrazione non contiene audio da salvare."
        case .separationFailed(let details):
            "Separazione degli stem non riuscita. \(details)"
        }
    }
}

/// Riceve i buffer dal tap del motore audio (thread audio in tempo reale) e li
/// scrive su un file temporaneo. Calcola anche il picco per il misuratore di livello.
///
/// Con `url` a `nil` non scrive nulla e fa solo da misuratore: è la modalità
/// usata per monitorare il livello d'ingresso prima della registrazione.
///
/// È `nonisolated`/`@unchecked Sendable` perché viene invocata dal thread audio,
/// non dal main actor.
nonisolated final class TapWriter: @unchecked Sendable {
    private var file: AVAudioFile?
    private let lock = NSLock()
    private var peaks: [Float]
    /// Ultimo picco valido, restituito quando tra due letture non sono arrivati
    /// buffer nuovi (il tap consegna a cadenza diversa da quella del misuratore).
    private var heldPeaks: [Float]
    private var hasFreshPeaks = false

    init(url: URL?, format: AVAudioFormat) throws {
        peaks = [Float](repeating: 0, count: Int(format.channelCount))
        heldPeaks = peaks
        file = try url.map {
            try AVAudioFile(
                forWriting: $0,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        }
    }

    /// Aggiunge un buffer al file e aggiorna il picco corrente di ogni canale.
    func append(_ buffer: AVAudioPCMBuffer) {
        try? file?.write(from: buffer)

        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channels = min(Int(buffer.format.channelCount), peaks.count)
        var localPeaks = [Float](repeating: 0, count: channels)
        // Sotto-campioniamo (passo 8) per non gravare sul thread audio.
        for channel in 0..<channels {
            let samples = channelData[channel]
            var frame = 0
            while frame < frames {
                let value = abs(samples[frame])
                if value > localPeaks[channel] { localPeaks[channel] = value }
                frame += 8
            }
        }

        lock.lock()
        for channel in 0..<channels where localPeaks[channel] > peaks[channel] {
            peaks[channel] = localPeaks[channel]
        }
        hasFreshPeaks = true
        lock.unlock()
    }

    /// Restituisce i picchi per canale accumulati dall'ultima lettura e li azzera.
    /// Se non è arrivato nessun buffer nuovo, ripropone l'ultimo valore valido
    /// invece di uno zero spurio (che farebbe lampeggiare il misuratore).
    func consumePeaks() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        if hasFreshPeaks {
            heldPeaks = peaks
            peaks = [Float](repeating: 0, count: peaks.count)
            hasFreshPeaks = false
        }
        return heldPeaks
    }

    /// Chiude il file, assicurando lo scaricamento su disco.
    func close() {
        file = nil
    }
}
