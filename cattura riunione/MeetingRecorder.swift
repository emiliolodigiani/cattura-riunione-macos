//
//  MeetingRecorder.swift
//  cattura riunione
//
//  Orchestra la registrazione di una riunione: microfono (AudioRecorder)
//  e audio di sistema (SystemAudioTap) partono insieme; allo stop i due
//  file si miscelano in riunione.m4a dentro una nuova cartella riunione.
//

import Foundation
import Observation

@MainActor
@Observable
final class MeetingRecorder {

    let microfono = AudioRecorder()
    private let sistema = SystemAudioTap()

    /// Preferenza dell'utente: catturare anche l'audio delle altre app.
    var catturaSistema: Bool = UserDefaults.standard.object(forKey: "catturaSistema") as? Bool ?? true {
        didSet { UserDefaults.standard.set(catturaSistema, forKey: "catturaSistema") }
    }
    /// Avviso non bloccante (es. permesso di sistema negato).
    private(set) var avvisoSistema: String?
    private(set) var staMiscelando = false

    private var urlSistema: URL?

    var isRecording: Bool { microfono.isRecording }

    func avvia() async {
        avvisoSistema = nil
        urlSistema = nil
        guard await microfono.startRecording() else { return }
        if catturaSistema {
            do {
                urlSistema = try sistema.avvia()
            } catch {
                // Senza permesso o senza supporto si prosegue col solo
                // microfono: la riunione non va persa per questo.
                avvisoSistema = "Audio di sistema non catturato: \(error.localizedDescription)"
            }
        }
    }

    /// Ferma tutto, miscela e scrive riunione.m4a in una nuova cartella
    /// dentro `cartellaBase`. Restituisce la cartella della riunione.
    func ferma(in cartellaBase: URL) async -> URL? {
        sistema.ferma()
        guard let urlMicrofono = microfono.stopRecording() else { return nil }
        let urlSistema = self.urlSistema
        self.urlSistema = nil

        staMiscelando = true
        defer { staMiscelando = false }

        do {
            let cartella = try MeetingStore.creaCartella(in: cartellaBase, data: Date())
            let destinazione = cartella.appendingPathComponent(MeetingStore.nomeAudio)
            try await Task.detached(priority: .userInitiated) {
                var mix = try AudioCampioni.carica(urlMicrofono, frequenza: 48000)
                if let urlSistema,
                   let campioniSistema = try? AudioCampioni.carica(urlSistema, frequenza: 48000) {
                    mix = AudioCampioni.miscela(mix, campioniSistema)
                }
                try AudioCampioni.scriviM4A(mix, frequenza: 48000, in: destinazione)
            }.value
            pulisci(urlMicrofono, urlSistema)
            return cartella
        } catch {
            pulisci(urlMicrofono, urlSistema)
            microfono.errorMessage = "Impossibile salvare la riunione: \(error.localizedDescription)"
            return nil
        }
    }

    private nonisolated func pulisci(_ urls: URL?...) {
        for url in urls.compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
