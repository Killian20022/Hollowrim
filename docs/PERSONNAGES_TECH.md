# Personnages — fiche technique

## Vivants (humains : joueur, villageois, bandits) — branche `graphisme/persos-base`

### Les 3 points (décrits AVANT le code)
- **Macro (silhouette)** : un seul corps de base par morphologie (homme 1,81 m, femme 1,72 m ; squelette Quaternius conservé), **fermé**, 668 triangles + 96 de bagues,
  skinné **rigide (1-2 os par sommet)** sur RIG18. Épaules larges, taille marquée, mains et pieds un peu grands. Tête séparée (3 volumes de visage), coiffure (3), barbe (2).
  Les rôles se lisent à 20 m par la silhouette : robe longue + mante, tablier + bras nus, capuche + carquois, cape longue, casque + bouclier, capuche + fourrure dépareillée.
- **Méso (vêtements en couches)** : chaque couche est calculée sur les anneaux du corps à une marge de 1-4 cm (gilet +2,2 cm, tablier +3-4 cm, cape +4 cm, bagues +1,2-1,4 cm) :
  aucun vêtement « peint sur la peau ». Robes et jupes : **panneaux** (deux côtés pondérés sur la cuisse et le mollet du côté, avant et arrière internes sur ressort) ;
  capes, tablier, capuche : **5 os secondaires** hors RIG18 animés par ressort (`PersoRessorts`). Bagues de recouvrement aux jointures : ceinture, collet, bracelets, revers de bottes.
- **Micro (textures)** : atlas **256×256 par morphologie**, **48 texels/m** (constante unique `densite` dans `mise_en_page_<sexe>.json`, visage = tunique), **indices** (ton 0-7 + région) et non des couleurs :
  une rampe de 8 tons (ombres froides, lumières chaudes) est calculée dans le shader à partir de la couleur de base de la région (**paramètre d'instance**), quantifiée en **15 bits**.
  Arêtes claires peintes (ourlets, cols, nez, pommettes), broderies au fil d'or, coutures, cuir cloué ; bruit à seuil, jamais Bayer.
