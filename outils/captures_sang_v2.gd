extends SceneTree
## Planches et film du SANG V2 (combat/sang_v2) dans scenes/test_combat.tscn (FENÊTRE hors écran, godot_slot.sh) :
##   godot --path . --script res://outils/captures_sang_v2.gd -- --sortie=<dossier> [--film] [--avant]
## Planche : lame propre → sanglante (1, 3, 6 coups) → sèche → qui s'efface ; entaille qui coule (0 à 4 s) ; ennemi taché.
## --film : vue de jeu, coups réels sur 3 draugrs serrés puis l'arme au repos (ajouter --write-movie <f.avi> --fixed-fps 30 avant « -- ») ;
## --avant : sang v2 coupé (SangLame.actif = faux : ni lame, ni taches, ni coulures, ni gouttes) pour le film « avant ».

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")

var s: Node3D
var sortie := ""
var film := false
var _n := 0
var _cam: Camera3D
var _titre: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _attendre(t: float) -> void:
	for i in maxi(1, roundi(t * 30.0 if film else t * 60.0)):
		await process_frame

func _planche(nom: String, images: Array, colonnes: int, w := 640, h := 360) -> void:
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % colonnes) * w, (i / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

func _ennemi(pos: Vector3, lacet: float, genre := "guerrier") -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "capt_sang_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 5000.0
	d.vie_max = 5000.0
	d.combat.profil.chance_blocage = 0.0
	return d

func _info(d: Node3D, h: float, dir: Vector3, attaque := "legere") -> Dictionary:
	var vers: Vector3 = s.joueur.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	return {"type": "tranchant", "point": d.global_position + Vector3(0, h, 0) + vers * 0.2, "direction": dir.normalized(),
		"normale": vers, "attaque": attaque, "instant": 0.1, "charge": 0.0, "arme": "epee_metal"}

func _legende(t: String) -> void:
	_titre.text = t

func _go() -> void:
	sortie = _arg("sortie", "user://captures_sang_v2")
	film = _arg("film") != ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	SangLame.actif = _arg("avant") == ""
	Sang.niveau_force = 2
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var calque := CanvasLayer.new()
	calque.layer = 10
	root.add_child(calque)
	_titre = Label.new()
	_titre.add_theme_font_override("font", Palette.police())
	_titre.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE * 2)
	_titre.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_titre.add_theme_constant_override("outline_size", 4)
	_titre.position = Vector2(8, 6)
	calque.add_child(_titre)
	await _attendre(0.5)
	if film:
		await _film()
	else:
		await _planches()
	quit()

# ------------------------------------------------------------------ film (vue de jeu)

func _film() -> void:
	_legende("AVANT (sang v1)" if not SangLame.actif else "APRÈS : sang v2")
	s.placer_joueur(Vector3(0, 0, 0.4), 0.0, -4.0)
	var cibles := [_ennemi(Vector3(-0.75, 0, -1.25), deg_to_rad(-20.0)), _ennemi(Vector3(0.15, 0, -1.45), 0.0), _ennemi(Vector3(1.0, 0, -1.3), deg_to_rad(25.0))]
	s.mannequin.position = Vector3(-6.0, 0, 5.0)
	for d in cibles:
		d.set_physics_process(false)
		d.combat.profil.posture_max = 1e6   # pas de posture brisée ni de finisher : on montre le sang, pas la mise à mort
		d.combat.posture = 1e6
	await _attendre(1.0)
	var j: CharacterBody3D = s.joueur
	var mains = j.mains
	# balayage : on vise tour à tour les trois draugrs, coups légers enchaînés, un coup lourd au milieu
	var ordre := [1, 0, 1, 2, 1, 0, 2, 1, 1, 2]
	for k in ordre.size():
		var d: Node3D = cibles[ordre[k]]
		var vers := d.global_position - j.global_position
		var lacet := atan2(-vers.x, -vers.z)
		for f in 9:
			j.rotation.y = lerp_angle(j.rotation.y, lacet, 0.35)
			await process_frame
		if k == 4:
			mains.entrees.appuyer()
			await _attendre(1.0)
			mains.entrees.relacher()
			await _attendre(0.9)
		else:
			mains.attaquer(false)
			await _attendre(0.55)
	# l'arme au repos : la lame sanglante, les entailles qui coulent, les gouttes
	for f in 30:
		j.rotation.y = lerp_angle(j.rotation.y, 0.0, 0.2)
		await process_frame
	await _attendre(5.0)

# ------------------------------------------------------------------ planches

## Caméra de capture sur la lame (repère de l'épée : +Y le long de la lame, ±Z les plats).
func _cam_lame() -> void:
	var l := SangLame.instance
	var xf := l.global_transform
	var milieu := xf * l.garde.lerp(l.pointe, 0.66)
	var axe := (xf.basis * (l.pointe - l.garde)).normalized()
	var plat := (xf.basis * Vector3(0, 0, 1)).normalized()
	if plat.dot(Vector3(-0.4, 0.75, 0.55)) < 0.0:
		plat = -plat   # le plat éclairé par le soleil de la scène
	_cam.fov = 42.0
	_cam.global_position = milieu + plat * 0.55
	_cam.look_at(milieu, axe.cross(plat).normalized())   # la lame en travers de l'image

## Vue rapprochée de la lame puis vue de jeu (caméra du joueur), même instant.
func _deux_vues(vues_proche: Array, vues_jeu: Array, legende: String) -> void:
	await _attendre(0.9)   # les gouttes lâchées pendant l'avance rapide sont tombées
	_cam_lame()
	_cam.current = true
	_legende(legende + " (lame de près)")
	vues_proche.append(await _image())
	s.joueur.camera.current = true
	_legende(legende + " (vue de jeu)")
	vues_jeu.append(await _image())

func _planches() -> void:
	var j: CharacterBody3D = s.joueur
	s.placer_joueur(Vector3(0, 0, 0.4), 0.0, -4.0)
	var a := _ennemi(Vector3(0.0, 0, -1.3), 0.0)
	var b := _ennemi(Vector3(0.9, 0, -1.45), deg_to_rad(-60.0))
	var c := _ennemi(Vector3(-0.9, 0, -1.5), deg_to_rad(50.0))
	for d in [a, b, c]:
		d.set_physics_process(false)
	await _attendre(1.0)
	_cam = Camera3D.new()
	s.add_child(_cam)
	# --- 1. lame : propre → 1, 3, 6 coups → sèche → s'efface
	var lame := SangLame.instance
	var proche := []
	var jeu := []
	j.mains.set_process(false)   # bras figés : la lame ne bouge pas entre les vues
	await _deux_vues(proche, jeu, "lame propre")
	var coups := 0
	for cible_n in [1, 3, 6]:
		while coups < cible_n:
			a.recevoir_coup(5.0, j.global_position, false, _info(a, 1.3, Vector3(1, -0.3, 0), "lourde" if coups % 2 else "legere"))
			coups += 1
			await _attendre(0.1)
		await _attendre(1.7 if cible_n == 6 else 0.0)
		await _deux_vues(proche, jeu, "%d coup%s" % [cible_n, "s" if cible_n > 1 else ""] + (" (le sang coule)" if cible_n == 6 else ""))
	for etape in [[14.0, "sèche (17 s)"], [8.0, "s'efface (25 s)"], [8.0, "s'efface (33 s)"], [11.0, "presque propre (44 s)"]]:
		for k in int(etape[0]):
			lame._process(1.0)
		await _deux_vues(proche, jeu, etape[1])
	var vues := proche.slice(0, 4) + jeu.slice(0, 4) + proche.slice(4, 8) + jeu.slice(4, 8)
	_planche("lame_propre_sanglante_efface", vues, 4)
	lame.nettoyer()
	j.mains.set_process(true)
	# --- 2. entaille qui coule : un draugr (sang sombre) puis un bandit (sang vif), coup au torse, 0 à 6 s
	vues = []
	var px := 2.6
	for genre in ["guerrier", "bandit"]:
		var pe := Vector3(px, 0, -1.2)
		px += 2.4
		s.placer_joueur(Vector3(pe.x, 0, 0.4), 0.0, -4.0)
		var e := _ennemi(pe, atan2(0.0, -1.6) + PI, genre)
		await _attendre(0.5)
		e.set_physics_process(false)
		await _attendre(0.3)
		e.recevoir_coup(5.0, j.global_position, false, _info(e, 0.9 if genre != "bandit" else 0.98, Vector3(1, -0.3, 0)))
		var pl: Array = e.modele.get_meta("plaies", [])
		var dp: Decal = pl.back()
		await process_frame
		var nrm := dp.global_basis.y.normalized()
		nrm.y = 0.0
		nrm = nrm.normalized() if nrm.length() > 0.1 else Vector3(0, 0, 1)
		# pose figée (animations en pause) : la plaie reste cadrée pendant qu'elle coule
		e.set_process(false)
		for ap: AnimationPlayer in e.find_children("*", "AnimationPlayer", true, false):
			ap.pause()
		for at: AnimationTree in e.find_children("*", "AnimationTree", true, false):
			at.active = false
		for m: Node in e.find_children("*", "SkeletonModifier3D", true, false):
			m.set("active", false)
		await process_frame
		_cam.fov = 30.0
		_cam.global_position = dp.global_position + nrm * 1.15 + Vector3(0, 0.12, 0)
		_cam.look_at(dp.global_position + Vector3(0, 0.03, 0), Vector3.UP)
		_cam.current = true
		var t := 0.0
		for inst in [0.1, 1.2, 2.6, 6.0]:
			await _attendre(inst - t)
			t = inst
			_legende("entaille %s  t = %.1f s" % ["draugr" if genre != "bandit" else "bandit", inst])
			vues.append(await _image())
	s.placer_joueur(Vector3(0, 0, 0.4), 0.0, -4.0)
	_cam.current = true
	_planche("entaille_qui_coule", vues, 4)
	# --- 3. ennemi taché : coups sur A vers B et vers C ; vues de B et C (côté de A), puis plan large et vue de jeu
	vues = []
	for k in 4:
		a.recevoir_coup(5.0, j.global_position, false, _info(a, 1.35, Vector3(1, -0.1, 0) if k % 2 == 0 else Vector3(-1, -0.1, 0), "lourde"))
		await _attendre(0.25)
	await _attendre(1.0)
	for v in [b, c]:
		var vb: Vector3 = (a.global_position - v.global_position)
		vb.y = 0
		vb = vb.normalized()
		var vj: Vector3 = (j.global_position - v.global_position)
		vj.y = 0
		vj = vj.normalized()
		var centre: Vector3 = v.global_position + Vector3(0, 1.15, 0)
		_cam.fov = 45.0
		_cam.global_position = centre + (vb * 0.8 + vj).normalized() * 1.3 + Vector3(0, 0.15, 0)
		_cam.look_at(centre, Vector3.UP)
		_legende("voisin taché par la giclée (%d tache(s))" % Plaies.nombre_taches(v.modele))
		vues.append(await _image())
	_cam.global_position = Vector3(0.1, 1.55, 0.6)
	_cam.look_at(Vector3(0.0, 1.0, -1.4), Vector3.UP)
	_cam.fov = 55.0
	_legende("plan large : 3 draugrs")
	vues.append(await _image())
	j.camera.current = true
	await _attendre(0.5)
	_legende("vue de jeu")
	vues.append(await _image())
	_planche("ennemi_tache", vues, 2)
