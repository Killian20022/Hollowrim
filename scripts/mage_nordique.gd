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

const TEINTE_BARBE := Color(0.68, 0.68, 0.69)
const PEAU := Color(0.52, 0.41, 0.36)
## fourrure du manteau : gris plus sombre que celle du guerrier (la référence est sombre ; la fourrure claire volait la vedette au cristal)
const TEINTE_FOURRURE := Color(0.70, 0.71, 0.76)
## passe 2 : la fourrure n'est plus qu'un col (bordure de la capuche), crème / gris chaud (harmonisation des archétypes : au
## crépuscule la lumière froide la bleuit déjà) ; teinte cuite dans l'atlas des découpes (le tissu effiloché partage la surface).
const TEINTE_COL := Color(1.0, 0.93, 0.80)

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
	var tenue := {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "mante": C}
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
	# passe 2 : la mante devient une PÈLERINE de laine anthracite par-dessus la robe (plus de fourrure) : allongée vers le bas et
	# un peu évasée (elle couvre le haut des bras), ouverte au milieu du devant (amulette, bande brodée) ; frange effilochée plus bas
	_habiller(pieces["mante"], GuerrierNordique.materiau(MageTextures.tex("pelerine"), true, false, true, "mage_pelerine"))
	_deformer(pieces["mante"], func(p: Vector3) -> Vector3:
		var t := clampf((1.50 - p.y) / 0.20, 0.0, 1.0)
		var r := Vector2(p.x, p.z + 0.02)
		var e := r.normalized() * 0.035 * t
		return Vector3(p.x + e.x, p.y - 0.07 * t, p.z + e.y))
	GuerrierNordique._filtrer(pieces["mante"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > 0.03 and absf(c.x) < 0.075 + maxf(0.0, 1.50 - c.y) * 0.25 and c.y < 1.52))
	if pieces.has("capuche") and options.get("capuche", true):
		_habiller(pieces["capuche"], GuerrierNordique.materiau(MageTextures.tex("capuche")))
		# capuche ouverte devant (le pan qui couvrait le menton et le cou est retiré : la barbe sort de la capuche comme sur la
		# référence), sommet relevé et tiré en arrière (léger pic), bord avant avancé au-dessus du front (visage dans l'ombre)
		GuerrierNordique._filtrer(pieces["capuche"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > -0.01 and absf(c.x) < 0.105 + maxf(0.0, 1.58 - c.y) * 0.6 and c.y < 1.665))
		_deformer(pieces["capuche"], func(p: Vector3) -> Vector3:
			var t := smoothstep(1.74, 1.86, p.y) * smoothstep(0.06, -0.10, p.z)
			var f := smoothstep(1.68, 1.78, p.y) * smoothstep(0.02, 0.10, p.z)
			# passe 2 : capuche PROFONDE — tout l'avant (au-dessus de la bouche) avancé de 4 cm et élargi : le visage recule dans l'ombre
			var a := smoothstep(1.58, 1.66, p.y) * smoothstep(-0.02, 0.08, p.z)
			return p + Vector3(0, 0.045 * t, -0.035 * t) + Vector3(0, -0.012 * f, 0.022 * f) + Vector3(p.x * 0.18 * a, 0, 0.040 * a))
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
		# passe 3 : barbe COURTE (x 1,15), rabattue contre la poitrine (aucune pointe en avant : fini le « bec » de masque de peste)
		_deformer(mi_b, func(p: Vector3) -> Vector3:
			var d := maxf(0.0, 1.635 - p.y)
			var t := d / 0.08
			return Vector3(p.x * (1.0 - 0.10 * clampf(t, 0.0, 1.0)), 1.635 - d * 1.15, p.z - d * 0.35))
		GuerrierNordique._uv_barbe(mi_b)
		mi_b.material_override = GuerrierNordique.materiau(MageTextures.tex("barbe"), true, false, false, "mage_barbe")
		(mi_b.material_override as ShaderMaterial).set_shader_parameter("appoint", Vector3(0.06, 0.06, 0.07))
		(mi_b.material_override as ShaderMaterial).set_shader_parameter("teinte", Color(0.62, 0.62, 0.64))
	# la tunique s'arrête sous la ceinture (la jupe modelée prend le relais) ; le pantalon reste (vu sous la robe à la mort)
	GuerrierNordique._filtrer(pieces["tunique"], func(c: Vector3, n: Vector3) -> bool: return c.y > 0.93)
	_t("matieres", t0)
	var rest_skin := sq.create_skin_from_rest_transforms()
	var acc := Acc.new(sq)
	var A := Vector2(MageTextures.ATLAS)
	acc.robe(pieces["tunique"], pieces["pantalon"])
	var jupe := MageJupe.new()
	var mat_acc := GuerrierNordique.materiau(MageTextures.tex("accessoires"), false, false, true, "mage_acc")
	# passe 3 : liseré froid plus fort sur la robe et la pèlerine (la silhouette ne forme plus une masse noire à 4-8 m)
	mat_acc.set_shader_parameter("contour_froid", Vector3(0.36, 0.48, 0.68))
	(pieces["mante"].material_override as ShaderMaterial).set_shader_parameter("contour_froid", Vector3(0.30, 0.40, 0.58))
	jupe.preparer(sq, acc.jupe, mat_acc)
	sq.add_child(jupe)
	# pantalon (vu sous la robe à la mort, au saut) versé dans l'atlas (région R_PANTALON : ses UV tels quels) : une surface de moins
	acc.integrer(pieces["pantalon"], acc.op, func(uv: Vector2) -> Vector2:
		return (Vector2(MageTextures.R_PANTALON.position) + uv * Vector2(MageTextures.R_PANTALON.size)) / A)
	pieces["pantalon"].visible = false
	_t("robe", t0)
	acc.integrer(pieces["ceinture"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, clampf((uv.y - 0.698) / 0.302, 0.0, 1.0) * 15.6 + 0.2 + GuerrierTextures.R_CEINT.position.y) / A,
		func(p: Vector3, n: Vector3) -> Vector3: return Vector3(p.x, 0.985 + (p.y - 0.985) * 1.6, p.z) + n * 0.030)
	pieces["ceinture"].visible = false
	# passe 2 : manches larges évasées à bord effiloché, frange effilochée de la pèlerine, col de fourrure au bas de la capuche
	acc.manches(pieces["tunique"])
	acc.frange_tissu(pieces["mante"], 1.10, 1.47, 0.09, 0.17)
	if pieces.has("capuche") and options.get("capuche", true):
		acc.poitrine_libre = true
		acc.fourrure_bord(pieces["capuche"], 1.44, 1.58, 0.06, 0.10, 0.7, 1.8)
		acc.poitrine_libre = false
	# visage dans l'ombre de la capuche : la peau du visage (front -> lèvre) devient un masque quasi noir ; yeux bleus luisants
	acc.masque(pieces["peau"])
	GuerrierNordique._filtrer(pieces["peau"], func(c: Vector3, n: Vector3) -> bool: return not Acc.est_visage(c))
	acc.yeux_luisants(yeux)
	acc.amulette(pieces["tunique"])
	acc.pierre_ceinture()
	acc.boucle_ceinture()
	if options.get("baton", true):
		acc.baton()
	_t("accessoires (geometrie)", t0)
	var mi_acc := acc.construire(rest_skin)
	sq.add_child(mi_acc)
	_t("accessoires (materiaux)", t0)
	if options.get("baton", true):
		var bd := BatonDroit.new()
		bd.name = "BatonDroit"
		var info: Array = sq.get_meta("baton")
		bd.os_ = info[0]
		bd.prise = sq.get_bone_global_rest(info[0]).affine_inverse() * (info[1] as Transform3D)
		sq.add_child(bd)
	# tissus noirs : lumière propre un peu plus forte que le guerrier (le côté à l'ombre garde ses plis et ses broderies au
	# lieu de tomber en aplat noir) ; matériaux propres au mage
	for m in [pieces["tunique"].material_override, pieces["mante"].material_override, mi_acc.get_surface_override_material(0), mi_acc.get_surface_override_material(1), jupe.mat]:
		(m as ShaderMaterial).set_shader_parameter("appoint", Vector3(0.12, 0.155, 0.23))
	if pieces.has("capuche") and options.get("capuche", true):
		(pieces["capuche"].material_override as ShaderMaterial).set_shader_parameter("appoint", Vector3(0.05, 0.06, 0.085))
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
					m2.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * Color(0.86, 0.84, 0.86))
					m2.set_shader_parameter("appoint", Vector3(0.05, 0.05, 0.07))
					m2.set_shader_parameter("contour_froid", Vector3(0.22, 0.27, 0.38))
				Palette.materiaux.append(m2)
				Palette._appliquer(m2, Palette._ps1_actif)
				_mats[cle] = m2
			mi.set_surface_override_material(s, _mats[cle])

# ======================================================================================================== accessoires
## Atlas du mage (MageTextures.ATLAS, 256 x 512) pour la surface opaque ; atlas des découpes de même mise en page que le guerrier ;
## 3e surface : cristal émissif.
class Acc extends GuerrierNordique.Accessoires:
	## surface lumineuse (shader mage_orbe) : + couleur (genre / phase des particules) et UV2 (coin des quads de particules)
	var cri := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "c": PackedColorArray(), "uv2": PackedVector2Array()}
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

	## Boucle de ceinture (plaque de fer cerclée avec une pierre runique au centre) et deux pans de lanière qui pendent devant,
	## comme la ceinture ouvragée de la référence. Poids du bassin (la jupe en dessous est repoussée plus loin que la plaque).
	func boucle_ceinture() -> void:
		# devant de la ceinture : secteur 0 de l'anneau haut de la jupe (la projection sur la tunique tombe dans le trou de la ceinture)
		var poids := sq.find_bone("spine_01")
		var haut: Vector3 = jupe[0][0]
		var n := Vector3(0, 0.03, 1.0).normalized()
		var c := Vector3(0.0, 0.985, haut.z + 0.014)
		var cote := Vector3.UP.cross(n).normalized()
		var tr := Transform3D(Basis(cote, Vector3.UP, n), c)
		_boite_region(Vector3(-0.040, -0.030, -0.006), Vector3(0.040, 0.030, 0.006), tr, poids, GuerrierTextures.R_FER)
		var tr2 := Transform3D(Basis(cote, Vector3.UP, n), c + n * 0.007)
		_boite_region(Vector3(-0.019, -0.019, -0.005), Vector3(0.019, 0.019, 0.005), tr2, poids, MageTextures.R_PIERRE)
		# pans de lanière : deux rubans de cuir, l'un plus long, légèrement ouverts
		for k in 2:
			var s := -1.0 if k == 0 else 1.0
			var l0 := c + cote * (0.012 * s) - Vector3(0, 0.024, 0) + n * 0.002
			var l1 := l0 + Vector3(0, -(0.10 + 0.05 * k), 0) + cote * (0.012 * s) + n * 0.012
			_quad(op, l0 - cote * 0.011, l0 + cote * 0.011, l1 + cote * 0.011, l1 - cote * 0.011,
				_uva(32 + 2, 2), _uva(32 + 6, 2), _uva(32 + 6, 14), _uva(32 + 2, 14), poids, l0 - n * 0.1)

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

	# ------------------------------------------------------------ visage dans l'ombre, yeux luisants
	## Triangle de la peau qui appartient au visage sous la capuche (du front à la lèvre supérieure ; la barbe couvre le reste).
	static func est_visage(c: Vector3) -> bool:
		return c.y > 1.612 and c.y < 1.80 and c.z > 0.015 and absf(c.x) < 0.088

	## Copie les triangles du visage de la peau dans la surface opaque, texturés par R_MASQUE (quasi noir), gonflés de 2 mm.
	func masque(peau: MeshInstance3D) -> void:
		var a := peau.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := bones.size() / v.size()
		var r := MageTextures.R_MASQUE
		var os_de := {}
		for t in range(0, idx.size(), 3):
			if not est_visage((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0):
				continue
			for k in 3:
				var i := idx[t + k]
				op["v"].append(v[i] + nrm[i] * 0.002)
				op["n"].append(nrm[i])
				op["uv"].append(_uva(r.position.x + 2.0 + (i % 11), r.position.y + 2.0 + (i % 7)))
				var bo := [0, 0, 0, 0]
				var wo := [0.0, 0.0, 0.0, 0.0]
				for j in mini(nb, 4):
					var bb := bones[i * nb + j]
					if not os_de.has(bb):
						os_de[bb] = maxi(0, GuerrierNordique._os_de_bind(peau.skin, sq, bb))
					bo[j] = os_de[bb]
					wo[j] = w[i * nb + j]
				op["b"].append_array(PackedInt32Array(bo))
				op["w"].append_array(PackedFloat32Array(wo))

	## Deux fentes bleues luisantes (surface lumineuse) devant le masque, à la place des yeux.
	func yeux_luisants(centres: Array) -> void:
		var os_ := sq.find_bone("Head")
		var r := MageTextures.O_OEIL
		for c: Vector3 in centres:
			var cote := signf(c.x)
			var p := Vector3(c.x * 0.95, c.y - 0.002, c.z + 0.006)
			var dx := Vector3(0.013, 0, -0.003 * cote)
			var dy := Vector3(0, 0.0058, 0)
			_quad_cri(p - dx - dy, p + dx - dy, p + dx + dy, p - dx + dy, _uvo(r.position.x, r.end.y), _uvo(r.end.x, r.end.y), _uvo(r.end.x, r.position.y), _uvo(r.position.x, r.position.y), os_, Color(0, 0, 0, 1), [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

	# ------------------------------------------------------------ manches larges évasées, bord effiloché (surface découpée)
	## Cône à 10 pans du dessus du coude jusqu'au-delà du poignet (rayon 7 -> 14 cm), côté dessous plus long (le tissu pend),
	## texture D_EFFILOCHE (laine noire, bande de runes bleu pâle, lanières découpées au bord) ; double face.
	func manches(tunique: MeshInstance3D) -> void:
		var a := tunique.mesh.surface_get_arrays(0)
		var R := MageTextures.D_EFFILOCHE
		var D := Vector2(GuerrierTextures.DECOUPES)
		var N := 10
		for c in ["l", "r"]:
			var e := sq.get_bone_global_rest(sq.find_bone("lowerarm_" + c)).origin
			var m := sq.get_bone_global_rest(sq.find_bone("hand_" + c)).origin
			var ax := (m - e).normalized()
			var x := Vector3.UP
			var y := ax.cross(x).normalized()
			# anneaux : [centre, rayon, allongement du dessous, v]
			var anneaux := [[e - ax * 0.07, 0.068, 0.0, 0.0], [e + ax * 0.10, 0.088, 0.02, 0.35], [e + ax * 0.19, 0.118, 0.06, 0.62], [m + ax * 0.04, 0.158, 0.15, 1.0]]
			var pts := []
			var pds := []
			for k in anneaux.size():
				var an: Array = anneaux[k]
				var ligne := []
				var lp := []
				for i in N + 1:
					var ang := TAU * i / N
					var d := x * cos(ang) + y * sin(ang)
					var dessous := maxf(0.0, -d.y)
					var p: Vector3 = an[0] + d * float(an[1]) + ax * float(an[2]) * dessous + Vector3.DOWN * 0.05 * float(an[3]) * dessous
					ligne.append(p)
					lp.append(_poids_proche(tunique, a, p) if k == 0 else sq.find_bone("lowerarm_" + c))
				pts.append(ligne)
				pds.append(lp)
			for k in anneaux.size() - 1:
				var v0: float = R.position.y + R.size.y * float(anneaux[k][3])
				var v1: float = R.position.y + R.size.y * float(anneaux[k + 1][3]) - 0.5
				var centre: Vector3 = (anneaux[k][0] + anneaux[k + 1][0]) * 0.5
				for i in N:
					var u0 := (R.position.x + R.size.x * float(i) / N) / D.x
					var u1 := (R.position.x + R.size.x * float(i + 1) / N) / D.x
					var w4: Variant = [pds[k][i], pds[k][i + 1], pds[k + 1][i + 1], pds[k + 1][i]]
					var tous_int := true
					for q in w4:
						tous_int = tous_int and q is int
					if tous_int:
						w4 = [[PackedInt32Array([w4[0], 0, 0, 0]), PackedFloat32Array([1.0, 0, 0, 0])], [PackedInt32Array([w4[1], 0, 0, 0]), PackedFloat32Array([1.0, 0, 0, 0])], [PackedInt32Array([w4[2], 0, 0, 0]), PackedFloat32Array([1.0, 0, 0, 0])], [PackedInt32Array([w4[3], 0, 0, 0]), PackedFloat32Array([1.0, 0, 0, 0])]]
					else:
						for j in 4:
							if w4[j] is int:
								w4[j] = [PackedInt32Array([w4[j], 0, 0, 0]), PackedFloat32Array([1.0, 0, 0, 0])]
					_quad(dec, pts[k][i], pts[k][i + 1], pts[k + 1][i + 1], pts[k + 1][i], Vector2(u0, v0 / D.y), Vector2(u1, v0 / D.y), Vector2(u1, v1 / D.y), Vector2(u0, v1 / D.y), w4, centre)

	# ------------------------------------------------------------ frange effilochée de la pèlerine
	## Une carte de tissu effiloché par bord libre BAS de `mi` (y entre y0 et y1, hors ouverture du devant), pendant vers le bas
	## et un peu vers l'extérieur, longueur lg0-lg1 ; tranche de 16 texels prise au hasard dans D_EFFILOCHE (haut = laine).
	func frange_tissu(mi: MeshInstance3D, y0: float, y1: float, lg0: float, lg1: float) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var aretes := {}
		var refs := {}
		for t in range(0, idx.size(), 3):
			var ct := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			for k in 3:
				var i0: int = idx[t + k]
				var i1: int = idx[t + (k + 1) % 3]
				var p0 := v[i0].snapped(Vector3.ONE * 0.0005)
				var p1 := v[i1].snapped(Vector3.ONE * 0.0005)
				var cle := [p0, p1] if str(p0) < str(p1) else [p1, p0]
				aretes[cle] = int(aretes.get(cle, 0)) + 1
				refs[cle] = [i0, i1, ct]
		var R := MageTextures.D_EFFILOCHE
		var D := Vector2(GuerrierTextures.DECOUPES)
		var n := 0
		for cle in aretes:
			if aretes[cle] != 1:
				continue
			var p0 := v[refs[cle][0]]
			var p1 := v[refs[cle][1]]
			var ct: Vector3 = refs[cle][2]
			var m := (p0 + p1) * 0.5
			# bord BAS seulement (le triangle est au-dessus de l'arête), hors du devant ouvert
			if m.y < y0 or m.y > y1 or ct.y < m.y + 0.004 or (m.z > 0.03 and absf(m.x) < 0.10):
				continue
			var cote := p1 - p0
			var lc := cote.length()
			if lc < 0.004:
				continue
			cote /= lc
			var ext := Vector3(m.x, 0.0, m.z + 0.02).normalized()
			var dir := (Vector3.DOWN + ext * 0.22).normalized()
			var lg := lerpf(lg0, lg1, _h(n))
			var larg := maxf(lc * 1.35, 0.03)
			var g := m - cote * larg * 0.5 - dir * 0.03 + ext * 0.003
			var d := m + cote * larg * 0.5 - dir * 0.03 + ext * 0.003
			var u0 := (R.position.x + floorf(_h(n + 7) * 6.0) * 16.0) / D.x
			var u1 := u0 + 16.0 / D.x
			var pr := _poids_proche(mi, a, m)
			var pb := _poids_proche(mi, a, m + dir * lg * 0.6)
			_quad(dec, g, d, d + dir * lg, g + dir * lg, Vector2(u0, (R.position.y + 22.0) / D.y), Vector2(u1, (R.position.y + 22.0) / D.y), Vector2(u1, (R.end.y - 0.5) / D.y), Vector2(u0, (R.end.y - 0.5) / D.y), [pr, pr, pb, pb], m - ext * 0.1)
			n += 1

	# ------------------------------------------------------------ bâton runique (main droite)
	## Repère local : prise à l'origine, hampe le long de +y. Pied à -0,86 m (au sol), tête sculptée à +0,70 m, FOURCHE de quatre
	## griffes de bois qui s'écartent puis se referment sur un gros ORBE de glace (rayon 7 cm, centre +0,93 m : au-dessus de la
	## capuche), rune gravée ; étincelles qui montent et runes qui tournent autour (particules du shader mage_orbe).
	const Y_ORBE := 0.955
	const R_ORBE := 0.086

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
		# tête sculptée : nœud qui s'évase (départ de la fourche)
		_tube(op, L.call(0.70), L.call(0.80), 0.022, 0.034, 6, os_, MageTextures.R_TETE, 1)
		# fourche : quatre griffes épaisses qui enserrent l'orbe (s'écartent, montent, se referment au-dessus de l'équateur)
		for k in 4:
			var ang := TAU * k / 4.0 + PI / 4.0
			var dh := Vector3(cos(ang), 0, sin(ang))
			var q0 := tr * (dh * 0.026 + Vector3(0, 0.79, 0))
			var q1 := tr * (dh * 0.088 + Vector3(0, 0.865, 0))
			var q2 := tr * (dh * 0.099 + Vector3(0, Y_ORBE + 0.01, 0))
			var q3 := tr * (dh * 0.055 + Vector3(0, Y_ORBE + 0.090, 0))
			_tube(op, q0, q1, 0.013, 0.011, 4, os_, MageTextures.R_TETE, 1)
			_tube(op, q1, q2, 0.011, 0.009, 4, os_, MageTextures.R_TETE, 1)
			_tube(op, q2, q3, 0.009, 0.004, 4, os_, MageTextures.R_TETE, 1)
		# orbe : sphère UV 10 x 6 (surface lumineuse)
		var c := tr * Vector3(0, Y_ORBE, 0)
		var NU := 10
		var NV := 6
		var S := MageTextures.O_SPHERE
		var noir := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		var P := func(i: int, j: int) -> Vector3:
			var th := PI * j / NV
			var ph := TAU * i / NU
			return c + tr.basis * Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * R_ORBE
		for j in NV:
			for i in NU:
				var u0 := S.position.x + S.size.x * float(i) / NU
				var u1 := S.position.x + S.size.x * float(i + 1) / NU
				var v0 := S.position.y + S.size.y * float(j) / NV
				var v1 := S.position.y + S.size.y * float(j + 1) / NV
				_quad_cri(P.call(i, j), P.call(i + 1, j), P.call(i + 1, j + 1), P.call(i, j + 1), _uvo(u0, v0), _uvo(u1, v0), _uvo(u1, v1), _uvo(u0, v1), os_, Color(0, 0, 0, 1), noir, c)
		# étincelles (10) et runes qui tournent (3) : quads au centre de l'orbe, mis en mouvement par le shader
		var E := MageTextures.O_ETINCELLE
		for k in 10:
			var ph := fmod(float(k) * 0.618, 1.0)
			_particule(c + tr.basis * Vector3(0, R_ORBE * 0.6, 0), E, 0.016, os_, Color(ph, 0.5, _h(k), 1.0))
		var RU := MageTextures.O_RUNES
		for k in 3:
			var reg := Rect2i(RU.position + Vector2i((k % 2) * 16, (k / 2) * 16), Vector2i(16, 16))
			_particule(c, reg, 0.030, os_, Color(float(k) / 3.0, 1.0, 0.0, 1.0))

	## UV (texels) de la texture de l'orbe (64 x 64).
	func _uvo(x: float, y: float) -> Vector2:
		return Vector2(x / 64.0, y / 64.0)

	## Quad de la surface lumineuse (sommets a b c d, couleur = genre/phase, uv2 = coins) ; peau rigide sur un os.
	func _quad_cri(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, os_: int, col: Color, coins: Array, dedans := Vector3.INF) -> void:
		var pts := [a, b, c, d]
		var uvs := [ua, ub, uc, ud]
		var n := (c - a).cross(b - a)
		if n.length() > 1e-9:
			n = n.normalized()
			if dedans != Vector3.INF and n.dot((a + c) * 0.5 - dedans) < 0.0:
				n = -n
		for k: int in [0, 1, 2, 0, 2, 3]:
			cri["v"].append(pts[k])
			cri["n"].append(n if dedans == Vector3.INF else ((pts[k] - dedans).normalized()))
			cri["uv"].append(uvs[k])
			cri["b"].append_array([os_, 0, 0, 0])
			cri["w"].append_array([1.0, 0.0, 0.0, 0.0])
			cri["c"].append(col)
			cri["uv2"].append(coins[k])

	## Particule : 4 sommets au même point p, coins (+-taille) en UV2, région r de la texture de l'orbe.
	func _particule(p: Vector3, r: Rect2i, taille: float, os_: int, col: Color) -> void:
		_quad_cri(p, p, p, p, _uvo(r.position.x, r.end.y), _uvo(r.end.x, r.end.y), _uvo(r.end.x, r.position.y), _uvo(r.position.x, r.position.y), os_, col,
			[Vector2(-taille, -taille), Vector2(taille, -taille), Vector2(taille, taille), Vector2(-taille, taille)])

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
			if s == cri:
				arr[Mesh.ARRAY_COLOR] = s["c"]
				arr[Mesh.ARRAY_TEX_UV2] = s["uv2"]
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

## Surface lumineuse (orbe, yeux, particules) : shader mage_orbe (même accroche PS1), lueur portée par la texture.
const SHADER_ORBE := preload("res://shaders/mage_orbe.gdshader")

static func materiau_cristal() -> ShaderMaterial:
	if _mats.has("cristal"):
		return _mats["cristal"]
	var m := ShaderMaterial.new()
	m.shader = SHADER_ORBE
	m.set_shader_parameter("tex_base", MageTextures.tex("orbe"))
	m.set_shader_parameter("emission", Color(0.04, 0.08, 0.16))
	Palette.materiaux.append(m)
	Palette._appliquer(m, Palette._ps1_actif)
	_mats["cristal"] = m
	return m

## Garde le bâton DROIT quelle que soit l'animation (Idle, marche, lancement de sort : la main droite y tourne de ~20°) :
## après l'animation, la main droite pivote autour de la prise pour ramener l'axe du bâton à la verticale. Correction effacée
## quand le corps bascule de plus de 35-55° (chute, mort, ragdoll : le bâton suit la main). Aucun os ajouté, animations partagées intactes.
class BatonDroit extends SkeletonModifier3D:
	var os_ := -1
	var pelvis := -1
	var prise := Transform3D()

	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq == null or os_ < 0:
			return
		var H := PiedsAuSol.pose_globale(sq, os_)
		var S := H * prise
		var axe := S.basis.y.normalized()
		var ang := axe.angle_to(Vector3.UP)
		if ang < 0.003:
			return
		# effacée seulement quand le CORPS bascule (chute, mort, ragdoll) : en course le bras porte le bâton très incliné (~80°),
		# il est redressé aussi
		if pelvis < 0:
			pelvis = sq.find_bone("pelvis")
		var bassin := PiedsAuSol.pose_globale(sq, pelvis).basis
		var bascule := (bassin * sq.get_bone_global_rest(pelvis).basis.inverse()).y.normalized().angle_to(Vector3.UP)
		var w := 1.0 - smoothstep(deg_to_rad(35.0), deg_to_rad(55.0), bascule)
		if w <= 0.0:
			return
		var q := Quaternion().slerp(Quaternion(axe, Vector3.UP), w)
		var b := Basis(q)
		PiedsAuSol.poser_globale(sq, os_, Transform3D(b * H.basis, S.origin + b * (H.origin - S.origin)))
