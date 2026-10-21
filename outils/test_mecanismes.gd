extends SceneTree
## Test headless des mécanismes de donjon (scripts/mecanisme.gd, scripts/piege.gd) : statues, braseros (mauvais ordre, extinction),
## socles (objets consommés), mur fragile (cassé seulement par un coup PUISSANT), sauvegarde/restauration via quetes.vus,
## dalle à fléchettes (dégâts + évitement) et souffle de givre (rythme, dégâts, évitement).
## godot --headless --path . --script outils/test_mecanismes.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var labo: Node3D
var _echecs := 0
var _n_appels := 0
var _restaure_vu := false

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(sec: float) -> void:
	for i in int(ceil(sec * 60.0)):
		await physics_frame

func _rappel() -> void:
	_n_appels += 1
	_restaure_vu = Mecanisme.restauration

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(1.0)
	labo = Node3D.new()
	m.add_child(labo)
	var j: CharacterBody3D = m.joueur
	var base: Vector3 = j.global_position
	# sol d'essai (le terrain de la zone témoin ne couvre pas toute la surface d'essai) : dalle de 80 m, dessus au niveau du joueur
	Mecanisme.collision(labo, base + Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	print("joueur : ", base, " au sol : ", j.is_on_floor())
	await _statues(base)
	await _braseros(base)
	await _socles(base)
	await _mur(base)
	await _dalle(base)
	await _souffle(base)
	print("ECHECS : %d" % _echecs if _echecs > 0 else "TEST MÉCANISMES : OK")
	quit(1 if _echecs > 0 else 0)

func _vus(cle: String) -> bool:
	return m.quetes.vus.has(cle)

# ------------------------------------------------------------------ statues
func _statues(base: Vector3) -> void:
	print("-- statues")
	var pos: Array = [base + Vector3(-6, 0, 6), base + Vector3(-4, 0, 6), base + Vector3(-2, 0, 6)]
	var sol: Array = [0, 1, 2]
	_n_appels = 0
	var n = Mecanisme.statues(labo, pos, sol, "t_statues", _rappel)
	_verif(n is Node3D and not n.est_resolu(), "statues créées, non résolues")
	var depart_ok := true
	for i in 3:
		if n.orientation(i) == sol[i]:
			depart_ok = false
	_verif(depart_ok, "aucune statue n'est bien orientée au départ")
	_verif(n.get_child_count() > 6 and n._inters.size() == 3, "3 interactifs (E) sur les statues")
	# un tour complet d'une statue la ramène au départ ; l'énigme se résout en orientant les trois
	var k0: int = n.orientation(0)
	for i in 4:
		n.tourner(0)
	_verif(n.orientation(0) == k0 and _n_appels == 0, "4 quarts de tour = retour au départ, pas résolu")
	for i in 3:
		while n.orientation(i) != sol[i]:
			n.tourner(i)
	_verif(n.est_resolu() and _n_appels == 1 and _vus("meca:t_statues:resolu"), "résolue : rappel unique + événement meca:t_statues:resolu")
	var o: int = n.orientation(1)
	n.tourner(1)
	_verif(n.orientation(1) == o, "résolue : plus de rotation")
	# restauration : nouvelle instance (partie chargée) -> déjà résolue, rappel en mode restauration
	n.queue_free()
	await _attendre(0.2)
	_n_appels = 0
	_restaure_vu = false
	var n2 = Mecanisme.statues(labo, pos, sol, "t_statues", _rappel)
	_verif(n2.est_resolu() and _n_appels == 1 and _restaure_vu and n2.orientation(2) == 2, "restauration : résolue, rappel en mode restauration, statues en place")
	_verif(not Mecanisme.restauration, "Mecanisme.restauration remis à faux")
	# mort avant résolution : remise à zéro des orientations
	n2.queue_free()
	await _attendre(0.2)
	m.quetes.vus.erase("meca:t_statues:resolu")
	var n3 = Mecanisme.statues(labo, pos, sol, "t_statues", _rappel)
	n3.tourner(0)
	n3.restaurer()
	_verif(not n3.est_resolu() and n3.orientation(0) == (sol[0] + 1) % 4, "reset : orientations remises au départ")
	n3.queue_free()

# ------------------------------------------------------------------ braseros
func _braseros(base: Vector3) -> void:
	print("-- braseros")
	var pos: Array = [base + Vector3(-6, 0, -6), base + Vector3(-4, 0, -6), base + Vector3(-2, 0, -6), base + Vector3(0, 0, -6)]
	var ordre: Array = [2, 0, 3]
	_n_appels = 0
	var b = Mecanisme.braseros(labo, pos, ordre, "t_braseros", _rappel)
	b.activer(2)
	b.activer(0)
	_verif(b.allumes == [2, 0] and b.est_allume(2) and b.est_allume(0), "bon début : 2 puis 0 allumés")
	var lignes: Array = b.activer(1)
	_verif(b.allumes.is_empty() and not b.est_resolu() and lignes.size() > 0, "mauvais ordre : tout s'éteint (avec message)")
	b.activer(2)
	b.activer(0)
	b.activer(0)
	_verif(b.allumes == [2], "extinction d'un brasero : retire aussi les suivants")
	b.activer(2)
	_verif(b.allumes.is_empty(), "le seul brasero allumé s'éteint")
	b.activer(3)
	_verif(b.allumes.is_empty(), "3 d'abord : mauvais ordre")
	for i in ordre:
		b.activer(i)
	_verif(b.est_resolu() and _n_appels == 1 and _vus("meca:t_braseros:resolu"), "bon ordre : résolu, rappel unique, événement meca:t_braseros:resolu")
	_verif((b._flammes[2] as Node3D).visible and not (b._flammes[1] as Node3D).visible, "flammes visibles seulement sur les braseros de l'ordre")
	b.queue_free()
	await _attendre(0.2)
	_n_appels = 0
	var b2 = Mecanisme.braseros(labo, pos, ordre, "t_braseros", _rappel)
	_verif(b2.est_resolu() and _n_appels == 1 and _restaure_vu and b2.allumes == ordre, "restauration : braseros allumés dans l'ordre, rappel en mode restauration")
	b2.queue_free()

# ------------------------------------------------------------------ socles
func _socles(base: Vector3) -> void:
	print("-- socles")
	var inv = m.joueur.inventaire
	var ids: Array = ["fragment_sceau_os", "fragment_sceau_givre", "fragment_sceau_eau"]
	for id in ids:
		while inv.a(id):
			inv.retirer(id)
	var pos: Array = [base + Vector3(6, 0, -6), base + Vector3(8, 0, -6), base + Vector3(10, 0, -6)]
	_n_appels = 0
	var s = Mecanisme.socles(labo, pos, ids, "t_socles", _rappel)
	var l: Array = s.poser(0)
	_verif(l.size() == 1 and "sceau des Os" in l[0] and not s.poses[0], "sans l'objet : le socle dit ce qui manque, rien posé")
	inv.ajouter("fragment_sceau_os")
	inv.ajouter("fragment_sceau_eau")
	l = s.poser(1)
	_verif(not s.poses[1] and inv.a("fragment_sceau_eau"), "mauvais socle (pas le fragment de givre) : rien posé, rien consommé")
	s.poser(0)
	_verif(s.poses[0] and not inv.a("fragment_sceau_os") and _vus("meca:t_socles:s0"), "fragment des Os posé, consommé, événement s0")
	s.poser(2)
	_verif(s.poses[2] and not inv.a("fragment_sceau_eau") and not s.est_complet() and _n_appels == 0, "fragment de l'Eau posé ; pas encore complet")
	inv.ajouter("fragment_sceau_givre")
	s.poser(1)
	_verif(s.est_complet() and _n_appels == 1 and _vus("meca:t_socles:resolu"), "complet : rappel unique + meca:t_socles:resolu")
	s.queue_free()
	await _attendre(0.2)
	_n_appels = 0
	var s2 = Mecanisme.socles(labo, pos, ids, "t_socles", _rappel)
	_verif(s2.est_complet() and not s2.poses.has(false) and _n_appels == 1 and _restaure_vu, "restauration : 3 fragments en place, rappel en mode restauration")
	_verif(not inv.a("fragment_sceau_os") and not inv.a("fragment_sceau_eau"), "inventaire : fragments toujours consommés")
	s2.queue_free()

# ------------------------------------------------------------------ mur fragile
func _mur(base: Vector3) -> void:
	print("-- mur fragile")
	var j: CharacterBody3D = m.joueur
	var cam: Camera3D = j.camera
	var face: Vector3 = -cam.global_transform.basis.z
	face.y = 0.0
	face = face.normalized()
	var centre: Vector3 = j.global_position + face * 1.9 + Vector3(0, 1.2, 0)
	var lacet := atan2(-face.x, -face.z)
	_n_appels = 0
	var w = Mecanisme.mur_fragile(labo, centre, Vector3(3.0, 2.6, 0.5), lacet, "t_mur", _rappel)
	_verif(w.is_in_group("cassables") and not w.est_casse(), "mur créé, dans le groupe cassables")
	var ss := m.get_world_3d().direct_space_state
	var rayon := PhysicsRayQueryParameters3D.create(centre - face * 2.5, centre + face * 2.5)
	rayon.exclude = [j.get_rid()]
	_verif(not ss.intersect_ray(rayon).is_empty(), "collision du mur présente")
	j.vigueur = j.vigueur_max
	j.mains.attaquer(false)
	await _attendre(0.9)
	_verif(not w.est_casse() and _n_appels == 0, "coup léger : le mur tient")
	j.vigueur = j.vigueur_max
	j.mains.attaquer(true)
	await _attendre(1.2)
	_verif(w.est_casse() and _n_appels == 1 and _vus("meca:t_mur:casse"), "coup puissant : le mur cède, rappel unique, événement meca:t_mur:casse")
	_verif(not w.is_in_group("cassables"), "retiré du groupe cassables")
	await _attendre(0.2)
	_verif(ss.intersect_ray(rayon).is_empty(), "collision retirée : passage libre")
	w.queue_free()
	await _attendre(0.2)
	_n_appels = 0
	var w2 = Mecanisme.mur_fragile(labo, centre, Vector3(3.0, 2.6, 0.5), lacet, "t_mur", _rappel)
	_verif(w2.est_casse() and _n_appels == 1 and _restaure_vu and not w2._mesh.visible, "restauration : mur déjà cassé (aucun volume), rappel en mode restauration")
	w2.queue_free()

# ------------------------------------------------------------------ dalle à fléchettes
func _dalle(base: Vector3) -> void:
	print("-- dalle à fléchettes")
	var j: CharacterBody3D = m.joueur
	j.vie = j.vie_max
	j.mort = false
	var pd: Vector3 = base + Vector3(12, 0, 12)
	j.global_position = pd + Vector3(0, 0.1, 0)
	await _attendre(0.6)
	var sol := j.global_position
	j.global_position = sol + Vector3(0, 0.1, 3.0)
	await _attendre(0.3)
	var p = Piege.dalle_flechettes(labo, sol, sol + Vector3(7, 1.0, 0), Vector3(-1, 0, 0), "t_dalle")
	await _attendre(0.2)
	_verif(p.etat == 0, "dalle armée au départ")
	# évitement : on marche sur la dalle puis on quitte la ligne de tir
	var vie0: float = j.vie
	j.global_position = sol + Vector3(0, 0.1, 0)
	await _attendre(0.25)
	_verif(p.etat == 1, "le joueur déclenche la dalle (clic, amorçage)")
	j.global_position = sol + Vector3(0, 0.1, 3.0)
	await _attendre(2.0)
	_verif(p.fleches_tirees == 2 and j.vie >= vie0 - 0.01, "évité : 2 fléchettes tirées, aucun dégât (vie %.1f)" % j.vie)
	await _attendre(3.5)
	_verif(p.etat == 0, "dalle réarmée après 3 s (joueur hors de la dalle)")
	# touché : on reste sur la dalle
	j.vie = j.vie_max
	j.global_position = sol + Vector3(0, 0.1, 0)
	await _attendre(2.0)
	var perdu: float = j.vie_max - j.vie
	_verif(perdu >= 10.0 and perdu <= 26.0, "touché : %.1f dégâts (une ou deux fléchettes de 12)" % perdu)
	j.global_position = sol + Vector3(0, 0.1, 3.0)
	await _attendre(4.0)
	# un ennemi sur la dalle ne la déclenche pas (le piège ne regarde que le joueur)
	_verif(p.etat == 0, "réarmée de nouveau")
	var dr = m.creer_draugr("guerrier", labo.to_global(sol + Vector3(0, 0.05, 0)), 0.0, true, {})
	await _attendre(1.0)
	_verif(p.etat == 0, "un draugr posé sur la dalle ne la déclenche pas")
	if dr != null and is_instance_valid(dr):
		dr.queue_free()
	p.queue_free()

# ------------------------------------------------------------------ souffle de givre
func _souffle(base: Vector3) -> void:
	print("-- souffle de givre")
	var j: CharacterBody3D = m.joueur
	j.vie = j.vie_max
	var pd: Vector3 = base + Vector3(-14, 0, 14)
	j.global_position = pd + Vector3(0, 0.1, 0)
	await _attendre(0.6)
	var sol := j.global_position
	var p = Piege.souffle_givre(labo, sol + Vector3(4, 1.0, 0), Vector3(-1, 0, 0), 6.0, 6.0, "t_souffle")
	await _attendre(0.1)
	# rythme : calme -> annonce -> souffle
	var vus := {}
	for t in range(0, 60):
		vus[p.phase_a(t * 0.1)] = true
	_verif(vus.has("calme") and vus.has("annonce") and vus.has("souffle"), "le cycle comprend calme, annonce et souffle")
	_verif(p.dans_zone(sol) and not p.dans_zone(sol + Vector3(0, 0, 3.0)) and not p.dans_zone(sol + Vector3(-5, 0, 0)), "zone : dans l'axe oui, 3 m à côté non, au-delà de la longueur non")
	# calme : aucun dégât dans la zone
	p.temps = 0.0
	await _attendre(1.0)
	_verif(p.phase() == "calme" and j.vie >= j.vie_max - 0.01, "calme : traversée sans dégât")
	# souffle : dégâts par ticks de 5
	p.temps = 6.0 - 6.0 * 0.3 + 0.01
	await _attendre(1.2)
	var perdu: float = j.vie_max - j.vie
	_verif(p.phase() == "souffle" and perdu >= 8.0 and perdu <= 20.0 and p.degats_infliges >= 10.0, "souffle : %.1f dégâts (ticks de 5)" % perdu)
	# évitement : en dehors de la zone pendant le souffle
	j.vie = j.vie_max
	j.global_position = sol + Vector3(0, 0.1, 3.0)
	p.temps = 6.0 - 6.0 * 0.3 + 0.01
	await _attendre(1.2)
	_verif(j.vie >= j.vie_max - 0.01, "contourné : pas de dégât hors de la zone")
	p.queue_free()
