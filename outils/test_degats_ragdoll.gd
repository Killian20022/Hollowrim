extends SceneTree
## Test sans fenêtre des DÉGÂTS D'OBJETS lancés sur les ennemis (scripts/magie/degats_objets.gd) et du ragdoll des ennemis lancés
## (budget de dégâts physiques, relevé) :  godot --headless --fixed-fps 60 --path . --script res://outils/test_degats_ragdoll.gd -- --nouvelle
##  1. courbe d'énergie (chope ~rien, caisse grosse blessure, tonneau tue un bandit) et résistance des chefs ;
##  2. objet réel lancé sur un draugr (ImpactsLances.suivre) : dégâts, casse de l'objet (ObjetVivant), ragdoll si le choc est fort ;
##  3. attraction : une caisse tirée dans le dos d'un ennemi (vortex) lui fait des dégâts ;
##  4. ennemi lévité puis lancé contre un mur : dégâts légers à moyens, jamais fatals, ragdoll puis relevé.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var es: SortsEsprit
var rag: RagdollEsprit

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
	rag.journal.clear()
	magie.recharges.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	await _sim(0.4)

func _draugr(p: Vector3, type := "draugr") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "dg_%s_%d" % [type, randi() % 100000]
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	return d

## Objet cassable réel (ObjetVivant en bois) de masse m, posé en `p`, réveillé.
func _objet(p: Vector3, m: float, taille: Vector3) -> ObjetVivant:
	var o := ObjetVivant.new()
	o.ident = "dg_obj_%d" % randi()
	o.genre = "caisse"
	o.mass = m
	o.matiere = "bois"
	o.seuil_casse = 300.0
	o.monter_forme("boite", taille)
	s.add_child(o)
	o.global_position = p
	o.reveiller(true)
	return o

## Lance `o` à la vitesse v vers `cible` (tir tendu : la gravité est compensée, comme le lancer de la télékinésie).
func _lancer(o: RigidBody3D, cible: Vector3, v: float) -> void:
	o.freeze = false
	o.gravity_scale = 0.0
	o.linear_velocity = (cible - o.global_position).normalized() * v
	o.set_meta("lance_par", j)
	ImpactsLances.suivre(o, j, 3.0)

func _vie_perdue(d: Node, vie0: float) -> float:
	return vie0 - maxf(float(d.vie), 0.0)

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
	rag = es.rag if es != null else null
	if rag == null:
		print("ECHEC  ragdoll de projection absent")
		quit(1)
		return
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	await _courbe()
	await _objets_lances()
	await _attraction()
	await _telekinesie_attire()
	await _ennemi_lance()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ 1. courbe

func _courbe() -> void:
	var chope := DegatsObjets.degats(DegatsObjets.energie(0.4, 30.0), null, 0.0)
	var caisse := DegatsObjets.degats(DegatsObjets.energie(18.0, 15.0), null, 0.0)
	var tonneau := DegatsObjets.degats(DegatsObjets.energie(28.0, 13.4), null, 0.0)
	var lent := DegatsObjets.degats(DegatsObjets.energie(28.0, 4.0), null, 0.0)
	print("   courbe : chope %.1f  caisse %.1f  tonneau %.1f  tonneau lent %.1f" % [chope, caisse, tonneau, lent])
	_verif(chope < 6.0, "une chope lancée à 30 m/s ne fait presque rien (%.1f PV)" % chope)
	_verif(caisse > 80.0 and caisse < 135.0, "une caisse lancée fort = grosse blessure (%.0f PV bruts ; ~20 %% de moins une fois l'armure retirée)" % caisse)
	_verif(tonneau >= 125.0, "un tonneau à pleine vitesse tue un bandit de base (%.0f PV bruts)" % tonneau)
	_verif(lent < 15.0, "un tonneau qui roule à 4 m/s fait peu (%.1f PV)" % lent)
	var d := _draugr(Vector3(0, 0, -20), "draugr")
	var chef := _draugr(Vector3(2, 0, -20), "draugr")
	chef.boss = "hrafn"
	var r_chef := DegatsObjets.resistance(chef)
	var r_d := DegatsObjets.resistance(d)
	_verif(r_d > 0.95 and r_chef <= 0.36, "résistance : bandit %.2f, chef %.2f" % [r_d, r_chef])
	d.queue_free()
	chef.queue_free()

# ------------------------------------------------------------------ 2. objets réels lancés

## Un objet de masse m lancé à v sur un ennemi de type `type` : {vie_perdue, vie0, casse, ragdoll}
func _essai(type: String, m: float, taille: Vector3, v: float, boss := "") -> Dictionary:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(0, 0, 3.0), type)
	if boss != "":
		d.boss = boss
	await _sim(0.4)
	var vie0: float = d.vie
	var o := _objet(Vector3(0, 1.0, 8.0), m, taille)
	await _sim(0.1)
	_lancer(o, Elements._centre(d), v)
	var en_ragdoll := false
	var casse := false
	for k in 90:
		await _sim(DT)
		en_ragdoll = en_ragdoll or rag.contient(d)
		if is_instance_valid(o) and o.casse:
			casse = true
		if (casse or d.vie <= 0.0) and k > 10:
			break
	await _sim(0.3)
	var res := {"perdue": _vie_perdue(d, vie0), "vie0": vie0, "casse": casse, "ragdoll": en_ragdoll, "dernier": ImpactsLances.dernier.duplicate()}
	if is_instance_valid(o):
		o.queue_free()
	if is_instance_valid(d):
		d.queue_free()
	return res

func _objets_lances() -> void:
	var r: Dictionary = await _essai("draugr", 0.4, Vector3(0.12, 0.12, 0.12), 30.0)
	print("   chope -> draugr : ", r["perdue"], " PV ; ", r["dernier"].get("issue", "-"))
	_verif(float(r["perdue"]) < 8.0 and not bool(r["ragdoll"]), "chope sur un bandit : %.1f PV, pas de ragdoll" % float(r["perdue"]))
	r = await _essai("draugr", 18.0, Vector3(0.6, 0.5, 0.5), 15.0)
	print("   caisse -> draugr : ", r["perdue"], " PV ; ", r["dernier"].get("issue", "-"))
	_verif(float(r["perdue"]) > 50.0 and float(r["perdue"]) < float(r["vie0"]), "caisse lancée fort sur un bandit : grosse blessure (%.0f / %.0f PV)" % [float(r["perdue"]), float(r["vie0"])])
	_verif(bool(r["casse"]), "la caisse se brise sur l'ennemi (matière bois)")
	_verif(bool(r["ragdoll"]), "le choc de la caisse emporte l'ennemi en ragdoll")
	r = await _essai("draugr", 28.0, Vector3(0.6, 0.85, 0.6), 13.4)
	print("   tonneau -> draugr : ", r["perdue"], " PV ; ", r["dernier"].get("issue", "-"))
	_verif(float(r["perdue"]) >= float(r["vie0"]) - 0.5, "tonneau à pleine vitesse : le bandit meurt (%.0f / %.0f PV)" % [float(r["perdue"]), float(r["vie0"])])
	_verif(bool(r["casse"]), "le tonneau explose sur le bandit")
	r = await _essai("guerrier", 28.0, Vector3(0.6, 0.85, 0.6), 13.4)
	_verif(float(r["perdue"]) > 60.0 and float(r["perdue"]) < float(r["vie0"]), "le même tonneau sur un guerrier (135 PV) : il survit (%.0f / %.0f PV)" % [float(r["perdue"]), float(r["vie0"])])
	r = await _essai("draugr", 28.0, Vector3(0.6, 0.85, 0.6), 13.4, "hrafn")
	_verif(float(r["perdue"]) < 0.4 * float(r["vie0"]), "le même tonneau sur un chef : il résiste (%.0f / %.0f PV)" % [float(r["perdue"]), float(r["vie0"])])
	# le lanceur n'est jamais blessé par ses propres objets
	await _reset()
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var o := _objet(Vector3(0, 1.0, 5.0), 28.0, Vector3(0.6, 0.85, 0.6))
	await _sim(0.1)
	var vie_j: float = j.vie
	_lancer(o, j.camera.global_position, 14.0)
	await _sim(1.0)
	_verif(j.vie >= vie_j - 0.01, "le joueur lanceur ne prend rien de ses propres objets (%.0f -> %.0f)" % [vie_j, j.vie])
	if is_instance_valid(o):
		o.queue_free()

# ------------------------------------------------------------------ 3. attraction : caisse tirée dans le dos

func _attraction() -> void:
	await _reset()
	magie.equiper("gauche", "attraction")
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(0, 0, 3.0), "guerrier")
	d.vie_max = 600.0
	d.vie = 600.0
	var o := _objet(Vector3(0.3, 0.4, 0.0), 18.0, Vector3(0.6, 0.5, 0.5))   # derrière lui (3 m plus loin que lui)
	await _sim(0.5)
	await _viser_point(Elements._centre(d))
	var vie0: float = d.vie
	magie.appuyer("gauche")
	await _sim(0.1)
	magie.relacher("gauche")
	for k in 60:
		await _sim(DT)
		if not es.vortex.is_empty():
			break
	j.mana = 0.0   # il ne peut pas payer l'aspiration : il reste debout au sol (le vortex s'ouvre sur lui), les objets, eux, sont tirés
	var vmax := 0.0
	var casse := false
	var suivi := false
	for k in 150:
		await _sim(DT)
		if is_instance_valid(o):
			vmax = maxf(vmax, o.linear_velocity.length())
			casse = casse or o.casse
			suivi = suivi or o.get_node_or_null("SuiviLancer") != null
	print("   attraction : objet vmax %.1f m/s, ennemi %.0f -> %.0f PV, casse=%s" % [vmax, vie0, d.vie, str(casse)])
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	_verif(vmax >= 6.0, "l'objet est aspiré à plus de 6 m/s (VITESSE_ASPIRE 14) (%.1f)" % vmax)
	# le vortex flotte à hauteur de torse + 1,6 m : l'objet y monte en passant au-dessus d'un ennemi resté au sol ; ses chocs comptent quand même
	_verif(suivi, "l'objet aspiré à vive allure près d'un ennemi est suivi (impacts, dégâts, casse) ; brisé=%s, ennemi %.0f -> %.0f PV" % [str(casse), vie0, d.vie])
	await _sim(2.0)
	if is_instance_valid(d):
		d.queue_free()

# ------------------------------------------------------------------ 3b. télékinésie : objet saisi derrière un ennemi, attiré vers la main

func _telekinesie_attire() -> void:
	await _reset()
	magie.equiper("gauche", "telekinesie")
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(0.52, 0.0, 4.0), "draugr")   # à 52 cm de la ligne de visée : le rayon le frôle, l'objet (larg. 60 cm) l'accroche
	d.vie_max = 600.0
	d.vie = 600.0
	var o := _objet(Vector3(0.0, 0.3, 0.2), 18.0, Vector3(0.6, 0.5, 0.5))   # posé au sol, 3,8 m derrière lui
	o.freeze = true
	for n in get_nodes_in_group("telekinesable"):
		if n != o and n is Node3D and (n as Node3D).global_position.distance_to(o.global_position) < 6.0:
			n.queue_free()   # la scène d'essai pose une masse d'armes à proximité : elle serait saisie à la place
	await _sim(0.5)
	await _viser_point(Telekinesie.centre(o))
	print("   visée : ", magie.tk.viser(j.camera.global_position, -j.camera.global_basis.z, 40.0))
	var vie0: float = d.vie
	magie.appuyer("gauche")
	var vmax := 0.0
	var casse := false
	for k in 150:
		await _sim(DT)
		if is_instance_valid(o):
			vmax = maxf(vmax, o.linear_velocity.length())
			casse = casse or o.casse
		if casse or d.vie < vie0 - 3.0:
			break
	magie.relacher("gauche")
	print("   télékinésie : objet saisi derrière l'ennemi, tenu=%s, vmax %.1f m/s, ennemi %.0f -> %.0f PV, casse=%s" % [str(magie.tk.tient("gauche")), vmax, vie0, d.vie, str(casse)])
	for x in magie.tk.journal:
		print("   TK %.2f %s" % [x[0], x[1]])
	_verif(vmax >= 6.0, "objet attiré vers la main à plus de 6 m/s (%.1f)" % vmax)
	_verif(d.vie < vie0 - 3.0, "objet attiré à travers l'ennemi : il le percute (%.0f -> %.0f PV)" % [vie0, d.vie])
	await _sim(1.0)
	if is_instance_valid(o):
		o.queue_free()
	if is_instance_valid(d):
		d.queue_free()

# ------------------------------------------------------------------ 4. ennemi lévité puis lancé contre un mur

func _ennemi_lance() -> void:
	for type in ["draugr", "squelette"]:
		await _reset()
		magie.equiper("gauche", "levitation")
		s.placer_joueur(Vector3(0, 0, 8.0), 0.0)
		var d := _draugr(Vector3(0.0, 0.0, 4.5), type)
		await _sim(0.4)
		await _viser_point(Elements._centre(d))
		magie.appuyer("gauche")
		var tenu := false
		for k in 70:
			await _sim(DT)
			tenu = tenu or es.tient("gauche")
		var vie0: float = d.vie
		await _viser_point(Vector3(-3.0, 1.0, 1.0))
		magie.relacher("gauche")
		var vu := false
		var t_ia := -1.0
		var t := 0.0
		while t < 6.0:
			await _sim(DT)
			t += DT
			vu = vu or rag.en_vol(d)
			if vu and t_ia < 0.0 and not rag.contient(d) and d.is_physics_processing():
				t_ia = t
		var perdue := _vie_perdue(d, vie0)
		var chocs := es.journal.filter(func(x): return String(x[1]).begins_with("choc"))
		print("   %s lancé : %.0f / %.0f PV perdus ; %s ; relevé %s" % [type, perdue, vie0, str(chocs.map(func(x): return x[1])), str(_releve(d).get("clip", "-"))])
		_verif(tenu and vu, "%s : lévité puis lancé, il part en ragdoll" % type)
		_verif(d.vie > 0.0 and perdue <= 0.55 * float(d.vie_max) + 0.5, "%s : dégâts d'écrasement légers à moyens, jamais fatals (%.0f / %.0f PV)" % [type, perdue, float(d.vie_max)])
		_verif(t_ia > 0.0 and t_ia < 5.0, "%s : relevé animé puis IA reprise (%.2f s après le lancer)" % [type, t_ia])
		if is_instance_valid(d):
			d.queue_free()
	# budget : un choc de plus de 22 m/s contre un mur peut tuer (chute énorme), pas un choc ordinaire
	var f := {"subi": 0.0}
	var dd := _draugr(Vector3(0, 0, -30), "draugr")
	var a := es.degats_vol(f, dd, 80.0, 12.0)
	var b := es.degats_vol(f, dd, 80.0, 12.0)
	var c := es.degats_vol(f, dd, 80.0, 25.0)
	_verif(a + b <= 0.6 * float(dd.vie_max) + 0.01 and c == 80.0, "budget du vol : %.0f + %.0f (<= 60 %% de %.0f) ; choc énorme sans plafond (%.0f)" % [a, b, float(dd.vie_max), c])
	dd.queue_free()

func _releve(e: Node) -> Dictionary:
	for x in rag.journal:
		if x.get("e") == e and x.has("clip"):
			return x
	return {}
