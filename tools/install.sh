#!/bin/sh
# Installe l'application dans /Applications et la lance. C'est depuis cet emplacement que
# « Ouvrir au démarrage du Mac » fonctionne : l'app reste alors dans la barre des menus.
set -e
cd "$(dirname "$0")/.."
# Les photos des appareils ne sont pas dans le dépôt : on va les chercher une fois (environ 20 Mo).
# NOTHING_SANS_IMAGES=1 s'en passe ; l'app dessine alors l'appareil elle-même.
if [ -z "$NOTHING_SANS_IMAGES" ]; then tools/fetch-images.sh || true; fi
tools/build-app.sh
osascript -e 'quit app "Nothing X"' >/dev/null 2>&1 || true
rm -rf "/Applications/Nothing X.app"
cp -R ".build/Nothing X.app" "/Applications/Nothing X.app"
open "/Applications/Nothing X.app"
echo "Installée : /Applications/Nothing X.app"
