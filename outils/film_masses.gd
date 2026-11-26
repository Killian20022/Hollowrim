extends SceneTree
## MASSES ET MARTEAUX PAR CAPTURES (branche combat/coups_masses_marteaux ; outil repris de combat/hache_captures) : FILM du combo
## contre un draugr. Même séquence AVANT (--masses-anciennes) / APRÈS : repos 0,8 s, puis un clic toutes les 0,9 s
## (coups 1, 2, 3, 1 : combo strict), retour au repos, coup puissant (maintenu 0,9 s), garde.
##   godot --path . --write-movie <f.avi> --fixed-fps <n> --resolution 1280x720 --audio-driver Dummy
##         --script res://outils/film_masses.gd -- --nouvelle [--masses-anciennes] [--arme=masse_cloutee] [--fps=<n>] [--tps] [--titre=...]
##   --fps=<n> : même valeur que --fixed-fps (120 pour un ralenti × 0,5 lu à 60 i/s : une image de jeu tous les 1/120 s) ;
##   --tps     : vue à la 3e personne, caméra derrière l'épaule (celle du jeu) ;
##   --sans-puissant : combo seul.
var DT := 1.0 / 60.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var d: CharacterBody3D

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
	for i in maxi(1, roundi(sec / DT)):
		j.vigueur = j.vigueur_max
		if d != null and is_instance_valid(d) and d.get("vie") != null:
			d.set("vie", maxf(float(d.get("vie")), 80.0))   # le draugr reste debout tout le film
		await process_frame

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _go() -> void:
	DT = 1.0 / float(_arg("fps", "60"))
	RetourImpact.muet = true
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
		s.mannequin.global_position = Vector3(40, 0, 40)
	if s.get("hud") != null:
		s.hud.visible = false
	if s.get("mur") is Node3D:
		(s.mur as Node3D).visible = false
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = Vector2(8, 336)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 0), 0.0, -6.0)
	# draugr figé (sans IA) face au joueur, à portée de hache
	d = s.creer_draugr(Vector3(0.0, 0.0, -1.55), true)
	d.rotation.y = 0.0
	if _arg("tps") != "":
		j.basculer_vue(true)
		j.camera_tp.recaler()
	await _attendre(0.4)
	for id in _arg("armes", _arg("arme", "masse_cloutee")).split(","):
		mains.equipement.equiper("droite", CatalogueArmes.donnees(id))
		var nom_arme: String = mains.arme.nom
		await _attendre(1.0)
		var titre := _arg("titre", "AVANT (poses ecrites)" if GestesLourds.masses_anciennes else "APRES (captures)")
		mains.combat.forcer(EtatCombat.REPOS)
		mains._combo = 0
		mains._depuis_coup = 9.0
		var p := ProfilsAnimation.profil(mains.arme.profil)
		print("FILM profil %s combo %s" % [mains.arme.profil, str(p["combo"])])
		_texte("%s - %s : repos" % [nom_arme, titre])
		await _attendre(0.8)
		for k in 4:
			mains.entrees.appuyer()
			await _attendre(0.05)
			_texte("%s - %s : coup %d (%s)" % [nom_arme, titre, k + 1, mains._clip])
			mains.entrees.relacher()
			await _attendre(0.85)
			print("FILM clic %d -> clip %s" % [k + 1, mains._clip])
		var t := 0.0
		while t < 3.0 and not mains.combat.calme():
			await _attendre(DT)
			t += DT
		_texte("%s - %s : repos" % [nom_arme, titre])
		await _attendre(0.8)
		if _arg("sans-puissant") == "":
			_texte("%s - %s : coup puissant (maintenu)" % [nom_arme, titre])
			mains._depuis_coup = 9.0
			mains._combo = 0
			mains.entrees.appuyer()
			await _attendre(0.9)
			mains.entrees.relacher()
			t = 0.0
			while t < 3.0 and not (t > 0.3 and mains.combat.calme()):
				await _attendre(DT)
				t += DT
			_texte("%s - %s : repos" % [nom_arme, titre])
			await _attendre(0.8)
	print("FIN_FILM_MASSES")
	quit(0)
