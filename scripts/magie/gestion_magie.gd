class_name GestionMagie
extends Node3D
## Moteur des VISUELS de la magie (aucune logique de jeu) : un seul nœud « GestionMagie » par scène, créé à la demande par
## EffetsMagie (API publique : scripts/magie/effets_magie.gd ; doc : docs/MAGIE_EFFETS.md).
## Il possède :
##   - un pool d'émetteurs GPUParticles3D (particules = carrés de pixels, shaders/magie_part_*.gdshader), plafonné en
##     nombre d'émetteurs (MAX_EMETTEURS) et en particules vivantes (MAX_PARTICULES) ;
##   - un pool de MAX_LUMIERES OmniLight3D sans ombre, attribuées chaque image aux demandes les plus fortes ;
##   - les éclairs (traits pixel à largeur d'écran fixe, shaders/magie_trait.gdshader), plafonnés à MAX_ECLAIRS ;
##   - les cristaux (pics de nova, épines obscures) en MultiMesh (MAX_PICS par palette) ;
##   - les disques au sol (onde de choc, cercle runique, vortex), plafonnés à MAX_DISQUES ;
##   - l'état des effets persistants : auras des mains, jets canalisés, traînées des projectiles, statuts, enchantements,
##     zones, double incantation.
## Il tourne APRÈS les mains (process_priority) pour suivre le viewmodel sans retard d'une image.

const SH_ADD := preload("res://shaders/magie_part_add.gdshader")
const SH_MIX := preload("res://shaders/magie_part_mix.gdshader")
const SH_TRAIT := preload("res://shaders/magie_trait.gdshader")
const SH_CRISTAL := preload("res://shaders/magie_cristal.gdshader")
const SH_SOL := preload("res://shaders/magie_sol.gdshader")
const SH_SOL_MIX := preload("res://shaders/magie_sol_mix.gdshader")
const SH_VOILE := preload("res://shaders/magie_voile.gdshader")
const SH_TEINTE := preload("res://shaders/magie_teinte.gdshader")

const MAX_PARTICULES := 3000
const MAX_EMETTEURS := 64
const MAX_LUMIERES := 4
const MAX_ECLAIRS := 20
const MAX_PICS := 48
const MAX_DISQUES := 16
const MAX_STATUTS := 12
const MAX_PROJECTILES := 24
const POOL_GARDE := 24

## Couleurs des lumières dynamiques par école.
const LUMIERE := {
	"feu": Color(1.0, 0.55, 0.2), "glace": Color(0.45, 0.7, 1.0), "electricite": Color(0.55, 0.5, 1.0),
	"tenebres": Color(0.62, 0.25, 1.0), "soin": Color(1.0, 0.85, 0.45), "protection": Color(0.6, 0.8, 1.0),
}
## Palettes des cristaux : ombre, milieu, clair, reflet.
const CRISTAUX := {
	"glace": ["#1b2c5a", "#2f5fb8", "#7ab8f0", "#e8f6ff"],
	"tenebres": ["#0c0614", "#2a0e3e", "#5a1a8a", "#c070ff"],
	"corrompu": ["#1a0a30", "#3a2a7a", "#7a5ad0", "#e0b0ff"],
	"electricite": ["#2a1a6a", "#4a3ad0", "#9aa8ff", "#f0f2ff"],
	"feu": ["#5a1a1c", "#b3341f", "#fcb53a", "#fff0a8"],
	"soin": ["#3a5a1a", "#8ab040", "#f0d070", "#fff4c0"],
	"protection": ["#1a3050", "#3a6a9a", "#b8e0f0", "#eaf8ff"],
}
## Éclairs : [halo, cœur] par teinte.
const ARCS := {
	"electricite": ["#4a3ad0", "#f0f2ff"], "tenebres": ["#6a1aa0", "#f0c8ff"], "glace": ["#2f5fb8", "#e8f6ff"],
	"feu": ["#ec6a1f", "#fff0a8"], "drain": ["#7a1ad0", "#e8a8ff"], "soin": ["#8ab040", "#fff4c0"],
	"protection": ["#3a6a9a", "#eaf8ff"], "violet": ["#7a2ad0", "#f0d0ff"],
}

static var instance: GestionMagie

var horloge := 0.0
var rng := RandomNumberGenerator.new()
## Compteurs de refus (plafonds atteints), lus par les tests.
var refus := 0

var _libres: Array[GPUParticles3D] = []
var _emetteurs: Array = []        # {p, n, fin}
var _budget := 0
var _pms := {}
var _mats := {}
var _quad := QuadMesh.new()
var _mesh_eclat: ArrayMesh
var _mesh_pic: ArrayMesh
var _lumieres: Array[OmniLight3D] = []
var _demandes := {}               # cle -> {pos, noeud, couleur, energie, portee, prio, debut, fin, duree}
var _eclairs: Array = []          # {mi, im, fin, regen, prochain, gen, alpha}
var _libres_eclairs: Array[MeshInstance3D] = []
var _pics: Array = []             # {pal, pos, base, l, h, t0, monte, fin}
var _mm := {}                     # pal -> MultiMeshInstance3D
var _disques: Array = []          # {mi, mat, t0, duree, r0, r1, op, suivre}
var _auras := {}
var _jets := {}
var _projectiles: Array = []
var _statuts := {}
var _enchants := {}
var _zones: Array = []
var _double := {}
var _double_vis := {}
var _sphere: SphereMesh
var _plan := PlaneMesh.new()
var _quad_sol := QuadMesh.new()
var _teinte_calque: CanvasLayer
var _teinte_mat: ShaderMaterial
var _teinte_v := 0.0
var _teinte_cible := 0.0
var _teinte_c := Color.BLACK

# ====================================================================== cycle de vie

static func obtenir() -> GestionMagie:
	if instance != null and is_instance_valid(instance) and not instance.is_queued_for_deletion():
		return instance
	var arbre := Engine.get_main_loop() as SceneTree
	var g := GestionMagie.new()
	g.name = "GestionMagie"
	instance = g
	if arbre != null:
		var s: Node = arbre.current_scene if arbre.current_scene != null else arbre.root
		if s.is_node_ready():
			s.add_child(g)
		else:
			s.add_child.call_deferred(g)
	return g

func _init() -> void:
	process_priority = 100
	rng.randomize()
	_quad.size = Vector2.ONE
	_plan.size = Vector2(2, 2)
	_quad_sol.size = Vector2(2, 2)
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 8
	_sphere.rings = 4
	_mesh_eclat = _creer_eclat()
	_mesh_pic = _creer_pic()
	for i in MAX_LUMIERES:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		l.light_specular = 0.2
		l.distance_fade_enabled = true
		l.distance_fade_begin = 25.0
		l.distance_fade_length = 10.0
		add_child(l)
		_lumieres.append(l)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(dt: float) -> void:
	horloge += dt
	_maj_auras()
	_maj_jets()
	_maj_projectiles()
	_maj_statuts()
	_maj_enchants()
	_maj_zones()
	_maj_double()
	_maj_eclairs()
	_maj_pics()
	_maj_disques()
	_maj_emetteurs()
	_maj_lumieres()
	_maj_teinte(dt)

## Compteurs (tests, débogage).
func stats() -> Dictionary:
	var lum := 0
	for l in _lumieres:
		if l.visible:
			lum += 1
	return {"emetteurs": _emetteurs.size(), "particules": _budget, "lumieres": lum, "demandes_lumiere": _demandes.size(),
		"eclairs": _eclairs.size(), "pics": _pics.size(), "disques": _disques.size(), "statuts": _statuts.size(),
		"auras": _auras.size(), "jets": _jets.size(), "projectiles": _projectiles.size(), "enchants": _enchants.size(),
		"zones": _zones.size(), "refus": refus, "pool": _libres.size()}

## Éteint tout (changement de scène, tests).
func tout_arreter() -> void:
	for a in _auras.values():
		_aura_eteindre(a)
	_auras.clear()
	for j in _jets.values():
		_jet_arreter(j)
	_jets.clear()
	for k in _statuts.keys():
		_statut_retirer(k)
	for k in _enchants.keys():
		_enchant_retirer(k)
	_zones.clear()
	_double.clear()
	_maj_double()
	for e in _emetteurs:
		if is_instance_valid(e.p):
			e.p.emitting = false
		e.fin = minf(e.fin, horloge)
	for e in _eclairs:
		e.fin = horloge
	_pics.clear()
	for d in _disques:
		d.duree = 0.0
	_demandes.clear()

# ====================================================================== émetteurs de particules

func _nouveau_part() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.fixed_fps = 0
	p.interpolate = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	return p

## Lance un émetteur du réglage `nom` (PresetsMagie.R) sous `parent` (null = ce nœud, repère du monde) avec le repère
## local `xf`. Persistant : émet jusqu'à arreter(). Renvoie null si un plafond est atteint.
func emettre(nom: String, parent: Node, xf: Transform3D, persistant := false, k_n := 1.0, vie := -1.0, pm_perso: ParticleProcessMaterial = null) -> GPUParticles3D:
	var d: Dictionary = PresetsMagie.R.get(nom, {})
	if d.is_empty():
		push_warning("EffetsMagie : réglage inconnu « %s »" % nom)
		return null
	var n := maxi(1, int(round(float(d.n) * k_n)))
	if _emetteurs.size() >= MAX_EMETTEURS:
		if persistant or not _liberer_ponctuel():
			refus += 1
			return null
	var reste := MAX_PARTICULES - _budget
	if n > reste:
		n = reste
		if n < (2 if persistant else 4):
			refus += 1
			return null
	var p: GPUParticles3D = _libres.pop_back() if not _libres.is_empty() else _nouveau_part()
	p.amount = n
	p.lifetime = vie if vie > 0.0 else float(d.vie)
	p.one_shot = not persistant
	p.explosiveness = float(d.get("expl", 0.0))
	p.randomness = float(d.get("alea", 0.25))
	p.local_coords = bool(d.get("local", false))
	p.amount_ratio = 1.0
	p.speed_scale = 1.0
	p.process_material = pm_perso if pm_perso != null else _pm(nom, d)
	if String(d.get("mesh", "quad")) == "eclat":
		p.draw_pass_1 = _mesh_eclat
		p.material_override = _mat_cristal(String(d.get("pal", "glace")))
	else:
		p.draw_pass_1 = _quad
		p.material_override = _mat_part(bool(d.get("add", false)), float(d.get("cap", 6.0)), float(d.get("eclat", 1.3)))
	# les couches additives (cœurs, étincelles) passent par-dessus les corps opaques du même effet
	p.sorting_offset = 0.5 if bool(d.get("add", false)) else 0.0
	var ext := 2.0 if p.local_coords else 14.0
	p.visibility_aabb = AABB(Vector3.ONE * -ext, Vector3.ONE * ext * 2.0)
	var cible: Node = parent if parent != null else self
	if p.get_parent() != cible:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		cible.add_child(p)
	p.transform = xf
	p.visible = true
	p.restart()
	p.emitting = true
	var fin := INF if persistant else horloge + p.lifetime * (1.0 + p.randomness) + 0.25
	_emetteurs.append({"p": p, "n": n, "fin": fin})
	_budget += n
	return p

## Arrête un émetteur persistant : ses particules finissent leur vie, puis il retourne au pool.
func arreter(p: Variant) -> void:
	if p == null or not is_instance_valid(p):
		return   # un émetteur libéré avec son parent est retiré par _maj_emetteurs
	var g := p as GPUParticles3D
	for e in _emetteurs:
		if is_instance_valid(e.p) and e.p == g:
			g.emitting = false
			e.fin = minf(e.fin, horloge + g.lifetime * (1.0 + g.randomness) + 0.1)
			return

func _liberer_ponctuel() -> bool:
	# plafond d'émetteurs : le plus ancien ponctuel cède sa place
	var meilleur := -1
	for i in _emetteurs.size():
		if _emetteurs[i].fin < INF and (meilleur < 0 or _emetteurs[i].fin < _emetteurs[meilleur].fin):
			meilleur = i
	if meilleur < 0:
		return false
	_rendre(meilleur)
	return true

func _rendre(i: int) -> void:
	var e: Dictionary = _emetteurs[i]
	_emetteurs.remove_at(i)
	_budget -= int(e.n)
	if not is_instance_valid(e.p) or (e.p as Node).is_queued_for_deletion():
		return
	var p: GPUParticles3D = e.p
	p.emitting = false
	p.visible = false
	if p.get_parent() != self:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		add_child(p)
	if _libres.size() < POOL_GARDE:
		_libres.append(p)
	else:
		p.queue_free()

func _maj_emetteurs() -> void:
	var i := _emetteurs.size() - 1
	while i >= 0:
		var e: Dictionary = _emetteurs[i]
		if horloge >= e.fin or not is_instance_valid(e.p) or not (e.p as Node).is_inside_tree() and e.fin < INF:
			_rendre(i)
		i -= 1

## ParticleProcessMaterial partagé d'un réglage (cache) ; `r` (rayon) / `ext` (boîte) / `ecart` surchargent le réglage
## (copie mise en cache par valeur arrondie).
func _pm(nom: String, d: Dictionary, sur := {}) -> ParticleProcessMaterial:
	var cle := nom
	for k in sur:
		cle += "|%s=%s" % [k, str(sur[k])]
	if _pms.has(cle):
		return _pms[cle]
	var dd := d.duplicate()
	dd.merge(sur, true)
	var pm := ParticleProcessMaterial.new()
	pm.direction = dd.get("dir", Vector3.UP)
	pm.spread = float(dd.get("ecart", 0.0))
	var v: Vector2 = dd.get("vit", Vector2.ZERO)
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.gravity = dd.get("grav", Vector3.ZERO)
	var am: Vector2 = dd.get("amort", Vector2.ZERO)
	pm.damping_min = am.x
	pm.damping_max = am.y
	var ra: Vector2 = dd.get("radial", Vector2.ZERO)
	pm.radial_accel_min = ra.x
	pm.radial_accel_max = ra.y
	var rv: Vector2 = dd.get("radiale_v", Vector2.ZERO)
	pm.radial_velocity_min = rv.x
	pm.radial_velocity_max = rv.y
	var t: Vector2 = dd.get("taille", Vector2(0.03, 0.05))
	pm.scale_min = t.x
	pm.scale_max = t.y
	var courbe := String(dd.get("courbe", "plat"))
	if courbe != "plat":
		var c := Curve.new()
		match courbe:
			"monte":
				c.add_point(Vector2(0, 0.35))
				c.add_point(Vector2(1, 1.0))
			"descend":
				c.add_point(Vector2(0, 1.0))
				c.add_point(Vector2(1, 0.2))
			"bosse":
				c.add_point(Vector2(0, 0.3))
				c.add_point(Vector2(0.35, 1.0))
				c.add_point(Vector2(1, 0.45))
		var ct := CurveTexture.new()
		ct.curve = c
		pm.scale_curve = ct
	var r := float(dd.get("r", 0.0))
	match String(dd.get("forme", "point")):
		"sphere":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = r
		"surface":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			pm.emission_sphere_radius = r
		"boite":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = dd.get("ext", Vector3(0.25, 0.8, 0.25))
		"anneau":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = dd.get("axe", Vector3.UP)
			pm.emission_ring_radius = r
			pm.emission_ring_inner_radius = r * 0.92
			pm.emission_ring_height = 0.02
		"disque":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = r
			pm.emission_ring_inner_radius = 0.0
			pm.emission_ring_height = 0.05
	pm.particle_flag_align_y = String(dd.get("mesh", "quad")) == "eclat"
	if dd.has("turb"):
		# turbulence (bruit GPU) : flammes et fumées qui ondulent au lieu de filer droit
		var tu: Vector2 = dd.turb
		pm.turbulence_enabled = true
		pm.turbulence_influence_min = tu.x
		pm.turbulence_influence_max = tu.y
		pm.turbulence_noise_scale = float(dd.get("turb_echelle", 2.0))
		pm.turbulence_noise_strength = float(dd.get("turb_force", 1.0))
		pm.turbulence_noise_speed = Vector3(0, 0.6, 0)
	if dd.has("rampe"):
		pm.color_ramp = _rampe(dd.rampe, bool(dd.get("garde_fin", false)))
	_pms[cle] = pm
	return pm

## Rampe EN PALIERS (interpolation constante) : quelques couleurs franches, puis un palier transparent.
static func _rampe(couleurs: Array, garde_fin: bool) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cs: Array[Color] = []
	for c in couleurs:
		cs.append(Color(c) if c is String else c)
	if not garde_fin:
		var der := cs[cs.size() - 1]
		cs.append(Color(der, 0.0))
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in cs.size():
		offs.append(float(i) / float(cs.size()))
		cols.append(cs[i])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 64
	return gt

func _mat_part(add: bool, cap: float, eclat: float) -> ShaderMaterial:
	var cle := "p%s|%s|%s" % [add, cap, eclat]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_ADD if add else SH_MIX
		m.set_shader_parameter("taille_max", cap)
		m.set_shader_parameter("eclat", eclat)
		_mats[cle] = m
	return _mats[cle]

func _mat_cristal(pal: String, multimesh := false) -> ShaderMaterial:
	var cle := "c%s|%s" % [pal, multimesh]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_CRISTAL
		var c: Array = CRISTAUX.get(pal, CRISTAUX.glace)
		m.set_shader_parameter("c_ombre", Color(c[0]))
		m.set_shader_parameter("c_milieu", Color(c[1]))
		m.set_shader_parameter("c_clair", Color(c[2]))
		m.set_shader_parameter("c_reflet", Color(c[3]))
		m.set_shader_parameter("eclat", 1.15)
		m.set_shader_parameter("multimesh", multimesh)
		_mats[cle] = m
	return _mats[cle]

func _mat_coeur(couleur: Color, add := true, eclat := 1.5) -> Material:
	# matériau « particule » réutilisé pour les cœurs pleins (sphères lumineuses des projectiles)
	var cle := "s%s|%s|%s" % [couleur.to_html(), add, eclat]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(couleur.r * eclat, couleur.g * eclat, couleur.b * eclat, couleur.a)
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_fog = true
		m.disable_receive_shadows = true
		_mats[cle] = m
	return _mats[cle]

# ====================================================================== lumières (pool)

## Demande de lumière : persistante (duree <= 0, à renouveler chaque image) ou éclair bref qui décroît (duree > 0).
func lumiere(cle: String, pos: Vector3, couleur: Color, energie: float, portee: float, prio: float, duree := -1.0) -> void:
	var fin := horloge + (duree if duree > 0.0 else 0.12)
	_demandes[cle] = {"pos": pos, "couleur": couleur, "energie": energie, "portee": portee, "prio": prio,
		"debut": horloge, "fin": fin, "duree": duree}

func _maj_lumieres() -> void:
	var liste: Array = []
	for cle in _demandes.keys():
		var d: Dictionary = _demandes[cle]
		if horloge > d.fin:
			_demandes.erase(cle)
			continue
		var e := float(d.energie)
		if d.duree > 0.0:
			var k := clampf((horloge - d.debut) / d.duree, 0.0, 1.0)
			e *= (1.0 - k) * (1.0 - k)
		liste.append([float(d.prio) * (0.5 + e), d, e])
	liste.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in MAX_LUMIERES:
		var l := _lumieres[i]
		if i < liste.size():
			var d: Dictionary = liste[i][1]
			l.visible = true
			l.position = d.pos
			l.light_color = d.couleur
			l.light_energy = liste[i][2]
			l.omni_range = d.portee
		else:
			l.visible = false

# ====================================================================== teinte d'écran (discrète, pendant les jets)

## Demande de teinte (à renouveler chaque image) : halo coloré léger sur les bords de l'écran, couleur de l'école.
func _teinte_demande(ecole: String, k: float) -> void:
	if k > _teinte_cible:
		_teinte_cible = k
		_teinte_c = LUMIERE.get(ecole, LUMIERE.feu)

func _maj_teinte(dt: float) -> void:
	var cible := minf(_teinte_cible, 1.5)
	_teinte_cible = 0.0
	_teinte_v = move_toward(_teinte_v, cible, dt * (5.0 if cible > _teinte_v else 2.5))
	if _teinte_v <= 0.001:
		if _teinte_calque != null:
			_teinte_calque.visible = false
		return
	if _teinte_calque == null:
		_teinte_calque = CanvasLayer.new()
		_teinte_calque.layer = 1
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_teinte_mat = ShaderMaterial.new()
		_teinte_mat.shader = SH_TEINTE
		r.material = _teinte_mat
		_teinte_calque.add_child(r)
		add_child(_teinte_calque)
	_teinte_calque.visible = true
	_teinte_mat.set_shader_parameter("teinte", _teinte_c)
	_teinte_mat.set_shader_parameter("force", _teinte_v * 0.11)

# ====================================================================== éclairs (traits pixel)

## Éclair : `gen` (Callable sans argument) renvoie un Array de [PackedVector3Array (polyligne), largeur, alpha] ;
## redessiné toutes les `regen` s jusqu'à `duree` (duree < 0 : persistant, à couper avec eclair_fin).
func eclair(parent: Node, teinte: String, largeur: float, duree: float, regen: float, gen: Callable) -> Dictionary:
	if _eclairs.size() >= MAX_ECLAIRS:
		refus += 1
		return {}
	var mi: MeshInstance3D = _libres_eclairs.pop_back() if not _libres_eclairs.is_empty() else null
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
	mi.material_override = _mat_trait(teinte, largeur)
	var cible: Node = parent if parent != null else self
	if mi.get_parent() != cible:
		if mi.get_parent() != null:
			mi.get_parent().remove_child(mi)
		cible.add_child(mi)
	mi.transform = Transform3D.IDENTITY
	mi.visible = true
	# dessiné au prochain passage de _maj_eclairs (même image : ce nœud passe après les mains et la logique)
	var e := {"mi": mi, "fin": INF if duree < 0.0 else horloge + duree, "regen": regen, "prochain": 0.0, "gen": gen}
	_eclairs.append(e)
	return e

func eclair_fin(e: Dictionary) -> void:
	if not e.is_empty():
		e.fin = horloge

func _mat_trait(teinte: String, largeur: float) -> ShaderMaterial:
	var cle := "t%s|%s" % [teinte, largeur]
	if not _mats.has(cle):
		var c: Array = ARCS.get(teinte, ARCS.electricite)
		var m := ShaderMaterial.new()
		m.shader = SH_TRAIT
		m.set_shader_parameter("halo", Color(c[0]))
		m.set_shader_parameter("coeur", Color(c[1]))
		m.set_shader_parameter("largeur_halo", 1.0 + 2.0 * largeur)
		m.set_shader_parameter("largeur_coeur", largeur)
		_mats[cle] = m
	return _mats[cle]

func _eclair_dessiner(e: Dictionary) -> void:
	var mi: MeshInstance3D = e.mi
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	var traits: Array = (e.gen as Callable).call()
	var vide := true
	for t in traits:
		if (t[0] as PackedVector3Array).size() >= 2:
			vide = false
			break
	if vide:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in traits:
		var pts: PackedVector3Array = t[0]
		var w := float(t[1])
		var a := float(t[2])
		for i in range(1, pts.size()):
			var p0 := pts[i - 1]
			var p1 := pts[i]
			var d := p1 - p0
			if d.length_squared() < 1e-10:
				continue
			d = d.normalized()
			for couche in [0.0, 1.0]:
				_sommet_trait(im, p0, d, couche, -1.0, w, a)
				_sommet_trait(im, p0, d, couche, 1.0, w, a)
				_sommet_trait(im, p1, d, couche, 1.0, w, a)
				_sommet_trait(im, p0, d, couche, -1.0, w, a)
				_sommet_trait(im, p1, d, couche, 1.0, w, a)
				_sommet_trait(im, p1, d, couche, -1.0, w, a)
	im.surface_end()

static func _sommet_trait(im: ImmediateMesh, p: Vector3, d: Vector3, couche: float, cote: float, w: float, a: float) -> void:
	im.surface_set_normal(d)
	im.surface_set_color(Color(1, 1, 1, a))
	im.surface_set_uv(Vector2(couche, cote))
	im.surface_set_uv2(Vector2(w, 0))
	im.surface_add_vertex(p)

func _maj_eclairs() -> void:
	var i := _eclairs.size() - 1
	while i >= 0:
		var e: Dictionary = _eclairs[i]
		var mi: Variant = e.mi
		if not is_instance_valid(mi) or horloge >= e.fin:
			_eclairs.remove_at(i)
			if is_instance_valid(mi):
				((mi as MeshInstance3D).mesh as ImmediateMesh).clear_surfaces()
				mi.visible = false
				if mi.get_parent() != self:
					if mi.get_parent() != null:
						mi.get_parent().remove_child(mi)
					add_child(mi)
				_libres_eclairs.append(mi)
		elif horloge >= e.prochain:
			e.prochain = horloge + float(e.regen)
			_eclair_dessiner(e)
		i -= 1

## Polyligne d'éclair de a à b : déplacement du milieu (perpendiculaire au hasard), `prof` subdivisions.
func foudre(a: Vector3, b: Vector3, ampl: float, prof := 4) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var amp := ampl
	for _k in prof:
		var n := PackedVector3Array()
		for i in range(pts.size() - 1):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			n.append(p0)
			var d := p1 - p0
			var perp := d.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
			n.append((p0 + p1) * 0.5 + perp * rng.randf_range(-amp, amp))
		n.append(pts[pts.size() - 1])
		pts = n
		amp *= 0.55
	return pts

## Ajoute à `traits` un éclair de a à b et `ramifs` branches courtes.
func foudre_ramifiee(traits: Array, a: Vector3, b: Vector3, ampl: float, largeur: float, ramifs: int, prof := 4) -> void:
	var p := foudre(a, b, ampl, prof)
	traits.append([p, largeur, 1.0])
	var l := a.distance_to(b)
	for _k in ramifs:
		var i := rng.randi_range(1, maxi(1, p.size() - 2))
		var o := p[i]
		var dir := (b - a).normalized()
		var dev := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var fin := o + (dir + dev * 0.9).normalized() * l * rng.randf_range(0.12, 0.3)
		traits.append([foudre(o, fin, l * 0.06, 2), maxf(1.0, largeur - 1.0), 0.7])

# ====================================================================== cristaux (MultiMesh)

## Pic de cristal : base en `pos`, axe `haut`, largeur `l`, hauteur `h` ; pousse en `monte` s après `delai`, se brise
## (fonte par cases) à `fin` (temps absolu de l'horloge).
func pic(pal: String, pos: Vector3, haut: Vector3, l: float, h: float, delai: float, monte: float, fin: float) -> void:
	if not _mm.has(pal):
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _mesh_pic
		mm.instance_count = MAX_PICS
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = _mat_cristal(pal, true)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm[pal] = mmi
	var n := 0
	for p in _pics:
		if p.pal == pal:
			n += 1
	if n >= MAX_PICS:
		refus += 1
		return
	var y := haut.normalized()
	var x := y.cross(Vector3(0.3, 0.1, 1.0).normalized()).normalized()
	var base := Basis(x, y, x.cross(y)).rotated(y, rng.randf() * TAU)
	_pics.append({"pal": pal, "pos": pos, "base": base, "l": l, "h": h, "t0": horloge + delai, "monte": monte, "fin": fin})

func _maj_pics() -> void:
	var i := _pics.size() - 1
	while i >= 0:
		if horloge > _pics[i].fin + 0.45:
			_pics.remove_at(i)
		i -= 1
	var compte := {}
	for pal in _mm:
		compte[pal] = 0
	for p in _pics:
		var mmi: MultiMeshInstance3D = _mm[p.pal]
		var k := clampf((horloge - p.t0) / maxf(p.monte, 0.01), 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var fonte := clampf((horloge - p.fin) / 0.4, 0.0, 1.0)
		var b: Basis = p.base.scaled_local(Vector3(p.l, maxf(p.h * k, 0.001), p.l))
		var idx: int = compte[p.pal]
		mmi.multimesh.set_instance_transform(idx, Transform3D(b, p.pos))
		mmi.multimesh.set_instance_custom_data(idx, Color(fonte, 0, 0, 0))
		compte[p.pal] = idx + 1
	for pal in _mm:
		(_mm[pal] as MultiMeshInstance3D).multimesh.visible_instance_count = compte[pal]

# ====================================================================== disques au sol / face caméra

## Disque : `reglages` = paramètres du shader magie_sol (couleur, coeur, anneau, epaisseur, remplissage, runes,
## spirale, eclat, texels, tourne) ; rayon r0 → r1 en `duree` s ; opacité qui s'éteint sur la fin (`fondu` part).
func disque(pos: Vector3, normale: Vector3, r0: float, r1: float, duree: float, reglages: Dictionary, mix := false, face_camera := false, fondu := 0.4) -> Dictionary:
	if _disques.size() >= MAX_DISQUES:
		refus += 1
		return {}
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_sol if face_camera else _plan
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = SH_SOL_MIX if mix else SH_SOL
	for k in reglages:
		var v: Variant = reglages[k]
		m.set_shader_parameter(k, Color(v) if v is String else v)
	m.set_shader_parameter("face_camera", face_camera)
	mi.material_override = m
	add_child(mi)
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var base := Basis(x, y, x.cross(y))
	mi.transform = Transform3D(base.scaled_local(Vector3.ONE * maxf(r0, 0.001)), pos + y * 0.03)
	var d := {"mi": mi, "mat": m, "t0": horloge, "duree": duree, "r0": r0, "r1": r1, "op": float(reglages.get("opacite", 1.0)),
		"base": base, "pos": pos + y * 0.03, "fondu": fondu, "suivre": null}
	_disques.append(d)
	return d

func _maj_disques() -> void:
	var i := _disques.size() - 1
	while i >= 0:
		var d: Dictionary = _disques[i]
		var mi: Variant = d.mi
		var k := clampf((horloge - d.t0) / maxf(d.duree, 0.001), 0.0, 1.0)
		if k >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_disques.remove_at(i)
			i -= 1
			continue
		var r := lerpf(d.r0, d.r1, 1.0 - pow(1.0 - minf(k / 0.6, 1.0), 2.0))
		var pos: Vector3 = d.pos
		if d.suivre != null:
			if is_instance_valid(d.suivre) and (d.suivre as Node3D).is_inside_tree():
				pos = (d.suivre as Node3D).global_position
		(mi as MeshInstance3D).transform = Transform3D((d.base as Basis).scaled_local(Vector3.ONE * maxf(r, 0.001)), pos)
		var fondu := float(d.fondu)
		var op := float(d.op) * (1.0 if k < 1.0 - fondu else (1.0 - k) / maxf(fondu, 0.001))
		(d.mat as ShaderMaterial).set_shader_parameter("opacite", op)
		i -= 1

# ====================================================================== maillages

## Éclat de cristal (bipyramide hexagonale allongée sur -Z, longueur 1, facettes à plat).
static func _creer_eclat() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var avant := Vector3(0, 0, -0.75)
	var arriere := Vector3(0, 0, 0.25)
	var anneau: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		anneau.append(Vector3(cos(a) * (0.16 if i % 2 == 0 else 0.11), sin(a) * 0.14, 0.0))
	for i in 6:
		var p0 := anneau[i]
		var p1 := anneau[(i + 1) % 6]
		st.add_vertex(avant); st.add_vertex(p1); st.add_vertex(p0)
		st.add_vertex(arriere); st.add_vertex(p0); st.add_vertex(p1)
	st.generate_normals()
	return st.commit()

## Pic de cristal (pyramide hexagonale irrégulière, base sous le sol, hauteur 1 sur +Y).
static func _creer_pic() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var bas: Array[Vector3] = []
	var mil: Array[Vector3] = []
	var rr := [1.0, 0.8, 0.95, 0.75, 1.0, 0.85]
	for i in 6:
		var a := TAU * i / 6.0
		bas.append(Vector3(cos(a) * rr[i], -0.15, sin(a) * rr[i]))
		mil.append(Vector3(cos(a + 0.2) * rr[i] * 0.6, 0.45, sin(a + 0.2) * rr[i] * 0.6))
	var pointe := Vector3(0.12, 1.0, 0.05)
	for i in 6:
		var j := (i + 1) % 6
		st.add_vertex(bas[i]); st.add_vertex(mil[i]); st.add_vertex(mil[j])
		st.add_vertex(bas[i]); st.add_vertex(mil[j]); st.add_vertex(bas[j])
		st.add_vertex(mil[i]); st.add_vertex(pointe); st.add_vertex(mil[j])
	st.generate_normals()
	return st.commit()

func _boule(parent: Node3D, rayon: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * rayon * 2.0
	parent.add_child(mi)
	return mi

# ====================================================================== outils

static func base_vers(dir: Vector3) -> Basis:
	## Repère dont -Z regarde `dir`.
	var d := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var haut := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(d, haut)

static func base_normale(n: Vector3) -> Basis:
	## Repère dont +Y suit la normale.
	var y := n.normalized() if n.length() > 0.0001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

func valide(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and (n as Node).is_inside_tree()

## Boîte englobante des visuels de `n` dans le repère de `n` (repli : silhouette humaine).
func boite(n: Node3D) -> AABB:
	var res := AABB()
	var vu := false
	var inv := n.global_transform.affine_inverse()
	var liste := n.find_children("*", "VisualInstance3D", true, false)
	var k := 0
	for v in liste:
		if k > 40:
			break
		if v is GPUParticles3D or v is OmniLight3D or v is Light3D or not (v as Node3D).visible:
			continue
		k += 1
		var vi := v as VisualInstance3D
		var bb: AABB = (inv * vi.global_transform) * vi.get_aabb()
		if bb.size.length() > 6.0 or bb.size.length() < 0.001:
			continue
		res = bb if not vu else res.merge(bb)
		vu = true
	if not vu:
		return AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.8, 0.6))
	return res

func _exclus_depuis(n: Node) -> Array[RID]:
	var ex: Array[RID] = []
	var p := n
	while p != null:
		if p is CollisionObject3D:
			ex.append((p as CollisionObject3D).get_rid())
		p = p.get_parent()
	return ex

## Point d'arrivée d'un rayon visuel (collision ou portée).
func point_vise(depuis: Node3D, o: Vector3, dir: Vector3, portee: float) -> Dictionary:
	var fin := o + dir * portee
	if not depuis.is_inside_tree():
		return {"pos": fin, "touche": false, "normale": -dir}
	var q := PhysicsRayQueryParameters3D.create(o, fin, 0xFFFFFFFF, _exclus_depuis(depuis))
	var r := depuis.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"pos": fin, "touche": false, "normale": -dir}
	return {"pos": r.position, "touche": true, "normale": r.normal, "collider": r.collider}

func _ecole_ok(ecole: String) -> String:
	return ecole if LUMIERE.has(ecole) else "feu"

# ====================================================================== auras des mains

func aura_main(main: Node3D, ecole: String, intensite: float) -> void:
	if main == null or not is_instance_valid(main):
		return
	ecole = _ecole_ok(ecole)
	var id := main.get_instance_id()
	var a: Dictionary = _auras.get(id, {})
	if intensite <= 0.001:
		if not a.is_empty():
			_aura_eteindre(a)
			_auras.erase(id)
		return
	if not a.is_empty() and a.ecole != ecole:
		_aura_eteindre(a)
		a = {}
	if a.is_empty():
		a = _aura_creer(main, ecole)
		_auras[id] = a
	a.i = clampf(intensite, 0.0, 1.5)

func _aura_creer(main: Node3D, ecole: String) -> Dictionary:
	var ancre := Node3D.new()
	ancre.name = "AuraMagie"
	add_child(ancre)
	ancre.position = main.global_position
	var a := {"main": main, "ancre": ancre, "ecole": ecole, "i": 0.0, "emit": [], "eclair": {}, "disque": {}, "extra": []}
	var noms: Array = []
	match ecole:
		"feu": noms = ["feu_aura", "feu_aura_coeur", "feu_aura_braise"]
		"glace": noms = ["glace_aura", "glace_aura_cristal", "glace_aura_eclats"]
		"electricite": noms = ["elec_aura", "elec_aura_lueur"]
		"tenebres": noms = ["ten_aura", "ten_aura_lueur"]
		"soin": noms = ["soin_aura"]
		"protection": noms = ["prot_aura"]
	for nom in noms:
		var p := emettre(nom, ancre, Transform3D.IDENTITY, true)
		if p != null:
			a.emit.append(p)
	if ecole == "electricite":
		a.eclair = eclair(ancre, "electricite", 2.0, -1.0, 0.05, _gen_aura_arcs.bind(a))
	elif ecole == "tenebres":
		# vortex noir et violet DANS la paume (spirale), bien visible en vue FPS
		var vortex := _vortex_main(ancre, 0.07)
		a.extra.append(vortex)
	elif ecole == "protection":
		var mi := MeshInstance3D.new()
		mi.mesh = _quad_sol
		var m := ShaderMaterial.new()
		m.shader = SH_SOL
		m.set_shader_parameter("couleur", Color("#7ab0d8"))
		m.set_shader_parameter("coeur", Color("#eaf8ff"))
		m.set_shader_parameter("anneau", 0.85)
		m.set_shader_parameter("epaisseur", 0.07)
		m.set_shader_parameter("runes", 0.9)
		m.set_shader_parameter("texels", 32.0)
		m.set_shader_parameter("tourne", 0.15)
		m.set_shader_parameter("opacite", 0.8)
		m.set_shader_parameter("face_camera", true)
		mi.material_override = m
		mi.scale = Vector3.ONE * 0.06
		ancre.add_child(mi)
		a.extra.append(mi)
	return a

func _vortex_main(parent: Node3D, rayon: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_sol
	var m := ShaderMaterial.new()
	m.shader = SH_SOL_MIX
	m.set_shader_parameter("couleur", Color("#b050ff"))
	m.set_shader_parameter("coeur", Color("#06030c"))
	m.set_shader_parameter("anneau", 0.92)
	m.set_shader_parameter("epaisseur", 0.06)
	m.set_shader_parameter("spirale", 1.0)
	m.set_shader_parameter("texels", 28.0)
	m.set_shader_parameter("tourne", 0.8)
	m.set_shader_parameter("opacite", 1.0)
	m.set_shader_parameter("face_camera", true)
	mi.material_override = m
	mi.scale = Vector3.ONE * rayon
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _gen_aura_arcs(a: Dictionary) -> Array:
	var traits: Array = []
	var i := float(a.i)
	var dbl: bool = _double.get(a.ecole, false)
	var n := 3 + int(i * 5.0) + (2 if dbl else 0)
	for _k in n:
		var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.015
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.05, 0.11) * (1.0 + 0.4 * i)
		traits.append([foudre(o, b, 0.025, 3), 1.0 if rng.randf() < 0.5 else 0.6, 1.0])
	return traits

func _aura_eteindre(a: Dictionary) -> void:
	for p in a.emit:
		arreter(p)
	eclair_fin(a.eclair)
	for x in a.extra:
		if is_instance_valid(x):
			x.queue_free()
	a.extra.clear()
	var ancre: Node3D = a.ancre
	if is_instance_valid(ancre):
		# l'ancre reste le temps que les dernières particules (locales) s'éteignent
		var t := get_tree().create_timer(1.7, false) if is_inside_tree() else null
		if t != null:
			t.timeout.connect(ancre.queue_free)
		else:
			ancre.queue_free()

func _maj_auras() -> void:
	for id in _auras.keys():
		var a: Dictionary = _auras[id]
		var main: Variant = a.main
		if not valide(main):
			_aura_eteindre(a)
			_auras.erase(id)
			continue
		var ancre: Node3D = a.ancre
		var i := float(a.i)
		var dbl: bool = _double.get(a.ecole, false)
		var k := (0.75 + 0.5 * minf(i, 1.0)) * (1.25 if dbl else 1.0)
		ancre.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), (main as Node3D).global_position)
		for p in a.emit:
			if is_instance_valid(p):
				p.amount_ratio = clampf(0.3 + 0.7 * i, 0.05, 1.0)
		var c: Color = LUMIERE[a.ecole]
		var scint := 1.0
		if a.ecole == "electricite":
			scint = 0.6 + 0.8 * rng.randf()
		elif a.ecole == "feu":
			scint = 0.9 + 0.2 * sin(horloge * 23.0) * sin(horloge * 7.0)
		lumiere("aura%d" % id, ancre.position + Vector3.UP * 0.05, c, (1.5 + 4.0 * i) * scint * (1.5 if dbl else 1.0), 4.5 + 3.5 * i, 2.0 + i)

# ====================================================================== jets canalisés

func jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif: bool) -> void:
	if origine == null or not is_instance_valid(origine):
		return
	ecole = _ecole_ok(ecole)
	var id := origine.get_instance_id()
	var j: Dictionary = _jets.get(id, {})
	if not actif:
		if not j.is_empty():
			_jet_arreter(j)
			_jets.erase(id)
		return
	var dbl: bool = _double.get(ecole, false)
	if not j.is_empty() and (j.ecole != ecole or j.dbl != dbl or absf(float(j.portee) - portee) > portee * 0.2 or absf(float(j.largeur) - largeur) > maxf(largeur, 0.05) * 0.3):
		_jet_arreter(j)
		j = {}
	if j.is_empty():
		j = _jet_creer(ecole, origine, portee, largeur, dbl)
		_jets[id] = j
	j.dir = direction.normalized() if direction.length() > 0.0001 else Vector3.FORWARD
	j.vu = horloge
	_jet_placer(j)

func _jet_creer(ecole: String, origine: Node3D, portee: float, largeur: float, dbl: bool) -> Dictionary:
	var j := {"ecole": ecole, "origine": origine, "portee": portee, "largeur": largeur, "dbl": dbl, "emit": [], "eclair": {},
		"dir": Vector3.FORWARD, "vu": horloge, "fin_pos": Vector3.ZERO, "touche": false, "normale": Vector3.UP, "t_bout": 0.0, "t_rayon": -1.0,
		"suit_bout": [], "bouclier": {}, "cible": null, "gerbe": [], "gerbe_cible": null, "gerbe_bb": AABB(), "flash": null, "debut": horloge}
	var kl := 1.6 if dbl else 1.0
	# cône 2 à 3 fois plus large qu'un rayon « géométrique » : la flamme s'évase et noie la cible
	var ecart := clampf(rad_to_deg(atan2(largeur * 0.5 * kl, maxf(portee, 0.5))) * 2.4, 8.0, 32.0)
	var kn := 1.4 if dbl else 1.0
	match ecole:
		"feu", "glace", "soin":
			var noms: Array = {"feu": ["feu_jet_coeur", "feu_jet", "feu_jet_bord", "feu_jet_braise", "feu_jet_fumee", "feu_paume"],
				"glace": ["glace_jet", "glace_jet_corps", "glace_jet_cristal", "glace_jet_brume", "glace_paume"], "soin": ["soin_jet"]}[ecole]
			for nom in noms:
				var d: Dictionary = PresetsMagie.R[nom]
				if nom.ends_with("paume"):
					var pp := emettre(nom, null, Transform3D.IDENTITY, true, kn)
					if pp != null:
						j.emit.append(pp)
					continue
				var v: Vector2 = d.vit
				var vm := (v.x + v.y) * 0.5
				var kv := 1.6 if nom.ends_with("fumee") or nom.ends_with("brume") else 1.2
				var pm := _pm(nom, d, {"ecart": snappedf(float(d.get("ecart", 9.0)) * ecart / 9.0, 0.5)})
				var p := emettre(nom, null, Transform3D.IDENTITY, true, kn, portee / vm * kv, pm)
				if p != null:
					p.set_meta("v_jet", vm / kv)
					j.emit.append(p)
		"electricite":
			j.eclair = eclair(null, "electricite", 4.0 if dbl else 3.0, -1.0, 0.05, _gen_jet_arc.bind(j))
			var pe := emettre("elec_paume", null, Transform3D.IDENTITY, true, kn)
			if pe != null:
				j.emit.append(pe)
			# éclat aveuglant dans la paume (sphère additive qui papillote)
			var f := Node3D.new()
			add_child(f)
			_boule(f, 0.5, _mat_coeur(Color("#f0f2ff"), true, 2.2))
			_boule(f, 1.0, _mat_coeur(Color("#7a7af0", 0.45), true, 1.4))
			j.flash = f
		"tenebres":
			j.eclair = eclair(null, "drain", 5.0 if dbl else 4.0, -1.0, 0.04, _gen_drain.bind(j))
			for nom in ["ten_drain_sombre", "ten_drain_rouge", "ten_drain_eclats"]:
				var p := emettre(nom, null, Transform3D.IDENTITY, true, kn)
				if p != null:
					j.emit.append(p)
					j.suit_bout.append(p)
		"protection":
			j.bouclier = disque(Vector3.ZERO, Vector3.FORWARD, largeur * 0.5 * kl, largeur * 0.5 * kl, 1e9,
				{"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.88, "epaisseur": 0.06, "runes": 1.0, "remplissage": 0.25, "texels": 40.0, "tourne": 0.2, "eclat": 1.3}, false, false, 0.05)
	return j

func _gen_jet_arc(j: Dictionary) -> Array:
	var traits: Array = []
	var o: Vector3 = (j.origine as Node3D).global_position if valide(j.origine) else Vector3.ZERO
	var b: Vector3 = j.fin_pos
	var l := o.distance_to(b)
	var dbl: bool = j.dbl
	# arc principal épais + 2 arcs secondaires, nombreuses ramifications ; quelques fourches vers le corps de la cible
	foudre_ramifiee(traits, o, b, l * 0.1, 1.0, 5 if dbl else 4, 5)
	for _k in (3 if dbl else 2):
		var dev := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.35
		foudre_ramifiee(traits, o, b + dev, l * 0.14, 0.6, 2, 5)
	if j.touche:
		for _k in 3:
			var fin := b + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.8, 0.5), rng.randf_range(-0.4, 0.4))
			traits.append([foudre(b, fin, 0.08, 3), 0.6, 0.8])
	return traits

func _gen_drain(j: Dictionary) -> Array:
	var traits: Array = []
	if not valide(j.origine):
		return traits
	var o: Vector3 = (j.origine as Node3D).global_position
	var b: Vector3 = j.fin_pos
	var axe := b - o
	var l := axe.length()
	if l < 0.05:
		return traits
	var dir := axe / l
	var x := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := dir.cross(x)
	var n := clampi(int(l * 9.0), 8, 60)
	var dbl: bool = j.dbl
	var brins := 5 if dbl else 4
	# filaments épais qui ondulent et s'enroulent (pas un trait fin) : rayon qui respire le long du trajet
	for brin in brins:
		var pts := PackedVector3Array()
		var ph := horloge * (7.0 + brin) + brin * TAU / brins
		var amp := (0.07 + 0.05 * float(brin % 2)) * (1.4 if dbl else 1.0)
		for i in n + 1:
			var t := float(i) / n
			var rayon := amp * (0.35 + sin(t * PI) * (1.6 + 0.6 * sin(horloge * 3.0 + brin)))
			var a := ph - t * (10.0 + 3.0 * brin)
			pts.append(o + axe * t + (x * cos(a) + y * sin(a)) * rayon)
		traits.append([pts, 1.0 if brin < 2 else 0.6, 1.0])
	return traits

## Cible du jet : ce que touche le rayon (corps mobile), sinon l'ennemi le plus proche de l'axe (groupes « ennemis »,
## « cibles_combat », « cibles_magie ») : le jet s'arrête sur lui et la gerbe l'enveloppe.
func _jet_cible(j: Dictionary, o: Vector3, dir: Vector3) -> void:
	var portee := float(j.portee)
	var r := point_vise(j.origine, o, dir, portee)
	var cible: Node3D = null
	var col: Variant = r.get("collider")
	if r.touche and col is Node3D and not (col is StaticBody3D) and not (col is CSGShape3D):
		cible = col
	var lim := o.distance_to(r.pos)
	if cible == null:
		var meilleur := 1e9
		for g in ["ennemis", "cibles_combat", "cibles_magie"]:
			for n in get_tree().get_nodes_in_group(g):
				if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
					continue
				var c := (n as Node3D).global_position + Vector3.UP * 1.0
				var t := (c - o).dot(dir)
				if t < 0.3 or t > lim + 0.5:
					continue
				var ecart := (o + dir * t).distance_to(c)
				if ecart < 0.9 and t < meilleur:
					meilleur = t
					cible = n
	j.cible = cible
	if cible != null:
		if j.gerbe_cible != cible:
			j.gerbe_bb = boite(cible)
		var bb: AABB = j.gerbe_bb if j.gerbe_cible == cible else boite(cible)
		var centre := cible.global_transform * bb.get_center()
		var t2 := maxf((centre - o).dot(dir), 0.3)
		j.fin_pos = o + dir * t2
		j.touche = true
		j.normale = -dir
	else:
		j.fin_pos = r.pos
		j.touche = r.touche
		j.normale = r.normale

func _jet_gerbe(j: Dictionary) -> void:
	# gerbe qui ENVELOPPE le corps de la cible (flammes, givre, étincelles, fumée obscure sur toute la silhouette)
	var cible: Variant = j.cible
	if j.gerbe_cible != cible:
		for p in j.gerbe:
			arreter(p)
		j.gerbe = []
		j.gerbe_cible = cible
		if cible != null and valide(cible):
			var bb: AABB = j.gerbe_bb
			var ext := (bb.size * 0.45).max(Vector3(0.1, 0.2, 0.1))
			var exs := Vector3(snappedf(ext.x, 0.05), snappedf(ext.y, 0.05), snappedf(ext.z, 0.05))
			var noms: Array = {"feu": ["feu_gerbe", "feu_gerbe_braise"], "glace": ["glace_gerbe", "glace_gerbe_cristal"],
				"electricite": ["elec_gerbe"], "tenebres": ["ten_gerbe", "ten_gerbe_lueur"]}.get(j.ecole, [])
			for nom in noms:
				var p := emettre(nom, null, Transform3D.IDENTITY, true, 1.4 if j.dbl else 1.0, -1.0, _pm(nom, PresetsMagie.R[nom], {"ext": exs}))
				if p != null:
					j.gerbe.append(p)
	if cible != null and valide(cible):
		var centre: Vector3 = (cible as Node3D).global_transform * (j.gerbe_bb as AABB).get_center()
		for p in j.gerbe:
			if is_instance_valid(p):
				p.position = centre

func _jet_placer(j: Dictionary) -> void:
	var origine: Node3D = j.origine
	if not valide(origine):
		return
	var o := origine.global_position
	var dir: Vector3 = j.dir
	if horloge - float(j.t_rayon) > 0.08:
		j.t_rayon = horloge
		_jet_cible(j, o, dir)
	var fin: Vector3 = j.fin_pos
	var l := o.distance_to(fin)
	var vers := (fin - o) / maxf(l, 0.001) if l > 0.05 else dir
	var b := base_vers(vers)
	for p in j.emit:
		if is_instance_valid(p) and not j.suit_bout.has(p):
			p.transform = Transform3D(b, o)
			# les particules s'éteignent DANS la cible : le jet remplit tout le trajet sans la traverser
			if p.has_meta("v_jet"):
				var vie := clampf(l / float(p.get_meta("v_jet")), 0.08, 3.0)
				if absf(p.lifetime - vie) > vie * 0.18:
					p.lifetime = vie
	# drain : les particules partent de la cible et remontent vers la main
	for p in j.suit_bout:
		if is_instance_valid(p):
			p.transform = Transform3D(base_vers(o - fin), fin)
			var vie := clampf(l / 5.75, 0.1, 2.0)
			if absf(p.lifetime - vie) > 0.15:
				p.lifetime = vie
	if not j.bouclier.is_empty():
		var d: Dictionary = j.bouclier
		d.pos = o + dir * 0.35
		d.base = GestionMagie.base_normale(dir)
	if j.flash != null and is_instance_valid(j.flash):
		(j.flash as Node3D).transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.035, 0.08) * (1.4 if j.dbl else 1.0)), o)
	_jet_gerbe(j)
	# feu / glace / électricité : léchage au point touché
	if j.touche and horloge - float(j.t_bout) > 0.12:
		j.t_bout = horloge
		var bn := base_normale(j.normale)
		match j.ecole:
			"feu":
				emettre("feu_lechage", null, Transform3D(bn, fin), false)
			"glace":
				emettre("glace_bouffee", null, Transform3D(bn, fin), false)
			"electricite":
				emettre("elec_etincelles", null, Transform3D(bn, fin), false, 0.7)
	# lumière : forte sur la main (un peu devant, pour éclairer main et sol) et à l'arrivée, couleur de l'école
	var c: Color = LUMIERE[j.ecole]
	var kd := 1.2 if j.dbl else 1.0   # deux jets = deux lumières : multiplicateur modéré (neige surexposée sinon)
	var sc := 1.0
	if j.ecole == "electricite":
		sc = 0.55 + 0.9 * rng.randf()
	elif j.ecole == "feu":
		sc = 0.9 + 0.15 * sin(horloge * 21.0) * sin(horloge * 6.0)
	var id := origine.get_instance_id()
	lumiere("aura%d" % id, o + vers * 0.5, c, 5.0 * kd * sc, 7.5 + 1.5 * kd, 9.0)
	lumiere("jet%d" % id, fin - vers * minf(0.7, l * 0.3) + Vector3.UP * 0.3, c, 7.0 * kd * sc, 7.0 + 2.0 * kd, 8.0)
	_teinte_demande(j.ecole, 1.0 if not j.dbl else 1.4)

func _jet_arreter(j: Dictionary) -> void:
	for p in j.emit:
		arreter(p)
	for p in j.gerbe:
		arreter(p)
	j.gerbe = []
	eclair_fin(j.eclair)
	if j.flash != null and is_instance_valid(j.flash):
		(j.flash as Node).queue_free()
	j.flash = null
	if not j.bouclier.is_empty():
		j.bouclier.duree = 0.0

func _maj_jets() -> void:
	for id in _jets.keys():
		var j: Dictionary = _jets[id]
		if not valide(j.origine) or horloge - float(j.vu) > 0.2:
			_jet_arreter(j)
			_jets.erase(id)
		else:
			_jet_placer(j)

# ====================================================================== projectiles

func projectile_visuel(ecole: String, forme: String) -> Node3D:
	ecole = _ecole_ok(ecole)
	var racine := Node3D.new()
	racine.name = "ProjectileMagie"
	var visuel := Node3D.new()
	visuel.name = "Visuel"
	racine.add_child(visuel)
	var pal: Array = PresetsMagie.R[PresetsMagie.de(ecole, "trainee")].rampe
	var dbl: bool = _double.get(ecole, false)
	var k := 1.4 if dbl else 1.0
	var coeur: Array = []
	match forme:
		"eclat", "lance":
			var lance := forme == "lance"
			var cp := "glace" if ecole == "glace" else ("tenebres" if ecole == "tenebres" else ecole)
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh_eclat
			mi.material_override = _mat_cristal(cp)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = (Vector3(1.6, 1.6, 4.0) if lance else Vector3(1.3, 1.3, 1.7)) * k
			visuel.add_child(mi)
			if lance:
				# cristaux latéraux en couronne vers l'arrière (lance de givre massive)
				for i in (8 if dbl else 6):
					var s := MeshInstance3D.new()
					s.mesh = _mesh_eclat
					s.material_override = mi.material_override
					s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					var a := TAU * i / (8.0 if dbl else 6.0)
					var lg := 1.1 if i % 2 == 0 else 0.75
					s.transform = Transform3D(Basis.from_euler(Vector3(sin(a) * 0.45, cos(a) * 0.45, 0)).scaled(Vector3(0.7, 0.7, lg) * k), Vector3(cos(a) * 0.16, sin(a) * 0.16, 0.35 + 0.2 * float(i % 2)) * k)
					visuel.add_child(s)
		"trait":
			_boule(visuel, 0.15 * k, _mat_coeur(Color(pal[2]).darkened(0.7), false, 1.0))
			_boule(visuel, 0.28 * k, _mat_coeur(Color(pal[1], 0.6), true, 1.6))
			_boule(visuel, 0.42 * k, _mat_coeur(Color(pal[2], 0.3), true, 1.2))
			if ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
		_:   # "boule", "orbe"
			_boule(visuel, (0.17 if forme == "boule" else 0.1) * k, _mat_coeur(Color(pal[0]), true, 1.8))
			_boule(visuel, (0.3 if forme == "boule" else 0.17) * k, _mat_coeur(Color(pal[2], 0.5), true, 1.2))
			if forme == "boule":
				_boule(visuel, 0.42 * k, _mat_coeur(Color(pal[3] if pal.size() > 3 else pal[2], 0.25), true, 1.1))
			if ecole == "feu":
				coeur.append(emettre("feu_boule_coeur", visuel, Transform3D.IDENTITY, true))
			elif ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
	if _projectiles.size() >= MAX_PROJECTILES:
		refus += 1
	else:
		var e := {"noeud": racine, "visuel": visuel, "ecole": ecole, "forme": forme, "emit": [], "coeur": coeur, "prec": null, "entre": false, "eclair": {}, "dbl": dbl}
		_projectiles.append(e)
		if ecole == "electricite":
			e.eclair = eclair(visuel, "electricite", 1.0, -1.0, 0.05, _gen_orbe_arcs.bind(0.12 * k))
	return racine

func _gen_orbe_arcs(r: float) -> Array:
	var traits: Array = []
	for _k in 4:
		var a := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r * 0.3
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r * rng.randf_range(1.0, 2.2)
		traits.append([foudre(a, b, r * 0.3, 3), 1.0, 1.0])
	return traits

func _maj_projectiles() -> void:
	var i := _projectiles.size() - 1
	while i >= 0:
		var e: Dictionary = _projectiles[i]
		var n: Variant = e.noeud
		var vivant: bool = n != null and is_instance_valid(n) and not (n as Node).is_queued_for_deletion()
		if vivant and (n as Node).is_inside_tree():
			var pos: Vector3 = (n as Node3D).global_position
			if not e.entre:
				e.entre = true
				var noms: Array = [PresetsMagie.de(e.ecole, "trainee")]
				if e.ecole == "feu":
					noms.append("feu_trainee_fumee")
					noms.append("feu_trainee_braise")
				elif e.ecole == "glace":
					noms.append("glace_trainee_brume")
					if e.forme == "lance":
						noms.append("glace_trainee_eclats")
				elif e.ecole == "tenebres":
					noms.append("ten_trainee_lueur")
				for nom in noms:
					var p := emettre(nom, null, Transform3D(Basis.IDENTITY, pos), true, 1.5 if e.forme == "lance" or e.dbl else 1.0)
					if p != null:
						e.emit.append(p)
			for p in e.emit:
				if is_instance_valid(p):
					p.position = pos
			if e.prec != null:
				var v: Vector3 = pos - (e.prec as Vector3)
				if v.length() > 0.0005:
					var vis: Node3D = e.visuel
					vis.global_basis = base_vers(v)
			e.prec = pos
			var c: Color = LUMIERE[e.ecole]
			lumiere("proj%d" % (n as Node).get_instance_id(), pos, c, 3.6 if e.forme in ["boule", "orbe", "trait"] else 2.2, 6.0, 3.0)
		elif not vivant or e.entre:
			for p in e.emit + e.coeur:
				arreter(p)
			eclair_fin(e.eclair)
			_projectiles.remove_at(i)
		i -= 1

# ====================================================================== impacts

func impact(ecole: String, position: Vector3, normale: Vector3, force: float) -> void:
	ecole = _ecole_ok(ecole)
	var f := clampf(force, 0.3, 3.0)
	var b := base_normale(normale)
	var xf := Transform3D(b.scaled(Vector3.ONE * sqrt(f)), position)
	var c: Color = LUMIERE[ecole]
	var kn := clampf(0.6 + 0.4 * f, 0.5, 1.6)
	match ecole:
		"feu":
			emettre("feu_impact", null, xf, false, kn)
			emettre("feu_impact_braise", null, xf, false, kn)
			emettre("feu_impact_fumee", null, xf, false, kn)
			disque(position, normale, 0.1, 1.7 * f, 0.45, {"couleur": "#ec6a1f", "coeur": "#fff0a8", "anneau": 0.85, "epaisseur": 0.14, "texels": 40.0})
		"glace":
			emettre("glace_impact", null, xf, false, kn)
			emettre("glace_impact_eclats", null, xf, false, kn)
			emettre("glace_impact_brume", null, xf, false, kn)
			emettre("glace_impact_poudre", null, xf, false, kn)
			disque(position, normale, 0.1, 1.3 * f, 0.35, {"couleur": "#5f9fe8", "coeur": "#e8f6ff", "anneau": 0.85, "epaisseur": 0.1, "texels": 40.0})
			# cristaux qui JAILLISSENT de l'impact
			for k in 6 + int(f * 3.0):
				var a := rng.randf() * TAU
				var off := (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.05, 0.4) * f
				var axe := (b.y + off.normalized() * rng.randf_range(0.4, 1.0)).normalized()
				pic("glace", position + off, axe, rng.randf_range(0.06, 0.12) * f, rng.randf_range(0.35, 0.8) * f, k * 0.015, 0.1, horloge + 1.3 + rng.randf() * 0.4)
		"electricite":
			emettre("elec_impact", null, xf, false, kn)
			disque(position, normale, 0.1, 1.4 * f, 0.3, {"couleur": "#7a7af0", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 48.0, "eclat": 1.8})
			var centre := position + b.y * 0.05
			eclair(null, "electricite", 2.0, 0.3, 0.05, func() -> Array:
				var traits: Array = []
				for _k in 7:
					var a := rng.randf() * TAU
					var fin := centre + (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.6, 1.4) * f + b.y * rng.randf_range(0.0, 0.4)
					foudre_ramifiee(traits, centre, fin, 0.12 * f, 1.0, 1, 4)
				return traits)
		"tenebres":
			emettre("ten_impact", null, xf, false, kn)
			emettre("ten_impact_sombre", null, xf, false, kn)
			emettre("ten_impact_eclats", null, xf, false, kn)
			disque(position, normale, 0.1, 1.0 * f, 0.5, {"couleur": "#5a1a8a", "coeur": "#0c0614", "anneau": 0.8, "epaisseur": 0.15, "spirale": 0.8, "texels": 40.0}, true)
			for k in 4 + int(f * 2.0):
				var a := rng.randf() * TAU
				var off := (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.05, 0.4) * f
				var axe := (b.y + off.normalized() * rng.randf_range(0.3, 0.9)).normalized()
				pic("tenebres", position + off, axe, rng.randf_range(0.03, 0.06) * f, rng.randf_range(0.25, 0.55) * f, k * 0.015, 0.1, horloge + 0.9 + rng.randf() * 0.3)
		"soin":
			emettre("soin_impact", null, xf, false, kn)
			disque(position, normale, 0.2, 1.0 * f, 0.9, {"couleur": "#b8d060", "coeur": "#fff4c0", "anneau": 0.85, "epaisseur": 0.08, "runes": 0.8, "texels": 40.0})
		"protection":
			emettre("prot_impact", null, xf, false, kn)
			disque(position, normale, 0.3, 1.0 * f, 0.6, {"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.85, "epaisseur": 0.08, "runes": 1.0, "texels": 40.0})
	lumiere("impact%d" % rng.randi(), position + b.y * 0.4, c, 7.0 * clampf(f, 0.6, 2.0), 7.0 + 2.0 * f, 6.0, 0.45)

# ====================================================================== zones

func zone(ecole: String, position: Vector3, rayon: float, duree: float) -> void:
	ecole = _ecole_ok(ecole)
	var r := maxf(rayon, 0.3)
	var d := maxf(duree, 0.3)
	var z := {"ecole": ecole, "pos": position, "r": r, "duree": d, "t0": horloge, "emit": [], "prochain": horloge + 0.1, "fini": false, "eclair": {}}
	var rq := snappedf(r, 0.25)
	var base := Transform3D(Basis.IDENTITY, position)
	var kz := clampf(r / 2.5, 0.5, 2.0)
	match ecole:
		"feu":
			emettre("feu_explosion", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.4), false, kz)
			emettre("feu_explosion_fumee", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.5), false, kz)
			emettre("feu_impact_braise", null, base, false, 1.5)
			disque(position, Vector3.UP, 0.2, r * 1.15, 0.55, {"couleur": "#ec6a1f", "coeur": "#fff0a8", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5a1a1c", "coeur": "#b3341f", "anneau": 0.95, "epaisseur": 0.05, "remplissage": 0.35, "texels": 48.0, "eclat": 1.0}, false, false, 0.3)
			for nom in ["feu_sol", "feu_sol_braise"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
		"glace":
			emettre("glace_nova_souffle", null, Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.25), false, kz, r / 6.0)
			disque(position, Vector3.UP, 0.2, r * 1.1, 0.45, {"couleur": "#a8d8f8", "coeur": "#e8f6ff", "anneau": 0.9, "epaisseur": 0.07, "texels": 64.0, "eclat": 1.6})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5f9fe8", "coeur": "#e8f6ff", "anneau": 0.94, "epaisseur": 0.04, "remplissage": 0.3, "runes": 0.5, "texels": 64.0, "eclat": 0.9}, false, false, 0.25)
			for nom in ["glace_nova_brume", "glace_scintille"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			var nb := clampi(int(r * 7.0), 8, 32)
			for k in nb:
				var anneau := 0.55 if k % 3 == 0 else 0.92
				var a := TAU * k / nb + rng.randf_range(-0.15, 0.15)
				var dist := r * anneau * rng.randf_range(0.85, 1.05)
				var off := Vector3(cos(a), 0, sin(a)) * dist
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.35, 0.8)).normalized()
				var h := rng.randf_range(0.6, 1.5) * (1.15 - anneau * 0.3) * kz
				pic("glace", position + off, axe, h * rng.randf_range(0.18, 0.28), h, dist / r * 0.22, 0.18, horloge + d - 0.3)
		"electricite":
			disque(position, Vector3.UP, 0.2, r, 0.3, {"couleur": "#7a7af0", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.8})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#4a3ad0", "coeur": "#b4c0ff", "anneau": 0.93, "epaisseur": 0.05, "remplissage": 0.12, "runes": 0.9, "texels": 64.0, "tourne": 0.1, "eclat": 1.4}, false, false, 0.2)
			var pd: Dictionary = PresetsMagie.R["elec_sol"]
			var p := emettre("elec_sol", null, base, true, kz, -1.0, _pm("elec_sol", pd, {"r": rq}))
			if p != null:
				z.emit.append(p)
			z.eclair = eclair(null, "electricite", 1.0, d, 0.07, _gen_anneau_arcs.bind(position, r))
		"tenebres":
			emettre("ten_eruption", null, base, false, kz, -1.0, _pm("ten_eruption", PresetsMagie.R["ten_eruption"], {"r": snappedf(r * 0.6, 0.25)}))
			emettre("ten_impact_sombre", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position), false, kz)
			disque(position, Vector3.UP, 0.3, r * 1.1, 0.5, {"couleur": "#9a3ae0", "coeur": "#d08aff", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5a1a8a", "coeur": "#0c0614", "anneau": 0.95, "epaisseur": 0.05, "spirale": 0.9, "texels": 64.0, "eclat": 1.0}, true, false, 0.3)
			for nom in ["ten_sol", "ten_sol_sombre"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			var nb := clampi(int(r * 6.0), 8, 28)
			for k in nb:
				var a := rng.randf() * TAU
				var dist := r * sqrt(rng.randf_range(0.04, 1.0))
				var off := Vector3(cos(a), 0, sin(a)) * dist
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.1, 1.0) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).normalized()
				var h := rng.randf_range(0.8, 2.2) * kz
				pic("tenebres", position + off, axe, h * rng.randf_range(0.1, 0.16), h, rng.randf() * 0.25, 0.12, horloge + d - 0.3)
		"soin":
			disque(position, Vector3.UP, r, r, d, {"couleur": "#b8d060", "coeur": "#fff4c0", "anneau": 0.92, "epaisseur": 0.05, "remplissage": 0.15, "runes": 0.9, "texels": 64.0, "tourne": 0.05}, false, false, 0.3)
			var p := emettre("soin_sol", null, base, true, kz, -1.0, _pm("soin_sol", PresetsMagie.R["soin_sol"], {"r": rq}))
			if p != null:
				z.emit.append(p)
		"protection":
			disque(position, Vector3.UP, r, r, d, {"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.92, "epaisseur": 0.05, "remplissage": 0.1, "runes": 1.0, "texels": 64.0, "tourne": -0.05}, false, false, 0.3)
			var p := emettre("prot_sol", null, base, true, kz, -1.0, _pm("prot_sol", PresetsMagie.R["prot_sol"], {"r": rq}))
			if p != null:
				z.emit.append(p)
	lumiere("zone%d" % rng.randi(), position + Vector3.UP * 0.8, LUMIERE[ecole], 7.0 * kz, r * 2.5 + 3.0, 8.0, 0.5)
	_zones.append(z)

func _gen_anneau_arcs(centre: Vector3, r: float) -> Array:
	var traits: Array = []
	for _k in 3:
		var a := rng.randf() * TAU
		var a2 := a + rng.randf_range(0.3, 0.9)
		var p0 := centre + Vector3(cos(a), 0.05, sin(a)) * r * 0.95
		var p1 := centre + Vector3(cos(a2), 0.05, sin(a2)) * r * 0.95
		traits.append([foudre(p0, p1, r * 0.06, 4), 1.0, 0.8])
	return traits

func _maj_zones() -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var z: Dictionary = _zones[i]
		var t := horloge - float(z.t0)
		var pos: Vector3 = z.pos
		var r := float(z.r)
		var c: Color = LUMIERE[z.ecole]
		if t >= float(z.duree):
			for p in z.emit:
				arreter(p)
			if z.ecole == "glace":
				var pd: Dictionary = PresetsMagie.R["glace_eclats_zone"]
				emettre("glace_eclats_zone", null, Transform3D(Basis.IDENTITY, pos), false, clampf(r / 2.5, 0.5, 2.0), -1.0, _pm("glace_eclats_zone", pd, {"r": snappedf(r * 0.8, 0.25)}))
			_zones.remove_at(i)
			i -= 1
			continue
		var scint := 0.85 + 0.3 * sin(horloge * 17.0) * sin(horloge * 5.3)
		lumiere("zone_p%d" % i, pos + Vector3.UP * 0.9, c, 2.2 * scint, r * 2.0 + 2.0, 3.0)
		if z.ecole == "electricite" and horloge >= float(z.prochain):
			# tempête statique : éclairs du ciel sur un point du disque
			z.prochain = horloge + rng.randf_range(0.08, 0.22)
			var a := rng.randf() * TAU
			var sol := pos + Vector3(cos(a), 0, sin(a)) * r * sqrt(rng.randf())
			var ciel := sol + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(4.5, 6.5), rng.randf_range(-1.2, 1.2))
			var w := 2.0 if rng.randf() < 0.4 else 1.0
			eclair(null, "electricite", w, 0.14, 0.05, func() -> Array:
				var traits: Array = []
				foudre_ramifiee(traits, ciel, sol, 0.5, w, 3, 5)
				return traits)
			emettre("elec_etincelles", null, Transform3D(Basis.IDENTITY, sol), false, 0.6)
			lumiere("foudre", sol + Vector3.UP * 1.5, Color(0.75, 0.75, 1.0), 6.0, 7.0, 9.0, 0.15)
		i -= 1

# ====================================================================== chaîne d'éclairs

func chaine(ecole: String, points: Array) -> void:
	if points.size() < 2:
		return
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(p)
	var teinte := "electricite" if ecole == "electricite" or not ARCS.has(ecole) else ecole
	var dbl: bool = _double.get("electricite", false)
	var t0 := horloge
	var pas := 0.06
	# propagation VISIBLE : chaque saut part 0,06 s après le précédent ; arcs épais, ramifiés
	eclair(null, teinte, 3.0 if dbl else 2.0, 0.45 + pas * (pts.size() - 2), 0.05, func() -> Array:
		var traits: Array = []
		var n := clampi(int((horloge - t0) / pas) + 1, 1, pts.size() - 1)
		for i in range(1, n + 1):
			var l := pts[i - 1].distance_to(pts[i])
			foudre_ramifiee(traits, pts[i - 1], pts[i], l * 0.1, 1.0, 3, 5)
			foudre_ramifiee(traits, pts[i - 1], pts[i], l * 0.14, 0.6, 1, 5)
		return traits)
	var sp := "elec_impact" if teinte == "electricite" else "violet_etincelles"
	for i in range(1, pts.size()):
		var xf := Transform3D(Basis.IDENTITY, pts[i])
		if i == 1:
			emettre(sp, null, xf, false, 0.5)
		else:
			get_tree().create_timer(pas * (i - 1), false).timeout.connect(func() -> void: emettre(sp, null, xf, false, 0.5))
	lumiere("chaine%d" % rng.randi(), pts[0].lerp(pts[pts.size() - 1], 0.5), LUMIERE.get(ecole, LUMIERE.electricite), 8.0, 9.0, 7.0, 0.45)

# ====================================================================== statuts des cibles

func statut_cible(cible: Node3D, statut: String, duree: float) -> void:
	if cible == null or not is_instance_valid(cible):
		return
	var cle := "%d:%s" % [cible.get_instance_id(), statut]
	if duree <= 0.0:
		_statut_retirer(cle)
		return
	if _statuts.has(cle):
		_statuts[cle].fin = horloge + duree
		return
	if _statuts.size() >= MAX_STATUTS:
		# le plus proche de sa fin cède sa place
		var pire := ""
		for k in _statuts:
			if pire == "" or _statuts[k].fin < _statuts[pire].fin:
				pire = k
		_statut_retirer(pire)
	var bb := boite(cible)
	var ext := (bb.size * 0.42).max(Vector3(0.08, 0.15, 0.08))
	var s := {"cible": cible, "statut": statut, "fin": horloge + duree, "emit": [], "voiles": [], "eclair": {}, "bb": bb}
	var noms: Array = {"brulure": ["brulure", "brulure_braise"], "gel": ["gel", "gel_brume"], "choc": ["choc"], "corruption": ["corruption", "corruption_lueur", "corruption_eclats"]}.get(statut, [])
	for nom in noms:
		var pd: Dictionary = PresetsMagie.R[nom]
		var p := emettre(nom, null, Transform3D(Basis.IDENTITY, cible.global_transform * bb.get_center()), true, 1.0, -1.0,
			_pm(nom, pd, {"ext": Vector3(snappedf(ext.x, 0.05), snappedf(ext.y, 0.05), snappedf(ext.z, 0.05))}))
		if p != null:
			s.emit.append(p)
	var voile: Array = {"gel": [1, "#5f9fe8", "#e8f6ff", 0.7, 2], "choc": [3, "#7a7af0", "#f0f2ff", 0.8, 3], "corruption": [4, "#5a1a8a", "#d08aff", 0.6, 0], "brulure": [1, "#b3341f", "#fcb53a", 0.45, 1]}.get(statut, [])
	if not voile.is_empty():
		s.voiles = _voiler(cible, voile[0], Color(voile[1]), Color(voile[2]), voile[3], Vector3.UP, 0.4 if statut == "gel" else 0.0)
	if statut == "choc":
		s.eclair = eclair(null, "electricite", 2.0, -1.0, 0.08, _gen_choc.bind(s))
	_statuts[cle] = s

func _gen_choc(s: Dictionary) -> Array:
	var traits: Array = []
	if not valide(s.cible):
		return traits
	var bb: AABB = s.bb
	var xf: Transform3D = (s.cible as Node3D).global_transform
	for _k in 3:
		var p0 := xf * (bb.position + bb.size * Vector3(rng.randf(), rng.randf(), rng.randf()))
		var p1 := p0 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.2, 0.45)
		traits.append([foudre(p0, p1, 0.06, 3), 1.0, 1.0])
	return traits

func _statut_retirer(cle: String) -> void:
	var s: Dictionary = _statuts.get(cle, {})
	if s.is_empty():
		return
	for p in s.emit:
		arreter(p)
	eclair_fin(s.eclair)
	_devoiler(s.voiles)
	_statuts.erase(cle)

func _maj_statuts() -> void:
	for cle in _statuts.keys():
		var s: Dictionary = _statuts[cle]
		if horloge >= float(s.fin) or not valide(s.cible):
			_statut_retirer(cle)
			continue
		var centre: Vector3 = (s.cible as Node3D).global_transform * (s.bb as AABB).get_center()
		for p in s.emit:
			if is_instance_valid(p):
				p.position = centre
		if s.statut == "brulure":
			lumiere("statut" + cle, centre, LUMIERE.feu, 1.2 + 0.3 * sin(horloge * 19.0), 3.0, 1.0)
		elif s.statut == "corruption":
			lumiere("statut" + cle, centre, LUMIERE.tenebres, 1.0 + 0.3 * sin(horloge * 5.0), 2.5, 0.8)

## Pose la couche additive magie_voile sur les maillages de `n` (seulement ceux sans material_overlay) ; renvoie
## [[maillage, ancien overlay]] pour la retirer.
func _voiler(n: Node3D, motif: int, couleur: Color, coeur: Color, force: float, axe: Vector3, fond := 0.0) -> Array:
	var res: Array = []
	var liste := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		liste.append(n)
	for v in liste:
		var mi := v as MeshInstance3D
		if mi.material_overlay != null or not mi.visible or mi.mesh == null:
			continue
		var m := ShaderMaterial.new()
		m.shader = SH_VOILE
		m.set_shader_parameter("couleur", couleur)
		m.set_shader_parameter("coeur", coeur)
		m.set_shader_parameter("force", force)
		m.set_shader_parameter("motif", motif)
		m.set_shader_parameter("fond", fond)
		var g := _grille_de(mi)
		m.set_shader_parameter("grille", g)
		var echelle := mi.global_basis.get_scale().x
		m.set_shader_parameter("cases", 64.0 / maxf(echelle, 0.0001))
		m.set_shader_parameter("gonfle", 0.006 / maxf(echelle, 0.0001))
		var axe_local := (mi.global_basis.inverse() * (n.global_basis * axe)).normalized()
		m.set_shader_parameter("axe", axe_local)
		mi.material_overlay = m
		res.append(mi)
		if res.size() >= 24:
			break
	return res

func _grille_de(mi: MeshInstance3D) -> float:
	var mat: Material = mi.material_override
	if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0)
	if mat is ShaderMaterial:
		var v: Variant = (mat as ShaderMaterial).get_shader_parameter("grille")
		if v != null:
			return float(v)
		var sh := (mat as ShaderMaterial).shader
		if sh != null and sh.code.contains("uniform float grille"):
			return 135.0
	return 0.0

func _devoiler(voiles: Array) -> void:
	for mi in voiles:
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay is ShaderMaterial and ((mi as MeshInstance3D).material_overlay as ShaderMaterial).shader == SH_VOILE:
			(mi as MeshInstance3D).material_overlay = null

# ====================================================================== enchantements d'arme

func enchant_arme(arme: Node3D, ecole: String, actif: bool) -> void:
	if arme == null or not is_instance_valid(arme):
		return
	var id := arme.get_instance_id()
	if _enchants.has(id):
		if actif and _enchants[id].ecole == ecole:
			return
		_enchant_retirer(id)
	if not actif:
		return
	ecole = _ecole_ok(ecole)
	var bb := boite(arme)
	var axe_i := 0
	for k in 3:
		if bb.size[k] > bb.size[axe_i]:
			axe_i = k
	var axe := Vector3.ZERO
	axe[axe_i] = 1.0
	# la lame : les 3/4 du côté le plus éloigné de l'origine (la poignée est près de l'origine de l'arme)
	var lo := bb.position[axe_i]
	var hi := bb.end[axe_i]
	var vers_haut := absf(hi) >= absf(lo)
	var l := bb.size[axe_i]
	var centre := bb.get_center()
	centre[axe_i] = (hi - l * 0.375) if vers_haut else (lo + l * 0.375)
	var ext := bb.size * 0.5
	ext[axe_i] = l * 0.375
	for k in 3:
		if k != axe_i:
			ext[k] = maxf(ext[k], 0.01)
	var e := {"arme": arme, "ecole": ecole, "emit": [], "voiles": [], "eclair": {}, "centre": centre, "ext": ext, "axe": axe if vers_haut else -axe}
	var noms: Array = {"feu": ["enchant_feu", "enchant_feu_braise"], "glace": ["enchant_glace", "enchant_glace_brume"], "electricite": ["enchant_elec"], "tenebres": ["enchant_ten", "enchant_ten_lueur"], "soin": ["soin_aura"], "protection": ["prot_aura"]}[ecole]
	var echelle := arme.global_basis.get_scale()
	var ext_m := ext * echelle
	for nom in noms:
		var pd: Dictionary = PresetsMagie.R[nom]
		var pm: ParticleProcessMaterial = null
		if String(pd.get("forme", "")) == "boite":
			pm = _pm(nom, pd, {"ext": Vector3(snappedf(ext_m.x, 0.01), snappedf(ext_m.y, 0.01), snappedf(ext_m.z, 0.01))})
		var p := emettre(nom, null, Transform3D(arme.global_basis.orthonormalized(), arme.global_transform * centre), true, 1.0, -1.0, pm)
		if p != null:
			e.emit.append(p)
	var voile: Array = {"feu": [1, "#ec6a1f", "#fff0a8", 0.75], "glace": [2, "#5f9fe8", "#e8f6ff", 0.6], "electricite": [3, "#7a7af0", "#f0f2ff", 0.8], "tenebres": [4, "#7a2ad0", "#d08aff", 0.6], "soin": [0, "#b8d060", "#fff4c0", 0.5], "protection": [0, "#7ab0d8", "#eaf8ff", 0.5]}[ecole]
	e.voiles = _voiler(arme, voile[0], Color(voile[1]), Color(voile[2]), voile[3], e.axe, 0.4)
	if ecole == "electricite":
		e.eclair = eclair(null, "electricite", 1.0, -1.0, 0.06, _gen_lame_arcs.bind(e))
	_enchants[id] = e

func _gen_lame_arcs(e: Dictionary) -> Array:
	var traits: Array = []
	if not valide(e.arme):
		return traits
	var xf: Transform3D = (e.arme as Node3D).global_transform
	var c: Vector3 = e.centre
	var ax: Vector3 = e.axe
	var ext: Vector3 = e.ext
	var demi := absf(ext.dot(ax.abs()))
	var a := xf * (c - ax * demi * rng.randf_range(0.6, 1.0))
	var b := xf * (c + ax * demi * rng.randf_range(0.7, 1.0))
	traits.append([foudre(a, b, 0.015, 4), 1.0, 1.0])
	for _k in 2:
		var o := xf * (c + ax * demi * rng.randf_range(-1.0, 1.0))
		traits.append([foudre(o, o + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.05, 0.12), 0.015, 2), 1.0, 0.8])
	return traits

func _enchant_retirer(id: int) -> void:
	var e: Dictionary = _enchants.get(id, {})
	if e.is_empty():
		return
	for p in e.emit:
		arreter(p)
	eclair_fin(e.eclair)
	_devoiler(e.voiles)
	_enchants.erase(id)

func _maj_enchants() -> void:
	for id in _enchants.keys():
		var e: Dictionary = _enchants[id]
		if not valide(e.arme):
			_enchant_retirer(id)
			continue
		var arme: Node3D = e.arme
		var xf := Transform3D(arme.global_basis.orthonormalized(), arme.global_transform * (e.centre as Vector3))
		for p in e.emit:
			if is_instance_valid(p):
				p.transform = xf
		var scint := 1.0 + (0.2 * sin(horloge * 21.0) if e.ecole == "feu" else (0.5 * rng.randf() - 0.25 if e.ecole == "electricite" else 0.0))
		lumiere("enchant%d" % id, xf.origin, LUMIERE[e.ecole], 1.1 * scint, 2.8, 1.5)

# ====================================================================== réactions entre écoles

func reaction(nom: String, position: Vector3, rayon: float) -> void:
	var r := maxf(rayon, 0.3)
	var kz := clampf(r / 2.0, 0.5, 2.0)
	var base := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.3)
	var rq := snappedf(r, 0.25)
	match nom:
		"vapeur":
			emettre("vapeur", null, base, false, kz)
			emettre("vapeur_gouttes", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r * 1.2, 0.5, {"couleur": "#c8d2dc", "coeur": "#f6f8ff", "anneau": 0.88, "epaisseur": 0.07, "texels": 56.0, "eclat": 1.2})
			lumiere("vapeur%d" % rng.randi(), position + Vector3.UP, Color(1.0, 0.9, 0.8), 3.0, r * 2.0 + 2.0, 5.0, 0.4)
		"decharge":
			emettre("glace_impact_eclats", null, base, false, kz)
			emettre("elec_impact", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.35, {"couleur": "#5f9fe8", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.8})
			eclair(null, "glace", 1.0, 0.55, 0.05, _gen_radial.bind(position, r, 8, 0.05))
			lumiere("decharge%d" % rng.randi(), position + Vector3.UP * 0.5, Color(0.7, 0.8, 1.0), 8.0, r * 2.0 + 3.0, 9.0, 0.4)
		"decharge_incendiaire":
			emettre("feu_explosion", null, base, false, kz * 0.7)
			emettre("incendiaire_etincelles", null, base, false, kz)
			emettre("feu_impact_fumee", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r * 1.1, 0.4, {"couleur": "#ec6a1f", "coeur": "#fffbe8", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0, "eclat": 1.8})
			eclair(null, "feu", 1.0, 0.5, 0.05, _gen_radial.bind(position, r, 7, 0.4))
			lumiere("incendiaire%d" % rng.randi(), position + Vector3.UP * 0.6, Color(1.0, 0.75, 0.45), 9.0, r * 2.0 + 3.0, 9.0, 0.45)
		"cristaux_corrompus":
			var pd: Dictionary = PresetsMagie.R["corrompu_scintille"]
			emettre("corrompu_scintille", null, Transform3D(Basis.IDENTITY, position), false, kz, -1.0, _pm("corrompu_scintille", pd, {"r": rq}))
			emettre("ten_impact_sombre", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.5, {"couleur": "#7a5ad0", "coeur": "#e0b0ff", "anneau": 0.9, "epaisseur": 0.07, "texels": 64.0})
			var nb := clampi(int(r * 5.0), 6, 20)
			for k in nb:
				var a := rng.randf() * TAU
				var off := Vector3(cos(a), 0, sin(a)) * r * sqrt(rng.randf_range(0.05, 1.0))
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.2, 0.8)).normalized()
				var h := rng.randf_range(0.7, 1.7) * kz
				pic("corrompu", position + off, axe, h * rng.randf_range(0.15, 0.25), h, rng.randf() * 0.2, 0.15, horloge + 2.2)
			lumiere("corrompu%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.45, 1.0), 5.0, r * 2.0 + 2.0, 7.0, 0.8)
		"flammes_obscures":
			var z := {"ecole": "tenebres", "pos": position, "r": r, "duree": 2.0, "t0": horloge, "emit": [], "prochain": INF, "fini": false, "eclair": {}}
			for n2 in ["obscur_sol", "obscur_sombre"]:
				var pd: Dictionary = PresetsMagie.R[n2]
				var p := emettre(n2, null, Transform3D(Basis.IDENTITY, position), true, kz, -1.0, _pm(n2, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			emettre("ten_eruption", null, Transform3D(Basis.IDENTITY, position), false, kz * 0.6, -1.0, _pm("ten_eruption", PresetsMagie.R["ten_eruption"], {"r": snappedf(r * 0.5, 0.25)}))
			disque(position, Vector3.UP, r, r, 2.0, {"couleur": "#6a1aa0", "coeur": "#0c0614", "anneau": 0.95, "epaisseur": 0.05, "remplissage": 0.4, "texels": 56.0, "eclat": 1.0}, true, false, 0.3)
			_zones.append(z)
			lumiere("obscur%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.3, 1.0), 5.0, r * 2.0 + 2.0, 7.0, 0.6)
		"arcs_violets":
			emettre("violet_etincelles", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.35, {"couleur": "#7a2ad0", "coeur": "#f0d0ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.7})
			eclair(null, "violet", 1.0, 0.6, 0.05, _gen_radial.bind(position, r, 6, 0.6))
			lumiere("violet%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.4, 1.0), 7.0, r * 2.0 + 3.0, 8.0, 0.45)
		_:
			push_warning("EffetsMagie.reaction : réaction inconnue « %s »" % nom)

func _gen_radial(centre: Vector3, r: float, n: int, montee: float) -> Array:
	var traits: Array = []
	var o := centre + Vector3.UP * 0.08
	for _k in n:
		var a := rng.randf() * TAU
		var fin := centre + Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.5, 1.0) + Vector3.UP * rng.randf_range(0.02, montee)
		foudre_ramifiee(traits, o, fin, r * 0.08, 1.0, 1, 4)
	return traits

# ====================================================================== double incantation

func double(ecole: String, actif: bool) -> void:
	ecole = _ecole_ok(ecole)
	_double[ecole] = actif
	if not actif:
		_double.erase(ecole)

func _maj_double() -> void:
	for ecole in _double_vis.keys():
		if not _double.get(ecole, false):
			_double_fin(_double_vis[ecole])
			_double_vis.erase(ecole)
	for ecole in _double:
		var mains: Array = []
		for a in _auras.values():
			if a.ecole == ecole and valide(a.main):
				mains.append(a)
		var v: Dictionary = _double_vis.get(ecole, {})
		if mains.size() < 2:
			if not v.is_empty():
				_double_fin(v)
				_double_vis.erase(ecole)
			continue
		var p0: Vector3 = (mains[0].ancre as Node3D).position
		var p1: Vector3 = (mains[1].ancre as Node3D).position
		var milieu := (p0 + p1) * 0.5
		if v.is_empty():
			v = {"noeud": Node3D.new(), "emit": [], "eclair": {}, "p0": p0, "p1": p1}
			add_child(v.noeud)
			var n: Node3D = v.noeud
			match ecole:
				"tenebres":
					_vortex_main(n, 0.16)
				"glace":
					var p := emettre("glace_double_orbite", n, Transform3D.IDENTITY, true)
					if p != null:
						v.emit.append(p)
				"feu":
					var p := emettre("feu_aura", n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.2), Vector3.ZERO), true, 1.5)
					if p != null:
						v.emit.append(p)
				"electricite":
					v.eclair = eclair(null, "electricite", 2.0, -1.0, 0.05, func() -> Array:
						var t: Array = []
						foudre_ramifiee(t, v.p0, v.p1, (v.p0 as Vector3).distance_to(v.p1) * 0.15, 2.0, 2, 4)
						return t)
				_:
					var mi := MeshInstance3D.new()
					mi.mesh = _quad_sol
					var m := ShaderMaterial.new()
					m.shader = SH_SOL
					var pal: Array = PresetsMagie.R[PresetsMagie.de(ecole, "trainee")].rampe
					m.set_shader_parameter("couleur", Color(pal[2]))
					m.set_shader_parameter("coeur", Color(pal[0]))
					m.set_shader_parameter("runes", 1.0)
					m.set_shader_parameter("tourne", 0.3)
					m.set_shader_parameter("texels", 32.0)
					m.set_shader_parameter("face_camera", true)
					mi.material_override = m
					mi.scale = Vector3.ONE * 0.14
					n.add_child(mi)
			_double_vis[ecole] = v
		v.p0 = p0
		v.p1 = p1
		(v.noeud as Node3D).position = milieu
		lumiere("double" + ecole, milieu, LUMIERE[ecole], 3.5, 6.0, 6.0)

func _double_fin(v: Dictionary) -> void:
	for p in v.emit:
		arreter(p)
	eclair_fin(v.eclair)
	var n: Node3D = v.noeud
	if is_instance_valid(n):
		# les émetteurs du pool sous ce nœud y retournent avant sa libération
		for e in _emetteurs:
			if is_instance_valid(e.p) and (e.p as Node).get_parent() == n:
				n.remove_child(e.p)
				add_child(e.p)
				e.fin = horloge
		n.queue_free()

# ====================================================================== préchauffage

## Compile une fois chaque réglage (particules hors de vue) : évite l'à-coup du premier sort.
func prechauffer() -> void:
	var loin := Transform3D(Basis.IDENTITY, Vector3(0, -500, 0))
	for nom in PresetsMagie.R:
		var p := emettre(nom, null, loin, false, 0.05, 0.05)
		if p == null:
			break
	pic("glace", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)
	pic("tenebres", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)
	pic("corrompu", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)
