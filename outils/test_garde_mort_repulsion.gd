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
			await _mort(gs[0])
		if _seul() != "mort":
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
	_devant(g, 3.0)
	await _attendre(0.4)
	var mod: Node3D = g.modele
	var ba := _bassin(mod)
	await _attendre(0.05)
	var p0 := ba.global_position
	var s := es._sort("repulsion")
	var oeil: Vector3 = j.camera.global_position
	var avant := (g.global_position + Vector3.UP * 1.0 - oeil).normalized()
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
	_verif(g in res["ennemis"] or (cr.combattant_de(g) != null and cr.combattant_de(g) in res["ennemis"]), "le garde est touché par l'onde")
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
