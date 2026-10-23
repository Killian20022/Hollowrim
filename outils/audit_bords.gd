extends SceneTree
## AUDIT DES BUGS — bords de la carte : le vrai joueur court vers chaque bord (tous les 8 m, plusieurs directions, avec sauts)
## et on vérifie qu'il ne passe jamais sous le terrain, ne sort pas de la zone et ne tombe pas dans le vide.
##   godot --headless --path . --script outils/audit_bords.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
const Base := preload("res://outils/audit_base.gd")
const PAS_BORD := 14.0
const DUREE := 3.0              # secondes simulées par essai
var m: Node3D
var R := Base.Rapport.new("bords")

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 6:
		await physics_frame
	var j: CharacterBody3D = m.joueur
	var limite: float = j.LIMITE
	R.stats["limite_joueur"] = limite
	R.stats["demi_terrain"] = m.TAILLE * 0.5
	var essais := 0
	var vide := 0
	var hors := 0
	var pire_sous := 0.0
	var lancers: Array = []
	# départs : chaque 8 m sur le carré de côté 2×(limite−4), direction vers l'extérieur (4 caps par point : normale ±30°, ±60°)
	var s := limite - 4.0
	var t := -s
	while t <= s + 0.01:
		lancers.append([Vector2(t, -s), Vector2(0, -1)])
		lancers.append([Vector2(t, s), Vector2(0, 1)])
		lancers.append([Vector2(-s, t), Vector2(-1, 0)])
		lancers.append([Vector2(s, t), Vector2(1, 0)])
		t += PAS_BORD
	j.set_physics_process(true)
	Input.action_press("course")
	Input.action_press("avant")
	for l in lancers:
		var p0: Vector2 = l[0]
		print("bords : départ ", p0, " essais ", essais)
		var dir: Vector2 = l[1]
		for ang in [0.0, 0.6]:
			var d := dir.rotated(ang)
			j.global_position = Vector3(p0.x, m.hauteur(p0.x, p0.y) + 0.3, p0.y)
			j.velocity = Vector3.ZERO
			j.vigueur = j.vigueur_max
			j.rotation.y = atan2(-d.x, -d.y)
			essais += 1
			var n := int(DUREE * 60.0)
			var y_rel_min := 0.0
			for f in n:
				if f % 50 == 25:
					Input.action_press("saut")
				elif f % 50 == 26:
					Input.action_release("saut")
				j.vigueur = j.vigueur_max
				await physics_frame
				var g := j.global_position
				y_rel_min = minf(y_rel_min, float(g.y - m.hauteur(g.x, g.z)))
				if g.y < -30.0:
					break
			var g := j.global_position
			var rel: float = g.y - m.hauteur(g.x, g.z)
			pire_sous = minf(pire_sous, y_rel_min)
			if rel < -1.0 or g.y < -30.0:
				vide += 1
				R.ajouter("chute_dans_le_vide", "bloquant", g, "le joueur passe %.1f m sous le sol en courant vers le bord depuis (%.0f, %.0f) cap (%.1f, %.1f)" % [-rel, p0.x, p0.y, d.x, d.y])
			if absf(g.x) > limite + 0.6 or absf(g.z) > limite + 0.6:
				hors += 1
				R.ajouter("sortie_de_zone", "bloquant", g, "le joueur dépasse la limite de %.0f m" % limite)
	Input.action_release("avant")
	Input.action_release("course")
	R.stats["essais"] = essais
	R.stats["chutes"] = vide
	R.stats["sorties"] = hors
	R.stats["plus_enfonce_sous_sol_m"] = snappedf(pire_sous, 0.01)
	# garde-fou : rien ne rattrape un joueur qui tomberait (pas de plan de mort / retour) → à noter
	var src := FileAccess.get_file_as_string("res://scripts/joueur.gd") + FileAccess.get_file_as_string("res://scripts/monde.gd")
	var filet := src.contains("y < -") or src.contains("position.y <") or src.contains("global_position.y <")
	R.stats["filet_de_securite_anti_chute"] = filet
	if not filet:
		R.ajouter("pas_de_filet", "gênant", Vector3.ZERO, "aucun garde-fou si le joueur passe sous la carte (pas de remontée/téléportation quand y < seuil) : une seule faille de collision = chute infinie")
	# le dernier mètre : hauteur du terrain sur le pourtour de la zone (le mur invisible est à la limite, le relief continue jusqu'à 120 m)
	var bas := INF
	var tt := -120.0
	while tt <= 120.0:
		for c in [Vector2(tt, -120), Vector2(tt, 120), Vector2(-120, tt), Vector2(120, tt)]:
			bas = minf(bas, m.hauteur(c.x, c.y))
		tt += 2.0
	R.stats["hauteur_mini_sur_le_bord_120m"] = snappedf(bas, 0.01)
	var bas2 := INF
	tt = -limite
	while tt <= limite:
		for c in [Vector2(tt, -limite), Vector2(tt, limite), Vector2(-limite, tt), Vector2(limite, tt)]:
			bas2 = minf(bas2, m.hauteur(c.x, c.y))
		tt += 2.0
	R.stats["hauteur_mini_sur_la_limite_joueur"] = snappedf(bas2, 0.01)
	R.ecrire()
	quit(0)
