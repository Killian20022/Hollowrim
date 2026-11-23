extends SceneTree
## Test sans fenêtre du RAGDOLL DE PROJECTION + RELEVÉ des sorts de l'esprit (scripts/magie/ragdoll_esprit.gd ; docs/MAGIE.md) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_ragdoll_esprit.gd -- --nouvelle
## Répulsion -> ragdoll -> relevé capturé -> IA en moins de 4 s ; dos / ventre -> bon clip ; pas de saut au passage ragdoll -> clip ;
## pieds au sol ; mort en vol = cadavre ; pas de traversée du sol ni du mur ; plafond de ragdolls ; lévitation lâchée et lancée ;
## relâchement de l'attraction ; interrupteur (vol cinématique d'avant).

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const SURVEILLES := ["pelvis", "Head", "foot_l", "foot_r", "hand_l", "hand_r"]

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var es: SortsEsprit
var rag: RagdollEsprit
## traversées détectées (os qui passe à travers le décor d'une image à l'autre)
var _traversees: Array = []
var _prec := {}
## pose AFFICHÉE du bassin (après modificateurs) par ennemi : instance_id -> [Vector3 image précédente, saut max au relevé]
var _affiche := {}

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in maxi(1, roundi(t / DT)):
		mains.avancer(DT)
		await physics_frame
		_surveiller()

func _viser_point(c: Vector3) -> void:
	for k in 3:
		var o: Vector3 = j.camera.global_position
		var d := c - o
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
	es.tout_lacher()
	es.journal.clear()
	rag.journal.clear()
	magie.recharges.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	_traversees.clear()
	_prec.clear()
	await _sim(0.4)

func _draugr(p: Vector3, type := "squelette") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "rd_%s_%d" % [type, randi() % 100000]
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	sq.skeleton_updated.connect(_sur_squelette.bind(d, sq))
	return d

## Pose affichée du bassin (le signal part après les modificateurs : ragdoll, fondu) ; saut d'une image à l'autre pendant le relevé.
func _sur_squelette(d: CharacterBody3D, sq: Skeleton3D) -> void:
	if not is_instance_valid(d):
		return
	var p := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("pelvis")).origin
	var id := d.get_instance_id()
	var a: Array = _affiche.get(id, [p, 0.0, false, 0])
	if rag.phase(d) == "releve" or bool(a[2]):
		a[1] = maxf(float(a[1]), (p - (a[0] as Vector3)).length())
		if OS.get_cmdline_user_args().has("--debug-saut") and (p - (a[0] as Vector3)).length() > 0.09:
			a[3] = int(a[3]) + 1
			print("   SAUT %s phase=%s p=%s prec=%s t=%s anim=%s" % [d.name, rag.phase(d), p, a[0], rag.corps[id]["t"] if rag.contient(d) else -1, d.anim.current_animation])
	a[2] = rag.phase(d) == "releve"
	a[0] = p
	_affiche[id] = a

## Os physiques des corps en vol : aucun ne doit passer à travers le décor (rayon de sa position précédente à l'actuelle).
func _surveiller() -> void:
	for id in rag.corps:
		var fi: Dictionary = rag.corps[id]
		if not is_instance_valid(fi["e"]) or String(fi["phase"]) != "vol":
			continue
		var rd: Ragdoll = fi["rd"]
		for nom in SURVEILLES:
			var pb := rd.os.get(nom) as PhysicalBone3D
			if pb == null:
				continue
			var cle := "%d_%s" % [id, nom]
			var p := pb.global_position
			if _prec.has(cle):
				var q := PhysicsRayQueryParameters3D.create(_prec[cle], p, 1)
				q.exclude = [j.get_rid()]
				var r := j.get_world_3d().direct_space_state.intersect_ray(q)
				# os passé DERRIÈRE la surface de plus de 8 cm (frôler la face, rayon de l'os compris, n'est pas une traversée)
				if not r.is_empty() and not (r["collider"] is CharacterBody3D) and ((r["position"] as Vector3) - p).dot(r["normal"]) > 0.08:
					_traversees.append("%s %s %s -> %s (%s)" % [(fi["e"] as Node).name, nom, _prec[cle], p, (r["collider"] as Node).name])
			if p.y < -0.05:
				_traversees.append("%s %s sous le sol y=%.2f" % [(fi["e"] as Node).name, nom, p.y])
			_prec[cle] = p

func _etat_nom(e: Node) -> String:
	var cst: Dictionary = e.get_script().get_script_constant_map()
	for k in cst:
		if cst[k] is int and int(cst[k]) == int(e.get("etat")) and k in ["TRAQUE", "ATTAQUE", "CHUTE", "TITUBE", "MORT", "GARDE", "ETOURDI"]:
			return k
	return str(e.get("etat"))

func _onde(tenue: float) -> void:
	magie.appuyer("gauche")
	await _sim(tenue)
	magie.relacher("gauche")
	await _sim(0.05)

func _fin(e: Node) -> Dictionary:
	for x in rag.journal:
		if x.get("e") == e and x.has("fini"):
			return x
	return {}

func _releve(e: Node) -> Dictionary:
	for x in rag.journal:
		if x.get("e") == e and x.has("clip"):
			return x
	return {}

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	es = magie.esprit
	rag = es.rag if es != null else null
	_verif(RagdollEsprit.actif and rag != null, "ragdoll de projection installé (SortsEsprit.rag)")
	if rag == null:
		quit(1)
		return
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	await _repulsion()
	await _dos_ventre()
	await _mort_en_vol()
	await _plafond()
	await _levitation()
	await _attraction()
	await _interrupteur()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ répulsion : vol, choc, relevé, IA

func _repulsion() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 1.0), 90.0)
	var d := _draugr(Vector3(-1.4, 0.0, 1.0), "squelette")
	await _sim(0.6)
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	var vie0: float = d.vie
	var t0 := Time.get_ticks_msec()
	await _onde(1.5)
	var vu_vol := false
	var y_max := -1.0
	var t_ia := -1.0
	var t := 0.0
	while t < 6.0:
		await _sim(DT)
		t += DT
		if rag.en_vol(d):
			vu_vol = true
			y_max = maxf(y_max, (rag.corps[d.get_instance_id()]["rd"] as Ragdoll).os["pelvis"].global_position.y)
		if vu_vol and t_ia < 0.0 and not rag.contient(d) and d.is_physics_processing() and _etat_nom(d) in ["TRAQUE", "ATTAQUE"]:
			t_ia = t
	var rl := _releve(d)
	print("   relevé : ", rl, "  fin : ", _fin(d))
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	_verif(vu_vol and y_max > 0.9, "Répulsion chargée : le squelette part en ragdoll (bassin jusqu'à %.2f m)" % y_max)
	var chocs := es.journal.filter(func(x): return String(x[1]).begins_with("choc"))
	_verif(not chocs.is_empty() and d.vie < vie0, "choc du ragdoll contre le mur : %s ; %.0f -> %.0f PV" % [chocs[0][1] if not chocs.is_empty() else "-", vie0, d.vie])
	_verif(t_ia > 0.0 and t_ia < 4.0, "il se relève et reprend l'IA en %.2f s (< 4 s depuis l'onde)" % t_ia)
	_verif(not rl.is_empty() and String(rl["clip"]) in [RagdollEsprit.CLIP_DOS, RagdollEsprit.CLIP_VENTRE], "relevé capturé joué : %s" % rl.get("clip", "-"))
	var a: Array = _affiche.get(d.get_instance_id(), [Vector3.ZERO, 99.0])
	_verif(float(a[1]) < 0.12, "pas de saut au passage ragdoll -> relevé (bassin affiché : %.3f m par image au plus)" % float(a[1]))
	_verif(_traversees.is_empty(), "aucun os à travers le sol ou le mur (%s)" % str(_traversees.slice(0, 3)))
	# debout : pieds au sol, capsule sur le sol, hors du mur
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	var pied := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("foot_l")).origin).y
	_verif(absf(d.global_position.y) < 0.1 and pied < 0.3 and pied > -0.05, "debout : capsule au sol (y=%.2f), pied à %.2f m" % [d.global_position.y, pied])
	_verif(d.global_position.x > -3.05 and d.collision_layer != 0, "capsule rendue, du bon côté du mur (x=%.2f)" % d.global_position.x)
	d.queue_free()

# ------------------------------------------------------------------ dos / ventre

func _dos_ventre() -> void:
	for cas in [["dos", -PI * 0.5, RagdollEsprit.CLIP_DOS], ["ventre", PI * 0.5, RagdollEsprit.CLIP_VENTRE]]:
		await _reset()
		s.placer_joueur(Vector3(6, 0, 6), 0.0)
		var d := _draugr(Vector3(8.0, 0.0, 3.0), "squelette")
		await _sim(0.3)
		d.rotation.x = float(cas[1])   # couché d'avance (devant vers le haut : dos ; vers le bas : ventre), lâché de 0,35 m
		d.global_position.y = 0.35
		await _sim(DT * 2)
		_verif(rag.prendre(d, Vector3(0.0, 0.3, 0.0), es._sort("repulsion")), "%s : ragdoll pris" % cas[0])
		await _sim(4.5)
		var rl := _releve(d)
		_verif(String(rl.get("clip", "")) == String(cas[2]) and bool(rl.get("ventre", false)) == (cas[0] == "ventre"),
			"couché sur le %s : relevé %s (attendu %s)" % [cas[0], rl.get("clip", "-"), cas[2]])
		_verif(not _fin(d).is_empty() and absf(d.rotation.x) < 0.01 and d.is_physics_processing(), "%s : debout, droit, IA rendue (%.2f s)" % [cas[0], float(_fin(d).get("t_total", -1.0))])
		var a: Array = _affiche.get(d.get_instance_id(), [Vector3.ZERO, 99.0])
		_verif(float(a[1]) < 0.12, "%s : pas de saut au relevé (%.3f m par image au plus)" % [cas[0], float(a[1])])
		d.queue_free()

# ------------------------------------------------------------------ mort en vol

func _mort_en_vol() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 1.0), 90.0)
	var d := _draugr(Vector3(-1.4, 0.0, 1.0), "squelette")
	await _sim(0.4)
	d.vie = 3.0
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	await _onde(1.5)
	await _sim(4.5)
	var rd := Ragdoll.equiper(d.modele) as Ragdoll
	var morts := rag.journal.filter(func(x): return x.get("e") == d and x.has("mort"))
	_verif(_etat_nom(d) == "MORT" and not rag.contient(d) and _releve(d).is_empty(), "tué pendant le vol : il ne se relève pas (%s, %s)" % [_etat_nom(d), str(morts)])
	_verif(rd != null and rd.actif and not (d.anim as AnimationPlayer).active, "le ragdoll reste : c'est le cadavre")
	d.queue_free()

# ------------------------------------------------------------------ plafond

func _plafond() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 1.0), 90.0)
	var es_l: Array = []
	for k in 8:
		var ang := deg_to_rad(-30.0 + 60.0 * k / 7.0)
		es_l.append(_draugr(Vector3(-cos(ang) * 2.4, 0.0, 1.0 + sin(ang) * 2.4), "squelette"))
	await _sim(0.5)
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	await _onde(1.5)
	var maxi_rd := 0
	var cine := 0
	for k in 20:
		await _sim(DT)
		maxi_rd = maxi(maxi_rd, rag.nb_en_vol())
		cine = maxi(cine, es.vols.size())
	var refus := es.journal.filter(func(x): return String(x[1]).contains("plafond atteint (%d)" % RagdollEsprit.PLAFOND)).size()
	_verif(maxi_rd <= RagdollEsprit.PLAFOND and (maxi_rd >= 5 or refus > 0), "plafond : %d ragdolls en vol au plus vus, jamais plus de %d (%d refus au plafond)" % [maxi_rd, RagdollEsprit.PLAFOND, refus])
	var cine_j := es.journal.filter(func(x): return String(x[1]).contains("plafond atteint")).size()
	_verif(cine >= 1 or cine_j >= 1, "au-delà du plafond : vol cinématique (%d refus notés)" % cine_j)
	await _sim(5.0)
	var debout := 0
	for e in es_l:
		if is_instance_valid(e) and e.is_physics_processing() and not rag.contient(e):
			debout += 1
	_verif(debout == es_l.size(), "les %d se sont relevés" % debout)
	for e in es_l:
		e.queue_free()

# ------------------------------------------------------------------ lévitation (lâchée, lancée)

func _levitation() -> void:
	for mode in ["lachee", "lancee"]:
		await _reset()
		magie.equiper("gauche", "levitation")
		s.placer_joueur(Vector3(0, 0, 8.0), 0.0)
		var d := _draugr(Vector3(0.0, 0.0, 4.5), "squelette")
		await _sim(0.4)
		await _viser_point(Elements._centre(d))
		magie.appuyer("gauche")
		var tenu := false
		for k in 70:
			await _sim(DT)
			tenu = tenu or es.tient("gauche")
		if mode == "lachee":
			es.lacher("gauche")   # appui bref (relâché avant TENUE_MIN) : il retombe
			magie._couper("gauche", false)
			magie.inc["gauche"].changer(Incantation.REPOS)
			magie.inc["gauche"].tenu = false
		else:
			await _viser_point(Vector3(-3.0, 1.0, 1.0))
			magie.relacher("gauche")
		var vu := false
		for k in 20:
			await _sim(DT)
			vu = vu or rag.en_vol(d)
		await _sim(4.5)
		_verif(tenu and vu and not _fin(d).is_empty(), "lévitation %s : ragdoll puis relevé (%s, %.2f s)" % [mode, _releve(d).get("clip", "-"), float(_fin(d).get("t_total", -1.0))])
		_verif(_traversees.is_empty(), "lévitation %s : aucune traversée (%s)" % [mode, str(_traversees.slice(0, 2))])
		d.queue_free()

# ------------------------------------------------------------------ attraction (relâchement)

func _attraction() -> void:
	await _reset()
	magie.equiper("gauche", "attraction")
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(1.0, 0.0, 3.0), "squelette")
	d.vie_max = 400.0   # on teste le relevé, pas la mort au choc
	d.vie = 400.0
	await _sim(0.4)
	await _viser_point(Vector3(0.0, 1.4, 3.5))
	magie.appuyer("gauche")
	await _sim(0.1)
	magie.relacher("gauche")
	var vu := false
	for k in 600:
		await _sim(DT)
		vu = vu or rag.en_vol(d)
		if vu and not _fin(d).is_empty():
			break
	await _sim(0.5)
	if not vu or _fin(d).is_empty():
		print("   phase ", rag.phase(d), " ", rag.journal)
		for x in es.journal:
			print("   ES %.2f %s" % [x[0], x[1]])
	_verif(vu and not _fin(d).is_empty(), "relâchement de l'attraction : ragdoll puis relevé (%s)" % _releve(d).get("clip", "-"))
	d.queue_free()

# ------------------------------------------------------------------ interrupteur

func _interrupteur() -> void:
	await _reset()
	RagdollEsprit.actif = false
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 1.0), 90.0)
	var d := _draugr(Vector3(-1.4, 0.0, 1.0), "squelette")
	await _sim(0.4)
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	await _onde(1.5)
	var cine := false
	for k in 20:
		await _sim(DT)
		cine = cine or es.vols.has(d.get_instance_id())
	_verif(cine and not rag.contient(d), "--sans-ragdoll-esprit : vol cinématique d'avant")
	RagdollEsprit.actif = true
	await _sim(3.0)
	d.queue_free()
