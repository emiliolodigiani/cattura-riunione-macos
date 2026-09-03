#!/bin/bash
#
# Pubblica una build notarizzata come release su GitHub (repo origin).
#
# Uso: scripts/pubblica-release.sh [--prova] "/percorso/di/Cattura Riunione.app"
#      scripts/pubblica-release.sh [--prova] "/percorso/di/Cattura Riunione 1.0.35.dmg"
#
# Con una .app (di solito l'esportazione dell'Organizer con "Export
# Notarized App") verifica il sigillo di notarizzazione e la comprime
# in uno zip; con un .dmg o .zip già pronti carica quelli. Il numero di
# versione viene dall'Info.plist (o dal nome del file per dmg/zip) e
# diventa l'etichetta della release: v1.0.35. Con --prova prepara tutto
# ma mostra soltanto i comandi di pubblicazione senza eseguirli.
#
set -euo pipefail

PROVA=0
if [ "${1:-}" = "--prova" ]; then PROVA=1; shift; fi
ART="${1:?Indica il percorso della .app notarizzata (o di un .dmg/.zip)}"
# Percorso assoluto prima di spostarsi nella radice del repo (dove
# git e gh devono girare), altrimenti i percorsi relativi si perdono.
case "$ART" in /*) ;; *) ART="$PWD/$ART" ;; esac
cd "$(dirname "$0")/.."

NOME="Cattura Riunione"
case "$ART" in

  *.app)
    # Senza sigillo niente release: Gatekeeper rifiuterebbe l'app
    # scaricata. L'esportazione giusta è quella dell'Organizer dopo
    # la notarizzazione ("Export Notarized App").
    if ! xcrun stapler validate "$ART" >/dev/null 2>&1; then
      echo "ERRORE: \"$ART\" non ha il sigillo di notarizzazione." >&2
      echo "Esporta l'app dall'Organizer con \"Export Notarized App\" dopo la notarizzazione." >&2
      exit 1
    fi
    echo "Sigillo di notarizzazione verificato."
    VERSIONE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ART/Contents/Info.plist")"
    # Lo zip con ditto preserva firma e metadati; il nome senza spazi
    # perché GitHub li sostituirebbe con dei punti.
    ASSET="$(dirname "$ART")/Cattura-Riunione-$VERSIONE.zip"
    rm -f "$ASSET"
    ditto -c -k --sequesterRsrc --keepParent "$ART" "$ASSET"
    echo "Creato: $ASSET"
    ;;

  *.dmg|*.zip)
    VERSIONE="$(basename "$ART" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)"
    if [ -z "$VERSIONE" ]; then
      echo "ERRORE: non trovo la versione nel nome \"$(basename "$ART")\": serve tipo \"… 1.0.35.dmg\"." >&2
      exit 1
    fi
    ASSET="$(dirname "$ART")/Cattura-Riunione-$VERSIONE.${ART##*.}"
    [ "$ASSET" = "$ART" ] || cp -f "$ART" "$ASSET"
    ;;

  *)
    echo "ERRORE: formato non riconosciuto (accetto .app, .dmg, .zip)." >&2
    exit 1
    ;;
esac

TAG="v$VERSIONE"
if [ "$PROVA" = 1 ]; then
  echo "Prova: pubblicherei $ASSET come release $TAG con:"
  echo "  git push origin main"
  echo "  gh release create $TAG \"$ASSET\" --target main --title \"$NOME $VERSIONE\" --notes \"Build notarizzata di $NOME $VERSIONE.\""
  exit 0
fi

# La release etichetta il main remoto: prima si allinea il sorgente.
git push origin main

if gh release view "$TAG" >/dev/null 2>&1; then
  # Release già esistente: si sostituisce soltanto l'asset.
  gh release upload "$TAG" "$ASSET" --clobber
  echo "Asset aggiornato sulla release esistente $TAG."
else
  gh release create "$TAG" "$ASSET" --target main \
    --title "$NOME $VERSIONE" \
    --notes "Build notarizzata di $NOME $VERSIONE."
fi
