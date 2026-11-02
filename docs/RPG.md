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

Champs des armures (refonte HD, 2026-11-02) : `materiau` (`or` | `verre` | `obsidienne` | `rubis` | `saphir` : ensembles par
matériau, tables de butin par palier) ; **variante enchantée** = fiche à part (nouvel id, rare ou unique, jamais en boutique) avec
`"base": "<id de la pièce>"` (elle en reprend `modele_porte` / `modele_sol`, l'armure, le poids et l'emplacement ; les chausses
suivent la base : `ArmureVisible.base_de`) et `"variante_materiau": "enchante"` : `ArmureVisible` (porté) et `ObjetMonde` (sol)
habillent alors les matériaux du glb avec le preset `<matière>.enchante` de `ArmureVisible.MATIERES` (runes / gemmes luisantes,
posé par les agents modèles), à défaut le preset de base avec une faible lueur (`LUEUR_VARIANTE`).

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
| clés de `ReglagesCombat.COMPETENCES` (`une_main`, `deux_mains`, `destruction`, `furtivite`, `armure`, `parade`) | multiplicateurs de l'arbre | `Progression.mult` → `ReglagesCombat.competence()` (`parade` : lu par `Competences.reduction_parade`, ÷ mult) |
| `restauration` | × vie rendue par les sorts de soin (mult) | lot B (`LanceurSorts.canaliser`) |
| `destruction_feu`, `destruction_glace`, `destruction_electricite`, `destruction_tenebres` | × dégâts des sorts de l'école (mult) | lot B (`LanceurSorts.frapper`) |
| `regen_vie` | + % de régénération de vie | lot B (joueur, lignes de régén.) |
| `cout_destruction`, `cout_restauration` | fraction de coût en moins selon l'école (soin / protection = restauration), s'ajoute à `cout_sorts` ; plancher ×0,25 | lot B (`Progression.facteur_cout_sort`, MainSort) |
| `cout_double` | fraction de coût en moins en double incantation | lot B (MainSort) |
| `cout_protection` | fraction de mana en moins par coup absorbé (sort Protection) | lot B (`MainSort.absorber`) |
| `cout_course` | fraction de vigueur en moins pour courir (plancher ×0,2) | lot B (`Competences.cout_course`) |
| `saignement_une_main`, `saignement_deux_mains` | part des dégâts du coup infligée en saignement sur 3 s (pas sur os / sans sang) | lot B (`Progression.coup_porte` → `Saignement`) |
| `vol_vie_une_main`, `vol_vie_deux_mains` | part des dégâts rendue en vie | lot B (`coup_porte`) |
| `etourdir_une_main`, `etourdir_deux_mains` | chance d'étourdir (statut choc 0,7 s) sur un coup fort (lourd / contre) | lot B (`coup_porte`) |
| `vigueur_tue_une_main`, `vigueur_tue_deux_mains` | vigueur rendue quand le coup tue | lot B (`coup_porte`) |
| `riposte` | part du coup paré (parade parfaite) renvoyée à l'attaquant | lot B (`Progression.garde_tenue`) |
| `vigueur_parade` | vigueur rendue sur parade parfaite | lot B (`garde_tenue`) |
| `etourdir_parade` | chance d'étourdir l'attaquant sur parade parfaite | lot B (`garde_tenue`) |
| `recup_furtif` | vigueur ET mana rendus après une attaque furtive | lot B (`Progression.attaque_furtive` → joueur) |
| `xp_<compétence canonique>` | + fraction d'XP de compétence gagnée | lot B (`Progression.pratiquer`) |
| `degats_une_main`, `degats_deux_mains`, `degats_destruction` (équipement) | multipliés dans `Progression.mult` de la clé correspondante (× (1 + bonus)) | lot B |
| `coup_feu`, `coup_glace`, `coup_electricite`, `coup_tenebres` | points de dégâts de l'élément AJOUTÉS à chaque coup d'arme du joueur (× résistance de la cible à ce type, × 0,5 coup affaibli) ; un coup fort (lourd / chargé / contre) pose aussi brûlure (2 s, 2/s) / gel (2 s, 0,3) / choc (0,6 s) / corruption (3 s, 0,1) si l'arme ou un sort n'en pose pas déjà un. Seulement sur des gantelets enchantés (une seule source portée) | armures HD (`Elements.coup_equipement`, appelé par `Elements.avant_coup`) |
| `resist_magie` | fraction en moins sur TOUT coup magique reçu (glace / feu / electricite / tenebres), additionnée à la résistance propre de l'élément, plafond commun 80 % (`EquipementCorps.RESISTANCE_MAX`) | armures HD (`EquipementCorps.resistance_totale`, `joueur.recevoir_coup`) |
| `vol_vie` | part des dégâts d'un coup d'arme rendue en vie, toute arme, même sans perk (s'ajoute à `vol_vie_une_main` / `_deux_mains`) | armures HD (`Progression.coup_porte`) |

Un lot qui a besoin d'une clé nouvelle l'ajoute à ce tableau (une ligne) et la documente dans son rapport.

**Type des coups reçus** (`joueur.recevoir_coup(…, {"type": …})`, intégration) : `glace` / `feu` / `electricite` → résistance
`resist_*` (pas l'armure) ; `physique` (ou absent) → armure. Souffle du dragon de givre, souffle des pièges, onde de choc du
troll de givre (pics de glace) = `glace` ; morsure / queue du dragon, fléchettes, charge et coups du troll = `physique`.

**Apparence unique des fenêtres** (intégration) : menu, coffre, butin, boutique et forge sont peints par `Parchemin`
(`scripts/menu/parchemin.gd`) : même codex (`Parchemin.texture_livre`, une image par taille d'écran, partagée), mêmes signets,
même bandeau de touches. `LivreParchemin` n'est plus qu'un adaptateur (repère des pages décalé de `DY`, `hauteur()`) ; l'ancien
shader `livre_parchemin.gdshader` est supprimé.

## 4. API objets, équipement, stockage

### `Conteneur` (`scripts/rpg/conteneur.gd`) — base générique
`pieces`, `objets {id: n}`, signal `change` ; `nombre(id)`, `ajouter(id, n)`, `retirer(id, n)`, `a(id)`, `nom(id)`,
`poids()`, `capacite()` (INF par défaut), `place_pour(id)`, `ids_de(categorie)`, `vide()`, `exporter()`, `importer(d)`
(alias traduits, inconnus ignorés). `"pieces"` est accepté comme identifiant par `nombre / ajouter / retirer`.

### `Inventaire extends Conteneur` (`scripts/inventaire.gd`) — le sac ET le registre
- Statique : `objet(id)` / `fiche(id)` → fiche ou `{}` ; `connu(id)` ; `categorie_de(id)` ; `emplacement_de(id)` ;
  `est_quete(id)` ; `alias(id)` ; `ids_connus()` ; constantes `CATEGORIES`, `EMPLACEMENTS`, `ALIAS`, `CAPACITE` (150 depuis le lot A) ;
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
a_perk(id), rang_perk(id), acheter_perk(id) -> String, reinitialiser_perks()   # lot B : §13
mult(cle) -> float                # 1 + somme des perks (× équipement « degats_* » pour une_main / deux_mains / destruction)
bonus(cle) -> float               # perks + EquipementCorps.effets_totaux()
# ajouts lot B (§13) : refus_perk(id), points_depenses(), refus_reinitialisation(pieces), reinitialiser_chez_sigrun(bourse),
# effets_perks(), perk_total(cle), facteur(cle) ; statiques arbre(), perk(id), perks_de(pierre), rangs_max(id), bonus_global(cle),
# pratiquer_global, pratiquer_de, competence_arme(arme), coup_porte, garde_tenue, facteur_cout_sort, attaque_furtive
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
menu             {favoris [ids]}      (intégration : favoris du Sac ; absente = aucun favori, sans changer de version)
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
- **Lot B → lot C** : le panneau Tab actuel (`hud._panneau`) liste maintenant les 8 compétences (`Competences.NOMS`) ; à
  22 px par ligne il n'y a plus la place pour les quêtes dessous : le remplacer par l'onglet Compétences (lot D) / MenuPersonnage.
  L'annonce de niveau affiche « Une main » au lieu de « Épée » (test_hud_l7 adapté).
- Commentaires qui citent encore `data/butin/objets.json` dans quelques scripts (dont `equipement_mains.gd`, non touché
  exprès) : le fichier est devenu `data/objets/consommables.json` (et les autres fichiers de `data/objets/`).

## 13. Progression et arbre de compétences (lot B)

### Compétences à l'usage
`Competences` gère les 8 compétences (nom interne `epee` = canonique `une_main`, gardé pour le HUD, les tests et les v1).
Courbe : `Competences.seuil(n) = 0,025 n² − 1,5` (15 → 16 : ~4 XP ; 50 → 51 : ~61 ; 99 → 100 : ~244). Chaque niveau de
compétence donne `n` XP de niveau (inchangé, socle). Gains (tous par `Progression.pratiquer`, × (1 + `xp_<comp>`)) :

| Compétence | Gain | Où |
|---|---|---|
| une_main / deux_mains (selon `Progression.competence_arme`) | coup qui porte 1,0 (lourd / contre 1,8), finisher 2,5 | `mains.gd` (`Progression.coup_porte` / `pratiquer_de`) |
| parade | garde : 0,6 + 0,08 × dégâts (+0,6 parade parfaite) | `joueur.recevoir_coup` (`Progression.garde_tenue`) |
| armure | coup encaissé sans garde : 0,3 + 0,04 × dégâts | `joueur.recevoir_coup` |
| destruction | sort du joueur qui touche : 0,06 × dégâts (avant perks) | `LanceurSorts.frapper` |
| restauration | soin : 0,06 × vie vraiment rendue ; protection : 0,06 × dégâts absorbés | `LanceurSorts.canaliser`, `MainSort.absorber` |
| furtivite | attaque furtive : 3 + 0,02 × dégâts | `CalculDegats.calculer` (`Progression.attaque_furtive`) |
| athletisme | course : 0,12 / s | `joueur._physics_process` |

Bonus de NIVEAU (inchangés) : une main et deux mains (+30 % au niveau 100, chacune avec son propre niveau :
`Competences.multiplicateur_degats(nom)`), parade (garde ×0,5 au niveau 100), athlétisme (course ×0,5). Les 5 autres
compétences n'agissent que par l'arbre. XP des quêtes : `data/quetes.json` `recompense.xp` (200 / 120 / 150 / 200 / 150 /
250 / 400 ; défaut `XP_QUETE_DEFAUT` 150). Simulation (temps de jeu → niveaux, 3 profils) : `outils/simulation_progression.gd`
→ `Desktop/Skyrim captures/rpg_progression/` : niveau 2 vers 10 min, 5 vers 30 min, 10 vers 3 h, 15 vers 8 h, 20 vers 20 h.

### Arbre : `data/competences/arbre.json`
`{pierres {id: {nom, competence, titre, description}}, ordre_pierres [8], perks {id: {nom, pierre, pos [colonne -2..2,
rangée 0..3 (0 = racine, en bas)], parents [], description, rangs [{niveau, effets, texte}]}}}`.
- Un rang = 1 point d'arbre. `niveau` = niveau requis de la compétence de la pierre ; `parents` : il suffit d'en posséder UN
  (vide = racine, une par pierre). `effets` = TOTAUX au rang atteint (pas cumulés d'un rang à l'autre).
- `mult(cle) = 1 + Σ effets` (ReglagesCombat le lit pour les 6 clés de combat : aucun chiffre de ReglagesCombat changé),
  `bonus(cle) = Σ effets + équipement`. Les maxima (vie, magie, vigueur, charge) suivent par `Progression.change` →
  `joueur.recalculer_stats`.
- Sauvegarde : `progression.perks {id: rang}` (inchangé). À l'import, un perk retiré de l'arbre ou un rang en trop rend son
  point. Nouveau perk = nouvel id ; jamais de renommage.
- `resist_froid / feu / choc` (Sang de Jötunn, Écailles de Jörmungandr) : additionnés dans `bonus()`, **appliqués par le
  lot A** (dégâts élémentaires reçus).

### API pour l'interface (lot D) et Sigrún (lot D / E)
- Lire : `Progression.arbre()`, `perks_de(pierre)`, `perk(id)`, `rangs_max(id)` ; `p.rang_perk(id)`, `p.refus_perk(id)`
  (texte prêt à afficher : « Une main 30 requis. », « Il faut d'abord : Croc de fer. », « Aucun point d'arbre. »,
  « Rang maximal atteint. »), `p.points_perk`, `p.points_depenses()`, `p.competences.progression(nom interne)`.
- Agir : `p.acheter_perk(id) -> String` ("" = fait ; signal `change`).
- **Sigrún** (le dialogue n'a que « Commercer / Au revoir » : branchement laissé au lot D / E) : `p.refus_reinitialisation(pieces)`
  pour griser le choix, puis `p.reinitialiser_chez_sigrun(joueur.inventaire) -> String` (paie `Progression.PRIX_REINITIALISATION`
  = 500 pièces, rend tous les points ; rien n'est payé en cas de refus).

### Liste des perks (55 perks, 104 rangs)

#### Pierre du Loup — Une main

Épées, haches, masses et dagues tenues d'une main.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Lame aguerrie** (`lame_aguerrie`) | 15 : +10 % de dégâts aux armes à une main.<br>25 : +20 % de dégâts aux armes à une main.<br>40 : +30 % de dégâts aux armes à une main.<br>55 : +40 % de dégâts aux armes à une main.<br>75 : +50 % de dégâts aux armes à une main. | — (racine) |
| **Élève de Týr** (`eleve_de_tyr`) | 20 : La compétence Une main progresse 25 % plus vite. | Lame aguerrie |
| **Croc de fer** (`croc_de_fer`) | 30 : Les coups à une main font saigner : 15 % des dégâts en 3 s.<br>50 : Saignement : 30 % des dégâts en 3 s. | Lame aguerrie |
| **Crocs de Fenrir** (`crocs_de_fenrir`) | 35 : Coup puissant à une main : 20 % de chances d'étourdir.<br>60 : 35 % de chances d'étourdir. | Lame aguerrie |
| **Curée** (`curee`) | 40 : Tuer à une main rend 25 de vigueur. | Crocs de Fenrir |
| **Soif du loup** (`soif_du_loup`) | 45 : Les coups à une main rendent 4 % des dégâts en vie. | Croc de fer |
| **Lame de Fenrir** (`lame_de_fenrir`) | 85 : +15 % de dégâts à une main et +15 % de saignement. | Soif du loup ou Curée |

#### Pierre de l'Ours — Deux mains

Grandes épées, haches et marteaux de guerre.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Bras de l'ours** (`bras_de_l_ours`) | 15 : +10 % de dégâts aux armes à deux mains.<br>25 : +20 % de dégâts aux armes à deux mains.<br>40 : +30 % de dégâts aux armes à deux mains.<br>55 : +40 % de dégâts aux armes à deux mains.<br>75 : +50 % de dégâts aux armes à deux mains. | — (racine) |
| **Force de Magni** (`force_de_magni`) | 20 : La compétence Deux mains progresse 25 % plus vite. | Bras de l'ours |
| **Hache sanglante** (`hache_sanglante`) | 30 : Les coups à deux mains font saigner : 20 % des dégâts en 3 s.<br>50 : Saignement : 35 % des dégâts en 3 s. | Bras de l'ours |
| **Marteau de Thor** (`marteau_de_thor`) | 30 : Coup puissant à deux mains : 25 % de chances d'étourdir.<br>55 : 40 % de chances d'étourdir. | Bras de l'ours |
| **Festin des corbeaux** (`festin_des_corbeaux`) | 40 : Tuer à deux mains rend 30 de vigueur. | Marteau de Thor |
| **Rage du berserker** (`rage_du_berserker`) | 50 : Les coups à deux mains rendent 5 % des dégâts en vie. | Hache sanglante |
| **Fendeur de crânes** (`fendeur_de_cranes`) | 85 : +20 % de dégâts à deux mains et +10 % de chances d'étourdir. | Rage du berserker ou Festin des corbeaux |

#### Pierre du Rempart — Parade

Garde, parade parfaite et riposte.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Rempart de tilleul** (`rempart_de_tilleul`) | 15 : Garde renforcée de 10 % : moins de dégâts bloqués et de vigueur dépensée.<br>25 : Garde renforcée de 20 % : moins de dégâts bloqués et de vigueur dépensée.<br>40 : Garde renforcée de 30 % : moins de dégâts bloqués et de vigueur dépensée.<br>55 : Garde renforcée de 40 % : moins de dégâts bloqués et de vigueur dépensée.<br>75 : Garde renforcée de 50 % : moins de dégâts bloqués et de vigueur dépensée. | — (racine) |
| **Œil de Heimdall** (`oeil_de_heimdall`) | 20 : La compétence Parade progresse 25 % plus vite. | Rempart de tilleul |
| **Riposte de Heimdall** (`riposte_de_heimdall`) | 30 : Une parade parfaite renvoie 50 % du coup à l'attaquant.<br>55 : La parade parfaite renvoie 100 % du coup. | Rempart de tilleul |
| **Souffle du guetteur** (`souffle_du_guetteur`) | 25 : Une parade parfaite rend 10 de vigueur.<br>45 : Une parade parfaite rend 20 de vigueur. | Rempart de tilleul |
| **Garde de fer** (`garde_de_fer`) | 50 : Une parade parfaite a 50 % de chances d'étourdir l'attaquant. | Riposte de Heimdall |
| **Chêne inébranlable** (`chene_inebranlable`) | 35 : +20 de vigueur maximale. | Souffle du guetteur |
| **Mur de boucliers** (`mur_de_boucliers`) | 80 : Garde renforcée de 20 % de plus et riposte +25 %. | Garde de fer ou Chêne inébranlable |

#### Pierre de la Montagne — Armure

Encaisser les coups, résister au froid, au feu et à la foudre.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Cuir et maille** (`cuir_et_maille`) | 15 : Dégâts reçus divisés par 1,1 (−9 %).<br>25 : Dégâts reçus divisés par 1,2 (−17 %).<br>40 : Dégâts reçus divisés par 1,3 (−23 %).<br>55 : Dégâts reçus divisés par 1,4 (−29 %).<br>75 : Dégâts reçus divisés par 1,5 (−33 %). | — (racine) |
| **Endurci** (`endurci`) | 20 : La compétence Armure progresse 25 % plus vite. | Cuir et maille |
| **Sang de Jötunn** (`sang_de_jotunn`) | 25 : Résistance au froid +15 %.<br>50 : Résistance au froid +30 %. | Cuir et maille |
| **Écailles de Jörmungandr** (`ecailles_de_jormungandr`) | 30 : Résistance au feu et à la foudre +15 %.<br>55 : Résistance au feu et à la foudre +30 %. | Cuir et maille |
| **Corps de colosse** (`corps_de_colosse`) | 30 : +20 de vie maximale.<br>60 : +40 de vie maximale. | Cuir et maille |
| **Sang de troll** (`sang_de_troll`) | 45 : Régénération de vie doublée (+100 %). | Corps de colosse |
| **Rempart vivant** (`rempart_vivant`) | 80 : Armure +20 % de plus et +20 de vie maximale. | Sang de Jötunn ou Écailles de Jörmungandr ou Sang de troll |

#### Pierre de l'Orage — Destruction

Feu, givre, foudre et ténèbres.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Paroles de puissance** (`paroles_de_puissance`) | 15 : +10 % de dégâts des sorts de destruction.<br>25 : +20 % de dégâts des sorts de destruction.<br>40 : +30 % de dégâts des sorts de destruction.<br>55 : +40 % de dégâts des sorts de destruction.<br>75 : +50 % de dégâts des sorts de destruction. | — (racine) |
| **Apprenti du seiðr** (`apprenti_du_seidr`) | 20 : La compétence Destruction progresse 25 % plus vite. | Paroles de puissance |
| **Runes économes** (`runes_econes`) | 20 : Sorts de destruction : coût −15 %.<br>50 : Sorts de destruction : coût −30 %. | Paroles de puissance |
| **Double jet** (`double_jet`) | 40 : Double incantation (le même sort dans les deux mains) : coût −25 %. | Runes économes |
| **Cœur de Muspell** (`coeur_de_muspell`) | 30 : Sorts de feu : +25 % de dégâts.<br>55 : Sorts de feu : +50 % de dégâts. | Paroles de puissance |
| **Souffle de Niflheim** (`souffle_de_niflheim`) | 30 : Sorts de givre : +25 % de dégâts.<br>55 : Sorts de givre : +50 % de dégâts. | Paroles de puissance |
| **Colère de Thor** (`colere_de_thor`) | 30 : Sorts de foudre : +25 % de dégâts.<br>55 : Sorts de foudre : +50 % de dégâts. | Paroles de puissance |
| **Ombre de Hel** (`ombre_de_hel`) | 30 : Sorts de ténèbres : +25 % de dégâts.<br>55 : Sorts de ténèbres : +50 % de dégâts. | Paroles de puissance |

#### Pierre d'Eir — Restauration

Soin, protection et mana.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Mains d'Eir** (`mains_d_eir`) | 15 : Sorts de soin : +15 % de vie rendue.<br>30 : Sorts de soin : +30 % de vie rendue.<br>50 : Sorts de soin : +45 % de vie rendue.<br>70 : Sorts de soin : +60 % de vie rendue. | — (racine) |
| **Disciple de la völva** (`disciple_de_la_volva`) | 20 : La compétence Restauration progresse 25 % plus vite. | Mains d'Eir |
| **Souffle économe** (`souffle_econome`) | 20 : Soin et protection : coût −15 %.<br>50 : Soin et protection : coût −30 %. | Mains d'Eir |
| **Garde runique** (`garde_runique`) | 30 : Protection : chaque coup absorbé coûte 25 % de mana en moins.<br>55 : Protection : 50 % de mana en moins par coup absorbé. | Souffle économe |
| **Source d'Urd** (`source_d_urd`) | 25 : Régénération de mana +25 %.<br>50 : Régénération de mana +50 %. | Mains d'Eir |
| **Puits de Mímir** (`puits_de_mimir`) | 30 : +20 de mana maximal.<br>60 : +40 de mana maximal. | Source d'Urd |
| **Bénédiction de Frigg** (`benediction_de_frigg`) | 80 : Sorts de soin +25 % et régénération de vie +50 %. | Garde runique ou Puits de Mímir |

#### Pierre du Corbeau — Furtivité

Attaques furtives : frapper un ennemi qui ne t'a pas vu.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Lame dans l'ombre** (`lame_dans_l_ombre`) | 15 : Attaques furtives : +15 % de dégâts.<br>30 : Attaques furtives : +30 % de dégâts.<br>50 : Attaques furtives : +45 % de dégâts.<br>70 : Attaques furtives : +60 % de dégâts. | — (racine) |
| **Pensée de Huginn** (`pensee_de_huginn`) | 15 : La compétence Furtivité progresse 50 % plus vite. | Lame dans l'ombre |
| **Mémoire de Muninn** (`memoire_de_muninn`) | 30 : Une attaque furtive rend 15 de vigueur et 15 de mana.<br>50 : Une attaque furtive rend 30 de vigueur et 30 de mana. | Lame dans l'ombre |
| **Voile de Hel** (`voile_de_hel`) | 50 : Attaques furtives : +25 % de dégâts de plus. | Pensée de Huginn ou Mémoire de Muninn |
| **Manteau d'Odin** (`manteau_d_odin`) | 80 : Attaques furtives +35 % et +15 de vigueur et de mana rendus. | Voile de Hel |

#### Pierre du Cerf — Athlétisme

Course, souffle, vigueur et charge portée.

| Perk | Rangs (niveau requis : effet) | Parents |
|---|---|---|
| **Pied léger** (`pied_leger`) | 15 : La course coûte 15 % de vigueur en moins.<br>35 : La course coûte 30 % de vigueur en moins. | — (racine) |
| **Coureur des neiges** (`coureur_des_neiges`) | 20 : La compétence Athlétisme progresse 25 % plus vite. | Pied léger |
| **Souffle long** (`souffle_long`) | 25 : Régénération de vigueur +20 %.<br>50 : Régénération de vigueur +40 %. | Pied léger |
| **Dos du bœuf** (`dos_du_boeuf`) | 20 : +25 de charge portée.<br>45 : +50 de charge portée. | Pied léger |
| **Cœur du cerf** (`coeur_du_cerf`) | 30 : +20 de vigueur maximale.<br>60 : +40 de vigueur maximale. | Souffle long |
| **Sabot de Sleipnir** (`sabot_de_sleipnir`) | 55 : La course coûte encore 20 % de vigueur en moins. | Cœur du cerf ou Dos du bœuf |
| **Vent du nord** (`vent_du_nord`) | 80 : Régénération de vigueur +30 % et +20 de vigueur maximale. | Sabot de Sleipnir |

## 14. Carte du monde et registre des lieux (branche `rpg/carte`, 2026-11-02)

- **`Lieux`** (`scripts/rpg/lieux.gd`, statique) : registre UNIQUE des lieux extérieurs (`LIEUX` : id, nom, type, x, z,
  rayon de découverte, découvrable, majeur, note, « à … », « près de … ») et des cibles de quête (`CIBLES` : déclencheur →
  lieu, par préfixe ; une étape de `data/quetes.json` peut aussi porter `"carte": "<id>"`). API : `liste()`, `lieu(id)`,
  `position(id, monde)` (porte réelle du tertre / de la grotte), `decouvert(id, hud)` (suit `hud.lieux_vus`, clé = nom),
  `declarer_au_hud(hud, monde)` (sans doublon), `cibles_quetes(quetes, monde)` (une cible par quête en cours ; « suivie »
  = celle du HUD), `position_joueur(monde)` / `sous_terre(monde)` (sous terre : la porte d'entrée), `ou_est(monde)`.
  **À partager avec la boussole** (branche `hud/barre_objets`) : `hud.lieux` / `monde._interface` peuvent lire
  `Lieux.liste()` et `Lieux.cibles_quetes()` au lieu de leurs listes écrites à la main. Agrandissement : une ligne par lieu.
- **`CarteMonde`** (`scripts/menu/carte_monde.gd`) : générateur de la maquette 3D (relief `monde.hauteurs_maillage` + pourtour
  `monde.hauteur()`, couleurs depuis la carte de sol / eau / chemins / enceinte / champs, sapins `monde.arbres`, bâtiments
  `village.emprises`, palissade, cercle, tertre, pont ; nuages, brume, courbes de niveau ; shaders `carte_*.gdshader`).
  ~0,7 s à la première ouverture de l'onglet, puis gardé ; rendu seulement quand l'onglet est affiché.
- **`OngletCarte`** (`scripts/menu/onglet_carte.gd`, `extends OngletMenu`, id `carte`) : branchement = une ligne dans
  `MenuPersonnage.ONGLETS` : `{"id": "carte", "titre": "Carte", "script": "res://scripts/menu/onglet_carte.gd"}` (+ `KEY_M:
  "carte"` dans `TOUCHES_ONGLETS` si voulu). Laisse passer Tab, Échap, I / K / J, Q / E, LB / RB, B, Retour.
- Tests : `test_onglet_carte` (`--nouvelle`). Captures : `outils/captures_carte.gd -- --nouvelle --sortie=<dossier>`.
