extends SceneTree
## ÉCONOMIE (gameplay/economie, docs/ECONOMIE.md) :
##   - RECELEUR : Bersi Main-Grise (id « receleur », data/villageois.json + data/marchands.json), sur le quai sous l'auvent du moulin,
##     corps d'un archétype nordique existant (guerrier PnjNordique, variante « hab_receleur »), toujours à son poste (profil veilleur) ;
##     « Commercer » au dialogue, rachète tout à 25 % de la valeur, et les objets VOLÉS (Crime.voles) dont il ôte la marque ;
##   - MARCHANDS HONNÊTES : refusent la part volée d'une pile (ligne grisée « (volé) » en bas de l'onglet Vendre), vendent le reste ;
##     un objet acheté n'est jamais compté volé ;
##   - MARGE MINIMALE : même avec une faveur énorme (bonus « prix » 0,5), racheter ce qu'on vient d'acheter fait toujours perdre de l'or ;
##   - LEÇONS (Formation) : une leçon = +1 niveau, prix 40 + 6 x niveau, 3 par maître et par période de 2 jours, plafond du maître,
##     refus sans pièces, options de dialogue, sauvegarde (Marchand.exporter, clé « formations »).
##   godot --headless --path . --script res://outils/test_economie.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const QUAI := Vector2(31.0, 56.5)

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

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var mb: Marchand = m.marchand
	var cr: Crime = Crime.trouver(m)
	var prog: Progression = j.get("progression")
	_verif(cr != null and prog != null, "monde : crime et progression présents")
	# --- données
	_verif(Marchand.verifier().is_empty(), "données des marchands valides %s" % str(Marchand.verifier()))
	_verif(Marchand.est_marchand("receleur") and Marchand.est_receleur("receleur") and not Marchand.est_receleur("forgeron") and not Marchand.est_receleur("ancienne"),
		"Bersi est un marchand receleur ; Brodd et Grima sont honnêtes")
	# --- le PNJ
	var bersi := _pnj("receleur")
	_verif(bersi != null, "Bersi Main-Grise est au village")
	if bersi == null:
		print("ECHECS : %d" % (_echecs))
		quit(1)
		return
	var corps: Node = bersi.get("modele")
	_verif(Marchand.pour_pnj(bersi) == "receleur" and String(bersi.nom_affiche()) == "Bersi Main-Grise", "Bersi commerce (« %s »)" % bersi.nom_affiche())
	_verif(corps != null and String(corps.get_meta("pnj_nordique", "")) == "hab_receleur" and PnjNordique.HABITANTS.has("hab_receleur"),
		"corps : archétype nordique existant, variante hab_receleur (pas de nouveau modèle)")
	var p2 := Vector2(bersi.global_position.x, bersi.global_position.z)
	_verif(p2.distance_to(QUAI) < 1.5 and p2.distance_to(Vector2(44, 40)) < 22.0, "Bersi sur le quai, dans l'enceinte (%.1f ; %.1f)" % [p2.x, p2.y])
	_verif(not (bersi.has_method("est_endormi") and bersi.est_endormi()), "Bersi éveillé à son poste")
	var d: Control = m.dialogue
	bersi.set_physics_process(false)
	j.global_position = bersi.global_position + Vector3(0, 0, 1.6)
	d._ouvrir(bersi)
	await process_frame
	var textes: Array = d._options.map(func(o: Dictionary) -> String: return String(o.get("texte", "")))
	_verif(d._ouvert and d._marchand == "receleur" and textes.has("Commercer") and textes.any(func(t: String) -> bool: return t.begins_with("Leçon : Furtivité")),
		"dialogue de Bersi : Commercer et une leçon de Furtivité %s" % str(textes))
	d._fermer()
	await process_frame
	# --- prix
	_verif(Marchand.prix_vente("forgeron", "collier_or") == 34 and Marchand.prix_vente("receleur", "collier_or") == 21 and Marchand.prix_achat("receleur", "crochet") == 3,
		"prix : collier 85 → 34 chez Brodd, 21 chez Bersi (25 %) ; crochet 2 → 3 chez Bersi")
	# --- objets volés : Brodd vend la part honnête, refuse la part volée
	inv.pieces = 0
	for oid: String in ["collier_or", "potion_soin", "potion_endurance"]:
		inv.retirer(oid, inv.nombre(oid))
	cr.voles.clear()
	inv.ajouter("collier_or", 2)
	cr.voles["collier_or"] = 1
	_verif(Marchand.voles_de(inv, "collier_or") == 1 and Marchand.vendables("forgeron", inv, "collier_or") == 1 and Marchand.vendables("receleur", inv, "collier_or") == 2,
		"2 colliers dont 1 volé : Brodd peut en racheter 1, Bersi 2")
	mb.ouvrir("forgeron")
	mb.changer_onglet(1)
	var l_vole: Array = mb.lignes.filter(func(l: Dictionary) -> bool: return l["id"] == "collier_or" and bool(l.get("vole", false)))
	var l_ok: Array = mb.lignes.filter(func(l: Dictionary) -> bool: return l["id"] == "collier_or" and not bool(l.get("vole", false)))
	_verif(l_vole.size() == 1 and int(l_vole[0]["n"]) == 1 and String(l_vole[0]["refus"]).contains("volé") and l_ok.size() == 1 and int(l_ok[0]["n"]) == 1 and String(l_ok[0]["refus"]) == "",
		"boutique de Brodd : collier honnête vendable, collier volé à part, grisé (« %s »)" % (String(l_vole[0]["refus"]) if not l_vole.is_empty() else "?"))
	var r := mb.traiter(mb.lignes.find(l_ok[0]), true)
	_verif(r == "" and inv.nombre("collier_or") == 1 and inv.pieces == 34 and int(cr.voles.get("collier_or", 0)) == 1, "R sur la pile honnête : un seul collier vendu (34 pièces), le volé reste marqué")
	r = Marchand.vendre("forgeron", inv, "collier_or", 1)
	_verif(r.contains("volé") and inv.nombre("collier_or") == 1 and inv.pieces == 34, "Brodd refuse le collier volé (« %s »)" % r)
	mb.fermer()
	inv.ajouter("potion_soin", 1)
	cr.voles["potion_soin"] = 1
	_verif(Marchand.vendre("ancienne", inv, "potion_soin", 1).contains("volé") and inv.nombre("potion_soin") == 1, "Grima refuse la potion volée")
	# --- Bersi rachète le volé et efface la marque
	var or_b := Marchand.or_de("receleur")
	r = Marchand.vendre("receleur", inv, "collier_or", 1)
	_verif(r == "" and inv.nombre("collier_or") == 0 and inv.pieces == 34 + 21 and not cr.voles.has("collier_or") and Marchand.or_de("receleur") == or_b - 21,
		"Bersi rachète le collier volé 21 pièces, la marque disparaît")
	r = Marchand.vendre("receleur", inv, "potion_soin", 1)
	_verif(r == "" and not cr.voles.has("potion_soin") and Marchand.vendre("receleur", inv, "anneau_givre", 1).contains("quête"), "Bersi rachète la potion volée ; les objets de quête restent invendables")
	# --- marque du sac (Conteneur.noter_vol, posée par ObjetsVivants quand on prend un objet possédé)
	inv.retirer("coupe_argent", inv.nombre("coupe_argent"))
	inv.ajouter("coupe_argent", 1)
	inv.noter_vol("coupe_argent", 1)
	_verif(Marchand.refus_vente("forgeron", "coupe_argent", null, inv).contains("volé") and Marchand.vendre("ancienne", inv, "coupe_argent", 1).contains("volé"),
		"coupe marquée volée dans le sac : Brodd et Grima refusent")
	r = Marchand.vendre("receleur", inv, "coupe_argent", 1)
	_verif(r == "" and not inv.est_vole("coupe_argent") and not bool(inv.get_meta("vole", false)), "Bersi la rachète, plus aucune marque au sac")
	# --- un objet acheté n'est pas volé (marque obsolète bornée)
	cr.voles["potion_endurance"] = 3
	inv.pieces = 500
	var avant_pe := inv.nombre("potion_endurance")
	r = Marchand.acheter("ancienne", inv, "potion_endurance", 1)
	_verif(r == "" and inv.nombre("potion_endurance") == avant_pe + 1 and Marchand.voles_de(inv, "potion_endurance") == avant_pe and Marchand.vendables("ancienne", inv, "potion_endurance") >= 1,
		"potion achetée chez Grima : pas volée, revendable (marques %d)" % Marchand.voles_de(inv, "potion_endurance"))
	cr.voles.clear()
	# --- marge minimale : faveur extrême, aucun gain par achat-revente
	prog._effets_cache = {"_": 0.0, "prix": 0.5}
	var gains: Array = []
	for mid: String in Marchand.ids():
		for ent: Dictionary in Marchand.fiche(mid).get("stock", []):
			var oid := String(ent["id"])
			if Marchand.prix_vente(mid, oid) > floori(Marchand.prix_achat(mid, oid) * Marchand.MARGE_MIN) and Marchand.prix_vente(mid, oid) > 1:
				gains.append("%s:%s" % [mid, oid])
	_verif(Marchand.faveur("forgeron") >= 0.5 and gains.is_empty(), "faveur %.2f : rachat ≤ 75 %% de l'achat partout %s" % [Marchand.faveur("forgeron"), str(gains)])
	_verif(Marchand.prix_vente("forgeron", "epee_or") < Marchand.prix_achat("forgeron", "epee_or"), "épée d'or : achat %d, rachat %d (plus d'argent infini)" % [Marchand.prix_achat("forgeron", "epee_or"), Marchand.prix_vente("forgeron", "epee_or")])
	prog._effets_cache = {}
	# --- leçons
	Formation.reinitialiser()
	inv.pieces = 1000
	var n0 := prog.competence("une_main")
	var prix0 := Formation.prix(prog, "forgeron")
	_verif(prix0 == 40 + 6 * n0, "leçon d'Une main chez Brodd : %d pièces au niveau %d" % [prix0, n0])
	r = Formation.prendre_lecon(prog, inv, "forgeron")
	_verif(r == "" and prog.competence("une_main") == n0 + 1 and inv.pieces == 1000 - prix0 and Formation.restantes("forgeron") == 2, "une leçon : +1 niveau (%d), %d pièces payées" % [prog.competence("une_main"), prix0])
	Formation.prendre_lecon(prog, inv, "forgeron")
	Formation.prendre_lecon(prog, inv, "forgeron")
	var pieces3 := inv.pieces
	r = Formation.prendre_lecon(prog, inv, "forgeron")
	_verif(r != "" and prog.competence("une_main") == n0 + 3 and inv.pieces == pieces3, "4e leçon de la période refusée (« %s »)" % r)
	var services := ServicesPnj.trouver(m)
	var opts: Array = services.options("forgeron") if services != null else []
	var o_lecon: Array = opts.filter(func(o: Dictionary) -> bool: return String(o["texte"]).begins_with("Leçon : Une main"))
	_verif(o_lecon.size() == 1, "Brodd propose « %s »" % (String(o_lecon[0]["texte"]) if not o_lecon.is_empty() else "?"))
	var rep: Variant = (o_lecon[0]["action"] as Callable).call() if not o_lecon.is_empty() else null
	_verif(rep is Array and (rep as Array).size() == 1 and String(rep[0]).contains("deux jours"), "action du choix fatigué : réplique de refus %s" % str(rep))
	var sauve := JSON.stringify(Marchand.exporter())
	Marchand.avancer(48.0)
	_verif(Formation.restantes("forgeron") == 3, "2 jours plus tard : 3 leçons de nouveau")
	inv.pieces = 10
	r = Formation.prendre_lecon(prog, inv, "forgeron")
	_verif(r.contains("pièces") and inv.pieces == 10, "sans assez de pièces : refus (« %s »)" % r)
	inv.pieces = 1000
	rep = (o_lecon[0]["action"] as Callable).call()
	_verif(rep is Array and prog.competence("une_main") == n0 + 4, "action du choix : leçon donnée, réplique de Brodd %s" % str(rep))
	prog.competences.niveaux["epee"] = 50
	r = Formation.prendre_lecon(prog, inv, "forgeron")
	_verif(r != "" and prog.competence("une_main") == 50, "plafond du maître (50) : refus (« %s »)" % r)
	var maitres: Array = (Formation.donnees().get("maitres", {}) as Dictionary).keys()
	var sans_pnj: Array = maitres.filter(func(id: String) -> bool: return _pnj(id) == null)
	_verif(maitres.size() == 5 and sans_pnj.is_empty(), "5 maîtres, tous au village %s" % str(maitres))
	Marchand.importer(JSON.parse_string(sauve))
	_verif(Formation.restantes("forgeron") == 0 and int(Formation.lecons["forgeron"]["n"]) == 3, "sauvegarde : leçons de la période relues")
	Marchand.reinitialiser()
	_verif(Formation.lecons.is_empty() and Formation.restantes("forgeron") == 3, "nouvelle partie : leçons remises à zéro")
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
