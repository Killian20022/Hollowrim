# Chantier RPG — contrat du socle (lot 0)

Posé le 2026-11-02 sur la branche `rpg/socle` (depuis `biome/zone-temoin` 2f5c383). Conception complète :
`C:\Users\lopezk19\Jeux\conception_rpg\CONCEPTION_RPG.md`. Ce document est le **contrat** que les lots A à E respectent :
format des données, API (noms et signatures figés), signaux, sauvegarde, propriété des fichiers. Changer une signature ou
un format ici = prévenir Max avant.

## 1. Décisions validées par l'utilisateur (toutes les recommandations)

| Q | Choix |
|---|---|
| Q1 c | Compétences à l'usage → niveau du personnage ; les quêtes donnent aussi de l'XP ; par niveau : +10 vie / magie / vigueur au choix + 1 point d'arbre |
| Q2 a | Difficulté fixe par région (pas de mise à l'échelle des ennemis) |
| Q3 b | Emplacements : tête, torse, mains, pieds, collier (cou), anneau ; le bouclier reste en main gauche |
| Q4 a | Armure **non visible** sur le héros pour l'instant |
| Q5 a | Sac 150 qui grandit avec la vigueur (+5 par choix), armes allégées, surcharge = lent / pas de course (jamais bloqué) |
| Q6 b | ~55 perks sur 8 pierres ; réinitialisation chez Sigrún pour 500 pièces |
| Q7 a | Enchantements seulement sur des objets trouvés (écrits à la main) |
| Q8 a | Pas d'usure ; forge de Brodd : +1 / +2 / +3 avec pièces + minerais (identifiant dérivé `epee_soldat+2`) |
| Q9 c | Coffre loué chez Grima dès le début + maison à acheter (~1500 pièces) ; coffres du monde = prendre seulement |

**État au lot 0** : le jeu est identique pour le joueur (capacité 100, poids inchangés, aucun perk, aucune UI nouvelle).
Le recalage 150 / poids des armes est au lot A.

## 2. Registre unique des objets — `data/objets/*.json`

Un seul endroit pour les fiches (fin des 5 sources) : `data/objets/<fichier>.json` = `{"_doc": …, "objets": {id: fiche}}`,
**un fichier par catégorie** (pas de conflit entre lots). Les 20 armes famille × matériau restent dans
`data/armes/catalogue_armes.json` (fiches calculées par `CatalogueArmes.fiche_objet`, consultées après le registre).
Les anciens emplacements `Inventaire.OBJETS` (constante) et `data/butin/objets.json` n'existent plus (même contenu,
mêmes identifiants, mêmes poids / valeurs : vérifié par `test_rpg_socle`).

| Fichier | Contenu | Propriétaire |
|---|---|---|
| `armes.json` | armes écrites à la main (épées or / rubis / verre / obsidienne / Croc-Rouge, Skarnholt, hache de Kolbeinn) | A |
| `armures.json` | (vide) armures tête / torse / mains / pieds | A |
| `bijoux.json` | amulette de givre (cou, sans effet pour l'instant) | A |
| `consommables.json` | potions, nourriture, tomes | A (effets) / personne d'autre |
| `ingredients.json` | os, poussière de tombe, minerais, cristal, champignon, fourrure, croc, écaille | A / E (forge : lecture) |
| `quete.json` | clés, fragments de sceau, journaux, registre, broche, anneau de givre, amulette d'Eirik | — (quêtes) |
| `divers.json` | lame antique, relique, anneau de cuivre, coupe, collier d'or | A |

Fiche (tous les champs sauf `nom`, `poids`, `valeur`, `categorie`, `rarete` sont facultatifs) :

```json
"casque_fer": {
  "nom": "Casque de fer",
  "categorie": "armure",          // arme | armure | bijou | consommable | ingredient | quete | divers  (Inventaire.CATEGORIES)
  "rarete": "commun",             // commun | peu_commun | rare | unique  (ButinTables.COULEURS_RARETE)
  "poids": 4.0, "valeur": 45,
  "emplacement": "tete",          // armure / bijou : tete | torse | mains | pieds | cou | anneau  (Inventaire.EMPLACEMENTS)
  "type_armure": "lourde",        // lourde | legere (arbre « Armure », lot B)
  "armure": 12,                   // points d'armure
  "icone": "casque",              // motif IconesCombat (sinon losange de rareté ; arme sans motif : épée)
  "effets": {"resist_froid": 0.1},// clés §3 ; consommables : vie / mana / vigueur / duree / famille / apprendre (inchangé)
  "quete": false,                 // explicite : invendable, non lâchable, non déposable ; toute fiche de valeur 0 (hors consommable) l'a
  "description": "…"
}
```

Règles :
- **Jamais de renommage** d'identifiant ; nouvelle fiche = nouvel id. Si un renommage devient inévitable : ligne dans
  `Inventaire.ALIAS` (ancien → nouveau), lue par tous les `importer()` et par la migration. On n'en retire jamais une ligne.
- Identifiant dérivé de la forge (lot E) : `<id>+<n>` ; `Inventaire.objet()` devra le résoudre (lot E ajoute ce cas dans
  `Inventaire.objet`, en tête, sans toucher au reste).
- **Butin : toute nouvelle entrée EN FIN de table** (`data/butin/*.json`) : les tirages sont à graine fixe, une entrée
  insérée au milieu change le contenu des coffres déjà vus. `test_rpg_socle` le vérifie contre
  `outils/donnees_test/butin_empreinte.json` (ne modifier ce fichier que pour y AJOUTER des tables neuves).
- Objets de départ (`epee`, `torche`, `bouclier`, `vide`) : hors du sac, toujours disponibles, sans poids (inchangé).

## 3. Clés d'effets (communes)

Additionnées par `EquipementCorps.effets_totaux()` (valeurs numériques) et par les perks (lot B), lues par
`Progression.bonus(cle)` (additif) ou `Progression.mult(cle)` (multiplicatif, 1,0 = neutre).

| Clé | Sens | Lu par |
|---|---|---|
| `vie_max`, `magie_max`, `vigueur_max` | + points de jauge | `joueur.recalculer_stats` (déjà branché) |
| `charge` | + capacité du sac | `joueur.recalculer_stats` (déjà branché) |
| `regen_magie`, `regen_vigueur` | + % de régénération | lot B (joueur, lignes de régén.) |
| `resist_froid`, `resist_feu`, `resist_choc` | fraction de dégâts élémentaires en moins (0,1 = −10 %) | lot A |
| `degats_une_main`, `degats_deux_mains`, `degats_destruction` | + fraction de dégâts | lot A / B |
| `cout_sorts` | fraction de coût en moins | lot B (LanceurSorts) |
| `prix` | fraction de prix en faveur du joueur | lot E (Marchand) |
| clés de `ReglagesCombat.COMPETENCES` (`une_main`, `deux_mains`, `destruction`, `furtivite`, `armure`, `parade`) | multiplicateurs de l'arbre | `Progression.mult` → `ReglagesCombat.competence()` |

Un lot qui a besoin d'une clé nouvelle l'ajoute à ce tableau (une ligne) et la documente dans son rapport.

## 4. API objets, équipement, stockage

### `Conteneur` (`scripts/rpg/conteneur.gd`) — base générique
`pieces`, `objets {id: n}`, signal `change` ; `nombre(id)`, `ajouter(id, n)`, `retirer(id, n)`, `a(id)`, `nom(id)`,
`poids()`, `capacite()` (INF par défaut), `place_pour(id)`, `ids_de(categorie)`, `vide()`, `exporter()`, `importer(d)`
(alias traduits, inconnus ignorés). `"pieces"` est accepté comme identifiant par `nombre / ajouter / retirer`.

### `Inventaire extends Conteneur` (`scripts/inventaire.gd`) — le sac ET le registre
- Statique : `objet(id)` / `fiche(id)` → fiche ou `{}` ; `connu(id)` ; `categorie_de(id)` ; `emplacement_de(id)` ;
  `est_quete(id)` ; `alias(id)` ; `ids_connus()` ; constantes `CATEGORIES`, `EMPLACEMENTS`, `ALIAS`, `CAPACITE` (100) ;
  `OBJETS` (toutes les fiches de `data/objets/`, nom historique gardé).
- Instance : `capacite()` = `CAPACITE + capacite_bonus` (posé par `joueur.recalculer_stats`) ; `surcharge()`.

### `EquipementCorps` (`scripts/rpg/equipement_corps.gd`, `joueur.equipement_corps`)
`emplacements {tete, torse, mains, pieds, cou, anneau}` (id ou "") ; `refus(id) -> String` ; `equiper(id) -> String`
("" = fait) ; `retirer(emplacement)` ; `objet_a(emplacement)` ; `est_equipe(id)` ; `armure_totale()` ; `effets_totaux()` ;
signal `change(emplacement)` ; `exporter()` / `importer(d)`.
Règles : l'objet porté **reste dans le sac** (il pèse) ; s'il quitte le sac (vendu, lâché, déposé), il est retiré de son
emplacement automatiquement. Les mains restent à `EquipementMains` (ne pas fusionner).

### `Stockage` (`scripts/rpg/stockage.gd`, statique comme `Marchand`)
`COFFRES {coffre_grima (acces depart), coffre_maison (acces maison)}`, `PRIX_MAISON` 1500, `maison_achetee` ;
`conteneur(id) -> Conteneur` (null si inconnu) ; `accessible(id)` ; `refus_transfert(de, vers, id, n)` ;
`transferer(de, vers, id, n) -> String` (objet de quête : jamais déposé dans un coffre ; le sac peut dépasser sa capacité) ;
`reinitialiser()` (nouvelle partie, appelé par `monde`) ; `exporter()` / `importer(d)`.
Coffres du monde : inchangés (`ButinTables` + `FenetreButin`, prendre seulement).

## 5. Progression (`scripts/rpg/progression.gd`, `joueur.progression`)

```
niveau, xp_niveau, points_perk, points_attribut, attributs {vie, magie, vigueur}, perks {id: rang}, competences (Competences)
competence(nom) -> int            # 15..100, nom canonique ou interne (« epee » = « une_main »)
pratiquer(nom, quantite)          # délègue à Competences.pratiquer ; compétence pas encore gérée : ignorée
gagner_xp(quantite, annoncer=true)# XP de niveau ; chaque niveau : +1 points_perk, +1 points_attribut, signal niveau_perso
seuil_niveau(n) = 100 + 50 n      # statique ; xp_competence_jusqua(n) = somme des niveaux 16..n (statique)
part_niveau() -> 0..1
choisir_attribut(nom) -> String   # +10 (GAIN_ATTRIBUT) ; "" = fait
a_perk(id), rang_perk(id), acheter_perk(id) -> String, reinitialiser_perks()   # lot B (acheter : refus au lot 0)
mult(cle) -> float                # 1,0 au lot 0 (lot B : perks)
bonus(cle) -> float               # perks (lot B) + EquipementCorps.effets_totaux()
bonus_vie(), bonus_magie(), bonus_vigueur(), bonus_charge()   # attributs + bonus ; charge = 0,5 × attributs.vigueur + bonus("charge")
activer() ; static courante() ; static mult_global(cle)        # joueur courant (WeakRef) ; 1,0 sans joueur
static canonique(nom), interne(nom)                            # ALIAS_COMPETENCES {"epee": "une_main"}
signal niveau_perso(niveau), niveau_competence(nom canonique, niveau), change
exporter() / importer(d)
```

- Constantes : `COMPETENCES` (8 noms canoniques : une_main, deux_mains, parade, armure, destruction, restauration,
  furtivite, athletisme), `ATTRIBUTS`, `GAIN_ATTRIBUT` 10, `CHARGE_PAR_VIGUEUR` 0,5, `XP_QUETE_DEFAUT` 150,
  `PRIX_REINITIALISATION` 500, `NIVEAU_MAX` 81.
- **Déjà branché au lot 0** (invisible pour le joueur) : chaque niveau de compétence gagné donne `niveau` XP de niveau
  (`Competences.niveau_gagne` → `gagner_xp`) ; chaque quête terminée donne `recompense.xp` (défaut 150, `quetes._completer`,
  une ligne). Rien ne l'annonce encore (lot D : annonces HUD / écran de niveau).
- `joueur.competences` **reste** l'objet `Competences` (alias de `progression.competences`) : `mains.gd`, `hud.gd`,
  `joueur.gd` l'appellent sans changement. Lot B : passer les nouveaux gains par `joueur.progression.pratiquer(nom canonique)`.
- `ReglagesCombat.competence(nom)` = `COMPETENCES[nom] × Progression.mult_global(nom)` : `DegatsCombat`, `LanceurSorts`,
  `CalculDegats`, `joueur.recevoir_coup` reçoivent les perks sans modification.
- `joueur.recalculer_stats()` : `vie_max = 100 + bonus_vie() + bénédiction(10)`, `mana_max = 100 + bonus_magie()`,
  `vigueur_max = 100 + bonus_vigueur()`, `inventaire.capacite_bonus = bonus_charge()` ; appelé sur `Progression.change`,
  `EquipementCorps.change` et `regler_benediction`. Les maxima ne sont **jamais** sauvegardés.

## 6. Signaux pour l'interface

| Émetteur | Signal | Quand |
|---|---|---|
| `joueur.inventaire` (et tout `Conteneur`) | `change` | ajout / retrait / import (déjà écouté par quêtes, mains) |
| `joueur.equipement_corps` | `change(emplacement)` | équiper / retirer / objet sorti du sac / import ("") |
| `joueur.progression` | `change` | XP, niveau, points, attributs, perks, import |
| `joueur.progression` | `niveau_perso(niveau)` | un niveau de personnage gagné |
| `joueur.progression` | `niveau_competence(nom, niveau)` | relais canonique de `Competences.niveau_gagne` |
| `joueur.competences` | `niveau_gagne(nom interne, niveau)` | inchangé (annonce HUD actuelle) |
| `joueur` | `avis(texte)` | inchangé (surcharge…) |

## 7. Sauvegarde version 2

`monde.sauvegarder()` écrit `"version": 2` et les clés nouvelles ; `monde.charger()` appelle `Migration.migrer(d)`
**avant** tout `importer()`.

```
progression      {niveau, xp_niveau, points_perk, points_attribut, attributs {vie, magie, vigueur}, perks {id: rang},
                  competences {niveaux {8 noms canoniques}, experience {…}}}     (remplace l'ancienne clé « competences »)
equipement_corps {tete, torse, mains, pieds, cou, anneau}
stockage         {coffres {id: {pieces, objets}}, maison_achetee}
```
Les autres clés sont inchangées. Ordre de lecture : progression → inventaire → equipement_corps (après le sac) → stockage
→ … (avant `magie` et `quetes`, pour que les maxima soient justes quand mana / bénédiction sont relues).

**Migration v1 → v2** (`scripts/rpg/migration.gd`, fonctions pures, copie profonde) : `competences` →
`progression.competences` (epee → une_main, les 5 nouvelles à 15, expérience reprise) ; **niveau recalculé** comme si les
montées avaient eu lieu (somme des niveaux 16..n de chaque compétence) + XP des quêtes terminées (`recompense.xp`, défaut
150) ; points d'arbre et choix d'attribut **à dépenser** (rien d'attribué d'office) ; sac inchangé (alias seulement si
besoin) ; equipement_corps et stockage vides. Version > 2 : lue au mieux, avertissement. Une v2 ne se charge pas dans un
ancien exe (non exigé).
Une clé nouvelle de sauvegarde = un lot la demande à Max ; une migration v2 → v3 suit le même modèle (`vers_v3`).

## 8. Menu : `OngletMenu` (`scripts/menu/onglet_menu.gd`)

Base vide (`extends Control`) : `joueur`, `id_onglet()`, `titre()`, `ouvrir()`, `fermer()`, `entree(e) -> bool`,
`aide() -> [[touche, action]…]`, signaux `message(texte)`, `contenu_change`. La coquille `MenuPersonnage` (lot C) gère
Tab / Échap / B, LB / RB (Q / E physiques), pause, souris, bandeau d'aide. **Aucune règle de jeu dans un onglet.**
`menu_style.gd` : propriété du lot C (D demande).

## 9. Qui touche quoi

| Lot | Possède (seul à modifier) | Touche aussi (lignes précises, à signaler dans le rapport) |
|---|---|---|
| A Objets | `data/objets/armures.json`, `bijoux.json`, `armes.json`, `divers.json`, `consommables.json` ; corps de `scripts/rpg/equipement_corps.gd` ; `data/butin/sous_tables.json`, `cadavres.json` (ajouts EN FIN) ; `scripts/icones_combat.gd` | `joueur.gd` : `recevoir_coup` seule (formule d'armure `× 120 / (120 + armure × competence("armure"))`) ; `Inventaire.CAPACITE` 100 → 150 ; `data/marchands.json` (stock Brodd) ; `catalogue_armes.json` (poids) |
| B Progression | `scripts/rpg/progression.gd` (corps), `scripts/competences.gd`, `data/competences/arbre.json` | `mains.gd` (lignes `pratiquer` seules), `magie/lanceur_sorts.gd`, `magie/main_sort.gd` (gains), `quetes.gd` (`recompense.xp` déjà lue), `data/quetes.json`, `calcul_degats.gd` (furtif), `joueur.gd` (lignes de régén. / `pratiquer`) |
| C Menu | `scripts/menu/menu_personnage.gd`, `onglet_equipement.gd`, `onglet_sac.gd`, `onglet_magie.gd`, `scripts/menu_style.gd`, `scripts/inventaire_mains.gd` | `hud.gd` (`_panneau` et Tab), `monde._interface` (1 ligne) ; **lit** `EquipementMains` sans le modifier |
| D Onglets | `scripts/menu/onglet_competences.gd`, `onglet_personnage.gd`, `onglet_quetes.gd`, `ecran_niveau.gd` | `hud.gd` (annonce de niveau seulement), `quetes.gd` (lecture) |
| E Stockage | `scripts/rpg/stockage.gd` (corps), `scripts/fenetre_butin.gd`, `scripts/marchand.gd`, `data/marchands.json` (sauf stock Brodd : A) | `Inventaire.objet` (cas `id+n` en tête), un intérieur (`interieurs_maisons.gd` ou halle) pour le coffre, `monde.gd` (aucune clé nouvelle : `stockage` est déjà sauvegardée) |

Fichiers du socle (`scripts/inventaire.gd`, `scripts/rpg/conteneur.gd`, `scripts/rpg/migration.gd`,
`scripts/menu/onglet_menu.gd`, `docs/RPG.md`) : pas de refonte par un lot ; un ajout de fonction est possible s'il est
signalé (une fonction neuve, pas de signature changée).

## 10. Règles anti-conflit

- **Fichiers sensibles** : `joueur.gd`, `monde.gd`, `hud.gd`, `mains.gd`. Le lot 0 y a posé tous les champs et toutes les
  clés de sauvegarde ; un lot n'y touche que les lignes listées au §9.
- **Branche `tps/mains_sorts`** (en cours) : touche `magie/equipement_mains.gd`, `inventaire_mains.gd`, `mains.gd`,
  `corps_joueur.gd`. **Ne pas refondre** `equipement_mains.gd` ni `combat/equipement.gd` ; points d'accroche à utiliser :
  `EquipementMains.objets_possedes / fiche / essai / equiper / assigner_raccourci` (lecture et appels seulement).
- **Butin** : ajouts en fin de table (test). **Identifiants** : aucun renommage (ALIAS sinon).
- **Équilibrage** : le lot B ne change aucun chiffre de `ReglagesCombat` ; les perks partent de 1,0.
- **Tests** : chacun ses tests ciblés (`bash outils/tous_les_tests.sh <nom>`, Godot via `/tmp/godot_slot.sh`) ; la suite
  complète une seule fois, à la fusion (Max).

## 11. Tests du socle

- `test_rpg_socle` (`--nouvelle`) : registre (49 anciens objets identiques, catégories, quête explicite, emplacements),
  butin en fin de table, Conteneur / Stockage, EquipementCorps, Progression, `ReglagesCombat.competence`, joueur réel.
- `test_migration_v2` (`v1;v2`, deux processus) : migration sur la copie `outils/donnees_test/sauvegarde_v1_reelle.json`
  (vraie sauvegarde v1 du 2026-10-30, copiée en lecture) et sur une v1 avancée ; chargement par le jeu, réécriture en v2,
  relecture par un 2e processus. Fichier de test seulement (`sauvegarde_test_<hash>.json`), jamais `user://sauvegarde.json`.

## 12. Dette laissée volontairement aux lots

- **Armes listées deux fois** dans l'écran I (« Divers » = tout le sac sauf consommables) : c'est de l'interface
  (`inventaire_mains.gd`, branche tps en cours) → lot C (onglet Sac à filtres par `Inventaire.categorie_de`). Attention :
  la hache de Kolbeinn est maintenant « arme » mais **n'a pas de modèle tenu** ; un filtre « Armes » qui ne liste que
  l'équipable la ferait disparaître → la montrer dans le Sac (catégorie arme, non équipable) tant que le lot A n'a pas fait
  son modèle.
- **Bonus caché de la hache de Kolbeinn** (`Equipement.bonus_trophee` : ×1,25 si elle est dans le sac) : le faire dépendre
  de l'équipement exige une arme tenue (modèle + `DonneesArme`) → **lot A** (lui donner une `DonneesArme` famille hache,
  mettre le bonus dans ses propres dégâts comme Skarnholt, puis `bonus_trophee` → 1,0). Gardé tel quel au lot 0 pour que
  le jeu reste identique.
- `Equipement.choisir_selon_inventaire` (Skarnholt remplace l'épée de métal si elle est dans le sac) : inchangé
  (`combat/equipement.gd`, zone de la branche tps).
- `Marchand.de_quete` lit encore `valeur == 0` (équivalent au drapeau `quete` aujourd'hui) → lot E peut passer à
  `Inventaire.est_quete`.
- Deux mécanismes « déjà ouvert » (`quetes.vus` / `ButinTables.pilles`) : inchangés.
- Commentaires qui citent encore `data/butin/objets.json` dans quelques scripts (dont `equipement_mains.gd`, non touché
  exprès) : le fichier est devenu `data/objets/consommables.json` (et les autres fichiers de `data/objets/`).
