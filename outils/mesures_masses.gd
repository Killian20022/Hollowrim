extends SceneTree
## MASSES ET MARTEAUX PAR CAPTURES (branche combat/coups_masses_marteaux ; outil repris de combat/hache_captures) : MESURES des
## critères du brief 2026-11-26 (poignet, manche / avant-bras, tête dans le cadre, timing), dans le jeu
## (mains.gd, machine à états, clips, couche passive), SANS FENÊTRE, pas imposé de 1/60 s (mains.pas_manuel).
##   godot --headless --path . --script res://outils/mesures_masses.gd -- --nouvelle [--masses-anciennes]
##         [--arme=masse_cloutee] [--csv=C:\\...\\criteres.csv] [--etiquette=avant|apres] [--seq=combo,puissant] [--detail]
## Séquences : combo 1, 2, 3, 1 (un clic toutes les 0,8 s, comme les films), coup puissant (maintenu 0,9 s). Par CLIP joué :
##   poignet  : flexion / déviation du poignet droit (pose affichée, après tous les modificateurs ; même calcul que
##              mesures_coups_v5.gd), max |f| / |d|, plus grande variation d'une image à l'autre (cassure = poignet qui claque) ;
##   fil      : angle entre le FIL du fer (+X du modèle, ramené dans le plan perpendiculaire au manche) et le mouvement de la
##              tête (point à 92 % garde -> pointe) pendant la frappe : 0° = le fil mène, 90° = le plat, 180° = le dos mène ;
##   course   : course de la tête à l'écran (x et y, % de l'écran 480 × 270) pendant le clip (coups amples bord à bord) ;
##   visible  : images où la tête OU le manche (milieu) est dans le cadre / images du clip (arme toujours visible) ;
##   axe      : angle manche / avant-bras droit (max, pendant la frappe) — « manche dans l'axe de l'avant-bras » ;
##   acoups   : accélération max de la tête à l'écran hors frappe, tête dans le cadre (px/image²) ; saut au changement de clip (px) ;
##   camera   : rotation max de la caméra par rapport à la tête du joueur (°) et sa variation max par image ;
##   trace    : écart (cm) entre la tête VUE (modèle affiché) et la tête du TRACÉ de détection (pose_arme du clip) en frappe.
## Lignes « MASSES ... » ; « MASSES_RESUME » à la fin.
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const ORIGINE := Vector3(-12.0, 0.0, 6.0)

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var etiq := "x"
var _att := {}
var _fil_signe := 1.0   # +1 : le fil est du côté +X du modèle (lu sur la géométrie du fer)

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _images(n: int) -> void:
	for i in n:
		j.vigueur = j.vigueur_max
		mains.avancer(DT)
		await process_frame

func _ecran(p_local: Vector3) -> Vector3:
	var p := mains.transform * p_local
	var z := maxf(-p.z, 0.05)
	return Vector3(p.x / z / ProfilsAnimation.TAN_H * 240.0, -p.y / z / ProfilsAnimation.TAN_V * 135.0, -p.z)

func _attaches() -> void:
	var sq: Skeleton3D = mains._sq
	for o in ["lowerarm_r", "hand_r", "index_01_r", "pinky_01_r", "lowerarm_l", "hand_l", "index_01_l", "pinky_01_l"]:
		var b := BoneAttachment3D.new()
		b.bone_name = o
		sq.add_child(b)
		_att[o] = b

func _poignet(c := "r") -> Vector2:
	var coude: Vector3 = _att["lowerarm_" + c].global_position
	var p: Vector3 = _att["hand_" + c].global_position
	var ix: Vector3 = _att["index_01_" + c].global_position
	var au: Vector3 = _att["pinky_01_" + c].global_position
	var a := (p - coude).normalized()
	var h := ((ix + au) * 0.5 - p).normalized()
	var x := ix - au
	var e2 := (x - a * x.dot(a)).normalized()
	var e3 := a.cross(e2)
	return Vector2(rad_to_deg(atan2(h.dot(e3), h.dot(a))), rad_to_deg(atan2(h.dot(e2), h.dot(a))))

## Côté du fil : le fer s'étend surtout du côté +X ou -X du manche (sommets du modèle au-delà de 70 % de la longueur).
func _cote_fil() -> float:
	var m: Node3D = mains._modele_arme_d
	var inv := m.global_transform.affine_inverse()
	var pos := 0.0
	var neg := 0.0
	var y_min: float = mains._garde_lame.y + (mains._pointe_lame.y - mains._garde_lame.y) * 0.7
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf := inv * (mi as MeshInstance3D).global_transform
		for v: Vector3 in mesh.get_faces():
			var q: Vector3 = xf * v   # repère du modèle (comme les repères garde / pointe)
			if q.y >= y_min:
				pos = maxf(pos, q.x)
				neg = maxf(neg, -q.x)
	print("MASSES %s garde %s pointe %s modele %s" % [etiq, mains._garde_lame, mains._pointe_lame, m.transform])
	print("MASSES %s fer : etendue +X %.3f m, -X %.3f m -> fil du cote %s" % [etiq, pos, neg, "+X" if pos >= neg else "-X"])
	return 1.0 if pos >= neg else -1.0

func _echantillon(t: float) -> Dictionary:
	var pe: Transform3D = mains.pivot_epee.transform
	var tete_l: Vector3 = mains._garde_lame.lerp(mains._pointe_lame, 0.92)
	var milieu_l: Vector3 = mains._garde_lame.lerp(mains._pointe_lame, 0.5)
	var sq: Skeleton3D = mains._sq
	var th := sq.get_bone_global_pose(sq.find_bone("hand_r"))
	var tl := sq.get_bone_global_pose(sq.find_bone("lowerarm_r"))
	var inv: Transform3D = mains.global_transform.affine_inverse()
	var fa: Vector3 = (inv.basis * (sq.global_transform.basis * (th.origin - tl.origin))).normalized()
	var mt: Transform3D = inv * mains._modele_arme_d.global_transform
	var d := {"t": t, "etat": int(mains.combat.etat), "clip": String(mains.anim.clip), "tc": float(mains.anim.t), "w": _poignet(), "wl": _poignet("l"),
		"e": _ecran(pe * tete_l), "em": _ecran(pe * milieu_l), "m3": mt * tete_l, "ax": mt.basis.y.normalized(), "fx": mt.basis.x.normalized() * _fil_signe,
		"fa": fa, "actif": mains._actif_lance and mains.combat.etat in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE]}
	# caméra : rotation par rapport à la tête du joueur
	var rc: Basis = j.tete.global_transform.basis.orthonormalized().inverse() * j.camera.global_transform.basis.orthonormalized()
	d["cam"] = rad_to_deg(rc.get_rotation_quaternion().get_angle())
	d["camq"] = rc.get_rotation_quaternion()
	# tracé : tête du tracé de détection (pose du clip, comme mains._tracer) contre tête affichée, repère monde
	if d["actif"] and mains._clip != "":
		var xf: Transform3D = mains._transform_monde() * mains._couche() * mains.anim.pose_arme(mains._clip, mains.anim.t)
		_n_trace += 1
		d["trace_cm"] = (xf * tete_l).distance_to(mains.pivot_epee.global_transform * tete_l) * 100.0
	return d

func _remettre() -> void:
	s.placer_joueur(ORIGINE, 0.0, 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	await _images(50)

## clics = [[instant, maintien], ...] ; s'arrête au retour au repos.
func _sequence(nom: String, clics: Array) -> Array:
	await _remettre()
	var ech: Array = []
	var t := 0.0
	var k := 0
	var tenu := -1.0
	var vu := false
	var clips_lances: Array[String] = []
	while t < 10.0:
		if k < clics.size() and tenu < 0.0 and t >= float(clics[k][0]) - 1e-6:
			mains.entrees.appuyer()
			tenu = t + float(clics[k][1])
			k += 1
		if tenu >= 0.0 and t >= tenu - 1e-6:
			mains.entrees.relacher()
			tenu = -1.0
		await _images(1)
		t += DT
		var e: int = mains.combat.etat
		if e in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CHARGE_LOURDE]:
			vu = true
			if clips_lances.is_empty() or clips_lances[-1] != mains._clip:
				clips_lances.append(mains._clip)
		ech.append(_echantillon(t))
		if vu and k >= clics.size() and tenu < 0.0 and mains.combat.calme():
			break
	for i in 20:
		await _images(1)
		t += DT
		ech.append(_echantillon(t))
	print("MASSES %s %s clips lances : %s" % [etiq, nom, ", ".join(clips_lances)])
	_resume[nom + "_clips"] = clips_lances
	return ech

var _resume := {}
var _csv: Array[String] = []
var _n_trace := 0

func _analyser(nom: String, ech: Array) -> void:
	# segments par clip
	var segs: Array = []
	for i in ech.size():
		var c: String = ech[i]["clip"]
		if segs.is_empty() or segs[-1][0] != c:
			segs.append([c, i, i])
		segs[-1][2] = i
	var sauts := 0.0
	for si in range(1, segs.size()):
		var i: int = segs[si][1]
		if i >= 2 and i < ech.size() - 1:
			# saut au raccord : écart de la tête à l'image du raccord par rapport à la prolongation des deux images d'avant
			var pred: Vector3 = ech[i - 1]["e"] * 2.0 - ech[i - 2]["e"]
			sauts = maxf(sauts, Vector2(ech[i]["e"].x - pred.x, ech[i]["e"].y - pred.y).length())
	var cam_max := 0.0
	var cam_var := 0.0
	for i in ech.size():
		cam_max = maxf(cam_max, ech[i]["cam"])
		if i > 0:
			cam_var = maxf(cam_var, rad_to_deg((ech[i]["camq"] as Quaternion).angle_to(ech[i - 1]["camq"])))
	for sg in segs:
		var c: String = sg[0]
		if c == "" or c == "repos":
			continue
		var wf := 0.0
		var wd := 0.0
		var wvar := 0.0
		var lf := 0.0
		var ld := 0.0
		var lvar := 0.0
		var axe_min := INF
		var axe_max := 0.0
		var fils: Array[float] = []
		var xr := Vector2(INF, -INF)
		var yr := Vector2(INF, -INF)
		var vis := 0
		var tot := 0
		var axe := 0.0
		var acc := 0.0
		var tr := 0.0
		var lignes := []
		for i in range(maxi(sg[1], 1), mini(sg[2], ech.size() - 2) + 1):
			var e: Dictionary = ech[i]
			var w: Vector2 = e["w"]
			wf = maxf(wf, absf(w.x))
			wd = maxf(wd, absf(w.y))
			wvar = maxf(wvar, (w - (ech[i - 1]["w"] as Vector2)).length())
			if mains.arme.deux_mains:
				var wl: Vector2 = e["wl"]
				lf = maxf(lf, absf(wl.x))
				ld = maxf(ld, absf(wl.y))
				lvar = maxf(lvar, (wl - (ech[i - 1]["wl"] as Vector2)).length())
			var a_ma := rad_to_deg((e["ax"] as Vector3).angle_to(e["fa"]))
			axe_min = minf(axe_min, a_ma)
			axe_max = maxf(axe_max, a_ma)
			var p: Vector3 = e["e"]
			var pm: Vector3 = e["em"]
			tot += 1
			var dans := func(q: Vector3) -> bool: return q.z > 0.08 and absf(q.x) < 240.0 and absf(q.y) < 135.0
			if dans.call(p) or dans.call(pm):
				vis += 1
			if p.z > 0.08:
				xr = Vector2(minf(xr.x, p.x), maxf(xr.y, p.x))
				yr = Vector2(minf(yr.x, p.y), maxf(yr.y, p.y))
			var ac := Vector2(ech[i + 1]["e"].x - 2.0 * p.x + ech[i - 1]["e"].x, ech[i + 1]["e"].y - 2.0 * p.y + ech[i - 1]["e"].y).length()
			if not e["actif"] and dans.call(p) and dans.call(ech[i - 1]["e"]) and dans.call(ech[i + 1]["e"]):   # à l'image seulement
				acc = maxf(acc, ac)
			var v: Vector3 = ech[i + 1]["m3"] - ech[i - 1]["m3"]
			var ax: Vector3 = e["ax"]
			v = v - ax * v.dot(ax)
			var fx: Vector3 = e["fx"]
			fx = (fx - ax * fx.dot(ax)).normalized()
			var fil := rad_to_deg(fx.angle_to(v.normalized())) if v.length() > 0.004 else -1.0
			if e["actif"]:
				axe = maxf(axe, rad_to_deg(ax.angle_to(e["fa"])))
				if fil >= 0.0:
					fils.append(fil)
				tr = maxf(tr, float(e.get("trace_cm", 0.0)))
			lignes.append("%.2f%s[%.3f]:w(%.0f,%.0f)fil%.0f" % [e["t"], "*" if e["actif"] else "", e["tc"], w.x, w.y, fil])
		var fm := 0.0
		var fx_ := 0.0
		for a in fils:
			fm += a
			fx_ = maxf(fx_, a)
		fm /= maxf(fils.size(), 1)
		print("MASSES %s %-9s %-10s poignet max |f| %.0f |d| %.0f var %.1f deg/img | fil moy %.0f max %.0f deg (%d img) | course x %.0f %% y %.0f %% | visible %d/%d | manche/avant-bras max %.0f deg | acoups %.1f px/img2 | trace-fer %.1f cm" % [
			etiq, nom, c, wf, wd, wvar, fm, fx_, fils.size(), 100.0 * (xr.y - xr.x) / 480.0, 100.0 * (yr.y - yr.x) / 270.0, vis, tot, axe, acc, tr])
		var m: Dictionary = mains.anim.marqueurs(c) if mains.anim.existe(c) else {}
		var v := maxf(mains.arme.vitesse, 0.05)
		var anticip := float(m.get("frappe", 0.0)) / v
		var frappe := (float(m.get("fin_frappe", 0.0)) - float(m.get("frappe", 0.0))) / v
		var retour := (float(m.get("fin", 0.0)) - float(m.get("fin_frappe", 0.0))) / v
		print("MASSES_CRITERES %s %s %s %s : poignet D |dev| %.0f (<=25) |flex| %.0f (<=60) saut %.1f (<=12) | G |dev| %.0f |flex| %.0f saut %.1f | manche/avant-bras %.0f..%.0f | tete visible %d/%d | anticipation %.2f s frappe %.2f s retour %.2f s" % [
			_id, etiq, nom, c, wd, wf, wvar, ld, lf, lvar, axe_min, axe_max, vis, tot, anticip, frappe, retour])
		_csv.append("%s;%s;%s;%s;%.1f;%.1f;%.1f;%.1f;%.1f;%.1f;%.0f;%.0f;%d;%d;%.2f;%.2f;%.2f;%.0f;%.0f" % [
			_id, etiq, nom, c, wd, wf, wvar, ld, lf, lvar, axe_min, axe_max, vis, tot, anticip, frappe, retour,
			100.0 * (xr.y - xr.x) / 480.0, 100.0 * (yr.y - yr.x) / 270.0])
		if _arg("detail") != "":
			print("MASSES_DETAIL %s %s : %s" % [nom, c, " ".join(lignes)])
	print("MASSES %s %-9s raccords : saut max %.1f px | camera rotation max %.2f deg, variation max %.2f deg/img" % [etiq, nom, sauts, cam_max, cam_var])

var _id := ""

func _mesurer_arme(id_variante: String) -> void:
	# « arme@écart@rotation » : variante de la prise gauche (écart des mains, rotation de la main gauche autour du manche), essais
	var parts := id_variante.split("@")
	var id := parts[0]
	var donnees: DonneesArme = CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else load("res://data/armes/%s.tres" % id)
	if parts.size() > 1:
		donnees = donnees.duplicate()
		donnees.ecart_mains = float(parts[1])
		if parts.size() > 2:
			donnees.rotation_main_gauche = float(parts[2])
		print("MASSES variante %s : ecart %.2f rotation gauche %.0f fusee_bas %.2f" % [id_variante, donnees.ecart_mains, donnees.rotation_main_gauche, donnees.fusee_bas])
	mains.equipement.equiper("droite", donnees)
	await _images(60)
	if _att.is_empty():
		_attaches()
	await _images(2)
	_fil_signe = _cote_fil()
	var p := ProfilsAnimation.profil(mains.arme.profil)
	print("MASSES %s arme %s profil %s combo %s lourd %s (anciennes %s)" % [etiq, id, mains.arme.profil, str(p["combo"]), p["lourd"], str(GestesLourds.masses_anciennes)])
	var seqs := _arg("seq", "combo,puissant").split(",")
	if "combo" in seqs:
		var e := await _sequence("combo", [[0.0, 0.05], [0.8, 0.05], [1.6, 0.05], [2.4, 0.05]])
		_analyser("combo", e)
	if "rapide" in seqs:
		var e := await _sequence("rapide", [[0.0, 0.05], [0.45, 0.05], [0.9, 0.05], [1.35, 0.05]])
		_analyser("rapide", e)
	if "puissant" in seqs:
		var e := await _sequence("puissant", [[0.0, 0.9]])
		_analyser("puissant", e)


func _go() -> void:
	etiq = _arg("etiquette", "avant" if GestesLourds.masses_anciennes else "apres")
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	if s.get("mannequin") != null:
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
		s.mannequin.global_position = Vector3(40, 0, 40)
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	for id in _arg("armes", _arg("arme", "masse_cloutee")).split(","):
		_id = id
		await _mesurer_arme(id)
	print("MASSES %s echantillons du trace compares : %d" % [etiq, _n_trace])
	var chemin := _arg("csv")
	if chemin != "":
		var neuf := not FileAccess.file_exists(chemin)
		var f := FileAccess.open(chemin, FileAccess.READ_WRITE if not neuf else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			if neuf:
				f.store_line("arme;version;sequence;clip;poignet_d_dev_max;poignet_d_flex_max;poignet_d_saut_max;poignet_g_dev_max;poignet_g_flex_max;poignet_g_saut_max;manche_avantbras_min;manche_avantbras_max;tete_visible;images;anticipation_s;frappe_s;retour_s;course_x_pct;course_y_pct")
			for l in _csv:
				f.store_line(l)
			f.close()
	print("FIN_MASSES")
	quit(0)
