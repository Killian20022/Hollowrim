extends Node3D
## Scène de test des dégâts (branche combat/degats_gore) : mannequin, draugr guerrier, squelette et bandit sur quatre sols (pierre,
## neige, bois, pierre) devant un mur, joueur factice, post-traitement ps1 du jeu, débogage (dégâts flottants, posture, réaction,
## finisher disponible). Un PILOTE automatique frappe chaque cible (sans le joueur réel ni mains.gd) : coups légers / lourds,
## tête / jambes, appels SANS info (compatibilité), posture brisée, finisher (décapitation), mort et flaques.
##   godot --path . scenes/test_degats.tscn -- --nouvelle [--nuit] [--vue=obs|fps] [--captures=<dossier>] [--perf] [--gore=0|1|2] [--fin=s]
##   --test : aucun pilote (outils/test_degats.gd s'en sert comme décor).

const DRAUGR := preload("res://scripts/draugr.gd")
const JOUEUR := preload("res://scripts/combat/joueur_test.gd")
const POST := preload("res://shaders/ps1_post.gdshader")

class HudTest extends Control:
	func avis(_t: String) -> void:
		pass

var post: ShaderMaterial
var joueur: CharacterBody3D
var hud: Control
var obs: Camera3D
var cibles: Array = []
var nuit := false
var vue := "obs"
var dossier_captures := ""
var _n_capture := 0
var _sens := 1.0
var _journal: Array[String] = []
var torche: OmniLight3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _ready() -> void:
	CombatEnnemi.debug = _arg("debug", "1") != "0"
	nuit = _arg("nuit") != ""
	vue = _arg("vue", "obs")
	dossier_captures = _arg("captures")
	if _arg("gore") != "":
		Sang.niveau_force = int(_arg("gore"))
	RetourImpact.sol_force = ""
	_decor()
	_interface()
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	joueur.name = "JoueurTest"
	add_child(joueur)
	joueur.global_position = Vector3(0, 0, 3.0)
	hud = HudTest.new()
	add_child(hud)
	obs = Camera3D.new()
	obs.fov = 62.0
	add_child(obs)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.62, 0.3)
	torche.omni_range = 9.0
	torche.light_energy = 2.2 if nuit else 0.0
	torche.visible = nuit
	joueur.add_child(torche)
	torche.position = Vector3(-0.35, 1.45, -0.3)
	if _arg("perf") != "":
		_perf.call_deferred()
		return
	_cibles()
	(obs if vue == "obs" else joueur.camera).current = true
	if _arg("test") == "":
		_pilote.call_deferred()

# ------------------------------------------------------------------ décor

func _decor() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1) if nuit else Color(0.42, 0.48, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.16, 0.24) if nuit else Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 0.35 if nuit else 0.7
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.03 if nuit else 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation = Vector3(deg_to_rad(-48), deg_to_rad(35), 0)
	soleil.light_color = Color(0.4, 0.45, 0.65) if nuit else Color(1.0, 0.93, 0.82)
	soleil.light_energy = 0.12 if nuit else 1.1
	soleil.shadow_enabled = true
	add_child(soleil)
	var pierre := Palette.tex("sol_pierre_test", ["#2c2a2a", "#3c3836", "#4e4844", "#625a54"], 4, 0.5)
	var neige := Palette.tex("sol_neige_test", Palette.NEIGE, 4, 0.3)
	var bois := Palette.tex("sol_bois_test", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.6)
	var sols := [pierre, neige, bois, pierre]
	for k in 4:
		_bloc(Vector3(4.0, 0.2, 9.0), Vector3(-6.0 + k * 4.0, -0.1, 0.5), sols[k], Vector2(4, 9))
	_bloc(Vector3(16.0, 3.2, 0.4), Vector3(0, 1.6, -2.6), pierre, Vector2(16, 3))

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

# ------------------------------------------------------------------ cibles

func creer_draugr(type: String, pos: Vector3, options := {}) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = type
	d.joueur = joueur
	d.hud = hud
	d.ident = "%s_test_%d" % [type, get_child_count()]
	for cle in options:
		d.set(cle, options[cle])
	d.position = pos
	d.rotation.y = 0.0   # regarde +Z (le joueur)
	add_child(d)
	return d

func _cibles() -> void:
	var m := Mannequin.new()
	m.joueur = joueur
	add_child(m)
	m.position = Vector3(-6, 0, 0)
	cibles.append(m)
	cibles.append(creer_draugr("guerrier", Vector3(-2, 0.05, 0), {"ident": "guerrier"}))
	cibles.append(creer_draugr("squelette", Vector3(2, 0.05, 0), {"ident": "squelette"}))
	cibles.append(creer_draugr("sbire", Vector3(6, 0.05, 0), {"ident": "sbire"}))
	for c in cibles:
		c.name = String(c.get("ident")) if c.get("ident") else "mannequin"
	cibles[0].name = "mannequin"
	for c in cibles:
		if c is CharacterBody3D:
			c.set_physics_process(false)

# ------------------------------------------------------------------ pilote

func _attendre(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _viser(c: Node3D, distance := 1.7) -> void:
	var pos := c.global_position + Vector3(0, 0, distance)
	pos.y = 0.0
	joueur.global_position = pos
	joueur.rotation.y = 0.0   # la caméra regarde -Z
	joueur.tete.rotation.x = -0.05
	_placer_obs(c)

func _placer_obs(c: Node3D) -> void:
	var cible := c.global_position + Vector3(0, 1.0, 0)
	obs.global_position = cible + Vector3(2.4, 0.75, 2.6)
	obs.look_at(cible, Vector3.UP)

## Un coup d'épée simulé : info complète (comme l'épée FPS) ou vide (comme mains.gd aujourd'hui).
func frapper(c: Node, attaque := "legere", zone := "", avec_info := true) -> String:
	var lourd := attaque != "legere"
	var base := 34.0 if lourd else 14.0
	var o := joueur.global_position
	var vers := (c as Node3D).global_position - o
	vers.y = 0.0
	vers = vers.normalized()
	var cote := vers.cross(Vector3.UP)
	_sens = -_sens
	var info := {}
	if avec_info:
		var h := 1.15
		if zone == "tete":
			h = 1.6
		elif zone == "jambes":
			h = 0.55
		info = {"type": "tranchant", "attaque": attaque, "arme": "epee", "stagger": CalculDegats.STAGGER[attaque],
			"direction": (cote * _sens * 0.85 + vers * 0.35 + Vector3.DOWN * 0.2).normalized(),
			"point": (c as Node3D).global_position + Vector3(0, h, 0) - vers * 0.22, "normale": -vers}
		if zone != "":
			info["zone"] = zone
	var r: String = c.recevoir_coup(base, o, lourd, info)
	var cr: Variant = c.get("combat")
	var reac := ""
	if cr is CombatEnnemi:
		reac = (cr as CombatEnnemi).derniere_reaction
	_journal.append("%s %s %s -> %s (%s)" % [c.name, attaque, zone, r, reac])
	print("COUP ", _journal[-1])
	joueur.secousse = maxf(joueur.secousse, 0.25 if not lourd else 0.5)
	return r

func capturer(nom: String) -> void:
	if dossier_captures == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var chemin := ProjectSettings.globalize_path(dossier_captures).path_join("%02d_%s%s.png" % [_n_capture, nom, "_nuit" if nuit else ""])
	_n_capture += 1
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	img.save_png(chemin)
	print("CAPTURE ", chemin)

func _activer(c: Node) -> void:
	for x in cibles:
		if is_instance_valid(x) and x is CharacterBody3D and x.vivant():
			x.set_physics_process(x == c)

func _pilote() -> void:
	await _attendre(1.5)
	var seul := _arg("seul")   # --seul=guerrier : une seule cible (vidéo courte)
	if seul == "" or seul == "mannequin":
		await _pilote_mannequin()
	for i in range(1, cibles.size()):
		if seul == "" or seul == String(cibles[i].name):
			await _pilote_draugr(i)
	print("TRACES ", Sang.nombre_traces(self))
	var fin := float(_arg("fin", "0"))
	if fin > 0.0 or dossier_captures != "" or seul != "":
		await _attendre(maxf(fin, 0.5))
		get_tree().quit(0)

func _pilote_mannequin() -> void:
	# --- mannequin : coups sans info (compatibilité mains.gd), puis avec info, posture brisée, finisher
	var m: Node3D = cibles[0]
	_viser(m)
	await _attendre(0.6)
	for k in 2:
		frapper(m, "legere", "", false)
		await _attendre(0.5)
	frapper(m, "lourde", "torse")
	await _attendre(0.08)
	await capturer("mannequin_impact_lourd")
	await _attendre(0.6)
	var n := 0
	while m.finisher_possible(joueur) == "" and n < 12:
		frapper(m, "legere" if n % 2 == 0 else "lourde", "torse")
		n += 1
		await _attendre(0.45)
	await capturer("mannequin_posture_brisee")
	frapper(m, "lourde", "tete")
	await _attendre(0.25)
	await capturer("mannequin_finisher")
	await _attendre(1.0)

## Draugr : séquence légère/légère/lourde jusqu'au finisher ou à la mort (le dernier meurt sans finisher : mort standard).
func _pilote_draugr(i: int) -> void:
	if true:
		var c: CharacterBody3D = cibles[i]
		_activer(c)
		_viser(c)
		await _attendre(0.8)
		var coups := 0
		var finisher_fait := false
		while c.vivant() and coups < 30:
			var cat: String = c.finisher_possible(joueur)
			if cat != "" and (i != cibles.size() - 1 or _arg("seul") != ""):
				# caméra rapprochée sur la tête pour la décapitation
				var tete := c.global_position + Vector3(0, 1.45, 0)
				obs.global_position = tete + Vector3(1.5, 0.15, 1.3)
				obs.look_at(tete + Vector3(0, -0.2, 0), Vector3.UP)
				var r := frapper(c, "lourde", "torse")
				finisher_fait = r == "tue"
				var rb: Variant = c.modele.get_meta("tete_coupee", null)
				print("DECAPITE ", c.name, " ", c.modele.has_meta("decapite"), " tete=", rb != null)
				await _attendre(0.05)
				await capturer("%s_finisher_%s_a" % [c.name, cat])
				await _attendre(0.45)
				await capturer("%s_finisher_%s_b" % [c.name, cat])
				await _attendre(1.2)
				await capturer("%s_finisher_%s_c" % [c.name, cat])
				if rb is Node3D and is_instance_valid(rb):
					await _attendre(1.0)
					var pt: Vector3 = (rb as Node3D).global_position
					obs.global_position = pt + Vector3(0.9, 0.7, 0.9)
					obs.look_at(pt, Vector3.UP)
					await _attendre(0.1)
					await capturer("%s_tete_au_sol" % c.name)
					print("TETE ", c.name, " a ", pt.distance_to(c.global_position), " m du corps")
				break
			var motif := ["legere", "legere", "lourde"][coups % 3] as String
			var zone := ["torse", "bras", "jambes", "torse", "tete"][coups % 5] as String
			if _arg("seul") != "":
				zone = ["torse", "bras", "torse", "tete"][coups % 4] as String   # vidéo : pas de chute, la posture casse -> décapitation
			frapper(c, motif, zone, coups % 4 != 3)
			if coups < 3:
				await _attendre(0.18)
				await capturer("%s_impact_%s_%d" % [c.name, motif, coups])
			if coups == 2 and c.vivant():
				# plaies sur le corps vivant : gros plan sur le buste
				await _attendre(0.5)
				var b := c.global_position + Vector3(0, 1.15, 0)
				obs.global_position = b + Vector3(0.45, 0.25, 1.15)
				obs.look_at(b, Vector3.UP)
				await _attendre(0.05)
				await capturer("%s_plaies_vivant" % c.name)
				_placer_obs(c)
			coups += 1
			await _attendre(0.7 if motif == "legere" else 0.95)
		# plaies et flaques
		await _attendre(2.5)
		var bassin: Node3D = c.combat._accroche("pelvis")
		var pc: Vector3 = bassin.global_position if bassin else c.global_position
		obs.global_position = pc + Vector3(1.1, 1.5, 1.2)
		obs.look_at(pc, Vector3.UP)
		await _attendre(0.2)
		await capturer("%s_flaque_plaies" % c.name)
		_placer_obs(c)
		print("FIN CIBLE ", c.name, " finisher=", finisher_fait, " vivant=", c.vivant())

# ------------------------------------------------------------------ perf : 5 draugrs saignants au pire cas

func _perf() -> void:
	joueur.global_position = Vector3(0, 0, 2.0)
	joueur.camera.current = true
	joueur.tete.rotation.x = -0.25
	var ds: Array = []
	for k in 5:
		var a := -0.9 + k * 0.45
		var p := Vector3(sin(a) * 2.2, 0.05, 2.0 - cos(a) * 2.2)
		var d := creer_draugr("guerrier" if k % 2 == 0 else "sbire", p)
		d.rotation.y = atan2(-sin(a), cos(a))
		ds.append(d)
	await _attendre(2.0)
	if _arg("chaud") != "":
		# préchauffe : un 6e draugr achevé hors mesure (shaders des effets compilés, ragdoll et décapitation déjà vus)
		var x := creer_draugr("guerrier", Vector3(0, 0.05, -1.5))
		await _attendre(0.5)
		x.combat.briser_posture()
		x.subir_finisher("etourdi", {"origine": joueur.global_position})
		await _attendre(2.0)
	var base := await _mesurer(2.0)
	# coups lourds sur tous (sang, plaies), puis finishers simultanés (5 décapitations, 5 jets)
	for d in ds:
		frapper(d, "lourde", "torse")
	await _attendre(0.3)
	for d in ds:
		frapper(d, "legere", "bras")
	for d in ds:
		d.combat.briser_posture()
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		for d in ds:
			d.subir_finisher("etourdi", {"origine": joueur.global_position}))
	var t0 := Time.get_ticks_usec()
	var g: Dictionary = await _mesurer(4.0)
	print("PERF base moy %.2f ms max %.2f ms | gore moy %.2f ms max %.2f ms | traces %d" % [base["moy"], base["max"], g["moy"], g["max"], Sang.nombre_traces(self)])
	get_tree().quit(0)

func _mesurer(duree: float) -> Dictionary:
	var t := 0.0
	var n := 0
	var somme := 0.0
	var pire := 0.0
	var avant := Time.get_ticks_usec()
	while t < duree:
		await get_tree().process_frame
		var maint := Time.get_ticks_usec()
		var ms := (maint - avant) / 1000.0
		avant = maint
		t += ms / 1000.0
		if n > 0:
			somme += ms
			pire = maxf(pire, ms)
		n += 1
	return {"moy": somme / maxf(n - 1, 1), "max": pire}
