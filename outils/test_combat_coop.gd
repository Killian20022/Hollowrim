extends Node
## LOT 4a : ennemis et dégâts multi-cibles — UNE instance (hôte ou invité), lancée deux fois par outils/test_combat_coop.sh :
##   godot --headless --path . res://outils/test_combat_coop.tscn -- --role=hote|invite --port=24811
## Les deux instances déroulent le MÊME scénario en lockstep (barrières « sync »). Imprime « TEST ok / ECHEC … » puis
## « TEST_COMBAT_COOP <role> OK|ECHEC » ; code de sortie 0 / 1.
## Couvre : échelle PV/dégâts selon n (et retour proportionnel quand n baisse), ciblage (plus proche, à terre ignoré, menace),
## coups de l'invité validés par l'hôte (cadence, portée) et répliqués, coup ennemi résolu par la VICTIME (+ PV répliqués),
## mort répliquée (ragdoll chez l'invité), marionnettes libérées à la déconnexion.

class FauxMonde extends Node3D:
	var joueur: CharacterBody3D
	var village: Node3D
	var cycle: Node
	var hud: Node
	var dialogue: Control
	var vie: Node
	var faune: Node
	var marchand: Node

const JOUEUR := preload("res://scripts/joueur.gd")
const DRAUGR := preload("res://scripts/draugr.gd")
const TROLL := preload("res://scripts/troll_givre_ia.gd")
const DRAGON := preload("res://scripts/dragon.gd")

var _role := "hote"
var _port := 24811
var _ok := true
var _res: Node
var _joueur: CharacterBody3D
var _monde: FauxMonde
var _avatar: ProtoAvatar
var _vus := {}
var _msgs := {}           # évènements de bilan reçus (nom -> données)
var _t_pos := 0.0
var _d_cible: CharacterBody3D
var _d_hit: CharacterBody3D
var _d_mort: CharacterBody3D
var _troll: CharacterBody3D
var _dragon: CharacterBody3D

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
	if not await _attendre(func() -> bool: return _vus.has(nom), 40.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		_fin()

func _process(dt: float) -> void:
	if _res == null or _joueur == null or not _res.est_en_ligne():
		return
	_t_pos += dt
	if _t_pos >= 0.1:
		_t_pos = 0.0
		_res.envoyer_evenement("t_pos", 0, {"p": _joueur.global_position})

func _sur_pos(_e: int, _id: Variant, d: Variant) -> void:
	if _avatar != null and is_instance_valid(_avatar.noeud):
		_avatar.noeud.global_position = d["p"]

## Place le joueur local selon le rôle, puis laisse les positions se propager.
func _placer(h: Vector3, g: Vector3) -> void:
	_joueur.global_position = h if _role == "hote" else g
	_joueur.velocity = Vector3.ZERO
	await _pause(0.6)

func _sbire(ident: String, pos: Vector3, dort: bool, vie: float) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.set("type", "sbire")
	d.set("dort", dort)
	d.set("joueur", _joueur)
	d.set("ident", ident)
	d.name = ident
	if vie > 0.0:
		d.set("vie_imposee", vie)
	d.position = pos
	_monde.add_child(d)
	return d

func _journal(type: String, cle := "", val: Variant = null) -> int:
	var n := 0
	for j: Dictionary in CombatCoop.journal:
		if String(j.get("type", "")) == type and (cle == "" or j.get(cle) == val):
			n += 1
	return n

func _fin() -> void:
	print("TEST_COMBAT_COOP %s %s" % [_role, "OK" if _ok else "ECHEC"])
	await _pause(0.5)
	get_tree().quit(0 if _ok else 1)

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("t_pos", _sur_pos)
	_res.abonner("bilan", func(_e: int, id: Variant, d: Variant) -> void: _msgs[String(id)] = d)
	# --- monde minimal : sol, joueur local, ennemis (mêmes ident / positions chez tout le monde) ---
	_monde = FauxMonde.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_joueur = CharacterBody3D.new()
	_joueur.set_script(JOUEUR)
	_joueur.name = "Joueur"
	_joueur.position = Vector3(0, 0.1, 0) if _role == "hote" else Vector3(2.0, 0.1, 0)
	_monde.add_child(_joueur)
	_monde.joueur = _joueur
	await _pause(0.5)
	_joueur.set("est_local", true)
	_joueur.vie = 1.0e6
	_joueur.vie_max = 1.0e6
	_d_cible = _sbire("d_cible", Vector3(0, 0, -60), true, 0.0)
	_d_hit = _sbire("d_hit", Vector3(40, 0, 0), false, 2000.0)
	_d_mort = _sbire("d_mort", Vector3(-40, 0, 0), true, 30.0)
	_troll = CharacterBody3D.new()
	_troll.set_script(TROLL)
	_troll.set("joueur", _joueur)
	_troll.set("ident", "t_echelle")
	_troll.name = "t_echelle"
	_troll.set("vie_imposee", 1000.0)
	_troll.position = Vector3(0, 0, 60)
	_monde.add_child(_troll)
	_dragon = CharacterBody3D.new()
	_dragon.set_script(DRAGON)
	_dragon.set("joueur", _joueur)
	_dragon.set("ident", "dragon_t")
	_dragon.name = "dragon_t"
	_dragon.set("hauteur_sol", func(_x: float, _z: float) -> float: return 0.0)
	_dragon.set("centre", Vector3(0, 0, 180))
	_dragon.position = Vector3(0, 42, 180)
	_monde.add_child(_dragon)
	await _pause(0.5)

	# ===== 1. solo : rien ne change =====
	_verif(not _res.est_en_ligne(), "solo : hors ligne")
	_verif(CombatCoop.ids().size() == 5, "5 ennemis enregistrés (draugr x3, troll, dragon) : %s" % str(CombatCoop.ids()))
	_verif(is_equal_approx(float(_d_hit.vie_max), 2000.0) and not bool(_d_hit.marionnette), "solo : PV de base, pas de marionnette")
	_verif(is_equal_approx(CombatCoop.facteur_pv(1), 1.0) and is_equal_approx(CombatCoop.facteur_pv(2), 1.6) and is_equal_approx(CombatCoop.facteur_pv(4), 2.8),
		"facteurs PV : x1,0 / x1,6 / x2,8 pour 1 / 2 / 4 joueurs")
	_verif(_d_cible.joueur == _joueur, "solo : la cible reste le joueur (maj_cible sans effet)")
	var degats_base := float(_d_hit.get_meta("coop_base_degats"))

	# ===== connexion =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 40.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 30.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	var autre: int = 1 if _role != "hote" else int(_res.joueurs()[1])
	_avatar = ProtoAvatar.creer(_monde, autre, Vector3(2.0, 0.0, 0.0) if _role == "hote" else Vector3(0, 0.0, 0))
	await _barriere("connectes")

	# ===== 2. échelle PV / dégâts =====
	await _attendre(func() -> bool: return is_equal_approx(float(_d_hit.vie_max), 3200.0) and is_equal_approx(float(_troll.vie_max), 1600.0), 8.0)
	_verif(Effets.coop, "Effets.coop actif en coop (finishers / ralentis coupés)")
	_verif(is_equal_approx(float(_d_hit.vie_max), 3200.0), "PV du draugr x1,6 (2000 -> 3200) : %.1f" % float(_d_hit.vie_max))
	_verif(is_equal_approx(float(_troll.vie_max), 1600.0), "PV du troll (EnnemiBase) x1,6 : %.1f" % float(_troll.vie_max))
	_verif(absf(float(_d_hit.vie) - 3200.0) < 1.0, "vie pleine proportionnelle : %.1f" % float(_d_hit.vie))
	if _role == "hote":
		_verif(absf(float(_d_hit.degats) - degats_base * 1.2) < 0.01, "dégâts x1,2 chez l'hôte (%.2f -> %.2f)" % [degats_base, float(_d_hit.degats)])
		_verif(not bool(_d_hit.marionnette), "hôte : l'ennemi garde son IA")
	else:
		_verif(bool(_d_hit.marionnette) and bool(_troll.marionnette) and bool(_dragon.marionnette), "invité : ennemis = marionnettes")
	await _barriere("echelle")

	# ===== 3. ciblage (observé chez l'hôte) =====
	await _placer(Vector3(0, 0.1, -72), Vector3(0, 0.1, -45))   # hôte 12 m, invité 15 m du dormeur
	if _role == "hote":
		var cible_h := await _attendre(func() -> bool: return _d_cible.joueur == _joueur, 3.0)
		_verif(cible_h, "cible = joueur le plus proche (hôte à 12 m, invité à 15 m)")
	await _placer(Vector3(0, 0.1, -90), Vector3(0, 0.1, -72))   # hôte 30 m, invité 12 m
	if _role == "hote":
		var cible_i := await _attendre(func() -> bool: return _d_cible.joueur == _avatar.noeud, 3.0)
		_verif(cible_i, "cible bascule sur l'invité (12 m contre 30 m)")
		_avatar.noeud.set("a_terre", true)
		var cible_t := await _attendre(func() -> bool: return _d_cible.joueur == _joueur, 3.0)
		_verif(cible_t, "joueur à terre non ciblé (retour sur l'hôte)")
		_avatar.noeud.set("a_terre", false)
	await _placer(Vector3(0, 0.1, -72), Vector3(0, 0.1, -46))   # hôte 12 m, invité 14 m
	if _role == "hote":
		await _attendre(func() -> bool: return _d_cible.joueur == _joueur, 3.0)
		_verif(_d_cible.joueur == _joueur, "tenue : cible = hôte (12 m) malgré l'invité à 14 m")
		CombatCoop.noter_menace(_d_cible, autre, 100.0)   # l'invité a fait 100 de dégâts : plus menaçant
		var cible_m := await _attendre(func() -> bool: return _d_cible.joueur == _avatar.noeud, 3.0)
		_verif(cible_m, "menace : l'invité, plus menaçant, devient la cible (14 m contre 12 m)")
		_verif(_d_cible.joueur is CharacterBody3D, "la cible reste un CharacterBody3D")
	await _barriere("ciblage")

	# ===== 4. coups de l'invité (validés par l'hôte) =====
	_joueur.global_position = Vector3(0, 0.1, -150) if _role == "hote" else Vector3(40, 0.1, -3)
	_joueur.velocity = Vector3.ZERO
	await _pause(0.8)
	var vie0 := float(_d_hit.vie)
	var info := {"attaque": "legere", "type": "tranchant", "point": Vector3(40, 1.0, 0)}
	if _role == "invite":
		await _attendre(func() -> bool: return bool(_d_hit.marionnette), 3.0)
		var r1: String = _d_hit.recevoir_coup(40.0, _joueur.global_position, false, info)
		var r2: String = _d_hit.recevoir_coup(40.0, _joueur.global_position, false, info)   # même image : cadence refusée par l'hôte
		_verif(r1 == "touche" and r2 == "touche", "marionnette : retour immédiat « touche » (%s, %s)" % [r1, r2])
		await _pause(0.5)
		_d_hit.recevoir_coup(40.0, _joueur.global_position, false, info)                  # 3e coup, cadence respectée
		await _pause(0.6)
		_joueur.global_position = Vector3(40, 0.1, -60)                                    # loin : hors de portée
		await _pause(0.7)
		_d_hit.recevoir_coup(40.0, _joueur.global_position, false, info)
		await _pause(0.5)
	if _role == "hote":
		var baisse := await _attendre(func() -> bool: return float(_d_hit.vie) < vie0 - 1.0, 6.0)
		_verif(baisse, "coup de l'invité appliqué chez l'hôte (%.1f -> %.1f)" % [vie0, float(_d_hit.vie)])
		await _pause(2.5)
		_verif(_journal("applique", "de", autre) == 2, "2 coups appliqués sur 3 (cadence refuse le doublon) : %d" % _journal("applique", "de", autre))
		_verif(_journal("refus", "raison", "cadence") == 1, "1 refus de cadence : %d" % _journal("refus", "raison", "cadence"))
		_verif(_journal("refus", "raison", "portee") == 1, "1 refus de portée (invité à 60 m) : %d" % _journal("refus", "raison", "portee"))
		_res.envoyer_evenement("bilan", "vie_hote", {"vie": float(_d_hit.vie), "vm": float(_d_hit.vie_max)})
		_verif(_d_hit.joueur == _avatar.noeud, "l'ennemi frappé cible l'invité qui le frappe")
	else:
		await _attendre(func() -> bool: return _msgs.has("vie_hote"), 5.0)
		await _pause(0.6)
		var m: Dictionary = _msgs.get("vie_hote", {})
		_verif(not m.is_empty() and absf(float(_d_hit.vie) - float(m["vie"])) < 2.0 and float(_d_hit.vie) < 3200.0,
			"PV de la marionnette = PV de l'hôte (%.1f / %.1f)" % [float(_d_hit.vie), float(m.get("vie", -1.0))])
	await _barriere("coups")

	# ===== 5. coup ennemi : la VICTIME décide =====
	await _placer(Vector3(0, 0.1, -150), Vector3(40, 0.1, -2))
	var vie_av := float(_joueur.vie)
	var subis := 0
	if _role == "hote":
		await _attendre(func() -> bool: return _d_hit.joueur == _avatar.noeud, 3.0)
		_verif(_d_hit.joueur == _avatar.noeud, "le draugr éveillé vise l'invité (seul joueur proche)")
		var naturel := await _attendre(func() -> bool: return _journal("subi_envoye") > 0, 10.0)
		if not naturel:
			_avatar.noeud.recevoir_coup(15.0, _d_hit.global_position, {"type": "physique"})
			await _pause(0.5)
		print("INFO coup ennemi naturel : ", naturel)
		_verif(_journal("subi_envoye") > 0, "coup d'ennemi sur l'avatar -> « cb_coup_subi » envoyé à la victime")
		await _pause(1.5)
		_verif(CombatCoop.dernier_res.has(autre), "résultat de la victime reçu par l'hôte : %s" % str(CombatCoop.dernier_res.get(autre)))
		var avh: float = float(_avatar.noeud.vie)
		_msgs.erase("vie_invite")
		await _attendre(func() -> bool: return _msgs.has("vie_invite"), 6.0)
		var mi: Dictionary = _msgs.get("vie_invite", {})
		_verif(not mi.is_empty() and float(mi["vie"]) < 1.0e6, "la victime a bien perdu des PV chez elle (%.1f)" % float(mi.get("vie", -1.0)))
		_verif(not mi.is_empty() and absf(avh - float(mi["vie"])) < 2.0 and avh < 1.0e6, "PV de l'invité répliqués pour l'affichage chez l'hôte (%.1f / %.1f)" % [avh, float(mi.get("vie", -1.0))])
		_verif(float(_joueur.vie) == 1.0e6, "les PV de l'hôte ne bougent pas (il n'est pas la cible)")
	else:
		await _attendre(func() -> bool: return _journal("subi") > 0, 14.0)
		subis = _journal("subi")
		await _pause(1.5)
		_verif(subis > 0, "l'invité a résolu le coup chez lui (« subi » x%d, résultat %s)" % [subis, str(CombatCoop.journal.filter(func(j: Dictionary) -> bool: return j["type"] == "subi").map(func(j: Dictionary) -> String: return j["res"]))])
		_verif(float(_joueur.vie) < vie_av, "PV de l'invité baissent chez lui (%.1f -> %.1f)" % [vie_av, float(_joueur.vie)])
		_res.envoyer_evenement("bilan", "vie_invite", {"vie": float(_joueur.vie)})
		await _pause(1.0)
	await _barriere("victime")

	# ===== 6. mort répliquée =====
	await _placer(Vector3(0, 0.1, -150), Vector3(-40, 0.1, -3))
	if _role == "invite":
		await _attendre(func() -> bool: return bool(_d_mort.marionnette), 3.0)
		_d_mort.recevoir_coup(100.0, _joueur.global_position, false, {"attaque": "legere", "type": "tranchant", "point": Vector3(-40, 1.0, 0)})
		var mort_i := await _attendre(func() -> bool: return not _d_mort.vivant(), 6.0)
		_verif(mort_i, "la marionnette meurt chez l'invité (ragdoll déclenché par l'hôte)")
		_verif(_journal("mort") >= 1 or not _d_mort.vivant(), "évènement « cb_mort » reçu")
	else:
		var mort_h := await _attendre(func() -> bool: return not _d_mort.vivant(), 6.0)
		_verif(mort_h, "l'hôte a tué le draugr sur le coup de l'invité")
		_verif(_journal("applique", "id", "e:d_mort") == 1, "un seul coup appliqué sur d_mort")
	await _pause(1.0)
	await _barriere("mort")

	# ===== 7. déconnexion de l'invité : l'échelle revient en proportion =====
	var ratio_h := 0.0
	var ratio_t := 0.0
	if _role == "hote":
		ratio_h = float(_d_hit.vie) / float(_d_hit.vie_max)
		ratio_t = float(_troll.vie) / float(_troll.vie_max)
		_troll.vie = float(_troll.vie_max) * 0.5   # blessé à 50 % : doit rester à 50 %
		ratio_t = 0.5
	await _barriere("avant_deco")
	if _role == "invite":
		_res.deconnecter()
		await _pause(0.3)
		_verif(not bool(_d_hit.marionnette) and not Effets.coop, "invité déconnecté : marionnettes relâchées, Effets.coop faux")
	else:
		await _attendre(func() -> bool: return _res.joueurs().size() == 1, 10.0)
		await _attendre(func() -> bool: return is_equal_approx(float(_d_hit.vie_max), 2000.0), 4.0)
		_verif(is_equal_approx(float(_d_hit.vie_max), 2000.0), "n=1 : PV de base rétablis (%.1f)" % float(_d_hit.vie_max))
		_verif(absf(float(_d_hit.vie) / float(_d_hit.vie_max) - ratio_h) < 0.01, "vie conservée en proportion (%.3f -> %.3f)" % [ratio_h, float(_d_hit.vie) / float(_d_hit.vie_max)])
		_verif(absf(float(_troll.vie) / float(_troll.vie_max) - ratio_t) < 0.01 and is_equal_approx(float(_troll.vie_max), 1000.0), "troll : 50 %% conservé, PV de base 1000 (%.1f)" % float(_troll.vie_max))
		_verif(absf(float(_d_hit.degats) - degats_base) < 0.01, "dégâts de base rétablis")
		_verif(not Effets.coop, "Effets.coop de nouveau faux")
	_fin()
