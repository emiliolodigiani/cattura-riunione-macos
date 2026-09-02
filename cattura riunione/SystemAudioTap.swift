//
//  SystemAudioTap.swift
//  cattura riunione
//
//  Cattura l'audio riprodotto dalle altre app (le voci dei partecipanti
//  a una call) con un process tap di Core Audio: tap globale su tutti i
//  processi → dispositivo aggregato privato → IOProc che scrive su CAF
//  e misura i picchi per il misuratore di livello. Può anche solo
//  monitorare (nessun file), per mostrare il livello prima di
//  registrare. Il primo avvio fa comparire la richiesta di sistema
//  "registrazione dell'audio di sistema" (NSAudioCaptureUsageDescription).
//

import AudioToolbox
import CoreAudio
import Foundation

/// Picchi per canale condivisi tra il thread audio e la UI, con la
/// stessa logica di TapWriter (ultimo valore valido tra due letture).
nonisolated final class MisuratorePicchi: @unchecked Sendable {
    private let lock = NSLock()
    private var picchi: [Float]
    private var picchiTenuti: [Float]
    private var freschi = false

    init(canali: Int) {
        picchi = [Float](repeating: 0, count: canali)
        picchiTenuti = picchi
    }

    /// Da chiamare sul thread audio: campiona un buffer interleaved
    /// Float32 (passo 8 per non pesare sul tempo reale).
    func misura(_ lista: UnsafePointer<AudioBufferList>, canali: Int, bytesPerFrame: UInt32) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: lista))
        guard canali > 0, bytesPerFrame > 0,
              let primo = buffers.first, let dati = primo.mData else { return }
        let frames = Int(primo.mDataByteSize / bytesPerFrame)
        let campioni = dati.assumingMemoryBound(to: Float.self)
        var locali = [Float](repeating: 0, count: canali)
        var frame = 0
        while frame < frames {
            for canale in 0..<canali {
                let valore = abs(campioni[frame * canali + canale])
                if valore > locali[canale] { locali[canale] = valore }
            }
            frame += 8
        }

        lock.lock()
        if picchi.count == canali {
            for canale in 0..<canali where locali[canale] > picchi[canale] {
                picchi[canale] = locali[canale]
            }
            freschi = true
        }
        lock.unlock()
    }

    func consuma() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        if freschi {
            picchiTenuti = picchi
            picchi = [Float](repeating: 0, count: picchi.count)
            freschi = false
        }
        return picchiTenuti
    }
}

final class SystemAudioTap {

    nonisolated enum Errore: LocalizedError {
        case creazioneTap(OSStatus)
        case formatoTap(OSStatus)
        case dispositivoAggregato(OSStatus)
        case ioProc(OSStatus)
        case file(OSStatus)

        var errorDescription: String? {
            switch self {
            case .creazioneTap(let s): "Cattura dell'audio di sistema negata o non disponibile (\(s))."
            case .formatoTap(let s): "Formato del tap di sistema non leggibile (\(s))."
            case .dispositivoAggregato(let s): "Creazione del dispositivo di cattura fallita (\(s))."
            case .ioProc(let s): "Avvio della cattura di sistema fallito (\(s))."
            case .file(let s): "Creazione del file per l'audio di sistema fallita (\(s))."
            }
        }
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregatoID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var file: ExtAudioFileRef?
    private var misuratore: MisuratorePicchi?
    private(set) var url: URL?

    /// Avvia il tap in solo monitoraggio: nessun file, solo i picchi
    /// per il misuratore di livello.
    func avviaMonitoraggio() throws {
        try configura(conFile: false)
    }

    /// Crea tap, dispositivo aggregato e file, e avvia la cattura.
    /// Restituisce l'URL del CAF temporaneo in scrittura.
    func avvia() throws -> URL {
        try configura(conFile: true)
        return url!
    }

    private func configura(conFile: Bool) throws {
        ferma()

        // 1. Tap globale: mixdown stereo di tutti i processi.
        let descrizione = CATapDescription(stereoMixdownOfProcesses: [])
        descrizione.isPrivate = true
        var nuovoTap = AudioObjectID(kAudioObjectUnknown)
        var stato = AudioHardwareCreateProcessTap(descrizione, &nuovoTap)
        guard stato == noErr else { throw Errore.creazioneTap(stato) }
        tapID = nuovoTap

        // 2. Formato dell'audio prodotto dal tap.
        var indirizzo = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var dimensione = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        stato = AudioObjectGetPropertyData(tapID, &indirizzo, 0, nil, &dimensione, &asbd)
        guard stato == noErr else { ferma(); throw Errore.formatoTap(stato) }
        let bytesPerFrame = asbd.mBytesPerFrame

        // 3. Dispositivo aggregato privato che contiene solo il tap.
        let composizione: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Cattura Riunione — audio di sistema",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: descrizione.uuid.uuidString]
            ],
        ]
        var nuovoAggregato = AudioObjectID(kAudioObjectUnknown)
        stato = AudioHardwareCreateAggregateDevice(composizione as CFDictionary, &nuovoAggregato)
        guard stato == noErr else { ferma(); throw Errore.dispositivoAggregato(stato) }
        aggregatoID = nuovoAggregato

        // 4. Solo in registrazione: file CAF temporaneo nel formato del tap.
        var fileLocale: ExtAudioFileRef?
        if conFile {
            let destinazione = FileManager.default.temporaryDirectory
                .appendingPathComponent("riunione-sistema-\(UUID().uuidString).caf")
            stato = ExtAudioFileCreateWithURL(
                destinazione as CFURL, kAudioFileCAFType, &asbd, nil,
                AudioFileFlags.eraseFile.rawValue, &fileLocale
            )
            guard stato == noErr, let nuovoFile = fileLocale else { ferma(); throw Errore.file(stato) }
            stato = ExtAudioFileSetProperty(
                nuovoFile, kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &asbd
            )
            guard stato == noErr else { ExtAudioFileDispose(nuovoFile); ferma(); throw Errore.file(stato) }
            ExtAudioFileWriteAsync(nuovoFile, 0, nil) // innesca la coda asincrona
            file = nuovoFile
            url = destinazione
        }

        // I picchi si misurano solo se il formato è il Float32
        // interleaved atteso dal mixdown del tap.
        let interleavedFloat32 = asbd.mFormatID == kAudioFormatLinearPCM
            && asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
            && asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
            && asbd.mBitsPerChannel == 32
        let misuratore = interleavedFloat32
            ? MisuratorePicchi(canali: Int(asbd.mChannelsPerFrame)) : nil
        self.misuratore = misuratore

        // 5. IOProc: copia l'ingresso del dispositivo aggregato sul file
        //    (se c'è) e aggiorna i picchi.
        let fileCatturato = file
        let canali = Int(asbd.mChannelsPerFrame)
        stato = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregatoID, nil) {
            _, ingresso, _, _, _ in
            if let fileCatturato, bytesPerFrame > 0 {
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ingresso))
                if let primo = buffers.first {
                    let frames = primo.mDataByteSize / bytesPerFrame
                    if frames > 0 {
                        ExtAudioFileWriteAsync(fileCatturato, frames, ingresso)
                    }
                }
            }
            misuratore?.misura(ingresso, canali: canali, bytesPerFrame: bytesPerFrame)
        }
        guard stato == noErr, let ioProcID else { ferma(); throw Errore.ioProc(stato) }
        stato = AudioDeviceStart(aggregatoID, ioProcID)
        guard stato == noErr else { ferma(); throw Errore.ioProc(stato) }
    }

    /// I picchi per canale dall'ultima lettura (vuoto se il tap è fermo).
    func consumaPicchi() -> [Float] {
        misuratore?.consuma() ?? []
    }

    /// Ferma la cattura e rilascia tap, dispositivo e file (idempotente).
    func ferma() {
        if let ioProcID, aggregatoID != kAudioObjectUnknown {
            AudioDeviceStop(aggregatoID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregatoID, ioProcID)
        }
        ioProcID = nil
        if aggregatoID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregatoID)
            aggregatoID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        if let file {
            ExtAudioFileDispose(file)
            self.file = nil
        }
        misuratore = nil
        url = nil
    }
}
