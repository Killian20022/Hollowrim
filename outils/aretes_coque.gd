extends SceneTree
## Étanchéité GÉOMÉTRIQUE de la coque du repaire (retours exe 4, passe v3) : soude les sommets de tous les maillages Coque* par position
## exacte et compte les triangles de chaque arête. Une arête bordée d'UN seul triangle est un bord ouvert : soit une jonction en T
## (sommet posé au milieu d'une arête voisine non découpée : fissure d'un pixel), soit un vrai vide (bords écartés : barre noire de près).
##   godot --headless --path . --script res://outils/aretes_coque.gd -- [--detail=C] [--max=40]
## Imprime, par branche, le nombre et la longueur des bords ouverts, classés « T » (bord voisin colinéaire à < 1 mm) ou « vide »
## (écart au bord ouvert le plus proche, en cm), et les pires vides.
var g: Grotte

func _init() -> void:
	_go.call_deferred()

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _go() -> void:
	var detail := ""
	var nmax := 25
	var prefixe := "CoqueFine"      # la coque fine seule ; --tout : aussi les facettes « Coque_ » du décor (îlots, corniches, glace : ouvertes par nature)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--detail="):
			detail = a.substr(9)
		elif a == "--tout":
			prefixe = "Coque"
		elif a.begins_with("--max="):
			nmax = int(a.substr(6))
	var pere := Node3D.new()
	root.add_child(pere)
	g = Grotte.creer(pere, null, {})
	await process_frame
	var ids := {}
	var pos := PackedVector3Array()
	var aretes := {}      # Vector2i(min, max) -> [nombre, nom du maillage]
	var nb_tri := 0
	var noeuds: Array = []
	for n in g.get_children():
		if n is MeshInstance3D and String(n.name).begins_with(prefixe):
			noeuds.append(n)
	if prefixe == "CoqueFine":      # 2e passe : les bouchons (dôme, bouche, ciel) et le décor ne FERMENT que des arêtes déjà dans la coque
		for n in g.get_children():
			if n is MeshInstance3D and String(n.name).begins_with("Coque_"):
				noeuds.append(n)
	for n in noeuds:
		var bouchon := String(n.name).begins_with("Coque_") and prefixe == "CoqueFine"
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var cnt := ix.size() if ix.size() > 0 else v.size()
			for t in cnt / 3:
				var tri: Array[int] = []
				for c in 3:
					var q: Vector3 = v[ix[t * 3 + c]] if ix.size() > 0 else v[t * 3 + c]
					var id: int = ids.get(q, -1)
					if id < 0 and bouchon:
						id = -2
					elif id < 0:
						id = pos.size()
						pos.append(q)
						ids[q] = id
					tri.append(id)
				if tri[0] == tri[1] or tri[1] == tri[2] or tri[0] == tri[2]:
					continue
				nb_tri += 1
				for c in 3:
					var e := Vector2i(mini(tri[c], tri[(c + 1) % 3]), maxi(tri[c], tri[(c + 1) % 3]))
					if bouchon and (e.x < 0 or not aretes.has(e)):
						continue
					var r: Array = aretes.get(e, [0, String(n.name)])
					r[0] += 1
					aretes[e] = r
	var bords: Array = []
	var trop := 0
	for e: Vector2i in aretes:
		var c: int = aretes[e][0]
		if c == 1:
			bords.append(e)
		elif c > 2:
			trop += 1
	# index spatial des bords ouverts (cases de 0,5 m)
	var cases := {}
	for i in bords.size():
		var e: Vector2i = bords[i]
		var a: Vector3 = pos[e.x]
		var b: Vector3 = pos[e.y]
		var nseg := maxi(1, ceili(a.distance_to(b) / 0.4))
		for k in nseg + 1:
			var p := a.lerp(b, float(k) / float(nseg))
			var ck := Vector3i(floori(p.x / 0.5), floori(p.y / 0.5), floori(p.z / 0.5))
			var l: Array = cases.get(ck, [])
			if l.is_empty() or l.back() != i:
				l.append(i)
			cases[ck] = l
	# repère branche / s : anneau le plus proche
	var par_br := {}
	var vides: Array = []
	var hist := {}      # branche + sommet d'anneau le plus proche -> bords ouverts
	for i in bords.size():
		var e: Vector2i = bords[i]
		var a: Vector3 = pos[e.x]
		var b: Vector3 = pos[e.y]
		var mid := (a + b) * 0.5
		var best := 1e9
		var ck0 := Vector3i(floori(mid.x / 0.5), floori(mid.y / 0.5), floori(mid.z / 0.5))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for j: int in cases.get(ck0 + Vector3i(dx, dy, dz), []):
						if j == i:
							continue
						var f: Vector2i = bords[j]
						var d := maxf(_seg_dist(a.lerp(b, 0.25), pos[f.x], pos[f.y]), 0.0)
						d = minf(d, _seg_dist(mid, pos[f.x], pos[f.y]))
						best = minf(best, d)
		var brn := ""
		var sb := 0.0
		var bd := 1e9
		var kp := -1
		for id: String in g.ordre:
			for r: Dictionary in (g.br[id] as Dictionary)["anneaux"]:
				var dd := (r["P"] as Vector3).distance_squared_to(mid)
				if dd < bd:
					bd = dd
					brn = id
					sb = float(r["s"])
					var dk := 1e9
					for k in Grotte.NB:
						var d2 := ((r["pts"] as Array)[k] as Vector3).distance_squared_to(mid)
						if d2 < dk:
							dk = d2
							kp = k
		var cle_k := "%s k%02d" % [brn, kp]
		hist[cle_k] = int(hist.get(cle_k, 0)) + 1
		var L := a.distance_to(b)
		var genre := "T" if best < 0.001 else "vide"
		var pb: Dictionary = par_br.get(brn, {"T": 0, "vide": 0, "lT": 0.0, "lv": 0.0})
		pb[genre] += 1
		pb["lT" if genre == "T" else "lv"] += L
		par_br[brn] = pb
		if genre == "vide":
			vides.append([best, L, brn, sb, mid, aretes[e][1]])
	print("COQUE : %d triangles, %d sommets, %d arêtes, %d bords ouverts, %d arêtes à 3+ triangles" % [nb_tri, pos.size(), aretes.size(), bords.size(), trop])
	for id in par_br:
		var pb: Dictionary = par_br[id]
		print("   %s : T %d (%.1f m)   vide %d (%.1f m)" % [id, pb["T"], pb["lT"], pb["vide"], pb["lv"]])
	var hk: Array = hist.keys()
	hk.sort()
	var ligne := "PAR SOMMET :"
	for k: String in hk:
		ligne += " %s=%d" % [k, hist[k]]
	print(ligne)
	vides.sort_custom(func(x, y) -> bool: return x[1] * minf(x[0], 0.5) > y[1] * minf(y[0], 0.5))
	for k in mini(nmax, vides.size()):
		var w: Array = vides[k]
		if detail != "" and w[2] != detail:
			continue
		print("VIDE écart %.1f cm  long %.2f m  %s s=%.1f  y=%.2f  %s" % [100.0 * minf(w[0], 9.99), w[1], w[2], w[3], (w[4] as Vector3).y - 0.0, w[5]])
	quit(0)
