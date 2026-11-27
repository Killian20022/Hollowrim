extends SceneTree
## GRAND MARTEAU, garde en 3e personne (défaut C de l'exe 8) : GROS PLANS de la main gauche sur le manche, en jeu (corps du joueur,
## CorpsCoupsTps), garde tenue puis coup bloqué, 3 angles (face, côté gauche, dessus). Fenêtre HORS ÉCRAN (godot_slot).
##   godot --path . --resolution 1280x720 --script res://outils/gros_plan_main_gauche_gm.gd -- --nouvelle --sortie=<dossier Windows>
##         [--nom=apres] [--ik-gauche-garde-ancien]  (A/B : la main gauche d'avant)
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _images(n: int, garde: bool) -> void:
	for i in n:
		if garde:
			mains.entrees.forcer_garde(0.2)
		j.vigueur = j.vigueur_max
		mains.avancer(DT)
		await process_frame

func _go() -> void:
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	if s.get("hud") != null:
		s.hud.visible = false
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("mur") is Node3D:
		(s.mur as Node3D).visible = false
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.placer_joueur(Vector3(0, 0, 0), 0.0, 0.0)
	j.basculer_vue(true)
	mains.equipement.equiper("droite", CatalogueArmes.donnees("grand_marteau"))
	await _images(40, false)
	var corps: Node3D = j.get("corps")
	var sq: Skeleton3D = corps.modele.find_child("Skeleton3D", true, false)
	var bg := BoneAttachment3D.new()
	bg.bone_name = "hand_l"
	sq.add_child(bg)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	var sortie := _arg("sortie", "user://gros_plan_gm")
	var nom := _arg("nom", "x")
	await _images(80, true)   # garde tenue
	await _photos(cam, bg, sortie, nom + "_tenue")
	var origine := j.global_position + (-j.global_transform.basis.z) * 2.0
	mains.defendre(10.0, origine, true)
	await _images(12, true)   # coup bloqué, au plus fort de l'encaisse
	await _photos(cam, bg, sortie, nom + "_encaisse")
	print("FIN_GROS_PLAN")
	quit(0)

func _photos(cam: Camera3D, bg: Node3D, sortie: String, nom: String) -> void:
	var p := bg.global_position
	var av := -j.global_transform.basis.z
	var dr := j.global_transform.basis.x
	var vues := {"face": av * 0.75 + Vector3.UP * 0.1, "gauche": -dr * 0.75 + av * 0.2 + Vector3.UP * 0.1, "dessus": Vector3.UP * 0.7 + av * 0.3}
	for v in vues:
		cam.global_position = p + vues[v]
		cam.look_at(p, Vector3.UP if v != "dessus" else av)
		mains.entrees.forcer_garde(0.2)
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(sortie.path_join("%s_%s.png" % [nom, v]))
