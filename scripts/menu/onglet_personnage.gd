class_name OngletPersonnage
extends OngletMenu
## Onglet « Personnage » (lot D ; maquette A_parchemin/1_equipement, page « Registre ») : page gauche « Voyageur » = sceau de
## cire du niveau, barre d'XP, CHOIX D'ATTRIBUT (+10 vie / magie / vigueur, trois cartes) quand un niveau attend, attributs
## gravés, points d'arbre ; page droite « Registre » = niveau, vie / vigueur / magie, armure, charge, pièces, résistances,
## niveaux des 8 compétences. Le choix appelle Progression.choisir_attribut (aucune règle ici).
## Commandes : gauche / droite (flèches, croix, stick) ou survol = choisir une carte ; Entrée, D, clic, A = graver le choix.

const CARTES := ["vie", "magie", "vigueur"]
const Y_CARTES := 150.0

var carte := 0                    ## carte choisie (index dans CARTES)
var _avis := ""
var _avis_t := 0.0
var _police: FontFile
var _gothique: FontFile
var _sceau: ImageTexture

func id_onglet() -> String:
	return "personnage"

func titre() -> String:
	return "Personnage"

func aide() -> Array:
	if _attente() > 0:
		return [["Gauche / Droite", "Choisir"], ["Entrée", "Graver le choix"]]
	return []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_sceau = ImageTexture.create_from_image(Parchemin.sceau(20, 9))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_avis = ""
			queue_redraw()

func _attente() -> int:
	return joueur.progression.points_attribut if joueur != null else 0

func ouvrir() -> void:
	_avis = ""
	if joueur != null and not joueur.progression.change.is_connected(queue_redraw):
		joueur.progression.change.connect(queue_redraw)
	queue_redraw()

func fermer() -> void:
	if joueur != null and joueur.progression.change.is_connected(queue_redraw):
		joueur.progression.change.disconnect(queue_redraw)

## Grave le choix d'attribut de la carte choisie : réponse de Progression.choisir_attribut ("" = fait).
func choisir() -> String:
	if joueur == null:
		return "Aucun joueur."
	var nom: String = CARTES[carte]
	var r: String = joueur.progression.choisir_attribut(nom)
	if r == "":
		_avis = "+%d %s gravé." % [Progression.GAIN_ATTRIBUT, _nom_attribut(nom).to_lower()]
		Sons.jouer(self, ["sword-unsheathe"], -12.0)
	else:
		_avis = r
	_avis_t = 3.0
	message.emit(_avis)
	contenu_change.emit()
	queue_redraw()
	return r

func entree(e: InputEvent) -> bool:
	if _attente() <= 0:
		return false
	if e is InputEventMouseMotion:
		var i := _carte_sous(make_input_local(e).position)
		if i >= 0 and i != carte:
			carte = i
			queue_redraw()
		return i >= 0
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _carte_sous(make_input_local(e).position)
		if i < 0:
			return false
		carte = i
		choisir()
		return true
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_D:
		choisir()
		return true
	if e.is_action_pressed("ui_accept", false):
		choisir()
		return true
	if e.is_action_pressed("ui_left", true):
		carte = posmod(carte - 1, CARTES.size())
		queue_redraw()
		return true
	if e.is_action_pressed("ui_right", true):
		carte = posmod(carte + 1, CARTES.size())
		queue_redraw()
		return true
	return false

func _rect_carte(i: int) -> Rect2:
	return Rect2(20 + i * 99, Y_CARTES, 91, 66)

func _carte_sous(p: Vector2) -> int:
	var q := p - Parchemin.origine(size)
	for i in CARTES.size():
		if _rect_carte(i).has_point(q):
			return i
	return -1

static func _nom_attribut(nom: String) -> String:
	return {"vie": "Vie", "magie": "Magie", "vigueur": "Vigueur"}.get(nom, nom)

static func _couleur(nom: String) -> Color:
	return {"vie": Parchemin.VIE, "magie": Parchemin.MAGIE, "vigueur": Parchemin.VIGUEUR}.get(nom, Parchemin.BOIS)

## Nombre à la française : décimale à virgule, milliers séparés par une espace.
static func nombre(v: float, decimales := 0) -> String:
	var s := ("%." + str(decimales) + "f") % v
	var parts := s.split(".")
	var ent := parts[0]
	var neg := ent.begins_with("-")
	if neg:
		ent = ent.substr(1)
	var res := ""
	while ent.length() > 3:
		res = " " + ent.substr(ent.length() - 3) + res
		ent = ent.substr(0, ent.length() - 3)
	res = ("-" if neg else "") + ent + res
	return res + ("," + parts[1] if parts.size() > 1 else "")

func _max_attribut(nom: String) -> float:
	match nom:
		"vie": return joueur.vie_max
		"magie": return joueur.mana_max
		_: return joueur.vigueur_max

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if joueur == null:
		return
	draw_set_transform(Parchemin.origine(size))
	var pr: Progression = joueur.progression
	_page_gauche(pr)
	_page_droite(pr)
	draw_set_transform(Vector2.ZERO)

func _page_gauche(pr: Progression) -> void:
	Parchemin.titre(self, _gothique, _police, Vector2(20, 30), "Voyageur")
	# sceau du niveau
	var sp := Vector2(22, 64)
	draw_texture(_sceau, sp)
	var n := str(pr.niveau)
	var ln := Parchemin.largeur(_police, n, 32)
	var c := sp + _sceau.get_size() * 0.5
	draw_string(_police, Vector2(roundf(c.x - ln * 0.5) + 1, c.y + 11 + 1), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Parchemin.RUBRIQUE_SOMBRE)
	draw_string(_police, Vector2(roundf(c.x - ln * 0.5), c.y + 11), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Parchemin.OR_CLAIR)
	Parchemin.texte(self, _police, Vector2(78, 68), "Niveau %d" % pr.niveau, Parchemin.RUBRIQUE)
	Parchemin.texte_droite(self, _police, 312, 68, "%d %%" % roundi(pr.part_niveau() * 100.0), Parchemin.PALE)
	Parchemin.barre(self, Rect2(78, 83, 234, 7), pr.part_niveau(), Parchemin.BOIS)
	Parchemin.texte(self, _police, Vector2(78, 94), "%s / %s XP vers le niveau %d" % [nombre(floorf(pr.xp_niveau)), nombre(Progression.seuil_niveau(pr.niveau)), pr.niveau + 1], Parchemin.PALE)
	Parchemin.filet(self, 28, 122, 276)
	# choix d'attribut
	var att := pr.points_attribut
	Parchemin.texte(self, _police, Vector2(20, 130), "Choix d'attribut", Parchemin.RUBRIQUE)
	if att > 0:
		Parchemin.texte_droite(self, _police, 312, 130, "%d en attente" % att, Parchemin.RUBRIQUE)
		for i in CARTES.size():
			_carte(i, pr)
		var bas := _avis if _avis != "" else "Entrée : graver +%d en %s" % [Progression.GAIN_ATTRIBUT, _nom_attribut(CARTES[carte]).to_lower()]
		Parchemin.texte(self, _police, Vector2(20, 222), bas, Parchemin.RUBRIQUE if _avis == "" else Parchemin.ENCRE)
	else:
		var l := Parchemin.couper(_police, "Aucun choix en attente. Chaque niveau gagné en apporte un : +%d à la vie, à la magie ou à la vigueur (la vigueur porte aussi +%d de charge)." % [Progression.GAIN_ATTRIBUT, roundi(Progression.GAIN_ATTRIBUT * Progression.CHARGE_PAR_VIGUEUR)], 290)
		for j in mini(l.size(), 5):
			Parchemin.texte(self, _police, Vector2(20, 150 + j * 11), l[j], Parchemin.PALE)
		if _avis != "":
			Parchemin.texte(self, _police, Vector2(20, 222), _avis, Parchemin.ENCRE)
	Parchemin.filet(self, 28, 242, 276)
	Parchemin.texte(self, _police, Vector2(20, 250), "Attributs gravés", Parchemin.RUBRIQUE)
	var x := 20.0
	for nom: String in CARTES:
		var s := "%s +%d" % [_nom_attribut(nom), int(pr.attributs[nom])]
		Parchemin.texte(self, _police, Vector2(x, 264), s, Parchemin.ENCRE)
		x += Parchemin.largeur(_police, s) + 16.0
	Parchemin.texte(self, _police, Vector2(20, 282), "Points d'arbre", Parchemin.RUBRIQUE)
	Parchemin.texte(self, _police, Vector2(112, 282), "%d à dépenser" % pr.points_perk if pr.points_perk > 0 else "aucun", Parchemin.ENCRE)
	Parchemin.texte(self, _police, Vector2(20, 296), "(onglet Compétences)" if pr.points_perk > 0 else "(1 par niveau gagné)", Parchemin.PALE)
	if joueur.get("benediction"):
		Parchemin.texte(self, _police, Vector2(20, 312), "Bénédiction des ancêtres : +10 vie", Parchemin.OR_TERNI)

## Carte de choix : vélin clair, bandeau de couleur, « +10 Vie », valeur avant → après (+ charge pour la vigueur).
func _carte(i: int, _pr: Progression) -> void:
	var nom: String = CARTES[i]
	var r := _rect_carte(i)
	var sel := i == carte
	draw_rect(r, Parchemin.RUBRIQUE if sel else Parchemin.ENCRE)
	draw_rect(r.grow(-1), Parchemin.VELIN[6] if sel else Parchemin.VELIN[5])
	if sel:
		draw_rect(r.grow(-1), Parchemin.OR_VIF, false, 1.0)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 4), _couleur(nom))
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 1), Color(Parchemin.CLAIR, 0.5))
	var t := "+%d %s" % [Progression.GAIN_ATTRIBUT, _nom_attribut(nom)]
	Parchemin.texte(self, _police, Vector2(r.position.x, r.position.y + 11), t, Parchemin.RUBRIQUE if sel else Parchemin.ENCRE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var avant := _max_attribut(nom)
	Parchemin.texte(self, _police, Vector2(r.position.x, r.position.y + 27), "%s > %s" % [nombre(avant), nombre(avant + Progression.GAIN_ATTRIBUT)], Parchemin.ENCRE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var sous := "+%d charge" % roundi(Progression.GAIN_ATTRIBUT * Progression.CHARGE_PAR_VIGUEUR) if nom == "vigueur" else ("jauge de vie" if nom == "vie" else "jauge de magie")
	Parchemin.texte(self, _police, Vector2(r.position.x, r.position.y + 43), sous, Parchemin.PALE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if sel:
		Parchemin.ruban(self, Rect2(r.position.x + r.size.x * 0.5 - 7, r.end.y - 2, 14, 8))

func _page_droite(pr: Progression) -> void:
	var X := 336.0
	var D := 618.0
	Parchemin.titre(self, _gothique, _police, Vector2(X, 30), "Registre")
	Parchemin.texte(self, _police, Vector2(X, 66), "Niveau", Parchemin.RUBRIQUE)
	Parchemin.texte(self, _police, Vector2(X + 50, 66), str(pr.niveau), Parchemin.ENCRE)
	Parchemin.barre(self, Rect2(X + 72, 68, 150, 7), pr.part_niveau(), Parchemin.BOIS)
	Parchemin.texte_droite(self, _police, D, 66, "%d %%" % roundi(pr.part_niveau() * 100.0), Parchemin.PALE)
	var lignes := [["Vie", joueur.vie, joueur.vie_max, Parchemin.VIE], ["Vigueur", joueur.vigueur, joueur.vigueur_max, Parchemin.VIGUEUR],
		["Magie", joueur.mana, joueur.mana_max, Parchemin.MAGIE]]
	for j in lignes.size():
		var l: Array = lignes[j]
		var y := 82.0 + j * 15.0
		Parchemin.texte(self, _police, Vector2(X, y), l[0], Parchemin.RUBRIQUE)
		Parchemin.barre(self, Rect2(X + 72, y + 2, 150, 7), float(l[1]) / maxf(1.0, float(l[2])), l[3])
		Parchemin.texte_droite(self, _police, D, y, "%d/%d" % [roundi(float(l[1])), roundi(float(l[2]))], Parchemin.ENCRE)
	Parchemin.filet(self, X + 8, 134, 266)
	var inv: Inventaire = joueur.inventaire
	_kv(X, 142, "Armure", str(roundi(joueur.equipement_corps.armure_totale())))
	_kv(X + 138, 142, "Charge", "%s / %s" % [nombre(inv.poids(), 1), nombre(inv.capacite())], Parchemin.RUBRIQUE if inv.surcharge() else Parchemin.ENCRE)
	_kv(X, 156, "Pièces", nombre(inv.pieces), Parchemin.OR_TERNI)
	_kv(X + 138, 156, "Points", "%d d'arbre" % pr.points_perk)
	Parchemin.texte(self, _police, Vector2(X, 172), "Résistances", Parchemin.RUBRIQUE)
	var res := []
	for r: Array in [["Froid", "resist_froid"], ["Feu", "resist_feu"], ["Choc", "resist_choc"]]:
		res.append("%s %d %%" % [r[0], roundi(pr.bonus(r[1]) * 100.0)])
	Parchemin.texte(self, _police, Vector2(X + 76, 172), "  ·  ".join(res), Parchemin.ENCRE)
	Parchemin.filet(self, X + 8, 190, 266)
	Parchemin.texte(self, _police, Vector2(X, 198), "Compétences", Parchemin.RUBRIQUE)
	for i in Progression.COMPETENCES.size():
		var nom: String = Progression.COMPETENCES[i]
		var x := X + (i / 4) * 146.0
		var y := 214.0 + (i % 4) * 22.0
		Parchemin.texte(self, _police, Vector2(x, y), Parchemin.nom_competence(nom), Parchemin.ENCRE)
		Parchemin.texte_droite(self, _police, x + 128, y, str(pr.competence(nom)), Parchemin.ENCRE)
		Parchemin.barre(self, Rect2(x, y + 13, 128, 4), _part_competence(nom), Parchemin.BOIS)

func _kv(x: float, y: float, k: String, v: String, col := Parchemin.ENCRE) -> void:
	Parchemin.texte(self, _police, Vector2(x, y), k, Parchemin.RUBRIQUE)
	Parchemin.texte(self, _police, Vector2(x + 52, y), v, col)

func _part_competence(nom: String) -> float:
	var i := Progression.interne(nom)
	var c: Competences = joueur.progression.competences
	return clampf(c.progression(i), 0.0, 1.0) if c.niveaux.has(i) else 0.0
