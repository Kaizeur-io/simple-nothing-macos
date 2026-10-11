#!/bin/sh
# Compile puis lance la sonde en lecture seule. Elle tourne comme une petite application :
# macOS n'accorde le Bluetooth qu'à une app qui déclare pourquoi elle en a besoin, et vous
# demande votre accord au premier lancement.
#   tools/probe.sh [nom de l'appareil]
set -e
cd "$(dirname "$0")/.."
app=.build/Probe.app
mkdir -p "$app/Contents/MacOS"
cp tools/probe-Info.plist "$app/Contents/Info.plist"
swiftc -O tools/probe.swift -o "$app/Contents/MacOS/probe" -framework IOBluetooth 2>&1 | grep -v warning || true
# Signature locale. L'identité est fixée sur l'identifiant de l'app : sans cela elle changerait à chaque
# compilation et macOS redemanderait l'accord Bluetooth à chaque fois.
codesign --force --sign - -r="designated => identifier \"local.nothing-mac.probe\"" "$app" >/dev/null 2>&1
out=.build/probe.log
: > "$out"
open -W -n "$app" --stdout "$PWD/$out" --stderr "$PWD/$out" --args "$@"
cat "$out"
