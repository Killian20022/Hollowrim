class_name GrotteJeu
extends RefCounted
## Gameplay d'une grotte du kit : transforme les POINTS D'ACCROCHE de Grotte.accroches (ennemis, coffres, ressources, interactions,
## mécanismes, lieux) en nœuds du monde, et gère leur état (sauvegarde par quetes.vus, mort du joueur, apparition progressive).
##
##  - coffres : interactifs « Ouvrir » (bourse BUTIN posée au-dessus, contenu {objet: n}) ; état quetes.vus["<pref>:<id>"] ; une bourse
##    non ramassée est perdue à la mort du joueur : le coffre se referme (comme la crypte).
##  - ressources : minerais, cristaux, champignons (ids d'Inventaire.OBJETS) ; état quetes.vus["<pref>:res_<id>"].
##  - interactions (récit) : journal, registre… : texte (clé de quetes.texte ou lignes), objet remis, événement de quête signalé.
##  - mécanismes : « mur_fragile » via Mecanisme.mur_fragile (cède au coup puissant ; état géré par Mecanisme, relu à la mort).
##  - lieux : événement (ex. « lieu:camp_hrafn ») signalé quand le joueur approche.
##  - ennemis : bandits (« sbire » habillé, tenue = indice de TENUES, corps Humain ; --persos-kit : PersoDefs), archers (option « archer » ; « poste » sur corniche), chef (« boss »),
##    patrouilles. Créés par petits groupes quand le joueur s'approche ; identifiants FIXES (ceux des données) ; ceux tués dans une partie
##    chargée (`acces.morts_charges`) ne reviennent pas.
##  - lumières : seules les plus proches sont allumées (au plus MAX_LUM, à moins de 26 m).
##  - ambiance (refonte matières) : ambiante sombre et neutre (les ombres tombent presque au noir, plus de « bleu plastique »),
##    brume noire (densité de Grotte.ambiance inchangée, vérifiée par test_grotte_acces) ; la couleur vient des lanternes orange et des accents froids (jour, lac, cristaux).
## Le préfixe des états est def["id"] ("grotte").

const BUTIN := preload("res://scripts/butin.gd")
const MAX_LUM := 9
const AMBIANTE := Color(0.26, 0.31, 0.40)   # passe 2 kit : gris à peine froid (plus le bleu saturé uniforme) ; le chaud vient des lanternes, le froid des cristaux et du jour
const AMBIANTE_E := 3.5
const BRUME_C := Color(0.14, 0.24, 0.42)   # v2 : brume bleu glacé (le fond s'éclaire, le premier plan reste sombre)
const BRUME_D := 0.022
const DIST_APPARITION := 46.0

## Tenues des bandits (corps Humain) : [tenue, étoffes, coiffure, teinte des cheveux, barbe] ; indice 4 = Hrafn, le chef (casque nasal ;
## mante de fourrure brune, plus sombre que celle des bandits : la fourrure « noir » de la version d’origine n’existe pas, Humain.creer échouait).
const C := Color.WHITE
const TENUES := [
	[{"tunique": C, "pantalon": C, "mante": C, "capuche": C, "sacoche": C, "bottes": C, "ceinture": C, "brassards": C, "gants": C},
		{"tunique": "cuir_a", "pantalon": "brun", "mante": "brun", "capuche": "brun", "sacoche": "cuir_b", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "cuir_b", "gants": "cuir_b"}, "Hair_Buzzed", Color(0.3, 0.2, 0.12), true],
	[{"tunique": C, "pantalon": C, "mante": C, "epaulieres": C, "pteruges": C, "bottes": C, "ceinture": C, "brassards": C},
		{"tunique": "cuir_b", "pantalon": "gris", "mante": "gris", "epaulieres": "cuir_a", "pteruges": "cuir_a", "bottes": "cuir_b", "ceinture": "cuir_a", "brassards": "cuir_a"}, "Hair_SimpleParted", Color(0.5, 0.35, 0.2), true],
	[{"tunique": C, "pantalon": C, "cape_courte": C, "capuche": C, "sacoche": C, "bottes": C, "ceinture": C, "gants": C},
		{"tunique": "lin", "pantalon": "noir", "cape_courte": "brun", "capuche": "gris", "sacoche": "cuir_a", "bottes": "cuir_a", "ceinture": "cuir_b", "gants": "cuir_b"}, "Hair_Long", Color(0.2, 0.16, 0.12), false],
	[{"tunique": C, "pantalon": C, "mante": C, "carquois": C, "pteruges": C, "bottes": C, "ceinture": C, "brassards": C},
		{"tunique": "cuir_a", "pantalon": "brun", "mante": "blanc", "carquois": "cuir_b", "pteruges": "cuir_b", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "cuir_b"}, "Hair_Buzzed", Color(0.55, 0.5, 0.45), true],
	[{"tunique": C, "pantalon": C, "mante": C, "epaulieres": C, "pteruges": C, "bottes": C, "ceinture": C, "brassards": C, "gants": C},
		{"tunique": "cuir_b", "pantalon": "noir", "mante": "brun", "epaulieres": "cuir_a", "pteruges": "cuir_b", "bottes": "cuir_b", "ceinture": "cuir_a", "brassards": "cuir_a", "gants": "cuir_b"}, "Hair_Long", Color(0.12, 0.1, 0.09), true],
]

## --persos-kit : tenue du chef en personnage de base unifié (les bandits ordinaires viennent alors de PersoDefs.bandit(k), k = indice « tenue » 0-3).
const HRAFN := {"corps": "homme", "tete": 2, "cheveux": 2, "barbe": 2, "couleur_cheveux": Color("#1c1612"), "peau": Color("#e6bfa5"), "tunique": "cuir", "sur": "noir",
	"pantalon": "noir", "cuir": "cuir_a", "fourrure": "blanc", "accessoires": ["epaulieres", "pteruges", "cape_courte", "gilet"], "casque": "casque_nasal"}

const RESSOURCES := {
	"minerai_fer": ["Filon de fer", "Extraire du minerai de fer"],
	"minerai_argent": ["Filon d’argent", "Extraire du minerai d’argent"],
	"cristal_givre": ["Cristaux de givre", "Détacher un cristal"],
	"champignon_lumineux": ["Champignons lumineux", "Cueillir des champignons"],
}

var acces: Node3D                       # GrotteAcces (monde, joueur, dialogue, quetes, hud, morts_charges)
var g: Grotte
var prefixe := "grotte"
var interactifs := {}                   # id -> nœud Interactif
var ennemis := {}                       # id -> CharacterBody3D (apparus)
var _file: Array = []                   # accroches d'ennemis pas encore apparues
var _lieux: Array = []
var _t := 0.0
var _cri_dit := false
var _defaite_dite := false
var _murs := {}

func installer(acces_: Node3D, g_: Grotte) -> void:
	acces = acces_
	g = g_
	prefixe = String(g.def.get("id", "grotte"))
	for a: Dictionary in g.accroches:
		match String(a["type"]):
			"coffre":
				_coffre(a)
			"ressource":
				_ressource(a)
			"interaction":
				_interaction(a)
			"meca":
				_meca(a)
			"lieu":
				_lieux.append(a)
			"ennemi":
				_file.append(a)
	_etat()

func _vus() -> Dictionary:
	return acces.quetes.vus

## État acquis (partie chargée, mort du joueur) : coffres vidés, ressources prises, objets récits pris.
func _etat() -> void:
	var vus := _vus()
	for id: String in interactifs:
		var it: Node3D = interactifs[id]
		var cle: String = it.get_meta("cle_etat", "")
		if cle != "" and vus.has(cle):
			it.actif = false

func _interactif(pos: Vector3, nom: String, verbe: String, action: Callable, condition := Callable(), unique := true, rayon := 2.3) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = acces.joueur
	it.dialogue = acces.dialogue
	it.nom = nom
	it.verbe = verbe
	it.condition = condition
	it.action = action
	it.unique = unique
	it.rayon = rayon
	it.position = pos
	g.add_child(it)
	return it

func _inconnu(id: String) -> bool:
	return id != "pieces" and not Inventaire.OBJETS.has(id)

# ------------------------------------------------------------------ coffres
func _coffre(a: Dictionary) -> void:
	var d: Dictionary = a["d"]
	var id: String = a["id"]
	var butin: Dictionary = {}
	for k: String in (d.get("butin", {}) as Dictionary):
		if not _inconnu(k):
			butin[k] = d["butin"][k]
	var lieu: Vector3 = a["lieu"]
	var cle := "%s:%s" % [prefixe, id]
	var it := _interactif(a["pos"], String(d.get("nom", "Coffre")), "Ouvrir le coffre", func() -> Array: return _ouvrir_coffre(id, butin, lieu),
		func() -> bool: return not _vus().has(cle), true)
	it.set_meta("cle_etat", cle)
	it.set_meta("genre", "coffre")
	interactifs[id] = it

func _ouvrir_coffre(id: String, contenu: Dictionary, lieu: Vector3) -> Array:
	acces.quetes.signaler("%s:%s" % [prefixe, id])
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = acces.joueur
	b.hud = acces.hud
	b.contenu = contenu.duplicate()
	b.set_meta("coffre", id)
	g.add_child(b)
	b.position = lieu + Vector3(0, 0.75, 0)
	Sons.jouer_a(g, ["doorOpen_1", "handleCoins"], g.to_global(lieu), -2.0)
	return []

# ------------------------------------------------------------------ ressources
func _ressource(a: Dictionary) -> void:
	var d: Dictionary = a["d"]
	var id: String = a["id"]
	var genre: String = d["genre"]
	if _inconnu(genre):
		push_warning("grotte : objet inconnu %s" % genre)
		return
	var n: int = int(d.get("n", 1))
	var cle := "%s:res_%s" % [prefixe, id]
	var txt: Array = RESSOURCES.get(genre, [genre, "Prendre"])
	var it := _interactif(a["pos"], txt[0], txt[1], func() -> Array: return _prendre_ressource(id, genre, n, cle),
		func() -> bool: return not _vus().has(cle), true, 2.0)
	it.set_meta("cle_etat", cle)
	interactifs["res_" + id] = it

func _prendre_ressource(_id: String, genre: String, n: int, cle: String) -> Array:
	acces.quetes.signaler(cle)
	acces.joueur.inventaire.ajouter(genre, n)
	acces.hud.avis("+ %d %s" % [n, acces.joueur.inventaire.nom(genre)])
	Sons.jouer(g, ["handleCoins", "handleCoins2"], -8.0)
	return []

# ------------------------------------------------------------------ interactions de récit
func _interaction(a: Dictionary) -> void:
	var d: Dictionary = a["d"]
	var id: String = a["id"]
	var cle := "%s:%s" % [prefixe, id]
	var it := _interactif(a["pos"], String(d["nom"]), String(d["verbe"]), func() -> Array: return _lire(d, cle),
		func() -> bool: return not _vus().has(cle), true)
	it.set_meta("cle_etat", cle)
	interactifs[id] = it

func _lire(d: Dictionary, cle: String) -> Array:
	acces.quetes.signaler(cle)
	var obj: String = d.get("objet", "")
	if obj != "" and not _inconnu(obj):
		acces.joueur.inventaire.ajouter(obj, 1)
		acces.hud.avis("+ 1 %s" % acces.joueur.inventaire.nom(obj))
	var evt: String = d.get("evt", "")
	if evt != "":
		acces.quetes.signaler(evt)
	var lignes: Array = []
	if d.has("texte_cle"):
		lignes = acces.quetes.texte(String(d["texte_cle"]))
	if lignes.is_empty():
		lignes = d.get("texte", [])
	return lignes

# ------------------------------------------------------------------ mécanismes
func _meca(a: Dictionary) -> void:
	var d: Dictionary = a["d"]
	match String(d["genre"]):
		"mur_fragile":
			var taille: Vector3 = d["taille"]
			var centre: Vector3 = (a["pos"] as Vector3) + Vector3(0, taille.y * 0.5, 0)
			var ident := "%s_%s" % [prefixe, a["id"]]
			var evt: String = d.get("evt", "")
			var ctx := {"materiau": g.decor.mat("c_roche_mur")}      # le mur se fond dans la roche voisine (assombri : pas d'occlusion peinte)
			var m: Node3D = Mecanisme.mur_fragile(g, centre, taille, float(a["lacet"]), ident, func() -> void:
				if evt != "":
					acces.quetes.signaler(evt), ctx)
			_murs[a["id"]] = m

# ------------------------------------------------------------------ ennemis
func _apparence(e: Dictionary) -> Dictionary:
	if Personnage.kit_actif():
		var kk: int = maxi(int(e.get("tenue", 0)), 0)
		if kk >= 4:
			return {"perso": PersoDef.depuis(HRAFN)}
		return {"perso": PersoDefs.bandit(kk)}
	return apparence_humain(int(e.get("tenue", 0)), String(e.get("casque", "")))

## Apparence Humain d'un bandit (tenue 0-4) ; `casque` imposé par les données, sinon casque nasal pour Hrafn (4).
static func apparence_humain(tenue: int, casque := "") -> Dictionary:
	var k: int = clampi(tenue, 0, TENUES.size() - 1)
	var t: Array = TENUES[k]
	var app := {"corps": "homme", "draugr": false, "tenue": (t[0] as Dictionary).duplicate(), "etoffes": (t[1] as Dictionary).duplicate(), "cheveux": t[2],
		"teinte_cheveux": t[3], "barbe": t[4], "peau": Color(0.93, 0.78, 0.7)}
	if casque != "":
		app["casque"] = casque
	elif k == 4:
		app["casque"] = "casque_nasal"
	return app

func _creer_ennemi(a: Dictionary) -> void:
	var id: String = a["id"]
	var e: Dictionary = a["d"]
	var monde: Node3D = acces.monde
	var pos: Vector3 = g.to_global(a["pos"])
	var lacet: float = float(a["lacet"]) + g.global_rotation.y
	var boss: String = e.get("boss", "")
	var opts := {"ident": id, "nom_affiche": e.get("nom", "Bandit"), "contourne": true, "apparence": _apparence(e)}
	if boss == "":
		opts["vie_imposee"] = 55.0
	else:
		opts["boss"] = boss
	if e.get("archer", false):
		opts["archer"] = true
		if e.has("sur"):
			opts["poste"] = true
	var pat: Array = a["patrouille"]
	if not pat.is_empty():
		var pts: Array = []
		for p: Vector3 in pat:
			pts.append(g.to_global(p) + Vector3(0, 0.05, 0))
		opts["patrouille"] = pts
	var dr: CharacterBody3D = monde.creer_draugr(String(e.get("type", "sbire")) if boss == "" else "sbire", pos, lacet, false, opts)
	if monde._paisible():
		dr.process_mode = Node.PROCESS_MODE_DISABLED
	ennemis[id] = dr
	if boss == "hrafn":
		dr.mort.connect(func(_i: String) -> void: _dire_defaite())

func _dire_defaite() -> void:
	if _defaite_dite:
		return
	_defaite_dite = true
	var l: Array = acces.quetes.texte("hrafn_defaite")
	if not l.is_empty():
		acces.dialogue.dire_au_passage("Hrafn", String(l[0]))

## Appelé toutes les 0,25 s quand le joueur est dans la grotte.
func tick(dt: float) -> void:
	_ambiance()
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	var pj: Vector3 = acces.joueur.global_position
	# lumières : les plus proches seulement
	var proches: Array = []
	for l: OmniLight3D in g.decor.toutes:
		var d := l.global_position.distance_to(pj)
		l.visible = false
		if d < 26.0:
			proches.append([d - float(l.get_meta("bonus", 0.0)), l])     # bonus : puits de jour, gardés dans le budget malgré la hauteur
	proches.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i in mini(MAX_LUM, proches.size()):
		(proches[i][1] as OmniLight3D).visible = true
	# lieux
	for a: Dictionary in _lieux:
		var d: Dictionary = a["d"]
		var evt: String = d["evt"]
		if _vus().has(evt):
			continue
		var p: Vector3 = g.to_global(a["pos"])
		if Vector2(p.x - pj.x, p.z - pj.z).length() < float(d.get("rayon", 5.0)) and absf(p.y - pj.y) < 4.0:
			acces.quetes.signaler(evt)
	# apparition des ennemis proches (2 au plus par passage)
	var n := 0
	var i := 0
	while i < _file.size() and n < 2:
		var a: Dictionary = _file[i]
		var p: Vector3 = g.to_global(a["pos"])
		if Vector2(p.x - pj.x, p.z - pj.z).length() < DIST_APPARITION and absf(p.y - pj.y) < 12.0:
			_file.remove_at(i)
			if not acces.morts_charges.has(a["id"]) and not ennemis.has(a["id"]):
				_creer_ennemi(a)
			n += 1
		else:
			i += 1
	# cri de Hrafn
	if not _cri_dit and ennemis.has("hrafn") and is_instance_valid(ennemis["hrafn"]):
		if ennemis["hrafn"].get("_cri_fait") == true:
			_cri_dit = true
			var l: Array = acces.quetes.texte("hrafn_cri")
			if not l.is_empty():
				acces.dialogue.dire_au_passage("Hrafn", String(l[0]))

## Réglages d'environnement de la refonte : réappliqués dès que l'entrée dans la grotte (monde._sous_terre puis Grotte.ambiance)
## les a remis aux valeurs d'origine.
func _ambiance() -> void:
	var monde: Node = acces.monde
	if monde == null or not ("_env" in monde):
		return
	var env: Environment = monde.get("_env")
	if env == null or env.ambient_light_color == AMBIANTE:
		return
	env.ambient_light_color = AMBIANTE
	env.ambient_light_energy = AMBIANTE_E
	env.fog_light_color = BRUME_C
	env.fog_density = BRUME_D

## Mort du joueur sous terre : ennemis retirés (ceux tués dans le fichier le restent), coffres dont la bourse n'a pas été ramassée refermés.
func reinitialiser(sauves: Array) -> void:
	acces.morts_charges = sauves.duplicate()
	var monde: Node3D = acces.monde
	for id: String in ennemis:
		if is_instance_valid(ennemis[id]):
			ennemis[id].queue_free()
		monde.draugrs.erase(id)
	ennemis.clear()
	_file.clear()
	for a: Dictionary in g.accroches:
		if String(a["type"]) == "ennemi":
			_file.append(a)
	_cri_dit = false
	_defaite_dite = false
	for b in g.get_children():
		if b.has_meta("coffre"):
			var id: String = b.get_meta("coffre")
			b.queue_free()
			acces.quetes.vus.erase("%s:%s" % [prefixe, id])
			if interactifs.has(id):
				(interactifs[id] as Node3D).actif = true
	_etat()
	Mecanisme.restaurer_tout(g)
