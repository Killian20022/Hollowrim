extends SceneTree
## Test des tables de butin à graine fixe (scripts/butin_tables.gd, data/butin/*.json) et des consommables
## (scripts/consommables.gd) dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_butin.gd -- --nouvelle
## Données valides, déterminisme (même graine = même butin, même après « rechargement »), graine du monde, raretés
## (fréquences, unique au plus une fois), objets fixes + tirage (coffres de donjon), état pillé sauvegardé, uniques déjà pris
## changés en pièces, bourses d'ennemis stables, potions → vraies stats du joueur, inventaire (I, catégorie Potions),
## raccourci 1-0 d'une potion (sans toucher aux mains), HUD, icônes, sauvegarde des raccourcis (fichier de test).

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var magie: Node
var ui: InventaireMains
var eq: EquipementMains
var _captures := ""

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

## Avec fenêtre (bash /tmp/godot_slot.sh, fenêtre hors écran) et --captures=<dossier> : 2 captures (Potions, barre du HUD).
func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.substr(11)
	_donnees()
	_determinisme()
	_raretes()
	_contenants()
	_persistance()
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	magie = j.mains.magie
	ui = s.inventaire_ui
	eq = magie.eq
	await _images(20)
	_ennemis()
	_potions()
	await _inventaire()
	await _raccourcis()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ données

func _donnees() -> void:
	var err := ButinTables.verifier()
	_verif(err.is_empty(), "données de data/butin/ valides (%s)" % ("aucune erreur" if err.is_empty() else "; ".join(err)))
	var noms := ButinTables.tables().keys()
	for t in ["coffre_crypte", "coffre_crypte_riche", "coffre_boss", "coffre_bandit", "urne", "tonneau", "caisse", "cadavre_draugr", "cadavre_bandit", "cadavre_mage"]:
		_verif(noms.has(t), "table « %s » présente" % t)
	_verif(ButinTables.table_pour("coffre", "grotte") == "coffre_bandit" and ButinTables.table_pour("coffre", "crypte") == "coffre_crypte", "table par zone : coffre de grotte = coffre_bandit, de crypte = coffre_crypte")
	_verif(ButinTables.table_pour("draugr", "crypte") == "cadavre_draugr" and ButinTables.table_pour("tonneau", "zone_inconnue") == "tonneau", "repli sur la zone « defaut » (draugr en crypte, tonneau d'une zone inconnue)")
	for id in ["potion_soin", "potion_mana", "potion_endurance", "pain_seigle", "viande_sechee"]:
		_verif(Inventaire.connu(id) and Consommables.est(id) and IconesCombat.connu(String(Inventaire.objet(id).get("icone", ""))), "consommable %s : connu du sac, icône pixel « %s »" % [id, Inventaire.objet(id).get("icone", "")])
	var img := IconesCombat.image(IconesCombat.MOTIFS["potion_soin"])
	_verif(img.get_width() == 16 and img.get_height() == 16 and img.get_pixel(8, 9).a > 0.5, "icône de potion 16x16 dessinée (motif, pas d'image externe)")
	_verif(ButinTables.hacher("crypte:cof_ossuaire") == ButinTables.hacher("crypte:cof_ossuaire") and ButinTables.hacher("a") != ButinTables.hacher("b") and ButinTables.hacher("a") == 3826002220, "hachage FNV-1a stable (« a » = 3826002220)")

func _determinisme() -> void:
	ButinTables.reinitialiser()
	var a := ButinTables.tirer_pour("crypte:cof_ossuaire", "coffre_crypte")
	var b := ButinTables.tirer_pour("crypte:cof_ossuaire", "coffre_crypte")
	_verif(a == b and not a.is_empty(), "même contenant, même graine : même butin (%s)" % str(ButinTables.contenu(a)))
	var g := ButinTables.graine("crypte:cof_ossuaire")
	var memes := true
	for i in 20:
		memes = memes and ButinTables.tirer("coffre_boss", g + i) == ButinTables.tirer("coffre_boss", g + i)
	_verif(memes, "20 graines × 2 tirages du coffre de boss : identiques deux à deux")
	# le hasard global ne change rien
	seed(12345)
	randi()
	var c := ButinTables.tirer_pour("crypte:cof_ossuaire", "coffre_crypte")
	_verif(c == a, "indépendant du hasard global (randi / seed)")
	var distincts := {}
	for i in 60:
		distincts[str(ButinTables.tirer_pour("crypte:test_%d" % i, "coffre_crypte"))] = true
	_verif(distincts.size() >= 30, "contenants différents : contenus variés (%d contenus distincts sur 60)" % distincts.size())
	ButinTables.graine_monde = 777
	var d := ButinTables.tirer_pour("crypte:cof_ossuaire", "coffre_crypte")
	var diff := 0
	for i in 30:
		ButinTables.graine_monde = 777
		var x := str(ButinTables.tirer_pour("crypte:t%d" % i, "coffre_crypte"))
		ButinTables.graine_monde = ButinTables.GRAINE_MONDE_DEFAUT
		if x != str(ButinTables.tirer_pour("crypte:t%d" % i, "coffre_crypte")):
			diff += 1
	_verif(diff >= 15, "autre graine du monde : autres contenus (%d / 30 changent ; cof_ossuaire : %s)" % [diff, str(ButinTables.contenu(d))])
	ButinTables.reinitialiser()
	_verif(ButinTables.tirer_pour("crypte:cof_ossuaire", "coffre_crypte") == a, "graine par défaut rétablie : contenu d'origine")

func _raretes() -> void:
	var nb := {"commun": 0, "peu_commun": 0, "rare": 0, "unique": 0}
	var vides := 0
	var unique_double := false
	var pieces_ok := true
	var or_min := 1 << 30
	var or_max := 0
	for i in 3000:
		var l := ButinTables.tirer(  "coffre_crypte", 1000 + i)
		var obj := 0
		var vus := {}
		for o: Dictionary in l:
			_verif_silencieux(ButinTables.RARETES.has(o["rarete"]))
			if o["id"] == "pieces":
				or_min = mini(or_min, int(o["n"]))
				or_max = maxi(or_max, int(o["n"]))
				continue
			obj += 1
			nb[o["rarete"]] += 1
			if vus.has(o["id"]):
				pieces_ok = false   # un même id doit être regroupé
			vus[o["id"]] = true
		if obj == 0:
			vides += 1
	_verif(nb["commun"] > nb["peu_commun"] and nb["peu_commun"] > nb["rare"] and nb["rare"] > 0, "fréquences des raretés (3000 coffres de crypte) : commun %d > peu commun %d > rare %d" % [nb["commun"], nb["peu_commun"], nb["rare"]])
	_verif(vides > 0 and vides < 1500, "tirages « rien » possibles mais minoritaires (%d coffres sans objet sur 3000)" % vides)
	_verif(or_min >= 8 and or_max <= 30, "or du coffre de crypte dans [8, 30] (vu %d-%d)" % [or_min, or_max])
	_verif(pieces_ok, "un même objet tiré deux fois est regroupé (une seule ligne, n cumulé)")
	# unique : au plus une fois par tirage
	for i in 3000:
		var l := ButinTables.tirer("coffre_boss", 5000 + i)
		for o: Dictionary in l:
			if o["id"] == "epee_obsidienne" and int(o["n"]) > 1:
				unique_double = true
	_verif(not unique_double, "un objet unique (épée en obsidienne) au plus une fois par coffre de boss")
	var boss := ButinTables.tirer("coffre_boss", 42)
	_verif(ButinTables.contenu(boss).has("potion_soin_forte"), "coffre de boss : objet garanti (grande potion de soin)")
	# zone : bonus de rareté de la crypte basse
	var rares := [0, 0]
	for i in 3000:
		for k in 2:
			for o: Dictionary in ButinTables.tirer("coffre_crypte", 9000 + i, "crypte" if k == 0 else "crypte_basse"):
				if o["rarete"] == "rare":
					rares[k] += 1
	_verif(rares[1] > rares[0], "zone « crypte_basse » : plus de rares que « crypte » (%d > %d)" % [rares[1], rares[0]])
	var trouve_arme := false
	for i in 400:
		for o: Dictionary in ButinTables.tirer("coffre_boss", 70000 + i):
			if String(o["id"]).begins_with("epee_"):
				trouve_arme = trouve_arme or EquipementMains.new().objet(String(o["id"])) != null
	_verif(trouve_arme, "les épées tirées sont de vraies armes équipables (prêt pour tout_disponible=false)")

func _verif_silencieux(cond: bool) -> void:
	if not cond:
		_verif(false, "rareté inconnue dans un tirage")

func _contenants() -> void:
	var fixe := {"pieces": 34, "os_draugr": 2, "poussiere_tombe": 1}
	var avec := fixe.duplicate()
	avec["table"] = "coffre_crypte"
	var r := ButinTables.resoudre(avec, "crypte:cof_ossuaire")
	var garde := true
	for k in fixe:
		garde = garde and int(r.get(k, 0)) >= int(fixe[k])
	_verif(garde and not r.has("table") and r != fixe, "coffre de donjon : objets fixes gardés + tirage ajouté (%s)" % str(r))
	_verif(ButinTables.resoudre(avec, "crypte:cof_ossuaire") == r, "coffre de donjon : même contenu à chaque construction")
	_verif(ButinTables.resoudre({"pieces": 80, "hache_kolbeinn": 1}, "crypte:x") == {"pieces": 80, "hache_kolbeinn": 1}, "coffre de quête (sans « table ») : contenu inchangé")
	var src := FileAccess.get_file_as_string("res://scripts/crypte_donjon.gd")
	_verif(src.count("\"table\": \"") >= 20 and src.contains("\"hache_kolbeinn\": 1, \"pieces\": 80, \"table\": \"coffre_boss\""), "crypte : coffres et urnes branchés sur les tables (%d)" % src.count("\"table\": \""))

func _persistance() -> void:
	ButinTables.reinitialiser()
	_verif(not ButinTables.est_pille("crypte:urne_ossuaire"), "nouvelle partie : rien n'est pillé")
	ButinTables.piller("crypte:urne_ossuaire")
	ButinTables.piller("grotte:camp_a")
	ButinTables.uniques_pris["epee_obsidienne"] = true
	ButinTables.graine_monde = 4242
	var avant := ButinTables.tirer_pour("crypte:cof_g1", "coffre_crypte")
	var texte := JSON.stringify({"butin": ButinTables.exporter()})   # comme monde.sauvegarder
	ButinTables.reinitialiser()
	_verif(not ButinTables.est_pille("grotte:camp_a") and ButinTables.graine_monde == ButinTables.GRAINE_MONDE_DEFAUT, "réinitialisation : état vidé")
	var lu: Dictionary = JSON.parse_string(texte)
	ButinTables.importer(lu["butin"])   # comme monde.charger
	_verif(ButinTables.est_pille("crypte:urne_ossuaire") and ButinTables.est_pille("grotte:camp_a") and not ButinTables.est_pille("crypte:cof_g1"), "rechargement : contenants pillés restent pillés, les autres non")
	_verif(ButinTables.graine_monde == 4242 and ButinTables.tirer_pour("crypte:cof_g1", "coffre_crypte") == avant, "rechargement : même graine du monde, même contenu pour un coffre non ouvert")
	_verif(ButinTables.uniques_pris.has("epee_obsidienne"), "rechargement : uniques pris mémorisés")
	ButinTables.importer({})
	_verif(ButinTables.pilles.is_empty() and ButinTables.graine_monde == ButinTables.GRAINE_MONDE_DEFAUT, "ancienne sauvegarde (sans « butin ») : graine par défaut, rien de pillé")
	# prendre : un unique déjà pris devient des pièces
	var inv := Inventaire.new()
	var l: Array[Dictionary] = [{"id": "pieces", "n": 10, "rarete": "commun"}, {"id": "epee_obsidienne", "n": 1, "rarete": "unique"}, {"id": "potion_soin", "n": 2, "rarete": "commun"}]
	ButinTables.prendre(inv, l)
	_verif(inv.pieces == 10 and inv.a("epee_obsidienne") and inv.nombre("potion_soin") == 2, "prendre : pièces, unique et potions dans le sac")
	var r2 := ButinTables.prendre(inv, [{"id": "epee_obsidienne", "n": 1, "rarete": "unique"}])
	_verif(inv.nombre("epee_obsidienne") == 1 and inv.pieces == 10 + int(Inventaire.objet("epee_obsidienne")["valeur"]) and r2[0]["id"] == "pieces", "prendre : second exemplaire d'un unique changé en %d pièces" % int(Inventaire.objet("epee_obsidienne")["valeur"]))
	var inv2 := Inventaire.new()
	inv2.importer(inv.exporter())
	_verif(inv2.nombre("potion_soin") == 2 and inv2.a("epee_obsidienne") and inv2.poids() > 10.0, "sac sauvegardé : potions et objets de data/butin/objets.json gardés au rechargement (poids %.1f)" % inv2.poids())
	ButinTables.reinitialiser()

# ------------------------------------------------------------------ ennemis

func _ennemis() -> void:
	var d1 := ButinTables.contenu(ButinTables.tirer_pour("ennemi:cr_ossuaire_1", "cadavre_draugr"))
	var d2 := ButinTables.contenu(ButinTables.tirer_pour("ennemi:cr_ossuaire_1", "cadavre_draugr"))
	_verif(d1 == d2 and int(d1.get("os_draugr", 0)) >= 1, "bourse d'un draugr : stable pour un même ident, toujours des os (%s)" % str(d1))
	var mage := ButinTables.contenu(ButinTables.tirer_pour("ennemi:cr_g4_mage", ButinTables.table_pour("mage")))
	_verif(mage.has("cristal_givre"), "bourse du mage : cristal de givre garanti (%s)" % str(mage))
	var src := FileAccess.get_file_as_string("res://scripts/draugr.gd")
	_verif(src.contains("ButinTables.tirer_pour(\"ennemi:\"") and not src.contains("randi_range(4, 14)"), "draugr.gd : bourse tirée de la table (plus de randi)")

# ------------------------------------------------------------------ potions → stats

## Les effets des potions sont progressifs (EffetsPotions) : on laisse passer le temps (effets versés en entier, délais levés).
func _fin_effets() -> void:
	j.potions.avancer(j, 30.0)

func _potions() -> void:
	var inv: Inventaire = j.inventaire
	for id in ["potion_soin", "potion_mana", "potion_endurance", "pain_seigle", "tome_boule_feu"]:
		inv.ajouter(id, 2)
	j.vie = 30.0
	var r := Consommables.utiliser(j, "potion_soin")
	_fin_effets()
	_verif(r == "" and is_equal_approx(j.vie, 70.0) and inv.nombre("potion_soin") == 1, "potion de soin : vie 30 → %.0f, reste %d" % [j.vie, inv.nombre("potion_soin")])
	j.vie = j.vie_max
	r = Consommables.utiliser(j, "potion_soin")
	_fin_effets()
	_verif(r != "" and inv.nombre("potion_soin") == 1, "vie pleine : potion refusée et gardée (« %s »)" % r)
	j.mana = 10.0
	r = Consommables.utiliser(j, "potion_mana")
	_fin_effets()
	_verif(r == "" and is_equal_approx(j.mana, 60.0), "potion de mana : mana 10 → %.0f" % j.mana)
	j.mana = j.mana_max - 5.0
	Consommables.utiliser(j, "potion_mana")
	_fin_effets()
	_verif(is_equal_approx(j.mana, j.mana_max), "mana plafonnée à mana_max (%.0f)" % j.mana)
	j.vigueur = 5.0
	r = Consommables.utiliser(j, "potion_endurance")
	_fin_effets()
	_verif(r == "" and is_equal_approx(j.vigueur, 65.0), "potion d'endurance : vigueur 5 → %.0f" % j.vigueur)
	j.vie = 50.0
	j.vigueur = 50.0
	r = Consommables.utiliser(j, "pain_seigle")
	_fin_effets()
	_verif(r == "" and is_equal_approx(j.vie, 58.0) and is_equal_approx(j.vigueur, 70.0), "pain de seigle : vie +8, vigueur +20 (%.0f / %.0f)" % [j.vie, j.vigueur])
	_verif(Consommables.description("pain_seigle").contains("8 de vie") and Consommables.description("pain_seigle").contains("endurance"), "description : « %s »" % Consommables.description("pain_seigle"))
	# tome : apprendre un sort (tout_disponible : déjà connu → refus, sinon appris)
	var avait := eq.sorts_connus.has("boule_feu")
	if avait:
		_verif(Consommables.utiliser(j, "tome_boule_feu").contains("connaissez"), "tome d'un sort déjà connu : refusé")
		eq.sorts_connus.erase("boule_feu")
	r = Consommables.utiliser(j, "tome_boule_feu")
	_verif(r == "" and eq.sorts_connus.has("boule_feu") and inv.nombre("tome_boule_feu") == 1, "tome de boule de feu : sort appris (%s)" % ("" if r == "" else r))
	j.mort = true
	_verif(Consommables.utiliser(j, "potion_soin") != "" and inv.nombre("potion_soin") == 1, "mort : rien n'est bu")
	j.mort = false
	_verif(Consommables.utiliser(j, "os_draugr") != "", "un objet non consommable ne s'utilise pas")

# ------------------------------------------------------------------ inventaire (I)

func _inventaire() -> void:
	var inv: Inventaire = j.inventaire
	inv.ajouter("potion_soin", 2)   # 3 en tout
	inv.ajouter("os_draugr", 1)
	ui.ouvrir()
	await _images(2)
	ui._changer_categorie("consommables")
	await _images(2)
	var ids: Array = []
	for b in ui._liste.get_children():
		if b is Button:
			ids.append(String(b.get_meta("id")))
	_verif(ids.has("conso:potion_soin") and ids.has("conso:pain_seigle") and not ids.has("conso:potion_mana") and not ids.has("conso:os_draugr"), "catégorie Potions : consommables du sac seulement, les épuisés disparaissent (%s)" % str(ids))
	ui._changer_categorie("divers")
	await _images(2)
	var ids_d: Array = []
	for b in ui._liste.get_children():
		if b is Button:
			ids_d.append(String(b.get_meta("id")))
	_verif(ids_d.has("sac:os_draugr") and not ids_d.has("sac:potion_soin"), "Divers : le reste du sac, sans les potions")
	ui._changer_categorie("consommables")
	await _images(2)
	j.vie = 20.0
	var n0 := inv.nombre("potion_soin")
	var mains_av := [ui.tenu("gauche"), ui.tenu("droite")]
	var r_inv := ui.equiper("droite", "conso:potion_soin")
	_fin_effets()
	_verif(r_inv == "" and is_equal_approx(j.vie, 60.0) and inv.nombre("potion_soin") == n0 - 1, "inventaire : clic sur la potion = bue (vie 20 → %.0f, reste %d)" % [j.vie, inv.nombre("potion_soin")])
	_verif([ui.tenu("gauche"), ui.tenu("droite")] == mains_av, "boire ne change pas les mains")
	j.vie = j.vie_max
	_fin_effets()
	var rf := ui.equiper("gauche", "conso:potion_soin")
	_verif(rf != "" and ui.message.contains("maximum"), "inventaire : refus expliqué (« %s »)" % ui.message)
	ui._choisir("conso:potion_soin")
	await _capture("butin_potions.png")
	_verif(ui.memoriser(6) == "" and eq.raccourcis[6].get("conso") == "potion_soin" and not eq.raccourcis[6].has("gauche"), "Potions : touche 7 = potion de soin rangée dans le raccourci 7")
	ui.fermer()
	await _images(2)

func _raccourcis() -> void:
	var inv: Inventaire = j.inventaire
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "torche")
	j.vie = 25.0
	var n0 := inv.nombre("potion_soin")
	magie.raccourci(6)
	_fin_effets()
	_verif(is_equal_approx(j.vie, 65.0) and inv.nombre("potion_soin") == n0 - 1, "touche 7 en jeu : potion bue (vie 25 → %.0f)" % j.vie)
	_verif(eq.mains["gauche"]["id"] == "torche" and eq.mains["droite"]["id"] == "epee", "touche 7 : les mains restent torche | épée")
	var hud: Control = s.hud.combat_ui if s.hud.get("combat_ui") != null else null
	if hud != null:
		await _images(3)
		var pr: Array = hud._presets({}, {})
		await _capture("butin_hud.png")
		_verif(String(pr[6].get("conso", "")) == "potion_soin" and int(pr[6].get("nombre", -1)) == inv.nombre("potion_soin"), "HUD : case 7 = potion de soin x%d" % int(pr[6].get("nombre", -1)))
	# plus de potion : refus, rien ne change
	while inv.a("potion_soin"):
		inv.retirer("potion_soin")
	j.vie = 25.0
	magie.raccourci(6)
	_verif(is_equal_approx(j.vie, 25.0) and eq.mains["droite"]["id"] == "epee", "touche 7 sans potion : rien (refus « Vous n'en avez plus. »)")
	# sauvegarde des raccourcis : le consommable reste rangé
	var texte := JSON.stringify({"magie": magie.exporter()})
	eq.assigner_raccourci(6, "vide", "epee")
	_verif(not eq.raccourcis[6].has("conso"), "réassigner des mains efface le consommable du raccourci")
	magie.importer((JSON.parse_string(texte) as Dictionary)["magie"])
	_verif(eq.raccourcis[6].get("conso") == "potion_soin", "rechargement : raccourci 7 = potion de soin")
	eq.vider_raccourci(6)
	_verif(not eq.raccourcis[6].has("conso"), "raccourci vidé : plus de consommable")
	_verif(eq.assigner_conso(2, "os_draugr") != "", "un objet non consommable ne se range pas dans un raccourci")
