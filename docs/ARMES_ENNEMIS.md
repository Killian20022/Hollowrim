# Armes des ennemis (vraies armes du catalogue)

Les ennemis ne tiennent plus des boîtes de fer ni des mains vides : ils portent des armes du **catalogue**
(`data/armes/catalogue_armes.json`), les mêmes objets que le joueur peut trouver, vendre et équiper.

| Fichier | Rôle |
|---|---|
| `data/armes/armes_ennemis.json` | Données : profils (tirage pondéré), usure, réglages de prise, bornes d'équilibrage, armes uniques |
| `scripts/armes_ennemis.gd` (`ArmesEnnemis`) | Tirage, instanciation, prise, stats de combat, chute au sol |
| `scripts/arme_aplomb_tripo.gd` | Garde l'arme dans l'axe naturel de la main (déjà celui de l'épée des draugrs Tripo) |
| `assets/modeles/armes/integrees/hd/gourdin.*`, `sources_blender/scripts/gourdin.py` | Gourdin noueux (1 260 triangles), catalogue famille « masse » |
| `outils/test_armes_ennemis.gd` | Test (`bash outils/tous_les_tests.sh test_armes_ennemis`) |
| `outils/captures_armes_ennemis.gd`, `outils/film_armes_ennemis.gd` | Planches (en jeu, vraie crypte) et film 3e personne |

## Qui tient quoi

| Ennemi | Profil | Armes (poids) |
|---|---|---|
| Draugr (sbire) | `draugr` | épée de soldat 4, hache de guerre 3, masse cloutée 2, hachette 2 |
| Draugr ancien (type guerrier) | `draugr_ancien` | hache de guerre 4, épée de soldat 3, marteau de guerre 2, masse cloutée 1 |
| Squelette | `squelette` | épée de soldat 4 (rouillée), gourdin 3, hachette 3 |
| Bandit | `bandit` | hachette 3, gourdin 3, sabre de pillard 3, masse cloutée 2 |
| Bandit casqué (costaud) | `bandit_costaud` | hache de guerre 4, masse cloutée 2, marteau de guerre 1 |
| Gobelin | `gobelin` | dague d'acier 4, gourdin 1 |
| Jarl Kolbeinn | `jarl` | hache de Kolbeinn (unique : hache de guerre teintée givre) |
| Archers (draugr, squelette, bandit) | – | arc (inchangé, `ChasseresseNordique.equiper_arc`) |
| Hrafn, Svanhild | – | inchangés (épée de leur corps) |
| Zombie, mages, troll, bêtes | – | mains nues / sort / griffes (inchangés) |

Aucune arme précieuse (or, verre, rubis, obsidienne, saphir) chez les ennemis communs : le test le vérifie.

## Tirage

`ArmesEnnemis.tirer(profil, ident)` : graine = `ident + "|arme"`. Un même ennemi tient donc la même arme à chaque partie, après
chargement d'une sauvegarde et sur sa dépouille couchée (`Draugr.spec_depouille` contient l'ident). Le tirage a sa propre graine :
il ne décale aucun des tirages existants (casque, tenue, état du draugr). Sans ident, tirage propre à chaque appel.

## Prise

- Corps Tripo (draugr, squelette, gobelin, jarl) : même chaîne que l'épée d'avant : `EnnemiTripo.PRISE` (base), poing MESURÉ sur
  le maillage de `hand_r` (`EnnemiTripo.centre_poing`), échelle `ECH_ARME`. Le repère `prise` de la scène de l'arme est posé au poing
  (`origine = poing - axe_Y * prise.y`).
- Bandits (corps `GuerrierNordique`) : poing fixe de l'épée qu'ils tenaient (`ArmesEnnemis.centre_fixe`).
- `ArmeAplombTripo` : au repos et en marche la tête / la pointe vise une direction (`cible`), jamais « en broche » à l'horizontale ;
  pendant les coups (`Sword_Attack`, `Punch_Cross`, `Zombie_*`), la mort et les réactions, l'arme est rendue au clip.
  L'épée pointe vers l'avant et le bas (valeur d'origine) ; les armes d'hast (hache, hachette, masse, marteau, gourdin) ont la tête
  levée en diagonale (`cible` et `limite` dans `armes_ennemis.json`, par famille ou par arme ; `torsion` tourne l'arme autour de son axe).
- Les clips d'attaque sont ceux d'origine (captures Mixamo des ennemis) : aucune clé de pose écrite à la main.

## Combat

`Draugr._armer_catalogue` (sauf chefs) : dégâts × rapport des dégâts de l'arme à ceux de l'épée de soldat, rythme des gestes × rapport
des vitesses, portée du corps à corps = `PORTEE` + écart de portée de l'arme / 2 ; tout borné par `equilibre` du JSON (dégâts 0,8-1,35,
rythme 0,8-1,12, portée ±0,2 m). La hache de guerre est donc plus lente et plus mordante que l'épée, le gourdin plus faible, le
marteau le plus lent. Les armes à deux mains (grand marteau) ne sont données à aucun ennemi courant.

## Mort et butin

- À la mort, l'arme quitte la main (`ArmesEnnemis.lacher`), tombe en 0,4 s et se pose à plat sur le terrain près de la main
  (`ObjetMonde.visuel(id, "sol")` : couchée, pivot au sol, inclinée selon la pente du sol).
- Le butin du corps contient la même arme du catalogue (`Draugr._laisser_butin`) : « Fouiller » la met au sac, le visuel au sol
  disparaît (`Butin._apres_fouille`).
- Dépouille couchée (sauvegarde, plafond de cadavres) : `Butin.modele_depouille(spec, butin)` retire l'arme de la main et la
  repose au sol si elle est encore dans le butin.
- L'arme unique du jarl n'est pas lâchée (`uniques.hache_kolbeinn.butin = false`) : la vraie hache est sur le trône (objet unique).

## Performances

Les armes du catalogue font 3,7 à 9,2 k triangles (gourdin 1,3 k). Maillages partagés entre toutes les instances, matériaux partagés
(`EpeesLongues.materiaux`, teinte d'usure clonée une fois par matière et par teinte), LOD automatiques de l'import glb
(`generate_lods`), `visibility_range_end = 50` m. Mesure : voir le rapport de la branche `ennemis/vraies_armes`.

## Ajouter une arme à un profil

1. Si besoin, créer l'arme au catalogue (modèle `.tscn` avec `prise` / `garde` / `pointe`, comme `gourdin.tscn`).
2. L'ajouter dans `profils.<ennemi>.armes` avec un poids ; si l'arme est d'hast, régler `cible` / `limite` dans `familles` ou `prises`.
3. Planche de contrôle : `captures_armes_ennemis.gd` (ajouter un cas dans `CAS`), puis `test_armes_ennemis`.
