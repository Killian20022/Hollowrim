class_name Manette
extends Node
## Manette (Xbox / SDL standard) : boutons des commandes, remappage, lecture des sticks et « dernière entrée ».
## docs/OPTIONS_SAUVEGARDES.md « Manette ». Le clavier et la souris ne changent pas : ce fichier AJOUTE des événements de manette
## aux mêmes actions de l'InputMap (Touches.appliquer appelle Manette.appliquer), le code du jeu continue de tester l'action.
##
## Schéma par défaut :
##   stick gauche = se déplacer (fixe)      stick droit = regarder (fixe ; sensibilité, zone morte, courbe, inversion Y réglables)
##   RT = main droite (frapper ; maintenir = coup puissant ; sort de droite)      LT = main gauche (garde / sort de gauche)
##   A = parler, ouvrir, ramasser   B = esquiver   X = torche   Y = sauter   LB = courir (maintenu)   RB = carte
##   L3 = s'accroupir (action « accroupi », furtivité)   R3 = vue 1re / 3e personne
##   croix haut / droite / bas / gauche = raccourcis 1 / 2 / 3 / 4     Vue (Back) = menu du personnage     Start = pause (fixe)
## Dans les menus, les touches internes restent celles déjà posées par chaque écran : A valider, B retour, X / Y actions,
## LB / RB onglets, croix et stick gauche pour choisir (le stick n'envoie qu'un pas par poussée : voir changement()).
##
## Le nœud lui-même (posé sous la racine par installer()) suit la DERNIÈRE ENTRÉE : clavier / souris ou manette (actif(),
## generation) ; les textes d'aide (Aides, HUD, bandeaux des menus, invite) passent alors en noms de boutons. Il filtre aussi les
## mouvements d'axe : seuls les franchissements de seuil passent aux scripts (une gâchette tenue n'envoie pas cent « appuis »),
## l'état continu des axes reste lisible par Input (déplacement, caméra).
##
## Codes : bouton b = b (JOY_BUTTON_*) ; axe a sens + = 100 + 2a, sens - = 101 + 2a (LT = 108, RT = 110) ; AUCUN = -1.
## Réglages : user://options.cfg, section « manette » (« <action> », « sensibilite », « inverser_y », « zone_morte », « courbe »).
## Mode outil (tests, captures) : boutons par défaut, rien n'est écrit (comme Touches).

const AUCUN := -1
const AXE := 100
const LT := AXE + 2 * JOY_AXIS_TRIGGER_LEFT
const RT := AXE + 2 * JOY_AXIS_TRIGGER_RIGHT
## Seuils d'un axe vu comme un bouton (hystérésis : pas de rebond autour du seuil).
const SEUIL := 0.5
const SEUIL_RELACHE := 0.35
## Vitesse de rotation de la caméra au stick à fond, sensibilité 100 % (radians / s).
const VITESSE_LACET := 3.2
const VITESSE_TANGAGE := 2.2
## Courbes de réponse du stick droit (exposant appliqué après la zone morte) : Linéaire, Douce, Forte.
const COURBES := [1.0, 1.8, 2.6]
const NOMS_COURBES := ["Linéaire", "Douce", "Forte"]

## Boutons par défaut des commandes de Touches.ACTIONS (déplacement exclu : stick gauche fixe) et des commandes propres à la
## manette (EXTRAS). Une commande absente = sans bouton par défaut (réglable dans Options > Touches).
const DEFAUT := {
	"course": JOY_BUTTON_LEFT_SHOULDER, "saut": JOY_BUTTON_Y, "esquive": JOY_BUTTON_B, "interagir": JOY_BUTTON_A,
	"torche": JOY_BUTTON_X, "vue": JOY_BUTTON_RIGHT_STICK, "menu": JOY_BUTTON_BACK, "carte": JOY_BUTTON_RIGHT_SHOULDER,
	"main_droite": RT, "main_gauche": LT, "accroupi": JOY_BUTTON_LEFT_STICK,
	"raccourci_1": JOY_BUTTON_DPAD_UP, "raccourci_2": JOY_BUTTON_DPAD_RIGHT, "raccourci_3": JOY_BUTTON_DPAD_DOWN,
	"raccourci_4": JOY_BUTTON_DPAD_LEFT,
}
## Commandes hors de Touches.ACTIONS : leur entrée clavier / souris FIXE (créée ici si l'action n'existe pas encore : main_sort.gd
## ne la recrée pas). « accroupi » : la touche clavier vient de Touches.ACTIONS quand la furtivité l'y ajoute (gameplay/furtivite).
const EXTRAS := [
	{"id": "main_droite", "nom": "Main droite (frapper, sort)", "souris": MOUSE_BUTTON_LEFT},
	{"id": "main_gauche", "nom": "Main gauche (garde, sort)", "souris": MOUSE_BUTTON_RIGHT},
	{"id": "raccourci_1", "nom": "Raccourci 1", "touche": KEY_1},
	{"id": "raccourci_2", "nom": "Raccourci 2", "touche": KEY_2},
	{"id": "raccourci_3", "nom": "Raccourci 3", "touche": KEY_3},
	{"id": "raccourci_4", "nom": "Raccourci 4", "touche": KEY_4},
	{"id": "accroupi", "nom": "S'accroupir"},
]
## Stick gauche : déplacement (axes fixes, zone morte réglable). Stick droit : regard (lu par regard()).
const STICK_GAUCHE := {"avant": [JOY_AXIS_LEFT_Y, -1.0], "arriere": [JOY_AXIS_LEFT_Y, 1.0], "gauche": [JOY_AXIS_LEFT_X, -1.0], "droite": [JOY_AXIS_LEFT_X, 1.0]}
const STICK_DROIT := {"regard_haut": [JOY_AXIS_RIGHT_Y, -1.0], "regard_bas": [JOY_AXIS_RIGHT_Y, 1.0], "regard_gauche": [JOY_AXIS_RIGHT_X, -1.0], "regard_droite": [JOY_AXIS_RIGHT_X, 1.0]}
const UI_STICK := {"ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0], "ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0]}
## Boutons qu'on ne peut pas attribuer : Start (pause), Guide.
const RESERVES := [JOY_BUTTON_START, JOY_BUTTON_GUIDE]
const REGLAGES_DEFAUT := {"sensibilite": 1.0, "inverser_y": false, "zone_morte": 0.2, "courbe": 1}

## id -> code (bouton ou axe) : l'état courant, appliqué à l'InputMap par appliquer().
static var liaisons := {}
## Dernière entrée : vrai = manette. `generation` change à chaque bascule (les textes d'aide se reconstruisent).
static var _active := false
static var generation := 0
static var _axes := {}            # "<appareil>:<axe>" -> -1 / 0 / 1 (axe vu comme bouton)
static var _evt_id := 0           # dernier événement d'axe évalué par changement() (mémoire : un même événement, une même réponse)
static var _evt_change := false

# ------------------------------------------------------------------ installation

## Pose le nœud de suivi sous la racine (une fois). Appelé par l'autoload Lancement et par le joueur (tests --script).
static func installer(arbre: SceneTree) -> void:
	if arbre == null or arbre.root.has_node("Manette"):
		return
	var n := Manette.new()
	n.name = "Manette"
	arbre.root.add_child.call_deferred(n)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Touches.installer()

## Reste le DERNIER enfant de la racine : son _input passe avant celui des scènes (les mouvements d'axe sans franchissement de seuil
## sont avalés avant d'atteindre les menus et le jeu).
func _process(_dt: float) -> void:
	var r := get_parent()
	if r != null and get_index() != r.get_child_count() - 1:
		r.move_child(self, -1)

func _input(e: InputEvent) -> void:
	var g := generation
	noter(e)
	if g != generation:
		_redessiner(get_tree().root)   # bandeaux et aides dessinés : réécrits avec les noms de l'autre appareil
	if e is InputEventJoypadMotion and not changement(e):
		get_viewport().set_input_as_handled()

static func _redessiner(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control:
		(n as Control).queue_redraw()
	for c in n.get_children():
		if c is CanvasItem or c is CanvasLayer or c is Window or c.get_child_count() > 0 and not (c is Node3D):
			_redessiner(c)

## Note l'appareil de la dernière entrée (appelé par _input ; direct dans les tests).
static func noter(e: InputEvent) -> void:
	var manette := _active
	if e is InputEventJoypadButton and e.pressed:
		manette = true
	elif e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) >= SEUIL:
		manette = true
	elif (e is InputEventKey or e is InputEventMouseButton) and e.is_pressed():
		manette = false
	elif e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() > 4.0:
		manette = false
	if manette != _active:
		_active = manette
		generation += 1

## Vrai si la dernière entrée vient de la manette.
static func actif() -> bool:
	return _active

static func forcer(manette: bool) -> void:
	if manette != _active:
		_active = manette
		generation += 1

## Texte selon l'appareil courant.
static func ou(clavier: String, manette: String) -> String:
	return manette if _active else clavier

static func est_manette(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion

## Un événement d'axe fait-il franchir un seuil (appui / relâchement) ? Même réponse pour un même événement, quel que soit le
## nombre de scripts qui le demandent. Un événement qui n'est pas un axe : toujours vrai.
static func changement(e: InputEvent) -> bool:
	if not (e is InputEventJoypadMotion):
		return true
	if e.get_instance_id() == _evt_id:
		return _evt_change
	var m := e as InputEventJoypadMotion
	var cle := "%d:%d" % [m.device, m.axis]
	var avant: int = _axes.get(cle, 0)
	var v := m.axis_value
	var etat := avant
	if v >= SEUIL:
		etat = 1
	elif v <= -SEUIL:
		etat = -1
	elif absf(v) < SEUIL_RELACHE:
		etat = 0
	_axes[cle] = etat
	_evt_id = e.get_instance_id()
	_evt_change = etat != avant
	return _evt_change

## Bouton pressé de l'événement ; une poussée du stick gauche compte comme la croix (un pas par poussée) ; -1 sinon.
static func bouton_ou_croix(e: InputEvent) -> int:
	if e is InputEventJoypadButton:
		return (e as InputEventJoypadButton).button_index if e.pressed else -1
	if e is InputEventJoypadMotion and changement(e):
		var m := e as InputEventJoypadMotion
		if absf(m.axis_value) < SEUIL:
			return -1
		if m.axis == JOY_AXIS_LEFT_Y:
			return JOY_BUTTON_DPAD_UP if m.axis_value < 0.0 else JOY_BUTTON_DPAD_DOWN
		if m.axis == JOY_AXIS_LEFT_X:
			return JOY_BUTTON_DPAD_LEFT if m.axis_value < 0.0 else JOY_BUTTON_DPAD_RIGHT
	return -1

## Sens de l'axe (−1, 0, 1) après le dernier événement vu par changement().
static func etat_axe(device: int, axe: int) -> int:
	return int(_axes.get("%d:%d" % [device, axe], 0))

# ------------------------------------------------------------------ liaisons

static func _defauts() -> Dictionary:
	var d := {}
	for id: String in ids():
		d[id] = int(DEFAUT.get(id, AUCUN))
	return d

## Toutes les commandes réglables à la manette : celles de Touches.ACTIONS (sauf le déplacement, au stick) puis EXTRAS.
static func ids() -> Array:
	var l: Array = []
	for a: Dictionary in Touches.ACTIONS:
		if not STICK_GAUCHE.has(a["id"]):
			l.append(String(a["id"]))
	for x: Dictionary in EXTRAS:
		if not l.has(x["id"]):
			l.append(String(x["id"]))
	return l

static func nom_action(id: String) -> String:
	for a: Dictionary in Touches.ACTIONS:
		if a["id"] == id:
			return String(a["nom"])
	for x: Dictionary in EXTRAS:
		if x["id"] == id:
			return String(x["nom"])
	return id

## Section « manette » des options par défaut (Jeu.OPTIONS_DEFAUT).
static func options_defaut() -> Dictionary:
	var d := REGLAGES_DEFAUT.duplicate()
	for id: String in ids():
		d[id] = int(DEFAUT.get(id, AUCUN))
	return d

## Relit les boutons du joueur (défauts en mode outil). N'applique pas : Touches.charger() applique tout ensuite.
static func charger_liaisons() -> void:
	liaisons = _defauts()
	if Jeu.mode_outil():
		return
	for id: String in liaisons:
		liaisons[id] = int(Jeu.option("manette", id))

static func code_de(id: String) -> int:
	if liaisons.is_empty():
		charger_liaisons()
	return int(liaisons.get(id, AUCUN))

## Ajoute les événements de manette à l'InputMap (appelé par Touches.appliquer, après les touches) : retire d'abord ceux qui y
## étaient (appel répétable), crée les actions propres à la manette avec leur entrée clavier / souris fixe.
static func appliquer() -> void:
	if liaisons.is_empty():
		charger_liaisons()
	var zm := zone_morte()
	for id: String in STICK_GAUCHE:
		_preparer(id, zm)
		var e := InputEventJoypadMotion.new()
		e.axis = STICK_GAUCHE[id][0]
		e.axis_value = STICK_GAUCHE[id][1]
		InputMap.action_add_event(id, e)
	for id: String in STICK_DROIT:
		_preparer(id, 0.05)
		var e := InputEventJoypadMotion.new()
		e.axis = STICK_DROIT[id][0]
		e.axis_value = STICK_DROIT[id][1]
		InputMap.action_add_event(id, e)
	# navigation des interfaces (boutons, listes) : le stick gauche s'ajoute à la croix (un pas par poussée : changement())
	for ui: String in UI_STICK:
		if InputMap.has_action(ui) and not _a_axe(ui, int(UI_STICK[ui][0]), float(UI_STICK[ui][1])):
			var e := InputEventJoypadMotion.new()
			e.axis = UI_STICK[ui][0]
			e.axis_value = UI_STICK[ui][1]
			InputMap.action_add_event(ui, e)
	for x: Dictionary in EXTRAS:
		var id: String = x["id"]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		if x.has("souris") and not _a_souris(id, int(x["souris"])):
			var m := InputEventMouseButton.new()
			m.button_index = int(x["souris"]) as MouseButton
			InputMap.action_add_event(id, m)
		if x.has("touche") and not _a_touche(id, int(x["touche"])):
			var k := InputEventKey.new()
			k.physical_keycode = int(x["touche"]) as Key
			InputMap.action_add_event(id, k)
	for id: String in liaisons:
		if not InputMap.has_action(id):
			continue
		_preparer(id, SEUIL)
		var ev := evenement(int(liaisons[id]))
		if ev != null:
			InputMap.action_add_event(id, ev)

## Action existante (créée sinon), sans ses événements de manette, avec la zone morte donnée.
static func _preparer(id: String, zone: float) -> void:
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	InputMap.action_set_deadzone(id, zone)
	for ev in InputMap.action_get_events(id):
		if est_manette(ev):
			InputMap.action_erase_event(id, ev)

static func _a_axe(id: String, axe: int, sens: float) -> bool:
	for ev in InputMap.action_get_events(id):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == axe and signf((ev as InputEventJoypadMotion).axis_value) == signf(sens):
			return true
	return false

static func _a_souris(id: String, b: int) -> bool:
	for ev in InputMap.action_get_events(id):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == b:
			return true
	return false

static func _a_touche(id: String, k: int) -> bool:
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == k:
			return true
	return false

## Événement d'InputMap d'un code (null pour AUCUN). device -1 : toutes les manettes.
static func evenement(code: int) -> InputEvent:
	if code == AUCUN:
		return null
	if code >= AXE:
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = ((code - AXE) / 2) as JoyAxis
		m.axis_value = -1.0 if (code - AXE) % 2 == 1 else 1.0
		return m
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = code as JoyButton
	return b

## Code d'un événement de manette (bouton pressé, axe au-delà du seuil), AUCUN sinon.
static func code_evenement(e: InputEvent) -> int:
	if e is InputEventJoypadButton and e.pressed:
		return (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) >= SEUIL:
		var m := e as InputEventJoypadMotion
		return AXE + 2 * int(m.axis) + (1 if m.axis_value < 0.0 else 0)
	return AUCUN

## Attribuable : bouton non réservé, ou gâchette (les sticks restent au déplacement et au regard).
static func attribuable(code: int) -> bool:
	if code == AUCUN or code in RESERVES:
		return false
	return code < AXE or code == LT or code == RT

## Comme Touches.lier : la commande `id` reçoit `code` ; une autre commande qui l'avait reçoit l'ancien bouton de celle-ci (échange).
## code = AUCUN efface. Renvoie l'action échangée ("" si aucune).
static func lier(id: String, code: int) -> String:
	if liaisons.is_empty():
		charger_liaisons()
	if code != AUCUN and not attribuable(code):
		return ""
	var ancien := int(liaisons.get(id, AUCUN))
	var autre := ""
	if code != AUCUN:
		for oid: String in liaisons:
			if oid != id and int(liaisons[oid]) == code:
				autre = oid
				liaisons[oid] = ancien
	liaisons[id] = code
	_enregistrer()
	return autre

static func retablir() -> void:
	liaisons = _defauts()
	_enregistrer()

static func _enregistrer() -> void:
	appliquer()
	if Jeu.mode_outil():
		return
	for id: String in liaisons:
		Jeu.regler("manette", id, int(liaisons[id]), false)
	Jeu.ecrire_options()

# ------------------------------------------------------------------ noms

## Nom d'un bouton tel qu'imprimé sur une manette Xbox (« A », « LB », « Croix haut »…).
static func nom_code(code: int) -> String:
	match code:
		AUCUN: return "—"
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_BACK: return "Vue"
		JOY_BUTTON_GUIDE: return "Guide"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_DPAD_UP: return "Croix haut"
		JOY_BUTTON_DPAD_DOWN: return "Croix bas"
		JOY_BUTTON_DPAD_LEFT: return "Croix gauche"
		JOY_BUTTON_DPAD_RIGHT: return "Croix droite"
		LT: return "LT"
		RT: return "RT"
	if code >= AXE:
		return "Axe %d%s" % [(code - AXE) / 2, "-" if (code - AXE) % 2 == 1 else "+"]
	return "Bouton %d" % code

## Bouton d'une commande, écrit pour le joueur (« A », « RT »…).
static func libelle(id: String) -> String:
	return nom_code(code_de(id))

## Libellé d'une commande selon la dernière entrée : bouton de manette ou touche du clavier (Touches.libelle).
static func libelle_courant(id: String) -> String:
	return libelle(id) if _active else Touches.libelle(id)

## Touches FIXES des menus (bandeaux « E Prendre », « Échap Fermer »…) -> bouton qui fait la même chose dans ces menus ;
## "" = pas d'équivalent (l'entrée est retirée du bandeau).
const EQUIVALENTS := {
	"E": "A", "Entrée": "A", "Espace": "A", "R": "Y", "G": "X", "C": "X", "F": "Y", "Tab": "LB / RB", "Échap": "B",
	"Flèches": "Croix", "← →": "Croix", "Haut / Bas": "Croix", "Gauche / Droite": "Croix", "Page préc. / suiv.": "LT / RT",
	"Clic gauche": "RT", "Clic droit": "LT", "1-0": "", "1 - 0": "", "Molette": "", "Retour": "B",
}

static func equivalent(touche: String) -> String:
	if touche == Touches.libelle_deplacement():
		return "Stick G"
	if touche == Touches.libelle("menu"):
		return "LB / RB"
	return String(EQUIVALENTS.get(touche, touche))

## Bandeau de touches [[touche, libellé, …], …] : tel quel au clavier ; à la manette, touches remplacées par leur bouton, entrées
## sans équivalent retirées, un même bouton jamais deux fois (le premier gagne).
static func traduire(lignes: Array) -> Array:
	if not _active:
		return lignes
	var r: Array = []
	var vus := {}
	for l: Array in lignes:
		var b := equivalent(String(l[0]))
		if b == "" or vus.has(b):
			continue
		vus[b] = true
		var n := l.duplicate()
		n[0] = b
		r.append(n)
	return r

# ------------------------------------------------------------------ réglages et sticks

static func reglage(cle: String) -> Variant:
	if _reglages_test.has(cle):
		return _reglages_test[cle]
	if Jeu.mode_outil():
		return REGLAGES_DEFAUT[cle]
	return Jeu.option("manette", cle)

## Réglages imposés par un test (mode outil : les options du joueur ne sont pas lues ; l'écran Options écrit ici en mode outil).
static var _reglages_test := {}

## Change un réglage (écran Options) : options.cfg en jeu, mémoire seulement en mode outil.
static func regler(cle: String, valeur: Variant) -> void:
	if Jeu.mode_outil():
		_reglages_test[cle] = valeur
	else:
		Jeu.regler("manette", cle, valeur)
	if cle == "zone_morte":
		appliquer()

static func sensibilite() -> float:
	return clampf(float(reglage("sensibilite")), 0.2, 3.0)

static func inverser_y() -> bool:
	return bool(reglage("inverser_y"))

static func zone_morte() -> float:
	return clampf(float(reglage("zone_morte")), 0.05, 0.5)

static func courbe() -> float:
	return float(COURBES[clampi(int(reglage("courbe")), 0, COURBES.size() - 1)])

## Réponse d'un stick : zone morte RADIALE (le stick qui « dérive » au repos ne fait rien), remise à l'échelle 0..1 au-delà, puis
## courbe (exposant : petits gestes plus fins, plein régime au bord).
static func reponse(v: Vector2, zone: float, exposant: float) -> Vector2:
	var l := v.length()
	if l <= zone:
		return Vector2.ZERO
	var n := clampf((l - zone) / (1.0 - zone), 0.0, 1.0)
	return v / l * pow(n, exposant)

## Stick droit après zone morte et courbe (x : droite +, y : bas +).
static func regard() -> Vector2:
	if not InputMap.has_action("regard_droite"):
		return Vector2.ZERO
	var v := Vector2(Input.get_action_raw_strength("regard_droite") - Input.get_action_raw_strength("regard_gauche"),
		Input.get_action_raw_strength("regard_bas") - Input.get_action_raw_strength("regard_haut"))
	return reponse(v, zone_morte(), courbe())

## Rotation de caméra (lacet, tangage en radians) pour `dt` secondes au stick droit : sensibilité et inversion Y comprises.
static func rotation_regard(dt: float) -> Vector2:
	var r := regard()
	if r == Vector2.ZERO:
		return Vector2.ZERO
	var k := sensibilite()
	return Vector2(-r.x * VITESSE_LACET * k * dt, -r.y * VITESSE_TANGAGE * k * dt * (-1.0 if inverser_y() else 1.0))

## Commande tenue sur une manette (bouton ou gâchette), sans compter le clavier ni la souris.
static func tenue(id: String) -> bool:
	var code := code_de(id)
	return code != AUCUN and _manette_presse(code)

static func _manette_presse(code: int) -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		pads = [0]   # événements simulés (tests) : appareil 0
	for p: int in pads:
		if code >= AXE:
			var axe := (code - AXE) / 2
			var s := -1.0 if (code - AXE) % 2 == 1 else 1.0
			if Input.get_joy_axis(p, axe as JoyAxis) * s >= SEUIL or etat_axe(p, axe) == int(s):
				return true
		elif Input.is_joy_button_pressed(p, code as JoyButton):
			return true
	return false
