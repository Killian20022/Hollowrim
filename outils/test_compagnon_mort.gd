extends SceneTree
## Test headless du compagnon d'Eirik mort (crypte du tertre, salle barricadée, interaction note_compagnon_2) :
##  - corps en armure MAISON (GardeMaison, ensemble fer, sans livrée ni arme), pas l'ancien Guerrier ;
##  - ALLONGÉ (pose Death01 figée) : tête et bassin près du sol, corps étalé à l'horizontale, bras pas en croix ;
##  - aucune pièce visible SANS matière (le « blanc » de la cotte de mailles : ArmureVisible remettait material_override à null) ;
##  - posé sur le sol (aucun os sous le sol ni à plus de 0,6 m), interaction « Fouiller le corps » à portée du torse ;
##  - sang séché sous le corps (la torche éteinte est fondue dans le décor : vérifiée en image). Texte de la fouille : test_quetes.
## godot --headless --path . --script res://outils/test_compagnon_mort.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 10:
		await process_frame
	var c0 := m.tertre.crypte.find_child("CorpsCompagnon", true, false) as Node3D
	var rd0: Ragdoll = c0.get_node_or_null("Ragdoll") if c0 else null
	if rd0 != null:      # le corps finit sa chute en ragdoll puis est figé
		var t0 := Time.get_ticks_msec()
		for i in 600:
			await physics_frame
			if rd0.est_fige():
				break
		print("      ragdoll figé : %s après %d images de physique" % [rd0.est_fige(), Engine.get_physics_frames()])
	var crypte: Node3D = m.tertre.crypte
	var c := crypte.find_child("CorpsCompagnon", true, false) as Node3D
	_verif(c != null, "corps du compagnon présent dans la crypte")
	if c == null:
		quit(1)
		return
	_verif(c.has_meta("garde_maison") and not c.has_meta("livree_garde"), "corps en armure maison (GardeMaison), sans livrée")
	var portees: Dictionary = c.get_meta(GardeMaison.META, {})
	_verif(String(portees.get("torse", "")) == "cuirasse_fer", "cuirasse de fer portée (%s)" % [portees])
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	sq.force_update_all_bone_transforms()
	var rd: Ragdoll = c.get_node_or_null("Ragdoll")
	_verif(rd == null or rd.est_fige(), "corps figé après sa chute (ragdoll endormi)")
	var sol_y := c.global_position.y
	var gp := func(nom: String) -> Vector3:
		if rd != null and rd.pose_monde(nom) != null:
			return (rd.pose_monde(nom) as Transform3D).origin      # os physique figé : pose affichée
		return sq.global_transform * sq.get_bone_global_pose(sq.find_bone(nom)).origin
	var tete: Vector3 = gp.call("Head")
	var bassin: Vector3 = gp.call("pelvis")
	var pied: Vector3 = (gp.call("foot_l") + gp.call("foot_r")) * 0.5
	var main_l: Vector3 = gp.call("hand_l")
	var main_r: Vector3 = gp.call("hand_r")
	print("      tête %.2f m, bassin %.2f m au-dessus du sol ; tête-pieds à l'horizontale %.2f m ; mains %.2f / %.2f m ; écart des mains %.2f m"
		% [tete.y - sol_y, bassin.y - sol_y, Vector2(tete.x - pied.x, tete.z - pied.z).length(), main_l.y - sol_y, main_r.y - sol_y, main_l.distance_to(main_r)])
	print("      repère du corps : main_l %s main_r %s tête %s bassin %s" % [c.to_local(main_l), c.to_local(main_r), c.to_local(tete), c.to_local(bassin)])
	_verif(tete.y - sol_y < 0.45, "tête au sol (< 0,45 m) : allongé, pas debout")
	_verif(bassin.y - sol_y < 0.40, "bassin au sol (< 0,40 m)")
	_verif(Vector2(tete.x - pied.x, tete.z - pied.z).length() > 1.0, "corps étalé à l'horizontale (tête-pieds > 1 m)")
	_verif(main_l.distance_to(main_r) < 1.55, "bras pas en croix (écart des mains < 1,55 m, pose de repos : ~1,7 m)")
	var bas := INF
	var haut := -INF
	var plus_haut := ""
	var noms: Array = rd.os.keys() if rd != null else Array(range(sq.get_bone_count())).map(func(i: int) -> String: return sq.get_bone_name(i))
	for nom: String in noms:      # ragdoll : les os physiques (les phalanges suivent leur main)
		var y: float = (gp.call(nom) as Vector3).y - sol_y
		if y > haut:
			plus_haut = nom
		bas = minf(bas, y)
		haut = maxf(haut, y)
	_verif(bas > -0.08 and haut < 0.7, "os entre le sol et 0,7 m (%.2f .. %.2f, plus haut : %s)" % [bas, haut, plus_haut])
	var vis: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if _visible_sous(mi, c):
			vis.append(String(mi.name))
	print("      maillages visibles : ", vis)
	var blancs: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not _visible_sous(mi, c) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if mi.material_override == null and mi.get_surface_override_material(s) == null and mi.mesh.surface_get_material(s) == null:
				blancs.append("%s:%d" % [mi.name, s])
	_verif(blancs.is_empty(), "aucune pièce visible sans matière (blanc) %s" % [blancs])
	var dj: CrypteDonjon = m.tertre.donjon
	var it_pos := Vector3.INF
	for it: Dictionary in dj.interactions:
		if String(it.get("id", "")) == "note_compagnon_2":
			it_pos = it["pos"]
	_verif(it_pos != Vector3.INF, "interaction « Fouiller le corps » (note_compagnon_2) présente")
	var torse_local := crypte.to_local((tete + bassin) * 0.5)
	if it_pos != Vector3.INF:
		var dd := Vector2(it_pos.x - torse_local.x, it_pos.z - torse_local.z).length()
		_verif(dd < 0.9, "interaction à portée du torse (%.2f m)" % dd)
	var taches := crypte.find_children("SangSeche*", "MeshInstance3D", true, false)
	_verif(taches.size() >= 2, "sang séché sous le corps (%d)" % taches.size())

	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)

## Visible dans le corps (la crypte est cachée tant que le joueur est dehors : is_visible_in_tree serait faux partout).
func _visible_sous(n: Node, haut: Node) -> bool:
	var x: Node = n
	while x != null and x != haut:
		if x is Node3D and not (x as Node3D).visible:
			return false
		x = x.get_parent()
	return true
