extends SceneTree
## Lot sommeil : lits, PNJ qui se couchent et se lèvent, joueur qui dort / attend.
##   - des lits sont posés sur les marqueurs « emplacement_lit » (simple, double, propriétaire, foyer), avec collision ;
##   - la nuit, Sigrún rentre à pied, ouvre sa porte, va à SON lit, s'assoit, s'allonge et dort (couchée sur la paillasse, dans le cadre,
##     sans collision propre) ; le matin elle se redresse, se lève, ressort et rejoint son poste ;
##   - heure sautée : les civils qui ont un lit y sont couchés, les autres dorment cachés comme avant ;
##   - réveillée (on lui parle) : elle se lève, puis se recouche ;
##   - le joueur dort 8 h dans un lit libre : heure + 8 h, vie / magie / vigueur pleines, bonus « reposé » ; attendre 3 h (fenêtre, T) ;
##   - refus en combat et si un ennemi rôde ; intrusion vue par un témoin -> nœud « crime » ; sauvegarde `sommeil`.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_sommeil.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var vie: Vie
var sm: Sommeil
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame

## Avance l'horloge par petits pas (pas de saut : les PNJ marchent) jusqu'à `h`.
func _avancer_vers(h: float, pas := 0.1) -> void:
	var c: Node = m.cycle
	while fposmod(h - float(c.heure), 24.0) > 0.001 and fposmod(h - float(c.heure), 24.0) < 23.0:
		c.heure = fposmod(float(c.heure) + minf(pas, fposmod(h - float(c.heure), 24.0)), 24.0)
		vie.tick()
		await _attendre(0.25)

## Couché dans son lit : modèle allongé (tête vers le chevet, face au plafond), dans le cadre, au-dessus de la paillasse.
func _couche_dans(n: Node3D, l: Lit) -> String:
	var mo: Node3D = n.modele
	var xf := l.global_transform.affine_inverse() * mo.global_transform
	var haut := xf.basis.y.normalized()
	var face := xf.basis.z.normalized()
	var tete := xf * Vector3(0, 1.55, 0)
	var pied := xf.origin
	var r := ""
	if haut.dot(Vector3(0, 0, 1)) < 0.9:
		r += " tête pas vers le chevet (%s)" % str(haut)
	if face.dot(Vector3.UP) < 0.9:
		r += " face pas au plafond"
	for p: Vector3 in [tete, pied]:
		if absf(p.x) > l.largeur * 0.5 or absf(p.z) > l.longueur * 0.5:
			r += " hors du cadre %s" % str(p)
		if p.y < Lit.H_PAILLASSE:
			r += " sous la paillasse %.2f" % p.y
	return r

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	await _attendre(2.5)        # Sommeil balaie les marqueurs toutes les secondes
	vie = m.get_node_or_null("Vie")
	sm = m.get_node_or_null("Sommeil")
	_verif(vie != null and sm != null and m.sommeil == sm, "nœuds Vie et Sommeil branchés dans le monde")
	if vie == null or sm == null:
		_fin()
		return
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var j: CharacterBody3D = m.joueur

	# --- lits posés sur les marqueurs
	var marqueurs := root.get_tree().get_nodes_in_group("emplacement_lit")
	_verif(marqueurs.size() >= 4 and sm.lits.size() == marqueurs.size(), "un lit par marqueur « emplacement_lit » (%d marqueurs, %d lits)" % [marqueurs.size(), sm.lits.size()])
	var simple := Lit.creer(1, "volva")
	var dbl := Lit.creer(2, "a,b")
	_verif(simple.places() == 1 and dbl.places() == 2 and dbl.a_pour_proprietaire("b") and simple.get_child_count() >= 4, "Lit.creer : simple (1 place), double (2 places, deux propriétaires), maillages et collision")
	simple.free()
	dbl.free()
	var lit_volva: Lit = null
	var lit_libre: Lit = null
	for l: Lit in sm.lits:
		if l.a_pour_proprietaire("volva"):
			lit_volva = l
		elif l.libre() and l.foyer == "chasseurs":
			lit_libre = l
	_verif(lit_volva != null and lit_volva.foyer == "sigrun", "le lit de Sigrún est chez elle (foyer %s)" % (lit_volva.foyer if lit_volva else "?"))
	_verif(lit_libre != null, "un lit libre chez les chasseurs")
	# lit double posé par un marqueur ajouté après coup (comme ceux d'un autre lot) : deux places côte à côte, un foyer
	var mk := Marker3D.new()
	mk.add_to_group("emplacement_lit")
	mk.set_meta("largeur", 2)
	mk.set_meta("foyer", "essai")
	m.add_child(mk)
	mk.global_position = Vector3(20.0, m.hauteur(20.0, 60.0), 60.0)
	await _attendre(1.3)
	var dbl_l: Lit = mk.get_node_or_null("Lit")
	var a1: Array = sm.lit_pour("essai_1", "essai")
	var a2: Array = sm.lit_pour("essai_2", "essai")
	var a3: Array = sm.lit_pour("essai_3", "essai")
	_verif(dbl_l != null and dbl_l.double() and a1 == [dbl_l, 0] and a2 == [dbl_l, 1] and a3.is_empty(), "marqueur ajouté : lit double posé, deux places attribuées, la troisième personne n'en a pas")
	_verif(dbl_l != null and dbl_l.pose_couchee(0).origin.distance_to(dbl_l.pose_couchee(1).origin) > 0.6, "les deux places couchées sont côte à côte (%.2f m)" % (dbl_l.pose_couchee(0).origin.distance_to(dbl_l.pose_couchee(1).origin) if dbl_l else 0.0))
	if lit_volva == null or lit_libre == null:
		_fin()
		return

	# --- la nuit, Sigrún va à son lit (à pied, porte ouverte puis refermée) et s'y couche
	var c: Dictionary = vie.civil("volva")
	var n: Node3D = c["n"]
	var ip: Interieur = m.village.interieur("sigrun")
	var porte: Vector3 = vie._portes["sigrun"]["pos"]
	j.global_position = porte + Vector3(0, 0.3, 0) + (porte - ip.global_position).normalized() * 3.0     # tout près : LOD complet
	j.velocity = Vector3.ZERO
	m.cycle.heure = 20.8
	vie.tick()
	await _attendre(0.5)
	var rentree: float = float(c["f"].get("rentree", 21.5)) + EmploiDuTemps.decalage("volva")
	# elle est loin (place) : on la pose devant sa maison pour un trajet court, puis l'heure passe pas à pas
	n.installer(porte + Vector3(1.5, 0, 1.5), false)
	await _attendre(0.3)
	var porte_ouverte := false
	await _avancer_vers(rentree + 0.05, 0.05)
	var vu_rentre := false
	var vu_assis := false
	var vu_allonge := false
	for i in 60 * 45:
		await physics_frame
		vu_rentre = vu_rentre or n.etat == 4
		vu_assis = vu_assis or n.seq in ["assoir", "assis"]
		vu_allonge = vu_allonge or n.seq == "allonger"
		porte_ouverte = porte_ouverte or ip.ouverte
		if n.seq == "dort" and not ip.ouverte:
			break
	_verif(vu_rentre and porte_ouverte, "Sigrún rentre à pied et ouvre sa porte (RENTRE vu : %s, porte ouverte : %s)" % [vu_rentre, porte_ouverte])
	_verif(vu_assis and vu_allonge and n.seq == "dort", "elle s'assoit au bord, s'allonge, dort (assise : %s, allongée : %s, état : « %s »)" % [vu_assis, vu_allonge, n.seq])
	_verif(not ip.ouverte, "la porte est refermée derrière elle")
	_verif(n.est_endormi() and n.visible and n._forme.disabled and lit_volva.occupants[0] == n, "couchée : endormie, visible, sans collision propre, place 0 de son lit")
	var defaut := _couche_dans(n, lit_volva)
	_verif(defaut == "", "allongée sur la paillasse, dans le cadre, tête au chevet%s" % defaut)
	var anim: AnimationPlayer = n.anim
	_verif(anim.current_animation == n.CLIP_COUCHE if anim != null else false, "clip couché (respiration) : %s" % (anim.current_animation if anim else "?"))

	# --- réveillée : on lui parle, elle se lève, puis se recouche
	var lignes: Array = n.parler()
	_verif(lignes.size() >= 1 and n.seq == "redresser", "on lui parle : elle se redresse (« %s »)" % (lignes[0] if lignes.size() > 0 else ""))
	await _attendre(4.0)
	_verif(n.seq == "" and not n.est_endormi() and not n._forme.disabled, "debout à côté du lit, solide (état %d)" % n.etat)
	n.fin_conversation()
	var recouchee := false
	for i in 60 * 25:
		await physics_frame
		if n.seq == "dort":
			recouchee = true
			break
	_verif(recouchee, "la conversation finie, elle se recouche (encore la nuit)")

	# --- le matin : elle se lève et ressort
	var reveil: float = float(c["f"].get("reveil", 6.5)) + EmploiDuTemps.decalage("volva")
	m.cycle.heure = reveil - 0.6
	vie._heure_prec = m.cycle.heure
	vie.tick()
	await _attendre(0.3)
	_verif(n.seq == "dort", "%.1f h : elle dort encore" % m.cycle.heure)
	await _avancer_vers(reveil + 0.05, 0.05)
	var vu_lever := false
	var dehors := false
	for i in 60 * 45:
		await physics_frame
		vu_lever = vu_lever or n.seq in ["redresser", "lever"]
		if n.seq == "" and not n.est_endormi() and not ip.dedans(ip.to_local(n.global_position), 0.2):
			dehors = true
			if n.etat == 0:
				break
	_verif(vu_lever, "au réveil, elle se redresse puis se lève (animations)")
	_verif(dehors and n.visible and not n._forme.disabled, "elle ressort de sa maison, solide (état %d, à %.1f m de son poste)" % [n.etat, n.global_position.distance_to(n.points[0])])
	_verif(lit_volva.occupants[0] == null, "son lit est libéré")

	# --- heure sautée (chargement, sommeil) : ceux qui ont un lit y sont couchés, les autres dorment cachés
	m.cycle.heure = 3.0
	vie._heure_prec = -1.0
	vie.tick()
	await _attendre(0.5)
	var couches := 0
	var caches := 0
	var mauvais := 0
	for cc: Dictionary in vie.civils:
		var nn: Node3D = cc["n"]
		if cc["id"] == "garde":
			continue
		if nn.au_lit():
			couches += 1
			if _couche_dans(nn, nn.lit) != "":
				mauvais += 1
				print("   mal couché : %s%s" % [cc["id"], _couche_dans(nn, nn.lit)])
		elif nn.est_endormi() and not nn.visible:
			caches += 1
	_verif(couches >= 4 and couches + caches == 15, "3 h : %d civils couchés dans un lit, %d dorment cachés (15 en tout)" % [couches, caches])
	_verif(mauvais == 0, "tous les couchés sont dans leur cadre (%d mal posés)" % mauvais)
	_verif(lit_libre.occupants[0] != null and String(lit_libre.occupants[0].donnees.get("type", "")).begins_with("chass"), "le lit libre des chasseurs accueille un chasseur du foyer")

	# --- le joueur dort 8 h dans un lit libre ; heure, vie, magie justes
	m.cycle.heure = 22.0
	vie._heure_prec = -1.0
	vie.tick()
	var lit_j: Lit = null
	sm._reserve.clear()
	sm._attrib.clear()
	if dbl_l != null and dbl_l.place_libre() >= 0:
		lit_j = dbl_l          # lit libre posé plus haut (personne de ce foyer : il reste libre la nuit)
	for l: Lit in ([] if lit_j != null else sm.lits):
		if l.libre() and l.place_libre() >= 0 and l.foyer == "chasseurs":
			lit_j = l
	if lit_j == null:
		for l: Lit in sm.lits:
			if l.place_libre() >= 0:
				lit_j = l
	j.global_position = lit_j.global_position + Vector3(0, 0.5, 0) + lit_j.global_transform.basis.x * 1.0
	await _attendre(0.5)
	j.vie = 20.0
	j.mana = 5.0
	j.vigueur = 10.0
	_verif(sm.refus(lit_j) == "", "dormir est permis ici (« %s »)" % sm.refus(lit_j))
	var r := sm.executer(8, "dormir", lit_j)
	_verif(r == "" and j.en_dialogue, "dodo : fondu lancé, joueur immobile")
	await _attendre(4.5)
	_verif(absf(m.cycle.heure - 6.0) < 0.02, "8 h de sommeil depuis 22 h : il est %.2f h" % m.cycle.heure)
	_verif(is_equal_approx(j.vie, j.vie_max) and is_equal_approx(j.mana, j.mana_max) and is_equal_approx(j.vigueur, j.vigueur_max), "vie %.0f/%.0f, magie %.0f/%.0f, vigueur %.0f/%.0f : refaites" % [j.vie, j.vie_max, j.mana, j.mana_max, j.vigueur, j.vigueur_max])
	_verif(sm.repos == "repose" and Progression.bonus_repos > 0.0 and not j.en_dialogue, "bonus « reposé » (+%d %% d'expérience), joueur rendu à lui-même" % int(Progression.bonus_repos * 100.0))
	_verif(lit_j.place_libre() >= 0, "le lit est libéré au réveil")

	# --- attendre 3 h (fenêtre « Attendre » ouverte comme par la touche T)
	j.vie = 50.0
	var h_av: float = m.cycle.heure
	sm.demander("attendre")
	_verif(sm.fenetre.ouvert and paused, "Attendre : la fenêtre s'ouvre, le jeu est en pause")
	sm.fenetre.regler(3)
	sm.fenetre.valider()
	_verif(not paused, "valider : la pause est levée")
	await _attendre(4.5)
	_verif(absf(fposmod(m.cycle.heure - h_av, 24.0) - 3.0) < 0.02, "attendre 3 h : de %.2f h à %.2f h" % [h_av, m.cycle.heure])
	var attendu: float = 50.0 + (j.vie_max - 50.0) * 3.0 / 8.0
	_verif(absf(float(sm.dernier["vie"]) - attendu) < 0.5, "attendre régénère au prorata (vie %.1f au réveil, attendu %.1f)" % [float(sm.dernier["vie"]), attendu])

	# --- refus : en combat, ennemi qui rôde
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nvar combat := true\nfunc en_combat() -> bool:\n\treturn combat\nfunc vivant() -> bool:\n\treturn true\n"
	sc.reload()
	var loup := Node3D.new()
	loup.set_script(sc)
	loup.add_to_group("ennemis")
	m.add_child(loup)
	loup.global_position = j.global_position + Vector3(8, 0, 0)
	var h0: float = m.cycle.heure
	var rc := sm.executer(8, "dormir", lit_j)
	_verif(rc.contains("combat") and m.cycle.heure == h0 and not sm._en_cours, "en combat : refusé (« %s »), l'heure ne bouge pas" % rc)
	loup.combat = false
	var rr := sm.refus(lit_j)
	_verif(rr.contains("rôdent"), "un hostile à 8 m : refusé (« %s »)" % rr)
	_verif(sm.demander("attendre") != "" and not sm.fenetre.ouvert, "attendre aussi est refusé, sans fenêtre")
	loup.queue_free()
	await _attendre(0.2)
	_verif(sm.refus(lit_j) == "", "ennemi parti : permis")

	# --- intrusion : dormir dans le lit de Grima, une fermière éveillée dans la maison -> le nœud « crime » est prévenu
	var sc2 := GDScript.new()
	sc2.source_code = "extends Node\nvar vus: Array = []\nfunc signaler_intrusion(lit, proprietaire) -> void:\n\tvus.append([lit, proprietaire])\n"
	sc2.reload()
	var crime := Node.new()
	crime.set_script(sc2)
	crime.add_to_group("crime")
	m.add_child(crime)
	m.cycle.heure = 12.0
	vie._heure_prec = -1.0
	vie.tick()
	await _attendre(0.3)
	var lit_grima: Lit = null
	for l: Lit in sm.lits:
		if l.a_pour_proprietaire("ancienne"):
			lit_grima = l
	var ipg: Interieur = m.village.interieur("grima")
	var temoin: Node3D = vie.civil("hab_paysanne_1")["n"]
	sm.passer_temps(1, "dormir", lit_grima)
	_verif(crime.vus.is_empty(), "personne dans la maison : pas de témoin, rien n'est signalé")
	temoin.installer(ipg.to_global(Vector3(1.0, ipg.sol_y, 0.6)), false)
	await _attendre(0.2)
	sm.passer_temps(1, "dormir", lit_grima)
	_verif(crime.vus.size() == 1 and crime.vus[0][1] == "ancienne", "une fermière éveillée la voit : intrusion signalée (propriétaire « %s »)" % (crime.vus[0][1] if crime.vus.size() > 0 else "?"))
	sm.passer_temps(1, "dormir", lit_j)
	_verif(crime.vus.size() == 1, "dans un lit libre : rien n'est signalé")
	crime.queue_free()

	# --- sauvegarde
	sm._debut_repos("bien_repose")
	sm.repos_reste = 5.5
	var d := JSON.parse_string(JSON.stringify(sm.exporter())) as Dictionary
	sm._fin_repos()
	sm.restaurer(d)
	_verif(sm.repos == "bien_repose" and absf(sm.repos_reste - 5.5) < 0.01 and absf(Progression.bonus_repos - 0.15) < 0.001, "sauvegarde : bonus « bien reposé » et heures restantes relus")
	sm.restaurer({})
	_verif(sm.repos == "" and Progression.bonus_repos == 0.0, "ancienne sauvegarde (sans clé sommeil) : aucun bonus, pas d'erreur")
	m.sauvegarder()
	var fich: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	var sv: Variant = JSON.parse_string(FileAccess.get_file_as_string(fich))
	_verif(sv is Dictionary and (sv as Dictionary).get("sommeil") is Dictionary and (sv as Dictionary).get("vie") is Dictionary, "le fichier de sauvegarde contient « sommeil » et « vie »")
	_fin()

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	if m != null:
		m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
