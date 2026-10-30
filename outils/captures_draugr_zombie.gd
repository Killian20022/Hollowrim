extends SceneTree
## Film et planche des draugrs « zombies » (draugr.gd option zombie, clips Zombie_*) dans la VRAIE crypte, salle « prep »
## (cr_prep_2 et cr_prep_3), en vue de jeu (caméra du joueur) ; FENÊTRE hors écran via godot_slot.sh :
##   godot --path . --write-movie <film.avi> --fixed-fps 30 --script res://outils/captures_draugr_zombie.gd -- --sortie=<dossier>
## Film : les deux zombies allongés, le premier se relève quand le joueur approche, titube, frappe à mains nues ; le second se relève
## et arrive ; le joueur frappe le premier (réactions capturées) puis le tue ; le second attaque. Les autres gardiens sont figés et
## cachés. FILM_FIN imprimé (nombre d'images du film, la fin de l'avi). Planche des poses : images du film assemblées par ffmpeg
## (select + crop + tile ; une planche faite ici avec une caméra à part ne rendait rien : le jeu rend par la caméra du joueur).
const SCENE := preload("res://scenes/foret_test.tscn")
const POSE_JOUEUR := Vector3(0.0, 0.0, -20.5)   # repère de la crypte, salle prep
const ZOMBIES := ["cr_prep_2", "cr_prep_3"]
var m: Node3D
var j: CharacterBody3D
var t: Node
var c: Node3D
var sortie := ""
var cible: Node3D
var _images := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.split("=", true, 1)[1]
	return defaut

func _init() -> void:
	_go.call_deferred()

func _attendre(s: float) -> void:
	for i in int(s * 30.0):
		await process_frame

func _go() -> void:
	sortie = _arg("sortie", "res://captures/draugr_zombie")
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourImpact.muet = true
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	j = m.joueur
	for i in 5:
		await physics_frame
	t = m.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	c = t.crypte
	t._basculer(true)                          # vraie entrée (lumières, ciel coupé, salles), sous le fondu
	for i in 30:
		await process_frame
	j.global_position = c.to_global(POSE_JOUEUR) + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	process_frame.connect(_suivre)
	# apparition : seuls les deux zombies restent actifs (figés jusqu'à leur tour) ; les autres gardiens sont figés et cachés
	for k in 60:
		t._gerer_zones()
		_figer_autres()
		await physics_frame
		if ZOMBIES.all(func(id: String) -> bool: return m.draugrs.has(id) and is_instance_valid(m.draugrs[id])):
			break
	var z2: Node3D = m.draugrs.get("cr_prep_2")
	var z3: Node3D = m.draugrs.get("cr_prep_3")
	if z2 == null or z3 == null:
		print("ECHEC zombies absents")
		quit(1)
		return
	for z: Node3D in [z2, z3]:
		z.process_mode = Node.PROCESS_MODE_DISABLED
	_images = 0
	cible = z2
	await _attendre(1.5)                       # allongés
	z2.process_mode = Node.PROCESS_MODE_INHERIT  # le joueur est à 3,9 m : réveil
	await _attendre(2.5)
	z3.process_mode = Node.PROCESS_MODE_INHERIT  # 9,7 m : réveil aussi
	await _attendre(10.0)                      # démarche et attaques du premier
	for k in 2:                                # le joueur frappe : réactions
		if z2.vivant():
			z2.recevoir_coup(6.0, j.global_position, false)
		await _attendre(1.6)
	if z2.vivant():
		z2.recevoir_coup(400.0, j.global_position, true)
	await _attendre(2.0)
	cible = z3
	await _attendre(9.0)
	print("FILM_FIN images=%d" % _images)
	process_frame.disconnect(_suivre)
	print("CAPTURES_DRAUGR_ZOMBIE fini : ", sortie)
	quit()

func _figer_autres() -> void:
	for id: String in m.draugrs:
		var e = m.draugrs[id]
		if is_instance_valid(e) and not ZOMBIES.has(id) and e.process_mode != Node.PROCESS_MODE_DISABLED:
			e.process_mode = Node.PROCESS_MODE_DISABLED
			e.visible = false

## Caméra du joueur tournée doucement vers la cible (poitrine) ; le joueur ne meurt pas.
func _suivre() -> void:
	_images += 1
	_figer_autres()
	if m.hud != null and "aide_t" in m.hud:
		m.hud.aide_t = 0.0                     # cartouche d'aide des touches (60 s en début de partie) : masqué
	if "vie" in j:
		j.vie = j.vie_max
	if cible == null or not is_instance_valid(cible):
		return
	var v: Vector3 = cible.global_position + Vector3(0, 0.75, 0) - j.tete.global_position
	var lacet := atan2(-v.x, -v.z)
	var tangage := atan2(v.y, Vector2(v.x, v.z).length())
	j.rotation.y = lerp_angle(j.rotation.y, lacet, 0.12)
	j.tete.rotation.x = lerpf(j.tete.rotation.x, tangage, 0.12)
