extends SceneTree
## Essai Tripo : le jarl ANIMÉ (scripts/jarl_tripo.gd : squelette nordique, clips des humains, cape à ressorts) joue le vrai PNJ du village
## (habitant « hab_jarl_tripo », data/habitants_tripo.json, activé par l'argument --jarl-tripo) : marche réelle (Villageois.rentrer), demi-tour,
## repos, parole (Villageois.parler), plan de nuit à la torche. Caméra = celle du joueur (1re personne), hors écran.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_tripo_jarl_anime.gd -- --jarl-tripo --nouvelle --sortie=<dossier>
## Affiche les images de début/fin de chaque plan (« PLAN nom debut fin ») pour découper l'AVI ; photos fixes dans <dossier> (planche_*.png).
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var v: CharacterBody3D
var torche: OmniLight3D
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
		if n != v and n is Node3D:
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

## Attend que le jarl soit à moins de `r` m de `but` (ou `max_s` s), en gardant la caméra fixe.
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
		_cam(pos_cam, v.global_position + Vector3(0, 1.0, 0))

func _att_suivi(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()
		_suivre()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	while v == null:
		for n in get_nodes_in_group("villageois"):
			if n.get("donnees") is Dictionary and n.donnees.get("id") == "hab_jarl_tripo":
				v = n
		if v == null:
			await process_frame
	for n in get_nodes_in_group("villageois"):
		if n.get("_delai_interpelle") != null:
			n._delai_interpelle = 99999.0       # personne n'interpelle la caméra
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false       # mains, bouclier et arme de la 1re personne
	for n in get_nodes_in_group("villageois"):
		if n != v and n is Node3D:
			(n as Node3D).visible = false     # plans propres : seul le jarl est vu
	if m.get("vie") != null:
		m.vie.set_process(false)        # pas de rentrée au lit à la nuit
	if m.get("dialogue") != null:
		m.dialogue.set_process(false)
	j.camera.fov = 52.0
	_cacher()
	_heure(11.0)
	await _att(2.0)
	# couloir libre : point de départ (grille autour du poste) + cap (16 directions) laissant 10 m de marche droite, 1,5 m derrière le bout
	# pour la caméra et 3,5 m de recul sur le côté du milieu pour le plan de profil
	var p_poste := _sol(v.global_position)
	var p0 := p_poste
	var cap := Vector3.ZERO
	var meilleur := 0.0
	var cand: Array = []
	for dx in range(-12, 13, 3):
		for dz in range(-12, 13, 3):
			cand.append(Vector3(dx, 0, dz))
	cand.sort_custom(func(a1: Vector3, b1: Vector3) -> bool: return a1.length() < b1.length())
	# le jarl marche vers la caméra : on préfère un cap proche du sens de la lumière du soleil (son visage éclairé, pas à contre-jour)
	var dl: Vector3 = -m.cycle.lumiere.global_transform.basis.z
	var sun_h := Vector3(dl.x, 0.0, dl.z).normalized()
	for seuil in [0.35, -2.0]:
		for off: Vector3 in cand:
			var s0 := _sol(p_poste + off)
			for k in 16:
				var d := Vector3(sin(k * TAU / 16.0), 0.0, cos(k * TAU / 16.0))
				if d.dot(sun_h) < seuil:
					continue
				var lt := Vector3(d.z, 0.0, -d.x)
				var mid := s0 + d * 4.0
				if v.chemin_libre(s0 - d * 1.5, s0 + d * 10.0) and v.chemin_libre(mid, mid + lt * 3.5):
					p0 = s0
					cap = d
					meilleur = 10.0
					break
			if meilleur > 0.0:
				break
		if meilleur > 0.0:
			break
	print("COULOIR cap %s longueur %.0f m depuis %s" % [cap, meilleur, p0])
	if meilleur == 0.0:
		push_error("aucun couloir libre")
		quit(1)
		return
	var L := 8.0
	var A := _sol(p0)                      # bout 1 (le poste)
	var B := _sol(p0 + cap * L)            # bout 2
	var lat := Vector3(cap.z, 0.0, -cap.x) # côté du couloir
	# --- plan 1 : il marche vers la caméra (de B vers A, caméra derrière A dans l'axe), puis fait demi-tour et s'éloigne
	var P := _sol(A)
	v.installer(B, false, false, "Idle", NAN)
	await _att(0.6)
	pos_cam = P
	suit = true
	_cam(P, B + Vector3(0, 1.0, 0))
	v.rentrer(_sol(A + cap * 2.2), false, [], false, false, "Idle", NAN)
	_plan("approche_eloignement", true)
	await _jusqua(A + cap * 2.2, 0.6, 14.0)
	await _fixe("planche_face")
	v.rentrer(B, false, [], false, false, "Idle", NAN)
	await _att_suivi(1.2)
	await _fixe("planche_dos")
	await _jusqua(B, 0.7, 14.0)
	_plan("approche_eloignement", false)
	# --- plan 2 : de profil, il traverse le champ puis fait demi-tour (caméra fixe à 3,6 m du milieu du couloir)
	var M := _sol(p0 + cap * L * 0.5)
	v.installer(A + cap * 0.5, false, false, "Idle", NAN)
	await _att(0.5)
	pos_cam = M + lat * 3.2
	_cam(pos_cam, M + Vector3(0, 1.0, 0))
	v.rentrer(_sol(B - cap * 0.5), false, [], false, false, "Idle", NAN)
	suit = true
	_plan("profil_demitour", true)
	await _jusqua(M, 0.5, 14.0)
	await _fixe("planche_profil")
	await _jusqua(B - cap * 0.5, 0.7, 14.0)
	v.rentrer(_sol(A + cap * 0.5), false, [], false, false, "Idle", NAN)    # demi-tour
	await _att_suivi(5.5)
	_plan("profil_demitour", false)
	# --- plan 3 : repos (il respire, face à la caméra à 2,6 m) puis parole (Interact, Idle_Talking)
	var R := _sol(M)
	v.installer(R, false, false, "Idle", PI)
	await _att(0.5)
	suit = false
	_cam(R - cap * 2.6, R + Vector3(0, 1.1, 0))
	v.rotation.y = atan2(-cap.x, -cap.z)
	_plan("repos_parole", true)
	await _att(4.5)
	await _fixe("repos")
	j.en_dialogue = true
	v.parler()
	await _att(7.0)
	j.en_dialogue = false
	_plan("repos_parole", false)
	# --- plan 4 : nuit à la torche, il marche vers la caméra puis s'arrête
	v.fin_conversation()
	_heure(23.0)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.65, 0.3)
	torche.light_energy = 2.2
	torche.omni_range = 7.0
	torche.position = Vector3(0.35, -0.2, -0.3)
	j.camera.add_child(torche)
	v.installer(_sol(A + cap * 6.0), false, false, "Idle", NAN)
	await _att(0.4)
	pos_cam = P
	suit = true
	_cam(P, A + cap * 6.0 + Vector3(0, 1.0, 0))
	v.rentrer(_sol(A + cap * 2.2), false, [], false, false, "Idle", NAN)
	_plan("nuit_torche", true)
	await _jusqua(A + cap * 2.2, 0.6, 12.0)
	await _fixe("planche_nuit")
	await _att_suivi(3.0)
	_plan("nuit_torche", false)
	print("FIN %d" % img)
	quit(0)
