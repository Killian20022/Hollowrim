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
