extends SceneTree
## Lot vie/metiers : gestes de métier au poste et causeries entre PNJ.
##   - données : data/vie/metiers.json (clips EXISTANTS de Humain.bibliotheque()), data/vie/conversations.json (>= 30 échanges de 2 à 4
##     répliques, rôles connus, pas de « Gunnhild ») ;
##   - 10 h : chaque habitant à métier joue l'étape de son métier, à son poste (étal, banc, puits, tas de bois), les fixes face à leur ouvrage ;
##     le cycle avance (au moins deux clips vus en 40 s) ; le vieux assis sur le banc, modèle rehaussé, pieds au sol, assise à la bonne hauteur ;
##   - corps Tripo (Gunnar, Eirwen) : métier joué aussi ; 20 h : gestes du feu ;
##   - causerie : deux PNJ se tournent l'un vers l'autre, 2 à 4 répliques, sous-titre, chacun reprend son métier ; l'un rejoint l'autre à pied
##     puis retourne à son poste ; filtres (heure, météo, journal, disposition) ; interrompue si le joueur parle à l'un d'eux ;
##   - perf : tick de Vie < 2 ms (médiane), rien loin du joueur ; `--sans-metiers` : ancien comportement.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_metiers_pnj.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var vie: Vie
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

func _heure(h: float) -> void:
	m.cycle.heure = h
	vie.tick()
	await _attendre(0.3)

func _donnees() -> void:
	var lib := Humain.bibliotheque()
	var md := Metiers.donnees()
	var clips_ok := true
	var manque := []
	for nom: String in md.get("metiers", {}):
		for e: Dictionary in md["metiers"][nom]["etapes"]:
			if not lib.has_animation(String(e["clip"])):
				clips_ok = false
				manque.append(e["clip"])
	_verif(clips_ok, "metiers.json : tous les clips existent dans Humain.bibliotheque() %s" % str(manque))
	var ech := ConversationsVie.charger()
	_verif(ech.size() >= 30, "conversations.json : %d échanges (>= 30)" % ech.size())
	var formes := true
	var ids := {}
	var texte := FileAccess.get_file_as_string(ConversationsVie.FICHIER)
	for e: Dictionary in ech:
		var l: Array = e.get("lignes", [])
		formes = formes and l.size() >= 2 and l.size() <= 4 and not ids.has(e.get("id", ""))
		ids[e.get("id", "")] = true
		var qui := {}
		for x: Array in l:
			formes = formes and String(x[0]) in ["a", "b"] and String(x[1]).length() > 3 and String(x[1]).length() < 140
			qui[x[0]] = true
		formes = formes and qui.size() == 2
	_verif(formes, "chaque échange : id unique, 2 à 4 répliques courtes, les deux parlent")
	_verif(not texte.contains("Gunnhild") and texte.contains("Gunnar"), "le chef s'appelle Gunnar (pas de Gunnhild)")
	var q: Dictionary = m.quetes.donnees
	var imp := ""
	for e: Dictionary in ech:
		var e2 := e.duplicate()
		e2["texte"] = e.get("lignes", [])      # impossible() exige du texte : les lignes en tiennent lieu
		var r := RepliquesFiltrees.impossible(e2, q)
		if r != "":
			imp += "%s:%s " % [e["id"], r]
	_verif(imp == "", "aucun filtre impossible (quêtes, étapes, bornes) %s" % imp)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 10:
		await physics_frame
	vie = m.get_node_or_null("Vie")
	_verif(vie != null and vie.conversations != null, "Vie et ses causeries branchées")
	if vie == null:
		_fin()
		return
	await _donnees()
	var j: CharacterBody3D = m.joueur
	j.global_position = Vector3(44.0, m.hauteur(44.0, 40.0) + 0.2, 40.0)
	j.velocity = Vector3.ZERO
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	vie.conversations._prochain = 1.0e9      # pas de causerie spontanée pendant la partie « gestes »
	await _heure(10.0)

	# --- métiers résolus
	var attendus := {"forgeron": "forgeron", "ancienne": "puiser", "hab_paysan_3": "marchand", "hab_paysan_2": "banc",
		"hab_chasseur_2": "bois", "hab_paysanne_3": "lavandiere", "chasseuse": "pisteuse", "volva": "voyante", "chef": "chef",
		"garde": "faction", "hab_mage_tripo": "mage"}
	for id: String in attendus:
		var c := vie.civil(id)
		var n: Node3D = c.get("n")
		_verif(n != null and String(n.metier.get("nom", "")) == attendus[id], "%s : métier « %s »" % [id, attendus[id]])
	var sans: Node3D = vie.civil("hab_paysan_1")["n"]
	_verif(sans.metier.is_empty() and sans._act() == "Idle_Talking", "habitant sans métier : activité d'avant gardée (hab_paysan_1 : Idle_Talking)")

	# --- au poste, l'étape du métier est jouée ; postes déplacés appliqués
	await _attendre(1.0)
	for id: String in attendus:
		var n: Node3D = vie.civil(id)["n"]
		var ok: bool = n.etat == 0 and n.geste() != "" and (n._anim == n.geste() or n._anim in ["Sitting_Enter", "Interact", "Idle_Talking", "Idle"])
		_verif(ok, "%s : au poste, geste « %s » (clip joué %s)" % [id, n.geste(), n._anim])
	var marchand: Node3D = vie.civil("hab_paysan_3")["n"]
	_verif(Vector2(marchand.global_position.x - 51.05, marchand.global_position.z - 29.95).length() < 0.3, "le marchand est derrière l'étal des primeurs (51,05 ; 29,95)")
	_verif(absf(angle_difference(marchand.rotation.y, 0.0)) < 0.15, "le marchand fait face au comptoir")
	var grima: Node3D = vie.civil("ancienne")["n"]
	var vers_puits := Vector2(42.0 - grima.global_position.x, 38.0 - grima.global_position.z)
	_verif(vers_puits.length() < 2.2 and vers_puits.length() > 1.4, "Grima au bord du puits (%.2f m du centre)" % vers_puits.length())
	_verif(absf(angle_difference(grima.rotation.y, atan2(vers_puits.x, vers_puits.y))) < 0.2, "Grima tournée vers le puits")
	# le joueur s'approche du marchand : il garde son cap (métier fixe), sa tête suit
	j.global_position = marchand.global_position + Vector3(2.0, 0.2, 0.0)
	await _attendre(1.5)
	_verif(absf(angle_difference(marchand.rotation.y, 0.0)) < 0.15, "joueur à 2 m : le marchand ne pivote pas hors de son étal")

	# --- assis sur le banc
	var vieux: Node3D = vie.civil("hab_paysan_2")["n"]
	_verif(vieux.assis() and vieux._anim.begins_with("Sitting"), "le vieux est assis sur le banc (%s)" % vieux._anim)
	_verif(absf(vieux.modele.position.y - vieux._y_modele0 - 0.04) < 0.005, "modèle rehaussé de 4 cm (banc 0,48 m)")
	var sq: Skeleton3D = vieux.modele.find_child("Skeleton3D", true, false)
	var bassin := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("pelvis")).origin
	var sol := float(m.hauteur(bassin.x, bassin.z))
	_verif(bassin.y - sol > 0.42 and bassin.y - sol < 0.62, "bassin à %.2f m du sol (assise du banc 0,48 m)" % (bassin.y - sol))
	var dz := Vector2(bassin.x - 47.5, bassin.z - 46.6).length()
	print("bassin ", bassin, " origine ", vieux.global_position)
	_verif(dz < 0.22, "bassin au-dessus de l'assise du banc (%.2f m du milieu)" % dz)
	var pied := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("foot_l")).origin
	_verif(absf(pied.y - float(m.hauteur(pied.x, pied.z))) < 0.18, "pied gauche au sol (%.2f m)" % (pied.y - float(m.hauteur(pied.x, pied.z))))

	# --- le cycle avance
	var vus := {}
	var forg: Node3D = vie.civil("forgeron")["n"]
	for k in 40:
		await _attendre(1.0)
		vus[forg._anim] = true
	_verif(vus.size() >= 2 and vus.has("Fixing_Kneeling"), "Brodd : le cycle du métier avance en 40 s (%s)" % str(vus.keys()))

	# --- corps Tripo
	var gunnar: Node3D = vie.civil("chef")["n"]
	var eir: Node3D = vie.civil("hab_mage_tripo")["n"]
	_verif(gunnar.modele is Node3D and gunnar.anim.has_animation("Interact") and gunnar.geste() != "", "Gunnar (corps Tripo) : métier « chef » joué (%s)" % gunnar._anim)
	_verif(eir.geste() != "" and eir.anim.has_animation("Spell_Simple_Idle"), "Eirwen (corps Tripo) : métier « mage » joué (%s)" % eir._anim)

	# --- 20 h : gestes du feu
	await _heure(20.0)
	await _attendre(1.0)
	var au_feu := 0
	for c: Dictionary in vie.civils:
		var n: Node3D = c["n"]
		if n._act_vie == "@feu" and String(n._metier_soir.get("nom", "")) == "feu":
			au_feu += 1
	_verif(au_feu >= 6, "20 h : %d civils au feu avec les gestes du feu" % au_feu)
	await _heure(10.0)
	await _attendre(1.0)

	# --- causerie forcée (sur place) entre deux PNJ proches
	var cv := vie.conversations
	var lignes: Array = []
	cv.ligne_dite.connect(func(nom: String, t: String, idx: String) -> void: lignes.append([nom, t, idx]))
	var pa: Node3D = vie.civil("hab_paysan_1")["n"]
	var pb: Node3D = vie.civil("hab_paysanne_1")["n"]
	j.global_position = pa.global_position + Vector3(0, 0.2, 4.0)
	_verif(cv.forcer("hab_paysan_1", "hab_paysanne_1"), "causerie entre les deux paysans voisins")
	await _attendre(2.0)
	var va := (pb.global_position - pa.global_position).normalized()
	var fa := Vector3(sin(pa.rotation.y), 0, cos(pa.rotation.y))
	var fb := Vector3(sin(pb.rotation.y), 0, cos(pb.rotation.y))
	_verif(fa.dot(va) > 0.9 and fb.dot(-va) > 0.9, "ils se font face (%.2f / %.2f)" % [fa.dot(va), fb.dot(-va)])
	var t1 := 0
	while cv.actives() and t1 < 30:
		await _attendre(1.0)
		t1 += 1
	_verif(not cv.actives() and lignes.size() >= 2 and lignes.size() <= 4, "causerie finie : %d répliques (%s)" % [lignes.size(), lignes[0][2] if not lignes.is_empty() else "-"])
	_verif(lignes.size() >= 2 and lignes[0][0] != lignes[1][0], "les deux parlent tour à tour")
	_verif(pa.causerie == null and pb.causerie == null and pa._anim == "Idle_Talking", "chacun reprend son activité")

	# --- causerie avec déplacement : Eirwen rejoint Sigrún (la place) puis revient
	var sig: Node3D = vie.civil("volva")["n"]
	var poste_e: Vector3 = eir.points[0]
	eir.global_position = poste_e
	j.global_position = sig.global_position + Vector3(3.0, 0.2, 3.0)
	var d0 := eir.global_position.distance_to(sig.global_position)
	lignes.clear()
	var lance := cv.forcer("hab_mage_tripo", "volva")
	_verif(lance, "causerie Eirwen / Sigrún lancée (%.1f m entre elles)" % d0)
	if lance:
		var marche := false
		var t2 := 0
		var d_min := 99.0
		while cv.actives() and t2 < 40:
			await _attendre(0.5)
			t2 += 1
			marche = marche or eir.etat == 4 or sig.etat == 4
			d_min = minf(d_min, eir.global_position.distance_to(sig.global_position))
		_verif(d0 <= ConversationsVie.R_FACE or (marche and d_min < 1.8), "l'une rejoint l'autre à pied (au plus près %.2f m)" % d_min)
		_verif(lignes.size() >= 2, "%d répliques échangées (%s)" % [lignes.size(), lignes[0][2] if not lignes.is_empty() else "-"])
		await _attendre(8.0)
		var de_retour := eir.global_position.distance_to(poste_e) < 1.0 or sig.global_position.distance_to(sig.points[0]) < 1.0
		_verif(de_retour and eir.etat != 4 and sig.etat != 4, "la marcheuse est retournée à son poste")

	# --- filtres
	var a: Node3D = vie.civil("hab_paysan_1")["n"]
	var b: Node3D = vie.civil("hab_paysanne_1")["n"]
	var ca := vie.civil("hab_paysan_1")
	var e_nuit := _ech("nuit_rentrer")
	var e_temp := _ech("tempete_porte")
	var e_brodd := _ech("brodd_fer")
	var e_quete := _ech("tertre_calme")
	_verif(cv.refus(e_nuit, a, b, ca) == "heure", "10 h : échange de nuit refusé")
	m.cycle.heure = 22.5
	_verif(cv.refus(e_nuit, a, b, ca) == "", "22 h 30 : échange de nuit accepté")
	m.cycle.heure = 10.0
	_verif(cv.refus(e_temp, a, b, ca) == "meteo", "temps calme : échange de tempête refusé")
	cv.force_meteo = "tempete"
	_verif(cv.refus(e_temp, a, b, ca) == "", "tempête : échange de tempête accepté")
	cv.force_meteo = ""
	_verif(cv.refus(e_brodd, a, b, ca) == "roles" and cv.refus(e_brodd, forg, b, ca) == "", "échange de Brodd : seulement avec Brodd")
	_verif(cv.refus(e_quete, a, b, ca) == "journal", "anneau pas rendu : échange « tertre calme » refusé")
	var r_disp := cv.refus(_ech("etranger_mefiance"), a, b, ca)
	_verif(r_disp == "disposition", "joueur bien vu (neutre) : échange de méfiance refusé (%s)" % r_disp)
	var ch := cv.choisir(forg, b)
	_verif(not ch.is_empty() and ConversationsVie.precision(ch["e"]) >= 2, "Brodd et une fermière : un échange propre à Brodd est préféré (%s)" % (ch["e"]["id"] if not ch.is_empty() else "-"))

	# --- le joueur parle à l'un d'eux : la causerie s'interrompt
	vie.conversations._repos.clear()
	j.global_position = a.global_position + Vector3(0, 0.2, 3.0)
	if cv.forcer("hab_paysan_1", "hab_paysanne_1"):
		await _attendre(1.0)
		j.en_dialogue = true
		a.parler()
		vie.tick()
		await _attendre(0.6)
		vie.tick()
		_verif(not cv.actives() and a.causerie == null and b.causerie == null, "le joueur parle à l'un : la causerie s'arrête")
		j.en_dialogue = false
		await _attendre(1.0)
	else:
		_verif(false, "deuxième causerie forcée")

	# --- loin du joueur : rien
	cv.finir()
	cv._repos.clear()
	cv._prochain = 0.0
	j.global_position = Vector3(44.0, m.hauteur(44.0, 100.0) + 0.3, 100.0)
	for k in 8:
		vie.tick()
		await _attendre(0.5)
	_verif(not cv.actives(), "joueur à 60 m de la place : aucune causerie %s (joueur %s)" % [str([cv.actif["a"].donnees["id"], cv.actif["b"].donnees["id"]]) if cv.actives() else "", j.global_position])

	# --- spontanées près du joueur
	j.global_position = Vector3(41.0, m.hauteur(41.0, 41.0) + 0.2, 41.0)
	cv._prochain = 0.0
	var spont := 0
	var dites0 := cv.dites
	for k in 120:
		await _attendre(0.5)
		if cv.actives():
			spont += 1
		if cv.causeries >= 3 and not cv.actives():
			break
	_verif(cv.dites > dites0, "causeries spontanées sur la place (%d répliques en %.0f s)" % [cv.dites - dites0, 60.0])

	# --- perf
	var mesures: Array = []
	for k in 30:
		vie.tick()
		mesures.append(vie.tick_ms)
		await _attendre(0.1)
	var tms: Array = []
	for k in 30:
		var t := Time.get_ticks_usec()
		vie.tick()
		tms.append((Time.get_ticks_usec() - t) / 1000.0)
	tms.sort()
	_verif(float(tms[15]) < 2.0, "tick de Vie (métiers + causeries) : médiane %.3f ms" % float(tms[15]))
	_fin()

func _ech(id: String) -> Dictionary:
	for e: Dictionary in vie.conversations.echanges:
		if e["id"] == id:
			return e
	return {}

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
