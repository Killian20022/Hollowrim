extends SceneTree
## Planche du corps du compagnon d'Eirik (crypte_donjon.gd COMPAGNON), hors du monde : allongé (Death01 figé), vu de dessus et de 3/4,
## puis chaque maillage visible seul (repérer une pièce sans matière ou mal teinte). Sortie : <sortie>/corps_*.png
##   godot --path . --script res://outils/planche_compagnon_mort.gd -- --sortie=<dossier absolu> [--compagnon-ancien]
const W := 640
const H := 360

var sv: SubViewport
var cam: Camera3D

func _initialize() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.split("=", true, 1)[1]
	return defaut

func _go() -> void:
	var sortie := _arg("sortie", "C:/Users/lopezk19/Jeux/rendus/soir_2026-11-25/compagnon_mort/planche")
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	sol.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.25, 0.25, 0.28)
	sol.material_override = ms
	sv.add_child(sol)
	var lum := DirectionalLight3D.new()
	lum.rotation_degrees = Vector3(-55, 30, 0)
	lum.light_energy = 1.2
	sv.add_child(lum)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0.6, 1.4, 0.8)
	omni.light_color = Color(1.0, 0.7, 0.4)
	omni.light_energy = 1.5
	omni.omni_range = 4.0
	sv.add_child(omni)
	var c: Node3D
	if OS.get_cmdline_user_args().has("--compagnon-ancien"):
		c = PnjNordique.creer("garde")
	else:
		c = GardeMaison.creer(CrypteDonjon.COMPAGNON)
	sv.add_child(c)
	(load("res://scripts/draugr.gd") as GDScript).call("figer_pose_allongee", c)
	cam = Camera3D.new()
	cam.fov = 60.0
	sv.add_child(cam)
	for i in 6:
		await process_frame
	await _cliche(sortie + "/corps_dessus.png", Vector3(0, 2.6, -0.6), Vector3(0, 0, -0.7))
	await _cliche(sortie + "/corps_34.png", Vector3(1.6, 1.4, 0.6), Vector3(0, 0.1, -0.7))
	var visibles: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			visibles.append(mi)
	for mi: MeshInstance3D in visibles:
		for autre: MeshInstance3D in visibles:
			autre.visible = autre == mi
		await _cliche(sortie + "/seul_%s.png" % mi.name, Vector3(0, 2.6, -0.6), Vector3(0, 0, -0.7))
	for autre: MeshInstance3D in visibles:
		autre.visible = true
	print("PLANCHE OK ", sortie)
	quit(0)

func _cliche(chemin: String, oeil: Vector3, cible: Vector3) -> void:
	cam.position = oeil
	cam.look_at(cible, Vector3.UP if absf((cible - oeil).normalized().y) < 0.98 else Vector3.FORWARD)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(chemin)
