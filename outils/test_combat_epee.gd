extends SceneTree
## Test sans fenêtre du combat à l'épée (scène scenes/test_combat.tscn) :
##   godot --headless --path . --script res://outils/test_combat_epee.gd -- --nouvelle
## 1. Indépendance au pas de temps : la même suite de coups (léger, léger, léger, lourd chargé) contre le mannequin, simulée
##    à 30, 60 et 144 images/s (mains.avancer(1/fps) et physics_ticks_per_second = fps), donne exactement les mêmes touches
##    (nombre, dégâts) et des instants d'impact identiques à un pas de tracé près.
## 2. Une seule touche par cible et par coup ; combo de directions (diag_dg, diag_gd, horizontale) ; charge plafonnée.
## 3. Mur : la lame est arrêtée sur la face du mur (étincelle + rebond = état Staggered), rien n'est touché derrière.
## 4. Draugr : coup léger qui touche (vie en baisse), coup lourd qui le fait tituber (réactions existantes conservées).
## 5. Garde : l'ancienne interface (etat = GARDE) bloque toujours et pare dans la fenêtre.
## 6. Endurance insuffisante : coup affaibli (dégâts ×0,5).

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

## Avance le combat de `duree` secondes à pas fixe dt (sans attendre le moteur : le décor est statique).
func _simuler(duree: float, dt: float) -> void:
	var n := roundi(duree / dt)
	for i in n:
		mains.avancer(dt)
		if i % 24 == 23:
			await process_frame

func _reset(pos: Vector3, lacet: float) -> void:
	s.placer_joueur(pos, lacet)
	j.vigueur = j.vigueur_max
	j.secousse = 0.0
	j.competences = Competences.new()   # la pratique ferait monter les dégâts d'une suite à l'autre
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._pose_courante = mains._pose_repos()
	mains.defense = DefenseJoueur.new()   # pas de fenêtre de contre-attaque laissée par une parade précédente
	# mannequin (CombatEnnemi depuis la fusion combat/degats_gore) : posture neuve, sinon une posture brisée par la suite
	# précédente ouvrirait un finisher au premier clic de la suivante
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	await physics_frame
	await physics_frame

## Suite de coups contre le mannequin à `fps` ; renvoie le journal [{degats, puissant, t}] (t : temps simulé de l'impact).
func _suite(fps: int) -> Array:
	Engine.physics_ticks_per_second = fps
	await _reset(Vector3.ZERO, 0.0)
	var dt := 1.0 / float(fps)
	var journal := []
	var horloge := [0.0]
	var cb := func(degats: float, puissant: bool) -> void:
		var info: Dictionary = s.mannequin.coups[s.mannequin.coups.size() - 1]["info"]
		journal.append({"degats": snappedf(degats, 0.01), "puissant": puissant, "t": horloge[0], "instant": float(info.get("instant", -1.0))})
	s.mannequin.touche.connect(cb)
	var gestes := []
	# coups légers enchaînés (combo complet, coups_v5 : 4 ; chacun mémorisé pendant la récupération du précédent)
	for i in CoupsUneMain.COMBO.size():
		mains.entrees.appuyer()
		for k in roundi(0.05 / dt):
			mains.avancer(dt)
			horloge[0] += dt
		mains.entrees.relacher()
		var n := roundi(0.40 / dt)
		for k in n:
			mains.avancer(dt)
			horloge[0] += dt
			if k == roundi(0.1 / dt):
				gestes.append(mains._geste_nom)
		await process_frame
	# retour au repos puis coup lourd chargé 1,5 s (au-delà du plafond)
	for k in roundi(0.6 / dt):
		mains.avancer(dt)
		horloge[0] += dt
	# coups_v5 : 4 coups légers brisent la posture du mannequin, étourdi il oscille (au rythme de _process, pas du pas
	# simulé) : on le remet d'aplomb pour que le lourd frappe la même cible quel que soit le pas de temps
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	s.mannequin._tilt = Vector2.ZERO
	s.mannequin._v = Vector2.ZERO
	s.mannequin.pivot.basis = Basis()
	# … et la vue aussi : l'accompagnement des 4 coups (ressorts de CameraCorps, tassement de l'estoc) est avancé par la
	# physique du joueur au rythme du moteur ; repartie du repos, la caméra est la même à 30, 60 et 144 i/s
	j.camera_corps = CameraCorps.new()
	j.tassement = 0.0
	await physics_frame
	await physics_frame
	mains.entrees.appuyer()
	var charge_vue := 0.0
	for k in roundi(1.5 / dt):
		mains.avancer(dt)
		horloge[0] += dt
		charge_vue = maxf(charge_vue, mains._charge)
	var etat_charge: int = mains.combat.etat
	mains.entrees.relacher()
	for k in roundi(0.9 / dt):
		mains.avancer(dt)
		horloge[0] += dt
	s.mannequin.touche.disconnect(cb)
	print("   %d i/s : gestes %s, charge max %.2f (état pendant la charge : %s), touches %s" % [fps, gestes, charge_vue, EtatCombat.NOMS[etat_charge], journal.map(func(h: Dictionary) -> String: return "%.1f%s@%.3f(+%.4f)" % [h["degats"], "P" if h["puissant"] else "", h["t"], h["instant"]])])
	return [journal, gestes, charge_vue, etat_charge]

func _tester() -> void:
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.draugr._bouclier = 0.0   # pas de blocage aléatoire : test déterministe
	s.draugr.combat.profil.chance_blocage = 0.0
	_verif(mains.arme != null and mains.arme.id == "epee_metal", "arme par défaut : épée en métal (%s)" % (mains.arme.id if mains.arme else "aucune"))
	_verif(mains._modele_arme_d != null and mains._pointe_lame.y > 0.9, "modèle chargé par la DonneesArme, repères garde/pointe lus (pointe y=%.3f)" % mains._pointe_lame.y)

	# --- 1-2. même suite de coups à 30, 60, 144 images/s
	print("-- indépendance au pas de temps")
	var res := {}
	for fps in [30, 60, 144]:
		res[fps] = await _suite(fps)
	var ref: Array = res[60][0]
	_verif(ref.size() == 5, "5 coups (combo de 4 + lourd) -> 5 touches sur le mannequin à 60 i/s (une seule par coup) : %d" % ref.size())
	_verif(res[60][1] == ["diag_dg", "revers_gd", "taille_dg", "estoc_combo"], "combo de base : diagonale, revers gauche → droite, taille droite → gauche, estoc %s" % [res[60][1]])
	if ref.size() == 5:
		_verif(absf(ref[2]["degats"] - 14.0 * 1.1) < 0.05, "le coup 3 (taille horizontale) : %.1f" % ref[2]["degats"])
		_verif(absf(ref[3]["degats"] - 14.0 * 1.25) < 0.05, "le coup 4 (estoc) est le plus fort : %.1f" % ref[3]["degats"])
	_geometrie_combo()
	_verif(absf(float(res[60][2]) - 1.0) < 1e-6 and res[60][3] == EtatCombat.CHARGE_LOURDE, "charge plafonnée à 1 en HeavyCharge")
	if ref.size() == 5:
		_verif(not ref[0]["puissant"] and ref[4]["puissant"] and absf(ref[4]["degats"] - 34.0 * 1.3) < 0.05, "léger 14, lourd à pleine charge 34 × 1,3 = %.1f" % ref[4]["degats"])
	for fps in [30, 144]:
		var jr: Array = res[fps][0]
		var memes := jr.size() == ref.size()
		var ecart_geste := 0.0
		var ecart := 0.0
		if memes:
			for i in jr.size():
				memes = memes and jr[i]["degats"] == ref[i]["degats"] and jr[i]["puissant"] == ref[i]["puissant"]
				ecart_geste = maxf(ecart_geste, absf(jr[i]["instant"] - ref[i]["instant"]))
				ecart = maxf(ecart, absf(jr[i]["t"] - ref[i]["t"]))
		# dans le geste, l'impact tombe sur la grille du tracé (1/240 s) : même instant à un pas près, quel que soit le rendu ;
		# l'horloge absolue dépend des entrées, lues une fois par image : quelques images d'écart au plus
		_verif(memes and ecart_geste <= TraceLame.PAS + 1e-6, "%d i/s : mêmes touches qu'à 60 i/s, même instant dans le geste (écart %.4f s ; horloge %.3f s)" % [fps, ecart_geste, ecart])
	Engine.physics_ticks_per_second = 60
	# contrat d'impact (combat/degats_gore) : info transmise en 4e paramètre aux cibles qui l'acceptent
	var cs: Array = s.mannequin.coups
	var i_l: Dictionary = cs[cs.size() - 4]["info"] if cs.size() >= 4 else {}
	var i_h: Dictionary = cs[cs.size() - 1]["info"] if cs.size() >= 1 else {}
	var cles := ["type", "point", "direction", "normale", "zone", "attaque", "arme", "stagger", "collider"]
	_verif(cles.all(func(k: String) -> bool: return i_l.has(k)) and i_l["type"] == "tranchant" and i_l["arme"] == "epee_metal" and i_l["attaque"] == "legere" and (i_l["direction"] as Vector3).is_normalized(), "info du coup léger complète (zone %s, stagger %s)" % [i_l.get("zone"), i_l.get("stagger")])
	_verif(i_h.get("attaque") == "chargee_max" and float(i_h.get("stagger", 0.0)) > float(i_l.get("stagger", 9.0)), "info du coup lourd : chargee_max, stagger %s" % [i_h.get("stagger")])

	# --- 2 bis. directions selon le contexte (phase 4) et continuité des enchaînements
	print("-- directions")
	var cas := [["en avançant", Vector3(0, 0, -3.2), Vector2.ZERO, "verticale_l"], ["pas à droite", Vector3(3.2, 0, 0), Vector2.ZERO, "horizontale_gd"],
		["pas à gauche", Vector3(-3.2, 0, 0), Vector2.ZERO, "horizontale"], ["en reculant", Vector3(0, 0, 2.5), Vector2.ZERO, "estoc"],
		["souris vers la droite", Vector3.ZERO, Vector2(120, 0), "horizontale_gd"], ["souris vers le bas", Vector3.ZERO, Vector2(0, 120), "verticale_l"]]
	for c in cas:
		await _reset(Vector3.ZERO, 0.0)
		var n0: int = s.mannequin.coups.size()
		j.velocity = c[1]
		mains.noter_souris(c[2])
		mains.entrees.appuyer()
		for k in 3:
			mains.avancer(1.0 / 60.0)
		mains.entrees.relacher()
		var g: String = mains._geste_nom
		for k in 40:
			mains.avancer(1.0 / 60.0)
		j.velocity = Vector3.ZERO
		_verif(g == c[3] and s.mannequin.coups.size() == n0 + 1, "%s : geste %s (attendu %s), %d touche" % [c[0], g, c[3], s.mannequin.coups.size() - n0])
	# pas de côté prolongé : les horizontales alternent de sens dans l'enchaînement
	await _reset(Vector3.ZERO, 0.0)
	var suite := []
	for i in 3:
		j.velocity = Vector3(3.2, 0, 0)
		mains.entrees.appuyer()
		for k in 3:
			mains.avancer(1.0 / 60.0)
		mains.entrees.relacher()
		suite.append(mains._geste_nom)
		for k in 26:
			mains.avancer(1.0 / 60.0)
	j.velocity = Vector3.ZERO
	_verif(suite == ["horizontale_gd", "horizontale", "horizontale_gd"], "pas à droite enchaîné : %s" % [suite])
	# hors de la fenêtre de combo, le combo repart du premier geste
	await _reset(Vector3.ZERO, 0.0)
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	await _simuler(1.2, 1.0 / 60.0)
	mains.entrees.appuyer()
	for k in 3:
		mains.avancer(1.0 / 60.0)
	mains.entrees.relacher()
	_verif(mains._geste_nom == "diag_dg", "après le repos, le combo repart de diag_dg (%s)" % mains._geste_nom)
	await _simuler(0.8, 1.0 / 60.0)

	# --- 2 ter. coups en espace écran : le mannequin à 1,5 m et à 2 m est touché par chacun des 3 coups du combo
	print("-- portée (mannequin à 1,5 et 2 m)")
	for dist in [1.5, 2.0]:
		await _reset(Vector3(0, 0, s.POS_MANNEQUIN.z + dist), 0.0)
		var n_av: int = s.mannequin.coups.size()
		var vus := []
		for c in 3:
			mains.entrees.appuyer()
			for k in 3:
				mains.avancer(1.0 / 60.0)
			mains.entrees.relacher()
			var n_c: int = s.mannequin.coups.size()
			for k in 24:
				mains.avancer(1.0 / 60.0)
			vus.append("%s:%d" % [mains._geste_nom, s.mannequin.coups.size() - n_c])
		_verif(s.mannequin.coups.size() - n_av == 3, "mannequin à %.1f m : 3 coups, 3 touches %s" % [dist, vus])
		await _simuler(0.8, 1.0 / 60.0)

	# --- 3. mur : la lame s'arrête sur la face
	print("-- mur")
	await _reset(Vector3(-1.9, 0, 1.0), 90.0)   # face à -X, mur à 1,15 m
	var avant: int = s.mannequin.coups.size()
	var etats := {}
	var face: float = s.POS_MUR.x + s.TAILLE_MUR.x * 0.5
	var impacts: Array = []
	mains.trace.garder_debug = true
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	for k in 30:
		mains.avancer(1.0 / 60.0)
		etats[mains.combat.etat] = true
	impacts = mains.trace.debug_impacts.duplicate()
	mains.trace.garder_debug = false
	_verif(etats.has(EtatCombat.DESEQUILIBRE), "la lame rebondit sur le mur (état Staggered atteint)")
	_verif(impacts.size() == 1 and absf((impacts[0] as Vector3).x - face) < 0.06, "point d'arrêt sur la face du mur (x=%s, face %.2f)" % [str(impacts[0].x) if impacts.size() > 0 else "?", face])
	_verif(s.mannequin.coups.size() == avant, "rien n'est touché à travers le mur")

	# les coups du combo, chacun face au mur : la lame est toujours arrêtée sur la face
	for g in CoupsUneMain.COMBO:
		await _reset(Vector3(-1.9, 0, 1.0), 90.0)
		var n_m: int = s.mannequin.coups.size()
		mains.trace.garder_debug = true
		mains.entrees.appuyer()
		mains.avancer(1.0 / 60.0)
		mains._geste_nom = g
		mains._preparer_geste(false)
		await _simuler(0.05, 1.0 / 60.0)
		mains.entrees.relacher()
		var vu_rebond := false
		for k in 30:
			mains.avancer(1.0 / 60.0)
			vu_rebond = vu_rebond or mains.combat.etat == EtatCombat.DESEQUILIBRE
		var imp: Array = mains.trace.debug_impacts.duplicate()
		mains.trace.garder_debug = false
		_verif(vu_rebond and imp.size() == 1 and absf((imp[0] as Vector3).x - face) < 0.06 and s.mannequin.coups.size() == n_m, "%s face au mur : arrêtée sur la face (x=%s), rebond, rien derrière" % [g, str(snappedf((imp[0] as Vector3).x, 0.001)) if imp.size() > 0 else "?"])

	# --- 4. draugr
	print("-- draugr")
	var d: CharacterBody3D = s.draugr
	var vers := (Vector3(0, 0, 0) - d.global_position)
	vers.y = 0.0
	var pos_j := d.global_position + vers.normalized() * 1.6
	await _reset(Vector3(pos_j.x, 0.0, pos_j.z), rad_to_deg(atan2(-(-vers.x), -(-vers.z))))
	var vie0: float = d.vie
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	await _simuler(0.6, 1.0 / 60.0)
	_verif(d.vie < vie0, "coup léger : le draugr est touché (vie %.0f -> %.0f)" % [vie0, d.vie])
	j.vigueur = j.vigueur_max
	d.etat = d.TRAQUE
	d.vie = 400.0   # le coup lourd vertical touche la tête (critique × 1,5, règles de degats_gore) : il ne doit pas tuer ici
	var vie1: float = d.vie
	mains.entrees.appuyer()
	await _simuler(0.5, 1.0 / 60.0)
	mains.entrees.relacher()
	await _simuler(0.7, 1.0 / 60.0)
	_verif(d.vie < vie1 and d.etat == d.TITUBE, "coup lourd : touché et titube (vie %.0f -> %.0f, état %d)" % [vie1, d.vie, d.etat])

	# --- 5. garde (ancienne interface)
	print("-- garde")
	await _reset(Vector3.ZERO, 0.0)
	mains.etat = mains.GARDE
	mains.temps_garde = 0.0
	_verif(mains.bloque, "etat = GARDE : garde levée (bloque)")
	var r: String = j.recevoir_coup(10.0, j.global_position + Vector3(0, 0, -1.5))
	_verif(r == "parade" and j.vie >= 99.9, "coup reçu de face dans la fenêtre : parade (%s, vie %.1f)" % [r, j.vie])
	mains.etat = mains.REPOS

	# --- 6. endurance insuffisante
	print("-- endurance")
	await _reset(Vector3.ZERO, 0.0)
	j.vigueur = 2.0
	var n0: int = s.mannequin.coups.size()
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	await _simuler(0.6, 1.0 / 60.0)
	var dernier: Dictionary = s.mannequin.coups[s.mannequin.coups.size() - 1] if s.mannequin.coups.size() > n0 else {}
	_verif(not dernier.is_empty() and absf(float(dernier["degats"]) - 7.0) < 0.05, "sans endurance : coup affaibli (%s dégâts au lieu de 14)" % [dernier.get("degats", "aucun")])
	print("   transitions refusées par la machine à états : %d" % mains.combat.refus)

	await _annulation()
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)


## Combo 2026-10-27 (clips, cinématique directe, sans rendu) : trajet du milieu de lame à l'écran pendant la frappe et
## « tranchant qui mène » (angle normale du plat / mouvement du milieu de lame, 90 = le tranchant mène).
func _geometrie_combo() -> void:
	var cam_mains: Transform3D = mains.transform
	for g in CoupsUneMain.COMBO:
		var clip := String(ProfilsAnimation.geste(mains.arme.profil, g)["clip"])
		var m: Dictionary = mains.anim.marqueurs(clip)
		var t0 := float(m["frappe"])
		var t1 := float(m["fin_frappe"])
		var ecr := func(t: float) -> Vector2:
			var x: Transform3D = cam_mains * mains.anim.pose_arme(clip, t)
			return ProfilsAnimation.vers_ecran(x * mains._garde_lame.lerp(mains._pointe_lame, 0.5))
		var a: Vector2 = ecr.call(t0)
		var b: Vector2 = ecr.call(t1)
		var fils := []
		var n := 12
		for k in n:
			var ta := t0 + (t1 - t0) * k / n
			var tb := t0 + (t1 - t0) * (k + 1) / n
			var xa: Transform3D = cam_mains * mains.anim.pose_arme(clip, ta)
			var xb: Transform3D = cam_mains * mains.anim.pose_arme(clip, tb)
			var mil: Vector3 = mains._garde_lame.lerp(mains._pointe_lame, 0.6)
			var mv: Vector3 = xb * mil - xa * mil
			if mv.length() > 1e-4:
				fils.append(rad_to_deg(acos(clampf(absf(xb.basis.z.normalized().dot(mv.normalized())), 0.0, 1.0))))
		var moy := 0.0
		for f in fils:
			moy += float(f) / fils.size()
		var d := b - a
		print("   %s : milieu de lame %s -> %s, fil moyen %.0f°" % [g, a.snapped(Vector2.ONE * 0.01), b.snapped(Vector2.ONE * 0.01), moy])
		match g:
			"diag_dg":
				_verif(d.x < -0.4 and d.y < -0.3 and a.x > 0.0 and a.y > 0.0 and b.x < 0.0 and b.y < 0.0, "coup 1 : VRAIE diagonale haut-droite → bas-gauche à travers le centre (%s -> %s)" % [a, b])
				_verif(moy >= 70.0, "coup 1 : le tranchant mène (fil moyen %.0f° ≥ 70)" % moy)
			"revers_gd":
				_verif(d.x > 0.5 and absf(d.y) < 0.2, "coup 2 : horizontal GAUCHE → DROITE (%s -> %s)" % [a, b])
				_verif(moy >= 70.0, "coup 2 : le tranchant mène, lame à plat (fil moyen %.0f° ≥ 70)" % moy)
			"taille_dg":
				_verif(d.x < -0.6 and absf(d.y) < 0.3, "coup 3 : taille HORIZONTALE droite → gauche (%s -> %s)" % [a, b])
				_verif(moy >= 70.0, "coup 3 : le tranchant mène (fil moyen %.0f° ≥ 70)" % moy)
			"estoc_combo":
				var p0: Transform3D = cam_mains * mains.anim.pose_arme(clip, t0)
				var p1: Transform3D = cam_mains * mains.anim.pose_arme(clip, t1)
				_verif((p1.origin - p0.origin).z < -0.1, "coup 4 : estoc, le poing pousse vers l'avant (%.2f m)" % (p1.origin - p0.origin).z)

## Règle d'annulation (P5) : la garde demandée pendant la PRÉPARATION d'une attaque légère la coupe (parade levée,
## aucune touche) ; une fois la lame active, le coup va au bout (la garde n'est prise qu'en récupération).
func _annulation() -> void:
	print("-- annulation par la garde")
	await _reset(s.POS_MANNEQUIN + Vector3(0, 0, 1.6), 0.0)
	var n0: int = mains.annulations
	var touches := [0]
	var f := func(_d: float, _p: bool) -> void: touches[0] += 1
	s.mannequin.touche.connect(f)
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	var prep: bool = mains.combat.etat == EtatCombat.ATTAQUE_LEGERE and not mains._actif_lance
	mains.entrees.forcer_garde(0.5)
	await _simuler(1.0 / 60.0, 1.0 / 60.0)
	_verif(prep and mains.combat.defense() and mains.annulations == n0 + 1, "garde pendant la préparation : attaque annulée, garde levée en 1 image (état %s)" % mains.combat.nom())
	await _simuler(0.6, 1.0 / 60.0)
	_verif(touches[0] == 0, "attaque annulée : aucune touche (%d)" % touches[0])
	mains.entrees.forcer_garde(0.0)
	await _reset(s.POS_MANNEQUIN + Vector3(0, 0, 1.6), 0.0)
	mains.entrees.appuyer()
	await _simuler(0.05, 1.0 / 60.0)
	mains.entrees.relacher()
	var k := 0
	while not mains._actif_lance and k < 60:
		await _simuler(1.0 / 60.0, 1.0 / 60.0)
		k += 1
	mains.entrees.forcer_garde(0.3)
	await _simuler(1.0 / 60.0, 1.0 / 60.0)
	_verif(mains.combat.attaque(), "lame active : la garde n'annule pas le coup (état %s)" % mains.combat.nom())
	await _simuler(0.8, 1.0 / 60.0)
	_verif(touches[0] >= 1, "coup mené au bout : le mannequin est touché (%d)" % touches[0])
	mains.entrees.forcer_garde(0.0)
	s.mannequin.touche.disconnect(f)
	await _simuler(0.6, 1.0 / 60.0)
