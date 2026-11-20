extends SceneTree
## Non-régression de l'opti PiedsAuSol (2026-11-20) : deux personnages identiques sur deux pentes identiques, même animation au même instant ;
## l'un avec la version optimisée (poses de la chaîne calculées une fois), l'autre avec la version d'avant (--sans-opti-pieds). À chaque image,
## les cibles des pieds, les pôles des genoux, les inclinaisons et la pose finale des jambes (repère du personnage) doivent coïncider.
##   godot --headless --path . --script res://outils/test_pieds_opti.gd
## Sortie « TEST_PIEDS_OPTI OK » ou « ECHEC » (code 1).
const ECART := 0.0005      # m (ou rad) : arrondis flottants seulement

var persos: Array = []     # [corps, PiedsAuSol]
var k := 0
var pire := 0.0
var detail := {}
func _note(nom: String, v: float) -> void:
	detail[nom] = maxf(float(detail.get(nom, 0.0)), v)
	pire = maxf(pire, v)
var anims := ["Walk", "Idle", "Jog_Fwd", "Sprint"]

func _init() -> void:
	_go.call_deferred()

func _sol(x: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(4, 0.4, 4)
	cs.shape = b
	sb.add_child(cs)
	sb.position = Vector3(x, -0.2, 0)
	sb.rotation = Vector3(deg_to_rad(12.0), 0, deg_to_rad(9.0))
	root.add_child(sb)
	var marche := StaticBody3D.new()     # une marche sous le pied gauche
	var cs2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(0.3, 0.3, 0.6)
	cs2.shape = b2
	marche.add_child(cs2)
	marche.position = Vector3(x + 0.15, 0.0, 0.1)
	root.add_child(marche)

func _go() -> void:
	for i in 2:
		var x := 20.0 * i
		_sol(x)
		var c := CharacterBody3D.new()
		var f := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		f.shape = cap
		f.position.y = 0.9
		c.add_child(f)
		c.position = Vector3(x, 0.05, 0)
		root.add_child(c)
		var mod: Node3D = PnjNordique.creer("forgeron")
		c.add_child(mod)
		var p := PiedsAuSol.equiper(mod, c) as PiedsAuSol
		p._opti = (i == 0) if not OS.get_cmdline_user_args().has("--controle") else OS.get_cmdline_user_args().has("--controle-opti")
		var ap: AnimationPlayer = mod.get_node("Animations")
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		persos.append([c, p, ap, mod])
	for e in persos:
		(e[2] as AnimationPlayer).play(anims[0])

func _globale_finale(p: PiedsAuSol, sq: Skeleton3D, i: int) -> Transform3D:
	var t: Transform3D = p._finale[i]
	if not p._opti:
		return t
	var g := Transform3D()
	var chaine: Array[int] = []
	var b := i
	while b >= 0:
		chaine.push_front(b)
		b = sq.get_bone_parent(b)
	for os_i in chaine:
		g = g * (p._finale[os_i] if p._finale.has(os_i) else sq.get_bone_pose(os_i))
	return g

func _process(dt: float) -> bool:
	if persos.is_empty():
		return false
	k += 1
	if k % 90 == 0:
		var a: String = anims[(k / 90) % anims.size()]
		for e in persos:
			var ap: AnimationPlayer = e[2]
			if ap.has_animation(a):
				ap.play(a, 0.0)
	for e in persos:
		(e[2] as AnimationPlayer).advance(1.0 / 60.0)
	if k > 3:
		var a0: PiedsAuSol = persos[0][1]
		var a1: PiedsAuSol = persos[1][1]
		var dx := Vector3(20, 0, 0)
		var sq0 := a0.get_skeleton()
		var sq1 := a1.get_skeleton()
		for s in 2:
			_note("cible", (a0._cibles[s].global_position + dx - a1._cibles[s].global_position).length())
			_note("pole", (a0._poles[s].global_position + dx - a1._poles[s].global_position).length())
			_note("rot", a0._rot[s].angle_to(a1._rot[s]))
			_note("decal", absf(a0._decal[s] - a1._decal[s]))
		for i: int in a0._chaine():
			if a0._finale.has(i) and a1._finale.has(i):
				var g0 := _globale_finale(a0, sq0, i)
				var g1 := _globale_finale(a1, sq1, i)
				_note("finale_pos", (g0.origin - g1.origin).length())
				_note("finale_rot", g0.basis.get_rotation_quaternion().angle_to(g1.basis.get_rotation_quaternion()))
	if k >= 420:
		var ok := pire < ECART and a_finale()
		print("TEST_PIEDS_OPTI %s : écart maximal %.6f sur %d images (seuil %.4f), finale remplie=%s" % ["OK" if ok else "ECHEC", pire, k, ECART, str(a_finale())], " ", detail)
		quit(0 if ok else 1)
	return false

func a_finale() -> bool:
	return not (persos[0][1] as PiedsAuSol)._finale.is_empty() and not (persos[1][1] as PiedsAuSol)._finale.is_empty()
