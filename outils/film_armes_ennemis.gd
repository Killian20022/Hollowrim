extends SceneTree
## Film d'un combat à la 3e PERSONNE (caméra derrière l'épaule du joueur, scène test_combat) contre TROIS ennemis armés différemment :
## un draugr à la hache de guerre, un squelette au gourdin, un bandit au sabre de pillard (armes du catalogue, ArmesEnnemis). Les ennemis avancent,
## frappent avec leur arme (gestes capturés d'origine, portée / dégâts / rythme de l'arme) ; le joueur pare puis riposte à l'épée.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_armes_ennemis.gd -- --nouvelle
##         [--armes=hache_guerre,gourdin,sabre_pillard] [--duree=26]
const DT := 1.0 / 60.0
const POS_J := Vector3(0.0, 0.0, 7.0)

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var ennemis: Array[CharacterBody3D] = []
var _noms: Array[String] = []

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	for i in roundi(sec / DT):
		var vivants := []
		for k in ennemis.size():
			if is_instance_valid(ennemis[k]) and ennemis[k].etat != ennemis[k].MORT:
				vivants.append(_noms[k])
		l.text = "   |   ".join(_noms) if vivants.size() > 0 else "fin du combat"
		j.vie = j.vie_max      # le joueur tient bon : on regarde les armes des ennemis, pas sa mort
		await process_frame

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 40)
	calque.add_child(l)

## Ennemi de `type` portant `arme` (identifiant cherché : le tirage est à graine stable), posé en `p`, tourné vers le joueur.
func _ennemi(type: String, arme: String, p: Vector3, apparence := {}) -> CharacterBody3D:
	for k in 600:
		var d := CharacterBody3D.new()
		d.set_script(load("res://scripts/draugr.gd"))
		d.type = type
		d.joueur = j
		d.hud = s.hud
		d.ident = "film_%s_%d" % [type, k]
		if not apparence.is_empty():
			d.apparence = apparence
		d.position = p
		d.rotation.y = atan2(POS_J.x - p.x, POS_J.z - p.z)
		s.add_child(d)
		if String(d._arme) == arme:
			d.vie_max = 900.0
			d.vie = 900.0
			d._bouclier = 0.0
			d.combat.profil.chance_blocage = 0.0
			d.combat.profil.posture_max = 9999.0
			d.combat.posture = 9999.0
			return d
		d.queue_free()
		await process_frame
	return null

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-6.0, 0.0, -6.0)
	_etiquette(s)
	j.basculer_vue(true)
	var armes := _arg("armes", "hache_guerre,gourdin,sabre_pillard").split(",")
	s.placer_joueur(POS_J, 0.0, -6.0)
	j.camera_tp.recaler()
	j.vigueur = j.vigueur_max
	var app_b: Dictionary = GrotteJeu.apparence_humain(1, "")
	var defs := [["sbire", POS_J + Vector3(-3.0, 0.0, -8.0), {}, "draugr — %s"], ["squelette", POS_J + Vector3(0.4, 0.0, -9.5), {}, "squelette — %s"], ["sbire", POS_J + Vector3(3.2, 0.0, -8.0), app_b, "bandit — %s"]]
	for i in 3:
		var dd: Array = defs[i]
		var e: CharacterBody3D = await _ennemi(String(dd[0]), armes[i], dd[1], dd[2])
		if e != null:
			ennemis.append(e)
			_noms.append(String(dd[3]) % String(CatalogueArmes.entree(armes[i]).get("nom", armes[i])))
	print("ENNEMIS ", _noms)
	await _attendre(0.7)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
	var fin := float(_arg("duree", "26"))
	var t := 0.0
	var phase := 0
	while t < fin:
		# le joueur tient bon : garde quand un ennemi est tout près, sinon combo d'épée
		var proche := false
		for e in ennemis:
			if is_instance_valid(e) and e.etat == e.ATTAQUE:
				proche = true
		if proche and phase % 3 == 0:
			mains.entrees.forcer_garde(0.9)
			await _attendre(1.0)
			t += 1.0
		else:
			mains.entrees.appuyer()
			await _attendre(0.05)
			mains.entrees.relacher()
			await _attendre(0.5)
			t += 0.55
		phase += 1
	print("FIN_SEQUENCE")
	quit(0)
