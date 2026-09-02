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
        didSet {
            UserDefaults.standard.set(catturaSistema, forKey: "catturaSistema")
            guard !inRegistrazione else { return }
            catturaSistema ? avviaMonitoraggioSistema() : fermaMonitoraggioSistema()
        }
    }

    /// Avviso non bloccante (es. permesso di sistema negato).
    private(set) var avvisoSistema: String?
    private(set) var staMiscelando = false
    private(set) var inRegistrazione = false
    private(set) var elapsed: TimeInterval = 0
    /// Picchi (0…1) dell'audio di sistema, anche in solo monitoraggio.
    private(set) var livelliSistema: [Float] = []

    private var urlSistema: URL?
    private var avvio: Date?
    private var orologio: Task<Void, Never>?
    private var misuratoreSistema: Task<Void, Never>?

    var isRecording: Bool { inRegistrazione }

    init() {
        if catturaSistema { avviaMonitoraggioSistema() }
    }

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
                // avvia() rimpiazza l'eventuale tap di monitoraggio.
                urlSistema = try sistema.avvia()
                avviaMisuratoreSistema()
            } catch {
                misuratoreSistema?.cancel()
                misuratoreSistema = nil
                livelliSistema = []
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
        // Il misuratore di sistema riprende (o si spegne) subito.
        catturaSistema ? avviaMonitoraggioSistema() : fermaMonitoraggioSistema()
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

                // Le codifiche AAC sono il grosso dell'attesa dopo lo
                // stop: mix e tracce singole si scrivono in parallelo.
                // Le tracce si salvano solo se entrambe "vere" (con
                // campioni): alimentano la diarizzazione separata.
                let mixNormalizzato = AudioCampioni.normalizza(mix)
                try await withThrowingTaskGroup(of: Void.self) { gruppo in
                    gruppo.addTask {
                        try AudioCampioni.scriviM4A(
                            mixNormalizzato, frequenza: 48000,
                            in: cartella.appendingPathComponent(MeetingStore.nomeAudio)
                        )
                    }
                    if let mic = campioniMic, let sistema = campioniSistema,
                       !mic.isEmpty, !sistema.isEmpty {
                        gruppo.addTask {
                            try AudioCampioni.scriviM4A(
                                AudioCampioni.normalizza(mic), frequenza: 48000,
                                in: cartella.appendingPathComponent(MeetingStore.nomeAudioMicrofono)
                            )
                        }
                        gruppo.addTask {
                            try AudioCampioni.scriviM4A(
                                AudioCampioni.normalizza(sistema), frequenza: 48000,
                                in: cartella.appendingPathComponent(MeetingStore.nomeAudioSistema)
                            )
                        }
                    }
                    try await gruppo.waitForAll()
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

    // MARK: Monitoraggio dell'audio di sistema

    /// Tap senza file, solo per il misuratore. Silenzioso se fallisce
    /// (es. permesso negato): il misuratore resta semplicemente vuoto e
    /// l'errore vero arriva quando si prova a registrare.
    private func avviaMonitoraggioSistema() {
        guard !inRegistrazione else { return }
        try? sistema.avviaMonitoraggio()
        avviaMisuratoreSistema()
    }

    private func fermaMonitoraggioSistema() {
        sistema.ferma()
        misuratoreSistema?.cancel()
        misuratoreSistema = nil
        livelliSistema = []
    }

    /// Travasa i picchi del tap nello stato osservabile, con la stessa
    /// balistica del misuratore del microfono.
    private func avviaMisuratoreSistema() {
        misuratoreSistema?.cancel()
        misuratoreSistema = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else { break }
                let picchi = self.sistema.consumaPicchi()
                if self.livelliSistema.count != picchi.count {
                    self.livelliSistema = picchi
                } else {
                    self.livelliSistema = zip(self.livelliSistema, picchi).map { max($1, $0 * 0.631) }
                }
            }
        }
    }
}
