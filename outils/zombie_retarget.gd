extends SceneTree
## Clips « Zombie_* » des draugrs : données Mixamo du « Not So Scary Zombie Pack » (sources_blender/mixamo/zombie_mixamo.json, écrites
## par sources_blender/scripts/extraire_mixamo_zombie.py) reportées sur le squelette Quaternius (65 os) des humains et des draugrs.
##   godot --headless --path . --script res://outils/zombie_retarget.gd
## -> assets/modeles/humains/animations_zombie.res (AnimationLibrary, fusionnée par Humain.bibliotheque()).
##
## Report : chaque os cible prend la rotation MONDE de l'os Mixamo correspondant, corrigée de l'écart de pose de repos
##   R_cible(t) = R_mixamo(t) · R_mixamo_repos⁻¹ · A⁻¹ · R_cible_repos
## où A est la rotation minimale qui amène la direction de repos de l'os Mixamo (tête -> enfant) sur celle de l'os cible : la
## direction de chaque os suit exactement celle de la capture (T-pose Mixamo vs repos Quaternius sans importance). Bassin : trajet
## Mixamo × (hauteur du bassin cible / hauteur des hanches Mixamo). Toutes les images sources (30 i/s) sont gardées : arcs continus.
const SOURCE := "res://sources_blender/mixamo/zombie_mixamo.json"
const SORTIE := "res://assets/modeles/humains/animations_zombie.res"
const CORPS := "res://assets/modeles/humains/homme_vetu.glb"
## os Mixamo -> [os cible, enfant Mixamo, enfant cible] (enfant vide : pas de correction de direction)
static func correspondances() -> Dictionary:
	var c := {"Hips": ["pelvis", "Spine", "spine_01"], "Spine": ["spine_01", "Spine1", "spine_02"], "Spine1": ["spine_02", "Spine2", "spine_03"],
		"Spine2": ["spine_03", "Neck", "neck_01"], "Neck": ["neck_01", "Head", "Head"], "Head": ["Head", "", ""]}
	for cote: Array in [["Left", "l"], ["Right", "r"]]:
		var m: String = cote[0]
		var q: String = cote[1]
		c[m + "Shoulder"] = ["clavicle_" + q, m + "Arm", "upperarm_" + q]
		c[m + "Arm"] = ["upperarm_" + q, m + "ForeArm", "lowerarm_" + q]
		c[m + "ForeArm"] = ["lowerarm_" + q, m + "Hand", "hand_" + q]
		c[m + "Hand"] = ["hand_" + q, m + "HandMiddle1", "middle_01_" + q]
		c[m + "UpLeg"] = ["thigh_" + q, m + "Leg", "calf_" + q]
		c[m + "Leg"] = ["calf_" + q, m + "Foot", "foot_" + q]
		c[m + "Foot"] = ["foot_" + q, m + "ToeBase", "ball_" + q]
		c[m + "ToeBase"] = ["ball_" + q, m + "Toe_End", "ball_leaf_" + q]
		for d: Array in [["Thumb", "thumb"], ["Index", "index"], ["Middle", "middle"], ["Ring", "ring"], ["Pinky", "pinky"]]:
			for i in [1, 2, 3]:
				var fin := "_leaf_" if i == 3 else "_"
				c["%sHand%s%d" % [m, d[0], i]] = ["%s_0%d_%s" % [d[1], i, q], "%sHand%s%d" % [m, d[0], i + 1], "%s_0%d%s%s" % [d[1], i + 1, fin, q]]
	return c

## Image du contact corrigée à la main : le coup de tête recule d'abord la tête (armé, images 19-34) puis la projette (image ~40) ;
## la mesure automatique (tête la plus en avant) tombait sur la pose de départ.
const IMPACT_FORCE := {"Zombie_Tete": 0.51}

static func _q(a: Array) -> Quaternion:
	return Quaternion(float(a[1]), float(a[2]), float(a[3]), float(a[0])).normalized()

static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _init() -> void:
	var f := FileAccess.open(SOURCE, FileAccess.READ)
	if f == null:
		print("ECHEC source introuvable ", SOURCE)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var racine: Node3D = (load(CORPS) as PackedScene).instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	# repère du squelette dans le modèle (rotation seule pour les directions ; complet pour la position du bassin)
	var m_sq := Transform3D()
	var n: Node = sq
	while n != racine and n is Node3D:
		m_sq = (n as Node3D).transform * m_sq
		n = n.get_parent()
	print("squelette dans le modèle : ", m_sq)
	var S := m_sq.basis.orthonormalized().get_rotation_quaternion()
	var nb := sq.get_bone_count()
	var rest_g: Array[Transform3D] = []
	for i in nb:
		rest_g.append(m_sq * sq.get_bone_global_rest(i))
	var rot_repos: Array[Quaternion] = []
	for i in nb:
		rot_repos.append(rest_g[i].basis.orthonormalized().get_rotation_quaternion())
	# préfixe des pistes : celui des clips Quaternius existants (« …/Skeleton3D:os »)
	var prefixe := ""
	var bib := Humain.bibliotheque()
	var a0: Animation = bib.get_animation("Idle")
	for t in a0.get_track_count():
		var p := String(a0.track_get_path(t))
		if p.contains(":"):
			prefixe = p.get_slice(":", 0)
			break
	print("préfixe des pistes : ", prefixe)
	var corr := correspondances()
	var lib := AnimationLibrary.new()
	var i_bassin := sq.find_bone("pelvis")
	for nom: String in data:
		var clip: Dictionary = data[nom]
		var repos: Dictionary = clip["repos"]
		var images: Array = clip["images"]
		var fps := float(clip["fps"])
		# A⁻¹ · R_cible_repos et R_mixamo_repos⁻¹ par os cible
		var droite := {}   # i_cible -> Quaternion (A⁻¹ · Rq_repos)
		var gauche := {}   # i_cible -> Quaternion (Rm_repos⁻¹)
		var source := {}   # i_cible -> nom Mixamo
		for mn: String in corr:
			if not repos.has(mn):
				continue
			var c: Array = corr[mn]
			var iq := sq.find_bone(c[0])
			if iq < 0:
				print("ECHEC os cible absent ", c[0])
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
		anim.loop_mode = Animation.LOOP_LINEAR if clip["boucle"] else Animation.LOOP_NONE
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
				anim.rotation_track_insert_key(pistes[i], tps, (glob[p].inverse() * glob[i]).normalized())
			# bassin : position dans le repère du parent (os racine)
			var pos_modele := _v(im["_bassin"]) * k_bassin
			var parent_g := rest_g[i_parent_bassin] if i_parent_bassin >= 0 else m_sq
			anim.position_track_insert_key(t_pos, tps, parent_g.affine_inverse() * pos_modele)
		var impact := float(IMPACT_FORCE.get(nom, clip["impact"]))
		anim.set_meta("impact", impact)
		lib.add_animation(nom, anim)
		print("CLIP %s : %d images, %.2f s, impact %.2f, boucle %s, %d os reportés, k_bassin %.3f" % [nom, nimg, anim.length, impact, clip["boucle"], droite.size(), k_bassin])
	var err := ResourceSaver.save(lib, SORTIE, ResourceSaver.FLAG_COMPRESS)
	print("ECRIT " if err == OK else "ECHEC écriture ", SORTIE, " ", err)
	_controler.call_deferred(racine, sq, lib, m_sq, err)

## Contrôle (arbre en marche) : quelques images appliquées au squelette -> tête, mains, pieds dans le modèle.
func _controler(racine: Node3D, sq: Skeleton3D, lib: AnimationLibrary, m_sq: Transform3D, err: int) -> void:
	var ap := AnimationPlayer.new()
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("z", lib)
	get_root().add_child(racine)
	await process_frame
	for nom: String in ["Zombie_Attente", "Zombie_Reveil", "Zombie_Marche", "Zombie_Poing"]:
		for f: float in [0.0, 0.5, 1.0]:
			ap.play("z/" + nom)
			ap.seek(ap.current_animation_length * f, true)
			await process_frame
			var pos := func(o: String) -> Vector3: return (m_sq * sq.get_bone_global_pose(sq.find_bone(o)).origin).snappedf(0.01)
			print("CONTROLE %s %.1f : tete %s main_d %s main_g %s pied_g %s pied_d %s" % [nom, f, pos.call("Head"), pos.call("hand_r"), pos.call("hand_l"), pos.call("foot_l"), pos.call("foot_r")])
	racine.queue_free()
	quit(0 if err == OK else 1)
