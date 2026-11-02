class_name OngletMagie
extends OngletLivre
## Onglet MAGIE du codex (lot C). Page de gauche : le grimoire, sorts connus (EquipementMains.objets_possedes("sorts"), triés
## par école) avec leur coût et les marques D / G des mains qui les tiennent. Page de droite : fiche du sort (école, type,
## coût, dégâts, effet, recharge…), ce que donnerait chaque main (ou la raison du refus, avant d'essayer), les deux mains
## actuelles et la rangée des raccourcis 1-0.
## Touches : haut / bas = sort ; E / Entrée / A / clic = main droite ; G / X / clic droit = main gauche ; 1-0 = ranger les deux
## mains actuelles dans ce raccourci ; clic sur une case = idem, clic droit = la vider.

var choisi := ""
var sorts: Array[String] = []
var _sel := 0
var _haut := 0
var _rangs := 12
## Lignes du grimoire : ["ecole", nom] ou ["sort", id, index dans `sorts`].
var _lignes: Array = []

func id_onglet() -> String:
	return "magie"

func titre() -> String:
	return "Magie"

func _c() -> InventaireMains:
	return coquille as InventaireMains

func _eq() -> EquipementMains:
	return _c()._eq() if _c() != null else null

func ouvrir() -> void:
	relire()

func relire() -> void:
	var eq := _eq()
	sorts = eq.objets_possedes("sorts") if eq != null else ([] as Array[String])
	_lignes = []
	var ecole := ""
	for i in sorts.size():
		var s := eq.sort_par_id(sorts[i])
		var e := s.ecole if s != null else ""
		if e != ecole:
			ecole = e
			_lignes.append(["ecole", String(EquipementMains.NOMS_ECOLES.get(e, e))])
		_lignes.append(["sort", sorts[i], i])
	var i0 := sorts.find(choisi)
	_sel = clampi(i0 if i0 >= 0 else _sel, 0, maxi(0, sorts.size() - 1))
	choisi = sorts[_sel] if not sorts.is_empty() else ""
	queue_redraw()
	contenu_change.emit()

func choisir(id: String) -> void:
	var i := sorts.find(id)
	if i >= 0:
		_sel = i
		choisi = id
	queue_redraw()

func _ligne_de(i_sort: int) -> int:
	for k in _lignes.size():
		if _lignes[k][0] == "sort" and int(_lignes[k][2]) == i_sort:
			return k
	return 0

func _visible_sel() -> void:
	var l := _ligne_de(_sel)
	if l - 1 < _haut:
		_haut = maxi(0, l - 1)
	elif l >= _haut + _rangs:
		_haut = l - _rangs + 1
	_haut = clampi(_haut, 0, maxi(0, _lignes.size() - _rangs))

func entree(e: InputEvent) -> bool:
	if _c() == null:
		return false
	var d := direction(e)
	if (d == -1 or d == 1) and not sorts.is_empty():
		_sel = clampi(_sel + d, 0, sorts.size() - 1)
		choisi = sorts[_sel]
		_visible_sel()
		Sons.jouer(self, ["cloth1"], -24.0)
		return true
	var k := touche(e)
	var b := bouton(e)
	if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER] or b == JOY_BUTTON_A:
		_c().equiper("droite", choisi)
		return true
	if k == KEY_G or b == JOY_BUTTON_X:
		_c().equiper("gauche", choisi)
		return true
	var c := chiffre(e)
	if c >= 0:
		_c().memoriser(c)
		return true
	return false

func aide() -> Array:
	return [["E", "Main droite"], ["G", "Main gauche"], ["1-0", "Raccourci"]]

func survoler(action: String, valeur: Variant) -> void:
	if action == "sort":
		_sel = int(valeur)
		choisi = sorts[_sel]
		contenu_change.emit()

func cliquer(action: String, valeur: Variant, b: int) -> void:
	match action:
		"sort":
			survoler(action, valeur)
			_c().equiper("gauche" if b == MOUSE_BUTTON_RIGHT else "droite", choisi)
		"case":
			if b == MOUSE_BUTTON_RIGHT:
				_c().vider_raccourci(int(valeur))
			else:
				_c().memoriser(int(valeur))

func defiler(sens: int, _pos: Vector2) -> bool:
	if _lignes.size() <= _rangs:
		return false
	_haut = clampi(_haut + sens, 0, _lignes.size() - _rangs)
	return true

func _draw() -> void:
	if joueur == null or _eq() == null:
		return
	_zones.clear()
	var eq := _eq()
	var r := rects()
	var g: Rect2 = r["gauche"]
	var d: Rect2 = r["droite"]
	Parchemin.titre(self, _gothique, _police, Vector2(g.position.x, g.position.y), "Grimoire")
	texte(g.end.x, g.position.y + 9.0, "%d sorts connus" % sorts.size(), Parchemin.PALE, true)
	var x := g.position.x
	var w := g.size.x
	var y0 := g.position.y + 40.0
	texte(x + 20.0, y0 - 10.0, "Sort", Parchemin.RUBRIQUE)
	texte(x + w, y0 - 10.0, "Coût", Parchemin.RUBRIQUE, true)
	Parchemin.regle(self, x, y0, w)
	_rangs = maxi(1, int((g.end.y - 4.0 - (y0 + 3.0)) / H_LIGNE))
	_visible_sel()
	for k in range(_haut, mini(_lignes.size(), _haut + _rangs)):
		var l: Array = _lignes[k]
		var ly := y0 + 3.0 + (k - _haut) * H_LIGNE
		if l[0] == "ecole":
			texte(x + 2.0, ly + 5.0, String(l[1]), Parchemin.RUBRIQUE)
			Parchemin.filet(self, x + largeur(String(l[1])) + 14.0, ly + 9.0, w - largeur(String(l[1])) - 22.0)
			continue
		var id := String(l[1])
		var i := int(l[2])
		var rl := Rect2(x, ly, w, H_LIGNE - 1.0)
		if i == _sel:
			Parchemin.ligne_choisie(self, rl)
		zone(rl, "sort", i)
		icone(MenuStyle.icone_objet(id), Vector2(x + 1, ly + 1))
		var m := "D" if _c().tenu("droite") == id else ("G" if _c().tenu("gauche") == id else "")
		if m != "":
			MenuStyle.marque(self, _police, x + 9.0, ly + 8.0, m)
		if _c().tenu("droite") == id and _c().tenu("gauche") == id:
			MenuStyle.marque(self, _police, x - 1.0, ly + 8.0, "G")
		var s := eq.sort_par_id(id)
		texte(x + 21.0, ly + 4.0, s.nom if s != null else id, Parchemin.ENCRE, false, w - 70.0)
		if s != null:
			texte(x + w, ly + 4.0, ("%d/s" % roundi(s.cout_par_seconde)) if s.canalise() else str(roundi(s.cout)), Parchemin.MAGIE, true)
		Parchemin.regle(self, x, ly + H_LIGNE - 1.0, w)
	_dessiner_fiche(d)

func _dessiner_fiche(d: Rect2) -> void:
	var eq := _eq()
	var x := d.position.x
	var y := d.position.y
	if choisi != "":
		var f := eq.fiche(choisi)
		MenuStyle.cadre_icone(self, Rect2(x, y + 2, 40, 40))
		icone(MenuStyle.icone_objet(choisi), Vector2(x + 4, y + 6), 2)
		titre_fiche(x + 46.0, y, String(f["nom"]), d.size.x - 46.0, Parchemin.ENCRE)
		var rub := OngletLivre.lignes_rubriques(f["lignes"])
		var notes: Array = []
		if not rub.is_empty():
			texte(x + 46.0, y + 23.0, String(rub[0][0]), Parchemin.PALE, false, d.size.x - 46.0)
		texte(x + 46.0, y + 34.0, "École : %s" % EquipementMains.NOMS_ECOLES.get(String(f["ecole"]), String(f["ecole"])), IconesCombat.accent(String(f["ecole"])).darkened(0.45))
		y += 50.0
		Parchemin.filet(self, x + 8.0, y, d.size.x - 16.0)
		y += 6.0
		for i in range(1, rub.size()):
			if rub[i][1] == "":
				notes.append(rub[i][0])
				continue
			texte(x, y, String(rub[i][0]), Parchemin.RUBRIQUE)
			texte(x + 74.0, y, String(rub[i][1]), Parchemin.ENCRE, false, d.size.x - 74.0)
			Parchemin.regle(self, x, y + 10.0, d.size.x)
			y += 12.0
		y += 2.0
		var vues := {}
		for n: String in notes:   # une note par ligne, sans doublon (la description répète parfois la ligne de charge)
			var cle := n.substr(0, 18)
			if vues.has(cle) or y > d.end.y - 100.0:
				continue
			vues[cle] = true
			y = paragraphe(x, y, d.size.x, n, Parchemin.PALE, 2)
		y += 4.0
		for m in ["droite", "gauche"]:
			var e := eq.essai(m, choisi)
			var etat: String
			var col := Parchemin.ENCRE
			if _c().tenu(m) == choisi:
				etat = "en main"
				col = Parchemin.VIGUEUR
			elif String(e["refus"]) != "":
				etat = String(e["refus"])
				col = Parchemin.RUBRIQUE
			else:
				etat = "équiper (%s)" % ("E" if m == "droite" else "G") + ("" if String(e["effet"]) == "" else " : " + String(e["effet"]).trim_suffix("."))
			var lm := texte(x, y, "Main %s" % m, Parchemin.RUBRIQUE)
			texte(x + lm + 6.0, y, etat, col, false, d.size.x - lm - 6.0)
			y += 11.0
	# mains actuelles + raccourcis (bas de page)
	var yb := d.end.y - 70.0
	Parchemin.filet(self, x + 8.0, yb, d.size.x - 16.0)
	yb += 6.0
	var demi := floorf(d.size.x * 0.5)
	for k in 2:
		var m := "gauche" if k == 0 else "droite"
		var bx := x + k * demi
		var id := _c().tenu(m)
		icone(MenuStyle.icone_objet(id, id == "vide"), Vector2(bx, yb))
		texte(bx + 19.0, yb + 4.0, String(eq.fiche(id)["nom"]) if id != "vide" else "main nue", Parchemin.ENCRE if id != "vide" else Parchemin.PALE, false, demi - 22.0)
	yb += 20.0
	texte(x, yb, "Raccourcis", Parchemin.RUBRIQUE)
	texte(d.end.x, yb, "1-0 : y ranger les deux mains", Parchemin.PALE, true)
	yb += 11.0
	var lc := floorf((d.size.x - 9.0 * 2.0) / 10.0)
	var g := _c().tenu("gauche")
	var dr := _c().tenu("droite")
	for i in 10:
		var rc := Rect2(x + i * (lc + 2.0), yb, lc, 20)
		var ent: Dictionary = eq.raccourcis[i] if i < eq.raccourcis.size() else {}
		var vide := not ent.has("gauche") and not ent.has("droite") and not ent.has("conso")
		var actif := not vide and String(ent.get("gauche", "")) == g and String(ent.get("droite", "")) == dr
		MenuStyle.vignette(self, rc, actif, vide)
		zone(rc, "case", i)
		if ent.has("conso"):
			icone(MenuStyle.icone_objet(String(ent["conso"])), Vector2(rc.position.x + floorf((lc - 16.0) * 0.5), yb + 2))
		elif not vide:
			var gi := String(ent.get("gauche", "vide"))
			var di := String(ent.get("droite", "vide"))
			# deux demi-icônes : main gauche (moitié gauche), main droite (moitié droite)
			var t1 := MenuStyle.icone_objet(gi, gi == "vide")
			var t2 := MenuStyle.icone_objet(di, di == "vide")
			var cxr := rc.position.x + floorf(lc * 0.5)
			draw_texture_rect_region(t1, Rect2(cxr - 8.0, yb + 2.0, 8, 16), Rect2(4, 0, 8, 16))
			draw_texture_rect_region(t2, Rect2(cxr, yb + 2.0, 8, 16), Rect2(4, 0, 8, 16))
		texte(rc.get_center().x - largeur(str((i + 1) % 10)) * 0.5, yb + 21.0, str((i + 1) % 10), Parchemin.RUBRIQUE if actif else Parchemin.PALE)
