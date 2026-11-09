extends SceneTree
## Film des OBJETS VIVANTS (preuves, lot « objets ») dans la halle de Gunnar, vue du joueur (FPS) :
##   1. un sort de feu frappe une table servie : chopes, assiettes et vivres sont projetés, retombent et se rendorment ;
##   2. on vise une miche : « Voler Pain de seigle (3) » en rouge, E : elle part au sac ;
##   3. on saisit une pomme (E maintenu), on la lance à travers la halle.
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_objets_vivants.gd -- --nouvelle --paisible --sortie=<dossier>
## Images : <dossier>/f_00000.png …

const SCENE := preload("res://scenes/foret_test.tscn")

var s: Node3D
var j: CharacterBody3D
var ov: ObjetsVivants
var sortie := ""
var n := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _filmer(k: int) -> void:
	for i in k:
		await _image()

## Le joueur regarde le point `p` (lacet du corps, tangage de la tête).
func _regarder(p: Vector3) -> void:
	var o: Vector3 = j.camera.global_position
	var d := p - o
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _proche(l: Array, genre: String, de: Vector3) -> ObjetVivant:
	var best: ObjetVivant = null
	for o: ObjetVivant in l:
		if o.genre == genre and not o.has_meta("pris") and not o.coince and (best == null or o.global_position.distance_to(de) < best.global_position.distance_to(de)):
			best = o
	return best

func _go() -> void:
	sortie = _arg("sortie", "user://film_objets")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	j = s.joueur
	ov = s.objets_vivants
	s.cycle.heure = 20.0
	var ip: Interieur = s.village.interieur("halle")
	var halle := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.ident.begins_with("halle:"))
	# table servie côté +X (Interieur halle : tables en x = ±3,9, z = -1,75, plateau à 0,78 m) : le joueur se tient du côté de la nef,
	# l'œil 1,3 m devant le plateau, et regarde la table de haut (aide des touches et annonces coupées, bras masqués : on voit les objets)
	var centre := ip.to_global(Vector3(3.9, ip.sol_y + 0.8, -1.75))
	for l: Array in s.hud.lieux_nommes:
		s.hud.lieux_vus[l[2]] = true
	s.hud.aide_t = 0.0
	j.mains.visible = false
	j.global_position = ip.to_global(Vector3(3.6, ip.sol_y + 0.02, -0.25))
	j.velocity = Vector3.ZERO
	for i in 40:
		await process_frame
	_regarder(centre + Vector3(0, -0.15, 0))
	await _filmer(30)
	# 1. boule de feu au milieu de la table
	EffetsMagie.impact("feu", centre + Vector3(0, 0.05, 0), Vector3.UP, 1.4)
	await _filmer(35)
	var sol := ip.to_global(Vector3(3.9, ip.sol_y, -0.9))      # le regard descend vers le plancher, où les objets ont roulé
	for k in 25:
		_regarder((centre + Vector3(0, -0.15, 0)).lerp(sol, (k + 1) / 25.0))
		await _image()
	await _filmer(40)
	centre = sol
	# 2. viser une miche, la voler
	var pain := _proche(halle, "q_pain", j.global_position)
	if pain != null:
		for k in 20:
			_regarder(centre.lerp(pain.global_position, (k + 1) / 20.0))
			await _image()
		await _filmer(25)
		ov._viser()
		ov.prendre(pain)
		await _filmer(35)
	# 3. saisir une pomme, la lancer vers le foyer
	var pomme := _proche(halle, "q_pomme", j.global_position)
	if pomme == null:
		pomme = _proche(halle, "q_cuisse", j.global_position)
	if pomme != null:
		for k in 15:
			_regarder((centre if pain == null else pain.global_position).lerp(pomme.global_position, (k + 1) / 15.0))
			await _image()
		await _filmer(10)
		ov.saisir(pomme)
		await _filmer(25)
		var loin := ip.to_global(Vector3(-3.0, ip.sol_y + 1.6, 0.0))
		var vu: Vector3 = j.camera.global_position - j.camera.global_transform.basis.z * 2.0
		for k in 20:
			_regarder(vu.lerp(loin, (k + 1) / 20.0))
			await _image()
		ov.lancer()
		await _filmer(60)
	print("FILM %d images dans %s" % [n, sortie])
	quit(0)
