extends SceneTree
## Film des MORTS d'araignée des cavernes (BeteQuat, retours exe 5) : quatre plans de ~4 s dans l'arène de neige du test
## (scenes/test_troll_mage.tscn, mode --test), caméra d'observateur fixe :
##   1. coups légers   2. coup lourd   3. boule de feu (DegatsCombat.appliquer, info de sort)   4. coup lourd sur une PENTE de 24°
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_mort_araignee.gd -- --nouvelle --test --debug=0
## (fenêtre hors écran via godot_slot.sh). Chaque plan imprime `SEGMENT <nom> <image début> <image fin>` et, à la fin du plan, la
## mesure du corps : `CORPS <nom> haut=<hauteur du bassin au-dessus du sol> glisse=<m> bouge=<m dans la dernière seconde>`.

const SCENE := preload("res://scenes/test_troll_mage.tscn")
const BETE := preload("res://scripts/bete_quat.gd")
const PENTE_DEG := 24.0
const PENTE_POS := Vector3(14.0, 0.0, -6.0)

var sc: Node3D
var j: CharacterBody3D
var cam: Camera3D

func _init() -> void:
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _pente() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(8.0, 0.4, 8.0)
	cs.shape = b
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	mi.mesh = bm
	var tex := Palette.tex("sol_pierre_test", ["#2c2a2a", "#3c3836", "#4e4844", "#625a54"], 4, 0.5)
	var m := Palette.materiau(tex, Vector2(4, 4))
	m.set_shader_parameter("tex_neige", tex)
	mi.material_override = m
	sb.add_child(mi)
	sc.add_child(sb)
	sb.position = PENTE_POS + Vector3(0, 1.4, 0)
	sb.rotation.x = deg_to_rad(PENTE_DEG)       # descend vers +Z (vers la caméra)

## Hauteur du sol sous un point (rayon vertical, hors capsules).
func _sol(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p - Vector3(0, 6, 0))
	q.collision_mask = 1
	var ex: Array[RID] = []
	for e in get_nodes_in_group("ennemis"):
		ex.append((e as CollisionObject3D).get_rid())
	ex.append(j.get_rid())
	q.exclude = ex
	var r := root.get_world_3d().direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) if not r.is_empty() else 0.0

func _bassin(a: Node3D) -> Vector3:
	var sq := a.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return a.global_position
	var meilleur := -1
	for i in sq.get_bone_count():
		var n := sq.get_bone_name(i).to_lower()
		if n.contains("body") or n.contains("hip") or n.contains("pelvis") or n.contains("root") or n.contains("spine"):
			meilleur = i
			break
	if meilleur < 0:
		meilleur = 0
	return sq.to_global(sq.get_bone_global_pose(meilleur).origin)

func _plan(nom: String, pos: Vector3, lacet: float, cam_decal: Vector3, frappe: Callable) -> void:
	j.global_position = Vector3(0, 0, 40.0)
	var ar: CharacterBody3D = sc.creer_ennemi(BETE, pos, {"ident": "araignee_" + nom, "espece": "araignee"})
	ar.rotation.y = lacet
	await _images(40)                  # elle se pose (gravité)
	var vise := ar.global_position + Vector3(0, 0.35, 0)
	cam.global_position = vise + cam_decal
	cam.look_at(vise, Vector3.UP)
	var i0 := Engine.get_frames_drawn()
	await _images(15)
	var depart := ar.global_position
	j.global_position = ar.global_position + Vector3(sin(lacet), 0, cos(lacet)) * 1.7
	j.global_position.y = ar.global_position.y
	await frappe.call(ar)
	var t := 0
	while ar.vivant() and t < 60:
		await frappe.call(ar)
		t += 1
	j.global_position = Vector3(0, 0, 40.0)
	await _images(60)
	var p_avant := _bassin(ar.modele)
	await _images(30)
	var p_apres := _bassin(ar.modele)
	var b := _bassin(ar.modele)
	print("CORPS %s haut=%.2f glisse=%.2f bouge=%.3f anim=%s" % [nom, b.y - _sol(b), Vector2(ar.global_position.x - depart.x, ar.global_position.z - depart.z).length(),
		p_apres.distance_to(p_avant), ar.anim.current_animation])
	var i1 := Engine.get_frames_drawn()
	print("SEGMENT %s %d %d" % [nom, i0, i1])
	ar.queue_free()
	for n in get_nodes_in_group("butin"):
		n.queue_free()

func _coup(ar: Node, attaque: String) -> void:
	sc.frapper(ar, attaque)
	await _images(14)

func _feu(ar: Node) -> void:
	var s: DonneesSort = load("res://data/sorts/boule_feu.tres")
	var o := j.global_position + Vector3(0, 1.4, 0)
	var p: Vector3 = (ar as Node3D).global_position + Vector3(0, 0.4, 0)
	var info := {"type": s.type_degats, "ecole": s.ecole, "attaque": "sort", "sort": s.id, "stagger": s.stagger, "point": p,
		"direction": (p - o).normalized(), "statut": s.statut, "duree_statut": s.duree_statut, "puissance_statut": s.puissance_statut,
		"drain": s.drain, "continu": false}
	DegatsCombat.appliquer(ar, 26.0, o, true, info)
	await _images(18)

func _go() -> void:
	RetourImpact.muet = true
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _images(10)
	j = sc.joueur
	cam = sc.obs
	cam.fov = 55.0
	_pente()
	await _images(5)
	var cote := Vector3(2.2, 1.0, 1.6)
	await _plan("coup_leger", Vector3(-4, 0.05, -4), 0.5, cote, func(a: Node) -> void: await _coup(a, "legere"))
	await _plan("coup_lourd", Vector3(-4, 0.05, -4), 0.5, cote, func(a: Node) -> void: await _coup(a, "lourde"))
	await _plan("sort_feu", Vector3(-4, 0.05, -4), 0.5, cote, _feu)
	await _plan("pente", PENTE_POS + Vector3(0, 3.0, 0), 0.0, Vector3(2.6, 1.0, 2.0), func(a: Node) -> void: await _coup(a, "lourde"))
	print("FILM fini")
	quit(0)
