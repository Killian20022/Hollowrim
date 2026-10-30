extends SceneTree
## GESTES LOURDS (branche combat/gestes_lourds) : film en vue de jeu puis planche des poses clés, en UN lancement.
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_gestes_lourds.gd --
##         --nouvelle --sortie=<dossier des poses>
## Film : hache de guerre, masse cloutée, marteau de guerre, grand marteau — chacun contre 2 draugrs actifs : garde au repos,
## combo de 3 coups, coup puissant (maintenu). Puis poses figées (repos, armés, impacts) → <sortie>/planche_poses.png.
const DT := 1.0 / 60.0
const ARMES := ["hache_guerre", "masse_cloutee", "marteau_guerre", "grand_marteau"]
const POSES := [
	["hache_guerre", "repos_h:0.0", "Hache : repos (manche bas, tête penchée)"], ["hache_guerre", "h_a:0.15", "Hache 1 : armé"],
	["hache_guerre", "h_a:0.30", "Hache 1 : impact (arrêt net)"], ["hache_guerre", "h_c:0.32", "Hache 3 : taille verticale, impact"],
	["masse_cloutee", "repos_m:0.0", "Masse : repos (tête lourde)"], ["masse_cloutee", "m_a:0.40", "Masse 1 : crochet, armé"],
	["masse_cloutee", "m_a:0.63", "Masse 1 : crochet, impact"], ["masse_cloutee", "m_c:0.70", "Masse 3 : écrasement, impact"],
	["marteau_guerre", "repos_m:0.0", "Marteau : repos"], ["marteau_guerre", "m_c:0.46", "Marteau 1 : écrasement, armé"],
	["marteau_guerre", "m_c:0.70", "Marteau 1 : impact"], ["marteau_guerre", "m_b:0.62", "Marteau 3 : revers, impact"],
	["grand_marteau", "repos_gm:0.0", "Grand marteau : repos (2 mains)"], ["grand_marteau", "gm_a:0.45", "Grand marteau : armé"],
	["grand_marteau", "gm_a:0.70", "Grand marteau : tête au sol"], ["grand_marteau", "gm_b:0.67", "Grand marteau 2 : diagonale, impact"],
]

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await process_frame

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id))
	await _attendre(0.8)

func _clic() -> void:
	mains.entrees.appuyer()
	await _attendre(0.05)
	mains.entrees.relacher()

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _attendre(0.7)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 300)
	calque.add_child(l)
	await _film()
	await _poses()
	quit(0)

func _film() -> void:
	for n in ARMES.size():
		var id: String = ARMES[n]
		s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
		await _equiper(id)
		var nom: String = mains.arme.nom
		mains.combat.forcer(EtatCombat.REPOS)
		j.vigueur = j.vigueur_max
		j.vie = j.vie_max if "vie_max" in j else j.vie
		_texte("%s : tenue au repos" % nom)
		await _attendre(1.2)
		var d1: Node = s.creer_draugr(Vector3(-0.8, 0, 3.1), true)
		var d2: Node = s.creer_draugr(Vector3(0.8, 0, 3.4), true)
		for d in [d1, d2]:
			d.look_at(j.global_position, Vector3.UP, true)
		await _attendre(0.3)
		var p := ProfilsAnimation.profil(mains.arme.profil)
		_texte("%s : combo (%s)" % [nom, ", ".join(p["combo"])])
		mains._combo = 0
		var pas := 1.5 if mains.arme.deux_mains else (0.62 if mains.arme.profil == "hache" else 1.0)
		for k in 3:
			await _clic()
			await _attendre(pas)
		await _attendre(0.6)
		j.vigueur = j.vigueur_max
		_texte("%s : coup puissant (maintenu)" % nom)
		mains.entrees.appuyer()
		await _attendre(1.0)
		mains.entrees.relacher()
		await _attendre(2.0 if mains.arme.deux_mains else 1.4)
		for d in [d1, d2]:
			if is_instance_valid(d):
				d.queue_free()
		await _attendre(0.2)
	print("FIN_FILM")

func _poses() -> void:
	var dossier := _arg("sortie", "res://captures/gestes_lourds")
	DirAccess.make_dir_recursive_absolute(dossier)
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0, -4.0)
	var imgs: Array[Image] = []
	var arme := ""
	for i in POSES.size():
		if POSES[i][0] != arme:
			arme = POSES[i][0]
			await _equiper(arme)
		mains._pose_figee = String(POSES[i][1])
		_texte("%s  (%s)" % [POSES[i][2], POSES[i][1]])
		await _attendre(0.25)
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join("pose_%02d_%s.png" % [i, String(POSES[i][1]).replace(":", "_")]))
		imgs.append(img)
	mains._pose_figee = ""
	var w := imgs[0].get_width() / 2
	var h := imgs[0].get_height() / 2
	var col := 4
	var planche := Image.create(w * col, h * ceili(imgs.size() / float(col)), false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im := imgs[i]
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
	planche.save_png(dossier.path_join("planche_poses.png"))
	print("PLANCHE ", dossier.path_join("planche_poses.png"))
