#!/bin/sh
# Compile l'application et la lance. Elle tourne comme un paquet .app : macOS n'accorde le
# Bluetooth qu'à une app qui déclare pourquoi elle en a besoin, et demande votre accord au
# premier lancement.
#   tools/app.sh [options de lancement, voir Sources/NothingX/NothingXApp.swift]
set -e
cd "$(dirname "$0")/.."
swift build -c release 2>&1 | grep -E "error|warning|Compiling|Build" || true
app=".build/Nothing X.app"
res="$app/Contents/Resources"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$res"
cp tools/app-Info.plist "$app/Contents/Info.plist"
cp .build/release/NothingX "$app/Contents/MacOS/NothingX"
cp -R Sources/NothingX/Traductions/*.lproj "$res/"

# Ce qui appartient à Nothing (images, polices) reste hors du dépôt. L'app s'en sert s'il est là,
# et montre sinon des pictogrammes et des polices du système.
cp maquette/assets/products/cmf-headphone-pro-*.png "$res/" 2>/dev/null || true
cp originaux/polices/*.otf "$res/" 2>/dev/null || true
for pair in black:dark-grey white:light-grey green:light-green; do
  src="originaux/ear-web/b175_${pair%%:*}.webp"
  if [ -f "$src" ]; then sips -s format png -Z 480 "$src" --out "$res/cmf-headphone-pro-front-${pair##*:}.png" >/dev/null 2>&1; fi
done

# Icône : la vôtre si originaux/icone.png existe, sinon celle que dessine tools/make-icon.swift.
icon=originaux/icone.png
if [ ! -f "$icon" ]; then
  icon=.build/icone.png
  if [ ! -f "$icon" ] || [ tools/make-icon.swift -nt "$icon" ]; then
    swiftc tools/make-icon.swift -o .build/make-icon && .build/make-icon "$icon"
  fi
fi
set=.build/AppIcon.iconset
rm -rf "$set" && mkdir -p "$set"
for size in 16 32 128 256 512; do
  sips -z $size $size "$icon" --out "$set/icon_${size}x${size}.png" >/dev/null 2>&1
  sips -z $((size * 2)) $((size * 2)) "$icon" --out "$set/icon_${size}x${size}@2x.png" >/dev/null 2>&1
done
iconutil -c icns "$set" -o "$res/AppIcon.icns"

# Signature locale. L'identité est fixée sur l'identifiant de l'app : sans cela elle changerait à chaque
# compilation et macOS redemanderait l'accord Bluetooth à chaque fois.
codesign --force --sign - -r="designated => identifier \"local.nothing-mac.app\"" "$app" >/dev/null 2>&1
open -n "$app" --args "$@"
