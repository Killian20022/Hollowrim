extends SceneTree
## Planches et film du DÉMEMBREMENT (étape 1 : draugr, bandit) dans scenes/test_combat.tscn (FENÊTRE hors écran, godot_slot.sh) :
##   godot --path . --script res://outils/captures_demembrement.gd -- --sortie=<dossier> [--membres=tete,bras_l,...]
##         [--genres=guerrier,bandit] [--film] [--nuit]
## Par membre et gabarit : planche de 8 vues (caméra témoin de trois quarts, à 2,6 m) de l'instant de la coupe à 2,5 s, + une vue
## FPS (caméra du joueur) ; « sang_sol » : vue plongeante des flaques et traces après les coupes ; « entailles » : coups non
## mortels sur un draugr et un bandit vivants (plaies aux points d'impact, orientées selon la lame), puis le même corps mort.
## --film : enchaîne tout en continu (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- »).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const INSTANTS := [0.0, 0.08, 0.2, 0.4, 0.7, 1.1, 1.7, 2.5]
## Coup par membre : hauteur relative du point, sens de la lame (repère : +X = droite du joueur), attaque.
const COUPS := {
	"tete": [0.85, Vector3(1, -0.05, 0), "legere"],
	"bras_l": [0.68, Vector3(1, -0.8, 0), "legere"],
	"bras_r": [0.68, Vector3(-1, -0.8, 0), "legere"],
	"avantbras_r": [0.55, Vector3(-1, -0.7, 0), "legere"],
	"jambe_r": [0.32, Vector3(1, -0.3, 0), "lourde"],
	"mollet_l": [0.15, Vector3(1, -0.1, 0), "lourde"],
	"moitie": [0.52, Vector3(1, -0.1, 0), "chargee_max"],
}

var s: Node3D
var sortie := ""
var film := false
var _n := 0
var _cam: Camera3D
var _x := -10.0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _attendre(t: float) -> void:
	var fin := Time.get_ticks_msec() + int(t * 1000.0)
	if film:
		for i in maxi(1, roundi(t * 30.0)):
			await process_frame
		return
	while Time.get_ticks_msec() < fin:
		await process_frame

func _planche(nom: String, images: Array, colonnes: int, w := 480, h := 270) -> void:
	if film or images.is_empty():
		return
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % colonnes) * w, (i / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

func _ennemi(genre: String, pos: Vector3, lacet: float) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "capt_demembre_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 300.0
	d.vie_max = 300.0
	d.combat.profil.chance_blocage = 0.0
	d.set_physics_process(false)
	return d

func _info(d: Node3D, rel: float, dir_ecran: Vector3, attaque: String) -> Dictionary:
	var vers: Vector3 = s.joueur.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	var droite: Vector3 = -vers.cross(Vector3.UP)    # droite du joueur qui regarde la cible
	var dir := (droite * dir_ecran.x + Vector3.UP * dir_ecran.y - vers * 0.3).normalized()
	return {"type": "tranchant", "point": d.global_position + Vector3(0, 1.8 * rel * d.modele.scale.y, 0) + vers * 0.2,
		"direction": dir, "normale": vers, "attaque": attaque, "instant": 0.1, "charge": 1.0 if attaque == "chargee_max" else 0.0}

## Caméra témoin sur le flanc de la cible (perpendiculaire au joueur, un peu en avant) ; le corps du joueur est caché.
func _temoin(cible: Vector3, haut := 1.1, dist := 2.6, cote := 1.0) -> void:
	var vj: Vector3 = s.joueur.global_position - cible
	vj.y = 0.0
	vj = vj.normalized()
	var lat := Vector3.UP.cross(vj) * cote
	_cam.global_position = cible + lat * dist + vj * dist * 0.35 + Vector3(0, haut, 0)
	_cam.look_at(cible + Vector3(0, haut * 0.55, 0) - vj * 0.3, Vector3.UP)
	_cam.current = true
	s.joueur.visible = false

func _cas(genre: String, membre: String) -> void:
	var lacet := 0.0
	_x += 2.4
	var pos := Vector3(_x, 0.0, -1.9)
	s.placer_joueur(Vector3(_x, 0, 0), 0.0)
	var d := _ennemi(genre, pos, lacet)
	d.set_physics_process(true)
	await _attendre(0.5)
	d.set_physics_process(false)
	Demembrement.membre_force = membre
	Demembrement.chance_forcee = 1.0
	var c: Array = COUPS[membre]
	_temoin(d.global_position, 1.0, 2.1 if membre != "moitie" else 2.6, -1.0 if membre.ends_with("_l") else 1.0)
	var images: Array = []
	if not film:
		images.append(await _image())
	d.vie = 1.0
	d.recevoir_coup(50.0, s.joueur.global_position, String(c[2]) == "chargee_max", _info(d, c[0], c[1], c[2]))
	var t := 0.0
	for ti: float in INSTANTS:
		await _attendre(ti - t)
		t = ti
		if not film:
			images.append(await _image())
	# vue FPS (caméra du joueur) à la fin
	s.joueur.visible = true
	s.joueur.camera.current = true
	await _attendre(0.05 if not film else 0.8)
	if not film:
		images.append(await _image())
	_planche("%s_%s" % [membre, genre], images, int(_arg("colonnes", "5")))
	Demembrement.membre_force = ""
	Demembrement.chance_forcee = -1.0
	d.set_meta("a_effacer", true)

func _entailles(genre: String) -> void:
	_x += 2.4
	s.placer_joueur(Vector3(_x, 0, 0), 0.0)
	var d := _ennemi(genre, Vector3(_x, 0.0, -1.7), 0.0)
	d.set_physics_process(true)
	await _attendre(0.5)
	d.set_physics_process(false)
	Demembrement.chance_forcee = 0.0
	var images: Array = []
	_temoin(d.global_position, 1.3, 1.9, -0.5)
	var coups := [[0.66, Vector3(1, -0.7, 0)], [0.55, Vector3(-1, -0.4, 0)], [0.75, Vector3(1, 0.1, 0)], [0.4, Vector3(-1, -0.9, 0)], [0.6, Vector3(0.2, -1, 0)]]
	for k in coups.size():
		var cp: Array = coups[k]
		d.vie = 300.0
		d.recevoir_coup(12.0, s.joueur.global_position, false, _info(d, cp[0], cp[1], "legere"))
		d.set_physics_process(false)
		await _attendre(0.35)
		if k % 2 == 1 and not film:
			images.append(await _image())
	_temoin(d.global_position, 1.3, 1.5, -0.25)
	await _attendre(0.2)
	if not film:
		images.append(await _image())
	# le même corps, mort (ragdoll) : les plaies restent
	d.vie = 1.0
	d.recevoir_coup(30.0, s.joueur.global_position, false, _info(d, 0.6, Vector3(1, -0.5, 0), "legere"))
	await _attendre(2.2)
	_cam.global_position = d.global_position + Vector3(0.9, 1.4, 1.1)
	var bassin := d.global_position
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	for a in sq.get_children():
		if a is BoneAttachment3D and (a as BoneAttachment3D).bone_name == "spine_02" or (a is BoneAttachment3D and (a as BoneAttachment3D).bone_name == "spine_03"):
			bassin = (a as Node3D).global_position
	_cam.global_position = bassin + Vector3(0.7, 1.1, 0.8)
	_cam.look_at(bassin, Vector3.UP)
	_cam.current = true
	await _attendre(0.1)
	if not film:
		images.append(await _image())
	_planche("entailles_%s" % genre, images, 3)
	Demembrement.chance_forcee = -1.0
	d.set_meta("a_effacer", true)

func _effacer() -> void:
	for n in s.get_children():
		if n.has_meta("a_effacer"):
			n.queue_free()

func _go() -> void:
	sortie = _arg("sortie", "user://captures_demembrement")
	film = _arg("film") != ""
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	var o := {"draugr": "aucun", "sans-aide": ""}
	if _arg("nuit") != "":
		o["nuit"] = ""
	s.options = o
	root.add_child(s)
	current_scene = s
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(30, 0, 30)
	s.joueur.mains.pas_manuel = true
	# long mur proche derrière les cibles : éclaboussures murales
	s.mur.global_position = Vector3(-30, 1.3, 30)
	s._boite_statique(Vector3(0.0, 1.3, -3.3), Vector3(40.0, 2.6, 0.3), (s.mur.get_child(1) as MeshInstance3D).material_override)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	s.add_child(_cam)
	Sang.niveau_force = 2
	for i in 40:
		await process_frame
	var membres := _arg("membres", "tete,bras_l,avantbras_r,jambe_r,mollet_l,moitie").split(",")
	var genres := _arg("genres", "guerrier,bandit").split(",")
	for g in genres:
		for m in membres:
			await _cas(g, m)
	# sang au sol et au mur après les coupes (les 3 dernières : morceaux et traces encore là)
	_cam.global_position = Vector3(_x - 1.0, 3.2, 1.0)
	_cam.look_at(Vector3(_x - 2.4, 0, -2.2), Vector3.UP)
	_cam.current = true
	await _attendre(0.3)
	if not film:
		var im := await _image()
		_cam.global_position = Vector3(_x + 0.8, 1.4, -0.6)
		_cam.look_at(Vector3(_x - 2.0, 0.5, -3.1), Vector3.UP)
		await _attendre(0.1)
		_planche("sang_sol", [im, await _image()], 2)
	for g in genres:
		await _entailles(g)
		_effacer()
	print("CAPTURES DEMEMBREMENT : fini")
	quit()
