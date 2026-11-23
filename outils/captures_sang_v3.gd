extends SceneTree
## Planches, film et banc du SANG V3 (combat/sang_v3) dans scenes/test_combat.tscn (FENÊTRE hors écran, godot_slot.sh) :
##   godot --path . --script res://outils/captures_sang_v3.gd -- --sortie=<dossier> --lieu=interieur|neige [--film|--banc] [--sans-sang-v3]
## Planche (par défaut) : mêmes coups, même caméra, même graine : coup d'épée (en vol, puis 2 s après), arme lancée qui
##   traverse (en vol, 2 s après), mur derrière, sol au pied ; images vue_<n>.png (l'assemblage avant/après se fait à part).
## --film : ~15 s, coups d'épée réels du joueur puis un petit lanceur de test projette des épées sur un bandit et un draugr
##   (ralenti à l'impact), le dernier tue : corps projeté, traînée, flaque (ajouter --write-movie <f.avi> --fixed-fps 30 avant « -- »).
## --banc : 6 ennemis, coups + traversées en continu 12 s puis 4 s de calme : FPS moyens et 1 % bas (lancer avec --disable-vsync).
## --sans-sang-v3 : sang v2 (avant).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")

var s: Node3D
var sortie := ""
var lieu := "neige"
var film := false
var _n := 0
var _cam: Camera3D
var _titre: Label
var _vue := 0

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
	for i in maxi(1, roundi(t * (30.0 if film else 60.0))):
		await process_frame

func _sauver(nom: String) -> void:
	var im := await _image()
	_vue += 1
	im.save_png(sortie.path_join("vue_%d_%s.png" % [_vue, nom]))
	print("VUE ", _vue, " ", nom)

func _ennemi(pos: Vector3, lacet: float, genre := "guerrier") -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "capt_sang_v3_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 5000.0
	d.vie_max = 5000.0
	d.combat.profil.chance_blocage = 0.0
	d.combat.profil.posture_max = 1e6
	d.combat.posture = 1e6
	return d

func _info(d: Node3D, h: float, dir: Vector3, attaque := "legere") -> Dictionary:
	var vers: Vector3 = s.joueur.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	return {"type": "tranchant", "point": d.global_position + Vector3(0, h, 0) + vers * 0.2, "direction": dir.normalized(),
		"normale": vers, "attaque": attaque, "instant": 0.1, "charge": 0.0, "arme": "epee_metal"}

func _boite(p: Vector3, taille: Vector3, m: Material, rot := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = p
	b.rotation.y = rot
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	f.shape = bs
	b.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	s.add_child(b)
	return b

## Décor : un mur et une caisse derrière les cibles, une marche de pierre au sol ; intérieur = plancher, murs, plafond, torche.
func _decor() -> void:
	var roche := Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.5), Vector2(3, 3))
	var bois := Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(2, 2))
	_boite(Vector3(0, 1.5, -4.6), Vector3(7, 3, 0.4), roche)                  # mur derrière les cibles
	_boite(Vector3(1.3, 0.35, -3.7), Vector3(0.7, 0.7, 0.7), bois, 0.3)       # caisse
	_boite(Vector3(-0.6, 0.07, -2.9), Vector3(1.6, 0.14, 0.5), roche)        # marche de pierre (relief)
	if lieu == "interieur":
		_boite(Vector3(0, -0.05, -1), Vector3(12, 0.1, 12), bois)                # plancher (au-dessus de la neige)
		_boite(Vector3(-3.6, 1.5, -1), Vector3(0.4, 3, 10), roche)
		_boite(Vector3(3.6, 1.5, -1), Vector3(0.4, 3, 10), roche)
		_boite(Vector3(0, 3.1, -1), Vector3(8, 0.2, 10), bois)
		s.soleil.visible = false
		s.env.background_color = Color(0.01, 0.01, 0.015)
		s.env.ambient_light_color = Color(0.5, 0.42, 0.36)
		s.env.ambient_light_energy = 0.32
		var t := OmniLight3D.new()
		t.light_color = Color(1.0, 0.66, 0.36)
		t.light_energy = 2.2
		t.omni_range = 7.0
		t.shadow_enabled = true
		s.add_child(t)
		t.position = Vector3(-2.2, 2.2, -1.6)
	else:
		# vraie neige du jeu (palette NEIGE, plus claire que la neige piétinée de la scène) et « sol enneigé » pour le sang
		_boite(Vector3(0, -0.04, -1), Vector3(14, 0.08, 14), Palette.materiau(Palette.tex("neige", Palette.NEIGE, 4, 0.5), Vector2(6, 6)))
		EffetsSol.forcer_neige = true

func _go() -> void:
	seed(4242)
	sortie = _arg("sortie", "user://captures_sang_v3")
	lieu = _arg("lieu", "neige")
	film = _arg("film") != ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
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
	s.mannequin.position = Vector3(-8.0, 0, 6.0)
	s.mur.position = Vector3(-9, 1.3, 8)
	_decor()
	await _attendre(0.5)
	if _arg("banc") != "":
		await _banc()
	elif film:
		await _film()
	else:
		await _planche()
	quit()

func _legende(t: String) -> void:
	_titre.text = t

# ------------------------------------------------------------------ lanceur de test (remplace la télékinésie / ImpactsLances)

## Une épée part de `de` vers le torse de `cible`, la traverse (sang d'entrée et de sortie, sang sur la lame) et reste plantée
## (attachée à l'os du torse, la pointe ressort dans le dos). `tue` : la cible meurt (ragdoll projeté).
func _lancer_epee(de: Vector3, cible: CharacterBody3D, vitesse := 14.0, tue := false, ralenti := false) -> void:
	var e := EpeesLongues.instancier("metal")
	s.add_child(e)
	var prise := EpeesLongues.repere(e, "prise")
	var pointe := EpeesLongues.repere(e, "pointe")
	var axe_l: Vector3 = (pointe.position - (prise.position if prise else Vector3.ZERO)).normalized() if pointe else Vector3.UP
	var but := cible.global_position + Vector3(0, 1.2, 0)
	var dir := (but - de).normalized()
	var base := Basis(Quaternion(axe_l, dir))
	e.global_transform = Transform3D(base, de)
	var t := 0.0
	var dist := de.distance_to(but)
	while t * vitesse < dist - 0.25:
		var dt := 1.0 / (30.0 if film else 60.0)
		t += dt
		e.global_transform = Transform3D(base.rotated(dir, t * 2.0), de + dir * t * vitesse)
		await process_frame
	if ralenti:
		Engine.time_scale = 0.3
	var couleur: Color = cible.combat.profil.couleur_sang
	var entree := but - dir * 0.22
	var sortie_pt := but + dir * 0.22
	Sang.traversee(cible, entree, sortie_pt, dir, 2.6, couleur)
	Plaies.ajouter(cible.modele, entree, -dir, dir, 0.42, couleur, cible.combat.profil.matiere)
	Plaies.ajouter(cible.modele, sortie_pt, dir, dir, 0.45, couleur, cible.combat.profil.matiere)
	# la lame traverse : 2/3 ressortent dans le dos, ensanglantée
	e.global_transform = Transform3D(base, but - dir * 0.35 + dir * 0.55)
	SangLame.ensanglanter(e, 3.0, couleur)
	var sq := cible.modele.find_children("*", "Skeleton3D", true, false)
	if not sq.is_empty():
		var acc := BoneAttachment3D.new()
		acc.bone_name = "spine_03"
		(sq[0] as Skeleton3D).add_child(acc)
		await process_frame
		var xf := e.global_transform
		s.remove_child(e)
		acc.add_child(e)
		e.global_transform = xf
	if tue:
		cible.vie = 1.0
		cible.recevoir_coup(500.0, de, true, {"type": "perforant", "point": but, "direction": dir, "normale": -dir, "attaque": "lourde",
			"instant": 0.1, "charge": 1.0, "arme": "epee_metal"})
	else:
		cible.recevoir_coup(2.0, de, false, {"type": "perforant", "point": entree, "direction": dir, "normale": -dir, "attaque": "lourde",
			"instant": 0.1, "charge": 0.0, "arme": "epee_metal"})
	if ralenti:
		await _attendre(0.6 * 0.3)
		Engine.time_scale = 1.0

# ------------------------------------------------------------------ planche

func _cam_fixe() -> void:
	_cam = Camera3D.new()
	s.add_child(_cam)
	_cam.fov = 58.0
	_cam.global_position = Vector3(2.4, 1.55, 0.2)
	_cam.look_at(Vector3(-0.2, 0.9, -3.0), Vector3.UP)
	_cam.current = true

func _planche() -> void:
	var v3 := "APRÈS : sang v3" if SangV3.actif else "AVANT : sang v2"
	s.placer_joueur(Vector3(0, 0, 0.4), 0.0, -4.0)
	var b := _ennemi(Vector3(-0.4, 0, -2.4), deg_to_rad(10.0), "bandit")
	b.set_physics_process(false)
	await _attendre(1.0)
	_cam_fixe()
	# 1. coup d'épée (de droite à gauche, un peu vers le bas) : en vol puis 2 s après
	b.recevoir_coup(5.0, s.joueur.global_position, false, _info(b, 1.3, Vector3(-1, -0.15, -0.35), "lourde"))
	await _attendre(0.13)
	_legende("%s — coup d'épée (%s)" % [v3, lieu])
	await _sauver("coup_en_vol")
	await _attendre(2.0)
	_legende("%s — coup d'épée, 2 s après" % v3)
	await _sauver("coup_apres")
	# 2. draugr : épée lancée qui le traverse
	b.position = Vector3(-6, 0, 6)
	var d := _ennemi(Vector3(0.6, 0, -2.6), deg_to_rad(-15.0), "guerrier")
	d.set_physics_process(false)
	await _attendre(0.6)
	await _lancer_epee(Vector3(2.0, 1.4, 0.6), d, 14.0)
	await _attendre(0.1)
	_legende("%s — épée lancée qui traverse un draugr" % v3)
	await _sauver("traverse_en_vol")
	await _attendre(2.2)
	_legende("%s — traversée, 2 s après" % v3)
	await _sauver("traverse_apres")
	# 3. bandit : épée lancée, plaie de sortie vers le mur, gros plan sur le mur
	d.position = Vector3(6, 0, 6)
	b.position = Vector3(-0.3, 0, -3.3)
	b.rotation.y = deg_to_rad(-20.0)
	await _attendre(0.5)
	await _lancer_epee(Vector3(1.8, 1.3, 0.8), b, 14.0)
	await _attendre(2.0)
	_cam.global_position = Vector3(1.0, 1.4, -2.2)
	_cam.look_at(Vector3(-0.6, 0.9, -4.4), Vector3.UP)
	_legende("%s — mur et caisse derrière le bandit" % v3)
	await _sauver("mur")
	# 4. sol : le bandit meurt (flaque, traînée) ; vue plongeante 6 s après
	b.vie = 1.0
	b.recevoir_coup(900.0, s.joueur.global_position, true, _info(b, 1.2, Vector3(-0.4, 0, -1), "lourde"))
	await _attendre(6.0)
	_cam.global_position = Vector3(1.4, 2.4, -0.8)
	_cam.look_at(Vector3(-0.5, 0.0, -3.4), Vector3.UP)
	_legende("%s — sol : gouttes, flaque, traînée (6 s)" % v3)
	await _sauver("sol")
	_cam.current = false
	s.joueur.camera.current = true
	await _attendre(0.3)
	_legende("%s — vue de jeu" % v3)
	await _sauver("vue_jeu")
	print("TRACES ", Sang.nombre_traces(s), " | cout CPU sang ", Sang.cout_us / 1000.0, " ms")

# ------------------------------------------------------------------ film (~15 s)

func _film() -> void:
	var v3 := "sang v3" if SangV3.actif else "AVANT (sang v2)"
	s.placer_joueur(Vector3(0, 0, 0.6), 0.0, -6.0)
	var b := _ennemi(Vector3(-0.2, 0, -1.0), deg_to_rad(0.0), "bandit")
	var d := _ennemi(Vector3(1.1, 0, -2.8), deg_to_rad(-20.0), "guerrier")
	for e in [b, d]:
		e.set_physics_process(false)
	await _attendre(0.8)
	var j: CharacterBody3D = s.joueur
	var mains = j.mains
	_legende(v3 + " — coups d'épée")
	for k in 5:
		if k == 3:
			mains.entrees.appuyer()
			await _attendre(0.9)
			mains.entrees.relacher()
			await _attendre(0.9)
		else:
			mains.attaquer(false)
			await _attendre(0.65)
	# recul : on regarde les cibles d'un peu plus loin, le lanceur de test projette des épées
	for f in 20:
		j.global_position = j.global_position.lerp(Vector3(1.4, 0, 1.6), 0.12)
		var vers: Vector3 = Vector3(0.3, 0, -2.2) - j.global_position
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-vers.x, -vers.z), 0.2)
		await process_frame
	_legende(v3 + " — épée lancée (télékinésie, lanceur de test) : draugr, ralenti")
	await _lancer_epee(j.global_position + Vector3(0.3, 1.5, 0), d, 13.0, false, true)
	await _attendre(1.6)
	_legende(v3 + " — épée lancée : bandit, sortie dans le dos")
	b.position = Vector3(-0.5, 0, -2.9)
	await _attendre(0.2)
	await _lancer_epee(j.global_position + Vector3(0.3, 1.5, 0), b, 13.0, false, true)
	await _attendre(1.6)
	_legende(v3 + " — dernière épée : il est projeté")
	await _lancer_epee(j.global_position + Vector3(0.3, 1.5, 0), b, 15.0, true, true)
	await _attendre(3.0)
	_legende(v3 + " — le mur, la caisse, le sol")
	for f in 60:
		var vers: Vector3 = Vector3(-0.4, 0.3, -4.2) - j.global_position
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-vers.x, -vers.z), 0.08)
		await process_frame
	await _attendre(1.5)

# ------------------------------------------------------------------ banc FPS

func _banc() -> void:
	s.placer_joueur(Vector3(0, 0, 1.2), 0.0, -8.0)
	var es := []
	for k in 6:
		var e := _ennemi(Vector3(-2.0 + k * 0.8, 0, -2.2 - (k % 2) * 0.6), 0.0, "bandit" if k % 2 else "guerrier")
		e.set_physics_process(false)
		es.append(e)
	await _attendre(2.0)
	var calme_avant := await _mesure(3.0, [], false)
	var combat := await _mesure(12.0, es, true)
	var calme := await _mesure(4.0, [], false)
	print("BANC %s %s : calme avant %.1f FPS | combat %.1f FPS (1%% bas %.1f) | calme après %.1f FPS | traces %d | cout CPU sang %.1f ms" % [
		"v3" if SangV3.actif else "v2", lieu, calme_avant["fps"], combat["fps"], combat["bas"], calme["fps"], Sang.nombre_traces(s), Sang.cout_us / 1000.0])

func _mesure(duree: float, es: Array, frapper: bool) -> Dictionary:
	var temps := PackedFloat32Array()
	var t := 0.0
	var prochain := 0.0
	var k := 0
	var dernier := Time.get_ticks_usec()
	while t < duree:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - dernier) / 1e6
		dernier = now
		temps.append(dt)
		t += dt
		if frapper and t >= prochain:
			prochain = t + 0.18
			var e: CharacterBody3D = es[k % es.size()]
			k += 1
			if k % 5 == 0:
				var p := e.global_position + Vector3(0, 1.2, 0)
				var dir := Vector3(randf_range(-0.4, 0.4), -0.05, -1).normalized()
				Sang.traversee(e, p - dir * 0.2, p + dir * 0.2, dir, 2.6, e.combat.profil.couleur_sang)
			else:
				e.recevoir_coup(3.0, s.joueur.global_position, false, _info(e, 1.25, Vector3(randf_range(-1, 1), -0.2, -0.4), "lourde" if k % 3 == 0 else "legere"))
	var tri := temps.duplicate()
	tri.sort()
	var somme := 0.0
	for x in temps:
		somme += x
	var n_bas := maxi(1, int(tri.size() * 0.01))
	var bas := 0.0
	for i in n_bas:
		bas += tri[tri.size() - 1 - i]
	return {"fps": temps.size() / maxf(somme, 0.001), "bas": n_bas / maxf(bas, 0.0001)}
