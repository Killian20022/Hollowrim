extends SceneTree
## Test headless : godot --headless -s res://outils/test_marche_pnj.gd
## Vérifie que villageois et draugr avancent face en avant (corps orienté dans le sens du déplacement),
## que speed_scale suit la vitesse, que la tête suit le joueur et que les animations s'enchaînent.

class FauxJoueur extends CharacterBody3D:
	var en_dialogue := false
	var mort := false
	var camera: Camera3D
	func recevoir_coup(_d: float, _o: Vector3) -> String:
		return "touche"

var _echecs := 0
var _pose_tete := Basis()
var _sq_suivi: Skeleton3D

## Lu à la fin de la mise à jour du squelette (modificateurs compris) : hors de ce signal, Godot rend la pose d'animation brute.
func _noter_tete() -> void:
	_pose_tete = (_sq_suivi.global_transform * _sq_suivi.get_bone_global_pose(_sq_suivi.find_bone("Head"))).basis


func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _initialize() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var monde := Node3D.new()
	root.add_child(monde)
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	f.shape = BoxShape3D.new()
	(f.shape as BoxShape3D).size = Vector3(120, 1, 120)
	sol.position.y = -0.5
	sol.add_child(f)
	monde.add_child(sol)
	var j := FauxJoueur.new()
	j.camera = Camera3D.new()
	j.camera.position.y = 1.6
	j.add_child(j.camera)
	monde.add_child(j)
	j.position = Vector3(3.0, 0.1, 0.0)  # proche, sur le côté

	# --- villageois : promenade forcée avec le joueur à côté (il doit marcher face à sa route)
	var liste: Array = load("res://scripts/villageois.gd").charger()
	var v: CharacterBody3D = load("res://scripts/villageois.gd").new()
	v.donnees = liste[0]
	v.joueur = j
	v.points = [Vector3(0, 0.1, 0), Vector3(0, 0.1, -12)]
	v.position = v.points[0]
	monde.add_child(v)
	await process_frame
	v._prochaine_promenade = 0.1
	var pire := 1.0
	var vmax := 0.0
	var scales: Array = []
	var anims := {}
	for i in 360:
		await physics_frame
		var vh := Vector3(v.velocity.x, 0, v.velocity.z)
		anims[v._anim] = true
		if vh.length() > 0.5:
			var avant := v.global_transform.basis.z
			pire = minf(pire, vh.normalized().dot(Vector3(avant.x, 0, avant.z).normalized()))
			vmax = maxf(vmax, vh.length())
			scales.append(v.anim.speed_scale)
	_verif(vmax > 0.5, "villageois : il marche (vmax %.2f m/s)" % vmax)
	_verif(pire > 0.8, "villageois : corps dans le sens de la marche (pire cosinus %.2f)" % pire)
	if scales.size() > 0:
		_verif(absf(scales.back() * 1.03 - vmax) < 0.15, "villageois : speed_scale %.2f ~ vitesse %.2f / 1,03" % [scales.back(), vmax])
	print("   animations jouées : ", anims.keys())
	# tête : le joueur est à 4,5 m sur le côté (hors de portée du regard du corps) : la tête doit
	# tourner vers lui, limitée à ±60°
	v.etat = v.POSTE
	v._activite(true)
	v._prochaine_promenade = 1000.0
	v.rotation.y = 0.0
	v.global_position = Vector3(0, 0.1, 5)
	j.global_position = Vector3(4.5, 0.1, 5.0)
	for i in 60:
		await physics_frame
	var sq: Skeleton3D = v.modele.find_child("Skeleton3D", true, false)
	_sq_suivi = sq
	sq.skeleton_updated.connect(_noter_tete)
	for i in 3:
		await physics_frame
	print("   os cou/tête : ", sq.find_bone("neck_01"), " ", sq.find_bone("Head"))
	print("   lacet tête ", rad_to_deg(v._tete.lacet), "° tangage ", rad_to_deg(v._tete.tangage), "°  corps ", rad_to_deg(v.rotation.y), "°")
	var tete_v := Vector3.ZERO
	tete_v = (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head"))).basis.z
	print("   axe z de la tête (monde) ", tete_v)
	_verif(absf(rad_to_deg(v._tete.lacet) - 60.0) < 3.0, "villageois : la tête tourne vers le joueur, bornée à 60° (%.1f°)" % rad_to_deg(v._tete.lacet))
	var axe_z := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("Head"))).basis.z
	print("   z de la tête en repère monde ", axe_z)
	var gh := _pose_tete
	j.global_position = Vector3(40, 0.1, 40)  # joueur loin : la tête revient droit devant
	for i in 120:
		await physics_frame
	var gh0 := _pose_tete
	var angle := gh.get_rotation_quaternion().angle_to(gh0.get_rotation_quaternion())
	_verif(rad_to_deg(angle) > 40.0, "villageois : l'os Head a réellement tourné (%.1f° d'écart entre tête tournée et droite)" % rad_to_deg(angle))
	_verif(absf(v._tete.lacet) < deg_to_rad(2.0), "villageois : la tête revient droit (%.1f°)" % rad_to_deg(v._tete.lacet))
	# variété et conversation
	v._delai_variete = 0.0
	v._autour = 0.0
	v._variete_fin = 0.0
	var vus := {}
	for i in 900:
		await physics_frame
		vus[v._anim] = true
		if v._delai_variete > 3.0:
			v._delai_variete = 0.5  # accélère le test
	print("   animations de repos vues : ", vus.keys())
	_verif(vus.size() >= 2, "villageois : variété au repos")
	v.parler()
	j.en_dialogue = true
	var parole := {}
	for i in 1200:
		await physics_frame
		parole[v._anim] = true
	print("   conversation : ", parole.keys())
	_verif(parole.has("Idle_Talking") and parole.has("Idle"), "villageois : alterne Idle_Talking / Idle en conversation")
	j.en_dialogue = false

	# --- draugr : poursuite
	j.position = Vector3(-30, 0.1, 30)
	var d: CharacterBody3D = load("res://scripts/draugr.gd").new()
	d.joueur = j
	d.type = "guerrier"
	monde.add_child(d)
	d.global_position = Vector3(-30, 0.1, 5)
	await process_frame
	var dpire := 1.0
	var dscales := {}
	var danim := {}
	for i in 420:
		await physics_frame
		var vh := Vector3(d.velocity.x, 0, d.velocity.z)
		danim[d._anim] = true
		if vh.length() > 0.5 and d._anim in ["Walk", "Jog_Fwd"]:
			var avant := d.global_transform.basis.z
			dpire = minf(dpire, vh.normalized().dot(Vector3(avant.x, 0, avant.z).normalized()))
			dscales[d._anim] = d.anim.speed_scale
	print("   draugr animations : ", danim.keys(), " scales ", dscales)
	_verif(dpire > 0.7, "draugr : corps dans le sens de la marche (pire cosinus %.2f)" % dpire)
	# combat : le joueur arrive près
	j.global_position = d.global_position + Vector3(0.0, 0.0, 1.4)
	var att := false
	for i in 300:
		await physics_frame
		if d._anim in ["Sword_Attack", "Punch_Cross"]:
			att = true
	_verif(att, "draugr : attaque")
	var vers := (j.global_position - d.global_position)
	vers.y = 0
	var face := d.global_transform.basis.z
	_verif(vers.normalized().dot(Vector3(face.x, 0, face.z).normalized()) > 0.9, "draugr : orienté vers le joueur")
	d.recevoir_coup(10.0, j.global_position, true)
	print("   réaction : ", d._anim)
	_verif(d._anim in ["Hit_Chest", "Hit_Head"], "draugr : réaction au coup")
	j.global_position = Vector3(40, 0.1, 40)
	d.recevoir_coup(500.0, j.global_position, true)
	await create_timer(6.0).timeout
	# la mort est un ragdoll : le corps doit être couché sur le sol (bassin bas) et figé
	var sqd: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "pelvis"
	sqd.add_child(ba)
	await process_frame
	await process_frame
	var haut_bassin := ba.global_position.y - d.global_position.y
	print("   bassin à ", haut_bassin, " m du sol, ragdoll figé : ", d._ragdoll != null and d._ragdoll.est_fige())
	_verif(d._ragdoll != null and d._ragdoll.est_fige() and haut_bassin < 0.35 and haut_bassin > -0.1, "draugr : mort au sol (ragdoll couché et figé)")
	print("FIN ", "tout vert" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit()
