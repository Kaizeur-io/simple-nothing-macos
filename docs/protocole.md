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
| `C01F` égaliseur | `401F` | `00` | n° de préréglage |
| `C04F` audio spatial | `404F` | `02 00` | à décoder (l'app affichait « Mode concert ») |
| `C041` faible latence | `4041` | `00` | `01` = activée |
| `C04E` renfort des basses | `404E` | `00 00` | à décoder |
| `C018` commandes | `4018` | `04` puis 4 × 4 octets | appareil, bouton, geste, action |

Les quatre commandes reçues correspondent à ce qu'affichait l'app mobile :

| Octets | Sens |
|---|---|
| `06 0a 01 0b` | bouton, appui simple → assistant vocal |
| `06 0a 07 01` | bouton, appui long → aucune action |
| `06 05 01 23` | curseur → réglage des basses |
| `06 01 07 16` | molette, appui long → contrôle du bruit |

## Reçu sans rien demander

À l'ouverture du canal le casque envoie de lui-même `4041` (latence), `E003` (réduction du bruit), ainsi que `7C09` et `E019`, non identifiés. Après la lecture de la batterie il renvoie aussi `E001` (même contenu que `4007`).

## Reste à établir

- La correspondance entre le n° de préréglage de l'égaliseur et les noms de l'app (Pop, Rock, Électronique…).
- Le contenu des réponses audio spatial et renfort des basses.
- Toutes les écritures (`F0xx`) : aucune n'a encore été envoyée.
