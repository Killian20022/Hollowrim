extends SceneTree
## Test des JAMBIÈRES (emplacement « jambes » d'EquipementCorps, scripts/rpg/armure_visible.gd _poser_chausses) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_jambieres.gd -- --nouvelle
##   - données : 10 paires, emplacement « jambes », glb porté (chausses/) et glb au sol (sol/), préset de matière valide, butin et boutique ;
##   - équipement : une paire va à « jambes » et à nul autre emplacement, se retire, se retrouve à l'export / l'import ;
##     SAUVEGARDE ANCIENNE (sans clé « jambes ») : valide, le torse reste porté ;
##   - affichage : torse sans jambières = chausses par défaut du torse ; jambières équipées = les remplacent (avec ou sans torse), la
##     tenue du héros au-dessus de la ceinture reste quand il n'y a pas de torse ; ôtées, les chausses par défaut reviennent.
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _heros(eq: EquipementCorps) -> Array:
	var h := HerosSkarnholt.creer({})
	root.add_child(h)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var porteur := Node.new()
	h.add_child(porteur)
	return [h, sq, ArmureVisible.equiper(porteur, sq, eq)]

func _lancer() -> void:
	var ids: Array = Inventaire.ids_connus().filter(func(id: String) -> bool: return Inventaire.emplacement_de(id) == "jambes")
	ok(ids.size() == 10, "10 paires de jambières au registre (%d)" % ids.size())
	var fautes := []
	for id: String in ids:
		var f := Inventaire.objet(id)
		var pre := String(f.get("preset_materiau", ""))
		if not (Inventaire.categorie_de(id) == "armure" and float(f.get("armure", 0)) > 0.0 and ArmureVisible.a_modele(id)
				and ResourceLoader.exists(ArmureVisible.chemin_sol(id)) and IconesCombat.connu(String(f.get("icone", "")))
				and (pre == "" or ArmureVisible.MATIERES.has(pre))):
			fautes.append(id)
	ok(fautes.is_empty(), "jambières : armure, glb porté, glb au sol, icône, préset de matière %s" % str(fautes))
	ok("jambes" in Inventaire.EMPLACEMENTS and EquipementCorps.new().emplacements.has("jambes"), "« jambes » est un emplacement de corps")
	# butin et boutique
	var tables := 0
	for f in ["res://data/butin/armures_paliers.json", "res://data/butin/sous_tables.json"]:
		tables += FileAccess.get_file_as_string(f).count("jambieres_")
	ok(tables >= 12, "jambières dans les tables de butin (%d entrées)" % tables)
	var stock := false
	for e: Dictionary in Marchand.fiche("forgeron").get("stock", []):
		stock = stock or String(e.get("id", "")).begins_with("jambieres_")
	ok(stock and Marchand.rachete("forgeron", "jambieres_acier_nordique"), "Brodd vend et rachète des jambières")
	# équipement
	var inv := Inventaire.new()
	var eq := EquipementCorps.new(inv)
	inv.ajouter("jambieres_fer", 1)
	inv.ajouter("cuirasse_fer", 1)
	ok(eq.equiper("jambieres_fer") == "" and eq.objet_a("jambes") == "jambieres_fer" and eq.objet_a("pieds") == "", "jambières : portées à « jambes » seulement")
	eq.equiper("cuirasse_fer")
	var ex := eq.exporter()
	var eq2 := EquipementCorps.new(inv)
	eq2.importer(ex)
	ok(eq2.objet_a("jambes") == "jambieres_fer" and eq2.objet_a("torse") == "cuirasse_fer", "export / import : jambières et torse retrouvés")
	var ancien := ex.duplicate()
	ancien.erase("jambes")
	var eq3 := EquipementCorps.new(inv)
	eq3.importer(ancien)
	ok(eq3.objet_a("torse") == "cuirasse_fer" and eq3.objet_a("jambes") == "", "ancienne sauvegarde (sans « jambes ») : valide, torse porté, pas de jambières")
	var pas_ici := ex.duplicate()
	pas_ici["pieds"] = "jambieres_fer"
	var eq4 := EquipementCorps.new(inv)
	eq4.importer(pas_ici)
	ok(eq4.objet_a("pieds") == "", "des jambières rangées aux « pieds » dans une sauvegarde sont ignorées")
	var armure_avant := eq.armure_totale()
	eq.retirer("jambes")
	ok(eq.armure_totale() < armure_avant, "les jambières comptent dans l'armure")
	inv.retirer("jambieres_fer", 1)
	# affichage
	var eqv := EquipementCorps.new(Inventaire.new())
	var r := _heros(eqv)
	var sq: Skeleton3D = r[1]
	var av: ArmureVisible = r[2]
	for id in ["armure_cuir", "jambieres_or", "jambieres_verre"]:
		eqv.inventaire.ajouter(id, 1)
	eqv.equiper("armure_cuir")
	ok(av.porte("jambes") == "chausses_cuir", "torse sans jambières : chausses par défaut du torse (%s)" % av.porte("jambes"))
	eqv.equiper("jambieres_or")
	var mj := av.maillage("jambes")
	ok(av.porte("jambes") == "jambieres_or" and mj != null and mj.get_parent() == sq, "jambières équipées : elles remplacent les chausses par défaut (%s)" % av.porte("jambes"))
	var mat := mj.get_surface_override_material(0) as ShaderMaterial if mj else null
	ok(mat != null and ArmureVisible.est_shader_armure(mat.shader) and mat.shader == ArmureVisible.shader_or(), "jambières d'or : matière HD et shader de brillance de l'or")
	eqv.equiper("jambieres_verre")
	mat = av.maillage("jambes").get_surface_override_material(0) as ShaderMaterial
	ok(mat != null and mat.shader == ArmureVisible.shader_gemme(), "jambières de verre : préset de la fiche, shader de brillance de la gemme")
	var p := sq.get_node_or_null("pantalon") as MeshInstance3D
	ok(p != null and p.mesh.surface_get_array_index_len(0) <= 3, "pantalon du héros entièrement retiré sous les jambières")
	eqv.retirer("jambes")
	ok(av.porte("jambes") == "chausses_cuir", "jambières ôtées : les chausses par défaut du torse reviennent")
	eqv.retirer("torse")
	ok(av.maillage("jambes") == null, "ni torse ni jambières : pas de chausses, tenue du héros")
	var tun := sq.get_node_or_null("tunique") as MeshInstance3D
	var tris_tunique: int = tun.mesh.surface_get_array_index_len(0) if tun else 0
	eqv.equiper("jambieres_or")
	var tun2 := sq.get_node_or_null("tunique") as MeshInstance3D
	var t2: int = tun2.mesh.surface_get_array_index_len(0) if tun2 else 0
	ok(av.porte("jambes") == "jambieres_or" and t2 > 0 and t2 < tris_tunique, "jambières seules : la tunique du héros reste au-dessus de la ceinture (%d / %d triangles), son bas est retiré" % [t2, tris_tunique])
	print("TEST JAMBIERES : %s (ECHECS : %d)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)
