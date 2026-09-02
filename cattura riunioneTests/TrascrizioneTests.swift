//
//  TrascrizioneTests.swift
//  Modello del verbale: etichette, rinomina, andata/ritorno JSON, tempi.
//

import XCTest
@testable import Cattura_Riunione

final class TrascrizioneTests: XCTestCase {

    private func trascrizioneDiProva() -> Trascrizione {
        let interventi = [
            Intervento(id: UUID(), idParlante: "speaker_1", inizio: 0, fine: 4.2, testo: "Buongiorno a tutti."),
            Intervento(id: UUID(), idParlante: "speaker_0", inizio: 4.5, fine: 9.0, testo: "Buongiorno, iniziamo."),
            Intervento(id: UUID(), idParlante: "speaker_1", inizio: 9.4, fine: 12.0, testo: "Primo punto."),
        ]
        return Trascrizione(
            versione: 1,
            durata: 12.0,
            interventi: interventi,
            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
        )
    }

    func testEtichettePerOrdineDiComparsa() {
        let t = trascrizioneDiProva()
        // Chi parla per primo è "Parlante 1", a prescindere dall'id grezzo.
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Parlante 1")
        XCTAssertEqual(t.nome(perParlante: "speaker_0"), "Parlante 2")
    }

    func testRinomina() {
        var t = trascrizioneDiProva()
        t.rinomina(parlante: "speaker_1", in: "Mario")
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Mario")
        XCTAssertEqual(t.nome(perParlante: "speaker_0"), "Parlante 2")
    }

    func testRinominaVuotaRipristinaEtichetta() {
        var t = trascrizioneDiProva()
        t.rinomina(parlante: "speaker_1", in: "Mario")
        t.rinomina(parlante: "speaker_1", in: "   ")
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Parlante 1")
    }

    func testAndataRitornoJSON() throws {
        let t = trascrizioneDiProva()
        let dati = try JSONEncoder().encode(t)
        let riletta = try JSONDecoder().decode(Trascrizione.self, from: dati)
        XCTAssertEqual(riletta, t)
    }

    func testFormattaTempo() {
        XCTAssertEqual(FormattaTempo.hhmmss(0), "00:00:00")
        XCTAssertEqual(FormattaTempo.hhmmss(62.9), "00:01:02")
        XCTAssertEqual(FormattaTempo.hhmmss(3725), "01:02:05")
    }
}
