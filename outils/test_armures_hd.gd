extends SceneTree
## Armures HD — DONNÉES (branche armures_hd/donnees, 2026-11-02 ; charte conception_rpg/CHARTE_ARMURES_HD.md) :
##   - 5 ensembles par matériau (or, verre, obsidienne, rubis, saphir) : 4 pièces, ids fixés, échelle d'armure / poids cohérente
##     avec les ensembles existants (léger : os < verre < saphir ; lourd : fer < or < acier < rubis < obsidienne), chemins des glb ;
##   - variantes enchantées : base, même modèle, « variante_materiau » enchante, rare / unique, effets connus, coups élémentaires
##     seulement sur des gantelets ; ArmureVisible.variante / base_de / chausses de la base ;
##   - clés d'effets nouvelles : coup_<élément> (Elements.coup_equipement, chemin DegatsCombat.appliquer), resist_magie
##     (EquipementCorps.resistance_totale, plafond 80 %, joueur.recevoir_coup), vol_vie (Progression.coup_porte, sans perk) ;
##   - butin par palier 1..5 (ButinTables.tirer_armure / probabilites) : déterminisme, enchantées croissantes, fréquences ;
##   - Brodd : quelques pièces or / verre / saphir, jamais d'enchantée ; il rachète tout ;
##   - équilibrage : coups de draugr / jarl encaissés avec chaque ensemble, compétence Armure neutre et au maximum de l'arbre.
##   godot --headless --path . --script res://outils/test_armures_hd.gd -- --nouvelle

const SCENE := preload("res://scenes/test_combat.tscn")
const MATERIAUX := ["or", "verre", "obsidienne", "rubis", "saphir"]
const PIECES := ["casque_%s", "cuirasse_%s", "gantelets_%s", "bottes_%s"]
const ANCIENS := {
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"fourrure": ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"],
	"os": ["casque_os", "cuirasse_os", "gants_os", "bottes_os"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"acier_nordique": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
}
const COUPS := ["coup_feu", "coup_glace", "coup_electricite", "coup_tenebres"]

var _ok := true
var _n := 0

class Cible extends Node3D:
	var recu := 0.0
	var vie := 100.0
	func recevoir_coup(d: float, _o: Vector3, _p: bool, _info := {}) -> String:
		recu = d
		return "touche"

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _tester() -> void:
	_ensembles()
	_variantes()
	_coups_elementaires()
	_resistances()
	_butin_paliers()
	_brodd()
	await _joueur()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

static func ids_de(m: String) -> Array:
	if ANCIENS.has(m):
		return ANCIENS[m]
	return PIECES.map(func(p: String) -> String: return p % m)

static func total(m: String) -> Vector2:
	var t := Vector2.ZERO
	for id in ids_de(m):
		t += Vector2(float(Inventaire.objet(id).get("armure", 0)), float(Inventaire.objet(id).get("poids", 0)))
	return t

static func variantes() -> Array:
	return Inventaire.ids_connus().filter(func(id: String) -> bool: return String(Inventaire.objet(id).get("variante_materiau", "")) != "")

# ------------------------------------------------------------------ ensembles par matériau

func _ensembles() -> void:
	var fautes := []
	for m in MATERIAUX:
		var empl := []
		for id: String in ids_de(m):
			var f := Inventaire.objet(id)
			empl.append(String(f.get("emplacement", "")))
			if f.is_empty() or String(f.get("materiau", "")) != m or String(f.get("rarete", "")) != "rare" or f.has("effets") \
					or f.get("modele_porte", "") != "res://assets/modeles/armures/porte/%s.glb" % id \
					or f.get("modele_sol", "") != "res://assets/modeles/armures/sol/%s.glb" % id or not IconesCombat.connu(String(f.get("icone", ""))) \
					or String(f.get("nom", "")) == "" or String(f.get("description", "")) == "":
				fautes.append(id)
		_verif(empl == ["tete", "torse", "mains", "pieds"], "%s : 4 pièces tête / torse / mains / pieds (armure %d, %.1f kg)" % [m, total(m).x, total(m).y])
	_verif(fautes.is_empty(), "pièces de base : rares, sans effet, matériau, icône, nom, chemins porte/<id>.glb et sol/<id>.glb %s" % str(fautes))
	_verif(String(Inventaire.objet("cuirasse_verre").get("type_armure")) == "legere" and String(Inventaire.objet("cuirasse_saphir").get("type_armure")) == "legere"
		and String(Inventaire.objet("cuirasse_or").get("type_armure")) == "lourde" and String(Inventaire.objet("cuirasse_rubis").get("type_armure")) == "lourde"
		and String(Inventaire.objet("cuirasse_obsidienne").get("type_armure")) == "lourde", "légères : verre, saphir ; lourdes : or, rubis, obsidienne")
	var t := {}
	for m in MATERIAUX + ANCIENS.keys():
		t[m] = total(m)
	# COMPROMIS (profils de l'utilisateur, 2026-11-02) : acier polyvalent ; or prestige (protection moyenne, lourd, valeur, magie / prix) ;
	# rubis magie (résistance magique, sorts ; physique moyen) ; verre mobilité (très léger, physique moyen-haut) ; obsidienne
	# physique très haut, très lourde, vigueur / course pénalisées, magie faible ; saphir : froid
	_verif(t["os"].x < t["saphir"].x and t["saphir"].x < t["verre"].x and t["verre"].x < t["acier_nordique"].x and t["fer"].x < t["verre"].x,
		"verre (%d) : protection moyenne-haute, entre le fer et l'acier ; saphir %d, os %d" % [t["verre"].x, t["saphir"].x, t["os"].x])
	_verif(t["verre"].y == MATERIAUX.map(func(m: String) -> float: return total(m).y).min() and t["verre"].y < t["cuir"].y + 2.0, "verre : le plus léger des ensembles précieux (%.1f kg)" % t["verre"].y)
	_verif(t["fer"].x < t["or"].x and t["or"].x < t["rubis"].x and t["rubis"].x < t["acier_nordique"].x and t["acier_nordique"].x < t["obsidienne"].x,
		"physique : fer %d < or %d < rubis %d < acier %d < obsidienne %d" % [t["fer"].x, t["or"].x, t["rubis"].x, t["acier_nordique"].x, t["obsidienne"].x])
	_verif(t["or"].y > t["fer"].y and t["obsidienne"].y == (MATERIAUX + ANCIENS.keys()).map(func(m: String) -> float: return total(m).y).max() and t["obsidienne"].y <= 40.0,
		"or lourd (%.1f > fer %.1f), obsidienne la plus lourde de toutes (%.1f kg ≤ 40)" % [t["or"].y, t["fer"].y, t["obsidienne"].y])
	var tr := {}
	for m in MATERIAUX + ANCIENS.keys():
		tr[m] = {}
		for id in ids_de(m):
			var tf: Dictionary = Inventaire.objet(id).get("traits", {})
			for k in tf:
				tr[m][k] = float(tr[m].get(k, 0.0)) + float(tf[k])
	print("       traits de matière par ensemble : ", tr)
	var rm := func(m: String) -> float: return float(tr[m].get("resist_magie", 0.0))
	_verif(rm.call("rubis") >= 0.2 and float(tr["rubis"].get("degats_destruction", 0.0)) >= 0.1 and MATERIAUX.all(func(m: String) -> bool: return m == "rubis" or rm.call(m) < rm.call("rubis")),
		"rubis : meilleure protection MAGIQUE (%.2f) et dégâts des sorts +%d %%" % [rm.call("rubis"), roundi(float(tr["rubis"].get("degats_destruction", 0.0)) * 100.0)])
	_verif(rm.call("obsidienne") < 0.0 and float(tr["obsidienne"].get("regen_vigueur", 0.0)) < 0.0 and float(tr["obsidienne"].get("cout_course", 0.0)) < 0.0,
		"obsidienne : protection magique faible (%.2f), vigueur et course pénalisées" % rm.call("obsidienne"))
	_verif(float(tr["verre"].get("vigueur_max", 0.0)) > 0.0 and float(tr["verre"].get("cout_course", 0.0)) > 0.0 and float(tr["verre"].get("regen_vigueur", 0.0)) > 0.0,
		"verre : mobilité (vigueur, régénération de vigueur, course)")
	_verif(float(tr["or"].get("magie_max", 0.0)) > 0.0 and float(tr["or"].get("prix", 0.0)) > 0.0 and float(tr["saphir"].get("resist_froid", 0.0)) >= 0.2,
		"or : magie et prix (persuasion des marchands) ; saphir : froid")
	_verif(tr["acier_nordique"].is_empty() and tr["fer"].is_empty(), "fer / acier : polyvalents, sans trait")
	var gagnant := []
	for m in MATERIAUX:   # aucun ensemble précieux ne bat l'acier PARTOUT (armure, poids, résistance magique)
		if t[m].x >= t["acier_nordique"].x and t[m].y <= t["acier_nordique"].y and rm.call(m) >= 0.0:
			gagnant.append(m)
	_verif(gagnant.is_empty(), "compromis : aucun ensemble précieux meilleur que l'acier à la fois en armure, en poids et en magie %s" % str(gagnant))
	var val := {}
	for m in MATERIAUX + ANCIENS.keys():
		val[m] = 0
		for id in ids_de(m):
			val[m] += int(Inventaire.objet(id).get("valeur", 0))
	_verif(MATERIAUX.all(func(m: String) -> bool: return val[m] > val["acier_nordique"] * 2) and val["or"] == MATERIAUX.map(func(m: String) -> int: return val[m]).max(),
		"valeurs : chaque ensemble précieux vaut plus de 2 × l'acier nordique, l'or (prestige) le plus %s" % str(val))
	var torse_part := []
	for m in MATERIAUX:
		var p: float = float(Inventaire.objet("cuirasse_" + m).get("armure")) / float(t[m].x)
		if p < 0.4 or p > 0.5:
			torse_part.append(m)
	_verif(torse_part.is_empty(), "répartition : le torse porte 40-50 %% de l'armure de l'ensemble %s" % str(torse_part))

# ------------------------------------------------------------------ variantes enchantées

func _variantes() -> void:
	var vs := variantes()
	var par_m := {}
	var fautes := []
	var coups_hors_mains := []
	for id: String in vs:
		var f := Inventaire.objet(id)
		var b := Inventaire.objet(String(f.get("base", "")))
		var m := String(f.get("materiau", ""))
		par_m[m] = int(par_m.get(m, 0)) + 1
		var ef: Dictionary = f.get("effets", {})
		if b.is_empty() or f.get("variante_materiau") != "enchante" or not String(f.get("rarete")) in ["rare", "unique"] or ef.is_empty() \
				or f.get("modele_porte") != b.get("modele_porte") or f.get("modele_sol") != b.get("modele_sol") or f.get("armure") != b.get("armure") \
				or f.get("poids") != b.get("poids") or f.get("emplacement") != b.get("emplacement") or m != String(b.get("materiau")) \
				or int(f.get("valeur")) <= int(b.get("valeur")) or f.get("icone") != b.get("icone") or f.get("traits", {}) != b.get("traits", {}):
			fautes.append(id)
		for k in ef:
			if k in COUPS and f.get("emplacement") != "mains":
				coups_hors_mains.append(id)
	_verif(MATERIAUX.all(func(m: String) -> bool: return int(par_m.get(m, 0)) >= 2 and int(par_m.get(m, 0)) <= 4), "2 à 4 variantes enchantées par matériau précieux %s" % str(par_m))
	_verif(fautes.is_empty(), "variante = base (même glb sol / porté, armure, poids, emplacement, icône), « enchante », rare / unique, effets, plus chère %s" % str(fautes))
	_verif(coups_hors_mains.is_empty(), "dégâts ajoutés aux coups (coup_*) seulement sur des gantelets : une seule source portée %s" % str(coups_hors_mains))
	var cles := {}
	for id: String in vs:
		for k in Inventaire.objet(id).get("effets", {}):
			cles[k] = true
	for k in ["coup_feu", "coup_glace", "coup_electricite", "coup_tenebres", "resist_magie", "vol_vie", "resist_froid", "resist_feu", "resist_choc", "magie_max", "cout_sorts", "regen_vie", "regen_magie"]:
		if not cles.has(k):
			fautes.append(k)
	_verif(fautes.is_empty(), "palette d'effets : 4 coups élémentaires, résistances (froid, feu, choc, magie), magie, coût des sorts, régénérations, vol de vie %s" % str(fautes))
	_verif(ArmureVisible.variante("gantelets_rubis_braise") == "enchante" and ArmureVisible.variante("gantelets_rubis") == ""
		and ArmureVisible.base_de("cuirasse_saphir_hiver") == "cuirasse_saphir" and ArmureVisible.base_de("cuirasse_fer") == "cuirasse_fer"
		and ArmureVisible.famille_chausses("cuirasse_saphir_hiver") == ArmureVisible.famille_chausses("cuirasse_saphir")
		and ArmureVisible.chemin_porte("cuirasse_saphir_hiver") == ArmureVisible.chemin_porte("cuirasse_saphir"),
		"ArmureVisible : variante « enchante », base, mêmes chausses et même glb porté que la base")
	var m1 := ArmureVisible.materiau("or", null, "enchante")
	var m0 := ArmureVisible.materiau("or", null)
	_verif(float(m1.get_shader_parameter("mt_lueur")) >= ArmureVisible.LUEUR_VARIANTE and float(m0.get_shader_parameter("mt_lueur")) < ArmureVisible.LUEUR_VARIANTE
		and m1.resource_name == "armure_or.enchante", "matériau `or.enchante` : preset de base + lueur faible tant que le preset dédié n'existe pas")
	var bad := []
	for id: String in vs:
		if String(Inventaire.objet(id).get("rarete")) == "unique" and Inventaire.objet(id).get("effets", {}).size() < 2:
			bad.append(id)
	_verif(bad.is_empty(), "les uniques ont au moins deux effets %s" % str(bad))

# ------------------------------------------------------------------ coups élémentaires (Elements.coup_equipement)

func _coups_elementaires() -> void:
	var c := Cible.new()
	root.add_child(c)
	var i := {"attaque": "legere", "arme": "epee_soldat"}
	var d := Elements.coup_equipement(c, i, {"coup_feu": 5.0})
	_verif(absf(d - 5.0) < 0.001 and String(i.get("statut", "")) == "" and i.get("enchant_equipement") == ["feu"], "coup léger + gantelets de braise : +5 de feu, pas de statut")
	i = {"attaque": "lourde", "arme": "epee_soldat"}
	d = Elements.coup_equipement(c, i, {"coup_glace": 4.0})
	_verif(absf(d - 4.0) < 0.001 and i.get("statut") == "gel" and absf(float(i.get("puissance_statut")) - 0.3) < 0.001, "coup lourd + givre : +4 et gel 0,3")
	i = {"attaque": "contre", "arme": "epee_soldat", "statut": "brulure"}
	Elements.coup_equipement(c, i, {"coup_electricite": 4.0})
	_verif(i.get("statut") == "brulure", "le statut de l'arme (rubis) n'est pas remplacé par celui des gantelets")
	i = {"attaque": "legere", "arme": "epee_soldat", "affaibli": true}
	d = Elements.coup_equipement(c, i, {"coup_tenebres": 3.0})
	_verif(absf(d - 1.5) < 0.001, "coup affaibli : moitié (%.2f)" % d)
	_verif(Elements.coup_equipement(c, {"attaque": "legere"}, {"vie_max": 20.0}) == 0.0, "sans enchantement : 0")
	# joueur courant : progression + équipement réels, chemin unique des coups (DegatsCombat.appliquer)
	var sac := Inventaire.new()
	var ec := EquipementCorps.new(sac)
	var p := Progression.new()
	p.equipement_corps = ec
	p.activer()
	sac.ajouter("gantelets_rubis_braise")
	ec.equiper("gantelets_rubis_braise")
	var r := DegatsCombat.appliquer(c, 14.0, Vector3(0, 0, 2), false, {"attaque": "legere", "arme": "epee_soldat", "type": "tranchant"})
	_verif(r == "touche" and absf(c.recu - 19.0) < 0.001, "DegatsCombat.appliquer : épée 14 + gantelets de braise portés = %.1f reçus" % c.recu)
	r = DegatsCombat.appliquer(c, 20.0, Vector3(0, 0, 2), false, {"attaque": "sort", "ecole": "feu", "type": "feu"})
	_verif(absf(c.recu - 20.0) < 0.001, "un sort ne reçoit pas le bonus des gantelets (%.1f)" % c.recu)
	r = DegatsCombat.appliquer(c, 18.0, Vector3(0, 0, 2), true, {"attaque": "lourde", "arme": "masse_cloutee", "type": "contondant"})
	_verif(absf(c.recu - 23.0) < 0.001 and Statuts.a(c, "brulure"), "masse (contondant), coup lourd : +5 et brûlure posée (%.1f)" % c.recu)
	ec.retirer("mains")
	c.queue_free()

# ------------------------------------------------------------------ résistances (resist_magie, plafond)

func _resistances() -> void:
	var sac := Inventaire.new()
	var ec := EquipementCorps.new(sac)
	var p := Progression.new()
	p.equipement_corps = ec
	for id in ["casque_saphir_ymir", "cuirasse_saphir_hiver", "bottes_saphir_glacier"]:
		sac.ajouter(id)
		ec.equiper(id)
	var g := EquipementCorps.resistance_totale(p, "glace")
	_verif(absf(g - EquipementCorps.RESISTANCE_MAX) < 0.0001, "saphir (froid 0,35 + 0,3 + 0,2 + magie 0,15 = 1,0) : plafonné à 80 %% (%.2f)" % g)
	_verif(absf(EquipementCorps.resistance_totale(p, "feu") - 0.15) < 0.0001 and absf(EquipementCorps.resistance_totale(p, "tenebres") - 0.15) < 0.0001
		and EquipementCorps.resistance_totale(p, "tranchant") == 0.0 and EquipementCorps.resistance_totale(p, "") == 0.0,
		"resist_magie 0,15 : feu et ténèbres −15 %, coup physique 0")
	_verif(EquipementCorps.est_magique("tenebres") and EquipementCorps.est_magique("glace") and not EquipementCorps.est_magique("tranchant") and not EquipementCorps.est_magique(""),
		"types magiques : ténèbres / glace oui, tranchant / vide non (armure)")

# ------------------------------------------------------------------ butin par palier

func _butin_paliers() -> void:
	ButinTables.recharger()
	_verif(ButinTables.verifier().is_empty(), "tables de butin : tous les objets connus %s" % str(ButinTables.verifier().slice(0, 4)))
	var ench := []
	var moy := []
	var precieux := []
	for n in range(1, 6):
		var pr := ButinTables.probabilites(ButinTables.table_armure(n))
		var s := 0.0
		var e := 0.0
		var a := 0.0
		var pq := 0.0
		for id: String in pr:
			s += pr[id]
			a += pr[id] * float(Inventaire.objet(id).get("armure", 0))
			if not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty():
				e += pr[id]
			if String(Inventaire.objet(id).get("materiau", "")) != "" and not Inventaire.objet(id).has("effets"):
				pq += pr[id]   # pièce de base d'un ensemble précieux
		_verif(absf(s - 1.0) < 0.0001 and pr.keys().all(func(id: String) -> bool: return Inventaire.categorie_de(id) == "armure"), "palier %d : toujours une pièce d'armure (somme %.4f)" % [n, s])
		ench.append(e)
		moy.append(a)
		precieux.append(pq)
	print("       enchantées par palier : ", ench.map(func(x: float) -> String: return "%.1f %%" % (x * 100.0)))
	print("       armure moyenne par pièce : ", moy.map(func(x: float) -> String: return "%.1f" % x))
	_verif(ench[0] == 0.0 and absf(ench[1] - 0.02) < 1e-4 and absf(ench[2] - 0.09) < 1e-4 and absf(ench[3] - 0.13) < 1e-4 and absf(ench[4] - 0.25) < 1e-4,
		"chance d'enchantée : 0 / 2 / 9 / 13 / 25 %")
	_verif(moy[0] < moy[1] and moy[1] < moy[2] and moy[2] < moy[3] and moy[3] < moy[4], "armure moyenne croissante avec le palier")
	_verif(precieux[0] == 0.0 and precieux[1] == 0.0 and precieux[2] > 0.0 and precieux[4] > precieux[3], "matériaux précieux à partir du palier 3, de plus en plus %s" % str(precieux))
	var p5 := ButinTables.probabilites("armures_palier_5")
	_verif(not p5.has("capuche_cuir") and not p5.has("casque_fer") and p5.has("cuirasse_obsidienne") and p5.has("casque_rubis_surt"), "palier 5 : ni cuir ni fer ; obsidienne et uniques")
	# déterminisme, bornes
	_verif(ButinTables.tirer_armure(3, 1234) == ButinTables.tirer_armure(3, 1234) and ButinTables.tirer_armure(0, 77) == ButinTables.tirer_armure(1, 77)
		and ButinTables.tirer_armure(9, 77) == ButinTables.tirer_armure(5, 77) and ButinTables.table_armure(-3) == "armures_palier_1", "même graine = même pièce ; palier borné à 1..5")
	# fréquences mesurées ≈ probabilités (palier 4, 6000 tirages)
	var pr4 := ButinTables.probabilites("armures_palier_4")
	var compte := {}
	var nb := 6000
	var une_piece := true
	for k in nb:
		var l := ButinTables.tirer_armure(4, ButinTables.graine("essai_palier:%d" % k))
		une_piece = une_piece and l.size() == 1 and int(l[0]["n"]) == 1
		if not l.is_empty():
			compte[String(l[0]["id"])] = int(compte.get(String(l[0]["id"]), 0)) + 1
	var ecart := 0.0
	var ench_mesure := 0.0
	for id: String in pr4:
		ecart = maxf(ecart, absf(float(compte.get(id, 0)) / nb - pr4[id]))
		if not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty():
			ench_mesure += float(compte.get(id, 0)) / nb
	_verif(une_piece and ecart < 0.015 and absf(ench_mesure - 0.13) < 0.02, "palier 4, %d tirages : une pièce à chaque fois, écart max %.4f, enchantées %.1f %%" % [nb, ecart, ench_mesure * 100.0])
	var zc := ButinTables.probabilites("armures_palier_4", "crypte_basse")
	var ez := 0.0
	for id: String in zc:
		if not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty():
			ez += zc[id]
	_verif(ez > ench[3], "zone crypte_basse (rares ×1,5) : plus d'enchantées (%.1f %% contre %.1f %%)" % [ez * 100.0, ench[3] * 100.0])

# ------------------------------------------------------------------ Brodd

func _brodd() -> void:
	_verif(Marchand.verifier().is_empty(), "marchands : tous les objets connus")
	var rayon := {}
	for e: Dictionary in Marchand.fiche("forgeron").get("stock", []):
		rayon[String(e.get("id"))] = int(e.get("chance", 100))
	var precieux := rayon.keys().filter(func(id: String) -> bool: return Inventaire.categorie_de(id) == "armure" and String(Inventaire.objet(id).get("materiau", "")) != "")
	var ench := rayon.keys().filter(func(id: String) -> bool: return not (Inventaire.objet(id).get("effets", {}) as Dictionary).is_empty())
	_verif(precieux.size() >= 4 and precieux.all(func(id: String) -> bool: return String(Inventaire.objet(id)["materiau"]) in ["or", "verre", "saphir"] and rayon[id] <= 12),
		"Brodd : pièces or / verre / saphir rares en rayon (≤ 12 %%) %s" % str(precieux))
	_verif(ench.is_empty(), "jamais d'armure enchantée en boutique %s" % str(ench))
	var non := []
	for id: String in Inventaire.ids_connus():
		if Inventaire.categorie_de(id) == "armure" and String(Inventaire.objet(id).get("materiau", "")) != "" and not Marchand.rachete("forgeron", id):
			non.append(id)
	_verif(non.is_empty(), "Brodd rachète les nouvelles pièces et leurs variantes %s" % str(non))

# ------------------------------------------------------------------ joueur réel : équilibrage (ReglagesCombat)

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
	var dr := ReglagesCombat.degats("draugr")
	var jarl := ReglagesCombat.degats("jarl")
	var lignes := {}
	for m in ["nu", "cuir", "os", "fer", "acier_nordique"] + MATERIAUX:
		for e in ["tete", "torse", "mains", "pieds"]:
			j.equipement_corps.retirer(e)
		if m != "nu":
			for id in ids_de(m):
				j.inventaire.ajouter(id)
				j.equipement_corps.equiper(id)
		lignes[m] = [ceili(100.0 / _coup(j, dr)), ceili(100.0 / _coup(j, jarl))]
	print("       coups pour tuer (100 PV, compétence Armure 1,0) [draugr 11, jarl 28] : ", lignes)
	_verif(lignes["nu"][0] == 10 and lignes["obsidienne"][0] > lignes["acier_nordique"][0] and lignes["obsidienne"][0] <= 20 and lignes["obsidienne"][1] <= 8,
		"équilibrage : obsidienne complète > acier, mais un draugr la tue en ≤ 20 coups, le jarl en ≤ 8 (%s / %s)" % [str(lignes["obsidienne"]), str(lignes["acier_nordique"])])
	_verif(lignes["verre"][0] >= lignes["os"][0] and lignes["saphir"][0] >= lignes["os"][0] and lignes["or"][0] <= lignes["acier_nordique"][0], "verre, saphir ≥ os ; or ≤ acier (protection moyenne)")
	# pire cas : obsidienne + arbre Armure au maximum (Cuir et maille 1,5 + Rempart vivant +0,2 = ×1,7)
	var red := 1.0 - EquipementCorps.facteur_armure(total("obsidienne").x * 1.7)
	_verif(red <= 0.65, "obsidienne + arbre Armure au maximum : −%.0f %% de dégâts physiques (≤ 65 %%, jamais invincible)" % (red * 100.0))
	# résistance magique réelle (recevoir_coup) : l'obsidienne est vulnérable à la magie
	for id in ids_de("obsidienne"):
		j.equipement_corps.equiper(id)
	var dt: float = _coup(j, 20.0, {"type": "tenebres"})
	var df: float = _coup(j, 20.0, {"type": "feu"})
	_verif(absf(dt - 22.0) < 0.05 and absf(df - 22.0) < 0.05, "obsidienne complète (résistance magique −10 %%) : ténèbres 20 -> %.2f, feu 20 -> %.2f" % [dt, df])
	j.inventaire.ajouter("casque_obsidienne_hel")
	j.equipement_corps.equiper("casque_obsidienne_hel")
	dt = _coup(j, 20.0, {"type": "tenebres"})
	_verif(absf(dt - 18.0) < 0.05, "Heaume de Hel à la place du heaume (+20 %% de magie) : obsidienne à +10 %%, ténèbres 20 -> %.2f" % dt)
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.retirer(e)
	for id in ids_de("rubis"):
		j.inventaire.ajouter(id)
		j.equipement_corps.equiper(id)
	df = _coup(j, 20.0, {"type": "feu"})
	_verif(absf(df - 16.0) < 0.05 and absf(j.progression.mult("destruction") - 1.15) < 0.001, "rubis complet : feu 20 -> %.2f (−20 %%), sorts ×%.2f" % [df, j.progression.mult("destruction")])
	# vol de vie (Progression.coup_porte, sans aucun perk)
	j.inventaire.ajouter("gantelets_obsidienne_nidhogg")
	j.equipement_corps.equiper("gantelets_obsidienne_nidhogg")
	j.vie = 50.0
	Progression.coup_porte(j, null, CatalogueArmes.donnees("epee_soldat"), 20.0, "touche", false)
	_verif(absf(float(j.vie) - 51.2) < 0.01 and j.progression.perks.is_empty(), "Gantelets de Nidhogg : 6 %% de 20 = +1,2 vie, sans perk (%.2f)" % float(j.vie))
	j.vie = 100.0
	s.queue_free()
	await process_frame
