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
        case diarizzazione
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

    /// Trascrive il file audio e restituisce il verbale, o nil (con la
    /// fase a .errore) se qualcosa va storto.
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

            fase = .diarizzazione
            let risultato = try await diarizzatore.process(audio: campioni)
            let turni = TurniParlato.consolida(risultato.segments.map {
                TurnoParlato(
                    idParlante: $0.speakerId,
                    inizio: Double($0.startTimeSeconds),
                    fine: Double($0.endTimeSeconds)
                )
            })

            let stratiDecoder = await asr.decoderLayerCount
            var interventi: [Intervento] = []
            for (indice, turno) in turni.enumerated() {
                fase = .trascrizione(Double(indice) / Double(max(1, turni.count)))
                let da = max(0, Int(turno.inizio * 16000))
                let a = min(campioni.count, Int(turno.fine * 16000))
                guard a > da else { continue }
                let ritaglio = Array(campioni[da..<a])
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

            let trascrizione = Trascrizione(
                versione: 1,
                durata: durata,
                interventi: interventi,
                nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
            )
            fase = .completato
            return trascrizione
        } catch {
            fase = .errore("Trascrizione non riuscita: \(error.localizedDescription)")
            return nil
        }
    }
}
