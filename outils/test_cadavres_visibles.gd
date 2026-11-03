extends SceneTree
## Tout corps FOUILLABLE a un modèle visible (bug « cadavre invisible mais je peux le fouiller », crypte) :
##   - un cadavre d'ennemi avec des objets encore à fouiller ne disparaît pas au bout de 30 s (draugr.gd, ennemi_base.gd) ;
##     il disparaît une fois fouillé ; son maillage est non vide, visible, au-dessus du sol ;
##   - une dépouille restaurée d'une sauvegarde (Butin.restaurer) porte un modèle (maillage non vide, visible, au-dessus du sol) ;
##   - chaque interaction « corps » de la crypte (Corps d'un compagnon, corps d'Eirik) a un personnage allongé à moins de 1,5 m.
##   godot --headless --path . --script res://outils/test_cadavres_visibles.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Maillages visibles (non vides, portée de dessin non nulle) sous `racine`.
## `dans_arbre` faux : on ignore la visibilité des ancêtres au-dessus de `racine` (zone de la crypte non chargée = légitime).
func _mailles_visibles(racine: Node, dans_arbre := true) -> Array:
	var r := []
	for n in racine.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and (mi.is_visible_in_tree() or (not dans_arbre and mi.visible)) and mi.get_aabb().size.length() > 0.01 and (mi.visibility_range_end == 0.0 or mi.visibility_range_end > 10.0) \
				and mi.layers != 0 and mi.transparency < 1.0:
			r.append(mi)
	return r

func _au_dessus_du_sol(racine: Node3D, y_sol: float) -> bool:
	for mi: MeshInstance3D in _mailles_visibles(racine):
		var a := mi.global_transform * mi.get_aabb()
		if a.end.y > y_sol - 0.05:
			return true
	return false

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	var t = m.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	var c: Node3D = t.crypte
	t.dedans = true
	c.visible = true
	m.joueur.global_position = c.to_global(Vector3(-21, 0.1, -12))
	for i in 4:
		t._gerer_zones()
		await physics_frame
	# --- 1. cadavres d'ennemis fouillables ; plafond à 1 cadavre non fouillé par zone (2e mort : le 1er devient une dépouille statique)
	var gardiens := []
	for id: String in m.draugrs:
		if id.begins_with("cr_") and is_instance_valid(m.draugrs[id]):
			gardiens.append(m.draugrs[id])
	_verif(gardiens.size() >= 2, "au moins deux gardiens de la crypte sont apparus (%d)" % gardiens.size())
	if gardiens.size() < 2:
		quit(1)
		return
	BUTIN.max_cadavres = 1
	var ga = gardiens[0]
	var gb = gardiens[1]
	var butins := []
	for g in [ga, gb]:
		g._mourir()
		for i in 5:
			await physics_frame
		var bu: Node3D = g._butin if "_butin" in g else null
		if bu == null:      # code sans le correctif : on retrouve la bourse parmi les enfants du parent
			for n in g.get_parent().get_children():
				if n.get_script() == BUTIN and n.has_method("a_fouille") and n.a_fouille():
					bu = n
		butins.append(bu)
		_verif(bu != null and bu.a_fouille(), "le cadavre laisse un corps fouillable (invite présente)")
	BUTIN.max_cadavres = 10
	# 1er cadavre : plafond dépassé -> ragdoll remplacé par sa dépouille statique (même endroit, modèle visible, sans physique)
	_verif(not is_instance_valid(ga) or ga.is_queued_for_deletion(), "plafond : le plus ancien ragdoll est retiré")
	var dep: Node = butins[0].get_node_or_null("ModeleDepouille") if butins[0] != null and is_instance_valid(butins[0]) else null
	_verif(dep != null, "plafond : sa dépouille statique est posée sur la bourse")
	if dep != null:
		_verif(not _mailles_visibles(dep).is_empty() and dep.find_children("*", "Skeleton3D", true, false).size() > 0, "dépouille du plafond : vrai modèle (squelette) visible")
		_verif(_au_dessus_du_sol(dep, (dep as Node3D).global_position.y), "dépouille du plafond : au-dessus du sol")
		_verif(Vector3((dep as Node3D).global_position).distance_to(butins[0].global_position) < 1.0, "dépouille du plafond : au pied de la bourse")
	_verif(butins[0] != null and is_instance_valid(butins[0]) and butins[0].a_fouille(), "plafond : la dépouille reste fouillable")
	# 2e cadavre : toujours un ragdoll, encore là après 30 s
	_verif(is_instance_valid(gb) and not gb.is_queued_for_deletion(), "dernier cadavre : ragdoll conservé")
	gb._t = 31.0
	for i in 5:
		await physics_frame
	_verif(is_instance_valid(gb) and not gb.is_queued_for_deletion(), "cadavre fouillable encore là après 30 s")
	if is_instance_valid(gb):
		_verif(not _mailles_visibles(gb).is_empty(), "cadavre : maillage visible et non vide (%d maillages)" % _mailles_visibles(gb).size())
		_verif(_au_dessus_du_sol(gb, gb.global_position.y - 1.0), "cadavre : au-dessus du sol")
	# fouillé en entier : plus d'invite, le cadavre part
	if butins[1] != null and is_instance_valid(butins[1]):
		butins[1].objets.clear()
		butins[1]._apres_fouille()
	if is_instance_valid(gb):
		gb._t = 31.0
	for i in 5:
		await physics_frame
	_verif(not is_instance_valid(gb) or gb.is_queued_for_deletion(), "cadavre fouillé : il disparaît au bout de 30 s")
	# --- 2. dépouille restaurée d'une sauvegarde : vrai modèle d'après le type sauvegardé (squelette, guerrier) ; ancienne sauvegarde : draugr
	ButinTables.reinitialiser()
	var base: Vector3 = m.joueur.global_position + Vector3(3, 0, 0)
	var specs := {"essai_sq": {"type": "squelette", "ident": "essai_sq", "lacet": 1.0}, "essai_gu": {"type": "guerrier", "lacet": 2.0}, "essai_vieux": null}
	var k := 0
	for id: String in specs:
		var cle := "ennemi:" + id
		var e := {"pos": [base.x + k * 2.0, base.y, base.z], "nom": "Draugr d'essai"}
		if specs[id] != null:
			e["modele"] = specs[id]
		ButinTables.corps[cle] = e
		ButinTables.restes[cle] = {"os_draugr": 1}
		k += 1
	# aller-retour JSON : le type survit à la sauvegarde
	var json := JSON.parse_string(JSON.stringify(ButinTables.exporter())) as Dictionary
	ButinTables.reinitialiser()
	ButinTables.importer(json)
	_verif(ButinTables.corps["ennemi:essai_sq"].get("modele", {}).get("type", "") == "squelette", "sauvegarde : le type du corps survit à l'export/import JSON")
	BUTIN.restaurer(m, m.joueur, m.hud)
	for i in 3:
		await physics_frame
	var restaures := m.get_tree().get_nodes_in_group("corps_butin")
	_verif(restaures.size() == 3, "3 dépouilles restaurées (%d)" % restaures.size())
	for rest: Node3D in restaures:
		var dm := rest.get_node_or_null("ModeleDepouille") as Node3D
		_verif(rest.a_fouille() and dm != null, "dépouille restaurée %s : invite de fouille + modèle" % rest.cle_sauvegarde)
		if dm != null:
			_verif(not _mailles_visibles(dm).is_empty() and dm.find_children("*", "Skeleton3D", true, false).size() > 0, "dépouille restaurée %s : vrai modèle visible (squelette)" % rest.cle_sauvegarde)
			_verif(dm.find_children("*", "MeshInstance3D", true, false).all(func(mi: MeshInstance3D) -> bool: return not (mi.mesh is BoxMesh)) and _au_dessus_du_sol(dm, dm.global_position.y), "dépouille restaurée %s : pas un bonhomme en blocs, au-dessus du sol" % rest.cle_sauvegarde)
	# --- 3. corps posés de la crypte (interactions « corps »)
	t.salles.tout_reveler()      # SalleActive cache le décor des salles éloignées : on se place « dans toutes les salles »
	var corps := 0
	for n in c.find_children("*", "Node3D", true, false):
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/interactif.gd" and String(n.get("verbe")).to_lower().contains("corps"):
			corps += 1
			var p: Vector3 = n.global_position
			var trouve := false
			for sk in c.find_children("*", "Skeleton3D", true, false):
				var modele_3d := sk.get_parent().get_parent() as Node3D      # racine du personnage (Armature > Skeleton3D)
				var d := Vector2(modele_3d.global_position.x - p.x, modele_3d.global_position.z - p.z).length()
				var n_vis := _mailles_visibles(modele_3d, false).size()
				print("      %s : d = %.2f m, dy = %.2f, maillages visibles = %d" % [modele_3d.get_path(), d, modele_3d.global_position.y - p.y, n_vis])
				if d < 1.5 and absf(modele_3d.global_position.y - p.y) < 1.5 and n_vis > 0:
					trouve = true
			_verif(trouve, "interaction « %s » (%s) : personnage allongé visible à moins de 1,5 m" % [n.get("verbe"), n.get("nom")])
	_verif(corps >= 1, "interactions « corps » trouvées dans la crypte (%d)" % corps)
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
