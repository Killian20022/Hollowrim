extends SceneTree
## Test sans fenêtre : accueil du joueur (prologue, premier objectif, bulles d'aide), quêtes qui se répondent (Sigrún donneuse des
## sceaux, indice sur Hrafn, répliques « après »), fin du premier chapitre (teaser du château), compatibilité des sauvegardes.
##   godot --headless --path . --script res://outils/test_prologue.gd -- --nouvelle --prologue --aides
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var bon := true

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	bon = bon and ok

func _villageois(id: String) -> Node:
	for v in m.get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id") == id:
			return v
	return null

func _parler(id: String) -> Array:
	var lignes: Array = _villageois(id).parler()
	_villageois(id).fin_conversation()
	return lignes

## Texte d'une réplique de data/dialogue/repliques.json (par identifiant).
func _texte_replique(id: String) -> Array:
	for r: Dictionary in RepliquesFiltrees.charger():
		if r.get("id") == id:
			return r["texte"]
	return []

func _contient(lignes: Array, mot: String) -> bool:
	return " ".join(PackedStringArray(lignes.map(func(l: Variant) -> String: return str(l)))).contains(mot)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 20:
		await process_frame
	var q = m.quetes
	var n = m.narration
	var a = m.aides
	var j = m.joueur

	print("1. Prologue de la nouvelle partie")
	_verif(n.actif and n.pages.size() == 4 and n.titre == "Skarnholt", "l'écran d'arrivée est ouvert (4 pages, titre Skarnholt)")
	_verif(j.en_dialogue, "joueur figé pendant l'arrivée (ni marche ni combat)")
	_verif(not q.vus.has("prologue_vu") and not q.etat.has("bienvenue"), "aucun objectif avant la fin de l'arrivée")
	_verif(m.hud.aide_t == 0.0 and not a.actif, "cartouche des touches et bulles attendent la fin de l'arrivée")
	n._t = 1.0
	n.page = 3
	n._terminer()   # comme Échap (passer)
	await create_timer(1.0).timeout
	_verif(not n.actif and not j.en_dialogue, "arrivée passable : écran refermé, joueur libre")

	print("2. Premier objectif : aller voir Gunnhild")
	_verif(q.vus.has("prologue_vu") and q.etat.get("bienvenue", 0) == 1, "quête « Skarnholt » lancée à la fin de l'arrivée")
	var obj: Array = q.objectifs()
	_verif(not obj.is_empty() and String(obj[-1][1]).contains("Gunnhild"), "objectif affiché : « %s »" % (obj[-1][1] if not obj.is_empty() else ""))
	var cibles: Array = Lieux.cibles_quetes(q, m)
	var chef: Node3D = _villageois("chef")
	var ok_cible := false
	for c: Dictionary in cibles:
		if c["quete"] == "bienvenue" and (c["pos"] as Vector3).distance_to(chef.global_position) < 1.0:
			ok_cible = true
	_verif(ok_cible, "la boussole vise Gunnhild elle-même (marqueur de quête)")
	_verif(m.hud.aide_t > 0.0 and a.actif, "cartouche des touches affiché, bulles d'aide actives")

	print("3. Gunnhild renvoie vers Sigrún, Sigrún donne les sceaux")
	var l_chef := _parler("chef")
	_verif(q.etat.get("anneau_givre", 0) == 1 and q.etat.get("bienvenue", 0) == 2, "parler à Gunnhild : anneau de givre lancée, « Skarnholt » terminée")
	_verif(_contient(l_chef, "Sigrún") and _contient(l_chef, "sceaux"), "Gunnhild renvoie vers Sigrún avant le tertre")
	_verif(q.etat.get("sceaux_brises", -1) == -1, "les sceaux ne démarrent pas tout seuls")
	var l_volva := _parler("volva")
	_verif(q.etat.get("sceaux_brises", 0) == 1 and _contient(l_volva, "Os") and _contient(l_volva, "socles"), "Sigrún donne la quête des sceaux brisés")
	var l_volva2 := _parler("volva")
	_verif(_contient(l_volva2, "Réunis-les"), "pendant la quête, Sigrún parle des sceaux (pas de l'anneau)")

	print("4. Indice sur Hrafn dès la première conversation de Haldor")
	var l_garde := _parler("garde")
	_verif(_contient(l_garde, "bandits") and _contient(l_garde, "Hrafn"), "Haldor parle des bandits et de Hrafn dès sa première rencontre")
	_verif(q.etat.get("repaire_hrafn", 0) == 1, "quête du repaire lancée")
	_verif(not _contient(_texte_replique("chasseuse.frere_ylva.fin"), "arc"), "plus d'arc d'Ylva dans ses répliques de quête")
	var ylva: Dictionary = _villageois("chasseuse").donnees
	_verif(not _contient(ylva["apres"], "arc bandé"), "Ylva ne parle plus d'un arc que le joueur n'a pas")
	_verif(_contient(_villageois("forgeron").donnees["lignes"], "compagnons"), "Brodd : Eirik avait des compagnons")

	_verif(_contient(_villageois("garde").donnees["lignes"], "bandits") and _contient(_villageois("garde").donnees["apres"], "Hrafn"), "Haldor : l'indice Hrafn est aussi dans ses lignes fixes")
	_verif(_contient(l_garde, "Hrafn"), "(et dans la conversation de quête)")
	_verif(_contient(q.texte("note_eirik"), "croissant fendu") and _contient(q.texte("registre_hrafn"), "croissant fendu"), "le croissant fendu est sur la lettre d'Eirik et le registre de Hrafn")
	_verif(_contient(q.texte("note_compagnon_3"), "secours"), "note des compagnons : Eirik est parti chercher du secours")
	_verif(_contient(_villageois("garde").donnees["lignes"], "quatre autres"), "Haldor : les quatre autres étaient partis avant Eirik")
	print("5. Récompenses nommées")
	var recs := {}
	for qd: Dictionary in q.donnees["quetes"]:
		recs[qd["id"]] = qd.get("recompense", {}).get("objets", {})
	_verif(recs["anneau_givre"].has("amulette_givre") and Inventaire.OBJETS.has("amulette_givre"), "Gunnhild : l'amulette de givre, devenue unique")
	_verif(recs["frere_ylva"].has("manteau_loup_ylva"), "Ylva : la peau de loup promise (Manteau de loup d'Ylva)")
	_verif(recs["repaire_hrafn"].has("potion_soin") and recs["expedition_sigrun"].has("potion_soin_forte") and recs["sceaux_brises"].has("potion_mana"), "Haldor, Grima, Sigrún remettent aussi un objet")
	_verif(Inventaire.OBJETS["manteau_loup_ylva"].get("nom", "") == "Manteau de loup d’Ylva", "nom affiché du manteau")
	_verif(Inventaire.OBJETS["journal_sigrun"]["nom"] == "Journal de Solveig" and Inventaire.OBJETS["broche_sigrun"]["nom"] == "Broche de Solveig", "expédition : noms affichés « Solveig » (ids inchangés)")
	var butins := FileAccess.get_file_as_string("res://scripts/grotte_donnees.gd")
	_verif(not butins.contains("\"amulette_givre\""), "amulette de givre retirée de tous les coffres de la grotte (unique : récompense)")
	for qid in recs:
		for oid in recs[qid]:
			_verif(Inventaire.OBJETS.has(oid), "objet de récompense « %s » existe" % oid)

	print("6. Répliques « après » selon l'état des quêtes")
	var etat0: Dictionary = q.etat.duplicate()
	var vus0: Dictionary = q.vus.duplicate()
	q.etat = {"repaire_hrafn": 5}
	_verif(_contient(q.apres("garde"), "registre"), "Haldor : Hrafn tué → il parle du registre")
	q.etat = {"repaire_hrafn": 5, "anneau_givre": 6}
	_verif(_contient(q.apres("garde"), "morts qui marchent"), "Haldor : Hrafn tué ET anneau rendu → autre réplique")
	q.etat = {"anneau_givre": 6}
	q.vus = {"choix:piller_offrandes": true}
	_verif(_contient(q.apres("forgeron"), "pillé"), "Brodd : le pillage des offrandes se sait")
	q.vus = {}
	_verif(q.apres("forgeron").size() > 0 and _contient(q.apres("forgeron"), "anneau gris"), "Brodd : anneau rendu → réplique")
	q.etat = {}
	_verif(q.apres("garde").is_empty(), "aucune condition remplie → vide (réplique fixe de villageois.json)")
	q.etat = etat0
	q.vus = vus0

	print("7. Fin du premier chapitre et teaser du château")
	q.importer({"etat": {"anneau_givre": 5, "bienvenue": 2}, "vus": [], "journal": []})
	_verif(not q.fini("anneau_givre") and q.en_cours("anneau_givre"), "anneau de givre à une étape de la fin")
	var l_fin := _parler("chef")
	_verif(q.fini("anneau_givre") and q.etat.get("horizon_sud", 0) == 1, "anneau rendu à Gunnhild → « La lueur du sud » commence")
	_verif(_contient(l_fin, "croissant") and _contient(l_fin, "Kaldborg") and _contient(l_fin, "Sigrún"), "Gunnhild reconnaît le sceau de la dîme (Kaldborg) et envoie vers Sigrún")
	_verif(j.inventaire.a("amulette_givre"), "l'amulette de givre est dans le sac")
	await create_timer(2.0).timeout
	_verif(n.actif and n.titre == "Svanhild dort" and n.sous_titre == "Fin du premier chapitre", "écran de fin du premier chapitre")
	n._t = 1.0
	n._terminer()
	await create_timer(1.0).timeout
	var l_cendres := _parler("volva")
	_verif(q.etat.get("horizon_sud", 0) == 2 and _contient(l_cendres, "Kaldborg"), "Sigrún montre le château du sud")
	var vers_chateau := false
	for c: Dictionary in Lieux.cibles_quetes(q, m):
		if c["quete"] == "horizon_sud" and c["lieu"] == "chateau":
			vers_chateau = true
	_verif(vers_chateau and String(q.objectifs()[-1][1]).contains("Kaldborg"), "objectif « À suivre » + boussole vers le château")
	_verif(_contient(q.apres("chef"), "Kaldborg"), "Gunnhild commente le château ensuite")
	var fini_avant: bool = q.fini("anneau_givre")
	q.importer(JSON.parse_string(JSON.stringify(q.exporter())))
	_verif(q.fini("anneau_givre") == fini_avant and q.etat.get("horizon_sud", 0) == 2, "sauvegarde → rechargement : même état")

	print("8. Sauvegardes existantes")
	var attendu := {"anneau_givre": 6, "frere_ylva": 3, "lames_brodd": 4, "repaire_hrafn": 5, "expedition_sigrun": 4, "sceaux_brises": 5, "jarl_gele": 3}
	for id in attendu:
		_verif(q._quete(id).get("etapes", []).size() == attendu[id], "quête « %s » : %d étapes inchangées" % [id, attendu[id]])
	for id in ["amulette_givre", "anneau_givre", "amulette_eirik", "journal_sigrun", "broche_sigrun", "registre_hrafn", "fragment_sceau_os"]:
		_verif(Inventaire.OBJETS.has(id), "objet « %s » toujours présent" % id)
	q.importer({"etat": {"anneau_givre": 6, "frere_ylva": 3}, "vus": [], "journal": []})
	_verif(q.etat.get("horizon_sud", 0) == 1 and not q.etat.has("bienvenue"), "ancienne partie, anneau déjà rendu : la suite du récit se propose, pas de prologue rétroactif")
	q.importer({"etat": {"anneau_givre": 2}, "vus": [], "journal": []})
	_verif(not q.etat.has("horizon_sud"), "ancienne partie en cours : rien de plus")

	print("9. Bulles d'aide, une seule fois")
	a.vues = {}
	a._file.clear()
	a._cle = ""
	a._repit = 0.0
	_verif(a.proposer("ennemi") and not a.proposer("ennemi"), "une aide ne se met pas deux fois en file")
	for i in 20:
		await process_frame
	_verif(a.cle_courante() == "ennemi" and a.vues.has("ennemi") and a.alpha() > 0.0, "la bulle « ennemi » s'affiche")
	a._t = a.DUREE
	for i in 5:
		await process_frame
	_verif(a.cle_courante() == "" and not a.proposer("ennemi"), "bulle refermée, jamais revue")
	var sauve: Array = a.exporter()
	a.vues = {}
	a.importer(JSON.parse_string(JSON.stringify(sauve)))
	_verif(a.vues.has("ennemi") and not a.proposer("ennemi"), "bulles vues : sauvegardées et relues")
	a.tout_vu()
	_verif(not a.proposer("sort") and not a.proposer("coffre") and not a.proposer("menu"), "ancienne sauvegarde (tout_vu) : aucune bulle")
	a.vues = {}
	Jeu.options["jeu"]["aides"] = false
	_verif(not a.proposer("sort"), "option « Bulles d'aide » désactivée : rien")
	Jeu.options["jeu"]["aides"] = true
	_verif(Jeu.OPTIONS_DEFAUT["jeu"]["aides"] == true, "bulles d'aide activées par défaut")
	# déclencheurs
	a._file.clear()
	a._cle = ""
	var ennemi := Node3D.new()
	root.add_child(ennemi)
	m.hud._cible = ennemi
	m.hud._a_cible = 3.0
	a._sonder()
	_verif(a._file.has("ennemi"), "premier ennemi à l'écran → aide de combat")
	m.hud._cible = null
	ennemi.queue_free()
	a._file.clear()
	var avait_sort: bool = a._sort_en_main()
	print("   sort en main au départ : ", avait_sort)
	a._jeu_actif = a.DELAI_MENU
	a._sonder()
	_verif(a._file.has("menu"), "après un moment de jeu → rappel du menu et de la carte")
	for cle in a.TEXTES:
		_verif(String(a.TEXTES[cle][1]).length() > 20, "texte d'aide « %s » présent" % cle)

	print("TEST PROLOGUE : ", "OK" if bon else "ÉCHEC")
	quit()
