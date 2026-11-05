extends SceneTree
## Test sans fenêtre du MIXAGE et des PAS PAR MATÉRIAU (scripts/mixage.gd, zone_son.gd, materiau_sol.gd) :
##   godot --headless --path . --script res://outils/test_son.gd -- --nouvelle
## 1. bus : Musique, Ambiance, Effets, Interface, SousTerre existent et sont routés ; limiteur sur le master ; les volumes
##    d'Options (général, musique, effets) sont reliés ;
## 2. reverb : éteinte dehors, allumée dans la crypte, la grotte et une maison (salle de plus en plus petite), refondue dehors ;
## 3. ducking : la musique baisse pendant un dialogue et remonte après ;
## 4. pas : le joueur qui marche sur trois sols (neige, pavé, plancher d'une maison) joue des fichiers du bon matériau, et ceux-ci
##    diffèrent d'un sol à l'autre ; chaque fichier de pas existe ; les sons d'interface existent et vont sur le bus Interface.
const SCENE := preload("res://scenes/foret_test.tscn")

var echecs := 0
var m: Node3D
var _joues: Array[String] = []     # noms des fichiers lancés (lecteurs ajoutés à l'arbre)

func _init() -> void:
	_tester.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	print(("  ok  " if cond else "  ÉCHEC ") + texte)
	if not cond:
		echecs += 1

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _attendre_s(s: float) -> void:
	await create_timer(s).timeout

func _noeud_ajoute(n: Node) -> void:
	if n is AudioStreamPlayer and n.stream != null:
		_joues.append(n.stream.resource_path.get_file().get_basename())

func _tester() -> void:
	print("test_son")
	# ------------------------------------------------------------ 1. bus
	Mixage.creer()
	Mixage.creer()   # idempotent
	for nom: StringName in [&"Musique", &"Ambiance", &"Effets", &"Interface", &"SousTerre"]:
		verifier(AudioServer.get_bus_index(nom) != -1, "bus « %s » présent" % nom)
	verifier(AudioServer.bus_count == 6, "6 bus exactement (Master + 5) : %d" % AudioServer.bus_count)
	verifier(AudioServer.get_bus_index(&"SousTerre") < AudioServer.get_bus_index(&"Effets") and AudioServer.get_bus_index(&"SousTerre") < AudioServer.get_bus_index(&"Ambiance"),
			"SousTerre est AVANT Effets et Ambiance (le serveur mixe du dernier bus au premier : un envoi vers un indice plus haut serait perdu)")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Effets")) == &"SousTerre", "Effets → SousTerre")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Ambiance")) == &"SousTerre", "Ambiance → SousTerre")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(&"SousTerre")) == &"Master", "SousTerre → Master")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Interface")) == &"Master", "Interface → Master (jamais de reverb)")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Musique")) == &"Master", "Musique → Master")
	var lim := false
	for i in AudioServer.get_bus_effect_count(0):
		lim = lim or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	verifier(lim, "limiteur sur le master")
	verifier(Mixage.reverb() != null and not Mixage.reverb_active(), "reverb créée et ÉTEINTE par défaut")
	Jeu.charger_options()
	Jeu.options["son"]["effets"] = 0.5
	Jeu.options["son"]["musique"] = 0.25
	Jeu.options["son"]["general"] = 0.8
	Jeu.appliquer_son()
	verifier(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Effets")), linear_to_db(0.5)), "volume « effets » relié au bus Effets")
	verifier(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Interface")), linear_to_db(0.5)), "l'Interface suit « effets »")
	verifier(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Musique")), linear_to_db(0.25)), "volume « musique » relié au bus Musique")
	verifier(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.8)), "volume « général » relié au Master")
	Jeu.charger_options()
	Jeu.appliquer_son()

	# ------------------------------------------------------------ 2. reverb par salle
	m = SCENE.instantiate()
	root.add_child(m)
	await _attendre(10)
	var zs: ZoneSon = null
	for c in m.get_children():
		if c is ZoneSon:
			zs = c
	verifier(zs != null, "le monde pose un ZoneSon")
	if zs == null:
		quit(1)
		return
	var j: Node3D = m.joueur
	m.tertre.dedans = false
	if m.grotte_acces != null:
		m.grotte_acces.dedans = false
	j.global_position = Vector3(0, 5, 20)
	await _attendre_s(1.0)
	verifier(ZoneSon.zone_en(m, j.global_position) == "dehors" and not Mixage.reverb_active(), "dehors : reverb éteinte")
	verifier(is_zero_approx(Mixage.reverb().wet), "dehors : wet = 0")
	var tailles := {}
	for z: String in ["crypte", "grotte"]:
		var porteur = m.tertre if z == "crypte" else m.grotte_acces
		if porteur == null:
			verifier(false, "%s : porteur absent" % z)
			continue
		if z == "crypte":
			# vraie entrée dans la crypte (le donjon se bâtit en fil d'exécution : on attend la bascule, comme test_musique)
			m.tertre._passer(true)
			var t_att := 0.0
			while not m.tertre.dedans and t_att < 40.0:
				await _attendre_s(0.25)
				t_att += 0.25
		else:
			porteur.dedans = true   # la grotte se construit en fil : on pose seulement l'indicateur que ZoneSon lit
		await _attendre_s(2.0)
		verifier(Mixage.zone == z and Mixage.reverb_active(), "%s : reverb allumée" % z)
		verifier(is_equal_approx(Mixage.reverb().wet, Mixage.ZONES[z]["wet"]), "%s : wet = %.2f après le fondu" % [z, Mixage.ZONES[z]["wet"]])
		tailles[z] = Mixage.reverb().room_size
		if z == "crypte":
			m.tertre._passer(false)
			var t_sor := 0.0
			while m.tertre.dedans and t_sor < 20.0:
				await _attendre_s(0.1)
				t_sor += 0.1
			await _attendre_s(0.6)
		else:
			porteur.dedans = false
			await _attendre_s(0.5)
		verifier(Mixage.reverb().wet < Mixage.ZONES[z]["wet"], "%s : sortie en fondu (wet %.3f < %.2f à 0,5 s)" % [z, Mixage.reverb().wet, Mixage.ZONES[z]["wet"]])
		await _attendre_s(2.0)
		verifier(not Mixage.reverb_active() and Mixage.zone == "dehors", "%s : reverb éteinte à la sortie" % z)
	# une maison du village
	var halle: Interieur = m.village.interieur("halle")
	verifier(halle != null, "la halle existe")
	var dans_halle := halle.to_global(Vector3(0, halle.sol_y + 0.3, 0))
	j.global_position = dans_halle
	await _attendre_s(2.0)
	verifier(Mixage.zone == "maison" and Mixage.reverb_active(), "maison : reverb allumée")
	tailles["maison"] = Mixage.reverb().room_size
	verifier(tailles.get("grotte", 0.0) > tailles.get("crypte", 0.0) and tailles.get("crypte", 0.0) > tailles["maison"],
			"salle : grotte %.2f > crypte %.2f > maison %.2f" % [tailles.get("grotte", 0.0), tailles.get("crypte", 0.0), tailles["maison"]])

	# ------------------------------------------------------------ 3. ducking
	verifier(is_zero_approx(Mixage.duck_db()), "ducking : 0 dB au repos")
	j.en_dialogue = true
	await _attendre_s(1.0)
	verifier(Mixage.est_duck() and Mixage.duck_db() < -8.0, "dialogue : musique baissée (%.1f dB)" % Mixage.duck_db())
	j.en_dialogue = false
	await _attendre_s(2.2)
	verifier(not Mixage.est_duck() and absf(Mixage.duck_db()) < 0.5, "fin du dialogue : musique remontée (%.1f dB)" % Mixage.duck_db())

	# ------------------------------------------------------------ 4. pas par matériau
	for mat: String in MateriauSol.TOUS:
		var manque := []
		for nom: String in MateriauSol.PAS[mat]:
			if Sons.flux(nom) == null:
				manque.append(nom)
		verifier(manque.is_empty(), "%s : %d fichiers de pas présents %s" % [mat, MateriauSol.PAS[mat].size(), manque])
	var manque_ui := []
	for nom: String in ["ui_niveau", "ui_quete_debut", "ui_quete_fin", "ui_ramasse", "ui_potion", "ui_menu_ouvre", "ui_menu_ferme"] + MateriauSol.SAUT:
		if Sons.flux(nom) == null:
			manque_ui.append(nom)
	verifier(manque_ui.is_empty(), "sons d'interface et de saut présents %s" % [manque_ui])
	verifier(Mixage.bus_de(_lecteur_test("ui_niveau")) == Mixage.INTERFACE, "ui_* → bus Interface")
	verifier(Mixage.bus_de(_lecteur_test("ambiance_vent")) == Mixage.AMBIANCE, "ambiance_* → bus Ambiance")
	verifier(Mixage.bus_de(_lecteur_test("footstep_snow_000")) == Mixage.EFFETS, "pas → bus Effets")

	var sols := {
		"neige": Vector3(0, 0, 20),
		"pierre": Vector3(44.0, 0, 40.0),            # place pavée du village
		"bois": null,                                # plancher de la halle
	}
	var vus := {}
	node_added.connect(_noeud_ajoute)
	for nom_sol: String in ["neige", "pierre", "bois"]:
		var p: Vector3
		if nom_sol == "bois":
			p = halle.to_global(Vector3(0, halle.sol_y + 0.2, 0))
		else:
			p = sols[nom_sol]
			p.y = maxf(m.hauteur(p.x, p.z), float(m.h_village)) + 0.6
		var attendu: String = MateriauSol.en(m, p)
		verifier(attendu == nom_sol, "sol « %s » détecté comme %s" % [nom_sol, attendu])
		j.global_position = p
		j.velocity = Vector3.ZERO
		await _attendre(20)    # pose au sol
		_joues.clear()
		Input.action_press("avant")
		await _attendre_s(3.0)
		Input.action_release("avant")
		var pas: Array[String] = []
		for n in _joues:
			if n.begins_with("footstep_") or n.begins_with("pas_"):
				pas.append(n)
		var bons := 0
		for n in pas:
			if n in MateriauSol.PAS[nom_sol]:
				bons += 1
		print("      position finale %s, vitesse %s" % [j.global_position, j.velocity])
		print("      %s : %d pas joués %s ; joueur.materiau_sol = %s" % [nom_sol, pas.size(), pas.slice(0, 4), j.materiau_sol])
		verifier(pas.size() >= 1 and bons == pas.size(), "%s : tous les pas viennent du jeu « %s »" % [nom_sol, nom_sol])
		vus[nom_sol] = pas
	var ens := [vus["neige"][0] if not vus["neige"].is_empty() else "", vus["pierre"][0] if not vus["pierre"].is_empty() else "", vus["bois"][0] if not vus["bois"].is_empty() else ""]
	verifier(ens[0] != ens[1] and ens[1] != ens[2] and ens[0] != ens[2], "le premier pas diffère d'un sol à l'autre %s" % [ens])
	# saut et atterrissage
	_joues.clear()
	var p := Vector3(0, 0, 20)
	p.y = m.hauteur(p.x, p.z) + 3.0
	j.global_position = p
	j.velocity = Vector3.ZERO
	await _attendre_s(1.5)
	verifier(_joues.any(func(n: String) -> bool: return n.begins_with("footstep_snow")), "atterrissage sur la neige : un pas de neige %s" % [_joues.slice(0, 3)])
	node_added.disconnect(_noeud_ajoute)

	print("RÉSULTAT : ", "OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(0 if echecs == 0 else 1)

func _lecteur_test(nom: String) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = Sons.flux(nom)
	return a
