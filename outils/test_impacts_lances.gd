extends SceneTree
## Test sans fenêtre des IMPACTS D'OBJETS LANCÉS (ImpactsLances, SuiviLancer, ArmeLancee), dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_impacts_lances.gd -- --nouvelle
## - épée rapide pointe en avant → plantée dans un bandit, accrochée à un os, elle suit le corps ;
## - très rapide sur un squelette (léger) → traverse, ressort, se fiche dans le mur derrière ;
## - lancée du plat → rebond, dégâts contondants réduits, pas plantée ;
## - tonneau (15 kg, 12 m/s) → dégâts + renversé ;
## - plantée puis tuée → le cadavre (ragdoll) garde l'arme, qui suit l'os ; retirée par télékinésie → libre ;
## - interrupteur --sans-armes-plantees (ImpactsLances.regler(false)) → la lame rebondit.
## Le lanceur de test : jeter(id_ou_objet, depuis, vers, vitesse, a_plat) — réutilisé par outils/video_impacts_lances.gd.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")

var s: Node3D
var echecs := 0
var _n := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _ennemi(genre: String, pos: Vector3, vie := 300.0) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "test_lance_%d" % _n
	d.position = pos
	d.rotation.y = PI * 0.5     # tourné vers +X (vers le lanceur)
	s.add_child(d)
	d.vie = vie
	d.vie_max = maxf(vie, 80.0)
	d.combat.profil.chance_blocage = 0.0
	d.dort = false
	return d

## Lanceur de test : une arme du catalogue (id) ou un objet déjà fait, lancé de `depuis` vers `vers` à `v` m/s, pointe en avant
## (ou à plat : lame perpendiculaire au vol). Contacts : SuiviLancer (comme la télékinésie peut le faire).
static func jeter(parent: Node, quoi: Variant, depuis: Vector3, vers: Vector3, v: float, lanceur: Node, a_plat := false) -> RigidBody3D:
	var o: RigidBody3D = ArmeLancee.creer(String(quoi)) if quoi is String else quoi
	if o.get_parent() == null:
		parent.add_child(o)
	o.global_position = depuis
	var dir := (vers - depuis).normalized()
	if o.has_method("donnees_arme"):
		var ab := ImpactsLances.axe_monde(o, o.donnees_arme())
		var axe: Vector3 = (Vector3(ab[1]) - Vector3(ab[0])).normalized()
		var cible := dir
		if a_plat:
			cible = dir.cross(Vector3.UP).normalized()
		o.global_basis = Basis(Quaternion(axe, cible)) * o.global_basis
		o.global_position = depuis
	o.linear_velocity = dir * v
	o.angular_velocity = Vector3.ZERO
	ImpactsLances.suivre(o, lanceur)
	return o

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

func _lancer() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mannequin.position = Vector3(30, 0, 30)
	s.placer_joueur(Vector3(0, 0, 25), 0.0)
	Sang.niveau_force = 2
	var j: Node = s.joueur

	# --- 1. épée rapide pointe en avant → plantée dans un bandit
	var b := _ennemi("bandit", Vector3(2.0, 0, -6.0))
	await _attendre(20)
	var cible := b.global_position + Vector3(0, 1.25, 0)
	var vie0: float = b.vie
	var e1 := jeter(s, "epee_soldat", cible + Vector3(4.0, 0.1, 0), cible, 15.0, j)
	await _attendre(30)
	ok(ImpactsLances.plantee(e1), "épée 15 m/s pointe en avant : plantée (%s)" % ImpactsLances.dernier.get("issue", "?"))
	ok(b.vie < vie0, "bandit blessé (%.0f → %.0f, dégâts %.1f)" % [vie0, b.vie, float(ImpactsLances.dernier.get("degats", 0))])
	var m1: Dictionary = e1.get_meta("plantee", {})
	var rt: Node3D = m1.get("rt")
	ok(rt != null and rt.get_parent() is BoneAttachment3D, "accrochée à un os (%s)" % m1.get("os", "?"))
	var d_os: float = e1.global_position.distance_to((rt.get_parent() as Node3D).global_position) if rt else 99.0
	ok(d_os < 0.9, "l'arme est au contact du corps (%.2f m de l'os)" % d_os)
	var ab := ImpactsLances.axe_monde(e1, e1.donnees_arme())
	var pointe: Vector3 = ab[1]
	var centre := b.global_position + Vector3(0, 1.2, 0)
	ok(Vector2(pointe.x - centre.x, pointe.z - centre.z).length() < 0.35, "pointe dans le corps (%.2f m de l'axe du torse)" % Vector2(pointe.x - centre.x, pointe.z - centre.z).length())
	# elle suit le corps : on le déplace
	var rel0 := (rt.get_parent() as Node3D).global_transform.affine_inverse() * e1.global_position
	b.global_position += Vector3(0, 0, 1.0)
	await _attendre(6)
	var rel1 := (rt.get_parent() as Node3D).global_transform.affine_inverse() * e1.global_position
	ok(rel0.distance_to(rel1) < 0.05, "l'arme suit l'os quand le corps bouge (écart %.3f)" % rel0.distance_to(rel1))

	# --- 2. très rapide sur un squelette → traverse, se fiche dans le mur derrière (mur à x = -3,05, face +X)
	var sq := _ennemi("squelette", Vector3(-1.2, 0, 1.0), 300.0)
	await _attendre(20)
	var c2 := sq.global_position + Vector3(0, 1.15, 0)
	var e2 := jeter(s, "epee_soldat", c2 + Vector3(4.0, 0.0, 0.0), c2, 58.0, j)
	var vu_traverse := false
	for i in 50:
		await physics_frame
		if String(ImpactsLances.dernier.get("issue", "")) == "traverse":
			vu_traverse = true
	ok(vu_traverse, "épée 58 m/s sur squelette : traverse (E %.0f J ≥ seuil %.0f J)" % [float(ImpactsLances.dernier.get("energie", 0)), float(ImpactsLances.dernier.get("seuil", 0))])
	var m2: Dictionary = e2.get_meta("plantee", {})
	ok(bool(m2.get("mur", false)), "puis plantée dans le mur derrière (%s, x %.2f)" % [ImpactsLances.dernier.get("issue", "?"), e2.global_position.x])
	var ab2 := ImpactsLances.axe_monde(e2, e2.donnees_arme())
	ok(Vector3(ab2[1]).x < -3.03 and Vector3(ab2[1]).x > -3.25, "pointe enfoncée dans le mur (x %.3f)" % Vector3(ab2[1]).x)
	ok(sq.vie < 300.0, "squelette touché (%.0f PV)" % sq.vie)

	# --- 3. du plat → rebond
	var b3 := _ennemi("bandit", Vector3(2.0, 0, -10.0))
	await _attendre(20)
	var c3 := b3.global_position + Vector3(0, 1.2, 0)
	var v3: float = b3.vie
	var e3 := jeter(s, "epee_soldat", c3 + Vector3(4.0, 0, 0), c3, 15.0, j, true)
	await _attendre(30)
	ok(not ImpactsLances.plantee(e3), "épée lancée du plat : pas plantée")
	ok(String(ImpactsLances.dernier.get("issue", "")) == "rebond", "issue rebond (%s)" % ImpactsLances.dernier.get("issue", "?"))
	var dg3: float = v3 - b3.vie
	ok(dg3 > 0.5 and dg3 < 12.0, "dégâts contondants réduits (%.1f)" % dg3)

	# --- 4. tonneau 15 kg à 12 m/s → dégâts + renversé
	var b4 := _ennemi("bandit", Vector3(2.0, 0, -14.0))
	await _attendre(20)
	var c4 := b4.global_position + Vector3(0, 1.0, 0)
	var v4: float = b4.vie
	var t := RigidBody3D.new()
	t.mass = 15.0
	t.name = "TonneauTest"
	var f := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.32
	cyl.height = 0.85
	f.shape = cyl
	t.add_child(f)
	jeter(s, t, c4 + Vector3(4.0, 0, 0), c4, 12.0, j)
	var renverse := false
	for i in 30:
		await physics_frame
		if b4.etat == DRAUGR.CHUTE:
			renverse = true
	ok(b4.vie < v4 and v4 - b4.vie > 15.0, "tonneau : dégâts selon l'énergie (%.1f)" % (v4 - b4.vie))
	ok(renverse, "tonneau : bandit renversé (q = %.0f kg·m/s)" % float(ImpactsLances.dernier.get("quantite_mvt", 0)))

	# --- 5. plantée puis tuée : le cadavre garde l'arme
	var b5 := _ennemi("bandit", Vector3(9.0, 0, -18.0), 12.0)
	await _attendre(20)
	var c5 := b5.global_position + Vector3(0, 1.3, 0)
	var e5 := jeter(s, "epee_soldat", c5 + Vector3(3.5, 0, 0), c5, 14.0, j)
	await _attendre(80)
	ok(b5.etat == DRAUGR.MORT, "bandit tué par l'épée lancée")
	ok(ImpactsLances.plantee(e5), "le cadavre garde l'arme (%s)" % ImpactsLances.dernier.get("issue", "?"))
	var rt5: Node3D = e5.get_meta("plantee", {}).get("rt") if ImpactsLances.plantee(e5) else null
	if rt5 != null:
		var o5 := (rt5.get_parent() as Node3D)
		var rel := o5.global_transform.affine_inverse() * e5.global_position
		await _attendre(40)
		var rel2 := o5.global_transform.affine_inverse() * e5.global_position
		ok(rel.distance_to(rel2) < 0.08 and o5.global_position.y < 1.0, "elle suit l'os du ragdoll (écart %.3f, os à y %.2f)" % [rel.distance_to(rel2), o5.global_position.y])
	# re-saisie par télékinésie : arrachée
	e5.saisi_telekinesie(true)
	await _attendre(3)
	ok(not ImpactsLances.plantee(e5) and not e5.freeze, "re-saisie : arrachée, corps rigide libre")

	# --- 6. interrupteur --sans-armes-plantees
	ImpactsLances.regler(false)
	var b6 := _ennemi("bandit", Vector3(9.0, 0, -6.0))
	await _attendre(20)
	var c6 := b6.global_position + Vector3(0, 1.25, 0)
	var e6 := jeter(s, "epee_soldat", c6 + Vector3(4.0, 0, 0), c6, 15.0, j)
	await _attendre(30)
	ok(not ImpactsLances.plantee(e6), "--sans-armes-plantees : la lame ne se plante pas (%s)" % ImpactsLances.dernier.get("issue", "?"))
	ImpactsLances.regler(true)

	# --- 7. hache : plantée fil en avant
	var b7 := _ennemi("bandit", Vector3(9.0, 0, -12.0))
	await _attendre(20)
	var c7 := b7.global_position + Vector3(0, 1.25, 0)
	var e7 := jeter(s, "hachette", c7 + Vector3(4.0, 0, 0), c7, 15.0, j)
	await _attendre(30)
	ok(ImpactsLances.plantee(e7), "hachette pointe en avant : plantée (%s)" % ImpactsLances.dernier.get("issue", "?"))

	# --- 8. tué devant un mur : « brochette », cloué au mur par l'épée (mur à x = -3,05 ; zone libérée par le squelette du cas 2)
	for n in s.get_children():
		if n is RigidBody3D and n != e2:
			n.queue_free()
	sq.queue_free()
	e2.queue_free()
	var dc := _ennemi("guerrier", Vector3(-1.9, 0, 1.0), 10.0)
	await _attendre(20)
	var c8 := dc.global_position + Vector3(0, 1.25, 0)
	var e8 := jeter(s, "epee_soldat", c8 + Vector3(4.0, 0.0, 0.0), c8, 18.0, j)
	await _attendre(12)
	ok(String(ImpactsLances.dernier.get("issue", "")) == "cloue", "draugr tué devant le mur : cloué (%s)" % ImpactsLances.dernier.get("issue", "?"))
	var cl: Variant = ImpactsLances.dernier.get("clouage")
	await _attendre(180)
	if cl is Node and is_instance_valid(cl):
		var pbc: PhysicalBone3D = cl.pb
		var cible_os: Vector3 = cl.cible()
		ok(pbc.global_position.distance_to(cible_os) < 0.1, "3 s après : l'os %s reste épinglé (écart %.3f m)" % [ImpactsLances.dernier.get("os_cloue", "?"), pbc.global_position.distance_to(cible_os)])
		ok(pbc.global_position.x > -3.05, "l'os ne traverse pas le mur (x %.2f, mur -3,05)" % pbc.global_position.x)
		var ab8 := ImpactsLances.axe_monde(e8, e8.donnees_arme())
		ok(Vector3(ab8[1]).x < -3.05 and Vector3(ab8[0]).x > -3.05, "pointe dans le mur, garde devant le corps (pointe x %.2f, prise x %.2f)" % [Vector3(ab8[1]).x, Vector3(ab8[0]).x])
		var bassin: PhysicalBone3D = (cl.rd as Ragdoll).os.get("pelvis")
		ok(bassin != null and bassin.global_position.y < pbc.global_position.y, "le bas du corps pend sous l'os cloué")
	else:
		ok(false, "clouage introuvable")
	# --- 9. pas tué devant le mur : plantée, pas clouée
	var dn := _ennemi("guerrier", Vector3(-1.9, 0, -0.2), 300.0)
	await _attendre(20)
	var c9 := dn.global_position + Vector3(0, 1.25, 0)
	var e9 := jeter(s, "epee_soldat", c9 + Vector3(4.0, 0.0, 0.0), c9, 18.0, j)
	await _attendre(20)
	ok(String(ImpactsLances.dernier.get("issue", "")) == "plantee" and ImpactsLances.plantee(e9), "pas tué devant le mur : plantée, pas clouée (%s)" % ImpactsLances.dernier.get("issue", "?"))

	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
