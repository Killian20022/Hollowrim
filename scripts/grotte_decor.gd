class_name GrotteDecor
extends CrypteDecor
## Décor de la grotte vitrine : coque de roche facettée (sommets colorés = occlusion peinte + masque de neige/glace/mousse),
## concrétions (stalagmites, stalactites, colonnes), rochers, cristaux, et mobilier du campement de bandits.
## Hérite de CrypteDecor (lot 7a) pour le bois, le fer, les os, les flammes sprites, les halos, les lumières vacillantes :
## rien n'est modifié dans la crypte. Les matières propres à la grotte (roche, strate, sol, neige, glace, mousse, cristal…)
## sont peintes dans des fils d'exécution par GrotteTextures et affichées par shaders/grotte.gdshader.

const CASE_C := 10.0
const PAINT_PARENT := ["bois", "fer", "lame", "os", "argile", "parchemin", "toile", "halo", "flamme"]
const DOSSIER := "res://assets/grotte"
const PROPRES_MIPS := ["roche", "roche_b", "roche_givre", "neige_sol", "strate", "sol", "neige", "glace", "glace_sup", "givre", "glacon", "cristal", "peau", "paille", "or", "piste"]
const PROPRES_PLATES := ["jour", "ciel", "rai", "flaque", "brume"]
const GROTTE_SHADER := preload("res://shaders/grotte.gdshader")
const AO_GAMMA := 1.0          # occlusion peinte accentuée : creux et pieds de paroi quasi noirs (références)

## Coques : [texture de base, texture superposée ("" = aucune), teinte, émission, part de texture en émission,
##           givre des faces hautes, sol mouillé, projection monde (1) ou UV (0)]
## Refonte matières : plus de mousse (les styles « mousse » / « strate » gardent leur nom mais deviennent roche brune givrée
## et sol mouillé), plus de bleu saturé ; la glace superposée n'est plus qu'un vernis gris-bleu.
const COQUES := {
	"c_roche_neige": ["roche_givre", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.8, 0.0, 1.0],
	"c_roche_mousse": ["roche", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.45, 0.0, 1.0],
	"c_roche_glace": ["roche_b", "glace_sup", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.7, 0.0, 1.0],
	"c_roche_nu": ["roche", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.4, 0.0, 1.0],
	"c_strate_mousse": ["strate", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.4, 0.0, 1.0],
	"c_strate_glace": ["strate", "glace_sup", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.75, 0.0, 1.0],
	"c_strate_suie": ["strate", "", Color(0.92, 0.84, 0.78), Vector3(0.0, 0.0, 0.0), 0.0, 0.0, 0.0, 1.0],
	"c_sol_neige": ["sol", "neige_sol", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.45, 0.0, 1.0],
	"c_sol_mousse": ["sol", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.25, 1.0, 1.0],
	"c_sol_glace": ["sol", "glace_sup", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.5, 0.6, 1.0],
	"c_sol_nu": ["sol", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.3, 0.8, 1.0],
	"c_sol_camp": ["sol", "", Color(1.0, 0.9, 0.8), Vector3(0.0, 0.0, 0.0), 0.0, 0.0, 0.35, 1.0],
	"c_glace": ["glace", "", Color(1, 1, 1), Vector3(0.004, 0.008, 0.014), 0.0, 0.15, 1.0, 1.0],
	"c_piste": ["piste", "", Color(1, 1, 1), Vector3(0.0, 0.0, 0.0), 0.0, 0.0, 0.0, 0.0],
	"c_cristal": ["cristal", "", Color(0.74, 0.8, 0.92), Vector3(0.0, 0.0, 0.0), 0.25, 0.0, 0.0, 0.0],
	"c_or": ["or", "", Color(1, 1, 1), Vector3(0.05, 0.035, 0.0), 0.12, 0.0, 0.0, 0.0],
	"c_glacon": ["glacon", "", Color(0.9, 0.95, 1.0), Vector3(0.012, 0.018, 0.026), 0.12, 0.0, 0.0, 0.0],
}

var _coq := {}
var coll: PackedVector3Array = PackedVector3Array()   # triangles de la coque (collision exacte)
var _gtaches := {}
var _gimg := {}
var _gtex := {}
var _blanc: ImageTexture
var nb_facettes := 0

func _init(parent: Node3D, solide: StaticBody3D) -> void:
	super(parent, solide)
	for nom in PROPRES_MIPS + PROPRES_PLATES:
		var cible: Array = [null]
		_gimg[nom] = cible
		var chemin := "%s/%s.res" % [DOSSIER, nom]
		if ResourceLoader.exists(chemin):        # textures précalculées (outils/generer_grotte.gd)
			cible[0] = load(chemin)
		else:                                     # repli : peintes à la volée dans un fil d'exécution
			_gtaches[nom] = WorkerThreadPool.add_task(_peindre_g.bind(nom, cible))

func _peindre(nom: String, cible: Array) -> void:
	if nom in PAINT_PARENT:      # les autres textures de la crypte ne servent pas ici : on ne les peint pas
		super._peindre(nom, cible)

func _peindre_g(nom: String, cible: Array) -> void:
	cible[0] = image_finale(nom)

## Image définitive d'une matière (avec mipmaps si besoin) : calculée ici, ou précalculée par outils/generer_grotte.gd.
static func image_finale(nom: String) -> Image:
	var img: Image = or_image() if nom == "or" else GrotteTextures.image(nom)
	return GrotteTextures.mips_image(img) if nom in PROPRES_MIPS else img

static func or_image() -> Image:
	return CrypteTextures.or_image()   # même or martelé que la crypte (64 texels/m)

func _tex_g(nom: String) -> ImageTexture:
	if not _gtex.has(nom):
		if _gtaches.has(nom):
			WorkerThreadPool.wait_for_task_completion(_gtaches[nom])
			_gtaches.erase(nom)
		_gtex[nom] = ImageTexture.create_from_image((_gimg[nom] as Array)[0])
	return _gtex[nom]

func attendre_tout() -> void:
	super.attendre_tout()
	for nom in _gtaches.keys():
		WorkerThreadPool.wait_for_task_completion(_gtaches[nom])
		_gtaches.erase(nom)

# ------------------------------------------------------------------ matériaux propres
func mat(nom: String) -> Material:
	if _mats.has(nom):
		return _mats[nom]
	var m: Material
	if COQUES.has(nom):
		var d: Array = COQUES[nom]
		var sm := ShaderMaterial.new()
		sm.shader = GROTTE_SHADER
		sm.set_shader_parameter("tex_base", _tex_g(d[0]))
		if d[1] != "":
			sm.set_shader_parameter("tex_sup", _tex_g(d[1]))
		else:
			if _blanc == null:
				var bi := Image.create(2, 2, false, Image.FORMAT_RGBA8)
				bi.fill(Color(1, 1, 1, 1))
				_blanc = ImageTexture.create_from_image(bi)
			sm.set_shader_parameter("tex_sup", _blanc)
		sm.set_shader_parameter("teinte", d[2])
		sm.set_shader_parameter("emission", d[3])
		sm.set_shader_parameter("emis_tex", d[4])
		sm.set_shader_parameter("givre", d[5])
		sm.set_shader_parameter("tex_givre", _tex_g("givre"))
		sm.set_shader_parameter("mouille", d[6])
		sm.set_shader_parameter("triplan", d[7])
		sm.set_shader_parameter("ao_gamma", AO_GAMMA if nom != "c_cristal" and nom != "c_glacon" else 1.0)
		sm.set_shader_parameter("decoupe", 1.0 if nom == "c_piste" else 0.0)
		if nom == "c_sol_neige":
			sm.set_shader_parameter("echelle_sup", 0.5)     # neige du sol extérieur : tuile de 8 m (16 texels/m), même grain que dehors
		m = sm
	elif nom == "jour" or nom == "ciel":
		var s := StandardMaterial3D.new()
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.albedo_texture = _tex_g(nom)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.disable_fog = true
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = s
	elif nom == "brume_g":
		var s := StandardMaterial3D.new()
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.albedo_texture = _tex_g("brume")
		s.albedo_color = Color(0.55, 0.6, 0.68)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
		s.disable_receive_shadows = true
		s.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m = s
	elif nom == "rai_g" or nom == "flaque_g":
		var s := StandardMaterial3D.new()
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		s.albedo_texture = _tex_g("rai" if nom == "rai_g" else "flaque")
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
		s.disable_receive_shadows = true
		m = s
	elif nom == "peau" or nom == "paille" or nom == "or":
		var sm := ShaderMaterial.new()
		sm.shader = CRYPTE_SHADER
		sm.set_shader_parameter("tex_base", _tex_g(nom))
		sm.set_shader_parameter("crasse", 0.0)
		if nom == "or":
			sm.set_shader_parameter("emission", Vector3(0.10, 0.07, 0.01))
		m = sm
	else:
		m = super.mat(nom)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("crasse", 0.0)     # pas de bande de crasse (calée sur le sol de la crypte)
	_mats[nom] = m
	return m

# ------------------------------------------------------------------ facettes colorées
var _coq_idx := {}     # nom -> { Vector2i(case) -> tampon } : évite de fabriquer une clé texte par facette

func _buf_c(c: Vector3, nom: String) -> Dictionary:
	var par_nom: Dictionary
	if _coq_idx.has(nom):
		par_nom = _coq_idx[nom]
	else:
		par_nom = {}
		_coq_idx[nom] = par_nom
	var ci := Vector2i(floori(c.x / CASE_C), floori(c.z / CASE_C))
	if par_nom.has(ci):
		return par_nom[ci]
	var buf := {"nom": nom, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}
	par_nom[ci] = buf
	_coq["%d,%d|%s" % [ci.x, ci.y, nom]] = buf
	return buf

static func hash2(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)

## Un triangle de coque. `ref` : point du côté visible ; si `ref_visible` est faux, c'est le côté caché (objets qui s'éloignent de leur axe).
## `cols` : couleur de chaque sommet (rgb = AO peinte, a = masque de la couche superposée). `tuile` : taille de la tuile en mètres.
func facette(nom: String, a: Vector3, b: Vector3, c: Vector3, ref: Vector3, cols: Array, ref_visible := true, tuile := 4.0, collision := false, uvs: Array = []) -> void:
	var geo := (b - a).cross(c - a)
	if geo.length_squared() < 1e-10:
		return
	var n := geo.normalized()
	var centre := (a + b + c) / 3.0
	var vers: float = (ref - centre).dot(n)
	if (vers < 0.0) == ref_visible:
		n = -n
	var buf := _buf_c(centre, nom)
	var v: PackedVector3Array = buf["v"]
	var nn: PackedVector3Array = buf["n"]
	var uu: PackedVector2Array = buf["u"]
	var cc: PackedColorArray = buf["c"]
	var inv := geo.dot(n) > 0.0                      # ordre d'enroulement (0, 2, 1) ou (0, 1, 2)
	var p1 := c if inv else b
	var p2 := b if inv else c
	var k1 := 2 if inv else 1
	var k2 := 1 if inv else 2
	v.append(a); v.append(p1); v.append(p2)
	nn.append(n); nn.append(n); nn.append(n)
	if uvs.is_empty():
		# base du plan calculée UNE fois pour la facette (et non à chaque sommet)
		var t: Vector3
		var paroi := absf(n.y) < 0.7
		if paroi:
			t = Vector3.UP.cross(n).normalized()
		else:
			t = (Vector3.RIGHT - n * n.x).normalized()
		var bb := n.cross(t)
		if paroi and bb.y > 0.0:
			bb = -bb
		var it := 1.0 / tuile
		uu.append(Vector2(a.dot(t), a.dot(bb)) * it)
		uu.append(Vector2(p1.dot(t), p1.dot(bb)) * it)
		uu.append(Vector2(p2.dot(t), p2.dot(bb)) * it)
	else:
		uu.append(uvs[0]); uu.append(uvs[k1]); uu.append(uvs[k2])
	cc.append(cols[0]); cc.append(cols[k1]); cc.append(cols[k2])
	if collision:
		coll.append(a); coll.append(b); coll.append(c)
	nb_facettes += 1

## UV dans le plan de la facette (mètres / tuile) : densité de texels uniforme quelle que soit la pente (la projection sur un
## axe du monde étirait la roche en « bandes » sur les toits et parois obliques). Parois : haut de la texture = haut du monde
## (strates horizontales) ; sol et toits doux : axe X du monde. Pas de décalage au hasard par facette : la texture est continue
## d'une facette à sa voisine (plus de « triangles » visibles).
static func _uv_plan(p: Vector3, n: Vector3, tuile: float) -> Vector2:
	var t: Vector3
	if absf(n.y) < 0.7:
		t = Vector3.UP.cross(n).normalized()
	else:
		t = (Vector3.RIGHT - n * n.x).normalized()
	var b := n.cross(t)
	if absf(n.y) < 0.7 and b.y > 0.0:
		b = -b                                       # « bas » de la texture vers le bas du monde
	return Vector2(p.dot(t), p.dot(b)) / tuile

static func col(ao: float, masque := 0.0) -> Color:
	return Color(ao, ao * 0.99, ao * 1.02, masque)

# ------------------------------------------------------------------ concrétions et rochers
## Solide de révolution irrégulier. profil : Vector2(rayon, y) de la base vers la pointe (y négatif = stalactite).
func revolution(nom: String, base: Vector3, profil: Array, cotes: int, graine: int, jit: float, masque: float, ao_base := 0.6, ao_tete := 1.0, tuile := 2.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var a0 := r.randf() * TAU
	var anneaux: Array = []
	var haut: float = (profil[profil.size() - 1] as Vector2).y
	for k in profil.size():
		var p: Vector2 = profil[k]
		var ring: Array = []
		for i in cotes:
			if p.x < 0.001:
				ring.append(base + Vector3(0, p.y, 0))
				continue
			var a := a0 + TAU * (float(i) + (r.randf() - 0.5) * 0.45) / cotes
			var rr := p.x * (1.0 + (r.randf() - 0.5) * jit)
			ring.append(base + Vector3(cos(a) * rr, p.y + (r.randf() - 0.5) * jit * 0.25 * absf(haut) / profil.size(), sin(a) * rr))
		anneaux.append(ring)
	var axe := base + Vector3(0, haut * 0.5, 0)
	for k in profil.size() - 1:
		var t0 := float(k) / (profil.size() - 1)
		var t1 := float(k + 1) / (profil.size() - 1)
		var c0 := col(lerpf(ao_base, ao_tete, t0), masque)
		var c1 := col(lerpf(ao_base, ao_tete, t1), masque)
		for i in cotes:
			var j := (i + 1) % cotes
			var a: Vector3 = anneaux[k][i]
			var b: Vector3 = anneaux[k][j]
			var c: Vector3 = anneaux[k + 1][j]
			var d: Vector3 = anneaux[k + 1][i]
			facette(nom, a, b, c, axe, [c0, c0, c1], false, tuile)
			facette(nom, a, c, d, axe, [c0, c1, c1], false, tuile)

## Stalagmite (vers le haut) ou stalactite (vers le bas) ; `sommet` = point d'attache pour une stalactite.
func pointe(nom: String, base: Vector3, r: float, h: float, graine: int, masque := 0.0, cotes := 6) -> void:
	var s := 1.0 if h > 0.0 else -1.0
	var hh := absf(h)
	var profil := [Vector2(r, 0.0), Vector2(r * 0.62, s * hh * 0.4), Vector2(r * 0.26, s * hh * 0.78), Vector2(0.0, s * hh)]
	if r > 0.3:
		profil = [Vector2(r, 0.0), Vector2(r * 0.8, s * hh * 0.18), Vector2(r * 0.52, s * hh * 0.5), Vector2(r * 0.24, s * hh * 0.82), Vector2(0.0, s * hh)]
	revolution(nom, base, profil, cotes if r > 0.3 else 5, graine, 0.38, masque, 0.55, 1.0)

## Colonne : stalagmite et stalactite soudées (y_bas -> y_haut), taille de la taille r_mid.
func colonne(nom: String, x: float, z: float, y_bas: float, y_haut: float, r: float, graine: int, masque := 0.0) -> void:
	var h := y_haut - y_bas
	var profil := [Vector2(r * 1.7, 0.0), Vector2(r * 1.15, h * 0.12), Vector2(r * 0.8, h * 0.36), Vector2(r * 0.62, h * 0.52), Vector2(r * 0.85, h * 0.72), Vector2(r * 1.25, h * 0.92), Vector2(r * 1.8, h + 0.3)]
	revolution(nom, Vector3(x, y_bas, z), profil, 7, graine, 0.3, masque, 0.55, 0.7)
	# colonne = solide : un cylindre approché pour la collision
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 0.95
	cyl.height = h
	cs.shape = cyl
	cs.position = Vector3(x, y_bas + h * 0.5, z)
	corps.add_child(cs)

## Rocher bas, à facettes (éboulis, blocs sur la glace, congères sous la neige quand masque est grand).
func rocher(nom: String, base: Vector3, r: float, h: float, graine: int, masque := 0.0, collision := true, cotes := 6) -> void:
	var profil := [Vector2(r, -h * 0.12), Vector2(r * 1.02, h * 0.38), Vector2(r * 0.72, h * 0.82), Vector2(r * 0.3, h), Vector2(0.0, h * 1.02)]
	revolution(nom, base, profil, cotes, graine, 0.5, masque, 0.62, 1.0, 3.0)
	if collision and r > 0.45:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r * 0.8
		cyl.height = h * 0.9
		cs.shape = cyl
		cs.position = base + Vector3(0, h * 0.45, 0)
		corps.add_child(cs)

## Congère : monticule bas de neige soufflée (crête de vent), sans collision (haut ≤ 0,5 m : on le traverse comme une neige molle).
func congere(base: Vector3, r: float, h: float, graine: int) -> void:
	var profil := [Vector2(r, -0.06), Vector2(r * 0.93, h * 0.42), Vector2(r * 0.66, h * 0.82), Vector2(r * 0.3, h), Vector2(0.0, h * 1.02)]
	revolution("c_sol_neige", base, profil, 9, graine, 0.34, 1.6, 0.8, 1.0, 4.0)

## Caillou : pyramide irrégulière à 4 faces (micro-détail du sol, 4 triangles).
func caillou(nom: String, base: Vector3, r: float, h: float, graine: int, masque := 0.0) -> void:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var a0 := rg.randf() * TAU
	var pts: Array = []
	for i in 4:
		var a := a0 + TAU * (float(i) + rg.randf() * 0.3) / 4.0
		var rr := r * rg.randf_range(0.7, 1.15)
		pts.append(base + Vector3(cos(a) * rr, -h * 0.1, sin(a) * rr))
	var sommet := base + Vector3(rg.randf_range(-0.2, 0.2) * r, h, rg.randf_range(-0.2, 0.2) * r)
	var axe := base + Vector3(0, h * 0.4, 0)
	var c0 := col(0.7, masque)
	var c1 := col(1.0, masque)
	for i in 4:
		facette(nom, pts[i], pts[(i + 1) % 4], sommet, axe, [c0, c0, c1], false, 2.0)

## Cristal : prisme hexagonal terminé par une pointe, incliné d'au plus `incl` radians.
func cristal(base: Vector3, r: float, l: float, graine: int, incl := 0.5, axe_bias := Vector3.UP) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var d := (axe_bias + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * incl).normalized()
	var u := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
	var w := d.cross(u)
	var a0 := rng.randf() * TAU
	var ring0: Array = []
	var ring1: Array = []
	var ring2: Array = []
	for i in 6:
		var a := a0 + TAU * i / 6.0
		var rad := u * cos(a) + w * sin(a)
		ring0.append(base + rad * r * (0.92 + rng.randf() * 0.16))
		ring1.append(base + d * l * 0.68 + rad * r * (0.9 + rng.randf() * 0.2))
		ring2.append(base + d * l * 0.9 + rad * r * 0.5)
	var pointe_p := base + d * l
	var axe := base + d * l * 0.5
	var teinte := [Color(0.62, 0.78, 1.0), Color(0.7, 1.0, 1.0), Color(0.9, 0.78, 1.0), Color(0.78, 0.9, 1.0), Color(0.55, 0.7, 0.98)]
	for i in 6:
		var j := (i + 1) % 6
		var c0: Color = teinte[(i + graine) % 5]
		c0.a = 0.0
		var c1 := Color(1, 1, 1, 0.0)
		facette("c_cristal", ring0[i], ring0[j], ring1[j], axe, [c0, c0, c1], false, 2.0)
		facette("c_cristal", ring0[i], ring1[j], ring1[i], axe, [c0, c1, c1], false, 2.0)
		facette("c_cristal", ring1[i], ring1[j], ring2[j], axe, [c1, c1, c1], false, 2.0)
		facette("c_cristal", ring1[i], ring2[j], ring2[i], axe, [c1, c1, c1], false, 2.0)
		facette("c_cristal", ring2[i], ring2[j], pointe_p, axe, [c1, c1, Color(1.2, 1.2, 1.2, 0.0)], false, 2.0)

# ------------------------------------------------------------------ outils de mobilier
## Prisme entre deux points (bûche, hampe, perche) ; UV en mètres, 32 texels/m.
func prisme(nom: String, a: Vector3, b: Vector3, r: float, cotes := 6, r_b := -1.0) -> void:
	var ax := (b - a)
	var longueur := ax.length()
	if longueur < 0.001:
		return
	var d := ax / longueur
	var u := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var w := d.cross(u)
	var t: float = TUILE.get(nom, 1.0)
	var rb := r if r_b < 0.0 else r_b
	var cote := 2.0 * r * sin(PI / cotes)
	for i in cotes:
		var a0 := TAU * i / cotes
		var a1 := TAU * (i + 1) / cotes
		var r0 := u * cos(a0) + w * sin(a0)
		var r1 := u * cos(a1) + w * sin(a1)
		var p0 := a + r0 * r
		var p1 := a + r1 * r
		var p2 := b + r1 * rb
		var p3 := b + r0 * rb
		var n := (r0 + r1).normalized()
		quad(nom, p0, p1, p2, p3, n, [Vector2(0, i * cote / t), Vector2(0, (i + 1) * cote / t), Vector2(longueur / t, (i + 1) * cote / t), Vector2(longueur / t, i * cote / t)])
	# bouts : un éventail (bois, fer)
	for k in 2:
		var c := a if k == 0 else b
		var rr := r if k == 0 else rb
		var nn := -d if k == 0 else d
		var bf := _buf(c, nom)
		for i in cotes:
			var a0 := TAU * i / cotes
			var a1 := TAU * (i + 1) / cotes
			var q0 := c + (u * cos(a0) + w * sin(a0)) * rr
			var q1 := c + (u * cos(a1) + w * sin(a1)) * rr
			_tri(bf, c, q0, q1, nn, Vector2(0.5, 0.5), Vector2(0.5 + cos(a0) * 0.2, 0.5 + sin(a0) * 0.2), Vector2(0.5 + cos(a1) * 0.2, 0.5 + sin(a1) * 0.2))
	_nb_pieces += 1

## Boîte orientée par une Basis complète (couvercle ouvert, plateaux inclinés).
func boite_b(nom: String, centre: Vector3, taille: Vector3, basis: Basis) -> void:
	var h := taille * 0.5
	var t: float = TUILE.get(nom, 1.0)
	for f in _FACES:
		var n: Vector3 = f[0]
		var pts: Array = f[1]
		var w: Array = []
		var u: Array = []
		for p: Vector3 in pts:
			w.append(centre + basis * (p * h))
			u.append(_uv(p * h, n, t))
		quad(nom, w[0], w[1], w[2], w[3], basis * n, u)
	_nb_pieces += 1

func solide_rond(centre: Vector3, rayon: float, haut: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rayon
	cyl.height = haut
	cs.shape = cyl
	cs.position = centre
	corps.add_child(cs)

func projecteur(pos: Vector3, cible: Vector3, couleur: Color, energie: float, portee: float, angle: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = couleur.lerp(Color(0.86, 0.9, 0.97), 0.6)     # jour de la faille : blanc froid, sans bleu saturé
	l.light_energy = energie
	l.spot_range = portee
	l.spot_angle = angle
	l.spot_attenuation = 0.8
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 6.0
	racine.add_child(l)
	l.position = pos
	l.look_at_from_position(pos, cible, Vector3.RIGHT if absf((cible - pos).normalized().y) > 0.95 else Vector3.UP)
	return l

## Rai oblique : deux plans croisés, du haut (origine du rai) vers le bas ; carte additive "rai_g".
func rai_oblique(haut: Vector3, bas: Vector3, largeur_haut: float, largeur_bas: float) -> void:
	var d := (bas - haut)
	var lat := d.cross(Vector3.UP).normalized()
	for k in 2:
		var s := lat if k == 0 else d.cross(lat).normalized()
		var a := haut - s * largeur_haut * 0.5
		var b := haut + s * largeur_haut * 0.5
		var c := bas + s * largeur_bas * 0.5
		var e := bas - s * largeur_bas * 0.5
		var n := (b - a).cross(e - a).normalized()
		quad("rai_g", a, b, c, e, n, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])

# ------------------------------------------------------------------ mobilier du campement
func caisse(pos: Vector3, taille := Vector3(0.7, 0.5, 0.5), lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	boite("bois", pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	for dx in [-0.5, 0.5]:
		boite("bois", pos + b * Vector3(dx * (taille.x - 0.06), taille.y * 0.5, 0), Vector3(0.06, taille.y + 0.02, taille.z + 0.02), lacet)
	for dy in [0.07, taille.y - 0.07]:
		boite("fer", pos + Vector3(0, dy, 0), Vector3(taille.x + 0.02, 0.035, taille.z + 0.02), lacet)
	var s := b * Vector3(taille.x, 0, taille.z)
	solide(pos + Vector3(0, taille.y * 0.5, 0), Vector3(absf(s.x), taille.y, absf(s.z)))

func coffre_ouvert(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	boite("bois", pos + Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.56), lacet)
	boite("fer", pos + Vector3(0, 0.02, 0), Vector3(0.94, 0.05, 0.6), lacet)
	for dx in [-0.3, 0.3]:
		boite("fer", pos + b * Vector3(dx, 0.22, 0), Vector3(0.09, 0.46, 0.6), lacet)
	# couvercle rabattu en arrière (charnière à l'arrière du dessus)
	var charn := pos + b * Vector3(0, 0.44, -0.28)
	var rot := b * Basis(Vector3.RIGHT, deg_to_rad(-112.0))
	boite_b("bois", charn + rot * Vector3(0, 0.07, 0.25), Vector3(0.9, 0.1, 0.5), rot)
	boite_b("fer", charn + rot * Vector3(-0.3, 0.07, 0.25), Vector3(0.09, 0.12, 0.52), rot)
	boite_b("fer", charn + rot * Vector3(0.3, 0.07, 0.25), Vector3(0.09, 0.12, 0.52), rot)
	# butin : pièces en tas dans le coffre
	for k in 14:
		var px := rng.randf_range(-0.34, 0.34)
		var pz := rng.randf_range(-0.2, 0.2)
		boite("or", pos + b * Vector3(px, 0.43 + 0.04 * (1.0 - absf(px) * 2.0), pz), Vector3(0.07, 0.025, 0.07), rng.randf() * TAU)
	var sz := b * Vector3(0.9, 0, 0.56)
	solide(pos + Vector3(0, 0.3, 0), Vector3(absf(sz.x), 0.6, absf(sz.z)))

func pieces(pos: Vector3, n: int, rayon: float) -> void:
	for k in n:
		var a := rng.randf() * TAU
		var d := rng.randf() * rayon
		boite("or", pos + Vector3(cos(a) * d, 0.012 + 0.02 * float(k % 3) * (1.0 - d / rayon), sin(a) * d), Vector3(0.06, 0.02, 0.06), rng.randf() * TAU)

func sac(pos: Vector3, e := 1.0) -> void:
	var prof := [Vector2(0.2, 0.0), Vector2(0.26, 0.12), Vector2(0.24, 0.3), Vector2(0.14, 0.44), Vector2(0.06, 0.5), Vector2(0.1, 0.56)]
	var pe: Array = []
	for p: Vector2 in prof:
		pe.append(p * e)
	tour("paille", pos, pe, 6, 0.3, true)
	tour("fer", pos + Vector3(0, 0.42 * e, 0), [Vector2(0.075 * e, 0.0), Vector2(0.075 * e, 0.03 * e)], 6, 0.3, false)

func tabouret(pos: Vector3) -> void:
	boite("bois", pos + Vector3(0, 0.42, 0), Vector3(0.34, 0.06, 0.34), 0.3)
	for sx in [-0.12, 0.12]:
		for sz in [-0.12, 0.12]:
			boite("bois", pos + Vector3(sx, 0.2, sz), Vector3(0.05, 0.4, 0.05), 0.0)

func couchage(pos: Vector3, lacet := 0.0, peau_col := true) -> void:
	var b := Basis(Vector3.UP, lacet)
	# châlit de bois sur 4 pieds (plateau à 0,3 m), paillasse, paille, fourrures, oreiller : haut de 0,55 m
	for sx in [-0.44, 0.44]:
		for sz in [-0.9, 0.9]:
			boite("bois", pos + b * Vector3(sx, 0.15, sz), Vector3(0.09, 0.3, 0.09), lacet)
	boite("bois", pos + b * Vector3(0, 0.31, 0), Vector3(1.0, 0.07, 2.0), lacet)
	boite("bois", pos + b * Vector3(-0.47, 0.37, 0), Vector3(0.06, 0.1, 2.0), lacet)
	boite("bois", pos + b * Vector3(0.47, 0.37, 0), Vector3(0.06, 0.1, 2.0), lacet)
	boite("peau", pos + b * Vector3(0, 0.41, 0), Vector3(0.88, 0.14, 1.9), lacet)                 # paillasse
	boite("paille", pos + b * Vector3(0, 0.49, 0.35), Vector3(0.82, 0.03, 1.2), lacet)           # paille qui déborde
	boite("peau", pos + b * Vector3(0.02, 0.53, 0.32), Vector3(0.8, 0.07, 1.1), lacet + 0.04)    # couverture de fourrure
	boite("peau", pos + b * Vector3(-0.1, 0.6, -0.1), Vector3(0.5, 0.08, 0.34), lacet + 0.5)     # fourrure roulée
	boite("paille" if peau_col else "peau", pos + b * Vector3(0.0, 0.54, -0.76), Vector3(0.46, 0.14, 0.3), lacet)   # oreiller
	var s := b * Vector3(1.0, 0, 2.0)
	solide(pos + Vector3(0, 0.3, 0), Vector3(absf(s.x), 0.6, absf(s.z)))

func ratelier(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	for sx in [-0.8, 0.8]:
		boite("bois", pos + b * Vector3(sx, 0.7, 0), Vector3(0.1, 1.4, 0.1), lacet)
	boite("bois", pos + b * Vector3(0, 1.15, 0), Vector3(1.7, 0.08, 0.08), lacet)
	boite("bois", pos + b * Vector3(0, 0.45, 0), Vector3(1.7, 0.08, 0.08), lacet)
	for k in 6:
		var x := -0.62 + k * 0.25
		var pied := pos + b * Vector3(x, 0.02, 0.28)
		var tete := pos + b * Vector3(x + rng.randf_range(-0.04, 0.04), 1.55 + (0.25 if k % 3 == 0 else 0.0), 0.04)
		if k % 3 == 0:        # lance : hampe de bois, fer de lance
			prisme("bois", pied, tete, 0.018, 5)
			prisme("lame", tete - (tete - pied).normalized() * 0.04, tete + (tete - pied).normalized() * 0.2, 0.03, 4, 0.004)
		else:                  # épée : lame de fer, garde, poignée
			prisme("lame", pied, tete - Vector3(0, 0.2, 0), 0.022, 4, 0.016)
			boite_b("fer", tete - Vector3(0, 0.2, 0), Vector3(0.22, 0.035, 0.035), b)
			prisme("bois", tete - Vector3(0, 0.2, 0), tete + Vector3(0, 0.05, 0), 0.016, 5)
	solide(pos + Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 0.5) if absf(cos(lacet)) > 0.7 else Vector3(0.5, 1.5, 1.8))

func trophee(pos: Vector3, hauteur := 1.6, lacet := 0.0) -> void:
	prisme("bois", pos, pos + Vector3(0.03, hauteur, 0), 0.04, 5)
	crane(pos + Vector3(0.03, hauteur - 0.01, 0), lacet)
	solide_rond(pos + Vector3(0, hauteur * 0.5, 0), 0.08, hauteur)

func feu_camp(pos: Vector3) -> void:
	for k in 9:
		var a := TAU * k / 9.0 + 0.2
		rocher("c_roche_nu", pos + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), 0.17, 0.2, 400 + k, 0.0, false, 5)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		prisme("bois", pos + Vector3(cos(a) * 0.5, 0.05, sin(a) * 0.5), pos + Vector3(-cos(a) * 0.05, 0.28, -sin(a) * 0.05), 0.05, 6)
	tour("braise", pos + Vector3(0, 0.07, 0), [Vector2(0.42, 0.0), Vector2(0.38, 0.03)], 8, 0.0, true)
	flamme(pos + Vector3(0, 0.2, 0), 2.1)
	flamme(pos + Vector3(0.12, 0.2, 0.08), 1.4)
	carte("halo", pos + Vector3(0, 0.03, 0), Vector3.UP, 3.6, 3.6)
	solide_rond(pos + Vector3(0, 0.15, 0), 0.7, 0.3)

# ------------------------------------------------------------------ fin : coque colorée
func finir() -> void:
	if racine is Grotte:
		_habiller(racine as Grotte)
	super.finir()
	for cle in _coq:
		var b: Dictionary = _coq[cle]
		var v: PackedVector3Array = b["v"]
		if v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = b["n"]
		arr[Mesh.ARRAY_TEX_UV] = b["u"]
		arr[Mesh.ARRAY_COLOR] = b["c"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat(b["nom"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Coque_" + String(cle).replace("|", "_").replace(",", "_").replace("-", "m")
		racine.add_child(mi)
	_coq.clear()
	_coq_idx.clear()

# ------------------------------------------------------------------ habillage (refonte matières, lumière, accessoires)
## Passe finale, après les modules de GrotteModules et avant la fusion des maillages : n'utilise que l'interface publique de Grotte
## (zones, branches, sol_en, plafond_en, demi_l, droite, tang, libre). Aucun accessoire n'ajoute de facette de collision à la coque ;
## les solides éventuels (caisses, poteaux) ne sont posés que là où `libre` le permet (voie centrale et réserves intactes).
##  - lumières : les lumières vert-bleu « décoratives » deviennent des LANTERNES orange (sur étai de mine, sur poteau, ou brasero au camp) ;
##    restent froides : l'entrée (jour), le lac gelé, la branche des cristaux.
##  - glaçons au plafond (denses à l'entrée, au lac, aux cristaux), toiles d'araignée dans les angles, chaînes, caisses et tonneaux
##    (mine, camp, cache), braseros du camp, cascade gelée vers le lac, nappes de brume au sol.
const FROID_LAC := Color(0.62, 0.78, 0.86)
const FROID_CRISTAL := Color(0.5, 0.68, 1.0)
const JOUR_C := Color(0.78, 0.86, 1.0)
const LANTERNE_C := Color(1.0, 0.6, 0.28)

var _hab_r := RandomNumberGenerator.new()

func _habiller(g: Grotte) -> void:
	_hab_r.seed = 9173
	_retoucher_lumieres(g)
	for zid: String in g.zones:
		var z: Dictionary = g.zones[zid]
		match String(z.get("theme", "")):
			"mine":
				_hab_mine(g, z)
			"repaire":
				_hab_camp(g, z)
			"lac":
				_hab_lac(g, z)
			"cristaux":
				_hab_cristaux(g, z)
			"cache":
				_hab_cache(g, z)
			"boyau", "carrefour":
				_hab_boyau(g, z)
	_glacons(g)

## Style de matière d'une branche en s (même lecture que Grotte._matiere).
static func _style_en(g: Grotte, id: String, s: float) -> String:
	var sty := "nu"
	for m: Array in ((g.br[id] as Dictionary)["d"] as Dictionary).get("matieres", [[999.0, "nu"]]):
		sty = String(m[1])
		if s < float(m[0]):
			break
	return sty

## (branche, s, lat) du point de la galerie le plus proche d'une position locale.
static func _situer(g: Grotte, p: Vector3) -> Array:
	var best := ["", 0.0, 0.0]
	var bd := 1e18
	for id: String in g.ordre:
		for r: Dictionary in (g.br[id] as Dictionary)["anneaux"]:
			var c: Vector3 = r["P"]
			var d := Vector2(c.x - p.x, c.z - p.z).length_squared()
			if d < bd:
				bd = d
				best = [id, float(r["s"]), (p - c).dot(r["R"] as Vector3)]
	return best

static func _zone_en(g: Grotte, id: String, s: float) -> Dictionary:
	for zid: String in g.zones:
		var z: Dictionary = g.zones[zid]
		if String(z["branche"]) == id and s >= float(z["s"][0]) and s <= float(z["s"][1]):
			return z
	return {}

func _retoucher_lumieres(g: Grotte) -> void:
	var etais := {}       # branche -> [s des étais]
	for zid: String in g.zones:
		var z: Dictionary = g.zones[zid]
		var pr: Dictionary = z.get("params", {})
		if pr.has("etais"):
			var l: Array = etais.get(String(z["branche"]), [])
			l.append_array(pr["etais"])
			etais[String(z["branche"])] = l
	for l: OmniLight3D in toutes.duplicate():
		var col := l.light_color
		var a_source := false                          # une flamme visible tout près (feu de camp, torche) : rien à changer
		for f: Array in _flammes_def:
			if (f[0] as Vector3).distance_to(l.position) < 1.6:
				a_source = true
				break
		if a_source:
			continue
		var sit := _situer(g, l.position)
		var id: String = sit[0]
		if id == "":
			continue
		var s: float = sit[1]
		var z := _zone_en(g, id, s)
		var th := String(z.get("theme", ""))
		var sty := _style_en(g, id, s)
		if th == "entree" and s < 12.0:
			l.light_color = JOUR_C                      # jour froid de la bouche
			continue
		if th == "cristaux" and sty == "cristaux":
			l.light_color = FROID_CRISTAL                # DA « cristal bleu » : accent court, pas d'éclairage d'ensemble
			l.light_energy = 0.9
			l.omni_range = 5.5
			continue
		if th == "lac" and sty == "glace" and col.b > col.g and _hab_r.randf() < 0.6:
			l.light_color = FROID_LAC
			l.light_energy *= 0.75
			continue
		# lumière chaude : on lui donne une source visible
		l.light_color = LANTERNE_C.lerp(Color(1.0, 0.5, 0.2), _hab_r.randf())
		l.light_energy = maxf(l.light_energy, 2.5)
		l.omni_range = maxf(l.omni_range, 10.0)
		l.omni_attenuation = 1.3
		lumieres.append([l, l.light_energy, _hab_r.randf() * 10.0])
		var proche_etai := -1.0
		for se: float in etais.get(id, []):
			if absf(se - s) < 4.5 and (proche_etai < 0.0 or absf(se - s) < absf(proche_etai - s)):
				proche_etai = se
		if proche_etai >= 0.0:
			l.position = _lanterne_etai(g, id, proche_etai, 1.0 if fmod(proche_etai, 2.0) < 1.0 else -1.0)
		elif th == "repaire":
			var dl := g.demi_l(id, s)
			var cote := 1.0 if float(sit[2]) >= 0.0 else -1.0
			var lat := cote * (dl.y if cote > 0.0 else dl.x) * 0.72
			var p := g.sol_en(id, s, lat)
			brasero_fer(p, g.libre(id, s, lat, 0.45))
			l.position = p + Vector3(0, 1.3, 0)
		else:
			var dl := g.demi_l(id, s)
			var cote := 1.0 if float(sit[2]) >= 0.0 else -1.0
			var lat := cote * maxf((dl.y if cote > 0.0 else dl.x) - 0.55, 0.9)
			var p := g.sol_en(id, s, lat)
			l.position = poteau_lanterne(p, -g.droite(id, s) * cote, g.libre(id, s, lat, 0.2))

# ------------------------------------------------------------------ pièces d'accessoires
## Lanterne de fer suspendue (crochet en `haut`) : chaînette, chapeau, cage à 4 montants, flamme, halo. Rend le centre de la flamme.
func lanterne(haut: Vector3, chaine_l := 0.18) -> Vector3:
	var c := haut - Vector3(0, chaine_l, 0)
	if chaine_l > 0.02:
		chaine(haut, c)
	tour("fer", c - Vector3(0, 0.07, 0), [Vector2(0.13, 0.0), Vector2(0.03, 0.07)], 6, 0.0, true)      # chapeau
	var bas := c - Vector3(0, 0.36, 0)
	tour("fer", bas, [Vector2(0.11, 0.0), Vector2(0.11, 0.025)], 6, 0.0, true)                         # fond
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var o := Vector3(cos(a) * 0.1, 0, sin(a) * 0.1)
		boite("fer", bas + o + Vector3(0, 0.15, 0), Vector3(0.022, 0.29, 0.022))
	boite("fer", bas + Vector3(0, 0.15, 0), Vector3(0.21, 0.018, 0.21))                               # cerclage
	var f := bas + Vector3(0, 0.06, 0)
	flamme(f, 0.75)
	carte("halo", f + Vector3(0, 0.1, 0), Vector3(0, 0, 1), 0.9, 0.9)
	carte("halo", f + Vector3(0, 0.1, 0), Vector3(1, 0, 0), 0.9, 0.9)
	return f + Vector3(0, 0.12, 0)

## Poteau de bois planté au sol, potence et lanterne pendue côté galerie (`vers` = vers le centre). Rend la position de la lumière.
func poteau_lanterne(pied: Vector3, vers: Vector3, avec_solide := false) -> Vector3:
	var d := Vector3(vers.x, 0, vers.z).normalized()
	var h := 2.35
	prisme("bois", pied + Vector3(0, -0.1, 0), pied + Vector3(0, h, 0), 0.085, 6)
	prisme("bois", pied + Vector3(0, h - 0.12, 0) - d * 0.08, pied + Vector3(0, h - 0.12, 0) + d * 0.62, 0.05, 5)
	prisme("bois", pied + Vector3(0, h - 0.62, 0), pied + Vector3(0, h - 0.16, 0) + d * 0.4, 0.035, 5)    # jambe de force
	boite("fer", pied + Vector3(0, h - 0.12, 0) + d * 0.58, Vector3(0.05, 0.06, 0.05))
	for k in 3:                                                                                           # cordage autour du pied
		boite("paille", pied + Vector3(0, 0.25 + 0.06 * k, 0), Vector3(0.2, 0.035, 0.2), 0.4 * k)
	if avec_solide:
		solide_rond(pied + Vector3(0, 1.1, 0), 0.1, 2.2)
	return lanterne(pied + Vector3(0, h - 0.16, 0) + d * 0.58, 0.16)

## Lanterne pendue à la traverse d'un étai de mine (côté `cote`). Rend la position de la lumière.
func _lanterne_etai(g: Grotte, id: String, s: float, cote: float) -> Vector3:
	var dl := g.demi_l(id, s)
	var w := (dl.y if cote > 0.0 else dl.x) - 0.25
	var h := Grotte._interp((g.br[id] as Dictionary)["profil"], s, 4)
	var pa := g.sol_en(id, s, -(dl.x - 0.25))
	var pb := g.sol_en(id, s, dl.y - 0.25)
	var haut := minf(pa.y, pb.y) + h - 0.55 - 0.17
	var p := g.sol_en(id, s, cote * maxf(w - 0.55, 0.6))
	var T := g.tang(id, s)
	return lanterne(Vector3(p.x, haut, p.z) + T * 0.2, 0.3)

## Brasero de fer forgé : trépied, vasque, braises, grande flamme, halo au sol.
func brasero_fer(pos: Vector3, avec_solide := true) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		prisme("fer", pos + Vector3(cos(a) * 0.36, 0.0, sin(a) * 0.36), pos + Vector3(cos(a) * 0.16, 0.72, sin(a) * 0.16), 0.03, 4)
	tour("fer", pos + Vector3(0, 0.68, 0), [Vector2(0.14, 0.0), Vector2(0.36, 0.1), Vector2(0.44, 0.24), Vector2(0.4, 0.26)], 8, 0.0, true)
	boite("fer", pos + Vector3(0, 0.84, 0), Vector3(0.9, 0.03, 0.05), 0.3)
	tour("braise", pos + Vector3(0, 0.9, 0), [Vector2(0.36, 0.0), Vector2(0.3, 0.04)], 8, 0.0, true)
	flamme(pos + Vector3(0, 0.92, 0), 1.8)
	flamme(pos + Vector3(0.1, 0.92, 0.06), 1.2)
	carte("halo", pos + Vector3(0, 0.03, 0), Vector3.UP, 3.2, 3.2)
	if avec_solide:
		solide_rond(pos + Vector3(0, 0.5, 0), 0.42, 1.0)

## Toile d'araignée tendue dans l'angle paroi / plafond, côté `cote`.
func _toile_angle(g: Grotte, id: String, s: float, cote: float, l := 1.0) -> void:
	var dl := g.demi_l(id, s)
	var w := (dl.y if cote > 0.0 else dl.x)
	var lat := cote * w * 0.82
	var haut := g.plafond_en(id, s, lat)
	var sol := g.sol_en(id, s, lat)
	if haut.y - sol.y < 2.0:
		return
	var coin := Vector3(haut.x, haut.y - 0.15, haut.z)
	var T := g.tang(id, s)
	var R := g.droite(id, s)
	toile(coin, T * (1.0 if _hab_r.randf() < 0.5 else -1.0), -R * cote, l)

## Caisse empilée (une ou deux) près de la paroi ; collision seulement si la place est libre.
func _caisses(g: Grotte, id: String, s: float, cote: float, n := 2) -> void:
	var dl := g.demi_l(id, s)
	var w := (dl.y if cote > 0.0 else dl.x)
	if w < 1.6:
		return
	var lat := cote * (w - 0.75)
	if not g.libre(id, s, lat, 0.6):
		return
	var p := g.sol_en(id, s, lat)
	var lac := atan2(g.tang(id, s).x, g.tang(id, s).z) + _hab_r.randf_range(-0.3, 0.3)
	caisse(p, Vector3(0.75, 0.55, 0.6), lac)
	if n > 1:
		var b := Basis(Vector3.UP, lac)
		caisse(p + b * Vector3(0.05, 0.55, 0.02), Vector3(0.55, 0.42, 0.48), lac + 0.35)
		if g.libre(id, s + 0.9, lat, 0.45):
			tonneau(g.sol_en(id, s + 0.9, lat), 0.85)

# ------------------------------------------------------------------ zones
func _hab_mine(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	# une lanterne allumée sur chaque étai qui n'en porte pas encore (une sur deux de chaque côté)
	var pr: Dictionary = z.get("params", {})
	var ke := 0
	for se: float in pr.get("etais", []):
		var cote := 1.0 if fmod(se, 2.0) < 1.0 else -1.0
		var deja := false
		for l: OmniLight3D in toutes:
			var sit := _situer(g, l.position)
			if String(sit[0]) == id and absf(float(sit[1]) - se) < 1.0:
				deja = true
				break
		if not deja:
			var pl := _lanterne_etai(g, id, se, -cote if ke % 2 == 0 else cote)
			lumiere(pl, LANTERNE_C, 2.2, 9.0, 1.3, true)
		ke += 1
	var s := s0 + 2.5
	var k := 0
	while s < s1 - 1.5:
		var cote := 1.0 if k % 2 == 0 else -1.0
		if _hab_r.randf() < 0.55:
			_toile_angle(g, id, s, cote, _hab_r.randf_range(0.7, 1.3))
		if k % 3 == 1:
			_caisses(g, id, s, -cote, 1 + (k % 2))
		if k % 3 == 2:
			var dl := g.demi_l(id, s)
			var lat := cote * maxf((dl.y if cote > 0.0 else dl.x) - 0.55, 0.9)
			if g.libre(id, s, lat, 0.2):
				var pl := poteau_lanterne(g.sol_en(id, s, lat), -g.droite(id, s) * cote, true)
				lumiere(pl, LANTERNE_C, 2.2, 9.0, 1.3, true)
		s += _hab_r.randf_range(3.5, 6.0)
		k += 1

func _hab_camp(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	# braseros de fer contre les parois (deux par zone de camp), lumière orange vacillante
	for k in 2:
		var sb := lerpf(s0, s1, 0.3 + 0.4 * k)
		var cote := -1.0 if k == 0 else 1.0
		var dlb := g.demi_l(id, sb)
		var latb := cote * (dlb.y if cote > 0.0 else dlb.x) * 0.7
		if g.libre(id, sb, latb, 0.5):
			var pb := g.sol_en(id, sb, latb)
			brasero_fer(pb, true)
			lumiere(pb + Vector3(0, 1.4, 0), Color(1.0, 0.52, 0.2), 2.3, 9.0, 1.4, true)
	# chaînes pendues au plafond, crochets
	var s := s0 + 3.0
	var k := 0
	while s < s1 - 2.0:
		var cote := 1.0 if k % 2 == 0 else -1.0
		var dl := g.demi_l(id, s)
		var lat := cote * (dl.y if cote > 0.0 else dl.x) * _hab_r.randf_range(0.45, 0.75)
		var haut := g.plafond_en(id, s, lat)
		var sol := g.sol_en(id, s, lat)
		var libre_h := haut.y - sol.y
		if libre_h > 3.2:
			var bas := haut.y - minf(libre_h - 2.4, _hab_r.randf_range(0.8, 1.8))
			chaine(Vector3(haut.x, haut.y + 0.1, haut.z), Vector3(haut.x, bas, haut.z))
			boite("fer", Vector3(haut.x, bas - 0.06, haut.z), Vector3(0.12, 0.03, 0.03))
		_caisses(g, id, s + 1.5, -cote, 2)
		if _hab_r.randf() < 0.6:
			_toile_angle(g, id, s + 0.7, cote, 1.1)
		s += _hab_r.randf_range(3.5, 5.0)
		k += 1

func _hab_boyau(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var s := float(z["s"][0]) + 2.0
	var k := 0
	while s < float(z["s"][1]) - 1.0:
		_toile_angle(g, id, s, 1.0 if k % 2 == 0 else -1.0, _hab_r.randf_range(0.6, 1.1))
		s += _hab_r.randf_range(3.0, 5.5)
		k += 1

func _hab_cache(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var s := float(z["s"][0]) + 1.5
	var k := 0
	while s < float(z["s"][1]) - 0.5:
		_toile_angle(g, id, s, 1.0, _hab_r.randf_range(0.8, 1.4))
		_toile_angle(g, id, s + 1.2, -1.0, _hab_r.randf_range(0.8, 1.4))
		s += _hab_r.randf_range(2.0, 3.0)
		k += 1

## Lac : cascade gelée sur la paroi du côté du lac, nappes de brume sur la glace.
func _hab_lac(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var b: Dictionary = g.br[id]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	if String(z.get("role", "")) == "combat":
		var best := -1.0
		var bl := 0.0
		var s := s0 + 3.0
		while s < s1 - 3.0:
			var lam := g.lac_f(b, s)
			if lam > bl + 0.01 and g.faille_f(b, s) < 0.02:
				bl = lam
				best = s
			s += 1.0
		if best > 0.0:
			_cascade(g, id, best + 4.0 if best + 4.0 < s1 - 2.0 else best)
	# brume : cartes horizontales au ras du sol / de la glace
	var s := s0 + 2.0
	while s < s1 - 1.0:
		var dl := g.demi_l(id, s)
		var lat := _hab_r.randf_range(-dl.x * 0.7, dl.y * 0.7)
		var p := g.sol_en(id, s, lat)
		_nappe(p + Vector3(0, _hab_r.randf_range(0.12, 0.3), 0), _hab_r.randf_range(4.0, 6.5))
		s += _hab_r.randf_range(3.0, 4.5)

func _hab_cristaux(g: Grotte, z: Dictionary) -> void:
	var id: String = z["branche"]
	var s := float(z["s"][0]) + 6.0
	while s < float(z["s"][1]) - 1.0:
		var dl := g.demi_l(id, s)
		var p := g.sol_en(id, s, _hab_r.randf_range(-dl.x * 0.6, dl.y * 0.6))
		_nappe(p + Vector3(0, _hab_r.randf_range(0.1, 0.25), 0), _hab_r.randf_range(3.5, 5.5))
		s += _hab_r.randf_range(3.0, 4.0)

## Nappe de brume : deux cartes horizontales décalées (tons en paliers, bords rongés), sans collision.
func _nappe(c: Vector3, taille: float) -> void:
	var a := _hab_r.randf() * TAU
	var u := Vector3(cos(a), 0, sin(a)) * taille * 0.5
	var v := Vector3(-sin(a), 0, cos(a)) * taille * 0.5
	quad("brume_g", c - u - v, c + u - v, c + u + v, c - u + v, Vector3.UP, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var c2 := c + Vector3(0, 0.22, 0) + u * 0.3
	quad("brume_g", c2 - v * 0.8 - u * 0.7, c2 + u * 0.7 - v * 0.8, c2 + u * 0.7 + v * 0.8, c2 - u * 0.7 + v * 0.8, Vector3.UP, [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)])

## Cascade gelée : rideau de colonnes de glace du haut de la paroi (côté lac, à gauche) jusqu'à la glace, pied évasé.
func _cascade(g: Grotte, id: String, s: float) -> void:
	var dl := g.demi_l(id, s)
	var T := g.tang(id, s)
	var R := g.droite(id, s)
	var y_bas := g.lac_y - 0.05
	for k in 11:
		var ds := (float(k) - 5.0) * 0.32 + _hab_r.randf_range(-0.08, 0.08)
		var lat := -dl.x * 0.93 + absf(float(k) - 5.0) * 0.05
		var top := g.plafond_en(id, s + ds, lat)
		var base := g.sol_en(id, s + ds, lat)
		var pied := Vector3(base.x, maxf(y_bas, base.y - 0.1), base.z)
		var h := top.y - pied.y - 0.3
		if h < 1.5:
			continue
		var r := _hab_r.randf_range(0.14, 0.3) * (1.2 - absf(float(k) - 5.0) * 0.08)
		var prof := [Vector2(r * 2.4, 0.0), Vector2(r * 1.5, h * 0.1), Vector2(r * 1.05, h * 0.3), Vector2(r * 0.85, h * 0.6), Vector2(r * 1.1, h * 0.85), Vector2(r * 1.6, h + 0.35)]
		revolution("c_glacon", pied + R * 0.15, prof, 6, _hab_r.randi(), 0.3, 0.0, 0.85, 1.0, 1.0)
	# flaque de glace claire au pied, glaçons courts tout autour
	for k in 14:
		var ds := _hab_r.randf_range(-2.4, 2.4)
		var lat := -dl.x * _hab_r.randf_range(0.6, 0.9)
		var top := g.plafond_en(id, s + ds, lat)
		pointe("c_glacon", top + Vector3(0, 0.08, 0), _hab_r.randf_range(0.05, 0.13), -_hab_r.randf_range(0.5, 1.6), _hab_r.randi(), 0.0, 5)
	carte("halo_f", g.sol_en(id, s, -dl.x * 0.7) + Vector3(0, 0.03, 0) + T * 0.0, Vector3.UP, 4.0, 4.0)

## Glaçons pendus au plafond, par grappes : denses à l'entrée, au lac gelé et chez les cristaux, rares ailleurs, jamais au camp.
## Ils restent hors de portée de la tête (2,3 m de garde au sol, ou près des parois).
func _glacons(g: Grotte) -> void:
	for id: String in g.ordre:
		var b: Dictionary = g.br[id]
		var L: float = b["L"]
		var s := 1.0
		while s < L - 1.0:
			var sty := _style_en(g, id, s)
			var dens := 0.0
			match sty:
				"neige":
					dens = 0.95
				"glace", "cristaux":
					dens = 0.75
				"camp":
					dens = 0.0
				"goulot":
					dens = 0.25
				_:
					dens = 0.18
			if g.faille_f(b, s) > 0.02:
				dens = 0.0
			if _hab_r.randf() < dens:
				var dl := g.demi_l(id, s)
				var cote := 1.0 if _hab_r.randf() < 0.5 else -1.0
				var w := (dl.y if cote > 0.0 else dl.x)
				var lat0 := cote * w * _hab_r.randf_range(0.35, 0.85)
				var n := _hab_r.randi_range(2, 6)
				for k in n:
					var lat := lat0 + _hab_r.randf_range(-0.5, 0.5)
					var ss := s + _hab_r.randf_range(-0.4, 0.4)
					var top := g.plafond_en(id, ss, lat)
					var sol := g.sol_en(id, ss, lat)
					var garde := top.y - sol.y
					var l := _hab_r.randf_range(0.25, 1.1) * (1.0 if k % 3 != 0 else 0.5)
					if garde - l < 2.3 and absf(lat) < w * 0.7:
						l = garde - 2.3
					if l < 0.15 or garde < 1.0:
						continue
					pointe("c_glacon", top + Vector3(0, 0.1, 0), _hab_r.randf_range(0.03, 0.09) * (0.6 + l * 0.6), -l, _hab_r.randi(), 0.0, 5)
			s += 0.8
