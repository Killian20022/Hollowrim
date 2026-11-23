extends SceneTree
## CASSABLES PARTOUT (scripts/casse_objets.gd, objet_vivant.gd, objets_vivants.gd MEUBLES/FRAGILES, cassable.gd recevoir_choc) :
##   - recensement : mobilier léger physique (tonneaux, caisses, cageots, tabourets, chaises, bancs, jarres, sacs) dans les intérieurs,
##     sur la place, au marché et aux abords ; tous endormis (gelés), dans le groupe « telekinesable » avec leur masse ;
##   - casse : un tonneau, une jarre, une chaise cassent sous un choc suffisant (recevoir_choc), PAS sous un petit choc ; caisse de fer
##     incassable ; vrais morceaux (éclats physiques) qui se gèlent ; instance cachée, collision retirée ; état « casse » sauvegardé ;
##     partie neuve : l'objet revient entier ; coup d'épée sur une jarre (fragile) ; urne de la crypte (Cassable.recevoir_choc) ;
##   - perf de sommeil : aucun corps du monde éveillé au repos ; éclats tous gelés quelques secondes après la casse ; plafond d'éclats.
##   godot --headless --path . --script res://outils/test_cassables_partout.gd -- --nouvelle

const SCENE := preload("res://scenes/foret_test.tscn")

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
		await physics_frame

func _premier(genres: Array, lieu := "") -> ObjetVivant:
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.genre in genres and not o.casse and (lieu == "" or o.ident.begins_with(lieu)):
			return o
	return null

func _tester() -> void:
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	for i in 1800:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	await _images(20)
	var j: CharacterBody3D = s.joueur

	# --- recensement
	var tous := ObjetsVivants._vivants()
	var meubles := tous.filter(func(o: ObjetVivant) -> bool: return o.meuble)
	var par_lieu := {}
	for o: ObjetVivant in meubles:
		var l := o.ident.get_slice(":", 0)
		par_lieu[l] = int(par_lieu.get(l, 0)) + 1
	var fragiles := tous.filter(func(o: ObjetVivant) -> bool: return not o.meuble and o.seuil_casse < INF)
	print("INFO   meubles par lieu : ", par_lieu)
	var petits := {}
	for o: ObjetVivant in tous:
		if not o.meuble:
			var l := o.ident.get_slice(":", 0)
			var c: Array = petits.get(l, [0, 0])
			c[0] += 1
			c[1] += 1 if o.seuil_casse < INF else 0
			petits[l] = c
	print("INFO   petits objets par lieu [tous, fragiles] : ", petits)
	print("INFO   %d objets vivants, dont %d meubles et %d petits objets fragiles" % [tous.size(), meubles.size(), fragiles.size()])
	_verif(meubles.size() >= 60 and par_lieu.has("village") and par_lieu.has("halle"), "%d meubles physiques (village, halle… : %s)" % [meubles.size(), str(par_lieu.keys())])
	_verif(fragiles.size() >= 10, "%d petits objets fragiles (cruches, bouteilles, potions…)" % fragiles.size())
	var dans_groupe := tous.all(func(o: ObjetVivant) -> bool: return o.is_in_group("telekinesable") and o.has_method("masse_telekinesie") and o.has_method("saisi_telekinesie") and o.has_method("recevoir_choc"))
	_verif(dans_groupe, "tous les objets vivants sont « telekinesable » (masse_telekinesie, saisi_telekinesie, recevoir_choc)")
	var gel := tous.all(func(o: ObjetVivant) -> bool: return o.freeze)
	var eveilles := tous.filter(func(o: ObjetVivant) -> bool: return not o.freeze).size()
	_verif(gel, "au repos, aucun objet éveillé (%d / %d)" % [eveilles, tous.size()])
	var actifs := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	print("INFO   corps physiques actifs dans le monde : %d" % actifs)

	var tonneau := _premier(["q_tonneau", "pq_tonneau", "q_tonneau_2"], "halle")
	if tonneau == null:
		tonneau = _premier(["q_tonneau", "pq_tonneau", "q_tonneau_2"])
	var jarre := _premier(["q_jarre", "pq_jarre"])
	var chaise := _premier(["q_chaise", "pq_chaise", "q_chaise_2", "q_tabouret", "pq_tabouret"])
	_verif(tonneau != null and jarre != null and chaise != null, "trouvés : tonneau %s, jarre %s, chaise %s" % [
		tonneau.ident if tonneau else "-", jarre.ident if jarre else "-", chaise.ident if chaise else "-"])
	if tonneau == null or jarre == null or chaise == null:
		_fin()
		return
	_verif(tonneau.masse_telekinesie() > 25.0 and chaise.masse_telekinesie() < 10.0 and tonneau.bloque and tonneau.collision_layer & 1,
		"masses : tonneau %.0f kg (bloque le passage, calque 1), chaise %.1f kg, jarre %.1f kg" % [tonneau.mass, chaise.mass, jarre.mass])

	# --- petits chocs : rien ne casse
	for o: ObjetVivant in [tonneau, jarre, chaise]:
		j.global_position = o.global_position + Vector3(0, 0.5, 2.5)
		await _images(3)
		var r := o.recevoir_choc(Vector3(1.5, 0, 0), 0.4, o.global_position)      # une chope qui le heurte à 1,5 m/s
		_verif(not r and not o.casse, "%s : petit choc (%.1f J) sans casse" % [o.genre, CasseObjets.energie(Vector3(1.5, 0, 0), 0.4)])
	var r2 := tonneau.recevoir_choc(Vector3(3.0, 0, 0), 5.0, tonneau.global_position)      # 22 J : encore trop peu pour un tonneau
	_verif(not r2 and not tonneau.casse, "tonneau : choc moyen (22 J) sans casse (seuil %.0f J)" % tonneau.seuil_casse)

	# --- chocs suffisants : chaque objet casse en vrais morceaux
	var mm_avant := 0
	for o: ObjetVivant in [tonneau, jarre, chaise]:
		j.global_position = o.global_position + Vector3(0, 0.5, 2.5)
		await _images(3)
		var n0 := CasseObjets.nb_eclats()
		var t0 := Time.get_ticks_usec()
		var ok := o.recevoir_choc(Vector3(0, 0, -9.0), 12.0, o.global_position + Vector3(0, 0.3, 0.4))      # 486 J
		var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var n_ecl := CasseObjets.nb_eclats() - n0
		var cache := not o.visible      # (l'instance du MultiMesh est mise à l'échelle 0 ; relue du serveur de rendu, elle arrive une image plus tard)
		print("INFO   %s : coût de la casse %s, dont morceaux (maillages) %.1f ms" % [o.genre, str(CasseObjets.derniere_mesure), CasseObjets.derniere_decoupe_ms])
		_verif(ok and o.casse and n_ecl >= 3 and cache and o.collision_layer == 0,
			"%s : casse sous 486 J en %d morceaux (%.1f ms), instance cachée (%s), collision retirée (%d)" % [o.genre, n_ecl, dt_ms, cache, o.collision_layer])
		_verif((ObjetsVivants.etats.get(o.ident, {}) as Dictionary).has("casse"), "%s : état « casse » retenu pour la sauvegarde" % o.genre)
	# éclats : retombent puis se gèlent (aucun coût physique)
	var gele_en := -1
	for i in 600:
		await physics_frame
		if CasseObjets.nb_eclats_eveilles() == 0:
			gele_en = i
			break
	_verif(gele_en >= 0, "éclats tous gelés %d images après la casse (%d éclats au sol)" % [gele_en, CasseObjets.nb_eclats()])

	# --- liquide : la flaque du tonneau brisé est posée sur le plancher sous lui ; brisé en l'air au-dessus du vide : aucune flaque
	var flaques := get_nodes_in_group("flaques")
	var sol_t := tonneau.global_position.y - tonneau._taille.y * 0.5
	var bonne := flaques.any(func(f: Node3D) -> bool: return absf(f.global_position.y - sol_t) < 0.15 and Vector2(f.global_position.x - tonneau.global_position.x, f.global_position.z - tonneau.global_position.z).length() < 1.0)
	_verif(bonne, "tonneau : flaque posée au sol sous lui (%d flaques)" % flaques.size())
	var n_av := get_nodes_in_group("flaques").size()
	CasseObjets.verser_liquide(s, Vector3(0, 900, 0), Vector3.UP, 1.0)
	await _images(90)
	_verif(get_nodes_in_group("flaques").size() <= n_av, "liquide versé à 900 m au-dessus de tout : aucune flaque en l'air")
	_verif(get_nodes_in_group("flaques").all(func(f: Node3D) -> bool: return _sous_surface(f)), "toutes les flaques reposent sur une surface (rayon vers le bas sous leur centre)")

	# --- fer : incassable
	var fer: ObjetVivant = null
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.matiere == "fer" and not o.casse:
			fer = o
			break
	if fer != null:
		_verif(not fer.recevoir_choc(Vector3(0, 0, -12), 40.0, fer.global_position) and not fer.casse, "%s (fer) : 2 880 J sans casse (il sonne)" % fer.genre)
	else:
		_verif(false, "aucun objet de fer trouvé")

	# --- coup d'épée sur un objet fragile, et sur un tonneau (ne casse pas)
	var jarre2 := _premier(["q_jarre", "pq_jarre"])
	if jarre2 != null:
		j.global_position = jarre2.global_position + Vector3(0, 0.5, 2.0)
		await _images(3)
		_verif(jarre2.frapper(false, jarre2.global_position + Vector3(0, 0.4, 0.6)) and jarre2.casse, "jarre : un coup d'épée léger la brise")
	var tonneau2 := _premier(["q_tonneau", "pq_tonneau", "q_tonneau_2"])
	if tonneau2 != null:
		j.global_position = tonneau2.global_position + Vector3(0, 0.5, 2.0)
		await _images(3)
		tonneau2.frapper(true, tonneau2.global_position + Vector3(0, 0.4, 0.6))
		_verif(not tonneau2.casse, "tonneau : un coup d'épée puissant ne le brise pas (il cogne)")

	# --- sauvegarde : l'export garde les objets brisés ; partie neuve : ils reviennent entiers
	var exp := ObjetsVivants.exporter()
	_verif((exp.get(tonneau.ident, {}) as Dictionary).has("casse") and (exp.get(chaise.ident, {}) as Dictionary).has("casse"), "export : tonneau et chaise notés brisés")
	ObjetsVivants.reinitialiser()
	_verif(not tonneau.casse and tonneau.visible and tonneau.collision_layer & 1 and tonneau.freeze, "partie neuve : le tonneau revient entier, gelé, bloquant")
	ObjetsVivants.importer(exp)
	_verif(tonneau.casse and chaise.casse, "chargement : brisés de nouveau, sans effets")

	# --- urne de la crypte (Cassable.recevoir_choc)
	var c := Cassable.new()
	var v := PackedVector3Array([Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0), Vector3(0, 0.5, 0.1), Vector3(0, 0, -0.2), Vector3(0.2, 0, 0), Vector3(0, 0.5, 0.1)])
	var nn := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uu := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var cc := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	c.monter("test:urne_0", "urne", 1.0, [{"nom": "m", "v": v, "n": nn, "u": uu, "c": cc}], {"m": StandardMaterial3D.new()})
	s.add_child(c)
	c.global_position = j.global_position + Vector3(0, 0, -2)
	await _images(2)
	_verif(not c.recevoir_choc(Vector3(2, 0, 0), 0.5, c.global_position) and not c.casse, "urne de crypte : petit choc (1 J) sans casse")
	_verif(c.recevoir_choc(Vector3(8, 0, 0), 2.0, c.global_position) and c.casse, "urne de crypte : objet de 2 kg à 8 m/s (64 J) : brisée")

	# --- plafond d'éclats : casser beaucoup de meubles ne dépasse jamais MAX_ECLATS
	var n_casses := 0
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.meuble and not o.casse and o.seuil_casse < INF and o.is_inside_tree() and n_casses < 14:
			o.casser(true, o.global_position + Vector3(0, 0.2, 0.3), Vector3(0, 0, -5))
			n_casses += 1
	await _images(2)
	_verif(CasseObjets.nb_eclats() <= CasseObjets.MAX_ECLATS, "%d meubles brisés d'un coup : %d éclats (plafond %d)" % [n_casses, CasseObjets.nb_eclats(), CasseObjets.MAX_ECLATS])
	_fin()

func _sous_surface(f: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(f.global_position + Vector3(0, 0.1, 0), f.global_position - Vector3(0, 0.15, 0), 1)
	return not (f as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _fin() -> void:
	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
