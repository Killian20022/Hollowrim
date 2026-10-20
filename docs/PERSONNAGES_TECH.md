# Fiches techniques des personnages

(Une section par agent. Cette section : « Squelette guerrier ». Si le fichier existe déjà sur la branche fusionnée, ajouter la section à la suite.)

## Squelette guerrier (ennemi « squelette », branche graphisme/squelette-guerrier)

### Macro / Méso / Micro (décidés avant le code)
- **Macro (silhouette à 20 m)** : un grand os clair sur le fond sombre de la crypte : cage thoracique en bloc rayé de noir, casque conique en fer, bouclier rond ébréché au bras gauche, lame ou arc à droite, os longs épais à épiphyses larges. Se distingue du draugr (chair momifiée, haillons) par l'absence totale d'étoffe et par la teinte ivoire.
- **Méso (2-8 m)** : cage thoracique à 6 pans (fentes intercostales peintes, sternum saillant), bassin en 3 blocs (sacrum + 2 ailes iliaques), crâne facetté avec orbites et narine en pyramides creuses réelles, mâchoire séparée, nasal du casque ; chaque os long = prisme à 4 pans évasé aux deux bouts (condyles) qui recouvre l'articulation voisine (aucun trou au pliage).
- **Micro (< 2 m)** : atlas 256² à DENSITE_PERSO = 32 texels/m, un îlot par face ; os ivoire -> brun (taches, dessous des os plus sombres, poussière vers le bas), arêtes éclaircies d'un texel sur les grandes faces, fer rouillé par plaques, bouclier peint écaillé (secteurs rouges), dents du maxillaire, lueur froide dans les orbites (matériau non éclairé très sombre bleuté, surface 1).

### Budget
- Triangles (tout compris) : **552** corps + casque + bouclier ; +38 épée = **590** ; +44 arc = **596** (cible 450-600). Détail : crâne 32, face 50, mâchoire 20, casque 42, cage 44, bassin 36, os longs 8 (28 ou 20 chacun), mains 24, pieds 24, clavicules 24, cou 12, lombes 12, bouclier 38.
- Os : 25 = RIG18 (root + 18 déformants) + `spine_02` + 4 feuilles sans poids (`ball_l/r`, `middle_01_l/r`, exigées par `scripts/ragdoll.gd`). Plafond 26 respecté ; aucun os secondaire à ressort (pas d'étoffe sur un squelette).
- Skinning rigide : 1 os, poids 1,0 par sommet (pièces rigides, adapté au vertex snapping). Bouclier -> `lowerarm_l`, arme -> `hand_r` (repère de la prise de l'épée du joueur, `draugr.gd: prise`).
- Texture : 1 atlas 256x256 (~16 % utilisé à 32 texels/m : marge pour 64 texels/m), palette 15 bits, rampes de 8 tons, tramage par bruit de valeur (jamais Bayer). Matériau : `ps1.gdshader` via `Humain.shader_perso` (mipmaps plus proche voisin). 2 surfaces : 0 = atlas, 1 = orbites.
- Mémoire/perf : 1 matériau partagé par tous les squelettes (cache statique), 1 draw call par surface.

### Fichiers
- `sources_blender/scripts/squelette_guerrier.py` : génère squelette (depuis `homme_vetu_lot1.glb`, mêmes os et pose de repos -> animations et ragdoll inchangés), maillages, UV, atlas, export. Rejouable : `outils/blender.sh` (puis `godot --headless --import`, puis `outils/generer_squelette.gd`).
- `assets/modeles/squelettes/squelette_guerrier.glb` (maillages `squelette`, `epee`, `arc`), `sources_blender/squelette_guerrier_atlas.png`, `assets/personnages/squelette_guerrier.res` (précalcul, repli sur le PNG).
- `scripts/squelette_guerrier.gd` (`SqueletteGuerrier.creer({"arme": "epee"|"arc"})`), `scripts/draugr.gd` (types `squelette`, `squelette_archer`).
- Outils : `galerie_squelette.gd` (fixe / anim 8 images / jour-nuit), `galerie_trous.gd` (personas `squelette_epee|arc`), `test_squelette.gd`, `test_squelette_traversees.gd`, `analyse_prise.gd`.

### Comportement
70 PV, marche 1,05 m/s (draugr 0,85), course 4,3 m/s (3,4), 14 dégâts ; coups puissants x1,3 (os secs, « contondant » simplifié : le jeu n'a pas d'arme contondante) ; bouclier : mêmes parades que le guerrier ; frappe uniquement `Sword_Attack` (le coup de poing ferait traverser la tête par la lame) ; mort = ragdoll existant (tas d'os < 0,35 m, étalement < 1 m), sons d'os (`impactWood_heavy`, `chop`), butin d'os de draugr. L'archer est une variante VISUELLE : aucun système de tir n'existe, il frappe à l'arc.

### Ajouter un squelette
1. Dans une zone : `gardien("zone", "squelette"` ou `"squelette_archer", pos, lacet, dort, debout, "cr_zone_xxx")` ; passer un identifiant fixe (dernier argument) pour ne pas décaler les identifiants numérotés déjà sauvegardés.
2. Hors crypte : `monde.creer_draugr("squelette", pos, lacet, dort)`.
3. Changer le modèle : modifier le script Blender, `outils/blender.sh`, import Godot, `outils/generer_squelette.gd` (incrémenter `SqueletteGuerrier.VERSION`), `test_squelette.gd` + `test_squelette_traversees.gd`.
4. Changer la densité : `DENSITE_PERSO` dans le script Blender ET dans `squelette_guerrier.gd` (la valeur est cuite dans les UV).

### Vérifications
Voir le journal dans `docs/MISSION_GRAPHISME.md` (lot « squelette guerrier »).
