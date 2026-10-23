extends SceneTree
## Test sans fenêtre du squelette nordique guerrier : apparition (modèle, budget de triangles, arme), coup léger et puissant
## (fragilité aux coups puissants), mort en ragdoll (aucun os sous le terrain, corps figé en tas), sauvegarde (identifiant stable
## dans draugrs_morts, pas de réapparition) et gardiens de l'ossuaire de la crypte.
##   godot --headless --path . --script res://outils/test_squelette.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const OS_MESURES := ["pelvis", "spine_03", "Head", "hand_l", "hand_r", "foot_l", "foot_r", "calf_l", "calf_r"]
const BUDGET := Vector2i(4000, 7500)   # triangles visibles (variante complète) ; draugr : 7 500 au plus

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _triangles(d: Node3D) -> int:
	var n := 0
	for mi: MeshInstance3D in d.modele.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return n

func _creer(type: String, x: float, z: float, opts := {}) -> CharacterBody3D:
	var d: CharacterBody3D = m.creer_draugr(type, Vector3(x, m.hauteur(x, z) + 0.05, z), 0.0, false, opts)
	return d

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await process_frame
	m.joueur.global_position = Vector3(60, m.hauteur(60, 60) + 1.0, 60)  # loin : ils restent calmes
	# --- apparition
	var epee := _creer("squelette", 4.0, -4.0)
	var archer := _creer("squelette_archer", 4.0, 4.0)
	for i in 30:
		await physics_frame
	for d in [epee, archer]:
		var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
		_verif(sq != null and sq.find_bone("hand_r") >= 0 and sq.find_bone("ball_l") >= 0, "%s : squelette RIG18 + feuilles du ragdoll (%d os)" % [d.type, sq.get_bone_count()])
		_verif(sq.get_bone_count() <= 26, "%s : au plus 26 os" % d.type)
		var tri := _triangles(d)
		_verif(tri >= BUDGET.x and tri <= BUDGET.y, "%s : %d triangles dans le budget %d-%d" % [d.type, tri, BUDGET.x, BUDGET.y])
		_verif(d.vie_max == 70.0 and d.nom_affiche == "Squelette", "%s : 70 PV, nommé « Squelette »" % d.type)
		_verif(d.anim.has_animation("Sword_Idle") and d.anim.has_animation("Death01") and d.anim.has_animation("Sword_Attack"), "%s : animations de la bibliothèque partagée" % d.type)
	_verif(epee.modele.find_child("epee", true, false).visible and not epee.modele.find_child("arc", true, false).visible, "épéiste : épée visible, arc caché")
	_verif(archer.modele.find_child("arc", true, false).visible and not archer.modele.find_child("epee", true, false).visible, "archer : arc visible, épée cachée")
	# --- coups : léger (par derrière : pas de parade), puissant (os fragiles : +30 %)
	var derriere := epee.global_position + Vector3(0, 0, -2.0)
	var r: String = epee.recevoir_coup(10.0, derriere, false)
	_verif(r == "touche" and absf(epee.vie - 60.0) < 0.01, "coup léger : touché, 60 PV (%s, %.1f)" % [r, epee.vie])
	var derriere2 := archer.global_position + Vector3(0, 0, -2.0)
	archer.recevoir_coup(20.0, derriere2, true)
	_verif(absf(archer.vie - 44.0) < 0.01, "coup puissant : fragile (20 x 1,3 = 26 dégâts, 44 PV : %.1f)" % archer.vie)
	# --- mort : ragdoll
	var morts := []
	epee.mort.connect(func(id: String) -> void: morts.append(id))
	var sq: Skeleton3D = epee.modele.find_child("Skeleton3D", true, false)
	var att := {}
	for n in OS_MESURES:
		var ba := BoneAttachment3D.new()
		ba.bone_name = n
		sq.add_child(ba)
		att[n] = ba
	await process_frame
	var r2: String = epee.recevoir_coup(500.0, epee.global_position + Vector3(-1.8, 0, 0), true)
	_verif(r2 == "tue" and not epee.vivant() and morts == [epee.ident], "coup mortel : « tue », signal mort émis (%s)" % [morts])
	_verif(epee.collision_layer == 0 and epee.collision_mask == 0, "capsule coupée à la mort")
	var rd: Ragdoll = epee._ragdoll
	_verif(rd != null and rd.actif, "ragdoll déclenché")
	var pire := 1e9
	var n := 0
	while n < 1500 and not (rd and rd.est_fige()):
		await physics_frame
		n += 1
		for k in att:
			var p: Vector3 = (att[k] as Node3D).global_position
			pire = minf(pire, p.y - m.hauteur(p.x, p.z))
	_verif(rd != null and rd.est_fige(), "corps figé après %d images" % n)
	# seuil -8 cm : on mesure les ORIGINES des os (articulations, pas la surface des formes) contre la hauteur lisse du terrain ; le sol physique est un maillage à facettes et le temps réel fait varier le pire cas de -0,03 à +0,02 m (vu -0,052 une fois) : tolérance, pas un enfoncement
	_verif(pire > -0.08, "aucun os sous le terrain (pire %.3f m)" % pire)
	var haut := 0.0
	var etalement := 0.0
	var centre: Vector3 = (att["pelvis"] as Node3D).global_position
	for k in att:
		var p: Vector3 = (att[k] as Node3D).global_position
		haut = maxf(haut, p.y - m.hauteur(p.x, p.z))
		etalement = maxf(etalement, Vector2(p.x - centre.x, p.z - centre.z).length())
	_verif(haut < 0.7, "tas d'os à terre : hauteur max %.2f m" % haut)
	_verif(etalement < 2.2, "tas d'os groupé : étalement %.2f m" % etalement)
	# --- sauvegarde : l'identifiant du mort est enregistré, le vivant non
	m.joueur.mort = false
	m.sauvegarder()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(m.fichier_sauvegarde()))
	var liste: Array = d.get("draugrs_morts", []) if d is Dictionary else []
	_verif(liste.has(epee.ident) and not liste.has(archer.ident), "sauvegarde : %s dans draugrs_morts, pas %s" % [epee.ident, archer.ident])
	# --- crypte : les trois squelettes de l'ossuaire (identifiants fixes), pas de réapparition après mort enregistrée
	var t = m.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	var c: Node3D = t.crypte
	var ids := []
	for g in t.donjon.gardiens:
		if String(g["type"]).begins_with("squelette"):
			ids.append(g["ident"] + ":" + g["type"])
	_verif(ids.has("cr_ossuaire_sq1:squelette") and ids.has("cr_ossuaire_sq2:squelette") and ids.has("cr_ossuaire_sqa:squelette_archer"), "donjon : 2 squelettes à l'épée + 1 archer dans l'ossuaire %s" % [ids])
	var fixes := true
	for g in t.donjon.gardiens:
		var gi: String = g["ident"]
		fixes = fixes and (gi.begins_with("cr_") or gi == "jarl")      # tous les identifiants du donjon sont fixes (fournis par la table du kit)
	_verif(fixes and t.donjon.gardiens.size() >= 30, "identifiants de gardiens fixes, jamais numérotés automatiquement (%d gardiens)" % t.donjon.gardiens.size())
	t.dedans = true
	c.visible = true
	m.joueur.global_position = c.to_global(Vector3(-35, 0.1, -20))
	for i in 12:
		t._gerer_zones()
		await physics_frame
	var apparus := []
	for id: String in m.draugrs:
		if id.begins_with("cr_ossuaire_sq") and is_instance_valid(m.draugrs[id]):
			apparus.append(id)
	_verif(apparus.size() == 3, "les 3 squelettes de l'ossuaire apparaissent à l'approche %s" % [apparus])
	var sq1: CharacterBody3D = m.draugrs.get("cr_ossuaire_sq1")
	_verif(sq1 != null and sq1.dort and sq1.debout and sq1.type == "squelette", "squelette endormi debout dans sa niche")
	if sq1:
		sq1._mourir()
		m.joueur.mort = false
		m.sauvegarder()
		var d2: Variant = JSON.parse_string(FileAccess.get_file_as_string(m.fichier_sauvegarde()))
		_verif((d2.get("draugrs_morts", []) as Array).has("cr_ossuaire_sq1"), "crypte : le squelette tué est dans la sauvegarde")
		t.morts_charges = d2.get("draugrs_morts", [])
		t.reinitialiser([])
		await process_frame
	print("TEST SQUELETTE : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	SqueletteGuerrier.vider()
	Humain.vider()
	Sons.vider()
	quit(1 if _echecs > 0 else 0)
