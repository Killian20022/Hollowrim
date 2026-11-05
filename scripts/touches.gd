class_name Touches
extends RefCounted
## Touches du jeu : une ACTION de l'InputMap par commande, avec deux touches possibles (principale et secondaire).
## Le code du jeu ne teste jamais une touche en dur : il interroge l'action (Input.is_action_pressed("saut"),
## e.is_action_pressed("torche", false)…), de sorte que le remappage (Options > Touches) s'applique partout.
## Les touches sont des touches PHYSIQUES (position sur le clavier : ZQSD en AZERTY = WASD) ; libelle() les écrit
## comme le clavier du joueur les affiche. Enregistrement : user://options.cfg, section « touches » (Jeu.regler).
## En mode outil (tests, captures) les réglages du joueur ne sont pas lus : touches par défaut, jamais enregistrées.

## id de l'action, nom affiché, [principale, secondaire] par défaut (KEY_NONE = aucune).
const ACTIONS := [
	{"id": "avant", "nom": "Avancer", "defaut": [KEY_W, KEY_UP]},
	{"id": "arriere", "nom": "Reculer", "defaut": [KEY_S, KEY_DOWN]},
	{"id": "gauche", "nom": "Aller à gauche", "defaut": [KEY_A, KEY_LEFT]},
	{"id": "droite", "nom": "Aller à droite", "defaut": [KEY_D, KEY_RIGHT]},
	{"id": "course", "nom": "Courir", "defaut": [KEY_SHIFT, KEY_NONE]},
	{"id": "saut", "nom": "Sauter", "defaut": [KEY_SPACE, KEY_NONE]},
	{"id": "esquive", "nom": "Esquiver (pas de côté / en arrière)", "defaut": [KEY_ALT, KEY_C]},
	{"id": "interagir", "nom": "Parler, ouvrir, ramasser", "defaut": [KEY_E, KEY_NONE]},
	{"id": "torche", "nom": "Torche", "defaut": [KEY_T, KEY_NONE]},
	{"id": "vue", "nom": "Vue 1re / 3e personne", "defaut": [KEY_V, KEY_NONE]},
	{"id": "menu", "nom": "Menu du personnage", "defaut": [KEY_TAB, KEY_NONE]},
	{"id": "inventaire", "nom": "Sac", "defaut": [KEY_I, KEY_NONE]},
	{"id": "competences", "nom": "Compétences", "defaut": [KEY_K, KEY_NONE]},
	{"id": "quetes", "nom": "Quêtes", "defaut": [KEY_J, KEY_NONE]},
	{"id": "carte", "nom": "Carte", "defaut": [KEY_M, KEY_NONE]},
	{"id": "sauvegarde_rapide", "nom": "Sauvegarde rapide", "defaut": [KEY_F5, KEY_NONE]},
	{"id": "chargement_rapide", "nom": "Chargement rapide", "defaut": [KEY_F9, KEY_NONE]},
	{"id": "aide", "nom": "Aide des touches", "defaut": [KEY_F1, KEY_NONE]},
]
## Touches qu'on ne peut pas attribuer (menus, plein écran, débogage).
const RESERVEES := [KEY_ESCAPE, KEY_F11, KEY_ENTER, KEY_KP_ENTER, KEY_F3, KEY_P]

## id -> [principale, secondaire] (codes de touches physiques) : l'état courant, appliqué à l'InputMap par installer().
static var liaisons := {}

static func _defauts() -> Dictionary:
	var d := {}
	for a: Dictionary in ACTIONS:
		d[a["id"]] = (a["defaut"] as Array).duplicate()
	return d

## Section « touches » des options par défaut (Jeu.OPTIONS_DEFAUT) : "<id>" et "<id>_2".
static func options_defaut() -> Dictionary:
	var d := {}
	for a: Dictionary in ACTIONS:
		d[a["id"]] = int(a["defaut"][0])
		d[String(a["id"]) + "_2"] = int(a["defaut"][1])
	return d

## Relit les réglages du joueur (ou les touches par défaut en mode outil) puis applique tout à l'InputMap.
static func charger() -> void:
	liaisons = _defauts()
	if not Jeu.mode_outil():
		for a: Dictionary in ACTIONS:
			var id: String = a["id"]
			liaisons[id] = [int(Jeu.option("touches", id)), int(Jeu.option("touches", id + "_2"))]
	appliquer()

## Crée (si besoin) les actions et leur donne leurs touches. Sans danger si appelé plusieurs fois (joueur, menus…).
static func installer() -> void:
	if liaisons.is_empty():
		charger()
	elif not InputMap.has_action("avant") or not InputMap.has_action("menu"):
		appliquer()

static func appliquer() -> void:
	if liaisons.is_empty():
		liaisons = _defauts()
	for a: Dictionary in ACTIONS:
		var id: String = a["id"]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		for k: int in liaisons[id]:
			if k != KEY_NONE:
				var e := InputEventKey.new()
				e.physical_keycode = k as Key
				InputMap.action_add_event(id, e)

static func touches_de(id: String) -> Array:
	installer()
	return liaisons.get(id, [KEY_NONE, KEY_NONE])

## Écrit une touche physique comme le clavier du joueur l'affiche (« Z » pour la touche W d'un AZERTY).
static func nom_touche(k: int) -> String:
	if k == KEY_NONE:
		return "—"
	var key := k as Key
	var etiquette: Key = DisplayServer.keyboard_get_label_from_physical(key) if DisplayServer.get_name() != "headless" else key
	var cle: Key = etiquette if etiquette != KEY_NONE else key
	var t := OS.get_keycode_string(cle)
	match cle:   # noms français, et signes de ponctuation écrits tels quels (la police pixel n'a pas de flèches)
		KEY_UP: t = "Haut"
		KEY_DOWN: t = "Bas"
		KEY_LEFT: t = "Gauche"
		KEY_RIGHT: t = "Droite"
		KEY_SHIFT: t = "Maj"
		KEY_SPACE: t = "Espace"
		KEY_CTRL: t = "Ctrl"
		KEY_ALT: t = "Alt"
		KEY_TAB: t = "Tab"
		KEY_COMMA: t = ","
		KEY_PERIOD: t = "."
		KEY_SEMICOLON: t = ";"
		KEY_COLON: t = ":"
		KEY_SLASH: t = "/"
		KEY_BACKSLASH: t = "\\"
		KEY_APOSTROPHE: t = "'"
		KEY_MINUS: t = "-"
		KEY_EQUAL: t = "="
		KEY_PAGEUP: t = "Page préc."
		KEY_PAGEDOWN: t = "Page suiv."
		KEY_BACKSPACE: t = "Retour"
	return t

## Touche principale d'une action, écrite pour le joueur (« E », « Tab »…) : textes d'aide et bandeaux.
static func libelle(id: String) -> String:
	return nom_touche(int(touches_de(id)[0]))

## Les deux touches (« Z / ↑ »), ou seulement la principale si la seconde est vide.
static func libelles(id: String) -> String:
	var t := touches_de(id)
	if int(t[1]) == KEY_NONE:
		return nom_touche(int(t[0]))
	return "%s / %s" % [nom_touche(int(t[0])), nom_touche(int(t[1]))]

## Déplacements écrits d'un bloc (« ZQSD » ou « WASD » selon le clavier) ; « Z / Q / S / D » avec des touches plus longues.
static func libelle_deplacement() -> String:
	var l: Array = []
	for id in ["avant", "gauche", "arriere", "droite"]:
		l.append(libelle(id))
	return "".join(l) if l.all(func(t: String) -> bool: return t.length() == 1) else " / ".join(l)

## Action qui utilise déjà la touche `k` (hors `sauf`), "" si elle est libre.
static func action_de(k: int, sauf := "", sauf_rang := -1) -> String:
	installer()
	for a: Dictionary in ACTIONS:
		var id: String = a["id"]
		for r in 2:
			if id == sauf and r == sauf_rang:
				continue
			if int(liaisons[id][r]) == k:
				return id
	return ""

static func attribuable(k: int) -> bool:
	return k != KEY_NONE and not (k in RESERVEES)

## Attribue la touche `k` au rang `rang` (0 principale, 1 secondaire) de l'action `id`. Si une autre commande l'utilisait,
## elle reçoit l'ancienne touche de celle-ci (échange) : jamais deux commandes sur la même touche, jamais de commande orpheline.
## k = KEY_NONE efface le rang (permis seulement pour la touche secondaire). Renvoie le nom de l'action échangée ("" si aucune).
static func lier(id: String, rang: int, k: int) -> String:
	installer()
	if k == KEY_NONE:
		if rang == 0:
			return ""
		liaisons[id][rang] = KEY_NONE
		_enregistrer()
		return ""
	if not attribuable(k):
		return ""
	var ancien: int = int(liaisons[id][rang])
	var autre := ""
	for a: Dictionary in ACTIONS:
		var oid: String = a["id"]
		for r in 2:
			if (oid == id and r == rang) or int(liaisons[oid][r]) != k:
				continue
			autre = oid
			liaisons[oid][r] = KEY_NONE if oid == id else ancien   # même commande, autre rang : déplacée ; sinon échange
	liaisons[id][rang] = k
	_enregistrer()
	return autre

static func retablir() -> void:
	liaisons = _defauts()
	_enregistrer()

static func _enregistrer() -> void:
	appliquer()
	if Jeu.mode_outil():
		return
	for a: Dictionary in ACTIONS:
		var id: String = a["id"]
		Jeu.regler("touches", id, int(liaisons[id][0]), false)
		Jeu.regler("touches", id + "_2", int(liaisons[id][1]), false)
	Jeu.ecrire_options()
