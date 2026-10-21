extends SceneTree
## Test headless de l'entrée / sortie de la crypte et de la grotte, depuis le monde : le joueur posé devant la porte, l'interactif
## mène DANS la crypte (pas devant la grotte), sans invite « Sortir de la grotte » ; la sortie ramène devant le tertre ; idem grotte.
##   godot --headless --path . --script outils/test_entree_crypte.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _inter(nom: String) -> Node3D:
	for n in m.find_children("*", "Node3D", true, false):
		if n.get("verbe") != null and n.get("nom") == nom:
			return n
	return null

func _invites() -> Array:
	var r: Array = []
	for p in m.dialogue._invites:
		if is_instance_valid(p):
			r.append(str(p.get("verbe")))
	return r

func _images(n: int) -> void:
	for i in n:
		await physics_frame

func _attendre_vrai(f: Callable, max_s: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < max_s * 1000.0:
		if f.call():
			return true
		await physics_frame
	return f.call()

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(5)
	var j: CharacterBody3D = m.joueur
	var t: Node3D = m.tertre
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	await _images(6)
	# --- grotte : entrée
	j.global_position = a.porte_dehors + Vector3(0, 0.5, 0)
	await _images(10)
	var bouche := _inter("Grotte des bandits")
	_verif(bouche != null, "interactif de la grotte trouvé")
	if bouche == null:
		quit(1)
		return
	m.dialogue.inviter(bouche)
	bouche.parler()
	_verif(await _attendre_vrai(func() -> bool: return a.dedans, 30.0), "entrée dans la grotte : a.dedans")
	await _images(30)
	_verif(j.global_position.y < -182.0 and not t.dedans, "le joueur est dans la grotte (y %.1f), pas dans la crypte" % j.global_position.y)
	var s := _inter("Sortie de la grotte")
	# comme en jeu : le joueur est devant la sortie, la regarde, l'invite est affichée, il appuie sur E
	var dir := Vector3(-1, 0, 0)
	j.global_position = s.global_position - Vector3(0, 1.5, 0) - dir * 1.2
	j.rotation.y = atan2(-dir.x, -dir.z)
	j.tete.rotation.x = 0.0
	j.velocity = Vector3.ZERO
	await _images(10)
	print("invites devant la sortie de la grotte : ", _invites())
	_verif(_invites().has("Sortir de la grotte"), "l'invite de sortie s'affiche devant la sortie de la grotte")
	m.dialogue._ouvrir(s)        # touche E : la grotte se referme ensuite (process désactivé) sans retirer l'invite
	_verif(await _attendre_vrai(func() -> bool: return not a.dedans, 10.0), "sortie de la grotte")
	await _images(30)
	_verif(j.global_position.distance_to(a.porte_dehors) < 2.0, "retour devant la bouche (%s)" % str(j.global_position))
	# --- crypte : entrée
	j.global_position = t.porte_dehors + Vector3(0, 0.5, 0)
	await _images(10)
	var porte := _inter("Tertre de Svanhild")
	_verif(porte != null, "interactif du tertre trouvé")
	m.dialogue.inviter(porte)
	porte.parler()
	_verif(await _attendre_vrai(func() -> bool: return t.dedans, 30.0), "entrée dans la crypte : t.dedans")
	await _images(30)
	var dist := Vector3(j.global_position.x, 0, j.global_position.z).distance_to(Vector3(t.crypte.global_position.x, 0, t.crypte.global_position.z))
	print("joueur : ", j.global_position, " crypte : ", t.crypte.global_position)
	_verif(absf(j.global_position.y - t.crypte.global_position.y) < 3.0 and dist < 4.0, "le joueur est dans le vestibule de la crypte")
	_verif(not a.dedans, "la grotte n'est pas marquée « dedans »")
	_verif(not a.grotte_visible() if a.has_method("grotte_visible") else (a.grotte == null or not a.grotte.visible), "la grotte est cachée")
	var inv := _invites()
	print("invites : ", inv)
	_verif(not inv.has("Sortir de la grotte"), "pas d'invite « Sortir de la grotte » dans la crypte")
	# --- crypte : sortie
	var sortie := _inter("Sortie")
	m.dialogue.inviter(sortie)
	sortie.parler()
	_verif(await _attendre_vrai(func() -> bool: return not t.dedans, 10.0), "sortie de la crypte : not t.dedans")
	await _images(30)
	_verif(j.global_position.distance_to(t.porte_dehors) < 2.0, "retour devant le tertre (%s)" % str(j.global_position))
	var inv2 := _invites()
	print("invites apres sortie de grotte : ", inv2)
	_verif(not inv2.has("Sortir de la grotte"), "pas d'invite « Sortir de la grotte » périmée une fois dehors")
	_verif(m.dialogue._plus_proche() == null, "aucune invite fantôme : E ne ferait rien loin de tout interactif")
	# --- retour à la crypte après la grotte : l'invite proposée est bien celle du tertre
	j.global_position = t.porte_dehors + Vector3(0, 0.5, 0)
	j.rotation.y = t.orientation + PI
	await _images(10)
	var inv3 := _invites()
	print("invites devant le tertre : ", inv3)
	_verif(not inv3.has("Sortir de la grotte"), "devant le tertre : pas d'invite de sortie de grotte")
	print("ECHECS : %d" % _echecs if _echecs > 0 else "TOUT OK")
	quit(_echecs)
