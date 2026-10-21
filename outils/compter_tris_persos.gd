extends SceneTree
## Triangles et surfaces (≈ appels de dessin) de chaque personnage vivant, corps Humain (défaut) contre kit Personnage (--persos-kit).
##   godot --headless --path . --script res://outils/compter_tris_persos.gd -- --nouvelle
const VILL := preload("res://scripts/villageois.gd")
const GJ := preload("res://scripts/grotte_jeu.gd")
const CJ := preload("res://scripts/corps_joueur.gd")

func _init() -> void:
	_lancer.call_deferred()

func _compte(n: Node) -> Vector2i:
	var tris := 0
	var surf := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			surf += 1
			var a := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return Vector2i(tris, surf)

func _ligne(nom: String, h: Node3D, k: Node3D, totaux: Array) -> void:
	var a := _compte(h)
	var b := _compte(k)
	totaux[0] += a.x
	totaux[1] += a.y
	totaux[2] += b.x
	totaux[3] += b.y
	print("PERSO %-12s humain %5d tris %3d surfaces | kit %5d tris %3d surfaces | x%.1f" % [nom, a.x, a.y, b.x, b.y, float(a.x) / maxf(b.x, 1.0)])
	h.free()
	k.free()

func _lancer() -> void:
	var totaux := [0, 0, 0, 0]
	for id: String in VILL.APPARENCES:
		_ligne(id, Humain.creer(VILL.APPARENCES[id]), Personnage.creer(PersoDefs.villageois(id)), totaux)
	for k in 5:
		var kit: Node3D = Personnage.creer(PersoDef.depuis(GJ.HRAFN)) if k == 4 else Personnage.creer(PersoDefs.bandit(k))
		_ligne("bandit_%d" % k if k < 4 else "hrafn", Humain.creer(GJ.apparence_humain(k)), kit, totaux)
	_ligne("joueur", Humain.creer(CJ.APPARENCE), Personnage.creer(PersoDefs.joueur()), totaux)
	print("TOTAL humain %d tris %d surfaces | kit %d tris %d surfaces" % totaux)
	quit(0)
