extends SceneTree
## Essai Tripo : jarl statique (assets/pnj/tripo_jarl.glb, texture passée au shader PS1) debout au village à côté d'un vrai habitant
## (PnjNordique), caméra du joueur en 1re personne : approche jusqu'à 2 m (face), tour (profil, dos), puis même plan de nuit à la torche.
## FENÊTRE (godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tripo_jarl.gd -- --nouvelle --sortie=<dossier>
## Fixes dans <dossier> : jarl_<face|profil|dos>.png, hab_<face|profil|dos>.png (même distance 2 m, hauteur d'yeux), ensemble.png.
const SCENE := "res://scenes/foret_test.tscn"
const GLB := "res://assets/pnj/tripo_jarl.glb"
const DIST := 2.0
var m: Node3D
var j: CharacterBody3D
var jarl: Node3D
var hab: Node3D
var torche: OmniLight3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _att(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()

## Une image ; referme le menu du personnage s'il s'ouvre (touche réelle de l'utilisateur reçue par la fenêtre hors écran).
func _pf() -> void:
	if m != null and m.get("inventaire_ui") != null and m.inventaire_ui.ouvert:
		m.inventaire_ui.fermer()
	await process_frame

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

## Caméra du joueur à `r` m de `c`, côté direction `ang` (rad, 0 = devant un modèle qui regarde +Z), regardant le point `c`.
func _cam(c: Vector3, ang: float, r: float, tangage := 0.0) -> void:
	var p := c + Vector3(sin(ang), 0.0, cos(ang)) * r
	j.global_position = Vector3(p.x, m.hauteur(p.x, p.z) + 0.1, p.z)
	j.rotation.y = ang
	j.tete.rotation.x = deg_to_rad(tangage)
	j.velocity = Vector3.ZERO

func _fixe(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://tripo").path_join(nom + ".png"))

func _habiller(racine: Node) -> void:
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				var mat := Palette.materiau(tex, Vector2.ONE, Color.WHITE, _arg("double", "1") == "1")   # double face : bouche les trous du manteau
				mat.set_shader_parameter("tex_neige", tex)
				mi.set_surface_override_material(s, mat)

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	for v in get_nodes_in_group("villageois"):
		if v.get("donnees") is Dictionary and v.donnees.get("id") == "hab_paysan_1":
			hab = v
		if v.get("_delai_interpelle") != null:
			v._delai_interpelle = 99999.0
	await _att(2.0)
	_heure(11.0)
	var hp := hab.global_position
	# le jarl se tient à 1,3 m à droite de l'habitant (vu de face), tourné comme lui
	var dirh := Vector3(sin(hab.rotation.y), 0.0, cos(hab.rotation.y))
	var cote := Vector3(dirh.z, 0.0, -dirh.x)
	var jp := hp + cote * 1.3
	jarl = (load(GLB) as PackedScene).instantiate()
	_habiller(jarl)
	root.add_child(jarl)
	jarl.global_position = Vector3(jp.x, m.hauteur(jp.x, jp.z), jp.z)
	jarl.rotation.y = hab.rotation.y
	print("HAB %s rot %.2f JARL %s" % [hp, hab.rotation.y, jarl.global_position])
	var ry: float = hab.rotation.y
	await _att(0.5)
	# --- fixes (même distance, hauteur d'yeux) : jarl puis habitant, face / profil / dos
	var noms := ["face", "profil", "dos"]
	for k in 3:
		_cam(jarl.global_position, ry + k * PI * 0.5, DIST)
		await _att(0.4)
		await _fixe("jarl_" + noms[k])
	for k in 3:
		_cam(hab.global_position, ry + k * PI * 0.5, DIST)
		await _att(0.4)
		await _fixe("hab_" + noms[k])
	var mid := (jarl.global_position + hab.global_position) * 0.5
	_cam(mid, ry, 3.6)
	await _att(0.4)
	await _fixe("ensemble")
	if _arg("fixes_seulement") == "1":
		print("FIN_FIXES")
		quit(0)
	# --- film de jour : approche (4 s) puis tour (6 s) autour du jarl
	print("DEBUT_SEQUENCE %d" % Engine.get_process_frames())
	for k in 120:
		_cam(jarl.global_position, ry, lerpf(6.0, DIST, smoothstep(0.0, 1.0, k / 119.0)))
		await process_frame
	await _att(0.5)
	for k in 180:
		_cam(jarl.global_position, ry + TAU * 0.8 * smoothstep(0.0, 1.0, k / 179.0), DIST)
		await process_frame
	# --- nuit à la torche : même plan, lumière chaude portée par la caméra
	_heure(23.0)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.65, 0.3)
	torche.light_energy = 2.2
	torche.omni_range = 7.0
	torche.position = Vector3(0.35, -0.2, -0.3)
	j.camera.add_child(torche)
	for k in 150:
		_cam(jarl.global_position, ry + PI * 0.9 * smoothstep(0.0, 1.0, k / 149.0) * (1.0 if k < 150 else 0.0) - PI * 0.0, lerpf(3.0, DIST, minf(k / 40.0, 1.0)))
		await process_frame
	print("FIN_SEQUENCE %d" % Engine.get_process_frames())
	quit(0)
