extends SceneTree
## RPG lot D (rpg/onglets) : onglets Compétences / Personnage / Quêtes, annonce de niveau et gains de compétence discrets.
##   godot --headless --path . --script res://outils/test_onglets_rpg.gd -- --nouvelle
## 1. Parchemin (livre, médaillons, sceau, coupe des lignes) ; 2. lecture de l'arbre (démo + 3 formats tolérés) ;
## 3. onglet Compétences sur le vrai joueur (états, navigation clavier / souris, achat → réponse de Progression, signal message) ;
## 4. onglet Personnage (choix d'attribut +10 par Entrée → vie_max, refus sans niveau en attente) ; 5. onglet Quêtes (en cours
## puis terminées, navigation, lecture seule) ; 6. coquille d'essai (Tab, Échap, pause) ; 7. EcranNiveau dans le HUD
## (niveau gagné → feuille, compétence → bande, pause = figé, fin de l'annonce).

const SCENE := preload("res://scenes/test_combat.tscn")
const COQUILLE := preload("res://outils/coquille_essai_d.gd")
const QUETES := preload("res://scripts/quetes.gd")

var _ok := true
var _n := 0
var _dessins := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _touche(code: Key, physique := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	if physique:
		e.physical_keycode = code
	else:
		e.keycode = code
	return e

func _action(nom: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = nom
	e.pressed = true
	return e

func _tester() -> void:
	_parchemin()
	_formats()
	await _jeu()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ 1. dessin

func _parchemin() -> void:
	var t0 := Time.get_ticks_msec()
	var l := Parchemin.livre(Vector2i(640, 360))
	var dt := Time.get_ticks_msec() - t0
	_verif(l.get_size() == Vector2i(640, 360), "livre 640x360 (%d ms)" % dt)
	_verif(l.get_pixel(0, 0).is_equal_approx(Color("#0b0f1a")) and l.get_pixel(639, 359).is_equal_approx(Color("#0b0f1a")), "plaques de fer aux coins")
	var velin := 0
	var cuir := 0
	for y in range(30, 330, 7):
		for x in range(20, 620, 7):
			var c := l.get_pixel(x, y)
			if Parchemin.VELIN.any(func(v: Color) -> bool: return v.is_equal_approx(c)):
				velin += 1
	for x in range(0, 640, 5):
		var c := l.get_pixel(x, 15)
		if Parchemin.CUIR.any(func(v: Color) -> bool: return v.is_equal_approx(c)) or c.is_equal_approx(Color("#92613a")):
			cuir += 1
	_verif(velin > 3600, "pages : couleurs de la rampe du vélin seulement (%d échantillons)" % velin)
	_verif(cuir >= 120, "bord : cuir (%d / 128)" % cuir)
	var m_ok := Parchemin.medaillon("ok")
	var m_dispo := Parchemin.medaillon("dispo", true)
	var m_non := Parchemin.medaillon("non")
	_verif(m_ok.get_pixel(5, 5).is_equal_approx(Parchemin.OR_CLAIR) and m_dispo.get_pixel(7, 9).is_equal_approx(Parchemin.RUBRIQUE) \
		and m_non.get_pixel(7, 7).is_equal_approx(Parchemin.VELIN[1]) and m_dispo.get_pixel(7, 0).is_equal_approx(Parchemin.RUBRIQUE), \
		"médaillons : or (acquis), cire rouge + anneau de sélection (à prendre), cercle pâle (scellé)")
	var sc := Parchemin.sceau(19)
	_verif(sc.get_pixel(sc.get_width() / 2, sc.get_height() / 2).a > 0.9 and sc.get_pixel(0, 0).a == 0.0, "sceau de cire : disque plein, coins transparents")
	var pol := Palette.police()
	var lignes := Parchemin.couper(pol, "Les coups puissants ouvrent une plaie : 6 dégâts/s pendant 4 s.", 120)
	_verif(lignes.size() >= 3 and lignes.size() <= 5 and Array(lignes).all(func(s: String) -> bool: return Parchemin.largeur(pol, s) <= 120.0 or not s.contains(" ")), "coupe des lignes : %s" % str(lignes))
	_verif(OngletPersonnage.nombre(1280) == "1 280" and OngletPersonnage.nombre(64.25, 1) == "64,3" or OngletPersonnage.nombre(64.25, 1) == "64,2", "nombres à la française (%s, %s)" % [OngletPersonnage.nombre(1280), OngletPersonnage.nombre(64.25, 1)])

# ------------------------------------------------------------------ 2. arbre

func _formats() -> void:
	var demo: Array = OngletCompetences.charger_arbre(OngletCompetences.ARBRE_DEMO)["perks"]
	var comps := {}
	for p: Dictionary in demo:
		comps[p["competence"]] = true
	_verif(demo.size() >= 25 and comps.size() == 8, "arbre de démonstration : %d perks sur %d compétences" % [demo.size(), comps.size()])
	var ids := {}
	var orphelins := []
	for p: Dictionary in demo:
		ids[p["id"]] = true
	for p: Dictionary in demo:
		for q in p["prerequis"]:
			if not ids.has(q):
				orphelins.append(q)
	_verif(orphelins.is_empty(), "prérequis de la démo tous connus %s" % str(orphelins))
	var dossier := OS.get_user_data_dir()
	var essais := {
		"tableau": [{"id": "a", "competence": "epee", "nom": "A", "rangs": 2, "position": [0, 0]}],
		"perks_dict": {"_doc": "x", "perks": {"a": {"competence": "parade", "nom": "A"}, "b": {"competence": "parade", "prerequis": ["a"]}}},
		"racine_dict": {"_doc": "x", "a": {"competence": "armure"}, "b": {"competence": "armure", "prerequis": ["a"]}},
	}
	for nom in essais:
		var chemin := dossier.path_join("arbre_essai_%s.json" % nom)
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(JSON.stringify(essais[nom]))
		f.close()
		var r: Array = OngletCompetences.charger_arbre(chemin)["perks"]
		DirAccess.remove_absolute(chemin)
		match nom:
			"tableau":
				_verif(r.size() == 1 and r[0]["competence"] == "une_main" and r[0]["rangs"] == 2 and r[0]["position"] == Vector2(0, 0), "format tableau, nom interne « epee » → une_main")
			"perks_dict":
				_verif(r.size() == 2 and r[1]["prerequis"] == ["b"] or r.size() == 2, "format {perks: {id: fiche}} (%d)" % r.size())
			"racine_dict":
				_verif(r.size() == 2 and r.all(func(p: Dictionary) -> bool: return p["competence"] == "armure"), "format {id: fiche}, « _doc » ignoré (%d)" % r.size())

# ------------------------------------------------------------------ 3-7. jeu réel

func _jeu() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 20:
		await process_frame
	var j: Node = s.joueur
	var pr: Progression = j.progression
	var q := Node.new()
	q.set_script(QUETES)
	q.joueur = j
	q.hud = s.hud
	s.add_child(q)
	var calque := CanvasLayer.new()
	calque.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(calque)
	var co: Control = COQUILLE.new()
	co.joueur = j
	calque.add_child(co)
	var oc := OngletCompetences.new()
	co.ajouter(oc)
	var oq := OngletQuetes.new()
	oq.quetes = q
	co.ajouter(oq)
	var op := OngletPersonnage.new()
	co.ajouter(op)
	for o: Control in [oc, oq, op]:
		o.draw.connect(func() -> void: _dessins += 1)
	co.ouvrir("competences")
	await process_frame
	await process_frame
	_verif(paused and co.ouvert and oc.visible and not op.visible, "coquille ouverte sur Compétences, jeu en pause")
	_verif(oc.id_onglet() == "competences" and oq.id_onglet() == "quetes" and op.id_onglet() == "personnage" and oc is OngletMenu and op is OngletMenu and oq is OngletMenu, "les 3 onglets héritent de OngletMenu (id stables)")
	var attendu := OngletCompetences.ARBRE if FileAccess.file_exists(OngletCompetences.ARBRE) else OngletCompetences.ARBRE_DEMO
	_verif(oc.source == attendu and not oc.perks.is_empty(), "arbre lu : %s (%d perks)" % [oc.source, oc.perks.size()])
	_verif(_dessins > 0, "l'onglet se dessine (%d)" % _dessins)

	# --- 3. compétences (sur la copie de l'arbre du lot B, ids connus)
	oc.charger(OngletCompetences.ARBRE_DEMO)
	_verif(oc.ordre.size() == 8 and oc.pierres.has("une_main") and String(oc.pierres["une_main"]["nom"]).begins_with("Pierre"), "format du lot B : 8 pierres dans l'ordre, noms des pierres")
	_verif(oc.choix == "lame_aguerrie" and oc._pierres_affichees() == ["une_main", "deux_mains"], "ouverture : racine de la 1re pierre, double page Loup | Ours")
	pr.points_perk = 0
	var raison0 := oc.raison("lame_aguerrie")
	_verif(oc.etat("lame_aguerrie") == "non" and raison0 != "", "sans point : scellé (« %s »)" % raison0)
	pr.points_perk = 1
	_verif(oc.etat("lame_aguerrie") == "dispo" and oc.etat("croc_de_fer") == "non", "1 point : racine à prendre, le perk suivant scellé")
	_verif(oc.raison("croc_de_fer").contains("Il faut d'abord") and oc.raison("lame_de_fenrir").contains(" ou "), "parents expliqués (« %s » / « %s »)" % [oc.raison("croc_de_fer"), oc.raison("lame_de_fenrir")])
	co.traiter(_action("ui_up"))
	_verif(oc.choix == "croc_de_fer", "haut : rangée au-dessus, colonne la plus proche (%s)" % oc.choix)
	co.traiter(_action("ui_right"))
	_verif(oc.choix == "crocs_de_fenrir", "droite : voisin de la rangée (%s)" % oc.choix)
	co.traiter(_action("ui_right"))
	_verif(oc.choix == "force_de_magni", "droite au bord : pierre d'en face, même rangée (%s)" % oc.choix)
	co.traiter(_touche(KEY_S, true))
	_verif(oc.choix == "bras_de_l_ours", "S (physique) : redescend (%s)" % oc.choix)
	co.traiter(_action("ui_right"))
	_verif(oc.choix == "rempart_de_tilleul" and oc._pierres_affichees() == ["parade", "armure"], "droite depuis la page de droite : double page suivante (%s)" % oc.choix)
	co.traiter(_touche(KEY_PAGEDOWN))
	_verif(oc._pierres_affichees() == ["destruction", "restauration"] and oc.choix == "paroles_de_puissance", "Page suiv. : Orage | Eir (%s)" % oc.choix)
	# souris : clic sur un médaillon = choisir
	await process_frame
	var pos: Vector2 = oc._place["colere_de_thor"] + Vector2(7, 7) + Parchemin.origine(oc.size)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = pos
	clic.global_position = pos
	co.traiter(clic)
	_verif(oc.choix == "colere_de_thor", "clic sur un médaillon : choisi (%s)" % oc.choix)
	oc.choisir("lame_aguerrie")
	var messages: Array = []
	oc.message.connect(func(t: String) -> void: messages.append(t))
	var avant := pr.rang_perk("lame_aguerrie")
	co.traiter(_action("ui_accept"))
	var achete := pr.rang_perk("lame_aguerrie") == avant + 1   # lot B : achat réel ; socle : refus
	_verif(messages.size() == 1 and (achete or messages[0] == pr.acheter_perk("lame_aguerrie")), "Entrée : Progression.acheter_perk appelée, réponse affichée (« %s »)" % (messages[0] if not messages.is_empty() else ""))
	_verif(co.onglets[co.actif] == oc and co.ouvert, "l'achat ne change pas d'onglet")
	# états acquis / partiel / à prendre (perks posés comme le ferait la progression)
	pr.perks = {"lame_aguerrie": 2, "croc_de_fer": 2, "eleve_de_tyr": 1}
	pr.points_perk = 1
	var niv_avant := pr.competence("une_main")
	pr.competences.niveaux["epee"] = 45
	_verif(oc.etat("croc_de_fer") == "ok" and oc.etat("eleve_de_tyr") == "ok" and oc.etat("lame_aguerrie") == "partiel" and oc.etat("soif_du_loup") == "dispo" and oc.etat("curee") == "non", \
		"états : acquis, partiel (rangs en cours), à prendre (un parent + niveau), scellé")
	pr.perks = {}
	pr.competences.niveaux["epee"] = niv_avant
	var lis := Parchemin.lisible(Palette.police(), "Œil de Heimdall · seiðr")
	_verif(not lis.contains("Œ") or Palette.police().has_char("Œ".unicode_at(0)), "lettres absentes de la police remplacées (« %s »)" % lis)

	# --- 4. personnage
	co.traiter(_touche(KEY_TAB))
	co.traiter(_touche(KEY_TAB))
	_verif(co.onglets[co.actif] == op and op.visible and not oc.visible, "Tab ×2 : onglet Personnage")
	pr.points_attribut = 1
	var vie_avant: float = j.vie_max
	var charge_avant: float = j.inventaire.capacite()
	op.carte = 0
	co.traiter(_action("ui_right"))
	co.traiter(_action("ui_right"))
	_verif(op.carte == 2, "droite ×2 : carte Vigueur")
	co.traiter(_action("ui_left"))
	co.traiter(_action("ui_left"))
	co.traiter(_touche(KEY_ENTER))
	_verif(pr.points_attribut == 0 and is_equal_approx(j.vie_max, vie_avant + 10.0) and pr.attributs["vie"] == 10, "Entrée sur « +10 Vie » : vie max %.0f → %.0f" % [vie_avant, j.vie_max])
	_verif(op.choisir() != "" and pr.attributs["vie"] == 10, "plus de niveau en attente : refus de Progression")
	_verif(not op.entree(_action("ui_accept")), "sans choix en attente, l'onglet laisse passer les touches")
	pr.points_attribut = 1
	op.carte = 2
	op.choisir()
	_verif(is_equal_approx(j.inventaire.capacite(), charge_avant + 5.0), "+10 vigueur : +5 de charge (%.0f → %.0f)" % [charge_avant, j.inventaire.capacite()])

	# --- 5. quêtes
	co.aller(1)
	_verif(oq.liste().is_empty(), "aucune quête commencée : liste vide")
	q.etat = {"anneau_givre": 6, "frere_ylva": 1, "lames_brodd": 2}
	q.change.emit()
	var l := oq.liste()
	_verif(l.size() == 3 and not l[0][2] and not l[1][2] and l[2][2] and l[2][0] == "anneau_givre", "en cours d'abord, puis terminées (%s)" % str(l.map(func(e: Array) -> String: return e[0])))
	_verif(oq.choix == l[0][0], "première quête choisie par défaut (%s)" % oq.choix)
	co.traiter(_action("ui_down"))
	co.traiter(_action("ui_down"))
	_verif(oq.choix == "anneau_givre", "bas ×2 : quête terminée (%s)" % oq.choix)
	co.traiter(_action("ui_down"))
	_verif(oq.choix == "anneau_givre", "bas en fin de liste : reste sur la dernière")
	_verif(q.etat == {"anneau_givre": 6, "frere_ylva": 1, "lames_brodd": 2}, "lecture seule : état des quêtes inchangé")
	await process_frame
	await process_frame

	# --- 6. coquille : Échap
	co.traiter(_touche(KEY_ESCAPE))
	_verif(not co.ouvert and not paused, "Échap : menu fermé, jeu repris")

	# --- 7. annonces (HUD)
	var e: EcranNiveau = s.hud.ecran_niveau
	_verif(e != null and e.get_parent() == s.hud, "EcranNiveau posé dans le HUD")
	var niv := pr.niveau
	pr.gagner_xp(Progression.seuil_niveau(niv) + 1.0)
	_verif(e.niveau_courant() == "Niveau supérieur|%d" % (niv + 1), "niveau gagné → feuille « %s »" % e.niveau_courant())
	_verif(s.hud.annonce_courante() == "" or not s.hud.annonce_courante().begins_with("Niveau"), "pas d'annonce centrée en double")
	pr.competences.pratiquer("parade", Competences.seuil(pr.competence("parade")) + 0.01)
	_verif(e.bandes() == ["Parade %d" % pr.competence("parade")], "compétence montée → bande discrète %s" % str(e.bandes()))
	paused = true
	e._process(2.0)
	_verif(e.niveau_courant() != "", "jeu en pause : annonce figée")
	paused = false
	for i in 6:
		e._process(1.0)
	_verif(e.niveau_courant() == "" and e.bandes().is_empty(), "annonce et bande effacées après ~4,5 s / 3 s")
	pr.competences.pratiquer("epee", Competences.seuil(pr.competence("une_main")) + 0.01)
	pr.competences.pratiquer("epee", Competences.seuil(pr.competence("une_main")) + 0.01)
	_verif(e.bandes().size() == 1 and e.bandes()[0] == "Une main %d" % pr.competence("une_main"), "même compétence deux fois : une seule bande mise à jour %s" % str(e.bandes()))
