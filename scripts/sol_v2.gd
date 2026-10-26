class_name SolV2
## Extérieurs v2 : sol de la portion témoin du chemin (docs/DIAGNOSTIC_SOL.md).
## Le shader ps1 (branche `sol2_rect`) dessine dans ce rectangle un sol procédural à texels fins ; ce script
## l'active par zone (`--sol-v2=off` ou l'option de pose `sol_v2=0` rendent l'ancien sol, pour les captures
## avant/après) et pose les éléments 3D de la zone : touffes d'herbe sèche qui sortent de la neige, rochers
## organiques (sources_blender/scripts/roches_sol_v2.py) et pierres de tailles variées au bord du chemin.

## Rectangle témoin (x0, z0, x1, z1) autour du chemin feu → cercle.
const RECT := Vector4(-22.0, -22.0, -8.0, -8.0)
## C1 : le sol v2 (shader) couvre toute la carte ; RECT ne sert plus qu'à la zone témoin (touffes/rochers d'origine).
const MONDE := Vector4(-119.5, -119.5, 119.5, 119.5)
const DAT_ROCHES := "res://assets/modeles/roches_sol_v2.dat"
const PORTEE := 45.0

static var actif := true
static var actif_defaut := true
static var _decor: Node3D = null
static var _corps: Array[CollisionShape3D] = []

static func appliquer(monde: Node) -> void:
	if not ZoneBiome.actif:
		return
	var a: Dictionary = monde._arguments()
	actif_defaut = String(a.get("sol-v2", "on")) != "off"
	regler(monde, actif_defaut)

## Active ou coupe la zone v2 (shader + éléments 3D).
static func regler(monde: Node, oui: bool) -> void:
	actif = oui
	if monde.mat_terrain != null:
		monde.mat_terrain.set_shader_parameter("sol2_rect", MONDE if oui else Vector4(0, 0, 0, 0))
	if _decor != null:
		_decor.visible = oui
		for f in _corps:
			f.disabled = not oui

static func dans_rect(x: float, z: float, marge := 0.0) -> bool:
	return x > RECT.x + marge and x < RECT.z - marge and z > RECT.y + marge and z < RECT.w - marge

# --- éléments 3D ------------------------------------------------------------------------------

## Appelé par monde.gd après SousBois.creer (les touffes évitent arbres et rochers).
static func creer(monde: Node) -> void:
	if not ZoneBiome.actif:
		return
	_decor = Node3D.new()
	_decor.name = "SolV2Decor"
	monde.add_child(_decor)
	_corps.clear()
	var rochers := _poser_rochers(monde)
	if monde.has_method("_souffle"): await monde._souffle()   # chargement étalé : une image entre deux poses (sans effet sinon)
	_poser_touffes(monde, rochers)
	if monde.has_method("_souffle"): await monde._souffle()
	await _poser_ailleurs(monde, rochers)
	_decor.visible = actif

## Rochers de `roches_sol_v2.dat` : nom → ArrayMesh (facettes à plat, couleurs de sommets : AO + masque de neige).
static func _charger_rochers() -> Dictionary:
	var res := {}
	var f := FileAccess.open(DAT_ROCHES, FileAccess.READ)
	if f == null:
		push_error("SolV2 : %s introuvable" % DAT_ROCHES)
		return res
	var m := TexturesBati.m_roche()
	var n := f.get_32()
	for _i in n:
		var ln := f.get_8()
		var nom := f.get_buffer(ln).get_string_from_utf8()
		var nv := f.get_32()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var v: Array = []
		for _k in nv:
			var d := f.get_buffer(28).to_float32_array()
			v.append([Vector3(d[0], d[1], d[2]), Color(d[3], d[4], d[5], d[6])])
		for t in range(0, nv, 3):
			for k in [0, 2, 1]:   # Godot : face avant = sens horaire
				st.set_color(v[t + k][1])
				st.add_vertex(v[t + k][0])
		st.generate_normals()
		var mesh := st.commit()
		mesh.surface_set_material(0, m)
		res[nom] = mesh
	return res

static func _poser_rochers(monde: Node) -> Array:
	var modeles := _charger_rochers()
	if modeles.is_empty():
		return []
	var ligne: Array = Chemins.LIGNE_CERCLE
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("sol_v2_rochers")
	# [x, z, modèle, échelle, lacet] : deux grands rochers de part et d'autre du chemin, puis une garniture de pierres
	var cand: Array = [
		[-11.9, -14.9, "roche_A", 1.15], [-15.3, -10.9, "roche_C", 1.25],
	]
	# pierres de tailles variées au bord du chemin (1,0 à 3,6 m de l'axe, de part et d'autre)
	for i in range(0, ligne.size() - 1):
		var a: Vector2 = ligne[i]
		var b: Vector2 = ligne[i + 1]
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var long := a.distance_to(b)
		var s := rng.randf_range(0.2, 0.9)
		while s < long:
			var cote := 1.0 if rng.randf() < 0.5 else -1.0
			var ecart := rng.randf_range(0.9, 3.6)
			var p := a + dir * s + perp * cote * ecart
			var u := rng.randf()
			var nom: String = "roche_D" if u < 0.45 else ("roche_F" if u < 0.8 else "roche_B")
			if ecart > 2.6 and rng.randf() < 0.3:
				nom = "roche_E"
			cand.append([p.x, p.y, nom, rng.randf_range(0.7, 1.3)])
			s += rng.randf_range(1.2, 3.0)
	var posees: Array = []
	var parts := {}
	for c in cand:
		var x: float = c[0]
		var z: float = c[1]
		if not dans_rect(x, z, 1.0) or Vegetation.exclu_decor(x, z):
			continue
		var d: float = monde.chemins.distance(x, z)
		if d < 0.85:
			continue
		var trop_pres := false
		for q in posees:
			if Vector2(x, z).distance_to(q["pos"]) < 0.5 * (q["r"] + 0.6 * c[3]) + 0.35:
				trop_pres = true
				break
		if not trop_pres:   # passe D : pas de rocher sur une souche ou une branche du sous-bois (elle le traversait)
			for t: Transform3D in monde.get_meta("sous_bois_gros", []):
				if Vector2(x, z).distance_to(Vector2(t.origin.x, t.origin.z)) < 0.55 * float(c[3]) + 0.5:
					trop_pres = true
					break
		if trop_pres:
			continue
		var s: float = c[3]
		var yaw := ZoneBiome.alea_pos(x, z, 11) * TAU
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * (0.85 + 0.3 * ZoneBiome.alea_pos(x, z, 12)), s))
		var xf := Transform3D(b, Vector3(x, monde.hauteur(x, z), z))
		var nom: String = c[2]
		if not parts.has(nom):
			parts[nom] = []
		parts[nom].append(xf)
		posees.append({"pos": Vector2(x, z), "r": s * (1.0 if nom in ["roche_A", "roche_C"] else 0.5)})
		# collision : seulement les gros rochers (convexe, points déjà transformés, aucune échelle sur la forme)
		if nom in ["roche_A", "roche_C", "roche_E"]:
			var corps := StaticBody3D.new()
			var pts := PackedVector3Array()
			for p in (modeles[nom] as ArrayMesh).create_convex_shape().points:
				pts.append(b * p)
			var convexe := ConvexPolygonShape3D.new()
			convexe.points = pts
			var forme := CollisionShape3D.new()
			forme.shape = convexe
			forme.position = xf.origin
			corps.add_child(forme)
			_decor.add_child(corps)
			_corps.append(forme)
	for nom: String in parts:
		for mmi in Instanciation.repartir(_decor, modeles[nom], parts[nom], {"portee": PORTEE, "marge": 4.0, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("SolV2 : %d rochers et pierres posés" % posees.size())
	return posees

# --- touffes d'herbe sèche ----------------------------------------------------------------------

## Texture de touffe 48² : brins foin → paille, courbés, qui sortent d'un petit monticule de neige.
static func texture_touffe(graine: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := 48
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var herbe: Array[Color] = [Color("#3b2f17"), Color("#5c4e2d"), Color("#82723f"), Color("#a08a4c"), Color("#b39d5d"), Color("#8a5a2a")]
	var neige: Array[Color] = [Color("#8898bf"), Color("#aab8d6"), Color("#cdd7ec"), Color("#f0eff4")]
	for n in 34:
		var bx := 24.0 + rng.randfn(0.0, 4.5)
		var h := rng.randi_range(14, 44)
		var sens := 1.0 if bx + rng.randf_range(-6.0, 6.0) > 24.0 else -1.0
		var courbe := rng.randf_range(0.0, 15.0) * (float(h) / 44.0) * sens
		var teinte := rng.randi_range(1, 3) + (2 if rng.randf() < 0.08 else 0)
		for k in h:
			var u := float(k) / h
			var y := t - 1 - k
			var px := int(round(bx + courbe * u * u))
			if px < 0 or px >= t or y < 0:
				break
			var ton := clampi(teinte - (1 if u < 0.2 else 0) + (1 if u > 0.65 else 0), 0, 4)
			var c := herbe[ton]
			if rng.randf() < 0.04:
				c = herbe[5]
			img.set_pixel(px, y, c)
			if h > 28 and u < 0.7 and px + 1 < t:
				img.set_pixel(px + 1, y, herbe[clampi(ton - 1, 0, 4)])
	# monticule de neige au pied (bord irrégulier) + quelques flocons accrochés aux brins
	for x in range(8, 40):
		var dx := (x - 24.0) / 16.0
		var hh := int(round(5.5 * sqrt(maxf(0.0, 1.0 - dx * dx)) + rng.randf_range(-1.0, 1.0)))
		for k in hh:
			var y := t - 1 - k
			var c := neige[clampi(1 + (1 if k >= hh - 2 else 0) + (1 if rng.randf() < 0.2 else 0), 0, 3)]
			if k < 2 and rng.randf() < 0.5:
				c = neige[0]
			img.set_pixel(x, y, c)
	for n in 14:
		var x := rng.randi_range(14, 34)
		var y := rng.randi_range(t - 24, t - 8)
		if img.get_pixel(x, y).a > 0.5:
			img.set_pixel(x, y, neige[rng.randi_range(1, 3)])
	return ImageTexture.create_from_image(img)

## Touffe : 4 quads croisés dont le haut se courbe (deux rangées), pied sombre, découpés par l'alpha.
static func mesh_touffe(materiau: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pied := Color(0.6, 0.6, 0.6)
	var tete := Color.WHITE
	for k in 4:
		var a := PI * k / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		var pen := d.cross(Vector3.UP) * 0.10   # le haut se penche
		var b0 := d * -0.52 + Vector3(0, -0.03, 0)
		var b1 := d * 0.52 + Vector3(0, -0.03, 0)
		var m0 := d * -0.46 + Vector3(0, 0.42, 0) + pen * 0.4
		var m1 := d * 0.46 + Vector3(0, 0.42, 0) + pen * 0.4
		var h0 := d * -0.36 + Vector3(0, 0.78, 0) + pen
		var h1 := d * 0.36 + Vector3(0, 0.78, 0) + pen
		var cm := Color(0.85, 0.85, 0.85)
		Arbres._tri(st, b0, b1, m1, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0.46), pied, pied, cm)
		Arbres._tri(st, b0, m1, m0, Vector2(0, 1), Vector2(1, 0.46), Vector2(0, 0.46), pied, cm, cm)
		Arbres._tri(st, m0, m1, h1, Vector2(0, 0.46), Vector2(1, 0.46), Vector2(1, 0), cm, cm, tete)
		Arbres._tri(st, m0, h1, h0, Vector2(0, 0.46), Vector2(1, 0), Vector2(0, 0), cm, tete, tete)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, materiau)
	return mesh

static func _poser_touffes(monde: Node, rochers: Array) -> void:
	var mat := SousBois.materiau_herbe(texture_touffe(77), Color(1.05, 1.0, 0.95))
	var mesh := mesh_touffe(mat)
	var arbres: Array = monde.get_meta("arbres_zone") if monde.has_meta("arbres_zone") else []
	var xfs: Array = []
	var pas := 1.05
	var x0 := RECT.x + 0.6
	while x0 < RECT.z - 0.6:
		var z0 := RECT.y + 0.6
		while z0 < RECT.w - 0.6:
			var jx := x0 + (ZoneBiome.alea_pos(x0, z0, 21) - 0.5) * pas * 0.9
			var jz := z0 + (ZoneBiome.alea_pos(x0, z0, 22) - 0.5) * pas * 0.9
			z0 += pas
			if not dans_rect(jx, jz, 0.5) or Vegetation.exclu_decor(jx, jz):
				continue
			var d: float = monde.chemins.distance(jx, jz)
			if d < 0.95:
				continue
			# plus de touffes au bord du chemin (1-3 m), quelques-unes plus loin, par amas
			var amas := ZoneBiome.alea_pos(floorf(jx / 3.0), floorf(jz / 3.0), 23)
			var p := 0.10 + 0.50 * smoothstep(0.95, 1.7, d) * (1.0 - smoothstep(2.8, 5.0, d)) * (0.4 + amas)
			if ZoneBiome.alea_pos(jx, jz, 24) > p:
				continue
			if SousBois._pres_d_un_arbre(arbres, jx, jz, 0.5):
				continue
			var bloque := false
			for r in rochers:
				if Vector2(jx, jz).distance_to(r["pos"]) < r["r"] * 0.9 + 0.3:
					bloque = true
					break
			if bloque:
				continue
			var s := 0.42 + 0.42 * ZoneBiome.alea_pos(jx, jz, 25)
			var yaw := ZoneBiome.alea_pos(jx, jz, 26) * TAU
			xfs.append(SousBois._tf(jx, SousBois._bas(monde, jx, jz, 0.4) - 0.02, jz, yaw, s, 0.75 + 0.45 * ZoneBiome.alea_pos(jx, jz, 27)))
		x0 += pas
	xfs = PosesDecor.filtrer(monde, xfs, "touffe", mesh)   # passe D : règles de pose
	for mmi in Instanciation.repartir(_decor, mesh, xfs, {"portee": 32.0, "ombre": false}):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("SolV2 : %d touffes" % xfs.size())

# --- C1 : le reste de la carte -------------------------------------------------------------------

## Zone où `_poser_ailleurs` pose rochers et touffes (hors rectangle témoin). C1a : ouest (x < 0) et nord (z < 0) ;
## C1b : toute la carte (est et sud compris) ; `_libre_ailleurs` exclut toujours le village (refait par C7) et le seuil de la grotte.
static func dans_region(_x: float, _z: float) -> bool:
	return true

## Hors des zones à ne pas encombrer : village (refait par C7), seuil de la grotte, abords des chemins, bord de la carte.
static func _libre_ailleurs(monde: Node, x: float, z: float, marge_chemin: float) -> bool:
	if not dans_region(x, z) or dans_rect(x, z, -0.6):
		return false
	if Vector2(x, z).length() > 100.0:
		return false   # pente du pourtour : pas de rochers posés dans les collines
	if Vector2(x - monde.VILLAGE.x, z - monde.VILLAGE.z).length() < 46.0:
		return false
	if ReliefVillage.exclu(x, z):   # C7a : enceinte du village v2 (haute rue, T3) et lit de la rivière
		return false
	if EauVillage.sous_le_lac(x, z, monde.hauteur(x, z)):   # C7c : lac fermé de la combe SO
		return false
	if Vector2(x - 92.0, z + 27.0).length() < 14.0:   # seuil de la grotte (GrotteAcces.SITE)
		return false
	if Vegetation.exclu_decor(x, z) or monde._pres_du_chemin(x, z, marge_chemin):
		return false
	return monde.chemins.distance(x, z) >= marge_chemin

## Index spatial (cellules de 4 m) des arbres et des rochers existants : [Vector2 centre, rayon].
static func _obstacles_existants(monde: Node) -> Dictionary:
	var g := {}
	for a: Transform3D in monde.arbres:
		_ajouter_obstacle(g, Vector2(a.origin.x, a.origin.z), 0.45 + 0.35 * a.basis.get_scale().x)
	var arbres_zone: Array = monde.get_meta("arbres_zone") if monde.has_meta("arbres_zone") else []
	for a in arbres_zone:
		_ajouter_obstacle(g, Vector2(a["pos"].x, a["pos"].z), 0.45 + 0.35 * a["s"])
	for nd in monde.get_children():
		if nd is StaticBody3D:
			for f in nd.get_children():
				if f is CollisionShape3D and f.shape is ConvexPolygonShape3D:
					var r := 0.0
					for p in (f.shape as ConvexPolygonShape3D).points:
						r = maxf(r, Vector2(p.x, p.z).length())
					_ajouter_obstacle(g, Vector2(f.position.x, f.position.z), r)
	return g

static func _ajouter_obstacle(g: Dictionary, c: Vector2, r: float) -> void:
	var k := Vector2i(floori(c.x / 4.0), floori(c.y / 4.0))
	if not g.has(k):
		g[k] = []
	g[k].append([c, r])

static func _bloque(g: Dictionary, x: float, z: float, r: float) -> bool:
	var kx := floori(x / 4.0)
	var kz := floori(z / 4.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l = g.get(Vector2i(kx + dx, kz + dz))
			if l == null:
				continue
			for o in l:
				if Vector2(x, z).distance_to(o[0]) < o[1] + r:
					return true
	return false

static func _pente(monde: Node, x: float, z: float) -> float:
	var h: float = monde.hauteur(x, z)
	return maxf(maxf(absf(monde.hauteur(x + 1.0, z) - h), absf(monde.hauteur(x - 1.0, z) - h)), maxf(absf(monde.hauteur(x, z + 1.0) - h), absf(monde.hauteur(x, z - 1.0) - h)))

## Rochers v2 et touffes d'herbe sèche sur le reste de la région (amas par bruit, plus denses au bord des chemins).
static func _poser_ailleurs(monde: Node, rochers_temoin: Array) -> void:
	var obst := _obstacles_existants(monde)
	var modeles := _charger_rochers()
	var noms := ["roche_D", "roche_F", "roche_B"]
	var xr: Array = []
	var parts := {}
	var pas_r := 5.5
	var nb_gros := 0
	var gx := -118.0
	while gx < 118.0:
		var gz := -118.0
		while gz < 118.0:
			var x := gx + ZoneBiome.alea_pos(gx, gz, 31) * pas_r
			var z := gz + ZoneBiome.alea_pos(gx, gz, 32) * pas_r
			gz += pas_r
			if not _libre_ailleurs(monde, x, z, 1.6):
				continue
			var amas := ZoneBiome.alea_pos(floorf(x / 18.0), floorf(z / 18.0), 33)   # amas de 18 m : certains secteurs sans rien
			if ZoneBiome.alea_pos(x, z, 34) > 0.18 + 0.55 * amas * amas:
				continue
			if _pente(monde, x, z) > 0.9:
				continue
			var u := ZoneBiome.alea_pos(x, z, 35)
			var nom: String = noms[0] if u < 0.4 else (noms[1] if u < 0.75 else noms[2])
			var s := 0.7 + 0.6 * ZoneBiome.alea_pos(x, z, 36)
			var gros := ZoneBiome.alea_pos(x, z, 37) < 0.16 and amas > 0.4
			if gros:
				nom = ["roche_A", "roche_C", "roche_E"][int(ZoneBiome.alea_pos(x, z, 38) * 2.999)]
				s = 0.95 + 0.4 * ZoneBiome.alea_pos(x, z, 39)
			var rr := s * (1.0 if gros else 0.55)
			if _bloque(obst, x, z, rr * 0.8):
				continue
			var yaw := ZoneBiome.alea_pos(x, z, 11) * TAU
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * (0.85 + 0.3 * ZoneBiome.alea_pos(x, z, 12)), s))
			var xf := Transform3D(b, Vector3(x, monde.hauteur(x, z) - 0.05, z))
			if not parts.has(nom):
				parts[nom] = []
			parts[nom].append(xf)
			xr.append({"pos": Vector2(x, z), "r": rr})
			_ajouter_obstacle(obst, Vector2(x, z), rr * 0.8)
			if gros:
				nb_gros += 1
				var corps := StaticBody3D.new()
				var pts := PackedVector3Array()
				for p in (modeles[nom] as ArrayMesh).create_convex_shape().points:
					pts.append(b * p)
				var convexe := ConvexPolygonShape3D.new()
				convexe.points = pts
				var forme := CollisionShape3D.new()
				forme.shape = convexe
				forme.position = xf.origin
				corps.add_child(forme)
				_decor.add_child(corps)
				_corps.append(forme)
		gx += pas_r
		if monde.has_method("_souffle"): await monde._souffle()   # chargement étalé (positions tirées par hachage : ordre sans effet)
	for nom: String in parts:
		for mmi in Instanciation.repartir(_decor, modeles[nom], parts[nom], {"portee": PORTEE, "marge": 4.0, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("SolV2 : %d rochers et pierres ailleurs (dont %d avec collision)" % [xr.size(), nb_gros])
	if monde.has_method("_souffle"): await monde._souffle()
	# touffes
	var mat := SousBois.materiau_herbe(texture_touffe(78), Color(1.05, 1.0, 0.95))
	var mesh := mesh_touffe(mat)
	var xfs: Array = []
	var pas := 1.7
	var x0 := -118.0
	while x0 < 118.0:
		var z0 := -118.0
		while z0 < 118.0:
			var jx := x0 + (ZoneBiome.alea_pos(x0, z0, 41) - 0.5) * pas * 0.9
			var jz := z0 + (ZoneBiome.alea_pos(x0, z0, 42) - 0.5) * pas * 0.9
			z0 += pas
			if not _libre_ailleurs(monde, jx, jz, 0.95):
				continue
			var d: float = monde.chemins.distance(jx, jz)
			var amas := ZoneBiome.alea_pos(floorf(jx / 3.0), floorf(jz / 3.0), 43)
			var gr := ZoneBiome.alea_pos(floorf(jx / 20.0), floorf(jz / 20.0), 44)   # grandes clairières d'herbe
			var p := (0.03 + 0.20 * gr * gr) * (0.4 + amas)
			if d < INF:
				p += 0.35 * smoothstep(0.95, 1.7, d) * (1.0 - smoothstep(2.8, 5.0, d)) * (0.4 + amas)
			if ZoneBiome.alea_pos(jx, jz, 45) > p or _pente(monde, jx, jz) > 1.1:
				continue
			if _bloque(obst, jx, jz, 0.35):
				continue
			var s := 0.42 + 0.42 * ZoneBiome.alea_pos(jx, jz, 46)
			var yaw := ZoneBiome.alea_pos(jx, jz, 47) * TAU
			xfs.append(SousBois._tf(jx, SousBois._bas(monde, jx, jz, 0.4) - 0.02, jz, yaw, s, 0.75 + 0.45 * ZoneBiome.alea_pos(jx, jz, 48)))
		x0 += pas
		if monde.has_method("_souffle"): await monde._souffle()
	if monde.has_method("_souffle"): await monde._souffle()
	xfs = PosesDecor.filtrer(monde, xfs, "touffe", mesh)   # passe D : règles de pose
	for mmi in Instanciation.repartir(_decor, mesh, xfs, {"portee": 32.0, "ombre": false}):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("SolV2 : %d touffes ailleurs" % xfs.size())
