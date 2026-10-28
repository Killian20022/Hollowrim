class_name InventaireMains
extends CanvasLayer
## Écran d'inventaire des deux mains (touche I, action « inventaire » reconfigurable ; jeu en PAUSE pendant qu'il est ouvert).
##   - en haut : ce que tient chaque main (gauche en bleu, droite en or, comme le HUD) ;
##   - catégories Armes / Sorts / Divers (A/E au clavier AZERTY = touches physiques Q/E, LB/RB à la manette) ;
##   - liste des objets possédés (icônes du HUD : IconesCombat) et fiche de l'objet choisi (dégâts, mana, vitesse, effet) ;
##   - ÉQUIPER : clic gauche (ou Entrée, D, A manette) = main droite ; clic droit (ou G, X manette) = main gauche, comme en
##     combat. Une action impossible n'est jamais muette : la fiche dit d'avance pour chaque main pourquoi (« Le bouclier se
##     porte au bras gauche. ») et le bandeau du bas répète la raison si on essaie quand même ;
##   - RACCOURCIS 1-0 : appuyer sur un chiffre (ou cliquer une case) range les deux mains ACTUELLES dans ce raccourci (paire
##     G|D, lue telle quelle par la barre du HUD) ; clic droit sur une case = la vider. Sauvegardés avec la partie.
## Aucune règle ici : tout passe par EquipementMains (objets_possedes, fiche, essai, assigner_raccourci) et MainSort.equiper,
## eux-mêmes pilotés par data/magie/regles_mains.json et data/magie/inventaire.json.

const BLEU := Color("#6f9be8")
const ROUGE := Color("#e0574a")
const FER := Color("#3a4458")

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
var categorie := "armes"
## Dernier message du bandeau (tests).
var message := ""
## Objet dont la fiche est affichée.
var choisi := ""

var _racine: Control
var _liste: VBoxContainer
var _defile: ScrollContainer
var _cats: Array[Button] = []
var _cases: Array[Button] = []
var _main_ui := {}
var _fiche: VBoxContainer
var _avis: Label
var _aide: Label
var _souris := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	layer = 45   # sous le menu pause (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("inventaire"):
		InputMap.add_action("inventaire")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_I
		InputMap.action_add_event("inventaire", e)
	_construire()

func _magie() -> Node:
	if joueur == null or joueur.get("mains") == null:
		return null
	return joueur.mains.get("magie")

func _eq() -> EquipementMains:
	var m := _magie()
	return m.eq if m != null else null

## Identifiant de ce que tient une main, au format des raccourcis et du catalogue ("vide" pour la main nue).
func tenu(m: String) -> String:
	var eq := _eq()
	if eq == null or eq.categorie(m) == "vide":
		return "vide"
	return String(eq.mains[m].get("id", "vide"))

# ------------------------------------------------------------------ construction

func _construire() -> void:
	_racine = Control.new()
	_racine.theme = MenuStyle.theme()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.visible = false
	add_child(_racine)
	var voile := ColorRect.new()
	voile.color = Color(MenuStyle.FOND, 0.82)   # le HUD (objectif, barre) ne doit pas transparaître dans le panneau
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(612, 0)
	centre.add_child(panneau)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panneau.add_child(v)

	# titre
	var haut := HBoxContainer.new()
	v.add_child(haut)
	haut.add_child(MenuStyle.etiquette("Inventaire", MenuStyle.OR))
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(vide)
	_aide = MenuStyle.etiquette("", MenuStyle.GRIS)
	haut.add_child(_aide)

	# les deux mains
	var mains := HBoxContainer.new()
	mains.add_theme_constant_override("separation", 6)
	v.add_child(mains)
	for m in ["gauche", "droite"]:
		mains.add_child(_emplacement(m))

	# catégories | liste | fiche
	var milieu := HBoxContainer.new()
	milieu.add_theme_constant_override("separation", 6)
	v.add_child(milieu)
	var cats := VBoxContainer.new()
	cats.custom_minimum_size = Vector2(66, 0)
	cats.add_theme_constant_override("separation", 0)
	milieu.add_child(cats)
	var eq_cat: Array = EquipementMains._lire(EquipementMains.FICHIER_INVENTAIRE).get("categories", [])
	for c: Dictionary in eq_cat:
		var id := String(c.get("id", ""))
		var b := MenuStyle.bouton(String(c.get("nom", id)), func() -> void: _changer_categorie(id))
		b.set_meta("id", id)
		cats.add_child(b)
		_cats.append(b)
	milieu.add_child(_separateur())
	_defile = ScrollContainer.new()
	_defile.custom_minimum_size = Vector2(214, 168)
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	milieu.add_child(_defile)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 0)
	_defile.add_child(_liste)
	milieu.add_child(_separateur())
	_fiche = VBoxContainer.new()
	_fiche.custom_minimum_size = Vector2(268, 0)
	_fiche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fiche.add_theme_constant_override("separation", -2)
	milieu.add_child(_fiche)

	# raccourcis 1-0
	var titre_r := MenuStyle.etiquette("Raccourcis : 1-0 ou clic = y ranger vos deux mains, clic droit = vider", MenuStyle.GRIS)
	v.add_child(titre_r)
	var barre := HBoxContainer.new()
	barre.alignment = BoxContainer.ALIGNMENT_CENTER
	barre.add_theme_constant_override("separation", 3)
	v.add_child(barre)
	for i in 10:
		var b := _case_raccourci(i)
		barre.add_child(b)
		_cases.append(b)

	_avis = MenuStyle.etiquette("", MenuStyle.RUNE)
	_avis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avis.custom_minimum_size = Vector2(580, 0)
	v.add_child(_avis)

func _separateur() -> Control:
	var s := ColorRect.new()
	s.color = Color(FER, 0.8)
	s.custom_minimum_size = Vector2(1, 0)
	return s

func _cadre(bord: Color) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = Color(MenuStyle.FOND, 0.85)
	c.border_color = bord
	c.set_border_width_all(1)
	c.anti_aliasing = false
	c.content_margin_left = 4
	c.content_margin_right = 4
	c.content_margin_top = 2
	c.content_margin_bottom = 2
	return c

func _icone_rect(cote: int) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(cote, cote)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Emplacement d'une main (aperçu en haut) : icône 32 px (16 px doublés, nets), « Main gauche », nom de l'objet.
func _emplacement(m: String) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _cadre(BLEU if m == "gauche" else MenuStyle.OR))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var ico := _icone_rect(32)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", -3)
	var titre := MenuStyle.etiquette("Main gauche  (clic droit)" if m == "gauche" else "Main droite  (clic gauche)", BLEU if m == "gauche" else MenuStyle.OR)
	var nom := MenuStyle.etiquette("")
	t.add_child(titre)
	t.add_child(nom)
	if m == "gauche":
		h.add_child(ico)
		h.add_child(t)
	else:
		h.alignment = BoxContainer.ALIGNMENT_END
		titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(t)
		h.add_child(ico)
	_main_ui[m] = {"icone": ico, "nom": nom}
	return p

## Case de raccourci : icône main gauche | icône main droite, numéro de la touche dessous.
func _case_raccourci(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 34)
	b.focus_mode = Control.FOCUS_ALL
	b.button_mask = 0   # la souris passe par gui_input (gauche = ranger, droite = vider) ; Entrée / A : ranger
	var cadre := _cadre(FER)
	b.add_theme_stylebox_override("normal", cadre)
	var foc := _cadre(MenuStyle.RUNE)
	foc.bg_color = Color(MenuStyle.RUNE, 0.12)
	for s in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, foc)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var g := _icone_rect(16)
	var d := _icone_rect(16)
	h.add_child(g)
	h.add_child(d)
	var n := MenuStyle.etiquette(str((i + 1) % 10), MenuStyle.PARCHEMIN)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	b.set_meta("g", g)
	b.set_meta("d", d)
	b.set_meta("n", n)
	b.pressed.connect(func() -> void: memoriser(i))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				memoriser(i)
				b.accept_event()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				vider_raccourci(i)
				b.accept_event())
	return b

# ------------------------------------------------------------------ ouverture

func ouvrir() -> void:
	if ouvert or _eq() == null:
		return
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false   # le panneau Tab se ferme, l'inventaire prend sa place (toujours en pause)
	ouvert = true
	get_tree().paused = true
	_souris = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_racine.visible = true
	message = ""
	_avis.text = ""
	var cle_a := ""
	var cle_e := ""
	if DisplayServer.get_name() != "headless":   # disposition du clavier (AZERTY : A / E)
		cle_a = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_Q))
		cle_e = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_E))
	_aide.text = "%s / %s : catégorie   I / Échap : fermer" % [cle_a if cle_a != "" else "Q", cle_e if cle_e != "" else "E"]
	Sons.jouer(self, ["cloth1", "cloth2"], -10.0)
	_changer_categorie(categorie)

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_racine.visible = false
	get_tree().paused = false
	Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	Sons.jouer(self, ["cloth1", "cloth2"], -12.0)

func basculer() -> void:
	if ouvert:
		fermer()
	else:
		ouvrir()

func _peut_ouvrir() -> bool:
	if joueur == null or joueur.get("mort") or joueur.get("en_dialogue"):
		return false
	if get_tree().paused and not (hud != null and hud.get("panneau_ouvert")):
		return false   # menu pause, écran de chargement…
	return true

func _unhandled_input(e: InputEvent) -> void:
	if ouvert or not e.is_action_pressed("inventaire") or (e is InputEventKey and e.echo):
		return
	if _peut_ouvrir():
		get_viewport().set_input_as_handled()
		ouvrir()

## Ouvert : I / Échap / B ferment, chiffres = raccourcis, G = main gauche, D = main droite, Q/E ou LB/RB = catégorie ;
## les touches du jeu (Tab, T, V, F5…) ne font rien.
func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	var vp := get_viewport()
	if e is InputEventKey:
		var k := e as InputEventKey
		if not k.pressed:
			if k.physical_keycode in [KEY_TAB, KEY_E, KEY_F5, KEY_F9, KEY_P, KEY_T, KEY_V, KEY_Q, KEY_G, KEY_D]:
				vp.set_input_as_handled()
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN]):
			vp.set_input_as_handled()
			return
		if k.physical_keycode == KEY_ESCAPE or e.is_action_pressed("inventaire"):
			vp.set_input_as_handled()
			fermer()
			return
		for i in 10:
			if e.is_action_pressed("raccourci_%d" % ((i + 1) % 10)):
				vp.set_input_as_handled()
				memoriser(i)
				return
		match k.physical_keycode:
			KEY_Q:
				_categorie_voisine(-1)
			KEY_E:
				_categorie_voisine(1)
			KEY_G:
				equiper("gauche", choisi)
			KEY_D:
				equiper("droite", choisi)
			KEY_TAB, KEY_F5, KEY_F9, KEY_P, KEY_T, KEY_V:
				pass
			_:
				return
		vp.set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed:
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER:
				_categorie_voisine(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_categorie_voisine(1)
			JOY_BUTTON_X:
				equiper("gauche", choisi)
			_:
				return
		vp.set_input_as_handled()

# ------------------------------------------------------------------ actions

func _changer_categorie(id: String) -> void:
	categorie = id
	for b in _cats:
		var actif := String(b.get_meta("id")) == id
		b.add_theme_color_override("font_color", MenuStyle.OR if actif else MenuStyle.PARCHEMIN)
	_remplir_liste()
	_rafraichir()

func _categorie_voisine(sens: int) -> void:
	if _cats.is_empty():
		return
	var i := 0
	for k in _cats.size():
		if String(_cats[k].get_meta("id")) == categorie:
			i = k
	_changer_categorie(String(_cats[(i + sens + _cats.size()) % _cats.size()].get_meta("id")))

## Équipe `id` dans `main` par MainSort.equiper (coupe l'incantation de la main, règles de regles_mains.json).
## Renvoie "" ou la raison du refus (affichée dans le bandeau).
func equiper(main: String, id: String) -> String:
	var eq := _eq()
	if eq == null or id == "":
		return "Rien à équiper."
	if id.begins_with("sac:"):
		return _dire("Cet objet ne se tient pas en main.", true)
	var cote := "gauche" if main == "gauche" else "droite"
	if tenu(main) == id:
		return _dire("%s est déjà dans la main %s." % [eq.fiche(id)["nom"], cote], false)
	var essai := eq.essai(main, id)
	if String(essai["refus"]) != "":
		Sons.jouer(self, ["cloth1"], -18.0)
		return _dire("Main %s : %s" % [cote, essai["refus"]], true)
	var r: String = _magie().equiper(main, id)
	if r != "":
		return _dire("Main %s : %s" % [cote, r], true)
	Sons.jouer(self, ["sword-unsheathe"] if eq.categorie(main).begins_with("arme") else ["cloth1", "cloth2"], -12.0)
	var texte := "%s : main %s." % [eq.fiche(id)["nom"], cote]
	if String(essai["effet"]) != "":
		texte += " " + String(essai["effet"])
	_dire(texte, false)
	_rafraichir()
	return ""

## Range les deux mains actuelles dans le raccourci i (0..9 = touches 1..0).
func memoriser(i: int) -> String:
	var eq := _eq()
	if eq == null:
		return ""
	var g := tenu("gauche")
	var d := tenu("droite")
	var r := eq.assigner_raccourci(i, g, d)
	if r != "":
		return _dire(r, true)
	_dire("Raccourci %d : %s | %s" % [(i + 1) % 10, eq.fiche(g)["nom"], eq.fiche(d)["nom"]], false)
	Sons.jouer(self, ["cloth1", "cloth2"], -12.0)
	_rafraichir()
	return ""

func vider_raccourci(i: int) -> void:
	var eq := _eq()
	if eq == null:
		return
	eq.vider_raccourci(i)
	_dire("Raccourci %d vidé : la touche ne change plus les mains." % ((i + 1) % 10), false)
	_rafraichir()

func _dire(texte: String, refus: bool) -> String:
	message = texte
	_avis.text = texte
	_avis.add_theme_color_override("font_color", ROUGE if refus else MenuStyle.RUNE)
	return texte if refus else ""

# ------------------------------------------------------------------ affichage

## Couleur d'icône : les sorts sans motif propre (enchantements) prennent l'épée teintée de leur école.
func _icone_et_teinte(id: String) -> Array:
	if IconesCombat.connu(id) or id == "vide":
		return [IconesCombat.icone(id), Color.WHITE]
	var eq := _eq()
	var f: Dictionary = eq.fiche(id) if eq != null else {}
	if String(f.get("genre", "")) == "sort":
		return [IconesCombat.icone("epee"), IconesCombat.accent(String(f.get("ecole", ""))).lightened(0.2)]
	if String(f.get("genre", "")).begins_with("arme"):
		return [IconesCombat.icone("epee"), Color.WHITE]
	return [IconesCombat.icone("inconnu"), Color.WHITE]

func _remplir_liste() -> void:
	for c in _liste.get_children():
		c.queue_free()
		_liste.remove_child(c)
	var eq := _eq()
	if eq == null:
		return
	var boutons: Array = []
	if categorie == "divers":
		var inv: Inventaire = joueur.inventaire
		var p := MenuStyle.etiquette("Pièces : %d" % inv.pieces, MenuStyle.OR)
		_liste.add_child(p)
		for id in inv.objets:
			var b := _ligne("sac:" + String(id), "%s  x%d" % [inv.nom(id), inv.objets[id]], null, Color.WHITE)
			boutons.append(b)
		if inv.objets.is_empty():
			_liste.add_child(MenuStyle.etiquette("(sac vide)", MenuStyle.GRIS))
	else:
		for id in eq.objets_possedes(categorie):
			var it := _icone_et_teinte(id)
			boutons.append(_ligne(id, String(eq.fiche(id)["nom"]), it[0], it[1]))
	for b in boutons:
		_liste.add_child(b)
	MenuStyle.chainer(boutons)
	# focus : l'objet déjà choisi s'il est dans la liste, sinon le premier
	var cible: Button = null
	for b: Button in boutons:
		if String(b.get_meta("id")) == choisi:
			cible = b
	if cible == null and not boutons.is_empty():
		cible = boutons[0]
	if cible != null:
		_choisir(String(cible.get_meta("id")))
		cible.grab_focus.call_deferred()
	else:
		_choisir("")

## Ligne de la liste : icône + nom ; marques G (bleu) / D (or) à droite si l'objet est tenu.
func _ligne(id: String, texte: String, icone: Texture2D, teinte: Color) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = icone
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.button_mask = 0   # souris : gui_input (gauche = main droite, droite = main gauche) ; Entrée / A = main droite
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override("icon_max_width", 16)
	for c in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, teinte)
	b.set_meta("id", id)
	var marques := HBoxContainer.new()
	marques.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	marques.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	marques.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marques.add_theme_constant_override("separation", 3)
	var mg := MenuStyle.etiquette("G", BLEU)
	var md := MenuStyle.etiquette("D", MenuStyle.OR)
	marques.add_child(mg)
	marques.add_child(md)
	b.add_child(marques)
	b.set_meta("mg", mg)
	b.set_meta("md", md)
	b.focus_entered.connect(func() -> void: _choisir(id))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void: equiper("droite", id))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				b.grab_focus()
				equiper("droite", id)
				b.accept_event()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				b.grab_focus()
				equiper("gauche", id)
				b.accept_event())
	return b

func _choisir(id: String) -> void:
	choisi = id
	_remplir_fiche()

func _remplir_fiche() -> void:
	for c in _fiche.get_children():
		c.queue_free()
		_fiche.remove_child(c)
	var eq := _eq()
	if eq == null or choisi == "":
		return
	if choisi.begins_with("sac:"):
		var id := choisi.substr(4)
		var inv: Inventaire = joueur.inventaire
		var o: Dictionary = Inventaire.OBJETS.get(id, {})
		_fiche.add_child(MenuStyle.etiquette(inv.nom(id), MenuStyle.OR))
		_fiche.add_child(_texte("Quantité : %d" % int(inv.objets.get(id, 0))))
		_fiche.add_child(_texte("Poids : %s   Valeur : %d" % [str(o.get("poids", 0.0)), int(o.get("valeur", 0))]))
		_fiche.add_child(_texte("Ne se tient pas en main.", MenuStyle.GRIS))
		return
	var f := eq.fiche(choisi)
	_fiche.add_child(MenuStyle.etiquette(String(f["nom"]), MenuStyle.OR if String(f["ecole"]) == "" else IconesCombat.accent(String(f["ecole"])).lightened(0.15)))
	for l in f["lignes"]:
		_fiche.add_child(_texte(String(l)))
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 4)
	_fiche.add_child(esp)
	# pour chaque main : possible (et ses conséquences) ou la raison du refus — avant même d'essayer
	for m in ["droite", "gauche"]:
		var e := eq.essai(m, choisi)
		var touche := "Clic gauche / D" if m == "droite" else "Clic droit / G"
		var en_main := tenu(m) == choisi
		var etat: String
		var couleur: Color
		if en_main:
			etat = "en main"
			couleur = BLEU if m == "gauche" else MenuStyle.OR
		elif String(e["refus"]) != "":
			etat = String(e["refus"])
			couleur = ROUGE
		else:
			etat = "équiper" + ("" if String(e["effet"]) == "" else " (" + String(e["effet"]).trim_suffix(".") + ")")
			couleur = MenuStyle.PARCHEMIN
		_fiche.add_child(_texte("%s, main %s : %s" % [touche, m, etat], couleur))

func _texte(t: String, c := MenuStyle.PARCHEMIN) -> Label:
	var l := MenuStyle.etiquette(t, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	return l

## Met à jour les mains, les marques G/D de la liste, la fiche et les cases des raccourcis.
func _rafraichir() -> void:
	var eq := _eq()
	if eq == null:
		return
	for m in ["gauche", "droite"]:
		var id := tenu(m)
		var it := _icone_et_teinte(id)
		var ui: Dictionary = _main_ui[m]
		(ui["icone"] as TextureRect).texture = it[0]
		(ui["icone"] as TextureRect).modulate = it[1]
		var nom := String(eq.fiche(id)["nom"])
		if m == "gauche" and id == "vide" and eq.categorie("droite") == "arme_deux_mains":
			nom = "(arme à deux mains)"
			(ui["icone"] as TextureRect).texture = _icone_et_teinte(tenu("droite"))[0]
			(ui["icone"] as TextureRect).modulate = Color(1, 1, 1, 0.45)
		(ui["nom"] as Label).text = nom
	for b in _liste.get_children():
		if b is Button and b.has_meta("mg"):
			var id := String(b.get_meta("id"))
			(b.get_meta("mg") as Label).visible = tenu("gauche") == id
			(b.get_meta("md") as Label).visible = tenu("droite") == id
	_remplir_fiche()
	var ig := tenu("gauche")
	var idr := tenu("droite")
	for i in _cases.size():
		var b := _cases[i]
		var r: Dictionary = eq.raccourcis[i] if i < eq.raccourcis.size() else {}
		var vide := not r.has("gauche") and not r.has("droite")
		for k in ["g", "d"]:
			var id := String(r.get("gauche" if k == "g" else "droite", ""))
			var t := b.get_meta(k) as TextureRect
			if id == "" or (id == "vide" and vide):
				t.texture = null
			else:
				var it := _icone_et_teinte(id)
				t.texture = it[0]
				t.modulate = Color(it[1], 0.35 if id == "vide" else 1.0)
		var actif := not vide and String(r.get("gauche", "vide")) == ig and String(r.get("droite", "vide")) == idr
		(b.get_meta("n") as Label).add_theme_color_override("font_color", MenuStyle.OR if actif else (MenuStyle.GRIS if vide else MenuStyle.PARCHEMIN))
		b.tooltip_text = String(r.get("nom", "")) if not vide else "vide"
