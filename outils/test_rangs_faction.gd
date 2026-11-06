extends SceneTree
## Factions humaines jouables et rangs (scripts/rangs.gd, data/factions_joueur.json), dans le vrai monde :
##   - contrat (groupe « rangs » : rang, reputation, ajouter_reputation), données cohérentes (seuils croissants, chefs réels) ;
##   - adhésion, SEUILS (réputation et compétences : le refus dit ce qui manque), SAUT de rangs, DÉLAI de 7 jours, sommet ;
##   - EXCLUSION (réputation négative, immédiate et à la demande), rivalités (jamais sous 0 par ricochet) ;
##   - avantages : remise de Brodd (prix d'achat), repos « bien reposé » dans un lit libre, objets du rang ;
##   - récompense de quête (réputation de faction), options et répliques du dialogue du chef ;
##   - SAUVEGARDE (aller-retour JSON, clé du monde) et migration d'une ancienne partie (non membre partout).
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_rangs_faction.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var rg: Rangs
var j: CharacterBody3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await physics_frame

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id:
			return v
	return null

func _niveaux(v: int) -> void:
	for c in Competences.NOMS:
		j.progression.competences.niveaux[c] = v

func _txt(l: Array) -> String:
	return " | ".join(l.map(func(x: Variant) -> String: return String(x)))

func _remettre() -> void:
	rg.restaurer({})
	_niveaux(15)

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
	_verif(rg != null and Rangs.courant == rg and rg.is_in_group("rangs"), "nœud Rangs branché, groupe « rangs », service courant")
	if rg == null:
		_fin()
		return
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.heure = 12.0
	# ------------------------------------------------------------------ données
	_verif(rg.factions().size() >= 2 and rg.factions().size() <= 3, "2 ou 3 factions : %s" % str(rg.factions()))
	var ok_d := true
	for f: String in rg.factions():
		var n := rg.nb_rangs(f)
		var fi := rg.fiche(f)
		ok_d = ok_d and n >= 4 and n <= 5 and (fi["rep_min"] as Array).size() == n and (fi["skill_haut"] as Array).size() == n and (fi["skill_bas"] as Array).size() == n
		for i in range(1, n):
			ok_d = ok_d and rg.rep_min(f, i) > rg.rep_min(f, i - 1) and rg.skill_haut(f, i) > rg.skill_haut(f, i - 1)
		ok_d = ok_d and _pnj(String(fi["chef"])) != null and (fi["competences"] as Array).size() >= 3
		for c: String in fi["competences"]:
			ok_d = ok_d and Progression.COMPETENCES.has(Progression.canonique(c))
		for k: String in fi.get("rivalites", {}):
			ok_d = ok_d and rg.factions().has(k)
	_verif(ok_d, "4-5 rangs, seuils croissants, tableaux de même longueur, chefs présents au village, compétences et rivalités valides")
	_remettre()
	_verif(rg.rang("garde_jarl") == -1 and rg.rang("inconnue") == -1 and rg.reputation("garde_jarl") == 0.0, "nouvelle partie : non membre partout, réputation 0 ; faction inconnue : -1")
	# ------------------------------------------------------------------ adhésion et seuils
	var G := "garde_jarl"
	var l := rg.adherer(G)
	_verif(rg.rang(G) == 0 and not l.is_empty(), "adhésion à la Garde : rang 0 (%s)" % rg.nom_rang(G, 0))
	_verif(String(rg.adherer(G)[0]) == String((rg.fiche(G)["voix"]["deja"] as Array)[0]), "déjà membre : réplique « déjà des nôtres »")
	j.progression.competences.niveaux["epee"] = 18
	rg.ajouter_reputation(G, 9.0)
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 0 and _txt(l).contains("10 de réputation et Une main à 22"), "refus qui DIT ce qui manque : %s" % _txt(l))
	rg.ajouter_reputation(G, 1.0)
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 0 and _txt(l).contains("Une main à 22") and not _txt(l).contains("de réputation"), "réputation suffisante, compétence trop basse : « %s »" % _txt(l))
	j.progression.competences.niveaux["epee"] = 22
	j.progression.competences.niveaux["parade"] = 5
	j.progression.competences.niveaux["armure"] = 5
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 0 and _txt(l).contains(" à 8") and not _txt(l).contains("Une main"), "la SECONDE compétence compte aussi (bas) : « %s »" % _txt(l))
	j.progression.competences.niveaux["parade"] = 8
	# délai : adhésion à l'instant T, promotion méritée mais trop tôt
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 0 and _txt(l).contains("7 jour"), "mérité mais délai : reviens dans 7 jours (%s)" % _txt(l))
	Marchand.avancer(24.0 * 3.0)
	_verif(is_equal_approx(rg.delai_restant(G), 4.0), "3 jours plus tard : délai restant 4 jours (%.2f)" % rg.delai_restant(G))
	Marchand.avancer(24.0 * 4.0)
	var potions0: int = j.inventaire.nombre("potion_soin")
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 1 and rg.nom_rang(G, 1) == "Porte-bouclier", "7 jours écoulés : promu %s (%s)" % [rg.nom_rang(G, rg.rang(G)), _txt(l)])
	_verif(_txt(l).contains("Porte-bouclier"), "la réplique de promotion nomme le rang")
	# saut de rangs : tout mérité d'un coup, après le délai
	rg.ajouter_reputation(G, 200.0)
	_niveaux(100)
	var delai_avant := rg.delai_restant(G)
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 1 and delai_avant > 6.9 and _txt(l).contains("jour"), "tout mérité mais le délai court encore : pas de promotion (%s)" % _txt(l))
	Marchand.avancer(24.0 * 7.0)
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == 4 and rg.nom_rang(G, 4) == "Champion du jarl", "SAUT : du rang 1 au rang 4 d'un coup (%s)" % rg.nom_rang(G, rg.rang(G)))
	_verif(j.inventaire.nombre("potion_soin") == potions0 + 2 and j.inventaire.nombre("potion_soin_forte") >= 1, "objets des rangs sautés donnés (2 potions de soin du rang 2, 1 grande potion du rang 4)")
	_verif(_txt(rg.promouvoir(G)).contains(String((rg.fiche(G)["voix"]["sommet"] as Array)[0])), "au sommet : plus de rang à donner")
	# ------------------------------------------------------------------ avantages
	var fav := Marchand.faveur("forgeron")
	var sans := fav - Rangs.remise("forgeron")
	_verif(is_equal_approx(Rangs.remise("forgeron"), 0.18) and fav > sans, "Champion : remise de Brodd 18 %% (faveur %.3f contre %.3f)" % [fav, sans])
	var prix_membre := Marchand.prix_achat("forgeron", "potion_soin")
	rg.restaurer({})
	var prix_nu := Marchand.prix_achat("forgeron", "potion_soin")
	_verif(prix_membre < prix_nu, "prix d'achat chez Brodd : %d pièces pour le Champion, %d pour un inconnu" % [prix_membre, prix_nu])
	_verif(Rangs.remise("ancienne") == 0.0 and not Rangs.repos_bien(), "non membre : aucune remise, pas de repos de faveur")
	var C := "cercle_sigrun"
	rg.restaurer({"rep": {C: 80.0}, "rang": {C: 1}, "dernier": {C: 0.0}})
	_verif(not Rangs.repos_bien(), "Cercle rang 1 : pas encore de lit de veille")
	rg.restaurer({"rep": {C: 80.0}, "rang": {C: 2}, "dernier": {C: 0.0}})
	_verif(Rangs.repos_bien(), "Cercle rang 2 : lit de veille")
	var lit := Lit.creer(1.0)   # lit libre (sans propriétaire), hors décor : seul son statut compte
	if lit.libre():
		m.sommeil.passer_temps(8, "dormir", lit)
		var avec: String = m.sommeil.repos
		m.sommeil._fin_repos()
		rg.restaurer({})
		m.sommeil.passer_temps(8, "dormir", lit)
		var sans_r: String = m.sommeil.repos
		m.sommeil._fin_repos()
		_verif(avec == "bien_repose" and sans_r == "repose", "lit libre : « %s » avec le lit de veille, « %s » sans" % [avec, sans_r])
	lit.free()
	# ------------------------------------------------------------------ exclusion et rivalités
	_remettre()
	rg.adherer(G)
	rg.ajouter_reputation(G, 30.0)
	rg.ajouter_reputation(G, -80.0)
	_verif(rg.rang(G) == -1 and rg.reputation(G) == -50.0, "réputation négative : exclu sur-le-champ (rang %d, réputation %.0f, bornée à -50)" % [rg.rang(G), rg.reputation(G)])
	l = rg.adherer(G)
	_verif(rg.rang(G) == -1 and _txt(l).contains("ruinée"), "exclu : ne peut pas revenir tant que la réputation est négative (%s)" % _txt(l))
	rg.ajouter_reputation(G, 50.0)
	rg.adherer(G)
	_verif(rg.rang(G) == 0, "réputation remontée à 0 : peut rentrer")
	rg._rep[G] = -5.0      # exclusion À LA DEMANDE (réputation passée sous 0 sans passer par ajouter_reputation)
	l = rg.promouvoir(G)
	_verif(rg.rang(G) == -1 and _txt(l).contains(String((rg.fiche(G)["voix"]["exclu"] as Array)[0])), "exclusion à la demande du chef : %s" % _txt(l))
	_remettre()
	rg.ajouter_reputation(G, 20.0)
	rg.ajouter_reputation(C, 40.0)
	_verif(is_equal_approx(rg.reputation(G), 10.0) and rg.reputation(C) == 40.0, "rivalité : +40 au Cercle retire 25 %% à la Garde (20 -> %.1f)" % rg.reputation(G))
	rg.ajouter_reputation(C, 200.0)
	_verif(rg.reputation(G) == 0.0, "la rivalité ne descend jamais sous 0 (Garde : %.1f)" % rg.reputation(G))
	var H := "chasseurs"
	rg.ajouter_reputation(H, 30.0)
	_verif(rg.reputation(G) == 0.0 and rg.reputation(C) == 100.0, "les Chasseurs n'ont pas de rivale")
	# ------------------------------------------------------------------ quêtes : récompenses de réputation
	_remettre()
	var q_ok := true
	for q: Dictionary in m.quetes.donnees["quetes"]:
		var r: Dictionary = q.get("recompense", {})
		if r.get("reputation") is Dictionary:
			for f: String in r["reputation"]:
				q_ok = q_ok and rg.factions().has(f)
	_verif(q_ok, "recompense.reputation des quêtes : factions toutes connues")
	rg.ajouter_reputation(G, 20.0)
	var qs: Dictionary = m.quetes._quete("sceaux_brises")
	m.quetes.etat["sceaux_brises"] = (qs["etapes"] as Array).size() - 1
	m.quetes._completer(qs, (qs["etapes"] as Array).size() - 1)
	_verif(rg.reputation(C) == 25.0 and is_equal_approx(rg.reputation(G), 20.0 - 25.0 * 0.25), "quête des sceaux terminée : Cercle +25, Garde %.2f (rivale)" % rg.reputation(G))
	# ------------------------------------------------------------------ dialogue du chef
	_remettre()
	rg.ajouter_reputation(G, 30.0)
	Marchand.avancer(24.0 * 30.0)
	var garde := _pnj("garde")
	var av := garde.global_transform.basis.z
	av.y = 0.0
	var p := garde.global_position + av.normalized() * 1.6
	p.y = m.hauteur(p.x, p.z) + 0.1
	j.global_position = p
	await _attendre(0.2)
	var ok_o: bool = m.dialogue.engager(garde)
	var textes: Array = m.dialogue._options.map(func(o: Dictionary) -> String: return String(o["texte"]))
	_verif(ok_o and textes.any(func(t: String) -> bool: return t.begins_with("Rejoindre")), "chef non membre : option « %s »" % " / ".join(textes))
	await _jusquaux_choix()
	var i_o: int = textes.find(textes.filter(func(t: String) -> bool: return t.begins_with("Rejoindre"))[0])
	m.dialogue._choisir(i_o)
	m.dialogue._valider_choix()
	await _attendre(0.2)
	_verif(rg.rang(G) == 0 and m.dialogue._ouvert and String(m.dialogue._lignes[0]).contains("Veilleur"), "« Rejoindre » : rang 0 et le chef répond (« %s »)" % String(m.dialogue._lignes[0]).left(60))
	await _jusquaux_choix()
	textes = m.dialogue._options.map(func(o: Dictionary) -> String: return String(o["texte"]))
	_verif(textes.has("Demander une promotion"), "membre : option « Demander une promotion » (%s)" % " / ".join(textes))
	m.dialogue._choisir(textes.find("Demander une promotion"))
	m.dialogue._valider_choix()
	await _attendre(0.2)
	var dit := _txt(m.dialogue._lignes)
	_verif(rg.rang(G) == 0 and dit.contains("il te faut") and dit.contains("Une main à 22"), "promotion refusée au dialogue, avec ce qui manque : %s" % dit)
	m.dialogue._fermer()
	Marchand.avancer(24.0 * 7.0)
	j.progression.competences.niveaux["epee"] = 30
	j.progression.competences.niveaux["parade"] = 30
	ok_o = m.dialogue.engager(garde)
	await _jusquaux_choix()
	textes = m.dialogue._options.map(func(o: Dictionary) -> String: return String(o["texte"]))
	m.dialogue._choisir(textes.find("Demander une promotion"))
	m.dialogue._valider_choix()
	await _attendre(0.2)
	_verif(rg.rang(G) >= 1 and m.dialogue._ouvert, "promotion acceptée au dialogue : %s (%s)" % [rg.nom_rang(G, rg.rang(G)), _txt(m.dialogue._lignes)])
	m.dialogue._fermer()
	# ------------------------------------------------------------------ sauvegarde
	_remettre()
	rg.adherer(G)
	rg.ajouter_reputation(G, 33.0)
	rg.ajouter_reputation(H, 12.0)
	var js: Variant = JSON.parse_string(JSON.stringify(rg.exporter()))
	var avant := rg.exporter()
	rg.restaurer({})
	_verif(rg.rang(G) == -1 and rg.reputation(G) == 0.0, "ancienne partie (clé absente) : non membre partout")
	rg.restaurer(js)
	_verif(rg.rang(G) == 0 and rg.reputation(G) == 33.0 and rg.reputation(H) == 12.0 and JSON.stringify(rg.exporter()) == JSON.stringify(avant), "aller-retour JSON : rang et réputations identiques (%s)" % JSON.stringify(rg.exporter()))
	_verif(Rangs.new().exporter().has("rang"), "exporter() d'un nœud neuf valide")
	m.sauvegarder(Sauvegardes.AUTO)
	var f := Sauvegardes.fichier(Sauvegardes.AUTO)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	_verif(d is Dictionary and (d as Dictionary).get("rangs") is Dictionary and float(d["rangs"]["rep"].get(G, 0)) == 33.0, "la sauvegarde du monde contient « rangs » (rep Garde 33)")
	rg.restaurer({"rep": {"faction_morte": 50.0, G: 500.0}, "rang": {G: 99, "faction_morte": 1}})
	_verif(rg.reputation(G) == 100.0 and rg.rang(G) == rg.nb_rangs(G) - 1 and rg.reputation("faction_morte") == 0.0, "données corrompues ou obsolètes : bornées, factions inconnues ignorées")
	_fin()

func _jusquaux_choix() -> bool:
	for k in 400:
		await process_frame
		if m.dialogue._choix_vis or not m.dialogue._ouvert:
			break
		m.dialogue._suite()
	return m.dialogue._choix_vis

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
