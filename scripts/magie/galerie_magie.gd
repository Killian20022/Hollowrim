extends Node3D
## Galerie des visuels de la magie (scenes/galerie_magie.tscn) : joue chaque effet de EffetsMagie l'un après l'autre,
## en vue FPS avec la VRAIE main gauche du héros (bras_fps, mains.gd du joueur réel ; la torche est rangée et la main
## gauche est posée paume en avant par CE script, sans toucher à mains.gd) ou en vue de côté, dans une crypte de nuit
## ou dehors de jour. Cibles : draugrs (DraugrNordique.creer, figés).
##   godot --path . res://scenes/galerie_magie.tscn -- [--lieu=crypte|dehors] [--vue=fps|cote] [--plans=a,b,...]
##       [--captures=<dossier>]   une image PNG au milieu de chaque plan (<lieu>_<vue>_<plan>.png), puis quitte
##       [--perf]                 mesure : temps d'image sans effet, puis avec 3 effets simultanés + 5 cibles avec statut
##       [--boucle]               rejoue la suite sans fin (démonstration)
##   Vidéo Movie Maker : --write-movie <fichier.avi> --fixed-fps 30 -- --lieu=crypte (quitte à la fin de la suite).

const JOUEUR := preload("res://scripts/joueur.gd")
const POST := preload("res://shaders/ps1_post.gdshader")

## Plans : [nom, durée (s), instant de la capture (s)].
const PLANS := [
	["aura_feu", 2.2, 1.6], ["jet_feu", 2.4, 1.2], ["boule_feu", 2.4, 0.16], ["explosion_feu", 2.0, 0.42], ["zone_feu", 2.6, 0.5],
	["aura_glace", 2.0, 1.4], ["eclat_glace", 2.2, 0.12], ["lance_givre", 2.4, 0.1], ["souffle_givre", 2.4, 1.2], ["nova_gelee", 2.8, 0.7],
	["aura_electricite", 2.0, 1.4], ["arc_electrique", 2.4, 1.0], ["chaine_eclairs", 1.8, 0.15], ["tempete_statique", 3.0, 1.2],
	["aura_tenebres", 2.0, 1.4], ["trait_ombre", 2.2, 0.14], ["drain_vie", 2.4, 1.2], ["explosion_obscure", 2.8, 0.6],
	["soin", 2.4, 1.2], ["protection", 2.4, 1.2],
	["statuts", 3.0, 1.5], ["enchant_feu", 1.6, 1.0], ["enchant_glace", 1.6, 1.0], ["enchant_electricite", 1.6, 1.0], ["enchant_tenebres", 1.6, 1.0],
	["vapeur", 1.6, 0.35], ["decharge", 1.6, 0.2], ["decharge_incendiaire", 1.6, 0.2], ["cristaux_corrompus", 1.8, 0.5],
	["flammes_obscures", 1.8, 0.6], ["arcs_violets", 1.6, 0.2],
	["double_feu", 2.4, 1.4], ["double_glace", 2.4, 0.45], ["double_electricite", 2.4, 1.2], ["double_tenebres", 2.4, 1.2],
]

## Angles d'Euler (°) candidats de la main gauche (--balayage).
const BALAYAGE := [[15, -80, -15], [-60, -80, -15], [-60, -60, 0], [-80, -90, 0], [60, -80, -15], [0, -80, -80],
	[0, -80, 80], [-40, -120, -30], [-40, -40, 30], [30, -150, 0], [-90, 0, 0], [0, 0, -90]]
## Pose retenue (main gauche en incantation) : angles d'Euler (°) et position dans le repère des mains.
const POSE_EULER := Vector3(-40, -120, -30)
const POSE_POS := Vector3(-0.34, -0.2, -0.42)

var lieu := "crypte"
var vue := "fps"
var joueur: CharacterBody3D
var mains: Node3D
var obs: Camera3D
var paume_g: Node3D
var paume_d: Node3D
var cibles: Array[Node3D] = []
var post: ShaderMaterial
var dossier := ""
var _plans: Array = []
var _i := -1
var _t := 0.0
var _capture_faite := false
var _boucle := false
var _projectiles: Array = []   # [noeud, depart, arrivee, t, duree, ecole]
var _pose_ok := false
var _texte: Label

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _ready() -> void:
	process_priority = 50   # après mains.gd (pose de la main gauche), avant GestionMagie (100)
	lieu = _arg("lieu", "crypte")
	vue = _arg("vue", "fps")
	dossier = _arg("captures")
	_boucle = _arg("boucle") != ""
	var filtre := _arg("plans")
	for p in PLANS:
		if filtre == "" or filtre.split(",").has(p[0]):
			_plans.append(p)
	if _arg("balayage") != "":
		# réglage de la pose de la main gauche : une capture par jeu d'angles (outil de mise au point)
		_plans.clear()
		for k in BALAYAGE.size():
			_plans.append(["pose_%d" % k, 1.0, 0.8])
	_decor()
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	add_child(joueur)
	joueur.global_position = Vector3(0, 0.05, 0)
	mains = joueur.mains
	obs = Camera3D.new()
	obs.fov = 66.0
	add_child(obs)
	obs.position = Vector3(5.2, 1.6, -5.0)
	obs.look_at(Vector3(-0.3, 1.0, -2.6))
	for i in 3:
		var d := DraugrNordique.creer({})
		add_child(d)
		d.position = Vector3(-1.6 + i * 1.6, 0.0, -6.0 - absf(i - 1) * 0.6)
		d.add_to_group("cibles_magie")   # sans collision : les jets les trouvent par ce groupe
		cibles.append(d)
	_interface()
	_preparer_mains.call_deferred()
	if _arg("perf") != "":
		_perf.call_deferred()

# ---------------------------------------------------------------- décor

func _decor() -> void:
	var nuit := lieu == "crypte"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.035) if nuit else Color(0.52, 0.58, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.1, 0.16) if nuit else Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.25 if nuit else 0.75
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.05 if nuit else 0.012
	env.glow_enabled = not nuit
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	if not nuit:
		var soleil := DirectionalLight3D.new()
		soleil.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
		soleil.light_color = Color(1.0, 0.94, 0.85)
		soleil.light_energy = 1.1
		soleil.shadow_enabled = true
		add_child(soleil)
	var pierre := Palette.tex("sol_pierre_galerie", ["#1d1919", "#2c2424", "#393130", "#4a3a30"], 4, 0.5)
	var neige := Palette.tex("sol_neige_test", Palette.NEIGE, 4, 0.3)
	var mur := Palette.tex("mur_galerie", ["#141010", "#1d1919", "#2c2424", "#393130"], 4, 0.6)
	if nuit:
		_bloc(Vector3(14, 0.2, 18), Vector3(0, -0.1, -4), pierre, Vector2(7, 9))
		_bloc(Vector3(14, 5, 0.6), Vector3(0, 2.5, -12.5), mur, Vector2(7, 3))
		_bloc(Vector3(0.6, 5, 18), Vector3(-6.5, 2.5, -4), mur, Vector2(9, 3))
		_bloc(Vector3(0.6, 5, 18), Vector3(6.5, 2.5, -4), mur, Vector2(9, 3))
		for z in [1.5, -8.0]:
			for x in [-4.0, 4.0]:
				_bloc(Vector3(0.8, 4.0, 0.8), Vector3(x, 2.0, z), mur, Vector2(1, 3))
		for p: Vector3 in [Vector3(-6.0, 2.2, -6.0), Vector3(6.0, 2.2, -9.0)]:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.3)
			l.light_energy = 1.3
			l.omni_range = 6.0
			add_child(l)
			l.position = p
	else:
		_bloc(Vector3(40, 0.2, 40), Vector3(0, -0.1, -6), neige, Vector2(20, 20))
		for p: Vector3 in [Vector3(-5, 1.4, -9), Vector3(5.5, 1.1, -11), Vector3(-7, 1.6, -3)]:
			_bloc(Vector3(1.4, p.y * 2.0, 1.2), p, Palette.tex("roche", Palette.ROCHE, 4, 0.5), Vector2(1, 2))

func _bloc(taille: Vector3, pos: Vector3, tex: Texture2D, uv: Vector2) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	cs.shape = b
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := Palette.materiau(tex, uv)
	m.set_shader_parameter("tex_neige", tex)
	mi.material_override = m
	sb.add_child(mi)
	add_child(sb)
	sb.position = pos

func _interface() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST
	rect.material = post
	calque.add_child(rect)
	_texte = Label.new()
	_texte.add_theme_font_override("font", Palette.police())
	_texte.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	_texte.add_theme_color_override("font_color", Color("#e8e0c8"))
	_texte.add_theme_color_override("font_shadow_color", Color("#0b0f1a"))
	_texte.position = Vector2(8, 6)
	_texte.visible = dossier == ""
	calque.add_child(_texte)

# ---------------------------------------------------------------- mains

## Main gauche du héros : torche rangée hors de vue, doigts ouverts, et deux repères « paume » (point d'où jaillit le sort).
func _preparer_mains() -> void:
	mains.porte_torche.visible = false
	var sq: Skeleton3D = mains._sq
	for i in mains._doigts.keys():
		var n := sq.get_bone_name(i)
		if n.ends_with("_l") or n.ends_with(".L"):
			# main ouverte, doigts légèrement fléchis (pose de repos du squelette, un peu repliée)
			var repos := sq.get_bone_rest(i).basis.get_rotation_quaternion()
			mains._doigts[i] = repos.slerp(mains._doigts[i], 0.18)
	paume_g = Node3D.new()
	paume_g.name = "PaumeG"
	mains._accroche_g.add_child(paume_g)
	paume_g.position = Vector3(0, 0.09, 0.03)
	paume_d = Node3D.new()
	paume_d.name = "PaumeD"
	mains._accroche_d.add_child(paume_d)
	paume_d.position = Vector3(0, 0.09, 0.03)
	(joueur.camera if vue == "fps" else obs).current = true
	_pose_ok = true

## Pose de la main gauche (après mains.gd) : avant-bras tendu, paume vers l'avant, comme les poses d'incantation.
func _poser_main_gauche() -> void:
	if not _pose_ok:
		return
	var avance := 1.0
	var nom: String = _plans[_i][0] if _i >= 0 and _i < _plans.size() else ""
	if nom.begins_with("enchant") or nom == "statuts":
		avance = 0.0
	var repos: Transform3D = mains.pivot_torche.transform
	var e := POSE_EULER
	if nom.begins_with("pose_"):
		var a: Array = BALAYAGE[int(nom.trim_prefix("pose_"))]
		e = Vector3(a[0], a[1], a[2])
	var b := Basis.from_euler(e * (PI / 180.0))
	var lance := Transform3D(b, POSE_POS)
	mains.pivot_torche.transform = repos.interpolate_with(lance, avance)

# ---------------------------------------------------------------- déroulé

func _process(dt: float) -> void:
	_poser_main_gauche()
	_maj_projectiles(dt)
	if not _pose_ok or _plans.is_empty() or _arg("perf") != "":
		return
	if _i < 0:
		_i = 0
		_t = 0.0
		_debut(_plans[0][0])
	_t += dt
	var p: Array = _plans[_i]
	if String(p[0]).begins_with("pose_"):
		EffetsMagie.aura_main(paume_g, "feu", 1.0)
	_pendant(p[0], _t)
	if dossier != "" and not _capture_faite and _t >= float(p[2]):
		_capture_faite = true
		_capturer("%s_%s_%s" % [lieu, vue, p[0]])
	if _t >= float(p[1]):
		_fin(p[0])
		_i += 1
		_t = 0.0
		_capture_faite = false
		if _i >= _plans.size():
			if _boucle:
				_i = 0
			else:
				_terminer.call_deferred()
				set_process(false)
				return
		_debut(_plans[_i][0])

func _terminer() -> void:
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", EffetsMagie.stats())

func _vise(i := 1) -> Vector3:
	return cibles[clampi(i, 0, cibles.size() - 1)].global_position + Vector3.UP * 1.1

func _dir_vers(o: Node3D, cible: Vector3) -> Vector3:
	return (cible - o.global_position).normalized()

func _tirer(ecole: String, forme: String, cible: Vector3, duree := 0.45, depuis: Node3D = null) -> void:
	var o: Node3D = depuis if depuis != null else paume_g
	var p := EffetsMagie.projectile_visuel(ecole, forme)
	add_child(p)
	p.global_position = o.global_position + _dir_vers(o, cible) * 0.15
	_projectiles.append([p, p.global_position, cible, 0.0, duree, ecole, forme])

func _maj_projectiles(dt: float) -> void:
	var i := _projectiles.size() - 1
	while i >= 0:
		var e: Array = _projectiles[i]
		e[3] += dt
		var k := clampf(e[3] / e[4], 0.0, 1.0)
		var p: Node3D = e[0]
		p.global_position = (e[1] as Vector3).lerp(e[2], k)
		if k >= 1.0:
			var n := ((e[1] as Vector3) - (e[2] as Vector3)).normalized()
			EffetsMagie.impact(e[5], e[2], n, 1.3 if e[6] == "lance" else 1.0)
			if e[5] == "glace":
				EffetsMagie.statut_cible(cibles[1], "gel", 2.0)
			elif e[5] == "tenebres":
				EffetsMagie.statut_cible(cibles[1], "corruption", 2.0)
			elif e[5] == "feu":
				EffetsMagie.statut_cible(cibles[1], "brulure", 2.0)
			p.queue_free()
			_projectiles.remove_at(i)
		i -= 1

func _debut(nom: String) -> void:
	_texte.text = nom.replace("_", " ")
	var sol_c := Vector3(0, 0, -6.2)
	match nom:
		"boule_feu":
			EffetsMagie.aura_main(paume_g, "feu", 1.0)
			_tirer("feu", "boule", _vise())
		"explosion_feu":
			EffetsMagie.aura_main(paume_g, "feu", 1.0)
			_tirer("feu", "boule", _vise(), 0.3)
		"zone_feu":
			EffetsMagie.zone("feu", sol_c, 2.6, 2.2)
		"eclat_glace":
			EffetsMagie.aura_main(paume_g, "glace", 1.0)
			for k in 3:
				_tirer("glace", "eclat", _vise(k), 0.35 + k * 0.05)
		"lance_givre":
			EffetsMagie.aura_main(paume_g, "glace", 1.0)
			_tirer("glace", "lance", _vise(), 0.55)
		"nova_gelee":
			EffetsMagie.zone("glace", sol_c, 2.6, 2.4)
		"chaine_eclairs":
			EffetsMagie.aura_main(paume_g, "electricite", 1.0)
			var pts: Array[Vector3] = [paume_g.global_position]
			for c in [1, 0, 2]:
				pts.append(_vise(c))
			EffetsMagie.chaine("electricite", pts)
			for c in cibles:
				EffetsMagie.statut_cible(c, "choc", 1.6)
		"tempete_statique":
			EffetsMagie.zone("electricite", sol_c, 2.8, 2.8)
		"trait_ombre":
			EffetsMagie.aura_main(paume_g, "tenebres", 1.0)
			_tirer("tenebres", "trait", _vise(), 0.5)
		"explosion_obscure":
			EffetsMagie.zone("tenebres", sol_c, 2.6, 2.4)
		"soin":
			EffetsMagie.aura_main(paume_g, "soin", 1.0)
			EffetsMagie.zone("soin", Vector3(0, 0, -1.2), 1.6, 2.2)
		"protection":
			EffetsMagie.aura_main(paume_g, "protection", 1.0)
			EffetsMagie.zone("protection", Vector3(0, 0, -0.4), 1.4, 2.2)
		"statuts":
			EffetsMagie.statut_cible(cibles[0], "brulure", 2.8)
			EffetsMagie.statut_cible(cibles[1], "gel", 2.8)
			EffetsMagie.statut_cible(cibles[2], "choc", 2.8)
		"vapeur", "decharge", "decharge_incendiaire", "cristaux_corrompus", "flammes_obscures", "arcs_violets":
			EffetsMagie.reaction(nom, sol_c, 2.0)
		"double_feu", "double_glace", "double_electricite", "double_tenebres":
			var ecole := nom.trim_prefix("double_")
			mains._modele_arme_d.visible = false
			EffetsMagie.double(ecole, true)
			EffetsMagie.aura_main(paume_g, ecole, 1.0)
			EffetsMagie.aura_main(paume_d, ecole, 1.0)
			if ecole == "glace":
				_tirer("glace", "lance", _vise(), 0.6)
		_:
			if nom.begins_with("enchant_"):
				EffetsMagie.enchant_arme(mains._modele_arme_d, nom.trim_prefix("enchant_"), true)

func _pendant(nom: String, t: float) -> void:
	match nom:
		"aura_feu", "aura_glace", "aura_electricite", "aura_tenebres":
			EffetsMagie.aura_main(paume_g, nom.trim_prefix("aura_"), clampf(t / 1.4, 0.05, 1.0))
		"jet_feu", "arc_electrique", "drain_vie", "souffle_givre":
			var ecole: String = {"jet_feu": "feu", "arc_electrique": "electricite", "drain_vie": "tenebres", "souffle_givre": "glace"}[nom]
			EffetsMagie.aura_main(paume_g, ecole, 1.0)
			var actif := t > 0.15 and t < 2.0
			EffetsMagie.jet(ecole, paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, actif)
			if actif and t > 0.6:
				EffetsMagie.statut_cible(cibles[1], {"feu": "brulure", "electricite": "choc", "tenebres": "corruption", "glace": "gel"}[ecole], 0.8)
		"soin":
			pass
		"protection":
			EffetsMagie.jet("protection", paume_g, -joueur.camera.global_basis.z, 1.0, 0.7, t < 2.0)
		"double_feu", "double_electricite", "double_tenebres":
			var ecole := nom.trim_prefix("double_")
			var actif := t > 0.3 and t < 2.1
			EffetsMagie.jet(ecole, paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, actif)
			EffetsMagie.jet(ecole, paume_d, _dir_vers(paume_d, _vise()), 7.0, 1.0, actif)

func _fin(nom: String) -> void:
	for p in [paume_g, paume_d]:
		EffetsMagie.aura_main(p, "feu", 0.0)
		EffetsMagie.jet("feu", p, Vector3.FORWARD, 1.0, 1.0, false)
	if nom.begins_with("enchant_"):
		EffetsMagie.enchant_arme(mains._modele_arme_d, "feu", false)
	if nom.begins_with("double_"):
		EffetsMagie.double(nom.trim_prefix("double_"), false)
		mains._modele_arme_d.visible = true

# ---------------------------------------------------------------- mesure

func _perf() -> void:
	await get_tree().create_timer(1.5).timeout
	var cibles5: Array[Node3D] = cibles.duplicate()
	for i in 2:
		var d := DraugrNordique.creer({})
		add_child(d)
		d.position = Vector3(-3.2 + i * 6.4, 0.0, -5.0)
		cibles5.append(d)
	await get_tree().create_timer(1.0).timeout
	var base := await _mesurer(240, func() -> void: pass)
	EffetsMagie.prechauffer()
	await get_tree().create_timer(0.5).timeout
	EffetsMagie.aura_main(paume_g, "feu", 1.0)
	EffetsMagie.zone("glace", Vector3(0, 0, -6), 2.6, 60.0)
	var statuts := ["brulure", "gel", "choc", "corruption", "brulure"]
	for i in 5:
		EffetsMagie.statut_cible(cibles5[i], statuts[i], 60.0)
	await get_tree().create_timer(0.8).timeout
	var avec := await _mesurer(240, func() -> void:
		EffetsMagie.jet("electricite", paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, true))
	var s := EffetsMagie.stats()
	if _arg("perf") == "pire":
		# pire cas : double incantation de feu (deux jets + deux auras) + explosion incendiaire + 5 statuts
		EffetsMagie.tout_arreter()
		await get_tree().create_timer(1.5).timeout
		for i in 5:
			EffetsMagie.statut_cible(cibles5[i], statuts[i], 60.0)
		EffetsMagie.double("feu", true)
		EffetsMagie.aura_main(paume_g, "feu", 1.0)
		EffetsMagie.aura_main(paume_d, "feu", 1.0)
		EffetsMagie.zone("feu", Vector3(0, 0, -6), 2.6, 60.0)
		for k in 30:
			EffetsMagie.jet("feu", paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, true)
			EffetsMagie.jet("feu", paume_d, _dir_vers(paume_d, _vise()), 7.0, 1.0, true)
			await get_tree().process_frame
		var pire := await _mesurer(240, func() -> void:
			EffetsMagie.jet("feu", paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, true)
			EffetsMagie.jet("feu", paume_d, _dir_vers(paume_d, _vise()), 7.0, 1.0, true))
		var s2 := EffetsMagie.stats()
		print("PERF_PIRE %s %s : double feu (2 jets + 2 auras) + explosion incendiaire + 5 statuts %.2f ms (%d appels) ; %d particules, %d émetteurs, %d lumières" % [
			lieu, vue, pire[0], pire[1], s2.particules, s2.emetteurs, s2.lumieres])
		if dossier != "":
			_capturer("%s_%s_perf_pire" % [lieu, vue])
			await get_tree().create_timer(0.3).timeout
	print("PERF %s %s : sans effet %.2f ms (%d appels de dessin) ; 3 effets (aura feu + arc électrique + nova) + 5 statuts %.2f ms (%d appels) ; %d particules, %d émetteurs, %d lumières, %d éclairs" % [
		lieu, vue, base[0], base[1], avec[0], avec[1], s.particules, s.emetteurs, s.lumieres, s.eclairs])
	if dossier != "":
		_capturer("%s_%s_perf" % [lieu, vue])
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _mesurer(n: int, chaque: Callable) -> Array:
	var t0 := Time.get_ticks_usec()
	var appels := 0
	for k in n:
		chaque.call()
		await get_tree().process_frame
		appels += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return [(Time.get_ticks_usec() - t0) / 1000.0 / n, appels / n]
