class_name MaisonTripo
## Auberge « h2 » (la Chope) : extérieur chaumière Tripo (maison en L, texture cuite 512 px) et intérieur taverne Tripo (512 px) à la
## place du bâti procédural. PAR DÉFAUT (lot 2) ; `--modeles-anciens[=maison]`, `-- --sans-tripo` ou `--h2-ancien` rend le bâti d'avant
## (emprise, porte et mobilier d'avant ; data/batiments.json est le même).
## Reprise G2 (audit 2026-11-10) : plus AUCUN étirement. La chaumière est mise à l'échelle UNIFORME (S_EXT : sa porte fait 2 m) et posée
## en grande auberge (13 m sur 12, en L) ; on entre par la porte du pignon de l'aile nord, face à la place. La pièce enterable est cette aile
## (rectangle 7,6 × 5,5 m sous le rampant du toit) ; le reste du L est plein (collisions). Le battant de la porte EST le vantail du modèle,
## découpé dans le maillage et monté sur charnière (plus de vieux battant noir posé devant). La taverne est elle aussi à l'échelle uniforme
## (S_INT), recoupée de son mur ouest (mezzanine, escalier) pour tenir dans la largeur, sur le matériau des intérieurs (ps1_interieur :
## ambiante propre, feux et bougies), avec un âtre qui brûle, lanterne, appliques et bougies.
## Seules opérations sur les maillages source : échelle uniforme et découpe (tri des triangles), à la construction.
static var actif := ModelesTripo.actif("maison") and not (OS.get_cmdline_user_args().has("--sans-tripo") or OS.get_cmdline_user_args().has("--h2-ancien"))
const EXT := "res://assets/essai_tripo/cottage.glb"
const INT := "res://assets/essai_tripo/taverne.glb"

## --- chaumière (unités du glb : x, y haut, z ; la porte d'entrée est au pignon -X de l'aile nord) ---
const S_EXT := 27.0                       # porte du pignon : 0,075 de haut dans le modèle -> 2,0 m
const PIED_M := 0.223                     # bas du modèle (posé au sol)
const SEUIL_M := 0.2525                   # dessus du seuil de la porte
const CENTRE_M := Vector2(-0.20, 0.0675)  # centre (x, z) de la pièce enterable (aile nord, de la porte au faîte de l'aile sud)
const X_PORTE_M := -0.340                 # plan du battant de la porte
const PIECE_M := Vector2(0.28, 0.205)     # longueur (x, de la porte au bout) et largeur (z) intérieures de la pièce
const FAITE_M := 0.446                    # faîte du toit de l'aile (dessus des bardeaux)
const RIVE_M := 0.361                     # toit au droit des murs gouttereaux de l'aile
## battant : triangles du vantail du modèle (boîte et normale)
const BATTANT_MIN := Vector3(-0.348, 0.250, 0.030)
const BATTANT_MAX := Vector3(-0.331, 0.332, 0.110)
## aile sud (le grand pan du L, plein) : x, z du modèle
const AILE_SUD_X := Vector2(-0.19, 0.05)
const AILE_SUD_Z := Vector2(-0.15, 0.30)
## emplacement (monde) du centre de la pièce et lacet : le pignon d'entrée (-X du modèle) regarde le nord (-Z monde), la place ;
## le dos de l'aile sud longe le quai, l'aile ouest du L ferme une petite cour (tonneaux, sacs) ; à l'est, la maison voisine.
const POS := Vector2(51.3, 51.45)
const LACET := -PI * 0.5

## --- taverne (unités du glb : murs au nord -Z (âtre) et à l'ouest -X, ouverte au sud et à l'est) ---
const S_INT := 7.2                        # âtre 0,16 -> 1,15 m, table 0,08 -> 0,58 m, murs 0,23-0,36 -> 1,7-2,6 m
const SOL_T := 0.091                      # dessus du plancher de la taverne
const COUPE_T := -0.23                    # on garde x >= COUPE_T (le mur ouest, sa mezzanine et l'escalier sont retirés)
const MILIEU_T := 0.13                    # milieu (x) de la partie gardée

## Props du mobilier du village déplacés quand l'auberge Tripo est là (sinon ils seraient dans ses murs) : ancienne -> nouvelle position.
const DEPLACES := {
	Vector3(51.0, 0.0, 45.9): Vector3(47.2, 0.0, 49.6),        # tonneau devant l'ancienne porte -> cour du L
	Vector3(47.3, 0.0, 55.2): Vector3(46.3, 0.0, 50.7),        # sacs (dans l'aile sud) -> cour du L, contre le mur
	Vector3(46.0, 0.0, 55.0): Vector3(45.6, 0.0, 49.9),
	Vector3(54.4, 0.0, 50.6): Vector3(55.6, 0.0, 49.3),        # souche et hache (sous l'avant-toit est) -> à côté du tronc
	Vector3(54.4, 0.6, 50.6): Vector3(55.6, 0.6, 49.3),
}

## Même chose pour les poses simples de MobilierVillage.POSES (clé « modèle x z ») : le porche de la porte avance jusqu'à z ≈ 45.
const DEPLACES_POSES := {
	"caisse_b 50.4 44.6": Vector2(49.0, 44.3),      # devant le porche -> à gauche, contre la façade du dehors
	"etal 52.5 42.5": Vector2(48.4, 41.8),          # étal du poissonnier, à 5 m devant la porte -> à l'ouest de l'allée (ses props suivent)
	"sacs 51.4 44.9": Vector2(53.2, 44.6),          # dans le passage de la porte -> à droite du porche
	"banniere 48 47.5": Vector2(47.6, 45.6),        # dans le mur ouest de l'aile d'entrée -> au coin du porche
	"banniere 48.0 47.5": Vector2(47.6, 45.6),      # (même clé si le flottant s'écrit « 48.0 »)
}

static func deplacer(p: Vector3) -> Vector3:
	return DEPLACES.get(p, p) if actif else p

static func arg(nom: String, defaut: float) -> float:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + nom + "="):
			return float(s.get_slice("=", 1))
	return defaut

## Passe un modèle au shader ps1 du jeu (double face, métal éteint) ; `neige` : le dessus (alpha de sommet 0) prend la texture de neige.
static func ps1(racine: Node, teinte := Color(1.25, 1.25, 1.25), double_face := true) -> void:
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				mi.set_surface_override_material(s, Palette.materiau(tex, Vector2.ONE, teinte, double_face))

static func aabb(n: Node3D) -> AABB:
	var r := AABB()
	var premier := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()      # repère de `mi` dans celui de `n`, par la chaîne locale : marche aussi hors de l'arbre (intérieur bâti sur un fil)
		var x: Node3D = mi
		while x != n and x != null:
			t = x.transform * t
			x = x.get_parent() as Node3D
		var b := t * mi.get_aabb()
		r = b if premier else r.merge(b)
		premier = false
	return r

## Premier maillage du modèle (les deux glb n'en ont qu'un).
static func _maillage(n: Node3D) -> MeshInstance3D:
	return n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D

static func _texture(m: Mesh) -> Texture2D:
	var src := m.surface_get_material(0) if m.get_surface_count() > 0 else null
	return (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null

## DÉCOUPE : sépare les triangles de la 1re surface de `mi` selon `garder(centre, normale, coin_min) -> bool`. Rend [ArrayMesh gardé, ArrayMesh
## retiré] (chaque morceau ne garde que ses sommets, valeurs inchangées ; rien n'est déplacé ni réécrit). Repère du maillage = repère du glb (nœuds sans transformation).
static func _decouper(mi: MeshInstance3D, garder: Callable) -> Array:
	var a: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	var k1 := PackedInt32Array()
	var k2 := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var n := (p1 - p0).cross(p2 - p0)
		n = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
		var dst := k1 if garder.call((p0 + p1 + p2) / 3.0, n, p0.min(p1).min(p2)) else k2
		dst.append(idx[t])
		dst.append(idx[t + 1])
		dst.append(idx[t + 2])
	var r := []
	for k: PackedInt32Array in [k1, k2]:
		var am := ArrayMesh.new()
		if not k.is_empty():
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compacter(a, k))
			am.surface_set_material(0, mi.mesh.surface_get_material(0))
		r.append(am)
	return r

## Boîte des seuls sommets indexés (les morceaux découpés gardent TOUS les sommets du modèle : get_aabb() rendrait la maison entière).
static func _boite_triangles(m: ArrayMesh) -> AABB:
	var a: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var r := AABB(v[idx[0]], Vector3.ZERO)
	for i in idx:
		r = r.expand(v[i])
	return r

## Ne garde que les sommets utilisés par `k` (mêmes valeurs, renumérotés) : un morceau découpé ne traîne pas les sommets de l'autre.
static func _compacter(a: Array, k: PackedInt32Array) -> Array:
	var nv: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var neuf := PackedInt32Array()
	neuf.resize(nv)
	neuf.fill(-1)
	var ordre := PackedInt32Array()
	var idx := PackedInt32Array()
	idx.resize(k.size())
	for i in k.size():
		var o := k[i]
		if neuf[o] < 0:
			neuf[o] = ordre.size()
			ordre.append(o)
		idx[i] = neuf[o]
	var b := []
	b.resize(Mesh.ARRAY_MAX)
	for t in Mesh.ARRAY_MAX:
		var src = a[t]
		if src == null or t == Mesh.ARRAY_INDEX:
			continue
		var n: int = src.size()
		if n % nv != 0:
			b[t] = src
			continue
		var pas: int = n / nv
		var dst = src.duplicate()
		dst.resize(ordre.size() * pas)
		for j in ordre.size():
			for c in pas:
				dst[j * pas + c] = src[ordre[j] * pas + c]
		b[t] = dst
	b[Mesh.ARRAY_INDEX] = idx
	return b

## Repère du pivot (mètres) d'un point du modèle de la chaumière.
static func ext_p(x: float, y: float, z: float) -> Vector3:
	return Vector3((x - CENTRE_M.x) * S_EXT, (y - PIED_M) * S_EXT, (z - CENTRE_M.y) * S_EXT)

static var _battant: ArrayMesh      # vantail découpé (repère du modèle), posé sur la charnière par `dessin_battant`
static var _battant_boite: AABB

## Chaumière à l'échelle uniforme, sans son battant (découpé : il devient le vantail de la porte). Le pivot `p` est au centre de la pièce,
## bas du modèle à y = 0.
static func exterieur(p: Node3D) -> void:
	var n := (load(EXT) as PackedScene).instantiate() as Node3D
	n.name = "CottageTripo"
	var mi := _maillage(n)
	var dans_battant := func(c: Vector3, nn: Vector3) -> bool:
		return absf(nn.x) > 0.5 and c.x > BATTANT_MIN.x and c.x < BATTANT_MAX.x and c.y > BATTANT_MIN.y and c.y < BATTANT_MAX.y \
			and c.z > BATTANT_MIN.z and c.z < BATTANT_MAX.z
	var parts := _decouper(mi, func(c: Vector3, nn: Vector3, _mn: Vector3) -> bool: return not dans_battant.call(c, nn))
	mi.mesh = parts[0]
	_battant = parts[1]
	_battant_boite = _boite_triangles(_battant) if _battant.get_surface_count() > 0 else AABB(BATTANT_MIN, BATTANT_MAX - BATTANT_MIN)
	ps1(n, Color(1.45, 1.45, 1.45), false)
	p.add_child(n)
	n.scale = Vector3.ONE * S_EXT
	n.position = Vector3(-CENTRE_M.x * S_EXT, -PIED_M * S_EXT, -CENTRE_M.y * S_EXT)

## Dimensions utiles de la porte (repère du pivot) : [milieu du seuil sur le plan du battant, largeur, hauteur].
static func porte() -> Array:
	var b := _battant_boite
	return [ext_p(X_PORTE_M, SEUIL_M, b.get_center().z), b.size.z * S_EXT, (b.end.y - SEUIL_M) * S_EXT]

## Vantail (appelé par BatimentsOuverts._vantaux, repère de la charnière) : le battant du modèle, même échelle, double face.
static func dessin_battant(h: Node3D, xf: Transform3D) -> void:
	if _battant == null or _battant.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "BattantTripo"
	mi.mesh = _battant
	var tex := _texture(_battant)
	if tex != null:
		mi.set_surface_override_material(0, Palette.materiau(tex, Vector2.ONE, Color(1.45, 1.45, 1.45), true))
	h.add_child(mi)
	# le battant est dans le repère du pivot (la charnière n'est pas tournée, porte fermée) : son bas-milieu va au milieu du vantail (`xf.origin`)
	var b := _battant_boite
	var bas := Vector3(b.get_center().x, SEUIL_M, b.get_center().z)
	mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * S_EXT), xf.origin - bas * S_EXT)

## Pièce enterable (BatimentsOuverts.ouvrir, repère du pivot) et collisions du reste du L.
static func coque(v, p: Node3D, bas_c: float) -> Interieur:
	var demi := PIECE_M * S_EXT * 0.5
	var y_sol := (SEUIL_M - PIED_M) * S_EXT - 0.02
	var d := porte()
	var cp: Vector3 = d[0]
	var faite := (FAITE_M - PIED_M) * S_EXT
	var rive := (RIVE_M - PIED_M) * S_EXT
	var sp := {"id": "h2", "style": "planches", "int": demi, "ext": demi + Vector2(0.3, 0.25), "y_sol": y_sol, "y_mur": rive - 0.1,
		"toit": {"faite": faite, "pente": (faite - rive) / demi.y}, "bas": bas_c, "haut": faite, "fenetres": [], "bord": demi.x + 0.3,
		"porte": {"cote": "-X", "c": Vector3(cp.x - 0.02, y_sol, cp.z), "n": Vector3.LEFT, "larg": maxf(d[1], 1.1), "haut": maxf(d[2], 1.95),
			"dessin": func(h: Node3D, _k: int, xf: Transform3D) -> void: dessin_battant(h, xf)}}
	var ip := BatimentsOuverts.ouvrir(v, p, sp)
	# aile sud du L (pleine) : trois boîtes autour de la pièce
	var x0 := ext_p(AILE_SUD_X.x, 0, 0).x
	var x1 := ext_p(AILE_SUD_X.y, 0, 0).x
	var z0 := ext_p(0, 0, AILE_SUD_Z.x).z
	var z1 := ext_p(0, 0, AILE_SUD_Z.y).z
	var ez := demi.y + 0.25
	var ex := demi.x + 0.3
	var hy := faite - 0.6
	var boite := func(xa: float, xb: float, za: float, zb: float) -> void:
		v._collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3((xa + xb) * 0.5, (bas_c + hy) * 0.5, (za + zb) * 0.5)), Vector3(xb - xa, hy - bas_c, zb - za))
	boite.call(x0, x1, z0, -ez)
	boite.call(x0, x1, ez, z1)
	boite.call(ex, x1, -ez, ez)
	v._emprise(p, Vector2(ex + 0.4, ez + 0.4), Vector2.ZERO, ip)
	v._emprise(p, Vector2((x1 - x0) * 0.5 + 0.4, (z1 - z0) * 0.5 + 0.4), Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5))
	return ip

## Matériau des intérieurs (ambiante propre, lumières des feux) sur la texture Tripo, UV du maillage, double face.
static var _sh_int_double: Shader
static func materiau_interieur(tex: Texture2D, teinte := Color(1.15, 1.1, 1.05)) -> ShaderMaterial:
	if _sh_int_double == null:
		var sh := Shader.new()
		sh.code = Interieurs.SHADER.code.replace("render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;",
			"render_mode diffuse_lambert, specular_disabled, ambient_light_disabled, cull_disabled;")
		_sh_int_double = sh
	var m := ShaderMaterial.new()
	m.shader = _sh_int_double
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("tex_neige", tex)
	m.set_shader_parameter("tex_relief", TexturesBati.relief_neutre())
	m.set_shader_parameter("tex_neige_relief", TexturesBati.relief_neutre())
	m.set_shader_parameter("uv_maillage", true)
	m.set_shader_parameter("relief", 0.0)
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("ambiant", Interieurs.AMBIANT)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.suivre(m)
	return m

## Position (repère de l'intérieur : porte +Z, plancher à F) d'un point de la taverne (unités du glb).
static func int_p(x: float, y: float, z: float) -> Vector3:
	return Vector3((x - MILIEU_T) * S_INT, Interieurs.F + (y - SOL_T) * S_INT, z * S_INT)

## Taverne : échelle uniforme, mur ouest retiré (découpe), le fond (âtre) contre le pignon du fond ; feu, lanterne, appliques, bougies.
static func interieur(b: Interieurs, pl: Dictionary) -> void:
	var n := (load(INT) as PackedScene).instantiate() as Node3D
	n.name = "TaverneTripo"
	var mi := _maillage(n)
	var tex := _texture(mi.mesh)
	var parts := _decouper(mi, func(_c: Vector3, _nn: Vector3, mn: Vector3) -> bool: return mn.x >= COUPE_T - 0.05 and mn.y >= SOL_T - 0.06)     # triangle entier du bon côté, dessous du plancher retiré : rien ne dépasse la doublure
	mi.mesh = parts[0]
	if tex != null:
		mi.set_surface_override_material(0, materiau_interieur(tex))
	b._p().add_child(n)
	n.scale = Vector3.ONE * S_INT
	n.position = int_p(0.0, 0.0, 0.0)
	var F := Interieurs.F
	# âtre (ouverture du modèle : x 0,03 à 0,35, fond à z -0,44) : flammes, lit de braises, halo, lumière du feu
	var atre := int_p(0.19, SOL_T, -0.415)
	b.flamme(atre + Vector3(0, 0.12, 0), 1.6)
	b.flamme(atre + Vector3(0.28, 0.08, 0.03), 1.0)
	b.lit_braises(atre + Vector3(0, 0.03, 0), Vector2(0.7, 0.4))
	b.halo(Vector3(atre.x, F + 0.03, atre.z + 0.9), Vector3.UP, 3.2, 3.2, Color(1, 0.9, 0.8, 1))
	b.lumiere(atre + Vector3(0, 0.8, 0.7), 3.0, 8.5)
	# lanterne sous le faîte, au-dessus des tables ; appliques près de la porte ; bougies sur la grande table
	var pl_l := Vector3(-0.6, 0, 0.6)
	BatimentsOuverts._lanterne(b, Vector3(pl_l.x, BatimentsOuverts._y_plafond_en(pl, pl_l) - 0.9, pl_l.z), 2.0)
	BatimentsOuverts._applique(b, pl, "-X", float(pl["az"]) - 1.0, true)
	BatimentsOuverts._applique(b, pl, "+X", float(pl["az"]) - 1.0, true)
	for c: Vector2 in [Vector2(-0.14, 0.05), Vector2(-0.04, 0.07)]:
		b.bougie(int_p(c.x, 0.171, c.y), 0.14, c.x < -0.1)
