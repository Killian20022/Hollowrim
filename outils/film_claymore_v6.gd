extends SceneTree
## Claymore v6 (branche combat/claymore_v6) : FILM 1re personne, d'après outils/film_claymore_v5.gd (même séquence d'entrées), pour
## comparer v4 / v6. Ajouts : --fps=<n> (même valeur que --fixed-fps : à 240, le film lu à 60 i/s est un VRAI ralenti × 0,25,
## une image de jeu tous les 1/240 s) et --gros-plan (caméra posée à côté du poignet droit, qui le suit : flexion / déviation de la
## main par rapport à l'avant-bras visibles de profil).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   film    : godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --audio-driver Dummy
##             --script res://outils/film_claymore_v5.gd -- --nouvelle --film --etiquette=<texte>
##             repos 0,6 s, combo complet enchaîné au plus tôt (un clic gardé en tampon par coup, comme un joueur qui clique vite),
##             pause, coup puissant (maintenu 0,9 s), retour au repos. Même séquence d'entrées avant / après.
##   planche : godot --path . --resolution 960x540 --audio-driver Dummy --script res://outils/film_claymore_v5.gd --
##             --nouvelle --planche --sortie=<dossier> --etiquette=<texte>
##             par coup (diagonale, revers, vertical, puissante) : armé, frappe (milieu), fin de frappe, suivi, fin du clip ;
##             + repos, garde, charge tenue. → <dossier>/<etiquette>_planche_poses.png (5 colonnes).
var DT := 1.0 / 60.0

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
	DT = 1.0 / float(_arg("fps", "60"))
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
	mains.equipement.equiper("droite", CatalogueArmes.donnees(_arg("arme", "claymore")))
	await _attendre(1.2)
	if _arg("planche") != "":
		await _planche()
	if _arg("gros-plan") != "":
		_installer_gros_plan()
	if _arg("vue-derriere") != "":
		_installer_vue_derriere(_arg("vue-derriere"))
	if _arg("film") != "":
		await _film()
	print("FIN_FILM_V6")
	quit(0)

func _film() -> void:
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	_texte("%s : garde" % etiq)
	await _attendre(0.6)
	if _arg("coup2") != "":
		# coup 2 du combo (gauche -> droite) joué SEUL depuis la tenue, puis pause
		_texte("%s : coup 2 seul" % etiq)
		mains._combo = 1
		mains._depuis_coup = 0.0
		mains.entrees.appuyer()
		await process_frame
		mains.entrees.relacher()
		var tc := 0.0
		while tc < 4.0 and not (tc > 0.3 and mains.combat.calme()):
			await process_frame
			j.vigueur = j.vigueur_max
			tc += DT
		print("FILM coup2 %.2f s" % tc)
		await _attendre(0.8)
		mains._depuis_coup = 9.0
		mains._combo = 0
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

var _cam_gp: Camera3D

## Caméra de gros plan : à 50 cm du poignet droit, sur le côté extérieur (droite) et en avant (repère de la caméra du joueur),
## visée sur le poignet ; suit la main à chaque image (après les mains : priorité de traitement basse).
func _installer_gros_plan() -> void:
	_cam_gp = Camera3D.new()
	_cam_gp.fov = 40.0 if _arg("gros-plan") != "2" else 55.0
	_cam_gp.near = 0.01
	s.add_child(_cam_gp)
	_cam_gp.current = true
	if _arg("gros-plan") == "2":
		# les DEUX poignets, vus de face (devant les mains, un peu en dessous), éclairés par une lampe posée sur la caméra
		var l1 := OmniLight3D.new()
		l1.light_energy = 2.5
		l1.omni_range = 3.0
		l1.light_cull_mask = 0xFFFFFFFF
		l1.shadow_enabled = false
		_cam_gp.add_child(l1)
		l1.position = Vector3(0.15, 0.25, 0.0)
		var l2 := OmniLight3D.new()
		l2.light_energy = 1.2
		l2.omni_range = 3.0
		l2.light_cull_mask = 0xFFFFFFFF
		_cam_gp.add_child(l2)
		l2.position = Vector3(-0.3, -0.1, 0.1)
		process_frame.connect(_suivre_deux_poignets)
		return
	process_frame.connect(_suivre_gros_plan)

## --vue-derriere=d|g : 1re personne VUE DE DOS — caméra 0,6 m derrière la tête du joueur, 0,25 m au-dessus, décalée de 0,2 m
## vers l'épaule droite (d) ou gauche (g), qui regarde dans la même direction que la caméra du joueur (inclinée de 20° vers le bas) ; deux lampes (bras lisibles).
var _cote_derriere := 1.0

func _installer_vue_derriere(cote: String) -> void:
	_cote_derriere = -1.0 if cote == "g" else 1.0
	_cam_gp = Camera3D.new()
	_cam_gp.fov = 55.0
	_cam_gp.near = 0.02
	s.add_child(_cam_gp)
	_cam_gp.current = true
	for r in [[Vector3(0.3 * _cote_derriere, 0.4, 0.2), 2.2], [Vector3(-0.3 * _cote_derriere, 0.0, -0.6), 1.2]]:
		var l := OmniLight3D.new()
		l.light_energy = r[1]
		l.omni_range = 4.0
		l.light_cull_mask = 0xFFFFFFFF
		_cam_gp.add_child(l)
		l.position = r[0]
	process_frame.connect(_suivre_derriere)

func _suivre_derriere() -> void:
	# même direction que la caméra du joueur, inclinée de 20° vers le bas : les bras (sous la caméra) restent dans le cadre
	var t: Transform3D = j.camera.global_transform
	var b := t.basis * Basis(Vector3.RIGHT, deg_to_rad(-20.0))
	_cam_gp.global_transform = Transform3D(b, t.origin + t.basis.z * 0.6 + t.basis.y * 0.25 + t.basis.x * 0.2 * _cote_derriere)

func _suivre_deux_poignets() -> void:
	var sq: Skeleton3D = mains._sq
	var pd: Vector3 = mains._accroche_d.global_position
	var pg: Vector3 = mains._accroche_g.global_position
	var vise := (pd + pg) * 0.5
	var b: Basis = j.camera.global_transform.basis
	# devant les mains (vers ce que regarde le joueur), un peu sur la droite et en dessous : on voit l'intérieur des deux poignets
	var pos := vise - b.z * 0.55 + b.x * 0.12 - b.y * 0.08
	_cam_gp.global_position = pos
	_cam_gp.look_at(vise, b.y)

func _suivre_gros_plan() -> void:
	var sq: Skeleton3D = mains._sq
	var ih := sq.find_bone("hand_r")
	var il := sq.find_bone("lowerarm_r")
	var poignet: Vector3 = sq.global_transform * sq.get_bone_global_pose(ih).origin
	var coude: Vector3 = sq.global_transform * sq.get_bone_global_pose(il).origin
	var b: Basis = j.camera.global_transform.basis
	var cote := (b.x * 1.0 - b.z * 0.45 + b.y * 0.1).normalized()
	var vise := poignet.lerp(coude, 0.15)
	_cam_gp.global_position = vise + cote * 0.5
	_cam_gp.look_at(vise, b.y)

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
