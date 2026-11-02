extends Control
## COQUILLE D'ESSAI du lot D (en attendant MenuPersonnage du lot C) : affiche les onglets Compétences / Quêtes / Personnage
## seuls, dans le codex de la direction A (Parchemin.livre), avec les signets de cuir, l'en-tête et le bandeau des touches.
## Reproduit le contrat de docs/RPG.md §8 tel que la coquille du lot C l'appliquera :
##   - chaque onglet est un enfant plein écran (640x360 logique), `joueur` posé AVANT ouvrir() ;
##   - chaque événement est d'abord proposé à onglet.entree(e) ; s'il n'est pas consommé : Tab / E (physique) / RB = onglet
##     suivant, Q (physique, A en AZERTY) / LB = précédent, Échap / B = fermer ; clic sur un signet = cet onglet ;
##   - fermer() sur l'onglet quitté, ouvrir() sur le nouveau ; jeu en pause pendant le menu ;
##   - signal message(texte) des onglets → bandeau (ici : ligne sous les pages) ; aide() → bandeau des touches.
## Utilisé par outils/lanceur_onglets_rpg.gd (captures, essai à la main) et outils/test_onglets_rpg.gd.

signal ferme

const SIGNETS_C := ["Équipement", "Sac", "Magie"]   ## onglets du lot C, dessinés éteints (non cliquables) pour la mise en page

var joueur: Node = null
var onglets: Array = []        ## OngletMenu (ordre des signets après ceux du lot C)
var actif := 0
var ouvert := false
var _livre: ImageTexture
var _police: FontFile
var _message := ""
var _message_t := 0.0
var _signets: Array = []       ## [Rect2, index d'onglet ou -1]

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_police = Palette.police()
	visible = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func ajouter(o: OngletMenu) -> void:
	o.joueur = joueur
	o.visible = false
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(o)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.message.connect(func(t: String) -> void:
		_message = t
		_message_t = 3.0
		queue_redraw())
	o.contenu_change.connect(queue_redraw)
	onglets.append(o)

func ouvrir(id := "") -> void:
	if _livre == null:
		_livre = ImageTexture.create_from_image(Parchemin.livre(Vector2i(640, 360)))
	for i in onglets.size():
		if onglets[i].id_onglet() == id:
			actif = i
	ouvert = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_montrer(actif)

func fermer() -> void:
	if not ouvert:
		return
	onglets[actif].fermer()
	onglets[actif].visible = false
	ouvert = false
	visible = false
	get_tree().paused = false
	ferme.emit()

func aller(i: int) -> void:
	if i == actif or onglets.is_empty():
		return
	onglets[actif].fermer()
	onglets[actif].visible = false
	actif = posmod(i, onglets.size())
	_montrer(actif)

func _montrer(i: int) -> void:
	onglets[i].visible = true
	onglets[i].ouvrir()
	queue_redraw()

func _process(dt: float) -> void:
	if _message_t > 0.0:
		_message_t -= dt
		if _message_t <= 0.0:
			_message = ""
			queue_redraw()

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	if traiter(e):
		get_viewport().set_input_as_handled()

## Un événement : d'abord l'onglet, puis la coquille. Renvoie true s'il est consommé (tests : appelé directement).
func traiter(e: InputEvent) -> bool:
	if onglets[actif].entree(e):
		queue_redraw()
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_TAB or k.physical_keycode == KEY_E:
			aller(actif + (-1 if k.shift_pressed else 1))
			return true
		if k.physical_keycode == KEY_Q:
			aller(actif - 1)
			return true
		if k.keycode == KEY_ESCAPE:
			fermer()
			return true
	if e is InputEventJoypadButton and e.pressed:
		var b := (e as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_RIGHT_SHOULDER:
			aller(actif + 1)
			return true
		if b == JOY_BUTTON_LEFT_SHOULDER:
			aller(actif - 1)
			return true
		if b == JOY_BUTTON_B or b == JOY_BUTTON_BACK:
			fermer()
			return true
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = make_input_local(e).position
		for s: Array in _signets:
			if (s[0] as Rect2).has_point(p) and int(s[1]) >= 0:
				aller(int(s[1]))
				return true
	return false

func _draw() -> void:
	if _livre != null:
		draw_texture(_livre, Vector2.ZERO)
	# en-tête sur le cuir
	var pr = joueur.get("progression") if joueur != null else null
	var niv := (pr as Progression).niveau if pr is Progression else 1
	Parchemin.texte(self, _police, Vector2(20, 8), "Voyageur · niveau %d" % niv, Parchemin.TEXTE_CUIR)
	if joueur != null and joueur.get("inventaire") is Inventaire:
		var inv: Inventaire = joueur.inventaire
		Parchemin.texte_droite(self, _police, 620, 8, "Poids %s / %s" % [OngletPersonnage.nombre(inv.poids(), 1), OngletPersonnage.nombre(inv.capacite())], Parchemin.TEXTE_CUIR)
	# signets : ceux du lot C (éteints) puis les nôtres
	var titres: Array = []
	for t: String in SIGNETS_C:
		titres.append([t, -1])
	for i in onglets.size():
		titres.append([onglets[i].titre(), i])
	var tot := 0.0
	for t: Array in titres:
		tot += ceilf(Parchemin.largeur(_police, t[0])) + 18.0 + 3.0
	var x := roundf((size.x - tot + 3.0) * 0.5)
	_signets = []
	for t: Array in titres:
		var l := Parchemin.signet(self, _police, x, t[0], int(t[1]) == actif)
		_signets.append([Rect2(x, 2, l, 24), t[1]])
		x += l + 3.0
	# bandeau des touches : aide de l'onglet + celles de la coquille
	var lignes: Array = []
	if not onglets.is_empty():
		lignes = onglets[actif].aide().duplicate()
	lignes.append_array([["Tab / RB", "Onglet"], ["Échap / B", "Fermer"]])
	if _message != "":
		var lm := Parchemin.largeur(_police, _message)
		draw_rect(Rect2(roundf((size.x - lm) * 0.5) - 6, size.y - 23, lm + 12, 17), Parchemin.CUIR[0])
		Parchemin.texte(self, _police, Vector2(roundf((size.x - lm) * 0.5), size.y - 21), _message, Parchemin.OR_VIF)
	else:
		Parchemin.bandeau_touches(self, _police, size, lignes)
