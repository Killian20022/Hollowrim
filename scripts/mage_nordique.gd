class_name MageNordique
## Mage nordique (refonte des personnages, étape 4, branche refonte/persos_mage) — même recette que le Guerrier pilote validé :
## base Humain.creer (corps homme Quaternius, 65 os, animations et ragdoll d'origine), matières de GuerrierTextures / MageTextures
## (128 texels/m, palettes froides, mipmaps pixel art), shader ps1_perso + contour par coque, fourrure en MÈCHES géométriques,
## accessoires MODELÉS par code (rien n'est peint en relief).
##   - longue robe de laine épaisse bleu ardoise : haut = tunique retexturée (bande brodée de runes au milieu du devant, poignets
##     brodés), JUPE MODELÉE jusqu'aux chevilles (doublure, ourlet uni sans damier) recalculée à chaque image par MageJupe : elle
##     pend du bassin et les jambes la repoussent, elles ne la traversent jamais (test_mage) ;
##   - manteau de fourrure : mante + franges et touffes de mèches (même fourrure que le guerrier), manchettes de fourrure ;
##   - capuche de laine gris-brun (cheveux cachés), barbe grise, visage à l'ombre ;
##   - bâton runique dans la main droite (hampe gravée de runes, bagues de fer, prise de cuir, tête sculptée à trois griffes)
##     tenant un CRISTAL de glace à facettes, légèrement émissif (pas de lumière ni de halo ajoutés) ;
##   - amulettes : disque runique en pendentif sur un cordon, pierre runique pendue à la ceinture.
## Signature : lancement de sort avec les clips Spell_Simple_* (Enter / Idle / Shoot / Exit : main GAUCHE tendue, le bâton
## reste dans la droite).
##   MageNordique.creer({"baton": true, "capuche": true}) -> Node3D
## Contrat identique à Humain.creer (nœud racine -> Skeleton3D + AnimationPlayer « Animations », mêmes os) : Ragdoll.equiper,
## PiedsAuSol.equiper marchent tels quels. Aucun PNJ modifié (nouvelle fabrique).

const TEINTE_BARBE := Color(0.80, 0.80, 0.82)
const PEAU := Color(0.93, 0.84, 0.80)

## Prise du bâton (outils/inspecter_mage.gd -- 0.3) : repère centré dans la paume droite, dans le repère posé de hand_r, à 30 % du
## chemin entre « vertical en Idle » et « vertical en Spell_Simple_Idle » (8° en Idle, ~20° pendant le sort, au lieu de 45°).
const PRISE_BATON := Transform3D(Basis(Vector3(-0.947591, -0.319101, -0.015678), Vector3(0.269132, -0.823724, 0.499045), Vector3(-0.172160, 0.468671, 0.866434)), Vector3(-0.002341, 0.057720, 0.007557))

## Bâton : (décalage vers l'extérieur de la main en m, inclinaison du pied vers l'extérieur en °, inclinaison du pied vers l'avant en °).
static var reglage_baton := Vector3(0.035, 10.0, 3.0)
## Anneaux de la jupe (hauteur au repos) et rayons du profil (x, z) de la taille à l'ourlet.
const ANNEAUX := [0.99, 0.90, 0.79, 0.66, 0.53, 0.40, 0.28, 0.17]
const SECTEURS := 20
const Z_CENTRE := -0.03

static var chrono := false

static func vider() -> void:
	MageTextures.vider()
	GuerrierNordique.vider()

static func creer(options := {}) -> Node3D:
	var C := Color.WHITE
	var tenue := {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "mante": C, "manchettes": C}
	if options.get("capuche", true):
		tenue["capuche"] = C
	var app := {"corps": "homme", "barbe": true, "cheveux": "Hair_Long", "teinte_cheveux": TEINTE_BARBE, "peau": PEAU, "tenue": tenue}
	var t0 := Time.get_ticks_usec()
	var racine := Humain.creer(app)
	racine.name = "MageNordique"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var pieces := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		pieces[String(mi.name)] = mi
	# -- vêtements existants : matières du mage (la tunique devient le haut de la robe)
	_habiller(pieces["tunique"], GuerrierNordique.materiau(MageTextures.tex("robe_haut")))
	_habiller(pieces["bottes"], GuerrierNordique.materiau(GuerrierTextures.tex("bottes")))
	_habiller(pieces["mante"], GuerrierNordique.materiau(GuerrierTextures.tex("mante")))
	if pieces.has("capuche") and options.get("capuche", true):
		_habiller(pieces["capuche"], GuerrierNordique.materiau(MageTextures.tex("capuche")))
		# capuche ouverte devant (le pan qui couvrait le menton et le cou est retiré : la barbe sort de la capuche comme sur la
		# référence), sommet relevé et tiré en arrière (léger pic), bord avant avancé au-dessus du front (visage dans l'ombre)
		GuerrierNordique._filtrer(pieces["capuche"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > -0.01 and absf(c.x) < 0.105 + maxf(0.0, 1.58 - c.y) * 0.6 and c.y < 1.665))
		_deformer(pieces["capuche"], func(p: Vector3) -> Vector3:
			var t := smoothstep(1.74, 1.86, p.y) * smoothstep(0.06, -0.10, p.z)
			var f := smoothstep(1.68, 1.78, p.y) * smoothstep(0.02, 0.10, p.z)
			return p + Vector3(0, 0.045 * t, -0.035 * t) + Vector3(0, -0.006 * f, 0.018 * f))
	var sc: MeshInstance3D = pieces.get("SuperHero_Male")
	if sc:
		sc.visible = false
	_peau(pieces)
	# allègement (même méthode que le guerrier) : yeux en cartes peintes, peau sous les manches retirée, mains décimées, sourcils retirés
	var yeux := GuerrierNordique._centres_yeux(pieces.get("Eyes"))
	if pieces.has("Eyes"):
		pieces["Eyes"].visible = false
	GuerrierNordique._filtrer(pieces.get("peau"), func(c: Vector3, n: Vector3) -> bool: return absf(c.x) < 0.19 or absf(c.x) > 0.69)
	GuerrierNordique._decimer(pieces.get("peau"), func(p: Vector3) -> float: return 0.027 if absf(p.x) > 0.5 else (0.018 if p.z < 0.035 else 0.0))
	if pieces.has("Eyebrows"):
		pieces["Eyebrows"].visible = false
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin + Vector3(0, 0.07, 0)
	GuerrierNordique._filtrer(sq.get_node_or_null("Hair_Beard"), func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002)
	GuerrierNordique._decimer(sq.get_node_or_null("Hair_Beard"), func(p: Vector3) -> float: return 0.008)
	var mi_b: MeshInstance3D = sq.get_node_or_null("Hair_Beard")
	if mi_b:
		# barbe de mage : allongée sous le menton (x 1,9 vers le bas) et un peu avancée, pointe resserrée
		_deformer(mi_b, func(p: Vector3) -> Vector3:
			var d := maxf(0.0, 1.635 - p.y)
			var t := d / 0.08
			return Vector3(p.x * (1.0 - 0.25 * clampf(t, 0.0, 1.0)), 1.635 - d * 1.9, p.z + d * 0.25))
		GuerrierNordique._uv_barbe(mi_b)
		mi_b.material_override = GuerrierNordique.materiau(MageTextures.tex("barbe"), true, false, false, "mage_barbe")
		(mi_b.material_override as ShaderMaterial).set_shader_parameter("appoint", Vector3(0.10, 0.10, 0.11))
	# la tunique s'arrête sous la ceinture (la jupe modelée prend le relais) ; le pantalon reste (vu sous la robe à la mort)
	GuerrierNordique._filtrer(pieces["tunique"], func(c: Vector3, n: Vector3) -> bool: return c.y > 0.93)
	_t("matieres", t0)
	var rest_skin := sq.create_skin_from_rest_transforms()
	var acc := Acc.new(sq)
	var A := Vector2(MageTextures.ATLAS)
	acc.robe(pieces["tunique"], pieces["pantalon"])
	var jupe := MageJupe.new()
	jupe.preparer(sq, acc.jupe, GuerrierNordique.materiau(MageTextures.tex("accessoires"), false, false, true, "mage_acc"))
	sq.add_child(jupe)
	# pantalon (vu sous la robe à la mort, au saut) versé dans l'atlas (région R_PANTALON : ses UV tels quels) : une surface de moins
	acc.integrer(pieces["pantalon"], acc.op, func(uv: Vector2) -> Vector2:
		return (Vector2(MageTextures.R_PANTALON.position) + uv * Vector2(MageTextures.R_PANTALON.size)) / A)
	pieces["pantalon"].visible = false
	_t("robe", t0)
	acc.integrer(pieces["ceinture"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, clampf((uv.y - 0.698) / 0.302, 0.0, 1.0) * 15.6 + 0.2 + GuerrierTextures.R_CEINT.position.y) / A,
		func(p: Vector3, n: Vector3) -> Vector3: return Vector3(p.x, 0.985 + (p.y - 0.985) * 1.3, p.z) + n * 0.030)
	pieces["ceinture"].visible = false
	# manchettes de fourrure versées dans l'atlas des découpes (région libre de la cape, fourrure pleine)
	acc.integrer_uv_bornes(pieces["manchettes"], acc.dec, Rect2(0, 32, 112, 64), Vector2(GuerrierTextures.DECOUPES), 0.004)
	pieces["manchettes"].visible = false
	# manteau de fourrure : franges longues aux épaules et dans le dos, touffes ; rien au-dessus de 1,50 m (sous la capuche)
	acc.poitrine_libre = true
	acc.fourrure_bord(pieces["mante"], 1.25, 1.45, 0.15, 0.24, 1.0, 1.7)
	acc.fourrure_surface(pieces["mante"], 1.34, 1.50, 0.09, 0.15, 64)
	acc.poitrine_libre = false
	acc.yeux(yeux)
	acc.amulette(pieces["tunique"])
	acc.pierre_ceinture()
	if options.get("baton", true):
		acc.baton()
	_t("accessoires (geometrie)", t0)
	var mi_acc := acc.construire(rest_skin)
	sq.add_child(mi_acc)
	_t("accessoires (materiaux)", t0)
	racine.set_meta("mage_nordique", true)
	return racine

static func _t(etape: String, t0: int) -> void:
	if chrono:
		print("MAGE %-26s %7.1f ms" % [etape, (Time.get_ticks_usec() - t0) / 1000.0])

## Déplace les sommets de `mi` (repos) par f(p) ; peau d'os, UV et matériau gardés.
static func _deformer(mi: MeshInstance3D, f: Callable) -> void:
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] = f.call(v[i])
	a[Mesh.ARRAY_VERTEX] = v
	var nb := (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / v.size()
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	mi.mesh = m

static func _habiller(mi: MeshInstance3D, m: ShaderMaterial) -> void:
	mi.visible = true
	mi.material_override = m

## Peau et sourcils au shader du guerrier (copie de la branche peau de GuerrierNordique.creer) : peau moins éclaircie que celle
## du guerrier (le visage reste dans l'ombre de la capuche, comme sur la référence), appoint froid plus faible.
static var _mats := {}

static func _peau(pieces: Dictionary) -> void:
	for nom in ["peau", "Eyebrows"]:
		var mi: MeshInstance3D = pieces.get(nom)
		if mi == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				continue
			var cle := "mage_peau_%s_%d" % [nom, s]
			if not _mats.has(cle):
				var m2 := ShaderMaterial.new()
				m2.shader = GuerrierNordique.shader(nom == "Eyebrows")
				for p in ["tex_base", "teinte", "emission", "saturation"]:
					m2.set_shader_parameter(p, m.get_shader_parameter(p))
				if nom == "peau":
					m2.next_pass = GuerrierNordique.contour()
					var te: Variant = m.get_shader_parameter("teinte")
					m2.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * Color(1.08, 1.04, 1.02))
					m2.set_shader_parameter("appoint", Vector3(0.09, 0.09, 0.11))
					m2.set_shader_parameter("contour_froid", Vector3(0.22, 0.27, 0.38))
				Palette.materiaux.append(m2)
				Palette._appliquer(m2, Palette._ps1_actif)
				_mats[cle] = m2
			mi.set_surface_override_material(s, _mats[cle])

# ======================================================================================================== accessoires
## Atlas du mage (MageTextures.ATLAS, 256 x 512) pour la surface opaque ; atlas des découpes de même mise en page que le guerrier ;
## 3e surface : cristal émissif.
class Acc extends GuerrierNordique.Accessoires:
	var cri := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	## points de la jupe au repos : [anneau][secteur]
	var jupe: Array = []

	func _init(s: Skeleton3D) -> void:
		super(s)

	func _uva(x: float, y: float) -> Vector2:
		return Vector2(x / MageTextures.ATLAS.x, y / MageTextures.ATLAS.y)

	## Devant de la poitrine plus largement dégagé que sur le guerrier : la barbe, l'amulette et la bande brodée se lisent.
	func _poitrine(p: Vector3) -> bool:
		return poitrine_libre and p.z > 0.0 and absf(p.x) < 0.16 and p.y < 1.55

	# ------------------------------------------------------------ jupe (points au repos ; maillage : MageJupe, recalculé à chaque image)
	## Anneaux évasés (profil elliptique, rayon au moins 1,8 cm hors de la tunique et du pantalon mesurés au repos dans le même secteur).
	func robe(tunique: MeshInstance3D, pantalon: MeshInstance3D) -> void:
		var N := MageNordique.SECTEURS
		var ys: Array = MageNordique.ANNEAUX
		var zc := MageNordique.Z_CENTRE
		var evase := 0.0
		# rayon mini mesuré par anneau et secteur
		var mini_r := []
		for k in ys.size():
			var ligne := []
			ligne.resize(N)
			ligne.fill(0.0)
			mini_r.append(ligne)
		for mi: MeshInstance3D in [tunique, pantalon]:
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for p in v:
				var ang := atan2(p.x, p.z - zc)
				var sec := posmod(int(roundf(ang / TAU * N)), N)
				var r := Vector2(p.x, p.z - zc).length()
				for k in ys.size():
					if absf(p.y - float(ys[k])) < 0.07:
						for ds in [-1, 0, 1]:
							var s2 := posmod(sec + ds, N)
							mini_r[k][s2] = maxf(mini_r[k][s2], r * (0.97 if ds != 0 else 1.0))
		var pts := []
		for k in ys.size():
			var y: float = ys[k]
			var h: float = (float(ys[0]) - y) / (ys[0] - ys[ys.size() - 1])
			var e := sqrt(h)
			var rx := lerpf(0.185, 0.29 + evase, e)
			var rz := lerpf(0.150, 0.26 + evase, e)
			var ligne := []
			for i in N:
				var a := TAU * i / N
				var d := Vector2(sin(a) * rx, cos(a) * rz)
				var r := maxf(d.length(), float(mini_r[k][i]) + 0.018)
				var dn := Vector2(sin(a), cos(a))
				ligne.append(Vector3(dn.x * r, y, zc + dn.y * r))
			pts.append(ligne)
		jupe = pts

	## Comme integrer, UV ramenés des bornes UV de la pièce vers la région `r` (texels) d'un atlas de taille `taille` ; sommets gonflés de `gonfle`.
	func integrer_uv_bornes(mi: MeshInstance3D, s: Dictionary, r: Rect2, taille: Vector2, gonfle := 0.0) -> void:
		var uv: PackedVector2Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for q in uv:
			lo = lo.min(q)
			hi = hi.max(q)
		var ext := (hi - lo).max(Vector2(1e-4, 1e-4))
		integrer(mi, s, func(q: Vector2) -> Vector2: return (r.position + (q - lo) / ext * r.size) / taille,
			func(p: Vector3, n: Vector3) -> Vector3: return p + n * gonfle)

	# ------------------------------------------------------------ amulettes
	## Disque runique plat (R_DISQUE) orienté par n, tranche sombre ; poids donnés.
	func _disque_runique(centre: Vector3, n: Vector3, rayon: float, poids: Variant, cotes := 10) -> void:
		var x := n.cross(Vector3.UP).normalized()
		var y := x.cross(n).normalized() * -1.0
		if y.y < 0.0:
			y = -y
		var r := MageTextures.R_DISQUE
		var cuv := Vector2(r.position) + Vector2(r.size) * 0.5
		var dedans := centre - n * 0.05
		var ep := n * 0.008
		for i in cotes:
			var a0 := TAU * i / cotes
			var a1 := TAU * (i + 1) / cotes
			var e0 := x * cos(a0) + y * sin(a0)
			var e1 := x * cos(a1) + y * sin(a1)
			var t0 := cuv + Vector2(cos(a0), -sin(a0)) * r.size.x * 0.47
			var t1 := cuv + Vector2(cos(a1), -sin(a1)) * r.size.x * 0.47
			var pw3: Variant = poids if poids is int else [poids[0], poids[1], poids[2]]
			_tri(op, [centre + ep, centre + e0 * rayon + ep, centre + e1 * rayon + ep], [_uva(cuv.x, cuv.y), _uva(t0.x, t0.y), _uva(t1.x, t1.y)], pw3, dedans)
			_quad(op, centre + e0 * rayon + ep, centre + e1 * rayon + ep, centre + e1 * rayon, centre + e0 * rayon,
				_uva(r.position.x + 1, r.position.y + 1), _uva(r.position.x + 3, r.position.y + 1), _uva(r.position.x + 3, r.position.y + 3), _uva(r.position.x + 1, r.position.y + 3), poids, dedans)

	## Pendentif : disque runique sur la poitrine (sous la barbe), cordon de cuir jusqu'au cou des deux côtés.
	func amulette(tunique: MeshInstance3D) -> void:
		var pr := _projeter(tunique, 0.0, 1.24, true)
		if pr.is_empty():
			push_warning("MageNordique : amulette hors de la tunique")
			return
		var os_ := sq.find_bone("spine_03")
		var c: Vector3 = pr[0] + pr[1] * 0.022
		_disque_runique(c, pr[1], 0.036, os_)
		for cote: float in [-1.0, 1.0]:
			var haut := Vector3(0.075 * cote, 1.50, 0.035)
			var bas := c + Vector3(0.022 * cote, 0.030, 0.004)
			_tube(op, haut, bas, 0.0045, 0.0045, 3, os_, MageTextures.R_CORDON, 2)

	## Pierre runique pendue à la ceinture, hanche gauche (suit la jupe : mêmes poids que la jupe à cet endroit).
	func pierre_ceinture() -> void:
		var a := deg_to_rad(48.0)
		var base := Vector3(sin(a) * 0.205, 0.955, MageNordique.Z_CENTRE + cos(a) * 0.185)
		var n := Vector3(sin(a), 0, cos(a))
		var poids := sq.find_bone("pelvis")
		# lanière
		var l0 := base + n * 0.02
		var l1 := base + n * 0.04 + Vector3(0, -0.07, 0)
		var cote := n.cross(Vector3.UP).normalized()
		_quad(op, l0 - cote * 0.006, l0 + cote * 0.006, l1 + cote * 0.006, l1 - cote * 0.006,
			_uva(32 + 2, 2), _uva(32 + 6, 2), _uva(32 + 6, 14), _uva(32 + 2, 14), poids, l0 - n * 0.1)
		# pierre : boîte 4,5 x 6 x 1,6 cm
		var c := l1 + n * 0.008 + Vector3(0, -0.032, 0)
		var tr := Transform3D(Basis(cote, Vector3.UP, n), c)
		_boite_region(Vector3(-0.0225, -0.03, -0.008), Vector3(0.0225, 0.03, 0.008), tr, poids, MageTextures.R_PIERRE)

	## Boîte texturée par une région entière (face avant = toute la région, tranches = bord de la région).
	func _boite_region(a: Vector3, b: Vector3, tr: Transform3D, poids: Variant, r: Rect2i) -> void:
		var c := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
			Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		var faces := [[3, 2, 1, 0], [4, 5, 6, 7], [7, 6, 2, 3], [0, 1, 5, 4], [4, 7, 3, 0], [1, 2, 6, 5]]
		for f in faces.size():
			var fc: Array = faces[f]
			var x0 := r.position.x + 0.5
			var x1 := r.end.x - 0.5
			var y0 := r.position.y + 0.5
			var y1 := r.end.y - 0.5
			if f != 1:
				x1 = x0 + 2.0
				y1 = y0 + 2.0
			_quad(op, tr * c[fc[0]], tr * c[fc[1]], tr * c[fc[2]], tr * c[fc[3]], _uva(x0, y1), _uva(x1, y1), _uva(x1, y0), _uva(x0, y0), poids, tr * ((a + b) * 0.5))

	# ------------------------------------------------------------ bâton runique (main droite)
	## Repère local : prise à l'origine, hampe le long de +y (verticale en pose Idle). Pied à -0,86 m (au sol), tête à +0,80 m,
	## cristal jusqu'à +1,02 m (au-dessus de la capuche, comme sur la référence).
	func baton() -> void:
		var os_ := sq.find_bone("hand_r")
		var rb: Vector3 = MageNordique.reglage_baton
		var incl := Basis(Vector3.BACK, deg_to_rad(-rb.y)) * Basis(Vector3.RIGHT, deg_to_rad(-rb.z))
		var tr := sq.get_bone_global_rest(os_) * MageNordique.PRISE_BATON * Transform3D(incl, Vector3(-rb.x, 0, 0))
		sq.set_meta("baton", [os_, tr])
		var L := func(y: float) -> Vector3: return tr * Vector3(0, y, 0)
		_tube(op, L.call(-0.84), L.call(0.70), 0.017, 0.021, 6, os_, MageTextures.R_HAMPE, 5)
		_tube(op, L.call(-0.89), L.call(-0.83), 0.015, 0.020, 6, os_, GuerrierTextures.R_FER, 1)      # sabot de fer
		_tube(op, L.call(-0.11), L.call(0.12), 0.024, 0.024, 6, os_, GuerrierTextures.R_POIGNEE, 1)   # prise de cuir
		_tube(op, L.call(0.40), L.call(0.43), 0.024, 0.024, 6, os_, GuerrierTextures.R_FER, 1)        # bague
		_tube(op, L.call(0.66), L.call(0.70), 0.026, 0.026, 6, os_, GuerrierTextures.R_FER, 1)        # bague haute
		# tête sculptée : nœud qui s'évase puis se resserre
		_tube(op, L.call(0.70), L.call(0.77), 0.024, 0.037, 6, os_, MageTextures.R_TETE, 1)
		_tube(op, L.call(0.77), L.call(0.80), 0.037, 0.028, 6, os_, MageTextures.R_TETE, 1)
		# trois griffes de bois qui enserrent le cristal
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var dirh := Vector3(cos(a), 0, sin(a))
			var p0 := tr * (dirh * 0.024 + Vector3(0, 0.79, 0))
			var p1 := tr * (dirh * 0.058 + Vector3(0, 0.88, 0))
			var p2 := tr * (dirh * 0.026 + Vector3(0, 0.99, 0))
			_tube(op, p0, p1, 0.010, 0.008, 4, os_, MageTextures.R_TETE, 1)
			_tube(op, p1, p2, 0.008, 0.004, 4, os_, MageTextures.R_TETE, 1)
		# cristal : bipyramide hexagonale allongée (surface émissive à part)
		var bas := tr * Vector3(0, 0.80, 0)
		var haut := tr * Vector3(0, 1.02, 0)
		var milieu := 0.885
		var rc := 0.034
		for i in 6:
			var a0 := TAU * i / 6.0
			var a1 := TAU * (i + 1) / 6.0
			var e0 := tr * Vector3(cos(a0) * rc, milieu, sin(a0) * rc)
			var e1 := tr * Vector3(cos(a1) * rc, milieu, sin(a1) * rc)
			var u0 := float(i % 4) * 8.0
			var c := tr * Vector3(0, milieu, 0)
			_tri(cri, [haut, e0, e1], [Vector2((u0 + 4.0) / 32.0, 0.02), Vector2(u0 / 32.0, 0.5), Vector2((u0 + 7.9) / 32.0, 0.5)], os_, c)
			_tri(cri, [bas, e1, e0], [Vector2((u0 + 4.0) / 32.0, 0.98), Vector2((u0 + 7.9) / 32.0, 0.5), Vector2(u0 / 32.0, 0.5)], os_, c)

	# ------------------------------------------------------------ assemblage
	func construire(skin: Skin) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		var mats := []
		for s: Dictionary in [op, dec, cri]:
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
				mats.append(GuerrierNordique.materiau(MageTextures.tex("accessoires"), false, false, true, "mage_acc"))
			elif s == dec:
				mats.append(GuerrierNordique.materiau(MageTextures.tex("decoupes"), true, true, false, "mage_dec"))
			else:
				mats.append(MageNordique.materiau_cristal())
		var mi := MeshInstance3D.new()
		mi.name = "accessoires"
		mi.mesh = mesh
		mi.skin = skin
		mi.skeleton = NodePath("..")
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i])
		return mi

## Cristal : shader du guerrier, émission froide modérée (lisible de nuit, pas de halo), liseré froid fort, pas de contour noir.
static func materiau_cristal() -> ShaderMaterial:
	if _mats.has("cristal"):
		return _mats["cristal"]
	var m := ShaderMaterial.new()
	m.shader = GuerrierNordique.shader(false)
	m.set_shader_parameter("tex_base", MageTextures.tex("cristal"))
	m.set_shader_parameter("emission", Color(0.16, 0.34, 0.70))
	m.set_shader_parameter("appoint", Vector3(0.35, 0.40, 0.50))
	m.set_shader_parameter("contour_froid", Vector3(0.30, 0.45, 0.70))
	m.set_shader_parameter("ombre_force", 0.3)
	Palette.materiaux.append(m)
	Palette._appliquer(m, Palette._ps1_actif)
	_mats["cristal"] = m
	return m
