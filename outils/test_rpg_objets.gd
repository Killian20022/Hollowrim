extends SceneTree
## RPG lot A (objets et armures, docs/RPG.md §2-§4, §12) : gamme d'armures 4 emplacements × matériaux (progression d'armure
## et de poids), bijoux à effets lisibles (clés §3), enchantements seulement sur les objets trouvés, icônes 16 px ;
## EquipementCorps (armure totale, effets, pièces, retirer) ; formule d'armure de joueur.recevoir_coup (physique : × 120 /
## (120 + armure × compétence Armure), élémentaire : résistance) ; sac 150 + vigueur, armes allégées (8 armes + armure
## lourde tiennent) ; hache de Kolbeinn tenue (bonus dans ses propres dégâts, plus de bonus « dans le sac ») ; butin
## (tables en fin, région) ; stock de Brodd ; équilibrage (ReglagesCombat : coups de draugr encaissés).
##   godot --headless --path . --script res://outils/test_rpg_objets.gd -- --nouvelle

const SCENE := preload("res://scenes/test_combat.tscn")
const MATERIAUX := {   # matériau -> pièces (tete, torse, mains, pieds)
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"fourrure": ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"acier_nordique": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"os": ["casque_os", "cuirasse_os", "gants_os", "bottes_os"],
}
const CLES_EFFETS := ["vie_max", "magie_max", "vigueur_max", "charge", "regen_magie", "regen_vigueur", "resist_froid", "resist_feu",
	"resist_choc", "degats_une_main", "degats_deux_mains", "degats_destruction", "cout_sorts", "prix"]

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
	_donnees()
	_equipement_corps()
	_poids_et_sac()
	_kolbeinn()
	_butin()
	_marchand()
	await _joueur()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

static func _total(ids: Array) -> Vector2:
	var t := Vector2.ZERO
	for id in ids:
		t += Vector2(float(Inventaire.objet(id).get("armure", 0)), float(Inventaire.objet(id).get("poids", 0)))
	return t

# ------------------------------------------------------------------ données

func _donnees() -> void:
	var armures := Inventaire.ids_connus().filter(func(id: String) -> bool: return Inventaire.categorie_de(id) == "armure")
	var bijoux := Inventaire.ids_connus().filter(func(id: String) -> bool: return Inventaire.categorie_de(id) == "bijou")
	_verif(armures.size() >= 26 and bijoux.size() >= 10, "registre : %d armures, %d bijoux" % [armures.size(), bijoux.size()])
	var fautes := []
	for id: String in armures:
		var f := Inventaire.objet(id)
		if not String(f.get("emplacement", "")) in ["tete", "torse", "mains", "pieds"] or float(f.get("armure", 0)) <= 0.0 \
				or not String(f.get("type_armure", "")) in ["lourde", "legere"]:
			fautes.append(id)
	_verif(fautes.is_empty(), "armures : emplacement tete/torse/mains/pieds, points d'armure, type lourde/legere %s" % str(fautes))
	var empl := {}
	for id: String in bijoux:
		empl[Inventaire.emplacement_de(id)] = true
		if (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty():
			fautes.append(id)
	_verif(empl.has("cou") and empl.has("anneau") and fautes.is_empty(), "bijoux : cou et anneau, chacun avec un effet %s" % str(fautes))
	var cles_inconnues := []
	var enchant_communs := []
	var icones := []
	for id: String in armures + bijoux:
		var f := Inventaire.objet(id)
		var ef: Dictionary = f.get("effets", {})
		for k in ef:
			if not k in CLES_EFFETS:
				cles_inconnues.append("%s.%s" % [id, k])
		if not ef.is_empty() and String(f.get("rarete", "")) in ["commun", "peu_commun"] and id != "amulette_givre":
			enchant_communs.append(id)
		if not IconesCombat.connu(String(f.get("icone", ""))):
			icones.append(id)
	_verif(cles_inconnues.is_empty(), "effets : seulement des clés de docs/RPG.md §3 %s" % str(cles_inconnues))
	_verif(enchant_communs.is_empty(), "enchantements sur des pièces rares / uniques (amulette de givre : bijou commun trouvé, historique) %s" % str(enchant_communs))
	_verif(icones.is_empty(), "chaque armure / bijou a son icône 16 px (IconesCombat) %s" % str(icones))
	var img := IconesCombat.image(IconesCombat.MOTIFS["casque_fer"])
	_verif(img.get_width() == 16 and img.get_height() == 16 and img.get_pixel(8, 4).a > 0.5, "icône casque de fer : 16x16, pleine au centre")
	_verif(IconesCombat.ecole_de("casque_os") == "" and IconesCombat.ecole_de("torse_acier") == "", "palettes de matière (os, acier) : pas une école de magie")
	# progression des matériaux : armure cuir < fourrure < fer < acier ; le lourd pèse plus que le léger
	var t := {}
	for m in MATERIAUX:
		t[m] = _total(MATERIAUX[m])
		var emplacements := []
		for id in MATERIAUX[m]:
			emplacements.append(Inventaire.emplacement_de(id))
		_verif(emplacements == ["tete", "torse", "mains", "pieds"], "%s : 4 pièces tête / torse / mains / pieds (armure %d, %.1f kg)" % [m, t[m].x, t[m].y])
	_verif(t["cuir"].x < t["fourrure"].x and t["fourrure"].x < t["fer"].x and t["fer"].x < t["acier_nordique"].x, "armure croissante : cuir < fourrure < fer < acier nordique")
	_verif(t["cuir"].y < t["fourrure"].y and t["fourrure"].y < t["os"].y and t["os"].y < t["fer"].y and t["fer"].y < t["acier_nordique"].y, "poids croissant : cuir < fourrure < os < fer < acier nordique")
	_verif(t["os"].x > t["fer"].x and t["os"].y < t["fer"].y * 0.6, "os de draugr (crypte) : plus d'armure que le fer pour moitié moins de poids")
	_verif(Inventaire.objet("amulette_givre").get("effets", {}).get("resist_froid", 0.0) == 0.25, "amulette de givre : −25 % de dégâts de froid")

# ------------------------------------------------------------------ équipement de corps

func _equipement_corps() -> void:
	var sac := Inventaire.new()
	var ec := EquipementCorps.new(sac)
	for id in MATERIAUX["fer"] + ["amulette_ours", "anneau_braise", "capuche_cuir"]:
		sac.ajouter(id)
	for id in MATERIAUX["fer"]:
		ec.equiper(id)
	_verif(ec.armure_totale() == 58.0 and ec.nombre_pieces("lourde") == 4 and ec.nombre_pieces("legere") == 0, "armure de fer complète : 58 points, 4 pièces lourdes")
	_verif(absf(ec.poids_porte() - 25.0) < 0.01 and absf(sac.poids() - (25.0 + 0.3 + 0.1 + 1.0)) < 0.01, "portée, l'armure reste dans le sac (25 kg)")
	_verif(ec.equiper("capuche_cuir") == "" and ec.objet_a("tete") == "capuche_cuir" and ec.armure_totale() == 51.0 and ec.nombre_pieces("legere") == 1,
		"équiper une capuche remplace le casque : 51 points, 1 pièce légère")
	ec.equiper("amulette_ours")
	ec.equiper("anneau_braise")
	_verif(ec.effets_totaux() == {"vie_max": 25.0, "resist_feu": 0.25} and ec.effet("vie_max") == 25.0 and ec.effet("charge") == 0.0, "bijoux : effets additionnés (vie +25, feu −25 %)")
	ec.retirer("torse")
	_verif(ec.objet_a("torse") == "" and ec.armure_totale() == 25.0, "retirer la cuirasse : 25 points")
	sac.retirer("amulette_ours")
	_verif(ec.objet_a("cou") == "" and not ec.effets_totaux().has("vie_max"), "amulette vendue / lâchée : retirée, son effet aussi")
	_verif(EquipementCorps.cle_resistance("glace") == "resist_froid" and EquipementCorps.cle_resistance("feu") == "resist_feu"
		and EquipementCorps.cle_resistance("electricite") == "resist_choc" and EquipementCorps.cle_resistance("tranchant") == "", "types de dégâts -> résistances")
	_verif(absf(EquipementCorps.facteur_armure(0.0) - 1.0) < 0.0001 and absf(EquipementCorps.facteur_armure(120.0) - 0.5) < 0.0001, "formule : 0 d'armure = ×1, 120 = ×0,5")

# ------------------------------------------------------------------ sac, poids des armes

func _poids_et_sac() -> void:
	_verif(Inventaire.CAPACITE == 150.0 and Inventaire.new().capacite() == 150.0, "sac : capacité 150")
	var sac := Inventaire.new()
	var armes := ["epee_soldat", "hache_guerre", "claymore", "marteau_guerre", "dague_acier", "bouclier_cercle", "epee_or", "hache_kolbeinn"]
	for id in armes:
		sac.ajouter(id)
	var p_armes := sac.poids()
	for id in MATERIAUX["acier_nordique"]:
		sac.ajouter(id)
	_verif(p_armes <= 55.0 and sac.poids() <= 90.0 and not sac.surcharge(), "8 armes = %.1f kg ; + armure d'acier nordique = %.1f kg sur 150 (pas surchargé)" % [p_armes, sac.poids()])
	var lourdes := []
	for id in CatalogueArmes.ids():
		if float(Inventaire.objet(id).get("poids", 0)) > 13.0:
			lourdes.append(id)
	for id in ["epee_skarnholt", "epee_or", "epee_rubis", "epee_verre", "epee_obsidienne", "epee_hrafn", "hache_kolbeinn"]:
		if float(Inventaire.objet(id).get("poids", 0)) > 7.0:
			lourdes.append(id)
	_verif(lourdes.is_empty(), "armes allégées : aucune arme du catalogue > 13 kg, épées écrites à la main ≤ 7 kg %s" % str(lourdes))
	var p := Progression.new()
	p.gagner_xp(150.0)
	p.choisir_attribut("vigueur")
	sac.capacite_bonus = p.bonus_charge()
	_verif(sac.capacite() == 155.0, "vigueur +10 : sac 155")

# ------------------------------------------------------------------ hache de Kolbeinn

func _kolbeinn() -> void:
	var sac := Inventaire.new()
	var eq := Equipement.new()
	var em := EquipementMains.new(eq, sac)
	var h: Variant = em.objet("hache_kolbeinn")
	_verif(h is DonneesArme and (h as DonneesArme).profil == "hache" and (h as DonneesArme).element == "gel" and ResourceLoader.exists((h as DonneesArme).modele),
		"hache de Kolbeinn : arme tenue (gestes de hache, gel, modèle présent)")
	var base := CatalogueArmes.donnees("hache_guerre")
	_verif(absf((h as DonneesArme).degats_leger - base.degats_leger * 1.25) < 0.1 and absf((h as DonneesArme).degats_lourd - base.degats_lourd * 1.25) < 0.1,
		"son bonus ×1,25 est dans ses propres dégâts (%.1f / %.1f contre %.1f / %.1f)" % [(h as DonneesArme).degats_leger, (h as DonneesArme).degats_lourd, base.degats_leger, base.degats_lourd])
	sac.ajouter("hache_kolbeinn")
	var tous := []
	for c: Dictionary in em.catalogue.get("categories", []):
		tous.append_array(em.objets_possedes(String(c.get("id", ""))))
	_verif(tous.has("hache_kolbeinn"), "dans le sac : la hache est proposée à l'équipement")
	_verif(eq.bonus_trophee(sac) == 1.0, "plus de bonus « dans le sac » : bonus_trophee = 1,0 avec la hache rangée")

# ------------------------------------------------------------------ butin

func _butin() -> void:
	_verif(ButinTables.verifier().is_empty(), "tables de butin : tous les objets connus")
	var t := ButinTables.tables()
	for nom in ["armures_communes", "armures_draugr", "armures_rares", "armures_crypte", "bijoux_enchantes"]:
		_verif(t.has(nom), "sous-table %s" % nom)
	var vus := {}
	for i in 400:
		for table in ["cadavre_draugr", "cadavre_bandit", "cadavre_mage", "coffre_bandit", "coffre_crypte_riche", "coffre_boss"]:
			for o: Dictionary in ButinTables.tirer(table, 1000 + i, "crypte" if table != "coffre_bandit" else "grotte"):
				var cat := Inventaire.categorie_de(String(o["id"]))
				if cat in ["armure", "bijou"]:
					if not vus.has(table):
						vus[table] = {}
					vus[table][String(o["id"])] = true
	var draugr: Dictionary = vus.get("cadavre_draugr", {})
	_verif(draugr.has("casque_os") or draugr.has("gants_os") or draugr.has("bottes_os"), "corps de draugr : pièces d'os de draugr %s" % str(draugr.keys()))
	var bandit: Dictionary = vus.get("cadavre_bandit", {})
	_verif(bandit.has("armure_cuir") or bandit.has("capuche_cuir") or bandit.has("casque_fourrure"), "corps de bandit : cuir / fourrure %s" % str(bandit.keys().slice(0, 6)))
	var mage: Dictionary = vus.get("cadavre_mage", {})
	_verif(mage.has("capuche_thaumaturge"), "corps de mage : capuche du thaumaturge possible")
	var riches: Dictionary = vus.get("coffre_crypte_riche", {})
	riches.merge(vus.get("coffre_boss", {}))
	var enchantes := riches.keys().filter(func(id: String) -> bool: return not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty())
	_verif(not enchantes.is_empty(), "coffres riches / chef de la crypte : pièces enchantées %s" % str(enchantes.slice(0, 6)))
	var bandit_c: Dictionary = vus.get("coffre_bandit", {})
	var rares_grotte := bandit_c.keys().filter(func(id: String) -> bool: return String(Inventaire.objet(id).get("rarete", "")) in ["rare", "unique"])
	_verif(not bandit_c.is_empty() and rares_grotte.is_empty(), "coffres de bandits (grotte) : armures communes seulement %s" % str(bandit_c.keys().slice(0, 6)))

# ------------------------------------------------------------------ marchand

func _marchand() -> void:
	_verif(Marchand.verifier().is_empty(), "marchands : tous les objets connus")
	var en_rayon := {}
	var enchantes := []
	for e: Dictionary in Marchand.fiche("forgeron").get("stock", []):
		var id := String(e.get("id", ""))
		en_rayon[id] = true
		if not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty():
			enchantes.append(id)
	var armures := en_rayon.keys().filter(func(id: String) -> bool: return Inventaire.categorie_de(id) == "armure")
	_verif(armures.size() >= 12 and en_rayon.has("cuirasse_fer") and en_rayon.has("cuirasse_acier_nordique") and not en_rayon.has("cuirasse_os"),
		"Brodd vend cuir, fourrure, fer, acier nordique (%d pièces), pas d'os de draugr" % armures.size())
	_verif(enchantes.is_empty(), "aucun objet enchanté en boutique %s" % str(enchantes))
	_verif(Marchand.rachete("forgeron", "casque_os") and Marchand.rachete("forgeron", "anneau_braise"), "Brodd rachète armures et bijoux")
	var n := 0
	for per in 20:
		for id in Marchand.stock_tire("forgeron", per):
			if Inventaire.categorie_de(id) == "armure":
				n += 1
	_verif(n >= 20 * 3, "réassorts : %d pièces d'armure en rayon sur 20 périodes" % n)

# ------------------------------------------------------------------ joueur réel : dégâts reçus

func _coup(j: Node, degats: float, options := {}) -> float:
	j.vie = 100.0
	j.mort = false
	j.recevoir_coup(degats, j.global_position + j.global_transform.basis.z * -1.5, options)
	return 100.0 - float(j.vie)

func _joueur() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 10:
		await process_frame
	var j = s.joueur
	_verif(j.inventaire.capacite() == 150.0, "joueur neuf : sac 150")
	var d0: float = _coup(j, 30.0)
	_verif(absf(d0 - 30.0) < 0.01, "sans armure : 30 de dégâts encaissés en entier (%.2f)" % d0)
	for id in MATERIAUX["fer"] + ["amulette_givre", "collier_portefaix"]:
		j.inventaire.ajouter(id)
	for id in MATERIAUX["fer"]:
		j.equipement_corps.equiper(id)
	var d1: float = _coup(j, 30.0)
	_verif(absf(d1 - 30.0 * 120.0 / 178.0) < 0.05, "armure de fer (58) : 30 -> %.2f (× 120 / 178)" % d1)
	var dg: float = _coup(j, 20.0, {"type": "glace"})
	_verif(absf(dg - 20.0) < 0.05, "coup de glace : l'armure ne l'arrête pas, sans résistance (%.2f)" % dg)
	j.equipement_corps.equiper("amulette_givre")
	dg = _coup(j, 20.0, {"type": "glace"})
	_verif(absf(dg - 15.0) < 0.05, "amulette de givre : coup de glace 20 -> %.2f (−25 %%)" % dg)
	var df: float = _coup(j, 20.0, {"type": "feu"})
	_verif(absf(df - 20.0) < 0.05, "elle ne protège pas du feu (%.2f)" % df)
	j.equipement_corps.equiper("collier_portefaix")
	_verif(j.inventaire.capacite() == 180.0, "collier du portefaix au cou : sac 180 (+30)")
	j.equipement_corps.retirer("cou")
	_verif(j.inventaire.capacite() == 150.0, "retiré : sac 150")
	# équilibrage : coups de draugr (ReglagesCombat) encaissés avant de tomber, selon l'armure
	var dr := ReglagesCombat.degats("draugr")
	var coups := {}
	for m in ["", "cuir", "fer", "acier_nordique"]:
		for e in ["tete", "torse", "mains", "pieds"]:
			j.equipement_corps.retirer(e)
		if m != "":
			for id in MATERIAUX[m]:
				j.inventaire.ajouter(id)
				j.equipement_corps.equiper(id)
		coups[m if m != "" else "nu"] = ceili(100.0 / _coup(j, dr))
	print("       coups de draugr (11) pour tuer : ", coups)
	_verif(coups["nu"] == 10 and coups["cuir"] > coups["nu"] and coups["acier_nordique"] > coups["fer"] and coups["acier_nordique"] <= 18,
		"équilibrage : draugr nu 10 coups, armure lourde complète ≤ 18 (%s)" % str(coups))
	j.vie = 100.0
	s.queue_free()
	await process_frame
