extends SceneTree
## Épées longues (assets/modeles/armes/epees/*.glb) : nœuds prise / garde / pointe, repère et échelle communs avec
## epee_nordique.glb (+Y lame, +X quillons, poing à y = 0,03), budget de triangles, noms de matériaux, habillage PS1.
##   godot --headless --path . --script outils/test_epees_longues.gd -- --nouvelle
const NOMS_MATS := ["lame", "lame_or", "fer", "or", "cuir", "gemme", "rubis", "verre", "emeraude", "obsidienne", "veine"]
const TRIS_MAX := 450
const MILIEU_POIGNEE := 0.03   # scripts/mains.gd

var _echecs := 0

func _verifier(ok: bool, msg: String) -> void:
	if not ok:
		_echecs += 1
		print("ÉCHEC : ", msg)

## Boîte, triangles et étendue en y par matériau, dans le repère de la racine.
func _mesurer(racine: Node3D) -> Dictionary:
	var boite := AABB()
	var premier := true
	var tris := 0
	var par_mat := {}
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		var xf := racine.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var mat := mi.mesh.surface_get_material(s)
			var nom := mat.resource_name.get_slice(".", 0) if mat else "?"
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx.size() > 0 else vs.size()) / 3
			var e: Vector2 = par_mat.get(nom, Vector2(99, -99))
			for v in vs:
				var p := xf * v
				e = Vector2(minf(e.x, p.y), maxf(e.y, p.y))
				if premier:
					boite = AABB(p, Vector3.ZERO)
					premier = false
				else:
					boite = boite.expand(p)
			par_mat[nom] = e
	return {"boite": boite, "tris": tris, "mats": par_mat}

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var ref: Node3D = load("res://assets/modeles/joueur/epee_nordique.glb").instantiate()
	root.add_child(ref)
	var mr := _mesurer(ref)
	var br: AABB = mr["boite"]
	print("référence epee_nordique : y [%.3f ; %.3f]  x ±%.3f  z ±%.3f  cuir y %s  %d tris" % [br.position.y, br.end.y, br.size.x * 0.5, br.size.z * 0.5, mr["mats"].get("cuir"), mr["tris"]])
	for v: String in EpeesLongues.VARIANTES:
		var chemin: String = EpeesLongues.DOSSIER + v + ".glb"
		_verifier(ResourceLoader.exists(chemin), "%s introuvable" % chemin)
		if not ResourceLoader.exists(chemin):
			continue
		var e := EpeesLongues.instancier(v)
		root.add_child(e)
		var m := _mesurer(e)
		var b: AABB = m["boite"]
		var reps := {}
		for n in ["prise", "garde", "pointe"]:
			var r := EpeesLongues.repere(e, n)
			_verifier(r != null, "%s : nœud « %s » absent" % [v, n])
			reps[n] = (e.global_transform.affine_inverse() * r.global_transform).origin if r else Vector3.ZERO
		var longueur := b.size.y
		print("%-10s longueur %.3f m  y [%.3f ; %.3f]  x ±%.3f  z ±%.3f  %3d tris  prise %s  garde %s  pointe %s  mats %s" % [
			v, longueur, b.position.y, b.end.y, b.size.x * 0.5, b.size.z * 0.5, m["tris"], reps["prise"], reps["garde"], reps["pointe"], m["mats"].keys()])
		# échelle : épée longue de 1,0 à 1,16 m, lame le long de +Y, quillons en X, mince en Z
		_verifier(longueur > 1.0 and longueur < 1.16, "%s : longueur %.3f hors [1,0 ; 1,16]" % [v, longueur])
		_verifier(b.size.x < 0.32 and b.size.x > 0.15, "%s : envergure de garde %.3f" % [v, b.size.x])
		_verifier(b.size.z < 0.07, "%s : épaisseur %.3f" % [v, b.size.z])
		_verifier(absf(b.get_center().x) < 0.005 and absf(b.get_center().z) < 0.005, "%s : épée décentrée %s" % [v, b.get_center()])
		# repère : poing à y = MILIEU_POIGNEE sur l'axe, dans le cuir comme l'épée nordique ; garde au-dessus ; pointe = haut de la boîte
		var p: Vector3 = reps["prise"]
		_verifier(p.distance_to(Vector3(0, MILIEU_POIGNEE, 0)) < 0.002, "%s : prise %s ≠ (0 ; %.2f ; 0)" % [v, p, MILIEU_POIGNEE])
		var cuir: Vector2 = m["mats"].get("cuir", Vector2.ZERO)
		_verifier(cuir.x < p.y - 0.05 and cuir.y > p.y + 0.04, "%s : la poignée %s n'entoure pas le poing" % [v, cuir])
		_verifier(reps["garde"].y > 0.08 and reps["garde"].y < 0.11, "%s : garde à y = %.3f" % [v, reps["garde"].y])
		_verifier(absf(reps["pointe"].y - b.end.y) < 0.002 and reps["pointe"].y > 0.9, "%s : pointe %.3f ≠ bout de lame %.3f" % [v, reps["pointe"].y, b.end.y])
		_verifier(b.end.y > br.end.y, "%s : plus courte que l'épée nordique" % v)
		_verifier(m["tris"] <= TRIS_MAX, "%s : %d triangles > %d" % [v, m["tris"], TRIS_MAX])
		# matériaux : noms connus, tous remplacés par un ShaderMaterial PS1
		for nom in m["mats"]:
			_verifier(nom in NOMS_MATS, "%s : matériau inconnu « %s »" % [v, nom])
		for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				_verifier(mi.get_surface_override_material(s) is ShaderMaterial, "%s/%s : surface %d non habillée" % [v, mi.name, s])
	print("test_epees_longues : %s (ECHECS : %d)" % ["OK" if _echecs == 0 else "ÉCHEC", _echecs])
	quit(1 if _echecs > 0 else 0)
