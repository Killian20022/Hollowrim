class_name PnjNordique
## PNJ du village et alliés : chacun est UN des archétypes nordiques ENTIER, de la tête aux pieds (Guerrier, Mage, Chasseresse, Gardien :
## mêmes 65 os Humain/Quaternius, mêmes pièces, mêmes animations, même ragdoll ; aucune pièce d'un autre modèle — D/pnj_complets,
## 2026-10-23 : plus de visage Humain greffé ni d'étoffe du haut recolorée seule) + une variante légère faite ICI, après la création :
##   - teinte : une BANDE de teintes de toute la tenue tournée ou désaturée (valeurs et tissage gardés, haut et bas assortis), cape du
##     garde au rouge du jarl ; images précalculées dans assets/pnj/<clé>.res (outils/generer_pnj.gd), recalcul au lancement si absentes ;
##   - coiffure : teinte des cheveux / de la barbe ;
##   - accessoires montrés / cachés : surfaces ou triangles de la maille d'accessoires retirés (cape, fourrure), pièces masquées ;
##   - armes : options des archétypes (épée, bouclier, bâton, arc) ou maillet / canne modelés ici, attachés à la main droite.
## PnjNordique.creer(id) -> Node3D (contrat de Humain.creer : Skeleton3D + AnimationPlayer « Animations »). `--pnj-anciens` (argument
## utilisateur) : les appelants retombent sur Humain.creer (voir ancien()).
##   ids : garde, forgeron, chasseuse, volva, ancienne, chef, eirik (+ garde_lance : Gardien à lance, pour alterner les gardes)

const DOSSIER := "res://assets/pnj"
const VERSION := 7
static var enregistrer := false
static var _cache := {}
static var _ancien := -1

const IDS := ["garde", "garde_lance", "forgeron", "chasseuse", "volva", "ancienne", "chef", "eirik"]

## Vrai si l'argument utilisateur `--pnj-anciens` est passé : les anciens corps Humain.creer partout.
static func ancien() -> bool:
	if _ancien < 0:
		_ancien = 1 if OS.get_cmdline_user_args().has("--pnj-anciens") else 0
	return _ancien == 1

static func vider() -> void:
	_cache.clear()

# ======================================================================================================== fabrique
static func creer(id: String) -> Node3D:
	var n: Node3D
	match id:
		"garde": n = _garde()
		"garde_lance": n = _garde_lance()
		"forgeron": n = _forgeron()
		"chasseuse": n = _chasseuse()
		"volva": n = _volva()
		"ancienne": n = _ancienne()
		"chef": n = _chef()
		"eirik": n = _eirik()
		_:
			push_warning("PnjNordique : id inconnu « %s », la cheffe est créée à la place" % id)
			n = _chef()
	n.set_meta("pnj_nordique", id)
	return n

static func _sq(n: Node3D) -> Skeleton3D:
	return n.find_child("Skeleton3D", true, false) as Skeleton3D

static func _pieces(sq: Skeleton3D) -> Dictionary:
	var d := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		d[String(mi.name)] = mi
	return d

# -------------------------------------------------------------------------------------------------------- variantes
## Haldor, garde de la porte : casque à nasal, mailles, épée et bouclier au bras ; la cape et le bouclier prennent le rouge du jarl.
static func _garde() -> Node3D:
	var n := GuerrierNordique.creer({"casque": true, "bouclier": "bras", "epee": true})
	n.name = "PnjGarde"
	var sq := _sq(n)
	var p := _pieces(sq)
	_cape_teinte(sq, "garde_cape", Color.from_hsv(0.0, 0.72, 1.0), 1.15)
	_teinte_tex(p["pantalon"], 0, "garde_pantalon", {"col": Color.from_hsv(0.08, 0.10, 1.0), "v": 0.80})
	_teinte_poil(p.get("Hair_Beard"), Color(0.62, 0.45, 0.30))
	return n

## Second garde (alternance) : Gardien à lance et bouclier dans le dos, même rouge de cape que le premier.
static func _garde_lance() -> Node3D:
	var n := GardienNordique.creer({"bouclier": "dos", "lance": true})
	n.name = "PnjGardeLance"
	return n

## Brodd, le forgeron : le Guerrier ENTIER, variante avant-bras nus (manches retroussées), sans casque, bouclier ni épée ; seule la cape
## est ôtée (accessoire : la fourrure des épaules, le plastron et la mante restent) ; barbe brune, maillet de forge.
static func _forgeron() -> Node3D:
	var n := GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false, "avant_bras_nus": true})
	n.name = "PnjForgeron"
	var sq := _sq(n)
	var p := _pieces(sq)
	_sans_cape(sq)
	_teinte_poil(p.get("Hair_Beard"), Color(0.55, 0.38, 0.24))
	_teinte_poil(p.get("Hair_Long"), Color(0.55, 0.38, 0.24))
	_maillet(sq)
	return n

## Ylva, la chasseuse : la Chasseresse ENTIÈRE (arc porté, carquois, couteau), étoffes de l'archétype ; cheveux roux.
static func _chasseuse() -> Node3D:
	var n := ChasseresseNordique.creer({})
	n.name = "PnjChasseuse"
	var p := _pieces(_sq(n))
	_teinte_poil(p.get("Hair_Long"), Color(1.15, 0.62, 0.42))
	return n

## Sigrún, la völva : le Mage ENTIER en corps femme (capuche profonde, visage dans l'ombre aux yeux luisants, pèlerine, écailles, robe,
## bâton à orbe) ; seule variante : les bleus de TOUTE la tenue tournés vers le violet (valeurs et tissage gardés, haut et bas assortis).
static func _volva() -> Node3D:
	var n := MageNordique.creer({"baton": true, "capuche": true, "corps": "femme"})
	n.name = "PnjVolva"
	_teinte_bande(_sq(n), "volva", {"bande": Vector2(0.48, 0.80), "dh": 0.07, "sm": 0.85, "smin": 0.05})
	return n

## Grima, l'ancienne : le Mage ENTIER en corps femme, sans bâton à orbe ; laines délavées (bleus de toute la tenue désaturés vers le
## gris, valeurs gardées) ; canne de marche.
static func _ancienne() -> Node3D:
	var n := MageNordique.creer({"baton": false, "capuche": true, "corps": "femme"})
	n.name = "PnjAncienne"
	var sq := _sq(n)
	_teinte_bande(sq, "ancienne", {"bande": Vector2(0.48, 0.80), "dh": 0.0, "sm": 0.3, "smin": 0.05})
	_canne(sq)
	return n

## Gunnhild, la cheffe : la Chasseresse ENTIÈRE sans arc, carquois ni couteau ; cheveux blond clair.
static func _chef() -> Node3D:
	var n := ChasseresseNordique.creer({"arc": false, "carquois": false, "couteau": false})
	n.name = "PnjChef"
	var p := _pieces(_sq(n))
	_teinte_poil(p.get("Hair_Long"), Color(1.1, 0.95, 0.70))
	return n

## Eirik, l'explorateur mort de la crypte : le Guerrier ENTIER sans casque, bouclier ni épée (elle gît au sol) ; bleus de la tenue tournés
## vers le vert (valeurs gardées), cheveux cuivrés, teint cireux.
static func _eirik() -> Node3D:
	var n := GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false})
	n.name = "PnjEirik"
	var sq := _sq(n)
	var p := _pieces(sq)
	_teinte_bande(sq, "eirik", {"bande": Vector2(0.48, 0.80), "dh": -0.27, "sm": 0.6})
	_teinte_poil(p.get("Hair_Beard"), Color(1.0, 0.62, 0.38))
	_teinte_poil(p.get("Hair_Long"), Color(1.0, 0.62, 0.38))
	var peau: MeshInstance3D = p.get("peau")
	if peau:
		_multiplier(peau, 0, Color(0.80, 0.86, 0.95))
	return n

## Cape du guerrier retirée (zone u < 0,64 de la surface « découpes » des accessoires) ; mèches de fourrure gardées.
static func _sans_cape(sq: Skeleton3D) -> void:
	var acc: MeshInstance3D = sq.get_node_or_null("accessoires")
	if acc:
		_filtrer_surface(acc, 1, func(_c: Vector3, _n: Vector3, uv: Vector2) -> bool: return uv.x > 0.64)

# ======================================================================================================== teintes
## Matériau (de la surface s, ou material_override si s < 0) dupliqué, texture tex_base teintée, remis sur la surface.
## spec : "col" Color (teinte + saturation cibles), "v" (facteur de valeur), "rect" Rect2i (zone en texels, sinon toute l'image).
static func _teinte_tex(mi: MeshInstance3D, s: int, cle: String, spec: Dictionary) -> void:
	if mi == null:
		return
	var m := _materiau_de(mi, s)
	if m == null:
		return
	var src := m.get_shader_parameter("tex_base") as Texture2D
	if src == null:
		return
	var m2 := m.duplicate() as ShaderMaterial
	m2.set_shader_parameter("tex_base", _texture_teintee(src, cle, spec))
	_enreg(m2)
	_poser_materiau(mi, s, m2)

## Teinte d'une BANDE de teintes sur toutes les pièces visibles (peau, cheveux, yeux et orbe exclus) : seuls les texels dont la teinte
## est dans spec.bande (et saturés) changent : teinte + dh, saturation x sm, valeur intacte. La tenue de l'archétype reste entière et
## assortie (haut et bas ensemble), cuirs, fourrures et métaux gardent leurs couleurs.
static func _teinte_bande(sq: Skeleton3D, prefixe: String, spec: Dictionary) -> void:
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		var nom := String(mi.name)
		if mi.mesh == null or not mi.visible or nom == "peau" or nom == "Eyes" or nom.begins_with("Hair") or nom == "Eyebrows":
			continue
		for s in mi.mesh.get_surface_count():
			var m := _materiau_de(mi, s)
			if m == null or m.shader == null or m.shader.resource_path.get_file() == "mage_orbe.gdshader":
				continue
			_teinte_tex(mi, s, "%s_%s_%d" % [prefixe, nom, s], spec)

static func _multiplier(mi: MeshInstance3D, s: int, c: Color) -> void:
	var m := _materiau_de(mi, s)
	if m == null:
		return
	var m2 := m.duplicate() as ShaderMaterial
	var te: Variant = m.get_shader_parameter("teinte")
	m2.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * c)
	_enreg(m2)
	_poser_materiau(mi, s, m2)

## Cheveux / barbe : teinte du matériau (la texture reste, la couleur est multipliée).
static func _teinte_poil(mi: MeshInstance3D, c: Color) -> void:
	if mi == null:
		return
	var m := _materiau_de(mi, -1)
	if m == null:
		return
	var m2 := m.duplicate() as ShaderMaterial
	m2.set_shader_parameter("teinte", c)
	_enreg(m2)
	mi.material_override = m2

## Cape du guerrier (zone D_CAPE de l'atlas des découpes) teintée ; la fourrure voisine ne change pas.
static func _cape_teinte(sq: Skeleton3D, cle: String, col: Color, v: float) -> void:
	var acc: MeshInstance3D = sq.get_node_or_null("accessoires")
	if acc == null:
		return
	for s in acc.mesh.get_surface_count():
		var m := _materiau_de(acc, s)
		if m != null and m.get_shader_parameter("decoupe") == true:
			_teinte_tex(acc, s, cle, {"col": col, "v": v, "rect": GuerrierTextures.D_CAPE})

static func _enreg(m: ShaderMaterial) -> void:
	Palette.materiaux.append(m)
	Palette._appliquer(m, Palette._ps1_actif)

static func _materiau_de(mi: MeshInstance3D, s: int) -> ShaderMaterial:
	var m: Material = null
	if s >= 0:
		m = mi.get_surface_override_material(s)
	if m == null:
		m = mi.material_override
	if m == null and s >= 0 and mi.mesh:
		m = mi.mesh.surface_get_material(s)
	return m as ShaderMaterial

static func _poser_materiau(mi: MeshInstance3D, s: int, m: ShaderMaterial) -> void:
	if s >= 0 and mi.material_override == null:
		mi.set_surface_override_material(s, m)
	elif s >= 0 and mi.get_surface_override_material(s) != null:
		mi.set_surface_override_material(s, m)
	else:
		mi.material_override = m

static func _chemin(cle: String) -> String:
	return "%s/%s.res" % [DOSSIER, cle.validate_filename()]

static func _texture_teintee(src: Texture2D, cle: String, spec: Dictionary) -> ImageTexture:
	if _cache.has(cle):
		return _cache[cle]
	var mips: Image = null
	if ResourceLoader.exists(_chemin(cle)):
		var im := ResourceLoader.load(_chemin(cle)) as Image
		if im != null and im.get_meta("version", -1) == VERSION:
			mips = im
	if mips == null:
		var img := src.get_image().duplicate() as Image     # copie : en --headless (serveur factice), get_image() rend l'image même de la texture
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var col: Color = spec.get("col", Color.WHITE)
		var vm: float = spec.get("v", 1.0)
		var add: float = spec.get("add", 0.0)
		var r: Rect2i = spec.get("rect", Rect2i(Vector2i.ZERO, img.get_size()))
		for y in range(r.position.y, mini(r.end.y, img.get_height())):
			for x in range(r.position.x, mini(r.end.x, img.get_width())):
				var c := img.get_pixel(x, y)
				if c.a < 0.05:
					continue
				var o: Color
				if spec.has("bande"):
					var b: Vector2 = spec["bande"]
					if c.s < float(spec.get("smin", 0.12)) or c.h < b.x or c.h > b.y:
						continue
					o = Color.from_hsv(fposmod(c.h + float(spec.get("dh", 0.0)), 1.0), clampf(c.s * float(spec.get("sm", 1.0)), 0.0, 1.0), c.v)
				else:
					o = Color.from_hsv(col.h, col.s, clampf(c.v * vm + add, 0.0, 1.0))
				o.a = c.a
				img.set_pixel(x, y, o)
		mips = GuerrierTextures.mips_pixel(img)
		if enregistrer:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
			mips.set_meta("version", VERSION)
			ResourceSaver.save(mips, _chemin(cle), ResourceSaver.FLAG_COMPRESS)
	_cache[cle] = ImageTexture.create_from_image(mips)
	return _cache[cle]

# ======================================================================================================== géométrie
## Retire de la surface s les triangles pour lesquels garder(centre, normale, uv moyen) est faux. Maille d'accessoires : sommets sans
## index, peau d'os conservée (mêmes sommets, mêmes poids) ; matériaux des autres surfaces remis.
static func _filtrer_surface(mi: MeshInstance3D, s: int, garder: Callable) -> void:
	if mi == null or mi.mesh == null or s >= mi.mesh.get_surface_count():
		return
	var mesh := ArrayMesh.new()
	var mats: Array = []
	for k in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(k)
		if k == s:
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			var garde := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var p0 := v[idx[t]]
				var p1 := v[idx[t + 1]]
				var p2 := v[idx[t + 2]]
				var nn := (p2 - p0).cross(p1 - p0).normalized()
				var uvm := Vector2.ZERO
				if uvs.size() == v.size():
					uvm = (uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0
				if garder.call((p0 + p1 + p2) / 3.0, nn, uvm):
					garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
			if garde.is_empty():
				continue     # surface entièrement retirée
			a[Mesh.ARRAY_INDEX] = garde
		var nb: int = 4
		if a[Mesh.ARRAY_BONES] != null and (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
			nb = (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
		mats.append(mi.get_surface_override_material(k))
	mi.mesh = mesh
	for j in mats.size():
		mi.set_surface_override_material(j, mats[j])

# ======================================================================================================== accessoires tenus
static func _boite(st: SurfaceTool, a: Vector3, b: Vector3, uv: Vector2) -> void:
	var c := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
		Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var faces := [[3, 2, 1, 0], [4, 5, 6, 7], [7, 6, 2, 3], [0, 1, 5, 4], [4, 7, 3, 0], [1, 2, 6, 5]]
	for f: Array in faces:
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv)
			st.add_vertex(c[f[k]])

static func _mesh_outil(boites: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Array in boites:
		_boite(st, b[0], b[1], b[2])
	st.generate_normals()
	return st.commit()

static func _tenir(sq: Skeleton3D, nom: String, prise: Transform3D, boites: Array) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.name = nom
	att.bone_name = "hand_r"
	sq.add_child(att)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_outil(boites)
	mi.transform = prise
	mi.material_override = GuerrierNordique.materiau(GuerrierTextures.tex("accessoires"), false, false, true)
	att.add_child(mi)
	return att

static func _uv_rect(r: Rect2i) -> Vector2:
	return (Vector2(r.position) + Vector2(r.size) * 0.5) / Vector2(GuerrierTextures.ATLAS)

## Maillet de forge : manche de bois, tête de fer, tenu comme l'épée du guerrier (même prise).
static func _maillet(sq: Skeleton3D) -> void:
	var bois := _uv_rect(GuerrierTextures.R_POIGNEE)
	var fer := _uv_rect(GuerrierTextures.R_FER)
	_tenir(sq, "Maillet", GuerrierNordique.Accessoires.PRISE, [
		[Vector3(-0.016, -0.05, -0.016), Vector3(0.016, 0.40, 0.016), bois],
		[Vector3(-0.045, 0.37, -0.085), Vector3(0.045, 0.46, 0.085), fer],
		[Vector3(-0.030, -0.065, -0.030), Vector3(0.030, -0.04, 0.030), fer]])

## Canne de marche de l'ancienne : même prise et même redressement que le bâton du mage (BatonDroit), mais un simple bâton de bois.
static func _canne(sq: Skeleton3D) -> void:
	var rb: Vector3 = MageNordique.reglage_baton
	var incl := Basis(Vector3.BACK, deg_to_rad(-rb.y)) * Basis(Vector3.RIGHT, deg_to_rad(-rb.z))
	var prise := MageNordique.PRISE_BATON * Transform3D(incl, Vector3(-rb.x, 0, 0))
	var bois := _uv_rect(GuerrierTextures.R_POIGNEE)
	var fer := _uv_rect(GuerrierTextures.R_FER)
	_tenir(sq, "Canne", prise, [
		[Vector3(-0.014, -0.84, -0.014), Vector3(0.014, 0.17, 0.014), bois],
		[Vector3(-0.016, -0.88, -0.016), Vector3(0.016, -0.84, 0.016), fer],
		[Vector3(-0.022, 0.17, -0.022), Vector3(0.022, 0.215, 0.022), bois],
		[Vector3(-0.060, 0.17, -0.020), Vector3(0.0, 0.20, 0.020), bois]])
	var bd := MageNordique.BatonDroit.new()
	bd.name = "BatonDroit"
	bd.os_ = sq.find_bone("hand_r")
	bd.prise = prise
	sq.add_child(bd)
