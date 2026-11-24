extends SceneTree
## SESSION LONGUE (robustesse, 2026-11-24) : VRAI monde (foret_test.tscn) sur chaque instance, 1 hôte + jusqu'à 3 invités, headless, avec le simulateur
## (--sim-latence= --sim-gigue= --sim-perte=). L'hôte déroule un calendrier de phases (diffusé 1 fois par seconde) ; chaque rôle y joue sa partition.
##   godot --headless --path . --script res://outils/session_longue.gd -- --nouvelle --role=hote|i1|i2|i3 --port=N [--attendus=N] [--echelle=1.0]
## Chaque instance imprime « ETAT … » toutes les 5 s (FPS, mémoire, position, vie, avatars, ennemis, objets cassés, octets réseau) et « SL ok/ECHEC … ».
## Le verdict croisé (désynchronisations) est fait par outils/session_longue.sh à partir des journaux.

const SCENE := preload("res://scenes/foret_test.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const PHASES := [["marche", 25.0], ["combat", 50.0], ["pvp", 60.0], ["objets", 40.0], ["coffre", 12.0], ["terre", 30.0], ["sommeil", 25.0],
	["zone", 30.0], ["sauve", 8.0], ["depart", 45.0], ["fin", 12.0]]
const CENTRE := Vector3(5, 0, 5)   # repère du joueur de l'hôte au départ

var _role := "hote"
var _port := 25901
var _attendus := 1
var _ech := 1.0
var _R: Node
var _m: Node3D
var _j: CharacterBody3D
var _fait := {}
var _phase := ""
var _ok := true
var _t_etat := 0.0
var _fps_min := 999.0
var _t_depart := 0.0
var _marche := false
var _ennemis: Array = []
var _fin := false

func _init() -> void:
	_principal.call_deferred()

func _v(cond: bool, msg: String) -> void:
	print(("SL ok     " if cond else "SL ECHEC  ") + "[" + _role + "] " + msg)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai: float) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()

func _pause(s: float) -> void:
	await create_timer(s * _ech).timeout

func _principal() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
		elif a.begins_with("--attendus="):
			_attendus = int(a.substr(11))
		elif a.begins_with("--echelle="):
			_ech = float(a.substr(10))
	_R = root.get_node("/root/Reseau")
	_R.nom_joueur = {"hote": "Hote", "i1": "Astrid", "i2": "Bjorn", "i3": "Sigrid"}.get(_role, "X")
	_R.hote_perdu.connect(func(raison: String) -> void: print("SL HOTE_PERDU raison=", raison))
	_R.joueur_deconnecte.connect(func(id: int) -> void: print("SL DECONNECTE ", id))
	_R.joueur_connecte.connect(func(id: int) -> void: print("SL CONNECTE ", id))
	_R.abonner("sl_phase", func(_e: int, id: Variant, _d: Variant) -> void: _sur_phase(String(id)))
	if _role == "hote":
		_v(_R.heberger(_port) == OK, "heberger")
		await _construire()
		print("HOTE_PRET")
		_v(await _attendre(func() -> bool: return _R.joueurs().size() >= _attendus + 1, 240.0), "%d joueurs connectés" % _R.joueurs().size())
		_t_depart = Time.get_ticks_msec() / 1000.0
		_calendrier.call_deferred()
	else:
		await create_timer(1.0).timeout
		_v(_R.rejoindre("127.0.0.1", _port) == OK, "rejoindre")
		_v(await _attendre(func() -> bool: return _R.est_en_ligne() and _R.mon_id() > 1, 90.0), "connecté")
		await _construire()
		print("INVITE_PRET ", _role)
	while not _fin:
		await create_timer(0.5).timeout
	print("SL_SESSION %s %s" % [_role, "OK" if _ok else "ECHEC"])
	quit(0 if _ok else 1)

func _construire() -> void:
	Jeu.chargement_etale = true
	paused = true
	_m = SCENE.instantiate()
	root.add_child(_m)
	var pret := await _attendre(func() -> bool: return _m.pret, 400.0)
	paused = false
	Jeu.chargement_etale = false
	_v(pret, "monde prêt")
	_j = _m.joueur
	_j.vie_max = maxf(_j.vie_max, 100.0)
	_j.vie = _j.vie_max
	await create_timer(2.0).timeout
	_v(_m.get_node_or_null("AvatarsCoop") != null, "AvatarsCoop posé par le monde")

func _calendrier() -> void:
	for p: Array in PHASES:
		_phase = p[0]
		var fin := Time.get_ticks_msec() / 1000.0 + float(p[1]) * _ech
		print("SL PHASE ", _phase)
		while Time.get_ticks_msec() / 1000.0 < fin:
			_R.envoyer_evenement("sl_phase", _phase, null)
			_sur_phase(_phase)
			await create_timer(1.0).timeout
	_fin = true

func _sur_phase(nom: String) -> void:
	if _fait.has(nom) or _m == null or _j == null:
		return
	_fait[nom] = true
	_phase = nom
	call("_p_" + nom)

func _process(dt: float) -> bool:
	if _j == null:
		return false
	var f := 1.0 / maxf(dt, 0.0001)
	if Time.get_ticks_msec() / 1000.0 - _t_etat > 5.0:
		_t_etat = Time.get_ticks_msec() / 1000.0
		_etat()
		_fps_min = 999.0
	_fps_min = minf(_fps_min, f)
	return false

func _etat() -> void:
	var av := {}
	var ac: Node = _m.get_node_or_null("AvatarsCoop")
	if ac != null:
		for id in ac.avatars:
			var n: Node3D = ac.avatars[id].noeud
			if is_instance_valid(n):
				av[id] = "%.0f,%.0f|%.0f" % [n.global_position.x, n.global_position.z, float(n.get("vie")) if n.get("vie") != null else -1.0]
	var en := {}
	for e in _ennemis:
		if is_instance_valid(e):
			en[String(e.get("ident"))] = "%.0f" % float(e.get("vie"))
		else:
			en["?"] = "libre"
	var casses := []
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.casse:
			casses.append(o.ident)
	casses.sort()
	var rs := Resilience.instance()
	var env := 0
	if rs != null and rs.wrapper != null:
		env = int(rs.wrapper.env_octets)
	print("ETAT t=%d role=%s ph=%s fps=%.0f fpsmin=%.0f mem=%.0f pos=%.0f,%.0f vie=%.0f av=%s en=%s casses=%s env=%d" % [
		int(Time.get_ticks_msec() / 1000.0), _role, _phase, Engine.get_frames_per_second(), _fps_min,
		OS.get_static_memory_usage() / 1048576.0, _j.global_position.x, _j.global_position.z, _j.vie, JSON.stringify(av), JSON.stringify(en),
		JSON.stringify(casses), env])

func _oeil() -> Vector3:
	return _j.camera.global_position

func _avant() -> Vector3:
	return -_j.camera.global_transform.basis.z

func _info_coup(pt: Vector3) -> Dictionary:
	return {"attaque": "legere", "type": "tranchant", "point": pt + Vector3(0, 1.1, 0), "direction": Vector3(1, -0.4, 0).normalized(), "normale": Vector3(0, 0, 1), "zone": "torse"}

func _a_pos(p: Vector3) -> void:
	_j.global_position = p
	_j.velocity = Vector3.ZERO


# ================================================================================================ phases

func _p_marche() -> void:
	# marche réelle (entrées du joueur) en cercle : chacun tourne à son rythme
	var t := 0.0
	var fin := 25.0 * _ech
	var cap: float = {"hote": 0.0, "i1": 1.6, "i2": 3.1, "i3": 4.7}.get(_role, 0.0)
	_j.rotation.y = cap
	Input.action_press("avant")
	while t < fin:
		_j.rotation.y += 0.01
		await create_timer(0.1).timeout
		t += 0.1
	Input.action_release("avant")

func _p_combat() -> void:
	# 3 draugrs identiques chez tous (même ident, même place) ; chacun frappe ; l'hôte enregistre
	var base := Vector3(40, 0, 40)
	for i in 3:
		var e := CharacterBody3D.new()
		e.set_script(DRAUGR)
		e.set("type", "sbire")
		e.set("ident", "sl_d%d" % i)
		e.name = "sl_d%d" % i
		e.set("joueur", _j)
		e.set("vie_imposee", 600.0)
		_m.add_child(e)
		e.global_position = Vector3(base.x + i * 3.0, _m.hauteur(base.x + i * 3.0, base.z) + 0.2, base.z)
		_ennemis.append(e)
	_a_pos(Vector3(base.x + 3.0, _m.hauteur(base.x + 3.0, base.z - 4.0) + 0.5, base.z - 4.0 + {"hote": 0, "i1": 1, "i2": 2, "i3": 3}.get(_role, 0)))
	await _pause(3.0)
	for r in 14:
		for e in _ennemis:
			if is_instance_valid(e) and e.has_method("vivant") and e.vivant():
				e.recevoir_coup(35.0, _j.global_position, r % 4 == 3, _info_coup(e.global_position))
		await _pause(2.5)

func _p_pvp() -> void:
	_j.vie = _j.vie_max
	_j.mana = _j.mana_max
	var ordre := ["hote", "i1", "i2", "i3"]
	_a_pos(Vector3(60 + ordre.find(_role) * 2.0, _m.hauteur(60, 60) + 0.5, 60))
	await _pause(4.0)
	# chacun son tour lance une boule de feu et tire une flèche en direction du joueur suivant
	for i in ordre.size():
		if ordre[i] == _role:
			var cible := _avatar_de(ordre[(i + 1) % ordre.size()])
			if cible != null:
				var d := (cible.global_position + Vector3(0, 1.1, 0) - _oeil()).normalized()
				var s := ReseauProjectiles.sort_par_id("boule_feu")
				_j.mana = _j.mana_max
				_j.mains.magie.lanceur.lancer(s, null, _oeil(), d, 1.0)
				await _pause(1.5)
				var s2 := ReseauProjectiles.sort_par_id("repulsion")
				_j.mains.magie.esprit.repulsion(s2, 1.0, null, _oeil(), d)
		await _pause(5.0)
	_v(not _j.mort, "PvP : personne n'est mort d'un coup (vie %.0f)" % _j.vie)

func _avatar_de(r: String) -> Node3D:
	var nom: String = {"hote": "Hote", "i1": "Astrid", "i2": "Bjorn", "i3": "Sigrid"}.get(r, "")
	var ac: Node = _m.get_node_or_null("AvatarsCoop")
	if ac == null:
		return null
	for id in ac.avatars:
		if String(ac.avatars[id].nom) == nom:
			return ac.avatars[id].noeud
	return null

func _p_objets() -> void:
	# casse + télékinésie : i1 brise 3 objets précis (mêmes idents partout), i2 en brise 2 autres ; l'état « cassés » est comparé dans les ETAT
	_a_pos(Vector3(12, _m.hauteur(12, 8) + 0.5, 8))
	await _pause(3.0)
	var cibles := []
	for o: ObjetVivant in ObjetsVivants._vivants():
		if not o.casse and o.seuil_casse < INF and o.ident.begins_with("village"):
			cibles.append(o)
		if cibles.size() >= 6:
			break
	cibles.sort_custom(func(a: ObjetVivant, b: ObjetVivant) -> bool: return a.ident < b.ident)
	var mien: Array = {"i1": [0, 1, 2], "i2": [3, 4], "i3": [5], "hote": []}.get(_role, [])
	for k in mien:
		if k < cibles.size():
			var o: ObjetVivant = cibles[k]
			o.reveiller(true)
			o.casser(true, o.global_position + Vector3(0, 0.5, 0), Vector3(3, 1, 0))
			ObjetsVivants.diffuser_casse(o, o.global_position, Vector3(3, 1, 0))
			await _pause(1.0)
	print("SL objets idents visés : ", cibles.map(func(o: ObjetVivant) -> String: return o.ident))
	await _pause(12.0)
	var n := 0
	for o: ObjetVivant in cibles:
		if o.casse:
			n += 1
	_v(n == mini(cibles.size(), 6), "objets : %d/%d cassés chez moi (attendu tous)" % [n, cibles.size()])
	_v(CasseObjets.nb_eclats() < 400, "éclats : %d (plafond)" % CasseObjets.nb_eclats())

func _p_coffre() -> void:
	# « premier arrivé » : tous réclament la même clé au même instant ; un seul gagne
	var gagne := []
	ReseauLieux.reclamer("sl:coffre1", func() -> void: gagne.append(_role), func() -> void: pass, "coffre")
	await _pause(6.0)
	print("SL COFFRE gagnant_chez_moi=", gagne)

func _p_terre() -> void:
	if _role == "i1":
		await _pause(2.0)
		_j.vie = 1.0
		_j.recevoir_coup(500.0, _j.global_position + Vector3(2, 0, 0)) if _j.has_method("recevoir_coup") else null
		await _pause(6.0)
		var at := ATerre.de(_j)
		print("SL TERRE i1 a_terre=", at.est_a_terre(_R.mon_id()) if at != null else "?", " mort=", _j.mort)
	elif _role == "i2" or _role == "hote":
		await _pause(5.0)

func _p_sommeil() -> void:
	await _pause(3.0)
	var som: Node = _m.get("sommeil")
	if _role == "hote" and som != null:
		som._sur_choix(1, "attendre", null)
	await _pause(4.0)
	if som != null and som._vote.en_cours():
		som._vote.repondre(true)
	await _pause(8.0)
	print("SL SOMMEIL vote_en_cours=", som._vote.en_cours() if som != null else "?", " heure=", "%.2f" % float(_m.cycle.heure))

func _p_zone() -> void:
	# i2 entre dans la crypte (changement de zone) puis ressort
	if _role == "i2":
		_m.tertre._passer(true)
		await _pause(8.0)
		print("SL ZONE i2 dedans=", _m.tertre.get("dedans"))
		_m.tertre._passer(false)
		await _pause(6.0)
	else:
		await _pause(15.0)

func _p_sauve() -> void:
	if _role == "hote":
		_v(_m.sauvegarder(), "hôte : sauvegarde du monde")
	else:
		_v(_m.sauvegarder_personnage(), "invité : sauvegarde du personnage")

func _p_depart() -> void:
	if _role == "i2":
		# part proprement puis revient
		await _pause(5.0)
		_R.deconnecter()
		await _pause(6.0)
		_v(_R.rejoindre("127.0.0.1", _port) == OK, "i2 : rejoindre après départ")
		_v(await _attendre(func() -> bool: return _R.est_en_ligne() and _R.mon_id() > 1, 60.0), "i2 : reconnecté")
		await _pause(10.0)
		print("SL RETOUR i2 joueurs=", _R.joueurs().size())
	else:
		await _pause(30.0)

func _p_fin() -> void:
	if _role == "hote":
		await _pause(3.0)
		print("SL HOTE_QUITTE")
		_R.deconnecter()
		_fin = true
	else:
		await _pause(10.0)
		print("SL FIN invite en_ligne=", _R.est_en_ligne())
		_fin = true
