extends SceneTree
## Captures des finitions butin : fenêtre de butin (poids du sac), caisse de la grotte avant / après la casse.
##   godot --path . --script res://outils/capture_finitions_butin.gd -- --nouvelle --sortie=<dossier>
const SCENE := preload("res://scenes/foret_test.tscn")
var _dossier := ""

func _init() -> void:
	_go.call_deferred()

func _att(n: int) -> void:
	for i in n:
		await process_frame

func _cap(nom: String) -> void:
	await _att(6)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_dossier)
	root.get_texture().get_image().save_png(_dossier.path_join(nom))
	print("CAPTURE ", nom)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_dossier = a.substr(9)
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _att(20)
	var j: CharacterBody3D = m.joueur
	j.inventaire.ajouter("minerai_fer", 6)
	j.inventaire.ajouter("potion_soin", 3)
	var fb: FenetreButin = m.fenetre_butin
	fb.ouvrir("Draugr ancien", {"collier_or": 1, "potion_soin_forte": 1, "os_draugr": 2, "minerai_fer": 3}, 14)
	await _att(10)
	await _cap("1_fenetre_butin_poids_sac.png")
	fb.fermer()
	await _att(5)
	var ga: Node3D = m.grotte_acces
	ga.attendre_exterieur()
	var gr: Grotte = ga.obtenir()
	var cs: Cassable = null
	var k := 0
	for c: Cassable in gr.find_children("*", "Cassable", true, false):
		if c.genre == "caisse" and not c.casse:
			k += 1
			if k == 8:
				cs = c
				break
	if cs == null:
		print("pas de caisse")
		quit(1)
		return
	ga.montrer(true)
	var p := cs.global_position
	var off := Vector3(1.6, 0.0, 1.9)
	j.global_position = p + off + Vector3(0, 0.15, 0)
	j.rotation.y = atan2(off.x, off.z)
	j.tete.rotation.x = -atan2(1.25, off.length())
	j.velocity = Vector3.ZERO
	j.set_physics_process(false)      # figé : le sol de cette zone n'est pas toujours prêt
	await _att(30)
	await _cap("2_caisse_grotte_intacte.png")
	cs.frapper(true, p + Vector3(1.0, 0.8, 1.2))
	await _att(18)
	await _cap("3_caisse_grotte_cassee_vol.png")
	await _att(80)
	await _cap("4_caisse_grotte_cassee_eclats.png")
	quit(0)
