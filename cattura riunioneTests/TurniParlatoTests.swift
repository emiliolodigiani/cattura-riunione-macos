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

    // MARK: Doppia traccia (microfono + sistema)

    func testUnisceLeDueTracceConPrefissiEOrdine() {
        let mic = [TurnoParlato(idParlante: "S1", inizio: 4.0, fine: 8.0)]
        let sistema = [TurnoParlato(idParlante: "S1", inizio: 0.0, fine: 3.0)]
        let esito = TurniParlato.unisci(microfono: mic, sistema: sistema)
        XCTAssertEqual(esito, [
            TurnoParlato(idParlante: "sistema:S1", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "microfono:S1", inizio: 4.0, fine: 8.0),
        ])
    }

    func testConsolidaOgniTracciaPerConto() {
        // I due frammenti del microfono si uniscono anche se in mezzo,
        // sull'altra traccia, qualcuno sta parlando.
        let mic = [
            TurnoParlato(idParlante: "S1", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "S1", inizio: 3.4, fine: 6.0),
        ]
        let sistema = [TurnoParlato(idParlante: "S1", inizio: 3.1, fine: 5.0)]
        let esito = TurniParlato.unisci(microfono: mic, sistema: sistema)
        XCTAssertEqual(esito, [
            TurnoParlato(idParlante: "microfono:S1", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "sistema:S1", inizio: 3.1, fine: 5.0),
        ])
    }

    func testTracceVuote() {
        XCTAssertEqual(TurniParlato.unisci(microfono: [], sistema: []), [])
        let mic = [TurnoParlato(idParlante: "S1", inizio: 0.0, fine: 2.0)]
        XCTAssertEqual(
            TurniParlato.unisci(microfono: mic, sistema: []),
            [TurnoParlato(idParlante: "microfono:S1", inizio: 0.0, fine: 2.0)]
        )
    }

    // MARK: Eco dell'audio di sistema nel microfono

    func testScartaIlClusterCheParlaSoloSopraIlSistema() {
        // "Eco" esiste solo mentre parla il sistema: copertura totale, via.
        let mic = [
            TurnoParlato(idParlante: "Eco", inizio: 1.0, fine: 4.0),
            TurnoParlato(idParlante: "Eco", inizio: 10.0, fine: 12.0),
        ]
        let sistema = [
            TurnoParlato(idParlante: "S1", inizio: 0.0, fine: 5.0),
            TurnoParlato(idParlante: "S1", inizio: 9.0, fine: 13.0),
        ]
        XCTAssertEqual(TurniParlato.senzaEco(mic, sistema: sistema), [])
    }

    func testTieneIlParlanteLocaleAncheSeAVolteSiSovrappone() {
        // Un parlante vero tiene il turno anche quando i remoti tacciono:
        // copertura 2 s su 8 s, ben sotto la soglia.
        let mic = [
            TurnoParlato(idParlante: "Locale", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "Locale", inizio: 8.0, fine: 10.0),
        ]
        let sistema = [TurnoParlato(idParlante: "S1", inizio: 4.0, fine: 9.0)]
        XCTAssertEqual(TurniParlato.senzaEco(mic, sistema: sistema), mic)
    }

    func testScartaSoloIlClusterEcoNonGliAltri() {
        let mic = [
            TurnoParlato(idParlante: "Locale", inizio: 0.0, fine: 10.0),
            TurnoParlato(idParlante: "Eco", inizio: 12.0, fine: 15.0),
        ]
        let sistema = [TurnoParlato(idParlante: "S1", inizio: 11.0, fine: 16.0)]
        XCTAssertEqual(TurniParlato.senzaEco(mic, sistema: sistema), [
            TurnoParlato(idParlante: "Locale", inizio: 0.0, fine: 10.0),
        ])
    }

    func testLaCoperturaNonContaDueVolteISovrapposti() {
        // Due parlanti di sistema sullo stesso intervallo: la copertura è
        // l'unione (2 s su 4, sotto soglia), non la somma (4 s su 4).
        let mic = [TurnoParlato(idParlante: "Locale", inizio: 0.0, fine: 4.0)]
        let sistema = [
            TurnoParlato(idParlante: "S1", inizio: 0.0, fine: 2.0),
            TurnoParlato(idParlante: "S2", inizio: 0.0, fine: 2.0),
        ]
        XCTAssertEqual(TurniParlato.senzaEco(mic, sistema: sistema), mic)
    }

    func testSenzaSistemaNonScartaNulla() {
        let mic = [TurnoParlato(idParlante: "Locale", inizio: 0.0, fine: 1.0)]
        XCTAssertEqual(TurniParlato.senzaEco(mic, sistema: []), mic)
    }

    func testUnisciScartaLEcoDalMicrofono() {
        // Il filtro è parte della fusione delle due tracce.
        let mic = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "B", inizio: 8.5, fine: 10.0),
        ]
        let sistema = [TurnoParlato(idParlante: "S1", inizio: 8.0, fine: 11.0)]
        XCTAssertEqual(TurniParlato.unisci(microfono: mic, sistema: sistema), [
            TurnoParlato(idParlante: "microfono:A", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "sistema:S1", inizio: 8.0, fine: 11.0),
        ])
    }
}
