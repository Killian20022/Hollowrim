class_name FenetreButin
extends CanvasLayer
## Lot L3 « fenêtre de butin » (docs/BUTIN.md §8, INSPIRATION_IGNITE §2.18) : à l'ouverture d'un coffre ou à la fouille d'un corps, la
## liste des OBJETS du contenant (les pièces, elles, jaillissent et vont seules au sac : scripts/butin.gd, ligne « + N pièces » du titre).
##   - une ligne par objet : icône (motif IconesCombat de objets.json, sinon losange de la couleur de rareté), nom en couleur de
##     rareté (ButinTables.COULEURS_RARETE), nombre et poids en police du corps (Kenney) ; fiche de la ligne choisie (rareté, valeur,
##     effet d'un consommable) ; poids du sac en pied ;
##   - PRENDRE un objet : E, Entrée, Espace, clic gauche, A (manette) ; TOUT PRENDRE : R, Y (manette), clic sur « Tout prendre » ;
##     choisir : flèches, Z/S (touches physiques W/S), molette, survol, croix ; FERMER : Échap, Tab, clic droit, B (manette) ;
##   - jeu en PAUSE pendant qu'elle est ouverte (comme l'inventaire) ; la gerbe de pièces d'un coffre continue (PROCESS_MODE_ALWAYS) ;
##   - la prise passe par ButinTables.prendre (un unique déjà pris devient des pièces) ; l'objet est retiré du dictionnaire du
##     CONTENANT (`objets`, passé par référence) : ce qui n'est pas pris y reste (coffre : ButinTables.restes, sauvegardé ; corps :
##     butin.gd) ; `fin` est appelé à la fermeture. Tout pris = fermeture seule.
## Style : cadre ornementé du lot L7 (MenuStyle.cadre_orne), titre en Jacquard 24 (MenuStyle.police_gothique), texte et chiffres en
## Palette.police, surbrillance bleue des boutons de MenuStyle ; dessin en pixels entiers (EchelleUi), comme le panneau Tab du HUD.
## Une seule instance, créée par monde._interface ; les contenants la trouvent par FenetreButin.trouver(noeud).

const GROUPE := "fenetre_butin"
const LIGNE := 14.0
const MAX_LIGNES := 8
const ORDRE_RARETE := {"unique": 0, "rare": 1, "peu_commun": 2, "commun": 3}
const FER := Color("#3a4458")

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
var titre := ""
## Pièces versées à l'ouverture (affichées à côté du titre ; déjà dans le sac).
var pieces := 0
## Lignes affichées : [{id, n, rarete}] (ordre : rareté décroissante puis ordre du contenant).
var lignes: Array[Dictionary] = []
var choix := 0

var _objets: Dictionary = {}
var _fin: Callable
var _vue: Control
var _police: FontFile
var _gothique: FontFile
var _cadre: StyleBox
var _haut := 0        # première ligne visible (défilement)
var _zones := {}      # zones cliquables du dernier dessin (repère logique) : "ligne:i", "tout", "fermer"
var _souris := Input.MOUSE_MODE_CAPTURED
var _icones := {}

static func trouver(n: Node) -> FenetreButin:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as FenetreButin

## Coffre ouvert (tertre.gd, grotte_jeu.gd : _ouvrir_coffre) : fenêtre sur les objets restés dans le coffre (ButinTables.restes[cle]) ;
## à la fermeture, le coffre n'est plus proposé s'il est vide, sinon il devient « Fouiller le coffre ». Sans fenêtre (scène sans
## interface) : tout va au sac (repli).
static func fouiller(n: Node, cle: String, nom: String, n_or: int, it: Node3D, joueur_: CharacterBody3D, hud_: Control) -> void:
	var objets: Dictionary = ButinTables.reste(cle)
	var maj := func() -> void:
		if objets.is_empty():
			ButinTables.restes.erase(cle)
		if it != null and is_instance_valid(it):
			it.actif = ButinTables.a_reste(cle)
			it.verbe = "Fouiller le coffre"
			if not it.actif and it.get("dialogue") != null:
				it.dialogue.retirer_invite(it)
	if objets.is_empty():
		maj.call()
		return
	var f := trouver(n)
	if f == null or not f.ouvrir(nom, objets, n_or, maj):
		var liste: Array = []
		for id: String in objets:
			liste.append({"id": id, "n": int(objets[id]), "rarete": ButinTables.rarete_de(id)})
		for o: Dictionary in ButinTables.prendre(joueur_.inventaire, liste):
			if hud_ != null:
				hud_.avis("+ %d %s" % [int(o["n"]), joueur_.inventaire.nom(String(o["id"]))])
		objets.clear()
		maj.call()

func _ready() -> void:
	layer = 44   # au-dessus du HUD, sous l'inventaire (45) et le menu pause (50)
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

## Ouvre la fenêtre sur `objets` ({id: n}, modifié en place à chaque prise). Rien à montrer : false (rien n'est ouvert).
func ouvrir(nom: String, objets: Dictionary, pieces_versees := 0, fin := Callable()) -> bool:
	if ouvert or joueur == null:
		return false
	lignes.clear()
	var i := 0
	for id: String in objets:
		if id == "pieces" or int(objets[id]) <= 0:
			continue
		lignes.append({"id": id, "n": int(objets[id]), "rarete": ButinTables.rarete_de(id), "i": i})
		i += 1
	if lignes.is_empty():
		return false
	lignes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = ORDRE_RARETE.get(a["rarete"], 3)
		var rb: int = ORDRE_RARETE.get(b["rarete"], 3)
		return ra < rb if ra != rb else int(a["i"]) < int(b["i"]))
	titre = nom
	pieces = pieces_versees
	_objets = objets
	_fin = fin
	choix = 0
	_haut = 0
	ouvert = true
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_vue.visible = true
	_vue.queue_redraw()
	Sons.jouer(self, ["cloth1", "cloth2"], -10.0)
	return true

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_vue.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	var f := _fin
	_fin = Callable()
	_objets = {}
	if f.is_valid():
		f.call()

## Prend la ligne i (toute la pile) ; renvoie ce qui est arrivé dans le sac [{id, n, rarete}].
func prendre(i := -1) -> Array[Dictionary]:
	if i < 0:
		i = choix
	if not ouvert or i < 0 or i >= lignes.size():
		return []
	var l: Dictionary = lignes[i]
	# poids : on ne prend que ce que le sac peut porter (le reste demeure dans le contenant)
	var place := joueur.inventaire.place_pour(String(l["id"]))
	if place < int(l["n"]):
		if hud != null:
			hud.avis("Trop lourd : sac %d / %d" % [roundi(joueur.inventaire.poids()), roundi(joueur.inventaire.capacite())])
		if place <= 0:
			return []
		var part: Dictionary = l.duplicate()
		part["n"] = place
		var rp := ButinTables.prendre(joueur.inventaire, [part])
		for o: Dictionary in rp:
			if hud != null:
				hud.avis("+ %d %s" % [int(o["n"]), joueur.inventaire.nom(String(o["id"]))])
		l["n"] = int(l["n"]) - place
		_objets[String(l["id"])] = int(l["n"])
		Sons.jouer(self, ["cloth1", "cloth2"], -8.0)
		_vue.queue_redraw()
		return rp
	var res := ButinTables.prendre(joueur.inventaire, [l])
	for o: Dictionary in res:
		if hud != null:
			hud.avis("+ %d %s" % [int(o["n"]), joueur.inventaire.nom(String(o["id"]))])
	_objets.erase(String(l["id"]))
	lignes.remove_at(i)
	Sons.jouer(self, ["cloth1", "cloth2"], -8.0)
	if lignes.is_empty():
		fermer()
	else:
		choix = clampi(choix, 0, lignes.size() - 1)
		_suivre()
		_vue.queue_redraw()
	return res

func tout_prendre() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var i := 0
	while ouvert and i < lignes.size():
		var avant := lignes.size()
		res.append_array(prendre(i))
		if ouvert and lignes.size() >= avant:   # ligne gardée (sac plein) : on passe à la suivante
			i += 1
	return res

func _choisir(i: int) -> void:
	if lignes.is_empty():
		return
	var n := clampi(i, 0, lignes.size() - 1)
	if n != choix:
		choix = n
		_suivre()
		_vue.queue_redraw()

func _suivre() -> void:
	if choix < _haut:
		_haut = choix
	elif choix >= _haut + MAX_LIGNES:
		_haut = choix - MAX_LIGNES + 1
	_haut = clampi(_haut, 0, maxi(0, lignes.size() - MAX_LIGNES))

# ------------------------------------------------------------------ entrées

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	var vp := get_viewport()
	if e is InputEventKey:
		var k := e as InputEventKey
		vp.set_input_as_handled()      # aucune touche du jeu sous la fenêtre (E, Tab, I, F5, chiffres…)
		if not k.pressed:
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			return
		match k.physical_keycode:
			KEY_ESCAPE, KEY_TAB:
				fermer()
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				prendre()
			KEY_R:
				tout_prendre()
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
				prendre()
			JOY_BUTTON_Y:
				tout_prendre()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_DPAD_UP:
				_choisir(choix - 1)
			JOY_BUTTON_DPAD_DOWN:
				_choisir(choix + 1)
	elif e is InputEventMouseMotion:
		vp.set_input_as_handled()
		var z := _zone((e as InputEventMouseMotion).position)
		if z.begins_with("ligne:"):
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
				if z.begins_with("ligne:"):
					prendre(int(z.substr(6)))
				elif z == "prendre":
					prendre()
				elif z == "tout":
					tout_prendre()
				elif z == "fermer":
					fermer()

## Zone cliquable sous un point de l'écran (pixels de la fenêtre → repère logique de la vue).
func _zone(p: Vector2) -> String:
	var q := p / maxf(1.0, _vue.scale.x)
	for nom: String in _zones:
		if (_zones[nom] as Rect2).has_point(q):
			return nom
	return ""

# ------------------------------------------------------------------ dessin

func _process(_dt: float) -> void:
	if ouvert and EchelleUi.appliquer(_vue):
		_vue.queue_redraw()

func _texte(pos: Vector2, texte: String, couleur := MenuStyle.PARCHEMIN, largeur := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_vue.draw_string(_police, pos + Vector2(1, 1), texte, align, largeur, Palette.TAILLE_POLICE, MenuStyle.FOND)
	_vue.draw_string(_police, pos, texte, align, largeur, Palette.TAILLE_POLICE, couleur)

func _larg(texte: String) -> float:
	return ceilf(_police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x)

static func poids_texte(p: float) -> String:
	if p <= 0.0:
		return "-"
	return ("%d" % roundi(p)) if absf(p - roundf(p)) < 0.05 else ("%.1f" % p).replace(".", ",")

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

func _dessiner() -> void:
	if not ouvert:
		return
	var s := _vue.size
	_zones.clear()
	_vue.draw_rect(Rect2(Vector2.ZERO, s), Color(MenuStyle.FOND, 0.45))
	var vis := mini(lignes.size(), MAX_LIGNES)
	var w := clampf(s.x - 190.0, 280.0, 340.0)
	var h := 112.0 + vis * LIGNE
	var o := ((s - Vector2(w, h)) * 0.5).floor()
	_vue.draw_rect(Rect2(o + Vector2(6, 6), Vector2(w, h) - Vector2(12, 12)), Color(MenuStyle.FOND, 0.9))   # l'invite « E » ne transparaît pas
	_vue.draw_style_box(_cadre, Rect2(o, Vector2(w, h)))
	var gx := o.x + 16.0
	var dx := o.x + w - 16.0             # bord droit du texte
	var c_poids := dx                    # colonne « Poids » (alignée à droite)
	var c_nb := dx - 44.0                # colonne « Nb » (alignée à droite)
	# titre (gothique 24) et pièces versées
	var t := titre
	while t.length() > 4 and _gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x > w - 120.0:
		t = t.substr(0, t.length() - 2) + "…"
	MenuStyle.texte_detoure(_vue, _gothique, Vector2(gx, o.y + 29), t, MenuStyle.TITRE_GRAND, MenuStyle.OR)
	if pieces > 0:
		var tp := "+ %d pièces" % pieces
		_texte(Vector2(dx - _larg(tp), o.y + 27), tp, MenuStyle.OR)
	_vue.draw_rect(Rect2(gx, o.y + 35, w - 32.0, 1), FER)
	# en-têtes
	var y := o.y + 47.0
	_texte(Vector2(gx + 14.0, y), "Objet", MenuStyle.GRIS)
	_texte(Vector2(c_nb - _larg("Nb"), y), "Nb", MenuStyle.GRIS)
	_texte(Vector2(c_poids - _larg("Poids"), y), "Poids", MenuStyle.GRIS)
	y += 4.0
	# lignes
	for k in vis:
		var i := _haut + k
		var l: Dictionary = lignes[i]
		var r := Rect2(gx - 4.0, y, w - 24.0, LIGNE)
		_zones["ligne:%d" % i] = r
		var col := Color(ButinTables.COULEURS_RARETE.get(String(l["rarete"]), "#c8d0dc"))
		if i == choix:
			_vue.draw_rect(r, Color(MenuStyle.RUNE, 0.12))
			_vue.draw_rect(Rect2(r.position, Vector2(2, LIGNE)), Color(MenuStyle.RUNE, 0.7))
		var ico := _icone(String(l["id"]), String(l["rarete"]))
		var ts := ico.get_size()
		var cote := 12.0 if ts.x > 12.0 else ts.x
		_vue.draw_texture_rect(ico, Rect2(Vector2(gx, y + floorf((LIGNE - cote) * 0.5)), Vector2(cote, cote)), false)
		var nom: String = joueur.inventaire.nom(String(l["id"]))
		var larg_nom := c_nb - 30.0 - (gx + 14.0)
		while nom.length() > 4 and _larg(nom) > larg_nom:
			nom = nom.substr(0, nom.length() - 2) + "…"
		var c_txt := col.lightened(0.15) if i == choix else col
		_texte(Vector2(gx + 14.0, y + 11.0), nom, c_txt)
		var nb := "x%d" % int(l["n"])
		_texte(Vector2(c_nb - _larg(nb), y + 11.0), nb, MenuStyle.PARCHEMIN)
		var pt := poids_texte(float(Inventaire.objet(String(l["id"])).get("poids", 0.0)) * int(l["n"]))
		_texte(Vector2(c_poids - _larg(pt), y + 11.0), pt, MenuStyle.PARCHEMIN)
		y += LIGNE
	if lignes.size() > MAX_LIGNES:      # repères de défilement
		if _haut > 0:
			_texte(Vector2(dx - 6.0, o.y + 58.0), "^", MenuStyle.GRIS)
		if _haut + MAX_LIGNES < lignes.size():
			_texte(Vector2(dx - 6.0, y - 1.0), "v", MenuStyle.GRIS)
	# fiche de la ligne choisie
	y += 6.0
	_vue.draw_rect(Rect2(gx, y, w - 32.0, 1), FER)
	y += 13.0
	if choix < lignes.size():
		var l: Dictionary = lignes[choix]
		var id := String(l["id"])
		var f := Inventaire.objet(id)
		var rar := String(l["rarete"])
		var nr := String(ButinTables.NOMS_RARETE.get(rar, rar))
		var fiche := nr.substr(0, 1).to_upper() + nr.substr(1)
		if int(f.get("valeur", 0)) > 0:
			fiche += "   valeur %d" % int(f.get("valeur", 0))
		var desc := Consommables.description(id) if Consommables.est(id) else ""
		_texte(Vector2(gx, y), fiche, Color(ButinTables.COULEURS_RARETE.get(rar, "#c8d0dc")))
		if desc != "":
			var x := gx + _larg(fiche) + 10.0
			var d := desc
			while d.length() > 4 and x + _larg(d) > dx:
				d = d.substr(0, d.length() - 2) + "…"
			_texte(Vector2(x, y), d, MenuStyle.PARCHEMIN)
	# pied : actions (cliquables) et poids du sac
	y = o.y + h - 15.0
	var x0 := gx
	for a: Array in [["E", "Prendre", "prendre"], ["R", "Tout prendre", "tout"], ["Échap", "Fermer", "fermer"]]:
		var cle := "[%s]" % a[0]
		_texte(Vector2(x0, y), cle, MenuStyle.OR)
		var lx := x0 + _larg(cle) + 3.0
		_texte(Vector2(lx, y), a[1], MenuStyle.PARCHEMIN)
		var fin := lx + _larg(a[1])
		_zones[a[2]] = Rect2(x0 - 2.0, y - 11.0, fin - x0 + 4.0, LIGNE)
		x0 = fin + 10.0
	var ps: float = joueur.inventaire.poids()
	var sac := "Sac : %s" % (poids_texte(ps) if ps > 0.0 else "0")
	if x0 + _larg(sac) <= dx:
		_texte(Vector2(dx - _larg(sac), y), sac, MenuStyle.GRIS)
