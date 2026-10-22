extends SceneTree
## Test de SalleActive (crypte) et des gabarits d'ennemis (duplicate au lieu de reconstruire).
## godot --headless --path . --script res://outils/test_salle_active.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
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
	_gabarits()
	var t = m.tertre
	var t0 := Time.get_ticks_msec()
	t.attendre_donjon()
	print("attente du donjon + modèles d'ennemis : %d ms (%d gabarits)" % [Time.get_ticks_msec() - t0, EnnemisNordiques.nb_gabarits()])
	for i in 5:
		await physics_frame
	var sa: SalleActive = t.salles
	_verif(sa != null, "SalleActive installée")
	_verif(sa.classement_fini(), "géométrie classée")
	var dj: CrypteDonjon = t.donjon
	_verif(sa.salles.size() == dj.modules.size(), "une salle par module (%d / %d)" % [sa.salles.size(), dj.modules.size()])
	var sym := true
	for id: String in sa.salles:
		for v: String in sa.salles[id]["voisins"]:
			if not sa.salles.has(v) or not (sa.salles[v]["voisins"] as Array).has(id):
				sym = false
	_verif(sym, "graphe des portes symétrique")
	var classes := 0
	for id: String in sa.salles:
		classes += (sa.salles[id]["noeuds"] as Array).size()
	print("géométrie classée : %d maillages dans les salles (%d nœuds distincts)" % [classes, sa._noeuds.size()])
	_verif(sa._noeuds.size() > 500, "plus de 500 maillages gérés par salle")

	var c: Node3D = t.crypte
	# --- localisation du joueur
	var j: CharacterBody3D = m.joueur
	j.global_position = c.to_global(Vector3(0, 0.1, -12))
	_verif(sa.salle_de(c.to_local(j.global_position)) == "niches", "joueur dans « niches »")
	j.global_position = c.to_global(Vector3(0, 0.1, -71))
	_verif(sa.salle_de(c.to_local(j.global_position)) == "arene", "joueur dans « arene »")
	j.global_position = c.to_global(Vector3(-16, -6 + 0.1, -43))
	print("étage bas : salle = ", sa.salle_de(c.to_local(j.global_position)))

	# --- ennemis : un dormeur dans la niche (proche), un dans l'arène (loin), un garde dans l'aile ouest
	var proche: CharacterBody3D = m.creer_draugr("sbire", c.to_global(Vector3(0.85, 0.05, -13.0)), 0.0, true, {"ident": "t_proche", "debout": true})
	var loin: CharacterBody3D = m.creer_draugr("sbire", c.to_global(Vector3(3, 0.05, -71.0)), 0.0, true, {"ident": "t_loin", "debout": true})
	var garde: CharacterBody3D = m.creer_draugr("guerrier", c.to_global(Vector3(-21, 0.05, -16.0)), 0.0, false, {"ident": "t_garde"})
	var morts: Array = []
	loin.mort.connect(func(id: String) -> void: morts.append(id))
	j.global_position = c.to_global(Vector3(0, 0.1, -12))
	sa.rafraichir(true)
	_verif(sa.courante == "niches", "salle courante = niches")
	_verif(not proche.est_gele() and proche.visible, "ennemi de la salle courante : actif et visible")
	_verif(loin.est_gele() and not loin.visible and loin.process_mode == Node.PROCESS_MODE_DISABLED, "ennemi de l'arène : gelé, caché, process coupé")
	_verif(not garde.est_gele(), "garde de l'ossuaire : actif (le couloir s1, « long », relie niches et ossuaire)")
	var cachees := 0
	for id: int in sa._noeuds:
		if not (sa._noeuds[id]["n"] as GeometryInstance3D).visible:
			cachees += 1
	print("géométrie cachée dans « niches » : %d / %d" % [cachees, sa._noeuds.size()])
	_verif(cachees > 100, "plus de 100 maillages cachés hors de la salle active")
	_verif((sa._noeuds.values().filter(func(e: Dictionary) -> bool: return (e["s"] as Array).has("niches") and not (e["n"] as GeometryInstance3D).visible)).is_empty(), "aucun maillage de la salle courante n'est caché")
	# --- le joueur avance : l'arène devient voisine, l'ennemi se réveille de son gel
	j.global_position = c.to_global(Vector3(0, 0.1, -66))
	sa.rafraichir(true)
	_verif(sa.courante in ["arene", "antichambre"], "salle courante = %s" % sa.courante)
	j.global_position = c.to_global(Vector3(0, 0.1, -62))
	sa.rafraichir(true)
	_verif(not loin.est_gele() and loin.visible and loin.process_mode != Node.PROCESS_MODE_DISABLED, "ennemi de l'arène dégelé quand sa salle est voisine")
	_verif(proche.est_gele(), "l'ennemi de la niche, maintenant loin, est gelé")
	# --- un ennemi gelé qu'on alerte ou qu'on frappe se dégèle ; sa mort signale bien « tue »
	j.global_position = c.to_global(Vector3(0, 0.1, -12))
	sa.rafraichir(true)
	_verif(loin.est_gele(), "regelé")
	loin.alerter()
	_verif(not loin.est_gele(), "alerter() dégèle")
	sa.rafraichir(true)
	_verif(not loin.est_gele(), "un ennemi qui poursuit n'est jamais gelé")
	loin.recevoir_coup(999.0, c.to_global(Vector3(3, 1, -70)), true)
	_verif(morts == ["t_loin"], "la mort signale tue:t_loin (%s)" % str(morts))
	sa.rafraichir(true)
	_verif(not loin.est_gele(), "un mort n'est pas gelé")
	# --- joueur dehors : tout est gelé, tout est visible
	sa.rafraichir(false)
	_verif(proche.est_gele() and garde.est_gele(), "joueur dehors : ennemis de la crypte gelés")
	var tout_visible := true
	for id: int in sa._noeuds:
		if not (sa._noeuds[id]["n"] as GeometryInstance3D).visible:
			tout_visible = false
	_verif(tout_visible, "joueur dehors : toute la géométrie est rétablie")
	sa.tout_reveler()
	_verif(not proche.est_gele(), "tout_reveler() dégèle")
	print("Résultat : %d échec(s)" % _echecs)
	quit(1 if _echecs > 0 else 0)

## Gabarits : la copie d'une variante est rapide, équivalente et indépendante.
func _gabarits() -> void:
	var app_d := EnnemisNordiques.apparence_defaut("sbire")
	var app_b := {"corps": "homme", "draugr": false, "tenue": {"tunique": Color.WHITE}}
	var specs := [
		{"type": "sbire", "ident": "g_sbire_1", "apparence": app_d},
		{"type": "guerrier", "ident": "g_guerrier_1", "apparence": EnnemisNordiques.apparence_defaut("guerrier")},
		{"type": "sbire", "ident": "g_bandit_1", "apparence": app_b},
		{"type": "sbire", "archer": true, "ident": "g_barcher_1", "apparence": app_b},
		{"type": "guerrier", "boss": "jarl", "ident": "jarl", "apparence": app_d},
	]
	for sp: Dictionary in specs:
		var t0 := Time.get_ticks_usec()
		var a := EnnemisNordiques.creer(sp)
		var t1 := Time.get_ticks_usec()
		var b := EnnemisNordiques.creer(sp)
		var t2 := Time.get_ticks_usec()
		print("gabarit %-12s : 1re %.1f ms, 2e %.1f ms" % [sp["ident"], (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		root.add_child(a)
		root.add_child(b)
		_verif(a != b and a.get_meta("variante") == b.get_meta("variante") and b.has_meta("armes_nordiques"), "%s : copie distincte, même variante (%s)" % [sp["ident"], b.get_meta("variante")])
		_verif(a.find_children("*", "", true, false).size() == b.find_children("*", "", true, false).size(), "%s : même nombre de nœuds (%d)" % [sp["ident"], b.find_children("*", "", true, false).size()])
		var sqa := a.find_child("Skeleton3D", true, false) as Skeleton3D
		var sqb := b.find_child("Skeleton3D", true, false) as Skeleton3D
		_verif(sqa.get_bone_count() == 65 and sqb.get_bone_count() == 65, "%s : 65 os" % sp["ident"])
		# les accessoires accrochés à un os (arme, couronne) suivent la main / la tête dans la copie
		for att: BoneAttachment3D in sqb.find_children("*", "BoneAttachment3D", false, false):
			var i := sqb.find_bone(att.bone_name)
			var os_pos := (sqb.global_transform * sqb.get_bone_global_pose(i)).origin
			_verif(att.get_bone_idx() == i and i >= 0 and att.global_position.distance_to(os_pos) < 0.1, "%s : %s suit l'os %s (idx %d/%d, écart %.3f)" % [sp["ident"], att.name, att.bone_name, att.get_bone_idx(), i, att.global_position.distance_to(os_pos)])
		var ap := b.get_node("Animations") as AnimationPlayer
		ap.play("Walk")
		ap.advance(0.3)
		_verif(ap.current_animation == "Walk" and ap.has_animation("Death01"), "%s : la copie joue ses animations" % sp["ident"])
		if sp["ident"] == "g_barcher_1":
			var pa := sqb.get_node_or_null("PoseArcher")
			_verif(pa != null and pa.ap == ap and pa.mi_porte != null and pa.mi_vise != null and pa.os_.size() > 0, "archer bandit : PoseArcher relié à la copie")
			ap.play("Pistol_Aim_Neutral")
			ap.advance(0.05)
			pa.appliquer(sqb)
			_verif(not pa.mi_porte.visible and pa.mi_vise.visible, "archer bandit : l'arc de visée remplace l'arc porté")
			var pa0 := sqa.get_node("PoseArcher")
			_verif(pa0.mi_vise != pa.mi_vise and pa0.ap != ap, "archer bandit : les deux copies sont indépendantes")
		a.queue_free()
		b.queue_free()
