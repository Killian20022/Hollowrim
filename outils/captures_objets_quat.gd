extends SceneTree
## Captures EN JEU des objets ramassables en props Quaternius texturés (ObjetsQuat, champ modele_quat) : AVANT | APRÈS, même cadrage.
##   godot --path . --disable-vsync --script res://outils/captures_objets_quat.gd -- --nouvelle --paisible --sortie=<dossier> --nom=apres
##   (avant : la même commande avec --props-quat-ancien --nom=avant)
## Images : <nom>_1_sol_pres.png (objets posés sur la place), <nom>_2_sol_homme.png (même rangée à hauteur d'homme),
## <nom>_3_neige.png (dans la neige), <nom>_4_lache.png (sac lâché : tas + bourse), <nom>_5_main_<genre>.png (objet vivant tenu, E maintenu).
## Avec fenêtre (godot_slot.sh : hors écran).

const SCENE := preload("res://scenes/foret_test.tscn")
const RANG := ["potion_soin", "potion_mana", "potion_soin_forte", "potion_endurance", "tome_boule_feu", "tome_lance_givre",
	"cle_archives", "coupe_argent", "chope", "hydromel", "chandelier", "parchemin"]
const TENUS := ["q_chope", "q_bouteille_1", "q_assiette", "q_livre_7", "q_chandelier_table"]
var _dossier := ""
var _nom := "apres"
var m: Node3D
var j: CharacterBody3D
var _poses: Array[Node3D] = []

func _init() -> void:
	_go.call_deferred()

func _att(n: int) -> void:
	for i in n:
		await process_frame

func _cap(nom: String) -> void:
	await _att(10)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_dossier)
	var im := root.get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	im.save_png(_dossier.path_join("%s_%s" % [_nom, nom]))
	print("CAPTURE ", _nom, "_", nom)

func _sol(x: float, z: float) -> float:
	var h := float(m.hauteur(x, z))
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z))
	q.exclude = [j.get_rid()]
	var r := m.get_world_3d().direct_space_state.intersect_ray(q)
	var y := float(r["position"].y) if not r.is_empty() else h
	return y + ObjetMonde.hausse_sol(Vector3(x, y, z), m)

func _regarder(pied: Vector3, cible: Vector3) -> void:
	j.set_physics_process(false)
	j.velocity = Vector3.ZERO
	j.global_position = pied + Vector3(0, 0.05, 0)
	var off := pied - cible
	j.rotation.y = atan2(off.x, off.z)
	var oeil: Vector3 = j.camera.global_position
	j.tete.rotation.x = -atan2(oeil.y - cible.y, Vector2(off.x, off.z).length())

func _vider() -> void:
	for n in _poses:
		if is_instance_valid(n):
			n.queue_free()
	_poses.clear()

func _rangee(c: Vector3) -> void:
	for i in RANG.size():
		var o := ObjetMonde.creer(RANG[i])
		m.add_child(o)
		var x := c.x + (i % 6 - 2.5) * 0.26
		var z := c.z + (i / 6) * 0.32
		o.global_position = Vector3(x, _sol(x, z), z)
		o.rotation.y = 0.25 * (i % 3 - 1)
		_poses.append(o)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_dossier = a.substr(9)
		elif a.begins_with("--nom="):
			_nom = a.substr(6)
	print("OBJETS_QUAT actif=", ObjetsQuat.actif)
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	for i in 2400:
		await process_frame
		if m.village != null and m.village.get("prets") == true:
			break
	j = m.joueur
	m.cycle.heure = 12.0
	m.cycle._process(0.0)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	j.mains.visible = false
	for l: Array in m.hud.lieux_nommes:
		m.hud.lieux_vus[l[2]] = true
	m.hud.aide_t = 0.0
	await _att(20)
	# 1. rangée sur la place (pavés), de près puis à hauteur d'homme
	var c := Vector3(38.2, 0.0, 44.4)
	_rangee(c)
	var cible := Vector3(c.x, _sol(c.x, c.z + 0.16), c.z + 0.16)
	_regarder(Vector3(c.x, _sol(c.x, c.z - 0.8), c.z - 0.8), cible)
	await _att(20)
	await _cap("1_sol_pres.png")
	_regarder(Vector3(c.x + 0.5, _sol(c.x + 0.5, c.z - 2.2), c.z - 2.2), cible)
	await _att(10)
	await _cap("2_sol_homme.png")
	_vider()
	# 2. dans la neige (hors pavés), au nord de la place
	var cn := Vector3(30.0, 0.0, 58.0)
	_rangee(cn)
	var cible_n := Vector3(cn.x, _sol(cn.x, cn.z + 0.16), cn.z + 0.16)
	_regarder(Vector3(cn.x, _sol(cn.x, cn.z - 0.85), cn.z - 0.85), cible_n)
	await _att(15)
	await _cap("3_neige.png")
	_vider()
	# 3. objets lâchés : un tas de 6 (4 montrés + bourse / sacoche pour le surplus)
	var b := Node3D.new()
	b.set_script(preload("res://scripts/butin.gd"))
	b.joueur = j
	b.hud = m.hud
	b.nom_corps = Lacher.NOM
	b.contenu = {"potion_soin": 1, "potion_mana": 1, "tome_drain_vie": 1, "chope": 1, "minerai_fer": 2, "cle_maison": 1}
	b.cle_sauvegarde = "lache:capture_quat"
	m.add_child(b)
	var pl := Vector3(c.x + 1.5, 0.0, c.z + 1.0)
	b.global_position = Vector3(pl.x, _sol(pl.x, pl.z), pl.z)
	_regarder(Vector3(pl.x, _sol(pl.x, pl.z - 1.3), pl.z - 1.3), b.global_position)
	await _att(15)
	await _cap("4_lache.png")
	b.queue_free()
	# 4. en main : objets vivants de la halle saisis (E maintenu), devant la caméra
	j.set_physics_process(true)
	var ov: ObjetsVivants = m.objets_vivants
	var ip: Interieur = m.village.interieur("halle")
	j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
	j.velocity = Vector3.ZERO
	await _att(20)
	var halle := ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.ident.begins_with("halle:"))
	var pris := {}
	for o: ObjetVivant in halle:
		if o.genre in TENUS and not pris.has(o.genre) and not o.coince:
			pris[o.genre] = o
	for g: String in TENUS:
		if not pris.has(g):
			print("INFO pas de ", g, " dans la halle")
			continue
		var o: ObjetVivant = pris[g]
		j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
		j.rotation.y = ip.global_rotation.y + deg_to_rad(25.0)
		j.tete.rotation.x = deg_to_rad(-8.0)
		j.velocity = Vector3.ZERO
		await _att(4)
		if not ov.saisir(o):
			print("INFO saisie refusée ", g)
			continue
		ov._dist_tenu = 0.75
		await _att(40)
		await _cap("5_main_%s.png" % g)
		ov.lacher()
		await _att(10)
	print("CAPTURES %s dans %s" % [_nom, _dossier])
	quit(0)
