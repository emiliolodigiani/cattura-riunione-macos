//
//  VerbaleMarkdownTests.swift
//

import XCTest
@testable import Cattura_Riunione

final class VerbaleMarkdownTests: XCTestCase {

    func testEsportazione() {
        let interventi = [
            Intervento(id: UUID(), idParlante: "s1", inizio: 0, fine: 4, testo: "Buongiorno a tutti."),
            Intervento(id: UUID(), idParlante: "s0", inizio: 65, fine: 70, testo: "Iniziamo."),
        ]
        var t = Trascrizione(
            versione: 1, durata: 70, interventi: interventi,
            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
        )
        t.rinomina(parlante: "s0", in: "Mario")

        var componenti = DateComponents()
        (componenti.year, componenti.month, componenti.day) = (2026, 9, 2)
        let data = Calendar(identifier: .gregorian).date(from: componenti)!

        let md = VerbaleMarkdown.esporta(t, titolo: "Riunione di prova", data: data)

        XCTAssertTrue(md.hasPrefix("# Riunione di prova\n"))
        XCTAssertTrue(md.contains("2 settembre 2026"))
        // Riepilogo dei parlanti col tempo di parola di ciascuno, in
        // ordine di chi ha parlato di più (s0 5 s, s1 4 s → 56% e 44%).
        XCTAssertTrue(md.contains("Parlanti: **Mario** 00:00:05 (56%) · **Parlante 1** 00:00:04 (44%)"),
                      "riepilogo mancante o diverso in:\n\(md)")
        XCTAssertTrue(md.contains("**Parlante 1** (00:00:00)\nBuongiorno a tutti."))
        XCTAssertTrue(md.contains("**Mario** (00:01:05)\nIniziamo."))
        XCTAssertTrue(md.contains("Durata: 00:01:10"))
    }

    func testSenzaInterventi() {
        let t = Trascrizione(versione: 1, durata: 0, interventi: [], nomiParlanti: [:])
        let md = VerbaleMarkdown.esporta(t, titolo: "Vuota", data: Date())
        XCTAssertTrue(md.contains("Nessun intervento rilevato."))
    }
}
