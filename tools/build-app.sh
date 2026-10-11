#!/bin/sh
# Compile l'application et fabrique le paquet .build/Nothing X.app, sans le lancer.
# Appelé par tools/app.sh (lancer) et tools/install.sh (installer).
set -e
cd "$(dirname "$0")/.."
if ! command -v swift >/dev/null 2>&1; then
  echo "Il manque les outils de développement d'Apple. Lancez « xcode-select --install », attendez la fin de l'installation, puis relancez ce script." >&2
  exit 1
fi
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
  echo "macOS 14 (Sonoma) ou plus récent est nécessaire." >&2
  exit 1
fi
if ! swift build -c release >.build-log 2>&1; then
  cat .build-log >&2
  rm -f .build-log
  exit 1
fi
rm -f .build-log
app=".build/Nothing X.app"
res="$app/Contents/Resources"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$res"
cp tools/app-Info.plist "$app/Contents/Info.plist"
cp .build/release/NothingX "$app/Contents/MacOS/NothingX"
cp -R Sources/NothingX/Traductions/*.lproj "$res/"

# Ce qui appartient à Nothing (images, polices) reste hors du dépôt. L'app s'en sert s'il est là,
# et montre sinon des pictogrammes et des polices du système.
# NOTHING_PUBLIC=1 construit la version à diffuser, sans rien de tout cela.
if [ -z "$NOTHING_PUBLIC" ]; then
  cp maquette/assets/products/cmf-headphone-pro-*.png "$res/" 2>/dev/null || true
  cp originaux/polices/*.otf "$res/" 2>/dev/null || true
  for pair in black:dark-grey white:light-grey green:light-green; do
    src="originaux/ear-web/b175_${pair%%:*}.webp"
    if [ -f "$src" ]; then sips -s format png -Z 480 "$src" --out "$res/cmf-headphone-pro-front-${pair##*:}.png" >/dev/null 2>&1; fi
  done
fi

# Icône : la vôtre si originaux/icone.png existe, sinon celle que dessine tools/make-icon.swift.
icon=originaux/icone.png
if [ ! -f "$icon" ] || [ -n "$NOTHING_PUBLIC" ]; then
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
