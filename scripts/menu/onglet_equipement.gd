class_name OngletEquipement
extends OngletLivre
## Onglet ÉQUIPEMENT du codex (lot C ; maquette A_parchemin/1_equipement.html). Page de gauche : le héros dans une arche
## enluminée, ses 6 emplacements de corps (EquipementCorps : tête, torse, mains / amulette, anneau, pieds) et ses deux mains
## (EquipementMains, lu sans être modifié : les mains s'équipent par InventaireMains.equiper → MainSort.equiper). Page de
## droite : le registre (niveau, vie, vigueur, magie, armure, dégâts, poids, pièces, résistances) puis la fiche de
## l'emplacement choisi ; « Changer » y ouvre la liste des objets possibles avec la comparaison (armure, dégâts).
## Touches : flèches / croix = emplacement ; E / Entrée / A / clic = changer ; R / Y / clic droit = retirer ; dans la liste :
## haut / bas, E = équiper, Échap / B = annuler.

const HEROS := preload("res://assets/ui/menu_heros.png")
## [id, libellé] ; colonne de gauche puis de droite (4 rangs chacune), comme la maquette.
const EMPLACEMENTS := [["tete", "Tête"], ["torse", "Torse"], ["mains", "Mains"], ["droite", "Main droite"],
	["cou", "Amulette"], ["anneau", "Anneau"], ["pieds", "Pieds"], ["gauche", "Main gauche"]]
const NOMS_EMP := {"tete": "tête", "torse": "torse", "mains": "mains", "pieds": "pieds", "cou": "cou", "anneau": "anneau"}

var sel := 3   # main droite (comme la maquette)
## Liste « Changer » ouverte : candidats [{id, nom, delta, couleur}] ; vide = fermée.
var choix: Array = []
var choix_sel := 0
var _choix_haut := 0
var _choix_rangs := 6
var _arche: ImageTexture

func id_onglet() -> String:
	return "equipement"

func titre() -> String:
	return "Équipement"

func _c() -> InventaireMains:
	return coquille as InventaireMains

func _eq() -> EquipementMains:
	return _c()._eq() if _c() != null else null

func ouvrir() -> void:
	choix = []
	if _arche == null:
		_arche = ImageTexture.create_from_image(MenuStyle.image_arche(84, 216))
	queue_redraw()

func fermer() -> void:
	choix = []

func relire() -> void:
	if not choix.is_empty():
		_ouvrir_choix()
	queue_redraw()
	contenu_change.emit()

## Identifiant de l'emplacement choisi (tete… ou droite / gauche).
func emplacement() -> String:
	return String(EMPLACEMENTS[sel][0])

func est_main(emp: String) -> bool:
	return emp == "droite" or emp == "gauche"

## Ce qui occupe un emplacement ("" = vide ; « vide » n'est jamais rendu pour une main).
func objet_de(emp: String) -> String:
	if est_main(emp):
		var t := _c().tenu(emp) if _c() != null else "vide"
		return "" if t == "vide" else t
	return joueur.equipement_corps.objet_a(emp)

# ------------------------------------------------------------------ liste « Changer »

## Candidats de l'emplacement choisi : objets du sac qui s'y portent, ou ce qui se tient dans cette main.
func candidats(emp: String) -> Array:
	var res: Array = []
	if est_main(emp):
		var eq := _eq()
		if eq == null:
			return res
		var liste: Array[String] = eq.objets_possedes("armes")
		liste.append_array(eq.objets_possedes("sorts"))
		for id in liste:
			if String(eq.essai(emp, id)["refus"]) != "" or (id == "epee" and liste.has("epee_skarnholt") and eq.objet("epee") == eq.objet("epee_skarnholt")):
				continue
			var d := _delta_main(emp, id)
			res.append({"id": id, "nom": String(eq.fiche(id)["nom"]), "delta": d[0], "couleur": d[1]})
	else:
		res.append({"id": "", "nom": "(rien)", "delta": "", "couleur": Parchemin.PALE})
		var inv: Inventaire = joueur.inventaire
		for id: String in inv.objets:
			if Inventaire.emplacement_de(id) == emp:
				var da := roundi(float(Inventaire.objet(id).get("armure", 0.0)) - float(Inventaire.objet(objet_de(emp)).get("armure", 0.0)))
				res.append({"id": id, "nom": String(Inventaire.objet(id).get("nom", id)), "delta": "armure %+d" % da if da != 0 else "",
					"couleur": Parchemin.VIGUEUR if da > 0 else Parchemin.RUBRIQUE})
	return res

func _delta_main(emp: String, id: String) -> Array:
	var eq := _eq()
	var a := eq.objet(id) as DonneesArme
	var b := eq.arme(emp)
	if a == null or b == null or not EquipementMains.categorie_de(a).begins_with("arme") or not eq.categorie(emp).begins_with("arme"):
		return ["", Parchemin.PALE]
	var dl := roundi(a.degats_leger - b.degats_leger)
	var dg := roundi(a.degats_lourd - b.degats_lourd)
	if dl == 0 and dg == 0:
		return ["", Parchemin.PALE]
	return ["%+d / %+d" % [dl, dg], Parchemin.VIGUEUR if dl + dg > 0 else Parchemin.RUBRIQUE]

func _ouvrir_choix() -> void:
	var garde := String(choix[choix_sel]["id"]) if not choix.is_empty() and choix_sel < choix.size() else objet_de(emplacement())
	choix = candidats(emplacement())
	choix_sel = 0
	for i in choix.size():
		if choix[i]["id"] == garde:
			choix_sel = i
	_choix_haut = clampi(choix_sel - 2, 0, maxi(0, choix.size() - _choix_rangs))
	if choix.size() <= (0 if est_main(emplacement()) else 1):
		choix = []
		message.emit("!Rien à porter ici : aucun objet du sac ne va à cet emplacement (%s)." % NOMS_EMP.get(emplacement(), emplacement()))

## Équipe le candidat i de la liste ouverte.
func valider_choix(i: int) -> String:
	if i < 0 or i >= choix.size():
		return ""
	var id := String(choix[i]["id"])
	var emp := emplacement()
	choix = []
	if est_main(emp):
		return _c().equiper(emp, id) if id != "vide" else _c().retirer_main(emp)
	if id == "":
		return _c().retirer_corps(emp) if objet_de(emp) != "" else ""
	return _c().porter(id)

## Retire ce qui occupe l'emplacement choisi.
func retirer() -> String:
	var emp := emplacement()
	if objet_de(emp) == "":
		return _c().dire("Rien à retirer ici.", true)
	return _c().retirer_main(emp) if est_main(emp) else _c().retirer_corps(emp)

# ------------------------------------------------------------------ entrées

func entree(e: InputEvent) -> bool:
	if _c() == null:
		return false
	var d := direction(e)
	var k := touche(e)
	var b := bouton(e)
	if not choix.is_empty():
		if d == -1 or d == 1:
			choix_sel = clampi(choix_sel + d, 0, choix.size() - 1)
			if choix_sel < _choix_haut:
				_choix_haut = choix_sel
			elif choix_sel >= _choix_haut + _choix_rangs:
				_choix_haut = choix_sel - _choix_rangs + 1
			return true
		if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER] or b == JOY_BUTTON_A:
			valider_choix(choix_sel)
			return true
		if k in [KEY_ESCAPE, KEY_BACKSPACE] or b == JOY_BUTTON_B or d == -2 or d == 2:
			choix = []
			return true
		return k != KEY_TAB and b != JOY_BUTTON_LEFT_SHOULDER and b != JOY_BUTTON_RIGHT_SHOULDER and k != KEY_NONE
	if d != 0:
		var col := sel / 4
		var rang := sel % 4
		if d == -1 or d == 1:
			rang = (rang + d + 4) % 4
		else:
			col = 1 - col
		sel = col * 4 + rang
		Sons.jouer(self, ["cloth1"], -24.0)
		return true
	if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER] or b == JOY_BUTTON_A:
		_ouvrir_choix()
		return true
	if k == KEY_R or b == JOY_BUTTON_Y:
		retirer()
		return true
	return false

func aide() -> Array:
	if not choix.is_empty():
		return [["E", "Équiper"], ["Échap", "Annuler"]]
	return [["E", "Changer"], ["R", "Retirer"]]

func survoler(action: String, valeur: Variant) -> void:
	if action == "emp" and choix.is_empty():
		sel = int(valeur)
		contenu_change.emit()
	elif action == "choix":
		choix_sel = int(valeur)

func cliquer(action: String, valeur: Variant, b: int) -> void:
	match action:
		"emp":
			if not choix.is_empty() and sel == int(valeur) and b == MOUSE_BUTTON_LEFT:
				choix = []
				return
			sel = int(valeur)
			choix = []
			if b == MOUSE_BUTTON_RIGHT:
				retirer()
			else:
				_ouvrir_choix()
		"choix":
			if b == MOUSE_BUTTON_RIGHT:
				choix = []
			else:
				valider_choix(int(valeur))

func defiler(sens: int, _pos: Vector2) -> bool:
	if choix.size() <= _choix_rangs:
		return false
	_choix_haut = clampi(_choix_haut + sens, 0, choix.size() - _choix_rangs)
	return true

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if joueur == null or _c() == null:
		return
	_zones.clear()
	var r := rects()
	var g: Rect2 = r["gauche"]
	var d: Rect2 = r["droite"]
	Parchemin.titre(self, _gothique, _police, Vector2(g.position.x, g.position.y), "Voyageur")
	# arche + héros (sprite 1:1, pieds sur la bande de terre)
	var cx := floorf(g.position.x + g.size.x * 0.5)
	var ay := g.position.y + 36.0
	if _arche != null:
		draw_texture(_arche, Vector2(cx - 43.0, ay))
	var bas_arche := ay + 216.0
	draw_texture(HEROS, Vector2(cx - 34.0, bas_arche - 6.0 - 160.0))
	# emplacements
	for i in EMPLACEMENTS.size():
		var emp := String(EMPLACEMENTS[i][0])
		var rs := _rect_emplacement(i, g)
		var id := objet_de(emp)
		MenuStyle.vignette(self, rs, i == sel, id == "")
		var tex: Texture2D = null
		var teinte := Color.WHITE
		if id != "":
			tex = MenuStyle.icone_objet(id)
		elif emp == "gauche" and _eq() != null and _eq().categorie("droite") == "arme_deux_mains":
			tex = MenuStyle.icone_objet(_c().tenu("droite"))
			teinte = Color(1, 1, 1, 0.4)
		elif est_main(emp):
			tex = MenuStyle.icone_objet("vide", true)
		else:
			tex = MenuStyle.icone_emplacement(emp)
		icone(tex, rs.position + Vector2(5, 5), 1, teinte)
		var lib := String(EMPLACEMENTS[i][1])
		var ll := largeur(lib)
		texte(rs.get_center().x - ll * 0.5, rs.end.y + 3.0, lib, Parchemin.RUBRIQUE)
		if i == sel:
			if i < 4:
				Parchemin.ruban(self, Rect2(rs.position.x - 17.0, rs.position.y + 9.0, 14, 8))
			else:
				Parchemin.ruban(self, Rect2(rs.end.x + 3.0, rs.position.y + 9.0, 14, 8))
		zone(Rect2(rs.position - Vector2(10, 2), rs.size + Vector2(20, 16)), "emp", i)
	_dessiner_registre(d)

func _rect_emplacement(i: int, g: Rect2) -> Rect2:
	var col := i / 4
	var rang := i % 4
	var x := g.position.x + 40.0 if col == 0 else g.end.x - 66.0
	return Rect2(x, g.position.y + 44.0 + rang * 62.0, 26, 26)

func _dessiner_registre(d: Rect2) -> void:
	var x := d.position.x
	Parchemin.titre(self, _gothique, _police, Vector2(x, d.position.y), "Registre")
	var p: Progression = joueur.progression
	var y := d.position.y + 30.0
	var bx := x + 58.0
	var bl := d.size.x - 58.0 - 56.0
	texte(x, y, "Niveau", Parchemin.RUBRIQUE)
	texte(x + 40.0, y, str(p.niveau))
	Parchemin.barre(self, Rect2(bx, y + 1, bl, 7), p.part_niveau(), Parchemin.CUIR[3])
	texte(d.end.x, y, "%d %%" % roundi(p.part_niveau() * 100.0), Parchemin.PALE, true)
	var stats := [["Vie", joueur.vie, joueur.vie_max, Parchemin.RUBRIQUE], ["Vigueur", joueur.vigueur, joueur.vigueur_max, Parchemin.VIGUEUR],
		["Magie", joueur.mana, joueur.mana_max, Parchemin.MAGIE]]
	for s: Array in stats:
		y += 13.0
		texte(x, y, String(s[0]), Parchemin.RUBRIQUE)
		Parchemin.barre(self, Rect2(bx, y + 1, bl, 7), float(s[1]) / maxf(1.0, float(s[2])), s[3])
		texte(d.end.x, y, "%d/%d" % [roundi(float(s[1])), roundi(float(s[2]))], Parchemin.ENCRE, true)
	y += 18.0
	Parchemin.filet(self, x + 8.0, y, d.size.x - 16.0)
	y += 7.0
	var ec: EquipementCorps = joueur.equipement_corps
	var inv: Inventaire = joueur.inventaire
	var x2 := x + floorf(d.size.x * 0.5)
	texte(x, y, "Armure", Parchemin.RUBRIQUE)
	texte(x + 52.0, y, str(roundi(ec.armure_totale())))
	texte(x2, y, "Dégâts", Parchemin.RUBRIQUE)
	texte(x2 + 52.0, y, _degats())
	y += 12.0
	texte(x, y, "Poids", Parchemin.RUBRIQUE)
	texte(x + 52.0, y, "%s / %d" % [MenuPersonnage.poids_texte(inv.poids()), roundi(inv.capacite())], Parchemin.RUBRIQUE if inv.surcharge() else Parchemin.ENCRE)
	texte(x2, y, "Pièces", Parchemin.RUBRIQUE)
	texte(x2 + 52.0, y, OngletSac._milliers(inv.pieces))
	y += 13.0
	var ef := ec.effets_totaux()
	var lr := texte(x, y, "Résistances", Parchemin.RUBRIQUE)
	texte(x + lr + 6.0, y, "Froid %s · Feu %s · Choc %s" % [_pc(ef.get("resist_froid", 0.0)), _pc(ef.get("resist_feu", 0.0)), _pc(ef.get("resist_choc", 0.0))],
		Parchemin.ENCRE, false, d.size.x - lr - 6.0)
	y += 16.0
	Parchemin.filet(self, x + 8.0, y, d.size.x - 16.0)
	y += 7.0
	if choix.is_empty():
		_dessiner_fiche(d, y)
	else:
		_dessiner_choix(d, y)

func _degats() -> String:
	var eq := _eq()
	if eq == null or not eq.categorie("droite").begins_with("arme"):
		return "-"
	var a := eq.arme("droite")
	return "%d / %d" % [roundi(a.degats_leger), roundi(a.degats_lourd)]

static func _pc(v: Variant) -> String:
	var x := roundi(float(v) * 100.0)
	return "0" if x == 0 else "%d %%" % x

## Fiche de l'emplacement choisi (bas de la page de droite).
func _dessiner_fiche(d: Rect2, y: float) -> void:
	var x := d.position.x
	var emp := emplacement()
	var id := objet_de(emp)
	texte(x, y, String(EMPLACEMENTS[sel][1]), Parchemin.RUBRIQUE)
	texte(d.end.x, y, ("porté" if not est_main(emp) else "équipée") if id != "" else "vide", Parchemin.PALE, true)
	y += 12.0
	var ec: EquipementCorps = joueur.equipement_corps
	var bas := d.end.y - 9.0
	if id == "":
		var t := "Main nue." if est_main(emp) else "Rien n'est porté ici."
		if emp == "gauche" and _eq() != null and _eq().categorie("droite") == "arme_deux_mains":
			t = "L'arme à deux mains occupe aussi cette main."
		paragraphe(x, y, d.size.x, t + "  E : choisir un objet.", Parchemin.PALE)
		texte(d.end.x, bas, "Armure totale %d" % roundi(ec.armure_totale()), Parchemin.PALE, true)
		return
	MenuStyle.cadre_icone(self, Rect2(x, y, 40, 40))
	icone(MenuStyle.icone_objet(id), Vector2(x + 4, y + 4), 2)
	var nom := ""
	var sous := ""
	var stat := ""
	var desc := ""
	var valeur := int(Inventaire.objet(id).get("valeur", 0))
	if est_main(emp):
		var f := _eq().fiche(id)
		nom = String(f["nom"])
		var rub := OngletLivre.lignes_rubriques(f["lignes"])
		var notes: Array = []
		for i in rub.size():
			if rub[i][1] == "":
				if i == 0:
					sous = String(rub[i][0]).replace(" (", " · ").trim_suffix(")")
				else:
					notes.append(rub[i][0])
			elif stat == "":
				stat = "%s %s" % [rub[i][0], rub[i][1]]
		desc = " ".join(notes)
		var poids := float(Inventaire.objet(id).get("poids", 0.0))
		if poids > 0.0:
			stat += "  ·  %s kg" % MenuPersonnage.poids_texte(poids)
	else:
		var o := Inventaire.objet(id)
		nom = String(o.get("nom", id))
		sous = "%s · %s" % [OngletSac.NOMS_CATEGORIES.get(String(o.get("categorie", "")), "Armure"), NOMS_EMP.get(emp, emp)]
		stat = "Armure %d  ·  %s kg" % [roundi(float(o.get("armure", 0.0))), MenuPersonnage.poids_texte(float(o.get("poids", 0.0)))]
		desc = String(o.get("description", ""))
		var ef: Variant = o.get("effets", {})
		if ef is Dictionary and not (ef as Dictionary).is_empty():
			var morceaux: Array = []
			for k: String in ef:
				morceaux.append("%s %s" % [OngletSac.NOMS_EFFETS.get(k, k), OngletSac._effet_txt(k, ef[k])])
			desc = (desc + " " if desc != "" else "") + " · ".join(morceaux)
	texte(x + 46.0, y + 2.0, nom, Parchemin.ENCRE, false, d.size.x - 46.0)
	texte(x + 46.0, y + 14.0, sous, Parchemin.PALE, false, d.size.x - 46.0)
	texte(x + 46.0, y + 26.0, stat, Parchemin.ENCRE, false, d.size.x - 46.0)
	y += 46.0
	if desc != "":
		paragraphe(x, y, d.size.x, desc, Parchemin.ENCRE, maxi(1, int((bas - 4.0 - y) / 10.0)))
	if valeur > 0:
		texte(x, bas, "Valeur %d" % valeur, Parchemin.OR_TERNI)
	texte(d.end.x, bas, "Armure totale %d" % roundi(ec.armure_totale()), Parchemin.PALE, true)

## Liste « Changer » : candidats + comparaison.
func _dessiner_choix(d: Rect2, y: float) -> void:
	var x := d.position.x
	texte(x, y, "Choisir : %s" % String(EMPLACEMENTS[sel][1]).to_lower(), Parchemin.RUBRIQUE)
	texte(d.end.x, y, "E équiper · Échap annuler", Parchemin.PALE, true)
	y += 12.0
	Parchemin.regle(self, x, y, d.size.x)
	y += 2.0
	_choix_rangs = maxi(1, int((d.end.y - y) / 17.0))
	for i in range(_choix_haut, mini(choix.size(), _choix_haut + _choix_rangs)):
		var c: Dictionary = choix[i]
		var rl := Rect2(x, y, d.size.x, 16)
		if i == choix_sel:
			Parchemin.ligne_choisie(self, rl)
		zone(rl, "choix", i)
		var id := String(c["id"])
		if id != "":
			icone(MenuStyle.icone_objet(id), Vector2(x + 1, y))
		var porte := id == objet_de(emplacement()) or (id == "vide" and objet_de(emplacement()) == "")
		var ln := texte(x + 20.0, y + 4.0, String(c["nom"]), Parchemin.ENCRE, false, d.size.x - 100.0)
		if porte:
			texte(x + 24.0 + ln, y + 4.0, "(actuel)", Parchemin.PALE)
		texte(d.end.x - 2.0, y + 4.0, String(c["delta"]), c["couleur"], true)
		Parchemin.regle(self, x, y + 16.0, d.size.x)
		y += 17.0
