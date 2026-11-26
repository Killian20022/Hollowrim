class_name AllurePnj
## [pnj/realisme_v1, passe 2, 2026-11-26] Allure des PNJ maison du village : relecture « un peu moins Playmobil, pas franchement ».
## Complète RealismePnj (peintures) par de la GÉOMÉTRIE et des tenues, sans toucher au squelette ni aux animations :
##   - chevelure en cartes de mèches découpées (alpha coupé, style PS1) sur une calotte de mèches, coiffures par individu
##     (court, rasé, chauve à couronne, long libre, attaché en queue, nattes, chignon) : remplace le casque lisse à raie nette et les
##     rubans plats des tempes ; barbe repeinte en brins ;
##   - col / collet de laine ou de cuir (épaisseur, plis, ourlet) au lieu de l'anneau plat de la mante ;
##   - tenues recombinées à partir des pièces existantes (tunique de laine au lieu des mailles, robe, tablier, cape courte, sacoche,
##     ceinture, fourrure dense) et teintes de laine variées ; corpulences (épaules, ventre, taille) par déformation des sommets au
##     repos (poids et os inchangés) ;
##   - fourrures en touffes irrégulières (cartes de mèches et mante repeintes) ;
##   - peau sans liseré noir (contour) ; capuche mate (laine) ; doigts lisibles (peints dans l'atlas, RealismePnj).
## Ne concerne que les PNJ de la table ALLURES (habitants, forgeron, chasseuse, cheffe, völva, ancienne) ; jamais eirik / garde (crypte),
## ni les armures validées, ni les corps Tripo.

## coiffure, cheveux (couleur naturelle), barbe (true/false), tenue, laine (teinte des étoffes), carrure {epaules, ventre, taille}
const ALLURES := {
	"forgeron":          {"coiffure": "attache", "cheveux": "brun", "barbe": true, "tenue": "forge", "laine": "lin", "carrure": {"epaules": 0.07, "ventre": 0.04}},
	"hab_paysan_a":      {"coiffure": "court", "cheveux": "chatain", "barbe": true, "tenue": "laine", "laine": "brun", "carrure": {"ventre": 0.09, "taille": 0.05}},
	"hab_paysan_b":      {"coiffure": "rase", "cheveux": "blond", "barbe": false, "tenue": "cape", "laine": "vert", "carrure": {"epaules": 0.03}},
	"hab_paysan_c":      {"coiffure": "chauve", "cheveux": "poivre_sel", "barbe": true, "tenue": "fourrure", "laine": "gris", "fourrure": "brun", "carrure": {"epaules": -0.04, "ventre": 0.05}},
	"hab_receleur":      {"coiffure": "long", "cheveux": "gris", "barbe": true, "tenue": "cape", "laine": "noir", "carrure": {"epaules": -0.05, "taille": -0.03}},
	"hab_chasseur_a":    {"coiffure": "court", "cheveux": "roux", "barbe": true, "tenue": "fourrure", "laine": "brun", "fourrure": "gris", "carrure": {"epaules": 0.05}},
	"hab_chasseur_b":    {"coiffure": "attache", "cheveux": "brun_fonce", "barbe": true, "tenue": "laine", "laine": "vert", "carrure": {"taille": -0.03}},
	"chef":              {"coiffure": "chignon", "cheveux": "gris", "tenue": "fourrure", "laine": "rouge", "fourrure": "gris", "carrure": {"epaules": 0.02}},
	"chasseuse":         {"fourrure": "fauve", "coiffure": "nattes", "cheveux": "auburn", "tenue": "chasse", "laine": "brun", "carrure": {}},
	"hab_paysanne_a":    {"fourrure": "creme", "coiffure": "nattes", "cheveux": "chatain_clair", "tenue": "robe", "laine": "bleu", "carrure": {"ventre": 0.03, "taille": 0.03}},
	"hab_paysanne_b":    {"coiffure": "chignon", "cheveux": "blanc", "tenue": "robe", "laine": "gris", "carrure": {"ventre": 0.05, "epaules": -0.03}},
	"hab_paysanne_c":    {"fourrure": "brun", "coiffure": "attache", "cheveux": "brun_fonce", "tenue": "tablier", "laine": "rouge", "carrure": {"taille": -0.03}},
	"hab_chasseresse_a": {"coiffure": "attache", "cheveux": "chatain", "tenue": "chasse", "laine": "vert", "carrure": {}},
	"hab_chasseresse_b": {"coiffure": "nattes", "cheveux": "roux", "tenue": "fourrure", "laine": "brun", "fourrure": "brun", "carrure": {"epaules": 0.02}},
	"volva":             {"tenue": "mage"},
	"ancienne":          {"tenue": "mage"},
}

## Couleurs de cheveux naturelles (albédo moyen, sans saturation du shader) : roux cuivré et auburn, pas de rose ni d'orange vif.
const POILS := {
	"blond": Color(0.60, 0.52, 0.38), "chatain_clair": Color(0.47, 0.37, 0.27), "chatain": Color(0.35, 0.26, 0.19),
	"brun": Color(0.25, 0.19, 0.14), "brun_fonce": Color(0.17, 0.13, 0.10), "roux": Color(0.44, 0.27, 0.17),
	"auburn": Color(0.33, 0.21, 0.15), "gris": Color(0.52, 0.51, 0.49), "poivre_sel": Color(0.38, 0.37, 0.35),
	"blanc": Color(0.74, 0.73, 0.70),
}

## Laines (couleur de base du tissage) et cuirs, sourds.
const LAINES := {
	"brun": Color(0.40, 0.30, 0.21), "lin": Color(0.58, 0.52, 0.42), "gris": Color(0.42, 0.42, 0.41), "vert": Color(0.30, 0.34, 0.24),
	"bleu": Color(0.26, 0.31, 0.40), "rouge": Color(0.44, 0.21, 0.17), "noir": Color(0.19, 0.18, 0.17), "ocre": Color(0.52, 0.41, 0.24),
}
const CUIR := Color(0.37, 0.29, 0.22)
const FOURRURES := {"brun": Color(0.40, 0.31, 0.23), "gris": Color(0.50, 0.48, 0.45), "creme": Color(0.66, 0.61, 0.53), "fauve": Color(0.48, 0.37, 0.26)}

static func concerne(id: String) -> bool:
	return ALLURES.has(id) and RealismePnj.concerne(id)

## Avant les peintures de RealismePnj : tenue (pièces montrées / cachées, matériaux), rubans et mèches détachées retirés, corpulence.
static func avant(n: Node3D, id: String) -> void:
	if not concerne(id):
		return
	var a: Dictionary = ALLURES[id]
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return
	var p := _pieces(sq)
	var tenue := String(a.get("tenue", ""))
	var g := absi(hash(id + "_allure"))
	if a.has("coiffure"):
		for nom in ["Hair_Long", "Hair_Buns", "Hair_SimpleParted", "Hair_Buzzed", "Eyebrows"]:
			if p.has(nom):
				(p[nom] as MeshInstance3D).visible = false
		if p.has("Hair_Beard") and not bool(a.get("barbe", false)):
			(p["Hair_Beard"] as MeshInstance3D).visible = false
	if tenue != "mage":
		_tenue(sq, p, a, tenue, g)
		var acc: MeshInstance3D = p.get("accessoires")
		if acc != null and a.has("coiffure"):
			var tr := GuerrierTextures.R_TRESSE
			var r0 := Vector2(tr.position) / 256.0
			var r1 := Vector2(tr.end) / 256.0
			var garder_tresses := tenue == "forge"
			# rubans de tempes et nattes de l'atlas (tubes R_TRESSE) : retirés (nouvelles nattes en cartes) ; le forgeron garde ses tresses de barbe
			if not garder_tresses:
				_retirer(acc, 0, func(_c: Vector3, uv: Vector2) -> bool: return uv.x > r0.x and uv.x < r1.x and uv.y > r0.y and uv.y < r1.y)
			# mèches détachées des tempes (cartes D_CHEV) : remplacées par la chevelure en cartes
			var dc := GuerrierTextures.D_CHEV
			var dd := Vector2(GuerrierTextures.DECOUPES)
			var c0 := Vector2(dc.position) / dd
			var c1 := Vector2(dc.end) / dd
			_retirer(acc, 1, func(_c: Vector3, uv: Vector2) -> bool: return uv.x > c0.x - 0.002 and uv.y > c0.y - 0.002 and uv.y < c1.y + 0.002)
		if acc != null and p.has("SuperHero_Male"):
			# hommes : écharpe en anneau plat (R_ECHARPE, l'« anneau » vert ou gris du cou) et plastron de mailles du Guerrier retirés
			# (le collet ou la fourrure les remplacent ; les paysans ne portent pas de mailles)
			var e0 := Vector2(GuerrierTextures.R_ECHARPE.position) / 256.0
			var e1 := Vector2(GuerrierTextures.R_ECHARPE.end) / 256.0
			_retirer(acc, 0, func(_c: Vector3, uv: Vector2) -> bool: return uv.x > e0.x and uv.x < e1.x and uv.y > e0.y and uv.y < e1.y)
			# plastron gardé (il bouche l'encolure de la tunique) mais repeint en laine de la tunique (RealismePnj)
			if p.has("plastron"):
				acc.set_meta("plastron_laine", LAINES["lin"] if tenue == "forge" else (LAINES[String(a.get("laine", "brun"))] as Color))

		if acc != null:
			# cartes de fourrure en pointes (D_MECHES et « feuilles » de la Chasseresse, 2 bandes de l'atlas des découpes) : retirées
			# sauf avec la tenue de fourrure, où elles sont repeintes en touffes de la couleur de la fourrure
			var m0 := Vector2(GuerrierTextures.D_MECHES.position) / Vector2(GuerrierTextures.DECOUPES)
			if tenue != "fourrure":
				_retirer(acc, 1, func(_c: Vector3, uv: Vector2) -> bool: return uv.x > m0.x - 0.002 and uv.y < 0.502)
			else:
				acc.set_meta("fourrure_pnj", FOURRURES[String(a.get("fourrure", "brun"))])
			# col de fourrure en pointes de l'atlas des accessoires des habitants (texels 160-192 x 128-144, crème rayé) : retiré
			# pour tous (le collet de laine ou de cuir, la mante en touffes ou la capuche le remplacent)
			var tb := (acc.get_active_material(0) as ShaderMaterial).get_shader_parameter("tex_base") as Texture2D if acc.get_active_material(0) is ShaderMaterial else null
			if tb != null and tb.get_width() == 256:
				_retirer(acc, 0, func(_c: Vector3, uv: Vector2) -> bool: return uv.x > 0.625 and uv.x < 0.75 and uv.y > 0.5 and uv.y < 0.5625)
		_carrure(sq, a.get("carrure", {}))

## Après les peintures : chevelure en cartes, barbe, col, réglages de peau et de capuche.
static func apres(n: Node3D, id: String) -> void:
	if not concerne(id):
		return
	var a: Dictionary = ALLURES[id]
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return
	var p := _pieces(sq)
	var g := absi(hash(id + "_allure"))
	var femme := sq.get_bone_global_rest(sq.find_bone("Head")).origin.y < 1.58
	# peau : pas de liseré noir (il découpait le visage en arêtes dures) ; ombre moins froide, torche et soleil bas moins orangés
	reglages_peau(p.get("peau"))
	if a.has("coiffure"):
		for nom in ["Hair_Long", "Hair_Buns", "Hair_SimpleParted", "Hair_Buzzed", "Eyebrows"]:
			if p.has(nom):
				(p[nom] as MeshInstance3D).visible = false
		var poil: Color = POILS[String(a["cheveux"])]
		ChevelurePnj.batir(sq, String(a["coiffure"]), poil, femme, g)
		var barbe: MeshInstance3D = p.get("Hair_Beard")
		if barbe != null:
			barbe.visible = bool(a.get("barbe", false)) and not femme
			if barbe.visible:
				ChevelurePnj.barbe(barbe, poil, g)
	var tenue := String(a.get("tenue", ""))
	if tenue in ["laine", "cape", "forge"] and not femme:
		var cuir := tenue in ["cape", "chasse", "forge"]
		var col: Color = CUIR if cuir else (LAINES[String(a.get("laine", "brun"))] as Color).lightened(0.06)
		ColPnj.batir(sq, col, cuir, femme, g)
	# capuche et étoffes de la tête : mates (pas de liseré froid ni de rehaut d'arête qui les faisaient briller comme du plastique)
	for nom in ["capuche"]:
		if p.has(nom):
			_matifier(p[nom] as MeshInstance3D)
	if tenue == "mage" and p.has("accessoires"):
		_matifier(p["accessoires"] as MeshInstance3D)

## Réglages du matériau de peau (copie) : sans contour, ombre tiède, lumières chaudes ramenées vers le neutre.
static func reglages_peau(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as ShaderMaterial
		if m == null:
			continue
		var m2 := m.duplicate() as ShaderMaterial
		m2.next_pass = null
		m2.set_shader_parameter("ombre_froide", Vector3(0.42, 0.42, 0.50))
		m2.set_shader_parameter("ombre_force", 0.55)
		m2.set_shader_parameter("soleil_desat", 0.62)
		m2.set_shader_parameter("lampe_desat", 0.60)
		m2.set_shader_parameter("contour_froid", Vector3(0.10, 0.12, 0.16))
		Palette.suivre(m2)
		if mi.material_override == m:
			mi.material_override = m2
		else:
			mi.set_surface_override_material(s, m2)

static func _matifier(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as ShaderMaterial
		if m == null:
			continue
		var m2 := m.duplicate() as ShaderMaterial
		m2.set_shader_parameter("contour_froid", Vector3(0.04, 0.05, 0.06))
		m2.set_shader_parameter("rehaut", 0.25)
		var sat = m.get_shader_parameter("saturation")
		m2.set_shader_parameter("saturation", (float(sat) if sat != null else 1.0) * 0.85)
		if m.next_pass != null:
			m2.next_pass = m.next_pass
		Palette.suivre(m2)
		if mi.material_override == m:
			mi.material_override = m2
		else:
			mi.set_surface_override_material(s, m2)

static func _pieces(sq: Skeleton3D) -> Dictionary:
	var d := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		d[String(mi.name)] = mi
	return d

# ======================================================================================================== tenues
## Matériau d'étoffe (copie) : texture de laine / cuir du lot 4 (PersonnagesTextures), teinte, sans contour pour les pièces ajoutées.
static func _etoffe(nom_tex: String, teinte: Color) -> ShaderMaterial:
	var tex := PersonnagesTextures.tex(nom_tex)
	var m := (GuerrierNordique.materiau(tex, true, false, true) as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("teinte", teinte)
	Palette.suivre(m)
	return m

## Laine teintée : le tissage « neutre » (gris) multiplié par la couleur voulue (valeurs gardées).
static func _laine(c: Color) -> ShaderMaterial:
	return _etoffe("tunique_neutre", Color(c.r / 0.60, c.g / 0.60, c.b / 0.60))

static func _montrer(p: Dictionary, nom: String, m: ShaderMaterial) -> void:
	var mi: MeshInstance3D = p.get(nom)
	if mi == null:
		return
	mi.visible = true
	# pièces ajoutées par-dessus la tenue de l'archétype (plus épaisse que le corps Quaternius) : gonflées le long des normales
	var gonfle := {"tablier": 0.035, "cape_courte": 0.03, "sacoche": 0.02, "ceinture": 0.018}
	if gonfle.has(nom):
		m.set_shader_parameter("gonfle", gonfle[nom])
	if nom == "tablier":
		_normales_dehors(mi)
	mi.material_override = m

## Le tablier de l'archétype a ses normales tournées vers le corps (éclairé de l'intérieur : noir ; le gonflement le rentrait
## dans le buste) : normales retournées si leur moyenne en z s'oppose à la position moyenne en z de la pièce.
static func _normales_dehors(mi: MeshInstance3D) -> void:
	if mi.mesh == null or mi.has_meta("normales_dehors"):
		return
	var arr0 := mi.mesh.surface_get_arrays(0)
	var vv: PackedVector3Array = arr0[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr0[Mesh.ARRAY_NORMAL]
	var sz := 0.0
	var sn := 0.0
	for i in vv.size():
		sz += vv[i].z
		sn += nn[i].z
	mi.set_meta("normales_dehors", true)
	if sz * sn >= 0.0:
		return
	var mesh := ArrayMesh.new()
	var mats: Array = []
	for k in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(k)
		var nb := 4
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] != null and v.size() > 0:
			nb = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / v.size()
		for kc in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[kc] = null
		var n2: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in n2.size():
			n2[i] = -n2[i]
		arr[Mesh.ARRAY_NORMAL] = n2
		arr[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
		mats.append(mi.get_surface_override_material(k))
	mi.mesh = mesh
	for j in mats.size():
		mi.set_surface_override_material(j, mats[j])

static func _cacher(p: Dictionary, nom: String) -> void:
	if p.has(nom):
		(p[nom] as MeshInstance3D).visible = false

static func _tenue(sq: Skeleton3D, p: Dictionary, a: Dictionary, tenue: String, g: int) -> void:
	var laine: Color = LAINES[String(a.get("laine", "brun"))]
	var pant := ["brun", "gris", "noir", "lin"][g % 4] as String
	var homme := p.has("SuperHero_Male")
	match tenue:
		"laine", "cape", "forge", "fourrure":
			if homme:
				# tunique de laine au lieu de la cotte de mailles du guerrier (paysans, chasseurs) ; pantalon de laine
				_montrer(p, "tunique", _laine(laine))
				_montrer(p, "pantalon", _etoffe("pantalon_" + pant, Color.WHITE))
			_montrer(p, "ceinture", _etoffe("ceinture_cuir_" + ["a", "b", "c"][g % 3], Color.WHITE))
			if tenue != "fourrure":
				_cacher(p, "mante")
			if tenue == "cape":
				_montrer(p, "cape_courte", _laine(laine.darkened(0.15)))
				_cacher(p, "cape")
			if tenue in ["laine", "cape"]:
				_montrer(p, "sacoche", _etoffe("bottes_cuir_b", Color.WHITE))
			if tenue == "forge":
				_montrer(p, "tunique", _laine(LAINES["lin"]))
				_montrer(p, "tablier", _etoffe("tunique_cuir_b", Color.WHITE))
		"robe":
			# femmes : tunique et mante de l'archétype gardées (sous la mante, l'encolure est vide) ; robe longue et tablier de lin
			_montrer(p, "robe", _laine(laine.darkened(0.08)))
			_montrer(p, "tablier", _laine(LAINES["lin"]))
			_montrer(p, "ceinture", _etoffe("ceinture_cuir_a", Color.WHITE))
			_cacher(p, "pantalon")
		"tablier":
			_montrer(p, "tablier", _laine(LAINES["lin"].darkened(0.05)))
			_montrer(p, "ceinture", _etoffe("ceinture_cuir_b", Color.WHITE))
			_montrer(p, "cape_courte", _laine(laine.darkened(0.1)))
		"chasse":
			_montrer(p, "ceinture", _etoffe("ceinture_cuir_c", Color.WHITE))
			_montrer(p, "sacoche", _etoffe("bottes_cuir_a", Color.WHITE))
	var mm: MeshInstance3D = p.get("mante")
	if mm != null and (tenue == "fourrure" or (not homme and mm.visible)):
		var f: Color = FOURRURES[String(a.get("fourrure", "gris" if not homme else "brun"))]
		mm.visible = true
		mm.set_meta("fourrure_pnj", f)     # RealismePnj : mante repeinte entièrement en touffes de cette couleur, ourlet découpé

## Retire de la surface `s` les triangles dont `retirer(centre, uv moyen)` est vrai ; le nombre de surfaces est gardé (triangle
## dégénéré si tout part), les matériaux aussi.
static func _retirer(mi: MeshInstance3D, s: int, retirer: Callable) -> void:
	if mi == null or mi.mesh == null or s >= mi.mesh.get_surface_count():
		return
	var mesh := ArrayMesh.new()
	var mats: Array = []
	for k in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(k)
		var nb := 4
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] != null and vv.size() > 0:
			nb = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / vv.size()
		for kc in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[kc] = null
		if k == s:
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(vv.size())
				for i in vv.size():
					idx[i] = i
			var garde := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var c := (vv[idx[t]] + vv[idx[t + 1]] + vv[idx[t + 2]]) / 3.0
				var uvm := Vector2.ZERO
				if uvs.size() == vv.size():
					uvm = (uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0
				if not retirer.call(c, uvm):
					garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
			if garde.is_empty():
				garde.append_array([0, 0, 0])
			arr[Mesh.ARRAY_INDEX] = garde
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
		mats.append(mi.get_surface_override_material(k))
	mi.mesh = mesh
	for j in mats.size():
		mi.set_surface_override_material(j, mats[j])

# ======================================================================================================== corpulence
## Corpulence : sommets AU REPOS déplacés (même fonction de la position pour toutes les pièces, donc elles restent emboîtées) ;
## poids, os et animations inchangés. epaules : buste et carrure (x) ; ventre : avancée du ventre (z) ; taille : tour de taille (x, z).
## Amplitudes de quelques pour cent (au-delà, les bras traversent le buste).
static func _carrure(sq: Skeleton3D, c: Dictionary) -> void:
	var ep := float(c.get("epaules", 0.0))
	var ve := float(c.get("ventre", 0.0))
	var ta := float(c.get("taille", 0.0))
	if absf(ep) + absf(ve) + absf(ta) < 0.001:
		return
	var y_ep := sq.get_bone_global_rest(sq.find_bone("spine_03")).origin.y + 0.10
	var y_ve := sq.get_bone_global_rest(sq.find_bone("spine_01")).origin.y + 0.02
	var f := func(v: Vector3) -> Vector3:
		var r := v
		var ax := absf(v.x)
		# buste et épaules (pas les bras : |x| < 0,24, fondu au-delà)
		var k_ep := exp(-pow((v.y - y_ep) / 0.16, 2)) * (1.0 - smoothstep(0.20, 0.30, ax))
		r.x += v.x * ep * k_ep
		r.z += v.z * ep * 0.5 * k_ep
		# ventre : vers l'avant, sur le devant seulement
		var k_ve := exp(-pow((v.y - y_ve) / 0.14, 2)) * (1.0 - smoothstep(0.14, 0.24, ax))
		if v.z > -0.02:
			r.z += ve * 1.6 * k_ve * smoothstep(-0.02, 0.10, v.z)
		r.x += v.x * ve * 0.5 * k_ve
		# taille (tour de hanches / taille)
		var k_ta := exp(-pow((v.y - y_ve + 0.06) / 0.18, 2)) * (1.0 - smoothstep(0.24, 0.34, ax))
		r.x += v.x * ta * k_ta
		r.z += v.z * ta * k_ta
		return r
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if mi.mesh == null or not (mi.mesh is ArrayMesh):
			continue
		var mesh := ArrayMesh.new()
		var mats: Array = []
		for k in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(k)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in vv.size():
				vv[i] = f.call(vv[i])
			arr[Mesh.ARRAY_VERTEX] = vv
			for kc in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arr[kc] = null     # canaux personnalisés (inutilisés par ps1_perso) : leur format n'est pas transmis par add_surface_from_arrays
			var nb := 4
			if arr[Mesh.ARRAY_BONES] != null and vv.size() > 0:
				nb = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / vv.size()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
			mats.append(mi.get_surface_override_material(k))
		mi.mesh = mesh
		for j in mats.size():
			mi.set_surface_override_material(j, mats[j])
