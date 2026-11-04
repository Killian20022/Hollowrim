extends SceneTree
## Sonde (headless) : double magie au lancer, image par image : états, gestes, IK du bras droit, paumes dans le repère caméra.
##   godot --headless --fixed-fps 60 --path . --script res://outils/sonde_double_main.gd -- --nouvelle [--sort=trait_ombre]

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

func _init() -> void:
	_go.call_deferred()

func _arg(n: String, d := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.split("=", true, 1)[1]
	return d

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	var j = s.joueur
	var mains = j.mains
	var magie: MainSort = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	for i in 20:
		await physics_frame
	var sort := _arg("sort", "trait_ombre")
	magie.equiper("gauche", sort)
	magie.equiper("droite", sort)
	for i in 60:
		mains.avancer(DT)
		await physics_frame
	var cam: Camera3D = j.camera
	for f in 70:
		if f == 2:
			magie.appuyer("gauche")
			magie.appuyer("droite")
		if f == 8:
			magie.relacher("gauche")
			magie.relacher("droite")
		mains.avancer(DT)
		await physics_frame
		var l := []
		for m in ["gauche", "droite"]:
			var i: Incantation = magie.inc[m]
			var p: Node3D = magie._p(m)
			var loc := cam.global_transform.affine_inverse() * p.global_position
			var e: Dictionary = magie.gestes._etat[m]
			l.append("%s %s%s g=%s/%s loc=(%.2f,%.2f,%.2f)" % [m[0], i.nom(), "*" if i.meneuse else "", e.geste, e.phase, loc.x, loc.y, loc.z])
		print("%02d infl_d=%.2f | %s" % [f, float(magie._infl_d), " | ".join(l)])
	quit(0)
