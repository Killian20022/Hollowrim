extends SceneTree
## Test headless de la porte du goulet du repaire (levier) : fermée, une capsule de joueur (r 0,35 ; h 1,8) NE la traverse PAS ;
## le levier (interactif) l'ouvre : état noté dans quetes.vus, collision retirée, la capsule passe jusqu'à la salle aux cristaux ;
## une « mort » (reinitialiser) ne la referme pas ; une partie neuve (état effacé) la retrouve fermée.
##   godot --headless --path . --script outils/test_porte_repaire.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await physics_frame

## Fait avancer la capsule du point `a` au point `b` (monde) ; renvoie la distance restante au but après `duree` s.
func _marcher(cap: CharacterBody3D, a: Vector3, b: Vector3, duree: float) -> float:
	cap.global_position = a
	cap.velocity = Vector3.ZERO
	await _attendre(0.2)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var t := 0.0
	while t < duree:
		var d := Vector3(b.x - cap.global_position.x, 0, b.z - cap.global_position.z)
		if d.length() < 0.3:
			break
		cap.velocity.x = d.normalized().x * 3.0
		cap.velocity.z = d.normalized().z * 3.0
		cap.velocity.y -= 20.0 * dt
		cap.move_and_slide()
		await physics_frame
		t += dt
	return Vector2(b.x - cap.global_position.x, b.z - cap.global_position.z).length()

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(1.0)
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	var g: Grotte = a.obtenir()
	a.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _attendre(0.5)
	var jeu: GrotteJeu = a.jeu
	var q: Node = m.quetes
	_verif(g.has_meta("porte_goulot") and jeu.interactifs.has("levier_goulot"), "porte et levier du goulet présents")
	var meta: Dictionary = g.get_meta("porte_goulot")
	var lat_m: float = (float(meta["lat_g"]) + float(meta["lat_d"])) * 0.5
	var cap := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	cap.add_child(cs)
	cap.floor_snap_length = 0.4
	g.add_child(cap)
	var av: Vector3 = g.to_global(g.sol_en("C", 1.0, lat_m) + Vector3(0, 0.1, 0))
	var ap: Vector3 = g.to_global(g.sol_en("C", 8.0, lat_m) + Vector3(0, 0.1, 0))
	var reste := await _marcher(cap, av, ap, 6.0)
	_verif(reste > 3.0, "porte fermée : la capsule est arrêtée (%.1f m du but, y compris z %.1f)" % [reste, g.to_local(cap.global_position).z])
	_verif(not q.vus.has("grotte:levier_goulot"), "état : porte non ouverte au départ")
	(jeu.interactifs["levier_goulot"] as Node3D).parler()
	await _attendre(3.2)
	_verif(q.vus.has("grotte:levier_goulot"), "levier tiré : état noté dans quetes.vus (sauvegardé, répliqué par ReseauLieux)")
	reste = await _marcher(cap, av, ap, 8.0)
	_verif(reste < 0.6, "porte ouverte : la capsule traverse jusqu'à la salle aux cristaux (reste %.2f m)" % reste)
	jeu.reinitialiser([])
	await _attendre(0.5)
	reste = await _marcher(cap, av, ap, 8.0)
	_verif(reste < 0.6, "après une mort la porte reste ouverte (reste %.2f m)" % reste)
	q.vus.erase("grotte:levier_goulot")
	jeu._etat()
	await _attendre(0.3)
	reste = await _marcher(cap, av, ap, 5.0)
	_verif(reste > 3.0, "partie neuve (état effacé) : porte refermée (%.1f m du but)" % reste)
	print("TOUT OK" if _echecs == 0 else "%d ECHEC(S)" % _echecs)
	quit(_echecs)
