class_name Mixage
## Table de mixage du jeu : bus, reverb « Sous-terre », limiteur du master, ducking de la musique.
##
##   Musique ─────────────────────────────┐                    (Amplify « ducking » : -9 dB pendant un dialogue / un finisher)
##   Ambiance ─┐                          ├─► Master (HardLimiter -0,5 dB)
##   Effets ───┴─► SousTerre (Reverb) ────┤
##   Interface ───────────────────────────┘                    (UI, menus, voix de dialogue : jamais de reverb)
##
## Le bus SousTerre est toujours dans la chaîne, mais sa reverb n'est ACTIVE que sous terre ou dans un intérieur : dehors,
## l'effet est désactivé (aucun coût, son sec). La taille de salle dépend du lieu (ZONES). Les transitions sont des fondus
## du mélange « wet » (≈ 1,2 s) : jamais de coupure. Les volumes du joueur (Options) passent par Jeu.appliquer_son.

const MUSIQUE := &"Musique"
const AMBIANCE := &"Ambiance"
const EFFETS := &"Effets"
const INTERFACE := &"Interface"
const SOUS_TERRE := &"SousTerre"
const BUS_ROUTES := [MUSIQUE, AMBIANCE, EFFETS, INTERFACE]   # enfants de Master (Ambiance et Effets passent par SousTerre)

## Salles : taille de la pièce, absorption des aigus, part de reverb, retard initial (ms).
const ZONES := {
	"dehors": {"wet": 0.0},
	"grotte": {"room": 0.90, "damp": 0.45, "wet": 0.34, "predelay": 45.0},    # grande caverne : longue traîne
	"crypte": {"room": 0.62, "damp": 0.30, "wet": 0.28, "predelay": 25.0},    # couloirs et salles de pierre nue : dur et clair
	"maison": {"room": 0.20, "damp": 0.75, "wet": 0.14, "predelay": 8.0},     # pièce de bois, tentures : courte et mate
}
const FONDU_REVERB := 1.2      # s
const LIMITE_DB := -0.5        # plafond du limiteur du master
const DUCK_DB := -9.0          # baisse de la musique
const DUCK_ENTREE := 0.45
const DUCK_SORTIE := 1.4

const SCRIPT_MUSIQUE := preload("res://scripts/musique.gd")

static var zone := "dehors"
static var _tw: Tween
static var _tw_duck: Tween
static var _duck := {}         # source -> true (dialogue, finisher)

## Crée les bus et leurs effets (idempotent) : appelé par Jeu.creer_bus au lancement du jeu et par les tests.
static func creer() -> void:
	# ORDRE : un bus n'envoie qu'à un bus d'indice PLUS BAS (le serveur mixe du dernier au premier) → SousTerre avant Ambiance et Effets
	for nom: StringName in [SOUS_TERRE, MUSIQUE, AMBIANCE, EFFETS, INTERFACE]:
		if AudioServer.get_bus_index(nom) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, nom)
	for nom: StringName in BUS_ROUTES + [SOUS_TERRE]:
		AudioServer.set_bus_send(AudioServer.get_bus_index(nom), &"Master")
	for nom: StringName in [AMBIANCE, EFFETS]:
		AudioServer.set_bus_send(AudioServer.get_bus_index(nom), SOUS_TERRE)
	# limiteur léger sur le master (les sorts en rafale et les impacts ne saturent plus)
	if _effet(&"Master", AudioEffectHardLimiter) == null:
		var l := AudioEffectHardLimiter.new()
		l.pre_gain_db = 0.0
		l.ceiling_db = LIMITE_DB
		l.release = 0.08
		AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Master"), l)
	if _effet(MUSIQUE, AudioEffectAmplify) == null:
		AudioServer.add_bus_effect(AudioServer.get_bus_index(MUSIQUE), AudioEffectAmplify.new())
	if _effet(SOUS_TERRE, AudioEffectReverb) == null:
		var r := AudioEffectReverb.new()
		r.dry = 1.0
		r.wet = 0.0
		r.hipass = 0.1
		AudioServer.add_bus_effect(AudioServer.get_bus_index(SOUS_TERRE), r)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(SOUS_TERRE), 0, false)

static func _effet(bus: StringName, type: Variant) -> AudioEffect:
	var b := AudioServer.get_bus_index(bus)
	if b == -1:
		return null
	for i in AudioServer.get_bus_effect_count(b):
		var e := AudioServer.get_bus_effect(b, i)
		if is_instance_of(e, type):
			return e
	return null

static func reverb() -> AudioEffectReverb:
	return _effet(SOUS_TERRE, AudioEffectReverb) as AudioEffectReverb

## Vrai si la reverb du bus SousTerre est allumée.
static func reverb_active() -> bool:
	var b := AudioServer.get_bus_index(SOUS_TERRE)
	if b == -1:
		return false
	for i in AudioServer.get_bus_effect_count(b):
		if AudioServer.get_bus_effect(b, i) is AudioEffectReverb:
			return AudioServer.is_bus_effect_enabled(b, i)
	return false

static func _allumer(oui: bool) -> void:
	var b := AudioServer.get_bus_index(SOUS_TERRE)
	for i in AudioServer.get_bus_effect_count(b):
		if AudioServer.get_bus_effect(b, i) is AudioEffectReverb:
			AudioServer.set_bus_effect_enabled(b, i, oui)

static func _arbre() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Passe dans la salle `nom` ("dehors", "grotte", "crypte", "maison") : fondu du mélange wet. `duree` 0 = tout de suite.
static func zone_vers(nom: String, duree := FONDU_REVERB) -> void:
	if not ZONES.has(nom) or AudioServer.get_bus_index(SOUS_TERRE) == -1:
		return
	var r := reverb()
	if r == null:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var avant := zone
	zone = nom
	var cible: Dictionary = ZONES[nom]
	var tree := _arbre()
	if duree <= 0.0 or tree == null:
		if nom == "dehors":
			r.wet = 0.0
			_allumer(false)
		else:
			_regler(r, cible)
			r.wet = float(cible["wet"])
			_allumer(true)
		return
	_tw = tree.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if nom == "dehors":
		_tw.tween_property(r, "wet", 0.0, duree)
		_tw.tween_callback(func() -> void:
			if zone == "dehors":
				_allumer(false))
		return
	if reverb_active() and avant != "dehors" and avant != nom:
		_tw.tween_property(r, "wet", 0.0, duree * 0.3)   # d'une salle à l'autre : on éteint, on change la taille, on rallume
		_tw.tween_callback(_regler.bind(r, cible))
	else:
		r.wet = 0.0
		_regler(r, cible)
		_allumer(true)
	_tw.tween_property(r, "wet", float(cible["wet"]), duree)

static func _regler(r: AudioEffectReverb, c: Dictionary) -> void:
	r.room_size = float(c["room"])
	r.damping = float(c["damp"])
	r.predelay_msec = float(c["predelay"])
	r.spread = 1.0

## Duck : la musique baisse tant qu'au moins une source (« dialogue », « finisher ») le demande.
static func duck(source: String, oui: bool) -> void:
	if oui == _duck.has(source):
		return
	if oui:
		_duck[source] = true
	else:
		_duck.erase(source)
	var a := _effet(MUSIQUE, AudioEffectAmplify) as AudioEffectAmplify
	var tree := _arbre()
	if a == null or tree == null:
		return
	if _tw_duck != null and _tw_duck.is_valid():
		_tw_duck.kill()
	var vers := DUCK_DB if not _duck.is_empty() else 0.0
	_tw_duck = tree.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw_duck.tween_property(a, "volume_db", vers, DUCK_ENTREE if vers < 0.0 else DUCK_SORTIE).set_trans(Tween.TRANS_SINE)

static func duck_db() -> float:
	var a := _effet(MUSIQUE, AudioEffectAmplify) as AudioEffectAmplify
	return a.volume_db if a != null else 0.0

static func est_duck() -> bool:
	return not _duck.is_empty()

## Remet la table à zéro (tests, retour au titre).
static func reinitialiser() -> void:
	_duck.clear()
	zone_vers("dehors", 0.0)
	var a := _effet(MUSIQUE, AudioEffectAmplify) as AudioEffectAmplify
	if a != null:
		a.volume_db = 0.0
	zone = "dehors"

## Bus d'un lecteur resté sur Master (Lancement) : lecteurs du nœud Musique → Musique ; vent, feu et ambiances (générateurs, fichiers
## « ambiance_* ») → Ambiance ; sons d'interface (fichiers « ui_* ») → Interface ; le reste → Effets.
static func bus_de(n: Node) -> StringName:
	var p := n.get_parent()
	if p != null and p.get_script() == SCRIPT_MUSIQUE:
		return MUSIQUE
	var f: AudioStream = n.get("stream")
	if f is AudioStreamGenerator:
		return AMBIANCE
	var nom := f.resource_path.get_file() if f != null else ""
	if nom.begins_with("ambiance_"):
		return AMBIANCE
	if nom.begins_with("ui_"):
		return INTERFACE
	return EFFETS
