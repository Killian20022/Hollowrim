class_name ATerre
extends Node
## LOT 3 — état « à terre » (coop). Nœud permanent enfant du joueur LOCAL (joueur.gd l'installe ; inerte en solo).
##   - 0 PV en coop avec au moins un allié DEBOUT : le joueur tombe (joueur.a_terre, 0 PV, immobile, ne peut rien faire, invulnérable) ;
##     DUREE s plus tard sans secours -> mort habituelle (joueur.mort + signal deces : rechargement du monde). Aucun allié debout
##     (solo, seul, tous à terre / partis) -> mort immédiate comme avant.
##   - un allié à moins de PORTEE m qui maintient l'action « interagir » (E) RELEVER_S s relève le joueur (PV partiels : PV_RELEVE).
##   - chaque machine connaît l'état de tous (évènement « a_terre_etat » : id = pair, donnees = {t: bool}) ; « a_terre_releve » (vers le
##     pair à terre) déclenche le relèvement chez lui. Avatars distants = nœuds « Joueur_<id> » (registre ou frère du joueur).
## Indications minimales : voile rouge + compte à rebours chez le joueur à terre, « Maintenez E » + progression chez le secouriste.

const DUREE := 30.0
const RELEVER_S := 3.0
const PORTEE := 2.5
const PV_RELEVE := 0.3          # part de vie_max au relèvement

## Test : simule la touche d'interaction maintenue (headless : aucune entrée).
static var touche_forcee := false

var joueur: CharacterBody3D
var reste := 0.0                # secondes avant la mort (à terre)
var etats := {}                 # pair -> à terre ? (tous les pairs connus)
var _prog := 0.0                # relèvement d'un allié en cours
var _hors_prec := false         # dernier état annoncé : à terre OU mort (= ne peut pas secourir)
var _cible := 0                 # pair en cours de relèvement
var _calque: CanvasLayer
var _voile: ColorRect
var _texte: Label

static func installer(j: CharacterBody3D) -> ATerre:
	var a := ATerre.new()
	a.name = "ATerre"
	a.joueur = j
	j.add_child(a)
	return a

static func de(j: Node) -> ATerre:
	return j.get_node_or_null("ATerre") as ATerre if j != null else null

## Peut-on tomber plutôt que mourir ? (coop, joueur local, un allié debout)
static func peut_tomber(j: Node) -> bool:
	var a := de(j)
	return a != null and PauseCoop.R().est_en_ligne() and bool(j.get("est_local")) and a.allies_debout() > 0

static func tomber(j: Node) -> void:
	var a := de(j)
	if a != null:
		a._tomber()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseCoop.R().abonner("a_terre_etat", _sur_etat)
	PauseCoop.R().abonner("a_terre_releve", _sur_releve)
	PauseCoop.R().joueur_deconnecte.connect(func(id: int) -> void: etats.erase(id))
	_calque = CanvasLayer.new()
	_calque.layer = 45
	add_child(_calque)
	_voile = ColorRect.new()
	_voile.color = Color(0.5, 0.0, 0.0, 0.35)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.visible = false
	_calque.add_child(_voile)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_CENTER)
	_texte.position = Vector2(-220, 40)
	_texte.size = Vector2(440, 60)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_color_override("font_color", Color(0.95, 0.85, 0.7))
	_texte.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_texte.add_theme_constant_override("outline_size", 4)
	_texte.visible = false
	_calque.add_child(_texte)

func _exit_tree() -> void:
	PauseCoop.R().desabonner("a_terre_etat", _sur_etat)
	PauseCoop.R().desabonner("a_terre_releve", _sur_releve)

func est_a_terre(pair: int) -> bool:
	return bool(etats.get(pair, false))

## Alliés connectés qui ne sont ni à terre ni morts (« hors jeu » = à terre ou mort, annoncé par évènement).
func allies_debout() -> int:
	var n := 0
	for id: int in PauseCoop.R().joueurs():
		if id != PauseCoop.R().mon_id() and not est_a_terre(id):
			n += 1
	return n

# ------------------------------------------------------------------------------------------------ chute / relèvement

func _tomber() -> void:
	joueur.a_terre = true
	joueur.vie = 0.0
	joueur.velocity = Vector3.ZERO
	joueur.set("en_dialogue", true)       # contrôles gelés (marche, combat, menus)
	reste = DUREE
	joueur.avis.emit("Vous êtes à terre : un allié peut vous relever.")

func _releve() -> void:
	if not joueur.a_terre:
		return
	joueur.a_terre = false
	joueur.vie = maxf(1.0, joueur.vie_max * PV_RELEVE)
	joueur.tete.rotation.z = 0.0
	if not PauseCoop.occupe():
		joueur.set("en_dialogue", false)
	reste = 0.0
	joueur.avis.emit("Vous êtes relevé.")

func _mourir() -> void:
	joueur.a_terre = false
	joueur.mort = true
	reste = 0.0
	joueur.deces.emit()

func _annoncer(t: bool) -> void:
	etats[PauseCoop.R().mon_id()] = t
	PauseCoop.R().envoyer_evenement("a_terre_etat", PauseCoop.R().mon_id(), {"t": t})

func _sur_etat(_exp: int, id: Variant, d: Variant) -> void:
	etats[int(id)] = bool(d["t"])
	if int(id) != PauseCoop.R().mon_id():
		var av := noeud_de(int(id))   # avatar distant : l'état « à terre » suit le registre (cibles des PNJ / ennemis)
		if av != null and "a_terre" in av:
			av.a_terre = bool(d["t"])

func _sur_releve(_exp: int, id: Variant, _d: Variant) -> void:
	if int(id) == PauseCoop.R().mon_id():
		_releve()

# ------------------------------------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	if joueur == null or not PauseCoop.R().est_en_ligne():
		_voile.visible = false
		_texte.visible = false
		return
	var hors: bool = joueur.a_terre or joueur.mort
	if hors != _hors_prec:
		_hors_prec = hors
		_annoncer(hors)       # à terre, mort, relevé ou réapparu : tous les pairs le savent
	if joueur.a_terre:
		joueur.set("en_dialogue", true)
		reste -= dt
		if reste <= 0.0 or allies_debout() == 0:
			_mourir()      # personne pour relever (ou tous à terre) : mort / rechargement habituels
			return
		_voile.visible = true
		_texte.visible = true
		_texte.text = "À TERRE — %d s\nUn allié peut vous relever (maintenir E)" % ceili(reste)
		return
	_voile.visible = false
	if joueur.mort:
		_texte.visible = false
		return
	_secourir(dt)

## Secouriste : maintenir « interagir » près d'un allié à terre.
func _secourir(dt: float) -> void:
	var cible := _plus_proche_a_terre()
	var tenue := touche_forcee or (InputMap.has_action("interagir") and Input.is_action_pressed("interagir"))
	if cible == 0 or not tenue or joueur.en_dialogue:
		if cible != _cible:
			_prog = 0.0
		_cible = cible
		if cible != 0 and not joueur.en_dialogue:
			_texte.visible = true
			_texte.text = "Joueur %d est à terre\nMaintenez E pour le relever" % cible
		else:
			_texte.visible = false
		if not tenue:
			_prog = 0.0
		return
	if cible != _cible:
		_prog = 0.0
		_cible = cible
	_prog += dt
	_texte.visible = true
	_texte.text = "Relèvement de Joueur %d : %d %%" % [cible, int(clampf(_prog / RELEVER_S, 0.0, 1.0) * 100.0)]
	if _prog >= RELEVER_S:
		_prog = 0.0
		PauseCoop.R().envoyer_evenement("a_terre_releve", cible, null, cible)
		etats[cible] = false      # en attendant la confirmation (a_terre_etat) du relevé lui-même

func _plus_proche_a_terre() -> int:
	var meilleur := 0
	var dmin := PORTEE
	for id: int in etats:
		if id == PauseCoop.R().mon_id() or not bool(etats[id]):
			continue
		var n := noeud_de(id)
		if n == null:
			continue
		var d := joueur.global_position.distance_to(n.global_position)
		if d <= dmin:
			dmin = d
			meilleur = id
	return meilleur

func noeud_de(id: int) -> Node3D:
	var n: Node = PauseCoop.R().registre.noeud(id)
	if n == null and joueur.get_parent() != null:
		n = joueur.get_parent().get_node_or_null("Joueur_%d" % id)
	return n as Node3D
