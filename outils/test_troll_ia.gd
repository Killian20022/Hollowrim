extends SceneTree
## Test sans fenêtre de l'IA du Troll de givre (scripts/troll_givre_ia.gd, socle EnnemiBase) :
##   godot --headless --path . -s res://outils/test_troll_ia.gd -- --nouvelle --test
## Décor : scenes/test_troll_mage.tscn en mode --test. Vérifie : groupe « ennemis », profil (feu > 1, posture haute), détection,
## attaque réelle sur le joueur factice, parade du balayage (titube, posture), onde au sol mal parée (dégâts à travers la garde) et
## évitée hors du disque, charge (touche, contre un mur : assommé), coups reçus avec et sans info, hyper-armure des coups légers,
## feu (dégâts ×, régénération coupée), régénération, rage à mi-vie, posture brisée -> étourdi -> finisher (décapitation), signal
## mort, butin, mort « sauvegardée » (monde.creer_ennemi : draugrs + quetes.signaler), mort sans finisher.

const SCENE := preload("res://scenes/test_troll_mage.tscn")
const TROLL := preload("res://scripts/troll_givre_ia.gd")
const BUTIN := preload("res://scripts/butin.gd")

var _ok := 0
var _ko := 0
var sc: Node3D
var j: CharacterBody3D
var morts: Array = []

func _init() -> void:
	_tester.call_deferred()

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

func _troll(pos: Vector3, ident: String, options := {}) -> CharacterBody3D:
	options["ident"] = ident
	var t: CharacterBody3D = sc.creer_ennemi(TROLL, pos, options)
	t.mort.connect(func(id: String) -> void: morts.append(id))
	await _frames(3)
	return t

## Place le joueur à `d` m devant le troll (le troll regarde +Z), joueur tourné vers lui.
func _devant(t: Node3D, d: float) -> void:
	j.global_position = t.global_position + t.global_transform.basis.z * d
	j.global_position.y = 0.0
	var v := t.global_position - j.global_position
	j.rotation.y = atan2(-v.x, -v.z)

func _attendre_etat(t: Node, etats: Array, max_frames: int) -> bool:
	for i in max_frames:
		if t.etat in etats:
			return true
		await physics_frame
	return t.etat in etats

func _tester() -> void:
	RetourImpact.muet = true
	Sang.niveau_force = 2
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	j = sc.joueur
	j.global_position = Vector3(0, 0, 18.0)

	# --- A. création
	var t := await _troll(Vector3(0, 0.05, 0), "troll_a")
	_verif(t.is_in_group("ennemis") and t.vivant() and t.vie == 420.0, "troll : groupe ennemis, vivant, %d PV" % t.vie)
	var p: ProfilCible = t.combat.profil
	_verif(p.resistances["feu"] > 1.0 and p.resistances["glace"] < 0.5 and p.posture_max >= 100.0 and p.armure_part < 0.06,
		"profil troll_givre : feu ×%.2f, glace ×%.2f, posture %d, armure %.0f %%" % [p.resistances["feu"], p.resistances["glace"], p.posture_max, p.armure_part * 100])
	_verif(t.anim.has_animation("Troll_Griffes") and t.anim.has_animation("Jump_Start") and t.anim.has_animation("Sprint"), "clips du troll présents (griffes, écrasement, charge)")

	# --- B. détection (à 12 m, en vue)
	t.etat = t.GARDE
	_devant(t, 12.0)
	await _frames(20)
	_verif(t.en_combat(), "détecte le joueur à 12 m (état %d)" % t.etat)

	# --- C. attaque réelle : le joueur à 2,4 m encaisse un coup dans les 6 s
	t._cd_charge = 99.0
	_devant(t, 2.4)
	var c0: int = j.coups_recus
	for i in 360:
		if j.coups_recus > c0:
			break
		_devant(t, 2.4)
		await physics_frame
	_verif(j.coups_recus > c0, "attaque le joueur au contact : %d coup(s), dernière attaque « %s »" % [j.coups_recus - c0, t.derniere_attaque])

	# --- D. parade du balayage : il titube, sa posture s'effondre
	await _attendre_etat(t, [t.TRAQUE], 300)
	_devant(t, 2.4)
	t.combat.posture = p.posture_max
	t._lancer_balayage()
	var t_imp: float = t._t_impact
	_verif(t_imp > 0.9, "balayage télégraphié : armement %.2f s" % t_imp)
	j.garde = "parade"
	await _frames(int(t_imp * 60.0) + 6)
	j.garde = ""
	_verif(t.etat in [t.TITUBE, t.ETOURDI] and t.combat.posture < p.posture_max * 0.6, "balayage paré : le troll titube (état %d), posture %d/%d" % [t.etat, t.combat.posture, p.posture_max])

	# --- E. onde au sol : mal parée dans le disque, sans effet hors du disque
	await _attendre_etat(t, [t.TRAQUE], 200)
	_devant(t, 2.0)
	j.garde = "parade"
	var d0: float = j.degats_recus
	var c1: int = j.coups_recus
	t._lancer_ecrase(t.global_transform.basis.z)
	var alerte_ok: bool = is_instance_valid(t._alerte)
	await _frames(int(t.DUREE_ARMEMENT_ECRASE * 60.0) + 6)
	j.garde = ""
	_verif(alerte_ok, "écrasement télégraphié : disque d'alerte au sol")
	_verif(j.coups_recus > c1 and j.degats_recus - d0 > 15.0 and float(j.dernier_options.get("imparable", 0.0)) > 0.0,
		"onde dans le disque, garde levée : se pare mal (%.0f dégâts à travers la garde)" % (j.degats_recus - d0))
	await _attendre_etat(t, [t.TRAQUE], 200)
	_devant(t, 7.0)
	var c2: int = j.coups_recus
	t._lancer_ecrase(t.global_transform.basis.z)
	await _frames(int(t.DUREE_ARMEMENT_ECRASE * 60.0) + 6)
	_verif(j.coups_recus == c2, "onde évitée hors du disque (aucun coup)")

	# --- F. charge : touche le joueur dans l'axe ; contre un mur, il s'assomme
	await _attendre_etat(t, [t.TRAQUE], 200)
	_devant(t, 8.0)
	var c3: int = j.coups_recus
	t._lancer_charge(t.global_transform.basis.z)
	await _frames(int((t.ANNONCE_CHARGE + 1.2) * 60.0))
	_verif(j.coups_recus > c3, "charge annoncée puis portée : le joueur est percuté")
	await _attendre_etat(t, [t.TRAQUE], 200)
	# mur : le grand mur de l'arène est à z = -22 ; troll à z = -18, charge vers -Z
	t.global_position = Vector3(0, 0.05, -17.0)
	t.rotation.y = PI
	j.global_position = Vector3(12, 0, 10)
	await _frames(2)
	t._lancer_charge(Vector3(0, 0, -1))
	t._t = t.ANNONCE_CHARGE * 0.8     # direction déjà figée (vers le mur)
	var sonne := await _attendre_etat(t, [t.SONNE], int((t.ANNONCE_CHARGE + 1.5) * 60.0))
	_verif(sonne, "charge contre le mur : assommé (SONNE)")

	# --- G. coups reçus sans info / avec info / hyper-armure
	t.queue_free()
	await _frames(2)
	var u := await _troll(Vector3(-6, 0.05, 6), "troll_b")
	u.set_physics_process(false)
	_devant(u, 2.0)
	var derriere: Vector3 = u.global_position - u.global_transform.basis.z * 2.0
	var v0: float = u.vie
	var r: String = u.recevoir_coup(14.0, derriere, false)
	var dt0: float = v0 - u.vie
	_verif(r == "touche" and dt0 > 8.0, "sans info (3 args) : touché, %.1f dégâts" % dt0)
	r = u.recevoir_coup(10.0, derriere)
	_verif(r == "touche", "2 args : %s" % r)
	_verif(Plaies.nombre(u.modele) >= 1, "plaie posée sur le troll (%d)" % Plaies.nombre(u.modele))
	u.etat = u.TRAQUE
	r = u.recevoir_coup(14.0, j.global_position, false, {"attaque": "legere", "zone": "torse", "type": "tranchant"})
	_verif(u.etat != u.TITUBE and u.combat.derniere_reaction == "leger", "hyper-armure : coup léger sans titube (%s)" % u.combat.derniere_reaction)
	var v1: float = u.vie
	u.recevoir_coup(14.0, j.global_position, false, {"attaque": "legere", "zone": "torse", "type": "feu"})
	var dfeu: float = v1 - u.vie
	_verif(dfeu > dt0 * 1.4 and u._brule > 0.0, "feu : %.1f dégâts (tranchant %.1f) et régénération coupée (%.1f s)" % [dfeu, dt0, u._brule])

	# --- H. régénération (5 s sans coup, pas de feu)
	u._brule = 0.0
	u.vie = 300.0
	u._t_sans_coup = 10.0
	u.set_physics_process(true)
	u.etat = u.GARDE
	j.global_position = Vector3(30, 0, 30)
	await _frames(60)
	_verif(u.vie > 304.0, "régénération hors combat : %.1f PV (300 au départ)" % u.vie)
	u._brule = 5.0
	var v2: float = u.vie
	await _frames(30)
	_verif(absf(u.vie - v2) < 0.01, "pas de régénération en brûlant")

	# --- I. rage à mi-vie
	_devant(u, 3.0)
	u.etat = u.TRAQUE
	u.vie = u.vie_max * 0.52
	u.recevoir_coup(14.0, j.global_position, false, {"attaque": "legere", "zone": "torse"})
	await _frames(6)
	_verif(u.rage and u.etat == u.RAGE, "rage à mi-vie (état %d, rage %s)" % [u.etat, u.rage])
	_verif(u.finisher_possible(j) == "", "pas de finisher pendant le rugissement")
	await _attendre_etat(u, [u.TRAQUE], 200)

	# --- J. posture brisée -> étourdi -> finisher (décapitation), signal mort, butin
	u.set_physics_process(false)
	var n := 0
	while u.combat.etourdi <= 0.0 and n < 30:
		u.vie = 400.0
		u.recevoir_coup(34.0, j.global_position, true, {"attaque": "chargee_max", "zone": "torse", "stagger": 42.0})
		n += 1
	_verif(u.combat.etourdi > 0.0 and u.etat == u.ETOURDI, "posture brisée après %d coups chargés : ÉTOURDI" % n)
	_devant(u, 1.8)
	var cat: String = u.finisher_possible(j)
	_verif(cat in ["etourdi", "lateral"], "finisher disponible : « %s »" % cat)
	var b0 := _butins()
	r = u.recevoir_coup(34.0, j.global_position, true, {"attaque": "lourde"})
	_verif(r == "tue" and not u.vivant(), "coup lourd sur troll étourdi : finisher, « tue »")
	_verif(u.modele.has_meta("decapite") and u.modele.get_meta("tete_coupee", null) != null, "troll décapité (tête en corps rigide)")
	_verif(morts.has("troll_b"), "signal mort émis : %s" % str(morts))
	_verif(_butins() == b0 + 1, "butin lâché")
	var bt: Node = null
	for ch in sc.get_children():
		if ch.get_script() == BUTIN:
			bt = ch
	_verif(bt != null and bt.contenu.has("fourrure_troll"), "butin du troll : %s" % (str(bt.contenu) if bt else "?"))
	await _frames(40)
	_verif(u._ragdoll != null and u._ragdoll.actif, "ragdoll actif sur le cadavre")

	# --- K. mort sans finisher (coups ordinaires), sans info
	var w := await _troll(Vector3(6, 0.05, 6), "troll_c", {"vie_imposee": 30.0})
	w.set_physics_process(false)
	_devant(w, 2.0)
	var b1 := _butins()
	r = w.recevoir_coup(40.0, j.global_position, false)
	_verif(r == "tue" and not w.vivant() and morts.has("troll_c") and _butins() == b1 + 1, "mort ordinaire sans info : tué, signal, butin")

	# --- L. mort sauvegardée : monde.creer_ennemi enregistre l'ennemi (draugrs) et relaie « tue:<ident> » aux quêtes
	var MONDE: Script = load("res://scripts/monde.gd")
	var m: Node3D = Node3D.new()
	m.set_script(MONDE)
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar vus := {}\nfunc signaler(e: String) -> void:\n\tvus[e] = true\n"
	gs.reload()
	var q := Node.new()
	q.set_script(gs)
	m.set("quetes", q)
	m.set("joueur", j)
	var e: CharacterBody3D = m.creer_ennemi(TROLL, Vector3(0, 0, 0), 0.0, {"ident": "troll_sauve"})
	var enreg: bool = (m.get("draugrs") as Dictionary).has("troll_sauve")
	e.mort.emit("troll_sauve")
	_verif(enreg and q.vus.has("tue:troll_sauve"), "monde.creer_ennemi : enregistré dans draugrs (draugrs_morts) et « tue:troll_sauve » signalé aux quêtes")
	m.free()
	q.free()

	print("RÉSUMÉ test_troll_ia : %d OK, %d en échec" % [_ok, _ko])
	print("ECHECS : %d" % _ko)
	quit(1 if _ko > 0 else 0)
