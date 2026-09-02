//
//  MeetingRecorder.swift
//  cattura riunione
//
//  Orchestra la registrazione di una riunione. Le due sorgenti sono
//  indipendenti: microfono (AudioRecorder), uscite del Mac
//  (SystemAudioTap), o entrambe. Allo stop si scrive riunione.m4a (il
//  mix per riascolto ed esportazione) e, quando le tracce sono due,
//  anche microfono.m4a e sistema.m4a per la diarizzazione separata.
//

import Foundation
import Observation

@MainActor
@Observable
final class MeetingRecorder {

    let microfono = AudioRecorder()
    private let sistema = SystemAudioTap()

    /// Preferenze dell'utente: quali sorgenti registrare.
    var registraMicrofono: Bool = UserDefaults.standard.object(forKey: "registraMicrofono") as? Bool ?? true {
        didSet { UserDefaults.standard.set(registraMicrofono, forKey: "registraMicrofono") }
    }
    var catturaSistema: Bool = UserDefaults.standard.object(forKey: "catturaSistema") as? Bool ?? true {
        didSet { UserDefaults.standard.set(catturaSistema, forKey: "catturaSistema") }
    }

    /// Avviso non bloccante (es. permesso di sistema negato).
    private(set) var avvisoSistema: String?
    private(set) var staMiscelando = false
    private(set) var inRegistrazione = false
    private(set) var elapsed: TimeInterval = 0

    private var urlSistema: URL?
    private var avvio: Date?
    private var orologio: Task<Void, Never>?

    var isRecording: Bool { inRegistrazione }

    func avvia() async {
        guard !inRegistrazione else { return }
        avvisoSistema = nil
        urlSistema = nil
        microfono.errorMessage = nil

        guard registraMicrofono || catturaSistema else {
            microfono.errorMessage = "Attiva almeno una sorgente da registrare."
            return
        }

        if registraMicrofono {
            guard await microfono.startRecording() else { return }
        }

        if catturaSistema {
            do {
                urlSistema = try sistema.avvia()
            } catch {
                if registraMicrofono {
                    // Col microfono attivo si prosegue comunque: la
                    // riunione non va persa per un permesso negato.
                    avvisoSistema = "Audio di sistema non catturato: \(error.localizedDescription)"
                } else {
                    microfono.errorMessage =
                        "Impossibile catturare l'audio di sistema: \(error.localizedDescription)"
                    return
                }
            }
        }

        inRegistrazione = true
        avvio = Date()
        elapsed = 0
        orologio = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, let avvio = self.avvio else { break }
                self.elapsed = Date().timeIntervalSince(avvio)
            }
        }
    }

    /// Ferma tutto, miscela e scrive i file audio in una nuova cartella
    /// dentro `cartellaBase`. Restituisce la cartella della riunione.
    func ferma(in cartellaBase: URL) async -> URL? {
        guard inRegistrazione else { return nil }
        inRegistrazione = false
        orologio?.cancel()
        orologio = nil
        avvio = nil

        sistema.ferma()
        let urlMicrofono = microfono.isRecording ? microfono.stopRecording() : nil
        let urlSistema = self.urlSistema
        self.urlSistema = nil
        guard urlMicrofono != nil || urlSistema != nil else { return nil }

        staMiscelando = true
        defer { staMiscelando = false }

        do {
            let cartella = try MeetingStore.creaCartella(in: cartellaBase, data: Date())
            try await Task.detached(priority: .userInitiated) {
                // La traccia registrata si carica per forza (fallire qui è
                // un errore vero); quella di sistema, quando c'è anche il
                // microfono, può mancare senza far perdere la riunione.
                var campioniMic: [Float]?
                if let urlMicrofono {
                    campioniMic = try AudioCampioni.carica(urlMicrofono, frequenza: 48000)
                }
                var campioniSistema: [Float]?
                if let urlSistema {
                    if campioniMic == nil {
                        campioniSistema = try AudioCampioni.carica(urlSistema, frequenza: 48000)
                    } else {
                        campioniSistema = try? AudioCampioni.carica(urlSistema, frequenza: 48000)
                    }
                }

                let mix: [Float]
                switch (campioniMic, campioniSistema) {
                case let (mic?, sistema?): mix = AudioCampioni.miscela(mic, sistema)
                case let (mic?, nil): mix = mic
                case let (nil, sistema?): mix = sistema
                case (nil, nil): throw AudioCampioni.Errore.conversioneFallita
                }
                try AudioCampioni.scriviM4A(
                    AudioCampioni.normalizza(mix), frequenza: 48000,
                    in: cartella.appendingPathComponent(MeetingStore.nomeAudio)
                )

                // Con due tracce vere si salvano anche i singoli, ciascuno
                // normalizzato: alimentano la diarizzazione separata.
                if let mic = campioniMic, let sistema = campioniSistema {
                    try AudioCampioni.scriviM4A(
                        AudioCampioni.normalizza(mic), frequenza: 48000,
                        in: cartella.appendingPathComponent(MeetingStore.nomeAudioMicrofono)
                    )
                    try AudioCampioni.scriviM4A(
                        AudioCampioni.normalizza(sistema), frequenza: 48000,
                        in: cartella.appendingPathComponent(MeetingStore.nomeAudioSistema)
                    )
                }
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
