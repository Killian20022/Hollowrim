extends SceneTree
## Test sans fenêtre de la FOUDRE v2 (scripts/magie/foudre_v2.gd, docs/MAGIE_FOUDRE_V2.md) :
##   - arbre d'éclair : bouts tenus, 2-4 branches, points du tronc plafonnés, nervure cohérente (pas d'aller-retour) ;
##   - cadence : une nouvelle forme toutes les 2 à 4 images, jamais plus vite ;
##   - canalisation (EffetsMagie.jet électricité) : un Canal, arcs plafonnés (MAX_ARCS_CANAL), qui partent des doigts
##     (à moins de 25 cm de la paume) et finissent près du point visé ; ni décharge ni faisceau de la v1 ;
##   - chaîne : arcs v2, tout s'éteint ; `--foudre-v1` : l'ancien rendu revient (décharge / pas de Canal).
##   godot --headless --path . --script res://outils/test_foudre_v2.gd -- --nouvelle
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	print("  ok  " if cond else "  ÉCHEC ", texte)
	if not cond:
		echecs += 1

func _lancer() -> void:
	print("test_foudre_v2")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# --- arbre
	var a := Vector3(0, 1.5, 0)
	var b := Vector3(0, 1.2, -6)
	var pire_retour := 0.0
	for essai in 40:
		var tr := FoudreV2.arbre(a, a.lerp(b, 0.45) + Vector3(0.3, 0, 0), b, rng, essai * 0.1, {"branches": 2 + essai % 3})
		var tronc: PackedVector3Array = tr[0].p
		if essai == 0:
			verifier(tronc[0].distance_to(a) < 1e-4 and tronc[tronc.size() - 1].distance_to(b) < 1e-4, "arbre : le tronc part de a et finit sur b")
			verifier(tronc.size() <= FoudreV2.MAX_POINTS_TRONC + 1, "arbre : %d points de tronc <= %d" % [tronc.size(), FoudreV2.MAX_POINTS_TRONC + 1])
		var nb := tr.filter(func(t): return int(t.niv) == 1).size()
		if nb != 2 + essai % 3:
			verifier(false, "arbre : %d branches au lieu de %d" % [nb, 2 + essai % 3])
		# cohérence : avancer le long de l'axe ; un segment qui recule de plus de 15 cm = zigzag qui part dans tous les sens
		var d := (b - a).normalized()
		for i in range(1, tronc.size()):
			pire_retour = maxf(pire_retour, -(tronc[i] - tronc[i - 1]).dot(d))
	verifier(pire_retour < 0.15, "nervure cohérente : pire recul le long de l'axe %.3f m < 0,15" % pire_retour)
	# --- cadence
	var monde := Node3D.new()
	root.add_child(monde)
	current_scene = monde
	var arc := FoudreV2.Arc.new(monde, FoudreV2.materiau())
	var formes: Array[int] = []
	for img in 200:
		if arc.a_refaire(img):
			arc.former(FoudreV2.arbre(a, a.lerp(b, 0.5), b, rng, 0.0), a, b, img, rng)
			formes.append(img)
	var ecarts_ok := true
	for i in range(1, formes.size()):
		var e := formes[i] - formes[i - 1]
		if e < FoudreV2.REGEN_MIN or e > FoudreV2.REGEN_MAX:
			ecarts_ok = false
	verifier(ecarts_ok and formes.size() >= 200 / FoudreV2.REGEN_MAX, "cadence : %d formes en 200 images, écart 2 à 4 images" % formes.size())
	# --- canalisation par le contrat EffetsMagie
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.position = Vector3(0, 1.6, 4)
	cam.current = true
	var main_g := Node3D.new()
	cam.add_child(main_g)
	main_g.position = Vector3(-0.25, -0.2, -0.45)
	var g := GestionMagie.obtenir()
	await process_frame
	for v1 in [false, true]:
		GestionMagie.foudre_v1 = v1
		var max_vis := 0
		var max_formes := 0
		var depart_ok := true
		var n_formes := 0
		for i in 90:
			EffetsMagie.jet("electricite", main_g, -cam.global_basis.z, 8.0, 0.5, true)
			await process_frame
			var j: Dictionary = g._jets.get(main_g.get_instance_id(), {})
			if v1:
				continue
			var cn: FoudreV2.Canal = j.get("foudre")
			if cn == null:
				depart_ok = false
				continue
			max_vis = maxi(max_vis, cn.nb_arcs_visibles())
			max_formes = maxi(max_formes, cn.formes_image)
			n_formes += cn.formes_image
			var jr: Dictionary = FoudreV2.journal
			for p in jr.get("departs", []):
				if (p as Vector3).distance_to(jr.o) > 0.25:
					depart_ok = false
		var jj: Dictionary = g._jets.get(main_g.get_instance_id(), {})
		if v1:
			verifier(jj.get("foudre") == null, "--foudre-v1 : pas de Canal (ancien rendu)")
		else:
			verifier(jj.get("foudre") != null and jj.get("decharge") == null and jj.get("faisceau") == null, "v2 : un Canal, ni décharge ni faisceau v1")
			verifier(max_vis > 0 and max_vis <= FoudreV2.MAX_ARCS_CANAL, "v2 : arcs visibles %d (1..%d)" % [max_vis, FoudreV2.MAX_ARCS_CANAL])
			verifier(depart_ok, "v2 : tous les arcs partent des doigts (< 25 cm de la paume)")
			# 90 images, 4 arcs, une forme toutes les 2-4 images : entre 90 et 180 formes
			verifier(n_formes >= 80 and n_formes <= 190, "v2 : %d nouvelles formes en 90 images (4 arcs, 2-4 images chacun)" % n_formes)
		EffetsMagie.jet("electricite", main_g, Vector3.FORWARD, 8.0, 0.5, false)
		for i in 5:
			await process_frame
	GestionMagie.foudre_v1 = false
	# --- chaîne
	var pts: Array[Vector3] = [Vector3(0, 1.4, 3.5), Vector3(0, 1.0, -4), Vector3(2, 1.0, -5), Vector3(4, 1.0, -5)]
	EffetsMagie.chaine("electricite", pts)
	await process_frame
	await process_frame
	verifier(g._chaines.size() == 1, "chaîne v2 : une chaîne d'arcs structurés")
	var t0 := Time.get_ticks_msec()
	while not g._chaines.is_empty() and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	verifier(g._chaines.is_empty(), "chaîne v2 : éteinte après sa durée")
	# --- autres sorts électriques : éclair ramifié = arbre (orage, tempête, impact, lame), disques sans runes, particules allégées
	g._teinte_gen = "electricite"
	var tr: Array = []
	g.foudre_ramifiee(tr, Vector3.ZERO, Vector3(0, 0, -6), 0.4, 3.0, 3, 5)
	g._teinte_gen = ""
	var niveaux := {}
	for t in tr:
		if t.size() > 3:
			niveaux[int(t[3])] = true
	verifier(tr.size() >= 4 and niveaux.has(0) and niveaux.has(1), "éclair ramifié v2 : arbre tronc + branches (%d traits, niveaux %s)" % [tr.size(), niveaux.keys()])
	var dv := GestionMagie._disque_v2({"couleur": "#4a3ad0", "runes": 0.9, "texels": 64.0, "epaisseur": 0.05, "remplissage": 0.12, "eclat": 1.4})
	verifier(float(dv.runes) == 0.0 and float(dv.texels) == 128.0, "disque électrique v2 : sans runes, texels doublés")
	GestionMagie.foudre_v1 = true
	var pe1 := g.emettre("elec_impact", null, Transform3D.IDENTITY, false, 1.0)
	GestionMagie.foudre_v1 = false
	var pe := g.emettre("elec_impact", null, Transform3D.IDENTITY, false, 1.0)
	var n1 := pe1.amount if pe1 != null else -1
	var n2 := pe.amount if pe != null else -1
	verifier(n1 > 0 and n2 > 0 and n2 <= ceili(n1 * 0.36) + 1, "particules électriques v2 allégées (%d contre %d en v1)" % [n2, n1])
	var nd := g.get_child_count()
	g._decharge_ponctuelle(Vector3.ZERO, Vector3(0, 0, -2), 0.3)
	verifier(g.get_child_count() == nd, "v2 : plus de décharge ponctuelle (formes d'atlas)")
	print("ECHECS %d" % echecs)
	print("TEST %s" % ("OK" if echecs == 0 else "ÉCHEC"))
	quit(0 if echecs == 0 else 1)
