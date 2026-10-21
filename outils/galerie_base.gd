extends SceneTree
## Galerie de controle des personnages « base unifiee » (PersoDef) : fond magenta (le vide se voit), SubViewport 270x270 comme en jeu, memes
## reglages jour / nuit que scripts/cycle.gd.
##   Statique : godot --path . --script res://outils/galerie_base.gd -- --sortie=res://captures/persos/apres [--perso=a,b] [--pose=Idle] [--rangs=j2,j8,n2,n8]
##   Animee   : ... -- --anim=Walk --images=8 [--dist=2.6]   (bande de N images du cycle x 3 angles, jour ; --nuit pour la nuit ; --fond=sol : sol gris)
## Poses : Idle, Walk, Sword_Idle, T, Attaque, Genoux, Course, Assis ; --anim accepte tout nom d'animation de la bibliotheque (Walk, Sprint, Sword_Attack...).
const ANGLES := [["face", 0.0], ["profil", 90.0], ["dos", 180.0]]
const POSES := {"Idle": ["Idle", 0.3], "Walk": ["Walk", 0.35], "Sword_Idle": ["Sword_Idle", 0.2], "T": ["A_TPose", 0.0], "Attaque": ["Sword_Attack", 0.45], "Genoux": ["Fixing_Kneeling", 0.5], "Course": ["Sprint", 0.3], "Assis": ["Sitting_Idle", 0.3]}
var cote := 270
var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var courant: Node3D

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _regler(nuit: bool) -> void:
	env.ambient_light_color = Color(0.32, 0.4, 0.62) if nuit else Color(0.55, 0.62, 0.76)
	env.ambient_light_energy = 0.55 if nuit else 0.62
	if _arg("clair", "") != "":
		env.ambient_light_energy = 1.5     # revue des trous / textures : tout est eclaire
	soleil.light_color = Color(0.62, 0.72, 1.0) if nuit else Color(1.0, 0.86, 0.7)
	soleil.light_energy = 0.75 if nuit else 1.45
	soleil.rotation_degrees = Vector3(-50, 25, 0) if nuit else Vector3(-25, -30, 0)

func _photo(az_deg: float, dist: float, haut: float) -> Image:
	var az := deg_to_rad(az_deg)
	var cible := Vector3(0, haut, 0)
	cam.global_position = cible + Vector3(sin(az), 0.0, cos(az)) * dist
	cam.look_at(cible, Vector3.UP)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _lancer() -> void:
	cote = int(_arg("cote", "270"))
	var sortie := _arg("sortie", "res://captures/persos/apres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	sv = SubViewport.new()
	sv.size = Vector2i(cote, cote)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	sv.add_child(soleil)
	if _arg("sol", "") != "":        # plan gris a y = 0 : juge le contact des semelles
		var plan := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(20, 20)
		plan.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.36, 0.34)
		plan.material_override = mat
		sv.add_child(plan)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	sv.add_child(cam)
	var persos := PersoDefs.toutes()
	var choix := _arg("perso", "").split(",", false)
	var pose: String = _arg("pose", "Idle")
	var anim_nom := _arg("anim", "")
	for nom: String in persos:
		if not choix.is_empty() and not (nom in choix):
			continue
		courant = Personnage.creer(persos[nom])
		sv.add_child(courant)
		if _arg("sans-ressorts", "") != "" and courant.has_node("PersoRessorts"):
			courant.get_node("PersoRessorts").simulateur.active = false
		var ap: AnimationPlayer = courant.get_node("Animations")
		if anim_nom != "":
			await _bande(ap, nom, sortie, anim_nom)
		else:
			var def: Array = POSES.get(pose, ["A_TPose", 0.0])
			if pose != "repos":
				ap.play(def[0])
				ap.seek(ap.get_animation(def[0]).length * float(def[1]), true)
				ap.pause()
			for i in 3:
				await process_frame
			var rangs := _arg("rangs", "j2,j8,n2,n8").split(",", false)
			var feuille := Image.create(cote * ANGLES.size(), cote * rangs.size(), false, Image.FORMAT_RGBA8)
			var zoom := Image.create(cote * ANGLES.size(), cote * rangs.size(), false, Image.FORMAT_RGBA8)
			for rang in rangs.size():
				var nuit: bool = rangs[rang].begins_with("n")
				var dist := float(rangs[rang].substr(1))
				_regler(nuit)
				for col in ANGLES.size():
					var haut := float(_arg("haut", "1.15")) if dist < 3.0 else 0.95
					var cible := _arg("cible", "")          # tete | pieds : vise un os du squelette (gros plans, hauteur propre a chaque morphologie)
					if cible != "":
						var sq := courant.find_child("Skeleton3D", true, false) as Skeleton3D
						var os_ := sq.find_bone("Head" if cible == "tete" else "calf_l")
						haut = (sq.global_transform * sq.get_bone_global_pose(os_)).origin.y + (0.07 if cible == "tete" else -0.25)
					var img: Image = await _photo(float(ANGLES[col][1]), dist, haut)
					feuille.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(col * cote, rang * cote))
					if dist > 3.0:
						var r := Rect2i(cote / 2 - 34, cote / 2 - 56, 68, 112)
						var p := img.get_region(r)
						p.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
						zoom.blit_rect(p, Rect2i(0, 0, p.get_width(), p.get_height()), Vector2i(col * cote + (cote - p.get_width()) / 2, rang * cote + 20))
			feuille.save_png(ProjectSettings.globalize_path(sortie) + "/%s_%s.png" % [nom, pose])
			zoom.save_png(ProjectSettings.globalize_path(sortie) + "/%s_%s_zoom8m.png" % [nom, pose])
		courant.queue_free()
		await process_frame
	Palette.vider()
	Humain.vider()
	Personnage.vider()
	quit(0)

## Angles retenus (--angles=face,profil,dos ; defaut : les trois).
func _angles() -> Array:
	var voulus := _arg("angles", "face,profil,dos").split(",", false)
	var r := []
	for a: Array in ANGLES:
		if a[0] in voulus:
			r.append(a)
	return r

## Bande animee : N images regulieres d'un cycle, 3 angles (lignes). Les ressorts tournent en temps reel : on avance l'animation par pas de temps simules.
func _bande(ap: AnimationPlayer, nom: String, sortie: String, anim_nom: String) -> void:
	var n := int(_arg("images", "8"))
	var dist := float(_arg("dist", "2.6"))
	var nuit := _arg("nuit", "") != ""
	_regler(nuit)
	var anim := ap.get_animation(anim_nom)
	var duree := anim.length
	if _arg("live", "") != "":
		await _bande_live(ap, nom, sortie, anim_nom, n, dist, nuit)
		return
	ap.play(anim_nom)
	var angles := _angles()
	var bande := Image.create(cote * n, cote * angles.size(), false, Image.FORMAT_RGBA8)
	for col in angles.size():
		ap.play(anim_nom)
		ap.seek(0.0, true)
		for k in n:
			ap.seek(duree * float(k) / n, true)
			ap.pause()
			var img: Image = await _photo(float(angles[col][1]), dist, float(_arg("haut", "0.95")))
			bande.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(k * cote, col * cote))
	bande.save_png(ProjectSettings.globalize_path(sortie) + "/%s_%s_bande%s.png" % [nom, anim_nom, "_nuit" if nuit else ""])

## Bande « en direct » : l'animation tourne en temps reel pendant que le personnage AVANCE (--vit=m/s) : les ressorts prennent l'inertie du
## deplacement (cape qui traine, pan qui se souleve). Une image tous les duree/n secondes ; la camera suit le personnage.
func _bande_live(ap: AnimationPlayer, nom: String, sortie: String, anim_nom: String, n: int, dist: float, nuit: bool) -> void:
	var vit := float(_arg("vit", "1.3"))
	var duree := ap.get_animation(anim_nom).length
	ap.play(anim_nom)
	ap.speed_scale = vit / float(_arg("ref", "1.03")) if anim_nom == "Walk" else 1.0
	var bande := Image.create(cote * n, cote * ANGLES.size(), false, Image.FORMAT_RGBA8)
	for col in ANGLES.size():
		courant.position = Vector3.ZERO
		ap.play(anim_nom)
		for i in 40:            # lancement : la cape prend sa vitesse de croisiere
			courant.position.z += vit / 60.0
			await process_frame
		for k in n:
			var t_prochain := Time.get_ticks_msec() + int(duree / ap.speed_scale / n * 1000.0)
			while Time.get_ticks_msec() < t_prochain:
				await process_frame
				courant.position.z += vit * 1.0 / maxf(Engine.get_frames_per_second(), 20.0)
			var az := deg_to_rad(float(ANGLES[col][1]))
			var cible := courant.position + Vector3(0, 0.95, 0)
			cam.global_position = cible + Vector3(sin(az), 0.0, cos(az)) * dist
			cam.look_at(cible, Vector3.UP)
			await RenderingServer.frame_post_draw
			var img := sv.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			bande.blit_rect(img, Rect2i(0, 0, cote, cote), Vector2i(k * cote, col * cote))
	bande.save_png(ProjectSettings.globalize_path(sortie) + "/%s_%s_live%s.png" % [nom, anim_nom, "_nuit" if nuit else ""])
