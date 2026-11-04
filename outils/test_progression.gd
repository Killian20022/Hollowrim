extends SceneTree
## RPG lot B (docs/RPG.md §13) : progression et arbre de compétences.
##   1. Compétences : les 8 gérées, courbe (premiers niveaux rapides puis ralentit), gains « xp_* » des perks.
##   2. Niveau du personnage : XP des montées de compétence, XP des quêtes (data/quetes.json recompense.xp).
##   3. Arbre data/competences/arbre.json : ~55 perks, 8 pierres, une racine par pierre, parents valides, rangs croissants,
##      clés d'effets connues.
##   4. Achat / prérequis (point, niveau de compétence, parent) / rang max / réinitialisation (Sigrún, 500 pièces).
##   5. Effets : ReglagesCombat.competence (dégâts une main / deux mains, armure, furtivité via CalculDegats), coûts de sorts,
##      parade, course, régénérations, saignement, vol de vie, riposte, récupération furtive ; joueur réel (vie / charge).
##   6. Sauvegarde : export / import des perks (perk inconnu ou rang en trop : point rendu), migration v1 -> v2.
##   godot --headless --path . --script res://outils/test_progression.gd -- --nouvelle

const SCENE := preload("res://scenes/test_combat.tscn")
## Clés d'effets autorisées dans l'arbre (docs/RPG.md §3 ; *_<comp> pour les compétences d'arme).
const CLES := ["une_main", "deux_mains", "parade", "armure", "destruction", "restauration", "furtivite",
	"destruction_feu", "destruction_glace", "destruction_electricite", "destruction_tenebres",
	"vie_max", "magie_max", "vigueur_max", "charge", "regen_vie", "regen_magie", "regen_vigueur",
	"resist_froid", "resist_feu", "resist_choc", "cout_sorts", "cout_destruction", "cout_restauration", "cout_protection",
	"cout_double", "cout_course", "saignement_une_main", "saignement_deux_mains", "vol_vie_une_main", "vol_vie_deux_mains",
	"etourdir_une_main", "etourdir_deux_mains", "vigueur_tue_une_main", "vigueur_tue_deux_mains", "riposte",
	"vigueur_parade", "etourdir_parade", "recup_furtif", "xp_une_main", "xp_deux_mains", "xp_parade", "xp_armure",
	"xp_destruction", "xp_restauration", "xp_furtivite", "xp_athletisme"]
const CIBLE := """extends Node3D
var vie := 100.0
func vivant() -> bool:
	return vie > 0.0
func en_combat() -> bool:
	return false
func recevoir_coup(d, _o, _p = false, _i = {}) -> String:
	vie -= d
	return "tue" if vie <= 0.0 else "touche"
"""

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _tester() -> void:
	_competences()
	_niveau()
	_arbre()
	_achat()
	_effets()
	_sauvegarde()
	await _joueur()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

## Progression « pleine » pour les tests d'achat : compétences au niveau voulu, points d'arbre.
func _prog(niveau_comp := 100, points := 200) -> Progression:
	var p := Progression.new()
	var niv := {}
	for c in Progression.COMPETENCES:
		niv[c] = niveau_comp
	p.importer({"points_perk": points, "competences": {"niveaux": niv}})
	return p

# ------------------------------------------------------------------ 1. compétences

func _competences() -> void:
	var c := Competences.new()
	_verif(c.niveaux.size() == 8 and c.niveaux.has("epee") and c.niveaux.has("destruction") and c.niveaux.has("athletisme"), "8 compétences gérées (epee = une_main)")
	var croissant := true
	for n in range(15, 100):
		croissant = croissant and Competences.seuil(n + 1) > Competences.seuil(n)
	_verif(croissant and Competences.seuil(15) < 5.0 and Competences.seuil(50) > 55.0 and Competences.seuil(99) > 240.0,
		"courbe croissante : 15->16 %.1f XP, 50->51 %.0f, 99->100 %.0f" % [Competences.seuil(15), Competences.seuil(50), Competences.seuil(99)])
	var p := Progression.new()
	for nom in Progression.COMPETENCES:
		p.pratiquer(nom, Competences.seuil(15) + 0.01)
	var tous := true
	for nom in Progression.COMPETENCES:
		tous = tous and p.competence(nom) == 16
	_verif(tous, "chaque compétence canonique monte à la pratique (15 -> 16)")
	p.pratiquer("une_main", 100000.0)
	_verif(p.competence("une_main") == 100 and p.competences.progression("epee") == 1.0, "plafond 100")
	# perk xp_ : +25 % de gain
	var q := _prog(20, 5)
	q.importer({"points_perk": 5, "competences": {"niveaux": {"une_main": 20}}})
	_verif(q.acheter_perk("lame_aguerrie") == "" and q.acheter_perk("eleve_de_tyr") == "", "achat Lame aguerrie puis Élève de Týr")
	var avant := float(q.competences.experience["epee"])
	q.pratiquer("une_main", 1.0)
	_verif(absf(float(q.competences.experience["epee"]) - avant - 1.25) < 0.001, "Élève de Týr : 1 XP pratiquée = 1,25 XP")

# ------------------------------------------------------------------ 2. niveau du personnage

func _niveau() -> void:
	var p := Progression.new()
	var niveaux := []
	p.niveau_perso.connect(func(n: int) -> void: niveaux.append(n))
	# 15 -> 25 en une main : 16 + … + 25 = 205 XP de niveau -> niveau 2 (150), 55 vers le 3
	var total := 0.0
	for n in range(15, 25):
		total += Competences.seuil(n)
	p.pratiquer("une_main", total + 0.001)
	_verif(p.competence("une_main") == 25 and p.niveau == 2 and absf(p.xp_niveau - 55.0) < 0.01 and niveaux == [2],
		"une main 15 -> 25 : +205 XP de niveau -> niveau 2 (+55)")
	_verif(p.points_perk == 1 and p.points_attribut == 1, "niveau 2 : 1 point d'arbre, 1 choix d'attribut")
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quetes.json"))
	var xp_ok := true
	var somme := 0.0
	for qd: Dictionary in lu["quetes"]:
		if qd.get("discrete", false):
			continue   # prologue et suite du récit : sans fanfare ni XP
		var x := float(qd.get("recompense", {}).get("xp", -1))
		xp_ok = xp_ok and x >= 100.0 and x <= 500.0
		somme += x
	_verif(xp_ok and Progression.XP_QUETE_DEFAUT == 150, "chaque quête a recompense.xp (100..500) ; défaut 150 inchangé ; total %.0f" % somme)
	p.gagner_xp(float(lu["quetes"][0]["recompense"]["xp"]))
	_verif(p.niveau == 3, "XP d'une quête (anneau de givre 200) : niveau 3")

# ------------------------------------------------------------------ 3. arbre

func _arbre() -> void:
	var a := Progression.arbre()
	var perks: Dictionary = a["perks"]
	_verif(perks.size() >= 50 and perks.size() <= 60, "arbre : %d perks (~55)" % perks.size())
	_verif(a["pierres"].size() == 8 and (a["ordre_pierres"] as Array).size() == 8, "8 pierres runiques")
	var pierres_ok := true
	for pid in a["pierres"]:
		pierres_ok = pierres_ok and pid in Progression.COMPETENCES and String(a["pierres"][pid]["competence"]) == pid
		var racines := 0
		for id in Progression.perks_de(pid):
			if (perks[id]["parents"] as Array).is_empty():
				racines += 1
		pierres_ok = pierres_ok and racines == 1 and Progression.perks_de(pid).size() >= 5
	_verif(pierres_ok, "une pierre par compétence canonique, une racine chacune, au moins 5 perks")
	var mauvais := []
	var rangs := 0
	for id in perks:
		var f: Dictionary = perks[id]
		var ok: bool = String(f.get("nom", "")) != "" and String(f.get("description", "")) != "" and a["pierres"].has(f.get("pierre", ""))
		for pa in f["parents"]:
			ok = ok and perks.has(pa) and perks[pa]["pierre"] == f["pierre"]
		var prec := 0
		for r: Dictionary in f["rangs"]:
			ok = ok and int(r["niveau"]) >= 15 and int(r["niveau"]) <= 100 and int(r["niveau"]) > prec and String(r.get("texte", "")) != ""
			ok = ok and not (r["effets"] as Dictionary).is_empty()
			prec = int(r["niveau"])
			for k in r["effets"]:
				ok = ok and k in CLES
			rangs += 1
		ok = ok and not (f["rangs"] as Array).is_empty() and (f.get("pos", []) as Array).size() == 2
		if not ok:
			mauvais.append(id)
	_verif(mauvais.is_empty(), "fiches valides (nom, description, parents de la même pierre, rangs 15..100 croissants, clés connues, pos) %s" % str(mauvais))
	# accessibilité : chaque perk atteignable depuis la racine
	var atteint := {}
	var change := true
	while change:
		change = false
		for id in perks:
			if atteint.has(id):
				continue
			var pa: Array = perks[id]["parents"]
			var ok := pa.is_empty()
			for x in pa:
				ok = ok or atteint.has(x)
			if ok:
				atteint[id] = true
				change = true
	_verif(atteint.size() == perks.size(), "tous les perks atteignables (pas de cycle)")
	_verif(rangs > Progression.NIVEAU_MAX - 1, "%d rangs au total : impossible de tout prendre (niveau max %d)" % [rangs, Progression.NIVEAU_MAX])

# ------------------------------------------------------------------ 4. achat, prérequis, réinitialisation

func _achat() -> void:
	var p := Progression.new()
	_verif(p.acheter_perk("lame_aguerrie") == "Aucun point d'arbre.", "sans point : refus")
	p.importer({"points_perk": 3})
	_verif(p.acheter_perk("croc_de_fer") != "" and not p.a_perk("croc_de_fer"), "parent manquant : refus (%s)" % p.refus_perk("croc_de_fer"))
	_verif(p.acheter_perk("lame_aguerrie") == "" and p.rang_perk("lame_aguerrie") == 1 and p.points_perk == 2, "racine : achat (1 point)")
	_verif(p.refus_perk("lame_aguerrie").contains("25"), "rang 2 : niveau 25 requis (%s)" % p.refus_perk("lame_aguerrie"))
	_verif(p.refus_perk("croc_de_fer").contains("30"), "parent possédé mais Une main 30 requise (%s)" % p.refus_perk("croc_de_fer"))
	_verif(p.acheter_perk("perk_inconnu") == "Perk inconnu.", "perk inconnu : refus")
	var q := _prog(100, 10)
	for i in 5:
		q.acheter_perk("lame_aguerrie")
	_verif(q.rang_perk("lame_aguerrie") == 5 and q.acheter_perk("lame_aguerrie") == "Rang maximal atteint." and q.points_perk == 5, "5 rangs puis rang maximal")
	_verif(q.acheter_perk("croc_de_fer") == "" and q.acheter_perk("curee") != "", "Croc de fer acheté ; Curée exige Crocs de Fenrir")
	_verif(q.acheter_perk("lame_de_fenrir") != "" and q.acheter_perk("crocs_de_fenrir") == "" and q.acheter_perk("curee") == "",
		"Lame de Fenrir refusée sans Soif du loup ni Curée ; Crocs de Fenrir puis Curée")
	_verif(q.acheter_perk("lame_de_fenrir") == "" and q.points_depenses() == 9 and q.points_perk == 1, "un seul parent suffit (Curée) : Lame de Fenrir ; 9 points dépensés")
	# Sigrún
	var bourse := Conteneur.new()
	bourse.pieces = 499
	_verif(q.reinitialiser_chez_sigrun(bourse) != "" and bourse.pieces == 499 and q.points_depenses() == 9, "Sigrún : 499 pièces -> refus, rien payé")
	bourse.pieces = 650
	_verif(q.reinitialiser_chez_sigrun(bourse) == "" and bourse.pieces == 150 and q.points_perk == 10 and q.perks.is_empty() and q.mult("une_main") == 1.0,
		"Sigrún : 500 pièces payées, 10 points rendus, perks oubliés")
	_verif(q.refus_reinitialisation(1000) == "Aucun perk à oublier." and Progression.PRIX_REINITIALISATION == 500, "rien à oublier : refus ; prix 500")

# ------------------------------------------------------------------ 5. effets

func _effets() -> void:
	var p := _prog(100, 200)
	p.activer()
	var arme := DonneesArme.new()
	arme.degats_leger = 20.0
	arme.famille = "epee_longue"
	var base := DegatsCombat.calculer(arme, false, 0.0, false, 1.0, 1.0)
	_verif(base == 20.0 and ReglagesCombat.competence("une_main") == 1.0, "sans perk : dégâts inchangés (20)")
	p.acheter_perk("lame_aguerrie")
	_verif(absf(DegatsCombat.calculer(arme, false, 0.0, false, 1.0, 1.0) - 22.0) < 0.001, "Lame aguerrie 1 : épée +10 % (22)")
	for i in 4:
		p.acheter_perk("lame_aguerrie")
	_verif(absf(ReglagesCombat.competence("une_main") - 1.5) < 0.001 and ReglagesCombat.competence("deux_mains") == 1.0, "Lame aguerrie 5 : une main ×1,5, deux mains inchangé")
	var marteau := DonneesArme.new()
	marteau.degats_leger = 20.0
	marteau.famille = "marteau"
	p.acheter_perk("bras_de_l_ours")
	_verif(absf(DegatsCombat.calculer(marteau, false, 0.0, false, 1.0, 1.0) - 22.0) < 0.001 and Progression.competence_arme(marteau) == "deux_mains",
		"marteau : compétence Deux mains, Bras de l'ours +10 %")
	p.acheter_perk("cuir_et_maille")
	_verif(absf(ReglagesCombat.competence("armure") - 1.1) < 0.001, "Cuir et maille 1 : armure ×1,1 (dégâts reçus ÷ 1,1)")
	# furtivité : CalculDegats
	var prof := ProfilCible.new()
	var info := {"quantite": 10.0, "attaque": "legere", "type": "contondant", "zone": "torse", "stagger": 0.0}
	var d0: float = CalculDegats.calculer(info, prof, {"surpris": true})["degats"]
	p.acheter_perk("lame_dans_l_ombre")
	var d1: float = CalculDegats.calculer(info, prof, {"surpris": true})["degats"]
	_verif(absf(d1 / d0 - 1.15) < 0.001, "Lame dans l'ombre 1 : attaque furtive ×1,15 (%.1f -> %.1f)" % [d0, d1])
	var p2 := _prog(15, 0)
	p2.activer()
	CalculDegats.calculer(info, prof, {"surpris": true})
	_verif(float(p2.competences.experience["furtivite"]) > 3.0, "attaque furtive : la Furtivité progresse")
	p.activer()
	# coûts de sorts
	_verif(Progression.facteur_cout_sort("feu") == 1.0 and Progression.facteur_cout_sort("soin") == 1.0, "sans perk : coût des sorts ×1")
	p.acheter_perk("paroles_de_puissance")
	p.acheter_perk("runes_econes")
	_verif(absf(Progression.facteur_cout_sort("feu") - 0.85) < 0.001 and Progression.facteur_cout_sort("soin") == 1.0, "Runes économes : destruction −15 %, soin inchangé")
	p.acheter_perk("runes_econes")
	p.acheter_perk("double_jet")
	_verif(absf(Progression.facteur_cout_sort("glace", true) - 0.45) < 0.001, "double incantation : −30 % −25 % (0,45)")
	p.acheter_perk("coeur_de_muspell")
	_verif(absf(Progression.mult_global("destruction_feu") - 1.25) < 0.001 and Progression.mult_global("destruction_glace") == 1.0, "Cœur de Muspell : feu +25 %")
	_verif(absf(ReglagesCombat.competence("destruction") - 1.1) < 0.001, "Paroles de puissance 1 : destruction ×1,1")
	p.acheter_perk("mains_d_eir")
	p.acheter_perk("souffle_econome")
	_verif(absf(Progression.facteur_cout_sort("soin") - 0.85) < 0.001 and absf(Progression.mult_global("restauration") - 1.15) < 0.001, "Mains d'Eir / Souffle économe : soin +15 %, coût −15 %")
	# parade, course
	var c := Competences.new()
	var red0 := c.reduction_parade()
	var course0 := c.cout_course()
	p.acheter_perk("rempart_de_tilleul")
	p.acheter_perk("pied_leger")
	_verif(absf(c.reduction_parade() - red0 / 1.1) < 0.001 and absf(c.cout_course() - course0 * 0.85) < 0.001,
		"Rempart de tilleul : garde ÷1,1 ; Pied léger : course −15 %")
	# régénérations, bonus additifs
	p.acheter_perk("souffle_long")
	p.acheter_perk("source_d_urd")
	_verif(absf(p.facteur("regen_vigueur") - 1.2) < 0.001 and absf(p.facteur("regen_magie") - 1.25) < 0.001 and p.facteur("regen_vie") == 1.0,
		"régénérations : vigueur ×1,2, mana ×1,25, vie ×1")
	# récupération furtive
	p.acheter_perk("pensee_de_huginn")
	p.acheter_perk("memoire_de_muninn")
	Progression.attaque_furtive(30.0)
	_verif(p.prendre_recup_furtive() == 15.0 and p.prendre_recup_furtive() == 0.0, "Mémoire de Muninn : 15 de récupération, prise une fois")
	# équilibrage : ReglagesCombat inchangé
	_verif(ReglagesCombat.COMPETENCES.values().all(func(v) -> bool: return v == 1.0) and ReglagesCombat.FURTIF == 2.5, "ReglagesCombat : chiffres inchangés (1,0 ; FURTIF 2,5)")

# ------------------------------------------------------------------ 6. sauvegarde

func _sauvegarde() -> void:
	var p := _prog(100, 6)
	p.acheter_perk("lame_aguerrie")
	p.acheter_perk("lame_aguerrie")
	p.acheter_perk("pied_leger")
	var d := p.exporter()
	_verif(d["perks"] == {"lame_aguerrie": 2, "pied_leger": 1} and int(d["points_perk"]) == 3 and d["competences"]["niveaux"].size() == 8, "export : perks par id et rang, 8 compétences")
	var q := Progression.new()
	q.importer(d)
	_verif(q.rang_perk("lame_aguerrie") == 2 and q.points_perk == 3 and absf(q.mult("une_main") - 1.2) < 0.001, "import : perks et effets relus")
	d["perks"]["perk_disparu"] = 2
	d["perks"]["pied_leger"] = 9
	q.importer(d)
	_verif(not q.a_perk("perk_disparu") and q.rang_perk("pied_leger") == 2 and q.points_perk == 3 + 2 + 7, "perk inconnu / rang en trop : points rendus")
	var v1 := {"version": 1, "competences": {"niveaux": {"epee": 30, "parade": 20, "athletisme": 25}, "experience": {"epee": 2.0}}}
	var m := Migration.migrer(v1)
	var r := Progression.new()
	r.importer(m["progression"])
	_verif(r.competence("une_main") == 30 and r.competence("athletisme") == 25 and r.competence("restauration") == 15 and r.perks.is_empty()
		and r.exporter()["competences"]["niveaux"].size() == 8, "migration v1 -> v2 lue par la progression du lot B (8 compétences, aucun perk)")

# ------------------------------------------------------------------ joueur réel

func _joueur() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 10:
		await process_frame
	var j = s.joueur
	var p: Progression = j.progression
	_verif(Progression.courante() == p, "joueur : progression courante")
	p.importer({"points_perk": 30, "competences": {"niveaux": {"armure": 100, "athletisme": 100, "une_main": 100, "parade": 100, "furtivite": 100}}})
	_verif(p.acheter_perk("cuir_et_maille") == "" and p.acheter_perk("corps_de_colosse") == "" and j.vie_max == 120.0, "Corps de colosse : vie max 120 (recalculer_stats)")
	var cap := float(j.inventaire.capacite())
	_verif(p.acheter_perk("pied_leger") == "" and p.acheter_perk("dos_du_boeuf") == "" and absf(float(j.inventaire.capacite()) - cap - 25.0) < 0.01, "Dos du bœuf : +25 de charge")
	# cible factice (groupe ennemis)
	var sc := GDScript.new()
	sc.source_code = CIBLE
	sc.reload()
	var cible = Node3D.new()
	cible.set_script(sc)
	cible.add_to_group("ennemis")
	s.add_child(cible)
	cible.global_position = j.global_position + Vector3(0, 0, -1.5)
	# saignement + vol de vie
	var arme := DonneesArme.new()
	arme.famille = "epee_longue"
	var xp0: float = float(p.competences.experience["epee"])
	p.acheter_perk("lame_aguerrie")
	p.acheter_perk("croc_de_fer")
	p.acheter_perk("croc_de_fer")
	p.acheter_perk("soif_du_loup")
	j.vie = 50.0
	Progression.coup_porte(j, cible, arme, 20.0, "touche", false)
	_verif(absf(j.vie - 50.8) < 0.01, "Soif du loup : 4 %% de 20 = 0,8 vie rendue (%.2f)" % j.vie)
	_verif(float(p.competences.experience["epee"]) != xp0 or p.competence("une_main") == 100, "coup porté : pratique de la compétence de l'arme")
	var sg := cible.get_node_or_null("Saignement") as Saignement
	_verif(sg != null and absf(sg.reste - 6.0) < 0.01, "Croc de fer 2 : saignement de 30 % de 20 = 6")
	for i in 240:
		await process_frame
	_verif(absf(cible.vie - 94.0) < 0.05 and not is_instance_valid(sg), "saignement infligé en 3 s puis retiré (vie %.2f)" % cible.vie)
	# riposte et vigueur sur parade parfaite
	p.acheter_perk("rempart_de_tilleul")
	p.acheter_perk("riposte_de_heimdall")
	p.acheter_perk("souffle_du_guetteur")
	j.vigueur = 50.0
	Progression.garde_tenue(j, {"issue": "parade", "degats": 0.0, "cout": 0.0}, 20.0, cible.global_position)
	_verif(absf(cible.vie - 84.0) < 0.05 and absf(j.vigueur - 60.0) < 0.01, "parade parfaite : riposte 50 %% (10) et +10 vigueur (vie cible %.1f)" % cible.vie)
	Progression.garde_tenue(j, {"issue": "bloque", "degats": 5.0, "cout": 3.0}, 20.0, cible.global_position)
	_verif(absf(cible.vie - 84.0) < 0.05, "simple blocage : pas de riposte")
	# récupération furtive consommée par le joueur
	p.acheter_perk("lame_dans_l_ombre")
	p.acheter_perk("memoire_de_muninn")
	j.mana = 10.0
	Progression.attaque_furtive(20.0)
	await physics_frame
	await physics_frame
	_verif(j.mana >= 25.0, "Mémoire de Muninn : +15 mana rendus par le joueur (%.1f)" % j.mana)
	_verif(ReglagesCombat.competence("une_main") > 1.0 and j.competences.multiplicateur_degats() == 1.0 + ReglagesCombat.GAIN_COMPETENCE_EPEE,
		"joueur : perks dans ReglagesCombat, bonus de niveau d'arme inchangé (une main 100)")
	s.queue_free()
	await process_frame
