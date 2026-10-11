#!/bin/sh
# Installe l'application dans /Applications et la lance. C'est depuis cet emplacement que
# « Ouvrir au démarrage du Mac » fonctionne : l'app reste alors dans la barre des menus.
set -e
cd "$(dirname "$0")/.."
tools/build-app.sh
osascript -e 'quit app "Nothing X"' >/dev/null 2>&1 || true
rm -rf "/Applications/Nothing X.app"
cp -R ".build/Nothing X.app" "/Applications/Nothing X.app"
open "/Applications/Nothing X.app"
echo "Installée : /Applications/Nothing X.app"
