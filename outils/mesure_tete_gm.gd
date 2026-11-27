extends SceneTree
## GRAND MARTEAU, 1re personne (défaut B de l'exe 8 : tête coupée par le haut de l'écran pendant l'élan) : MESURE, image par
## image à 60 i/s dans le jeu (mains.gd, machine à états, clips, couche passive, cadrage), de la TÊTE DE L'ARME à l'écran.
##   godot --headless --path . --fixed-fps 60 --script res://outils/mesure_tete_gm.gd -- --nouvelle [--arme=grand_marteau]
##         [--etiquette=avant|apres] [--csv=C:\\...\\tete_gm.csv]
## Tête = boîte englobante du fer (sommets du modèle au-delà de 78 % garde -> pointe), 8 coins projetés (repère de la caméra,
## ProfilsAnimation.TAN_H / TAN_V). Par clip : images où un coin sort par le HAUT (y > 1), plus longue série, dépassement max
## (part de la demi-hauteur d'écran), instants (temps du clip) ; images où la tête entière est hors champ ; part de l'écran
## Dépassement en DEGRÉS au-dessus du bord haut (angle vertical du coin moins le demi-champ vertical). Lignes « TETE_GM ... », « TETE_GM_RESUME » à la fin.
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const ORIGINE := Vector3(-12.0, 0.0, 6.0)

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var etiq := "x"
var _coins: Array[Vector3] = []
var _lignes: Array[String] = []
var _cadrage_max := 0.0
var _mains_cachees := 0

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

## Coins de la boîte du fer, repère du modèle.
func _coins_tete() -> void:
	var m: Node3D = mains._modele_arme_d
	var inv := m.global_transform.affine_inverse()
	var y_min: float = mains._garde_lame.y + (mains._pointe_lame.y - mains._garde_lame.y) * 0.78
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf := inv * (mi as MeshInstance3D).global_transform
		for v: Vector3 in mesh.get_faces():
			var q: Vector3 = xf * v
			if q.y >= y_min:
				mn = mn.min(q)
				mx = mx.max(q)
	_coins.clear()
	for k in 8:
		_coins.append(Vector3(mx.x if k & 1 else mn.x, mx.y if k & 2 else mn.y, mx.z if k & 4 else mn.z))
	print("TETE_GM %s fer : boite %s -> %s (repere du modele)" % [etiq, mn, mx])

## Point du repère monde -> écran normalisé (x, y dans -1..1, y vers le HAUT) et profondeur (m) devant l'œil.
func _ecran(p: Vector3) -> Vector3:
	var cam := (mains.get_parent() as Node3D).global_transform
	var q := cam.affine_inverse() * p
	var z := -q.z
	var zz := maxf(z, 0.02)
	return Vector3(q.x / zz / ProfilsAnimation.TAN_H, q.y / zz / ProfilsAnimation.TAN_V, z)

func _echantillon() -> Dictionary:
	var m: Node3D = mains._modele_arme_d
	var ymax := -INF
	var dedans := 0
	var devant := true
	var cam := (mains.get_parent() as Node3D).global_transform
	var haut := rad_to_deg(atan(ProfilsAnimation.TAN_V))
	for c in _coins:
		var e := _ecran(m.global_transform * c)
		var q := cam.affine_inverse() * (m.global_transform * c)
		# dépassement du bord haut en degrés (angle vertical du coin au-dessus de l'axe de visée moins le demi-champ) ; un coin
		# derrière l'œil, au-dessus : > 90 - demi-champ
		ymax = maxf(ymax, rad_to_deg(atan2(q.y, -q.z)) - haut)
		if e.z > 0.05 and absf(e.x) <= 1.0 and absf(e.y) <= 1.0:
			dedans += 1
		if e.z <= 0.05:
			devant = false
	var ctr := Vector3.ZERO
	for c in _coins:
		ctr += c / 8.0
	var qc := cam.affine_inverse() * (m.global_transform * ctr)
	var sqm: Skeleton3D = mains._sq
	var mains_vues := 0
	for o in ["hand_r", "hand_l"]:
		var e := _ecran(sqm.global_transform * sqm.get_bone_global_pose(sqm.find_bone(o)).origin)
		if e.z > 0.05 and absf(e.x) <= 1.0 and e.y >= -1.0:
			mains_vues += 1
	if mains_vues == 0:
		_mains_cachees += 1
	var cg = mains.get("_cadrage")
	_cadrage_max = maxf(_cadrage_max, rad_to_deg(float(cg)) if cg != null else 0.0)
	return {"clip": String(mains.anim.reel(mains.anim.clip)), "tc": float(mains.anim.t), "ymax": ymax, "yc": rad_to_deg(atan2(qc.y, -qc.z)) - haut, "dedans": dedans, "devant": devant,
		"etat": int(mains.combat.etat)}

func _remettre() -> void:
	s.placer_joueur(ORIGINE, 0.0, 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	await _images(50)

func _sequence(nom: String, clics: Array) -> Array:
	await _remettre()
	var ech: Array = []
	var t := 0.0
	var k := 0
	var tenu := -1.0
	var vu := false
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
		if mains.combat.etat in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CHARGE_LOURDE]:
			vu = true
		var e := _echantillon()
		e["t"] = t
		ech.append(e)
		if vu and k >= clics.size() and tenu < 0.0 and mains.combat.calme():
			break
	return ech

func _analyser(nom: String, ech: Array) -> Dictionary:
	var par_clip := {}
	var ordre: Array[String] = []
	var serie := 0
	var clip_prec := ""
	for e: Dictionary in ech:
		var c: String = e["clip"]
		if not par_clip.has(c):
			par_clip[c] = {"n": 0, "coupe": 0, "serie": 0, "dep": 0.0, "hors": 0, "instants": [], "centre": 0}
			ordre.append(c)
		var st: Dictionary = par_clip[c]
		st["n"] += 1
		if c != clip_prec:
			serie = 0
		clip_prec = c
		var coupe: bool = float(e["ymax"]) > 0.0
		if coupe:
			st["coupe"] += 1
			serie += 1
			st["serie"] = maxi(st["serie"], serie)
			st["dep"] = maxf(st["dep"], float(e["ymax"]))
			(st["instants"] as Array).append("%.2f" % float(e["tc"]))
		else:
			serie = 0
		if int(e["dedans"]) == 0:
			st["hors"] += 1
		if float(e["yc"]) > 0.0:
			st["centre"] += 1
		_lignes.append("%s;%s;%s;%.3f;%.3f;%.3f;%d;%d" % [etiq, nom, c, float(e["t"]), float(e["tc"]), float(e["ymax"]), int(e["dedans"]), 1 if coupe else 0])
	var tot := {"coupe": 0, "serie": 0}
	for c in ordre:
		var st: Dictionary = par_clip[c]
		var ins: Array = st["instants"]
		print("TETE_GM %s %-9s %-11s images %3d | tete coupee en haut %3d (serie max %2d, depassement max %5.1f deg au-dessus du bord) | tete entiere hors champ %3d | centre de la tete hors champ %3d | instants %s" % [
			etiq, nom, c, st["n"], st["coupe"], st["serie"], float(st["dep"]), st["hors"], st["centre"],
			("%s..%s" % [ins[0], ins[-1]]) if not ins.is_empty() else "-"])
		if c.begins_with("gm_") or c.begins_with("charge_gm") or c.begins_with("lourd_gm"):
			tot["coupe"] += int(st["coupe"])
			tot["serie"] = maxi(tot["serie"], int(st["serie"]))
	return tot

func _go() -> void:
	etiq = _arg("etiquette", "x")
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
	var id := _arg("arme", "grand_marteau")
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id))
	await _images(60)
	print("TETE_GM %s arme %s profil %s" % [etiq, id, mains.arme.profil])
	_coins_tete()
	var r1 := _analyser("combo", await _sequence("combo", [[0.0, 0.05], [0.8, 0.05], [1.6, 0.05]]))
	var r2 := _analyser("puissant", await _sequence("puissant", [[0.0, 0.9]]))
	print("TETE_GM_RESUME %s images tete coupee : combo %d (serie max %d) puissant %d (serie max %d) | cadrage du viewmodel max %.1f deg | images sans aucune main a l'ecran %d" % [etiq, r1["coupe"], r1["serie"], r2["coupe"], r2["serie"], _cadrage_max, _mains_cachees])
	var csv := _arg("csv", "")
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_line("version;sequence;clip;t;t_clip;depassement_haut_deg;coins_dedans;coupee")
		for l in _lignes:
			f.store_line(l)
	quit(0)
