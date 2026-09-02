# Cattura Riunione — specifica di progetto

Data: 2 settembre 2026
Stato: approvata (design discusso e approvato in conversazione)

## Scopo

App macOS nativa per registrare riunioni e produrne il verbale: trascrizione
automatica con divisione dei parlanti (diarizzazione), tutta in locale, senza
Python né servizi esterni. Riusa l'impianto di registrazione già collaudato
dell'app "cattura brano" (`~/workspace/cattura brano`).

## Requisiti

1. **Registrazione riunioni in presenza**: dal microfono selezionato, come in
   cattura brano.
2. **Registrazione call online**: cattura anche l'audio di sistema (le voci
   degli altri partecipanti in Zoom/Meet/Teams) tramite i *process tap* di
   Core Audio.
3. **Importazione di file esistenti**: trascinamento o pannello Apri per
   trascrivere un file audio già registrato (wav, m4a, mp3, caf, aiff).
4. **Trascrizione in post-elaborazione** (mai live): a fine registrazione o
   su file importato, con diarizzazione dei parlanti.
5. **Verbale nell'app**: lista degli interventi «Parlante N (hh:mm:ss) —
   testo», con:
   - rinomina dei parlanti («Parlante 2» → «Mario») aggiornata ovunque;
   - riascolto sincronizzato: clic su un intervento → l'audio riparte da lì;
   - esportazione in Markdown e copia negli appunti.
6. **Riapertura delle riunioni passate** dalla cartella di destinazione.
7. **Tutto locale**: dopo il primo scaricamento dei modelli l'app funziona
   offline. Nessun dato audio o testo lascia il Mac.

## Fuori perimetro (YAGNI)

- Trascrizione live durante la riunione.
- Riconoscimento della stessa voce tra riunioni diverse (impronte vocali).
- Riassunti o elaborazioni AI del verbale.
- Localizzazione: l'app è solo in italiano (la trascrizione riconosce le
  lingue supportate da Parakeet v3, italiano incluso).
- Distribuzione su App Store (l'app non è sandboxed, come cattura brano).

## Piattaforma e dipendenze

- macOS 14+ (la cattura dell'audio di sistema richiede le API dei
  process tap, macOS 14.2+; su 14.0/14.1 degrada a solo microfono),
  solo Apple Silicon, da M1 in poi. [Requisito aggiornato dall'utente
  il 2/9/2026: in origine macOS 15+.]
- SwiftUI + AVFoundation/Core Audio, progetto Xcode formato moderno
  (objectVersion 77, cartelle sincronizzate) derivato da quello di
  cattura brano.
- Unica dipendenza esterna: **FluidAudio** (Swift Package,
  `https://github.com/FluidInference/FluidAudio`, licenza Apache 2.0) per
  ASR (Parakeet TDT v3, multilingue) e diarizzazione (modelli Core ML).
  I modelli (~1 GB) vengono scaricati da Hugging Face al primo utilizzo e
  conservati in locale.
- Bundle id: `it.emiliolodigiani.cattura-riunione`. Hardened runtime, non
  sandboxed, entitlement `com.apple.security.device.audio-input`.

## Architettura

### Componenti riusati da cattura brano (copiati e adattati)

- `AudioRecorder` — AVAudioEngine sul formato hardware del microfono
  (incluso il fix del tap sul formato reale) e protezione dalle NSException
  (`ObjCExceptionCatcher`).
- `AudioInputDevice` — enumerazione e scelta del dispositivo di ingresso.
- `OutputFolderStore` — cartella di destinazione persistita con bookmark.
- Pattern di `SettingsView` e struttura generale dell'app SwiftUI.

Non servono: LAME/MP3, aubio/BeatDetector, Demucs.

### Componenti nuovi

1. **`SystemAudioTap`** — cattura dell'audio di sistema con i process tap di
   Core Audio (`CATapDescription` + `AudioHardwareCreateProcessTap` +
   dispositivo aggregato). Richiede `NSAudioCaptureUsageDescription`
   (permesso TCC "registrazione solo audio di sistema", meno invasivo della
   registrazione schermo). Scrive su file WAV proprio, avviato insieme al
   microfono. Se nessuna app riproduce audio, registra silenzio: innocuo.
2. **`MeetingRecorder`** — orchestrazione: avvia/ferma insieme
   `AudioRecorder` (mic → `microfono.wav`) e `SystemAudioTap`
   (sistema → `sistema.wav`); a fine registrazione miscela i due file in
   un'unica traccia mono e la codifica in `riunione.m4a` (AAC) per
   l'archivio. La miscelazione è una somma campione per campione con
   normalizzazione se necessario (i due file partono insieme; eventuali
   piccole derive di clock sono irrilevanti ai fini della trascrizione).
3. **`TranscriptionEngine`** — pipeline FluidAudio in post-elaborazione:
   - conversione dell'audio a 16 kHz mono (AVAudioConverter);
   - diarizzazione → turni di parola `{parlante, inizio, fine}`;
   - trascrizione ASR → testo con timestamp;
   - fusione per timestamp → `[Intervento]` (vedi modello dati).
   Riporta l'avanzamento (fasi + percentuale) per la UI.
4. **`ModelStore`** — stato dei modelli Core ML: presenti / da scaricare /
   scaricamento in corso (con avanzamento) / errore di rete con ritento.
   L'equivalente concettuale di `DemucsInstaller`, ma senza passi manuali.
5. **Modello dati e persistenza** — una riunione è una cartella
   `Riunione AAAA-MM-GG HH.mm/` nella cartella di destinazione:
   - `riunione.m4a` — audio archiviato;
   - `trascrizione.json` — struttura `Trascrizione` (versione del formato,
     durata, elenco `Intervento {idParlante, inizio, fine, testo}`, mappa
     `nomiParlanti {idParlante: nome}`);
   - `verbale.md` — esportazione Markdown rigenerata a ogni modifica dei
     nomi.
   I WAV intermedi vivono in una cartella temporanea e vengono eliminati a
   elaborazione conclusa.
6. **UI** (SwiftUI):
   - finestra principale: scelta ingresso, livello, Registra/Ferma, stato
     dell'elaborazione; elenco delle riunioni passate; zona di trascinamento
     per importare file;
   - vista verbale: lista interventi, rinomina parlante (doppio clic sul
     nome), riproduzione sincronizzata (AVAudioPlayer + evidenziazione
     dell'intervento corrente), Esporta/Copia;
   - Impostazioni (⌘,): cartella di destinazione, dispositivo di ingresso,
     cattura audio di sistema sì/no.

### Flusso dati

```
mic ──AudioRecorder──▶ microfono.wav ─┐
                                       ├─ mix ─▶ riunione.m4a ─▶ riproduzione
sistema ─SystemAudioTap─▶ sistema.wav ─┘         │
                                                 ▼ 16 kHz mono
file importato ──────────────────────────────▶ TranscriptionEngine
                                                 │ diarizzazione + ASR + fusione
                                                 ▼
                                     trascrizione.json ◀──▶ UI verbale
                                                 │ rinomina, export
                                                 ▼
                                             verbale.md
```

## Gestione errori

- **Permesso microfono negato** → istruzioni per Impostazioni di Sistema
  (come cattura brano).
- **Permesso audio di sistema negato** → la registrazione prosegue col solo
  microfono, con avviso chiaro.
- **Primo avvio senza rete** → messaggio esplicito e pulsante di ritento;
  registrare è comunque possibile, la trascrizione parte quando i modelli
  ci sono (la riunione resta in stato "da trascrivere").
- **NSException di AVAudioEngine/Core Audio** → intercettate con
  `ObjCExceptionCatcher`, mai crash dell'app.
- **File importato non decodificabile** → errore leggibile, nessuna cartella
  creata.
- **Interruzione dell'app durante l'elaborazione** → la cartella della
  riunione con l'audio resta valida; la trascrizione si può rilanciare.

## Test

- Unit test (XCTest) sulla logica pura, senza audio reale:
  - fusione diarizzazione+ASR (casi: sovrapposizioni, turni senza testo,
    testo fuori dai turni);
  - modello `Trascrizione`: codifica/decodifica JSON, rinomina parlanti;
  - esportazione Markdown.
- La registrazione, il tap di sistema e la pipeline Core ML si verificano
  con una prova reale guidata a fine implementazione (registrazione breve
  con due voci + una call di prova).

## Decisioni già prese

- App indipendente da cattura brano: sorgenti copiati, non condivisi.
- Trascrizione solo in post-elaborazione.
- Nome: **cattura riunione**; cartella `~/workspace/cattura riunione`.
- Commit frequenti in italiano, senza chiedere conferma, dopo ogni blocco
  di modifiche verificato (preferenza consolidata dell'utente).
