# Audit du combat à l'épée FPS (P1, 2026-10-27)

Référence : `references/combat_epee/prompt_perfectionnement_ultime.md` (16 critères). Périmètre de cette branche
(combat/coups_finishers) : animations du bras et de l'épée du joueur, épaisseur des lames, combos, garde et parade.
Collisions, profils des 5 épées, caméra et corps, finishers côté ennemi : branches combat/collisions_profils,
combat/camera_corps et combat/finishers_ennemis.

## Ce qui existe (et reste)
- **Pipeline** : poses clés en espace écran (`sources_blender/scripts/gestes_bras_epee.py`) → solveur anatomique
  (`anim_bras_epee.py` : butées, coude, clavicule, torsion pondérée) → Blender (Bézier) → `assets/animations/bras_epee.tres`
  (clips 120 Hz + marqueurs). Lecture par cinématique directe (`AnimateurBras.pose_arme`) : la lame qui blesse est celle
  qu'on voit. Couche additive `DecalageBras` (respiration, marche, inertie, recul).
- **Machine à états** `EtatCombat` (12 états, table de transitions, refus comptés) ; mémoire d'entrée
  (`EntreesCombat.tampon`) ; fenêtres de combo `enchainement` par geste ; récupération obligatoire.
- **Repos en tranche** validé (plat à 79° de l'œil, lame à 12° de la verticale), identique pour les 5 épées.
- **Défense** : garde orientée, parade parfaite, contre-attaque, garde brisée (tests test_defense).
- **Deux mains** : la main gauche (torche, magie, bouclier) reste pilotée à part ; aucun changement de ce côté ici.

## Ce qui n'allait pas (avant la passe 6)
- Lames trop fines : au repos, le métal ne faisait que 4,7 px de large à l'écran.
- Combo : le « 1 » se lisait comme un vertical raide, et le « 2 » allait de droite à gauche. Il n'y avait pas d'estoc dans le combo.
- Avant-bras retourné de 190° sur le revers (torsion de −95 à +95) ; lame vue en bout à la fin de B.
- Le lourd était un armé lent tout du long, sans vrai coup sec.
- Garde et parade : l'épée restait presque immobile sous le coup.
- Pas de règle d'annulation explicite : une attaque lancée par erreur ne pouvait pas être coupée par la garde.

## Latences mesurées (`outils/mesure_latence_combat.gd`, sans fenêtre)

Conditions de mesure :
- clic de 50 ms à 60 i/s, mannequin à 1,6 m ;
- chaque appui suivant est fait dès que la fenêtre de combo s'ouvre ;
- les temps sont comptés en ms depuis l'appui.

| Coup | Animation | Zone active | Impact | Combo possible | Repos |
|---|---|---|---|---|---|
| 1 diagonale | 50 | 183 | 217 | 333 | — |
| 2 horizontal G → D | 17 | 150 | 200 | 300 | — |
| 3 estoc | 17 | 167 | 200 | 350 | 550 |
| lourd (appui 0,6 s) | 50 | 750 (150 après le relâchement) | 800 | 983 | 1 617 |

Lecture :
- l'animation démarre au plus tard au 3e image ;
- l'impact arrive à environ 200 ms ;
- les coups s'enchaînent toutes les 300 à 350 ms sans repasser par le repos (le repos n'est atteint qu'après le 3e coup).

## Fait (passe 6)
- **Lames** : épaisseur ×1,8 et largeur ×1,12, avec un méplat élargi. La largeur apparente au repos passe :
  - pour le métal, de 4,7 à 7,0 px ;
  - pour l'or, de 4,1 à 6,2 px ;
  - pour le rubis, de 5,5 à 8,7 px ;
  - pour le verre, de 4,4 à 6,8 px.
  
  Commit 13ecd75.
- **Combo** : diagonale haut-droite → bas-gauche, puis horizontal gauche → droite à plat, puis estoc. Le tranchant mène à :
  - 71° sur la diagonale ;
  - 80° sur l'horizontal ;
  - 70° sur l'estoc.
  
  Dans le jeu (frappe), la lame visible et la part d'écran prise par le bras sont :
  - coup 1 : lame 28-100 %, bras 6-15,3 % ;
  - coup 2 : lame 28-96 %, bras 6,9-11,4 % ;
  - coup 3 : lame 100 %, bras 3,9-5 %.
  
  Commit 7d8dd36.
- **Lourd** : 4 phases (armé haut, tension, coup sec en 0,15 s, grand suivi, retour). Lame visible 52-96 %, bras 6,3-9,2 %. Commit 40dd934.
- **Garde réactive** :
  - coup encaissé : l'épée est chassée, rebondit puis revient en garde (0,26 s) ;
  - parade parfaite : choc sec (0,22 s).
  
  Commit 40dd934.
- **Annulation** : la garde pendant la préparation d'une attaque légère coupe l'attaque en une image. Une fois la lame active, le coup va au bout. Commit 791b806.

## Passe 7 (2026-10-27, branche combat/vertical)
Mesures `outils/captures_combat_epee.gd -- --mesures [--gestes=verticale_l,diag_gd]` (lame visible = dans le cadre et non
cachée par le bras ou la torche ; plat vu = |normale du plat · œil| ; pointe = angle du déplacement de la pointe pendant
frappe + suivi, à l'écran, avec l'horizontale) :

| Geste | Lame visible (toutes images) | Bras | Plat vu (armé → suivi) | Pointe |
|---|---|---|---|---|
| vertical avant (coup_c_ancien) | 12-100 %, 15 images < 60 % | 3,7-15,3 % | ≤ 63 % | 86° (mais lame à plat, se lit en diagonale) |
| vertical V3 (coup_v) | 52-100 %, 1 image < 60 % (tenue) | 3,7-14,3 % | ≤ 31 % | 81° |

- **Vertical V3** : armé court au coin haut droit (poing à mi-hauteur : plus haut, l'avant-bras dépasse 15 %), lame
  dressée penchée vers l'avant, puis descente dans un plan vertical un peu à droite du centre, tranche vers l'œil, poignet
  qui casse ; la pointe finit en bas juste à gauche du centre, sous le poing (jamais derrière lui : pas de lame en bout).
- **1re image de la frappe** : diagonale 28 → 84 % (lame de l'armé penchée vers l'avant, même poing, frappe identique
  image par image dès la 2e image) ; revers du combo 28 → 56 % (armé à -0,30 au lieu de -0,40 : la lame ne peut pas
  pointer plus vers l'avant, butée de pronation). Latences inchangées (mesure_latence_combat : 33/167/200/317 ms etc.).

## Passe 8 (2026-10-28, branche combat/poignet_fouet) : le poignet qui fouette
Retour utilisateur : `references/combat_epee/prompt_poignet_fouet.md` (« les coups partent en inversé » : la main descendait
d'un bloc, l'épée raide comme un levier, la pointe qui traînait).

Ce qui a été fait :
- **Mesure** `anim_bras_epee.py -- --fouet` (lignes FOUET / FOUET_RESUME) : part des images où la pointe est devant le
  poing dans le sens du coup (début / fin de la frappe), rapport vitesse pointe / vitesse poing, « fil » (tranchant qui mène,
  même calcul que test_combat_epee).
- **Recherche des articulations** `sources_blender/scripts/optim_fouet.py` : les poings des clés restent ceux de
  gestes_bras_epee.py ; les angles (torsion k, flexion f, inclinaison r, coude phi) des clés de frappe sont cherchés
  (recherche locale, graine fixe) pour : pointe derrière au début / devant à la fin, pointe ≥ 3 × plus rapide que le poing,
  fil ≥ 75°, trajet du milieu de lame voulu, direction finale de la lame, pas de saut d'image ni de retournement. Les
  angles trouvés sont recopiés dans les clés (k, f, r, phi : clé fixée, comme REPOS).
- **Diagonale (coup_a, clés D4_*)** : lame armée en arrière au-dessus de l'épaule (pointe en haut à droite du poing),
  avant-bras en supination (k ≈ +90) ; à la frappe la pronation (+93 → −58°) et la cassure du poignet font passer la lame
  par-dessus puis la fouettent vers le bas-gauche devant la main ; le poing ne fait que (0,56 ; 0,15) → (0,20 ; −0,18).
  Une clé de récupération (V3_RETOUR) évite que la lame passe derrière la caméra au retour.
- **Lourd (P4_*)** : charge tenue lame dressée (P4_CHARGE, lame entière dans le cadre) ; au relâchement le poignet s'arme
  en arrière (0,06 s) puis claque : même fouet par-dessus, balayage vers la gauche devant la main.
- Anciens gestes gardés pour comparaison : coup_a_levier, coup_b_levier, lourd_levier.

Mesures (FOUET_RESUME, frappe = marqueurs frappe → fin_frappe ; avant = *_levier) :

| Coup | Pointe devant (début → fin) | v pointe / v poing | Fil |
|---|---|---|---|
| diagonale avant | +0,41 → +0,72 (la pointe ne passe jamais : levier) | 1,2 | 81° |
| diagonale après | −0,55 → +0,80 (derrière, puis devant) | 6,7 | 79° (test : 74°) |
| lourd avant | −0,70 → +0,91 | 1,7 | 60° |
| lourd après | −0,64 → +1,00 | 4,5 | 61° |
| horizontal G → D (inchangé dans le fond) | −1,00 → −1,00 | 2,0 → 2,9 | 81° → 73° (test : 74°) |
| vertical coup_v (inchangé) | −0,68 → +1,00 | 6,4 | 58° |

Latences (mesure_latence_combat, avant → après) : identiques sauf l'impact de la diagonale 200 → 217 ms (une image : la
lame passe par-dessus avant d'atteindre le mannequin) ; zone active 167 ms et combo 317 ms inchangés. Repos : plat 71°.
Lame visible pendant la charge du lourd : 100 % (l'armé en arrière du relâchement : 16-44 % pendant 4 images).

Limites :
- **Horizontal G → D (coup_b)** : pas de vrai fouet. Avant-bras en pronation, la lame ne peut pas pointer vers la droite
  avec le poing au centre (butées du poignet) ; il faudrait une rotation de l'avant-bras de ~180° (lame qui pointe en l'air
  au milieu du coup). La lame rattrape le poing (pointe 2,9 × plus vite, armée plus en arrière qu'avant) sans le dépasser.
- **Estoc** : poussée, pas de fouet (clés E_* d'origine).
- L'armé de la diagonale et du lourd met la pointe hors du cadre en haut à droite (lame visible 56-72 % à l'armé de la diagonale, mesuré en jeu).

## Écarts restants
- **Vertical** : une image de passage (milieu de la frappe) montre la lame très raccourcie (angle lame / visée 11°,
  76 % visible) ; au suivi la lame est raccourcie de moitié environ (angle 40°) et penche vers le bas à gauche à l'écran ;
  la récupération montre le plat 2 images (≈ 45-50 %) quand l'avant-bras repasse de la pronation à la supination.
  Une lame de 0,87 m tenue à 0,6 m de l'œil (champ 72°) ne peut pas descendre « à plat dans l'écran » en restant
  dans le cadre : elle est soit raccourcie (vers le fond), soit coupée par le bord bas.
- **Revers du combo** : armé (images 1-6, reprises de la fin de la diagonale) encore à 32-56 %.
- **Récupération** : la garde n'y est prise qu'après 0,12 s (choix conservé).
- **Vues Blender** (`--vue=cote|dessus|epaule`) : elles existent mais sont encore trop éloignées pour bien lire.
- **3e personne** : pas de geste propre par direction.
