extends SceneTree
## Test sans fenêtre des SORTS DE L'ESPRIT (scripts/magie/sorts_esprit.gd ; docs/MAGIE.md, « Sorts de l'esprit ») :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_sorts_esprit.gd -- --nouvelle
## Répulsion (projette, coût selon la charge, choc contre un mur, objet projeté), Lévitation d'ennemi (coût squelette < draugr <
## troll, soulevé, drain, lancer qui percute un autre ennemi, chute à mana 0, chef qui refuse, troll qui brise l'emprise),
## Attraction (aspire ennemi et objet, coût fixe + supplément, relâche tout), IA rendue après le vol (le draugr se relève).

const SCENE := preload("res://scenes/test_magie.tscn")
const TROLL := preload("res://scripts/troll_givre_ia.gd")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var es: SortsEsprit

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in maxi(1, roundi(t / DT)):
		mains.avancer(DT)
		await physics_frame

func _viser_point(c: Vector3) -> void:
	for k in 3:
		var o: Vector3 = j.camera.global_position
		var d := c - o
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
	es.tout_lacher()
	es.journal.clear()
	es.dernier_refus = ""
	es._refus_t.clear()
	magie.recharges.clear()
	magie.journal.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	await _sim(0.4)

## Ennemi de draugr.gd (IA coupée : il subit), ou troll.
func _draugr(p: Vector3, type := "guerrier", boss := "") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.boss = boss
	d.joueur = j
	d.hud = s.hud
	d.ident = "es_%s_%d" % [type, randi() % 100000]
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	return d

func _troll(p: Vector3) -> CharacterBody3D:
	var t := CharacterBody3D.new()
	t.set_script(TROLL)
	t.set("joueur", j)
	t.position = p
	s.add_child(t)
	t.set_physics_process(false)
	return t

## En vol (cinématique, ou ragdoll de projection : RagdollEsprit) ; vitesse du vol ; libre = rendu à son IA (ni vol, ni ragdoll, ni relevé).
func _en_vol(e: Node) -> bool:
	if es.vols.has(e.get_instance_id()):
		return String(es.vols[e.get_instance_id()]["mode"]) == "vol"
	return es.rag != null and es.rag.en_vol(e)

func _vitesse(e: Node) -> float:
	if es.vols.has(e.get_instance_id()):
		return (es.vols[e.get_instance_id()]["v"] as Vector3).length()
	if es.rag != null and es.rag.en_vol(e):
		return (es.rag._centre_masse(es.rag.corps[e.get_instance_id()]["rd"])[1] as Vector3).length()
	return 0.0

func _libre(e: Node) -> bool:
	return not es.vols.has(e.get_instance_id()) and not (es.rag != null and es.rag.contient(e)) and e.is_physics_processing()

## Hauteur des pieds (racine ; en ragdoll : centre du corps − 1,1 m, comme Elements._centre).
func _hauteur(e: Node3D) -> float:
	return Elements._centre(e).y - 1.1

func _attendre_libre(e: Node, max_s: float) -> void:
	var t := 0.0
	while t < max_s and is_instance_valid(e) and SortsEsprit.vivant(e) and not _libre(e):
		await _sim(0.1)
		t += 0.1
	if is_instance_valid(e) and SortsEsprit.vivant(e) and not _libre(e):
		print("   PAS LIBRE %s : vols=%s ragdoll=%s process=%s état=%s" % [e.name, es.vols.has(e.get_instance_id()), es.rag.phase(e) if es.rag != null else "-", e.is_physics_processing(), _etat_nom(e)])

func _etat_nom(e: Node) -> String:
	var cst: Dictionary = e.get_script().get_script_constant_map()
	for k in cst:
		if cst[k] is int and int(cst[k]) == int(e.get("etat")) and k in ["TRAQUE", "ATTAQUE", "CHUTE", "TITUBE", "GARDE", "SONNE", "ETOURDI", "DORT", "REVEIL", "PATROUILLE", "VISE"]:
			return k
	return str(e.get("etat"))

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	es = magie.esprit
	_verif(SortsEsprit.actif and es != null, "sorts de l'esprit installés (MainSort.esprit)")
	for id in SortsEsprit.IDS:
		var sd := magie.eq.sort_par_id(id)
		_verif(sd != null and SortsEsprit.est_sort(sd) and sd.ecole == "esprit" and magie.eq.sorts_connus.has(id), "sort « %s » : école esprit, connu" % id)
	_verif(magie.eq.sort_par_id("repulsion").se_charge() and magie.eq.sort_par_id("levitation").canalise(), "Répulsion à charge, Lévitation canalisée")
	magie.equiper("droite", "epee")
	magie.raccourci_sort_gauche("repulsion")
	_verif(String(magie.eq.mains["gauche"].get("id")) == "repulsion", "touche G : Répulsion à gauche")
	magie.raccourci_sort_gauche("repulsion")
	_verif(String(magie.eq.mains["gauche"].get("id")) != "repulsion", "touche G : rend la main d'avant")
	await _repulsion()
	await _couts()
	await _levitation()
	await _chefs()
	await _mana_zero()
	await _attraction()
	await _ia_libre()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ répulsion

## Lance la répulsion depuis (0,0,1) vers le mur (-X) en maintenant `tenue` s ; renvoie le mana payé.
func _onde(tenue: float) -> float:
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(tenue)
	magie.relacher("gauche")
	await _sim(0.3 if tenue < 0.3 else 0.05)   # au tap, le sort part à la fin de l'incantation (0,12 s)
	return m0 - float(j.mana)

func _repulsion() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	var sd := magie.eq.sort_par_id("repulsion")
	s.placer_joueur(Vector3(0, 0, 1.0), 90.0)
	# tap : petite onde
	var d1 := _draugr(Vector3(-1.4, 0.0, 1.0), "squelette")
	await _sim(0.6)
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	var c_tap := await _onde(0.05)
	var v_tap := 0.0
	for k in 40:
		await _sim(DT)
		if _en_vol(d1):
			v_tap = maxf(v_tap, _vitesse(d1))
	_verif(absf(c_tap - LanceurSorts.cout(sd, 0.0)) < 1.5, "Répulsion au tap : %.1f de mana (attendu %.1f)" % [c_tap, LanceurSorts.cout(sd, 0.0)])
	d1.queue_free()
	await _reset()
	# pleine charge : le draugr est projeté contre le mur, une chaise aussi
	magie.equiper("gauche", "repulsion")
	var d2 := _draugr(Vector3(-1.4, 0.0, 1.0), "squelette")
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(), Vector3(-1.2, 0.0, 1.9)))
	await _sim(0.6)
	await _viser_point(Vector3(-3.0, 1.0, 1.0))
	var p2 := d2.global_position
	var vie0: float = d2.vie
	var c_plein := await _onde(1.5)
	var envol := false
	var y_max := p2.y
	var v_plein := 0.0
	for k in 50:
		await _sim(DT)
		if _en_vol(d2):
			envol = true
			v_plein = maxf(v_plein, _vitesse(d2))
		y_max = maxf(y_max, _hauteur(d2))
	await _sim(1.0)
	_verif(absf(c_plein - LanceurSorts.cout(sd, 1.0)) < 1.5 and c_plein > c_tap * 2.0, "coût selon la charge : %.1f pleine charge contre %.1f au tap" % [c_plein, c_tap])
	_verif(envol and y_max > p2.y + 0.3, "le squelette est projeté (en l'air : +%.2f m)" % (y_max - p2.y))
	_verif(v_plein > v_tap * 1.5, "plus fort chargée : projeté à %.1f m/s contre %.1f m/s au tap" % [v_plein, v_tap])
	var chocs := es.journal.filter(func(x): return String(x[1]).begins_with("choc"))
	_verif(not chocs.is_empty() and d2.vie < vie0, "choc contre le mur : %s ; %.0f -> %.0f PV" % [chocs[0][1] if not chocs.is_empty() else "-", vie0, d2.vie])
	_verif(chaise.global_position.distance_to(Vector3(-1.2, 0.0, 1.9)) > 0.6, "la chaise est projetée (%.2f m)" % chaise.global_position.distance_to(Vector3(-1.2, 0.0, 1.9)))
	await _attendre_libre(d2, 5.0)
	_verif(_libre(d2), "le squelette est rendu à son IA après l'atterrissage (et le relevé)")
	d2.queue_free()
	chaise.queue_free()

# ------------------------------------------------------------------ lévitation : coûts

func _couts() -> void:
	await _reset()
	var sd := magie.eq.sort_par_id("levitation")
	var sq := _draugr(Vector3(20, 0, 20), "squelette")
	var dr := _draugr(Vector3(22, 0, 20), "sbire")
	var gu := _draugr(Vector3(24, 0, 20), "guerrier")
	var tr := _troll(Vector3(26, 0, 20))
	await _sim(0.5)
	var lignes := []
	var prec := -1.0
	var croissant := true
	for e in [sq, dr, gu, tr]:
		var p := SortsEsprit.puissance(e)
		var c := SortsEsprit.cout_levitation(sd, p)
		var dd := SortsEsprit.drain_levitation(sd, p)
		lignes.append("%s P=%.2f saisie %.1f drain %.1f/s emprise %s" % [String(e.get("nom_affiche")), p, c, dd, "illimitée" if SortsEsprit.duree_emprise(p) == INF else "%.1f s" % SortsEsprit.duree_emprise(p)])
		if c <= prec:
			croissant = false
		prec = c
	for l in lignes:
		print("   COUT ", l)
	_verif(croissant, "coût de la lévitation : squelette < draugr < guerrier < troll")
	_verif(SortsEsprit.cout_levitation(sd, SortsEsprit.puissance(tr)) > 3.0 * SortsEsprit.cout_levitation(sd, SortsEsprit.puissance(sq)), "troll : plus de 3 fois le prix d'un squelette")
	for e in [sq, dr, gu, tr]:
		e.queue_free()

# ------------------------------------------------------------------ lévitation : soulever, drain, lancer

func _levitation() -> void:
	await _reset()
	magie.equiper("gauche", "levitation")
	var sd := magie.eq.sort_par_id("levitation")
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var sq := _draugr(Vector3(0.0, 0.0, 1.2), "squelette")
	var cible := _draugr(Vector3(-2.6, 0.0, -1.5), "guerrier")
	await _sim(0.6)
	await _viser_point(Elements._centre(sq) + Vector3(0.3, 0.0, 0.0))
	await _sim(0.2)
	_verif(es.visee["gauche"] == sq, "visée aidée : le squelette est pris à côté du réticule")
	var y0 := sq.global_position.y
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(0.3)
	_verif(es.tient("gauche") and es.ennemi_tenu("gauche") == sq, "maintenir : le squelette est soulevé")
	var p := SortsEsprit.puissance(sq)
	var paye: float = m0 - float(j.mana)
	var att := SortsEsprit.cout_levitation(sd, p)
	_verif(paye >= att * 0.95 and paye <= att + 4.0, "emprise payée : %.1f (attendu %.1f + drain)" % [paye, att])
	await _sim(0.8)
	_verif(sq.global_position.y > y0 + 0.35, "il lévite : +%.2f m" % (sq.global_position.y - y0))
	_verif(not sq.is_physics_processing(), "son IA est suspendue pendant l'emprise")
	var m1: float = j.mana
	await _sim(1.0)
	var drain: float = m1 - float(j.mana)
	var dd := SortsEsprit.drain_levitation(sd, p)
	_verif(absf(drain - dd) < dd * 0.25, "drain continu : %.1f /s (attendu %.1f)" % [drain, dd])
	# lancer sur le guerrier : les deux encaissent
	await _viser_point(Elements._centre(cible) + Vector3(0.3, 0.0, 0.0))
	await _sim(0.3)
	var v_sq: float = sq.vie
	var v_ci: float = cible.vie
	magie.relacher("gauche")
	await _sim(0.05)
	_verif(not es.tient("gauche") and _en_vol(sq), "relâcher : il est projeté")
	_verif(String(magie.gestes._etat["gauche"]["geste"]) == "lance", "geste capturé « lance » au relâchement")
	for k in 120:
		await _sim(DT)
		if cible.vie < v_ci:
			break
	_verif(cible.vie < v_ci and sq.vie < v_sq, "projeté sur le guerrier : guerrier %.0f -> %.0f, squelette %.0f -> %.0f" % [v_ci, cible.vie, v_sq, sq.vie])
	await _attendre_libre(sq, 5.0)
	await _attendre_libre(cible, 5.0)
	_verif(es.vols.is_empty() and (not SortsEsprit.vivant(sq) or _libre(sq)) and (not SortsEsprit.vivant(cible) or _libre(cible)), "tous deux rendus à leur IA")
	sq.queue_free()
	cible.queue_free()

# ------------------------------------------------------------------ chefs, troll

func _chefs() -> void:
	await _reset()
	magie.equiper("gauche", "levitation")
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var chef := _draugr(Vector3(0.0, 0.0, 1.0), "guerrier", "jarl")
	await _sim(0.6)
	await _viser_point(Elements._centre(chef))
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(0.6)
	_verif(not es.tient("gauche") and es.dernier_refus == "Trop puissant.", "un chef résiste : « %s »" % es.dernier_refus)
	_verif(m0 - float(j.mana) < 3.0, "refus sans mana dépensé (%.1f)" % (m0 - float(j.mana)))
	magie.relacher("gauche")
	chef.queue_free()
	await _reset()
	magie.equiper("gauche", "levitation")
	var tr := _troll(Vector3(0.0, 0.0, 0.5))
	await _sim(0.8)
	await _viser_point(Elements._centre(tr))
	m0 = j.mana
	magie.appuyer("gauche")
	await _sim(0.3)
	var pris := es.tient("gauche")
	var paye: float = m0 - float(j.mana)
	await _sim(1.5)
	_verif(pris and paye > 80.0, "le troll se soulève, mais coûte %.0f de mana" % paye)
	_verif(not es.tient("gauche") and String(magie.refus["gauche"]) in ["Il brise l'emprise !", "Mana épuisé."], "il retombe vite : « %s »" % magie.refus["gauche"])
	magie.relacher("gauche")
	await _sim(2.0)
	_verif(not es.vols.has(tr.get_instance_id()) and tr.is_physics_processing(), "le troll est rendu à son IA (%s)" % _etat_nom(tr))
	tr.queue_free()

# ------------------------------------------------------------------ chute à mana 0

func _mana_zero() -> void:
	await _reset()
	magie.equiper("gauche", "levitation")
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var d := _draugr(Vector3(0.0, 0.0, 1.0), "sbire")
	await _sim(0.6)
	await _viser_point(Elements._centre(d))
	var sol := d.global_position.y
	magie.appuyer("gauche")
	await _sim(1.0)
	_verif(es.tient("gauche") and d.global_position.y > sol + 0.3, "draugr soulevé (+%.2f m)" % (d.global_position.y - sol))
	j.mana = 1.0
	await _sim(0.4)
	_verif(not es.tient("gauche") and es.dernier_refus == "" and magie.refus["gauche"] == "Mana épuisé.", "mana à 0 : l'emprise lâche (« %s »)" % magie.refus["gauche"])
	await _sim(1.6)
	_verif(absf(_hauteur(d) - sol) < 0.25 and not es.vols.has(d.get_instance_id()), "il retombe au sol (%.2f m)" % (_hauteur(d) - sol))
	_verif((d.is_physics_processing() or (es.rag != null and es.rag.contient(d))) and _etat_nom(d) == "CHUTE", "à terre (ragdoll / relevé), IA rendue ensuite (%s)" % _etat_nom(d))
	magie.relacher("gauche")
	d.queue_free()

# ------------------------------------------------------------------ attraction

func _attraction() -> void:
	await _reset()
	magie.equiper("gauche", "attraction")
	var sd := magie.eq.sort_par_id("attraction")
	s.placer_joueur(Vector3(0, 0, 5.0), 0.0)
	var d := _draugr(Vector3(2.0, 0.0, -0.5), "squelette")
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(), Vector3(-1.8, 0.0, 0.0)))
	await _sim(0.6)
	var centre_vise := Vector3(0.0, 0.0, -0.3)
	await _viser_point(centre_vise)
	var dist_d0 := Vector2(d.global_position.x, d.global_position.z + 0.3).length()
	var dist_c0 := Vector2(chaise.global_position.x, chaise.global_position.z + 0.3).length()
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(0.1)
	magie.relacher("gauche")
	await _sim(1.8)
	_verif(not es.vortex.is_empty() and String(es.vortex[0]["phase"]) == "actif", "le point s'est ouvert en vortex")
	var centre: Vector3 = es.vortex[0]["pos"] if not es.vortex.is_empty() else centre_vise
	var dist_d1 := Vector2(d.global_position.x - centre.x, d.global_position.z - centre.z).length()
	var dist_c1 := Vector2(chaise.global_position.x - centre.x, chaise.global_position.z - centre.z).length()
	_verif(es.vols.has(d.get_instance_id()) and String(es.vols[d.get_instance_id()]["mode"]) == "attire" and dist_d1 < dist_d0 - 0.4, "le squelette est aspiré : %.2f -> %.2f m du centre" % [dist_d0, dist_d1])
	_verif(dist_c1 < dist_c0 - 0.4, "la chaise est aspirée : %.2f -> %.2f m" % [dist_c0, dist_c1])
	var paye: float = m0 - float(j.mana)
	var att := sd.cout + SortsEsprit.supplement_attraction(sd, SortsEsprit.puissance(d))
	_verif(absf(paye - att) < 1.5, "coût fixe + supplément : %.1f (attendu %.1f)" % [paye, att])
	for k in 150:
		if es.vortex.is_empty():
			break
		await _sim(DT)
	_verif(es.vortex.is_empty() and not es.journal.filter(func(x): return String(x[1]).begins_with("attraction relâchée")).is_empty(), "le vortex relâche tout")
	var v_max := chaise.linear_velocity.length()
	for k in 10:
		await _sim(DT)
		v_max = maxf(v_max, chaise.linear_velocity.length())
	_verif(v_max > 5.0, "la chaise est projetée au relâchement (%.1f m/s)" % v_max)
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	if magie.tk != null:
		for x in magie.tk.journal.slice(-10):
			print("   TK %.2f %s" % [x[0], x[1]])
	var proj := not es.journal.filter(func(x): return String(x[1]).begins_with("attraction relâchée : 1 ennemis")).is_empty()
	_verif(proj and (_en_vol(d) or not SortsEsprit.vivant(d)), "le squelette est projeté au relâchement (%s)" % ("en vol" if SortsEsprit.vivant(d) else "tué par le choc"))
	await _attendre_libre(d, 5.5)
	_verif(not SortsEsprit.vivant(d) or _libre(d), "le squelette est rendu à son IA")
	d.queue_free()
	chaise.queue_free()

# ------------------------------------------------------------------ IA active : il se relève

func _ia_libre() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var d := _draugr(Vector3(2.5, 0.0, -2.5), "sbire")   # à 7 m (hors de la ligne du mannequin), il court sur le joueur pendant la charge
	d.set_physics_process(true)
	d.call("_changer", d.get_script().get_script_constant_map()["TRAQUE"])
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)   # ce qu'on teste ici : l'IA après le vol (un coup reçu couperait la charge)
	await _viser_point(Elements._centre(d))
	await _onde(1.45)
	var vu_chute := false
	for k in 30:
		await _sim(DT)
		vu_chute = vu_chute or _etat_nom(d) == "CHUTE"
	var etats := []
	for k in 10:
		await _sim(0.5)
		etats.append(_etat_nom(d))
	print("   états après la projection : ", etats)
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	print("   magie : ", magie.journal.slice(-8))
	_verif(vu_chute and d.is_physics_processing() and es.vols.is_empty(), "projeté avec son IA active : à terre (CHUTE), IA rendue (%s)" % str(etats))
	_verif(String(etats[-1]) in ["TRAQUE", "ATTAQUE", "TITUBE", "VISE"], "il s'est relevé et reprend le combat (%s)" % etats[-1])
	d.queue_free()
