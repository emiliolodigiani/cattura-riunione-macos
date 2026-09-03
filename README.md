# Cattura Riunione

App macOS (14+, Apple Silicon da M1 in poi) che registra riunioni —
microfono e, per le call, audio di sistema (macOS 14.2+) — e produce il
verbale con trascrizione e divisione dei parlanti. Tutto avviene in locale: dopo il primo
scaricamento dei modelli (~1 GB da Hugging Face) non serve la rete.

## Come funziona

1. **Registra**: microfono e/o uscite del Mac (audio di sistema, via
   process tap di Core Audio) — anche una sola delle due sorgenti. Allo
   stop nasce il mix normalizzato `riunione.m4a`; con entrambe le
   sorgenti restano anche le tracce separate `microfono.m4a` e
   `sistema.m4a`.
2. **Trascrive**: diarizzazione (chi parla e quando) e trascrizione
   (Parakeet TDT v3, italiano incluso) con FluidAudio/Core ML. Con le
   tracce separate ogni traccia viene diarizzata per conto suo: chi
   parla al microfono non si confonde mai con le voci della call.
3. **Verbale**: interventi per parlante con orari; rinomina dei
   parlanti, riascolto sincronizzato, esportazione Markdown.

Ogni riunione è una cartella `Riunione AAAA-MM-GG HH.mm` nella cartella
di destinazione, con `riunione.m4a`, `trascrizione.json` e il verbale
`Nome riunione - verbale.md`, riconoscibile anche copiato altrove.

## Installazione

Il DMG notarizzato è nella pagina delle
[Release](https://github.com/emiliolodigiani/cattura-riunione-macos/releases):
aprirlo e trascinare l'app in Applicazioni. Requisiti: macOS 14 o
successivo (audio di sistema da 14.2), Mac con Apple Silicon.

## Uso responsabile

Usa l'app **sempre nel rispetto della legge**. Le norme su registrazioni,
privacy e consenso cambiano da paese a paese: informati e rispettale.
In particolare **non registrare persone che non sanno di essere
registrate**: avvisa sempre i partecipanti alla riunione e ottieni il
loro consenso prima di avviare la registrazione.

L'autore **declina ogni responsabilità** per usi impropri o illeciti
dell'app e per qualsiasi danno o conseguenza derivante dal suo uso.

## Licenza

© 2026 Emilio Lodigiani. Distribuita con licenza
[GNU GPL v3](LICENSE): software libero — chiunque può usarlo,
studiarlo, modificarlo e ridistribuirlo, ma le versioni ridistribuite
devono restare libere sotto la stessa licenza, sorgenti compresi. Il
software è fornito «così com'è», **senza garanzie di alcun tipo**,
espresse o implicite, e l'uso è a esclusivo rischio di chi lo utilizza.

Trascrizione e diarizzazione usano
[FluidAudio](https://github.com/FluidInference/FluidAudio)
(licenza Apache 2.0, compatibile con la GPL v3); i relativi modelli si
scaricano da Hugging Face al primo uso, con le condizioni delle
rispettive schede.

## Sviluppo

Progetto Xcode standard: `cattura riunione.xcodeproj`, schema
«Cattura Riunione». Test: `xcodebuild … test`. Le convenzioni del
progetto sono in `CLAUDE.md`; specifica e piano in `docs/superpowers/`.
