extends SceneTree
## Test sans fenêtre de la FURTIVITÉ (docs/COMBAT.md « Furtivité ») dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_furtivite.gd -- --nouvelle
## 1. Accroupi : bascule, vitesse ×0,5, capsule et yeux abaissés, relevé par la course, refus sous un plafond bas.
## 2. Bruit : immobile < accroupi < marche < course ; armure lourde plus bruyante ; ouïe des PNJ (crime) à l'échelle.
## 3. Visibilité : accroupi ×0,5, torche allumée visible (×1,25), nuit sans torche ×0,5 (cycle simulé), torche rangée = 1.
## 4. Détection progressive d'un garde : jauge qui monte (pas de repérage instantané), debout repéré, accroupi à même distance non,
##    de dos plus discret, bruit accroupi < course, le joueur reçoit la jauge (œil du HUD).
## 5. Coup furtif : ×FURTIF de dos OU de face accroupi inaperçu, jamais cumulé (pas de ×FURTIF²) ; debout de face = coup normal.
## 6. Compétence Furtivité qui progresse ; œil du HUD ; action « accroupi » remappable (Touches).
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(n: int) -> void:
	for i in n:
		await physics_frame

## `n` images avec le joueur ramené à l'origine à chaque image (il marche sur place : le décor de test le bloquerait vite).
func _marche(n: int) -> void:
	for i in n:
		await physics_frame
		j.global_position = Vector3(0, j.global_position.y, 0)

func _vitesse_h() -> float:
	return Vector2(j.velocity.x, j.velocity.z).length()

func _garde(distance: float, face: bool) -> CharacterBody3D:
	## Garde immobile à `distance` m devant (z négatif) le joueur placé à l'origine ; `face` : il regarde le joueur, sinon lui tourne le dos.
	var d: CharacterBody3D = s.creer_draugr(Vector3(0, 0, -distance), true)
	d.set_physics_process(true)
	d.set_process(true)
	d.rotation.y = 0.0 if face else PI   # basis.z = +z : regarde vers le joueur (z +)
	d.etat = d.GARDE
	d.origine = d.global_position
	return d

## Secondes (temps simulé) avant que `d` passe en TRAQUE ; -1 si pas en `max_s` s. Le joueur reste à l'origine.
func _delai_reperage(d: CharacterBody3D, max_s: float) -> float:
	var t := 0.0
	while t < max_s:
		await physics_frame
		t += DT
		j.global_position = Vector3(j.global_position.x, j.global_position.y, 0.0) if j.global_position.z != 0.0 else j.global_position
		if d.etat != d.GARDE:
			return t
	return -1.0

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await physics_frame
	s.placer_joueur(Vector3.ZERO, 0.0)

	# --- 1. accroupi
	_verif(not j.accroupi, "debout au départ")
	_verif(InputMap.has_action("accroupi") and Touches.touches_de("accroupi")[0] == KEY_CTRL, "action « accroupi » (Ctrl) dans Touches : remappable")
	Input.action_press("avant")
	await _marche(40)
	var v_debout := _vitesse_h()
	_verif(absf(v_debout - j.VITESSE) < 0.3, "marche debout ≈ VITESSE (%.2f m/s)" % v_debout)
	_verif(j.s_accroupir(true) and j.accroupi, "s'accroupir")
	await _marche(40)
	var v_accr := _vitesse_h()
	_verif(absf(v_accr - j.VITESSE * j.ACCROUPI_VITESSE) < 0.25, "vitesse accroupie ≈ ×%.1f (%.2f m/s)" % [j.ACCROUPI_VITESSE, v_accr])
	_verif(absf(j.tete.position.y - j.ACCROUPI_TETE) < 0.02 and absf(j._capsule.height - j.ACCROUPI_CAPSULE) < 0.02,
		"yeux à %.2f m, capsule %.2f m accroupi" % [j.tete.position.y, j._capsule.height])
	_verif(absf(j.camera.global_position.y - (j.global_position.y + j.ACCROUPI_TETE)) < 0.15, "caméra 1re personne abaissée (%.2f m au-dessus des pieds)" % (j.camera.global_position.y - j.global_position.y))
	j.basculer_vue(true)
	await _pas(10)
	_verif(absf(j.corps.scale.y - j.ACCROUPI_CORPS) < 0.02 and j.camera_tp.camera.current, "3e personne : corps écrasé à ×%.2f, caméra TP active" % j.corps.scale.y)
	j.basculer_vue(false)
	Input.action_press("course")
	await _marche(40)
	_verif(not j.accroupi, "accroupi relevé par la course")
	await _marche(40)
	_verif(absf(_vitesse_h() - j.COURSE) < 0.4, "course ≈ COURSE (%.2f m/s)" % _vitesse_h())
	_verif(absf(j.tete.position.y - 1.62) < 0.02 and absf(j._capsule.height - 1.8) < 0.02, "yeux et capsule redressés")
	Input.action_release("course")
	Input.action_release("avant")
	await _pas(30)
	# plafond bas : on ne peut pas se relever
	j.s_accroupir(true)
	await _pas(15)
	var plafond := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4, 0.2, 4)
	cs.shape = bx
	plafond.add_child(cs)
	plafond.position = Vector3(0, 1.4, 0)
	s.add_child(plafond)
	await _pas(3)
	_verif(not j.s_accroupir(false) and j.accroupi, "plafond à 1,4 m : impossible de se relever")
	plafond.queue_free()
	await _pas(3)
	_verif(j.s_accroupir(false) and not j.accroupi, "plafond ôté : debout")
	await _pas(30)

	# --- 2. bruit
	j.velocity = Vector3.ZERO
	var b_immo := Furtivite.bruit(j)
	j.velocity = Vector3(0, 0, -3.2)
	var b_marche := Furtivite.bruit(j)
	j.accroupi = true
	j.velocity = Vector3(0, 0, -1.6)
	var b_accr := Furtivite.bruit(j)
	j.accroupi = false
	j.est_court = true
	j.velocity = Vector3(0, 0, -6.5)
	var b_course := Furtivite.bruit(j)
	j.est_court = false
	_verif(b_immo < b_accr and b_accr < b_marche and b_marche < b_course, "bruit : immobile %.1f < accroupi %.1f < marche %.1f < course %.1f m" % [b_immo, b_accr, b_marche, b_course])
	j.velocity = Vector3(0, 0, -3.2)
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.emplacements[e] = ""
	j.equipement_corps.emplacements["torse"] = "cuirasse_fer"
	j.equipement_corps.emplacements["tete"] = "casque_fer"
	var b_lourd := Furtivite.bruit(j)
	_verif(b_lourd > b_marche * 1.2, "armure lourde (2 pièces) plus bruyante : %.1f > %.1f m" % [b_lourd, b_marche])
	j.equipement_corps.emplacements["torse"] = ""
	j.equipement_corps.emplacements["tete"] = ""
	_verif(is_equal_approx(Furtivite.ouie(j, 2.5), 2.5), "ouïe des PNJ (R_OUIE 2,5 m) : marche = référence")
	j.accroupi = true
	_verif(Furtivite.ouie(j, 2.5) < 1.2, "ouïe des PNJ accroupi réduite (%.2f m)" % Furtivite.ouie(j, 2.5))
	j.accroupi = false
	j.velocity = Vector3.ZERO

	# --- 3. visibilité
	var torche_sortie: bool = j.mains.torche_sortie
	j.mains.torche_sortie = true
	_verif(is_equal_approx(Furtivite.visibilite(j), Furtivite.VUE_TORCHE), "torche allumée : visible de plus loin (×%.2f)" % Furtivite.visibilite(j))
	j.mains.torche_sortie = false
	_verif(is_equal_approx(Furtivite.visibilite(j), 1.0), "torche rangée, jour : ×1")
	j.accroupi = true
	_verif(is_equal_approx(Furtivite.visibilite(j), Furtivite.VUE_ACCROUPI), "accroupi : ×%.1f" % Furtivite.visibilite(j))
	j.mains.torche_sortie = true
	_verif(is_equal_approx(Furtivite.visibilite(j), Furtivite.VUE_ACCROUPI * Furtivite.VUE_TORCHE), "accroupi + torche : ×%.2f (la flamme se voit)" % Furtivite.visibilite(j))
	j.accroupi = false
	j.mains.torche_sortie = torche_sortie
	# nuit simulée : un faux monde avec cycle.heure, le joueur y est temporairement déplacé
	var script_monde := GDScript.new()
	script_monde.source_code = "extends Node3D\nvar cycle\nvar _sous_terre_actif := false\n"
	script_monde.reload()
	var faux := Node3D.new()
	faux.set_script(script_monde)
	var cycle := RefCounted.new()
	var script_cycle := GDScript.new()
	script_cycle.source_code = "extends RefCounted\nvar heure := 23.0\n"
	script_cycle.reload()
	cycle = script_cycle.new()
	faux.cycle = cycle
	root.add_child(faux)
	var parent := j.get_parent()
	j.reparent(faux, false)
	j.mains.torche_sortie = false
	_verif(Furtivite.est_sombre(j) and is_equal_approx(Furtivite.visibilite(j), Furtivite.VUE_NUIT), "nuit, sans torche : ×%.1f" % Furtivite.visibilite(j))
	j.mains.torche_sortie = true
	_verif(is_equal_approx(Furtivite.visibilite(j), Furtivite.VUE_TORCHE), "nuit + torche : pas de bénéfice de la nuit (×%.2f)" % Furtivite.visibilite(j))
	cycle.heure = 12.0
	j.mains.torche_sortie = false
	_verif(not Furtivite.est_sombre(j), "midi : pas sombre")
	j.reparent(parent, false)
	faux.queue_free()
	j.mains.torche_sortie = torche_sortie
	s.placer_joueur(Vector3.ZERO, 0.0)
	j.mains.torche_sortie = false   # la suite se joue de jour, torche rangée : visibilité 1
	await _pas(5)

	# --- 4. détection progressive (garde à 12 m, portée de vue DETECTION = 17 m)
	var g := _garde(12.0, true)
	await _pas(6)
	_verif(g.etat == g.GARDE and g.vigilance > 0.0 and g.vigilance < 0.5, "debout à 12 m : la jauge monte sans repérage instantané (%.2f)" % g.vigilance)
	_verif(j.detection > 0.0, "le joueur reçoit la jauge (œil du HUD) : %.2f" % j.detection)
	var t_debout: float = await _delai_reperage(g, 4.0)
	_verif(t_debout > 0.3 and t_debout < 3.0, "debout à 12 m : repéré après %.2f s" % t_debout)
	g.queue_free()
	await _pas(3)
	j.accroupi = true
	g = _garde(12.0, true)
	var t_accr: float = await _delai_reperage(g, 4.0)
	_verif(t_accr < 0.0 and g.vigilance < 0.05, "accroupi immobile à 12 m (portée 8,5 m) : jamais repéré en 4 s (jauge %.2f)" % g.vigilance)
	g.queue_free()
	await _pas(3)
	g = _garde(6.0, true)
	j.velocity = Vector3(0, 0, -1.6)
	var t_proche: float = await _delai_reperage(g, 4.0)
	_verif(t_proche > 0.0, "accroupi à 6 m, de face : fini par être repéré (%.2f s)" % t_proche)
	g.queue_free()
	j.accroupi = false
	await _pas(3)
	g = _garde(12.0, false)
	var t_dos: float = await _delai_reperage(g, 4.0)
	_verif(t_dos < 0.0 or t_dos > t_debout, "debout à 12 m mais DANS LE DOS du garde (portée 8,5 m) : plus discret (%.2f s, de face %.2f s)" % [t_dos, t_debout])
	g.queue_free()
	await _pas(3)
	# bruit : garde de dos à 10 m, joueur qui court (bruit 14 m) repéré, accroupi non
	g = _garde(10.0, false)
	Input.action_press("avant")
	Input.action_press("course")
	await _marche(30)
	var v_court: float = g.vigilance
	Input.action_release("course")
	g.queue_free()
	await _pas(3)
	g = _garde(10.0, false)
	j.accroupi = true
	await _marche(30)
	var v_accr2: float = g.vigilance
	Input.action_release("avant")
	_verif(v_court > 0.0 and v_accr2 <= 0.001, "garde de dos à 10 m : la course s'entend (jauge %.2f), accroupi non (%.2f)" % [v_court, v_accr2])
	j.accroupi = false
	g.queue_free()
	await _pas(30)

	# --- 5. coup furtif
	var d := _garde(2.0, true)
	var coup := func(accroupi: bool, de_dos: bool) -> float:
		j.accroupi = accroupi
		d.vie = d.vie_max
		d.etat = d.GARDE
		d.vigilance = 0.0
		var o := Vector3(0, 0, 0) if not de_dos else Vector3(0, 0, -4.0)   # origine du coup : devant (le garde regarde z+) ou derrière
		d.recevoir_coup(10.0, o, false, {})
		var perdu: float = d.vie_max - d.vie
		d.vie = d.vie_max
		return perdu
	var normal: float = coup.call(false, false)
	var accroupi_face: float = coup.call(true, false)
	var dos: float = coup.call(false, true)
	var dos_accroupi: float = coup.call(true, true)
	var f := ReglagesCombat.FURTIF * ReglagesCombat.competence("furtivite")
	_verif(normal > 0.0 and absf(dos / normal - f) < 0.1, "coup dans le dos : ×%.2f (attendu ×%.2f, FURTIF existant)" % [dos / maxf(normal, 0.01), f])
	_verif(absf(accroupi_face / normal - f) < 0.1, "coup de face, accroupi et inaperçu : ×%.2f" % [accroupi_face / maxf(normal, 0.01)])
	_verif(absf(dos_accroupi / normal - f) < 0.1, "dos + accroupi : toujours ×%.2f, JAMAIS cumulé (×%.2f)" % [dos_accroupi / maxf(normal, 0.01), f * f])
	d.vigilance = 0.8
	j.accroupi = true
	d.vie = d.vie_max
	d.etat = d.GARDE
	d.recevoir_coup(10.0, Vector3.ZERO, false, {})
	var repere: float = d.vie_max - d.vie
	_verif(absf(repere / normal - 1.0) < 0.1, "accroupi mais déjà soupçonné (jauge 0,8) : coup normal (×%.2f)" % [repere / maxf(normal, 0.01)])
	j.accroupi = false
	d.queue_free()
	await _pas(3)

	# --- 6. compétence, HUD
	var cle: String = Progression.interne(Progression.canonique("furtivite"))
	var xp0: float = j.competences.experience[cle]
	var niv0: int = j.competences.niveaux[cle]
	j.accroupi = true
	Input.action_press("avant")
	for i in 120:
		j.signaler_vigilance(0.4)
		await physics_frame
	Input.action_release("avant")
	var gain: float = (j.competences.experience[cle] - xp0) + float(j.competences.niveaux[cle] - niv0) * 1000.0
	_verif(gain > 0.3, "accroupi en mouvement près d'un ennemi qui ne voit pas : la Furtivité progresse (+%.2f)" % gain)
	j.accroupi = false
	var hud_furtif := Control.new()
	hud_furtif.set_script(load("res://scripts/hud_furtivite.gd"))
	hud_furtif.joueur = j
	root.add_child(hud_furtif)
	j.accroupi = true
	for i in 20:
		j.signaler_vigilance(0.9)
		await physics_frame
	hud_furtif._process(0.5)
	await _pas(2)   # le dessin réel a lieu dans la boucle (queue_redraw)
	_verif(hud_furtif._alpha > 0.5 and hud_furtif._ouvert > 0.5, "œil du HUD : visible et ouvert à jauge 0,9 (alpha %.2f)" % hud_furtif._alpha)
	hud_furtif.queue_free()
	j.accroupi = false

	print("TEST_FURTIVITE ", "OK" if _ok else "ECHECS")
	quit(0 if _ok else 1)
