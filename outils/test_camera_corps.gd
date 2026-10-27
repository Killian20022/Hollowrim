extends SceneTree
## Test sans fenêtre de la caméra « corps » et des mouvements passifs des mains (CameraCorps, MouvementsPassifs) :
##   godot --headless --path . --script res://outils/test_camera_corps.gd -- --nouvelle [--courbes=<dossier>]
## 1. Indépendance aux images par seconde : le même scénario (repos, marche, sprint, virage souris, saut, chute de 2 m,
##    attaque + impact léger, attaque lourde + impact lourd, coup reçu) simulé à 30, 60 et 144 i/s donne les mêmes
##    positions / rotations aux instants communs (multiples de 1/6 s) et les mêmes pics par phase.
## 2. Amplitudes SUBTILES (bornes en cm / degrés) : repos, balancement de tête, inertie de virage, atterrissages
##    proportionnels à la hauteur, accompagnement des attaques ≤ 0,4°, secousse légère < lourde, coup reçu.
## 3. Main gauche : mêmes mouvements avec un léger retard (déphasage mesuré en ms).
## 4. Options : curseurs à 0 → rien ne bouge (par canal), « Réduire les mouvements » plafonne ; options par défaut à 100 % ;
##    curseurs présents dans le panneau Options. Les options sont modifiées EN MÉMOIRE seulement (options.cfg intact).
## 5. Joueur réel (scenes/test_combat.tscn) : chute de 2 m avec la vraie physique à 30, 60 et 144 ticks : même hauteur
##    mesurée, même creux de caméra ; tout revient au repos.
## --courbes=<dossier> : écrit courbes_<fps>.csv et une planche courbes.png (30/60/144 superposées).

const SCENE := preload("res://scenes/test_combat.tscn")
const FPS := [30, 60, 144]
const DUREE := 11.5

var _ok := true

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return ""

# --- scénario -----------------------------------------------------------------------------------------------------
# Tous les changements tombent sur des multiples de 1/6 s (communs à 30, 60, 144 i/s et au pas de 1/240 s).
## Phases : [nom, début, fin].
const PHASES := [
	["repos", 0.0, 1.0], ["marche", 1.0, 3.0], ["sprint", 3.0, 5.0], ["arret", 5.0, 5.5], ["virage", 5.5, 6.0],
	["saut", 6.0, 7.0], ["chute_2m", 7.0, 8.0], ["attaque_legere", 8.0, 9.0], ["attaque_lourde", 9.0, 10.0],
	["coup_recu", 10.0, 11.5],
]

func _phase(t: float) -> String:
	for p: Array in PHASES:
		if t > float(p[1]) + 1e-6 and t <= float(p[2]) + 1e-6:
			return p[0]
	return "repos"

## Entrées à l'instant t (fin de l'image) : vitesse locale (x, y, z), au sol, altitude, souris (px/s).
func _entrees(t: float) -> Dictionary:
	var v := Vector3.ZERO
	var sol := true
	var y := 0.0
	var souris := 0.0
	if t > 1.0 + 1e-6 and t <= 3.0 + 1e-6:
		v.z = -3.2
	elif t > 3.0 + 1e-6 and t <= 5.0 + 1e-6:
		v.z = -6.5
	if t > 5.5 + 1e-6 and t <= 5.0 + 5.0 / 6.0 + 1e-6:
		souris = 3000.0   # ≈ 6,6 rad/s à la sensibilité par défaut : un demi-tour en ~0,5 s (virage vif)
	if t > 6.0 - 1e-6 and t < 6.0 + 4.0 / 6.0 - 1e-6:   # vol [début, fin) : décollage et atterrissage constatés aux mêmes instants à toute cadence
		var tau := t - 6.0
		sol = false
		v.y = 4.4 - 13.0 * tau
		y = maxf(4.4 * tau - 6.5 * tau * tau, 0.0)
	if t > 7.0 - 1e-6 and t < 7.5 - 1e-6:
		var tau := t - 7.0
		sol = false
		v.y = -13.0 * tau
		y = 2.0 - 6.5 * tau * tau
	if t > 7.0 - 1.0 / 6.0 + 1e-6 and t < 7.0 - 1e-6:
		y = 2.0   # sur un rebord de 2 m (téléporté : le joueur y est posé)
	return {"v": v, "sol": sol, "y": y, "souris": souris}

## Événements ponctuels (instant multiple de 1/6 s) : [t, genre, paramètres].
const EVENEMENTS := [
	[8.0, "accompagner", Vector2(-1, 0), 1.0], [8.0 + 1.0 / 6.0, "impact", 0.22],
	[9.0, "accompagner", Vector2(0, 1), 1.4], [9.0 + 1.0 / 6.0, "impact", 0.5],
	[10.0, "coup_recu", Vector3(1, 0, 0), 0.7],
]

## Simule le scénario à `fps` ; f = {arme, tete, secousses}. Renvoie {echantillons (t multiple de 1/6), pics par phase, csv}.
func _simuler(fps: int, f: Dictionary) -> Dictionary:
	var dt := 1.0 / float(fps)
	var mp := MouvementsPassifs.new()
	var cc := CameraCorps.new()
	mp.amplitude = f["arme"]
	cc.tete = f["tete"]
	cc.secousses = f["secousses"]
	var phase_pas := 0.0
	var secousse := 0.0
	var faits := {}
	var ech: Array = []
	var pics := {}
	var csv := PackedStringArray(["t,cam_y_cm,cam_x_cm,tangage_deg,lacet_deg,roulis_deg,decalage_cm,bras_y_cm,bras_lacet_deg,gauche_lacet_deg"])
	var n := roundi(DUREE * fps)
	var y_prec := 0.0
	for k in range(1, n + 1):
		var t := k * dt
		var e := _entrees(t)
		if float(e["souris"]) > 0.0:
			mp.souris(Vector2(float(e["souris"]) * dt, 0.0))
		var vs := Vector2(e["v"].x, e["v"].z).length()
		if bool(e["sol"]):
			phase_pas += dt * vs * 2.4
		secousse = maxf(0.0, secousse - dt * 1.8)
		mp.avancer(dt, e["v"], e["sol"], true, e["y"])
		cc.avancer(dt, vs, phase_pas, e["sol"], e["v"].y, secousse, e["y"])
		# événements constatés à la fin de l'image (comme un coup reçu entre deux ticks de physique)
		for ev: Array in EVENEMENTS:
			var cle := str(ev[0]) + String(ev[1])
			if not faits.has(cle) and t >= float(ev[0]) - 1e-6:
				faits[cle] = true
				match String(ev[1]):
					"accompagner":
						cc.accompagner(ev[2], ev[3])
					"impact":
						secousse = maxf(secousse, float(ev[2]))
						cc.impact(secousse)
					"coup_recu":
						secousse = maxf(secousse, 0.7)
						cc.coup_recu(ev[2], ev[3])
		y_prec = e["y"]
		var m := {
			"cam_y": cc.position.y, "cam_x": cc.position.x, "tangage": cc.rotation_lisse.x, "lacet": cc.rotation_lisse.y,
			"roulis": cc.rotation_lisse.z, "roulis_total": cc.rotation.z, "decalage": cc.decalage.length(), "bras_pos": mp.decalage_d.origin,
			"bras_rot": mp.rot_affichee, "gauche_rot": mp.rot_affichee_g, "gauche_pos": mp.decalage_g.origin,
		}
		var ph := _phase(t)
		if not pics.has(ph):
			pics[ph] = {"cam_y_min": 0.0, "cam_y_max": 0.0, "cam_x": 0.0, "tangage": 0.0, "lacet": 0.0, "roulis": 0.0,
				"decalage": 0.0, "bras_y_min": 0.0, "bras_y_max": 0.0, "bras_pos": 0.0, "bras_rot": 0.0, "t_pic_d": 0.0,
				"t_pic_g": 0.0, "pic_d": 0.0, "pic_g": 0.0}
		var p: Dictionary = pics[ph]
		p["cam_y_min"] = minf(p["cam_y_min"], m["cam_y"])
		p["cam_y_max"] = maxf(p["cam_y_max"], m["cam_y"])
		p["cam_x"] = maxf(p["cam_x"], absf(m["cam_x"]))
		p["tangage"] = maxf(p["tangage"], absf(m["tangage"]))
		p["lacet"] = maxf(p["lacet"], absf(m["lacet"]))
		p["roulis"] = maxf(p["roulis"], absf(m["roulis"]))
		p["decalage"] = maxf(p["decalage"], m["decalage"])
		p["bras_y_min"] = minf(p["bras_y_min"], m["bras_pos"].y)
		p["bras_y_max"] = maxf(p["bras_y_max"], m["bras_pos"].y)
		p["bras_pos"] = maxf(p["bras_pos"], m["bras_pos"].length())
		var rb: Vector3 = m["bras_rot"]
		p["bras_rot"] = maxf(p["bras_rot"], maxf(absf(rb.x), absf(rb.y)))
		if absf(rb.y) > p["pic_d"]:
			p["pic_d"] = absf(rb.y)
			p["t_pic_d"] = t
		var rg: Vector3 = m["gauche_rot"]
		if absf(rg.y) > p["pic_g"]:
			p["pic_g"] = absf(rg.y)
			p["t_pic_g"] = t
		if k % (fps / 6 if fps % 6 == 0 else fps) == 0 and fps % 6 == 0:
			ech.append({"t": t, "cam_p": cc.position, "cam_r": cc.rotation, "dec": cc.decalage, "bras": mp.decalage_d,
				"gauche": mp.decalage_g})
		csv.append("%.4f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [t, cc.position.y * 100.0, cc.position.x * 100.0,
			rad_to_deg(cc.rotation.x), rad_to_deg(cc.rotation.y), rad_to_deg(cc.rotation.z), cc.decalage.length() * 100.0,
			mp.decalage_d.origin.y * 100.0, rad_to_deg(rb.y), rad_to_deg(rg.y)])
	return {"ech": ech, "pics": pics, "csv": csv, "chute_cam": cc.derniere_chute, "chute_bras": mp.derniere_chute,
		"repos_final": cc.position.length() + cc.rotation.length() + cc.decalage.length(),
		"bras_final": mp.rot_affichee.length()}

func _ecart_echantillons(a: Array, b: Array) -> Vector2:
	# max (m, rad) sur position/décalage puis rotation, aux instants communs
	var ep := 0.0
	var er := 0.0
	var i := 0
	var j := 0
	while i < a.size() and j < b.size():
		var ta: float = a[i]["t"]
		var tb: float = b[j]["t"]
		if absf(ta - tb) < 1e-6:
			if OS.get_cmdline_user_args().has("--detail"):
				var dd := [(a[i]["cam_p"] - b[j]["cam_p"]).length(), (a[i]["dec"] - b[j]["dec"]).length(), (a[i]["bras"].origin - b[j]["bras"].origin).length(), (a[i]["gauche"].origin - b[j]["gauche"].origin).length()]
				if dd.max() > 0.0005:
					print("DETAIL t=%.3f %s" % [ta, str(dd)])
			ep = maxf(ep, (a[i]["cam_p"] - b[j]["cam_p"]).length())
			ep = maxf(ep, (a[i]["dec"] - b[j]["dec"]).length())
			ep = maxf(ep, (a[i]["bras"].origin - b[j]["bras"].origin).length())
			ep = maxf(ep, (a[i]["gauche"].origin - b[j]["gauche"].origin).length())
			er = maxf(er, (a[i]["cam_r"] - b[j]["cam_r"]).length())
			i += 1
			j += 1
		elif ta < tb:
			i += 1
		else:
			j += 1
	return Vector2(ep, er)

func _cm(v: float) -> String:
	return "%.2f cm" % (v * 100.0)

func _deg(v: float) -> String:
	return "%.2f°" % rad_to_deg(v)

func _tester() -> void:
	var tous := {"arme": 1.0, "tete": 1.0, "secousses": 1.0}
	var r := {}
	for fps: int in FPS:
		r[fps] = _simuler(fps, tous)
	# 1. indépendance aux images par seconde (144 n'est pas multiple de 6 → comparé par les pics ; 30 / 60 aussi aux instants)
	var e := _ecart_echantillons(r[30]["ech"], r[60]["ech"])
	print("MESURE ecart 30/60 aux instants communs : position %.3f mm, rotation %.4f°" % [e.x * 1000.0, rad_to_deg(e.y)])
	_verif(e.x < 0.0012 and e.y < deg_to_rad(0.02), "30 et 60 i/s : mêmes positions (< 1,2 mm : une entrée constatée à l'image près) et rotations (< 0,02°) aux instants communs")
	var cles := ["cam_y_min", "cam_y_max", "cam_x", "tangage", "lacet", "roulis", "bras_y_min", "bras_y_max", "bras_rot", "decalage"]
	var pire := 0.0
	var pire_nom := ""
	for ph: Array in PHASES:
		for c: String in cles:
			var ref: float = r[60]["pics"][ph[0]][c]
			for fps: int in [30, 144]:
				var v: float = r[fps]["pics"][ph[0]][c]
				var tol := maxf(absf(ref) * 0.06, 0.001 if c.begins_with("cam_y") or c.begins_with("bras_y") or c == "cam_x" else deg_to_rad(0.04))
				if c == "decalage":
					tol = maxf(absf(ref) * 0.15, 0.0005)   # bruit de secousse (< 8 Hz) : pic échantillonné à la cadence
				var d := absf(v - ref) / tol
				if d > pire:
					pire = d
					pire_nom = "%s/%s à %d i/s : %.5f contre %.5f" % [ph[0], c, fps, v, ref]
	print("MESURE pire écart de pic (en tolérances) : %.2f (%s)" % [pire, pire_nom])
	_verif(pire <= 1.0, "pics identiques à 30 / 60 / 144 i/s par phase (≤ 6 % ou 1 mm / 0,04° ; secousse ≤ 15 %)")
	for fps: int in FPS:
		print("MESURE %d i/s : chute caméra %.3f m, chute bras %.3f m" % [fps, r[fps]["chute_cam"], r[fps]["chute_bras"]])
	_verif(absf(r[30]["chute_cam"] - 2.0) < 0.01 and absf(r[144]["chute_cam"] - 2.0) < 0.01, "chute de 2 m mesurée à 2 m à 30 et 144 i/s")

	# 2. amplitudes (60 i/s)
	var p: Dictionary = r[60]["pics"]
	print("MESURE repos : bras %.1f mm (y %.1f…%.1f mm), rotation %.2f° ; caméra immobile %.4f cm" % [p["repos"]["bras_pos"] * 1000.0,
		p["repos"]["bras_y_min"] * 1000.0, p["repos"]["bras_y_max"] * 1000.0, rad_to_deg(p["repos"]["bras_rot"]), p["repos"]["cam_y_max"] * 100.0])
	_verif(p["repos"]["bras_pos"] < 0.008 and p["repos"]["cam_y_max"] < 1e-5 and p["repos"]["lacet"] < 1e-6, "repos : mains < 8 mm, caméra immobile")
	for ph in ["marche", "sprint"]:
		print("MESURE %s : tête %s haut-bas, %s gauche-droite, roulis %s ; bras %s haut-bas" % [ph, _cm(p[ph]["cam_y_max"] - p[ph]["cam_y_min"]),
			_cm(p[ph]["cam_x"]), _deg(p[ph]["roulis"]), _cm(p[ph]["bras_y_max"] - p[ph]["bras_y_min"])])
	_verif(p["marche"]["cam_y_max"] < p["sprint"]["cam_y_max"], "balancement de tête : marche < sprint")
	_verif(p["sprint"]["cam_y_max"] <= 0.025 and p["sprint"]["cam_x"] <= 0.011 and p["sprint"]["roulis"] <= deg_to_rad(0.3), "balancement de tête discret (sprint ≤ 2,5 cm, ≤ 1,1 cm, ≤ 0,3°)")
	var lag_ms := (float(p["virage"]["t_pic_g"]) - float(p["virage"]["t_pic_d"])) * 1000.0
	print("MESURE virage (3000 px/s pendant 1/3 s) : inertie bras %s (gauche %s), retard de la main gauche %.0f ms" % [_deg(p["virage"]["pic_d"]),
		_deg(p["virage"]["pic_g"]), lag_ms])
	_verif(p["virage"]["pic_d"] > deg_to_rad(0.8) and p["virage"]["pic_d"] <= MouvementsPassifs.ROT_MAX + 1e-6, "inertie de virage visible et plafonnée (≤ 4°)")
	_verif(lag_ms >= 15.0 and lag_ms <= 120.0, "main gauche : même mouvement, léger retard (15-120 ms)")
	print("MESURE saut 0,74 m : tête %s, tangage %s ; chute 2 m : tête %s, tangage %s ; bras %s / %s" % [_cm(-p["saut"]["cam_y_min"]),
		_deg(p["saut"]["tangage"]), _cm(-p["chute_2m"]["cam_y_min"]), _deg(p["chute_2m"]["tangage"]), _cm(-p["saut"]["bras_y_min"]),
		_cm(-p["chute_2m"]["bras_y_min"])])
	_verif(-p["chute_2m"]["cam_y_min"] > -p["saut"]["cam_y_min"] * 1.5 and -p["chute_2m"]["cam_y_min"] <= 0.06, "atterrissage proportionnel à la hauteur (2 m > 0,74 m), ≤ 6 cm")
	print("MESURE attaque légère : lacet %s, secousse %s / %s ; lourde : tangage %s, secousse %s / %s ; coup reçu : roulis %s, tangage %s, secousse %s" % [
		_deg(p["attaque_legere"]["lacet"]), _cm(p["attaque_legere"]["decalage"]), _deg(p["attaque_legere"]["roulis"]),
		_deg(p["attaque_lourde"]["tangage"]), _cm(p["attaque_lourde"]["decalage"]), _deg(p["attaque_lourde"]["roulis"]),
		_deg(p["coup_recu"]["roulis"]), _deg(p["coup_recu"]["tangage"]), _cm(p["coup_recu"]["decalage"])])
	_verif(p["attaque_legere"]["lacet"] <= deg_to_rad(0.45) and p["attaque_legere"]["lacet"] > deg_to_rad(0.1), "attaque : la vue accompagne à peine (0,1-0,45°)")
	_verif(p["attaque_legere"]["decalage"] < p["attaque_lourde"]["decalage"], "secousse : légère < lourde")
	_verif(p["coup_recu"]["roulis"] > deg_to_rad(0.4) and p["coup_recu"]["roulis"] < deg_to_rad(2.0), "coup reçu : la tête penche (0,4-2°)")
	_verif(r[60]["repos_final"] < 1e-3 and r[60]["bras_final"] < 1e-3, "tout revient au repos (secousse comprise)")

	# 4. options
	var o := {}
	for nom: String in ["balancement_arme", "mouvement_tete", "secousses"]:
		_verif(is_equal_approx(float(Jeu.OPTIONS_DEFAUT["affichage"][nom]), 1.0), "option %s : 100 %% par défaut" % nom)
	Jeu.option("affichage", "reduire_mouvements")
	var sauve: Dictionary = Jeu.options.duplicate(true)
	var zero_arme := _simuler(60, {"arme": 0.0, "tete": 1.0, "secousses": 1.0})
	var zero_tete := _simuler(60, {"arme": 1.0, "tete": 0.0, "secousses": 1.0})
	var zero_sec := _simuler(60, {"arme": 1.0, "tete": 1.0, "secousses": 0.0})
	var max_bras := 0.0
	var max_tete := 0.0
	var max_sec := 0.0
	for ph: Array in PHASES:
		max_bras = maxf(max_bras, zero_arme["pics"][ph[0]]["bras_pos"])
		if ph[0] in ["repos", "marche", "sprint", "arret", "virage", "saut", "chute_2m", "attaque_legere"]:
			max_tete = maxf(max_tete, absf(zero_tete["pics"][ph[0]]["cam_y_min"]) + zero_tete["pics"][ph[0]]["cam_y_max"])
			max_tete = maxf(max_tete, zero_tete["pics"][ph[0]]["lacet"] + zero_tete["pics"][ph[0]]["tangage"] + zero_tete["pics"][ph[0]]["roulis"])
		max_sec = maxf(max_sec, zero_sec["pics"][ph[0]]["decalage"])
		if ph[0] in ["coup_recu"]:
			max_sec = maxf(max_sec, zero_sec["pics"][ph[0]]["roulis"])
	_verif(max_bras < 1e-6, "Balancement de l'arme 0 % : mains immobiles")
	_verif(max_tete < 1e-6, "Mouvement de tête 0 % : ni balancement, ni saut, ni atterrissage")
	_verif(max_sec < 1e-6, "Secousses 0 % : ni secousse ni coup reçu")
	Jeu.options["affichage"]["reduire_mouvements"] = true
	Jeu.options["affichage"]["balancement_arme"] = 1.0
	Jeu.options["affichage"]["mouvement_tete"] = 1.0
	Jeu.options["affichage"]["secousses"] = 1.0
	var f := CameraCorps.facteurs()
	_verif(is_equal_approx(f["arme"], CameraCorps.REDUIT_ARME) and is_equal_approx(f["tete"], CameraCorps.REDUIT_TETE) \
		and is_equal_approx(f["secousses"], CameraCorps.REDUIT_SECOUSSES), "Réduire les mouvements : tout plafonné (%.2f, %.2f, %.2f)" % [f["arme"], f["tete"], f["secousses"]])
	Jeu.options["affichage"]["secousses"] = 0.1
	_verif(is_equal_approx(CameraCorps.facteurs()["secousses"], 0.1), "Réduire les mouvements ne remonte pas un curseur plus bas")
	var red := _simuler(60, CameraCorps.facteurs())
	print("MESURE réduit : tête sprint %s, bras virage %s, secousse coup reçu %s" % [_cm(red["pics"]["sprint"]["cam_y_max"]),
		_deg(red["pics"]["virage"]["pic_d"] * CameraCorps.REDUIT_ARME), _cm(red["pics"]["coup_recu"]["decalage"])])
	Jeu.options = sauve
	# curseurs présents dans le panneau Options (sans les toucher : rien n'est écrit)
	var menu := PanelContainer.new()
	menu.set_script(preload("res://scripts/menu_options.gd"))
	root.add_child(menu)
	await process_frame
	var textes := []
	_textes(menu, textes)
	for t: String in ["Balancement de l'arme", "Mouvement de tête", "Secousses", "Réduire les mouvements", "Arrêt sur image"]:
		_verif(t in textes, "panneau Options : « %s »" % t)
	menu.queue_free()

	# courbes
	var dossier := _arg("courbes")
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
		for fps: int in FPS:
			var fa := FileAccess.open(dossier.path_join("courbes_%d.csv" % fps), FileAccess.WRITE)
			fa.store_string("\n".join(r[fps]["csv"]) + "\n")
		_planche(r, dossier.path_join("courbes.png"))

	# 5. joueur réel : chute de 2 m avec la vraie physique
	var res := {}
	for fps: int in FPS:
		res[fps] = await _chute_reelle(fps)
		print("MESURE joueur réel %d ticks : hauteur %.3f m, creux caméra %s, creux bras %.3f m (passifs), repos final %.5f" % [fps,
			res[fps]["h"], _cm(res[fps]["creux"]), res[fps]["h_bras"], res[fps]["final"]])
	for fps: int in [30, 144]:
		_verif(absf(res[fps]["h"] - res[60]["h"]) < 0.03 and absf(res[fps]["creux"] - res[60]["creux"]) < 0.003,
			"joueur réel à %d ticks : même chute (%.3f / %.3f m) et même creux de caméra (%s / %s)" % [fps, res[fps]["h"], res[60]["h"],
			_cm(res[fps]["creux"]), _cm(res[60]["creux"])])
	_verif(res[60]["final"] < 1e-3, "joueur réel : caméra revenue au repos")
	Engine.physics_ticks_per_second = 60
	print("RESUME test_camera_corps : %s" % ("OK" if _ok else "ECHEC"))
	quit(0 if _ok else 1)

func _textes(n: Node, l: Array) -> void:
	if n is Label:
		l.append((n as Label).text)
	elif n is Button:
		l.append((n as Button).text)
	for c in n.get_children():
		_textes(c, l)

## Le vrai joueur tombe de 2 m sur le sol plat de la scène de test (physique à `fps` ticks).
func _chute_reelle(fps: int) -> Dictionary:
	Engine.physics_ticks_per_second = fps
	var s: Node3D = SCENE.instantiate()
	s.set("options", {"draugr": "aucun", "sans-aide": ""})
	root.add_child(s)
	var j: CharacterBody3D = s.joueur
	for i in 20:
		await physics_frame
	s.placer_joueur(Vector3(0, 0, 0.3), 0.0)
	for i in fps:
		await physics_frame
	j.global_position.y += 2.0
	j.velocity = Vector3.ZERO
	var creux := 0.0
	for i in fps * 2:
		await physics_frame
		creux = minf(creux, j.camera.position.y)
	for i in fps * 2:
		await physics_frame
	var r := {"h": j.camera_corps.derniere_chute, "creux": -creux, "h_bras": j.mains.passifs.derniere_chute,
		"final": j.camera.position.length() + j.camera.rotation.length()}
	s.queue_free()
	await process_frame
	return r

## Planche des courbes : tête (y), tangage, lacet, roulis, bras (y), lacet bras / main gauche ; 30 (rouge), 60 (vert),
## 144 (bleu) superposées sur toute la durée du scénario.
func _planche(r: Dictionary, chemin: String) -> void:
	var w := 1400
	var hp := 150
	var series := [["tête y (cm)", 1, 3.0], ["tangage (°)", 3, 1.2], ["lacet (°)", 4, 1.0], ["roulis (°)", 5, 2.0],
		["secousse (cm)", 6, 3.0], ["bras y (cm)", 7, 3.0], ["lacet bras / gauche (°)", 8, 4.5]]
	var img := Image.create(w, hp * series.size(), false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.1))
	var couleurs := {30: Color(1, 0.35, 0.3), 60: Color(0.4, 1, 0.4), 144: Color(0.4, 0.6, 1)}
	for si in series.size():
		var y0 := si * hp + hp / 2
		for x in w:
			img.set_pixel(x, y0, Color(0.3, 0.3, 0.35))
			img.set_pixel(x, si * hp, Color(0.5, 0.5, 0.55))
		for ph: Array in PHASES:
			var xp := int(float(ph[1]) / DUREE * (w - 1))
			for y in range(si * hp, (si + 1) * hp):
				img.set_pixel(xp, y, Color(0.25, 0.25, 0.3))
		for fps: int in FPS:
			for ligne: String in r[fps]["csv"].slice(1):
				var c := ligne.split(",")
				var t := float(c[0])
				var cols := [int(series[si][1])] if si < 6 else [8, 9]
				for col: int in cols:
					var v := float(c[col])
					var x := int(t / DUREE * (w - 1))
					var y := clampi(y0 - int(v / float(series[si][2]) * (hp * 0.45)), si * hp, (si + 1) * hp - 1)
					var cl: Color = couleurs[fps] * (1.0 if col != 9 else 0.6)
					img.set_pixel(clampi(x, 0, w - 1), y, cl)
	img.save_png(chemin)
	print("PLANCHE %s (échelles : %s)" % [chemin, ", ".join(series.map(func(s: Array) -> String: return "%s ±%s" % [s[0], s[2]]))])
