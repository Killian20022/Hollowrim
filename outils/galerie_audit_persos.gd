extends SceneTree
## Audit des personnages (refonte/persos_audit) : rendu 640x360 (résolution interne de la refonte), caméra du jeu (FOV 72° vertical),
## chaque type de personnage construit par SON vrai chemin de code (Personnage.creer, nœud draugr.gd, SqueletteGuerrier, dragon.gd).
##   godot --path . --script res://outils/galerie_audit_persos.gd -- --sortie=<dossier absolu> [--perso=a,b] [--sans-images]
## Écrit, par personnage :
##   <nom>_planche.png : 3 colonnes (face, 3/4 avant, dos) x 4 lignes (jour 2 m, jour 4 m, crypte 2 m, crypte 4 m), 640x360 chacune ;
##   <nom>_visage.png  : gros plan x4 (plus proche voisin) du visage vu de face à 2 m ;
## et mesures.csv : triangles, os, surfaces, textures (taille), hauteur réelle (m), hauteur à l'écran (px) à 2 / 4 / 8 / 15 m, largeur du visage
## et du bouclier en pixels à ces distances.
const W := 640
const H := 360
const FOV := 72.0
const DIST_MESURE := [2.0, 4.0, 8.0, 15.0]
const VUES := [["face", 0.0], ["trois_quarts", 35.0], ["dos", 180.0]]
const RANGS := [["jour", 2.0], ["jour", 4.0], ["crypte", 2.0], ["crypte", 4.0]]
const DRAUGR := preload("res://scripts/draugr.gd")
const DRAGON := preload("res://scripts/dragon.gd")

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var torche: OmniLight3D
var csv: Array[String] = ["nom;construction;triangles;os;surfaces;textures;hauteur_m;px_2m;px_4m;px_8m;px_15m;visage_px_2m;visage_px_4m;visage_px_8m;visage_px_15m"]

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

## [nom, genre, paramètre]
func _liste() -> Array:
	return [
		["garde", "perso", PersoDefs.villageois("garde")],
		["chef", "perso", PersoDefs.villageois("chef")],
		["forgeron", "perso", PersoDefs.villageois("forgeron")],
		["chasseuse", "perso", PersoDefs.villageois("chasseuse")],
		["joueur_3e", "perso", PersoDefs.joueur()],
		["bandit_casque", "draugr", {"type": "sbire", "apparence": {"perso": PersoDefs.bandit(1)}}],
		["bandit_archer", "draugr", {"type": "sbire", "archer": true, "apparence": {"perso": PersoDefs.bandit(3)}}],
		["draugr_sbire", "draugr", {"type": "sbire"}],
		["draugr_guerrier", "draugr", {"type": "guerrier"}],
		["boss_jarl", "draugr", {"type": "guerrier", "boss": "jarl"}],
		["boss_svanhild", "draugr", {"type": "guerrier", "boss": "svanhild", "echelle": 1.12, "apparence": {"corps": "femme", "casque": "couronne_givre", "cheveux": "Hair_Long",
			"teinte_cheveux": Color(1.1, 1.15, 1.25), "tenue": {"tunique": Color.WHITE, "haillons": Color.WHITE, "cape": Color.WHITE, "mante": Color.WHITE, "brassards": Color.WHITE,
			"ceinture": Color.WHITE, "bottes": Color.WHITE, "epaulieres": Color.WHITE}, "etoffes": {"tunique": "draugr", "haillons": "draugr", "cape": "draugr", "mante": "blanc", "epaulieres": "draugr"}}}],
		["squelette", "draugr", {"type": "squelette"}],
		["squelette_archer", "draugr", {"type": "squelette_archer"}],
		["dragon", "dragon", {}],
	]

func _lancer() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/audit_persos"))
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	sv.add_child(soleil)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.62, 0.32)
	torche.omni_range = 9.0
	torche.omni_attenuation = 1.2
	sv.add_child(torche)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	var msol := StandardMaterial3D.new()
	msol.albedo_color = Color(0.3, 0.31, 0.33)
	sol.material_override = msol
	sol.name = "sol"
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	var choix := _arg("perso", "").split(",", false)
	for e: Array in _liste():
		if not choix.is_empty() and not (e[0] in choix):
			continue
		var n: Node3D = _construire(e[1], e[2])
		for i in 4:
			await process_frame
		_figer(n)
		for i in 2:
			await process_frame
		await _traiter(e[0], e[1], n, sortie, sol)
		n.queue_free()
		for i in 3:
			await process_frame
	var f := FileAccess.open(sortie + "/mesures.csv", FileAccess.WRITE)
	f.store_string("\n".join(csv) + "\n")
	f.close()
	print("AUDIT : ", sortie)
	quit(0)

func _construire(genre: String, p: Variant) -> Node3D:
	if genre == "perso":
		var n: Node3D = Personnage.creer(p)
		sv.add_child(n)
		return n
	if genre == "dragon":
		var d := CharacterBody3D.new()
		d.set_script(DRAGON)
		d.set("joueur", Node3D.new())
		sv.add_child(d)
		d.set_physics_process(false)
		d.set_process(false)
		return d
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	for cle in p:
		d.set(cle, p[cle])
	d.set("dort", false)
	sv.add_child(d)
	d.set_physics_process(false)
	return d

## Pose fixe : Idle pour les vivants pacifiques, Sword_Idle (garde de combat du draugr) pour les ennemis.
func _figer(n: Node3D) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if ap == null:
		return
	var nom := "Sword_Idle" if n.get_script() == DRAUGR else "Idle"
	if not ap.has_animation(nom):
		nom = "Idle"
	ap.play(nom)
	ap.seek(ap.get_animation(nom).length * 0.25, true)
	ap.pause()

func _regler(mode: String) -> void:
	if mode == "mesure":
		env.background_color = Color(1, 0, 1)
	elif mode == "jour":
		env.background_color = Color(0.56, 0.62, 0.72)
	else:
		env.background_color = Color(0.035, 0.04, 0.06)
	var crypte := mode == "crypte"
	env.ambient_light_color = Color(0.22, 0.27, 0.4) if crypte else Color(0.55, 0.62, 0.76)
	env.ambient_light_energy = 0.35 if crypte else 0.62
	soleil.visible = not crypte
	soleil.light_color = Color(1.0, 0.86, 0.7)
	soleil.light_energy = 1.45
	soleil.rotation_degrees = Vector3(-25, -30, 0)
	torche.visible = crypte
	torche.light_energy = 2.2

func _photo(az_deg: float, dist: float, cam_h: float, cible_h: float) -> Image:
	var az := deg_to_rad(az_deg)
	cam.global_position = Vector3(sin(az) * dist, cam_h, cos(az) * dist)
	cam.look_at(Vector3(0, cible_h, 0), Vector3.UP)
	# torche de crypte : à 1,2 m sur le côté de la caméra, à hauteur d'épaule (le joueur la tient)
	var cote := Vector3(cos(az), 0, -sin(az))
	torche.global_position = cam.global_position + cote * 0.9 + Vector3(0, 0.2, 0)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _est_fond(c: Color) -> bool:
	return c.r > 0.85 and c.g < 0.2 and c.b > 0.85

## Boîte des pixels non magenta (le sol est caché pendant la mesure).
func _boite(img: Image) -> Rect2i:
	var x0 := W
	var y0 := H
	var x1 := -1
	var y1 := -1
	for y in H:
		for x in W:
			if not _est_fond(img.get_pixel(x, y)):
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _stats(n: Node3D) -> Dictionary:
	var tris := 0
	var surfaces := 0
	var tex := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var a := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m: Material = mi.get_surface_override_material(s)
			if m == null:
				m = mi.material_override
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if m is ShaderMaterial:
				for u in (m as ShaderMaterial).shader.get_shader_uniform_list():
					var v: Variant = (m as ShaderMaterial).get_shader_parameter(u["name"])
					if v is Texture2D:
						tex["%s %dx%d" % [u["name"], (v as Texture2D).get_width(), (v as Texture2D).get_height()]] = true
			elif m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture != null:
				var t := (m as StandardMaterial3D).albedo_texture
				tex["albedo %dx%d" % [t.get_width(), t.get_height()]] = true
	var os_ := 0
	for sq: Skeleton3D in n.find_children("*", "Skeleton3D", true, false):
		os_ += sq.get_bone_count()
	return {"tris": tris, "surfaces": surfaces, "os": os_, "tex": ",".join(tex.keys())}

func _os_y(n: Node3D, os_nom: String) -> float:
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null or sq.find_bone(os_nom) < 0:
		return -1.0
	return (sq.global_transform * sq.get_bone_global_pose(sq.find_bone(os_nom))).origin.y

func _traiter(nom: String, genre: String, n: Node3D, sortie: String, sol: Node3D) -> void:
	var st := _stats(n)
	var dragon := genre == "dragon"
	# --- mesures (fond magenta, sans sol, caméra horizontale à mi-hauteur)
	_regler("mesure")
	sol.visible = false
	var px := []
	var visage := []
	var haut_m := 0.0
	var tete_y := _os_y(n, "Head")
	for d: float in DIST_MESURE:
		var dd := d * (4.0 if dragon else 1.0)
		var img: Image = await _photo(0.0, dd, 0.9, 0.9)
		var b := _boite(img)
		px.append(b.size.y)
		if haut_m == 0.0 and b.size.y > 0:
			# hauteur réelle déduite de la projection (caméra horizontale à 0,9 m) : bas et haut de la boîte
			var f := (H * 0.5) / tan(deg_to_rad(FOV * 0.5))
			var y_haut := 0.9 + (H * 0.5 - b.position.y) / f * dd
			var y_bas := 0.9 + (H * 0.5 - (b.position.y + b.size.y)) / f * dd
			haut_m = y_haut - y_bas
		# largeur du visage : rangée de pixels au niveau de l'os Head + 7 cm (yeux), largeur du personnage à cette hauteur
		if tete_y > 0.0:
			var f2 := (H * 0.5) / tan(deg_to_rad(FOV * 0.5))
			var yy := int(H * 0.5 - (tete_y + 0.07 - 0.9) / dd * f2)
			var xs := []
			if yy >= 0 and yy < H:
				for x in W:
					if not _est_fond(img.get_pixel(x, yy)):
						xs.append(x)
			visage.append(0 if xs.is_empty() else int(xs.back()) - int(xs.front()) + 1)
		else:
			visage.append(0)
		if d == 2.0 and not dragon:
			img.save_png(sortie + "/%s_mesure_2m.png" % nom)
	sol.visible = true
	csv.append("%s;%s;%d;%d;%d;%s;%.2f;%d;%d;%d;%d;%d;%d;%d;%d" % [nom, genre, st.tris, st.os, st.surfaces, st.tex, haut_m, px[0], px[1], px[2], px[3], visage[0], visage[1], visage[2], visage[3]])
	print("MESURE ", csv.back())
	if _arg("sans-images", "") != "":
		return
	# --- planche
	var planche := Image.create(W * VUES.size(), H * RANGS.size(), false, Image.FORMAT_RGBA8)
	for r in RANGS.size():
		_regler(RANGS[r][0])
		for c in VUES.size():
			var d: float = RANGS[r][1] * (6.0 if dragon else 1.0)
			var img: Image = await _photo(VUES[c][1], d, 1.6 if not dragon else 2.5, (1.0 if d < 3.0 else 0.95) if not dragon else 1.8)
			planche.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(c * W, r * H))
	planche.save_png(sortie + "/%s_planche.png" % nom)
	# --- gros plan visage (face, 2 m, jour) agrandi x4
	if tete_y > 0.0:
		_regler("jour")
		var img: Image = await _photo(0.0, 2.0, tete_y + 0.07, tete_y + 0.07)
		var r := Rect2i(W / 2 - 40, H / 2 - 30, 80, 60)
		var p := img.get_region(r)
		p.resize(r.size.x * 4, r.size.y * 4, Image.INTERPOLATE_NEAREST)
		p.save_png(sortie + "/%s_visage.png" % nom)
