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
## matières : MÊMES presets que scripts/rpg/armure_visible.gd de l'agent X (branche rpg/armures_legeres) ; le nom du matériau Blender
## est « preset[.variante] » (fer.maille, acier.givre, cuir.braise, fourrure.laine, os.corne, fer.noir…) : seul le préfixe compte.
const MATIERES := {
	"cuir": {"teinte": Color(1.04, 1.0, 0.98), "bord": 0.14, "poli": 0.22},
	"fourrure": {"teinte": Color(1.02, 1.0, 0.98), "bord": 0.05, "poli": 0.05},
	"os": {"teinte": Color(1.02, 1.0, 0.97), "bord": 0.10, "poli": 0.30},
	"fer": {"teinte": Color(1.0, 1.0, 1.02), "metal": 0.5, "poli": 0.35, "reflet": Color(0.95, 0.96, 1.0)},
	"acier": {"teinte": Color(1.04, 1.04, 1.06), "metal": 0.75, "poli": 0.7, "reflet": Color(0.94, 0.98, 1.05)},
	"or": {"teinte": Color(1.0, 1.0, 1.0), "metal": 0.72, "poli": 0.6, "reflet": Color(1.06, 0.9, 0.62)},
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
	var p: Dictionary = MATIERES.get(nom.get_slice(".", 0), MATIERES["cuir"])
	var m := Palette.materiau(tex, Vector2.ONE, p.get("teinte", Color.WHITE))
	m.shader = EpeesLongues.shader_matiere(false)
	m.set_shader_parameter("tex_neige", tex)
	m.set_shader_parameter("mt_boite", 0.0)
	for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
		m.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
	m.set_shader_parameter("mt_opacite", 1.0)
	m.set_shader_parameter("mt_reflet", p.get("reflet", Color.WHITE))
	m.set_shader_parameter("reflet_force", 0.0)
	m.set_shader_parameter("reflet_fil", 0.0)
	m.next_pass = GuerrierNordique.contour()
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
	# débogage : --invisible=<id> garde le masquage de l'emplacement mais cache la pièce (voir ce qui reste du héros dessous)
	for a in OS.get_cmdline_user_args():
		if a == "--invisible=" + id:
			mi.visible = false
	return mi

## Cache ce que recouvrent les emplacements portés : MÊME règle que scripts/rpg/armure_visible.gd de l'agent X (recouvert() de f38c947, copiée ici
## pour essayer les pièces avant la fusion de son système) : zones de repos (mains |x| > 0,58 ; pieds y < 0,40 / 0,47 ; tête : casque,
## crête, camail, cheveux ; torse : cotte |x| < 0,42, mante, plastron, haut du pantalon, mèches de la nuque…).
const MAINS_X := 0.58
const TORSE_X := 0.42
const PIEDS_Y := 0.40
const PIEDS_Y_ACC := 0.47
const TETE_Y := 1.585
const CAMAIL_Y := 1.46
const CAMAIL_BAS_TORSE := 1.62
const TORSE_PANTALON_Y := 0.71
const TORSE_CHEVEUX_Y := 1.575

static func _cacher(sq: Skeleton3D, _empl: String) -> void:
	var z := []
	for c in sq.get_children():
		if c.has_meta("armure"):
			z.append(EMPL.get(String(c.get_meta("armure")), ""))
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if mi.has_meta("armure"):
			continue
		var nom := String(mi.name)
		if not mi.has_meta("orig"):
			mi.set_meta("orig", mi.mesh)
			mi.set_meta("vis", mi.visible)
		if nom.begins_with("Hair_Long"):
			mi.visible = bool(mi.get_meta("vis")) and not z.has("tete")
		if not mi.visible or not _concerne(nom, z):
			continue
		mi.mesh = _filtrer(mi.get_meta("orig"), nom, z)

static func _concerne(nom: String, z: Array) -> bool:
	match nom:
		"tunique":
			return z.has("torse") or z.has("mains")
		"mante", "Hair_Long":
			return z.has("torse")
		"brassards", "peau":
			return z.has("mains")
		"bottes":
			return z.has("pieds")
		"pantalon":
			return z.has("pieds") or z.has("torse")
		"accessoires":
			return true
	return false

static func _dans(r: Rect2i, u: Vector2) -> bool:
	return u.x >= r.position.x and u.y >= r.position.y and u.x < r.end.x and u.y < r.end.y

static func recouvert(nom: String, surface: int, c: Vector3, u: Vector2, z: Array, haut := -INF, x_min := INF) -> bool:
	if haut == -INF:
		haut = c.y
	if x_min == INF:
		x_min = absf(c.x)
	if z.has("mains") and absf(c.x) > MAINS_X and nom in ["tunique", "brassards", "peau", "accessoires"]:
		return true
	if z.has("pieds"):
		if nom == "bottes":
			return true
		if nom == "pantalon" and c.y < PIEDS_Y:
			return true
		if nom == "accessoires" and c.y < PIEDS_Y_ACC:
			return true
	var acc := nom == "accessoires" and surface == 0
	var oeil := acc and _dans(GuerrierTextures.R_OEIL, u)
	var casque := acc and (_dans(GardienTextures.R_CASQUE, u) or _dans(GardienTextures.R_BANDEAU, u))
	var camail := acc and _dans(GuerrierTextures.R_PLASTRON, u) and c.y > CAMAIL_Y
	if z.has("tete") and nom == "accessoires" and not oeil and (casque or camail or c.y > TETE_Y):
		return true
	if z.has("torse"):
		if camail and c.y < CAMAIL_BAS_TORSE:
			return true
		if nom == "pantalon" and haut > TORSE_PANTALON_Y:
			return true
		if nom == "tunique" and x_min < TORSE_X:
			return true
		if nom == "mante":
			return true
		if nom == "Hair_Long" and c.y < TORSE_CHEVEUX_Y:
			return true
		if nom == "accessoires":
			if surface == 1:
				return true
			if not oeil and not casque and not camail and c.y > 0.55 and c.y < TETE_Y and absf(c.x) < 0.45:
				return true
	return false

static func _filtrer(orig: Mesh, nom: String, z: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	for s in orig.get_surface_count():
		var a := orig.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx := _indices(a)
		var atlas := Vector2(GuerrierTextures.ATLAS) if s == 0 else Vector2(GuerrierTextures.DECOUPES)
		var garde := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			var u := Vector2.ZERO
			if not uv.is_empty():
				u = (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0 * atlas
			if not recouvert(nom, s, c, u, z, maxf(v[idx[t]].y, maxf(v[idx[t + 1]].y, v[idx[t + 2]].y)), minf(absf(v[idx[t]].x), minf(absf(v[idx[t + 1]].x), absf(v[idx[t + 2]].x)))):
				garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if garde.is_empty():
			garde = PackedInt32Array([0, 0, 0])
		a[Mesh.ARRAY_INDEX] = garde
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(s, orig.surface_get_material(s))
	return m

## Indices des triangles (surfaces sans tableau d'indices : sommets pris trois par trois).
static func _indices(a: Array) -> PackedInt32Array:
	if a[Mesh.ARRAY_INDEX] != null:
		return a[Mesh.ARRAY_INDEX]
	var r := PackedInt32Array()
	for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		r.append(i)
	return r

# ================================================================================================ test de traversée
## Camail du casque de base du héros et haut du col de la tenue de base autour du cou (accessoires) : leur masquage sous une pièce
## de torse est l'affaire d'ArmureVisible (agent X, prévenu) ; ils ne sont pas suivis ici.
func _sans_camail(a: Array, ids: PackedInt32Array) -> PackedInt32Array:
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var r := PackedInt32Array()
	for i in ids:
		if uv.size() > i and v[i].y > CAMAIL_Y and _dans(GuerrierTextures.R_PLASTRON, uv[i] * Vector2(GuerrierTextures.ATLAS)):
			continue
		if v[i].y > 1.50 and absf(v[i].x) < 0.2:
			continue     # haut du col / camail de la tenue de base autour du cou (triangles au-dessus de TETE_Y, gardés par ArmureVisible)
		r.append(i)
	return r

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
		if c.name == &"accessoires":
			ids_c = _sans_camail(a, ids_c)
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
	var detail := {}      # « pièce du corps @ position de repos arrondie » -> [nb, pire]
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
							var p0r: Vector3 = (e[1][Mesh.ARRAY_VERTEX] as PackedVector3Array)[e[2][q]]
							var cle := "%s @ (%.2f, %.2f, %.2f) os %s" % [e[0].name, snappedf(p0r.x, 0.05), snappedf(p0r.y, 0.05), snappedf(p0r.z, 0.05), sq.get_bone_name(o)]
							if args.has("--detail") and _tri_touche.size() == 2:
								var pa: Vector3 = (v_arm[_tri_touche[0]][Mesh.ARRAY_VERTEX] as PackedVector3Array)[_tri_touche[1]]
								cle += " <- armure (%.2f, %.2f, %.2f)" % [snappedf(pa.x, 0.02), snappedf(pa.y, 0.02), snappedf(pa.z, 0.02)]
							var d0: Array = detail.get(cle, [0, 0.0, ""])
							detail[cle] = [d0[0] + 1, maxf(d0[1], prof), clip if prof > d0[1] else d0[2]]
						pire_clip = maxf(pire_clip, prof)
		if pire_clip > pire:
			pire = pire_clip
			pire_ou = clip
		total_mauvais += mauvais
		print("   %s / %s : %d points ressortis > %.1f cm, pire %.1f cm (main droite déplacée de %.0f cm : clip bien joué)" % [id, clip, mauvais, TOL * 100.0, pire_clip * 100.0, bouge * 100.0])
	if args.has("--detail"):
		var cles := detail.keys()
		cles.sort_custom(func(a, b) -> bool: return detail[a][0] > detail[b][0])
		for c in cles.slice(0, 12):
			print("      DETAIL %s : %d fois, pire %.1f cm (%s)" % [c, detail[c][0], detail[c][1] * 100.0, detail[c][2]])
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
				var th := ((hit as Vector3) - a).length() / L
				if th > best:
					best = th
					_tri_touche = [arm.find(s), idx[t]]
	return best

## --detail : dernier triangle de l'armure touché par _coupe_t (surface, 1er sommet) -> sommet de l'armure au repos dans le détail
var _tri_touche := []

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
	mg.equiper("gauche", Equipement.MAIN_VIDE)
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

## Le héros face au soleil (vue de face éclairée), HUD caché.
func _poser_au_soleil() -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	for l: DirectionalLight3D in root.find_children("*", "DirectionalLight3D", true, false):
		if l.visible and l.light_energy > 0.3:
			var sd := -l.global_transform.basis.z
			sd.y = 0.0
			if sd.length() > 0.01:
				sd = sd.normalized()
				j.rotation.y = atan2(sd.x, sd.z) + deg_to_rad(float(_arg("decal", "25")))
			break

func _planches() -> void:
	await _scene_jeu()
	_poser_au_soleil()
	# mains vides pour les planches (pose de repos lisible, pas de torche devant l'armure) ; le film garde l'épée
	j.mains.magie.equiper("gauche", Equipement.MAIN_VIDE)
	if not args.has("--epee"):
		j.mains.magie.equiper("droite", Equipement.MAIN_VIDE)
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/armures_lourdes"))
	var ens := _arg("ensembles", "fer,acier,uniques_lourds,uniques_legers").split(",", false)
	# caméra libre : face / 3-4 / dos autour du héros, puis buste en 3/4 ; vue de jeu (caméra 3e personne) à la fin
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	for e in ens:
		var ids: Array = ENSEMBLES.get(e, e.split("+"))
		await _equiper_ensemble(ids)
		await _attendre(0.6)
		var c := j.global_position + Vector3(0, 0.92, 0)
		var avant := -j.global_transform.basis.z
		for v in [["face", 0.0, 3.1, 0.0], ["34", 40.0, 3.1, 0.0], ["dos", 180.0, 3.1, 0.0], ["buste", 30.0, 1.35, 0.55], ["34dos", 140.0, 3.1, 0.0]]:
			var d := avant.rotated(Vector3.UP, deg_to_rad(v[1]))
			var cc := c + Vector3(0, v[3], 0)
			cam.global_position = cc + d * float(v[2]) + Vector3(0, 0.25, 0)
			cam.look_at(cc, Vector3.UP)
			cam.make_current()
			await _attendre(0.2)
			await _capture("%s/%s_%s.png" % [sortie, e, v[0]])
		# pièces au sol, posées devant le héros
		var sol := Node3D.new()
		scene.add_child(sol)
		var droite := avant.cross(Vector3.UP).normalized()
		var x := -0.84
		for id: String in ids:
			var ch := DOSSIER_SOL + id + ".glb"
			if ResourceLoader.exists(ch):
				var p := (load(ch) as PackedScene).instantiate() as Node3D
				for m: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
					for s in m.mesh.get_surface_count():
						var m0 := m.mesh.surface_get_material(s) as BaseMaterial3D
						m.set_surface_override_material(s, materiau(m0.resource_name if m0 else "fer", m0.albedo_texture if m0 else null))
				sol.add_child(p)
				p.global_position = j.global_position + avant * 1.2 + droite * x
				p.global_rotation.y = j.global_rotation.y + PI
				x += 0.56
		j.visible = false
		cam.global_position = j.global_position + avant * 3.1 + Vector3(0, 1.25, 0)
		cam.look_at(j.global_position + avant * 1.2 + Vector3(0, 0.12, 0), Vector3.UP)
		await _attendre(0.3)
		await _capture("%s/%s_sol.png" % [sortie, e])
		j.visible = true
		sol.queue_free()
		cam.clear_current()

func _film() -> void:
	await _scene_jeu()
	_poser_au_soleil()
	j.rotation.y += PI      # soleil derrière la caméra 3e personne : le dos du héros (vu en jeu) est éclairé
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = true
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
