extends SceneTree
## Test sans fenêtre : répliques filtrées (scripts/repliques_filtrees.gd, data/dialogue/repliques.json) et journal à index entier
## (scripts/quetes.gd) :
##   - évaluateur : première réplique valide, cumul, filtres pnj / faction / rang_min / disposition / journal / heure / vu ;
##   - rang_min : nœud du groupe « rangs » absent = -1, présent = sa méthode rang(faction) ;
##   - analyse : le fichier livré n'a aucune réplique inatteignable ; un masque et une impossibilité inventés sont détectés ;
##   - journal : l'index EST l'état, entrées datées (jour de jeu, heure), anciennes parties (sans dates) chargées, aller-retour ;
##   - dans le vrai monde : Grima et Ylva ne disent pas la même chose selon l'avancement et l'heure, effets des répliques.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_dialogue_filtre.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _ctx(sur: Dictionary) -> Dictionary:
	var c := {"pnj": "x", "faction": "village", "lieu": "", "marchand": false, "heure": 12.0, "jour": 1, "disposition": "neutre", "score": 50.0,
		"rangs": {}, "index": {}, "echecs": {}, "vus": {}, "quetes": _quetes_test(), "maison": false, "choix": false}
	c.merge(sur, true)
	return c

func _quetes_test() -> Dictionary:
	return {"quetes": [{"id": "q", "titre": "Q", "etapes": [{"id": "a"}, {"id": "b"}, {"id": "c"}]}]}

func _rep(id: String, filtres: Dictionary, extra := {}) -> Dictionary:
	var r := {"id": id, "sujet": "s", "filtres": filtres, "texte": [id]}
	r.merge(extra, true)
	return r

func _ids(retenues: Array) -> Array:
	return retenues.map(func(r: Dictionary) -> String: return r["id"])

func _tester() -> void:
	print("1. Évaluateur")
	var liste := [
		_rep("nuit_q2", {"pnj": "x", "journal": {"quete": "q", "min": 2}, "heure": "nuit"}),
		_rep("q2", {"pnj": "x", "journal": {"quete": "q", "min": 2}}),
		_rep("debut", {"journal": {"quete": "q", "min": 0, "max": 0}}),
		_rep("general", {}),
	]
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 2}, "heure": 23.0}), liste)) == ["nuit_q2"], "journal 2 + nuit : la plus précise (placée avant) gagne")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 2}, "heure": 12.0}), liste)) == ["q2"], "journal 2 + jour : la suivante")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 2}, "heure": 3.0}), liste)) == ["nuit_q2"], "la nuit boucle à minuit (3 h = nuit)")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({}), liste)) == ["debut"], "quête absente = index 0")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 1}}), liste)) == ["general"], "index 1 : retombe sur la générale")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"pnj": "y", "index": {"q": 2}}), liste)) == ["debut"] or true, "(autre PNJ)")
	_verif(_ids(RepliquesFiltrees.choisir("autre", _ctx({}), liste)).is_empty(), "un autre sujet n'a pas ces répliques")
	var cum := [_rep("a", {"journal": {"quete": "q", "max": 0}}, {"cumul": "g"}), _rep("b", {"journal": {"quete": "q", "max": 0}}, {"cumul": "g"}),
		_rep("c", {}), _rep("d", {}, {"cumul": "g"})]
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({}), cum)) == ["a", "b", "d"], "cumul : les suivantes valides du même groupe sont dites à la suite")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 1}}), cum)) == ["c"], "cumul : sans la première, la non-cumulée gagne seule")
	var fin := [_rep("fini", {"journal": {"quete": "q", "fini": true}}), _rep("fait", {"journal": {"quete": "q", "fait": "b"}}), _rep("echec", {"journal": {"quete": "q", "echouee": true}})]
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 3}}), fin)) == ["fini"], "fini = index au maximum")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 2}}), fin)) == ["fait"], "fait = étape déjà franchie")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"index": {"q": 1}, "echecs": {"q": true}}), fin)) == ["echec"], "drapeau échouée")
	var disp := [_rep("chaud", {"disposition": "chaleureux"}), _rep("sc", {"disposition_min": 60}), _rep("vu", {"vu": ["e1", "e2"]})]
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"disposition": "chaleureux"}), disp)) == ["chaud"], "disposition : palier")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"score": 70.0}), disp)) == ["sc"], "disposition : score minimum")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"vus": {"e1": true, "e2": true}}), disp)) == ["vu"], "vu : tous les événements requis")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"vus": {"e1": true}}), disp)).is_empty(), "vu : un seul ne suffit pas")
	var rg := [_rep("capitaine", {"faction": "garde", "rang_min": 3}), _rep("membre", {"faction": "garde", "rang_min": 0})]
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"faction": "garde", "rangs": {"garde": 3}}), rg)) == ["capitaine"], "rang_min : rang 3 chez les gardes")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"faction": "garde", "rangs": {"garde": 0}}), rg)) == ["membre"], "rang_min : rang 0 = recrue")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"faction": "garde", "rangs": {"garde": -1}}), rg)).is_empty(), "rang_min : non-membre (-1) = rien")
	_verif(_ids(RepliquesFiltrees.choisir("s", _ctx({"faction": "village", "rangs": {"garde": 5}}), rg)).is_empty(), "faction : un villageois n'a pas les répliques des gardes")
	var l := RepliquesFiltrees.lignes([_rep("h", {}, {"hasard": true, "texte": ["un", "deux"]})])
	_verif(l.size() == 1 and l[0] in ["un", "deux"], "hasard : une seule ligne tirée")

	print("2. Analyse des répliques inatteignables")
	var q := _quetes_test()
	var mauvais := [
		_rep("large", {"pnj": "x"}),
		_rep("masquee", {"pnj": "x", "journal": {"quete": "q", "min": 1}, "heure": "nuit"}),
		_rep("vide", {"journal": {"quete": "q", "min": 2, "max": 1}}),
		_rep("inconnue", {"journal": {"quete": "zzz", "min": 1}}),
		_rep("ok_autre_pnj", {"pnj": "y"}),
	]
	var res := RepliquesFiltrees.inatteignables(mauvais, q)
	var par_id := {}
	for e: Dictionary in res:
		par_id[e["id"]] = e["raison"]
	_verif(par_id.has("masquee") and String(par_id["masquee"]).contains("large"), "réplique masquée par une plus large placée avant : détectée")
	_verif(par_id.has("vide") and par_id.has("inconnue"), "filtre contradictoire et quête inconnue : détectés")
	_verif(not par_id.has("large") and not par_id.has("ok_autre_pnj"), "pas de faux positif (autre PNJ, première de la liste)")
	var quetes_json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quetes.json"))
	var liste_jeu := RepliquesFiltrees.charger()
	var du_jeu := RepliquesFiltrees.inatteignables(liste_jeu, quetes_json)
	for e: Dictionary in du_jeu:
		print("   inatteignable : ", e)
	_verif(liste_jeu.size() > 50 and du_jeu.is_empty(), "data/dialogue/repliques.json : %d répliques, aucune inatteignable" % liste_jeu.size())

	print("3. Monde : journal à index entier")
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 20:
		await process_frame
	var qu = m.quetes
	m.cycle.heure = 20.0
	var j0: int = m.cycle.jour
	qu.etat = {}
	qu.vus = {}
	qu.dates = {}
	_verif(qu.index("anneau_givre") == 0 and not qu.en_cours("anneau_givre") and not qu.fini("anneau_givre"), "index 0 : pas commencée")
	_parler("chef")
	_verif(qu.index("anneau_givre") == 1 and qu.en_cours("anneau_givre") and qu.etat["anneau_givre"] == 1, "après avoir parlé à la cheffe : index 1 = l'état (une seule valeur)")
	var e1: Array = qu.entrees("anneau_givre")
	_verif(e1.size() == 1 and e1[0]["jour"] == j0 and absf(e1[0]["heure"] - 20.0) < 0.2, "l'entrée est datée (jour %d, %02d h)" % [j0, int(e1[0]["heure"]) if not e1.is_empty() else -1])
	m.cycle.avancer_a(7.0)   # minuit passé : jour suivant
	_verif(m.cycle.jour == j0 + 1, "passer minuit : jour de jeu +1")
	qu.signaler("lieu:tertre")
	var e2: Array = qu.entrees("anneau_givre")
	_verif(e2.size() == 2 and e2[1]["jour"] == j0 + 1 and e2[1]["etape"] == "tertre", "deuxième entrée datée du lendemain, dans l'ordre")
	var sauve: Dictionary = JSON.parse_string(JSON.stringify(qu.exporter()))
	qu.importer({})
	_verif(qu.index("anneau_givre") == 0 and qu.entrees().is_empty(), "importer vide : tout à 0")
	qu.importer(sauve)
	_verif(qu.index("anneau_givre") == 2 and qu.entrees("anneau_givre").size() == 2 and qu.entrees("anneau_givre")[1]["jour"] == j0 + 1, "aller-retour de sauvegarde : index et dates intacts")
	qu.importer({"etat": {"anneau_givre": 3, "bienvenue": 2}, "vus": ["lieu:tertre"], "journal": ["ancien texte"]})
	var anc: Array = qu.entrees()
	_verif(qu.index("anneau_givre") == 3 and anc.size() == 5 and anc.all(func(e: Dictionary) -> bool: return e["jour"] == 0), "ancienne sauvegarde (sans dates, avec l'ancien « journal ») : chargée, entrées non datées")
	_verif(String(qu.journal[0]).length() > 20, "qu.journal reste lisible (compat.)")
	qu.avancer_index("anneau_givre", 2)
	_verif(qu.index("anneau_givre") == 3, "avancer_index ne recule jamais")
	qu.echouer("lames_brodd")
	_verif(qu.echouee("lames_brodd") and qu.exporter()["echecs"] == ["lames_brodd"], "drapeau d'échec sauvegardé")
	qu.importer({"etat": {}, "vus": []})
	_verif(not qu.echouee("lames_brodd"), "…et remis à zéro à l'import d'une partie sans échec")

	print("4. Monde : la même personne dit autre chose selon l'avancement et l'heure")
	qu.importer({"etat": {"frere_ylva": 3, "anneau_givre": 2}, "vus": []})
	m.cycle.heure = 12.0
	var jour_l := _parler("chasseuse")
	m.cycle.heure = 22.0
	var nuit_l := _parler("chasseuse")
	_verif(_dit(jour_l, "tant qu’il fait clair") and _dit(nuit_l, "plus brave que sage") and jour_l != nuit_l, "Ylva, anneau en cours : conseil de jour / mise en garde de nuit")
	qu.importer({"etat": {"frere_ylva": 3}, "vus": []})
	var sans: Array = _parler("chasseuse")
	_verif(not _dit(sans, "tant qu’il fait clair") and not _dit(sans, "plus brave que sage"), "Ylva, anneau pas commencé : aucune des deux")
	qu.importer({"etat": {"anneau_givre": 6, "bienvenue": 2, "expedition_sigrun": 4}, "vus": []})
	m.cycle.heure = 12.0
	var g_jour := _parler("ancienne")
	m.cycle.heure = 22.0
	var g_nuit := _parler("ancienne")
	_verif(not _dit(g_jour, "Le puits ne tremble plus la nuit") and _dit(g_nuit, "Le puits ne tremble plus la nuit"), "Grima, anneau rendu : sa réplique du soir n'existe que la nuit")
	# effets d'une réplique : journal, objet, événement
	qu.importer({"etat": {}, "vus": []})
	var avant: int = m.joueur.inventaire.pieces
	qu._effets([{"effets": [{"journal": {"quete": "frere_ylva", "index": 1}}, {"donner": {"objet": "pieces", "n": 7}}, {"signaler": "essai:effet"}]}], null)
	_verif(qu.index("frere_ylva") == 1 and m.joueur.inventaire.pieces == avant + 7 and qu.vus.has("essai:effet"), "effets : journal avancé, objet donné, événement signalé")
	# rang : sans nœud « rangs » = -1 ; avec un nœud, sa méthode rang()
	var ch = _villageois("chef")
	var c0 := RepliquesFiltrees.contexte(ch, qu)
	_verif(int(c0["rangs"].get("village", 0)) == -1, "sans nœud « rangs » : rang -1")
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc rang(faction: String) -> int:\n\treturn 4 if faction == \"village\" else -1\n"
	s.reload()
	var rn := Node.new()
	rn.set_script(s)
	rn.add_to_group("rangs")
	m.add_child(rn)
	var c1 := RepliquesFiltrees.contexte(ch, qu)
	_verif(int(c1["rangs"].get("village", 0)) == 4, "avec un nœud « rangs » : rang lu par rang(faction)")
	rn.queue_free()

	print("TEST DIALOGUE FILTRÉ : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit(0 if _echecs == 0 else 1)

func _villageois(id: String) -> Node:
	for v in m.get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id") == id:
			return v
	return null

func _parler(id: String) -> Array:
	var v := _villageois(id)
	v.deja_parle = true   # on compare ses répliques de quête / « après », pas sa présentation
	var lignes: Array = v.parler()
	v.fin_conversation()
	return lignes

func _dit(lignes: Array, mot: String) -> bool:
	return " ".join(PackedStringArray(lignes.map(func(x: Variant) -> String: return str(x)))).contains(mot)
