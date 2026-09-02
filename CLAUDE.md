# cattura riunione

App macOS nativa (SwiftUI, macOS 15+, Apple Silicon) che registra riunioni —
microfono + audio di sistema per le call — e produce il verbale con
trascrizione e divisione dei parlanti, tutto in locale via FluidAudio.

## Documenti guida

- **Specifica** (che cosa costruire, architettura, decisioni prese):
  `docs/superpowers/specs/2026-09-02-cattura-riunione-design.md`
- **Piano di implementazione** (in che ordine, con che verifiche):
  `docs/superpowers/plans/2026-09-02-cattura-riunione-piano.md`

Leggi entrambi prima di scrivere codice. La specifica è approvata: non
rimetterla in discussione; se emerge un ostacolo reale, fermati e segnalalo.

## Progetto gemello di riferimento

`~/workspace/cattura brano` è l'app da cui questa deriva. Da lì si copiano
(adattandoli) `AudioRecorder`, `AudioInputDevice`, `OutputFolderStore`,
`ObjCExceptionCatcher.h/.m` + bridging header, e il pattern di
`SettingsView`. Il suo `project.pbxproj` (objectVersion 77, cartelle
sincronizzate) è il modello per generare il progetto Xcode di questa app.
Non modificare MAI nulla dentro `~/workspace/cattura brano`.

## Convenzioni

- **Tutto in italiano**: commenti, stringhe UI, nomi dei documenti, messaggi
  di commit. Stile dei commenti come in cattura brano: un'intestazione che
  spiega il *perché* del file, commenti solo dove il codice non basta.
- Nomi dei tipi in inglese (Swift idiomatico: `MeetingRecorder`,
  `TranscriptionEngine`), testo per l'utente in italiano.
- Messaggi di commit come nella cronologia di cattura brano: riga breve
  descrittiva in italiano (es. «Tap sul formato hardware reale: …»).
- **Commit dopo ogni blocco di modifiche verificato, senza chiedere
  conferma.**
- Concurrency: `@MainActor` + `@Observable` per lo stato UI, come in
  cattura brano.

## Compilazione e test

```sh
# compila (Debug)
xcodebuild -project "cattura riunione.xcodeproj" -scheme "Cattura Riunione" \
  -configuration Debug -derivedDataPath build build

# test unitari
xcodebuild -project "cattura riunione.xcodeproj" -scheme "Cattura Riunione" \
  -destination 'platform=macOS' -derivedDataPath build test

# In Xcode la destinazione dev'essere «Il mio Mac»: con «Any Mac
# (Apple Silicon, Intel)» i pacchetti compilano anche x86_64 e
# FluidAudio non compila (usa Float16, inesistente su Intel).
# Stessa ragione per cui la build Release da riga di comando vuole
# ARCHS=arm64 globale: i pacchetti Swift in Release compilano
# universali con le PROPRIE impostazioni.
xcodebuild -project "cattura riunione.xcodeproj" -scheme "Cattura Riunione" \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build ARCHS=arm64 build
```

Il progetto deve sempre restare apribile e compilabile da Xcode: niente
generatori esterni, il `.pbxproj` si scrive a mano partendo da quello di
cattura brano.

## Punti delicati (leggere prima di toccarli)

- **AVAudioEngine**: installare i tap sul formato hardware reale del
  dispositivo, non su un formato imposto (lezione già pagata in cattura
  brano, commit `8ae56f5`); avvolgere le chiamate che possono lanciare
  NSException con `ObjCExceptionCatcher`.
- **Audio di sistema**: process tap di Core Audio (`CATapDescription` +
  `AudioHardwareCreateProcessTap` + dispositivo aggregato), con
  `NSAudioCaptureUsageDescription` nell'Info.plist. Se il permesso manca,
  degradare al solo microfono con avviso, mai bloccare la registrazione.
- **FluidAudio**: i modelli si scaricano da Hugging Face al primo uso
  (~1 GB); ogni percorso di codice deve reggere l'assenza dei modelli e
  l'assenza di rete.
- I file grezzi della registrazione (CAF temporanei) si eliminano a fine
  elaborazione. Nella cartella della riunione restano `riunione.m4a`
  (mix per riascolto/esportazione), `trascrizione.json`, il verbale
  «Nome riunione - verbale.md» (il nome segue le rinomine) e,
  per le registrazioni doppie (microfono + audio di sistema), anche
  `microfono.m4a` e `sistema.m4a`: alimentano la diarizzazione separata
  per traccia, molto più affidabile di quella sul mix.
