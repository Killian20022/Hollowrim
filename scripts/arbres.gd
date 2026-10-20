class_name Arbres
## Arbres procéduraux, version 2 : épicéas à étages de branches en étoile, pointes qui
## tombent, dessous sombre, neige posée sur le dessus des branches ; plus des arbres morts.
## Chaque modèle est un ArrayMesh à trois surfaces (tronc, aiguilles, neige).

## Texture d'aiguilles : courts traits obliques sur fond sombre (plutôt que du bruit).
static func texture_aiguilles(graine: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := 32
	var fond := [Color("#09140f"), Color("#0d1a13")]
	var traits := [Color("#163024"), Color("#1d3b2b"), Color("#26493a"), Color("#33584a")]
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	for y in t:
		for x in t:
			img.set_pixel(x, y, fond[(x * 7 + y * 3 + rng.randi_range(0, 1)) % 2])
	for n in 150:
		var x := rng.randi_range(0, t - 1)
		var y := rng.randi_range(0, t - 1)
		var c: Color = traits[rng.randi_range(0, 3)]
		var dx := 1 if rng.randf() < 0.5 else -1
		for k in rng.randi_range(2, 4):
			img.set_pixel(posmod(x + k * dx, t), posmod(y + k, t), c)
	return ImageTexture.create_from_image(img)

## Neige sur les branches : blanc bleuté, quelques creux plus sombres.
static func texture_neige_branches(graine: int) -> ImageTexture:
	return Palette.texture(32, ["#8c9cb8", "#a9b7cf", "#c3cfe2", "#dde5f1"], 4, graine, 0.25)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.set_uv(ua); st.add_vertex(a)
	st.set_color(cb); st.set_uv(ub); st.add_vertex(b)
	st.set_color(cc); st.set_uv(uc); st.add_vertex(c)

## Un étage de branches en étoile : `pointes` branches qui retombent autour du tronc.
static func _etage(feuille: SurfaceTool, neige: SurfaceTool, rng: RandomNumberGenerator, y_haut: float, rayon: float, chute: float, pointes: int, rot: float, enneige: float, assombri := 1.0) -> void:
	var sommet := Vector3(0, y_haut, 0)
	var dessous := Vector3(0, y_haut - chute * 0.55, 0)
	var bouts: Array[Vector3] = []
	var creux: Array[Vector3] = []
	for k in pointes:
		var a := rot + TAU * k / pointes
		var r := rayon * rng.randf_range(0.85, 1.12)
		var tombe := chute * rng.randf_range(0.85, 1.25)
		bouts.append(Vector3(cos(a) * r, y_haut - tombe, sin(a) * r))
		var a2 := a + TAU * 0.5 / pointes
		creux.append(Vector3(cos(a2) * r * 0.52, y_haut - chute * 0.45, sin(a2) * r * 0.52))
	# couleurs de sommet plafonnées à 1 : le matériau éclaircit l'ensemble (teinte)
	var clair := Color(1.0, 1.0, 0.95)
	var moyen := Color(0.72, 0.72, 0.72) * assombri
	var sombre := Color(0.27, 0.29, 0.33) * assombri
	moyen.a = 1.0
	sombre.a = 1.0
	for k in pointes:
		var b0 := bouts[k]
		var c0 := creux[k]
		var b1 := bouts[(k + 1) % pointes]
		var u := float(k) / pointes * 3.0
		# dessus : le sommet est plus sombre (au cœur de l'arbre), les pointes plus claires
		_tri(feuille, sommet, c0, b0, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u, 1), moyen, moyen, clair)
		_tri(feuille, sommet, b1, c0, Vector2(u, 0), Vector2(u + 1, 1), Vector2(u + 0.5, 0.6), moyen, clair, moyen)
		# dessous, dans l'ombre
		_tri(feuille, dessous, b0, c0, Vector2(u, 0), Vector2(u, 1), Vector2(u + 0.5, 0.6), sombre, moyen, sombre)
		_tri(feuille, dessous, c0, b1, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u + 1, 1), sombre, sombre, moyen)
		# neige posée sur le dessus, sans atteindre les pointes (qui restent vertes)
		if rng.randf() < enneige:
			var f := rng.randf_range(0.62, 0.9)
			var hausse := Vector3(0, 0.1, 0)
			var nb0 := sommet.lerp(b0, f) + hausse
			var nb1 := sommet.lerp(b1, f * rng.randf_range(0.85, 1.0)) + hausse
			var nc := sommet.lerp(c0, f * 1.05) + hausse
			var blanc := Color.WHITE
			_tri(neige, sommet + hausse * 1.5, nc, nb0, Vector2(u, 0), Vector2(u + 0.5, 0.6), Vector2(u, 1), blanc, blanc, blanc)
			_tri(neige, sommet + hausse * 1.5, nb1, nc, Vector2(u, 0), Vector2(u + 1, 1), Vector2(u + 0.5, 0.6), blanc, blanc, blanc)

static func _tronc(st: SurfaceTool, rayon: float, hauteur: float, cotes := 6) -> void:
	for k in cotes:
		var a0 := TAU * k / cotes
		var a1 := TAU * (k + 1) / cotes
		# évasement au pied
		var p0 := Vector3(cos(a0) * rayon * 1.6, -0.5, sin(a0) * rayon * 1.6)
		var p1 := Vector3(cos(a1) * rayon * 1.6, -0.5, sin(a1) * rayon * 1.6)
		var m0 := Vector3(cos(a0) * rayon, 0.4, sin(a0) * rayon)
		var m1 := Vector3(cos(a1) * rayon, 0.4, sin(a1) * rayon)
		var h0 := Vector3(cos(a0) * rayon * 0.35, hauteur, sin(a0) * rayon * 0.35)
		var h1 := Vector3(cos(a1) * rayon * 0.35, hauteur, sin(a1) * rayon * 0.35)
		var sombre := Color(0.6, 0.6, 0.6)
		var w := Color.WHITE
		_tri(st, p0, p1, m1, Vector2(k, 4), Vector2(k + 1, 4), Vector2(k + 1, 3), sombre, sombre, w)
		_tri(st, p0, m1, m0, Vector2(k, 4), Vector2(k + 1, 3), Vector2(k, 3), sombre, w, w)
		_tri(st, m0, m1, h1, Vector2(k, 3), Vector2(k + 1, 3), Vector2(k + 1, 0), w, w, w)
		_tri(st, m0, h1, h0, Vector2(k, 3), Vector2(k + 1, 0), Vector2(k, 0), w, w, w)

# --- Lot 2, troncs : écorce à 32 texels/m, fût en 8 pans irréguliers, racines, mousse, neige plaquée -------
const TRONC := preload("res://shaders/ps1_tronc.gdshader")
const VENT := Vector2(0.8, -0.6)    # le vent vient du nord-est : la neige se plaque de ce côté
const NORD := Vector2(-0.35, -0.94) # mousse et lichen côté nord(-ouest)

## Matériau des troncs (ps1_tronc.gdshader) : tuiles `haut` et `pied` d'`Ecorces`, enregistré dans Palette.materiaux.
static func materiau_tronc(haut: String, pied: String, teinte := Color.WHITE, mousse := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TRONC
	m.set_shader_parameter("tex_haut", Ecorces.tuile(haut))
	m.set_shader_parameter("tex_pied", Ecorces.tuile(pied))
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("mousse_force", mousse)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

## Abscisse de texture autour d'un tronc, en miroir (0 → 1 → 0) : continue partout, sans couture (cotes pair).
static func _tri_u(k: int, n: int) -> float:
	var kk := k if k * 2 <= n else n - k
	return float(kk) / (n * 0.5)

static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, c: Color, uv: Vector2, uv2: Vector2) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.set_uv2(uv2)
	st.add_vertex(p)

## Fût en tour : `anneaux` = [[y, rayon, cx, cz], ...] du bas vers le haut, `cotes` pans (pair), section
## irrégulière (chaque sommet écarté de ±`irr`), normales lissées. cfg : pied (Vector2 : y où l'écorce du pied
## est pleine / nulle), ao (Callable y -> occlusion), mousse, vent (force de la neige plaquée), irr.
## Alpha de sommet = 1 − neige : dans la terre (y < 0) le sol est tout blanc, puis la neige se retire ; côté
## vent elle remonte. Aucun tirage dans le RNG de l'arbre (rt = RNG propre).
static func _fut(st: SurfaceTool, rt: RandomNumberGenerator, anneaux: Array, cotes: int, cfg: Dictionary) -> void:
	var nr := anneaux.size()
	var irr: float = cfg.get("irr", 0.07)
	var pied: Vector2 = cfg.get("pied", Vector2(0.4, 1.5))
	var ao_f: Callable = cfg.get("ao", func(_y: float) -> float: return 0.8)
	var mousse: float = cfg.get("mousse", 1.0)
	var vent: float = cfg.get("vent", 0.55)
	var bk: Array[float] = []
	for k in cotes:
		bk.append(rt.randf_range(-1.0, 1.0))
	var P: Array = []
	for j in nr:
		var a: Array = anneaux[j]
		var row: Array[Vector3] = []
		for k in cotes:
			var ang := TAU * k / cotes
			var f := 1.0 + irr * (bk[k] * 0.6 + rt.randf_range(-1.0, 1.0) * 0.4)
			row.append(Vector3(a[2] + cos(ang) * a[1] * f, a[0], a[3] + sin(ang) * a[1] * f))
		P.append(row)
	var V: Array = []
	for j in nr:
		var a: Array = anneaux[j]
		var row: Array = []
		for k in cotes:
			var ang := TAU * k / cotes
			var d := Vector2(cos(ang), sin(ang))
			var kp: int = (k + 1) % cotes
			var km: int = (k + cotes - 1) % cotes
			var nrm: Vector3 = (P[j][kp] - P[j][km]).cross(P[mini(j + 1, nr - 1)][k] - P[maxi(j - 1, 0)][k])
			if nrm.dot(Vector3(d.x, 0.0, d.y)) < 0.0:
				nrm = -nrm
			nrm = nrm.normalized()
			var y: float = a[0]
			var s_pied := 1.0 if y < -0.05 else (lerpf(0.85, 0.25, clampf(y / 0.7, 0.0, 1.0)) * (0.75 + 0.25 * bk[k]))
			if y >= 0.7:
				s_pied = 0.0
			var w := maxf(0.0, d.dot(VENT))
			var s_vent := w * w * vent * smoothstep(0.4, 2.0, y) * (0.7 + 0.3 * bk[(k + 3) % cotes])
			var neige := maxf(s_pied, s_vent)
			var ao: float = ao_f.call(y)
			var m := smoothstep(0.05, 0.9, d.dot(NORD)) * (1.0 - smoothstep(1.4, 3.4, y)) * mousse
			var pw := clampf((pied.y - y) / maxf(pied.y - pied.x, 0.01), 0.0, 1.0)
			row.append([nrm, Color(ao, ao, ao, 1.0 - neige), Vector2(pw, m)])
		V.append(row)
	for j in nr - 1:
		var a0: Array = anneaux[j]
		var a1: Array = anneaux[j + 1]
		var t0: float = TAU * a0[1] * 0.25
		var t1: float = TAU * a1[1] * 0.25
		for k in cotes:
			var k2 := (k + 1) % cotes
			var ids := [[j, k, t0, k], [j, k2, t0, k + 1], [j + 1, k2, t1, k + 1], [j + 1, k, t1, k]]
			var pts: Array[Vector3] = []
			for q in 4:
				pts.append(P[ids[q][0]][ids[q][1]])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for q in tri:
					var jj: int = ids[q][0]
					var kk: int = ids[q][1]
					var v: Array = V[jj][kk]
					var u: float = float(ids[q][2]) * _tri_u(ids[q][3], cotes)
					_vert(st, pts[q], v[0], v[1], Vector2(u, -float(anneaux[jj][0]) / 2.0), v[2])

## Contreforts : `n` racines en prismes à 4 pans qui partent du fût, s'écartent et plongent dans la neige.
static func _racines(st: SurfaceTool, rt: RandomNumberGenerator, n: int, r: float, cx: float, cz: float, haut := 0.8, ampleur := 1.0, simple := false) -> void:
	var off := rt.randf() * TAU
	for i in n:
		var ang := off + TAU * (i + rt.randf_range(-0.25, 0.25)) / n
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var o := Vector3(cx, 0.0, cz)
		var rr := r * 0.55 * rt.randf_range(0.8, 1.2) * ampleur
		var L := r * rt.randf_range(2.4, 3.4) * ampleur
		var p0 := o + d * r * 0.6 + Vector3(0, haut * rt.randf_range(0.8, 1.2), 0)
		var p1 := o + d * (r * 0.95 + L * 0.35) + Vector3(0, haut * 0.28, 0)
		var p2 := o + d * (r * 0.8 + L) + Vector3(0, -0.32, 0)
		if simple:
			_bois(st, p0, p2, rr, rr * 0.45, 3, Color(0.58, 0.58, 0.58), true, -p0.y / 2.0, 1.0, 0.7)
			continue
		_bois(st, p0, p1, rr, rr * 0.8, 4, Color(0.62, 0.62, 0.62), true, -p0.y / 2.0, 1.0, 0.7)
		_bois(st, p1, p2, rr * 0.8, rr * 0.45, 4, Color(0.55, 0.55, 0.55), true, -p1.y / 2.0, 1.0, 0.7)

## Raccord au sol : cuvette de neige autour du fût (la neige fond près de l'écorce, creux sombre) bordée d'une petite congère,
## plus haute côté vent, qui s'étale en pente douce. Anneaux de `n` pans (24 à 32 triangles), alpha de sommet 0 = tout blanc.
static func _congere(st: SurfaceTool, rt: RandomNumberGenerator, n: int, r: float, cx: float, cz: float, ampleur := 1.0) -> void:
	# [rayon / r, hauteur, éclairage] : cuvette près de l'écorce, lèvre de la congère, pente qui se fond dans le sol
	var profil := [[1.15, -0.05, 0.55], [1.9, 0.07, 0.92], [3.0, 0.12, 1.0], [4.6, -0.12, 1.0]]
	var bk: Array[float] = []
	for k in n:
		bk.append(rt.randf_range(0.8, 1.2))
	var P: Array = []
	for j in profil.size():
		var row: Array[Vector3] = []
		for k in n:
			var a := TAU * k / n
			var w := maxf(0.0, Vector2(cos(a), sin(a)).dot(VENT))
			var h: float = profil[j][1]
			if h > 0.0:
				h *= (0.55 + 0.9 * w) * bk[k] * ampleur
			row.append(Vector3(cx + cos(a) * r * profil[j][0] * bk[k] * (0.9 if j == 3 else 1.0), h, cz + sin(a) * r * profil[j][0] * bk[k] * (0.9 if j == 3 else 1.0)))
		P.append(row)
	for j in profil.size() - 1:
		for k in n:
			var k2 := (k + 1) % n
			var ids := [[j, k], [j, k2], [j + 1, k2], [j + 1, k]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var q: Array[Vector3] = []
				for i in tri:
					q.append(P[ids[i][0]][ids[i][1]])
				var nr := (q[1] - q[0]).cross(q[2] - q[0])
				var flip := nr.y > 0.0     # front = sens horaire, vu du dessus
				for i in ([tri[0], tri[2], tri[1]] if flip else tri):
					var jj: int = ids[i][0]
					var kk: int = ids[i][1]
					var v: Vector3 = P[jj][kk]
					var e: float = profil[jj][2]
					_vert(st, v, Vector3(0, 1, 0), Color(e, e, e, 0.0), Vector2(v.x, v.z) * 0.5, Vector2.ZERO)

## Chicots : moignons de branches mortes sur le fût (prismes à 4 pans).
static func _chicots(st: SurfaceTool, rt: RandomNumberGenerator, n: int, y0: float, y1: float, r: float, cx: float, cz: float, rayon_fut: float, cotes := 4) -> void:
	for i in n:
		var y := rt.randf_range(y0, y1)
		var a := rt.randf() * TAU
		var d := Vector3(cos(a), rt.randf_range(-0.1, 0.35), sin(a))
		var o := Vector3(cx + cos(a) * rayon_fut * 0.7, y, cz + sin(a) * rayon_fut * 0.7)
		_bois(st, o, o + d * rt.randf_range(0.14, 0.36), r, r * 0.55, cotes, Color(0.78, 0.78, 0.78), true)

# --- Lot 2 : épicéa en cartes de rameaux ----------------------------------------------------------
const RAMEAU := preload("res://shaders/ps1_rameau.gdshader")

## Matériau des cartes de rameaux (ps1_rameau.gdshader, dérivé de ps1_herbe), enregistré dans
## Palette.materiaux pour suivre la touche P (accroche + affine).
static func materiau_rameau(tex: Texture2D, teinte := Color.WHITE, teinte_neige := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RAMEAU
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("teinte_neige", teinte_neige)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

## Matériaux partagés des épicéas : [tronc (ps1, écorce pixel art), rameaux (atlas)].
static var _mats_epicea: Array = []
static func materiaux_epicea() -> Array:
	if _mats_epicea.is_empty() or not is_instance_valid(_mats_epicea[0]):
		_mats_epicea = [
			materiau_tronc("epicea_haut", "epicea_pied", Color(0.95, 0.95, 0.98)),
			materiau_rameau(TexturesArbres.atlas_epicea(), REGLAGES_EPICEA["teinte"], REGLAGES_EPICEA["teinte_neige"]),
		]
	return _mats_epicea

## Réglages de l'épicéa (voir docs/MISSION_GRAPHISME.md, journal du lot 2).
const REGLAGES_EPICEA := {
	"teinte": Color(0.84, 0.94, 0.95),   # éclaircit la rampe EPICEA AIGUILLES sous la lumière du jeu
	"teinte_neige": Color(1.0, 1.0, 1.0),
	"pli": 0.45,          # angle (rad) des deux ailes d'un rameau sous l'horizontale (rameau en toit)
	"crete": 0.1,         # hauteur de la crête de neige posée sur la tige (m)
	"aile": 0.47,         # demi-largeur d'une carte / longueur du rameau
	"milieu": 0.3,        # part de la retombée atteinte à mi-branche (bas : branche presque horizontale, bout qui retombe)
}

## Triangle orienté : sa face avant regarde `face` (Godot : (b - a) × (c - a) du côté de la face avant).
static func _tri_o(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color, na: Vector3, nb: Vector3, nc: Vector3, face: Vector3) -> void:
	if (b - a).cross(c - a).dot(face) < 0.0:
		var t := b; b = c; c = t
		var tu := ub; ub = uc; uc = tu
		var tn := nb; nb = nc; nc = tn
	st.set_color(col); st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_color(col); st.set_normal(nb); st.set_uv(ub); st.add_vertex(b)
	st.set_color(col); st.set_normal(nc); st.set_uv(uc); st.add_vertex(c)

## Quadrilatère p0-p1-p2-p3 (dans l'ordre du contour), face avant vers `face`.
static func _quad_o(st: SurfaceTool, p: Array, uv: Array, col: Color, n: Array, face: Vector3) -> void:
	_tri_o(st, p[0], p[1], p[2], uv[0], uv[1], uv[2], col, n[0], n[1], n[2], face)
	_tri_o(st, p[0], p[2], p[3], uv[0], uv[2], uv[3], col, n[0], n[2], n[3], face)

## Normale de feuillage : vers l'extérieur de la couronne et vers le haut (volume doux, pas de facettes).
static func _n_feuillage(v: Vector3, rayon_local: float) -> Vector3:
	var radial := Vector3(v.x, 0.0, v.z) / maxf(rayon_local, 0.4)
	return (radial * 0.9 + Vector3.UP * 0.55).normalized()

static func _uv(r: Rect2, u: float, v: float) -> Vector2:
	return r.position + Vector2(u, v) * r.size

## Un rameau : tige en 2 tronçons (part du tronc, s'incline vers le bas, le bout se relève un peu),
## carte pliée en toit le long de la tige (deux ailes inclinées de `pli` sous l'horizontale, texture
## coupée en deux le long de la tige dessinée), plus une crête de neige debout sur la tige.
## `segments` 1 (LOD) ou 2. `ao` : couleur de sommet (occlusion), `crete` : hauteur de crête (0 = aucune).
static func _rameau(st: SurfaceTool, origine: Vector3, a: float, L: float, chute: float, releve: float, region: Rect2, pli: float, ao: Color, crete: float, crete_v: Rect2, segments := 2) -> void:
	var d := Vector3(cos(a), 0.0, sin(a))
	var cote := Vector3(-sin(a), 0.0, cos(a))
	var tige: Array[Vector3] = [origine]
	var vs: Array[float] = [1.0]
	if segments == 2:
		tige.append(origine + d * L * 0.5 + Vector3(0, -chute * REGLAGES_EPICEA["milieu"], 0))
		tige.append(origine + d * L + Vector3(0, -chute + releve, 0))
		vs.append_array([0.5, 0.0])
	else:
		tige.append(origine + d * L + Vector3(0, -chute + releve * 0.5, 0))
		vs.append(0.0)
	var W := L * REGLAGES_EPICEA["aile"]
	var ao_base := Color(ao.r * 0.8, ao.g * 0.8, ao.b * 0.8, 1.0)
	# largeur le long de la tige : étroite au tronc (moins de cartes croisées au cœur), pleine au milieu
	var largeurs: Array = [0.35, 1.0, 0.85] if segments == 2 else [0.45, 0.9]
	for i in tige.size() - 1:
		var p0 := tige[i]
		var p1 := tige[i + 1]
		var axe := (p1 - p0).normalized()
		for w in [-1.0, 1.0]:
			var dir_aile: Vector3 = cote * w * cos(pli) + Vector3.DOWN * sin(pli)
			var aile: Vector3 = dir_aile * W * largeurs[i]
			var aile1: Vector3 = dir_aile * W * largeurs[i + 1]
			var face := axe.cross(aile)
			if face.y < 0.0:
				face = -face
			var u_bord := 0.0 if w < 0.0 else 1.0
			var r0 := Vector3(p0.x, 0, p0.z).length() + 0.3
			var r1 := Vector3(p1.x, 0, p1.z).length() + 0.3
			var n0 := _n_feuillage(p0, r1)
			var n1 := _n_feuillage(p1, r1)
			var n0b := _n_feuillage(p0 + aile, r1)
			var n1b := _n_feuillage(p1 + aile1, r1)
			# l'occlusion : sombre près du tronc, clair au bout
			var c := ao_base if i == 0 else ao
			_quad_o(st, [p0, p1, p1 + aile1, p0 + aile],
				[_uv(region, 0.5, vs[i]), _uv(region, 0.5, vs[i + 1]), _uv(region, u_bord, vs[i + 1]), _uv(region, u_bord, vs[i])],
				c, [n0, n1, n1b, n0b], face)
		if crete > 0.0:
			var h := Vector3.UP * crete * (1.0 if i == 0 else 0.75)
			var b0 := p0 + Vector3.UP * 0.02
			var b1 := p1 + Vector3.UP * 0.02
			var nn := (_n_feuillage(p1, r_ou(p1)) + Vector3.UP).normalized()
			var col := Color(1, 1, 1, 0)
			var u0 := 0.5 * i
			_quad_o(st, [b0, b1, b1 + h, b0 + h],
				[_uv(crete_v, u0, 1.0), _uv(crete_v, u0 + 0.5, 1.0), _uv(crete_v, u0 + 0.5, 0.0), _uv(crete_v, u0, 0.0)],
				col, [nn, nn, nn, nn], cote)

static func r_ou(v: Vector3) -> float:
	return Vector3(v.x, 0, v.z).length() + 0.3

## Tronc à écorce pixel art : UV à 16 texels/m (tuile 32 px = 2 m), évasé au pied, neige au pied
## (alpha de sommet 0 = neige de `tex_neige`), mousse côté nord (teinte verdâtre sur le bas).
static func _tronc_ecorce(st: SurfaceTool, rng: RandomNumberGenerator, rayon: float, hauteur: float, cotes := 6) -> void:
	var anneaux := [[-0.5, 1.6], [0.12, 1.2], [1.2, 1.0], [hauteur, 0.3]]
	var tour := TAU * rayon / 2.0   # périmètre en tuiles de 2 m
	var neige_cote: Array[float] = []
	for k in cotes + 1:
		neige_cote.append(0.0 if rng.randf() < 0.3 else 1.0)
	neige_cote[cotes] = neige_cote[0]
	for k in cotes:
		var a0 := TAU * k / cotes
		var a1 := TAU * (k + 1) / cotes
		for j in anneaux.size() - 1:
			var y0: float = anneaux[j][0]
			var y1: float = anneaux[j + 1][0]
			var s0: float = anneaux[j][1]
			var s1: float = anneaux[j + 1][1]
			var p := [Vector3(cos(a0) * rayon * s0, y0, sin(a0) * rayon * s0), Vector3(cos(a1) * rayon * s0, y0, sin(a1) * rayon * s0),
				Vector3(cos(a1) * rayon * s1, y1, sin(a1) * rayon * s1), Vector3(cos(a0) * rayon * s1, y1, sin(a0) * rayon * s1)]
			var u0 := tour * k / cotes
			var u1 := tour * (k + 1) / cotes
			var uv := [Vector2(u0, -y0 / 2.0), Vector2(u1, -y0 / 2.0), Vector2(u1, -y1 / 2.0), Vector2(u0, -y1 / 2.0)]
			var cols: Array[Color] = []
			for q in 4:
				var ak := k + (1 if q == 1 or q == 2 else 0)
				var yq: float = y0 if q < 2 else y1
				var aq := TAU * ak / cotes
				var c := Color(1, 1, 1, 1)
				if yq < 0.0:
					c.a = 0.0 if neige_cote[ak] < 0.5 else 0.6   # 0.6 : la neige s'arrête juste au-dessus du sol
				elif yq < 0.5:
					c.a = neige_cote[ak] * 0.4 + 0.6
				if yq < 1.5 and sin(aq) < -0.3:   # nord = -Z : mousse
					c = Color(0.78, 0.95, 0.8, c.a)
				if yq < 1.5:
					c = Color(c.r * 0.82, c.g * 0.82, c.b * 0.82, c.a)
				cols.append(c)
			for t in [[0, 1, 2], [0, 2, 3]]:
				var centre := Vector3(0, (p[t[0]].y + p[t[1]].y + p[t[2]].y) / 3.0, 0)
				var face: Vector3 = (p[t[0]] + p[t[1]] + p[t[2]]) / 3.0 - centre
				var aa: Vector3 = p[t[0]]
				var bb: Vector3 = p[t[1]]
				var cc: Vector3 = p[t[2]]
				var ia: int = t[0]
				var ib: int = t[1]
				var ic: int = t[2]
				if (bb - aa).cross(cc - aa).dot(face) < 0.0:
					var tmp := ib; ib = ic; ic = tmp
				for idx in [ia, ib, ic]:
					var v: Vector3 = p[idx]
					st.set_color(cols[idx])
					st.set_normal(Vector3(v.x, 0.15, v.z).normalized())
					st.set_uv(uv[idx])
					st.add_vertex(v)

static func _forme_epicea(forme: int) -> Dictionary:
	return {
		"hauteur": [9.5, 7.5, 5.0][forme],
		"base": [2.3, 2.9, 1.7][forme],
		"etages": [10, 9, 6][forme],
		"bas": [1.3, 0.9, 0.8][forme],
		"tronc": [0.2, 0.22, 0.13][forme],
	}

## Fût d'épicéa : 8 pans (4 au loin), évasé en contreforts, chicots sous la jupe de branches.
static func _fut_epicea(st: SurfaceTool, graine: int, r: float, H: float, bas: float, lod: bool) -> void:
	var rt := RandomNumberGenerator.new()
	rt.seed = graine * 31 + 7
	var ys: Array = [-0.5, 0.3, 1.4, H] if lod else [-0.5, 0.1, 1.2, H * 0.55, H]
	var fl: Array = [1.7, 1.05, 1.0, 0.35] if lod else [1.75, 1.3, 1.02, 0.72, 0.35]
	var an: Array = []
	for i in ys.size():
		an.append([ys[i], r * fl[i], 0.0, 0.0])
	var ao := func(y: float) -> float:
		if y < 0.0:
			return 0.45
		if y < 1.0:
			return lerpf(0.52, 0.8, y)
		return lerpf(0.74, 0.95, clampf((y - 1.0) / (H - 1.0), 0.0, 1.0))
	_fut(st, rt, an, 4 if lod else 6, {"pied": Vector2(0.35, 1.7), "ao": ao, "mousse": 1.0, "vent": 0.5})
	if not lod:
		_racines(st, rt, 4, r, 0.0, 0.0, 0.85, 1.15, true)
		_congere(st, rt, 6, r, 0.0, 0.0)

## Épicéa : `forme` 0 élancé, 1 large et touffu, 2 jeune et clairsemé. Squelette (hauteur, largeur,
## étages) identique à l'ancien modèle ; le feuillage est fait de cartes de rameaux en pixel art
## (une carte pliée par branche, orientée selon la branche), avec du ciel entre les étages.
## `lod` vrai : version lointaine (moitié des étages, 4 branches d'un seul tronçon, tronc 3 pans, sans crête).
## Surfaces : 0 tronc (ps1), 1 rameaux (ps1_rameau). N'utilise que son propre RNG (graine).
static func epicea(forme: int, graine: int, materiaux: Array, lod := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var f := _forme_epicea(forme)
	var hauteur: float = f["hauteur"]
	var base: float = f["base"]
	var etages: int = f["etages"]
	var bas: float = f["bas"]
	var tronc := SurfaceTool.new()
	tronc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rameaux := SurfaceTool.new()
	rameaux.begin(Mesh.PRIMITIVE_TRIANGLES)
	# le fût n'utilise plus `rng` (silhouette inchangée) : on consomme les mêmes tirages que l'ancien tronc
	for _i in (4 if lod else 7):
		rng.randf()
	_fut_epicea(tronc, graine, f["tronc"], hauteur * 0.88, bas, lod)
	var pli: float = REGLAGES_EPICEA["pli"]
	var crete: float = 0.0 if lod else REGLAGES_EPICEA["crete"]
	var longs := [TexturesArbres.uv_epicea(TexturesArbres.R_LONG_A), TexturesArbres.uv_epicea(TexturesArbres.R_LONG_B)]
	var courts := [TexturesArbres.uv_epicea(TexturesArbres.R_COURT_A), TexturesArbres.uv_epicea(TexturesArbres.R_COURT_B)]
	var n_etages := maxi(4, etages / 2) if lod else etages
	# jupe basse : petits rameaux courts et pendants sous le premier étage (plus de tronc nu sous la couronne)
	for e in (1 if lod else 3):
		var yj := lerpf(0.55, bas + 0.55, float(e) / 2.0) if not lod else 0.9
		var rj := base * lerpf(0.4, 0.62, float(e) / 2.0)
		var nj := 4 if lod else 6
		var rotj := rng.randf() * TAU
		var aoj := Color(0.62 + 0.1 * e, 0.62 + 0.1 * e, 0.64 + 0.1 * e, 1.0)
		for b in nj:
			var a := rotj + TAU * (b + rng.randf_range(-0.2, 0.2)) / nj
			var Lj := rj * rng.randf_range(0.8, 1.1)
			var cj := TexturesArbres.uv_epicea(TexturesArbres.R_COURT_A if rng.randf() < 0.5 else TexturesArbres.R_COURT_B)
			_rameau(rameaux, Vector3(cos(a) * 0.08, yj + rng.randf_range(-0.1, 0.1), sin(a) * 0.08), a, Lj, Lj * rng.randf_range(0.2, 0.32), 0.0, cj, pli * 1.0, aoj, 0.0, Rect2(), 1)
	for e in n_etages:
		var k := float(e) / (n_etages - 1)
		# étages plus serrés vers la flèche (la pointe de l'épicéa est dense, le bas aéré)
		var y := lerpf(bas + 0.9, hauteur - 0.3, 1.0 - pow(1.0 - k, 1.3))
		var rayon := base * (1.0 - k * 0.85) * rng.randf_range(0.92, 1.06)
		var n := (5 + rng.randi_range(0, 1)) if lod else (9 - int(k * 4.0) + rng.randi_range(0, 1) + (1 if forme == 1 else 0))
		var rot := rng.randf() * TAU
		# occlusion : étages du bas plus sombres (sous la couronne)
		var ao_v := lerpf(0.72, 1.0, pow(k, 0.7))
		var ao := Color(ao_v, ao_v, ao_v, 1.0)
		for b in n:
			var a := rot + TAU * (b + rng.randf_range(-0.22, 0.22)) / n
			var L := rayon * rng.randf_range(0.85, 1.1) * (1.15 if lod else 1.0)
			# les étages du bas tombent, ceux du haut se redressent (flèche de l'épicéa)
			var chute := L * lerpf(0.17, -0.05, pow(k, 1.1)) * rng.randf_range(0.8, 1.2)
			var releve := L * 0.05 * (1.0 - k)
			var o := Vector3(cos(a) * 0.08, y + rng.randf_range(-0.12, 0.12), sin(a) * 0.08)
			var region: Rect2 = (longs if L > 1.3 else courts)[rng.randi_range(0, 1)]
			var cv := TexturesArbres.uv_epicea(Rect2i(TexturesArbres.R_CRETE_X, TexturesArbres.R_CRETE_Y + TexturesArbres.CRETE_H * rng.randi_range(0, TexturesArbres.CRETES - 1), TexturesArbres.CRETE_W, TexturesArbres.CRETE_H))
			# ailes plus tombantes en bas (rameaux pendants de l'épicéa), plus plates en haut
			var pli_b := pli * lerpf(0.9, 0.8, k) * rng.randf_range(0.85, 1.15)
			_rameau(rameaux, o, a, L, chute, releve, region, pli_b, ao, crete * rng.randf_range(0.7, 1.2) if L > 0.8 else 0.0, cv, 1 if lod else 2)
	# flèche : deux cartes verticales croisées
	var fr := TexturesArbres.uv_epicea(TexturesArbres.R_FLECHE)
	var hf := 2.2
	var lf := 1.3
	var y0 := hauteur - 1.2
	var col := Color(1, 1, 1, 0)
	var nn := Vector3.UP
	for q in 2:
		var a := rng.randf() * PI if q == 0 else 0.0
		var dd := Vector3(cos(a + q * PI * 0.5), 0, sin(a + q * PI * 0.5)) * lf * 0.5
		_quad_o(rameaux, [Vector3(0, y0, 0) - dd, Vector3(0, y0, 0) + dd, Vector3(0, y0 + hf, 0) + dd, Vector3(0, y0 + hf, 0) - dd],
			[_uv(fr, 0, 1), _uv(fr, 1, 1), _uv(fr, 1, 0), _uv(fr, 0, 0)], col, [nn, nn, nn, nn], dd.cross(Vector3.UP))
	var mesh := ArrayMesh.new()
	var surfaces := [tronc, rameaux]
	for i in 2:
		var st: SurfaceTool = surfaces[i]
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[i])
	return mesh

## Silhouette d'ombre de l'épicéa (MMI « ombre seule », jusqu'à 50 m) : étages en étoile opaques (~130
## triangles) aux mêmes hauteurs et rayons que les cartes. Les cartes en alpha coûtaient ~3 ms GPU
## dans la passe d'ombre (mesure au feu) ; l'ombre portée au sol reste celle d'un sapin à étages.
static func epicea_ombre(forme: int, graine: int, materiau: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + 7
	var f := _forme_epicea(forme)
	var hauteur: float = f["hauteur"]
	var base: float = f["base"]
	var bas: float = f["bas"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vide := SurfaceTool.new()
	vide.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tronc(st, f["tronc"], hauteur * 0.88, 3)
	var n := 6
	for e in n:
		var k := float(e) / (n - 1)
		var y := lerpf(bas + 0.9, hauteur - 0.3, 1.0 - pow(1.0 - k, 1.3))
		var rayon := base * (1.0 - k * 0.85)
		_etage(st, vide, rng, y, rayon, rayon * lerpf(0.42, 0.1, k) + 0.3, 7, rng.randf() * TAU, 0.0)
	_etage(st, vide, rng, hauteur + 0.6, 0.35, 1.2, 4, 0.0, 0.0)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, materiau)
	return mesh

## Épicéa lointain (LOD 85-250 m) : voir `epicea(..., lod = true)`.
static func epicea_lointain(forme: int, graine: int, materiaux: Array) -> ArrayMesh:
	return epicea(forme, graine, materiaux, true)

# --- Lot 2 : bois (branches en prismes), pin sylvestre, bouleau d'hiver, arbre mort -----------------

## Branche en prisme effilé de `p0` (rayon r0) à `p1` (rayon r1), `cotes` pans, UV d'écorce à 16 texels/m
## (tuile 32 px = 2 m). Neige sur le dessus : l'arête du haut a l'alpha de sommet 0 (ps1 : 0 = neige),
## si `neige` est vrai. `col` : teinte de sommet (occlusion). Renvoie rien ; écrit dans `st`.
static func _bois(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, cotes: int, col: Color, neige: bool, v0 := 0.0, pied := 0.0, mousse := 0.0) -> void:
	var axe := p1 - p0
	var L := axe.length()
	if L < 0.001:
		return
	axe /= L
	var u := axe.cross(Vector3.UP)
	if u.length() < 0.1:
		u = axe.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := u.cross(axe).normalized()   # vers le haut
	if v.y < 0.0:
		v = -v
		u = -u
	var tour := TAU * maxf(r0, 0.03) / 2.0
	var miroir := cotes % 2 == 0
	for k in cotes:
		var a0 := TAU * k / cotes
		var a1 := TAU * (k + 1) / cotes
		var d0 := v * cos(a0) + u * sin(a0)
		var d1 := v * cos(a1) + u * sin(a1)
		var q := [p0 + d0 * r0, p0 + d1 * r0, p1 + d1 * r1, p1 + d0 * r1]
		var ua := tour * 0.5 * _tri_u(k, cotes) if miroir else tour * k / cotes
		var ub := tour * 0.5 * _tri_u(k + 1, cotes) if miroir else tour * (k + 1) / cotes
		var uv := [Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v0 - L / 2.0), Vector2(ua, v0 - L / 2.0)]
		var c0 := col
		var c1 := col
		if neige:
			c0.a = 0.0 if k == 0 else 1.0           # arête du haut (a0 = 0) : neige
			c1.a = 0.0 if k + 1 == cotes else 1.0
		var cs := [c0, c1, c1, c0]
		var ns := [d0, d1, d1, d0]
		var face := (d0 + d1) * 0.5
		var aux := Vector2(pied, mousse)
		for t in [[0, 1, 2], [0, 2, 3]]:
			var ia: int = t[0]
			var ib: int = t[1]
			var ic: int = t[2]
			if (q[ib] - q[ia]).cross(q[ic] - q[ia]).dot(face) < 0.0:
				var tmp := ib; ib = ic; ic = tmp
			for idx in [ia, ib, ic]:
				st.set_color(cs[idx]); st.set_normal(ns[idx]); st.set_uv(uv[idx]); st.set_uv2(aux); st.add_vertex(q[idx])

## Ligne brisée de bois : points `pts`, rayons interpolés de r0 à r1.
static func _bois_chaine(st: SurfaceTool, pts: Array, r0: float, r1: float, cotes: int, col: Color, neige: bool) -> void:
	var n := pts.size() - 1
	var v := 0.0
	for i in n:
		var ra := lerpf(r0, r1, float(i) / n)
		var rb := lerpf(r0, r1, float(i + 1) / n)
		_bois(st, pts[i], pts[i + 1], ra, rb, cotes, col, neige, v)
		v -= (pts[i + 1] - pts[i]).length() / 2.0

## Branche tordue : part de `o` dans la direction `d`, `n` tronçons, chaque tronçon dévie au hasard.
static func _chemin_tordu(rng: RandomNumberGenerator, o: Vector3, d: Vector3, L: float, n: int, torsion: float, gravite := 0.0) -> Array:
	var pts := [o]
	var p := o
	var dir := d.normalized()
	for i in n:
		dir = (dir + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * torsion + Vector3.DOWN * gravite).normalized()
		p += dir * L / n
		pts.append(p)
	return pts

static var _mats_essences := {}
## Matériaux partagés : "pin" [écorce, rameaux], "bouleau" [écorce, ramilles], "mort" [bois].
static func materiaux_essence(nom: String) -> Array:
	if not _mats_essences.has(nom) or not is_instance_valid(_mats_essences[nom][0]):
		match nom:
			"pin":
				_mats_essences[nom] = [materiau_tronc("pin_haut", "pin_pied", Color(1.05, 1.0, 1.02), 0.25),
					materiau_rameau(TexturesArbres.atlas_pin(), Color(1.15, 1.22, 1.25))]
			"bouleau":
				_mats_essences[nom] = [materiau_tronc("bouleau_haut", "bouleau_pied", Color(0.95, 0.95, 1.0), 0.3),
					materiau_rameau(TexturesArbres.atlas_bouleau(), Color(1.1, 1.1, 1.1))]
			"mort":
				_mats_essences[nom] = [materiau_tronc("mort_haut", "mort_pied", Color(1.0, 1.0, 1.0), 0.6)]
	return _mats_essences[nom]

static func _commit(surfaces: Array, mats: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in surfaces.size():
		var st: SurfaceTool = surfaces[i]
		st.commit(mesh)
		mesh.surface_set_material(i, mats[i])
	return mesh

static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

## Pin sylvestre (buttes sèches) : haut fût droit, écorce orangée en haut et grise au pied, chicots des
## branches tombées, couronne haute et irrégulière de grosses branches relevées portant des houppes
## d'aiguilles (cartes de rameaux de pin pliées en toit). Surfaces : 0 bois (ps1), 1 houppes (ps1_rameau).
## Fût du pin : 8 pans à travers les points `fut` (sinueux), racines, chicots ; écorce du pied jusqu'à ~3 m.
static func _fut_pin(st: SurfaceTool, graine: int, fut: Array, H: float, lod := false) -> void:
	var rt := RandomNumberGenerator.new()
	rt.seed = graine * 17 + 3
	var an: Array = [[-0.5, 0.17 * 1.9, 0.0, 0.0], [0.0, 0.17 * 1.45, 0.0, 0.0], [0.6, 0.17 * 1.15, 0.0, 0.0], [1.5, 0.165, 0.0, 0.0]]
	var y_prec := 1.5
	for i in range(1, 5):
		var pf: Vector3 = fut[i]
		var rad := lerpf(0.17, 0.05, float(i) / 4.0)
		# un anneau intermédiaire entre chaque point du fût (fût moins anguleux)
		var pm: Vector3 = (fut[i] as Vector3).lerp(fut[i - 1], 0.5)
		if pm.y > y_prec + 0.3:
			an.append([pm.y, lerpf(0.17, 0.05, (i - 0.5) / 4.0), pm.x, pm.z])
		an.append([pf.y, rad, pf.x, pf.z])
		y_prec = pf.y
	var ao := func(y: float) -> float:
		if y < 0.0:
			return 0.45
		if y < 1.2:
			return lerpf(0.5, 0.82, y / 1.2)
		return 0.95 if y < H * 0.5 else lerpf(0.95, 0.7, clampf((y - H * 0.5) / (H * 0.4), 0.0, 1.0))
	_fut(st, rt, an, 4 if lod else 6, {"pied": Vector2(0.9, 2.8), "ao": ao, "mousse": 0.7, "vent": 0.6, "irr": 0.06})
	if not lod:
		_racines(st, rt, 5, 0.17, 0.0, 0.0, 1.15, 1.5)
		_congere(st, rt, 8, 0.17, 0.0, 0.0, 1.4)

static func pin(graine: int, mats: Array, lod := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bois := _st()
	var houppes := _st()
	var H := rng.randf_range(10.5, 12.0)
	var region := TexturesArbres.uv_region(TexturesArbres.R_PIN)
	var vide := Rect2()
	# fût légèrement sinueux, gris au pied, orangé au-dessus de 3 m
	var fut := [Vector3(0, -0.5, 0)]
	for i in 4:
		var y := H * (i + 1) / 4.0
		fut.append(Vector3(rng.randf_range(-0.12, 0.12), y, rng.randf_range(-0.12, 0.12)))
	_fut_pin(bois, graine, fut, H, lod)
	# chicots (branches mortes cassées) sur le fût
	for i in 5:
		var y := rng.randf_range(2.5, H * 0.6)
		var a := rng.randf() * TAU
		var o := Vector3(0, y, 0)
		_bois(bois, o, o + Vector3(cos(a), rng.randf_range(-0.2, 0.3), sin(a)) * rng.randf_range(0.25, 0.6), 0.04, 0.015, 3, Color(0.7, 0.66, 0.7), true)
	# couronne : grosses branches relevées, houppes au bout et sur les côtés
	var n := rng.randi_range(10, 12)
	for b in n:
		var k := float(b) / (n - 1)
		var y := lerpf(H * 0.55, H * 0.93, k)
		var a := TAU * b * 0.382 + rng.randf_range(-0.3, 0.3)   # angle d'or : couronne irrégulière
		var L := lerpf(2.6, 1.0, k) * rng.randf_range(0.8, 1.15)
		var elev := deg_to_rad(rng.randf_range(20, 45))
		var d := Vector3(cos(a) * cos(elev), sin(elev), sin(a) * cos(elev))
		var o := Vector3(fut[3].x * (y / H), y, fut[3].z * (y / H))
		var pts := _chemin_tordu(rng, o, d, L, 3, 0.25)
		_bois_chaine(bois, pts, 0.07, 0.025, 6, Color(1, 1, 1), true)
		var bout: Vector3 = pts[3]
		# houppes : une dans le prolongement, trois sur les côtés
		for h in 4:
			var decale: float = [0.0, 0.7, -0.7, 0.2][h]
			var ah := a + decale + rng.randf_range(-0.2, 0.2)
			var p: Vector3 = bout if h == 0 else (pts[2] if h < 3 else pts[1])
			var Lh := rng.randf_range(1.4, 1.9) * (1.0 if h == 0 else 0.8)
			_rameau(houppes, p, ah, Lh, -Lh * rng.randf_range(0.05, 0.3), 0.0, region, 0.45, Color(0.95, 0.95, 0.95), 0.0, vide, 2)
	# sommet : bouquet de houppes dressées
	var top: Vector3 = fut[4]
	for h in 4:
		var ah := TAU * h / 4.0 + rng.randf_range(-0.3, 0.3)
		_rameau(houppes, top + Vector3(0, -0.3, 0), ah, 1.1, -0.5, 0.0, region, 0.5, Color(1, 1, 1), 0.0, vide, 2)
	return _commit([bois, houppes], mats)

## Bouleau d'hiver (zones humides) : tronc blanc fin à marques noires, pied sombre, branches nues
## montantes qui s'arquent, voile de ramilles pendantes violacées (cartes verticales).
## Surfaces : 0 bois (ps1), 1 ramilles (ps1_rameau, sans dessous distinct).
## Fût du bouleau : 8 pans, blanc à lenticelles, pied crevassé sombre jusqu'à ~1,2 m, petits contreforts.
static func _fut_bouleau(st: SurfaceTool, graine: int, fut: Array, H: float, lod := false) -> void:
	var rt := RandomNumberGenerator.new()
	rt.seed = graine * 13 + 5
	var an: Array = [[-0.5, 0.16 * 1.7, 0.0, 0.0], [0.0, 0.16 * 1.35, 0.0, 0.0], [0.5, 0.16 * 1.1, 0.0, 0.0]]
	var y_prec := 0.5
	for i in range(1, 5):
		var pf: Vector3 = fut[i]
		var pm: Vector3 = (fut[i] as Vector3).lerp(fut[i - 1], 0.5)
		if pm.y > y_prec + 0.3:
			an.append([pm.y, lerpf(0.16, 0.04, (i - 0.5) / 4.0), pm.x, pm.z])
		an.append([pf.y, lerpf(0.16, 0.04, float(i) / 4.0), pf.x, pf.z])
		y_prec = pf.y
	var ao := func(y: float) -> float:
		if y < 0.0:
			return 0.5
		return lerpf(0.62, 0.98, clampf(y / 1.5, 0.0, 1.0))
	_fut(st, rt, an, 4 if lod else 6, {"pied": Vector2(0.5, 1.5), "ao": ao, "mousse": 0.3, "vent": 0.5, "irr": 0.05})
	if not lod:
		_racines(st, rt, 3, 0.16, 0.0, 0.0, 0.7, 0.85)

static func bouleau(graine: int, mats: Array, lod := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bois := _st()
	var ramilles := _st()
	var H := rng.randf_range(7.5, 9.0)
	var penche := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var fut := [Vector3(0, -0.5, 0)]
	for i in 4:
		var t := (i + 1) / 4.0
		fut.append(penche * t * t + Vector3(rng.randf_range(-0.08, 0.08), H * t, rng.randf_range(-0.08, 0.08)))
	_fut_bouleau(bois, graine, fut, H, lod)
	var region := TexturesArbres.uv_region(Rect2i(0, 0, 64, 64))
	var n := rng.randi_range(9, 12)
	for b in n:
		var k := float(b) / (n - 1)
		var y := lerpf(H * 0.32, H * 0.92, k)
		var a := TAU * b * 0.382 + rng.randf_range(-0.4, 0.4)
		var L := lerpf(2.8, 1.2, k) * rng.randf_range(0.8, 1.1)
		var elev := deg_to_rad(rng.randf_range(40, 65))
		var o: Vector3 = fut[1].lerp(fut[4], (y - fut[1].y) / (fut[4].y - fut[1].y))
		var d := Vector3(cos(a) * cos(elev), sin(elev), sin(a) * cos(elev))
		# la branche monte puis s'arque vers le bas (gravité croissante)
		var pts := [o]
		var p := o
		var dir := d
		for i in 4:
			dir = (dir + Vector3.DOWN * 0.22 * i + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))).normalized()
			p += dir * L / 4.0
			pts.append(p)
		_bois_chaine(bois, pts, 0.045, 0.012, 3, Color(0.95, 0.95, 0.98), true)
		# ramilles : 2 cartes pendantes le long de la moitié extérieure de la branche
		for c in 1:
			var p0: Vector3 = pts[2]
			var p1: Vector3 = pts[4]
			var haut := (p1 - p0)
			var long := haut.length() * 1.3
			var dirh := haut.normalized()
			var chute := Vector3.DOWN * long * rng.randf_range(0.6, 0.85) + Vector3(cos(a), 0, sin(a)) * 0.2
			var q := [p0, p0 + dirh * long, p0 + dirh * long + chute, p0 + chute]
			var nn := _n_feuillage(p1, 2.0)
			var col := Color(1, 1, 1, 0)
			_quad_o(ramilles, q, [_uv(region, 0, 0), _uv(region, 1, 0), _uv(region, 1, 1), _uv(region, 0, 1)], col, [nn, nn, nn, nn], dirh.cross(Vector3.UP))
	return _commit([bois, ramilles], mats)

## Arbre mort : fût gris argenté sans écorce, sommet cassé, branches tordues lisibles (prismes à 2-3
## tronçons qui dévient), quelques rameaux secondaires et moignons cassés, givre sur le dessus de chaque
## branche (alpha de sommet → neige du shader ps1). Une seule surface (bois).
## `materiaux` est gardé pour compatibilité avec les appelants (forêt, sous-bois, zones) : le bois mort
## utilise toujours la texture pixel art partagée `materiaux_essence("mort")`.
## Fût de l'arbre mort : 8 pans le long de la ligne brisée `fut`, évasé, racines exposées, chicots, fentes.
static func _fut_mort(st: SurfaceTool, graine: int, fut: Array, lod := false) -> void:
	var rt := RandomNumberGenerator.new()
	rt.seed = graine * 19 + 11
	var an: Array = []
	var n := fut.size()
	var pre: Vector3 = fut[0]
	an.append([pre.y, 0.24 * 1.9, pre.x, pre.z])
	for i in range(1, n):
		var a: Vector3 = fut[i - 1]
		var b: Vector3 = fut[i]
		if i == 1:
			var m := a.lerp(b, 0.28)
			an.append([m.y, 0.24 * 1.45, m.x, m.z])
		var m2 := a.lerp(b, 0.6) if i > 1 else a.lerp(b, 0.6)
		an.append([m2.y, lerpf(0.24, 0.08, (i - 0.4) / (n - 1.0)), m2.x, m2.z])
		an.append([b.y, lerpf(0.24, 0.08, float(i) / (n - 1.0)), b.x, b.z])
	var ao := func(y: float) -> float:
		if y < 0.0:
			return 0.5
		return lerpf(0.6, 1.0, clampf(y / 2.0, 0.0, 1.0))
	_fut(st, rt, an, 4 if lod else 6, {"pied": Vector2(0.3, 1.2), "ao": ao, "mousse": 0.6, "vent": 0.65, "irr": 0.1})
	if lod:
		return
	_racines(st, rt, 4, 0.24, (fut[0] as Vector3).x, (fut[0] as Vector3).z, 0.9, 1.0)
	_chicots(st, rt, 5, 0.9, 3.8, 0.04, 0.0, 0.0, 0.2)

static func arbre_mort(graine: int, materiaux: Array = [], lod := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bois := _st()
	var H := rng.randf_range(5.0, 6.4)
	var fut := _chemin_tordu(rng, Vector3(0, -0.5, 0), Vector3.UP, H + 0.5, 4, 0.12)
	_fut_mort(bois, graine, fut, lod)
	# sommet cassé : éclat pointu de travers
	var top: Vector3 = fut[4]
	_bois(bois, top, top + Vector3(rng.randf_range(-0.15, 0.15), 0.55, rng.randf_range(-0.15, 0.15)), 0.08, 0.01, 4, Color(0.9, 0.9, 0.9), false)
	var n := rng.randi_range(6, 9)
	for b in n:
		var k := float(b) / (n - 1)
		var t := lerpf(0.35, 0.92, k)
		var i := mini(int(t * 4.0), 3)
		var o: Vector3 = fut[i].lerp(fut[i + 1], t * 4.0 - i)
		var a := TAU * b * 0.382 + rng.randf_range(-0.5, 0.5)
		var elev := deg_to_rad(rng.randf_range(5, 50))
		var casse := rng.randf() < 0.2
		var L := lerpf(2.8, 1.3, k) * rng.randf_range(0.75, 1.15) * (0.35 if casse else 1.0)
		var d := Vector3(cos(a) * cos(elev), sin(elev), sin(a) * cos(elev))
		var pts := _chemin_tordu(rng, o, d, L, 1 if casse else 3, 0.6)
		_bois_chaine(bois, pts, 0.09, 0.025 if not casse else 0.06, 6, Color(0.95, 0.95, 0.95), true)
		if not casse:
			# rameaux secondaires tordus
			for s in rng.randi_range(2, 3):
				var p: Vector3 = pts[rng.randi_range(1, 2)]
				var d2 := (d + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(0.0, 0.8), rng.randf_range(-0.9, 0.9))).normalized()
				_bois_chaine(bois, _chemin_tordu(rng, p, d2, L * 0.45, 2, 0.5), 0.035, 0.01, 3, Color(0.9, 0.9, 0.9), true)
	return _commit([bois], materiaux_essence("mort"))

## Petit genévrier bas, à moitié sous la neige (couvre-sol). Lot 2 : rameaux en cartes pixel art comme
## l'épicéa (une seule surface, matériau `materiaux_epicea()[1]`) ; `materiaux` gardé pour compatibilité.
static func buisson(graine: int, materiaux: Array = []) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var st := _st()
	var courts := [TexturesArbres.uv_epicea(TexturesArbres.R_COURT_A), TexturesArbres.uv_epicea(TexturesArbres.R_COURT_B)]
	for i in 3:
		var y := 0.5 + i * 0.13
		var r := rng.randf_range(0.55, 0.85) * (1.0 - i * 0.2)
		var n := 7 - i
		var rot := rng.randf() * TAU
		var ao := Color(0.75 + i * 0.1, 0.75 + i * 0.1, 0.75 + i * 0.1, 1.0)
		for b in n:
			var a := rot + TAU * (b + rng.randf_range(-0.2, 0.2)) / n
			_rameau(st, Vector3(0, y, 0), a, r, r * 0.45, 0.0, courts[rng.randi_range(0, 1)], 0.85, ao, 0.0, Rect2(), 1)
	return _commit([st], [materiaux_epicea()[1]])

## Semis (lot E) : jeune épicéa de sous-bois, ~60 cm. Lot 2 : trois petits étages de rameaux en cartes et
## une flèche (une seule surface, matériau `materiaux_epicea()[1]`) ; `materiaux` gardé pour compatibilité.
static func semis(graine: int, materiaux: Array = []) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var st := _st()
	var courts := [TexturesArbres.uv_epicea(TexturesArbres.R_COURT_A), TexturesArbres.uv_epicea(TexturesArbres.R_COURT_B)]
	for e in 3:
		var k := e / 2.0
		var y := lerpf(0.3, 0.75, k)
		var r := lerpf(0.45, 0.2, k)
		var n := 5 - e
		var rot := rng.randf() * TAU
		for b in n:
			var a := rot + TAU * (b + rng.randf_range(-0.2, 0.2)) / n
			_rameau(st, Vector3(0, y, 0), a, r, r * lerpf(0.4, 0.1, k), 0.0, courts[rng.randi_range(0, 1)], 0.7, Color(0.85 + 0.15 * k, 0.85 + 0.15 * k, 0.85 + 0.15 * k, 1.0), 0.0, Rect2(), 1)
	var fr := TexturesArbres.uv_epicea(TexturesArbres.R_FLECHE)
	var nn := Vector3.UP
	for q in 2:
		var dd := Vector3(cos(q * PI * 0.5), 0, sin(q * PI * 0.5)) * 0.15
		_quad_o(st, [Vector3(0, 0.55, 0) - dd, Vector3(0, 0.55, 0) + dd, Vector3(0, 0.95, 0) + dd, Vector3(0, 0.95, 0) - dd],
			[_uv(fr, 0, 1), _uv(fr, 1, 1), _uv(fr, 1, 0), _uv(fr, 0, 0)], Color(1, 1, 1, 0), [nn, nn, nn, nn], dd.cross(Vector3.UP))
	return _commit([st], [materiaux_epicea()[1]])
