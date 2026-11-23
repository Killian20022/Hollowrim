extends SceneTree
## Film « cassables partout » (preuves du chantier, 2026-11-23), vue du joueur, pilote automatique et impulsions scriptées :
##   1. halle de Gunnar : un tabouret projeté contre une jarre (elle éclate, saumure renversée), un cageot lancé dans un tonneau (douelles
##      et cerclages, bière qui se répand), une chaise jetée contre le mur ;
##   2. place du village : une caisse lancée dans un tonneau, un sac bousculé, un cageot brisé.
## Chaque « lancer » imite ImpactsLances : au contact, recevoir_choc(vitesse, masse, point) sur l'objet lancé ET sur sa cible.
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_cassables_partout.gd -- --nouvelle --paisible --sortie=<dossier> [--planche=<dossier>]
## Images : <dossier>/f_00000.png … ; --planche : avant / après de la casse d'un tonneau, d'une jarre, d'une chaise (av_<genre>.png, ap_<genre>.png).

const SCENE := preload("res://scenes/foret_test.tscn")

var s: Node3D
var j: CharacterBody3D
var sortie := ""
var planche := ""
var n := 0
var _regard := Vector3.ZERO

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if sortie != "":
		root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _cliche(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if planche != "":
		root.get_texture().get_image().save_png("%s/%s.png" % [planche, nom])

func _filmer(k: int) -> void:
	for i in k:
		await _image()

func _regarder(p: Vector3) -> void:
	_regard = p
	var o: Vector3 = j.camera.global_position
	var d := p - o
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _tourner(vers: Vector3, k: int) -> void:
	var de := _regard
	for i in k:
		_regarder(de.lerp(vers, smoothstep(0.0, 1.0, (i + 1) / float(k))))
		await _image()

## Meuble le plus proche de `de` parmi `genres` (intact, endormi).
func _proche(genres: Array, de: Vector3, sauf: Array = [], rayon := 1e9) -> ObjetVivant:
	var best: ObjetVivant = null
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.genre in genres and not o.casse and not o.has_meta("pris") and not (o in sauf) and o.global_position.distance_to(de) < rayon \
				and (best == null or o.global_position.distance_to(de) < best.global_position.distance_to(de)):
			best = o
	return best

## Le joueur se place à `dist` m de `cible`, du côté de `depuis`, et la regarde.
func _placer(cible: Vector3, depuis: Vector3, dist: float, h := 0.0) -> void:
	var d := depuis - cible
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	j.global_position = Vector3(cible.x, j.global_position.y, cible.z) + d * dist
	j.velocity = Vector3.ZERO
	for i in 3:
		await physics_frame
	var y_sol := j.global_position.y
	j.global_position.y = y_sol + h
	_regarder(cible)

## Lance `a` (réveillé, vitesse vers `b`) ; au contact (distance des centres), choc sur les deux, comme ImpactsLances.
func _lancer(a: ObjetVivant, b: Node3D, vitesse: float, haut := 0.25, max_images := 40) -> void:
	a.saisi_telekinesie(true)
	a.saisi_telekinesie(false)
	var cible := b.global_position + Vector3(0, haut, 0)
	var dir := (cible - a.global_position)
	var t := dir.length() / vitesse
	var v := dir / maxf(t, 0.05) + Vector3.UP * 9.8 * t * 0.5      # parabole qui arrive sur la cible
	a.linear_velocity = v
	a.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-4, 4), randf_range(-7, 7))
	a.elan = Vector3.ZERO
	a.set_meta("lance_par", j)
	var touche := false
	for i in max_images:
		await _image()
		if a.casse or not is_instance_valid(a):
			break
		var r := 0.45 + (b.get("_taille").length() * 0.3 if b.get("_taille") != null else 0.2)
		if not touche and a.global_position.distance_to(b.global_position + Vector3(0, haut * 0.6, 0)) < r:
			touche = true
			var va := a.linear_velocity if a.linear_velocity.length() > 2.0 else v
			if b.has_method("recevoir_choc"):
				b.call("recevoir_choc", va, a.mass, a.global_position)
			a.recevoir_choc(va, maxf(a.mass, 8.0), a.global_position)
			a.linear_velocity *= 0.3
			break

func _go() -> void:
	sortie = _arg("sortie", "")
	planche = _arg("planche", "")
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	if planche != "":
		DirAccess.make_dir_recursive_absolute(planche)
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	j = s.joueur
	s.cycle.heure = 11.0
	for l: Array in s.hud.lieux_nommes:
		s.hud.lieux_vus[l[2]] = true
	s.hud.aide_t = 0.0
	j.mains.visible = false
	j.set_physics_process(false)      # pilote automatique : le corps ne bouge que par nous
	var ip: Interieur = s.village.interieur("halle")
	var centre := ip.to_global(Vector3(0, ip.sol_y + 0.6, 0))
	var meubles := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.meuble)
	print("FILM %d meubles physiques" % meubles.size())

	# ---------------------------------------------------------------- 1. halle
	var tonneau := _proche(["q_tonneau", "pq_tonneau", "q_tonneau_2"], centre, [], 9.0)
	var jarre := _proche(["q_jarre", "pq_jarre"], centre, [], 9.0)
	var tabouret := _proche(["q_tabouret", "pq_tabouret"], jarre.global_position if jarre else centre)
	var chaise := _proche(["q_chaise", "pq_chaise", "q_chaise_2"], centre)
	print("FILM halle : tonneau %s, jarre %s, tabouret %s, chaise %s" % [tonneau != null, jarre != null, tabouret != null, chaise != null])
	if jarre != null and tabouret != null:
		await _placer(jarre.global_position, centre, 2.6)
		j.global_position.y = ip.to_global(Vector3(0, ip.sol_y, 0)).y + 0.02
		_regarder(jarre.global_position + Vector3(0, 0.1, 0))
		for i in 30:
			await process_frame
		await _cliche("av_jarre")
		await _filmer(20)
		var source := tabouret
		if source.global_position.distance_to(jarre.global_position) > 5.0:      # tabouret trop loin : on le pose au bord du champ
			source.global_position = j.global_position + (jarre.global_position - j.global_position) * 0.35 + Vector3(0, 0.6, 0) + j.global_transform.basis.x * 0.8
		await _lancer(source, jarre, 8.0, 0.3)
		await _filmer(10)
		await _cliche("ap_jarre")
		await _filmer(30)
	if tonneau != null:
		await _placer(tonneau.global_position, centre, 2.8)
		j.global_position.y = ip.to_global(Vector3(0, ip.sol_y, 0)).y + 0.02
		_regarder(tonneau.global_position + Vector3(0, 0.15, 0))
		for i in 10:
			await process_frame
		await _cliche("av_tonneau")
		await _filmer(15)
		var cageot := _proche(["q_cageot_vide", "pq_cageot_vide", "q_caisse", "pq_caisse", "q_tabouret", "pq_tabouret"], tonneau.global_position, [tonneau])
		if cageot != null:
			cageot.global_position = j.global_position + (tonneau.global_position - j.global_position) * 0.3 + Vector3(0, 0.9, 0) - j.global_transform.basis.x * 0.6
			await _lancer(cageot, tonneau, 10.0, 0.45)
		else:
			tonneau.recevoir_choc(Vector3(0, 0, -10), 15.0, tonneau.global_position)
		await _filmer(12)
		await _cliche("ap_tonneau")
		await _filmer(40)
	if chaise != null:
		var mur := chaise.global_position - (centre - chaise.global_position).normalized() * 0.2
		await _placer(chaise.global_position, centre, 2.4)
		j.global_position.y = ip.to_global(Vector3(0, ip.sol_y, 0)).y + 0.02
		_regarder(chaise.global_position + Vector3(0, 0.2, 0))
		for i in 10:
			await process_frame
		await _cliche("av_chaise")
		await _filmer(15)
		# saisie télékinétique imitée : la chaise s'élève, tremble, puis part contre le mur et éclate
		chaise.saisi_telekinesie(true)
		chaise.gravity_scale = 0.0
		var p0 := chaise.global_position
		for i in 18:
			chaise.linear_velocity = (p0 + Vector3(0, 1.0, 0) - chaise.global_position) * 6.0
			chaise.angular_velocity = Vector3(0.6, 1.2, 0.3)
			await _image()
		chaise.gravity_scale = 1.0
		chaise.saisi_telekinesie(false)
		var dirm := (mur - chaise.global_position)
		dirm.y = 0.0
		chaise.linear_velocity = dirm.normalized() * 11.0 + Vector3.UP * 1.0
		for i in 25:
			await _image()
			if chaise.casse:
				break
			if chaise.global_position.distance_to(p0 + Vector3(0, 1.0, 0)) > 0.9 and chaise.linear_velocity.length() < 6.0:      # elle a heurté le mur
				chaise.recevoir_choc(dirm.normalized() * 11.0, chaise.mass, chaise.global_position)
				break
		if not chaise.casse:
			chaise.recevoir_choc(dirm.normalized() * 11.0, chaise.mass, chaise.global_position)
		await _filmer(8)
		await _cliche("ap_chaise")
		await _filmer(35)

	# ---------------------------------------------------------------- 2. place du village
	var place := Vector3(49.0, 0.0, 33.0)
	var t2 := _proche(["q_tonneau", "pq_tonneau", "q_tonneau_2"], place)
	if t2 != null and t2.ident.begins_with("village") or t2 != null:
		var vue := t2.global_position + Vector3(-3.0, 0, 2.4)
		j.global_position = Vector3(vue.x, t2.global_position.y + 0.3, vue.z)
		for i in 4:
			await physics_frame
		_regarder(t2.global_position + Vector3(0, 0.2, 0))
		for i in 30:
			await process_frame
		await _filmer(20)
		var caisse := _proche(["q_caisse", "pq_caisse", "q_caisse_2", "q_cageot_vide", "pq_cageot_vide"], t2.global_position, [t2], 6.0)
		if caisse != null:
			await _lancer(caisse, t2, 11.0, 0.4)
		else:
			t2.recevoir_choc(Vector3(0, 0, -10), 15.0, t2.global_position)
		await _filmer(35)
		var sac := _proche(["q_sac", "pq_sac", "q_sac_debout"], t2.global_position, [], 6.0)
		if sac != null:
			await _tourner(sac.global_position + Vector3(0, 0.2, 0), 15)
			sac.saisi_telekinesie(true)
			sac.saisi_telekinesie(false)
			sac.linear_velocity = (sac.global_position - j.global_position).normalized() * 3.5 + Vector3.UP * 2.0
			sac.angular_velocity = Vector3(3, 1, 2)
			await _filmer(30)
		var cg := _proche(["q_cageot_vide", "pq_cageot_vide", "q_cageot_pommes", "pq_cageot_pommes", "q_cageot_carottes", "q_jarre"], j.global_position, [], 10.0)
		if cg != null:
			await _tourner(cg.global_position + Vector3(0, 0.1, 0), 15)
			await _filmer(5)
			cg.frapper(true, j.global_position)
			await _filmer(40)
	print("FILM %d images dans %s ; éclats %d" % [n, sortie, CasseObjets.nb_eclats()])
	quit(0)
