#!/bin/sh
# Installe l'application dans /Applications et la lance. C'est depuis cet emplacement que
# « Ouvrir au démarrage du Mac » fonctionne : l'app reste alors dans la barre des menus.
set -e
cd "$(dirname "$0")/.."
# Les photos des appareils ne sont pas dans le dépôt : on va les chercher une fois (environ 20 Mo).
# NOTHING_SANS_IMAGES=1 s'en passe ; l'app dessine alors l'appareil elle-même.
if [ -z "$NOTHING_SANS_IMAGES" ]; then tools/fetch-images.sh || true; fi
tools/build-app.sh
osascript -e 'quit app "Simple Nothing"' >/dev/null 2>&1 || true
# L'app refuse de tourner en double : on attend que l'ancienne copie ait vraiment fini de se fermer.
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -xq SimpleNothing || break; sleep 0.5; done
rm -rf "/Applications/Simple Nothing.app"
cp -R ".build/Simple Nothing.app" "/Applications/Simple Nothing.app"
open "/Applications/Simple Nothing.app"
echo "Installée : /Applications/Simple Nothing.app"
