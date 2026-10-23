# Donjons — la crypte de Svanhild (plan final, 2026-10-21)

Branche `donjons/crypte`. Fichiers : `scripts/crypte_donjon.gd` (table de modules + récits de salle), `scripts/donjon_kit.gd` (kit réutilisable),
`scripts/crypte_decor.gd` (primitives de décor, dont les nouveaux éléments narratifs), `scripts/tertre.gd` (vestibule, alcôve, herse, intégration,
mécanismes, choix moral), `outils/test_crypte.gd` et `outils/test_crypte_mort.gd`.
Repère de la crypte : x est, z sud ; l'entrée est en z = +4, on s'enfonce vers −Z ; étage −1 : y = −6. La crypte est posée à (−38, −140, −23) dans le monde.

## 1. Histoire et objectifs

L'expédition d'Eirik (frère d'Ylva, quête `frere_ylva`) a forcé la crypte pour l'anneau de Svanhild (quête `anneau_givre`). En brisant les trois
SCEAUX (Os, Givre, Eau) elle a réveillé les morts. Ses compagnons se sont barricadés aux archives, de l'intérieur, et y sont morts. Le prestige
des lieux croît vers le tombeau : vestibule rustique, salles funéraires, trône de glace, antichambre royale, arène, tombeau.

- Objectif principal : tuer Svanhild (`anneau_givre` ; nombre d'étapes inchangé). La porte de l'arène est scellée tant que les trois fragments
  de sceau (Os, Givre, Eau) ne sont pas posés sur les trois socles de la salle rituelle (`Mecanisme.socles`, ident `socles_rituel`).
  Si Svanhild est déjà morte dans la sauvegarde (`tue:svanhild`), la porte est ouverte d'office.
- Facultatif : Jarl Kolbeinn le Gelé (salle du trône) → hache de Kolbeinn.
- Choix moral dans le tombeau (après la victoire) : piller ou respecter les offrandes royales.

## 2. Chiffres

| | avant | après |
|---|---|---|
| surface intérieure (somme des modules) | ≈ 4 990 m² | ≈ 3 580 m² (−28 %) |
| couloirs (hors vestibule) | 254 m | 107 m + 24 m d'escaliers |
| plus long couloir | 44 m (LB2) | 12 m (S2, avec porte barrée et gardien) ; aucun couloir > 12 m sans contenu |
| ennemis | 31 | 35 (dont 6 archers, 2 patrouilles, 6 réveils sur événement, 2 boss avec Svanhild) |
| coffres, urnes et cachettes fouillables | 15 | 28 (24 coffres et urnes, 4 cachettes ; 2 chambres secrètes) |

Test `outils/test_crypte.gd` : surface ≤ 3 700 m², couloirs ≤ 160 m (vérifiés).

## 3. Schéma des étages (non à l'échelle ; le nord est en haut)

### Étage 0

```
                                                    ┌───────────┐
                                                    │  TOMBEAU  │  fresque, offrandes royales, CHOIX MORAL
                                                    │ x12..24   │  (porte coulissante : s'ouvre à la mort de Svanhild)
                              ┌─────────────────────┴─┬─────────┘
   TRÉSOR      GALERIE DES    │         ARÈNE         │   Svanhild, 2 phases ; piliers, estrade, sarcophage (0,-72)
   (secret)    ANCÊTRES       │      x±12  z-80..-62  │
 ┌───────┐    ┌──────────┐    └───────────┬───────────┘
 │jarl   ╪════╡ 3 statues│            ┌───┴────┐
 │3 coffr│pivot  énigme  │            │ANTICH. │  tapis, râteliers, statues, coffre (calme)
 └───────┘    │ 3 gravure│            └───┬────┘
              └────┬─────┘                ╪ porte scellée (frise des 3 sceaux)
                   │ w3 (9 m)         ┌────┴─────┐
                   │                  │ RITUELLE │  vasque, cercle gravé, 3 SOCLES (os / givre / eau)
              ┌────┴────┐ u1 ↓ −6     └────┬─────┘
  secret ═════╡ OSSUAIRE│                  ║ herse (levier dans la salle de préparation)
 ┌─────┐mur   │ autel   │  W1 (6 m)   ┌────┴──────┐                 G4 TRÔNE         G1 SALLE DES GLACES
 │reliq│frag. │ fragment├─────────────┤PRÉPARATION├── G0 (10 m) ──┐  ┌──────────┐    ┌───────────────┐
 └─────┘      │ estrade │             │ 2 tables  │  alcôve       ├──┤  Jarl +  ├─G3─┤ souffles de   │ ↓ d1 vers −1
              └────┬────┘      ╞══ S1 │ levier    │  d'Eirik      │  │  2 archers│8 m │ givre, autel  │
                   │ s1 (11 m, porte barrée)     └────┬──────┘    └──┘          └────┘ du fragment   │
                   └───────────────────────────┐     │ NICHES (12 m : embuscade)                      │
                                               └─────┤                       G2 (9 m) ────────────────┘
                                              ┌──────┴───┐ S2 (12 m, porte barrée)  │
                                              │VESTIBULE ├────────────────────┐ ┌───┴──────────┐
                                              │ fresque  │                    └─┤  QUARTIERS   │ + ARMURERIE secrète
                                              └──────────┘                      │ lits, journal│   (mur fragile)
                                                    ↑ sortie vers le tertre     └──────────────┘
```

Raccourcis en boucle : S1 (ossuaire → couloir des niches) et S2 (quartiers → vestibule), portes barrées côté entrée, qu'on lève depuis la salle.

### Étage −1 (sceau de l'Eau), accessible par `u1` (ossuaire) et `d1` (salle des glaces)

```
                 salle barricadée (lb2b)
                       ┃ (barricade, brèche à l'est)
 CISTERNE (lb3)  lb2w  ┃  ARCHIVES (lb2)    lb2e    CHAPELLE (lb2a)   lb1c    GARDE (lb1)
 ┌─────────────┐ 6 m ┌─┸───────────────┐   8 m   ┌───────────────┐   6 m   ┌──────────────┐
 │ bassin, 4   ╞═════╡ étagères, notes, ╞═════════╡ autel, bancs, ╞═════════╡ tonneaux,    │
 │ braseros,   │dalle│ gravats,        │ dalle   │ inscription   │         │ râtelier,    │
 │ bannières,  │     │ patrouille      │         │ cachette      │         │ archer,coffres│
 │ fragment    │     └────────┬────────┘         └───────────────┘         └──────┬───────┘
 └─────────────┘              │ u1 ↑ ossuaire                                     │ d1 ↑ salle des glaces
```

## 4. Fonction de chaque salle

| id | rôle | contenu |
|---|---|---|
| (vestibule, tertre) | repos | fresque des trois sceaux (objectif lisible), braseros qui guident, sortie |
| `niches` | embuscade | 3 niches, 2 sbires debout dans les niches, os frais, sac éventré, épée brisée |
| `prep` | combat entre obstacles | salle de préparation des morts : 4 piliers, 2 tables d'embaumement, tonneaux d'huiles, levier de la herse gardé (guerrier éveillé), cachette sous la table |
| (alcôve, tertre) | récit | corps d'Eirik, anneau et amulette (inchangé) |
| (couloir de la herse, tertre) | passage | herse, levier côté préparation |
| `rituelle` | hub / énigme | vasque, cercle gravé, plaques des 3 sceaux, 3 socles, porte de l'arène scellée (frise Os/Givre/Eau), rituel interrompu, 2 gardiens de la porte |
| `antichambre` | repos riche | tapis, râteliers, 2 statues de gardes, bannières royales, coffre de la Dame |
| `arene` | boss | Svanhild (2 phases), 6 piliers, estrade à 3 degrés, glace ; porte est scellée jusqu'à sa mort |
| `tombeau` | récit / choix | fresque de Svanhild, autel d'offrandes royales (couronne, coupes, or), statues d'ancêtres, 3 gardiens du serment dormants |
| `w1`, `s1`, `w3` | passages | 6 m, 11,4 m (porte barrée), 9 m |
| `ossuaire` | combat (sceau des Os) | autel d'os + fragment, panneaux d'os, 3 sarcophages dont 1 pillé, estrade d'archer (rampe), piliers ; le gardien des Os se lève au ramassage |
| `ossuaire_secret` | trésor | derrière le mur fragile : reliquaire, or |
| `u1` | escalier | ossuaire → archives (12 m) |
| `reliquaires` | énigme (galerie des ancêtres) | 3 statues à orienter vers 3 gravures (couronne N, navire E, hache S), crâne-indice, sarcophages, coffres → ouvre le mur pivotant du trésor |
| `tresor` | trésor secret | 3 coffres, or, râtelier, 1 gardien |
| `g0` | passage givré | 10 m |
| `g1` | piège (sceau du Givre) | 2 souffles de givre contournables par le sud, dais de glace, autel du fragment, 1 archer, 1 gardien réveillé au ramassage |
| `g2` | passage | 9 m, coffre givré |
| `quartiers` | calme (repos) | lits, râteliers, boucliers, journal de la garde, coffre, cachette (planche) ; mur fragile vers l'armurerie |
| `armurerie` | trésor secret | coffre, râteliers |
| `s2` | passage + raccourci | 12 m, porte barrée côté vestibule, 1 sbire |
| `g3` | piège | 8 m, dalle de pression → fléchettes |
| `g4` | salle du trône (mini-boss facultatif) | trône de glace, Jarl Kolbeinn, 2 archers postés, 3 coffres dont `cof_jarl` (hache unique) |
| `d1` | escalier | glaces → garde (12 m) |
| `lb2` | récit (archives en ruine) | étagères debout/renversées, parchemins, gravats, poutre, registre, cachette, coffre, 1 patrouille |
| `lb2b` | récit (salle barricadée) | barricade de l'intérieur avec brèche, 3 dépouilles, 3 notes (dont l'indice de la cisterne), bagages |
| `lb2w`, `lb2e`, `lb1c` | passages | 6 m (dalle), 8 m (dalle), 6 m |
| `lb3` | énigme (sceau de l'Eau) | bassin, 4 braseros à allumer dans l'ordre des 4 bannières, fragment sur socle, 3 gardiens (1 archer posté, 1 réveillé au ramassage) |
| `lb2a` | calme (chapelle) | autel, inscription, bancs, cachette (pierre descellée), coffre |
| `lb1` | combat / récompense (garde) | 1 patrouille, 1 archer, tonneaux, 2 coffres dont `cof_lb1b` |

## 5. Ennemis (identifiants fixes)

Types existants uniquement (draugr « sbire » / « guerrier » / « squelette » / « squelette_archer »), options de `monde.creer_draugr` :

- archers (`archer: true`, tirent pour de vrai) : `cr_ossuaire_sqa` (**poste** sur l'estrade), `cr_g1_arch`, `cr_g4_arch1/2`, `cr_lb3_arch` (poste), `cr_lb1_arch`.
- patrouilles (`patrouille`, 3 points, en repère monde via `crypte.to_global`) : `cr_lb2_17` (archives), `cr_lb1_15` (garde).
- réveil sur événement (`reveil_evt`) : `cr_ossuaire_gardien` (« ramasse:fragment_sceau_os »), `cr_g1_gardien` (« …givre »), `cr_lb3_noye` (« …eau »), `cr_serment_1..3` (« vague_gardiens », émis par `quetes.choisir("piller_offrandes")`).
- boss : `jarl` (`boss: "jarl"`, ident « jarl » pour `tue:jarl`) ; Svanhild (créée par `tertre._lever_svanhild` avec `boss: "svanhild"`).
- zones calmes (aucun ennemi) : vestibule, alcôve, quartiers, armurerie, chapelle, antichambre, chambre secrète, galerie (sauf un guerrier endormi).
- anciens gardiens d'origine (niches, préparation, tombeau) : désormais `cr_niches_1/2`, `cr_prep_1..3`, `cr_rituelle_1/2` (voir §9).

Liste : niches 2 · prep 3 · rituelle 2 · tombeau 3 · ossuaire 7 · reliquaires 1 · tresor 1 · g1 4 · s2 1 · g4 3 · lb2 1 · lb3 4 · lb1 3 = 35.

## 6. Coffres, cachettes, objets de quête

Coffres (genre `coffre`, identifiant fixe → `quetes.vus["crypte:<id>"]`) : `cof_prep`, `cof_antichambre`, `cof_ossuaire`, `urne_ossuaire`, `cof_mur1`, `cof_reliq1`, `cof_reliq2`,
`urne_reliq`, `cof_tresor1..3`, `cof_g1`, `cof_g2`, `cof_quartiers`, `cof_mur2`, `cof_g4a`, `cof_g4b`, `cof_jarl` (hache de Kolbeinn), `cof_archives`, `cof_lb2b`, `cof_lb3`, `cof_lb2a`, `cof_lb1`, `cof_lb1b`.
Cachettes : `cach_prep` (bandelettes), `cach_quartiers` (planche), `cach_archives` (rayon creux), `cach_chapelle` (pierre descellée).
Fragments (genre `fragment`) : `fragment_os` (autel d'os), `fragment_givre` (autel de la salle des glaces), `fragment_eau` (cisterne, après les braseros).

## 7. Pièges, mécanismes, secrets (appels posés par `tertre._poser_meca`)

| ident | appel | lieu |
|---|---|---|
| `socles_rituel` | `Mecanisme.socles(crypte, 3 positions, [fragment_sceau_os, _givre, _eau], …, on_complet = tertre._ouvrir_arene)` | salle rituelle ; émet `meca:socles_rituel:complet` |
| `statues_galerie` | `Mecanisme.statues(crypte, 3 positions, [0, 1, 2], …, on_resolu = tertre._ouvrir_secret)` | galerie (0 = nord, 1 = est, 2 = sud) ; ouvre le mur pivotant |
| `braseros_cisterne` | `Mecanisme.braseros(crypte, 4 positions, [2, 0, 3, 1], …)` | cisterne (ordre montré par les bannières) ; débloque `fragment_eau` |
| `mur_ossuaire`, `mur_quartiers` | `Mecanisme.mur_fragile(crypte, pos centre, taille (0,6 × 3 × 2,4), 0, …, ctx.materiau)` | murs fragiles (coup puissant) : fissures + courant d'air |
| `souffle_g1a`, `souffle_g1b` | `Piege.souffle_givre(crypte, pos, dir, 10, période 4,2 / 3,1, …)` | salle des glaces (bouches dans le mur nord ; givre au sol = zone balayée) |
| `piege_g3`, `piege_lb2w`, `piege_lb2e` | `Piege.dalle_flechettes(crypte, pos_dalle, pos_bouche, dir, …)` | couloirs (dalle fendue + os devant + plaque percée en face) |

Portes mobiles du donjon : `s1`, `s2` (portes barrées, `quetes.vus["crypte:s1"]`), `arene` (porte scellée), `tombe` (s'ouvre à `tue:svanhild`), pivot `secret` (galerie → trésor).
Chaque callback est rappelé à la création si l'état est déjà acquis (`Mecanisme.restauration`) ; `Mecanisme.restaurer_tout(crypte)` est appelé à la mort du joueur.

## 8. Choix moral (tombeau)

Deux interactions devant l'autel d'offrandes : « Piller les offrandes » → `quetes.choisir("piller_offrandes")` (pièces, reliques d'offrande, événement `vague_gardiens` : les trois gardiens
du serment se lèvent) ; « S'incliner devant les ancêtres » → `quetes.choisir("respecter_offrandes")` (Bénédiction des ancêtres, +10 vie max, sauvegardée). Définitif.

## 9. Sauvegardes

- Identifiants de salles conservés : `ossuaire`, `reliquaires`, `tresor`, `g1`–`g4`, `s1`, `s2`, `w1`, `w3`, `u1`, `d1`, `lb1`, `lb2`, `lb2a`, `lb3`, `arene`. Supprimés : `s3`, `g5`, `g6` (et leurs gardiens), `lb2` long couloir (devenu salle).
- Coffres conservés avec leurs identifiants et leur butin : `cof_ossuaire`, `urne_ossuaire`, `cof_reliq1/2`, `urne_reliq`, `cof_tresor1..3`, `cof_g1`, `cof_g2`, `cof_g4a/b`, `cof_lb1`, `cof_lb2a`, `cof_lb3`. Nouveaux : voir §6.
- Gardiens conservés : `cr_ossuaire_1..3`, `cr_ossuaire_sq1/sq2/sqa`, `cr_reliquaires_5`, `cr_tresor_8`, `cr_g1_9/10`, `cr_s2_11`, `cr_lb1_15/16`, `cr_lb2_17`, `cr_lb3_18/19`.
  Les gardiens de la partie d'origine (couloir des niches, salle des piliers, tombeau) n'avaient pas d'identifiant et n'étaient pas réinitialisés à la mort : ils passent par la file d'apparition du donjon
  (identifiants fixes, apparition à l'approche, retour à zéro à la mort) ; un ancien `draugrs_morts` de ces gardiens (« sbire_12 »…) est simplement ignoré.
- Ancien crâne pivotant : `crypte:secret` reste honoré (mur déjà ouvert dans une ancienne partie) ; la nouvelle ouverture passe par `meca:statues_galerie:resolu`.

## 10. Kit de modules (`scripts/donjon_kit.gd`)

Principe : une salle = un MODULE, un dictionnaire de données ; la crypte = la table `CrypteDonjon.plan()` (liste de modules + liaisons + accroches à identifiants fixes).
Le module est écrit en repère LOCAL (centre de la salle, +x est, +z sud) ; `CrypteDecor.xf` le pose dans la crypte (translation, quarts de tour, miroir) : tout décor passe par `quad()`,
`solide()`, `lumiere()`, `flamme()`… qui appliquent ce transform. Ce n'est PAS un générateur aléatoire : chaque salle est dessinée à la main dans la table, avec ses variantes figées.

Champs d'un module :

| champ | sens |
|---|---|
| `id`, `type` | identifiant fixe de zone ; `salle`, `couloir` (axe z local, 3,2 m de large) ou `escalier` (haut à −z local) |
| `o`, `y`, `dim`, `h` | centre (x, z), hauteur du sol (0 ou −6), dimensions locales sur la grille 1/2/4 m, hauteur sous plafond |
| `rot`, `miroir` | quarts de tour (0–3), symétrie gauche/droite |
| `graine` | RNG propre au module (même graine = même salle, indépendante de l'ordre de construction) |
| `theme` | `tombeau`, `ossuaire`, `givre`, `glace`, `eau`, `tresor`, `garde` (matières) |
| `role` | `combat`, `enigme`, `repos`, `tresor`, `piege`, `recit`, `passage` (documente et pilote les décors par défaut) |
| `usure` | 0 intact, 1 fissuré (fissures, gravats), 2 effondré en partie (gravats, jamais sur un passage) |
| `ouv` | `[côté local N/S/E/O, décalage, largeur, secret?, module relié]` ; `verifier()` contrôle que deux modules reliés ont des ouvertures qui coïncident |
| `lum` | `{braseros: n, appliques: n}` : 4 à 6 lumières par salle, sans ombre (teinte et énergie tirées dans une plage par la graine) |
| `garnitures` | décors génériques : `piliers`, `panneaux_os`, `sarcophages`, `estrade` (avec rampe), `couverts`, `oculus` |
| `extra` | méthode de récit propre à la salle (`_x_*`) |
| `ennemis`, `coffres`, `interactions`, `meca` | points d'accroche gameplay (identifiants fixes), écrits en repère de la crypte puis convertis en local |

Variantes (une graine fixée par module dans la table, rendu stable) : jeu de décor tiré dans la liste du thème (os, armes, urnes, crânes), état d'usure, miroir gauche/droite, position des couverts et des piliers
parmi les emplacements valides (`libre()` évite les passages et les accroches), teinte et intensité des lumières dans une plage, petits accessoires (toiles, glaçons, congères). Les accroches gameplay
(portes, coffres, mécanismes, ennemis) sont réservées avant tout décor aléatoire : elles restent atteignables quelle que soit la variante (contrôlé par `test_crypte.gd`).

Pour un autre donjon : sous-classer `DonjonKit`, écrire sa table (`plan()`) et ses récits `_x_*`, appeler `module()` pour chaque entrée puis `verifier()`.
Limites : l'escalier n'est orienté que le long de Z (rot 0 ou 2) ; les pièces uniques (vestibule, alcôve d'Eirik, herse, arène, tombeau) gardent des récits spécifiques.

## 11. Décor narratif ajouté (`CrypteDecor`)

`statue` (guerrier, jarl, ancêtre, gardienne), `socle`, `embleme` / `frise` (symboles gravés : os, givre, eau, couronne, navire, hache, épée, soleil, cercle, triangle, croix, vague), `banniere` (intacte, déchirée, en lambeaux, teintée),
`chaine`, `table_embaumement`, `barricade` (avec brèche toujours libre), `lit`, `ratelier_armes`, `bouclier_mural`, `autel`, `bassin`, `parchemins_epars`, `etagere_renversee`, `gravats`, `fissures`, `dalle_fendue`,
`sarcophage_pille`, `sac_dechire`, `coffre_force`, `tapis`, `trone`. Aucune nouvelle matière : matières existantes seulement (pas de nouvelle texture, `CrypteTextures.VERSION` inchangée).

## 12. Tests

`bash outils/tous_les_tests.sh` (dont `test_crypte` : remplissage de la crypte par une capsule — escaliers et rampes compris —, chaque salle, coffre, interaction, mécanisme et ennemi atteignable, aucun ennemi dans un mur,
liaisons des modules, surface, lumières, portes fermées bloquantes, escaliers franchis par une capsule physique ; `test_crypte_mort` : réinitialisation à la mort, y compris les gardiens d'origine).
Options de `test_crypte.gd` : `--plan` (zones, ennemis, interactions, mécanismes), `--carte [--bas]` (carte ASCII des cases atteintes).

## 13. Crypte v2 : refonte graphique, salle rituelle + couloir des niches (2026-10-22, branche `crypte_v2/salle_couloir`)

Référence : `references/crypte_v2_planche.png` (vues 2 « salle principale », 3 « couloir », 6 « salle de tombeau »), prompt `references/crypte_v2_prompt.md`.
Pilotes : la salle `rituelle` (hub, vasque, socles, porte scellée de l'arène) et le couloir `niches`. Salles, ouvertures, collisions (sauf le sarcophage ajouté),
interactions, ennemis, mécanismes et quêtes sont INCHANGÉS. Les autres modules ne sont pas touchés (extension après validation).

### Activer le style v2 sur un module (table de données)

Ajouter au dictionnaire du module dans `CrypteDonjon.plan()` une clé `"v2": {...}` (constantes `V2_NICHES`, `V2_RITUELLE` en tête de `crypte_donjon.gd`).
Le kit (`DonjonKit.module`) remplace alors les dalles `dalle0` par `dalle_v2` (thème) et délègue l'habillage à `scripts/crypte_v2.gd` (`CrypteV2.salle` / `CrypteV2.couloir`).
Les positions sont en repère de la crypte (comme les accroches) et converties en repère local. Champs (valeurs par défaut dans `CrypteV2.DEFAUTS`) :

| champ | sens |
|---|---|
| `piliers` | salle : abscisses locales des piliers + arches le long des murs longs (ignorés devant une ouverture ou une applique). Couloir : un pilier/arche tous les 4 m, automatique |
| `pilier`, `naissance`, `arche` | modules Blender du pilier et de l'arche, hauteur de naissance de l'arche (= hauteur du pilier) |
| `panneaux`, `haut_panneau` | panneaux de maçonnerie en relief (0,22 m) sur tous les murs libres, jusqu'à `haut_panneau`, corniche au sommet |
| `lustres` | lustres de fer (module `lustre_fer`) comme le décor de base (1 à 3 selon la surface) |
| `statues`, `sarcophages`, `candelabres`, `bannieres` | `[{pos, lacet, ...}]` ; sarcophage : collision par défaut (boîte), statue : sans collision sauf `collision: true` ; bannière rouge à croix dorée (`CrypteDecor.banniere`, sujet `croix`) |
| `eboulis`, `dalles` | `[{pos, mod, lacet}]` : tas de pierres et dalles soulevées |
| `flaques` | `[{pos, r, graine}]` : **PLACEHOLDER d'eau** (polygone sombre plat, matière `flaque`). Emplacement réservé : `CrypteDecor.eau_slots` (centre + rayon) ; le système d'eau (branche eau/prototype) n'a qu'à lire cette liste ou remplacer `CrypteDecor.flaque()` |
| `givre` | nombre de décalques de givre au sol (hors angles) |

### Modules Blender (`sources_blender/scripts/crypte_modules_v2.py`)

`blender.exe -b --python sources_blender/scripts/crypte_modules_v2.py` (rejouable, graines fixes) écrit `assets/crypte/modules/crypte_v2.dat` (lu par
`CrypteDecor.modele()` via FileAccess : sûr dans le fil de construction), `crypte_v2.glb` (export de référence) et `sources_blender/crypte_modules_v2.blend`.
Chaque module = pierre taillée par assises irrégulières (blocs aux arêtes abattues, sommets bougés, inclinés de quelques degrés), couleurs de sommet cuites
(ton de chaque bloc x occlusion ambiante par rayons) ; objets nommés `module__matiere` (`pierre`, `fer`, `cire`, `bois`) et `module__pts` (points de flamme).
Repère Godot, origine au pied, `+z` = face avant (vers la pièce). `CrypteDecor.modele(nom, pos, lacet, echelle, mats)` verse les triangles dans les tampons
de matière existants (fusion par cellule de 8 m : aucun nœud en plus) avec UV triplanaires en mètres.

| module | usage |
|---|---|
| `pilier_mur_1p6`, `_3p2`, `_6` | pilier engagé (saillie 0,34 m), socle à ressauts, assises, chapiteau |
| `colonne_mur_3p2`, `_6` | demi-colonne à tambours (disponible, pas encore posée) |
| `arche_2p0`, `arche_4p0`, `arche_10p7` | arc en voussoirs (portée, flèche) ; plein cintre ou surbaissé |
| `pan_mur_a/b/c`, `pan_mur_haut` | panneaux de maçonnerie 1,8 / 2,6 / 3,4 m x 3 m (4,4 m) |
| `eboulis_a/b/c`, `dalles_a/b/c` | tas de pierres, dalles soulevées |
| `sarcophage`, `statue_capuche`, `candelabre`, `lustre_fer` | objets de la planche |
| `marches_3p0` | volée de 4 marches usées (disponible pour les escaliers) |

### Textures (`CrypteTextures`, `VERSION` inchangée = 13 ; seuls les nouveaux .res sont ajoutés)

- `dalle_v2` : dalles IRRÉGULIÈRES (Voronoï à joints gauchis, ton/inclinaison/usure par dalle, fissures, éclats, graviers et givre dans les joints, poussière et plaques humides), 128 texels/m.
- `pierre_v2` : pierre nue des modules (grain fin, strates, piqûres), 128 texels/m, sans joints.
- `givre_sol` : décalque de givre au bord déchiqueté (alpha tout ou rien), remplace les plaques de neige rectangulaires du sol.
- Régénérer : `godot --headless --path . --script res://outils/generer_crypte.gd -- --seulement=dalle_v2,pierre_v2,givre_sol` ; aperçu : `outils/previsu_textures_crypte_v2.gd`.
- Pour changer le dessin d'une de ces textures après coup, régénérer ses .res (la VERSION n'a pas été bumpée pour ne pas réécrire les 40 autres fichiers).

## 14. Crypte v2 dans TOUTES les salles (lot C4, 2026-10-23, branche `C/crypte_v2`)

Référence : `references/crypte_v2_planche.png` + `references/crypte_v2_prompt.md`. Les 31 modules du kit (salles, couloirs, escaliers) sont en v2 ;
le vestibule, l'alcôve d'Eirik et le couloir de la herse (bâtis par `tertre.gd`) sont passés en v2 au lot C4b (§15). `-- --crypte-v1` rend toujours l'ancienne crypte (captures « avant »).

- **Activation** : `CrypteDonjon.plan()` ajoute `"v2": {}` (ou `V2_SALLES[id]`) à chaque module sans table. Les deux pilotes validés gardent leur table
  avec `"auto": false` (rien de neuf n'y est placé, à part la vasque v2 et la pierre plus claire des statues).
- **Mode auto** (`CrypteV2.salle` puis `CrypteV2.finir`, appelé par `DonjonKit.module()` APRÈS le récit `_x_*` et les garnitures) :
  statues encapuchonnées contre les murs (nombre selon la surface, `statues_auto` pour forcer) avec candélabre et bougies ; éboulis, dalles soulevées,
  flaques ; urnes, crânes, bougies au pied des murs ; givre (plus dans les salles froides) ; piliers engagés + arche mise à la portée sur les murs
  longs (sauf salles à piliers isolés et salles de plus de 16,5 m de large) ; panneaux de maçonnerie autour de tout ce qui est plaqué au mur ;
  bannières rouges à croix (bleues dans les salles froides) si le récit n'en pose aucune.
  Le placement évite passages, accroches (ennemis, coffres, interactions, mécanismes) ET les boîtes de collision posées par le récit (`_boites_sol`).
- **Objets plaqués au mur** : `CrypteDecor.occupations` (râteliers, étagères, panneaux d'os) → pas de panneau derrière ; `saillie_cb` avance
  bannières, boucliers, gravures, frises et fissures devant les panneaux (jamais dans une ouverture). Murs fragiles, bouches de souffle et de
  fléchettes (table `meca`) et `v2.reserves` gardent leur mur nu.
- **Primitives v2** (quand `CrypteDecor.v2`) : `pilier()` → `pilier_libre_5/8`, `arc()` → `arche_*` étirée, `sarcophage()` → module sculpté,
  `statue()` → pierre `statue_v2` ; `_g_estrade` → `estrade_3x4` ; vasque du rituel → `vasque_rituel`, autel des Os → `autel_octo`,
  degrés de l'arène → `degres_arene` ; escaliers : piliers engagés sous les arcs. TOUTES les collisions restent les boîtes d'avant.
- **Statues mieux éclairées** sans dépasser le budget : matière `statue_v2` (ambiant ×4,4 au lieu de ×2,6, teinte plus claire) ; et une lumière
  basse (0,5 m, devant le socle) seulement si la salle a moins de 6 lumières et si aucun maillage voisin n'en voit déjà 6 (test_crypte : 7 par
  salle, 8 par maillage).
- **Emplacements d'eau (lot C5)** : `tertre.eau_slots()` → `[{centre (repère crypte), rayon, module, genre, taille}]`, genres `flaque`
  (placeholder sombre posé), `vasque` (bassin du rituel, surface à 0,74 m), `bassin` (citerne lb3, `taille` = intérieur), `flaque_froide`
  (sous les oculus et sur l'estrade de l'arène). Le système d'eau remplace `CrypteDecor.flaque()` ou lit cette liste.
- **Perf de construction** : `CrypteDecor.modele()` cache les triangles par module et les transforme en bloc ; les modules de plus de 3 m sont
  répartis triangle par triangle dans les cases de 8 m (sinon l'AABB d'un maillage grossit et touche plus de 8 lumières).
- **Outils** : `outils/sonde_crypte_v2.gd` (sans fenêtre) : ce que le mode auto a posé par salle, la liste des emplacements d'eau,
  `--zone=<id>` (lumières comptées par test_crypte), `--maillage=<nom>` (lumières qui touchent un maillage).

## 15. Crypte v2 : fin du lot (C4b, 2026-10-23, branche `C/crypte_v2_fin`)

- **Pièces de `tertre.gd`** : `CrypteV2.tertre_debut(d)` + `CrypteV2.piece_tertre(d, id, x0, x1, z0, z1, hauteur, ouvertures, table)` habillent
  vestibule, alcôve d'Eirik et couloir de la herse en mode pilote (table explicite, comme la salle rituelle) ; collisions, interactions, lumières inchangées.
- **Statues** : `statue()` de type `ancetre/capuche/gardienne` → module sculpté `statue_capuche` (même collision) ; matière `statue_v2` avec
  « lueur » d'hémisphère du shader (`lueur_haut` / `lueur_bas`, `CrypteDecor.LUEUR_STATUE_*`) : modelé lisible SANS lumière de plus.
- **Sarcophages** : module `sarcophage` sculpté, `sarcophage_svanhild` pour le tombeau de l'arène (même collision) ; `socle()` → `socle_v2`.
- **Socles des sceaux (mécanisme du rituel)** : `_x_rituelle` verse `socle_v2` à l'encombrement du socle v1 ; `Mecanisme.socles` reçoit
  `ctx["socles_habilles"]` (posé par `tertre._poser_meca`) et ne crée plus que le creux, le fragment, sa lueur et la collision.
- Perf (14 vues de la crypte, moyenne de 2 passes A / 3 passes B) : GPU +0,08 ms en moyenne, +0,31 ms au pire vs ed4a8b2.
