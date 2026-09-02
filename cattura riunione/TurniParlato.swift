//
//  TurniParlato.swift
//  cattura riunione
//
//  Pulizia dei turni di parola in uscita dalla diarizzazione, prima del
//  ritaglio audio per la trascrizione.
//

import Foundation

nonisolated struct TurnoParlato: Equatable {
    var idParlante: String
    var inizio: Double
    var fine: Double
}

nonisolated enum TurniParlato {
    /// Ordina i turni, scarta quelli più corti di `durataMinima` e unisce
    /// i turni consecutivi dello stesso parlante separati da meno di
    /// `distanzaMassima` secondi. L'ordine delle operazioni conta: lo
    /// scarto dei microturni può rendere contigui turni prima separati.
    static func consolida(
        _ turni: [TurnoParlato],
        distanzaMassima: Double = 1.0,
        durataMinima: Double = 0.5
    ) -> [TurnoParlato] {
        let validi = turni
            .filter { $0.fine - $0.inizio >= durataMinima }
            .sorted { $0.inizio < $1.inizio }

        var esito: [TurnoParlato] = []
        for turno in validi {
            if var ultimo = esito.last,
               ultimo.idParlante == turno.idParlante,
               turno.inizio - ultimo.fine <= distanzaMassima {
                ultimo.fine = max(ultimo.fine, turno.fine)
                esito[esito.count - 1] = ultimo
            } else {
                esito.append(turno)
            }
        }
        return esito
    }
}
