extends SceneTree
## Essai Tripo : les 3 gardes ANIMÉS (scripts/garde_tripo.gd : lancier, garde à l'épée, archer, squelette nordique, clips des humains, tabard à ressorts)
## jouent les vrais PNJ du village (data/habitants_tripo.json, argument --gardes-tripo) : ils marchent côte à côte vers la caméra puis s'éloignent,
## puis chacun passe de profil. Rendu natif 960x540 (le contenu n'est pas mis à l'échelle de 640x360 du jeu). Caméra = celle du joueur, hors écran.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tripo_gardes_v2.gd -- --gardes-tripo --nouvelle --sortie=<dossier>
## Affiche les images de début/fin de chaque plan (« PLAN nom debut fin ») ; photos fixes dans <dossier> (face.png, dos.png, profil_<1..3>.png).
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var gs: Array = []        # les 3 gardes
var v: CharacterBody3D   # garde du milieu (le lancier) : sert de repère
var img := 0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _pf() -> void:
	if m != null and m.get("inventaire_ui") != null and m.inventaire_ui.ouvert:
		m.inventaire_ui.fermer()
	img += 1
	if img % 15 == 0:
		_cacher()
	await process_frame

## Plans propres : seul le jarl est vu (les autres habitants et gardes naissent au fil de l'eau), pas d'invite « Parler à ».
func _cacher() -> void:
	for n in get_nodes_in_group("villageois"):
		if not gs.has(n) and n is Node3D:
			(n as Node3D).visible = false
	if m.get("dialogue") != null and m.dialogue.get("_invite") != null:
		m.dialogue._invite.visible = false

func _att(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

## Caméra du joueur en `pos` (sol) regardant `cible` (point monde) ; yeux ~1,6 m.
func _cam(pos: Vector3, cible: Vector3) -> void:
	var d := cible - pos
	j.global_position = Vector3(pos.x, m.hauteur(pos.x, pos.z) + 0.1, pos.z)
	j.rotation.y = atan2(-d.x, -d.z)
	var dh := Vector2(d.x, d.z).length()
	j.tete.rotation.x = clampf(atan2(cible.y - (j.global_position.y + 1.6), maxf(dh, 0.1)), -0.5, 0.5)
	j.velocity = Vector3.ZERO

func _sol(p: Vector3) -> Vector3:
	return Vector3(p.x, m.hauteur(p.x, p.z), p.z)

func _fixe(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://tripo").path_join(nom + ".png"))

func _plan(nom: String, debut: bool) -> void:
	print("PLAN %s %s %d" % [nom, "debut" if debut else "fin", img])

## Attend que le garde central soit à moins de `r` m de `but` (ou `max_s` s), en gardant la caméra fixe.
func _jusqua(but: Vector3, r: float, max_s: float) -> void:
	var t := 0.0
	while t < max_s and Vector2(v.global_position.x - but.x, v.global_position.z - but.z).length() > r:
		await _pf()
		_suivre()
		t += 1.0 / 30.0

## Caméra fixe en `pos_cam`, qui pivote pour garder le jarl (cible de la visée : la poitrine).
var pos_cam := Vector3.ZERO
var suit := false
func _suivre() -> void:
	if suit:
		_cam(pos_cam, _centre() + Vector3(0, 1.0, 0))

func _att_suivi(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()
		_suivre()

func _centre() -> Vector3:
	var s := Vector3.ZERO
	for g: Node3D in gs:
		s += g.global_position
	return s / gs.size()

func _montrer(actifs: Array) -> void:
	for g: Node3D in gs:
		g.visible = actifs.has(g)

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	var re := _arg("epee_rot"); if re != "": var q := re.split(","); GardeTripo.EPEE_ROT = Vector3(float(q[0]), float(q[1]), float(q[2]))
	var rp := _arg("epee_pos"); if rp != "": var q2 := rp.split(","); GardeTripo.EPEE_POS = Vector3(float(q2[0]), float(q2[1]), float(q2[2]))
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	var ids := ["hab_garde_epee_tripo", "hab_garde_lance_tripo", "hab_archer_tripo"]     # gauche, milieu, droite (vus de face)
	var trouves := {}
	while trouves.size() < 3:
		for n in get_nodes_in_group("villageois"):
			if n.get("donnees") is Dictionary and ids.has(n.donnees.get("id")):
				trouves[n.donnees.get("id")] = n
		if trouves.size() < 3:
			await process_frame
	for i in ids:
		gs.append(trouves[i])
	v = gs[1]
	for n in get_nodes_in_group("villageois"):
		if n.get("_delai_interpelle") != null:
			n._delai_interpelle = 99999.0
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	if m.get("vie") != null:
		m.vie.set_process(false)
	if m.get("dialogue") != null:
		m.dialogue.set_process(false)
	j.camera.fov = 52.0
	_cacher()
	_heure(11.0)
	await _att(2.0)
	# couloir libre : 3 voies parallèles espacées de 1,3 m, 10 m de marche droite, soleil plutôt dans le dos de la caméra
	var p_poste := _sol(v.global_position)
	var p0 := p_poste
	var cap := Vector3.ZERO
	var cand: Array = []
	for dx in range(-12, 13, 3):
		for dz in range(-12, 13, 3):
			cand.append(Vector3(dx, 0, dz))
	cand.sort_custom(func(a1: Vector3, b1: Vector3) -> bool: return a1.length() < b1.length())
	var dl: Vector3 = -m.cycle.lumiere.global_transform.basis.z
	var sun_h := Vector3(dl.x, 0.0, dl.z).normalized()
	var trouve := false
	for seuil in [0.35, -2.0]:
		for off: Vector3 in cand:
			var s0 := _sol(p_poste + off)
			for k in 16:
				var d := Vector3(sin(k * TAU / 16.0), 0.0, cos(k * TAU / 16.0))
				if d.dot(sun_h) < seuil:
					continue
				var lt := Vector3(d.z, 0.0, -d.x)
				var mid := s0 + d * 4.0
				var ok: bool = v.chemin_libre(mid, mid + lt * 3.5) and v.chemin_libre(mid, mid - lt * 3.5)
				for dec in [-1.3, 0.0, 1.3]:
					ok = ok and v.chemin_libre(s0 + lt * dec - d * 1.5, s0 + lt * dec + d * 10.0)
				if ok:
					p0 = s0
					cap = d
					trouve = true
					break
			if trouve:
				break
		if trouve:
			break
	print("COULOIR cap %s depuis %s" % [cap, p0])
	if not trouve:
		push_error("aucun couloir libre")
		quit(1)
		return
	var L := 8.0
	var A := _sol(p0)
	var B := _sol(p0 + cap * L)
	var lat := Vector3(cap.z, 0.0, -cap.x)       # côté du couloir
	var decs := [1.3, 0.0, -1.3]      # lat pointe à GAUCHE de la caméra (qui regarde vers B) : l épée à gauche de l image
	var P := _sol(A)
	if _arg("stills") != "":
		await _plan3(p0, cap, L, lat, decs)
	# --- plan 1 : ils marchent côte à côte vers la caméra (de B vers A), puis s'éloignent
	for i in 3:
		gs[i].installer(_sol(B + lat * decs[i]), false, false, "Idle", NAN)
	await _att(0.6)
	pos_cam = P
	suit = true
	_cam(P, B + Vector3(0, 1.0, 0))
	for i in 3:
		gs[i].rentrer(_sol(A + cap * 3.2 + lat * decs[i]), false, [], false, false, "Idle", NAN)
	_plan("approche_eloignement", true)
	await _jusqua(A + cap * 3.2, 0.6, 14.0)
	await _fixe("face")
	for i in 3:
		gs[i].rentrer(_sol(B + lat * decs[i]), false, [], false, false, "Idle", NAN)
	await _att_suivi(1.6)
	await _fixe("dos")
	await _jusqua(B, 0.8, 14.0)
	_plan("approche_eloignement", false)
	# --- plan 2 : de profil, en file indienne (épée en tête, lancier, archer) devant une caméra fixe à 3,4 m du milieu du couloir
	var M := _sol(p0 + cap * L * 0.5)
	var offs := [1.8, 0.0, -1.8]
	for i in 3:
		gs[i].installer(_sol(M - cap * 3.5 + cap * offs[i]), false, false, "Idle", NAN)
	await _att(0.5)
	suit = false
	_cam(M + lat * 3.4, M + Vector3(0, 1.0, 0))
	for i in 3:
		gs[i].rentrer(_sol(M + cap * 3.5 + cap * offs[i]), false, [], false, false, "Idle", NAN)
	_plan("profil_file", true)
	await _jusqua(M, 0.35, 12.0)
	await _fixe("profil")
	await _jusqua(M + cap * 3.5, 0.6, 12.0)
	_plan("profil_file", false)
	await _plan3(p0, cap, L, lat, decs)
	print("FIN %d" % img)
	quit(0)

func _plan3(p0: Vector3, cap: Vector3, L: float, lat: Vector3, decs: Array) -> void:
	# --- plan 3 : gros plans immobiles (armes en main) puis l'archer tire sur une cible
	var N := _sol(p0 + cap * L * 0.5)
	for i in 3:
		gs[i].installer(_sol(N + lat * (decs[i] * 1.2)), false, false, "Idle", NAN)
	await _att(0.6)
	if _arg("stills") != "":
		for i in 3:
			_cam(_sol(N + lat * (decs[i] * 1.2)) + cap * -2.6 + lat * 0.9, _sol(N + lat * (decs[i] * 1.2)) + Vector3(0, 1.1, 0))
			await _att(0.3)
			await _fixe("gros_%d" % i)
		quit(0)
		return
	var arch = gs[2]
	_plan("archer_tir", true)
	var but := _sol(N - cap * 9.0 + lat * decs[2]) + Vector3(0, 1.3, 0)
	var ap_ := _sol(arch.global_position)
	_cam(ap_ - lat * 3.2 + cap * 0.8, ap_ + Vector3(0, 1.3, 0) - cap * 1.2)
	suit = false
	var at := ArcherTripo.poser(arch)
	at.tirer_sur(but, 2)
	await _att(7.5)
	_plan("archer_tir", false)
