extends Node
## PvP coop : UNE instance (hôte ou invité), lancée deux fois par outils/test_pvp.sh (headless) :
##   godot --headless --path . res://outils/test_pvp.tscn -- --role=hote|invite --port=24851 [--sans-pvp]
## Hôte en (0,0,0) face à -Z, invité en (0,0,-8) face à +Z. Scénario en lockstep (barrières « sync »).
## Avec PvP : boule de feu, éclair en chaîne, rayon noir, glace, flèche, répulsion (hôte -> invité puis invité -> hôte), puis l'hôte
##   SAISIT l'invité (lévitation), le soulève et le LANCE : l'invité perd le contrôle, vole, atterrit, reprend la main.
## Avec --sans-pvp : aucune de ces attaques ne touche (vie intacte, pas de saisie).
## Imprime « TEST ok / ECHEC … » puis « TEST_PVP <role> OK|ECHEC » ; code de sortie 0 / 1.

const JOUEUR := preload("res://scripts/joueur.gd")
const POS_HOTE := Vector3(0, 0.1, 0)
const POS_INVITE := Vector3(0, 0.1, -8)

var _role := "hote"
var _port := 24851
var _sans := false
var _ok := true
var _res: Node
var _monde: Node3D
var _j: CharacterBody3D
var _avatar: ProtoAvatar
var _avatar_pos := Vector3.ZERO
var _vus := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
		elif a == "--sans-pvp":
			_sans = true
	_lancer.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("TEST ok     " if cond else "TEST ECHEC  ") + "[" + _role + (" sans-pvp" if _sans else "") + "] " + msg)
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
	if not await _attendre(func() -> bool: return _vus.has(nom), 90.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)

func _physics_process(_dt: float) -> void:
	# position réelle de l'autre joueur (envoyée à chaque image) : l'avatar la suit (sol : petit pas vers le bas pour is_on_floor)
	if _res != null and _res.est_en_ligne() and _res.joueurs().size() > 1 and _j != null and is_instance_valid(_j):
		_res.envoyer_evenement("test_pos", 0, _j.global_position)
	if _avatar != null and is_instance_valid(_avatar.noeud):
		var n := _avatar.noeud
		n.global_position = _avatar_pos
		n.velocity = Vector3.ZERO

func _oeil() -> Vector3:
	return _j.camera.global_position

func _avant() -> Vector3:
	return -_j.camera.global_transform.basis.z

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("test_pos", func(_e: int, _id: Variant, d: Variant) -> void: _avatar_pos = d)
	_monde = Node3D.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_j = CharacterBody3D.new()
	_j.set_script(JOUEUR)
	_j.name = "Joueur"
	_j.position = POS_HOTE if _role == "hote" else POS_INVITE
	if _role != "hote":
		_j.rotation.y = PI   # l'invité regarde vers +Z (vers l'hôte)
	_monde.add_child(_j)
	_j.vie_max = 100.0
	_j.vie = 100.0
	await _pause(0.6)
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 100.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 30.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	var autre: int = 1 if _role != "hote" else int(_res.joueurs()[1])
	_avatar_pos = (POS_INVITE if _role == "hote" else POS_HOTE) - Vector3(0, 0.1, 0)
	_avatar = ProtoAvatar.creer(_monde, autre, _avatar_pos)
	ReseauProjectiles.installer()
	CombatCoop.brancher_avatar(_avatar.noeud, autre)
	if _role == "hote":
		PvpCoop.definir(not _sans, false)
	await _barriere("connectes")
	await _pause(0.8)
	_verif(PvpCoop.actif() == (not _sans), "PvP %s chez %s" % ["inactif" if _sans else "actif", _role])

	# ===== A. sorts de l'hôte sur l'invité, puis de l'invité sur l'hôte =====
	var sorts := ["boule_feu", "chaine_eclairs", "rayon_noir", "eclat_glace"]
	for i in sorts.size():
		await _phase("sort_h_" + sorts[i], "hote", func() -> void: await _lancer_sort(sorts[i]))
		await _phase("sort_i_" + sorts[i], "invite", func() -> void: await _lancer_sort(sorts[i]))
	# ===== B. flèches =====
	await _phase("fleche_h", "hote", _tirer_fleche)
	await _phase("fleche_i", "invite", _tirer_fleche)
	# ===== C. répulsion : la victime reçoit des dégâts ET une impulsion =====
	await _phase("repulsion", "hote", _repulser)
	_j.global_position = POS_HOTE if _role == "hote" else POS_INVITE
	_j.velocity = Vector3.ZERO
	await _pause(0.5)
	# ===== C2. arme lancée (se plante dans l'avatar), mêlée =====
	await _phase("arme_lancee", "hote", _jeter_arme)
	await _phase("arme_lancee_i", "invite", _jeter_arme)
	await _melee()
	# ===== D. saisie (lévitation) puis lancer =====
	await _saisie_et_lancer()
	# ===== E. dégâts plafonnés : un coup falsifié énorme ne tue pas, un coup hors portée / sans PvP est refusé =====
	await _falsifie()

	print("TEST_PVP %s %s" % [_role, "OK" if _ok else "ECHEC"])
	await _pause(0.5)
	get_tree().quit(0 if _ok else 1)

## Une attaque de `attaquant` : la victime doit perdre de la vie (PvP) ou rien (--sans-pvp) ; l'attaquant ne perd rien.
func _phase(nom: String, attaquant: String, action: Callable) -> void:
	_j.vie = 100.0
	_j.mana = _j.mana_max
	await _barriere(nom + "_0")
	var victime := _role != attaquant
	if not victime:
		await action.call()
	if victime:
		if _sans:
			await _pause(2.5)
			_verif(is_equal_approx(_j.vie, 100.0), "%s : victime intacte sans PvP (%.1f)" % [nom, _j.vie])
		else:
			var ok := await _attendre(func() -> bool: return _j.vie < 99.9, 9.0)
			_verif(ok, "%s : la victime encaisse (%.1f PV)" % [nom, _j.vie])
			_verif(_j.vie > 0.0 and not _j.mort, "%s : pas de one-shot (vie %.1f)" % [nom, _j.vie])
			if nom.ends_with("boule_feu"):
				_verif(await _attendre(func() -> bool: return PvpVictime.pour(_j).journal.has("brule"), 3.0), "%s : brûlure appliquée à la victime" % nom)
			if nom.ends_with("eclat_glace"):
				_verif(_j.lenteur > 0.0 and _j.lenteur_facteur < 1.0, "%s : gel (ralenti %.1f s x%.2f)" % [nom, _j.lenteur, _j.lenteur_facteur])
	else:
		await _pause(2.5)
		_verif(is_equal_approx(_j.vie, 100.0), "%s : l'attaquant n'est pas blessé (%.1f)" % [nom, _j.vie])
	await _barriere(nom + "_1")
	_j.vie = 100.0
	await _pause(0.3)
	await _barriere(nom + "_2")

func _lancer_sort(id: String) -> void:
	var s := ReseauProjectiles.sort_par_id(id)
	_j.mana = _j.mana_max
	if s.portee_mode == DonneesSort.Portee.JET:
		for k in 40:
			_j.mains.magie.lanceur.canaliser(s, null, _oeil(), _avant(), 0.05, "droite")
			await get_tree().physics_frame
	else:
		_j.mains.magie.lanceur.lancer(s, null, _oeil(), _avant(), 1.0)
		await _pause(0.2)

func _tirer_fleche() -> void:
	_j.inventaire.ajouter("arc_chasseur", 1)
	_j.inventaire.ajouter("fleche", 30)
	_j.arc.equiper()
	_j.arc.appuyer()
	await _pause(1.4)
	_j.arc.relacher()

func _jeter_arme() -> void:
	# un tir qui frôle le corps (os du squelette de l'avatar, pose de test) continue son vol : on vise le torse à plusieurs hauteurs
	var o: RigidBody3D = null
	for h in [1.1, 1.3, 0.9, 1.5]:
		o = ArmeLancee.creer("epee_soldat")
		_monde.add_child(o)
		var depuis := _oeil() + _avant() * 1.0
		var vers: Vector3 = _avatar.noeud.global_position + Vector3(0, h, 0)
		var dir := (vers - depuis).normalized()
		o.global_position = depuis
		var ab := ImpactsLances.axe_monde(o, o.donnees_arme())
		var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
		o.global_basis = Basis(Quaternion(axe, dir)) * o.global_basis
		o.global_position = depuis
		o.linear_velocity = dir * 22.0
		o.set_meta("lance_par", _j)
		await get_tree().physics_frame
		ImpactsLances.objet_touche(o, _avatar.noeud, vers, -dir, dir * 22.0, _j)
		if String(ImpactsLances.dernier.get("issue", "")) != "frole" or _sans:
			break
		o.queue_free()
	await _pause(0.3)
	if not _sans:
		_verif(ImpactsLances.plantee(o) or o.has_meta("plantee"), "arme lancée : plantée dans l'avatar (%s)" % String(ImpactsLances.dernier.get("issue", "?")))

## Mêlée : les deux joueurs face à face à 1,3 m ; l'hôte frappe l'invité, puis l'invité l'hôte.
func _melee() -> void:
	if _role == "hote":
		_j.global_position = POS_HOTE
	else:
		_j.global_position = Vector3(0, 0.1, -1.3)
	_j.velocity = Vector3.ZERO
	await _pause(0.8)
	_j.arc.ranger()   # arc équipé : plus d'épée (mains._peut_agir)
	_j.mains.magie.equiper("droite", "epee")
	await _phase("melee_h", "hote", _frapper_epee)
	await _phase("melee_i", "invite", _frapper_epee)
	_j.global_position = POS_HOTE if _role == "hote" else POS_INVITE
	_j.velocity = Vector3.ZERO
	await _pause(0.8)

func _frapper_epee() -> void:
	for i in 3:
		_j.mains.attaquer()
		await _pause(1.0)

func _repulser() -> void:
	var s := ReseauProjectiles.sort_par_id("repulsion")
	_j.mana = _j.mana_max
	_j.mains.magie.esprit.repulsion(s, 1.0, null, _oeil(), _avant())

func _saisie_et_lancer() -> void:
	_j.vie = 100.0
	_j.mana = _j.mana_max
	await _barriere("lev_0")
	var depart_y := _j.global_position.y
	if _role == "hote":
		var s := ReseauProjectiles.sort_par_id("levitation")
		var es: SortsEsprit = _j.mains.magie.esprit
		var tenu := false
		for k in 90:
			_j.mana = _j.mana_max
			es.maintenir("droite", s, null, _oeil(), _avant(), 1.0 / 60.0)
			await get_tree().physics_frame
			if k == 60:
				tenu = es.tient("droite")
		_verif(tenu == (not _sans), "lévitation : l'hôte %s l'avatar de l'invité" % ("tient" if tenu else "ne tient pas"))
		if tenu:
			es.relacher("droite", s, _oeil(), _avant())
		await _pause(0.3)
	else:
		if _sans:
			await _pause(2.0)
			_verif(not PvpVictime.pour(_j).occupe() and absf(_j.global_position.y - depart_y) < 0.2, "lévitation sans PvP : l'invité n'est pas saisi")
		else:
			var v := PvpVictime.pour(_j)
			var ok := await _attendre(func() -> bool: return v.tenu, 6.0)
			_verif(ok, "lévitation : l'invité est saisi (perd le contrôle)")
			await _pause(0.6)
			_verif(_j.global_position.y > depart_y + 0.25, "lévitation : l'invité est soulevé (y=%.2f)" % _j.global_position.y)
			_verif(_j.en_dialogue, "lévitation : contrôles de l'invité gelés pendant la saisie")
			var lance := await _attendre(func() -> bool: return v.en_vol, 6.0)
			_verif(lance, "lancer : l'invité part en vol (impulsion appliquée chez son propriétaire)")
			var fini := await _attendre(func() -> bool: return not v.occupe(), 12.0)
			_verif(fini, "lancer : l'invité atterrit et reprend la main")
			_verif(not _j.en_dialogue, "lancer : contrôles rendus")
			var dz := _j.global_position.z - POS_INVITE.z
			_verif(absf(dz) > 2.0 or Vector2(_j.global_position.x, _j.global_position.z).distance_to(Vector2(POS_INVITE.x, POS_INVITE.z)) > 2.0, "lancer : déplacé de %.1f m" % Vector2(_j.global_position.x, _j.global_position.z).distance_to(Vector2(POS_INVITE.x, POS_INVITE.z)))
			_verif(not _j.mort and _j.vie >= 1.0, "lancer : jamais mortel (vie %.1f)" % _j.vie)
	await _barriere("lev_1")

## Coups falsifiés envoyés à l'hôte par l'invité : dégâts énormes (plafonnés, pas de one-shot), hors bornes (refusés).
func _falsifie() -> void:
	_j.vie = 100.0
	await _barriere("fals_0")
	if _role != "hote":
		_res.envoyer_evenement(PvpCoop.EV_COUP, 1, {"deg": 100.0, "orig": Vector3(0, 1, -4), "opt": {}}, 1)
		await _pause(0.3)
		_res.envoyer_evenement(PvpCoop.EV_COUP, 1, {"deg": 5000.0, "orig": Vector3(0, 1, -4), "opt": {}}, 1)
	else:
		await _pause(1.5)
		if _sans:
			_verif(is_equal_approx(_j.vie, 100.0), "coups falsifiés sans PvP : rien (%.1f)" % _j.vie)
		else:
			_verif(_j.vie < 100.0 and _j.vie > 0.0 and not _j.mort, "coup énorme plafonné : l'hôte encaisse sans mourir (%.1f)" % _j.vie)
			_verif(PvpCoop.refuses >= 1, "dégâts hors bornes (5000) refusés par l'hôte (%d refus)" % PvpCoop.refuses)
	await _barriere("fals_1")
