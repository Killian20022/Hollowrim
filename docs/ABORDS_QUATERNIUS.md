# Abords et enceinte : props Quaternius (branche gen/abords, 2026-11-04)

Base 491ccd18 (props/lot4). Uniquement des props DÉJÀ convertis (`assets/crypte/modules/props_quaternius.dat`, API `PropsQuaternius`,
fichier non modifié). Méthode de docs/PROPS_REMPLACEMENT.md : fondu dans les maillages existants, aucun nœud par prop, collisions conservées.
Décision de l'utilisateur (même jour) : seuls les objets FABRIQUÉS sont remplacés ; la nature maison (rochers, buissons, touffes, os,
cairns) est plus naturelle que celle de Quaternius (« jouet », « pâte à modeler ») et reste telle quelle.

Interrupteur : `-- --abords-anciens` rend les anciennes pièces maison (aussi avec `--sans-remplacement` / `--sans-lot4`).
Code : `scripts/abords_q.gd` (`AbordsQ.actif`, `vers_maillage`, `mesh_fondu`, `base_segment`).
Captures : `bash outils/captures_gen_abords.sh <dossier> [--abords-anciens]` (poses `outils/poses_gen_abords.txt`).

## Remplacé

| Endroit | Avant (maison) | Après (Quaternius) | Détail |
|---|---|---|---|
| barrières de l'entrée + clôtures des champs (`AbordsVillage._barriere`, héritée par RuesVillage) | piquets + 2 lisses en rondins | travées q_barriere_bois / q_barriere_ext_2 (Medieval Village) d'un piquet au suivant, pente suivie ; neige posée sur la lisse haute et calottes sur les montants | dans `_bois` (texture de rondin, UV en mètres) : RuesVillage les dessine sans changer son fichier. Le code maison tourne toujours (mêmes tirages de `rng`, mêmes collisions de piquets, congères, touffes) mais ses rondins et sa neige vont dans des maillages jetés ; la neige des travées a son propre générateur |
| camp des bandits (`grotte_acces.gd`) | 5 pieux isolés | chevaux de frise : longrine + paires de pieux croisés en X (q_poutre_ronde) | collisions inchangées |
| | étendard : perches + boîte de peau | perches q_poutre_ronde + tissu q_banniere_toile en matière « peau » | |
| | portique (poteaux, linteau, jambes de force) | q_poutre_ronde | lanterne et lumières validées gardées |
| | — | q_piege_ours tendu sur la terrasse (nouveau, `GrotteDecor.q4`) | |

Les props de l'entrée de la grotte n'emploient que des matières déjà présentes (fer, bois, peau) : une matière neuve (fer_mat) lancerait un
chargement de texture attendu sous FilVerrou par le fil de construction.

## Gardé, et pourquoi

- Rochers (entrée, tumulus, cercle runique, foyer, cairns), buissons, touffes, os épars du cercle : décision de l'utilisateur (voir plus haut).
  Les essais (q_roc_1-4, q_os_tas_2) sont retirés du code.
- Bordure du tumulus : gardée (essai q_bordure_1/2 retiré : aucun gain visible en vue de jeu).
- Foyer éteint de la grotte : gardé (enfoui sous la congère de la terrasse, l'échange ne se voyait pas).
- Crânes sur piques : module validé g_trophee + crâne anatomique (q_crane rejeté au lot 4 : « boule »).
- **Palissade du village** (`village.gd` `_palissade_v2`, `_pieu_taille`, `_liens_v2`) : GARDÉE. Les seules pièces converties
  (q_palissade, _bout, _angle) sont le muret de PIERRE du Modular Dungeon (1,3 m, moellons beiges) : ni rondins, ni pieux taillés,
  ni nordique. Les pieux bas taillés restent l'identité du village.
- **Grilles d'eau** : gardées (q_pieux est un hérisson de pointes de fer de donjon, pas une grille de pieux dans un lit).
- **Forge fermée** (`_forge`) : gardée. C'est du bâti (murs, toit, vantaux interactifs) ; aucune pièce de la liste ne la remplace sans
  la dégrader. `village.gd` n'est pas modifié.
- Pierre levée, menhirs, stèle, borne runique, portes à têtes de dragon, lanternes, dalles et butte : gardés (consigne).
