class_name MobilierVillage
extends Node3D
## Lot C7a : mobilier du village v2 (modules Blender sources_blender/scripts/mobilier_village.py → assets/modeles/mobilier_village.dat).
## Référence : references/village_v2_planche.png (vues 1-3, vignettes « éléments de décoration »). Positions : docs/PLAN_VILLAGE_V2.md.
## Toutes les pièces d'une même matière sont FUSIONNÉES en un seul maillage (≈ 10 appels de dessin) ; seuls les tissus des
## bannières restent des nœuds (balancement au vent). Lumière réelle : le brasero de la place seulement ; les braseros des
## terrasses et les flammes sont émissifs. Collisions simples (cylindres, boîtes) sur tout ce qui se heurte.

const DAT := "res://assets/modeles/mobilier_village.dat"
const ACCROCHE_TISSU := Vector3(0.55, 3.72, 0.0)   # haut du tissu dans le repère du mât (rapport Blender)
const BRAISES_Y := 1.05
const PORTEE := 55.0

## [module, x, z, lacet° (0 = l'avant regarde le nord, -Z), échelle]
const POSES := [
	["puits", 42.0, 38.0, 15.0, 1.0],
	["etal", 51.5, 30.5, 180.0, 1.0], ["etal", 54.2, 33.4, 90.0, 1.0], ["etal", 52.5, 42.5, 60.0, 1.0],
	["banniere", 38.0, 28.5, 180.0, 1.0], ["banniere", 50.0, 28.5, 180.0, 1.0], ["banniere", 36.0, 46.0, 0.0, 1.0],
	["banniere", 48.0, 47.5, 0.0, 1.0], ["banniere", 23.5, 25.8, 48.0, 1.12], ["banniere", 41.0, 65.4, 0.0, 1.0],
	["brasero", 36.0, 39.0, 0.0, 1.0], ["brasero", 39.6, 71.2, 0.0, 1.0], ["brasero", 39.5, 77.0, 0.0, 1.0],
	["banc", 32.8, 40.5, -90.0, 1.0], ["banc", 47.5, 46.6, 0.0, 1.0], ["banc", 40.6, 29.6, 180.0, 1.0], ["banc", 50.2, 86.0, 90.0, 1.0],
	["tonneau_a", 49.4, 31.3, 20.0, 1.0], ["caisse_a", 49.5, 30.1, 35.0, 1.0], ["caisse_b", 53.6, 31.7, -10.0, 1.0],
	["tonneau_b", 55.4, 35.4, 140.0, 1.0], ["tonneau_a", 54.7, 40.5, 0.0, 1.0], ["caisse_b", 50.4, 44.6, 25.0, 1.0],
	["tonneau_a", 46.6, 54.2, 0.0, 1.0], ["tonneau_b", 47.3, 53.5, 70.0, 1.0], ["caisse_a", 41.3, 54.4, -20.0, 1.0],
	["tonneau_a", 28.3, 51.71, 0.0, 1.0], ["caisse_b", 27.25, 51.71, 0.0, 1.0],   # passe D : sortis du mur de la maison de pierre (25,5 ; 55,5), ruelle vers Grima
	["tonneau_a", 39.3, 69.3, 0.0, 1.0], ["caisse_a", 38.9, 70.3, 15.0, 1.0], ["tonneau_b", 50.0, 79.2, 200.0, 1.0],
	["charrette", 57.0, 26.5, 8.0, 1.0],
	["tas_bois", 58.0, 51.6, 0.0, 1.0], ["tas_bois", 53.5, 88.5, 90.0, 1.0],
	# L7 : densité (petits groupes contre les tonneaux et caisses d'avant : rien sur les passages)
	["caisse_c", 50.3, 29.6, 50.0, 1.0], ["sacs", 53.7, 30.6, 15.0, 1.0], ["tonneau_c", 55.9, 36.2, 0.0, 1.0],
	["caisse_c", 55.3, 41.2, -25.0, 1.0], ["sacs", 51.4, 44.9, 80.0, 1.0], ["caisse_c", 46.4, 55.0, 10.0, 1.0],
	["sacs", 40.4, 54.6, -60.0, 1.0], ["caisse_c", 40.0, 68.8, 30.0, 1.0], ["tonneau_c", 49.3, 79.9, 0.0, 1.0],
]
## Collisions par module : ["cyl", rayon, hauteur, centre] ou ["boite", taille, centre] (repère du module).
const COLLISIONS := {
	"puits": [["cyl", 1.72, 0.85, Vector3(0, 0.42, 0)], ["cyl", 0.1, 3.0, Vector3(1.3, 1.5, 1.3)], ["cyl", 0.1, 3.0, Vector3(-1.3, 1.5, 1.3)],
		["cyl", 0.1, 3.0, Vector3(1.3, 1.5, -1.3)], ["cyl", 0.1, 3.0, Vector3(-1.3, 1.5, -1.3)]],
	"etal": [["boite", Vector3(3.1, 1.0, 0.9), Vector3(0, 0.5, -0.45)], ["cyl", 0.09, 2.3, Vector3(-1.5, 1.15, 0.95)], ["cyl", 0.09, 2.3, Vector3(1.5, 1.15, 0.95)]],
	"banniere": [["cyl", 0.12, 4.0, Vector3(0, 2.0, 0)]],
	"brasero": [["cyl", 0.46, 1.1, Vector3(0, 0.55, 0)]],
	"banc": [["boite", Vector3(1.8, 0.48, 0.38), Vector3(0, 0.24, 0)]],
	"tonneau_a": [["cyl", 0.31, 0.86, Vector3(0, 0.43, 0)]],
	"tonneau_b": [["cyl", 0.25, 0.71, Vector3(0, 0.355, 0)]],
	"caisse_a": [["boite", Vector3(0.66, 0.65, 0.66), Vector3(0, 0.325, 0)]],
	"caisse_b": [["boite", Vector3(0.88, 0.6, 0.68), Vector3(0, 0.3, 0)]],
	"charrette": [["boite", Vector3(1.5, 1.0, 2.2), Vector3(0, 0.5, 0.25)]],
	"tas_bois": [["boite", Vector3(1.95, 1.1, 1.05), Vector3(0, 0.55, 0)]],
	"tonneau_c": [["cyl", 0.31, 0.81, Vector3(0, 0.405, 0)]],
	"caisse_c": [["boite", Vector3(0.48, 0.45, 0.43), Vector3(0, 0.225, 0)]],
	"sacs": [["boite", Vector3(0.8, 0.55, 0.6), Vector3(0, 0.275, -0.1)]],
}

var monde: Node
var _corps: StaticBody3D
var _tissus: Array = []      # [Node3D, phase]
var _lumieres: Array = []    # [OmniLight3D, énergie, phase]
var _t := 0.0

static func creer(monde_: Node) -> MobilierVillage:
	var m := MobilierVillage.new()
	m.name = "MobilierVillage"
	m.monde = monde_
	monde_.add_child(m)
	m._construire()
	return m

static func _materiau(nom: String) -> Material:
	match nom:
		# E/pierre_chaude : margelle du puits, socle du brasero en pierre chaude comme le bâti (étaient gris-bleu (0.9, 0.92, 0.98), (0.92, 0.94, 1.0))
		"pierre_brute": return TexturesBati.m_pierre_brute_e(Color(1.0, 0.95, 0.86))
		"pierre_fine": return TexturesBati.m_pierre_fine_e(Color(1.03, 0.97, 0.88))
		# L7 : bois plus clair (était (0.85, 0.8, 0.75) : tonneaux presque noirs à distance de jeu), proche des planches du bâti
		"planches_h": return TexturesBati.m_planches_e(Color(1.0, 0.95, 0.88))
		"planches_v": return TexturesBati.m_bois_debout_e(Color(1.0, 0.95, 0.88))
		"fer": return TexturesBati.m_fer_e(Color(0.7, 0.7, 0.75))
		"cuir": return TexturesBati.m_cuir_e()
		"foin": return TexturesBati.m_foin_e()
		"braises": return TexturesBati.m_braises()
		"tenture_rouge", "peau":
			return TexturesBati.materiau(nom, Color.WHITE, 32.0, 0.6)   # tissus modélisés double face
	return TexturesBati.m_planches_e()

## Lit le .dat : {"module/matiere": [PackedVector3Array positions, PackedColorArray couleurs]} (ordre Godot des sommets).
## L7 : lu une fois (cache) et d'un bloc par entrée (était un get_buffer par sommet) ; le poste de forge, l'enclos et le feu de
## camp réutilisent le même cache (poser_dans / noeud_modules).
static var _cache := {}
static func charger() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var res := {}
	var f := FileAccess.open(DAT, FileAccess.READ)
	if f == null:
		push_error("MobilierVillage : %s introuvable" % DAT)
		return res
	var n := f.get_32()
	for _i in n:
		var ln := f.get_8()
		var nom := f.get_buffer(ln).get_string_from_utf8()
		var nv := f.get_32()
		var pos := PackedVector3Array()
		var col := PackedColorArray()
		pos.resize(nv)
		col.resize(nv)
		var d := f.get_buffer(nv * 28).to_float32_array()
		for k in nv:
			var o := k * 7
			pos[k] = Vector3(d[o], d[o + 1], d[o + 2])
			col[k] = Color(d[o + 3], d[o + 4], d[o + 5], d[o + 6])
		# Godot : face avant = sens horaire → on inverse chaque triangle (comme SolV2)
		for t in range(0, nv, 3):
			var p := pos[t + 1]
			pos[t + 1] = pos[t + 2]
			pos[t + 2] = p
			var c := col[t + 1]
			col[t + 1] = col[t + 2]
			col[t + 2] = c
		res[nom] = [pos, col]
	_cache = res
	return res

## Tableaux indexés (sommets dédoublonnés, normales plates) d'une entrée « module/matière », pour Village._ajouter : cache.
static var _indexes := {}
static func arrays_de(nom: String) -> Array:
	if _indexes.has(nom):
		return _indexes[nom]
	var d: Array = charger()[nom]
	var pos: PackedVector3Array = d[0]
	var col: PackedColorArray = d[1]
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var ii := PackedInt32Array()
	var vus := {}
	for t in range(0, pos.size(), 3):
		var nf := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])   # sens horaire (Godot) : normale sortante
		if nf.length_squared() < 1e-14:
			continue
		nf = nf.normalized()
		for j in 3:
			var cle := [pos[t + j], nf, col[t + j]]
			var k: int = vus.get(cle, -1)
			if k < 0:
				k = v.size()
				vus[cle] = k
				v.append(pos[t + j])
				nn.append(nf)
				cc.append(col[t + j])
			ii.append(k)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nn
	a[Mesh.ARRAY_COLOR] = cc
	a[Mesh.ARRAY_INDEX] = ii
	_indexes[nom] = a
	return a

## Matières de mobilier_village.py → matières du village (même lot de fusion que le bâti : aucun appel de dessin en plus).
static func mats_village(v) -> Dictionary:
	return {"planches_h": v.m_poutres_h, "planches_v": v.m_poutres, "fer": v.m_fer, "pierre_brute": v.m_brute, "pierre_fine": v.m_pierre_fine,
		"cuir": v.m_cuir, "peau": v.m_cuir, "foin": v.m_foin, "braises": v.m_braises}

## Pose un module dans un nœud du village (Village._ajouter : fusionné par matière avec le bâti). `xf` dans le repère de `parent`.
static func poser_dans(v, parent: Node3D, mod: String, xf: Transform3D, mats := {}) -> void:
	if mats.is_empty():
		mats = mats_village(v)
	var pre := mod + "/"
	for nom: String in charger():
		if nom.begins_with(pre):
			v._ajouter(parent, arrays_de(nom), xf, mats[nom.substr(pre.length())])

## Nœud autonome (hors du village : feu de camp du cercle) : poses [module, Transform3D] fusionnées par matière, matières C7a.
static func noeud_modules(poses: Array, nom_noeud: String) -> Node3D:
	var racine := Node3D.new()
	racine.name = nom_noeud
	var st_par := {}
	var donnees := charger()
	for p: Array in poses:
		var pre: String = String(p[0]) + "/"
		for nom: String in donnees:
			if not nom.begins_with(pre):
				continue
			var mat := nom.substr(pre.length())
			if not st_par.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st_par[mat] = st
			var d: Array = donnees[nom]
			var pos: PackedVector3Array = d[0]
			var col: PackedColorArray = d[1]
			var xf: Transform3D = p[1]
			for k in pos.size():
				(st_par[mat] as SurfaceTool).set_color(col[k])
				(st_par[mat] as SurfaceTool).add_vertex(xf * pos[k])
	for mat: String in st_par:
		var st: SurfaceTool = st_par[mat]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Mobilier_" + mat
		mi.mesh = st.commit()
		mi.material_override = _materiau(mat)
		racine.add_child(mi)
	return racine

func _sol(x: float, z: float) -> float:
	return DetailsSol.hauteur_maillage(monde, x, z)

## Hauteur de pose : le plus bas des 5 points de l'emprise (rien ne flotte), un peu enfoncé.
func _sol_bas(x: float, z: float, r: float) -> float:
	var h := _sol(x, z)
	for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		h = minf(h, _sol(x + d.x, z + d.y))
	return h - 0.03

func _construire() -> void:
	var t0 := Time.get_ticks_msec()
	var donnees := charger()
	if donnees.is_empty():
		return
	_corps = StaticBody3D.new()
	_corps.name = "CollisionsMobilier"
	add_child(_corps)
	var fusion := {}   # matière → SurfaceTool
	var tris := 0
	var num := 0
	for pose: Array in POSES:
		num += 1
		var mod: String = pose[0]
		var x: float = pose[1]
		var z: float = pose[2]
		var s: float = pose[4]
		var r_emprise: float = {"puits": 1.6, "etal": 1.4, "charrette": 1.2, "tas_bois": 0.9, "banc": 0.8, "sacs": 0.4}.get(mod, 0.3)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(pose[3])).scaled(Vector3.ONE * s), Vector3(x, _sol_bas(x, z, r_emprise), z))
		for nom: String in donnees:
			var morceaux := nom.split("/")
			if morceaux[0] != mod:
				continue
			if not fusion.has(morceaux[1]):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				fusion[morceaux[1]] = st
			_ajouter(fusion[morceaux[1]], donnees[nom], xf)
			tris += (donnees[nom][0] as PackedVector3Array).size() / 3
		if mod == "banniere":
			var piv := Node3D.new()
			piv.name = "Tissu"
			piv.transform = xf * Transform3D(Basis(), ACCROCHE_TISSU)
			add_child(piv)
			for nom: String in donnees:
				if nom.begins_with("banniere_tissu/"):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					_ajouter(st, donnees[nom], Transform3D.IDENTITY)
					st.generate_normals()
					var mi := MeshInstance3D.new()
					mi.mesh = st.commit()
					mi.material_override = _materiau(nom.split("/")[1])
					mi.visibility_range_end = PORTEE
					piv.add_child(mi)
					tris += (donnees[nom][0] as PackedVector3Array).size() / 3
			_tissus.append([piv, randf() * TAU, piv.rotation])
		if mod == "brasero":
			var haut := xf * Vector3(0, BRAISES_Y, 0)
			Torche.flamme_fixe(self, haut, 2.4, x * 0.37)
			if _lumieres.is_empty():   # une seule vraie lumière : le brasero de la place (premier de la liste)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.55, 0.22)
				l.light_energy = 2.2
				l.omni_range = 8.0
				l.omni_attenuation = 1.3
				l.shadow_enabled = false
				l.distance_fade_enabled = true
				l.distance_fade_begin = 12.0
				l.distance_fade_length = 6.0
				l.position = haut + Vector3(0, 0.35, 0)
				add_child(l)
				_lumieres.append([l, l.light_energy, x])
		for c: Array in COLLISIONS.get(mod, []):
			var forme := CollisionShape3D.new()
			forme.set_meta("objet", "%s#%d" % [mod, num])   # audit_interpenetrations : pièces d'un même module
			if c[0] == "cyl":
				var cy := CylinderShape3D.new()
				cy.radius = c[1] * s
				cy.height = c[2] * s
				forme.shape = cy
				forme.position = xf * (c[3] as Vector3)
			else:
				var bx := BoxShape3D.new()
				bx.size = (c[1] as Vector3) * s
				forme.shape = bx
				forme.transform = Transform3D(xf.basis.orthonormalized(), xf * (c[2] as Vector3))
			_corps.add_child(forme)
	for mat: String in fusion:
		var st: SurfaceTool = fusion[mat]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Mobilier_" + mat
		mi.mesh = st.commit()
		mi.material_override = _materiau(mat)
		mi.visibility_range_end = PORTEE
		add_child(mi)
	print("MobilierVillage : %d poses, %d triangles, %d matières, %d tissus, %d collisions, %d ms" % [POSES.size(), tris, fusion.size(), _tissus.size(), _corps.get_child_count(), Time.get_ticks_msec() - t0])

func _ajouter(st: SurfaceTool, d: Array, xf: Transform3D) -> void:
	var pos: PackedVector3Array = d[0]
	var col: PackedColorArray = d[1]
	for k in pos.size():
		st.set_color(col[k])
		st.add_vertex(xf * pos[k])

func _process(dt: float) -> void:
	_t += dt
	for t: Array in _tissus:
		var n: Node3D = t[0]
		var ph: float = t[1]
		var r0: Vector3 = t[2]
		n.rotation = r0 + Vector3(sin(_t * 1.3 + ph) * 0.05, sin(_t * 0.7 + ph * 1.7) * 0.06, 0.0)
	var cyc = monde.get("cycle") if monde != null else null
	var nuit := 1.0 - (float(cyc.clarte()) if cyc != null else 0.0)
	for l: Array in _lumieres:
		var k: float = l[2]
		(l[0] as OmniLight3D).light_energy = float(l[1]) * lerpf(0.45, 1.0, nuit) * (1.0 + sin(_t * 9.0 + k) * 0.05 + sin(_t * 23.0 + k) * 0.03)
