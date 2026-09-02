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
    @State private var riunioneInRinomina: Riunione?
    @State private var nuovoNomeRiunione = ""
    @State private var riunioneInEliminazione: Riunione?

    var body: some View {
        NavigationSplitView {
            barraLaterale
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            if let selezione {
                VerbaleView(cartella: selezione)
                    .id(selezione)
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
                    Text(riunione.nome)
                    if !riunione.haTrascrizione {
                        Text("Da trascrivere").font(.caption).foregroundStyle(.orange)
                    }
                }
                .tag(riunione.cartella)
                // simultaneousGesture: un normale onTapGesture ruberebbe
                // il clic singolo alla selezione della lista.
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    nuovoNomeRiunione = riunione.nome
                    riunioneInRinomina = riunione
                })
                .contextMenu {
                    Button(riunione.haTrascrizione ? "Trascrivi di nuovo" : "Trascrivi") {
                        Task { await trascrivi(cartella: riunione.cartella) }
                    }
                    .disabled(motore == nil || cartellaInElaborazione != nil)
                    Button("Rinomina…") {
                        nuovoNomeRiunione = riunione.nome
                        riunioneInRinomina = riunione
                    }
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

            HStack {
                Button {
                    importaConPannello()
                } label: {
                    Label("Importa file audio…", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(registratore.isRecording || cartellaInElaborazione != nil)
            }
            .padding(.horizontal, 12)
            Text("Puoi anche trascinare un file audio sull'elenco per trascriverlo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .alert("Rinomina riunione", isPresented: rinominaPresentata) {
            TextField("Nome", text: $nuovoNomeRiunione)
            Button("Annulla", role: .cancel) { riunioneInRinomina = nil }
            Button("Rinomina") { confermaRinominaRiunione() }
        }
        .alert("Eliminare la riunione?", isPresented: eliminazionePresentata) {
            Button("Annulla", role: .cancel) { riunioneInEliminazione = nil }
            Button("Sposta nel Cestino", role: .destructive) { confermaEliminaRiunione() }
        } message: {
            Text("«\(riunioneInEliminazione?.nome ?? "")» finisce nel Cestino con audio e verbale.")
        }
    }

    /// I due alert si presentano quando c'è una riunione in lavorazione.
    private var rinominaPresentata: Binding<Bool> {
        Binding(get: { riunioneInRinomina != nil },
                set: { if !$0 { riunioneInRinomina = nil } })
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
            Picker("Ingresso", selection: $microfono.selectedDeviceID) {
                ForEach(registratore.microfono.devices) { dispositivo in
                    Text(dispositivo.name).tag(Optional(dispositivo.id))
                }
            }
            .onChange(of: registratore.microfono.selectedDeviceID) {
                registratore.microfono.noteDeviceChanged()
            }

            Toggle("Registra anche l'audio di sistema (call)", isOn: $registratore.catturaSistema)
                .disabled(registratore.isRecording)

            HStack {
                if registratore.isRecording {
                    Button {
                        Task { await fermaRegistrazione() }
                    } label: {
                        Label("Ferma", systemImage: "stop.circle.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    Text(FormattaTempo.hhmmss(registratore.microfono.elapsed))
                        .monospacedDigit()
                } else {
                    Button {
                        Task { await registratore.avvia() }
                    } label: {
                        Label("Registra", systemImage: "record.circle")
                    }
                    .disabled(registratore.staMiscelando || cartellaInElaborazione != nil)
                }
            }

            MisuratoreLivello(livelli: registratore.microfono.levels)

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
        if let motore, cartellaInElaborazione != nil {
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
        case .diarizzazione:
            Label("Riconoscimento dei parlanti…", systemImage: "person.2").font(.caption)
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
        let audio = cartella.appendingPathComponent(MeetingStore.nomeAudio)
        if let trascrizione = await motore.trascrivi(audio: audio) {
            try? MeetingStore.salva(trascrizione, in: cartella)
            aggiornaElenco()
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
            aggiornaElenco()
            await trascrivi(cartella: cartella)
        } catch {
            registratore.microfono.errorMessage =
                "Importazione non riuscita: \(error.localizedDescription)"
        }
    }

    // MARK: Gestione delle riunioni

    private func confermaRinominaRiunione() {
        guard let riunione = riunioneInRinomina else { return }
        riunioneInRinomina = nil
        do {
            let nuova = try MeetingStore.rinomina(cartella: riunione.cartella, in: nuovoNomeRiunione)
            if selezione == riunione.cartella { selezione = nuova }
            aggiornaElenco()
        } catch {
            registratore.microfono.errorMessage = error.localizedDescription
        }
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
