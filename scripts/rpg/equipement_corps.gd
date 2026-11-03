class_name EquipementCorps
extends RefCounted
## Équipement de corps (Q3 b) : tete, torse, mains, pieds, cou, anneau, jambes (jambières : emplacement ajouté après coup, une sauvegarde
## sans cette clé reste valide : importer() la laisse vide, le torse porté garde alors ses chausses par défaut). Les mains (armes, bouclier, sorts, torche) restent
## à EquipementMains (ne pas fusionner : docs/RPG.md §6). Contrat : docs/RPG.md §4.
## Un objet équipé RESTE dans le sac (il compte dans le poids, Q5) ; s'il quitte le sac (vendu, lâché, déposé), il est
## retiré de son emplacement automatiquement. Armure non visible sur le héros pour l'instant (Q4 a).
## LOT 0 : API et règles de base ; LOT A : effets en jeu. Armure : joueur.recevoir_coup applique aux coups PHYSIQUES
## dégâts × ARMURE_REFERENCE / (ARMURE_REFERENCE + armure_totale() × ReglagesCombat.competence("armure")) (60 d'armure =
## −33 %, 120 = −50 %) ; coups élémentaires (options.type glace / feu / electricite) : résistance resist_* (clés §3,
## équipement + perks via Progression.bonus), plafonnée à RESISTANCE_MAX, sans l'armure.

signal change(emplacement: String)

## Points d'armure qui divisent les dégâts par deux (formule ci-dessus).
const ARMURE_REFERENCE := 120.0
## Une résistance élémentaire ne retire jamais plus de 80 % d'un coup.
const RESISTANCE_MAX := 0.8
## Vulnérabilité maximale (traits négatifs : obsidienne, resist_magie −10 % pour l'ensemble) : +25 % de dégâts au plus.
const RESISTANCE_MIN := -0.25
## Type de dégâts d'un coup reçu (options.type de recevoir_coup, DonneesSort.type_degats) -> clé de résistance (§3).
const RESISTANCES := {"glace": "resist_froid", "givre": "resist_froid", "froid": "resist_froid", "gel": "resist_froid",
	"feu": "resist_feu", "brulure": "resist_feu", "electricite": "resist_choc", "choc": "resist_choc"}
## Types de dégâts MAGIQUES (refonte HD 2026-11-02) : la clé « resist_magie » s'ajoute à leur résistance propre (plafond commun
## RESISTANCE_MAX). « tenebres » / « magie » n'ont pas de résistance propre : seulement resist_magie (et pas l'armure).
const TYPES_MAGIQUES := ["glace", "givre", "froid", "gel", "feu", "brulure", "electricite", "choc", "tenebres", "magie"]

var inventaire: Inventaire = null
var emplacements := {"tete": "", "torse": "", "mains": "", "pieds": "", "cou": "", "anneau": "", "jambes": ""}

func _init(inv: Inventaire = null) -> void:
	lier(inv)

func lier(inv: Inventaire) -> void:
	if inventaire != null and inventaire.change.is_connected(_sur_sac):
		inventaire.change.disconnect(_sur_sac)
	inventaire = inv
	if inventaire != null:
		inventaire.change.connect(_sur_sac)

## "" si l'objet peut être porté, sinon la raison (message lisible).
func refus(id: String) -> String:
	if not Inventaire.connu(id):
		return "Objet inconnu."
	var e := Inventaire.emplacement_de(id)
	if e == "" or not emplacements.has(e):
		return "%s ne se porte pas." % Inventaire.objet(id).get("nom", id)
	if inventaire != null and not inventaire.a(id):
		return "Vous n'avez pas cet objet."
	return ""

## Équipe `id` à son emplacement (remplace l'objet qui y était) : "" si fait, sinon la raison.
func equiper(id: String) -> String:
	var r := refus(id)
	if r != "":
		return r
	var e := Inventaire.emplacement_de(id)
	if emplacements[e] == id:
		return ""
	emplacements[e] = id
	change.emit(e)
	return ""

func retirer(emplacement: String) -> void:
	if emplacements.get(emplacement, "") == "":
		return
	emplacements[emplacement] = ""
	change.emit(emplacement)

func objet_a(emplacement: String) -> String:
	return String(emplacements.get(emplacement, ""))

func est_equipe(id: String) -> bool:
	return id != "" and emplacements.values().has(id)

## Somme des points d'armure portés (avant multiplicateur de la compétence Armure : lot A).
func armure_totale() -> float:
	var t := 0.0
	for e in emplacements:
		if emplacements[e] != "":
			t += float(Inventaire.objet(emplacements[e]).get("armure", 0.0))
	return t

## Somme des effets portés (clés communes : docs/RPG.md §3), lue par Progression.bonus() : « traits » de matière (armures HD,
## toujours actifs, malus négatifs permis) + « effets » (enchantements).
func effets_totaux() -> Dictionary:
	var t := {}
	for e in emplacements:
		if emplacements[e] == "":
			continue
		var ef := effets_de(emplacements[e])
		for k in ef:
			t[k] = float(t.get(k, 0.0)) + float(ef[k])
	return t

## Effets d'UNE pièce : traits de matière + enchantement (valeurs numériques seulement) ; affichage des menus, comparaisons.
static func effets_de(id: String) -> Dictionary:
	var t := {}
	var f := Inventaire.objet(id)
	for champ in ["traits", "effets"]:
		var ef: Variant = f.get(champ, {})
		if ef is Dictionary:
			for k in ef:
				if typeof(ef[k]) in [TYPE_INT, TYPE_FLOAT]:
					t[k] = float(t.get(k, 0.0)) + float(ef[k])
	return t

## Valeur d'un effet porté (0 si aucun) : raccourci de effets_totaux().
func effet(cle: String) -> float:
	return float(effets_totaux().get(cle, 0.0))

## Poids des pièces portées (déjà compté dans le sac : information pour l'interface).
func poids_porte() -> float:
	var t := 0.0
	for e in emplacements:
		if emplacements[e] != "":
			t += float(Inventaire.objet(emplacements[e]).get("poids", 0.0))
	return t

## Nombre de pièces d'armure portées du type « lourde » / « legere » (arbre « Armure », lot B).
func nombre_pieces(type_armure: String) -> int:
	var n := 0
	for e in emplacements:
		if emplacements[e] != "" and String(Inventaire.objet(emplacements[e]).get("type_armure", "")) == type_armure:
			n += 1
	return n

## Clé de résistance (« resist_froid »…) d'un type de dégâts, "" pour un coup physique.
static func cle_resistance(type_degats: String) -> String:
	return String(RESISTANCES.get(type_degats, ""))

## Vrai si un coup de ce type est magique / élémentaire (résistances, pas l'armure).
static func est_magique(type_degats: String) -> bool:
	return type_degats in TYPES_MAGIQUES

## Part retirée d'un coup de `type_degats` par les résistances de `p` (Progression : perks + équipement) : resist_<élément> +
## resist_magie, bornée à RESISTANCE_MIN..RESISTANCE_MAX (négative = vulnérabilité) ; 0 pour un coup physique ou sans progression.
static func resistance_totale(p: Progression, type_degats: String) -> float:
	if p == null or not est_magique(type_degats):
		return 0.0
	var cle := cle_resistance(type_degats)
	var r := p.bonus("resist_magie") + (p.bonus(cle) if cle != "" else 0.0)
	return clampf(r, RESISTANCE_MIN, RESISTANCE_MAX)

## Facteur appliqué aux dégâts physiques pour `armure` points (déjà multipliés par la compétence Armure).
static func facteur_armure(armure: float) -> float:
	return ARMURE_REFERENCE / (ARMURE_REFERENCE + maxf(armure, 0.0))

## Le sac a changé : un objet porté qui n'y est plus est retiré.
func _sur_sac() -> void:
	if inventaire == null:
		return
	for e in emplacements:
		if emplacements[e] != "" and not inventaire.a(emplacements[e]):
			emplacements[e] = ""
			change.emit(e)

func exporter() -> Dictionary:
	return emplacements.duplicate()

## Relit les emplacements (après l'inventaire) ; objet inconnu, absent du sac ou au mauvais emplacement : ignoré.
func importer(d: Dictionary) -> void:
	for e in emplacements:
		emplacements[e] = ""
	for e in d:
		var id := Inventaire.alias(String(d[e]))
		if emplacements.has(e) and id != "" and refus(id) == "" and Inventaire.emplacement_de(id) == e:
			emplacements[e] = id
	change.emit("")
