class_name RayonNoir
extends Node3D
## v3 : RAYON droit à longue portée (40 m), cercle runique animé au départ, impact soigné (anneaux, étincelles), palette au choix
##   (--palette-rayon=0|1|2, voir PALETTES). Plus de drain : c'est un rayon, pas un sort ciblé.
## RAYON NOIR : visuel du sort CONTINU des ténèbres (data/sorts/rayon_noir.tres, type CANALISE, forme « rayon_noir »), sur le modèle du
## rayon tiré d'un coup (RayonNeant, scripts/magie/rayon_neant.gd) : même tube englobant (RayonNeant._tube()), shader dérivé
## (shaders/rayon_noir_faisceau.gdshader : cœur noir profond, liseré pourpre, ondulation lente qui court vers la cible, fumée déchirée
## et brins enroulés), tache d'ombre dérivée de celle du néant (shaders/rayon_noir_tache.gdshader) et mêmes bouffées (NoyauEcole.Bouffees).
## Un nœud PAR MAIN (par_paume), piloté chaque image par LanceurSorts.canaliser → EffetsMagie.rayon_noir :
##   allumage (~0,2 s) : la tête du rayon file de la main à la cible ; tenu : le rayon suit la visée (l'inertie est dans
##   LanceurSorts, la même pour les dégâts et l'image), s'arrête au premier décor ou au premier ennemi ;
##   au bout : tache d'ombre qui RONGE la surface (elle grandit, son bord bouillonne ; balayée, elle laisse des taches qui s'effacent),
##   volutes de fumée noire qui montent, quelques braises violettes, lumière violette faible (sur les murs) ;
##   le long du rayon : fumée sombre qui s'en échappe, 3 à 5 PETITES RUNES nordiques (violet pâle) qui glissent vers la cible et
##   s'éteignent (shader des runes de la main, shaders/runes_orbite.gdshader) ;
##   relâchement : le rayon se resserre et se dissipe en fumée (0,35 s), les taches s'effacent (3 s).
## PERF : 1 maillage de rayon, 1 tache tenue + 5 taches laissées (quads), 2 MultiMesh (fumée 26, braises 14), 5 quads de runes,
## 2 lumières du pool de GestionMagie (aucune OmniLight créée ici). Aucune particule en masse.
## `RayonNoir.actif = false` (--sans-rayon-noir) : le sort n'existe pas (EquipementMains), rien n'est créé.

static var actif := not OS.get_cmdline_user_args().has("--sans-rayon-noir")
const ID := "rayon_noir"
const FORME := "rayon_noir"

const SH_FAISCEAU := preload("res://shaders/rayon_noir_faisceau.gdshader")
const SH_HALO := preload("res://shaders/rayon_noir_halo.gdshader")
const SH_TACHE := preload("res://shaders/rayon_noir_tache.gdshader")
const SH_RUNE := preload("res://shaders/runes_orbite.gdshader")
const SH_VITESSE := preload("res://shaders/rayon_vitesse.gdshader")
const SH_CERCLE := preload("res://shaders/rayon_cercle.gdshader")
const SH_IMPACT := preload("res://shaders/rayon_impact.gdshader")
## Cercle runique du départ : diamètre (m), distance devant la paume (m), durée d'ouverture / de fermeture (s).
const CERCLE_D := 0.3
const CERCLE_DEVANT := 0.2
const CERCLE_OUVRE := 0.22
const CERCLE_FERME := 0.3
## Impact : côté du quad (m).
const IMPACT_D := 1.5
## Palettes : cœur sombre + liseré lumineux. noir, fume, bord, filet (faisceau), accent (cercle/impact), lumiere, rune, coeur_rune, fumee[4], braise[4].
const PALETTES := [
	{"nom": "magenta_nocturne", "noir": "#05010c", "fume": "#3a0b5c", "bord": "#c622a8", "filet": "#ffc4f2", "accent": "#e23cc4", "lumiere": "#a02cd8",
		"rune": "#e89cff", "coeur_rune": "#fff0ff", "fumee": ["#04010a", "#1c0836", "#5a1a86", "#b45ae0"], "braise": ["#07030c", "#a02ab8", "#ff8ae8", "#fff0fb"]},
	{"nom": "indigo_aurore", "noir": "#030615", "fume": "#16124a", "bord": "#5a46ff", "filet": "#b8f4ff", "accent": "#54d8ff", "lumiere": "#4a52ff",
		"rune": "#9fd8ff", "coeur_rune": "#f0fcff", "fumee": ["#02030c", "#0c0e38", "#2c2a98", "#6a90f0"], "braise": ["#03050f", "#3a3ad0", "#78e4ff", "#f0fdff"]},
	{"nom": "pourpre_braise", "noir": "#0a0108", "fume": "#4a0a38", "bord": "#d02468", "filet": "#ffd6b8", "accent": "#ff7a4a", "lumiere": "#c42a6a",
		"rune": "#ffa0c0", "coeur_rune": "#fff2e6", "fumee": ["#07010a", "#2a0824", "#7a1850", "#d8607a"], "braise": ["#0a0206", "#c02060", "#ff9a5a", "#fff4e0"]},
]
static var palette_n := clampi(int(_arg_palette()), 0, PALETTES.size() - 1)
static func _arg_palette() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--palette-rayon="):
			return int(a.get_slice("=", 1))
	return 0
static func pal() -> Dictionary:
	return PALETTES[palette_n]
## Allumage (s) : la tête du rayon file de la main à la cible ; extinction (s) : le rayon se resserre et se dissipe.
const ALLUMAGE := 0.1
const EXTINCTION := 0.07
const VIE_TENUE := 0.3
## Le nœud s'éteint seul s'il n'est plus nourri (main coupée sans arrêt explicite).
const OUBLI := 0.25
## Rayon du faisceau (m) loin de la main (× largeur du sort) et à la sortie de la paume ; distance d'ouverture.
const RAYON_LOIN := 0.4
const RAYON_MAIN := 0.045
const OUVERTURE := 7.0
## Tache d'ombre : côté du quad (m ; la flaque en couvre ~25 à 80 %) à l'impact, croissance pendant qu'on tient le même point, taches laissées en balayant.
const TACHE := 1.9
const TACHE_MAX := 3.2
const NB_TACHES_LAISSEES := 5
const PAS_TACHE := 0.7
const DUREE_TACHE_LAISSEE := 3.0
const NB_FUMEE := 26
const NB_BRAISES := 24
## Runes qui glissent le long du rayon : nombre de quads, période d'émission (s), durée du trajet (s), taille (m).
const NB_RUNES := 9
const PERIODE_RUNE := 0.11
const TRAJET_RUNE := 0.42
const TAILLE_RUNE := 0.12
const SIGNES := [4, 1, 5, 7, 6]
## v2 : l'orbe tenu dans la main pendant ce sort (NoyauEcole, runes de la main) est réduit (il cachait la gauche de l'écran).
const TAILLE_ORBE := 0.64

## Un rayon par main (id de la paume → RayonNoir).
static var par_paume := {}
## Compteurs (tests) : rayons créés, images nourries, arrêts.
static var stats := {"crees": 0, "images": 0, "arrets": 0}

var paume: Node3D
var debut := Vector3.ZERO
var fin := Vector3.ZERO
var normale := Vector3.UP
var touche_decor := false
var cible: Node3D
var largeur := 1.0
var puissance := 1.0
var allume := true
var _t := 0.0          # depuis l'allumage
var _t_fin := -1.0     # depuis le relâchement (-1 = tenu)
var _vu := 0.0         # dernier appel de maj (horloge locale)
var _fin_l := Vector3.ZERO
var _faisceau: MeshInstance3D
var _vitesse: MeshInstance3D
var _mat_vitesse: ShaderMaterial
var _cercle: MeshInstance3D
var _mat_cercle: ShaderMaterial
var _impact: MeshInstance3D
var _mat_impact: ShaderMaterial
var _mat: ShaderMaterial
var _halo: ShaderMaterial
var _tache: MeshInstance3D
var _mat_tache: ShaderMaterial
var _t_tache := 0.0     # temps passé sur le point actuel
var _pt_tache := Vector3.INF
var _dia_k := 1.0          # réduction de la tache pour qu'elle reste sur la surface (arête de pilier, coin)
var _laissees: Array = []   # [{mi, mat, t}]
var _fumee: NoyauEcole.Bouffees
var _braises: NoyauEcole.Bouffees
var _bouf: Array = []       # bouffées vivantes [{p, v, t, vie, s, h, sorte}]
var _runes: Array = []      # [{mi, t (−1 = libre), h}]
var _t_rune := 0.0
var _t_arrache := 0.0
var _t_bouf := 0.0
var _t_braise := 0.0
var _graine := 0.0
var _corps_vu := {}         # cible → dernier embrasement (horloge)

# ------------------------------------------------------------------ API statique

## Une image de rayon tenu, depuis `paume` (suivie) : `depart` (paume ou point de fusion), `fin` (premier décor ou ennemi), `normale`
## (surface touchée), `touche_decor`, `cible_` (ennemi touché ou null), `largeur_` (largeur du sort), `puissance_` (double : >1).
static func maj(paume_: Node3D, depart: Vector3, fin_: Vector3, normale_: Vector3, touche_decor_: bool, cible_: Node3D, largeur_: float, puissance_: float) -> RayonNoir:
	if not actif or paume_ == null or not is_instance_valid(paume_):
		return null
	var id := paume_.get_instance_id()
	var r: RayonNoir = par_paume.get(id)
	if r == null or not is_instance_valid(r) or r.is_queued_for_deletion() or not r.allume:
		r = RayonNoir.new()
		r.name = "RayonNoir"
		r.paume = paume_
		r.debut = depart
		r.fin = fin_
		r._fin_l = fin_   # v2 : le rayon jaillit d'un coup jusqu'à l'impact (la tête du shader file en 0,1 s)
		r.largeur = largeur_
		r.puissance = puissance_
		var parent := paume_.get_tree().current_scene if paume_.get_tree().current_scene != null else paume_.get_tree().root
		parent.add_child(r)
		par_paume[id] = r
		stats.crees = int(stats.crees) + 1
		SonsMagie.rayon_noir_allume(depart)
		var g := GestionMagie.obtenir()
		if g != null and not EffetsMagie.muet:   # petit éclair de départ : bref, dans la main
			g.lumiere("rayon_noir_eclair%d" % id, depart, Color(0.75, 0.45, 1.0), 3.0, 3.0, 0.9, 0.16)
	r.debut = depart
	r.fin = fin_
	r.normale = normale_.normalized() if normale_.length() > 0.01 else Vector3.UP
	r.touche_decor = touche_decor_
	r.cible = cible_
	r.largeur = largeur_
	r.puissance = puissance_
	r._vu = r._t
	stats.images = int(stats.images) + 1
	return r

## Relâchement (ou mana à 0, interruption) : le rayon de cette main se dissipe.
static func arreter(paume_: Node3D) -> void:
	if paume_ == null:
		return
	var id := paume_.get_instance_id()
	var r: RayonNoir = par_paume.get(id)
	par_paume.erase(id)
	if r != null and is_instance_valid(r) and r.allume:
		r._eteindre()

static func existe(paume_: Node3D) -> bool:
	if paume_ == null:
		return false
	var r: RayonNoir = par_paume.get(paume_.get_instance_id())
	return r != null and is_instance_valid(r) and r.allume

static func tout_arreter() -> void:
	for id in par_paume.keys():
		var r: RayonNoir = par_paume[id]
		if r != null and is_instance_valid(r):
			r.queue_free()
	par_paume.clear()

# ------------------------------------------------------------------ construction

func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	_graine = randf() * 10.0
	_mat = ShaderMaterial.new()
	_mat.shader = SH_FAISCEAU
	_mat.set_shader_parameter("graine", _graine)
	_mat.set_shader_parameter("ouverture", OUVERTURE)
	var pl := pal()
	for k in ["noir", "fume", "bord", "filet"]:
		_mat.set_shader_parameter(k, Color(pl[k]))
	_halo = ShaderMaterial.new()
	_halo.shader = SH_HALO
	_halo.set_shader_parameter("graine", _graine)
	_halo.set_shader_parameter("ouverture", OUVERTURE)
	_halo.set_shader_parameter("bord", Color(pl["bord"]))
	_halo.set_shader_parameter("force_halo", 0.85)
	_halo.render_priority = 1
	_mat.next_pass = _halo
	_faisceau = _mi(RayonNeant._tube(), _mat, 50.0)
	# v3d : lignes de vitesse autour du rayon (un second tube, coque plus large ; aucun traitement CPU par trait)
	_mat_vitesse = ShaderMaterial.new()
	_mat_vitesse.shader = SH_VITESSE
	_mat_vitesse.set_shader_parameter("graine", _graine)
	_mat_vitesse.set_shader_parameter("bord", Color(pl["bord"]))
	_mat_vitesse.set_shader_parameter("filet", Color(pl["filet"]))
	_mat_vitesse.set_shader_parameter("ouverture", OUVERTURE)
	_vitesse = _mi(RayonNeant._tube(), _mat_vitesse, 50.0)
	_mat_tache = _nouvelle_tache_mat()
	_tache = _mi(_quad(), _mat_tache, 2.0)
	_tache.visible = false
	for i in NB_TACHES_LAISSEES:
		var m := _nouvelle_tache_mat()
		var t := _mi(_quad(), m, 2.0)
		t.visible = false
		_laissees.append({"mi": t, "mat": m, "t": -1.0})
	_fumee = NoyauEcole.Bouffees.new(NB_FUMEE, RayonNeant._mat_bouffee(0, pl["fumee"], 0.9, 0.95))
	_braises = NoyauEcole.Bouffees.new(NB_BRAISES, RayonNeant._mat_bouffee(1, pl["braise"], 0.7, 1.25))
	for b: NoyauEcole.Bouffees in [_fumee, _braises]:
		b.mi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
		add_child(b.mi)
	var mr := ShaderMaterial.new()
	mr.shader = SH_RUNE
	mr.set_shader_parameter("couleur", Color(pl["rune"]))
	mr.set_shader_parameter("coeur", Color(pl["coeur_rune"]))
	for i in NB_RUNES:
		var q := _mi(_quad(), mr, 4.0)
		q.set_instance_shader_parameter("symbole", float(SIGNES[i % SIGNES.size()]))
		q.visible = false
		_runes.append({"mi": q, "t": -1.0, "h": randf()})
	_mat_cercle = ShaderMaterial.new()
	_mat_cercle.shader = SH_CERCLE
	_mat_cercle.set_shader_parameter("accent", Color(pl["accent"]))
	_mat_cercle.set_shader_parameter("bord", Color(pl["bord"]))
	_mat_cercle.set_shader_parameter("filet", Color(pl["filet"]))
	_mat_cercle.set_shader_parameter("noir", Color(pl["noir"]))
	_cercle = _mi(_quad(), _mat_cercle, 2.0)
	_mat_impact = ShaderMaterial.new()
	_mat_impact.shader = SH_IMPACT
	_mat_impact.set_shader_parameter("accent", Color(pl["accent"]))
	_mat_impact.set_shader_parameter("bord", Color(pl["bord"]))
	_mat_impact.set_shader_parameter("filet", Color(pl["filet"]))
	_impact = _mi(_quad(), _mat_impact, 2.0)
	_impact.visible = false
	_t_rune = PERIODE_RUNE * 0.6   # première rune peu après l'allumage

func _mi(mesh: Mesh, mat: Material, marge: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.top_level = true
	m.layers = CoucheMagie.CALQUE
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = marge
	add_child(m)
	return m

static var _quad_mesh: QuadMesh
static func _quad() -> QuadMesh:
	if _quad_mesh == null:
		_quad_mesh = QuadMesh.new()
		_quad_mesh.size = Vector2.ONE
	return _quad_mesh

func _nouvelle_tache_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_TACHE
	m.set_shader_parameter("graine", randf() * 10.0)
	return m

func _eteindre() -> void:
	allume = false
	_t_fin = 0.0
	stats.arrets = int(stats.arrets) + 1
	SonsMagie.rayon_noir_eteint(_fin_l)
	# le rayon se dissipe en fumée : bouffées posées le long de l'axe, qui s'écartent et montent
	var l := debut.distance_to(_fin_l)
	var n := clampi(int(l / 0.9) + 3, 4, 12)
	for k in n:
		var u := (float(k) + randf()) / n
		var p := debut.lerp(_fin_l, u)
		var lat := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized()
		_bouffee(p, lat * randf_range(0.3, 0.7) + Vector3.UP * 0.25, randf_range(0.7, 1.1), randf_range(0.35, 0.6) * largeur, 0)

# ------------------------------------------------------------------ image

func _process(dt: float) -> void:
	_t += dt
	var g := GestionMagie.obtenir()
	if allume and _t - _vu > OUBLI:
		par_paume.erase(paume.get_instance_id() if paume != null and is_instance_valid(paume) else 0)
		_eteindre()
	var cam := get_viewport().get_camera_3d()
	var cb := cam.global_basis if cam != null else Basis.IDENTITY
	# bout du rayon lissé (pas de saut entre le centre d'un ennemi et le mur derrière lui)
	_fin_l = _fin_l.lerp(fin, 1.0 - exp(-dt * 30.0)) if allume else _fin_l
	var vie := VIE_TENUE
	if allume:
		vie = 0.1 * clampf(_t / ALLUMAGE, 0.0, 1.0) if _t < ALLUMAGE else VIE_TENUE
	else:
		_t_fin += dt
		vie = lerpf(0.6, 1.0, clampf(_t_fin / EXTINCTION, 0.0, 1.0))
	_faisceau.visible = vie < 0.999
	_vitesse.visible = _faisceau.visible
	if _faisceau.visible:
		_placer_faisceau(vie)
		if g != null and g.couche != null:
			g.couche.demander()
	_maj_cercle(g)
	_maj_impact(g)
	_maj_tache(dt, cb, g)
	_maj_runes(dt, cb)
	_maj_bouffees(dt, cb)
	_maj_lumieres(g, vie)
	if allume:
		_maj_corps(g)
	var vivant := allume or _t_fin < EXTINCTION or not _bouf.is_empty()
	for e in _laissees:
		vivant = vivant or float(e.t) >= 0.0
	if not vivant or (not allume and _t_fin > DUREE_TACHE_LAISSEE + 0.5):
		queue_free()

func _placer_faisceau(vie: float) -> void:
	var axe := _fin_l - debut
	var l := maxf(axe.length(), 0.1)
	var d := axe / l
	var x := Vector3.UP.cross(d)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := d.cross(x).normalized()
	_faisceau.global_transform = Transform3D(Basis(x, y, d * l), debut)
	_vitesse.global_transform = _faisceau.global_transform
	_vitesse.visible = true
	var kv := clampf(puissance, 1.0, 1.6)
	_mat_vitesse.set_shader_parameter("longueur", l)
	_mat_vitesse.set_shader_parameter("rayon_max", RAYON_LOIN * largeur * kv)
	_mat_vitesse.set_shader_parameter("rayon_min", RAYON_MAIN * kv)
	_mat_vitesse.set_shader_parameter("vie", vie)
	var k := clampf(puissance, 1.0, 1.6)
	for m: ShaderMaterial in [_mat, _halo]:
		m.set_shader_parameter("longueur", l)
		m.set_shader_parameter("rayon_max", RAYON_LOIN * largeur * k)
		m.set_shader_parameter("rayon_min", RAYON_MAIN * k)
		m.set_shader_parameter("eclat", 0.95 + 0.3 * (k - 1.0))
		m.set_shader_parameter("vie", vie)

## Cercle runique au départ : perpendiculaire au rayon, devant la paume ; il s'ouvre en tournant, ses runes s'allument une à une.
func _maj_cercle(g: GestionMagie) -> void:
	var ouv := clampf(_t / CERCLE_OUVRE, 0.0, 1.0) if allume else 1.0 - clampf(_t_fin / CERCLE_FERME, 0.0, 1.0)
	if ouv <= 0.01:
		_cercle.visible = false
		return
	var axe := _fin_l - debut
	var d := axe / maxf(axe.length(), 0.1)
	var x := Vector3.UP.cross(d)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := d.cross(x).normalized()
	var dia := CERCLE_D * clampf(puissance, 1.0, 1.3)
	# quad : X, Y dans le plan du cercle, Z = le rayon (face visible côté caméra grâce à cull_disabled)
	_cercle.global_transform = Transform3D(Basis(x * dia, y * dia, d), debut + d * CERCLE_DEVANT)
	_cercle.visible = true
	_mat_cercle.set_shader_parameter("ouv", ouv)
	_mat_cercle.set_shader_parameter("t", _t)
	if g != null and g.couche != null:
		g.couche.demander()

## Impact soigné : disque lumineux, anneaux qui s'élargissent, étincelles rayonnantes, petit cercle de runes.
func _maj_impact(g: GestionMagie) -> void:
	var k := clampf(_t / 0.12, 0.0, 1.0) if allume else 1.0 - clampf(_t_fin / 0.18, 0.0, 1.0)
	if k <= 0.01 or _t < ALLUMAGE * 0.8:
		_impact.visible = false
		return
	var n := normale if (touche_decor or cible == null) else (debut - _fin_l).normalized()
	var u := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
	var w := n.cross(u)
	var dia := IMPACT_D * clampf(largeur / 0.6, 0.8, 1.5) * clampf(puissance, 1.0, 1.3) * (0.4 + 0.6 * k)
	_impact.global_transform = Transform3D(Basis(u * dia, w * dia, n), _fin_l + n * 0.07)
	_impact.visible = true
	_mat_impact.set_shader_parameter("ouv", k)
	_mat_impact.set_shader_parameter("t", _t)
	if g != null and g.couche != null:
		g.couche.demander()

## Tache d'ombre au bout (décor seulement : sur un ennemi, c'est OmbreCorps qui rampe sur lui).
func _maj_tache(dt: float, _cb: Basis, g: GestionMagie) -> void:
	var tenu := allume and touche_decor and cible == null and _t >= ALLUMAGE * 0.8
	if tenu:
		if _pt_tache == Vector3.INF or _pt_tache.distance_to(_fin_l) > PAS_TACHE:
			if _pt_tache != Vector3.INF and _tache.visible:
				_laisser(_tache.global_transform)
			_pt_tache = _fin_l
			_t_tache = 0.0
			_dia_k = _place_libre(_fin_l, normale)
		_t_tache += dt
		var n := normale
		var dia := lerpf(TACHE, TACHE_MAX, smoothstep(0.0, 2.5, _t_tache)) * clampf(largeur / 0.6, 0.8, 1.6) * _dia_k
		var u := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
		var w := n.cross(u)
		_tache.global_transform = Transform3D(Basis(u * dia, w * dia, n), _fin_l + n * 0.03)
		_tache.visible = true
		# le bord bouillonne (la forme change lentement : la tache ronge la surface)
		_mat_tache.set_shader_parameter("etendue", smoothstep(0.0, 1.6, _t_tache) * 0.55 + smoothstep(0.0, 0.25, _t_tache) * 0.45)
		_mat_tache.set_shader_parameter("fondu", 1.0)
		if g != null and g.couche != null:
			g.couche.demander()
	elif _tache.visible:
		_laisser(_tache.global_transform)
		_tache.visible = false
		_pt_tache = Vector3.INF
	for e in _laissees:
		if float(e.t) < 0.0:
			continue
		e.t = float(e.t) + dt
		var k := float(e.t) / DUREE_TACHE_LAISSEE
		if k >= 1.0:
			e.t = -1.0
			(e.mi as MeshInstance3D).visible = false
			continue
		(e.mat as ShaderMaterial).set_shader_parameter("fondu", 1.0 - k)

## Part de la taille de la tache qui tient sur la surface touchée (4 rayons autour du point, à 0,35 × la taille maxi) : 1, 0,6 ou 0,35.
## Une tache est un carré posé sur la surface : sans ce test elle déborderait d'une arête de pilier, en l'air.
func _place_libre(p: Vector3, n: Vector3) -> float:
	if not is_inside_tree():
		return 1.0
	var monde := get_world_3d().direct_space_state
	var u := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
	var w := n.cross(u)
	for k: float in [1.0, 0.6, 0.35]:
		var r := TACHE_MAX * 0.35 * k * clampf(largeur / 0.6, 0.8, 1.6)
		var ok := true
		for dv: Vector3 in [u, -u, w, -w]:
			var a := p + n * 0.25 + dv * r
			var q := PhysicsRayQueryParameters3D.create(a, a - n * 0.5, 1)
			var h := monde.intersect_ray(q)
			if h.is_empty() or absf((h["position"] - p).dot(n)) > 0.08:
				ok = false
				break
		if ok:
			return k
	return 0.25

func _laisser(tr: Transform3D) -> void:
	var libre: Dictionary = {}
	var plus_vieille := -1.0
	for e in _laissees:
		if float(e.t) < 0.0:
			libre = e
			break
		if float(e.t) > plus_vieille:
			plus_vieille = float(e.t)
			libre = e
	(libre.mi as MeshInstance3D).global_transform = tr
	(libre.mi as MeshInstance3D).visible = true
	(libre.mat as ShaderMaterial).set_shader_parameter("graine", float(_mat_tache.get_shader_parameter("graine")))
	(libre.mat as ShaderMaterial).set_shader_parameter("etendue", float(_mat_tache.get_shader_parameter("etendue")))
	(libre.mat as ShaderMaterial).set_shader_parameter("fondu", 1.0)
	_mat_tache.set_shader_parameter("graine", randf() * 10.0)   # la suivante a sa propre forme
	libre.t = 0.0

## 3 à 5 runes qui glissent de la main vers la cible le long du rayon, en tournant lentement autour de l'axe, puis s'éteignent.
func _maj_runes(dt: float, cb: Basis) -> void:
	if allume and _t > ALLUMAGE:
		_t_rune += dt
		if _t_rune >= PERIODE_RUNE:
			_t_rune -= PERIODE_RUNE * randf_range(0.85, 1.15)
			for r in _runes:
				if float(r.t) < 0.0:
					r.t = 0.0
					r.h = randf()
					break
	var axe := _fin_l - debut
	var l := maxf(axe.length(), 0.1)
	var d := axe / l
	var x := Vector3.UP.cross(d)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := d.cross(x).normalized()
	var fondu_fin := 1.0 if allume else 1.0 - clampf(_t_fin / EXTINCTION, 0.0, 1.0)
	for r in _runes:
		var mi: MeshInstance3D = r.mi
		if float(r.t) < 0.0:
			mi.visible = false
			continue
		r.t = float(r.t) + dt
		# trajet plus court pour un rayon court (vitesse ~ constante, jamais moins de 0,45 s)
		var duree := clampf(TRAJET_RUNE * l / 8.0, 0.22, TRAJET_RUNE * 1.4)
		var p := float(r.t) / duree
		if p >= 1.0 or fondu_fin <= 0.01:
			r.t = -1.0
			mi.visible = false
			continue
		var u := 0.08 + 0.86 * (1.0 - pow(1.0 - p, 1.6))
		var a := TAU * float(r.h) + p * 2.2
		var rr := RAYON_LOIN * largeur * (0.55 + 0.35 * smoothstep(0.0, 0.3, u)) * (1.0 - 0.6 * smoothstep(0.75, 1.0, p))
		var pos := debut + d * (u * l) + (x * cos(a) + y * sin(a)) * rr
		var s := TAILLE_RUNE * (0.75 + 0.35 * sin(PI * minf(p * 1.3, 1.0))) * clampf(puissance, 1.0, 1.4)
		mi.global_transform = Transform3D(cb.scaled(Vector3.ONE * s), pos)
		var al := smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.62, 1.0, p)) * fondu_fin
		mi.set_instance_shader_parameter("eclat", 2.3 * al * (0.85 + 0.15 * sin(_t * 9.0 + float(r.h) * 6.0)))
		mi.visible = al > 0.01

## Fumée qui s'échappe du rayon, volutes et braises au point d'impact.
func _maj_bouffees(dt: float, cb: Basis) -> void:
	if allume and _t > ALLUMAGE * 0.5:
		var l := debut.distance_to(_fin_l)
		# fumée sombre qui s'échappe le long du rayon (au-delà du premier mètre : rien devant l'œil)
		_t_bouf += dt
		while _t_bouf > 0.09:
			_t_bouf -= 0.09
			if l > 1.6:
				var p := debut.lerp(_fin_l, randf_range(minf(1.2 / l, 0.5), 0.92))
				var lat := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
				_bouffee(p, lat * randf_range(0.15, 0.4) + Vector3.UP * 0.18, randf_range(0.7, 1.0), randf_range(0.18, 0.3) * largeur, 0)
			# volutes au point d'impact : montent et s'élargissent
			var n := normale if (touche_decor or cible == null) else (debut - _fin_l).normalized()
			_bouffee(_fin_l + n * 0.12, n * randf_range(0.25, 0.55) + Vector3.UP * randf_range(0.35, 0.7) + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), randf_range(1.0, 1.5), randf_range(0.3, 0.5) * largeur, 0)
		# étincelles fines qui s'arrachent du rayon (en plus de la fumée)
		_t_arrache += dt
		while _t_arrache > 0.045 and l > 1.0:
			_t_arrache -= 0.045
			var pa := debut.lerp(_fin_l, randf_range(0.02, 0.8))
			var dl := (_fin_l - debut).normalized()
			var lat3 := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_bouffee(pa + lat3 * 0.1, lat3 * randf_range(0.5, 1.4) + dl * randf_range(1.0, 3.0), randf_range(0.3, 0.6), randf_range(0.012, 0.024), 1)
		# braises violettes au point d'impact (rares)
		_t_braise += dt
		while _t_braise > 0.07:
			_t_braise -= 0.07
			var nb := normale if touche_decor else (debut - _fin_l).normalized()
			var lat2 := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_bouffee(_fin_l + nb * 0.05, nb * randf_range(1.0, 2.2) + lat2 * randf_range(0.6, 1.4), randf_range(0.45, 0.8), randf_range(0.014, 0.03), 1)
	var lot_f: Array = []
	var lot_b: Array = []
	var restants: Array = []
	for b in _bouf:
		b.t = float(b.t) + dt
		var p := float(b.t) / float(b.vie)
		if p >= 1.0:
			continue
		restants.append(b)
		if int(b.sorte) == 0:
			b.v = (b.v as Vector3) * exp(-dt * 0.9)
			b.p = (b.p as Vector3) + (b.v as Vector3) * dt
			var s := float(b.s) * lerpf(0.6, 1.6, p)
			var al := smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.45, 1.0, p)) * 0.72
			lot_f.append([b.p, cb.scaled(Vector3(s, s, 1.0)), Color(1, 1, 1, al), Color(float(b.h), 0.3 + 0.6 * p, 0.0, 0.0)])
		else:
			b.v = (b.v as Vector3) + Vector3(0, -3.5, 0) * dt
			b.p = (b.p as Vector3) + (b.v as Vector3) * dt
			var s2 := float(b.s) * (1.0 - 0.5 * p)
			var al2 := smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.5, 1.0, p))
			lot_b.append([b.p, cb.scaled(Vector3(s2, s2, 1.0)), Color(1, 1, 1, al2), Color(float(b.h), float(lot_b.size() % 2), 3.0, 0.0)])
	_bouf = restants
	_fumee.ecrire(lot_f, cb)
	_braises.ecrire(lot_b, cb, false)

func _bouffee(p: Vector3, v: Vector3, vie: float, s: float, sorte: int) -> void:
	var n := 0
	for b in _bouf:
		if int(b.sorte) == sorte:
			n += 1
	if n >= (NB_FUMEE if sorte == 0 else NB_BRAISES):
		return
	_bouf.append({"p": p, "v": v, "t": 0.0, "vie": vie, "s": s, "h": randf(), "sorte": sorte})

## Lumière violette faible : une au bout (sur le mur / la cible), une au milieu du rayon (le long des murs de la crypte).
func _maj_lumieres(g: GestionMagie, vie: float) -> void:
	if g == null:
		return
	var k := (1.0 - smoothstep(0.6, 1.0, vie)) * smoothstep(0.0, 0.1, vie)
	if k <= 0.01:
		return
	var id := get_instance_id()
	var pulse := 0.9 + 0.1 * sin(_t * 2.6 * TAU / 2.6)
	var n := normale if touche_decor else (debut - _fin_l).normalized()
	var e_bout := 1.7 if cible == null else 0.8   # sur un corps, OmbreCorps l'éclaire déjà
	g.lumiere("rayon_noir_b%d" % id, _fin_l + n * 0.5, Color(pal()["lumiere"]), e_bout * k * pulse * clampf(puissance, 1.0, 1.5), 4.5, 0.6)
	var l := debut.distance_to(_fin_l)
	if l > 2.5:
		g.lumiere("rayon_noir_m%d" % id, debut.lerp(_fin_l, 0.55) + Vector3.UP * 0.15, Color(pal()["lumiere"]), 0.75 * k * clampf(puissance, 1.0, 1.4), minf(5.5, l * 0.6), 0.45)

## L'ombre qui RAMPE sur la cible (OmbreCorps : éclaboussure sombre qui s'étale, corruption qui monte) : renouvelée toutes les 1,1 s.
func _maj_corps(g: GestionMagie) -> void:
	if cible == null or not is_instance_valid(cible) or g == null or _t < ALLUMAGE * 0.8:
		return
	var h := g.horloge
	var id := cible.get_instance_id()
	if h - float(_corps_vu.get(id, -INF)) < 1.1:
		return
	_corps_vu[id] = h
	ImpactCorps.embraser(cible, "tenebres", _fin_l, (_fin_l - debut).normalized(), 0.4 * clampf(puissance, 1.0, 1.5), 2.0)
