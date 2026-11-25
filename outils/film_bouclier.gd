extends SceneTree
## Film du bouclier v2 (scenes/test_magie.tscn, vue joueur puis 3e personne), UN lancement, hors écran :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 1280x720 --script res://outils/film_bouclier.gd -- --nouvelle
## Sortir le bouclier, garde, coup bloqué, parade parfaite (coup de bouclier, un plan au ralenti), garde brisée, puis la 3e personne
## (repos et garde, plusieurs angles).
const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 30.0

var s: Node3D
var j: CharacterBody3D
var m: MainSort
var mains: Node3D
var l: Label

func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		await process_frame

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _go() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	m = s.magie
	j = s.joueur
	mains = j.mains
	if s.get("titre") != null:
		s.titre.visible = false
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	l = Label.new()
	l.position = Vector2(24, 650)
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	cl.add_child(l)
	m.equiper("droite", "epee")
	m.equiper("gauche", "vide")
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	j.vigueur = j.vigueur_max
	mains.defense = DefenseJoueur.new()
	var devant := j.global_position + Vector3(0, 0, -1.5)
	await _attendre(1.2)
	_texte("Sortir le bouclier")
	m.equiper("gauche", "bouclier")
	await _attendre(1.6)
	_texte("Garde")
	mains.entrees.forcer_garde(2.4)
	await _attendre(1.0)
	_texte("Coup bloque")
	j.recevoir_coup(12.0, devant)
	await _attendre(1.4)
	mains.entrees.forcer_garde(0.0)
	await _attendre(0.8)
	_texte("Parade parfaite : coup de bouclier (ralenti)")
	mains.entrees.forcer_garde(3.0)
	await _attendre(0.05)
	Engine.time_scale = 0.35
	j.recevoir_coup(12.0, devant)
	await _attendre(1.2)
	Engine.time_scale = 1.0
	mains.entrees.forcer_garde(0.0)
	await _attendre(0.8)
	_texte("Garde brisee")
	mains.entrees.forcer_garde(3.0)
	await _attendre(0.5)
	j.vigueur = 1.0
	j.recevoir_coup(30.0, devant)
	await _attendre(1.6)
	mains.entrees.forcer_garde(0.0)
	await _attendre(0.6)
	_texte("3e personne : repos et garde")
	s.joueur.basculer_vue(true)
	for ang in [-130.0, -60.0, 60.0, 150.0]:
		j.camera_tp.set("_orbite", deg_to_rad(ang))
		j.camera_tp.recaler()
		await _attendre(1.0)
		mains.entrees.forcer_garde(1.2)
		await _attendre(1.3)
		mains.entrees.forcer_garde(0.0)
		await _attendre(0.3)
	quit(0)
