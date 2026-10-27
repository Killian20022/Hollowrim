extends SceneTree
## Réglage des gestes d'attaque (ProfilsAnimation) avec le POIGNET RIGIDE des coups (±15°) :
##   godot --headless --path . --script res://outils/regler_gestes.gd -- [--gestes=diag_dg,horizontale_gd] [--verifier]
## Pour chaque clé (armer, milieu, fin, suivi) de chaque geste, cherche le pôle du coude qui rend la lame affichée (IK +
## orientation_main) la plus proche de la lame voulue (celle du tracé), et affiche l'écart (degrés) et la lame obtenue.
## --verifier : n'optimise pas, mesure l'écart image / tracé le long de l'arc (9 points) avec les pôles du profil.

const SCENE := preload("res://scenes/test_combat.tscn")

var m: Node3D
var cam: Camera3D
var _flexion_nulle := true

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

## Écarts (lame, tranchant) en degrés entre la lame affichée et la pose voulue, pour un pôle donné.
func _mesurer(pose: Transform3D, coude: Vector3) -> Array:
	m.pivot_epee.transform = pose
	m._coude_d.position = coude
	m.regler_poignet(true)
	m._orient_d.flexion_max = 0.0 if _flexion_nulle else deg_to_rad(m.FLEXION_COUP)
	for i in 4:
		m._reposer_doigts()
		await process_frame
	var inv := cam.global_transform.affine_inverse() * m.global_transform
	var vu: Transform3D = cam.global_transform.affine_inverse() * m._modele_arme_d.global_transform
	var voulu: Transform3D = inv * m.pivot_epee.transform
	var local := m.transform.affine_inverse() * vu
	return [rad_to_deg(vu.basis.y.angle_to(voulu.basis.y)), rad_to_deg(vu.basis.x.angle_to(voulu.basis.x)), local.basis.y.normalized(), local.basis.x.normalized()]

## Pose d'une clé avec le tranchant tangent à l'arc (le 4e élément éventuel est ignoré : on le recalcule).
func _pose_sans_fil(g: Dictionary, k: String) -> Transform3D:
	var h := g.duplicate(true)
	for c in ProfilsAnimation.CLES:
		h[c] = (h[c] as Array).slice(0, 3)
	return ProfilsAnimation.pose_cle(h, k)

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun"}
	root.add_child(s)
	for i in 10:
		await process_frame
	m = s.joueur.mains
	cam = s.joueur.camera
	m.pas_manuel = true
	m.passifs.amplitude = 0.0
	var noms := _arg("gestes", "diag_dg,horizontale_gd,verticale_l,diag_gd,horizontale,estoc,verticale").split(",")
	var pire := 0.0
	for nom in noms:
		var g := ProfilsAnimation.geste(m.arme.profil, nom)
		if _arg("verifier") != "":
			_flexion_nulle = false
			var e_max := 0.0
			var ligne := ""
			for i in 9:
				var u := i / 8.0
				var r: Array = await _mesurer(ProfilsAnimation.pose_active(g, u), ProfilsAnimation.coude_actif(g, u))
				e_max = maxf(e_max, r[0])
				ligne += " %.0f" % r[0]
			var rs: Array = await _mesurer(ProfilsAnimation.pose_cle(g, "suivi"), ProfilsAnimation.coude_cle(g, "suivi"))
			print("VERIF %-15s écart lame le long de l'arc (°) :%s   suivi %.0f   max %.0f" % [nom, ligne, rs[0], maxf(e_max, rs[0])])
			pire = maxf(pire, maxf(e_max, rs[0]))
			continue
		# un seul pôle de coude par geste (le coude ne saute pas d'une clé à l'autre) : celui qui minimise l'écart de la
		# lame aux 4 clés + l'écart du tranchant naturel à la tangente de l'arc (tranchant devant)
		var tangentes := {}
		for k in ProfilsAnimation.CLES:
			var cible := _pose_sans_fil(g, k)
			tangentes[k] = cible.basis.x   # sans 4e élément : tranchant = tangente de l'arc
		var meilleur_score := 1e9
		var coude := Vector3.ZERO
		var res := {}
		var grille := []
		for x in [0.2, 0.5, 0.8, 1.1]:
			for y in [-0.8, -0.4, 0.0, 0.4]:
				for z in [-0.4, 0.0, 0.4, 0.8]:
					grille.append(Vector3(x, y, z))
		for passe in 2:
			for c: Vector3 in grille:
				var score := 0.0
				var r_cles := {}
				for k in ProfilsAnimation.CLES:
					var r: Array = await _mesurer(_pose_sans_fil(g, k), c)
					var t: Vector3 = tangentes[k]
					var y: Vector3 = r[2]
					var tp := (t - y * t.dot(y)).normalized()
					var e_fil := rad_to_deg((r[3] as Vector3).angle_to(tp))
					e_fil = minf(e_fil, 180.0 - e_fil)   # lame à deux tranchants : l'un ou l'autre devant, jamais le plat
					score += r[0] + 0.5 * e_fil
					r_cles[k] = [r[0], e_fil, r[2], r[3]]
					if score > meilleur_score:
						break
				if score < meilleur_score:
					meilleur_score = score
					coude = c
					res = r_cles
			grille = []
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					for z in [-1, 0, 1]:
						grille.append(coude + Vector3(x, y, z) * 0.15)
		# la clé « armer » (tenue avant la frappe) peut avoir son propre pôle : le coude glisse ensuite vers celui de la frappe
		var coude_a := coude
		var sc_a: float = res["armer"][0] + 0.5 * res["armer"][1]
		grille = []
		for x in [0.05, 0.35, 0.65, 0.95]:
			for y in [-0.95, -0.55, -0.15, 0.25]:
				for z in [-0.55, -0.15, 0.25, 0.65, 0.95]:
					grille.append(Vector3(x, y, z))
		for passe in 2:
			for c: Vector3 in grille:
				var r: Array = await _mesurer(_pose_sans_fil(g, "armer"), c)
				var t: Vector3 = tangentes["armer"]
				var y: Vector3 = r[2]
				var e_fil := rad_to_deg((r[3] as Vector3).angle_to((t - y * t.dot(y)).normalized()))
				e_fil = minf(e_fil, 180.0 - e_fil)
				if r[0] + 0.5 * e_fil + c.distance_to(coude) * 10.0 < sc_a:
					sc_a = r[0] + 0.5 * e_fil + c.distance_to(coude) * 10.0
					coude_a = c
					res["armer"] = [r[0], e_fil, r[2], r[3]]
			grille = []
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					for z in [-1, 0, 1]:
						grille.append(coude_a + Vector3(x, y, z) * 0.15)
		print("GESTE %s : coude %s (armer %s), score %.0f" % [nom, coude.snapped(Vector3.ONE * 0.01), coude_a.snapped(Vector3.ONE * 0.01), meilleur_score])
		for k in ProfilsAnimation.CLES:
			var cle: Array = g[k]
			var r: Array = res[k]
			var ck: Vector3 = coude_a if k == "armer" else coude
			print("CLE %-15s %-7s lame %.0f° tranchant/tangente %.0f°  \"%s\": [Vector3%s, Vector3%s, Vector3%s, Vector3%s]," % [nom, k, r[0], r[1], k, cle[0], (r[2] as Vector3).snapped(Vector3.ONE * 0.01), ck.snapped(Vector3.ONE * 0.01), (r[3] as Vector3).snapped(Vector3.ONE * 0.01)])
	if _arg("verifier") != "":
		print("PIRE ÉCART : %.0f°" % pire)
	quit()
