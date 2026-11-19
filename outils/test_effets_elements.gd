extends SceneTree
## Test sans fenêtre de l'EFFET PASSIF D'ÉLÉMENT des lames (EffetElementLame, docs/EFFETS_ELEMENTS.md) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_effets_elements.gd -- --nouvelle
## - arme à élément en main : effet sous l'arme FPS (bon élément, mains reliées) et sous l'arme du corps (3e personne) ;
##   l'un ou l'autre visible selon la vue ; arme sans élément : aucun effet ; changement d'arme : l'ancien effet disparaît ;
## - renfort pendant la charge de l'attaque puissante ;
## - arme au sol / au râtelier (ObjetMonde) et arme d'ennemi (ArmesEnnemis, hache de Kolbeinn) : effet présent ;
## - budget : particules par arme bornées, matériaux partagés entre deux armes du même élément, aucune lumière ajoutée ;
## - interrupteur EffetElementLame.actif (= --sans-effet-element) : plus aucun effet posé.

const SCENE := preload("res://scenes/test_combat.tscn")
const MAX_PARTICULES_ARME := 64

var s: Node3D
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _frames(n: int) -> void:
	for k in n:
		await process_frame

func _effet(n: Node) -> EffetElementLame:
	if n == null or not is_instance_valid(n):
		return null
	return n.get_node_or_null("EffetElement") as EffetElementLame

func _particules(e: EffetElementLame) -> int:
	var t := 0
	for c in e.get_children():
		if c is GPUParticles3D:
			t += (c as GPUParticles3D).amount
	return t

func _lumieres(n: Node) -> int:
	return n.find_children("*", "Light3D", true, false).size()

func _lancer() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _frames(20)
	var j: CharacterBody3D = s.joueur
	var mains: Node3D = j.mains
	var tps = j.corps.get("mains_tps")
	# 1. épée de rubis (feu) en main
	mains.equipement.equiper("droite", load("res://data/armes/epee_rubis.tres"))
	await _frames(10)
	var e := _effet(mains.get("_modele_arme_d"))
	ok(e != null and e.type == "feu", "épée de rubis : effet de feu sous l'arme FPS")
	ok(e != null and e.mains == mains, "effet FPS relié aux mains (renfort de charge)")
	ok(e != null and _particules(e) > 0 and _particules(e) <= MAX_PARTICULES_ARME, "particules par arme bornées (%d <= %d)" % [_particules(e) if e else -1, MAX_PARTICULES_ARME])
	ok(e != null and _lumieres(e) == 0, "aucune lumière dynamique dans l'effet")
	ok(e != null and e.is_visible_in_tree(), "1re personne : effet FPS visible")
	print("ECHELLE effet FPS : ", e.global_basis.get_scale() if e else Vector3.ZERO)
	var et: EffetElementLame = tps.get("_effet_d") if tps != null else null
	ok(et != null and et.type == "feu", "arme du corps (3e personne) : effet de feu")
	ok(et != null and not et.is_visible_in_tree(), "1re personne : effet de l'arme du corps caché (ombre seule)")
	j.basculer_vue(true)
	await _frames(5)
	ok(et != null and et.is_visible_in_tree(), "3e personne : effet de l'arme du corps visible")
	ok(e != null and not e.is_visible_in_tree(), "3e personne : effet FPS caché (mains cachées)")
	j.basculer_vue(false)
	await _frames(5)
	# 2. renfort pendant la charge
	var r0 := e.renfort
	mains.entrees.appuyer()
	await _frames(70)
	ok(e.renfort > r0 + 0.3, "charge de l'attaque puissante : renfort de l'effet (%.2f -> %.2f)" % [r0, e.renfort])
	mains.entrees.relacher()
	await _frames(120)
	# 3. même élément, autre arme : matériaux partagés ; arme sans élément : rien
	var pm_rubis: Material = (e.get_child(0) as GPUParticles3D).material_override
	mains.equipement.equiper("droite", load("res://data/armes/epee_hrafn.tres"))
	await _frames(10)
	var e2 := _effet(mains.get("_modele_arme_d"))
	ok(e2 != null and (e2.get_child(0) as GPUParticles3D).material_override == pm_rubis, "deux armes de feu : matériau de dessin partagé")
	mains.equipement.equiper("droite", load("res://data/armes/epee_metal.tres"))
	await _frames(10)
	ok(_effet(mains.get("_modele_arme_d")) == null, "épée d'acier (sans élément) : aucun effet")
	ok(tps == null or tps.get("_effet_d") == null, "arme du corps sans élément : aucun effet")
	for id in ["epee_verre", "epee_obsidienne", "hache_kolbeinn"]:
		var d: DonneesArme = load("res://data/armes/%s.tres" % id)
		mains.equipement.equiper("droite", d)
		await _frames(10)
		var ei := _effet(mains.get("_modele_arme_d"))
		ok(ei != null and ei.type == d.element_type, "%s : effet « %s » en main" % [id, d.element_type])
		if ei != null:
			ok(ei.garde.distance_to(ei.pointe) > 0.1, "%s : segment tranchant lu (%.2f m)" % [id, ei.garde.distance_to(ei.pointe)])
	# électricité (aucune arme du jeu ne la porte encore) : arme d'essai
	var de := (load("res://data/armes/epee_metal.tres") as DonneesArme).duplicate() as DonneesArme
	de.element_type = "electricite"
	mains.equipement.equiper("droite", de)
	await _frames(30)
	var ee := _effet(mains.get("_modele_arme_d"))
	ok(ee != null and ee.type == "electricite" and ee._arc != null, "électricité : étincelles + arcs")
	# 4. au sol, au râtelier
	for pose in ["sol", "ratelier"]:
		var v := ObjetMonde.visuel("epee_rubis", pose, 2)
		s.add_child(v)
		await _frames(3)
		var trouve := v.find_children("EffetElement", "", true, false)
		ok(trouve.size() == 1 and (trouve[0] as EffetElementLame).type == "feu", "épée de rubis « %s » : effet de feu" % pose)
		v.queue_free()
	var vs := ObjetMonde.visuel("epee_metal", "sol", 2)
	s.add_child(vs)
	await _frames(2)
	ok(vs.find_children("EffetElement", "", true, false).is_empty(), "épée d'acier au sol : aucun effet")
	vs.queue_free()
	# 5. arme d'ennemi (hache de Kolbeinn, glace) et arme ordinaire
	var hache := ArmesEnnemis.instancier("hache_kolbeinn")
	var dk := ArmesEnnemis.donnees_arme("hache_kolbeinn")
	ok(dk != null and dk.element_type == "glace", "hache de Kolbeinn : données d'arme (glace) retrouvées")
	EffetElementLame.poser(hache, dk)
	s.add_child(hache)
	await _frames(2)
	ok(_effet(hache) != null and _effet(hache).type == "glace" and _effet(hache).portee > 0.0, "hache de Kolbeinn (PNJ) : effet de glace, portée bornée")
	hache.queue_free()
	ok(ArmesEnnemis.donnees_arme("hache_guerre") != null and ArmesEnnemis.donnees_arme("hache_guerre").element_type == "", "hache de guerre ordinaire : pas d'élément")
	ok(EffetElementLame.type_de("epee_rubis") == "feu" and EffetElementLame.type_de("epee_soldat") == "", "type_de : rubis = feu, soldat = rien")
	# 6. interrupteur
	EffetElementLame.actif = false
	mains.equipement.equiper("droite", load("res://data/armes/epee_rubis.tres"))
	await _frames(10)
	ok(_effet(mains.get("_modele_arme_d")) == null, "--sans-effet-element : aucun effet posé")
	EffetElementLame.actif = true
	print("RESULTAT test_effets_elements : %d echec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
