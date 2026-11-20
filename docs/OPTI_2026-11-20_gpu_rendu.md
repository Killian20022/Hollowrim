# Opti 2026-11-20 — domaine gpu_rendu

Base f0c1b14b, machine partagée (2 Godot max via godot_slot), PC sur secteur (BatteryStatus 2), fenêtre 1280x720 hors écran.
Outil : `outils/mesure_ab_rendu.gd` (A/B ENTRELACÉS dans un seul lancement : `--ab=base,x,y,base --tours=N --planche=<dossier>`).
Ms GPU = `viewport_get_measured_render_time_gpu` (racine) ; FPS = 1000/ms.

## Conclusion
Aucun réglage de rendu ne gagne du temps GPU SANS changer l'image. Rien n'est changé dans le jeu : la branche n'apporte que
l'outil de mesure. Surtout, le GPU n'est PAS le goulot : son plafond est de 70 à 125 FPS, alors que les vrais FPS sont de
35 à 48 (dt médian 21 à 29 ms) → CPU (scripts, envoi des appels, physique : autres domaines).

| Lieu | GPU (ms) → plafond GPU | dt médian (ms) → vrais FPS |
|---|---|---|
| Témoin / feu de camp, 21 h | 8,0 à 9,2 → 109 à 125 FPS | 21 à 24 → 42 à 48 FPS |
| Témoin, 12 h | 7,5 → 134 FPS | 20,5 → 49 FPS |
| Forêt, 12 h | 5,6 → 179 FPS | 8,6 → 116 FPS |
| Place du village, 12 h | 13,2 à 14,8 → 68 à 76 FPS | 25,6 à 33,6 → 30 à 39 FPS |

## Postes mesurés (A/B entrelacés, Δ GPU contre base)
| Essai | Feu 21 h | Témoin 12 h | Forêt 12 h | Place 12 h | Image | Décision |
|---|---|---|---|---|---|---|
| ombres du soleil coupées | −3,6 | — | — | −8,6 | change | référence du coût seulement |
| atlas 3072 | — | −0,21 | −0,10 | +0,06 | identique | aucun gain |
| atlas 2560 | — | +0,13 | −0,28 | +0,06 | identique | aucun gain |
| atlas 2048 | −1,7 | −1,2 | −1,6 / −1,9 | −0,5 / −0,8 | **bords d'ombre flous** | refusé |
| atlas 2048 + filtre très bas | — | — | −1,15 | +1,1 | grain le long des bords | refusé |
| atlas 2048 + filtre dur | — | — | −1,13 | −0,26 | bords en escalier | refusé |
| glow linéaire | +0,06 | −0,33 | −0,03 | +1,0 | — | aucun gain |
| ciel incrémental (radiance) | −0,02 | — | — | +0,46 | identique | aucun gain |
| ciel coupé (coût total du ciel) | −0,5 | — | — | +0,1 | change | ciel déjà bon marché |
| mode Élevé (couche fine des sorts) | +0,18 | — | — | — | identique | le post plein écran ne coûte rien |
| Élevé + post coupé | +0,43 | — | — | — | — | → SubViewport 640x360 inutile |
| Élevé en 1080p | +0,52 | — | — | — | — | idem |
| terrain dessiné en dernier (41d91b85) | ordre d'avant −0,4 | — | — | ordre d'avant −2,6 | identique | retiré (3919ae82) |
| aurore : couches hors bande sautées | −0,15 | — | — | — | risque d'un palier 15 bits près du noir | retiré (3919ae82) |
| shader ps1 léger | +0,03 | — | — | bruit | — | retiré (e162fcc6) |

Planches : `C:\Users\lopezk19\Jeux\rendus\opti_2026-11-20\gpu_rendu\` (atlas_foret12h_zoom2x_*.png : bords d'ombre au zoom ×2,
atlas_place12h_4096_vs_2048.png) ; images brutes par réglage dans brut\, brut2\, brut3\.
NB : entre deux captures, le vent, les PNJ et les nuages bougent (base contre base = 12 à 18 % de pixels > 8/255) ; seul
l'œil (zoom ×2) tranche.

## Ombres : où passe le coût
Inventaire (`--inventaire-ombres`, place 12 h, 62 m) : 649 projeteurs, 644 k triangles (≈ la moitié des primitives de l'image).
Bâti du village 186 k, gardes 114 maillages / 113 k (chaque pièce d'armure projette), mobilier 91 k (extérieur), villageois
88 k, arbres 57 k. Le terrain ne projette pas ; les intérieurs et les PNJ éloignés sont déjà coupés (village.gd, LOD d'ombre
des gardes et villageois).

## Pistes hors domaine
- persos_anim : pièces d'armure des gardes (114 projeteurs) : une ombre par perso (silhouette fusionnée, ou seules les pièces
  extérieures projettent).
- appels_dessin : maillages fusionnés de 92 à 145 m (village, forêt) dessinés entiers dans les DEUX tranches de l'ombre ;
  les découper par quartier permettrait d'écarter les morceaux hors tranche.
- cpu_scripts / physique : l'écart dt (21-34 ms) contre GPU (8-15 ms) est le vrai frein des FPS.
