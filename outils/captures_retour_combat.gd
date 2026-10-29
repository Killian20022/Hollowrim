extends SceneTree
## Captures du RETOUR DE COMBAT (lot L6) : barre + nom + statut, chiffres de dégâts, mort d'un squelette (os qui jaillissent).
##   godot --path . --script res://outils/captures_retour_combat.gd -- --nouvelle --test --sortie=<dossier>
## Fenêtre 960x540 (lancer par godot_slot.sh : hors écran).

const SCENE := preload("res://scenes/test_degats.tscn")
const HUD := preload("res://scripts/hud.gd")
const FAUX_JOUEUR := """extends CharacterBody3D
var competences := Competences.new()
var ennemi_vise: Node = null
var en_dialogue := false
var mort := false
var camera: Camera3D
var inventaire = null
"""
var sc: Node3D
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _f(n: int) -> void:
	for i in n:
		await process_frame

func _photo(nom: String) -> void:
	await _f(2)
	root.get_texture().get_image().save_png("%s/%s.png" % [sortie, nom])

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	DirAccess.make_dir_recursive_absolute(sortie)
	DisplayServer.window_set_size(Vector2i(960, 540))
	root.size = Vector2i(960, 540)
	RetourImpact.muet = true
	RetourImpact.arret_actif = false
	ChiffresDegats.force_actif = 1
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _f(10)
	var j: CharacterBody3D = sc.joueur
	var sq: CharacterBody3D = sc.creer_draugr("squelette", Vector3(0, 0.05, 0.5), {"ident": "cap_sq"})
	await _f(10)
	sq.set_physics_process(false)
	j.global_position = Vector3(0, 0, 30.0)
	var cam := Camera3D.new()
	cam.fov = 60.0
	sc.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(1.0, 1.35, 3.0)
	cam.look_at(Vector3(0, 1.0, 0.5))
	var fj := CharacterBody3D.new()
	var scr := GDScript.new()
	scr.source_code = FAUX_JOUEUR
	scr.reload()
	fj.set_script(scr)
	sc.add_child(fj)
	fj.set("camera", cam)
	var hud := Control.new()
	hud.set_script(HUD)
	hud.joueur = fj
	sc.add_child(hud)
	await _f(3)
	fj.set("ennemi_vise", sq)
	sq.vie = 5000.0
	Statuts.de(sq).appliquer("brulure", 8.0, 1.0)
	sq.recevoir_coup(23.0, sq.global_position + Vector3(0, 0, 2.0), false, {"attaque": "legere", "zone": "torse", "point": sq.global_position + Vector3(0, 1.2, 0.2)})
	await _f(8)
	await _photo("1_barre_nom_statut_chiffre")
	sq.recevoir_coup(41.0, sq.global_position + Vector3(0, 0, 2.0), true, {"attaque": "lourde", "zone": "torse", "point": sq.global_position + Vector3(0, 1.2, 0.2)})
	await _f(10)
	await _photo("2_coup_lourd")
	sq.vie = 1.0
	sq.recevoir_coup(500.0, sq.global_position + Vector3(0, 0, 2.0), true, {"attaque": "lourde", "zone": "torse", "point": sq.global_position + Vector3(0, 1.2, 0.2)})
	for k in [6, 12, 20, 40]:
		await _f(k)
		await _photo("3_mort_%02d" % k)
	await _f(120)
	await _photo("4_os_au_sol_3s")
	await _f(600)
	await _photo("5_os_au_sol_13s")
	print("CAPTURES_RETOUR_COMBAT fini : ", sortie)
	quit()
