extends SceneTree
## Film des coups à une main (coups_v5) en vue de jeu, contre DEUX draugrs : combo complet au rythme des clics (4 clics à
## 0,47 s) puis coup puissant (clic maintenu), deux passages. Ne cite aucune classe propre à coups_v5 : le même script tourne
## dans un worktree de coups_v4 (comparaison honnête, mêmes entrées ; là-bas le 4e clic relance la diagonale).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_coups_v5.gd -- --nouvelle
##         [--titre=coups_v5]
## Les draugrs sont actifs (réactions aux coups) mais ne frappent pas (recharge maintenue), ne parent pas et tiennent les
## deux passages (vie 600, posture infinie : ni mort ni finisher au milieu du film).
const DT := 1.0 / 60.0
const POS_J := Vector3(0.0, 0.0, 7.0)

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var draugrs: Array[CharacterBody3D] = []
var _texte_base := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	for i in roundi(sec / DT):
		for d in draugrs:
			if is_instance_valid(d):
				d._recharge = 99.0
		l.text = "%s — %s   [%s]" % [_arg("titre", ""), _texte_base, mains._geste_nom if mains.combat.etat != EtatCombat.REPOS else "repos"]
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

func _poser_draugrs() -> void:
	for d in draugrs:
		if is_instance_valid(d):
			d.queue_free()
	draugrs.clear()
	for x in [-0.55, 0.6]:
		var p := POS_J + Vector3(x, 0.0, -1.75)
		var d: CharacterBody3D = s.creer_draugr(p, false)
		d.rotation.y = atan2(p.x - POS_J.x, p.z - POS_J.z)   # tourné vers le joueur
		d._bouclier = 0.0
		d.combat.profil.chance_blocage = 0.0
		d.vie_max = 600.0   # survit aux deux passages : on voit chaque coup porter (pas de mort ni de finisher au milieu)
		d.vie = 600.0
		d.combat.profil.posture_max = 9999.0
		d.combat.posture = 9999.0
		draugrs.append(d)

func _sequence() -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	j.vigueur = j.vigueur_max
	_texte_base = "combo (4 clics en rythme)"
	await _attendre(0.5)
	for k in 4:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(0.42)
	await _attendre(0.8)
	# deux draugrs neufs, joueur replacé, pour le coup puissant (ceux du combo sont souvent à terre)
	_poser_draugrs()
	s.placer_joueur(POS_J, 0.0, -6.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _attendre(0.5)
	_texte_base = "coup puissant (clic maintenu)"
	mains.entrees.appuyer()
	await _attendre(0.75)
	mains.entrees.relacher()
	await _attendre(1.4)

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-6.0, 0.0, -6.0)   # hors du cadre
	_etiquette(s)
	await _attendre(0.7)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
	for passage in 2:
		_poser_draugrs()
		s.placer_joueur(POS_J, 0.0, -6.0)
		await _attendre(0.6)
		await _sequence()
	print("FIN_SEQUENCE")
	quit(0)
