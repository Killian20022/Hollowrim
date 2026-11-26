extends SceneTree
## Test headless du compagnon d'Eirik mort (crypte du tertre, salle barricadée, interaction note_compagnon_2) :
##  - corps en armure MAISON (GardeMaison, ensemble fer, sans livrée ni arme), pas l'ancien Guerrier ;
##  - ALLONGÉ (pose Death01 figée) : tête et bassin près du sol, corps étalé à l'horizontale, bras pas en croix ;
##  - aucune pièce visible SANS matière (le « blanc » de la cotte de mailles : ArmureVisible remettait material_override à null) ;
##  - posé sur le sol (aucun os sous le sol ni à plus de 0,6 m), interaction « Fouiller le corps » à portée du torse ;
##  - sang séché sous le corps (la torche éteinte est fondue dans le décor : vérifiée en image). Texte de la fouille : test_quetes.
## godot --headless --path . --script res://outils/test_compagnon_mort.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	CrypteDecor.journal_actif = true      # bornes de chaque objet du décor fusionné (objets voisins posés au sol)
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
	m.tertre.attendre_donjon()
	for i in 10:
		await process_frame
	var c0 := m.tertre.crypte.find_child("CorpsCompagnon", true, false) as Node3D
	var rd0: Ragdoll = c0.get_node_or_null("Ragdoll") if c0 else null
	if rd0 != null:      # le corps finit sa chute en ragdoll puis est figé
		var t0 := Time.get_ticks_msec()
		for i in 600:
			await physics_frame
			if rd0.est_fige():
				break
		print("      ragdoll figé : %s après %d images de physique" % [rd0.est_fige(), Engine.get_physics_frames()])
	var crypte: Node3D = m.tertre.crypte
	var c := crypte.find_child("CorpsCompagnon", true, false) as Node3D
	_verif(c != null, "corps du compagnon présent dans la crypte")
	if c == null:
		quit(1)
		return
	_verif(c.has_meta("garde_maison") and not c.has_meta("livree_garde"), "corps en armure maison (GardeMaison), sans livrée")
	var portees: Dictionary = c.get_meta(GardeMaison.META, {})
	_verif(String(portees.get("torse", "")) == "cuirasse_fer", "cuirasse de fer portée (%s)" % [portees])
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	sq.force_update_all_bone_transforms()
	var rd: Ragdoll = c.get_node_or_null("Ragdoll")
	_verif(rd == null or rd.est_fige(), "corps figé après sa chute (ragdoll endormi)")
	var sol_y := c.global_position.y
	var gp := func(nom: String) -> Vector3:
		if rd != null and rd.pose_monde(nom) != null:
			return (rd.pose_monde(nom) as Transform3D).origin      # os physique figé : pose affichée
		return sq.global_transform * sq.get_bone_global_pose(sq.find_bone(nom)).origin
	var tete: Vector3 = gp.call("Head")
	var bassin: Vector3 = gp.call("pelvis")
	var pied: Vector3 = (gp.call("foot_l") + gp.call("foot_r")) * 0.5
	var main_l: Vector3 = gp.call("hand_l")
	var main_r: Vector3 = gp.call("hand_r")
	print("      tête %.2f m, bassin %.2f m au-dessus du sol ; tête-pieds à l'horizontale %.2f m ; mains %.2f / %.2f m ; écart des mains %.2f m"
		% [tete.y - sol_y, bassin.y - sol_y, Vector2(tete.x - pied.x, tete.z - pied.z).length(), main_l.y - sol_y, main_r.y - sol_y, main_l.distance_to(main_r)])
	print("      repère du corps : main_l %s main_r %s tête %s bassin %s" % [c.to_local(main_l), c.to_local(main_r), c.to_local(tete), c.to_local(bassin)])
	_verif(tete.y - sol_y < 0.45, "tête au sol (< 0,45 m) : allongé, pas debout")
	_verif(bassin.y - sol_y < 0.40, "bassin au sol (< 0,40 m)")
	_verif(Vector2(tete.x - pied.x, tete.z - pied.z).length() > 1.0, "corps étalé à l'horizontale (tête-pieds > 1 m)")
	_verif(main_l.distance_to(main_r) < 1.55, "bras pas en croix (écart des mains < 1,55 m, pose de repos : ~1,7 m)")
	var bas := INF
	var haut := -INF
	var plus_haut := ""
	var noms: Array = rd.os.keys() if rd != null else Array(range(sq.get_bone_count())).map(func(i: int) -> String: return sq.get_bone_name(i))
	for nom: String in noms:      # ragdoll : les os physiques (les phalanges suivent leur main)
		var y: float = (gp.call(nom) as Vector3).y - sol_y
		if y > haut:
			plus_haut = nom
		bas = minf(bas, y)
		haut = maxf(haut, y)
	_verif(bas > -0.08 and haut < 0.7, "os entre le sol et 0,7 m (%.2f .. %.2f, plus haut : %s)" % [bas, haut, plus_haut])
	var vis: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if _visible_sous(mi, c):
			vis.append(String(mi.name))
	print("      maillages visibles : ", vis)
	var blancs: Array = []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not _visible_sous(mi, c) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if mi.material_override == null and mi.get_surface_override_material(s) == null and mi.mesh.surface_get_material(s) == null:
				blancs.append("%s:%d" % [mi.name, s])
	_verif(blancs.is_empty(), "aucune pièce visible sans matière (blanc) %s" % [blancs])
	var dj: CrypteDonjon = m.tertre.donjon
	var it_pos := Vector3.INF
	for it: Dictionary in dj.interactions:
		if String(it.get("id", "")) == "note_compagnon_2":
			it_pos = it["pos"]
	_verif(it_pos != Vector3.INF, "interaction « Fouiller le corps » (note_compagnon_2) présente")
	var torse_local := crypte.to_local((tete + bassin) * 0.5)
	if it_pos != Vector3.INF:
		var dd := Vector2(it_pos.x - torse_local.x, it_pos.z - torse_local.z).length()
		_verif(dd < 0.9, "interaction à portée du torse (%.2f m)" % dd)
	var taches := crypte.find_children("SangSeche*", "MeshInstance3D", true, false)
	_verif(taches.size() >= 2, "sang séché sous le corps (%d)" % taches.size())
	if rd != null:
		_contact_sol(c, sq, rd, sol_y - 0.02)
		_verif(crypte.find_child("OmbreContact", true, false) != null, "ombre de contact sous le corps")
		var pk := (sq.get_node_or_null("peau") as MeshInstance3D)
		_verif(pk != null and pk.has_meta("teint_mort"), "teint de mort (peau désaturée)")
		_accessoires(crypte, rd, sol_y - 0.02, main_l, main_r)
	_flotte(crypte)

	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)

## Plaqué au sol : pour chaque os physique, le plus bas des sommets du corps (peau et armure, skinnés) qu'il porte ; à plus de 3 cm
## du sol il doit reposer sur une autre partie du corps (un sommet d'un autre os à moins de 6 cm sous lui), sinon il « flotte ».
func _contact_sol(c: Node3D, sq: Skeleton3D, rd: Ragdoll, sol: float) -> void:
	var monde := {}      # os -> Transform3D monde (os physique : pose du ragdoll ; sinon chaîne de poses locales depuis l'ancêtre physique)
	var region := {}     # os -> os physique qui le porte
	for b in sq.get_bone_count():
		var chaine: Array = []
		var x := b
		while x >= 0 and rd.pose_monde(sq.get_bone_name(x)) == null:
			chaine.push_front(x)
			x = sq.get_bone_parent(x)
		if x < 0:
			continue
		var t: Transform3D = rd.pose_monde(sq.get_bone_name(x))
		for y: int in chaine:
			t = t * sq.get_bone_pose(y)
		monde[b] = t
		region[b] = sq.get_bone_name(x)
	var bas := {}
	var pts: Array = []      # [pos, région]
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not _visible_sous(mi, c) or mi.mesh == null or mi.name == "OmbreFusion":
			continue
		var sk := mi.skin
		for s in mi.mesh.get_surface_count():
			var ar := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var os_v: Variant = ar[Mesh.ARRAY_BONES]
			var po_v: Variant = ar[Mesh.ARRAY_WEIGHTS]
			var k := 8 if os_v is PackedInt32Array and (os_v as PackedInt32Array).size() == vs.size() * 8 else 4
			for i in range(0, vs.size(), 3):
				var p: Vector3
				var reg := ""
				if sk != null and os_v is PackedInt32Array and (os_v as PackedInt32Array).size() >= vs.size() * k:
					var acc := Vector3.ZERO
					var wmax := -1.0
					for j in k:
						var w: float = (po_v as PackedFloat32Array)[i * k + j]
						if w <= 0.0:
							continue
						var bi: int = (os_v as PackedInt32Array)[i * k + j]
						var bone := sk.get_bind_bone(bi)
						if bone < 0:
							bone = sq.find_bone(sk.get_bind_name(bi))
						if not monde.has(bone):
							continue
						acc += ((monde[bone] as Transform3D) * sk.get_bind_pose(bi) * vs[i]) * w
						if w > wmax:
							wmax = w
							reg = region[bone]
					if reg == "":
						continue
					p = acc
				else:
					var at := mi.get_parent()
					while at != null and not (at is BoneAttachment3D):
						at = at.get_parent()
					if at == null or not monde.has((at as BoneAttachment3D).bone_idx):
						continue
					var ba := at as BoneAttachment3D
					p = (monde[ba.bone_idx] as Transform3D) * (ba.global_transform.affine_inverse() * mi.global_transform) * vs[i]
					reg = region[ba.bone_idx]
				pts.append([p, reg])
				if not bas.has(reg) or p.y < (bas[reg] as Vector3).y:
					bas[reg] = p
	var flottants: Array = []
	var resume: Array = []
	for reg: String in bas:
		var p: Vector3 = bas[reg]
		var ecart := p.y - sol
		resume.append("%s %.0f" % [reg, ecart * 100.0])
		if ecart <= 0.03:
			continue
		var porte := false
		for q: Array in pts:
			if q[1] != reg and (q[0] as Vector3).y < p.y and (q[0] as Vector3).distance_to(p) < 0.06:
				porte = true
				break
		if not porte:
			flottants.append("%s %.1f cm" % [reg, ecart * 100.0])
	print("      plus bas sommet par os, cm au-dessus du sol : ", ", ".join(resume))
	_verif(flottants.is_empty(), "corps plaqué au sol : aucun os à plus de 3 cm sans appui %s" % [flottants])

## Bouclier posé à côté, épée tombée à 0,5-1 m d'une main, torche éteinte : au sol, hors du corps.
func _accessoires(crypte: Node3D, rd: Ragdoll, sol: float, main_l: Vector3, main_r: Vector3) -> void:
	for nom: String in ["EpeeCompagnon", "BouclierCompagnon", "TorcheCompagnon"]:
		var n := crypte.find_child(nom, true, false) as Node3D
		_verif(n != null, "%s présent" % nom)
		if n == null:
			continue
		var bb := _aabb(n)
		_verif(absf(bb.position.y - sol) < 0.02, "%s au sol (bas à %.1f cm)" % [nom, (bb.position.y - sol) * 100.0])
		var ctr := bb.get_center()
		var dmin := INF
		var plus_pres := ""
		for os_n: String in rd.os.keys():
			var dd := Vector2(ctr.x, ctr.z).distance_to(Vector2((rd.pose_monde(os_n) as Transform3D).origin.x, (rd.pose_monde(os_n) as Transform3D).origin.z))
			if dd < dmin:
				dmin = dd
				plus_pres = os_n
		_verif(dmin > 0.22, "%s hors du corps (centre à %.2f m de %s)" % [nom, dmin, plus_pres])
		if nom == "EpeeCompagnon":
			var dm := minf(Vector2(ctr.x, ctr.z).distance_to(Vector2(main_l.x, main_l.z)), Vector2(ctr.x, ctr.z).distance_to(Vector2(main_r.x, main_r.z)))
			_verif(dm >= 0.4 and dm <= 1.1, "épée tombée près d'une main (%.2f m du centre de l'épée)" % dm)

func _aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var premier := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var b := mi.global_transform * mi.get_aabb()
		bb = b if premier else bb.merge(b)
		premier = false
	return bb

## Aucun objet du journal autour du corps (os, crânes, sacs...) ne flotte : rayon vers le bas sous le centre de chaque objet posé au sol.
const POSES_AU_SOL := ["os_tas", "crane", "sac_dechire", "arme", "tonneau", "table", "coffre", "etagere_renversee", "barricade"]
func _flotte(crypte: Node3D) -> void:
	var centre := Vector3(-16.0, -6.0, -53.0)
	var vus := 0
	var hauts: Array = []
	for dec: CrypteDecor in [m.tertre.d, m.tertre.d2]:
		for e: Dictionary in dec.journal:
			var t: String = e["t"]
			var garde := t.begins_with("pq:")
			for x: String in POSES_AU_SOL:
				garde = garde or t == x
			if not garde or e.get("partie", false):
				continue
			var a: float = e["lacet"]
			var mn := Basis(Vector3.UP, a) * (e["min"] as Vector3)
			var mx := Basis(Vector3.UP, a) * (e["max"] as Vector3)
			var ce := (mn + mx) * 0.5
			if Vector2(ce.x - centre.x, ce.z - centre.z).length() > 2.5 or absf(ce.y - centre.y) > 1.5:
				continue
			vus += 1
			var bas := minf(mn.y, mx.y) - centre.y
			if absf(bas) > 0.03:
				hauts.append("%s (%.2f, %.2f) %.1f cm" % [t, ce.x, ce.z, bas * 100.0])
	for rb: RigidBody3D in crypte.find_children("Cass_*", "RigidBody3D", true, false):
		var p := crypte.to_local(rb.global_position)
		if Vector2(p.x - centre.x, p.z - centre.z).length() > 2.5 or absf(p.y - centre.y) > 1.5:
			continue
		vus += 1
		if absf(p.y - centre.y) > 0.03:
			hauts.append("%s %.1f cm" % [rb.name, (p.y - centre.y) * 100.0])
	_verif(vus >= 5 and hauts.is_empty(), "objets voisins posés au sol (%d objets à 2,5 m) %s" % [vus, hauts])

## Visible dans le corps (la crypte est cachée tant que le joueur est dehors : is_visible_in_tree serait faux partout).
func _visible_sous(n: Node, haut: Node) -> bool:
	var x: Node = n
	while x != null and x != haut:
		if x is Node3D and not (x as Node3D).visible:
			return false
		x = x.get_parent()
	return true
