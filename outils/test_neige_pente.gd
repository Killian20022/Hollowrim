extends SceneTree
## Retours exe 5 (« des tas de neige qui ne suivent aucune physique, droits alors qu'ils sont dans une pente ») : chaque tas de neige de
## la grotte (congères du kit et congères drapées du décor) a sa BASE dans le sol : aucun point du bord du bas au-dessus du sol réel
## (vide visible sous le tas), aucun tas avalé (plus de la moitié de son bord à plus de 0,5 m sous le sol) et aucun tas sur une pente
## plus raide que PENTE_NEIGE.
##   godot --headless --path . --script outils/test_neige_pente.gd [-- --variante=N] [--sans-acces] [--lister]
## Aussi : objets (rochers, caisses) des congères enfoncés dans la neige ; congères du kit en pente remplacées par des drapées ;
## l'entrée extérieure (GrotteAcces, monde chargé) a ses congères posées sur le relief.
const TOL_HAUT := 0.012      # m : un point du bord du bas plus haut que le sol de plus que ça = vide sous la neige
const TOL_BAS := 0.5

var g: Grotte
var _echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Sommets du bas d'un gabarit du kit (repère du gabarit).
func _bas_gabarit(nom: String) -> PackedVector3Array:
	var G: Dictionary = g.kit.gab[nom]
	var tous := PackedVector3Array()
	for mat: String in G["surf"]:
		tous.append_array((G["surf"][mat] as Dictionary)["v"])
	var ymin := INF
	for v in tous:
		ymin = minf(ymin, v.y)
	var bas := PackedVector3Array()
	for v in tous:
		if v.y < ymin + 0.02:
			bas.append(v)
	return bas

## [pire écart au-dessus du sol, part des points enfouis de plus de TOL_BAS, points sans sol] d'un bord du bas (repère de la grotte).
## Un point sans sol est dans la roche (au-delà de la paroi : bord caché) ; un point profondément enfoui aussi (pied de paroi).
func _mesure(pts: PackedVector3Array) -> Vector3:
	var haut := -INF
	var avales := 0
	var sans := 0
	for p in pts:
		var s := g.sol_objet(p.x, p.z, p.y + 0.6)
		if s < -1e8:
			sans += 1
			continue
		haut = maxf(haut, p.y - s)
		if s - p.y > TOL_BAS:
			avales += 1
	return Vector3(haut, float(avales) / maxf(pts.size() - sans, 1), sans)

## Repère de capture (« s,décalage » global, voir Grotte.resoudre) le plus proche d'un point local : "s=… lat=…".
func _ou(p: Vector3) -> String:
	var best := INF
	var res := ""
	for id: String in g.ordre:
		var s := 0.0
		while s < g.longueur(id):
			var a := g.sol_en(id, s, 0.0)
			var d := Vector2(p.x - a.x, p.z - a.z).length()
			if d < best:
				best = d
				var R := g.droite(id, s)
				res = "s=%.1f lat=%.1f" % [float(g.br[id]["decalage"]) + s, (p - a).dot(R)]
			s += 0.25
	return res

func _lancer() -> void:
	var pere := Node3D.new()
	root.add_child(pere)
	var def_g: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variante="):
			def_g = GrotteDonnees.variante(GrotteDonnees.repaire_hrafn(), int(a.substr(11)))
	g = Grotte.creer(pere, null, def_g)
	for i in 3:
		await physics_frame
	var bords: Array = []       # [description, PackedVector3Array]
	if g.kit != null:
		var poses: Array = g.kit.get("neige_poses") if g.kit.get("neige_poses") != null else []
		if poses.is_empty():     # ancien code : instances brutes du kit
			for cle: String in g.kit._inst:
				if cle.begins_with("neige_"):
					for xf: Transform3D in g.kit._inst[cle]:
						poses.append([cle.get_slice("|", 0), xf])
		var caches := {}
		for e: Array in poses:
			if not caches.has(e[0]):
				caches[e[0]] = _bas_gabarit(e[0])
			var w := PackedVector3Array()
			for v: Vector3 in caches[e[0]]:
				w.append((e[1] as Transform3D) * v)
			bords.append(["kit %s (%.1f ; %.1f ; %.1f)" % [e[0], (e[1] as Transform3D).origin.x, (e[1] as Transform3D).origin.y, (e[1] as Transform3D).origin.z], w])
	var nk := bords.size()
	if OS.get_cmdline_user_args().has("--lister") and g.kit != null:
		for e: Array in g.kit.neige_poses:
			var o: Vector3 = (e[1] as Transform3D).origin
			print("   kit %s  %s  pente %.0f°  descendu %.2f m  haut %.2f m" % [e[0], _ou(o), e[2], e[3], (e[1] as Transform3D).basis.y.length() * float(g.kit.gab[e[0]]["h"])])
	var nb: Array = g.decor.get("neige_bases") if g.decor.get("neige_bases") != null else []
	for b: PackedVector3Array in nb:
		if OS.get_cmdline_user_args().has("--lister"):
			var cc := (b[0] + b[9]) * 0.5
			var rr := Vector2(b[0].x - b[9].x, b[0].z - b[9].z).length() * 0.5
			print("   congère du décor  %s  r %.1f" % [_ou(cc), rr])
			for e: Array in g.decor.empreintes:
				var pe: Vector3 = e[0]
				if Vector2(pe.x - cc.x, pe.z - cc.z).length() < rr + float(e[1]):
					print("      objet r %.2f h %.2f pied-sol %.2f roche %s" % [e[1], e[2], pe.y - g.sol_objet(pe.x, pe.z, pe.y + 0.3), e.size() > 3])
			for cle: String in g.kit._inst:
				for xf: Transform3D in g.kit._inst[cle]:
					if Vector2(xf.origin.x - cc.x, xf.origin.z - cc.z).length() < rr + 0.3:
						print("      kit %s pied-sol %.2f ech %s" % [cle.get_slice("|", 0), xf.origin.y - g.sol_objet(xf.origin.x, xf.origin.z, xf.origin.y + 0.3), xf.basis.get_scale()])
		bords.append(["congère (%.1f ; %.1f ; %.1f)" % [b[0].x, b[0].y, b[0].z], b])
	print("%d tas de neige : %d congères du kit, %d congères du décor ; %d + %d refusées (pente, marche, vide)" % [bords.size(), nk, bords.size() - nk,
		int(g.kit.get("neige_refus")) if g.kit != null and g.kit.get("neige_refus") != null else 0, int(g.decor.get("neige_refus")) if g.decor.get("neige_refus") != null else 0])
	print("   motifs de refus : ", GrotteDecor.refus_neige, " ; bords du bas aplanis : ", g.decor.bords_adoucis)
	_verif(bords.size() >= 20, "la grotte a des tas de neige (%d)" % bords.size())
	var flottent := 0
	var avales := 0
	var pire := 0.0
	for e: Array in bords:
		var m := _mesure(e[1])
		pire = maxf(pire, m.x)
		if m.x > TOL_HAUT:
			flottent += 1
			if flottent <= 12:
				var c0 := Vector3.ZERO
				for q: Vector3 in e[1]:
					c0 += q
				print("      bord du bas %.2f m au-dessus du sol : %s  %s" % [m.x, e[0], _ou(c0 / (e[1] as PackedVector3Array).size())])
		if m.y > 0.5:
			avales += 1
			if avales <= 6:
				print("      %.0f %% du bord enfoui de plus de %.1f m : %s" % [m.y * 100.0, TOL_BAS, e[0]])
	_verif(flottent == 0, "aucun tas de neige dont la base sort du sol (%d sur %d, pire %.3f m)" % [flottent, bords.size(), pire])
	_verif(avales == 0, "aucun tas avalé par le sol (plus de la moitié du bord à plus de %.1f m dessous) (%d)" % [TOL_BAS, avales])
	# pente : le plan du sol sous chaque tas reste ≤ PENTE_NEIGE (sinon il n'aurait pas dû être posé)
	var raides := 0
	for e: Array in bords:
		var pts: PackedVector3Array = e[1]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		var rmax := 0.0
		for p in pts:
			rmax = maxf(rmax, Vector2(p.x - c.x, p.z - c.z).length())
		var pl := GrotteDecor.plan_neige(func(x: float, z: float) -> float: return g.sol_objet(x, z, c.y + rmax + 0.6), c, maxf(rmax * 0.8, 0.1))
		if not pl.is_empty() and float(pl["pente"]) > GrotteDecor.PENTE_NEIGE + 4.0:
			raides += 1
	_verif(raides == 0, "aucun tas sur une pente > %.0f° (%d)" % [GrotteDecor.PENTE_NEIGE + 4.0, raides])
	# rochers et caisses DANS une congère : la neige monte contre leur bord (enfoncés, pas posés dessus)
	var posees := 0
	for c: Array in g.decor.neige_colliers:
		if float(c[1]) < (c[0] as Vector3).y + 0.05:
			posees += 1
			print("      objet posé sur la neige : pied %s, neige au bord %.2f" % [c[0], c[1]])
	_verif(posees == 0, "objets des congères enfoncés dans la neige (%d sur %d posés dessus)" % [posees, g.decor.neige_colliers.size()])
	# contenants (coffres, caisses, tonneaux, sacs) : jamais enfouis sous une congère (ni du décor, ni du kit)
	var enfouis := 0
	for c: Array in g.decor.contenants:
		var pc: Vector3 = c[0]
		var ep := 0.0
		for dx: Array in [[0.0, 0.0], [1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0]]:     # centre et bord du contenant
			ep = maxf(ep, g.decor.neige_epaisseur(pc.x + float(dx[0]) * float(c[1]), pc.z + float(dx[1]) * float(c[1])))
		var sous_kit := false
		for e: Array in g.kit.neige_poses:
			var xf: Transform3D = e[1]
			if Vector2(pc.x - xf.origin.x, pc.z - xf.origin.z).length() < xf.basis.x.length() * 0.9 and absf(pc.y - xf.origin.y) < 0.8:
				sous_kit = true
		if ep > 0.03 or sous_kit:
			enfouis += 1
			print("      contenant enfoui : pied %s r %.2f h %.2f, neige %.2f, kit %s  %s" % [pc, c[1], c[2], ep, sous_kit, _ou(pc)])
	_verif(enfouis == 0, "aucun contenant (coffre, caisse, tonneau, sac) enfoui sous une congère (%d sur %d)" % [enfouis, g.decor.contenants.size()])
	# congères du kit en pente : remplacées (aucune congère cisaillée au-delà de PENTE_KIT)
	var cisaillees := 0
	for e: Array in g.kit.neige_poses:
		if float(e[2]) >= GrotteKit.PENTE_KIT:
			cisaillees += 1
	_verif(cisaillees == 0, "aucune congère du kit cisaillée sur une pente ≥ %.0f° (%d)" % [GrotteKit.PENTE_KIT, cisaillees])
	if not OS.get_cmdline_user_args().has("--sans-acces"):
		await _acces()
	print("TEST NEIGE PENTE : %s (%d échec(s))" % ["OK" if _echecs == 0 else "ECHEC", _echecs])
	quit(_echecs)

## Entrée extérieure (GrotteAcces, dans le monde) : ses congères drapées sur le relief, base dans le sol.
func _acces() -> void:
	var m: Node3D = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	while not bool(m.get("pret")):
		await process_frame
	var a = m.get("grotte_acces")
	_verif(a != null, "entrée de la grotte construite")
	if a == null:
		return
	var t0 := Time.get_ticks_msec()
	while (int(a._tache_ext) >= 0 and not WorkerThreadPool.is_task_completed(int(a._tache_ext))) or a.decor == null:
		await process_frame                                   # l'extérieur se bâtit dans un fil
		if Time.get_ticks_msec() - t0 > 120000:
			break
	_verif(a.decor != null, "décor de l'entrée bâti")
	if a.decor == null:
		return
	var nb: Array = a.decor.neige_bases
	var flottent := 0
	var pire := 0.0
	for b: PackedVector3Array in nb:
		var haut := -INF
		for p in b:
			haut = maxf(haut, p.y - a._hl(p.x, p.z))
		pire = maxf(pire, haut)
		if haut > TOL_HAUT:
			flottent += 1
	print("entrée : %d congères, %d refusées" % [nb.size(), a.decor.neige_refus])
	if OS.get_cmdline_user_args().has("--lister"):
		for dq: Array in a.decor.neige_disques:
			print("   entrée : congère %s r %.1f h %.2f pente %.0f°" % [dq[0], dq[1], dq[2], dq[3]])
	_verif(nb.size() >= 6, "l'entrée a ses congères (%d)" % nb.size())
	_verif(flottent == 0, "entrée : aucune congère dont la base sort du sol (%d, pire %.3f m)" % [flottent, pire])
