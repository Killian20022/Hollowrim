extends Node3D
## Galerie des visuels de la magie (scenes/galerie_magie.tscn) : joue chaque effet de EffetsMagie l'un après l'autre,
## en vue FPS avec la VRAIE main gauche du héros (bras_fps, mains.gd du joueur réel ; la torche est rangée et la main
## gauche est posée paume en avant par CE script, sans toucher à mains.gd) ou en vue de côté, dans une crypte de nuit
## ou dehors de jour. Cibles : draugrs (DraugrNordique.creer, figés).
##   godot --path . res://scenes/galerie_magie.tscn -- [--lieu=crypte|dehors] [--vue=fps|cote] [--plans=a,b,...]
##       [--captures=<dossier>]   une image PNG au milieu de chaque plan (<lieu>_<vue>_<plan>.png), puis quitte
##       [--perf]                 mesure : temps d'image sans effet, puis avec 3 effets simultanés + 5 cibles avec statut
##       [--perf=jet]             mesure : un seul jet tenu (3 mesures de 240 images) ; --ecole=electricite|… (feu par défaut)
##       [--boucle]               rejoue la suite sans fin (démonstration)
##       [--instants=a,b,...]     plusieurs captures par plan, aux instants donnés (s)
##       [--cible=<m>]            cibles à cette distance de l'œil (6 m par défaut ; ex. 3 ou 8 pour le jet de flammes)
##       (plan souffle_givre_sol : souffle de givre vers le sol, à mi-chemin de la cible du milieu)
##       [--tourne=<°/s>]         jets canalisés : la vue pivote (lacet) à partir de 0,8 s et le jet suit la caméra
##                                (inertie du jet quand on tourne)
##   Vidéo Movie Maker : --write-movie <fichier.avi> --fixed-fps 30 -- --lieu=crypte (quitte à la fin de la suite).

const JOUEUR := preload("res://scripts/joueur.gd")
const POST := preload("res://shaders/ps1_post.gdshader")

## Plans : [nom, durée (s), instant de la capture (s)].
const PLANS := [
	["vide", 1.0, 0.8],   # sans effet : référence du monde (rétro et couche fine doivent donner le même décor)
	["aura_feu", 2.2, 1.6], ["jet_feu", 2.4, 1.2], ["jet_feu_loin", 3.0, 1.5], ["boule_feu", 2.4, 0.16], ["explosion_feu", 2.0, 0.42], ["zone_feu", 2.6, 0.5],
	["aura_glace", 2.0, 1.4], ["eclat_glace", 2.2, 0.12], ["eclat_glace_sol", 2.0, 0.5], ["lance_givre", 2.4, 0.1], ["souffle_givre", 2.4, 1.2], ["souffle_givre_loin", 3.0, 1.5], ["souffle_givre_sol", 2.6, 1.4], ["nova_gelee", 2.8, 0.7],
	["aura_electricite", 2.0, 1.4], ["arc_electrique", 2.4, 1.0], ["chaine_eclairs", 1.8, 0.15], ["impact_electricite", 1.4, 0.1], ["tempete_statique", 3.0, 1.2],
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
	if _arg("detail-sorts") == "":
		CoucheMagie.niveau_force = CoucheMagie.ELEVE   # la galerie montre la couche fine (sauf --detail-sorts=retro|moyen)
	GestionMagie.masquer_particules = _arg("sans-particules") != ""
	GestionMagie.sans_procedural = _arg("sans-procedural") != ""
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
		var dc := float(_arg("cible", "6"))
		d.position = Vector3((-1.6 + i * 1.6) * clampf(dc / 6.0, 0.5, 1.0), 0.0, -dc - absf(i - 1) * 0.6)
		d.add_to_group("cibles_magie")   # sans collision : les jets les trouvent par ce groupe
		cibles.append(d)
	_interface()
	GestionMagie.obtenir()   # comme en jeu (préchauffe au chargement) : la couche fine règle la fenêtre dès le début
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
	rect.visible = _arg("sans-post") == ""   # mise au point : comparer le décor sans le post-traitement
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
	# souris libre : la fenêtre (hors écran) ne capture pas le curseur de l'utilisateur et la vue ne bouge pas
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	if dossier != "" and _arg("instants") != "":
		# --instants=0.5,1.2 : plusieurs captures par plan (<lieu>_<vue>_<plan>_<instant>.png)
		var suffixe := "_tourne" if _arg("tourne") != "" else ""
		for x in _arg("instants").split(","):
			if _t >= float(x) and _t - dt < float(x):
				_capturer("%s_%s_%s%s_%s" % [lieu, vue, p[0], suffixe, x])
	elif dossier != "" and not _capture_faite and _t >= float(p[2]):
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
	var cm: CoucheMagie = GestionMagie.instance.couche if GestionMagie.instance != null else null
	print("CAPTURE ", nom, " ", img.get_size(), " ", EffetsMagie.stats(), (" couche k=%d m=%d actif=%s prof=%s copies=%d fenetre=%s" % [cm.k, cm.m, cm.actif, cm.profondeur.taille, cm.profondeur.copies, get_window().size]) if cm != null and cm.profondeur != null else "")

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
		"eclat_glace_sol":
			# éclats qui frappent le sol devant les cibles : impact de givre sur une surface (hors corps)
			EffetsMagie.aura_main(paume_g, "glace", 1.0)
			for k in 3:
				_tirer("glace", "eclat", Vector3(-1.0 + k * 1.0, 0.02, -3.6 - 0.4 * k), 0.3 + k * 0.05)
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
		"impact_electricite":
			# impact sur une surface (sol devant les cibles, puis mur) : éclatement de la décharge
			EffetsMagie.impact("electricite", Vector3(0.4, 0.0, -4.2), Vector3.UP, 1.0)
			get_tree().create_timer(0.5).timeout.connect(func() -> void: EffetsMagie.impact("electricite", Vector3(-1.2, 0.0, -3.4), Vector3.UP, 1.6))
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
			EffetsMagie.jet(ecole, paume_g, _dir_jet(paume_g, t), _portee(), 1.0, actif)
			if actif and t > 0.6:
				EffetsMagie.statut_cible(cibles[1], {"feu": "brulure", "electricite": "choc", "tenebres": "corruption", "glace": "gel"}[ecole], 0.8)
		"jet_feu_loin", "souffle_givre_loin":
			# jet dans le vide, au-dessus des cibles, vers le mur du fond : portée entière de la vague (feu) / du souffle (glace)
			var ec_loin := "glace" if nom == "souffle_givre_loin" else "feu"
			EffetsMagie.aura_main(paume_g, ec_loin, 1.0)
			var loin := Vector3(1.4, 3.1, -12.2) if lieu == "crypte" else Vector3(1.4, 3.1, -14.0)
			EffetsMagie.jet(ec_loin, paume_g, _dir_vers(paume_g, loin) if _arg("tourne") == "" else _dir_jet(paume_g, t), 9.0, 0.9, t > 0.15 and t < 2.6)
		"souffle_givre_sol":
			# souffle de givre dirigé vers le SOL, devant la cible du milieu : la brume doit s'écraser et ramper au sol
			EffetsMagie.aura_main(paume_g, "glace", 1.0)
			var sol := cibles[1].global_position * Vector3(1.0, 0.0, 0.55) + Vector3(0.0, cibles[1].global_position.y + 0.02, 0.0)
			EffetsMagie.jet("glace", paume_g, _dir_vers(paume_g, sol), _portee(), 1.0, t > 0.15 and t < 2.2)
		"soin":
			pass
		"protection":
			EffetsMagie.jet("protection", paume_g, -joueur.camera.global_basis.z, 1.0, 0.7, t < 2.0)
		"double_feu", "double_electricite", "double_tenebres":
			var ecole := nom.trim_prefix("double_")
			var actif := t > 0.3 and t < 2.1
			EffetsMagie.jet(ecole, paume_g, _dir_jet(paume_g, t), _portee(), 1.0, actif)
			EffetsMagie.jet(ecole, paume_d, _dir_jet(paume_d, t), _portee(), 1.0, actif)

## Portée des jets canalisés de la galerie : 7 m, ou un peu au-delà des cibles éloignées (--cible=8 : 9 m, comme le sort).
func _portee() -> float:
	return maxf(7.0, float(_arg("cible", "6")) + 1.0)

## Direction d'un jet : vers la cible du milieu ; avec --tourne, la vue pivote à partir de 0,8 s et le jet suit la caméra.
func _dir_jet(o: Node3D, t: float) -> Vector3:
	var v := float(_arg("tourne", "0"))
	if v == 0.0 or t < 0.8:
		return _dir_vers(o, _vise())
	if t < 2.0 and o == paume_g:   # une seule rotation par image, même en double incantation
		joueur.rotate_y(deg_to_rad(v) * get_process_delta_time())
	var cible: Vector3 = joueur.camera.global_position - joueur.camera.global_basis.z * 6.0
	return _dir_vers(o, cible)

func _fin(nom: String) -> void:
	for p in [paume_g, paume_d]:
		EffetsMagie.aura_main(p, "feu", 0.0)
		EffetsMagie.jet("feu", p, Vector3.FORWARD, 1.0, 1.0, false)
	if nom.begins_with("enchant_"):
		EffetsMagie.enchant_arme(mains._modele_arme_d, "feu", false)
	if nom.begins_with("double_"):
		EffetsMagie.double(nom.trim_prefix("double_"), false)
		mains._modele_arme_d.visible = true
	if _arg("tourne") != "":
		joueur.rotation.y = 0.0

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
	if _arg("perf") == "jet":
		# --perf=jet [--ecole=glace] : coût d'UN jet tenu (aura + jet sur la cible du milieu), rien d'autre ; 3 mesures
		var ec_p := _arg("ecole", "feu")
		await get_tree().create_timer(0.5).timeout
		EffetsMagie.aura_main(paume_g, ec_p, 1.0)
		for k in 30:
			EffetsMagie.jet(ec_p, paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, true)
			await get_tree().process_frame
		for r in 3:
			var mj := await _mesurer(240, func() -> void:
				EffetsMagie.jet(ec_p, paume_g, _dir_vers(paume_g, _vise()), 7.0, 1.0, true))
			var sj := EffetsMagie.stats()
			print("PERF_JET %s %s %s : sans effet %.2f ms (GPU %.2f ms) ; jet %.2f ms (%d appels ; GPU %.2f ms) ; %d particules, %d émetteurs" % [
				ec_p, lieu, vue, base[0], base[2], mj[0], mj[1], mj[2], sj.particules, sj.emetteurs])
		get_tree().quit()
		return
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
		print("PERF_PIRE %s %s : double feu (2 jets + 2 auras) + explosion incendiaire + 5 statuts %.2f ms (%d appels ; GPU %.2f ms) ; %d particules, %d émetteurs, %d lumières" % [
			lieu, vue, pire[0], pire[1], pire[2], s2.particules, s2.emetteurs, s2.lumieres])
		if dossier != "":
			_capturer("%s_%s_perf_pire" % [lieu, vue])
			await get_tree().create_timer(0.3).timeout
	print("PERF %s %s : sans effet %.2f ms (%d appels de dessin ; GPU %.2f ms) ; 3 effets (aura feu + arc électrique + nova) + 5 statuts %.2f ms (%d appels ; GPU %.2f ms) ; %d particules, %d émetteurs, %d lumières, %d éclairs" % [
		lieu, vue, base[0], base[1], base[2], avec[0], avec[1], avec[2], s.particules, s.emetteurs, s.lumieres, s.eclairs])
	if dossier != "":
		_capturer("%s_%s_perf" % [lieu, vue])
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _mesurer(n: int, chaque: Callable) -> Array:
	# temps GPU mesuré par le moteur (fenêtre + couche fine de la magie) : moins sensible que le temps d'image aux
	# autres programmes qui chargent la machine
	var vps: Array[RID] = [get_viewport().get_viewport_rid()]
	var cm: CoucheMagie = GestionMagie.instance.couche if GestionMagie.instance != null else null
	if cm != null and cm.vp != null:
		vps.append(cm.vp.get_viewport_rid())
	for v in vps:
		RenderingServer.viewport_set_measure_render_time(v, true)
	var t0 := Time.get_ticks_usec()
	var appels := 0
	var gpu := 0.0
	var gpu_couche := 0.0
	for k in n:
		chaque.call()
		await get_tree().process_frame
		appels += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vps[0])
		if vps.size() > 1:
			gpu_couche += RenderingServer.viewport_get_measured_render_time_gpu(vps[1])
	print("  GPU fenêtre %.2f ms + couche fine %.2f ms = %.2f ms" % [gpu / n, gpu_couche / n, (gpu + gpu_couche) / n])
	return [(Time.get_ticks_usec() - t0) / 1000.0 / n, appels / n, (gpu + gpu_couche) / n]
