#!/bin/sh
# Compile l'application et la lance depuis le dossier du projet. Elle tourne comme un paquet .app :
# macOS n'accorde le Bluetooth qu'à une app qui déclare pourquoi elle en a besoin, et demande votre
# accord au premier lancement.
#   tools/app.sh [options de lancement, voir Sources/SimpleNothing/SimpleNothingApp.swift]
set -e
# Une app lancée par « open » démarre à la racine du disque : on lui dit d'où vient la commande,
# pour qu'un chemin relatif (rapport, capture) arrive là où on l'attend.
here=$PWD
cd "$(dirname "$0")/.."
tools/build-app.sh
open -n ".build/Simple Nothing.app" --env "NOTHING_PWD=$here" --args "$@"
