//
//  MeetingStoreTests.swift
//

import XCTest
@testable import Cattura_Riunione

final class MeetingStoreTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("riunioni-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private var trascrizione: Trascrizione {
        let interventi = [Intervento(id: UUID(), idParlante: "s0", inizio: 0, fine: 3, testo: "Ciao.")]
        return Trascrizione(versione: 1, durata: 3, interventi: interventi,
                            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi))
    }

    func testCreaCartellaConNomeDatato() throws {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute) = (2026, 9, 2, 14, 30)
        let data = Calendar(identifier: .gregorian).date(from: c)!
        let cartella = try MeetingStore.creaCartella(in: base, data: data)
        XCTAssertEqual(cartella.lastPathComponent, "Riunione 2026-09-02 14.30")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cartella.path))
    }

    func testCreaCartellaConNomePersonalizzato() throws {
        let prima = try MeetingStore.creaCartella(in: base, nome: "Chiacchierata col cliente")
        XCTAssertEqual(prima.lastPathComponent, "Chiacchierata col cliente")
        // Stesso nome → suffisso progressivo, come per le cartelle datate.
        let seconda = try MeetingStore.creaCartella(in: base, nome: "Chiacchierata col cliente")
        XCTAssertEqual(seconda.lastPathComponent, "Chiacchierata col cliente ~2")
        // Nome vuoto → si ricade sul nome datato standard.
        let datata = try MeetingStore.creaCartella(in: base, nome: "   ")
        XCTAssertTrue(datata.lastPathComponent.hasPrefix("Riunione "))
    }

    func testCartellaDuplicataRiceveSuffisso() throws {
        let data = Date()
        let prima = try MeetingStore.creaCartella(in: base, data: data)
        let seconda = try MeetingStore.creaCartella(in: base, data: data)
        XCTAssertNotEqual(prima, seconda)
        XCTAssertTrue(FileManager.default.fileExists(atPath: seconda.path))
    }

    func testSalvaECarica() throws {
        // Catturata una volta: la proprietà genera id nuovi a ogni accesso.
        let trascrizione = self.trascrizione
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        try MeetingStore.salva(trascrizione, in: cartella)
        let riletta = MeetingStore.caricaTrascrizione(da: cartella)
        XCTAssertEqual(riletta, trascrizione)
        // salva() rigenera anche il verbale, col nome della riunione nel
        // nome del file: copiato altrove resta riconoscibile.
        let verbale = cartella.appendingPathComponent(
            "\(cartella.lastPathComponent) - verbale.md"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: verbale.path))
    }

    func testRinominaCartella() throws {
        let trascrizione = self.trascrizione
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        try MeetingStore.salva(trascrizione, in: cartella)
        let nuova = try MeetingStore.rinomina(cartella: cartella, in: "Riunione col cliente")
        XCTAssertEqual(nuova.lastPathComponent, "Riunione col cliente")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cartella.path))
        // La trascrizione resta leggibile e il verbale viene rigenerato
        // con nuovo nome file e nuovo titolo; quello vecchio sparisce.
        XCTAssertEqual(MeetingStore.caricaTrascrizione(da: nuova), trascrizione)
        let verbale = try String(
            contentsOf: nuova.appendingPathComponent("Riunione col cliente - verbale.md"),
            encoding: .utf8
        )
        XCTAssertTrue(verbale.hasPrefix("# Riunione col cliente\n"))
        let residui = try FileManager.default.contentsOfDirectory(atPath: nuova.path)
            .filter { $0.hasSuffix("- verbale.md") || $0 == "verbale.md" }
        XCTAssertEqual(residui, ["Riunione col cliente - verbale.md"])
    }

    func testRinominaRifiutaNomeVuotoOGiaUsato() throws {
        let prima = try MeetingStore.creaCartella(in: base, data: Date())
        let seconda = try MeetingStore.creaCartella(in: base, data: Date())
        XCTAssertThrowsError(try MeetingStore.rinomina(cartella: prima, in: "   "))
        XCTAssertThrowsError(
            try MeetingStore.rinomina(cartella: prima, in: seconda.lastPathComponent)
        )
    }

    func testEliminaSpostaNelCestino() throws {
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        try MeetingStore.elimina(cartella: cartella)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cartella.path))
    }

    func testElenca() throws {
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        // Senza riunione.m4a la cartella non è una riunione valida.
        XCTAssertTrue(MeetingStore.elenca(in: base).isEmpty)
        FileManager.default.createFile(
            atPath: cartella.appendingPathComponent("riunione.m4a").path, contents: Data([0])
        )
        let riunioni = MeetingStore.elenca(in: base)
        XCTAssertEqual(riunioni.count, 1)
        XCTAssertEqual(riunioni[0].cartella, cartella)
        XCTAssertFalse(riunioni[0].haTrascrizione)
    }
}
