class_name ChasseresseNordique
## Chasseresse nordique (refonte persos, ÉTAPE 4, d'après le Guerrier pilote validé : branche refonte/persos_chasseresse).
##
## Référence : Image ChatGPT 21 oct. 2026, 14_01_57-2.png — chasseresse blonde à deux longues tresses, grand col de fourrure,
## cape vert-bleu sombre, jaque de cuir à écailles, baudrier et ceinture à boucle, jupe de cuir frangée de fourrure et tabard
## sarcelle, brassards lacés, pantalon olive, bottes lacées à revers de fourrure, arc long, carquois dans le dos, couteau.
##
## MÊME recette que GuerrierNordique (dont les outils sont APPELÉS, rien n'y est modifié) : base Humain.creer (corps FEMME
## Quaternius, 65 os, mêmes animations et ragdoll), matières peintes à 128 texels/m (ChasseresseTextures + matières communes de
## GuerrierTextures : fourrure, bottes, fer), fourrure en mèches géométriques, accessoires modelés (arc, carquois et flèches,
## couteau, tresses, baudrier, boucle, fibule), contour par coque, shader ps1_perso (liseré froid), budget <= 7 500 triangles et
## <= 10 surfaces visibles.
##
##   ChasseresseNordique.creer({"arc": true, "carquois": true, "couteau": true}) -> Node3D
## Contrat identique à Humain.creer : nœud racine -> Skeleton3D + AnimationPlayer « Animations », mêmes os.
##
## Posture d'archer : clips existants Pistol_Aim_Neutral (visée) et Pistol_Shoot (tir), comme le bandit archer (draugr.gd) :
## l'arc est alors tenu VERTICAL bras tendu dans la main droite (« arc_vise ») ; hors de ces clips, il est porté le long du corps
## dans la main gauche (« arc_porte »). L'échange se fait tout seul au changement de clip (signal de l'AnimationPlayer).

const PEAU := Color(0.96, 0.86, 0.80)

static var _mats := {}

static func vider() -> void:
	_mats.clear()
	ChasseresseTextures.vider_tout()

## Clips de la posture d'archer (l'arc passe dans la main droite, tendu à la verticale).
static func clip_de_visee(nom: String) -> bool:
	return nom.begins_with("Pistol")

static var chrono := false

static func _t(etape: String, t0: int) -> void:
	if chrono:
		print("CHASSERESSE %-26s %7.1f ms" % [etape, (Time.get_ticks_usec() - t0) / 1000.0])

# ======================================================================================================== fabrique
static func creer(options := {}) -> Node3D:
	var C := Color.WHITE
	var app := {"corps": "femme", "cheveux": "Hair_Long", "teinte_cheveux": Color(0.85, 0.72, 0.5), "peau": PEAU,
		"tenue": {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "brassards": C, "cape": C, "mante": C}}
	var t0 := Time.get_ticks_usec()
	var racine := Humain.creer(app)
	_t("Humain.creer", t0)
	racine.name = "ChasseresseNordique"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var pieces := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		pieces[String(mi.name)] = mi
	# -- vêtements : matières de la chasseresse (jaque, pantalon olive, brassards lacés) et communes (bottes, fourrure)
	_habiller(pieces["tunique"], GuerrierNordique.materiau(ChasseresseTextures.tex("jaque")))
	_habiller(pieces["pantalon"], GuerrierNordique.materiau(ChasseresseTextures.tex("pantalon")))
	_habiller(pieces["bottes"], GuerrierNordique.materiau(GuerrierTextures.tex("bottes")))
	_habiller(pieces["brassards"], GuerrierNordique.materiau(ChasseresseTextures.tex("brassards")))
	_habiller(pieces["mante"], GuerrierNordique.materiau(GuerrierTextures.tex("mante")))
	for nom in ["Superhero_Female", "SuperHero_Female"]:
		if pieces.has(nom):
			pieces[nom].visible = false
	_peau(pieces)
	# allègement (comme le guerrier) : yeux en cartes peintes, peau sous les manches retirée, mains et crâne décimés, sourcils
	# retirés, couches intérieures des cheveux retirées puis mèches décimées
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin + Vector3(0, 0.09, 0)
	var yeux := GuerrierNordique._centres_yeux(pieces.get("Eyes"))
	if pieces.has("Eyes"):
		pieces["Eyes"].visible = false
	GuerrierNordique._filtrer(pieces.get("peau"), func(c: Vector3, n: Vector3) -> bool: return absf(c.x) < 0.19 or absf(c.x) > 0.60)
	GuerrierNordique._decimer(pieces.get("peau"), func(p: Vector3) -> float: return 0.026 if absf(p.x) > 0.5 else (0.017 if p.z < 0.03 else 0.0))
	if pieces.has("Eyebrows"):
		pieces["Eyebrows"].visible = false
	var mi_ch: MeshInstance3D = sq.get_node_or_null("Hair_Long")
	if mi_ch:
		GuerrierNordique._filtrer(mi_ch, func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002)
		GuerrierNordique._decimer(mi_ch, func(p: Vector3) -> float: return 0.03)
		var src: Texture2D = (mi_ch.material_override as ShaderMaterial).get_shader_parameter("tex_base")
		mi_ch.material_override = GuerrierNordique.materiau(ChasseresseTextures.cheveux(src), true, false, true, "cheveux_chasseresse")
	_t("matieres", t0)
	# col de fourrure ouvert en V sur le devant (baudrier, fibule et tresses se lisent)
	GuerrierNordique._filtrer(pieces["mante"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > 0.0 and absf(c.x) < 0.13 + (c.y - 1.28) * 0.3 and c.y < 1.47))
	var rest_skin := sq.create_skin_from_rest_transforms()
	var acc := Acc.new(sq)
	var A := Vector2(GuerrierTextures.ATLAS)
	var D := Vector2(GuerrierTextures.DECOUPES)
	# ceinture (élargie) et cape versées dans les 2 surfaces des accessoires (atlas) : 2 surfaces de moins
	acc.integrer(pieces["ceinture"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, clampf((uv.y - 0.616) / 0.384, 0.0, 1.0) * 15.6 + 0.2 + GuerrierTextures.R_CEINT.position.y) / A,
		func(p: Vector3, n: Vector3) -> Vector3: return Vector3(p.x, 0.966 + (p.y - 0.966) * 1.35, p.z) + n * 0.006)
	acc.integrer(pieces["cape"], acc.dec, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 - ChasseresseTextures.CAPE_U0, uv.y * 128.0) / D)
	for nom in ["ceinture", "cape"]:
		pieces[nom].visible = false
	# baudrier (épaule droite -> hanche gauche) sur la jaque
	acc.baudrier_sur(pieces["tunique"], Vector2(-0.15, 1.42), Vector2(0.17, 0.95), 0.026)
	# fourrure en mèches : grand col (épaules, dos, col dressé), revers des bottes, frange de la jupe, manchons aux coudes
	acc.poitrine_libre = true
	acc.fourrure_bord(pieces["mante"], 1.22, 1.42, 0.10, 0.17, 1.0, 1.7)
	acc.fourrure_surface(pieces["mante"], 1.32, 1.56, 0.08, 0.13, 80)
	acc.col_libre = true
	acc.fourrure_bord(pieces["mante"], 1.47, 1.62, 0.05, 0.09, -0.6, 1.5)
	acc.col_libre = false
	acc.poitrine_libre = false
	acc.fourrure_bord(pieces["bottes"], 0.30, 0.45, 0.06, 0.09, 1.0, 1.6)
	acc.frange(pieces["tunique"], func(m: Vector3) -> bool: return m.y < 0.72, 0.05, 0.08, Vector3.DOWN, 1.5)
	var xin := 9.0
	for p in (pieces["brassards"].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		xin = minf(xin, absf(p.x))
	acc.frange(pieces["brassards"], func(m: Vector3) -> bool: return absf(m.x) < xin + 0.03, 0.05, 0.075, Vector3.ZERO, 1.8)
	acc.boucle(Vector3(0.0, 0.966, 0.122), 0.042)
	acc.fibule_sur(pieces["mante"], pieces["tunique"], Vector2(-0.115, 1.40))
	acc.yeux(yeux)
	acc.tresses()
	if options.get("carquois", true):
		acc.carquois()
	if options.get("couteau", true):
		acc.couteau()
	_t("accessoires (geometrie)", t0)
	sq.add_child(acc.construire(rest_skin, "accessoires"))
	# arc : deux maillages (porté main gauche / tendu main droite), un seul visible à la fois
	if options.get("arc", true):
		var porte := Acc.new(sq)
		var tr_porte := porte.repere_porte()
		var tr_vise := sq.get_bone_global_rest(sq.find_bone("hand_r")) * GuerrierNordique.Accessoires.PRISE * Transform3D(Basis(), Vector3(0, 0.04, 0))
		sq.set_meta("arc_porte", [sq.find_bone("hand_l"), tr_porte])     # contrôle des traversées (outils/test_chasseresse.gd)
		sq.set_meta("arc_vise", [sq.find_bone("hand_r"), tr_vise])
		porte.arc(tr_porte, sq.find_bone("hand_l"))
		var mi_porte := porte.construire(rest_skin, "arc_porte")
		var vise := Acc.new(sq)
		vise.arc(tr_vise, sq.find_bone("hand_r"))
		var mi_vise := vise.construire(rest_skin, "arc_vise")
		sq.add_child(mi_porte)
		sq.add_child(mi_vise)
		mi_vise.visible = false
		var ap := racine.get_node("Animations") as AnimationPlayer
		ap.current_animation_changed.connect(func(nom: StringName) -> void:
			if not is_instance_valid(mi_vise):
				return
			var v := clip_de_visee(String(nom))
			mi_vise.visible = v
			mi_porte.visible = not v)
	_t("accessoires (materiaux)", t0)
	racine.set_meta("chasseresse_nordique", true)
	return racine

static func _habiller(mi: MeshInstance3D, m: ShaderMaterial) -> void:
	mi.visible = true
	mi.material_override = m

## Peau (visage, mains) : textures de Humain._peau passées au shader des personnages pilotes, éclaircie, appoint propre et
## liseré froid (le visage reste lisible à 17h30 et à 8 m), contour sombre.
static func _peau(pieces: Dictionary) -> void:
	var mi: MeshInstance3D = pieces.get("peau")
	if mi == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as ShaderMaterial
		if m == null:
			continue
		var cle := "peau_%d" % s
		if not _mats.has(cle):
			var m2 := ShaderMaterial.new()
			m2.shader = GuerrierNordique.shader(false)
			for p in ["tex_base", "teinte", "emission", "saturation"]:
				m2.set_shader_parameter(p, m.get_shader_parameter(p))
			m2.next_pass = GuerrierNordique.contour()
			var te: Variant = m.get_shader_parameter("teinte")
			m2.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * Color(1.24, 1.17, 1.12))
			m2.set_shader_parameter("appoint", Vector3(0.17, 0.155, 0.17))
			m2.set_shader_parameter("contour_froid", Vector3(0.24, 0.29, 0.40))
			Palette.materiaux.append(m2)
			Palette._appliquer(m2, Palette._ps1_actif)
			_mats[cle] = m2
		mi.set_surface_override_material(s, _mats[cle])


# ======================================================================================================== accessoires
## Accessoires de la chasseresse : ceux du guerrier (mèches de fourrure, disques ouvragés, yeux, intégration à l'atlas) + arc,
## carquois et flèches, couteau, tresses blondes, frange, baudrier paramétré. Atlas : ChasseresseTextures (même disposition).
class Acc extends GuerrierNordique.Accessoires:

	func _pw(os_: int) -> Array:
		return [PackedInt32Array([os_, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]

	func _pw2(a: int, b: int, t: float) -> Array:
		return [PackedInt32Array([a, b, 0, 0]), PackedFloat32Array([1.0 - t, t, 0.0, 0.0])]

	## Tube à pans le long d'une polyligne `pts` (rayons `rayons`, poids d'os `poids` par point), UV : région `r` enroulée en u,
	## répartie en v sur la longueur ; `bout` = cône fermant le dernier anneau.
	func _tube_poly(s: Dictionary, pts: Array, rayons: Array, poids: Array, cotes: int, r: Rect2i, bout := false) -> void:
		var lg := [0.0]
		for i in range(1, pts.size()):
			lg.append(lg[i - 1] + (pts[i] - pts[i - 1]).length())
		var total: float = lg[lg.size() - 1]
		var anneaux := []
		for i in pts.size():
			var tg: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var x := tg.cross(Vector3.FORWARD if absf(tg.z) < 0.9 else Vector3.RIGHT).normalized()
			var y := tg.cross(x)
			var an := []
			for k in cotes:
				var a := TAU * k / cotes
				an.append(pts[i] + (x * cos(a) + y * sin(a)) * float(rayons[i]))
			anneaux.append(an)
		for i in pts.size() - 1:
			var v0: float = r.position.y + r.size.y * lg[i] / total
			var v1: float = r.position.y + r.size.y * lg[i + 1] / total
			for k in cotes:
				var k1 := (k + 1) % cotes
				var u0 := r.position.x + r.size.x * float(k) / cotes
				var u1 := r.position.x + r.size.x * float(k + 1) / cotes
				_quad(s, anneaux[i][k], anneaux[i][k1], anneaux[i + 1][k1], anneaux[i + 1][k], _uva(u0, v0), _uva(u1, v0), _uva(u1, v1), _uva(u0, v1),
					[poids[i], poids[i], poids[i + 1], poids[i + 1]], (pts[i] + pts[i + 1]) * 0.5)
		if bout:
			var n := pts.size() - 1
			var pointe: Vector3 = pts[n] + (pts[n] - pts[n - 1]).normalized() * float(rayons[n]) * 1.5
			for k in cotes:
				var k1 := (k + 1) % cotes
				var u0 := r.position.x + r.size.x * float(k) / cotes
				_tri(s, [anneaux[n][k], anneaux[n][k1], pointe], [_uva(u0, r.end.y - 2), _uva(u0 + r.size.x / cotes, r.end.y - 2), _uva(u0, r.end.y - 0.5)],
					[poids[n], poids[n], poids[n]], pts[n] - (pts[n] - pts[n - 1]).normalized() * 0.05)

	# ------------------------------------------------------------ tresses blondes (deux longues nattes devant les épaules)
	func tresses() -> void:
		var h := sq.find_bone("Head")
		var nk := sq.find_bone("neck_01")
		var sp := sq.find_bone("spine_03")
		for cote: float in [-1.0, 1.0]:
			var pts := [Vector3(0.078 * cote, 1.665, 0.005), Vector3(0.090 * cote, 1.585, 0.035), Vector3(0.098 * cote, 1.50, 0.075),
				Vector3(0.104 * cote, 1.43, 0.135), Vector3(0.106 * cote, 1.36, 0.162), Vector3(0.104 * cote, 1.29, 0.172), Vector3(0.10 * cote, 1.23, 0.168)]
			var ray := [0.019, 0.018, 0.017, 0.016, 0.015, 0.013, 0.010]
			var pw := [_pw(h), _pw(h), _pw2(h, nk, 0.5), _pw2(nk, sp, 0.5), _pw(sp), _pw(sp), _pw(sp)]
			_tube_poly(op, pts, ray, pw, 5, GuerrierTextures.R_TRESSE, true)

	# ------------------------------------------------------------ frange de mèches le long des bords libres choisis
	## Comme fourrure_bord, mais les arêtes sont choisies par `garder(milieu)` et la direction est `dir` (ZERO = vers l'extérieur
	## le long du bras, pour les manchons des coudes).
	func frange(mi: MeshInstance3D, garder: Callable, lg0: float, lg1: float, dir0: Vector3, elargi: float) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var aretes := {}
		var refs := {}
		for t in range(0, idx.size(), 3):
			for k in 3:
				var i0: int = idx[t + k]
				var i1: int = idx[t + (k + 1) % 3]
				var p0 := v[i0].snapped(Vector3.ONE * 0.0005)
				var p1 := v[i1].snapped(Vector3.ONE * 0.0005)
				var cle := [p0, p1] if str(p0) < str(p1) else [p1, p0]
				aretes[cle] = int(aretes.get(cle, 0)) + 1
				refs[cle] = [i0, i1]
		var n := 0
		for cle in aretes:
			if aretes[cle] != 1:
				continue
			var i0: int = refs[cle][0]
			var i1: int = refs[cle][1]
			var m := (v[i0] + v[i1]) * 0.5
			if not garder.call(m):
				continue
			var cote := v[i1] - v[i0]
			var lc := cote.length()
			if lc < 0.004:
				continue
			cote /= lc
			var ext := (nrm[i0] + nrm[i1]).normalized()
			var dir: Vector3
			if dir0 == Vector3.ZERO:
				# bras en pose de repos (T) : le manchon retombe vers la main, un peu vers l'extérieur
				var radial := Vector3(0.0, m.y - 1.418, m.z + 0.055).normalized()
				ext = radial
				dir = (Vector3(signf(m.x), 0, 0) * 0.85 + radial * 0.5).normalized()
			else:
				ext.y = 0.0
				if ext.length() < 0.1:
					ext = Vector3(m.x, 0.0, m.z)
				ext = ext.normalized()
				dir = (dir0 + ext * 0.45).normalized()
			_carte(mi, a, m - dir * 0.012 + ext * 0.004, cote, dir, maxf(lc * elargi, 0.035), lerpf(lg0, lg1, _h(n)), n % 4, ext)
			n += 1

	# ------------------------------------------------------------ baudrier paramétré (devant et dos, projeté sur `mi`)
	func baudrier_sur(mi: MeshInstance3D, depart: Vector2, arrivee: Vector2, demi: float) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var r := GuerrierTextures.R_BAUD
		for devant: bool in [true, false]:
			var dir := (arrivee - depart).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var nseg := 12
			var prec: Array = []
			for k in nseg + 1:
				var c := depart.lerp(arrivee, float(k) / nseg)
				var bords := []
				for sg: float in [-1.0, 1.0]:
					var q := c + perp * demi * sg
					var pr := _projeter(mi, q.x, q.y, devant)
					if pr.is_empty():
						bords = []
						break
					bords.append(pr[0] + pr[1] * 0.008)
				if bords.is_empty():
					prec = []
					continue
				var vt: float = r.position.y + posmod(k * 5, 60)
				if not prec.is_empty():
					var v0: float = prec[2]
					var v1 := v0 + 5.0
					var dedans := Vector3(c.x, c.y, -0.5 if devant else 0.5)
					_quad(op, prec[0], prec[1], bords[1], bords[0], _uva(r.position.x + 0.5, v0), _uva(r.end.x - 0.5, v0),
						_uva(r.end.x - 0.5, v1), _uva(r.position.x + 0.5, v1),
						[_poids_proche(mi, a, prec[0]), _poids_proche(mi, a, prec[1]), _poids_proche(mi, a, bords[1]), _poids_proche(mi, a, bords[0])], dedans)
				prec = [bords[0], bords[1], vt]

	## Fibule ronde posée sur `mi` (repli sur `secours` si le point tombe dans l'ouverture).
	func fibule_sur(mi: MeshInstance3D, secours: MeshInstance3D, xy: Vector2) -> void:
		var cible := mi
		var pr := _projeter(mi, xy.x, xy.y, true)
		if pr.is_empty():
			cible = secours
			pr = _projeter(secours, xy.x, xy.y, true)
		if pr.is_empty():
			push_warning("ChasseresseNordique : fibule hors des pièces %s" % xy)
			return
		var pw := _poids_proche(cible, cible.mesh.surface_get_arrays(0), pr[0])
		_disque(pr[0] + pr[1] * 0.014, pr[1], 0.036, [pw, pw, pw, pw])

	# ------------------------------------------------------------ arc long (repère : y le long de l'arc, +z = dos de l'arc)
	## Arc d'if de 1,44 m, poignée au centre (origine), branches qui reviennent vers l'archer (-z) et bouts recourbés vers
	## l'avant ; section rectangulaire (4 pans) qui s'affine vers les bouts ; corde tendue entre les bouts (prisme à 3 pans).
	const DEMI_ARC := 0.72

	func arc(tr: Transform3D, os_: int) -> void:
		var pts := []
		var lar := []
		var ep := []
		var n := 12
		for i in n + 1:
			var t := -1.0 + 2.0 * i / n
			var at := absf(t)
			var z := -0.11 * at * at + 0.045 * smoothstep(0.78, 1.0, at)
			pts.append(Vector3(0.0, t * DEMI_ARC, z))
			lar.append(lerpf(0.017, 0.008, smoothstep(0.1, 1.0, at)))
			ep.append(lerpf(0.022, 0.010, smoothstep(0.1, 1.0, at)))
		var r := ChasseresseTextures.R_ARC
		for i in n:
			var anneaux := []
			for j in [i, i + 1]:
				var tg: Vector3 = (pts[mini(j + 1, n)] - pts[maxi(j - 1, 0)]).normalized()
				var nz := Vector3.RIGHT.cross(tg).normalized()      # normale dans le plan de courbure (vers le dos)
				var c: Vector3 = pts[j]
				var lx: float = lar[j]
				var lz: float = ep[j] * 0.5
				anneaux.append([c + Vector3(lx, 0, 0) + nz * lz, c - Vector3(lx, 0, 0) + nz * lz, c - Vector3(lx, 0, 0) - nz * lz, c + Vector3(lx, 0, 0) - nz * lz])
			var v0: float = r.position.y + r.size.y * float(n - i) / n
			var v1: float = r.position.y + r.size.y * float(n - i - 1) / n
			for k in 4:
				var k1 := (k + 1) % 4
				var u0 := r.position.x + 4.0 * k
				_quad(op, tr * anneaux[0][k], tr * anneaux[0][k1], tr * anneaux[1][k1], tr * anneaux[1][k], _uva(u0, v0), _uva(u0 + 4.0, v0), _uva(u0 + 4.0, v1), _uva(u0, v1),
					os_, tr * ((pts[i] + pts[i + 1]) * 0.5))
		# corde
		var haut: Vector3 = pts[n] + Vector3(0, -0.02, -0.004)
		var bas: Vector3 = pts[0] + Vector3(0, 0.02, -0.004)
		var rc := ChasseresseTextures.R_CORDE
		for k in 3:
			var a0 := TAU * k / 3.0
			var a1 := TAU * (k + 1) / 3.0
			var d0 := Vector3(cos(a0), 0, sin(a0)) * 0.0028
			var d1 := Vector3(cos(a1), 0, sin(a1)) * 0.0028
			_quad(op, tr * (bas + d0), tr * (bas + d1), tr * (haut + d1), tr * (haut + d0), _uva(rc.position.x, rc.end.y), _uva(rc.end.x, rc.end.y),
				_uva(rc.end.x, rc.position.y), _uva(rc.position.x, rc.position.y), os_, tr * ((bas + haut) * 0.5))

	## Repère de l'arc porté dans la main gauche : calculé sur la pose de la main dans Idle (fraction 0,3), l'arc y est presque
	## vertical (un peu penché vers l'avant et l'extérieur, la branche haute dégage le bras) ; dans la marche il balance avec le bras.
	const POSE_IDLE_MAIN_G := Transform3D(Basis(Vector3(-0.889131, -0.235068, -0.392669), Vector3(0.028026, -0.884364, 0.465956), Vector3(-0.456794, 0.403291, 0.792903)), Vector3(0.263458, 0.885619, 0.038581))

	func repere_porte() -> Transform3D:
		var P := POSE_IDLE_MAIN_G.orthonormalized()
		var R := sq.get_bone_global_rest(sq.find_bone("hand_l"))
		var prise := P.origin + P.basis.y * 0.085 + P.basis.z * -0.01
		var axe := Vector3(0.16, 1.0, 0.20).normalized()
		var dos := Vector3(0.35, 0.0, 1.0)
		dos = (dos - axe * dos.dot(axe)).normalized()
		var D := Transform3D(Basis(axe.cross(dos), axe, dos), prise)
		return R * P.affine_inverse() * D

	# ------------------------------------------------------------ carquois dans le dos et flèches
	## Carquois de cuir en biais (haut derrière l'épaule droite, bas vers la hanche gauche), sur la cape ; 6 flèches dépassent,
	## empennage en cartes découpées (plumes) ; os spine_03 (haut) et spine_02 (bas).
	func carquois() -> void:
		var s3 := sq.find_bone("spine_03")
		var s2 := sq.find_bone("spine_02")
		var haut := Vector3(-0.115, 1.50, -0.265)
		var bas := Vector3(0.075, 0.99, -0.255)
		var axe := (haut - bas).normalized()
		var pts := [bas, bas.lerp(haut, 0.5), haut]
		var ray := [0.050, 0.056, 0.060]
		var pw := [_pw2(s3, s2, 0.6), _pw2(s3, s2, 0.2), _pw(s3)]
		_tube_poly(op, pts, ray, pw, 7, ChasseresseTextures.R_CARQ)
		# fond et ouverture (disques sombres)
		var x := axe.cross(Vector3.FORWARD).normalized()
		var y := axe.cross(x)
		var rc := ChasseresseTextures.R_CARQ
		for bout: Array in [[bas, -1.0, 0.050, pw[0]], [haut - axe * 0.03, 1.0, 0.060, pw[2]]]:
			var c: Vector3 = bout[0]
			for k in 7:
				var a0 := TAU * k / 7.0
				var a1 := TAU * (k + 1) / 7.0
				_tri(op, [c, c + (x * cos(a0) + y * sin(a0)) * float(bout[2]), c + (x * cos(a1) + y * sin(a1)) * float(bout[2])],
					[_uva(rc.position.x + 8, rc.position.y + 2), _uva(rc.position.x + 4, rc.position.y + 4), _uva(rc.position.x + 12, rc.position.y + 4)],
					[bout[3], bout[3], bout[3]], c - axe * float(bout[1]) * 0.05)
		# flèches : fûts (prismes à 3 pans) et empennage croisé (2 cartes découpées par flèche)
		var D := Vector2(GuerrierTextures.DECOUPES)
		var pl := ChasseresseTextures.D_PLUME
		for i in 6:
			var ang := TAU * i / 6.0 + 0.4
			var ecart := (x * cos(ang) + y * sin(ang)) * 0.030
			var penche := (x * cos(ang) + y * sin(ang)) * 0.06 * _h(i)
			var a := haut - axe * 0.04 + ecart
			var b := haut + (axe + penche).normalized() * (0.20 + 0.05 * _h(i + 7)) + ecart
			_tube_poly(op, [a, b], [0.0055, 0.0055], [_pw(s3), _pw(s3)], 3, ChasseresseTextures.R_FUT)
			var ax := (b - a).normalized()
			var w0 := ax.cross(Vector3.UP).normalized()
			var w1 := ax.cross(w0).normalized()
			var var_ := (i % 2) * 16.0
			for w: Vector3 in [w0, w1]:
				var p0 := b - ax * 0.11
				var p1 := b - ax * 0.005
				_quad(dec, p0 - w * 0.014, p0 + w * 0.014, p1 + w * 0.014, p1 - w * 0.014,
					Vector2(pl.position.x + var_, pl.position.y) / D, Vector2(pl.position.x + var_ + 16.0, pl.position.y) / D,
					Vector2(pl.position.x + var_ + 16.0, pl.end.y) / D, Vector2(pl.position.x + var_, pl.end.y) / D, s3, p0 - w.cross(ax) * 0.05)

	# ------------------------------------------------------------ couteau à la ceinture (hanche droite, os pelvis)
	func couteau() -> void:
		var os_ := sq.find_bone("pelvis")
		var b := Basis(Vector3.FORWARD, deg_to_rad(-12.0)) * Basis(Vector3.RIGHT, deg_to_rad(-10.0))
		var tr := Transform3D(b, Vector3(-0.205, 0.955, 0.075))
		_boite_r(Vector3(-0.016, -0.17, -0.009), Vector3(0.016, 0.0, 0.009), tr, os_, ChasseresseTextures.R_FOURREAU)     # fourreau
		_boite_r(Vector3(-0.022, 0.0, -0.012), Vector3(0.022, 0.012, 0.012), tr, os_, GuerrierTextures.R_FER)           # garde
		_tube_poly(op, [tr * Vector3(0, 0.012, 0), tr * Vector3(0, 0.085, 0)], [0.011, 0.010], [_pw(os_), _pw(os_)], 5, GuerrierTextures.R_POIGNEE)
		_boite_r(Vector3(-0.014, 0.085, -0.012), Vector3(0.014, 0.102, 0.012), tr, os_, GuerrierTextures.R_FER)         # pommeau

	## Boîte à 6 faces, chaque face reçoit toute la région `r`.
	func _boite_r(a: Vector3, b: Vector3, tr: Transform3D, os_: int, r: Rect2i) -> void:
		var c := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
			Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		var faces := [[3, 2, 1, 0], [4, 5, 6, 7], [7, 6, 2, 3], [0, 1, 5, 4], [4, 7, 3, 0], [1, 2, 6, 5]]
		for fc: Array in faces:
			_quad(op, tr * c[fc[0]], tr * c[fc[1]], tr * c[fc[2]], tr * c[fc[3]], _uva(r.position.x + 0.5, r.position.y + 0.5), _uva(r.end.x - 0.5, r.position.y + 0.5),
				_uva(r.end.x - 0.5, r.end.y - 0.5), _uva(r.position.x + 0.5, r.end.y - 0.5), os_, tr * ((a + b) * 0.5))

	# ------------------------------------------------------------ assemblage (textures de la chasseresse)
	func construire(skin: Skin, nom := "accessoires") -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		var mi := MeshInstance3D.new()
		mi.name = nom
		var mats := []
		for s: Dictionary in [op, dec]:
			if s["v"].is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s["v"]
			arr[Mesh.ARRAY_NORMAL] = s["n"]
			arr[Mesh.ARRAY_TEX_UV] = s["uv"]
			arr[Mesh.ARRAY_BONES] = s["b"]
			arr[Mesh.ARRAY_WEIGHTS] = s["w"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			if s == op:
				mats.append(GuerrierNordique.materiau(ChasseresseTextures.tex("accessoires"), false, false, true))
			else:
				mats.append(GuerrierNordique.materiau(ChasseresseTextures.tex("decoupes"), true, true, false))
		mi.mesh = mesh
		mi.skin = skin
		mi.skeleton = NodePath("..")
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i])
		return mi
