extends SceneTree
## Claymore v4 (branche combat/claymore_v4) : MESURES + planches avant / après, la claymore du jeu (CatalogueArmes « claymore »,
## stats du catalogue appliquées, comme dans le butin) comparée à l'épée à une main (« epee_soldat »).
## FENÊTRE hors écran (godot_slot.sh) :
##   godot --path . --fixed-fps 60 --resolution 960x540 --audio-driver Dummy --script res://outils/captures_claymore_v4.gd --
##         --nouvelle --sortie=<dossier> [--etiquette=avant|apres] [--parties=mesures,fps,tps,arme,film]
## mesures : angle de la lame (écran : par rapport à la verticale ; 3D : par rapport à l'avant-bras) au repos / en garde / en
##           marche, et durées réelles des coups (clic -> retour au repos, phases du geste) ; lignes « MESURE ... » dans le log.
## fps     : planche 1re personne (repos, garde, marche, armé, frappe, suivi du combo 1-2-3, puissante).
## tps     : planche 3e personne (repos, garde, coup), caméra de côté.
## arme    : gros plan de l'arme, au sol (ObjetMonde).
## film    : combo 1-2-3 puis puissante (même séquence avant / après) ; à lancer seul avec --write-movie.
const DT := 1.0 / 60.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var dossier := ""
var etiq := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.vigueur = j.vigueur_max
		await process_frame

func _texte(t: String) -> void:
	if l != null:
		l.text = t
	print("ETAPE ", t)

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else load("res://data/armes/%s.tres" % id))
	await _attendre(1.0)

func _go() -> void:
	RetourImpact.muet = true
	dossier = _arg("sortie", "res://captures/claymore_v4")
	etiq = _arg("etiquette", "x")
	DirAccess.make_dir_recursive_absolute(dossier)
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("hud") != null:
		s.hud.visible = false
	await _attendre(0.7)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 500)
	calque.add_child(l)
	var parties := _arg("parties", "mesures,fps,tps,arme").split(",")
	if parties.has("mesures"):
		await _mesures()
	if parties.has("fps"):
		await _planche_fps()
	if parties.has("tps"):
		await _planche_tps()
	if parties.has("arme"):
		await _planche_arme()
	if parties.has("film"):
		await _film()
	print("FIN_CAPTURES")
	quit(0)

# ------------------------------------------------------------------ mesures

func _cam() -> Camera3D:
	return root.get_viewport().get_camera_3d()

## Points monde garde / pointe de l'arme affichée (repères du modèle, ou garde / pointe de la DonneesArme).
func _lame_monde() -> Array:
	var m: Node3D = mains.get("_modele_arme_d")
	var g: Vector3 = mains.get("_garde_lame")
	var p: Vector3 = mains.get("_pointe_lame")
	if m == null or not is_instance_valid(m):
		return []
	return [m.global_transform * g, m.global_transform * p]

func _os_monde(nom_contient: Array) -> Vector3:
	for sq: Skeleton3D in mains.find_children("*", "Skeleton3D", true, false):
		for i in sq.get_bone_count():
			var n := sq.get_bone_name(i).to_lower()
			var ok := true
			for c in nom_contient:
				if not n.contains(c):
					ok = false
			if ok:
				return sq.global_transform * sq.get_bone_global_pose(i).origin
	return Vector3.INF

## [angle écran / verticale (° , + = pointe à droite), angle 3D lame / avant-bras (°), avancée de la pointe (° vers l'avant)]
func _angles() -> Array:
	var lm := _lame_monde()
	if lm.is_empty():
		return [0.0, 0.0, 0.0]
	var c := _cam()
	var eg := c.unproject_position(lm[0])
	var ep := c.unproject_position(lm[1])
	var d := ep - eg
	var ecran := rad_to_deg(atan2(d.x, -d.y))
	var coude := _os_monde(["lowerarm", "r"])
	if coude == Vector3.INF:
		coude = _os_monde(["forearm", "r"])
	var main := _os_monde(["hand", "r"])
	var bras := 0.0
	var lame: Vector3 = (lm[1] - lm[0]).normalized()
	if coude != Vector3.INF and main != Vector3.INF:
		bras = rad_to_deg((main - coude).normalized().angle_to(lame))
	var loc := c.global_transform.basis.inverse() * lame
	var avance := rad_to_deg(atan2(-loc.z, loc.y))
	return [ecran, bras, avance]

func _mesurer_pose(nom: String, fig: String, marche := false) -> void:
	mains._pose_figee = fig
	if marche:
		mains._pose_figee = ""
		j.velocity = Vector3(0, 0, -2.0)
	await _attendre(0.5 if not marche else 1.2)
	var a := _angles()
	mains._pose_figee = ""
	print("MESURE %s angle %s : ecran=%.1f deg / verticale, lame/avant-bras=%.1f deg, pointe vers l'avant=%.1f deg" % [etiq, nom, a[0], a[1], a[2]])

func _clic(maintien := 0.05) -> void:
	mains.entrees.appuyer()
	await _attendre(maintien)
	mains.entrees.relacher()

## Clic puis images jusqu'au retour au repos : durées réelles (s) de chaque phase.
func _mesurer_coup(nom: String, maintien := 0.05) -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	await _attendre(0.6)
	var t := 0.0
	mains.entrees.appuyer()
	var relache := false
	var phases := {}
	var prec := -1
	var t_actif0 := -1.0
	var t_actif1 := -1.0
	while t < 6.0:
		if not relache and t >= maintien:
			mains.entrees.relacher()
			relache = true
		await process_frame
		j.vigueur = j.vigueur_max
		t += DT
		var e: int = mains.combat.etat
		if e != prec:
			phases[t] = e
			prec = e
		if t_actif0 < 0.0 and mains.get("_t_geste") != null and float(mains.get("_t_geste")) >= float(mains.get("_duree_prep")) + float(mains.get("_duree_tenue")):
			t_actif0 = t
		if t_actif0 >= 0.0 and t_actif1 < 0.0 and float(mains.get("_t_geste")) >= float(mains.get("_duree_prep")) + float(mains.get("_duree_tenue")) + float(mains.get("_duree_active")):
			t_actif1 = t
		if relache and t > 0.2 and (e == EtatCombat.REPOS or e == EtatCombat.MOUVEMENT):
			break
	print("MESURE %s duree %s : total=%.2f s (clic -> repos), prep=%.2f tenue=%.2f frappe=%.2f recup=%.2f ; frappe de %.2f a %.2f s ; phases=%s" % [
		etiq, nom, t, float(mains.get("_duree_prep")), float(mains.get("_duree_tenue")), float(mains.get("_duree_active")),
		float(mains.get("_duree_recup")), t_actif0, t_actif1, str(phases)])

## Combo 1-2-3 enchaîné au plus tôt (clic dès que la fenêtre d'enchaînement s'ouvre) : durée totale.
func _mesurer_combo(nom: String) -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	await _attendre(0.6)
	var t := 0.0
	var clics := 0
	var t_clic := -1.0
	while t < 10.0:
		if clics < 3 and (t_clic < 0.0 or t - t_clic > 0.08):
			if clics == 0 or mains.combat.attaque() or mains.combat.etat == EtatCombat.RECUPERATION:
				mains.entrees.appuyer()
				await process_frame
				t += DT
				mains.entrees.relacher()
				t_clic = t
				clics += 1
		await process_frame
		j.vigueur = j.vigueur_max
		t += DT
		if clics >= 3 and t - t_clic > 0.3 and (mains.combat.etat == EtatCombat.REPOS or mains.combat.etat == EtatCombat.MOUVEMENT):
			break
	print("MESURE %s duree combo %s : 3 coups enchaines au plus tot = %.2f s" % [etiq, nom, t])

func _mesures() -> void:
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	for id in ["claymore", "epee_soldat"]:
		await _equiper(id)
		var a: DonneesArme = mains.arme
		print("MESURE %s arme %s : vitesse=%.2f preparation=%.2f recuperation=%.2f profil=%s modele=%s" % [etiq, id, a.vitesse, a.preparation, a.recuperation, a.profil, a.modele])
		await _mesurer_pose(id + " repos", "")
		mains.entrees.forcer_garde(1.0)
		await _attendre(0.6)
		var g := _angles()
		print("MESURE %s angle %s : ecran=%.1f deg / verticale, lame/avant-bras=%.1f deg, pointe vers l'avant=%.1f deg" % [etiq, id + " garde", g[0], g[1], g[2]])
		await _attendre(0.8)
		await _mesurer_coup(id + " leger")
		await _mesurer_coup(id + " puissant", 0.9)
		await _mesurer_combo(id)
		mains.combat.forcer(EtatCombat.REPOS)
		await _attendre(0.5)

# ------------------------------------------------------------------ planches

func _capture() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _planche(imgs: Array[Image], nom: String, col := 4) -> void:
	var w := imgs[0].get_width() / 2
	var h := imgs[0].get_height() / 2
	var planche := Image.create(w * col, h * ceili(imgs.size() / float(col)), false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im := imgs[i]
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
	planche.save_png(dossier.path_join(nom))
	print("PLANCHE ", dossier.path_join(nom))

func _planche_fps() -> void:
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	await _equiper("claymore")
	var imgs: Array[Image] = []
	var poses := [["", "repos"], ["garde_2m:0.0", "garde"], ["c2_a:%s" % _t_marq("c2_a", "arme"), "1 diagonale : arme"],
		["c2_a:%s" % _t_mi("c2_a"), "1 diagonale : frappe"], ["c2_b:%s" % _t_mi("c2_b"), "2 retour : frappe"],
		["c2_c:%s" % _t_mi("c2_c"), "3 vertical : frappe"], ["charge_2m:%s" % _t_marq("charge_2m", "fin"), "puissante : charge"],
		["lourd_2m:%s" % _t_mi("lourd_2m"), "puissante : frappe"]]
	for p in poses:
		mains._pose_figee = String(p[0])
		if p[1] == "garde":
			mains._pose_figee = ""
			mains.entrees.forcer_garde(0.8)
		_texte("%s 1re pers. : %s" % [etiq, p[1]])
		await _attendre(0.5)
		var a := _angles()
		l.text += "   (lame %.0f deg / verticale)" % a[0]
		await process_frame
		imgs.append(_capture())
		await _attendre(0.6)
	mains._pose_figee = ""
	_planche(imgs, "%s_planche_1re_personne.png" % etiq)

func _t_marq(clip: String, m: String) -> String:
	var mq: Dictionary = mains.anim.marqueurs(clip)
	return "%.3f" % float(mq.get(m, 0.0))

func _t_mi(clip: String) -> String:
	var mq: Dictionary = mains.anim.marqueurs(clip)
	return "%.3f" % ((float(mq.get("frappe", 0.0)) + float(mq.get("fin_frappe", 0.0))) * 0.5)

func _planche_tps() -> void:
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	await _equiper("claymore")
	j.basculer_vue(true)
	var imgs: Array[Image] = []
	for orb in [-100.0, 150.0]:
		j.camera_tp.set("_orbite", deg_to_rad(orb))
		j.camera_tp.recaler()
		_texte("%s 3e pers. : repos (orbite %d)" % [etiq, orb])
		await _attendre(1.2)
		_mesure_tps("repos")
		imgs.append(_capture())
	# gros plan des mains sur la poignée (repos)
	var long0: float = j.camera_tp.bras.spring_length
	j.camera_tp.bras.spring_length = 1.7
	j.camera_tp.set("_orbite", deg_to_rad(-140.0))
	j.camera_tp.recaler()
	_texte("%s 3e pers. : mains sur la poignee" % etiq)
	await _attendre(1.0)
	imgs.append(_capture())
	j.camera_tp.bras.spring_length = long0
	j.camera_tp.set("_orbite", deg_to_rad(-100.0))
	j.camera_tp.recaler()
	mains.entrees.forcer_garde(1.2)
	_texte("%s 3e pers. : garde" % etiq)
	await _attendre(0.9)
	_mesure_tps("garde")
	imgs.append(_capture())
	await _attendre(0.8)
	mains.combat.forcer(EtatCombat.REPOS)
	await _attendre(0.5)
	mains._combo = 0
	mains.entrees.appuyer()
	await _attendre(0.05)
	mains.entrees.relacher()
	var t := 0.0
	while t < 3.0:
		await process_frame
		t += DT
		if float(mains.get("_t_geste")) >= float(mains.get("_duree_prep")) + float(mains.get("_duree_tenue")) + float(mains.get("_duree_active")) * 0.5:
			break
	_texte("%s 3e pers. : coup 1 (frappe)" % etiq)
	await process_frame
	imgs.append(_capture())
	await _attendre(2.0)
	j.basculer_vue(false)
	await _attendre(0.5)
	_planche(imgs, "%s_planche_3e_personne.png" % etiq, 2)

## Lame de l'arme tenue par le corps (3e personne) : angle à la verticale du monde, part vers l'avant / la droite du joueur.
func _mesure_tps(nom: String) -> void:
	var c = j.get("corps")
	var mt = c.get("mains_tps") if c != null else null
	var a: Node3D = mt.get("_arme_d") if mt != null else null
	if a == null or not is_instance_valid(a):
		print("MESURE %s tps %s : pas d'arme" % [etiq, nom])
		return
	var d := a.global_basis.y.normalized()
	var av := d.dot(-j.global_basis.z)
	var dr := d.dot(j.global_basis.x)
	print("MESURE %s angle tps %s : lame/verticale=%.1f deg, vers l'avant=%.1f deg, vers la droite=%.1f deg" % [etiq, nom,
		rad_to_deg(d.angle_to(Vector3.UP)), rad_to_deg(atan2(av, d.y)), rad_to_deg(atan2(dr, d.y))])

## Gros plan de l'arme (SubViewport, même lumière avant / après) + arme posée au sol (ObjetMonde).
func _planche_arme() -> void:
	var a: DonneesArme = CatalogueArmes.donnees("claymore")
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3d44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a0")
	env.ambient_light_energy = 0.5
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-30, -35, 0)
	sol.light_energy = 1.3
	vp.add_child(sol)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var m: Node3D = (load(a.modele) as PackedScene).instantiate()
	if a.habillage == "claymore":
		ClaymoreMateriaux.habiller(m)
	else:
		EpeesLongues.habiller(m)
	vp.add_child(m)
	var tris := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for sidx in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sidx)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("MESURE %s triangles claymore (%s) = %d" % [etiq, a.modele, tris])
	var lg := 1.6
	var vues := [
		# [projection ortho ?, taille / fov, position caméra, cible, rotation de l'arme] ; couchée en travers du cadre 16:9
		[true, lg * 0.62, Vector3(0.0, 0, 3), Vector3(0.0, 0, 0), Vector3(0, 0, -PI / 2)],
		[true, lg * 0.62, Vector3(0.0, 0, 3), Vector3(0.0, 0, 0), Vector3(deg_to_rad(55), 0, -PI / 2)],
		[false, 34.0, Vector3(0.20, 0.17, 0.52), Vector3(0.0, 0.14, 0.0), Vector3(0, deg_to_rad(10), 0)],
		[false, 30.0, Vector3(-0.14, -0.15, 0.46), Vector3(0.0, -0.19, 0.0), Vector3(0, deg_to_rad(-15), 0)],
		[false, 26.0, Vector3(0.10, 0.34, 0.36), Vector3(0.0, 0.33, 0.0), Vector3(0, deg_to_rad(25), 0)],
	]
	var imgs: Array[Image] = []
	for v in vues:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL if v[0] else Camera3D.PROJECTION_PERSPECTIVE
		if v[0]:
			cam.size = v[1]
		else:
			cam.fov = v[1]
		cam.position = v[2]
		cam.look_at(v[3])
		m.rotation = v[4]
		m.position = Vector3(-0.47, 0, 0) if v[0] else Vector3.ZERO   # milieu de l'arme (y ~ 0,47) au centre du cadre
		await _attendre(0.2)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(960, 540, Image.INTERPOLATE_NEAREST)
		imgs.append(img)
	vp.queue_free()
	# au sol, dans la scène de test (ObjetMonde : rendu réel d'un objet du butin)
	var om: Variant = ObjetMonde.visuel("claymore", "sol")
	if om is Node3D:
		mains.equipement.equiper("droite", load("res://data/armes/main_vide.tres"))
		s.add_child(om)
		(om as Node3D).global_position = Vector3(0.0, 0.0, 4.6)
		s.placer_joueur(Vector3(0, 0, 5.9), 0.0, -50.0)
		await _attendre(0.8)
		var cs := _capture()
		var w := cs.get_width()
		var h := cs.get_height()
		var zc := cs.get_region(Rect2i(w / 4, h / 4, w / 2, h / 2))   # centre agrandi x2 (pixels nets)
		zc.resize(w, h, Image.INTERPOLATE_NEAREST)
		imgs.append(zc)
		om.queue_free()
	_planche(imgs, "%s_planche_arme.png" % etiq, 2)

# ------------------------------------------------------------------ film

func _film() -> void:
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	await _equiper("claymore")
	for vue in [false, true]:
		j.basculer_vue(vue)
		if vue:
			j.camera_tp.set("_orbite", deg_to_rad(-110.0))
			j.camera_tp.recaler()
		mains.combat.forcer(EtatCombat.REPOS)
		_texte("%s %s : garde" % [etiq, "3e pers." if vue else "1re pers."])
		await _attendre(1.0)
		var d1: Node = s.creer_draugr(Vector3(-0.6, 0, 3.6), false)
		d1.look_at(j.global_position, Vector3.UP, true)
		_texte("%s %s : combo 1-2-3 (clic toutes les 0,7 s)" % [etiq, "3e pers." if vue else "1re pers."])
		mains._combo = 0
		for k in 3:
			await _clic()
			await _attendre(0.7)
		await _attendre(1.6)
		_texte("%s %s : coup puissant (maintenu 0,9 s)" % [etiq, "3e pers." if vue else "1re pers."])
		await _clic(0.9)
		await _attendre(2.2)
		if is_instance_valid(d1):
			d1.queue_free()
	j.basculer_vue(false)
