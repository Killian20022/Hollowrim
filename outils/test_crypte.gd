extends SceneTree
## Test headless de la crypte (lot 7a) : le décor ne doit pas gêner le parcours. Rayons horizontaux à 0,5 m et 1,4 m
## le long du chemin du joueur (entrée → couloir → salle → alcôve / levier → herse), sol sous chaque point, et
## inventaire des collisions du décor. godot --headless --path . --script outils/test_crypte.gd
const SCENE := preload("res://scenes/foret_test.tscn")

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
	# les êtres vivants (draugrs, PNJ, joueur) se déplacent selon la sauvegarde : seul le décor est testé
	var vivants: Array[RID] = []
	for n in m.find_children("*", "CharacterBody3D", true, false):
		vivants.append((n as CharacterBody3D).get_rid())
	# le donjon (bâti dans un fil d'exécution) doit être intégré
	var t0 := Time.get_ticks_msec()
	m.tertre.attendre_donjon()
	print("attente du donjon : %d ms" % (Time.get_ticks_msec() - t0))
	for i in 5:
		await physics_frame
	var t = m.tertre
	_verif(t.donjon != null and t._tache < 0, "donjon intégré")
	var chemin := [
		Vector3(0, 0, 0.5), Vector3(0, 0, -4), Vector3(0, 0, -12), Vector3(0, 0, -19), Vector3(0, 0, -25),
		Vector3(5.5, 0, -25), Vector3(0, 0, -25), Vector3(-6.5, 0, -25), Vector3(-9.0, 0, -24.0), Vector3(-7.5, 0, -25),
		Vector3(0, 0, -25), Vector3(0, 0, -31.5), Vector3(0, 0, -32.5),
		Vector3(0, 0, -42.5), Vector3(0, 0, -47.5),
	]
	for i in chemin.size() - 1:
		for h in [0.5, 1.4]:
			var a: Vector3 = c.to_global(chemin[i] + Vector3(0, h, 0))
			var b: Vector3 = c.to_global(chemin[i + 1] + Vector3(0, h, 0))
			var q := PhysicsRayQueryParameters3D.create(a, b)
			q.exclude = vivants
			var r := ss.intersect_ray(q)
			if i == 12 and not m.tertre._herse_ouverte:     # segment qui traverse la herse baissée : doit être bloqué
				_verif(not r.is_empty(), "segment %d→%d à %.1f m arrêté par la herse baissée" % [i, i + 1, h])
				continue
			_verif(r.is_empty(), "segment %d→%d à %.1f m dégagé%s" % [i, i + 1, h, "" if r.is_empty() else " (touche %s en %s)" % [(r["collider"] as Node).name, r["position"]]])
	for p: Vector3 in chemin:
		var o: Vector3 = c.to_global(p + Vector3(0, 1.0, 0))
		var qs := PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -2.0, 0))
		qs.exclude = vivants
		var r := ss.intersect_ray(qs)
		_verif(not r.is_empty() and absf(r["position"].y - c.global_position.y) < 0.05, "sol à y=0 sous %s" % [p])
	# --- le donjon : portes barrées bloquantes, puis ouvertes
	for id in ["s1", "s2", "s3"]:
		var pp: Node3D = t.donjon.portes[id]
		var y0 := 1.2
		var o := c.to_global(pp.position + Vector3(-1.2, y0, 0))
		var o2 := c.to_global(pp.position + Vector3(1.2, y0, 0))
		var rr := ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o2))
		_verif(not rr.is_empty(), "porte %s fermée : un rayon à travers est arrêté" % id)
	var sp: Node3D = t.donjon.portes["secret"]
	var rs := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c.to_global(Vector3(-46.5, 1.2, -59.0)), c.to_global(Vector3(-50.0, 1.2, -59.0))))
	_verif(not rs.is_empty(), "mur secret fermé : bloquant")
	for id in ["s1", "s2", "s3", "secret"]:
		t.quetes.vus["crypte:" + id] = true
	t._etat_donjon()
	t.herse.position.y = 2.9
	for i in 3:
		await physics_frame
	var etage := func(z: float, z0: float, z1: float, y1: float) -> float:
		return y1 * (z - z0) / (z1 - z0)
	var B := -6.0
	var parcours := {
		"boucle ossuaire (niches, S1, ossuaire, W1, salle)": [Vector3(0, 0, -4), Vector3(0, 0, -9), Vector3(-6, 0, -9), Vector3(-26, 0, -9), Vector3(-26, 0, -19.8), Vector3(-8, 0, -19.8), Vector3(0, 0, -19.8), Vector3(0, 0, -25)],
		"ossuaire - reliquaires": [Vector3(-26, 0, -19.8), Vector3(-26, 0, -25), Vector3(-38, 0, -25), Vector3(-38, 0, -33), Vector3(-38, 0, -48), Vector3(-38, 0, -52), Vector3(-38, 0, -58)],
		"reliquaires - salle secrète": [Vector3(-38, 0, -58), Vector3(-40, 0, -59), Vector3(-47, 0, -59), Vector3(-54, 0, -59)],
		"reliquaires - S3 - arène": [Vector3(-38, 0, -58), Vector3(-38, 0, -66), Vector3(-23, 0, -66), Vector3(-14, 0, -66), Vector3(-10, 0, -66), Vector3(-6, 0, -66), Vector3(-6, 0, -62), Vector3(0, 0, -60)],
		"salle - herse - antichambre - arène": [Vector3(0, 0, -25), Vector3(0, 0, -31.5), Vector3(0, 0, -42.5), Vector3(-2, 0, -47), Vector3(-2, 0, -53), Vector3(0, 0, -57), Vector3(0, 0, -62), Vector3(0, 0, -66)],
		"salle - aile est - galerie sud - S2 - entrée": [Vector3(0, 0, -25), Vector3(0, 0, -30), Vector3(5.5, 0, -29.7), Vector3(24, 0, -29.7), Vector3(34, 0, -29.7), Vector3(34, 0, -19), Vector3(34, 0, -2), Vector3(5, 0, -2), Vector3(0, 0, -2)],
		"boucle est (G1, G3, G4, G5, G6, G2)": [Vector3(34, 0, -29.7), Vector3(46, 0, -30), Vector3(60, 0, -30), Vector3(70, 0, -30), Vector3(70, 0, -21), Vector3(70, 0, -9.6), Vector3(36, 0, -9.6), Vector3(34, 0, -9.6)],
		"escalier descendant (G1 - LB1)": [Vector3(34, 0, -30), Vector3(34, 0, -38), Vector3(34, 0, -40.5), Vector3(34, etage.call(-45.0, -40.0, -52.0, B), -45.0), Vector3(34, etage.call(-50.0, -40.0, -52.0, B), -50.0), Vector3(34, B, -52.5), Vector3(34, B, -56)],
		"étage inférieur (LB1 - LB2 - LB3)": [Vector3(34, B, -56), Vector3(34, B, -66), Vector3(26, B, -66), Vector3(-19, B, -66), Vector3(-24, B, -66), Vector3(-29.2, B, -62), Vector3(-29.2, B, -48)],
		"chambre latérale (LB2a)": [Vector3(4, B, -66), Vector3(4, B, -70), Vector3(4, B, -72)],
		"escalier montant (LB3 - ossuaire)": [Vector3(-29.2, B, -48), Vector3(-29.2, B, -46.5), Vector3(-29.2, etage.call(-40.0, -34.0, -46.0, B), -40.0), Vector3(-29.2, 0, -34.5), Vector3(-29.2, 0, -32)],
	}
	for nom in parcours:
		var pts: Array = parcours[nom]
		var bons := 0
		var tot := 0
		for i in pts.size() - 1:
			for h in [0.5, 1.4]:
				var a: Vector3 = c.to_global(pts[i] + Vector3(0, h, 0))
				var b: Vector3 = c.to_global(pts[i + 1] + Vector3(0, h, 0))
				var q := PhysicsRayQueryParameters3D.create(a, b)
				q.exclude = vivants
				var r := ss.intersect_ray(q)
				tot += 1
				if r.is_empty():
					bons += 1
				else:
					print("      %s : %s → %s touche %s en %s" % [nom, pts[i], pts[i + 1], (r["collider"] as Node).name, c.to_local(r["position"])])
		_verif(bons == tot, "parcours « %s » : %d/%d segments dégagés" % [nom, bons, tot])
		var sols := 0
		for p: Vector3 in pts:
			var o: Vector3 = c.to_global(p + Vector3(0, 1.0, 0))
			var qs := PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -2.5, 0))
			qs.exclude = vivants
			var r := ss.intersect_ray(qs)
			if not r.is_empty() and absf(r["position"].y - (c.global_position.y + p.y)) < 0.4:
				sols += 1
			else:
				print("      sol manquant sous %s (%s)" % [p, "rien" if r.is_empty() else str(c.to_local(r["position"]))])
		_verif(sols == pts.size(), "parcours « %s » : sol sous les %d points" % [nom, pts.size()])
	t.herse.position.y = 0.0
	# bornes du monde : toute collision de la crypte dans les ±108 m du joueur
	var hors := 0
	for corps_ in [t.corps, t._cont.get_child(0)]:
		for s2 in corps_.get_children():
			if s2 is CollisionShape3D:
				var gp: Vector3 = (s2 as CollisionShape3D).global_position
				if absf(gp.x) > 107.0 or absf(gp.z) > 107.0:
					hors += 1
					print("      hors bornes : ", gp, " forme ", (s2 as CollisionShape3D).shape)
	_verif(hors == 0, "toutes les collisions de la crypte dans les bornes (%d dehors)" % hors)
	# lumières : au plus 8 allumées sur un même maillage (limite du renderer mobile), joueur placé au centre de chaque zone
	var lum: Array = []
	for decor in [t.d, t.d2]:
		lum.append_array(decor.toutes)
	var maillages := c.find_children("Decor_*", "MeshInstance3D", true, false)
	var centres: Array = [["entrée", Vector3(0, 0, -1)], ["niches", Vector3(0, 0, -12)], ["salle des piliers", Vector3(0, 0, -25)], ["alcôve", Vector3(-9, 0, -25)], ["herse", Vector3(0, 0, -37)], ["antichambre", Vector3(0, 0, -50)]]
	for z in t.donjon.zones:
		var r: Rect2 = z["rect"]
		centres.append([z["nom"], Vector3(r.get_center().x, z["y"], r.get_center().y)])
	var pire := 0
	var pire_nom := ""
	var allumees_max := 0
	var joueur_pos: Vector3 = m.joueur.global_position
	for cz in centres:
		m.joueur.global_position = c.to_global(cz[1] + Vector3(0, 0.1, 0))
		t._gerer_zones()
		var vis := 0
		for l: OmniLight3D in lum:
			if l.visible:
				vis += 1
		allumees_max = maxi(allumees_max, vis)
		var pire_zone := 0
		for mi in maillages:
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if bb.get_center().distance_to(m.joueur.global_position) > 70.0:
				continue
			var nb := 0
			for l: OmniLight3D in lum:
				if not l.visible:
					continue
				var pt := l.global_position
				var proche := Vector3(clampf(pt.x, bb.position.x, bb.end.x), clampf(pt.y, bb.position.y, bb.end.y), clampf(pt.z, bb.position.z, bb.end.z))
				if proche.distance_to(pt) <= l.omni_range:
					nb += 1
			pire_zone = maxi(pire_zone, nb)
			if nb > pire:
				pire = nb
				pire_nom = "%s (%s)" % [mi.name, cz[0]]
		if pire_zone > 8:
			print("      zone « %s » : jusqu'à %d lumières sur un maillage" % [cz[0], pire_zone])
	m.joueur.global_position = joueur_pos
	print("lumières : %d au total, %d allumées au plus, au plus %d sur un même maillage (%s)" % [lum.size(), allumees_max, pire, pire_nom])
	_verif(pire <= 8, "pas plus de 8 lumières allumées sur un maillage")
	await physics_frame
	await physics_frame
	# une capsule descend puis remonte les deux escaliers (rampe de collision sous les marches)
	for esc in [["descente G1 → LB1", Vector3(34, 0.1, -40.6), Vector3(0, 0, -1), -6.0, -52.0], ["montée LB3 → ossuaire", Vector3(-29.2, -5.9, -46.6), Vector3(0, 0, 1), 0.0, -36.0]]:
		var cb := CharacterBody3D.new()
		var cap := CollisionShape3D.new()
		var cs := CapsuleShape3D.new()
		cs.radius = 0.35
		cs.height = 1.8
		cap.shape = cs
		cap.position.y = 0.9
		cb.add_child(cap)
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
	# interactions et gardiens du donjon
	_verif(t.donjon.interactions.size() >= 20 and t._inter.size() == t.donjon.interactions.size(), "interactions du donjon créées (%d)" % t.donjon.interactions.size())
	m.joueur.global_position = c.to_global(Vector3(-35, 0.1, -20))
	for i in 40:
		await physics_frame
		await process_frame
	_verif(m.draugrs.has("cr_ossuaire_1") and m.draugrs.has("cr_w1_4") == false, "les gardiens de l'ossuaire apparaissent à l'approche (%d draugrs en tout)" % m.draugrs.size())
	var avant: int = m.joueur.inventaire.pieces
	t._ouvrir_coffre("cof_ossuaire", {"pieces": 34}, Vector3(-25.2, 0, -30.8))
	_verif(t.quetes.vus.has("crypte:cof_ossuaire"), "coffre ouvert : signalé (sauvegardé avec les quêtes)")
	m.joueur.global_position = c.to_global(Vector3(-25.2, 0.1, -30.0))
	for i in 5:
		await process_frame
	_verif(m.joueur.inventaire.pieces == avant + 34, "la bourse du coffre est ramassée (+34 pièces)")
	var n := 0
	for s in m.tertre.corps.get_children():
		if s is CollisionShape3D:
			n += 1
	print("collisions du corps de la crypte : ", n)
	# la herse bloque bien le passage tant que le levier n'est pas tiré
	# (une partie sauvegardée peut l'avoir levée : on ne vérifie que si elle est baissée ; lancer avec -- --nouvelle sinon)
	if not m.tertre._herse_ouverte:
		var hs := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c.to_global(Vector3(0, 1.0, -31.0)), c.to_global(Vector3(0, 1.0, -35.0))))
		_verif(not hs.is_empty(), "la herse arrête un rayon de la salle vers le tombeau")
	else:
		print("herse levée par la sauvegarde : contrôle sauté")
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)
