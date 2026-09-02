//
//  VerbaleMarkdown.swift
//  cattura riunione
//
//  Il verbale in forma leggibile: il file verbale.md salvato accanto
//  all'audio e il testo per il pulsante Copia.
//

import Foundation

nonisolated enum VerbaleMarkdown {

    static func esporta(_ trascrizione: Trascrizione, titolo: String, data: Date) -> String {
        let formattatore = DateFormatter()
        formattatore.locale = Locale(identifier: "it_IT")
        formattatore.dateStyle = .long
        formattatore.timeStyle = .none

        var righe: [String] = []
        righe.append("# \(titolo)")
        righe.append("")
        righe.append("\(formattatore.string(from: data)) · Durata: \(FormattaTempo.hhmmss(trascrizione.durata))")
        righe.append("")

        // Riepilogo: chi ha parlato e per quanto (quota sul parlato totale).
        let tempi = trascrizione.tempiDiParola()
        let totale = tempi.reduce(0) { $0 + $1.durata }
        if totale > 0 {
            let voci = tempi.map { voce in
                let quota = Int((voce.durata / totale * 100).rounded())
                return "**\(trascrizione.nome(perParlante: voce.idParlante))** "
                    + "\(FormattaTempo.hhmmss(voce.durata)) (\(quota)%)"
            }
            righe.append("Parlanti: " + voci.joined(separator: " · "))
            righe.append("")
        }

        if trascrizione.interventi.isEmpty {
            righe.append("Nessun intervento rilevato.")
        } else {
            for intervento in trascrizione.interventi.sorted(by: { $0.inizio < $1.inizio }) {
                righe.append("**\(trascrizione.nome(perParlante: intervento.idParlante))** (\(FormattaTempo.hhmmss(intervento.inizio)))")
                righe.append(intervento.testo)
                righe.append("")
            }
        }
        return righe.joined(separator: "\n")
    }
}
