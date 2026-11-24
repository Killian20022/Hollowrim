# Feu v2 (branche magie/feu_v2)

Retour utilisateur (exe 3) : les sorts de feu sont « brouillons » à côté du gel et de la foudre v2. Refonte d'après la méthode de la
foudre v2 : formes structurées, couches, détail fin, paliers de couleur francs, largeur de trait entière en pixels.

## Ce qui change
- `scripts/magie/feu_v2.gd` (classe `FeuV2`) + `shaders/feu_v2_corps.gdshader`, `feu_v2_langue.gdshader`, `feu_v2_roussi.gdshader`.
- **Orbe** (`FeuV2.orbe`) : trois coques de bruit 3D (cœur blanc-jaune, gaine orange trouée en langues, peau rouge déchirée qui
  s'étire en goutte) + 9 flammèches en rubans qui s'enroulent autour et filent vers la queue (chemin calculé dans le shader).
  Utilisée : (1) projectile de la boule de feu (`projectile_visuel`), (2) charge d'une main (remplace la flamme tenue au-delà de
  6 % de charge), (3) double incantation : UNE orbe, portée par la main meneuse, au point de fusion entre les deux mains.
- **Explosion** (`FeuV2.explosion`) : flash bref, cœur qui se refroidit et rétrécit, gaine qui s'ouvre, 16 éclats radiaux en rubans,
  braises fines et fumée légère. L'impact + la zone qui le suit ne dessinent plus qu'UNE explosion ; l'ancien anneau de pixels
  (`disque`) et la bouffée procédurale sont supprimés en couche fine.
- **Jet de flammes** : l'impact « sprite plat » (aura procédurale `_jet_eclabousse` + particules `feu_lechage`) est remplacé par
  `FeuV2.lechage` (langues qui lèchent la surface, lueur basse, braises fines) et un **roussi** discret (tache à 3 paliers, 7 s,
  14 au plus) ; filets d'accompagnement en rubans (`FeuV2.jet`) le long du jet.
- `-- --feu-v1` remet l'ancien rendu (planches avant/après).
- Tout vit dans le calque de la couche fine : sans elle (détail « Rétro ») rien ne change.

## Vérifications
- `outils/test_feu_v2.gd` (sans fenêtre) : orbe, projectile, explosion unique, léchage + filets + roussi, libération, `--feu-v1`.
- `outils/test_effets_magie.gd` : plafonds de la couche fine inchangés.
- `outils/film_feu_v2.gd` : film 1re personne (plein air de nuit, `--crypte=0,-24,0,-4` pour la crypte) ; **lancer avec
  `--detail-sorts=eleve` et `--resolution 1280x720`** (en 960x540 la couche fine est éteinte : facteur d'échelle 1).
