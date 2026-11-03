extends SceneTree
## Test de l'ARMURE PORTÉE VISIBLE (scripts/rpg/armure_visible.gd, branche rpg/armures_legeres) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_armure_visible.gd -- --nouvelle [--detail] [--id=<id>]
##   [--familles=obsidienne,or]
## A. Héros seul (HerosSkarnholt + ArmureVisible), pour CHAQUE pièce d'armures.json dont le glb porté existe :
##   - posée sur le squelette du corps, skin résolu par nom d'os (aucun os manquant), pose de liaison = pose de repos du héros (< 1 mm) ;
##   - budget : <= 900 triangles (casque / capuche <= 600), texture <= 256² (atlas peint par famille, 4 pièces), matériau « matière » ;
##   - masquage : plus aucun triangle de la tenue dans la zone recouverte (cotte |x| < 0,42, gants au-delà de |x| 0,58, bottes,
##     casque / cheveux) ; ôter la pièce rend les maillages d'origine ;
##   - AUCUNE TRAVERSÉE pendant les animations jouées (locomotion, coups 3e personne, sorts 3e personne ; 8 instants par clip) :
##     un point visible de la tenue restante (cou, manches, pantalon, brassards, barbe…) qui est SOUS la pièce au repos ne ressort pas
##     à travers elle de plus de TOL (segment os -> point coupé par un triangle posé de la pièce : la longueur au-delà = traversée).
##     Familles testées ensemble (4 pièces portées), comme en jeu.
##   - pose au sol (sol/<id>.glb) : présente, pivot au sol.
## B. En jeu (scène de combat) : équiper / ôter par EquipementCorps (signal change) habille et rhabille le corps ; vue 1re personne :
##   les bras FPS prennent la matière des gants portés, et la retrouvent quand on les ôte ; ombre seule à la 1re personne.
const TOL := 0.010
const TRIS_MAX := 900
const TRIS_TETE := 600
## Budgets de la charte des armures HD (conception_rpg/CHARTE_ARMURES_HD.md, 2026-11-02) : torse 1 500-2 500, casque 800-1 400,
## gants / bottes 600-1 200 ; textures 512² par pièce (ou atlas 1024²), lues avec mipmaps (ArmureVisible.shader_hd).
const TRIS_HD := {"torse": 2500, "tete": 1400, "mains": 1200, "pieds": 1200}
## Budgets propres à certaines pièces HD au niveau de détail du verre v5 (armure d'or v3 : lames articulées, genouillères, lions en relief).
const TRIS_HD_ID := {"cuirasse_or": 3000, "cuirasse_or_enchante": 3000, "bottes_or": 3200, "bottes_or_enchante": 3200}
const TEX_MAX := 1024
const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Sword_Attack", "Hit_Chest", "Jump", "Crouch_Fwd",
	"coups/slash_1", "coups/slash_2", "coups/revers", "coups/estoc", "coups/vertical", "coups/q_Sword_Regular_Combo", "coups/gs_slash",
	"coups/q_Sword_Block", "sorts/Sort_Lancer1M", "sorts/Sort_Jet2M", "sorts/Sort_Zone2M", "sorts/Spell_Simple_Shoot_D"]
var echecs := 0
var detail := false

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	detail = OS.get_cmdline_user_args().has("--detail")
	_lancer.call_deferred()

static func pieces() -> Array:
	var res := []
	var f := FileAccess.open("res://data/objets/armures.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for id: String in d["objets"]:
		if ArmureVisible.a_modele(id):
			res.append([id, String(d["objets"][id]["emplacement"])])
	for id: String in fiches_hd():
		if ArmureVisible.a_modele(id) and not d["objets"].has(id):
			res.append([id, Inventaire.emplacement_de(id)])
	return res

## Pièces HD livrées par les agents armures avant leur report dans armures.json (sources_blender/armures/<ensemble>/pieces.json,
## pour l'agent DONNÉES) : fiches injectées dans le registre le temps du test (rien n'est écrit). Variantes (« variante_de » : même
## maillage, autre texture / matériau) non testées en famille.
static func fiches_hd() -> Array:
	var ids := []
	var dossier := "res://sources_blender/armures/"
	for sous in DirAccess.get_directories_at(dossier):
		var chemin := dossier + sous + "/pieces.json"
		if not FileAccess.file_exists(chemin):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if not d is Dictionary:
			continue
		var o: Dictionary = d.get("objets", {})
		for id: String in o:
			if o[id].has("variante_de"):
				continue
			if not Inventaire.OBJETS.has(id):
				Inventaire.OBJETS[id] = o[id]
			ids.append(id)
	return ids

# ------------------------------------------------------------------------------------------------------ poses
static func _os_bind(mi: MeshInstance3D, sq: Skeleton3D, b: int) -> int:
	return GuerrierNordique._os_de_bind(mi.skin, sq, b)

## Positions posées (repère du squelette) des sommets `ids` d'un maillage skinné.
static func poses(sq: Skeleton3D, mi: MeshInstance3D, a: Array, ids: PackedInt32Array) -> PackedVector3Array:
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
				mats[bi] = sq.get_bone_global_pose(_os_bind(mi, sq, bi)) * mi.skin.get_bind_pose(bi)
			p += ((mats[bi] as Transform3D) * v[i]) * wj
		res[k] = p
	return res

static func tous(n: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(n)
	for i in n:
		r[i] = i
	return r

## Os dominant de chaque sommet (index du squelette).
static func os_dominant(sq: Skeleton3D, mi: MeshInstance3D, a: Array, ids: PackedInt32Array) -> PackedInt32Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / v.size()
	var r := PackedInt32Array()
	for i in ids:
		var best := 0
		var bw := -1.0
		for j in nb:
			if w[i * nb + j] > bw:
				bw = w[i * nb + j]
				best = bones[i * nb + j]
		r.append(_os_bind(mi, sq, best))
	return r

## Segment de l'os (tête -> tête du premier enfant, ou 10 cm dans l'axe) en pose courante.
static func segment_os(sq: Skeleton3D, b: int) -> Array:
	var t := sq.get_bone_global_pose(b)
	var enf := sq.get_bone_children(b)
	var fin := t.origin + t.basis.y.normalized() * 0.1
	if enf.size() > 0:
		fin = sq.get_bone_global_pose(enf[0]).origin
	return [t.origin, fin]

static func proche_segment(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-8 else 0.0

# ------------------------------------------------------------------------------------------------------ A. héros seul
func _heros(eq: EquipementCorps) -> Array:
	var h := HerosSkarnholt.creer({})
	root.add_child(h)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := h.get_node("Animations") as AnimationPlayer
	if not ap.has_animation_library("coups"):
		ap.add_animation_library("coups", CorpsCoupsTps.BIBLIOTHEQUE)
		ap.add_animation_library("sorts", CorpsMainsTps.SORTS)
	var porteur := Node.new()
	h.add_child(porteur)
	var av := ArmureVisible.equiper(porteur, sq, eq)
	return [h, sq, ap, av]

func _eq_avec(ids: Array) -> EquipementCorps:
	var inv := Inventaire.new()
	var eq := EquipementCorps.new(inv)
	for id in ids:
		inv.ajouter(id, 1)
		eq.equiper(id)
	return eq

func _verifier_piece(id: String, e: String) -> void:
	var eq := _eq_avec([])
	var r := _heros(eq)
	var h: Node3D = r[0]
	var sq: Skeleton3D = r[1]
	var av: ArmureVisible = r[3]
	var origine := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		origine[mi] = mi.mesh
	eq.inventaire.ajouter(id, 1)
	eq.equiper(id)
	var mi := av.maillage(e)
	ok(mi != null and mi.get_parent() == sq and mi.visible, "%s : modèle porté posé sur le squelette du corps (%s)" % [id, e])
	if mi == null:
		h.free()
		return
	# skin : liaisons par nom, toutes résolues
	var manquants := 0
	for b in mi.skin.get_bind_count():
		if _os_bind(mi, sq, b) < 0:
			manquants += 1
	ok(manquants == 0, "%s : %d liaisons d'os, toutes trouvées sur le squelette du héros" % [id, mi.skin.get_bind_count()])
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	sq.reset_bone_poses()
	var pr := poses(sq, mi, a, tous(v.size()))
	var ecart := 0.0
	for i in v.size():
		ecart = maxf(ecart, pr[i].distance_to(v[i]))
	ok(ecart < 0.001, "%s : pose de liaison = pose de repos du héros (écart max %.2f mm)" % [id, ecart * 1000.0])
	var tris := 0
	for s in mi.mesh.get_surface_count():
		tris += mi.mesh.surface_get_array_index_len(s) / 3
	var tmax := TRIS_TETE if e == "tete" else TRIS_MAX
	var hd := false
	for s in mi.mesh.get_surface_count():
		var ms := mi.get_surface_override_material(s) as ShaderMaterial
		var tx: Texture2D = ms.get_shader_parameter("tex_base") if ms else null
		hd = hd or (tx != null and tx.get_width() > ArmureVisible.TEX_HD)
	if hd:
		tmax = int(TRIS_HD_ID.get(id, TRIS_HD.get(e, TRIS_MAX)))
	ok(tris <= tmax, "%s : %d triangles (<= %d)" % [id, tris, tmax])
	var mat := mi.get_surface_override_material(0) as ShaderMaterial
	var tex: Texture2D = mat.get_shader_parameter("tex_base") if mat else null
	var tex_max := TEX_MAX if hd else 256
	ok(mat != null and (mat.shader == EpeesLongues.shader_matiere(false) or (hd and (mat.shader == ArmureVisible.shader_hd() or mat.shader == ArmureVisible.shader_or()))) and tex != null
		and tex.get_width() <= tex_max and tex.get_height() <= tex_max,
		"%s : matériau « matière » (%s), texture %s" % [id, mat.resource_name if mat else "?", str(tex.get_size()) if tex else "absente"])
	# masquage
	var reste := _triangles_recouverts(sq, av.zones(), av.limites())
	ok(reste == 0, "%s : plus aucun triangle de la tenue dans la zone « %s » (%d restants)" % [id, e, reste])
	if e == "torse":
		var jb := av.maillage("jambes")
		ok(jb != null and String(jb.get_meta("armure_id")) == "chausses_" + ArmureVisible.famille_chausses(id), "%s : chausses assorties posées (%s)" % [id, jb.get_meta("armure_id") if jb else "aucune"])
		var p := sq.get_node_or_null("pantalon") as MeshInstance3D
		ok(p != null and (p.mesh.surface_get_array_index_len(0) <= 3), "%s : pantalon du héros entièrement retiré sous les chausses" % id)
	if e == "tete":
		var ch := sq.get_node_or_null("Hair_Long") as MeshInstance3D
		ok(ch == null or not ch.visible, "%s : cheveux cachés sous la pièce de tête" % id)
	ok(ResourceLoader.exists(ArmureVisible.chemin_sol(id)), "%s : pose au sol présente (sol/%s.glb)" % [id, id])
	var s := ArmureVisible.instancier_sol(id)
	if s != null:
		root.add_child(s)
		var aabb := AABB()
		var premier := true
		for m: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			var b := m.global_transform * m.get_aabb()
			aabb = b if premier else aabb.merge(b)
			premier = false
		ok(absf(aabb.position.y) < 0.01 and aabb.size.y < 0.75, "%s : au sol, pivot au sol (bas à %.1f cm, hauteur %.0f cm)" % [id, aabb.position.y * 100.0, aabb.size.y * 100.0])
		s.free()
	eq.retirer(e)
	var rendu := true
	for m: MeshInstance3D in origine:
		if is_instance_valid(m) and m.mesh != origine[m]:
			rendu = false
	ok(rendu and av.maillage(e) == null and av.maillage("jambes") == null, "%s : ôtée, la tenue d'origine revient (mêmes maillages)" % id)
	h.free()

## Triangles visibles de la tenue du héros encore situés dans une zone recouverte (repos).
func _triangles_recouverts(sq: Skeleton3D, z: Array, lim := {}) -> int:
	var n := 0
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if not mi.visible or mi.has_meta("armure_id"):
			continue
		var nom := String(mi.name)
		if nom in ["pantalon", "tunique"] and lim.has("ourlet"):
			continue     # coupés à l'ourlet réel : vérifiés par _trous / traversées
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else tous(v.size())
			var atlas := Vector2(GuerrierTextures.ATLAS) if s == 0 else Vector2(GuerrierTextures.DECOUPES)
			for t in range(0, idx.size() - 2, 3):
				if idx[t] == idx[t + 1] and idx[t + 1] == idx[t + 2]:
					continue
				var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
				var u := (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0 * atlas if not uv.is_empty() else Vector2.ZERO
				var ys := [v[idx[t]].y, v[idx[t + 1]].y, v[idx[t + 2]].y]
				if nom == "accessoires" and c.y < 1.2 and lim.has("ourlets"):
					continue     # pans coupés à l'ourlet réel (sous-triangles de découpe)
				if ArmureVisible.recouvert(nom, s, c, u, z, ys.max(), minf(absf(v[idx[t]].x), minf(absf(v[idx[t + 1]].x), absf(v[idx[t + 2]].x))), ys.min(), lim):
					n += 1
					if detail:
						print("    reste %s/%d %s" % [nom, s, c.snapped(Vector3.ONE * 0.01)])
	return n

## Traversées : famille complète portée, tous les clips.
func _traversees(famille: String, liste: Array) -> void:
	var eq := _eq_avec(liste)
	var r := _heros(eq)
	var h: Node3D = r[0]
	var sq: Skeleton3D = r[1]
	var ap: AnimationPlayer = r[2]
	var av: ArmureVisible = r[3]
	sq.reset_bone_poses()
	# pièces portées : sommets et triangles
	var armures := []
	for mi: MeshInstance3D in av.maillages():
		var a := mi.mesh.surface_get_arrays(0)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		armures.append({"mi": mi, "a": a, "idx": idx, "ids": tous((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()), "e": String(mi.get_meta("armure_emplacement", ""))})
	# points visibles de la tenue restante
	var pts := []
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if not mi.visible or mi.has_meta("armure_id") or mi.skin == null:
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else tous(v.size())
			var vu := {}
			for t in range(0, idx.size() - 2, 3):
				if idx[t] == idx[t + 1] and idx[t + 1] == idx[t + 2]:
					continue
				for k in 3:
					vu[idx[t + k]] = true
			var ids := PackedInt32Array(vu.keys())
			if ids.is_empty():
				continue
			var s_arr := a.duplicate()
			pts.append({"mi": mi, "a": s_arr, "ids": ids, "nom": String(mi.name), "os": os_dominant(sq, mi, s_arr, ids)})
	# au repos : points SOUS une pièce = le segment os -> point est libre ET son prolongement au-delà du point (12 cm, vers
	# l'extérieur) rencontre la pièce ; t le long de l'os gardé
	for A: Dictionary in armures:
		A["p0"] = poses(sq, A["mi"], A["a"], A["ids"])
	var dedans := []   # [groupe, k, armure, t]
	for g in pts.size():
		var P: Dictionary = pts[g]
		var pp := poses(sq, P["mi"], P["a"], P["ids"])
		for k in pp.size():
			var b: int = P["os"][k]
			var seg := segment_os(sq, b)
			var t := proche_segment(seg[0], seg[1], pp[k])
			var c: Vector3 = (seg[0] as Vector3).lerp(seg[1], t)
			var dn := (pp[k] - c).normalized()
			var dehors := pp[k] + dn * 0.12
			for ai in armures.size():
				var A: Dictionary = armures[ai]
				var pa: PackedVector3Array = A["p0"]
				var idx: PackedInt32Array = A["idx"]
				var libre := true
				var couvert := Vector3.INF
				for i in range(0, idx.size(), 3):
					if Geometry3D.segment_intersects_triangle(c, pp[k], pa[idx[i]], pa[idx[i + 1]], pa[idx[i + 2]]) != null:
						libre = false
						break
					if couvert == Vector3.INF:
						var hc: Variant = Geometry3D.segment_intersects_triangle(pp[k], dehors, pa[idx[i]], pa[idx[i + 1]], pa[idx[i + 2]])
						if hc != null:
							couvert = hc
				if libre and couvert != Vector3.INF:
					# triangles de la pièce AUTOUR du point qui le couvre (8 cm) : on mesure la sortie à travers CETTE surface (un
					# point qui rentre dans une autre partie de la pièce, ex. le bras qui frôle le flanc, reste caché : ce n'est pas
					# une traversée visible)
					var voisins := PackedInt32Array()
					for i in range(0, idx.size(), 3):
						if ((pa[idx[i]] + pa[idx[i + 1]] + pa[idx[i + 2]]) / 3.0).distance_to(couvert) < 0.08:
							voisins.append(i)
					dedans.append([g, k, ai, t, voisins])
					break
	print("  %s : %d points de la tenue sous les pièces au repos" % [famille, dedans.size()])
	var pire := 0.0
	var ou := ""
	var nb_clips := 0
	for clip in CLIPS:
		if not ap.has_animation(clip):
			print("  (clip absent : %s)" % clip)
			continue
		nb_clips += 1
		ap.play(clip)
		var lg := ap.get_animation(clip).length
		var pire_clip := 0.0
		for n in 8:
			ap.seek(lg * n / 8.0, true)
			var pa_cour := []
			var dirs := []
			for A: Dictionary in armures:
				pa_cour.append(poses(sq, A["mi"], A["a"], A["ids"]))
			var pp_cour := {}
			for d: Array in dedans:
				var g: int = d[0]
				if not pp_cour.has(g):
					pp_cour[g] = poses(sq, pts[g]["mi"], pts[g]["a"], pts[g]["ids"])
				var p: Vector3 = pp_cour[g][d[1]]
				var b: int = pts[g]["os"][d[1]]
				var seg := segment_os(sq, b)
				var c: Vector3 = (seg[0] as Vector3).lerp(seg[1], d[3])
				var A: Dictionary = armures[d[2]]
				var pa: PackedVector3Array = pa_cour[d[2]]
				var idx: PackedInt32Array = A["idx"]
				for i: int in d[4]:
					var hit: Variant = Geometry3D.segment_intersects_triangle(c, p, pa[idx[i]], pa[idx[i + 1]], pa[idx[i + 2]])
					if hit != null:
						var prof := p.distance_to(hit as Vector3)
						pire_clip = maxf(pire_clip, prof)
						if prof > TOL and detail:
							print("    > %.1f mm %s t=%.2f %s sous %s (repos %s)" % [prof * 1000.0, clip, n / 8.0, pts[g]["nom"], A["e"], (pts[g]["a"][Mesh.ARRAY_VERTEX][pts[g]["ids"][d[1]]] as Vector3).snapped(Vector3.ONE * 0.005)])
						if prof > pire:
							pire = prof
							ou = "%s t=%.2f %s sous %s" % [clip, n / 8.0, pts[g]["nom"], A["e"]]
		if detail or pire_clip > TOL:
			print("  %s %s : traversée max %.1f mm" % [famille, clip, pire_clip * 1000.0])
	ok(pire <= TOL, "%s : aucune traversée de la tenue à travers les pièces > %.0f mm (%d clips x 8 instants, %d points ; pire %.1f mm %s)" % [famille, TOL * 1000.0, nb_clips, dedans.size(), pire * 1000.0, ou])
	h.free()

# ------------------------------------------------------------------------------------------------------ A2. pas de trou
## Combinaisons torse seul / pieds seuls / torse + pieds de chaque famille : tout triangle MASQUÉ du pantalon, de la cotte et des
## bottes du héros doit être réellement COUVERT par une pièce portée au repos (le rayon de l'os vers le centre du triangle, prolongé
## de 15 cm vers l'extérieur, rencontre une pièce) : sinon on verrait le fond à travers la jambe (« jambes qui disparaissent »).
func _trous(famille: String, liste: Array) -> void:
	var par_e := {}
	for id: String in liste:
		par_e[Inventaire.emplacement_de(id)] = id
	var combos := []
	if par_e.has("torse"):
		combos.append([par_e["torse"]])
	if par_e.has("pieds"):
		combos.append([par_e["pieds"]])
	if par_e.has("torse") and par_e.has("pieds"):
		combos.append([par_e["torse"], par_e["pieds"]])
	for combo in combos:
		var eq := _eq_avec(combo)
		var r := _heros(eq)
		var h: Node3D = r[0]
		var sq: Skeleton3D = r[1]
		var av: ArmureVisible = r[3]
		sq.reset_bone_poses()
		var tris_p := []
		for mi: MeshInstance3D in av.maillages():
			if true:
				var a := mi.mesh.surface_get_arrays(0)
				tris_p.append([poses(sq, mi, a, tous((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())), a[Mesh.ARRAY_INDEX]])
		for mb: MeshInstance3D in sq.find_children("bottes", "MeshInstance3D", false, false):     # ce qui reste des bottes du héros couvre aussi
			var ab := mb.mesh.surface_get_arrays(0)
			var vb: PackedVector3Array = ab[Mesh.ARRAY_VERTEX]
			if vb.size() >= 3:
				tris_p.append([poses(sq, mb, ab, tous(vb.size())), ab[Mesh.ARRAY_INDEX] if ab[Mesh.ARRAY_INDEX] != null else tous(vb.size())])
		var masques := 0
		var vides := 0
		if detail:
			for mi: MeshInstance3D in av.maillages():
				print("    pièce ", mi.get_meta("armure_id"), " aabb ", mi.mesh.get_aabb(), " tris ", mi.mesh.surface_get_array_index_len(0) / 3)
		var ou := ""
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			var nom := String(mi.name)
			if not nom in ["pantalon", "tunique", "bottes"] or not av._originaux.has(mi):
				continue
			if nom in ["pantalon", "tunique"]:     # coupés (pas masqués par triangles) : contrôle par bandes ci-dessous
				if nom == "pantalon":
					vides += _trous_pantalon(sq, mi, av, tris_p)
				continue
				continue
			var orig: Mesh = av._originaux[mi]
			var ao := orig.surface_get_arrays(0)
			var v: PackedVector3Array = ao[Mesh.ARRAY_VERTEX]
			var io: PackedInt32Array = ao[Mesh.ARRAY_INDEX] if ao[Mesh.ARRAY_INDEX] != null else tous(v.size())
			var gardes := {}
			var af := mi.mesh.surface_get_arrays(0)
			var ifl: PackedInt32Array = af[Mesh.ARRAY_INDEX]
			for t in range(0, ifl.size() - 2, 3):
				gardes[Vector3i(ifl[t], ifl[t + 1], ifl[t + 2])] = true
			var dom := os_dominant(sq, mi, ao, tous(v.size()))
			for t in range(0, io.size() - 2, 3):
				if gardes.has(Vector3i(io[t], io[t + 1], io[t + 2])):
					continue
				if absf(((v[io[t]] + v[io[t + 1]] + v[io[t + 2]]) / 3.0).x) > ArmureVisible.MAINS_X:
					continue     # mains : hors sujet ici
				var c := (v[io[t]] + v[io[t + 1]] + v[io[t + 2]]) / 3.0
				if c.y > 1.10 or c.y < 0.10 or absf(c.x) < 0.06:
					continue     # jambes et hanches seulement (le haut du corps reste sous la pièce, les semelles sous les bottes)
				masques += 1
				var seg := segment_os(sq, dom[io[t]])
				var axe: Vector3 = (seg[0] as Vector3).lerp(seg[1], proche_segment(seg[0], seg[1], c))
				if (c - axe).normalized().y < -0.6:
					continue     # face tournée vers le sol (dessous du pied, sous la semelle ouverte) : invisible
				var fin := c + (c - axe).normalized() * 0.15
				var couvert := false
				for tp: Array in tris_p:
					var pa: PackedVector3Array = tp[0]
					var ix: PackedInt32Array = tp[1]
					for i in range(0, ix.size(), 3):
						if Geometry3D.segment_intersects_triangle(axe, fin, pa[ix[i]], pa[ix[i + 1]], pa[ix[i + 2]]) != null:
							couvert = true
							break
					if couvert:
						break
				if not couvert:     # rayon tombé pile sur une arête : 3 rayons voisins sur 4 (à 5 mm) suffisent
					var nh := 0
					for dd: Vector3 in [Vector3(0.005, 0, 0), Vector3(-0.005, 0, 0), Vector3(0, 0.005, 0), Vector3(0, -0.005, 0)]:
						var ff := c + dd + (c + dd - axe).normalized() * 0.15
						var touche := false
						for tp: Array in tris_p:
							var pa: PackedVector3Array = tp[0]
							var ip: PackedInt32Array = tp[1]
							for i in range(0, ip.size(), 3):
								if Geometry3D.segment_intersects_triangle(axe, ff, pa[ip[i]], pa[ip[i + 1]], pa[ip[i + 2]]) != null:
									touche = true
									break
							if touche:
								break
						nh += int(touche)
					couvert = nh >= 3
					if not couvert and detail:
						var carte := ""
						for gy in range(-4, 5):
							for gx in range(-4, 5):
								var dd := Vector3(gx * 0.0025, gy * 0.0025, 0)
								var ff := c + dd + (c + dd - axe).normalized() * 0.15
								var touche := false
								for tp: Array in tris_p:
									var pa: PackedVector3Array = tp[0]
									var ip: PackedInt32Array = tp[1]
									for i in range(0, ip.size(), 3):
										if Geometry3D.segment_intersects_triangle(axe, ff, pa[ip[i]], pa[ip[i + 1]], pa[ip[i + 2]]) != null:
											touche = true
											break
									if touche:
										break
								carte += "#" if touche else "."
							carte += "\n"
						print("    trou ", c, " :\n", carte)
						for tp: Array in tris_p:
							var pa: PackedVector3Array = tp[0]
							var ip: PackedInt32Array = tp[1]
							var aretes := {}
							for i in range(0, ip.size(), 3):
								for e in 3:
									var u0: Vector3 = pa[ip[i + e]].snapped(Vector3.ONE * 0.0005)
									var u1: Vector3 = pa[ip[i + (e + 1) % 3]].snapped(Vector3.ONE * 0.0005)
									var cle := [u0, u1] if str(u0) < str(u1) else [u1, u0]
									aretes[str(cle)] = aretes.get(str(cle), [0, u0, u1])
									aretes[str(cle)][0] += 1
							for k in aretes:
								var ar: Array = aretes[k]
								if ar[0] == 1 and ((ar[1] + ar[2]) / 2.0).distance_to(c) < 0.05:
									print("      bord ouvert ", ar[1], " ", ar[2])
				if not couvert:
					vides += 1
					ou = "%s %s" % [nom, c.snapped(Vector3.ONE * 0.01)]
		ok(vides == 0, "%s %s : aucune zone vide (%d triangles du pantalon / de la cotte / des bottes masqués, %d non couverts %s)" % [famille, combo, masques, vides, ou])
		h.free()

## Pantalon coupé : chaque bande horizontale de 2 cm de la jambe (repos) qui n'a plus de pantalon doit être couverte par une pièce
## (échantillons autour de la jambe gauche et droite) ; renvoie le nombre d'échantillons vides.
func _trous_pantalon(sq: Skeleton3D, mi: MeshInstance3D, av: ArmureVisible, tris_p: Array) -> int:
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var vides := 0
	for cote: float in [1.0, -1.0]:
		var y := 0.18
		while y < 0.98:
			var c := Vector3(0.10 * cote, y, 0.02)
			var somme := Vector3.ZERO     # centre de la section : moyenne des sommets couvrants à cette hauteur, de ce côté
			var nb := 0
			for tp: Array in tris_p:
				for q: Vector3 in (tp[0] as PackedVector3Array):
					if absf(q.y - y) < 0.025 and q.x * cote > 0.03 and q.x * cote < 0.25:
						somme += q
						nb += 1
			if nb > 2:
				c = Vector3(somme.x / nb, y, somme.z / nb)
			# du pantalon reste-t-il à cette hauteur sur cette jambe ?
			var reste := false
			for t in range(0, ix.size() - 2, 3):
				var y0 := minf(v[ix[t]].y, minf(v[ix[t + 1]].y, v[ix[t + 2]].y))
				var y1 := maxf(v[ix[t]].y, maxf(v[ix[t + 1]].y, v[ix[t + 2]].y))
				if y0 <= y and y1 >= y and signf(v[ix[t]].x) == cote and y1 > y0:
					reste = true
					break
			if not reste:
				var couvert := false
				for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(cote, 0, 0)]:
					var fin := c + d * 0.3
					for tp: Array in tris_p:
						var pa: PackedVector3Array = tp[0]
						var ip: PackedInt32Array = tp[1]
						for i in range(0, ip.size(), 3):
							if Geometry3D.segment_intersects_triangle(c, fin, pa[ip[i]], pa[ip[i + 1]], pa[ip[i + 2]]) != null:
								couvert = true
								break
						if couvert:
							break
					if not couvert:
						break
				if not couvert:
					vides += 1
					if detail:
						print("    jambe vide y=%.2f cote=%d" % [y, cote])
			y += 0.02
	return vides

# ------------------------------------------------------------------------------------------------------ B. en jeu
func _en_jeu(ps: Array) -> void:
	var sc: Node = load("res://scenes/test_combat.tscn").instantiate()
	sc.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(sc)
	var j: CharacterBody3D = sc.joueur
	for i in 10:
		await process_frame
	var corps: Node3D = j.corps
	var av: ArmureVisible = corps.armure
	ok(av != null, "en jeu : corps_joueur a son ArmureVisible")
	var gants := ""
	for p: Array in ps:
		j.inventaire.ajouter(p[0], 1)
		if p[1] == "mains" and gants == "":
			gants = p[0]
	var par_e := {}
	for p: Array in ps:
		if not par_e.has(p[1]):
			par_e[p[1]] = p[0]
	for e in par_e:
		j.equipement_corps.equiper(par_e[e])
	await process_frame
	var tout := true
	for e in par_e:
		tout = tout and av.porte(e) == par_e[e]
	ok(tout, "en jeu : équiper %s habille le corps (%s)" % [par_e.values(), av.zones()])
	j.basculer_vue(false)
	await process_frame
	var mi := av.maillage(par_e.keys()[0])
	ok(mi != null and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "1re personne : la pièce ne projette que son ombre")
	if gants != "":
		var bras: Node = j.mains.get("bras")
		var n_ab := 0
		var n_arm := 0
		for m: MeshInstance3D in bras.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				var mm := m.mesh.surface_get_material(s)
				if mm and mm.resource_name.get_slice(".", 0) == "ab_gant":
					n_ab += 1
					if m.get_surface_override_material(s) != AvantBras.materiaux()["ab_gant"]:
						n_arm += 1
		ok(n_ab > 0 and n_arm == n_ab, "1re personne : gants %s sur les bras FPS (%d / %d surfaces de gant)" % [gants, n_arm, n_ab])
		j.equipement_corps.retirer("mains")
		await process_frame
		var revenu := 0
		for m: MeshInstance3D in bras.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				var mm := m.mesh.surface_get_material(s)
				if mm and mm.resource_name.get_slice(".", 0) == "ab_gant" and m.get_surface_override_material(s) == AvantBras.materiaux()["ab_gant"]:
					revenu += 1
		ok(revenu == n_ab, "1re personne : gants ôtés, les gants d'origine reviennent")
	j.basculer_vue(true)
	for e in par_e:
		j.equipement_corps.retirer(e)
	await process_frame
	ok(av.zones().is_empty(), "en jeu : tout ôté, plus aucune pièce sur le corps")
	sc.queue_free()
	await process_frame

func _lancer() -> void:
	var ps := pieces()
	var seul := ""
	var fams := PackedStringArray()     # --familles=obsidienne,or : seulement ces familles (dernier mot de l'id)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			seul = a.substr(5)
		elif a.begins_with("--familles="):
			fams = a.substr(11).split(",")
	print("pièces avec modèle porté : %d %s" % [ps.size(), ps.map(func(p: Array) -> String: return p[0])])
	ok(ps.size() >= 12, "au moins les 12 pièces légères (cuir, fourrure, os) ont un modèle porté (%d)" % ps.size())
	if not fams.is_empty():
		ps = ps.filter(func(p: Array) -> bool: return fams.has(String(p[0]).get_slice("_", String(p[0]).get_slice_count("_") - 1)))
	var familles := {}
	for p: Array in ps:
		if seul != "" and p[0] != seul:
			continue
		_verifier_piece(p[0], p[1])
		var f: String = p[0].get_slice("_", p[0].get_slice_count("_") - 1)
		if not familles.has(f):
			familles[f] = []
		familles[f].append(p[0])
	for f in familles:
		_traversees(f, familles[f])
		_trous(f, familles[f])
	await _en_jeu(ps)
	print("TEST ARMURE VISIBLE : %s (ECHECS : %d)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
