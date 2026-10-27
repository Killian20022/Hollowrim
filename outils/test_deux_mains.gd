extends SceneTree
## Test sans fenêtre des configurations des deux mains (prompt §12) et des profils des 5 épées (§11), dans
## scenes/test_combat.tscn (mannequin à 1,5 m) :
##   godot --headless --path . --script res://outils/test_deux_mains.gd -- --nouvelle
## Pour chaque configuration : équipement (règles de regles_mains.json), attaque (le mannequin est touché, ou le sort part),
## garde (clic droit tenu → coup de face bloqué / paré), main non attaquante (torche abaissée puis revenue, bouclier
## visible). Lignes CONFIG (tableau OK / non / KO) et PROFIL (durées, coût, statut posé).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const EPEES := ["epee_metal", "epee_or", "epee_rubis", "epee_verre", "epee_obsidienne"]

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: Node
var _lignes := []

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
		if i % 6 == 5:
			await physics_frame

func _reset() -> void:
	Input.action_release("main_gauche")
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
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	var st := Statuts.de(s.mannequin, false)
	if st != null:
		st.actifs.clear()
		st.recharge_reaction = 0.0
	s.placer_joueur(Vector3(0, 0, s.POS_MANNEQUIN.z + 1.5), 0.0)
	await _sim(0.5)

## Coup léger (ou lourd) de la main droite : nombre de touches sur le mannequin.
func _attaque(lourd := false) -> int:
	var n0: int = s.mannequin.coups.size()
	mains.entrees.appuyer()
	await _sim(0.6 if lourd else 0.05)
	mains.entrees.relacher()
	await _sim(0.7)
	return s.mannequin.coups.size() - n0

## Clic droit tenu (action main_gauche) puis coup ennemi de face : issue (« parade », « bloque ») ou "" si la garde ne joue pas.
func _garde() -> String:
	Input.action_press("main_gauche")
	await _sim(0.35)   # après la fenêtre de parade : blocage simple
	var leve: bool = mains.bloque
	var r := ""
	if leve:
		r = String(j.recevoir_coup(10.0, j.global_position + Vector3(0, 0, -1.5)))
	Input.action_release("main_gauche")
	await _sim(0.5)
	return r if leve else ""

func _config(nom: String, droite: Variant, gauche: Variant) -> Dictionary:
	await _reset()
	var r := {"nom": nom}
	var refus_d: String = magie.equiper("droite", droite)
	var refus_g: String = magie.equiper("gauche", gauche) if gauche != null else ""
	r["refus"] = (refus_d + " " + refus_g).strip_edges()
	await _sim(0.6)   # dégainer
	return r

func _ligne(nom: String, equipement: String, attaque: String, garde: String, autre: String) -> void:
	_lignes.append("CONFIG %-22s | équipement %-28s | attaque %-30s | garde %-24s | autre main %s" % [nom, equipement, attaque, garde, autre])

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
	for i in 20:
		await physics_frame
	var eq: EquipementMains = magie.eq

	# 1. épée + torche
	await _config("épée + torche", "epee", "torche")
	var ok_eq: bool = eq.categorie("droite") == "arme" and eq.categorie("gauche") == "torche" and mains.torche_sortie
	var baisse_max := [0.0]
	var n0: int = s.mannequin.coups.size()
	mains.entrees.appuyer()
	await _sim(0.05)
	mains.entrees.relacher()
	for i in 20:
		mains.avancer(DT)
		baisse_max[0] = maxf(baisse_max[0], mains._baisse_torche)
	await _sim(1.2)
	var t1: int = s.mannequin.coups.size() - n0
	var revenue: bool = mains._baisse_torche < 0.03
	var g1 := await _garde()
	_verif(ok_eq, "épée + torche : équipées (épée à droite, torche sortie)")
	_verif(t1 == 1, "épée + torche : le coup léger touche le mannequin (%d)" % t1)
	_verif(g1 in ["bloque", "parade"], "épée + torche : clic droit = garde, coup de face %s" % g1)
	_verif(baisse_max[0] > 0.2 and revenue, "épée + torche : la torche s'abaisse pendant le coup (%.2f m) puis revient (%.3f)" % [baisse_max[0], mains._baisse_torche])
	_ligne("épée + torche", "OK", "OK (%d touche)" % t1, "OK (%s)" % g1, "torche abaissée %.2f m puis revenue" % baisse_max[0])

	# 2. épée + sort (main gauche)
	await _config("épée + sort", "epee", "eclat_glace")
	var ok2: bool = eq.categorie("gauche") == "sort" and eq.categorie("droite") == "arme"
	var t2 := await _attaque()
	var nj: int = magie.journal.size()
	magie.appuyer("gauche")
	magie.relacher("gauche")
	await _sim(0.8)
	var sort_parti := false
	for i in range(nj, magie.journal.size()):
		sort_parti = sort_parti or String(magie.journal[i][1]).begins_with("lance gauche eclat_glace")
	var g2 := await _garde()
	_verif(ok2 and t2 == 1, "épée + sort : équipés, le coup d'épée touche (%d)" % t2)
	_verif(sort_parti, "épée + sort : le sort de la main gauche part")
	_verif(g2 == "" and not eq.clic_droit_garde(), "épée + sort : clic droit = sort, pas de garde (règle regles_mains.json)")
	_ligne("épée + sort", "OK", "OK (épée %d touche, sort lancé)" % t2, "non (clic droit = sort)", "main qui incante (MainSort)")

	# 3. épée + bouclier
	await _config("épée + bouclier", "epee", "bouclier")
	var ok3: bool = eq.categorie("gauche") == "bouclier"
	var t3 := await _attaque()
	var bouclier_vu: bool = magie._bouclier != null and magie._bouclier.visible
	var v0: float = j.vigueur
	var g3 := await _garde()
	var par_bouclier: bool = magie.arme_de_garde(mains.arme).id == "bouclier"
	_verif(ok3 and bouclier_vu, "épée + bouclier : équipés, bouclier affiché au bras gauche")
	_verif(t3 == 1, "épée + bouclier : le coup d'épée touche (%d)" % t3)
	_verif(g3 in ["bloque", "parade"] and par_bouclier, "épée + bouclier : garde au bouclier (%s, réduction %.0f %%)" % [g3, magie.arme_de_garde(mains.arme).reduction_garde * 100.0])
	_ligne("épée + bouclier", "OK", "OK (%d touche)" % t3, "OK (%s, bouclier %.0f %%)" % [g3, magie.arme_de_garde(mains.arme).reduction_garde * 100.0], "bouclier visible, endurance %.1f → %.1f" % [v0, j.vigueur])

	# 4. deux épées : refusé par les règles (pas d'arme en main gauche)
	await _reset()
	magie.equiper("droite", "epee")
	var refus4: String = magie.equiper("gauche", "epee")
	_verif(refus4 != "" and eq.categorie("gauche") != "arme", "deux épées : la main gauche refuse l'épée (« %s »)" % refus4)
	_ligne("deux épées", "KO — refusé (« %s »)" % refus4, "—", "—", "pas de modèle ni de clips pour une épée à gauche")

	# 5. deux sorts
	await _config("deux sorts", "eclat_glace", "jet_flammes")
	var ok5: bool = eq.categorie("droite") == "sort" and eq.categorie("gauche") == "sort" and not mains.arme.est_arme()
	var n5: int = s.mannequin.coups.size()
	mains.entrees.appuyer()   # pas d'épée : le clic ne lance aucun coup fantôme
	await _sim(0.05)
	mains.entrees.relacher()
	await _sim(0.4)
	var fantome: bool = mains.combat.attaque() or s.mannequin.coups.size() != n5
	nj = magie.journal.size()
	magie.appuyer("droite")
	magie.appuyer("gauche")
	await _sim(0.6)
	var deux_actifs: bool = magie.inc["gauche"].active() and (magie.inc["droite"].active() or magie.journal.size() > nj)
	magie.relacher("droite")
	magie.relacher("gauche")
	await _sim(0.6)
	var g5 := await _garde()
	_verif(ok5 and not fantome, "deux sorts : équipés, aucun coup d'épée fantôme")
	_verif(deux_actifs, "deux sorts : les deux mains incantent ensemble")
	_verif(g5 == "", "deux sorts : pas de garde (clic droit = main gauche)")
	_ligne("deux sorts", "OK", "OK (deux mains incantent)", "non (clic droit = sort)", "—")

	# 6. arme à deux mains (pas encore de modèle : l'épée de métal marquée deux_mains)
	var deux := Equipement.EPEE_METAL.duplicate() as DonneesArme
	deux.deux_mains = true
	deux.id = "epee_deux_mains_test"
	await _config("arme à deux mains", deux, "torche")
	var range_2m: bool = eq.categorie("droite") == "vide" and eq.categorie("gauche") == "torche"
	magie.equiper("droite", deux)
	await _sim(0.6)
	var ok6: bool = eq.categorie("droite") == "arme_deux_mains" and eq.categorie("gauche") == "vide" and not mains.torche_sortie
	mains.equipement.basculer_gauche()   # T : la torche ne peut pas sortir avec une arme à deux mains
	await _sim(0.1)
	var t_refusee: bool = not mains.torche_sortie
	var t6 := await _attaque()
	var t6l := await _attaque(true)
	var g6 := await _garde()
	_verif(range_2m, "deux mains : prendre la torche à gauche range l'arme à deux mains")
	_verif(ok6 and t_refusee, "deux mains : main gauche libérée, T ne ressort pas la torche")
	_verif(t6 == 1 and t6l == 1, "deux mains : coups léger et lourd touchent (%d, %d)" % [t6, t6l])
	_verif(g6 in ["bloque", "parade"], "deux mains : clic droit = garde (%s)" % g6)
	_ligne("arme à deux mains", "OK (gauche libérée, T refusé)", "OK (léger %d, lourd %d)" % [t6, t6l], "OK (%s)" % g6, "main gauche vide : pas de pose deux mains sur la poignée (clips à créer)")

	# 7. profils des 5 épées (épée + torche)
	print("-- profils des 5 épées")
	var ref_prep := 0.0
	for id in EPEES:
		var a: DonneesArme = load("res://data/armes/%s.tres" % id)
		await _reset()
		magie.equiper("droite", "epee")
		magie.equiper("gauche", "torche")
		mains.equipement.equiper("droite", a)
		await _sim(0.6)
		mains.entrees.appuyer()
		mains.avancer(DT)
		var prep: float = mains._duree_prep + mains._duree_tenue
		var recup: float = mains._duree_recup
		var v_av: float = j.vigueur
		await _sim(0.04)
		mains.entrees.relacher()
		await _sim(0.7)
		var cout_l: float = v_av - j.vigueur
		var st_l := Statuts.de(s.mannequin, false)
		var statut_l := "" if st_l == null else ",".join(st_l.actifs.keys())
		if st_l != null:
			st_l.actifs.clear()
		var t_l: int = s.mannequin.coups.size()
		var touche_l: bool = t_l > 0
		var v_l: float = j.vigueur
		var tl := await _attaque(true)
		var st_h := Statuts.de(s.mannequin, false)
		var statut_h := "" if st_h == null else ",".join(st_h.actifs.keys())
		var m: Dictionary = mains.anim.marqueurs("coup_a")
		var attendu := float(m["frappe"]) / a.vitesse * a.preparation
		if id == "epee_metal":
			ref_prep = prep
		_verif(absf(prep - attendu) < 1e-3, "%s : préparation du coup A = clip / vitesse × préparation (%.3f s, attendu %.3f)" % [id, prep, attendu])
		_verif(touche_l and tl == 1, "%s : coups léger et lourd touchent" % id)
		var lourd_attendu := a.element if a.element_lourd_seulement else ""
		var leger_attendu := "" if a.element_lourd_seulement else a.element
		_verif(statut_l == leger_attendu and (a.element == "" or statut_h.contains(a.element)), "%s : effet élémentaire léger « %s », lourd « %s » (attendu %s / %s)" % [id, statut_l, statut_h, leger_attendu, a.element])
		print("PROFIL %-16s prep_A %.3f s (×%.2f du métal)  récup %.3f s  endurance léger %.1f  lourd %.1f  statut léger « %s » lourd « %s »" % [id, prep, prep / maxf(ref_prep, 1e-3), recup, cout_l, v_l - j.vigueur, statut_l, statut_h])
	mains.equipement.equiper("droite", Equipement.EPEE_METAL)

	print("== tableau des deux mains")
	for l in _lignes:
		print(l)
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
