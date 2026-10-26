class_name EauVillage
extends Node3D
## Lot C7c (plan docs/PLAN_VILLAGE_V2.md §4) : la rivière du village et le lac fermé de la combe sud-ouest, avec le système
## `Eau` validé (docs/EAU.md). Règle de l'utilisateur : la rivière NAÎT dans la carte (cascade d'un rocher au pied du versant
## est), finit dans le LAC FERMÉ, ne touche jamais un bord ; on la traverse par le pont ou le gué ; aucun trou sous l'eau.
##
## - Source : rocher-falaise (Blender) d'où sort une cascade de 2,7 m → bassin (86,5 ; 58) ;
## - ruisseau (surface en pente, `niveau_cb`) du bassin à la grille E (65 ; 61,5), gué de pierres plates en (78 ; 59) ;
## - rivière (3,05 → 2,6) sur le plateau : pont de pierre en arche (44 ; 57 → 66), quai sur pieux (x 29–38, rive nord),
##   roue à aubes (23,5 ; 60,1) contre le mur sud de la maison du moulin (C7b), seuil de pierre et petite cascade de 3,4 m
##   (lèvre x = 19,75) qui tombe dans le lac ;
## - lac (-0,8 m) : composante connexe du relief sous -0,8 autour de (-20 ; 44), gelé au large (glace MARCHABLE : on ne nage
##   jamais), eau libre à plaques devant l'arrivée de la rivière (fond marchable invisible à 0,55 m sous la surface).
## Le lit est creusé par ReliefVillage (C7a) ; ici on ne touche pas au relief. Tout fond d'eau = maillage EXACT du terrain.
## `--sans-eau-village` : rien n'est posé (mesures A/B).

const MODELE := "res://assets/modeles/eau/eau_village.glb"

const SOURCE_LEVRE := Vector3(89.3, 15.2, 57.7)
const BASSIN := Vector2(86.5, 58.0)
const X_GRILLE_E := 65.0
const LEVRE_MOULIN := Vector3(19.75, 2.6, 61.0)   # bord aval du seuil (l'eau tombe vers -x)
const SEUIL_LONG := 2.7                           # le seuil va de x 19,75 à 22,45
const SEUIL_DESSUS := 0.45                        # sous la surface
const ROUE := Vector3(23.5, 3.65, 60.1)           # centre ; axe nord-sud ; l'arbre entre dans le mur sud de la maison M (z 58,5)
const ROUE_VITESSE := 0.55                        # rad/s (le bas de la roue suit le courant, vers -x)
const PONT := Vector3(44.0, 0.0, 61.5)            # y = h_village (plateau) ; axe nord-sud, 9 m
const QUAI := Vector3(29.0, 3.35, 57.2)           # coin côté berge, dessus des planches
const GUE := Vector2(78.0, 59.3)
const LAC_NIVEAU := -0.8
const LAC_CENTRE := Vector2(-20.0, 44.0)
const LAC_RECT := Rect2(-70.0, 2.0, 91.0, 87.0)
const LAC_ARRIVEE := Vector2(15.0, 61.0)          # eau libre devant la cascade du moulin
const LAC_LIBRE := 9.0                            # m : rayon de l'eau libre
const GLACE_PROF := 0.75                          # m : au-delà, le lac est pris (glace marchable)
const FOND_MARCHE := 0.55                         # m : eau libre profonde → fond invisible à 0,55 m sous la surface

var monde: Node
var ruisseau: Eau
var riviere: Eau
var lac: Eau
var cascade_source: Cascade
var cascade_moulin: Cascade
var roue: Node3D
var corps: StaticBody3D
var _hgrille := PackedFloat32Array()
var _n := 0
var _pas := 2.0
var _demi := 120.0
var _lac_masque := PackedByteArray()
var _lac_hm := PackedFloat32Array()   # hauteur du maillage au centre de chaque case de la carte du lac
var _lac_res := 2.0
var _lac_w := 0
var _lac_h := 0
var _mats := {}

## Vrai si (x, z), de sol à `h` m, est sous le lac (ou sur sa rive immédiate) : forêt, rochers et touffes ne s'y posent pas.
## Le pied de la cascade du moulin (6 m autour de LAC_ARRIVEE) reste dégagé lui aussi (un sapin y masquait la chute).
static func sous_le_lac(x: float, z: float, h: float) -> bool:
	if Vector2(x, z).distance_to(LAC_ARRIVEE) < 6.0:
		return true
	return LAC_RECT.has_point(Vector2(x, z)) and h < LAC_NIVEAU + 0.35

static func creer(monde_: Node) -> EauVillage:
	var args: Dictionary = monde_.call("_arguments")
	if args.has("sans-ancien-village") and monde_.get("village") != null:
		monde_.village.visible = false   # captures/sondes C7c seulement : l'ancienne palissade (avant C7b) coupe la rivière et le pont
		for c in monde_.village.find_children("*", "CollisionObject3D", true, false):
			(c as CollisionObject3D).collision_layer = 0   # … et la traversée du pont (sonde_c7c_sorties)
	if args.has("sans-eau-village"):
		return null
	var e := EauVillage.new()
	e.name = "EauVillage"
	e.monde = monde_
	monde_.add_child(e)
	e._construire()
	return e

func _construire() -> void:
	var t0 := Time.get_ticks_usec()
	_n = int(monde.CASES) + 1
	_pas = float(monde.TAILLE) / float(monde.CASES)
	_demi = float(monde.TAILLE) * 0.5
	_hgrille.resize(_n * _n)
	_hgrille.fill(NAN)
	corps = StaticBody3D.new()
	corps.name = "Collisions"
	add_child(corps)
	var modele: Node = (load(MODELE) as PackedScene).instantiate()
	var etapes := [["grille", _grille_riviere], ["source", _source.bind(modele)], ["ruisseau", _ruisseau], ["riviere", _riviere], ["moulin", _moulin.bind(modele)],
		["pont", _pont.bind(modele)], ["quai", _quai.bind(modele)], ["gue", _gue.bind(modele)], ["lac", _lac]]
	var detail := ""
	for e: Array in etapes:
		var t := Time.get_ticks_usec()
		(e[1] as Callable).call()
		detail += " %s %d" % [e[0], (Time.get_ticks_usec() - t) / 1000]
	modele.free()
	print("EauVillage étapes (ms) :", detail)
	print("EauVillage : %d ms (ruisseau %.0f m², rivière %.0f m², lac %.0f m²)" % [(Time.get_ticks_usec() - t0) / 1000, ruisseau.surface_m2(), riviere.surface_m2(), lac.surface_m2()])

func _process(dt: float) -> void:
	if roue != null:
		roue.rotation.z = wrapf(roue.rotation.z + ROUE_VITESSE * dt, -PI, PI)

# ------------------------------------------------------------------ relief exact (sommets du maillage, mis en cache)

func _hs(i: int, j: int) -> float:
	var k := j * _n + i
	var h := _hgrille[k]
	if is_nan(h):
		h = monde.hauteur(i * _pas - _demi, j * _pas - _demi)
		_hgrille[k] = h
	return h

## Hauteur du maillage du terrain (mêmes triangles que monde._terrain, comme DetailsSol.hauteur_maillage), avec cache.
func hm(x: float, z: float) -> float:
	var u := (x + _demi) / _pas
	var v := (z + _demi) / _pas
	var i := clampi(floori(u), 0, _n - 2)
	var j := clampi(floori(v), 0, _n - 2)
	var fu := u - i
	var fv := v - j
	if fu + fv <= 1.0:
		var ha := _hs(i, j)
		return ha + (_hs(i + 1, j) - ha) * fu + (_hs(i, j + 1) - ha) * fv
	var hd := _hs(i + 1, j + 1)
	return hd + (_hs(i, j + 1) - hd) * (1.0 - fu) + (_hs(i + 1, j) - hd) * (1.0 - fv)

# ------------------------------------------------------------------ matières

func _mat(nom: String) -> Material:
	if not _mats.has(nom):
		var m: Material
		match nom:
			"maconnerie": m = TexturesBati.materiau_e("pierre_maison_e", Color(1.5, 1.38, 1.24))   # pont : pierre chaude des maisons (E/pierre_chaude)
			"taille": m = TexturesBati.m_pierre_fine_e(Color(1.32, 1.29, 1.27))
			"dalles": m = TexturesBati.m_pierre_fine_e(Color(1.1, 1.08, 1.08))
			"roche": m = TexturesBati.m_roche()
			"roche_mouillee": m = TexturesBati.m_roche(Color(0.72, 0.76, 0.86))
			"planches": m = TexturesBati.m_planches_e(Color(0.98, 0.94, 0.9))
			"bois_mouille": m = TexturesBati.m_planches_e(Color(0.92, 0.86, 0.82))
			"poteaux": m = TexturesBati.m_bois_debout_e(Color(0.95, 0.9, 0.86))
			"rondins": m = TexturesBati.m_rondins_e(Color(1.25, 1.18, 1.1))
		_mats[nom] = m
	return _mats[nom]

## Copie la pièce `nom` du modèle Blender sous `parent`, avec sa matière.
func _piece(modele: Node, nom: String, parent: Node3D, mat: String, xf := Transform3D.IDENTITY, ombre := true) -> MeshInstance3D:
	var src := modele.find_child(nom, true, false) as MeshInstance3D
	if src == null:
		push_error("EauVillage : pièce « %s » absente de %s" % [nom, MODELE])
		return null
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = src.mesh
	mi.transform = xf
	mi.material_override = _mat(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 85.0
	parent.add_child(mi)
	return mi

func _collision_maillage(modele: Node, nom: String, xf: Transform3D) -> void:
	var src := modele.find_child(nom, true, false) as MeshInstance3D
	if src == null and nom.ends_with("_Col"):
		# l'importeur glTF lit le suffixe « _col » (nodes/use_name_suffixes) : « Pont_Col » arrive renommé « Pont »
		src = modele.find_child(nom.trim_suffix("_Col"), true, false) as MeshInstance3D
	if src == null:
		push_error("EauVillage : collision « %s » absente de %s" % [nom, MODELE])
		return
	var forme := src.mesh.create_trimesh_shape()
	forme.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "Col_" + nom
	cs.shape = forme
	cs.transform = xf
	corps.add_child(cs)

func _boite(centre: Vector3, taille: Vector3, xf_rot := Basis.IDENTITY) -> void:
	var b := BoxShape3D.new()
	b.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = b
	cs.transform = Transform3D(xf_rot, centre)
	corps.add_child(cs)

func _lacet_vers(d: Vector2) -> float:
	return atan2(-d.y, d.x)   # +x local → direction d (x, z)

func _relier_cycle(n: Node) -> void:
	var c: Node = monde.get("cycle")
	if c != null:
		n.set("cycle", c)

# ------------------------------------------------------------------ rivière : niveau, fond, courant, glace

## Grille de la rivière (4 cases/m, x 19,75..90, z 53,5..67) : point de l'axe le plus proche, rastérisé segment par segment
## (même résultat que ReliefVillage.riviere jusqu'à 4 m de l'axe, ~50 fois moins cher), fond exact du maillage.
const RG_X0 := 19.75
const RG_Z0 := 53.5
const RG_RES := 4.0
var _rg_w := 0
var _rg_h := 0
var _rg_d := PackedFloat32Array()
var _rg_hw := PackedFloat32Array()
var _rg_eau := PackedFloat32Array()
var _rg_dir := PackedVector2Array()
var _rg_fond := PackedFloat32Array()

func _grille_riviere() -> void:
	_rg_w = ceili((90.0 - RG_X0) * RG_RES)
	_rg_h = ceili((67.0 - RG_Z0) * RG_RES)
	var n := _rg_w * _rg_h
	_rg_d.resize(n)
	_rg_d.fill(INF)
	_rg_hw.resize(n)
	_rg_eau.resize(n)
	_rg_dir.resize(n)
	_rg_fond.resize(n)
	_rg_fond.fill(1000.0)
	var R := ReliefVillage.RIVIERE
	var marge := 4.0
	for s in R.size() - 1:
		var a := Vector2(R[s][0], R[s][1])
		var b := Vector2(R[s + 1][0], R[s + 1][1])
		var ab := b - a
		var l2 := ab.length_squared()
		var dirv := ab.normalized()
		var i0 := maxi(0, floori((minf(a.x, b.x) - marge - RG_X0) * RG_RES))
		var i1 := mini(_rg_w - 1, ceili((maxf(a.x, b.x) + marge - RG_X0) * RG_RES))
		var j0 := maxi(0, floori((minf(a.y, b.y) - marge - RG_Z0) * RG_RES))
		var j1 := mini(_rg_h - 1, ceili((maxf(a.y, b.y) + marge - RG_Z0) * RG_RES))
		for j in range(j0, j1 + 1):
			var z := RG_Z0 + (j + 0.5) / RG_RES
			for i in range(i0, i1 + 1):
				var x := RG_X0 + (i + 0.5) / RG_RES
				var p := Vector2(x, z)
				var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				var k := j * _rg_w + i
				if d < _rg_d[k]:
					_rg_d[k] = d
					_rg_hw[k] = lerpf(R[s][2], R[s + 1][2], t)
					_rg_eau[k] = lerpf(R[s][3], R[s + 1][3], t)
					_rg_dir[k] = dirv
	for j in _rg_h:
		var z := RG_Z0 + (j + 0.5) / RG_RES
		for i in _rg_w:
			var k := j * _rg_w + i
			if _rg_d[k] > _rg_hw[k] + 1.2:
				continue
			var x := RG_X0 + (i + 0.5) / RG_RES
			var h := hm(x, z)
			if x >= LEVRE_MOULIN.x and x <= LEVRE_MOULIN.x + SEUIL_LONG and absf(z - LEVRE_MOULIN.z) < 2.5:
				h = maxf(h, LEVRE_MOULIN.y - SEUIL_DESSUS)
			_rg_fond[k] = h

func _rg(x: float, z: float) -> int:
	var i := floori((x - RG_X0) * RG_RES)
	var j := floori((z - RG_Z0) * RG_RES)
	if i < 0 or j < 0 or i >= _rg_w or j >= _rg_h:
		return -1
	return j * _rg_w + i

## Niveau de l'eau (surface en pente) : celui de ReliefVillage, plat (2,6) au-dessus du seuil du moulin.
func niveau_riviere(x: float, z: float) -> float:
	if x <= 22.0 and x >= LEVRE_MOULIN.x - 0.5:
		return LEVRE_MOULIN.y
	var k := _rg(x, z)
	if k < 0 or _rg_d[k] == INF:
		return LEVRE_MOULIN.y
	return _rg_eau[k]

## Fond de la rivière : maillage exact dans le lit (+1,2 m de berge), dessus du seuil ; ailleurs « très haut » (pas d'eau).
func fond_riviere(x: float, z: float) -> float:
	var k := _rg(x, z)
	return 1000.0 if k < 0 else _rg_fond[k]

func courant_riviere(x: float, z: float) -> Vector2:
	var k := _rg(x, z)
	if k < 0 or _rg_d[k] == INF:
		return Vector2.ZERO
	var hw := _rg_hw[k]
	var centre := 1.0 - pow(clampf(_rg_d[k] / maxf(hw, 0.1), 0.0, 1.0), 2.0)
	var v := 0.3 + 0.5 * centre
	if x > X_GRILLE_E:
		v *= 1.0 + 0.8 * smoothstep(84.0, 80.0, x)   # la descente est vive, le bassin calme
		v *= 1.0 - 0.6 * (1.0 - smoothstep(1.0, 3.0, Vector2(x, z).distance_to(BASSIN)))
	return _rg_dir[k] * v

func glace_ruisseau(x: float, _z: float) -> Vector2:
	return Vector2(Eau.Variante.BORDS_GELES, 0.18 + 0.14 * smoothstep(80.0, 70.0, x))

func glace_riviere(x: float, z: float) -> Vector2:
	# plaques flottantes le long du quai, bords gelés ailleurs ; eau libre près de la roue et du seuil (le courant brasse)
	if x > 27.0 and x < 40.0:
		return Vector2(Eau.Variante.PLAQUES, 0.45 * smoothstep(27.0, 30.0, x) * smoothstep(40.0, 37.0, x) + 0.05)
	var pres_roue := 1.0 - smoothstep(1.5, 4.0, Vector2(x, z).distance_to(Vector2(ROUE.x, ROUE.z)))
	return Vector2(Eau.Variante.BORDS_GELES, 0.24 * (1.0 - pres_roue) + 0.06)

# ------------------------------------------------------------------ source

func _source(modele: Node) -> void:
	var d := BASSIN - Vector2(SOURCE_LEVRE.x, SOURCE_LEVRE.z)
	var xf := Transform3D(Basis(Vector3.UP, _lacet_vers(d)), SOURCE_LEVRE)
	_piece(modele, "Rocher_Source", self, "roche", xf)
	_collision_maillage(modele, "Rocher_Source", xf)
	cascade_source = Cascade.creer(SOURCE_LEVRE.y - 12.5, 1.6)
	cascade_source.name = "CascadeSource"
	cascade_source.transform = xf
	_relier_cycle(cascade_source)
	add_child(cascade_source)

func _ruisseau() -> void:
	var zone := Rect2(X_GRILLE_E, 53.5, SOURCE_LEVRE.x + 0.3 - X_GRILLE_E, 12.5)
	var turbs: Array = [cascade_source.zone_turbulence(2.0)]
	var x := 83.0
	while x > 67.0:   # rapides de la descente
		turbs.append([Vector2(x, z_axe(x)), 1.4, 0.35])
		x -= 3.2
	ruisseau = Eau.creer(&"ruisseau", zone, 3.05, fond_riviere, {"niveau_cb": niveau_riviere, "pas_maille": 1.0,
		"params": {"c_peu": Color("#4a8598"), "absorption": 2.4},
		"courant": courant_riviere, "turbulences": turbs, "variantes": glace_ruisseau})
	ruisseau.name = "EauRuisseau"
	_relier_cycle(ruisseau)
	add_child(ruisseau)

## z de l'axe de la rivière à l'abscisse x (polyligne RIVIERE).
func z_axe(x: float) -> float:
	var R := ReliefVillage.RIVIERE
	for i in R.size() - 1:
		var xa: float = R[i][0]
		var xb: float = R[i + 1][0]
		if (x <= xa and x >= xb) or (x >= xa and x <= xb):
			var t := (x - xa) / (xb - xa) if xb != xa else 0.0
			return lerpf(float(R[i][1]), float(R[i + 1][1]), t)
	return 61.0

# ------------------------------------------------------------------ rivière du plateau

func _riviere() -> void:
	var zone := Rect2(LEVRE_MOULIN.x, 55.5, X_GRILLE_E - LEVRE_MOULIN.x, 11.5)
	var turbs: Array = [[Vector2(ROUE.x - 0.3, ROUE.z), 1.3, 0.8], [Vector2(LEVRE_MOULIN.x + 0.4, LEVRE_MOULIN.z), 1.2, 0.45],
		[Vector2(X_GRILLE_E - 0.6, 61.5), 1.6, 0.35]]
	riviere = Eau.creer(&"riviere", zone, 2.8, fond_riviere, {"niveau_cb": niveau_riviere, "pas_maille": 1.0,
		"params": {"c_peu": Color("#3c7488"), "c_moyen": Color("#22507a"), "absorption": 2.3},
		"courant": courant_riviere, "turbulences": turbs, "variantes": glace_riviere})
	riviere.name = "EauRiviere"
	_relier_cycle(riviere)
	add_child(riviere)

# ------------------------------------------------------------------ moulin : seuil, petite cascade, roue

func _moulin(modele: Node) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI), LEVRE_MOULIN)   # +x local → -x monde (aval)
	_piece(modele, "Seuil_Taille", self, "taille", xf)
	_piece(modele, "Seuil_Roches", self, "roche_mouillee", xf, false)
	_collision_maillage(modele, "Seuil_Taille", xf)
	cascade_moulin = Cascade.creer(LEVRE_MOULIN.y - LAC_NIVEAU, 4.0)
	cascade_moulin.name = "CascadeMoulin"
	cascade_moulin.transform = xf
	_relier_cycle(cascade_moulin)
	add_child(cascade_moulin)
	cascade_moulin.falaise.visible = false   # le seuil de pierre de taille remplace la falaise de blocs
	# roue (tourne autour de z) + arbre ; palier et console fixes
	roue = Node3D.new()
	roue.name = "Roue"
	roue.position = ROUE
	add_child(roue)
	_piece(modele, "Roue", roue, "bois_mouille")
	_piece(modele, "Roue_Axe", roue, "rondins")
	var fixe := Transform3D(Basis.IDENTITY, ROUE)
	_piece(modele, "Roue_Support", self, "poteaux", fixe)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.52
	cyl.height = 0.82
	var cs := CollisionShape3D.new()
	cs.name = "Col_Roue"
	cs.shape = cyl
	cs.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ROUE)
	corps.add_child(cs)
	_boite(ROUE + Vector3(0.0, -1.05, 0.72), Vector3(1.3, 2.4, 0.3))   # chevalet du palier

# ------------------------------------------------------------------ pont de pierre en arche

func _pont(modele: Node) -> void:
	var p := Vector3(PONT.x, float(monde.h_village), PONT.z)
	var xf := Transform3D(Basis.IDENTITY, p)
	var n := Node3D.new()
	n.name = "Pont"
	n.transform = xf
	add_child(n)
	_piece(modele, "Pont_Maconnerie", n, "maconnerie")
	_piece(modele, "Pont_Taille", n, "taille")
	_piece(modele, "Pont_Tablier", n, "dalles")
	_collision_maillage(modele, "Pont_Col", xf)

# ------------------------------------------------------------------ quai sur pieux

func _quai(modele: Node) -> void:
	var xf := Transform3D(Basis.IDENTITY, QUAI)
	var n := Node3D.new()
	n.name = "Quai"
	n.transform = xf
	add_child(n)
	_piece(modele, "Quai_Planches", n, "planches")
	_piece(modele, "Quai_Pieux", n, "rondins")
	_boite(QUAI + Vector3(4.5, -0.06, 1.1), Vector3(9.0, 0.12, 2.25))

# ------------------------------------------------------------------ gué : pierres plates en travers du ruisseau

func _gue(modele: Node) -> void:
	var r := ReliefVillage.riviere(GUE.x, GUE.y)
	var dir: Vector2 = r["direction"]
	var perp := Vector2(-dir.y, dir.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gue_c7c")
	var n := Node3D.new()
	n.name = "Gue"
	add_child(n)
	for k in 6:
		var s := -2.3 + k * 0.92 + rng.randf_range(-0.12, 0.12)
		var p := GUE + perp * s + dir * rng.randf_range(-0.15, 0.15)
		var eau := niveau_riviere(p.x, p.y)
		var sol := hm(p.x, p.y)
		var haut := maxf(eau + 0.13, sol + 0.12)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)), Vector3(p.x, haut, p.y))
		_piece(modele, "Gue_%d" % (k % 3 + 1), n, "roche_mouillee", xf, false)
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.36
		cyl.height = maxf(haut - (sol - 0.3), 0.4)
		var cs := CollisionShape3D.new()
		cs.shape = cyl
		cs.position = Vector3(p.x, haut - cyl.height * 0.5, p.y)
		corps.add_child(cs)

# ------------------------------------------------------------------ lac fermé

## Composante connexe du relief sous le niveau du lac autour de LAC_CENTRE, dilatée de 2 cases (rive réelle).
func _masque_lac() -> void:
	_lac_w = ceili(LAC_RECT.size.x * _lac_res)
	_lac_h = ceili(LAC_RECT.size.y * _lac_res)
	var bas := PackedByteArray()
	bas.resize(_lac_w * _lac_h)
	_lac_hm.resize(_lac_w * _lac_h)
	for j in _lac_h:
		var z := LAC_RECT.position.y + (j + 0.5) / _lac_res
		for i in _lac_w:
			var x := LAC_RECT.position.x + (i + 0.5) / _lac_res
			var h := hm(x, z)
			_lac_hm[j * _lac_w + i] = h
			bas[j * _lac_w + i] = 1 if h < LAC_NIVEAU else 0
	_lac_masque.resize(_lac_w * _lac_h)
	_lac_masque.fill(0)
	var i0 := int((LAC_CENTRE.x - LAC_RECT.position.x) * _lac_res)
	var j0 := int((LAC_CENTRE.y - LAC_RECT.position.y) * _lac_res)
	var pile := PackedInt32Array([j0 * _lac_w + i0])
	_lac_masque[j0 * _lac_w + i0] = 1
	while not pile.is_empty():
		var k: int = pile[pile.size() - 1]
		pile.resize(pile.size() - 1)
		var ci := k % _lac_w
		var cj := k / _lac_w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni := ci + d.x
			var nj := cj + d.y
			if ni < 0 or nj < 0 or ni >= _lac_w or nj >= _lac_h:
				push_error("EauVillage : le lac touche le cadre LAC_RECT (%d, %d)" % [ni, nj])
				continue
			var kk := nj * _lac_w + ni
			if bas[kk] == 1 and _lac_masque[kk] == 0:
				_lac_masque[kk] = 1
				pile.append(kk)
	for passe in 2:
		var suiv := _lac_masque.duplicate()
		for j in range(1, _lac_h - 1):
			for i in range(1, _lac_w - 1):
				var k := j * _lac_w + i
				if _lac_masque[k] == 0 and (_lac_masque[k - 1] | _lac_masque[k + 1] | _lac_masque[k - _lac_w] | _lac_masque[k + _lac_w]) != 0:
					suiv[k] = 1
		_lac_masque = suiv

func _lk(x: float, z: float) -> int:
	var i := floori((x - LAC_RECT.position.x) * _lac_res)
	var j := floori((z - LAC_RECT.position.y) * _lac_res)
	if i < 0 or j < 0 or i >= _lac_w or j >= _lac_h:
		return -1
	return j * _lac_w + i

func dans_lac(x: float, z: float) -> bool:
	var k := _lk(x, z)
	return k >= 0 and _lac_masque[k] == 1

func fond_lac(x: float, z: float) -> float:
	var k := _lk(x, z)
	return _lac_hm[k] if k >= 0 and _lac_masque[k] == 1 else 1000.0

## Eau libre devant l'arrivée de la rivière : disque au bord irrégulier (même limite pour l'image et la collision).
func eau_libre(x: float, z: float) -> bool:
	var d := Vector2(x, z) - LAC_ARRIVEE
	var a := d.angle()
	return d.length() < LAC_LIBRE + 1.1 * sin(3.0 * a + 0.4) + 0.6 * sin(7.0 * a + 1.3)

## Glace du lac : prise au large (marchable), eau libre à plaques devant l'arrivée de la rivière, rive gelée ailleurs.
func glace_lac(x: float, z: float) -> Vector2:
	var k := _lk(x, z)
	var prof := LAC_NIVEAU - (_lac_hm[k] if k >= 0 else 0.0)
	if eau_libre(x, z):
		return Vector2(Eau.Variante.PLAQUES, 0.3 + 0.3 * smoothstep(LAC_LIBRE - 4.0, LAC_LIBRE, Vector2(x, z).distance_to(LAC_ARRIVEE)))
	if prof > GLACE_PROF:
		return Vector2(Eau.Variante.GLACE, 1.0)
	return Vector2(Eau.Variante.BORDS_GELES, 0.85)

## Hauteur du sol marchable du lac au sommet (x, z) : NAN hors du lac ; sous le relief (le terrain porte) sur la rive sèche
## et dans l'eau libre peu profonde ; rampe lissée jusqu'à la glace (ou jusqu'au fond invisible de l'eau libre).
func _sol_lac(x: float, z: float) -> float:
	var k := _lk(x, z)
	if k < 0 or _lac_masque[k] == 0:
		return NAN
	var h := hm(x, z)
	var prof := LAC_NIVEAU - h
	var libre := eau_libre(x, z)
	var cible := LAC_NIVEAU - FOND_MARCHE if libre else LAC_NIVEAU
	var pleine := FOND_MARCHE if libre else GLACE_PROF
	if prof >= pleine:
		return cible
	if prof <= 0.0 or cible <= h:
		return h - 0.03
	return snappedf(h + (cible - h) * smoothstep(0.0, pleine, prof), 0.001)

func _lac() -> void:
	_masque_lac()
	lac = Eau.creer(&"lac", LAC_RECT, LAC_NIVEAU, fond_lac, {"resolution": _lac_res, "variantes": glace_lac,
		"params": {"glace_ton_plaques": 1.0},
		"brume_zone": Rect2(LAC_ARRIVEE.x - 14.0, LAC_ARRIVEE.y - 10.0, 16.0, 20.0)})
	lac.name = "EauLac"
	_relier_cycle(lac)
	add_child(lac)
	# sol marchable : glace (au niveau de l'eau) au large ; fond invisible (0,55 m sous l'eau) dans l'eau libre profonde.
	# Passe D : entre ces sols et la rive, une RAMPE continue rejoint le relief (avant : marche de 0,75 m au bord de la glace,
	# avec des pièges sans retour au pied des berges raides, ex. (17,4 ; 70,6) près du moulin). On s'enfonce au plus d'une
	# vingtaine de centimètres dans la rive gelée.
	var faces := PackedVector3Array()
	var pas := 1.0
	var nx := int(LAC_RECT.size.x / pas)
	var nz := int(LAC_RECT.size.y / pas)
	var ys := PackedFloat32Array()
	ys.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			ys[j * (nx + 1) + i] = _sol_lac(LAC_RECT.position.x + i * pas, LAC_RECT.position.y + j * pas)
	for j in nz:
		var z0 := LAC_RECT.position.y + j * pas
		var debut := -1
		var y_debut := 0.0
		for i in nx + 1:
			var plat := NAN    # cellule plate (glace ou fond) : fusionnée en bandes
			var a0 := NAN
			var b0 := NAN
			var c0 := NAN
			var d0 := NAN
			if i < nx:
				a0 = ys[j * (nx + 1) + i]
				b0 = ys[j * (nx + 1) + i + 1]
				c0 = ys[(j + 1) * (nx + 1) + i + 1]
				d0 = ys[(j + 1) * (nx + 1) + i]
				if a0 == b0 and b0 == c0 and c0 == d0:
					plat = a0
			if debut >= 0 and (is_nan(plat) or plat != y_debut):
				var xa := LAC_RECT.position.x + debut * pas
				var xb := LAC_RECT.position.x + i * pas
				faces.append_array([Vector3(xa, y_debut, z0), Vector3(xb, y_debut, z0), Vector3(xb, y_debut, z0 + pas),
					Vector3(xa, y_debut, z0), Vector3(xb, y_debut, z0 + pas), Vector3(xa, y_debut, z0 + pas)])
				debut = -1
			if not is_nan(plat):
				if debut < 0:
					debut = i
					y_debut = plat
			elif i < nx and not (is_nan(a0) or is_nan(b0) or is_nan(c0) or is_nan(d0)):
				var x0 := LAC_RECT.position.x + i * pas
				var pa := Vector3(x0, a0, z0)
				var pb := Vector3(x0 + pas, b0, z0)
				var pc := Vector3(x0 + pas, c0, z0 + pas)
				var pd := Vector3(x0, d0, z0 + pas)
				faces.append_array([pa, pb, pc, pa, pc, pd])
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.name = "Col_GlaceLac"
	cs.shape = forme
	corps.add_child(cs)
