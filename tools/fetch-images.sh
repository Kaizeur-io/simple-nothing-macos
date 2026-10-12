#!/bin/sh
# Va chercher les photos des appareils (vue de face, sur fond transparent) et les range dans
# originaux/ear-web/, que git ignore. tools/build-app.sh les met ensuite dans l'app.
#
# Ces images appartiennent à Nothing : elles ne sont pas dans ce dépôt. Elles viennent du dépôt public
# du projet Ear (web), à une révision figée pour que leur contenu ne puisse pas changer sous nos pieds.
# Sans réseau, ou si un fichier a disparu, l'app dessine l'appareil elle-même.
#   tools/fetch-images.sh          (environ 20 Mo, une seule fois : les fichiers déjà là sont gardés)
cd "$(dirname "$0")/.."
revision=d076e1371572fbf0a14b441f9b3cafbf9a237e04
source="https://raw.githubusercontent.com/radiance-project/ear-web/$revision/res/assets"
images="b155_black b155_white b157_white b162_black b162_white b162_yellow \
  b163_black b163_orange b163_white b164_black b164_orange b164_white \
  b168_black b168_orange b168_white b170_black b170_grey b171_black \
  b171_white b172_black b172_blue b172_orange b172_white b173_black \
  b173_white b174_blue b174_white b175_black b175_green b175_white \
  b179_black b179_green b179_orange b181_black b181_white b184_blue \
  b184_white b185_black b185_orange b185_white b186_black b186_pink \
  b186_white b189_black b189_blue b189_orange b189_white b190_black \
  b190_pink b190_white b190_yellow b192_black b192_silver"
mkdir -p originaux/ear-web
got=0
missed=0
for name in $images; do
  file="originaux/ear-web/$name.webp"
  if [ -s "$file" ]; then continue; fi
  if curl -sfL --max-time 30 -o "$file.part" "$source/${name}_duo.webp" && [ -s "$file.part" ]; then
    mv "$file.part" "$file"
    got=$((got + 1))
  else
    rm -f "$file.part"
    missed=$((missed + 1))
  fi
done
echo "Photos des appareils : $got téléchargée(s), $missed introuvable(s), $(ls originaux/ear-web/*.webp 2>/dev/null | wc -l | tr -d ' ') sur place."
