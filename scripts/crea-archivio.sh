#!/bin/sh
# Archivio Release per la distribuzione (Organizer di Xcode).
#
# Product > Archive da Xcode NON può funzionare: l'azione di archivio
# usa la destinazione generica e i pacchetti Swift compilano ANCHE per
# x86_64 ignorando ogni impostazione del progetto, e FluidAudio su
# Intel non compila (usa Float16). Come per compila-release.sh, l'unico
# rimedio è l'override globale ARCHS da riga di comando.
#
# L'archivio finisce nella cartella degli archivi di Xcode, così appare
# nell'Organizer (Window > Organizer) pronto per «Distribute App».
set -e
cd "$(dirname "$0")/.."
ARCHIVIO="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/Cattura Riunione $(date "+%d-%m-%Y, %H.%M").xcarchive"
exec xcodebuild -project "cattura riunione.xcodeproj" \
  -scheme "Cattura Riunione" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build ARCHS=arm64 \
  -archivePath "$ARCHIVIO" archive
