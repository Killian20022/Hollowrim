extends SceneTree
## Test sans fenêtre de l'onglet Carte (branche rpg/carte) : registre Lieux (positions = constantes du monde, découverte,
## cibles de quête), générateur CarteMonde (relief, sapins, bâtiments, couleurs), OngletCarte (contrat OngletMenu, zoom,
## déplacement, centrage, entrées laissées à la coquille, projection du joueur).
##   godot --headless --path . --script res://outils/test_onglet_carte.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, quoi: String) -> void:
	print(("OK     " if ok else "ÉCHEC  ") + quoi)
	if not ok:
		echecs += 1

func _touche(k: Key, physique := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	if physique:
		e.physical_keycode = k
	e.keycode = k
	return e

func _tester() -> void:
	create_timer(420.0, true, false, true).timeout.connect(func() -> void:
		print("ÉCHEC  délai dépassé (420 s)")
		quit(1))
	m = SCENE.instantiate()
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.pret and Time.get_ticks_msec() - t0 < 200000:
		await process_frame
	_verif(m.pret, "monde prêt (%d ms)" % (Time.get_ticks_msec() - t0))

	# --- Lieux : positions recopiées = constantes du monde
	_verif(Lieux.lieu("skarnholt")["pos"] == Vector2(m.VILLAGE.x, m.VILLAGE.z), "Skarnholt = monde.VILLAGE")
	_verif(Lieux.lieu("cercle")["pos"] == Vector2(m.CERCLE.x, m.CERCLE.z), "Cercle = monde.CERCLE")
	_verif(Lieux.lieu("tertre")["pos"] == Vector2(m.TUMULUS.x, m.TUMULUS.z), "Tertre = monde.TUMULUS")
	_verif(Lieux.lieu("grotte")["pos"] == GrotteAcces.SITE, "Grotte = GrotteAcces.SITE")
	var az := deg_to_rad(ArrierePlan.CHATEAU_AZIMUT)
	var ch: Vector2 = Lieux.lieu("chateau")["pos"]
	_verif(ch.distance_to(Vector2(sin(az), cos(az)) * ArrierePlan.CHATEAU_DIST) < 0.5, "Château = ArrierePlan (azimut, distance)")
	var noms_hud := {}
	for ln: Array in m.hud.lieux_nommes:
		noms_hud[ln[2]] = true
	var tous := true
	for l: Dictionary in Lieux.liste():
		if l["decouvrable"] and not noms_hud.has(l["nom"]):
			tous = false
			print("   lieu découvrable absent du HUD : ", l["nom"])
	_verif(tous, "chaque lieu découvrable est annoncé par le HUD sous le même nom")
	var n_avant: int = m.hud.lieux_nommes.size()
	Lieux.declarer_au_hud(m.hud, m)
	_verif(m.hud.lieux_nommes.size() == n_avant, "declarer_au_hud : aucun doublon")
	_verif(Lieux.position("tertre", m) == m.tertre.porte_dehors, "position du tertre = porte réelle")
	# découverte
	m.hud.lieux_vus.clear()
	_verif(not Lieux.decouvert("skarnholt", m.hud) and Lieux.decouvert("feu", m.hud) and Lieux.decouvert("chateau", m.hud), "nouvelle partie : lieux à découvrir cachés, repères connus")
	m.hud.lieux_vus["Skarnholt"] = true
	_verif(Lieux.decouvert("skarnholt", m.hud), "Skarnholt découvert après hud.lieux_vus")
	# déclencheurs
	_verif(Lieux.lieu_du_declencheur("lieu:tertre") == "tertre", "déclencheur lieu:tertre → tertre")
	_verif(Lieux.lieu_du_declencheur("ramasse:fragment_sceau_givre") == "tertre", "préfixe ramasse:fragment_sceau → tertre")
	_verif(Lieux.lieu_du_declencheur("objet:lame_antique>=3") == "cercle", "objet:lame_antique>=3 → cercle")
	_verif(Lieux.lieu_du_declencheur("tue:hrafn") == "grotte", "tue:hrafn → grotte")
	var sans := []
	for q: Dictionary in m.quetes.donnees["quetes"]:
		for e: Dictionary in q["etapes"]:
			var ok := e.has("carte")
			for evt: String in String(e["declencheur"]).split("|"):
				ok = ok or Lieux.lieu_du_declencheur(evt) != ""
			if not ok:
				sans.append(e["declencheur"])
	_verif(sans.is_empty(), "chaque étape de quête a un lieu sur la carte %s" % str(sans))
	# cibles de quêtes
	_verif(Lieux.cibles_quetes(m.quetes, m).is_empty(), "aucune quête : aucune cible")
	m.quetes.signaler("parle:chef")
	m.quetes.signaler("parle:forgeron")
	var cq := Lieux.cibles_quetes(m.quetes, m)
	_verif(cq.size() == 2, "deux quêtes en cours → deux cibles (%d)" % cq.size())
	var par_id := {}
	for c: Dictionary in cq:
		par_id[c["quete"]] = c
	_verif(par_id.has("anneau_givre") and par_id["anneau_givre"]["lieu"] == "tertre", "L'anneau de givre → tertre")
	_verif(par_id.has("lames_brodd") and par_id["lames_brodd"]["lieu"] == "cercle", "Le fer des morts → cercle (lames des draugrs)")
	_verif(cq.filter(func(c: Dictionary) -> bool: return c["suivie"]).size() == 1, "une seule quête suivie (celle du HUD)")

	# --- onglet
	var calque := CanvasLayer.new()
	root.add_child(calque)
	var o := OngletCarte.new()
	_verif(o is OngletMenu and o.id_onglet() == "carte" and o.titre() == "Carte" and not o.aide().is_empty(), "contrat OngletMenu")
	o.joueur = m.joueur
	calque.add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.size = Vector2(640, 360)
	o.visible = true
	var t1 := Time.get_ticks_msec()
	o.ouvrir()
	for i in 4:
		await process_frame
	_verif(o.carte != null and o.carte.pret, "carte construite (%d ms, générateur %d ms)" % [Time.get_ticks_msec() - t1, o.carte.temps_ms if o.carte else -1])
	if o.carte == null:
		_fin()
		return
	print("   sapins %d, bâtiments %d, relief %.1f..%.1f m" % [o.carte.nb_sapins, o.carte.nb_batiments, o.carte.h_min, o.carte.h_max])
	_verif(o.carte.nb_sapins > m.arbres.size() * 0.8, "sapins repris du monde (%d / %d arbres)" % [o.carte.nb_sapins, m.arbres.size()])
	_verif(o.carte.nb_batiments >= 8, "bâtiments repris des emprises du village (%d)" % o.carte.nb_batiments)
	var img: Image = o.carte.carte_couleur.get_image()
	var px_lac := img.get_pixel(int(EauVillage.LAC_CENTRE.x + 120), int(EauVillage.LAC_CENTRE.y + 120))
	var px_riv := img.get_pixel(int(50 + 120), int(61.5 + 120))
	_verif(px_lac.b > px_lac.r, "couleur du lac bleutée %s" % px_lac)
	_verif(px_riv.b > px_riv.r and px_riv.v < 0.6, "rivière sombre et bleue %s" % px_riv)
	var hx := 30.0
	_verif(absf(o.carte.hauteur(hx, 12.0) - m.hauteur(hx, 12.0)) < 0.6, "relief de la maquette = relief du monde")
	# joueur au centre à l'ouverture
	var pj: Vector3 = m.joueur.global_position
	var s := o.ecran(Vector3(pj.x, o.carte.hauteur(pj.x, pj.z), pj.z))
	_verif(s.distance_to(o.rect_carte().get_center()) < 4.0, "ouverture : le joueur au centre de la carte (%s)" % s)
	# zoom clavier
	var d0: float = o.dist
	_verif(o.entree(_touche(KEY_EQUAL)) and o.dist < d0, "+ : zoom avant")
	_verif(o.entree(_touche(KEY_MINUS)) and is_equal_approx(o.dist, d0), "- : zoom arrière")
	for i in 30:
		o.entree(_touche(KEY_PAGEDOWN))
	_verif(is_equal_approx(o.dist, o._dist_max), "zoom borné (vue d'ensemble %.0f m)" % o._dist_max)
	# déplacement : regarder() borné, centrage
	o.regarder(Vector2(5000, 5000), 100.0, true)
	_verif(o.cible.x <= o.carte.demi + 10.5, "déplacement borné à la carte")
	_verif(o.entree(_touche(KEY_SPACE)), "Espace consommé (centrer)")
	for i in 60:
		await process_frame
	_verif(o._centre.distance_to(Vector2(pj.x, pj.z)) < 1.5, "Espace : retour sur le joueur")
	var titre := o.centrer_quete()
	_verif(titre != "", "F : aller à la quête « %s »" % titre)
	# la coquille garde ses touches
	var laisse := true
	for k in [KEY_TAB, KEY_ESCAPE, KEY_I, KEY_K, KEY_J, KEY_Q, KEY_E]:
		if o.entree(_touche(k)):
			laisse = false
			print("   touche avalée : ", OS.get_keycode_string(k))
	var b := InputEventJoypadButton.new()
	b.pressed = true
	for bt in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B, JOY_BUTTON_BACK]:
		b.button_index = bt
		if o.entree(b):
			laisse = false
	_verif(laisse, "Tab, Échap, I / K / J, Q / E, LB / RB, B, Retour laissés à la coquille")
	# sous terre : le joueur est placé à la porte du tertre
	m.tertre.dedans = true
	_verif(Lieux.position_joueur(m) == m.tertre.porte_dehors and Lieux.sous_terre(m) == "tertre", "sous terre : position = porte du tertre")
	m.tertre.dedans = false
	o.fermer()
	_verif(o.vue.render_target_update_mode == SubViewport.UPDATE_DISABLED, "fermer : la vue ne se rend plus")
	_fin()

func _fin() -> void:
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
