extends SceneTree
## Mesure (coups_v4) : trajectoire de la POINTE de l'épée à l'écran (480×270) image par image, pour les 4 coups validés
## (combo enchaîné diag_dg → revers_gd → estoc_combo, puis puissant « lourd »), telle que l'image la montre (fondus compris).
## Lignes « IMG » : n°, état, temps du clip, pointe (px), vitesse (px/image à 60 i/s), avancée du joueur (m), caméra (°).
## Lignes « BILAN » par coup : vitesse max, vitesse à la fin de la frappe et 3 images après (arrêt sec ?), part de la frappe
## où la vitesse est maximale (accélération franche ?), écart de la pointe entre la fin d'un coup et le début du suivant.
##   godot --headless --path . --script res://outils/analyse_coups_v4.gd -- --nouvelle [--detail]
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _cam_max := Vector3.ZERO

func _init() -> void:
	_go.call_deferred()

func _pointe() -> Vector2:
	var p: Vector3 = mains.transform * (mains.pivot_epee.transform * mains._pointe_lame)   # image affichée (couche additive comprise)
	return ProfilsAnimation.vers_ecran(p) * Vector2(240.0, 135.0)

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	mains.debug_combat = true   # imprime la vitesse de la pointe en fin de frappe (pas de dessin : trace.garder_debug reste faux)
	for i in 40:
		await process_frame
	# le jeu tourne seul (mains._process, joueur._physics_process) : avancée, caméra et geste comme en partie
	var detail := "--detail" in OS.get_cmdline_user_args()
	var prec := _pointe()
	var x0 := j.global_position
	# combo : un appui court tous les 0,42 s (dans la fenêtre d'enchaînement), puis le puissant
	var appuis := {0: 0.05, 25: 0.05, 50: 0.05, 100: 0.6}
	var relache_a := -1
	var par_coup := {}
	var ordre := []
	for k in 190:
		if appuis.has(k):
			mains.entrees.appuyer()
			relache_a = k + roundi(float(appuis[k]) / DT)
		if k == relache_a:
			mains.entrees.relacher()
		await process_frame
		var p := _pointe()
		var v := p.distance_to(prec)
		var g: String = mains._geste_nom
		var e: int = mains.combat.etat
		var phase := "repos"
		if e in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE]:
			phase = "frappe" if mains._actif_lance else "arme"
		elif e == EtatCombat.CHARGE_LOURDE:
			phase = "charge"
		elif e == EtatCombat.RECUPERATION:
			phase = "suivi" if mains.combat.t < mains._duree_suivi else "retour"
		if phase != "repos":
			if not par_coup.has(g):
				par_coup[g] = {"v": [], "phase": [], "p": []}
				ordre.append(g)
			par_coup[g]["v"].append(v)
			par_coup[g]["phase"].append(phase)
			par_coup[g]["p"].append(p)
		_cam_max = _cam_max.max(j.camera_corps.rotation_lisse.abs() * (180.0 / PI))
		if detail:
			var rot: Vector3 = j.camera.rotation
			print("IMG %3d %-12s %-7s pointe (%6.1f, %6.1f) v %5.1f  avancée %.3f m  caméra lacet %+.2f° tangage %+.2f° roulis %+.2f°" % [k, g, phase, p.x, p.y, v,
				(j.global_position - x0).length(), rad_to_deg(rot.y), rad_to_deg(rot.x), rad_to_deg(rot.z)])
		prec = p
	for g in ordre:
		var d: Dictionary = par_coup[g]
		var vs: Array = d["v"]
		var ph: Array = d["phase"]
		var i0 := ph.find("frappe")
		var i1 := ph.rfind("frappe")
		var vmax := 0.0
		var imax := 0
		for i in range(maxi(i0, 0), i1 + 1):
			if vs[i] > vmax:
				vmax = vs[i]
				imax = i
		var apres: Array = vs.slice(i1 + 1, i1 + 4)
		print("BILAN %-12s frappe %d images, v max %.1f px/image à %d %% de la frappe, v fin de frappe %.1f, 3 images après %s, suivi %d images" % [g, i1 - i0 + 1, vmax,
			roundi(100.0 * float(imax - i0) / maxf(float(i1 - i0), 1.0)), vs[i1] if i1 >= 0 else 0.0, apres.map(func(x): return snappedf(x, 0.1)), ph.count("suivi")])
	print("CAMERA amplitude max : lacet %.2f°, tangage %.2f°, roulis %.2f°" % [_cam_max.y, _cam_max.x, _cam_max.z])
	print("AVANCEE totale du joueur pendant la séquence : %.2f m" % (j.global_position - x0).length())
	quit(0)
