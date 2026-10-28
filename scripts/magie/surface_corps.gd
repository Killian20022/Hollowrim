class_name SurfaceCorps
extends RefCounted
## SOCLE « impact des sorts sur les corps » (docs/MAGIE_IMPACT_CORPS.md) : points échantillonnés sur la SURFACE des
## maillages d'un corps (personnage skinné + pièces rigides), qui SUIVENT SES OS : animation, attaque, chute, ragdoll,
## décapitation (l'os de la tête écrasé par CouTranche rabat ses points sur le cou).
##
##   var s := SurfaceCorps.de(cible)      # null si la cible n'a aucun maillage visible
##   s.actualiser(origine)                # une fois par image au plus : positions / normales MONDE - origine
##   s.pos[i], s.nor[i], s.nb             # PackedVector3Array (relatives à `origine`, axes du monde)
##   s.ecrire(img_pos, img_nor)           # remplit deux images RGBAF (SurfaceCorps.image()) pour les émetteurs GPU
##
## Coût : la lecture des maillages (surface_get_arrays, 0,1 à 2 ms par maillage) est faite UNE fois par forme de maillage
## (cache statique par signature : toutes les copies d'une variante de draugr le partagent) et étalée par ImpactCorps
## (au plus un maillage par image, en avance sur les ennemis proches). Par image : une multiplication de PackedVector3Array
## par os touché (~30), en natif.

## Points au plus par corps (les points en trop sont ignorés).
const LARGEUR := 256
## Les textures de points sont en RGBA flottant (le RGB flottant n'est pas échantillonnable partout, Iris Xe compris) : les
## xyz des points y sont tassés bout à bout (3 flottants par point, 4 par texel) → LARGEUR × 3 / 4 texels, aucune
## conversion côté CPU (octets du PackedVector3Array tels quels). Lecture : magie_corps_part.gdshader (lire3).
const TEXELS_POINTS := LARGEUR * 3 / 4
## Texels de PARAMÈTRES du foyer à la suite des points (texture des positions) : jet, impact, foyers… (voir
## ImpactCorps.regler_* et magie_corps_part.gdshader) → aucun set_shader_parameter par image.
const TEXELS_PARAMS := 8
const TEXELS := TEXELS_POINTS + TEXELS_PARAMS
static var _zeros_params := PackedByteArray()
## Points par m² de surface (estimée) : ~1,8 m² visibles sur un draugr → ~200 points.
const DENSITE := 120.0
const MIN_PAR_MAILLAGE := 4
const MAX_PAR_MAILLAGE := 72
## Triangles tirés au hasard pour estimer l'aire d'un maillage (pas de boucle sur tous les triangles).
const TIRAGES_AIRE := 320
## Pièces ignorées (trop petites ou à l'intérieur de la tête).
const IGNORES := ["Eyes", "Eyebrows"]

## Cache des échantillons par signature de maillage : {"b": PackedInt32Array (bind du skin, -1 = rigide),
## "p": PackedVector3Array (repère du maillage), "n": PackedVector3Array}.
static var _cache := {}
static var lectures := 0          # maillages lus (tests, débogage)
static var duree_lectures_us := 0

var cible: Node3D
var squelette: Skeleton3D
## Groupes d'échantillons qui bougent ensemble (construction) : {"mi", "sq", "os" (-1 = rigide), "o", "n"}.
var _groupes: Array = []
## Groupes FUSIONNÉS par (repère, os) en tableaux typés (chaque image : pas de dictionnaire) : repère = squelette (maillage
## enfant direct sans décalage) ou maillage rigide ; os -1 = rigide.
var _g_base: Array[Node3D] = []
var _g_sq: Array[Skeleton3D] = []
var _g_os := PackedInt32Array()
var _g_o: Array[PackedVector3Array] = []
var _g_n: Array[PackedVector3Array] = []
var _g_pose: Array[Transform3D] = []
var pos := PackedVector3Array()
var nor := PackedVector3Array()
## Os (index du squelette, -1 pour une pièce rigide) de chaque point, dans l'ordre de pos.
var os_de := PackedInt32Array()
var nb := 0
## Boîte des points (repère monde - origine), après actualiser().
var bas := 0.0
var haut := 1.8
var centre := Vector3.ZERO
## Ellipsoïde du corps (après actualiser) : centre et demi-axes du monde, d'après les os touchés (suit le ragdoll).
var masse_centre := Vector3(0, 1, 0)
var masse_demi := Vector3(0.3, 0.8, 0.3)
var _image := -1
var _origine := Vector3.ZERO
var _repli := false
## (Agent B, perf) groupes PARTAGÉS entre maillages : clé = squelette + os + transformée du maillage. Les pièces d'un même
## personnage (tunique, pantalon, bottes… même squelette, même transformée) ne font plus qu'un groupe par os : ~60 → ~25
## groupes pour un draugr, actualiser() presque deux fois moins cher.
var _par_cle := {}

## Échantillonnage d'une cible. `lire` = faux : les maillages pas encore en cache sont sautés (repli en capsules si rien
## n'est prêt ; ImpactCorps les lit ensuite, un par image, et refait la surface) → jamais de lecture au premier impact.
static func de(c: Node3D, lire := true, branche := true) -> SurfaceCorps:
	if c == null or not is_instance_valid(c):
		return null
	var s := SurfaceCorps.new()
	s.cible = c
	s.squelette = c.find_child("Skeleton3D", true, false) as Skeleton3D
	if s.squelette == null and c is Skeleton3D:
		s.squelette = c
	for mi in maillages(c):
		if lire or _cache.has(signature(mi)):
			s._ajouter(mi)
		else:
			s._repli = true
	if s._groupes.is_empty():
		s._repli_capsules()
	if s._groupes.is_empty():
		return null
	s._compter()
	if branche:
		s.brancher()
	return s

## Poses APRÈS les modificateurs du squelette (ragdoll = PhysicalBoneSimulator3D, cou tranché, raideur) : elles ne sont
## lisibles qu'au signal skeleton_updated ; hors de lui, get_bone_global_pose rend la pose animée seule. Branché tant que
## la surface sert (foyer actif), lâché ensuite (lacher).
func brancher() -> void:
	for sq in _squelettes():
		if not sq.skeleton_updated.is_connected(_poses_modifiees.bind(sq)):
			sq.skeleton_updated.connect(_poses_modifiees.bind(sq))

func _squelettes() -> Array[Skeleton3D]:
	var r: Array[Skeleton3D] = []
	for i in _g_sq.size():
		var v: Variant = _g_sq[i]
		if v == null or not is_instance_valid(v):
			continue
		var sq := v as Skeleton3D
		if not r.has(sq):
			r.append(sq)
	return r

## Copie des poses modifiées de chaque os touché (appelé par Skeleton3D.skeleton_updated).
func _poses_modifiees(sq: Skeleton3D) -> void:
	for i in _g_os.size():
		if _g_sq[i] == sq:
			_g_pose[i] = sq.get_bone_global_pose(_g_os[i])

## Détache les signaux (le foyer est rendu au pool).
func lacher() -> void:
	for sq in _squelettes():
		if is_instance_valid(sq):
			for c in sq.skeleton_updated.get_connections():
				if (c.callable as Callable).get_object() == self:
					sq.skeleton_updated.disconnect(c.callable)

## Maillages visibles retenus d'une cible (aussi ceux qui reçoivent le voile).
static func maillages(c: Node3D) -> Array[MeshInstance3D]:
	var res: Array[MeshInstance3D] = []
	var liste := c.find_children("*", "MeshInstance3D", true, false)
	if c is MeshInstance3D:
		liste.append(c)
	for v in liste:
		var mi := v as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or IGNORES.has(String(mi.name)):
			continue
		if mi.get_parent() is GPUParticles3D or mi.name.begins_with("AuraMagie"):
			continue
		var t := mi.get_aabb().size
		if t.length() < 0.03 or t.length() > 6.0:
			continue
		res.append(mi)
		if res.size() >= 16:
			break
	return res

## Vrai si tous les maillages de la cible sont déjà en cache (aucune lecture à faire au premier impact).
static func pret(c: Node3D) -> bool:
	for mi in maillages(c):
		if not _cache.has(signature(mi)):
			return false
	return true

## Lit (et met en cache) UN maillage pas encore lu de la cible ; renvoie faux s'il n'y avait plus rien à lire.
static func preparer_un(c: Node3D) -> bool:
	for mi in maillages(c):
		var sig := signature(mi)
		if not _cache.has(sig):
			_cache[sig] = _echantillonner(mi.mesh)
			return true
	return false

## Signature d'une forme de maillage : nom de la pièce, surfaces, sommets, taille arrondie au décimètre. Les copies d'une
## pièce (variantes de draugr amincies, usées : mêmes sommets, positions à quelques mm près) partagent leurs échantillons
## → une seule lecture du GPU par pièce et par séance, pas une par ennemi.
static func signature(mi: MeshInstance3D) -> String:
	var m := mi.mesh
	var a := m.get_aabb()
	var n := 0
	if m is ArrayMesh:
		for i in m.get_surface_count():
			n += (m as ArrayMesh).surface_get_array_len(i)
	else:
		n = -m.get_class().hash() % 100000
	return "%s|%d|%d|%.1f|%.1f|%.1f" % [mi.name, m.get_surface_count(), n, a.size.x, a.size.y, a.size.z]

## Tirage de points sur la surface d'un maillage, pondéré par l'aire (estimée sur TIRAGES_AIRE triangles).
static func _echantillonner(m: Mesh) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	lectures += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var rb := PackedInt32Array()
	var rp := PackedVector3Array()
	var rn := PackedVector3Array()
	for s in m.get_surface_count():
		if m is ArrayMesh and (m as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if v.size() < 3:
			continue
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var os_v: Variant = arr[Mesh.ARRAY_BONES]
		var po_v: Variant = arr[Mesh.ARRAY_WEIGHTS]
		var os_a := PackedInt32Array(os_v) if os_v != null else PackedInt32Array()
		var po_a := PackedFloat32Array(po_v) if po_v != null else PackedFloat32Array()
		var par := (os_a.size() / v.size()) if not os_a.is_empty() else 0
		var nt := (idx.size() / 3) if not idx.is_empty() else (v.size() / 3)
		if nt <= 0:
			continue
		# aire : moyenne de triangles tirés au hasard × nombre de triangles
		var tris := PackedInt32Array()
		var cumul := PackedFloat32Array()
		var somme := 0.0
		var nm := mini(nt, TIRAGES_AIRE)
		for k in nm:
			var ti := rng.randi_range(0, nt - 1) if nt > TIRAGES_AIRE else k
			var i0 := idx[ti * 3] if not idx.is_empty() else ti * 3
			var i1 := idx[ti * 3 + 1] if not idx.is_empty() else ti * 3 + 1
			var i2 := idx[ti * 3 + 2] if not idx.is_empty() else ti * 3 + 2
			var aire := (v[i1] - v[i0]).cross(v[i2] - v[i0]).length() * 0.5
			somme += aire
			tris.append(ti)
			cumul.append(somme)
		if somme <= 0.0:
			continue
		var aire_tot := somme / nm * nt
		var k_pts := clampi(int(round(aire_tot * DENSITE)), MIN_PAR_MAILLAGE, MAX_PAR_MAILLAGE)
		for _k in k_pts:
			var r := rng.randf() * somme
			var lo := cumul.bsearch(r)
			var ti := tris[mini(lo, tris.size() - 1)]
			var i0 := idx[ti * 3] if not idx.is_empty() else ti * 3
			var i1 := idx[ti * 3 + 1] if not idx.is_empty() else ti * 3 + 1
			var i2 := idx[ti * 3 + 2] if not idx.is_empty() else ti * 3 + 2
			var a := rng.randf()
			var b := rng.randf()
			if a + b > 1.0:
				a = 1.0 - a
				b = 1.0 - b
			var p := v[i0] + (v[i1] - v[i0]) * a + (v[i2] - v[i0]) * b
			var n := Vector3.ZERO
			if nn.size() == v.size():
				n = (nn[i0] * (1.0 - a - b) + nn[i1] * a + nn[i2] * b)
			if n.length() < 0.0001:
				n = (v[i1] - v[i0]).cross(v[i2] - v[i0])
			# os dominant du sommet le plus proche du point tiré (poids le plus fort)
			var bind := -1
			if par > 0:
				var iv := i0 if (1.0 - a - b) >= maxf(a, b) else (i1 if a >= b else i2)
				var meilleur := -1.0
				for j in par:
					var w := po_a[iv * par + j] if po_a.size() > iv * par + j else 0.0
					if w > meilleur:
						meilleur = w
						bind = os_a[iv * par + j]
			rb.append(bind)
			rp.append(p)
			rn.append(n.normalized())
	duree_lectures_us += Time.get_ticks_usec() - t0
	return {"b": rb, "p": rp, "n": rn}

func _ajouter(mi: MeshInstance3D) -> void:
	var sig := signature(mi)
	if not _cache.has(sig):
		_cache[sig] = _echantillonner(mi.mesh)
	var e: Dictionary = _cache[sig]
	var skin := mi.skin
	var sq := squelette if skin != null else null
	if skin != null and mi.skeleton != NodePath(""):
		var s2 := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if s2 != null:
			sq = s2
	var par_os := {}   # clé de groupe -> groupe (nouveaux groupes de ce maillage)
	var t_mi := str(mi.global_transform if mi.is_inside_tree() else mi.transform)
	var bs: PackedInt32Array = e.b
	var ps: PackedVector3Array = e.p
	var ns: PackedVector3Array = e.n
	for i in ps.size():
		var b := bs[i]
		var os := -1
		var o := ps[i]
		var n := ns[i]
		if sq != null and skin != null and b >= 0 and b < skin.get_bind_count():
			os = skin.get_bind_bone(b)
			if os < 0:
				os = sq.find_bone(skin.get_bind_name(b))
			if os >= 0:
				var bp := skin.get_bind_pose(b)
				o = bp * o
				n = (bp.basis * n).normalized()
		# pièce skinnée : groupe partagé par os (et transformée du maillage) entre les pièces d'un même squelette (agent B) ;
		# pièce rigide : son propre groupe. _compter fusionne ensuite par (repère, os) (agent A).
		var cle := "%d:%d:%s" % [sq.get_instance_id(), os, t_mi] if os >= 0 else "%d:%d" % [mi.get_instance_id(), os]
		if not par_os.has(cle):
			if _par_cle.has(cle):
				par_os[cle] = _par_cle[cle]
			else:
				par_os[cle] = {"mi": mi, "sq": sq if os >= 0 else null, "os": os, "o": PackedVector3Array(), "n": PackedVector3Array(), "neuf": true}
		# (un PackedVector3Array lu dans un dictionnaire est une COPIE : on le relit, on ajoute, on le réécrit)
		var g: Dictionary = par_os[cle]
		var go: PackedVector3Array = g.o
		var gn: PackedVector3Array = g.n
		go.append(o)
		gn.append(n)
		g.o = go
		g.n = gn
	for cle in par_os:
		var g: Dictionary = par_os[cle]
		if g.get("neuf", false):
			g.erase("neuf")
			_par_cle[cle] = g
			_groupes.append(g)

## Repli sans maillage lisible (ou avant lecture) : capsules le long des os du squelette.
func _repli_capsules() -> void:
	if squelette == null:
		return
	_repli = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for b in squelette.get_bone_count():
		var nom := squelette.get_bone_name(b)
		if nom.contains("index") or nom.contains("middle") or nom.contains("pinky") or nom.contains("ring") or nom.contains("thumb") or nom.contains("leaf") or nom == "root":
			continue
		var rayon := 0.06
		if nom.begins_with("spine") or nom == "pelvis":
			rayon = 0.14
		elif nom == "Head":
			rayon = 0.1
		elif nom.begins_with("thigh"):
			rayon = 0.085
		var go := PackedVector3Array()
		var gn := PackedVector3Array()
		for _k in 6:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.2), rng.randf_range(-1, 1))
			var n := Vector3(d.x, 0.0, d.z).normalized()
			go.append(Vector3(n.x * rayon, d.y * 0.15, n.z * rayon))
			gn.append(n)
		_groupes.append({"mi": null, "sq": squelette, "os": b, "o": go, "n": gn})

func _compter() -> void:
	# trop de points : chaque groupe est éclairci dans la même proportion (aucune partie du corps n'est perdue)
	var total := 0
	for g in _groupes:
		total += (g.o as PackedVector3Array).size()
	if total > LARGEUR:
		var k := float(LARGEUR) / float(total)
		for g in _groupes:
			var go: PackedVector3Array = g.o
			var gn: PackedVector3Array = g.n
			var garde := maxi(1, int(floor(go.size() * k)))
			var no := PackedVector3Array()
			var nn := PackedVector3Array()
			for i in garde:
				var j := int(float(i) * go.size() / garde)
				no.append(go[j])
				nn.append(gn[j])
			g.o = no
			g.n = nn
	# fusion par (repère, os) : les maillages enfants directs du squelette, sans décalage, partagent son repère
	var index := {}
	for g in _groupes:
		var mi: MeshInstance3D = g.mi
		var sq: Skeleton3D = g.sq
		var os := int(g.os)
		var base: Node3D = mi
		if os >= 0 and sq != null and (mi == null or (mi.get_parent() == sq and mi.transform.is_equal_approx(Transform3D.IDENTITY))):
			base = sq
		if base == null:
			continue
		var cle := "%d:%d" % [base.get_instance_id(), os]
		if not index.has(cle):
			index[cle] = _g_os.size()
			_g_base.append(base)
			_g_sq.append(sq if os >= 0 else null)
			_g_os.append(os)
			_g_o.append(PackedVector3Array())
			_g_n.append(PackedVector3Array())
			_g_pose.append(sq.get_bone_global_pose(os) if os >= 0 and sq != null else Transform3D.IDENTITY)
		var i: int = index[cle]
		_g_o[i].append_array(g.o)
		_g_n[i].append_array(g.n)
	_groupes.clear()
	nb = 0
	os_de.clear()
	for i in _g_os.size():
		var k := _g_o[i].size()
		nb += k
		for _j in k:
			os_de.append(_g_os[i])
	nb = mini(nb, LARGEUR)

func repli() -> bool:
	return _repli

## Positions et normales du monde (relatives à `origine`), une seule fois par image. `normales` = faux : seules les
## positions sont refaites (les normales de l'image précédente servent aux poids d'émission : une image de retard).
func actualiser(origine: Vector3, normales := true) -> void:
	var img := Engine.get_process_frames()
	if img == _image and origine == _origine:
		return
	_image = img
	_origine = origine
	normales = normales or nor.size() < nb
	pos.clear()
	if normales:
		nor.clear()
	var dec := Transform3D(Basis.IDENTITY, -origine)
	var y0 := INF
	var y1 := -INF
	var som := Vector3.ZERO
	var som2 := Vector3.ZERO
	var k_os := 0
	var base_prec: Node3D = null
	var xf_base := Transform3D.IDENTITY
	for i in _g_os.size():
		var base := _g_base[i]
		if base != base_prec:
			if not is_instance_valid(base):
				continue
			base_prec = base
			xf_base = base.global_transform
		var xf := xf_base * _g_pose[i] if _g_os[i] >= 0 else xf_base
		var o: PackedVector3Array = (dec * xf) * _g_o[i]
		pos.append_array(o)
		if normales:
			var e := xf.basis.x.length()
			nor.append_array(Transform3D(xf.basis / maxf(e, 0.0001), Vector3.ZERO) * _g_n[i])
		# bornes verticales (un point par groupe suffit) et os pour l'ellipsoïde du corps
		var p0 := o[0]
		y0 = minf(y0, p0.y)
		y1 = maxf(y1, p0.y)
		som += p0
		som2 += p0 * p0
		k_os += 1
	if pos.size() > LARGEUR:
		pos.resize(LARGEUR)
	if nor.size() > LARGEUR:
		nor.resize(LARGEUR)
	nb = pos.size()
	if nb > 0:
		bas = y0
		haut = y1
		centre = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	if k_os > 0:
		masse_centre = som / k_os
		var var_ := som2 / k_os - masse_centre * masse_centre
		masse_demi = Vector3(sqrt(maxf(var_.x, 0.0)), sqrt(maxf(var_.y, 0.0)), sqrt(maxf(var_.z, 0.0))) * 1.7
		masse_demi = masse_demi.max(Vector3(0.18, 0.18, 0.18))

## Écrit les points dans deux images RGBAF de TEXELS × 1 (au-delà de `nb` : zéros, jamais lus par le shader) ; `params`
## (TEXELS_PARAMS × 4 flottants) suit les positions.
func ecrire(img_pos: Image, img_nor: Image, params := PackedFloat32Array()) -> void:
	if nb <= 0:
		return
	pos.resize(LARGEUR)
	nor.resize(LARGEUR)
	if _zeros_params.is_empty():
		_zeros_params.resize(TEXELS_PARAMS * 16)
	var o := pos.to_byte_array()
	o.append_array(params.to_byte_array() if params.size() == TEXELS_PARAMS * 4 else _zeros_params)
	var n := nor.to_byte_array()
	n.append_array(_zeros_params)
	img_pos.set_data(TEXELS, 1, false, Image.FORMAT_RGBAF, o)
	img_nor.set_data(TEXELS, 1, false, Image.FORMAT_RGBAF, n)

## Image vide au bon format pour ecrire().
static func image() -> Image:
	return Image.create_empty(TEXELS, 1, false, Image.FORMAT_RGBAF)

## Index du point le plus proche de l'axe d'un jet (origine o, direction d, en coordonnées relatives) parmi ceux tournés
## vers lui : le point d'impact sur la surface. -1 si aucun.
func point_vise(o: Vector3, d: Vector3, pas := 2) -> int:
	var meilleur := -1
	var score := INF
	for i in range(0, nb, pas):
		var n := nor[i]
		if n.dot(d) > 0.15:
			continue
		var v := pos[i] - o
		var t := v.dot(d)
		if t <= 0.0:
			continue
		var ecart := (v - d * t).length()
		var s := ecart + t * 0.05
		if s < score:
			score = s
			meilleur = i
	return meilleur

## Index des `k` points les plus « chauds » (proches de `p`, sur des os différents si possible) : foyers de la brûlure.
func foyers_pres_de(p: Vector3, k: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var res := PackedInt32Array()
	if nb <= 0:
		return res
	var vus := {}
	var essais := 0
	while res.size() < k and essais < 60:
		essais += 1
		var i := rng.randi_range(0, nb - 1)
		var d := pos[i].distance_to(p)
		# plus on est près du point touché, plus le point a de chances d'être un foyer
		if rng.randf() > exp(-d * d / 0.35):
			continue
		var os := os_de[i] if i < os_de.size() else -1
		if vus.has(os) and essais < 45:
			continue
		vus[os] = true
		res.append(i)
	return res
