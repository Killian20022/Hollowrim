extends SceneTree
## Série de captures de la grotte dans UNE seule instance du jeu (fenêtre nécessaire) :
##   godot --path . --script outils/captures_grotte.gd -- --nouvelle --paisible --sortie=res://captures/grotte/x [--mains] [--poses=a,b,c] [--x2]
## Poses « s,décalage,lacet°,tangage° » (s = mètres le long du parcours 0-124, décalage + = droite, lacet 0 = vers le fond, + = vers la gauche).
const POSES := {
	"entree": "3,0,0,-8", "pente": "9,0,0,-6", "retour": "12,0,180,2", "dehors": "7,0,180,4", "boyau": "20,0,0,-3", "boyau2": "29,0,0,-4",
	"caverne": "37,2.5,0,-4", "lac": "41,1.5,35,-8", "lac2": "44,2.0,70,-12", "faille": "45,1.5,25,8", "rai": "49,2.4,80,-6", "lac3": "58,2.0,60,-4",
	"fin_lac": "63,2.0,0,-4", "galerie": "69,0,0,-3", "galerie2": "76,0,0,-6", "marches": "82,0,0,-18", "etai": "86,0,180,-4",
	"camp_entree": "91,0,0,-2", "camp": "95,0,-15,-6", "camp2": "98,-1,35,-8", "camp3": "105,0,180,-6", "camp4": "100,3,-60,-8", "fond": "109,0,0,-2",
	"cristaux": "114,0,0,-4", "cristaux2": "118,1,30,0", "cristaux3": "121,0,180,2", "butin": "104,-1.5,150,-25", "ratelier": "99,2.5,-90,-5",
	"gp_stalag": "40,2.0,90,-20", "gp_crane": "93,-1.0,10,-35", "gp_neige": "10,0,0,-30", "gp_cristal": "119,0.5,20,-10", "gp_glace": "52,-3,120,-45",
}

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := "res://captures/grotte/x"
	var noms: Array = []
	var mains := false
	var x2 := false
	for a in args:
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
		elif a.begins_with("--poses="):
			noms = a.substr(8).split(",")
		elif a == "--mains":
			mains = true
		elif a == "--x2":
			x2 = true
	if noms.is_empty():
		noms = ["entree", "pente", "boyau", "caverne", "lac", "rai", "galerie", "marches", "camp", "camp2", "fond", "cristaux"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 30:
		await process_frame
	m._aller_grotte("4,0,0,0")
	m.joueur.mains.visible = mains
	m.calque.visible = false
	for i in 10:
		await process_frame
	var t0 := Time.get_ticks_msec()
	for n in noms:
		var p: PackedStringArray = String(POSES.get(n, n)).split(",")
		var g: Node3D = m.grotte
		m.joueur.global_position = g.monde_sol(float(p[0]), float(p[1])) + Vector3(0, 0.1, 0)
		m.joueur.rotation.y = g.cap_monde(float(p[0])) + deg_to_rad(float(p[2]))
		m.joueur.tete.rotation.x = deg_to_rad(float(p[3]))
		for i in 25:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		if x2:
			img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(dossier + "/" + n + ".png"))
	print("étapes grotte (ms) : ", m.grotte.etapes)
	print("captures : ", noms.size(), " en ", Time.get_ticks_msec() - t0, " ms ; grotte ", m.grotte.temps_ms, " ms, ", m.grotte.nb_lumieres, " lumières, ", m.grotte.decor.nb_facettes, " facettes")
	quit()
