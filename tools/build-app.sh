#!/bin/sh
# Compile l'application et fabrique le paquet .build/Simple Nothing.app, sans le lancer.
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
app=".build/Simple Nothing.app"
res="$app/Contents/Resources"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$res"
cp tools/app-Info.plist "$app/Contents/Info.plist"
cp .build/release/SimpleNothing "$app/Contents/MacOS/SimpleNothing"
cp -R Sources/SimpleNothing/Traductions/*.lproj "$res/"

# Ce qui appartient à Nothing (images, polices) reste hors du dépôt. L'app s'en sert s'il est là,
# et montre sinon des pictogrammes et des polices du système.
# NOTHING_PUBLIC=1 construit la version à diffuser, sans rien de tout cela.
# NOTHING_SANS_POLICES=1 garde les photos mais pas vos polices : c'est l'app des visuels du README,
# avec les polices du système qu'obtient quelqu'un qui installe depuis le dépôt.
if [ -z "$NOTHING_PUBLIC" ]; then
  if [ -z "$NOTHING_SANS_POLICES" ]; then cp originaux/polices/*.otf "$res/" 2>/dev/null || true; fi
  # Vues de face : <modèle>_<couleur>.webp devient device-<MODÈLE>-<couleur>.png. La conversion est
  # gardée dans .build/images pour ne pas la refaire à chaque construction.
  mkdir -p .build/images
  for src in originaux/ear-web/*.webp; do
    [ -f "$src" ] || continue
    base=$(basename "$src" .webp)
    out=".build/images/device-$(echo "${base%%_*}" | tr a-z A-Z)-${base#*_}.png"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
      sips -s format png -Z 480 "$src" --out "$out" >/dev/null 2>&1 || continue
    fi
    cp "$out" "$res/"
  done
  # Vues de trois quarts du CMF Headphone Pro, fabriquées par tools/build-assets.swift à partir de vos propres sources.
  for pair in dark-grey:black light-grey:white light-green:green; do
    src="maquette/assets/products/cmf-headphone-pro-${pair%%:*}.png"
    if [ -f "$src" ]; then cp "$src" "$res/device-B175-${pair##*:}-34.png"; fi
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
codesign --force --sign - -r="designated => identifier \"io.github.kaizeur-io.simple-nothing\"" "$app" >/dev/null 2>&1
