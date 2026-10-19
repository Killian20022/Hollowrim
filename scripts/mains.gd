extends Node3D
## Mains du joueur (enfant de la caméra) : épée à droite, torche à gauche.
## Clic gauche : coup léger (les coups alternent droite/gauche). Maintenir : coup puissant.
## Clic droit maintenu : garde (une garde levée juste avant l'impact = parade).
## T : sortir / ranger la torche.


enum { REPOS, ARMER, CHARGE, FRAPPE, RETOUR, GARDE, ENCAISSE }

const DEGATS_LEGER := 14.0
const DEGATS_PUISSANT := 34.0
const COUT_LEGER := 8.0
const COUT_PUISSANT := 26.0
const SEUIL_CHARGE := 0.28  # durée d'appui au-delà de laquelle le coup devient puissant

# poses de l'épée : [position, rotation en degrés (x, y, z)] pour un coup de droite à gauche ;
# le coup inverse utilise la pose miroir.
const POSES := {
	"repos": [Vector3(0.30, -0.36, -0.58), Vector3(-30, 0, 12)],
	"armer": [Vector3(0.42, -0.16, -0.50), Vector3(15, -20, -62)],
	"charge": [Vector3(0.46, -0.08, -0.40), Vector3(30, -28, -75)],
	"frappe": [Vector3(-0.24, -0.38, -0.6), Vector3(-70, 30, 92)],
	"garde": [Vector3(0.12, -0.26, -0.56), Vector3(-10, 10, 78)],
	"encaisse": [Vector3(0.16, -0.18, -0.48), Vector3(5, 10, 92)],
}

var joueur: CharacterBody3D
var bloque := false
var temps_garde := 0.0
var torche_sortie := true

var etat := REPOS
var _t := 0.0
var _appui := -1.0
var _sens := 1.0
var _puissant := false
var _touche_faite := false
var _depuis_coup := 9.0
var _depart := Transform3D()
var _balance := Vector2.ZERO
var _respiration := 0.0
var _pose_figee := ""
var _baisse := 0.0

var pivot_epee: Node3D
var pivot_torche: Node3D
var torche_lumiere: OmniLight3D
var flamme: GPUParticles3D
var bras_epee: MeshInstance3D
var bras_torche: MeshInstance3D

func _ready() -> void:
	pivot_epee = Node3D.new()
	add_child(pivot_epee)
	pivot_epee.add_child(_epee())
	joueur.inventaire.change.connect(_teinte_epee)
	bras_epee = _main(pivot_epee, 1.0)
	pivot_epee.transform = _pose("repos")
	_depart = pivot_epee.transform

	pivot_torche = Node3D.new()
	pivot_torche.position = Vector3(-0.34, -0.44, -0.62)
	pivot_torche.rotation_degrees = Vector3(-14, 0, -12)
	add_child(pivot_torche)
	_torche()
	bras_torche = _main(pivot_torche, -1.0)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mains="):
			_pose_figee = a.substr(8)

## Gant de cuir qui tient l'objet ; l'avant-bras est un cylindre recalé à chaque image
## entre une épaule hors écran et le poing.
func _main(pivot: Node3D, cote: float) -> MeshInstance3D:
	var cuir := Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5))
	var poing := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.075, 0.09, 0.085)
	poing.mesh = b
	poing.material_override = cuir
	pivot.add_child(poing)
	var bras := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.05
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	bras.mesh = c
	bras.material_override = cuir
	add_child(bras)
	return bras

func _recaler_bras(bras: MeshInstance3D, epaule: Vector3, poing: Vector3) -> void:
	var axe := poing - epaule
	var base := Basis(Quaternion(Vector3.UP, axe.normalized()))
	bras.transform = Transform3D(base.scaled_local(Vector3(1, axe.length() * 0.92, 1)), epaule + axe * 0.46)

## Épée nordique à une main : lame à section losange, garde droite, poignée de cuir, pommeau.
func _epee() -> MeshInstance3D:
	var acier := Palette.materiau(Palette.tex("acier", Palette.ACIER, 4, 0.3), Vector2(1, 4), Color(0.85, 0.9, 1.0))
	_acier = acier
	var fer := Palette.materiau(Palette.tex("acier", Palette.ACIER, 4, 0.3), Vector2.ONE, Color(0.55, 0.58, 0.66))
	var cuir := Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(1, 3))
	var mesh := ArrayMesh.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# section : tranchant gauche, plat avant, tranchant droit, plat arrière
	var section := [Vector2(-0.026, 0), Vector2(0, 0.007), Vector2(0.026, 0), Vector2(0, -0.007)]
	var anneaux := [[0.1, 1.0], [0.62, 0.85]]
	var pointe := Vector3(0, 0.8, 0)
	for k in 4:
		var a0: Vector2 = section[k]
		var a1: Vector2 = section[(k + 1) % 4]
		var b0 := Vector3(a0.x, anneaux[0][0], a0.y) * Vector3(anneaux[0][1], 1, 1)
		var b1 := Vector3(a1.x, anneaux[0][0], a1.y) * Vector3(anneaux[0][1], 1, 1)
		var h0 := Vector3(a0.x * anneaux[1][1], anneaux[1][0], a0.y)
		var h1 := Vector3(a1.x * anneaux[1][1], anneaux[1][0], a1.y)
		_tri(st, b1, b0, h0, Vector2(1, 1), Vector2(0, 1), Vector2(0, 0.2))
		_tri(st, b1, h0, h1, Vector2(1, 1), Vector2(0, 0.2), Vector2(1, 0.2))
		_tri(st, h1, h0, pointe, Vector2(1, 0.2), Vector2(0, 0.2), Vector2(0.5, 0))
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, acier)

	var garde := BoxMesh.new()
	garde.size = Vector3(0.17, 0.028, 0.034)
	var pommeau := SphereMesh.new()
	pommeau.radius = 0.024
	pommeau.height = 0.042
	pommeau.radial_segments = 6
	pommeau.rings = 3
	var poignee := CylinderMesh.new()
	poignee.top_radius = 0.016
	poignee.bottom_radius = 0.018
	poignee.height = 0.13
	poignee.radial_segments = 6
	poignee.rings = 1
	for partie in [[garde, fer, Vector3(0, 0.088, 0)], [pommeau, fer, Vector3(0, -0.05, 0)], [poignee, cuir, Vector3(0, 0.015, 0)]]:
		var arrays: Array = partie[0].get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] += partie[2]
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, partie[1])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

var _acier: ShaderMaterial

## L'Épée de Skarnholt, forgée par Brodd : lame claire aux reflets dorés.
func _teinte_epee() -> void:
	if _acier != null and joueur.inventaire.a("epee_skarnholt"):
		_acier.set_shader_parameter("teinte", Color(1.15, 1.05, 0.85))
		_acier.set_shader_parameter("emission", Color(0.05, 0.04, 0.02))

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(uc); st.add_vertex(c)

func _torche() -> void:
	var baton := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.022
	c.bottom_radius = 0.026
	c.height = 0.42
	c.radial_segments = 5
	c.rings = 1
	baton.mesh = c
	baton.material_override = Palette.materiau(Palette.tex("ecorce", Palette.ECORCE), Vector2(1, 3))
	baton.position = Vector3(0, 0.08, 0)
	pivot_torche.add_child(baton)
	var tete := MeshInstance3D.new()
	var t := CylinderMesh.new()
	t.top_radius = 0.045
	t.bottom_radius = 0.035
	t.height = 0.11
	t.radial_segments = 6
	t.rings = 1
	tete.mesh = t
	tete.material_override = Palette.materiau(Palette.tex("chiffon", ["#2a1a10", "#3b2414", "#1a0f08", "#4a2e18"], 8, 0.6))
	tete.position = Vector3(0, 0.31, 0)
	pivot_torche.add_child(tete)

	flamme = GPUParticles3D.new()
	flamme.amount = 32
	flamme.lifetime = 0.3
	flamme.local_coords = true
	flamme.position = Vector3(0, 0.36, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.035
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.6, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	g.colors = PackedColorArray([Color(3.0, 2.3, 0.9), Color(2.6, 1.0, 0.25), Color(1.2, 0.25, 0.05), Color(0.3, 0.05, 0.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	flamme.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	flamme.draw_pass_1 = q
	pivot_torche.add_child(flamme)

	torche_lumiere = OmniLight3D.new()
	torche_lumiere.light_color = Color(1.0, 0.58, 0.28)
	torche_lumiere.light_energy = 1.5
	torche_lumiere.omni_range = 10.0
	torche_lumiere.omni_attenuation = 1.3
	torche_lumiere.position = Vector3(0, 0.42, 0.08)
	pivot_torche.add_child(torche_lumiere)

func _pose(nom: String, sens := 1.0) -> Transform3D:
	var p: Vector3 = POSES[nom][0]
	var r: Vector3 = POSES[nom][1]
	if sens < 0.0:
		p.x = -p.x
		r.y = -r.y
		r.z = -r.z
	return Transform3D(Basis.from_euler(r * (PI / 180.0)), p)

func _unhandled_input(e: InputEvent) -> void:
	if joueur == null or joueur.mort or joueur.en_dialogue or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventMouseMotion:
		_balance += Vector2(e.screen_relative.x, e.screen_relative.y) * 0.00035
		_balance = _balance.limit_length(0.05)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and etat in [REPOS, RETOUR] and not bloque:
			_appui = 0.0
			_changer(ARMER)
		elif not e.pressed and _appui >= 0.0:
			_puissant = _appui >= SEUIL_CHARGE
			_appui = -1.0
			if etat in [ARMER, CHARGE]:
				_lancer_coup()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_T:
		torche_sortie = not torche_sortie
		Sons.jouer(self, ["cloth1", "cloth2"], -8.0)

func attaquer(puissant := false) -> void:
	## Pour les tests automatiques : un coup complet sans souris.
	_puissant = puissant
	_changer(ARMER)
	await get_tree().create_timer(0.35 if puissant else 0.09).timeout
	_lancer_coup()

func _lancer_coup() -> void:
	var cout := COUT_PUISSANT if _puissant else COUT_LEGER
	if joueur.vigueur <= 0.0:
		_puissant = false
	joueur.depenser(cout)
	Sons.jouer(self, ["swing", "swing2", "swing3"], -2.0 if _puissant else -5.0, 0.12)
	_changer(FRAPPE)

func _changer(nouvel: int) -> void:
	etat = nouvel
	_t = 0.0
	_depart = pivot_epee.transform
	if nouvel == FRAPPE:
		_touche_faite = false

func encaisser() -> void:
	_changer(ENCAISSE)

func _process(dt: float) -> void:
	if joueur == null:
		return
	_t += dt
	_depuis_coup += dt
	_respiration += dt
	if _appui >= 0.0:
		_appui += dt
	if _pose_figee != "":
		pivot_epee.transform = _pose(_pose_figee, 1.0)
		etat = -1

	var veut_garde: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not joueur.mort
	if veut_garde and etat == REPOS:
		_changer(GARDE)
		temps_garde = 0.0
	bloque = etat in [GARDE, ENCAISSE]
	if bloque:
		temps_garde += dt

	var cible := _pose("repos")
	var vitesse := 10.0
	match etat:
		ARMER:
			cible = _pose("armer", _sens)
			vitesse = 22.0
			if _appui >= SEUIL_CHARGE:
				_changer(CHARGE)
		CHARGE:
			cible = _pose("charge", _sens)
			vitesse = 6.0
		FRAPPE:
			var duree := 0.2 if _puissant else 0.15
			var k := clampf(_t / duree, 0.0, 1.0)
			pivot_epee.transform = _depart.interpolate_with(_pose("frappe", _sens), ease(k, 0.45))
			if not _touche_faite and k >= 0.45:
				_touche_faite = true
				_tester_coup()
			if k >= 1.0:
				_changer(RETOUR)
				_sens = -_sens
				_depuis_coup = 0.0
		RETOUR:
			vitesse = 9.0
			if _t > 0.3:
				_changer(REPOS)
				if _depuis_coup > 0.9:
					_sens = 1.0
		GARDE:
			cible = _pose("garde")
			vitesse = 18.0
			if not veut_garde:
				_changer(REPOS)
		ENCAISSE:
			cible = _pose("encaisse")
			vitesse = 25.0
			if _t > 0.18:
				_changer(GARDE if veut_garde else REPOS)
	if etat != FRAPPE and _pose_figee == "":
		pivot_epee.transform = pivot_epee.transform.interpolate_with(cible, 1.0 - exp(-vitesse * dt))

	# inertie de la souris et respiration
	_balance = _balance.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * dt))
	var souffle := sin(_respiration * 1.6) * 0.006
	# pendant une conversation, on baisse les armes
	_baisse = lerpf(_baisse, 0.45 if joueur.en_dialogue else 0.0, 1.0 - exp(-6.0 * dt))
	position = Vector3(-_balance.x, _balance.y + souffle - _baisse, 0.0)

	# torche : baissée pendant la garde, rangée avec T
	var y_torche := -0.44
	if bloque:
		y_torche = -0.58
	if not torche_sortie:
		y_torche = -0.95
	pivot_torche.position.y = lerpf(pivot_torche.position.y, y_torche, 1.0 - exp(-8.0 * dt))
	var allumee := torche_sortie or pivot_torche.position.y > -0.8
	flamme.emitting = allumee
	torche_lumiere.visible = allumee
	torche_lumiere.light_energy = 1.4 + sin(_respiration * 13.0) * 0.12 + sin(_respiration * 29.0) * 0.08 + randf() * 0.12
	_recaler_bras(bras_epee, Vector3(0.42, -0.85, 0.05), pivot_epee.position)
	_recaler_bras(bras_torche, Vector3(-0.42, -0.85, 0.05), pivot_torche.position)

func _tester_coup() -> void:
	var cam := get_parent() as Node3D
	var origine := cam.global_position
	var face := -cam.global_transform.basis.z
	var face_plate := Vector2(face.x, face.z).normalized()
	var portee := 2.7 if _puissant else 2.3
	var resultat := ""
	for e in get_tree().get_nodes_in_group("ennemis"):
		if not e.vivant():
			continue
		var cible_coup: Vector3 = e.point_impact() if e.has_method("point_impact") else e.global_position + Vector3(0, 1.0, 0)
		var v: Vector3 = cible_coup - origine
		var d := v.length()
		if d > portee + 0.4:
			continue
		if d > 0.9 and Vector2(v.x, v.z).normalized().dot(face_plate) < 0.5:
			continue
		var base := DEGATS_PUISSANT if _puissant else DEGATS_LEGER
		if joueur.inventaire.a("epee_skarnholt"):
			base *= 1.35
		var r: String = e.recevoir_coup(base * joueur.competences.multiplicateur_degats(), joueur.global_position, _puissant)
		if r == "touche" or r == "tue":
			joueur.competences.pratiquer("epee", 1.8 if _puissant else 1.0)
		joueur.ennemi_vise = e
		if r == "bloque" and resultat == "":
			resultat = "bloque"
		elif r != "bloque":
			resultat = "touche"
	if resultat == "touche":
		Effets.arret_image(get_tree(), 0.11 if _puissant else 0.06)
		joueur.secousse = maxf(joueur.secousse, 0.5 if _puissant else 0.25)
	elif resultat == "bloque":
		# l'épée rebondit sur le bouclier
		_changer(ENCAISSE)
		joueur.secousse = maxf(joueur.secousse, 0.3)
