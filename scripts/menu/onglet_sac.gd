class_name OngletSac
extends OngletLivre
## Onglet SAC du codex (lot C ; maquette A_parchemin/2_inventaire.html). Page de gauche : catégories du registre en marge
## (Tout, Favoris, Armes, Armures, Bijoux, Potions, Ingrédients, Quête, Divers) et registre des objets (icône, rareté, nom,
## poids, valeur ; marques D / G = tenu en main, P = porté ; étoile = favori), pièces et poids en pied de page. Page de droite :
## fiche détaillée (famille, rareté, description, statistiques, comparaison avec l'objet porté ou tenu, poids / valeur).
## Une arme n'apparaît qu'UNE fois (fin du doublon « armes aussi dans Divers ») : armes tenables (EquipementMains) + armes du
## sac sans modèle tenu (hache de Kolbeinn : catégorie Armes, « trophée », non équipable tant que le lot A n'a pas son modèle).
## Touches : E / Entrée / A = équiper (main droite), porter, retirer ou boire ; G / X / clic droit = main gauche ; R / Y = lâcher
## (Maj : toute la pile) ; F = favori ; ← → = catégorie ; 1-0 = raccourci (potion choisie, sinon les deux mains).

const CATEGORIES := [["tout", "Tout"], ["favoris", "Favoris"], ["arme", "Armes"], ["armure", "Armures"], ["bijou", "Bijoux"],
	["consommable", "Potions"], ["ingredient", "Ingrédients"], ["quete", "Quête"], ["divers", "Divers"]]
const ORDRE := ["arme", "armure", "bijou", "consommable", "ingredient", "quete", "divers"]
const NOMS_CATEGORIES := {"arme": "Arme", "armure": "Armure", "bijou": "Bijou", "consommable": "Consommable", "ingredient": "Ingrédient",
	"quete": "Objet de quête", "divers": "Objet de valeur"}
const NOMS_EMPLACEMENTS := {"tete": "tête", "torse": "torse", "mains": "mains", "pieds": "pieds", "cou": "cou", "anneau": "anneau"}
const NOMS_EFFETS := {"resist_froid": "Froid", "resist_feu": "Feu", "resist_choc": "Choc", "vie_max": "Vie", "magie_max": "Magie",
	"vigueur_max": "Vigueur", "charge": "Charge", "regen_magie": "Régén. magie", "regen_vigueur": "Régén. vigueur", "cout_sorts": "Coût des sorts",
	"prix": "Prix", "degats_une_main": "Dégâts à une main", "degats_deux_mains": "Dégâts à deux mains", "degats_destruction": "Dégâts de destruction"}

var filtre := "tout"
## Objet choisi (identifiant du registre ou de l'équipement des mains).
var choisi := ""
## Lignes affichées : {id, nom, n, poids, valeur, rarete, categorie, hors_sac}.
var lignes: Array = []
var _sel := 0
var _haut := 0
var _rangs := 10
var _comptes := {}

func id_onglet() -> String:
	return "sac"

func titre() -> String:
	return "Sac"

func ouvrir() -> void:
	relire()

func _inv() -> Inventaire:
	return joueur.inventaire if joueur != null else null

func _c() -> InventaireMains:
	return coquille as InventaireMains

func _eq() -> EquipementMains:
	return _c()._eq() if _c() != null else null

## Relit le sac (après une action) en gardant l'objet choisi.
func relire() -> void:
	_construire()
	var i := -1
	for k in lignes.size():
		if lignes[k]["id"] == choisi:
			i = k
	_sel = clampi(i if i >= 0 else _sel, 0, maxi(0, lignes.size() - 1))
	choisi = String(lignes[_sel]["id"]) if not lignes.is_empty() else ""
	_visible_sel()
	queue_redraw()
	contenu_change.emit()

func filtrer(f: String) -> void:
	filtre = f
	_sel = 0
	_haut = 0
	choisi = ""
	if joueur != null:
		relire()

## Choisit un objet ; s'il n'est pas dans la catégorie affichée, passe à « Tout ».
func choisir(id: String) -> void:
	if joueur == null:
		choisi = id
		return
	_construire()
	var i := _index(id)
	if i < 0 and filtre != "tout" and id != "":
		filtre = "tout"
		_construire()
		i = _index(id)
	if i < 0:
		choisi = ""
	else:
		_sel = i
		choisi = id
	_visible_sel()
	queue_redraw()
	contenu_change.emit()

func _index(id: String) -> int:
	for k in lignes.size():
		if lignes[k]["id"] == id:
			return k
	return -1

## Toutes les entrées du sac (une par objet) puis filtrées.
func _toutes() -> Array:
	var inv := _inv()
	var eq := _eq()
	var res: Array = []
	var vus := {}
	if eq != null:   # armes tenables : celles de départ (hors du sac, sans poids) et celles du sac
		var possedees := eq.objets_possedes("armes")
		for id in possedees:
			if id == "vide" or vus.has(id):
				continue
			if id == "epee" and possedees.has("epee_skarnholt") and eq.objet("epee") == eq.objet("epee_skarnholt"):
				continue   # même lame que l'épée de Skarnholt du sac
			vus[id] = true
			res.append(_entree(id, eq))
	if inv != null:
		for id: String in inv.objets:
			if vus.has(id):
				continue
			vus[id] = true
			res.append(_entree(id, eq))
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := ORDRE.find(a["categorie"])
		var cb := ORDRE.find(b["categorie"])
		if ca != cb:
			return ca < cb
		if a["hors_sac"] != b["hors_sac"]:
			return a["hors_sac"]
		return String(a["nom"]).naturalnocasecmp_to(String(b["nom"])) < 0)
	return res

func _entree(id: String, eq: EquipementMains) -> Dictionary:
	var inv := _inv()
	var o := Inventaire.objet(id)
	var dans_sac := inv != null and inv.a(id)
	var nom := String(o.get("nom", ""))
	if nom == "" and eq != null:
		nom = String(eq.fiche(id)["nom"])
	return {"id": id, "nom": nom, "n": inv.nombre(id) if dans_sac else 1, "poids": float(o.get("poids", 0.0)) if dans_sac else 0.0,
		"valeur": int(o.get("valeur", 0)) if dans_sac else 0, "rarete": String(o.get("rarete", "commun")),
		"categorie": String(o.get("categorie", "arme" if o.is_empty() else "divers")), "hors_sac": not dans_sac}

func _construire() -> void:
	var tout := _toutes()
	_comptes = {"tout": tout.size(), "favoris": 0}
	lignes = []
	for e: Dictionary in tout:
		var c := String(e["categorie"])
		_comptes[c] = int(_comptes.get(c, 0)) + 1
		var fav := _c() != null and _c().est_favori(e["id"])
		if fav:
			_comptes["favoris"] = int(_comptes["favoris"]) + 1
		if filtre == "tout" or c == filtre or (filtre == "favoris" and fav):
			lignes.append(e)

func _visible_sel() -> void:
	if _sel < _haut:
		_haut = _sel
	elif _sel >= _haut + _rangs:
		_haut = _sel - _rangs + 1
	_haut = clampi(_haut, 0, maxi(0, lignes.size() - _rangs))

func _deplacer(d: int) -> void:
	if lignes.is_empty():
		return
	_sel = clampi(_sel + d, 0, lignes.size() - 1)
	choisi = String(lignes[_sel]["id"])
	_visible_sel()
	Sons.jouer(self, ["cloth1"], -24.0)

func _categorie_voisine(sens: int) -> void:
	var i := 0
	for k in CATEGORIES.size():
		if CATEGORIES[k][0] == filtre:
			i = k
	filtrer(String(CATEGORIES[(i + sens + CATEGORIES.size()) % CATEGORIES.size()][0]))
	Sons.jouer(self, ["cloth1", "cloth2"], -18.0)

# ------------------------------------------------------------------ actions

## Action principale sur l'objet choisi : main droite, porter / retirer, boire.
func action_principale() -> String:
	if choisi == "" or _c() == null:
		return ""
	var ec: EquipementCorps = joueur.equipement_corps
	if Inventaire.emplacement_de(choisi) != "" and ec.est_equipe(choisi):
		return _c().retirer_corps(Inventaire.emplacement_de(choisi))
	return _c().equiper("droite", choisi)

func _verbe() -> String:
	if choisi == "":
		return "Équiper"
	if Inventaire.emplacement_de(choisi) != "":
		return "Retirer" if joueur.equipement_corps.est_equipe(choisi) else "Porter"
	if Consommables.est(choisi):
		return "Utiliser" if Inventaire.objet(choisi).get("effets", {}).has("apprendre") else "Boire"
	return "Équiper"

func entree(e: InputEvent) -> bool:
	if _c() == null:
		return false
	var d := direction(e)
	if d == -1 or d == 1:
		_deplacer(d)
		return true
	if d == -2 or d == 2:
		_categorie_voisine(-1 if d == -2 else 1)
		return true
	var k := touche(e)
	var shift := e is InputEventKey and (e as InputEventKey).shift_pressed
	match k:
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			action_principale()
			return true
		KEY_G:
			_c().equiper("gauche", choisi)
			return true
		KEY_R, KEY_L:
			_c().lacher(shift)
			return true
		KEY_F:
			_c().basculer_favori(choisi)
			return true
		KEY_PAGEUP, KEY_PAGEDOWN:
			_deplacer(_rangs * (-1 if k == KEY_PAGEUP else 1))
			return true
	match bouton(e):
		JOY_BUTTON_A:
			action_principale()
			return true
		JOY_BUTTON_X:
			_c().equiper("gauche", choisi)
			return true
		JOY_BUTTON_Y:
			_c().lacher(false)
			return true
		JOY_BUTTON_RIGHT_STICK:
			_c().lacher(true)
			return true
	var c := chiffre(e)
	if c >= 0:
		_c().memoriser(c)
		return true
	return false

## L'objet choisi peut-il aller dans la main gauche (bouclier, torche, sort, arme légère selon regles_mains.json) ?
func _gauche_possible() -> bool:
	return _c() != null and _c().tenable(choisi) and String(_eq().essai("gauche", choisi)["refus"]) == ""

func aide() -> Array:
	var a: Array = [["E", _verbe()]]
	if _gauche_possible():
		a.append(["G", "Main gauche"])
	a.append(["R", "Lâcher"])
	a.append(["F", "Favori"])
	a.append(["← →", "Catégorie"])
	return a

func survoler(action: String, valeur: Variant) -> void:
	if action == "ligne" and int(valeur) < lignes.size():
		_sel = int(valeur)
		choisi = String(lignes[_sel]["id"])
		contenu_change.emit()

func cliquer(action: String, valeur: Variant, b: int) -> void:
	match action:
		"ligne":
			survoler(action, valeur)
			if b == MOUSE_BUTTON_RIGHT:
				_c().equiper("gauche", choisi)
			else:
				action_principale()
		"cat":
			filtrer(String(valeur))
		"bouton":
			actionner(String(valeur))

## Boutons (souris) de la fiche de l'objet choisi : [[action, libellé]…] ; « Lâcher » seulement si l'objet peut l'être.
func boutons_fiche() -> Array:
	if choisi == "" or _c() == null:
		return []
	var b: Array = [["principal", _verbe()]]
	if _gauche_possible():
		b.append(["gauche", "Main gauche"])
	if _inv().a(choisi) and Lacher.refus(choisi) == "":
		b.append(["lacher", "Lâcher"])
		if _inv().nombre(choisi) > 1:
			b.append(["tout", "Tout lâcher"])
	b.append(["favori", "Retirer favori" if _c().est_favori(choisi) else "Favori"])
	return b

## Action d'un bouton de la fiche (principal, gauche, lacher, tout, favori).
func actionner(action: String) -> void:
	match action:
		"principal":
			action_principale()
		"gauche":
			_c().equiper("gauche", choisi)
		"lacher":
			_c().lacher(false)
		"tout":
			_c().lacher(true)
		"favori":
			_c().basculer_favori(choisi)

func defiler(sens: int, _pos: Vector2) -> bool:
	if lignes.size() <= _rangs:
		return false
	_haut = clampi(_haut + sens, 0, lignes.size() - _rangs)
	return true

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if joueur == null:
		return
	_zones.clear()
	var r := rects()
	var g: Rect2 = r["gauche"]
	var d: Rect2 = r["droite"]
	var inv := _inv()
	Parchemin.titre(self, _gothique, _police, Vector2(g.position.x, g.position.y), "Sac")
	# marge : catégories
	var cx := g.position.x - 4.0
	var y := g.position.y + 34.0
	for c: Array in CATEGORIES:
		var actif: bool = c[0] == filtre
		var n := int(_comptes.get(c[0], 0))
		if actif:
			Parchemin.ruban(self, Rect2(cx - 3.0, y - 2.0, 74, 12))
		var col := Parchemin.CLAIR if actif else (Parchemin.PALE if n > 0 else Color(Parchemin.PALE, 0.55))
		texte(cx, y, String(c[1]), col)
		texte(cx + 69.0, y, str(n), col, true)
		zone(Rect2(cx - 3.0, y - 3.0, 74, 14), "cat", c[0])
		y += 14.0
	var xr := g.position.x + 74.0   # filet vermillon de la marge
	draw_rect(Rect2(xr, g.position.y + 28.0, 1, g.size.y - 44.0), Parchemin.RUBRIQUE)
	# registre
	var x := xr + 4.0
	var w := g.end.x - x
	var y0 := g.position.y + 30.0
	texte(x + 25.0, y0 - 10.0, "Nom", Parchemin.RUBRIQUE)
	texte(x + w - 30.0, y0 - 10.0, "Poids", Parchemin.RUBRIQUE, true)
	texte(x + w, y0 - 10.0, "Val.", Parchemin.RUBRIQUE, true)
	Parchemin.regle(self, x, y0, w)
	_rangs = maxi(1, int((g.end.y - 16.0 - (y0 + 3.0)) / H_LIGNE))
	_visible_sel()
	if lignes.is_empty():
		texte(x + 4.0, y0 + 8.0, "(rien ici)" if filtre != "favoris" else "(aucun favori : F)", Parchemin.PALE)
	for i in range(_haut, mini(lignes.size(), _haut + _rangs)):
		var e: Dictionary = lignes[i]
		var ly := y0 + 3.0 + (i - _haut) * H_LIGNE
		var rl := Rect2(x, ly, w, H_LIGNE - 1.0)
		if i == _sel:
			Parchemin.ligne_choisie(self, rl)
		zone(rl, "ligne", i)
		var id := String(e["id"])
		icone(MenuStyle.icone_objet(id), Vector2(x + 1, ly + 1))
		var m := _marque(id)
		if m != "":
			MenuStyle.marque(self, _police, x + 9.0, ly + 8.0, m)
		draw_rect(Rect2(x + 19, ly + 7, 3, 3), MenuStyle.RARETE_ENCRE.get(e["rarete"], MenuStyle.RARETE_ENCRE["commun"]))
		var nom := String(e["nom"])
		var suffixe := "  x%d" % int(e["n"]) if int(e["n"]) > 1 else ""
		var lmax := w - 25.0 - 62.0 - (8.0 if _c().est_favori(id) else 0.0)
		var ln := texte(x + 25.0, ly + 4.0, nom, Parchemin.ENCRE, false, lmax - largeur(suffixe))
		if suffixe != "":
			texte(x + 25.0 + ln, ly + 4.0, suffixe, Parchemin.PALE)
		if _c().est_favori(id):
			MenuStyle.etoile(self, x + 25.0 + ln + largeur(suffixe) + 3.0, ly + 5.0)
		texte(x + w - 30.0, ly + 4.0, "-" if e["hors_sac"] else MenuPersonnage.poids_texte(float(e["poids"]) * int(e["n"])), Parchemin.ENCRE, true)
		texte(x + w, ly + 4.0, "-" if e["hors_sac"] else str(int(e["valeur"])), Parchemin.RUBRIQUE if i == _sel else Parchemin.OR_TERNI, true)
		Parchemin.regle(self, x, ly + H_LIGNE - 1.0, w)
	if lignes.size() > _rangs:   # repère de défilement dans la marge du registre
		var hh := g.end.y - 16.0 - y0
		var t := maxf(8.0, hh * _rangs / lignes.size())
		var ty := y0 + (hh - t) * _haut / maxf(1.0, lignes.size() - _rangs)
		draw_rect(Rect2(xr - 1.0, ty, 3, t), Parchemin.RUBRIQUE)
	# pied de page
	texte(g.position.x - 4.0, g.end.y - 9.0, "Pièces %s" % _milliers(inv.pieces), Parchemin.OR_TERNI)
	texte(g.end.x, g.end.y - 9.0, "Poids %s / %d" % [MenuPersonnage.poids_texte(inv.poids()), roundi(inv.capacite())],
		Parchemin.RUBRIQUE if inv.surcharge() else Parchemin.ENCRE, true)
	_dessiner_fiche(d)

## Marque sur l'icône : D / G (main), P (porté).
func _marque(id: String) -> String:
	if _c() == null:
		return ""
	if _c().tient("droite", id):
		return "D"
	if _c().tient("gauche", id):
		return "G"
	if joueur.equipement_corps.est_equipe(id):
		return "P"
	return ""

static func _milliers(n: int) -> String:
	var s := str(absi(n))
	var res := ""
	while s.length() > 3:
		res = " " + s.substr(s.length() - 3) + res
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + res

## Contenu de la fiche de l'objet `id` : {titre, sous, rarete, extra, desc, lignes [[rubrique, valeur]], compare [texte, couleur, vs],
## poids, valeur, note, note_couleur, hors_sac}.
func fiche(id: String) -> Dictionary:
	var eq := _eq()
	var o := Inventaire.objet(id)
	var inv := _inv()
	var dans_sac := inv != null and inv.a(id)
	var f := {"titre": String(o.get("nom", id)), "sous": NOMS_CATEGORIES.get(String(o.get("categorie", "")), ""), "rarete": String(o.get("rarete", "commun")),
		"extra": "", "desc": String(o.get("description", "")), "lignes": [], "compare": [], "poids": float(o.get("poids", 0.0)),
		"valeur": int(o.get("valeur", 0)), "note": "", "note_couleur": Parchemin.PALE, "hors_sac": not dans_sac}
	var lignes_f: Array = f["lignes"]
	var tenable := _c() != null and _c().tenable(id)
	var cat := String(o.get("categorie", ""))
	if tenable:
		var fe := eq.fiche(id)
		if String(f["titre"]) == id or String(f["titre"]) == "":
			f["titre"] = String(fe["nom"])
		var notes: Array = []
		var premiere := true
		for l: Array in lignes_rubriques(fe["lignes"]):
			if l[1] == "":
				if premiere and String(fe["genre"]).begins_with("arme"):
					f["sous"] = String(l[0]).replace(" (", " · ").trim_suffix(")")
				else:
					notes.append(l[0])
			else:
				lignes_f.append(l)
			premiere = false
		if f["desc"] == "" and not notes.is_empty():
			f["desc"] = " ".join(notes)
		if String(f["sous"]) == "":
			f["sous"] = {"bouclier": "Bouclier", "torche": "Torche", "arme_deux_mains": "Arme à deux mains", "arme": "Arme"}.get(String(fe["genre"]), "Arme")
		if bool(fe["deux_mains"]):
			f["extra"] = "deux mains"
		f["compare"] = _comparer_main(id)
		if _c().tient("droite", id):
			f["note"] = "En main droite."
		elif _c().tient("gauche", id):
			f["note"] = "En main gauche."
		else:
			var es := eq.essai("droite", id)
			var eg := eq.essai("gauche", id)
			if String(es["refus"]) == "":
				f["note"] = "Main droite : %s" % (String(es["effet"]) if String(es["effet"]) != "" else "prête à l'équiper.")
			elif String(eg["refus"]) == "":
				f["note"] = "Main gauche : %s" % (String(eg["effet"]) if String(eg["effet"]) != "" else "prête à l'équiper (G).")
			else:
				f["note"] = String(es["refus"])
				f["note_couleur"] = Parchemin.RUBRIQUE
		if not dans_sac:
			f["note"] = String(f["note"]) + " Toujours sur vous : ne pèse rien."
	elif cat == "arme":
		f["sous"] = "Arme · trophée"
		f["note"] = "Ne se tient pas encore en main : un trophée à garder (ou à vendre)."
		f["note_couleur"] = Parchemin.RUBRIQUE
	if Inventaire.emplacement_de(id) != "":
		var emp := Inventaire.emplacement_de(id)
		f["sous"] = "%s · %s" % [NOMS_CATEGORIES.get(cat, "Armure"), NOMS_EMPLACEMENTS.get(emp, emp)]
		if o.has("armure"):
			lignes_f.append(["Armure", str(roundi(float(o["armure"])))])
		if o.has("type_armure"):
			lignes_f.append(["Type", "lourde" if String(o["type_armure"]) == "lourde" else "légère"])
		var ef: Variant = o.get("effets", {})
		if ef is Dictionary:
			for k: String in ef:
				lignes_f.append([NOMS_EFFETS.get(k, k), _effet_txt(k, ef[k])])
		f["compare"] = _comparer_corps(id)
		var porte: bool = joueur.equipement_corps.est_equipe(id)
		f["note"] = "Porté : il reste dans le sac (il pèse)." if porte else "Se porte : %s (E)." % NOMS_EMPLACEMENTS.get(emp, emp)
	elif Consommables.est(id):
		f["desc"] = Consommables.description(id) if String(f["desc"]) == "" else String(f["desc"])
		lignes_f.append(["Quantité", str(inv.nombre(id))])
		var rf := Consommables.refus(joueur, id)
		f["note"] = "E : %s ; 1-0 : le ranger dans un raccourci." % _verbe().to_lower() if rf == "" else "Pour l'instant : " + rf
		f["note_couleur"] = Parchemin.PALE if rf == "" else Parchemin.RUBRIQUE
	if Inventaire.est_quete(id):
		f["note"] = "Objet de quête : il ne se lâche ni ne se vend."
		f["note_couleur"] = Parchemin.RUBRIQUE
	elif dans_sac and not tenable and Inventaire.emplacement_de(id) == "" and not Consommables.est(id) and cat != "arme":
		f["note"] = "Se vend chez les marchands ; R pour le lâcher."
	return f

static func _effet_txt(k: String, v: Variant) -> String:
	var x := float(v)
	if k.begins_with("resist_") or k.begins_with("regen_") or k.begins_with("degats_") or k in ["cout_sorts", "prix"]:
		return "%s%d %%" % ["-" if k.begins_with("resist_") or k == "cout_sorts" else "+", roundi(absf(x) * 100.0)]
	return "%+d" % roundi(x)

## Comparaison d'une arme / d'un bouclier avec ce que tient la main concernée : [texte, couleur, « vs nom »] ou [].
func _comparer_main(id: String) -> Array:
	var eq := _eq()
	var a := eq.objet(id) as DonneesArme
	if a == null:
		return []
	var cat := EquipementMains.categorie_de(a)
	if cat.begins_with("arme"):
		if _c().tient("droite", id) or not eq.categorie("droite").begins_with("arme"):
			return [] if _c().tient("droite", id) else ["main droite sans arme", Parchemin.PALE, ""]
		var b := eq.arme("droite")
		var dl := roundi(a.degats_leger - b.degats_leger)
		var dg := roundi(a.degats_lourd - b.degats_lourd)
		return ["%+d / %+d" % [dl, dg], Parchemin.VIGUEUR if dl + dg > 0 else (Parchemin.RUBRIQUE if dl + dg < 0 else Parchemin.PALE), "vs " + b.nom]
	if cat == "bouclier" and eq.categorie("gauche") == "bouclier" and not _c().tient("gauche", id):
		var b2 := eq.arme("gauche")
		var dgd := roundi((a.reduction_garde - b2.reduction_garde) * 100.0)
		return ["garde %+d %%" % dgd, Parchemin.VIGUEUR if dgd > 0 else (Parchemin.RUBRIQUE if dgd < 0 else Parchemin.PALE), "vs " + b2.nom]
	return []

## Comparaison d'un objet de corps avec celui porté au même emplacement.
func _comparer_corps(id: String) -> Array:
	var ec: EquipementCorps = joueur.equipement_corps
	var emp := Inventaire.emplacement_de(id)
	var porte := ec.objet_a(emp)
	if porte == id:
		return []
	if porte == "":
		return ["emplacement libre", Parchemin.PALE, ""]
	var da := roundi(float(Inventaire.objet(id).get("armure", 0.0)) - float(Inventaire.objet(porte).get("armure", 0.0)))
	return ["armure %+d" % da, Parchemin.VIGUEUR if da > 0 else (Parchemin.RUBRIQUE if da < 0 else Parchemin.PALE), "vs " + String(Inventaire.objet(porte).get("nom", porte))]

func _dessiner_fiche(d: Rect2) -> void:
	if choisi == "":
		Parchemin.filet(self, d.position.x + 8.0, d.position.y + d.size.y * 0.5, d.size.x - 16.0)
		return
	var f := fiche(choisi)
	var x := d.position.x
	var y := d.position.y
	MenuStyle.cadre_icone(self, Rect2(x, y + 2, 40, 40))
	icone(MenuStyle.icone_objet(choisi), Vector2(x + 4, y + 6), 2)
	titre_fiche(x + 46.0, y, String(f["titre"]), d.size.x - 46.0)
	texte(x + 46.0, y + 23.0, String(f["sous"]), Parchemin.PALE, false, d.size.x - 46.0)
	var rar := String(f["rarete"])
	var lr := texte(x + 46.0, y + 34.0, String(ButinTables.NOMS_RARETE.get(rar, rar)).capitalize(), MenuStyle.RARETE_ENCRE.get(rar, Parchemin.PALE))
	if String(f["extra"]) != "":
		texte(x + 46.0 + lr, y + 34.0, " · " + String(f["extra"]), Parchemin.PALE)
	y += 50.0
	Parchemin.filet(self, x + 8.0, y, d.size.x - 16.0)
	y += 6.0
	if String(f["desc"]) != "":
		y = paragraphe(x, y, d.size.x, String(f["desc"]), Parchemin.ENCRE, 3) + 3.0
	for l: Array in f["lignes"]:
		if y > d.end.y - 64.0:
			break
		texte(x, y, String(l[0]), Parchemin.RUBRIQUE)
		texte(x + 74.0, y, String(l[1]), Parchemin.ENCRE, false, d.size.x - 74.0)
		Parchemin.regle(self, x, y + 10.0, d.size.x)
		y += 12.0
	var cmp: Array = f["compare"]
	if not cmp.is_empty():
		y += 2.0
		texte(x, y, "Comparé", Parchemin.RUBRIQUE)
		var lc := texte(x + 74.0, y, String(cmp[0]), cmp[1])
		if String(cmp[2]) != "":
			texte(x + 74.0 + lc + 8.0, y, String(cmp[2]), Parchemin.PALE, false, d.size.x - 82.0 - lc)
		y += 12.0
	y = maxf(y + 4.0, d.end.y - 64.0)
	Parchemin.filet(self, x + 8.0, y, d.size.x - 16.0)
	y += 7.0
	if not f["hors_sac"]:
		texte(x, y, "Poids", Parchemin.RUBRIQUE)
		texte(x + 36.0, y, "%s kg" % MenuPersonnage.poids_texte(float(f["poids"])))
		texte(x + 96.0, y, "Valeur", Parchemin.RUBRIQUE)
		texte(x + 136.0, y, str(int(f["valeur"])), Parchemin.OR_TERNI)
	else:
		texte(x, y, "Équipement de départ", Parchemin.PALE)
	y += 12.0
	paragraphe(x, y, d.size.x, String(f["note"]), f["note_couleur"], 2)
	# boutons (souris) en bas de la fiche
	var bx := x
	var by := d.end.y - 12.0
	for b: Array in boutons_fiche():
		var lb := largeur(b[1]) + 10.0
		var rb := Rect2(bx, by, lb, 12)
		var surv: bool = _survol >= 0 and _survol < _zones.size() and _zones[_survol][1] == "bouton" and _zones[_survol][2] == b[0]
		if surv:
			Parchemin.ruban(self, rb)
		else:
			_bouton_encre(rb)
		texte(bx + 5.0, by + 2.0, String(b[1]), Parchemin.CLAIR if surv else Parchemin.ENCRE)
		zone(rb, "bouton", b[0])
		bx += lb + 4.0

func _bouton_encre(r: Rect2) -> void:
	draw_rect(r, Parchemin.PALE)
	draw_rect(r.grow(-1), Parchemin.VELIN[4])
