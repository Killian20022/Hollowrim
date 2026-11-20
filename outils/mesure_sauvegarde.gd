extends SceneTree
## Coût de la SAUVEGARDE AUTOMATIQUE sur le fil principal (opti saccades 2026-11-20) : elle part à chaque porte de maison actionnée,
## à l'entrée / sortie de la crypte et de la grotte, à la fin d'une quête et toutes les 10 min — en pleine partie.
##   godot --headless --path . --script res://outils/mesure_sauvegarde.gd -- --nouvelle [--n=5]
## Écrit UNIQUEMENT le fichier de test de cette copie du projet (Sauvegardes.fichier_test, mode outil), jamais user://sauvegarde.json.
## Sortie : « SAUV exporter_monde=.. exporter_personnage=.. stringify=.. ecrire=.. total=.. taille=.. » par essai (ms, octets),
## puis « SAUV_IMAGE pire=.. » : la plus longue image du fil principal pendant monde.autosauvegarder() (chemin réel du jeu).
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	var t0 := Time.get_ticks_msec()
	while m.get("pret") != true and Time.get_ticks_msec() - t0 < 180000:
		await process_frame
	for k in 30:
		await process_frame
	assert(Sauvegardes.fichier(Sauvegardes.AUTO).begins_with("user://sauvegarde_test_"))
	var n := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	for k in n:
		var a0 := Time.get_ticks_usec()
		var dm: Dictionary = m.exporter_monde()
		var a1 := Time.get_ticks_usec()
		var dp: Dictionary = m.exporter_personnage()
		var a2 := Time.get_ticks_usec()
		var tx := JSON.stringify(SauvegardeMulti.fusionner(dm, dp), "\t")
		var a3 := Time.get_ticks_usec()
		var err := Sauvegardes.ecrire(Sauvegardes.fichier(Sauvegardes.AUTO), tx)
		var a4 := Time.get_ticks_usec()
		print("SAUV exporter_monde=%.1f exporter_personnage=%.1f stringify=%.1f ecrire=%.1f total=%.1f taille=%d err=%d" % [(a1 - a0) / 1000.0,
			(a2 - a1) / 1000.0, (a3 - a2) / 1000.0, (a4 - a3) / 1000.0, (a4 - a0) / 1000.0, tx.length(), err])
		await process_frame
	# chemin réel du jeu : durée de l'appel autosauvegarder() puis pire image des 40 suivantes (une écriture en fil s'y termine)
	for k in n * 2:
		var asyn := k % 2 == 1     # alterné : synchrone (avant / --sans-opti-sauvegarde) puis en fil (chemin du jeu)
		var mt := FileAccess.get_modified_time(Sauvegardes.fichier(Sauvegardes.AUTO))
		var b0 := Time.get_ticks_usec()
		m.autosauvegarder(asyn)
		var appel := (Time.get_ticks_usec() - b0) / 1000.0
		var pire := 0.0
		var c0 := Time.get_ticks_usec()
		for i in 40:
			await process_frame
			var c1 := Time.get_ticks_usec()
			pire = maxf(pire, (c1 - c0) / 1000.0)
			c0 = c1
		print("SAUV_IMAGE %s appel=%.1f ms pire_image_apres=%.1f ms derniere=%s fichier_ecrit=%s" % ["fil " if asyn else "sync", appel, pire,
			m.derniere_autosauvegarde, Sauvegardes.valide(Sauvegardes.AUTO)])
		m.derniere_autosauvegarde = ""
		await create_timer(1.1).timeout
	quit(0)
