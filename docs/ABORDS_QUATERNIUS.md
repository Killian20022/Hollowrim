# Abords et enceinte : props Quaternius (branche gen/abords, 2026-11-04)

Base 491ccd18 (props/lot4). Uniquement des props DÉJÀ convertis (`assets/crypte/modules/props_quaternius.dat`, API `PropsQuaternius`,
fichier non modifié). Méthode de docs/PROPS_REMPLACEMENT.md : fondu dans les maillages existants, aucun nœud par prop, collisions conservées.

Interrupteur : `-- --abords-anciens` rend les anciennes pièces maison (aussi avec `--sans-remplacement` / `--sans-lot4`).
Code : `scripts/abords_q.gd` (`AbordsQ.actif`, `vers_maillage`, `mesh_fondu`, `base_segment`).
Captures : `bash outils/captures_gen_abords.sh <dossier> [--abords-anciens]` (poses `outils/poses_gen_abords.txt`).

| Endroit | Avant (maison) | Après (Quaternius) | Détail |
|---|---|---|---|
| sentier d'entrée (`abords_village.gd`) | rochers polyèdres facettés | q_roc_1-4 (Medieval Dungeon, lot 4) | même emprise (sx, sy, sz), fondus dans `_pierre` (texture de granit, teinte froide), faces du dessus en neige (alpha 0) ; congères, touffes, collisions inchangées |
| barrières de l'entrée + clôtures des champs (`_barriere`, hérité par RuesVillage) | piquets + 2 lisses en rondins, neige posée | travées q_barriere_bois / q_barriere_ext_2 d'un piquet au suivant, pente suivie | dans `_bois` (texture de rondin, UV en mètres) : RuesVillage les dessine sans changement de son fichier ; le code maison tourne toujours (mêmes tirages de `rng`, mêmes collisions de piquets, congères, touffes) mais ses rondins et sa neige vont dans des maillages jetés |
| buissons, touffes | gardés | — | aucune plante convertie (Ultimate Nature : seulement bûche et souche) |
| abords du tumulus (`abords_tumulus.gd`) | rochers maison, pierres de bordure (boîtes enneigées) | q_roc_1-4, q_bordure_1/2 relevées en blocs bas | deux maillages (RochersQ, BordureQ) au lieu de 14 MeshInstance ; mêmes tirages, mêmes emprises |
| cercle runique (`cercle_runique.gd`) | 6 rochers bas, 3 os en boîtes | q_roc_1-4 ; os épars = q_os_tas_2 (Bones2 : fémurs et côtes étalés) | le tas q_os_tas (« en boule ») n'est PAS utilisé ; bois de cerf gardé (pas d'équivalent) |
| camp des bandits (`grotte_acces.gd`) | 5 pieux isolés | chevaux de frise : longrine + paires de pieux croisés en X (q_poutre_ronde) | collisions inchangées |
| | foyer éteint : cailloux, bûches, tas d'os maison | couronne q_roc, q_feu_bois noirci (`@bois`), q_os_tas_2 | |
| | étendard : perches + boîte de peau | perches q_poutre_ronde + tissu q_banniere_toile en matière « peau » | |
| | portique (poteaux, linteau, jambes de force) | q_poutre_ronde | lanterne et lumières validées gardées |
| | cairns (3 rochers maison) | 3 q_roc empilés (roche givrée) | collision du bas gardée |
| | — | q_piege_ours tendu sur la terrasse (nouveau) | via `GrotteDecor.q4` |
| | crânes sur piques | **gardés** | module validé g_trophee + crâne anatomique (q_crane rejeté au lot 4 : « boule ») |

## Gardé, et pourquoi

- **Palissade du village** (`village.gd` `_palissade_v2`, `_pieu_taille`, `_liens_v2`) : GARDÉE. Les seules pièces converties
  (q_palissade, _bout, _angle) sont le muret de PIERRE du Modular Dungeon (1,3 m, moellons beiges) : ni rondins, ni pieux taillés,
  ni nordique. Rien d'aussi bon dans la liste ; les pieux bas taillés restent l'identité du village.
- **Grilles d'eau** : gardées (pieux fins dans le lit, pas d'équivalent ; q_pieux est un hérisson de pointes de fer de donjon).
- **Forge fermée** (`_forge`) : gardée. C'est du bâti (murs, toit, vantaux interactifs) ; les props de la liste n'en remplacent aucune
  pièce sans la dégrader. `village.gd` n'est pas modifié.
- Pierre levée, menhirs, stèle, borne runique, portes à têtes de dragon, lanternes, dalles et butte : gardés (consigne).
