class_name FeuFixe
extends Node3D
## Feux FIXES en gros pixels (feu de camp du village, braseros, foyer-forge, lits de braises des maisons) : pilote + fabriques.
## Même langage que la torche tenue (shaders/flamme_fixe.gdshader, dérivé de flamme_pixels.gdshader : cases d'écran entières, 5 tons
## francs, pied arrondi enfoui dans le support) mais sans inertie : souffle du vent (uniform global `vent_monde`) + petit mouvement vivant.
##   - `camp(parent, sol)` : grand feu de plusieurs langues autour des bûches, lit de braises qui pulse, braises qui montent, fumée
##     en gros pixels sombres, halo de chaleur en paliers au sol et en lueur, distorsion de chaleur par blocs, une lumière à paliers ;
##   - `lit_de_braises(...)`, `halo_sol(...)`, `etincelles(...)` : briques réutilisées par la forge et les foyers des maisons ;
##   - `forge(...)` : foyer enfermé, étincelles en continu et gerbe quand Brodd forge (groupe « foyer_forge », `activer()`).
## PERFORMANCE : tout est coupé au-delà de `dist_max` (aucun calcul, rien d'affiché) ; la distorsion au-delà de 25 m ; au plus
## MAX_LUMIERES lumières dynamiques de feux fixes allumées en même temps (les plus proches, classement 4 fois par seconde).
## Le vent : `FeuFixe.regler_vent(v)` (monde.gd, avec les rafales du son du vent ; nul sous terre).

const SHADER_FLAMME := preload("res://shaders/flamme_fixe.gdshader")
const SHADER_BRAISES := preload("res://shaders/feu_lit_braises.gdshader")
const SHADER_HALO_SOL := preload("res://shaders/feu_halo_sol.gdshader")
const SHADER_CHALEUR := preload("res://shaders/feu_chaleur.gdshader")
const SHADER_HALO := preload("res://shaders/halo_sprite.gdshader")
const SHADER_GERBE := preload("res://shaders/gerbe_pixels.gdshader")
const MAX_LUMIERES := 4
const COULEUR_LUMIERE := Color(1.0, 0.55, 0.22)

static var vent := Vector3(0.45, 0.0, 0.2)
static var _actifs: Array[FeuFixe] = []
static var _dernier_classement := 0

# --- réglages du pilote -----------------------------------------------------------------------------------------------------
var dist_max := 45.0
var dist_chaleur := 25.0
var lumiere: OmniLight3D
var energie := 3.0
var portee_lum := 14.0
var phase := 0.0
var cachables: Array[Node3D] = []        # tout ce qui disparaît au-delà de dist_max
var chaleur: Node3D
var halo_sol_mat: ShaderMaterial
var halo_sol_base := 0.5
var halo_sprite_mat: ShaderMaterial
var halo_sprite_base := 0.7
var braises_mats: Array[ShaderMaterial] = []
var particules_vent: Array[GPUParticles3D] = []   # gravité horizontale = vent
var rafale_etincelles: GPUParticles3D            # forge : gerbe quand elle s'active
var _d := 1e9
var _loin := false
var _autorise := true
var _t := 0.0
var _boost := 0.0
var _vent_vu := Vector3.ZERO

# ------------------------------------------------------------------------------------------------ vent global
static func regler_vent(v: Vector3) -> void:
	vent = v
	RenderingServer.global_shader_parameter_set("vent_monde", v)

# ------------------------------------------------------------------------------------------------ briques
static func _carte(parent: Node3D, pos: Vector3, mat: Material, taille: Vector2, couche := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = taille
	if couche:
		q.orientation = PlaneMesh.FACE_Y                # carte horizontale (normale +Y)
	else:
		q.center_offset = Vector3(0, 0.5, 0)
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	return mi

## Matériau de flamme fixe. `cell_m` : taille d'une case (m) ; la flamme fait 14 cases de haut.
static func materiau_flamme(cell_m: float, phase_: float, large := 1.0, braises := 0.0, cuit := 0.0, abri := false) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_FLAMME
	sm.set_shader_parameter("cell_m", cell_m)
	sm.set_shader_parameter("phase_u", phase_)
	sm.set_shader_parameter("large", large)
	sm.set_shader_parameter("braises", braises)
	sm.set_shader_parameter("cuit", cuit)
	sm.set_shader_parameter("vent_k", 0.0 if abri else 1.0)
	return sm

## Une langue de flamme (quad écran accroché au pied).
static func langue(parent: Node3D, pos: Vector3, cell_m: float, phase_: float, large := 1.0, braises := 0.0, cuit := 0.0, abri := false) -> MeshInstance3D:
	var mi := _carte(parent, pos, materiau_flamme(cell_m, phase_, large, braises, cuit, abri), Vector2(1, 1), false)
	mi.extra_cull_margin = 3.0
	return mi

## Lit de braises : carte horizontale (ellipse de `taille` m) en cases de monde qui pulsent. Rend le matériau.
static func lit_de_braises(parent: Node3D, pos: Vector3, taille: Vector2, case_m := 0.05) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_BRAISES
	sm.set_shader_parameter("case_m", case_m)
	return _carte(parent, pos, sm, taille)

## Halo de chaleur au sol en paliers (carte horizontale, `diametre` m).
static func halo_sol(parent: Node3D, pos: Vector3, diametre: float, intensite := 0.5, teinte := Color(1.0, 0.50, 0.16)) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_HALO_SOL
	sm.set_shader_parameter("intensite", intensite)
	sm.set_shader_parameter("teinte", teinte)
	return _carte(parent, pos, sm, Vector2(diametre, diametre))

## Lueur (carte face à la caméra, anneaux en paliers de la texture « halo »).
static func halo_face(parent: Node3D, pos: Vector3, taille: float, intensite: float) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_HALO
	sm.set_shader_parameter("halo", ObjetsTextures.tex("halo"))
	sm.set_shader_parameter("taille", taille)
	sm.set_shader_parameter("intensite", intensite)
	return _carte(parent, pos, sm, Vector2(1, 1), false)

## Particules de petits carrés nets (shader des gerbes). `couleurs` : rampe en paliers ; `alphas` : opacité sur la vie.
static func particules(parent: Node3D, pos: Vector3, nombre: int, duree: float, vmin: float, vmax: float, rayon: float, echelle: Vector2,
		px: Vector2, couleurs: PackedColorArray, alphas: PackedColorArray, gravite := Vector3(0, 0.3, 0), spread := 20.0, fps := 24) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.local_coords = false
	p.position = pos
	p.fixed_fps = fps
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 9, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rayon
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = gravite
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.scale_min = echelle.x
	pm.scale_max = echelle.y
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	for i in couleurs.size():
		offs.append(float(i) / float(couleurs.size()))
	g.offsets = offs
	g.colors = couleurs
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 64
	pm.color_initial_ramp = gt
	var ga := Gradient.new()
	var offa := PackedFloat32Array()
	for i in alphas.size():
		offa.append(float(i) / float(alphas.size() - 1))
	ga.offsets = offa
	ga.colors = alphas
	var gat := GradientTexture1D.new()
	gat.gradient = ga
	pm.color_ramp = gat
	p.process_material = pm
	var q := QuadMesh.new()
	var mq := ShaderMaterial.new()
	mq.shader = SHADER_GERBE
	mq.set_shader_parameter("taille_min", px.x)
	mq.set_shader_parameter("taille_max", px.y)
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

# ------------------------------------------------------------------------------------------------ feu de camp
## Grand feu de camp du village. `sol` : centre du foyer au niveau du sol (couronne de pierres r 0,62, bûches en tipi jusqu'à 0,8 m).
## Rend le pilote ; `lumiere` est l'OmniLight3D du feu (le son du feu s'y accroche).
static func camp(parent: Node3D, sol: Vector3) -> FeuFixe:
	var f := FeuFixe.new()
	f.name = "FeuDeCampPixels"
	f.position = sol
	f.energie = 5.2
	f.portee_lum = 16.0
	f.dist_max = 60.0
	parent.add_child(f)
	# lit de braises + halos
	var lit := lit_de_braises(f, Vector3(0, 0.115, 0), Vector2(1.0, 1.0), 0.05)
	f.braises_mats.append(lit.material_override as ShaderMaterial)
	f.cachables.append(lit)
	var hs := halo_sol(f, Vector3(0, 0.07, 0), 11.0, 0.55)
	f.halo_sol_mat = hs.material_override as ShaderMaterial
	f.halo_sol_base = 0.55
	f.cachables.append(hs)
	var hf := halo_face(f, Vector3(0, 0.6, 0), 4.2, 0.55)
	f.halo_sprite_mat = hf.material_override as ShaderMaterial
	f.halo_sprite_base = 0.55
	f.cachables.append(hf)
	# langues : une grande au centre, quatre autour (hauteurs et phases différentes), pieds dans les bûches
	var langues := [
		[Vector3(0.0, 0.10, 0.0), 0.080, 1.25, 0.9],
		[Vector3(0.20, 0.10, 0.05), 0.058, 1.1, 0.6],
		[Vector3(-0.18, 0.10, 0.12), 0.064, 1.1, 0.6],
		[Vector3(0.05, 0.10, -0.2), 0.052, 1.0, 0.5],
		[Vector3(-0.1, 0.12, -0.08), 0.070, 1.15, 0.8],
	]
	for i in langues.size():
		var l: Array = langues[i]
		var m := langue(f, l[0], l[1], 0.9 + i * 1.37, l[2], l[3])
		f.cachables.append(m)
	# braises qui montent et dérivent (jaune → orange → rouge), carrés de 2 à 4 px
	var br := particules(f, Vector3(0, 0.45, 0), 26, 2.8, 0.7, 1.7, 0.22, Vector2(0.014, 0.026), Vector2(2.0, 4.0),
		PackedColorArray([Color("#fff0a0"), Color("#ffc83a"), Color("#f07319"), Color("#e04418")]),
		PackedColorArray([Color(1, 1, 1, 1), Color(0.9, 0.55, 0.3, 1), Color(0.5, 0.2, 0.1, 0.5), Color(0.3, 0.1, 0.1, 0)]),
		Vector3(0.0, 0.35, 0.0), 14.0)
	f.particules_vent.append(br)
	f.cachables.append(br)
	# colonne de fumée légère : gros carrés sombres, chauds au pied puis gris, opacité en paliers
	var fu := particules(f, Vector3(0, 1.15, 0), 12, 5.0, 0.55, 0.95, 0.18, Vector2(0.07, 0.13), Vector2(5.0, 11.0),
		PackedColorArray([Color(0.26, 0.17, 0.14), Color(0.17, 0.14, 0.14), Color(0.13, 0.12, 0.13)]),
		PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0)]),
		Vector3(0.0, 0.12, 0.0), 10.0, 12)
	f.particules_vent.append(fu)
	f.cachables.append(fu)
	# distorsion de chaleur (un plan, lit l'image rendue) : seulement près
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_CHALEUR
	var ch := _carte(f, Vector3(0, 1.0, 0), sm, Vector2(1, 1), false)
	f.chaleur = ch
	# lumière à paliers
	var l := OmniLight3D.new()
	l.light_color = COULEUR_LUMIERE
	l.light_energy = f.energie
	l.omni_range = f.portee_lum
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.position = Vector3(0, 0.9, 0)
	f.add_child(l)
	f.lumiere = l
	return f

# ------------------------------------------------------------------------------------------------ forge / foyer enfermé
## Étincelles d'un foyer de forge : un filet continu + une gerbe (`activer()`). Pas de lumière propre (celle de l'intérieur reste).
## `pos` : au-dessus des braises, dans le repère de `parent` (racine de l'intérieur).
static func forge(parent: Node3D, pos: Vector3, largeur: float) -> FeuFixe:
	var f := FeuFixe.new()
	f.name = "FeuForge"
	f.position = pos
	f.dist_max = 14.0
	f.add_to_group("foyer_forge")
	parent.add_child(f)
	var couleurs := PackedColorArray([Color("#fff5b0"), Color("#ffc83a"), Color("#f07319"), Color("#c43014")])
	var alphas := PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.45, 0.3, 1), Color(0.4, 0.15, 0.1, 0)])
	var filet := particules(f, Vector3.ZERO, 8, 1.2, 0.5, 1.3, largeur * 0.35, Vector2(0.012, 0.02), Vector2(2.0, 4.0), couleurs, alphas, Vector3(0, -0.4, 0), 35.0)
	f.cachables.append(filet)
	var gerbe := particules(f, Vector3.ZERO, 36, 1.4, 1.2, 3.2, largeur * 0.3, Vector2(0.012, 0.024), Vector2(2.0, 4.0), couleurs, alphas, Vector3(0, -3.2, 0.5), 55.0)
	gerbe.one_shot = true
	gerbe.explosiveness = 0.95
	gerbe.emitting = false
	f.rafale_etincelles = gerbe
	f.cachables.append(gerbe)
	return f

## La forge s'active (amélioration d'un objet chez Brodd) : gerbe d'étincelles + les braises du foyer s'avivent 2,5 s.
func activer() -> void:
	_boost = 2.5
	if rafale_etincelles != null:
		rafale_etincelles.restart()
		rafale_etincelles.emitting = true

# ------------------------------------------------------------------------------------------------ pilote
func _enter_tree() -> void:
	_actifs.append(self)

func _exit_tree() -> void:
	_actifs.erase(self)

func _ready() -> void:
	phase = randf() * 10.0
	set_process(true)

static func _classer(cam_pos: Vector3) -> void:
	var maintenant := Time.get_ticks_msec()
	if maintenant - _dernier_classement < 250:
		return
	_dernier_classement = maintenant
	var proches: Array[FeuFixe] = []
	for a in _actifs:
		a._d = cam_pos.distance_to(a.global_position)
		a._autorise = false
		if a.lumiere != null and a._d < a.portee_lum * 1.6:
			proches.append(a)
	proches.sort_custom(func(x: FeuFixe, y: FeuFixe) -> bool: return x._d < y._d)
	for i in mini(MAX_LUMIERES, proches.size()):
		proches[i]._autorise = true

func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_classer(cam.global_position)
	_d = cam.global_position.distance_to(global_position)
	var loin := _d > dist_max
	if loin != _loin:
		_loin = loin
		for n in cachables:
			if is_instance_valid(n):
				n.visible = not loin
		if loin and lumiere != null:
			lumiere.visible = false
		if loin and chaleur != null:
			chaleur.visible = false
	if loin:
		return
	_t += dt
	_boost = maxf(_boost - dt, 0.0)
	if chaleur != null:
		chaleur.visible = _d < dist_chaleur
	# vent → dérive des braises et de la fumée (gravité horizontale), seulement si le vent a changé
	if not vent.is_equal_approx(_vent_vu):
		_vent_vu = vent
		for p in particules_vent:
			((p.process_material) as ParticleProcessMaterial).gravity = Vector3(vent.x * 0.9, (p.process_material as ParticleProcessMaterial).gravity.y, vent.z * 0.9)
	# lumière à paliers (14 i/s) : scintillement + léger déplacement, sans stroboscope
	var palier := floorf(_t * 14.0 + phase)
	var s1 := fposmod(sin(palier * 12.9898) * 43758.5453, 1.0)
	var s2 := fposmod(sin(palier * 78.233 + 1.7) * 24634.6345, 1.0)
	var k := 1.0 + (s1 - 0.5) * 0.30 + sin(_t * 2.3 + phase) * 0.06 + sin(_t * 9.0 + phase) * 0.05 + (0.25 if _boost > 0.0 else 0.0)
	if lumiere != null:
		var on := _autorise and _d < portee_lum * 1.6
		lumiere.visible = on
		if on:
			lumiere.light_energy = energie * k
			lumiere.position = Vector3((s1 - 0.5) * 0.12, 0.9 + (s2 - 0.5) * 0.12, (s2 - 0.5) * 0.12)
			lumiere.light_color = COULEUR_LUMIERE.lerp(Color(1.0, 0.72, 0.38), clampf((k - 1.0) * 2.0, 0.0, 0.5))
	var pas := floorf(k * 6.0 + 0.5) / 6.0      # paliers de 1/6 pour les halos et le lit de braises
	if halo_sol_mat != null:
		halo_sol_mat.set_shader_parameter("pouls", pas)
		halo_sol_mat.set_shader_parameter("intensite", halo_sol_base)
	if halo_sprite_mat != null:
		halo_sprite_mat.set_shader_parameter("intensite", halo_sprite_base * pas)
	var pouls := 0.85 + 0.25 * (0.5 + 0.5 * sin(_t * 1.7 + phase)) + (0.35 if _boost > 0.0 else 0.0)
	pouls = floorf(pouls * 8.0 + 0.5) / 8.0
	for m in braises_mats:
		m.set_shader_parameter("pouls", pouls)
