//
//  RitaglioTurniTests.swift
//  I confini della diarizzazione cadono spesso a metà parola: il
//  ritaglio audio di un turno prende un piccolo margine attorno, senza
//  uscire dalla traccia.
//

import XCTest
@testable import Cattura_Riunione

final class RitaglioTurniTests: XCTestCase {

    func testAggiungeIlMargineAiDueLati() {
        let turno = TurnoParlato(idParlante: "A", inizio: 2.0, fine: 4.0)
        let intervallo = TranscriptionEngine.intervalloRitaglio(turno, campioniTotali: 160_000)
        // Margine di 0,3 s per lato a 16 kHz: 4800 campioni.
        XCTAssertEqual(intervallo, (2 * 16000 - 4800)..<(4 * 16000 + 4800))
    }

    func testNonEsceDallaTraccia() {
        let turno = TurnoParlato(idParlante: "A", inizio: 0.1, fine: 9.9)
        let intervallo = TranscriptionEngine.intervalloRitaglio(turno, campioniTotali: 160_000)
        XCTAssertEqual(intervallo, 0..<160_000)
    }

    func testTurnoFuoriDallaTracciaÈVuoto() {
        // Turno oltre la fine dei campioni (tracce di lunghezza diversa).
        let turno = TurnoParlato(idParlante: "A", inizio: 20.0, fine: 22.0)
        let intervallo = TranscriptionEngine.intervalloRitaglio(turno, campioniTotali: 160_000)
        XCTAssertTrue(intervallo.isEmpty)
    }
}
