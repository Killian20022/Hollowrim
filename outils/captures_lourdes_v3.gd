extends SceneTree
## Armures lourdes HD v3 (branche armures/lourdes_hd_v3) : mêmes vues AVANT / APRÈS, sur le héros, scène de combat, shader ps1,
## de jour ou de nuit à la torche (--nuit : ambiance nocturne de test_combat + torche en main gauche) :
##   godot --path . --resolution 960x540 --script res://outils/captures_lourdes_v3.gd -- --nouvelle --sortie=<dossier>
##         [--variantes=avant,apres] [--familles=acier] [--nuit]
## avant = glb copiés (non suivis) dans assets/modeles/armures/_avant_v3/avant/{porte,sol}/ ; apres = glb du dépôt.
## Images <v>_<vue>.png.
const DT := 1.0 / 30.0
const AVANT := "res://assets/modeles/armures/_avant_v3/"
const FAMILLES := {
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"obsidienne": ["casque_obsidienne", "cuirasse_obsidienne", "gantelets_obsidienne", "bottes_obsidienne"],
	"or": ["casque_or", "cuirasse_or", "gantelets_or", "bottes_or"],
	"obsidienne_enchante": ["casque_obsidienne_enchante", "cuirasse_obsidienne_enchante", "gantelets_obsidienne_enchante", "bottes_obsidienne_enchante"],
	"or_enchante": ["casque_or_enchante", "cuirasse_or_enchante", "gantelets_or_enchante", "bottes_or_enchante"],
}
const PiecesEssai := preload("res://outils/pieces_essai.gd")
var s: Node
var j: CharacterBody3D
var cam: Camera3D
var l: Label
var sortie := ""
var variantes: Array = ["avant", "apres"]
var famille := "acier"
var nuit := false
var origine := {}
func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		_soleil_de_face()
		await process_frame

func _soleil_de_face() -> void:
	var c := root.get_viewport().get_camera_3d()
	if c == null or s.soleil == null:
		return
	var avant := -c.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		return
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	var dir := (avant + Vector3(0, -0.85, 0)).normalized()
	s.soleil.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), s.soleil.global_position)

func _version(v: String) -> void:
	for id: String in FAMILLES[famille]:
		var fi: Dictionary = Inventaire.OBJETS[id]
		if not origine.has(id):
			origine[id] = [fi.get("modele_porte", ""), fi.get("modele_sol", "")]
		if v == "apres":
			fi["modele_porte"] = origine[id][0]
			fi["modele_sol"] = origine[id][1]
		else:
			fi["modele_porte"] = AVANT + v + "/porte/" + id + ".glb"
			fi["modele_sol"] = AVANT + v + "/sol/" + id + ".glb"

func _equiper(ids: Array) -> void:
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.retirer(e)
	await _attendre(0.1)
	for id: String in ids:
		j.inventaire.ajouter(id, 1)
		var r: String = j.equipement_corps.equiper(id)
		if r != "":
			print("REFUS ", id, " : ", r)

func _capture(nom: String, rect: Rect2i, texte := "") -> void:
	_soleil_de_face()
	var k0 := root.get_viewport().get_visible_rect().size.y / 540.0
	l.text = texte
	l.position = Vector2(rect.position) * k0 + Vector2(4, 2)
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var k := img.get_height() / 540.0
	img = img.get_region(Rect2i(Vector2i(Vector2(rect.position) * k), Vector2i(Vector2(rect.size) * k)))
	if k != 1.0:
		img.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _placer_cam(deg: float, dist := 2.5, h := 1.0, hc := 1.15) -> void:
	var p := j.global_position
	var devant := -j.global_transform.basis.z
	var dir := devant.rotated(Vector3.UP, deg_to_rad(deg))
	cam.global_position = p + dir * dist + Vector3(0, hc, 0)
	cam.look_at(p + Vector3(0, h, 0), Vector3.UP)

## Caméra visant un os du squelette du héros (pose de combat : la tête et le buste sont plus bas qu'au repos).
func _placer_cam_os(deg: float, dist: float, os_nom: String, dh: float) -> void:
	var sq: Skeleton3D = j.corps.find_child("Skeleton3D", true, false)
	var cible := j.global_position + Vector3(0, 1.3, 0)
	if sq != null and sq.find_bone(os_nom) >= 0:
		cible = sq.global_transform * sq.get_bone_global_pose(sq.find_bone(os_nom)).origin
	var devant := -j.global_transform.basis.z
	var dir := devant.rotated(Vector3.UP, deg_to_rad(deg))
	cam.global_position = cible + dir * dist + Vector3(0, dh, 0)
	cam.look_at(cible, Vector3.UP)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--variantes="):
			variantes = a.substr(12).split(",")
		elif a.begins_with("--familles="):
			famille = a.substr(11)
		elif a == "--nuit":
			nuit = true
	PiecesEssai.injecter()
	DirAccess.make_dir_recursive_absolute(sortie)
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if nuit:
		s.options["nuit"] = ""
	root.add_child(s)
	j = s.joueur
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	j.basculer_vue(true)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != calque:
			(n as CanvasLayer).visible = false
	j.mains.magie.equiper("droite", "epee")
	j.mains.magie.equiper("gauche", "torche" if nuit else "vide")
	await _attendre(1.0)
	cam = Camera3D.new()
	cam.fov = 40.0
	s.add_child(cam)
	var ids: Array = FAMILLES[famille]
	for v: String in variantes:
		_version(v)
		var titre: String = {"avant": "AVANT", "apres": "APRES v3"}.get(v, v) + (" NUIT" if nuit else "")
		cam.current = true
		await _equiper(ids)
		await _attendre(0.6)
		# corps entier à 2 m (cadre serré, du genou à la tête) et à 5 m (lisibilité en 480 x 270)
		for vue in [["face", 0.0], ["tq", 40.0], ["profil", 90.0], ["dos", 180.0]]:
			_placer_cam(vue[1], 2.2, 1.1, 1.3)
			await _attendre(0.12)
			await _capture("%s_%s_2m" % [v, vue[0]], Rect2i(270, 0, 420, 540), "%s %s 2 m" % [titre, vue[0]])
		for vue in [["face", 0.0], ["tq", 40.0], ["dos", 180.0]]:
			_placer_cam(vue[1], 5.0, 0.95, 1.4)
			await _attendre(0.12)
			await _capture("%s_%s_5m" % [v, vue[0]], Rect2i(330, 60, 300, 420), "%s %s 5 m" % [titre, vue[0]])
		# bustes (gorgerin) avec et sans casque
		for vue in [["face", 0.0], ["tq", 35.0], ["profil", 90.0]]:
			_placer_cam_os(vue[1], 1.1, "neck_01", 0.1)
			await _attendre(0.12)
			await _capture("%s_buste_%s" % [v, vue[0]], Rect2i(240, 0, 480, 540), "%s buste %s" % [titre, vue[0]])
		j.equipement_corps.retirer("tete")
		await _attendre(0.3)
		for vue in [["face", 0.0], ["tq", 35.0], ["profil", 90.0]]:
			_placer_cam_os(vue[1], 1.1, "neck_01", 0.1)
			await _attendre(0.12)
			await _capture("%s_buste_sans_casque_%s" % [v, vue[0]], Rect2i(240, 0, 480, 540), "%s sans casque %s" % [titre, vue[0]])
		j.equipement_corps.equiper(ids[0])
		await _attendre(0.3)
		# gros plans
		for g in [["epaule", 70.0, 0.85, "clavicle_l", 0.06], ["coude", 95.0, 0.85, "lowerarm_l", 0.05], ["plastron", 10.0, 0.75, "spine_02", 0.05],
				["casque_face", 0.0, 0.62, "Head", 0.04], ["casque_profil", 90.0, 0.62, "Head", 0.04], ["genou", 25.0, 0.8, "calf_l", 0.08],
				["dos_haut", 160.0, 0.9, "spine_03", 0.1]]:
			_placer_cam_os(g[1], g[2], g[3], g[4])
			await _attendre(0.12)
			await _capture("%s_gp_%s" % [v, g[0]], Rect2i(240, 0, 480, 540), "%s gros plan %s" % [titre, g[0]])
		# au sol
		var poses: Array[Node3D] = []
		for i in ids.size():
			var n := ArmureVisible.instancier_sol(ids[i])
			if n == null:
				continue
			s.add_child(n)
			var devant := -j.global_transform.basis.z
			var cote := devant.cross(Vector3.UP)
			n.global_position = j.global_position + devant * 1.6 + cote * (-1.05 + 0.7 * i)
			n.rotation.y = j.rotation.y + PI
			poses.append(n)
		j.visible = false
		var c := j.global_position + (-j.global_transform.basis.z) * 1.6
		cam.global_position = c + (-j.global_transform.basis.z) * 1.6 + Vector3(0, 1.2, 0)
		cam.look_at(c + Vector3(0, 0.08, 0), Vector3.UP)
		await _attendre(0.2)
		await _capture("%s_sol" % v, Rect2i(120, 70, 720, 400), "%s pieces au sol" % titre)
		for n in poses:
			n.queue_free()
		j.visible = true
		# gantelets en vue FPS
		j.basculer_vue(false)
		j.mains.visible = true
		j.tete.rotation.x = -0.35
		await _attendre(1.2)
		await _capture("%s_fps" % v, Rect2i(0, 0, 960, 540), "%s gantelets FPS" % titre)
		j.tete.rotation.x = 0.0
		j.basculer_vue(true)
		await _attendre(0.3)
	print("FIN captures_lourdes_v3")
	quit(0)
