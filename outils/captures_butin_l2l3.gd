extends SceneTree
## Captures des lots L2 / L3 (FENÊTRE hors écran via godot_slot.sh, --fixed-fps 60 : une image = 1/60 s de jeu, séquences
## reproductibles ; --audio-driver Dummy : aucun son chez l'utilisateur).
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_butin_l2l3.gd -- --nouvelle --paisible
##         --sortie=<dossier> [--sequence] [--fenetre] [--res=480x270]
##   --sequence : pièces qui jaillissent du coffre de la salle de préparation (cof_prep) puis d'un corps, images à 0,1 … 1,3 s
##   --fenetre  : fenêtre de butin (coffre puis corps) — lot L3
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/butin_l2l3"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	var f := dossier.path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	var t: Node3D = m.tertre
	t.attendre_donjon()
	t._basculer(true)
	await _images(90)
	m.joueur.mains.visible = false
	m.hud.aide_t = 0.0          # pas de cartouche d'aide des touches sur les captures
	if args.has("sequence"):
		await _sequence(t)
	if args.has("fenetre"):
		await _fenetre(t)
	quit()

## L2 : gerbe du coffre (images à 0,1-1,3 s), puis gerbe d'un corps (au sol, puis aspirée quand on s'approche).
func _sequence(t: Node3D) -> void:
	m._capture_coffres({"face": "cof_prep:1.9:-25"}, "crypte")
	await _images(40)
	await _capturer("gerbe_coffre_0_avant")
	(t._inter["cof_prep"] as Node3D).parler()
	var reperes := [6, 12, 18, 24, 33, 42, 54, 66, 84]
	var k := 0
	for i in 90:
		await process_frame
		if k < reperes.size() and i + 1 == reperes[k]:
			await _capturer("gerbe_coffre_%d_%03dms" % [k + 1, roundi(reperes[k] * 1000.0 / 60.0)])
			k += 1
	# corps : gerbe posée à 3 m devant le joueur, puis on s'approche
	var j: CharacterBody3D = m.joueur
	var avant := -j.global_basis.z
	avant.y = 0.0
	avant = avant.normalized()
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = j
	b.hud = m.hud
	b.contenu = {"pieces": 60}
	b.nom_corps = "Draugr"
	t.crypte.add_child(b)
	b.global_position = Vector3(j.global_position.x, j.global_position.y - 0.1, j.global_position.z) + avant * 2.6
	var reperes2 := [8, 16, 26, 40, 70]
	k = 0
	for i in 72:
		await process_frame
		if k < reperes2.size() and i + 1 == reperes2[k]:
			await _capturer("gerbe_corps_%d_%03dms" % [k + 1, roundi(reperes2[k] * 1000.0 / 60.0)])
			k += 1
	j.global_position += avant * 1.4
	for i in 30:
		await process_frame
		if i == 8 or i == 18 or i == 28:
			await _capturer("gerbe_corps_aspiree_%02d" % i)

## L3 : fenêtre de butin (complétée par le lot L3).
func _fenetre(_t: Node3D) -> void:
	pass
