# Lancer des écoles runiques (glace, électricité, ténèbres)

Le sort lancé naît de l'effet au repos (mêmes cristaux / arcs / fumée, mêmes runes). Code : `scripts/magie/lancer_ecole.gd` (socle), `lancer_glace.gd`, `lancer_elec.gd`, `lancer_tenebres.gd` ; rayon du néant : `rayon_neant.gd` ; outil : `outils/captures_lancer_ecoles.gd`.

## API (LancerEcole)
- `projectile(ecole, forme)` : nœud pour `ProjectileSort.tirer_sort` (pilotage automatique) ; `creer(ecole, forme)` : nœud autonome.
- `demarrer(progression)` / `maintenir(tete, dir)` / `terminer(point)` ; `reformer(main, centre)` par école (le repos se reforme dans la main).
- `combiner(main_g, main_d, point_fusion, intensite, ecole, forme)` : double magie (deux flux → un seul, plus large, un seul anneau de runes).
- `depart(ecole, main, dir, k)` : geste de départ des sorts sans projectile ; `LancerElec.tension(...)` : arcs paume → cible ; `LancerTenebres.volute_rayon(...)` : fumée → cercle du rayon.

## Points de branchement (provisoires, à remplacer par l'API de transition commune)
- `projectile_sort.gd` : `demarrer` au tir, `maintenir` chaque image, `terminer` à la fin du vol, rampe de vitesse au départ.
- `lancer_ecole.gd` `demarrer` : `reformer` des mains 0,4 s après le départ (à remplacer par la récupération de MainSort).
- `effets_magie.gd` : `projectile_visuel`, `_lancer_jet` (front montant → départ, descendant → reformer), `_lancer_zone`, `chaine`, `decharge`.
- `rayon_neant.gd` : DELAI / AVANCE (le faisceau paraît après la fumée et grandit depuis le cercle).

## Captures
`godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_lancer_ecoles.gd -- --nouvelle --sortie=<dossier> [--scen=…] [--cam=gros|fps|suit|tps] [--double] [--film] [--combiner=glace|electricite|tenebres]`
Les nouveaux `class_name` demandent un `godot --headless --path . --import`.
