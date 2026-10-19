extends SceneTree
## Test headless de la végétation écologique du lot E (zone témoin) :
##   godot --headless --path . --script outils/test_vegetation_biome.gd
## Arbres ≥ 2,5 m du chemin, rien dans les exclusions, aucune instance flottante ou trop enfoncée,
## nombre d'arbres ≈ avant (±15 %), distance minimale entre arbres, aucun arbre dans le cône de vue,
## touffes ≥ 0,8 m du chemin. Utilise `monde.arbres_zone` (meta) et les MultiMesh de sous-bois.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _bas(x: float, z: float, r: float) -> float:
	return minf(minf(m.hauteur(x - r, z), m.hauteur(x + r, z)), minf(m.hauteur(x, z - r), m.hauteur(x, z + r)))

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await process_frame
	var avant: int = m.get_meta("arbres_zone_avant")
	var ch = m.chemins
	var infos: Array = m.get_meta("arbres_zone")
	var n := infos.size()
	_verif(absf(float(n - avant)) <= 0.15 * avant, "arbres dans la zone : %d (avant %d, tolérance ±15 %%)" % [n, avant])
	var d_chemin := INF
	var excl := 0
	var cone := 0
	var flottants := 0
	var enfonces := 0
	var jeunes := 0
	var morts := 0
	var tordus := 0
	for a: Dictionary in infos:
		var p: Vector3 = a["pos"]
		var s: float = a["s"]
		d_chemin = minf(d_chemin, ch.distance(p.x, p.z))
		if Vegetation.exclu_decor(p.x, p.z):
			excl += 1
		if ch.dans_cone_vue(p.x, p.z):
			cone += 1
		if p.y > _bas(p.x, p.z, 0.5 * s) + 0.05:
			flottants += 1
		if p.y < _bas(p.x, p.z, 0.5 * s) - 0.6:
			enfonces += 1
		if a["forme"] == 2 and s < 0.65 and a["nouveau"]:
			jeunes += 1
		if a["forme"] == 3:
			morts += 1
	_verif(d_chemin >= 2.5, "arbres à ≥ 2,5 m du chemin (min %.2f)" % d_chemin)
	_verif(excl == 0, "aucun arbre dans les exclusions (feu, cercle, tumulus) : %d" % excl)
	_verif(cone == 0, "aucun arbre dans le cône de vue : %d" % cone)
	_verif(flottants == 0, "aucun arbre flottant : %d" % flottants)
	_verif(enfonces == 0, "aucun arbre trop enfoncé : %d" % enfonces)
	_verif(jeunes >= 10, "jeunes arbres en lisière : %d (morts %d)" % [jeunes, morts])
	# distance minimale : au moins un arbre nouveau dans chaque paire
	var proches := 0
	var dmin := INF
	for i in n:
		for j in range(i + 1, n):
			if not (infos[i]["nouveau"] or infos[j]["nouveau"]):
				continue
			var d := Vector2(infos[i]["pos"].x - infos[j]["pos"].x, infos[i]["pos"].z - infos[j]["pos"].z).length()
			dmin = minf(dmin, d)
			if d < Vegetation.DIST_MIN_SERRE - 0.01:
				proches += 1
	_verif(proches == 0, "distance minimale entre arbres ≥ %.1f m (min mesuré %.2f)" % [Vegetation.DIST_MIN_SERRE, dmin])
	# aucun arbre ancien gardé hors fondu qui violerait quelque chose : le tronc gênant (-18.5, -14.7)
	var gene := INF
	for a: Dictionary in infos:
		gene = minf(gene, Vector2(a["pos"].x + 18.5, a["pos"].z + 14.7).length())
	_verif(gene > 1.5, "plus de tronc en (-18.5, -14.7) (plus proche : %.2f m)" % gene)
	# clairières : part de la zone en D < 0,15
	var bruit := Vegetation.nouveau_bruit_amas()
	var tot := 0
	var clair := 0
	var x := ZoneBiome.X0 + 1.0
	while x < ZoneBiome.X1:
		var z := ZoneBiome.Z0 + 1.0
		while z < ZoneBiome.Z1:
			tot += 1
			if Vegetation.densite_amas(bruit, x, z) < Vegetation.D_CLAIRIERE:
				clair += 1
			z += 2.0
		x += 2.0
	print("      clairières (D < 0,15) : %.1f %% de la zone" % (100.0 * clair / tot))
	# sous-bois : touffes ≥ 0,8 m du chemin, rien dans les exclusions, ancrage
	var mm_n := 0
	var touffe_min := INF
	var sb_excl := 0
	var sb_flot := 0
	var tris := 0
	for nd in m.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := nd as MultiMeshInstance3D
		if not mmi.has_meta("sous_bois"):
			continue
		var mm := mmi.multimesh
		var est_touffe: bool = mmi.get_meta("sous_bois") == "touffe"
		var tpm := 0
		for sf in mm.mesh.get_surface_count():
			tpm += (mm.mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		tris += tpm * mm.instance_count
		for t: Transform3D in mmi.get_meta("transforms"):
			var o := t.origin
			mm_n += 1
			if Vegetation.exclu_decor(o.x, o.z):
				sb_excl += 1
			if est_touffe:
				touffe_min = minf(touffe_min, ch.distance(o.x, o.z))
			if o.y > _bas(o.x, o.z, 0.3) + 0.05:
				sb_flot += 1
				print("      flottant ", mmi.get_meta("sous_bois"), " ", o, " excès ", o.y - _bas(o.x, o.z, 0.3))
	_verif(mm_n > 0, "instances de sous-bois : %d (%d triangles au total dans la zone)" % [mm_n, tris])
	_verif(touffe_min >= 0.8, "touffes à ≥ 0,8 m du chemin (min %.2f)" % touffe_min)
	_verif(sb_excl == 0, "aucun élément de sous-bois dans les exclusions : %d" % sb_excl)
	_verif(sb_flot == 0, "aucun élément de sous-bois flottant : %d" % sb_flot)
	print("ECHEC : %d" % _echecs if _echecs > 0 else "OK : végétation de la zone conforme")
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
