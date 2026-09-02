//
//  TranscriptionEngine.swift
//  cattura riunione
//
//  La post-elaborazione che produce il verbale: audio → 16 kHz mono →
//  diarizzazione → consolidamento dei turni → trascrizione ASR di ogni
//  turno ritagliato → Trascrizione.
//

import FluidAudio
import Foundation
import Observation

@MainActor
@Observable
final class TranscriptionEngine {

    enum Fase: Equatable {
        case inattivo
        case decodifica
        /// Avanzamento 0…1 sui blocchi di diarizzazione.
        case diarizzazione(Double)
        /// Avanzamento 0…1 sulla trascrizione dei turni.
        case trascrizione(Double)
        case completato
        case errore(String)
    }

    private(set) var fase: Fase = .inattivo
    private let modelli: ModelStore

    init(modelli: ModelStore) {
        self.modelli = modelli
    }

    /// Trascrive la riunione nella cartella: con le tracce separate
    /// (microfono.m4a + sistema.m4a) diarizza ciascuna per conto suo —
    /// separazione dei parlanti molto più affidabile — altrimenti lavora
    /// sul mix riunione.m4a.
    func trascrivi(riunione cartella: URL) async -> Trascrizione? {
        let urlMic = cartella.appendingPathComponent(MeetingStore.nomeAudioMicrofono)
        let urlSistema = cartella.appendingPathComponent(MeetingStore.nomeAudioSistema)
        if FileManager.default.fileExists(atPath: urlMic.path),
           FileManager.default.fileExists(atPath: urlSistema.path) {
            return await trascrivi(microfono: urlMic, sistema: urlSistema)
        }
        return await trascrivi(audio: cartella.appendingPathComponent(MeetingStore.nomeAudio))
    }

    /// Trascrive un singolo file audio (mix o importato).
    func trascrivi(audio url: URL) async -> Trascrizione? {
        guard let asr = modelli.asr, let diarizzatore = modelli.diarizzatore else {
            fase = .errore("I modelli non sono pronti: scaricali dalle Impostazioni.")
            return nil
        }

        do {
            fase = .decodifica
            let campioni = try await Task.detached(priority: .userInitiated) {
                try AudioCampioni.carica(url, frequenza: 16000)
            }.value
            let durata = Double(campioni.count) / 16000

            fase = .diarizzazione(0)
            let risultato = try await diarizzatore.process(audio: campioni, progressCallback: avanzamentoDiarizzazione())
            let turni = TurniParlato.consolida(risultato.segments.map(TurnoParlato.init))

            let interventi = try await trascriviTurni(turni, con: asr) { _ in campioni }
            return concludi(interventi: interventi, durata: durata)
        } catch {
            fase = .errore("Trascrizione non riuscita: \(error.localizedDescription)")
            return nil
        }
    }

    /// Trascrizione a doppia traccia: diarizzazione separata di microfono
    /// e audio di sistema, poi fusione degli interventi per timestamp.
    private func trascrivi(microfono urlMic: URL, sistema urlSistema: URL) async -> Trascrizione? {
        guard let asr = modelli.asr, let diarizzatore = modelli.diarizzatore else {
            fase = .errore("I modelli non sono pronti: scaricali dalle Impostazioni.")
            return nil
        }

        do {
            fase = .decodifica
            let (campioniMic, campioniSistema) = try await Task.detached(priority: .userInitiated) {
                (try AudioCampioni.carica(urlMic, frequenza: 16000),
                 try AudioCampioni.carica(urlSistema, frequenza: 16000))
            }.value
            // Una traccia vuota (registrazioni vecchie o degeneri) manda
            // in errore i modelli: meglio ripiegare sul mix.
            if campioniMic.isEmpty || campioniSistema.isEmpty {
                let mix = urlMic.deletingLastPathComponent()
                    .appendingPathComponent(MeetingStore.nomeAudio)
                return await trascrivi(audio: mix)
            }
            let durata = Double(max(campioniMic.count, campioniSistema.count)) / 16000

            fase = .diarizzazione(0)
            // Le due tracce si spartiscono la barra: 0…0,5 e 0,5…1.
            let esitoMic = try await diarizzatore.process(
                audio: campioniMic, progressCallback: avanzamentoDiarizzazione(da: 0, a: 0.5)
            )
            let esitoSistema = try await diarizzatore.process(
                audio: campioniSistema, progressCallback: avanzamentoDiarizzazione(da: 0.5, a: 1)
            )
            let turni = TurniParlato.unisci(
                microfono: esitoMic.segments.map(TurnoParlato.init),
                sistema: esitoSistema.segments.map(TurnoParlato.init)
            )

            let interventi = try await trascriviTurni(turni, con: asr) { turno in
                turno.idParlante.hasPrefix(TurniParlato.prefissoMicrofono) ? campioniMic : campioniSistema
            }
            return concludi(interventi: interventi, durata: durata)
        } catch {
            fase = .errore("Trascrizione non riuscita: \(error.localizedDescription)")
            return nil
        }
    }

    /// Callback di progresso della diarizzazione (chiamato fuori dal
    /// main actor), riportato sulla fase entro l'intervallo dato.
    private func avanzamentoDiarizzazione(
        da inizio: Double = 0, a fine: Double = 1
    ) -> @Sendable (Int, Int) -> Void {
        { fatti, totale in
            guard totale > 0 else { return }
            let quota = inizio + (fine - inizio) * Double(fatti) / Double(totale)
            Task { @MainActor [weak self] in
                guard let self, case .diarizzazione = self.fase else { return }
                self.fase = .diarizzazione(min(1, quota))
            }
        }
    }

    /// Trascrive ogni turno ritagliandolo dalla traccia che gli compete.
    private func trascriviTurni(
        _ turni: [TurnoParlato],
        con asr: AsrManager,
        campioni: (TurnoParlato) -> [Float]
    ) async throws -> [Intervento] {
        let stratiDecoder = await asr.decoderLayerCount
        var interventi: [Intervento] = []
        for (indice, turno) in turni.enumerated() {
            fase = .trascrizione(Double(indice) / Double(max(1, turni.count)))
            let sorgente = campioni(turno)
            let da = max(0, Int(turno.inizio * 16000))
            let a = min(sorgente.count, Int(turno.fine * 16000))
            guard a > da else { continue }
            let ritaglio = Array(sorgente[da..<a])
            // Ogni turno è un ritaglio indipendente: stato del decoder nuovo.
            var statoDecoder = TdtDecoderState.make(decoderLayers: stratiDecoder)
            let esito = try await asr.transcribe(ritaglio, decoderState: &statoDecoder)
            let testo = esito.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !testo.isEmpty else { continue }
            interventi.append(Intervento(
                id: UUID(), idParlante: turno.idParlante,
                inizio: turno.inizio, fine: turno.fine, testo: testo
            ))
        }
        return interventi
    }

    private func concludi(interventi: [Intervento], durata: Double) -> Trascrizione {
        let trascrizione = Trascrizione(
            versione: 1,
            durata: durata,
            interventi: interventi,
            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
        )
        fase = .completato
        return trascrizione
    }
}

private extension TurnoParlato {
    /// Ponte dal segmento di FluidAudio al turno interno.
    init(_ segmento: TimedSpeakerSegment) {
        self.init(
            idParlante: segmento.speakerId,
            inizio: Double(segmento.startTimeSeconds),
            fine: Double(segmento.endTimeSeconds)
        )
    }
}
