extends SceneTree
## Film + MESURES des coups d'épée à la 3e personne (branche tps/coups_propres, 2026-11-12 ; retour utilisateur : « en vue 3e
## personne, à l'épée, les mouvements ne se terminent pas, on dirait un enchaînement de convulsions »).
## Même séquence d'entrées pour l'AVANT et l'APRÈS (le script ne cite rien de propre à la correction) :
##   1 arrêt, clics espacés (combo 1-2-3-4)   2 arrêt, clics répétés (spam)   3 marche, clics espacés   4 marche, spam
##   5 coup puissant à l'arrêt   [+ claymore et hache avec --seulement=...,claymore,hache]
## Mesures (pose FINALE, après tous les modificateurs : accroches BoneAttachment3D) par segment : vitesse angulaire des os du bras
## droit et du buste (°/image à 60 i/s), « à-coups » = variation de la vitesse angulaire d'une image à l'autre (°/image²), sauts de
## pose, va-et-vient (le mouvement repart en sens inverse), pointe de l'arme (accélération), et part de chaque geste réellement
## jouée avant d'être quittée (« gestes interrompus »).
##   godot --path . --fixed-fps 60 [--headless] [--write-movie f.avi --resolution 960x540] --script res://outils/film_coups_tps_propres.gd
##         -- --nouvelle [--titre=AVANT] [--camera=cote] [--mesures=C:/.../mesures.txt] [--seulement=espace,spam,marche_espace,marche_spam,puissant]
const DT := 1.0 / 60.0
const OS_SUIVIS := ["upperarm_r", "lowerarm_r", "hand_r", "spine_02", "spine_03", "neck_01", "upperarm_l"]
const SEUIL_ACOUP := 2.5     # °/image² : variation brutale de vitesse angulaire (convulsion)
const SEUIL_SAUT := 9.0      # °/image : saut de pose (si ce n'est pas la vitesse propre du geste)

var s: Node
var j: CharacterBody3D
var mains: Node3D
var corps: Node3D
var ct: Node
var sq: Skeleton3D
var l: Label
var _texte := ""
var _acc := {}        # os -> BoneAttachment3D
var _seg := ""
var _donnees := {}    # segment -> {os: [Quaternion]}, "_pointe": [Vector3], "_clips": [String], "_tsrc": [float]
var _ordre: Array[String] = []
var _sortie := []     # lignes du rapport
var _cam: Camera3D    # --camera=cote : caméra libre de côté qui suit le joueur

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _image() -> void:
	j.vigueur = j.vigueur_max
	if _cam != null:
		# de côté (côté droit du joueur), à 4,2 m, suit le joueur sans tourner avec lui
		var centre := j.global_position + Vector3(0, 1.0, 0)
		_cam.global_position = centre + Vector3(4.2, 0.6, 0.6)
		_cam.look_at(centre)
	var clip: String = mains.anim.reel(mains.anim.clip) if mains.anim.clip != "" else ""
	l.text = "%s — %s   [%s]" % [_arg("titre", ""), _texte, clip]
	await process_frame
	if _seg == "":
		return
	var d: Dictionary = _donnees[_seg]
	var base := sq.global_basis.orthonormalized().inverse()
	for n in _acc:
		(d[n] as Array).append((base * (_acc[n] as Node3D).global_basis.orthonormalized()).get_rotation_quaternion())
	(d["_pointe"] as Array).append(sq.global_transform.affine_inverse() * _pointe())
	(d["_clips"] as Array).append(String(ct.get("_clip")))
	(d["_tsrc"] as Array).append(float(ct.get("_t_src")))
	(d["_poids"] as Array).append(float(ct.call("poids_geste")))

func _attendre(sec: float) -> void:
	for i in roundi(sec / DT):
		await _image()

func _pointe() -> Vector3:
	var m: Node3D = ct.call("modele_arme")
	if m == null:
		return (_acc["hand_r"] as Node3D).global_position
	var aabb := AABB()
	var premier := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		aabb = mi.get_aabb() if premier else aabb.merge(mi.get_aabb())
		premier = false
	return m.global_transform * Vector3(0.0, aabb.end.y, 0.0)

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 500)
	calque.add_child(l)

func _debut(nom: String, texte: String, marche: bool) -> void:
	_texte = texte
	s.placer_joueur(Vector3(0.0, 0.0, 12.0) if marche else Vector3(0.0, 0.0, 4.0), 0.0, -6.0)
	j.camera_tp.recaler()
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	if marche:
		Input.action_press("avant")
	await _attendre(0.6)
	_seg = nom
	_ordre.append(nom)
	_donnees[nom] = {"_pointe": [], "_clips": [], "_tsrc": [], "_poids": []}
	for n in _acc:
		_donnees[nom][n] = []

func _fin_segment(apres := 1.0) -> void:
	await _attendre(apres)
	Input.action_release("avant")
	_seg = ""
	await _attendre(0.3)

func _clics(n: int, intervalle: float) -> void:
	for k in n:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(intervalle - 0.05)

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if id != "" else Equipement.new().main_droite)
	await _attendre(0.8)

func _go() -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	corps = j.corps
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-16.0, 0.0, -16.0)
	_etiquette(s)
	j.basculer_vue(true)
	if _arg("camera", "") == "cote":
		_cam = Camera3D.new()
		_cam.fov = 50.0
		s.add_child(_cam)
		_cam.current = true
	await _attendre(0.5)
	ct = corps.coups_tps
	sq = corps.modele.find_child("Skeleton3D", true, false)
	for n in OS_SUIVIS:
		if sq.find_bone(n) >= 0:
			var b := BoneAttachment3D.new()
			b.bone_name = n
			sq.add_child(b)
			_acc[n] = b
	await _attendre(0.3)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
	var parties := _arg("seulement", "espace,spam,marche_espace,marche_spam,puissant").split(",")
	for p in parties:
		match p:
			"espace":
				await _debut("arret_espace", "à l'arrêt, clics espacés (combo 1-2-3-4)", false)
				await _clics(4, 0.75)
				await _fin_segment()
			"spam":
				await _debut("arret_spam", "à l'arrêt, clics répétés", false)
				await _clics(26, 0.1)
				await _fin_segment()
			"marche_espace":
				await _debut("marche_espace", "en marchant, clics espacés", true)
				await _clics(4, 0.75)
				await _fin_segment(0.6)
			"marche_spam":
				await _debut("marche_spam", "en marchant, clics répétés", true)
				await _clics(26, 0.1)
				await _fin_segment(0.6)
			"puissant":
				await _debut("puissant", "coup puissant à l'arrêt", false)
				mains.entrees.appuyer()
				await _attendre(0.8)
				mains.entrees.relacher()
				await _fin_segment(1.2)
			"claymore":
				await _equiper("claymore")
				await _debut("claymore_spam", "claymore, clics répétés", false)
				await _clics(24, 0.1)
				await _fin_segment(1.2)
				await _debut("claymore_puissant", "claymore, coup puissant", false)
				mains.entrees.appuyer()
				await _attendre(0.8)
				mains.entrees.relacher()
				await _fin_segment(1.4)
				await _equiper("")
			"hache":
				await _equiper("hache_guerre")
				await _debut("hache_spam", "hache, clics répétés", false)
				await _clics(24, 0.1)
				await _fin_segment(1.2)
				await _equiper("masse_cloutee")
				await _debut("masse_spam", "masse, clics répétés", false)
				await _clics(24, 0.1)
				await _fin_segment(1.2)
				await _equiper("")
	print("FIN_SEQUENCE")
	_rapport()
	quit(0)

# --------------------------------------------------------------------------------------------- mesures

static func _vecteur(q: Quaternion) -> Vector3:
	# rotation q en vecteur axe * angle (degrés), angle dans [0, 180]
	if q.w < 0.0:
		q = -q
	var ang := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var ax := Vector3(q.x, q.y, q.z)
	if ax.length() < 1e-6:
		return Vector3.ZERO
	return ax.normalized() * rad_to_deg(ang)

func _rapport() -> void:
	var lignes: Array[String] = []
	lignes.append("== %s (60 i/s ; à-coup > %.1f °/image², saut > %.0f °/image) ==" % [_arg("titre", "?"), SEUIL_ACOUP, SEUIL_SAUT])
	var total_acoups := 0
	for seg in _ordre:
		var d: Dictionary = _donnees[seg]
		lignes.append("-- %s (%d images)" % [seg, (d["_clips"] as Array).size()])
		if _arg("detail", "") == seg:
			for k in range(1, (d["_clips"] as Array).size()):
				var t := ""
				for n in ["spine_03", "hand_r"]:
					t += " %s %5.1f" % [n, _vecteur((d[n][k] as Quaternion) * (d[n][k - 1] as Quaternion).inverse()).length()]
				print("DETAIL %3d %-14s t=%5.1f p=%.2f%s" % [k, d["_clips"][k], float(d["_tsrc"][k]) * 30.0, float(d["_poids"][k]), t])
		for n in _acc:
			var qs: Array = d[n]
			var v_prec := Vector3.ZERO
			var w_max := 0.0
			var a_max := 0.0
			var acoups := 0
			var sauts := 0
			var allers := 0
			var somme_a := 0.0
			for k in range(1, qs.size()):
				var dq: Quaternion = (qs[k] as Quaternion) * (qs[k - 1] as Quaternion).inverse()
				var v := _vecteur(dq)
				w_max = maxf(w_max, v.length())
				if v.length() > SEUIL_SAUT:
					sauts += 1
				if k >= 2:
					var a := (v - v_prec).length()
					somme_a += a
					a_max = maxf(a_max, a)
					if a > SEUIL_ACOUP:
						acoups += 1
					if v.length() > 1.0 and v_prec.length() > 1.0 and v.dot(v_prec) < -0.2 * v.length() * v_prec.length():
						allers += 1
				v_prec = v
			if n in ["upperarm_r", "lowerarm_r", "hand_r", "spine_03"]:
				total_acoups += acoups
			lignes.append("   %-11s vitesse max %5.1f °/i | à-coup max %5.1f °/i² moyen %4.2f | à-coups %3d | sauts %2d | va-et-vient %2d" % [n, w_max, a_max, somme_a / maxf(qs.size() - 2, 1), acoups, sauts, allers])
		# pointe de l'arme
		var pt: Array = d["_pointe"]
		var acc_max := 0.0
		var acc_pics := 0
		for k in range(2, pt.size()):
			var acc := ((pt[k] as Vector3) - 2.0 * (pt[k - 1] as Vector3) + (pt[k - 2] as Vector3)).length()
			acc_max = maxf(acc_max, acc)
			if acc > 0.035:
				acc_pics += 1
		lignes.append("   pointe : accélération max %.3f m/image² | pics > 0,035 : %d" % [acc_max, acc_pics])
		# gestes : part jouée de chaque geste avant d'être quitté
		lignes.append("   gestes : " + _gestes(d))
	lignes.append("TOTAL à-coups (bras droit + buste, tous segments) : %d" % total_acoups)
	for li in lignes:
		print(li)
	var f := _arg("mesures", "")
	if f != "":
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string("\n".join(lignes) + "\n")
		fa.close()

## Part jouée de chaque geste (image de capture atteinte / plage [début, fin] de CLIPS) ; journal du corps s'il en tient un.
func _gestes(d: Dictionary) -> String:
	var clips: Array = d["_clips"]
	var ts: Array = d["_tsrc"]
	var morceaux: Array[String] = []
	var tab: Dictionary = (ct.get_script() as GDScript).get_script_constant_map()["CLIPS"]
	var k := 0
	while k < clips.size():
		var c: String = clips[k]
		var e := k
		while e + 1 < clips.size() and clips[e + 1] == c:
			e += 1
		if c != "" and tab.has(c):
			var im: Array = tab[c]["im"]
			var a := float(im[0])
			var b := float(im[im.size() - 1])
			var atteinte := float(ts[e]) * 30.0
			# le corps peut finir le geste après la fin du clip FPS (couche sortante) : son journal le dit
			var jr = ct.get("journal")
			if jr is Array:
				for x: Dictionary in jr:
					if x.get("clip", "") == c and absf(float(x.get("debut_image", -1)) - float(k)) < 0.5:
						atteinte = maxf(atteinte, float(x.get("image", atteinte)))
			morceaux.append("%s %d%%" % [c.replace("coup_", ""), roundi(100.0 * clampf((atteinte - a) / maxf(b - a, 1.0), 0.0, 1.0))])
		k = e + 1
	return ", ".join(morceaux)
