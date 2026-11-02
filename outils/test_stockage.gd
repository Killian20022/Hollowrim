extends SceneTree
## Lot E RPG « stockage, marchands, forge » (scripts/rpg/stockage.gd, fenetre_coffre.gd, forge.gd, services_pnj.gd, docs/RPG.md) :
##   - COFFRE LOUÉ chez Grima (objet E dans son intérieur) : fenêtre coffre ↔ sac (ranger 1, la pile, tout ; prendre ; pièces par 100),
##     objets de quête refusés (gardés au sac par « tout ranger »), poids avant / après, arme tenue rangée = main vide, pause, touches ;
##   - MAISON : refus sans 1500 pièces, achat chez Gunnhild (option de dialogue), clé, coffre et râtelier de la maison (arme exposée) ;
##   - FORGE de Brodd : +1/+2/+3 contre pièces + minerais, identifiant « id+n », fiche (nom, valeur), dégâts relevés, arme tenue
##     rééquipée, armure portée rééquipée et relevée, refus (minerais, +3, quête), fenêtre (E) ;
##   - DIALOGUE : Brodd « Commercer / Forge / Au revoir », Gunnhild « Acheter la maison », Sigrún « Oublier mes talents » (500 pièces,
##     Progression.reinitialiser_perks) ; MARCHAND : de_quete → Inventaire.est_quete, objet forgé vendu à sa valeur relevée,
##     armures rachetées par Brodd, filtre de catégorie ;
##   - SAUVEGARDE : monde.sauvegarder → charger (fichier de test) : coffres, maison, arme forgée au sac ET en main.
##   godot --headless --path . --script res://outils/test_stockage.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await process_frame

func _touche(k: Key, maj := false) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.shift_pressed = maj
		e.pressed = p
		root.push_input(e)
	await process_frame

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

func _textes(d: Control) -> Array:
	return d._options.map(func(o: Dictionary) -> String: return String(o["texte"]))

func _interactif(ip: Node, nom: String) -> Node3D:
	for c in ip.get_children():
		if c.get("nom") == nom and c.has_method("texte_action"):
			return c
	return null

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var sv: ServicesPnj = m.services
	var fc: FenetreCoffre = sv.fenetre_coffre if sv != null else null
	_verif(sv != null and ServicesPnj.trouver(m) == sv and fc != null and FenetreCoffre.trouver(m) == fc and Forge.trouver(m) == sv.forge, "services, fenêtre coffre et forge créés (un de chaque)")
	_verif(not Stockage.maison_achetee and Stockage.conteneur("coffre_grima").vide(), "nouvelle partie : coffre de Grima vide, maison à vendre")
	# --- objets posés dans les intérieurs
	var ig: Interieur = m.village.interieur("grima")
	var it_g := _interactif(ig, "Coffre loué chez Grima")
	_verif(it_g != null and it_g.verbe == "Ouvrir le coffre loué", "coffre loué posé dans la maison de Grima (E : « Ouvrir le coffre loué »)")
	var im: Interieur = m.village.interieur(Stockage.MAISON)
	var it_m := _interactif(im, "Coffre de la maison")
	_verif(it_m != null and not it_m.condition.call() and sv.ratelier != null and sv.ratelier.is_inside_tree(), "maison des Frostmark : coffre (fermé avant l'achat) et râtelier posés")
	# --- fenêtre coffre ↔ sac
	_verif(not fc.ouvrir("coffre_maison") and not fc.ouvert, "coffre de la maison : refusé avant l'achat")
	inv.pieces = 250
	inv.ajouter("os_draugr", 5)
	inv.ajouter("minerai_fer", 2)
	inv.ajouter("cle_archives", 1)
	inv.ajouter("epee_soldat", 1)
	var eq: EquipementMains = j.mains.magie.eq
	eq.equiper("droite", "epee_soldat")
	_verif(String(eq.mains["droite"].get("id", "")) == "epee_soldat", "épée de soldat en main droite")
	it_g.parler()
	await process_frame
	_verif(fc.ouvert and fc.id_coffre == "coffre_grima" and paused and fc.cote == 1, "E sur le coffre : fenêtre ouverte, jeu en pause, page du sac (coffre vide)")
	fc._choisir(fc.lignes[1].find("os_draugr"))
	var p0 := inv.poids()
	await _touche(KEY_E)
	var g := Stockage.conteneur("coffre_grima")
	_verif(g.nombre("os_draugr") == 1 and inv.nombre("os_draugr") == 4 and absf(inv.poids() - (p0 - 0.5)) < 0.01, "E : 1 os rangé (sac %.1f → %.1f kg)" % [p0, inv.poids()])
	await _touche(KEY_E, true)
	_verif(g.nombre("os_draugr") == 5 and not inv.a("os_draugr"), "Maj+E : toute la pile rangée")
	fc._choisir(fc.lignes[1].find("cle_archives"))
	var r := fc.transferer()
	_verif(r.contains("quête") and inv.a("cle_archives") and not g.a("cle_archives"), "clé de quête refusée (« %s »)" % r)
	_verif(fc.lignes[1].back() == "cle_archives", "objets de quête listés en bas du sac")
	await _touche(KEY_R)
	_verif(g.nombre("epee_soldat") == 1 and g.nombre("minerai_fer") == 2 and g.pieces == 250 and inv.pieces == 0 and inv.a("cle_archives"), "R : tout rangé (pièces comprises) sauf la clé de quête")
	_verif(eq.categorie("droite") == "vide", "l'épée rangée a quitté la main droite")
	await _touche(KEY_TAB)
	_verif(fc.cote == 0, "Tab : page du coffre")
	fc._choisir(fc.lignes[0].find("pieces"))
	await _touche(KEY_E)
	_verif(inv.pieces == 100 and g.pieces == 150, "E sur les pièces : 100 reprises")
	fc._choisir(fc.lignes[0].find("minerai_fer"))
	await _touche(KEY_E)
	_verif(inv.nombre("minerai_fer") == 1 and g.nombre("minerai_fer") == 1, "E : un minerai repris")
	await _touche(KEY_R)
	_verif(g.vide() and inv.nombre("os_draugr") == 5 and inv.pieces == 250 and inv.a("epee_soldat"), "R : tout repris, coffre vide")
	await _touche(KEY_ESCAPE)
	await process_frame
	_verif(not fc.ouvert and not paused, "Échap : fenêtre fermée, jeu repris")
	# --- dialogue : options des services
	var d: Control = m.dialogue
	for id in ["forgeron", "chef", "volva", "ancienne"]:
		_pnj(id).set_physics_process(false)
		_pnj(id).set_process(false)
	j.global_position = _pnj("forgeron").global_position + Vector3(0, 0, 1.5)
	d._ouvrir(_pnj("forgeron"))
	_verif(_textes(d) == ["Commercer", "Forge", "Au revoir"], "Brodd : %s" % str(_textes(d)))
	d._fermer()
	j.global_position = _pnj("ancienne").global_position + Vector3(0, 0, 1.5)
	d._ouvrir(_pnj("ancienne"))
	_verif(_textes(d) == ["Commercer", "Au revoir"], "Grima inchangée : %s" % str(_textes(d)))
	d._fermer()
	j.global_position = _pnj("chef").global_position + Vector3(0, 0, 1.5)
	d._ouvrir(_pnj("chef"))
	_verif(_textes(d).size() == 2 and String(_textes(d)[0]).begins_with("Acheter la maison"), "Gunnhild : %s" % str(_textes(d)))
	# --- achat de la maison (par le dialogue)
	var tours := 0
	while d._ouvert and not d._choix_vis and tours < 40:
		await _touche(KEY_E)
		await _attendre(0.05)
		tours += 1
	await _touche(KEY_E)
	_verif(not d._ouvert and not Stockage.maison_achetee and inv.pieces == 250, "sans 1500 pièces : pas d'achat")
	inv.pieces = 2000
	d._ouvrir(_pnj("chef"))
	tours = 0
	while d._ouvert and not d._choix_vis and tours < 40:
		await _touche(KEY_E)
		await _attendre(0.05)
		tours += 1
	await _touche(KEY_E)
	_verif(Stockage.maison_achetee and inv.pieces == 500 and inv.a(Stockage.CLE_MAISON) and Inventaire.est_quete(Stockage.CLE_MAISON), "maison achetée par le dialogue : -1500 pièces, clé de quête au sac")
	_verif(sv.options("chef").is_empty() and it_m.condition.call() and Stockage.accessible("coffre_maison"), "plus d'option d'achat, coffre de la maison accessible")
	_verif(Stockage.acheter_maison(inv) != "", "deuxième achat refusé")
	# râtelier : une arme rangée dans le coffre de la maison s'y montre
	_verif(fc.ouvrir("coffre_maison"), "coffre de la maison ouvert")
	fc._choisir(fc.lignes[1].find("epee_soldat"))
	fc.transferer()
	fc.fermer()
	sv._actualiser_ratelier()
	_verif(ServicesPnj.armes_exposees() == ["epee_soldat"] and sv._armes_rack != null and sv._armes_rack.get_child_count() == 1, "râtelier : l'épée rangée est exposée %s" % str(ServicesPnj.armes_exposees()))
	Stockage.transferer(Stockage.conteneur("coffre_maison"), inv, "epee_soldat", 1)
	# --- Sigrún
	d._fermer()
	var pr: Progression = j.progression
	_verif(sv.reinitialiser_arbre() != "" and inv.pieces == 500, "Sigrún : aucun talent à oublier, rien payé")
	pr.perks = {"talent_test": 2}
	pr.points_perk = 0
	_verif(sv.reinitialiser_arbre() == "" and inv.pieces == 0 and pr.points_perk == 2 and pr.perks.is_empty(), "Sigrún : 500 pièces, 2 points rendus (Progression.reinitialiser_perks)")
	# --- forge : règles
	_verif(Forge.base_de("epee_soldat+2") == "epee_soldat" and Forge.niveau_de("epee_soldat+2") == 2 and Forge.niveau_de("epee_soldat") == 0, "identifiants id+n")
	var f2 := Inventaire.objet("epee_soldat+2")
	var v0 := int(Inventaire.objet("epee_soldat")["valeur"])
	_verif(String(f2.get("nom", "")) == "%s +2" % Inventaire.objet("epee_soldat")["nom"] and int(f2["valeur"]) == roundi(v0 * 1.5) and Inventaire.categorie_de("epee_soldat+2") == "arme", "fiche « %s », valeur %d → %d" % [f2.get("nom"), v0, f2.get("valeur")])
	_verif(Inventaire.objet("epee_soldat+4").is_empty() and Inventaire.objet("inconnu+1").is_empty(), "+4 et base inconnue : pas de fiche")
	eq.equiper("droite", "epee_soldat")
	inv.pieces = 0
	var rf := Forge.ameliorer(j, "epee_soldat")
	_verif(rf.contains("pièces") and inv.a("epee_soldat"), "sans pièces : refus (« %s »)" % rf)
	inv.pieces = 5000
	inv.retirer("minerai_fer", inv.nombre("minerai_fer"))
	rf = Forge.ameliorer(j, "epee_soldat")
	_verif(rf.contains("minerai") and inv.a("epee_soldat"), "sans minerai : refus (« %s »)" % rf)
	inv.ajouter("minerai_fer", 5)
	inv.ajouter("minerai_argent", 3)
	inv.ajouter("cristal_givre", 1)
	var c1 := Forge.cout("epee_soldat")
	var b0 := Forge.arme_de_base("epee_soldat")
	rf = Forge.ameliorer(j, "epee_soldat")
	_verif(rf == "" and inv.a("epee_soldat+1") and not inv.a("epee_soldat") and inv.pieces == 5000 - int(c1["pieces"]) and inv.nombre("minerai_fer") == 3, "+1 : %d pièces et 2 minerais de fer payés" % int(c1["pieces"]))
	var a1: DonneesArme = eq.arme("droite")
	_verif(String(eq.mains["droite"].get("id", "")) == "epee_soldat+1" and a1 != null and absf(a1.degats_leger - b0.degats_leger * 1.1) < 0.01 and absf(a1.degats_lourd - b0.degats_lourd * 1.1) < 0.01,
		"l'épée +1 reste en main, dégâts %.1f → %.1f" % [b0.degats_leger, a1.degats_leger if a1 != null else -1.0])
	_verif(Forge.ameliorer(j, "epee_soldat+1") == "" and Forge.ameliorer(j, "epee_soldat+2") == "" and inv.a("epee_soldat+3") and inv.nombre("minerai_argent") == 0 and not inv.a("cristal_givre"), "+2 puis +3 (argent et cristal de givre payés)")
	_verif(Forge.ameliorer(j, "epee_soldat+3").contains("+3") and absf(eq.arme("droite").degats_leger - b0.degats_leger * 1.35) < 0.01, "+3 : plus rien à forger ; dégâts ×1,35 en main")
	_verif(Forge.refus_objet("anneau_givre").contains("quête") and Forge.refus_objet("epee_skarnholt") != "" and Forge.refus_objet("potion_soin") != "", "refus : quête, Skarnholt, potion")
	# armure (fiche d'essai : armures.json est au lot A)
	Inventaire.OBJETS["casque_essai_e"] = {"nom": "Casque d'essai", "categorie": "armure", "rarete": "commun", "poids": 3.0, "valeur": 40, "emplacement": "tete", "armure": 10}
	inv.ajouter("casque_essai_e", 1)
	inv.ajouter("minerai_fer", 2)
	var ec: EquipementCorps = j.equipement_corps
	_verif(ec.equiper("casque_essai_e") == "" and ec.armure_totale() == 10.0, "casque d'essai porté (armure 10)")
	_verif(Forge.ameliorer(j, "casque_essai_e") == "" and ec.objet_a("tete") == "casque_essai_e+1" and ec.armure_totale() > 10.0, "casque +1 : toujours porté, armure %.0f" % ec.armure_totale())
	# fenêtre de la forge
	var fo: Forge = sv.forge
	inv.ajouter("dague_acier", 1)
	inv.ajouter("minerai_fer", 2)
	_verif(fo.ouvrir() and paused and fo.lignes.has("dague_acier") and fo.lignes.has("epee_soldat+3"), "fenêtre de la forge : armes du sac %s" % str(fo.lignes))
	fo._choisir(fo.lignes.find("dague_acier"))
	await _touche(KEY_E)
	_verif(inv.a("dague_acier+1") and fo.lignes[fo.choix] == "dague_acier+1", "E : dague forgée +1, toujours choisie")
	await _touche(KEY_TAB)
	_verif(fo.signet == 1 and fo.lignes == ["casque_essai_e+1"], "Tab : signet Armures %s" % str(fo.lignes))
	await _touche(KEY_ESCAPE)
	_verif(not fo.ouvert and not paused, "Échap : forge fermée")
	# --- marchand
	_verif(Marchand.de_quete(Stockage.CLE_MAISON) and Marchand.refus_vente("forgeron", "cle_archives").contains("quête"), "de_quete → Inventaire.est_quete (clé de la maison invendable)")
	_verif(Marchand.prix_vente("forgeron", "dague_acier+1") > Marchand.prix_vente("forgeron", "dague_acier") and Marchand.rachete("forgeron", "casque_essai_e+1") and not Marchand.rachete("ancienne", "casque_essai_e+1"), "objet forgé vendu plus cher ; Brodd rachète les armures")
	var mb: Marchand = m.marchand
	mb.ouvrir("forgeron")
	await _touche(KEY_TAB)
	var cats := mb.categories()
	_verif(cats.has("arme") and cats.has("armure") and cats[0] == "", "catégories du sac : %s" % str(cats))
	mb.changer_categorie("armure")
	_verif(mb.lignes.size() == 1 and String(mb.lignes[0]["id"]) == "casque_essai_e+1", "filtre Armures : le casque seul")
	await _touche(KEY_C)
	_verif(mb.categorie != "armure", "C : catégorie suivante (%s)" % mb.categorie)
	mb.fermer()
	ec.retirer("tete")
	inv.retirer("casque_essai_e+1", 1)
	Inventaire.OBJETS.erase("casque_essai_e")
	# --- sauvegarde / chargement
	Stockage.transferer(inv, Stockage.conteneur("coffre_grima"), "os_draugr", 3)
	Stockage.transferer(inv, Stockage.conteneur("coffre_maison"), "dague_acier+1", 1)
	m.sauvegarder()
	var texte := FileAccess.get_file_as_string(m.fichier_sauvegarde())
	var dd: Dictionary = JSON.parse_string(texte)
	_verif(dd.get("stockage", {}).get("maison_achetee", false) and dd["stockage"]["coffres"].has("coffre_maison"), "sauvegarde : clé « stockage » (maison, deux coffres)")
	Stockage.reinitialiser()
	inv.importer({})
	eq.equiper("droite", "vide")
	m.charger()
	await process_frame
	_verif(Stockage.maison_achetee and Stockage.conteneur("coffre_grima").nombre("os_draugr") == 3 and Stockage.conteneur("coffre_maison").nombre("dague_acier+1") == 1, "rechargé : maison achetée, os chez Grima, dague +1 dans la maison")
	_verif(inv.a("epee_soldat+3") and String(eq.mains["droite"].get("id", "")) == "epee_soldat+3" and absf(eq.arme("droite").degats_leger - b0.degats_leger * 1.35) < 0.01, "rechargé : épée +3 au sac et en main (dégâts relevés)")
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
