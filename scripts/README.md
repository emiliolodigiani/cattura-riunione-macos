# Script di build e pubblicazione

Tutti si lanciano dalla radice del repo (ma funzionano da qualsiasi
cartella: i percorsi relativi valgono da dove li invochi).

## Flusso completo di una release

1. In Xcode: **Product > Archive**, poi dall'Organizer **Distribute App**
   per la notarizzazione e infine **Export Notarized App** (per esempio
   in `~/Downloads`).
2. Pubblica su GitHub:

   ```sh
   scripts/pubblica-release.sh "/percorso/di/Cattura Riunione.app"
   ```

   Lo script verifica il sigillo di notarizzazione (rifiuta l'app se
   manca), confeziona il DMG con `crea-dmg.sh`, allinea `main` sul
   remoto e crea la release `v<versione>` (la versione viene
   dall'Info.plist, es. `v1.0.36`) con il DMG come asset. Se la release
   esiste già, sostituisce soltanto l'asset.

Per vedere cosa farebbe senza pubblicare nulla:

```sh
scripts/pubblica-release.sh --prova "/percorso/di/Cattura Riunione.app"
```

Accetta anche un `.dmg` o `.zip` già pronti (versione ricavata dal nome
del file, es. `Cattura Riunione 1.0.36.dmg`):

```sh
scripts/pubblica-release.sh "/percorso/di/Cattura Riunione 1.0.36.dmg"
```

Prerequisiti: [gh](https://cli.github.com) autenticata (`gh auth login`)
e [create-dmg](https://github.com/create-dmg/create-dmg)
(`brew install create-dmg`).

## Gli script uno per uno

- **`pubblica-release.sh [--prova] <app|dmg|zip>`** — pubblica una build
  notarizzata come release su GitHub (vedi sopra).
- **`crea-dmg.sh <app> [dmg-di-uscita]`** — solo il DMG di
  distribuzione (icona a sinistra, alias di Applicazioni a destra);
  senza secondo argomento nasce accanto all'app come
  `Cattura Riunione 1.0.36.dmg`.
- **`compila-release.sh`** — build Release da riga di comando
  (solo arm64), senza archiviare né pubblicare.
