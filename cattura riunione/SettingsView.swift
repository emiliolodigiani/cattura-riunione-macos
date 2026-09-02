//
//  SettingsView.swift
//  cattura riunione
//
//  Impostazioni (⌘,): cartella di destinazione delle riunioni e
//  preferenza sulla cattura dell'audio di sistema.
//

import AppKit
import SwiftUI

struct SettingsView: View {

    @State private var cartelle = OutputFolderStore()
    @AppStorage("catturaSistema") private var catturaSistema = true

    var body: some View {
        Form {
            Section("Destinazione") {
                HStack {
                    Text(cartelle.url.path(percentEncoded: false))
                        .truncationMode(.middle)
                        .lineLimit(1)
                    Spacer()
                    Button("Scegli…") { cartelle.choose() }
                }
            }
            Section("Registrazione") {
                Toggle("Cattura l'audio di sistema (call)", isOn: $catturaSistema)
                Text("Alla prima registrazione macOS chiede il permesso di registrare l'audio di sistema.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
