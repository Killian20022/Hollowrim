extends SceneTree
## Test sans fenêtre du système de dégâts / gore (branche combat/degats_gore) :
##   godot --headless --path . -s res://outils/test_degats.gd -- --nouvelle
## Décor : scenes/test_degats.tscn en mode --test (pas de pilote). Vérifie : compatibilité sans info (2, 3 et 4 arguments), zones et
## dégâts, posture brisée -> étourdi -> finisher, décapitation (tête détachée en corps rigide, cou replié), squelette décapité,
## mort sans argument (tests existants), signal mort (sauvegarde des morts) et butin à chaque mort, plafonds (traces, plaies),
## option gore désactivé, mannequin, chute + finisher « sol », interruption d'attaque, échelle de temps rendue à 1, dragon (4 args).

const SCENE := preload("res://scenes/test_degats.tscn")
const BUTIN := preload("res://scripts/butin.gd")

var _ok := 0
var _ko := 0
var sc: Node3D
var morts: Array = []

func _init() -> void:
	_tester.call_deferred()

## Rôle du joueur (mains._tenter_finisher) : une cible achevable reçoit le finisher, sinon le coup normal.
func _frapper_ou_achever(c: Node, j: Node3D, degats: float, info: Dictionary) -> String:
	var cat: String = c.finisher_possible(j)
	if cat != "":
		var i := info.duplicate()
		i["origine"] = j.global_position
		return c.subir_finisher(cat, i)
	return c.recevoir_coup(degats, j.global_position, true, info)

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _butins() -> int:
	var n := 0
	for c in sc.get_children():
		if c.get_script() == BUTIN:
			n += 1
	return n

func _draugr(type: String, x: float, ident: String) -> CharacterBody3D:
	var d: CharacterBody3D = sc.creer_draugr(type, Vector3(x, 0.05, 0.5), {"ident": ident})
	d.mort.connect(func(id: String) -> void: morts.append(id))
	await _frames(5)
	d.set_physics_process(false)   # immobile : réactions pilotées par le test
	return d

func _tester() -> void:
	RetourImpact.muet = true
	Sang.niveau_force = 2
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	var j: CharacterBody3D = sc.joueur
	j.global_position = Vector3(0, 0, 3.0)

	# --- A/B. compatibilité : appels sans info (mains.gd, pièges, flèches, tests existants)
	var g := await _draugr("guerrier", -3.0, "t_guerrier")
	var derriere := g.global_position + Vector3(0, 0, -2.0)   # de dos : pas de bouclier
	var v0: float = g.vie
	var r: String = g.recevoir_coup(14.0, derriere, false)
	var d0 := v0 - float(g.vie)
	_verif(r == "touche" and d0 > 11.0 and d0 < 14.5, "sans info (3 args) : touché, %.1f dégâts (mailles -8 %%)" % d0)
	_verif(String(g.combat.dernier_resultat["info"]["zone"]) == "torse", "sans info : zone déduite = torse (%s)" % g.combat.dernier_resultat["info"]["zone"])
	r = g.recevoir_coup(5.0, derriere)
	_verif(r == "touche", "2 args (puissant par défaut faux) : %s" % r)
	# --- C. info complète : la tête prend plus
	var v1: float = g.vie
	r = g.recevoir_coup(14.0, derriere, false, {"zone": "tete", "direction": Vector3.RIGHT, "type": "tranchant", "attaque": "legere"})
	var d1 := v1 - float(g.vie)
	_verif(r == "touche" and d1 > d0, "info zone tête : %.1f dégâts > torse %.1f" % [d1, d0])
	_verif(Plaies.nombre(g.modele) >= 1, "plaie posée sur le corps (%d)" % Plaies.nombre(g.modele))

	# --- D. posture brisée -> étourdi -> finisher disponible
	var n := 0
	while g.combat.etourdi <= 0.0 and n < 10 and g.vivant():
		g.vie = 500.0   # on teste la posture, pas la vie
		g.recevoir_coup(14.0, derriere, false, {"attaque": "legere", "zone": "torse"})
		n += 1
	_verif(g.combat.etourdi > 0.0 and g.etat == g.ETOURDI, "posture brisée après %d coups légers : ÉTOURDI" % n)
	j.global_position = g.global_position + Vector3(0, 0, 1.6)
	var cat: String = g.finisher_possible(j)
	_verif(cat in ["etourdi", "lateral"], "finisher disponible : « %s »" % cat)
	j.global_position = g.global_position + Vector3(0, 0, 6.0)
	_verif(g.finisher_possible(j) == "", "trop loin : pas de finisher")
	j.global_position = g.global_position + Vector3(0, 0, 1.6)

	# --- E. finisher (coup lourd) -> décapitation
	g.vie = 60.0
	var b0 := _butins()
	r = _frapper_ou_achever(g, j, 34.0, {"attaque": "lourde"})
	_verif(r == "tue" and not g.vivant(), "coup lourd sur cible étourdie : finisher, « tue »")
	_verif(morts.has("t_guerrier"), "signal mort émis (sauvegarde des morts) : %s" % str(morts))
	_verif(_butins() == b0 + 1, "butin lâché (finisher)")
	_verif(g.modele.has_meta("decapite"), "décapité")
	var tete: RigidBody3D = g.modele.get_meta("tete_coupee", null)
	var sk: Skeleton3D = tete.get_node_or_null("Skeleton3D") if tete else null
	var mailles := sk.find_children("*", "MeshInstance3D", false, false).size() if sk else 0
	_verif(tete != null and sk != null and mailles >= 2, "tête : corps rigide + %d maillages copiés" % mailles)
	var sq: Skeleton3D = g.modele.find_child("Skeleton3D", true, false)
	_verif(sq.get_child(sq.get_child_count() - 1) is Decapitation.CouTranche or sq.get_node_or_null("CouTranche") != null, "cou replié (modificateur CouTranche)")
	var ct: Node = sq.get_node_or_null("CouTranche")
	var apres_simu := ct != null and ct.get_index() > (sq.get_node("SimulateurRagdoll").get_index() if sq.has_node("SimulateurRagdoll") else -1)
	_verif(apres_simu, "CouTranche après le simulateur du ragdoll")
	var cou: Node3D = sq.get_node_or_null("Coupe")
	await _frames(60)
	var ecart := tete.global_position.distance_to(cou.global_position) if (tete and cou) else 0.0
	_verif(ecart > 0.5, "la tête s'est détachée du cou (%.2f m après 1 s)" % ecart)
	_verif(Sang.nombre_traces(sc) > 0, "traces de sang au sol (%d)" % Sang.nombre_traces(sc))

	# --- F. squelette décapité (os : pas de sang, éclats)
	var s := await _draugr("squelette", 0.0, "t_squelette")
	j.global_position = s.global_position + Vector3(0, 0, 1.6)
	s.combat.briser_posture()
	s._etourdir()
	var tr0 := Sang.nombre_traces(sc)
	r = s.subir_finisher("etourdi", {"origine": j.global_position})
	_verif(r == "tue" and s.modele.has_meta("decapite") and s.modele.get_meta("tete_coupee", null) != null, "squelette : subir_finisher -> crâne détaché")
	_verif(morts.has("t_squelette"), "squelette : signal mort")

	# --- G. mort sans argument (tests existants : test_crypte_mort, test_squelette)
	var m := await _draugr("sbire", 3.0, "t_sbire")
	var b1 := _butins()
	m._mourir()
	_verif(not m.vivant() and morts.has("t_sbire") and _butins() == b1 + 1, "_mourir() sans argument : mort, signal, butin")

	# --- L. chute (coup lourd aux jambes) -> finisher « sol »
	var c := await _draugr("sbire", 6.0, "t_chute")
	c.set_physics_process(true)
	j.global_position = c.global_position + Vector3(0, 0, 1.6)
	r = c.recevoir_coup(34.0, j.global_position, true, {"attaque": "lourde", "zone": "jambes"})
	_verif(c.etat == c.CHUTE, "coup lourd aux jambes : renversé (CHUTE) [%s]" % c.combat.derniere_reaction)
	await _frames(110)
	print("   chute : etat=%d t=%.2f au_sol=%s dist=%.2f duree Death01=%.2f" % [c.etat, c._t, c.combat.au_sol, c.global_position.distance_to(j.global_position), c._duree("Death01")])
	_verif(c.combat.au_sol and c.finisher_possible(j) == "sol", "au sol : finisher « sol » (%s)" % c.finisher_possible(j))
	r = _frapper_ou_achever(c, j, 34.0, {"attaque": "lourde"})
	_verif(r == "tue" and not c.modele.has_meta("decapite"), "coup de grâce au sol : tué, sans décapitation")

	# --- M. interruption d'une attaque
	var a := await _draugr("sbire", 9.0, "t_attaque")
	a.set_physics_process(true)
	a._changer(a.ATTAQUE)
	a._attaque = "Sword_Attack"
	a._coup_donne = false
	a.recevoir_coup(14.0, a.global_position + Vector3(0, 0, -2.0), false, {"attaque": "legere", "zone": "tete"})
	_verif(a.etat == a.TITUBE and a.combat.dernier_resultat.get("interrompt", false), "coup moyen pendant l'armement : attaque interrompue (%s)" % a.combat.derniere_reaction)

	# --- H. plafonds
	for k in 200:
		Sang.trace(sc, Vector3(randf_range(-5, 5), 0.0, randf_range(-1, 3)), Vector3.UP, Vector3.RIGHT, 0.3, Color.RED, "giclure")
	await process_frame
	_verif(Sang.nombre_traces(sc) <= Sang.MAX_TRACES, "plafond des traces : %d <= %d" % [Sang.nombre_traces(sc), Sang.MAX_TRACES])
	var p := await _draugr("guerrier", -6.0, "t_plaies")
	for k in 14:
		p.vie = 500.0
		p.recevoir_coup(14.0, p.global_position + Vector3(0, 0, -2.0), false, {"attaque": "legere", "zone": ["torse", "bras", "jambes"][k % 3]})
	await process_frame
	_verif(Plaies.nombre(p.modele) <= Plaies.MAX_PAR_CORPS and Plaies.nombre(p.modele) >= 3, "plafond des plaies : %d <= %d" % [Plaies.nombre(p.modele), Plaies.MAX_PAR_CORPS])

	# --- I. gore désactivé
	Sang.niveau_force = 0
	var o := await _draugr("guerrier", -9.0, "t_off")
	j.global_position = o.global_position + Vector3(0, 0, 1.6)
	var tr1 := Sang.nombre_traces(sc)
	o.recevoir_coup(14.0, o.global_position + Vector3(0, 0, -2.0), false, {"attaque": "legere"})
	o.combat.briser_posture()
	o._etourdir()
	r = _frapper_ou_achever(o, j, 34.0, {"attaque": "lourde"})
	await _frames(5)
	_verif(r == "tue" and not o.modele.has_meta("decapite") and Plaies.nombre(o.modele) == 0, "gore désactivé : finisher sans décapitation ni plaie")
	_verif(Sang.nombre_traces(sc) <= tr1, "gore désactivé : aucune trace ajoutée")
	Sang.niveau_force = 2

	# --- J. mannequin
	var mq: Node = sc.cibles[0]
	j.global_position = (mq as Node3D).global_position + Vector3(0, 0, 1.6)
	r = mq.recevoir_coup(14.0, j.global_position, false)
	_verif(r == "touche" and mq.total > 0.0 and mq.vivant(), "mannequin : touché sans info, total %.0f, toujours debout" % mq.total)
	mq.combat.briser_posture()
	r = _frapper_ou_achever(mq, j, 34.0, {"attaque": "lourde"})
	_verif(r == "tue" and not mq.tete.visible and mq.vivant(), "mannequin : finisher, tête envolée, mannequin toujours là")

	# --- K. dragon : accepte le 4e argument (contrat épée FPS)
	var dr: Script = load("res://scripts/dragon.gd")
	var nargs := -1
	for meth in dr.get_script_method_list():
		if meth["name"] == "recevoir_coup":
			nargs = (meth["args"] as Array).size()
	_verif(nargs == 4, "dragon.recevoir_coup : 4 paramètres (%d)" % nargs)

	# --- N. échelle de temps rendue à 1 (arrêts sur image cumulés)
	Effets.arret_image(self, 0.05)
	Effets.arret_image(self, 0.12)
	Effets.ralenti(self, 0.3, 0.2)
	await create_timer(1.2, true, false, true).timeout
	_verif(is_equal_approx(Engine.time_scale, 1.0), "échelle de temps revenue à 1 (%.2f)" % Engine.time_scale)

	print("RÉSUMÉ test_degats : %d OK, %d en échec" % [_ok, _ko])
	print("ECHECS : %d" % _ko)
	quit(1 if _ko > 0 else 0)
