//
//  VerbaleView.swift
//  cattura riunione
//
//  Segnaposto: il verbale vero arriva col task successivo.
//

import SwiftUI

struct VerbaleView: View {
    let cartella: URL
    var body: some View {
        Text(cartella.lastPathComponent)
    }
}
