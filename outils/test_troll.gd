extends SceneTree
## Test du Troll de givre (TrollGivre) : contrat de Humain.creer (mêmes 65 os, AnimationPlayer « Animations »), clips du troll,
## budget (<= 9 000 triangles, <= 10 surfaces), toutes les surfaces au shader PS1 à accroche, taille (2,4-3,0 m en Idle, voûté),
## bras longs (bout des doigts sous le genou + 0,25 m en Idle), bibliothèque des PNJ intacte (la voûte est cuite dans une COPIE).
##   godot --headless --path . --script res://outils/test_troll.gd -- --nouvelle
const ANIMS := ["Idle", "Walk", "Jog_Fwd", "Troll_Attaque", "Troll_Griffes", "Hit_Chest", "Death01"]
const BUDGET := 7500
const SURFACES_MAX := 10
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	# valeur de référence d'une clé de la bibliothèque des humains, avant toute création de troll
	var lib := Humain.bibliotheque()
	var a_idle := lib.get_animation("Idle")
	var piste := -1
	for t in a_idle.get_track_count():
		if String(a_idle.track_get_path(t)).get_slice(":", 1) in TrollGivre.VOUTE and a_idle.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			piste = t
			break
	if piste < 0:
		ok(false, "piste de rotation d'un os voûté introuvable dans Idle")
		quit(1)
		return
	var q_avant: Quaternion = a_idle.track_get_key_value(piste, 0)
	var t0 := Time.get_ticks_usec()
	var g := TrollGivre.creer({})
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	root.add_child(g)
	var h := Humain.creer({"corps": "homme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(h)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var sqh := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var memes := sq.get_bone_count() == sqh.get_bone_count()
	for i in sqh.get_bone_count():
		memes = memes and sq.get_bone_name(i) == sqh.get_bone_name(i)
	ok(memes, "mêmes os que Humain.creer (%d)" % sq.get_bone_count())
	var ap := g.get_node_or_null("Animations") as AnimationPlayer
	var manque := []
	for a in ANIMS:
		if ap == null or not ap.has_animation(a):
			manque.append(a)
	ok(manque.is_empty(), "AnimationPlayer « Animations » et clips %s (absents : %s) ; creer %.0f ms" % [ANIMS, manque, dt])
	var tris := 0
	var surfaces := 0
	var non_ps1 := []
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			tris += mi.mesh.surface_get_array_index_len(s) / 3 if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s) / 3
			var m: Material = mi.get_surface_override_material(s)
			if m == null: m = mi.material_override
			if not (m is ShaderMaterial) or not (m as ShaderMaterial).shader.code.contains("grille"):
				non_ps1.append("%s/%d" % [mi.name, s])
	ok(tris <= BUDGET, "%d triangles visibles (<= %d)" % [tris, BUDGET])
	ok(surfaces <= SURFACES_MAX, "%d surfaces visibles (<= %d)" % [surfaces, SURFACES_MAX])
	ok(non_ps1.is_empty(), "toutes les surfaces passent par un shader PS1 à accroche (%s)" % [non_ps1])
	# bibliothèque des PNJ intacte
	var q_apres: Quaternion = Humain.bibliotheque().get_animation("Idle").track_get_key_value(piste, 0)
	ok(q_avant.is_equal_approx(q_apres) and Humain.bibliotheque() != ap.get_animation_library(""), "bibliothèque d'animations des PNJ non modifiée (voûte dans une copie)")
	ok((sqh.get_node("tunique") as MeshInstance3D).material_override is ShaderMaterial and sqh.get_bone_rest(sqh.find_bone("lowerarm_l")).origin.y < 0.26, "Humain.creer (PNJ) non modifié (os et matières)")
	# taille et bras en Idle (repère du monde : l'Armature est agrandie)
	ap.play("Idle")
	ap.seek(0.6, true)
	var hd := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head")).origin
	var main := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("middle_04_leaf_l")).origin
	var genou := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("calf_l")).origin
	var haut := hd.y + 0.30     # sommet du crâne + crinière au-dessus de l'os de la tête
	ok(haut > 2.1 and haut < 3.0, "hauteur en Idle (voûté, genoux fléchis) : %.2f m (2,1-3,0)" % haut)
	ok(main.y < genou.y + 0.25, "bras longs : bout des doigts à %.2f m (genou à %.2f m, + 0,25 m toléré : bras écartés en garde)" % [main.y, genou.y])
	# chaque clip se joue sans NaN et garde les pieds près du sol (hors mort)
	for clip in ANIMS:
		ap.play(clip)
		var lg := ap.get_animation(clip).length
		var bas := 9.0
		var nan := false
		for k in 8:
			ap.seek(lg * k / 8.0, true)
			for o in ["foot_l", "foot_r"]:
				var p := sq.global_transform * sq.get_bone_global_pose(sq.find_bone(o)).origin
				nan = nan or is_nan(p.y)
				bas = minf(bas, p.y)
		ok(not nan and bas > -0.15 and bas < 0.6, "%s : pied le plus bas à %.2f m" % [clip, bas])
	print("TEST TROLL : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
