class_name Interieur
extends Node3D
## Un intérieur de maison (lot « kit intérieur ») : contenu masquable, lumières activées de près, porte animée.
## Le nœud est posé à l'origine du pivot du bâtiment (repère local : X = grand axe, Z = largeur, porte côté +Z).
## - `racine` : tout l'intérieur (maillages fusionnés, flammes, halos, lumières) ; masqué au-delà de `DIST_VISIBLE` ;
## - lumières : OmniLight3D courtes, sans ombre, allumées seulement si le joueur est dedans ou à moins de
##   `DIST_LUMIERE` m de l'emprise (socle technique § 2) ; elles vacillent au pas de 1/12 s ;
## - porte : un ou deux vantaux sur charnière (pivot animé), un blocage de collision tant qu'elle est fermée,
##   fermeture automatique quand on s'éloigne.

const DIST_VISIBLE := 26.0
const DIST_LUMIERE := 8.0
const DIST_FERMETURE := 14.0

var nom := ""
var demi := Vector2(3.0, 2.0)          # demi-emprise INTÉRIEURE (x, z)
var racine: Node3D
var lumieres: Array = []               # [OmniLight3D, énergie, phase]
var vantaux: Array = []                # [Node3D charnière, angle d'ouverture (rad)]
var bloc_porte: CollisionShape3D
var porte_locale := Vector3.ZERO       # centre de la porte (repère local)
var ouverte := false
var interactif: Node3D
var sans_porte := false
var sol_y := 0.42                      # dessus du sol intérieur (repère local)
var _t := 0.0
var _acc := 0.0
var _allume := true
var _tween: Tween

func _init() -> void:
	racine = Node3D.new()
	racine.name = "Contenu"
	add_child(racine)

## Lumière du décor : couleur chaude par défaut, rayon court, atténuation forte, pas d'ombre.
func lumiere(pos: Vector3, energie: float, portee: float, couleur := Color(1.0, 0.56, 0.24), att := 1.7, vacille := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = att
	l.shadow_enabled = false
	l.position = pos
	racine.add_child(l)
	lumieres.append([l, energie, randf() * 10.0 if vacille else -1.0])
	return l

## Position (repère local) du joueur/de la caméra.
func _camera() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return to_local(cam.global_position) if cam != null else Vector3(1e4, 0, 1e4)

## Vrai si la position locale est dans l'emprise intérieure (marge `m`).
func dedans(p: Vector3, m := 0.0) -> bool:
	return absf(p.x) < demi.x + m and absf(p.z) < demi.y + m and p.y < 6.5

func distance_emprise(p: Vector3) -> float:
	var d := Vector2(maxf(absf(p.x) - demi.x, 0.0), maxf(absf(p.z) - demi.y, 0.0))
	return d.length()

func _process(dt: float) -> void:
	_t += dt
	_acc += dt
	if _acc >= 0.2:
		_acc = 0.0
		var c := _camera()
		var d := distance_emprise(c)
		racine.visible = d < DIST_VISIBLE
		var allume := d < DIST_LUMIERE or dedans(c, 0.5)
		if allume != _allume:
			_allume = allume
			for l in lumieres:
				(l[0] as OmniLight3D).visible = allume
		if ouverte and d > DIST_FERMETURE:
			basculer(false, false)
	if _allume and racine.visible:
		for l in lumieres:
			var ph: float = l[2]
			if ph < 0.0:
				continue
			var pas := floorf(_t * 12.0 + ph * 3.0)
			var h := fposmod(sin(pas * 12.9898 + ph) * 43758.5453, 1.0)
			var f := 0.88 + sin(_t * 6.3 + ph) * 0.05 + sin(_t * 15.1 + ph * 2.0) * 0.03 + (h - 0.5) * 0.1
			(l[0] as OmniLight3D).light_energy = l[1] * f

## Ouvre ou ferme la porte (animation de 0,5 s, bruit de porte).
func basculer(ouvrir: bool, bruit := true) -> void:
	if ouvrir == ouverte:
		return
	ouverte = ouvrir
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for v in vantaux:
		var n: Node3D = v[0]
		var cible: float = float(v[1]) if ouvrir else 0.0
		_tween.tween_property(n, "rotation:y", cible, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if bloc_porte != null:
		bloc_porte.set_deferred("disabled", ouvrir)
	if interactif != null:
		interactif.verbe = "Fermer la porte" if ouverte else "Ouvrir la porte"
	if bruit and is_inside_tree():
		Sons.jouer_a(self, ["doorOpen_1", "creak1"], to_global(porte_locale), -6.0)

## Pose l'objet « porte » (touche E) ; à appeler quand le joueur et la boîte de dialogue existent.
func activer(joueur: CharacterBody3D, dialogue: Control) -> void:
	if interactif != null or sans_porte:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = "Fermer la porte" if ouverte else "Ouvrir la porte"
	it.rayon = 2.4
	it.action = func() -> Array:
		basculer(not ouverte)
		return []
	it.position = porte_locale + Vector3(0, 0.0, 0)
	add_child(it)
	interactif = it
