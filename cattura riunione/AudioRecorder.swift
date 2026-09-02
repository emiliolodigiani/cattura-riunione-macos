//
//  AudioRecorder.swift
//  cattura riunione
//
//  Riusato da cattura brano e ridotto all'essenziale: selezione
//  dell'interfaccia, monitoraggio del livello, registrazione del
//  microfono su file temporaneo. Le lezioni imparate restano: tap sul
//  formato REALE dell'hardware e guardia sulle NSException di
//  AVAudioEngine.
//

import AVFoundation
import CoreAudio
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioRecorder {

    // MARK: Stato osservabile

    var devices: [AudioInputDevice] = []
    var selectedDeviceID: AudioDeviceID?
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// Picchi lineari (0…1) per canale, aggiornati durante la registrazione.
    private(set) var levels: [Float] = []
    var errorMessage: String?

    // MARK: Stato interno

    private let engine = AVAudioEngine()
    private var writer: TapWriter?
    /// Tap di solo monitoraggio, attivo quando non si registra.
    private var monitor: TapWriter?
    private var tempURL: URL?
    private var startDate: Date?
    private var meterTask: Task<Void, Never>?

    var selectedDevice: AudioInputDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    init() {
        refreshDevices()
        Task { await startMonitoring() }
    }

    // MARK: Dispositivi

    func refreshDevices() {
        devices = AudioDeviceEnumerator.inputDevices()
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = AudioDeviceEnumerator.defaultInputDevice() ?? devices.first?.id
        }
    }

    // MARK: Monitoraggio del livello (senza registrare)

    /// Avvia il motore audio con un tap di sola misura, così il misuratore
    /// mostra il livello d'ingresso anche prima di registrare.
    func startMonitoring() async {
        guard !isRecording, monitor == nil else { return }
        // Senza permesso non mostriamo errori: il messaggio arriva solo
        // quando l'utente prova davvero a registrare.
        guard await requestMicrophoneAccess() else { return }
        // La risposta al permesso può arrivare molto dopo (finestra di sistema
        // al primo avvio): nel frattempo l'utente può aver premuto Registra.
        // Senza questo ricontrollo si installerebbe un secondo tap sul bus già
        // occupato, e AVAudioEngine abbatte l'app con una NSException.
        guard !isRecording, monitor == nil else { return }

        do {
            try configureEngineInput()
            let input = engine.inputNode
            let format = try validatedInputFormat(of: input)

            let monitor = try TapWriter(url: nil, format: format)
            try withObjCExceptionGuard {
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    monitor.append(buffer)
                }
                engine.prepare()
                try engine.start()
            }

            self.monitor = monitor
            startMeter()
        } catch {
            stopMonitoring()
            if errorMessage == nil {
                errorMessage = "Ingresso non attivo: \(error.localizedDescription)"
            }
        }
    }

    private func stopMonitoring() {
        // Nessuna guardia su `monitor`: se l'avvio del monitoraggio fallisce
        // dopo installTap, il tap resta installato con `monitor` ancora nil,
        // e va comunque rimosso (removeTap è innocuo se non c'è alcun tap).
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        monitor = nil
        stopMeter()
        levels = []
    }

    /// Da chiamare quando cambia l'interfaccia selezionata.
    func noteDeviceChanged() {
        guard !isRecording else { return }
        errorMessage = nil
        stopMonitoring()
        Task { await startMonitoring() }
    }

    // MARK: Registrazione

    /// Avvia la registrazione del microfono. Restituisce `false` se non
    /// è stato possibile partire (l'errore è in `errorMessage`).
    func startRecording() async -> Bool {
        guard !isRecording else { return false }
        errorMessage = nil

        guard await requestMicrophoneAccess() else {
            errorMessage = "Permesso al microfono negato. Abilitalo in Impostazioni di Sistema › Privacy e sicurezza › Microfono."
            return false
        }

        stopMonitoring()

        do {
            let input = engine.inputNode
            try configureEngineInput()
            let format = try validatedInputFormat(of: input)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("riunione-mic-\(UUID().uuidString).caf")
            let writer = try TapWriter(url: tempURL, format: format)

            try withObjCExceptionGuard {
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    writer.append(buffer)
                }
                engine.prepare()
                try engine.start()
            }

            self.writer = writer
            self.tempURL = tempURL
            self.startDate = Date()
            self.elapsed = 0
            self.isRecording = true
            startMeter()
            return true
        } catch {
            cleanupEngine()
            errorMessage = "Impossibile avviare la registrazione: \(error.localizedDescription)"
            await startMonitoring()
            return false
        }
    }

    /// Ferma la registrazione e restituisce il CAF temporaneo col
    /// microfono; il chiamante ne diventa proprietario (e lo elimina).
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        isRecording = false
        stopMeter()
        levels = []
        startDate = nil

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        defer { Task { await startMonitoring() } }

        guard let writer, let tempURL else { return nil }
        writer.close()
        self.writer = nil
        self.tempURL = nil
        return tempURL
    }

    // MARK: Utilità

    /// Formato con cui installare il tap sul nodo d'ingresso: quello REALE
    /// dell'hardware (`inputFormat`), mai quello del bus di uscita
    /// (`outputFormat`), che dopo un cambio di interfaccia può restare in
    /// cache col formato del dispositivo precedente e far fallire
    /// installTap con "Failed to create tap due to format mismatch".
    private func validatedInputFormat(of input: AVAudioInputNode) throws -> AVAudioFormat {
        let hardware = input.inputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
            throw RecorderError.invalidFormat
        }
        return hardware
    }

    /// Esegue `body` intercettando sia gli errori Swift sia le NSException
    /// Objective-C di AVAudioEngine: un'eccezione lasciata correre fin
    /// dentro AppKit corromperebbe lo stato della concorrenza Swift.
    private func withObjCExceptionGuard(_ body: () throws -> Void) throws {
        var swiftError: Error?
        let objcError = CBCatchObjCException {
            do { try body() } catch { swiftError = error }
        }
        if let swiftError { throw swiftError }
        if let objcError { throw objcError }
    }

    /// Instrada il nodo d'ingresso del motore verso l'interfaccia selezionata.
    private func configureEngineInput() throws {
        guard let device = selectedDevice, let audioUnit = engine.inputNode.audioUnit else { return }
        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw RecorderError.deviceSelectionFailed(status) }
        // Scarta i formati che il motore tiene in cache dal dispositivo
        // precedente: senza reset il tap fallirebbe per formato discordante.
        engine.reset()
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func startMeter() {
        stopMeter()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else { break }
                guard let source = self.writer ?? self.monitor else { break }
                let peaks = source.consumePeaks()
                if self.levels.count != peaks.count {
                    self.levels = peaks
                } else {
                    // Balistica da peak meter: attacco immediato, rilascio
                    // graduale, per una lettura stabile senza sfarfallio.
                    self.levels = zip(self.levels, peaks).map { max($1, $0 * 0.631) }
                }
                if self.isRecording, let startDate = self.startDate {
                    self.elapsed = Date().timeIntervalSince(startDate)
                }
            }
        }
    }

    private func stopMeter() {
        meterTask?.cancel()
        meterTask = nil
    }

    private func cleanupEngine() {
        stopMeter()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        writer?.close()
        writer = nil
        monitor = nil
        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        tempURL = nil
        isRecording = false
    }
}
