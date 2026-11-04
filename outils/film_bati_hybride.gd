extends SceneTree
## Film de déambulation du bâti hybride (bati/hybride) : de l'entrée du village à la haute rue, vue de jeu 1re personne.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_bati_hybride.gd \
##         -- --nouvelle --paisible --sans-mains --heure=16.5 [--bati-ancien]
## Le joueur est déplacé le long d'un tracé (coordonnées MONDE, rues dégagées) à 1,8 m/s, regard dans le sens de la marche.
const DT := 1.0 / 30.0
const VITESSE := 1.8
## Entrée sud-ouest -> place -> entre H1 et l'auberge H2 -> rue -> escaliers de la haute rue (x 44, z 66-82 : H3 à l'ouest, H4 à
## l'est) -> haut de la rue, devant le porche de H5.
const TRACE := [Vector2(31.4, 28.6), Vector2(38.0, 34.0), Vector2(42.5, 38.7), Vector2(45.0, 44.0), Vector2(41.2, 48.5),
	Vector2(41.2, 56.0), Vector2(44.0, 61.0), Vector2(44.0, 83.0), Vector2(41.5, 83.0)]

var m: Node

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	while not m.pret:
		await process_frame
	for i in 90:      # chargement différé des intérieurs, ombres, brume
		await process_frame
	var j: CharacterBody3D = m.joueur
	j.process_mode = Node.PROCESS_MODE_DISABLED
	j.mains.visible = false     # décor seul : ni bras, ni torche, ni HUD
	if m.hud != null:
		m.hud.visible = false
	print("FILM debut image=%d" % Engine.get_frames_drawn())
	var lacet := _lacet(TRACE[1] - TRACE[0])
	for k in TRACE.size() - 1:
		var a: Vector2 = TRACE[k]
		var b: Vector2 = TRACE[k + 1]
		var n := maxi(1, roundi(a.distance_to(b) / (VITESSE * DT)))
		for i in n:
			var q := a.lerp(b, float(i) / n)
			var vise := _lacet(b - a)
			lacet = lerp_angle(lacet, vise, 0.05)
			j.global_position = Vector3(q.x, m.hauteur(q.x, q.y) + 0.1, q.y)
			j.rotation.y = lacet
			j.tete.rotation.x = deg_to_rad(3.0)
			await process_frame
	for i in 45:
		await process_frame
	print("FILM fini")
	quit(0)

## Lacet du joueur pour regarder dans la direction `d` (x, z monde) : avant = -Z local.
func _lacet(d: Vector2) -> float:
	return atan2(-d.x, -d.y)
