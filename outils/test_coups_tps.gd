extends SceneTree
## Test sans fenêtre des coups d'arme du corps à la 3e personne (CorpsCoupsTps, branche tps/coups) :
##   godot --headless --path . --fixed-fps 60 --script res://outils/test_coups_tps.gd -- --nouvelle
## 1. Combo 1-2-3-4 au rythme des clics : le corps suit coup_a6, coup_b6, coup_t6, coup_c6 (4 captures différentes), plus
##    de Sword_Attack ; la pointe de l'arme balaie un vrai arc pendant chaque frappe.
## 2. Coup puissant : charge tenue (armé tenu) puis frappe ; selon le déplacement (arrêt, en avançant, à droite, en reculant)
##    le corps joue la capture de la direction choisie par mains.gd.
## 3. Garde tenue, parade, coup encaissé : poses de défense.
## 4. Claymore (deux mains) : coups 2 mains, modèle de la claymore dans la main, main gauche sur la poignée.
## 5. Hache, masse : leurs gestes ; l'arme affichée suit l'équipement.
## 6. Poignet : la main droite ne casse pas (écart à l'axe de l'avant-bras borné).
## 7. Retour à la locomotion après le geste.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var corps: Node3D
var ct: CorpsCoupsTps
var _vus: Array[String] = []
var _poignet_max := 0.0
var _pointe := []   # positions monde de la pointe pendant les frappes
var _vel := Vector3.ZERO   # vitesse imposée au joueur (repère du joueur) avant chaque image : choix du coup puissant

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pointe_monde() -> Vector3:
	var m: Node3D = ct.modele_arme() if ct.modele_arme() != null else corps.arme_corps
	var aabb := AABB()
	var premier := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.get_aabb()
		aabb = b if premier else aabb.merge(b)
		premier = false
	# repère du modèle : la lame suit +Y ; la pointe = haut de la boîte
	return m.global_transform * Vector3(0.0, aabb.end.y, 0.0)

## Avance mains (pas imposé) et le moteur (corps, squelette) image par image ; note les clips suivis et le poignet.
func _avancer(duree: float) -> void:
	for i in roundi(duree / DT):
		j.velocity = j.global_transform.basis * _vel
		mains.avancer(DT)
		await process_frame
		var c := ct._clip
		if c != "" and (_vus.is_empty() or _vus[-1] != c):
			_vus.append(c)
		if ct._actif_clip and ct._poids > 0.99:
			_poignet_max = maxf(_poignet_max, ct.poignet_deg)
		if mains.etat == mains.FRAPPE:
			_pointe.append(_pointe_monde())

## Objets visibles accrochés à la main droite du corps (épée fixe d'origine, arme de CorpsMainsTps, toute autre copie).
func _armes_visibles() -> int:
	var sq: Skeleton3D = corps.modele.find_child("Skeleton3D", true, false)
	var n := 0
	for c in sq.get_children():
		if c is BoneAttachment3D and (c as BoneAttachment3D).bone_name == "hand_r":
			for o in c.get_children():
				if o is Node3D and (o as Node3D).visible and not o.find_children("*", "MeshInstance3D", true, false).is_empty():
					n += 1
	return n

## Main gauche du corps dans le repère du joueur (pose finale : accroche de CorpsMainsTps).
func _main_g_locale() -> Vector3:
	var a: Node3D = corps.mains_tps.get("_accroche")["gauche"]
	return j.global_transform.affine_inverse() * a.global_position - _cou_local()

## Base du cou dans le repère du joueur (les captures plient les jambes : on mesure la main par rapport au buste).
func _cou_local() -> Vector3:
	var sq: Skeleton3D = corps.modele.find_child("Skeleton3D", true, false)
	for c in sq.get_children():
		if c is BoneAttachment3D and (c as BoneAttachment3D).bone_name == "neck_01":
			return j.global_transform.affine_inverse() * (c as Node3D).global_position
	var b := BoneAttachment3D.new()
	b.bone_name = "neck_01"
	sq.add_child(b)
	return j.global_transform.affine_inverse() * b.global_position

## Deux mains, pose finale : poignet gauche -> sa cible sur la poignée de l'arme affichée (CorpsMainsTps.cible_gauche_locale).
func _ecart_final_gauche() -> float:
	# accroches (pose APRÈS les modificateurs ; get_bone_global_pose rend celle d'avant)
	var sq: Skeleton3D = corps.modele.find_child("Skeleton3D", true, false)
	var md: Transform3D = (corps.mains_tps.get("_accroche")["droite"] as Node3D).global_transform
	var mg: Transform3D = (corps.mains_tps.get("_accroche")["gauche"] as Node3D).global_transform
	var c: Transform3D = sq.global_transform * corps.mains_tps.cible_gauche_locale(sq.global_transform.affine_inverse() * md)
	# point de prise de la main gauche (pivot_torche) -> point visé sur la poignée (l'orientation du poignet peut différer)
	var pv: Vector3 = corps.pivot_torche.transform.origin
	return (mg * pv).distance_to(c * pv)

func _arc() -> float:
	var l := 0.0
	for k in range(1, _pointe.size()):
		l += (_pointe[k] as Vector3).distance_to(_pointe[k - 1])
	return l

func _reset() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0)
	j.vigueur = j.vigueur_max
	_vel = Vector3.ZERO
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains.defense = DefenseJoueur.new()
	_vus.clear()
	_pointe.clear()
	await _avancer(0.6)
	_vus.clear()
	_pointe.clear()

func _clic(tenu := 0.05) -> void:
	mains.entrees.appuyer()
	await _avancer(tenu)
	mains.entrees.relacher()

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if id != "" else Equipement.new().main_droite)
	await _avancer(0.7)

func _tester() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	corps = j.corps
	mains.pas_manuel = true
	s.mannequin.position = Vector3(-8.0, 0.0, -8.0)
	j.basculer_vue(true)
	await process_frame
	ct = corps.coups_tps
	_verif(ct != null and ct.get_index() < corps.modele.find_child("PiedsAuSol", true, false).get_index(), "CorpsCoupsTps installé avant les pieds au sol")

	# 1. combo (épée + torche en main gauche : la torche reste levée pendant les coups, bras gauche à CorpsMainsTps)
	await _reset()
	var h_repos := _main_g_locale().y
	var h_min := 9.0
	var torche_vue := true
	var arcs: Array[float] = []
	for k in 4:
		_pointe.clear()
		await _clic()
		for i in 25:
			await _avancer(DT)
			if ct._poids > 0.5:
				h_min = minf(h_min, _main_g_locale().y)
				torche_vue = torche_vue and corps.pivot_torche.is_visible_in_tree()
		arcs.append(_arc())
	await _avancer(0.9)
	print("       combo suivi : ", _vus, " ; arcs de la pointe (m) : ", arcs.map(func(x): return snappedf(x, 0.01)))
	_verif(_vus.slice(0, 4) == ["coup_a6", "coup_b6", "coup_t6", "coup_c6"], "combo 1-2-3-4 : quatre gestes différents dans l'ordre")
	var srcs := {}
	for c in _vus.slice(0, 4):
		srcs[CorpsCoupsTps.CLIPS[c]["src"]] = true
	_verif(srcs.size() == 4, "quatre captures différentes (plus « toujours le même coup »)")
	_verif(arcs.all(func(x): return x > 0.35), "chaque frappe balaie un arc (pointe > 0,35 m)")
	print("       main gauche (torche) sous le cou : %.2f m au repos, au plus bas %.2f m pendant les coups" % [h_repos, h_min])
	_verif(torche_vue and corps.mains_tps.torche_tenue(), "torche tenue et visible pendant tout le combo")
	_verif(h_min > h_repos - 0.15, "torche levée pendant les coups (la main gauche ne retombe pas)")
	_verif(_armes_visibles() == 1, "épée : une seule arme visible dans la main du corps (%d)" % _armes_visibles())
	_verif(corps._action != "Sword_Attack" and String(corps.anim.current_animation) != "Sword_Attack", "l'ancien Sword_Attack n'est plus joué")
	_verif(not ct.pilote() and ct._poids < 0.05, "retour à la locomotion après le combo")

	# 2. puissants directionnels
	for cas: Array in [["arret", Vector3.ZERO, "charge_lourd", "lourd"], ["avant", Vector3(0, 0, -3), "charge_vertical", "lourd_vertical"],
			["droite", Vector3(3, 0, 0), "charge_gd", "lourd_gd"], ["arriere", Vector3(0, 0, 2.5), "charge_revers", "lourd_revers"]]:
		await _reset()
		_vel = cas[1]
		mains.entrees.appuyer()
		await _avancer(0.5)
		_vel = Vector3.ZERO
		await _avancer(0.5)
		var tenu_charge := ct._clip
		var t_charge := ct._t_src
		await _avancer(0.3)
		var tenu_ok: bool = ct._clip == cas[2] and absf(ct._t_src - t_charge) < 0.05
		mains.entrees.relacher()
		_pointe.clear()
		await _avancer(1.3)
		print("       puissant %s : %s ; arc %.2f m" % [cas[0], _vus, _arc()])
		_verif(tenu_charge == cas[2] and tenu_ok, "puissant %s : armé « %s » tenu pendant la charge" % [cas[0], cas[2]])
		_verif(_vus.has(cas[3]) and _arc() > 0.35, "puissant %s : frappe « %s »" % [cas[0], cas[3]])

	# 3. défense
	await _reset()
	mains.entrees.forcer_garde(1.0)
	await _avancer(0.5)
	_verif(ct._clip == "garde" and ct.pilote() and corps.anim.current_animation != "Sword_Attack", "garde tenue : pose de blocage capturée")
	mains.encaisser()
	await _avancer(0.1)
	_verif(_vus.has("garde"), "garde vue (%s)" % [_vus])
	mains.entrees.forcer_garde(0.0)
	await _avancer(0.8)

	# 4. claymore
	await _equiper("claymore")
	await _reset()
	_verif(ct.modele_arme() != null and ct.modele_arme() == corps.mains_tps.arme_tenue() and not corps.arme_corps.visible, "claymore affichée dans la main du corps (modèle de CorpsMainsTps)")
	_verif(_armes_visibles() == 1, "une seule arme visible dans la main droite du corps (%d)" % _armes_visibles())
	var ecarts: Array[float] = []
	var finals: Array[float] = []
	for k in 3:
		_pointe.clear()
		await _clic()
		for i in 40:
			await _avancer(DT)
			if ct._poids > 0.99 and ct.ecart_gauche >= 0.0:
				ecarts.append(ct.ecart_gauche)
			finals.append(_ecart_final_gauche())
		await _avancer(0.3)
	await _avancer(1.0)
	print("       claymore : ", _vus, " ; écart main gauche / poignée max %.3f m" % ecarts.max())
	_verif(_vus.slice(0, 3) == ["c2_a", "c2_b", "c2_c"], "claymore : combo deux mains")
	_verif(not ecarts.is_empty() and ecarts.max() < 0.06, "claymore : main gauche sur la poignée (< 6 cm)")
	print("       claymore : pose finale (après l'IK de CorpsMainsTps), main gauche -> poignée max %.3f m" % finals.max())
	_verif(finals.max() < 0.08, "claymore : main gauche restée sur la poignée de l'arme affichée pendant tout le coup (pose finale)")

	# 5. hache, masse
	for cas: Array in [["hache_guerre", "h_a"], ["masse_cloutee", "m_a"]]:
		await _equiper(cas[0])
		await _reset()
		await _clic()
		await _avancer(0.9)
		_verif(_vus.has(cas[1]) and ct.modele_arme() != null and _armes_visibles() == 1, "%s : geste %s, une seule arme affichée" % [cas[0], cas[1]])
	await _equiper("")

	# 6. poignet
	print("       poignet droit : écart max à l'axe de l'avant-bras %.1f°" % _poignet_max)
	_verif(_poignet_max <= CorpsCoupsTps.POIGNET_MAX_TEST, "poignet droit borné (pas de casse)")
	print("FIN test_coups_tps : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
