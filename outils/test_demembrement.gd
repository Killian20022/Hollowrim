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
const TROLL := preload("res://scripts/troll_givre_ia.gd")

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

func _troll(pos: Vector3) -> CharacterBody3D:
	_n += 1
	var t := CharacterBody3D.new()
	t.set_script(TROLL)
	t.joueur = s.joueur
	t.hud = s.hud
	t.ident = "test_troll_%d" % _n
	t.position = pos
	s.add_child(t)
	return t

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

## Étape 2 : boyaux de la coupe en deux, squelette (membre d'os avant l'éclatement), troll (tête / bras seulement), sorts.
func _etape2() -> void:
	Demembrement.chance_forcee = 1.0
	# boyaux : coupe en deux d'un draugr
	Demembrement.membre_force = "moitie"
	var d := _ennemi("guerrier", Vector3(-4, 0, -5.0))
	await _attendre(15)
	d.recevoir_coup(50.0, s.joueur.global_position, true, _info(d, 0.5, Vector3(1, -0.1, 0), "chargee_max"))
	await _attendre(40)
	var pend: Array = d.modele.find_children("BoyauxPendants*", "MeshInstance3D", true, false)
	ok(pend.size() == 1 and (pend[0] as MeshInstance3D).mesh != null, "coupe en deux : boyaux pendants au moignon")
	if pend.size() == 1:
		var axe := (pend[0] as Node3D).global_basis.y.normalized()
		ok(axe.y > 0.8, "boyaux pendus vers le bas (axe %.2f)" % axe.y)
	var tas: Array = Sang.gestion(s).find_children("BoyauxTas*", "MeshInstance3D", true, false)
	ok(tas.size() >= 1, "coupe en deux : tas de boyaux au sol (%d)" % tas.size())
	# squelette : un bras d'os saute (morceau, sans sang ni jet), puis les os éclatent comme avant
	Demembrement.membre_force = "bras_r"
	var sq := _ennemi("squelette", Vector3(-2, 0, -5.0))
	await _attendre(15)
	var jets0: int = Demembrement.Jets.obtenir(sq).actifs()
	var l0 := EclatsOs.lances
	sq.recevoir_coup(80.0, s.joueur.global_position, false, _info(sq, 0.65, Vector3(-1, -0.7, 0)))
	await _attendre(35)
	var rb: RigidBody3D = sq.modele.get_meta("morceau_bras_r", null)
	ok(rb != null and rb.visible, "squelette : le bras d'os saute (morceau)")
	ok(Demembrement.Jets.obtenir(sq).actifs() <= jets0, "squelette : pas de jet de sang")
	ok(EclatsOs.lances > l0, "squelette : les os éclatent toujours à la mort (%d lancés)" % (EclatsOs.lances - l0))
	var caps: Array = sq.modele.find_children("*Capuchon*", "MeshInstance3D", true, false)
	ok(caps.size() >= 1 and ((caps[0] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("c_chair") == Demembrement.CHAIRS["os"][0], "squelette : capuchon d'os cassé")
	# troll : bras oui, jambe non (rabattue sur le bras), jamais coupé en deux
	var t := _troll(Vector3(1, 0, -6.0))
	await _attendre(20)
	var ct: CombatEnnemi = t.combat
	Demembrement.membre_force = ""
	var n_jambe := 0
	var n_moitie := 0
	for k in 60:
		var m := Demembrement.choisir(ct, {"info": _info(t, 0.2, Vector3(1, -0.2, 0))}, "puissant")
		if m.begins_with("jambe") or m.begins_with("mollet"):
			n_jambe += 1
		if m == "moitie":
			n_moitie += 1
	ok(n_jambe == 0 and n_moitie == 0, "troll : ni jambe ni coupe en deux (%d, %d)" % [n_jambe, n_moitie])
	Demembrement.membre_force = "bras_l"
	t.vie = 1.0
	t.recevoir_coup(80.0, s.joueur.global_position, false, _info(t, 0.6, Vector3(1, -0.7, 0)))
	await _attendre(40)
	var rbt: RigidBody3D = t.modele.get_meta("morceau_bras_l", null)
	ok(rbt != null and rbt.visible, "troll : bras tranché (morceau)")
	if rbt:
		var cap: CapsuleShape3D = (rbt.get_child(0) as CollisionShape3D).shape
		ok(cap.radius > 0.09, "troll : morceau épais (rayon %.2f m)" % cap.radius)
	# sorts : le feu carbonise ; la glace fait éclater un membre gelé (pas de morceau)
	Demembrement.membre_force = ""
	Demembrement.chance_forcee = 0.0
	var df := _ennemi("bandit", Vector3(3, 0, -5.0))
	await _attendre(15)
	df.vie = 1.0
	df.recevoir_coup(40.0, s.joueur.global_position, false, {"type": "feu", "ecole": "feu", "attaque": "sort", "point": df.global_position + Vector3(0, 1.2, 0.2)})
	await _attendre(150)
	var voiles := 0
	var noir := 0.0
	for mi: MeshInstance3D in df.modele.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay != null and mi.material_overlay.resource_name == "carbonise":
			voiles += 1
			noir = maxf(noir, float(mi.get_instance_shader_parameter("carbonise")))
	ok(df.modele.has_meta("carbonise") and voiles >= 3 and noir > 0.9, "feu : corps carbonisé (%d maillages, %.2f)" % [voiles, noir])
	Demembrement.chance_forcee = 1.0
	Demembrement.membre_force = "jambe_l"
	var dg := _ennemi("guerrier", Vector3(5, 0, -5.0))
	await _attendre(15)
	dg.vie = 1.0
	dg.recevoir_coup(40.0, s.joueur.global_position, false, {"type": "glace", "ecole": "glace", "attaque": "sort", "point": dg.global_position + Vector3(0, 1.2, 0.2)})
	await _attendre(40)
	ok(String(dg.modele.get_meta("mode_jambe_l", "")) == "glace" and dg.modele.get_meta("morceau_jambe_l", null) == null, "glace : la jambe gelée éclate (pas de morceau)")
	var capg: Array = dg.modele.find_children("*Capuchon*", "MeshInstance3D", true, false)
	ok(capg.size() >= 1 and ((capg[0] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("c_chair") == Demembrement.CHAIRS["glace"][0], "glace : moignon de glace")
	# sons du démembrement présents (banque RetourImpact, fichiers importés)
	var manquants := []
	for cat in ["membre_tranche", "giclee", "chute_membre", "os_brise", "glace_eclate", "carbonise", "boyaux"]:
		for nom: String in RetourImpact.BANQUE[cat]:
			if RetourImpact._chemin(nom) == "":
				manquants.append(nom)
	ok(manquants.is_empty(), "sons du démembrement présents (%s)" % ", ".join(manquants))

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
	var m := func(rel: float, dir: Vector3, _fort: bool, lat := 0.0) -> String:
		return Demembrement.membre_du_coup(d0, d0.modele, h, _info(d0, rel, dir, "legere", lat))
	ok(m.call(0.84, Vector3(1, 0, 0), false) == "tete", "horizontal haut (cou) → tête (%s)" % m.call(0.84, Vector3(1, 0, 0), false))
	ok(String(m.call(0.3, Vector3(1, -0.2, 0), false)).begins_with("jambe_"), "bas → jambe (%s)" % m.call(0.3, Vector3(1, -0.2, 0), false))
	ok(String(m.call(0.12, Vector3(1, 0, 0), false)).begins_with("mollet_"), "très bas → mollet (%s)" % m.call(0.12, Vector3(1, 0, 0), false))
	var diag: String = m.call(0.62, Vector3(1, -0.8, 0), false, 0.22)
	ok(diag.begins_with("bras_") or diag.begins_with("avantbras_"), "diagonale au buste → bras (%s)" % diag)
	ok(m.call(0.55, Vector3(1, -0.1, 0), true) != "moitie", "le choix par la hauteur ne coupe jamais en deux (%s)" % m.call(0.55, Vector3(1, -0.1, 0), true))
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
	# coupe en deux : coup puissant seulement, 1 fois sur 3 ; jamais sur un coup normal, lourd, ni en niveau réduit ; finishers : rien
	var n_moitie := 0
	var n_moitie_autre := 0
	var n_moitie_reduit := 0
	for k in 600:
		if Demembrement.choisir(c, r_epee, "puissant") == "moitie":
			n_moitie += 1
		if Demembrement.choisir(c, r_epee, "lourde") == "moitie" or Demembrement.choisir(c, r_epee, "legere") == "moitie":
			n_moitie_autre += 1
	Sang.niveau_force = 1
	for k in 200:
		if Demembrement.choisir(c, r_epee, "puissant") == "moitie":
			n_moitie_reduit += 1
	Sang.niveau_force = 2
	ok(n_moitie > 150 and n_moitie < 250, "coup puissant : ~1 coupe en deux sur 3 (%d / 600)" % n_moitie)
	ok(n_moitie_autre == 0, "coup normal ou lourd : jamais coupé en deux (%d)" % n_moitie_autre)
	ok(n_moitie_reduit == 0, "niveau réduit : pas de coupe en deux (%d)" % n_moitie_reduit)
	var r_fin := r_epee.duplicate(true)
	r_fin["info"]["attaque"] = "finisher"
	r_fin["info"]["mort_finisher"] = "effondre"
	var n_fin := 0
	for k in 50:
		if Demembrement.choisir(c, r_fin, "finisher") != "":
			n_fin += 1
	ok(n_fin == 0, "finishers (épée plantée, dos, pommeau) : corps entier (%d)" % n_fin)
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
	await _etape2()
	Demembrement.membre_force = ""
	Demembrement.chance_forcee = -1.0
	Sang.niveau_force = -1
	print("TEST DEMEMBREMENT : ", "OK" if echecs == 0 else "ÉCHEC", "  (ECHECS : %d)" % echecs)
	quit(1 if echecs > 0 else 0)
