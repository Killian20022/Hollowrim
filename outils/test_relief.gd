extends SceneTree
## Test sans fenêtre du RELIEF de la neige (scripts/effets_sol.gd : profondeurs ; scripts/couche_neige.gd : grille) :
## empreinte de botte (talon + avant-pied, creux ~8 cm, bourrelet autour), course plus profonde + sillon, trou du feu avec lèvre,
## fondu en fin de vie, jamais sur l'eau / hors neige, placement de la grille par cases entières.
##   godot --headless --path . --script res://outils/test_relief.gd
var echecs := 0
var e: EffetsSol

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
	var monde := Node3D.new()
	root.add_child(monde)
	var joueur := Node3D.new()
	monde.add_child(joueur)
	joueur.position = Vector3(2, 0, 2)
	EffetsSol.forcer_neige = true
	await _images(4)
	e = EffetsSol.obtenir()
	await _images(3)
	e._suivre_joueur(joueur)

	# --- botte à la marche : le joueur regarde vers -z (dir = (0, -1)) ; pied gauche à +0,17 m en x
	e._empreinte(Vector3(2, 0, 2), Vector2(0, -1), true, false)
	var cx := 2.17
	var talon := e.profondeur(cx, 2.0 + 0.145)   # vers l'arrière (dir = -z) : le talon est à +z
	var avant := e.profondeur(cx, 2.0 - 0.085)
	verifier(avant > 0.05 and avant < 0.11, "marche : creux de l'avant-pied %.3f m (5 à 11 cm)" % avant)
	verifier(talon > 0.05 and talon < 0.11, "marche : creux du talon %.3f m" % talon)
	verifier(e.profondeur(cx, 2.0 + 0.145) > 0.0 and e.profondeur(cx + 0.45, 2.0) == 0.0, "marche : rien loin de la botte")
	var haut := 0.0
	for k in 40:
		haut = minf(haut, e.profondeur(cx + (k - 20) * 0.02, 2.0 - 0.085))
	verifier(haut < -0.02, "marche : bourrelet de neige repoussée sur le pourtour (%.3f m)" % haut)
	verifier(e.profondeur(2.0, 2.0 - 0.085) <= 0.0 and e.profondeur(cx - 0.34, 2.0 - 0.085) == 0.0, "marche : pas de creux entre les deux pieds ni sous l'autre pied")
	verifier(e.lire_relief(cx, 2.1).y > e.t + 20.0, "marche : le relief dure (fin dans %.0f s)" % (e.lire_relief(cx, 2.1).y - e.t))

	# --- course : plus profond, plus grand, sillon entre deux empreintes du même pied
	e.reinitialiser()
	e._empreinte(Vector3(10, 0, 10), Vector2(0, -1), true, true)
	var course := e.profondeur(10.21, 10.0 - 0.1)
	verifier(course > 0.09 and course < 0.14, "course : creux %.3f m (9 à 14 cm)" % course)
	e._empreinte(Vector3(10, 0, 8.1), Vector2(0, -1), true, true)
	var milieu := e.profondeur(10.21, 9.05)
	verifier(milieu > 0.03, "course : sillon traîné entre les deux empreintes (%.3f m)" % milieu)

	# --- fin de vie : le creux se rebouche (fondu sur 10 s) puis disparaît
	EffetsSol.saut_de_temps(EffetsSol.DUREE_RELIEF - 5.0)
	var mi := e.profondeur(10.21, 9.9)
	verifier(mi > 0.0 and mi < course, "fin de vie : creux à moitié rebouché (%.3f m)" % mi)
	EffetsSol.saut_de_temps(6.0)
	verifier(e.profondeur(10.21, 9.9) == 0.0, "fin de vie : relief effacé")

	# --- feu : le trou vient du masque de fonte (shader) ; la lèvre est écrite en relief
	e.reinitialiser()
	e.fondre(0.0, 0.0, 0.8)
	var levre := 0.0
	for k in 60:
		levre = minf(levre, e.profondeur(float(k) * 0.03 - 0.9, 0.0))
	verifier(levre <= -0.03, "feu : lèvre épaisse autour du trou (%.3f m)" % levre)
	verifier(e.lire(0.0, 0.0).x > e.t, "feu : le centre est fondu (masque)")

	# --- jamais hors neige
	EffetsSol.forcer_neige = false
	e.reinitialiser()
	var n0 := int(EffetsSol.stats["texels"])
	e._empreinte(Vector3(30, 0, 30), Vector2(0, -1), true, false)
	verifier(int(EffetsSol.stats["texels"]) == n0, "hors neige : aucun relief écrit")
	EffetsSol.forcer_neige = true

	# --- recentrage de la fenêtre : le relief posé reste lisible, la grille se cale sur les texels
	e.reinitialiser()
	e._empreinte(Vector3(2, 0, 2), Vector2(0, -1), true, false)
	e._centrer(Vector2(4.0, 3.0))
	verifier(e.profondeur(2.17, 2.0 - 0.085) > 0.05, "fenêtre recentrée : le creux est conservé")
	var g := CoucheNeige.new()
	monde.add_child(g)
	var p := g.placer(Vector2(3.337, -1.249))
	verifier(is_equal_approx(p.x * 16.0, roundf(p.x * 16.0)) and is_equal_approx(p.y * 16.0, roundf(p.y * 16.0)), "grille : coin aligné sur les texels de 1/16 m")
	verifier(absf(p.x + 7.0 - 3.337) <= 1.0 / 16.0 and absf(p.y + 7.0 + 1.249) <= 1.0 / 16.0, "grille : centrée sur le joueur (à un texel près)")
	g.free()
	var maillage := CoucheNeige._grille()
	verifier(maillage.get_surface_count() == 1 and maillage.surface_get_array_len(0) == 225 * 225, "grille : %d sommets (14 m, cases de 6,25 cm)" % maillage.surface_get_array_len(0))
	var cle := CoucheNeige._grille().get_aabb()
	verifier(cle.size.x > 13.5 and cle.size.x < 14.5, "grille : emprise 14 m")
	print("ECHECS : ", echecs)
	quit(0)
