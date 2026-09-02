//
//  cattura_riunioneApp.swift
//  cattura riunione
//
//  Punto d'ingresso: registra riunioni e ne produce il verbale trascritto.
//

import SwiftUI

@main
struct CatturaRiunioneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        Settings {
            SettingsView()
        }
    }
}
