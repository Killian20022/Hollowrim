# Accueil du joueur et quêtes qui racontent (nuit du 2026-11-04)

## Accueil (nouvelle partie)
- `scripts/narration.gd` : écran de texte plein cadre (prologue, 4 pages, `data/quetes.json` → `textes.prologue`). E / Espace / clic = suite, Échap = passer. Le joueur est « en dialogue » pendant l'écran ; le jeu n'est pas en pause.
- Fin de l'arrivée → événement `prologue_vu` → quête discrète `bienvenue` (« Parler à Gunnar, à la longue maison », marqueur de boussole sur Gunnar) + cartouche des touches (60 s, F1) + bulles d'aide actives.
- `scripts/aides.gd` : bulles contextuelles, une fois chacune (premier ennemi à l'écran, sort en main, premier coffre, rappel menu/carte après 45 s). Sauvegardées (`aides_vues`) ; une sauvegarde sans cette clé = joueur averti, aucune bulle. Option : Options → « Bulles d'aide » (`Jeu.option("jeu", "aides")`).
- Jamais en mode outil/test (`Jeu.mode_outil()`), sauf `--prologue` (accueil + fin de chapitre) et `--aides` (bulles).

## Quêtes (moteur `scripts/quetes.gd`, ids inchangés)
- Quête discrète (`"discrete": true`) : ni « Nouvelle quête » ni fanfare ni XP.
- Premier déclencheur `fini:<quête>` : une quête peut commencer à la fin d'une autre (`horizon_sud` après `anneau_givre`). Les parties déjà avancées la reçoivent au chargement (`_rattraper`).
- `"apres"` (data/quetes.json) : répliques des villageois selon l'état (`fini:`, `en_cours:`, `etape:q:e`, `vu:evt`, `maison`, `choix`, `!` pour nier, `&` pour combiner) ; première entrée vraie, sinon les « apres » fixes de villageois.json.
- Une conversation fait avancer et fait parler TOUTES les quêtes concernées (la plus avancée dans le récit d'abord).
- Fin du premier chapitre : `fini:anneau_givre` → écran « Svanhild dort » (monde.gd `_sur_evenement_histoire`) puis quête-teaser `horizon_sud` (Kaldborg, le Sire Ottar, Porte du Sud ; `Lieux.CIBLES["lieu:chateau"]`).
- Alignement sur `docs/BIBLE_TRAME_BIOMES.md` (acte I) : Eirik et quatre compagnons, croissant fendu (lettre d'Eirik, registre de Hrafn), Sigrún donneuse des sceaux, amulette de givre unique (plus en butin), Manteau de loup d'Ylva.

## Tests
`test_quetes`, `test_prologue` (accueil, bulles, apres, fin, compat sauvegardes), `test_sauvegarde`, `test_migration_v2`. Captures : `outils/captures_accueil.gd`.

## Quêtes sans combat (branche `gameplay/quetes_sans_combat`, 2026-11-11)
Deux mini-récits du Val de Skarnholt, sur le thème de la bible (*la dette envers les morts, et ce qu'on tait*), joués par
le dialogue, l'heure, l'observation du décor et un vrai choix. Aucune des fins n'est « la bonne ».

### « Le grenier qui maigrit » (`grenier_maigre`, donneuse Grima)
1. **Grima** (de jour, à la 2e conversation, après Solveig) : deux sacs disparaissent chaque semaine du grenier commun ; au puits, on
   accuse déjà la lavandière, bientôt l'étranger. Elle veut savoir la première.
2. **Serrure du grenier** (bâtiment `grenier`, « Examiner la serrure ») : intacte, graissée ; des balles d'orge filent vers
   l'est. Deux clés : Gunnar et Haldor. *Facultatif* : **Haldor** avoue qu'il dort parfois à la porte et a vu, avant l'aube,
   une lanterne partir vers les fermes, « comme quelqu'un qui rentre chez lui ».
3. **Grange de l'est** (`grange_a`, « Fouiller la paille ») : une trappe, onze sacs rangés, le **bâton de taille** de Gunnar.
4. **Gunnar** avoue : un sac sur trois mis de côté pour le mois noir, sans quoi on mangera la semence. Il demande le silence.
5. **Grima, le choix** : *Dire la vérité* (le puits se calme mais la réserve fond ; Gunnar −20 « trahi » ; 2 pains de seigle)
   ou *Mentir : « Des rats… »* (la réserve est sauve, la suspicion reste sur la lavandière ; Grima −8 « mensonge »,
   Gunnar reconnaissant ; +60 pièces de Gunnar). 120 XP.
   Conséquences : réplique « une fois » puis « après » de Grima et Gunnar, Haldor qui ne dort plus, causeries
   (`grenier_verite`, `grenier_verite_puits`, `grenier_silence`), et la **trappe de la grange** : ouverte et vidée après
   la vérité, recouverte de paille après le silence (`scripts/recits_village.gd`).

### « L'écorce au fil rouge » (`fil_rouge`, donneuse Sigrún)
1. **Sigrún** (une fois les sceaux confiés ET Ylva rencontrée) : la nuit où Eirik est parti, il n'était pas seul au cercle ; elle a regardé
   sans rien faire. Elle a gravé ce qu'elle a vu sur une écorce (`ecorce_sigrun`) qu'il faut remettre à Ylva **le soir**.
2. **Ylva** : le jour, « Pas maintenant. Ce soir, au feu. » ; de **18 h 30 à 21 h 30** (son planning : le feu de la place),
   elle reconnaît le fil rouge et attend.
3. **Le choix** (trois lieux, trois fins) : *Lui tendre l'écorce* (Ylva, le soir ; elle retient « une femme au capuchon de
   renard, venue du sud » ; deux versions selon qu'elle sait déjà son frère mort ; talisman d'os, +10 chasseurs),
   *Jeter l'écorce dans le foyer* (Brodd, qui parle du fer qu'il aurait dû fondre et donne un anneau de cuivre ; Sigrún −5),
   *Lui rendre l'écorce : « Dis-le-lui toi-même »* (Sigrún ira au feu ; 2 potions de mana, +10 cercle de Sigrún).
4. **Sigrún** clôt la quête (fil coupé net, odeur de bouleau, ou « Ce soir, au feu »). 100 XP.
   Conséquences : répliques d'Ylva, de Sigrún et de Brodd, causeries `ecorce_renard` et `ecorce_feu`.

### Moteur (ajouts, rétrocompatibles)
- `data/quetes.json` : `"choix"` d'une quête = options de dialogue `{id, pnj, index, si?, texte, repond, effets?, puis?,
  exige?, refus?}` (offertes par `ServicesPnj.options` → `Quetes.options` quand la quête est à `index` et que les filtres `si`
  de RepliquesFiltrees passent ; valider signale `issue:<quête>:<id>`). Une étape porte `"issues": {"<évt>": {journal,
  recompense}}` : le journal et la récompense suivent l'issue retenue (`Quetes.issue`, `Quetes.recompense_de`, lue par
  l'onglet Quêtes). `"remis"` = objets repris à la fin (comme la constante REMIS). Étapes : `"pnj"` / `"cible": [x, z]` pour
  le repère de boussole et de carte (`Lieux.cibles_quetes`).
- Effets de répliques : `retirer`, `disposition_pnj` (mémoire d'un autre PNJ), `avis`. Filtre `pas_vu` (RepliquesFiltrees) :
  avec l'effet `signaler: "dit:<id>"`, une réplique de conséquence n'est dite qu'une fois. Mémoire de disposition :
  `trahi` (−20), `mensonge` (−8) dans `data/disposition.json`.
- Sauvegarde : rien de nouveau, l'issue est un événement de `vus` (déjà sauvegardé).

Tests : `test_quetes_sans_combat` (chaque fin par le vrai dialogue, heure, indices, journal par issue, disposition, après,
causeries, repères, aller-retour JSON). Captures : `outils/captures_quetes_sans_combat.gd`.
