extends SceneTree
## Test sans fenêtre de la magie et des deux mains (scènes/test_magie.tscn, docs/MAGIE.md) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_magie.gd -- --nouvelle
## Compatibilité des deux mains (règles data/magie/regles_mains.json), mana (coût, régénération après délai), les 12 sorts +
## soin + protection, double incantation (fenêtre de synchronisation), réactions entre écoles, interruption par un coup,
## épée + magie (sort mémorisé pendant un coup, canalisation coupée, bonus après sort), enchantement de la lame et combos,
## statuts sur un draugr (gel, choc, brûlure), contrat HUD et EffetsMagie, sauvegarde (aller-retour JSON).

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var _signaux_mains := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		mains.avancer(DT)
		await physics_frame

func _reset(pos := Vector3(0, 0, 1.2)) -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	magie.enchantement = {}
	j.mana = j.mana_max
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains.defense = DefenseJoueur.new()
	for m in [s.mannequin, s.mannequin2, s.mannequin3]:
		m.total = 0.0
		m.coups.clear()
		var st := Statuts.de(m, false)
		if st != null:
			st.actifs.clear()
			st.recharge_reaction = 0.0
		var mc: CombatEnnemi = m.combat
		mc.posture = mc.profil.posture_max
		mc.etourdi = 0.0
	Elements.journal.clear()
	s.placer_joueur(pos, 0.0)
	await physics_frame
	await physics_frame

func _total() -> float:
	return s.total_degats()

func _journal_a(texte: String) -> bool:
	for l in magie.journal:
		if String(l[1]).begins_with(texte):
			return true
	return false

func _reaction(nom: String) -> bool:
	for e in Elements.journal:
		if e["nom"] == nom:
			return true
	return false

func _tenir(main: String, t: float) -> void:
	magie.appuyer(main)
	await _sim(t)
	magie.relacher(main)

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	j.etat_mains_change.connect(func(_g: Dictionary, _d: Dictionary) -> void: _signaux_mains += 1)
	for i in 20:
		await physics_frame
	await _compatibilite()
	await _mana()
	await _sorts()
	await _soin_protection()
	await _double()
	await _reactions()
	await _interruption()
	await _epee_magie()
	await _enchantement()
	await _statuts_draugr()
	_contrats()
	_sauvegarde()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ compatibilité des deux mains

func _compatibilite() -> void:
	var eq := magie.eq
	_verif(eq.equiper("gauche", "epee") != "", "main gauche : épée refusée (« %s »)" % eq.refus("gauche", eq.objet("epee")))
	_verif(eq.equiper("droite", "bouclier") != "", "main droite : bouclier refusé")
	eq.equiper("droite", "jet_flammes")
	_verif(eq.equiper("gauche", "enchant_feu") != "", "enchantement refusé sans épée dans l'autre main")
	_verif(mains.equipement.main_droite == EquipementMains.MAIN_SORT and mains.arme == EquipementMains.MAIN_SORT, "main droite qui incante : l'épée reçoit main_sort (pas de modèle)")
	mains.equipement.choisir_selon_inventaire(j.inventaire)
	_verif(eq.categorie("droite") == "sort", "l'inventaire ne remet pas l'épée par-dessus un sort")
	var deux := Equipement.EPEE_METAL.duplicate() as DonneesArme
	deux.deux_mains = true
	deux.id = "epee_deux_mains_test"
	eq.equiper("gauche", "torche")
	eq.equiper("droite", deux)
	_verif(eq.categorie("droite") == "arme_deux_mains" and eq.categorie("gauche") == "vide", "arme à deux mains : la main gauche est libérée")
	_verif(eq.clic_droit_garde(), "arme à deux mains : clic droit = garde")
	eq.equiper("gauche", "torche")
	_verif(eq.categorie("droite") == "vide" and eq.categorie("gauche") == "torche", "torche à gauche : l'arme à deux mains est rangée")
	var cas := [["vide", "epee", true], ["torche", "epee", true], ["bouclier", "jet_flammes", true], ["jet_flammes", "epee", false], ["jet_flammes", "boule_feu", false], ["bouclier", "epee", true]]
	for c in cas:
		eq.equiper("droite", c[1])
		eq.equiper("gauche", c[0])
		_verif(eq.clic_droit_garde() == c[2], "clic droit avec %s / %s = %s" % [c[0], c[1], "garde" if c[2] else "main gauche"])
	eq.equiper("droite", "epee")
	eq.equiper("gauche", "bouclier")
	_verif(magie.arme_de_garde(mains.arme).id == "bouclier", "garde avec bouclier : c'est le bouclier qui pare")
	eq.equiper("gauche", "jet_flammes")
	_verif(eq.equiper("gauche", "soin") == "" and eq.sort("gauche").id == "soin", "changement de sort dans une main")
	_verif(_signaux_mains > 5, "signal etat_mains_change émis à chaque changement (%d)" % _signaux_mains)

# ------------------------------------------------------------------ mana

func _mana() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "jet_flammes")
	await _reset()
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(1.16)
	var depense: float = m0 - j.mana
	_verif(magie.inc["gauche"].etat == Incantation.CANALISE, "jet de flammes : canalisation tant que le bouton est tenu")
	_verif(absf(depense - 13.0) < 2.5, "jet de flammes : ~13 mana/s (%.1f en 1 s)" % depense)
	_verif(_total() > 10.0, "jet de flammes : le mannequin brûle (%.1f dégâts)" % _total())
	magie.relacher("gauche")
	await _sim(0.6)
	var m1: float = j.mana
	await _sim(0.4)
	_verif(absf(j.mana - m1) < 0.01, "mana : pas de régénération pendant le délai (%.1f → %.1f)" % [m1, j.mana])
	await _sim(1.5)
	_verif(j.mana > m1 + 5.0, "mana : régénération après le délai (%.1f → %.1f)" % [m1, j.mana])
	j.mana = 2.0
	magie.appuyer("gauche")
	await _sim(0.1)
	_verif(magie.inc["gauche"].etat == Incantation.REPOS and magie.refus["gauche"].contains("mana"), "sans mana : refus expliqué (« %s »)" % magie.refus["gauche"])
	magie.relacher("gauche")

# ------------------------------------------------------------------ les 12 sorts

func _sorts() -> void:
	var ids := ["jet_flammes", "boule_feu", "explosion_incendiaire", "eclat_glace", "lance_givre", "nova_gelee", "arc_electrique",
		"chaine_eclairs", "tempete_statique", "trait_ombre", "drain_vie", "explosion_obscure"]
	for id in ids:
		magie.equiper("gauche", "vide")
		magie.equiper("droite", id)
		await _reset()
		var sd := magie.eq.sort("droite")
		var t := 0.9 if sd.canalise() else (1.1 if sd.se_charge() else 0.05)
		j.vie = 50.0
		await _tenir("droite", t)
		await _sim(1.2)
		_verif(_total() > 5.0 and j.mana < j.mana_max - 5.0, "%s : %.1f dégâts, %.1f mana" % [id, _total(), j.mana_max - j.mana])
		if sd.statut != "":
			var porte := false
			for m in [s.mannequin, s.mannequin2, s.mannequin3]:
				if Statuts.a(m, sd.statut) or (sd.statut == "choc"):
					porte = true
			_verif(porte, "%s : statut « %s » posé" % [id, sd.statut])
		if id == "drain_vie":
			_verif(j.vie > 52.0, "drain de vie : le joueur se soigne (%.1f)" % j.vie)
		if id == "chaine_eclairs":
			var touches := {}
			for e in magie.lanceur.journal:
				if e["sort"] == id:
					touches[e["cible"]] = true
			_verif(touches.size() >= 2, "chaîne d'éclairs : saute de cible en cible (%d cibles)" % touches.size())
		if sd.recharge > 0.5:
			_verif(magie.recharges.has(id) or sd.recharge < 1.3, "%s : recharge en cours" % id)
	await _sim(4.0)   # fin de la tempête

# ------------------------------------------------------------------ soin et protection

func _soin_protection() -> void:
	magie.equiper("gauche", "soin")
	magie.equiper("droite", "protection")
	await _reset()
	j.vie = 40.0
	magie.appuyer("gauche")
	await _sim(1.2)
	_verif(j.vie > 52.0, "soin : %.1f PV après 1 s" % j.vie)
	magie.appuyer("droite")
	await _sim(0.3)
	var v0: float = j.vie
	var m0: float = j.mana
	j.recevoir_coup(20.0, j.global_position + Vector3(0, 0, -1.5))
	_verif(v0 - j.vie < 9.5 and m0 - j.mana > 3.0, "protection de face : %.1f PV perdus sur 20, %.1f mana" % [v0 - j.vie, m0 - j.mana])
	_verif(magie.inc["droite"].etat == Incantation.CANALISE, "protection : un coup ne la coupe pas")
	v0 = j.vie
	j.recevoir_coup(20.0, j.global_position + Vector3(0, 0, 1.5))
	_verif(v0 - j.vie > 15.0, "protection : un coup dans le dos passe (%.1f)" % (v0 - j.vie))
	_verif(j.statuts_actifs.any(func(e): return e["nom"] == "protection"), "statuts_actifs du joueur : protection")
	magie.relacher("gauche")
	magie.relacher("droite")
	await _sim(0.4)

# ------------------------------------------------------------------ double incantation

func _double() -> void:
	# référence : un seul jet 1 s
	magie.equiper("droite", "jet_flammes")
	magie.equiper("gauche", "jet_flammes")
	await _reset()
	await _tenir("gauche", 1.16)
	var simple := _total()
	await _sim(0.5)
	await _reset()
	var m0: float = j.mana
	var d0 := int(EffetsMagie.appels.get("double", 0))
	magie.appuyer("gauche")
	await _sim(0.05)
	magie.appuyer("droite")
	await _sim(1.11)
	_verif(magie.inc["gauche"].double and magie.inc["droite"].double, "feu + feu dans la fenêtre (0,05 s) : double incantation")
	var cout: float = m0 - j.mana
	_verif(cout > 24.0 and cout < 34.0, "double feu : mana ×2,2 (%.1f en 1 s)" % cout)
	_verif(_total() > simple * 1.6, "double feu : dégâts accrus (%.1f contre %.1f)" % [_total(), simple])
	_verif(int(EffetsMagie.appels.get("double", 0)) > d0, "EffetsMagie.double appelé")
	magie.relacher("droite")
	await _sim(0.1)
	_verif(not magie.inc["gauche"].active(), "double : relâcher une main termine le sort")
	await _sim(0.5)
	await _reset()
	magie.appuyer("gauche")
	await _sim(0.3)
	magie.appuyer("droite")
	await _sim(0.3)
	_verif(not magie.inc["gauche"].double and magie.inc["droite"].active(), "appuis à 0,3 s d'écart : deux jets séparés, pas de double")
	magie.relacher("gauche")
	magie.relacher("droite")
	await _sim(0.5)
	# les 3 autres écoles
	for id in ["eclat_glace", "chaine_eclairs", "drain_vie", "lance_givre"]:
		magie.equiper("droite", id)
		magie.equiper("gauche", id)
		await _reset()
		var p0 := int(EffetsMagie.appels.get("projectile_visuel", 0))
		var sd := magie.eq.sort("droite")
		m0 = j.mana
		j.vie = 50.0
		magie.appuyer("gauche")
		magie.appuyer("droite")
		await _sim(0.9 if sd.canalise() else (1.0 if sd.se_charge() else 0.05))
		var dbl: bool = magie.inc["gauche"].double or _journal_a("double " + id)
		magie.relacher("gauche")
		magie.relacher("droite")
		await _sim(0.8)
		var detail := ""
		match id:
			"eclat_glace":
				detail = "%d éclats" % (int(EffetsMagie.appels.get("projectile_visuel", 0)) - p0)
				_verif(int(EffetsMagie.appels.get("projectile_visuel", 0)) - p0 == 6, "double glace : 6 éclats au lieu de 3")
			"lance_givre":
				detail = "%d lances" % (int(EffetsMagie.appels.get("projectile_visuel", 0)) - p0)
				_verif(int(EffetsMagie.appels.get("projectile_visuel", 0)) - p0 == 3, "double lance : lance massive + 2 cristaux")
			"chaine_eclairs":
				var touches := {}
				for e in magie.lanceur.journal:
					if e["sort"] == id:
						touches[e["cible"]] = true
				detail = "%d cibles" % touches.size()
				_verif(touches.size() == 3, "double électricité : propagation à toutes les cibles (3)")
			"drain_vie":
				detail = "vie %.1f" % j.vie
				_verif(j.vie > 56.0, "double ténèbres : drain renforcé (%.1f)" % j.vie)
		_verif(dbl and m0 - j.mana > LanceurSorts.cout(sd, 0.0) * 1.5, "double %s (%s, %.1f mana)" % [id, detail, m0 - j.mana])

# ------------------------------------------------------------------ réactions

func _reactions() -> void:
	var paires := [["eclat_glace", "boule_feu", "vapeur"], ["eclat_glace", "chaine_eclairs", "decharge"], ["trait_ombre", "boule_feu", "flammes_obscures"],
		["trait_ombre", "eclat_glace", "cristaux_corrompus"], ["boule_feu", "chaine_eclairs", "decharge_incendiaire"], ["trait_ombre", "chaine_eclairs", "arcs_violets"]]
	for p in paires:
		magie.equiper("gauche", p[0])
		magie.equiper("droite", p[1])
		await _reset()
		await _tenir("gauche", 0.05)
		await _sim(0.5)
		var m0: float = j.mana
		await _tenir("droite", 0.05)
		await _sim(0.5)
		_verif(_reaction(p[2]), "%s puis %s : réaction « %s » (mana %.1f)" % [p[0], p[1], p[2], m0 - j.mana])
	# recharge de la réaction sur la cible et réaction sans mana
	magie.equiper("gauche", "eclat_glace")
	magie.equiper("droite", "boule_feu")
	await _reset()
	await _tenir("gauche", 0.05)
	await _sim(0.4)
	j.mana = 16.0   # juste la boule de feu non chargée (14,4), pas les 6 de la vapeur
	await _tenir("droite", 0.05)
	await _sim(0.5)
	_verif(not _reaction("vapeur"), "réaction impayable (mana) : coup normal, pas de vapeur")

# ------------------------------------------------------------------ interruption

func _interruption() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "boule_feu")
	await _reset()
	var n0 := magie.lanceur.journal.size()
	magie.appuyer("gauche")
	await _sim(0.5)
	_verif(magie.inc["gauche"].etat == Incantation.CHARGE and j.charge_gauche > 0.2, "boule de feu : charge (%.2f)" % j.charge_gauche)
	j.recevoir_coup(14.0, j.global_position + Vector3(0.5, 0, -1.2))
	await _sim(0.05)
	_verif(magie.inc["gauche"].interrompue and magie.refus["gauche"].contains("interrompue"), "coup ennemi de 14 : incantation interrompue")
	magie.relacher("gauche")
	await _sim(0.6)
	_verif(magie.lanceur.journal.size() == n0, "interrompue : rien n'est lancé")
	magie.appuyer("gauche")
	await _sim(0.3)
	j.recevoir_coup(4.0, j.global_position + Vector3(0.5, 0, -1.2))
	await _sim(0.05)
	_verif(magie.inc["gauche"].etat == Incantation.CHARGE, "coup faible (4) : la charge continue (seuil %.0f)" % magie.eq.sort("gauche").seuil_interruption)
	magie.relacher("gauche")
	await _sim(0.6)

# ------------------------------------------------------------------ épée + magie

func _epee_magie() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "eclat_glace")
	await _reset(Vector3(0, 0, 0))
	mains.entrees.appuyer()
	await _sim(0.05)
	mains.entrees.relacher()
	await _sim(0.03)
	_verif(mains.combat.attaque(), "épée : coup léger en cours")
	magie.appuyer("gauche")
	magie.relacher("gauche")
	await _sim(0.02)
	_verif(magie.inc["gauche"].libre() and magie.inc["gauche"].tampon >= 0.0, "sort pendant un coup d'épée : mémorisé, pas lancé")
	await _sim(0.6)
	_verif(_journal_a("lance gauche eclat_glace"), "le sort mémorisé part après le coup d'épée")
	# épée juste après un sort : bonus d'ouverture
	_verif(magie.bonus_apres_sort(s.mannequin) > 1.0, "épée après sort sur la même cible : bonus ×%.2f" % magie.bonus_apres_sort(s.mannequin))
	# une attaque d'épée coupe la canalisation
	magie.equiper("gauche", "jet_flammes")
	await _reset(Vector3(0, 0, 0))
	magie.appuyer("gauche")
	await _sim(0.4)
	_verif(magie.inc["gauche"].etat == Incantation.CANALISE, "jet canalisé de la main gauche, épée au repos")
	mains.entrees.appuyer()
	await _sim(0.05)
	mains.entrees.relacher()
	await _sim(0.05)
	_verif(not magie.inc["gauche"].active(), "coup d'épée : la canalisation de la main gauche s'arrête")
	magie.relacher("gauche")
	await _sim(0.6)
	# garde : clic droit = main gauche avec un sort, garde avec main vide
	_verif(not magie.eq.clic_droit_garde(), "épée + sort : le clic droit lance le sort (pas de garde)")

# ------------------------------------------------------------------ enchantement + combos

func _enchantement() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "enchant_feu")
	await _reset(Vector3(0, 0, 0))
	var m0: float = j.mana
	await _tenir("gauche", 0.05)
	await _sim(0.9)
	_verif(not magie.enchantement_actif().is_empty() and absf(m0 - j.mana - 35.0) < 1.0, "lame ardente : enchantement actif, 35 mana")
	_verif(j.statuts_actifs.any(func(e): return e["nom"] == "enchant_feu"), "statuts_actifs : enchantement et durée")
	mains.attaquer()
	await _sim(0.7)
	var dernier: Dictionary = s.mannequin.coups[-1]["info"] if not s.mannequin.coups.is_empty() else {}
	_verif(String(dernier.get("enchant", "")) == "feu" and Statuts.a(s.mannequin, "brulure"), "coup d'épée enchanté : feu ajouté, cible en flammes")
	# combo : cible gelée + épée = brise-glace (gel consommé)
	magie.enchantement = {}
	await _reset(Vector3(0, 0, 0))
	Statuts.de(s.mannequin).appliquer("gel", 3.0, 0.4)
	mains.attaquer()
	await _sim(0.7)
	dernier = s.mannequin.coups[-1]["info"] if not s.mannequin.coups.is_empty() else {}
	_verif(String(dernier.get("combo", "")) == "brise_glace" and not Statuts.a(s.mannequin, "gel"), "épée sur cible gelée : combo « brise-glace », gel consommé")
	await _reset(Vector3(0, 0, 0))
	Statuts.de(s.mannequin).appliquer("corruption", 3.0, 0.15)
	j.vie = 50.0
	mains.attaquer()
	await _sim(0.7)
	_verif(j.vie > 50.5, "épée sur cible corrompue : combo « moisson » (vie %.1f)" % j.vie)
	# l'enchantement se termine
	magie.enchantement = {"sort": magie.eq.sort_par_id("enchant_glace"), "reste": 0.1}
	await _sim(0.2)
	_verif(magie.enchantement.is_empty(), "enchantement temporaire : fin après sa durée")

# ------------------------------------------------------------------ statuts sur un draugr

func _statuts_draugr() -> void:
	var d: CharacterBody3D = s.creer_draugr(Vector3(3.0, 0, -2.0), true)
	for i in 10:
		await physics_frame
	var st := Statuts.de(d)
	st.appliquer("gel", 3.0, 0.5)
	_verif(absf(Statuts.facteur_vitesse(d) - 0.5) < 0.01, "draugr gelé : vitesse ×0,5")
	st.appliquer("choc", 0.5, 0.5)
	_verif(d.etat == d.TITUBE, "draugr choqué : il titube (interrompu)")
	_verif(not st.appliquer("choc", 0.5, 0.5), "choc : immunité juste après (pas d'étourdissement en boucle)")
	var v0: float = d.vie
	st.appliquer("brulure", 2.0, 6.0)
	await _sim(1.05)
	_verif(d.vie < v0 - 4.0, "draugr en flammes : %.1f PV perdus en 1 s" % (v0 - d.vie))
	d.queue_free()

# ------------------------------------------------------------------ contrats

func _contrats() -> void:
	var manquants := []
	for f in ["aura_main", "jet", "projectile_visuel", "impact", "zone", "chaine", "statut_cible", "enchant_arme", "reaction", "double"]:
		if int(EffetsMagie.appels.get(f, 0)) == 0:
			manquants.append(f)
	_verif(manquants.is_empty(), "EffetsMagie : les 10 fonctions du contrat sont appelées %s" % str(manquants))
	for p in ["mana", "mana_max", "charge_gauche", "charge_droite", "recharges", "statuts_actifs"]:
		_verif(j.get(p) != null, "HUD : joueur.%s" % p)
	_verif(j.has_signal("etat_mains_change"), "HUD : signal etat_mains_change")

func _sauvegarde() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "drain_vie")
	j.mana = 42.0
	var texte := JSON.stringify(magie.exporter())
	magie.equiper("gauche", "torche")
	j.mana = 100.0
	magie.importer(JSON.parse_string(texte))
	_verif(magie.eq.mains["gauche"]["id"] == "drain_vie" and magie.eq.mains["droite"]["id"] == "epee" and absf(j.mana - 42.0) < 0.01,
		"sauvegarde : mains (%s / %s) et mana restaurés" % [magie.eq.mains["gauche"]["id"], magie.eq.mains["droite"]["id"]])
	_verif(magie.eq.sorts_connus.size() == 18, "sauvegarde : 18 sorts connus")
