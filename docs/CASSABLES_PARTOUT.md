# Cassables partout (2026-11-23, branche monde/cassables_partout)

Demande : « que quasiment tous les objets puissent se casser » (télékinésie : on saisit un objet, on le lance). Ce chantier rend le
mobilier léger et les petits objets PHYSIQUES, saisissables (groupe `telekinesable`) et CASSABLES par choc. Le sort lui-même
(saisie, lancer), les dégâts des objets lancés (ImpactsLances), le sang et la lumière sont d'autres branches.

## Contrats (brief commun)

| Contrat | Où | Comportement |
|---|---|---|
| groupe `telekinesable` | `ObjetVivant._init` | tous les objets vivants (petits objets ET mobilier léger) ; rien avec `--sans-cassables-partout` |
| `masse_telekinesie() -> float` | `ObjetVivant` | la vraie masse (kg) : tonneau 31-40, banc ~22, caisse 16-26, chaise 6, tabouret 4, jarre 4-9, sac 25 |
| `saisi_telekinesie(saisi)` | `ObjetVivant` | réveillé même coincé dans le décor (`reveiller(true)`), ne se rendort pas tant qu'il est tenu ; relâché : se rendort à l'arrêt |
| `recevoir_choc(vitesse, masse, point) -> bool` | `ObjetVivant`, `Cassable` (crypte/grotte) | énergie ½·m·v² contre le seuil de la matière ; vrai si brisé ; sous le seuil : son de choc (bois qui cogne, fer qui sonne) |

## Matières et seuils (`CasseObjets.MATIERES`)

| Matière | Seuil | Exemples | Découpe |
|---|---|---|---|
| œuf | 1,2 J | œufs | tessons (3) |
| verre | 4 J | bouteilles d'hydromel, potions | tessons (5) |
| poterie | 14 J | cruches, pots d'argile, jarres, urnes de la crypte | tessons : 4 secteurs × 2 étages (7) |
| bois léger | 80 J | tabourets, chaises, cageots | composantes (pieds, assise, dossier) puis planches (7) |
| bois | 200 J | caisses, bancs, caisses de la crypte | planches (8) |
| tonneau | 300 J | tonneaux | DOUELLES (8 secteurs verticaux) + cerclages entiers (11) |
| bois ferré | 350 J | caisses cerclées de fer | planches (9) |
| fer, tissu, nourriture | ∞ | assiettes d'étain, chandeliers, seaux de fer, sacs, vivres | jamais : ils rebondissent (son) |

Repères : une chope (0,4 kg) qui heurte un tonneau à 1,5 m/s = 0,5 J (rien) ; un coup d'épée léger = 60 J (jarre, cruche brisées ;
tonneau non) ; un puissant = 160 J (cageot, chaise brisés) ; un objet de 12 kg lancé à 9 m/s = 486 J (tonneau brisé). Une chute
casse aussi : à chaque contact d'un objet éveillé, l'énergie PERDUE (½·m·Δv²) est comparée au seuil (une cruche qui tombe d'une
étagère se brise, pas un tonneau qui bascule).

## Ce qui se passe à la casse

- l'instance du MultiMesh disparaît, la collision est retirée, ce qui reposait dessus retombe (`reveiller_voisins`) ;
- VRAIS morceaux : le modèle est découpé (une fois par modèle, dans un FIL DE FOND dès la pose : `CasseObjets.preparer`) en
  composantes connexes puis tranché selon la matière ; chaque morceau garde les matériaux et UV du modèle (pq_* texturés) ;
- éclats = RigidBody3D boîte, calque 0 / masque 1 (le décor seulement : ni le joueur, ni les PNJ, ni entre eux), gelés (statiques)
  dès qu'ils sont posés 2,5 s, ou à plus de 30 m, ou après 12 s ; effacés (rétrécis) après 40 s ; jamais plus de 64 dans le monde ;
- gerbe de gros pixels de la matière (nouveaux profils `poterie`, `verre`, `oeuf`, `liquide` de GerbePixels), poussière, son par
  matière (sons CC0 « 75 CC0 breaking/falling/hit SFX » et « 100 CC0 SFX », OpenGameArt, copiés en `assets/sons/casse_*.ogg`) ;
- contenu : caisse et tonneau versent une petite bourse (tables « caisse », « tonneau » de data/butin/contenants.json, tirage à
  graine fixe, « premier arrivé » en coop via ReseauLieux.reclamer) ; tonneau (sauf de pommes) et jarre : liquide qui gicle + flaque
  qui s'étale puis sèche (~14 s) ;
- bien d'un PNJ (meta « proprietaire » héritée : intérieurs, réserves des étals) : `crime.signaler_vol(objet, propriétaire, position)`,
  comme un vol (témoins, prime). Déplacer un objet possédé n'est PAS un crime (règle existante des objets vivants) ;
- sauvegarde : clé « casse » dans `ObjetsVivants.etats` (exportée avec les objets pris/déplacés) ; relu brisé sans effets ; partie
  neuve : l'objet revient entier ;
- coop : évènement `objet_casse` (ident, point, vitesse) ; l'hôte relaie aux autres invités ; chacun rejoue morceaux et effets.

## Inventaire (classement)

Compté par `outils/test_cassables_partout.gd` (partie neuve, village prêt). (a) = petit objet libre, (b) = mobilier léger cassable,
(c) = gros mobilier FIXE.

| Lieu | (b) mobilier léger physique | (a) petits objets libres (déjà vivants) |
|---|---|---|
| Halle de Gunnar | 20 (tonneaux, tabourets, chaise, bancs, jarres, cageots) | ~60, dont cruches/bouteilles fragiles |
| Maisons (Sigrún 5, chasseurs 5, Grima 8) | 18 | vaisselle, vivres, potions, livres |
| Forge de Brodd | 8 (tonneaux, cageots, sac, banc, tabouret, caisse ferrée) | seaux, marmite, outils |
| Place et ruelles (MobilierVillage POSES/POSES_D) | 40 (tonneaux, caisses, bancs, sacs) | — |
| Marché (réserves des 3 étals, biens des marchands) | 17 | denrées des étals |
| Abords (24 compositions : charrette, récoltes, camp de chasseur, réserve des bandits, postes de garde, établis, quai de pêche…) | 48 | — |
| **Total au démarrage** | **151** | **228** (dont 45 fragiles) |

Les bâtiments ouverts (fermes, ateliers) passent par `Interieurs.q` : leur mobilier léger devient physique quand ils sont posés.
Crypte et grotte : 40 cassables de la grotte et ceux de la crypte (urnes, tonneaux, caisses : `Cassable`) prennent `recevoir_choc`.

### (c) Gros mobilier fixe (reste du décor : navigation des PNJ, rien à faire)

Tables (Interieurs.table : grandes tables, tables ovales, établis), lits, coffres (fermés à clé ou non : coffres de butin du monde),
armoires, étagères (à arche, simples, à fioles), lutrins, porte-manteaux, râteliers, enclumes et billots, chaudrons, puits, étals
(comptoirs), charrettes, tas de bois, tentes, bannières, braseros, murs et bâti. Ils ne sont pas des corps rigides : la télékinésie
ne les voit pas (pas dans le groupe), ce qui revient au refus « Trop lourd. ».

### Non couverts (limites)

- props posés par `PropsQuaternius.village` / `Village._tonneau` (coin d'abreuvoir de l'enclos d'Ylva, tonneau de la ferme) et par
  `CrypteDonjon` (caisse et tabouret du donjon) : restent fondus dans le décor ;
- urnes, tonneaux et caisses de la crypte et de la grotte (`Cassable`) : cassent par `recevoir_choc` (seuils ci-dessus) mais restent
  des StaticBody : la télékinésie ne peut pas les SAISIR (pas dans le groupe) ;
- les petits objets non fragiles (chopes, écuelles, livres, nourriture) ne cassent pas (ils rebondissent) ;
- coop : la trajectoire d'un objet poussé n'est pas répliquée (comme avant ce chantier) ; seule la casse l'est.

## Perf

Mesures `outils/audit_mesure_lieu.gd` (fenêtre hors écran, 12 s, midi), A/B ENTRELACÉS `--sans-cassables-partout` / normal,
machine très chargée par les autres agents (les valeurs absolues sont basses, seul l'écart compte) : voir le rapport du chantier.
- au repos : 0 corps physique actif (tout est gelé) ; casse mesurée en jeu (fenêtre) : 2 à 9 ms pour un objet (éclats 0,6-3 ms,
  effets 1-5 ms ; découpe préparée dans un fil de fond à la pose) ; calcul des témoins (vol) reporté à l'image suivante ;
- éclats : plafond 64, gelés en ~3 s, effacés à 40 s ;
- chargement : la place ne fond plus ses meubles (MobilierVillage 44 992 triangles fondus au lieu de 92 092) ; MultiMesh par modèle
  (+~20 appels de dessin dans la halle, +~50 sur la place avec les ombres des meubles).

## Interrupteur

`-- --sans-cassables-partout` : le mobilier reste fondu dans le décor avec ses anciens solides, rien ne casse, rien n'entre dans le
groupe `telekinesable` (les petits objets vivants restent comme avant).
