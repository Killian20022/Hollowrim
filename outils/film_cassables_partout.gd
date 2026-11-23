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
	if nom.begins_with("ap_"):
		print("FILM casse %s : %s" % [nom, str(CasseObjets.derniere_mesure)])
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

## Hauteur du sol (décor, calque 1) sous (x, z), sous `de_haut`.
func _sol_y(x: float, z: float, de_haut: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, de_haut, z), Vector3(x, de_haut - 30.0, z), 1, [j.get_rid()])
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) if not r.is_empty() else de_haut - 1.0

## Le joueur se place à `dist` m de `cible`, du côté de `depuis`, et la regarde.
## Point de vue DÉGAGÉ sur `o` : autour de lui (12 directions, 3 distances, d'abord du côté de `depuis`), le premier d'où un rayon
## tiré de l'œil (1,55 m) touche l'objet lui-même ; Vector3.INF si aucun.
func _vue_degagee(o: ObjetVivant, depuis: Vector3) -> Vector3:
	var espace := j.get_world_3d().direct_space_state
	var base := atan2(depuis.x - o.global_position.x, depuis.z - o.global_position.z)
	for dist: float in [2.6, 3.2, 2.1]:
		for k in 12:
			var a: float = base + float(k / 2) * 0.52 * (1.0 if k % 2 == 0 else -1.0)
			var p := o.global_position + Vector3(sin(a), 0, cos(a)) * dist
			var y: float = sol_fixe if not is_nan(sol_fixe) else float(s.hauteur(p.x, p.z))
			var oeil := Vector3(p.x, y + 1.55, p.z)
			var q := PhysicsRayQueryParameters3D.create(oeil, o.global_position, 1 | Cassable.CALQUE, [j.get_rid()])
			var r := espace.intersect_ray(q)
			var pied := PhysicsRayQueryParameters3D.create(oeil, Vector3(p.x, y - 0.3, p.z), 1, [j.get_rid()])
			var rp := espace.intersect_ray(pied)      # rien entre l'œil et le plancher (pas dans un meuble, pas dans un mur)
			if not r.is_empty() and r["collider"] == o and (rp.is_empty() or float((rp["position"] as Vector3).y) < y + 0.1):
				return Vector3(p.x, y, p.z)
	return Vector3.INF

## Le joueur se tient au point de vue dégagé sur `o` (sinon à `dist` m du côté de `depuis`) et le regarde.
func _cadrer(o: ObjetVivant, depuis: Vector3, dist := 2.6) -> void:
	var v := _vue_degagee(o, depuis)
	if v == Vector3.INF:
		await _placer(o.global_position, depuis, dist)
		return
	j.global_position = v + Vector3(0, 0.02, 0)
	j.velocity = Vector3.ZERO
	for i in 2:
		await physics_frame
	_regarder(o.global_position)

var sol_fixe := NAN      ## intérieur : hauteur du plancher (sinon relief du monde)
func _placer(cible: Vector3, depuis: Vector3, dist: float, h := 0.0) -> void:
	var d := depuis - cible
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	var p := Vector3(cible.x, 0, cible.z) + d * dist
	var y: float = sol_fixe if not is_nan(sol_fixe) else float(s.hauteur(p.x, p.z))
	j.global_position = Vector3(p.x, y + 0.02 + h, p.z)
	j.velocity = Vector3.ZERO
	for i in 2:
		await physics_frame
	_regarder(cible)

## Point de départ d'un lancer vers `cible` : entre le joueur et la cible, à `dist` m de la cible, décalé sur le côté, `haut` m au-dessus.
func _depart_lancer(cible: Node3D, dist: float, haut: float) -> Vector3:
	var vers := j.global_position - cible.global_position
	vers.y = 0.0
	vers = vers.normalized()
	var cote := vers.cross(Vector3.UP).normalized()
	return cible.global_position + (vers * 0.75 + cote * 0.65).normalized() * dist + Vector3(0, haut, 0)

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
	var arrivee := ceili(t * 30.0)      # images (--fixed-fps 30) : la parabole y arrive
	var bc := b.global_position + Vector3(0, haut * 0.6, 0)
	for i in max_images:
		await _image()
		if a.casse or not is_instance_valid(a):
			break
		var r: float = 0.45 + ((b.get("_taille") as Vector3).length() * 0.3 if b.get("_taille") != null else 0.2)
		if a.global_position.distance_to(bc) < r or i + 1 >= arrivee:
			var va := a.linear_velocity if a.linear_velocity.length() > v.length() * 0.7 else v      # vitesse du lancer (un objet lourd freiné par le sol garde celle-ci)
			var rb := false
			if b.has_method("recevoir_choc"):
				rb = b.call("recevoir_choc", va, a.mass, a.global_position)
			var ra := a.recevoir_choc(va, maxf(a.mass, 8.0), a.global_position)
			print("FILM impact %s -> %s : %.1f m/s, %.0f J, cible brisée %s, projectile brisé %s (image %d/%d, dist %.2f)" % [a.genre, b.get("genre"), va.length(),
				CasseObjets.energie(va, a.mass), rb, ra, i + 1, arrivee, a.global_position.distance_to(bc)])
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
	var ips := root.get_node_or_null("CompteurIps")      # le compteur d'images/s du film à pas fixe ne veut rien dire
	if ips != null:
		ips.set("visible", false)
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	s.cycle.heure = 11.0
	for l: Array in s.hud.lieux_nommes:
		s.hud.lieux_vus[l[2]] = true
	s.hud.aide_t = 0.0
	j.mains.visible = false
	j.set_physics_process(false)      # pilote automatique : le corps ne bouge que par nous
	if s.get("crime") != null:      # film de démonstration : pas de témoins ni de gardes (la casse d'un bien possédé reste un vol en jeu)
		(s.crime as Node).remove_from_group("crime")
	var ip: Interieur = s.village.interieur("halle")
	var centre := ip.to_global(Vector3(0, ip.sol_y + 0.6, 0))
	sol_fixe = ip.to_global(Vector3(0, ip.sol_y, 0)).y
	var meubles := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.meuble)
	print("FILM %d meubles physiques" % meubles.size())

	# ---------------------------------------------------------------- 1. halle
	var tonneau := _proche(["q_tonneau", "pq_tonneau", "q_tonneau_2"], centre, [], 9.0)
	var jarre: ObjetVivant = null      # une jarre de la halle qu'on voit d'un point dégagé, de préférence au sol
	var jarres := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.genre in ["q_jarre", "pq_jarre"] and o.ident.begins_with("halle"))
	jarres.sort_custom(func(x: ObjetVivant, y: ObjetVivant) -> bool: return x.global_position.y < y.global_position.y)
	for o: ObjetVivant in jarres:
		if _vue_degagee(o, centre) != Vector3.INF:
			jarre = o
			break
	if jarre == null:
		jarre = _proche(["q_jarre", "pq_jarre"], centre, [], 9.0)
	var tonneaux := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.genre in ["q_tonneau", "pq_tonneau", "q_tonneau_2"] and o.ident.begins_with("halle"))
	for o: ObjetVivant in tonneaux:
		if _vue_degagee(o, centre) != Vector3.INF:
			tonneau = o
			break
	var tabouret := _proche(["q_tabouret", "pq_tabouret"], jarre.global_position if jarre else centre)
	var chaise := _proche(["q_chaise", "pq_chaise", "q_chaise_2"], centre, [], 12.0)
	if chaise == null:
		chaise = _proche(["q_tabouret", "pq_tabouret"], centre, [tabouret], 12.0)
	print("FILM halle : tonneau %s, jarre %s, tabouret %s, chaise %s" % [tonneau != null, jarre != null, tabouret != null, chaise != null])
	if jarre != null and tabouret != null:
		await _cadrer(jarre, centre, 2.2)
		_regarder(jarre.global_position + Vector3(0, 0.1, 0))
		for i in 30:
			await process_frame
		await _cliche("av_jarre")
		await _filmer(20)
		# le tabouret part d'un bras du joueur, de biais, et vole droit dans la jarre (rien entre les deux)
		tabouret.global_position = _depart_lancer(jarre, 1.3, 0.5)
		tabouret.actualiser_visuel()
		await _filmer(4)
		await _lancer(tabouret, jarre, 7.0, 0.25)
		await _filmer(10)
		await _cliche("ap_jarre")
		await _filmer(35)
	if tonneau != null:
		await _cadrer(tonneau, centre, 2.4)
		_regarder(tonneau.global_position + Vector3(0, 0.2, 0))
		for i in 10:
			await process_frame
		await _cliche("av_tonneau")
		await _filmer(15)
		# un autre tonneau de la halle, soulevé, projeté dans le premier : les deux éclatent en douelles et cerclages
		var autre := _proche(["q_tonneau", "pq_tonneau", "q_tonneau_2", "q_caisse", "pq_caisse"], tonneau.global_position, [tonneau])
		if autre != null:
			autre.global_position = _depart_lancer(tonneau, 1.5, 0.7)
			autre.actualiser_visuel()
			await _filmer(4)
			await _lancer(autre, tonneau, 6.5, 0.4)
		else:
			tonneau.recevoir_choc(Vector3(0, 0, -10), 15.0, tonneau.global_position)
		await _filmer(12)
		await _cliche("ap_tonneau")
		await _filmer(45)
	if chaise != null:
		var mur := chaise.global_position - (centre - chaise.global_position).normalized() * 0.2
		await _cadrer(chaise, centre, 2.1)
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
	sol_fixe = NAN
	var place := Vector3(46.9, 0.0, 53.9)      # ruelle au sud de la place : tonneaux, caisse et sacs PUBLICS (pas de réserve d'étal)
	var t2: ObjetVivant = null
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.genre in ["q_tonneau", "pq_tonneau", "q_tonneau_2"] and o.ident.begins_with("village:") and not o.casse \
				and (t2 == null or o.global_position.distance_to(Vector3(place.x, o.global_position.y, place.z)) < t2.global_position.distance_to(Vector3(place.x, t2.global_position.y, place.z))):
			t2 = o
	if t2 != null:
		await _cadrer(t2, t2.global_position + Vector3(-2.6, 0, -2.2), 3.4)
		_regarder(t2.global_position + Vector3(0, 0.2, 0))
		for i in 30:
			await process_frame
		await _filmer(20)
		var caisse := _proche(["q_caisse", "pq_caisse", "q_caisse_2", "q_cageot_vide", "pq_cageot_vide"], t2.global_position, [t2], 6.0)
		if caisse != null:
			caisse.global_position = _depart_lancer(t2, 1.6, 0.6)
			caisse.actualiser_visuel()
			await _filmer(4)
			await _lancer(caisse, t2, 12.0, 0.4)
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
	print("FILM %d images dans %s ; éclats %d ; dernière casse %s" % [n, sortie, CasseObjets.nb_eclats(), str(CasseObjets.derniere_mesure)])
	quit(0)
