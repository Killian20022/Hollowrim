extends SceneTree
## Test sans fenêtre du MONDE RÉACTIF SUR LA NEIGE (scripts/effets_sol.gd, glace_fondante.gd) : empreintes, fonte par le feu
## (durée 30-60 s, traînée d'un jet), blocs de glace (plafond, fonte accélérée par le feu), brûlures et ombres, fenêtre torique,
## effacement complet puis coût nul (effets_rect.w == 0), aucun effet hors neige.
##   godot --headless --path . --script res://outils/test_effets_sol.gd -- --nouvelle
var echecs := 0
var e: EffetsSol
var joueur: Node3D

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _lancer() -> void:
	# sol plat de collision
	var monde := Node3D.new()
	root.add_child(monde)
	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(400, 1, 400)
	cs.shape = bx
	sol.add_child(cs)
	sol.position = Vector3(0, -0.5, 0)
	monde.add_child(sol)
	joueur = Node3D.new()
	monde.add_child(joueur)
	joueur.position = Vector3(2, 0, 2)
	EffetsSol.forcer_neige = true
	EffetsMagie.muet = false
	await _images(4)
	e = EffetsSol.obtenir()
	await _images(3)
	verifier(e != null and e.is_node_ready(), "le nœud EffetsSol est créé")
	var rect: Vector4 = RenderingServer.global_shader_parameter_get("effets_rect") if RenderingServer.global_shader_parameter_get("effets_rect") != null else Vector4.ZERO
	verifier(not e._rect_actif and e._fin_vie <= e.t, "au repos : rien de vivant, le shader ne lit rien (coût nul)")
	var envois0 := int(EffetsSol.stats["envois"])
	await _images(10)
	verifier(int(EffetsSol.stats["envois"]) == envois0, "au repos : aucun envoi du masque")

	# --- empreintes
	e._joueur = joueur
	e._centrer(Vector2(2, 2))
	EffetsSol.empreinte_pas(joueur, Vector2(0, -4), true, false)
	EffetsSol.empreinte_pas(joueur, Vector2(0, -4), false, true)
	var v := e.lire(2.27, 2.0)
	verifier(v.z > e.t + 20.0, "pas : empreinte au pied gauche (fin dans %.1f s)" % (absf(v.z) - e.t))
	verifier(e.lire(2.0, 2.0).z == 0.0, "pas : le centre entre les deux pieds reste intact")
	verifier(e._rect_actif or e._fin_vie > e.t, "pas : le masque devient vivant")
	await _images(8)
	verifier(e._rect_actif and int(EffetsSol.stats["envois"]) > envois0, "pas : masque envoyé et lu par le shader")
	EffetsSol.saut_de_temps(DUREE_PAS_PLUS)
	await _images(5)
	verifier(e.lire(2.27, 2.0).z <= e.t, "pas : l'empreinte est expirée après %.0f s" % DUREE_PAS_PLUS)
	verifier(not e._rect_actif, "tout effacé : le shader ne lit plus rien")

	# --- saut / atterrissage
	EffetsSol.saut(joueur)
	EffetsSol.atterrissage(joueur, 9.0)
	verifier(e.lire(2.0, 2.0).z > e.t, "atterrissage : cuvette au point d'impact")

	# --- feu : impact
	EffetsMagie.impact("feu", Vector3(0, 0.05, 0), Vector3.UP, 1.5)
	var f := e.lire(0.0, 0.0)
	verifier(f.x - e.t >= 29.0 and f.x - e.t <= 61.0, "feu : neige fondue au centre, se reforme en %.0f s (30-60)" % (f.x - e.t))
	verifier(absf(f.y) >= 30.0 and absf(f.y) <= 60.0, "feu : durée stockée %.0f s" % absf(f.y))
	verifier(e.lire(1.4, 0.0).x <= e.t, "feu : rayon limité (rien à 1,4 m)")
	var bord := e.lire(0.9, 0.0).x
	verifier(bord == 0.0 or bord - e.t < f.x - e.t, "feu : le bord dure moins longtemps que le centre")
	EffetsSol.saut_de_temps(61.0)
	await _images(5)
	verifier(e.lire(0.0, 0.0).x <= e.t and not e._rect_actif, "feu : après 61 s la neige est revenue partout")

	# --- feu : jet continu = traînée
	var paume := Node3D.new()
	root.add_child(paume)
	for k in 12:
		paume.global_position = Vector3(-5.0 + k * 0.3, 0.5, -4.0)
		EffetsMagie.jet("feu", paume, Vector3.DOWN, 0.6, 1.0, true)
		EffetsSol.saut_de_temps(0.12)
		await process_frame
	var fondus := 0
	for k in 12:
		if e.lire(-5.0 + k * 0.3, -4.0).x > e.t:
			fondus += 1
	verifier(fondus >= 11, "jet : traînée continue (%d/12 points fondus)" % fondus)
	verifier(e.lire(-5.0, -2.5).x <= e.t, "jet : rien hors de la traînée")

	# --- glace : bloc, plafond, fonte, chaleur
	EffetsSol.saut_de_temps(61.0)
	await _images(3)
	EffetsMagie.impact("glace", Vector3(6, 0.05, 6), Vector3.UP, 1.2)
	await _images(3)
	verifier(e._blocs.size() == 1 and is_instance_valid(e._blocs[0]), "glace : un amas de glace posé à l'impact")
	var bloc: GlaceFondante = e._blocs[0]
	verifier(bloc.get_child_count() >= 2, "glace : bloc + pics en volume (%d pièces)" % bloc.get_child_count())
	var mat := (bloc.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	verifier(mat != null and mat.shader.resource_path.ends_with("magie_cristal.gdshader"), "glace : matière cristal de la magie")
	EffetsSol.saut_de_temps(GlaceFondante.TENUE + GlaceFondante.FONTE * 0.5)
	await _images(2)
	verifier(float(mat.get_shader_parameter("fonte")) > 0.2 and bloc.scale == Vector3.ONE, "glace : en train de fondre (fonte %.2f)" % float(mat.get_shader_parameter("fonte")))
	verifier(e.lire(6.0, 6.0).x > e.t and e.lire(6.0, 6.0).y < 0.0, "glace : flaque au pied du bloc")
	EffetsSol.saut_de_temps(40.0)
	await _images(3)
	verifier(not is_instance_valid(bloc) or bloc.is_queued_for_deletion(), "glace : l'amas a entièrement fondu")
	verifier(e.lire(6.0, 6.0).x <= e.t, "glace : la flaque a séché")
	# chaleur : fond bien plus vite
	EffetsMagie.impact("glace", Vector3(-8, 0.05, 6), Vector3.UP, 1.0)
	await _images(2)
	var b2: GlaceFondante = e._blocs[e._blocs.size() - 1]
	var age_avant := b2.age
	EffetsMagie.impact("feu", Vector3(-8, 0.05, 6.2), Vector3.UP, 1.5)
	b2.vieillir(0.5)
	verifier(b2.age > age_avant + 0.5 * 4.0, "feu + glace : fonte accélérée (âge %.1f en 0,5 s)" % b2.age)
	# plafond
	for k in 25:
		EffetsMagie.impact("glace", Vector3(-20 + k * 0.6, 0.05, 12), Vector3.UP, 1.0)
	await _images(2)
	var vivants := 0
	for b in e._blocs:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			vivants += 1
	verifier(vivants <= EffetsSol.MAX_BLOCS, "glace : plafond %d amas <= %d" % [vivants, EffetsSol.MAX_BLOCS])

	# --- électricité et ténèbres
	EffetsMagie.impact("electricite", Vector3(4, 0.05, -6), Vector3.UP, 1.0)
	verifier(e.lire(4.0, -6.0).w > e.t, "électricité : brûlure au sol")
	EffetsMagie.zone("tenebres", Vector3(8, 0.05, -6), 2.0, 3.0)
	var o := e.lire(8.0, -6.0).w
	verifier(o < -e.t, "ténèbres : tache d'ombre")
	EffetsSol.saut_de_temps(19.0)
	verifier(e.lire(8.0, -6.0).w >= -e.t, "ténèbres : la tache s'est résorbée en 19 s")

	# --- fenêtre torique : s'éloigner vide les bandes entrantes seulement
	EffetsMagie.impact("feu", Vector3(4, 0.05, 4), Vector3.UP, 1.0)
	verifier(e.lire(4.0, 4.0).x > e.t, "fenêtre : fonte posée")
	joueur.position = Vector3(40, 0, 40)
	EffetsSol.empreinte_pas(joueur, Vector2(0, -4), true, false)
	verifier(e.lire(4.0, 4.0) == Vector4.ZERO, "fenêtre : hors fenêtre après déplacement du joueur")
	verifier(e.lire(40.27, 40.0).z > e.t, "fenêtre : empreinte posée dans la nouvelle fenêtre")
	# --- hors neige : rien
	EffetsSol.forcer_neige = false
	var n0 := int(EffetsSol.stats["pas"])
	EffetsSol.empreinte_pas(joueur, Vector2(0, -4), true, false)
	verifier(int(EffetsSol.stats["pas"]) == n0, "hors neige : aucune empreinte")
	EffetsSol.actif = false
	EffetsSol.forcer_neige = true
	var n1 := int(EffetsSol.stats["pas"])
	EffetsSol.empreinte_pas(joueur, Vector2(0, -4), true, false)
	verifier(int(EffetsSol.stats["pas"]) == n1, "désactivé : aucun effet")
	EffetsSol.actif = true
	print("stats : ", EffetsSol.stats)
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)

const DUREE_PAS_PLUS := 26.0
