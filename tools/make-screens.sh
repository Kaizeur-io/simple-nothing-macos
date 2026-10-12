#!/bin/sh
# Fabrique les visuels de présentation, en anglais : prend les captures de l'app en mode démo,
# puis les compose sur un fond uni (tools/compose-screens.swift). Le fichier x.png est au format
# 16:9 pour les réseaux.
#
#   tools/make-screens.sh                 → docs/, avec la version publique de l'app (aucune image de Nothing)
#   tools/make-screens.sh <dossier>       → même chose ailleurs
#   NOTHING_COMPLET=1 tools/make-screens.sh originaux/presentation
#                                         → avec les photos et polices de originaux/, pour un usage hors dépôt
set -e
cd "$(dirname "$0")/.."
out="${1:-docs}"
shots=".build/captures"
app=".build/Simple Nothing.app"
if [ -n "$NOTHING_COMPLET" ]; then tools/build-app.sh >/dev/null; else NOTHING_PUBLIC=1 tools/build-app.sh >/dev/null; fi
rm -rf "$shots" && mkdir -p "$shots"
export NOTHING_PWD="$PWD"
shot() { open -n -W "$app" --args --demo --demo-battery 82 "$@"; }
echo "Captures…"
for theme in dark light; do
  shot "--$theme" -AppleLanguages "(en)" --section listen --snapshot "$shots/en-listen-$theme.png"
done
for section in controls link device app; do
  shot --light -AppleLanguages "(en)" --section "$section" --snapshot "$shots/en-$section-light.png"
done
shot --dark -AppleLanguages "(en)" --snapshot-menu "$shots/en-menu-dark.png"
shot --dark -AppleLanguages "(en)" --snapshot-hud "$shots/en-hud-dark.png"
shot --dark -AppleLanguages "(en)" --snapshot-toast "$shots/en-toast-dark.png"
open -n -W "$app" --args --demo --demo-battery 18 --dark -AppleLanguages "(en)" --snapshot-battery "$shots/en-battery-dark.png"
echo "Composition…"
swiftc -O tools/compose-screens.swift -o .build/compose-screens
.build/compose-screens "$shots" "$out"
