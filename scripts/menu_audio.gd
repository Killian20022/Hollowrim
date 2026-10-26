class_name MenuAudio
extends Node
## Sons du menu principal : musique (bus « Musique »), ambiances en boucle (vent, torche, eau) et sons d'interface (bus « Effets »).
## Les volumes du joueur (Options : général, musique, effets) s'appliquent par les bus (Jeu.appliquer_son), en direct.
## Fichiers : res://audio/menu/ (CC0, crédits dans assets/LICENCES.md). Un fichier absent est simplement ignoré (repli silencieux).
## Changer de musique : modifier PISTE (index dans PISTES_MUSIQUE) ou ajouter une piste à la liste.

const PISTES_MUSIQUE := [
	"res://audio/menu/musique_4_beyond_the_frozen_veil_boucle.ogg",   # synth-thetic, conçue pour boucler
	"res://audio/menu/musique_2_long_winter.ogg",                      # indieteur, morceau entier (bouclé tel quel)
]
const PISTE := 0
const VOLUME_MUSIQUE_DB := -9.0
## [chemin, volume dB] : boucles normalisées à -3 dBFS en crête, donc nettement baissées ici.
const AMBIANCES := {
	"vent": ["res://audio/menu/vent_boucle.ogg", -17.0],
	"torche": ["res://audio/menu/torche_boucle.ogg", -21.0],
	"eau": ["res://audio/menu/eau_boucle.ogg", -25.0],
}
const SONS := {
	"survol": ["res://audio/menu/ui_survol.ogg", -17.0],
	"validation": ["res://audio/menu/ui_validation.ogg", -9.0],
	"transition": ["res://audio/menu/ui_transition.ogg", -11.0],
	"retour": ["res://audio/menu/ui_survol.ogg", -15.0],
}
const SILENCE_DB := -60.0

var _musique: AudioStreamPlayer
var _ambiances: Array[AudioStreamPlayer] = []
var _volumes := {}   # lecteur → volume cible (dB)
var _dernier_survol := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := _flux(PISTES_MUSIQUE[clampi(PISTE, 0, PISTES_MUSIQUE.size() - 1)], true)
	if m != null:
		_musique = _lecteur(m, &"Musique", VOLUME_MUSIQUE_DB)
	for nom: String in AMBIANCES:
		var f := _flux(AMBIANCES[nom][0], true)
		if f != null:
			_ambiances.append(_lecteur(f, &"Effets", AMBIANCES[nom][1]))

## Tout démarre en silence puis monte en `fondu` secondes (la musique un peu après les ambiances).
func demarrer(fondu := 2.5) -> void:
	for l: AudioStreamPlayer in _tous():
		l.volume_db = SILENCE_DB
		l.play(randf() * 8.0 if l != _musique else 0.0)
		var tw := create_tween()
		if l == _musique:
			tw.tween_interval(0.6)
		tw.tween_property(l, "volume_db", _volumes[l], fondu).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Baisse progressive de tout (avant le chargement du monde) ; `await` possible.
func baisser(duree := 1.4) -> void:
	var tous := _tous()
	if tous.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for l: AudioStreamPlayer in tous:
		tw.tween_property(l, "volume_db", SILENCE_DB, duree).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	for l: AudioStreamPlayer in tous:
		l.stop()

func jouer(nom: String) -> void:
	if not SONS.has(nom):
		return
	if nom == "survol":   # survols en rafale (souris qui balaie la colonne) : un son toutes les 60 ms au plus
		if Time.get_ticks_msec() - _dernier_survol < 60:
			return
		_dernier_survol = Time.get_ticks_msec()
	var f := _flux(SONS[nom][0], false)
	if f == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = f
	a.bus = &"Effets"
	a.volume_db = SONS[nom][1]
	a.pitch_scale = randf_range(0.97, 1.03) if nom == "survol" else 1.0
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func musique_presente() -> bool:
	return _musique != null

func _tous() -> Array[AudioStreamPlayer]:
	var t: Array[AudioStreamPlayer] = []
	if _musique != null:
		t.append(_musique)
	t.append_array(_ambiances)
	return t

func _lecteur(f: AudioStream, bus: StringName, volume: float) -> AudioStreamPlayer:
	var l := AudioStreamPlayer.new()
	l.stream = f
	l.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	l.volume_db = SILENCE_DB
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(l)
	_volumes[l] = volume
	return l

static func _flux(chemin: String, boucle: bool) -> AudioStream:
	if not ResourceLoader.exists(chemin):
		return null
	var f: AudioStream = load(chemin)
	if f == null:
		return null
	if boucle and "loop" in f:
		f = f.duplicate()
		f.set("loop", true)
	return f
