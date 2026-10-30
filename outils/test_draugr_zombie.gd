extends SceneTree
## Draugr « zombie » (draugr.gd, option zombie ; clips Zombie_* reportés du Mixamo « Not So Scary Zombie Pack » par
## outils/zombie_retarget.gd) : clips présents et continus (pas d'à-coup d'une image à l'autre, boucles raccordées), réveil
## (allongé -> debout quand le joueur approche), démarche titubante, attaque à mains nues qui touche, réaction capturée, et
## draugr ordinaire inchangé (épée, clips Quaternius).
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_draugr_zombie.gd -- --nouvelle
const DRAUGR := preload("res://scripts/draugr.gd")
const JOUEUR := preload("res://scripts/combat/joueur_test.gd")
const CLIPS := ["Zombie_Reveil", "Zombie_Marche", "Zombie_Attente", "Zombie_Poing", "Zombie_Tete", "Zombie_Griffes", "Zombie_Coup", "Zombie_Coup2"]
## Continuité : le report ne doit ajouter AUCUN saut à la capture. Le saut d'un os entre deux images du clip reporté est comparé au
## plus grand saut (rotation locale) de la capture Mixamo elle-même (le poing claque le poignet de 1,18 rad en une image à 30 i/s
## dans la source), à SAUT_TOLERANCE près.
const RETARGET := preload("res://outils/zombie_retarget.gd")
const SAUT_TOLERANCE := 0.05
var echecs := 0
var monde: Node3D
var joueur: CharacterBody3D

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _attendre(s: float) -> void:
	var n := int(s * 60.0)
	for i in n:
		await physics_frame

func _draugr(pos: Vector3, opts: Dictionary) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire"
	d.joueur = joueur
	for k in opts:
		d.set(k, opts[k])
	d.position = pos
	monde.add_child(d)
	return d

func _tete(d: Node) -> float:
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	return (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head"))).origin.y - d.global_position.y

## Plus grand saut de rotation LOCALE (os / parent Mixamo) d'une image à la suivante dans la capture source du clip.
var _source := {}
func _saut_source(clip: String) -> float:
	if _source.is_empty():
		_source = JSON.parse_string(FileAccess.get_file_as_string(RETARGET.SOURCE))
	var images: Array = _source[clip]["images"]
	var corr: Dictionary = RETARGET.correspondances()
	# parent Mixamo de chaque os : l'os dont l'enfant de direction est celui-ci (chaîne colonne, bras, jambes, doigts)
	var parent := {}
	for mn: String in corr:
		var enfant := String(corr[mn][1])
		if enfant != "":
			parent[enfant] = mn
	for c in ["Left", "Right"]:
		parent[c + "Shoulder"] = "Spine2"
		parent[c + "UpLeg"] = "Hips"
		for d in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
			parent["%sHand%s1" % [c, d]] = c + "Hand"
	var pire := 0.0
	for mn: String in corr:
		if not parent.has(mn) or not images[0].has(mn):
			continue
		var pn: String = parent[mn]
		for k in range(1, images.size()):
			var l0: Quaternion = RETARGET._q(images[k - 1][pn]).inverse() * RETARGET._q(images[k - 1][mn])
			var l1: Quaternion = RETARGET._q(images[k][pn]).inverse() * RETARGET._q(images[k][mn])
			pire = maxf(pire, l0.angle_to(l1))
	return pire

func _lancer() -> void:
	# --- 1. clips
	var bib := Humain.bibliotheque()
	for c: String in CLIPS:
		ok(bib.has_animation(c), "clip %s présent dans Humain.bibliotheque()" % c)
	ok(bib.get_animation("Zombie_Marche").loop_mode == Animation.LOOP_LINEAR and bib.get_animation("Zombie_Attente").loop_mode == Animation.LOOP_LINEAR, "marche et attente en boucle")
	for c: String in ["Zombie_Poing", "Zombie_Tete", "Zombie_Griffes"]:
		var im := float(bib.get_animation(c).get_meta("impact", -1.0))
		ok(im > 0.1 and im < 0.9, "%s : image du contact mesurée (%.2f)" % [c, im])
	for c: String in CLIPS:
		var a := bib.get_animation(c)
		var pire := 0.0
		var pire_os := ""
		var raccord := 0.0
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var n := a.track_get_key_count(t)
			for k in range(1, n):
				var q0: Quaternion = a.track_get_key_value(t, k - 1)
				var q1: Quaternion = a.track_get_key_value(t, k)
				var ang := q0.angle_to(q1)
				if ang > pire:
					pire = ang
					pire_os = String(a.track_get_path(t)).get_slice(":", 1)
			if a.loop_mode == Animation.LOOP_LINEAR and n > 1:
				raccord = maxf(raccord, (a.track_get_key_value(t, 0) as Quaternion).angle_to(a.track_get_key_value(t, n - 1)))
		var src := _saut_source(c)
		ok(pire < src + SAUT_TOLERANCE, "%s : arcs continus, rien d'ajouté à la capture (saut max %.3f rad/image sur %s ; capture %.3f)" % [c, pire, pire_os, src])
		if a.loop_mode == Animation.LOOP_LINEAR:
			ok(raccord < 0.15, "%s : boucle raccordée (écart %.3f rad)" % [c, raccord])

	# --- 2. scène : sol + joueur factice
	monde = Node3D.new()
	get_root().add_child(monde)
	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(60, 1, 60)
	cs.shape = bx
	cs.position.y = -0.5
	sol.add_child(cs)
	monde.add_child(sol)
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	joueur.position = Vector3(0, 0, 25)
	monde.add_child(joueur)

	# --- 3. réveil
	var z := _draugr(Vector3(0, 0.05, 0), {"zombie": true, "dort": true, "ident": "test_zombie"})
	await _attendre(0.3)
	ok(not z.modele.find_children("*", "BoneAttachment3D", true, false).any(func(b: BoneAttachment3D) -> bool: return b.bone_name == "hand_r" and b.get_child_count() > 0), "zombie désarmé (rien dans la main droite)")
	ok(String(z.modele.get_meta("variante", "")).contains("_mains_"), "variante mains nues (%s)" % z.modele.get_meta("variante", ""))
	ok(z.etat == z.DORT and z.anim.assigned_animation == "Zombie_Reveil", "endormi allongé sur la 1re image du relevé")
	var h0 := _tete(z)
	ok(h0 < 0.45, "allongé : tête au ras du sol (%.2f m)" % h0)
	joueur.position = Vector3(0, 0, 8)   # à moins de REVEIL_DISTANCE
	await _attendre(0.2)
	ok(z.etat == z.REVEIL and z.anim.is_playing() and z.anim.current_animation == "Zombie_Reveil", "le joueur approche : il se relève (Zombie_Reveil)")
	var haut_max := h0
	var saut := 0.0
	var h_prec := h0
	for i in int(3.6 * 60):
		await physics_frame
		var h := _tete(z)
		saut = maxf(saut, absf(h - h_prec))
		h_prec = h
		haut_max = maxf(haut_max, h)
		if z.etat != z.REVEIL:
			break
	ok(haut_max > 1.05, "debout après le relevé (tête à %.2f m)" % haut_max)
	ok(saut < 0.08, "relevé sans à-coup (tête : %.3f m/image au plus)" % saut)
	ok(z.etat == z.TRAQUE, "puis il traque le joueur (état %d)" % z.etat)

	# --- 4. démarche
	await _attendre(0.8)
	ok(z.anim.current_animation == "Zombie_Marche", "démarche titubante vers le joueur (%s)" % z.anim.current_animation)
	ok(z._vit > 0.2 and z._vit <= 0.81, "allure de mort-vivant, jamais de course (%.2f m/s)" % z._vit)

	# --- 5. attaque à mains nues
	joueur.position = z.global_position + z.global_transform.basis.z * 1.3
	var vues := {}
	for i in int(14.0 * 60):
		await physics_frame
		if z.etat == z.ATTAQUE:
			vues[String(z.anim.current_animation)] = true
		if joueur.coups_recus >= 2:
			break
	ok(joueur.coups_recus >= 1, "attaque à mains nues qui touche (%d coups reçus)" % joueur.coups_recus)
	ok(not vues.is_empty() and vues.keys().all(func(k: String) -> bool: return k in ["Zombie_Poing", "Zombie_Tete", "Zombie_Griffes"]), "gestes capturés : %s" % [vues.keys()])

	# --- 6. réaction
	while z.etat == z.ATTAQUE:
		await physics_frame
	var r: String = z.recevoir_coup(4.0, joueur.global_position, false)
	await _attendre(0.05)
	ok(r == "touche" and String(z.anim.current_animation).begins_with("Zombie_Coup"), "réaction capturée au coup reçu (%s, %s)" % [r, z.anim.current_animation])
	await _attendre(1.2)
	ok(z.vivant() and String(z.anim.current_animation).begins_with("Zombie"), "reprend ses clips zombies après la réaction (%s)" % z.anim.current_animation)
	# mort : ragdoll habituel
	z.recevoir_coup(500.0, joueur.global_position, true)
	await _attendre(0.5)
	ok(not z.vivant(), "mort (ragdoll) comme les autres draugrs")

	# --- 7. draugr ordinaire inchangé
	var d := _draugr(Vector3(8, 0.05, 0), {"dort": true, "ident": "test_ordinaire"})
	await _attendre(0.2)
	ok(not d.zombie and d.anim.assigned_animation == "Death01", "draugr ordinaire : dort sur la pose Death01 (inchangé)")
	ok(not String(d.modele.get_meta("variante", "")).contains("_mains_"), "draugr ordinaire armé (%s)" % d.modele.get_meta("variante", ""))
	joueur.position = Vector3(8, 0, 30)
	var g := _draugr(Vector3(-8, 0.05, 0), {"ident": "test_garde"})
	await _attendre(0.3)
	ok(g.anim.current_animation == "Sword_Idle", "garde ordinaire : Sword_Idle (%s)" % g.anim.current_animation)

	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
