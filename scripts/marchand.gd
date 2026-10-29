class_name Marchand
extends CanvasLayer
## Lot L8 « marchands » (docs/BUTIN.md §9, INSPIRATION_IGNITE §2.18) : Brodd le forgeron et Grima, la doyenne du puits.
##   - données : data/marchands.json (bourse, prix d'achat / de rachat, ce que chacun rachète, stock tiré à graine fixe) ;
##   - ÉTAT (statique, comme ButinTables) : `heures` = heures de jeu écoulées depuis le début de la partie (suivies sur cycle.heure),
##     `etats[id]` = {or, stock {id: n}, periode} ; le stock et la bourse sont tirés à nouveau à chaque période de
##     `renouvellement_jours` jours de jeu (graine « marchand:<id>:<période> », ButinTables.graine) ; sauvegardé par monde.gd (« marchands ») ;
##   - prix : achat = valeur x achat (arrondi au-dessus), rachat = valeur x vente (arrondi au-dessous, 1 au moins) ;
##   - jamais vendables : valeur 0 (objets de quête), `invendables`, objet demandé par une étape « objet:<id>>=n » d'une quête en cours ;
##   - BOUTIQUE (une instance, créée par monde._interface, groupe « marchand ») : ouverte depuis le dialogue (option « Commercer ») ;
##     onglets Acheter / Vendre, une carte par objet (icône, nom en couleur de rareté, effet, nombre, prix + pièce), or du joueur et
##     bourse du marchand, délai avant le réassort ; jeu en PAUSE ;
##     clavier : E / Entrée / Espace = un ; R = toute la pile ; Tab, flèches gauche/droite, Q/D = onglet ; flèches haut/bas, Z/S,
##     molette = choisir ; Échap, clic droit = fermer ; manette : A = un, Y = la pile, LB/RB ou croix gauche/droite = onglet,
##     croix haut/bas = choisir, B = fermer ; souris : survol, clic sur une carte ou un onglet.
## Style : celui de la fenêtre de butin (FenetreButin) : cadre ornementé L7, titre en Jacquard 24, texte et chiffres en Kenney.

const GROUPE := "marchand"
const FICHIER := "res://data/marchands.json"
const CARTE := 24.0
const FER := Color("#3a4458")
const PLAQUE := Color("#121826")
const ROUGE := Color("#d0604c")
const VERT := Color("#8fd07a")
const ONGLETS := ["Acheter", "Vendre"]
const DUREE_AVIS := 2.2

## Heures de jeu écoulées depuis le début de la partie (sauvegardées).
static var heures := 0.0
## État de chaque marchand : {or: int, stock: {id: n}, periode: int}.
static var etats := {}
static var _donnees := {}
static var _lu := false

var joueur: CharacterBody3D
var hud: Control
## Monde (pour cycle et quetes, créés après l'interface) ; facultatif (tests).
var monde: Node
var ouvert := false
var id_marchand := ""
var titre := ""
## 0 = Acheter, 1 = Vendre.
var onglet := 0
## Cartes affichées : [{id, n, prix, refus}] (refus : "" ou raison : objet de quête, n'en veut pas).
var lignes: Array[Dictionary] = []
var choix := 0

var _vue: Control
var _police: FontFile
var _gothique: FontFile
var _cadre: StyleBox
var _haut := 0
var _zones := {}
var _souris := Input.MOUSE_MODE_CAPTURED
var _icones := {}
var _avis := ""
var _avis_couleur := MenuStyle.PARCHEMIN
var _avis_t := 0.0
var _heure_vue := -1.0

# ------------------------------------------------------------------ données et état (statique)

static func donnees() -> Dictionary:
	if not _lu:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_donnees = d if d is Dictionary else {}
		_lu = true
	return _donnees

static func fiche(id: String) -> Dictionary:
	return donnees().get("marchands", {}).get(id, {})

static func ids() -> Array:
	return donnees().get("marchands", {}).keys()

static func est_marchand(id: String) -> bool:
	return not fiche(id).is_empty()

## Id de marchand d'un PNJ (villageois : donnees.id), "" s'il ne commerce pas.
static func pour_pnj(pnj: Node) -> String:
	if pnj == null or not is_instance_valid(pnj):
		return ""
	var d: Variant = pnj.get("donnees")
	var id := String((d as Dictionary).get("id", "")) if d is Dictionary else ""
	return id if est_marchand(id) else ""

static func periode_de(id: String, h := -1.0) -> int:
	var jours := maxf(0.01, float(fiche(id).get("renouvellement_jours", 2)))
	return floori((heures if h < 0.0 else h) / (24.0 * jours))

## Heures de jeu avant le prochain réassort.
static func heures_avant_reassort(id: String) -> float:
	var jours := maxf(0.01, float(fiche(id).get("renouvellement_jours", 2)))
	return (periode_de(id) + 1) * 24.0 * jours - heures

## État courant (stock tiré, ou retiré si la période a changé).
static func etat(id: String) -> Dictionary:
	var p := periode_de(id)
	var e: Dictionary = etats.get(id, {})
	if e.is_empty() or int(e.get("periode", -1)) != p:
		e = {"periode": p, "or": int(fiche(id).get("or", 0)), "stock": stock_tire(id, p)}
		etats[id] = e
	return e

## Stock d'une période (même période = même stock : graine fixe).
static func stock_tire(id: String, periode: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ButinTables.graine("marchand:%s:%d" % [id, periode])
	var s := {}
	for ent: Dictionary in fiche(id).get("stock", []):
		var oid := String(ent.get("id", ""))
		var chance := int(ent.get("chance", 100))
		var tirage := rng.randi_range(1, 100)
		var v: Variant = ent.get("n", 1)
		var n := rng.randi_range(int(v[0]), int(v[1])) if v is Array else int(v)
		if tirage <= chance and n > 0 and Inventaire.connu(oid):
			s[oid] = int(s.get(oid, 0)) + n
	return s

static func or_de(id: String) -> int:
	return int(etat(id).get("or", 0))

static func stock(id: String) -> Dictionary:
	return etat(id).get("stock", {})

static func prix_achat(id: String, oid: String) -> int:
	return maxi(1, ceili(float(Inventaire.objet(oid).get("valeur", 0)) * float(fiche(id).get("achat", 1.1)) - 0.0001))

static func prix_vente(id: String, oid: String) -> int:
	return maxi(1, floori(float(Inventaire.objet(oid).get("valeur", 0)) * float(fiche(id).get("vente", 0.4)) + 0.0001))

## Objet de quête (jamais vendable) : valeur 0, liste `invendables`, objet demandé par une quête en cours.
static func de_quete(oid: String, quetes: Node = null) -> bool:
	if int(Inventaire.objet(oid).get("valeur", 0)) <= 0 or oid in donnees().get("invendables", []):
		return true
	if quetes != null and is_instance_valid(quetes) and quetes.get("donnees") is Dictionary:
		for q: Dictionary in quetes.donnees.get("quetes", []):
			if not quetes.en_cours(String(q.get("id", ""))):
				continue
			for et: Dictionary in q.get("etapes", []):
				for dec: String in String(et.get("declencheur", "")).split("|"):
					if dec.begins_with("objet:") and dec.substr(6).split(">=")[0] == oid:
						return true
	return false

static func rachete(id: String, oid: String) -> bool:
	var a: Array = fiche(id).get("achete", [])
	return a.is_empty() or oid in a or Inventaire.categorie_de(oid) in a

## Raison pour laquelle le marchand ne rachète pas cet objet ("" = possible).
static func refus_vente(id: String, oid: String, quetes: Node = null) -> String:
	if de_quete(oid, quetes):
		return "Objet de quête : invendable."
	if not rachete(id, oid):
		return "Ça ne l'intéresse pas."
	return ""

## Achète `n` objets (ou moins si le stock ou l'or manque : au moins un, sinon refus). Renvoie la raison du refus ("" = fait).
static func acheter(id: String, inv: Inventaire, oid: String, n := 1) -> String:
	var e := etat(id)
	var s: Dictionary = e["stock"]
	var dispo := int(s.get(oid, 0))
	if dispo <= 0:
		return "Plus en stock."
	var prix := prix_achat(id, oid)
	var k := mini(mini(n, dispo), inv.pieces / prix)
	if k <= 0:
		return "Pas assez de pièces (%d)." % prix
	inv.pieces -= k * prix
	inv.ajouter(oid, k)
	s[oid] = dispo - k
	if int(s[oid]) <= 0:
		s.erase(oid)
	e["or"] = int(e["or"]) + k * prix
	return ""

## Vend `n` objets du sac (ou moins si la bourse du marchand manque). Ce qui est vendu rejoint son stock jusqu'au réassort.
static func vendre(id: String, inv: Inventaire, oid: String, n := 1, quetes: Node = null) -> String:
	var r := refus_vente(id, oid, quetes)
	if r != "":
		return r
	var a := inv.nombre(oid)
	if a <= 0:
		return "Plus dans le sac."
	var e := etat(id)
	var prix := prix_vente(id, oid)
	var k := mini(mini(n, a), int(e["or"]) / prix)
	if k <= 0:
		return "Sa bourse est vide (%d pièces)." % int(e["or"])
	inv.retirer(oid, k)
	inv.ajouter("pieces", k * prix)
	e["or"] = int(e["or"]) - k * prix
	var s: Dictionary = e["stock"]
	s[oid] = int(s.get(oid, 0)) + k
	return ""

## Fait passer le temps de jeu (heures).
static func avancer(dh: float) -> void:
	if dh > 0.0:
		heures += dh

static func exporter() -> Dictionary:
	var e := {}
	for id: String in etats:
		var d: Dictionary = etats[id]
		e[id] = {"periode": int(d.get("periode", 0)), "or": int(d.get("or", 0)), "stock": (d.get("stock", {}) as Dictionary).duplicate()}
	return {"heures": heures, "etats": e}

static func importer(d: Dictionary) -> void:
	reinitialiser()
	heures = maxf(0.0, float(d.get("heures", 0.0)))
	var e: Dictionary = d.get("etats", {})
	for id: String in e:
		if not est_marchand(id) or not e[id] is Dictionary:
			continue
		var s := {}
		var st: Variant = e[id].get("stock", {})
		if st is Dictionary:
			for oid: String in st:
				if Inventaire.connu(oid) and int(st[oid]) > 0:
					s[oid] = int(st[oid])
		etats[id] = {"periode": int(e[id].get("periode", 0)), "or": int(e[id].get("or", 0)), "stock": s}

static func reinitialiser() -> void:
	heures = 0.0
	etats = {}

## Erreurs des données (test) : objets inconnus, marchand sans villageois, objet vendable que personne ne rachète.
static func verifier() -> Array[String]:
	var err: Array[String] = []
	for id: String in ids():
		for ent: Dictionary in fiche(id).get("stock", []):
			if not Inventaire.connu(String(ent.get("id", ""))):
				err.append("%s : objet inconnu %s" % [id, ent.get("id", "")])
			elif int(Inventaire.objet(String(ent["id"])).get("valeur", 0)) <= 0:
				err.append("%s : objet sans valeur en rayon %s" % [id, ent["id"]])
		for a: String in fiche(id).get("achete", []):
			if not Inventaire.connu(a) and not a in ["arme", "consommable", "divers"]:
				err.append("%s : « achete » inconnu %s" % [id, a])
	return err

# ------------------------------------------------------------------ boutique

static func trouver(n: Node) -> Marchand:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as Marchand

func _ready() -> void:
	layer = 44   # comme la fenêtre de butin : au-dessus du HUD, sous l'inventaire (45) et le menu pause (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUPE)
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_cadre = MenuStyle.cadre_orne()
	_vue = Control.new()
	_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vue.visible = false
	_vue.draw.connect(_dessiner)
	add_child(_vue)

func _quetes() -> Node:
	return monde.get("quetes") if monde != null and is_instance_valid(monde) else null

## Ouvre la boutique du marchand `id` (false si inconnu ou déjà ouverte).
func ouvrir(id: String, nom := "") -> bool:
	if ouvert or joueur == null or not est_marchand(id):
		return false
	id_marchand = id
	titre = String(fiche(id).get("titre", nom if nom != "" else id))
	onglet = 0
	choix = 0
	_haut = 0
	_avis_t = 0.0
	ouvert = true
	_remplir()
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_vue.visible = true
	_vue.queue_redraw()
	Sons.jouer(self, ["handleCoins", "handleCoins2"], -12.0)
	return true

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_vue.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED

func changer_onglet(o: int) -> void:
	if not ouvert:
		return
	var n := posmod(o, ONGLETS.size())
	if n != onglet:
		onglet = n
		choix = 0
		_haut = 0
		_remplir()
		Sons.jouer(self, ["cloth1"], -16.0)

## Recalcule les cartes de l'onglet (après une transaction : la carte choisie reste, ou la suivante).
func _remplir() -> void:
	lignes.clear()
	var inv: Inventaire = joueur.inventaire
	if onglet == 0:
		# ordre de l'étal = ordre de data/marchands.json (stable après un chargement), puis ce que le joueur a vendu
		var ordre: Array = (fiche(id_marchand).get("stock", []) as Array).map(func(en: Dictionary) -> String: return String(en.get("id", "")))
		var st := stock(id_marchand)
		var cles: Array = st.keys()
		cles.sort_custom(func(a: String, b: String) -> bool:
			var ia := ordre.find(a)
			var ib := ordre.find(b)
			ia = ia if ia >= 0 else 1000
			ib = ib if ib >= 0 else 1000
			return ia < ib if ia != ib else a < b)
		for oid: String in cles:
			lignes.append({"id": oid, "n": int(st[oid]), "prix": prix_achat(id_marchand, oid), "refus": ""})
	else:
		var bas: Array[Dictionary] = []
		for oid: String in inv.objets:
			if int(inv.objets[oid]) <= 0:
				continue
			var r := refus_vente(id_marchand, oid, _quetes())
			var l := {"id": oid, "n": int(inv.objets[oid]), "prix": prix_vente(id_marchand, oid), "refus": r}
			if r == "":
				lignes.append(l)
			else:
				bas.append(l)    # invendables en bas, grisés
		lignes.append_array(bas)
	choix = clampi(choix, 0, maxi(0, lignes.size() - 1))
	_suivre()
	_vue.queue_redraw()

## Transaction sur la carte i (n = 1, ou toute la pile si `tout`). Renvoie la raison du refus ("" = fait).
func traiter(i := -1, tout := false) -> String:
	if i < 0:
		i = choix
	if not ouvert or i < 0 or i >= lignes.size():
		return "Rien à choisir."
	var l: Dictionary = lignes[i]
	var oid := String(l["id"])
	var n := int(l["n"]) if tout else 1
	var inv: Inventaire = joueur.inventaire
	var avant := inv.pieces
	var r := acheter(id_marchand, inv, oid, n) if onglet == 0 else vendre(id_marchand, inv, oid, n, _quetes())
	if r != "":
		_annoncer(r, ROUGE)
		Sons.jouer(self, ["cloth1"], -14.0)
	else:
		var k := absi(inv.pieces - avant) / maxi(1, int(l["prix"]))
		_annoncer(("%s x%d : -%d pièces" if onglet == 0 else "%s x%d : +%d pièces") % [inv.nom(oid), k, absi(inv.pieces - avant)], VERT)
		Sons.jouer(self, ["handleCoins", "handleCoins2"], -6.0)
		choix = i
		_remplir()
	return r

func _annoncer(t: String, c: Color) -> void:
	_avis = t
	_avis_couleur = c
	_avis_t = DUREE_AVIS
	_vue.queue_redraw()

func _choisir(i: int) -> void:
	if lignes.is_empty():
		return
	var n := clampi(i, 0, lignes.size() - 1)
	if n != choix:
		choix = n
		_suivre()
		_vue.queue_redraw()

func _max_cartes() -> int:
	return clampi(int((_vue.size.y - 116.0) / CARTE), 3, 6)

func _suivre() -> void:
	var m := _max_cartes()
	if choix < _haut:
		_haut = choix
	elif choix >= _haut + m:
		_haut = choix - m + 1
	_haut = clampi(_haut, 0, maxi(0, lignes.size() - m))

# ------------------------------------------------------------------ entrées

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	var vp := get_viewport()
	if e is InputEventKey:
		var k := e as InputEventKey
		vp.set_input_as_handled()      # aucune touche du jeu sous la boutique (E, Tab, I, F5, chiffres…)
		if not k.pressed:
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			return
		match k.physical_keycode:
			KEY_ESCAPE:
				fermer()
			KEY_TAB:
				changer_onglet(onglet + 1)
			KEY_LEFT, KEY_A:
				changer_onglet(onglet - 1)
			KEY_RIGHT, KEY_D:
				changer_onglet(onglet + 1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				traiter()
			KEY_R:
				traiter(-1, true)
			KEY_UP, KEY_W:
				_choisir(choix - 1)
			KEY_DOWN, KEY_S:
				_choisir(choix + 1)
	elif e is InputEventJoypadButton:
		vp.set_input_as_handled()
		if not e.pressed:
			return
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				traiter()
			JOY_BUTTON_Y:
				traiter(-1, true)
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
				changer_onglet(onglet - 1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
				changer_onglet(onglet + 1)
			JOY_BUTTON_DPAD_UP:
				_choisir(choix - 1)
			JOY_BUTTON_DPAD_DOWN:
				_choisir(choix + 1)
	elif e is InputEventMouseMotion:
		vp.set_input_as_handled()
		var z := _zone((e as InputEventMouseMotion).position)
		if z.begins_with("carte:"):
			_choisir(int(z.substr(6)))
	elif e is InputEventMouseButton:
		vp.set_input_as_handled()
		var b := e as InputEventMouseButton
		if not b.pressed:
			return
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_choisir(choix - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_choisir(choix + 1)
			MOUSE_BUTTON_RIGHT:
				fermer()
			MOUSE_BUTTON_LEFT:
				var z := _zone(b.position)
				if z.begins_with("carte:"):
					traiter(int(z.substr(6)))
				elif z.begins_with("onglet:"):
					changer_onglet(int(z.substr(7)))
				elif z == "un":
					traiter()
				elif z == "tout":
					traiter(-1, true)
				elif z == "fermer":
					fermer()

func _zone(p: Vector2) -> String:
	var q := p / maxf(1.0, _vue.scale.x)
	for nom: String in _zones:
		if (_zones[nom] as Rect2).has_point(q):
			return nom
	return ""

# ------------------------------------------------------------------ temps et dessin

func _process(dt: float) -> void:
	# temps de jeu : suit l'horloge du cycle (arrêtée pendant la pause) ; un saut de plus de 6 h (chargement, capture) ne compte pas
	var cy: Variant = monde.get("cycle") if monde != null and is_instance_valid(monde) else null
	if cy is Node and is_instance_valid(cy):
		var h := float((cy as Node).get("heure"))
		if _heure_vue >= 0.0:
			var dh := fposmod(h - _heure_vue, 24.0)
			if dh < 6.0:
				avancer(dh)
		_heure_vue = h
	if not ouvert:
		return
	if EchelleUi.appliquer(_vue):
		_suivre()
		_vue.queue_redraw()
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_vue.queue_redraw()

## Après un chargement : l'horloge saute, on repart de l'heure lue.
func recaler_horloge() -> void:
	_heure_vue = -1.0

static func duree_texte(h: float) -> String:
	var hh := maxi(1, ceili(h - 0.0001))
	if hh < 24:
		return "%d h" % hh
	return "%d j %d h" % [hh / 24, hh % 24] if hh % 24 != 0 else "%d j" % (hh / 24)

func _texte(pos: Vector2, texte: String, couleur := MenuStyle.PARCHEMIN, largeur := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_vue.draw_string(_police, pos + Vector2(1, 1), texte, align, largeur, Palette.TAILLE_POLICE, MenuStyle.FOND)
	_vue.draw_string(_police, pos, texte, align, largeur, Palette.TAILLE_POLICE, couleur)

func _larg(texte: String) -> float:
	return ceilf(_police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x)

func _couper(t: String, larg: float) -> String:
	while t.length() > 4 and _larg(t) > larg:
		t = t.substr(0, t.length() - 2) + "…"
	return t

## Pièce d'or 7x7 en pixels (coin haut-gauche p).
func _piece(p: Vector2, alpha := 1.0) -> void:
	var sombre := Color("#7a4a16", alpha)
	var o := Color(MenuStyle.OR, alpha)
	var clair := Color("#ffe6a0", alpha)
	for r: Array in [[0, 2, 3], [1, 1, 5], [2, 0, 7], [3, 0, 7], [4, 0, 7], [5, 1, 5], [6, 2, 3]]:
		_vue.draw_rect(Rect2(p.x + r[1], p.y + r[0], r[2], 1), sombre)
	for r: Array in [[1, 2, 3], [2, 1, 5], [3, 1, 5], [4, 1, 5], [5, 2, 3]]:
		_vue.draw_rect(Rect2(p.x + r[1], p.y + r[0], r[2], 1), o)
	_vue.draw_rect(Rect2(p.x + 2, p.y + 2, 1, 2), clair)
	_vue.draw_rect(Rect2(p.x + 3, p.y + 2, 1, 3), Color(sombre, 0.6 * alpha))

## Prix aligné à droite (pièce comprise), renvoie le bord gauche.
func _prix(droite: float, y: float, valeur: int, couleur: Color, alpha := 1.0) -> float:
	var t := str(valeur)
	var x := droite - _larg(t)
	_texte(Vector2(x, y), t, Color(couleur, alpha))
	_piece(Vector2(x - 10.0, y - 8.0), alpha)
	return x - 10.0

func _icone(id: String, rarete: String) -> Texture2D:
	var motif := String(Inventaire.objet(id).get("icone", id))
	if Inventaire.categorie_de(id) == "arme" and not IconesCombat.connu(motif):
		motif = "epee"
	if IconesCombat.connu(motif):
		return IconesCombat.icone(motif)
	var cle := "l:" + rarete
	if not _icones.has(cle):
		_icones[cle] = MenuStyle._icone_losange(9, Color(ButinTables.COULEURS_RARETE.get(rarete, "#c8d0dc")), false)
	return _icones[cle]

func _description(id: String) -> String:
	if Consommables.est(id):
		return Consommables.description(id)
	var f := Inventaire.objet(id)
	var cat := "Arme" if Inventaire.categorie_de(id) == "arme" else "Objet"
	return "%s, %s kg" % [cat, FenetreButin.poids_texte(float(f.get("poids", 0.0)))]

func _dessiner() -> void:
	if not ouvert:
		return
	var s := _vue.size
	_zones.clear()
	_vue.draw_rect(Rect2(Vector2.ZERO, s), Color(MenuStyle.FOND, 0.45))
	var m := _max_cartes()
	var vis := mini(lignes.size(), m)
	var w := clampf(s.x - 150.0, 300.0, 380.0)
	var h := 102.0 + maxi(vis, 2) * CARTE
	var o := ((s - Vector2(w, h)) * 0.5).floor()
	_vue.draw_rect(Rect2(o + Vector2(6, 6), Vector2(w, h) - Vector2(12, 12)), Color(MenuStyle.FOND, 0.92))
	_vue.draw_style_box(_cadre, Rect2(o, Vector2(w, h)))
	var gx := o.x + 16.0
	var dx := o.x + w - 16.0
	var inv: Inventaire = joueur.inventaire
	var e := etat(id_marchand)
	# titre et or du joueur
	var t := titre
	while t.length() > 4 and _gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x > w - 110.0:
		t = t.substr(0, t.length() - 2) + "…"
	MenuStyle.texte_detoure(_vue, _gothique, Vector2(gx, o.y + 29), t, MenuStyle.TITRE_GRAND, MenuStyle.OR)
	_prix(dx, o.y + 27.0, inv.pieces, MenuStyle.OR)
	_vue.draw_rect(Rect2(gx, o.y + 35, w - 32.0, 1), FER)
	# onglets ; bourse du marchand à droite
	var x := gx
	var y := o.y + 50.0
	for i in ONGLETS.size():
		var nom: String = ONGLETS[i]
		var actif := i == onglet
		_texte(Vector2(x, y), nom, MenuStyle.OR if actif else MenuStyle.GRIS)
		if actif:
			_vue.draw_rect(Rect2(x, y + 3.0, _larg(nom), 1), MenuStyle.OR)
		_zones["onglet:%d" % i] = Rect2(x - 3.0, y - 11.0, _larg(nom) + 6.0, 16.0)
		x += _larg(nom) + 14.0
	var bourse := "Bourse"
	var gb := _prix(dx, y, int(e["or"]), MenuStyle.PARCHEMIN)
	_texte(Vector2(gb - 4.0 - _larg(bourse), y), bourse, MenuStyle.GRIS)
	y += 7.0
	# cartes
	if lignes.is_empty():
		var vide := "Étal vide. Revenez dans %s." % duree_texte(heures_avant_reassort(id_marchand)) if onglet == 0 else "Rien à vendre dans votre sac."
		_texte(Vector2(o.x, y + CARTE + 4.0), vide, MenuStyle.GRIS, w, HORIZONTAL_ALIGNMENT_CENTER)
	for k in vis:
		var i := _haut + k
		var l: Dictionary = lignes[i]
		var id := String(l["id"])
		var refus := String(l["refus"])
		var a := 0.45 if refus != "" else 1.0
		var r := Rect2(gx - 4.0, y, w - 24.0, CARTE - 2.0)
		_zones["carte:%d" % i] = r
		var rar := ButinTables.rarete_de(id)
		var col := Color(ButinTables.COULEURS_RARETE.get(rar, "#c8d0dc"))
		_vue.draw_rect(r, Color(PLAQUE, 0.95))
		if i == choix:
			_vue.draw_rect(r, Color(MenuStyle.RUNE, 0.10))
			_vue.draw_rect(r, Color(MenuStyle.RUNE, 0.7), false, 1.0)
		else:
			_vue.draw_rect(r, FER, false, 1.0)
		var ico := _icone(id, rar)
		var cote := 12.0 if ico.get_size().x > 12.0 else ico.get_size().x
		_vue.draw_texture_rect(ico, Rect2(Vector2(gx, y + floorf((CARTE - 2.0 - cote) * 0.5)), Vector2(cote, cote)), false, Color(1, 1, 1, a))
		var droite := dx - 4.0
		var gauche_prix := droite
		if refus == "":
			var peut := (inv.pieces >= int(l["prix"])) if onglet == 0 else (int(e["or"]) >= int(l["prix"]))
			gauche_prix = _prix(droite, y + 10.0, int(l["prix"]), MenuStyle.OR if peut else ROUGE)
		var nb := "x%d" % int(l["n"])
		_texte(Vector2(droite - _larg(nb), y + 20.0), nb, Color(MenuStyle.GRIS, maxf(a, 0.7)))
		var nom := _couper(inv.nom(id), gauche_prix - 8.0 - (gx + 16.0))
		_texte(Vector2(gx + 16.0, y + 10.0), nom, Color(col.lightened(0.15) if i == choix else col, a))
		var desc := refus if refus != "" else _description(id)
		_texte(Vector2(gx + 16.0, y + 20.0), _couper(desc, droite - _larg(nb) - 8.0 - (gx + 16.0)), Color(MenuStyle.GRIS if refus == "" else ROUGE, maxf(a, 0.8)))
		y += CARTE
	if lignes.size() > m:
		if _haut > 0:
			_texte(Vector2(dx + 2.0, o.y + 68.0), "^", MenuStyle.GRIS)
		if _haut + m < lignes.size():
			_texte(Vector2(dx + 2.0, o.y + 57.0 + vis * CARTE), "v", MenuStyle.GRIS)
	# ligne d'information : retour de la dernière transaction, sinon « stock limité »
	y = o.y + h - 31.0
	if _avis_t > 0.0:
		_texte(Vector2(gx, y), _couper(_avis, w - 32.0), _avis_couleur)
	elif onglet == 0:
		_texte(Vector2(gx, y), "Stock limité, réassort dans %s" % duree_texte(heures_avant_reassort(id_marchand)), Color(MenuStyle.OR, 0.8))
	else:
		_texte(Vector2(gx, y), "Rachat à %d %% de la valeur" % roundi(float(fiche(id_marchand).get("vente", 0.4)) * 100.0), Color(MenuStyle.OR, 0.8))
	# pied : actions cliquables
	y = o.y + h - 15.0
	var x0 := gx
	var verbe := "Acheter" if onglet == 0 else "Vendre"
	for act: Array in [["E", verbe, "un"], ["R", "Tout", "tout"], ["Tab", ONGLETS[1 - onglet], "onglet:%d" % (1 - onglet)], ["Échap", "Fermer", "fermer"]]:
		var cle := "[%s]" % act[0]
		_texte(Vector2(x0, y), cle, MenuStyle.OR)
		var lx := x0 + _larg(cle) + 3.0
		_texte(Vector2(lx, y), act[1], MenuStyle.PARCHEMIN)
		var fin := lx + _larg(act[1])
		if not _zones.has(act[2]):
			_zones[act[2]] = Rect2(x0 - 2.0, y - 11.0, fin - x0 + 4.0, 14.0)
		x0 = fin + 10.0
