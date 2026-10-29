# Butin, tables à graine fixe et consommables (lot L4)

Lot L4 du chantier « Ignite » (`docs/INSPIRATION_IGNITE.md` §2.18). Ce document est le **contrat** que les lots suivants
utilisent : L1 coffre animé, L3 fenêtre de butin, L5 objets cassables, L8 marchands (aucun visuel ici).

Fichiers :

| Fichier | Rôle |
|---|---|
| `scripts/butin_tables.gd` (`ButinTables`) | lecture des tables, tirage à graine, état pillé / uniques (sauvegardés) |
| `scripts/consommables.gd` (`Consommables`) | potions et nourriture : refus, effets sur les stats, description |
| `data/butin/coffres.json` | coffres : `coffre_crypte`, `coffre_crypte_riche`, `coffre_boss`, `coffre_bandit`, `coffre_mine` |
| `data/butin/contenants.json` | petits contenants : `urne`, `tonneau`, `caisse`, `sac` |
| `data/butin/cadavres.json` | corps : `cadavre_draugr`, `cadavre_bandit`, `cadavre_mage`, `cadavre_troll` |
| `data/butin/sous_tables.json` | sous-tables : `potions`, `nourriture`, `valeurs`, `tomes`, `armes` |
| `data/butin/zones.json` | table de chaque type de contenant par zone + modulateurs (or, rareté) |
| `data/butin/objets.json` | objets ajoutés au sac : consommables, épées trouvables, tomes, objets de valeur |
| `outils/test_butin.gd` | test (dans `outils/tous_les_tests.sh`) |

## 1. Format d'une table

```json
"coffre_crypte": {
	"or": [8, 30],
	"tirages": [1, 3],
	"rien": 20,
	"garanti": [{"id": "os_draugr", "n": [1, 2]}],
	"entrees": [
		{"id": "os_draugr", "poids": 30, "n": [1, 3]},
		{"table": "potions", "poids": 26},
		{"table": "tomes", "poids": 2, "rarete": "rare"}
	]
}
```

- `or` : pièces, `[min, max]` inclus (ou un nombre), multiplié par le facteur `or` de la zone.
- `tirages` : nombre de tirages pondérés (nombre ou `[min, max]`).
- `rien` : poids du tirage vide (facultatif).
- `garanti` : toujours donnés (avant les tirages).
- `entrees` : `{id, poids, n, rarete}` ou `{table, poids, rarete}` (sous-table tirée avec le même générateur ; 4 niveaux au plus).
- `rarete` : `commun` | `peu_commun` | `rare` | `unique`. Par défaut, celle de l'objet (`objets.json`), sinon `commun`.
  Le facteur `rarete` de la zone multiplie le **poids** des entrées de cette rareté (ex. `crypte_basse` : rares x1,5).
- Un `unique` sort au plus une fois par tirage ; une seconde fois dans la partie, `prendre()` le change en pièces (sa `valeur`).
- Un même id tiré plusieurs fois est regroupé (une ligne, `n` cumulé).

Couleurs et noms des raretés pour l'interface : `ButinTables.COULEURS_RARETE`, `ButinTables.NOMS_RARETE`.

## 2. Déterminisme

- Graine d'un contenant = FNV-1a 32 bits de `"<graine_monde>:<id stable>"` (`ButinTables.graine(id)`), indépendante de
  `randi()` / `seed()` (un `RandomNumberGenerator` local, parcours dans l'ordre des fichiers JSON).
- `graine_monde` vaut `20261028` par défaut, sauvegardée ; une ancienne sauvegarde garde la graine par défaut.
- Identifiants utilisés : `crypte:<id>` (coffres et urnes de la crypte, même clé que `quetes.vus`), `<grotte>:<id>`
  (coffres de grotte), `ennemi:<ident>` (bourses). Les lots suivants doivent prendre un identifiant **stable**
  (position arrondie ou id de la table de pose), jamais un `get_instance_id()`.
- Les coffres de donjon sont tirés à la construction (`DonjonKit.interaction`, aussi dans le fil de construction : la lecture
  des JSON est publiée d'un coup, sans état partiel).

## 3. API

```gdscript
ButinTables.tirer(table: String, graine: int, zone := "") -> Array[Dictionary]   # [{id, n, rarete}], pièces d'abord (id "pieces")
ButinTables.tirer_pour(id_contenant: String, table: String, zone := "") -> Array[Dictionary]
ButinTables.graine(id_contenant: String) -> int
ButinTables.table_pour(type: String, zone := "") -> String   # coffre, coffre_riche, coffre_boss, coffre_mine, urne, tonneau, caisse, sac, draugr, bandit, mage, troll
ButinTables.contenu(liste: Array) -> Dictionary              # {id: n}, format de scripts/butin.gd
ButinTables.resoudre(butin: Dictionary, id_contenant: String) -> Dictionary   # objets fixes + tirage de butin["table"] (+ "zone")
ButinTables.prendre(inv: Inventaire, liste: Array) -> Array[Dictionary]       # met dans le sac (uniques déjà pris → pièces), renvoie ce qui a été ajouté
ButinTables.rarete_de(id: String) -> String
ButinTables.piller(id_contenant) / est_pille(id_contenant) -> bool
ButinTables.exporter() -> Dictionary / importer(d) / reinitialiser()   # appelés par monde.gd (clé "butin" de la sauvegarde)
ButinTables.verifier() -> Array[String]                                 # erreurs des données (test)

Inventaire.objet(id) -> Dictionary      # OBJETS + data/butin/objets.json ; Inventaire.connu(id), Inventaire.categorie_de(id)
inv.ids_de("consommable") -> Array[String] ; inv.nombre(id) -> int

Consommables.est(id) / refus(joueur, id) -> String / utiliser(joueur, id) -> String / description(id) -> String
EquipementMains.assigner_conso(i, id) -> String ; conso_du_raccourci(i) -> String
MainSort.utiliser_conso(id) -> String   # avis HUD (ou refus)
```

Exemples pour les lots suivants :

```gdscript
# L5 — urne cassée dans la crypte (identifiant stable de la pose)
var id := "crypte:urne_%s" % salle_et_index
if not ButinTables.est_pille(id):
	var liste := ButinTables.tirer_pour(id, ButinTables.table_pour("urne", "crypte"), "crypte")
	ButinTables.prendre(joueur.inventaire, liste)
	ButinTables.piller(id)

# L3 — fenêtre de butin : une ligne par objet, couleur de rareté
for o in liste:
	ligne(joueur.inventaire.nom(o.id), o.n, Color(ButinTables.COULEURS_RARETE[o.rarete]), Inventaire.objet(o.id).get("poids", 0.0))

# L8 — stock d'un marchand renouvelé tous les 3 jours : graine = marchand + période
var stock := ButinTables.tirer_pour("marchand:forgeron:%d" % int(jour / 3), "stock_forgeron")
```

## 4. Branchements faits dans L4

- `DonjonKit.interaction` (donc `DonjonKit.coffre` et les urnes / cachettes) : un `butin` qui contient `"table"` est résolu par
  `ButinTables.resoudre` → objets fixes **plus** le tirage. Sans `"table"`, contenu inchangé (coffres de quête).
- `scripts/crypte_donjon.gd` : 25 coffres, urnes et cachettes ont une table (`coffre_crypte`, `coffre_crypte_riche` pour
  les trésors du jarl et l'armurerie, `coffre_boss` pour le coffre du Jarl, `urne`, `sac` ; étage inférieur en zone
  `crypte_basse`). Inchangés : Coffre de la Dame, Reliquaire des Os, Coffre de la garde (reliques de quête).
- `scripts/grotte_jeu.gd` + `grotte_donnees.gd` : mines (`coffre_mine`), camp et corniche (`coffre_bandit`), coffre de
  l'explorateur (`coffre_crypte_riche`), zone `grotte` ; inchangés : Sac de l'expédition (broche), Cachette de Hrafn.
- Bourses : `draugr.gd` (`cadavre_draugr`, ou `cadavre_bandit` pour un personnage humain ; or des chefs Hrafn / Jarl à
  graine fixe), `mage_nordique_ia.gd` (`cadavre_mage`), `troll_givre_ia.gd` (`cadavre_troll`). `dragon.gd` inchangé.
- État « vidé » : les coffres de crypte et de grotte restent marqués par `quetes.vus` (comme avant, et une bourse non
  ramassée est perdue à la mort). `ButinTables.pilles` sert aux nouveaux contenants (L5, corps L3) ; sauvegardé dans
  `monde.gd` (`"butin"`), remis à zéro au lancement d'une partie.

## 4 bis. Objets cassables (lot L5)

- `scripts/cassable.gd` (`Cassable`) : urnes et tonneaux du décor de la crypte et de la grotte (`CrypteDecor.cassable_debut/fin`, appelés par
  `ObjPetitMobilier.urne/tonneau`). Leurs triangles vont dans un tampon à part (lot `cass:<id>`), `finir()` en fait un nœud avec maillage et
  solide propres ; aucun tirage de `rng` / `rng_deco`, aucune emprise changée. Caisses de la grotte : non cassables (solide fusionné dans la roche).
- Identifiant stable : `<crypte|id de grotte>:<urne|tonneau>_<x*10>_<y*10>_<z*10>` (position dans le repère du lieu). État : `ButinTables.piller(id)`
  (sauvegardé avec la clé « butin ») ; un objet déjà pillé se brise sans bruit au premier contrôle (le monde est bâti avant le chargement).
- Coups : lame (`TraceLame.MASQUE` inclut le calque `Cassable.CALQUE` = 64, groupe « cassables », `frapper()`), sorts (`briser_sort()` : projectiles
  de `ProjectileSort`, jets de `GestionMagie` hors soin). Le calque 64 est franchissable (joueur / ennemis : masque 1) ; tout test de parcours
  par requête de forme doit avoir `collision_mask = 1`.
- Casse : 6 éclats (3 secteurs x 2 hauteurs) tirés des vrais triangles, retombée à la main (pas de RigidBody), `GerbePixels` (pierre / bois +
  poussière), son, bourse `butin.gd` si le tirage `table_pour("urne" | "tonneau", zone)` n'est pas vide (graine fixe par id).

## 5. Consommables

| id | effet | rareté |
|---|---|---|
| `potion_soin` | +40 vie | commun |
| `potion_soin_forte` | +100 vie | peu commun |
| `potion_mana` | +50 mana | commun |
| `potion_endurance` | +60 vigueur (endurance) | commun |
| `pain_seigle` | +8 vie, +20 vigueur | commun |
| `viande_sechee` | +15 vie | commun |
| `tome_boule_feu`, `tome_lance_givre`, `tome_drain_vie` | apprend le sort | rare |

- Effets instantanés sur les vraies stats (`joueur.soigner`, `joueur.mana`, `joueur.vigueur`, plafonnés au max) ;
  refus (et objet gardé) si la stat est pleine, le sort connu, le joueur mort.
- Inventaire (I) : catégorie **Potions** (`data/magie/inventaire.json`), entre Sorts et Divers (Divers n'affiche plus les
  consommables). Clic gauche / droit, Entrée, G ou D = utiliser ; un chiffre 1-0 dans cette catégorie range la potion choisie
  dans ce raccourci.
- Raccourci de consommable : entrée `{"touche", "conso": id, "nom"}` dans `EquipementMains.raccourcis` (sauvegardée) ; la
  touche boit sans changer les mains ni couper une incantation ; le HUD affiche l'icône au centre de la case et le nombre
  restant (grisé à 0). Assigner des mains au raccourci efface le consommable.
- Icônes : motifs 16x16 dans `IconesCombat.MOTIFS` (`potion_*`, `pain_seigle`, `viande_sechee`, `tome`), couleurs de la
  palette existante (bleu `u`/`U` repris de la palette glace).

## 6. Épées et sorts venant du butin

`data/magie/inventaire.json` garde `tout_disponible = true` (période de test). Les tables donnent déjà `epee_or`,
`epee_rubis`, `epee_verre`, `epee_obsidienne` (unique) par la sous-table `armes`, et des tomes de sorts. Pour passer au
butin : `tout_disponible = false`, puis `"inventaire": "epee_or"` (etc.) sur les objets du catalogue ; les tomes ajoutent
déjà le sort à `sorts_connus` (sauvegardé).

## 7. Limites connues

- Les sacs sur le sol restent la bourse de `scripts/butin.gd` (L2 / L3 les remplaceront).
- Pas de délai entre deux potions ni d'effet dans la durée (régénération) : instantané.
- `graine_monde` n'est pas encore tirée au hasard pour une nouvelle partie (constante) ; si un jour elle l'est, la fixer
  **avant** la construction des donjons.
- Pas de poids maximal du sac (le poids est calculé, non limité).
