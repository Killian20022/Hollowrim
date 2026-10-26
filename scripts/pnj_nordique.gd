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
const VERSION := 9
static var enregistrer := false
static var _cache := {}
static var _ancien := -1

## Sorciers du village (völva, ancienne) : vrai visage âgé sous la capuche (D/pnj_village_v2, 2026-10-26) ; false = l'ombre + les
## yeux luisants du Mage archétype (visage caché).
const SORCIERS_VISAGE := true
## Peau et cheveux des sorcières (visage montré) : Sigrún, la völva (teint pâle et froid, cheveux gris argent) ; Grima, l'ancienne (teint
## plus rose et tanné, cheveux blancs).
const PEAU_VOLVA := Color(0.84, 0.79, 0.80)
const PEAU_ANCIENNE := Color(0.90, 0.80, 0.76)
const CHEVEUX_VOLVA := Color(0.62, 0.62, 0.66)
const CHEVEUX_ANCIENNE := Color(0.86, 0.85, 0.82)

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
	var c := CachePersos.lire("pnj_" + id, "res://scripts/pnj_nordique.gd", {})   # PNJ déjà bâti et teint (cache disque, cache_persos.gd)
	if c != null:
		return c
	c = _creer(id)
	CachePersos.ecrire("pnj_" + id, "res://scripts/pnj_nordique.gd", {}, c)
	return c

static func _creer(id: String) -> Node3D:
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

## L'archétype ENTIER de chaque PNJ, sans aucune retouche (options d'armes / de corps seulement) : base de chaque variante ci-dessous,
## référence du test (test_pnj_village : le PNJ garde toutes les pièces de son archétype) et de la planche (outils/planche_pnj_complets.gd).
static func archetype_seul(id: String) -> Node3D:
	match id:
		"garde": return GuerrierNordique.creer({"casque": true, "bouclier": "bras", "epee": true})
		"garde_lance": return GardienNordique.creer({"bouclier": "dos", "lance": true})
		"forgeron": return GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false, "avant_bras_nus": true})
		"chasseuse": return ChasseresseNordique.creer({})
		"volva": return MageNordique.creer({"baton": true, "capuche": true, "corps": "femme", "visage": SORCIERS_VISAGE, "peau": PEAU_VOLVA})
		"ancienne": return MageNordique.creer({"baton": false, "capuche": true, "corps": "femme", "visage": SORCIERS_VISAGE, "peau": PEAU_ANCIENNE})
		"chef": return ChasseresseNordique.creer({"arc": false, "carquois": false, "couteau": false})
		"eirik": return GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false})
	return null

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
	var n := archetype_seul("garde")
	n.name = "PnjGarde"
	var sq := _sq(n)
	var p := _pieces(sq)
	_cape_teinte(sq, "garde_cape", Color.from_hsv(0.0, 0.72, 1.0), 1.15)
	_teinte_tex(p["pantalon"], 0, "garde_pantalon", {"col": Color.from_hsv(0.08, 0.10, 1.0), "v": 0.80})
	_teinte_poil(p.get("Hair_Beard"), Color(0.62, 0.45, 0.30))
	return n

## Second garde (alternance) : Gardien à lance et bouclier dans le dos, même rouge de cape que le premier.
static func _garde_lance() -> Node3D:
	var n := archetype_seul("garde_lance")
	n.name = "PnjGardeLance"
	return n

## Brodd, le forgeron : le Guerrier ENTIER, variante avant-bras nus (manches retroussées), sans casque, bouclier ni épée ; seule la cape
## est ôtée (accessoire : la fourrure des épaules, le plastron et la mante restent) ; barbe, cheveux et nattes brun foncé, tenue
## tournée vers le cuir brun, maillet de forge.
static func _forgeron() -> Node3D:
	var n := archetype_seul("forgeron")
	n.name = "PnjForgeron"
	var sq := _sq(n)
	var p := _pieces(sq)
	_sans_cape(sq)
	# variante nette d'Haldor (même Guerrier) : barbe et cheveux brun très foncé (Haldor : roux), bleus de la tenue tournés vers le
	# cuir brun (col, tabard : l'homme de la forge, sans le bleu de la garde)
	_teinte_poil(p.get("Hair_Beard"), Color(0.36, 0.27, 0.21))
	_teinte_poil(p.get("Hair_Long"), Color(0.36, 0.27, 0.21))
	_teinte_bande(sq, "forgeron", {"bande": Vector2(0.48, 0.80), "dh": -0.55, "sm": 0.45, "vm": 0.95})
	_tresses_teinte(sq, "forgeron_tresses", Color.from_hsv(0.07, 0.40, 1.0), 0.50)
	_maillet(sq)
	return n

## Ylva, la chasseuse : la Chasseresse ENTIÈRE (arc porté, carquois, couteau), étoffes de l'archétype ; cheveux et nattes roux.
static func _chasseuse() -> Node3D:
	var n := archetype_seul("chasseuse")
	n.name = "PnjChasseuse"
	var p := _pieces(_sq(n))
	_teinte_poil(p.get("Hair_Long"), Color(1.15, 0.62, 0.42))
	# les deux nattes (accessoires) restaient blondes sous des cheveux roux
	_tresses_teinte(_sq(n), "chasseuse_tresses", Color.from_hsv(0.045, 0.62, 1.0), 1.0)
	return n

## Sigrún, la völva : le Mage ENTIER en corps femme (capuche profonde, visage dans l'ombre aux yeux luisants, pèlerine, écailles, robe,
## bâton à orbe) ; seule variante : les bleus de TOUTE la tenue tournés vers le violet (valeurs et tissage gardés, haut et bas assortis).
static func _volva() -> Node3D:
	var n := archetype_seul("volva")
	n.name = "PnjVolva"
	if SORCIERS_VISAGE:
		_vieillir(_sq(n), "volva_peau", {"age": 0.75, "creux": 0.9, "taches": 0.3, "sourcils": Color(0.50, 0.50, 0.53), "cheveux": CHEVEUX_VOLVA})
	_teinte_bande(_sq(n), "volva", {"bande": Vector2(0.48, 0.80), "dh": 0.14, "sm": 0.6, "smin": 0.05})
	return n

## Grima, l'ancienne : le Mage ENTIER en corps femme, sans bâton à orbe ; laines délavées (bleus de toute la tenue désaturés vers le
## gris, valeurs gardées) ; canne de marche.
static func _ancienne() -> Node3D:
	var n := archetype_seul("ancienne")
	n.name = "PnjAncienne"
	var sq := _sq(n)
	if SORCIERS_VISAGE:
		_vieillir(sq, "ancienne_peau", {"age": 1.0, "creux": 0.6, "taches": 1.0, "sourcils": Color(0.80, 0.78, 0.74), "cheveux": CHEVEUX_ANCIENNE})
	_teinte_bande(sq, "ancienne", {"bande": Vector2(0.48, 0.80), "dh": -0.52, "sm": 0.35, "smin": 0.05, "vm": 1.15})
	# foulard de lin écru (la capuche) : silhouette claire, elle ne se confond plus avec la völva
	_teinte_tex(_pieces(sq).get("capuche"), -1, "ancienne_foulard", {"col": Color.from_hsv(0.09, 0.22, 1.0), "v": 1.9, "add": 0.06})
	_canne(sq)
	return n

## Gunnhild, la cheffe : la Chasseresse ENTIÈRE sans arc, carquois ni couteau ; cheveux et nattes gris cendré, tenue lie-de-vin.
static func _chef() -> Node3D:
	var n := archetype_seul("chef")
	n.name = "PnjChef"
	var sq := _sq(n)
	var p := _pieces(sq)
	# variante nette d'Ylva (même Chasseresse) : femme mûre, cheveux et nattes blond cendré grisonnant, bleus de la tenue tournés
	# vers le lie-de-vin (la cheffe ; ni le violet de la völva ni le rouge vif de la garde)
	# le multiplicateur « teinte » ne désature pas le blond doré : la texture des cheveux est elle-même repeinte en cendré
	_teinte_tex(p.get("Hair_Long"), -1, "chef_cheveux", {"col": Color.from_hsv(0.09, 0.14, 1.0), "v": 0.72})
	_teinte_poil(p.get("Hair_Long"), Color(1.0, 1.0, 1.0))
	_tresses_teinte(sq, "chef_tresses", Color.from_hsv(0.09, 0.14, 1.0), 0.65)
	# smin bas : la cape de la chasseresse est un bleu ardoise très désaturé
	_teinte_bande(sq, "chef", {"bande": Vector2(0.48, 0.80), "dh": 0.38, "sm": 1.5, "smin": 0.03, "vm": 0.92})
	return n

## Eirik, l'explorateur mort de la crypte : le Guerrier ENTIER sans casque, bouclier ni épée (elle gît au sol) ; bleus de la tenue tournés
## vers le vert (valeurs gardées), cheveux cuivrés, teint cireux.
static func _eirik() -> Node3D:
	var n := archetype_seul("eirik")
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
	var t := _texture_teintee(src, cle, spec)
	if t == null:
		return     # rien à teinter : matériau de l'archétype gardé
	var m2 := m.duplicate() as ShaderMaterial
	m2.set_shader_parameter("tex_base", t)
	_enreg(m2)
	_poser_materiau(mi, s, m2)

## Teinte d'une BANDE de teintes sur toutes les pièces visibles (peau, cheveux, yeux et orbe exclus) : seuls les texels dont la teinte
## est dans spec.bande (et saturés) changent : teinte + dh, saturation x sm, valeur intacte. La tenue de l'archétype reste entière et
## assortie (haut et bas ensemble), cuirs, fourrures et métaux gardent leurs couleurs.
static func _teinte_bande(sq: Skeleton3D, prefixe: String, spec: Dictionary) -> void:
	var cles := {}     # texture source -> clé (l'atlas partagé par la jupe et les accessoires du mage n'est teinté qu'une fois)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		var nom := String(mi.name)
		if mi.mesh == null or not mi.visible or nom == "peau" or nom == "Eyes" or nom.begins_with("Hair") or nom == "Eyebrows":
			continue
		for s in mi.mesh.get_surface_count():
			var m := _materiau_de(mi, s)
			if m == null or m.shader == null or m.shader.resource_path.get_file() == "mage_orbe.gdshader":
				continue
			var src: Variant = m.get_shader_parameter("tex_base")
			if not cles.has(src):
				cles[src] = "%s_%s_%d" % [prefixe, nom, s]
			_teinte_tex(mi, s, cles[src], spec)

## Visage âgé, peint dans la texture de peau (sans géométrie ni surface de plus) : chaque triangle du visage (repos) est rastérisé
## dans l'atlas, la position 3D de chaque texel donne rides du front, pattes d'oie, poches sous les yeux, sillons nez-bouche,
## plis d'amertume, joues creusées et taches de vieillesse (spec : "age" 0..1 force des rides, "creux" joues, "taches").
## Repères : centres des yeux (maillage Eyes, caché). Image précalculée comme les teintes (assets/pnj/<clé>.res).
static func _vieillir(sq: Skeleton3D, cle: String, spec: Dictionary) -> void:
	var peau: MeshInstance3D = sq.get_node_or_null("peau")
	if peau == null or peau.mesh == null:
		return
	var m := _materiau_de(peau, 0)
	if m == null:
		return
	var src := m.get_shader_parameter("tex_base") as Texture2D
	if src == null:
		return
	var t: ImageTexture = null
	if _cache.has(cle):
		t = _cache[cle]
	else:
		var mips: Image = null
		if ResourceLoader.exists(_chemin(cle)):
			var im := ResourceLoader.load(_chemin(cle)) as Image
			if im != null and im.get_meta("version", -1) == VERSION:
				mips = im
		if mips == null:
			var img := src.get_image().duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.clear_mipmaps()
			img.convert(Image.FORMAT_RGBA8)
			_peindre_age(img, peau, GuerrierNordique._centres_yeux(sq.get_node_or_null("Eyes")), spec)

			mips = GuerrierTextures.mips_pixel(img)
			if enregistrer:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
				mips.set_meta("version", VERSION)
				ResourceSaver.save(mips, _chemin(cle), ResourceSaver.FLAG_COMPRESS)
		t = ImageTexture.create_from_image(mips)
		_cache[cle] = t
	var m2 := m.duplicate() as ShaderMaterial
	m2.set_shader_parameter("tex_base", t)
	_enreg(m2)
	_poser_materiau(peau, 0, m2)

## Distance du point p (x, y) au segment a-b (plan du visage).
static func _dseg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - a - ab * h).length()

## Assombrissement (0..1) du texel en q (repère du modèle) : somme des marques de l'âge, en traits nets (seuils, pas de dégradé
## qui scintille) ; < 0 = éclaircissement (arête du pli, pommette).
static func _ride(q: Vector3, oe: Vector3, spec: Dictionary) -> float:
	var age: float = spec.get("age", 1.0)
	var x := absf(q.x)
	var ex := absf(oe.x)
	var y := q.y - oe.y     # 0 = hauteur des yeux
	var p := Vector2(x, y)
	var d := 0.0
	# front : 3 rides horizontales légèrement ondulées, au-dessus des sourcils
	if y > 0.030 and y < 0.075 and x < 0.050:
		var yy := y + 0.0025 * sin(x * 140.0)
		for k in 3:
			if absf(yy - (0.040 + 0.0105 * k)) < 0.0013 + 0.0004 * (2 - k):
				d = maxf(d, 0.55 * age * (1.0 - x / 0.06))
	# entre les sourcils : deux plis verticaux
	if absf(x - 0.007) < 0.0012 and y > 0.012 and y < 0.030:
		d = maxf(d, 0.45 * age)
	# pattes d'oie : 3 rayons depuis le coin extérieur de l'œil
	var coin := Vector2(ex + 0.016, 0.0)
	var r := p - coin
	if r.x > 0.0 and r.length() < 0.018:
		var ang := atan2(r.y, r.x)
		for a0 in [-0.45, 0.0, 0.45]:
			if absf(ang - a0) < 0.10:
				d = maxf(d, 0.5 * age)
	# poches sous les yeux : arc sombre + arête claire dessous
	var dx := (x - ex) / 0.016
	if absf(dx) < 1.0:
		var arc := -0.010 - 0.004 * (1.0 - dx * dx)
		if absf(y - arc) < 0.0013:
			d = maxf(d, 0.5 * age)
		elif absf(y - (arc - 0.003)) < 0.0012:
			d = minf(d, -0.15 * age) if d <= 0.0 else d
	# sillons nez-bouche (aile du nez -> coin de la bouche) et plis d'amertume (coin de la bouche -> menton)
	var s1 := _dseg(p, Vector2(0.020, -0.040), Vector2(0.033, -0.072))
	var s2 := _dseg(p, Vector2(0.031, -0.080), Vector2(0.036, -0.098))
	if s1 < 0.0016:
		d = maxf(d, 0.6 * age)
	elif s1 < 0.0040 and x > 0.027 + (-0.040 - y) * 0.35:
		d = minf(d, -0.12 * age) if d <= 0.0 else d     # arête claire du pli, côté joue
	if s2 < 0.0014:
		d = maxf(d, 0.45 * age)
	# orbites creusées (lisibles de loin : le regard s'enfonce sous l'arcade) : anneau sombre autour de l'œil, plus fort dessous
	var orb := Vector2((x - ex) / 0.021, (y + 0.002) / 0.014)
	var lo := orb.length()
	if lo < 1.0 and lo > 0.55:
		d = maxf(d, 0.12 * age * (1.0 if y < 0.0 else 0.4))
	# joues creusées sous la pommette (zone pleine, deux paliers nets)
	var cr: float = spec.get("creux", 0.0)
	var jc := Vector2((x - (ex + 0.008)) / 0.020, (y + 0.050) / 0.018)
	var lj := jc.length()
	if lj < 1.0:
		d = maxf(d, cr * (0.30 if lj < 0.6 else 0.16))
	# pommette éclairée au-dessus du creux
	elif cr > 0.0 and absf(x - ex - 0.010) < 0.012 and y > -0.030 and y < -0.020:
		d = minf(d, -0.10 * cr) if d <= 0.0 else d
	return d

## Sourcils peints (les sourcils Quaternius coûtent 1 480 triangles) : arc de 2,6 cm au-dessus de chaque œil, clairsemé (âge) ;
## renvoie l'opacité 0..1 du poil au point q.
static func _sourcil(q: Vector3, oe: Vector3, k: Vector2i) -> float:
	var ex := absf(oe.x)
	var dx := (absf(q.x) - ex + 0.002) / 0.015
	if absf(dx) > 1.0:
		return 0.0
	var arc := 0.017 + 0.004 * (1.0 - dx * dx) - 0.002 * dx
	var e := 0.0024 * (1.0 - 0.45 * maxf(0.0, dx))
	if absf(q.y - oe.y - arc) > e:
		return 0.0
	return 1.0 if GuerrierTextures._h(k.x, k.y, 3307) > 0.25 else 0.0

static func _peindre_age(img: Image, peau: MeshInstance3D, yeux: Array, spec: Dictionary) -> void:
	var a := peau.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var W := img.get_width()
	var H := img.get_height()
	var oe: Vector3 = yeux[0]
	var taches: float = spec.get("taches", 0.0)
	var fait := {}
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var cen := (p0 + p1 + p2) / 3.0
		# visage seulement : devant de la tête, du menton au sommet du crâne (cheveux peints sous la capuche)
		if cen.z < -0.03 or cen.y < oe.y - 0.13 or cen.y > oe.y + 0.16 or absf(cen.x) > 0.095:
			continue
		var u0 := uv[idx[t]] * Vector2(W, H)
		var u1 := uv[idx[t + 1]] * Vector2(W, H)
		var u2 := uv[idx[t + 2]] * Vector2(W, H)
		var den := (u1.y - u2.y) * (u0.x - u2.x) + (u2.x - u1.x) * (u0.y - u2.y)
		if absf(den) < 1e-6:
			continue
		for ty in range(int(floor(minf(u0.y, minf(u1.y, u2.y)))), int(ceil(maxf(u0.y, maxf(u1.y, u2.y)))) + 1):
			for tx in range(int(floor(minf(u0.x, minf(u1.x, u2.x)))), int(ceil(maxf(u0.x, maxf(u1.x, u2.x)))) + 1):
				var c := Vector2(tx + 0.5, ty + 0.5)
				var l0 := ((u1.y - u2.y) * (c.x - u2.x) + (u2.x - u1.x) * (c.y - u2.y)) / den
				var l1 := ((u2.y - u0.y) * (c.x - u2.x) + (u0.x - u2.x) * (c.y - u2.y)) / den
				var l2 := 1.0 - l0 - l1
				if l0 < -0.02 or l1 < -0.02 or l2 < -0.02:
					continue
				var k := Vector2i(posmod(tx, W), posmod(ty, H))
				if fait.has(k):
					continue
				fait[k] = true
				var q := p0 * l0 + p1 * l1 + p2 * l2
				var d := _ride(q, oe, spec)
				# taches de vieillesse (tempes, front, pommettes) : bruit à seuil net
				if taches > 0.0 and GuerrierTextures._h(k.x, k.y, 3301) > 1.0 - 0.025 * taches and (q.y > oe.y + 0.02 or absf(q.x) > 0.04):
					d = maxf(d, 0.28)
				var col := img.get_pixel(k.x, k.y)
				# cheveux sous la capuche : au-dessus de la lisière (arrondie, golfes aux tempes), mèches peignées en arrière (raie au
				# milieu), gris / blancs ; le cuir chevelu sombre de la texture d'origine ne se voit plus quand le capuchon est relevé
				var xs := absf(q.x)
				var lisiere := oe.y + 0.048 + 0.006 * (xs / 0.05) * (xs / 0.05) - 0.012 * smoothstep(0.045, 0.075, xs)
				if q.y > lisiere or (q.z < 0.04 and q.y > oe.y + 0.01):
					var ch: Color = spec.get("cheveux", Color(0.75, 0.74, 0.72))
					var raie := xs < 0.0025 and q.y > lisiere + 0.004
					var brin := GuerrierTextures._n(int(q.x * 900.0) + 512, int(q.y * 120.0) + 512, 1024, 1024, 128, 16, 3311)
					var f := 0.62 if raie else (0.80 if brin < 0.35 else (1.0 if brin < 0.75 else 1.12))
					img.set_pixel(k.x, k.y, Color(minf(ch.r * f, 1.0), minf(ch.g * f, 1.0), minf(ch.b * f, 1.0)))
					continue
				# fard bleu de la texture d'origine (corps femme) sur les paupières : repeint en peau, ombre de paupière brune
				if absf(q.y - oe.y) < 0.016 and absf(xs - absf(oe.x)) < 0.022 and col.b > col.r * 0.95:
					var lp := col.get_luminance()
					col = Color(lp * 1.12, lp * 0.92, lp * 0.82)
				if _sourcil(q, oe, k) > 0.0:
					img.set_pixel(k.x, k.y, (spec.get("sourcils", Color(0.62, 0.60, 0.58)) as Color))
					continue
				# teint âgé : un peu désaturé partout sur le visage
				# (pâli et refroidi : la peau tannée de l'atlas se lisait orange, jeune, sous la lumière froide)
				var lum := col.get_luminance()
				col = col.lerp(Color(lum * 1.10, lum * 1.02, lum * 1.00), float(spec.get("pale", 0.45)))
				if d > 0.0:
					col = Color(col.r * (1.0 - d * 0.80), col.g * (1.0 - d * 0.88), col.b * (1.0 - d * 0.84))
				elif d < 0.0:
					col = col.lerp(Color(1.0, 0.95, 0.90), -d)
				col.a = 1.0
				img.set_pixel(k.x, k.y, col)

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

## Nattes de la chasseresse (zone R_TRESSE de l'atlas opaque des accessoires) teintes comme les cheveux.
static func _tresses_teinte(sq: Skeleton3D, cle: String, col: Color, v: float) -> void:
	var acc: MeshInstance3D = sq.get_node_or_null("accessoires")
	if acc == null:
		return
	for s in acc.mesh.get_surface_count():
		var m := _materiau_de(acc, s)
		if m != null and m.get_shader_parameter("decoupe") != true and m.get_shader_parameter("tex_base") != null:
			_teinte_tex(acc, s, "%s_%d" % [cle, s], {"col": col, "v": v, "rect": GuerrierTextures.R_TRESSE})

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
		var nb := 0
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
					o = Color.from_hsv(fposmod(c.h + float(spec.get("dh", 0.0)), 1.0), clampf(c.s * float(spec.get("sm", 1.0)), 0.0, 1.0), clampf(c.v * float(spec.get("vm", 1.0)), 0.0, 1.0))
				else:
					o = Color.from_hsv(col.h, col.s, clampf(c.v * vm + add, 0.0, 1.0))
				o.a = c.a
				img.set_pixel(x, y, o)
				nb += 1
		if nb == 0:
			# aucun texel dans la bande (bottes, cuirs) : la texture de l'archétype reste, marqueur d'une image 1x1 enregistré
			mips = Image.create(1, 1, false, Image.FORMAT_RGBA8)
			mips.set_meta("identique", true)
		else:
			mips = GuerrierTextures.mips_pixel(img)
		if enregistrer:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
			mips.set_meta("version", VERSION)
			ResourceSaver.save(mips, _chemin(cle), ResourceSaver.FLAG_COMPRESS)
	_cache[cle] = null if mips.get_meta("identique", false) else ImageTexture.create_from_image(mips)
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
