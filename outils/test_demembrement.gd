extends SceneTree
## Test sans fenêtre du DÉMEMBREMENT (Demembrement, étape 1 : draugrs et bandits), dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_demembrement.gd -- --nouvelle
## - choix du membre selon la hauteur et le sens de la lame (tête, bras / avant-bras, jambe / mollet, coupe en deux) ;
## - chaque membre tranché pour de vrai sur un draugr ET un bandit : morceau en corps rigide (maillages copiés), membre replié sur
##   le corps (modificateur DERNIER du squelette), capuchons, jet ; le morceau tombe et reste au-dessus du sol ;
## - option à 0 : rien ; option réduite : jamais de coupe en deux ; flèche / piège (info sans coup d'épée) : rien ;
## - pool : au plus TAILLE_POOL morceaux, libérés après leur durée ; traces de sang plafonnées ; hasard global non consommé.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")

var s: Node3D
var echecs := 0
var _n := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _ennemi(genre: String, pos: Vector3) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "test_demembre_%d" % _n
	d.position = pos
	d.rotation.y = atan2(-pos.x, -pos.z) + PI   # tourné vers l'origine
	s.add_child(d)
	d.vie = 5.0
	d.vie_max = 300.0
	d.combat.profil.chance_blocage = 0.0
	return d

## Coup d'épée mortel (info comme mains._info_coup) à la hauteur relative `rel`, lame de sens `dir`.
func _info(d: Node3D, rel: float, dir: Vector3, attaque := "legere", lateral := 0.0) -> Dictionary:
	var vers: Vector3 = (s.joueur.global_position - d.global_position)
	vers.y = 0.0
	vers = vers.normalized()
	var cote: Vector3 = vers.cross(Vector3.UP)
	return {"type": "tranchant", "point": d.global_position + Vector3(0, 1.8 * rel, 0) + vers * 0.2 + cote * lateral,
		"direction": dir.normalized(), "normale": vers, "attaque": attaque, "instant": 0.1, "charge": 1.0 if attaque == "chargee_max" else 0.0}

func _accroche(sq: Skeleton3D, os: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = os
	sq.add_child(a)
	return a

func _membre_reel(genre: String, membre: String, x: float) -> void:
	Demembrement.membre_force = membre
	Demembrement.chance_forcee = 1.0
	var d := _ennemi(genre, Vector3(x, 0, -2.0))
	for i in 20:
		await physics_frame
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	var os_coupe: String = Demembrement.MEMBRES[membre]["os"] if membre != "tete" else "Head"
	var garde: String = Demembrement.MEMBRES[membre].get("garde", "") if membre != "tete" else ""
	var a_coupe := _accroche(sq, os_coupe if garde == "" else "thigh_l")
	var a_garde := _accroche(sq, garde) if garde != "" else null
	await process_frame
	var ech0 := a_coupe.global_transform.basis.get_scale().x
	var eg0 := a_garde.global_transform.basis.get_scale().x if a_garde != null else 1.0
	var r: String = d.recevoir_coup(50.0, s.joueur.global_position, false, _info(d, 0.6, Vector3(1, -0.4, 0)))
	ok(r == "tue", "%s/%s : coup mortel (%s)" % [genre, membre, r])
	for i in 30:
		await physics_frame   # mort « titubante » : le ragdoll (et la coupe) part 0,38 s après le coup
	if membre == "tete":
		ok(d.modele.has_meta("decapite") and d.modele.get_meta("tete_coupee", null) != null, "%s/tete : décapité par Decapitation" % genre)
		return
	var rb: RigidBody3D = d.modele.get_meta("morceau_" + membre, null)
	ok(rb != null and rb.visible and not rb.freeze, "%s/%s : morceau en corps rigide" % [genre, membre])
	ok((Demembrement.coupes_de(d.modele) as Array).has(membre), "%s/%s : membre noté coupé" % [genre, membre])
	var mt := sq.get_node_or_null("MembreTranche")
	var modifs := sq.get_children().filter(func(n: Node) -> bool: return n is SkeletonModifier3D)
	ok(mt != null and modifs.back() == mt, "%s/%s : modificateur MembreTranche en dernier (%s)" % [genre, membre, ", ".join(modifs.map(func(n: Node) -> String: return String(n.name)))])
	var visibles := 0
	if rb:
		for mi: MeshInstance3D in rb.find_children("Maille*", "MeshInstance3D", true, false):
			if mi.visible and mi.mesh != null and mi.skin != null:
				visibles += 1
	ok(visibles >= 2, "%s/%s : %d maillages copiés sur le morceau" % [genre, membre, visibles])
	var capuchons := 0
	for c in sq.find_children("*Capuchon*", "MeshInstance3D", true, false):
		capuchons += 1
	ok(capuchons >= 1 and rb != null and rb.find_children("*Capuchon*", "MeshInstance3D", true, false).size() >= 1, "%s/%s : capuchons de moignon (corps %d, morceau)" % [genre, membre, capuchons])
	var jets := Demembrement.Jets.obtenir(d)
	ok(jets != null and jets.actifs() >= 1, "%s/%s : jet du moignon actif" % [genre, membre])
	for i in 60:
		await physics_frame
	var ech := a_coupe.global_transform.basis.get_scale().x
	ok(ech < 0.05 * ech0, "%s/%s : membre replié sur le corps (échelle %.4f, avant %.3f)" % [genre, membre, ech, ech0])
	if a_garde != null:
		var eg := a_garde.global_transform.basis.get_scale().x
		ok(absf(eg - eg0) < 0.03 * eg0, "%s/moitie : le haut du corps garde sa taille (échelle colonne %.3f, avant %.3f)" % [genre, eg, eg0])
	if rb:
		ok(rb.global_position.y > -0.15, "%s/%s : le morceau reste au-dessus du sol (y %.2f)" % [genre, membre, rb.global_position.y])
		ok(rb.global_position.distance_to(d.global_position) < 6.0, "%s/%s : le morceau tombe près du corps (%.2f m)" % [genre, membre, rb.global_position.distance_to(d.global_position)])

func _lancer() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mannequin.position = Vector3(30, 0, 30)
	s.placer_joueur(Vector3.ZERO, 0.0)
	Sang.niveau_force = 2

	# --- 1. choix du membre selon le coup (sans tuer : membre_du_coup)
	var d0 := _ennemi("guerrier", Vector3(0, 0, -2.0))
	for i in 15:
		await physics_frame
	var c: CombatEnnemi = d0.combat
	var h := c.hauteur
	var m := func(rel: float, dir: Vector3, fort: bool, lat := 0.0, niv := 2) -> String:
		return Demembrement.membre_du_coup(d0, d0.modele, h, _info(d0, rel, dir, "legere", lat), fort, niv)
	ok(m.call(0.84, Vector3(1, 0, 0), false) == "tete", "horizontal haut (cou) → tête (%s)" % m.call(0.84, Vector3(1, 0, 0), false))
	ok(String(m.call(0.3, Vector3(1, -0.2, 0), false)).begins_with("jambe_"), "bas → jambe (%s)" % m.call(0.3, Vector3(1, -0.2, 0), false))
	ok(String(m.call(0.12, Vector3(1, 0, 0), false)).begins_with("mollet_"), "très bas → mollet (%s)" % m.call(0.12, Vector3(1, 0, 0), false))
	var diag: String = m.call(0.62, Vector3(1, -0.8, 0), false, 0.22)
	ok(diag.begins_with("bras_") or diag.begins_with("avantbras_"), "diagonale au buste → bras (%s)" % diag)
	ok(m.call(0.55, Vector3(1, -0.1, 0), true) == "moitie", "coup puissant horizontal au buste → coupe en deux (%s)" % m.call(0.55, Vector3(1, -0.1, 0), true))
	ok(m.call(0.55, Vector3(1, -0.1, 0), true, 0.0, 1) != "moitie", "niveau réduit : pas de coupe en deux (%s)" % m.call(0.55, Vector3(1, -0.1, 0), true, 0.0, 1))
	var dl: String = m.call(0.62, Vector3(1, -0.8, 0), false, 0.25)
	var dr: String = m.call(0.62, Vector3(1, -0.8, 0), false, -0.25)
	ok(dl.right(1) != dr.right(1), "le côté suit le point d'impact (%s / %s)" % [dl, dr])
	# règles : option, flèche, fréquence, hasard global intact
	Demembrement.chance_forcee = 1.0
	var r_epee := {"info": _info(d0, 0.6, Vector3(1, -0.5, 0))}
	Sang.niveau_force = 0
	ok(Demembrement.choisir(c, r_epee, "legere") == "", "option à 0 : aucun démembrement")
	Sang.niveau_force = 2
	ok(Demembrement.choisir(c, r_epee, "legere") != "", "option complète : démembrement possible")
	ok(Demembrement.choisir(c, {"info": {"type": "tranchant", "attaque": "legere"}}, "legere") == "", "flèche / piège (sans coup d'épée) : rien")
	var r_sort := r_epee.duplicate(true)
	r_sort["info"]["ecole"] = "destruction"
	ok(Demembrement.choisir(c, r_sort, "legere") == "", "sort : rien (étape 2)")
	Demembrement.chance_forcee = -1.0
	var n_leger := 0
	var n_fort := 0
	for k in 400:
		if Demembrement.choisir(c, r_epee, "legere") != "":
			n_leger += 1
		if Demembrement.choisir(c, r_epee, "puissant") != "":
			n_fort += 1
	ok(n_leger > 100 and n_leger < 180, "coup normal : ~35 %% de démembrements (%d / 400)" % n_leger)
	ok(n_fort == 400, "coup puissant : toujours (%d / 400)" % n_fort)
	seed(4242)
	var a1 := randf()
	seed(4242)
	for k in 20:
		Demembrement.choisir(c, r_epee, "legere")
	ok(is_equal_approx(randf(), a1), "le hasard global (salles, butin) n'est pas consommé")
	d0.queue_free()

	# --- 2. chaque membre, pour de vrai, sur un draugr et un bandit
	Demembrement.duree = 30.0
	var x := -6.0
	for genre in ["guerrier", "bandit"]:
		for membre in ["tete", "bras_l", "avantbras_r", "jambe_r", "mollet_l", "moitie"]:
			await _membre_reel(genre, membre, x)
			x += 1.2
			if Demembrement.morceaux_actifs() >= Demembrement.TAILLE_POOL - 1:
				pass
	ok(Demembrement.morceaux_actifs() <= Demembrement.TAILLE_POOL, "pool : au plus %d morceaux (%d)" % [Demembrement.TAILLE_POOL, Demembrement.morceaux_actifs()])
	ok(Sang.nombre_traces(s) <= Sang.MAX_TRACES, "traces de sang plafonnées (%d ≤ %d)" % [Sang.nombre_traces(s), Sang.MAX_TRACES])

	# --- 3. fin de vie des morceaux
	Demembrement.duree = 0.5
	Demembrement.membre_force = "bras_r"
	var d3 := _ennemi("bandit", Vector3(0, 0, -3.0))
	for i in 10:
		await physics_frame
	d3.recevoir_coup(50.0, s.joueur.global_position, false, _info(d3, 0.6, Vector3(1, -0.6, 0)))
	for i in 30:
		await physics_frame
	var rb3: RigidBody3D = d3.modele.get_meta("morceau_bras_r", null)
	ok(rb3 != null and rb3.visible, "morceau court : apparu")
	for i in 120:
		await physics_frame
	ok(rb3 == null or not rb3.visible, "morceau libéré après sa durée (pool rendu)")
	Demembrement.duree = Demembrement.DUREE
	Demembrement.membre_force = ""
	Demembrement.chance_forcee = -1.0
	Sang.niveau_force = -1
	print("TEST DEMEMBREMENT : ", "OK" if echecs == 0 else "ÉCHEC", "  (ECHECS : %d)" % echecs)
	quit(1 if echecs > 0 else 0)
