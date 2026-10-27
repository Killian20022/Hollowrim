extends SceneTree
## Captures du combat à l'épée dans scenes/test_combat.tscn (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_combat_epee.gd -- --sortie=<dossier> [--film]
## Planches (une image par séquence, vignettes côte à côte) : coups légers enchaînés, coup lourd chargé, rebond sur le
## mur avec le tracé de lame, marche / sprint / saut (animations passives), repos jour et nuit.
## --mesures : coups en espace écran image par image (60 i/s), avec en surimpression les mesures de chaque image
## (% de lame visible, angle lame / rayon de visée, couverture main + bras droit, écart avant-bras / poignée à l'écran) ;
## planches <sortie>/coup_<n>_<geste>.png et tableau min / max imprimé (lignes MESURE / RESUME).
## --film : scénario joué en continu pour Movie Maker (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- ») :
## combo sur le mannequin, coup lourd, puis combat contre le draugr.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _monter(options: Dictionary) -> void:
	if s != null:
		s.queue_free()
		await process_frame
	s = SCENE.instantiate()
	s.options = options
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

## Maintient des actions de déplacement pendant n images (réappuyées à chaque image : une fenêtre hors écran sans
## focus relâche les actions pressées par script).
func _tenir(actions: Array, n: int) -> void:
	for i in n:
		for a in ["avant", "course", "saut"]:
			if a in actions:
				Input.action_press(a)
			else:
				Input.action_release(a)
		await physics_frame
	await process_frame

## Avance le combat à pas fixe (pas_manuel) puis laisse le moteur poser l'IK et rendre.
func _pas(duree: float) -> void:
	for i in roundi(duree / DT):
		mains.avancer(DT)
	await process_frame
	await process_frame

func _planche(nom: String, images: Array) -> void:
	var w := 320
	var h := 180
	var p := Image.create(w * images.size(), h, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/combat_epee"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	if _arg("film") != "":
		await _film()
		quit()
		return
	if _arg("coups") != "":
		await _coups_image_par_image()
		quit()
		return
	if _arg("mesures") != "":
		await _coups_mesures()
		quit()
		return
	if _arg("film-coups") != "":
		await _film_coups(float(_arg("ralenti", "1")))
		quit()
		return
	await _monter({"draugr": "fige", "sans-aide": ""})
	mains.pas_manuel = true
	# --- repos (scène de test, jour)
	s.placer_joueur(Vector3.ZERO, 0.0)
	await _pas(0.5)
	var repos := await _image()
	repos.save_png(sortie.path_join("repos_scene_jour.png"))
	# --- combo de coups légers : préparation, phase active, fin, pour chacun des trois gestes
	var imgs := []
	for c in 3:
		mains.entrees.appuyer()
		await _pas(0.05)
		mains.entrees.relacher()
		await _pas(0.05)
		imgs.append(await _image())      # armé
		await _pas(0.10)
		imgs.append(await _image())      # milieu de la phase active
		await _pas(0.12)
		imgs.append(await _image())      # fin / récupération
		await _pas(0.15)
	await _planche("coups_legers_combo", imgs)
	await _pas(0.8)
	# --- directions selon le contexte (phase 4) : en avançant, pas à droite, pas à gauche, en reculant (armé, milieu)
	imgs = []
	for v in [Vector3(0, 0, -3.2), Vector3(3.2, 0, 0), Vector3(-3.2, 0, 0), Vector3(0, 0, 2.5)]:
		await _pas(0.6)
		j.velocity = v
		mains.entrees.appuyer()
		mains.avancer(DT)
		mains.entrees.relacher()
		await _pas(0.10)
		imgs.append(await _image())
		await _pas(0.09)
		imgs.append(await _image())
		j.velocity = Vector3.ZERO
		await _pas(0.4)
	await _planche("directions_avant_droite_gauche_recul", imgs)
	# --- coup lourd : charge, pleine charge, frappe, fin
	imgs = []
	mains.entrees.appuyer()
	await _pas(0.45)
	imgs.append(await _image())
	await _pas(1.0)
	imgs.append(await _image())          # pleine charge (tremblement, reflet)
	mains.entrees.relacher()
	await _pas(0.15)
	imgs.append(await _image())
	await _pas(0.10)
	imgs.append(await _image())
	await _pas(0.25)
	imgs.append(await _image())
	await _planche("coup_lourd", imgs)
	await _pas(0.8)
	# --- mur : rebond, avec le tracé de lame affiché (débogage)
	mains.basculer_debogage(true)
	s.placer_joueur(Vector3(-1.9, 0, 1.0), 90.0)
	await _pas(0.4)
	imgs = []
	mains.entrees.appuyer()
	await _pas(0.05)
	mains.entrees.relacher()
	await _pas(0.12)
	imgs.append(await _image())
	await _pas(0.05)
	imgs.append(await _image())
	await _pas(0.12)
	imgs.append(await _image())
	await _planche("mur_rebond_trace", imgs)
	# tracé sur le mannequin, vu de côté par une caméra de débogage
	s.placer_joueur(Vector3.ZERO, 0.0)
	await _pas(0.6)
	mains.entrees.appuyer()
	await _pas(0.05)
	mains.entrees.relacher()
	await _pas(0.5)
	var c := Camera3D.new()
	s.add_child(c)
	c.global_position = Vector3(2.6, 1.9, -0.4)
	c.look_at(Vector3(0, 1.3, -1.2))
	c.current = true
	await _pas(0.02)
	(await _image()).save_png(sortie.path_join("trace_lame_cote.png"))
	c.queue_free()
	j.camera.current = true
	mains.basculer_debogage(false)
	# --- animations passives : repos, marche, sprint, saut (vrai déplacement du joueur, temps réel)
	mains.pas_manuel = false
	s.placer_joueur(Vector3(0, 0, 2.0), 180.0)   # face à +Z : terrain dégagé
	imgs = []
	for i in 20:
		await process_frame
	imgs.append(await _image())
	await _tenir(["avant"], 40)
	imgs.append(await _image())          # marche
	await _tenir(["avant"], 9)
	imgs.append(await _image())          # marche, autre phase du pas
	await _tenir(["avant", "course"], 50)
	imgs.append(await _image())          # sprint : épée abaissée, torche stabilisée
	await _tenir(["avant", "course"], 7)
	imgs.append(await _image())
	await _tenir([], 6)
	imgs.append(await _image())          # arrêt brutal : léger retour des bras
	await _tenir(["saut"], 2)
	await _tenir([], 5)
	imgs.append(await _image())          # impulsion du saut
	for i in 60:
		await _tenir([], 1)
		if j.is_on_floor():
			break
	await _tenir([], 3)
	imgs.append(await _image())          # atterrissage
	await _planche("passifs_repos_marche_sprint_saut", imgs)
	# --- nuit
	await _monter({"draugr": "fige", "sans-aide": "", "nuit": ""})
	s.placer_joueur(Vector3.ZERO, 0.0)
	for i in 30:
		await process_frame
	(await _image()).save_png(sortie.path_join("repos_scene_nuit.png"))
	quit()

## Scénario continu pour Movie Maker (30 i/s imposés par --fixed-fps) : mannequin puis draugr actif.
func _film() -> void:
	RetourCoups.arret_actif = true
	await _monter({"draugr": "aucun", "sans-aide": ""})
	s.placer_joueur(Vector3(0, 0, 0.3), 0.0)
	for i in 30:
		await process_frame
	for c in 3:
		mains.attaquer(false)
		await create_timer(0.42).timeout
	await create_timer(0.6).timeout
	mains.entrees.appuyer()
	await create_timer(1.3).timeout
	mains.entrees.relacher()
	await create_timer(1.2).timeout
	# draugr : il arrive, on frappe, on pare, on frappe
	var d: CharacterBody3D = s.creer_draugr(Vector3(0.6, 0, -5.0), false)
	s.mannequin.position = Vector3(-2.2, 0, -1.5)
	for i in 420:
		await process_frame
		var vers := d.global_position - j.global_position
		vers.y = 0.0
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-vers.x, -vers.z), 0.15)
		if d.vivant() and vers.length() < 2.5:
			if d.etat == d.ATTAQUE and not mains.combat.attaque():
				mains.entrees.forcer_garde(0.4)
			elif i % 18 == 0:
				mains.attaquer(i % 72 == 0)
		if not d.vivant() and i > 60:
			break
	await create_timer(2.0).timeout


## Planches image par image (60 i/s) des 3 coups légers enchaînés et du coup lourd : chaque image est numérotée et
## porte l'état (préparation, tenue, frappe, suivi). Une planche par coup : <sortie>/coup_<n>_<geste>.png (grille 5 × 2).
func _coups_image_par_image() -> void:
	await _monter({"draugr": "aucun", "sans-aide": ""})
	mains.pas_manuel = true
	s.placer_joueur(Vector3(0, 0, 0.2), 0.0)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	var l := Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = Vector2(6, 330)
	calque.add_child(l)
	await _pas(0.6)
	for n in 4:
		var lourd := n == 3
		if lourd:
			await _pas(0.9)   # retour au repos avant le coup lourd
		mains.entrees.appuyer()
		var vues := []   # [étape, texte] puis image
		var i := 0
		var geste := ""
		var fini := false
		while not fini and i < 200:
			i += 1
			mains.avancer(DT)
			if lourd and i == 70:
				mains.entrees.relacher()
			elif not lourd and i == 2:
				mains.entrees.relacher()
			var e: int = mains.combat.etat
			if e == EtatCombat.CHARGE_LOURDE:
				if i == 30 or i == 69:
					vues.append(["charge", i])
				else:
					continue
			var etape := ""
			if e == EtatCombat.ATTAQUE_LEGERE or e == EtatCombat.ATTAQUE_LOURDE:
				geste = mains._geste_nom
				etape = "frappe" if mains._actif_lance else ("tenue" if mains._t_geste >= mains._duree_prep else "preparation")
			elif e == EtatCombat.RECUPERATION:
				etape = "suivi" if mains.combat.t < mains._duree_suivi else "retour"
				var fen: Array = mains._geste.get("enchainement", [0.05, 0.9])
				if etape == "retour" and (n < 2 or lourd) and mains.combat.t >= float(fen[0]) + 0.04:
					fini = true   # le coup suivant part ici (fenêtre de combo)
				if n == 2 and mains.combat.t > 0.16:
					fini = true
			elif e != EtatCombat.CHARGE_LOURDE:
				continue
			if lourd and e == EtatCombat.ATTAQUE_LEGERE and i != 6:
				continue   # coup lourd : bouton tenu, une seule image de la montée avant la charge
			if e != EtatCombat.CHARGE_LOURDE:
				if etape == "preparation" and i % 2 == 1:
					continue
				vues.append([etape, i])
			l.text = "Coup %d (%s) - image %02d (t = %d ms) - %s" % [n + 1, geste if geste != "" else "charge", vues.size(), roundi(i * DT * 1000.0), vues[vues.size() - 1][0]]
			await process_frame
			await process_frame
			vues[vues.size() - 1].append(await _image())
		var nom := "coup_%d_%s" % [n + 1, geste]
		var w := 320
		var h := 180
		var images := vues.filter(func(v: Array) -> bool: return v.size() > 2).slice(0, 15)
		var p := Image.create(w * 5, h * ceili(images.size() / 5.0), false, Image.FORMAT_RGBA8)
		for k in images.size():
			var im: Image = images[k][2]
			im.convert(Image.FORMAT_RGBA8)
			im.resize(w, h, Image.INTERPOLATE_BILINEAR)
			p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % 5) * w, (k / 5) * h))
		p.save_png(sortie.path_join(nom + ".png"))
		print("PLANCHE ", nom, " ", images.size(), " images")
		# coups 2 et 3 : l'appui du tour suivant tombe dans la fenêtre de combo du coup qui finit

## Les trois coups enchaînés puis le lourd, en continu (Movie Maker) ; ralenti < 1 : Engine.time_scale.
func _film_coups(ralenti: float) -> void:
	await _monter({"draugr": "aucun", "sans-aide": ""})
	s.placer_joueur(Vector3(0, 0, 0.2), 0.0)
	for i in 20:
		await process_frame
	Engine.time_scale = ralenti
	for boucle in 2:
		for c in 3:
			mains.entrees.appuyer()
			await create_timer(0.04).timeout
			mains.entrees.relacher()
			await create_timer(0.42).timeout
		await create_timer(0.6).timeout
		mains.entrees.appuyer()
		await create_timer(1.3).timeout
		mains.entrees.relacher()
		await create_timer(1.0).timeout
	Engine.time_scale = 1.0


# --- mesures des coups en espace écran -------------------------------------------------------------------------------

const SEUIL_LAME := 70.0
const SEUIL_ANGLE := 50.0
const SEUIL_BRAS := 15.0
const SEUIL_POIGNET := 15.0
var _mat_masque: ShaderMaterial

var _mat_vert: ShaderMaterial

func _masque_mat(vert := false) -> ShaderMaterial:
	if _mat_masque == null:
		for k in 2:
			var sh := Shader.new()
			sh.code = "shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled; void fragment() { ALBEDO = vec3(%s); }" % ["1.0, 0.0, 1.0", "0.0, 1.0, 0.0"][k]
			var m := ShaderMaterial.new()
			m.shader = sh
			if k == 0:
				_mat_masque = m
			else:
				_mat_vert = m
	return _mat_vert if vert else _mat_masque

var _attaches := {}
var _pointe_prec := Vector3.INF

## Position monde d'un os APRÈS les modificateurs (IK) : lue sur un BoneAttachment3D (get_bone_global_pose rend la
## pose sans les modificateurs en dehors de leur passe).
func _os_global(sq: Skeleton3D, nom: String) -> Vector3:
	if not _attaches.has(nom) or not is_instance_valid(_attaches[nom]):
		var b := BoneAttachment3D.new()
		b.bone_name = nom
		sq.add_child(b)
		_attaches[nom] = b
	return (_attaches[nom] as Node3D).global_position

## Mesures de l'image courante : [lame %, angle °, bras %, poignet °, garde écran, pointe écran].
func _mesurer_image() -> Array:
	var cam: Camera3D = j.camera
	var vp := root.get_viewport()
	var taille := vp.get_visible_rect().size
	# masque : bras en magenta plat, torche écartée (on mesure la main et le bras DROITS), HUD masqué
	var mailles: Array = mains.bras.find_children("*", "MeshInstance3D", true, false).filter(func(mi: Node) -> bool:
		return not mains._accroche_d.is_ancestor_of(mi) and not mains._accroche_g.is_ancestor_of(mi))
	for mi: MeshInstance3D in mailles:
		mi.material_override = _masque_mat()
	# torche (et main gauche) en vert : elle peut cacher la lame, elle ne compte pas dans la couverture du bras droit
	# (flamme et halo sont des cartes à fond transparent, les étincelles des points : masqués, pas comptés)
	var cartes: Array = mains._visuels_torche + mains.flammes
	var vertes: Array = mains._accroche_g.find_children("*", "GeometryInstance3D", true, false).filter(func(gi: Node) -> bool: return not gi in cartes)
	var mats_torche := []
	for gi: GeometryInstance3D in vertes:
		mats_torche.append(gi.material_override)
		gi.material_override = _masque_mat(true)
	var vis_cartes := []
	for c: Node3D in cartes:
		vis_cartes.append(c.visible)
		c.visible = false
	s.hud.visible = false
	var calques := s.find_children("*", "CanvasLayer", true, false)
	for c: CanvasLayer in calques:
		c.visible = false
	mains.trainee.visible = false
	await process_frame
	await process_frame
	var masque := await _image()   # occultation : bras (magenta) et torche (vert)
	# couverture du bras droit seul : main gauche et torche écartées hors champ
	var torche_avant: Transform3D = mains.pivot_torche.transform
	mains.pivot_torche.transform = Transform3D(Basis(), Vector3(-3.0, -3.0, 0.5))
	await process_frame
	await process_frame
	var masque_d := await _image()
	mains.pivot_torche.transform = torche_avant
	for mi: MeshInstance3D in mailles:
		mi.material_override = null
	for k in vertes.size():
		(vertes[k] as GeometryInstance3D).material_override = mats_torche[k]
	for k in cartes.size():
		(cartes[k] as Node3D).visible = vis_cartes[k]
	s.hud.visible = true
	for c: CanvasLayer in calques:
		c.visible = true
	mains.trainee.visible = true
	await process_frame   # l'IK reprend la torche à sa place avant l'image normale
	await process_frame
	masque_d.convert(Image.FORMAT_RGBA8)
	masque.convert(Image.FORMAT_RGBA8)
	var w := masque.get_width()
	var h := masque.get_height()
	var ech := Vector2(w, h) / taille
	var nb := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := masque_d.get_pixel(x, y)
			if c.r > 0.6 and c.b > 0.6 and c.g < 0.35:
				nb += 1
	var bras_pc := 100.0 * nb / float((w / 2) * (h / 2))
	# lame affichée (modèle tenu par l'os de la main)
	var xf: Transform3D = mains._modele_arme_d.global_transform
	var g: Vector3 = xf * mains._garde_lame
	var t: Vector3 = xf * mains._pointe_lame
	var vus := 0
	var n := 24
	for i in n + 1:
		var p := g.lerp(t, float(i) / n)
		if cam.is_position_behind(p):
			continue
		var e := cam.unproject_position(p)
		if e.x < 0 or e.y < 0 or e.x >= taille.x or e.y >= taille.y:
			continue
		var c := masque.get_pixel(clampi(int(e.x * ech.x), 0, w - 1), clampi(int(e.y * ech.y), 0, h - 1))
		if (c.r > 0.6 and c.b > 0.6 and c.g < 0.35) or (c.g > 0.6 and c.r < 0.35 and c.b < 0.35):
			continue   # cachée par la main / le bras droit ou par la torche
		vus += 1
	var lame_pc := 100.0 * vus / float(n + 1)
	var dir := (t - g).normalized()
	var visee := ((g + t) * 0.5 - cam.global_position).normalized()
	var angle := rad_to_deg(acos(clampf(absf(dir.dot(visee)), 0.0, 1.0)))
	# avant-bras / poignée à l'écran
	var sq: Skeleton3D = mains._sq
	var main := _os_global(sq, "hand_r")
	var coude := _os_global(sq, "lowerarm_r")
	var f := (main - coude).normalized()
	var f2 := cam.unproject_position(main + f * 0.03) - cam.unproject_position(main)
	var b2 := cam.unproject_position(t) - cam.unproject_position(g)
	var poignet := rad_to_deg(absf(f2.angle_to(b2))) if f2.length() > 0.01 and b2.length() > 0.01 else 0.0
	# tranchant devant : angle entre le fil de la lame (X du modèle) et le mouvement de la pointe, tous deux pris
	# perpendiculairement à la lame (lame à deux tranchants : replié sur 0-90°)
	var fil := -1.0
	if _pointe_prec != Vector3.INF and t.distance_to(_pointe_prec) > 0.004:
		var mv := (t - _pointe_prec)
		mv = (mv - dir * mv.dot(dir)).normalized()
		var x := xf.basis.x.normalized()
		x = (x - dir * x.dot(dir)).normalized()
		fil = rad_to_deg(acos(clampf(absf(x.dot(mv)), 0.0, 1.0)))
	_pointe_prec = t
	return [lame_pc, angle, bras_pc, poignet, cam.unproject_position(g) / taille, cam.unproject_position(t) / taille, fil]

func _coups_mesures() -> void:
	var opts := {"draugr": "aucun", "sans-aide": ""}
	if _arg("nuit") != "":
		opts["nuit"] = ""
	await _monter(opts)
	print("BRAS épaule %s, bras %.3f, avant-bras %.3f" % [mains._bras_base * mains._epaule_bras, mains._l_bras, mains._l_avant_bras])
	for nom in ["hand_r", "lowerarm_r", "upperarm_r", "hand_l"]:
		_os_global(mains._sq, nom)
	mains.pas_manuel = true
	mains.passifs.amplitude = 0.0
	s.placer_joueur(Vector3(0, 0, 0.2), 0.0)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	var l := Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 262)
	calque.add_child(l)
	var arme_id := _arg("arme", "")
	if arme_id != "":
		mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % arme_id))
		await _pas(0.6)
	await _pas(0.6)
	var dossier := sortie
	var resume := []
	# --gestes=a,b : chaque geste isolé depuis le repos (directions contextuelles) ; sinon combo 1-2-3 puis lourd
	var forces: Array = Array(_arg("gestes", "").split(",", false))
	var nb_seq := forces.size() if not forces.is_empty() else 4
	for n in nb_seq:
		var force: String = forces[n] if not forces.is_empty() else ""
		var lourd := n == 3 and force == ""
		if lourd or force != "":
			await _pas(0.9)
		mains.entrees.appuyer()
		var vues := []
		var i := 0
		var geste := ""
		var fini := false
		var mins := [1e9, 1e9, 1e9, 1e9]
		var maxs := [-1e9, -1e9, -1e9, -1e9]
		var viol := 0
		var fil_max := 0.0
		while not fini and i < 220:
			i += 1
			mains.avancer(DT)
			if i == 1 and force != "":
				mains._geste_nom = force
				mains._preparer_geste(false)
			if lourd and i == 50:
				mains.entrees.relacher()
			elif not lourd and i == 2:
				mains.entrees.relacher()
			var e: int = mains.combat.etat
			var etape := ""
			if e == EtatCombat.CHARGE_LOURDE:
				if i != 49:
					continue
				etape = "charge"
			elif e == EtatCombat.ATTAQUE_LEGERE or e == EtatCombat.ATTAQUE_LOURDE:
				geste = mains._geste_nom
				etape = "frappe" if mains._actif_lance else ("tenue" if mains._t_geste >= mains._duree_prep else "armer")
				if lourd and e == EtatCombat.ATTAQUE_LEGERE:
					continue
			elif e == EtatCombat.RECUPERATION:
				etape = "suivi" if mains.combat.t < mains._duree_suivi else "retour"
				var fen: Array = mains._geste.get("enchainement", [0.05, 0.9])
				if etape == "retour" and n < 2 and force == "" and mains.combat.t >= float(fen[0]) + 0.05:
					fini = true
				if (n >= 2 or force != "") and mains.combat.t > 0.2:
					fini = true
			else:
				continue
			await process_frame
			await process_frame
			var m: Array = await _mesurer_image()
			var actif := etape == "frappe"
			var mauvais: bool = actif and (m[0] < SEUIL_LAME or m[1] < SEUIL_ANGLE or m[2] > SEUIL_BRAS or m[3] > SEUIL_POIGNET)
			if actif:
				for k in 4:
					mins[k] = minf(mins[k], m[k])
					maxs[k] = maxf(maxs[k], m[k])
				if mauvais:
					viol += 1
			l.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if mauvais else (Color(1, 0.95, 0.5) if actif else Color(0.85, 0.85, 0.85)))
			l.text = "C%d %s #%02d %s %dms\nlame %d%%  angle %d  bras %.1f%%  poignet %d  fil %s" % [n + 1, geste, vues.size() + 1, etape, roundi(i * DT * 1000.0), roundi(m[0]), roundi(m[1]), m[2], roundi(m[3]), "-" if m[6] < 0.0 else str(roundi(m[6]))]
			if actif and m[6] >= 0.0:
				fil_max = maxf(fil_max, m[6])
			print("MESURE C%d %-15s #%02d %-7s lame %5.1f%% angle %4.1f bras %5.2f%% poignet %4.1f garde %s pointe %s | torche %s main_g %s | visé %.0f, épaule→main %.2f" % [n + 1, geste, vues.size() + 1, etape, m[0], m[1], m[2], m[3], (m[4] as Vector2).snapped(Vector2.ONE * 0.01), (m[5] as Vector2).snapped(Vector2.ONE * 0.01), mains.pivot_torche.transform.origin.snapped(Vector3.ONE * 0.01), (mains.global_transform.affine_inverse() * _os_global(mains._sq, "hand_l")).snapped(Vector3.ONE * 0.01), mains.ecart_coude, ((mains.pivot_epee.transform * mains.PRISE_D.affine_inverse()).origin).distance_to(mains._bras_base * mains._epaule_bras) / (mains._l_bras + mains._l_avant_bras)])
			var inv: Transform3D = mains.global_transform.affine_inverse()
			print("   coude réel %s visé %s | main réelle %s visée %s | épaule réelle %s" % [(inv * _os_global(mains._sq, "lowerarm_r")).snapped(Vector3.ONE * 0.01), mains.coude_vise.snapped(Vector3.ONE * 0.01), (inv * _os_global(mains._sq, "hand_r")).snapped(Vector3.ONE * 0.01), (mains.pivot_epee.transform * mains.PRISE_D.affine_inverse()).origin.snapped(Vector3.ONE * 0.01), (inv * _os_global(mains._sq, "upperarm_r")).snapped(Vector3.ONE * 0.01)])
			var img := await _image()
			vues.append(img)
		var nom := ("geste_%s" % geste) if force != "" else "coup_%d_%s" % [n + 1, geste]
		var w := 384
		var h := 216
		var images := vues.slice(0, 20)
		var p := Image.create(w * 5, h * ceili(images.size() / 5.0), false, Image.FORMAT_RGBA8)
		for k in images.size():
			var im: Image = images[k]
			im.convert(Image.FORMAT_RGBA8)
			im.resize(w, h, Image.INTERPOLATE_BILINEAR)
			p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % 5) * w, (k / 5) * h))
		p.save_png(dossier.path_join(nom + ".png"))
		var ligne := "RESUME C%d %-15s images %d | frappe : lame %.0f-%.0f %% | angle %.0f-%.0f | bras %.1f-%.1f %% | poignet %.0f-%.0f | fil/mouvement max %.0f | violations %d" % [n + 1, geste, images.size(), mins[0], maxs[0], mins[1], maxs[1], mins[2], maxs[2], mins[3], maxs[3], fil_max, viol]
		resume.append(ligne)
		print("PLANCHE ", nom, " ", images.size(), " images")
	for r in resume:
		print(r)
