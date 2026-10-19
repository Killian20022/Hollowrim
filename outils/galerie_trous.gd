extends SceneTree
## Galerie de contrôle des trous (lot 1 du chantier graphisme) : chaque personnage, en plusieurs poses
## et sous 8 angles, à 2 m et à 6 m, rendu dans un SubViewport 256x256 (même grille de tremblement
## que le jeu). Deux rendus par vue : « normal » (fond uni magenta : le vide se voit) et « debug »
## (matériau qui montre les FACES ARRIÈRE en jaune : si du jaune est visible, on regarde l'intérieur
## d'un maillage, c'est-à-dire un trou dans le rendu réel avec cull_back).
##   godot --path . --script outils/galerie_trous.gd -- --sortie=res://captures/trous/avant
##        [--perso=homme,femme,...] [--pose=T,Idle,...] [--fond=magenta|clair] [--cote=256]
## Écrit <sortie>/<perso>__<pose>.png (4 lignes x 8 colonnes : normal 2 m, debug 2 m, normal 6 m,
## debug 6 m) et <sortie>/metriques.csv (pixels de face arrière visibles, pixels de fond enclos).

const COTE_DEFAUT := 256
const ANGLES := [
	["face", 0.0, 0.0], ["trois_quarts", 45.0, 0.0], ["profil_d", 90.0, 0.0], ["trois_quarts_dos", 135.0, 0.0],
	["dos", 180.0, 0.0], ["profil_g", 270.0, 0.0], ["dessus", 0.0, 62.0], ["dessous", 0.0, -48.0],
]
## [animation, fraction de la durée, hauteur visée]
const POSES := {
	"T": ["A_TPose", 0.0, 0.9],
	"Idle": ["Idle", 0.3, 0.9],
	"Walk": ["Walk", 0.35, 0.9],
	"Attaque": ["Sword_Attack", 0.45, 0.9],
	"Parle": ["Idle_Talking", 0.6, 0.9],
	"Genoux": ["Fixing_Kneeling", 0.5, 0.55],
}
const C := Color.WHITE
const TENUE_COMPLETE := {"tunique": Color(0.42, 0.5, 0.78), "pantalon": Color(0.7, 0.65, 0.6), "bottes": C, "ceinture": C,
	"mante": Color(1.1, 1.0, 0.95), "brassards": C, "gants": C}
const DEBUG := preload("res://shaders/debug_faces.gdshader")

var cote := COTE_DEFAUT
var fond := Color(1.0, 0.0, 1.0)
var sv: SubViewport
var cam: Camera3D
var courant: Node3D
var csv: Array[String] = []

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _persos() -> Dictionary:
	var vill: Dictionary = load("res://scripts/villageois.gd").APPARENCES
	var d := {
		"homme": {"corps": "homme", "tenue": TENUE_COMPLETE, "cheveux": "Hair_SimpleParted", "barbe": true, "teinte_cheveux": Color(0.42, 0.28, 0.17)},
		"femme": {"corps": "femme", "tenue": TENUE_COMPLETE, "cheveux": "Hair_Long", "teinte_cheveux": Color(0.9, 0.75, 0.5)},
	}
	for id: String in vill:
		d["pnj_" + id] = vill[id]
	# draugrs : mêmes tenues que scripts/draugr.gd
	var sbire := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6)}}
	d["draugr_sbire"] = sbire
	d["draugr_guerrier"] = {"corps": "homme", "draugr": true, "casque": "casque_draugr", "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6), "mante": Color(0.5, 0.48, 0.45), "bottes": Color(0.6, 0.6, 0.6)}}
	d["svanhild"] = {"corps": "femme", "draugr": true, "casque": "couronne_givre", "cheveux": "Hair_Long", "teinte_cheveux": Color(1.1, 1.15, 1.25), "tenue": {"tunique": Color(0.4, 0.45, 0.6), "mante": Color(0.8, 0.85, 0.95), "brassards": Color(0.8, 0.85, 0.9), "ceinture": Color(0.8, 0.8, 0.8), "bottes": Color(0.6, 0.6, 0.6)}}
	# corps du joueur en 3e personne : scripts/corps_joueur.gd
	d["joueur_3e"] = {"corps": "homme", "tenue": {"tunique": Color(0.35, 0.4, 0.55), "pantalon": Color(0.8, 0.75, 0.7), "bottes": C, "ceinture": C, "mante": Color(1.1, 1.0, 0.95), "brassards": C, "gants": C},
		"cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.42, 0.28, 0.17), "barbe": true}
	return d

func _lancer() -> void:
	cote = int(_arg("cote", str(COTE_DEFAUT)))
	if _arg("fond", "magenta") == "clair":
		fond = Color(0.78, 0.85, 0.92)
	var sortie := _arg("sortie", "res://captures/trous/avant")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	sv = SubViewport.new()
	sv.size = Vector2i(cote, cote)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fond
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	sv.add_child(cam)
	var soleil := DirectionalLight3D.new()
	soleil.light_energy = 0.9
	cam.add_child(soleil)
	soleil.rotation_degrees = Vector3(-20, 15, 0)

	var persos := _persos()
	var choix := _arg("perso", "").split(",", false)
	var poses_voulues := _arg("pose", "").split(",", false)
	for nom: String in persos:
		if not choix.is_empty() and not (nom in choix):
			continue
		courant = Humain.creer(persos[nom])
		_origine.clear()
		_couleurs.clear()
		sv.add_child(courant)
		for pose: String in POSES:
			if not poses_voulues.is_empty() and not (pose in poses_voulues):
				continue
			await _feuille(nom, pose, sortie)
		courant.queue_free()
		await process_frame
	var f := FileAccess.open(ProjectSettings.globalize_path(sortie) + "/metriques.csv", FileAccess.WRITE)
	f.store_string("perso,pose,distance,angle,faces_arriere_px,fond_enclos_px\n" + "\n".join(csv) + "\n")
	f.close()
	f = FileAccess.open(ProjectSettings.globalize_path(sortie) + "/metriques_mesh.csv", FileAccess.WRITE)
	f.store_string("perso,pose,distance,angle,maillage,px\n" + "\n".join(csv_mesh) + "\n")
	f.close()
	Palette.vider()
	Humain.vider()
	quit(0)

func _poser(pose: String) -> void:
	var def: Array = POSES[pose]
	var ap: AnimationPlayer = courant.get_node("Animations")
	ap.play(def[0])
	var duree := ap.get_animation(def[0]).length
	ap.seek(duree * float(def[1]), true)
	ap.pause()
	for i in 3:
		await process_frame

func _feuille(nom: String, pose: String, sortie: String) -> void:
	await _poser(pose)
	var haut: float = float(_arg("haut", str((POSES[pose] as Array)[2])))
	var distances := _arg("dist", "2.2,6.0").split(",", false)
	var choisis: Array[int] = []
	for k in ANGLES.size():
		if _arg("angles", "") == "" or str(ANGLES[k][0]) in _arg("angles", "").split(","):
			choisis.append(k)
	var feuille := Image.create(cote * choisis.size(), cote * 2 * distances.size(), false, Image.FORMAT_RGBA8)
	var rangee := 0
	for dist_txt in distances:
		var dist := float(dist_txt)
		for debug in [false, true]:
			_mode_debug(debug)
			for col in choisis.size():
				var k := choisis[col]
				var a: Array = ANGLES[k]
				var az := deg_to_rad(float(a[1]))
				var el := deg_to_rad(float(a[2]))
				var cible := Vector3(0.0, haut, 0.0)
				var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
				cam.global_position = cible + dir * float(dist)
				cam.look_at(cible, Vector3.UP if absf(sin(el)) < 0.9 else Vector3.BACK)
				for i in 2:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := sv.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				feuille.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(col * cote, rangee * cote))
				if debug:
					csv.append("%s,%s,%.1f,%s,%d,%d" % [nom, pose, dist, a[0], _compter_jaune(img), 0])
					_par_maillage(img, "%s,%s,%.1f,%s" % [nom, pose, dist, a[0]])
				else:
					csv.append("%s,%s,%.1f,%s,%d,%d" % [nom, pose, dist, a[0] + "_normal", 0, _fond_enclos(img)])
			rangee += 1
	_mode_debug(false)
	feuille.save_png(ProjectSettings.globalize_path(sortie) + "/%s__%s.png" % [nom, pose])

var _couleurs := {}   # MeshInstance3D -> Color de ses faces arrière en mode debug
var csv_mesh: Array[String] = []

func _mode_debug(actif: bool) -> void:
	for mi: MeshInstance3D in courant.find_children("*", "MeshInstance3D", true, false):
		if actif:
			if not _origine.has(mi):
				_origine[mi] = mi.material_override
			if not _couleurs.has(mi):
				var n := _couleurs.size()
				var m := ShaderMaterial.new()
				m.shader = DEBUG
				var h := fposmod(float(n) * 0.0417, 0.8) + (0.07 if float(n) * 0.0417 >= 0.78 else 0.0)
				var col := Color.from_hsv(h, 1.0, 1.0)
				m.set_shader_parameter("dos", col)
				_couleurs[mi] = col
				mi.set_meta("debug_mat", m)
			mi.material_override = mi.get_meta("debug_mat")
		else:
			mi.material_override = _origine.get(mi, mi.material_override)

var _origine := {}

func _par_maillage(img: Image, prefixe: String) -> void:
	var compte := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			for mi: MeshInstance3D in _couleurs:
				var k: Color = _couleurs[mi]
				if absf(c.r - k.r) < 0.02 and absf(c.g - k.g) < 0.02 and absf(c.b - k.b) < 0.02:
					compte[mi.name] = int(compte.get(mi.name, 0)) + 1
					break
	for n in compte:
		csv_mesh.append("%s,%s,%d" % [prefixe, n, compte[n]])

func _compter_jaune(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if _est_dos(c):
				n += 1
	return n

## Pixels de fond magenta qui ne touchent pas le bord de l'image (poches entourées par le personnage).
func _fond_enclos(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var vu := PackedByteArray()
	vu.resize(w * h)
	var pile: Array[Vector2i] = []
	for x in w:
		pile.append(Vector2i(x, 0))
		pile.append(Vector2i(x, h - 1))
	for y in h:
		pile.append(Vector2i(0, y))
		pile.append(Vector2i(w - 1, y))
	while not pile.is_empty():
		var p: Vector2i = pile.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or vu[p.y * w + p.x] != 0:
			continue
		if not _est_fond(img.get_pixel(p.x, p.y)):
			continue
		vu[p.y * w + p.x] = 1
		pile.append(Vector2i(p.x + 1, p.y))
		pile.append(Vector2i(p.x - 1, p.y))
		pile.append(Vector2i(p.x, p.y + 1))
		pile.append(Vector2i(p.x, p.y - 1))
	var n := 0
	for y in h:
		for x in w:
			if vu[y * w + x] == 0 and _est_fond(img.get_pixel(x, y)):
				n += 1
	return n

func _est_dos(c: Color) -> bool:
	for mi: MeshInstance3D in _couleurs:
		var k: Color = _couleurs[mi]
		if absf(c.r - k.r) < 0.02 and absf(c.g - k.g) < 0.02 and absf(c.b - k.b) < 0.02:
			return true
	return false

func _est_fond(c: Color) -> bool:
	return absf(c.r - fond.r) < 0.06 and absf(c.g - fond.g) < 0.06 and absf(c.b - fond.b) < 0.06
