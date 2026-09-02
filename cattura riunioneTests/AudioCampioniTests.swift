//
//  AudioCampioniTests.swift
//  Le utilità audio si provano con file sintetici generati al volo.
//

import AVFoundation
import XCTest
@testable import Cattura_Riunione

final class AudioCampioniTests: XCTestCase {

    /// Scrive un WAV mono di `durata` secondi con una sinusoide a 440 Hz.
    private func wavDiProva(frequenza: Double, durata: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prova-\(UUID().uuidString).wav")
        let formato = AVAudioFormat(standardFormatWithSampleRate: frequenza, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: formato.settings)
        let frames = AVAudioFrameCount(frequenza * durata)
        let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData![0][i] = sin(Float(i) * 2 * .pi * 440 / Float(frequenza)) * 0.5
        }
        try file.write(from: buffer)
        return url
    }

    func testCaricaRicampionaA16k() throws {
        let url = try wavDiProva(frequenza: 48000, durata: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }
        let campioni = try AudioCampioni.carica(url, frequenza: 16000)
        // 2 secondi a 16 kHz, con tolleranza per i bordi del convertitore.
        XCTAssertEqual(Double(campioni.count), 32000, accuracy: 1600)
        XCTAssertTrue(campioni.contains { abs($0) > 0.1 }, "il segnale non deve sparire")
    }

    func testMiscelaSommaEConserva() {
        let a: [Float] = [0.5, 0.5, 0.5]
        let b: [Float] = [0.25, -0.25]
        let mix = AudioCampioni.miscela(a, b)
        XCTAssertEqual(mix.count, 3)
        XCTAssertEqual(mix[0], 0.75, accuracy: 0.001)
        XCTAssertEqual(mix[1], 0.25, accuracy: 0.001)
        XCTAssertEqual(mix[2], 0.5, accuracy: 0.001)
    }

    func testMiscelaLimitaIlFondoScala() {
        let mix = AudioCampioni.miscela([0.9], [0.9])
        XCTAssertLessThanOrEqual(mix[0], 1.0)
    }

    func testNormalizzaPortaIlPiccoAMenoUnDecibel() {
        let campioni: [Float] = [0.1, -0.27, 0.05]
        let esito = AudioCampioni.normalizza(campioni)
        XCTAssertEqual(esito.map(abs).max()!, 0.891, accuracy: 0.001)
        // I rapporti tra campioni restano invariati.
        XCTAssertEqual(esito[0] / esito[1], campioni[0] / campioni[1], accuracy: 0.001)
    }

    func testNormalizzaNonAmplificaIlSilenzio() {
        XCTAssertEqual(AudioCampioni.normalizza([]), [])
        // Sotto la soglia di rumore non si amplifica: si eviterebbe solo
        // di sparare a fondo scala il rumore di fondo.
        let quasiSilenzio = [Float](repeating: 0.0005, count: 100)
        XCTAssertEqual(AudioCampioni.normalizza(quasiSilenzio), quasiSilenzio)
    }

    func testNormalizzaNonAbbassaUnSegnaleGiaPieno() {
        let pieni: [Float] = [0.95, -0.95]
        XCTAssertEqual(AudioCampioni.normalizza(pieni), pieni)
    }

    func testScriviM4A() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prova-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let campioni = [Float](repeating: 0.1, count: 48000)
        try AudioCampioni.scriviM4A(campioni, frequenza: 48000, in: url)
        let riletto = try AVAudioFile(forReading: url)
        // Un secondo di audio, con la tolleranza del priming AAC.
        XCTAssertEqual(Double(riletto.length), 48000, accuracy: 4800)
    }
}
