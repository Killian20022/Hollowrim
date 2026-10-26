extends SceneTree
## Galerie des luminaires et accroches (lot L8) : un CrypteDecor seul (sol, mur), chaque objet posé avec ses vraies lumières, une vue
## proche par objet (640 x 360, rendu du jeu), agrandie x2 au plus proche voisin.
##   bash /tmp/godot_slot.sh godot --path . --script res://outils/galerie_luminaires.gd -- <dossier de sortie>
var _sortie := ""
var _vues: Array = []      # [nom, position caméra, cible]
var _cam: Camera3D
var _i := -1
var _attente := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_sortie = a[0] if a.size() > 0 and not a[0].begins_with("--") else "user://galerie_luminaires"
	DirAccess.make_dir_recursive_absolute(_sortie)
	root.size = Vector2i(640, 360)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.025, 0.035)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.34, 0.42)
	env.environment.ambient_light_energy = 0.5
	monde.add_child(env)
	var corps := StaticBody3D.new()
	monde.add_child(corps)
	var d := CrypteDecor.new(monde, corps)
	# sol et mur du fond (z = -1), salle de 16 x 6 m
	d.boite("dalle_v2", Vector3(0, -0.1, 1.5), Vector3(18.0, 0.2, 6.0))
	d.boite("mur0", Vector3(0, 2.5, -1.2), Vector3(18.0, 5.0, 0.4))
	d.boite("voute", Vector3(0, 4.1, 1.5), Vector3(18.0, 0.2, 6.0))
	d.applique(Vector3(-7.0, 0, -1.0), Vector3(0, 0, 1), 2.1, 5.0, 1.7)
	_vues.append(["applique", Vector3(-6.3, 2.0, 0.3), Vector3(-7.0, 2.15, -0.8)])
	_vues.append(["applique_loin", Vector3(-5.6, 1.6, 2.6), Vector3(-7.0, 2.1, -0.8)])
	d.chaine(Vector3(-4.6, 4.0, 0.2), Vector3(-4.6, 2.2, 0.2))
	d.chaine(Vector3(-4.2, 4.0, 0.2), Vector3(-4.2, 2.6, 0.2))
	_vues.append(["chaine", Vector3(-4.4, 2.8, 1.3), Vector3(-4.4, 3.0, 0.2)])
	CrypteV2.lustre(d, Vector3(-1.5, 4.0, 1.0), 1.4)
	d.lumiere(Vector3(-1.5, 2.9, 1.0), CrypteDecor.FEU_BOUGIE, 1.3, 6.0, 1.7)
	_vues.append(["lustre_v2", Vector3(-1.5, 1.7, 2.9), Vector3(-1.5, 2.7, 1.0)])
	d.lustre(Vector3(1.6, 4.0, 1.0), 1.3, 0.55, true)
	_vues.append(["lustre_v1", Vector3(1.6, 1.7, 2.9), Vector3(1.6, 2.8, 1.0)])
	for fp: Vector3 in ObjLuminaires.candelabre(d, Vector3(3.6, 0, 0.0), 0.0):
		d.flamme(fp, 0.5)
	d.lumiere(Vector3(3.6, 1.7, 0.0), CrypteDecor.FEU_BOUGIE, 0.9, 5.0, 1.6)
	_vues.append(["candelabre", Vector3(3.6, 1.5, 1.5), Vector3(3.6, 1.0, 0.0)])
	d.brasero(Vector3(5.6, 0, 0.6))
	_vues.append(["brasero_crypte", Vector3(5.6, 1.9, 2.3), Vector3(5.6, 0.8, 0.6)])
	var f := ObjLuminaires.lanterne(d, Vector3(7.2, 3.0, 0.4), 0.3)
	d.lumiere(f, CrypteDecor.FEU, 1.6, 4.0, 1.8)
	_vues.append(["lanterne", Vector3(7.2, 2.3, 1.4), Vector3(7.2, 2.5, 0.4)])
	ObjLuminaires.brasero_fer(d, Vector3(7.6, 0, 2.6))
	d.tour("braise", Vector3(7.6, 0.9, 2.6), [Vector2(0.36, 0.0), Vector2(0.3, 0.04)], 8, 0.0, true)
	d.flamme(Vector3(7.6, 0.92, 2.6), 1.8)
	d.lumiere(Vector3(7.6, 1.3, 2.6), CrypteDecor.FEU, 2.0, 5.0, 1.7)
	_vues.append(["brasero_grotte", Vector3(6.4, 1.6, 3.8), Vector3(7.6, 0.6, 2.6)])
	d.finir()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	monde.add_child(_cam)
	_suivante()

func _suivante() -> void:
	_i += 1
	if _i >= _vues.size():
		quit(0)
		return
	var v: Array = _vues[_i]
	_cam.look_at_from_position(v[1], v[2], Vector3.UP)
	_attente = 12

func _process(_delta: float) -> bool:
	if _i < 0 or _i >= _vues.size():
		return false
	_attente -= 1
	if _attente > 0:
		return false
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [_sortie, _vues[_i][0]])
	_suivante()
	return false
