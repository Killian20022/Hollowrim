extends SceneTree
## Objets physiques dans le monde (scripts/rpg/objet_monde.gd, etal_marchand.gd, bijoux_materiaux.gd ; Lacher / Butin « lache: ») :
##   godot --headless --path . --script res://outils/test_objets_monde.gd -- --nouvelle

const SCENE := preload("res://scenes/foret_test.tscn")
const BIJOUX := ["amulette_givre", "amulette_ours", "amulette_arcaniste", "collier_portefaix", "anneau_coureur", "anneau_adepte",
	"anneau_braise", "anneau_orage", "anneau_berserker", "anneau_marchand"]

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _mailles(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)

func _tester() -> void:
	# --- bijoux : fiche, glb, matériaux, pivot au sol
	var manque: Array = []
	var mauvais_mat: Array = []
	for b: String in BIJOUX:
		var f := Inventaire.objet(b)
		var c := ObjetMonde.chemin_modele(b)
		if String(f.get("modele", "")) == "" or c != String(f["modele"]):
			manque.append(b)
			continue
		var v := ObjetMonde.visuel(b, "studio")
		root.add_child(v)
		for mi: MeshInstance3D in _mailles(v):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s) as ShaderMaterial
				if m == null or m.shader == null:
					mauvais_mat.append("%s:%d" % [b, s])
		var bx := ObjetMonde.boite(v, Transform3D.IDENTITY)
		if absf(bx.position.y) > 0.002 or bx.size.x > 0.3 or bx.size.x < 0.015:
			manque.append("%s (boîte %s)" % [b, bx])
		v.free()
	_verif(manque.is_empty(), "10 bijoux : champ modele = glb présent, pivot au sol, taille réelle (%s)" % str(manque))
	_verif(mauvais_mat.is_empty(), "bijoux : toutes les surfaces en matériau ps1 / shader_matiere (%s)" % str(mauvais_mat))
	var vs := ObjetMonde.visuel("anneau_braise", "studio")
	var vg := ObjetMonde.visuel("anneau_braise", "sol")
	var ts := ObjetMonde.boite(vs, Transform3D.IDENTITY).size.x
	var tg := ObjetMonde.boite(vg, Transform3D.IDENTITY).size.x
	_verif(tg > ts * 2.5, "au sol, un anneau est exagéré (×%.2f) pour rester lisible" % (tg / ts))
	vs.free()
	vg.free()

	# --- arme couchée, accessoires, repli
	var ep := ObjetMonde.visuel("epee_or", "sol")
	root.add_child(ep)
	var be := ObjetMonde.boite(ep, Transform3D.IDENTITY)
	_verif(not ep.has_meta("repli") and be.size.y < 0.12 and maxf(be.size.x, be.size.z) > 0.7 and absf(be.position.y) < 0.002,
		"épée en or couchée à plat au sol (boîte %.2f x %.2f x %.2f)" % [be.size.x, be.size.y, be.size.z])
	ep.free()
	var ra := ObjetMonde.visuel("epee_or", "ratelier")
	var br := ObjetMonde.boite(ra, Transform3D.IDENTITY)
	_verif(br.size.y > 0.7 and absf(br.position.y) < 0.002, "épée au râtelier : debout, pommeau à y = 0 (hauteur %.2f)" % br.size.y)
	ra.free()
	var po := ObjetMonde.visuel("potion_soin", "sol")
	_verif(not po.has_meta("repli") and _mailles(po).size() >= 3, "potion : fiole en primitives (pas la sacoche)")
	po.free()
	var mi := ObjetMonde.visuel("minerai_fer", "sol")
	_verif(mi.has_meta("repli") and _mailles(mi).size() >= 3, "objet sans modèle (minerai) : repli sacoche")
	mi.free()
	var nb_armures := 0
	var avec_sol := 0
	for oid: String in Inventaire.ids_connus():
		if Inventaire.categorie_de(oid) == "armure":
			nb_armures += 1
			if ObjetMonde.chemin_modele(oid) != "":
				avec_sol += 1
	print("INFO   armures avec modèle au sol : %d / %d" % [avec_sol, nb_armures])
	var tas := ObjetMonde.tas({"anneau_braise": 1, "epee_or": 1, "potion_mana": 2, "minerai_fer": 3, "amulette_ours": 1, "tome_boule_feu": 1, "collier_portefaix": 1})
	_verif(tas.get_child_count() == ObjetMonde.MAX_TAS + 1, "tas de 7 objets : %d montrés + sacoche (%d nœuds)" % [ObjetMonde.MAX_TAS, tas.get_child_count()])
	tas.free()

	# --- étal : choix des pièces exposées
	var stock := {"epee_or": 1, "epee_rubis": 1, "minerai_fer": 5, "casque_fer": 1, "anneau_cuivre": 2, "bouclier_cercle": 1, "dague_acier": 1, "claymore": 1}
	var ch := EtalMarchand.choisir(stock)
	var ok_ch := ch.size() <= EtalMarchand.MAX_PIECES and ch.size() >= 2 and not ("minerai_fer" in ch)
	for oid in ch:
		ok_ch = ok_ch and ObjetMonde.a_modele(oid)
	_verif(ok_ch and EtalMarchand._nb_longues(ch) <= EtalMarchand.MAX_LONGUES, "étal : %d pièces à modèle, variées, 2 armes couchées au plus (%s)" % [ch.size(), ", ".join(ch)])
	_verif(EtalMarchand.choisir({"potion_soin": 3, "tome_lance_givre": 1, "pain_seigle": 4, "champignon_lumineux": 2}).size() == 3, "étal de Grima : fiole, livre, miche (pas le champignon)")

	# --- en jeu : lâcher un bijou -> l'objet au sol ; objet ramassable ; étals posés au village
	ButinTables.reinitialiser()
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	await _images(30)
	var j: CharacterBody3D = s.joueur
	var inv: Inventaire = j.inventaire
	inv.ajouter("amulette_ours", 1)
	_verif(Lacher.lacher(j, s.hud, "amulette_ours", 1) == "", "lâcher l'amulette de l'ours")
	await _images(3)
	var sac: Node3D = null
	for n in s.find_children("*", "Node3D", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("butin.gd") and String(n.cle_sauvegarde).begins_with("lache:"):
			sac = n
	var vis: Node3D = sac.get_node_or_null("Visuel") if sac != null else null
	var vu_glb := false
	if vis != null:
		for m: MeshInstance3D in _mailles(vis):
			vu_glb = vu_glb or m.mesh is ArrayMesh
	_verif(vis != null and vu_glb and not vis.find_child("Sacoche", true, false), "au sol : l'amulette elle-même (glb), pas un sac")
	var om := ObjetMonde.creer("anneau_adepte", 1, j, s.dialogue)
	s.add_child(om)
	om.global_position = j.global_position + Vector3(1, 0, 0)
	await _images(2)
	var avant := inv.nombre("anneau_adepte")
	om.prendre(inv)
	await _images(2)
	_verif(inv.nombre("anneau_adepte") == avant + 1 and not is_instance_valid(om), "objet posé ramassé : au sac, retiré du monde")
	var etals := s.find_children("Etal_*", "Node3D", true, false)
	var pieces := 0
	for e in etals:
		pieces += e.get_node("Pieces").get_child_count() if e.has_node("Pieces") else 0
	_verif(etals.size() == 2 and pieces >= 4, "étals de Brodd et Grima posés au village (%d étals, %d pièces exposées)" % [etals.size(), pieces])
	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
