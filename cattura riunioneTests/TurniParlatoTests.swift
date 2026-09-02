//
//  TurniParlatoTests.swift
//  La diarizzazione produce turni frammentati: qui si uniscono i
//  frammenti contigui dello stesso parlante e si scartano i microturni.
//

import XCTest
@testable import Cattura_Riunione

final class TurniParlatoTests: XCTestCase {

    func testUnisceFrammentiDelloStessoParlante() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "A", inizio: 3.4, fine: 6.0),   // pausa 0,4 s: si unisce
            TurnoParlato(idParlante: "B", inizio: 6.5, fine: 9.0),
        ]
        let esito = TurniParlato.consolida(turni)
        XCTAssertEqual(esito, [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "B", inizio: 6.5, fine: 9.0),
        ])
    }

    func testNonUnisceOltreLaDistanzaMassima() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "A", inizio: 5.0, fine: 8.0),   // pausa 2 s: resta separato
        ]
        XCTAssertEqual(TurniParlato.consolida(turni).count, 2)
    }

    func testScartaMicroturni() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "B", inizio: 3.1, fine: 3.3),   // 0,2 s: rumore, via
            TurnoParlato(idParlante: "A", inizio: 3.5, fine: 6.0),
        ]
        // Tolto il microturno di B, i due turni di A tornano contigui e si uniscono.
        XCTAssertEqual(TurniParlato.consolida(turni), [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 6.0),
        ])
    }

    func testOrdinaPerInizio() {
        let turni = [
            TurnoParlato(idParlante: "B", inizio: 5.0, fine: 8.0),
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 4.0),
        ]
        XCTAssertEqual(TurniParlato.consolida(turni).map(\.idParlante), ["A", "B"])
    }

    func testVuoto() {
        XCTAssertEqual(TurniParlato.consolida([]), [])
    }
}
