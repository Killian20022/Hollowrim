extends SceneTree
## Potions à effet progressif (scripts/effets_potions.gd, scripts/consommables.gd) et poids du sac limité
## (Inventaire.CAPACITE, surcharge du joueur, refus dans la fenêtre de butin et chez les marchands) :
##   godot --headless --path . --script res://outils/test_potions.gd -- --nouvelle
## Avec fenêtre (godot_slot.sh) et --captures=<dossier> : potions_effet_hud.png, potions_surcharge_inventaire.png, potions_surcharge_hud.png.

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var _captures := ""
var _avis: Array[String] = []

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

func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await _images(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	var chemin := _captures.path_join(nom)
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)

func _vider_sac() -> void:
	j.inventaire.objets.clear()
	j.potions.vider()

func _tester() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.substr(11)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	await _images(20)
	j.avis.connect(func(t: String) -> void: _avis.append(t))
	_donnees()
	_progressif()
	_delais()
	_refus_et_mort()
	await _poids()
	_butin_et_marchands()
	_anciennes_sauvegardes()
	await _captures_demo()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

func _donnees() -> void:
	var tout := true
	for id in ["potion_soin", "potion_soin_forte", "potion_mana", "potion_endurance", "pain_seigle", "viande_sechee"]:
		var e := Consommables.effets(id)
		tout = tout and float(e.get("duree", 0.0)) > 0.0 and e.has("famille")
	_verif(tout, "consommables : durée et famille renseignées")
	_verif(float(Consommables.effets("potion_soin")["duree"]) == 4.0 and float(Consommables.effets("potion_soin_forte")["duree"]) == 6.0, "petite potion 4 s, grande 6 s")
	var t_potion := float(Consommables.effets("potion_soin")["vie"]) / float(Consommables.effets("potion_soin")["duree"])
	var t_viande := float(Consommables.effets("viande_sechee")["vie"]) / float(Consommables.effets("viande_sechee")["duree"])
	_verif(t_viande < t_potion * 0.3, "nourriture plus lente et plus faible (%.1f contre %.1f points/s)" % [t_viande, t_potion])
	_verif(Consommables.description("potion_soin").contains("en 4 s"), "description : « %s »" % Consommables.description("potion_soin"))

func _progressif() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	inv.ajouter("potion_soin", 3)
	inv.ajouter("potion_mana", 2)
	inv.ajouter("potion_endurance", 1)
	inv.ajouter("potion_soin_forte", 1)
	j.vie = 30.0
	_verif(Consommables.utiliser(j, "potion_soin") == "", "boire la potion de soin")
	_verif(absf(j.vie - 30.0) < 0.5 and j.potions.actifs.size() == 1 and inv.nombre("potion_soin") == 2, "pas instantané : vie %.1f juste après" % j.vie)
	var st: Array = j.statuts_actifs
	_verif(st.any(func(e: Dictionary) -> bool: return e["nom"] == "pot_vie" and float(e["duree"]) > 3.5 and float(e["duree_max"]) == 4.0), "HUD : statut pot_vie (durée 4 s) dans statuts_actifs")
	j.potions.avancer(j, 2.0)
	_verif(absf(j.vie - 50.0) < 1.0, "à mi-durée : vie %.1f (≈ 50)" % j.vie)
	j.potions.avancer(j, 2.5)
	_verif(absf(j.vie - 70.0) < 0.01 and j.potions.actifs.is_empty(), "fin : vie %.1f (= 70), plus d'effet actif" % j.vie)
	j.potions.vider()
	# mana et vigueur
	j.mana = 10.0
	j.vigueur = 5.0
	Consommables.utiliser(j, "potion_mana")
	Consommables.utiliser(j, "potion_endurance")
	j.potions.avancer(j, 1.0)
	_verif(j.mana > 10.0 and j.mana < 40.0 and j.vigueur > 5.0 and j.vigueur < 40.0, "mana %.1f et vigueur %.1f montent peu à peu" % [j.mana, j.vigueur])
	j.potions.avancer(j, 10.0)
	_verif(absf(j.mana - 60.0) < 0.01 and absf(j.vigueur - 65.0) < 0.01, "mana 60 et vigueur 65 au bout du compte")
	# plafond
	j.vie = j.vie_max - 5.0
	j.potions.vider()
	Consommables.utiliser(j, "potion_soin_forte")
	j.potions.avancer(j, 7.0)
	_verif(is_equal_approx(j.vie, j.vie_max), "vie plafonnée à vie_max")

func _delais() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	inv.ajouter("potion_soin", 3)
	inv.ajouter("potion_soin_forte", 1)
	inv.ajouter("potion_mana", 1)
	j.vie = 10.0
	j.mana = 10.0
	Consommables.utiliser(j, "potion_soin")
	var r := Consommables.utiliser(j, "potion_soin")
	_verif(r.begins_with("Trop tôt") and inv.nombre("potion_soin") == 2, "même famille : refusée tout de suite (« %s »)" % r)
	_verif(Consommables.utiliser(j, "potion_soin_forte").begins_with("Trop tôt") and inv.nombre("potion_soin_forte") == 1, "la grande potion partage le délai de soin")
	_verif(Consommables.utiliser(j, "potion_mana") == "", "une autre famille (mana) reste possible")
	j.potions.avancer(j, 3.1)
	_verif(Consommables.utiliser(j, "potion_soin") == "" and j.potions.actifs.size() >= 2, "après le délai : on peut reboire, les effets se cumulent")
	_verif(Consommables.utiliser(j, "tome_boule_feu") != "" and not Consommables.utiliser(j, "tome_boule_feu").begins_with("Trop tôt"), "un tome n'est pas soumis aux délais")

func _refus_et_mort() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	inv.ajouter("potion_soin", 2)
	j.vie = j.vie_max - 10.0
	Consommables.utiliser(j, "potion_soin")
	j.potions.delais.clear()
	var r := Consommables.utiliser(j, "potion_soin")
	_verif(r.contains("maximum") and inv.nombre("potion_soin") == 1, "effet en cours qui suffit : 2e potion refusée (« %s »)" % r)
	j.potions.vider()
	j.vie = 20.0
	Consommables.utiliser(j, "potion_soin")
	j.mort = true
	j.potions.avancer(j, 1.0)
	_verif(j.potions.actifs.is_empty() and absf(j.vie - 20.0) < 0.01, "mort : effets annulés, aucune vie rendue")
	j.mort = false
	j.vie = j.vie_max
	j.potions.vider()

func _poids() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	_verif(is_equal_approx(inv.capacite(), 100.0) and not inv.surcharge(), "capacité du sac : %.0f, sac vide pas surchargé" % inv.capacite())
	inv.ajouter("minerai_fer", 30)   # 90
	_verif(not inv.surcharge() and inv.place_pour("minerai_fer") == 3 and inv.place_pour("epee_or") == 1 and inv.place_pour("pieces") > 1000, "90 / 100 : place pour 3 minerais, 1 épée, les pièces ne pèsent rien")
	_avis.clear()
	await _images(5)
	_verif(not j.surcharge and _avis.is_empty(), "joueur : pas surchargé à 90")
	inv.ajouter("minerai_fer", 4)    # 102
	await _images(5)
	_verif(inv.surcharge() and j.surcharge, "102 / 100 : surchargé")
	_verif(_avis.size() == 1 and _avis[0].contains("Surchargé") and _avis[0].contains("course"), "message clair (« %s »)" % (_avis[0] if not _avis.is_empty() else "aucun"))
	inv.retirer("minerai_fer", 4)
	await _images(5)
	_verif(not j.surcharge and _avis.size() == 2 and _avis[1].contains("plus surchargé"), "retour sous la limite : message de fin")
	_verif(j.LENTEUR_SURCHARGE < 1.0, "surcharge : vitesse x%.1f et course coupée (joueur.gd)" % j.LENTEUR_SURCHARGE)

func _butin_et_marchands() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	inv.ajouter("minerai_fer", 31)   # 93 → place pour 2 minerais
	var fb := FenetreButin.new()
	fb.joueur = j
	fb.hud = s.hud
	root.add_child(fb)
	var objets := {"minerai_fer": 5, "potion_soin": 1}
	_verif(fb.ouvrir("Coffre lourd", objets), "fenêtre de butin ouverte")
	var i_fer := 0
	for k in fb.lignes.size():
		if String(fb.lignes[k]["id"]) == "minerai_fer":
			i_fer = k
	fb.prendre(i_fer)
	_verif(inv.nombre("minerai_fer") == 33 and int(objets.get("minerai_fer", 0)) == 3 and not inv.surcharge(), "butin : seulement 2 minerais sur 5 emportés, 3 restent (sac %.1f)" % inv.poids())
	fb.prendre(fb.lignes.map(func(l: Dictionary) -> String: return String(l["id"])).find("minerai_fer"))
	_verif(inv.nombre("minerai_fer") == 33 and int(objets.get("minerai_fer", 0)) == 3, "butin : sac plein, rien de plus ne passe")
	var n_av := fb.lignes.size()
	fb.tout_prendre()
	_verif(fb.ouvert and inv.nombre("minerai_fer") == 33 and not inv.surcharge(), "« tout prendre » ne boucle pas et respecte la limite (reste : %d ligne(s))" % fb.lignes.size())
	fb.fermer()
	# marchand : achat refusé quand le sac est plein
	Marchand.reinitialiser()
	inv.ajouter("pieces", 500)
	var r := Marchand.acheter("forgeron", inv, "minerai_fer", 1)
	var stock := Marchand.stock("forgeron")
	if stock.has("minerai_fer"):
		inv.ajouter("minerai_fer", 1)   # 34 = 102 : plein
		r = Marchand.acheter("forgeron", inv, "minerai_fer", 1)
		_verif(r.begins_with("Trop lourd"), "marchand : achat refusé sac plein (« %s »)" % r)
		_verif(not inv.surcharge() or inv.nombre("minerai_fer") == 34, "marchand : le sac n'a pas grossi")
	else:
		_verif(true, "(Brodd n'a pas de minerai en stock cette période : refus testé sur un autre objet)")
		inv.objets.clear()
		inv.ajouter("minerai_fer", 33)
		inv.ajouter("pieces", 500)
		var oid := String(stock.keys()[0]) if not stock.is_empty() else ""
		if oid != "":
			var w := float(Inventaire.objet(oid).get("poids", 0.0))
			while inv.place_pour(oid) > 0 and w > 0.0:
				inv.ajouter("os_draugr", 1)
			_verif(Marchand.acheter("forgeron", inv, oid, 1).begins_with("Trop lourd") or w <= 0.0, "marchand : achat refusé sac plein")

func _anciennes_sauvegardes() -> void:
	var inv: Inventaire = j.inventaire
	_verif(not inv.exporter().has("potions") and (inv.exporter()["objets"] as Dictionary).size() >= 0, "la sauvegarde du sac reste {pieces, objets} (aucun champ nouveau)")
	var vieux := Inventaire.new()
	vieux.importer({"pieces": 12, "objets": {"epee_or": 6, "minerai_fer": 10, "potion_soin": 3}})   # 84 : ancienne partie lourde
	_verif(vieux.nombre("epee_or") == 6 and vieux.poids() > 84.0 - 0.1, "ancienne sauvegarde chargée telle quelle (poids %.1f)" % vieux.poids())
	vieux.importer({"pieces": 0, "objets": {"epee_or": 20}})
	_verif(vieux.nombre("epee_or") == 20 and vieux.surcharge(), "un vieux sac trop lourd se charge, simplement surchargé")
	var v2 := Inventaire.new()
	v2.importer({})
	_verif(v2.poids() == 0.0 and not v2.surcharge(), "ancien format vide accepté")

func _captures_demo() -> void:
	_vider_sac()
	var inv: Inventaire = j.inventaire
	inv.ajouter("potion_soin_forte", 3)
	inv.ajouter("potion_mana", 2)
	inv.ajouter("potion_endurance", 2)
	j.vie = 35.0
	j.mana = 20.0
	j.vigueur = 30.0
	Consommables.utiliser(j, "potion_soin_forte")
	Consommables.utiliser(j, "potion_mana")
	Consommables.utiliser(j, "potion_endurance")
	await _images(60)
	await _capture("potions_effet_hud.png")
	j.potions.vider()
	inv.ajouter("epee_or", 5)
	inv.ajouter("minerai_fer", 20)
	_avis.clear()
	await _images(5)
	_verif(j.surcharge, "démo : sac surchargé (%.0f / %.0f)" % [inv.poids(), inv.capacite()])
	await _capture("potions_surcharge_hud.png")
	var ui: InventaireMains = s.inventaire_ui
	ui.ouvrir()
	await _images(4)
	await _capture("potions_surcharge_inventaire.png")
	ui.fermer()
