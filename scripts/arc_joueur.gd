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

## Première personne (repère de la caméra), visée « à la Skyrim » : l'arc MONTE dans le champ, presque vertical, le poing gauche
## sous le réticule. La flèche est presque dans l'axe de la vue : de l'encoche, sous l'œil (ENCOCHE_VISEE, main de corde hors
## champ), elle passe par le repose-flèche (contre le flanc droit de la poignée, juste au-dessus du poing, tout près du réticule)
## et sa pointe se projette exactement au centre de l'écran. L'allonge est celle du modèle (pleine flexion des branches), rien
## n'est étiré. Au repos l'arc est baissé en bas à gauche, couché vers la droite ; la levée (~0,33 s) le monte et le redresse en
## même temps (interpolation des rotations).
## POSE_REPOS = [appui de la flèche sur l'arc, direction de la flèche, inclinaison (rad, positif = haut vers la gauche)].
const ENCOCHE_VISEE := Vector3(0.07, -0.09, -0.01)
const POSE_REPOS := [Vector3(-0.17, -0.34, -0.6), Vector3(0.35, -0.15, -1.0), -1.25]
## Repose-flèche en visée (repère local de l'arc) : le fût touche le flanc DROIT de la poignée (demi-largeur 3,1 cm + rayon du
## fût), à la hauteur de l'appui du modèle (au repos : ArcModele.APPUI).
const APPUI_VISEE_LOC := Vector3(-0.035, 0.045, 0.0)
## Poing gauche descendu le long de la poignée en visée (local) : son index juste sous le fût.
const DESCENTE_POING := 0.07
## Épaule gauche avancée en visée (repère de la caméra).
const AVANCE_EPAULE_G := Vector3(0.0, 0.0, 0.0)
## Vitesse de la levée (1/s) : 1 / 3 ≈ 0,33 s du repos à la visée.
const VITESSE_LEVEE := 3.0
## Bandage : l'arc (flèche dans l'axe) est encore un peu plus bas au début du bandage et finit de monter à pleine allonge ; la
## main de corde passe ainsi sous le champ. Nul dès le lâcher.
const BAISSE_BANDAGE := Vector3(0.0, -0.09, 0.02)
## Allonge visible (1re personne) : la main ne tire la corde qu'à partir de cette levée (0..1), puis au plus à cette vitesse (1/s).
const DEBUT_ALLONGE := 0.8
const VITESSE_ALLONGE := 2.2
## Arc de la 1re personne un peu réduit (1,15 m au lieu de 1,59 m), même échelle au repos et en visée.
const ECHELLE_ARC_VM := 0.72
## Bras 1re personne (bras_fps.glb) : agrandis (le modèle a un bras de 0,49 m, trop court pour tenir un arc à bout de bras) et
## légèrement avancés sous l'œil, les épaules hors champ.
const ECHELLE_BRAS := 1.3
const DECALAGE_BRAS := Vector3(0.0, -0.1, -0.42)
## Carquois (dos, à droite, hors champ) : la main droite y prend la flèche suivante.
const CARQUOIS := Vector3(0.3, -0.5, 0.05)
const COUDE_G := Vector3(-0.6, -1.2, -0.3)
## Coude gauche en visée : sorti vers l'extérieur (gauche) à hauteur d'épaule, comme le bras d'arc d'un vrai archer. Coude bas (repos),
## l'avant-bras montait à 60-65° et devenait presque parallèle à la poignée : le poignet borné ne pouvait plus serrer l'arc.
const COUDE_G_VISEE := Vector3(-0.8, -0.75, -0.25)
const COUDE_D := Vector3(0.8, -0.6, 0.1)
## Coude droit en visée : haut et en arrière (ligne de l'épaule, comme un vrai archer), le bras de corde reste hors champ.
const COUDE_D_VISEE := Vector3(0.7, 0.05, 0.6)
## Détour du coude droit pendant la levée (au milieu de la levée, repère de la caméra) : il reste BAS (coude sous l'épaule, comme
## un archer qui lève l'arc avant de bander) et le manchon de fourrure du brassard droit ne passe pas sous l'œil.
const DETOUR_COUDE_D := Vector3(0.0, -0.6, 0.2)
## Rechargement : la main de corde fait un détour vers le bas (repère de la caméra) entre le carquois et l'encoche.
const DETOUR_MAIN_RECHARGE := Vector3(0.04, -0.16, -0.02)
## Rechargement : détour du coude droit (bas, en dehors, en arrière) : le bras de corde ne barre pas le bas droit de l'image.
const DETOUR_COUDE_RECHARGE := Vector3(0.35, -0.7, 0.25)
## 3e personne : ancrage de la corde (repère du joueur, depuis l'os Head) au coin droit de la mâchoire, assez à droite et en
## avant pour que la main de corde reste HORS du crâne et du casque ; coude droit bien à droite et en arrière.
const ANCRAGE_TPS := Vector3(0.16, -0.11, 0.05)
const COUDE_D_TPS := Vector3(0.7, 0.05, 0.5)
## Épaule droite ramenée en arrière (repère de la caméra) : le bras de corde se replie naturellement vers la joue.
const RECUL_EPAULE_D := Vector3(0.05, 0.0, 0.3)

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
var _abaisse := 0.0
var _recul := 0.0
var _encochee := false
var _t := 0.0
var _dt := 1.0 / 60.0
var _u_vis := 0.0
# 1re personne
var _rig: Node3D
var _bras: Node3D
var _sq: Skeleton3D
var _pivot_d: Node3D
var _poing_vm: _Poing
## Repère monde de l'os de la main gauche après les modificateurs (mesure = true) : comparé à la cible de la poignée.
var main_g_monde := Transform3D()
var _coude_g_vm: Node3D
## Mesure (tests, films) : positions monde des os des mains de la 1re personne après l'IK (signal skeleton_updated).
var mesure := false
var _coude_d_vm: Node3D
var points_mains := {}
var _rel_epaule_g := Basis()
## Repère de la corde dans la main droite en crochet (repère de l'os hand_r ; tests).
var prise_corde := Transform3D()
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
	## Autres os déplacés {nom: décalage (repère du squelette)}.
	var decalages := {}
	## Main de corde (1re personne) : doigts de la main droite en CROCHET {os: rotation} au lieu du poing (prise méditerranéenne).
	var crochet := {}
	func _process_modification_with_delta(_dt: float) -> void:
		var sq := get_skeleton()
		if sq == null:
			return
		if os_decale != "":
			var i := sq.find_bone(os_decale)
			var parent := sq.get_bone_global_rest(sq.get_bone_parent(i))
			var g := sq.get_bone_global_rest(i)
			sq.set_bone_pose_position(i, parent.affine_inverse() * (g.origin + decalage))
		for nom: String in decalages:
			var i := sq.find_bone(nom)
			var parent := sq.get_bone_global_rest(sq.get_bone_parent(i))
			sq.set_bone_pose_position(i, parent.affine_inverse() * (sq.get_bone_global_rest(i).origin + (decalages[nom] as Vector3)))
		for i: int in doigts:
			var f := ferme_d if sq.get_bone_name(i).ends_with("_r") else ferme_g
			var q: Quaternion = crochet[i] if crochet.has(i) else doigts[i]
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

## Prise « méditerranéenne » de la main de corde : index au-dessus de l'encoche, majeur et annulaire dessous, la corde dans le
## pli de la DERNIÈRE phalange (articulation 03) ; auriculaire replié dans la paume, pouce détendu le long de l'index. Fraction
## de la flexion du poing par phalange [01, 02, 03] (0 = doigt tendu du repos, 1 = poing).
const CROCHET := {"index": [0.22, 0.85, 0.55], "middle": [0.22, 0.85, 0.55], "ring": [0.28, 0.85, 0.55], "pinky": [0.75, 1.0, 1.0], "thumb": [0.35, 0.45, 0.35]}

## Rotations des doigts en crochet (main `cote`) à partir du poing : {os: rotation}.
static func crochet_doigts(sq: Skeleton3D, poing_: Dictionary, cote: String) -> Dictionary:
	var d := {}
	for doigt: String in CROCHET:
		for k in 3:
			var i := sq.find_bone("%s_%02d_%s" % [doigt, k + 1, cote])
			if i < 0 or not poing_.has(i):
				continue
			var repos := sq.get_bone_rest(i).basis.get_rotation_quaternion()
			d[i] = repos.slerp(poing_[i], float(CROCHET[doigt][k]))
	return d

## Repère de la corde dans la main en crochet (convention calculer_prise : +y de l'auriculaire vers l'index, +x vers l'avant de la
## main) : la corde passe par le creux des crochets de l'index et du majeur (centre du cercle articulation 02 / 03 / bout), l'encoche
## entre les deux. Les doigts doivent être en crochet au moment du calcul.
static func calculer_crochet(sq: Skeleton3D, cote: String) -> Transform3D:
	var main := _pose_os(sq, "hand_" + cote).affine_inverse()
	var creux: Array[Vector3] = []
	for d in ["index", "middle"]:
		var a := main * _pose_os(sq, "%s_02_%s" % [d, cote]).origin
		var b := main * _pose_os(sq, "%s_03_%s" % [d, cote]).origin
		var c := main * _pose_os(sq, "%s_04_leaf_%s" % [d, cote]).origin
		creux.append(_centre_cercle(a, b, c).lerp(b, 0.35))
	var centre := (creux[0] + creux[1]) * 0.5
	var axe := (main * _pose_os(sq, "index_03_" + cote).origin - main * _pose_os(sq, "ring_03_" + cote).origin).normalized()
	var avant := main * _pose_os(sq, "middle_01_" + cote).origin
	var x := (avant - axe * axe.dot(avant)).normalized()
	return Transform3D(Basis(x, axe, x.cross(axe)), centre)

static func _centre_cercle(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var n := ab.cross(ac)
	if n.length_squared() < 1e-12:
		return (a + c) * 0.5
	return a + (n.cross(ab) * ac.length_squared() + ac.cross(n) * ab.length_squared()) / (2.0 * n.length_squared())

static func _pose_os(sq: Skeleton3D, nom: String) -> Transform3D:
	var i := sq.find_bone(nom)
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t

## Installe sur un squelette : poings, IK à deux os des deux bras vers les cibles, orientation des poignets. Rend [poing, ik_g, ik_d, or_g, or_d].
## Manchon de fourrure des brassards des bras d'ARC : les mèches (jusqu'à 10 cm du bras) mangeaient la main de corde près de l'œil et
## passaient en masse sombre devant la caméra au retour du carquois. Ici elles ne dépassent plus le brassard que de RESTE_FOURRURE
## de leur longueur : un liseré de fourrure, à sa place sur l'avant-bras. Rend un nouveau maillage (celui des autres armes est intact).
const RESTE_FOURRURE := 0.35
static func fourrure_reduite(src: ArrayMesh) -> ArrayMesh:
	if src == null:
		return src
	var dst := ArrayMesh.new()
	for k in src.get_surface_count():
		var a := src.surface_get_arrays(k)
		var m := src.surface_get_material(k)
		if m != null and m.resource_name.begins_with("ab_fourrure"):
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var c := Vector2.ZERO
			for p in v:
				c += Vector2(p.y, p.z)
			c /= v.size()
			var r0 := INF
			for p in v:
				r0 = minf(r0, Vector2(p.y, p.z).distance_to(c))
			for i in v.size():
				var q := Vector2(v[i].y, v[i].z) - c
				var r := q.length()
				if r > r0:
					q *= (r0 + (r - r0) * RESTE_FOURRURE) / r
				v[i] = Vector3(v[i].x, c.x + q.x, c.y + q.y)
			a[Mesh.ARRAY_VERTEX] = v
		var drap := 0
		var bo = a[Mesh.ARRAY_BONES]
		if bo != null and (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0 and bo.size() == (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8:
			drap = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		dst.add_surface_from_arrays(src.surface_get_primitive_type(k), a, [], {}, drap)
		dst.surface_set_material(k, m)
		dst.surface_set_name(k, src.surface_get_name(k))
	return dst

static func _installer_ik(racine: Node3D, sq: Skeleton3D, cible_g: Node3D, pivot_d: Node3D, coudes: Array[Node3D], fg := 1.0, fd := 1.0) -> Array:
	var poing := _Poing.new()
	poing.doigts = poings(racine, sq)
	for i: int in poing.doigts:
		sq.set_bone_pose_rotation(i, poing.doigts[i])
	var prise_g := calculer_prise(sq, "l")
	var prise_d := calculer_prise(sq, "r")
	var cg := Node3D.new()
	cible_g.add_child(cg)
	cg.transform = Transform3D(prise_g.basis, prise_g.origin * fg).affine_inverse()   # fg, fd : échelle main / repère de la cible
	var cd := Node3D.new()
	pivot_d.add_child(cd)
	cd.transform = Transform3D(prise_d.basis, prise_d.origin * fd).affine_inverse()
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
	for mi: MeshInstance3D in _bras.find_children("avant_bras_*", "MeshInstance3D", true, false):
		mi.mesh = fourrure_reduite(mi.mesh as ArrayMesh)
	if joueur.mains != null and joueur.mains.has_method("_habiller"):
		joueur.mains._habiller(_bras)
	for mi: MeshInstance3D in _bras.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		mi.layers = AvantBras.CALQUE
	var tete := _sq.get_bone_global_rest(_sq.find_bone("Head")).origin
	var yeux := tete + Vector3(0, 0.07, 0.1)
	var tour := Basis(Vector3.UP, PI)
	_bras.transform = Transform3D(tour.scaled(Vector3.ONE * ECHELLE_BRAS), -(tour * yeux) * ECHELLE_BRAS + DECALAGE_BRAS)
	_pivot_d = Node3D.new()
	_rig.add_child(_pivot_d)
	var coudes: Array[Node3D] = []
	for p in [COUDE_G, COUDE_D]:
		var c := Node3D.new()
		_rig.add_child(c)
		c.position = p
		coudes.append(c)
	var r := _installer_ik(_bras, _sq, _vm.repere_poignee, _pivot_d, coudes, ECHELLE_BRAS / ECHELLE_ARC_VM, ECHELLE_BRAS)
	_coude_d_vm = coudes[1]
	_coude_g_vm = coudes[0]
	_poing_vm = r[0]
	_poing_vm.ouvert_repos = true
	# main de corde en crochet (et non en poing) : doigts, repère de la corde dans la main, cible de l'IK et du poignet
	_poing_vm.crochet = crochet_doigts(_sq, _poing_vm.doigts, "r")
	for i: int in _poing_vm.crochet:
		_sq.set_bone_pose_rotation(i, _poing_vm.crochet[i])
	var prise_c := calculer_crochet(_sq, "r")
	for i: int in _poing_vm.doigts:
		_sq.set_bone_pose_rotation(i, _poing_vm.doigts[i])
	var cd: Node3D = _pivot_d.get_child(0)
	cd.transform = Transform3D(prise_c.basis, prise_c.origin * ECHELLE_BRAS).affine_inverse()
	(r[4] as SkeletonModifier3D).set("prise", prise_c)
	prise_corde = prise_c
	# épaule droite reculée à sa vraie place (le modèle est avancé pour que le bras d'arc atteigne la poignée)
	var rel := Transform3D()
	var nd: Node = _sq
	while nd != null and nd != _rig:
		rel = (nd as Node3D).transform * rel
		nd = nd.get_parent()
	_poing_vm.os_decale = "clavicle_r"
	_poing_vm.decalage = rel.basis.inverse() * RECUL_EPAULE_D
	_rel_epaule_g = rel.basis.inverse()
	_poing_vm.decalages["clavicle_l"] = Vector3.ZERO
	_sq.skeleton_updated.connect(_sur_squelette)
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
		return "Pistol_Aim_Neutral"   # après le lâcher le buste reste de profil (Pistol_Shoot tendait le bras droit comme un pistolet)
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
	var but_levee := 1.0 if etat == BANDE or etat == RECUP else 0.0   # l'arc reste en visée pendant tout le rechargement
	_levee = move_toward(_levee, but_levee, dt * (VITESSE_LEVEE if but_levee > _levee else 1.8))
	_abaisse = move_toward(_abaisse, 1.0 if etat == BANDE else 0.0, dt * 6.0)
	# arc levé en 1re personne : la tête invisible ne projette plus d'ombre (la main de corde, à la joue, y était plongée) ;
	# torse et jambes gardent la leur au sol
	var ob: Variant = joueur.corps.get("_ombre_bras") if joueur.corps != null else null
	if ob != null:
		ob.sans_tete = _levee > 0.3
	_zoom(dt)
	_dt = dt
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
## incliné de `incl` (rad, positif = vers la gauche à l'écran) autour de la flèche.
static func pose_arc(appui: Vector3, dir: Vector3, incl: float, z_encoche: float, ech := 1.0, appui_loc := ArcModele.APPUI) -> Transform3D:
	var d_loc := (appui_loc - Vector3(0.0, appui_loc.y, z_encoche)).normalized()
	var haut := Vector3.UP.rotated(dir.normalized(), -incl)
	var b := (Basis.looking_at(dir.normalized(), haut) * Basis.looking_at(d_loc, Vector3.UP).inverse()).scaled(Vector3.ONE * ech)
	return Transform3D(b, appui - b * appui_loc)

## Allonge de visée (m) : de l'encoche à pleine flexion du modèle jusqu'au repose-flèche.
static func allonge_visee() -> float:
	var z1 := float(ArcModele.infos().get("encoche_pleine_z", 0.574))
	return Vector2(APPUI_VISEE_LOC.x, z1).length() * ECHELLE_ARC_VM

## Pointe de la flèche à pleine allonge, sur l'axe de visée (centre de l'écran), à la longueur de la flèche de l'encoche.
static func pointe_visee() -> Vector3:
	var lp := ArcModele.longueur_pointe() * ECHELLE_ARC_VM
	var e := ENCOCHE_VISEE
	return Vector3(0.0, 0.0, e.z - sqrt(maxf(0.0, lp * lp - e.x * e.x - e.y * e.y)))

## Repose-flèche en visée : sur la ligne encoche -> pointe, à l'allonge de visée.
static func appui_visee() -> Vector3:
	return ENCOCHE_VISEE + (pointe_visee() - ENCOCHE_VISEE).normalized() * allonge_visee()

## Os des mains (après l'IK) : poing gauche refermé sur la poignée, puis mesure de ce que la main cache à l'écran.
func _sur_squelette() -> void:
	_poing_g_naturel()
	if not mesure:
		return
	for c in ["l", "r"]:
		var pts := PackedVector3Array()
		var racine := _sq.find_bone("hand_" + c)
		for i in _sq.get_bone_count():
			var k := i
			while k >= 0 and k != racine:
				k = _sq.get_bone_parent(k)
			if k == racine:
				pts.append(_sq.global_transform * _sq.get_bone_global_pose(i).origin)
		points_mains[c] = pts
	# avant-bras droit (coude, poignet) : manchon de fourrure du brassard (tests de la levée)
	points_mains["avant_bras_r"] = PackedVector3Array([_sq.global_transform * _sq.get_bone_global_pose(_sq.find_bone("lowerarm_r")).origin, _sq.global_transform * _sq.get_bone_global_pose(_sq.find_bone("hand_r")).origin])
	# main gauche (repère monde de l'os, après l'IK et le poignet) : écart à la prise voulue sur la poignée (tests)
	main_g_monde = _sq.global_transform * _sq.get_bone_global_pose(_sq.find_bone("hand_l"))

## Poing gauche SERRÉ sur la poignée : le repère de la prise tourne autour de l'axe de l'arc pour que les jointures suivent
## l'avant-bras (poignet droit, comme un vrai archer). Avec un repère imposé, le poignet borné (orientation_main) ne pouvait pas
## suivre en visée (jusqu'à 72° d'écart) : la main tournait autour du poignet et le poing restait à côté de la poignée, dans
## le vide. Ici l'orientation voulue est atteignable, donc le creux du poing tombe exactement sur la poignée à toutes les phases ;
## l'arc, lui, ne bouge pas (visée, repose-flèche et inclinaison inchangés). Lu sur l'image précédente (l'écart se résorbe en 2-3 images).
func _poing_g_naturel() -> void:
	var coude := _sq.global_transform * _sq.get_bone_global_pose(_sq.find_bone("lowerarm_l")).origin
	var poignet := _sq.global_transform * _sq.get_bone_global_pose(_sq.find_bone("hand_l")).origin
	var f := _vm.global_transform.basis.inverse() * (poignet - coude)
	f.y = 0.0
	if f.length_squared() < 1e-4 * (poignet - coude).length_squared():
		return   # avant-bras presque dans l'axe de l'arc : on garde le repère précédent
	var x0 := _vm.repere_poignee.basis.x.normalized()
	_vm.repere_poignee.basis = ArcModele.repere_main(x0.slerp(f.normalized(), 0.85))   # amorti : pas d'oscillation d'une image à l'autre

## Mesure à l'écran de la 1re personne (mesure = true depuis au moins une image) : demi-côté `demi` du carré autour du réticule
## (fraction de la HAUTEUR de l'écran) ; rend le nombre de points de l'arc (sommets) et des mains (os, gonflés de `rayon` m) dans
## ce carré, et le cadre du poing gauche en fractions de l'écran [gauche, haut, droite, bas] (os gonflés de `rayon`).
func mesure_ecran(demi := 0.04, rayon := 0.02) -> Dictionary:
	var cam: Camera3D = joueur.camera
	var taille := Vector2(cam.get_viewport().get_visible_rect().size)
	var c := taille * 0.5
	var h := demi * taille.y
	var dans := func(p: Vector3, r: float) -> bool:
		if cam.is_position_behind(p):
			return false
		var e := cam.unproject_position(p)
		var rp := 0.0
		if r > 0.0:
			var dist := (cam.global_transform.affine_inverse() * p).z
			rp = r / maxf(-dist, 0.01) / tan(deg_to_rad(cam.fov) * 0.5) * taille.y * 0.5
		return absf(e.x - c.x) < h + rp and absf(e.y - c.y) < h + rp
	var n_arc := 0
	var t := _vm.mi_arc.global_transform
	for v in _vm.mi_arc.mesh.get_faces():
		if dans.call(t * v, 0.0):
			n_arc += 1
	var n_mains := 0
	for k: String in points_mains:
		for p: Vector3 in points_mains[k]:
			if dans.call(p, rayon):
				n_mains += 1
	var cadre := Rect2()
	var premier := true
	for p: Vector3 in points_mains.get("l", PackedVector3Array()):
		if cam.is_position_behind(p):
			continue
		var e := cam.unproject_position(p)
		var dist := -(cam.global_transform.affine_inverse() * p).z
		var rp := rayon / maxf(dist, 0.01) / tan(deg_to_rad(cam.fov) * 0.5) * taille.y * 0.5
		var r := Rect2(e - Vector2(rp, rp), Vector2(rp, rp) * 2.0)
		cadre = r if premier else cadre.merge(r)
		premier = false
	return {"arc": n_arc, "mains": n_mains, "poing": [cadre.position.x / taille.x, cadre.position.y / taille.y, cadre.end.x / taille.x, cadre.end.y / taille.y]}

func _placer_vm() -> void:
	# pose de visée : la flèche va de l'encoche (contre la joue) à l'appui (au ras du poing gauche), sa pointe au centre de l'écran
	var appui_vis := appui_visee()
	var d_vis := (appui_vis - ENCOCHE_VISEE).normalized()
	var a_vm := 1.0   # pleine allonge du modèle, jamais au-delà
	# allonge VISIBLE : la corde ne recule qu'une fois l'arc levé (la main de corde prend la corde devant soi, sous le réticule,
	# puis la ramène à la joue), puis rattrape la tension (rien ne change au tir : vitesse et dégâts suivent `tension`)
	if etat == BANDE:
		var but := tension if _levee >= DEBUT_ALLONGE else 0.0
		_u_vis = move_toward(_u_vis, but, _dt * VITESSE_ALLONGE)
	else:
		_u_vis = 0.0
	var u := _u_vis * a_vm
	var z_u := _vm.encoche_pour(u).z
	var ph := _phase_recup()
	var l := smoothstep(0.0, 1.0, _levee)
	var d_u := d_vis
	# l'arc finit de monter pendant le bandage (la main de corde reste sous le champ) : pleine hauteur à pleine allonge
	var appui := appui_vis + BAISSE_BANDAGE * (1.0 - smoothstep(0.0, 1.0, u)) * _abaisse
	var incl := reglage("inclinaison_visee", 0.0)
	if tremblement > 0.0:
		appui += Vector3(_bruit(0.0), _bruit(1.7), 0.0) * 0.006 * tremblement
		d_u = d_u.rotated(Vector3.UP, _bruit(3.1) * 0.012 * tremblement)
	if _recul > 0.0:
		var k := _recul / 0.22
		appui += Vector3(0.0, 0.01, 0.035) * k * k
		incl += 0.06 * k
	# levée : position de l'appui interpolée, ROTATION interpolée (quaternions) entre la pose de repos et celle de visée
	var t_repos := pose_arc(POSE_REPOS[0], POSE_REPOS[1], POSE_REPOS[2], z_u, ECHELLE_ARC_VM)
	var t_vis := pose_arc(appui, d_u, incl, z_u, ECHELLE_ARC_VM, APPUI_VISEE_LOC)
	# l'arc se redresse en tête de levée (à mi-course il est droit) pendant que le poing monte : pas de passage couché
	var l_rot := smoothstep(0.0, 1.0, clampf(_levee / 0.5, 0.0, 1.0))
	var q := t_repos.basis.get_rotation_quaternion().slerp(t_vis.basis.get_rotation_quaternion(), l_rot)
	var b := Basis(q).scaled(Vector3.ONE * ECHELLE_ARC_VM)
	_vm.appui = ArcModele.APPUI.lerp(APPUI_VISEE_LOC, l)
	var p_appui: Vector3 = (POSE_REPOS[0] as Vector3).lerp(appui, l)
	_vm.transform = Transform3D(b, p_appui - b * _vm.appui)
	_poing_vm.decalages["clavicle_l"] = _rel_epaule_g * (AVANCE_EPAULE_G * l)
	_vm.repere_poignee.position = Vector3(0.0, -DESCENTE_POING * l, 0.0)
	# levée : le coude droit reste bas (détour), le bras de corde ne passe pas devant l'œil
	_coude_d_vm.position = COUDE_D.lerp(COUDE_D_VISEE, l) + DETOUR_COUDE_D * sin(PI * l)
	_coude_g_vm.position = COUDE_G.lerp(COUDE_G_VISEE, l)
	var ech := ECHELLE_ARC_VM
	_poing_vm.ferme_d = 1.0
	_vm.fleche_libre = null
	if ph >= 0.0:
		# rechargement : lâcher (main ouverte qui file en arrière), carquois (hors champ), retour avec une flèche
		_vm.regler(0.0, false)
		var nock_cam := _vm.transform * _vm.encoche_locale()
		# lâcher : la main file en arrière vers l'oreille et sort du champ en ~4 images, les doigts s'ouvrant en route
		var lacher := ENCOCHE_VISEE + Vector3(0.3, -0.12, 0.3)
		var repere: Basis = (_vm.transform.basis * _vm.repere_encoche.basis).orthonormalized()
		var main: Vector3
		var w_bas := sin(PI * clampf((ph - 0.08) / 0.92, 0.0, 1.0))
		if ph < 0.12:
			var k0 := ph / 0.12
			main = ENCOCHE_VISEE.lerp(lacher, 1.0 - (1.0 - k0) * (1.0 - k0)) + DETOUR_MAIN_RECHARGE * w_bas
			_poing_vm.ferme_d = 1.0 - 0.45 * k0
		elif ph < 0.5:
			main = lacher.lerp(CARQUOIS, smoothstep(0.0, 1.0, (ph - 0.12) / 0.38)) + DETOUR_MAIN_RECHARGE * w_bas
			_poing_vm.ferme_d = (ph - 0.12) / 0.38
		else:
			var k := smoothstep(0.0, 1.0, (ph - 0.5) / 0.5)
			main = CARQUOIS.lerp(nock_cam, k) + DETOUR_MAIN_RECHARGE * w_bas
			if fleches() > 0:
				var vers_appui := (_vm.transform * _vm.appui - main).normalized()
				# flèche déjà orientée vers l'avant (axe de tir de l'arc), jamais pendante
				var axe := (_vm.transform * _vm.appui - nock_cam).normalized()
				var d := axe.slerp(vers_appui, k)
				_vm.fleche_libre = _vm.transform.affine_inverse() * Transform3D(Basis.looking_at(d, Vector3.UP).scaled(Vector3.ONE * ech), main)
		# retour du carquois : la main passe BAS (sous le menton) et le coude droit descend, l'avant-bras ne frôle plus l'œil
		# (il passait à 7-13 cm sous la caméra : brassard coupé par le plan proche, masse noire anguleuse en bas à droite)
		_coude_d_vm.position += DETOUR_COUDE_RECHARGE * w_bas
		_pivot_d.transform = Transform3D(repere, main)
		_vm._appliquer()
	else:
		_vm.regler(u, _encochee)
		var t_enc := _vm.transform * _vm.repere_encoche.transform
		_pivot_d.transform = Transform3D(t_enc.basis.orthonormalized(), t_enc.origin)

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
	# visée : la flèche passe par l'ANCRAGE (coin droit de la mâchoire, en avant et à droite du crâne vu de la caméra) et file
	# dans l'axe du tir ; le poing gauche tient l'arc sur cette ligne, à ~95 % de l'allonge du bras depuis l'épaule.
	var joue := tete + b_j * ANCRAGE_TPS
	var appui_v := joue + visee * ((epaule - joue).dot(visee) + 0.47)
	var appui_r := joueur.global_position + b_j * Vector3(-0.32, 0.92, -0.2)
	var dir_r := (b_j * Vector3(0.15, -0.55, -1.0)).normalized()
	var dir_v := visee   # flèche exactement dans l'axe du tir
	var appui := appui_r.lerp(appui_v, l)
	var dir := dir_r.slerp(dir_v, l)
	var z0 := float(ArcModele.infos().get("encoche_repos_z", 0.195))
	var z1 := float(ArcModele.infos().get("encoche_pleine_z", 0.595))
	var a_max := clampf((joue.distance_to(appui_v) - z0) / (z1 - z0), 0.3, 1.0)
	var uu := u * a_max
	_tp.global_transform = pose_arc(appui, dir, lerpf(0.5, 0.0, l), _tp.encoche_pour(uu).z)   # arc vertical en visée
	_tp.fleche_libre = null
	_tp.regler(uu, _encochee and etat == BANDE)
	_pivot_corps_d.transform = _tp.repere_encoche.transform
	if ok:
		_coudes_corps[0].global_position = epaule + b_j * Vector3(-0.5, -0.5, 0.2)
		_coudes_corps[1].global_position = _os_monde("upperarm_r") + b_j * COUDE_D_TPS
		var ph_tp := _phase_recup()
		var lache := ph_tp >= 0.0
		var main_d := etat == BANDE or lache
		_ik_corps[1].active = main_d
		_or_corps[1].active = main_d
		_poing_corps.ferme_d = 1.0 if etat == BANDE else 0.0
		if lache:
			# lâcher : la main ouverte file en arrière, le long de la joue, puis l'animation la reprend
			# puis elle redescend vers la hanche droite (carquois) le temps du rechargement
			var n0 := _tp.encoche_pour(a_max)
			var arriere := n0 + Vector3(0.05, 0.03, 0.22)
			var hanche := _tp.global_transform.affine_inverse() * (joueur.global_position + b_j * Vector3(0.28, 0.95, 0.05))
			var pos := n0.lerp(arriere, smoothstep(0.0, 0.35, ph_tp)) if ph_tp < 0.35 else arriere.lerp(hanche, smoothstep(0.35, 1.0, ph_tp))
			_pivot_corps_d.transform = Transform3D(_tp.repere_encoche.basis, pos)

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
	_abaisse = 0.0
	_encochee = false
	_clip_tir = reglage("recuperation", 0.62)
	_t_bande = 0.0
	_t_plein = 0.0
	tir.emit(dernier_tir)
