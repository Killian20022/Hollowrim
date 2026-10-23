extends Node
## La musique et les ambiances ponctuelles. Choisit la piste selon la situation
## (combat > crypte > village > forêt) et enchaîne les morceaux par des fondus.
## Le monde pose `monde` avant add_child.

const VOLUME_DB := -12.0
const SILENCE_DB := -60.0
const FONDU := 2.5            # secondes
const RAYON_COMBAT := 30.0
const RAYON_VILLAGE := 30.0
const SORTIE_COMBAT := 6.0    # le combat « traîne » ce temps après la dernière menace
const PISTES := {
	"combat": ["res://assets/musique/combat_bataille.ogg"],
	"crypte": ["res://assets/musique/crypte_cavernes.ogg"],
	"village": ["res://assets/musique/village_auberge.ogg"],
	"foret": ["res://assets/musique/foret_cathedrale.ogg", "res://assets/musique/foret_hiver_nord.ogg"],
}

var monde: Node3D

var piste := ""                 # situation en cours
var _lecteurs: Array[AudioStreamPlayer] = []
var _actif := 0                 # index du lecteur audible
var _silence := 0.0             # attente avant le prochain morceau d'exploration
var _sortie_combat := 0.0
var _prochaine_bete := 0.0
var _derniere_foret := ""

func _ready() -> void:
	for i in 2:
		var l := AudioStreamPlayer.new()
		l.volume_db = SILENCE_DB
		l.finished.connect(_fini.bind(l))
		add_child(l)
		_lecteurs.append(l)
	_prochaine_bete = randf_range(40.0, 90.0)

## Situation voulue d'après l'état du monde.
func situation() -> String:
	var j: Node3D = monde.joueur
	if _sortie_combat > 0.0:
		return "combat"
	if (monde.tertre != null and monde.tertre.dedans) or (monde.grotte_acces != null and monde.grotte_acces.dedans):
		return "crypte"        # la même musique de cavernes sert à la grotte
	if Vector2(j.global_position.x - monde.VILLAGE.x, j.global_position.z - monde.VILLAGE.z).length() < RAYON_VILLAGE \
			or ReliefVillage.dans_enceinte(j.global_position.x, j.global_position.z, 6.0):   # C7b : toute l'enceinte v2 (haute rue, tour)
		return "village"
	return "foret"

func _menace() -> bool:
	var j: Node3D = monde.joueur
	for e in get_tree().get_nodes_in_group("ennemis"):
		if is_instance_valid(e) and e.has_method("en_combat") and e.en_combat() \
				and e.global_position.distance_to(j.global_position) < RAYON_COMBAT:
			return true
	return false

func _process(dt: float) -> void:
	if monde == null or monde.joueur == null:
		return
	if _menace():
		_sortie_combat = SORTIE_COMBAT
	else:
		_sortie_combat = maxf(0.0, _sortie_combat - dt)
	var voulue := situation()
	if voulue != piste:
		_changer(voulue)
	elif piste == "foret" and not _lecteurs[_actif].playing:
		_silence -= dt
		if _silence <= 0.0:
			_lancer(_lecteurs[_actif], _choisir())
	_bruits_lointains(dt)

func _choisir() -> String:
	var choix: Array = PISTES[piste].duplicate()
	if choix.size() > 1:
		choix.erase(_derniere_foret)
	var chemin: String = choix.pick_random()
	if piste == "foret":
		_derniere_foret = chemin
	return chemin

func _lancer(l: AudioStreamPlayer, chemin: String) -> void:
	l.stream = load(chemin)
	l.volume_db = VOLUME_DB if l == _lecteurs[_actif] else SILENCE_DB
	l.play()

## Fondu enchaîné vers une nouvelle situation.
func _changer(voulue: String) -> void:
	piste = voulue
	var ancien := _lecteurs[_actif]
	_actif = 1 - _actif
	var nouveau := _lecteurs[_actif]
	_fondu(ancien, SILENCE_DB, true)
	if voulue == "foret" and randf() < 0.5:
		# on laisse parfois la forêt au silence avant le premier morceau
		_silence = randf_range(10.0, 30.0)
		return
	_silence = 0.0
	nouveau.stream = load(_choisir())
	nouveau.volume_db = SILENCE_DB
	nouveau.play()
	_fondu(nouveau, VOLUME_DB, false)

func _fondu(l: AudioStreamPlayer, vers: float, arreter: bool) -> void:
	var tw := create_tween()
	tw.tween_property(l, "volume_db", vers, FONDU)
	if arreter:
		tw.tween_callback(func() -> void:
			if l != _lecteurs[_actif]:
				l.stop())

## Fin d'un morceau : combat, crypte et village bouclent ; la forêt s'offre un silence.
func _fini(l: AudioStreamPlayer) -> void:
	if l != _lecteurs[_actif]:
		return
	if piste == "foret":
		_silence = randf_range(20.0, 60.0)
	else:
		_lancer(l, _choisir())

## Corbeau ou loup lointain en forêt, toutes les 40 à 90 s (jamais sous terre).
func _bruits_lointains(dt: float) -> void:
	if (monde.tertre != null and monde.tertre.dedans) or (monde.grotte_acces != null and monde.grotte_acces.dedans):
		return
	_prochaine_bete -= dt
	if _prochaine_bete > 0.0:
		return
	_prochaine_bete = randf_range(40.0, 90.0)
	if piste != "foret":
		return
	var a := randf() * TAU
	var p: Vector3 = monde.joueur.global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(30.0, 60.0)
	p.y += 3.0
	Sons.jouer_a(self, [["ambiance_corbeau", "ambiance_loup"].pick_random()], p, -14.0, 0.1)
