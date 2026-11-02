extends SceneTree
## MAINS ET SORTS À LA 3e PERSONNE (branche tps/mains_sorts) : film en vue de jeu 3e personne, en UN lancement.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tps_mains.gd -- --nouvelle [--court]
## Scène test_combat (nuit) : marche torche en main → feu (préparation, jet) → givre → foudre → boule de feu chargée → retour torche →
## épée + sort (coup d'épée puis sort de la main gauche) → sort de la main droite avec la torche → double incantation.
## Les passages alternent caméra de jeu (derrière l'épaule) et caméra tournée de 3/4 (camera_tp._orbite) pour voir les deux bras.
## N'utilise que l'interface du joueur et de la magie : tourne aussi sur une version « avant » (biome/zone-temoin).
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
		await process_frame

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _orbite(deg: float) -> void:
	var c = j.camera_tp
	c.set("_orbite", deg_to_rad(deg))

func _equiper(m: String, id: String) -> void:
	var r: String = mg.equiper(m, id)
	if r != "":
		print("REFUS ", m, " ", id, " : ", r)

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
	await _film()
	print("FIN_FILM")
	quit(0)

func _marcher(sec: float, action := "avant") -> void:
	Input.action_press(action)
	await _attendre(sec)
	Input.action_release(action)
	await _attendre(0.4)

func _jet(m: String, id: String, nom: String) -> void:
	_equiper(m, id)
	_texte("%s : en main (repos)" % nom)
	await _attendre(1.0)
	_texte("%s : jet continu" % nom)
	mg.appuyer(m)
	await _attendre(2.4)
	mg.relacher(m)
	await _attendre(0.7)

func _charge(m: String, id: String, nom: String) -> void:
	_equiper(m, id)
	_texte("%s : en main" % nom)
	await _attendre(0.8)
	_texte("%s : charge (maintenu)" % nom)
	mg.appuyer(m)
	await _attendre(1.3)
	_texte("%s : lancer" % nom)
	mg.relacher(m)
	await _attendre(1.2)

func _film() -> void:
	_texte("Torche en main gauche, épée en main droite : marche")
	await _marcher(2.6)
	_orbite(-120.0)
	await _attendre(0.6)
	await _marcher(1.2, "arriere")
	_orbite(0.0)
	await _jet("gauche", "jet_flammes", "Feu (main gauche, épée à droite)")
	_orbite(-120.0)
	await _jet("gauche", "souffle_givre", "Givre (main gauche)")
	await _jet("gauche", "arc_electrique", "Foudre (main gauche)")
	_orbite(0.0)
	await _charge("gauche", "boule_feu", "Boule de feu (main gauche)")
	_texte("Retour de la torche")
	_equiper("gauche", "torche")
	await _attendre(0.8)
	await _marcher(1.6)
	_texte("Épée + sort : coup d'épée puis sort de la main gauche")
	_equiper("gauche", "boule_feu")
	_orbite(-60.0)
	await _attendre(0.6)
	mains.entrees.appuyer()
	await _attendre(0.05)
	mains.entrees.relacher()
	await _attendre(0.7)
	mg.appuyer("gauche")
	await _attendre(0.25)
	mg.relacher("gauche")
	await _attendre(1.2)
	_texte("Sort en main droite, torche en main gauche")
	_equiper("gauche", "torche")
	_orbite(0.0)
	await _charge("droite", "lance_givre", "Lance de givre (main droite)")
	await _jet("droite", "arc_electrique", "Foudre (main droite, torche à gauche)")
	_texte("Double incantation : feu dans les deux mains")
	_equiper("droite", "jet_flammes")
	_equiper("gauche", "jet_flammes")
	_orbite(-140.0)
	await _attendre(1.0)
	mg.appuyer("gauche")
	mg.appuyer("droite")
	await _attendre(2.4)
	mg.relacher("gauche")
	mg.relacher("droite")
	await _attendre(0.8)
	_orbite(0.0)
	_texte("Mains nues (sorts rangés)")
	_equiper("droite", "vide")
	_equiper("gauche", "vide")
	await _marcher(1.2)
	_equiper("droite", "epee")
	_equiper("gauche", "torche")
	await _attendre(0.6)
