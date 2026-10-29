extends SceneTree
## Lot L3 « fenêtre de butin » (scripts/fenetre_butin.gd, docs/BUTIN.md §8) :
##   - une fenêtre unique (groupe), lignes = objets sans les pièces, triées par rareté (unique, rare, peu commun, commun) ;
##   - jeu en pause pendant l'ouverture ; clavier : flèche bas = ligne suivante, E = prendre, R = tout prendre, Échap / Tab = fermer
##     (sans ouvrir le menu pause ni le panneau Tab) ; l'objet pris quitte le dictionnaire du contenant ; `fin` appelé une fois ;
##   - unique déjà pris → pièces (ButinTables.prendre) ; rien à montrer → pas de fenêtre ;
##   - ButinTables.restes : sauvegarde JSON relue en entiers ; corps : invite « Fouiller », fenêtre au nom de l'ennemi, corps retiré
##     une fois tout pris ; coffre de la crypte : objet laissé = « Fouiller le coffre », rouvert sans pièces en double.
##   godot --headless --path . --script res://outils/test_fenetre_butin.gd -- --nouvelle
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

func _ids(fb: FenetreButin) -> Array:
	return fb.lignes.map(func(l: Dictionary) -> String: return String(l["id"]))

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var fb: FenetreButin = m.fenetre_butin
	_verif(fb != null and FenetreButin.trouver(m) == fb and get_nodes_in_group(FenetreButin.GROUPE).size() == 1, "une seule fenêtre de butin, trouvée par le groupe")
	# --- ouverture, tri, pause
	var objets := {"pieces": 12, "os_draugr": 2, "potion_soin_forte": 1, "tome_boule_feu": 1, "epee_obsidienne": 1}
	var fins := [0]
	var ok: bool = fb.ouvrir("Coffre d'essai", objets, 12, func() -> void: fins[0] += 1)
	_verif(ok and fb.ouvert and paused, "ouverture : fenêtre ouverte, jeu en pause")
	_verif(_ids(fb) == ["epee_obsidienne", "tome_boule_feu", "potion_soin_forte", "os_draugr"], "lignes sans les pièces, triées par rareté : %s" % str(_ids(fb)))
	_verif(fb.pieces == 12 and fb.titre == "Coffre d'essai", "titre et pièces versées affichés (+12)")
	# --- clavier : bas puis E = prendre le tome
	await _touche(KEY_DOWN)
	_verif(fb.choix == 1, "flèche bas : ligne 2 choisie")
	var tome0 := inv.nombre("tome_boule_feu")
	await _touche(KEY_E)
	_verif(inv.nombre("tome_boule_feu") == tome0 + 1 and not objets.has("tome_boule_feu") and fb.lignes.size() == 3, "E : le tome est pris, retiré du contenant (%d lignes restent)" % fb.lignes.size())
	_verif(fb.ouvert and paused and not j.get("en_dialogue"), "E ne ferme pas la fenêtre et n'ouvre pas de dialogue")
	# --- R = tout prendre
	var os0 := inv.nombre("os_draugr")
	await _touche(KEY_R)
	_verif(not fb.ouvert and not paused and fins[0] == 1, "R : tout pris, fenêtre fermée, jeu repris, fin appelée une fois")
	_verif(inv.nombre("os_draugr") == os0 + 2 and inv.a("epee_obsidienne") and inv.a("potion_soin_forte") and objets.keys() == ["pieces"], "R : os, épée unique, potion au sac ; il ne reste que les pièces (déjà versées)")
	# --- unique déjà pris : pièces
	var or0 := inv.pieces
	var o2 := {"epee_obsidienne": 1}
	fb.ouvrir("Second coffre", o2)
	var res: Array = fb.prendre(0)
	_verif(res.size() == 1 and res[0]["id"] == "pieces" and inv.pieces == or0 + 300 and inv.nombre("epee_obsidienne") == 1, "unique déjà pris : changé en %d pièces" % (inv.pieces - or0))
	# --- Échap : ferme sans rien prendre, sans menu pause
	var o3 := {"anneau_cuivre": 1, "coupe_argent": 1}
	fb.ouvrir("Troisième coffre", o3)
	await _touche(KEY_ESCAPE)
	await process_frame
	_verif(not fb.ouvert and not paused and o3.size() == 2 and not inv.a("anneau_cuivre"), "Échap : fermée, rien pris, jeu repris (pas de menu pause)")
	fb.ouvrir("Troisième coffre", o3)
	await _touche(KEY_TAB)
	await process_frame
	_verif(not fb.ouvert and not paused and not m.hud.panneau_ouvert, "Tab : fermée sans ouvrir le panneau du personnage")
	# --- rien à montrer
	_verif(not fb.ouvrir("Vide", {"pieces": 4}) and not fb.ouvert and not paused, "seulement des pièces : pas de fenêtre")
	_verif(FenetreButin.poids_texte(0.5) == "0,5" and FenetreButin.poids_texte(10.0) == "10" and FenetreButin.poids_texte(0.0) == "-", "poids écrits à la française (0,5 / 10 / -)")
	# --- restes : sauvegarde JSON
	ButinTables.restes["essai:x"] = {"os_draugr": 3, "collier_or": 1}
	var texte := JSON.stringify({"butin": ButinTables.exporter()})
	ButinTables.reinitialiser()
	_verif(not ButinTables.a_reste("essai:x"), "nouvelle partie : aucun objet laissé")
	ButinTables.importer((JSON.parse_string(texte) as Dictionary)["butin"])
	var r: Dictionary = ButinTables.reste("essai:x")
	_verif(r == {"os_draugr": 3, "collier_or": 1} and typeof(r["os_draugr"]) == TYPE_INT, "restes relus de la sauvegarde (entiers) : %s" % str(r))
	ButinTables.restes.erase("essai:x")
	# --- corps : invite « Fouiller », fenêtre au nom de l'ennemi
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = j
	b.hud = m.hud
	b.contenu = {"collier_or": 1}
	b.nom_corps = "Draugr ancien"
	m.add_child(b)
	b.global_position = j.global_position + Vector3(1.5, 0, 0)
	await process_frame
	_verif(is_instance_valid(b) and b.a_fouille() and b._inter.verbe == "Fouiller" and b._inter.nom == "Draugr ancien", "corps sans pièces avec un objet : reste là, invite « Fouiller » (Draugr ancien)")
	(b._inter as Node3D).parler()
	_verif(fb.ouvert and fb.titre == "Draugr ancien" and _ids(fb) == ["collier_or"], "fouille : fenêtre au nom du corps")
	fb.tout_prendre()
	await process_frame
	await process_frame
	_verif(inv.a("collier_or") and not is_instance_valid(b), "fouille : collier pris, corps vidé retiré")
	# --- coffre de la crypte : laisser un objet puis revenir
	var t: Node3D = m.tertre
	t.attendre_donjon()
	await _attendre(0.2)
	var id := ""
	var contenu := {}
	for it: Dictionary in t.donjon.interactions:
		if String(it["id"]).begins_with("cof_") and it.has("butin") and t._inter.has(it["id"]):
			var n := 0
			for k in it["butin"]:
				if k != "pieces":
					n += 1
			if n >= 2:
				id = it["id"]
				contenu = it["butin"]
				break
	_verif(id != "", "coffre de la crypte à deux objets ou plus : %s %s" % [id, str(contenu)])
	if id == "":
		print("ECHECS : %d" % _echecs)
		quit(_echecs)
		return
	var ic: Node3D = t._inter[id]
	var or1 := inv.pieces
	ic.parler()
	var n_l: int = fb.lignes.size()
	_verif(fb.ouvert and fb.pieces == int(contenu.get("pieces", 0)) and inv.pieces == or1 + int(contenu.get("pieces", 0)), "coffre %s : fenêtre (%d objets), pièces versées à l'ouverture (+%d)" % [id, n_l, fb.pieces])
	fb.prendre(0)
	fb.fermer()
	_verif(ButinTables.a_reste("crypte:" + id) and ic.actif and ic.verbe == "Fouiller le coffre" and ic.condition.call(), "objets laissés : coffre toujours proposé, « Fouiller le coffre »")
	var or2 := inv.pieces
	ic.parler()
	_verif(fb.ouvert and fb.lignes.size() == n_l - 1 and fb.pieces == 0 and inv.pieces == or2, "rouvert : %d objet(s) laissé(s), aucune pièce en double" % fb.lignes.size())
	fb.tout_prendre()
	_verif(not ButinTables.a_reste("crypte:" + id) and not ic.actif and not ic.condition.call() and not paused, "tout pris : coffre vidé, plus proposé")
	await _attendre(0.2)
	print("ECHECS : %d" % _echecs)
	quit(_echecs)
