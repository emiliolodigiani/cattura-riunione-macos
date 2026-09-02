//
//  MeetingStore.swift
//  cattura riunione
//
//  Ogni riunione è una cartella "Riunione AAAA-MM-GG HH.mm" nella
//  cartella di destinazione, con dentro riunione.m4a, trascrizione.json
//  e verbale.md. Qui vivono creazione, salvataggio, lettura ed elenco.
//

import Foundation

nonisolated struct Riunione: Identifiable, Equatable {
    var id: URL { cartella }
    var cartella: URL
    var nome: String
    var data: Date
    var audioURL: URL
    var haTrascrizione: Bool
}

nonisolated enum MeetingStore {

    static let nomeAudio = "riunione.m4a"
    static let nomeTrascrizione = "trascrizione.json"
    static let nomeVerbale = "verbale.md"

    enum Errore: LocalizedError {
        case nomeNonValido
        case nomeGiaUsato
        var errorDescription: String? {
            switch self {
            case .nomeNonValido: "Il nome della riunione non può essere vuoto."
            case .nomeGiaUsato: "Esiste già una riunione con questo nome."
            }
        }
    }

    private static var formattatore: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy-MM-dd HH.mm"
        return f
    }

    /// Crea la cartella "Riunione AAAA-MM-GG HH.mm" (con suffisso ~2, ~3…
    /// se esiste già) e la restituisce.
    static func creaCartella(in base: URL, data: Date) throws -> URL {
        let nomeBase = "Riunione \(formattatore.string(from: data))"
        // isDirectory esplicito: senza, appendingPathComponent aggiunge la
        // barra finale solo se la cartella esiste già, e URL uguali sulla
        // carta risultano diverse nei confronti (selezione, test).
        var candidata = base.appendingPathComponent(nomeBase, isDirectory: true)
        var progressivo = 2
        while FileManager.default.fileExists(atPath: candidata.path) {
            candidata = base.appendingPathComponent("\(nomeBase) ~\(progressivo)", isDirectory: true)
            progressivo += 1
        }
        try FileManager.default.createDirectory(at: candidata, withIntermediateDirectories: true)
        return candidata
    }

    /// Salva trascrizione.json e rigenera verbale.md.
    static func salva(_ trascrizione: Trascrizione, in cartella: URL) throws {
        let codificatore = JSONEncoder()
        codificatore.outputFormatting = [.prettyPrinted, .sortedKeys]
        try codificatore.encode(trascrizione)
            .write(to: cartella.appendingPathComponent(nomeTrascrizione), options: .atomic)
        try salvaVerbale(trascrizione, in: cartella)
    }

    static func caricaTrascrizione(da cartella: URL) -> Trascrizione? {
        guard let dati = try? Data(contentsOf: cartella.appendingPathComponent(nomeTrascrizione)) else {
            return nil
        }
        return try? JSONDecoder().decode(Trascrizione.self, from: dati)
    }

    static func salvaVerbale(_ trascrizione: Trascrizione, in cartella: URL) throws {
        let info = try? FileManager.default.attributesOfItem(atPath: cartella.path)
        let data = info?[.creationDate] as? Date ?? Date()
        let markdown = VerbaleMarkdown.esporta(
            trascrizione, titolo: cartella.lastPathComponent, data: data
        )
        try markdown.data(using: .utf8)!
            .write(to: cartella.appendingPathComponent(nomeVerbale), options: .atomic)
    }

    /// Rinomina la cartella della riunione e rigenera il verbale (il cui
    /// titolo è il nome della cartella). Restituisce la nuova cartella.
    static func rinomina(cartella: URL, in nome: String) throws -> URL {
        let pulito = nome
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !pulito.isEmpty else { throw Errore.nomeNonValido }
        let destinazione = cartella.deletingLastPathComponent()
            .appendingPathComponent(pulito, isDirectory: true)
        guard destinazione != cartella else { return cartella }
        guard !FileManager.default.fileExists(atPath: destinazione.path) else {
            throw Errore.nomeGiaUsato
        }
        try FileManager.default.moveItem(at: cartella, to: destinazione)
        if let trascrizione = caricaTrascrizione(da: destinazione) {
            try salvaVerbale(trascrizione, in: destinazione)
        }
        return destinazione
    }

    /// Sposta la riunione nel Cestino (eliminazione recuperabile); se il
    /// volume non ha un Cestino, elimina definitivamente.
    static func elimina(cartella: URL) throws {
        do {
            try FileManager.default.trashItem(at: cartella, resultingItemURL: nil)
        } catch {
            try FileManager.default.removeItem(at: cartella)
        }
    }

    /// Le riunioni valide (cartelle con riunione.m4a), dalla più recente.
    static func elenca(in base: URL) -> [Riunione] {
        // Le URL si ricostruiscono da `base` (non da contentsOfDirectory(at:),
        // che le restituisce risolte, es. /private/var…): così coincidono con
        // quelle di creaCartella e i confronti di selezione nella UI tengono.
        let nomi = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        return nomi.compactMap { nome -> Riunione? in
            let cartella = base.appendingPathComponent(nome, isDirectory: true)
            let audio = cartella.appendingPathComponent(nomeAudio)
            guard FileManager.default.fileExists(atPath: audio.path) else { return nil }
            let attributi = try? FileManager.default.attributesOfItem(atPath: cartella.path)
            return Riunione(
                cartella: cartella,
                nome: cartella.lastPathComponent,
                data: attributi?[.creationDate] as? Date ?? .distantPast,
                audioURL: audio,
                haTrascrizione: FileManager.default.fileExists(
                    atPath: cartella.appendingPathComponent(nomeTrascrizione).path
                )
            )
        }
        .sorted { $0.data > $1.data }
    }
}
