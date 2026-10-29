extends SceneTree
## Lot L2 « Or lisible et pièces qui jaillissent » (docs/INSPIRATION_IGNITE.md §2.7, §2.18) :
##   - pièce : maillage octogonal 64 triangles au shader ps1 (Palette.materiau), plus de BoxMesh ni de cube qui flotte ;
##   - corps : les pièces jaillissent, retombent AU SOL autour du corps, attendent ; versées UNE fois quand le joueur passe à
##     < 1,5 m, puis aspirées vers lui et retirées ; aucun double ; même position = mêmes points de chute (graine propre) ;
##   - coffre de la crypte : contenu versé à l'ouverture (pièces exactes), gerbe partie de l'intérieur de la cuve, terminée seule,
##     pas de double ; or_tas v3 présent dans le .dat (matières or + noir).
##   godot --headless --path . --script res://outils/test_butin_l2.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await process_frame

func _gerbe(pos: Vector3, contenu: Dictionary) -> Node3D:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = m.joueur
	b.hud = m.hud
	b.contenu = contenu
	m.add_child(b)
	b.global_position = pos
	return b

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var j: CharacterBody3D = m.joueur
	# --- pièce
	var mesh: ArrayMesh = BUTIN.maillage()
	var tris := 0
	for s in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_verif(tris == 64, "pièce : %d triangles (octogone, face + bord + tranche)" % tris)
	var mat: Material = BUTIN._materiau("piece")
	_verif(mat is ShaderMaterial and (mat as ShaderMaterial).shader == Palette.PS1, "pièce : shader ps1 (Palette.materiau)")
	# --- corps : chute au sol, attente, versement unique à 1,5 m
	var x0 := 10.0
	var z0 := 10.0
	j.global_position = Vector3(x0, m.hauteur(x0, z0) + 0.1, z0)
	await _attendre(0.3)
	var pos := Vector3(x0 + 5.0, m.hauteur(x0 + 5.0, z0), z0)
	var or0: int = j.inventaire.pieces
	var os0: int = j.inventaire.nombre("os_draugr")
	var b := _gerbe(pos, {"pieces": 23, "os_draugr": 2})
	await _attendre(0.05)
	var n: int = b.pieces_visibles()
	_verif(n == 11, "corps : %d pièces jaillissent (4 + 23/3)" % n)
	var boites := 0
	for c in b.find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).mesh is BoxMesh:
			boites += 1
	_verif(boites == 0, "corps : aucune BoxMesh (bourse v1 retirée)")
	var hauts: Array[float] = []
	for c in b.get_children():
		if c is MeshInstance3D:
			hauts.append((c as MeshInstance3D).global_position.y - pos.y)
	await _attendre(0.25)
	var maxi := 0.0
	for c in b.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			maxi = maxf(maxi, (c as MeshInstance3D).global_position.y - pos.y)
	_verif(maxi > 0.55, "corps : les pièces SAUTENT (%.2f m au-dessus du sol à 0,3 s)" % maxi)
	await _attendre(1.2)
	var pts: Array[Vector3] = b.points_de_chute()
	var au_sol := true
	var dmax := 0.0
	for c in b.get_children():
		if c is MeshInstance3D:
			var p: Vector3 = (c as MeshInstance3D).global_position
			au_sol = au_sol and absf(p.y - m.hauteur(p.x, p.z)) < 0.12
			dmax = maxf(dmax, Vector2(p.x - pos.x, p.z - pos.z).length())
	_verif(au_sol and dmax < 1.0 and dmax > 0.3, "corps : pièces retombées au sol autour du corps (jusqu'à %.2f m)" % dmax)
	_verif(j.inventaire.pieces == or0 and b.pieces_visibles() == 11, "corps : joueur à 5 m, rien versé, les pièces attendent")
	j.global_position = pos + Vector3(-1.2, 0.1, 0)
	await _attendre(0.1)
	_verif(j.inventaire.pieces == or0 + 23 and j.inventaire.nombre("os_draugr") == os0, "corps : à 1,2 m, +23 pièces versées (%d → %d), les os restent dans le corps (L3)" % [or0, j.inventaire.pieces])
	await _attendre(2.2)
	_verif(is_instance_valid(b) and b.pieces_visibles() == 0 and b.a_fouille(), "corps : pièces aspirées, le corps reste à fouiller (objets)")
	b.fouiller()
	m.fenetre_butin.tout_prendre()
	_verif(j.inventaire.nombre("os_draugr") == os0 + 2, "corps : fouillé, +2 os")
	await _attendre(0.1)
	_verif(not is_instance_valid(b), "corps : tout pris, gerbe retirée")
	await _attendre(0.5)
	_verif(j.inventaire.pieces == or0 + 23, "corps : aucune pièce ramassée en double")
	# même position, même nombre : mêmes points de chute
	j.global_position = Vector3(x0, m.hauteur(x0, z0) + 0.1, z0)
	var b2 := _gerbe(pos, {"pieces": 23})
	await _attendre(0.05)
	_verif(b2.points_de_chute() == pts, "graine de gerbe : mêmes points de chute pour la même position")
	b2.queue_free()
	# --- coffre de la crypte
	var t: Node3D = m.tertre
	t.attendre_donjon()
	await _attendre(0.2)
	var attendu := {}
	for it: Dictionary in t.donjon.interactions:
		if it["id"] == "cof_prep":
			attendu = it["butin"]
	var avant: int = j.inventaire.pieces
	(t._inter["cof_prep"] as Node3D).parler()
	await _attendre(0.05)
	m.fenetre_butin.fermer()
	var g: Node3D = null
	for c in t.crypte.get_children():
		if c.get_script() == BUTIN:
			g = c
	_verif(j.inventaire.pieces == avant + int(attendu.get("pieces", 0)), "coffre : %d pièces versées à l'ouverture" % int(attendu.get("pieces", 0)))
	var lp: Vector3 = Vector3.ZERO
	var cv: CoffreCouvercle = t._couvercles.get("cof_prep")
	if cv != null:
		lp = (cv.get_parent() as Node3D).to_global(cv.lueur_pos)
	_verif(g != null and g.deja_verse and g.depart_global.distance_to(lp) < 0.01, "coffre : gerbe partie de l'intérieur de la cuve")
	_verif(g != null and g.process_mode == Node.PROCESS_MODE_ALWAYS, "coffre : la gerbe continue sous la fenêtre de butin (pause)")
	await _attendre(3.0)
	_verif(g == null or not is_instance_valid(g), "coffre : gerbe terminée et retirée (pièces aspirées)")
	_verif(j.inventaire.pieces == avant + int(attendu.get("pieces", 0)), "coffre : pas de double après l'aspiration")
	# --- or_tas v3 dans le .dat
	var f := FileAccess.open("res://assets/crypte/modules/objets_donjon.dat", FileAccess.READ)
	var noms := []
	var nb := f.get_32()
	for i in nb:
		var l := f.get_8()
		var nom := f.get_buffer(l).get_string_from_utf8()
		var nv := f.get_32()
		f.seek(f.get_position() + nv * 28)
		noms.append(nom)
	for v in "abc":
		_verif(noms.has("or_tas_%s__or" % v) and noms.has("or_tas_%s__noir" % v), "or_tas_%s : pièces (or) + noyau noir (creux)" % v)
	print("ECHECS : %d" % _echecs)
	quit(_echecs)
