class_name ArcJoueur
extends Node3D
## ARC DU JOUEUR (réglages : data/arc/arc_joueur.json ; modèle : ArcModele, arc_chasseur.glb fait main). Équiper l'arc_chasseur
## (Sac > Armes, ou touche B) : le sabre est rangé.
##   - clic gauche MAINTENU = bander : l'arc se lève, la main droite tire la corde jusqu'à la joue (tension 0..1 en ~1 s), les
##     branches plient, zoom léger, marche ralentie ; tenu trop longtemps à pleine tension, les bras TREMBLENT (et le tir aussi) ;
##   - relâché = tir : la corde claque, petit recul, la flèche part EXACTEMENT vers le centre de l'écran (aucune compensation de
##     la chute : à pleine tension le tir est tendu, un tir court retombe vite) avec une vitesse proportionnelle à la tension ;
##     vol balistique (gravité, légère traînée, le nez suit la trajectoire, raycast entre deux images : pas de traversée de mur),
##     dégâts selon la vitesse à l'IMPACT (Projectile.tirer_joueur) ;
##   - rechargement : la main droite va chercher une flèche au carquois (en bas à droite) et l'encoche, s'il en reste.
## Un relâché sous la tension minimale annule le tir sans perdre de flèche. Une flèche fichée dans le décor se ramasse en
## passant dessus (Projectile.recuperable, tirée au sort).
## Première personne : VRAIS BRAS (bras_fps.glb, mêmes matières que les mains de l'épée) sur la caméra, IK à deux os des deux
## bras + orientation des poignets : poing gauche sur la poignée, main droite sur la corde (au point d'encoche).
## Troisième personne : le même arc tenu par le CORPS (IK des deux bras sur le squelette du corps, buste de profil vers la cible).
## Les tests pilotent l'arc sans souris : appuyer() / relacher(), `tenu_force`.

signal tir(info: Dictionary)
signal sans_fleche
signal change(actif: bool)

enum { REPOS, BANDE, RECUP }
const FICHIER := "res://data/arc/arc_joueur.json"
const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const ORIENTATION := preload("res://scripts/orientation_main.gd")

## Première personne (repère de la caméra) : en visée, l'encoche est sous la joue droite (en bas à droite de l'écran) et la flèche
## traverse la vue en diagonale, sa pointe juste sous le centre de l'écran (d'où part le tir) ; au repos l'arc est baissé.
## POSE_REPOS = [appui de la flèche sur l'arc, direction de la flèche, inclinaison (rad, haut vers la droite)].
const ENCOCHE_VISEE := Vector3(0.13, -0.14, -0.26)
const POINTE_VISEE := Vector3(-0.03, -0.045, -1.0)
const POSE_REPOS := [Vector3(-0.2, -0.26, -0.55), Vector3(0.3, -0.12, -1.0), 0.85]
## Allonge du modèle atteinte à pleine tension à la 1re personne (le bras d'arc des bras_fps est court : encoche à la joue).
const ALLONGE_VM := 0.85
## Bras 1re personne : décalage du modèle (sous l'œil, avancé) : les épaules hors champ, le bras d'arc presque tendu.
const DECALAGE_BRAS := Vector3(0.0, -0.1, -0.58)
## Carquois (dos, à droite, hors champ) : la main droite y prend la flèche suivante.
const CARQUOIS := Vector3(0.3, -0.5, 0.05)
const COUDE_G := Vector3(-0.7, -0.8, -0.2)
const COUDE_D := Vector3(0.8, -0.6, 0.1)
## Épaule droite ramenée en arrière (repère de la caméra) : le bras de corde se replie naturellement vers la joue.
const RECUL_EPAULE_D := Vector3(0.05, 0.0, 0.5)

static var _r := {}

var joueur: CharacterBody3D
var actif := false
var etat := REPOS
var tension := 0.0
var tenu_force := false
var dernier_tir := {}
var tirs := 0
## Pas de souris réelle (tests, films) : seul `tenu_force` compte.
var souris_reelle := true
## Tremblement courant (0..1) : tension pleine tenue trop longtemps.
var tremblement := 0.0
var _t_bande := 0.0
var _t_plein := 0.0
var _t_recup := 0.0
var _avis_donne := false
var _fov_base := -1.0
var _cam_zoom: Camera3D
var _vm: ArcModele
var _tp: ArcModele
var _clip_tir := 0.0
var _levee := 0.0
var _recul := 0.0
var _encochee := false
var _t := 0.0
# 1re personne
var _rig: Node3D
var _bras: Node3D
var _sq: Skeleton3D
var _pivot_d: Node3D
var _poing_vm: _Poing
# 3e personne
var _sq_corps: Skeleton3D
var _ik_corps: Array[TwoBoneIK3D] = []
var _or_corps: Array = []
var _poing_corps: _Poing
var _pivot_corps_d: Node3D
var _coudes_corps: Array[Node3D] = []

static func reglages() -> Dictionary:
	if _r.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_r = d if d is Dictionary else {"_defaut": true}
	return _r

static func reglage(cle: String, defaut: float) -> float:
	return float(reglages().get(cle, defaut))

static func est_arc(id: String) -> bool:
	return id == String(reglages().get("id_arc", "arc_chasseur"))

func _id_fleche() -> String:
	return String(reglages().get("id_fleche", "fleche"))

func fleches() -> int:
	var inv: Variant = joueur.get("inventaire")
	return int(inv.nombre(_id_fleche())) if inv != null else 0

func _ready() -> void:
	name = "ArcJoueur"
	_rig = Node3D.new()
	_rig.name = "ArcVueFps"
	_rig.visible = false
	joueur.camera.add_child(_rig)
	_vm = ArcModele.new()
	_rig.add_child(_vm)
	_installer_bras()
	_tp = ArcModele.new()
	_tp.visible = false
	add_child(_tp)
	_pivot_corps_d = Node3D.new()
	_tp.add_child(_pivot_corps_d)
	set_physics_process(true)

# ------------------------------------------------------------------ mains

## Doigts refermés (poings) réappliqués à chaque image avant l'IK (sinon le squelette n'est pas marqué modifié et l'IK ne tourne
## pas) : 1 = poing fermé, 0 = doigts de la pose de repos (main droite ouverte au lâcher de la corde).
class _Poing extends SkeletonModifier3D:
	var doigts := {}
	var ferme_g := 1.0
	var ferme_d := 1.0
	## Main ouverte = doigts du repos du squelette (bras de la 1re personne, sans animation) ; sinon ceux de l'animation (corps).
	var ouvert_repos := false
	## Épaule déplacée (repère du squelette, depuis la pose de repos) : 1re personne, l'épaule droite ramenée à sa vraie place.
	var os_decale := ""
	var decalage := Vector3.ZERO
	func _process_modification_with_delta(_dt: float) -> void:
		var sq := get_skeleton()
		if sq == null:
			return
		if os_decale != "":
			var i := sq.find_bone(os_decale)
			var parent := sq.get_bone_global_rest(sq.get_bone_parent(i))
			var g := sq.get_bone_global_rest(i)
			sq.set_bone_pose_position(i, parent.affine_inverse() * (g.origin + decalage))
		for i: int in doigts:
			var f := ferme_d if sq.get_bone_name(i).ends_with("_r") else ferme_g
			var q: Quaternion = doigts[i]
			if f < 1.0:
				var ouvert := sq.get_bone_rest(i).basis.get_rotation_quaternion() if ouvert_repos else sq.get_bone_pose_rotation(i)
				q = ouvert.slerp(q, f)
			sq.set_bone_pose_rotation(i, q)

## Pose des poings prise dans l'animation de coup de poing (comme mains.gd) : {os: rotation}.
static func poings(racine: Node3D, sq: Skeleton3D) -> Dictionary:
	var ap := AnimationPlayer.new()
	racine.add_child(ap)
	ap.root_node = ap.get_path_to(racine)
	ap.add_animation_library("", Humain.bibliotheque())
	var avant := {}
	for i in sq.get_bone_count():
		avant[i] = sq.get_bone_pose(i)
	ap.play("Punch_Cross")
	ap.seek(0.0, true)
	var d := {}
	for i in sq.get_bone_count():
		var n := sq.get_bone_name(i)
		if n.begins_with("thumb") or n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") or n.begins_with("pinky"):
			d[i] = sq.get_bone_pose_rotation(i)
	ap.stop()
	ap.queue_free()
	for i: int in avant:
		var t: Transform3D = avant[i]
		sq.set_bone_pose_position(i, t.origin)
		sq.set_bone_pose_rotation(i, t.basis.get_rotation_quaternion())
	return d

## Prise d'un objet dans le poing fermé (même calcul que mains._calculer_prise) : axe par le creux des doigts, de l'auriculaire
## vers l'index ; +X vers les jointures. Les doigts doivent être en poing (poings()) au moment du calcul.
static func calculer_prise(sq: Skeleton3D, cote: String) -> Transform3D:
	var main := _pose_os(sq, "hand_" + cote).affine_inverse()
	var creux: Array[Vector3] = []
	for d in ["index", "middle", "ring", "pinky"]:
		var p1 := main * _pose_os(sq, "%s_01_%s" % [d, cote]).origin
		var p2 := main * _pose_os(sq, "%s_02_%s" % [d, cote]).origin
		var p3 := main * _pose_os(sq, "%s_03_%s" % [d, cote]).origin
		creux.append(Vector3((p1.x + p3.x) * 0.5, minf(p1.y, p2.y) - 0.009 - 0.018, p1.z))
	var centre := (creux[0] + creux[1] + creux[2] + creux[3]) * 0.25
	var axe := (creux[0] - creux[3]).normalized()
	var jointures := (Vector3.UP - axe * axe.dot(Vector3.UP)).normalized()
	return Transform3D(Basis(jointures, axe, jointures.cross(axe)), centre)

static func _pose_os(sq: Skeleton3D, nom: String) -> Transform3D:
	var i := sq.find_bone(nom)
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t

## Installe sur un squelette : poings, IK à deux os des deux bras vers les cibles, orientation des poignets. Rend [poing, ik_g, ik_d, or_g, or_d].
static func _installer_ik(racine: Node3D, sq: Skeleton3D, cible_g: Node3D, pivot_d: Node3D, coudes: Array[Node3D]) -> Array:
	var poing := _Poing.new()
	poing.doigts = poings(racine, sq)
	for i: int in poing.doigts:
		sq.set_bone_pose_rotation(i, poing.doigts[i])
	var prise_g := calculer_prise(sq, "l")
	var prise_d := calculer_prise(sq, "r")
	var cg := Node3D.new()
	cible_g.add_child(cg)
	cg.transform = prise_g.affine_inverse()
	var cd := Node3D.new()
	pivot_d.add_child(cd)
	cd.transform = prise_d.affine_inverse()
	sq.add_child(poing)
	var r: Array = [poing]
	for i in 2:
		var c: String = ["l", "r"][i]
		var ik := TwoBoneIK3D.new()
		sq.add_child(ik)
		ik.set_setting_count(1)
		ik.set_root_bone_name(0, "upperarm_" + c)
		ik.set_middle_bone_name(0, "lowerarm_" + c)
		ik.set_end_bone_name(0, "hand_" + c)
		ik.set_target_node(0, ik.get_path_to([cg, cd][i]))
		ik.set_pole_node(0, ik.get_path_to(coudes[i]))
		r.append(ik)
	for i in 2:
		var o := SkeletonModifier3D.new()
		o.set_script(ORIENTATION)
		o.os = ["hand_l", "hand_r"][i]
		o.cible = [cg, cd][i]
		o.prise = [prise_g, prise_d][i]
		o.deviation_max = deg_to_rad(40.0)
		o.flexion_max = deg_to_rad(65.0)
		sq.add_child(o)
		r.append(o)
	return r

func _installer_bras() -> void:
	_bras = BRAS.instantiate()
	_rig.add_child(_bras)
	_sq = _bras.find_child("Skeleton3D", true, false)
	if joueur.mains != null and joueur.mains.has_method("_habiller"):
		joueur.mains._habiller(_bras)
	for mi: MeshInstance3D in _bras.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		mi.layers = AvantBras.CALQUE
	var tete := _sq.get_bone_global_rest(_sq.find_bone("Head")).origin
	var yeux := tete + Vector3(0, 0.07, 0.1)
	var tour := Basis(Vector3.UP, PI)
	_bras.transform = Transform3D(tour, -(tour * yeux) + DECALAGE_BRAS)
	_pivot_d = Node3D.new()
	_rig.add_child(_pivot_d)
	var coudes: Array[Node3D] = []
	for p in [COUDE_G, COUDE_D]:
		var c := Node3D.new()
		_rig.add_child(c)
		c.position = p
		coudes.append(c)
	var r := _installer_ik(_bras, _sq, _vm.repere_poignee, _pivot_d, coudes)
	_poing_vm = r[0]
	_poing_vm.ouvert_repos = true
	# épaule droite reculée à sa vraie place (le modèle est avancé pour que le bras d'arc atteigne la poignée)
	var rel := Transform3D()
	var nd: Node = _sq
	while nd != null and nd != _rig:
		rel = (nd as Node3D).transform * rel
		nd = nd.get_parent()
	_poing_vm.os_decale = "clavicle_r"
	_poing_vm.decalage = rel.basis.inverse() * RECUL_EPAULE_D
	_sq.add_child(TorsionAvantBras.new())   # dernier : torsion des avant-bras répartie, mains inchangées

# ------------------------------------------------------------------ équipement

## Équipe l'arc (il faut l'arc au sac). "" ou la raison du refus.
func equiper() -> String:
	var inv: Variant = joueur.get("inventaire")
	if inv == null or not inv.a(String(reglages().get("id_arc", "arc_chasseur"))):
		return "Pas d'arc dans le sac."
	if actif:
		return ""
	actif = true
	_encochee = fleches() > 0
	_levee = 0.0
	_actualiser_vue()
	change.emit(true)
	return ""

func ranger() -> void:
	if not actif:
		return
	_annuler()
	actif = false
	_actualiser_vue()
	change.emit(false)

func basculer() -> String:
	if actif:
		ranger()
		return ""
	return equiper()

## Reprise de la vue (appelée aussi par joueur.basculer_vue).
func _actualiser_vue() -> void:
	var tp: bool = joueur.troisieme
	if joueur.mains != null:
		joueur.mains.visible = not tp and not actif
	_rig.visible = actif and not tp
	_tp.visible = actif and tp
	var corps: Node3D = joueur.corps
	if corps != null and corps.get("arme_corps") != null:
		corps.arme_corps.visible = not actif
	_arme_corps_visible(not actif)
	if actif and tp:
		_installer_corps()
	var on := actif and tp
	for ik in _ik_corps:
		if is_instance_valid(ik):
			ik.active = on
	for o in _or_corps:
		if is_instance_valid(o):
			o.active = on
	if _poing_corps != null and is_instance_valid(_poing_corps):
		_poing_corps.active = on
	if not actif and _fov_base > 0.0 and _cam_zoom != null:
		_cam_zoom.fov = _fov_base
		_fov_base = -1.0

func vue_changee() -> void:
	_actualiser_vue()

func _unhandled_input(e: InputEvent) -> void:
	if joueur.mort or joueur.en_dialogue or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_B:
		var r := basculer()
		if r != "":
			joueur.avis.emit(r)

# ------------------------------------------------------------------ entrées

func appuyer() -> void:
	tenu_force = true

func relacher() -> void:
	tenu_force = false

func _tenu() -> bool:
	if joueur.mort or joueur.en_dialogue:
		return false
	return tenu_force or (souris_reelle and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

## Facteur de vitesse de marche du joueur (joueur.gd) : ralenti pendant le bandage.
func facteur_vitesse() -> float:
	if etat != BANDE:
		return 1.0
	return lerpf(1.0, reglage("vitesse_marche", 0.55), clampf(tension * 2.0, 0.0, 1.0))

## Clip du corps (corps_joueur.gd) : "" = marche normale.
func clip_tps() -> String:
	if not actif:
		return ""
	if etat == BANDE:
		return "Pistol_Aim_Neutral"
	if _clip_tir > 0.0:
		return "Pistol_Shoot"
	return ""

## Lacet du corps pendant le tir (corps_joueur.gd) : de profil, l'épaule gauche vers la cible.
func lacet_tps() -> float:
	return reglage("lacet_tps", -0.9) * smoothstep(0.0, 1.0, _levee)

# ------------------------------------------------------------------ logique

func _camera_visee() -> Camera3D:
	if joueur.troisieme and joueur.get("camera_tp") != null and joueur.camera_tp.camera != null:
		return joueur.camera_tp.camera
	return joueur.camera

func _physics_process(dt: float) -> void:
	if not actif:
		return
	if not joueur.inventaire.a(String(reglages().get("id_arc", "arc_chasseur"))):
		ranger()   # arc vendu ou lâché
		return
	_t += dt
	_clip_tir = maxf(0.0, _clip_tir - dt)
	_recul = maxf(0.0, _recul - dt)
	var tenu := _tenu()
	match etat:
		REPOS:
			if not _encochee and fleches() > 0:
				_encochee = true   # flèches ramassées : la main en encoche une
			if tenu:
				if fleches() <= 0:
					_encochee = false
					if not _avis_donne:
						_avis_donne = true
						joueur.avis.emit("Plus de flèches.")
						Sons.jouer(self, ["cloth1"], -14.0)
						sans_fleche.emit()
				else:
					etat = BANDE
					_t_bande = 0.0
					_t_plein = 0.0
					tension = 0.0
					_cam_zoom = _camera_visee()
					_fov_base = _cam_zoom.fov
					Sons.jouer(self, ["creak1"], -16.0, 0.1, &"", 1.4)
			else:
				_avis_donne = false
		BANDE:
			_t_bande += dt
			# la tension monte vite puis plus lentement (la corde résiste en fin d'allonge)
			var u := clampf(_t_bande / maxf(reglage("temps_plein", 0.95), 0.05), 0.0, 1.0)
			tension = 1.0 - pow(1.0 - u, 1.6)
			if u >= 1.0:
				tension = 1.0
				_t_plein += dt
			tremblement = clampf((_t_plein - reglage("tremble_apres", 2.5)) / 2.5, 0.0, 1.0)
			if not tenu:
				if tension < reglage("tension_min", 0.12) or fleches() <= 0:
					_annuler()
				else:
					_tirer()
		RECUP:
			_t_recup += dt
			tension = maxf(0.0, tension - dt * 9.0)
			if _t_recup >= reglage("recuperation", 0.62):
				etat = REPOS
				tension = 0.0
				_encochee = fleches() > 0
				_avis_donne = tenu   # un clic tenu à la fin d'un tir ne ré-affiche pas l'avis en boucle
	if etat != BANDE:
		tremblement = maxf(0.0, tremblement - dt * 3.0)
	var but_levee := 1.0 if etat == BANDE or (etat == RECUP and _t_recup < 0.2) else 0.0
	_levee = move_toward(_levee, but_levee, dt * (4.5 if but_levee > _levee else 1.8))
	_zoom(dt)
	_modeles()

func _annuler() -> void:
	etat = REPOS
	tension = 0.0
	_t_bande = 0.0
	_t_plein = 0.0
	if _fov_base > 0.0 and _cam_zoom != null:
		_cam_zoom.fov = _fov_base

func _zoom(dt: float) -> void:
	if _fov_base <= 0.0 or _cam_zoom == null:
		return
	var cible := _fov_base - reglage("fov_zoom", 10.0) * (tension if etat == BANDE else 0.0)
	_cam_zoom.fov = lerpf(_cam_zoom.fov, cible, 1.0 - exp(-14.0 * dt))
	if etat == REPOS and absf(_cam_zoom.fov - _fov_base) < 0.05:
		_cam_zoom.fov = _fov_base
		_fov_base = -1.0

func _modele() -> ArcModele:
	return _tp if joueur.troisieme else _vm

## Phase du rechargement (0..1 sur la durée de récupération), -1 hors rechargement.
func _phase_recup() -> float:
	return clampf(_t_recup / maxf(reglage("recuperation", 0.62), 0.05), 0.0, 1.0) if etat == RECUP else -1.0

func _modeles() -> void:
	if joueur.troisieme:
		_placer_tp()
	else:
		_placer_vm()
	var corps: Node3D = joueur.corps
	if corps != null and corps.get("arme_corps") != null:
		corps.arme_corps.visible = false
	_arme_corps_visible(false)

## Arme de la main droite recopiée sur le corps (CorpsMainsTps) : rangée tant que l'arc est en main.
func _arme_corps_visible(v: bool) -> void:
	var corps: Node3D = joueur.corps
	var mt: Variant = corps.get("mains_tps") if corps != null else null
	if mt != null:
		var a: Variant = mt.get("_arme_d")
		if a is Node3D and is_instance_valid(a):
			(a as Node3D).visible = v

## Bruit doux du tremblement (somme de sinus).
func _bruit(k: float) -> float:
	return sin(_t * 17.0 + k) * 0.6 + sin(_t * 29.0 + k * 2.3) * 0.4

## Repère de l'arc tel que la flèche (de l'encoche à z_encoche vers l'appui) suive `dir`, l'appui en `appui`, le haut de l'arc
## incliné de `incl` (rad, vers la droite) autour de la flèche.
static func pose_arc(appui: Vector3, dir: Vector3, incl: float, z_encoche: float) -> Transform3D:
	var d_loc := (ArcModele.APPUI - Vector3(0.0, ArcModele.APPUI.y, z_encoche)).normalized()
	var haut := Vector3.UP.rotated(dir.normalized(), -incl)
	var b := Basis.looking_at(dir.normalized(), haut) * Basis.looking_at(d_loc, Vector3.UP).inverse()
	return Transform3D(b, appui - b * ArcModele.APPUI)

func _placer_vm() -> void:
	var u := tension * ALLONGE_VM if etat == BANDE else 0.0
	var ph := _phase_recup()
	# pose de visée : la flèche file de l'encoche (joue) vers le centre de l'écran, au loin
	var z_vis := _vm.encoche_pour(ALLONGE_VM).z
	var d_vis := (POINTE_VISEE - ENCOCHE_VISEE).normalized()
	var appui_vis := ENCOCHE_VISEE + d_vis * Vector2(ArcModele.APPUI.x, z_vis).length()
	var l := smoothstep(0.0, 1.0, _levee)
	var appui: Vector3 = (POSE_REPOS[0] as Vector3).lerp(appui_vis, l)
	var dir: Vector3 = (POSE_REPOS[1] as Vector3).normalized().slerp(d_vis, l)
	var incl: float = lerpf(POSE_REPOS[2], reglage("inclinaison_visee", 0.3), l)
	if tremblement > 0.0:
		appui += Vector3(_bruit(0.0), _bruit(1.7), 0.0) * 0.006 * tremblement
		dir = dir.rotated(Vector3.UP, _bruit(3.1) * 0.012 * tremblement)
	if _recul > 0.0:
		var k := _recul / 0.22
		appui += Vector3(0.0, 0.01, 0.035) * k * k
		incl += 0.06 * k
	_vm.transform = pose_arc(appui, dir, incl, _vm.encoche_pour(u).z)
	_poing_vm.ferme_d = 1.0
	_vm.fleche_libre = null
	if ph >= 0.0:
		# rechargement : lâcher (main ouverte qui file en arrière), carquois (hors champ), retour avec une flèche
		_vm.regler(0.0, false)
		var nock_cam := _vm.transform * _vm.encoche_locale()
		var lacher := ENCOCHE_VISEE + Vector3(0.07, 0.03, 0.1)
		var repere: Basis = _vm.transform.basis * _vm.repere_encoche.basis
		var main: Vector3
		if ph < 0.22:
			main = ENCOCHE_VISEE.lerp(lacher, smoothstep(0.0, 1.0, ph / 0.22))
			_poing_vm.ferme_d = 0.0
		elif ph < 0.5:
			main = lacher.lerp(CARQUOIS, smoothstep(0.0, 1.0, (ph - 0.22) / 0.28))
			_poing_vm.ferme_d = (ph - 0.22) / 0.28
		else:
			var k := smoothstep(0.0, 1.0, (ph - 0.5) / 0.5)
			main = CARQUOIS.lerp(nock_cam, k)
			if fleches() > 0:
				var vers_appui := (_vm.transform * ArcModele.APPUI - main).normalized()
				var d := Vector3(0.15, 0.35, -1.0).normalized().slerp(vers_appui, k)
				_vm.fleche_libre = _vm.transform.affine_inverse() * Transform3D(Basis.looking_at(d, Vector3.UP), main)
		_pivot_d.transform = Transform3D(repere, main)
		_vm._appliquer()
	else:
		_vm.regler(u, _encochee)
		_pivot_d.transform = _vm.transform * _vm.repere_encoche.transform

# ------------------------------------------------------------------ 3e personne

func _installer_corps() -> void:
	if not _ik_corps.is_empty() and is_instance_valid(_sq_corps) and is_instance_valid(_ik_corps[0]):
		return
	_ik_corps.clear()
	_or_corps.clear()
	var corps: Node3D = joueur.corps
	if corps == null or corps.get("modele") == null or corps.modele == null:
		return
	_sq_corps = corps.modele.find_child("Skeleton3D", true, false)
	if _sq_corps == null or _sq_corps.find_bone("hand_l") < 0 or _sq_corps.find_bone("index_01_l") < 0:
		_sq_corps = null
		return
	_coudes_corps.clear()
	for i in 2:
		var c := Node3D.new()
		add_child(c)
		_coudes_corps.append(c)
	var r := _installer_ik(corps.modele, _sq_corps, _tp.repere_poignee, _pivot_corps_d, _coudes_corps)
	_poing_corps = r[0]
	_ik_corps.assign([r[1], r[2]])
	_or_corps = [r[3], r[4]]

func _os_monde(nom: String) -> Vector3:
	var i := _sq_corps.find_bone(nom)
	return _sq_corps.global_transform * _sq_corps.get_bone_global_pose(i).origin

## Troisième personne : l'arc tenu par le corps. En visée : bras gauche tendu vers la cible depuis l'épaule, encoche à la joue droite ;
## au repos : arc tenu bas de la main gauche, pointe vers l'avant, la main droite libre (animation).
func _placer_tp() -> void:
	var u := tension if etat == BANDE else 0.0
	var b_j: Basis = joueur.global_transform.basis
	var cam := _camera_visee()
	var visee: Vector3 = -cam.global_transform.basis.z.normalized() if cam != null else -b_j.z
	var ok := _sq_corps != null and is_instance_valid(_sq_corps)
	var epaule := joueur.global_position + b_j * Vector3(-0.2, 1.45, 0.0)
	var tete := joueur.global_position + b_j * Vector3(0.0, 1.6, 0.0)
	if ok:
		epaule = _os_monde("upperarm_l")
		tete = _os_monde("Head")
	var l := smoothstep(0.0, 1.0, _levee)
	# visée : poing gauche à ~95 % de l'allonge du bras, sur la ligne épaule -> cible ; encoche sous la pommette droite
	var appui_v := epaule + visee * 0.47
	var joue := tete + b_j * Vector3(0.05, -0.06, -0.06)
	var appui_r := joueur.global_position + b_j * Vector3(-0.32, 0.92, -0.2)
	var dir_r := (b_j * Vector3(0.15, -0.55, -1.0)).normalized()
	var dir_v := (appui_v - joue).normalized()
	var appui := appui_r.lerp(appui_v, l)
	var dir := dir_r.slerp(dir_v, l)
	var z0 := float(ArcModele.infos().get("encoche_repos_z", 0.195))
	var z1 := float(ArcModele.infos().get("encoche_pleine_z", 0.595))
	var a_max := clampf((joue.distance_to(appui_v) - z0) / (z1 - z0), 0.3, 1.0)
	var uu := u * a_max
	_tp.global_transform = pose_arc(appui, dir, lerpf(0.5, 0.15, l), _tp.encoche_pour(uu).z)
	_tp.fleche_libre = null
	_tp.regler(uu, _encochee and etat == BANDE)
	_pivot_corps_d.transform = _tp.repere_encoche.transform
	if ok:
		_coudes_corps[0].global_position = epaule + b_j * Vector3(-0.5, -0.5, 0.2)
		_coudes_corps[1].global_position = _os_monde("upperarm_r") + b_j * Vector3(0.5, 0.15, 0.5)
		var main_d := etat == BANDE
		_ik_corps[1].active = main_d
		_or_corps[1].active = main_d
		_poing_corps.ferme_d = 1.0 if main_d else 0.0

# ------------------------------------------------------------------ tir

## Point visé par le centre de l'écran (raycast caméra) et départ de la flèche (pointe, ramenée devant un mur trop proche).
func _visee() -> Dictionary:
	var cam := _camera_visee()
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 200.0)
	q.exclude = [joueur.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var cible: Vector3 = r["position"] if not r.is_empty() else o + d * 200.0
	var depart := _modele().pointe()
	var oeil: Vector3 = joueur.camera.global_position
	if depart.distance_to(oeil) > 2.5:
		depart = oeil + d * 0.7
	# pas de départ derrière un mur (joueur collé au mur) : la flèche part du point de contact
	var q2 := PhysicsRayQueryParameters3D.create(oeil, depart)
	q2.exclude = [joueur.get_rid()]
	var r2 := get_world_3d().direct_space_state.intersect_ray(q2)
	if not r2.is_empty():
		depart = (r2["position"] as Vector3) - (depart - oeil).normalized() * 0.05
	return {"cible": cible, "depart": depart, "axe": d}

func _tirer() -> void:
	var inv: Variant = joueur.inventaire
	inv.retirer(_id_fleche(), 1)
	var t := tension
	var vit := lerpf(reglage("vitesse_min", 9.0), reglage("vitesse_max", 46.0), t)
	var v := _visee()
	var depart: Vector3 = v["depart"]
	var cible: Vector3 = v["cible"]
	# le tir part EXACTEMENT vers le point visé par le centre de l'écran (aucune compensation de la chute)
	var dir: Vector3 = (cible - depart).normalized() if depart.distance_to(cible) > 1.5 else v["axe"]
	if tremblement > 0.0:
		var ecart := deg_to_rad(reglage("tremble_ecart", 1.6)) * tremblement
		var cote := dir.cross(Vector3.UP).normalized()
		dir = dir.rotated(Vector3.UP, randf_range(-ecart, ecart)).rotated(cote, randf_range(-ecart, ecart))
	var recup := randf() < reglage("fleche_recuperable", 0.6)
	var p := Projectile.tirer_joueur(joueur.get_parent(), depart, dir, joueur, reglage("degats_max", 36.0), vit, recup)
	p.vitesse_reference = reglage("vitesse_max", 46.0)
	p.degats_min = reglage("degats_min", 3.0)
	var degats := p.degats_pour(vit)
	dernier_tir = {"tension": t, "degats": degats, "vitesse": vit, "projectile": p, "depart": depart, "direction": dir, "cible": cible}
	tirs += 1
	Sons.jouer(self, ["knifeSlice2"], -6.0, 0.1, &"", 0.7 + 0.5 * t)
	_modele().claquer()
	etat = RECUP
	_t_recup = 0.0
	_recul = 0.22
	_encochee = false
	_clip_tir = reglage("recuperation", 0.62)
	_t_bande = 0.0
	_t_plein = 0.0
	tir.emit(dernier_tir)
