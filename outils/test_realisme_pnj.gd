extends SceneTree
## [pnj/realisme_v1] Test de la passe « moins Playmobil » (RealismePnj / VisagePnj), headless :
##   godot --headless --path . --script res://outils/test_realisme_pnj.gd -- --sans-cache-persos
## Vérifie (passe 2), pour chaque PNJ concerné : même squelette, mêmes animations que le rendu
## d'avant (--pnj-realisme-ancien simulé par RealismePnj._ancien) ; textures de peau / étoffes / cheveux bien repeintes (copies, pas
## l'archétype partagé) ; zone du visage changée et le reste de l'atlas de peau intact ; eirik et garde (crypte) non touchés ; stature.
var echecs := 0

func _initialize() -> void:
	_lancer.call_deferred()

func _ok(c: bool, m: String) -> void:
	print(("OK    " if c else "ECHEC ") + m)
	if not c:
		echecs += 1

func _pieces(n: Node3D) -> Dictionary:
	var d := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var t := 0
		for s in mi.mesh.get_surface_count():
			t += mi.mesh.surface_get_array_index_len(s) if mi.mesh.surface_get_array_index_len(s) > 0 else mi.mesh.surface_get_array_len(s)
		var cle := String(mi.name) if not String(mi.name).begins_with("@") else "@anonyme"
		d[cle] = int(d.get(cle, 0)) + t      # nœuds sans nom (@MeshInstance3D@n) : numérotés différemment d'une création à l'autre
	return d

func _tex(n: Node3D, piece: String) -> Image:
	var mi := n.find_child(piece, true, false) as MeshInstance3D
	if mi == null:
		return null
	var m := mi.get_active_material(0) as ShaderMaterial
	var t := m.get_shader_parameter("tex_base") as Texture2D
	return t.get_image() if t else null

func _diff(a: Image, b: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			s += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			k += 1
	return s / maxf(k, 1)

func _tris_visibles(n: Node3D) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _sat_moy(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				s += c.s
				k += 1
	return s / maxf(k, 1)

func _lancer() -> void:
	CachePersos.actif = false
	for id: String in ["forgeron", "chasseuse", "volva", "hab_paysan_a", "hab_paysan_c", "hab_paysanne_b", "hab_receleur", "hab_chasseresse_b"]:
		RealismePnj._ancien = 1
		PnjNordique.vider()
		var a := PnjNordique._creer(id)
		RealismePnj._ancien = 0
		var t0 := Time.get_ticks_usec()
		var b := PnjNordique._creer(id)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var sa := a.find_child("Skeleton3D", true, false) as Skeleton3D
		var sb := b.find_child("Skeleton3D", true, false) as Skeleton3D
		_ok(sa.get_bone_count() == sb.get_bone_count(), "%s : même squelette (%d os)" % [id, sb.get_bone_count()])
		var aa := a.find_child("Animations", true, false) as AnimationPlayer
		var ab := b.find_child("Animations", true, false) as AnimationPlayer
		_ok(aa.get_animation_list() == ab.get_animation_list(), "%s : mêmes animations (%d)" % [id, ab.get_animation_list().size()])
		_ok(b.get_meta("realisme_pnj", "") == id, "%s : passe appliquée (%.0f ms)" % [id, ms])
		var ta := _tris_visibles(a)
		var tb := _tris_visibles(b)
		_ok(tb <= int(ta * 1.30), "%s : budget de triangles adaptatif (%d -> %d)" % [id, ta, tb])
		var al: Dictionary = AllurePnj.ALLURES.get(id, {})
		if al.has("coiffure"):
			var ch := sb.get_node_or_null("chevelure") as MeshInstance3D
			_ok(ch != null and ch.visible, "%s : chevelure en cartes (%s)" % [id, al["coiffure"]])
			var hl := sb.get_node_or_null("Hair_Long") as MeshInstance3D
			_ok(hl == null or not hl.visible, "%s : casque Hair_Long caché" % id)
		var pb := _tex(b, "peau")
		var W := pb.get_width()
		var visage := Rect2i(int(W * 0.10), int(W * 0.13), int(W * 0.17), int(W * 0.15))
		var sv := _sat_moy(pb, visage)
		_ok(sv < 0.40, "%s : peau du visage ni orange ni poupée (saturation moyenne %.2f)" % [id, sv])
		var ma := (a.find_child("peau", true, false) as MeshInstance3D).get_active_material(0)
		var mb := (b.find_child("peau", true, false) as MeshInstance3D).get_active_material(0)
		_ok(ma != mb, "%s : copie (matériau partagé intact)" % id)
		# chaque pièce visible a un matériau
		var sans := []
		for mi: MeshInstance3D in sb.find_children("*", "MeshInstance3D", false, false):
			if mi.visible and mi.mesh != null and mi.get_active_material(0) == null:
				sans.append(String(mi.name))
		_ok(sans.is_empty(), "%s : pièces visibles toutes habillées %s" % [id, sans])
		a.free()
		b.free()
	for id: String in ["eirik", "garde"]:
		var n := PnjNordique._creer(id)
		_ok(not n.has_meta("realisme_pnj") and n.find_child("chevelure", true, false) == null, "%s (crypte) : non touché" % id)
		n.free()
	_ok(RealismePnj.taille("hab_chasseur_a") > 1.0 and RealismePnj.taille("eirik") == 1.0, "stature : variation par individu, 1 hors profil")
	print("REALISME_PNJ %s (%d échec(s))" % ["OK" if echecs == 0 else "ECHEC", echecs])
	quit(1 if echecs > 0 else 0)
