extends SceneTree
## Test sans fenêtre du SOCLE « impact des sorts sur les corps » (scripts/magie/impact_corps.gd, surface_corps.gd,
## feu_corps.gd ; docs/MAGIE_IMPACT_CORPS.md) :
##   - les points d'émission sont SUR le corps et SUIVENT SES OS (déplacement, rotation, os animé, ragdoll, décapitation) ;
##   - aucun nœud, matériau ni texture créé par impact (pool préchauffé ; compteurs du moteur et du module) ;
##   - voile partagé (un seul matériau, paramètres d'instance), retiré à la fin ;
##   - plafond de particules (MAX_PARTICULES_FIN) respecté avec 3 draugrs + double jet, 5 cibles pour 4 foyers ;
##   - brûlure après l'arrêt du jet, puis extinction complète ; rendu d'avant si ImpactCorps.actif = faux.
##   godot --headless --path . --script res://outils/test_impact_corps.gd -- --nouvelle
var echecs := 0
var monde: Node3D
var _poses := {}   # os -> pose globale APRÈS les modificateurs (comme SurfaceCorps), lue au signal skeleton_updated

func _noter_poses(sq: Skeleton3D) -> void:
	for b in sq.get_bone_count():
		_poses[b] = sq.get_bone_global_pose(b)

func _pose(sq: Skeleton3D, b: int) -> Transform3D:
	return sq.global_transform * (_poses[b] as Transform3D if _poses.has(b) else sq.get_bone_global_pose(b))

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _draugr(pos: Vector3) -> Node3D:
	var d: Node3D = DraugrNordique.creer({})
	monde.add_child(d)
	d.position = pos
	d.add_to_group("cibles_magie")
	return d

## Jet factice (même dictionnaire que GestionMagie._jet_creer) : appelle le point d'accroche sans le reste du jet.
func _faux_jet(gm: GestionMagie, origine: Node3D, cible: Node3D, dbl := false) -> Dictionary:
	return {"ecole": "feu", "origine": origine, "portee": 5.5, "largeur": 0.9, "dbl": dbl, "emit": [], "gerbe": [],
		"gerbe_cible": null, "cible": cible, "fin_pos": cible.global_position + Vector3.UP * 1.1, "t_bout": 0.0, "horloge": gm.horloge}

## Jet factice d'une autre école (arc électrique, drain) ; `eclair` : générateur d'origine factice (le socle le remplace).
func _faux_jet_ecole(gm: GestionMagie, ecole: String, origine: Node3D, cible: Node3D) -> Dictionary:
	var j := _faux_jet(gm, origine, cible)
	j.ecole = ecole
	j["eclair"] = {"gen": func() -> Array: return [[PackedVector3Array([Vector3.ZERO, Vector3.ONE]), 1.0, 1.0]]}
	return j

func _canaux(c: Node3D) -> Vector4:
	var m := Vector4.ZERO
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay != null:
			var v: Variant = (mi as MeshInstance3D).get_instance_shader_parameter("mc_ecoles")
			if v is Vector4:
				m = Vector4(maxf(m.x, v.x), maxf(m.y, v.y), maxf(m.z, v.z), maxf(m.w, v.w))
	return m

func _ecoles_b(gm: GestionMagie, ic: ImpactCorps, main: Node3D, corps: Array, crees0: int) -> void:
	EffetsMagie.tout_arreter()
	await _images(3)
	var noeuds0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var res0 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var da: Node3D = corps[0]
	var db: Node3D = corps[1]
	var dc: Node3D = corps[2]
	# arc électrique sur da, drain sur db (jets factices : le point d'accroche jet_gerbe), givre et choc par statut sur dc
	var je := _faux_jet_ecole(gm, "electricite", main, da)
	var jd := _faux_jet_ecole(gm, "tenebres", main, db)
	var max_budget := 0
	var fin_sur := true
	for k in 50:
		for jj: Dictionary in [je, jd]:
			jj.fin_pos = (jj.cible as Node3D).global_position + Vector3.UP * 1.1
			ImpactCorps.jet_gerbe(gm, jj)
		if k % 10 == 0:
			ImpactCorps.statut(gm, da, "choc", 0.5)
			ImpactCorps.statut(gm, db, "corruption", 3.0)
			ImpactCorps.statut(gm, dc, "gel", 3.0)
			ImpactCorps.statut(gm, dc, "choc", 0.5)
		await process_frame
		max_budget = maxi(max_budget, gm._budget)
		# le faisceau / le drain finissent SUR la surface du corps (pas en son centre)
		var fe: ImpactCorps.Foyer = ic.trouver(da, "electricite")
		if fe != null and int(fe.d.imp_i) >= 0 and k > 3:
			var sp: Vector3 = da.global_position + fe.surface.pos[int(fe.d.imp_i)]
			fin_sur = fin_sur and (je.fin_pos as Vector3).distance_to(sp) < 0.1
	var fe: ImpactCorps.Foyer = ic.trouver(da, "electricite")
	var fd: ImpactCorps.Foyer = ic.trouver(db, "tenebres")
	var fg: ImpactCorps.Foyer = ic.trouver(dc, "glace")
	var fc: ImpactCorps.Foyer = ic.trouver(dc, "electricite")
	verifier(fe != null and fd != null and fg != null and fc != null, "écoles B : foyers électricité, ténèbres, glace, choc sur des corps")
	verifier(fin_sur, "électricité : le faisceau finit sur la surface du corps")
	verifier(fe != null and fe.arcs.visible and fe.nb_segs > 10, "électricité : arcs sur le corps (%d sous-segments)" % (fe.nb_segs if fe != null else 0))
	verifier(fd != null and fd.arcs.visible and fd.nb_segs > 10, "drain : filaments arrachés à la surface (%d sous-segments)" % (fd.nb_segs if fd != null else 0))
	# les arcs sont accrochés aux POINTS du corps : index valides, maillage posé sur l'origine du corps (le shader suit les os)
	var ok_idx := true
	for f: ImpactCorps.Foyer in [fe, fd]:
		if f == null:
			continue
		for k in f.nb_segs:
			var ia := int(f.segs[k * 8])
			ok_idx = ok_idx and ia >= 0 and ia < f.surface.nb
		ok_idx = ok_idx and f.arcs.global_position.distance_to(f.origine()) < 0.001 and f.arcs.mesh == ic.mesh_arcs
	verifier(ok_idx, "arcs : points d'accroche valides, maillage partagé posé sur le corps")
	# le corps bouge : les arcs le suivent (même repère que les émetteurs)
	da.position += Vector3(0.6, 0.0, 0.2)
	ImpactCorps.jet_gerbe(gm, je)
	await _images(2)
	verifier(fe != null and fe.arcs.global_position.distance_to(da.global_position) < 0.001 and fe.em[0].p.global_position.distance_to(da.global_position) < 0.001, "suivi : arcs et émetteurs suivent le corps déplacé")
	var cg := _canaux(dc)
	verifier(cg.x > 0.5 and cg.y > 0.0, "voile : givre ET choc fusionnés sur le même corps (%.2f, %.2f)" % [cg.x, cg.y])
	verifier(_canaux(db).z > 0.2, "voile : ténèbres sur le corps drainé (%.2f)" % _canaux(db).z)
	var coque_ok: bool = fg != null and fg.avec_coque and fg.coques[0].material_override == ic.mat_coques.glace
	coque_ok = coque_ok and fd != null and fd.coques[0].material_override == ic.mat_coques.tenebres
	verifier(coque_ok, "coque : un matériau partagé par école (glace, ténèbres), pris dans le pool")
	verifier(max_budget <= GestionMagie.MAX_PARTICULES_FIN, "plafond : écoles B, %d particules <= %d" % [max_budget, GestionMagie.MAX_PARTICULES_FIN])
	# projectiles : impact DANS un corps → rendu sur sa surface ; sur le décor → rendu d'avant
	EffetsMagie.tout_arreter()
	await _images(2)
	var centre: Vector3 = da.global_position + Vector3.UP * 1.1
	verifier(ImpactCorps.impact(gm, "glace", centre, Vector3.BACK, 0.8), "projectile : lance de givre dans un corps prise en charge")
	verifier(ImpactCorps.impact(gm, "tenebres", db.global_position + Vector3.UP * 1.1, Vector3.BACK, 0.8), "projectile : trait d'ombre dans un corps pris en charge")
	verifier(ImpactCorps.impact(gm, "feu", dc.global_position + Vector3.UP * 1.1, Vector3.BACK, 1.6), "projectile : boule de feu dans un corps prise en charge (souffle = impulsion)")
	verifier(ImpactCorps.impact(gm, "electricite", da.global_position + Vector3.UP * 1.0, Vector3.BACK, 0.7), "chaîne d'éclairs : impact sur le corps pris en charge")
	verifier(not ImpactCorps.impact(gm, "glace", Vector3(0, 1.0, 8.0), Vector3.BACK, 0.8), "projectile sur le décor : rendu d'avant")
	var fg2: ImpactCorps.Foyer = ic.trouver(da, "glace")
	await _images(5)
	verifier(fg2 != null and float(fg2.d.rayon) > 0.0 and float(fg2.d.gel) > 0.0, "glace : la plaque de givre gagne la surface depuis le point touché (rayon %.2f m)" % (float(fg2.d.rayon) if fg2 != null else 0.0))
	# (la chaîne n'ouvre ni ne lit de surface : elle reprend celle d'un foyer du corps, ici celui de l'impact électrique)
	var pts := [main.global_position, da.global_position + Vector3.UP * 1.1] as Array[Vector3]
	ImpactCorps.points_sur_corps(gm, pts)
	verifier(pts[1].distance_to(da.global_position + Vector3.UP * 1.1) > 0.05, "chaîne : l'arc se pose sur la surface du corps (%.2f m du centre)" % pts[1].distance_to(da.global_position + Vector3.UP * 1.1))
	# rien de créé par tout ça (pool, matériaux et rampes des écoles créés avec le pool)
	await _images(3)
	verifier(ic.crees == crees0, "écoles B : rien créé par le module (%d → %d)" % [crees0, ic.crees])
	verifier(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == noeuds0, "écoles B : nombre de nœuds du moteur inchangé")
	verifier(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= res0, "écoles B : nombre de ressources du moteur inchangé (%d → %d)" % [res0, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	# persistances puis extinction : givre qui fond, traces de choc, ténèbres qui se dissipent → foyers rendus, canaux nuls
	for c: Node3D in corps:
		for st in ["gel", "choc", "corruption", "brulure"]:
			ImpactCorps.statut(gm, c, st, 0.0)
	await _images(20)
	var fond: ImpactCorps.Foyer = ic.trouver(da, "glace")
	verifier(fond != null and float(fond.d.fonte) > 0.0, "glace : le givre fond après le statut (gouttes)")
	var t1 := Time.get_ticks_msec()
	while ImpactCorps.stats().foyers > 0 and Time.get_ticks_msec() - t1 < 60000:
		await process_frame
	verifier(ImpactCorps.stats().foyers == 0 and ImpactCorps.stats().particules == 0, "écoles B : extinction complète (foyers, réserve)")
	var reste := 0
	for c: Node3D in corps:
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay == ic.mat_voile:
				reste += 1
	verifier(reste == 0, "écoles B : voile retiré de tous les maillages (%d restants)" % reste)

func _points_de_l_os(s: SurfaceCorps, os: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for i in s.nb:
		if s.os_de[i] == os:
			r.append(i)
	return r

func _lancer() -> void:
	print("test_impact_corps")
	monde = Node3D.new()
	root.add_child(monde)
	current_scene = monde
	GestionMagie.forcer_fin = true   # réglages de la couche fine (pas de rendu sans fenêtre)
	var gm := GestionMagie.obtenir()
	await _images(2)
	var ic := ImpactCorps.obtenir(gm)
	await _images(1)
	verifier(ic.foyers.size() == ImpactCorps.MAX_FOYERS, "pool : %d foyers" % ic.foyers.size())
	var d1 := _draugr(Vector3(0, 0, -4))
	var d2 := _draugr(Vector3(-1.6, 0, -4.6))
	var d3 := _draugr(Vector3(1.6, 0, -4.6))
	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(40, 1, 40)
	cs.shape = bx
	sol.add_child(cs)
	monde.add_child(sol)
	sol.position = Vector3(0, -0.5, 0)
	var main := Node3D.new()
	monde.add_child(main)
	main.position = Vector3(0, 1.4, 0)
	# lecture des maillages EN AVANCE (un par image), sans aucun jet
	var t0 := Time.get_ticks_msec()
	while not (SurfaceCorps.pret(d1) and SurfaceCorps.pret(d2) and SurfaceCorps.pret(d3)) and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	verifier(SurfaceCorps.pret(d1) and SurfaceCorps.pret(d3), "maillages des draugrs lus d'avance (%d lectures, %.1f ms en tout)" % [SurfaceCorps.lectures, SurfaceCorps.duree_lectures_us / 1000.0])

	# ------------------------------------------------ surface : points sur le corps
	var s := SurfaceCorps.de(d1)
	await _images(2)
	s.actualiser(d1.global_position)
	verifier(s.nb >= 120 and s.nb <= SurfaceCorps.LARGEUR, "surface : %d points (120..%d)" % [s.nb, SurfaceCorps.LARGEUR])
	verifier(not s.repli(), "surface : vrais maillages (pas le repli en capsules)")
	verifier(s.bas > -0.15 and s.bas < 0.25 and s.haut > 1.4 and s.haut < 2.0, "surface : du sol (%.2f) à la tête (%.2f)" % [s.bas, s.haut])
	var hors := 0
	for i in s.nb:
		var p := s.pos[i]
		if Vector2(p.x, p.z).length() > 1.2 or p.y < -0.2 or p.y > 2.1:
			hors += 1
	verifier(hors == 0, "surface : tous les points sur la silhouette (%d hors de la boîte du corps)" % hors)
	var sq := d1.find_child("Skeleton3D", true, false) as Skeleton3D
	sq.skeleton_updated.connect(_noter_poses.bind(sq))
	await _images(2)
	s.actualiser(d1.global_position)
	var main_g := sq.find_bone("hand_l")
	var avant_bras := sq.find_bone("lowerarm_l")
	var pts_main := _points_de_l_os(s, main_g)
	if pts_main.is_empty():
		pts_main = _points_de_l_os(s, avant_bras)
		main_g = avant_bras
	verifier(not pts_main.is_empty(), "surface : %d points sur la main / l'avant-bras gauche" % pts_main.size())

	# ------------------------------------------------ les points SUIVENT les os
	var i0 := pts_main[0] if not pts_main.is_empty() else 0
	var os_xf := _pose(sq, main_g)
	var local0 := os_xf.affine_inverse() * (d1.global_position + s.pos[i0])
	d1.position += Vector3(0.7, 0.0, -0.3)
	d1.rotation.y = 1.2
	sq.set_bone_pose_rotation(sq.find_bone("upperarm_l"), sq.get_bone_pose_rotation(sq.find_bone("upperarm_l")) * Quaternion(Vector3.FORWARD, 1.1))
	await _images(2)
	s.actualiser(d1.global_position)
	os_xf = _pose(sq, main_g)
	var local1 := os_xf.affine_inverse() * (d1.global_position + s.pos[i0])
	verifier(local0.distance_to(local1) < 0.01, "suivi : point de la main fixe dans le repère de son os après déplacement + bras levé (écart %.4f m)" % local0.distance_to(local1))
	var monde0 := d1.global_position + s.pos[i0]
	# ragdoll : le corps tombe, les points suivent
	var rd := Ragdoll.equiper(d1) as Ragdoll
	verifier(rd != null, "ragdoll équipé")
	if rd != null:
		rd.declencher(Vector3(0.0, 0.0, -1.0) * 40.0, d1.global_position + Vector3.UP * 1.3)
		await _images(90)
		s.actualiser(d1.global_position)
		os_xf = _pose(sq, main_g)
		var local2 := os_xf.affine_inverse() * (d1.global_position + s.pos[i0])
		verifier(local0.distance_to(local2) < 0.01, "suivi : ragdoll, point toujours collé à son os (écart %.4f m)" % local0.distance_to(local2))
		verifier(s.haut < 1.2, "suivi : ragdoll, le corps est tombé (haut des points %.2f m)" % s.haut)
		verifier(monde0.distance_to(d1.global_position + s.pos[i0]) > 0.2, "suivi : la main a bougé avec le corps (%.2f m)" % monde0.distance_to(d1.global_position + s.pos[i0]))
	# décapitation : l'os de la tête écrasé → ses points se rabattent sur le cou
	var tete := sq.find_bone("Head")
	var pts_tete := _points_de_l_os(s, tete)
	if not pts_tete.is_empty():
		var ct := Decapitation.CouTranche.new()
		ct.os = tete
		sq.add_child(ct)
		await _images(3)
		s.actualiser(d1.global_position)
		var cou := _pose(sq, tete)
		var loin := 0.0
		for i in pts_tete:
			loin = maxf(loin, (d1.global_position + s.pos[i]).distance_to(cou.origin))
		verifier(loin < 0.03, "suivi : décapitation, points de la tête rabattus sur le cou (%.3f m)" % loin)
		ct.queue_free()

	# ------------------------------------------------ aucun nœud / matériau / texture créé par impact
	await _images(5)
	var crees0 := ic.crees
	var noeuds0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var res0 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var enfants0 := ic.get_child_count()
	var jets := [_faux_jet(gm, main, d2), _faux_jet(gm, main, d3)]
	var max_budget := 0
	for rep in 3:
		for k in 40:
			for j: Dictionary in jets:
				j.fin_pos = (j.cible as Node3D).global_position + Vector3.UP * 1.1
				ImpactCorps.jet_gerbe(gm, j)
			if k % 12 == 0:
				ImpactCorps.statut(gm, d2, "brulure", 3.0)
				ImpactCorps.statut(gm, d3, "brulure", 3.0)
			await process_frame
			max_budget = maxi(max_budget, gm._budget)
		await _images(30)
	verifier(ic.crees == crees0, "impacts : rien créé par le module (%d → %d)" % [crees0, ic.crees])
	verifier(ic.get_child_count() == enfants0, "impacts : aucun nœud ajouté sous ImpactCorps (%d → %d)" % [enfants0, ic.get_child_count()])
	var noeuds1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var res1 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	verifier(noeuds1 == noeuds0, "impacts : nombre de nœuds du moteur inchangé (%d → %d)" % [noeuds0, noeuds1])
	verifier(res1 <= res0, "impacts : nombre de ressources du moteur inchangé (%d → %d)" % [res0, res1])
	var f2: ImpactCorps.Foyer = ic.trouver(d2, "feu")
	verifier(f2 != null and not f2.voiles.is_empty(), "voile : %d maillages voilés sur le draugr" % (f2.voiles.size() if f2 != null else 0))
	var partage := true
	if f2 != null:
		for mi: MeshInstance3D in f2.voiles:
			partage = partage and mi.material_overlay == ic.mat_voile
		for k in f2.voiles.size():
			var c: MeshInstance3D = f2.coques[k]
			partage = partage and c.material_override == ic.mat_coque and c.visible and c.mesh == (f2.voiles[k] as MeshInstance3D).mesh
	verifier(partage, "voile et coque : UN matériau partagé, coque = même maillage que le corps")
	verifier(f2 != null and f2.d.k_brule > 0.0, "brûlure : le corps brûle après l'arrêt du jet")
	verifier(max_budget <= GestionMagie.MAX_PARTICULES_FIN, "plafond : %d particules au plus <= %d" % [max_budget, GestionMagie.MAX_PARTICULES_FIN])

	# ------------------------------------------------ plafond : vrai double jet sur 3 draugrs + 5 cibles pour 4 foyers
	var d4 := _draugr(Vector3(3.0, 0, -5))
	var d5 := _draugr(Vector3(-3.0, 0, -5))
	var paume_d := Node3D.new()
	monde.add_child(paume_d)
	paume_d.position = Vector3(0.3, 1.4, 0)
	EffetsMagie.double("feu", true)
	var pire := 0
	for k in 90:
		for c: Node3D in [d2, d3]:
			EffetsMagie.jet("feu", main, (c.global_position + Vector3.UP * 1.1 - main.global_position).normalized(), 7.0, 0.9, true)
			EffetsMagie.jet("feu", paume_d, (c.global_position + Vector3.UP * 1.1 - paume_d.global_position).normalized(), 7.0, 0.9, true)
		for c: Node3D in [d1, d2, d3, d4, d5]:
			EffetsMagie.statut_cible(c, "brulure", 3.0)
		await process_frame
		pire = maxi(pire, gm._budget)
	var st := ImpactCorps.stats()
	verifier(pire <= GestionMagie.MAX_PARTICULES_FIN, "plafond : double jet + 5 corps en feu, %d particules <= %d" % [pire, GestionMagie.MAX_PARTICULES_FIN])
	verifier(st.foyers <= ImpactCorps.MAX_FOYERS, "pool : %d foyers actifs <= %d" % [st.foyers, ImpactCorps.MAX_FOYERS])
	verifier(ic.crees == crees0, "pool : 5 cibles sans rien créer (%d)" % ic.crees)
	EffetsMagie.double("feu", false)
	EffetsMagie.jet("feu", main, Vector3.FORWARD, 7.0, 0.9, false)
	EffetsMagie.jet("feu", paume_d, Vector3.FORWARD, 7.0, 0.9, false)

	# ------------------------------------------------ extinction : braises, carbonisation qui s'estompe, voile retiré
	for c: Node3D in [d1, d2, d3, d4, d5]:
		EffetsMagie.statut_cible(c, "brulure", 0.0)
	var t1 := Time.get_ticks_msec()
	while ImpactCorps.stats().foyers > 0 and Time.get_ticks_msec() - t1 < 60000:
		await process_frame
	verifier(ImpactCorps.stats().foyers == 0, "extinction : tous les foyers rendus au pool")
	verifier(ImpactCorps.stats().particules == 0, "extinction : réserve de particules rendue (%d)" % ImpactCorps.stats().particules)
	var reste := 0
	for c: Node3D in [d2, d3, d4, d5]:
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay == ic.mat_voile:
				reste += 1
	verifier(reste == 0, "extinction : voile retiré de tous les maillages (%d restants)" % reste)

	# ------------------------------------------------ agent B : électricité, glace, ténèbres, projectiles (même socle)
	await _ecoles_b(gm, ic, main, [d2, d3, d4], crees0)

	# ------------------------------------------------ tout_arreter et rendu d'avant
	ImpactCorps.statut(gm, d2, "brulure", 3.0)
	await _images(3)
	EffetsMagie.tout_arreter()
	await _images(2)
	verifier(ImpactCorps.stats().foyers == 0 and ImpactCorps.stats().particules == 0, "tout_arreter : foyers éteints, réserve rendue")
	ImpactCorps.actif = false
	verifier(not ImpactCorps.jet_gerbe(gm, _faux_jet(gm, main, d2)), "ImpactCorps.actif = faux : la gerbe d'avant reprend la main")
	ImpactCorps.actif = true
	GestionMagie.forcer_fin = false
	print("test_impact_corps : ", "TOUT OK" if echecs == 0 else "ECHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)
