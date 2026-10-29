extends SceneTree
## Lot L9 « objets uniques et armes exposées » (docs/INSPIRATION_IGNITE.md §2.14, §2.18), en deux processus comme test_sauvegarde :
##   -s res://outils/test_objets_uniques.gd -- ecrire    crypte : hache de Kolbeinn sur le trône (prise seulement après le Jarl),
##       épée d'obsidienne sur le râtelier de l'armurerie ; forge : Épée de Skarnholt sur le râtelier quand Brodd l'a forgée (quête
##       lames_brodd, étape « epee ») ; grotte : Croc-Rouge sur son chevalet ; prise = sac + modèle retiré + « ramasse:<objet> », jamais
##       deux fois ; coffre qui retirerait le même unique → pièces ; marchand (prix de rachat, objet de quête refusé) ; reflet de lame
##       (shader des lames) ; épée de Skarnholt à entrelacs ; « tout disponible » préparé (inventaire_hors_test) mais inchangé ; sauvegarde
##   -s res://outils/test_objets_uniques.gd -- verifier  rechargement : objets pris absents (modèles cachés, pas d'invite), au sac
const SCENE := preload("res://scenes/foret_test.tscn")
var FICHIER: String = load("res://scripts/monde.gd").fichier_test()

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred(OS.get_cmdline_user_args()[0])

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await process_frame

func _geo(n: Node) -> int:
	var k := n.find_children("*", "GeometryInstance3D", true, false).size()
	return k + (1 if n is GeometryInstance3D else 0)

func _tester(etape: String) -> void:
	if FICHIER == "user://sauvegarde.json" or load("res://scripts/monde.gd").fichier_sauvegarde() != FICHIER:
		print("TEST OBJETS UNIQUES : ÉCHEC (le jeu viserait la vraie sauvegarde, test annulé)")
		quit(1)
		return
	if etape == "ecrire":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	m.tertre.attendre_donjon()
	await _attendre(0.2)
	if etape == "ecrire":
		await _ecrire()
	else:
		await _verifier()
	print("ECHECS : %d" % _echecs)
	quit(_echecs)

func _ecrire() -> void:
	var t: Node3D = m.tertre
	var q: Node = m.quetes
	var inv: Inventaire = m.joueur.inventaire
	# --- modules Blender et données
	for mod in ["hache_kolbeinn", "presentoir_ratelier", "presentoir_socle"]:
		_verif(CrypteDecor.modele_existe(mod), "module %s présent dans objets_donjon.dat" % mod)
	for o in ObjetUnique.FICHES:
		var f := Inventaire.objet(o)
		_verif(String(f.get("rarete", "")) == "unique" and int(f.get("valeur", 0)) > 0, "%s : fiche unique, valeur %d" % [o, int(f.get("valeur", 0))])
	# --- crypte : hache sur le trône, obsidienne au râtelier
	var u: Dictionary = t._uniques
	_verif(u.has("unique_hache_kolbeinn") and u.has("unique_epee_obsidienne"), "crypte : %d objets uniques posés (%s)" % [u.size(), u.keys()])
	var hache: ObjetUnique = u.get("unique_hache_kolbeinn")
	var obs: ObjetUnique = u.get("unique_epee_obsidienne")
	if hache == null or obs == null:
		return
	_verif(hache.visible and _geo(hache) >= 1 and obs.visible and _geo(obs) >= 3, "crypte : modèles visibles (hache %d maillage(s), épée %d)" % [_geo(hache), _geo(obs)])
	var assise: Transform3D = t.d2.get_meta("trone_assise")
	var vers := assise.affine_inverse() * hache.position       # repère de l'assise : devant = +z
	_verif(vers.z > 0.4 and vers.z < 1.0 and vers.y > -0.5 and vers.y < 0.2 and absf(vers.x) < 0.7, "hache dressée contre le devant du trône (repère de l'assise %s)" % vers)
	var ih: Node3D = t._inter["unique_hache_kolbeinn"]
	_verif(not ih.condition.call(), "hache : pas d'invite tant que le Jarl vit")
	q.signaler("tue:jarl")
	_verif(ih.condition.call() and ih.verbe == "Prendre la hache", "hache : invite « %s » une fois le Jarl vaincu" % ih.verbe)
	var p0 := inv.pieces
	ih.parler()
	_verif(inv.nombre("hache_kolbeinn") == 1 and not hache.visible and ObjetUnique.pris("hache_kolbeinn") and q.vus.has("ramasse:hache_kolbeinn"),
		"hache prise : au sac, modèle retiré, « ramasse:hache_kolbeinn » signalé")
	_verif(not ih.condition.call(), "hache : plus d'invite une fois prise")
	ObjetUnique.prendre("hache_kolbeinn", inv, null, hache)
	_verif(inv.nombre("hache_kolbeinn") == 1 and inv.pieces == p0, "hache : jamais prise deux fois")
	var r := ButinTables.prendre(inv, [{"id": "hache_kolbeinn", "n": 1}])
	_verif(inv.nombre("hache_kolbeinn") == 1 and inv.pieces == p0 + 200 and r.size() == 1 and r[0]["id"] == "pieces", "un second exemplaire (coffre) devient %d pièces" % (inv.pieces - p0))
	# marchand : rachat à la valeur x 0,4 ; un objet de quête reste invendable
	_verif(Marchand.prix_vente("forgeron", "hache_kolbeinn") == 80 and Marchand.refus_vente("forgeron", "hache_kolbeinn", q) == "", "marchand : hache rachetée %d pièces" % Marchand.prix_vente("forgeron", "hache_kolbeinn"))
	_verif(Marchand.de_quete("fragment_sceau_os", q), "marchand : objet de quête toujours invendable")
	(t._inter["unique_epee_obsidienne"] as Node3D).parler()
	_verif(inv.a("epee_obsidienne") and not obs.visible, "obsidienne prise sur le râtelier de l'armurerie")
	# --- forge : Épée de Skarnholt
	var uf: ObjetUnique = m.unique_forge
	_verif(uf != null and not uf.visible, "forge : râtelier vide tant que Brodd n'a pas forgé l'épée")
	if uf != null:
		inv.ajouter("lame_antique", 3)
		q.signaler("parle:forgeron")
		q.signaler("objet:lame_antique>=3")
		q.repliques("forgeron")       # Brodd forge l'épée (étape « fin »)
		await process_frame
		_verif(int(q.etat.get("lames_brodd", -1)) == 3 and uf.visible and not inv.a("epee_skarnholt"), "forge : l'épée attend sur le râtelier (étape %d)" % int(q.etat.get("lames_brodd", -1)))
		var rp: Array = q.repliques("forgeron")
		_verif(not rp.is_empty() and String(rp[0]).contains("râtelier"), "forge : Brodd renvoie au râtelier (« %s »)" % (rp[0] if not rp.is_empty() else ""))
		var itf: Node3D = null
		for c in uf.get_parent().get_parent().get_children():
			if c.get("verbe") == "Prendre l’épée":
				itf = c
		_verif(itf != null and itf.condition.call(), "forge : invite « Prendre l’épée »")
		if itf != null:
			itf.parler()
		await process_frame
		_verif(inv.a("epee_skarnholt") and not uf.visible and not q.en_cours("lames_brodd"), "forge : épée prise, quête terminée (étape %d)" % int(q.etat.get("lames_brodd", -1)))
	# --- épée de Skarnholt : modèle à entrelacs, reflet de lame
	var a: DonneesArme = load("res://data/armes/epee_skarnholt.tres")
	var e := EpeesLongues.instancier("skarnholt")
	var mats := {}
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var sm := mi.get_surface_override_material(s)
			for k in EpeesLongues.materiaux():
				if EpeesLongues.materiaux()[k] == sm:
					mats[k] = true
	_verif(a.modele.ends_with("skarnholt.glb") and a.habillage == "epees_longues" and mats.has("entrelacs") and mats.has("lame") and EpeesLongues.repere(e, "pointe") != null,
		"épée de Skarnholt : glb à entrelacs habillé (%s)" % [mats.keys()])
	e.free()
	var lame: ShaderMaterial = EpeesLongues.materiaux()["lame"]
	_verif(lame.shader == EpeesLongues.shader_reflet() and lame.shader.code.contains("reflet_force") and EpeesLongues.materiaux()["obsidienne"].shader == EpeesLongues.shader_reflet(),
		"reflet de lame : lame, lame_or et obsidienne sur le shader à reflet")
	# --- fin du « tout disponible » (2026-10-29) : les épées se gagnent, l'épée de départ reste
	var eq := EquipementMains.new(null, Inventaire.new())
	_verif(not bool(eq.catalogue.get("tout_disponible", true)), "« tout disponible » terminé (inventaire.json)")
	var sans := eq.objets_possedes("armes")
	eq.inventaire.ajouter("epee_or")
	eq.inventaire.ajouter("epee_hrafn")
	var avec := eq.objets_possedes("armes")
	_verif(not sans.has("epee_or") and not sans.has("epee_skarnholt") and not sans.has("epee_hrafn") and avec.has("epee_or") and avec.has("epee_hrafn") and sans.has("epee") and sans.has("torche"),
		"épées gagnées (achat, butin, objets uniques) équipables ; épée et torche de départ présentes")
	_verif(eq.sorts_connus.size() == 7 and eq.sorts_connus.has("soin") and eq.sorts_connus.has("jet_flammes") and not eq.sorts_connus.has("boule_feu"), "sorts de départ seulement (%d)" % eq.sorts_connus.size())
	# tomes partout : chaque sort hors départ a un tome qui l'apprend
	var sans_tome: Array[String] = []
	var depart: Array = eq.catalogue.get("sorts_depart", [])
	var tout := EquipementMains.new(null, null)
	tout.apprendre_tout()
	for id in tout.sorts_connus:
		if not depart.has(id) and Inventaire.objet("tome_" + id).is_empty():
			sans_tome.append(id)
	_verif(sans_tome.is_empty(), "un tome pour chaque sort hors départ (manque : %s)" % str(sans_tome))
	# --- grotte : Croc-Rouge
	var ga: Node3D = m.grotte_acces
	ga.attendre_exterieur()
	ga.obtenir()
	ga.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _attendre(0.5)
	var jeu: GrotteJeu = ga.jeu
	var uh: ObjetUnique = jeu.uniques.get("epee_hrafn")
	_verif(uh != null and uh.visible and _geo(uh) >= 3, "grotte : Croc-Rouge posé sur son chevalet")
	if uh != null:
		(jeu.interactifs["unique_epee_hrafn"] as Node3D).parler()
		_verif(inv.a("epee_hrafn") and not uh.visible, "grotte : Croc-Rouge pris")
		var eq2: EquipementMains = m.joueur.mains.magie.eq if m.joueur.mains.get("magie") != null else null
		if eq2 != null:
			_verif(eq2.objets_possedes("armes").has("epee_hrafn"), "Croc-Rouge listé dans les armes de l'inventaire")
	m.sauvegarder()

func _verifier() -> void:
	var t: Node3D = m.tertre
	var inv: Inventaire = m.joueur.inventaire
	var u: Dictionary = t._uniques
	var tous := true
	for id in u:
		tous = tous and not (u[id] as ObjetUnique).visible and not (t._inter[id] as Node3D).condition.call()
	_verif(u.size() >= 2 and tous, "rechargement : objets uniques de la crypte absents, sans invite (%d)" % u.size())
	_verif(inv.nombre("hache_kolbeinn") == 1 and inv.a("epee_obsidienne") and inv.a("epee_skarnholt") and inv.a("epee_hrafn"), "rechargement : les quatre uniques au sac")
	_verif(m.unique_forge != null and not m.unique_forge.visible, "rechargement : râtelier de la forge vide")
	m.tertre.reinitialiser([])      # mort sous terre : rien ne revient
	_verif(not (u["unique_hache_kolbeinn"] as ObjetUnique).visible, "mort du joueur : la hache ne réapparaît pas")
	var ga: Node3D = m.grotte_acces
	ga.attendre_exterieur()
	ga.obtenir()
	ga.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _attendre(0.5)
	var uh: ObjetUnique = ga.jeu.uniques.get("epee_hrafn")
	_verif(uh != null and not uh.visible, "rechargement : chevalet de Hrafn vide")
