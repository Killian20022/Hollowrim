class_name Progression
extends RefCounted
## État du personnage (docs/RPG.md §5) : niveau, expérience de niveau, points à dépenser, attributs, perks, compétences.
## Tenue par le joueur (joueur.progression) ; joueur.competences reste l'objet Competences de la progression (alias : aucun
## appel existant ne change). Progression hybride (Q1 c) : chaque niveau de compétence gagné rapporte autant d'XP de niveau
## que le niveau atteint, les quêtes en donnent aussi ; chaque niveau = 1 choix d'attribut (+10 vie / magie / vigueur) et
## 1 point d'arbre.
## LOT 0 (socle) : API stable, corps minimaux. LOT B remplit : 8 compétences réelles, arbre (data/competences/arbre.json),
## mult / bonus des perks, perks spéciaux, réinitialisation chez Sigrún. Les noms et signatures ci-dessous NE CHANGENT PAS.

signal niveau_perso(niveau: int)                  ## niveau du personnage gagné (une fois par niveau)
signal niveau_competence(nom: String, niveau: int) ## nom canonique (COMPETENCES), relais de Competences.niveau_gagne
signal change                                      ## tout changement (points, attributs, perks, niveau) : UI, recalculer_stats

## Les 8 compétences (noms canoniques, ceux de la sauvegarde v2 et de l'arbre). Q1 c.
const COMPETENCES := ["une_main", "deux_mains", "parade", "armure", "destruction", "restauration", "furtivite", "athletisme"]
## Nom interne de Competences -> nom canonique (le lot B pourra renommer « epee » en « une_main » : vider alors l'entrée).
const ALIAS_COMPETENCES := {"epee": "une_main"}
const ATTRIBUTS := ["vie", "magie", "vigueur"]
const GAIN_ATTRIBUT := 10            ## +10 à la jauge choisie, par niveau
const CHARGE_PAR_VIGUEUR := 0.5      ## +5 de charge par choix « vigueur » (10 points)
const NIVEAU_MAX := 81               ## plafond technique (tout au maximum ≈ 80) ; de fait ~50 (docs/CONCEPTION_RPG §2.7)
## XP d'une quête terminée sans champ `recompense.xp` dans data/quetes.json (migration v1 et lot B : même valeur).
const XP_QUETE_DEFAUT := 150
const PRIX_REINITIALISATION := 500   ## Sigrún (Q6 b), lot B

var niveau := 1
var xp_niveau := 0.0                 ## XP accumulée vers le niveau suivant (0 .. seuil_niveau(niveau))
var points_perk := 0                 ## points d'arbre non dépensés
var points_attribut := 0             ## choix d'attribut en attente (écran de niveau, lot D)
var attributs := {"vie": 0, "magie": 0, "vigueur": 0}
var perks := {}                      ## id -> rang acheté (lot B)
var competences := Competences.new() ## progression à l'usage (scripts/competences.gd)
## Équipement de corps, pour bonus() (posé par le joueur) ; null dans les tests unitaires.
var equipement_corps: EquipementCorps = null
## Données de compétences de la sauvegarde que Competences ne connaît pas encore (5 nouvelles avant le lot B) : rendues
## telles quelles à l'export, rien ne se perd.
var _comp_inconnues := {"niveaux": {}, "experience": {}}

# ------------------------------------------------------------------ joueur courant (ReglagesCombat.competence)

static var _courant: WeakRef = null

## Le joueur rend sa progression « courante » : ReglagesCombat.competence() lit alors ses multiplicateurs.
func activer() -> void:
	_courant = weakref(self)

static func courante() -> Progression:
	return _courant.get_ref() as Progression if _courant != null else null

## Multiplicateur de l'arbre pour une clé de ReglagesCombat.COMPETENCES (« une_main », « destruction », « armure »…) :
## 1,0 si aucun joueur (tests, scènes d'essai) ou rien d'acheté.
static func mult_global(cle: String) -> float:
	var p := courante()
	return p.mult(cle) if p != null else 1.0

func _init() -> void:
	competences.niveau_gagne.connect(_sur_niveau_competence)

# ------------------------------------------------------------------ compétences

static func canonique(nom: String) -> String:
	return String(ALIAS_COMPETENCES.get(nom, nom))

static func interne(nom: String) -> String:
	for k in ALIAS_COMPETENCES:
		if ALIAS_COMPETENCES[k] == nom:
			return String(k)
	return nom

## Niveau 15..100 d'une compétence (nom canonique ou interne).
func competence(nom: String) -> int:
	var i := interne(canonique(nom))
	if competences.niveaux.has(i):
		return int(competences.niveaux[i])
	return int(_comp_inconnues["niveaux"].get(canonique(nom), Competences.DEPART))

## Pratique d'une compétence (remplace Competences.pratiquer, qui reste valable). Compétence pas encore gérée : ignorée.
func pratiquer(nom: String, quantite: float) -> void:
	var i := interne(canonique(nom))
	if competences.niveaux.has(i):
		competences.pratiquer(i, quantite)

func _sur_niveau_competence(nom: String, n: int) -> void:
	niveau_competence.emit(canonique(nom), n)
	gagner_xp(float(n))

# ------------------------------------------------------------------ niveau du personnage

## XP de niveau pour passer de n à n+1.
static func seuil_niveau(n: int) -> float:
	return 100.0 + 50.0 * n

## XP de niveau rapportée par une compétence montée de DEPART à `n` (somme des niveaux atteints).
static func xp_competence_jusqua(n: int) -> float:
	var t := 0.0
	for k in range(Competences.DEPART + 1, n + 1):
		t += k
	return t

## Ajoute de l'XP de niveau (montée de compétence, quête). Chaque niveau : +1 point d'arbre, +1 choix d'attribut.
func gagner_xp(quantite: float, annoncer := true) -> void:
	if quantite <= 0.0:
		return
	xp_niveau += quantite
	while niveau < NIVEAU_MAX and xp_niveau >= seuil_niveau(niveau):
		xp_niveau -= seuil_niveau(niveau)
		niveau += 1
		points_perk += 1
		points_attribut += 1
		if annoncer:
			niveau_perso.emit(niveau)
	change.emit()

## Part de la barre de niveau (0 → 1).
func part_niveau() -> float:
	return clampf(xp_niveau / seuil_niveau(niveau), 0.0, 1.0)

## Dépense un choix d'attribut : "" si fait, sinon la raison.
func choisir_attribut(nom: String) -> String:
	if not nom in ATTRIBUTS:
		return "Attribut inconnu."
	if points_attribut <= 0:
		return "Aucun niveau en attente."
	points_attribut -= 1
	attributs[nom] = int(attributs[nom]) + GAIN_ATTRIBUT
	change.emit()
	return ""

# ------------------------------------------------------------------ arbre (lot B)

func a_perk(id: String) -> bool:
	return int(perks.get(id, 0)) > 0

func rang_perk(id: String) -> int:
	return int(perks.get(id, 0))

## Achète un rang de perk : "" si fait, sinon la raison. LOT B : prérequis, niveau requis, rangs (data/competences/arbre.json).
func acheter_perk(_id: String) -> String:
	return "L'arbre de compétences n'est pas encore gravé."

## Rend tous les points d'arbre (Sigrún, PRIX_REINITIALISATION pièces : le paiement est fait par l'appelant).
func reinitialiser_perks() -> void:
	for id in perks:
		points_perk += int(perks[id])
	perks = {}
	change.emit()

## Multiplicateur d'une clé (1,0 = neutre) : produit des effets des perks (lot B). Clés : docs/RPG.md §3.
func mult(_cle: String) -> float:
	return 1.0

## Bonus additif d'une clé (« vie_max », « charge », « resist_froid »…) : perks (lot B) + équipement de corps.
func bonus(cle: String) -> float:
	var b := 0.0
	if equipement_corps != null:
		b += float(equipement_corps.effets_totaux().get(cle, 0.0))
	return b

## Maxima dérivés (joueur.recalculer_stats) : jamais stockés, toujours recalculés.
func bonus_vie() -> float:
	return float(attributs["vie"]) + bonus("vie_max")

func bonus_magie() -> float:
	return float(attributs["magie"]) + bonus("magie_max")

func bonus_vigueur() -> float:
	return float(attributs["vigueur"]) + bonus("vigueur_max")

func bonus_charge() -> float:
	return float(attributs["vigueur"]) * CHARGE_PAR_VIGUEUR + bonus("charge")

# ------------------------------------------------------------------ sauvegarde (clé « progression », version 2)

func exporter() -> Dictionary:
	var c := competences.exporter()
	var niv := {}
	var xp := {}
	for k in _comp_inconnues["niveaux"]:
		niv[k] = _comp_inconnues["niveaux"][k]
	for k in _comp_inconnues["experience"]:
		xp[k] = _comp_inconnues["experience"][k]
	for k in c["niveaux"]:
		niv[canonique(k)] = c["niveaux"][k]
	for k in c["experience"]:
		xp[canonique(k)] = c["experience"][k]
	return {"niveau": niveau, "xp_niveau": xp_niveau, "points_perk": points_perk, "points_attribut": points_attribut,
		"attributs": attributs.duplicate(), "perks": perks.duplicate(), "competences": {"niveaux": niv, "experience": xp}}

func importer(d: Dictionary) -> void:
	niveau = clampi(int(d.get("niveau", 1)), 1, NIVEAU_MAX)
	xp_niveau = maxf(0.0, float(d.get("xp_niveau", 0.0)))
	points_perk = maxi(0, int(d.get("points_perk", 0)))
	points_attribut = maxi(0, int(d.get("points_attribut", 0)))
	var a: Dictionary = d.get("attributs", {})
	for k in ATTRIBUTS:
		attributs[k] = int(a.get(k, 0))
	perks = {}
	var p: Dictionary = d.get("perks", {})
	for k in p:
		perks[String(k)] = int(p[k])
	var c: Dictionary = d.get("competences", {})
	var niv: Dictionary = c.get("niveaux", {})
	var xp: Dictionary = c.get("experience", {})
	var interne_niv := {}
	var interne_xp := {}
	_comp_inconnues = {"niveaux": {}, "experience": {}}
	for k in niv:
		var i := interne(String(k))
		if competences.niveaux.has(i):
			interne_niv[i] = niv[k]
		else:
			_comp_inconnues["niveaux"][String(k)] = int(niv[k])
	for k in xp:
		var i := interne(String(k))
		if competences.niveaux.has(i):
			interne_xp[i] = xp[k]
		else:
			_comp_inconnues["experience"][String(k)] = float(xp[k])
	competences.importer({"niveaux": interne_niv, "experience": interne_xp})
	change.emit()
