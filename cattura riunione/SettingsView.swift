//
//  SettingsView.swift
//  cattura riunione
//
//  Impostazioni (⌘,): cartella di destinazione delle riunioni. Le
//  sorgenti da registrare si scelgono nella finestra principale.
//

import AppKit
import SwiftUI

struct SettingsView: View {

    @State private var cartelle = OutputFolderStore()

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
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
