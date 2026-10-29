extends SceneTree
## Test headless de la crypte (kit de donjon) : le décor ne doit pas gêner le parcours. Remplissage de la crypte par une capsule (grille de
## 0,5 m, rayon 0,34 m, escaliers et rampes compris) depuis le vestibule : chaque salle, chaque coffre, chaque interaction, chaque mécanisme et
## chaque ennemi doit être atteignable, aucun ennemi ne doit être dans un mur ; liaisons entre modules cohérentes ; réduction de surface ;
## lumières ; portes fermées bloquantes ; escaliers franchis par une capsule physique ; coffres, gardiens.
## godot --headless --path . --script outils/test_crypte.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const PAS := 0.5
const RAYON := 0.34

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	var c: Node3D = m.tertre.crypte
	var ss := m.get_world_3d().direct_space_state
	var vivants: Array[RID] = []
	for n in m.find_children("*", "CharacterBody3D", true, false):
		vivants.append((n as CharacterBody3D).get_rid())
	var t0 := Time.get_ticks_msec()
	m.tertre.attendre_donjon()
	print("attente du donjon : %d ms" % (Time.get_ticks_msec() - t0))
	for i in 5:
		await physics_frame
	var t = m.tertre
	var dj: CrypteDonjon = t.donjon
	_verif(dj != null and t._tache < 0, "donjon intégré")
	# --- plan : liaisons entre modules, surface
	var pb: Array = dj.verifier()
	for p in pb:
		print("      ", p)
	_verif(pb.is_empty(), "liaisons entre modules cohérentes (%d modules)" % dj.modules.size())
	var aire := 0.0
	var corridors := 0.0
	for id in dj.modules:
		var md: Dictionary = dj.modules[id]
		var dim: Vector2 = md["dim"]
		aire += dim.x * dim.y
		if md["role"] == "passage" or md.has("escalier"):
			corridors += dim.y
	aire += 60.0 + 16.0 + 32.0      # vestibule, alcôve d'Eirik, couloir de la herse (bâtis par tertre.gd)
	corridors += 10.0
	print("surface intérieure ≈ %d m² (avant : ≈ 4 990 m²), couloirs et escaliers ≈ %d m (avant : 254 m)" % [aire, corridors])
	_verif(aire <= 3700.0, "surface réduite d'au moins 25 %% (%d m² ≤ 3 700)" % aire)
	_verif(corridors <= 160.0, "couloirs courts (%d m ≤ 160)" % corridors)
	# --- état d'une partie avancée : portes ouvertes, mécanismes cassés
	var closes := {}
	for id in ["s1", "s2", "arene", "tombe"]:
		var pp: Node3D = dj.portes[id]
		var o := c.to_global(pp.position + Vector3(-1.2, 1.2, 0)) if id in ["s1", "s2", "tombe"] else c.to_global(pp.position + Vector3(0, 1.2, -1.2))
		var o2 := c.to_global(pp.position + Vector3(1.2, 1.2, 0)) if id in ["s1", "s2", "tombe"] else c.to_global(pp.position + Vector3(0, 1.2, 1.2))
		var rr := ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o2))
		_verif(not rr.is_empty(), "porte %s fermée : un rayon à travers est arrêté" % id)
	var sp: Node3D = dj.portes["secret"]
	var rs := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c.to_global(Vector3(-35.2, 1.2, -44.0)), c.to_global(Vector3(-37.5, 1.2, -44.0))))
	_verif(not rs.is_empty(), "mur secret de la galerie fermé : bloquant")
	var cass := get_nodes_in_group("cassables").filter(func(n): return not (n is Cassable))      # L5 : urnes et tonneaux (Cassable) hors sujet
	_verif(cass.size() == 2, "deux murs fragiles posés (%d)" % cass.size())
	for k in cass:
		var rf := ss.intersect_ray(PhysicsRayQueryParameters3D.create(k.global_position + Vector3(-1.2, 0, 0), k.global_position + Vector3(1.2, 0, 0)))
		_verif(not rf.is_empty(), "mur fragile %s fermé : bloquant" % k.name)
	_verif(not t._herse_ouverte and ss.intersect_ray(PhysicsRayQueryParameters3D.create(c.to_global(Vector3(0, 1.0, -31.0)), c.to_global(Vector3(0, 1.0, -35.0)))).size() > 0, "la herse baissée arrête un rayon de la salle de préparation vers la salle rituelle")
	# ouvre tout
	for id in ["s1", "s2"]:
		t.quetes.vus["crypte:" + id] = true
	t._porte_haut("arene", true)
	t._porte_haut("tombe", true)
	t._etat_donjon()
	(dj.portes["secret"] as Node3D).rotation.y = -PI * 0.5
	for k in get_nodes_in_group("cassables"):
		if not (k is Cassable):       # L5 : les urnes / tonneaux restent debout (ils ne bloquent pas le parcours testé : voir test_cassables)
			k.casser(false)
	t.herse.position.y = 2.9
	for i in 4:
		await physics_frame
	# --- remplissage par une capsule depuis le vestibule
	var cap := CapsuleShape3D.new()
	cap.radius = RAYON
	cap.height = 1.7
	var atteint := {}                  # Vector3i (x, z, étage) -> y (repère de la crypte) ; étage 1 = y < -3
	var niv := func(y: float) -> int:
		return 1 if y < -3.0 else 0
	var file: Array = [Vector3i(0, 1, 0)]
	atteint[Vector3i(0, 1, 0)] = 0.0
	var gy := c.global_position.y
	var libre := func(x: float, z: float, y_sol: float) -> bool:
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = cap
		qp.transform = Transform3D(Basis(), c.to_global(Vector3(x, y_sol + 0.13 + 0.85, z)))
		qp.exclude = vivants
		qp.collision_mask = 1          # masque du joueur : les cassables (calque propre) se traversent
		qp.collide_with_bodies = true
		return ss.intersect_shape(qp, 1).is_empty()
	var sol_en := func(x: float, z: float, y_ref: float) -> float:
		var a := c.to_global(Vector3(x, y_ref + 1.0, z))
		var q := PhysicsRayQueryParameters3D.create(a, a + Vector3(0, -2.3, 0))
		q.exclude = vivants
		var r := ss.intersect_ray(q)
		if r.is_empty():
			return NAN
		return (r["position"] as Vector3).y - gy
	var n_cases := 0
	var tf := Time.get_ticks_msec()
	while not file.is_empty():
		var k: Vector3i = file.pop_front()
		var yk: float = atteint[k]
		n_cases += 1
		for dxz in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = k.x + dxz.x
			var nz: int = k.y + dxz.y
			if nx < -100 or nx > 140 or nz < -180 or nz > 20:
				continue
			var x := nx * PAS
			var z := nz * PAS
			var ys: float = sol_en.call(x, z, yk)
			if is_nan(ys) or absf(ys - yk) > 0.36:
				continue
			var nk := Vector3i(nx, nz, niv.call(ys))
			if atteint.has(nk):
				continue
			if not libre.call(x, z, ys):
				continue
			atteint[nk] = ys
			file.append(nk)
	print("remplissage : %d cases (%d m²) en %d ms" % [atteint.size(), atteint.size() * PAS * PAS, Time.get_ticks_msec() - tf])
	if "--plan" in OS.get_cmdline_user_args():
		for z in dj.zones:
			var rr: Rect2 = z["rect"]
			print("ZONE %s %.1f %.1f %.1f %.1f %.1f" % [z["nom"], rr.position.x, rr.end.x, rr.position.y, rr.end.y, z["y"]])
		for g in dj.gardiens:
			var ex: Dictionary = g["extra"]
			print("ENNEMI %s %s %s %s %s" % [g["ident"], g["type"], g["zone"], "patrouille" if ex.has("patrouille") else "-", ex.get("reveil_evt", ex.get("boss", "-"))])
		for it in dj.interactions:
			print("INTER %s %s %s %s" % [it["id"], it["genre"], it["nom"], str(it.get("butin", ""))])
		for a in dj.meca:
			print("MECA %s %s" % [a["genre"], a["id"]])
	if "--carte" in OS.get_cmdline_user_args():
		# carte ASCII (1 m par caractère) : « . » étage 0, « , » étage -1 (« # » : les deux)
		var bas := "--bas" in OS.get_cmdline_user_args()
		for z in range(-82, 7):
			var ligne := ""
			for x in range(-48, 62):
				var h0 := false
				var h1 := false
				for sx in 2:
					for sz in 2:
						h0 = h0 or atteint.has(Vector3i(x * 2 + sx, z * 2 + sz, 0))
						h1 = h1 or atteint.has(Vector3i(x * 2 + sx, z * 2 + sz, 1))
				ligne += (",") if (h1 and not h0) else ("." if h0 and not h1 else ("#" if h0 and h1 else " "))
				if bas and not h1:
					ligne = ligne.substr(0, ligne.length() - 1) + " "
			print("%4d %s" % [z, ligne])
	var proche := func(p: Vector3, rayon_h: float, dy_max: float) -> bool:
		var kx := int(round(p.x / PAS))
		var kz := int(round(p.z / PAS))
		var nr := int(ceil(rayon_h / PAS))
		for ix in range(kx - nr, kx + nr + 1):
			for iz in range(kz - nr, kz + nr + 1):
				for lv in 2:
					var kk := Vector3i(ix, iz, lv)
					if atteint.has(kk) and Vector2(ix * PAS - p.x, iz * PAS - p.z).length() <= rayon_h and absf(float(atteint[kk]) - p.y) <= dy_max:
						return true
		return false
	# chaque salle
	for z in dj.zones:
		var r: Rect2 = z["rect"]
		var ok := false
		var y: float = z["y"]
		for ix in range(int(floor(r.position.x / PAS)), int(ceil(r.end.x / PAS)) + 1):
			for iz in range(int(floor(r.position.y / PAS)), int(ceil(r.end.y / PAS)) + 1):
				for lv in 2:
					var kk := Vector3i(ix, iz, lv)
					if atteint.has(kk) and r.has_point(Vector2(ix * PAS, iz * PAS)) and absf(float(atteint[kk]) - y) < 1.0 + (5.0 if "u1" == z["nom"] or "d1" == z["nom"] else 0.0):
						ok = true
		_verif(ok, "salle « %s » atteignable" % z["nom"])
	# coffres, interactions, mécanismes (cibles du kit)
	var manquants := 0
	var total := 0
	for id in dj.modules:
		for cb: Dictionary in dj.modules[id]["cibles"]:
			total += 1
			var p: Vector3 = cb["pos"]
			var py: float = p.y if p.y < -3.0 else 0.0
			if not proche.call(Vector3(p.x, py, p.z), 2.1, 2.0):
				manquants += 1
				print("      cible inatteignable : %s (%s) en %s" % [cb["id"], id, p])
	_verif(manquants == 0, "chaque coffre, interaction et mécanisme atteignable (%d cibles)" % total)
	for objectif in [["sarcophage de Svanhild", Vector3(0, 0.6, -69.5)], ["tombeau (offrandes)", Vector3(21.5, 0, -72)], ["trône du Jarl", Vector3(54, 0, -30)], ["socle du rituel", Vector3(0, 0, -50)], ["porte de l'arène", Vector3(0, 0, -55)]]:
		_verif(proche.call(objectif[1], 1.6, 1.5), "objectif atteignable : %s" % objectif[0])
	# ennemis : jamais dans un mur, et atteignables par le joueur
	var murs := 0
	var inacc := 0
	for g in dj.gardiens:
		var p: Vector3 = g["pos"]
		var qp := PhysicsShapeQueryParameters3D.new()
		var cs := CapsuleShape3D.new()
		cs.radius = 0.3
		cs.height = 1.6
		qp.shape = cs
		qp.collision_mask = 1
		qp.transform = Transform3D(Basis(), c.to_global(Vector3(p.x, p.y + 0.1 + 0.8, p.z)))
		qp.exclude = vivants
		if not ss.intersect_shape(qp, 1).is_empty():
			murs += 1
			print("      ennemi dans un mur : %s en %s" % [g["ident"], p])
		var pe := Vector3(p.x, p.y if p.y > -3.0 and p.y < 0.6 else (p.y if p.y < -3.0 else 0.0), p.z)
		if not proche.call(pe, 1.6, 1.3):
			inacc += 1
			print("      ennemi inatteignable : %s en %s" % [g["ident"], p])
	_verif(murs == 0, "aucun ennemi dans un mur (%d ennemis)" % dj.gardiens.size())
	_verif(inacc == 0, "chaque ennemi est atteignable par le joueur")
	var idents := {}
	var doublons := 0
	for g in dj.gardiens:
		if idents.has(g["ident"]):
			doublons += 1
		idents[g["ident"]] = true
	_verif(doublons == 0, "identifiants de gardiens uniques et fixes")
	var patrouilles := 0
	var archers := 0
	var reveils := 0
	for g in dj.gardiens:
		var ex: Dictionary = g["extra"]
		patrouilles += 1 if ex.has("patrouille") else 0
		archers += 1 if g["type"] == "squelette_archer" else 0
		reveils += 1 if ex.has("reveil_evt") else 0
	print("ennemis : %d (dont %d archers, %d patrouilles, %d réveils sur événement)" % [dj.gardiens.size(), archers, patrouilles, reveils])
	# --- bornes du monde
	var hors := 0
	for corps_ in [t.corps, t._cont.get_child(0)]:
		for s2 in corps_.get_children():
			if s2 is CollisionShape3D:
				var gp: Vector3 = (s2 as CollisionShape3D).global_position
				if absf(gp.x) > 107.0 or absf(gp.z) > 107.0:
					hors += 1
					print("      hors bornes : ", gp)
	_verif(hors == 0, "toutes les collisions de la crypte dans les bornes (%d dehors)" % hors)
	# --- lumières : au plus 8 sur un même maillage ; 4 à 6 par salle
	var lum: Array = []
	for decor in [t.d, t.d2]:
		lum.append_array(decor.toutes)
	var par_zone := {}
	for z in dj.zones:
		var r: Rect2 = z["rect"]
		var yz: float = z["y"]
		var nb := 0
		for l: OmniLight3D in t.d2.toutes:
			var lp: Vector3 = c.to_local(l.global_position)
			if r.grow(0.4).has_point(Vector2(lp.x, lp.z)) and absf(lp.y - yz) < 5.5 and not (z["nom"] in ["u1", "d1"]):
				nb += 1
		par_zone[z["nom"]] = nb
	var trop := []
	for nom in par_zone:
		if par_zone[nom] > 7:
			trop.append("%s=%d" % [nom, par_zone[nom]])
	print("lumières par salle : ", par_zone)
	_verif(trop.is_empty(), "au plus 7 lumières par salle %s" % str(trop))
	var maillages := c.find_children("Decor_*", "MeshInstance3D", true, false)
	var pire := 0
	var pire_nom := ""
	var joueur_pos: Vector3 = m.joueur.global_position
	var centres: Array = [["entrée", Vector3(0, 0, -1)], ["alcôve", Vector3(-9, 0, -25)], ["herse", Vector3(0, 0, -37)]]
	for z in dj.zones:
		var r: Rect2 = z["rect"]
		centres.append([z["nom"], Vector3(r.get_center().x, z["y"], r.get_center().y)])
	for cz in centres:
		m.joueur.global_position = c.to_global(cz[1] + Vector3(0, 0.1, 0))
		t._gerer_zones()
		for mi in maillages:
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if bb.get_center().distance_to(m.joueur.global_position) > 70.0:
				continue
			var nb := 0
			for l: OmniLight3D in lum:
				if not l.visible:
					continue
				var pt := l.global_position
				var pr := Vector3(clampf(pt.x, bb.position.x, bb.end.x), clampf(pt.y, bb.position.y, bb.end.y), clampf(pt.z, bb.position.z, bb.end.z))
				if pr.distance_to(pt) <= l.omni_range:
					nb += 1
			if nb > pire:
				pire = nb
				pire_nom = "%s (%s)" % [mi.name, cz[0]]
	m.joueur.global_position = joueur_pos
	print("lumières : %d au total, au plus %d sur un même maillage (%s)" % [lum.size(), pire, pire_nom])
	_verif(pire <= 8, "pas plus de 8 lumières allumées sur un maillage")
	await physics_frame
	# --- une capsule physique descend puis remonte les escaliers (rampe de collision sous les marches)
	for esc in [["descente ossuaire → archives", Vector3(-16, 0.1, -26.6), Vector3(0, 0, -1), -6.0, -38.0], ["montée archives → ossuaire", Vector3(-16, -5.9, -37.4), Vector3(0, 0, 1), 0.0, -28.0],
			["descente glaces → garde", Vector3(21, 0.1, -34.6), Vector3(0, 0, -1), -6.0, -46.0], ["montée garde → glaces", Vector3(21, -5.9, -45.4), Vector3(0, 0, 1), 0.0, -36.0]]:
		var cb := CharacterBody3D.new()
		var cp := CollisionShape3D.new()
		var cs2 := CapsuleShape3D.new()
		cs2.radius = 0.35
		cs2.height = 1.8
		cp.shape = cs2
		cp.position.y = 0.9
		cb.add_child(cp)
		cb.floor_snap_length = 0.4
		root.add_child(cb)
		cb.global_position = c.to_global(esc[1])
		var dir: Vector3 = esc[2]
		for i in 420:
			cb.velocity.x = 0.0
			cb.velocity.z = dir.z * 3.0
			if not cb.is_on_floor():
				cb.velocity.y -= 13.0 / 60.0
			cb.move_and_slide()
			await physics_frame
		var loc := c.to_local(cb.global_position)
		print("      capsule %s : arrivée en %s" % [esc[0], loc])
		_verif(absf(loc.y - float(esc[3])) < 0.35 and (loc.z < float(esc[4]) if dir.z < 0.0 else loc.z > float(esc[4])), "capsule : escalier « %s » franchi" % esc[0])
		cb.queue_free()
	# --- interactions, gardiens, coffres
	_verif(dj.interactions.size() >= 30 and t._inter.size() == dj.interactions.size(), "interactions du donjon créées (%d)" % dj.interactions.size())
	t._gerer_zones()
	m.joueur.global_position = c.to_global(Vector3(-21, 0.1, -12))
	for i in 40:
		await physics_frame
		await process_frame
		t._gerer_zones()
	_verif(m.draugrs.has("cr_ossuaire_1") and m.draugrs.has("cr_w1_4") == false, "les gardiens de l'ossuaire apparaissent à l'approche (%d draugrs en tout)" % m.draugrs.size())
	var avant: int = m.joueur.inventaire.pieces
	t._ouvrir_coffre("cof_ossuaire", {"pieces": 34}, Vector3(-28.2, 0, -24.7))
	_verif(t.quetes.vus.has("crypte:cof_ossuaire"), "coffre ouvert : signalé (sauvegardé avec les quêtes)")
	m.joueur.global_position = c.to_global(Vector3(-28.2, 0.1, -23.9))
	for i in 5:
		await process_frame
	_verif(m.joueur.inventaire.pieces == avant + 34, "la bourse du coffre est ramassée (+34 pièces)")
	# fragments : prise, marqueur, événement de réveil
	var it_os: Dictionary = {}
	for it in dj.interactions:
		if it["id"] == "fragment_os":
			it_os = it
	var sac_av: int = m.joueur.inventaire.objets.get("fragment_sceau_os", 0)
	t._prendre_fragment(it_os)
	_verif(m.joueur.inventaire.a("fragment_sceau_os") and t.quetes.vus.has("crypte:fragment_os") and t.quetes.vus.has("ramasse:fragment_sceau_os") and sac_av == 0, "fragment des Os : dans le sac, événement « ramasse: » émis (réveil du gardien)")
	# mage nordique de la salle du trône (g4, près du coffre cof_g4b) : EnnemiBase créé par la file des gardiens, debout sur le sol,
	# téléports qui restent dans la salle
	var rg := Rect2()
	for z in dj.zones:
		if z["nom"] == "g4":
			rg = z["rect"]
	t.dedans = true          # le test téléporte le joueur sans passer par l'entrée : la crypte doit se savoir occupée (gel par salle)
	m.joueur.global_position = c.to_global(Vector3(49.0, 0.1, -30.0))
	for i in 40:
		await physics_frame
		await process_frame
		t._gerer_zones()
	var mage = m.draugrs.get("cr_g4_mage")
	_verif(mage != null and is_instance_valid(mage) and mage is EnnemiBase and String(mage.get_script().resource_path).ends_with("mage_nordique_ia.gd"), "mage nordique cr_g4_mage apparu dans la salle du trône (EnnemiBase)")
	if mage != null and is_instance_valid(mage):
		var lm: Vector3 = c.to_local(mage.global_position)
		var r_sol := ss.intersect_ray(PhysicsRayQueryParameters3D.create(mage.global_position + Vector3(0, 1.0, 0), mage.global_position + Vector3(0, -2.0, 0), 1, [mage.get_rid()]))
		var ecart: float = (mage.global_position.y - (r_sol["position"] as Vector3).y) if not r_sol.is_empty() else 99.0
		_verif(rg.has_point(Vector2(lm.x, lm.z)) and absf(ecart) < 0.25, "mage debout sur le sol de g4 (local %s, écart au sol %.2f m, à %.1f m du coffre cof_g4b)" % [lm, ecart, Vector2(lm.x - 57.9, lm.z + 23.2).length()])
		_verif(not mage.est_gele() and t.salles.salle_de(lm) == "g4", "mage actif (pas gelé) avec le joueur dans g4 (salle %s, état %d)" % [t.salles.salle_de(lm), mage.etat])
		var hors_salle := 0
		var essais := 0
		for pj in [Vector3(45.0, 0.1, -30.0), Vector3(51.0, 0.1, -36.0), Vector3(51.0, 0.1, -24.0), Vector3(56.0, 0.1, -30.0), Vector3(44.5, 0.1, -37.0)]:
			m.joueur.global_position = c.to_global(pj)
			await physics_frame
			for k in 6:
				var tp: Vector3 = mage.point_teleport()
				if tp == Vector3.INF:
					continue
				essais += 1
				var lt: Vector3 = c.to_local(tp)
				if not rg.grow(-0.2).has_point(Vector2(lt.x, lt.z)):
					hors_salle += 1
					print("      téléport hors de g4 : %s (joueur en %s)" % [lt, pj])
		_verif(hors_salle == 0, "téléports du mage : %d points d'arrivée calculés, tous dans la salle g4" % essais)
		m.joueur.global_position = c.to_global(Vector3(-21, 0.1, -12))
		await physics_frame
		t.salles.rafraichir(true)
		_verif(mage.est_gele(), "mage gelé quand le joueur est loin (ossuaire)")
		t.reinitialiser(["cr_g4_mage"])
		m.joueur.global_position = c.to_global(Vector3(49.0, 0.1, -30.0))
		for i in 30:
			await physics_frame
			t._gerer_zones()
		_verif(not m.draugrs.has("cr_g4_mage"), "mage tué dans la sauvegarde (draugrs_morts) : ne revient pas")
	var n := 0
	for s in m.tertre.corps.get_children():
		if s is CollisionShape3D:
			n += 1
	print("collisions du corps de la crypte : ", n)
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)
