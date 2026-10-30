extends SceneTree
## Test sans fenêtre : GESTES PAR FAMILLE (branche combat/gestes_lourds, GestesLourds) — haches, masse, marteaux, grand marteau.
##   1. branchement : chaque arme du catalogue reçoit le profil de sa famille (hache, masse, marteau, grand_marteau), les
##      épées gardent le leur (combo d'épée inchangé) ; tenues remplacées (repos → repos_h / repos_m / repos_gm) ;
##   2. trajectoires : pendant chaque frappe, la tête de l'arme décrit un ARC continu à l'écran (pas de cassure > 45° entre
##      deux pas de 1/120 s avant l'impact, pas de retour en arrière) ; armé plus lent que la chute (masses, marteaux) ;
##   3. combo : les trois coups de chaque famille touchent le mannequin à 1,7 m ; le contact déclenche le « mordant » ;
##      un coup de masse dure ≥ 1,3 × le coup d'épée, un coup de grand marteau ≥ 2 × ;
##   4. grand marteau : main gauche sur le manche (IK de combat/claymore_2mains) au repos et à l'impact ;
##   5. traînée : tête seulement pour masses et marteaux.
##   godot --headless --path . --script res://outils/test_gestes_familles.gd -- --nouvelle
const SCENE := preload("res://scenes/test_combat.tscn")
const ATTENDU := {"hache_guerre": "hache", "hachette": "hache", "masse_cloutee": "masse", "marteau_guerre": "marteau",
	"grand_marteau": "grand_marteau", "epee_soldat": "epee_longue", "claymore": "deux_mains"}
const REPOS := {"hache": "repos_h", "masse": "repos_m", "marteau": "repos_m", "grand_marteau": "repos_gm"}
const A_TESTER := ["hache_guerre", "masse_cloutee", "marteau_guerre", "grand_marteau"]
const ORIGINE := Vector3(-12.0, 0.0, 6.0)
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _cible: StaticBody3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		mains.avancer(DT)
		await process_frame

func _remettre() -> void:
	s.placer_joueur(ORIGINE, 0.0, 0.0)
	_cible.global_position = ORIGINE + Vector3(0, 0, -1.7)
	_cible.coups.clear()
	var mc: CombatEnnemi = _cible.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._souris_recente = Vector2.ZERO
	await _images(30)
	await physics_frame
	await physics_frame

func _coup(enchaine := false) -> Dictionary:
	var n0: int = _cible.coups.size()
	mains.entrees.appuyer()
	var tenu := true
	var t := 0.0
	var clip := ""
	var fin := -1.0
	var mord := false
	for k in 300:
		if tenu and t >= 0.05 - 1e-9:
			mains.entrees.relacher()
			tenu = false
		mains.avancer(DT)
		await process_frame
		mord = mord or mains._mordant_u >= 0.0
		if mains.combat.etat in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE]:
			clip = mains._clip
		t += DT
		if enchaine and clip != "" and mains.combat.etat == EtatCombat.RECUPERATION and mains.combat.t > 0.15:
			fin = t
			break
		if not tenu and mains.combat.calme() and clip != "":
			fin = t
			break
	return {"clip": clip, "touches": _cible.coups.size() - n0, "duree": fin, "mord": mord}

## Arc de la tête à l'écran pendant la frappe du clip : [cassure max (°) avant l'impact, durée armé / durée frappe].
func _arc(clip: String) -> Array:
	var m: Dictionary = mains.anim.marqueurs(clip)
	var pts: Array[Vector2] = []
	var t := float(m["frappe"])
	while t <= float(m["fin_frappe"]) + 1e-6:
		var c: Vector3 = mains.transform * (mains.anim.pose_arme(clip, t) * mains._pointe_lame)
		if c.z < -0.15:   # tête devant la caméra seulement (armé au-dessus / derrière la tête : hors champ, projection sans sens)
			pts.append(ProfilsAnimation.vers_ecran(c))
		t += 1.0 / 120.0
	var pire := 0.0
	for i in range(1, pts.size() - 1):
		var a := pts[i] - pts[i - 1]
		var b := pts[i + 1] - pts[i]
		if a.length() > 0.003 and b.length() > 0.003:
			pire = maxf(pire, rad_to_deg(a.angle_to(b)) if a.angle_to(b) >= 0.0 else -rad_to_deg(a.angle_to(b)))
	var rapport := float(m["arme"]) / maxf(float(m["fin_frappe"]) - float(m["frappe"]), 1e-3)
	return [pire, rapport]

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	ButinTables.reinitialiser()
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	_cible = s.mannequin
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	# 1. branchement par famille
	for id in ATTENDU:
		var d := CatalogueArmes.donnees(id)
		_verif(d != null and d.profil == ATTENDU[id], "%s (famille %s) : profil « %s » (%s)" % [id, d.famille if d else "?", ATTENDU[id], d.profil if d else "?"])
	_verif(ProfilsAnimation.profil("epee_longue")["combo"] == ["diag_dg", "revers_gd", "estoc_combo"], "épée : combo inchangé")
	# référence : coup 1 de l'épée de métal
	await _remettre()
	var ref := await _coup()
	print("REF épée de métal : %s, durée %.2f s" % [ref["clip"], ref["duree"]])
	for id in A_TESTER:
		print("-- ", id)
		mains.equipement.equiper("droite", CatalogueArmes.donnees(id))
		await _images(40)
		var a: DonneesArme = mains.arme
		var p := ProfilsAnimation.profil(a.profil)
		_verif(mains.anim.reel("repos") == REPOS[a.profil], "%s : tenue de repos %s" % [id, mains.anim.reel("repos")])
		print("   poing le long du manche : %.3f m (repère « prise » + %.2f)" % [mains._milieu_d, GestesLourds.decalage_prise(a)])
		# 2. arcs
		for g in p["combo"]:
			var clip := String(p["gestes"][g]["clip"])
			var r := _arc(clip)
			_verif(r[0] <= 45.0, "%s : %s (%s) — arc continu pendant la frappe (cassure max %.0f°)" % [id, g, clip, r[0]])
			if a.profil != "hache":
				_verif(r[1] >= 2.0, "%s : %s — armé lent, chute rapide (armé = %.1f × la frappe)" % [id, g, r[1]])
		# 5. traînée
		var tr := GestesLourds.points_trainee(p["gestes"][p["combo"][0]], mains._garde_lame, mains._pointe_lame)
		if a.profil in ["masse", "marteau", "grand_marteau"]:
			_verif(tr.size() == 2 and (tr[1] - tr[0]).length() < (mains._pointe_lame - mains._garde_lame).length() * 0.35, "%s : traînée de la tête seulement" % id)
		# 4. grand marteau : main gauche sur le manche
		if a.deux_mains:
			var pire := 0.0
			for pose in ["repos_gm:0.0", "gm_a:0.45", "gm_a:0.70", "gm_b:0.67"]:
				mains._pose_figee = pose
				await _images(4)
				var poing_g: Vector3 = mains._accroche_g.global_transform * mains.PRISE_G.origin
				pire = maxf(pire, poing_g.distance_to(mains.to_global(mains.pivot_torche.position)))
			mains._pose_figee = ""
			_verif(pire <= 0.06 and not mains.porte_torche.visible, "%s : main gauche sur le manche (pire %.1f cm)" % [id, pire * 100.0])
		# 3. combo
		await _remettre()
		var clips: Array[String] = []
		var mord := false
		var duree1 := 0.0
		for k in 3:
			var r := await _coup(k < 2)
			clips.append(r["clip"])
			mord = mord or r["mord"]
			if k == 0:
				duree1 = r["duree"]
			_verif(r["touches"] >= 1, "%s : coup %d (%s) touche le mannequin à 1,7 m" % [id, k + 1, r["clip"]])
		var attendus: Array[String] = []
		for g in p["combo"]:
			attendus.append(String(p["gestes"][g]["clip"]))
		_verif(clips == attendus, "%s : combo %s" % [id, ", ".join(clips)])
		_verif(mord, "%s : la tête mord au contact (arrêt net + recul)" % id)
		await _remettre()
		var r1 := await _coup()
		var f := 2.0 if a.deux_mains else (1.3 if a.profil != "hache" else 0.9)
		_verif(r1["duree"] >= ref["duree"] * f, "%s : durée du coup %.2f s ≥ %.1f × épée (%.2f s)" % [id, r1["duree"], f, ref["duree"]])
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
