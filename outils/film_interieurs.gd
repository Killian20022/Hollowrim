extends SceneTree
## Film (≈ 16 s) des bâtiments ouverts (retours exe 5) : on s'approche d'une maison, on ouvre la porte, on entre, on fait le tour
## de la pièce du regard, on ressort.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_interieurs.gd -- --nouvelle --sans-mains --lits-provisoires [--bat=h1] [--heure=12]
## (fenêtre hors écran via godot_slot.sh). Caméra menée à la main dans le repère du bâtiment : plan reproductible.
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.split("=")[1]
	return defaut

## Caméra au point `p` (repère de l'intérieur, sol), regardant vers le point `c` (repère de l'intérieur).
func _cam(ip: Interieur, p: Vector3, c: Vector3) -> void:
	var g := ip.to_global(Vector3(p.x, ip.sol_y + 0.02, p.z))
	j.global_position = g
	j.velocity = Vector3.ZERO
	var cg := ip.to_global(c)
	var d := cg - (g + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	j.vie = 100000.0
	j.set_physics_process(false)
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = float(_arg("heure", "17.5"))
	m.cycle._process(0.0)
	j.camera.fov = 70.0
	var ip: Interieur = m.village.interieur(_arg("bat", "h1"))
	var zp := ip.porte_locale.z - 0.05
	var xd := ip.porte_locale.x
	var a := ip.demi
	var y_oeil := ip.sol_y + 1.6
	# trajet : [t (s), position, point visé] ; interpolation lissée entre les clés
	var cles := [
		[0.0, Vector3(xd - 0.5, 0, zp + 7.5), Vector3(xd, y_oeil - 0.2, zp)],
		[3.0, Vector3(xd - 0.1, 0, zp + 2.3), Vector3(xd, y_oeil - 0.7, zp - 1.0)],
		[4.6, Vector3(xd + 0.1, 0, zp + 1.3), Vector3(xd, y_oeil - 0.4, zp - 2.0)],
		[7.0, Vector3(xd, 0, zp - 1.2), Vector3(-a.x * 0.6, y_oeil - 0.5, -a.y)],
		[9.5, Vector3(xd * 0.5, 0, zp - 1.6), Vector3(a.x, y_oeil - 0.4, -a.y * 0.4)],
		[11.5, Vector3(xd * 0.5, 0, zp - 1.6), Vector3(a.x * 0.3, y_oeil + 0.6, a.y * 0.3)],
		[12.6, Vector3(xd * 0.5, 0, zp - 1.4), Vector3(xd, y_oeil - 0.3, zp + 3.0)],
		[15.6, Vector3(xd - 1.3, 0, zp + 3.4), Vector3(xd - 4.0, y_oeil - 0.2, zp + 9.0)],
	]
	_cam(ip, cles[0][1], cles[0][2])
	for i in 150:      # le village vit, l'intérieur se charge à l'approche
		await process_frame
	var total := int(15.6 * 30.0)
	var ouverte := false
	print("FILM début (%s, %s)" % [ip.id, ip.nom])
	for i in total + 1:
		var t := float(i) / 30.0
		var k := 0
		while k < cles.size() - 2 and t > float(cles[k + 1][0]):
			k += 1
		var t0: float = cles[k][0]
		var t1: float = cles[k + 1][0]
		var u := smoothstep(0.0, 1.0, clampf((t - t0) / (t1 - t0), 0.0, 1.0))
		var pos: Vector3 = (cles[k][1] as Vector3).lerp(cles[k + 1][1], u)
		var vise: Vector3 = (cles[k][2] as Vector3).lerp(cles[k + 1][2], u)
		if t >= 3.2 and not ouverte:
			ip.basculer(true)
			ouverte = true
		_cam(ip, pos, vise)
		await process_frame
	print("FILM fini")
	quit(0)
