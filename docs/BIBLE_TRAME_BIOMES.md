# HOLLOWRIM — Bible de trame et des biomes (2026-11-04)

Statut : proposition d'écriture, déléguée par l'utilisateur. Aucun fichier du jeu n'a été modifié.
Elle sert de base à la carte agrandie (×4 en surface, chunks de 80 m) et aux futures quêtes.

Sources lues : `AUDIT_2026-11-04.md`, `AUDIT_2026-11-04_histoire.md`, `audit_grille_creneau.md`, `plan_donjons.md`, `nordique/docs/{DONJONS, PLAN_CARTE_DE_BASE, PLAN_VILLAGE_V2, BIBLE_VISUELLE, DIRECTION_ARTISTIQUE}.md`, `nordique/data/{quetes,villageois,habitants,gardes}.json`, `scripts/rpg/lieux.gd`.

Règles de fidélité (rien de ce qui suit ne les casse) :
- Le mythe de Svanhild, les 3 sceaux (Os, Givre, Eau), Kolbeinn et la crypte sont intacts.
- Les ids de quêtes, d'objets et de PNJ ne changent pas (sauvegardes).
- Les deux donjons restent distincts, sans liaison.
- Pas de nouvelle créature exotique : on décline l'existant et on note les manques.
- Repère : x vers l'est, z vers le sud (le nord est -Z).

---

## 1. Pitch, thème, ton

### Pitch (5 lignes)
Skarnholt est un hameau d'une quarantaine d'âmes, tout au bord d'un monde de neige et d'aurores.
Un anneau a disparu de la tombe de Svanhild, la reine-guerrière : les morts se lèvent pour le reprendre.
Tu es l'étranger qui arrive au feu, et tu rends l'anneau.
Mais quelqu'un de bien vivant avait payé pour qu'on le vole : le Sire de Kaldborg, au sud, qui veut commander le froid.
Entre landes de tombes, mines de bandits et fjord gelé, il faudra remonter la piste de l'or jusqu'au château.

### Thème
**La dette envers les morts, et l'oubli.**
- La fresque de la crypte le dit déjà : « Ce n'est pas la haine qui la relevait. C'est l'oubli. »
- Svanhild se lève parce que plus personne ne dit son nom.
- Chaque acte pose la même question sous une forme différente : qui doit quoi à qui, et qui s'en souvient ?

### Ton
- Sombre nordique : froid, silence, humour sec des gens qui ont enterré la moitié du village.
- Un peu de chaleur humaine : la soupe de Grima, les bougonneries de Brodd, la bière tiède des gardes.
- La chaleur est le contrepoint voulu du froid. Chaque lieu hostile doit avoir son feu, quelque part.
- Écriture courte (modèle : les textes de donjon), peu de grands discours, pas d'ironie moderne.

### Ce qui distingue Hollowrim de Lunacid et de Dread Delusion
Les points ci-dessous viennent de l'audit : `audit_grille_creneau.md` et le bulletin de l'audit histoire.

| | Lunacid | Dread Delusion | Hollowrim |
|---|---|---|---|
| Univers | Gothique-cosmique hétéroclite, peu de gens | Archipel psychédélique, politique, ironique | **Un seul mythe nordique cohérent**, réaliste dans ses matières |
| Humain | Quasi absent | Factions et intrigues | **Un hameau vivant qu'on protège et qui change** après tes actes |
| Combat | Reproché : « clunky » | Reproché : raide | **Sensation de mêlée : point fort du jeu** (audit) |
| Quêtes | Peu | Fortes, sans combat | Mini-récits, voies multiples, **conséquence visible au village** |
| Ambiance | Étrange | Étrange | **Aurores, neige bleue, feu chaud** : le contraste froid / chaleur |

Promesse : moins étrange que ses cousins, plus tenu et plus humain. Durée visée : 6 à 8 h (Lunacid : 8-10 h, chiffre non vérifié).

---

## 2. Trame principale

### 2.1 Le canon (ce qui est vrai dans le monde)

**Svanhild**
- Fille de pêcheurs de la côte ouest, devenue reine par l'épée.
- Trois hivers de suite, elle brisa les raids du nord sur la glace du fjord.
- À sa mort, on enferma son givre dans un **anneau** et son sommeil sous **trois sceaux** : Os (la mémoire), Givre (le silence), Eau (l'oubli).

**Kolbeinn**
- Jarl de la garde de glace. Son serment tient les gardiens de la crypte.

**Les compagnons d'Eirik**
- Cinq jeunes têtes brûlées : Eirik, Halfdan, Bera, Orm, Tjorvi.
- Ils sont partis forcer la crypte il y a environ quinze jours.

**Ce que l'anneau fait vraiment** (nouveau, caché jusqu'à l'acte II)
- Il ne fait pas que « dormir » : il **commande la Garde de glace**, les morts froids de tous les tertres entre le fjord et les monts.
- Quiconque le porte avec les trois éclats de sceau réunis peut les lever et les mener.
- Svanhild ne s'en est jamais servie. Elle l'a fait sceller *contre* elle-même.

**Kaldborg (« Château-Froid »)**
- Le château du sud, visible à l'horizon, en (244 ; 548).
- Il tient les hameaux du nord par une dîme et des convois (sel, peaux, fer).

### 2.2 L'antagoniste vivant : Sire Ottar de Kaldborg
- Notable de la Marche, lettré, aimable, poli. Il n'élève jamais la voix.
- Il n'est ni un monstre ni un fou. Il pense sauver les siens.
- **But** : des hivers de plus en plus durs vident les caisses de Kaldborg et lui attirent des rivaux au sud.
  - Avec la Garde de glace, il ne serait plus un vassal contesté : il serait *le* seigneur du Nord.
  - Il lèverait les morts comme une armée qui ne mange pas.
- **Moyens**
  - Valdis, sa colporteuse, parle à Eirik et lui promet de l'or pour l'anneau.
  - Il paie Hrafn pour affamer les convois et pousser Skarnholt à la soumission.
  - Il envoie ses receveurs et ses soldats pour la dîme.
- **Signature** : un sceau de cire au **croissant fendu**, qui apparaît sur la lettre de Valdis, sur le registre de Hrafn et sur les bannières de la Marche.
- **Faiblesse** : il a besoin des *trois éclats* ET de l'anneau. L'anneau est revenu sur la tombe, les éclats sont sur les socles. Il doit donc voler ou tromper.

### 2.3 L'enjeu au-delà du hameau
- Skarnholt n'est que le premier maillon : trois autres hameaux dépendent des mêmes convois, et la Garde de glace dort sous les landes.
- Si Ottar réussit, tout le Nord appartient à un seigneur qui n'a plus de limite, ni vivante ni morte.
- Cela donne un compte à rebours naturel à l'acte III : la dîme, puis les soldats, puis la marche d'Ottar.

### 2.4 Rôle des 3 sceaux (en jeu)
- **Acte I** : clé d'une porte. Les éclats ouvrent l'arène de Svanhild (déjà codé).
- **Acte II** : cible. On découvre qu'ils *servent* à lever la Garde. Valdis tente de les reprendre.
- **Acte III** : choix. Quand on réunit anneau et éclats, le joueur décide de leur sort (voir 2.6).

Les trois sceaux sont aussi des repères thématiques :
- Os = mémoire. Ce qu'on garde d'un mort.
- Givre = silence. Ce qu'on tait.
- Eau = oubli. Ce qu'on laisse partir.

### 2.5 Le fil Gunnhild → Sigrún → crypte → château
1. **Gunnhild** envoie au cercle chercher qui a pris l'anneau (réplique ajoutée : « Va voir Sigrún d'abord. Elle sait lire ce qui dort là-bas. »).
2. **Sigrún** donne la quête des sceaux (elle devient donneuse, le démarrage automatique reste en secours). Elle explique les trois sceaux *avant* l'entrée, et lâche la clé de l'acte II : « L'anneau n'a pas été volé pour sa valeur. Quelqu'un voulait ce qu'il commande. »
3. **Crypte** : sceaux → Svanhild → anneau rendu. Dans la bourse d'Eirik, une lettre porte le **croissant fendu**.
4. **Retour** : Gunnhild reconnaît le sceau, c'est celui de la dîme. Elle avoue ce qu'elle cachait (voir fiche Gunnhild). Le château devient une direction, pas un décor.
5. Le **registre de Hrafn** porte le même croissant : la piste est confirmée.

### 2.6 Les trois actes et leurs jalons jouables

**Acte I — « Le froid qui revient »** (≈ 1 h 30, contenu actuel remis en ordre)
- Zones : Val de Skarnholt, Landes des Gisants (cercle, tertre), crypte.
- Jalons :
  1. Arrivée au feu (prologue court, objectif : la longue maison).
  2. Gunnhild → Sigrún → cercle.
  3. Premier combat guidé (un draugr isolé).
  4. Camp d'Eirik, tertre, vestibule, fresque.
  5. Trois éclats, socles, arène de Svanhild.
  6. Anneau rendu, scène à l'aube avec Gunnhild et Sigrún.
- Fin d'acte : la lettre au croissant fendu, et une première lueur rouge au sud.

**Acte II — « Ce qui se paie »** (≈ 2-3 h, surtout nouveau contenu)
- Zones : Monts du Fer (Hrafn, mine), Anse des Pêcheurs (Tjorvi, Reidun), Forêt Noire (Gué, Ylva).
- Jalons :
  1. Hrafn et son registre (nom de Valdis, nom du Gué).
  2. Le déserteur Tjorvi dit la vérité sur Eirik.
  3. Le Gué des Corbeaux : Ketil, péager corrompu.
  4. Valdis (capturée, achetée ou tuée) révèle ce que fait l'anneau.
  5. Milieu d'acte : **les éclats disparaissent des socles** (volés par des hommes de Valdis passés par la brèche du fjord). Svanhild se rouvre sans se relever : l'anneau refroidit.
  6. Les soldats de la dîme arrivent au village.

**Acte III — « Le Sire descend »** (≈ 1-2 h)
- Zones : Marche du Château, Porte du Sud, Kaldborg en vue.
- Jalons :
  1. Poste de la Cloche (Odd) et passage de la Marche.
  2. Récupération des éclats dans le camp de levée.
  3. Rencontre avec Ottar, en deux phases :
     - un face-à-face parlé, très tendu ;
     - un combat contre lui et sa garde levée.
  4. **Choix du sort de l'anneau**, trois voies :
     - *Rendre* : le sommeil reprend, mais l'oubli guette.
     - *Briser* : les morts partent en paix, mais plus rien ne protège contre le froid des landes.
     - *Confier à Gunnhild* : la Garde de glace défend Skarnholt, au prix d'un serment qui pèsera.
  5. Retour au village : fête sobre et **Pierre-Souvenir** gravée du nom de Svanhild sur la place.

**Teaser de fin**
- Dans la cave d'Ottar, un escalier descend vers un vide immense : *le Creux*. Une cloche sonne, très bas.
- Sigrún : « Kaldborg n'a pas été bâti sur du roc. Il est bâti au bord de quelque chose. » (« Hollowrim » = *le bord du Creux* : à valider avec l'utilisateur.)
- La Porte du Sud, jusque-là barrée, s'ouvre. Les 308 m jusqu'au château deviennent jouables dans une suite.

### 2.7 Corrections des incohérences relevées par l'audit

| Incohérence | Décision | Travail |
|---|---|---|
| **Eirik seul** (Brodd, Haldor, Gunnhild) vs **compagnons barricadés** (notes de crypte) | Eirik est le chef d'une troupe de cinq. Il est parti en expédition, a pris l'anneau, a fui seul chercher du secours, est repassé au village, puis est revenu à la crypte pour rendre l'anneau et mourir de froid dans l'alcôve. Les autres sont morts barricadés (Tjorvi a déserté et a survécu). | Haldor : « Il est passé en courant. Les quatre autres étaient partis avant lui. » Ylva : « parti avec quatre têtes brûlées ». Note compagnon 3 : remplacer « tenu jusqu'au bout » par « parti nous chercher du secours ». ~1 h de texte. |
| **L'arc d'Ylva** | Le joueur n'a pas d'arc. | Ligne « Garde ton arc bandé » → « Garde ta lame haute ». Ylva donne son arc plus tard (voir sa fiche). |
| **Peau de loup promise, jamais donnée** | Récompense nommée. | « Manteau de loup d'Ylva » à la fin de `frere_ylva`. |
| **`expedition_sigrun` vs Sigrún (la voyante)** | Ne pas renommer l'id ni `journal_sigrun` / `broche_sigrun` (sauvegardes). Seuls les textes affichés changent. | Noms affichés : « Journal de Solveig », « Broche de Solveig ». Si un renommage d'id est voulu un jour, passer par une table d'alias dans `migrateState`. |
| **`amulette_givre` aussi en butin** (`camp_a`, `mine_eboulis`) | Elle redevient unique : récompense de `anneau_givre`. | Remplacer le butin par « Pendentif de mineur » et « Talisman d'os » (objets de valeur, sans effet unique). |
| **Quête de Sigrún sans donneur** | Sigrún devient donneuse de `sceaux_brises`. | Une réplique chez Gunnhild + une chez Sigrún. Déclencheur automatique conservé. |
| **Indice Hrafn trop caché** (seulement dans l'« après » de Haldor) | Mention dès les premières lignes. | Un ajout dans `lignes`. |
| **« Le jarl paie en bière tiède »** (gardes) | « Jarl » est le surnom que les gardes donnent à Gunnhild (à confirmer). Le vivant du sud s'appelle *Sire*. | Aucun changement de texte. |

---

## 3. Personnages

Format : désir / peur / secret / réplique-type. Les répliques sont écrites dans la voix déjà établie.

### 3.1 PNJ existants

**Gunnhild Aldrsdotir — cheffe de Skarnholt (`chef`)**
- Désir : garder ses quarante âmes en vie jusqu'au printemps.
- Peur : être la dernière cheffe, celle sous qui le hameau s'éteint.
- Secret : elle paie à Kaldborg une dîme qui vide les réserves, et elle a caché l'état des greniers. Les convois volés *sont* la dîme.
- Réplique : « Je préfère payer que pleurer. Mais là, je n'ai plus de quoi payer. »

**Brodd le Large — forgeron (`forgeron`)**
- Désir : forger *une* lame dont il soit fier, avant que ses bras lâchent.
- Peur : avoir mis un mort sur la route d'Eirik en refusant de chauffer l'anneau (il croit qu'il aurait dû le détruire).
- Secret : il a tenu l'anneau une minute. Il a *entendu* sa voix. Il n'en parle jamais.
- Réplique : « Du fer, pas de discours. Mais ce fer-là, je l'ai entendu parler. »

**Ylva Frostmark — chasseuse (`chasseuse`)**
- Désir : savoir. Pas consoler, savoir.
- Peur : être seule et utile à personne. Elle chasse pour ne pas penser.
- Secret : elle a vu partir son frère et ne l'a pas retenu. Elle lui a taillé l'amulette en os de cerf *pour qu'il revienne*.
- Arc : colère, puis deuil, puis tutrice du joueur. Elle apprend à pister (acte II), puis, quand son arc devient disponible côté jeu, elle le lui confie (acte III).
- Réplique : « Chut. Les bêtes savent déjà que tu es là. »

**Sigrún la Voyante — Völva (`volva`)**
- Désir : mourir en ayant réparé les sceaux.
- Peur : que les runes aient toujours raison.
- Secret : elle a vu Valdis parler à Eirik et n'a rien dit, croyant « lire le destin ». Elle porte cette faute.
- Réplique : « Les runes montrent. Elles ne retiennent la main de personne. »

**Haldor Quatre-Yeux — garde de la porte (`garde`)**
- Désir : une saison sans paperasse de deuil.
- Peur : la nuit où la cloche sonnera et où il ne sera pas à son poste.
- Secret : il a laissé passer Eirik sans l'arrêter, la nuit où l'anneau brillait dans sa main, parce qu'il avait sommeil.
- Réplique : « Je tiens la porte. Toi, tu as des jambes. »

**Grima Cendrefroide — doyenne du puits (`ancienne`)**
- Désir : savoir ce qui est arrivé à Solveig.
- Peur : mourir sans l'avoir su.
- Secret : sa grand-mère a *posé* Svanhild dans la tombe, avec la lignée des pêcheurs. Elle sait que le nom de Svanhild se perd, et elle le répète à voix basse en tirant l'eau.
- Réplique : « Tire-moi un seau, petit. L'eau, elle, se souvient. »

**Eirik** (mort, voir l'alcôve)
- A voulu « bien faire » : l'or de Valdis devait payer la dîme de Skarnholt. Il est mort de l'avoir fait.

**Solveig** (morte, mine)
- Curieuse, rieuse. Elle a écrit son journal comme on laisse un mot sur la table.

**Hrafn** (chef bandit, `repaire_hrafn`)
- Désir : l'or. Peur : le fond de la mine.
- Secret : il ne travaille pas seul, il est payé par Kaldborg. Répliques déjà écrites (« Mon or… »).

**Svanhild et Kolbeinn**
- Voir 2.1. Ils ne vivent que par les textes. Ne pas les faire parler plus que ce qui existe.

**Gardes anonymes et habitants** (`gardes.json`, `habitants.json`)
- Ils sont le chœur du hameau. Ne pas leur donner de quêtes avant le chantier PNJ.
- À glisser : les gardes de la nuit parlent d'une lueur rouge au sud (acte II), puis des soldats (acte III).

### 3.2 Nouveaux PNJ (6)

**1. Sire Ottar de Kaldborg** — antagoniste (voir 2.2)
- Désir : un Nord à lui. Peur : redevenir un vassal parmi d'autres.
- Secret : il a *vu* le Creux et il en a peur.
- Réplique : « Je ne vole rien. Je mets de l'ordre dans ce que vous ne savez pas garder. »

**2. Valdis la Colporteuse** — agent d'Ottar
- Tient un étal sur la route des convois, puis au village.
- Désir : la liberté d'acheter sa propre dette à Kaldborg. Peur : Ottar.
- Secret : elle a vraiment aimé Eirik. Elle l'a vendu quand même.
- Ambiguë : on peut la tuer, la convaincre ou la protéger.
- Réplique : « Tout se vend. Même ce qu'on croit donner. »

**3. Tjorvi le Déserteur** — survivant de l'expédition
- Vit seul dans une cabane de l'Anse.
- Désir : qu'on lui dise qu'il n'y est pour rien. Peur : la nuit, la porte qui gratte.
- Secret : c'est lui qui a brisé le sceau de l'Eau, puis qui s'est enfui.
- Réplique : « J'ai entendu leurs voix derrière la porte. C'étaient les leurs. Et j'ai couru. »

**4. Reidun la Passeuse** — gardienne de l'Anse
- Vieille pêcheuse, descendante de la lignée de Svanhild, dernière à dire son nom sur la côte.
- Désir : que la lignée soit enfin *lue*. Peur : l'oubli.
- Secret : elle possède l'amulette jumelle de la reine (tresse de lin et d'os).
- Réplique : « On ne meurt pas deux fois. On meurt quand le dernier qui dit ton nom se tait. »

**5. Ketil Gué-Noir** — péager du Gué des Corbeaux
- Désir : sortir de la solde de Hrafn. Peur : perdre sa petite fille, qui vit au Gué.
- Secret : c'est lui qui tient les relais des convois.
- Réplique : « Je ne vole personne. Je regarde ailleurs. Ça coûte moins cher. »

**6. Odd le Sonneur** — veilleur de la Marche
- Ancien soldat de Kaldborg, déserteur. Il garde la cloche du Poste, seule alerte de la Marche.
- Désir : sonner une dernière fois pour une bonne raison. Peur : qu'on sache d'où il vient.
- Secret : il connaît la poterne du sud d'Ottar.
- Réplique : « Une cloche, c'est un mensonge qu'on dit tous ensemble : "il ne se passe rien." »

---

## 4. Biomes de la carte agrandie

### 4.1 Hypothèse d'emprise (à valider avec `Monde.etendue`)
- La carte actuelle couvre à peu près -120..+120 m (cercle (-38 ; -34), grotte (92 ; -27), moulin (95,5 ; 13) tiennent dedans).
- ×4 en surface = ×2 en longueur : **480 × 480 m, de -240 à +240, soit 6 × 6 chunks de 80 m.**
- Si le socle choisit un autre cadre, la disposition garde son sens : on décale la grille.
- Le château (244 ; 548) reste **hors carte**, en arrière-plan, à environ 308 m du bord sud.
- Chunk d'un point = (floor(x/80) ; floor(z/80)). Le village (44 ; 40) est dans le chunk (0 ; 0).

### 4.2 Schéma ASCII

Colonnes A à F = x. Lignes 1 à 6 = z. Chaque case = 80 × 80 m = 1 chunk. Entre parenthèses, l'indice du chunk (cx ; cz).

```
          x:  -240      -160       -80         0        80        160       240
               A         B          C          D         E          F
z -240 ┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
   1   │ LANDES  │ LANDES  │ LANDES  │ MONTS   │ MONTS   │ MONTS   │  (-3)
       │ (-3;-3) │         │         │ DU FER  │ cascade │ tanière │
z -160 ├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
   2   │ LANDES  │ LANDES  │ LANDES  │ MONTS   │ MONTS   │ MONTS   │  (-2)
       │ nourrice│ Pierre- │ des Noms│ guetteur│ étais   │ col     │
z  -80 ├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
   3   │ ANSE    │ LANDES  │ LANDES  │  VAL    │ MONTS   │ MONTS   │  (-1)
       │ glace   │ faille  │ ◉CERCLE │ nord    │ ◉GROTTE │         │
       │         │         │ ◉TERTRE │ village │ (92;-27)│         │
z    0 ├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
   4   │ ANSE    │ ANSE    │  VAL    │ ◉SKARN- │  VAL    │  VAL    │  (0)
       │ hameau  │ fumoir  │ lac gelé│ HOLT    │ moulin  │ champs  │
       │ noyé    │ Reidun  │ (-22;46)│ (44;40) │ (95;13) │         │
z   80 ├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
   5   │ ANSE    │ FORÊT   │ FORÊT   │ FORÊT   │ MARCHE  │ MARCHE  │  (1)
       │ épave   │ NOIRE   │ ◉GUÉ    │ cerf    │ camp de │         │
       │ Tjorvi  │         │ (-10;150)         │ levée   │         │
z  160 ├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
   6   │ ANSE    │ FORÊT   │ FORÊT   │ MARCHE  │ MARCHE  │ MARCHE  │  (2)
       │         │ toiles  │ tronc-  │ chapelle│ ◉CLOCHE │ ◉PORTE  │
       │         │         │ pont    │ brûlée  │ (150;180)DU SUD   │
z  240 └─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
                                                              │
                         ... ~308 m de landes grises (hors carte) ...
                                                              ▼
                                                CHÂTEAU KALDBORG (244 ; 548)
```

Chunks par biome (36 au total) :

| Biome | Cases | Nombre |
|---|---|---|
| Landes des Gisants | A1 B1 C1 A2 B2 C2 B3 C3 | 8 |
| Monts du Fer | D1 E1 F1 D2 E2 F2 E3 F3 | 8 |
| Val de Skarnholt | D3 C4 D4 E4 F4 | 5 |
| Anse des Pêcheurs | A3 A4 B4 A5 A6 | 5 |
| Forêt Noire | B5 C5 D5 B6 C6 | 5 |
| Marche du Château | E5 F5 D6 E6 F6 | 5 |

Axes et distances (à vol d'oiseau, estimations depuis les constantes de `lieux.gd`) :
- Village → cercle : ≈ 110 m. Village → grotte : ≈ 82 m. Feu (0 ; 0) → village : ≈ 60 m.
- Village → Gué des Corbeaux : ≈ 120 m. Village → Anse (-200 ; 60) : ≈ 245 m.
- Village → Poste de la Cloche : ≈ 160 m. Village → Porte du Sud : ≈ 280 m.
- Porte du Sud → château : ≈ 310 m. Village → château : ≈ 545 m.
- Routes :
  - **Piste du feu** (village → feu → cercle).
  - **Chemin de la grotte** (porte nord → Monts).
  - **Route des convois** (village → Forêt Noire → Gué → Marche → Porte du Sud).
  - **Piste côtière** (Val ouest → Anse).
- Course à 6,5 m/s : la traversée la plus longue (Anse → Porte du Sud, ≈ 500 m) dure ≈ 80 s en ligne droite. L'audit note qu'un extérieur vide se traverse trop vite : les reliefs, les falaises, les lisières denses et les POI doivent allonger les trajets réels.
- Densité cible : un POI tous les 60-80 m sur les routes principales.

### 4.3 Val de Skarnholt (existant, centre)
- **Ambiance** : hameau chaud dans la nuit bleue, feux, fumées droites. Le seul biome « sûr » et la mesure de tous les autres.
- **Palette PS1** : Neige crépuscule, Épicéa Aiguilles, Bois Travaillé, Tourbe Chaume, Braise Flamme aux fenêtres. Aucun nouvel écart par rapport à la zone témoin validée.
- **Végétation / roches** : épicéas, pins, bouleaux épars, rochers enneigés, chaumes de champs gelés.
- **Faune** : vaches, taureau, chevaux, âne, husky (existants) ; cerfs et biches en lisière ; renards. Ylva dit que cerfs et loups ont fui vers le sud : ils reviennent en fin d'acte.
- **Ennemis** : très peu, une meute de loups entre village et cercle (selon le chasseur). Reste de refuge.
- **POI et secrets**
  - Longue maison, forge, puits de Grima, place : inchangés.
  - **Pierre-Souvenir** (46 ; 44), absente au début, gravée en fin de partie.
  - Étable et enclos de la ferme (76 ; 22) : cache d'une trappe à grain.
  - Sentier du lac gelé (-22 ; 46) : palissade basse, raccourci vers la Forêt Noire.
- **Lien à la trame** : tout y revient. Les conséquences visibles s'y affichent.

### 4.4 Landes des Gisants (nord-ouest)
- **Ambiance** : plateau ventée, brume basse, lueurs vertes la nuit, croassements. La mémoire des morts : tertres, menhirs, offrandes rouillées.
- **Palette PS1** : Pierre froide, Végétation sèche brun-rouge givrée, Neige crépuscule, Runes cyan (rares), fond de ciel d'aurore. Pas de bleu saturé en grands aplats.
- **Végétation / roches** : bruyère morte, genévriers nains, bouleaux tordus, menhirs penchés, tertres couverts de neige, pierres à cupules.
- **Faune** : renards, corbeaux (manque : oiseaux animés à prévoir), loups en lisière. Aucun cerf (ils ont fui).
- **Ennemis** : draugrs (sbire, guerrier, ancien), squelettes et squelettes archers autour des tertres, gardiens du serment (rares). Patrouilles lentes, jamais plus de trois d'un coup.
- **POI et secrets**
  1. **Camp d'Eirik** (-70 ; -60) : tentes, cendres, journal d'Halfdan. Premiers indices de l'expédition.
  2. **Pierre des Noms** (-60 ; -120) : menhirs gravés, la plupart illisibles. Le nom de Svanhild est presque effacé. Quête Reidun.
  3. **Tumulus de la Nourrice** (-150 ; -130) : mini-donjon de 3 salles, casque de la Garde de glace. Entrée cachée sous un cairn.
  4. **Faille des Vents** (-110 ; -30) : raccourci vers l'Anse via une gorge, ouvert après le tertre.
  5. **Alignement des Veilleurs** (-190 ; -200) : cadran de pierres qui s'allument à l'aurore, énigme optionnelle.
- **Lien à la trame** : acte I (cercle, tertre), puis acte II/III (la Garde de glace dort ici ; sans anneau, ses tertres s'ouvrent).

### 4.5 Monts du Fer (nord-est)
- **Ambiance** : falaises dures, vent, neige poudreuse, échos. Le biome des bandits, de l'or sale et du travail ancien.
- **Palette PS1** : Pierre froide, Fer, Bois gris neigé (étais), Glace des cascades, lanternes Braise.
- **Végétation / roches** : pins rabougris, éboulis, parois lisses, filons visibles, glaçons, cascades gelées.
- **Faune** : loups, araignées (toiles « larges comme des voiles », selon le chasseur), chèvres (**manque**), aigles (**manque**), **ours** (**manque**, à trouver ; en attendant, loup massif).
- **Ennemis** : bandits (sbires, guerriers), bandits archers sur corniches, Hrafn. Un troll de givre rôde dans la grotte (déjà existant) ; en extérieur, un seul, annoncé comme le troll du donjon.
- **POI et secrets**
  1. **Grotte / vieille mine** (92 ; -27) : déjà là. Hrafn et son camp.
  2. **Poste des guetteurs** (60 ; -100) : plate-forme de bandits qui surveille la route des convois. Les éliminer *ou* les contourner change la quête de Hrafn.
  3. **Étais du Haut** (150 ; -110) : seconde entrée de mine, ouvre un passage à sens unique vers la corniche du camp (à valider : ne casse pas le plan « sans autre liaison »).
  4. **Cascade gelée** (130 ; -190) : cache derrière la glace, coffre de mineur.
  5. **Tanière de l'ours** (200 ; -200) : tanière (modèle manquant), objet « Griffes de l'ours » (récompense).
- **Lien à la trame** : acte II. Le registre et le croissant fendu y sont trouvés.

### 4.6 Anse des Pêcheurs (ouest et sud-ouest)
- **Ambiance** : fjord gelé, brume salée, mouettes, barques échouées. Le plus mélancolique : c'est ici que Svanhild est née.
- **Palette PS1** : Glace, Bois mort, Neige crépuscule, ciel lavande, lanternes Braise rares. Les quelques runes cyan sont ses seules couleurs vives.
- **Végétation / roches** : roseaux gelés, galets, pins du rivage, épaves, filets, séchoirs à poisson.
- **Faune** : renards blancs, husky (traîneaux), mouettes et phoques (**manque**), cerf isolé.
- **Ennemis** : noyés (draugr « anciens » à texture mouillée, pas de nouvelle créature), araignées côtières rares, mercenaires de Valdis à l'acte II.
- **POI et secrets**
  1. **Hameau noyé** (-200 ; 40) : maisons de pêcheurs prises par la glace. Maison natale de Svanhild.
  2. **Fumoir de Reidun** (-130 ; 70) : abri chaud, feu, barque, la Passeuse.
  3. **Épave du drakkar** (-220 ; 110) : navire pris dans la glace, chambre scellée.
  4. **Cabane de Tjorvi** (-190 ; 150) : refuge du déserteur.
  5. **Glace des Trois Hivers** (-225 ; -20) : champ de bataille de Svanhild, runes dans la glace (jamais d'effet d'eau : glace fissurée, sans animation).
- **Lien à la trame** : acte II. Origine de Svanhild, mémoire, preuve de l'expédition, brèche du fjord par laquelle les éclats sont volés.

### 4.7 Forêt Noire (sud-ouest et sud)
- **Ambiance** : épicéas serrés, lumière rare, silence épais. Les animaux fuyant le Nord sont ici, nerveux.
- **Palette PS1** : Épicéa Aiguilles dominant, Écorce brun-gris, Neige sombre (ombres violettes), lueur Braise des relais de convois.
- **Végétation / roches** : épicéas très denses, chablis, souches, fougères sèches, rochers moussus de neige.
- **Faune** : cerfs et biches (nombreux), loups (meutes), renards, sanglier (**manque**, à trouver), araignées de forêt (toiles), chevaux des convois.
- **Ennemis** : loups, araignées, éclaireurs de Hrafn avant la quête, bandits du Gué.
- **POI et secrets**
  1. **Pavillon d'Ylva** (-60 ; 120) : cabane de chasse, étal de peaux.
  2. **Gué des Corbeaux** (-10 ; 150) : péage, rivière gelée, pont de rondins. Ketil.
  3. **Clairière du Cerf blanc** (30 ; 110) : cerf blanc intouchable (quête sans combat).
  4. **Arbre aux toiles** (-110 ; 190) : nid d'araignées géantes, coffre de chasseur.
  5. **Tronc-pont** (-30 ; 200) : tronc tombé, raccourci qui évite le Gué.
- **Lien à la trame** : acte II. Route des convois, rouages de la dîme, enquête sur les animaux qui fuient.

### 4.8 Marche du Château (sud-est)
- **Ambiance** : terres rases, vent, brume grise, lueur rouge à l'horizon. Aucun repos : on est sur le domaine d'Ottar.
- **Palette PS1** : Pierre sombre, Fer, Laine rouge sombre (bannières), brume bleu nuit, Braise rouge à l'horizon. Peu de neige, un sol plus gris.
- **Végétation / roches** : herbes sèches, haies d'épines, bornes de pierre, ruines de poste, palissades militaires.
- **Faune** : chevaux de guerre (existants), loups affamés, corbeaux (**manque**).
- **Ennemis** : soldats de Kaldborg (corps humains existants, tabard au croissant fendu), mercenaires de Valdis, Garde de glace levée (draugrs guerriers renforcés), Ottar.
- **POI et secrets**
  1. **Camp de levée** (110 ; 130) : camp de la dîme, caisse des éclats à l'acte II.
  2. **Poste de la Cloche** (150 ; 180) : Odd, cloche, alerte.
  3. **Chapelle brûlée** (40 ; 190) : refuge, journal d'un soldat, cache.
  4. **Pont des Longs Adieux** (190 ; 200) : pont de pierre, embuscade ou passage secret dessous.
  5. **Porte du Sud** (230 ; 235) : barrière de pierre, scellée jusqu'au teaser. Au-delà, le château.
- **Lien à la trame** : acte III. Face-à-face avec Ottar.

---

## 5. Quêtes (14)

Règles :
- Les ids des quêtes existantes restent. Les nouvelles prennent des ids fixes.
- Récompense nommée à chaque fois.
- Conséquence visible au village à chaque fois.
- Les quêtes marquées « après PNJ » dépendent des routines et horaires (chantier village vivant).

### Principales
**Q1. L'anneau de givre** (Val → Landes → crypte) — existante, remise en ordre
- Donneur : Gunnhild. Étapes : inchangées (6). Ajout : « Va voir Sigrún » avant le cercle.
- Récompense : « Amulette de givre » (unique), 200 XP, 150 pièces.
- Conséquence : les aurores se calment, les gardes quittent leur ronde de nuit en armure.

**Q2. Les sceaux brisés** (crypte) — existante
- Donneuse : Sigrún (déclencheur automatique conservé).
- Étapes : fresque, trois éclats, trois socles, porte de l'arène.
- Récompense : « Rune d'aurore de Sigrún » (amulette), 250 XP.
- Conséquence : Sigrún sort de sa tente le soir et regarde le sud.

**Q3. Le repaire de Hrafn** (Monts) — existante, **voies multiples**
- Donneur : Haldor. Voies :
  - *Frontale* : tuer Hrafn.
  - *Furtive* : voler le registre sans le réveiller.
  - *Négociée* : racheter le registre à Hrafn (exige de la réputation ou beaucoup d'or).
  - *Sabotage* : couper les relais du Gué (lien Q11).
- Récompense : « Lunettes de neige de Haldor », 200 XP, 120 pièces.
- Conséquence : le premier convoi arrive au village, l'étal de sel rouvre.

**Q4. Ce qui se paie** (Monts → Anse → Forêt → village) — principale acte II
- Donneur : Gunnhild (après le croissant fendu).
- Étapes : suivre le registre → trouver Tjorvi et Valdis → apprendre ce que fait l'anneau → constater le vol des éclats.
- Récompense : « Sceau de Gunnhild » (laissez-passer de la Marche), 300 XP.
- Conséquence : soldats de la dîme visibles au village, bannières au croissant fendu.

**Q5. Le Sire descend** (Marche) — principale acte III, **voies multiples**
- Donneur : Gunnhild, puis Odd. Voies :
  - *Combat* : affronter Ottar et sa garde levée.
  - *Exposer* : montrer le registre et la lettre devant ses vassaux et ses soldats.
  - *Retourner* : utiliser l'anneau et les éclats pour retourner la Garde contre lui.
  - Dans tous les cas : choix du sort de l'anneau (rendre, briser, confier).
- Récompense : « Anneau de la Garde » (ou son absence), 600 XP.
- Conséquence : fêtes sobres, Pierre-Souvenir, nouvelle bannière.

### Secondaires existantes (récompenses nommées)

**Q6. Le frère d'Ylva** (Landes) — arc d'Ylva
- Donneuse : Ylva. Étapes : camp d'Eirik, amulette, retour.
- Récompense : « Manteau de loup d'Ylva », 120 XP, 60 pièces.
- Conséquence : Ylva accroche l'amulette d'Eirik à la porte de son pavillon.

**Q7. L'expédition de Solveig** (Monts) — partiellement sans combat
- Donneuse : Grima. Étapes : journal, broche, retour (l'îlot est atteignable sans combat).
- Récompense : « Lanterne de mineur de Solveig », 150 XP, 90 pièces.
- Conséquence : une lanterne neuve brûle toute la nuit au puits.

Autres existantes, sans changement de structure :
- **Le fer des morts** (Brodd) : « Épée de Skarnholt ». Conséquence : l'épée au râtelier, la forge réputée.
- **Le Jarl gelé** (facultative) : « Hache de Kolbeinn ». Conséquence : Gunnhild la regarde avec respect.

### Nouvelles secondaires

**Q8. Le sel qui tarde** (Anse) — **sans combat**
- Donneuse : la fermière (mari parti chercher du sel à la côte).
- Étapes : suivre la piste côtière → trouver Aslak, bloqué par la glace chez Reidun → l'aider à ramener le sel (escorte ou traîneau).
- Récompense : « Sac de sel de la côte » (objet de valeur), 100 XP.
- Conséquence : une saline fumante au village, soupe plus salée chez Grima.
- Après PNJ.

**Q9. La dernière barque** (Anse → Landes → Val) — **sans combat**
- Donneuse : Reidun.
- Étapes : écouter l'histoire de Svanhild → lire les noms à la Pierre des Noms → rapporter une pierre gravée.
- Récompense : « Amulette jumelle de Svanhild » (nouvel objet), 150 XP.
- Conséquence : Pierre-Souvenir sur la place, qui se grave au fil de la quête.

**Q10. Le déserteur** (Anse) — **voies multiples**
- Donneur : Tjorvi (ou rencontre).
- Voies :
  - *Pardonner* : lui offrir de rentrer au village avec Ylva.
  - *Livrer* : le rapporter à Gunnhild comme témoin.
  - *Le faire témoigner* : le convaincre de parler à Ylva elle-même.
- Récompense : « Hache de bûcheron de Halfdan », 150 XP.
- Conséquence : selon la voie, Ylva le recueille, le fait emprisonner, ou le protège.
- Après PNJ.

**Q11. Le péage du Gué** (Forêt) — **voies multiples**
- Donneur : Ketil.
- Voies :
  - *Payer* le péage.
  - *Furtif* : passer par le Tronc-pont.
  - *Combat* : tuer les gardes du Gué.
  - *Dénoncer* Ketil à Gunnhild.
- Récompense : « Clé du relais » (ouvre un coffre de convoi), 120 XP, 80 pièces.
- Conséquence : route ouverte ou marchands plus nombreux au village.

**Q12. La meute sans peur** (Forêt) — **sans combat**
- Donneuse : Ylva.
- Étapes : suivre les traces des bêtes → observer la clairière du Cerf blanc sans effrayer → comprendre qu'elles fuient la Marche.
- Récompense : « Arc d'Ylva » (quand le tir à l'arc existe ; sinon « Carquois du pisteur »), 140 XP.
- Conséquence : cerfs et biches reviennent paître autour des fermes.

**Q13. La cloche d'Odd** (Marche) — **sans combat**
- Donneur : Odd.
- Étapes : se glisser jusqu'au Poste de la Cloche → récupérer le battant volé → sonner la cloche au bon moment (pour couvrir une fuite).
- Récompense : « Plan de la poterne » (objet clé de l'acte III), 150 XP.
- Conséquence : la cloche de la tour de Skarnholt se met à sonner juste.

**Q14. Les étals du Nord** (Val) — après PNJ
- Donneuse : Valdis (si épargnée) ou Gunnhild.
- Étapes : tenir un étal de colporteur pendant une journée du hameau (livraisons, prix, vols).
- Récompense : « Étal de Valdis » (boutique permanente), 100 XP.
- Conséquence : un étal supplémentaire sur la place.

### Récapitulatif
- Sans combat obligatoire : Q8, Q9, Q12, Q13 (et en grande partie Q7, Q2).
- Voies multiples : Q3, Q5, Q10, Q11.
- Réparties : Val (Q1, Q14), Landes (Q6, Q9), Monts (Q3, Q7), Anse (Q8, Q10), Forêt (Q11, Q12), Marche (Q5, Q13).

---

## 6. Notes d'intégration
- **Lieux** : ajouter chaque POI à `Lieux.LIEUX` (une ligne chacun) ; la carte et la boussole s'adaptent. Types à ajouter à `TYPES` : `anse`, `gue`, `poste`.
- **Moteur de quêtes** : les déclencheurs existants (`parle:`, `lieu:`, `ramasse:`, `tue:`, `objet:`, `meca:`, `choix:`) suffisent. Utiliser le champ `carte` pour les étapes sans cible évidente.
- **Ennemis par zone** : niveau fixe par biome (Q2 de `CONCEPTION_RPG.md`). Ordre de danger croissant suggéré : Val (1) < Forêt (3-4) < Landes (4-6) < Monts (5-7) < Anse (6-7) < Marche (8-10).
- **Ordre de construction des chunks** : Val + Landes + Monts (déjà couverts par l'existant) d'abord ; puis Forêt Noire ; puis Anse ; Marche en dernier.
- **Manques de faune/modèles à trouver** : ours, sanglier, chèvre, oiseaux (corbeaux, mouettes, aigles), phoques. En attendant, doublures de loup/cerf.
- **Ne pas toucher** : les ids de quêtes et d'objets, les positions de `Lieux` existantes, le plan des deux donjons, le moteur de `quetes.gd`.
- **À valider par l'utilisateur** : le sens du mot « Hollowrim », l'emprise exacte de la carte, la deuxième entrée de mine (Étais du Haut), la voie « briser l'anneau ».
