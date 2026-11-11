# Audit des persos Tripo intégrés — 2026-11-11

But : vérifier qu'aucun perso Tripo intégré n'a les bugs du garde à l'épée (épée collée ou flottante, bras disparu ou en tige grise,
main détachée ou « pâte à modeler », éclats noirs flottants, trous), ni de bug de comportement (T-pose, glissade, LOD, erreurs Godot).

Branche `audit/persos_tripo` (depuis `biome/zone-temoin`). Branches lues sans y toucher : `tripo/epee_gardes` 9a659cb2 (épée v2d)
et `tripo/armure_verre` 3fc989ed (verre v3d).

Planches : `Desktop/Skyrim captures/a_voir_2026-11-11/audit_persos/`
- `village/` : un fichier par garde, plus Haldor, le jarl et la mage ;
- `crypte/` : les ennemis et les dépouilles ;
- `branche_epee_v2d/` et `branche_verre_v3d/` : les branches lues ;
- `epee_avant_zone-temoin_apres_v2d.png` : l'épée avant (zone-temoin) et après (v2d) ;
- `DEFAUT_arcs_ennemis_garde_et_tir.png` : le défaut des arcs ennemis.

Lecture d'une planche : chaque ligne est un état (repos, marche, course, garde, attaque A, attaque B). Les colonnes sont, dans
l'ordre : face, profil droit, profil gauche, 3/4, gros plan main droite, gros plan main gauche, puis la référence validée la plus
proche, à droite sous une bande dorée.

Outils :
- planches : `outils/audit_persos_tripo.gd`, avec `--vue=village` ou `--vue=crypte`, `--cibles=a,b` et `--sortie=` ;
- contrôle géométrique : `outils/controle_modele.gd`, copié depuis 2049f4d3 et non commité ici.

## Verdicts

| Perso | Verdict | Gravité | Capture | Cause probable | Correction proposée |
|---|---|---|---|---|---|
| Gardes à l'épée zone-temoin (e_s, ronde_rue/est/ouest/place) + Haldor | **DÉFAUT** | grave | village/garde_ronde_place_*, epee_avant…png | bug connu : `_poing_ferme` (poing cylindre) et l'épée sur `lowerarm_r` ; rien sur `hand_r` | **fusionner `tripo/epee_gardes` (v2d)**, qui corrige les deux (voir plus bas) |
| Draugr archer | **DÉFAUT** | grave | crypte/draugr_archer, DEFAUT_arcs… | en visée et au tir, l'arc reste horizontal devant la poitrine. Il n'est pas tenu : la main gauche ne serre pas la poignée et la corde ne passe pas par la main droite. `EnnemisNordiques._arc` = arc skinné de `SqueletteGuerrier.arc()`, sans `PoseArcher` | reprendre la chaîne de l'archer garde Tripo : `ChasseresseNordique.equiper_arc` + `PoseArcher` sur `hand_l`, et le contrôle du modèle avant de valider |
| Squelette archer | **DÉFAUT** | grave | crypte/squelette_archer, DEFAUT_arcs… | même cause | même correction |
| Squelette « mains nues » (variante épée) | **DÉFAUT** | moyen à grave | crypte/squelette (lignes course et attaque) | une lame ou un éclat sombre traverse l'avant-bras ou le poignet droit, et un bâton passe devant les jambes en course. Le contrôle trouve des éclats de 7, 8 et 9 faces près de `lowerarm_r`/`hand_r`. C'est probablement un reste de l'arme Tripo fondu dans le corps | modèle : retirer les îlots de l'arme dans le GLB (Blender, séparer par îlots connexes près de `hand_r`), puis relancer `controle_modele` |
| Draugr guerrier (×3 variantes) | défaut mineur | mineur | crypte/draugr_guerrier_a/b/c | arme rouillée bien tenue, bras continus. Le contrôle trouve un éclat de 8 faces près de `hand_r` (13 cm) qui ne se voit pas sur les planches | modèle : supprimer l'éclat, puis recontrôler |
| Gardes lanciers (so, n_o, e_n, halle_o, tour) | OK visuel, ECHEC au contrôle | mineur | village/garde_*_lance_* | la lance reste en main. Rapport main D de 4,53 : faux positif, parce que la lance Tripo est skinnée sur `hand_r`. Le contrôle trouve aussi un éclat d'1 face près de `hand_l`, 103 petits éclats, 5 petits trous et 11,7 % d'étirement de l'avant-bras gauche en marche | modèle : nettoyer les éclats et les trous. Outil : ignorer l'arme skinnée dans le rapport de la main |
| Archer garde (vigie, ronde_nord) | OK visuel, ECHEC au contrôle | mineur | village/garde_*_archer_* | arc tenu avec `PoseArcher`, conforme à la référence. Éclats de 4, 6 et 10 faces près de `hand_l`/`lowerarm_l` (3,8 à 7,2 cm), peut-être cachés par l'arc | modèle : nettoyer les éclats et recontrôler |
| Jarl Gunnar | défaut | mineur à moyen | village/jarl_gunnar (ligne course) | la cape éclate en pointes autour des jambes en course : les ressorts de la cape traversent les jambes | réglage : rigidité ou collisions des jambes de la cape (ressorts), à voir avec l'agent du jarl |
| Mage Eirwen | OK, avec une réserve | mineur | village/mage_eirwen | bâton tenu. En course, il semble s'écarter de la main, à confirmer en jeu | vérifier l'accroche du bâton sur `hand_r` en course |
| Armure dorée v10 (halle_e) | OK | — | village/garde_halle_e_* | mains nues, sans arme, silhouette propre | — |
| Armure de verre v2 (n_e) | OK | — | village/garde_n_e_* | épée en main, silhouette conforme. Le contrôle trouve 188 petits trous et 1 593 arêtes non-manifold, sans trou visible. Rendu sombre | — |
| Gobelin | OK | — | crypte/gobelin | dague tenue, étirement de 9,9 % (sous le seuil) | — |
| Dépouilles | OK | — | crypte/crypte_depouilles | corps au sol après la mort, pas de T-pose. Le squelette archer s'éparpille en os | — |

Aucune T-pose, glissade ou disparition LOD n'a été vue pendant les captures.

## Branches non fusionnées

- **Épée v2d** (`tripo/epee_gardes` 9a659cb2) : contrôle OK, 5 701 tris, épée sur `hand_r` à 0,8 cm, angle de 26 à 66°, rapport
  des mains 0,83 et 0,89. Sur la planche, le poing est un vrai gantelet et la poignée passe dans la main, garde sous le poing, dans
  tous les états. **Elle corrige le bug du garde à l'épée.** Je recommande de la fusionner après validation par l'utilisateur.
  Elle ne contient pas encore le correctif des accroches ci-dessous.
- **Verre v3d** (`tripo/armure_verre` 3fc989ed) : contrôle OK, 10 642 tris, arme à 4,9 cm, angle de 6 à 78°, main D 1,15. Sur la
  planche, l'épée est en main et les bras sont continus. Mon outil cadre mal les gros plans des mains en attaque, donc rien ne
  ressort sur ce point. Elle produit encore les 5 avertissements « Bone index -1 » (correctif non présent sur la branche).

## Correctifs de code faits sur cette branche

1. `scripts/ennemis_nordiques.gd` : `_resoudre_accroches(g)` dans `_gabarit`. Les gabarits sont bâtis hors de l'arbre ; leurs
   `BoneAttachment3D` restaient à `bone_idx = -1` et chaque `duplicate()` (`_corps`, ligne 323) avertissait « Bone index -1 out of
   range! Cannot connect BoneAttachment », 5 fois par crypte. L'index est maintenant résolu une seule fois depuis `bone_name`. La
   capture de la crypte n'affiche plus aucun de ces avertissements.
2. `scripts/villageois.gd` : `pose_couchee` était appelée sur un lit libéré, par exemple quand un intérieur se décharge pendant
   que le PNJ s'assoit (branche « assis » de `_au_lit`, et `abord_lit`). Maintenant, si le lit n'existe plus, le PNJ se relève et
   `abord_lit` renvoie sa position.

Tests ciblés : `test_ennemis_nordiques` (100 OK, 0 échec) et `test_sommeil` (44 OK, 0 échec).

## Limites de l'outil de capture

- L'angle « face » est calculé depuis les épaules. Il est approximatif sur certains corps, donc un profil peut être tourné de
  quelques dizaines de degrés.
- Les gros plans des mains en attaque sont parfois mal visés, la main étant sortie du cadre.
- Sur la planche des dépouilles, les corps projetés sortent souvent du cadre.
- Le contrôle géométrique compte l'arme skinnée de la lance comme une partie de la main, d'où un faux ECHEC sur le rapport de la main.
