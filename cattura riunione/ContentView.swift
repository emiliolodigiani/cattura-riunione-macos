//
//  ContentView.swift
//  cattura riunione
//
//  La finestra principale: a sinistra registrazione e importazione,
//  a destra l'elenco delle riunioni; la selezione apre il verbale.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var registratore = MeetingRecorder()
    @State private var modelli = ModelStore()
    @State private var motore: TranscriptionEngine?
    @State private var cartelle = OutputFolderStore()
    @State private var riunioni: [Riunione] = []
    @State private var selezione: URL?
    @State private var cartellaInElaborazione: URL?
    /// Nome del file in conversione durante l'importazione.
    @State private var importazioneInCorso: String?
    /// Cresce a ogni trascrizione salvata: entra nell'identità della
    /// vista del verbale, che così si ricarica anche quando la riunione
    /// appena trascritta era già selezionata.
    @State private var versioneTrascrizione = 0
    /// Cartella della riunione in rinomina in linea (stile Finder).
    @State private var rinominaInLinea: URL?
    @State private var nomeInModifica = ""
    @FocusState private var fuocoRinomina: URL?
    @State private var riunioneInEliminazione: Riunione?

    var body: some View {
        NavigationSplitView {
            barraLaterale
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            if let selezione {
                VerbaleView(cartella: selezione)
                    .id("\(selezione.absoluteString)#\(versioneTrascrizione)")
            } else {
                Text("Seleziona una riunione o avviane una nuova.")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            aggiornaElenco()
            await modelli.prepara()
        }
        .onChange(of: modelli.stato) {
            if motore == nil, modelli.stato == .pronti {
                motore = TranscriptionEngine(modelli: modelli)
            }
        }
    }

    private var barraLaterale: some View {
        VStack(alignment: .leading, spacing: 12) {
            pannelloRegistrazione
            Divider()
            pannelloStato
            List(riunioni, selection: $selezione) { riunione in
                VStack(alignment: .leading) {
                    if rinominaInLinea == riunione.cartella {
                        TextField("Nome", text: $nomeInModifica)
                            .textFieldStyle(.roundedBorder)
                            .focused($fuocoRinomina, equals: riunione.cartella)
                            .onSubmit { confermaRinominaInLinea() }
                            .onExitCommand { annullaRinominaInLinea() }
                    } else {
                        Text(riunione.nome)
                    }
                    if !riunione.haTrascrizione {
                        Text("Da trascrivere").font(.caption).foregroundStyle(.orange)
                    }
                }
                .tag(riunione.cartella)
                // La selezione si gestisce a mano: come nel Finder, il
                // clic su una riga già selezionata avvia la rinomina in
                // linea (un gesto di doppio clic ruberebbe il clic
                // singolo alla lista).
                .contentShape(Rectangle())
                .onTapGesture {
                    if selezione == riunione.cartella, rinominaInLinea == nil {
                        avviaRinomina(riunione)
                    } else if rinominaInLinea != riunione.cartella {
                        selezione = riunione.cartella
                    }
                }
                .contextMenu {
                    Button(riunione.haTrascrizione ? "Trascrivi di nuovo" : "Trascrivi") {
                        Task { await trascrivi(cartella: riunione.cartella) }
                    }
                    .disabled(motore == nil || cartellaInElaborazione != nil)
                    Button("Rinomina") { avviaRinomina(riunione) }
                    Button("Esporta audio…") { esportaAudio(riunione) }
                    Button("Mostra nel Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([riunione.cartella])
                    }
                    Divider()
                    Button("Elimina…", role: .destructive) { riunioneInEliminazione = riunione }
                }
            }
            .onDrop(of: [UTType.audio], isTargeted: nil) { fornitori in
                importa(fornitori)
            }
            // Invio sulla riunione selezionata: rinomina, come nel Finder.
            .onKeyPress(.return) {
                guard rinominaInLinea == nil, let selezione,
                      let riunione = riunioni.first(where: { $0.cartella == selezione })
                else { return .ignored }
                avviaRinomina(riunione)
                return .handled
            }
            // Il clic fuori dal campo conferma la rinomina (perdita di fuoco).
            .onChange(of: fuocoRinomina) {
                if rinominaInLinea != nil, fuocoRinomina != rinominaInLinea {
                    confermaRinominaInLinea()
                }
            }

            HStack {
                Button {
                    importaConPannello()
                } label: {
                    Label("Importa file audio…", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(registratore.isRecording || cartellaInElaborazione != nil
                          || importazioneInCorso != nil)
            }
            .padding(.horizontal, 12)
            Text("Puoi anche trascinare un file audio sull'elenco per trascriverlo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .alert("Eliminare la riunione?", isPresented: eliminazionePresentata) {
            Button("Annulla", role: .cancel) { riunioneInEliminazione = nil }
            Button("Sposta nel Cestino", role: .destructive) { confermaEliminaRiunione() }
        } message: {
            Text("«\(riunioneInEliminazione?.nome ?? "")» finisce nel Cestino con audio e verbale.")
        }
    }

    private var eliminazionePresentata: Binding<Bool> {
        Binding(get: { riunioneInEliminazione != nil },
                set: { if !$0 { riunioneInEliminazione = nil } })
    }

    private var pannelloRegistrazione: some View {
        // Bindable perché `microfono` è un let: il Binding derivato da
        // $registratore non attraversa proprietà non scrivibili.
        @Bindable var microfono = registratore.microfono
        return VStack(alignment: .leading, spacing: 8) {
            Toggle("Registra il microfono", isOn: $registratore.registraMicrofono)
                .disabled(registratore.isRecording)

            Picker("Ingresso", selection: $microfono.selectedDeviceID) {
                ForEach(registratore.microfono.devices) { dispositivo in
                    Text(dispositivo.name).tag(Optional(dispositivo.id))
                }
            }
            .onChange(of: registratore.microfono.selectedDeviceID) {
                registratore.microfono.noteDeviceChanged()
            }
            .disabled(!registratore.registraMicrofono || registratore.isRecording)

            if registratore.registraMicrofono {
                MisuratoreLivello(livelli: registratore.microfono.levels)
            }

            Toggle("Registra le uscite (audio di sistema)", isOn: $registratore.catturaSistema)
                .disabled(registratore.isRecording || !MeetingRecorder.sistemaDisponibile)
            if !MeetingRecorder.sistemaDisponibile {
                Text("Richiede macOS 14.2 o successivo.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if registratore.catturaSistema {
                MisuratoreLivello(livelli: registratore.livelliSistema)
            }

            HStack {
                if registratore.isRecording {
                    Button {
                        Task { await fermaRegistrazione() }
                    } label: {
                        Label("Ferma", systemImage: "stop.circle.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    Text(FormattaTempo.hhmmss(registratore.elapsed))
                        .monospacedDigit()
                } else {
                    Button {
                        Task { await registratore.avvia() }
                    } label: {
                        Label("Registra", systemImage: "record.circle")
                    }
                    .disabled(registratore.staMiscelando
                              || cartellaInElaborazione != nil
                              || importazioneInCorso != nil
                              || (!registratore.registraMicrofono && !registratore.catturaSistema))
                }
            }

            if !registratore.registraMicrofono && !registratore.catturaSistema {
                Text("Attiva almeno una sorgente da registrare.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let avviso = registratore.avvisoSistema {
                Text(avviso).font(.caption).foregroundStyle(.orange)
            }
            if let errore = registratore.microfono.errorMessage {
                Text(errore).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var pannelloStato: some View {
        switch modelli.stato {
        case .daScaricare, .pronti:
            EmptyView()
        case .inScaricamento(let cosa):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Scaricamento: \(cosa)").font(.caption)
            }
            .padding(.horizontal, 12)
        case .errore(let messaggio):
            VStack(alignment: .leading, spacing: 4) {
                Text(messaggio).font(.caption).foregroundStyle(.red)
                Button("Riprova") { Task { await modelli.prepara() } }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
        }
        if registratore.staMiscelando {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Salvataggio della riunione…").font(.caption)
            }
            .padding(.horizontal, 12)
        }
        if let nome = importazioneInCorso {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Importazione di «\(nome)»…").font(.caption)
            }
            .padding(.horizontal, 12)
        }
        // Il caso .errore resta visibile anche a elaborazione conclusa
        // (cartellaInElaborazione ormai azzerata), sennò sparirebbe
        // prima che qualcuno possa leggerlo.
        if let motore, cartellaInElaborazione != nil || motore.fase.èErrore {
            statoElaborazione(motore.fase)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func statoElaborazione(_ fase: TranscriptionEngine.Fase) -> some View {
        switch fase {
        case .inattivo, .completato:
            EmptyView()
        case .decodifica:
            Label("Preparazione dell'audio…", systemImage: "waveform").font(.caption)
        case .diarizzazione(let avanzamento):
            ProgressView(value: avanzamento) {
                Text("Riconoscimento dei parlanti…").font(.caption)
            }
        case .trascrizione(let avanzamento):
            ProgressView(value: avanzamento) { Text("Trascrizione…").font(.caption) }
        case .errore(let messaggio):
            Text(messaggio).font(.caption).foregroundStyle(.red)
        }
    }

    // MARK: Azioni

    private func aggiornaElenco() {
        riunioni = MeetingStore.elenca(in: cartelle.url)
    }

    private func fermaRegistrazione() async {
        guard let cartella = await registratore.ferma(in: cartelle.url) else { return }
        aggiornaElenco()
        await trascrivi(cartella: cartella)
    }

    private func trascrivi(cartella: URL) async {
        guard let motore else { return }
        cartellaInElaborazione = cartella
        defer { cartellaInElaborazione = nil }
        if let trascrizione = await motore.trascrivi(riunione: cartella) {
            try? MeetingStore.salva(trascrizione, in: cartella)
            aggiornaElenco()
            versioneTrascrizione += 1
            selezione = cartella
        }
    }

    private func importa(_ fornitori: [NSItemProvider]) -> Bool {
        guard let fornitore = fornitori.first else { return false }
        _ = fornitore.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                await importaFile(url)
            }
        }
        return true
    }

    private func importaConPannello() {
        let pannello = NSOpenPanel()
        pannello.canChooseFiles = true
        pannello.canChooseDirectories = false
        pannello.allowsMultipleSelection = false
        pannello.allowedContentTypes = [.audio]
        pannello.prompt = "Importa"
        pannello.message = "Scegli un file audio da trascrivere"
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        Task { await importaFile(url) }
    }

    private func importaFile(_ url: URL) async {
        guard importazioneInCorso == nil else { return }
        importazioneInCorso = url.lastPathComponent
        do {
            // La riunione importata prende il nome del file.
            let cartella = try MeetingStore.creaCartella(
                in: cartelle.url, nome: url.deletingPathExtension().lastPathComponent
            )
            let destinazione = cartella.appendingPathComponent(MeetingStore.nomeAudio)
            // L'audio importato si riporta comunque a m4a 48 kHz
            // normalizzato, così la cartella riunione è uniforme.
            try await Task.detached(priority: .userInitiated) {
                let campioni = AudioCampioni.normalizza(
                    try AudioCampioni.carica(url, frequenza: 48000)
                )
                try AudioCampioni.scriviM4A(campioni, frequenza: 48000, in: destinazione)
            }.value
            importazioneInCorso = nil
            aggiornaElenco()
            await trascrivi(cartella: cartella)
        } catch {
            importazioneInCorso = nil
            registratore.microfono.errorMessage =
                "Importazione non riuscita: \(error.localizedDescription)"
        }
    }

    // MARK: Gestione delle riunioni

    private func avviaRinomina(_ riunione: Riunione) {
        nomeInModifica = riunione.nome
        rinominaInLinea = riunione.cartella
        // Il fuoco si assegna al giro successivo, quando il campo esiste.
        Task { fuocoRinomina = riunione.cartella }
    }

    private func confermaRinominaInLinea() {
        guard let cartella = rinominaInLinea else { return }
        rinominaInLinea = nil
        fuocoRinomina = nil
        let nome = nomeInModifica.trimmingCharacters(in: .whitespacesAndNewlines)
        // Campo svuotato = annulla, come il Finder che ripristina il nome.
        guard !nome.isEmpty else { return }
        do {
            let nuova = try MeetingStore.rinomina(cartella: cartella, in: nome)
            if selezione == cartella { selezione = nuova }
            aggiornaElenco()
        } catch {
            registratore.microfono.errorMessage = error.localizedDescription
        }
    }

    private func annullaRinominaInLinea() {
        rinominaInLinea = nil
        fuocoRinomina = nil
    }

    private func confermaEliminaRiunione() {
        guard let riunione = riunioneInEliminazione else { return }
        riunioneInEliminazione = nil
        do {
            try MeetingStore.elimina(cartella: riunione.cartella)
            if selezione == riunione.cartella { selezione = nil }
            aggiornaElenco()
        } catch {
            registratore.microfono.errorMessage =
                "Eliminazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func esportaAudio(_ riunione: Riunione) {
        let pannello = NSSavePanel()
        pannello.allowedContentTypes = [.mpeg4Audio]
        pannello.nameFieldStringValue = "\(riunione.nome).m4a"
        pannello.prompt = "Esporta"
        guard pannello.runModal() == .OK, let destinazione = pannello.url else { return }
        do {
            if FileManager.default.fileExists(atPath: destinazione.path) {
                try FileManager.default.removeItem(at: destinazione)
            }
            try FileManager.default.copyItem(at: riunione.audioURL, to: destinazione)
        } catch {
            registratore.microfono.errorMessage =
                "Esportazione dell'audio non riuscita: \(error.localizedDescription)"
        }
    }
}

/// Barra del livello d'ingresso, un canale per riga.
struct MisuratoreLivello: View {
    let livelli: [Float]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(livelli.indices, id: \.self) { indice in
                GeometryReader { geometria in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(livelli[indice] > 0.9 ? .red : .green)
                            .frame(width: geometria.size.width * CGFloat(livelli[indice]))
                    }
                }
                .frame(height: 6)
            }
        }
        .animation(.linear(duration: 0.05), value: livelli)
    }
}
