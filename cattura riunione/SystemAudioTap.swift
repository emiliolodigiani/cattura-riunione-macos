//
//  SystemAudioTap.swift
//  cattura riunione
//
//  Cattura l'audio riprodotto dalle altre app (le voci dei partecipanti
//  a una call) con un process tap di Core Audio: tap globale su tutti i
//  processi → dispositivo aggregato privato → IOProc che scrive su CAF.
//  Il primo avvio fa comparire la richiesta di sistema "registrazione
//  dell'audio di sistema" (NSAudioCaptureUsageDescription).
//

import AudioToolbox
import CoreAudio
import Foundation

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
    private var bytesPerFrame: UInt32 = 0
    private(set) var url: URL?

    /// Crea tap, dispositivo aggregato e file, e avvia la cattura.
    /// Restituisce l'URL del CAF temporaneo in scrittura.
    func avvia() throws -> URL {
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
        bytesPerFrame = asbd.mBytesPerFrame

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

        // 4. File CAF temporaneo nel formato del tap.
        let destinazione = FileManager.default.temporaryDirectory
            .appendingPathComponent("riunione-sistema-\(UUID().uuidString).caf")
        var nuovoFile: ExtAudioFileRef?
        stato = ExtAudioFileCreateWithURL(
            destinazione as CFURL, kAudioFileCAFType, &asbd, nil,
            AudioFileFlags.eraseFile.rawValue, &nuovoFile
        )
        guard stato == noErr, let nuovoFile else { ferma(); throw Errore.file(stato) }
        stato = ExtAudioFileSetProperty(
            nuovoFile, kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &asbd
        )
        guard stato == noErr else { ferma(); throw Errore.file(stato) }
        ExtAudioFileWriteAsync(nuovoFile, 0, nil) // innesca la coda asincrona
        file = nuovoFile

        // 5. IOProc: copia l'ingresso del dispositivo aggregato sul file.
        let fileLocale = nuovoFile
        let bpf = bytesPerFrame
        stato = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregatoID, nil) {
            _, ingresso, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ingresso))
            guard let primo = buffers.first, bpf > 0 else { return }
            let frames = primo.mDataByteSize / bpf
            if frames > 0 {
                ExtAudioFileWriteAsync(fileLocale, frames, ingresso)
            }
        }
        guard stato == noErr, let ioProcID else { ferma(); throw Errore.ioProc(stato) }
        stato = AudioDeviceStart(aggregatoID, ioProcID)
        guard stato == noErr else { ferma(); throw Errore.ioProc(stato) }

        url = destinazione
        return destinazione
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
    }
}
