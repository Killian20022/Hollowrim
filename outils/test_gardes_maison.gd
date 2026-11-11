extends SceneTree
## Gardes en armure maison (scripts/garde_maison.gd), sans le monde :
##   - chaque rôle de data/gardes.json donne un corps de Gardien habillé par ArmureVisible avec les pièces de son ensemble (ids connus,
##     glb présents), les pièces recouvertes du corps masquées ;
##   - armes : lance (clips Lance_Estoc) / épée au poing / arc ; lance et bouclier sortis des accessoires (« armes_garde ») ;
##   - variété : sans_casque, pieces ; carrure ;
##   - démembrement : le morceau tranché emporte les pièces d'armure ; ragdoll ;
##   - butin : un garde tué (PnjCombat) laisse les pièces qu'il portait.
##   - livrée : tabard de Skarnholt (data/gardes.json « tabard ») sur lanciers, gardes à l'épée et Haldor, pas sur l'élite, l'archer ni le
##     garde d'or ; ôtable par garde ; jamais dans le butin ; maillage fermé, poids sur le torse/bassin/cuisses ; au démembrement il reste
##     au corps (ni copié dans le morceau, ni replié avec la jambe).
##   godot --headless --path . --script res://outils/test_gardes_maison.gd -- --nouvelle
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _garde(id: String) -> Dictionary:
	for g: Dictionary in GardesVillage.donnees()["gardes"]:
		if String(g.get("id", "")) == id:
			return g
	return {}

func _tester() -> void:
	var monde := Node3D.new()
	root.add_child(monde)
	await process_frame
	_verif(GardeMaison.actif({}), "armures maison par défaut")
	# tableaux : chaque id d'ensemble est une armure connue avec son modèle porté
	for nom: String in GardeMaison.ensembles():
		var e: Dictionary = GardeMaison.ensembles()[nom]
		for emp: String in e:
			var id := String(e[emp])
			_verif(Inventaire.connu(id) and Inventaire.emplacement_de(id) == emp and ArmureVisible.a_modele(id), "ensemble %s : %s (%s) connu, porté en %s" % [nom, id, emp, emp])
	var cas := {"so": ["lance", "cuirasse_fer"], "e_s": ["epee", "cuirasse_acier_nordique"], "vigie": ["arc", "armure_fourrure"],
		"ronde_nord": ["arc", "armure_cuir"], "n_e": ["epee", "cuirasse_verre"], "halle_e": ["epee", "cuirasse_or"], "ronde_ouest": ["epee", "cuirasse_acier_nordique"]}
	for id: String in cas:
		var g := _garde(id)
		var t0 := Time.get_ticks_usec()
		var mod := GardeMaison.creer(g)
		monde.add_child(mod)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var sq := mod.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := mod.get_node("Animations") as AnimationPlayer
		var av := mod.get_node_or_null("ArmureVisible") as ArmureVisible
		var pieces := GardeMaison.pieces_portees(mod)
		var arme: String = cas[id][0]
		_verif(av != null and pieces.has(cas[id][1]) and av.maillages().size() >= pieces.size(), "%s : %s portées (%d maillages d'armure), créé en %.0f ms" % [id, pieces, av.maillages().size() if av else 0, ms])
		_verif(sq.find_bone("hand_r") >= 0 and ap.has_animation("Idle") and ap.has_animation("Walk") and ap.has_animation("Death01"), "%s : squelette humain et clips partagés" % id)
		match arme:
			"lance":
				_verif(ap.has_animation("Lance_Estoc") and sq.get_node_or_null("armes_garde") != null, "%s : lance tenue (clips à la lance), lance et bouclier hors des accessoires" % id)
			"epee":
				_verif(not ap.has_animation("Lance_Estoc") and sq.find_child("EpeeJeu", true, false) != null, "%s : épée au poing, clips d'épée" % id)
			"arc":
				_verif(sq.get_node_or_null("arc_porte") != null and ap.has_animation("Pistol_Aim_Neutral"), "%s : arc du jeu porté" % id)
		if g.get("sans_casque", false):
			_verif(not pieces.has("casque_acier_nordique"), "%s : sans heaume (casque à nasal du Gardien)" % id)
		# masquage : la cotte du Gardien n'a plus de triangles sous la cuirasse (milieu du torse)
		var cotte := sq.get_node_or_null("tunique") as MeshInstance3D
		if cotte != null and av != null and av.maillage("torse") != null:
			var a := cotte.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var dessous := 0
			for t in range(0, idx.size() - 2, 3):
				var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
				if absf(c.x) < 0.12 and c.y > 1.05 and c.y < 1.35:
					dessous += 1
			_verif(dessous == 0, "%s : cotte du Gardien masquée sous la cuirasse (%d triangles restants au milieu du torse)" % [id, dessous])
		mod.queue_free()
	# livrée : tabard par rôle
	var attendus := {"so": true, "e_s": true, "ronde_rue": true, "halle_o": true, "ronde_place": true, "vigie": false, "ronde_nord": false, "n_e": false, "halle_e": false}
	for id: String in attendus:
		var mt := GardeMaison.creer(_garde(id))
		var lv := GardeMaison.livree(mt)
		_verif((lv != null) == bool(attendus[id]) and (lv == null or (lv.visible and lv.skin != null and String(mt.get_meta("livree_garde", "")) == "tabard_skarnholt")), "%s : tabard %s" % [id, "porté" if lv != null else "absent"])
		_verif(not GardeMaison.pieces_portees(mt).has("tabard_skarnholt"), "%s : tabard hors des pièces portées (pas de butin)" % id)
		mt.free()
	var hal := GardeMaison.creer({"role": "epee", "pieces": {"tete": "casque_acier_nordique"}})
	_verif(GardeMaison.livree(hal) != null, "Haldor (rôle épée) : tabard porté")
	hal.free()
	var sans := _garde("so").duplicate()
	sans["tabard"] = ""
	var ms := GardeMaison.creer(sans)
	_verif(GardeMaison.livree(ms) == null, "« tabard »: \"\" sur un garde : tabard ôté")
	ms.free()
	# géométrie : maillage fermé (chaque arête partagée par 2 triangles), os du haut du corps, matières tissu/cuir/fer
	var mt2 := GardeMaison.creer(_garde("so"))
	var lv2 := GardeMaison.livree(mt2)
	if lv2 != null:
		var aretes := {}
		var tris := 0
		var os_ok := true
		var nb_s := lv2.mesh.get_surface_count()
		var mats := []
		for si in nb_s:
			var a := lv2.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
			var cle := func(i: int) -> Vector3i: return Vector3i((v[i] * 2000.0).round())
			for t in range(0, idx.size() - 2, 3):
				for k in 3:
					var p0: Vector3i = cle.call(idx[t + k])
					var p1: Vector3i = cle.call(idx[t + (k + 1) % 3])
					var e := [p0, p1] if str(p0) < str(p1) else [p1, p0]
					aretes[str(e)] = int(aretes.get(str(e), 0)) + 1
			var m := lv2.get_surface_override_material(si)
			mats.append(m.resource_name if m else "?")
		var ouvertes := 0
		for e: String in aretes:
			if int(aretes[e]) != 2:
				ouvertes += 1
		var os_pondres := {}
		for si in nb_s:
			var a := lv2.mesh.surface_get_arrays(si)
			var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			for k in bo.size():
				if w[k] > 0.02:
					os_pondres[String(lv2.skin.get_bind_name(bo[k]))] = true
		for nom: String in os_pondres:
			if nom.contains("hand") or nom.contains("foot") or nom.contains("lowerarm") or nom.contains("calf"):
				os_ok = false
		print("    os pondérés du tabard : ", os_pondres.keys())
		_verif(ouvertes == 0 and tris > 3000 and tris < 8000, "tabard : maillage fermé (%d arêtes ouvertes), %d triangles" % [ouvertes, tris])
		_verif(os_ok, "tabard : attaché au torse / bassin / cuisses (ni mains, ni avant-bras, ni pieds)")
		_verif(mats.size() == 3 and str(mats).contains("tissu") and str(mats).contains("cuir"), "tabard : matières %s" % [mats])
	mt2.free()
	# démembrement : bras droit tranché d'un garde à l'épée -> le morceau emporte gantelet et cuirasse (maillages d'armure copiés)
	var gm := GardeMaison.creer(_garde("ronde_rue"))
	monde.add_child(gm)
	await process_frame
	(gm.get_node("Animations") as AnimationPlayer).play("Idle")
	await process_frame
	await process_frame
	var nb_mailles := (gm.find_child("Skeleton3D", true, false) as Skeleton3D).find_children("*", "MeshInstance3D", false, false).size()
	Demembrement.chance_forcee = 1.0
	var rb := Demembrement.trancher(gm, "avantbras_r", Vector3(2, 1, 0), Color(0.5, 0, 0))
	_verif(rb != null, "démembrement : avant-bras tranché (%d maillages sur le corps, MAILLAGES_MAX %d)" % [nb_mailles, Demembrement.MAILLAGES_MAX])
	if rb != null:
		var noms := []
		for mi: MeshInstance3D in rb.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh != null and mi.visible:
				noms.append(mi.mesh)
		var avec_gant := false
		var av2 := gm.get_node("ArmureVisible") as ArmureVisible
		for m: Mesh in noms:
			if av2.maillage("mains") != null and m == av2.maillage("mains").mesh:
				avec_gant = true
		_verif(avec_gant, "démembrement : le morceau emporte le gantelet porté")
	# jambe gauche tranchée : le tabard ne part pas avec le morceau et ne s'attache plus à la cuisse coupée
	var lv3 := GardeMaison.livree(gm)
	var rb2 := Demembrement.trancher(gm, "jambe_l", Vector3(-2, 0.5, 0), Color(0.5, 0, 0))
	if rb2 != null and lv3 != null:
		var copie := false
		for mi: MeshInstance3D in rb2.find_children("*", "MeshInstance3D", true, false):
			if mi.visible and mi.mesh == lv3.mesh:
				copie = true
		var sur_cuisse := false
		var sq3 := gm.find_child("Skeleton3D", true, false) as Skeleton3D
		for i in lv3.skin.get_bind_count():
			if String(lv3.skin.get_bind_name(i)) == "thigh_l":
				sur_cuisse = true
		_verif(not copie and not sur_cuisse and lv3.get_parent() == sq3 and lv3.visible, "démembrement : le tabard reste au corps (pas dans le morceau, attaches de la cuisse coupée passées au bassin)")
	else:
		_verif(false, "démembrement de la jambe d'un garde à tabard")
	var rg := Ragdoll.equiper(gm)
	_verif(rg != null, "ragdoll équipé sur le garde en armure")
	# butin : un garde tué laisse ses pièces
	var pc := PnjCombat.new()
	pc.est_garde = true
	pc.modele = gm
	var b: Dictionary = pc._contenu_butin()
	var toutes := true
	for id: String in GardeMaison.pieces_portees(gm):
		toutes = toutes and int(b.get(id, 0)) == 1
	_verif(toutes and b.has("pieces") and b.size() >= 4, "butin du garde : pièces d'or + armure portée %s" % [b])
	pc.free()
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	monde.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
