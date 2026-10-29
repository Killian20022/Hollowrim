extends SceneTree
## Lot L8 « marchands » (scripts/marchand.gd, data/marchands.json, docs/BUTIN.md §9) :
##   - données valides ; Brodd (forgeron) et Grima (ancienne) sont marchands, la cheffe non ; stock à graine fixe par période ;
##   - ACHAT : prix = valeur x achat, pièces retirées, objet au sac, stock et bourse du marchand mis à jour ; refus sans pièces ;
##   - VENTE : prix = valeur x 0,4, l'objet rejoint le stock du marchand ; objets de quête (valeur 0, lames de Brodd pendant
##     « Le fer des morts ») invendables ; Grima ne rachète pas les épées ; refus quand la bourse du marchand est vide ;
##   - STOCK VIDE (tout acheté) puis RÉASSORT après 2 jours de jeu (nouveau tirage, bourse remise, objets vendus disparus) ;
##     l'horloge des marchands suit cycle.heure ;
##   - SAUVEGARDE : exporter → JSON → importer (heures, stock, bourse) ; nouvelle partie = état neuf ;
##   - BOUTIQUE : pause, onglets (Tab, manette RB), E / R, Échap / B ; DIALOGUE : « [T] Commercer » chez Brodd et Grima,
##     choix « Commercer / Au revoir » sur la dernière réplique, rien chez la cheffe.
##   godot --headless --path . --script res://outils/test_marchands.gd -- --nouvelle
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

func _touche(k: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = p
		root.push_input(e)
	await process_frame

func _bouton(b: JoyButton) -> void:
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = p
		root.push_input(e)
	await process_frame

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

func _ids(mb: Marchand) -> Array:
	return mb.lignes.map(func(l: Dictionary) -> String: return String(l["id"]))

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var mb: Marchand = m.marchand
	# --- données
	var err := Marchand.verifier()
	_verif(err.is_empty(), "données des marchands valides %s" % str(err))
	_verif(mb != null and Marchand.trouver(m) == mb and get_nodes_in_group(Marchand.GROUPE).size() == 1, "une seule boutique, trouvée par le groupe")
	var brodd := _pnj("forgeron")
	var grima := _pnj("ancienne")
	_verif(Marchand.pour_pnj(brodd) == "forgeron" and Marchand.pour_pnj(grima) == "ancienne" and Marchand.pour_pnj(_pnj("chef")) == "", "Brodd et Grima commercent, la cheffe non")
	_verif(Marchand.heures < 0.1 and Marchand.etats.is_empty(), "nouvelle partie : horloge des marchands à 0, aucun état")
	# tout objet vendable du jeu est racheté par au moins un marchand
	var personne: Array = []
	var catalogue: Array = Inventaire.OBJETS.keys()
	Inventaire.objet("potion_soin")
	catalogue.append_array(Inventaire._butin.keys())
	for oid: String in catalogue:
		if not Marchand.de_quete(oid) and not Marchand.rachete("forgeron", oid) and not Marchand.rachete("ancienne", oid):
			personne.append(oid)
	_verif(personne.is_empty(), "chaque objet vendable a un acheteur %s" % str(personne))
	# --- stock à graine fixe
	var s0 := Marchand.stock_tire("forgeron", 0)
	_verif(s0 == Marchand.stock_tire("forgeron", 0) and not s0.is_empty() and s0.has("minerai_fer"), "stock du forgeron, période 0 : même tirage deux fois %s" % str(s0))
	_verif(not Marchand.stock("ancienne").is_empty() and Marchand.stock("ancienne").has("potion_soin"), "Grima vend des potions %s" % str(Marchand.stock("ancienne")))
	_verif(Marchand.prix_achat("forgeron", "minerai_fer") == 14 and Marchand.prix_vente("forgeron", "collier_or") == 34 and Marchand.prix_vente("ancienne", "os_draugr") == 1 and Marchand.prix_achat("ancienne", "potion_soin") == 35,
		"prix : minerai 12 → 14 à l'achat, collier 85 → 34 à la vente, os 2 → 1, potion 30 → 35 chez Grima")
	# --- boutique : ouverture, achat
	inv.pieces = 100
	_verif(mb.ouvrir("forgeron") and mb.ouvert and paused and mb.onglet == 0 and mb.titre == "Forge de Brodd", "boutique ouverte (Forge de Brodd), jeu en pause, onglet Acheter")
	var i_fer := _ids(mb).find("minerai_fer")
	mb._choisir(i_fer)
	var fer0 := Marchand.stock("forgeron")["minerai_fer"] as int
	var or_m0 := Marchand.or_de("forgeron")
	await _touche(KEY_E)
	_verif(inv.pieces == 86 and inv.nombre("minerai_fer") == 1 and int(Marchand.stock("forgeron")["minerai_fer"]) == fer0 - 1 and Marchand.or_de("forgeron") == or_m0 + 14,
		"E : un minerai acheté 14 pièces (sac 86), stock %d → %d, bourse +14" % [fer0, int(Marchand.stock("forgeron").get("minerai_fer", 0))])
	_verif(mb.ouvert and paused and not j.en_dialogue, "E ne ferme pas la boutique")
	inv.pieces = 5
	var r := mb.traiter()
	_verif(r.begins_with("Pas assez") and inv.pieces == 5 and inv.nombre("minerai_fer") == 1, "sans assez de pièces : refus (« %s »), rien ne bouge" % r)
	# --- vente
	inv.ajouter("collier_or", 1)
	inv.ajouter("anneau_givre", 1)
	inv.ajouter("lame_antique", 2)
	await _touche(KEY_TAB)
	_verif(mb.onglet == 1, "Tab : onglet Vendre")
	var ids_v := _ids(mb)
	_verif(ids_v.has("collier_or") and ids_v.back() == "anneau_givre" and String(mb.lignes.back()["refus"]).contains("quête"), "Vendre : l'anneau de quête est listé en bas, refusé %s" % str(ids_v))
	mb._choisir(ids_v.find("collier_or"))
	or_m0 = Marchand.or_de("forgeron")
	await _touche(KEY_E)
	_verif(inv.pieces == 39 and not inv.a("collier_or") and Marchand.or_de("forgeron") == or_m0 - 34 and int(Marchand.stock("forgeron").get("collier_or", 0)) == 1,
		"E : collier vendu 34 pièces (sac 39), il rejoint l'étal du forgeron")
	r = mb.traiter(_ids(mb).find("anneau_givre"))
	_verif(r.contains("quête") and inv.a("anneau_givre"), "anneau de givre (valeur 0) : invendable (« %s »)" % r)
	var q: Node = m.quetes
	q.etat["lames_brodd"] = 1
	_verif(Marchand.de_quete("lame_antique", q) and Marchand.vendre("forgeron", inv, "lame_antique", 1, q).contains("quête") and inv.nombre("lame_antique") == 2,
		"lames antiques invendables pendant « Le fer des morts »")
	q.etat.erase("lames_brodd")
	_verif(not Marchand.de_quete("lame_antique", q) and Marchand.vendre("forgeron", inv, "lame_antique", 1, q) == "" and inv.nombre("lame_antique") == 1, "hors de la quête : une lame se vend")
	inv.ajouter("epee_or", 1)
	_verif(Marchand.refus_vente("ancienne", "epee_or") != "" and Marchand.refus_vente("forgeron", "epee_or") == "", "Grima ne rachète pas les épées, Brodd oui")
	Marchand.etat("forgeron")["or"] = 3
	r = Marchand.vendre("forgeron", inv, "epee_or", 1, q)
	_verif(r.begins_with("Sa bourse") and inv.a("epee_or"), "bourse du marchand vide : refus (« %s »)" % r)
	Marchand.etat("forgeron")["or"] = 600
	# --- manette : LB = onglet, B = fermer
	await _bouton(JOY_BUTTON_LEFT_SHOULDER)
	_verif(mb.onglet == 0, "manette LB : retour à Acheter")
	await _bouton(JOY_BUTTON_B)
	_verif(not mb.ouvert and not paused, "manette B : boutique fermée, jeu repris")
	# --- stock vide
	inv.pieces = 100000
	mb.ouvrir("forgeron")
	var n_tours := 0
	while not mb.lignes.is_empty() and n_tours < 40:
		await _touche(KEY_R)
		n_tours += 1
	_verif(mb.lignes.is_empty() and Marchand.stock("forgeron").is_empty(), "R : tout l'étal acheté en %d piles, stock vide" % n_tours)
	var avant := Marchand.heures_avant_reassort("forgeron")
	_verif(avant > 47.0 and avant <= 48.0 and Marchand.duree_texte(avant) == "2 j", "réassort dans %s (%.1f h)" % [Marchand.duree_texte(avant), avant])
	await _touche(KEY_ESCAPE)
	await process_frame
	_verif(not mb.ouvert and not paused, "Échap : boutique fermée (pas de menu pause)")
	# --- horloge : suit cycle.heure
	var h0 := Marchand.heures
	m.cycle.heure = fmod(m.cycle.heure + 1.5, 24.0)
	await process_frame
	await process_frame
	_verif(absf(Marchand.heures - h0 - 1.5) < 0.1, "horloge des marchands : +%.2f h quand le cycle avance de 1,5 h" % (Marchand.heures - h0))
	# --- réassort après 2 jours
	Marchand.avancer(48.0)
	var p := Marchand.periode_de("forgeron")
	_verif(p == 1 and Marchand.stock("forgeron") == Marchand.stock_tire("forgeron", 1) and not Marchand.stock("forgeron").is_empty() and Marchand.or_de("forgeron") == 600,
		"2 jours plus tard : réassort (période 1), bourse remise à 600 %s" % str(Marchand.stock("forgeron")))
	_verif(not Marchand.stock("forgeron").has("collier_or"), "le collier vendu a quitté l'étal au réassort")
	# --- sauvegarde
	Marchand.acheter("ancienne", inv, "potion_soin", 1)
	var texte := JSON.stringify({"marchands": Marchand.exporter()})
	var ref_h := Marchand.heures
	var ref_s := Marchand.stock("ancienne").duplicate()
	var ref_o := Marchand.or_de("ancienne")
	Marchand.reinitialiser()
	_verif(Marchand.heures == 0.0 and Marchand.etats.is_empty(), "réinitialiser : état neuf")
	Marchand.importer((JSON.parse_string(texte) as Dictionary)["marchands"])
	_verif(absf(Marchand.heures - ref_h) < 0.001 and Marchand.stock("ancienne") == ref_s and Marchand.or_de("ancienne") == ref_o and typeof(Marchand.stock("ancienne").values()[0]) == TYPE_INT,
		"rechargé : heures %.1f, stock et bourse de Grima identiques (entiers)" % Marchand.heures)
	# --- dialogue : option « Commercer »
	var d: Control = m.dialogue
	for pnj: Node3D in [brodd, grima, _pnj("chef")]:
		pnj.set_physics_process(false)
		pnj.set_process(false)
	j.global_position = brodd.global_position + Vector3(0, 0, 1.5)
	d._ouvrir(brodd)
	await process_frame
	_verif(d._ouvert and d._marchand == "forgeron" and d._carte_cmd.visible and not d._choix_vis, "Brodd : « [T] Commercer » affiché dès la 1re réplique")
	await _touche(KEY_T)
	_verif(not d._ouvert and mb.ouvert and mb.id_marchand == "forgeron" and paused and not j.en_dialogue, "T : dialogue fermé, boutique de Brodd ouverte")
	mb.fermer()
	j.global_position = grima.global_position + Vector3(0, 0, 1.5)
	d._ouvrir(grima)
	var tours := 0
	while d._ouvert and not d._choix_vis and tours < 40:
		await _touche(KEY_E)
		await _attendre(0.05)
		tours += 1
	_verif(d._ouvert and d._choix_vis and d._choix_ui.visible and d._choix == 0, "Grima : dernière réplique → choix « Commercer / Au revoir » (%d appuis)" % tours)
	await _touche(KEY_DOWN)
	_verif(d._choix == 1, "flèche bas : « Au revoir »")
	await _touche(KEY_UP)
	await _touche(KEY_E)
	_verif(not d._ouvert and mb.ouvert and mb.id_marchand == "ancienne" and mb.titre == "Remèdes de Grima", "E sur « Commercer » : boutique de Grima")
	mb.fermer()
	d._ouvrir(grima)
	tours = 0
	while d._ouvert and not d._choix_vis and tours < 40:
		await _touche(KEY_E)
		await _attendre(0.05)
		tours += 1
	await _touche(KEY_S)
	await _touche(KEY_E)
	_verif(not d._ouvert and not mb.ouvert and not paused, "« Au revoir » : dialogue fermé, pas de boutique")
	j.global_position = _pnj("chef").global_position + Vector3(0, 0, 1.5)
	d._ouvrir(_pnj("chef"))
	await process_frame
	_verif(d._ouvert and d._marchand == "" and not d._carte_cmd.visible, "cheffe : pas d'option Commercer")
	await _touche(KEY_T)
	_verif(d._ouvert and not mb.ouvert, "T chez la cheffe : rien")
	d._fermer()
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
