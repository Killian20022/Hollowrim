extends SceneTree
## Test sans fenêtre des SONS de la magie (scripts/magie/sons_magie.gd) : chaque sort (joueur et mage ennemi) a ses sons, tout est
## en .wav PCM (rien d'Ogg décodé à l'exécution), boucles bouclées, pools sans allocation, mage ennemi spatialisé, coût mesuré.
##   godot --headless --path . --script res://outils/test_sons_magie.gd -- --nouvelle
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

func _lancer() -> void:
	print("test_sons_magie")
	var racine := Node3D.new()
	root.add_child(racine)
	current_scene = racine
	# --- fichiers : tout en .wav, aucun .ogg / .mp3
	var dir := DirAccess.open("res://assets/sons/magie")
	var ogg := 0
	var wav := 0
	for f in dir.get_files():
		if f.ends_with(".ogg") or f.ends_with(".mp3"):
			ogg += 1
		if f.ends_with(".wav"):
			wav += 1
	verifier(ogg == 0 and wav >= SonsMagie.tous_les_noms().size(), "assets/sons/magie : %d .wav, %d .ogg/.mp3" % [wav, ogg])
	# --- chaque son existe, est un AudioStreamWAV PCM 16 bits, boucle ssi charge_ / jet_
	SonsMagie.precharger()
	var attente := 0
	while attente < 600:
		var prets := true
		for nom: String in SonsMagie.tous_les_noms():
			if ResourceLoader.load_threaded_get_status(SonsMagie._chemin(nom)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				prets = false
		if prets:
			break
		attente += 1
		await process_frame
	var manquants: Array = []
	var mal_boucles: Array = []
	for nom: String in SonsMagie.tous_les_noms():
		var s := SonsMagie.flux(nom)
		if s == null:
			manquants.append(nom)
			continue
		var boucle := nom.begins_with("magie/charge_") or nom.begins_with("magie/jet_")
		if s.format != AudioStreamWAV.FORMAT_16_BITS or s.data.size() == 0 or (s.loop_mode != AudioStreamWAV.LOOP_DISABLED) != boucle:
			mal_boucles.append(nom)
	verifier(manquants.is_empty(), "les %d sons se chargent en AudioStreamWAV %s" % [SonsMagie.tous_les_noms().size(), manquants])
	verifier(mal_boucles.is_empty(), "PCM 16 bits, boucle uniquement pour charge_ / jet_ %s" % [mal_boucles])
	verifier(SonsMagie.sync == 0, "aucun chargement synchrone après precharger() (%d)" % SonsMagie.sync)
	# --- chaque sort a ses sons (joueur : data/sorts, ennemis : data/sorts/ennemis)
	var sorts := 0
	for rep in ["res://data/sorts", "res://data/sorts/ennemis"]:
		for f in DirAccess.get_files_at(rep):
			if not f.ends_with(".tres"):
				continue
			var s := load(rep + "/" + f) as DonneesSort
			if s == null:
				continue
			sorts += 1
			var e := s.ecole
			var ok: bool = e in SonsMagie.ECOLES
			for n: String in SonsMagie.noms_ecole(e, "lancer") + SonsMagie.noms_ecole(e, "impact") + ["magie/charge_" + e, "magie/jet_" + e]:
				ok = ok and SonsMagie.flux(n) != null
			verifier(ok, "sort %s (%s) : charge, lancement, jet, impact" % [s.id, e])
	verifier(sorts >= 15, "%d sorts examinés" % sorts)
	verifier(SonsMagie.flux("magie/refus_mana") != null and SonsMagie.flux("magie/double") != null, "mana insuffisant et double incantation")
	for r: String in SonsMagie.REACTIONS:
		verifier(SonsMagie.flux("magie/reaction_" + r) != null, "réaction " + r)
	# --- points de branchement : les appels du contrat atteignent SonsMagie
	EffetsMagie.muet = false
	SonsMagie.appels.clear()
	var main := Node3D.new()
	racine.add_child(main)
	var ennemi := Node3D.new()
	racine.add_child(ennemi)
	ennemi.global_position = Vector3(25, 1.5, -10)
	var pts: Array[Vector3] = [Vector3(0, 1, -3), Vector3(1, 1, -5)]
	for e: String in ["feu", "glace", "electricite", "tenebres"]:
		EffetsMagie.aura_main(main, e, 1.0)
		EffetsMagie.jet(e, main, Vector3.FORWARD, 5.0, 1.0, true)
		EffetsMagie.impact(e, Vector3(0, 1, -5), Vector3.UP, 1.0)
		EffetsMagie.zone(e, Vector3(0, 0, -5), 3.0, 1.0)
		EffetsMagie.chaine(e, pts)
		EffetsMagie.double(e, true)
		EffetsMagie.enchant_arme(main, e, true)
		await process_frame
	for r: String in SonsMagie.REACTIONS:
		EffetsMagie.reaction(r, Vector3(0, 1, -4), 2.0)
	for a in ["aura", "jet", "impact", "zone", "chaine", "double", "enchant", "reaction"]:
		verifier(int(SonsMagie.appels.get(a, 0)) >= 4, "EffetsMagie -> SonsMagie.%s (%d appels)" % [a, int(SonsMagie.appels.get(a, 0))])
	verifier(SonsMagie.joues > 0, "des sons sont réellement lancés (%d)" % SonsMagie.joues)
	# --- mage ennemi : boucle spatialisée sur SA main
	var n := SonsMagie._n()
	EffetsMagie.tout_arreter()
	for i in 90:
		await process_frame
	verifier(n.boucles.all(func(v: SonsMagie.Voix) -> bool: return v.cle == -1), "tout_arreter : boucles éteintes")
	EffetsMagie.aura_main(ennemi, "glace", 0.9)
	await process_frame
	await process_frame
	var v_ennemi: SonsMagie.Voix = null
	for v in n.boucles:
		if v.cle == ennemi.get_instance_id() * 2:
			v_ennemi = v
	verifier(v_ennemi != null and v_ennemi.lecteur is AudioStreamPlayer3D and v_ennemi.lecteur.playing, "mage ennemi : charge jouée par un AudioStreamPlayer3D")
	verifier(v_ennemi != null and v_ennemi.lecteur.global_position.distance_to(ennemi.global_position) < 0.01, "mage ennemi : le son suit sa main (spatialisé)")
	EffetsMagie.aura_main(ennemi, "glace", 0.0)
	# jet : s'éteint seul
	EffetsMagie.jet("feu", main, Vector3.FORWARD, 5.0, 1.0, true)
	await process_frame
	var actif := n.boucles.any(func(v: SonsMagie.Voix) -> bool: return v.cle == main.get_instance_id() * 2 + 1)
	verifier(actif, "jet : boucle active tant qu'on l'appelle")
	for i in 80:
		await process_frame
	verifier(n.boucles.all(func(v: SonsMagie.Voix) -> bool: return v.cle == -1), "jet : boucle éteinte 0,25 s après le dernier appel")
	# --- muet : compté mais silencieux
	EffetsMagie.muet = true
	var avant := SonsMagie.joues
	var ap := int(SonsMagie.appels.get("impact", 0))
	EffetsMagie.impact("feu", Vector3.ZERO, Vector3.UP, 1.0)
	verifier(SonsMagie.joues == avant and int(SonsMagie.appels.get("impact", 0)) == ap + 1, "EffetsMagie.muet : appel compté, rien de joué")
	EffetsMagie.muet = false
	# --- pas d'allocation : nombre de nœuds et d'objets stable sur 400 sorts
	for i in 3:
		await process_frame
	EffetsMagie.tout_arreter()
	for i in 200:   # laisse mourir les visuels des appels précédents avant de compter
		await process_frame
	var noeuds := n.get_child_count()
	var obj0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var res0 := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var t0 := Time.get_ticks_usec()
	var appels := 0
	for i in 400:
		var e: String = SonsMagie.ECOLES[i % 4]
		SonsMagie.lancement(e, Vector3(0, 1, -3), 1.0)
		SonsMagie.impact(e, Vector3(0, 1, -5), 1.0)
		SonsMagie.reaction(SonsMagie.REACTIONS[i % 6], Vector3(0, 1, -4))
		SonsMagie.jet(e, main, true)
		SonsMagie.aura(main, e, 0.5 + 0.001 * i)
		appels += 5
		if i % 4 == 3:
			await process_frame
	var dt := float(Time.get_ticks_usec() - t0)
	verifier(n.get_child_count() == noeuds, "pool : %d nœuds avant / après 400 salves" % noeuds)
	verifier(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == obj0, "aucun nœud créé par sort (%d)" % int(obj0))
	verifier(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) <= res0 + 1, "aucune ressource créée par sort (%d -> %d)" % [int(res0), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	verifier(SonsMagie.sync == 0, "toujours aucun chargement synchrone (%d)" % SonsMagie.sync)
	# --- coût mesuré (CPU, fil principal) : appels seuls, puis salve typique par image
	var t1 := Time.get_ticks_usec()
	for i in 1000:
		SonsMagie.impact("feu", Vector3(0, 1, -5), 1.0)
		SonsMagie.lancement("glace", Vector3(0, 1, -3), 1.0)
	var par_appel := float(Time.get_ticks_usec() - t1) / 2000.0
	# pire image : 5 lectures réelles (plafond par image) + 3 boucles qui montent, mesurées image par image
	var pire := 0.0
	var somme := 0.0
	var lect0 := SonsMagie.joues
	await create_timer(0.3).timeout
	for i in 120:
		await create_timer(0.07).timeout
		var tt := Time.get_ticks_usec()
		for e: String in ["feu", "glace", "electricite", "tenebres"]:
			SonsMagie.lancement(e, Vector3(0, 1, -3), 1.0)
			SonsMagie.impact(e, Vector3(0, 1, -5), 1.0)
		SonsMagie.reaction("vapeur", Vector3(0, 1, -4))
		SonsMagie.jet("feu", main, true)
		SonsMagie.aura(main, "glace", 1.0)
		SonsMagie.aura(ennemi, "tenebres", 1.0)
		var d := float(Time.get_ticks_usec() - tt)
		somme += d
		pire = maxf(pire, d)
	print("  mesure image chargée : moyenne %.0f us, pire %.0f us, %d lectures réelles sur 120 images" % [somme / 120.0, pire, SonsMagie.joues - lect0])
	verifier(pire < 2000.0 and somme / 120.0 < 600.0, "salve de 5 lectures + 3 boucles par image (cas extrême) : moyenne %.0f us (< 600), pire %.0f us (< 2000)" % [somme / 120.0, pire])
	# coût continu : un jet + une charge ennemie appelés CHAQUE image (le cas d'un combat soutenu), sans nouvelle lecture
	var cont := 0.0
	var cont_max := 0.0
	for i in 240:
		await process_frame
		var tc := Time.get_ticks_usec()
		SonsMagie.jet("feu", main, true)
		SonsMagie.aura(ennemi, "tenebres", 1.0)
		var dc := float(Time.get_ticks_usec() - tc)
		cont += dc
		cont_max = maxf(cont_max, dc)
	# un sort complet (lancement + impact) = 2 lectures
	var cast := 0.0
	for i in 60:
		await create_timer(0.1).timeout
		var tk := Time.get_ticks_usec()
		SonsMagie.lancement("electricite", Vector3(0, 1, -3), 1.0)
		SonsMagie.impact("electricite", Vector3(0, 1, -8), 1.0)
		cast += float(Time.get_ticks_usec() - tk)
	print("  mesure : jet + charge chaque image : moyenne %.1f us (pire %.0f) ; un sort (lancement + impact) : %.1f us" % [cont / 240.0, cont_max, cast / 60.0])
	verifier(cont / 240.0 < 100.0 and cast / 60.0 < 300.0, "coût continu < 100 us par image, un sort < 300 us (marge sur le budget de +0,3 ms)")
	print("  mesure : %.1f us par appel de son (lecture ou refus), %d appels en %.1f ms avec %d images" % [par_appel, appels, dt / 1000.0, 100])
	verifier(par_appel < 100.0, "coût par appel < 100 us (%.1f us)" % par_appel)
	print("test_sons_magie : ", "TOUT OK" if echecs == 0 else "ECHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)
