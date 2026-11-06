class_name OngletFactions
extends OngletMenu
## Onglet « Factions » (style A parchemin) : page gauche = les factions humaines jouables (rang, réputation) ; page droite = la
## faction choisie : chef, compétences, échelle des rangs (réputation et compétences requises, avantage du rang), ce qui manque
## pour le rang suivant et le délai de promotion.
## LECTURE SEULE de scripts/rangs.gd (Rangs.courant) : aucune règle ici. Adhésion et promotion se demandent au chef (dialogue).
## Commandes : haut / bas (flèches, Z S, croix, stick, molette) ; clic = choisir.

const LIGNE := 40.0
const Y_LISTE := 64.0

var choix := ""                   ## id de la faction choisie
var _police: FontFile
var _gothique: FontFile

func id_onglet() -> String:
	return "factions"

func titre() -> String:
	return "Factions"

func aide() -> Array:
	return [["Haut / Bas", "Choisir"]]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _rangs() -> Rangs:
	return Rangs.courant if Rangs.courant != null and is_instance_valid(Rangs.courant) else null

func ouvrir() -> void:
	var rg := _rangs()
	if rg != null and not choix in rg.factions():
		choix = String(rg.factions()[0]) if not rg.factions().is_empty() else ""
	queue_redraw()

func deplacer(d: int) -> void:
	var rg := _rangs()
	if rg == null:
		return
	var ids := rg.factions()
	choix = String(ids[clampi(ids.find(choix) + d, 0, ids.size() - 1)])
	queue_redraw()

func entree(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			deplacer(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var rg := _rangs()
			var p: Vector2 = make_input_local(e).position - Parchemin.origine(size)
			if rg != null:
				for i in rg.factions().size():
					if Rect2(18, Y_LISTE + i * LIGNE, 296, LIGNE - 2).has_point(p):
						choix = String(rg.factions()[i])
						queue_redraw()
						return true
		return false
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.physical_keycode == KEY_W:
			deplacer(-1)
			return true
		if k.physical_keycode == KEY_S:
			deplacer(1)
			return true
	if e.is_action_pressed("ui_up", true):
		deplacer(-1)
		return true
	if e.is_action_pressed("ui_down", true):
		deplacer(1)
		return true
	return false

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	draw_set_transform(Parchemin.origine(size))
	Parchemin.titre(self, _gothique, _police, Vector2(20, 30), "Factions")
	var rg := _rangs()
	if rg == null or rg.factions().is_empty():
		Parchemin.texte(self, _police, Vector2(20, 70), "Aucune faction connue.", Parchemin.PALE)
		draw_set_transform(Vector2.ZERO)
		return
	if not choix in rg.factions():
		choix = String(rg.factions()[0])
	for i in rg.factions().size():
		_ligne(rg, String(rg.factions()[i]), Y_LISTE + i * LIGNE)
	Parchemin.texte(self, _police, Vector2(20, 294), "Parle au chef d'une faction pour la rejoindre", Parchemin.PALE)
	Parchemin.texte(self, _police, Vector2(20, 304), "ou demander une promotion (une par semaine).", Parchemin.PALE)
	_fiche(rg)
	draw_set_transform(Vector2.ZERO)

func _ligne(rg: Rangs, f: String, y: float) -> void:
	if f == choix:
		Parchemin.ligne_choisie(self, Rect2(18, y, 296, LIGNE - 3))
	var r := rg.rang(f)
	Parchemin.texte(self, _police, Vector2(24, y + 4), rg.nom(f), Parchemin.ENCRE)
	Parchemin.texte_droite(self, _police, 308, y + 4, rg.nom_rang(f, r), Parchemin.RUBRIQUE if r >= 0 else Parchemin.PALE)
	var rep := rg.reputation(f)
	Parchemin.texte(self, _police, Vector2(24, y + 18), "Réputation", Parchemin.PALE)
	Parchemin.barre(self, Rect2(96, y + 21, 170, 5), clampf(rep / Rangs.REP_MAX, 0.0, 1.0), Parchemin.OR_TERNI if rep >= 0.0 else Parchemin.RUBRIQUE)
	Parchemin.texte_droite(self, _police, 308, y + 18, str(roundi(rep)), Parchemin.RUBRIQUE if rep < 0.0 else Parchemin.ENCRE)
	Parchemin.regle(self, 18, y + LIGNE - 3, 296)

func _fiche(rg: Rangs) -> void:
	var f := choix
	var X := 336.0
	var D := 618.0
	var r := rg.rang(f)
	var fi := rg.fiche(f)
	var tl := Parchemin.couper(_gothique, rg.nom(f), 282, Parchemin.TITRE)
	draw_string(_gothique, Vector2(X, 49), tl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, Parchemin.TITRE, Parchemin.RUBRIQUE)
	Parchemin.texte(self, _police, Vector2(X, 60), "Chef : %s · %s" % [fi.get("chef_nom", "?"), fi.get("lieu", "")], Parchemin.PALE)
	Parchemin.filet(self, X + 8, 78, 266)
	# compétences de la faction
	var cs := rg.competences(f)
	var x := X
	Parchemin.texte(self, _police, Vector2(X, 84), "Compétences", Parchemin.RUBRIQUE)
	x = X + 76.0
	for c: Array in cs:
		var s := "%s %d" % [Parchemin.nom_competence(String(c[0])), int(c[1])]
		Parchemin.texte(self, _police, Vector2(x, 84), s, Parchemin.ENCRE)
		x += Parchemin.largeur(_police, s) + 12.0
	# échelle des rangs
	var y := 100.0
	Parchemin.texte(self, _police, Vector2(X, y), "Rangs", Parchemin.RUBRIQUE)
	Parchemin.texte_droite(self, _police, D, y, "réput. · compét.", Parchemin.PALE)
	y += 17.0
	for i in rg.nb_rangs(f):
		var actuel := i == r
		if actuel:
			Parchemin.ligne_choisie(self, Rect2(X - 4, y - 2, D - X + 8, 26))
		var texte_rang := ("%s" % rg.nom_rang(f, i))
		Parchemin.texte(self, _police, Vector2(X + 4, y), texte_rang, Parchemin.RUBRIQUE if actuel else (Parchemin.ENCRE if i <= r else Parchemin.PALE))
		Parchemin.texte_droite(self, _police, D, y, "%d · %d/%d" % [roundi(rg.rep_min(f, i)), rg.skill_haut(f, i), rg.skill_bas(f, i)], Parchemin.ENCRE if i <= r else Parchemin.PALE)
		var av := String((fi["rangs"][i] as Dictionary).get("texte", ""))
		var l := Parchemin.couper(_police, av, 270)
		Parchemin.texte(self, _police, Vector2(X + 4, y + 11), l[0] if not l.is_empty() else "", (Parchemin.ENCRE if actuel else Parchemin.OR_TERNI) if i <= r else Parchemin.PALE)
		y += 27.0
	# prochain rang
	y = maxf(y, 268.0) + 2.0
	Parchemin.filet(self, X + 8, y - 4, 266)
	if r < 0:
		var m := rg.manque(f, 0)
		_texte_long("Non membre. " + ("Pour entrer : il te faut %s." % " et ".join(m) if not m.is_empty() else "Parle à %s pour entrer." % fi.get("chef_nom", "son chef")), X, y + 2)
	elif r >= rg.nb_rangs(f) - 1:
		_texte_long("Rang le plus haut atteint.", X, y + 2)
	else:
		var m := rg.manque(f, r + 1)
		var txt := "Prochain rang, %s : " % rg.nom_rang(f, r + 1)
		txt += "il te faut %s." % " et ".join(m) if not m.is_empty() else "mérité, parle à %s." % fi.get("chef_nom", "son chef")
		var dj := rg.delai_restant(f)
		if dj > 0.0:
			txt += " Délai : %d jour(s)." % ceili(dj)
		_texte_long(txt, X, y + 2)

func _texte_long(s: String, x: float, y: float) -> void:
	var l := Parchemin.couper(_police, s, 282)
	for j in mini(l.size(), 4):
		Parchemin.texte(self, _police, Vector2(x, y + j * 10), l[j], Parchemin.ENCRE)
