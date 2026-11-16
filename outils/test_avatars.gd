extends Node3D
## LOT 4b : avatar distant complet — UNE instance (hôte ou invité), lancée deux fois par outils/test_avatars.sh (headless) ou par
## outils/captures_avatars.sh (rendu réel hors écran, --captures=<dossier>) :
##   godot --path . res://outils/test_avatars.tscn -- --role=hote|invite --port=24821 [--captures=<dossier>]
## Les deux instances déroulent le MÊME scénario en lockstep (barrières) : chacune joue SON joueur et vérifie l'avatar de l'AUTRE.
## Imprime « TEST ok / ECHEC … » puis « TEST_AVATARS <role> OK|ECHEC » ; avec --captures, « CAPTURE <fichier> ».

const JOUEUR := preload("res://scripts/joueur.gd")
const MOI := {
	"hote": {"nom": "Eirik", "droite": "epee", "gauche": "bouclier", "pos": Vector3(0, 0, 0), "lacet": 0.0,
		"corps": {"tete": "casque_fer", "torse": "cuirasse_fer", "mains": "gantelets_fer", "pieds": "bottes_fer"}},
	"invite": {"nom": "Astrid", "droite": "claymore", "gauche": "vide", "pos": Vector3(0, 0, -3.0), "lacet": PI,
		"corps": {"tete": "casque_acier_nordique", "torse": "cuirasse_acier_nordique", "mains": "gantelets_acier_nordique", "pieds": "bottes_acier_nordique"}},
}

var _role := "hote"
var _port := 24821
var _dossier := ""
var _ok := true
var _res: Node
var _joueur: CharacterBody3D
var _ac: AvatarsCoop
var _autre := 0
var _vus := {}
var _cam: Camera3D
var _marche := Vector3.ZERO     # vitesse imposée au joueur local (le test pilote son déplacement : la physique propre du joueur est coupée)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
		elif a.begins_with("--captures="):
			_dossier = a.substr(11)
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	_decor()
	_lancer.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("TEST ok     " if cond else "TEST ECHEC  ") + "[" + _role + "] " + msg)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai: float) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return cond.call()

## Barrière avec données : envoie les miennes, renvoie celles de l'autre instance.
func _barriere(nom: String, donnees: Variant = null) -> Variant:
	_res.envoyer_evenement("sync", nom, donnees)
	if not await _attendre(func() -> bool: return _vus.has(nom), 60.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)
		await get_tree().create_timer(5.0).timeout
	return _vus.get(nom)

func _decor() -> void:
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	add_child(sol)
	var mesh := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(80, 80)
	mesh.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.38, 0.33)
	mat.roughness = 1.0
	mesh.material_override = mat
	add_child(mesh)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 35, 0)
	soleil.light_energy = 1.1
	add_child(soleil)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)

# ------------------------------------------------------------------------------------------------ outils

func _av() -> CharacterBody3D:
	var a: AvatarDistant = _ac.avatars.get(_autre)
	return a.noeud if a != null and is_instance_valid(a.noeud) else null

func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Hauteur (m, au-dessus des pieds de l'avatar) du sommet de la tête du corps visible.
func _hauteur_tete(av: CharacterBody3D) -> float:
	var sq: Skeleton3D = av.corps.modele.find_child("Skeleton3D", true, false)
	var i := sq.find_bone("Head")
	return (sq.global_transform * sq.get_bone_global_pose(i)).origin.y - av.global_position.y

## Capture (rendu réel seulement) : caméra d'observation devant l'avatar de l'autre, décalée vers la droite.
func _cap(nom: String, distance := 2.7, haut := 1.45, vise := 1.05, cote := 0.9) -> void:
	if _dossier == "" or DisplayServer.get_name() == "headless":
		return
	var av := _av()
	if av == null:
		return
	var b := av.global_transform.basis
	var cible := av.global_position + Vector3(0, vise, 0)
	_cam.global_position = av.global_position + (-b.z * distance) + (b.x * cote) + Vector3(0, haut, 0)
	_cam.look_at(cible)
	_cam.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var f := "%s/%s_%s.png" % [_dossier, nom, _role]
	var err := img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size(), " ", error_string(err))

func _physics_process(dt: float) -> void:
	if _joueur == null:
		return
	if _joueur.a_terre or _joueur.mort:
		_marche = Vector3.ZERO
	_joueur.velocity = Vector3(_marche.x, -1.0, _marche.z)
	_joueur.move_and_slide()

func _poser(p: Vector3, lacet: float) -> void:
	_joueur.global_position = p
	_joueur.rotation.y = lacet
	_joueur.velocity = Vector3.ZERO

# ------------------------------------------------------------------------------------------------ scénario

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, d: Variant) -> void: _vus[String(id)] = d if d != null else true)
	var moi: Dictionary = MOI[_role]
	_joueur = JOUEUR.new()
	_joueur.name = "Joueur"
	_joueur.position = moi["pos"]
	add_child(_joueur)
	_joueur.set_physics_process(false)   # le test pilote la position / la vitesse du joueur (voir _physics_process ci-dessus)
	_joueur.rotation.y = moi["lacet"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam.current = true
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 60.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 40.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	_autre = 1 if _role != "hote" else int(_res.joueurs()[1])
	_ac = AvatarsCoop.installer(self, _joueur, moi["nom"])
	# équipement local : mains (EquipementMains) + pièces d'armure (directement, sans passer par le sac)
	var eq: EquipementMains = _joueur.mains.magie.eq
	eq.apprendre_tout()
	_verif(eq.equiper("droite", moi["droite"]) == "", "équipement local : %s en main droite" % moi["droite"])
	eq.equiper("gauche", moi["gauche"])
	for e: String in moi["corps"]:
		_joueur.equipement_corps.emplacements[e] = moi["corps"][e]
		_joueur.equipement_corps.change.emit(e)
	await _attendre(func() -> bool: return _av() != null, 20.0)
	_verif(_av() != null, "l'avatar de l'autre existe (Joueur_%d)" % _autre)
	await _barriere("connectes")

	# ===== 1. équipement, armure, nom =====
	var autre: Dictionary = MOI["invite" if _role == "hote" else "hote"]
	await _attendre(func() -> bool: return _av() != null and String(_ac.avatars[_autre].equipement.get("nom", "")) == autre["nom"], 15.0)
	await get_tree().create_timer(1.2).timeout
	var av := _av()
	var ev: EquipementMains = av.mains.magie.eq
	_verif(String(ev.mains["droite"].get("id", "")) == autre["droite"], "arme tenue répliquée : %s (lu : %s)" % [autre["droite"], ev.mains["droite"].get("id", "")])
	_verif(String(ev.mains["gauche"].get("id", "")).replace("main_vide", "vide") == autre["gauche"], "main gauche répliquée : %s (lue : %s)" % [autre["gauche"], ev.mains["gauche"].get("id", "")])
	var arme_ok: bool = av.mains.equipement.main_droite.id == ev.mains["droite"].get("id", "") or autre["droite"] == "epee"
	_verif(arme_ok, "Equipement de combat de l'avatar suit les mains")
	for e: String in autre["corps"]:
		_verif(av.equipement_corps.objet_a(e) == autre["corps"][e], "armure répliquée (%s) : %s" % [e, autre["corps"][e]])
	var ar: ArmureVisible = av.corps.armure
	_verif(ar != null and ar.porte("torse") == autre["corps"]["torse"], "ArmureVisible montre le torse « %s »" % autre["corps"]["torse"])
	_verif(ar != null and ar.maillage("torse") != null and ar.maillage("torse").visible, "maillage de torse visible sur l'avatar")
	_verif(_ac.avatars[_autre].etiquette != null and _ac.avatars[_autre].etiquette.text == autre["nom"], "nom flottant « %s »" % autre["nom"])
	_verif(_ac.avatars[_autre].etiquette.visible, "nom flottant visible à %.1f m" % _cam.global_position.distance_to(av.global_position))
	_verif(_res.registre.noeud(_autre) == av, "avatar inscrit au registre des joueurs")
	_verif(Progression.courante() == _joueur.progression, "la progression courante reste celle du joueur local (pas l'avatar)")
	await _cap("armure", 3.4, 1.35, 0.95, 1.1)
	await _cap("nom", 2.3, 1.95, 1.9, 0.5)
	await _barriere("equip_fin")

	# ===== 2. position / rotation / vitesse / tangage =====
	_joueur.tete.rotation.x = 0.35
	_marche = Vector3(2.4, 0, 0) if _role == "hote" else Vector3(-2.4, 0, 0)
	await get_tree().create_timer(0.8).timeout
	var mi_pas: Variant = await _barriere("marche", {"vel": _joueur.velocity, "pos": _joueur.global_position})
	av = _av()
	_verif(av.velocity.length() > 1.5 and sign(av.velocity.x) == sign(mi_pas["vel"].x), "vitesse répliquée en marche (%.2f m/s)" % av.velocity.length())
	_verif(av.corps.anim.current_animation in ["Walk", "Jog_Fwd"], "l'avatar joue une marche (« %s »)" % av.corps.anim.current_animation)
	_marche = Vector3.ZERO
	_joueur.velocity = Vector3.ZERO
	await get_tree().create_timer(0.7).timeout
	var vrai: Variant = await _barriere("arret", {"pos": _joueur.global_position, "lacet": _joueur.rotation.y, "tangage": _joueur.tete.rotation.x})
	av = _av()
	_verif(_dist_xz(av.global_position, vrai["pos"]) < 0.08, "position répliquée à %.3f m près" % _dist_xz(av.global_position, vrai["pos"]))
	_verif(absf(angle_difference(av.rotation.y, vrai["lacet"])) < 0.02, "lacet répliqué")
	_verif(absf(av.tete.rotation.x - float(vrai["tangage"])) < 0.02, "tangage de la tête répliqué (%.2f)" % av.tete.rotation.x)
	_verif(av.is_on_floor(), "avatar posé au sol (is_on_floor)")
	await _barriere("pose_fin")

	# ===== 3. accroupi =====
	_joueur.s_accroupir(true)
	await get_tree().create_timer(0.9).timeout
	await _barriere("accroupi")
	av = _av()
	_verif(av.accroupi and av.accroupi_k > 0.95, "accroupi répliqué (k = %.2f)" % av.accroupi_k)
	_verif(absf(av.corps.scale.y - JOUEUR.ACCROUPI_CORPS) < 0.03, "corps écrasé de l'avatar accroupi (%.2f)" % av.corps.scale.y)
	await _cap("accroupi", 2.8, 1.2, 0.8, 1.0)
	await _barriere("accroupi_vu")
	_joueur.s_accroupir(false)
	await get_tree().create_timer(0.9).timeout
	await _barriere("debout")
	_verif(not _av().accroupi and _av().accroupi_k < 0.05, "relevé de l'accroupi répliqué")

	# ===== 4. garde (clic droit tenu) =====
	_joueur.tete.rotation.x = 0.0
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_RIGHT
	clic.pressed = true
	clic.position = Vector2(100, 100)
	Input.parse_input_event(clic)
	await get_tree().create_timer(1.1).timeout
	var garde_locale := {"bloque": _joueur.mains.bloque, "clip": _joueur.mains.anim.clip}
	var g: Variant = await _barriere("garde", garde_locale)
	av = _av()
	_verif(bool(garde_locale["bloque"]), "garde levée chez moi (clip « %s »)" % garde_locale["clip"])
	_verif(av.mains.bloque, "garde répliquée : mains.bloque de l'avatar")
	_verif(av.mains.anim.clip == String(g["clip"]), "clip des mains répliqué : « %s » == « %s »" % [av.mains.anim.clip, g["clip"]])
	_verif(bool(av.mains.garde_bouclier()) == (_autre_gauche() == "bouclier"), "bouclier de l'avatar : garde_bouclier() = %s" % av.mains.garde_bouclier())
	await _cap("garde", 2.6, 1.4, 1.05, 0.8)
	await _barriere("garde_vue")
	clic.pressed = false
	Input.parse_input_event(clic)
	await get_tree().create_timer(0.7).timeout
	await _barriere("garde_fin")
	_verif(not _av().mains.bloque, "garde relâchée répliquée")

	# ===== 5. coup d'arme : clip + temps -> le corps TPS rejoue le coup =====
	var vu := {"pilote": false, "t_max": 0.0, "clips": {}}
	var capture_faite := false
	_joueur.mains.attaquer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1700:
		av = _av()
		var c: String = av.mains.anim.clip
		if av.corps.coups_tps.pilote():
			vu["pilote"] = true
			vu["clips"][c] = true
			vu["t_max"] = maxf(vu["t_max"], float(av.mains.anim.t))
			if not capture_faite and float(av.mains.anim.t) > 0.28:
				capture_faite = true
				await _cap("coup", 2.9, 1.35, 1.0, 0.9)
		await get_tree().create_timer(0.03).timeout
	await _barriere("coup")
	_verif(vu["pilote"], "CorpsCoupsTps pilote le corps de l'avatar pendant le coup de l'autre (clips vus : %s)" % str(vu["clips"].keys()))
	_verif(float(vu["t_max"]) > 0.25, "le temps du clip avance chez l'avatar (t max %.2f s)" % vu["t_max"])
	await get_tree().create_timer(0.8).timeout
	_verif(not _av().corps.coups_tps.pilote() or _av().mains.anim.clip == "repos", "le coup se termine : retour au repos")
	await _barriere("coup_fin")

	# ===== 6. à terre / relevé (ATerre réel chez le propriétaire ; un seul tombe à la fois : sinon plus d'allié debout = mort) =====
	await _phase_terre("invite")
	await _phase_terre("hote")

	# ===== 7. mort -> cadavre, puis réapparition =====
	var pos_mort := _joueur.global_position
	_joueur.vie = 0.0
	_joueur.mort = true
	await get_tree().create_timer(1.6).timeout
	await _barriere("mort", {"pos": pos_mort})
	av = _av()
	_verif(av.mort, "avatar mort (flag)")
	_verif(av.corps._ragdoll != null, "cadavre : le corps de l'avatar tombe en ragdoll")
	var p_mort: Vector3 = _vus["mort"]["pos"]
	_poser(_joueur.global_position + Vector3(2.0, 0, 0), _joueur.rotation.y)   # le joueur mort bouge (téléport de test) : le cadavre, lui, reste
	await get_tree().create_timer(0.8).timeout
	await _barriere("mort_stable")
	_verif(_dist_xz(_av().global_position, p_mort) < 0.5, "cadavre resté sur place (écart %.2f m)" % _dist_xz(_av().global_position, p_mort))
	await _cap("mort", 2.8, 1.6, 0.3, 0.9)
	await _barriere("mort_vue")
	var pos_re: Vector3 = moi["pos"] + Vector3(1.0, 0, 0.0)
	_joueur.mort = false
	_joueur.vie = _joueur.vie_max
	_poser(pos_re, moi["lacet"])
	await get_tree().create_timer(1.6).timeout
	var re: Variant = await _barriere("reapparu", {"pos": pos_re})
	av = _av()
	_verif(not av.mort and av.corps._ragdoll == null, "réapparition : plus de cadavre, corps recréé")
	_verif(_dist_xz(av.global_position, re["pos"]) < 0.3, "avatar réapparu à la position du joueur (écart %.2f m)" % _dist_xz(av.global_position, re["pos"]))
	_verif(_hauteur_tete(av) > 1.3, "avatar debout après la réapparition")
	_verif(av.corps.armure != null and av.corps.armure.porte("torse") == autre["corps"]["torse"], "armure toujours visible après la réapparition")
	await _barriere("fin")

	# ===== 8. déconnexion : l'avatar disparaît =====
	if _role == "invite":
		print("TEST_AVATARS invite %s" % ("OK" if _ok else "ECHEC"))
		await get_tree().create_timer(0.5).timeout
		_res.deconnecter()
		get_tree().quit(0 if _ok else 1)
		return
	var parti := await _attendre(func() -> bool: return _ac.avatars.is_empty() and get_node_or_null("Joueur_%d" % _autre) == null, 10.0)
	_verif(parti, "déconnexion de l'invité : son avatar est retiré")
	_verif(_res.registre.noeud(_autre) == null, "registre : nœud de l'invité vidé")
	print("TEST_AVATARS hote %s" % ("OK" if _ok else "ECHEC"))
	get_tree().quit(0 if _ok else 1)

func _phase_terre(tombe: String) -> void:
	var je_tombe := _role == tombe
	if je_tombe:
		ATerre.de(_joueur).etats[_autre] = false
		ATerre.tomber(_joueur)
	await get_tree().create_timer(2.0).timeout
	await _barriere("terre_" + tombe)
	if not je_tombe:
		var av := _av()
		_verif(av.a_terre and not av.mort, "avatar de %s à terre (flag)" % tombe)
		_verif(av.corps._action == "Death01", "corps_joueur de l'avatar joue la chute (« %s »)" % av.corps._action)
		var h := _hauteur_tete(av)
		_verif(h < 0.7, "corps couché : tête à %.2f m du sol (debout ~1,6)" % h)
		_verif(_ac.avatars[_autre].etiquette.position.y < 1.2, "nom flottant redescendu près du corps")
		await _cap("a_terre", 2.8, 1.5, 0.3, 0.9)
	await _barriere("terre_vu_" + tombe)
	if je_tombe:
		ATerre.de(_joueur)._releve()
	await get_tree().create_timer(2.2).timeout
	await _barriere("releve_" + tombe)
	if not je_tombe:
		var av2 := _av()
		_verif(not av2.a_terre, "avatar relevé (flag)")
		var h2 := _hauteur_tete(av2)
		_verif(h2 > 1.3, "corps debout après le relevé : tête à %.2f m" % h2)
		_verif(av2.corps._action == "", "corps_joueur reprend sa locomotion (action « %s »)" % av2.corps._action)

func _autre_gauche() -> String:
	return String(MOI["invite" if _role == "hote" else "hote"]["gauche"])
