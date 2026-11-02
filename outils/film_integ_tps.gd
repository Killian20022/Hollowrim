extends SceneTree
## Film de contrôle de la FUSION 3e personne (integration/tps = tps/coups + tps/mains_sorts), vue de jeu 3e personne :
## épée + torche (combo 1-2-3-4, de dos puis de 3/4), sort en main gauche + épée (coups puis boule de feu chargée de la main
## gauche), claymore (combo + puissant). À vérifier : UNE seule arme dans la main droite, torche levée pendant les coups,
## sort parti de la paume gauche, main gauche sur la poignée de la claymore.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_integ_tps.gd -- --nouvelle
const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var mg: Node
var l: Label

func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		var clip: String = mains.anim.reel(mains.anim.clip) if mains.anim.clip != "" else ""
		l.text = "%s   [%s]" % [l.get_meta("t", ""), clip]
		await process_frame

func _texte(t: String) -> void:
	l.set_meta("t", t)
	print("ETAPE ", t)

func _orbite(deg: float) -> void:
	j.camera_tp.set("_orbite", deg_to_rad(deg))

func _equiper(m: String, id: String) -> void:
	var r: String = mg.equiper(m, id)
	if r != "":
		print("REFUS ", m, " ", id, " : ", r)

func _combo(n: int, intervalle := 0.47) -> void:
	for k in n:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(intervalle - 0.05)

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "nuit": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	mg = mains.magie
	if mg.eq.has_method("apprendre_tout"):
		mg.eq.apprendre_tout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 8)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	j.basculer_vue(true)
	_equiper("droite", "epee")
	_equiper("gauche", "torche")
	await _attendre(1.0)

	_texte("1. Épée + torche : combo 1-2-3-4 (de dos)")
	await _combo(4)
	await _attendre(0.8)
	_orbite(-70.0)
	_texte("1. Épée + torche : combo 1-2-3-4 (3/4 gauche : la torche reste levée)")
	await _attendre(0.5)
	await _combo(4)
	await _attendre(0.8)
	_orbite(70.0)
	_texte("1. Épée + torche : combo 1-2-3-4 (3/4 droit : une seule épée)")
	await _attendre(0.5)
	await _combo(4)
	await _attendre(0.8)

	_texte("2. Boule de feu en main gauche + épée : coups")
	_equiper("gauche", "boule_feu")
	_orbite(-70.0)
	await _attendre(0.8)
	await _combo(2)
	await _attendre(0.6)
	_texte("2. Boule de feu main gauche : charge puis lancer (paume gauche)")
	mg.appuyer("gauche")
	await _attendre(1.3)
	mg.relacher("gauche")
	await _attendre(1.0)
	_texte("2. Jet de flammes main gauche + coup d'épée")
	_equiper("gauche", "jet_flammes")
	_orbite(-40.0)
	await _attendre(0.6)
	mg.appuyer("gauche")
	await _attendre(1.4)
	mg.relacher("gauche")
	await _attendre(0.3)
	await _combo(2)
	await _attendre(0.8)

	_texte("3. Claymore : combo (main gauche sur la poignée)")
	_equiper("gauche", "vide")
	_equiper("droite", "claymore_longue")
	_orbite(-70.0)
	await _attendre(1.2)
	await _combo(3, 0.75)
	await _attendre(0.8)
	_orbite(60.0)
	_texte("3. Claymore : puissant")
	await _attendre(0.4)
	mains.entrees.appuyer()
	await _attendre(0.8)
	mains.entrees.relacher()
	await _attendre(1.4)
	print("FIN_FILM")
	quit(0)
