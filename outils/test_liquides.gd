extends SceneTree
## Test sans fenêtre des LIQUIDES RÉALISTES (monde/liquides, docs/LIQUIDES.md) dans scenes/test_combat.tscn :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_liquides.gd -- --nouvelle
## - aucune goutte ni flaque ne reste en l'air, quelle que soit la hauteur du versement (0,6 m à 900 m) ;
## - flaque sur une surface horizontale seulement, jamais sur un mur (le liquide y coule) ;
## - ruissellement d'une étagère vers le sol (la flaque de l'étagère ne déborde pas dans le vide, le surplus s'égoutte) ;
## - absorption sur la neige (tache diffuse, sans reflet, plus petite) ; séchage différencié (l'eau s'efface avant le sang) ;
## - plafonds des pools (gouttes, flaques, taches, coulures, filets) ; rien ne tourne au repos ;
## - API sang inchangée (Sang, GouttesSang, SangLame, CasseObjets.verser_liquide) ; --sans-liquides : ancienne flaque.

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _frames(n: int) -> void:
	for k in n:
		await physics_frame

## Attend que plus rien ne vole ni ne coule (gouttes, sources, coulures), `maxi` images au plus.
func _calme(maxi := 1500) -> int:
	for i in maxi:
		await physics_frame
		var l := Liquides.instance
		if GouttesSang.en_vol() == 0 and (l == null or (l.sources.is_empty() and l.coulures.is_empty() and not _egoutte(l))):
			return i
	return -1

func _egoutte(l: Liquides) -> bool:
	for f: Variant in l.flaques:
		if is_instance_valid(f) and (f as Liquides.Flaque).exces > 0.0005 and not (f as Liquides.Flaque).bords.is_empty():
			return true
	return false

func _signature(script: Script, nom: String) -> Dictionary:
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == nom:
			var noms := []
			for a: Dictionary in m["args"]:
				noms.append(a["name"])
			return {"args": noms, "defauts": (m["default_args"] as Array).size()}
	return {}

func _boite(pos: Vector3, taille: Vector3, surface := "pierre") -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	b.add_child(cs)
	if surface != "":
		b.set_meta("surface_liquide", surface)
	s.add_child(b)
	b.position = pos
	return b

## Le nœud repose sur une surface : un rayon vers le bas (le long de -normale) trouve le décor à moins de `tol` m.
func _pose(n3: Node3D, nrm := Vector3.UP, tol := 0.1) -> bool:
	var p := n3.global_position
	var q := PhysicsRayQueryParameters3D.create(p + nrm * 0.08, p - nrm * tol, 1)
	return not n3.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _vivants(a: Array) -> Array:
	return a.filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as Node).is_queued_for_deletion())

func _lancer() -> void:
	Sang.niveau_force = 2
	ok(Liquides.actif, "liquides actifs (sans --sans-liquides)")
	# ---- API sang inchangée
	var S: Script = load("res://scripts/combat/sang.gd")
	var attendu := {
		"giclee": ["n", "point", "direction", "intensite", "couleur", "traces", "sorte"],
		"jet": ["attache", "local", "couleur", "duree"],
		"flaque": ["n", "pos", "couleur", "taille", "croissance"],
		"trace": ["n", "pos", "normale", "direction", "taille", "couleur", "sorte", "croissance", "delai", "support"],
		"tacher_voisins": ["source", "point", "direction", "intensite", "couleur"],
		"eclats_matiere": ["n", "point", "direction", "intensite", "couleur"],
		"sol_sous": ["n", "pos", "haut", "bas"],
		"traversee": ["n", "entree", "sortie_pt", "direction", "intensite", "couleur"],
		"sortie": ["n", "point", "direction", "intensite", "couleur"],
		"trainee_corps": ["corps", "couleur", "duree"],
		"saigner": ["n", "point", "couleur", "duree"],
	}
	for nom: String in attendu:
		var sg := _signature(S, nom)
		var a: Array = attendu[nom]
		ok(not sg.is_empty() and sg["args"] == a, "API sang inchangée : Sang.%s(%s)" % [nom, ", ".join(a)])
	var G: Script = load("res://scripts/combat/gouttes_sang.gd")
	ok(_signature(G, "lacher")["args"] == ["n", "pos", "couleur", "vitesse", "tache"], "API inchangée : GouttesSang.lacher")
	ok(_signature(G, "lacher_balistique")["args"] == ["n", "pos", "couleur", "vitesse", "taille"], "API inchangée : GouttesSang.lacher_balistique")
	ok((_signature(load("res://scripts/casse_objets.gd"), "verser_liquide")["args"] as Array).slice(0, 4) == ["n", "centre", "dir", "rayon"], "API : CasseObjets.verser_liquide(n, centre, dir, rayon, …)")
	ok(not _signature(load("res://scripts/combat/sang_lame.gd"), "ensanglanter").is_empty() and not _signature(load("res://scripts/combat/sang_lame.gd"), "coup").is_empty(), "API inchangée : SangLame.coup / ensanglanter")
	# ---- sortes
	for nom: String in ["sang_humain", "sang_draugr", "sang_troll", "eau", "biere", "hydromel", "vin", "huile", "lait", "potion_soin", "potion_mana"]:
		var so := Liquides.sorte(nom)
		ok(so.has("visc") and so.has("absorbe") and so.has("seche") and so.has("frais"), "sorte %s : couleur, viscosité, absorption, séchage" % nom)
	ok(Liquides.sang_de(ProfilCible.pour("draugr").couleur_sang) == "sang_draugr" and Liquides.sang_de(ProfilCible.pour("bandit").couleur_sang) == "sang_humain", "sang du profil : draugr / humain")
	ok(Liquides.contenu("q_tonneau", "", "x", true).size() == 2 and Liquides.contenu("q_tonneau_pommes", "", "x", false).is_empty(), "contenu : tonneau liquide, tonneau de pommes sec")
	ok(Liquides.contenu("", "potion_soin", "p", false)[0] == "potion_soin", "contenu : potion de soin (sa couleur)")
	# ---- scène : sol de pierre, mur, étagère
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _frames(20)
	EffetsSol.dehors = false
	var sol := _boite(Vector3(0, -0.21, 0), Vector3(40, 0.5, 40))      # dessus à y = 0,04 (au-dessus du sol de la scène)
	var mur := _boite(Vector3(0, 1.5, -6.0), Vector3(8, 3, 0.4))      # face avant à z = -5,8
	var etagere := _boite(Vector3(4.0, 1.175, -3.0), Vector3(1.2, 0.05, 0.4), "bois")      # planche, dessus à y = 1,2
	await _frames(5)
	var l := Liquides.obtenir(s)
	ok(l != null and not l.is_processing(), "nœud Liquides : rien ne tourne au repos")

	# ---- 1. versements de toutes les hauteurs : rien ne reste en l'air
	var hauteurs := [0.6, 2.0, 8.0, 30.0]
	for k in hauteurs.size():
		Liquides.verser_contenant(s, Vector3(-8.0 + k * 3.0, hauteurs[k], 4.0), Vector3.ZERO, ["eau", "biere", "vin", "lait"][k], 6.0, 0.6)
	var t_calme := await _calme(2400)
	ok(t_calme >= 0, "versements de 0,6 à 30 m : tout est retombé (%d images)" % t_calme)
	var fl := _vivants(l.flaques)
	ok(fl.size() >= 4, "versements : des flaques au sol (%d)" % fl.size())
	ok(fl.all(func(f: Node3D) -> bool: return absf(f.global_position.y) < 0.08 and _pose(f)), "toutes les flaques reposent sur le sol (aucune en l'air)")
	ok(_vivants(l.taches).all(func(t: Node3D) -> bool: return _pose(t, (t as Node3D).global_transform.basis.y.normalized())), "toutes les taches reposent sur une surface")
	var d0: int = Liquides.stats["flaques"]
	Liquides.verser_contenant(s, Vector3(200.0, 900.0, 200.0), Vector3.ZERO, "biere", 4.0, 0.6)      # au-dessus du vide (hors du sol)
	await _calme(600)
	ok(GouttesSang.en_vol() == 0 and Liquides.stats["flaques"] == d0, "versé à 900 m au-dessus du vide : aucune goutte restée en l'air, aucune flaque (perdu dans le vide)")
	ok(GouttesSang.resolues > 0, "gouttes en fin de vie menées jusqu'au contact ou au vide (%d)" % GouttesSang.resolues)

	# ---- 2. flaque : horizontale seulement, jamais sur un mur
	var pm := Vector3(0.5, 1.6, -5.8)
	ok(Liquides.flaque(s, pm, Vector3(0, 0, 1), "eau", 2.0) == null, "flaque demandée sur un mur : refusée (le liquide coule)")
	ok(l.coulures.size() >= 1, "… une coulure part à la place")
	Liquides.verser_contenant(s, Vector3(-1.0, 1.4, -5.4), Vector3(0, 0, -2.5), "vin", 3.0, 0.5)      # lancé contre le mur
	await _calme(2400)
	fl = _vivants(l.flaques)
	ok(fl.all(func(f: Liquides.Flaque) -> bool: return f.nrm.y > Liquides.PLAT), "aucune flaque sur une surface pentue ou verticale (%d flaques)" % fl.size())
	var filets := _vivants(l.filets)
	var sur_mur := filets.filter(func(f: Node3D) -> bool: return absf(f.global_position.z - (-5.8)) < 0.05)
	ok(sur_mur.size() >= 1, "coulures sur le mur (%d segments)" % sur_mur.size())
	var descend := sur_mur.any(func(f: Node3D) -> bool: return f.global_transform.basis.x.normalized().y < -0.9 and f.global_transform.basis.x.length() > 0.05)
	ok(descend, "une coulure descend le mur (segment vertical de plus de 5 cm)")
	var pied := fl.any(func(f: Liquides.Flaque) -> bool: return f.liquide == "vin" and f.centre.z < -5.0) or _vivants(l.taches).any(func(t: Node3D) -> bool: return t.global_position.z < -5.2 and t.global_position.y < 0.1)
	ok(pied, "le vin qui a coulé finit au pied du mur")

	# ---- 3. étagère -> sol
	var e0: int = Liquides.stats["egouttures"]
	Liquides.verser_contenant(s, Vector3(4.0, 1.55, -3.0), Vector3.ZERO, "biere", 8.0, 0.55)
	await _calme(2400)
	fl = _vivants(l.flaques)
	var haut := fl.filter(func(f: Liquides.Flaque) -> bool: return absf(f.centre.y - 1.2) < 0.05)
	var bas := fl.filter(func(f: Liquides.Flaque) -> bool: return f.liquide == "biere" and f.centre.y < 0.05 and Vector2(f.centre.x - 4.0, f.centre.z + 3.0).length() < 1.6)
	ok(haut.size() >= 1, "étagère : une flaque sur la planche (%d)" % haut.size())
	ok(bas.size() >= 1, "étagère : le liquide a coulé jusqu'au sol sous elle (%d flaques)" % bas.size())
	ok(Liquides.stats["egouttures"] > e0, "étagère : le surplus s'égoutte par le bord (%d gouttes)" % (Liquides.stats["egouttures"] - e0))
	var deborde := false
	for f: Liquides.Flaque in haut:
		for k in Liquides.Flaque.DIRS:
			var a := TAU * k / Liquides.Flaque.DIRS
			var pt := f.global_transform * (Vector3(cos(a), 0, sin(a)) * f.portee[k])
			if absf(pt.x - 4.0) > 0.62 or absf(pt.z + 3.0) > 0.22:
				deborde = true
	ok(not deborde, "étagère : la flaque s'arrête au bord de la planche (ne déborde pas dans le vide)")

	# ---- 4. neige : absorption
	EffetsSol.forcer_neige = true
	var neige := _boite(Vector3(-10.0, -0.15, -10.0), Vector3(4, 0.5, 4), "")      # dessus à y = 0,1
	await _frames(3)
	ok(Liquides.surface({"position": Vector3(-10, 0.1, -10), "normal": Vector3.UP, "collider": neige}) == "neige", "surface enneigée reconnue")
	ok(Liquides.rayon_pour("eau", "neige", 3.0) < Liquides.rayon_pour("eau", "pierre", 3.0), "la neige boit : flaque plus petite que sur la pierre")
	var fn := Liquides.flaque(s, Vector3(-10, 0.1, -10), Vector3.UP, "sang_humain", 0.5) as Liquides.Flaque
	await _frames(2)
	var mn := fn.material_override as ShaderMaterial if fn != null else null
	ok(mn != null and float(mn.get_shader_parameter("neige")) == 1.0 and float(mn.get_shader_parameter("brille")) == 0.0, "sang sur la neige : tache diffuse, liseré dilué, aucun reflet")
	var fp := Liquides.flaque(s, Vector3(6.0, 0.04, 6.0), Vector3.UP, "sang_humain", 0.5) as Liquides.Flaque
	var mp := fp.material_override as ShaderMaterial if fp != null else null
	ok(mp != null and float(mp.get_shader_parameter("brille")) > 0.5, "sang sur la pierre : flaque brillante (%s, brille %s)" % [fp.surf if fp else "-", mp.get_shader_parameter("brille") if mp else "-"])
	var fe := Liquides.flaque(s, Vector3(6.0, 0.04, 9.0), Vector3.UP, "eau", 0.5) as Liquides.Flaque
	EffetsSol.forcer_neige = false
	# séchage différencié : l'eau s'efface avant le sang
	SangV3.vieillissement(Sang.gestion(s)).avancer(80.0)
	await _frames(3)
	ok(not is_instance_valid(fe) and is_instance_valid(fp), "séchage : l'eau a disparu, le sang est encore là")
	ok(is_instance_valid(fp) and float(fp.get_instance_shader_parameter("seche")) >= 1.0, "séchage : le sang a séché (foncé, mat)")

	# ---- 5. pools plafonnés
	for k in 60:
		Liquides.flaque(s, Vector3(-15.0 + (k % 10) * 1.6, 0, 12.0 + int(k / 10) * 1.6), Vector3.UP, ["eau", "biere", "vin"][k % 3], 0.4)
	for k in 120:
		l._tache(s, Vector3(-15.0 + k * 0.1, 0, -12.0), Vector3.UP, Vector3.DOWN, "eau", 1.0, 1.0, false, "pierre", Color.BLACK, null)
	for k in 40:
		l.coulure(s, Vector3(-3.0 + k * 0.15, 2.5, -5.8), Vector3(0, 0, 1), "eau", 6.0)
	for k in 400:
		GouttesSang.lacher_liquide(s, Vector3(randf_range(-5, 5), randf_range(2, 6), randf_range(-3, 3)), Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2)), "eau", 2.0, 1.0)
	await _frames(2)
	ok(_vivants(l.flaques).size() <= Liquides.MAX_FLAQUES, "flaques plafonnées (%d ≤ %d)" % [_vivants(l.flaques).size(), Liquides.MAX_FLAQUES])
	ok(_vivants(l.taches).size() <= Liquides.MAX_TACHES, "taches plafonnées (%d ≤ %d)" % [_vivants(l.taches).size(), Liquides.MAX_TACHES])
	ok(l.coulures.size() <= Liquides.MAX_COULURES, "coulures plafonnées (%d ≤ %d)" % [l.coulures.size(), Liquides.MAX_COULURES])
	ok(GouttesSang.en_vol() <= GouttesSang.MAX_V3, "gouttes en vol plafonnées (%d ≤ %d)" % [GouttesSang.en_vol(), GouttesSang.MAX_V3])
	await _calme(2400)
	ok(_vivants(l.filets).size() <= Liquides.MAX_FILETS, "segments de coulure plafonnés (%d ≤ %d)" % [_vivants(l.filets).size(), Liquides.MAX_FILETS])
	ok(_vivants(l.flaques).all(func(f: Node3D) -> bool: return _pose(f)), "après la pluie de gouttes : toutes les flaques au sol")
	await _frames(30)
	ok(not l.is_processing() and GouttesSang.en_vol() == 0, "au repos : ni le nœud Liquides ni les gouttes ne tournent")

	# ---- 6. sang : giclée contre le mur -> coulure qui descend ; gore à 0 : rien
	var c0: int = Liquides.stats["coulures"]
	Sang.giclee(s.joueur, Vector3(0, 1.4, -4.6), Vector3(0, 0, -1), 2.5, ProfilCible.pour("bandit").couleur_sang)
	await _calme(1200)
	ok(Liquides.stats["coulures"] > c0, "sang sur le mur : de vraies coulures (%d)" % (Liquides.stats["coulures"] - c0))
	Sang.niveau_force = 0
	var g1 := GouttesSang.lachees
	GouttesSang.lacher_liquide(s, Vector3(0, 2, 0), Vector3.ZERO, "sang_humain", 2.0)
	ok(GouttesSang.lachees == g1, "gore à 0 : aucune goutte de sang (les autres liquides restent)")
	Sang.niveau_force = 2

	# ---- 7. --sans-liquides : l'ancienne flaque de CasseObjets
	Liquides.actif = false
	var n_av := get_nodes_in_group("flaques").size()
	CasseObjets.verser_liquide(s, Vector3(8.0, 0.6, 8.0), Vector3.UP, 0.8)
	await _frames(60)
	ok(get_nodes_in_group("flaques").filter(func(f: Node) -> bool: return f is CasseObjets.Flaque).size() >= 1 and get_nodes_in_group("flaques").size() > n_av, "--sans-liquides : ancienne flaque (CasseObjets.Flaque)")
	Liquides.actif = true

	print("cout liquides cumulé : %.1f ms ; %s" % [Liquides.cout_us / 1000.0, str(Liquides.stats)])
	Sang.niveau_force = -1
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
