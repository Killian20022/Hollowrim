extends SceneTree
## Clips Quaternius (UAL1, CC0) en MIROIR gauche <-> droite, ajoutés à assets/modeles/humains/animations_sorts_tps.res (suffixe « _D »).
##   godot --headless --path . --script res://outils/miroir_clips_tps.gd [-- --clips=Spell_Simple_Enter,...]
## Les Spell_Simple_* de la bibliothèque d'Humain incantent de la main GAUCHE (mesuré : main gauche tendue à 1,41 m, la droite en bas) ;
## corps_mains_tps.gd prend leur miroir « _D » pour la main droite.
## Calcul (rotations seules, repère du squelette ; M = réflexion sur le plan latéral du personnage) :
##   G'_i(t) = M · G_j(t) · M · D_i,  D_i = (M · G_j_repos · M)⁻¹ · G_i_repos   (j = os symétrique de i : _l <-> _r ; os du milieu : j = i)
##   L'_i(t) = G'_parent(t)⁻¹ · G'_i(t)   (D corrige les axes locaux des os gauches, qui ne sont pas forcément le reflet exact des droits)
const SORTIE := "res://assets/modeles/humains/animations_sorts_tps.res"
const CORPS := "res://assets/modeles/humains/homme_vetu.glb"
const FPS := 30.0

func _init() -> void:
	var clips := "Spell_Simple_Enter,Spell_Simple_Idle,Spell_Simple_Shoot,Spell_Simple_Exit"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			clips = a.substr(8)
	var racine: Node3D = (load(CORPS) as PackedScene).instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var m_sq := Transform3D()
	var n: Node = sq
	while n != racine and n is Node3D:
		m_sq = (n as Node3D).transform * m_sq
		n = n.get_parent()
	var S := m_sq.basis.orthonormalized()
	var M := S.inverse() * Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)) * S   # réflexion dans le repère du squelette
	var nb := sq.get_bone_count()
	var rest_g: Array[Basis] = []
	for i in nb:
		rest_g.append(sq.get_bone_global_rest(i).basis.orthonormalized())
	var partenaire: Array[int] = []
	for i in nb:
		var nom := sq.get_bone_name(i)
		var autre := nom
		if nom.ends_with("_l"):
			autre = nom.trim_suffix("_l") + "_r"
		elif nom.ends_with("_r"):
			autre = nom.trim_suffix("_r") + "_l"
		var j := sq.find_bone(autre)
		partenaire.append(j if j >= 0 else i)
	var D: Array[Basis] = []
	for i in nb:
		var j := partenaire[i]
		D.append((M * rest_g[j] * M).inverse() * rest_g[i])
	var bib := Humain.bibliotheque()
	var lib: AnimationLibrary = load(SORTIE)
	lib = lib.duplicate(true)
	for vieux in lib.get_animation_list():
		if String(vieux).begins_with("Spell_"):
			lib.remove_animation(vieux)
	for clip in clips.split(",", false):
		var src: Animation = bib.get_animation(clip)
		var prefixe := ""
		var pistes := {}   # i -> piste source
		var t_pos := -1
		for t in src.get_track_count():
			var p := String(src.track_get_path(t))
			var os_nom := p.get_slice(":", 1)
			prefixe = p.get_slice(":", 0)
			var i := sq.find_bone(os_nom)
			if i < 0:
				continue
			if src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pistes[i] = t
			elif src.track_get_type(t) == Animation.TYPE_POSITION_3D and os_nom == "pelvis":
				t_pos = t
		var anim := Animation.new()
		anim.length = src.length
		anim.loop_mode = src.loop_mode
		var sortie_pistes := {}
		for i in nb:
			if sq.get_bone_parent(i) < 0:
				continue
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [prefixe, sq.get_bone_name(i)]))
			sortie_pistes[i] = t
		var tp := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tp, NodePath("%s:pelvis" % prefixe))
		var nimg := int(round(src.length * FPS)) + 1
		for k in nimg:
			var tps := minf(k / FPS, src.length)
			var g: Array[Basis] = []
			g.resize(nb)
			for i in nb:
				var loc: Basis = Basis(src.rotation_track_interpolate(pistes[i], tps)) if pistes.has(i) else sq.get_bone_rest(i).basis
				var p := sq.get_bone_parent(i)
				g[i] = (g[p] * loc) if p >= 0 else loc
			var g2: Array[Basis] = []
			g2.resize(nb)
			for i in nb:
				g2[i] = (M * g[partenaire[i]] * M * D[i]).orthonormalized()
			for i: int in sortie_pistes:
				var p := sq.get_bone_parent(i)
				anim.rotation_track_insert_key(sortie_pistes[i], tps, (g2[p].inverse() * g2[i]).get_rotation_quaternion().normalized())
			var pos: Vector3 = src.position_track_interpolate(t_pos, tps) if t_pos >= 0 else sq.get_bone_rest(sq.find_bone("pelvis")).origin
			anim.position_track_insert_key(tp, tps, M * pos)
		lib.add_animation(clip + "_D", anim)
		print("MIROIR ", clip, "_D ", nimg, " images")
	var err := ResourceSaver.save(lib, SORTIE, ResourceSaver.FLAG_COMPRESS)
	print("ECRIT " if err == OK else "ECHEC ", SORTIE, " ", err)
	racine.free()
	quit(0 if err == OK else 1)
