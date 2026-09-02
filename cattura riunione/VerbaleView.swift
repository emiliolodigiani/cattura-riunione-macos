//
//  VerbaleView.swift
//  cattura riunione
//
//  Il verbale della riunione: interventi attribuiti, rinomina dei
//  parlanti (doppio clic sul nome), riascolto sincronizzato (clic su un
//  intervento), esportazione e copia.
//

import AVFoundation
import SwiftUI

struct VerbaleView: View {

    let cartella: URL

    @State private var trascrizione: Trascrizione?
    @State private var lettore: AVAudioPlayer?
    @State private var inRiproduzione = false
    @State private var posizione: TimeInterval = 0
    @State private var orologio: Timer?
    @State private var parlanteInRinomina: String?
    @State private var nuovoNome = ""

    var body: some View {
        Group {
            if let trascrizione {
                verbale(trascrizione)
            } else {
                Text("Questa riunione non è ancora stata trascritta.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(cartella.lastPathComponent)
        .onAppear(perform: carica)
        .onDisappear(perform: fermaRiproduzione)
    }

    private func verbale(_ t: Trascrizione) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                riepilogo(t)
                ForEach(t.interventi) { intervento in
                    riga(intervento, in: t)
                }
            }
            .padding(16)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    inRiproduzione ? pausa() : riproduci(da: posizione)
                } label: {
                    Label(inRiproduzione ? "Pausa" : "Riproduci",
                          systemImage: inRiproduzione ? "pause.fill" : "play.fill")
                }
                Text(FormattaTempo.hhmmss(posizione)).monospacedDigit()
                Button("Copia") { copia(t) }
                Button("Esporta") { esporta(t) }
            }
        }
    }

    /// Chi ha parlato e per quanto, in testa al verbale.
    @ViewBuilder
    private func riepilogo(_ t: Trascrizione) -> some View {
        let tempi = t.tempiDiParola()
        let totale = tempi.reduce(0) { $0 + $1.durata }
        if totale > 0 {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(tempi, id: \.idParlante) { voce in
                    HStack(spacing: 8) {
                        Text(t.nome(perParlante: voce.idParlante)).bold()
                        Text(FormattaTempo.hhmmss(voce.durata))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text("\(Int((voce.durata / totale * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // Barretta proporzionale alla quota di parlato.
                        GeometryReader { geometria in
                            Capsule()
                                .fill(Color.accentColor.opacity(0.35))
                                .frame(width: geometria.size.width * voce.durata / totale)
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func riga(_ intervento: Intervento, in t: Trascrizione) -> some View {
        let attivo = posizione >= intervento.inizio && posizione < intervento.fine
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if parlanteInRinomina == intervento.idParlante {
                    TextField("Nome", text: $nuovoNome)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit { confermaRinomina(intervento.idParlante) }
                } else {
                    Text(t.nome(perParlante: intervento.idParlante))
                        .bold()
                        .onTapGesture(count: 2) {
                            nuovoNome = t.nomiParlanti[intervento.idParlante] ?? ""
                            parlanteInRinomina = intervento.idParlante
                        }
                }
                Text(FormattaTempo.hhmmss(intervento.inizio))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(intervento.testo)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attivo ? Color.accentColor.opacity(0.12) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { riproduci(da: intervento.inizio) }
    }

    // MARK: Dati

    private func carica() {
        trascrizione = MeetingStore.caricaTrascrizione(da: cartella)
    }

    private func confermaRinomina(_ id: String) {
        guard var t = trascrizione else { return }
        t.rinomina(parlante: id, in: nuovoNome)
        trascrizione = t
        parlanteInRinomina = nil
        try? MeetingStore.salva(t, in: cartella)
    }

    // MARK: Riproduzione

    private func riproduci(da secondi: TimeInterval) {
        if lettore == nil {
            lettore = try? AVAudioPlayer(
                contentsOf: cartella.appendingPathComponent(MeetingStore.nomeAudio)
            )
        }
        guard let lettore else { return }
        lettore.currentTime = secondi
        lettore.play()
        inRiproduzione = true
        orologio?.invalidate()
        orologio = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                posizione = lettore.currentTime
                if !lettore.isPlaying { inRiproduzione = false }
            }
        }
    }

    private func pausa() {
        lettore?.pause()
        inRiproduzione = false
    }

    private func fermaRiproduzione() {
        orologio?.invalidate()
        orologio = nil
        lettore?.stop()
        lettore = nil
        inRiproduzione = false
    }

    // MARK: Esportazione

    private func copia(_ t: Trascrizione) {
        let testo = VerbaleMarkdown.esporta(t, titolo: cartella.lastPathComponent, data: Date())
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testo, forType: .string)
    }

    private func esporta(_ t: Trascrizione) {
        try? MeetingStore.salvaVerbale(t, in: cartella)
        NSWorkspace.shared.activateFileViewerSelecting([MeetingStore.urlVerbale(in: cartella)])
    }
}
