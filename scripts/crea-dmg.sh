#!/bin/bash
#
# Crea il DMG di distribuzione di Cattura Riunione: icona dell'app a
# sinistra, freccia e alias della cartella Applicazioni a destra
# (adattato da cattura brano).
#
# Uso: scripts/crea-dmg.sh "/percorso/di/Cattura Riunione.app" [dmg-di-uscita]
# (di solito l'app esportata dall'Organizer con "Export Notarized App";
# senza secondo argomento il DMG nasce accanto all'app come
# "Cattura Riunione 1.0.36.dmg")
#
set -euo pipefail

APP="${1:?Indica il percorso di \"Cattura Riunione.app\"}"
OUT="${2:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Versione e numero di build letti dall'app, per il nome del file e del
# volume. Il numero di build va aggiunto solo se la versione non lo
# contiene già (lo schema attuale produce versioni tipo "1.0.36" con
# progressivo incluso).
PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || true)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || true)"
NAME="Cattura Riunione"
VOLNAME="Cattura Riunione"
if [ -n "$VERSION" ]; then
  NAME="$NAME $VERSION"
  VOLNAME="$VOLNAME $VERSION"
  if [ -n "$BUILD" ] && [ "${VERSION##*.}" != "$BUILD" ]; then
    NAME="$NAME ($BUILD)"
  fi
fi
[ -n "$OUT" ] || OUT="$(dirname "$APP")/$NAME.dmg"

rm -f "$OUT"
create-dmg \
  --volname "$VOLNAME" \
  --background "$DIR/dmg-sfondo.png" \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "Cattura Riunione.app" 165 200 \
  --app-drop-link 495 200 \
  --hide-extension "Cattura Riunione.app" \
  "$OUT" "$APP"

echo "Creato: $OUT"
