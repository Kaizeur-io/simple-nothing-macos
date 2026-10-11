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
| `C041` faible latence | `4041` | `00` | `01` = activée |
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

## Écritures, d'après la documentation, pas encore essayées

Aucune écriture n'a été envoyée au casque. Ce tableau reprend ce que décrit Ear (web) ; chaque ligne reste à confirmer sur l'appareil.

| Commande | Données | Effet attendu |
|---|---|---|
| `F00F` | `01`, mode, `00` | réduction du bruit (mêmes valeurs qu'en lecture) |
| `F01D` | préréglage, `00` | égaliseur |
| `F041` | à établir | égaliseur personnalisé |
| `F052` | mode, suivi de tête | audio spatial |
| `F051` | activé, niveau | renfort des basses |
| `F040` | `01 00` activée, `02 00` désactivée | faible latence |
| `F003` | `01`, appareil, bouton, geste, action | commandes, une à la fois |
| `F01A` | `01` ou `00` | double connexion |
| `F01C` | n° de codec | codec (le casque peut redémarrer) |
| `F05C` | `01` ou `00` | profil sonore personnel |

## Reste à établir

- Le format de l'égaliseur personnalisé (`C044` / `F041`). Ear (web) donne pour ce modèle trois filtres : 140 Hz (Q 0,8), 980 Hz (Q 0,7), 3 500 Hz (Q 1,0).
- Le sens de `7C09` et `E019`.
- La liste des appareils de la double connexion (`C028`, lecture paginée).
- Le calibrage du profil sonore, qui repose chez Nothing sur un SDK tiers (Audiodo).
