extends Node
## LOT 4c : flèches, sorts, projectiles ennemis, pièges, mécanismes — UNE instance (hôte ou invité), lancée deux fois par outils/test_projectiles.sh :
##   godot --headless --path . res://outils/test_projectiles.tscn -- --role=hote|invite --port=24831
## Les deux instances déroulent le MÊME scénario en lockstep (barrières « sync »). Imprime « TEST ok / ECHEC … » puis
## « TEST_PROJECTILES <role> OK|ECHEC » ; code de sortie 0 / 1.
## Positions : hôte (0,0,0), invité (3,0,0) face à -Z ; cible (mannequin « Cible ») en (3,0,-10).

const JOUEUR := preload("res://scripts/joueur.gd")
const POS_HOTE := Vector3(0, 0.1, 0)
const POS_INVITE := Vector3(3, 0.1, 0)

var _role := "hote"
var _port := 24831
var _ok := true
var _res: Node
var _monde: Node3D
var _j: CharacterBody3D
var _avatar: ProtoAvatar
var _avatar_pos := Vector3.ZERO
var _cible: Mannequin
var _vus := {}
var _coups_avatar := 0
var _temps_recu := -1.0

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

func _pause(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _barriere(nom: String) -> void:
	_res.envoyer_evenement("sync", nom, null)
	if not await _attendre(func() -> bool: return _vus.has(nom), 60.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)

func _physics_process(_dt: float) -> void:
	# l'avatar de l'autre joueur : position fixe (aucun tampon réseau dans ce test) ; petit pas vers le bas pour que is_on_floor() soit vrai
	if _avatar != null and is_instance_valid(_avatar.noeud):
		var n := _avatar.noeud
		n.global_position = _avatar_pos
		n.velocity = Vector3(0.0, -1.0, 0.0)
		n.move_and_slide()
		n.global_position = _avatar_pos
		n.velocity = Vector3.ZERO

func _journal(type: String) -> Array:
	return ReseauProjectiles.journal.filter(func(e: Dictionary) -> bool: return e.get("type", "") == type)

func _tirer_arc(tenue: float) -> void:
	_j.arc.appuyer()
	await _pause(tenue)
	_j.arc.relacher()

func _equiper_arc() -> void:
	_j.inventaire.ajouter("arc_chasseur", 1)
	_j.inventaire.ajouter("fleche", 30)
	_j.arc.equiper()

func _oeil() -> Vector3:
	return _j.camera.global_position

func _avant() -> Vector3:
	return -_j.camera.global_transform.basis.z

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("test_temps", func(_e: int, _id: Variant, d: Variant) -> void: _temps_recu = float(d))
	# --- monde minimal : sol, joueur local, cible ---
	_monde = Node3D.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_j = CharacterBody3D.new()
	_j.set_script(JOUEUR)
	_j.name = "Joueur"
	_j.position = POS_HOTE if _role == "hote" else POS_INVITE
	_monde.add_child(_j)
	_j.vie_max = 100.0
	_j.vie = 100.0
	_cible = Mannequin.new()
	_cible.name = "Cible"
	_cible.joueur = _j
	_cible.position = Vector3(3, 0, -10)
	_monde.add_child(_cible)
	await _pause(0.6)   # le joueur retombe au sol

	# ===== connexion =====
	_verif(not ReseauProjectiles.en_ligne() and not ReseauProjectiles.invite(), "solo : hors ligne (aucune réplication)")
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 240.0)   # attente large : l'invité peut attendre un créneau godot_slot (machine chargée)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 90.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	var autre: int = 1 if _role != "hote" else int(_res.joueurs()[1])
	_avatar_pos = POS_INVITE - Vector3(0, 0.1, 0) if _role == "hote" else POS_HOTE - Vector3(0, 0.1, 0)
	_avatar = ProtoAvatar.creer(_monde, autre, _avatar_pos)
	_avatar.noeud.coup_distant.connect(func(_d: float, _o: Vector3, _opt: Dictionary) -> void: _coups_avatar += 1)
	ReseauProjectiles.installer()
	await _barriere("connectes")
	_verif(ReseauProjectiles.en_ligne() and ReseauProjectiles.invite() == (_role != "hote"), "en ligne : rôle reconnu")

	# ===== A. flèche de l'invité (arc réel) : dégâts validés par l'hôte, flèche vue chez l'hôte =====
	if _role != "hote":
		_equiper_arc()
		await _tirer_arc(1.4)
	if _role == "hote":
		_verif(await _attendre(func() -> bool: return _cible.coups.size() >= 1, 8.0), "flèche de l'invité : la cible de l'HÔTE est touchée (%d coup)" % _cible.coups.size())
		var c := _journal(ReseauProjectiles.EV_COUP)
		_verif(c.size() >= 1 and not c[0].has("refuse") and c[0]["de"] != 1, "flèche de l'invité : coup validé par l'hôte %s" % str(c))
		var copies := ReseauProjectiles._vivants.values().filter(func(p: Variant) -> bool: return p is Projectile and is_instance_valid(p) and p.distant)
		_verif(copies.size() >= 1, "flèche de l'invité : copie visible chez l'hôte (%d)" % copies.size())
	await _pause(1.0)
	if _role != "hote":
		_verif(_cible.coups.size() == 0, "flèche de l'invité : la marionnette de l'invité n'est pas blessée en local (l'hôte arbitre)")
	await _barriere("A")

	# ===== A2. coups invalides refusés par l'hôte =====
	var avant_refus := ReseauProjectiles.refuses
	var coups_avant := _cible.coups.size()
	if _role != "hote":
		_res.envoyer_evenement(ReseauProjectiles.EV_COUP, "faux:1", {"cible": "n:Cible", "degats": 1000.0, "point": Vector3(3, 1, -10), "dir": Vector3(0, 0, -1), "vit": 40.0}, 1)
		await _pause(0.3)
		_res.envoyer_evenement(ReseauProjectiles.EV_COUP, "faux:2", {"cible": "n:Cible", "degats": 20.0, "point": Vector3(3, 1, -300), "dir": Vector3(0, 0, -1), "vit": 40.0}, 1)
		await _pause(0.3)
		_res.envoyer_evenement(ReseauProjectiles.EV_COUP, "faux:3", {"cible": "n:Inconnue", "degats": 20.0, "point": Vector3(50, 1, 50), "dir": Vector3(0, 0, -1), "vit": 40.0}, 1)
	if _role == "hote":
		_verif(await _attendre(func() -> bool: return ReseauProjectiles.refuses >= avant_refus + 3, 6.0), "coups falsifiés (dégâts énormes, trop loin, cible inconnue) : 3 refus (%d)" % (ReseauProjectiles.refuses - avant_refus))
		_verif(_cible.coups.size() == coups_avant, "coups falsifiés : la cible n'a rien reçu")
	await _barriere("A2")

	# ===== B. flèche de l'hôte : visible et plantée chez l'invité =====
	if _role == "hote":
		_equiper_arc()
		_j.tete.rotation.x = deg_to_rad(-8.0)   # visée plongeante : à ~90 m/s une flèche horizontale quitterait le sol de 80 m avant de se ficher
		await _tirer_arc(1.4)
	else:
		_verif(await _attendre(func() -> bool: return _journal(ReseauProjectiles.EV_SPAWN).size() >= 1, 8.0), "flèche de l'hôte : l'invité reçoit le spawn")
		await _pause(2.5)
		var plantees := ReseauProjectiles._vivants.values().filter(func(p: Variant) -> bool: return p is Projectile and is_instance_valid(p) and p.distant and p.plantee)
		_verif(plantees.size() >= 1, "flèche de l'hôte : fichée et visible chez l'invité (%d)" % plantees.size())
		_verif(_cible.coups.size() == 0, "flèche de l'hôte : aucun dégât local sur la copie")
	await _pause(1.0)
	await _barriere("B")

	# ===== C. sort offensif de l'invité (boule de feu) : cast visible chez l'hôte, dégâts validés =====
	var coups_c := _cible.coups.size()
	if _role != "hote":
		var s := ReseauProjectiles.sort_par_id("boule_feu")
		_verif(s != null, "sort boule_feu chargé")
		_j.mains.magie.lanceur.lancer(s, null, _oeil(), _avant(), 1.0)
	if _role == "hote":
		_verif(await _attendre(func() -> bool: return _journal(ReseauProjectiles.EV_SORT_SPAWN).size() >= 1, 6.0), "sort de l'invité : projectile visible chez l'hôte")
		_verif(await _attendre(func() -> bool: return _cible.coups.size() > coups_c, 8.0), "sort de l'invité : l'hôte applique les dégâts (%d -> %d coups)" % [coups_c, _cible.coups.size()])
		var sc := _journal(ReseauProjectiles.EV_SORT_COUP)
		_verif(sc.size() >= 1 and not sc[0].has("refuse"), "sort de l'invité : sort_coup validé %s" % str(sc.map(func(e: Dictionary) -> Variant: return e.get("resultat", "refuse"))))
	await _pause(1.0)
	if _role != "hote":
		_verif(_cible.coups.size() == coups_c, "sort de l'invité : pas de dégât en local (délégué à l'hôte)")
	await _barriere("C")

	# ===== D. zone de l'hôte (nova de gel) : visible chez l'invité, aucun tir allié =====
	_j.vie = 100.0
	var vie_avatar := float(_avatar.noeud.vie)
	if _role == "hote":
		var nova := ReseauProjectiles.sort_par_id("nova_gelee")
		_j.mains.magie.lanceur.lancer(nova, null, _oeil(), _avant(), 1.0)
		await _pause(1.0)
		_verif(float(_avatar.noeud.vie) == vie_avatar, "zone de l'hôte (rayon 4,5, invité à 3 m) : l'avatar de l'invité n'est pas touché")
	else:
		_verif(await _attendre(func() -> bool: return _journal(ReseauProjectiles.EV_SORT_FX).any(func(e: Dictionary) -> bool: return e["kind"] == "zone"), 6.0), "zone de l'hôte : effet visible chez l'invité")
		await _pause(0.8)
		_verif(_j.vie == 100.0, "zone de l'hôte : l'invité (dans le rayon) n'est pas blessé par un allié (%.0f)" % _j.vie)
	await _barriere("D")

	# ===== E. soin et protection d'allié =====
	if _role != "hote":
		_j.vie = 50.0
	await _barriere("E0")
	if _role == "hote":
		var soin := ReseauProjectiles.sort_par_id("soin")
		for i in 15:
			_j.mains.magie.lanceur.canaliser(soin, null, _oeil(), _avant(), 0.1, "droite")
			await _pause(0.1)
	else:
		_verif(await _attendre(func() -> bool: return _j.vie > 58.0, 6.0), "soin d'allié : l'invité soigné par l'hôte (50 -> %.1f)" % _j.vie)
	await _barriere("E0b")
	if _role == "hote":
		var prot := ReseauProjectiles.sort_par_id("protection")
		for i in 10:
			_j.mains.magie.lanceur.canaliser(prot, null, _oeil(), _avant(), 0.1, "gauche")
			await _pause(0.1)
	else:
		_verif(await _attendre(func() -> bool: return ReseauProjectiles.protege_par_allie(), 4.0), "protection d'allié : reçue de l'hôte")
		_verif(ReseauProjectiles.absorber_allie(100.0, {}) < 80.0, "protection d'allié : coup réduit (100 -> %.0f)" % ReseauProjectiles.absorber_allie(100.0, {}))
	await _barriere("E1")
	if _role != "hote":
		await _pause(1.0)
		_verif(not ReseauProjectiles.protege_par_allie(), "protection d'allié : s'éteint quand le sort cesse")
	# soin dans l'autre sens : l'invité soigne l'hôte (acheminé par l'hôte « pour »)
	if _role == "hote":
		_j.vie = 40.0
	await _barriere("E2")
	if _role != "hote":
		var soin2 := ReseauProjectiles.sort_par_id("soin")
		for i in 15:
			_j.mains.magie.lanceur.canaliser(soin2, null, _oeil(), _avant(), 0.1, "droite")
			await _pause(0.1)
	else:
		_verif(await _attendre(func() -> bool: return _j.vie > 48.0, 8.0), "soin d'allié : l'hôte soigné par l'invité (40 -> %.1f)" % _j.vie)
	await _barriere("E3")

	# ===== F. projectiles ennemis (annoncés par l'hôte, résolus par la victime) =====
	_j.vie = 100.0
	_j.vie_max = 100.0
	_coups_avatar = 0
	await _barriere("F0")
	if _role == "hote":
		Projectile.tirer(_monde, Vector3(3, 1.0, -8), Vector3(0, 0, 1), null, 12.0, _j)
		await _pause(2.0)
		_verif(_coups_avatar == 0, "flèche ennemie : l'hôte ne résout rien pour l'avatar (coup_distant : %d)" % _coups_avatar)
		_verif(_j.vie == 100.0, "flèche ennemie visant l'invité : l'hôte n'est pas touché")
	else:
		_verif(await _attendre(func() -> bool: return _j.vie < 100.0, 6.0), "flèche ennemie : la victime (invité) encaisse chez elle (%.1f)" % _j.vie)
	await _barriere("F1")
	# trait de givre du mage (sort ennemi par LanceurSorts)
	_j.vie = 100.0
	await _barriere("F2")
	if _role == "hote":
		var mage := Node3D.new()
		mage.position = Vector3(3, 0, -8)
		_monde.add_child(mage)
		var lm := LanceurSorts.new(mage, "joueur")
		lm.cible_joueur = _avatar.noeud
		lm.lancer(ReseauProjectiles.sort_par_id("trait_givre_mage"), null, Vector3(3, 1.3, -8), Vector3(0, 0, 1), 1.0)
		await _pause(2.5)
		_verif(_coups_avatar == 0 and _j.vie == 100.0, "sort de mage visant l'invité : rien résolu côté hôte")
	else:
		_verif(await _attendre(func() -> bool: return _j.vie < 100.0, 8.0), "sort de mage : la victime (invité) encaisse chez elle (%.1f)" % _j.vie)
	await _barriere("F3")

	# ===== G. pièges et mécanismes =====
	_j.vie = 100.0
	if _role != "hote":
		_j.global_position = Vector3(3, 0.1, 2)
		_j.velocity = Vector3.ZERO
	else:
		_avatar_pos = Vector3(3, 0, 2)
	var dalle: Variant = Piege.dalle_flechettes(_monde, Vector3(3, 0, 2), Vector3(3, 1, -2), Vector3(0, 0, 1), "test:dalle", {"joueur": _j})
	var souffle: Variant = Piege.souffle_givre(_monde, Vector3(12, 1, 0), Vector3(1, 0, 0), 6.0, 6.0, "test:souffle", {"joueur": _j})
	var statues: Variant = Mecanisme.statues(_monde, [Vector3(-10, 0, 0), Vector3(-12, 0, 0)], [1, 2], "test:statues", func() -> void: pass, {"joueur": _j})
	var mur: Variant = Mecanisme.mur_fragile(_monde, Vector3(-10, 1, 6), Vector3(2, 2, 0.5), 0.0, "test:mur", func() -> void: pass, {"joueur": _j})
	var o0: int = statues.orientation(0)
	var o1: int = statues.orientation(1)
	await _pause(0.8)
	await _barriere("G0")
	if _role == "hote":
		_verif(await _attendre(func() -> bool: return dalle.fleches_tirees >= 2, 8.0), "dalle : l'invité qui marche dessus la déclenche chez l'hôte (%d fléchettes)" % dalle.fleches_tirees)
		_verif(_j.vie == 100.0, "dalle : l'hôte (hors ligne de tir) n'est pas touché")
	else:
		_verif(await _attendre(func() -> bool: return dalle.fleches_tirees >= 2, 8.0), "dalle : l'invité voit les fléchettes de l'hôte (%d)" % dalle.fleches_tirees)
		_verif(await _attendre(func() -> bool: return _j.vie < 100.0, 4.0), "dalle : la victime (invité) est touchée chez elle (%.1f)" % _j.vie)
		_verif(dalle.etat == Piege.Dalle.ARMEE, "dalle : l'invité ne fait tourner aucune machine à états (passif)")
	await _barriere("G1")
	# souffle : cycle recalé sur celui de l'hôte
	if _role != "hote":
		souffle.temps += 2.5
		_verif(await _attendre(func() -> bool: return _journal(ReseauProjectiles.EV_PIEGE).any(func(e: Dictionary) -> bool: return e["evt"] == "phase"), 6.0), "souffle : l'invité reçoit la phase de l'hôte")
	await _barriere("G2")
	if _role == "hote":
		_res.envoyer_evenement("test_temps", 0, souffle.temps)
	else:
		await _attendre(func() -> bool: return _temps_recu >= 0.0, 5.0)
		var ecart := absf(fposmod(souffle.temps - _temps_recu + souffle.periode * 0.5, souffle.periode) - souffle.periode * 0.5)
		_verif(ecart < 0.6, "souffle : cycle recalé chez l'invité (écart %.2f s)" % ecart)
	await _barriere("G3")
	# statues : l'invité tourne, l'hôte arbitre et diffuse
	if _role != "hote":
		statues.tourner(0)
		_verif(statues.orientation(0) == o0, "statue : l'invité n'applique rien avant la réponse de l'hôte")
	_verif(await _attendre(func() -> bool: return statues.orientation(0) == (o0 + 1) % 4, 6.0), "statue : l'orientation 0 passe de %d à %d chez moi" % [o0, statues.orientation(0)])
	await _barriere("G4")
	if _role == "hote":
		statues.tourner(1)
	_verif(await _attendre(func() -> bool: return statues.orientation(1) == (o1 + 1) % 4, 6.0), "statue : le geste de l'hôte (statue 1) arrive chez l'invité (%d -> %d)" % [o1, statues.orientation(1)])
	await _barriere("G5")
	# mur fragile : l'invité frappe fort, le mur cède chez les deux
	if _role != "hote":
		mur.frapper(true, Vector3.ZERO)
	_verif(await _attendre(func() -> bool: return mur.est_casse(), 6.0), "mur fragile : cassé chez moi aussi")
	await _barriere("G6")

	# ===== solo : sans réseau, tout redevient local =====
	await _pause(0.5)
	_res.deconnecter()
	_verif(not ReseauProjectiles.en_ligne() and not ReseauProjectiles.invite() and ReseauProjectiles.exclus_avatars().is_empty(), "solo : hors ligne, aucun avatar exclu")
	_verif(not ReseauProjectiles.router_meca(statues, "tourner", 0) and ReseauProjectiles.absorber_allie(10.0, {}) == 10.0, "solo : routage mécanisme inactif, aucune protection d'allié")
	var avant_solo: int = statues.orientation(0)
	statues.tourner(0)
	_verif(statues.orientation(0) == (avant_solo + 1) % 4, "solo : la statue tourne tout de suite")
	print("TEST_PROJECTILES %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)
