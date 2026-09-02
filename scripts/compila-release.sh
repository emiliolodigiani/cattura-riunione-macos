#!/bin/sh
# Build Release per tutti gli Apple Silicon (arm64, M1 in poi).
#
# Serve questo script perché da Xcode la destinazione generica («Any
# Mac», anche nella variante arm64) compila i pacchetti Swift ANCHE per
# x86_64, e FluidAudio su Intel non compila (usa Float16). L'override
# ARCHS da riga di comando è globale e vale anche per i pacchetti:
# è l'unico modo di fare una build generica di questo progetto.
set -e
cd "$(dirname "$0")/.."
exec xcodebuild -project "cattura riunione.xcodeproj" \
  -scheme "Cattura Riunione" -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build ARCHS=arm64 build
