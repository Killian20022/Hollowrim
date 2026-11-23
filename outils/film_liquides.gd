extends SceneTree
## Film, planche et banc des LIQUIDES RÉALISTES (monde/liquides, docs/LIQUIDES.md) dans scenes/test_combat.tscn (FENÊTRE hors écran) :
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_liquides.gd -- --nouvelle --sortie=<dossier> [--planche] [--banc] [--sans-liquides]
## Film (~21 s, images f_00000.png…) : 1. un tonneau de bière casse sur une étagère : la bière jaillit, s'étale sur la planche,
##   s'égoutte au bord et fait une flaque au sol ; 2. une jarre de vin casse au sol ; 3. coup d'épée sur un bandit devant un mur de
##   pierre : le sang gicle sur le mur et coule, gouttes et flaque au sol ; 4. dehors : sang sur la neige.
## --planche : mêmes scènes, une image par moment-clé (pl_<n>_<nom>.png) ; avec --sans-liquides : AVANT.
## --banc : 5 tonneaux cassés d'un coup (FPS moyens et 1 % bas pendant 8 s, puis 3 s de calme).
## Lumière de tournage (film / planche seulement) : une lampe douce près de la caméra.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")

var s: Node3D
var sortie := ""
var planche := false
var n := 0
var _cam: Camera3D
var _titre: Label
var _vue := 0
var _lampe: OmniLight3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if sortie != "" and not planche:
		root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _filmer(t: float) -> void:
	for i in maxi(1, roundi(t * 30.0)):
		await _image()

func _cliche(nom: String) -> void:
	if not planche:
		return
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_vue += 1
	root.get_texture().get_image().save_png("%s/pl_%d_%s.png" % [sortie, _vue, nom])
	print("VUE ", _vue, " ", nom)

func _legende(t: String) -> void:
	_titre.text = ("AVANT (sans liquides) — " if not Liquides.actif else "") + t

func _boite(p: Vector3, taille: Vector3, m: Material, surface := "", rot := 0.0) -> StaticBody3D:
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
	if surface != "":
		b.set_meta("surface_liquide", surface)
	s.add_child(b)
	return b

func _ennemi(pos: Vector3, lacet: float) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire"
	d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "film_liquides_%d" % randi()
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 5000.0
	d.vie_max = 5000.0
	d.combat.profil.chance_blocage = 0.0
	d.combat.profil.posture_max = 1e6
	d.combat.posture = 1e6
	return d

func _info(d: Node3D, h: float, dir: Vector3, attaque := "lourde") -> Dictionary:
	var vers: Vector3 = _cam.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	return {"type": "tranchant", "point": d.global_position + Vector3(0, h, 0) + vers * 0.2, "direction": dir.normalized(),
		"normale": vers, "attaque": attaque, "instant": 0.1, "charge": 0.0, "arme": "epee_metal"}

## Meuble vivant (tonneau, jarre) posé là, contenu choisi (l'identifiant décide du contenu, comme en jeu : on en cherche un qui donne `voulu`).
func _meuble(genre: String, xf: Transform3D, voulu: String) -> ObjetVivant:
	var mo := ObjetsVivants.morceaux_q(genre, func(_m: String) -> Material: return null)
	var res := ObjetsVivants.peupler(s, [ObjetsVivants.spec_meuble(genre, xf, mo, 60.0, true)], "film_liq_%s" % genre)
	if res.is_empty():
		push_error("meuble %s introuvable" % genre)
		return null
	var o: ObjetVivant = res[0]
	for k in 400:
		var id := "film_liq:%s:%d" % [genre, k]
		var c := Liquides.contenu(genre, "", id, o.liquide)
		if not c.is_empty() and c[0] == voulu:
			o.ident = id
			break
	return o

func _cam_vers(de: Vector3, vers: Vector3, fov := 52.0) -> void:
	_cam.global_position = de
	_cam.look_at(vers, Vector3.UP)
	_cam.fov = fov
	_lampe.global_position = de + (vers - de).normalized() * 0.4 + Vector3(0.3, 0.5, 0)

func _travelling(de: Vector3, a: Vector3, vers0: Vector3, vers1: Vector3, t: float) -> void:
	var k := maxi(1, roundi(t * 30.0))
	for i in k:
		var u := smoothstep(0.0, 1.0, (i + 1) / float(k))
		_cam_vers(de.lerp(a, u), vers0.lerp(vers1, u), _cam.fov)
		if planche:
			await process_frame
		else:
			await _image()

func _go() -> void:
	seed(2311)
	sortie = _arg("sortie", "user://film_liquides")
	planche = _arg("planche") != ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	Sang.niveau_force = 2
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
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
	s.mannequin.position = Vector3(-30.0, 0, 30.0)
	s.mur.position = Vector3(-31, 1.3, 32)
	s.hud.visible = false
	s.joueur.mains.visible = false
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, 0.0)
	_cam = Camera3D.new()
	s.add_child(_cam)
	_cam.current = true
	_lampe = OmniLight3D.new()       # lumière de tournage (film seulement)
	_lampe.light_color = Color(1.0, 0.9, 0.78)
	_lampe.light_energy = 0.6
	_lampe.omni_range = 6.0
	_lampe.shadow_enabled = false
	s.add_child(_lampe)
	await _attendre_images(20)
	if _arg("banc") != "":
		await _banc()
	else:
		await _film()
	quit()

func _attendre_images(k: int) -> void:
	for i in k:
		await process_frame

## Salle : plancher de bois, mur de pierre, étagère de bois contre le mur ; torche chaude.
func _salle() -> Dictionary:
	var roche := Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.5), Vector2(3, 3))
	var bois := Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(2, 2))
	_boite(Vector3(0, -0.045, -1), Vector3(14, 0.1, 14), bois, "bois")                 # plancher
	_boite(Vector3(0, 1.6, -4.4), Vector3(10, 3.2, 0.4), roche, "pierre")              # mur de pierre (fond)
	_boite(Vector3(-4.0, 1.6, -1), Vector3(0.4, 3.2, 8), roche, "pierre")
	_boite(Vector3(0, 3.3, -1), Vector3(10, 0.2, 8), bois, "bois")                    # plafond
	# étagère : planche épaisse, deux consoles collées au mur (le devant est libre : le liquide s'égoutte au sol)
	_boite(Vector3(-2.2, 0.875, -3.85), Vector3(1.5, 0.05, 0.7), bois, "bois")        # dessus à y = 0,9
	for x in [-2.8, -1.6]:
		_boite(Vector3(x, 0.45, -4.12), Vector3(0.08, 0.85, 0.16), bois, "bois")
	EffetsSol.dehors = false
	s.soleil.visible = false
	s.env.background_color = Color(0.01, 0.01, 0.015)
	s.env.ambient_light_color = Color(0.5, 0.42, 0.36)
	s.env.ambient_light_energy = 0.32
	var t := OmniLight3D.new()
	t.light_color = Color(1.0, 0.66, 0.36)
	t.light_energy = 2.0
	t.omni_range = 7.5
	t.shadow_enabled = true
	s.add_child(t)
	t.position = Vector3(0.6, 2.3, -2.6)
	return {"torche": t}

# ------------------------------------------------------------------ film

func _film() -> void:
	var salle := _salle()
	var etage := _meuble("pq_tonneau", Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3(-2.15, 0.9, -3.9)), "biere")
	var jarre := _meuble("pq_jarre", Transform3D(Basis.from_scale(Vector3.ONE * 1.0), Vector3(1.6, 0.0, -2.6)), "vin")
	await _attendre_images(20)
	# --- 1. tonneau de bière sur l'étagère
	_cam_vers(Vector3(-0.7, 1.25, -1.5), Vector3(-2.15, 0.55, -3.7), 54.0)
	_legende("Tonneau de bière brisé sur une étagère")
	await _filmer(1.0)
	await _cliche("tonneau_avant")
	if etage != null:
		etage.casser(true, etage.global_position + Vector3(0.1, 0.1, 0.25), Vector3(0, -0.5, 1.5))
	await _filmer(0.35)
	await _cliche("tonneau_jet")
	await _filmer(1.6)
	await _cliche("tonneau_coule")
	_legende("La bière s'égoutte au bord et s'étale au sol")
	await _travelling(Vector3(-0.7, 1.25, -1.5), Vector3(-1.0, 0.95, -1.9), Vector3(-2.15, 0.55, -3.7), Vector3(-2.1, 0.2, -3.4), 2.0)
	await _filmer(1.6)
	await _cliche("tonneau_flaque")
	# --- 2. jarre de vin au sol
	_legende("Jarre de vin brisée au sol")
	_cam_vers(Vector3(2.6, 1.05, -1.0), Vector3(1.5, 0.15, -2.6), 54.0)
	await _filmer(0.6)
	if jarre != null:
		jarre.casser(true, jarre.global_position + Vector3(0, 0.3, 0.2), Vector3(0, -1.0, -1.0))
	await _filmer(0.5)
	await _cliche("jarre_jet")
	await _filmer(2.2)
	await _cliche("jarre_flaque")
	# --- 3. coup d'épée sur un bandit devant le mur de pierre
	var b := _ennemi(Vector3(0.0, 0, -3.3), deg_to_rad(5.0))
	b.set_physics_process(false)
	_legende("Coup d'épée : le sang gicle sur le mur et coule")
	_cam_vers(Vector3(1.3, 1.5, -0.6), Vector3(-0.2, 1.1, -4.0), 56.0)
	await _filmer(0.6)
	b.recevoir_coup(5.0, _cam.global_position, false, _info(b, 1.35, Vector3(-0.35, -0.1, -1.0)))
	await _filmer(0.25)
	await _cliche("epee_gicle")
	await _filmer(0.6)
	b.recevoir_coup(5.0, _cam.global_position, false, _info(b, 1.25, Vector3(0.4, -0.15, -1.0)))
	await _filmer(1.6)
	await _cliche("epee_mur")
	_legende("Les coulures descendent ; gouttes et flaque au sol")
	b.vie = 1.0
	b.recevoir_coup(900.0, _cam.global_position, true, _info(b, 1.2, Vector3(-0.2, 0, -1)))
	await _travelling(Vector3(1.3, 1.5, -0.6), Vector3(1.0, 1.35, -1.7), Vector3(-0.2, 1.1, -4.0), Vector3(-0.3, 0.3, -3.8), 2.4)
	await _filmer(1.4)
	await _cliche("epee_sol")
	# --- 4. dehors : sang sur la neige
	_legende("Dehors : le sang sur la neige")
	b.queue_free()
	# plus loin (x + 40) : sol de neige, dehors, soleil
	var X := Vector3(40.0, 0, 0)
	EffetsSol.dehors = true
	s.soleil.visible = true
	s.env.background_color = Color(0.55, 0.6, 0.68)
	s.env.ambient_light_energy = 0.8
	_boite(X + Vector3(0, -0.035, -1), Vector3(14, 0.08, 14), Palette.materiau(Palette.tex("neige", Palette.NEIGE, 4, 0.5), Vector2(6, 6)))
	EffetsSol.forcer_neige = true
	var b2 := _ennemi(X + Vector3(0.2, 0, -2.6), deg_to_rad(-10.0))
	b2.set_physics_process(false)
	_cam_vers(X + Vector3(1.6, 1.45, -0.4), X + Vector3(0.0, 0.3, -2.8), 56.0)
	await _filmer(0.4)
	b2.recevoir_coup(5.0, _cam.global_position, false, _info(b2, 1.3, Vector3(-0.6, -0.2, -0.8)))
	await _filmer(0.7)
	b2.vie = 1.0
	b2.recevoir_coup(900.0, _cam.global_position, true, _info(b2, 1.2, Vector3(-0.3, -0.1, -1)))
	await _filmer(2.2)
	await _cliche("neige")
	await _filmer(0.6)
	print("FILM images %d | %s | gouttes résolues %d | cout liquides %.1f ms" % [n, str(Liquides.stats), GouttesSang.resolues, Liquides.cout_us / 1000.0])

# ------------------------------------------------------------------ banc : 5 tonneaux

func _banc() -> void:
	_salle()
	_lampe.visible = false
	var tonneaux := []
	for k in 5:
		tonneaux.append(_meuble("pq_tonneau", Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3(-2.4 + k * 1.1, 0.0, -2.6 - (k % 2) * 0.5)), "biere"))
	_cam_vers(Vector3(0.0, 1.6, 1.2), Vector3(0.0, 0.4, -2.8), 60.0)
	await _attendre_images(60)
	var calme := await _mesure(3.0)
	for o in tonneaux:
		if o != null:
			(o as ObjetVivant).casser(true, (o as Node3D).global_position + Vector3(0, 0.2, 0.3), Vector3(0, 0, -2))
	var casse := await _mesure(8.0)
	var apres := await _mesure(3.0)
	print("BANC TONNEAUX %s : calme %.1f FPS | casse de 5 tonneaux %.1f FPS (1%% bas %.1f) | calme après %.1f FPS | flaques %d | cout liquides %.1f ms" % [
		"liquides" if Liquides.actif else "sans-liquides", calme["fps"], casse["fps"], casse["bas"], apres["fps"],
		(Liquides.instance.flaques.size() if Liquides.instance else get_nodes_in_group("flaques").size()), Liquides.cout_us / 1000.0])

func _mesure(duree: float) -> Dictionary:
	var temps := PackedFloat32Array()
	var t := 0.0
	var dernier := Time.get_ticks_usec()
	while t < duree:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - dernier) / 1e6
		dernier = now
		temps.append(dt)
		t += dt
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
