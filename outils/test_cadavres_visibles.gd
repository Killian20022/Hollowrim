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
	# --- 1. cadavre d'ennemi fouillable : il reste après 30 s
	var gardien = null
	for id: String in m.draugrs:
		if id.begins_with("cr_") and is_instance_valid(m.draugrs[id]):
			gardien = m.draugrs[id]
			break
	_verif(gardien != null, "un gardien de la crypte est apparu")
	if gardien == null:
		quit(1)
		return
	gardien._mourir()
	for i in 5:
		await physics_frame
	var butin: Node3D = gardien._butin if "_butin" in gardien else null
	if butin == null:      # code sans le correctif : on retrouve la bourse parmi les enfants du parent
		for n in gardien.get_parent().get_children():
			if n.get_script() == BUTIN and n.has_method("a_fouille") and n.a_fouille():
				butin = n
	_verif(butin != null and butin.a_fouille(), "le cadavre laisse un corps fouillable (invite présente)")
	gardien._t = 31.0
	for i in 5:
		await physics_frame
	_verif(is_instance_valid(gardien) and not gardien.is_queued_for_deletion(), "cadavre fouillable encore là après 30 s")
	if is_instance_valid(gardien):
		var y_sol: float = gardien.global_position.y
		_verif(not _mailles_visibles(gardien).is_empty(), "cadavre : maillage visible et non vide (%d maillages)" % _mailles_visibles(gardien).size())
		_verif(_au_dessus_du_sol(gardien, y_sol - 1.0), "cadavre : au-dessus du sol")
	# fouillé en entier : plus d'invite, le cadavre part
	if butin != null and is_instance_valid(butin):
		butin.objets.clear()
		butin._apres_fouille()
	if is_instance_valid(gardien):
		gardien._t = 31.0
	for i in 5:
		await physics_frame
	_verif(not is_instance_valid(gardien) or gardien.is_queued_for_deletion(), "cadavre fouillé : il disparaît au bout de 30 s")
	# --- 2. dépouille restaurée d'une sauvegarde
	ButinTables.reinitialiser()
	var pos: Vector3 = m.joueur.global_position + Vector3(3, 0, 0)
	ButinTables.corps["ennemi:essai_cadavre"] = {"pos": [pos.x, pos.y, pos.z], "nom": "Draugr d'essai"}
	ButinTables.restes["ennemi:essai_cadavre"] = {"os_draugr": 1}
	BUTIN.restaurer(m, m.joueur, m.hud)
	for i in 3:
		await physics_frame
	var rest: Node3D = null
	for n in m.get_tree().get_nodes_in_group("corps_butin"):
		rest = n
	_verif(rest != null and rest.a_fouille(), "dépouille restaurée : invite de fouille")
	if rest != null:
		_verif(not _mailles_visibles(rest).is_empty(), "dépouille restaurée : maillage visible et non vide")
		_verif(_au_dessus_du_sol(rest, rest.global_position.y), "dépouille restaurée : au-dessus du sol")
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
