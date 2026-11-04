extends SceneTree
## Film (vue FPS) de l'ORDRE DU COMBO : 8 clics, le numéro du coup lancé est affiché (1 = diagonale, 2 = revers, 3 = taille,
## 4 = estoc, puis retour au 1). Fenêtre hors écran via godot_slot.sh :
##   godot --path . --write-movie <fichier.avi> --fixed-fps 60 --script res://outils/film_combo_ordre.gd -- --film
## Clics à rythme mêlé : normal, rapide (clic pendant le coup, mis en tampon), pause d'1 s.

const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var l: Label

func _init() -> void:
	_go.call_deferred()

func _afficher() -> void:
	var n := CoupsUneMain.COMBO.find(mains._geste_nom) + 1
	l.text = "COUP %d / 4   (%s)" % [n, mains._geste_nom]

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	l.text = "Clic 1 -> coup 1 ... clic 4 -> coup 4, puis retour au 1"
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 4.0), 0.0)   # hors de portée : pas de finisher
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains.combat.change.connect(func(_a: int, n: int) -> void:
		if n == EtatCombat.ATTAQUE_LEGERE:
			_afficher.call_deferred())
	mains.pas_manuel = false
	var attendre := func(sec: float) -> void:
		await create_timer(sec, true, false, false).timeout
	await attendre.call(0.8)
	# [durée du clic, attente après] : normal ×3, rapide ×2 (clic pendant le coup), pause d'1 s, normal ×2
	for c in [[0.05, 0.8], [0.05, 0.8], [0.05, 0.8], [0.05, 0.8], [0.04, 0.12], [0.04, 0.9], [0.05, 1.0], [0.05, 0.9]]:
		j.vigueur = j.vigueur_max
		mains.entrees.appuyer()
		await attendre.call(c[0])
		mains.entrees.relacher()
		await attendre.call(c[1])
	await attendre.call(1.0)
	quit()
