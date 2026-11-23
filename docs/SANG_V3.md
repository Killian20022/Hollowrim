# Sang v3 (branche combat/sang_v3, 2026-11-23)

Effets de sang propres et crédibles, en particulier pour les armes / objets lancés par la télékinésie qui se plantent et
traversent. DA PS1 nordique : texels nets, découpe alpha, jamais de tramage ni de fondu d'opacité, rouge sombre (pas fluo).
Moteur : `scripts/combat/sang_v3.gd` (`SangV3`), derrière la façade `Sang` (`scripts/combat/sang.gd`).
Interrupteur : `--sans-sang-v3` (comportement v2 exact). Option existante : **Sang / gore** (`Jeu.option("combat","gore")` 2/1/0).

## API — inchangée (les appels existants marchent tels quels)

| Fonction | Signature (inchangée) | Ce qui change en v3 |
|---|---|---|
| `Sang.giclee` | `(n, point, direction, intensite, couleur, traces := true, sorte := "impact")` | **ajout** `sorte` : `"impact"`, `"sortie"` (plaie de sortie), `"entree"`. Une couleur d'os / bois → gerbe d'éclats (pas de sang) |
| `Sang.jet` | `(attache, local, couleur, duree := 2.4)` | couleur de la palette v3 |
| `Sang.flaque` | `(n, pos, couleur, taille := 0.9, croissance := 4.0)` | s'étale lentement (≥ 14 s), un peu plus large |
| `Sang.trace` | `(n, pos, normale, direction, taille, couleur, sorte := "giclure", croissance := 0.0, delai := 0.0, support := null)` | **ajout** `support` (prop mobile qui porte la trace) ; sortes `"coulure"`, `"goutte"` en plus ; projetée sur le relief |
| `Sang.tacher_voisins`, `Sang.eclats_matiere`, `Sang.sol_sous`, `Sang.matiere_de`, `Sang.nombre_traces` | inchangées | — |
| `GouttesSang.lacher` | `(n, pos, couleur, vitesse := ZERO, tache := false)` | inchangée |
| `SangLame.equiper`, `SangLame.coup` | inchangées | couleur de la palette v3 (draugr noirâtre) |

## Ajouts

- `Sang.traversee(n, entree, sortie, direction, intensite, couleur)` — **arme qui traverse** : petite giclée à l'entrée (vers
  l'attaquant), jet arrière fort + brume rouge fine à la sortie, éclaboussures sur ce qui est derrière (mur, sol, prop).
  Squelette / bois : poussière d'os / échardes des deux côtés. `direction` = sens de l'objet. (À appeler par ImpactsLances.)
- `Sang.sortie(n, point, direction, intensite, couleur)` — plaie de sortie seule.
- `Sang.trainee_corps(corps, couleur, duree := 3.0)` — traînée d'un corps qui glisse / est projeté (suit le bassin du ragdoll),
  une trace « trainee » tous les ~0,32 m près du sol. Branché sur les morts « gros coup » (`CombatEnnemi.effets_mort`).
- `Sang.saigner(n, point, couleur, duree := 6.0)` — blessé qui goutte (gouttes + taches). Branché : ennemi sous 35 % de vie.
- `GouttesSang.lacher_balistique(n, pos, couleur, vitesse, taille := 1.0)` — vraie goutte qui vole et tache là où elle touche
  (sol, mur, prop ; allongée si elle arrive en rasant).
- `SangLame.ensanglanter(modele, intensite, couleur, garde := INF, pointe := INF) -> SangLame` — même sang que la lame du joueur
  sur une **autre arme** (arme plantée, lancée) : matériaux PS1 dupliqués (variante déjà compilée), nœud `SangArme` qui sèche,
  goutte et s'efface ; s'accumule à chaque traversée. Repères `garde` / `pointe` du modèle s'ils existent, sinon grand axe.
- `SangV3.sorte_sang(couleur)`, `SangV3.palette(couleur)`, `SangV3.couleur(couleur)` — variante de sang d'après la couleur du profil.

## Rendu

- **Giclée** : jet principal (traits alignés sur la vitesse, cône de 9°) dans le sens du coup + gouttelettes de tailles très
  variées (×0,35 à ×1,9) + brume (sortie, gros coups : points qui dérivent, freinés, rétrécissent en mourant) + 1 à 7 gouttes
  balistiques qui tachent où elles tombent. Particules : petit reflet humide, émission faible (0,18, v2 : 0,35).
- **Traces** (giclure, flaque, traînée, coulure, goutte) : shader propre (code dans `SangV3.CODE_TRACE`, pas de fichier
  .gdshader) ; masque RGBA peint par code (R = épaisseur, G = liseré, A = couverture). Séchage en 6 paliers (bords minces
  d'abord : rouge sombre → brun-noir, le reflet mouillé s'éteint) ; effacement en 6 paliers par épaisseur (le film mince part
  d'abord). Projection : 4 coins + centre sondés par rayon ; plan partagé si la surface est plane, sinon grille 5 x 5 posée
  sur la surface (marches, pierres, bosses). Mur : la giclure est orientée selon le vol, un filet (`coulure`) coule dessous.
  Prop mobile (RigidBody) : la trace lui est attachée.
- **Neige** (`EffetsSol.est_neige`) : sang un peu plus saturé + liseré d'un texel de sang dilué (rose sombre) : la tache
  ressort sur la neige claire sans virer au fluo.
- **Palettes** : vif (bandits, bêtes) rouge sombre `(0.40, 0.035, 0.028)` → sec brun ; **draugr** noirâtre froid
  `(0.10, 0.032, 0.030)` ; troll violacé ; araignée verdâtre ; squelette : poussière d'os (aucune trace).

## Plafonds / perf

- Émetteurs de giclées en **pool** : 8 jets, 8 gouttelettes, 4 brumes (le plus ancien est repris ; quantité fixe, `amount_ratio`
  par coup ; aucun nœud ni matériau créé par coup). v2 : un GPUParticles3D neuf par giclée.
- Traces : 64 au plus (`Sang.MAX_TRACES_V3`, ≤ 25 triangles chacune), séchées en 45 s (flaques 90 s), effacées après 150 s.
- Gouttes en vol : 80 (`GouttesSang.MAX_V3`), un rayon par goutte balistique et par image. Traînées : 3 corps suivis au plus.
- Hors combat : rien ne tourne (émetteurs arrêtés, GouttesSang sans `_process`, traces = tweens à 13 étapes).
- Mesure : `outils/captures_sang_v3.gd --banc` (FPS moyens, 1 % bas, coût CPU des giclées/traces).

## Outils

- Test : `outils/test_sang_v3.gd` (API, pools, variantes, traversée, relief, neige, arme plantée, traînée, gore à 0).
- Planches / film / banc : `outils/captures_sang_v3.gd -- --sortie=<dossier> --lieu=interieur|neige [--film|--banc] [--sans-sang-v3]`.

## Mesures (2026-11-23, machine partagée avec 2-3 autres Godot)

Banc `captures_sang_v3.gd --banc --lieu=interieur` (6 ennemis, un coup toutes les 0,18 s pendant 12 s, une traversée sur 5,
fenêtre 640x360 hors écran, sans vsync), deux passes chacun :

| | calme avant | combat | 1 % bas (combat) | calme après |
|---|---|---|---|---|
| v2 (`--sans-sang-v3`) | 100,5 / 100,9 FPS | 79,0 / 81,0 FPS | 15,9 / 8,7 FPS | 90,5 / 96,3 FPS |
| v3 | 98,8 / 93,6 FPS | 86,8 / 87,4 FPS | 18,0 / 15,9 FPS | 102,0 / 112,0 FPS |

Les émetteurs en pool (au lieu d'un GPUParticles3D neuf par giclée) font gagner ~7 FPS en combat ; le coût CPU par giclée
est plus haut (gouttes balistiques + leurs taches : ~2-3,5 ms répartis sur ~1 s, v2 ~1,5 ms), sans effet visible sur les FPS.

## Pièges

- Le sol ps1 (neige qui tient, relief) est dessiné ~2 cm AU-DESSUS de sa collision : une trace posée à 1 cm est enterrée.
  Traces au sol relevées de 3,5 cm (murs 1,2 cm), y compris les sommets des grilles projetées.
- Uniformes d'instance (`seche`, `efface`) : à poser APRÈS l'entrée dans l'arbre, sinon le rendu lit une valeur non
  initialisée (trace invisible).
- Les tests de taches orangées au mur (v2 : StandardMaterial teinté × 1,7 sous la torche) disparaissent en v3 : `Sang.trace`
  passe par le shader des traces et la palette (rouge sombre, draugr noirâtre).

## Limites

- Lanceur de test de `captures_sang_v3.gd` : l'épée plantée n'est pas orientée exactement (repères du glb) ; le vrai
  plantage est celui d'ImpactsLances (branche impacts). Le sang (traversée, lame ensanglantée) est indépendant.
- `Sang.traversee` n'est pas répliquée en coop : à diffuser par l'événement d'impact de la branche impacts.
- Neige : la flaque d'un cadavre reste en partie cachée sous le corps (elle s'étale lentement, ~12 s).
- Sang de draugr volontairement sombre : peu visible sur un plancher sombre (lisible sur la neige et la pierre claire).
