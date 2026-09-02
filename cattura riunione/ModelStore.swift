//
//  ModelStore.swift
//  cattura riunione
//
//  Stato dei modelli Core ML di FluidAudio: al primo avvio vanno
//  scaricati da Hugging Face (~1 GB), poi restano in locale e l'app
//  funziona offline. I gestori inizializzati vivono qui e vengono
//  riusati per tutte le trascrizioni della sessione.
//

import FluidAudio
import Foundation
import Observation

@MainActor
@Observable
final class ModelStore {

    enum Stato: Equatable {
        case daScaricare
        case inScaricamento(String)
        case pronti
        case errore(String)
    }

    private(set) var stato: Stato = .daScaricare
    private(set) var asr: AsrManager?
    private(set) var diarizzatore: DiarizerManager?

    /// Scarica (se serve) e inizializza i modelli. Riprovabile: in caso
    /// di errore lo stato torna interrogabile e si può richiamare.
    func prepara() async {
        guard stato != .pronti, asr == nil || diarizzatore == nil else { return }
        do {
            stato = .inScaricamento("Modelli di trascrizione…")
            let modelliAsr = try await AsrModels.downloadAndLoad()
            let asr = AsrManager(config: .default)
            try await asr.loadModels(modelliAsr)

            stato = .inScaricamento("Modelli di diarizzazione…")
            let modelliDiar = try await DiarizerModels.downloadIfNeeded()
            let diarizzatore = DiarizerManager()
            diarizzatore.initialize(models: modelliDiar)

            self.asr = asr
            self.diarizzatore = diarizzatore
            stato = .pronti
        } catch {
            stato = .errore(
                "Scaricamento dei modelli non riuscito: \(error.localizedDescription) "
                + "Controlla la connessione e riprova."
            )
        }
    }
}
