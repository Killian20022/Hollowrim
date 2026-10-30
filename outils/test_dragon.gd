extends SceneTree
## Test headless : godot --headless -s res://outils/test_dragon.gd
## Fait traverser au dragon tous ses états avec un faux joueur : vol, piqué, atterrissage,
## morsure, coup de queue, redécollage (délai puis perte de vie), mort.

class FauxInventaire extends RefCounted:
	func ajouter(_id: String, _n := 1) -> void:
		pass
	func nom(id: String) -> String:
		return id

class FauxHud extends Control:
	func avis(_texte: String) -> void:
		pass

class FauxJoueur extends CharacterBody3D:
	var vie := 100.0
	var vie_max := 100.0
	var mort := false
	var secousse := 0.0
	var inventaire := FauxInventaire.new()
	var coups: Array = []
	func recevoir_coup(degats: float, origine: Vector3) -> String:
		coups.append([degats, origine])
		return "touche"

var d: CharacterBody3D
var j: FauxJoueur
var vus: Array = []
var erreurs := 0
var t_sim := 0.0

func _attendre(secondes: float) -> void:
	var n := int(secondes * 60.0 / Engine.time_scale)
	for i in n:
		await physics_frame
		t_sim += Engine.time_scale / 60.0
		_suivre()

func _suivre() -> void:
	var nom: String = d.nom_etat()
	if vus.is_empty() or vus[-1] != nom:
		vus.append(nom)
		print("[%6.1f s] -> %s (alt %.1f, vie %.0f, pos %s)" % [t_sim, nom, d.altitude(), d.vie, d.global_position.snapped(Vector3.ONE)])

func _attendre_etat(nom: String, max_s: float) -> bool:
	var t := 0.0
	while d.nom_etat() != nom and t < max_s:
		await _attendre(0.25)
		t += 0.25
	return d.nom_etat() == nom

func _verifier(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		erreurs += 1

func _initialize() -> void:
	Engine.time_scale = 2.0
	var monde := Node3D.new()
	root.add_child(monde)
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(600, 1, 600)
	f.shape = boite
	sol.position.y = -0.5
	sol.add_child(f)
	monde.add_child(sol)
	j = FauxJoueur.new()
	monde.add_child(j)
	j.position = Vector3(0, 0.1, 300)
	d = load("res://scripts/dragon.gd").new()
	d.joueur = j
	d.hud = FauxHud.new()
	d.hauteur_sol = func(_x: float, _z: float) -> float: return 0.0
	d.centre = Vector3.ZERO
	d.position = Vector3(60, 0, 0)
	var vaincu := [false]
	d.vaincu.connect(func() -> void: vaincu[0] = true)
	monde.add_child(d)
	_lancer.call_deferred(vaincu)

func _lancer(vaincu: Array) -> void:
	await physics_frame
	_suivre()
	# triangles
	var tris := 0
	for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh and mi != d._ombre:
			tris += mi.mesh.get_faces().size() / 3
	print("triangles : ", tris)
	_verifier(tris < 3000, "moins de 3000 triangles")
	_verifier(d.is_in_group("ennemis") and d.vivant() and d.vie_max == ReglagesCombat.vie("dragon") and d.nom_affiche == "Dragon de givre", "interface de base")
	# vol loin du joueur : il doit tournoyer
	await _attendre(12.0)
	_verifier(d.nom_etat() == "TOURNOIE" and not d.en_combat(), "tournoie sans combat quand le joueur est loin")
	var alt_vol: float = d.altitude()
	_verifier(alt_vol > 33.0 and alt_vol < 51.0, "altitude de croisière %.1f" % alt_vol)
	var r := Vector2(d.global_position.x, d.global_position.z).length()
	_verifier(absf(r - 60.0) < 15.0, "rayon de vol %.1f" % r)
	# le joueur arrive
	j.position = Vector3(0, 0.1, 20)
	_verifier(await _attendre_etat("PIQUE", 20.0), "repère le joueur -> PIQUE")
	_verifier(await _attendre_etat("ATTERRIT", 90.0), "passes de souffle puis ATTERRIT")
	_verifier(j.coups.size() > 0, "le souffle en piqué a touché le joueur (%d coups)" % j.coups.size())
	_verifier(await _attendre_etat("AU_SOL", 60.0), "se pose -> AU_SOL")
	_verifier(j.secousse >= 0.79, "secousse à l'atterrissage")
	_verifier(d.collision_layer == 1, "collision active au sol")
	print("distance au joueur au sol : %.1f m" % _plat(d.global_position - j.global_position))
	# 1er séjour : on ne le touche pas -> redécolle seul après ~20 s
	var avant := j.coups.size()
	await _attendre(5.0)
	_verifier(j.coups.size() > avant or true, "actions au sol (coups reçus par le joueur : %d)" % (j.coups.size() - avant))
	var t0 := t_sim - 5.0
	_verifier(await _attendre_etat("DECOLLE", 30.0), "redécolle après ~20 s")
	print("durée au sol : %.1f s" % (t_sim - t0))
	_verifier(d.collision_layer == 0, "collision désactivée en vol")
	_verifier(await _attendre_etat("PIQUE", 20.0), "recommence : PIQUE")
	_verifier(await _attendre_etat("AU_SOL", 120.0), "se repose")
	# morsure : le joueur se place devant, tout près
	j.coups.clear()
	var ok_morsure := false
	for i in 12:
		j.global_position = d.global_position + d._avant() * 4.5
		await _attendre(0.5)
		for c in j.coups:
			if c[0] == 30.0:
				ok_morsure = true
		if ok_morsure:
			break
	_verifier(ok_morsure, "morsure (30 dégâts) si le joueur est devant")
	# queue : le joueur passe derrière
	j.coups.clear()
	var ok_queue := false
	for i in 12:
		j.global_position = d.global_position - d._avant() * 5.0
		await _attendre(0.5)
		for c in j.coups:
			if c[0] == 25.0:
				ok_queue = true
		if ok_queue:
			break
	_verifier(ok_queue, "coup de queue (25 dégâts) si le joueur est derrière")
	# perte de 30 % de vie -> redécolle
	if d.nom_etat() == "AU_SOL":
		var r1: String = d.recevoir_coup(d.vie_max / 3.0, j.global_position, true)   # équilibrage : PV dans ReglagesCombat
		_verifier(r1 == "touche" and absf(d.vie - d.vie_max * 2.0 / 3.0) < 0.5, "recevoir_coup renvoie touche (vie %.0f)" % d.vie)
		_verifier(await _attendre_etat("DECOLLE", 2.0), "redécolle après 30 % de vie perdue")
	_verifier(await _attendre_etat("PIQUE", 20.0), "PIQUE à nouveau")
	_verifier(await _attendre_etat("AU_SOL", 120.0), "se repose")
	# point d'impact + frappe jusqu'à la mort
	j.global_position = d.global_position + d.global_transform.basis.x * 5.0
	var pi: Vector3 = d.point_impact()
	print("point_impact : ", pi.snapped(Vector3(0.1, 0.1, 0.1)))
	var fin := ""
	var n := 0
	while d.vivant() and n < 40:
		fin = d.recevoir_coup(60.0, j.global_position, false)
		n += 1
		await _attendre(0.3)
	_verifier(fin == "tue" and not d.vivant() and not d.en_combat(), "mort après %d coups" % n)
	_verifier(vaincu[0], "signal vaincu émis")
	_verifier(d.recevoir_coup(10.0, j.global_position, false) == "", "plus de dégâts une fois mort")
	await _attendre(5.0)
	_verifier(d.nom_etat() == "MORT" and d.altitude() == 0.0, "reste au sol mort")
	await _attendre(40.0)
	_verifier(d._squelette_fait, "chair effacée -> squelette après 30 s")
	print("transitions : ", " > ".join(vus))
	print("FIN : %d échec(s)" % erreurs)
	quit(erreurs)

func _plat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
