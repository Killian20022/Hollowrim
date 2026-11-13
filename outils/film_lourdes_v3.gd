extends SceneTree
## Film des armures lourdes v3 en MOUVEMENT (zéro trou : épaules, aisselles, coudes, genoux) : héros en 3e personne, caméra
## de près qui le suit ; marche, course, combo d'épée. Une famille par passage.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_lourdes_v3.gd -- --nouvelle
##         --familles=acier,fer [--nuit]
const DT := 1.0 / 30.0
const FAMILLES := {
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"obsidienne": ["casque_obsidienne", "cuirasse_obsidienne", "gantelets_obsidienne", "bottes_obsidienne"],
	"or": ["casque_or", "cuirasse_or", "gantelets_or", "bottes_or"],
}
const PiecesEssai := preload("res://outils/pieces_essai.gd")
var s: Node
var j: CharacterBody3D
var cam: Camera3D
var l: Label
var suivi := {"os": "spine_02", "deg": 40.0, "dist": 2.0, "dh": 0.15}

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _soleil() -> void:
	var c := cam
	var avant := -c.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01 or s.soleil == null:
		return
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	s.soleil.global_transform = Transform3D(Basis.looking_at((avant + Vector3(0, -0.85, 0)).normalized(), Vector3.UP), s.soleil.global_position)

func _suivre() -> void:
	var sq: Skeleton3D = j.corps.find_child("Skeleton3D", true, false)
	var cible := j.global_position + Vector3(0, 1.2, 0)
	if sq != null and sq.find_bone(suivi["os"]) >= 0:
		cible = sq.global_transform * sq.get_bone_global_pose(sq.find_bone(suivi["os"])).origin
	var dir := (-j.global_transform.basis.z).rotated(Vector3.UP, deg_to_rad(suivi["deg"]))
	cam.global_position = cible + dir * suivi["dist"] + Vector3(0, suivi["dh"], 0)
	cam.look_at(cible, Vector3.UP)
	if not cam.current:
		cam.make_current()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		_suivre()
		_soleil()
		await process_frame

func _go() -> void:
	PiecesEssai.injecter()
	var nuit := "--nuit" in OS.get_cmdline_user_args()
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if nuit:
		s.options["nuit"] = ""
	root.add_child(s)
	j = s.joueur
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 8)
	calque.add_child(l)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != calque:
			(n as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 45.0
	s.add_child(cam)
	cam.current = true
	s.placer_joueur(Vector3(0, 0, 8.0), 0.0, -6.0)
	j.basculer_vue(true)
	j.mains.magie.equiper("droite", "epee")
	j.mains.magie.equiper("gauche", "torche" if nuit else "vide")
	await _attendre(1.0)
	for f in _arg("familles", "acier").split(","):
		for e in ["tete", "torse", "mains", "pieds"]:
			j.equipement_corps.retirer(e)
		await _attendre(0.2)
		for id: String in FAMILLES[f]:
			j.inventaire.ajouter(id, 1)
			j.equipement_corps.equiper(id)
		await _attendre(0.5)
		var vues := [["epaule + aisselle", "upperarm_l", 70.0, 1.1, 0.1], ["coude + genou", "calf_l", 60.0, 1.5, 0.3], ["dos + nuque", "spine_03", 160.0, 1.4, 0.1], ["plan large", "spine_02", 35.0, 2.6, 0.2]]
		for v in vues:
			suivi = {"os": v[1], "deg": v[2], "dist": v[3], "dh": v[4]}
			s.placer_joueur(Vector3(0, 0, 8.0), 0.0, -6.0)
			await _attendre(0.3)
			l.text = "%s v3 — %s : marche" % [f, v[0]]
			Input.action_press("avant")
			await _attendre(1.3)
			l.text = "%s v3 — %s : course" % [f, v[0]]
			Input.action_press("course")
			await _attendre(1.3)
			Input.action_release("course")
			Input.action_release("avant")
			l.text = "%s v3 — %s : combo" % [f, v[0]]
			for k in 3:
				j.mains.entrees.appuyer()
				await _attendre(0.07)
				j.mains.entrees.relacher()
				await _attendre(0.42)
			await _attendre(0.5)
	print("FIN_FILM")
	quit(0)
