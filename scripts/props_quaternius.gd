class_name PropsQuaternius
## Props Quaternius (CC0, Fantasy Props MegaKit + Medieval Village MegaKit) adaptés par sources_blender/scripts/importer_quaternius.py
## (references/quaternius_props/CATALOGUE.md). Fichier : assets/crypte/modules/props_quaternius.dat, entrées « q_<nom>__<matière> »,
## triangles non indexés (sommet = position + couleur ton × occlusion, alpha 1 = matière sans neige).
##
## Trois usages, toujours FONDUS dans les lots existants (aucun nœud par objet, aucun appel de dessin en plus quand la matière est déjà
## dans le lot) :
##   - intérieurs (Interieurs.q) : Village._ajouter, lots par (pièce, matière) ;
##   - village (MobilierVillage, marché) : SurfaceTool par matière du mobilier ;
##   - crypte (crypte()) : CrypteDecor.modele (tampons de la case de 8 m, emprise automatique).
## Règle fer → fer_mat (CATALOGUE §6) : le fer des props se pose MAT partout (la variante brillante sortait beige-doré).

const DAT := "res://assets/crypte/modules/props_quaternius.dat"

## Crypte : matières des props → matières de CrypteDecor (pierre → pierre_v2 par MAT_MODELE ; lin, jute, os, or… gardés : TUILE).
const MATS_CRYPTE := {"fer": "fer_mat"}

## `-- --sans-props-q` : rien n'est posé (captures « avant » et mesures A/B du coût, même lancement que le jeu).
static var actif := not ("--sans-props-q" in OS.get_cmdline_user_args())
static var _mods := {}        # nom -> [[matière, arrays indexés (ordre Godot, normales plates)]]
static var _boites := {}      # nom -> AABB (repère du prop : origine au sol, au centre de l'emprise)
static var _brut := {}        # nom -> [[matière, PackedVector3Array, PackedColorArray]] (ordre Godot)
static var _verrou := Mutex.new()
static var _crypte_lu := false

static func _charger() -> void:
	_verrou.lock()
	if _brut.is_empty():
		var f := FileAccess.open(DAT, FileAccess.READ)
		if f == null:
			push_error("PropsQuaternius : %s introuvable" % DAT)
		else:
			var n := f.get_32()
			for _k in n:
				var cle := f.get_buffer(f.get_8()).get_string_from_utf8()
				var nb := f.get_32()
				var fl := f.get_buffer(nb * 28).to_float32_array()
				var pos := PackedVector3Array()
				var col := PackedColorArray()
				pos.resize(nb)
				col.resize(nb)
				for q in nb:
					var o := q * 7
					pos[q] = Vector3(fl[o], fl[o + 1], fl[o + 2])
					col[q] = Color(fl[o + 3], fl[o + 4], fl[o + 5], 1.0)
				for t in range(0, nb, 3):     # Godot : face avant = sens horaire → a, c, b
					var p := pos[t + 1]
					pos[t + 1] = pos[t + 2]
					pos[t + 2] = p
					var c := col[t + 1]
					col[t + 1] = col[t + 2]
					col[t + 2] = c
				var mc := cle.split("__")
				if not _brut.has(mc[0]):
					_brut[mc[0]] = []
				(_brut[mc[0]] as Array).append([mc[1], pos, col])
				var bb: AABB = _boites.get(mc[0], AABB(pos[0], Vector3.ZERO)) if nb > 0 else _boites.get(mc[0], AABB())
				for q in nb:
					bb = bb.expand(pos[q])
				_boites[mc[0]] = bb
	_verrou.unlock()

static func existe(nom: String) -> bool:
	_charger()
	return _brut.has(nom)

## Boîte englobante du prop dans son repère (origine au sol, au centre de l'emprise ; X largeur, Y hauteur, Z profondeur).
static func boite(nom: String) -> AABB:
	_charger()
	return _boites.get(nom, AABB())

## Tableaux indexés (sommets dédoublonnés, normales plates) de chaque matière du prop : [[matière, arrays], …] (cache).
static func morceaux(nom: String) -> Array:
	_charger()
	_verrou.lock()
	if not _mods.has(nom):
		var res := []
		for e: Array in _brut.get(nom, []):
			var pos: PackedVector3Array = e[1]
			var col: PackedColorArray = e[2]
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var cc := PackedColorArray()
			var ii := PackedInt32Array()
			var vus := {}
			for t in range(0, pos.size(), 3):
				var nf := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])
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
			res.append([e[0], a])
		_mods[nom] = res
	var r: Array = _mods[nom]
	_verrou.unlock()
	return r

## Triangles bruts (ordre Godot) d'une matière, pour un SurfaceTool : [[matière, positions, couleurs], …].
static func triangles(nom: String) -> Array:
	_charger()
	return _brut.get(nom, [])

## Nombre de triangles d'un prop (mesure du coût).
static func nb_triangles(nom: String) -> int:
	var n := 0
	for e: Array in triangles(nom):
		n += (e[1] as PackedVector3Array).size() / 3
	return n

# ------------------------------------------------------------------------------------------------ crypte

## Pose un prop dans la crypte (repère local du module en cours de `d`), fondu dans les tampons du décor, emprise automatique
## (la pose aléatoire des détritus l'évite). `solide` : boîte de collision (gros objets). `mats` s'ajoute à MATS_CRYPTE.
static func crypte(d: CrypteDecor, nom: String, pos: Vector3, lacet := 0.0, e := 1.0, solide := false, mats := {}) -> void:
	if not actif:
		return
	_verrou.lock()
	if not _crypte_lu:
		_crypte_lu = true
		CrypteDecor._charger_modeles()
		CrypteDecor._modeles_verrou.lock()
		CrypteDecor._lire_dat(DAT)
		CrypteDecor._modeles_verrou.unlock()
	_verrou.unlock()
	if pos.y < 0.05:      # au sol : écarté du soubassement des murs (même règle que le mobilier de la crypte)
		var bb0 := boite(nom)
		pos = d._ecarter(pos, Vector2(bb0.size.x, bb0.size.z) * 0.5 * e, lacet)
	var m := MATS_CRYPTE.duplicate()
	m.merge(mats, true)
	d.modele(nom, pos, lacet, Vector3.ONE * e, m, true)
	if solide:
		var bb := boite(nom)
		var c := pos + Basis(Vector3.UP, lacet) * (bb.get_center() * e)
		var t := bb.size * e
		var b := Basis(Vector3.UP, lacet)
		var demi := (b * Vector3(t.x, 0, 0)).abs() + (b * Vector3(0, 0, t.z)).abs()     # boîte alignée sur les axes (solide() ne tourne pas)
		d.solide(c, Vector3(demi.x, t.y, demi.z))

# ------------------------------------------------------------------------------------------------ village (dehors)

static var _mats_v := {}
static var _mats_v_de: Object = null

## Matières du village pour les props (lots fondus avec le bâti : bois = poutres, fer = ferrures, jute = foin, pierre = pierre chaude
## des soubassements) ; lin, os, or, argile : textures de la crypte sur le shader du bâti (comme les intérieurs).
static func mats_village(v) -> Dictionary:
	if _mats_v_de != v:
		_mats_v_de = v
		for nom in ["os", "lin", "or", "argile"]:
			if not TexturesBati._cache.has(nom):
				var img: Image = ResourceLoader.load("res://assets/crypte/%s.res" % nom)
				TexturesBati._cache[nom] = [ImageTexture.create_from_image(img), TexturesBati.relief_neutre()]
		_mats_v = {"bois": v.m_poutres_h, "fer": v.m_fer, "jute": v.m_foin, "pierre": v.m_brute_soub, "noir": v.m_fer,
			"lin": TexturesBati.materiau("lin", Color(1.0, 0.96, 0.9), 64.0, 0.4),
			"os": TexturesBati.materiau("os", Color(1.1, 1.05, 0.95), 64.0, 0.0),
			"or": TexturesBati.materiau("or", Color(1.0, 0.95, 0.85), 64.0, 0.3),
			"argile": TexturesBati.materiau("argile", Color(1.05, 0.95, 0.9), 64.0, 0.4)}
		_mats_v["laine"] = _mats_v["lin"]
		_mats_v["toile"] = _mats_v["lin"]
	return _mats_v

## Pose un prop dehors, fondu dans les lots du village (Village._ajouter) ; `xf` dans le repère de `parent` (sol à y 0) ; `mats` :
## matière du prop -> nom de matière de mats_village (ex. {"fer": "argile"}) ; `solide` : boîte de collision de l'emprise.
static func village(v, parent: Node3D, nom: String, xf: Transform3D, solide := false, mats := {}) -> void:
	if not actif or not existe(nom):
		return
	var mv := mats_village(v)
	for m: Array in morceaux(nom):
		v._ajouter(parent, m[1], xf, mv[mats.get(m[0], m[0])] if mv.has(mats.get(m[0], m[0])) else mv["bois"])
	if solide:
		var bb := boite(nom)
		var s := xf.basis.get_scale()
		v._collision(parent, BoxShape3D.new(), Transform3D(xf.basis.orthonormalized(), xf * bb.get_center()), bb.size * s)
