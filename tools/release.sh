#!/bin/sh
# Fabrique l'archive à diffuser : l'app sans aucune image ni police de Nothing, zippée.
#   tools/release.sh            ->  .build/NothingX-<version>.zip
# L'archive n'est ni signée par un compte développeur ni notarisée : au premier lancement, macOS
# demandera de confirmer dans Réglages Système > Confidentialité et sécurité.
set -e
cd "$(dirname "$0")/.."
NOTHING_PUBLIC=1 tools/build-app.sh
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" tools/app-Info.plist)
zip=".build/NothingX-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent ".build/Nothing X.app" "$zip"
echo "Archive : $zip ($(du -h "$zip" | cut -f1 | tr -d ' '))"
ls ".build/Nothing X.app/Contents/Resources"
