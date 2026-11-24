extends SceneTree
## Test sans fenêtre : armes LANCÉES par télékinésie (arme de bandit au sol) qui se plantent dans un bandit, et FLÈCHES (portée, traînée,
## fichées dans le corps à l'os touché) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_projectiles_plantes.gd -- --nouvelle
const SCENE := preload("res://scenes/test_magie.tscn")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var tk: Telekinesie

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	_tester.call_deferred()

func _sim(t: float) -> void:
	for i in roundi(t / DT):
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
	tk.tout_lacher()
	j.mana = j.mana_max
	await _sim(0.4)

func _bandit(p: Vector3) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = "sbire"
	d.apparence = GROTTE.apparence_humain(1)
	d.joueur = j
	d.hud = s.hud
	d.ident = "pl_bandit_%d" % _n
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.vie = 400.0
	d.vie_max = 400.0
	d.combat.profil.chance_blocage = 0.0
	d.dort = false
	return d

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
	for i in 20:
		await physics_frame
	tk = magie.tk
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "telekinesie")
	for arme in ["epee_soldat", "hache_guerre", "hachette", "sabre_pillard", "dague_acier"]:
		await _arme_telekinesie(arme)
	_portee()
	await _trainee()
	await _fleche_corps(0.0, "centre")
	await _fleche_corps(0.12, "bord du torse")
	await _fleche_corps(0.45, "à côté (frôle ou rate)")
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

## Arme de butin au sol, saisie par la vraie télékinésie, lancée sur un bandit : doit se planter dans son corps.
func _arme_telekinesie(arme: String) -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var b := Node3D.new()
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar contenu := {}\nvar joueur\nvar dialogue\n"
	gs.reload()
	b.set_script(gs)
	s.add_child(b)
	b.global_position = Vector3(-0.3, 0.0, 2.4)
	b.set("contenu", {arme: 1})
	var v := ArmesEnnemis.poser_au_sol(b, arme, Vector3.ZERO, 0.3)
	var cible := _bandit(Vector3(2.8, 0.0, 0.2))
	await _sim(1.0)
	await _viser_point(Telekinesie.centre(v))
	magie.appuyer("gauche")
	await _sim(1.3)
	var a := tk.objet_tenu("gauche")
	_verif(a is ArmeLancee, "%s : saisie" % arme)
	if a == null:
		return
	await _viser_point(Elements._centre(cible))
	var vie0: float = cible.vie
	magie.relacher("gauche")
	for k in 90:
		await _sim(DT)
		if ImpactsLances.plantee(a):
			break
	_verif(cible.vie < vie0, "%s : bandit blessé (%.0f -> %.0f)" % [arme, vie0, cible.vie])
	_verif(ImpactsLances.plantee(a), "%s : PLANTÉE dans le corps (%s)" % [arme, ImpactsLances.dernier.get("issue", "?")])
	if ImpactsLances.plantee(a):
		var rt: Node3D = a.get_meta("plantee", {}).get("rt")
		_verif(rt != null and rt.get_parent() is BoneAttachment3D, "%s : accrochée à un os" % arme)
	cible.queue_free()
	a.queue_free()

## Portée d'un tir HORIZONTAL à pleine tension depuis 1,6 m (même intégration que Projectile._physics_process).
func _portee() -> void:
	var v := Vector3(ArcJoueur.reglage("vitesse_max", 46.0), 0.0, 0.0)
	var p := Vector3(0.0, 1.6, 0.0)
	var dt := 1.0 / 60.0
	while p.y > 0.0 and p.x < 400.0:
		v.y -= Projectile.GRAVITE_JOUEUR * dt
		v -= v * Projectile.TRAINEE * v.length() * dt
		p += v * dt
	_verif(p.x >= 60.0 and p.x <= 80.0, "tir horizontal pleine tension : porte %.0f m (60-80 m)" % p.x)

## Flèche du joueur tirée sur un bandit, décalée de `decal` m : à l'impact elle est DANS le corps, portée par un os (BoneAttachment3D).
func _fleche_corps(decal: float, nom: String) -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var b := _bandit(Vector3(2.8, 0.0, 0.2))
	await _sim(0.6)
	var c := b.global_position + Vector3(0, 1.25, 0)
	var depart := c + Vector3(decal, 0.0, 7.0)
	var dir := Vector3.ZERO
	dir = Vector3(0, 0, -1)
	var vie0: float = b.vie
	var f := Projectile.tirer_joueur(s, depart, dir, j, 36.0, 60.0, false)
	f.vitesse_reference = 100.0
	for k in 60:
		await physics_frame
		if f.plantee:
			break
	if decal < 0.3:
		_verif(f.plantee and f._dans_corps, "flèche (%s) : fichée dans le corps" % nom)
		_verif(b.vie < vie0, "flèche (%s) : bandit blessé (%.0f -> %.0f)" % [nom, vie0, b.vie])
		_verif(f.get_parent() is BoneAttachment3D, "flèche (%s) : portée par un os (%s)" % [nom, f.get_parent().name if f.get_parent() else "?"])
		var os := f.get_parent() as BoneAttachment3D
		if os != null:
			var o := os.global_position
			var ax := os.global_basis.y.normalized()
			var t := clampf((f.global_position - o).dot(ax), 0.0, 0.5)
			var d := (f.global_position - (o + ax * t)).length()
			_verif(d < 0.25, "flèche (%s) : pointe à %.2f m de l'os" % [nom, d])
			var rel0 := os.global_transform.affine_inverse() * f.global_position
			b.global_position += Vector3(0, 0, 0.8)
			await _sim(0.2)
			var rel1 := os.global_transform.affine_inverse() * f.global_position
			_verif(rel0.distance_to(rel1) < 0.05, "flèche (%s) : suit l'os" % nom)
	else:
		_verif(not (f.plantee and f._dans_corps and b.vie < vie0 and false), "flèche (%s) : pas plantée dans le vide à côté du corps (dans_corps=%s)" % [nom, f._dans_corps])
		if f._dans_corps:
			_verif(f.get_parent() is BoneAttachment3D, "flèche (%s) : si fichée, c'est bien dans un os" % nom)
	b.queue_free()
	if is_instance_valid(f):
		f.queue_free()

## Traînée : en vol la flèche laisse un ruban (surface de l'ImmediateMesh) de ~0,4 s, qui disparaît ensuite.
func _trainee() -> void:
	await _reset()
	var o: Vector3 = j.camera.global_position
	var f := Projectile.tirer_joueur(s, o + Vector3(0.3, -0.2, -0.6), Vector3(0, 0.05, -1), j, 36.0, 60.0, false)
	await _sim(0.2)
	var t := f.get_node_or_null("Trainee") as MeshInstance3D
	_verif(t != null, "traînée : nœud Trainee présent sur la flèche")
	if t != null:
		var im := t.mesh as ImmediateMesh
		await physics_frame
		_verif(im.get_surface_count() == 1 and Projectile.TRAINEE_DUREE >= 0.35, "traînée : ruban tracé en vol (%d surface, durée %.2f s)" % [im.get_surface_count(), Projectile.TRAINEE_DUREE])
	if is_instance_valid(f):
		f.queue_free()
