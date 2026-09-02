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

    /// Prefissi che distinguono i parlanti delle due tracce di una
    /// registrazione doppia (microfono + audio di sistema).
    static let prefissoMicrofono = "microfono:"
    static let prefissoSistema = "sistema:"

    /// Fonde i turni diarizzati sulle due tracce separate: ciascuna
    /// traccia viene consolidata per conto suo (una voce sull'altra
    /// traccia non deve spezzare i turni di questa), poi gli id dei
    /// parlanti ricevono il prefisso della traccia e il tutto si ordina
    /// per tempo d'inizio.
    static func unisci(microfono: [TurnoParlato], sistema: [TurnoParlato]) -> [TurnoParlato] {
        func prefissa(_ turni: [TurnoParlato], con prefisso: String) -> [TurnoParlato] {
            consolida(turni).map {
                TurnoParlato(idParlante: prefisso + $0.idParlante, inizio: $0.inizio, fine: $0.fine)
            }
        }
        return (prefissa(microfono, con: prefissoMicrofono) + prefissa(sistema, con: prefissoSistema))
            .sorted { $0.inizio < $1.inizio }
    }

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
