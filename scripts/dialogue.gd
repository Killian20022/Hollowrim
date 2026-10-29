extends Control
## Dialogues des villageois : invite « E Parler », boîte de conversation
## avec texte machine à écrire, et sous-titres des phrases lancées au passage.
## Positions relatives à `size` (écran logique, voir EchelleUi) : boîte centrée en bas, 320 px de large
## à 480x270, jusqu'à 420 px à 640x360 ; tout est replacé par _placer() quand la taille change.
## Propriété à poser AVANT add_child : joueur.
## Lot L8 : un villageois MARCHAND (data/marchands.json : Brodd, Grima) affiche « [T] Commercer » en haut à droite de la boîte
## pendant toute la conversation, puis, sur la dernière réplique, le choix « Commercer / Au revoir » (flèches ou Z/S, E / Entrée
## = valider ; T = commercer tout de suite) ; « Commercer » ferme le dialogue et ouvre la boutique (Marchand.ouvrir).
## Manette : A = suite / valider, B = fermer, X = commercer, croix haut/bas = choisir.

const VITESSE_TEXTE := 45.0  # caractères par seconde
const DIST_FERMETURE := 4.0
const DUREE_SOUS_TITRE := 3.5
const TAILLE_POLICE := Palette.TAILLE_POLICE   # taille native de la police pixel (voir Palette.police)
const HAUT_BOITE := 58.0
const BAS_BOITE := 18.0  # marge sous la boîte (et sous les sous-titres)
const OR := Color("#e8a64a")
const PARCHEMIN := Color("#e9dcc0")
const FOND := Color("#0b0f1a")
const CHEMINS := {
	"cadre": "res://assets/ui/dialogue_cadre.svg",
	"nom": "res://assets/ui/dialogue_nom.svg",
	"touche": "res://assets/ui/touche_e.svg",
	"suite": "res://assets/ui/suite.svg",
}

var joueur: CharacterBody3D

var _police: FontFile
var _invite_nom := ""     # nom de l'objet sous l'invite (« Grand coffre ») quand le verbe ne le dit pas déjà
var _invite_larg := 0.0
var _tex := {}
var _invites: Array[Node3D] = []
var _pnj: Node3D = null
var _lignes: Array = []
var _index := 0
var _t := 0.0
var _ouvert := false
var _sous_titre_t := 0.0

var _invite: Control
var _invite_texte: Label
var _boite: Control
var _texte: Label
var _nom: Label
var _cartouche: Control
var _fleche: Control
var _sous_titre: Label
var _marchand := ""        # id de marchand du PNJ en conversation ("" = il ne commerce pas)
var _choix_vis := false    # choix « Commercer / Au revoir » affiché (dernière réplique)
var _choix := 0            # 0 = Commercer, 1 = Au revoir
var _carte_cmd: Control    # cartouche « [T] Commercer » (haut droit de la boîte)
var _choix_ui: Control     # panneau des choix (au-dessus de la boîte, à droite)
const CHOIX := ["Commercer", "Au revoir"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police = Palette.police()
	for cle: String in CHEMINS:
		_tex[cle] = load(CHEMINS[cle]) if ResourceLoader.exists(CHEMINS[cle]) else null

	# invite « E Parler à … »
	_invite = Control.new()
	_invite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_invite.visible = false
	add_child(_invite)
	_invite_texte = _etiquette(PARCHEMIN)
	_invite.add_child(_invite_texte)

	# boîte de conversation (taille et position : _placer)
	_boite = _cadre("cadre", 8, Rect2(0, 0, 320, HAUT_BOITE))
	_boite.visible = false
	add_child(_boite)
	_texte = _etiquette(PARCHEMIN)
	_texte.position = Vector2(10, 9)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.clip_text = true
	_boite.add_child(_texte)
	_cartouche = _cadre("nom", 4, Rect2(8, -7, 60, 14))
	_boite.add_child(_cartouche)
	_nom = _etiquette(OR)
	_nom.position = Vector2(6, 0)
	_cartouche.add_child(_nom)
	_fleche = _dessin_fleche()
	_boite.add_child(_fleche)
	# lot L8 : commerce (marchands)
	_carte_cmd = _cadre("nom", 4, Rect2(0, -7, 80, 14))
	_carte_cmd.visible = false
	_boite.add_child(_carte_cmd)
	var cmd := _etiquette(PARCHEMIN)
	cmd.name = "Texte"
	cmd.position = Vector2(6, 0)
	_carte_cmd.add_child(cmd)
	_choix_ui = _cadre("cadre", 8, Rect2(0, 0, 92, 38))
	_choix_ui.visible = false
	_boite.add_child(_choix_ui)
	var dessin := Control.new()
	dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dessin.draw.connect(func() -> void:
		for i in CHOIX.size():
			var y := 15.0 + i * 13.0
			var c := OR if i == _choix else PARCHEMIN
			if i == _choix:
				dessin.draw_string(_police, Vector2(8, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, c)
			dessin.draw_string(_police, Vector2(18, y + 1), CHOIX[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, FOND)
			dessin.draw_string(_police, Vector2(17, y), CHOIX[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, c))
	_choix_ui.add_child(dessin)

	# sous-titre « au passage »
	_sous_titre = _etiquette(PARCHEMIN)
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sous_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sous_titre.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_sous_titre.modulate.a = 0.0
	add_child(_sous_titre)
	EchelleUi.appliquer(self)
	_placer()

## Place la boîte et les sous-titres d'après la taille logique de l'écran (coordonnées entières).
func _placer() -> void:
	var larg := clampf(size.x - 160.0, 320.0, 420.0)
	var cx := floorf(size.x * 0.5)
	_boite.position = Vector2(cx - floorf(larg * 0.5), size.y - BAS_BOITE - HAUT_BOITE)
	_boite.size = Vector2(larg, HAUT_BOITE)
	_texte.size = Vector2(larg - 28, HAUT_BOITE - 14)
	_fleche.position = Vector2(larg - 16, HAUT_BOITE - 9)
	_sous_titre.size = Vector2(larg, 20)
	_sous_titre.position = Vector2(cx - floorf(larg * 0.5), size.y - BAS_BOITE - _sous_titre.size.y)
	_carte_cmd.position = Vector2(larg - 8.0 - _carte_cmd.size.x, -7)
	_choix_ui.position = Vector2(larg - _choix_ui.size.x, -_choix_ui.size.y - 9.0)

func _etiquette(couleur: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _police)
	l.add_theme_font_size_override("font_size", TAILLE_POLICE)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_shadow_color", FOND)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("line_spacing", 1)
	return l

## NinePatch si la texture existe, sinon un cadre dessiné à la main.
func _cadre(cle: String, marge: int, zone: Rect2) -> Control:
	var c: Control
	if _tex[cle] != null:
		var np := NinePatchRect.new()
		np.texture = _tex[cle]
		np.patch_margin_left = marge
		np.patch_margin_right = marge
		np.patch_margin_top = marge
		np.patch_margin_bottom = marge
		c = np
	else:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(FOND, 0.85)
		sb.border_color = OR
		sb.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", sb)
		c = p
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = zone.position
	c.size = zone.size
	return c

func _dessin_fleche() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(5, 3)
	c.draw.connect(func() -> void:
		if _tex["suite"] != null:
			c.draw_texture(_tex["suite"], Vector2.ZERO)
		else:
			c.draw_rect(Rect2(0, 0, 5, 1), OR)
			c.draw_rect(Rect2(1, 1, 3, 1), OR)
			c.draw_rect(Rect2(2, 2, 1, 1), OR))
	return c

func inviter(pnj: Node3D) -> void:
	if not _invites.has(pnj):
		_invites.append(pnj)

func retirer_invite(pnj: Node3D) -> void:
	_invites.erase(pnj)

func dire_au_passage(nom: String, texte: String) -> void:
	if _ouvert:
		return
	_sous_titre.text = "%s : %s" % [nom, texte]
	_sous_titre_t = DUREE_SOUS_TITRE
	_sous_titre.modulate.a = 1.0

func _plus_proche() -> Node3D:
	var meilleur: Node3D = null
	var d_min := INF
	for p in _invites.duplicate():
		# une invite dont le nœud ne tourne plus (grotte refermée : process désactivé, hors de l'arbre) ne peut plus se retirer
		# elle-même : sans ce nettoyage elle restait « fantôme » et E renvoyait devant la grotte depuis n'importe où
		if not is_instance_valid(p) or not p.is_inside_tree() or not p.can_process():
			_invites.erase(p)
			continue
		var d := joueur.global_position.distance_squared_to(p.global_position)
		if d < d_min:
			d_min = d
			meilleur = p
	return meilleur

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton and e.pressed:
		_manette((e as InputEventJoypadButton).button_index)
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var touche: Key = e.physical_keycode
	if touche == KEY_E or (_choix_vis and touche in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
		if _ouvert:
			_suite()
			get_viewport().set_input_as_handled()
		elif _plus_proche() != null and not joueur.mort:
			_ouvrir(_plus_proche())
			get_viewport().set_input_as_handled()
	elif touche == KEY_ESCAPE and _ouvert:
		_fermer()
		get_viewport().set_input_as_handled()
	elif touche == KEY_T and _ouvert and _marchand != "":
		commercer()
		get_viewport().set_input_as_handled()
	elif _choix_vis and touche in [KEY_UP, KEY_DOWN, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT]:
		_choisir(1 - _choix)
		get_viewport().set_input_as_handled()

## Manette (lot L8) : A = parler / suite / valider, B = fermer, X = commercer, croix = choisir.
func _manette(b: JoyButton) -> void:
	match b:
		JOY_BUTTON_A:
			if _ouvert:
				_suite()
			elif _plus_proche() != null and not joueur.mort:
				_ouvrir(_plus_proche())
			else:
				return
		JOY_BUTTON_B:
			if not _ouvert:
				return
			_fermer()
		JOY_BUTTON_X:
			if not _ouvert or _marchand == "":
				return
			commercer()
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			if not _choix_vis:
				return
			_choisir(1 - _choix)
		_:
			return
	get_viewport().set_input_as_handled()

## Dernière réplique d'un marchand : choix « Commercer / Au revoir » (Commercer choisi d'office).
func _montrer_choix() -> void:
	_choix_vis = true
	_choix = 0
	_choix_ui.visible = true
	_carte_cmd.visible = false
	_choix_ui.get_child(0).queue_redraw()

func _choisir(i: int) -> void:
	_choix = clampi(i, 0, CHOIX.size() - 1)
	_choix_ui.get_child(0).queue_redraw()

## Lot L8 : ferme la conversation et ouvre la boutique du marchand (si la boutique existe dans la scène).
func commercer() -> bool:
	if not _ouvert or _marchand == "":
		return false
	var id := _marchand
	var nom := _nom.text
	_fermer()
	var m := Marchand.trouver(self)
	return m != null and m.ouvrir(id, nom)

func _ouvrir(pnj: Node3D) -> void:
	_lignes = pnj.parler()
	if _lignes.is_empty():
		return
	_pnj = pnj
	_ouvert = true
	_index = 0
	joueur.en_dialogue = true
	_sous_titre.modulate.a = 0.0
	_sous_titre_t = 0.0
	_nom.text = pnj.nom_affiche()
	_marchand = Marchand.pour_pnj(pnj)
	_choix_vis = false
	_choix_ui.visible = false
	_carte_cmd.visible = _marchand != ""
	if _marchand != "":
		var lc := _carte_cmd.get_node("Texte") as Label
		lc.text = "[T] Commercer"
		_carte_cmd.size.x = ceilf(_police.get_string_size(lc.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x) + 12.0
		lc.size = Vector2(_carte_cmd.size.x, 14)
		_placer()
	_cartouche.size.x = ceilf(_police.get_string_size(_nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x) + 12.0
	_nom.size = Vector2(_cartouche.size.x, 14)
	_boite.visible = true
	_afficher_ligne()
	Sons.jouer(self, ["cloth1"], -14.0)

func _afficher_ligne() -> void:
	_texte.text = str(_lignes[_index])
	_texte.visible_characters = 0
	_t = 0.0

func _suite() -> void:
	if _texte.visible_characters < _texte.text.length():
		_texte.visible_characters = _texte.text.length()
		_t = maxf(_t, float(_texte.text.length()) / VITESSE_TEXTE)   # sinon _process remettait la machine à écrire en arrière
		return
	if _choix_vis:     # dernière réplique d'un marchand : E valide le choix
		if _choix == 0:
			commercer()
		else:
			_fermer()
		return
	if _marchand != "" and _index >= _lignes.size() - 1:
		_montrer_choix()
		return
	_index += 1
	if _index >= _lignes.size():
		_fermer()
	else:
		_afficher_ligne()

func _fermer() -> void:
	_ouvert = false
	_boite.visible = false
	_choix_vis = false
	_choix_ui.visible = false
	joueur.en_dialogue = false
	if _pnj != null and is_instance_valid(_pnj) and _pnj.has_method("fin_conversation"):
		_pnj.fin_conversation()
	_pnj = null

func _process(dt: float) -> void:
	if EchelleUi.appliquer(self):
		_placer()
	if joueur == null:
		return
	if _ouvert:
		if _pnj == null or not is_instance_valid(_pnj) or joueur.mort \
				or joueur.global_position.distance_to(_pnj.global_position) > DIST_FERMETURE:
			_fermer()
		else:
			_t += dt
			var n := mini(int(_t * VITESSE_TEXTE), _texte.text.length())
			_texte.visible_characters = n
			_fleche.visible = n >= _texte.text.length() and fmod(_t, 0.8) < 0.5
			if _marchand != "" and not _choix_vis and n >= _texte.text.length() and _index >= _lignes.size() - 1:
				_montrer_choix()
			if _choix_vis:
				_fleche.visible = false
			_fleche.queue_redraw()
	# invite
	var p := _plus_proche() if not _ouvert else null
	if _invite.visible != (p != null):
		queue_redraw()  # sans cela, l'icône « E » dessinée restait affichée après l'invite
	_invite.visible = p != null
	if p != null:
		# un objet peut proposer son propre verbe (« Fouiller le corps », « Entrer »…)
		_invite_texte.text = p.texte_action() if p.has_method("texte_action") else "Parler à %s" % p.nom_affiche()
		var l := ceilf(_police.get_string_size(_invite_texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x)
		var icone: Texture2D = _tex["touche"]
		var larg_icone := 11.0 if icone != null else _police.get_string_size("[E] ", HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		if icone == null:
			_invite_texte.text = "[E] " + _invite_texte.text
		var total := l + larg_icone + (4.0 if icone != null else 0.0)
		_invite_larg = total
		var nom_obj: String = String(p.nom_affiche()) if p.has_method("nom_affiche") else ""
		_invite_nom = nom_obj if nom_obj != "" and _invite_texte.text.to_lower().find(nom_obj.to_lower()) < 0 else ""
		_invite.position = Vector2(roundf(floorf(size.x * 0.5) - total * 0.5), floorf(size.y * 0.5) + 15.0)  # sous le réticule
		_invite_texte.position = Vector2(larg_icone + (4.0 if icone != null else 0.0), 0) if icone != null else Vector2.ZERO
		queue_redraw()
	# sous-titre
	if _sous_titre_t > 0.0:
		_sous_titre_t -= dt
		_sous_titre.modulate.a = clampf(_sous_titre_t / 0.6, 0.0, 1.0)

func _draw() -> void:
	# lot L7 : bandeau sombre sous l'invite (lisible sur la neige), nom de l'objet en or dessous (« Grand coffre ») ; police du
	# corps : le gothique 12 px est illisible à cette taille, le 24 px trop gros sous le réticule
	if _invite != null and _invite.visible:
		var ln := _police.get_string_size(_invite_nom, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x if _invite_nom != "" else 0.0
		var lb := ceilf(maxf(_invite_larg, ln)) + 10.0
		draw_rect(Rect2(floorf(floorf(size.x * 0.5) - lb * 0.5), _invite.position.y, lb, 15.0 if _invite_nom == "" else 27.0), Color(FOND, 0.55))
		if _invite_nom != "":
			MenuStyle.texte_detoure(self, _police, Vector2(roundf(floorf(size.x * 0.5) - ln * 0.5), _invite.position.y + 23.0), _invite_nom, TAILLE_POLICE, OR, 0.9)
	# icône de la touche E à côté de l'invite
	if _invite != null and _invite.visible and _tex["touche"] != null:
		draw_texture(_tex["touche"], _invite.position + Vector2(0, 2))
