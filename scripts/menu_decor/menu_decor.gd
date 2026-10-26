extends Control
class_name MenuDecor
## Décor animé de l'écran titre (peinture 1920×1080 + shader + particules). Scène : res://scenes/menu_decor/menu_decor.tscn.
## Plein écran, cadrage « cover » (jamais déformé, recadré sur les bords selon le format d'écran).
## API : pulse_cristal(), set_logo_peint(bool), fondu_sortie(duree), fondu_entree(duree), set_animations(bool). Voir LISEZMOI.md.

signal fondu_termine

const TAILLE := Vector2(1920.0, 1080.0)

## Travelling latéral en sinus : amplitude au premier plan (px du fond) et période (s). Le ciel bouge ~8 fois moins.
@export var amplitude_px := 5.0
@export var periode_s := 50.0
## Marge du cadrage (1.012 = 1,2 % de rogné en plus) : cache les bords pendant le travelling.
@export var marge := 1.012
## Point d'ancrage du recadrage (0,5 ; 0,5 = centré). En 21:9 l'image est rognée en haut et en bas : y < 0,5 garde le haut (logo).
@export var ancrage := Vector2(0.5, 0.3)
## Vent de la neige : rafales lentes (px/s² appliqués à la gravité horizontale des flocons).
@export var force_vent := 7.0

@onready var _cadre: Control = $Cadre
@onready var _fond: TextureRect = $Cadre/Fond
@onready var _logo: TextureRect = $Cadre/LogoPeint
@onready var _halo: Sprite2D = $Cadre/HaloCristal
@onready var _neige_loin: GPUParticles2D = $Cadre/NeigeLoin
@onready var _neige_milieu: GPUParticles2D = $Cadre/NeigeMilieu
@onready var _neige_pres: GPUParticles2D = $Cadre/NeigePres
@onready var _fumees: Node2D = $Cadre/Fumees
@onready var _braises: Node2D = $Cadre/Braises
@onready var _fondu: ColorRect = $Fondu

var _t := 0.0
var _pulse := 0.0
var _tw_pulse: Tween
var _tw_fondu: Tween
var _animations := true
var _logo_peint := true
var _base_neige := {} # GPUParticles2D → position de repos
var _base_halo := Vector2.ZERO
var _base_logo := Vector2.ZERO
var _base_fumees := Vector2.ZERO
var _base_braises := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_cadrer)
	for n in [_neige_loin, _neige_milieu, _neige_pres]:
		_base_neige[n] = n.position
		# chaque couche a son propre matériau : le vent y est réglé séparément
		n.process_material = n.process_material.duplicate()
	_base_halo = _halo.position
	_base_logo = _logo.position
	_base_fumees = _fumees.position
	_base_braises = _braises.position
	_cadrer()
	_process(0.0)

func _cadrer() -> void:
	var s := maxf(size.x / TAILLE.x, size.y / TAILLE.y) * marge
	if s <= 0.0:
		return
	_cadre.scale = Vector2(s, s)
	_cadre.position = (size - TAILLE * s) * ancrage

func _process(delta: float) -> void:
	if _animations:
		_t += delta
	# caméra : sinus très lent (le contenu se déplace de decalage × profondeur)
	var w := TAU / periode_s
	var dec := Vector2(sin(_t * w) * amplitude_px, sin(_t * w * 0.73 + 1.3) * amplitude_px * 0.18)
	if not _animations:
		dec = Vector2.ZERO
	(_fond.material as ShaderMaterial).set_shader_parameter("decalage_px", dec)
	_logo.position = _base_logo + dec * 0.12
	_halo.position = _base_halo + dec * 0.12
	_fumees.position = _base_fumees + dec * 0.42
	_braises.position = _base_braises + dec * 0.92
	_neige_loin.position = _base_neige[_neige_loin] + dec * 0.3
	_neige_milieu.position = _base_neige[_neige_milieu] + dec * 0.6
	_neige_pres.position = _base_neige[_neige_pres] + dec * 1.15
	# vent : somme de deux sinus (rafales), déphasée par couche
	var phases := [0.0, 0.9, 1.7]
	var couches := [_neige_loin, _neige_milieu, _neige_pres]
	for i in 3:
		var v := (sin(_t * TAU / 13.0 + phases[i]) * 0.6 + sin(_t * TAU / 31.0 + phases[i] * 0.5) * 0.4) * force_vent
		var pm := (couches[i] as GPUParticles2D).process_material as ParticleProcessMaterial
		pm.gravity = Vector3(v, pm.gravity.y, 0.0)
	# halo du cristal : respiration lente + impulsion
	var repos := 0.30 + 0.06 * sin(_t * 1.3)
	_halo.modulate.a = clampf(repos + _pulse * 0.75, 0.0, 1.0)
	_halo.scale = Vector2.ONE * (1.0 + 0.12 * _pulse)

## Pulsation du cristal du logo (ex. au survol ou à la validation d'un bouton). force 0..1.
func pulse_cristal(force := 1.0) -> void:
	if _tw_pulse:
		_tw_pulse.kill()
	_tw_pulse = create_tween()
	_tw_pulse.tween_property(self, "_pulse", clampf(force, 0.0, 1.5), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw_pulse.tween_property(self, "_pulse", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## true : le logo peint (et la lueur du cristal) est affiché par-dessus le fond ; false : ciel nu (l'UI pose son propre logo).
func set_logo_peint(visible_ : bool) -> void:
	_logo_peint = visible_
	_logo.visible = visible_
	_halo.visible = visible_
	(_fond.material as ShaderMaterial).set_shader_parameter("logo_peint", 1.0 if visible_ else 0.0)

func is_logo_peint() -> bool:
	return _logo_peint

## Fondu au noir (par-dessus le décor). Émet fondu_termine à la fin ; renvoie le Tween (on peut faire `await decor.fondu_sortie(0.8).finished`).
func fondu_sortie(duree := 0.8) -> Tween:
	return _fondre(1.0, duree)

## Fondu depuis le noir.
func fondu_entree(duree := 0.8) -> Tween:
	_fondu.color.a = 1.0
	return _fondre(0.0, duree)

func _fondre(cible: float, duree: float) -> Tween:
	if _tw_fondu:
		_tw_fondu.kill()
	_fondu.visible = true
	_tw_fondu = create_tween()
	_tw_fondu.tween_property(_fondu, "color:a", cible, maxf(duree, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_fondu.finished.connect(func() -> void:
		_fondu.visible = _fondu.color.a > 0.001
		fondu_termine.emit())
	return _tw_fondu

## false : image fixe (accessibilité « réduire les animations ») — shader figé, particules arrêtées.
func set_animations(actif: bool) -> void:
	_animations = actif
	(_fond.material as ShaderMaterial).set_shader_parameter("force", 1.0 if actif else 0.0)
	for n in [_neige_loin, _neige_milieu, _neige_pres]:
		(n as GPUParticles2D).speed_scale = 1.0 if actif else 0.0
	for parent in [_fumees, _braises]:
		for p in (parent as Node).get_children():
			(p as GPUParticles2D).speed_scale = 1.0 if actif else 0.0
