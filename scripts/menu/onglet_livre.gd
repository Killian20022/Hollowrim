class_name OngletLivre
extends OngletMenu
## Base des pages du codex (lot C) : polices, rectangles des deux pages, registre défilant (lignes choisies au clavier, à la
## manette ou à la souris), fiche d'objet (icône encadrée, titre gothique, lignes « rubrique : valeur »). Dessin seulement :
## les actions passent par la coquille (InventaireMains). Les onglets du lot D peuvent en hériter (facultatif).

const H_LIGNE := 18.0   # hauteur d'une ligne de registre (icône 16 + 2)
## Côté du cadre de l'aperçu 3D d'une fiche (Sac, Équipement ; px en 640x360).
const COTE_APERCU := 72.0

var coquille: MenuPersonnage = null
var _police: FontFile
var _gothique: FontFile
## Zones cliquables du dessin courant : [Rect2, action (String), valeur]. Remplies par _draw, lues par _gui_input.
var _zones: Array = []
var _survol := -1

func _ready() -> void:
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE

func rects() -> Dictionary:
	return zones_livre(size)

## Zones de contenu du livre de Parchemin (pages de vélin, reliure) : {pages, reliure, gauche, droite, bas}.
## 640x360 : page de gauche 23..307 x 33..325, page de droite 332..617.
static func zones_livre(taille: Vector2) -> Dictionary:
	var p := Parchemin.pages(taille)
	var dos := Parchemin.reliure(taille) + 0.5
	return {"pages": p, "reliure": dos,
		"gauche": Rect2(p.position.x + 10.0, p.position.y + 6.0, dos - p.position.x - 22.0, p.size.y - 12.0),
		"droite": Rect2(dos + 12.0, p.position.y + 6.0, p.end.x - dos - 22.0, p.size.y - 12.0),
		"bas": Rect2(0, p.end.y + 2.0, taille.x, taille.y - p.end.y - 2.0)}

## Texte posé par le HAUT de sa ligne de 9 px (ligne de base 8 px plus bas ; Parchemin.texte : coin haut de la boîte de 11 px),
## aligné à droite si `droite` (x = bord droit), coupé avec « … » au-delà de `larg_max`. Renvoie la largeur.
static func texte_haut(ci: CanvasItem, police: Font, x: float, haut: float, t: String, couleur: Color, droite := false, larg_max := -1.0) -> float:
	if larg_max > 0.0:
		t = MenuStyle.raccourcir(police, t, larg_max)
	var l := Parchemin.largeur(police, t)
	Parchemin.texte(ci, police, Vector2(roundf(x - l) if droite else roundf(x), haut - 3.0), t, couleur)
	return l

func texte(x: float, haut: float, t: String, couleur := Parchemin.ENCRE, droite := false, larg_max := -1.0) -> float:
	return texte_haut(self, _police, x, haut, t, couleur, droite, larg_max)

func largeur(t: String) -> float:
	return _police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TAILLE).x

## Paragraphe coupé à `larg` ; renvoie le haut de la ligne suivante.
func paragraphe(x: float, haut: float, larg: float, t: String, couleur := Parchemin.ENCRE, max_lignes := 6, interligne := 10.0) -> float:
	var lignes := Parchemin.couper(_police, t, larg)
	for i in mini(lignes.size(), max_lignes):
		texte(x, haut, lignes[i], couleur)
		haut += interligne
	return haut

## Icône (16x16) à l'échelle entière `k`, avec une teinte.
func icone(tex: Texture2D, pos: Vector2, k := 1, teinte := Color.WHITE) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(pos, Vector2(16 * k, 16 * k)), false, teinte)

## Grande icône 32 px d'un objet (dessinée depuis son modèle : IconesObjets), sinon l'icône 16 px agrandie ×2.
func icone_grande(id: String, pos: Vector2, teinte := Color.WHITE) -> void:
	var t := MenuStyle.icone_objet_32(id)
	if t != null:
		draw_texture_rect(t, Rect2(pos, Vector2(32, 32)), false, teinte)
	else:
		icone(MenuStyle.icone_objet(id), pos, 2, teinte)

## Aperçu 3D tournant (ApercuObjet) de l'objet `id` dans un cadre de vélin `r` ; sans modèle 3D : grande icône au centre.
var _apercu: ApercuObjet = null
func apercu(r: Rect2, id: String) -> void:
	MenuStyle.cadre_apercu(self, r)
	if _apercu == null:
		_apercu = ApercuObjet.new()
		_apercu.name = "Apercu"
		add_child(_apercu)
	if not _apercu.placer(r.grow(-3), id):
		icone_grande(id, (r.get_center() - Vector2(16, 16)).floor())

func cacher_apercu() -> void:
	if _apercu != null:
		_apercu.cacher()

## Titre de fiche : gothique 24 px s'il tient dans `larg`, sinon police du corps (noms longs : « Croc-Rouge, l'épée de Hrafn »).
func titre_fiche(x: float, haut: float, t: String, larg: float, couleur := Parchemin.ENCRE) -> void:
	if _gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x <= larg:
		draw_string(_gothique, Vector2(roundf(x), roundf(haut) + 17.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, couleur)
	else:
		texte(x, haut + 5.0, t, couleur, false, larg)

## Zone cliquable (pour le dessin courant).
func zone(r: Rect2, action: String, valeur: Variant = null) -> void:
	_zones.append([r, action, valeur])

func _zone_sous(p: Vector2) -> int:
	for i in range(_zones.size() - 1, -1, -1):
		if (_zones[i][0] as Rect2).has_point(p):
			return i
	return -1

## Clic / survol : l'onglet traite les zones (cliquer(action, valeur, bouton) / survoler(action, valeur)) ; sinon l'événement
## remonte à la coquille (signets).
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var i := _zone_sous(e.position)
		if i != _survol:
			_survol = i
			if i >= 0:
				survoler(String(_zones[i][1]), _zones[i][2])
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			if defiler(-1 if b == MOUSE_BUTTON_WHEEL_UP else 1, e.position):
				accept_event()
				queue_redraw()
			return
		var i := _zone_sous(e.position)
		if i >= 0 and (b == MOUSE_BUTTON_LEFT or b == MOUSE_BUTTON_RIGHT):
			cliquer(String(_zones[i][1]), _zones[i][2], b)
			accept_event()
			queue_redraw()
			contenu_change.emit()

func survoler(_action: String, _valeur: Variant) -> void:
	pass

func cliquer(_action: String, _valeur: Variant, _bouton: int) -> void:
	pass

func defiler(_sens: int, _pos: Vector2) -> bool:
	return false

## Lignes « rubrique : valeur » d'une liste de textes (EquipementMains.fiche) : « Vitesse : 1   Endurance : 8 / 26 » donne deux
## lignes ; un texte sans « : » reste une note ([texte, ""]).
static func lignes_rubriques(lignes: Array) -> Array:
	var res: Array = []
	for l: String in lignes:
		for morceau in l.split("   ", false):
			var i := morceau.find(" : ")
			if i < 0 or i > 12:   # « Vive et économe : … » est une description, pas une rubrique
				res.append([morceau.strip_edges(), ""])
			else:
				res.append([morceau.substr(0, i).strip_edges(), valeur_lisible(morceau.substr(i + 3).strip_edges())])
	return res

## Valeur de fiche au format du menu (formatage côté menu, EquipementMains n'est pas touché) : « 11.0 (léger) / 24.0 (lourd) »
## → « 11 léger · 24 lourd » ; nombres « 12.0 » → « 12 », « 2.5 » → « 2,5 ».
static func valeur_lisible(v: String) -> String:
	var re := RegEx.create_from_string("(\\d+)\\.(\\d+)")
	var r := v
	for m in re.search_all(v):
		var dec := m.get_string(2).rstrip("0")
		r = r.replace(m.get_string(), m.get_string(1) if dec == "" else m.get_string(1) + "," + dec)
	var dl := RegEx.create_from_string("^(\\S+) \\(léger\\) / (\\S+) \\(lourd\\)$").search(r)
	if dl != null:
		r = "%s léger · %s lourd" % [dl.get_string(1), dl.get_string(2)]
	return r

## Dégâts d'une arme au format du menu (« 11 léger · 24 lourd »).
static func texte_degats(leger: float, lourd: float) -> String:
	return valeur_lisible("%s (léger) / %s (lourd)" % [str(snappedf(leger, 0.5)), str(snappedf(lourd, 0.5))])

## Touches de navigation communes : renvoie -1 / +1 (haut / bas), -2 / +2 (gauche / droite), 0 sinon.
static func direction(e: InputEvent) -> int:
	if e is InputEventKey and e.pressed:
		match (e as InputEventKey).physical_keycode:
			KEY_UP:
				return -1
			KEY_DOWN:
				return 1
			KEY_LEFT:
				return -2
			KEY_RIGHT:
				return 2
	elif e is InputEventJoypadButton and e.pressed:
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP:
				return -1
			JOY_BUTTON_DPAD_DOWN:
				return 1
			JOY_BUTTON_DPAD_LEFT:
				return -2
			JOY_BUTTON_DPAD_RIGHT:
				return 2
	return 0

## Code d'une touche physique pressée (0 si ce n'est pas une touche pressée).
static func touche(e: InputEvent) -> Key:
	if e is InputEventKey and e.pressed:
		return (e as InputEventKey).physical_keycode
	return KEY_NONE

## Bouton de manette pressé (-1 sinon).
static func bouton(e: InputEvent) -> int:
	if e is InputEventJoypadButton and e.pressed:
		return (e as InputEventJoypadButton).button_index
	return -1

## Raccourci 1-0 de l'événement (0..9) ou -1.
static func chiffre(e: InputEvent) -> int:
	for i in 10:
		if e.is_action_pressed("raccourci_%d" % ((i + 1) % 10)):
			return i
	if e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			return k - KEY_1
		if k == KEY_0:
			return 9
	return -1
