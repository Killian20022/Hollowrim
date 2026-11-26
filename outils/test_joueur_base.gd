extends SceneTree
## joueur_base : corps du joueur (homme / femme) de bout en bout, dans le VRAI monde (scenes/foret_test.tscn), sauvegarde de TEST :
##   1. ancienne partie (sauvegarde sans « apparence ») -> homme ;
##   2. nouvelle partie avec le choix « femme » (Jeu.apparence_choisie, posé par l'écran de choix) -> le joueur est la femme (modèle,
##      squelette des humains, Animations, armure portée) ; sauvegarde -> « apparence » écrite ;
##   3. « relance » (choix remis à homme, partie chargée) -> la femme revient de la sauvegarde ; validation réseau du personnage.
##   godot --headless --path . --script res://outils/test_joueur_base.gd
## Imprime « RESULTAT : OK » / « RESULTAT : ECHEC ».

const SCENE := preload("res://scenes/foret_test.tscn")
var _echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func _v(cond: bool, msg: String) -> void:
	print(("ok      " if cond else "ECHEC   ") + msg)
	if not cond:
		_echecs += 1

func _attendre_pret(m: Node, secondes := 150.0) -> bool:
	var t := 0.0
	while not m.pret and t < secondes:
		await process_frame
		t += 1.0 / 60.0
	return m.pret

func _monde() -> Node:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	_v(await _attendre_pret(m), "le monde se charge")
	return m

func _fermer(m: Node) -> void:
	m.queue_free()
	for i in 4:
		await process_frame

func _corps(j: Node) -> String:
	return String(j.corps.modele.get_meta("apparence", "?"))

func _lancer() -> void:
	var fichier: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	if fichier == "user://sauvegarde.json" or not fichier.contains("test"):
		_v(false, "le jeu viserait la vraie sauvegarde (%s) : test annulé" % fichier)
		quit(1)
		return
	var garde := FileAccess.get_file_as_bytes(fichier) if FileAccess.file_exists(fichier) else PackedByteArray()
	# 1. ancienne partie
	var fa := FileAccess.open(fichier, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"version": 2, "joueur": {"position": [10.0, 30.0, 10.0], "lacet": 0.5, "vie": 80.0}, "heure": 9.0,
		"inventaire": {"pieces": 12, "objets": {}}}))
	fa.close()
	Jeu.nouvelle_partie = false
	Jeu.apparence_choisie = "homme"
	var m := await _monde()
	var j = m.joueur
	_v(j.apparence == "homme" and _corps(j) == "homme", "ancienne partie sans choix : homme (%s / modèle %s)" % [j.apparence, _corps(j)])
	await _fermer(m)
	# 2. nouvelle partie, choix « femme »
	Jeu.nouvelle_partie = true
	Jeu.apparence_choisie = "femme"
	m = await _monde()
	j = m.joueur
	var sq: Skeleton3D = j.corps.modele.find_child("Skeleton3D", true, false)
	_v(j.apparence == "femme" and _corps(j) == "femme", "nouvelle partie « femme » : le joueur est la femme (%s / modèle %s)" % [j.apparence, _corps(j)])
	_v(sq != null and sq.get_bone_count() == 65 and sq.find_bone("hand_r") >= 0 and j.corps.anim.has_animation("Walk"), "squelette des humains (65 os) et clips")
	_v(sq != null and sq.motion_scale > 0.8 and sq.motion_scale < 1.0, "bassin des clips mis à la taille (motion_scale %.3f)" % (sq.motion_scale if sq else 0.0))
	j.inventaire.ajouter("cuirasse_fer", 1)
	_v(j.equipement_corps.equiper("cuirasse_fer") == "" and j.corps.armure.maillage("torse") != null, "une cuirasse se porte sur la femme")
	_v(m.sauvegarder(1), "sauvegarde")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sauvegardes.fichier(1)))
	_v(String(d.get("joueur", {}).get("apparence", "")) == "femme", "la sauvegarde garde le corps : %s" % d.get("joueur", {}).get("apparence", ""))
	var ex: Dictionary = SauvegardeMulti.valider(JSON.parse_string(JSON.stringify(m.exporter_personnage())))
	_v(bool(ex["ok"]) and String(ex["personnage"]["joueur"].get("apparence", "")) == "femme", "le personnage passe la validation réseau avec son corps")
	await _fermer(m)
	# 3. « relance » : le choix de l'écran est retombé à homme, la partie est chargée
	Jeu.nouvelle_partie = false
	Jeu.apparence_choisie = "homme"
	Sauvegardes.actif = 1
	m = await _monde()
	j = m.joueur
	_v(j.apparence == "femme" and _corps(j) == "femme", "partie rechargée : la femme revient (%s / modèle %s)" % [j.apparence, _corps(j)])
	_v(j.equipement_corps.objet_a("torse") == "cuirasse_fer" and j.corps.armure.maillage("torse") != null, "et porte toujours sa cuirasse")
	await _fermer(m)
	# remise de la sauvegarde de test
	if garde.size() > 0:
		var fb := FileAccess.open(fichier, FileAccess.WRITE)
		fb.store_buffer(garde)
		fb.close()
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : OK" if _echecs == 0 else "RESULTAT : ECHEC")
	quit(0 if _echecs == 0 else 1)
