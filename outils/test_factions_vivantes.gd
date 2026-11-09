extends SceneTree
## Factions « vivantes » : le rang se sent, chaque faction a sa quête, le crime coûte de la réputation de faction.
##   1. répliques de rang (sujet « rang » de data/dialogue/repliques.json) : chaque chef a une réplique par palier, au moins un autre PNJ
##      reconnaît le rang de chaque faction, rien pour un non-membre, le fichier n'a AUCUNE réplique inatteignable ;
##      le PNJ du village la dit vraiment en parlant (villageois.parler, garde_village.parler) ;
##   2. quêtes de faction (data/quetes.json) : le chef ne les propose qu'au rang minimal, elles se jouent de bout en bout (événements
##      réels du jeu : tue:, ramasse: par le sac, lieu:, parle:), donnent réputation + objet, journal daté, objets de quête repris ;
##      leurs déclencheurs existent dans le monde (ennemis, ressource, lieux, butin du troll) ;
##   3. crime -> réputation (data/factions_joueur.json, « crime ») : barème par type de crime VU pour la Garde, meurtre d'un membre pour sa
##      faction, exclusion si négative, dette réglée (amende, geôle) = part rendue, sauvegarde.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_factions_vivantes.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
const G := "garde_jarl"
const C := "cercle_sigrun"
const H := "chasseurs"

var m: Node3D
var rg: Rangs
var j: CharacterBody3D
var cr: Crime
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		if j != null:
			j.vie = j.vie_max
		await physics_frame

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id:
			return v
	return null

func _txt(l: Array) -> String:
	return " | ".join(l.map(func(x: Variant) -> String: return String(x)))

## État des rangs : {faction: [réputation, rang]} ; tout le reste à zéro (non membre).
func _etat(d: Dictionary) -> void:
	var rep := {}
	var rang := {}
	var der := {}
	for f: String in d:
		rep[f] = float(d[f][0])
		rang[f] = int(d[f][1])
		der[f] = 0.0
	rg.restaurer({"rep": rep, "rang": rang, "dernier": der})

## Textes de toutes les répliques de rang d'un contexte (filtre « pnj » facultatif).
func _textes_rang(faction: String, pnj_id := "") -> Array:
	var res: Array = []
	for r: Dictionary in RepliquesFiltrees.charger():
		var f: Dictionary = r.get("filtres", {})
		if String(r.get("sujet", "")) == "rang" and String(f.get("rang_faction", "")) == faction and (pnj_id == "" or String(f.get("pnj", "")) == pnj_id):
			res.append_array(r["texte"])
	return res

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 30:
		await physics_frame
	rg = m.rangs
	j = m.joueur
	cr = Crime.trouver(m)
	_verif(rg != null and cr != null and m.quetes != null, "monde : rangs, crime et quêtes branchés")
	if rg == null or cr == null:
		_fin()
		return
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.heure = 12.0
	await _attendre(1.0)
	await _repliques_de_rang()
	await _quetes_de_faction()
	await _crime_et_reputation()
	_fin()

# ============================================================================================== 1. répliques de rang

func _repliques_de_rang() -> void:
	print("1. Répliques de rang")
	var liste := RepliquesFiltrees.charger()
	var mauvaises := RepliquesFiltrees.inatteignables(liste, m.quetes.donnees)
	_verif(mauvaises.is_empty(), "répliques jamais atteignables : %d %s" % [mauvaises.size(), str(mauvaises.map(func(x: Dictionary) -> String: return String(x["id"])))])
	for f: String in rg.factions():
		var chef_id := String(rg.fiche(f)["chef"])
		var chef := _pnj(chef_id)
		_etat({})
		_verif(m.quetes.rang(chef_id, chef).is_empty(), "%s non membre : %s ne dit aucune réplique de rang" % [rg.nom(f), chef_id])
		var vus := {}
		var ok_paliers := true
		for r in rg.nb_rangs(f):
			_etat({f: [60.0, r]})
			var l: Array = m.quetes.rang(chef_id, chef)
			ok_paliers = ok_paliers and l.size() == 1 and (_textes_rang(f, chef_id)).has(l[0])
			vus[r] = _txt(l)
		_verif(ok_paliers, "%s : le chef (%s) a une réplique à chacun des %d rangs" % [rg.nom(f), chef_id, rg.nb_rangs(f)])
		# le rang se sent : le palier le plus haut n'a pas les mots du plus bas (textes tirés des listes de chaque palier)
		var bas := _etat_texte(f, chef_id, 0)
		var haut := _etat_texte(f, chef_id, rg.nb_rangs(f) - 1)
		_verif(not bas.is_empty() and not haut.is_empty() and bas.filter(func(t: String) -> bool: return haut.has(t)).is_empty(),
			"%s : le chef ne parle pas pareil au rang 0 et au rang %d" % [rg.nom(f), rg.nb_rangs(f) - 1])
		# au moins un AUTRE PNJ reconnaît le rang
		var autres := {}
		for r: Dictionary in liste:
			var fl: Dictionary = r.get("filtres", {})
			if String(r.get("sujet", "")) == "rang" and String(fl.get("rang_faction", "")) == f and String(fl.get("pnj", "")) != chef_id:
				autres[String(fl.get("pnj", "gardes du village"))] = true
		_verif(autres.size() >= 1, "%s : reconnue aussi par %s" % [rg.nom(f), str(autres.keys())])
	# 2 à 3 PNJ en tout pour la Garde (Haldor, Brodd, Gunnar, gardes) : Brodd parle selon le rang
	_etat({G: [60.0, 4]})
	var brodd := _pnj("forgeron")
	var l4: Array = m.quetes.rang("forgeron", brodd)
	_etat({G: [10.0, 1]})
	var l1: Array = m.quetes.rang("forgeron", brodd)
	_verif(not l4.is_empty() and not l1.is_empty() and l4 != l1 and _textes_rang(G, "forgeron").has(l4[0]) and _textes_rang(G, "forgeron").has(l1[0]),
		"Brodd : « %s » (Champion) contre « %s » (Porte-bouclier)" % [_txt(l4).left(50), _txt(l1).left(50)])
	# le PNJ la dit vraiment en parlant (touche E)
	_etat({H: [60.0, 3]})
	var ylva := _pnj("chasseuse")
	ylva.deja_parle = true
	var dit: Array = ylva.parler()
	ylva.fin_conversation()
	_verif(not dit.is_empty() and _textes_rang(H, "chasseuse").has(dit[0]), "Ylva (Maître de la chasse) ouvre sa conversation par sa réplique de rang : « %s »" % String(dit[0]).left(60))
	_etat({})
	ylva.deja_parle = true
	dit = ylva.parler()
	ylva.fin_conversation()
	_verif(dit.is_empty() or not _textes_rang(H, "chasseuse").has(dit[0]), "Ylva, joueur non membre : aucune réplique de rang")
	# garde du village
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = null
	for x in gv.gardes:
		if x.service == "poste":
			g = x
			break
	_verif(g != null, "un garde du village (poste) trouvé")
	if g != null:
		_etat({G: [60.0, 4]})
		var lg: Array = g.parler()
		g.fin_conversation()
		_verif(not lg.is_empty() and _textes_rang(G).has(lg[0]), "garde du village face à un Champion : « %s »" % String(lg[0]).left(60))
		_etat({})
		g.deja_parle = true
		lg = g.parler()
		g.fin_conversation()
		_verif(lg.is_empty() or not _textes_rang(G).has(lg[0]), "garde du village face à un non-membre : réplique ordinaire")
	_etat({})

func _etat_texte(f: String, pnj_id: String, r: int) -> Array:
	_etat({f: [90.0, r]})
	var res: Array = []
	for r_: Dictionary in RepliquesFiltrees.charger():
		var fl: Dictionary = r_.get("filtres", {})
		if String(r_.get("sujet", "")) == "rang" and String(fl.get("pnj", "")) == pnj_id and String(fl.get("rang_faction", "")) == f \
				and (int(fl.get("rang_min", 0)) == r):
			res.append_array(r_["texte"])
	return res

# ============================================================================================== 2. quêtes de faction

func _quetes_de_faction() -> void:
	print("2. Quêtes de faction")
	var q: Node = m.quetes
	q.importer({})   # journal vierge : parler à Ylva en 1. a déjà lancé sa quête
	# déclencheurs : ils existent dans le monde
	var grotte := FileAccess.get_file_as_string("res://scripts/grotte_donnees.gd")
	var tertre := FileAccess.get_file_as_string("res://scripts/tertre.gd")
	var cad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/butin/cadavres.json"))
	var garanti := false
	for e: Dictionary in cad["tables"]["cadavre_troll"].get("garanti", []):
		garanti = garanti or e["id"] == "fourrure_troll"
	_verif(grotte.contains("\"id\": \"bandit_4\"") and grotte.contains("\"id\": \"bandit_7\"") and grotte.contains("\"id\": \"troll_lac\""),
		"ennemis bandit_4, bandit_7 et troll_lac présents dans la grotte (événements tue:<id>)")
	_verif(grotte.contains("\"genre\": \"cristal_givre\"") and Inventaire.OBJETS.has("cristal_givre") and tertre.contains("signaler(\"lieu:tertre\")"),
		"cristal de givre à ramasser dans la grotte, seuil du tertre (lieu:tertre)")
	_verif(garanti and Inventaire.OBJETS.has("fourrure_troll"), "le cadavre du troll donne toujours une fourrure (butin garanti)")
	var defs := [
		{"id": "veille_mine", "f": G, "chef": "garde", "rmin": 2, "rep": 12.0, "objets": {"casque_fer": 1, "potion_soin_forte": 1},
			"etapes": ["tue:bandit_4", "tue:bandit_7"], "sac": {}},
		{"id": "cendre_runes", "f": C, "chef": "volva", "rmin": 1, "rep": 12.0, "objets": {"anneau_adepte": 1},
			"etapes": ["+cristal_givre", "lieu:tertre"], "sac": {"cristal_givre": 0}},
		{"id": "peau_troll", "f": H, "chef": "chasseuse", "rmin": 2, "rep": 14.0, "objets": {"armure_fourrure": 1},
			"etapes": ["tue:troll_lac", "+fourrure_troll"], "sac": {"fourrure_troll": 0}},
	]
	for dq: Dictionary in defs:
		var id: String = dq["id"]
		var f: String = dq["f"]
		var chef_id: String = dq["chef"]
		var chef := _pnj(chef_id)
		var qd: Dictionary = q._quete(id)
		var n: int = (qd["etapes"] as Array).size()
		_verif(n >= 3 and n <= 4 and qd["donneur"] == chef_id and (qd["recompense"]["reputation"] as Dictionary).has(f), "%s : %d étapes, donnée par %s, récompense en réputation de %s" % [id, n, chef_id, rg.nom(f)])
		# trop bas : rien
		_etat({f: [80.0, int(dq["rmin"]) - 1]})
		if f != C:
			rg._rep[C] = 20.0
		q.repliques(chef_id, chef)
		_verif(q.index(id) == 0, "%s : au rang %d (%s), %s ne la propose pas" % [id, int(dq["rmin"]) - 1, rg.nom_rang(f, int(dq["rmin"]) - 1), chef_id])
		# au rang minimal : proposée et commencée
		_etat({f: [80.0, int(dq["rmin"])]})
		if f != C:
			rg._rep[C] = 20.0
		var l: Array = q.repliques(chef_id, chef)
		_verif(q.index(id) == 1 and _txt(l).contains(String(rg.nom_rang(f, int(dq["rmin"])))), "%s : au rang %s, %s la propose et le journal s'ouvre (« %s »)" % [id, rg.nom_rang(f, int(dq["rmin"])), chef_id, _txt(l).left(50)])
		var l2: Array = q.repliques(chef_id, chef)
		_verif(q.index(id) == 1 and not l2.is_empty() and l2 != l, "%s : reparler au chef ne la relance pas, il rappelle la tâche" % id)
		# les étapes, par les vrais événements du jeu
		var rep0 := rg.reputation(f)
		var rival0 := rg.reputation(C)
		var obj0 := {}
		for o: String in dq["objets"]:
			obj0[o] = j.inventaire.nombre(o)
		for e: String in dq["etapes"]:
			var avant: int = q.index(id)
			if e.begins_with("+"):
				j.inventaire.ajouter(e.substr(1), 1)   # le sac signale « ramasse:<objet> »
			else:
				q.signaler(e)
			_verif(q.index(id) == avant + 1, "%s : étape « %s » franchie (index %d)" % [id, e, q.index(id)])
		_verif(q.index(id) == n - 1 and not q.fini(id), "%s : reste à rendre compte au chef" % id)
		var lf: Array = q.repliques(chef_id, chef)
		_verif(q.fini(id) and not lf.is_empty(), "%s : TERMINÉE en parlant à %s" % [id, chef_id])
		_verif(is_equal_approx(rg.reputation(f) - rep0, float(dq["rep"])), "%s : +%d de réputation %s (%.1f -> %.1f)" % [id, int(dq["rep"]), rg.nom(f), rep0, rg.reputation(f)])
		var objs_ok := true
		for o: String in dq["objets"]:
			objs_ok = objs_ok and j.inventaire.nombre(o) == int(obj0[o]) + int(dq["objets"][o])
		_verif(objs_ok, "%s : objet(s) reçu(s) %s" % [id, str(dq["objets"])])
		for o: String in dq["sac"]:
			_verif(j.inventaire.nombre(o) == int(dq["sac"][o]), "%s : l'objet de quête (%s) est repris" % [id, o])
		if f == G:
			_verif(rg.reputation(C) < rival0 and is_equal_approx(rival0 - rg.reputation(C), 12.0 * 0.25), "%s : rivalité, le Cercle perd 25 %% de 12 (%.1f -> %.1f)" % [id, rival0, rg.reputation(C)])
		var datees := true
		for e: Dictionary in q.entrees(id):
			datees = datees and int(e["jour"]) > 0
		_verif(q.entrees(id).size() == n and datees, "%s : journal de %d entrées, toutes datées" % [id, n])
		var l3: Array = q.repliques(chef_id, chef)
		_verif(q.index(id) == n and not _txt(l3).contains("propose"), "%s : une fois finie, elle ne revient pas" % id)
	# aucune étape ne mène à un lieu inconnu : les ennemis et objets de l'avancement ont une cible de carte
	var cibles_ok := true
	for dq: Dictionary in defs:
		for e: String in dq["etapes"]:
			var cle: String = e.substr(1) if e.begins_with("+") else e
			cle = "ramasse:" + cle if e.begins_with("+") else cle
			cibles_ok = cibles_ok and (Lieux.CIBLES.has(cle) or cle == "lieu:tertre")
	_verif(cibles_ok, "chaque étape a sa cible sur la carte (Lieux.CIBLES)")
	_etat({})

# ============================================================================================== 3. crime -> réputation

func _crime_et_reputation() -> void:
	print("3. Crime et réputation de faction")
	var bareme: Dictionary = rg.d["crime"]["vu"]
	_verif(bareme.size() >= 5 and rg.faction_juridiction("skarnholt") == G, "barème en data : %d types de crime, juridiction de Skarnholt = Garde du jarl" % bareme.size())
	for type: String in bareme:
		_etat({G: [40.0, 1]})
		cr._commettre(type, 0.0, [])
		_verif(is_equal_approx(rg.reputation(G), 40.0 - float(bareme[type])) and rg.rang(G) == 1, "crime vu « %s » : Garde 40 -> %.0f (barème %d)" % [type, rg.reputation(G), int(bareme[type])])
		cr._gracier()
		cr.perdue_factions.clear()
	# un crime non vu n'est pas puni : aucun appel à _commettre sans témoin
	_etat({G: [40.0, 1]})
	var obj := Node3D.new()
	obj.set_meta("id_objet", "coupe_argent")
	m.add_child(obj)
	var loin := Vector3(44.0, m.hauteur(44.0, 160.0) + 0.1, 160.0)
	j.global_position = loin
	await _attendre(0.3)
	var vu := cr.signaler_vol(obj, "forgeron", loin)
	_verif(not vu and rg.reputation(G) == 40.0, "vol sans témoin : la Garde ne perd rien")
	obj.queue_free()
	# exclusion
	_etat({G: [5.0, 2]})
	cr._commettre("meurtre", 0.0, [])
	_verif(rg.reputation(G) == -15.0 and rg.rang(G) == -1, "meurtre vu à 5 de réputation : -15, EXCLU de la Garde (rang %d)" % rg.rang(G))
	_verif(_txt(rg.adherer(G)).contains("ruinée"), "exclu : le chef refuse de le reprendre tant que la réputation est négative")
	cr._gracier()
	cr.perdue_factions.clear()
	# dette réglée : amende, puis geôle
	_etat({G: [40.0, 1]})
	cr.perdue_factions.clear()
	cr.perdue[Crime.JURIDICTION] = 0.0
	cr._commettre("agression", 40.0, [])
	cr._commettre("vol", 5.0, [])
	var perdu := 6.0 + 3.0
	_verif(is_equal_approx(rg.reputation(G), 40.0 - perdu) and is_equal_approx(float(cr.perdue_factions.get(G, 0.0)), perdu), "agression + vol : Garde 40 -> %.0f, %.0f perdus mémorisés" % [rg.reputation(G), float(cr.perdue_factions.get(G, 0.0))])
	var ex := cr.exporter()
	var copie: Dictionary = JSON.parse_string(JSON.stringify(ex))
	_verif(is_equal_approx(float((copie["perdue_factions"] as Dictionary).get(G, 0.0)), perdu), "sauvegarde « crime » : réputation de faction perdue relue")
	j.inventaire.pieces = 500
	var part_a := float(cr.disposition._sous("retour_reputation", "amende", 0.25))
	var part_g := float(cr.disposition._sous("retour_reputation", "geole", 0.5))
	var avant := rg.reputation(G)
	_verif(cr.payer_amende(), "amende payée")
	_verif(is_equal_approx(rg.reputation(G), avant + perdu * part_a), "amende : la Garde rend %.0f %% de la perte (%.2f -> %.2f)" % [part_a * 100.0, avant, rg.reputation(G)])
	_verif(cr.perdue_factions.is_empty(), "dette soldée : plus rien à rendre")
	_etat({G: [40.0, 1]})
	cr._commettre("agression", 40.0, [])
	avant = rg.reputation(G)
	var h0: float = m.cycle.heure
	cr.aller_en_prison()
	_verif(is_equal_approx(rg.reputation(G), avant + 6.0 * part_g), "geôle : la Garde rend %.0f %% de la perte (%.2f -> %.2f)" % [part_g * 100.0, avant, rg.reputation(G)])
	m.cycle.heure = 12.0
	cr._gracier()
	# meurtre d'un membre : sa faction, vu ou non
	cr.perdue_factions.clear()
	_etat({H: [40.0, 1]})
	var ylva := _pnj("chasseuse")
	j.global_position = Vector3(44.0, m.hauteur(44.0, 160.0) + 0.1, 160.0)
	var g_avant := rg.reputation(G)
	ylva.global_position = j.global_position + Vector3(0, 0, -3.0)
	var cle := cr.cle_pnj(ylva)
	cr.signaler_meurtre(ylva)
	_verif(cr.morts.has(cle) and is_equal_approx(rg.reputation(H), 40.0 - 25.0) and rg.rang(H) == 1, "meurtre d'Ylva : les Chasseurs perdent 25 (40 -> %.0f)" % rg.reputation(H))
	cr.signaler_meurtre(ylva)
	_verif(is_equal_approx(rg.reputation(H), 15.0), "le même mort n'est puni qu'une fois")
	_verif(rg.reputation(G) == g_avant, "personne ne tient la Garde pour responsable d'un meurtre non vu d'une chasseuse")
	_etat({H: [10.0, 1]})
	cr.morts.erase(cle)
	cr.signaler_meurtre(ylva)
	_verif(rg.reputation(H) == -15.0 and rg.rang(H) == -1, "assez de meurtres : réputation négative, exclu des Chasseurs")
	cr.morts.erase(cle)
	cr._gracier()
	cr.apaiser_tous()
	# garde du village tué : la Garde
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = gv.gardes[0]
	_etat({G: [60.0, 3]})
	var cleg := cr.cle_pnj(g)
	cr.signaler_meurtre(g)
	_verif(rg.reputation(G) <= 35.0 and rg.faction_du_membre(cleg) == G, "un garde du village tué : la Garde perd au moins 25 (60 -> %.0f)" % rg.reputation(G))
	cr.morts.erase(cleg)
	cr.perdue_factions.clear()
	cr._gracier()
	cr.apaiser_tous()
	_etat({})

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
