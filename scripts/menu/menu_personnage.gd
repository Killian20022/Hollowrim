class_name MenuPersonnage
extends CanvasLayer
## Menu du personnage (lot C, docs/RPG.md §8-9) : un codex de cuir ouvert plein écran, direction A « parchemin et cuir
## enluminé » (maquettes Desktop/Skyrim captures/maquettes_menu/A_parchemin). La COQUILLE dessine le livre, l'en-tête
## (« Voyageur · niveau N », poids du sac), les signets des onglets et le pied de page des touches ; chaque page est un
## OngletMenu (scripts/menu/onglet_*.gd) qui ne contient aucune règle de jeu.
##   Ouverture : Tab (dernier onglet), I = Sac, K = Compétences, J = Quêtes, M = Carte (touches réglables). Jeu en PAUSE, souris visible.
##   Onglets : Tab / Maj+Tab, LB / RB, clic sur un signet. Fermeture : Échap, B (manette), ou la touche de l'onglet affiché.
## Onglets du lot D (Compétences, Quêtes, Personnage) : chargés par leur chemin s'ils existent (fusion = simple branchement),
## sinon une page « à venir ». L'API des actions (équiper une main, boire, lâcher, raccourcis) est dans InventaireMains
## (scripts/inventaire_mains.gd), qui hérite de cette coquille.
## Captures : argument utilisateur --menu=<onglet> (ouvre le menu sur cet onglet dès que le monde est prêt).

signal ouvert_change(ouvert: bool)

## Onglets dans l'ordre des signets. `script` : chemin (les onglets du lot D peuvent manquer : page « à venir »).
const ONGLETS := [
	{"id": "equipement", "titre": "Équipement", "script": "res://scripts/menu/onglet_equipement.gd"},
	{"id": "sac", "titre": "Sac", "script": "res://scripts/menu/onglet_sac.gd"},
	{"id": "magie", "titre": "Magie", "script": "res://scripts/menu/onglet_magie.gd"},
	{"id": "competences", "titre": "Compétences", "script": "res://scripts/menu/onglet_competences.gd"},
	{"id": "quetes", "titre": "Quêtes", "script": "res://scripts/menu/onglet_quetes.gd"},
	{"id": "carte", "titre": "Carte", "script": "res://scripts/menu/onglet_carte.gd"},
	{"id": "personnage", "titre": "Personnage", "script": "res://scripts/menu/onglet_personnage.gd"},
]
## Actions (touches réglables : Touches) qui ouvrent directement un onglet ; Tab rouvre le dernier.
const ACTIONS_ONGLETS := {"inventaire": "sac", "competences": "competences", "quetes": "quetes", "carte": "carte"}
const DUREE_MESSAGE := 3.5
const ROUGE_CUIR := Color("#f0806a")

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
## Onglet affiché (ou à rouvrir avec Tab).
var onglet_actif := "equipement"
## Dernier message du bandeau (refus, confirmation ; tests).
var message := ""
var _refus := false
var _message_t := 0.0

var _vue: Control
var _onglets := {}           # id -> OngletMenu
var _livre: ImageTexture
var _taille_livre := Vector2.ZERO
var _police: FontFile
var _gothique: FontFile
var _signets: Array = []     # [Rect2, id]
var _survol_signet := ""
var _souris := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	layer = 45   # sous le menu pause (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Touches.installer()   # actions menu / inventaire / competences / quetes / carte
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_vue = Control.new()
	_vue.name = "Livre"
	_vue.theme = MenuStyle.theme()
	_vue.visible = false
	_vue.mouse_filter = Control.MOUSE_FILTER_STOP
	_vue.draw.connect(_dessiner)
	_vue.gui_input.connect(_entree_vue)
	add_child(_vue)
	for o: Dictionary in ONGLETS:
		_onglets[o["id"]] = _creer_onglet(o)
	if hud != null and "menu" in hud:
		hud.menu = self
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu="):
			(func() -> void:
				await get_tree().create_timer(0.5, true).timeout
				ouvrir(a.substr(7))).call_deferred()

func _exit_tree() -> void:
	MenuStyle.vider_menu()

func _creer_onglet(o: Dictionary) -> OngletMenu:
	var ong: OngletMenu = null
	var chemin := String(o["script"])
	if ResourceLoader.exists(chemin):
		var s := load(chemin) as Script
		if s != null and s.can_instantiate():
			var inst: Variant = s.new()
			if inst is OngletMenu:
				ong = inst
	if ong == null:
		ong = OngletAVenir.new()
		(ong as OngletAVenir).id = String(o["id"])
		(ong as OngletAVenir).nom = String(o["titre"])
	ong.name = "Onglet_" + String(o["id"])
	ong.visible = false
	ong.mouse_filter = Control.MOUSE_FILTER_PASS
	ong.set_anchors_preset(Control.PRESET_FULL_RECT)
	if "coquille" in ong:
		ong.set("coquille", self)
	ong.message.connect(func(t: String) -> void: dire(t, t.begins_with("!")))
	ong.contenu_change.connect(func() -> void: _vue.queue_redraw())
	_vue.add_child(ong)
	return ong

## Onglet par son identifiant (null si inconnu).
func onglet(id: String) -> OngletMenu:
	return _onglets.get(id)

func onglet_courant() -> OngletMenu:
	return _onglets.get(onglet_actif)

# ------------------------------------------------------------------ ouverture / fermeture

func peut_ouvrir() -> bool:
	if joueur == null or joueur.get("mort") or joueur.get("en_dialogue"):
		return false
	return not get_tree().paused or ouvert

## Ouvre le menu (jeu en pause) sur l'onglet `id` ("" = le dernier affiché).
func ouvrir(id := "") -> void:
	if id != "" and _onglets.has(id):
		if ouvert:
			changer_onglet(id)
			return
		onglet_actif = id
	if ouvert or joueur == null:
		return
	ouvert = true
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	message = ""
	_message_t = 0.0
	_vue.visible = true
	EchelleUi.appliquer(_vue)
	_preparer_livre()
	_montrer(onglet_actif)
	Sons.interface(self, ["ui_menu_ouvre"], -12.0)
	ouvert_change.emit(true)

func fermer() -> void:
	if not ouvert:
		return
	var o := onglet_courant()
	if o != null:
		o.fermer()
		o.visible = false
	ouvert = false
	_vue.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	Sons.interface(self, ["ui_menu_ferme"], -13.0)
	ouvert_change.emit(false)

func basculer(id := "") -> void:
	if ouvert and (id == "" or id == onglet_actif):
		fermer()
	else:
		ouvrir(id)

func changer_onglet(id: String) -> void:
	if not _onglets.has(id) or id == onglet_actif and onglet_courant().visible:
		return
	var o := onglet_courant()
	if o != null and o.visible:
		o.fermer()
		o.visible = false
	onglet_actif = id
	if ouvert:
		_montrer(id)
		Sons.jouer(self, ["cloth1", "cloth2"], -16.0)

func onglet_voisin(sens: int) -> void:
	var i := 0
	for k in ONGLETS.size():
		if ONGLETS[k]["id"] == onglet_actif:
			i = k
	changer_onglet(String(ONGLETS[(i + sens + ONGLETS.size()) % ONGLETS.size()]["id"]))

func _montrer(id: String) -> void:
	var o: OngletMenu = _onglets[id]
	o.joueur = joueur
	if "quetes" in o and o.get("quetes") == null and hud != null and hud.get("quetes") != null:
		o.set("quetes", hud.quetes)   # onglet Quêtes (lot D) : oq.quetes = monde.quetes
	o.visible = true
	o.size = _vue.size
	o.ouvrir()
	_vue.queue_redraw()

## Message du bandeau (pied de page) pendant DUREE_MESSAGE s ; `refus` : en rouge. Renvoie le texte si refus, sinon "".
func dire(texte: String, refus := false) -> String:
	message = texte.trim_prefix("!")
	_refus = refus
	_message_t = DUREE_MESSAGE if message != "" else 0.0
	if _vue != null:
		_vue.queue_redraw()
	return message if refus else ""

func _preparer_livre() -> void:
	if _livre != null and _taille_livre == _vue.size:
		return
	_taille_livre = _vue.size
	_livre = Parchemin.texture_livre(self, Vector2i(_taille_livre))

func _process(dt: float) -> void:
	if not ouvert:
		return
	if EchelleUi.appliquer(_vue):
		_preparer_livre()
		var o := onglet_courant()
		if o != null:
			o.size = _vue.size
	if _message_t > 0.0:
		_message_t -= dt
		if _message_t <= 0.0:
			_vue.queue_redraw()

# ------------------------------------------------------------------ entrées

func _unhandled_input(e: InputEvent) -> void:
	if ouvert:
		return
	var id := "-"
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("menu", false):
			id = ""
		else:
			for action: String in ACTIONS_ONGLETS:
				if e.is_action_pressed(action, false):
					id = ACTIONS_ONGLETS[action]
					break
	elif e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
		id = ""
	if id == "-" or not peut_ouvrir():
		return
	get_viewport().set_input_as_handled()
	ouvrir(id)

## Menu ouvert : l'onglet reçoit l'événement d'abord ; sinon Tab / LB / RB (onglets), Échap / B (fermer), I / K / J ;
## toutes les autres touches du jeu sont avalées (pas de torche, de vue, de sauvegarde rapide sous le menu).
func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	if e is InputEventMouse:
		return   # la souris passe par l'interface (onglets, puis _entree_vue pour les signets)
	var vp := get_viewport()
	var o := onglet_courant()
	if e is InputEventKey and not (e as InputEventKey).pressed:
		vp.set_input_as_handled()
		return
	if o != null and o.entree(e):
		vp.set_input_as_handled()
		_vue.queue_redraw()
		o.queue_redraw()
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		vp.set_input_as_handled()
		if k.echo:
			return
		if k.physical_keycode == KEY_ESCAPE:
			fermer()
		elif e.is_action_pressed("menu", false):
			onglet_voisin(-1 if k.shift_pressed else 1)
		else:
			for action: String in ACTIONS_ONGLETS:
				if e.is_action_pressed(action, false):
					basculer(ACTIONS_ONGLETS[action])
					break
	elif e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed:
		vp.set_input_as_handled()
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER:
				onglet_voisin(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				onglet_voisin(1)

## Souris sur le livre (hors des zones prises par l'onglet) : signets.
func _entree_vue(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var s := _signet_sous(e.position)
		if s != _survol_signet:
			_survol_signet = s
			_vue.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var s := _signet_sous(e.position)
		if s != "":
			changer_onglet(s)
			_vue.accept_event()

func _signet_sous(p: Vector2) -> String:
	for s: Array in _signets:
		if (s[0] as Rect2).has_point(p):
			return String(s[1])
	return ""

# ------------------------------------------------------------------ dessin de la coquille

func _dessiner() -> void:
	var t := _vue.size
	if _livre != null:
		_vue.draw_texture(_livre, Vector2.ZERO)
	# en-tête sur le cuir : « Voyageur · niveau N » à gauche, poids du sac à droite (comme la coquille d'essai du lot D)
	var niv := 1
	if joueur != null and joueur.get("progression") != null:
		niv = int(joueur.progression.niveau)
	var en_tete := "Voyageur · niveau %d" % niv
	Parchemin.texte(_vue, _police, Vector2(20, 8), en_tete, Parchemin.TEXTE_CUIR)
	var x_droite := t.x - 20.0
	if joueur != null:
		var inv: Inventaire = joueur.inventaire
		var poids := "Poids %s / %d" % [poids_texte(inv.poids()), roundi(inv.capacite())]
		Parchemin.texte_droite(_vue, _police, t.x - 20.0, 8, poids, ROUGE_CUIR if inv.surcharge() else Parchemin.TEXTE_CUIR)
		x_droite -= ceilf(Parchemin.largeur(_police, poids))
	# signets entre l'en-tête et le poids (7 signets : ils ne mordent plus sur « Voyageur · niveau N ») ; marge intérieure
	# resserrée (18 → 12 → 8 px) seulement si la rangée ne tient pas. L'actif est dessiné en dernier (il mord sur la page).
	var x_gauche := 20.0 + ceilf(Parchemin.largeur(_police, en_tete)) + 8.0
	x_droite -= 8.0
	var lt := 0.0
	for o: Dictionary in ONGLETS:
		lt += ceilf(Parchemin.largeur(_police, String(o["titre"])))
	var marge := 18.0
	var ecart := 3.0
	for essai: Array in [[18.0, 3.0], [14.0, 2.0], [12.0, 2.0], [10.0, 1.0], [8.0, 1.0]]:
		marge = essai[0]
		ecart = essai[1]
		if lt + ONGLETS.size() * (marge + ecart) - ecart <= x_droite - x_gauche:
			break
	var tot := lt + ONGLETS.size() * (marge + ecart) - ecart
	# centré sur la page si possible, sinon glissé dans l'espace libre entre l'en-tête et le poids
	var x := clampf(roundf((t.x - tot) * 0.5), x_gauche, maxf(x_gauche, x_droite - tot))
	_signets.clear()
	var x_actif := -1.0
	for o: Dictionary in ONGLETS:
		var id := String(o["id"])
		var l := ceilf(Parchemin.largeur(_police, String(o["titre"]))) + marge
		if id == onglet_actif:
			x_actif = x
		else:
			Parchemin.signet(_vue, _police, x, String(o["titre"]), false, marge)
			if id == _survol_signet:
				_vue.draw_rect(Rect2(x + 2, 21, l - 4, 1), Parchemin.TEXTE_CUIR)
		_signets.append([Rect2(x, 2, l, 24), id])
		x += l + ecart
	if x_actif >= 0.0:
		Parchemin.signet(_vue, _police, x_actif, _titre_de(onglet_actif), true, marge)
	# pied de page : message (quelques secondes) ou touches de l'onglet + celles de la coquille
	if _message_t > 0.0 and message != "":
		var txt := MenuStyle.raccourcir(_police, message, t.x - 40.0)
		var lm := Parchemin.largeur(_police, txt)
		_vue.draw_rect(Rect2(roundf((t.x - lm) * 0.5) - 6, t.y - 23, lm + 12, 17), Parchemin.CUIR[0])
		Parchemin.texte(_vue, _police, Vector2(roundf((t.x - lm) * 0.5), t.y - 21), txt, ROUGE_CUIR if _refus else Parchemin.OR_VIF)
		return
	var touches: Array = []
	var o := onglet_courant()
	if o != null:
		touches.append_array(o.aide())
	for defaut: Array in [[Touches.libelle("menu"), "Onglet"], ["Échap", "Fermer"]]:
		var cle := String(defaut[0]).get_slice(" ", 0)
		if not touches.any(func(k: Array) -> bool: return String(k[0]).get_slice(" ", 0) == cle):
			touches.append(defaut)
	Parchemin.bandeau_touches(_vue, _police, t, touches)

func _titre_de(id: String) -> String:
	for o: Dictionary in ONGLETS:
		if o["id"] == id:
			return String(o["titre"])
	return id

## Poids écrit à la française (64,3 ; 10 ; 0).
static func poids_texte(p: float) -> String:
	if absf(p - roundf(p)) < 0.05:
		return str(roundi(p))
	return ("%.1f" % p).replace(".", ",")

# ------------------------------------------------------------------ page « à venir » (onglets du lot D tant qu'ils manquent)

class OngletAVenir extends OngletMenu:
	var id := ""
	var nom := ""
	var _police: FontFile
	var _gothique: FontFile

	func _ready() -> void:
		_police = Palette.police()
		_gothique = MenuStyle.police_gothique(true)

	func id_onglet() -> String:
		return id

	func titre() -> String:
		return nom

	func ouvrir() -> void:
		queue_redraw()

	func _draw() -> void:
		var r := OngletLivre.zones_livre(size)
		var g: Rect2 = r["gauche"]
		var d: Rect2 = r["droite"]
		Parchemin.titre(self, _gothique, _police, Vector2(g.position.x, g.position.y), nom)
		var y := g.position.y + 40.0
		for l in Parchemin.couper(_police, "Cette page du codex n'est pas encore écrite. Elle le sera bientôt.", g.size.x - 8.0):
			Parchemin.texte(self, _police, Vector2(g.position.x, y), l, Parchemin.PALE)
			y += 11.0
		Parchemin.filet(self, d.position.x + 8.0, d.position.y + d.size.y * 0.5, d.size.x - 16.0)
