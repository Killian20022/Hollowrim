extends SceneTree
## Test sans fenêtre des VRAIES ARMES des ennemis (scripts/armes_ennemis.gd, data/armes/armes_ennemis.json, docs/ARMES_ENNEMIS.md) :
##   - données : toutes les armes existent au catalogue, aucune arme précieuse chez les ennemis communs, variété du tirage, graine STABLE ;
##   - gourdin : au catalogue (masse), modèle 1-3 k triangles, repères prise / garde / pointe ;
##   - corps : draugr (sbire, ancien), squelette, bandit (simple et costaud), gobelin, jarl : arme du catalogue dans la main droite, prise au
##     poing, jamais horizontale ni dans le corps, au repos, en marche, et pendant le coup ; même ennemi = même arme ;
##   - combat : stats de l'arme (portée / dégâts / rythme, bornés) ; la hache est plus lente que l'épée ; le draugr les applique ;
##   - mort : l'arme quitte la main, tombe À PLAT sur le terrain près du corps, entre dans le butin (même objet du catalogue), se ramasse en fouillant
##     et disparaît du sol quand elle est prise ; l'arme unique du jarl n'est pas lâchée ; la dépouille couchée (sauvegarde) porte la même arme au sol.
##   godot --headless --path . --script res://outils/test_armes_ennemis.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const PRECIEUX := ["or", "verre", "rubis", "obsidienne", "saphir", "emeraude", "argent"]
const ANIMS := ["Sword_Idle", "Walk", "Sword_Attack"]
var echecs := 0

func ok(c: bool, msg: String) -> void:
	print(("OK     " if c else "ECHEC  ") + msg)
	if not c:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _lancer() -> void:
	_donnees()
	_gourdin()
	await _corps()
	_combat()
	await _mort()
	print("ECHECS : %d" % echecs)
	quit(echecs)

# ------------------------------------------------------------------ données
func _donnees() -> void:
	var d := ArmesEnnemis.donnees()
	var profils: Dictionary = d.get("profils", {})
	ok(profils.size() >= 6, "profils d'ennemis lus (%s)" % str(profils.keys()))
	for nom: String in profils:
		var liste: Array = (profils[nom] as Dictionary).get("armes", [])
		var tous_connus := true
		var precieux := false
		for e: Dictionary in liste:
			var id := String(e["id"])
			tous_connus = tous_connus and ArmesEnnemis.connu(id)
			var mat := String(CatalogueArmes.entree(String(((d.get("uniques", {}) as Dictionary).get(id, {}) as Dictionary).get("modele_de", id))).get("materiau", ""))
			if PRECIEUX.has(mat) and nom != "jarl":
				precieux = true
		ok(tous_connus and not liste.is_empty(), "profil %s : %d armes, toutes au catalogue" % [nom, liste.size()])
		ok(not precieux, "profil %s : aucune arme précieuse (verre, or, rubis…)" % nom)
	for nom: String in ["draugr", "squelette", "bandit", "bandit_costaud"]:
		var vus := {}
		for i in 300:
			vus[ArmesEnnemis.tirer(nom, "ident_%d" % i)] = true
		ok(vus.size() >= 3, "profil %s : variété du tirage (%d armes différentes sur 300 ennemis : %s)" % [nom, vus.size(), str(vus.keys())])
	ok(ArmesEnnemis.tirer("draugr", "g1") == ArmesEnnemis.tirer("draugr", "g1") and ArmesEnnemis.tirer("bandit", "bandit_3") == ArmesEnnemis.tirer("bandit", "bandit_3"), "tirage à graine STABLE (même ident = même arme)")
	ok(ArmesEnnemis.tirer("jarl", "jarl") == "hache_kolbeinn" and not ArmesEnnemis.butin_possible("hache_kolbeinn"), "jarl : hache de Kolbeinn, jamais lâchée (déjà un objet unique du trône)")
	var has := {}
	for i in 12:
		has[ArmesEnnemis.tirer("squelette", "")] = true
	ok(has.size() >= 2, "sans ident : tirage propre à chaque appel")

# ------------------------------------------------------------------ gourdin
func _gourdin() -> void:
	ok(CatalogueArmes.connu("gourdin") and CatalogueArmes.famille_de("gourdin") == "masse", "gourdin : au catalogue, famille masse")
	var s := load(String(CatalogueArmes.entree("gourdin")["modele"])) as PackedScene
	var n := s.instantiate() as Node3D
	var t := _tris(n)
	ok(t >= 1000 and t <= 3000, "gourdin : %d triangles (1-3 k)" % t)
	ok(n.get_node_or_null("prise") != null and n.get_node_or_null("garde") != null and n.get_node_or_null("pointe") != null, "gourdin : repères prise / garde / pointe")
	var st := CatalogueArmes.stats("gourdin")
	var sm := CatalogueArmes.stats("masse_cloutee")
	ok(float(st["degats_leger"]) < float(sm["degats_leger"]) and float(st["valeur"]) < float(sm["valeur"]), "gourdin : plus faible et moins cher que la masse cloutée (%.1f < %.1f)" % [st["degats_leger"], sm["degats_leger"]])
	n.free()
	ok(CatalogueArmes.verifier().is_empty(), "catalogue : aucune erreur (%s)" % str(CatalogueArmes.verifier()))

# ------------------------------------------------------------------ corps
## [étiquette, spec EnnemisNordiques ou "squelette", profil attendu]
func _cas() -> Array:
	var app_d := {"corps": "homme", "draugr": true, "tenue": {}}
	var app_b := GrotteJeu.apparence_humain(1, "")
	var app_c := GrotteJeu.apparence_humain(2, "casque_nasal")
	return [
		["draugr", {"type": "sbire", "ident": "t_sbire", "apparence": app_d}],
		["draugr ancien", {"type": "guerrier", "ident": "t_guerrier", "apparence": EnnemisNordiques.apparence_defaut("guerrier")}],
		["bandit", {"type": "sbire", "ident": "t_bandit", "apparence": app_b}],
		["bandit costaud", {"type": "sbire", "ident": "t_costaud", "apparence": app_c}],
		["squelette", {"type": "squelette", "ident": "t_squelette"}],
		["jarl", {"type": "guerrier", "boss": "jarl", "ident": "jarl", "apparence": EnnemisNordiques.apparence_defaut("guerrier")}],
	]

func _modele(spec: Dictionary) -> Node3D:
	return EnnemisNordiques.squelette(spec) if String(spec["type"]).begins_with("squelette") else EnnemisNordiques.creer(spec)

func _corps() -> void:
	for c: Array in _cas():
		var spec: Dictionary = c[1]
		var n := _modele(spec)
		var id := ArmesEnnemis.arme_de(n)
		ok(id != "" and ArmesEnnemis.connu(id), "%s : arme du catalogue en main (%s)" % [c[0], id])
		var n2 := _modele(spec)
		ok(ArmesEnnemis.arme_de(n2) == id, "%s : même ennemi = même arme à chaque partie (%s)" % [c[0], ArmesEnnemis.arme_de(n2)])
		n2.free()
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var acc := sq.get_node_or_null("Arme") as BoneAttachment3D
		ok(acc != null and acc.bone_name == "hand_r", "%s : l'arme est dans la main droite (hand_r)" % c[0])
		var arme := acc.get_child(0) as Node3D if acc != null else null
		var ap := n.get_node("Animations") as AnimationPlayer
		ok(arme != null and arme.get_node_or_null("prise") != null and acc.get_node_or_null("Aplomb") != null, "%s : arme du catalogue (repères) + aplomb de la prise" % c[0])
		if arme == null:
			n.free()
			continue
		(acc.get_node("Aplomb") as Node).set("ap", ap)
		var main_os := sq.find_bone("hand_r")
		var pm := EnnemiTripo.poing_mesure(sq, "bandit" if c[0].begins_with("bandit") else String(spec.get("type", "")))
		var cm: Vector3 = pm["centre"]
		var am: Vector3 = pm["axe"]
		ok(cm.length() > 0.05 and am.length() > 0.99 and absf(am.dot(cm.normalized())) < 0.8, "%s : poing mesuré sur la main (à %.0f cm du poignet), manche dans le sens des articulations (%.0f° des doigts)" % [c[0], cm.length() * 100.0, rad_to_deg(acos(absf(am.dot(cm.normalized()))))])
		var t0 := Time.get_ticks_msec()
		for a: String in ANIMS:
			ap.play(a)
			ap.advance(0.35 if a != "Sword_Attack" else 0.3)
			for k in 45:
				await process_frame
			var pr := arme.get_node("prise") as Node3D
			var po := arme.get_node("pointe") as Node3D
			var v := po.global_position - pr.global_position
			var elev := rad_to_deg(asin(v.y / maxf(v.length(), 0.001)))
			var main_g := sq.global_transform * sq.get_bone_global_pose(main_os).origin
			var centre: Vector3 = (acc.get_node("Aplomb") as Node).get("centre")
			var poing_g := sq.global_transform * (sq.get_bone_global_pose(main_os) * centre)
			var d_poing := pr.global_position.distance_to(poing_g)
			ok(d_poing < 0.06 and centre.length() < 0.2, "%s / %s : la prise du manche est au creux du poing (%.1f cm du poing, poing à %.0f cm de l'os)" % [c[0], a, d_poing * 100.0, centre.length() * 100.0])
			# main fermée sur le manche : en travers des doigts (jamais « en broche » le long de l'avant-bras). Mesuré sur la pose réelle (tolérance : le
			# BoneAttachment3D a une image de retard sur un clip qui joue).
			if a != "Sword_Attack":
				var axe_m := v.normalized()
				var doigts_w := (sq.global_transform.basis * sq.get_bone_global_pose(main_os).basis * centre).normalized()
				var en_travers := rad_to_deg(acos(clampf(absf(axe_m.dot(doigts_w)), 0.0, 1.0)))
				ok(en_travers >= 30.0, "%s / %s : manche en travers des doigts, main fermée dessus (%.0f° des doigts)" % [c[0], a, en_travers])
			if a != "Sword_Attack":
				ok(absf(elev) >= 25.0, "%s / %s : arme ni horizontale ni couchée (élévation %.0f°)" % [c[0], a, elev])
			var tete := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head")).origin
			var bassin := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("pelvis")).origin
			var tronc := Vector2(bassin.x, bassin.z).distance_to(Vector2(po.global_position.x, po.global_position.z))
			ok(po.global_position.distance_to(tete) > 0.3 and po.global_position.distance_to(bassin) > 0.3, "%s / %s : la pointe ne traverse ni la tête ni le bassin (%.2f m du bassin)" % [c[0], a, po.global_position.distance_to(bassin)])
			var _t := tronc
		n.queue_free()
		await process_frame
	for id: String in ["epee_soldat", "hache_guerre", "hachette", "gourdin", "masse_cloutee", "sabre_pillard", "marteau_guerre", "dague_acier"]:
		var a := ArmesEnnemis.instancier(id)
		print("       %s : %d triangles" % [id, _tris(a)])
		a.free()
	var t := _tris(EnnemisNordiques.squelette({"type": "squelette", "ident": "t_squelette"}))
	ok(t < 16000, "squelette + arme : %d triangles (< 16 000)" % t)

# ------------------------------------------------------------------ combat
func _combat() -> void:
	var e := ArmesEnnemis.stats_combat("epee_soldat")
	var h := ArmesEnnemis.stats_combat("hache_guerre")
	var g := ArmesEnnemis.stats_combat("gourdin")
	var m := ArmesEnnemis.stats_combat("marteau_guerre")
	ok(absf(float(e["degats"]) - 1.0) < 0.01 and absf(float(e["rythme"]) - 1.0) < 0.01, "épée de soldat = référence (×1 dégâts, ×1 rythme)")
	ok(float(h["rythme"]) < float(e["rythme"]) and float(h["degats"]) >= float(e["degats"]), "hache de guerre : plus lente et plus mordante que l'épée (rythme %.2f, dégâts ×%.2f)" % [h["rythme"], h["degats"]])
	ok(float(g["degats"]) < 1.0 and float(g["degats"]) >= 0.8, "gourdin : moins de dégâts (×%.2f), dans les bornes" % g["degats"])
	ok(float(m["rythme"]) < float(h["rythme"]) + 0.001 and float(m["rythme"]) >= 0.8, "marteau : le plus lent (rythme %.2f)" % m["rythme"])
	for id: String in ["epee_soldat", "hache_guerre", "hachette", "gourdin", "masse_cloutee", "sabre_pillard", "marteau_guerre", "dague_acier"]:
		var s := ArmesEnnemis.stats_combat(id)
		ok(float(s["degats"]) >= 0.8 and float(s["degats"]) <= 1.35 and float(s["rythme"]) >= 0.8 and float(s["rythme"]) <= 1.12 and absf(float(s["portee"])) <= 0.2, "%s : stats dans les bornes (dégâts ×%.2f, rythme ×%.2f, portée %+.2f m)" % [id, s["degats"], s["rythme"], s["portee"]])

	# portée = longueur RÉELLE de l'arme (mesurée sur le modèle), pas une valeur écrite à la main
	var ids := ["epee_soldat", "hache_guerre", "hachette", "gourdin", "masse_cloutee", "sabre_pillard", "marteau_guerre", "dague_acier"]
	var lref := ArmesEnnemis.longueur("epee_soldat")
	ok(lref > 0.8 and lref < 1.3, "épée de soldat : longueur réelle mesurée %.2f m (0,8-1,3)" % lref)
	for id: String in ids:
		var lg := ArmesEnnemis.longueur(id)
		var st := ArmesEnnemis.stats_combat(id)
		var attendu := clampf((lg - lref) * 0.5, -0.2, 0.15)
		ok(lg > 0.3 and lg < 1.3 and absf(float(st["portee"]) - attendu) < 0.001, "%s : longueur réelle %.2f m -> portée %+.2f m (moitié de l'écart à l'épée)" % [id, lg, st["portee"]])
	ok(float(ArmesEnnemis.stats_combat("dague_acier")["portee"]) < float(ArmesEnnemis.stats_combat("hachette")["portee"]) + 0.001 and float(ArmesEnnemis.stats_combat("hachette")["portee"]) < 0.0, "portée : dague <= hachette < épée (plus l'arme est courte, plus l'ennemi doit s'approcher)")
	ok(ArmesEnnemis.longueur("sabre_pillard") > ArmesEnnemis.longueur("hache_guerre") and float(ArmesEnnemis.stats_combat("sabre_pillard")["portee"]) > float(ArmesEnnemis.stats_combat("hache_guerre")["portee"]), "portée : sabre plus long que la hache de guerre = portée plus grande")

# ------------------------------------------------------------------ mort et butin
func _mort() -> void:
	ButinTables.reinitialiser()
	var m: Node = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await process_frame
	m.joueur.global_position = Vector3(60, m.hauteur(60, 60) + 1.0, 60)
	var x := 4.0
	var z := -4.0
	var d: CharacterBody3D = m.creer_draugr("sbire", Vector3(x, m.hauteur(x, z) + 0.05, z), 0.0, false, {"ident": "t_mort_sbire", "vie_imposee": 10.0})
	for i in 20:
		await physics_frame
	var arme := String(d._arme)
	ok(arme != "" and ArmesEnnemis.arme_de(d.modele) == arme, "draugr en jeu : arme tenue %s" % arme)
	var st := ArmesEnnemis.stats_combat(arme)
	var ref := ReglagesCombat.degats("sbire")
	ok(absf(d.degats - ref * float(st["degats"])) < 0.01 and absf(d._portee - (d.PORTEE + float(st["portee"]))) < 0.001, "le draugr applique les stats de son arme (dégâts %.1f = %.1f × %.2f, portée %.2f m)" % [d.degats, ref, st["degats"], d._portee])
	var r: String = d.recevoir_coup(500.0, d.global_position + Vector3(-1.8, 0, 0), true)
	ok(r == "tue", "coup mortel (%s)" % r)
	var sq := d.modele.find_child("Skeleton3D", true, false) as Skeleton3D
	ok(sq.get_node_or_null("Arme") == null, "à la mort : plus d'arme dans la main")
	for i in 150:
		await physics_frame
	var corps: Node3D = null
	for b in get_nodes_in_group("corps_butin"):
		corps = b
	ok(corps != null and corps.objets.has(arme) and int(corps.objets[arme]) == 1, "le corps contient la même arme du catalogue (%s)" % (str(corps.objets) if corps != null else "?"))
	var sol := corps.get_node_or_null(ArmesEnnemis.SOL) as Node3D if corps != null else null
	ok(sol != null, "l'arme est posée au sol près du corps")
	if sol != null:
		var p := sol.global_position
		var y_sol: float = m.hauteur(p.x, p.z)
		ok(absf(p.y - y_sol) < 0.12, "arme POSÉE sur le terrain (%.3f m au-dessus du sol)" % (p.y - y_sol))
		var bas := 1e9
		var haut := -1e9
		for mi: MeshInstance3D in sol.find_children("*", "MeshInstance3D", true, false):
			var bb := mi.global_transform * mi.get_aabb()
			bas = minf(bas, bb.position.y)
			haut = maxf(haut, bb.end.y)
		ok(bas > y_sol - 0.06 and haut - bas < 0.2, "ni enfoncée dans le sol (%.3f) ni debout (hauteur %.2f m)" % [bas - y_sol, haut - bas])
		ok(p.distance_to(d.global_position) < 2.5, "tombée près du corps (%.2f m)" % p.distance_to(d.global_position))
	# se ramasse : fouille complète -> au sac, plus rien au sol
	if corps != null:
		corps.fouiller()
		var fb: FenetreButin = m.fenetre_butin
		fb.tout_prendre()
		await process_frame
		await process_frame
		ok(m.joueur.inventaire.a(arme), "l'arme se ramasse comme butin (%s au sac)" % m.joueur.inventaire.nom(arme))
		ok(sol == null or not is_instance_valid(sol) or sol.is_queued_for_deletion(), "arme prise : plus rien au sol")
	# dépouille statique (sauvegarde, plafond de cadavres) : même corps, l'arme est au sol et plus en main
	var bt := Node3D.new()
	bt.set_script(preload("res://scripts/butin.gd"))
	bt.joueur = m.joueur
	bt.hud = m.hud
	bt.contenu = {arme: 1}
	bt.modele_spec = d.spec_depouille()
	bt.cle_sauvegarde = "ennemi:t_dep"
	bt.add_child(preload("res://scripts/butin.gd").modele_depouille(bt.modele_spec, bt))
	m.add_child(bt)
	bt.global_position = Vector3(8, m.hauteur(8, 8) + 0.05, 8)
	await process_frame
	var dep_sq := bt.get_node("ModeleDepouille").find_child("Skeleton3D", true, false) as Skeleton3D
	ok(dep_sq.get_node_or_null("Arme") == null and bt.get_node_or_null(ArmesEnnemis.SOL) != null, "dépouille couchée : arme au sol près du corps, plus dans la main")
	# jarl : arme unique gardée en main (jamais lâchée)
	var j: CharacterBody3D = m.creer_draugr("guerrier", Vector3(-4.0, m.hauteur(-4.0, 4.0) + 0.05, 4.0), 0.0, false, {"boss": "jarl", "ident": "jarl", "vie_imposee": 10.0})
	for i in 10:
		await physics_frame
	ok(j._arme == "hache_kolbeinn" and ArmesEnnemis.arme_de(j.modele) == "hache_kolbeinn", "jarl : hache de Kolbeinn en main")
	var rj: String = j.recevoir_coup(500.0, j.global_position + Vector3(-1.8, 0, 0), true)
	if rj != "tue":
		rj = j.recevoir_coup(500.0, j.global_position + Vector3(-1.8, 0, 0), true)
	for i in 60:
		await physics_frame
	var cj: Node3D = null
	for b in get_nodes_in_group("corps_butin"):
		if b != corps and b != bt:
			cj = b
	print("       coup mortel sur le jarl : %s, etat %s" % [rj, str(j.etat)])
	print("       butin du jarl : %s" % (str(cj.objets) if cj != null else "aucun corps"))
	ok(rj == "tue" and (cj == null or (not cj.objets.has("hache_kolbeinn") and cj.get_node_or_null(ArmesEnnemis.SOL) == null)), "jarl mort : sa hache n'est pas lâchée (l'objet unique est sur le trône)")
