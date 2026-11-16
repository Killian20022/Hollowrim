extends Node
## LOT 4d : gore, ragdoll, cadavres, butin des corps, faune — UNE instance (hôte ou invité), lancée deux fois par outils/test_cadavres.sh :
##   godot --headless --path . res://outils/test_cadavres.tscn -- --role=hote|invite --port=24841
## Même scénario en lockstep (barrières « sync »). Imprime « TEST ok / ECHEC … » puis « TEST_CADAVRES <role> OK|ECHEC ».

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const BETE := preload("res://scripts/bete_quat.gd")

class FauxCycle extends Node:
	var heure := 12.0

var _role := "hote"
var _port := 24841
var _ok := true
var _res: Node
var _s: Node3D
var _vus := {}
var _recu := {}
var _impacts := 0
var _f: Faune
var _n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
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

func _barriere(nom: String) -> void:
	_res.envoyer_evenement("sync", nom, null)
	if not await _attendre(func() -> bool: return _vus.has(nom), 60.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)

## Envoie `v` à l'autre machine et attend la sienne pour la même clé.
func _echanger(cle: String, v: Variant) -> Variant:
	_res.envoyer_evenement("tres", cle, v)
	if not await _attendre(func() -> bool: return _recu.has(cle), 30.0):
		_verif(false, "échange « %s » jamais reçu" % cle)
		return null
	return _recu[cle]

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ennemi(ident: String, pos: Vector3) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "guerrier"
	d.joueur = _s.joueur
	d.hud = _s.hud
	d.ident = ident
	d.position = pos
	_s.add_child(d)
	d.vie = 5.0
	d.vie_max = 300.0
	d.combat.profil.chance_blocage = 0.0
	return d

func _info(d: Node3D) -> Dictionary:
	var vers: Vector3 = _s.joueur.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	return {"type": "tranchant", "point": d.global_position + Vector3(0, 1.1, 0) + vers * 0.2, "direction": Vector3(1, -0.4, 0).normalized(),
		"normale": vers, "attaque": "legere", "instant": 0.1, "charge": 0.0, "zone": "torse"}

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("tres", func(_e: int, id: Variant, d: Variant) -> void: _recu[String(id)] = d)
	_res.abonner("corps_impact", func(_e: int, _id: Variant, _d: Variant) -> void: _impacts += 1)
	_s = SCENE.instantiate()
	_s.options = {"draugr": "aucun", "sans-aide": ""}
	get_tree().root.add_child(_s)
	await _frames(20)
	_s.mannequin.position = Vector3(30, 0, 30)
	_s.placer_joueur(Vector3.ZERO, 0.0)
	Sang.niveau_force = 2
	var d1 := _ennemi("coop_d1", Vector3(-3, 0, -3))
	var d2 := _ennemi("coop_d2", Vector3(3, 0, -3))
	var d3 := _ennemi("coop_d3", Vector3(0, 0, -6))
	var d4 := _ennemi("coop_d4", Vector3(0, 0, -9))
	for d in [d1, d2, d3, d4]:
		d.set_physics_process(false)      # sans IA : ils restent où ils sont (l'hôte comme l'invité)
	# faune : instance minimale (sans demarrer(), pour garder la main sur les apparitions)
	_f = Faune.new()
	_f.name = "Faune"
	_f.joueur = _s.joueur
	_f.cycle = FauxCycle.new()
	_f.registre = {}
	_f.hauteur_de = func(_x: float, _z: float) -> float: return 0.0
	_f.accepte = func(_x: float, _z: float) -> bool: return true
	_f.fiche = Faune.charger_fiche()
	_f.fabrique = func(_e: String, pos: Vector3, lacet: float, options: Dictionary) -> Node:
		var b := CharacterBody3D.new()
		b.set_script(BETE)
		b.joueur = _s.joueur
		b.hud = _s.hud
		b.ident = String(options["ident"])
		for cle in options:
			b.set(cle, options[cle])
		b.position = pos
		b.rotation.y = lacet
		_f.registre[b.ident] = b
		_s.add_child(b)
		return b
	add_child(_f)
	_f.add_child(_f.cycle)
	_f.set_process(false)
	_f._creer_domestiques()
	_f._reseau_installer()
	await _frames(10)
	var vache: Node3D = _f.domestiques[0]["bete"]
	vache.set_physics_process(false)

	# ===== connexion =====
	_verif(not _res.est_en_ligne(), "solo : hors ligne avant la connexion")
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 90.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 60.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	await _barriere("connectes")
	await _frames(10)
	_verif(_f._marion == (_role != "hote"), "faune : marionnettes seulement chez l'invité")

	# ===== A. démembrement identique =====
	if _role == "hote":
		Demembrement.chance_forcee = 1.0
		Demembrement.membre_force = "bras_l"
	else:
		Demembrement.chance_forcee = 0.0       # l'invité ne doit RIEN décider : il suit le plan de l'hôte
		Demembrement.membre_force = ""
	await _barriere("pret_A")
	if _role == "hote":
		var rr: String = d1.recevoir_coup(50.0, _s.joueur.global_position, false, _info(d1))
		_verif(rr == "tue", "hôte : coup mortel sur coop_d1 (%s)" % rr)
		Demembrement.membre_force = "tete"
		rr = d2.recevoir_coup(50.0, _s.joueur.global_position, false, _info(d2))
		_verif(rr == "tue", "hôte : coup mortel sur coop_d2 (%s)" % rr)
	await _frames(120)
	var h1 := str(Demembrement.coupes_de(d1.modele))
	var h1b: Variant = await _echanger("coupes_d1", h1)
	_verif(h1 == h1b and h1.contains("bras_l"), "même démembrement sur coop_d1 : %s / %s" % [h1, h1b])
	_verif(d1.modele.get_meta("morceau_bras_l", null) != null, "coop_d1 : morceau de bras tranché présent")
	var dec: Variant = await _echanger("decap_d2", d2.modele.has_meta("decapite"))
	_verif(bool(dec) and d2.modele.has_meta("decapite"), "même décapitation sur coop_d2 (moi %s, autre %s)" % [d2.modele.has_meta("decapite"), dec])
	_verif(not d1.vivant() and not d2.vivant(), "les deux corps sont morts des deux côtés")
	_verif(d1.get("_ragdoll") != null and d1._ragdoll.actif, "ragdoll actif sur coop_d1")

	# ===== A2. effet de coup diffusé =====
	var avant := ReseauCorps.impacts_joues      # relevés AVANT la barrière : le coup de l'hôte peut arriver avant que l'invité la voie passer
	var recus_avant := _impacts
	await _barriere("pret_A2")
	if _role == "hote":
		var v: Vector3 = (_s.joueur.global_position - d3.global_position).normalized()
		d3.combat.effets_impact({"info": {"point": d3.global_position + Vector3(0, 1.2, 0), "direction": Vector3(1, 0, 0), "normale": v, "zone": "torse"},
			"impact": "moyen", "degats": 10.0, "reaction": "leger", "critique": false}, _s.joueur)
	await _attendre(func() -> bool: return _impacts > recus_avant or _role == "hote", 10.0)
	await _frames(10)
	if _role == "invite":
		_verif(_impacts == recus_avant + 1 and ReseauCorps.impacts_joues == avant + 1, "invité : l'effet du coup est joué (%d évènement, %d rejoué)" % [_impacts - recus_avant, ReseauCorps.impacts_joues - avant])
	else:
		_verif(_impacts == recus_avant and ReseauCorps.impacts_joues == avant, "hôte : rien de rejoué (déjà joué par effets_impact)")

	# ===== B. position finale du cadavre =====
	var rd1: Ragdoll = d1._ragdoll
	await _attendre(func() -> bool: return rd1.est_fige(), 20.0)
	await _barriere("repos_B")
	await _frames(90)
	var p_moi: Vector3 = rd1.os["pelvis"].global_position
	var p_autre: Variant = await _echanger("bassin_d1", p_moi)
	var ecart := p_moi.distance_to(p_autre)
	_verif(rd1.est_fige() and ecart < 0.35, "cadavre coop_d1 : bassin à %.2f m de celui de l'hôte (figé %s)" % [ecart, rd1.est_fige()])
	var sq := d1.modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var visible_p: Vector3 = (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("pelvis"))).origin
	var ecart_vis := visible_p.distance_to(p_moi)
	print("INFO [%s] bassin visible a %.2f m du bassin physique" % [_role, ecart_vis])
	var vis_autre: Variant = await _echanger("bassin_vis_d1", visible_p)
	_verif(visible_p.distance_to(vis_autre) < 0.5, "cadavre coop_d1 : pose VISIBLE du bassin à %.2f m de celle de l'hôte" % visible_p.distance_to(vis_autre))

	# ===== C. butin des corps : premier arrivé =====
	var b1: Node3D = d1._butin
	var b2: Node3D = d2._butin
	_verif(b1 != null and String(b1.cle_reseau) == "corps:coop_d1", "butin de coop_d1 : clé réseau « %s »" % (String(b1.cle_reseau) if b1 else "?"))
	b1.objets["os_draugr"] = 1
	b2.objets["os_draugr"] = 1
	await _barriere("pret_C")
	if _role == "invite":
		b1.fouiller()
		await _attendre(func() -> bool: return bool(b1.gagnant), 10.0)
		_verif(bool(b1.gagnant), "invité : premier arrivé sur coop_d1, il fouille")
	await _barriere("fouille_1")
	if _role == "hote":
		b1.fouiller()
		await get_tree().create_timer(1.0).timeout
		_verif(not bool(b1.gagnant) and b1.objets.is_empty(), "hôte : coop_d1 déjà fouillé par l'invité -> vide")
	await _frames(20)
	var gagnants := int(bool(b1.gagnant))
	var autre_g: Variant = await _echanger("gagnants", gagnants)
	_verif(gagnants + int(autre_g) == 1, "un seul gagnant de la fouille (moi %d, autre %d)" % [gagnants, int(autre_g)])
	if _role == "invite":
		_verif(b2.objets.has("os_draugr"), "invité : coop_d2 intact (jamais fouillé)")
	if _role == "hote":
		var ex: Dictionary = ReseauCorps.exporter()["corps"]
		_verif(ex.has("corps:coop_d2") and not ex.has("corps:coop_d1"), "instantané « cadavres » : coop_d2 oui, coop_d1 (fouillé) non (%s)" % str(ex.keys()))
		ReseauCorps.importer({"corps": {"corps:faux": {"pos": [5.0, 0.0, 5.0], "nom": "Faux", "modele": {"type": "guerrier"}, "objets": {"os_draugr": 1, "pieces": 3}}}})
		_verif(ReseauCorps._butins.has("corps:faux"), "importer() pose un corps fouillable d'après l'instantané")

	# ===== D. plafond de ragdolls actifs =====
	ReseauCorps.max_ragdolls = 1
	await _barriere("pret_D")
	if _role == "hote":
		Demembrement.chance_forcee = 0.0
		d3.recevoir_coup(50.0, _s.joueur.global_position, false, _info(d3))
		await _frames(2)
		d4.recevoir_coup(50.0, _s.joueur.global_position, false, _info(d4))
	await _frames(40)
	_verif(not d3.vivant() and not d4.vivant(), "coop_d3 et coop_d4 morts")
	print("INFO [%s] d3 rd=%s actif=%s fige=%s | d4 rd=%s actif=%s fige=%s | suivis=%d" % [_role, d3._ragdoll != null, d3._ragdoll.actif if d3._ragdoll else "?", d3._ragdoll.est_fige() if d3._ragdoll else "?", d4._ragdoll != null, d4._ragdoll.actif if d4._ragdoll else "?", d4._ragdoll.est_fige() if d4._ragdoll else "?", ReseauCorps._noeud._ragdolls.size()])
	_verif(d3._ragdoll != null and d3._ragdoll.est_fige() and not d4._ragdoll.est_fige(), "plafond : le plus ancien ragdoll est figé, le nouveau reste actif")
	ReseauCorps.max_ragdolls = 8

	# ===== E. faune =====
	await _barriere("pret_E")
	if _role == "hote":
		_f._creer_groupe({"id": 7, "espece": "loup", "x": 10.0, "z": 10.0, "groupe": 2, "u": 0.3, "biome": "foret"})
		await _frames(5)
		for b in _f.actifs[7]:
			b.set_physics_process(false)       # figé pour comparer des positions stables
	await _attendre(func() -> bool: return _f.actifs.has(7), 15.0)
	_verif(_f.actifs.has(7) and _f.actifs[7].size() == 2, "faune : groupe 7 (2 loups) présent chez moi")
	var ids := ""
	for b in _f.actifs.get(7, []):
		ids += String(b.ident) + ","
	var ids_autre: Variant = await _echanger("idents_faune", ids)
	_verif(ids == ids_autre and ids.contains("faune_007_0"), "mêmes identifiants de faune des deux côtés (%s)" % ids)
	var b0: Node3D = _f.actifs[7][0]
	_verif(_role == "hote" or not b0.is_physics_processing(), "invité : la bête est une marionnette (IA coupée)")
	if _role == "hote":
		b0.global_position = Vector3(14.0, 0.0, 8.0)
		vache.global_position = Vector3(40.0, 0.0, 5.0)
	await get_tree().create_timer(1.5).timeout
	var pos0: Vector3 = b0.global_position
	var pos0b: Variant = await _echanger("pos_loup", pos0)
	_verif(Vector2(pos0.x - pos0b.x, pos0.z - pos0b.z).length() < 0.8, "position du loup répliquée (moi %s, autre %s)" % [pos0, pos0b])
	var pv: Vector3 = vache.global_position
	var pvb: Variant = await _echanger("pos_vache", pv)
	_verif(Vector2(pv.x - pvb.x, pv.z - pvb.z).length() < 0.8, "position du domestique répliquée (moi %s, autre %s)" % [pv, pvb])
	# mort + dépeçage (butin des corps)
	await _barriere("pret_E2")
	if _role == "hote":
		ReseauCorps.contenus[String(b0.ident)] = {"pieces": 5, "os_draugr": 1}     # butin imposé (sinon tirage aléatoire de la bête)
		b0._mourir(Vector3(0, 0, 0), 20.0, false, {}, "legere")
	await _attendre(func() -> bool: return b0.est_mort, 10.0)
	await _frames(30)
	_verif(b0.est_mort, "loup mort des deux côtés")
	var contenu := str(b0._butin.contenu) if b0._butin != null else "aucun"
	var contenu_autre: Variant = await _echanger("contenu_loup", contenu)
	_verif(contenu == contenu_autre and contenu != "aucun", "même butin de la bête : %s / %s" % [contenu, contenu_autre])
	_verif(b0._butin != null and String(b0._butin.cle_reseau) == "corps:" + String(b0.ident), "butin de la bête arbitré (clé %s)" % (String(b0._butin.cle_reseau) if b0._butin else "?"))
	await _barriere("fin")
	print("TEST_CADAVRES %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)
