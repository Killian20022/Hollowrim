class_name Finishers
## Catalogue des FINISHERS (achèvements) lancés par l'épée du joueur, choisis selon le contexte (docs/COMBAT.md, « Finishers ») :
##
## | nom          | contexte                                          | geste du bras (bras_finishers.tres)        | victime                   |
## |--------------|---------------------------------------------------|--------------------------------------------|---------------------------|
## | plantee      | debout, DE FACE (étourdi, après parade, presque mort) | estoc, lame PLANTÉE ~0,55 s, retrait sec   | se plie sur la lame, tombe |
## | pommeau      | debout, de face (alterne avec plantee)            | pommeau au visage puis estoc planté court  | tête rejetée, recule, estoc |
## | decapitation | pris DE CÔTÉ (catégorie « lateral ») ou de face   | grand revers horizontal au cou             | tête tranchée (Decapitation) |
## | dos          | DANS SON DOS (> 120° de son regard)               | estoc planté entre les omoplates           | se cambre, s'affaisse      |
## | plonge       | À TERRE (catégorie « sol »)                       | lame levée, plongée dans la poitrine       | spasme, retombe            |
## Créatures hors gabarit humain (troll : > 2,3 m, mannequin sans squelette) : ancien finisher court (GestesDefense).
##
## Chaque finisher : clip du bras + marqueurs (lus dans le clip), ALIGNEMENTS (où la cible doit être, à quel instant, pour que
## la lame la traverse VRAIMENT : un point de l'épée — y_lame dans le repère de l'arme, + decalage dans le repère caméra — doit
## tomber sur un os de la victime), tangage de caméra résolu pour que la victime garde les pieds au sol, CLÉS DE POSE de la
## victime (PoseFinisher) et ÉVÉNEMENTS (sang, sons, mort). Le moteur : SequenceFinisher.

## Pointe de la lame dans le repère de l'épée (m, garde à 0,096) : bras_godot.json « pointe ».
const POINTE := 0.965
const GARDE := 0.096

const CATALOGUE := {
	"plantee": {
		"clip": "fin_plantee", "orientation": "face",
		# le centre du buste à 5 cm avant la pointe au contact (8 cm après la poussée) : la pointe est DANS le torse (demi-épaisseur
		# ~0,13 m) sans ressortir dans le dos ; ~0,18 m de lame dans le corps
		"alignements": [{"marqueur": "contact", "os": "spine_03", "y_lame": POINTE - 0.05, "decalage": Vector3.ZERO, "depuis": 0.0}],
		"pose": [
			[0.0, {}],
			[0.27, {"buste": -0.05, "tete": -0.1}],
			[0.33, {"buste": 0.42, "tete": 0.3, "bras": 0.55, "coudes": 0.5, "genoux": 0.08, "tremble": 0.05}],
			[0.50, {"buste": 0.5, "tete": 0.45, "bras": 0.75, "coudes": 0.9, "genoux": 0.22, "tremble": 0.07}],
			[0.84, {"buste": 0.55, "tete": 0.6, "bras": 0.45, "coudes": 0.6, "genoux": 0.38, "tremble": 0.09}],
			[0.95, {"buste": 0.25, "tete": 0.2, "bras": 0.3, "coudes": 0.4, "genoux": 0.45, "tremble": 0.02}],
		],
		"evenements": [["contact", "entree"], ["plante", "jet"], ["sortie", "retrait"], ["mort", "mort"], ["suivi", "secoue"]],
		"mort": "effondre",
	},
	"dos": {
		"clip": "fin_plantee", "orientation": "dos",
		"alignements": [{"marqueur": "contact", "os": "spine_03", "y_lame": POINTE - 0.05, "decalage": Vector3.ZERO, "depuis": 0.0}],
		"pose": [
			[0.0, {}],
			[0.33, {"buste": -0.35, "tete": -0.55, "bras": -0.35, "coudes": 0.2, "tremble": 0.06}],
			[0.55, {"buste": -0.25, "tete": -0.3, "bras": -0.2, "coudes": 0.5, "genoux": 0.18, "tremble": 0.08}],
			[0.84, {"buste": 0.3, "tete": 0.5, "bras": 0.1, "coudes": 0.3, "genoux": 0.4, "tremble": 0.06}],
			[0.95, {"buste": 0.45, "tete": 0.6, "genoux": 0.5}],
		],
		"evenements": [["contact", "entree"], ["plante", "jet"], ["sortie", "retrait"], ["mort", "mort"], ["suivi", "secoue"]],
		"mort": "effondre",
	},
	"pommeau": {
		"clip": "fin_pommeau", "orientation": "face",
		"alignements": [
			# le visage (os Head + 10 cm vers l'avant de la caméra) au pommeau (8 cm sous la garde, dans l'axe de l'arme)
			{"marqueur": "contact", "os": "Head", "y_lame": -0.06, "decalage": Vector3(0, 0, -0.1), "depuis": 0.0},
			{"marqueur": "contact2", "os": "spine_03", "y_lame": POINTE - 0.05, "decalage": Vector3.ZERO, "depuis": 0.25},
		],
		"pose": [
			[0.0, {}],
			[0.22, {}],
			[0.27, {"buste": -0.3, "tete": -0.75, "bras": -0.25, "tremble": 0.03}],
			[0.45, {"buste": -0.15, "tete": -0.35, "bras": 0.1, "genoux": 0.15}],
			[0.58, {"buste": -0.05, "tete": -0.1, "bras": 0.2, "genoux": 0.1}],
			[0.63, {"buste": 0.45, "tete": 0.35, "bras": 0.6, "coudes": 0.6, "genoux": 0.15, "tremble": 0.06}],
			[0.86, {"buste": 0.55, "tete": 0.55, "bras": 0.45, "coudes": 0.7, "genoux": 0.38, "tremble": 0.08}],
			[0.95, {"buste": 0.25, "tete": 0.25, "bras": 0.3, "genoux": 0.45}],
		],
		"evenements": [["contact", "pommeau"], ["contact2", "entree"], ["plante", "jet"], ["sortie", "retrait"], ["mort", "mort"], ["suivi", "secoue"]],
		"mort": "effondre",
	},
	"decapitation": {
		"clip": "fin_decapitation", "orientation": "face",
		# le cou à 62 cm de la garde, sur le tranchant, à l'instant où la lame balaie le centre
		"alignements": [{"marqueur": "contact", "os": "neck_01", "y_lame": 0.62, "decalage": Vector3.ZERO, "depuis": 0.0}],
		"pose": [
			[0.0, {}],
			[0.3, {"buste": -0.08, "tete": -0.15, "bras": 0.15}],
		],
		"evenements": [["contact", "tranche"]],
		"mort": "decapite",
		"trainee": true,
	},
	"plonge": {
		"clip": "fin_plonge", "orientation": "garder",
		# corps au sol : le centre de la poitrine à 5 cm avant la pointe
		"alignements": [{"marqueur": "contact", "os": "spine_03", "y_lame": POINTE - 0.05, "decalage": Vector3.ZERO, "depuis": 0.0}],
		"pose": [
			[0.0, {}],
			[0.33, {}],
			[0.38, {"buste": 0.35, "tete": 0.3, "bras": 0.5, "coudes": 0.6, "tremble": 0.1}],
			[0.6, {"buste": 0.2, "tete": 0.15, "bras": 0.35, "coudes": 0.4, "tremble": 0.12}],
			[0.8, {"buste": 0.08, "bras": 0.15, "tremble": 0.05}],
			[0.95, {}],
		],
		"evenements": [["contact", "entree"], ["plante", "jet"], ["sortie", "retrait"], ["mort", "mort"], ["suivi", "secoue"]],
		"mort": "cloue",
		"sol": true,
	},
}

## Dernier finisher joué (variété : pas deux fois le même de face).
static var dernier := ""
## Finisher imposé (tests, captures) : "" = choix selon le contexte.
static var force := ""

static func existe(nom: String) -> bool:
	return CATALOGUE.has(nom)

static func donnees(nom: String) -> Dictionary:
	return CATALOGUE[nom]

## La cible a un gabarit humain (squelette RIG18, taille ≤ 2,3 m) : finishers alignés possibles.
static func humanoide(cible: Node3D) -> bool:
	var cb: Variant = cible.get("combat")
	if not (cb is CombatEnnemi):
		return false
	var c := cb as CombatEnnemi
	if c.modele == null or c.hauteur > 2.3:
		return false
	var sq := c.modele.find_child("Skeleton3D", true, false) as Skeleton3D
	return sq != null and sq.find_bone("spine_03") >= 0 and sq.find_bone("Head") >= 0 and sq.find_bone("neck_01") >= 0

## Angle (degrés) entre le regard de la cible et la direction du joueur (0 = de face, 180 = dans son dos).
static func angle_joueur(cible: Node3D, joueur: Node3D) -> float:
	var v := joueur.global_position - cible.global_position
	var face := cible.global_transform.basis.z
	return rad_to_deg(absf(Vector2(face.x, face.z).angle_to(Vector2(v.x, v.z))))

## Finisher selon le contexte ("" : ancien finisher court). `categorie` : CombatEnnemi.finisher_possible.
static func choisir(cible: Node3D, categorie: String, joueur: Node3D) -> String:
	if not humanoide(cible):
		return ""
	if force != "" and CATALOGUE.has(force):
		return force
	if categorie == "sol":
		return "plonge"
	if angle_joueur(cible, joueur) > 120.0:
		return "dos"
	if categorie == "lateral":
		return "decapitation"
	# de face : l'épée plantée d'abord (demande de l'utilisateur), puis on varie sans répéter le dernier
	var ordre := ["plantee", "pommeau", "decapitation"]
	var i := (ordre.find(dernier) + 1) % ordre.size() if dernier in ordre else 0
	return ordre[i]

## Valeurs des canaux de pose de la victime à l'instant `t` (clés [t, {canal: valeur}], lissées par morceaux).
static func pose_a(cles: Array, t: float) -> Dictionary:
	var out := {}
	if cles.is_empty():
		return out
	var canaux := ["buste", "torsion", "lateral", "tete", "bras", "coudes", "genoux", "tremble"]
	var a: Array = cles[0]
	var b: Array = cles[0]
	for k in cles.size():
		if float(cles[k][0]) <= t:
			a = cles[k]
			b = cles[mini(k + 1, cles.size() - 1)]
	var ta := float(a[0])
	var tb := float(b[0])
	var s := 1.0 if tb <= ta else smoothstep(0.0, 1.0, clampf((t - ta) / (tb - ta), 0.0, 1.0))
	var da: Dictionary = a[1]
	var db: Dictionary = b[1]
	for c: String in canaux:
		out[c] = lerpf(float(da.get(c, 0.0)), float(db.get(c, 0.0)), s)
	return out
