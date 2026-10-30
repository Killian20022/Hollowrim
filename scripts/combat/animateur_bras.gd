class_name AnimateurBras
extends RefCounted
## Bras DROIT du viewmodel (épée) joué par de VRAIES ANIMATIONS à images clés : clés d'os posées à la main dans Blender
## (sources_blender/scripts/anim_bras_epee.py + gestes_bras_epee.py → assets/animations/bras_epee.tres), jouées par un
## AnimationPlayer (pas manuel : mains.gd fixe le temps du clip à chaque image, fondus courts entre clips).
## Seuls clavicle_r, upperarm_r, lowerarm_r et hand_r sont animés : la main gauche (torche, plus tard sorts) reste
## indépendante (IK sur pivot_torche, ou ses propres clips sur d'autres os).
## pose_arme(clip, t) recalcule la pose de l'épée À PARTIR DES MÊMES PISTES (cinématique directe) : le tracé de lame
## (pas fixe 1/240 s) échantillonne exactement ce que l'image montre, quelle que soit la cadence.
## Marqueurs de chaque clip (métadonnée « marqueurs », s à vitesse 1) : arme, frappe, fin_frappe, suivi, fin.

const BIBLIOTHEQUE := preload("res://assets/animations/bras_epee.tres")
## Finishers (achèvements) : bibliothèque À PART (sources_blender/scripts/gestes_finishers.py → bras_finishers.tres), jouée par
## le même AnimationPlayer sous le préfixe « fin/ » ; mêmes os, même repère, mêmes marqueurs (+ contact, plante, retrait, mort).
const FINISHERS := preload("res://assets/animations/bras_finishers.tres")
## Arme à deux mains (claymore) : bibliothèque À PART (sources_blender/scripts/gestes_2mains.py → bras_2mains.tres), préfixe
## « deux/ » ; mêmes os, même repère, mêmes marqueurs. La main gauche est posée par IK sur la poignée (mains._poser_deux_mains).
const DEUX_MAINS := preload("res://assets/animations/bras_2mains.tres")
## Haches, masses, marteaux (branche combat/gestes_lourds) : bibliothèque À PART (sources_blender/scripts/gestes_lourds.py →
## bras_lourds.tres), préfixe « lourd/ » ; mêmes os, même repère, mêmes marqueurs (GestesLourds).
const LOURDS := preload("res://assets/animations/bras_lourds.tres")
const OS_ANIMES := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const PREFIXE := "epee/"
const PREFIXE_FIN := "fin/"
const PREFIXE_DEUX := "deux/"
const PREFIXE_LOURD := "lourd/"
## Clips remplacés selon l'arme (profil « tenues » de ProfilsAnimation : « repos » → « repos_2m »…). Le nom LOGIQUE reste celui
## demandé (clip, comparaisons de mains.gd inchangées) ; seul le clip joué / mesuré change.
var variante := {}

var ap: AnimationPlayer
var sq: Skeleton3D
## Repère du nœud des bras dans celui des mains (mains.gd : _bras_base) et prise de l'épée dans l'os hand_r.
var base := Transform3D()
var prise := Transform3D()
## Clip en cours et son temps (s de clip).
var clip := ""
var t := 0.0
var _chaine: Array[int] = []        # os de la racine à hand_r
var _pistes := {}                   # clip -> {os: [piste rotation, piste position]}

func installer(bras: Node3D, squelette: Skeleton3D) -> void:
	sq = squelette
	ap = AnimationPlayer.new()
	ap.name = "AnimationsEpee"
	bras.add_child(ap)
	ap.root_node = NodePath("..")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.add_animation_library("epee", BIBLIOTHEQUE)
	ap.add_animation_library("fin", FINISHERS)
	ap.add_animation_library("deux", DEUX_MAINS)
	ap.add_animation_library("lourd", LOURDS)
	var i := sq.find_bone("hand_r")
	while i >= 0:
		_chaine.push_front(i)
		i = sq.get_bone_parent(i)
	var noms: Array[StringName] = []
	noms.append_array(BIBLIOTHEQUE.get_animation_list())
	noms.append_array(FINISHERS.get_animation_list())
	noms.append_array(DEUX_MAINS.get_animation_list())
	noms.append_array(LOURDS.get_animation_list())
	for nom in noms:
		var a := _anim(nom)
		var p := {}
		for k in a.get_track_count():
			var chemin := String(a.track_get_path(k))
			var os_nom := chemin.get_slice(":", 1)
			var o := sq.find_bone(os_nom)
			if o < 0:
				continue
			if not p.has(o):
				p[o] = [-1, -1]
			if a.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				p[o][0] = k
			elif a.track_get_type(k) == Animation.TYPE_POSITION_3D:
				p[o][1] = k
		_pistes[nom] = p

## Clip réellement joué pour le nom logique `nom` (variante de l'arme).
func reel(nom: String) -> String:
	return String(variante.get(nom, nom))

## Clip `nom` : bibliothèque des coups, puis celle des deux mains, sinon celle des finishers (variante de l'arme appliquée).
func _anim(nom: StringName) -> Animation:
	var r := StringName(reel(nom))
	if BIBLIOTHEQUE.has_animation(r):
		return BIBLIOTHEQUE.get_animation(r)
	if DEUX_MAINS.has_animation(r):
		return DEUX_MAINS.get_animation(r)
	if LOURDS.has_animation(r):
		return LOURDS.get_animation(r)
	return FINISHERS.get_animation(r)

func existe(nom: String) -> bool:
	var r := reel(nom)
	return BIBLIOTHEQUE.has_animation(r) or DEUX_MAINS.has_animation(r) or LOURDS.has_animation(r) or FINISHERS.has_animation(r)

func _prefixe(r: String) -> String:
	if BIBLIOTHEQUE.has_animation(r):
		return PREFIXE
	if LOURDS.has_animation(r):
		return PREFIXE_LOURD
	return PREFIXE_DEUX if DEUX_MAINS.has_animation(r) else PREFIXE_FIN

func longueur(nom: String) -> float:
	return _anim(nom).length

## Marqueurs du clip (s à vitesse 1) ; « fin » = longueur par défaut.
func marqueurs(nom: String) -> Dictionary:
	var a := _anim(nom)
	var m: Dictionary = a.get_meta("marqueurs", {}).duplicate()
	if not m.has("fin"):
		m["fin"] = a.length
	return m

## Lance un clip (fondu `fondu` s de clip depuis la pose affichée) au temps `depart`.
func jouer(nom: String, fondu := 0.08, depart := 0.0) -> void:
	clip = nom
	t = 0.0
	var r := reel(nom)
	ap.play(_prefixe(r) + r, fondu)
	if depart > 0.0:
		regler(depart)
	else:
		ap.advance(0.0)

## Amène le clip en cours au temps `cible` (le fondu avance d'autant) ; borné à la fin du clip (tenue de la dernière pose).
func regler(cible: float) -> void:
	if clip == "":
		return
	cible = clampf(cible, 0.0, longueur(clip) - 1e-4)
	var d := cible - t
	if d < 0.0:
		ap.seek(cible, true)
	else:
		ap.advance(d)
	t = cible

## Avance le clip en cours de `dt` s (poses tenues, charges, chocs de garde).
func avancer(dt: float) -> void:
	regler(t + dt)

func fini() -> bool:
	return clip == "" or t >= longueur(clip) - 2e-4

## Pose de l'épée (repère des mains, sans les mouvements passifs) dans le clip `nom` au temps `tc`, recalculée par
## cinématique directe sur les pistes du clip (rotation des os animés, repos des autres).
func pose_arme(nom: String, tc: float) -> Transform3D:
	var a := _anim(nom)
	var p: Dictionary = _pistes[StringName(reel(nom))]
	tc = clampf(tc, 0.0, a.length)
	var g := Transform3D()
	for o in _chaine:
		var loc := sq.get_bone_rest(o)
		if p.has(o):
			var pr: Array = p[o]
			var pos := a.position_track_interpolate(pr[1], tc) if pr[1] >= 0 else loc.origin
			var rot := a.rotation_track_interpolate(pr[0], tc) if pr[0] >= 0 else loc.basis.get_rotation_quaternion()
			loc = Transform3D(Basis(rot), pos)
		g = g * loc
	return base * g * prise

## Pose de l'épée affichée maintenant (poses locales du squelette après l'animation, fondus compris).
func pose_affichee() -> Transform3D:
	var g := Transform3D()
	for o in _chaine:
		g = g * sq.get_bone_pose(o)
	return base * g * prise
