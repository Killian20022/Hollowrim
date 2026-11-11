extends SceneTree
## Audit des personnages Tripo EN JEU (foret_test, shaders et éclairage du jeu), fenêtre HORS ÉCRAN (godot_slot.sh).
## Pour chaque personnage : une planche (lignes = repos, marche, course, garde, attaque x2, mort ; colonnes = face, profil droit,
## profil gauche, 3/4, gros plan main droite, gros plan main gauche, référence validée la plus proche en face, même instant).
##   --vue=village : gardes Tripo (tous corps et livrées, verre, armure dorée), Haldor, jarl, mage.
##   --vue=crypte  : draugr guerrier (3 armes), archer draugr, squelette, archer squelette, gobelin ; + vraie mort (dépouille) à la fin.
##   godot --path . --resolution 960x540 --script res://outils/audit_persos_tripo.gd -- --nouvelle --vue=village --sortie=<dossier> [--cibles=a,b]
## Écrit <sortie>/<vue>_<nom>.png (planche) ; imprime « CIBLE », « CLIPS », « PLANCHE ».
const SCENE := "res://scenes/foret_test.tscn"
const CW := 300            # cellule : recadrage centre 480x540 réduit
const CH := 338
var m: Node3D
var j: CharacterBody3D
var cam: Camera3D
var lum: OmniLight3D
var sortie := "user://audit_persos_tripo"
var base := Vector3.ZERO
var face := Vector3(0, 0, 1)      # direction vers laquelle les persos regardent
var lacet := 0.0
var filtre: Array = []

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		if is_instance_valid(j):
			j.vie = j.vie_max
		await process_frame

func _image() -> Image:
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	var w := im.get_width()
	var h := im.get_height()
	var cw := int(h * 480.0 / 540.0)
	var cr := im.get_region(Rect2i((w - cw) / 2, 0, cw, h))
	cr.resize(CW, CH, Image.INTERPOLATE_NEAREST)
	return cr

func _sol(x: float, z: float) -> float:
	if m.has_method("hauteur") and _arg("vue", "village") == "village":
		return m.hauteur(x, z)
	return base.y

## Clip (première variante existante) et instant normalisé de chaque ligne de la planche, selon le rôle.
func _lignes(ap: AnimationPlayer, role: String) -> Array:
	var c := {
		"repos": [["Idle"], 0.3],
		"marche": [["Walk"], 0.25],
		"course": [["Jog_Fwd", "Run"], 0.3],
		"garde": [["Pistol_Aim_Neutral"] if role == "arc" else (["Spell_Simple_Idle"] if role == "mage" else ["Sword_Idle"]), 0.4],
		"attaque_a": [["Pistol_Shoot"] if role == "arc" else (["Spell_Simple_Shoot"] if role == "mage" else (["Punch_Cross"] if role == "mains" else ["Sword_Attack"])), 0.3],
		"attaque_b": [["Pistol_Shoot"] if role == "arc" else (["Spell_Simple_Shoot"] if role == "mage" else (["Punch_Cross"] if role == "mains" else ["Sword_Attack"])), 0.65],
		"mort": [["Death"], 0.99],
	}
	var out: Array = []
	for k: String in ["repos", "marche", "course", "garde", "attaque_a", "attaque_b", "mort"]:
		for clip: String in c[k][0]:
			if ap.has_animation(clip):
				out.append([k, clip, float(c[k][1])])
				break
	return out

func _poser(n: Node3D, ap: AnimationPlayer, clip: String, t: float) -> void:
	ap.play(clip, 0.0)
	ap.seek(ap.get_animation(clip).length * t, true)
	ap.pause()

func _placer(n: Node3D, p: Vector3) -> void:
	n.global_position = Vector3(p.x, _sol(p.x, p.z) + 0.02, p.z)
	n.global_rotation = Vector3(0, lacet, 0)

func _os(n: Node3D, nom: String) -> Vector3:
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return n.global_position + Vector3(0, 1.0, 0)
	var i := sq.find_bone(nom)
	if i < 0:
		return n.global_position + Vector3(0, 1.0, 0)
	return sq.global_transform * sq.get_bone_global_pose(i).origin

## Caméra autour de la cible : `ang` degrés autour de Y depuis sa face, `dist` m, visée `vise`.
func _cam(vise: Vector3, ang: float, dist: float, fov: float, dh := 0.15) -> void:
	var d := Basis(Vector3.UP, deg_to_rad(ang)) * face
	cam.fov = fov
	cam.near = maxf(0.03, dist - (1.1 if dist > 2.0 else 0.45))      # tout ce qui est entre la caméra et le perso (caisses, murs) est coupé
	cam.global_position = vise + d * dist + Vector3(0, dh, 0)
	cam.look_at(vise, Vector3.UP)
	if lum != null:
		lum.global_position = cam.global_position + Vector3(0, 0.6, 0)

func _vues(n: Node3D, ref: Node3D, ap: AnimationPlayer, ap_ref: AnimationPlayer, clip: String, t: float) -> Array:
	var cells: Array = []
	var h := float(n.get_meta("audit_h", 1.0))
	var centre := n.global_position + Vector3(0, 0.95 * h, 0)
	for ang: float in [0.0, 90.0, -90.0, 40.0]:
		_cam(centre, ang, 3.6 * h, 32.0, 0.25)
		await _attendre(3)
		cells.append(await _image())
	var gauche := (_os(n, "upperarm_l") - _os(n, "upperarm_r"))
	gauche.y = 0.0
	gauche = gauche.normalized()
	for cote in [-1.0, 1.0]:       # main droite (côté -gauche) puis main gauche ; caméra dehors, un peu devant et au-dessus
		var mpos := _os(n, "hand_r" if cote < 0.0 else "hand_l")
		var dirc: Vector3 = (gauche * cote * 0.8 + face * 0.65 + Vector3.UP * 0.25).normalized()
		cam.fov = 30.0
		cam.near = 0.5
		cam.global_position = mpos + dirc * 1.15
		cam.look_at(mpos, Vector3.UP)
		if lum != null:
			lum.global_position = cam.global_position + Vector3(0, 0.6, 0)
		await _attendre(3)
		cells.append(await _image())
	if ref != null and ap_ref != null and ap_ref.has_animation(clip):
		var pos_n := n.global_position
		n.visible = false
		_placer(ref, pos_n)
		ref.visible = true
		_poser(ref, ap_ref, clip, t)
		var hr := float(ref.get_meta("audit_h", 1.0))
		await _attendre(2)
		var face_n := face
		var gr := _os(ref, "upperarm_l") - _os(ref, "upperarm_r")
		gr.y = 0.0
		if gr.length() > 0.05:
			face = gr.normalized().cross(Vector3.UP)
		_cam(ref.global_position + Vector3(0, 0.95 * hr, 0), 0.0, 3.6 * hr, 32.0, 0.25)
		await _attendre(3)
		cells.append(await _image())
		face = face_n
		ref.visible = false
		ref.global_position += Vector3(0, -60, 0)
		n.visible = true
	else:
		cells.append(null)
	return cells

func _etiquette(im: Image, texte_court: int, couleur: Color) -> void:
	# repère de couleur en haut à gauche (pas de police dans un SceneTree headless fiable) : bande de 6 px
	im.fill_rect(Rect2i(0, 0, CW, 4), couleur)

func _planche(nom: String, lignes: Array) -> void:
	var cols := 7
	var pl := Image.create(CW * cols + (cols - 1) * 2, CH * lignes.size() + (lignes.size() - 1) * 2, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.03, 0.03, 0.03))
	for r in lignes.size():
		var cells: Array = lignes[r]
		for c in cells.size():
			var im: Image = cells[c]
			if im == null:
				continue
			if c == cols - 1:
				_etiquette(im, 0, Color(0.85, 0.7, 0.2))      # colonne référence : bande dorée
			pl.blit_rect(im, Rect2i(0, 0, CW, CH), Vector2i(c * (CW + 2), r * (CH + 2)))
	var f := sortie.path_join(nom + ".png")
	pl.save_png(f)
	print("PLANCHE ", f, " lignes=", lignes.size())

func _auditer(nom: String, n: Node3D, ap: AnimationPlayer, role: String, ref: Node3D, ap_ref: AnimationPlayer) -> void:
	if not filtre.is_empty() and not filtre.has(nom):
		return
	_placer(n, base)
	n.visible = true
	var defs := _lignes(ap, role)
	var noms: Array = []
	for d: Array in defs:
		noms.append("%s=%s@%.2f" % [d[0], d[1], d[2]])
	print("CLIPS ", nom, " ", noms)
	var lignes: Array = []
	if not defs.is_empty():
		_poser(n, ap, String(defs[0][1]), float(defs[0][2]))
		await _attendre(45)      # ressorts (cape, tabard) : laisser retomber après le déplacement
		var g := _os(n, "upperarm_l") - _os(n, "upperarm_r")
		g.y = 0.0
		if g.length() > 0.05:
			face = g.normalized().cross(Vector3.UP)      # perso tourné vers +Z : épaule gauche en +X -> (+X) x (+Y) = +Z
		print("FACE ", nom, " ", face)
	for d: Array in defs:
		_placer(n, base)
		_poser(n, ap, String(d[1]), float(d[2]))
		await _attendre(4)
		lignes.append(await _vues(n, ref, ap, ap_ref, String(d[1]), float(d[2])))
	_planche(nom, lignes)
	n.global_position += Vector3(0, -60, 0)

func _figer(n: Node3D, modele: Node3D, ap: AnimationPlayer) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED
	if modele != null:
		modele.process_mode = Node.PROCESS_MODE_ALWAYS      # ressorts, pieds au sol, accroches
	if ap != null:
		ap.process_mode = Node.PROCESS_MODE_ALWAYS

func _go() -> void:
	sortie = _arg("sortie", sortie)
	var fc := _arg("cibles", "")
	if fc != "":
		filtre = Array(fc.split(","))
	DirAccess.make_dir_recursive_absolute(sortie)
	Effets.niveau_force = 1
	RetourImpact.muet = true
	var sc := (load(SCENE) as PackedScene).instantiate()
	sc.set_meta("test", true)
	root.add_child(sc)
	current_scene = sc
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	while not m.village.prets:
		await process_frame
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = float(_arg("heure", "11"))
	m.cycle._process(0.0)
	if m.get("hud") != null:
		if "aide_t" in m.hud:
			m.hud.aide_t = 0.0
		m.hud.visible = false
	j.mains.visible = false
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	cam = Camera3D.new()
	cam.near = 0.03
	m.add_child(cam)
	cam.make_current()
	var vue := _arg("vue", "village")
	if vue == "crypte":
		await _crypte()
	else:
		await _village()
	sc.queue_free()
	for i in 5:
		await process_frame
	quit(0)

func _village() -> void:
	await _attendre(120)
	base = Vector3(33.0, 0.0, 43.0)
	lacet = 0.0
	face = Vector3(0, 0, 1)
	j.global_position = Vector3(base.x + 6.0, m.hauteur(base.x + 6.0, base.z + 14.0) + 0.2, base.z + 14.0)
	var cibles: Array = []     # [nom, noeud, role, corps]
	var refs := {}
	for g in m.get_node("GardesVillage").gardes:
		var d: Dictionary = g.donnees
		var id := String(d.get("id", ""))
		var corps := GardesVillage.corps_tripo(d)
		if bool(d.get("armure_tripo", false)):
			corps = "dore"
		if corps == "":
			print("CIBLE ", id, " ignorée (pas Tripo) modele=", g.modele.name)
			continue
		var role := "lance" if corps == "tripo_garde_lance" else ("arc" if corps == "tripo_archer" else "epee")
		cibles.append(["garde_%s_%s_l%d" % [id, corps.replace("tripo_", ""), int(d.get("livree", 0))], g, role, corps])
		if id in ["halle_o", "ronde_place", "ronde_nord"]:
			refs[corps] = g
	for v in get_nodes_in_group("villageois"):
		if not ("donnees" in v):
			continue
		var vid := String(v.donnees.get("id", ""))
		if vid == "garde" and not v.has_method("alerter"):
			cibles.append(["haldor", v, "epee", "tripo_garde_epee"])
		elif vid == "chef" and not v.has_method("alerter"):
			cibles.append(["jarl_gunnar", v, "mains", "jarl"])
		elif vid == "hab_mage_tripo":
			cibles.append(["mage_eirwen", v, "mage", "mage"])
	for c: Array in cibles:
		var n: Node3D = c[1]
		_figer(n, n.get("modele"), n.get("anim"))
		print("CIBLE ", c[0], " corps=", c[3], " modele=", (n.get("modele") as Node).name if n.get("modele") else "?")
	for c: Array in cibles:
		var n: Node3D = c[1]
		n.global_position += Vector3(0, -60, 0)
	# référence la plus proche : corps d'origine (livrée 0) pour les gardes ; garde à l'épée ronde_place pour Haldor, verre, dorée.
	var ref_epee: Node3D = refs.get("tripo_garde_epee")
	for c: Array in cibles:
		var n: Node3D = c[1]
		var ref: Node3D = refs.get(String(c[3]), ref_epee)
		if ref == n:
			# référence de soi-même : on prend un autre corps validé (lancier) pour l'échelle
			ref = refs.get("tripo_garde_lance") if String(c[3]) != "tripo_garde_lance" else refs.get("tripo_archer")
		if String(c[3]) in ["jarl", "mage"]:
			ref = refs.get("tripo_garde_lance")
		await _auditer(String(c[0]), n, n.get("anim"), String(c[2]), ref, ref.get("anim") if ref != null else null)

func _crypte() -> void:
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	var t_max := Time.get_ticks_msec() + 30000
	while not t.dedans and Time.get_ticks_msec() < t_max:
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	print("CRYPTE dedans=", t.dedans)
	var c: Node3D = t.crypte
	j.global_position = c.to_global(Vector3(0.0, 0.1, -21.0))
	j.velocity = Vector3.ZERO
	if j.mains.get("torche_lumiere") != null:
		j.mains.torche_lumiere.visible = true
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	lacet = c.global_rotation.y
	face = Basis(Vector3.UP, lacet).z
	base = c.to_global(Vector3(0.0, 0.05, -27.0))
	lum = OmniLight3D.new()
	lum.omni_range = 9.0
	lum.light_energy = 1.6
	lum.light_color = Color(1.0, 0.78, 0.55)
	m.add_child(lum)
	var defs := [["draugr_guerrier_a", "guerrier", {"ident": "audit_g1"}, "epee"], ["draugr_guerrier_b", "guerrier", {"ident": "audit_g22"}, "epee"],
		["draugr_guerrier_c", "guerrier", {"ident": "audit_g333"}, "epee"], ["draugr_archer", "sbire", {"archer": true}, "arc"],
		["squelette", "squelette", {"variante": "epee"}, "mains"], ["squelette_archer", "squelette_archer", {}, "arc"], ["gobelin", "gobelin", {}, "epee"]]
	var cibles: Array = []
	for i in defs.size():
		var opts: Dictionary = (defs[i][2] as Dictionary).duplicate()
		if not opts.has("ident"):
			opts["ident"] = "audit_" + String(defs[i][0])
		opts["dort"] = false
		var d: CharacterBody3D = m.creer_draugr(String(defs[i][1]), base + Vector3(i * 3.0, 0, 0), lacet, false, opts)
		cibles.append([defs[i][0], d, defs[i][3]])
	await _attendre(20)
	for x: Array in cibles:
		var d: Node3D = x[1]
		_figer(d, d.get("modele"), d.get("anim"))
		var mo: Node3D = d.get("modele")
		var arme := ""
		if mo != null:
			for ba in mo.find_children("*", "BoneAttachment3D", true, false):
				arme += "%s(%s,%d) " % [ba.name, (ba as BoneAttachment3D).bone_name, (ba as BoneAttachment3D).bone_idx]
		d.set_meta("audit_h", 0.7 if String(x[0]) == "gobelin" else 1.0)
		print("CIBLE ", x[0], " modele=", mo.name if mo else "?", " tripo=", mo.get_meta("tripo_ennemi", "") if mo else "", " accroches=", arme)
		d.global_position += Vector3(0, -60, 0)
	var ref: Node3D = GardeTripo.creer("tripo_garde_epee", false, false)
	m.add_child(ref)
	ref.global_position = base + Vector3(0, -60, 0)
	var ap_ref := ref.get_node("Animations") as AnimationPlayer
	for x: Array in cibles:
		var d: Node3D = x[1]
		await _auditer(String(x[0]), d, d.get("anim"), String(x[2]), ref, ap_ref)
	# vraie mort : un coup fatal, IA rendue, photo de la dépouille après 3,5 s ; chaque mort à sa place (x + 4 m)
	var morts: Array = []
	var k := 0
	for x: Array in cibles:
		if not filtre.is_empty() and not filtre.has(String(x[0])):
			continue
		var d: CharacterBody3D = x[1]
		var p: Vector3 = c.to_global(Vector3(-2.4 + (k % 4) * 1.6, 0.05, -27.0 + (k / 4) * 2.4))
		k += 1
		_placer(d, p)
		d.visible = true
		d.process_mode = Node.PROCESS_MODE_INHERIT
		var ap: AnimationPlayer = d.get("anim")
		if ap:
			ap.play()
		await _attendre(3)
		var r = d.call("recevoir_coup", 999999.0, d.global_position + face * 1.5 + Vector3(0, 1.2, 0), true)
		print("MORT ", x[0], " -> ", r)
		await create_timer(3.5, true, false, true).timeout
		var cells: Array = []
		for ang: float in [0.0, 70.0, -110.0]:
			_cam(p + Vector3(0, 0.3, 0), ang, 2.6, 45.0, 1.3)
			await _attendre(3)
			cells.append(await _image())
		morts.append(cells)
		print("DEPOUILLE ", x[0], " valide=", is_instance_valid(d), " vivant=", d.call("vivant") if is_instance_valid(d) else "-")
	if not morts.is_empty():
		_planche("crypte_depouilles", morts)
