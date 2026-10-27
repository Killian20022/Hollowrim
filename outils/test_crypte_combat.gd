extends SceneTree
## Test sans fenêtre : combats enchaînés dans la VRAIE crypte (foret_test) contre des gardiens draugrs et squelettes — bug
## « ça rame énormément quand je tape dans la crypte » (2026-10-27). Vérifie :
##  - le tampon des uniformes d'instance est assez grand (sinon « Too many instances using shader instance variables » à chaque
##    gardien qui apparaît, et plus d'éclair blanc sur les ennemis touchés) ;
##  - les sons de combat sont des WAV (une lecture Ogg Vorbis coûtait ~2 ms de fil principal, 2 à 4 sons par coup) ;
##  - les caches d'effets sont prêts avant le 1er coup (textures peintes), et réutilisés (matériaux de particules, bouchons de cou) ;
##  - arrêt sur image « bref » (défaut) : aucun gel sur un coup léger, ralenti ×0,2 (pas ×0,03) sur un coup lourd, temps rendu à 1 ;
##  - coût d'un coup (appel de recevoir_coup / subir_finisher) borné après le préchauffage ;
##  - cadavres et têtes coupées restent dans la crypte (pas sous le sol) ;
##  - deux préchauffages simultanés rendent au soleil ses couches d'origine quel que soit l'ordre de fin.
##   bash outils/tous_les_tests.sh test_crypte_combat
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var _echecs := 0
var _ts_min := 1.0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	Effets.niveau_force = 1      # arrêt sur image « bref » (défaut du jeu), quelle que soit l'option du poste
	Sang.niveau_force = 2
	RetourImpact.muet = true
	process_frame.connect(func() -> void: _ts_min = minf(_ts_min, Engine.time_scale))

	# --- réglages et ressources
	var taille := int(ProjectSettings.get_setting("rendering/limits/global_shader_variables/buffer_size", 65536))
	_verif(taille >= 262144, "tampon des uniformes d'instance : %d (≥ 262144 : ~35 gardiens + décor de la crypte)" % taille)
	var n_ogg := 0
	var n_tot := 0
	for cat: String in RetourImpact.BANQUE:
		for nom: String in RetourImpact.BANQUE[cat]:
			n_tot += 1
			if not RetourImpact._chemin(nom).ends_with(".wav"):
				n_ogg += 1
	_verif(n_ogg == 0, "sons de combat en WAV : %d / %d" % [n_tot - n_ogg, n_tot])
	var n_k := 0
	for nom in ["impactPlate_medium_000", "impactPlate_medium_001", "impactWood_heavy_000", "impactMetal_heavy_001", "swing2", "mnstr1", "footstep_snow_000"]:
		if Sons.flux(nom) is AudioStreamWAV:
			n_k += 1
	_verif(n_k == 7, "bruitages Kenney du combat (lame contre mur, pas, râles) en WAV : %d / 7" % n_k)

	# --- deux préchauffages qui partagent le soleil
	var sol := DirectionalLight3D.new()
	sol.layers = 5
	root.add_child(sol)
	for ordre in [[0, 1], [1, 0]]:
		var p: Array = [PrechauffeRendu.lancer(null, root, [Transform3D()], sol), PrechauffeRendu.lancer(null, root, [Transform3D()], sol)]
		await process_frame
		var pendant := sol.layers
		p[ordre[0]].free()
		p[ordre[1]].free()
		_verif(pendant == 1 << 19 and sol.layers == 5, "soleil partagé par deux préchauffages (fin %s) : couches %d pendant, %d après (5 attendu)" % [ordre, pendant, sol.layers])
	sol.free()

	# --- la vraie crypte
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	j = m.joueur
	for i in 5:
		await physics_frame
	_verif(Sang._tex.size() >= 18, "textures de sang et de plaies peintes au chargement (%d)" % Sang._tex.size())
	var t = m.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	var c: Node3D = t.crypte
	t.dedans = true
	c.visible = true
	var choisis: Array = []
	var nb := {"draugr": 0, "squelette": 0}
	for g: Dictionary in t.donjon.gardiens:
		var ty := String(g["type"])
		var ex: Dictionary = g["extra"]
		if ty == "squelette_archer" or ex.has("si") or ex.has("reveil_evt") or ex.has("boss"):
			continue
		var cle := "squelette" if ty.begins_with("squelette") else "draugr"
		if nb[cle] < 2:
			nb[cle] += 1
			choisis.append(g)
	_verif(choisis.size() == 4, "4 gardiens choisis (2 draugrs, 2 squelettes) : %s" % [choisis.map(func(g): return g["ident"])])
	var appels_legers: Array = []
	var bouchons0: int = Decapitation._mats_bouchon.size()
	var premier := -1.0
	var pm_vus := {}
	var corps: Array = []
	var n_tetes := 0
	for g: Dictionary in choisis:
		var id := String(g["ident"])
		var pos: Vector3 = c.to_global(g["pos"])
		var face := Basis(Vector3.UP, c.global_rotation.y + float(g["lacet"])).z
		j.global_position = pos + face * 2.0 + Vector3(0, 0.1, 0)
		for k in 20:
			if m.draugrs.has(id) and is_instance_valid(m.draugrs[id]):
				break
			t._gerer_zones()
			await physics_frame
		if not (m.draugrs.has(id) and is_instance_valid(m.draugrs[id])):
			_verif(false, "%s apparaît" % id)
			continue
		var e = m.draugrs[id]
		corps.append(e)
		for k in 5:
			await physics_frame
		# 3 coups légers au torse, 1 lourd, puis posture brisée → finisher (décapitation)
		for k in 5:
			if not e.vivant():
				break
			_viser(e)
			var att := "lourde" if k == 3 else "legere"
			var info := _info(e, att, k)
			_ts_min = 1.0
			var t0 := Time.get_ticks_usec()
			if k == 4:
				e.combat.briser_posture()
				e._etourdir()
				var cat := String(e.finisher_possible(j))
				info["attaque"] = "finisher"
				info["origine"] = j.global_position
				info["stagger"] = 999.0
				info["zone"] = "tete"
				e.subir_finisher(cat if cat != "" else "etourdi", info)
			else:
				e.vie = maxf(e.vie, 200.0)      # le gardien survit jusqu'au finisher
				DegatsCombat.appliquer(e, 6.0 if att == "legere" else 14.0, j.global_position, att == "lourde", info)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if k == 0:
				premier = maxf(premier, ms)      # 1er coup sur chaque gardien (1er de son espèce compris)
			elif k < 3:
				appels_legers.append(ms)
			for n in m.get_children():
				if n is GPUParticles3D and n.process_material != null:
					pm_vus[n.process_material.get_instance_id()] = true
			# ~1 s de jeu (70 images ; les tests tournent en --fixed-fps 60, les minuteurs « temps réel » suivent ce pas) : le temps doit revenir à 1
			for f in 70:
				j.vie = j.vie_max
				await process_frame
			if k == 0:
				_verif(_ts_min >= 0.999, "%s, coup léger : aucun arrêt sur image en « bref » (échelle mini %.2f)" % [id, _ts_min])
			elif k == 3:
				_verif(absf(_ts_min - 0.2) < 0.01 or _ts_min >= 0.999, "%s, coup lourd : ralenti ×0,2 au plus (échelle mini %.2f, ×0,03 avant)" % [id, _ts_min])
			_verif(is_equal_approx(Engine.time_scale, 1.0), "%s, coup %d (%s) : temps revenu à 1 (%.2f), appel %.1f ms" % [id, k, info["attaque"], Engine.time_scale, ms])
		_verif(not e.vivant(), "%s achevé par le finisher" % id)
		if e.modele != null and e.modele.has_meta("tete_coupee"):
			n_tetes += 1
	_verif(premier < 40.0, "1er coup sur chaque gardien, après préchauffage : pire %.1f ms (150-200 ms avant : 1re compilation, textures)" % premier)
	appels_legers.sort()
	var pire := float(appels_legers[-1]) if not appels_legers.is_empty() else 0.0
	_verif(pire < 15.0, "coups légers suivants : pire appel %.1f ms (%d coups ; ~10 ms avant, dont 2 ms par son Ogg)" % [pire, appels_legers.size()])
	_verif(n_tetes >= 2, "têtes coupées : %d" % n_tetes)
	_verif(Decapitation._mats_bouchon.size() - bouchons0 <= 0, "bouchons de cou : matériaux partagés (%d avant les combats, %d après %d décapitations)" % [bouchons0, Decapitation._mats_bouchon.size(), n_tetes])
	_verif(Sang._pm_cache.size() <= 24 and pm_vus.size() <= Sang._pm_cache.size() + Effets._pm.size() + Sang._pm_jets.size() + 2, "matériaux de particules réutilisés : %d en cache, %d distincts vus" % [Sang._pm_cache.size(), pm_vus.size()])
	# cadavres et têtes : 3 s de physique, puis tous dans la crypte, au-dessus du sol
	for f in 180:
		await physics_frame
	var bas := 99.0
	var loin := 0.0
	for e in corps:
		if not is_instance_valid(e):
			continue
		for b in e.find_children("*", "PhysicalBone3D", true, false):
			var pl := c.to_local((b as Node3D).global_position)
			bas = minf(bas, pl.y)
			loin = maxf(loin, Vector2(pl.x, pl.z).length())
	for b in m.find_children("TeteCoupee", "RigidBody3D", true, false):
		var pl := c.to_local((b as Node3D).global_position)
		bas = minf(bas, pl.y)
		loin = maxf(loin, Vector2(pl.x, pl.z).length())
	_verif(bas > -0.4 and loin < 120.0, "cadavres et têtes dans la crypte : point le plus bas %.2f m, le plus loin %.1f m" % [bas, loin])
	_verif(is_equal_approx(Engine.time_scale, 1.0) and Effets._demandes.is_empty(), "fin : échelle de temps 1, aucune demande en cours")
	# garde-fou : une demande échue n'est plus prise en compte
	Effets._demandes.append([0.03, Time.get_ticks_msec() - 10])
	Effets._maj_temps()
	_verif(is_equal_approx(Engine.time_scale, 1.0) and Effets._demandes.is_empty(), "une demande d'échelle échue est ignorée (temps 1)")
	Effets.niveau_force = -1
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)

func _viser(e) -> void:
	var v: Vector3 = e.global_position - j.global_position
	j.rotation.y = atan2(-v.x, -v.z)

func _info(e, att: String, k: int) -> Dictionary:
	var c0: Vector3 = e.global_position + Vector3(0, float(e.combat.hauteur) * 0.6, 0)   # torse (squelettes plus petits : 1,15 m = tête)
	var dirj: Vector3 = (c0 - j.global_position).normalized()
	var arme: DonneesArme = j.mains.arme
	return {"type": "tranchant", "point": c0 - dirj * 0.25, "direction": j.global_transform.basis.x * (1.0 if k % 2 == 0 else -1.0),
		"normale": -dirj, "zone": "torse", "attaque": att, "arme": arme.id, "stagger": DegatsCombat.stagger(arme, att), "collider": e}
