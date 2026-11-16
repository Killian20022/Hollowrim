extends Node
## INTEGRATION LOT 4 (4a combat + 4b avatars + 4c projectiles + 4d corps) — UNE instance (hôte ou invité), lancée deux fois par outils/test_integration4.sh :
##   godot --headless --path . res://outils/test_integration4.tscn -- --role=hote|invite --port=24912
## Même scénario en lockstep. Couvre : l'invité frappe un draugr à échelle 2 joueurs (PV x1,6, coup validé par l'hôte, effet d'impact non rejoué chez lui),
## l'invité tire une flèche (arc réel, dégâts validés par l'hôte), l'ennemi tué laisse un corps fouillable UNE seule fois, et l'avatar de
## l'invité (AvatarsCoop) est visible chez l'hôte avec son équipement. Imprime « TEST_INTEGRATION4 <role> OK|ECHEC ».

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
const MOI := {
	"hote": {"nom": "Eirik", "droite": "epee", "gauche": "bouclier", "pos": Vector3(0, 0.1, 45),
		"corps": {"tete": "casque_fer", "torse": "cuirasse_fer", "mains": "gantelets_fer", "pieds": "bottes_fer"}},
	"invite": {"nom": "Astrid", "droite": "claymore", "gauche": "vide", "pos": Vector3(0, 0.1, 0),
		"corps": {"tete": "casque_acier_nordique", "torse": "cuirasse_acier_nordique", "mains": "gantelets_acier_nordique", "pieds": "bottes_acier_nordique"}},
}

var _role := "hote"
var _port := 24912
var _ok := true
var _res: Node
var _j: CharacterBody3D
var _monde: FauxMonde
var _ac: AvatarsCoop
var _vus := {}
var _recu := {}
var _impacts := 0
var _autre := 0

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
		_fin()

func _echanger(cle: String, v: Variant) -> Variant:
	_res.envoyer_evenement("tres", cle, v)
	if not await _attendre(func() -> bool: return _recu.has(cle), 30.0):
		_verif(false, "échange « %s » jamais reçu" % cle)
		return null
	return _recu[cle]

func _fin() -> void:
	print("TEST_INTEGRATION4 %s %s" % [_role, "OK" if _ok else "ECHEC"])
	await _pause(0.5)
	get_tree().quit(0 if _ok else 1)

func _ennemi(ident: String, type: String, pos: Vector3, vie: float) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.set("type", type)
	d.set("dort", true)
	d.set("joueur", _j)
	d.set("ident", ident)
	d.name = ident
	d.set("vie_imposee", vie)
	d.position = pos
	_monde.add_child(d)
	return d

func _av() -> CharacterBody3D:
	var a: AvatarDistant = _ac.avatars.get(_autre) if _ac != null else null
	return a.noeud if a != null and is_instance_valid(a.noeud) else null

func _journal(type: String, cle := "", val: Variant = null) -> int:
	var n := 0
	for e: Dictionary in CombatCoop.journal:
		if String(e.get("type", "")) == type and (cle == "" or e.get(cle) == val):
			n += 1
	return n

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("tres", func(_e: int, id: Variant, d: Variant) -> void: _recu[String(id)] = d)
	_res.abonner("corps_impact", func(_e: int, _id: Variant, _d: Variant) -> void: _impacts += 1)
	var moi: Dictionary = MOI[_role]
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
	_j = CharacterBody3D.new()
	_j.set_script(JOUEUR)
	_j.name = "Joueur"
	_j.position = moi["pos"]
	_monde.add_child(_j)
	_monde.joueur = _j
	await _pause(0.5)
	_j.set("est_local", true)
	_j.vie = 1.0e6
	_j.vie_max = 1.0e6
	# mêmes ennemis, mêmes ident, mêmes positions des deux côtés (autour de l'invité, loin de l'hôte)
	var d_hit := _ennemi("i4_hit", "sbire", Vector3(3, 0, -2), 2000.0)
	var d_fleche := _ennemi("i4_fleche", "sbire", Vector3(0, 0, -12), 2000.0)
	var d_mort := _ennemi("i4_mort", "guerrier", Vector3(-3, 0, -2), 30.0)
	for d in [d_hit, d_fleche, d_mort]:
		d.set_physics_process(false)
	await _pause(0.5)
	_verif(not _res.est_en_ligne() and CombatCoop.ids().size() >= 3, "solo : hors ligne, 3 ennemis enregistrés (%s)" % str(CombatCoop.ids()))
	_verif(is_equal_approx(float(d_hit.vie_max), 2000.0), "solo : PV de base (%.0f)" % float(d_hit.vie_max))

	# ===== connexion + modules =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 240.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 90.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	_autre = 1 if _role != "hote" else int(_res.joueurs()[1])
	_ac = AvatarsCoop.installer(_monde, _j, moi["nom"])
	ReseauProjectiles.installer()
	var eq: EquipementMains = _j.mains.magie.eq
	eq.apprendre_tout()
	eq.equiper("droite", moi["droite"])
	eq.equiper("gauche", moi["gauche"])
	for e: String in moi["corps"]:
		_j.inventaire.ajouter(moi["corps"][e], 1)   # sinon EquipementCorps retire la pièce « non possédée » au prochain changement du sac
		_j.equipement_corps.emplacements[e] = moi["corps"][e]
		_j.equipement_corps.change.emit(e)
	await _barriere("connectes")

	# ===== 1. échelle 2 joueurs =====
	await _attendre(func() -> bool: return is_equal_approx(float(d_hit.vie_max), 3200.0), 8.0)
	_verif(is_equal_approx(float(d_hit.vie_max), 3200.0), "échelle 2 joueurs : PV du draugr x1,6 (%.0f)" % float(d_hit.vie_max))
	_verif(bool(d_hit.marionnette) == (_role != "hote"), "marionnette seulement chez l'invité")
	await _barriere("echelle")

	# ===== 2. l'invité frappe un draugr (corps à corps) =====
	var vie0 := float(d_hit.vie)
	var avant_rejoue := ReseauCorps.impacts_joues
	var ev_avant := _impacts
	if _role == "invite":
		var info := {"attaque": "legere", "type": "tranchant", "point": Vector3(3, 1.1, -2), "direction": Vector3(1, -0.4, 0).normalized(),
			"normale": Vector3(0, 0, 1), "zone": "torse"}
		d_hit.recevoir_coup(60.0, _j.global_position, false, info)
		await _pause(0.8)
	else:
		var baisse := await _attendre(func() -> bool: return float(d_hit.vie) < vie0 - 1.0, 8.0)
		_verif(baisse, "hôte : le coup de l'invité est appliqué (%.1f -> %.1f)" % [vie0, float(d_hit.vie)])
		_verif(_journal("applique", "de", _autre) >= 1, "hôte : coup validé par CombatCoop (applique de %d)" % _autre)
	await _barriere("coup")
	if _role == "invite":
		await _attendre(func() -> bool: return _impacts > ev_avant, 6.0)
		_verif(_impacts > ev_avant, "invité : l'évènement d'effet de coup a bien été diffusé par l'hôte (%d)" % (_impacts - ev_avant))
		_verif(ReseauCorps.impacts_joues == avant_rejoue, "invité (attaquant, info qui) : l'effet d'impact n'est PAS rejoué chez lui (%d)" % (ReseauCorps.impacts_joues - avant_rejoue))
		_verif(absf(float(d_hit.vie) - float(d_hit.vie_max)) > 1.0, "invité : PV de la marionnette répliqués (%.1f / %.1f)" % [float(d_hit.vie), float(d_hit.vie_max)])
	await _barriere("coup_fin")

	# ===== 3. flèche de l'invité =====
	var vie_f := float(d_fleche.vie)
	if _role == "invite":
		_j.inventaire.ajouter("arc_chasseur", 1)
		_j.inventaire.ajouter("fleche", 30)
		_j.arc.equiper()
		_j.arc.appuyer()
		await _pause(1.4)
		_j.arc.relacher()
	else:
		var touche := await _attendre(func() -> bool: return float(d_fleche.vie) < vie_f - 1.0, 10.0)
		_verif(touche, "hôte : la flèche de l'invité blesse le draugr (%.1f -> %.1f)" % [vie_f, float(d_fleche.vie)])
	await _pause(1.0)
	await _barriere("fleche")

	# ===== 4. mort + corps fouillable une seule fois =====
	if _role == "invite":
		d_mort.recevoir_coup(100.0, _j.global_position, false, {"attaque": "legere", "type": "tranchant", "point": Vector3(-3, 1.1, -2),
			"direction": Vector3(1, -0.4, 0).normalized(), "normale": Vector3(0, 0, 1), "zone": "torse"})
	var mort := await _attendre(func() -> bool: return not d_mort.vivant(), 10.0)
	_verif(mort, "l'ennemi tué par l'invité est mort des deux côtés")
	var bok := await _attendre(func() -> bool: return d_mort._butin != null, 10.0)
	_verif(bok, "un corps fouillable existe")
	var b: Node3D = d_mort._butin
	_verif(b != null and String(b.cle_reseau) == "corps:i4_mort", "clé réseau du corps « %s »" % (String(b.cle_reseau) if b else "?"))
	if b != null:
		b.objets["os_draugr"] = 1
	await _barriere("corps")
	if _role == "invite" and b != null:
		b.fouiller()
		await _attendre(func() -> bool: return bool(b.gagnant), 10.0)
		_verif(bool(b.gagnant), "invité : premier arrivé, il fouille le corps")
	await _barriere("fouille")
	if _role == "hote" and b != null:
		b.fouiller()
		await _pause(1.0)
		_verif(not bool(b.gagnant) and b.objets.is_empty(), "hôte : corps déjà fouillé par l'invité -> rien à prendre")
	var g: Variant = await _echanger("gagnant", 1 if (b != null and bool(b.gagnant)) else 0)
	_verif(int(g) + (1 if (b != null and bool(b.gagnant)) else 0) == 1, "un seul gagnant de la fouille")
	await _barriere("fouille_fin")

	# ===== 5. avatar de l'autre avec son équipement =====
	var autre: Dictionary = MOI["invite" if _role == "hote" else "hote"]
	await _attendre(func() -> bool: return _av() != null and String(_ac.avatars[_autre].equipement.get("nom", "")) == autre["nom"], 20.0)
	await _pause(1.2)
	var av := _av()
	_verif(av != null, "l'avatar de l'autre est visible (Joueur_%d)" % _autre)
	if av != null:
		var evp: EquipementMains = av.mains.magie.eq
		_verif(String(evp.mains["droite"].get("id", "")) == autre["droite"], "arme tenue répliquée : %s (lu : %s)" % [autre["droite"], evp.mains["droite"].get("id", "")])
		_verif(av.equipement_corps.objet_a("torse") == autre["corps"]["torse"], "armure répliquée : torse %s" % av.equipement_corps.objet_a("torse"))
		var ar: ArmureVisible = av.corps.armure
		_verif(ar != null and ar.porte("torse") == autre["corps"]["torse"] and ar.maillage("torse") != null and ar.maillage("torse").visible, "armure visible sur l'avatar")
		_verif(_ac.avatars[_autre].etiquette != null and _ac.avatars[_autre].etiquette.text == autre["nom"], "nom flottant « %s »" % autre["nom"])
		_verif(_res.registre.noeud(_autre) == av, "avatar inscrit au registre des joueurs")
		var pos_av := av.global_position
		var vrai: Variant = await _echanger("pos_vraie", [_j.global_position.x, _j.global_position.z])
		_verif(Vector2(pos_av.x - float(vrai[0]), pos_av.z - float(vrai[1])).length() < 0.3, "position de l'avatar = celle du joueur distant")
	await _barriere("avatar")
	_fin()
