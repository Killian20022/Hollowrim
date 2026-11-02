class_name OngletCompetences
extends OngletMenu
## Onglet « Compétences » (lot D, docs/RPG.md §8-9 ; maquette A_parchemin/4_competences) : l'arbre dessiné à l'encre sur les
## deux pages du codex. Les 8 compétences sont 8 colonnes (4 par page : nom en rubrique, niveau, barre, famille) ; chaque perk
## est un médaillon : or gravé = acquis, sceau de cire rouge = à prendre, cercle pâle = scellé (sceau cerclé d'or : rangs en
## cours). Un tronc sort de la reliure, ses branches montent dans les colonnes. En bas : points à dépenser + légende (page
## gauche), fiche du perk choisi (page droite). Achat : Progression.acheter_perk (aucune règle ici : la réponse de la
## progression fait foi, le refus s'affiche tel quel).
## Données : data/competences/arbre.json (lot B), format docs/CONCEPTION_RPG.md §2.9, lu au mieux (voir charger_arbre) ; tant
## qu'il n'existe pas, outils/donnees_test/arbre_demo.json (démonstration).
## Commandes : flèches / Z S (physiques W S) / croix et stick = choisir ; Entrée, D, clic sur le perk choisi, A = apposer le
## sceau ; molette = monter / descendre. Tab, Échap, Q / E, LB / RB : coquille (non consommés).
## Dessiné pour l'écran logique 640x360 (centré s'il est plus grand) ; le fond du livre est peint par la coquille
## (Parchemin.livre), l'onglet ne dessine que le contenu des pages.

const ARBRE := "res://data/competences/arbre.json"
const ARBRE_DEMO := "res://outils/donnees_test/arbre_demo.json"
## Colonnes (x gauche) : 4 sur la page gauche, 4 sur la page droite ; largeur utile 70 px.
const COLS := [20, 93, 166, 239, 336, 409, 482, 555]
const LARG_COL := 70
const Y_BAS := 226        ## haut du médaillon du rang 0
const Y_HAUT := 70        ## haut du médaillon le plus haut possible
const PAS_MAX := 26
const PIED := 245         ## pied des colonnes (fin des branches du tronc)

var perks: Array = []                 ## fiches normalisées (voir _normaliser), dans l'ordre du fichier
var source := ""                      ## chemin réellement lu (tests)
var choix := ""                       ## id du perk choisi
var _par_id := {}
var _grille := {}                     ## competence -> [[id, …] par rang]
var _place := {}                      ## id -> Vector2 (coin haut-gauche du médaillon, repère 640x360)
var _zones := {}                      ## id -> Rect2 cliquable (repère 640x360)
var _avis := ""                       ## dernier refus / confirmation (ligne d'état de la fiche)
var _avis_t := 0.0
var _police: FontFile
var _gothique: FontFile
var _meds := {}                       ## "etat|sel" -> ImageTexture
var _encre: ImageTexture              ## arbre (tronc, branches, tiges) peint à l'encre
var _encre_cle := ""

func id_onglet() -> String:
	return "competences"

func titre() -> String:
	return "Compétences"

func aide() -> Array:
	return [["Flèches / Croix", "Choisir"], ["Entrée / A", "Apposer le sceau"]]

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
	var liste: Array = []
	for c: String in ([chemin] if chemin != "" else [ARBRE, ARBRE_DEMO]):
		liste = charger_arbre(c)
		if not liste.is_empty():
			source = c
			break
	perks = liste
	_par_id = {}
	for p: Dictionary in perks:
		_par_id[p["id"]] = p
	_disposer()
	if choix == "" or not _par_id.has(choix):
		choix = String(perks[0]["id"]) if not perks.is_empty() else ""
	_encre_cle = ""
	queue_redraw()

## Format accepté (au mieux, en attendant le fichier du lot B) : un tableau de fiches, ou {"perks": [fiches]} /
## {"perks": {id: fiche}}, ou directement {id: fiche} (clés commençant par « _ » ignorées). Fiche : id, competence (nom
## canonique ou interne), nom, description, niveau_requis, prerequis [ids], rangs, effets, position [x, y].
static func charger_arbre(chemin: String) -> Array:
	if not FileAccess.file_exists(chemin):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var brut: Array = []
	if d is Dictionary and d.has("perks"):
		d = d["perks"]
	if d is Array:
		brut = d
	elif d is Dictionary:
		for k in d:
			if String(k).begins_with("_") or not d[k] is Dictionary:
				continue
			var f: Dictionary = (d[k] as Dictionary).duplicate()
			if not f.has("id"):
				f["id"] = String(k)
			brut.append(f)
	var res: Array = []
	for f in brut:
		if f is Dictionary and f.has("id") and f.has("competence"):
			res.append(_normaliser(f))
	return res

static func _normaliser(f: Dictionary) -> Dictionary:
	var pos = f.get("position", null)
	var prerequis: Array = []
	for p in f.get("prerequis", []):
		prerequis.append(String(p))
	return {"id": String(f["id"]), "competence": Progression.canonique(String(f["competence"])),
		"nom": String(f.get("nom", f["id"])), "description": String(f.get("description", "")),
		"niveau_requis": int(f.get("niveau_requis", 0)), "prerequis": prerequis, "rangs": maxi(1, int(f.get("rangs", 1))),
		"effets": f.get("effets", {}), "position": Vector2(float(pos[0]), float(pos[1])) if pos is Array and pos.size() >= 2 else null}

## Rangs (lignes) de chaque colonne : position.y si donnée, sinon profondeur des prérequis dans la même compétence.
func _disposer() -> void:
	_grille = {}
	for nom: String in Progression.COMPETENCES:
		var rangs := {}
		for p: Dictionary in perks:
			if p["competence"] != nom:
				continue
			var r := int(p["position"].y) if p["position"] != null else _profondeur(p, 0)
			if not rangs.has(r):
				rangs[r] = []
			rangs[r].append(p)
		var cles := rangs.keys()
		cles.sort()
		var lignes: Array = []
		for r in cles:
			var l: Array = rangs[r]
			l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return (a["position"].x if a["position"] != null else 0.0) < (b["position"].x if b["position"] != null else 0.0))
			lignes.append(l.map(func(p: Dictionary) -> String: return String(p["id"])))
		_grille[nom] = lignes
	_place = {}
	_zones = {}
	for i in Progression.COMPETENCES.size():
		var nom: String = Progression.COMPETENCES[i]
		var lignes: Array = _grille[nom]
		var pas := _pas(lignes.size())
		for r in lignes.size():
			var ids: Array = lignes[r]
			for k in ids.size():
				var pos := Vector2(COLS[i] + 4 + k * 19, Y_BAS - r * pas)
				_place[ids[k]] = pos
				var larg := 15.0 if ids.size() > 1 else float(LARG_COL - 4)
				_zones[ids[k]] = Rect2(pos - Vector2(1, 1), Vector2(larg + 2, 17))

func _pas(n: int) -> int:
	return PAS_MAX if n <= 1 else mini(PAS_MAX, int(float(Y_BAS - Y_HAUT) / float(n - 1)))

func _profondeur(p: Dictionary, garde: int) -> int:
	var d := 0
	if garde > 12:
		return 0
	for q in p["prerequis"]:
		if _par_id.has(q) and _par_id[q]["competence"] == p["competence"]:
			d = maxi(d, _profondeur(_par_id[q], garde + 1) + 1)
	return d

# ------------------------------------------------------------------ état (affichage seulement)

func _prog() -> Progression:
	return joueur.progression if joueur != null else null

func rang(id: String) -> int:
	var pr := _prog()
	return pr.rang_perk(id) if pr != null else 0

## « ok » (tous les rangs), « partiel » (rangs en cours, encore achetable), « dispo » (achetable), « non » (scellé).
## Lecture des conditions de la fiche pour la COULEUR du médaillon ; l'achat reste décidé par Progression.acheter_perk.
func etat(id: String) -> String:
	var p: Dictionary = _par_id.get(id, {})
	var pr := _prog()
	if p.is_empty() or pr == null:
		return "non"
	var r := pr.rang_perk(id)
	if r >= int(p["rangs"]):
		return "ok"
	if raison(id) == "":
		return "partiel" if r > 0 else "dispo"
	return "ok" if r > 0 else "non"

## Pourquoi le perk est scellé ("" s'il peut être pris) : texte d'aide de la fiche.
func raison(id: String) -> String:
	var p: Dictionary = _par_id.get(id, {})
	var pr := _prog()
	if p.is_empty() or pr == null:
		return "Arbre indisponible."
	if pr.has_method("refus_perk"):   # si le lot B expose sa propre vérification, elle fait foi
		return String(pr.call("refus_perk", id))
	if pr.rang_perk(id) >= int(p["rangs"]):
		return "Déjà acquis."
	if pr.competence(p["competence"]) < int(p["niveau_requis"]):
		return "%s %d requis." % [Parchemin.nom_competence(p["competence"]), int(p["niveau_requis"])]
	for q in p["prerequis"]:
		if not pr.a_perk(q):
			return "Requiert : %s." % String(_par_id.get(q, {}).get("nom", q))
	if pr.points_perk <= 0:
		return "Aucun point à dépenser."
	return ""

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
		_avis = "Sceau apposé : %s%s." % [_par_id[choix]["nom"], "" if int(_par_id[choix]["rangs"]) <= 1 else " (rang %d)" % (avant + 1)]
		Sons.jouer(self, ["sword-unsheathe"], -12.0)
	else:
		_avis = r
	_avis_t = 3.0
	message.emit(_avis)
	contenu_change.emit()
	queue_redraw()
	return r

func entree(e: InputEvent) -> bool:
	if perks.is_empty():
		return false
	if e is InputEventMouseMotion:
		var id := _sous(make_input_local(e).position)
		if id != "" and id != choix:
			choix = id
			queue_redraw()
		return id != ""
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			deplacer(Vector2i(0, -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var id := _sous(make_input_local(e).position)
			if id == "":
				return false
			if id == choix or mb.double_click:
				acheter()
			else:
				choix = id
				queue_redraw()
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

## Déplace la sélection : haut / bas dans la colonne (le haut de l'écran = rangs plus élevés), gauche / droite entre voisins
## du même rang puis entre colonnes (au rang le plus proche).
func deplacer(d: Vector2i) -> void:
	if choix == "" or not _par_id.has(choix):
		return
	var c := Progression.COMPETENCES.find(_par_id[choix]["competence"])
	var lignes: Array = _grille[_par_id[choix]["competence"]]
	var r := 0
	var k := 0
	for i in lignes.size():
		if choix in lignes[i]:
			r = i
			k = lignes[i].find(choix)
	if d.y != 0:
		var nr := clampi(r - d.y, 0, lignes.size() - 1)
		choix = lignes[nr][mini(k, lignes[nr].size() - 1)]
	elif d.x != 0:
		var nk := k + d.x
		if nk >= 0 and nk < lignes[r].size():
			choix = lignes[r][nk]
		else:
			var nc := c
			for _i in Progression.COMPETENCES.size():
				nc = posmod(nc + d.x, Progression.COMPETENCES.size())
				var l2: Array = _grille[Progression.COMPETENCES[nc]]
				if not l2.is_empty():
					var r2 := mini(r, l2.size() - 1)
					choix = l2[r2][0 if d.x > 0 else l2[r2].size() - 1]
					break
	queue_redraw()

# ------------------------------------------------------------------ dessin

func _med(etat_: String, sel: bool) -> ImageTexture:
	var cle := "%s|%s" % [etat_, sel]
	if not _meds.has(cle):
		_meds[cle] = ImageTexture.create_from_image(Parchemin.medaillon(etat_, sel))
	return _meds[cle]

## Clé de l'image d'encre : change quand un perk change d'état (tiges pleines / pointillées).
func _cle_encre() -> String:
	var s := ""
	for p: Dictionary in perks:
		s += "1" if rang(p["id"]) > 0 else "0"
	return s

## L'arbre à l'encre (repère 640x360) : racines, tronc qui sort de la reliure, branches vers chaque colonne, liens entre un perk
## et ses prérequis (plein si les deux sont pris, pointillé sinon), bourgeons de feuilles.
func _peindre_encre() -> void:
	var img := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var E := Parchemin.ENCRE
	var cx := 320
	for f: Vector2 in [Vector2(286, 327), Vector2(296, 330), Vector2(308, 331), Vector2(332, 331), Vector2(344, 330), Vector2(354, 327)]:
		Parchemin.courbe(img, Vector2(cx, 302), Vector2((cx + f.x) * 0.5, 320), f, 1, E)
	for y in range(250, 316):
		var ep := 7 + int((y - 250) / 18.0)
		for x in range(cx - ep / 2 - 1, cx - ep / 2 + ep + 1):
			var col := E
			if x >= cx - ep / 2 and x < cx - ep / 2 + ep:
				col = Parchemin.PALE if x != cx - ep / 2 + 1 else Parchemin.VELIN[0]
			img.set_pixel(x, y, col)
	for i in Progression.COMPETENCES.size():
		var nom: String = Progression.COMPETENCES[i]
		var lignes: Array = _grille.get(nom, [])
		if lignes.is_empty():
			continue
		var bx := int(COLS[i]) + 11
		var debut := Vector2(cx + (-3 if i < 4 else 3), 252 - absf(i - 3.5) * 2.0)
		Parchemin.courbe(img, debut, Vector2(bx, 258), Vector2(bx, PIED), 2, E)
		# racines des perks sans prérequis dans la colonne : du pied au médaillon
		for id: String in lignes[0]:
			var c0: Vector2 = _place[id] + Vector2(7, 7)
			Parchemin.tracer(img, Vector2i(bx, PIED), Vector2i(int(c0.x), PIED - 4), 1, E)
			Parchemin.tracer(img, Vector2i(int(c0.x), PIED - 4), Vector2i(int(c0.x), int(c0.y)), 1, E)
		for ids: Array in lignes:
			for id: String in ids:
				var p: Dictionary = _par_id[id]
				for q: String in p["prerequis"]:
					if not _place.has(q) or _par_id[q]["competence"] != nom:
						continue
					var a := Vector2i(_place[q] + Vector2(7, 7))
					var b := Vector2i(_place[id] + Vector2(7, 7))
					var plein := rang(id) > 0 and rang(q) > 0
					_lien(img, a, b, plein)
		# bourgeons d'encre le long de la tige principale
		for r in range(lignes.size() - 1):
			var y := int(_place[lignes[r][0]].y) - 5
			img.fill_rect(Rect2i(bx - 3, y, 2, 1), Parchemin.PALE)
			img.fill_rect(Rect2i(bx + 2, y - 3, 2, 1), Parchemin.PALE)
	_encre = ImageTexture.create_from_image(img)

## Lien vertical puis horizontal (coude à mi-hauteur) : plein à l'encre, ou pointillé pâle (2 px sur 2).
func _lien(img: Image, a: Vector2i, b: Vector2i, plein: bool) -> void:
	var pts: Array = []
	var ym := (a.y + b.y) / 2
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
	var o := Parchemin.origine(size)
	draw_set_transform(o)
	var pr := _prog()
	if _encre_cle != _cle_encre() or _encre == null:
		_encre_cle = _cle_encre()
		_peindre_encre()
	draw_texture(_encre, Vector2.ZERO)
	# en-têtes des colonnes
	for i in Progression.COMPETENCES.size():
		var nom: String = Progression.COMPETENCES[i]
		var x := float(COLS[i])
		var niv := pr.competence(nom) if pr != null else Competences.DEPART
		var sel: bool = choix != "" and _par_id.has(choix) and _par_id[choix]["competence"] == nom
		if sel:
			Parchemin.ruban(self, Rect2(x - 3, 31, LARG_COL + 6, 14))
		Parchemin.texte(self, _police, Vector2(x, 32), Parchemin.nom_competence(nom), Parchemin.CLAIR if sel else Parchemin.RUBRIQUE)
		Parchemin.texte_droite(self, _police, x + LARG_COL, 32, str(niv), Parchemin.CLAIR if sel else Parchemin.ENCRE)
		Parchemin.barre(self, Rect2(x, 47, LARG_COL, 6), _part_competence(nom), Parchemin.BOIS)
		Parchemin.texte(self, _police, Vector2(x, 55), String(Parchemin.FAMILLES.get(nom, "")), Parchemin.PALE)
	# médaillons et noms
	for i in Progression.COMPETENCES.size():
		var lignes: Array = _grille.get(Progression.COMPETENCES[i], [])
		for ids: Array in lignes:
			for id: String in ids:
				var p: Dictionary = _par_id[id]
				var pos: Vector2 = _place[id]
				var et := etat(id)
				draw_texture(_med(et, id == choix), pos)
				if ids.size() == 1:
					var col := Parchemin.PALE if et == "non" else (Parchemin.RUBRIQUE if et == "dispo" or et == "partiel" else Parchemin.ENCRE)
					var nom_aff := String(p["nom"])
					var lignes_nom := Parchemin.couper(_police, nom_aff, LARG_COL - 22)
					if int(p["rangs"]) > 1:
						lignes_nom[lignes_nom.size() - 1] += " %d/%d" % [rang(id), int(p["rangs"])]
						if Parchemin.largeur(_police, lignes_nom[lignes_nom.size() - 1]) > LARG_COL - 20:
							var dernier := lignes_nom[lignes_nom.size() - 1]
							var cut := dernier.rfind(" ")
							lignes_nom[lignes_nom.size() - 1] = dernier.substr(0, cut)
							lignes_nom.append(dernier.substr(cut + 1))
					var y0 := pos.y + (2.0 if lignes_nom.size() == 1 else -3.0)
					for j in mini(lignes_nom.size(), 2):
						Parchemin.texte(self, _police, Vector2(pos.x + 18, y0 + j * 10), lignes_nom[j], col)
	# bas de la page gauche : points et légende
	var pts := pr.points_perk if pr != null else 0
	Parchemin.lettrine(self, _police, Rect2(20, 264, 26, 26), str(pts), Parchemin.TAILLE)
	Parchemin.texte(self, _police, Vector2(54, 265), "point%s à dépenser" % ("s" if pts > 1 else ""), Parchemin.ENCRE)
	Parchemin.texte(self, _police, Vector2(54, 277), "(1 par niveau gagné)", Parchemin.PALE)
	var lx := 20.0
	for l: Array in [["ok", "acquis", Parchemin.ENCRE], ["dispo", "à prendre", Parchemin.RUBRIQUE], ["non", "scellé", Parchemin.PALE]]:
		draw_texture(_med(l[0], false), Vector2(lx, 303))
		Parchemin.texte(self, _police, Vector2(lx + 18, 304), l[1], l[2])
		lx += 26.0 + Parchemin.largeur(_police, l[1]) + 14.0
	_fiche()
	draw_set_transform(Vector2.ZERO)

func _part_competence(nom: String) -> float:
	if joueur == null:
		return 0.0
	var i := Progression.interne(nom)
	var c: Competences = joueur.progression.competences
	return clampf(c.progression(i), 0.0, 1.0) if c.niveaux.has(i) else 0.0

## Fiche du perk choisi (bas de la page droite) : nom en rubrique gothique, condition, description, rang, état / refus.
func _fiche() -> void:
	if choix == "" or not _par_id.has(choix):
		Parchemin.texte(self, _police, Vector2(344, 270), "L'arbre n'est pas encore gravé.", Parchemin.PALE)
		return
	var p: Dictionary = _par_id[choix]
	var X := 344.0
	draw_string(_gothique, Vector2(X, 275), String(p["nom"]), HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Parchemin.RUBRIQUE)
	var pr := _prog()
	var req := "%s %d · tu es %d" % [Parchemin.nom_competence(p["competence"]), int(p["niveau_requis"]), pr.competence(p["competence"]) if pr != null else 15]
	var lt := Parchemin.largeur(_gothique, String(p["nom"]), Parchemin.TITRE)
	var yreq := 262.0 if X + lt + 12.0 + Parchemin.largeur(_police, req) < 618.0 else 278.0
	Parchemin.texte_droite(self, _police, 618, yreq, req, Parchemin.PALE)
	var y := 283.0 if yreq < 270.0 else 291.0
	var desc := Parchemin.couper(_police, String(p["description"]), 274)
	for j in mini(desc.size(), 3 if yreq < 270.0 else 2):
		Parchemin.texte(self, _police, Vector2(X, y + j * 10), desc[j], Parchemin.ENCRE)
	var r := rang(choix)
	var n := int(p["rangs"])
	var bas := 316.0
	var rang_txt := ("Rang %d / %d" % [r, n]) if n > 1 else ("Acquis" if r > 0 else "Un seul rang")
	Parchemin.texte(self, _police, Vector2(X, bas), rang_txt, Parchemin.OR_TERNI)
	var etat_txt := _avis
	var col := Parchemin.RUBRIQUE
	if etat_txt == "":
		var rs := raison(choix)
		if rs == "":
			etat_txt = "Entrée : apposer le sceau"
		elif rs == "Déjà acquis.":
			etat_txt = "Sceau apposé"
			col = Parchemin.PALE
		else:
			etat_txt = rs
			col = Parchemin.PALE
	Parchemin.texte_droite(self, _police, 618, bas, etat_txt, col)
