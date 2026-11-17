extends Node
## LOT 7 — tests de résilience réseau (une instance par processus ; lancée par outils/test_resilience.sh) :
##   godot --headless --path . res://outils/test_resilience.tscn -- --role=hote|invite --scn=<scénario> --port=N [--idx=1..3] [--invites=N] [--sim-latence=ms --sim-gigue=ms --sim-perte=%]
## Scénarios : conditions (verrous d'état + combat + parade sous latence/perte) ; depart (invité tué net en plein combat) ; hote_perdu (l'hôte est tué net) ;
## reconnexion (coupure simulée -> 3 essais -> reprise ; puis coupure durable -> abandon) ; debit (N invités, bande passante).
## Imprime « TEST_RESILIENCE <role> OK|ECHEC » et des lignes « METRIQUE … » reprises par le script.

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
const CYCLE := preload("res://scripts/cycle.gd")
const VILLAGEOIS := preload("res://scripts/villageois.gd")

var _role := "hote"
var _scn := "conditions"
var _port := 25201
var _idx := 1
var _nb_inv := 1
var _ok := true
var _res: Node
var _rs: Resilience
var _j: CharacterBody3D
var _monde: FauxMonde
var _ac: AvatarsCoop
var _cycle: Node
var _sync := {}      # nom -> {expediteur: true}
var _go := {}
var _recu := {}      # cle -> {expediteur: valeur}
var _gagnes := {}
var _perdus := {}
var _sim := Vector3.ZERO
var _silence := 3.5
var _n_pnj := 12
var _n_ennemis := 6

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--scn="):
			_scn = a.substr(6)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
		elif a.begins_with("--idx="):
			_idx = int(a.substr(6))
		elif a.begins_with("--pnj="):
			_n_pnj = int(a.substr(6))
		elif a.begins_with("--ennemis="):
			_n_ennemis = int(a.substr(10))
		elif a.begins_with("--silence="):
			_silence = float(a.substr(10))
		elif a.begins_with("--invites="):
			_nb_inv = int(a.substr(10))
	var p := SimulateurReseau.parametres()
	_sim = Vector3(float(p["latence"]), float(p["gigue"]), float(p["perte"]))
	_lancer.call_deferred()

func _etiq() -> String:
	return _role if _role == "hote" else "invite%d" % _idx

func _verif(cond: bool, msg: String) -> void:
	print(("TEST ok     " if cond else "TEST ECHEC  ") + "[" + _etiq() + "] " + msg)
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

func _fin() -> void:
	print("TEST_RESILIENCE %s %s" % [_etiq(), "OK" if _ok else "ECHEC"])
	await _pause(0.5)
	get_tree().quit(0 if _ok else 1)

# barrière à N invités : les invités signalent à l'hôte (renvoi toutes les s tant qu'ils n'ont pas de « go »), l'hôte répond « go » quand tous sont arrivés
func _barriere(nom: String, delai := 90.0) -> void:
	if _role == "hote":
		if not await _attendre(func() -> bool: return (_sync.get(nom, {}) as Dictionary).size() >= _nb_inv, delai):
			_verif(false, "barrière « %s » : %d/%d invités" % [nom, (_sync.get(nom, {}) as Dictionary).size(), _nb_inv])
			_fin()
			return
		_go[nom] = true
		_res.envoyer_evenement("go", nom, null)
	else:
		var t := 0.0
		while not _go.has(nom) and t < delai:
			_res.envoyer_evenement("sync", nom, null)
			var u := 0.0
			while not _go.has(nom) and u < 1.0:
				await get_tree().create_timer(0.05).timeout
				u += 0.05
			t += u
		if not _go.has(nom):
			_verif(false, "barrière « %s » jamais atteinte" % nom)
			_fin()

func _envoyer(cle: String, v: Variant) -> void:
	_res.envoyer_evenement("tres", cle, v)

## Hôte : valeur de la clé reçue de l'invité n°`i` (ordre de connexion) ; attend.
func _recevoir(cle: String, delai := 60.0) -> Dictionary:
	await _attendre(func() -> bool: return (_recu.get(cle, {}) as Dictionary).size() >= _nb_inv, delai)
	return _recu.get(cle, {})

func _ennemi(ident: String, type: String, pos: Vector3, vie: float, dort := true) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.set("type", type)
	d.set("dort", dort)
	d.set("joueur", _j)
	d.set("ident", ident)
	d.name = ident
	d.set("vie_imposee", vie)
	d.position = pos
	_monde.add_child(d)
	if dort:
		d.set_physics_process(false)
	return d

func _journal(type: String, cle := "", val: Variant = null) -> int:
	var n := 0
	for e: Dictionary in CombatCoop.journal:
		if String(e.get("type", "")) == type and (cle == "" or e.get(cle) == val):
			n += 1
	return n

func _journal_ennemi(type: String, ident: String) -> int:
	return _journal(type, "id", "e:" + ident)

func _autres() -> Array:
	var r: Array = []
	for id in _res.joueurs():
		if int(id) != _res.mon_id():
			r.append(int(id))
	return r

func _av(id: int) -> CharacterBody3D:
	var a: AvatarDistant = _ac.avatars.get(id) if _ac != null else null
	return a.noeud if a != null and is_instance_valid(a.noeud) else null

func _info_coup(pt: Vector3) -> Dictionary:
	return {"attaque": "legere", "type": "tranchant", "point": pt + Vector3(0, 1.1, 0), "direction": Vector3(1, -0.4, 0).normalized(), "normale": Vector3(0, 0, 1), "zone": "torse"}

# ------------------------------------------------------------------------------------------------ monde de test

func _monter_monde(avec_villageois: int) -> void:
	_monde = FauxMonde.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_j = CharacterBody3D.new()
	_j.set_script(JOUEUR)
	_j.name = "Joueur"
	_j.position = Vector3(0, 0.1, 45) if _role == "hote" else Vector3(2.0 * _idx, 0.1, 0)
	_monde.add_child(_j)
	_monde.joueur = _j
	_cycle = Node.new()
	_cycle.set_script(CYCLE)
	_cycle.env = Environment.new()
	_cycle.lumiere = DirectionalLight3D.new()
	_cycle.ciel = ShaderMaterial.new()
	_cycle.heure = 15.0 if _role == "hote" else 3.0
	_monde.add_child(_cycle)
	_monde.cycle = _cycle
	if avec_villageois > 0:
		var liste: Array = VILLAGEOIS.charger()
		for i in mini(avec_villageois, liste.size()):
			var p: CharacterBody3D = VILLAGEOIS.new()
			p.donnees = liste[i]
			p.joueur = _j
			p.points = [Vector3(i * 4.0 - 20.0, 0.1, -10), Vector3(i * 4.0 - 20.0, 0.1, -40), Vector3(i * 4.0 - 8.0, 0.1, -25)]
			p.position = p.points[0]
			_monde.add_child(p)
			p._prochaine_promenade = 0.1
	ReseauMondeVivant.installer(_monde)

func _connecter() -> void:
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > _nb_inv, 240.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > _nb_inv and _res.mon_id() > 1, 90.0)
	_verif(_res.joueurs().size() == 1 + _nb_inv, "%d joueurs en ligne (%s)" % [1 + _nb_inv, str(_res.joueurs())])
	_ac = AvatarsCoop.installer(_monde, _j, "Joueur-" + _etiq())
	ReseauProjectiles.installer()
	_rs = Resilience.instance()
	_verif(_rs != null, "nœud Resilience présent")
	if _rs != null:
		_rs.retour_titre_auto = false
		_rs.pause_essais = 1.0
		_rs.delai_confirmation = 3.0
		_rs.silence_max = _silence
		_rs.periode_ping = 0.25

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(e: int, id: Variant, _d: Variant) -> void:
		if not _sync.has(String(id)):
			_sync[String(id)] = {}
		_sync[String(id)][e] = true
		if _role == "hote" and _go.has(String(id)):
			_res.envoyer_evenement("go", id, null, e))   # retardataire (reconnecté) : on lui répond
	_res.abonner("go", func(_e: int, id: Variant, _d: Variant) -> void: _go[String(id)] = true)
	_res.abonner("tres", func(e: int, id: Variant, d: Variant) -> void:
		if not _recu.has(String(id)):
			_recu[String(id)] = {}
		_recu[String(id)][e] = d)
	_res.abonner("comp", func(_e: int, _id: Variant, d: Variant) -> void: Resilience.compensation = bool(d))
	await _monter_monde(_n_pnj if _scn == "debit" else 0)
	await _pause(0.5)
	_j.set("est_local", true)
	_j.vie = 1.0e6
	_j.vie_max = 1.0e6
	print("SCENARIO %s role=%s sim=latence %.0f gigue %.0f perte %.0f%%" % [_scn, _etiq(), _sim.x, _sim.y, _sim.z])
	match _scn:
		"conditions":
			await _sc_conditions()
		"depart":
			await _sc_depart()
		"hote_perdu":
			await _sc_hote_perdu()
		"reconnexion":
			await _sc_reconnexion()
		"debit":
			await _sc_debit()
	_fin()

# ================================================================================================ 1. conditions
func _sc_conditions() -> void:
	var d_hit := _ennemi("r_hit", "sbire", Vector3(3, 0, -2), 4000.0)
	var d_salve_on := _ennemi("r_salve_on", "sbire", Vector3(4, 0, -3), 4000.0)
	var d_salve_off := _ennemi("r_salve_off", "sbire", Vector3(0, 0, -3), 4000.0)
	var d_p_on := _ennemi("r_port_on", "sbire", Vector3(30, 0, -30), 4000.0)
	var d_p_off := _ennemi("r_port_off", "sbire", Vector3(50, 0, -30), 4000.0)
	if _role == "hote":
		_cycle.heure = 15.0
	await _connecter()
	await _barriere("connectes")
	var autre := int(_autres()[0]) if not _autres().is_empty() else 0
	var sim_actif := _sim.x > 0.0 or _sim.z > 0.0

	# ---- 1. RTT / perte mesurés
	await _pause(7.0)
	if _rs != null and autre != 0:
		var rtt := float(_rs.rtt.get(autre, -1.0))
		var perte := _rs.perte_mesuree(autre)
		print("METRIQUE rtt %s sim=%.0f/%.0f/%.0f rtt_mesure=%.0f ms rtt_min=%.0f rtt_max=%.0f perte_pings=%.1f%% ENet_rtt=%.0f" % [_etiq(), _sim.x, _sim.y, _sim.z, rtt,
			float(_rs.rtt_min.get(autre, -1.0)), float(_rs.rtt_max.get(autre, -1.0)), perte * 100.0, float(_rs.rtt_enet.get(autre, -1.0))])
		_verif(rtt >= 0.0, "RTT mesuré (%.0f ms)" % rtt)
		if sim_actif:
			_verif(rtt >= _sim.x * 0.6 and rtt <= _sim.x * 2.2 + 80.0, "RTT cohérent avec la simulation (%.0f ms pour %.0f simulés)" % [rtt, _sim.x])
		else:
			_verif(rtt < 60.0, "RTT local faible (%.0f ms)" % rtt)
	await _barriere("rtt")

	# ---- 2. heure alignée
	# l'hôte part de 15 h et avance de 1 h / 100 s : on compare à la lecture de l'hôte envoyée après l'attente
	var ok_heure := await _attendre(func() -> bool: return absf(fposmod(float(_cycle.heure) - 15.0 + 12.0, 24.0) - 12.0) < 1.0, 25.0)
	var h_hote: Variant = await _echanger_valeur("heure", float(_cycle.heure))
	var ecart_h := absf(fposmod(float(_cycle.heure) - float(h_hote) + 12.0, 24.0) - 12.0)
	_verif(ok_heure and ecart_h < 1.0, "heure alignée à l'heure près (moi %.2f h, autre %.2f h, écart %.2f h)" % [float(_cycle.heure), float(h_hote), ecart_h])
	await _barriere("heure")

	# ---- 3. coffre pris une fois + porte
	ReseauLieux.enregistrer_porte("res:porte", func() -> void: _gagnes["porte_rejouee"] = true)
	await _barriere("coffre_pret")
	ReseauLieux.reclamer("res:coffre", func() -> void: _gagnes["res:coffre"] = true, func() -> void: _perdus["res:coffre"] = true)
	await _attendre(func() -> bool: return _gagnes.has("res:coffre") or _perdus.has("res:coffre"), 30.0)
	_envoyer("coffre", 1 if _gagnes.has("res:coffre") else 0)
	if _role == "invite":
		ReseauLieux.router_porte("res:porte")
	var porte_ok := await _attendre(func() -> bool: return ReseauLieux.porte_ouverte("res:porte"), 30.0)
	_verif(porte_ok, "porte ouverte des deux côtés")
	await _barriere("coffre_porte")
	if _role == "hote":
		var cf := await _recevoir("coffre")
		var total := (1 if _gagnes.has("res:coffre") else 0)
		for e in cf:
			total += int(cf[e])
		_verif(total == 1, "coffre pris UNE seule fois malgré la latence (total %d)" % total)

	# ---- 4. coups d'invité validés par l'hôte
	var vie0 := float(d_hit.vie)
	if _role == "invite":
		for i in 8:
			d_hit.recevoir_coup(40.0, _j.global_position, false, _info_coup(Vector3(3, 0, -2)))
			await _pause(0.35)
	if _role == "hote":
		await _attendre(func() -> bool: return _journal_ennemi("applique", "r_hit") + _journal_ennemi("refus", "r_hit") >= 8, 40.0)
		_verif(_journal_ennemi("applique", "r_hit") == 8, "8 coups espacés de l'invité appliqués (appliqués %d, refus %d)" % [_journal_ennemi("applique", "r_hit"), _journal_ennemi("refus", "r_hit")])
	await _barriere("coups")
	await _pause(2.5)
	await _barriere("coups_fin")
	var pv_h: Variant = await _echanger_valeur("pv_hit", float(d_hit.vie))
	_verif(absf(float(d_hit.vie) - float(pv_h)) < 1.0, "PV de l'ennemi identiques des deux côtés (%.1f / %.1f ; départ %.1f)" % [float(d_hit.vie), float(pv_h), vie0])

	# ---- 5. salves rapprochées (3 coups / 150 ms) : compensation de cadence ON puis OFF
	await _salves(d_salve_on, "r_salve_on", Vector3(4, 0, -3), true)
	await _salves(d_salve_off, "r_salve_off", Vector3(0, 0, -3), false)

	# ---- 6. portée : l'invité court vers l'ennemi et frappe à 5,5 m
	await _courses(d_p_on, "r_port_on", Vector3(30, 0, -30), true)
	await _courses(d_p_off, "r_port_off", Vector3(50, 0, -30), false)
	if _role == "hote":
		Resilience.compensation = true

	# ---- 7. parade / esquive de la victime
	await _defense()

	# ---- 8. avatar visible et à sa place
	await _pause(1.5)
	var mon_pos := [_j.global_position.x, _j.global_position.z]
	var vrai: Variant = await _echanger_valeur("pos_vraie", mon_pos)
	var av := _av(autre)
	_verif(av != null, "avatar de l'autre visible")
	if av != null and vrai is Array:
		var ecart := Vector2(av.global_position.x - float(vrai[0]), av.global_position.z - float(vrai[1])).length()
		_verif(ecart < 0.6, "avatar à la position du joueur distant (écart %.2f m)" % ecart)
	if _rs != null:
		print("METRIQUE fin %s %s" % [_etiq(), _rs.resume()])
	await _barriere("fin")

## Envoie `v` à l'autre et renvoie ce qu'il envoie (hôte : valeur de l'invité n°1 ; invité : valeur de l'hôte via « tres » de l'hôte).
func _echanger_valeur(cle: String, v: Variant) -> Variant:
	_res.envoyer_evenement("tres", cle, v)
	var autre := int(_autres()[0]) if not _autres().is_empty() else 1
	await _attendre(func() -> bool: return (_recu.get(cle, {}) as Dictionary).has(autre), 40.0)
	return (_recu.get(cle, {}) as Dictionary).get(autre, null)

func _salves(e: CharacterBody3D, ident: String, pos: Vector3, comp: bool) -> void:
	if _role == "hote":
		Resilience.compensation = comp
		_res.envoyer_evenement("comp", 0, comp)
	await _barriere("salve_" + ident + "_prep")
	if _role == "invite":
		for s in 4:
			for i in 3:
				e.recevoir_coup(30.0, _j.global_position, false, _info_coup(pos))
				await _pause(0.15)
			await _pause(1.2)
	else:
		await _attendre(func() -> bool: return _journal_ennemi("applique", ident) + _journal_ennemi("refus", ident) >= 12, 40.0)
		await _pause(1.0)
		var ap := _journal_ennemi("applique", ident)
		var rf := _journal_ennemi("refus", ident)
		print("METRIQUE salves compensation=%s sim=%.0f/%.0f/%.0f appliques=%d/12 refus=%d" % [str(comp), _sim.x, _sim.y, _sim.z, ap, rf])
		if comp:
			_verif(ap == 12, "salves (3 coups / 150 ms) : 12 coups légitimes tous acceptés avec compensation (%d, refus %d)" % [ap, rf])
	await _barriere("salve_" + ident)

func _courses(e: CharacterBody3D, ident: String, pos: Vector3, comp: bool) -> void:
	if _role == "hote":
		Resilience.compensation = comp
		_res.envoyer_evenement("comp", 0, comp)
	await _barriere("course_" + ident + "_prep")
	if _role == "invite":
		for k in 5:
			var t := 0.0
			_j.global_position = pos + Vector3(0, 0.1, 12.0)
			var frappe := false
			while t < 3.0 and not frappe:
				await get_tree().physics_frame
				var dt := get_physics_process_delta_time()
				t += dt
				_j.velocity = Vector3.ZERO
				_j.global_position += Vector3(0, 0, -7.0) * dt
				if _j.global_position.distance_to(pos) <= 5.5:
					e.recevoir_coup(30.0, _j.global_position, false, _info_coup(pos))
					frappe = true
			await _pause(1.2)   # il continue de courir ? non : on se replace (cadence large)
	else:
		await _attendre(func() -> bool: return _journal_ennemi("applique", ident) + _journal_ennemi("refus", ident) >= 5, 40.0)
		await _pause(1.0)
		var ap := _journal_ennemi("applique", ident)
		var rf := _journal_ennemi("refus", ident)
		print("METRIQUE portee compensation=%s sim=%.0f/%.0f/%.0f appliques=%d/5 refus=%d (portee %d)" % [str(comp), _sim.x, _sim.y, _sim.z, ap, rf, _journal("refus", "raison", "portee")])
		if comp:
			_verif(ap == 5, "course vers l'ennemi, frappes à 5,5 m : 5/5 acceptées avec compensation (%d, refus %d)" % [ap, rf])
	await _barriere("course_" + ident)

func _defense() -> void:
	# l'hôte envoie des coups d'ennemi à l'avatar de l'invité ; la victime décide chez elle. Phase A : esquive (invulnérable) ; B : sans défense ; C : garde levée
	var n := 6
	var phases := ["esquive", "libre", "garde"]
	for ph: String in phases:
		await _barriere("def_" + ph + "_prep")
		var avant := _journal("subi")
		if _role == "invite":
			_j.esquive_t = -1.0
			_j.mains.pas_manuel = ph == "garde"   # la machine d'états des mains est figée : la garde forcée tient entre deux coups
			if ph == "garde":
				_j.mains.combat.forcer(EtatCombat.GARDE)
			_boucle_def = true
			_phase_def = ph
			_boucler_defense()
		await _barriere("def_" + ph + "_pret")
		if _role == "hote":
			var av := _av(int(_autres()[0]))
			if av != null:
				for i in n:
					av.recevoir_coup(10.0, av.global_position + Vector3(0, 0, -3), {})   # devant l'invité (il regarde -Z)
					await _pause(0.3)
		await _barriere("def_" + ph + "_envoye")
		if _role == "invite":
			await _attendre(func() -> bool: return _journal("subi") - avant >= n, 40.0)
			_boucle_def = false
			_j.mains.pas_manuel = false
			_j.esquive_t = -1.0
			var res: Array = []
			for k in range(CombatCoop.journal.size() - 1, -1, -1):
				var e: Dictionary = CombatCoop.journal[k]
				if String(e.get("type", "")) == "subi":
					res.append(String(e.get("res", "")))
					if res.size() >= n:
						break
			var attendu := {"esquive": ["esquive"], "libre": ["touche"], "garde": ["bloque", "parade", "brisee"]}[ph] as Array
			var tous := res.size() == n and res.all(func(r: String) -> bool: return attendu.has(r))
			print("METRIQUE defense phase=%s sim=%.0f/%.0f/%.0f resultats=%s" % [ph, _sim.x, _sim.y, _sim.z, str(res)])
			_verif(tous, "défense locale « %s » : %d/%d résultats corrects, non affectés par la latence %s" % [ph, res.filter(func(r: String) -> bool: return attendu.has(r)).size(), n, str(res)])
		await _barriere("def_" + ph)

var _boucle_def := false
var _phase_def := ""

func _boucler_defense() -> void:
	while _boucle_def:
		await get_tree().physics_frame
		_j.rotation = Vector3.ZERO   # regarde -Z
		match _phase_def:
			"esquive":
				_j.esquive_t = 0.0
			"garde":
				_j.mains.combat.forcer(EtatCombat.GARDE)   # (re-forcée à chaque image par sûreté)

# ================================================================================================ 2. départ brutal d'un invité en plein combat
func _sc_depart() -> void:
	var d_menace := _ennemi("d_menace", "guerrier", Vector3(3, 0, -2), 3000.0, false)
	var d_mort1 := _ennemi("d_mort1", "guerrier", Vector3(-3, 0, -2), 30.0)
	var d_mort2 := _ennemi("d_mort2", "guerrier", Vector3(-2, 0, 3), 30.0)
	await _connecter()
	await _barriere("connectes")
	var inv := int(_autres()[0]) if _role == "hote" else 1
	# l'invité blesse le guerrier éveillé (menace), tue deux sbires, en fouille un ; l'hôte garde son monde
	if _role == "invite":
		for i in 5:
			d_menace.recevoir_coup(40.0, _j.global_position, false, _info_coup(Vector3(3, 0, -2)))
			await _pause(0.3)
		d_mort1.recevoir_coup(100.0, _j.global_position, false, _info_coup(Vector3(-3, 0, -2)))
		d_mort2.recevoir_coup(100.0, _j.global_position, false, _info_coup(Vector3(-2, 0, 3)))
	await _attendre(func() -> bool: return not d_mort1.vivant() and not d_mort2.vivant(), 30.0)
	await _attendre(func() -> bool: return d_mort1._butin != null and d_mort2._butin != null, 30.0)
	_verif(d_mort1._butin != null and d_mort2._butin != null, "[%s] deux corps fouillables existent" % _etiq())
	for b in [d_mort1._butin, d_mort2._butin]:
		if b != null:
			b.objets["os_draugr"] = 1
	await _barriere("corps")
	if _role == "invite":
		d_mort2._butin.fouiller()   # l'invité fouille le 2e corps : l'attribution lui appartient
		await _attendre(func() -> bool: return bool(d_mort2._butin.gagnant), 30.0)
		_verif(bool(d_mort2._butin.gagnant), "invité : a fouillé le corps 2")
	await _barriere("fouille")
	if _role == "hote":
		var menace_av := 0
		for ident in ["e:d_menace"]:
			var m: Dictionary = CombatCoop.ennemi(ident).get_meta("coop_menace", {})
			menace_av = m.size()
		_verif(CombatCoop.ennemi("e:d_menace").get_meta("coop_menace", {}).has(inv), "hôte : l'invité a généré de la menace sur le guerrier")
		_verif(_av(inv) != null, "hôte : l'avatar de l'invité existe avant le départ")
		_rs_parti = false
		_rs.joueur_parti.connect(func(_id: int) -> void: _rs_parti = true)
		print("METRIQUE depart_debut %.2f" % (Time.get_ticks_msec() / 1000.0))
	await _barriere("avant_depart")
	if _role == "invite":
		print("TEST_RESILIENCE %s OK" % _etiq() if _ok else "TEST_RESILIENCE %s ECHEC" % _etiq())
		print("INVITE_TUE_NET")
		OS.kill(OS.get_process_id())
		return
	# --- hôte : l'invité a disparu sans prévenir (aucun paquet d'adieu) ---
	var t0 := Time.get_ticks_msec()
	var parti := await _attendre(func() -> bool: return _res.joueurs().size() == 1, 40.0)
	var delai := (Time.get_ticks_msec() - t0) / 1000.0
	_verif(parti, "hôte : l'invité tué net est retiré de la liste (délai de détection %.1f s)" % delai)
	print("METRIQUE depart_detection_s=%.1f" % delai)
	await _pause(1.5)
	_verif(_av(inv) == null, "hôte : avatar de l'invité retiré de la scène")
	_verif(not _ac.avatars.has(inv), "hôte : AvatarsCoop ne le référence plus")
	_verif(_res.registre.noeud(inv) == null, "hôte : registre sans nœud pour lui")
	_verif(_rs_parti, "hôte : signal Resilience.joueur_parti émis")
	var g := CombatCoop.ennemi("e:d_menace")
	_verif(is_instance_valid(g) and g.vivant(), "hôte : le guerrier est toujours vivant")
	_verif(not (g.get_meta("coop_menace", {}) as Dictionary).has(inv), "hôte : menace du parti retirée")
	_verif(g.get("joueur") == _j, "hôte : le guerrier a repris l'hôte pour cible")
	_verif(is_instance_valid(d_mort1._butin), "hôte : le corps non fouillé est toujours là")
	d_mort1._butin.fouiller()
	await _pause(1.0)
	_verif(bool(d_mort1._butin.gagnant), "hôte : peut fouiller le corps laissé par le parti (butin non perdu)")
	d_mort2._butin.fouiller()
	await _pause(1.0)
	_verif(not bool(d_mort2._butin.gagnant), "hôte : le corps déjà fouillé par le parti reste attribué (pas de doublon de butin)")
	var pv := float(g.vie)
	await _pause(2.0)
	_verif(is_instance_valid(g) and g.vivant(), "hôte : le monde continue de tourner (guerrier OK, PV %.0f)" % float(g.vie))
	# un nouvel invité pourrait arriver : le serveur accepte encore
	_verif(not _res.est_hote() == false, "hôte : toujours hôte")

var _rs_parti := false

# ================================================================================================ 3. l'hôte part (tué net)
func _sc_hote_perdu() -> void:
	await _connecter()
	_j.inventaire.ajouter("os_draugr", 3)
	await _barriere("connectes")
	if _role == "hote":
		print("TEST_RESILIENCE %s OK" % _etiq() if _ok else "TEST_RESILIENCE %s ECHEC" % _etiq())
		await _pause(1.0)
		print("HOTE_TUE_NET")
		OS.kill(OS.get_process_id())
		return
	# --- invité ---
	var etat := {"recu": false, "en_ligne_a_l_emission": false, "inventaire": -1, "raison": "", "msgs": [], "tentatives": [], "abandon": "", "titre": ""}
	_res.hote_perdu.connect(func(raison: String) -> void:
		etat["recu"] = true
		etat["raison"] = raison
		etat["en_ligne_a_l_emission"] = _res.est_en_ligne()
		etat["inventaire"] = _j.inventaire.nombre("os_draugr"))
	_rs.message.connect(func(t: String) -> void: etat["msgs"].append(t))
	_rs.reconnexion_tentative.connect(func(n: int, m: int) -> void: etat["tentatives"].append([n, m]))
	_rs.reconnexion_abandonnee.connect(func(t: String) -> void: etat["abandon"] = t)
	_rs.retour_titre_demande.connect(func(t: String) -> void: etat["titre"] = t)
	var t0 := Time.get_ticks_msec()
	var vu := await _attendre(func() -> bool: return etat["recu"], 40.0)
	var delai := (Time.get_ticks_msec() - t0) / 1000.0
	_verif(vu, "invité : Reseau.hote_perdu émis (raison « %s », après %.1f s)" % [str(etat["raison"]), delai])
	print("METRIQUE hote_perdu_detection_s=%.1f" % delai)
	_verif(etat["en_ligne_a_l_emission"], "invité : hook émis AVANT le retour en solo (sauvegarde possible)")
	_verif(etat["inventaire"] == 3, "invité : personnage intact à l'émission (inventaire %s)" % str(etat["inventaire"]))
	await _pause(0.3)
	_verif(not _res.est_en_ligne() and _res.est_hote() and _res.joueurs() == [1] or _rs.reconnexion_en_cours, "invité : retour en solo propre (ou reconnexion en cours)")
	var abandon := await _attendre(func() -> bool: return String(etat["abandon"]) != "", 90.0)
	_verif(abandon, "invité : reconnexion abandonnée après les essais (%s)" % str(etat["tentatives"]))
	_verif(etat["tentatives"].size() == 3, "invité : exactement 3 essais (%d)" % etat["tentatives"].size())
	_verif(String(etat["titre"]) != "" and Resilience.message_en_attente != "", "invité : retour au titre demandé avec un message (« %s »)" % String(etat["titre"]))
	_verif(etat["msgs"].size() >= 2, "invité : messages affichables (%d)" % etat["msgs"].size())
	_verif(_res.joueurs() == [1] and not _res.est_en_ligne(), "invité : solo propre à la fin")
	_verif(is_instance_valid(_j) and _j.vie > 0.0, "invité : le personnage est toujours là")

# ================================================================================================ 4. reconnexion
func _sc_reconnexion() -> void:
	await _connecter()
	_j.inventaire.ajouter("os_draugr", 5)
	await _barriere("connectes")
	await _pause(2.0)
	var ancien: int = _res.mon_id() if _role == "invite" else int(_autres()[0])
	var etat := {"perdu": false, "reussie": false, "nouvel": 0, "tentatives": [], "abandon": ""}
	var pos_avant := _j.global_position
	if _role == "invite":
		_rs.reconnexion_tentative.connect(func(n: int, m: int) -> void: etat["tentatives"].append([n, m]))
		_rs.reconnexion_reussie.connect(func(a: int, n: int) -> void:
			etat["reussie"] = true
			etat["nouvel"] = n)
		_rs.reconnexion_abandonnee.connect(func(t: String) -> void: etat["abandon"] = t)
		_res.hote_perdu.connect(func(_r: String) -> void:
			etat["perdu"] = true
			if not etat.get("durable", false):
				SimulateurReseau.coupe_globale = false)   # phase 1 : la liaison revient dès que la perte est déclarée
		await _pause(0.5)
		print("COUPURE_SIMULEE_1")
		SimulateurReseau.coupe_globale = true
	await _barriere("coupure1", 120.0)   # barrière : l'hôte attend l'invité (sync arrive après la reconnexion : hôte et invité l'envoient une fois reliés)
	if _role == "invite":
		_verif(etat["perdu"], "invité : perte de l'hôte détectée (coupure simulée)")
		var ok := await _attendre(func() -> bool: return etat["reussie"], 60.0)
		_verif(ok, "invité : reconnexion automatique réussie (essais %s)" % str(etat["tentatives"]))
		_verif(etat["nouvel"] > 1, "invité : nouvel identifiant réseau %d (ancien %d)" % [etat["nouvel"], ancien])
		_verif(_res.joueurs().size() == 2 and _res.est_en_ligne(), "invité : de nouveau en ligne %s" % str(_res.joueurs()))
		_verif(_j.inventaire.nombre("os_draugr") == 5, "invité : personnage repris tel quel (inventaire)")
		_verif(_j.global_position.distance_to(pos_avant) < 0.5, "invité : même position après reprise")
	else:
		var nv := await _attendre(func() -> bool: return _res.joueurs().size() == 2 and int(_autres()[0]) != ancien, 60.0)
		_verif(nv, "hôte : l'invité est revenu avec un nouvel id (%s, ancien %d)" % [str(_res.joueurs()), ancien])
	await _pause(4.0)
	if _role == "hote":
		var nvid := int(_autres()[0]) if not _autres().is_empty() else 0
		_verif(_av(nvid) != null, "hôte : nouvel avatar visible")
		_verif(_av(ancien) == null or ancien == nvid, "hôte : l'ancien avatar a disparu")
		_verif(String(_res.registre.infos(nvid).get("nom", "")).begins_with("Joueur-"), "hôte : nom du personnage repris (%s)" % str(_res.registre.infos(nvid).get("nom", "")))
	await _barriere("reprise", 120.0)

	# ---- phase 2 : coupure durable -> 3 essais -> abandon
	if _role == "invite":
		etat["tentatives"] = []
		etat["perdu"] = false
		etat["durable"] = true
		etat["abandon"] = ""
		await _pause(0.5)
		print("COUPURE_SIMULEE_2")
		SimulateurReseau.coupe_globale = true
		var perdu := await _attendre(func() -> bool: return etat["perdu"], 40.0)
		_verif(perdu, "invité : 2e perte détectée")
		var ab := await _attendre(func() -> bool: return String(etat["abandon"]) != "", 120.0)
		_verif(ab, "invité : coupure durable -> abandon après %d essais (%s)" % [etat["tentatives"].size(), String(etat["abandon"])])
		_verif(etat["tentatives"].size() == 3, "invité : 3 essais exactement")
		SimulateurReseau.coupe_globale = false
	else:
		await _attendre(func() -> bool: return _res.joueurs().size() == 1, 60.0)
		_verif(_res.joueurs().size() == 1, "hôte : l'invité muet est retiré (silence)")
		await _pause(2.0)

# ================================================================================================ 5. débit (N invités)
func _sc_debit() -> void:
	var autour: Array = []
	for i in _n_ennemis:
		autour.append(_ennemi("b_%d" % i, "guerrier" if i % 2 == 0 else "sbire", Vector3(cos(i) * 12.0, 0, sin(i) * 12.0 - 10.0), 5000.0, false))
	await _connecter()
	await _barriere("connectes")
	await _pause(6.0)
	await _barriere("echauffe")
	if autour.is_empty():
		autour.append(null)
	var rs := _rs
	rs.marquer()
	var t_fin := Time.get_ticks_msec() + 30000
	var theta := float(_idx) * 1.7
	var n_coups := 0
	var dt_coup := 0.0
	while Time.get_ticks_msec() < t_fin:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		theta += dt * 0.5
		_j.velocity = Vector3.ZERO
		if _role == "invite":
			_j.global_position = Vector3(cos(theta) * 8.0, 0.1, sin(theta) * 8.0 - 10.0)
			_j.rotation.y = -theta
			dt_coup += dt
			if dt_coup > 0.5:
				dt_coup = 0.0
				var e: Node3D = autour[n_coups % autour.size()]
				if e != null and is_instance_valid(e) and e.vivant():
					e.recevoir_coup(5.0, _j.global_position, false, _info_coup(e.global_position))
					n_coups += 1
		else:
			_j.global_position = Vector3(cos(theta) * 3.0, 0.1, sin(theta) * 3.0 - 10.0)
	var b := rs.bilan()
	var par_pair := ""
	for p in (b["env_par_pair_o_s"] as Dictionary):
		par_pair += " pair%d=%.1fKo/s" % [p, float(b["env_par_pair_o_s"][p]) / 1024.0]
	print("METRIQUE debit %s joueurs=%d env=%.1f Ko/s (filaire %.1f) rec=%.1f Ko/s (filaire %.1f) paquets_env=%.0f/s rec=%.0f/s %s | rtt=%s | pics env=%.1f rec=%.1f" % [_etiq(), 1 + _nb_inv,
		float(b["env_o_s"]) / 1024.0, float(b["env_filaire_o_s"]) / 1024.0, float(b["rec_o_s"]) / 1024.0, float(b["rec_filaire_o_s"]) / 1024.0, float(b["pk_env_s"]), float(b["pk_rec_s"]), par_pair, str(rs.rtt), rs.pic_env / 1024.0, rs.pic_rec / 1024.0])
	_verif(float(b["env_o_s"]) > 0.0, "trafic mesuré")
	await _barriere("fin")
