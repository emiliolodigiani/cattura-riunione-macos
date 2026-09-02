#!/bin/sh
# Build Release per tutti gli Apple Silicon (arm64, M1 in poi).
#
# L'override globale ARCHS=arm64 vale anche per i pacchetti Swift, che
# in Release compilerebbero universali con le proprie impostazioni:
# risparmia la fetta x86_64, inutile perché l'app è solo Apple Silicon.
# (Con FluidAudio fino alla 0.15.6 era anche l'unico modo di compilare:
# Float16 non esiste su Intel; dalla revisione agganciata nel progetto
# non è più obbligatorio.)
set -e
cd "$(dirname "$0")/.."
exec xcodebuild -project "cattura riunione.xcodeproj" \
  -scheme "Cattura Riunione" -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build ARCHS=arm64 build
