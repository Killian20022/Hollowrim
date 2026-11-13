extends SceneTree
## Claymore v5 (branche combat/claymore_v5) : MESURE DE LA NETTETÉ des coups en vue 1re personne, épée à une main (référence,
## « epee_metal ») contre claymore (« claymore »), dans le jeu (mains.gd, machine à états, clips, couche passive).
## SANS FENÊTRE, pas imposé de 1/60 s (mains.pas_manuel) :
##   godot --headless --path . --script res://outils/mesures_coups_v5.gd -- --nouvelle [--etiquette=avant|apres]
##         [--csv=<dossier>]   (une ligne par image : t, état, clip, temps du clip, pointe / garde à l'écran, écart main gauche)
## Point suivi : la lame à 60 % de la garde vers la pointe (la pointe de la claymore passe au ras de la caméra à l'armé).
## Séquences : coup léger 1 seul (clic -> repos), combo complet enchaîné au plus tôt (un clic gardé en tampon par coup),
## coup puissant (maintenu 0,9 s). Pointe et garde de la lame projetées à l'écran (480 × 270 px, repère de la caméra du
## viewmodel, ProfilsAnimation.vers_ecran) ; lignes « MESURE5 ... » dans le log :
##   duree      : total (clic -> repos), phases (armé, tension, frappe, récupération) en s de jeu ;
##   vitesse    : pic de la pointe (px/s), part du trajet faite pendant la frappe (netteté : 1 = tout le mouvement est la frappe) ;
##   pics       : nombre de bosses de vitesse > 25 % du pic (un geste propre : 1 par coup ; plus = mouvement haché) ;
##   acoups     : accélération max de la pointe hors frappe (px/image²) : secousses de l'armé et du retour ;
##   saut       : plus grand saut de pose d'une image à l'autre (px/image) relatif aux deux images voisines (raccord cassé) ;
##   rebonds    : demi-tours de la pointe pendant la récupération (vitesse > 40 px/s) : retour qui rebondit ;
##   arrivee    : temps entre la fin du dernier clip et l'immobilité (pointe < 0,5 px/image), mouvement résiduel (px) ;
##   main_g     : écart du poing gauche à la poignée (cm), max et moyen (claymore).
##   poignet    : (ajout claymore v6) angle du poignet droit à chaque image, dans le jeu : angle entre l'axe de la main (os hand_r,
##                +Y) et l'axe de l'avant-bras (tête de lowerarm_r -> tête de hand_r), en degrés ; max sur le geste, max pendant la
##                frappe, plus grande variation d'une image à l'autre (poignet qui « claque »).
##   poignets   : (claymore v6, coup 2) flexion (+ extension, vers le dos de la main) et déviation (+ radiale, vers le pouce) des
##                poignets DROIT et GAUCHE, pose APRÈS les modificateurs (IK de la main gauche comprise) : BoneAttachment3D sur
##                lowerarm / hand / index_01 / pinky_01 ; même calcul que sur les captures (axe avant-bras, axe main = poignet ->
##                milieu index-auriculaire, côté pouce = auriculaire -> index). Max sur le geste, variation max à la tenue.
## --seq=leger,coup2,combo,puissant : séquences jouées (coup2 = le 2e coup du combo joué seul, depuis la tenue).
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const ORIGINE := Vector3(-12.0, 0.0, 6.0)
const NOMS_ETATS := ["repos", "mvt", "leger", "charge", "lourd", "garde", "parade", "deseq", "recup", "equiper", "contre", "finisher"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var etiq := "x"
var csv := ""

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

## Point du repère des mains -> pixels de l'écran 480 × 270 (origine au centre, y vers le bas). Profondeur bornée à 0,25 m : une
## pointe qui passe au ras de la caméra (armé au-dessus de la tête) ne s'envole pas à l'infini.
func _ecran(p_local: Vector3) -> Vector2:
	var p := mains.transform * p_local
	var z := maxf(-p.z, 0.25)
	return Vector2(p.x / z / ProfilsAnimation.TAN_H * 240.0, -p.y / z / ProfilsAnimation.TAN_V * 135.0)

var _att := {}

func _attaches() -> void:
	var sq: Skeleton3D = mains._sq
	print("MESURE5 squelette des bras : ", sq.get_path(), " os hand_l=", sq.find_bone("hand_l"), " index_01_l=", sq.find_bone("index_01_l"))
	for c in ["l", "r"]:
		for o in ["lowerarm", "hand", "index_01", "pinky_01"]:
			var b := BoneAttachment3D.new()
			b.bone_name = "%s_%s" % [o, c]
			sq.add_child(b)
			_att["%s_%s" % [o, c]] = b

## [flexion, déviation] (degrés) du poignet `c` (« r » / « l »), pose affichée.
func _poignet(c: String) -> Vector2:
	var coude: Vector3 = _att["lowerarm_" + c].global_position
	var p: Vector3 = _att["hand_" + c].global_position
	var ix: Vector3 = _att["index_01_" + c].global_position
	var au: Vector3 = _att["pinky_01_" + c].global_position
	var a := (p - coude).normalized()
	var h := ((ix + au) * 0.5 - p).normalized()
	var x := ix - au
	var e2 := (x - a * x.dot(a)).normalized()
	var e3 := a.cross(e2) if c == "r" else e2.cross(a)
	return Vector2(rad_to_deg(atan2(h.dot(e3), h.dot(a))), rad_to_deg(atan2(h.dot(e2), h.dot(a))))

func _echantillon(t: float) -> Dictionary:
	var pe: Transform3D = mains.pivot_epee.transform
	var sq: Skeleton3D = mains._sq
	var ih := sq.find_bone("hand_r")
	var il := sq.find_bone("lowerarm_r")
	var th := sq.get_bone_global_pose(ih)
	var axe_ab := (th.origin - sq.get_bone_global_pose(il).origin).normalized()
	var cass := rad_to_deg(acos(clampf(th.basis.y.normalized().dot(axe_ab), -1.0, 1.0)))
	var d := {"cass": cass, "wd": _poignet("r"), "wg": _poignet("l"), "t": t, "etat": int(mains.combat.etat), "clip": String(mains.anim.clip), "tc": float(mains.anim.t),
		"p": _ecran(pe * mains._garde_lame.lerp(mains._pointe_lame, 0.6)), "g": _ecran(pe * mains._garde_lame), "pp": _ecran(pe * mains._pointe_lame), "mg": -1.0}
	# claymore v6 (horizontaux) : lame AFFICHÉE (modèle tenu par la main, +Y lame, +X tranchant, +Z normale du plat) dans le
	# repère des mains (la caméra : l'élan du joueur n'entre pas dans la vitesse) ; épaule droite (tête de upperarm_r)
	if mains._modele_arme_d != null:
		var mt: Transform3D = mains.global_transform.affine_inverse() * mains._modele_arme_d.global_transform
		d["m3"] = mt * mains._garde_lame.lerp(mains._pointe_lame, 0.6)
		d["nz"] = mt.basis.z.normalized()
		d["ax"] = mt.basis.y.normalized()
		d["ep"] = mains.global_transform.affine_inverse() * (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("upperarm_r")).origin)
		d["fa"] = (mains.global_transform.affine_inverse().basis * (sq.global_transform.basis * (th.origin - sq.get_bone_global_pose(il).origin))).normalized()
	if mains.arme != null and mains.arme.deux_mains:
		var poing_g: Vector3 = mains._accroche_g.global_transform * mains.PRISE_G.origin
		var cible: Vector3 = mains.to_global(mains.pivot_torche.position)
		d["mg"] = poing_g.distance_to(cible) * 100.0
		var cam_inv: Transform3D = mains.global_transform.affine_inverse()
		d["pg"] = _ecran(mains.transform.affine_inverse() * (cam_inv * poing_g)) if false else Vector2.ZERO
		var ld: Vector3 = (cam_inv * poing_g)
		var lc: Vector3 = (cam_inv * cible)
		d["xg"] = "%.3f,%.3f,%.3f / %.3f,%.3f,%.3f" % [ld.x, ld.y, ld.z, lc.x, lc.y, lc.z]
	return d

func _remettre() -> void:
	s.placer_joueur(ORIGINE, 0.0, 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	await _images(50)

## Joue une séquence : `clics` = [[instant (s), maintien (s)], ...] ; ou « au plus tôt » (n clics, un par coup, dès que le coup
## précédent a commencé). S'arrête au retour au repos. Renvoie les échantillons (avec 10 images de repos avant).
func _sequence(nom: String, clics: Array, au_plus_tot := 0, combo_depart := 0) -> Array:
	await _remettre()
	if combo_depart > 0:
		mains._combo = combo_depart
		mains._depuis_coup = 0.0
	var ech: Array = []
	for i in 10:
		ech.append(_echantillon(-0.1667 + i * DT))
		await _images(1)
	var t := 0.0
	var k := 0
	var tenu := -1.0
	var n_clics := au_plus_tot if au_plus_tot > 0 else clics.size()
	var phases := []
	var prec := -1
	var vu_attaque := false
	var dernier_lancement := -9.0
	while t < 8.0:
		# appuis
		if k < n_clics and tenu < 0.0:
			var go := false
			var maintien := 0.05
			if au_plus_tot > 0:
				go = k == 0 or (mains.combat.etat in [EtatCombat.ATTAQUE_LEGERE] and t - dernier_lancement > 0.1 and mains.entrees.tampon < 0.0 and k <= _coups_lances)
			else:
				go = t >= float(clics[k][0]) - 1e-6
				maintien = float(clics[k][1])
			if go:
				mains.entrees.appuyer()
				tenu = t + maintien
				k += 1
		if tenu >= 0.0 and t >= tenu - 1e-6:
			mains.entrees.relacher()
			tenu = -1.0
		var e0: int = mains.combat.etat
		await _images(1)
		t += DT
		var e: int = mains.combat.etat
		if e in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE] and e0 not in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CHARGE_LOURDE]:
			_coups_lances += 1
			dernier_lancement = t
		if e != prec:
			phases.append("%.2f:%s" % [t, NOMS_ETATS[e] if e < NOMS_ETATS.size() else str(e)])
			prec = e
		if e in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CHARGE_LOURDE]:
			vu_attaque = true
		var d := _echantillon(t)
		d["actif"] = mains._actif_lance and e in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE]
		ech.append(d)
		if vu_attaque and k >= n_clics and tenu < 0.0 and mains.combat.calme():
			break
	# images de repos après (pour mesurer l'arrivée)
	for i in 30:
		await _images(1)
		t += DT
		var d := _echantillon(t)
		d["actif"] = false
		d["apres"] = true
		ech.append(d)
	print("MESURE5 %s %s phases %s" % [etiq, nom, " ".join(phases)])
	_coups_lances = 0
	return ech

var _coups_lances := 0

## Claymore v6, horizontaux : par CLIP joué (segments de la séquence), pendant la frappe (actif) : écart du FIL au mouvement =
## asin(|normale du plat · vitesse|) (0° = le tranchant mène, 90° = le plat balaie à plat), moyenne, max, part des images < 20° ;
## COURSE de la pointe à l'écran (x min -> max, en % de la largeur, sur tout le clip et pendant la frappe), hauteur pendant la
## frappe ; avancée de l'épaule droite (cm, repère caméra) ; rotation de la lame autour de la verticale (lacet, degrés).
func _tranche(nom: String, ech: Array) -> void:
	var segs: Array = []
	for i in ech.size():
		var c: String = ech[i]["clip"]
		if segs.is_empty() or segs[-1][0] != c:
			segs.append([c, i, i])
		segs[-1][2] = i
	for sg in segs:
		var c: String = sg[0]
		if not (c.begins_with("c2_") or c.begins_with("lourd") or c.begins_with("coup_")):
			continue
		var ecarts: Array[float] = []
		var xs := Vector2(INF, -INF)
		var xa := Vector2(INF, -INF)
		var ya := Vector2(INF, -INF)
		var ez := Vector2(INF, -INF)
		var lac := Vector2(INF, -INF)
		var lignes := []
		var ang_ab := 0.0
		for i in range(maxi(sg[1], 1), mini(sg[2], ech.size() - 2) + 1):
			var e: Dictionary = ech[i]
			if not e.has("m3"):
				continue
			var x: float = e["pp"].x
			xs = Vector2(minf(xs.x, x), maxf(xs.y, x))
			ez = Vector2(minf(ez.x, e["ep"].z), maxf(ez.y, e["ep"].z))
			var ax: Vector3 = e["ax"]
			var l := rad_to_deg(atan2(ax.x, -ax.z))
			lac = Vector2(minf(lac.x, l), maxf(lac.y, l))
			var v: Vector3 = ech[i + 1]["m3"] - ech[i - 1]["m3"]
			var ec := rad_to_deg(asin(clampf(absf(v.normalized().dot(e["nz"])), 0.0, 1.0))) if v.length() > 1e-4 else 0.0
			if e.get("actif", false):
				ecarts.append(ec)
				ang_ab += rad_to_deg((e["ax"] as Vector3).angle_to(e["fa"]))
				xa = Vector2(minf(xa.x, x), maxf(xa.y, x))
				ya = Vector2(minf(ya.x, e["p"].y), maxf(ya.y, e["p"].y))
			lignes.append("%.2f%s:%.0f" % [e["t"], "*" if e.get("actif", false) else "", ec])
		if ecarts.is_empty():
			continue
		var moy := 0.0
		var mx := 0.0
		var bons := 0
		for a in ecarts:
			moy += a
			mx = maxf(mx, a)
			bons += 1 if a < 20.0 else 0
		moy /= ecarts.size()
		print("MESURE5 %s %-22s TRANCHE %s : fil/mouvement pendant la frappe moy %.0f deg max %.0f deg, %d/%d images < 20 deg | course pointe x %.0f..%.0f px = %.0f %% de l'ecran (frappe %.0f..%.0f = %.0f %%), hauteur frappe y %.0f..%.0f | epaule droite avance %.1f cm | lacet lame %.0f..%.0f deg | angle lame / avant-bras droit %.0f deg" % [
			etiq, nom, c, moy, mx, bons, ecarts.size(), xs.x, xs.y, 100.0 * (xs.y - xs.x) / 480.0, xa.x, xa.y, 100.0 * (xa.y - xa.x) / 480.0, ya.x, ya.y, 100.0 * (ez.y - ez.x), lac.x, lac.y, ang_ab / ecarts.size()])
		print("MESURE5 %s %-22s FIL %s : %s" % [etiq, nom, c, " ".join(lignes)])

func _analyser(nom: String, ech: Array, n_coups: int) -> void:
	_tranche(nom, ech)
	var n := ech.size()
	var v: Array[float] = []
	var vv: Array[Vector2] = []
	for i in n:
		var dv: Vector2 = (ech[i]["p"] - ech[maxi(i - 1, 0)]["p"]) if i > 0 else Vector2.ZERO
		vv.append(dv)
		v.append(dv.length())
	# fin du geste = dernière image non « apres »
	var i_fin := 0
	var i_deb := -1
	for i in n:
		if not ech[i].get("apres", false):
			i_fin = i
		if i_deb < 0 and ech[i]["t"] > 0.0:
			i_deb = i
	var total := float(ech[i_fin]["t"])
	var chemin := 0.0
	var chemin_actif := 0.0
	var pic := 0.0
	var t_actif := 0.0
	for i in range(1, n):
		chemin += v[i]
		if ech[i].get("actif", false):
			chemin_actif += v[i]
			t_actif += DT
		pic = maxf(pic, v[i])
	# bosses de vitesse (lissage 3 images) : maxima locaux > 25 % du pic séparés par un creux < 60 % du plus petit des deux
	var vl: Array[float] = []
	for i in n:
		vl.append((v[maxi(i - 1, 0)] + v[i] + v[mini(i + 1, n - 1)]) / 3.0)
	var bosses := 0
	var haut := 0.0
	var creux := INF
	var en_bosse := false
	for i in n:
		var x := vl[i]
		if not en_bosse:
			creux = minf(creux, x)
			if x > 0.25 * pic and x > creux / 0.6:
				en_bosse = true
				haut = x
				bosses += 1
		else:
			haut = maxf(haut, x)
			if x < haut * 0.6:
				en_bosse = false
				creux = x
	# accélérations
	var acc_hors := 0.0
	var acc_hors_t := 0.0
	var saut := 0.0
	var saut_t := 0.0
	for i in range(1, n - 1):
		var a: Vector2 = vv[i + 1] - vv[i]
		var actif: bool = ech[i].get("actif", false) or ech[i + 1].get("actif", false) or ech[i - 1].get("actif", false)
		if not actif and a.length() > acc_hors:
			acc_hors = a.length()
			acc_hors_t = float(ech[i]["t"])
		# saut de pose : déplacement de l'image comparé à la moyenne de ses voisines
		var r := v[i] - 0.5 * (v[i - 1] + v[i + 1])
		if r > saut:
			saut = r
			saut_t = float(ech[i]["t"])
	# demi-tours pendant la récupération (hors frappe, vitesse > 40 px/s = 0,67 px/image)
	var rebonds := 0
	var dir_prec := Vector2.ZERO
	for i in range(1, n):
		if ech[i].get("actif", false) or int(ech[i]["etat"]) not in [EtatCombat.RECUPERATION, EtatCombat.REPOS, EtatCombat.MOUVEMENT]:
			dir_prec = Vector2.ZERO
			continue
		if v[i] < 0.67:
			continue
		var d := vv[i].normalized()
		if dir_prec != Vector2.ZERO and d.dot(dir_prec) < -0.3:
			rebonds += 1
		dir_prec = d
	# arrivée : après la fin, première image où la pointe reste < 0,5 px/image jusqu'au bout
	var i_calme := n - 1
	for i in range(n - 1, i_fin - 30, -1):
		if v[i] >= 0.5:
			break
		i_calme = i
	var residu := 0.0
	for i in range(i_fin + 1, n):
		residu += v[i]
	var c_max := 0.0
	var c_frappe := 0.0
	var c_var := 0.0
	for i in n:
		c_max = maxf(c_max, float(ech[i]["cass"]))
		if ech[i].get("actif", false):
			c_frappe = maxf(c_frappe, float(ech[i]["cass"]))
		if i > 0:
			c_var = maxf(c_var, absf(float(ech[i]["cass"]) - float(ech[i - 1]["cass"])))
	var pdx := Vector2.ZERO
	var pgx := Vector2.ZERO
	var pdv := Vector2.ZERO
	var pgv := Vector2.ZERO
	var pd0: Vector2 = ech[0]["wd"]
	var pg0: Vector2 = ech[0]["wg"]
	for e in ech:
		var a: Vector2 = e["wd"]
		var b: Vector2 = e["wg"]
		pdx = Vector2(maxf(pdx.x, absf(a.x)), maxf(pdx.y, absf(a.y)))
		pgx = Vector2(maxf(pgx.x, absf(b.x)), maxf(pgx.y, absf(b.y)))
		pdv = Vector2(maxf(pdv.x, absf(a.x - pd0.x)), maxf(pdv.y, absf(a.y - pd0.y)))
		pgv = Vector2(maxf(pgv.x, absf(b.x - pg0.x)), maxf(pgv.y, absf(b.y - pg0.y)))
	print("MESURE5 %s %-22s poignet DROIT tenue f%+.0f d%+.0f, max |f| %.0f |d| %.0f, ecart a la tenue f %.0f d %.0f | GAUCHE tenue f%+.0f d%+.0f, max |f| %.0f |d| %.0f, ecart f %.0f d %.0f" % [
		etiq, nom, pd0.x, pd0.y, pdx.x, pdx.y, pdv.x, pdv.y, pg0.x, pg0.y, pgx.x, pgx.y, pgv.x, pgv.y])
	var mg_max := -1.0
	var mg_moy := 0.0
	var mg_n := 0
	for e in ech:
		if float(e["mg"]) >= 0.0:
			mg_max = maxf(mg_max, float(e["mg"]))
			mg_moy += float(e["mg"])
			mg_n += 1
	print("MESURE5 %s %-22s duree=%.2f s (%d coup(s)) frappe=%.2f s (%.0f %% du temps) | pic=%.0f px/s, trajet=%.0f px, %.0f %% pendant la frappe | bosses=%d (pour %d coup(s)) | acoups hors frappe=%.1f px/img2 (t=%.2f) | saut=%.1f px/img (t=%.2f) | rebonds=%d | arrivee=%.2f s apres la fin, residu %.1f px | main_g max=%.1f cm moy=%.1f cm | poignet max=%.0f deg (repos %.0f, frappe %.0f), variation max %.1f deg/img" % [
		etiq, nom, total, n_coups, t_actif, 100.0 * t_actif / maxf(total, 1e-3), pic * 60.0, chemin, 100.0 * chemin_actif / maxf(chemin, 1e-3),
		bosses, n_coups, acc_hors, acc_hors_t, saut, saut_t, rebonds, float(ech[i_calme]["t"]) - total, residu, mg_max, mg_moy / maxf(mg_n, 1), c_max, float(ech[0]["cass"]), c_frappe, c_var])
	if csv != "":
		var f := FileAccess.open(csv.path_join("%s_%s.csv" % [etiq, nom.replace(" ", "_")]), FileAccess.WRITE)
		f.store_line("t;etat;clip;tc;px;py;gx;gy;actif;main_g_cm;poing_g/cible_g;poignet_deg;poignetD_flex;poignetD_dev;poignetG_flex;poignetG_dev")
		for e in ech:
			f.store_line("%.4f;%d;%s;%.4f;%.2f;%.2f;%.2f;%.2f;%d;%.2f;%s;%.1f;%.1f;%.1f;%.1f;%.1f" % [e["t"], e["etat"], e["clip"], e["tc"], e["p"].x, e["p"].y, e["g"].x, e["g"].y, 1 if e.get("actif", false) else 0, e["mg"], e.get("xg", ""), e["cass"], e["wd"].x, e["wd"].y, e["wg"].x, e["wg"].y])
		f.close()

func _go() -> void:
	etiq = _arg("etiquette", "x")
	csv = _arg("csv", "")
	if csv != "":
		DirAccess.make_dir_recursive_absolute(csv)
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
	var seqs := _arg("seq", "leger,combo,puissant").split(",")
	for id in ["epee_metal", "claymore"]:
		mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else load("res://data/armes/%s.tres" % id))
		await _images(60)
		for b in _att.values():
			if is_instance_valid(b):
				b.queue_free()
		_att.clear()
		_attaches()
		await _images(2)
		if mains._modele_arme_d != null:   # lame dans le repère ANATOMIQUE de la main droite (pour mesurer les captures)
			var pw: Vector3 = _att["hand_r"].global_position
			var yv: Vector3 = ((_att["index_01_r"].global_position + _att["pinky_01_r"].global_position) * 0.5 - pw).normalized()
			var xv: Vector3 = _att["index_01_r"].global_position - _att["pinky_01_r"].global_position
			xv = (xv - yv * xv.dot(yv)).normalized()
			var hb := Basis(xv, yv, xv.cross(yv))
			var mb: Basis = mains._modele_arme_d.global_transform.basis.orthonormalized()
			var loc := hb.inverse() * mb
			print("MESURE5 %s LAME_DANS_MAIN %s x=%s y=%s z=%s" % [etiq, id, str(loc.x), str(loc.y), str(loc.z)])
		var a: DonneesArme = mains.arme
		var combo: Array = ProfilsAnimation.profil(a.profil)["combo"]
		print("MESURE5 %s arme %s : vitesse=%.2f preparation=%.2f recuperation=%.2f combo=%s" % [etiq, id, a.vitesse, a.preparation, a.recuperation, str(combo)])
		for g in combo:
			var c: String = ProfilsAnimation.geste(a.profil, g)["clip"]
			print("MESURE5 %s marqueurs %s %s : %s (longueur %.2f)" % [etiq, id, c, str(mains.anim.marqueurs(c)), mains.anim.longueur(c)])
		# raccords : début / fin de chaque clip du combo et de la puissante comparés à la tenue de repos (px, point à 60 % de la lame)
		var lame := func(clip: String, tc: float) -> Vector2:
			return _ecran(mains.anim.pose_arme(clip, tc) * mains._garde_lame.lerp(mains._pointe_lame, 0.6))
		var r0: Vector2 = lame.call("repos", 0.0)
		var clips: Array = []
		for g in combo:
			clips.append(String(ProfilsAnimation.geste(a.profil, g)["clip"]))
		var gl: Dictionary = ProfilsAnimation.geste(a.profil, ProfilsAnimation.profil(a.profil)["lourd"])
		clips.append(String(gl["clip"]))
		for c in clips:
			var L: float = mains.anim.longueur(c)
			print("MESURE5 %s raccord %s %s : debut-repos=%.1f px, fin-repos=%.1f px" % [etiq, id, c, (lame.call(c, 0.0) - r0).length(), (lame.call(c, L) - r0).length()])
		if "leger" in seqs:
			var e1 := await _sequence(id + " leger", [[0.0, 0.05]])
			_analyser(id + " leger", e1, 1)
		if "coup2" in seqs:
			var e2 := await _sequence(id + " coup2", [[0.0, 0.05]], 0, 1)
			_analyser(id + " coup2", e2, 1)
		if "combo" in seqs:
			var ec := await _sequence(id + " combo", [], combo.size())
			_analyser(id + " combo", ec, combo.size())
		if "puissant" in seqs:
			var ep := await _sequence(id + " puissant", [[0.0, 0.9]])
			_analyser(id + " puissant", ep, 1)
	print("FIN_MESURES5")
	quit(0)
