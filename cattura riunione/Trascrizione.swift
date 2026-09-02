//
//  Trascrizione.swift
//  cattura riunione
//
//  Il verbale strutturato di una riunione: interventi attribuiti ai
//  parlanti, con i nomi assegnati dall'utente. È il contenuto di
//  trascrizione.json nella cartella della riunione.
//

import Foundation

nonisolated struct Intervento: Codable, Equatable, Identifiable {
    var id: UUID
    /// Identificatore grezzo del parlante prodotto dalla diarizzazione.
    var idParlante: String
    /// Secondi dall'inizio della registrazione.
    var inizio: Double
    var fine: Double
    var testo: String
}

nonisolated struct Trascrizione: Codable, Equatable {
    var versione: Int
    var durata: Double
    var interventi: [Intervento]
    /// idParlante → nome mostrato. Contiene sempre tutti i parlanti:
    /// alla creazione le etichette ("Parlante 1"…) seguono l'ordine di
    /// prima comparsa, poi l'utente può sostituirle con i nomi veri.
    var nomiParlanti: [String: String]

    func nome(perParlante id: String) -> String {
        nomiParlanti[id] ?? "Parlante ?"
    }

    /// Rinomina un parlante; una stringa vuota ripristina l'etichetta
    /// predefinita in base all'ordine di comparsa.
    mutating func rinomina(parlante id: String, in nome: String) {
        let pulito = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        if pulito.isEmpty {
            nomiParlanti[id] = Self.etichette(perOrdineDiComparsa: interventi)[id]
        } else {
            nomiParlanti[id] = pulito
        }
    }

    /// Tempo di parola complessivo per parlante, dal più loquace.
    func tempiDiParola() -> [(idParlante: String, durata: Double)] {
        var totali: [String: Double] = [:]
        for intervento in interventi {
            totali[intervento.idParlante, default: 0] += max(0, intervento.fine - intervento.inizio)
        }
        return totali
            .map { (idParlante: $0.key, durata: $0.value) }
            .sorted { $0.durata > $1.durata }
    }

    /// Etichette predefinite: "Parlante 1" per chi parla per primo, e così via.
    static func etichette(perOrdineDiComparsa interventi: [Intervento]) -> [String: String] {
        var etichette: [String: String] = [:]
        for intervento in interventi.sorted(by: { $0.inizio < $1.inizio })
        where etichette[intervento.idParlante] == nil {
            etichette[intervento.idParlante] = "Parlante \(etichette.count + 1)"
        }
        return etichette
    }
}

nonisolated enum FormattaTempo {
    /// hh:mm:ss, troncato al secondo.
    static func hhmmss(_ secondi: Double) -> String {
        let s = max(0, Int(secondi))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
