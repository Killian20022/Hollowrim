extends SceneTree
## Coups d'arme du corps à la 3e personne (branche tps/coups) : captures Mixamo + clips Quaternius UAL2
## (sources_blender/mixamo/coups_tps.json, écrit par sources_blender/scripts/extraire_coups_tps.py) reportés sur le squelette
## Quaternius (65 os) du corps du joueur. MÊME report que les draugrs zombies (outils/zombie_retarget.gd, validé) :
##   R_cible(t) = R_source(t) · R_source_repos⁻¹ · A⁻¹ · R_cible_repos   (A : direction de repos source -> cible de chaque os)
##   godot --headless --path . --script res://outils/coups_tps_retarget.gd
## -> assets/animations/corps_coups_tps.res (AnimationLibrary, un clip « <source> » par capture ENTIÈRE, 30 i/s) ; les plages
## jouées, les marqueurs et la synchronisation avec mains.gd sont dans scripts/combat/corps_coups_tps.gd (CorpsCoupsTps.CLIPS).
##
## Surcouche « poignet » (leçon des coups FPS v6 : « le poignet qui se casse ») : la main droite (et la gauche pour les deux
## mains) ne s'écarte pas de plus de POIGNET_MAX de l'axe de l'avant-bras (flexion / inclinaison bornées, la torsion reste
## libre) ; l'arme prolonge l'avant-bras comme dans la capture, sans casse.
const SOURCE := "res://sources_blender/mixamo/coups_tps.json"
const SORTIE := "res://assets/animations/corps_coups_tps.res"
const CORPS := "res://assets/modeles/humains/homme_vetu.glb"
const ZOMBIE := preload("res://outils/zombie_retarget.gd")
const POIGNET_MAX := 38.0   # degrés (flexion + inclinaison combinées, autour de l'axe de l'avant-bras)
## clips dont on garde la liste (vide = tous ceux du fichier)
var seulement: PackedStringArray = []

static func _q(a: Array) -> Quaternion:
	return Quaternion(float(a[1]), float(a[2]), float(a[3]), float(a[0])).normalized()

static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

## Rotation locale `q` (main dans le repère de l'avant-bras) bornée : l'axe de la main (os Y) reste à `max_deg` au plus de son
## axe au repos ; la torsion autour de l'axe est conservée (décomposition balancement / torsion).
static func borner_poignet(q: Quaternion, repos: Quaternion, max_deg: float) -> Array:
	var rel := repos.inverse() * q   # écart au repos, repère de la main au repos
	var axe := Vector3.UP
	var v := rel * axe
	var ang := rad_to_deg(axe.angle_to(v))
	if ang <= max_deg:
		return [q, ang]
	var balance := Quaternion(axe, v)
	var torsion := balance.inverse() * rel
	var borne := Quaternion.IDENTITY.slerp(balance, max_deg / ang)
	return [(repos * borne * torsion).normalized(), ang]

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			seulement = a.substr(12).split(",")
	var f := FileAccess.open(SOURCE, FileAccess.READ)
	if f == null:
		print("ECHEC source introuvable ", SOURCE)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var racine: Node3D = (load(CORPS) as PackedScene).instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var m_sq := Transform3D()
	var n: Node = sq
	while n != racine and n is Node3D:
		m_sq = (n as Node3D).transform * m_sq
		n = n.get_parent()
	var S := m_sq.basis.orthonormalized().get_rotation_quaternion()
	var nb := sq.get_bone_count()
	var rest_g: Array[Transform3D] = []
	for i in nb:
		rest_g.append(m_sq * sq.get_bone_global_rest(i))
	var rot_repos: Array[Quaternion] = []
	for i in nb:
		rot_repos.append(rest_g[i].basis.orthonormalized().get_rotation_quaternion())
	var prefixe := "Skeleton3D"
	var bib := Humain.bibliotheque()
	var a0: Animation = bib.get_animation("Idle")
	for t in a0.get_track_count():
		var p := String(a0.track_get_path(t))
		if p.contains(":"):
			prefixe = p.get_slice(":", 0)
			break
	var corr: Dictionary = ZOMBIE.correspondances()
	var lib := AnimationLibrary.new()
	if ResourceLoader.exists(SORTIE) and not seulement.is_empty():
		lib = (load(SORTIE) as AnimationLibrary).duplicate(true)
	var i_bassin := sq.find_bone("pelvis")
	var i_main := {"r": sq.find_bone("hand_r"), "l": sq.find_bone("hand_l")}
	for nom: String in data:
		if not seulement.is_empty() and not seulement.has(nom):
			continue
		var clip: Dictionary = data[nom]
		var repos: Dictionary = clip["repos"]
		var images: Array = clip["images"]
		var fps := float(clip["fps"])
		var droite := {}
		var gauche := {}
		var source := {}
		for mn: String in corr:
			if not repos.has(mn):
				continue
			var c: Array = corr[mn]
			var iq := sq.find_bone(c[0])
			if iq < 0:
				continue
			var A := Quaternion.IDENTITY
			if String(c[1]) != "" and repos.has(c[1]) and sq.find_bone(c[2]) >= 0:
				var dm := (_v(repos[c[1]]["p"]) - _v(repos[mn]["p"])).normalized()
				var dq := (rest_g[sq.find_bone(c[2])].origin - rest_g[iq].origin).normalized()
				A = Quaternion(dm, dq)
			droite[iq] = A.inverse() * rot_repos[iq]
			gauche[iq] = _q(repos[mn]["q"]).inverse()
			source[iq] = mn
		var k_bassin := rest_g[i_bassin].origin.y / maxf(_v(repos["Hips"]["p"]).y, 0.01)
		var anim := Animation.new()
		var nimg := images.size()
		anim.length = float(nimg - 1) / fps
		anim.loop_mode = Animation.LOOP_NONE
		var pistes := {}
		for i in nb:
			if sq.get_bone_parent(i) < 0:
				continue
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [prefixe, sq.get_bone_name(i)]))
			anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
			pistes[i] = t
		var t_pos := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t_pos, NodePath("%s:pelvis" % prefixe))
		var i_parent_bassin := sq.get_bone_parent(i_bassin)
		var poignet_max := {"r": 0.0, "l": 0.0}
		for k in nimg:
			var im: Dictionary = images[k]
			var tps := float(k) / fps
			var glob: Array[Quaternion] = []
			glob.resize(nb)
			for i in nb:
				var p := sq.get_bone_parent(i)
				if droite.has(i):
					glob[i] = (_q(im[source[i]]) * gauche[i] * droite[i]).normalized()
				elif p >= 0:
					glob[i] = glob[p] * sq.get_bone_rest(i).basis.get_rotation_quaternion()
				else:
					glob[i] = S * sq.get_bone_rest(i).basis.get_rotation_quaternion()
			for i: int in pistes:
				var p := sq.get_bone_parent(i)
				var loc := (glob[p].inverse() * glob[i]).normalized()
				for cote: String in i_main:
					if i == i_main[cote]:
						var r := borner_poignet(loc, sq.get_bone_rest(i).basis.get_rotation_quaternion(), POIGNET_MAX)
						loc = r[0]
						poignet_max[cote] = maxf(poignet_max[cote], r[1])
				anim.rotation_track_insert_key(pistes[i], tps, loc)
			var pos_modele := _v(im["_bassin"]) * k_bassin
			var parent_g := rest_g[i_parent_bassin] if i_parent_bassin >= 0 else m_sq
			anim.position_track_insert_key(t_pos, tps, parent_g.affine_inverse() * pos_modele)
		lib.add_animation(nom, anim)
		print("CLIP %s : %d images, %.2f s, %d os reportés, poignet capture max d %.0f° g %.0f° (borné à %.0f°)" % [nom, nimg, anim.length, droite.size(), poignet_max["r"], poignet_max["l"], POIGNET_MAX])
	var err := ResourceSaver.save(lib, SORTIE, ResourceSaver.FLAG_COMPRESS)
	print("ECRIT " if err == OK else "ECHEC écriture ", SORTIE, " ", err)
	racine.free()
	quit(0 if err == OK else 1)
