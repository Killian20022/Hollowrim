extends SceneTree
## Armes du catalogue (data/armes/catalogue_armes.json, CatalogueArmes) : chaque arme se charge, a ses stats (famille x matériau),
## ses repères (prise / garde / pointe ; boucliers : prise / umbo, face peinte vers +X), une longueur dans la plage de sa famille,
## tous ses matériaux habillés en PS1 ; c'est un objet du sac (nom, poids, valeur, rareté, catégorie arme) et une DonneesArme
## équipable dans la bonne main ; elle est trouvable (butin) et les tables / la forge restent valides ; cohérence de l'équilibrage
## (dague plus vive que l'épée, deux mains plus forte et plus lente, obsidienne plus forte que l'acier…).
##   godot --headless --path . --script outils/test_armes_catalogue.gd -- --nouvelle
var _echecs := 0

func _verifier(ok: bool, msg: String) -> void:
	if not ok:
		_echecs += 1
		print("ÉCHEC : ", msg)

func _local(racine: Node, n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != racine:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

## Boîte (repère de la racine) et étendue en y par matériau.
func _mesurer(racine: Node3D) -> Dictionary:
	var boite := AABB()
	var premier := true
	var par_mat := {}
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		var xf := _local(racine, mi)
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var nom := mat.resource_name.get_slice(".", 0) if mat else "?"
			var e: AABB = par_mat.get(nom, AABB())
			var prem_m := not par_mat.has(nom)
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := xf * v
				boite = AABB(p, Vector3.ZERO) if premier else boite.expand(p)
				premier = false
				e = AABB(p, Vector3.ZERO) if prem_m else e.expand(p)
				prem_m = false
			par_mat[nom] = e
	return {"boite": boite, "mats": par_mat}

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var err := CatalogueArmes.verifier()
	_verifier(err.is_empty(), "données du catalogue valides %s" % str(err))
	var ids := CatalogueArmes.ids()
	_verifier(ids.size() == 20, "20 armes au catalogue (8 hybrides + 12 CC0) : %d" % ids.size())
	for f in CatalogueArmes.FAMILLES:
		_verifier(not CatalogueArmes.ids_famille(f).is_empty(), "famille « %s » représentée" % f)
	_verifier(CatalogueArmes.ids_famille(CatalogueArmes.FAMILLE_DEUX_MAINS).size() >= 4, "plusieurs claymores (famille deux_mains) : %s" % str(CatalogueArmes.ids_famille("deux_mains")))
	var mats_ps1 := EpeesLongues.materiaux()
	_verifier(mats_ps1.has("saphir"), "matériau PS1 « saphir » (Croc-de-Givre) dans EpeesLongues")
	var eq := EquipementMains.new()
	print("%-16s %-11s %-10s %5s %5s %5s %5s %5s %5s %5s %5s  %s" % ["arme", "famille", "matériau", "léger", "lourd", "vit.", "allon", "inert", "poids", "val.", "garde", "longueur / repères"])
	for id in ids:
		var s := CatalogueArmes.stats(id)
		var f := Inventaire.objet(id)
		var fam := CatalogueArmes.famille_de(id)
		# objet du sac
		_verifier(not f.is_empty() and Inventaire.connu(id) and Inventaire.categorie_de(id) == "arme", "%s : objet du sac de catégorie arme" % id)
		_verifier(float(f.get("poids", 0)) > 0.0 and int(f.get("valeur", 0)) > 0 and String(f.get("nom", "")) != "" and String(f.get("nom", "")) != id, "%s : nom, poids et valeur %s" % [id, str(f)])
		# DonneesArme
		var d := eq.objet(id) as DonneesArme
		_verifier(d != null, "%s : DonneesArme équipable" % id)
		if d == null:
			continue
		_verifier(d == CatalogueArmes.donnees(id), "%s : une seule ressource (cache)" % id)
		_verifier(d.id == id and d.famille == fam and d.materiau == String(f["materiau"]), "%s : id / famille / matériau portés par la DonneesArme" % id)
		_verifier(ResourceLoader.exists(d.modele), "%s : modèle %s" % [id, d.modele])
		var main := "gauche" if fam == "bouclier" else "droite"
		_verifier(eq.refus(main, d) == "", "%s : va en main %s" % [id, main])
		_verifier(eq.refus("droite" if main == "gauche" else "gauche", d) != "", "%s : refusé dans l'autre main" % id)
		if fam == "bouclier":
			_verifier(d.categorie == DonneesArme.Categorie.BOUCLIER and EquipementMains.categorie_de(d) == "bouclier", "%s : catégorie bouclier" % id)
			_verifier(d.reduction_garde >= 0.85 and d.angle_garde >= 150.0, "%s : garde de bouclier (%.2f, %d°)" % [id, d.reduction_garde, d.angle_garde])
		else:
			_verifier(d.est_arme() and d.degats_leger > 0.0 and d.degats_lourd > d.degats_leger, "%s : dégâts %.1f / %.1f" % [id, d.degats_leger, d.degats_lourd])
			_verifier(d.vitesse > 0.5 and d.vitesse < 1.6 and d.cout_lourd > d.cout_leger, "%s : vitesse %.2f, endurance %.1f/%.1f" % [id, d.vitesse, d.cout_leger, d.cout_lourd])
			_verifier(is_equal_approx(d.degats_leger, float(s["degats_leger"])) and is_equal_approx(d.vitesse, float(s["vitesse"])) and is_equal_approx(d.allonge, float(s["allonge"])), "%s : stats du catalogue appliquées" % id)
		if fam == CatalogueArmes.FAMILLE_DEUX_MAINS or id == "grand_marteau":
			_verifier(d.deux_mains and EquipementMains.categorie_de(d) == "arme_deux_mains" and (d.profil == "deux_mains" or (id == "grand_marteau" and d.profil == "grand_marteau")), "%s : arme à deux mains (profil « deux_mains », ou « grand_marteau » : combat/gestes_lourds)" % id)
		elif fam != "bouclier":
			_verifier(not d.deux_mains, "%s : une main" % id)
		# modèle : chargement, repères, échelle, habillage
		var e: Node3D = (load(d.modele) as PackedScene).instantiate()
		root.add_child(e)
		EpeesLongues.habiller(e)
		var m := _mesurer(e)
		var b: AABB = m["boite"]
		var reps := {}
		for n in (["prise", "umbo"] if fam == "bouclier" else ["prise", "garde", "pointe"]):
			var r := e.find_child(n, true, false)
			_verifier(r != null, "%s : repère « %s » absent" % [id, n])
			reps[n] = _local(e, r).origin if r else Vector3.INF
		var longueur := b.size.y
		var plage: Array = CatalogueArmes.LONGUEURS[fam]
		_verifier(longueur >= float(plage[0]) and longueur <= float(plage[1]), "%s : longueur %.3f m hors de la plage %s de « %s »" % [id, longueur, str(plage), fam])
		if fam == "bouclier":
			_verifier(reps["prise"].length() < 0.001, "%s : prise à l'origine (poing gauche)" % id)
			_verifier(b.position.x > -0.06 and b.end.x > 0.08 and b.size.x < 0.25 and b.size.z > 0.5, "%s : face peinte vers +X, disque dans le plan YZ (boîte %s)" % [id, b])
			_verifier(reps["umbo"].x > 0.05, "%s : umbo devant le poing (+X)" % id)
		else:
			_verifier(reps["prise"].distance_to(Vector3(0, 0.03, 0)) < 0.002 and is_equal_approx(d.milieu_poignee, 0.03), "%s : prise au centre du poing (0 ; 0,03 ; 0) : %s" % [id, reps["prise"]])
			var cuir: AABB = m["mats"].get("cuir", m["mats"].get("fer", AABB()))
			_verifier(cuir.position.y < 0.0 and cuir.end.y > 0.07, "%s : la fusée (cuir) entoure le poing : y [%.3f ; %.3f]" % [id, cuir.position.y, cuir.end.y])
			_verifier(reps["garde"].y > 0.06 and reps["pointe"].y > reps["garde"].y + 0.15, "%s : garde %s sous la pointe %s" % [id, reps["garde"], reps["pointe"]])
			_verifier(reps["pointe"].y <= b.end.y + 0.01 and reps["pointe"].y > b.end.y - 0.25, "%s : pointe %.3f près du bout %.3f" % [id, reps["pointe"].y, b.end.y])
			_verifier(b.position.y < 0.0 and absf(b.get_center().z) < 0.03, "%s : pommeau sous le poing, arme dans le plan de la lame" % id)
		for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var nom := mi.mesh.surface_get_material(k).resource_name.get_slice(".", 0) if mi.mesh.surface_get_material(k) else "?"
				_verifier(mi.get_surface_override_material(k) is ShaderMaterial, "%s : surface %s (%s) non habillée en PS1" % [id, mi.name, nom])
		print("%-16s %-11s %-10s %5.1f %5.1f %5.2f %5.2f %5.2f %5.1f %5d %5.2f  %.2f m  %s" % [id, fam, f["materiau"], s["degats_leger"], s["degats_lourd"], s["vitesse"], s["allonge"], s["inertie"], s["poids"], s["valeur"], s["reduction_garde"], longueur, str(reps.values())])
		e.free()
	# équipement : deux mains libère la gauche ; bouclier à gauche
	var inv := Inventaire.new()
	for id in ids:
		inv.ajouter(id)
	var eq2 := EquipementMains.new(null, inv)
	_verifier(eq2.equiper("gauche", "bouclier_cercle") == "" and eq2.categorie("gauche") == "bouclier", "bouclier cerclé en main gauche")
	_verifier(eq2.equiper("droite", "epee_soldat") == "" and eq2.categorie("gauche") == "bouclier", "épée de soldat + bouclier")
	_verifier(eq2.equiper("droite", "claymore") == "" and eq2.categorie("gauche") == "vide" and eq2.categorie("droite") == "arme_deux_mains", "claymore : la main gauche se vide")
	var possedes := eq2.objets_possedes("armes")
	var manquants := ids.filter(func(x: String) -> bool: return not possedes.has(x))
	_verifier(manquants.is_empty(), "écran d'inventaire : les 20 armes du sac listées dans Armes (manquent %s)" % str(manquants))
	var eq3 := EquipementMains.new(null, Inventaire.new())
	if not eq3.catalogue.get("tout_disponible", false):
		_verifier(not eq3.objets_possedes("armes").has("claymore"), "sac vide : aucune arme du catalogue listée")
	_verifier(eq2.fiche("claymore")["lignes"][0].begins_with("Arme à deux mains"), "fiche : famille affichée (%s)" % str(eq2.fiche("claymore")["lignes"]))
	# équilibrage
	var st := func(id: String, cle: String) -> float: return float(CatalogueArmes.stats(id)[cle])
	_verifier(st.call("dague_acier", "vitesse") > st.call("epee_soldat", "vitesse") and st.call("dague_acier", "degats_leger") < st.call("epee_soldat", "degats_leger") and st.call("dague_acier", "allonge") < st.call("epee_soldat", "allonge"), "dague : plus vive, plus faible, plus courte qu'une épée")
	_verifier(st.call("claymore", "degats_lourd") > st.call("veilleuse", "degats_lourd") and st.call("claymore", "vitesse") < st.call("veilleuse", "vitesse") and st.call("claymore", "allonge") > st.call("veilleuse", "allonge"), "deux mains : plus forte, plus lente, plus d'allonge qu'une épée longue")
	_verifier(st.call("crocs_de_cendre", "degats_lourd") > st.call("veilleuse", "degats_lourd") and st.call("crocs_de_cendre", "vitesse") < st.call("veilleuse", "vitesse"), "obsidienne : plus forte et plus lente que l'acier")
	_verifier(st.call("larme_de_givre", "vitesse") > st.call("veilleuse", "vitesse") and st.call("larme_de_givre", "reduction_garde") < st.call("veilleuse", "reduction_garde"), "verre : plus rapide, garde plus faible")
	_verifier(st.call("dent_d_or", "valeur") > st.call("garde_du_guet", "valeur") and st.call("sang_du_roi", "valeur") > st.call("claymore", "valeur"), "or et uniques plus chers")
	_verifier(st.call("masse_cloutee", "desequilibre_lourd") > st.call("epee_soldat", "desequilibre_lourd") and CatalogueArmes.stats("masse_cloutee")["type_degats"] == "contondant", "masse : contondante, déséquilibre plus")
	var vm := (load("res://data/armes/epee_metal.tres") as DonneesArme)
	_verifier(absf(st.call("veilleuse", "degats_leger") / 1.05 - vm.degats_leger) < 0.2 and vm.famille == "epee_longue", "épée longue en acier du catalogue = épée de métal du jeu (%.1f / %.1f)" % [st.call("veilleuse", "degats_leger") / 1.05, vm.degats_leger])
	_verifier(CatalogueArmes.stats("croc_de_givre")["element"].get("statut", "") == "gel" and CatalogueArmes.stats("sang_du_roi")["element"].get("statut", "") == "brulure", "saphir gèle, rubis brûle")
	for id in ids:
		_verifier(st.call(id, "poids") <= 30.0, "%s : poids %.1f ≤ 30 (sac de 100)" % [id, st.call(id, "poids")])
	# butin et forge
	_verifier(ButinTables.verifier().is_empty(), "tables de butin valides %s" % str(ButinTables.verifier()))
	_verifier(Marchand.verifier().is_empty(), "données des marchands valides %s" % str(Marchand.verifier()))
	var trouvables := {}
	for t in ["armes_communes", "armes_rares", "armes_crypte"]:
		for i in 600:
			for o: Dictionary in ButinTables.tirer(t, 1000 + i):
				trouvables[o["id"]] = String(o["rarete"])
	var forge := []
	for ent: Dictionary in Marchand.fiche("forgeron").get("stock", []):
		forge.append(String(ent["id"]))
	var introuvables := ids.filter(func(x: String) -> bool: return not trouvables.has(x) and not forge.has(x))
	_verifier(introuvables.is_empty(), "chaque arme est trouvable (butin ou forge) : manquent %s" % str(introuvables))
	_verifier(trouvables.get("sang_du_roi", "") == "unique" and trouvables.get("croc_de_givre", "") == "unique", "Sang-du-Roi et Croc-de-Givre : uniques")
	var crypte_rares := [0, 0]
	for i in 2000:
		for k in 2:
			for o: Dictionary in ButinTables.tirer("coffre_crypte_riche", 30000 + i, "crypte" if k == 0 else "crypte_basse"):
				if CatalogueArmes.connu(String(o["id"])) and o["rarete"] in ["rare", "unique"]:
					crypte_rares[k] += 1
	_verifier(crypte_rares[1] > crypte_rares[0], "armes rares plus fréquentes dans la crypte basse (%d > %d)" % [crypte_rares[1], crypte_rares[0]])
	var boss_armes := 0
	for i in 500:
		for o: Dictionary in ButinTables.tirer("coffre_boss", 50000 + i):
			if CatalogueArmes.ids_famille("deux_mains").has(String(o["id"])):
				boss_armes += 1
	_verifier(boss_armes > 0, "le coffre du Jarl peut donner une claymore (%d sur 500)" % boss_armes)
	print("test_armes_catalogue : %s (ECHECS : %d)" % ["OK" if _echecs == 0 else "ÉCHEC", _echecs])
	quit(1 if _echecs > 0 else 0)
