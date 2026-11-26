extends SceneTree
## Test sans fenêtre (bugs/gardes_mort_repulsion, 2026-11-26) : un garde du village tué TOMBE (ragdoll, bassin au sol, corps fouillable),
## et la Répulsion pleine charge PROJETTE un garde de plusieurs mètres.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_garde_mort_repulsion.gd -- --nouvelle --paisible
## Option -- --seul=mort|repulsion.

const SCENE := preload("res://scenes/foret_test.tscn")
const DT := 1.0 / 60.0
const DEPLACEMENT_MIN := 4.0      # m : répulsion pleine charge sur un garde à 3 m

var m: Node3D
var j: CharacterBody3D
var cr: Crime
var magie: MainSort
var es: SortsEsprit
var _echecs := 0
var _dossier := ""     # -- --images=<dossier> (avec fenêtre hors écran) : une image vue joueur toutes les 4 images de physique
var _prefixe := "x"
var _n_img := 0
var _k := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK     " if ok else "ECHEC  ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in maxi(1, int(s * 60.0)):
		if j != null:
			j.vie = j.vie_max
			j.mana = j.mana_max
		await physics_frame
		_k += 1
		if _dossier != "" and _k % 4 == 0:
			await process_frame
			var img := root.get_viewport().get_texture().get_image()
			if img != null:
				img.save_png("%s/%s_%03d.png" % [_dossier, _prefixe, _n_img])
				_n_img += 1

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return ""

func _seul() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seul="):
			return a.substr(7)
	return ""

## Gardes à pied (poste ou ronde, pas la vigie), visibles, triés par distance à `p`.
func _gardes() -> Array:
	var res: Array = []
	for g in get_nodes_in_group("gardes_village"):
		if g is Node3D and is_instance_valid(g) and g.visible and String(g.get("service")) != "vigie" and g.get("remplace") == null:
			res.append(g)
	return res

## Place le joueur à `d` m devant `n`, face à lui.
func _devant(n: Node3D, d: float) -> void:
	var av := n.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var p := n.global_position + av * d
	p.y = m.hauteur(p.x, p.z) + 0.1
	j.global_position = p
	j.velocity = Vector3.ZERO
	var vers := n.global_position - p
	j.rotation.y = atan2(-vers.x, -vers.z)
	if j.get("tete") is Node3D:
		(j.tete as Node3D).rotation.x = deg_to_rad(-12.0)

func _bassin(mod: Node3D) -> BoneAttachment3D:
	var sq: Skeleton3D = mod.find_child("Skeleton3D", true, false)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "pelvis"
	sq.add_child(ba)
	return ba

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame
	for i in 30:
		await physics_frame
	j = m.joueur
	_dossier = _arg("images")
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	m.cycle.heure = 12.0
	cr = Crime.trouver(m)
	magie = j.mains.magie
	magie.eq.apprendre_tout()
	es = magie.esprit
	_verif(cr != null and es != null, "Crime et sorts de l'esprit branchés")
	var gs := _gardes()
	print("   gardes à pied : ", gs.size())
	_verif(gs.size() >= 2, "au moins deux gardes à pied")
	if gs.size() >= 2 and cr != null:
		if _seul() != "repulsion":
			await _mort(gs[0])      # meurtre vu : toute la garde prend les armes
		if _seul() in ["", "hostiles"]:
			await _hostiles()
		if _seul() == "repulsion":
			var autre: Node3D = gs[1]
			for g in gs:          # le plus loin du premier (pas de garde déjà en alerte à côté)
				if is_instance_valid(g) and is_instance_valid(gs[0]) and (g as Node3D).global_position.distance_to(gs[0].global_position) > autre.global_position.distance_to(gs[0].global_position):
					autre = g
			cr._gracier()
			await _attendre(0.3)
			await _repulsion(autre)
	print("ECHECS : %d" % _echecs)
	quit(0 if _echecs == 0 else 1)

# ------------------------------------------------------------------ garde tué

func _mort(g: Node3D) -> void:
	_prefixe = "mort"
	_n_img = 0
	_devant(g, 1.8)
	await _attendre(0.3)
	var mod: Node3D = g.modele
	var ba := _bassin(mod)
	await _attendre(0.05)
	var y0: float = ba.global_position.y - m.hauteur(ba.global_position.x, ba.global_position.z)
	print("   garde %s (%s) : bassin à %.2f m du sol debout" % [g.name, g.get("service"), y0])
	var info := {"attaquant": j, "attaque": "lourde"}
	DegatsCombat.appliquer(g, 12.0, j.global_position, false, info)        # 1er coup : avertissement
	await _attendre(0.2)
	DegatsCombat.appliquer(g, 12.0, j.global_position, false, info)        # 2e : il prend les armes
	await _attendre(0.2)
	var c: PnjCombat = cr.combattant_de(g) as PnjCombat
	_verif(c != null, "garde frappé deux fois : combattant créé")
	if c == null:
		return
	var r := ""
	var n := 0
	while not c.est_mort and n < 12:
		r = String(DegatsCombat.appliquer(c, c.vie + 80.0, j.global_position, true, info))
		n += 1
		await _attendre(0.05)
	_verif(c.est_mort, "garde tué (%s, %d coups)" % [r, n])
	var t := 0.0
	var t_sol := -1.0
	var h := 99.0
	while t < 3.0:
		await _attendre(DT)
		t += DT
		if not is_instance_valid(ba):
			break
		h = ba.global_position.y - float(m.hauteur(ba.global_position.x, ba.global_position.z))
		if t_sol < 0.0 and h < 0.4:
			t_sol = t
	var rd: Ragdoll = c._ragdoll
	_diag(c.modele)
	print("   ragdoll=%s actif=%s ; bassin à %.2f m du sol après 3 s ; au sol après %.2f s" % [str(rd != null), str(rd != null and rd.actif), h, t_sol])
	_verif(rd != null and rd.actif, "ragdoll déclenché à la mort")
	_verif(t_sol >= 0.0 and t_sol < 2.0, "couché au sol en moins de 2 s (bassin < 0,4 m : %.2f s)" % t_sol)
	_verif(h < 0.4, "toujours couché à 3 s (bassin %.2f m)" % h)
	_verif(c._butin != null and is_instance_valid(c._butin), "corps fouillable (bourse posée)")
	if _dossier != "" and is_instance_valid(ba):
		# plan de côté : le joueur recule de 3,5 m, en biais, et regarde le corps
		var cp := ba.global_position
		var cote := (j.global_position - cp)
		cote.y = 0.0
		cote = cote.normalized().rotated(Vector3.UP, 1.1) * 3.5
		var pj := cp + cote
		pj.y = m.hauteur(pj.x, pj.z) + 0.1
		j.global_position = pj
		var vv := cp - pj
		j.rotation.y = atan2(-vv.x, -vv.z)
		if j.get("tete") is Node3D:
			(j.tete as Node3D).rotation.x = deg_to_rad(-28.0)
		_prefixe = "mort_cote"
		_n_img = 0
		await _attendre(0.5)

# ------------------------------------------------------------------ répulsion

func _repulsion(g: Node3D) -> void:
	_prefixe = "repulsion"
	_n_img = 0
	g = Elements.corps_visible(g) as Node3D      # déjà en armes (meurtre vu) : c'est son combattant qu'on voit
	if g is CharacterBody3D:
		(g as CharacterBody3D).set_physics_process(false)   # immobile le temps de viser (il courrait sur le joueur)
	_devant(g, 3.0)
	await _attendre(0.4)
	var mod: Node3D = g.modele
	var ba := _bassin(mod)
	await _attendre(0.05)
	var p0 := ba.global_position
	var s := es._sort("repulsion")
	var oeil: Vector3 = j.camera.global_position
	var avant := (g.global_position + Vector3.UP * 1.0 - oeil).normalized()
	if g is CharacterBody3D:
		(g as CharacterBody3D).set_physics_process(true)
	var res := es.repulsion(s, 1.0, null, oeil, avant)
	print("   répulsion : niveau %.2f force %.1f portée %.1f ; touchés %d" % [float(res["niveau"]), float(res["force"]), float(res["portee"]), (res["ennemis"] as Array).size()])
	var y_max := -99.0
	var d_max := 0.0
	var t := 0.0
	while t < 3.0:
		await _attendre(DT)
		t += DT
		if not is_instance_valid(ba):
			break
		var p := ba.global_position
		y_max = maxf(y_max, p.y - p0.y)
		d_max = maxf(d_max, Vector2(p.x - p0.x, p.z - p0.z).length())
	for x in es.journal.slice(-8):
		print("   ES %.2f %s" % [x[0], x[1]])
	print("   garde projeté : %.2f m à l'horizontale, bassin monté de %.2f m" % [d_max, y_max])
	var vu := false
	for e in res["ennemis"]:
		vu = vu or e == g or Elements.corps_visible(g) == e or (g is PnjCombat and (g as PnjCombat).pnj == e)
	_verif(vu, "le garde est touché par l'onde")
	_verif(d_max >= DEPLACEMENT_MIN, "répulsion pleine charge : garde projeté de %.2f m (≥ %.1f m)" % [d_max, DEPLACEMENT_MIN])
	_verif(y_max >= 0.5, "il décolle (bassin +%.2f m)" % y_max)

## Diagnostic : squelettes du modèle et maillages visibles (squelette résolu, peau) — un maillage hors du squelette du ragdoll reste debout.
func _diag(mod: Node3D) -> void:
	var sqs := mod.find_children("*", "Skeleton3D", true, false)
	print("   squelettes : ", sqs.map(func(x): return "%s(%d os) <- %s" % [x.name, (x as Skeleton3D).get_bone_count(), x.get_parent().name]))
	for mi: MeshInstance3D in mod.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var sq := mi.get_node_or_null(mi.skeleton) if mi.skeleton != NodePath("") else null
		print("     maillage %s (parent %s) : skin=%s squelette=%s y=%.2f" % [mi.name, mi.get_parent().name, str(mi.skin != null), (sq.name if sq else "-"), mi.global_position.y])

# ------------------------------------------------------------------ gardes HOSTILES tués en combat (épée, finisher, arc), répulsion

func _combattants_hostiles() -> Array:
	var l: Array = []
	for c in cr.combattants:
		if is_instance_valid(c) and not c.est_mort and c.mode == "hostile" and c.est_garde:
			l.append(c)
	l.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(j.global_position) < (b as Node3D).global_position.distance_to(j.global_position))
	return l

func _hostiles() -> void:
	await _attendre(1.0)
	var hs := _combattants_hostiles()
	print("   gardes hostiles après le meurtre : ", hs.size())
	_verif(hs.size() >= 4, "au moins 4 gardes hostiles (%d)" % hs.size())
	# arc_loin : flèche sur un garde à 14 m DANS LE DOS du joueur (AnimLod gèle hors champ le squelette ; le cas où le corps restait debout)
	var manieres := ["epee", "finisher", "arc", "arc_loin"]
	for i in mini(4, hs.size()):
		hs = _combattants_hostiles()
		if hs.is_empty():
			break
		await _tuer_hostile(hs[0], manieres[i])
	hs = _combattants_hostiles()
	if not hs.is_empty():
		await _repulsion_hostile(hs[0], false)    # dans la mêlée (au village, entouré de gardes) : informatif
	hs = _combattants_hostiles()
	if not hs.is_empty():
		await _repulsion_hostile(hs[0], true)     # en terrain dégagé : critère chiffré

## Point dégagé à ~95 m du centre du village, loin de tout PNJ (test_crime).
func _coin_desert() -> Vector3:
	for k in 60:
		var a := TAU * k / 60.0
		var p := Vector3(44.0 + cos(a) * 95.0, 0.0, 40.0 + sin(a) * 95.0)
		p.y = m.hauteur(p.x, p.z) + 0.1
		var ok := true
		for n: Node3D in cr.pnj_actifs():
			if n.global_position.distance_to(p) < 30.0:
				ok = false
				break
		if ok:
			return p
	return Vector3(44.0, m.hauteur(44.0, 160.0) + 0.1, 160.0)

func _tuer_hostile(c: PnjCombat, maniere: String) -> void:
	_prefixe = "hostile_" + maniere
	_n_img = 0
	var pnj: Node3D = c.pnj
	_devant(c, 2.0)
	if maniere == "arc_loin":
		c.set_physics_process(false)          # il ne court plus sur le joueur
		var av := (j.global_position - c.global_position)
		av.y = 0.0
		av = av.normalized()
		var p := c.global_position + av * 14.0
		p.y = m.hauteur(p.x, p.z) + 0.1
		j.global_position = p
		j.rotation.y = atan2(-av.x, -av.z)    # le joueur regarde AU LOIN, le garde dans son dos
		await _attendre(0.6)                  # AnimLod réévalue (0,1 s)
	await _attendre(0.1)
	var ba := _bassin(c.modele)
	var n := 0
	var r := ""
	while not c.est_mort and n < 40:
		var dos := c.global_position + c.global_transform.basis.z * -1.6   # dans le dos (un garde de face pare)
		match maniere:
			"epee":
				r = String(DegatsCombat.appliquer(c, 26.0, dos, false, {"attaquant": j, "attaque": "legere", "arme": "epee"}))
			"finisher":
				c.vie = minf(c.vie, c.vie_max * 0.12)
				var cat := c.finisher_possible(j)
				print("   finisher possible : « %s »" % cat)
				r = String(c.subir_finisher(cat if cat != "" else "etourdi", {"origine": j.global_position}))
			"arc", "arc_loin":
				r = String(DegatsCombat.appliquer(c, 30.0, dos, false, {"attaquant": j, "attaque": "legere", "arme": "arc", "type": "percant"}))
		n += 1
		await _attendre(0.25)
	_verif(c.est_mort, "garde hostile tué (%s, %d coups, %s)" % [maniere, n, r])
	var t := 0.0
	var t_sol := -1.0
	var h := 99.0
	var pnj_vu := false
	while t < 2.5:
		await _attendre(DT)
		t += DT
		if is_instance_valid(ba):
			h = ba.global_position.y - float(m.hauteur(ba.global_position.x, ba.global_position.z))
			if t_sol < 0.0 and h < 0.4:
				t_sol = t
		if is_instance_valid(pnj) and pnj.is_inside_tree() and pnj.is_visible_in_tree():
			pnj_vu = true
	var rd: Ragdoll = c._ragdoll if is_instance_valid(c) else null
	if is_instance_valid(c) and is_instance_valid(ba):
		var sq: Skeleton3D = c.modele.find_child("Skeleton3D", true, false)
		var tete := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head")).origin)
		var ro: Variant = c.combat.reaction_os if c.combat != null else null
		var mods := sq.get_children().filter(func(x): return x is SkeletonModifier3D).map(func(x): return "%s:%s" % [x.name, str(x.active)])
		print("     tête %.2f m au-dessus du bassin ; anim « %s » ; reaction_os actif=%s ; fige=%s ; modificateurs %s" % [tete.y - ba.global_position.y,
			c.anim.current_animation, str(ro != null and is_instance_valid(ro) and ro.active), str(rd != null and rd.est_fige()), str(mods)])
		print("     bassin (%.2f, %.2f, %.2f) sol %.2f ; sous le bassin : %s" % [ba.global_position.x, ba.global_position.y, ba.global_position.z,
			m.hauteur(ba.global_position.x, ba.global_position.z), str(_sous(ba.global_position, c))])
	print("   %s : ragdoll=%s, bassin %.2f m, au sol après %.2f s, PNJ d'origine visible=%s" % [maniere, str(rd != null and rd.actif), h, t_sol, str(pnj_vu)])
	_verif(rd != null and rd.actif and t_sol >= 0.0 and t_sol < 2.0, "%s : couché au sol en moins de 2 s (%.2f s, bassin %.2f m)" % [maniere, t_sol, h])
	_verif(not pnj_vu, "%s : le garde d'origine (caché) ne réapparaît pas debout" % maniere)

func _repulsion_hostile(c: PnjCombat, degage: bool) -> void:
	_prefixe = "repulsion_hostile" + ("_degage" if degage else "_melee")
	_n_img = 0
	c.set_physics_process(false)
	if degage:
		var p := _coin_desert()
		j.global_position = p
		j.velocity = Vector3.ZERO
		var q := p + Vector3(0, 0, -3.0)
		q.y = m.hauteur(q.x, q.z) + 0.02
		c.global_position = q
		c.rotation.y = 0.0
		await _attendre(0.05)
		print("   dégagé : joueur %s, garde voulu %s, garde réel %s (valide=%s, process=%s)" % [str(p.snappedf(0.1)), str(q.snappedf(0.1)), str(c.global_position.snappedf(0.1)), str(is_instance_valid(c)), str(c.is_physics_processing())])
	_devant(c, 3.0)
	await _attendre(0.6)
	var ba := _bassin(c.modele)
	var p0 := ba.global_position
	var oeil: Vector3 = j.camera.global_position
	var qr := PhysicsRayQueryParameters3D.create(oeil, Elements._centre(c), 1)
	qr.exclude = [j.get_rid(), c.get_rid()]
	var hr := j.get_world_3d().direct_space_state.intersect_ray(qr)
	print("   œil %s (joueur %s) ; obstacle : %s" % [str(oeil.snappedf(0.01)), str(j.global_position.snappedf(0.01)),
		"aucun" if hr.is_empty() else "%s (%s) en %s" % [(hr["collider"] as Node).name, (hr["collider"] as Node).get_class(), str((hr["position"] as Vector3).snappedf(0.01))]])
	var ce := Elements._centre(c)
	var d := ce - oeil
	print("   cible %s : distance %.2f, dy %.2f, dans cibles=%s, groupes ennemis=%s cibles_combat=%s, sans mur=%s" % [c.name, Vector3(d.x, 0, d.z).length(), d.y,
		str(es._cibles(oeil, 14.0).has(c)), str(c.is_in_group("ennemis")), str(c.is_in_group("cibles_combat")), str(es._sans_mur(oeil, ce, c))])
	c.set_physics_process(true)
	var res := es.repulsion(es._sort("repulsion"), 1.0, null, oeil, d.normalized())
	var dm := 0.0
	var ym := 0.0
	var t := 0.0
	while t < 3.0:
		await _attendre(DT)
		t += DT
		if is_instance_valid(ba):
			dm = maxf(dm, Vector2(ba.global_position.x - p0.x, ba.global_position.z - p0.z).length())
			ym = maxf(ym, ba.global_position.y - p0.y)
	for x in es.journal.slice(-10):
		print("   ES %.2f %s" % [x[0], x[1]])
	print("   répulsion sur garde hostile : touchés %d, projeté %.2f m, bassin +%.2f m" % [(res["ennemis"] as Array).size(), dm, ym])
	if not degage:
		return
	_verif(c in res["ennemis"], "répulsion : le garde hostile est touché")
	_verif(dm >= DEPLACEMENT_MIN and ym >= 0.5, "répulsion pleine charge sur garde hostile (terrain dégagé) : %.2f m (≥ %.1f), +%.2f m" % [dm, DEPLACEMENT_MIN, ym])

func _sous(p: Vector3, c: Node) -> String:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.05, p + Vector3.DOWN * 3.0)
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return "rien"
	var o: Object = r["collider"]
	return "%s à %.2f m" % [(o as Node).name if o is Node else str(o), p.y - (r["position"] as Vector3).y]
