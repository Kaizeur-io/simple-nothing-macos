# Nothing X pour Mac (projet personnel, non officiel)

Une application macOS pour régler les casques et écouteurs Nothing et CMF, que l'app officielle ne couvre que sur téléphone. Ce projet n'est ni affilié à Nothing Technology, ni soutenu par elle.

## Où en est le projet

- **Maquettes interactives** : faites. Deux versions, jour et nuit, tout l'état y est simulé.
- **Protocole** : la lecture fonctionne sur un CMF Headphone Pro (batterie, firmware, réduction du bruit, commandes). Voir [docs/protocole.md](docs/protocole.md). Aucune écriture n'a encore été testée.
- **Application** : pas commencée. Les maquettes ne pilotent aucun appareil.

## Arborescence

```
maquette/        maquettes HTML/CSS/JS, sans dépendance ni étape de construction
  index.html     V1 : transposition directe de l'app mobile (tuiles et sous-pages)
  v2.html        V2 : disposition pensée pour macOS (onglets, menus déroulants, barre des menus)
  shared.js      icônes, données et briques communes aux deux
  planche.html   planche de contrôle des visuels produit
tools/
  build-assets.swift   fabrique les visuels produit à partir de vos propres sources
  probe.swift          sonde Bluetooth en lecture seule
  probe.sh             compile et lance la sonde
docs/protocole.md      ce qui est vérifié du protocole
```

## Voir les maquettes

```sh
python3 -m http.server 4173 --directory maquette
```

Puis ouvrir `http://localhost:4173/v2.html`. La barre noire en bas de page pilote la maquette (thème, appareil connecté ou non, arrivée d'un nouvel appareil) et permet de passer d'une version à l'autre.

## Images produit

Les photos des appareils appartiennent à Nothing : elles ne sont pas dans le dépôt. Tant qu'elles n'ont pas été fabriquées, les maquettes fonctionnent mais sans images. Pour les obtenir, placez vos propres fichiers dans `sources/` puis lancez le script :

- `sources/captures/` : captures d'écran de l'app mobile (1280 × 2772, nommées `26725.jpg`… comme attendu par le script) ;
- `sources/site/` : images enregistrées depuis le site Nothing.

```sh
mkdir -p .build && swiftc -O tools/build-assets.swift -o .build/build-assets && .build/build-assets
```

Le script recadre, détoure et range le tout dans `maquette/assets/`.

## Sonder un appareil

Appareil allumé et connecté au Mac en Bluetooth :

```sh
tools/probe.sh
```

La sonde n'envoie que des lectures. macOS demande l'autorisation Bluetooth au premier lancement.

## Suite prévue

1. Décoder ce qui reste (égaliseur, audio spatial), puis tester une première écriture réversible : le mode de réduction du bruit.
2. Écrire l'application native (SwiftUI) sur la base de la V2 : fenêtre, barre des menus, carte d'appairage.
3. Étendre aux autres modèles.

## Projets voisins

- [nothing-bar](https://github.com/bestK1ngArthur/nothing-bar) : une app de barre des menus pour macOS existe déjà (GPL-3.0).
- [Ear (web)](https://github.com/radiance-project/ear-web) et [BudsLink](https://github.com/maniacx/BudsLink) : sources de la documentation du protocole.

Nothing, CMF et les noms de produits sont des marques de Nothing Technology Limited.
