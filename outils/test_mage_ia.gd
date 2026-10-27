extends SceneTree
## Test sans fenêtre de l'IA du Mage nordique (scripts/mage_nordique_ia.gd, socle EnnemiBase) :
##   godot --headless --path . -s res://outils/test_mage_ia.gd -- --nouvelle --test
## Décor : scenes/test_troll_mage.tscn en mode --test. Vérifie : groupe, profil (posture faible), détection, recul quand le joueur
## approche, trait de givre (projectile visible, touche le joueur, dégâts + ralentissement), trait évité d'un pas de côté, sort de
## zone (télégraphié, touche dans le disque, rien hors du disque), téléport quand le joueur colle, interruption du sort par un coup
## léger, coups avec / sans info, chute + finisher « sol », finisher rapide (décapitation), signal mort, butin, mort sauvegardée.

const SCENE := preload("res://scenes/test_troll_mage.tscn")
const MAGE := preload("res://scripts/mage_nordique_ia.gd")
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

func _projectiles() -> Array:
	var l := []
	for c in sc.get_children():
		if c is Projectile and (c as Projectile).genre == "givre":
			l.append(c)
	return l

func _mage(pos: Vector3, ident: String, options := {}) -> CharacterBody3D:
	options["ident"] = ident
	var m: CharacterBody3D = sc.creer_ennemi(MAGE, pos, options)
	m.mort.connect(func(id: String) -> void: morts.append(id))
	await _frames(3)
	return m

func _devant(m: Node3D, d: float, lat := 0.0) -> void:
	j.global_position = m.global_position + m.global_transform.basis.z * d + m.global_transform.basis.x * lat
	j.global_position.y = 0.0
	var v := m.global_position - j.global_position
	j.rotation.y = atan2(-v.x, -v.z)

func _attendre_etat(m: Node, etats: Array, max_frames: int) -> bool:
	for i in max_frames:
		if m.etat in etats:
			return true
		await physics_frame
	return m.etat in etats

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
	var m := await _mage(Vector3(0, 0.05, 2.0), "mage_a")
	_verif(m.is_in_group("ennemis") and m.vivant() and m.vie == 70.0, "mage : groupe ennemis, vivant, %d PV" % m.vie)
	var p: ProfilCible = m.combat.profil
	_verif(p.posture_max <= 25.0 and p.seuil_moyen <= 8.0 and p.resistances["glace"] < 1.0 and p.resistances["feu"] > 1.0, "profil mage_nordique : posture %d, seuil moyen %d, glace ×%.2f, feu ×%.2f" % [p.posture_max, p.seuil_moyen, p.resistances["glace"], p.resistances["feu"]])

	# --- B. détection
	_devant(m, 10.0)
	await _frames(15)
	_verif(m.en_combat(), "détecte le joueur à 10 m (état %d)" % m.etat)

	# --- C. trait de givre : projectile visible qui touche le joueur immobile, ralentissement
	m._recharge = 0.0
	m._cd_zone = 99.0
	m._cd_tp = 99.0
	var c0: int = j.coups_recus
	var vu_proj := false
	var lumiere := false
	for i in 300:
		_devant(m, 9.0)
		var ps := _projectiles()
		if not ps.is_empty():
			vu_proj = true
			lumiere = lumiere or ps[0].find_children("*", "OmniLight3D", true, false).size() > 0
		if j.coups_recus > c0:
			break
		await physics_frame
	_verif(m.tirs >= 1 and vu_proj and lumiere, "trait de givre lancé (%d), projectile visible et lumineux" % m.tirs)
	_verif(j.coups_recus > c0 and j.lenteur > 0.0 and j.lenteur_facteur < 1.0, "trait reçu : touché, ralenti (%.1f s, ×%.2f)" % [j.lenteur, j.lenteur_facteur])

	# --- D. trait évité : un pas de côté de 2,5 m pendant le vol
	await _attendre_etat(m, [m.TRAQUE], 200)
	m._recharge = 0.0
	_devant(m, 10.0)
	var c1: int = j.coups_recus
	var tir0: int = m.tirs
	for i in 240:
		if m.tirs > tir0:
			break
		_devant(m, 10.0)
		await physics_frame
	await _frames(3)
	j.global_position += m.global_transform.basis.x * 2.5
	await _frames(90)
	_verif(m.tirs > tir0 and j.coups_recus == c1, "trait évité d'un pas de côté (aucun coup)")

	# --- E. sort de zone : dans le disque = touché + ralenti ; hors du disque = rien
	await _attendre_etat(m, [m.TRAQUE], 200)
	m._recharge = 99.0
	_devant(m, 8.0)
	j.lenteur = 0.0
	var c2: int = j.coups_recus
	m._lancer_zone()
	var alerte_ok: bool = is_instance_valid(m._alerte)
	await _frames(int(m.ANNONCE_ZONE * 60.0) + 5)
	_verif(alerte_ok and m.zones == 1, "sort de zone télégraphié (disque au sol) puis déclenché")
	_verif(j.coups_recus > c2 and j.lenteur > 1.0, "dans le disque : touché et ralenti (%.1f s)" % j.lenteur)
	await _attendre_etat(m, [m.TRAQUE], 200)
	m._recharge = 99.0
	_devant(m, 8.0)
	var c3: int = j.coups_recus
	m._lancer_zone()
	await _frames(20)
	j.global_position += m.global_transform.basis.x * 4.0
	await _frames(int(m.ANNONCE_ZONE * 60.0))
	_verif(j.coups_recus == c3, "sorti du disque : aucun coup")

	# --- F. garde ses distances : joueur à 4 m -> il recule
	await _attendre_etat(m, [m.TRAQUE], 200)
	m._recharge = 99.0
	m._cd_tp = 99.0
	_devant(m, 4.0)
	var pj := j.global_position
	await _frames(90)
	var dist_apres: float = Vector2(m.global_position.x - pj.x, m.global_position.z - pj.z).length()
	_verif(dist_apres > 4.6, "recule quand le joueur approche : 4,0 m -> %.1f m" % dist_apres)

	# --- G. téléport quand le joueur colle
	m._cd_tp = 0.0
	_devant(m, 1.6)
	var pj2 := j.global_position
	var tp0: int = m.teleports
	await _frames(60)
	var d_tp: float = Vector2(m.global_position.x - pj2.x, m.global_position.z - pj2.z).length()
	_verif(m.teleports > tp0 and d_tp > 6.0, "téléport court quand le joueur colle : réapparu à %.1f m" % d_tp)

	# --- H. interruption : un coup léger pendant l'incantation annule le trait
	await _attendre_etat(m, [m.TRAQUE], 200)
	_devant(m, 6.0)
	m._lancer_trait()
	await _frames(20)
	var tir1: int = m.tirs
	var r: String = m.recevoir_coup(14.0, j.global_position, false, {"attaque": "legere", "zone": "torse"})
	await _frames(70)
	_verif(r == "touche" and m.tirs == tir1 and m.combat.derniere_reaction != "leger", "coup léger pendant le sort : interrompu (%s), aucun trait" % m.combat.derniere_reaction)

	# --- I. sans info + chute + finisher « sol »
	m.queue_free()
	await _frames(2)
	var n := await _mage(Vector3(-6, 0.05, 4), "mage_b")
	_devant(n, 1.8)
	var v0: float = n.vie
	r = n.recevoir_coup(14.0, j.global_position, false)
	_verif(r == "touche" and n.vie < v0, "sans info (3 args) : touché, %.1f dégâts" % (v0 - n.vie))
	_verif(Plaies.nombre(n.modele) >= 1, "plaie posée sur le mage")
	await _frames(40)
	n.combat.posture = p.posture_max
	r = n.recevoir_coup(34.0, j.global_position, true, {"attaque": "lourde", "zone": "jambes"})
	_verif(n.etat == n.CHUTE, "coup lourd aux jambes : renversé (%s)" % n.combat.derniere_reaction)
	await _frames(110)
	_devant(n, 1.6)
	var cat: String = n.finisher_possible(j)
	_verif(cat == "sol", "au sol : finisher « sol » (%s)" % cat)
	var b0 := _butins()
	r = n.recevoir_coup(34.0, j.global_position, true, {"attaque": "lourde"})
	_verif(r == "tue" and not n.vivant() and morts.has("mage_b") and _butins() == b0 + 1, "coup de grâce : tué, signal mort, butin")

	# --- J. finisher rapide (vie basse) -> décapitation ; butin du mage
	var o := await _mage(Vector3(6, 0.05, 4), "mage_c")
	o.set_physics_process(false)
	_devant(o, 1.8)
	o.vie = 15.0
	o.combat.posture = 5.0
	cat = o.finisher_possible(j)
	_verif(cat in ["rapide", "lateral"], "vie basse : finisher « %s »" % cat)
	var b1 := _butins()
	r = o.recevoir_coup(34.0, j.global_position, true, {"attaque": "lourde"})
	_verif(r == "tue" and o.modele.has_meta("decapite") and morts.has("mage_c"), "finisher : mage décapité, signal mort")
	var bt: Node = null
	for ch in sc.get_children():
		if ch.get_script() == BUTIN:
			bt = ch
	_verif(_butins() == b1 + 1 and bt != null and bt.contenu.has("cristal_givre"), "butin du mage : %s" % (str(bt.contenu) if bt else "?"))
	await _frames(30)
	_verif(o._ragdoll != null and o._ragdoll.actif, "ragdoll actif")

	# --- K. mort sauvegardée (monde.creer_ennemi)
	var MONDE: Script = load("res://scripts/monde.gd")
	var w: Node3D = Node3D.new()
	w.set_script(MONDE)
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar vus := {}\nfunc signaler(e: String) -> void:\n\tvus[e] = true\n"
	gs.reload()
	var q := Node.new()
	q.set_script(gs)
	w.set("quetes", q)
	w.set("joueur", j)
	var e: CharacterBody3D = w.creer_ennemi(MAGE, Vector3.ZERO, 0.0, {"ident": "mage_sauve"})
	var enreg: bool = (w.get("draugrs") as Dictionary).has("mage_sauve")
	e.mort.emit("mage_sauve")
	_verif(enreg and q.vus.has("tue:mage_sauve"), "monde.creer_ennemi : mage enregistré (draugrs_morts) et « tue:mage_sauve » signalé")
	w.free()
	q.free()

	print("RÉSUMÉ test_mage_ia : %d OK, %d en échec" % [_ok, _ko])
	print("ECHECS : %d" % _ko)
	quit(1 if _ko > 0 else 0)
