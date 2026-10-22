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
## Posture d'archer (passe 2) : pendant les clips Pistol_Aim_Neutral (visée) et Pistol_Shoot (tir), un SkeletonModifier3D
## (PoseArcher) remplace le haut du corps du clip par une vraie pose d'archer calculée à la construction (IK analytique à deux os) :
## buste tourné épaule gauche vers la cible, bras GAUCHE tendu qui tient l'arc, main DROITE à l'ancrage sous la joue droite.
## L'arc bandé (« arc_vise ») est porté par la main gauche ; le point d'encoche de la corde et l'arrière de la flèche sont
## pondérés sur la main droite : la corde est réellement tirée vers la main droite (deux brins en V) et la flèche encochée reste
## entre les deux mains. Au tir (Pistol_Shoot après LACHER s), la main droite part en arrière et l'arc relâché (« arc_relache »,
## corde droite, sans flèche) prend le relais. Hors visée, l'arc est porté le long du corps dans la main gauche (« arc_porte »),
## comme sur la référence. L'échange se fait tout seul (signal de l'AnimationPlayer + PoseArcher).

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
	_habiller(pieces["bottes"], GuerrierNordique.materiau(ChasseresseTextures.tex("bottes")))
	_habiller(pieces["brassards"], GuerrierNordique.materiau(ChasseresseTextures.tex("brassards")))
	_habiller(pieces["mante"], GuerrierNordique.materiau(ChasseresseTextures.tex("mante")))
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
		# passe 2 : les longueurs du dos sont rentrées dans la capuche rabattue (la capuche et les tresses se lisent de dos)
		GuerrierNordique._filtrer(mi_ch, func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002 and not (c.y < 1.50 and c.z < 0.0))
		GuerrierNordique._decimer(mi_ch, func(p: Vector3) -> float: return 0.03)
		var src: Texture2D = (mi_ch.material_override as ShaderMaterial).get_shader_parameter("tex_base")
		mi_ch.material_override = GuerrierNordique.materiau(ChasseresseTextures.cheveux(src), true, false, true, "cheveux_chasseresse")
	_t("matieres", t0)
	# silhouette plus élancée (passe 2) : jupe et cuisses resserrées vers l'axe de chaque jambe, taille marquée
	_deformer(pieces["tunique"], func(q: Vector3) -> Vector3:
		var f := 1.0 - 0.10 * smoothstep(1.02, 0.80, q.y)
		var t := 1.0 - 0.05 * smoothstep(1.10, 0.98, q.y) * smoothstep(0.86, 0.98, q.y)
		return Vector3(q.x * f * t, q.y, q.z * (0.5 + 0.5 * f) * t))
	_deformer(pieces["pantalon"], func(q: Vector3) -> Vector3:
		var f := 1.0 - 0.09 * smoothstep(0.46, 0.62, q.y) * (1.0 - smoothstep(0.96, 1.05, q.y))
		var cx := signf(q.x) * 0.095
		return Vector3(cx + (q.x - cx) * f, q.y, q.z * f))
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
	acc.dos_libre = true
	acc.fourrure_bord(pieces["mante"], 1.22, 1.42, 0.085, 0.145, 1.0, 1.7)
	acc.gros = 1.9
	acc.fourrure_surface(pieces["mante"], 1.32, 1.56, 0.07, 0.115, 22)
	acc.gros = 1.0
	acc.dos_libre = false
	acc.poitrine_libre = false
	acc.fourrure_bord(pieces["bottes"], 0.30, 0.45, 0.06, 0.09, 1.0, 1.6)
	acc.frange(pieces["tunique"], func(m: Vector3) -> bool: return m.y < 0.72, 0.05, 0.08, Vector3.DOWN, 1.5)
	var xin := 9.0
	for p in (pieces["brassards"].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		xin = minf(xin, absf(p.x))
	acc.frange(pieces["brassards"], func(m: Vector3) -> bool: return absf(m.x) < xin + 0.03, 0.05, 0.075, Vector3.ZERO, 1.8)
	acc.boucle_rect(Vector3(0.0, 0.966, 0.124))
	acc.fibule_sur(pieces["mante"], pieces["tunique"], Vector2(-0.115, 1.40))
	acc.yeux(yeux)
	acc.tresses()
	acc.capuche()
	if options.get("carquois", true):
		acc.carquois()
	if options.get("couteau", true):
		acc.couteau()
	_t("accessoires (geometrie)", t0)
	sq.add_child(acc.construire(rest_skin, "accessoires"))
	# arc : trois maillages (porté main gauche / bandé main gauche + corde et flèche tirées par la main droite / relâché),
	# un seul visible à la fois ; PoseArcher pose le haut du corps pendant la visée et le tir
	if options.get("arc", true):
		var posture := Posture.new(sq)
		var pose := posture.calculer()
		var hl := sq.find_bone("hand_l")
		var hr := sq.find_bone("hand_r")
		var Ml: Transform3D = sq.get_bone_global_rest(hl) * posture.glob(hl).affine_inverse()      # pose de visée -> repos (main G)
		var Mr: Transform3D = sq.get_bone_global_rest(hr) * posture.glob(hr).affine_inverse()      # pose de visée -> repos (main D)
		var porte := Acc.new(sq)
		var tr_porte := porte.repere_porte()
		var tr_vise: Transform3D = Ml * posture.repere_arc
		sq.set_meta("arc_porte", [hl, tr_porte])     # contrôle des traversées (outils/test_chasseresse.gd)
		sq.set_meta("arc_vise", [hl, tr_vise])
		sq.set_meta("corde_encoche", [hr, Transform3D(Basis(), Mr * posture.encoche)])
		porte.arc(tr_porte, hl)
		var mi_porte := porte.construire(rest_skin, "arc_porte")
		var vise := Acc.new(sq)
		vise.arc(tr_vise, hl, 0.165, false)
		vise.corde_bandee(tr_vise, hl, 0.165, Mr * posture.encoche, hr, Ml, Mr, posture)
		vise.fleche_encochee(posture, Ml, Mr, hl, hr)
		var mi_vise := vise.construire(rest_skin, "arc_vise")
		var relache := Acc.new(sq)
		relache.arc(tr_vise, hl)
		var mi_relache := relache.construire(rest_skin, "arc_relache")
		for mi: MeshInstance3D in [mi_porte, mi_vise, mi_relache]:
			sq.add_child(mi)
		mi_vise.visible = false
		mi_relache.visible = false
		var mod := PoseArcher.new()
		mod.name = "PoseArcher"
		mod.ap = racine.get_node("Animations") as AnimationPlayer
		mod.regler(sq, pose)
		mod.mi_porte = mi_porte
		mod.mi_vise = mi_vise
		mod.mi_relache = mi_relache
		sq.add_child(mod)
		var ap := racine.get_node("Animations") as AnimationPlayer
		ap.current_animation_changed.connect(func(nom: StringName) -> void:
			if is_instance_valid(mod):
				mod.visibilites(String(nom), 0.0))
	_t("accessoires (materiaux)", t0)
	racine.set_meta("chasseresse_nordique", true)
	return racine

## Déplace les sommets de `mi` par f(p) (même peau d'os, mêmes UV ; normales gardées : déformation douce).
static func _deformer(mi: MeshInstance3D, f: Callable) -> void:
	if mi == null:
		return
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nb: int = (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / v.size() if a[Mesh.ARRAY_BONES] != null else 4
	for i in v.size():
		v[i] = f.call(v[i])
	a[Mesh.ARRAY_VERTEX] = v
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mat := mi.get_surface_override_material(0)
	mi.mesh = m
	if mat:
		mi.set_surface_override_material(0, mat)

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


# ======================================================================================================== pose d'archer
## Bassin du clip Pistol_Aim_Neutral (identique dans Pistol_Shoot), mesuré (outils/sonde_pose_archer.gd) : les poses locales
## calculées ici sont relatives au bassin, la pose reste juste quel que soit le bassin du clip.
const BASSIN_VISEE := Transform3D(Basis(Vector3(0.973081, 0.0, 0.230462), Vector3(-0.035619, 0.987984, 0.150394), Vector3(-0.227693, -0.154554, 0.961389)), Vector3(0.002922, 0.877129, -0.086232))
const OS_POSE := ["spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
## Instant du lâcher dans Pistol_Shoot (s) et durée du retour de la main droite.
const LACHER := 0.06
const RECUL := 0.10

## Calcule la pose d'archer (poses locales des os de OS_POSE), dans l'espace du squelette, cible droit devant (+z) :
## torsion du buste (épaule gauche vers la cible), tête qui regarde la cible, IK à deux os pour chaque bras.
class Posture:
	var sq: Skeleton3D
	var loc := {}
	var bassin := -1
	var dir := Vector3(0, 0, 1)          # axe de la flèche
	var prise := Vector3.ZERO            # milieu de la poignée de l'arc (main gauche)
	var encoche := Vector3.ZERO          # point d'encoche (doigts de la main droite)
	var repere_arc := Transform3D()      # repère de l'arc bandé (y le long de l'arc, +z = dos de l'arc, vers la cible)
	const TORSION := [-13.0, -14.0, -15.0]
	const PAUME := 0.075                 # du poignet au creux de la main
	const ALLONGE := 0.548               # épaule -> poignée (bras presque tendu)

	func _init(s: Skeleton3D) -> void:
		sq = s
		bassin = sq.find_bone("pelvis")
		for i in sq.get_bone_count():
			loc[i] = sq.get_bone_rest(i)

	func glob(i: int) -> Transform3D:
		var t := Transform3D()
		while i >= 0:
			if i == bassin:
				return ChasseresseNordique.BASSIN_VISEE * t
			t = loc[i] * t
			i = sq.get_bone_parent(i)
		return t

	func _poser(nom: String, b: Basis) -> void:
		var i := sq.find_bone(nom)
		var pg := glob(sq.get_bone_parent(i))
		loc[i] = Transform3D(pg.basis.orthonormalized().inverse() * b.orthonormalized(), loc[i].origin)

	func _repos(nom: String) -> Basis:
		return sq.get_bone_global_rest(sq.find_bone(nom)).basis.orthonormalized()

	## IK à deux os : épaule (upperarm) -> coude -> poignet en `cible`, coude du côté `pole` ; la main prend le repère `main`.
	func _bras(cote: String, cible: Vector3, pole: Vector3, main: Basis) -> void:
		var iu := sq.find_bone("upperarm_" + cote)
		var il := sq.find_bone("lowerarm_" + cote)
		var ih := sq.find_bone("hand_" + cote)
		var a: float = (loc[il] as Transform3D).origin.length()
		var b: float = (loc[ih] as Transform3D).origin.length()
		var S := glob(iu).origin
		var d := clampf(S.distance_to(cible), 0.05, a + b - 0.002)
		var u := (cible - S).normalized()
		var v := (pole - u * pole.dot(u)).normalized()
		var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
		var E := S + u * a * ca + v * a * sqrt(1.0 - ca * ca)
		var W := S + u * d
		for paire: Array in [[iu, E - S], [il, W - E]]:
			var i: int = paire[0]
			var g := glob(i).basis.orthonormalized()
			var y: Vector3 = (paire[1] as Vector3).normalized()
			var q := Quaternion(g.y.normalized(), y)
			_poser(sq.get_bone_name(i), Basis(q) * g)
		_poser("hand_" + cote, main)

	func _main(y: Vector3, haut: Vector3) -> Basis:
		var z := (haut - y * haut.dot(y)).normalized()
		return Basis(y.cross(z), y, z)

	## Pose bandée (lache = 0) ou main droite partie en arrière après le tir (lache = 1) : {os: Quaternion}.
	func calculer(lache := 0.0) -> Dictionary:
		var cum := 0.0
		for k in 3:
			cum += TORSION[k]
			var nom: String = ["spine_01", "spine_02", "spine_03"][k]
			_poser(nom, Basis(Vector3.UP, deg_to_rad(cum)) * _repos(nom))
		_poser("neck_01", Basis(Vector3.UP, deg_to_rad(-cum * 0.55)) * Basis(Vector3.UP, deg_to_rad(cum)) * _repos("neck_01"))
		_poser("Head", Basis(Vector3.RIGHT, deg_to_rad(7.0)) * Basis(Vector3.FORWARD, deg_to_rad(4.0)) * _repos("Head"))
		for c in ["l", "r"]:
			var i := sq.find_bone("clavicle_" + c)
			loc[i] = sq.get_bone_rest(i)
		# ancrage : sous la pommette droite, au coin de la mâchoire
		var tete := glob(sq.find_bone("Head"))
		encoche = tete * Vector3(-0.048, -0.025, 0.075)
		# poignée : sur l'axe de la flèche, à ALLONGE de l'épaule gauche
		var S := glob(sq.find_bone("upperarm_l")).origin
		var w := encoche - S
		var bq := 2.0 * w.dot(dir)
		var tirage := (-bq + sqrt(maxf(bq * bq - 4.0 * (w.length_squared() - ALLONGE * ALLONGE), 0.0))) * 0.5
		prise = encoche + dir * tirage
		var cant := Basis(dir, deg_to_rad(-9.0))          # arc un peu penché (haut vers l'extérieur droit de l'archère)
		var haut := cant * Vector3.UP
		_bras("l", prise - dir * PAUME + haut * 0.0, Vector3(0.7, -0.6, -0.2), _main(dir, haut))
		var recul := (-dir * 0.075 + Vector3(-0.045, 0.012, 0.0)) * lache
		var doigts := encoche + recul
		_bras("r", doigts - dir * PAUME + Vector3(0.0, 0.0, 0.0), Vector3(-1.0, 0.25, -0.55), _main(dir, Vector3.UP))
		repere_arc = Transform3D(Basis(haut.cross(dir), haut, dir), prise + Vector3(-0.004, 0, 0))
		var res := {}
		for nom: String in ChasseresseNordique.OS_POSE:
			var i := sq.find_bone(nom)
			res[i] = (loc[i] as Transform3D).basis.get_rotation_quaternion()
		return res

## Applique la pose d'archer par-dessus le clip pendant la visée et le tir ; gère aussi quel arc est visible.
class PoseArcher extends SkeletonModifier3D:
	var ap: AnimationPlayer
	var os_ := PackedInt32Array()
	var bande: Array[Quaternion] = []
	var relache: Array[Quaternion] = []
	var origines: Array[Vector3] = []
	var mi_porte: MeshInstance3D
	var mi_vise: MeshInstance3D
	var mi_relache: MeshInstance3D

	func regler(sq: Skeleton3D, pose: Dictionary) -> void:
		var p2 := ChasseresseNordique.Posture.new(sq)
		var pr := p2.calculer(1.0)
		for i: int in pose:
			os_.append(i)
			bande.append(pose[i])
			relache.append(pr[i])
			origines.append(sq.get_bone_rest(i).origin)

	## Poids du lâcher (0 = bandé, 1 = main partie) pour le clip et l'instant donnés ; -1 = pas de visée.
	static func lache(nom: String, t: float) -> float:
		if not ChasseresseNordique.clip_de_visee(nom):
			return -1.0
		if nom.contains("Shoot"):
			return clampf((t - ChasseresseNordique.LACHER) / ChasseresseNordique.RECUL, 0.0, 1.0)
		return 0.0

	func visibilites(nom: String, t: float) -> void:
		var l := lache(nom, t)
		if mi_porte:
			mi_porte.visible = l < 0.0
		if mi_vise:
			mi_vise.visible = l >= 0.0 and l <= 0.0
		if mi_relache:
			mi_relache.visible = l > 0.0

	func appliquer(sq: Skeleton3D) -> void:
		if ap == null or sq == null:
			return
		var nom := String(ap.assigned_animation)
		var t := ap.current_animation_position if ap.has_animation(nom) else 0.0
		var l := lache(nom, t)
		visibilites(nom, t)
		if l < 0.0:
			return
		for k in os_.size():
			sq.set_bone_pose_position(os_[k], origines[k])
			sq.set_bone_pose_rotation(os_[k], bande[k].slerp(relache[k], l))

	func _process_modification_with_delta(_dt: float) -> void:
		appliquer(get_skeleton())

# ======================================================================================================== accessoires
## Accessoires de la chasseresse : ceux du guerrier (mèches de fourrure, disques ouvragés, yeux, intégration à l'atlas) + arc,
## carquois et flèches, couteau, tresses blondes, frange, baudrier paramétré. Atlas : ChasseresseTextures (même disposition).
class Acc extends GuerrierNordique.Accessoires:

	## Haut du dos laissé sans touffes (la capuche rabattue s'y pose).
	var dos_libre := false
	func _poitrine(p: Vector3) -> bool:
		return super(p) or (dos_libre and p.z < 0.0 and absf(p.x) < 0.17 and p.y > 1.27)

	## Mèches plus larges (touffes lisibles, passe vetements) : facteur sur la largeur des cartes du col.
	var gros := 1.0
	func _carte(mi: MeshInstance3D, a: Array, r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, ext: Vector3) -> void:
		super(mi, a, r, cote, dir, larg * gros, lg, variante, ext)

	## Boucle de ceinture rectangulaire en relief (cadre de fer poli, ardillon) : os pelvis.
	func boucle_rect(c: Vector3, dl := 0.046, dh := 0.036, ep := 0.011, pr := 0.016) -> void:
		var tr := Transform3D(Basis(), c)
		var os_ := sq.find_bone("pelvis")
		var f := GuerrierTextures.R_ANNEAU
		_boite(Vector3(-dl, dh - ep, -pr * 0.5), Vector3(dl, dh, pr * 0.5), tr, os_, f)
		_boite(Vector3(-dl, -dh, -pr * 0.5), Vector3(dl, -dh + ep, pr * 0.5), tr, os_, f)
		_boite(Vector3(-dl, -dh, -pr * 0.5), Vector3(-dl + ep, dh, pr * 0.5), tr, os_, f)
		_boite(Vector3(dl - ep, -dh, -pr * 0.5), Vector3(dl, dh, pr * 0.5), tr, os_, f)
		_boite(Vector3(-0.004, -dh + ep, -pr * 0.3), Vector3(0.004, dh - ep, pr * 0.7), tr, os_, f)

	# ------------------------------------------------------------ capuche rabattue (cuir brun, bord de fourrure chaude)
	## Capuche baissée : son ouverture fait le tour du cou (des clavicules au haut du dos), le sac de cuir repose à plat sur le
	## haut du dos, entre la mante et le carquois ; doublure sombre visible sur la première rangée ; bord garni de mèches qui
	## se dressent derrière la nuque (le grand col de fourrure de la référence). Os : spine_03 (sac), neck_01 (bord).
	func capuche() -> void:
		var nk := sq.find_bone("neck_01")
		var s3 := sq.find_bone("spine_03")
		var s2 := sq.find_bone("spine_02")
		var NP := 10
		var NV := 4
		var r := ChasseresseTextures.R_CAPUCHE
		var grille := []
		for i in NP + 1:
			var phi := lerpf(-2.0, 2.0, float(i) / NP)            # 0 = milieu du dos
			var c := cos(phi)
			var bord := Vector3(sin(phi) * 0.150, 1.455 + 0.065 * maxf(c, 0.0), -0.035 - c * 0.130)
			var pointe := Vector3(sin(phi) * 0.075, 1.245 + 0.05 * absf(sin(phi)), -0.168 - 0.012 * c)
			var col := []
			for j in NV + 1:
				var v := float(j) / NV
				var p := bord.lerp(pointe, v)
				var ext := Vector3(p.x, 0.0, p.z + 0.02).normalized()
				p += ext * 0.040 * sin(PI * minf(v * 1.3, 1.0)) + Vector3.UP * 0.02 * sin(PI * v)
				col.append(p)
			grille.append(col)
		var poids := func(j: int) -> Array:
			return _pw2(s3, nk, 0.35) if j == 0 else (_pw(s3) if j < NV else _pw2(s3, s2, 0.3))
		for i in NP:
			for j in NV:
				var u0 := r.position.x + r.size.x * float(i) / NP
				var u1 := r.position.x + r.size.x * float(i + 1) / NP
				var v0 := r.position.y + 47.0 * float(j) / NV
				var v1 := r.position.y + 47.0 * float(j + 1) / NV
				var a: Vector3 = grille[i][j]
				var b: Vector3 = grille[i + 1][j]
				var cc: Vector3 = grille[i + 1][j + 1]
				var d: Vector3 = grille[i][j + 1]
				var m := (a + cc) * 0.5
				_quad(op, a, b, cc, d, _uva(u0, v0), _uva(u1, v0), _uva(u1, v1), _uva(u0, v1),
					[poids.call(j), poids.call(j), poids.call(j + 1), poids.call(j + 1)], Vector3(0, m.y, 0.0))
				if j == 0:
					# doublure (face tournée vers le cou), légèrement en retrait
					var vd0 := r.position.y + 49.0
					var vd1 := r.position.y + 62.0
					var dedans := Vector3(m.x, m.y, m.z) * 3.0
					var ia := a.lerp(Vector3(0, a.y, 0), 0.03)
					var ib := b.lerp(Vector3(0, b.y, 0), 0.03)
					var ic := cc.lerp(Vector3(0, cc.y, 0), 0.03)
					var id := d.lerp(Vector3(0, d.y, 0), 0.03)
					_quad(op, ia, ib, ic, id, _uva(u0, vd0), _uva(u1, vd0), _uva(u1, vd1), _uva(u0, vd1),
						[poids.call(0), poids.call(0), poids.call(1), poids.call(1)], dedans)
		# bord de fourrure : une carte par segment de l'ouverture, dressée et rabattue vers l'extérieur
		for i in NP:
			var a: Vector3 = grille[i][0]
			var b: Vector3 = grille[i + 1][0]
			var m := (a + b) * 0.5
			var ext := Vector3(m.x, 0.0, m.z + 0.02).normalized()
			var dir := (Vector3.UP * 0.80 + ext * 0.60).normalized()
			var cote := (b - a).normalized()
			var lg := lerpf(0.10, 0.135, _h(i)) * (1.0 if absf(float(i) - NP * 0.5) < 3.5 else 0.85)
			_carte_pw(m - dir * 0.015 - ext * 0.004, cote, dir, (b - a).length() * 2.1, lg, i % 4, ext, _pw2(s3, nk, 0.45))
		# seconde rangée de mèches, couchées sur le sac (fourrure qui retombe sur le cuir)
		for i in range(1, NP, 2):
			var a: Vector3 = grille[i][0]
			var b: Vector3 = grille[i + 1][0]
			var m := (a + b) * 0.5
			var ext := Vector3(m.x, 0.0, m.z + 0.02).normalized()
			var dir := (Vector3.DOWN * 0.55 + ext * 0.8).normalized()
			_carte_pw(m + ext * 0.006, (b - a).normalized(), dir, (b - a).length() * 1.8, lerpf(0.06, 0.085, _h(i + 30)), (i + 1) % 4, ext, _pw(s3))

	## Carte de mèches aux poids donnés (comme _carte, sans maillage de référence).
	func _carte_pw(r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, ext: Vector3, pw: Array) -> void:
		var g := r - cote * larg * 0.5
		var d := r + cote * larg * 0.5
		var R := GuerrierTextures.D_MECHES
		var D := Vector2(GuerrierTextures.DECOUPES)
		var u0 := (R.position.x + variante * 16.0) / D.x
		var u1 := (R.position.x + variante * 16.0 + 16.0) / D.x
		var v1 := (R.position.y + R.size.y) / D.y
		_quad(dec, g, d, d + dir * lg, g + dir * lg, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, v1), Vector2(u0, v1), [pw, pw, pw, pw], r - ext * 0.1)

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

	func arc(tr: Transform3D, os_: int, courbure := 0.11, avec_corde := true) -> void:
		var pts := []
		var lar := []
		var ep := []
		var n := 12
		for i in n + 1:
			var t := -1.0 + 2.0 * i / n
			var at := absf(t)
			var z := -courbure * at * at + 0.045 * smoothstep(0.78, 1.0, at)
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
		if not avec_corde:
			return
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

	## Bout de l'arc (haut : signe 1, bas : -1) dans le repère de l'arc, pour une courbure k.
	func _bout(k: float, signe: float) -> Vector3:
		return Vector3(0.0, signe * (DEMI_ARC - 0.02), -k + 0.045 - 0.004)

	## Prisme fin entre a (os/poids pa) et b (pb) ; positions dans la POSE DE VISÉE, ramenées au repos par Ma / Mb.
	func _brin(a: Vector3, b: Vector3, Ma: Transform3D, Mb: Transform3D, pa: Variant, pb: Variant, rayon: float, cotes: int, r: Rect2i) -> void:
		var ax := (b - a).normalized()
		var x := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
		var y := ax.cross(x)
		var wa: Array = pa if pa is Array else _pw(pa)
		var wb: Array = pb if pb is Array else _pw(pb)
		for k in cotes:
			var o0 := (x * cos(TAU * k / cotes) + y * sin(TAU * k / cotes)) * rayon
			var o1 := (x * cos(TAU * (k + 1) / cotes) + y * sin(TAU * (k + 1) / cotes)) * rayon
			var u0 := r.position.x + r.size.x * float(k) / cotes
			var u1 := r.position.x + r.size.x * float(k + 1) / cotes
			var axe := a.lerp(b, 0.5)
			_tri_pose(op, [a + o0, a + o1, b + o1], [Ma, Ma, Mb], [_uva(u0, r.position.y), _uva(u1, r.position.y), _uva(u1, r.end.y)], [wa, wa, wb], axe)
			_tri_pose(op, [a + o0, b + o1, b + o0], [Ma, Mb, Mb], [_uva(u0, r.position.y), _uva(u1, r.end.y), _uva(u0, r.end.y)], [wa, wb, wb], axe)

	## Triangle construit dans la pose de visée (ordre des sommets choisi là, face avant vers l'extérieur de `dedans`), chaque
	## sommet ramené au repos par sa propre matrice (os différents : main gauche / main droite).
	func _tri_pose(s: Dictionary, p: Array, M: Array, uv: Array, pw: Array, dedans: Vector3) -> void:
		var p0: Vector3 = p[0]
		var n: Vector3 = (p[2] - p0).cross(p[1] - p0)
		var ordre := [0, 1, 2]
		if n.dot((p[0] + p[1] + p[2]) / 3.0 - dedans) < 0.0:
			ordre = [0, 2, 1]
			n = -n
		n = n.normalized()
		for k: int in ordre:
			var m: Transform3D = M[k]
			s["v"].append(m * (p[k] as Vector3))
			s["n"].append((m.basis * n).normalized())
			s["uv"].append(uv[k])
			s["b"].append_array(pw[k][0])
			s["w"].append_array(pw[k][1])

	## Corde bandée : deux brins des bouts de l'arc (main gauche) jusqu'au point d'encoche, pondéré sur la main droite
	## (la corde suit les doigts pendant la visée).
	func corde_bandee(tr: Transform3D, ol: int, k: float, _encoche_repos: Vector3, or_: int, Ml: Transform3D, Mr: Transform3D, posture: ChasseresseNordique.Posture) -> void:
		var arc_pose := posture.repere_arc
		var enc := posture.encoche
		for signe: float in [1.0, -1.0]:
			var bout := arc_pose * _bout(k, signe)
			_brin(bout, enc, Ml, Mr, ol, or_, 0.0030, 3, ChasseresseTextures.R_CORDE)

	## Flèche encochée : fût de l'encoche (main droite) à la pointe, 10 cm devant la poignée (main gauche) ; empennage près de
	## l'encoche, pointe de fer.
	func fleche_encochee(posture: ChasseresseNordique.Posture, Ml: Transform3D, Mr: Transform3D, ol: int, or_: int) -> void:
		var d := posture.dir
		var arriere := posture.encoche - d * 0.012
		var avant := posture.prise + d * 0.10 + Vector3(0.012, 0.0, 0.0)
		var ax := (avant - arriere).normalized()
		_brin(arriere, avant, Mr, Ml, or_, ol, 0.0050, 3, ChasseresseTextures.R_FUT)
		# pointe (losange de fer)
		var p0 := avant
		var p1 := avant + ax * 0.045
		_brin(p0, p1, Ml, Ml, ol, ol, 0.0085, 3, GuerrierTextures.R_FER)
		# empennage : trois ailettes triangulaires opaques (recto-verso, même surface que l'arc : pas de surface de plus)
		var rc := ChasseresseTextures.R_CORDE
		var w0 := ax.cross(Vector3.UP).normalized()
		var w1 := ax.cross(w0).normalized()
		var wr: Array = _pw(or_)
		for k in 3:
			var w := (w0 * cos(TAU * k / 3.0 + 0.5) + w1 * sin(TAU * k / 3.0 + 0.5)).normalized()
			var a := arriere + ax * 0.015
			var b := arriere + ax * 0.12
			var c := arriere + ax * 0.04 + w * 0.022
			for cote: float in [1.0, -1.0]:
				var nrm := w.cross(ax) * cote
				_tri_pose(op, [a, b, c], [Mr, Mr, Mr], [_uva(rc.position.x, rc.position.y), _uva(rc.end.x, rc.position.y + 20), _uva(rc.position.x + 2, rc.position.y + 40)],
					[wr, wr, wr], (a + b + c) / 3.0 - nrm * 0.05)

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
		for i in 11:
			var ang := TAU * i / 7.0 + 0.4
			var ecart := (x * cos(ang) + y * sin(ang)) * (0.034 if i < 7 else 0.014)
			var penche := (x * cos(ang) + y * sin(ang)) * 0.06 * _h(i)
			var a := haut - axe * 0.04 + ecart
			var b := haut + (axe + penche).normalized() * (0.27 + 0.06 * _h(i + 7)) + ecart
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
