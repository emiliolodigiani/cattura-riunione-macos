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
    /// traccia non deve spezzare i turni di questa), dal microfono si
    /// scartano i cluster che sono eco dell'audio di sistema, poi gli id
    /// dei parlanti ricevono il prefisso della traccia e il tutto si
    /// ordina per tempo d'inizio.
    static func unisci(microfono: [TurnoParlato], sistema: [TurnoParlato]) -> [TurnoParlato] {
        let sistemaConsolidato = consolida(sistema)
        let microfonoPulito = senzaEco(consolida(microfono), sistema: sistemaConsolidato)
        func prefissa(_ turni: [TurnoParlato], con prefisso: String) -> [TurnoParlato] {
            turni.map {
                TurnoParlato(idParlante: prefisso + $0.idParlante, inizio: $0.inizio, fine: $0.fine)
            }
        }
        return (prefissa(microfonoPulito, con: prefissoMicrofono)
                + prefissa(sistemaConsolidato, con: prefissoSistema))
            .sorted { $0.inizio < $1.inizio }
    }

    /// Scarta dai turni del microfono i cluster che sono eco dell'audio
    /// di sistema riprodotto dagli altoparlanti (niente cuffie). Il
    /// criterio non suppone nulla sul numero di parlanti locali: un
    /// parlante vero tiene il turno anche quando i remoti tacciono,
    /// mentre l'eco per costruzione esiste solo quando parla la traccia
    /// di sistema. Un cluster il cui parlato è coperto oltre `soglia`
    /// dal parlato di sistema è eco.
    static func senzaEco(
        _ microfono: [TurnoParlato],
        sistema: [TurnoParlato],
        soglia: Double = 0.75
    ) -> [TurnoParlato] {
        guard !sistema.isEmpty else { return microfono }
        let intervalli = intervalliUniti(sistema)
        var durata: [String: Double] = [:]
        var coperta: [String: Double] = [:]
        for turno in microfono {
            durata[turno.idParlante, default: 0] += turno.fine - turno.inizio
            coperta[turno.idParlante, default: 0] += copertura(di: turno, su: intervalli)
        }
        return microfono.filter { turno in
            let totale = durata[turno.idParlante, default: 0]
            return totale <= 0 || coperta[turno.idParlante, default: 0] / totale < soglia
        }
    }

    /// Unione temporale dei turni: intervalli disgiunti ordinati.
    private static func intervalliUniti(_ turni: [TurnoParlato]) -> [(inizio: Double, fine: Double)] {
        var esito: [(inizio: Double, fine: Double)] = []
        for turno in turni.sorted(by: { $0.inizio < $1.inizio }) {
            if var ultimo = esito.last, turno.inizio <= ultimo.fine {
                ultimo.fine = max(ultimo.fine, turno.fine)
                esito[esito.count - 1] = ultimo
            } else {
                esito.append((turno.inizio, turno.fine))
            }
        }
        return esito
    }

    /// Secondi del turno coperti dagli intervalli (già disgiunti).
    private static func copertura(
        di turno: TurnoParlato, su intervalli: [(inizio: Double, fine: Double)]
    ) -> Double {
        intervalli.reduce(0) {
            $0 + max(0, min(turno.fine, $1.fine) - max(turno.inizio, $1.inizio))
        }
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
