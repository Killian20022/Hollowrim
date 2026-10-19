extends SceneTree
## Signature d'invariance du biome : hauteurs du terrain, transforms de tous les MultiMesh
## (par mesh, triés) et pierres du cercle runique. Sert à prouver qu'un refactoring ne change rien.
## ATTENTION : en --headless le MultiMesh ne relit pas ses transforms (identité) : lancer AVEC fenêtre
##   (ex. --resolution 160x90) pour que la comparaison soit réelle ; référence : ref_ancien_fenetre.sig.
##   godot --headless --path . --script outils/test_biome.gd -- ecrire <fichier>
##   godot --headless --path . --script outils/test_biome.gd -- comparer <fichier> [--sans-zone] [--biome=ancien]
## --sans-zone : ignore tout ce qui touche la zone témoin (x ∈ [-58, 4], z ∈ [-64, 4] + fondu de 8 m).
const SCENE := preload("res://scenes/foret_test.tscn")
const PAS := 2.0
const DEMI := 120.0
# zone témoin élargie du fondu (valeurs écrites en dur : le test doit marcher avant ZoneBiome)
const ZX0 := -66.0
const ZX1 := 12.0
const ZZ0 := -72.0
const ZZ1 := 12.0

var m: Node

func _init() -> void:
	_tester.call_deferred()

func _dans_zone(x: float, z: float) -> bool:
	return x >= ZX0 and x <= ZX1 and z >= ZZ0 and z <= ZZ1

## Comparaison à 1e-4 près : le découpage en cellules (lot A) passe par des coordonnées locales,
## donc l'arrondi flottant peut différer d'un ulp ; l'ensemble trié reste le même.
func _memes_transforms(x: Array, y: Array) -> bool:
	if x.size() != y.size():
		return false
	for k in x.size():
		var p: Transform3D = x[k]
		var q: Transform3D = y[k]
		if (p.origin - q.origin).length() > 1e-4 or (p.basis.x - q.basis.x).length() > 1e-4 or (p.basis.y - q.basis.y).length() > 1e-4 or (p.basis.z - q.basis.z).length() > 1e-4:
			print("  premier écart (indice %d) : %s <> %s" % [k, p.origin, q.origin])
			print("   suite : ", x[k + 1].origin, x[k + 2].origin, " | ", y[k + 1].origin, y[k + 2].origin)
			return false
	return true

func _tri_transforms(a: Transform3D, b: Transform3D) -> bool:
	var oa := a.origin
	var ob := b.origin
	if oa.x != ob.x:
		return oa.x < ob.x
	if oa.z != ob.z:
		return oa.z < ob.z
	if oa.y != ob.y:
		return oa.y < ob.y
	return a.basis.x.x < b.basis.x.x

func _signature() -> Dictionary:
	var sig := {}
	# hauteurs
	var n := int(DEMI * 2.0 / PAS) + 1
	var hs := PackedFloat64Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = m.hauteur(i * PAS - DEMI, j * PAS - DEMI)
	sig["hauteurs"] = hs
	# tous les MultiMeshInstance3D, regroupés par mesh (clé = classe, boîte, surfaces, sommets)
	var groupes := {}
	for nd in m.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := nd as MultiMeshInstance3D
		if mmi.has_meta("lod"):
			continue  # MMI d'ombre ou de LOD ajoutés par le lot A
		var mm := mmi.multimesh
		var cle := "%s|%s|%d|%d" % [mm.mesh.get_class(), str(mm.mesh.get_aabb()), mm.mesh.get_surface_count(), (mm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if mm.mesh is ArrayMesh else 0]
		if not groupes.has(cle):
			groupes[cle] = []
		for k in mm.instance_count:
			groupes[cle].append(mmi.global_transform * mm.get_instance_transform(k))
	for cle in groupes:
		groupes[cle].sort_custom(_tri_transforms)
	sig["multimesh"] = groupes
	# pierres du cercle : boîtes posées à moins de 10 m du centre (menhirs) + stèle
	var pierres: Array = []
	for nd in m.get_children():
		if nd is MeshInstance3D and nd.mesh is BoxMesh:
			var p: Vector3 = nd.position
			if Vector2(p.x - m.CERCLE.x, p.z - m.CERCLE.z).length() < 10.0:
				pierres.append([nd.transform, (nd.mesh as BoxMesh).size])
	pierres.sort_custom(func(a, b) -> bool: return _tri_transforms(a[0], b[0]))
	sig["pierres"] = pierres
	return sig

func _filtrer(sig: Dictionary) -> Dictionary:
	var n := int(DEMI * 2.0 / PAS) + 1
	var hs: PackedFloat64Array = sig["hauteurs"]
	var h2 := PackedFloat64Array()
	for j in n:
		for i in n:
			if not _dans_zone(i * PAS - DEMI, j * PAS - DEMI):
				h2.append(hs[j * n + i])
	var mm2 := {}
	for cle in sig["multimesh"]:
		var l: Array = []
		for t: Transform3D in sig["multimesh"][cle]:
			if not _dans_zone(t.origin.x, t.origin.z):
				l.append(t)
		mm2[cle] = l
	var p2: Array = []
	for p in sig["pierres"]:
		if not _dans_zone(p[0].origin.x, p[0].origin.z):
			p2.append(p)
	return {"hauteurs": h2, "multimesh": mm2, "pierres": p2}

func _tester() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else ""
	var fichier := args[1] if args.size() > 1 else ""
	if mode == "" or fichier == "":
		print("usage : -- ecrire|comparer <fichier> [--sans-zone] [--biome=ancien|nouveau]")
		quit(2)
		return
	m = SCENE.instantiate()
	m.set_meta("test", true)
	for a in args:
		if a.begins_with("--biome="):
			m.set_meta("biome", a.substr(8))
	root.add_child(m)
	for i in 5:
		await process_frame
	var sig := _signature()
	var nb := 0
	for cle in sig["multimesh"]:
		nb += sig["multimesh"][cle].size()
		print("  mesh ", cle.left(60), " : ", sig["multimesh"][cle].size(), " instances")
	print("  pierres : ", sig["pierres"].size(), "  instances MultiMesh : ", nb)
	if mode == "ecrire":
		var f := FileAccess.open(fichier, FileAccess.WRITE)
		f.store_var(sig)
		f.close()
		print("OK signature écrite : ", fichier)
		quit(0)
		return
	var ref: Dictionary = FileAccess.open(fichier, FileAccess.READ).get_var()
	var a := sig
	var b := ref
	if args.has("--sans-zone"):
		a = _filtrer(sig)
		b = _filtrer(ref)
	var erreurs := 0
	if a["hauteurs"] != b["hauteurs"]:
		erreurs += 1
		print("ECART hauteurs")
	if a["pierres"] != b["pierres"]:
		erreurs += 1
		print("ECART pierres")
	var cles := {}
	for c in a["multimesh"]:
		cles[c] = true
	for c in b["multimesh"]:
		cles[c] = true
	for c in cles:
		if not _memes_transforms(a["multimesh"].get(c, []), b["multimesh"].get(c, [])):
			erreurs += 1
			print("ECART multimesh ", c)
	print("OK : signature identique" if erreurs == 0 else "ECHEC : %d écart(s)" % erreurs)
	quit(0 if erreurs == 0 else 1)
