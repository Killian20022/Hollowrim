extends SceneTree
## Agent Y (rpg/armures_lourdes) : outil d'ESSAI des armures lourdes portées, en attendant le système d'affichage de l'agent X
## (scripts/rpg/armure_visible.gd). Attache les glb portés (assets/modeles/armures/porte/<id>.glb, peau d'os sur le squelette du
## héros) au corps du joueur, cache ce qu'ils recouvrent, pose les matières (ps1 + shader_matiere d'EpeesLongues).
##
##   Test de traversée (sans fenêtre) :
##     godot --headless --path . --script res://outils/essai_armures_lourdes.gd -- --nouvelle --test [--ids=casque_fer,cuirasse_fer]
##     Sur chaque clip joué par le corps (locomotion, coups tps de corps_coups_tps.res, sort, coup reçu, saut), 8 instants : aucun
##     point visible du corps COUVERT au repos (rayon os -> point passant sous l'armure) ne ressort à travers l'armure de plus de TOL.
##   Planches en jeu (fenêtre hors écran, via godot_slot.sh) :
##     godot --path . --script res://outils/essai_armures_lourdes.gd -- --nouvelle --planche --sortie=<dossier> [--ensembles=fer,acier,...]
##   Film (marche + combo, de dos puis de 3/4) :
##     godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/essai_armures_lourdes.gd -- --nouvelle --film --ensemble=fer
const DOSSIER := "res://assets/modeles/armures/porte/"
const DOSSIER_SOL := "res://assets/modeles/armures/sol/"
const TOL := 0.012
const ENSEMBLES := {
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"uniques_lourds": ["heaume_jarl", "cuirasse_gardiens", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"uniques_legers": ["capuche_thaumaturge", "brigandine_braise", "gantelets_hrafn", "bottes_rodeur"],
}
## emplacement de chaque pièce (data/objets/armures.json)
const EMPL := {"casque_fer": "tete", "cuirasse_fer": "torse", "gantelets_fer": "mains", "bottes_fer": "pieds",
	"casque_acier_nordique": "tete", "cuirasse_acier_nordique": "torse", "gantelets_acier_nordique": "mains", "bottes_acier_nordique": "pieds",
	"heaume_jarl": "tete", "cuirasse_gardiens": "torse", "gantelets_hrafn": "mains", "bottes_rodeur": "pieds",
	"capuche_thaumaturge": "tete", "brigandine_braise": "torse"}
## pièces du corps cachées par emplacement ; « accessoires » (une seule maille : casque de base, plastron, épaulières, ceinture, gants,
## revers des bottes) : seuls les triangles portés par les os de la zone sont retirés
const CACHE := {"tete": ["Hair_Long"], "torse": ["tunique", "mante"], "mains": ["brassards"], "pieds": ["bottes"]}
const OS_ZONE := {
	"tete": ["Head"],
	"torse": ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r"],
	"mains": ["hand_l", "hand_r", "lowerarm_l", "lowerarm_r", "*doigts"],
	"pieds": ["calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"],
}
## matières (nom du matériau Blender -> preset shader_matiere ; UV propres : pas de projection boîte)
const MATIERES := {
	"fer": {"metal": 0.5, "poli": 0.38, "reflet": Color(0.95, 0.96, 1.0)},
	"fer_noir": {"metal": 0.55, "poli": 0.5, "reflet": Color(0.9, 0.93, 1.0)},
	"acier": {"metal": 0.78, "poli": 0.8, "reflet": Color(0.94, 0.98, 1.05)},
	"maille": {"metal": 0.6, "poli": 0.45, "reflet": Color(0.95, 0.97, 1.02)},
	"cuir": {"bord": 0.15, "poli": 0.2},
	"fourrure": {"bord": 0.04, "poli": 0.05},
	"laine": {"bord": 0.03, "poli": 0.05},
	"corne": {"bord": 0.2, "poli": 0.45, "metal": 0.1},
	"or": {"metal": 0.72, "poli": 0.6, "reflet": Color(1.06, 0.9, 0.62)},
	"argent": {"metal": 0.8, "poli": 0.75, "reflet": Color(0.96, 0.98, 1.04)},
	"givre": {"metal": 0.35, "poli": 0.9, "bord": 0.6, "reflet": Color(0.9, 0.97, 1.06), "lueur": 0.04},
	"braise": {"bord": 0.1, "poli": 0.2, "lueur": 0.0},
}

var echecs := 0
var args: PackedStringArray

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _arg(nom: String, defaut: String) -> String:
	for a in args:
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	args = OS.get_cmdline_user_args()
	_lancer.call_deferred()

func _lancer() -> void:
	if args.has("--test"):
		await _test()
	elif args.has("--planche"):
		await _planches()
	elif args.has("--film"):
		await _film()
	quit(1 if echecs > 0 else 0)

# ================================================================================================ pose des armures
static var _mats := {}

static func materiau(nom: String, tex: Texture2D) -> Material:
	var cle := "%s|%d" % [nom, tex.get_instance_id() if tex else 0]
	if _mats.has(cle):
		return _mats[cle]
	var p: Dictionary = MATIERES.get(nom.get_slice(".", 0), MATIERES["fer"])
	var m := Palette.materiau(tex, Vector2.ONE, Color.WHITE)
	m.shader = EpeesLongues.shader_matiere(false)
	m.set_shader_parameter("tex_neige", tex)
	m.set_shader_parameter("mt_boite", 0.0)
	for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
		m.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
	m.set_shader_parameter("mt_opacite", 1.0)
	m.set_shader_parameter("mt_reflet", p.get("reflet", Color.WHITE))
	m.set_shader_parameter("reflet_force", 0.0)
	m.set_shader_parameter("reflet_fil", 0.0)
	_mats[cle] = m
	return m

## Attache la pièce au squelette du corps ; retourne la MeshInstance3D (ou null si le glb manque).
static func porter(modele: Node3D, id: String) -> MeshInstance3D:
	var chemin := DOSSIER + id + ".glb"
	if not ResourceLoader.exists(chemin):
		push_warning("essai_armures_lourdes : glb absent " + chemin)
		return null
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var ancien := sq.get_node_or_null("armure_" + EMPL.get(id, id))
	if ancien:
		ancien.free()
	var inst := (load(chemin) as PackedScene).instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var sq_src := src.get_node_or_null(src.skeleton) as Skeleton3D
	var skin := src.skin.duplicate() as Skin
	for b in skin.get_bind_count():
		if skin.get_bind_name(b) == &"" and sq_src:
			skin.set_bind_name(b, sq_src.get_bone_name(skin.get_bind_bone(b)))
		skin.set_bind_bone(b, sq.find_bone(skin.get_bind_name(b)))
	var mi := MeshInstance3D.new()
	mi.name = "armure_" + EMPL.get(id, id)
	mi.mesh = src.mesh
	mi.skin = skin
	mi.set_meta("armure", id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for s in mi.mesh.get_surface_count():
		var m0 := mi.mesh.surface_get_material(s) as BaseMaterial3D
		var tex: Texture2D = m0.albedo_texture if m0 else null
		mi.set_surface_override_material(s, materiau(m0.resource_name if m0 else "fer", tex))
	inst.free()
	sq.add_child(mi)
	mi.skeleton = NodePath("..")
	_cacher(sq, EMPL.get(id, ""))
	return mi

## Cache les pièces du corps recouvertes par l'emplacement (et les triangles d'« accessoires » portés par ses os).
static func _cacher(sq: Skeleton3D, empl: String) -> void:
	for nom in CACHE.get(empl, []):
		var n := sq.get_node_or_null(NodePath(nom)) as MeshInstance3D
		if n:
			n.visible = false
	var acc := sq.get_node_or_null("accessoires") as MeshInstance3D
	if acc == null or not OS_ZONE.has(empl):
		return
	var zone := {}
	for nom: String in OS_ZONE[empl]:
		if nom == "*doigts":
			for b in sq.get_bone_count():
				var bn := sq.get_bone_name(b)
				for d in ["index", "middle", "ring", "pinky", "thumb"]:
					if bn.begins_with(d):
						zone[b] = true
		else:
			zone[sq.find_bone(nom)] = true
	var am := ArrayMesh.new()
	for s in acc.mesh.get_surface_count():
		var a := acc.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nb := bones.size() / v.size()
		var dans := PackedByteArray()
		dans.resize(v.size())
		for i in v.size():
			var t := 0.0
			for j in nb:
				if zone.has(GuerrierNordique._os_de_bind(acc.skin, sq, bones[i * nb + j])):
					t += w[i * nb + j]
			dans[i] = 1 if t >= 0.5 else 0
		var idx := _indices(a)
		var garde := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if dans[idx[t]] + dans[idx[t + 1]] + dans[idx[t + 2]] < 2:
				garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
		a[Mesh.ARRAY_INDEX] = garde
		var fl: int = acc.mesh.surface_get_format(s) & ~Mesh.ARRAY_FORMAT_VERTEX & ~Mesh.ARRAY_FORMAT_INDEX
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, fl & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS))
		var mat := acc.get_surface_override_material(s)
		am.surface_set_material(s, mat if mat else acc.mesh.surface_get_material(s))
		if mat:
			pass
	var ovs := []
	for s in acc.mesh.get_surface_count():
		ovs.append(acc.get_surface_override_material(s))
	acc.mesh = am
	for s in ovs.size():
		acc.set_surface_override_material(s, ovs[s])

## Indices des triangles (surfaces sans tableau d'indices : sommets pris trois par trois).
static func _indices(a: Array) -> PackedInt32Array:
	if a[Mesh.ARRAY_INDEX] != null:
		return a[Mesh.ARRAY_INDEX]
	var r := PackedInt32Array()
	for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		r.append(i)
	return r

# ================================================================================================ test de traversée
## Positions posées (repère du squelette) des sommets ids d'une pièce peau d'os.
func _poses(sq: Skeleton3D, mi: MeshInstance3D, a: Array, ids: PackedInt32Array) -> PackedVector3Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	var mats := {}
	var res := PackedVector3Array()
	res.resize(ids.size())
	for k in ids.size():
		var i := ids[k]
		var p := Vector3.ZERO
		for j in nb:
			var wj := w[i * nb + j]
			if wj <= 0.0:
				continue
			var bi := bones[i * nb + j]
			if not mats.has(bi):
				var os := GuerrierNordique._os_de_bind(mi.skin, sq, bi)
				mats[bi] = sq.get_bone_global_pose(os) * mi.skin.get_bind_pose(bi)
			p += ((mats[bi] as Transform3D) * v[i]) * wj
		res[k] = p
	return res

## Os principal (poids max) de chaque sommet -> point de l'axe de l'os (repos) le plus proche.
func _axes(sq: Skeleton3D, mi: MeshInstance3D, a: Array, ids: PackedInt32Array) -> Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	var os_ := PackedInt32Array()
	var pts := PackedVector3Array()
	for i in ids:
		var best := 0
		for j in nb:
			if w[i * nb + j] > w[i * nb + best]:
				best = j
		var o := GuerrierNordique._os_de_bind(mi.skin, sq, bones[i * nb + best])
		var a0 := sq.get_bone_global_rest(o).origin
		var a1 := a0
		for c in sq.get_bone_children(o):
			a1 = sq.get_bone_global_rest(c).origin
			break
		var p := Geometry3D.get_closest_point_to_segment(v[i], a0, a1) if a1 != a0 else a0
		os_.append(o)
		pts.append(p)
	return [os_, pts]

func _creer_heros() -> Node3D:
	var g := HerosSkarnholt.creer({})
	root.add_child(g)
	var ap := g.get_node("Animations") as AnimationPlayer
	var lib := load("res://assets/animations/corps_coups_tps.res") as AnimationLibrary
	if lib and not ap.has_animation_library("coups"):
		ap.add_animation_library("coups", lib)
	return g

func _test() -> void:
	var ids := _arg("ids", "").split(",", false)
	if ids.is_empty():
		for e: String in ["fer", "acier", "uniques_lourds", "uniques_legers"]:
			for id: String in ENSEMBLES[e]:
				if not ids.has(id):
					ids.append(id)
	var clips := ["Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Attack", "Spell_Simple_Shoot", "Hit_Chest", "Jump", "Idle_Torch"]
	var g := _creer_heros()
	var ap := g.get_node("Animations") as AnimationPlayer
	if ap.has_animation_library("coups"):
		var l := ap.get_animation_library("coups")
		var noms := l.get_animation_list()
		print("COUPS tps : %d clips" % noms.size())
		var pris := 0
		for n in noms:
			if pris < int(_arg("coups", "6")):
				clips.append("coups/" + n)
				pris += 1
	for id: String in ids:
		await _tester_piece(id, clips)
	g.free()
	print("FIN ESSAI ARMURES LOURDES : ", "ECHECS %d" % echecs if echecs else "TOUT OK")

func _tester_piece(id: String, clips: Array) -> void:
	var g := _creer_heros()
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := g.get_node("Animations") as AnimationPlayer
	var mi := porter(g, id)
	ok(mi != null, "%s : glb porté chargé et lié au squelette" % id)
	if mi == null:
		g.free()
		return
	var aa := mi.mesh.surface_get_arrays(0)
	# toutes les surfaces de l'armure en un seul tableau de triangles (repère du squelette)
	var tris := 0
	var v_arm := []
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		tris += _indices(a).size() / 3
		v_arm.append(a)
	var budget := 600 if EMPL[id] == "tete" else 900
	ok(tris <= budget, "%s : %d triangles (<= %d)" % [id, tris, budget])
	var nbind := 0
	for b in mi.skin.get_bind_count():
		if mi.skin.get_bind_bone(b) >= 0:
			nbind += 1
	ok(nbind == mi.skin.get_bind_count(), "%s : %d/%d os de la peau trouvés sur le squelette du héros" % [id, nbind, mi.skin.get_bind_count()])
	# points du corps encore visibles
	var corps := []
	for c in sq.get_children():
		if c is MeshInstance3D and c.visible and not c.has_meta("armure") and c.mesh:
			for s in c.mesh.get_surface_count():
				var a: Array = c.mesh.surface_get_arrays(s)
				var idx := _indices(a)
				var vu := {}
				for i in idx:
					vu[i] = true
				var ids_c := PackedInt32Array(vu.keys())
				corps.append([c, a, ids_c])
	sq.reset_bone_poses()
	var arm0 := _armure_posee(sq, mi, v_arm)
	var aabb := AABB((arm0[0][0] as PackedVector3Array)[0], Vector3.ZERO)
	for pts in arm0:
		for p in pts[0]:
			aabb = aabb.expand(p)
	aabb = aabb.grow(0.02)
	# points couverts au repos : le prolongement os -> point touche l'armure au-delà du point, le segment os -> point ne la touche pas
	var suivis := []      # [mi corps, tableau, ids, axes]
	var n_suivis := 0
	for e in corps:
		var c: MeshInstance3D = e[0]
		var a: Array = e[1]
		var ids_c: PackedInt32Array = e[2]
		var p0 := _poses(sq, c, a, ids_c)
		var ax := _axes(sq, c, a, ids_c)
		var garde := PackedInt32Array()
		var garde_ax := PackedVector3Array()
		var garde_os := PackedInt32Array()
		for k in ids_c.size():
			if not aabb.has_point(p0[k]):
				continue
			var cpt: Vector3 = ax[1][k]
			var dirv := p0[k] - cpt
			if dirv.length() < 0.005:
				continue
			var loin := cpt + dirv.normalized() * (dirv.length() + 0.25)
			if _coupe(arm0, cpt, p0[k]) >= 0.0:
				continue       # déjà dehors au repos (bord) : pas suivi
			var d := _coupe(arm0, p0[k], loin)
			if d < 0.0 or d > 0.12:
				continue
			garde.append(ids_c[k])
			garde_ax.append(cpt)
			garde_os.append(ax[0][k])
		if garde.size() > 0:
			suivis.append([c, a, garde, garde_ax, garde_os])
			n_suivis += garde.size()
	print("   %s : %d points du corps couverts suivis" % [id, n_suivis])
	var pire := 0.0
	var pire_ou := ""
	var total_mauvais := 0
	for clip: String in clips:
		if not ap.has_animation(clip):
			continue
		var anim := ap.get_animation(clip)
		var mauvais := 0
		var pire_clip := 0.0
		var bouge := 0.0
		var i_main := sq.find_bone("hand_r")
		for k in 8:
			ap.play(clip)
			ap.seek(anim.length * (k + 0.5) / 8.0, true)
			ap.advance(0.0)
			bouge = maxf(bouge, sq.get_bone_global_pose(i_main).origin.distance_to(sq.get_bone_global_rest(i_main).origin))
			var armp := _armure_posee(sq, mi, v_arm)
			for e in suivis:
				var pts := _poses(sq, e[0], e[1], e[2])
				for q in pts.size():
					var o: int = e[4][q]
					var cp: Vector3 = sq.get_bone_global_pose(o) * sq.get_bone_global_rest(o).affine_inverse() * (e[3][q] as Vector3)
					var tcut := _coupe_t(armp, cp, pts[q])
					if tcut >= 0.0:
						var prof := (pts[q] - cp).length() * (1.0 - tcut)
						if prof > TOL:
							mauvais += 1
						pire_clip = maxf(pire_clip, prof)
		if pire_clip > pire:
			pire = pire_clip
			pire_ou = clip
		total_mauvais += mauvais
		print("   %s / %s : %d points ressortis > %.1f cm, pire %.1f cm (main droite déplacée de %.0f cm : clip bien joué)" % [id, clip, mauvais, TOL * 100.0, pire_clip * 100.0, bouge * 100.0])
	# tolérance : quelques points sur des centaines de poses (aisselle en garde haute…) ; la profondeur reste bornée
	ok(total_mauvais <= maxi(3, n_suivis / 200) and pire < 0.04, "%s : traversées %d points > %.1f cm sur %d poses, pire %.1f cm (%s)" % [id, total_mauvais, TOL * 100.0, clips.size() * 8, pire * 100.0, pire_ou])
	g.free()

## Armure posée : liste [points posés, indices] par surface.
func _armure_posee(sq: Skeleton3D, mi: MeshInstance3D, v_arm: Array) -> Array:
	var res := []
	for a: Array in v_arm:
		var n := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var ids := PackedInt32Array()
		ids.resize(n)
		for i in n:
			ids[i] = i
		res.append([_poses(sq, mi, a, ids), _indices(a)])
	return res

## Distance (m) depuis a jusqu'au premier triangle de l'armure coupé par le segment a-b, -1 sinon.
func _coupe(arm: Array, a: Vector3, b: Vector3) -> float:
	var t := _coupe_t(arm, a, b)
	return t * (b - a).length() if t >= 0.0 else -1.0

## Fraction (0..1) du segment a-b où il coupe l'armure pour la DERNIÈRE fois (côté b), -1 sinon.
func _coupe_t(arm: Array, a: Vector3, b: Vector3) -> float:
	var best := -1.0
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var L := (b - a).length()
	for s: Array in arm:
		var p: PackedVector3Array = s[0]
		var idx: PackedInt32Array = s[1]
		for t in range(0, idx.size(), 3):
			var p0 := p[idx[t]]
			var p1 := p[idx[t + 1]]
			var p2 := p[idx[t + 2]]
			if maxf(p0.x, maxf(p1.x, p2.x)) < lo.x or minf(p0.x, minf(p1.x, p2.x)) > hi.x:
				continue
			if maxf(p0.y, maxf(p1.y, p2.y)) < lo.y or minf(p0.y, minf(p1.y, p2.y)) > hi.y:
				continue
			if maxf(p0.z, maxf(p1.z, p2.z)) < lo.z or minf(p0.z, minf(p1.z, p2.z)) > hi.z:
				continue
			var hit: Variant = Geometry3D.segment_intersects_triangle(a, b, p0, p1, p2)
			if hit != null:
				best = maxf(best, ((hit as Vector3) - a).length() / L)
	return best

# ================================================================================================ planches et film en jeu
var scene: Node
var j: CharacterBody3D

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec * 30.0)):
		if j:
			j.vigueur = j.vigueur_max
		await process_frame

func _scene_jeu() -> void:
	scene = load("res://scenes/test_combat.tscn").instantiate()
	scene.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(scene)
	j = scene.joueur
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if scene.get("mannequin"):
		scene.mannequin.visible = false
		scene.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	scene.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	j.basculer_vue(true)
	var mg = j.mains.magie
	mg.equiper("droite", "epee")
	await _attendre(1.0)

func _equiper_ensemble(ids: Array) -> void:
	var modele: Node3D = j.corps.modele
	for id: String in ids:
		porter(modele, id)
	# les mailles visibles du corps (vue 3e personne) : la liste de corps_joueur ne connaît pas l'armure -> rafraîchie
	var cj = j.corps
	if cj.get("_mailles") != null:
		cj._mailles.assign(modele.find_children("*", "MeshInstance3D", true, false))
		cj.definir_vue(true)

func _capture(chemin: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	img.save_png(chemin)
	print("CAPTURE ", chemin)

func _planches() -> void:
	await _scene_jeu()
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/armures_lourdes"))
	var ens := _arg("ensembles", "fer,acier,uniques_lourds,uniques_legers").split(",", false)
	# caméra libre : face / 3-4 / dos autour du héros, hauteur de la caméra 3e personne
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	for e in ens:
		var ids: Array = ENSEMBLES.get(e, e.split("+"))
		await _equiper_ensemble(ids)
		await _attendre(0.6)
		var c := j.global_position + Vector3(0, 1.0, 0)
		var avant := -j.global_transform.basis.z
		for v in [["face", 0.0], ["34", 40.0], ["dos", 180.0]]:
			var d := avant.rotated(Vector3.UP, deg_to_rad(v[1]))
			cam.global_position = c + d * 3.1 + Vector3(0, 0.35, 0)
			cam.look_at(c, Vector3.UP)
			cam.make_current()
			await _attendre(0.25)
			await _capture("%s/%s_%s.png" % [sortie, e, v[0]])
		# pièces au sol, posées devant le héros
		var sol := Node3D.new()
		scene.add_child(sol)
		var x := -0.9
		for id: String in ids:
			var ch := DOSSIER_SOL + id + ".glb"
			if ResourceLoader.exists(ch):
				var p := (load(ch) as PackedScene).instantiate() as Node3D
				for m: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
					for s in m.mesh.get_surface_count():
						var m0 := m.mesh.surface_get_material(s) as BaseMaterial3D
						m.set_surface_override_material(s, materiau(m0.resource_name if m0 else "fer", m0.albedo_texture if m0 else null))
				sol.add_child(p)
				p.global_position = j.global_position + avant * 1.6 + avant.cross(Vector3.UP) * x
				p.global_rotation.y = j.global_rotation.y + PI
				x += 0.6
		cam.global_position = j.global_position + avant * 3.2 + Vector3(0, 1.6, 0)
		cam.look_at(j.global_position + avant * 1.6 + Vector3(0, 0.15, 0), Vector3.UP)
		await _attendre(0.3)
		await _capture("%s/%s_sol.png" % [sortie, e])
		sol.queue_free()
		cam.clear_current()
		# vue de jeu (caméra 3e personne du joueur, de dos)
		j.camera_tp.set("_orbite", 0.0)
		await _attendre(0.4)
		await _capture("%s/%s_jeu.png" % [sortie, e])

func _film() -> void:
	await _scene_jeu()
	var ids: Array = ENSEMBLES.get(_arg("ensemble", "fer"), [])
	await _equiper_ensemble(ids)
	var mains = j.mains
	await _attendre(0.5)
	Input.action_press("avant")
	await _attendre(2.0)
	Input.action_release("avant")
	await _attendre(0.3)
	for k in 4:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(0.42)
	await _attendre(0.6)
	j.camera_tp.set("_orbite", deg_to_rad(-70.0))
	await _attendre(0.5)
	Input.action_press("avant")
	await _attendre(1.5)
	Input.action_release("avant")
	await _attendre(0.3)
	for k in 4:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(0.42)
	await _attendre(1.0)
