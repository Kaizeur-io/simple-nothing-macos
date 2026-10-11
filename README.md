# Nothing X pour Mac (projet personnel, non officiel)

Une application macOS pour régler les casques et écouteurs Nothing et CMF, que l'app officielle ne couvre que sur téléphone. Ce projet n'est ni affilié à Nothing Technology, ni soutenu par elle.

## Où en est le projet

- **Maquettes interactives** : faites. Deux versions, jour et nuit, tout l'état y est simulé.
- **Protocole** : la lecture fonctionne sur un CMF Headphone Pro (batterie, firmware, réduction du bruit, égaliseur, audio spatial, commandes, double connexion, codec). Voir [docs/protocole.md](docs/protocole.md). Les réglages aussi : mode de bruit, égaliseur, audio spatial, faible latence et commandes ont été écrits, relus et remis en place sur l'appareil.
- **Application** : première version. Elle détecte l'appareil relié au Mac, affiche son état réel dans la fenêtre et dans la barre des menus, et envoie les réglages. Seul le CMF Headphone Pro a été vérifié.

## Arborescence

```
Sources/
  NothingKit/    le protocole : trames, commandes, état de l'appareil (sans dépendance, testé)
  NothingX/      l'application SwiftUI : liaison Bluetooth, fenêtre, barre des menus
    Traductions/ l'anglais (les textes de l'app sont écrits en français)
Tests/           tests de NothingKit, à partir d'octets relevés sur un vrai casque
maquette/        maquettes HTML/CSS/JS, sans dépendance ni étape de construction
  index.html     V1 : transposition directe de l'app mobile (tuiles et sous-pages)
  v2.html        V2 : disposition pensée pour macOS (onglets, menus déroulants, barre des menus)
  shared.js      icônes, données et briques communes aux deux
  planche.html   planche de contrôle des visuels produit
tools/
  app.sh               compile l'application, l'emballe en .app et la lance
  make-icon.swift      dessine l'icône de l'application
  build-assets.swift   fabrique les visuels produit à partir de vos propres sources
  probe.swift          sonde Bluetooth en lecture seule
  probe.sh             compile et lance la sonde
docs/protocole.md      ce qui est vérifié du protocole
```

## Lancer l'application

Il suffit des outils en ligne de commande d'Apple (`xcode-select --install`), Xcode n'est pas nécessaire.

```sh
tools/app.sh
```

macOS demande l'autorisation Bluetooth au premier lancement. Sans appareil sous la main, `tools/app.sh --demo` montre l'app avec un état factice. Les tests se lancent avec `swift test`.

L'app suit la langue du système : français, ou anglais pour toutes les autres langues. Pour forcer l'anglais : `tools/app.sh -AppleLanguages "(en)"`.

Chaque réglage envoyé est suivi d'une relecture : l'écran montre ce que l'appareil a réellement retenu.

### Confirmer les réglages sur un appareil

```sh
tools/app.sh --verify rapport.txt
```

L'app modifie tour à tour le mode de bruit, l'égaliseur, l'audio spatial, la faible latence et une commande, relit la réponse de l'appareil, remet chaque valeur d'origine, puis écrit le résultat dans `rapport.txt` (ignoré par git : il contient les trames brutes). C'est le moyen de savoir ce qui marche sur un modèle qui n'a pas encore été vérifié.

## Voir les maquettes

```sh
python3 -m http.server 4173 --directory maquette
```

Puis ouvrir `http://localhost:4173/v2.html`. La barre noire en bas de page pilote la maquette (thème, appareil connecté ou non, arrivée d'un nouvel appareil) et permet de passer d'une version à l'autre.

## Ce qui reste hors du dépôt

Les photos des appareils et les polices appartiennent à Nothing (et à Lineto pour Lettera Mono) : elles ne sont pas dans le dépôt. Sans elles tout fonctionne, avec des pictogrammes et des polices de remplacement. Pour retrouver l'aspect d'origine sur votre machine, placez vos propres fichiers dans `originaux/`, que git ignore :

| Dossier | Contenu | Utilisé par |
|---|---|---|
| `originaux/captures/` | captures d'écran de l'app mobile (1280 × 2772, nommées `26725.jpg`… comme attendu par le script) | maquettes |
| `originaux/site/` | images enregistrées depuis le site Nothing | maquettes, fenêtre de l'app |
| `originaux/ear-web/` | `b175_black.webp`, `b175_white.webp`, `b175_green.webp` : le casque vu de face | barre des menus |
| `originaux/polices/` | `NType82-Headline.otf`, `LetteraMono-LL.otf`, `NDot-55.otf` | maquettes et app |
| `originaux/icone.png` | une icône carrée de votre choix | app, à la place de l'icône fournie |

Les visuels des maquettes se fabriquent ensuite avec :

```sh
mkdir -p .build && swiftc -O tools/build-assets.swift -o .build/build-assets && .build/build-assets
```

Le script recadre, détoure et range le tout dans `maquette/assets/`. `tools/app.sh` prend de son côté ce dont l'app a besoin à chaque construction.

## Sonder un appareil

Appareil allumé et connecté au Mac en Bluetooth :

```sh
tools/probe.sh
```

La sonde n'envoie que des lectures. macOS demande l'autorisation Bluetooth au premier lancement.

## Suite prévue

1. Confirmer les écritures restantes (double connexion, renfort des basses).
2. Compléter l'application : égaliseur personnalisé, carte d'arrivée d'un nouvel appareil, raccourci clavier global, liste de la double connexion.
3. Étendre aux autres modèles, dont les capacités diffèrent.

## Projets voisins

- [nothing-bar](https://github.com/bestK1ngArthur/nothing-bar) : une app de barre des menus pour macOS existe déjà (GPL-3.0).
- [Ear (web)](https://github.com/radiance-project/ear-web) et [BudsLink](https://github.com/maniacx/BudsLink) : sources de la documentation du protocole.

Nothing, CMF et les noms de produits sont des marques de Nothing Technology Limited.
