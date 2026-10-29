extends SceneTree
## Test sans fenêtre des GESTES DE MAGIE capturés (GestesMagie, data/magie/gestes_mixamo.json, docs/MAGIE.md) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_gestes_magie.gd -- --nouvelle
## Données : 7 gestes × 2 mains, phases attendues ; chaque pose garde la paume dans l'écran, devant l'œil et à distance ;
## chaque geste part de la pose de repos et y revient (dernière clé du départ / de la fin = repos, à 1 cm près).
## En jeu (scenes/test_magie.tscn) : chaque sort joue le bon geste ; la cible de la main ne saute jamais d'une image à
## l'autre (lancer, charge, jet, double, zone, main droite, interruption) ; soin / protection / enchantement gardent les
## poses fixes ; gestes coupés (GestesMagie.actif = false) = anciennes poses.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const TV := 0.7265   # tan(36°) : fov vertical 72°
const TH := TV * 16.0 / 9.0
## Saut maximal admis de la cible de la main entre deux images à 60 i/s (m) : 6 m/s ; les poussées capturées les plus vives
## vont à 4-5 m/s (un vrai lancer dépasse 10 m/s), un saut (changement de pose sans transition) dépasse 15 cm.
const SAUT_MAX := 0.10

var _ok := true
var _n := 0
var s: Node3D
var mains: Node3D
var magie: MainSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _tester() -> void:
	_donnees()
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	mains = s.joueur.mains
	magie = mains.magie
	magie.eq.apprendre_tout()   # fin du « tout disponible » : ce test a besoin de tous les sorts
	mains.pas_manuel = true
	for i in 20:
		await physics_frame
	await _en_jeu()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _donnees() -> void:
	var d := GestesMagie.donnees()
	var attendus := {"lance": ["entree", "depart"], "charge": ["entree", "tenue", "depart"], "jet": ["entree", "boucle", "fin"],
		"double": ["entree", "depart"], "double_charge": ["entree", "tenue", "depart"], "double_jet": ["entree", "boucle", "fin"],
		"zone": ["entree", "tenue", "depart"]}
	_verif(d.size() == attendus.size(), "données : %d gestes (attendu %d)" % [d.size(), attendus.size()])
	var repos_g: Dictionary = PosesIncantation.pose("repos", "gauche")
	for g in attendus:
		var ok_phases := d.has(g)
		var pire_cadre := 0
		var pire_dist := 9.0
		var ecart_repos := 0.0
		for m in ["gauche", "droite"]:
			if not ok_phases or not (d[g] as Dictionary).has(m):
				ok_phases = false
				continue
			var repos: Vector3 = repos_g["pos"] if m == "gauche" else Vector3(-repos_g["pos"].x, repos_g["pos"].y, repos_g["pos"].z)
			for ph in attendus[g]:
				if not (d[g][m] as Dictionary).has(ph):
					ok_phases = false
					continue
				var poses: Array = d[g][m][ph]
				for p: Dictionary in poses:
					var w := _v(p["pos"])
					var c := w + _v(p["doigts"]) * 0.07 + _v(p["paume"]) * 0.03
					var prof := -c.z
					if prof < 0.3 or absf(c.x) > 0.85 * TH * prof or c.y > 0.7 * TV * prof or c.y < -0.97 * TV * prof:
						pire_cadre += 1
					pire_dist = minf(pire_dist, c.length())
				if ph == "entree":
					ecart_repos = maxf(ecart_repos, _v(poses[0]["pos"]).distance_to(repos))
				if ph in ["depart", "fin"]:
					ecart_repos = maxf(ecart_repos, _v(poses[-1]["pos"]).distance_to(repos))
		_verif(ok_phases, "%s : 2 mains, phases %s" % [g, attendus[g]])
		_verif(pire_cadre == 0, "%s : paume dans l'écran sur toutes les poses (%d hors cadre)" % [g, pire_cadre])
		_verif(pire_dist >= 0.5, "%s : paume à %.2f m de l'œil au plus près (>= 0,50)" % [g, pire_dist])
		_verif(ecart_repos < 0.01, "%s : part du repos et y revient (écart %.1f mm)" % [g, ecart_repos * 1000.0])

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	s.joueur.mana = s.joueur.mana_max
	mains.combat.forcer(EtatCombat.REPOS)

## Joue un scénario [[s, action], ...] image par image ; rend [saut max de la cible de la main (m), gestes vus].
func _jouer(gauche: String, droite: String, actions: Array, duree: float, main := "gauche") -> Array:
	magie.equiper("droite", droite)
	magie.equiper("gauche", gauche)
	_reset()
	for i in 40:
		mains.avancer(DT)
	var pivot: Node3D = mains.get("pivot_torche" if main == "gauche" else "pivot_epee")
	var avant := pivot.transform.origin
	var saut := 0.0
	var vus := {}
	var t := 0.0
	var k := 0
	while t < duree:
		while k < actions.size() and t >= float(actions[k][0]):
			match String(actions[k][1]):
				"appui": magie.appuyer(main)
				"relache": magie.relacher(main)
				"appui2":
					magie.appuyer("gauche")
					magie.appuyer("droite")
				"relache2":
					magie.relacher("gauche")
					magie.relacher("droite")
				"coup": magie._sur_touche(99.0)
			k += 1
		s.joueur.mana = s.joueur.mana_max
		mains.avancer(DT)
		await physics_frame
		t += DT
		var o := pivot.transform.origin
		saut = maxf(saut, o.distance_to(avant))
		avant = o
		var e: Dictionary = magie.gestes._etat[main]
		if String(e["phase"]) != "":
			vus[String(e["geste"]) + ":" + String(e["phase"])] = true
	return [saut, vus.keys()]

func _en_jeu() -> void:
	var cas := [
		["lance", "eclat_glace", "epee", [[0.1, "appui"], [0.15, "relache"]], 1.3, "gauche", ["lance:entree", "lance:depart"]],
		["charge", "boule_feu", "epee", [[0.1, "appui"], [1.3, "relache"]], 2.3, "gauche", ["charge:entree", "charge:tenue", "charge:depart"]],
		["jet", "jet_flammes", "epee", [[0.1, "appui"], [1.6, "relache"]], 2.4, "gauche", ["jet:entree", "jet:boucle", "jet:fin"]],
		["zone", "explosion_obscure", "epee", [[0.1, "appui"], [1.4, "relache"]], 2.4, "gauche", ["zone:entree", "zone:tenue", "zone:depart"]],
		["nova (zone sans charge)", "nova_gelee", "epee", [[0.1, "appui"], [0.15, "relache"]], 1.5, "gauche", ["zone:entree", "zone:depart"]],
		["main droite", "vide", "eclat_glace", [[0.1, "appui"], [0.15, "relache"]], 1.3, "droite", ["lance:entree", "lance:depart"]],
		["double (gauche)", "eclat_glace", "eclat_glace", [[0.1, "appui2"], [0.15, "relache2"]], 1.5, "gauche", ["double:entree", "double:depart"]],
		["double (droite)", "eclat_glace", "eclat_glace", [[0.1, "appui2"], [0.15, "relache2"]], 1.5, "droite", ["double:entree", "double:depart"]],
		["double jet", "jet_flammes", "jet_flammes", [[0.1, "appui2"], [1.4, "relache2"]], 2.3, "gauche", ["double_jet:entree", "double_jet:boucle", "double_jet:fin"]],
		["double charge", "boule_feu", "boule_feu", [[0.1, "appui2"], [1.3, "relache2"]], 2.3, "droite", ["double_charge:entree", "double_charge:tenue", "double_charge:depart"]],
		["interruption pendant la charge", "boule_feu", "epee", [[0.1, "appui"], [0.6, "coup"], [0.7, "relache"]], 1.4, "gauche", ["charge:entree", "charge:tenue"]],
	]
	for c in cas:
		var r: Array = await _jouer(c[1], c[2], c[3], c[4], c[5])
		var vus: Array = r[1]
		var manque := []
		for g in c[6]:
			if not vus.has(g):
				manque.append(g)
		_verif(manque.is_empty(), "%s : gestes joués %s%s" % [c[0], vus, (" ; MANQUE " + str(manque)) if not manque.is_empty() else ""])
		_verif(float(r[0]) <= SAUT_MAX, "%s : la main ne saute pas (pire écart entre deux images %.1f cm <= %.1f)" % [c[0], float(r[0]) * 100.0, SAUT_MAX * 100.0])
	# poses fixes gardées : soin (profil « soi ») et enchantement (« lame »)
	for c2 in [["soin", "soin", "epee"], ["enchantement", "enchant_feu", "epee"]]:
		var r2: Array = await _jouer(c2[1], c2[2], [[0.1, "appui"], [0.9, "relache"]], 1.4, "gauche")
		_verif((r2[1] as Array).is_empty(), "%s : pose fixe gardée (aucun geste capturé)" % c2[0])
	# gestes coupés : anciennes poses
	GestesMagie.actif = false
	var r3: Array = await _jouer("eclat_glace", "epee", [[0.1, "appui"], [0.15, "relache"]], 1.0, "gauche")
	_verif((r3[1] as Array).is_empty(), "GestesMagie.actif = false : aucun geste capturé (anciennes poses)")
	GestesMagie.actif = true
