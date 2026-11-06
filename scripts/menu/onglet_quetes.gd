class_name OngletQuetes
extends OngletMenu
## Onglet « Quêtes » (lot D ; style A parchemin) : page gauche = registre des quêtes en cours puis terminées (ligne choisie
## surlignée à l'ocre, losange vermillon = en cours avec l'étape, coche à l'encre = terminée) ; page droite = la quête choisie :
## titre gothique, état, objectif actuel, journal des étapes faites (la plus récente d'abord), récompense.
## LECTURE SEULE de scripts/quetes.gd (donnees, etat, en_cours) : aucune règle, rien n'est modifié.
## Commandes : haut / bas (flèches, Z S, croix, stick, molette sur la page gauche) ; molette sur la page droite ou
## Page préc. / Page suiv. = faire défiler le journal ; clic = choisir.

const LIGNE := 18.0
const Y_LISTE := 64.0
const Y_FIN := 326.0

var quetes: Node = null           ## scripts/quetes.gd ; posé par la coquille, sinon retrouvé (monde.quetes / hud.quetes)
var choix := ""                   ## id de la quête choisie
var defilement := 0               ## lignes de journal sautées (page droite)
var _lignes: Array = []           ## [[type, id_ou_titre, y]] : « titre » (rubrique) ou « quete »
var _police: FontFile
var _gothique: FontFile

func id_onglet() -> String:
	return "quetes"

func titre() -> String:
	return "Quêtes"

func aide() -> Array:
	return [["Haut / Bas", "Choisir"], ["Molette", "Journal"]]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _trouver_quetes() -> Node:
	if quetes != null and is_instance_valid(quetes):
		return quetes
	var n: Node = joueur
	while n != null:
		var q = n.get("quetes")
		if q is Node:
			return q
		var h = n.get("hud")
		if h is Node and h.get("quetes") is Node:
			return h.get("quetes")
		n = n.get_parent()
	return null

## Quêtes commencées : [[id, quête (Dictionary), terminée]] ; en cours d'abord, puis terminées (ordre de data/quetes.json).
func liste() -> Array:
	var q := _trouver_quetes()
	if q == null:
		return []
	var cours: Array = []
	var finies: Array = []
	for f: Dictionary in q.donnees.get("quetes", []):
		var id := String(f["id"])
		if not q.etat.has(id):
			continue
		if q.en_cours(id):
			cours.append([id, f, false])
		else:
			finies.append([id, f, true])
	return cours + finies

func ouvrir() -> void:
	quetes = _trouver_quetes()
	if quetes != null and not quetes.change.is_connected(_rafraichir):
		quetes.change.connect(_rafraichir)
	_rafraichir()

func fermer() -> void:
	if quetes != null and is_instance_valid(quetes) and quetes.change.is_connected(_rafraichir):
		quetes.change.disconnect(_rafraichir)

func _rafraichir() -> void:
	var l := liste()
	var ids := l.map(func(e: Array) -> String: return e[0])
	if not choix in ids:
		choix = ids[0] if not ids.is_empty() else ""
		defilement = 0
	queue_redraw()

func _ids() -> Array:
	return liste().map(func(e: Array) -> String: return e[0])

func deplacer(d: int) -> void:
	var ids := _ids()
	if ids.is_empty():
		return
	var i := clampi(ids.find(choix) + d, 0, ids.size() - 1)
	if ids[i] != choix:
		choix = ids[i]
		defilement = 0
	queue_redraw()

func entree(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		var p: Vector2 = make_input_local(e).position - Parchemin.origine(size)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var d := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if p.x > 320.0:
				defilement = maxi(0, defilement + d)
				queue_redraw()
			else:
				deplacer(d)
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var id := _sous(p)
			if id != "":
				choix = id
				defilement = 0
				queue_redraw()
				return true
		return false
	if e is InputEventMouseMotion:
		return false
	if e is InputEventKey and e.pressed:
		var k := e as InputEventKey
		if k.physical_keycode == KEY_W:
			deplacer(-1)
			return true
		if k.physical_keycode == KEY_S:
			deplacer(1)
			return true
		if k.keycode == KEY_PAGEDOWN or k.keycode == KEY_PAGEUP:
			defilement = maxi(0, defilement + (3 if k.keycode == KEY_PAGEDOWN else -3))
			queue_redraw()
			return true
	if e.is_action_pressed("ui_up", true):
		deplacer(-1)
		return true
	if e.is_action_pressed("ui_down", true):
		deplacer(1)
		return true
	return false

func _sous(p: Vector2) -> String:
	for l: Array in _lignes:
		if l[0] == "quete" and Rect2(18, float(l[2]), 296, LIGNE).has_point(p):
			return String(l[1])
	return ""

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	draw_set_transform(Parchemin.origine(size))
	Parchemin.titre(self, _gothique, _police, Vector2(20, 30), "Quêtes")
	var l := liste()
	_lignes = []
	if l.is_empty():
		Parchemin.texte(self, _police, Vector2(20, 70), "Aucune quête pour l'instant.", Parchemin.PALE)
		Parchemin.texte(self, _police, Vector2(20, 82), "Parle aux gens du hameau.", Parchemin.PALE)
		draw_set_transform(Vector2.ZERO)
		return
	var cours := l.filter(func(e: Array) -> bool: return not e[2])
	var finies := l.filter(func(e: Array) -> bool: return e[2])
	# entrées (en cours, terminées) puis défilement pour garder la quête choisie visible
	var entrees: Array = []
	for groupe: Array in [["En cours", cours], ["Terminées", finies]]:
		if groupe[1].is_empty():
			continue
		entrees.append(["titre", groupe[0], groupe[1].size()])
		for e: Array in groupe[1]:
			entrees.append(["quete", e[0], e])
	var places := int((Y_FIN - Y_LISTE) / LIGNE)
	var i_sel := 0
	for i in entrees.size():
		if entrees[i][0] == "quete" and entrees[i][1] == choix:
			i_sel = i
	var debut := clampi(i_sel - places + 2, 0, maxi(0, entrees.size() - places))
	var y := Y_LISTE
	for i in range(debut, mini(entrees.size(), debut + places)):
		var en: Array = entrees[i]
		if en[0] == "titre":
			if i != debut:
				y += 4.0
			Parchemin.texte(self, _police, Vector2(20, y), en[1], Parchemin.RUBRIQUE)
			Parchemin.texte_droite(self, _police, 312, y, str(en[2]), Parchemin.PALE)
			Parchemin.regle(self, 18, y + 13, 296)
			y += 16.0
			continue
		var e: Array = en[2]
		var f: Dictionary = e[1]
		_lignes.append(["quete", e[0], y])
		if e[0] == choix:
			Parchemin.ligne_choisie(self, Rect2(18, y, 296, LIGNE - 1))
		if e[2]:
			_coche(Vector2(24, y + 5))
		else:
			_losange(Vector2(26, y + 8))
		Parchemin.texte(self, _police, Vector2(36, y + 3), String(f["titre"]), Parchemin.ENCRE if not e[2] else Parchemin.PALE)
		if not e[2]:
			Parchemin.texte_droite(self, _police, 310, y + 3, "%d/%d" % [int(quetes.etat[e[0]]), f["etapes"].size()], Parchemin.PALE)
		Parchemin.regle(self, 18, y + LIGNE - 1, 296)
		y += LIGNE
	if debut + places < entrees.size():
		Parchemin.texte(self, _police, Vector2(150, Y_FIN - 2), "...", Parchemin.PALE)
	_fiche()
	draw_set_transform(Vector2.ZERO)

## Losange vermillon (quête en cours).
func _losange(c: Vector2) -> void:
	for dy in range(-3, 4):
		var w := 3 - absi(dy)
		draw_rect(Rect2(c.x - w, c.y + dy, w * 2 + 1, 1), Parchemin.RUBRIQUE)
	draw_rect(Rect2(c.x, c.y - 2, 1, 1), Parchemin.RUBRIQUE_VIVE)

## Coche à l'encre (quête terminée, étape faite).
func _coche(p: Vector2) -> void:
	for d: Vector2i in [Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 3), Vector2i(5, 2), Vector2i(6, 1), Vector2i(7, 0)]:
		draw_rect(Rect2(p + Vector2(d), Vector2(1, 2)), Parchemin.ENCRE)

## « Jour 3, 21h30 » (vide pour une entrée non datée : partie d'avant le journal daté).
static func date_texte(jour: int, heure: float) -> String:
	return "" if jour <= 0 else "Jour %d, %02dh%02d" % [jour, int(heure), int(fmod(heure, 1.0) * 60.0)]

## Page droite : la quête choisie.
func _fiche() -> void:
	var q := _trouver_quetes()
	var f: Dictionary = {}
	for x: Dictionary in q.donnees.get("quetes", []):
		if x["id"] == choix:
			f = x
	if f.is_empty():
		return
	var X := 336.0
	var etapes: Array = f["etapes"]
	var n := int(q.etat.get(choix, 0))
	var finie := n >= etapes.size()
	var titre_l := Parchemin.couper(_gothique, String(f["titre"]), 282, Parchemin.TITRE)
	draw_string(_gothique, Vector2(X, 49), titre_l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Parchemin.RUBRIQUE)
	Parchemin.texte(self, _police, Vector2(X, 60), ("Terminée · %d étapes" % etapes.size()) if finie else ("En cours · étape %d sur %d" % [n, etapes.size()]), Parchemin.PALE)
	Parchemin.filet(self, X + 8, 78, 266)
	var y := 86.0
	if not finie and n > 0:
		Parchemin.texte(self, _police, Vector2(X, y), "Objectif", Parchemin.RUBRIQUE)
		y += 13.0
		for l in Parchemin.couper(_police, String(etapes[n - 1].get("objectif", "")), 280):
			Parchemin.texte(self, _police, Vector2(X, y), l, Parchemin.ENCRE)
			y += 10.0
		y += 6.0
	Parchemin.texte(self, _police, Vector2(X, y), "Journal", Parchemin.RUBRIQUE)
	y += 14.0
	# journal : la plus récente d'abord, coupé en lignes ; défilement par lignes
	var rendu: Array = []    # [texte, première ligne de l'entrée, date ?]
	var ecrites: Array = q.entrees(choix)
	ecrites.reverse()
	for e: Dictionary in ecrites:
		var date: String = date_texte(int(e["jour"]), float(e["heure"]))
		if date != "":
			rendu.append([date, false, true])
		var lignes := Parchemin.couper(_police, String(e["texte"]), 266)
		for j in lignes.size():
			rendu.append([lignes[j], j == 0 and date == "", false])
		rendu.append(["", false, false])
	var bas := 302.0
	var places := int((bas - y) / 10.0)
	defilement = clampi(defilement, 0, maxi(0, rendu.size() - places))
	for k in range(defilement, mini(rendu.size(), defilement + places)):
		var r: Array = rendu[k]
		if r[1] or r[2]:
			_coche(Vector2(X, y + 2))
		if r[0] != "":
			Parchemin.texte(self, _police, Vector2(X + 12, y), r[0], Parchemin.OR_TERNI if r[2] else Parchemin.ENCRE)
		y += 10.0 if r[0] != "" else 4.0
	if defilement + places < rendu.size():
		Parchemin.texte_droite(self, _police, 618, bas, "suite (molette)", Parchemin.PALE)
	var rec: Dictionary = f.get("recompense", {})
	var parts := ["%d XP" % int(rec.get("xp", Progression.XP_QUETE_DEFAUT))]
	if int(rec.get("pieces", 0)) > 0:
		parts.append("%d pièces" % int(rec["pieces"]))
	for id in rec.get("objets", {}):
		parts.append(Inventaire.objet(String(id)).get("nom", String(id)))
	Parchemin.texte(self, _police, Vector2(X, 314), ("Reçu : " if finie else "Récompense : ") + " · ".join(parts), Parchemin.OR_TERNI)
