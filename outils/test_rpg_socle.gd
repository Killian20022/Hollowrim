extends SceneTree
## Socle RPG (lot 0, docs/RPG.md) : registre unique des objets (data/objets/), catégories, emplacements, Conteneur / Stockage,
## EquipementCorps, Progression (niveau, points, attributs, alias de compétences, mult_global), ReglagesCombat.competence,
## règle « nouvelle entrée de butin en FIN de table », OngletMenu ; puis le joueur réel (scenes/test_combat.tscn) :
## recalculer_stats, bénédiction, multiplicateurs à 1,0.
##   godot --headless --path . --script res://outils/test_rpg_socle.gd -- --nouvelle

const SCENE := preload("res://scenes/test_combat.tscn")
const EMPREINTE := "res://outils/donnees_test/butin_empreinte.json"
## Identifiants du registre AVANT le lot 0 (ancienne constante Inventaire.OBJETS + data/butin/objets.json) : aucun ne doit
## disparaître ni changer de nom / poids / valeur. Lot A RPG : armes allégées (Q5 a) — épées / hache du registre et lame antique
## ont un poids neuf (ancien 9 / 7 / 9 / 9 / 7 / 10 / 9, lame 8) ; identifiants et valeurs inchangés.
const ANCIENS := {
	"os_draugr": [0.5, 2], "poussiere_tombe": [0.1, 6], "lame_antique": [4.0, 25], "amulette_givre": [0.3, 40], "anneau_givre": [0.1, 0],
	"amulette_eirik": [0.2, 0], "epee_skarnholt": [6.0, 120], "ecaille_dragon": [2.0, 80], "fragment_sceau_os": [0.6, 0],
	"fragment_sceau_givre": [0.6, 0], "fragment_sceau_eau": [0.6, 0], "cle_archives": [0.2, 0], "minerai_fer": [3.0, 12],
	"minerai_argent": [2.5, 45], "cristal_givre": [0.8, 70], "champignon_lumineux": [0.1, 8], "relique_offrande": [1.5, 90],
	"registre_hrafn": [0.8, 0], "journal_sigrun": [0.3, 0], "broche_sigrun": [0.1, 0], "hache_kolbeinn": [5.0, 200],
	"fourrure_troll": [4.0, 60], "croc_troll": [0.3, 18],
	"potion_soin": [0.5, 30], "potion_soin_forte": [0.5, 75], "potion_mana": [0.5, 35], "potion_endurance": [0.5, 25],
	"pain_seigle": [0.2, 3], "viande_sechee": [0.3, 5], "tome_boule_feu": [1.0, 120], "tome_lance_givre": [1.0, 120],
	"tome_souffle_givre": [1.0, 200], "tome_drain_vie": [1.0, 150], "tome_chaine_eclairs": [1.0, 220], "tome_nova_gelee": [1.0, 160],
	"tome_tempete_statique": [1.0, 260], "tome_explosion_incendiaire": [1.0, 240], "tome_explosion_obscure": [1.0, 240],
	"tome_enchant_electricite": [1.0, 140], "tome_enchant_glace": [1.0, 140], "tome_enchant_tenebres": [1.0, 140],
	"epee_or": [5.0, 180], "epee_rubis": [6.0, 220], "epee_verre": [4.5, 260], "epee_obsidienne": [7.0, 300], "epee_hrafn": [6.0, 280],
	"anneau_cuivre": [0.1, 15], "coupe_argent": [1.0, 35], "collier_or": [0.3, 85],
}

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
	_registre()
	_butin_en_fin()
	_conteneurs()
	_equipement_corps()
	_progression()
	await _joueur()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ registre

func _registre() -> void:
	var manquants := []
	for id in ANCIENS:
		var f := Inventaire.objet(id)
		if f.is_empty() or absf(float(f.get("poids", -1)) - float(ANCIENS[id][0])) > 0.0001 or int(f.get("valeur", -1)) != int(ANCIENS[id][1]):
			manquants.append(id)
	_verif(manquants.is_empty(), "les %d anciens objets gardent identifiant, poids et valeur %s" % [ANCIENS.size(), str(manquants)])
	var mauvaises := []
	var quete_implicite := []
	var empl := []
	var doublons := []
	for id: String in Inventaire.OBJETS:
		var f := Inventaire.objet(id)
		if not String(f.get("categorie", "")) in Inventaire.CATEGORIES or not f.has("nom") or not f.has("rarete"):
			mauvaises.append(id)
		if int(f.get("valeur", 0)) <= 0 and Inventaire.categorie_de(id) != "consommable" and not Inventaire.est_quete(id):
			quete_implicite.append(id)
		if Inventaire.categorie_de(id) in ["armure", "bijou"] and not Inventaire.emplacement_de(id) in Inventaire.EMPLACEMENTS:
			empl.append(id)
		if CatalogueArmes.connu(id):
			doublons.append(id)
	_verif(mauvaises.is_empty(), "chaque fiche a nom, rareté et une catégorie explicite valide %s" % str(mauvaises))
	_verif(quete_implicite.is_empty(), "objets de valeur 0 : drapeau quete explicite %s" % str(quete_implicite))
	_verif(empl.is_empty(), "armures et bijoux : emplacement valide %s" % str(empl))
	_verif(doublons.is_empty(), "aucune fiche en double avec le catalogue d'armes %s" % str(doublons))
	_verif(Inventaire.categorie_de("epee_skarnholt") == "arme" and Inventaire.categorie_de("hache_kolbeinn") == "arme", "Skarnholt et Kolbeinn classées « arme » (plus « divers »)")
	_verif(Inventaire.categorie_de("champignon_lumineux") == "ingredient" and Inventaire.categorie_de("minerai_fer") == "ingredient" and Inventaire.categorie_de("croc_troll") == "ingredient", "ingrédients classés « ingredient »")
	_verif(Inventaire.est_quete("cle_archives") and Inventaire.categorie_de("cle_archives") == "quete" and not Inventaire.est_quete("potion_soin"), "objets de quête : catégorie quete + drapeau")
	_verif(Inventaire.emplacement_de("amulette_givre") == "cou" and Inventaire.categorie_de("amulette_givre") == "bijou", "amulette de givre : bijou (cou)")
	_verif(Inventaire.categorie_de("claymore") == "arme" and Inventaire.connu("dague_acier") and Inventaire.ids_connus().has("claymore"), "armes du catalogue toujours lues (CatalogueArmes)")
	_verif(Inventaire.OBJETS.size() >= ANCIENS.size(), "registre : %d fiches dans data/objets/" % Inventaire.OBJETS.size())
	_verif(Inventaire.alias("os_draugr") == "os_draugr", "alias : identifiant inchangé sans renommage")
	var err := ButinTables.verifier()
	_verif(err.is_empty(), "tables de butin : tous les objets connus %s" % str(err))
	var em := Marchand.verifier()
	_verif(em.is_empty(), "marchands : tous les objets connus %s" % str(em))

## Règle anti-conflit : toute nouvelle entrée de butin EN FIN de table (graine fixe).
func _butin_en_fin() -> void:
	var emp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EMPREINTE)).get("tables", {})
	var t := ButinTables.tables()
	var fautes := []
	for nom: String in emp:
		if not t.has(nom):
			fautes.append(nom + " (disparue)")
			continue
		var ent: Array = t[nom].get("entrees", [])
		var attendu: Array = emp[nom]
		for i in attendu.size():
			var e: Dictionary = ent[i] if i < ent.size() else {}
			var cle := String(e.get("id", "")) if e.has("id") else "table:" + String(e.get("table", ""))
			if cle != String(attendu[i]):
				fautes.append("%s[%d] %s au lieu de %s" % [nom, i, cle, attendu[i]])
				break
	_verif(fautes.is_empty(), "butin : les %d tables commencent par leurs entrées d'origine (ajouts en fin seulement) %s" % [emp.size(), str(fautes)])

# ------------------------------------------------------------------ conteneurs, stockage

func _conteneurs() -> void:
	Stockage.reinitialiser()
	var sac := Inventaire.new()
	_verif(sac is Conteneur and sac.capacite() == Inventaire.CAPACITE, "le sac est un Conteneur, capacité %d" % sac.capacite())
	sac.ajouter("os_draugr", 3)
	sac.ajouter("cle_archives")
	sac.ajouter("pieces", 40)
	var g := Stockage.conteneur("coffre_grima")
	_verif(g != null and is_inf(g.capacite()) and Stockage.accessible("coffre_grima") and not Stockage.accessible("coffre_maison") and Stockage.conteneur("inconnu") == null,
		"coffre de Grima accessible dès le début, maison non achetée, id inconnu refusé")
	_verif(Stockage.transferer(sac, g, "os_draugr", 2) == "" and sac.nombre("os_draugr") == 1 and g.nombre("os_draugr") == 2, "déposer 2 os dans le coffre")
	_verif(Stockage.transferer(sac, g, "cle_archives") != "" and sac.a("cle_archives"), "objet de quête : dépôt refusé")
	_verif(Stockage.transferer(sac, g, "pieces", 15) == "" and sac.pieces == 25 and g.pieces == 15, "pièces déposées")
	_verif(Stockage.transferer(g, sac, "os_draugr", 5) != "" and Stockage.transferer(g, sac, "os_draugr", 2) == "" and sac.nombre("os_draugr") == 3, "reprendre (pas plus que le contenu)")
	var e := Stockage.exporter()
	Stockage.reinitialiser()
	_verif(Stockage.conteneur("coffre_grima").vide(), "nouvelle partie : coffres vides")
	Stockage.importer(e)
	_verif(Stockage.conteneur("coffre_grima").pieces == 15 and not Stockage.maison_achetee, "coffres relus (export / import)")
	var c := Conteneur.new()
	c.importer({"pieces": 3, "objets": {"objet_disparu": 2, "os_draugr": 1}})
	_verif(c.pieces == 3 and c.nombre("os_draugr") == 1 and not c.objets.has("objet_disparu"), "importer : objet inconnu ignoré sans plantage")
	Stockage.reinitialiser()

# ------------------------------------------------------------------ équipement de corps

func _equipement_corps() -> void:
	var sac := Inventaire.new()
	var ec := EquipementCorps.new(sac)
	var signaux := []
	ec.change.connect(func(e: String) -> void: signaux.append(e))
	_verif(ec.equiper("amulette_givre") != "", "pas dans le sac : refus")
	sac.ajouter("amulette_givre")
	sac.ajouter("potion_soin")
	_verif(ec.equiper("amulette_givre") == "" and ec.objet_a("cou") == "amulette_givre" and ec.est_equipe("amulette_givre") and signaux == ["cou"], "amulette portée au cou (signal change)")
	_verif(ec.equiper("potion_soin") != "" and ec.equiper("epee_or") != "", "potion et arme : ne se portent pas sur le corps")
	_verif(sac.poids() > 0.29, "l'objet porté reste dans le sac et compte dans le poids")
	_verif(ec.armure_totale() == 0.0 and ec.effets_totaux() == {"resist_froid": 0.25}, "amulette de givre (lot A) : armure 0, résistance au froid 25 %")
	var e := ec.exporter()
	sac.retirer("amulette_givre")
	_verif(ec.objet_a("cou") == "", "objet retiré du sac (vendu, lâché) : retiré de l'emplacement")
	sac.ajouter("amulette_givre")
	ec.importer(e)
	_verif(ec.objet_a("cou") == "amulette_givre", "export / import des emplacements")
	ec.importer({"cou": "potion_soin", "tete": "inconnu"})
	_verif(ec.objet_a("cou") == "" and ec.objet_a("tete") == "", "import : objet au mauvais emplacement ou inconnu ignoré")

# ------------------------------------------------------------------ progression

func _progression() -> void:
	_verif(Progression.courante() == null or Progression.mult_global("une_main") == 1.0, "sans joueur : mult_global = 1,0")
	var p := Progression.new()
	_verif(p.niveau == 1 and p.points_perk == 0 and p.competence("une_main") == 15 and p.competence("epee") == 15 and p.competence("destruction") == 15, "départ : niveau 1, compétences à 15 (epee = une_main)")
	_verif(Progression.seuil_niveau(1) == 150.0 and Progression.seuil_niveau(10) == 600.0 and Progression.xp_competence_jusqua(17) == 33.0, "seuils : 100 + 50 n ; 15 -> 17 = 16 + 17 XP")
	var niveaux := []
	var comp := []
	p.niveau_perso.connect(func(n: int) -> void: niveaux.append(n))
	p.niveau_competence.connect(func(nom: String, n: int) -> void: comp.append([nom, n]))
	p.pratiquer("une_main", Competences.seuil(15) + 0.01)
	_verif(p.competence("une_main") == 16 and comp == [["une_main", 16]] and absf(p.xp_niveau - 16.0) < 0.001, "pratiquer une_main : niveau 16, signal (nom canonique), +16 XP de niveau")
	p.pratiquer("destruction", 50.0)
	_verif(p.competence("destruction") == 15, "compétence pas encore gérée (lot B) : ignorée sans erreur")
	p.gagner_xp(150.0 + 200.0)
	_verif(p.niveau == 3 and niveaux == [2, 3] and p.points_perk == 2 and p.points_attribut == 2, "XP -> niveau 3 : 2 points d'arbre, 2 choix d'attribut")
	_verif(p.choisir_attribut("magie") == "" and p.attributs["magie"] == 10 and p.points_attribut == 1 and p.choisir_attribut("force") != "", "choix d'attribut +10 magie ; attribut inconnu refusé")
	p.choisir_attribut("vigueur")
	_verif(p.choisir_attribut("vie") != "" and p.bonus_charge() == 5.0 and p.bonus_magie() == 10.0, "plus de choix en attente ; vigueur -> +5 de charge")
	_verif(p.acheter_perk("lame_aguerrie") != "" and not p.a_perk("lame_aguerrie") and p.mult("une_main") == 1.0, "arbre vide au lot 0 : achat refusé, mult 1,0")
	var d := p.exporter()
	_verif(d["competences"]["niveaux"].has("une_main") and not d["competences"]["niveaux"].has("epee"), "export : noms canoniques")
	var q := Progression.new()
	d["competences"]["niveaux"]["furtivite"] = 33   # compétence que Competences ne connaît pas encore : gardée
	q.importer(d)
	var d2 := q.exporter()
	_verif(q.niveau == 3 and q.competence("une_main") == 16 and q.competence("furtivite") == 33 and int(d2["competences"]["niveaux"]["furtivite"]) == 33 and q.attributs["magie"] == 10,
		"import / export : niveau, compétences (inconnues gardées), attributs")
	q.activer()
	_verif(Progression.courante() == q and ReglagesCombat.competence("une_main") == 1.0 and ReglagesCombat.competence("armure") == 1.0 and ReglagesCombat.competence_arme("marteau") == 1.0,
		"progression courante : ReglagesCombat.competence() passe par mult_global, toujours 1,0")
	var b := OngletMenu.new()
	_verif(b.aide().is_empty() and not b.entree(InputEventKey.new()), "OngletMenu : base vide instanciable")
	b.free()

# ------------------------------------------------------------------ joueur réel

func _joueur() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 10:
		await process_frame
	var j = s.joueur
	_verif(j.competences == j.progression.competences and Progression.courante() == j.progression, "joueur : competences = alias de progression.competences, progression courante")
	_verif(j.vie_max == 100.0 and j.mana_max == 100.0 and j.vigueur_max == 100.0 and j.inventaire.capacite() == 150.0, "joueur neuf : maxima 100, charge 150 (lot A)")
	j.regler_benediction(true, true)
	_verif(j.vie_max == 110.0, "bénédiction : vie max 110")
	j.progression.gagner_xp(150.0)
	j.progression.choisir_attribut("vie")
	_verif(j.vie_max == 120.0 and j.progression.niveau == 2, "niveau 2 + 10 vie : vie max 120 (recalculer_stats)")
	j.inventaire.ajouter("amulette_givre")
	_verif(j.equipement_corps.equiper("amulette_givre") == "" and j.vie_max == 120.0, "amulette portée : vie max inchangée (elle résiste au froid)")
	_verif(ReglagesCombat.competence("une_main") == 1.0 and j.competences.multiplicateur_degats() == 1.0, "combat : multiplicateurs inchangés")
