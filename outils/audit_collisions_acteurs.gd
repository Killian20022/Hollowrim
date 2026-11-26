extends SceneTree
## AUDIT DES COLLISIONS DES ACTEURS (2026-11-26, bugs/collisions_acteurs) : en VRAI jeu (scenes/foret_test.tscn, nouvelle partie),
## fait vivre PNJ, gardes, ennemis et animaux N secondes et relève à chaque pas d'échantillonnage (2 images de physique) :
##   traverse   capsule (rétrécie : 75 % du rayon, 25 cm de marge au sol) qui recoupe une géométrie statique du calque 1 ;
##   passe_mur  segment entre deux échantillons (à 0,9 m du sol) coupé par une paroi (normale |y| < 0,5) : franchissement d'un mur ;
##   teleport   saut > 1,5 m entre deux échantillons d'un acteur vivant (avec « mur » si une paroi est franchie) ;
##   fantome    vivant visible qui se déplace (> 0,3 m/s) sans collision (calque/masque 0 ou forme coupée) ;
##   sous_sol   acteur sous le sol (rien sous ses pieds sur 2,5 m et un sol au-dessus de lui ; dehors : sous le relief de 0,5 m) ;
##   coince     animation de marche/course jouée alors que la vitesse RÉELLE est < 0,1 m/s (fenêtre de 1 s) : durée de l'épisode ;
##   os_mur     os d'un cadavre (PhysicalBone3D / morceau) séparé du centre du corps par une paroi, ou recoupant le décor ;
##   os_sous_sol os d'un cadavre sous le sol.
## Le joueur est invulnérable et se déplace d'un point à l'autre du lieu toutes les `--saut` s : les ennemis le poursuivent et
## doivent contourner le décor. Il n'y a pas de navmesh dans le jeu (pilotage direct + rayons d'évitement) : le critère « hors
## navmesh » est remplacé par sous_sol / passe_mur.
##
##   godot --headless --fixed-fps 60 --path . --script res://outils/audit_collisions_acteurs.gd -- --nouvelle --lieu=village
##        [--duree=120] [--saut=9] [--sortie=<dossier>] [--etiquette=avant|apres]
##        [--captures=N]       (avec fenêtre) image des N premiers épisodes graves, caméra à 4 m de l'acteur -> <sortie>/cas_<etiquette>_<lieu>_K.png
##        [--film=<classe>,<s>] (avec fenêtre) suit en 3e personne le 1er acteur de cette classe qui marche -> <sortie>/film_<etiquette>_<lieu>/
## Lieux : village (midi puis soir : retours à la maison), foret (draugrs de surface, faune), crypte, grotte (repaire des bandits).
## Sortie : <sortie>/audit_<etiquette>_<lieu>.csv (un épisode par ligne) et .json (totaux par type d'acteur et pires cas).
## Code de sortie : nombre d'épisodes graves (traverse/passe_mur/teleport mur/fantome/sous_sol/coince > 2 s/os_*).

const SCENE := "res://scenes/foret_test.tscn"
const PAS := 2
const LOCO := ["Walk", "Jog", "Run", "Sprint", "Trot", "Gallop", "Course", "Marche", "Crouch_Fwd", "Walk_Fwd"]

var args := {}
var lieu := "village"
var m: Node3D
var j: CharacterBody3D
var esp: PhysicsDirectSpaceState3D
var acteurs := {}        # instance_id -> fiche
var episodes: Array = [] # {lieu, classe, ident, cat, t, x, y, z, duree, detail}
var t_sim := 0.0
var points_tour: Array = []
var _i_tour := 0
var _exclus: Array[RID] = []
var _q_forme := PhysicsShapeQueryParameters3D.new()
var _capsule := CapsuleShape3D.new()
var _ips: Array = []
var _cam: Camera3D
var _captures_max := 0
var _captures: Array = []      # [{p, nom}] à prendre
var _n_captures := 0
var _film_classe := ""
var _film_duree := 0.0
var _film_suivi: Node3D
var _film_t := 0.0
var _film_n := 0

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	lieu = String(args.get("lieu", "village"))
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

func _go() -> void:
	m = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while (m.village == null or not m.village.prets) and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame
	await _attendre(20)
	j = m.joueur
	j.vie_max = 1.0e7
	j.vie = j.vie_max
	esp = root.get_world_3d().direct_space_state
	var duree := float(args.get("duree", "120"))
	match lieu:
		"village":
			m.cycle.heure = 12.0
			points_tour = [Vector3(44, 0, 40), Vector3(30, 0, 52), Vector3(58, 0, 30), Vector3(40, 0, 22), Vector3(52, 0, 56)]
		"foret":
			m.cycle.heure = 22.0      # nuit : loups ; les draugrs de surface sont dehors
			var c: Vector3 = (m.get_script() as Script).get_script_constant_map()["CERCLE"]
			points_tour = [Vector3(c.x + 6, 0, c.z + 6), Vector3(-16, 0, -15), Vector3(c.x - 6, 0, c.z - 2), Vector3(-4, 0, -28), Vector3(c.x + 12, 0, c.z + 12)]
		"crypte":
			m.tertre._passer(true)
			var tc := Time.get_ticks_msec()
			while not bool(m.tertre.get("dedans")) and Time.get_ticks_msec() - tc < 90000:
				await physics_frame
			await _attendre(60)
			points_tour = []
		"grotte":
			var ga: Node3D = m.grotte_acces
			ga.attendre_exterieur()
			var g: Node3D = ga.obtenir()
			m._aller_grotte("4,0,0,0")
			await _attendre(60)
			for id: String in g.ordre:
				var L: float = g.longueur(id)
				var s := 2.0
				while s < L - 1.0:
					points_tour.append(g.monde_sol(s, 0.0, id))
					s += 7.0
		_:
			print("lieu inconnu : ", lieu)
			quit(2)
			return
	if lieu in ["village", "foret"]:
		for k in points_tour.size():
			var p: Vector3 = points_tour[k]
			points_tour[k] = Vector3(p.x, m.hauteur(p.x, p.z) + 0.1, p.z)
	print("AUDIT %s : chargé en %.1f s, %d points de passage du joueur" % [lieu, (Time.get_ticks_msec() - t0) / 1000.0, points_tour.size()])
	_captures_max = int(args.get("captures", "0"))
	if args.has("film"):
		var fa := String(args["film"]).split(",")
		_film_classe = fa[0]
		_film_duree = float(fa[1]) if fa.size() > 1 else 10.0
	if _captures_max > 0 or _film_classe != "":
		_cam = Camera3D.new()
		_cam.fov = 70.0
		m.add_child(_cam)
	var saut := float(args.get("saut", "9"))
	var prochain := 0.0
	var n := 0
	var t_ips := Time.get_ticks_usec()
	while t_sim < duree:
		if lieu == "village" and t_sim >= duree * 0.5 and m.cycle.heure < 18.0:
			m.cycle.heure = 18.6     # soir : chacun rentre chez lui (routes les plus longues du village)
		if t_sim >= prochain:
			prochain = t_sim + saut
			_deplacer_joueur()
		j.vie = j.vie_max
		if "mort" in j and j.mort:
			j.mort = false
		await physics_frame
		n += 1
		t_sim += 1.0 / 60.0
		if n % PAS == 0:
			_echantillonner()
			if _cam != null:
				await _images()
		if n % 60 == 0:
			var u := Time.get_ticks_usec()
			_ips.append(60.0 / maxf((u - t_ips) / 1.0e6, 1e-6))
			t_ips = u
		if n % 1800 == 0:
			print("  t=%.0f s, %d acteurs suivis, %d épisodes" % [t_sim, acteurs.size(), episodes.size()])
	_clore()
	_ecrire()

## Le joueur saute d'un point de passage à l'autre (crypte : vers un ennemi vivant au hasard) ; il reste dehors du chemin des PNJ.
func _deplacer_joueur() -> void:
	var cible := Vector3.INF
	if lieu == "crypte" or (lieu == "grotte" and _i_tour % 2 == 1):
		var vivants: Array = []
		for f: Dictionary in acteurs.values():
			var a: Node3D = f["n"]
			if is_instance_valid(a) and not f["mort"] and a.is_inside_tree():
				vivants.append(a)
		if not vivants.is_empty():
			var a: Node3D = vivants[randi() % vivants.size()]
			var b := a.global_transform.basis.z
			cible = a.global_position + Vector3(b.x, 0, b.z).normalized() * 7.0 + Vector3(0, 0.3, 0)
			var r := esp.intersect_ray(PhysicsRayQueryParameters3D.create(a.global_position + Vector3(0, 1, 0), cible + Vector3(0, 0.7, 0)))
			if not r.is_empty():
				cible = a.global_position.lerp(cible, 0.3)
	if cible == Vector3.INF and not points_tour.is_empty():
		cible = points_tour[_i_tour % points_tour.size()]
	_i_tour += 1
	if cible != Vector3.INF:
		j.global_position = cible
		j.velocity = Vector3.ZERO

func _classe(a: Node) -> String:
	var s: Script = a.get_script()
	var nom := s.resource_path.get_file().get_basename() if s != null else a.get_class()
	for k in ["type", "espece"]:
		var v = a.get(k)
		if v is String and v != "":
			return "%s:%s" % [nom, v]
	return nom

func _acteurs_du_monde() -> Array:
	var r: Array = []
	for n: Node in m.find_children("*", "CharacterBody3D", true, false):
		if n == j or n.is_in_group("joueur_local") or not (n as Node3D).is_inside_tree():
			continue
		var s: Script = n.get_script()
		if s == null:
			continue
		var f := s.resource_path.get_file()
		if f in ["joueur.gd", "avatar_distant.gd", "proto_avatar.gd"]:
			continue
		r.append(n)
	return r

func _ident(a: Node) -> String:
	var i = a.get("ident")
	if i is String and i != "":
		return i
	var d = a.get("donnees")
	if d is Dictionary and (d as Dictionary).has("id"):
		return String(d["id"])
	return String(a.name)

func _forme(a: CollisionObject3D) -> CollisionShape3D:
	for c in a.get_children():
		if c is CollisionShape3D:
			return c
	return null

func _mort(a: Node) -> bool:
	if a.has_method("vivant"):
		return not a.vivant()
	return false

func _anim(a: Node) -> AnimationPlayer:
	var p = a.get("anim")
	if p is AnimationPlayer:
		return p
	return null

func _loco(a: Node) -> bool:
	var p := _anim(a)
	if p == null or not p.is_playing():
		return false
	var c := String(p.current_animation)
	for k: String in LOCO:
		if c.contains(k):
			return true
	return false

func _visible(a: Node3D) -> bool:
	return a.is_visible_in_tree() and a.process_mode != Node.PROCESS_MODE_DISABLED

func _echantillonner() -> void:
	_exclus.clear()
	var liste := _acteurs_du_monde()
	for a: CharacterBody3D in liste:
		_exclus.append(a.get_rid())
	_exclus.append(j.get_rid())
	for a: CharacterBody3D in liste:
		var id := a.get_instance_id()
		var p := a.global_position
		if not acteurs.has(id):
			acteurs[id] = {"n": a, "classe": _classe(a), "ident": _ident(a),
				"prec": p, "hist": [], "coince": 0.0, "ep": {}, "mort": false, "p_mort": p, "os_vus": {}, "t_vu": t_sim}
			continue
		var f: Dictionary = acteurs[id]
		var dt := float(PAS) / 60.0
		if _mort(a):
			if not f["mort"]:
				f["mort"] = true
				f["p_mort"] = f["prec"]
				f["t_mort"] = t_sim
			if int(t_sim * 30.0) % 5 == 0:
				_os(a, f)
			f["prec"] = p
			continue
		var vis := _visible(a)
		var d := p - (f["prec"] as Vector3)
		var dh := Vector2(d.x, d.z).length()
		var cs := _forme(a)
		var sans_col: bool = a.collision_layer == 0 or a.collision_mask == 0 or cs == null or cs.disabled
		# saut / téléportation
		if vis and dh > 1.5:
			var mur := _paroi_entre(f["prec"], p, a)
			var vu := _vu(f["prec"]) or _vu(p)
			_noter(f, "teleport" if vu else "teleport_hors_vue", p, 0.0, "%.1f m%s etat %s" % [dh, " a travers un mur" if mur else "", str(a.get("etat"))], mur and vu)
		elif vis and dh > 0.02 and not sans_col:
			if _paroi_entre(f["prec"], p, a):
				_noter(f, "passe_mur", p, 0.0, "%.2f m" % dh, true)
		# vitesse réelle sur 1 s
		var hist: Array = f["hist"]
		hist.append([t_sim, p])
		while hist.size() > 2 and t_sim - float(hist[0][0]) > 1.0:
			hist.pop_front()
		var v_reelle := 0.0
		if hist.size() >= 2 and t_sim - float(hist[0][0]) > 0.5:
			var q0: Vector3 = hist[0][1]
			v_reelle = Vector2(p.x - q0.x, p.z - q0.z).length() / (t_sim - float(hist[0][0]))
		if vis and _loco(a) and v_reelle < 0.1 and t_sim - float(f["t_vu"]) > 2.0:
			f["coince"] = float(f["coince"]) + dt
		else:
			if float(f["coince"]) > 1.0:
				_noter(f, "coince", p, float(f["coince"]), String(_anim(a).current_animation) if _anim(a) != null else "", float(f["coince"]) > 2.0)
			f["coince"] = 0.0
		# fantôme
		if vis and sans_col and v_reelle > 0.3 and dh < 1.5:
			_episode_continu(f, "fantome", p, dt, "calque %d masque %d" % [a.collision_layer, a.collision_mask])
		else:
			_fin_continu(f, "fantome")
		# capsule dans le décor
		if vis and not sans_col and cs.shape is CapsuleShape3D:
			var c0 := cs.shape as CapsuleShape3D
			_capsule.radius = c0.radius * 0.75
			_capsule.height = maxf(c0.height - 0.5, _capsule.radius * 2.0 + 0.01)
			_q_forme.shape = _capsule
			_q_forme.transform = Transform3D(cs.global_transform.basis.orthonormalized(), cs.global_transform.origin + Vector3(0, 0.1, 0))
			_q_forme.collision_mask = 1
			_q_forme.exclude = _exclus
			var hits := esp.intersect_shape(_q_forme, 4)
			var dur := false
			var quoi := ""
			for h in hits:
				var o: Object = h["collider"]
				if o is CharacterBody3D or o is PhysicalBone3D:
					continue
				if o is RigidBody3D and not (o as RigidBody3D).freeze:
					continue      # objet en vol (TK, poussé) : ce n'est pas le décor
				dur = true
				quoi = String((o as Node).name) if o is Node else str(o)
				break
			if dur:
				_episode_continu(f, "traverse", p, dt, quoi)
			else:
				_fin_continu(f, "traverse")
			# objets franchissables (calque 64 : urnes, tonneaux, chaises) : ils ne bloquent pas, mais un acteur ne doit pas les traverser
			_q_forme.collision_mask = Cassable.CALQUE
			var dans_objet := ""
			for h in esp.intersect_shape(_q_forme, 2):
				var o2: Object = h["collider"]
				if o2 is Node and not (o2 is CharacterBody3D) and not (o2 is PhysicalBone3D):
					dans_objet = String((o2 as Node).name)
					break
			if dans_objet != "":
				_episode_continu(f, "traverse_objet", p, dt, dans_objet)
			else:
				_fin_continu(f, "traverse_objet")
		# sous le sol
		if vis and _sous_sol(p, a):
			_episode_continu(f, "sous_sol", p, dt, "y=%.2f" % p.y)
		else:
			_fin_continu(f, "sous_sol")
		f["prec"] = p

## Vu par le joueur : à moins de 45 m et dans le champ de sa caméra.
func _vu(p: Vector3) -> bool:
	if p.distance_to(j.global_position) > 45.0:
		return false
	var cam: Camera3D = j.get("camera")
	if cam == null:
		return true
	return cam.is_position_in_frustum(p + Vector3(0, 1, 0))

func _paroi_entre(a0: Vector3, a1: Vector3, a: Node) -> bool:
	var h := Vector3(0, 0.9 * float(a.get("taille") if a.get("taille") != null else 1.0), 0)
	var q := PhysicsRayQueryParameters3D.create(a0 + h, a1 + h)
	q.exclude = _exclus
	q.collision_mask = 1
	q.hit_back_faces = true
	var r := esp.intersect_ray(q)
	if r.is_empty():
		return false
	var o: Object = r["collider"]
	if o is RigidBody3D and not (o as RigidBody3D).freeze:
		return false
	return absf((r["normal"] as Vector3).y) < 0.5

func _sous_sol(p: Vector3, _a: Node) -> bool:
	if lieu in ["village", "foret"] and not bool(m.tertre.get("dedans")) and m.get("grotte") == null:
		if p.y < m.hauteur(p.x, p.z) - 0.6:
			var r0 := esp.intersect_ray(_rayon(p + Vector3(0, 0.4, 0), p + Vector3(0, -2.5, 0)))
			return r0.is_empty()
		return false
	var r := esp.intersect_ray(_rayon(p + Vector3(0, 0.4, 0), p + Vector3(0, -2.5, 0)))
	if not r.is_empty():
		return false
	var h := esp.intersect_ray(_rayon(p + Vector3(0, 0.2, 0), p + Vector3(0, 30, 0)))
	return not h.is_empty()

func _rayon(de: Vector3, vers: Vector3) -> PhysicsRayQueryParameters3D:
	var q := PhysicsRayQueryParameters3D.create(de, vers)
	q.exclude = _exclus
	q.collision_mask = 1
	q.hit_back_faces = true
	return q

## Os du cadavre : séparés du centre du corps (position à la mort, à 0,5 m du sol) par une paroi ? sous le sol ?
func _os(a: Node, f: Dictionary) -> void:
	var centre: Vector3 = (f["p_mort"] as Vector3) + Vector3(0, 0.5, 0)
	var pelvis: Node3D = null
	var os_l: Array = []
	for b in a.find_children("*", "PhysicalBone3D", true, false):
		os_l.append(b)
		if String(b.name) == "pelvis":
			pelvis = b
	if os_l.is_empty():
		return
	if pelvis != null:
		centre = pelvis.global_position
		var rc := esp.intersect_ray(_rayon((f["p_mort"] as Vector3) + Vector3(0, 0.5, 0), centre))
		if not rc.is_empty() and absf((rc["normal"] as Vector3).y) < 0.5:
			_noter_os(f, "os_mur", centre, "pelvis passe la paroi")
	var vus: Dictionary = f["os_vus"]
	for b: Node3D in os_l:
		if b == pelvis:
			continue
		var q := b.global_position
		var r := esp.intersect_ray(_rayon(centre, q))
		if not r.is_empty() and absf((r["normal"] as Vector3).y) < 0.5 and (r["position"] as Vector3).distance_to(q) > 0.05:
			_noter_os(f, "os_mur", q, String(b.name))
		if _sous_sol(q + Vector3(0, 0.05, 0), a):
			_noter_os(f, "os_sous_sol", q, String(b.name))
	f["os_vus"] = vus

func _noter_os(f: Dictionary, cat: String, p: Vector3, detail: String) -> void:
	var vus: Dictionary = f["os_vus"]
	if vus.has(cat):
		return
	vus[cat] = true
	_noter(f, cat, p, 0.0, detail, true)

func _episode_continu(f: Dictionary, cat: String, p: Vector3, dt: float, detail: String) -> void:
	var ep: Dictionary = f["ep"]
	if not ep.has(cat):
		ep[cat] = {"t": t_sim, "p": p, "duree": 0.0, "detail": detail}
	ep[cat]["duree"] = float(ep[cat]["duree"]) + dt
	if cat != "traverse_objet" and float(ep[cat]["duree"]) >= 0.1 and not ep[cat].has("cap") and _cam != null and _n_captures + _captures.size() < _captures_max:
		ep[cat]["cap"] = true
		_captures.append({"p": p, "nom": "%s %s %s t=%.1f (%s)" % [cat, f["classe"], f["ident"], t_sim, detail]})

func _fin_continu(f: Dictionary, cat: String) -> void:
	var ep: Dictionary = f["ep"]
	if not ep.has(cat):
		return
	var e: Dictionary = ep[cat]
	ep.erase(cat)
	if float(e["duree"]) >= 0.1:      # au moins 3 échantillons de suite : pas un contact d'une image
		_noter(f, cat, e["p"], float(e["duree"]), String(e["detail"]), cat != "traverse_objet" or float(e["duree"]) > 1.0, float(e["t"]))

func _clore() -> void:
	for f: Dictionary in acteurs.values():
		for cat in (f["ep"] as Dictionary).keys():
			_fin_continu(f, cat)
		if float(f["coince"]) > 1.0:
			_noter(f, "coince", f["prec"], float(f["coince"]), "fin", float(f["coince"]) > 2.0)

## Captures des cas graves et film de suivi (avec fenêtre seulement : headless, le viewport ne rend rien).
func _images() -> void:
	var dos := String(args.get("sortie", ProjectSettings.globalize_path("res://captures/audit_collisions")))
	var et := String(args.get("etiquette", "audit"))
	if _film_classe != "" and _film_t < _film_duree:
		if _film_suivi == null or not is_instance_valid(_film_suivi):
			if t_sim > 6.0:
				for f: Dictionary in acteurs.values():
					var a: Node3D = f["n"]
					if is_instance_valid(a) and String(f["classe"]).contains(_film_classe) and not f["mort"] and _visible(a) and _loco(a):
						_film_suivi = a
						print("FILM : suit %s (%s)" % [f["ident"], f["classe"]])
						break
		else:
			var a := _film_suivi
			var arr := -a.global_transform.basis.z
			_cam.global_position = a.global_position + Vector3(arr.x, 0, arr.z).normalized() * 3.6 + Vector3(0, 2.2, 0) + a.global_transform.basis.x * 1.2
			_cam.look_at(a.global_position + Vector3(0, 1.0, 0))
			_cam.current = true
			await process_frame
			DirAccess.make_dir_recursive_absolute("%s/film_%s_%s" % [dos, et, lieu])
			root.get_viewport().get_texture().get_image().save_png("%s/film_%s_%s/f_%04d.png" % [dos, et, lieu, _film_n])
			_film_n += 1
			_film_t += float(PAS) / 60.0
			_cam.current = false
			return
	if _captures.is_empty():
		return
	var c: Dictionary = _captures.pop_front()
	var p: Vector3 = c["p"]
	var dirj := (j.global_position - p)
	dirj.y = 0.0
	dirj = dirj.normalized() if dirj.length() > 0.1 else Vector3.BACK
	_cam.global_position = p + dirj * 4.0 + Vector3(0, 2.5, 0)
	_cam.look_at(p + Vector3(0, 0.9, 0))
	_cam.current = true
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/cas_%s_%s_%02d.png" % [dos, et, lieu, _n_captures])
	print("CAPTURE %d : %s" % [_n_captures, c["nom"]])
	_n_captures += 1
	_cam.current = false

func _noter(f: Dictionary, cat: String, p: Vector3, duree: float, detail: String, grave: bool, t := -1.0) -> void:
	if grave and _cam != null and _n_captures + _captures.size() < _captures_max and cat in ["teleport", "passe_mur", "os_mur", "os_sous_sol"]:
		_captures.append({"p": p, "nom": "%s %s %s t=%.1f" % [cat, f["classe"], f["ident"], t_sim]})
	episodes.append({"lieu": lieu, "classe": f["classe"], "ident": f["ident"], "cat": cat, "t": snappedf(t if t >= 0.0 else t_sim, 0.1),
		"x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01), "duree": snappedf(duree, 0.05), "detail": detail, "grave": grave})

func _ecrire() -> void:
	var dos := String(args.get("sortie", ProjectSettings.globalize_path("res://captures/audit_collisions")))
	DirAccess.make_dir_recursive_absolute(dos)
	var et := String(args.get("etiquette", "audit"))
	var base := "%s/audit_%s_%s" % [dos, et, lieu]
	var fc := FileAccess.open(base + ".csv", FileAccess.WRITE)
	fc.store_line("lieu;classe;ident;cat;t;x;y;z;duree;grave;detail")
	for e: Dictionary in episodes:
		fc.store_line("%s;%s;%s;%s;%.1f;%.2f;%.2f;%.2f;%.2f;%s;%s" % [e["lieu"], e["classe"], e["ident"], e["cat"], e["t"], e["x"], e["y"], e["z"], e["duree"], "1" if e["grave"] else "0", String(e["detail"]).replace(";", ",")])
	fc.close()
	# totaux par classe
	var par_classe := {}
	var nb_classe := {}
	for f: Dictionary in acteurs.values():
		nb_classe[f["classe"]] = int(nb_classe.get(f["classe"], 0)) + 1
	var graves := 0
	var tot := {}
	for e: Dictionary in episodes:
		var k: String = e["classe"]
		if not par_classe.has(k):
			par_classe[k] = {}
		var c: String = e["cat"]
		if c == "coince" and not e["grave"]:
			c = "coince_1_2s"
		par_classe[k][c] = int(par_classe[k].get(c, 0)) + 1
		tot[c] = int(tot.get(c, 0)) + 1
		if e["grave"]:
			graves += 1
	var pires := episodes.filter(func(e: Dictionary) -> bool: return e["grave"])
	pires.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["duree"]) > float(b["duree"]))
	var ips_moy := 0.0
	for v in _ips:
		ips_moy += v
	ips_moy /= maxf(_ips.size(), 1)
	var fj := FileAccess.open(base + ".json", FileAccess.WRITE)
	fj.store_string(JSON.stringify({"lieu": lieu, "duree_s": t_sim, "acteurs": acteurs.size(), "acteurs_par_classe": nb_classe, "totaux": tot,
		"par_classe": par_classe, "graves": graves, "ips_simulation_moy": snappedf(ips_moy, 0.1), "pires": pires.slice(0, 25)}, "\t"))
	fj.close()
	print("ACTEURS %s : %s" % [lieu, str(nb_classe)])
	for k in par_classe:
		print("  %-34s %s" % [k, str(par_classe[k])])
	print("BILAN %s : %d acteurs, %d épisodes (%d graves) %s ; IPS simulation %.0f -> %s.csv" % [lieu, acteurs.size(), episodes.size(), graves, str(tot), ips_moy, base])
	quit(mini(graves, 250))
