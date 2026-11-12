extends SceneTree
## Claymore v5 (branche combat/claymore_v5) : FILM 1re personne et PLANCHE des poses clés, pour comparer avant (v4) / après (v5).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   film    : godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --audio-driver Dummy
##             --script res://outils/film_claymore_v5.gd -- --nouvelle --film --etiquette=<texte>
##             repos 0,6 s, combo complet enchaîné au plus tôt (un clic gardé en tampon par coup, comme un joueur qui clique vite),
##             pause, coup puissant (maintenu 0,9 s), retour au repos. Même séquence d'entrées avant / après.
##   planche : godot --path . --resolution 960x540 --audio-driver Dummy --script res://outils/film_claymore_v5.gd --
##             --nouvelle --planche --sortie=<dossier> --etiquette=<texte>
##             par coup (diagonale, revers, vertical, puissante) : armé, frappe (milieu), fin de frappe, suivi, fin du clip ;
##             + repos, garde, charge tenue. → <dossier>/<etiquette>_planche_poses.png (5 colonnes).
const DT := 1.0 / 60.0

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var etiq := ""

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
		await process_frame

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _go() -> void:
	RetourImpact.muet = true
	etiq = _arg("etiquette", "")
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("hud") != null:
		s.hud.visible = false
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(12, 500)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	await _attendre(0.5)
	mains.equipement.equiper("droite", CatalogueArmes.donnees("claymore"))
	await _attendre(1.2)
	if _arg("planche") != "":
		await _planche()
	if _arg("film") != "":
		await _film()
	print("FIN_FILM_V5")
	quit(0)

func _film() -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	_texte("%s : garde" % etiq)
	await _attendre(0.6)
	_texte("%s : combo complet (clics au plus tôt)" % etiq)
	var n: int = ProfilsAnimation.profil(mains.arme.profil)["combo"].size()
	var clics := 0
	var lances := 0
	var t_lance := -9.0
	var t := 0.0
	var prec: int = mains.combat.etat
	while t < 8.0:
		if clics < n and (clics == 0 or (mains.combat.etat == EtatCombat.ATTAQUE_LEGERE and t - t_lance > 0.1 and clics <= lances and mains.entrees.tampon < 0.0)):
			mains.entrees.appuyer()
			clics += 1
			await process_frame
			t += DT
			mains.entrees.relacher()
		await process_frame
		j.vigueur = j.vigueur_max
		t += DT
		var e: int = mains.combat.etat
		if e == EtatCombat.ATTAQUE_LEGERE and prec != EtatCombat.ATTAQUE_LEGERE:
			lances += 1
			t_lance = t
		prec = e
		if clics >= n and t - t_lance > 0.2 and mains.combat.calme():
			break
	print("FILM combo %.2f s" % t)
	await _attendre(0.7)
	_texte("%s : coup puissant (maintenu 0,9 s)" % etiq)
	mains.entrees.appuyer()
	await _attendre(0.9)
	mains.entrees.relacher()
	t = 0.0
	while t < 5.0 and not (t > 0.3 and mains.combat.calme()):
		await process_frame
		j.vigueur = j.vigueur_max
		t += DT
	print("FILM puissant (apres relache) %.2f s" % t)
	_texte("%s : garde" % etiq)
	await _attendre(1.0)

func _capture() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _planche() -> void:
	var dossier := _arg("sortie", "res://captures/claymore_v5")
	DirAccess.make_dir_recursive_absolute(dossier)
	var poses: Array = [["", "repos"], ["garde", "garde"], ["charge_2m:%.3f" % (mains.anim.longueur("charge_2m") - 0.001), "puissante : charge tenue"], ["", ""], ["", ""]]
	for c in ["c2_a", "c2_b", "c2_c", "lourd_2m"]:
		var m: Dictionary = mains.anim.marqueurs(c)
		var nom: String = {"c2_a": "1 diagonale", "c2_b": "2 revers", "c2_c": "3 vertical", "lourd_2m": "puissante"}[c]
		var fr := float(m["frappe"])
		var ff := float(m["fin_frappe"])
		poses.append_array([["%s:%.3f" % [c, float(m["arme"])], "%s : armé %.2f" % [nom, float(m["arme"])]],
			["%s:%.3f" % [c, (fr + ff) * 0.5], "%s : frappe %.2f" % [nom, (fr + ff) * 0.5]],
			["%s:%.3f" % [c, ff], "%s : fin frappe %.2f" % [nom, ff]],
			["%s:%.3f" % [c, float(m["suivi"])], "%s : suivi %.2f" % [nom, float(m["suivi"])]],
			["%s:%.3f" % [c, float(m["fin"]) - 0.001], "%s : fin %.2f" % [nom, float(m["fin"])]]])
	var imgs: Array[Image] = []
	for p in poses:
		if p[1] == "":
			imgs.append(null)
			continue
		mains._pose_figee = ""
		if p[0] == "garde":
			mains.entrees.forcer_garde(0.9)
		else:
			mains._pose_figee = String(p[0])
		_texte("%s  %s" % [etiq, p[1]])
		await _attendre(0.45)
		imgs.append(_capture())
		await _attendre(0.5)
	mains._pose_figee = ""
	var w := 480
	var h := 270
	var col := 5
	var planche := Image.create(w * col, h * ceili(imgs.size() / float(col)), false, Image.FORMAT_RGBA8)
	planche.fill(Color(0.05, 0.05, 0.05))
	for i in imgs.size():
		if imgs[i] == null:
			continue
		var im := imgs[i]
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
	planche.save_png(dossier.path_join("%s_planche_poses.png" % etiq))
	print("PLANCHE ", dossier.path_join("%s_planche_poses.png" % etiq))
