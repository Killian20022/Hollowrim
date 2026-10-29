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
- État « vidé » : les coffres de crypte et de grotte restent marqués par `quetes.vus` (ouvert = pièces au sac, même après la
  mort : lots L2-L3). `ButinTables.pilles` sert aux nouveaux contenants (L5) ; sauvegardé dans `monde.gd` (`"butin"`), remis à
  zéro au lancement d'une partie.

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
| `tome_<sort>` (un par sort hors départ : 11 tomes ; Grima vend les sorts de base, les coffres les plus forts) | apprend le sort | rare |

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

- ~~Les sacs sur le sol restent la bourse de `scripts/butin.gd`~~ : remplacés par les pièces qui jaillissent (L2) et la fenêtre de butin (L3).
- Potions progressives (`scripts/effets_potions.gd`, `joueur.potions`) : vie/mana/vigueur versées sur `duree` s (petite 4 s, grande 6 s, pain 12 s, viande 10 s), délai de 3 s (2 s nourriture) par `famille`, icônes pot_vie/pot_mana/pot_vigueur dans la rangée de statuts du HUD ; non sauvegardé.
- Poids du sac limité : `Inventaire.CAPACITE` = 100 ; au-delà, joueur surchargé (vitesse x0,6, pas de course, avis) ; butin (fenêtre) et marchands refusent / limitent à la capacité ; bourse du sol et récompenses de quête non limitées.
- `graine_monde` n'est pas encore tirée au hasard pour une nouvelle partie (constante) ; si un jour elle l'est, la fixer
  **avant** la construction des donjons.

## 8. Pièces qui jaillissent (L2) et fenêtre de butin (L3)

- **Coffre** (`tertre.gd` / `grotte_jeu.gd` : `_ouvrir_coffre`) : à la première ouverture, les PIÈCES vont au sac tout de suite et
  jaillissent du coffre (`scripts/butin.gd`, `deja_verse`, aspirées vers le joueur) ; l'or de la cuve (module `coffre_or_x` /
  `coffre_royal_or`, à part de la cuve depuis L3) s'enfonce sous le fond puis disparaît (`CoffreCouvercle`) ; les OBJETS restent
  dans `ButinTables.restes["<contenant>"]` et la fenêtre de butin s'ouvre (`FenetreButin.fouiller`). Fenêtre fermée avant la fin :
  le coffre devient « Fouiller le coffre » (objets laissés sauvegardés, clé `butin.restes`) ; tout pris : plus d'invite.
- **Corps** (`draugr.gd`, `ennemi_base.gd`, `dragon.gd` → `butin.gd`) : pièces au sol autour du corps, versées une fois quand le joueur
  passe à moins de 1,5 m ; objets : invite « Fouiller » (nom de l'ennemi) → fenêtre ; le nœud part quand tout est pris.
- **Fenêtre** (`scripts/fenetre_butin.gd`, une instance créée par `monde._interface`, groupe `fenetre_butin`) : jeu en pause ; une ligne
  par objet (icône, nom en couleur de rareté, nombre, poids), triées unique → commun ; fiche (rareté, valeur, effet) ; poids du sac.
  E / Entrée / Espace / clic / A = prendre ; R / Y = tout prendre ; Échap / Tab / clic droit / B = fermer ; flèches, Z/S, molette,
  croix = choisir. La prise passe par `ButinTables.prendre` (unique déjà pris → pièces).
- API : `FenetreButin.trouver(noeud)`, `ouvrir(titre, objets, pieces_versees, fin) -> bool` (objets modifié en place), `prendre(i)`,
  `tout_prendre()`, `fermer()` ; `ButinTables.reste(id) / a_reste(id) / restes`.
- Tests : `outils/test_butin_l2.gd`, `outils/test_fenetre_butin.gd`, `outils/test_coffre_l1.gd` (objets laissés relus après chargement).
  Captures : `outils/captures_butin_l2l3.gd -- --sequence` (gerbes) / `--fenetre [--petit]` (fenêtre, aussi en 480x270).
- Limites : le butin d'un corps n'est pas sauvegardé (un ennemi tué puis sauvegardé ne revient pas, son butin non pris est perdu,
  comme l'ancienne bourse) ; l'or de chaque coffre à couvercle est un maillage à part (1 à 2 appels de dessin de plus par coffre
  dans la portée de dessin, exception « objets interactifs » du socle).

## 9. Marchands (lot L8)

Brodd le Large (forgeron, id `forgeron`) et Grima Cendrefroide (doyenne du puits, id `ancienne`). Fichiers : `scripts/marchand.gd`
(`Marchand` : état statique + boutique), `data/marchands.json`, `scripts/dialogue.gd` (option « Commercer »), `outils/test_marchands.gd`,
`outils/captures_marchands.gd`.

- **Données** (`data/marchands.json`, clé = id du villageois) : `titre`, `or` (bourse au début de chaque période), `renouvellement_jours` (2),
  `achat` (1,1 Brodd ; 1,15 Grima), `vente` (0,4), `achete` (catégories ou ids rachetés), `stock` (`{id, n, chance}`).
  Brodd : épées (or, rubis, verre, au hasard), minerais, cristal, fourrure, anneau ; rachète armes, métaux, trophées, bijoux.
  Grima : potions, pain, viande séchée, champignons, poussière de tombe ; rachète consommables, ingrédients, os, bijoux.
  Le test vérifie que tout objet vendable du catalogue a au moins un acheteur.
- **Prix** : achat = `ceil(valeur x achat)`, rachat = `floor(valeur x vente)` (1 au moins). Exemples : minerai de fer 12 → 14 / 4,
  collier d'or 85 → 94 / 34, potion de soin chez Grima 30 → 35 / 12.
- **Jamais vendables** : valeur 0 (objets de quête), liste `invendables`, et tout objet demandé par une étape `objet:<id>>=n` d'une quête
  EN COURS (les lames antiques pendant « Le fer des morts »). Ils restent listés en bas de l'onglet Vendre, grisés, avec la raison.
- **Stock et temps** : `Marchand.heures` = heures de jeu écoulées depuis le début de la partie, suivies sur `cycle.heure` (arrêtée en pause ;
  un saut > 6 h, chargement ou capture, n'est pas compté). Période = `floor(heures / (24 x renouvellement_jours))` ; à chaque nouvelle période
  le stock est tiré à nouveau (graine `ButinTables.graine("marchand:<id>:<période>")`, même période = même étal), la bourse revient à `or`,
  ce que le joueur avait vendu disparaît. Un achat retire du stock et remplit la bourse ; une vente vide la bourse (refus si elle ne suffit
  pas) et met l'objet sur l'étal.
- **Sauvegarde** : clé `"marchands"` de `monde.sauvegarder()` = `{heures, etats: {id: {periode, or, stock}}}` ; `Marchand.reinitialiser()`
  à chaque lancement de partie, `Marchand.importer()` dans `charger()`.
- **Dialogue** : chez un marchand, cartouche « [T] Commercer » en haut à droite de la boîte pendant toute la conversation ; sur la
  dernière réplique, choix « Commercer / Au revoir » (haut/bas, Z/S ; E / Entrée / Espace = valider). Manette : A = suite / valider,
  B = fermer, X = commercer, croix = choisir. Correction au passage : E qui termine la réplique ne fait plus repartir la machine à écrire.
- **Boutique** (une instance, `monde.marchand`, calque 44, groupe `marchand`) : jeu en pause ; titre en Jacquard 24, or du joueur
  (pièce dessinée + chiffres Kenney), onglets Acheter / Vendre, bourse du marchand ; une carte par objet (icône, nom en couleur de
  rareté, effet ou « Arme, 9 kg », nombre, prix en or, rouge si on ne peut pas payer) ; ligne d'information (retour de la dernière
  transaction, « Stock limité, réassort dans 1 j 6 h ») ; étal vide : « Étal vide. Revenez dans … ».
  Clavier : E / Entrée / Espace = un, R = toute la pile, Tab / flèches gauche-droite / Q-D = onglet, haut-bas / Z-S / molette = choisir,
  Échap / clic droit = fermer. Manette : A, Y (pile), LB / RB ou croix gauche-droite, croix haut-bas, B.
- **API** : `Marchand.pour_pnj(pnj)`, `etat(id)`, `stock(id)`, `or_de(id)`, `prix_achat(id, oid)`, `prix_vente(id, oid)`, `de_quete(oid, quetes)`,
  `refus_vente(id, oid, quetes)`, `acheter(id, inv, oid, n) -> String`, `vendre(id, inv, oid, n, quetes) -> String` (refus, "" = fait),
  `avancer(heures)`, `heures_avant_reassort(id)`, `exporter() / importer(d) / reinitialiser()`, `verifier()` ;
  boutique : `Marchand.trouver(n)`, `ouvrir(id) -> bool`, `fermer()`, `changer_onglet(i)`, `traiter(i, tout) -> String`.
- **Limites** : pas d'armures dans le jeu (le forgeron vend armes et matériaux) ; les épées achetées n'ont pas encore d'effet tant que
  `data/magie/inventaire.json` garde `tout_disponible = true` ; pas de marchandage ni de prix selon une compétence ; pas de réparation.
