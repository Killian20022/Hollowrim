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
