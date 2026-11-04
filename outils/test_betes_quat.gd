extends SceneTree
## Test sans fenêtre des bêtes Quaternius (scripts/bete_quat.gd, socle EnnemiBase ; persos/quaternius_jeu 2026-11-04) :
##   godot --headless --path . -s res://outils/test_betes_quat.gd -- --nouvelle --test
## Décor : scenes/test_troll_mage.tscn (mode --test). Vérifie : modèles (Skeleton3D, « Animations », clips + alias du contrat),
## groupe ennemis / faune, loup qui détecte, alerte sa meute, encercle et mord (dégâts au joueur), réaction au coup, mort (clip Death,
## signal mort, butin), cerf qui fuit le joueur (non hostile, jamais en combat), araignée en embuscade, habitants Quaternius (contrat Humain).

const SCENE := preload("res://scenes/test_troll_mage.tscn")
const BETE := preload("res://scripts/bete_quat.gd")

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

func _bete(espece: String, pos: Vector3, ident: String, options := {}) -> CharacterBody3D:
	options["ident"] = ident
	options["espece"] = espece
	var b: CharacterBody3D = sc.creer_ennemi(BETE, pos, options)
	b.mort.connect(func(id: String) -> void: morts.append(id))
	await _frames(3)
	return b

func _tester() -> void:
	RetourImpact.muet = true
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	j = sc.joueur
	j.global_position = Vector3(0, 0, 40.0)

	# --- A. modèles : contrat des ennemis
	for id: String in ["pq_loup2", "pq_cerf2", "pq_biche", "pq_renard", "pq_araignee"]:
		var n := PersosQuat.creer(id)
		var ap := n.get_node_or_null("Animations") as AnimationPlayer
		var sq := n.find_child("Skeleton3D", true, false)
		var clips_ok := ap != null and ap.has_animation("Idle") and ap.has_animation("Walk") and ap.has_animation("Attack") and ap.has_animation("Death") and ap.has_animation("Death01")
		_verif(sq != null and clips_ok, "%s : Skeleton3D + Animations (Idle, Walk, Attack, Death, alias Death01)" % id)
		n.free()
	for id: String in PersosQuat.HABITANTS:
		var h := PersosQuat.creer(id)
		var ap2 := h.get_node_or_null("Animations") as AnimationPlayer
		var sq2 := h.find_child("Skeleton3D", true, false) as Skeleton3D
		_verif(ap2 != null and ap2.has_animation("Idle_Talking") and ap2.has_animation("Walk") and sq2 != null and sq2.find_bone("Head") >= 0 and sq2.find_bone("foot_l") >= 0,
			"%s : rig UAL (Head, foot_l) + clips du jeu (Idle_Talking, Walk)" % id)
		h.free()

	# --- B. loup : groupe, détection, alerte de meute
	var l1 := await _bete("loup", Vector3(0, 0.05, 0.0), "loup_t_a", {"meute": "t"})
	var l2 := await _bete("loup", Vector3(3, 0.05, -2.0), "loup_t_b", {"meute": "t"})
	_verif(l1.is_in_group("ennemis") and not l1.is_in_group("faune") and l1.vie == l1.vie_max and l1.nom_affiche == "Loup", "loup : groupe ennemis, %d PV" % l1.vie)
	_verif(not l1.en_combat(), "loup au repos : pas en combat")
	j.global_position = l1.global_position + l1.global_transform.basis.z * 12.0
	await _frames(30)
	_verif(l1.en_combat(), "loup : détecte le joueur à 12 m (état %d)" % l1.etat)
	_verif(l2.en_combat(), "meute : le second loup est alerté (état %d)" % l2.etat)

	# --- C. morsure : le joueur reste planté, il est mordu
	var c0: int = j.coups_recus
	var mordu := false
	for i in 600:
		if j.coups_recus > c0:
			mordu = true
			break
		await physics_frame
	_verif(mordu and (l1.attaques + l2.attaques) >= 1, "morsure reçue par le joueur (%d morsures)" % (l1.attaques + l2.attaques))

	# --- D. coup reçu puis mort : clip Death, signal, butin
	var r: String = l1.recevoir_coup(18.0, j.global_position, true, {})
	_verif(r == "touche" or r == "tue", "loup touché : %s (vie %d)" % [r, l1.vie])
	for i in 6:
		if not l1.vivant():
			break
		l1.recevoir_coup(30.0, j.global_position, true, {})
		await _frames(2)
	await _frames(5)
	_verif(not l1.vivant() and morts.has("loup_t_a"), "loup tué : signal mort")
	_verif(l1.anim.current_animation in ["Death", "Death01"], "mort : clip %s (pas de ragdoll)" % l1.anim.current_animation)
	l2.queue_free()
	await _frames(3)

	# --- E. cerf : non hostile, fuit
	j.global_position = Vector3(0, 0, 40.0)
	var cf := await _bete("cerf", Vector3(0, 0.05, 10.0), "cerf_t")
	_verif(cf.is_in_group("faune") and not cf.en_combat(), "cerf : faune, jamais en combat")
	j.global_position = cf.global_position + Vector3(0, 0, 6.0)
	var d0 := cf.global_position.distance_to(j.global_position)
	await _frames(120)
	var d1 := cf.global_position.distance_to(j.global_position)
	_verif(cf.etat == cf.FUITE and d1 > d0 + 3.0 and not cf.en_combat(), "cerf : fuit le joueur (%.1f -> %.1f m)" % [d0, d1])
	var c1: int = j.coups_recus
	await _frames(60)
	_verif(j.coups_recus == c1, "cerf : n'attaque jamais")
	cf.queue_free()

	# --- F. araignée : embuscade (pas vue à 9 m), attaque de près
	j.global_position = Vector3(0, 0, 40.0)
	var ar := await _bete("araignee", Vector3(0, 0.05, 20.0), "araignee_t")
	j.global_position = ar.global_position + ar.global_transform.basis.z * 9.0
	await _frames(30)
	_verif(not ar.en_combat(), "araignée : embuscade, ne réagit pas à 9 m")
	j.global_position = ar.global_position + ar.global_transform.basis.z * 4.5
	await _frames(30)
	_verif(ar.en_combat(), "araignée : bondit à 4,5 m")

	print("\nBETES_QUAT : %d OK, %d ÉCHEC(S)" % [_ok, _ko])
	quit(1 if _ko > 0 else 0)
