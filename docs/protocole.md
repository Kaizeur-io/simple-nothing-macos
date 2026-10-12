# Protocole : ce qui est vérifié

Relevé avec `tools/probe.sh` sur un CMF Headphone Pro (modèle B175, firmware 1.0.1.49) relié à un Mac sous macOS 26.3. La sonde n'envoie que des lectures.

Le format des trames et les numéros de commande viennent de la documentation communautaire du protocole, en particulier [Ear (web)](https://github.com/radiance-project/ear-web) et [BudsLink](https://github.com/maniacx/BudsLink). Aucun code de ces projets n'est repris ici.

## Liaison

- Bluetooth classique, RFCOMM, service `aeac4a03-dff5-498f-843a-34487cf133eb`.
- Sur ce casque le service est sur le canal 28. Le numéro se lit dans les services déclarés par l'appareil (SDP) ; il ne faut pas le coder en dur.
- Le port série que macOS crée tout seul (`/dev/cu.CMFHeadphonePro`) pointe sur un autre service (canal 12, « TOTA ») : il ne répond pas au protocole.
- macOS n'accorde le Bluetooth qu'à une application qui porte `NSBluetoothAlwaysUsageDescription` dans son `Info.plist`. Un simple exécutable lancé depuis un terminal est tué au premier appel ; d'où le petit paquet `.app` fabriqué par `tools/probe.sh`.

## Trame

```
55 60 01 | commande (2 octets, petit-boutiste) | longueur (2 octets) | séquence | données | CRC16
```

- CRC16 de type Modbus (valeur initiale `0xFFFF`, polynôme réfléchi `0xA001`) sur tout ce qui précède, octet faible en premier.
- En réponse, le CRC n'est présent que si le bit `0x20` du mot de contrôle (octets 1 et 2) est levé.
- Lectures : `0xC0xx`. Écritures : `0xF0xx`. Réponses : `0x40xx`. Notifications spontanées : `0xE0xx`.

## Lectures confirmées

| Requête | Réponse | Données reçues | Lecture |
|---|---|---|---|
| `C007` batterie | `4007` | `01 06 28` | 1 élément ; `06` = casque ; `28` = 40 % (bit `0x80` = en charge) |
| `C042` firmware | `4042` | `31 2e 30 2e 31 2e 34 39` | texte ASCII « 1.0.1.49 » |
| `C006` série | `4006` | lignes `type,rang,valeur` | rang 2 = firmware, rang 4 = n° de série, rang 6 = adresse |
| `C01E` réduction du bruit | `401E` | `01 01 00 02 01 00` | octet 1 = mode : `01` haut, `02` moyen, `03` bas, `04` adaptatif, `05` désactivée, `07` transparence |
| `C01F` égaliseur | `401F` | `00` | sans objet sur ce modèle, qui passe par `C050` |
| `C050` mode d'écoute | `4050` | `03` | préréglage de l'égaliseur, voir plus bas ; `03` = Pop, ce qu'affichait l'app |
| `C044` égaliseur personnalisé | `4044` | 109 octets nuls | aucune courbe enregistrée ; format à établir |
| `C04F` audio spatial | `404F` | `02 00` | mode, suivi de tête ; `02 00` = Concert, ce qu'affichait l'app |
| `C041` faible latence | `4041` | `00` ou `02` | `01` = activée ; `02` = désactivée après une écriture, `00` tant que rien n'a été réglé |
| `C04E` renfort des basses | `404E` | `00 00` | activé, niveau (le niveau affiché vaut la moitié de l'octet sur les modèles voisins) |
| `C018` commandes | `4018` | `04` puis 4 × 4 octets | appareil, bouton, geste, action |
| `C027` double connexion | `4027` | `01` | `01` = activée |
| `C029` codec | `4029` | `00` | `00` AAC, `01` LHDC, `02` LDAC |
| `C05A` profil sonore | `405A` | `00` | `01` = profil personnel activé |

### Préréglages de l'égaliseur

| Octet | Préréglage |
|---|---|
| `00` | Dirac Opteo (d'après Ear (web)) |
| `01` | Rock |
| `02` | Électronique |
| `03` | Pop |
| `04` | Améliorer les voix |
| `05` | Classique |
| `06` | Personnalisé |

### Audio spatial

| Octets | Mode |
|---|---|
| `00 00` | Désactivé |
| `01 00` | Fixe |
| `01 01` | Suivi de tête |
| `02 00` | Concert |
| `03 00` | Théâtre |
| `04 00` | Jeu |

Les quatre commandes reçues correspondent à ce qu'affichait l'app mobile :

| Octets | Sens |
|---|---|
| `06 0a 01 0b` | bouton, appui simple → assistant vocal |
| `06 0a 07 01` | bouton, appui long → aucune action |
| `06 05 01 23` | curseur → réglage des basses |
| `06 01 07 16` | molette, appui long → contrôle du bruit |

Geste : `01` appui simple ou glissement, `07` appui long. Bouton : `0a` bouton, `05` curseur, `01` molette.

Actions : `01` aucune, `0b` assistant vocal, `0a` `14` `15` `16` contrôle du bruit (selon les modes parcourus), `1b` audio spatial, `1d` micro coupé ou non, `1f` Essential News, `20` Channel Hop, `21` Essential Space, `22` préréglage d'égaliseur, `23` basses, `24` aigus. Le curseur n'accepte que `23` et `24`, la molette que le contrôle du bruit ou rien.

## Reçu sans rien demander

À l'ouverture du canal le casque envoie de lui-même `4041` (latence), `E003` (réduction du bruit), ainsi que `7C09` et `E019`, non identifiés. Après la lecture de la batterie il renvoie aussi `E001` (même contenu que `4007`).

## Écritures

Confirmées le 12 octobre 2026 avec `tools/app.sh --verify` : chaque valeur a été écrite, relue dans la réponse de l'appareil, puis remise en place. L'appareil accuse réception par une trame `70xx` vide (même numéro que l'écriture, bit de poids fort baissé).

| Commande | Données | Effet | État |
|---|---|---|---|
| `F00F` | `01`, mode, `00` | réduction du bruit (mêmes valeurs qu'en lecture) ; l'appareil envoie aussi `E003` | confirmé |
| `F01D` | préréglage, `00` | égaliseur | confirmé |
| `F052` | mode, suivi de tête | audio spatial | confirmé |
| `F040` | `01 00` activée, `02 00` désactivée | faible latence ; la relecture donne ensuite `01` ou `02` | confirmé |
| `F003` | `01`, appareil, bouton, geste, action | commandes, une à la fois | confirmé |
| `F01A` | `01` ou `00` | double connexion | fonctionne à l'usage, depuis l'app |
| `F01C` | n° de codec | codec (le casque peut redémarrer) | pas essayé |
| `F051` | activé, niveau | renfort des basses (niveaux `02` à `0A` par pas de 2, ou `00` `05` `0A` sur les modèles à trois crans) | pas essayé, absent du CMF Headphone Pro |
| `F05C` | `01` ou `00` | profil sonore personnel | pas essayé |
| `F041` | voir plus bas | égaliseur personnalisé | confirmé |
| `F01B` | `01` relier ou `00` détacher, puis les 6 octets de l'adresse | un des appareils de la double connexion | fonctionne à l'usage, depuis l'app |
| `F002` | casque : `06`, puis `01` ou `00` ; écouteurs : `02` gauche ou `03` droite, puis `01` ou `00` ; Ear (1) : `01` ou `00` seul | fait sonner l'appareil pour le retrouver | fonctionne à l'usage sur le casque (`06 01`) ; formats des écouteurs pas essayés |
| `F004` | `00 00`, puis `01` ou `00` | détection de port (lecture `C00E`, réponse `400E`, état au troisième octet) | pas essayé, absent du CMF Headphone Pro |

### Égaliseur personnalisé

Format décrit par Ear (web), confirmé sur l'appareil : la courbe écrite est relue à l'identique. Les nombres sont des flottants de 32 bits, petit-boutistes.

```
nombre de filtres | gain d'ensemble | pour chaque filtre : type, gain (dB), fréquence (Hz), qualité | 3 octets nuls par filtre
```

Pour ce modèle, trois filtres dans cet ordre : cloche (`01`) à 980 Hz, Q 0,7 pour les médiums ; plateau haut (`02`) à 3 500 Hz, Q 1,0 pour les aigus ; plateau bas (`00`) à 140 Hz, Q 0,8 pour les graves. Le gain d'ensemble vaut l'opposé du plus fort relèvement, pour ne pas saturer. Un casque sans courbe enregistrée répond à `C044` par 109 octets nuls ; avec une courbe, la réponse garde 109 octets, les filtres en tête, deux octets non identifiés après eux, puis des zéros.

## Double connexion

`C028` suivi d'un octet (le nombre d'appareils déjà reçus) renvoie une page de la liste dans `4028` : deux octets d'en-tête, le nombre d'appareils de la page, puis pour chacun un octet d'état (quartet haut : c'est l'appareil qui interroge ; quartet bas : il est connecté), six octets d'adresse, la longueur du nom et le nom. On redemande tant qu'une page apporte du nouveau. Format décrit par Ear (web) ; sur l'appareil la lecture a rendu quatre appareils en une page de 90 octets, et la demande suivante a renvoyé la même page.

`E00E` (un octet d'état, six d'adresse, un octet) arrive quand un appareil se relie ou part : l'app relit alors la liste. Interprétation probable, d'après la forme de la trame.

## Ce que chaque modèle sait faire

L'app ne propose un réglage que si le modèle l'a. La table (`Capabilities`, dans `Sources/NothingKit/Catalog.swift`) reprend la configuration que l'app officielle embarque pour chaque modèle : réduction du bruit, modes d'audio spatial, renfort des basses et ses crans, détection de port, sonnerie, double connexion et redémarrage éventuel quand on la change. Pour le CMF Headphone Pro : audio spatial Concert et Théâtre, sonnerie, double connexion sans redémarrage ; ni renfort des basses (le curseur d'énergie en tient lieu), ni détection de port. BudsLink annonce ces deux derniers pour ce modèle, à tort d'après la configuration officielle et d'après la réponse `00 00` à `C04E`.

## Reste à établir

- L'extinction automatique (`powerOffTime` dans la configuration officielle) : commande inconnue, absente d'Ear (web) comme de BudsLink. Il faudrait la relever dans un journal Bluetooth du téléphone pendant qu'on change ce réglage dans l'app officielle.
- Les gestes des écouteurs : l'app affiche ceux que l'appareil déclare (`C018`) et propose pour chacun les actions de la configuration officielle (`Model.actions(for:)`), mais aucun n'a été écrit sur de vrais écouteurs.

- Le sens de `7C09`, `E019` et `E002` (3 octets), reçus sans rien demander.
- Le calibrage du profil sonore, qui repose chez Nothing sur un SDK tiers (Audiodo).
