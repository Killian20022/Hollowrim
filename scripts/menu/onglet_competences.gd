class_name OngletCompetences
extends OngletMenu
## Onglet « Compétences » (lot D, docs/RPG.md §8-9 et §13 ; maquette A_parchemin/4_competences) : l'arbre dessiné à l'encre
## sur les deux pages du codex.
## - En haut, les 8 compétences (4 par page : nom en rubrique, barre de progression, niveau, pierre) : le sommaire.
## - Au milieu, deux PIERRES par double page (une par page : Loup | Ours, Rempart | Montagne, Orage | Eir, Corbeau | Cerf) :
##   titre gothique de la pierre, perks placés par `pos` [colonne -2..2, rangée 0..3] ; médaillon or gravé = acquis, sceau de
##   cire rouge = à prendre, sceau cerclé d'or = rangs en cours, cercle pâle = scellé ; liens à l'encre vers les parents
##   (pleins si pris, pointillés sinon). Un tronc sort de la reliure, ses deux branches portent les racines des pierres.
## - En bas : points à dépenser + légende (page gauche), fiche du perk choisi (page droite : effet du rang, condition, refus).
## Achat : Progression.acheter_perk ; raison d'un sceau : Progression.refus_perk (lot B) si elle existe. Aucune règle ici.
## Données : data/competences/arbre.json (lot B, format §13 : pierres / ordre_pierres / perks {nom, pierre, pos, parents,
## description, rangs [{niveau, effets, texte}]}), sinon outils/donnees_test/arbre_demo.json (copie du fichier du lot B) ;
## l'ancien format de la conception (§2.9 : competence, niveau_requis, prerequis, rangs entier, position) est aussi lu.
## Commandes : flèches / Z S (physiques W S) / croix et stick = choisir (gauche / droite passent d'une pierre à l'autre) ;
## Page préc. / suiv., gâchettes LT / RT, clic sur une compétence du sommaire = autre double page ; Entrée, D, A, clic sur le
## perk choisi = apposer le sceau ; molette = monter / descendre. Tab, Échap, Q / E, LB / RB : coquille (non consommés).
## Dessiné pour l'écran logique 640x360 (centré s'il est plus grand) ; le fond du livre est peint par la coquille.

const ARBRE := "res://data/competences/arbre.json"
const ARBRE_DEMO := "res://outils/donnees_test/arbre_demo.json"
## Sommaire : colonnes (x gauche) des 8 compétences, 4 par page ; largeur 70 px.
const COLS := [20, 93, 166, 239, 336, 409, 482, 555]
const LARG_COL := 70
const CENTRES := [166.0, 474.0]   ## centre des pages (arbre d'une pierre par page)
const PAS_X := 54.0               ## écart entre colonnes de perks (pos x)
const Y_BAS := 222                ## haut du médaillon de la rangée 0
const Y_HAUT := 100               ## haut du médaillon le plus haut
const PAS_MAX := 44
const LARG_NOM := 52.0            ## largeur des noms sous les médaillons

var perks: Array = []             ## fiches normalisées (voir _normaliser), dans l'ordre du fichier
var pierres := {}                 ## competence -> {id, nom, titre, description}
var ordre: Array = []             ## ordre des pierres (compétences canoniques)
var source := ""                  ## chemin réellement lu (tests)
var choix := ""                   ## id du perk choisi
var _par_id := {}
var _place := {}                  ## id -> Vector2 (coin haut-gauche du médaillon, repère 640x360) pour la double page affichée
var _zones := {}                  ## id -> Rect2 cliquable
var _zones_sommaire: Array = []   ## [Rect2, competence]
var _double := -1                 ## double page affichée (0..3)
var _avis := ""
var _avis_t := 0.0
var _police: FontFile
var _gothique: FontFile
var _meds := {}
var _encre: ImageTexture
var _encre_cle := ""

func id_onglet() -> String:
	return "competences"

func titre() -> String:
	return "Compétences"

func aide() -> Array:
	return [["Flèches / Croix", "Choisir"], ["Page / LT RT", "Pierres"], ["Entrée / A", "Apposer le sceau"]]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if perks.is_empty():
		charger()

func _process(dt: float) -> void:
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_avis = ""
			queue_redraw()

# ------------------------------------------------------------------ données

## Lit l'arbre : data/competences/arbre.json, sinon la démonstration. `chemin` force un fichier (tests).
func charger(chemin := "") -> void:
	var a := {}
	for c: String in ([chemin] if chemin != "" else [ARBRE, ARBRE_DEMO]):
		a = charger_arbre(c)
		if not a["perks"].is_empty():
			source = c
			break
	perks = a["perks"]
	pierres = a["pierres"]
	ordre = a["ordre"]
	_par_id = {}
	for p: Dictionary in perks:
		_par_id[p["id"]] = p
	if choix == "" or not _par_id.has(choix):
		choix = _racine(ordre[0]) if not ordre.is_empty() else ""
	_double = -1
	_disposer()
	queue_redraw()

## Lit un arbre au mieux. Renvoie {perks: [fiche normalisée], pierres: {competence: {id, nom, titre, description}}, ordre: [8]}.
## Formats : lot B (docs/RPG.md §13) {pierres, ordre_pierres, perks {id: {nom, pierre, pos, parents, description, rangs [{niveau,
## effets, texte}]}}} ; conception (§2.9) : tableau ou {perks: […] / {id: …}} ou {id: …} de fiches {competence, nom,
## description, niveau_requis, prerequis (tous requis), rangs (entier), position}.
static func charger_arbre(chemin: String) -> Dictionary:
	var res := {"perks": [], "pierres": {}, "ordre": []}
	if not FileAccess.file_exists(chemin):
		return res
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if d is Dictionary:
		for k in d.get("pierres", {}):
			var pi: Dictionary = d["pierres"][k]
			res["pierres"][Progression.canonique(String(pi.get("competence", k)))] = {"id": String(k), "nom": String(pi.get("nom", "")),
				"titre": String(pi.get("titre", "")), "description": String(pi.get("description", ""))}
		for k in d.get("ordre_pierres", []):
			var c := String(k)
			if d.get("pierres", {}).has(c):
				c = String(d["pierres"][c].get("competence", c))
			res["ordre"].append(Progression.canonique(c))
	var brut: Array = []
	if d is Dictionary and d.has("perks"):
		d = d["perks"]
	if d is Array:
		brut = d
	elif d is Dictionary:
		for k in d:
			if String(k).begins_with("_") or not d[k] is Dictionary or k in ["pierres", "ordre_pierres"]:
				continue
			var f: Dictionary = (d[k] as Dictionary).duplicate()
			if not f.has("id"):
				f["id"] = String(k)
			brut.append(f)
	for f in brut:
		if f is Dictionary and f.has("id") and (f.has("competence") or f.has("pierre")):
			res["perks"].append(_normaliser(f, res["pierres"]))
	if res["ordre"].is_empty():
		for c: String in Progression.COMPETENCES:
			res["ordre"].append(c)
	return res

static func _normaliser(f: Dictionary, pierres_: Dictionary) -> Dictionary:
	var comp := ""
	if f.has("pierre"):
		comp = String(f["pierre"])
		for c in pierres_:
			if pierres_[c]["id"] == comp:
				comp = String(c)
	else:
		comp = String(f["competence"])
	var niveaux: Array = []
	var textes: Array = []
	var rangs = f.get("rangs", 1)
	if rangs is Array:
		for r in rangs:
			niveaux.append(int(r.get("niveau", 0)) if r is Dictionary else 0)
			textes.append(String(r.get("texte", "")) if r is Dictionary else "")
	else:
		for i in maxi(1, int(rangs)):
			niveaux.append(int(f.get("niveau_requis", 0)))
			textes.append("")
	if niveaux.is_empty():
		niveaux = [0]
		textes = [""]
	var pos = f.get("pos", f.get("position", null))
	var parents: Array = []
	for p in f.get("parents", f.get("prerequis", [])):
		parents.append(String(p))
	return {"id": String(f["id"]), "competence": Progression.canonique(comp), "nom": String(f.get("nom", f["id"])),
		"description": String(f.get("description", "")), "niveaux": niveaux, "textes": textes, "rangs": niveaux.size(),
		"prerequis": parents, "un_parent": f.has("parents"),
		"position": Vector2(float(pos[0]), float(pos[1])) if pos is Array and pos.size() >= 2 else null}

func _perks_de(comp: String) -> Array:
	return perks.filter(func(p: Dictionary) -> bool: return p["competence"] == comp)

## Racine d'une pierre (rangée la plus basse).
func _racine(comp: String) -> String:
	var meilleur := ""
	var rmin := 999
	for p: Dictionary in _perks_de(comp):
		var r := _rangee(p)
		if r < rmin:
			rmin = r
			meilleur = p["id"]
	return meilleur

func _rangee(p: Dictionary) -> int:
	return int(p["position"].y) if p["position"] != null else _profondeur(p, 0)

func _colonne(p: Dictionary) -> float:
	if p["position"] != null:
		return p["position"].x
	var memes := _perks_de(p["competence"]).filter(func(q: Dictionary) -> bool: return _rangee(q) == _rangee(p))
	var i := memes.find(p)
	return i - (memes.size() - 1) * 0.5

func _profondeur(p: Dictionary, garde: int) -> int:
	var d := 0
	if garde > 12:
		return 0
	for q in p["prerequis"]:
		if _par_id.has(q) and _par_id[q]["competence"] == p["competence"]:
			d = maxi(d, _profondeur(_par_id[q], garde + 1) + 1)
	return d

## Double page du perk choisi (0..3) et place des médaillons de ses deux pierres.
func _disposer() -> void:
	var d := 0
	if _par_id.has(choix):
		d = maxi(0, ordre.find(_par_id[choix]["competence"])) / 2
	if d == _double and not _place.is_empty():
		return
	_double = d
	_place = {}
	_zones = {}
	var pa := _pierres_affichees()
	var n_max := 1
	for comp in pa:
		for p: Dictionary in _perks_de(comp):
			n_max = maxi(n_max, _rangee(p) + 1)
	var pas := PAS_MAX if n_max <= 1 else clampi(int(float(Y_BAS - Y_HAUT) / float(n_max - 1)), 22, PAS_MAX)
	for k in pa.size():
		for p: Dictionary in _perks_de(pa[k]):
			var pos := Vector2(roundf(CENTRES[k] + _colonne(p) * PAS_X) - 7.0, Y_BAS - _rangee(p) * pas)
			_place[p["id"]] = pos
			_zones[p["id"]] = Rect2(pos.x + 7.0 - LARG_NOM * 0.5, pos.y - 1, LARG_NOM, 36)
	_encre_cle = ""

func _pierres_affichees() -> Array:
	var r: Array = []
	for i in [_double * 2, _double * 2 + 1]:
		if i >= 0 and i < ordre.size():
			r.append(ordre[i])
	return r

# ------------------------------------------------------------------ état (affichage seulement)

func _prog() -> Progression:
	return joueur.progression if joueur != null else null

func rang(id: String) -> int:
	var pr := _prog()
	return pr.rang_perk(id) if pr != null else 0

## « ok » (tous les rangs, ou des rangs pris sans pouvoir en prendre un autre), « partiel » (rangs en cours, encore
## achetable), « dispo » (achetable), « non » (scellé). Couleur seulement : l'achat reste décidé par Progression.
func etat(id: String) -> String:
	var p: Dictionary = _par_id.get(id, {})
	if p.is_empty() or _prog() == null:
		return "non"
	var r := rang(id)
	if r >= int(p["rangs"]):
		return "ok"
	if raison(id) == "":
		return "partiel" if r > 0 else "dispo"
	return "ok" if r > 0 else "non"

## Pourquoi le prochain rang ne peut pas être pris ("" s'il le peut). Progression.refus_perk (lot B) fait foi ; sinon même
## lecture de la fiche, mêmes textes.
func raison(id: String) -> String:
	var p: Dictionary = _par_id.get(id, {})
	var pr := _prog()
	if p.is_empty() or pr == null:
		return "Perk inconnu."
	if pr.has_method("refus_perk"):
		return String(pr.call("refus_perk", id))
	var r := pr.rang_perk(id)
	if r >= int(p["rangs"]):
		return "Rang maximal atteint."
	var parents: Array = p["prerequis"]
	if not parents.is_empty():
		var pris := parents.filter(func(q: String) -> bool: return pr.a_perk(q))
		if (p["un_parent"] and pris.is_empty()) or (not p["un_parent"] and pris.size() < parents.size()):
			var noms := parents.map(func(q: String) -> String: return String(_par_id.get(q, {}).get("nom", q)))
			return "Il faut d'abord : %s." % (" ou " if p["un_parent"] else " et ").join(noms)
	var requis := int(p["niveaux"][r])
	if pr.competence(p["competence"]) < requis:
		return "%s %d requis." % [_titre_pierre(p["competence"]), requis]
	if pr.points_perk <= 0:
		return "Aucun point d'arbre."
	return ""

func _titre_pierre(comp: String) -> String:
	var t := String(pierres.get(comp, {}).get("titre", ""))
	return t if t != "" else Parchemin.nom_competence(comp)

# ------------------------------------------------------------------ OngletMenu

func ouvrir() -> void:
	if perks.is_empty():
		charger()
	_avis = ""
	_encre_cle = ""
	if joueur != null and not joueur.progression.change.is_connected(queue_redraw):
		joueur.progression.change.connect(queue_redraw)
	queue_redraw()

func fermer() -> void:
	if joueur != null and joueur.progression.change.is_connected(queue_redraw):
		joueur.progression.change.disconnect(queue_redraw)

## Appose le sceau (achète un rang) du perk choisi. Renvoie la réponse de Progression ("" = fait).
func acheter() -> String:
	var pr := _prog()
	if choix == "" or pr == null:
		return "Aucun perk."
	var avant := pr.rang_perk(choix)
	var r := pr.acheter_perk(choix)
	if r == "":
		_avis = "Sceau apposé : %s%s." % [Parchemin.lisible(_police, _par_id[choix]["nom"]), "" if int(_par_id[choix]["rangs"]) <= 1 else " (rang %d)" % (avant + 1)]
		Sons.jouer(self, ["sword-unsheathe"], -12.0)
	else:
		_avis = r
	_avis_t = 3.0
	message.emit(_avis)
	contenu_change.emit()
	queue_redraw()
	return r

## Choisit un perk (et affiche sa double page).
func choisir(id: String) -> void:
	if not _par_id.has(id) or id == choix:
		return
	choix = id
	_disposer()
	queue_redraw()

func entree(e: InputEvent) -> bool:
	if perks.is_empty():
		return false
	if e is InputEventMouseMotion:
		var id := _sous(make_input_local(e).position)
		if id != "":
			choisir(id)
		return id != ""
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			deplacer(Vector2i(0, -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var q: Vector2 = make_input_local(e).position - Parchemin.origine(size)
			for z: Array in _zones_sommaire:
				if (z[0] as Rect2).has_point(q):
					choisir(_racine(z[1]))
					return true
			var id := _sous(make_input_local(e).position)
			if id == "":
				return false
			if id == choix or mb.double_click:
				acheter()
			else:
				choisir(id)
			return true
		return false
	if e is InputEventKey and e.pressed:
		var k := e as InputEventKey
		if k.physical_keycode == KEY_W:
			deplacer(Vector2i(0, -1))
			return true
		if k.physical_keycode == KEY_S:
			deplacer(Vector2i(0, 1))
			return true
		if k.physical_keycode == KEY_D and not k.echo:
			acheter()
			return true
		if k.keycode == KEY_PAGEDOWN or k.keycode == KEY_PAGEUP:
			tourner(1 if k.keycode == KEY_PAGEDOWN else -1)
			return true
	if e is InputEventJoypadMotion:
		var jm := e as InputEventJoypadMotion
		if jm.axis == JOY_AXIS_TRIGGER_LEFT or jm.axis == JOY_AXIS_TRIGGER_RIGHT:
			if jm.axis_value > 0.6 and not has_meta("gachette"):
				set_meta("gachette", true)
				tourner(1 if jm.axis == JOY_AXIS_TRIGGER_RIGHT else -1)
			elif jm.axis_value < 0.3 and has_meta("gachette"):
				remove_meta("gachette")
			return true
	if e.is_action_pressed("ui_accept", false):
		acheter()
		return true
	for a: Array in [["ui_left", Vector2i(-1, 0)], ["ui_right", Vector2i(1, 0)], ["ui_up", Vector2i(0, -1)], ["ui_down", Vector2i(0, 1)]]:
		if e.is_action_pressed(a[0], true):
			deplacer(a[1])
			return true
	return false

func _sous(p: Vector2) -> String:
	var q := p - Parchemin.origine(size)
	for id in _zones:
		if (_zones[id] as Rect2).has_point(q):
			return String(id)
	return ""

## Double page suivante / précédente (racine de la pierre de gauche).
func tourner(d: int) -> void:
	if ordre.is_empty():
		return
	var n := int(ceil(ordre.size() / 2.0))
	choisir(_racine(ordre[posmod(_double + d, n) * 2]))

## Haut / bas : rangée voisine dans la pierre (colonne la plus proche) ; gauche / droite : perk voisin de la rangée, sinon
## pierre voisine (page d'en face, puis double page suivante / précédente) à la rangée la plus proche.
func deplacer(d: Vector2i) -> void:
	if not _par_id.has(choix):
		return
	var p: Dictionary = _par_id[choix]
	var comp: String = p["competence"]
	var r := _rangee(p)
	var c := _colonne(p)
	if d.y != 0:
		var cible := r - d.y
		var meilleur := ""
		var ecart := INF
		for q: Dictionary in _perks_de(comp):
			if _rangee(q) == cible and absf(_colonne(q) - c) < ecart:
				ecart = absf(_colonne(q) - c)
				meilleur = q["id"]
		if meilleur != "":
			choisir(meilleur)
		return
	var voisin := ""
	var ecart_x := INF
	for q: Dictionary in _perks_de(comp):
		var dx := (_colonne(q) - c) * d.x
		if _rangee(q) == r and dx > 0.0 and dx < ecart_x:
			ecart_x = dx
			voisin = q["id"]
	if voisin != "":
		choisir(voisin)
		return
	var i := posmod(ordre.find(comp) + d.x, ordre.size())
	var autres := _perks_de(ordre[i])
	if autres.is_empty():
		return
	var meilleur := ""
	var score := INF
	for q: Dictionary in autres:
		var s := absf(_rangee(q) - r) * 10.0 + _colonne(q) * d.x
		if s < score:
			score = s
			meilleur = q["id"]
	choisir(meilleur)

# ------------------------------------------------------------------ dessin

func _med(etat_: String, sel: bool) -> ImageTexture:
	var cle := "%s|%s" % [etat_, sel]
	if not _meds.has(cle):
		_meds[cle] = ImageTexture.create_from_image(Parchemin.medaillon(etat_, sel))
	return _meds[cle]

func _cle_encre() -> String:
	var s := str(_double)
	for id in _place:
		s += "1" if rang(id) > 0 else "0"
	return s

## L'arbre à l'encre (repère 640x360) : racines, tronc qui sort de la reliure, deux branches vers les racines des pierres,
## liens perk → parents (coude ; plein si les deux sont pris, pointillé pâle sinon).
func _peindre_encre() -> void:
	var img := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var E := Parchemin.ENCRE
	var cx := 320
	for f: Vector2 in [Vector2(288, 329), Vector2(298, 331), Vector2(309, 332), Vector2(331, 332), Vector2(342, 331), Vector2(352, 329)]:
		Parchemin.courbe(img, Vector2(cx, 304), Vector2((cx + f.x) * 0.5, 322), f, 1, E)
	for y in range(252, 318):
		var ep := 7 + int((y - 252) / 18.0)
		for x in range(cx - ep / 2 - 1, cx - ep / 2 + ep + 1):
			var col := E
			if x >= cx - ep / 2 and x < cx - ep / 2 + ep:
				col = Parchemin.PALE if x != cx - ep / 2 + 1 else Parchemin.VELIN[0]
			img.set_pixel(x, y, col)
	var pa := _pierres_affichees()
	for k in pa.size():
		var racine := _racine(pa[k])
		if racine == "" or not _place.has(racine):
			continue
		var rc: Vector2 = _place[racine] + Vector2(7, 7)
		var debut := Vector2(cx + (-3 if k == 0 else 3), 254)
		Parchemin.courbe(img, debut, Vector2(rc.x, 262), Vector2(rc.x, rc.y + 30), 2, E)
		Parchemin.tracer(img, Vector2i(int(rc.x), int(rc.y) + 30), Vector2i(int(rc.x), int(rc.y) + 8), 2, E)
		# rameau secondaire d'encre sur la branche
		var mi := Vector2(roundf((debut.x + rc.x) * 0.5), 259)
		var sg := -1.0 if k == 0 else 1.0
		Parchemin.courbe(img, mi, mi + Vector2(4 * sg, -5), mi + Vector2(10 * sg, -7), 1, Parchemin.PALE)
		for p: Dictionary in _perks_de(pa[k]):
			if not _place.has(p["id"]):
				continue
			for q: String in p["prerequis"]:
				if not _place.has(q):
					continue
				_lien(img, Vector2i(_place[q] + Vector2(7, 7)), Vector2i(_place[p["id"]] + Vector2(7, 7)), rang(p["id"]) > 0 and rang(q) > 0)
	_encre = ImageTexture.create_from_image(img)

## Lien du parent `a` (en bas) au perk `b` : vertical depuis le parent jusqu'au-dessous du nom de `b`, horizontal, vertical.
func _lien(img: Image, a: Vector2i, b: Vector2i, plein: bool) -> void:
	var pts: Array = []
	var ym := b.y + 28 if b.y + 28 < a.y - 8 else (a.y + b.y) / 2
	for seg: Array in [[a, Vector2i(a.x, ym)], [Vector2i(a.x, ym), Vector2i(b.x, ym)], [Vector2i(b.x, ym), b]]:
		var p0: Vector2i = seg[0]
		var p1: Vector2i = seg[1]
		var n := maxi(absi(p1.x - p0.x), absi(p1.y - p0.y))
		for t in n + 1:
			pts.append(p0 + (p1 - p0) * t / maxi(1, n))
	for i in pts.size():
		if plein or (i / 2) % 2 == 0:
			img.set_pixelv(pts[i], Parchemin.ENCRE if plein else Parchemin.PALE)

func _draw() -> void:
	draw_set_transform(Parchemin.origine(size))
	var pr := _prog()
	_disposer()
	if _encre_cle != _cle_encre() or _encre == null:
		_encre_cle = _cle_encre()
		_peindre_encre()
	_sommaire(pr)
	draw_texture(_encre, Vector2.ZERO)
	var pa := _pierres_affichees()
	for k in pa.size():
		_titre_page(pa[k], CENTRES[k])
		for p: Dictionary in _perks_de(pa[k]):
			_perk(p)
	# bas de la page gauche : points et légende
	var pts := pr.points_perk if pr != null else 0
	Parchemin.lettrine(self, _police, Rect2(20, 266, 26, 26), str(pts), Parchemin.TAILLE)
	Parchemin.texte(self, _police, Vector2(54, 267), "point%s à dépenser" % ("s" if pts > 1 else ""), Parchemin.ENCRE)
	Parchemin.texte(self, _police, Vector2(54, 279), "(1 par niveau gagné)", Parchemin.PALE)
	var lx := 20.0
	for l: Array in [["ok", "acquis", Parchemin.ENCRE], ["dispo", "à prendre", Parchemin.RUBRIQUE], ["non", "scellé", Parchemin.PALE]]:
		draw_texture(_med(l[0], false), Vector2(lx, 304))
		Parchemin.texte(self, _police, Vector2(lx + 18, 305), l[1], l[2])
		lx += 26.0 + Parchemin.largeur(_police, l[1]) + 10.0
	_fiche()
	draw_set_transform(Vector2.ZERO)

## Sommaire des 8 compétences (les deux pierres affichées sont soulignées, celle du perk choisi sur un ruban).
func _sommaire(pr: Progression) -> void:
	_zones_sommaire = []
	var pa := _pierres_affichees()
	var comp_sel := String(_par_id.get(choix, {}).get("competence", ""))
	for i in ordre.size():
		var nom: String = ordre[i]
		var x := float(COLS[i]) if i < COLS.size() else 20.0
		var sel := nom == comp_sel
		_zones_sommaire.append([Rect2(x - 2, 30, LARG_COL + 4, 38), nom])
		if sel:
			Parchemin.ruban(self, Rect2(x - 2, 31, LARG_COL + 3, 14))
		elif nom in pa:
			draw_rect(Rect2(x - 2, 44, LARG_COL + 4, 1), Parchemin.RUBRIQUE)
		Parchemin.texte(self, _police, Vector2(x, 32), Parchemin.nom_competence(nom), Parchemin.CLAIR if sel else Parchemin.RUBRIQUE)
		var niv := pr.competence(nom) if pr != null else Competences.DEPART
		Parchemin.barre(self, Rect2(x, 49, LARG_COL - 18, 6), _part_competence(nom), Parchemin.BOIS)
		Parchemin.texte_droite(self, _police, x + LARG_COL, 46, str(niv), Parchemin.ENCRE)
		var pierre := String(pierres.get(nom, {}).get("nom", ""))
		for pre: String in ["Pierre ", "du ", "de l'", "de la ", "d'"]:
			pierre = pierre.trim_prefix(pre)
		Parchemin.texte(self, _police, Vector2(x, 57), Parchemin.lisible(_police, pierre if pierre != "" else String(Parchemin.FAMILLES.get(nom, ""))), Parchemin.PALE)
	Parchemin.filet(self, 28, 71, 276)
	Parchemin.filet(self, 344, 71, 268)

## Titre gothique de la pierre centré sur sa page.
func _titre_page(comp: String, cx: float) -> void:
	var t := Parchemin.lisible(_gothique, String(pierres.get(comp, {}).get("nom", Parchemin.nom_competence(comp))))
	var l := Parchemin.largeur(_gothique, t, Parchemin.TITRE)
	draw_string(_gothique, Vector2(roundf(cx - l * 0.5), 91), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Parchemin.ENCRE)

## Médaillon + nom centré dessous (2 lignes au plus) + rangs « 2/5 » à droite du médaillon.
func _perk(p: Dictionary) -> void:
	var id: String = p["id"]
	if not _place.has(id):
		return
	var pos: Vector2 = _place[id]
	var et := etat(id)
	draw_texture(_med(et, id == choix), pos)
	var col := Parchemin.PALE if et == "non" else (Parchemin.RUBRIQUE if et == "dispo" or et == "partiel" else Parchemin.ENCRE)
	var lignes := Parchemin.couper(_police, Parchemin.lisible(_police, p["nom"]), LARG_NOM)
	if lignes.size() > 2:
		var reste := " ".join(lignes.slice(1))
		while reste.length() > 1 and Parchemin.largeur(_police, reste + ".") > LARG_NOM:
			reste = reste.substr(0, reste.length() - 1)
		lignes = PackedStringArray([lignes[0], reste.strip_edges() + "."])
	for j in lignes.size():
		var l := Parchemin.largeur(_police, lignes[j])
		Parchemin.texte_cerne(self, _police, Vector2(roundf(pos.x + 7.0 - l * 0.5), pos.y + 15.0 + j * 9.0), lignes[j], col)
	if int(p["rangs"]) > 1:
		Parchemin.texte_cerne(self, _police, Vector2(pos.x + 16, pos.y + 1), "%d/%d" % [rang(id), int(p["rangs"])], Parchemin.OR_TERNI if rang(id) > 0 else Parchemin.PALE)

func _part_competence(nom: String) -> float:
	if joueur == null:
		return 0.0
	var i := Progression.interne(nom)
	var c: Competences = joueur.progression.competences
	return clampf(c.progression(i), 0.0, 1.0) if c.niveaux.has(i) else 0.0

## Fiche du perk choisi (bas de la page droite) : nom en rubrique gothique, condition du prochain rang, effet (rang suivant ou
## dernier), description, rang, état / refus.
func _fiche() -> void:
	if not _par_id.has(choix):
		Parchemin.texte(self, _police, Vector2(344, 270), "L'arbre n'est pas encore gravé.", Parchemin.PALE)
		return
	var p: Dictionary = _par_id[choix]
	var X := 344.0
	var nom := Parchemin.lisible(_gothique, p["nom"])
	draw_string(_gothique, Vector2(X, 277), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Parchemin.RUBRIQUE)
	var pr := _prog()
	var r := rang(choix)
	var n := int(p["rangs"])
	var i_rang := mini(r, n - 1)
	var req := "%s %d · tu es %d" % [_titre_pierre(p["competence"]), int(p["niveaux"][i_rang]), pr.competence(p["competence"]) if pr != null else 15]
	if r >= n:
		req = "Tous les rangs pris"
	var lt := Parchemin.largeur(_gothique, nom, Parchemin.TITRE)
	var serre := X + lt + 12.0 + Parchemin.largeur(_police, req) >= 618.0
	Parchemin.texte_droite(self, _police, 618, 280 if serre else 264, req, Parchemin.PALE)
	var y := 292.0 if serre else 284.0
	var effet := String(p["textes"][i_rang])
	if effet != "" and n > 1:
		effet = ("Rang %d : " % (i_rang + 1)) + effet
	var lignes: Array = []
	if effet != "":
		for l in Parchemin.couper(_police, Parchemin.lisible(_police, effet), 274):
			lignes.append([l, Parchemin.ENCRE])
	for l in Parchemin.couper(_police, Parchemin.lisible(_police, p["description"]), 274):
		lignes.append([l, Parchemin.PALE])
	var places := 2 if serre else 3
	for j in mini(lignes.size(), places):
		Parchemin.texte(self, _police, Vector2(X, y + j * 10), lignes[j][0], lignes[j][1])
	var bas := 318.0
	var rang_txt := ("Rang %d / %d" % [r, n]) if n > 1 else ("Acquis" if r > 0 else "Un seul rang")
	Parchemin.texte(self, _police, Vector2(X, bas), rang_txt, Parchemin.OR_TERNI if n > 1 or r > 0 else Parchemin.PALE)
	var etat_txt := _avis
	var col := Parchemin.RUBRIQUE
	if etat_txt == "":
		var rs := raison(choix)
		if rs == "":
			etat_txt = "Entrée : apposer le sceau"
		else:
			etat_txt = rs
			col = Parchemin.PALE
	Parchemin.texte_droite(self, _police, 618, bas, Parchemin.lisible(_police, etat_txt), col)
