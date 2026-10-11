#!/bin/sh
# Compile l'application et la lance. Elle tourne comme un paquet .app : macOS n'accorde le
# Bluetooth qu'à une app qui déclare pourquoi elle en a besoin, et demande votre accord au
# premier lancement.
#   tools/app.sh [options de lancement, voir Sources/NothingX/NothingXApp.swift]
set -e
cd "$(dirname "$0")/.."
swift build -c release 2>&1 | grep -E "error|warning|Compiling|Build" || true
app=".build/Nothing X.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp tools/app-Info.plist "$app/Contents/Info.plist"
cp .build/release/NothingX "$app/Contents/MacOS/NothingX"
# Les images produit appartiennent à Nothing et restent hors du dépôt : sans elles, l'app montre un pictogramme.
cp maquette/assets/products/cmf-headphone-pro-*.png "$app/Contents/Resources/" 2>/dev/null || true
codesign --force --sign - "$app" >/dev/null 2>&1
open -n "$app" --args "$@"
