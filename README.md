# Cattura Riunione

App macOS (15+, Apple Silicon) che registra riunioni — microfono e, per
le call, audio di sistema — e produce il verbale con trascrizione e
divisione dei parlanti. Tutto avviene in locale: dopo il primo
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
di destinazione, con `riunione.m4a`, `trascrizione.json`, `verbale.md`.

## Sviluppo

Progetto Xcode standard: `cattura riunione.xcodeproj`, schema
«Cattura Riunione». Test: `xcodebuild … test`. Le convenzioni del
progetto sono in `CLAUDE.md`; specifica e piano in `docs/superpowers/`.
