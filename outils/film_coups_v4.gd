extends SceneTree
## Films AVANT / APRÈS des coups d'épée (coups_v4) en vue de jeu : combo diagonale → revers → estoc puis coup puissant.
## Ne cite aucune classe propre à coups_v4 : le même script tourne dans un worktree de la base (comparaison honnête).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_coups_v4.gd -- --nouvelle
##         --lieu=zone|crypte [--titre=AVANT] [--crypte=x,z,lacet,tangage] [--decalage=0.5]
##   zone   : scenes/test_combat.tscn, mannequin à 1,6 m, deux passages (combo + puissant) ;
##   crypte : la vraie crypte (scenes/foret_test.tscn, --crypte=… : pose du couloir), joueur décalé de --decalage m vers le mur de
##            droite (couloir étroit), même séquence. La ligne « DEBUT_SEQUENCE <s> » donne l'instant à garder au montage (ffmpeg -ss).
const DT := 1.0 / 60.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var _t := 0.0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in roundi(sec / DT):
		await process_frame

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 300)
	calque.add_child(l)

func _texte(t: String) -> void:
	l.text = "%s — %s" % [_arg("titre", ""), t] if _arg("titre", "") != "" else t

func _sequence() -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	j.vigueur = j.vigueur_max
	_texte("combo : 1 diagonale, 2 revers, 3 estoc")
	await _attendre(0.5)
	for k in 3:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(0.42)
	await _attendre(0.8)
	_texte("coup puissant (maintenu)")
	mains.entrees.appuyer()
	await _attendre(0.75)
	mains.entrees.relacher()
	await _attendre(1.3)

func _go() -> void:
	RetourImpact.muet = false
	var lieu := _arg("lieu", "zone")
	if lieu == "zone":
		s = load("res://scenes/test_combat.tscn").instantiate()
		s.options = {"draugr": "aucun", "sans-aide": ""}
		root.add_child(s)
		j = s.joueur
		mains = j.mains
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _attendre(0.7)
		_etiquette(s)
		s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.9), 0.0, -4.0)
		await _attendre(0.4)
		print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
		for passage in 2:
			s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.9), 0.0, -4.0)
			await _sequence()
	else:
		s = load("res://scenes/foret_test.tscn").instantiate()
		s.set_meta("test", true)
		root.add_child(s)
		current_scene = s
		j = s.joueur
		mains = j.mains
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# --crypte=… : monde._aller_crypte descend et place le joueur (1,3 s après la descente) ; on attend qu'il soit sous terre
		var y0 := j.global_position.y
		var n := 0
		while n < 60 * 40 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
			await process_frame
			n += 1
		await _attendre(2.5)
		_etiquette(s)
		var dec := float(_arg("decalage", "0.5"))
		j.global_position += j.global_transform.basis.x * dec
		await _attendre(0.6)
		print("DEBUT_SEQUENCE %.3f (images d'attente : %d)" % [Engine.get_process_frames() / 60.0, n])
		await _sequence()
		_texte("demi-tour, contre l'autre mur")
		j.rotation.y += PI
		await _attendre(0.4)
		await _sequence()
	print("FIN_SEQUENCE")
	quit(0)
