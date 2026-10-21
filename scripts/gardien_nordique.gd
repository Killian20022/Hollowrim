class_name GardienNordique
## Gardien nordique (garde de ville / de fortification), décliné du Guerrier pilote validé (GuerrierNordique, 83e97b3).
## Référence : « Image ChatGPT 21 oct. 2026, 14_01_58-4.png » (garde à la lance devant la palissade).
##
## Même recette que le guerrier : base Humain.creer (corps homme Quaternius, 65 os, animations partagées, ragdoll), pièces
## au shader ps1_perso + contour par coque, fourrure en mèches géométriques, accessoires MODELÉS dans un atlas à 128 texels/m.
## Ce qui le distingue du guerrier au premier coup d'œil (silhouette + couleur) :
##   - casque à plaques fermé sur le crâne, bandeau frontal et NASAL (le guerrier va tête nue) ;
##   - LANCE de 2,3 m tenue droite (le guerrier : épée courte) ;
##   - TABARD bleu du jarl de la poitrine aux genoux, bordure crème, une rune sobre, franges (le guerrier : plastron brun) ;
##   - épaulières en lames de fer, écharpe bleue au cou ; cotte de mailles brun-gris ferreux ; barbe et cheveux bruns.
## Même famille : cape bleue effilochée, fourrure gris-brun, bottes fourrées, bouclier rond cerclé de fer, cuir usé, liseré froid.
##
## Animations : la bibliothèque partagée est recopiée, et les clips où la lance doit rester droite sont recalculés (avant-bras
## droit relevé à l'horizontale, poing fermé, lance verticale) : « Idle » devient la garde en faction ; « Sword_Attack » devient
## un ESTOC (corps de Punch_Cross, lance pointée devant) ; « Sword_Idle » = garde de combat, lance pointée en avant.
## Les noms restent ceux de Humain.creer (aucun système à adapter) ; alias « Garde_Faction » et « Lance_Estoc ».
##
##   GardienNordique.creer({"bouclier": "bras" | "dos" | "", "lance": true}) -> Node3D
## Contrat identique à Humain.creer : racine -> Skeleton3D + AnimationPlayer « Animations », mêmes os, même ragdoll.

const TEINTE_CHEVEUX := Color(0.62, 0.45, 0.32)
const PEAU := Color(0.95, 0.86, 0.82)
## Prise du poing droit (repère de la main au repos) : axe de la hampe = Y local, centre du poing à l'origine (prise de l'épée).
const PRISE := GuerrierNordique.Accessoires.PRISE
## Tabard élargi (passe 2) : 0,33 m au lieu de 0,29 m, la bande bleue de la garde se lit de face et de dos à 8 m.
const LARGEUR_TABARD := 1.15

static var _mats := {}

static func materiau(tex: Texture2D, double_face := true, decoupe := false, avec_contour := true, cle := "") -> ShaderMaterial:
	return GuerrierNordique.materiau(tex, double_face, decoupe, avec_contour, cle)

static func vider() -> void:
	_lib = null
	_bas_lance = -1.0
	GardienTextures.vider()
	GuerrierNordique.vider()

# ======================================================================================================== fabrique
static func creer(options := {}) -> Node3D:
	var C := Color.WHITE
	var app := {"corps": "homme", "barbe": true, "cheveux": "Hair_Long", "teinte_cheveux": TEINTE_CHEVEUX, "peau": PEAU,
		"tenue": {"tunique": C, "pantalon": C, "bottes": C, "ceinture": C, "brassards": C, "cape": C, "mante": C, "tablier": C, "epaulieres": C}}
	var racine := Humain.creer(app)
	racine.name = "GardienNordique"
	var sq := racine.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := racine.get_node("Animations") as AnimationPlayer
	var pieces := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		pieces[String(mi.name)] = mi
	# -- animations à la lance (calculées une fois, partagées entre gardiens)
	var lib := _bibliotheque(ap, sq)
	ap.stop()
	sq.reset_bone_poses()
	ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	if _bas_lance < 0.0:
		_bas_lance = _mesurer_poing(lib.get_animation("Idle"), sq) - 0.06
	# -- matières
	_habiller(pieces["tunique"], materiau(GardienTextures.tex("mailles")))
	_habiller(pieces["pantalon"], materiau(GuerrierTextures.tex("pantalon")))
	_habiller(pieces["bottes"], materiau(GardienTextures.tex("bottes")))
	_habiller(pieces["brassards"], materiau(GuerrierTextures.tex("brassards")))
	_habiller(pieces["mante"], materiau(GardienTextures.tex("mante")))
	# passe 3 : le surcot cache le haut du pantalon et le bas de la cotte, le col couvre la mante : décimation de ces zones
	GuerrierNordique._decimer(pieces["pantalon"], func(p: Vector3) -> float: return 0.045 if p.y > 0.60 else 0.0)
	GuerrierNordique._decimer(pieces["tunique"], func(p: Vector3) -> float: return 0.045 if p.y < 1.0 else 0.0)
	GuerrierNordique._decimer(pieces["mante"], func(p: Vector3) -> float: return 0.032)
	var sc: MeshInstance3D = pieces.get("SuperHero_Male")
	if sc:
		sc.visible = false
	# peau : même traitement que le guerrier (éclaircie, appoint froid, contour)
	for nom in ["peau"]:
		var mi: MeshInstance3D = pieces.get(nom)
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				continue
			var cle := "gardien_peau_%d" % s
			if not _mats.has(cle):
				var m2 := ShaderMaterial.new()
				m2.shader = GuerrierNordique.shader(false)
				for p in ["tex_base", "teinte", "emission", "saturation"]:
					m2.set_shader_parameter(p, m.get_shader_parameter(p))
				m2.next_pass = GuerrierNordique.contour()
				var te: Variant = m.get_shader_parameter("teinte")
				m2.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * Color(1.18, 1.12, 1.08))
				m2.set_shader_parameter("appoint", Vector3(0.15, 0.14, 0.16))
				m2.set_shader_parameter("contour_froid", Vector3(0.24, 0.29, 0.40))
				Palette.materiaux.append(m2)
				Palette._appliquer(m2, Palette._ps1_actif)
				_mats[cle] = m2
			mi.set_surface_override_material(s, _mats[cle])
	# allègement (comme le guerrier) : yeux Quaternius -> cartes peintes, peau sous les manches retirée, mains décimées,
	# sourcils retirés ; cheveux : seulement ce qui dépasse SOUS le casque (nuque, côtés), plus de frange sur le front
	var yeux := GuerrierNordique._centres_yeux(pieces.get("Eyes"))
	var tete := sq.get_bone_global_rest(sq.find_bone("Head")).origin + Vector3(0, 0.07, 0)
	for nom in ["Eyes", "Eyebrows"]:
		if pieces.has(nom):
			pieces[nom].visible = false
	GuerrierNordique._filtrer(pieces.get("peau"), func(c: Vector3, n: Vector3) -> bool: return absf(c.x) < 0.19 or absf(c.x) > 0.69)
	GuerrierNordique._decimer(pieces.get("peau"), func(p: Vector3) -> float: return 0.027 if absf(p.x) > 0.5 else (0.018 if p.z < 0.035 else 0.0))
	var mi_ch: MeshInstance3D = sq.get_node_or_null("Hair_Long")
	if mi_ch:
		mi_ch.visible = true    # Humain.creer cache les cheveux sous un casque ; le nôtre est modelé ici
		GuerrierNordique._filtrer(mi_ch, func(c: Vector3, n: Vector3) -> bool: return c.y < 1.712 and c.z < 0.03 and n.dot(c - tete) > -0.002)
		GuerrierNordique._decimer(mi_ch, func(p: Vector3) -> float: return 0.03)
		var mc := materiau(GuerrierNordique._tex_cheveux(mi_ch), true, false, true, "gardien_cheveux")
		mc.set_shader_parameter("teinte", Color(0.78, 0.62, 0.48))
		mi_ch.material_override = mc
	var mi_b: MeshInstance3D = sq.get_node_or_null("Hair_Beard")
	if mi_b:
		GuerrierNordique._filtrer(mi_b, func(c: Vector3, n: Vector3) -> bool: return n.dot(c - tete) > -0.002)
		GuerrierNordique._decimer(mi_b, func(p: Vector3) -> float: return 0.011)
		GuerrierNordique._uv_barbe(mi_b)
		var mb := materiau(GuerrierTextures.tex("barbe"), true, false, false, "gardien_barbe")
		mb.set_shader_parameter("teinte", Color(0.70, 0.56, 0.46))
		mb.set_shader_parameter("appoint", Vector3(0.10, 0.09, 0.09))
		mi_b.material_override = mb
	# -- pièces versées dans les 2 surfaces de l'atlas (même budget de surfaces que le guerrier)
	var plastron := GuerrierNordique._plastron(sq, pieces["tunique"])
	GuerrierNordique._filtrer(pieces["mante"], func(c: Vector3, n: Vector3) -> bool: return not (c.z > 0.0 and absf(c.x) < 0.15 + (c.y - 1.30) * 0.25 and c.y < 1.53))
	var acc := AccGardien.new(sq)
	var A := Vector2(GuerrierTextures.ATLAS)
	var D := Vector2(GuerrierTextures.DECOUPES)
	acc.integrer(plastron, acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, (uv.y - GuerrierTextures.PL_V0 / 128.0) * 128.0 + GuerrierTextures.R_PLASTRON.position.y) / A)
	# ceinture : bombée sur le devant, elle serre le tabard (qui passe dessous)
	acc.integrer(pieces["ceinture"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(uv.x * 256.0 + GuerrierTextures.PL_U0, clampf((uv.y - 0.698) / 0.302, 0.0, 1.0) * 15.6 + 0.2 + GuerrierTextures.R_CEINT.position.y) / A,
		func(p: Vector3, n: Vector3) -> Vector3:
			var q := Vector3(p.x * 1.04, 0.989 + (p.y - 0.989) * 1.55, p.z * (1.32 if p.z > 0.0 else 1.04))
			return q + n * 0.006)
	var EP := GardienTextures.R_EPAUL
	acc.integrer(pieces["epaulieres"], acc.op, func(uv: Vector2) -> Vector2:
		return Vector2(EP.position.x + clampf((uv.x + 0.198) / 0.396, 0.0, 1.0) * (EP.size.x - 0.5), EP.position.y + clampf((uv.y - 0.17) / 0.23, 0.0, 1.0) * (EP.size.y - 0.5)) / A,
		func(p: Vector3, n: Vector3) -> Vector3: return p + n * 0.022 + Vector3(signf(p.x) * 0.012, -0.012, 0.0) * clampf((absf(p.x) - 0.18) / 0.2, 0.0, 1.0))
	# pèlerine (passe 2) : la cape du guerrier coupée aux hanches (rangée de 0,85 m), UV planaires vus de dos (emblème net)
	var PE := GardienTextures.D_PELERINE
	var uv_pelerine := func(_uv: Vector2, p: Vector3) -> Vector2:
		return Vector2(PE.position.x + clampf((GardienTextures.PEL_X - p.x) * 128.0, 0.0, PE.size.x - 0.5), PE.position.y + clampf((GardienTextures.PEL_Y - p.y) * 128.0, 0.0, PE.size.y - 0.5)) / D
	var aux_hanches := func(a: Vector3, b: Vector3, c: Vector3) -> bool: return maxf(a.y, maxf(b.y, c.y)) > 0.90
	acc.copier(pieces["cape"], acc.dec, uv_pelerine, Callable(), aux_hanches)
	# tabard : devant élargi (lisible à 8 m) + DOS (copie miroir posée sur le dos de la cotte et du pantalon, dépasse sous la pèlerine)
	var T := GardienTextures.D_TABARD
	var uv_tabard := func(uv: Vector2, _p: Vector3) -> Vector2:
		return Vector2(T.position.x + clampf((uv.x + 0.0796) / 0.1592, 0.0, 1.0) * (T.size.x - 0.5), T.position.y + clampf((uv.y - 0.078) / 0.922, 0.0, 1.0) * (T.size.y - 0.5)) / D
	acc.copier(pieces["tablier"], acc.dec, uv_tabard, func(p: Vector3, n: Vector3) -> Vector3: return Vector3(p.x * LARGEUR_TABARD, p.y, p.z) + n * 0.006)
	var dos := {}
	var sur_le_dos := func(p: Vector3, _n: Vector3) -> Vector3:
		var cle := p.snapped(Vector3.ONE * 0.0005)
		if not dos.has(cle):
			var x := p.x * LARGEUR_TABARD
			var z := 1.0
			for mi: MeshInstance3D in [pieces["tunique"], pieces["pantalon"]]:
				var pr := acc._projeter(mi, x, p.y, false)
				if not pr.is_empty():
					z = minf(z, pr[0].z - 0.016)
			dos[cle] = Vector3(x, p.y, z if z < 0.5 else -0.075 - p.z)
		return dos[cle]
	# seulement sous la pèlerine (au-dessus, il serait caché et se battrait avec elle)
	var sous_pelerine := func(a: Vector3, b: Vector3, c: Vector3) -> bool: return minf(a.y, minf(b.y, c.y)) < 0.97
	acc.copier(pieces["tablier"], acc.dec, uv_tabard, sur_le_dos, sous_pelerine, true)
	for nom in ["ceinture", "cape", "tablier", "epaulieres"]:
		pieces[nom].visible = false
	acc.poitrine_libre = true
	acc.epaules_libres = true
	acc.col(pieces["mante"])
	acc.poitrine_libre = false
	acc.epaules_libres = false
	acc.fourrure_bord(pieces["bottes"], 0.30, 0.45, 0.06, 0.09, 1.0, 1.6)
	acc.boucle(Vector3(0.0, 0.988, 0.176), 0.062)
	acc.fibule(plastron, Vector2(-0.13, 1.38))
	acc.yeux(yeux)
	acc.echarpe()
	acc.surcot(pieces["pantalon"], pieces["tunique"])
	acc.casque()
	plastron.visible = false
	var bouclier: String = options.get("bouclier", "bras")
	if bouclier != "":
		acc.bouclier(bouclier)
	if options.get("lance", true):
		acc.lance(_bas_lance)
	var mi_acc := acc.construire(sq.create_skin_from_rest_transforms())
	sq.add_child(mi_acc)
	racine.set_meta("gardien_nordique", true)
	return racine

static func _habiller(mi: MeshInstance3D, m: ShaderMaterial) -> void:
	mi.visible = true
	mi.material_override = m

# ======================================================================================================== animations
## Clips recalculés : « droite » = lance verticale (avant-bras droit relevé), « garde » = lance pointée en avant et vers le haut,
## « estoc » = lance pointée devant, légèrement vers le bas.
const CLIPS_DROITE := ["Idle", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Idle_Talking", "Hit_Chest"]
const PAS := 1.0 / 30.0
static var _lib: AnimationLibrary
## Longueur de hampe sous le poing (m) : pointe du talon à 1 cm du sol en garde en faction (mesurée sur Idle).
static var _bas_lance := -1.0

static func _bibliotheque(ap: AnimationPlayer, sq: Skeleton3D) -> AnimationLibrary:
	if _lib != null:
		return _lib
	var base := ap.get_animation_library("")
	var poing := _poing(ap, sq)
	var neuves := {}
	for nom: String in CLIPS_DROITE:
		neuves[nom] = _clip_lance(ap, sq, nom, "droite", poing)
	neuves["Sword_Idle"] = _clip_lance(ap, sq, "Sword_Idle", "garde", poing)
	neuves["Sword_Attack"] = _clip_lance(ap, sq, "Punch_Cross", "estoc", poing)
	neuves["Garde_Faction"] = neuves["Idle"]
	neuves["Lance_Estoc"] = neuves["Sword_Attack"]
	var lib := AnimationLibrary.new()
	for nom: StringName in base.get_animation_list():
		lib.add_animation(nom, neuves.get(String(nom), base.get_animation(nom)))
	for nom: String in neuves:
		if not lib.has_animation(nom):
			lib.add_animation(nom, neuves[nom])
	_lib = lib
	return lib

## Chaîne d'os du bras droit (de la racine à la main) : poses évaluées directement sur les pistes du clip (l'AnimationPlayer
## garde en cache l'ancienne bibliothèque tant que le nœud n'est pas dans l'arbre : on ne s'en sert pas pour le calcul).
const CHAINE := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]

static func _globales(a: Animation, sq: Skeleton3D, t: float) -> Dictionary:
	var res := {}
	var parent := Transform3D.IDENTITY
	for nom: String in CHAINE:
		var i := sq.find_bone(nom)
		var rest := sq.get_bone_rest(i)
		var chemin := NodePath("Armature/Skeleton3D:" + nom)
		var tp := a.find_track(chemin, Animation.TYPE_POSITION_3D)
		var tr := a.find_track(chemin, Animation.TYPE_ROTATION_3D)
		var pos := a.position_track_interpolate(tp, t) if tp >= 0 and a.track_get_key_count(tp) > 0 else rest.origin
		var rot := a.rotation_track_interpolate(tr, t) if tr >= 0 and a.track_get_key_count(tr) > 0 else rest.basis.get_rotation_quaternion()
		parent = parent * Transform3D(Basis(rot), pos)
		res[nom] = parent
	return res

## Hauteur minimale du centre du poing droit sur la garde en faction (Idle recalculé).
static func _mesurer_poing(a: Animation, sq: Skeleton3D) -> float:
	var ymin := 9.0
	for k in 8:
		ymin = minf(ymin, (_globales(a, sq, a.length * k / 8.0)["hand_r"] * PRISE).origin.y)
	return ymin

## Rotations des doigts droits (poing fermé) : première clé de Sword_Idle.
static func _poing(ap: AnimationPlayer, sq: Skeleton3D) -> Dictionary:
	var a := ap.get_animation("Sword_Idle")
	var res := {}
	for i in sq.get_bone_count():
		var n := sq.get_bone_name(i)
		if n.ends_with("_r") and (n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") or n.begins_with("pinky") or n.begins_with("thumb")):
			var tr := a.find_track(NodePath("Armature/Skeleton3D:" + n), Animation.TYPE_ROTATION_3D)
			if tr >= 0 and a.track_get_key_count(tr) > 0:
				res[n] = a.rotation_track_interpolate(tr, 0.0)
	return res

static func _piste(a: Animation, os_: String) -> int:
	var chemin := NodePath("Armature/Skeleton3D:" + os_)
	var t := a.find_track(chemin, Animation.TYPE_ROTATION_3D)
	if t < 0:
		t = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, chemin)
	else:
		while a.track_get_key_count(t) > 0:
			a.track_remove_key(t, 0)
	return t

static func _clip_lance(ap: AnimationPlayer, sq: Skeleton3D, src: String, mode: String, poing: Dictionary) -> Animation:
	var a := ap.get_animation(src)
	var res := a.duplicate(true) as Animation
	var t_bas := _piste(res, "lowerarm_r")
	var t_main := _piste(res, "hand_r")
	var g_loc := PRISE.basis.y.normalized()
	var n := int(ceilf(a.length / PAS))
	for k in n + 1:
		var t := minf(k * PAS, a.length)
		var gl := _globales(a, sq, t)
		var Pb: Basis = gl["upperarm_r"].basis.orthonormalized()
		var Lb: Basis = gl["lowerarm_r"].basis.orthonormalized()
		var Hb: Basis = gl["hand_r"].basis.orthonormalized()
		var h_loc := Lb.inverse() * Hb
		var cible := Vector3(0.0, -0.12, 1.0).normalized()
		if mode == "droite":
			# avant-bras relevé : vers l'avant, un peu vers l'extérieur et vers le bas (coude au corps)
			var df := Vector3(-0.30, -0.10, 1.0).normalized()
			Lb = Basis(Quaternion(Lb.y.normalized(), df)) * Lb
			cible = Vector3(0.0, 1.0, 0.06).normalized()
		elif mode == "garde":
			cible = Vector3(0.05, 0.40, 1.0).normalized()
		Hb = Lb * h_loc
		var g := (Hb * g_loc).normalized()
		Hb = Basis(Quaternion(g, cible)) * Hb
		res.rotation_track_insert_key(t_bas, t, (Pb.inverse() * Lb).get_rotation_quaternion())
		res.rotation_track_insert_key(t_main, t, (Lb.inverse() * Hb).get_rotation_quaternion())
	for os_: String in poing:
		var tp := _piste(res, os_)
		res.rotation_track_insert_key(tp, 0.0, poing[os_])
	return res

# ======================================================================================================== accessoires
class AccGardien extends GuerrierNordique.Accessoires:
	## Fourrure retirée des épaules (|x| > 0,24) : les épaulières de plaques restent lisibles sous le col de fourrure.
	var epaules_libres := false
	func _poitrine(p: Vector3) -> bool:
		return super._poitrine(p) or (epaules_libres and absf(p.x) > 0.24)

	## Comme integrer(), triangle par triangle : uvmap(uv, p) reçoit aussi la position (UV planaires), garder(a, b, c) filtre les
	## triangles (positions au repos), miroir = copie retournée devant/derrière (ordre des sommets inversé, normale z opposée).
	func copier(mi: MeshInstance3D, s: Dictionary, uvmap: Callable, deforme := Callable(), garder := Callable(), miroir := false) -> void:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := bones.size() / v.size()
		var os_de := {}
		for t in range(0, idx.size(), 3):
			if garder.is_valid() and not garder.call(v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]):
				continue
			for k: int in ([0, 2, 1] if miroir else [0, 1, 2]):
				var i := idx[t + k]
				var n := nrm[i]
				if miroir:
					n = Vector3(n.x, n.y, -n.z)
				var p := v[i]
				var q: Vector3 = deforme.call(p, n) if deforme.is_valid() else p
				s["v"].append(q)
				s["n"].append(n)
				s["uv"].append(uvmap.call(uv[i], p))
				var bo := [0, 0, 0, 0]
				var wo := [0.0, 0.0, 0.0, 0.0]
				for j in mini(nb, 4):
					var b := bones[i * nb + j]
					if not os_de.has(b):
						os_de[b] = maxi(0, GuerrierNordique._os_de_bind(mi.skin, sq, b))
					bo[j] = os_de[b]
					wo[j] = w[i * nb + j]
				s["b"].append_array(PackedInt32Array(bo))
				s["w"].append_array(PackedFloat32Array(wo))
	func _uva(x: float, y: float) -> Vector2:
		return Vector2(x / GuerrierTextures.ATLAS.x, y / GuerrierTextures.ATLAS.y)

	# ------------------------------------------------------------ casque à plaques (os Head)
	## Calotte de révolution un peu conique au-dessus de l'arcade (bord à 1,722 m), bandeau frontal rabattu, nasal, petite pointe.
	func casque() -> void:
		var os_ := sq.find_bone("Head")
		var c := Vector3(0.0, 1.722, -0.008)
		var rx := 0.103
		var rz := 0.117
		var profil := [[0.0, 1.0], [0.035, 0.99], [0.07, 0.90], [0.10, 0.70], [0.12, 0.42], [0.134, 0.0]]
		var n := 14
		var R := GardienTextures.R_CASQUE
		var B := GardienTextures.R_BANDEAU
		var dedans := c + Vector3(0, 0.04, 0)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var e0 := Vector3(cos(a0) * rx, 0.0, sin(a0) * rz)
			var e1 := Vector3(cos(a1) * rx, 0.0, sin(a1) * rz)
			var u0 := R.position.x + R.size.x * float(i) / n
			var u1 := R.position.x + R.size.x * float(i + 1) / n
			for k in profil.size() - 1:
				var A: Array = profil[k]
				var Bp: Array = profil[k + 1]
				var va: float = R.position.y + R.size.y * (1.0 - float(A[0]) / 0.134)
				var vb: float = R.position.y + R.size.y * (1.0 - float(Bp[0]) / 0.134)
				var p0: Vector3 = c + e0 * A[1] + Vector3(0, A[0], 0)
				var p1: Vector3 = c + e1 * A[1] + Vector3(0, A[0], 0)
				var p2: Vector3 = c + e1 * Bp[1] + Vector3(0, Bp[0], 0)
				var p3: Vector3 = c + e0 * Bp[1] + Vector3(0, Bp[0], 0)
				if k == profil.size() - 2:
					_tri(op, [p0, p1, p2], [_uva(u0, va), _uva(u1, va), _uva((u0 + u1) * 0.5, vb)], os_, dedans)
				else:
					_quad(op, p0, p1, p2, p3, _uva(u0, va), _uva(u1, va), _uva(u1, vb), _uva(u0, vb), os_, dedans)
			# bandeau frontal : bande extérieure (1 cm en saillie) + lèvre du dessous
			var bu0 := B.position.x + B.size.x * float(i) / n
			var bu1 := B.position.x + B.size.x * float(i + 1) / n
			var k_ext := 1.075
			var hb := -0.012
			var hh := 0.026
			var q0 := c + e0 * k_ext + Vector3(0, hb, 0)
			var q1 := c + e1 * k_ext + Vector3(0, hb, 0)
			var q2 := c + e1 * k_ext + Vector3(0, hh, 0)
			var q3 := c + e0 * k_ext + Vector3(0, hh, 0)
			_quad(op, q0, q1, q2, q3, _uva(bu0, B.position.y + B.size.y - 1), _uva(bu1, B.position.y + B.size.y - 1), _uva(bu1, B.position.y + 1), _uva(bu0, B.position.y + 1), os_, dedans)
			var r0 := c + e0 * 0.97 + Vector3(0, hb, 0)
			var r1 := c + e1 * 0.97 + Vector3(0, hb, 0)
			_quad(op, r0, r1, q1, q0, _uva(bu0, B.position.y + B.size.y - 1), _uva(bu1, B.position.y + B.size.y - 1), _uva(bu1, B.position.y + B.size.y - 2), _uva(bu0, B.position.y + B.size.y - 2), os_, dedans + Vector3(0, 0.2, 0))
			# dessus du bandeau (raccord à la calotte)
			var s0 := c + e0 * 1.0 + Vector3(0, hh + 0.004, 0)
			var s1 := c + e1 * 1.0 + Vector3(0, hh + 0.004, 0)
			_quad(op, q3, q2, s1, s0, _uva(bu0, B.position.y + 1), _uva(bu1, B.position.y + 1), _uva(bu1, B.position.y), _uva(bu0, B.position.y), os_, dedans)
		# nasal : lame de fer de l'arcade au bout du nez (devant = +z)
		var zf := c.z + rz * 1.075
		var f := GardienTextures.R_BANDEAU
		_boite_r(Vector3(-0.012, 1.655, zf - 0.004), Vector3(0.012, 1.745, zf + 0.006), os_, Rect2i(f.position.x, f.position.y, 12, f.size.y))

	## Boîte alignée sur les axes (repère du modèle), UV : une région de l'atlas.
	func _boite_r(a: Vector3, b: Vector3, os_: int, r: Rect2i) -> void:
		_boite(a, b, Transform3D.IDENTITY, os_, r)

	# ------------------------------------------------------------ écharpe de laine bleue au cou (neck_01 / spine_03)
	func echarpe() -> void:
		var i_cou := sq.find_bone("neck_01")
		var i_dos := sq.find_bone("spine_03")
		var pw := [PackedInt32Array([i_cou, i_dos, 0, 0]), PackedFloat32Array([0.55, 0.45, 0.0, 0.0])]
		var c := Vector3(0.0, 1.505, -0.012)
		var R := GardienTextures.R_LAINE
		var n := 12
		var sec := 5
		var rt := 0.030
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var m0 := c + Vector3(d0.x * 0.098, 0, d0.z * 0.112)
			var m1 := c + Vector3(d1.x * 0.098, 0, d1.z * 0.112)
			for j in sec:
				var b0 := TAU * j / sec
				var b1 := TAU * (j + 1) / sec
				var p := [m0 + d0 * cos(b0) * rt + Vector3(0, sin(b0) * rt * 1.2, 0), m1 + d1 * cos(b0) * rt + Vector3(0, sin(b0) * rt * 1.2, 0),
					m1 + d1 * cos(b1) * rt + Vector3(0, sin(b1) * rt * 1.2, 0), m0 + d0 * cos(b1) * rt + Vector3(0, sin(b1) * rt * 1.2, 0)]
				var u0 := R.position.x + R.size.x * float(i) / n
				var u1 := R.position.x + R.size.x * float(i + 1) / n
				var v0 := R.position.y + R.size.y * float(j) / sec
				var v1 := R.position.y + R.size.y * float(j + 1) / sec
				_quad(op, p[0], p[1], p[2], p[3], _uva(u0, v0), _uva(u1, v0), _uva(u1, v1), _uva(u0, v1), [pw, pw, pw, pw], (m0 + m1) * 0.5)


	# ------------------------------------------------------------ surcot de cuir (passe 3)
	## Deux panneaux de cuir brun (flancs gauche et droit) du bas de la ceinture (0,99 m) aux genoux (0,57 m), évasés, devant et dos
	## laissés libres (le tabard passe dessus, les jambes jouent). Rayons mesurés sur le pantalon et la cotte + marge + évasement ;
	## poids d'os du sommet de pantalon le plus proche. Ourlet bordé de fourrure crème (cartes plates).
	func surcot(pantalon: MeshInstance3D, tunique: MeshInstance3D) -> void:
		var ys := [0.99, 0.90, 0.80, 0.68, 0.57]
		var arr := pantalon.mesh.surface_get_arrays(0)
		var rayons := []
		for yy: float in ys:
			var rx := 0.0
			var zf := 0.0
			var zb := 0.0
			for mi: MeshInstance3D in [pantalon, tunique]:
				var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for p in v:
					if absf(p.y - yy) < 0.045:
						rx = maxf(rx, absf(p.x))
						zf = maxf(zf, p.z)
						zb = maxf(zb, -p.z)
			var marge := 0.028 + 0.070 * (0.99 - yy) / 0.42
			rayons.append([rx + marge, zf + marge, zb + marge])
		var R := GardienTextures.R_SURCOT
		var seg := 7
		var th0 := 0.30
		var th1 := PI - 0.30
		var cache := {}
		for lado: float in [1.0, -1.0]:
			for k in seg:
				var ta := lerpf(th0, th1, float(k) / seg)
				var tb := lerpf(th0, th1, float(k + 1) / seg)
				var ux := R.position.x + 10.0 * (k % 2)
				var ua := (ux + 0.3) if lado > 0.0 else (ux + 9.7)
				var ub := (ux + 9.7) if lado > 0.0 else (ux + 0.3)
				for j in ys.size() - 1:
					var pts := []
					var uvs := []
					var pws := []
					for c in 4:
						var t := ta if (c == 0 or c == 3) else tb
						var jj := j if c < 2 else j + 1
						var ra: Array = rayons[jj]
						var cz := cos(t)
						var pz: float = (ra[1] if cz > 0.0 else ra[2]) * cz
						var p := Vector3(lado * ra[0] * sin(t), ys[jj], pz)
						pts.append(p)
						uvs.append(_uva(ua if (c == 0 or c == 3) else ub, R.position.y + 0.3 + (R.size.y - 0.6) * float(jj) / (ys.size() - 1)))
						var ck := p.snapped(Vector3.ONE * 0.001)
						if not cache.has(ck):
							cache[ck] = _poids_proche(pantalon, arr, p)
						pws.append(cache[ck])
					_quad(op, pts[0], pts[1], pts[2], pts[3], uvs[0], uvs[1], uvs[2], uvs[3], pws, Vector3(0, pts[0].y, 0))
				# ourlet : carte de fourrure sous chaque segment
				var rb: Array = rayons[ys.size() - 1]
				var tm := (ta + tb) * 0.5
				var cz2 := cos(tm)
				var pm := Vector3(lado * rb[0] * sin(tm), ys[ys.size() - 1] + 0.012, (rb[1] if cz2 > 0.0 else rb[2]) * cz2)
				var ext := Vector3(pm.x, 0.0, pm.z).normalized()
				var tg := Vector3(-ext.z, 0.0, ext.x) * lado
				_carte_col(pantalon, arr, pm + ext * 0.004, tg, (Vector3.DOWN * 0.9 + ext * 0.45).normalized(), 0.085, 0.085 + _h(k) * 0.03, (k + int(lado)) % 4, false)

	# ------------------------------------------------------------ gros col de fourrure crème (passe 3)
	## Carte de mèche du col (D_COL), pliée en deux (la pointe retombe) : root, mi-longueur puis pointe ; `plie` = 4 triangles.
	func _carte_col(mi: MeshInstance3D, a: Array, r: Vector3, cote: Vector3, dir: Vector3, larg: float, lg: float, variante: int, plie := true) -> void:
		var C := GardienTextures.D_COL
		var D := Vector2(GuerrierTextures.DECOUPES)
		var u0 := (C.position.x + variante * 12.0 + 0.3) / D.x
		var u1 := (C.position.x + variante * 12.0 + 11.7) / D.x
		var v0 := (C.position.y + 0.3) / D.y
		var v1 := (C.position.y + C.size.y - 0.3) / D.y
		var ext := Vector3(dir.x, 0.0, dir.z).normalized()
		var d2 := (dir + Vector3.DOWN * 0.9).normalized() if plie else dir
		var m := r + dir * lg * 0.5
		var t := m + d2 * lg * 0.5
		var g := r - cote * larg * 0.5
		var d := r + cote * larg * 0.5
		var gm := m - cote * larg * 0.46
		var dm := m + cote * larg * 0.46
		var gt := t - cote * larg * 0.40
		var dt := t + cote * larg * 0.40
		var pr := _poids_proche(mi, a, r)
		var pm := _poids_proche(mi, a, m)
		var pt := _poids_proche(mi, a, t)
		var dedans := r - ext * 0.1 + Vector3(0, 0.05, 0)
		if plie:
			var vm := (v0 + v1) * 0.5
			_quad(dec, g, d, dm, gm, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, vm), Vector2(u0, vm), [pr, pr, pm, pm], dedans)
			_quad(dec, gm, dm, dt, gt, Vector2(u0, vm), Vector2(u1, vm), Vector2(u1, v1), Vector2(u0, v1), [pm, pm, pt, pt], dedans)
		else:
			_quad(dec, g, d, dt, gt, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), [pr, pr, pt, pt], dedans)

	## Trois couronnes de mèches autour du cou et sur les épaules, racines accrochées à la surface de la mante (sommet le plus
	## proche) : dressée autour du cou, retombant sur les épaules, retombée basse. Devant dégagé (menton, fibule).
	func col(mante: MeshInstance3D) -> void:
		var a := mante.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		# [nombre, y, rx, rz, vers l'extérieur, vers le haut/bas (+ = haut), longueur, largeur, angle mort devant]
		var couronnes := [
			[16, 1.52, 0.105, 0.12, 0.60, 0.80, 0.17, 0.11, 0.35],
			[22, 1.47, 0.160, 0.155, 0.95, -0.05, 0.24, 0.14, 0.40],
			[26, 1.42, 0.230, 0.180, 0.95, -0.45, 0.22, 0.13, 0.55],
			[28, 1.36, 0.300, 0.200, 0.90, -0.80, 0.18, 0.12, 0.90],
		]
		var n := 0
		for cr: Array in couronnes:
			var nb: int = cr[0]
			for i in nb:
				var th := TAU * (float(i) + 0.5 * (n % 2)) / nb
				var cz := cos(th)
				var ext := Vector3(sin(th), 0.0, cz)
				if cz > 0.0 and absf(sin(th)) < sin(float(cr[8])):
					continue
				var p := Vector3(sin(th) * cr[2], cr[1], cos(th) * cr[3] - 0.012)
				# accrochage : sommet de mante le plus proche
				var best := 0
				var bd := 1e9
				for k in v.size():
					var d := v[k].distance_squared_to(p)
					if d < bd:
						bd = d
						best = k
				var root := v[best] + nrm[best] * 0.012
				var dir := (ext * float(cr[4]) + Vector3.UP * float(cr[5])).normalized()
				var cote := ext.cross(Vector3.UP).normalized()
				var rd := 0.82 + _h(n) * 0.36
				_carte_col(mante, a, root, cote, dir, float(cr[7]) * (0.9 + _h(n + 1) * 0.3), float(cr[6]) * rd, (n + i) % 4)
				n += 1

	# ------------------------------------------------------------ lance (main droite)
	## Repère de la prise : hampe selon Y local ; talon à -bas, douille à 1,00 m, pointe à 1,30 m au-dessus du poing.
	func lance(bas: float) -> void:
		var os_ := sq.find_bone("hand_r")
		var tr := sq.get_bone_global_rest(os_) * GardienNordique.PRISE
		sq.set_meta("lance", [os_, tr, bas])
		if bas <= 0.0:
			bas = 1.1
		var H := GardienTextures.R_HAMPE
		# hampe : 6 pans, 3 segments, texture étirée du haut (v = 0, bague sous la douille) au talon ; poignée de cuir au poing
		var y0 := -bas
		var y1 := 1.0
		_tube(op, tr * Vector3(0, y1, 0), tr * Vector3(0, y0, 0), 0.016, 0.017, 6, os_, H, 3)
		# talon ferré
		_tube(op, tr * Vector3(0, y0, 0), tr * Vector3(0, y0 - 0.05, 0), 0.016, 0.006, 5, os_, Rect2i(H.position.x, H.position.y, H.size.x, 3), 1)
		# douille (cône de fer)
		var F := GardienTextures.R_FER_LANCE
		_tube(op, tr * Vector3(0, 1.0, 0), tr * Vector3(0, 1.075, 0), 0.019, 0.011, 6, os_, Rect2i(F.position.x, F.position.y, F.size.x, 10), 1)
		# fer en feuille : section en losange, [y, demi-largeur, demi-épaisseur]
		var sec := [[1.07, 0.014, 0.009], [1.14, 0.050, 0.009], [1.25, 0.040, 0.006], [1.34, 0.014, 0.004]]
		var pointe := Vector3(0, 1.42, 0)
		for k in sec.size():
			var A: Array = sec[k]
			var pa := [Vector3(-A[1], A[0], 0), Vector3(0, A[0], A[2]), Vector3(A[1], A[0], 0), Vector3(0, A[0], -A[2])]
			var va: float = F.position.y + 10.0 + (F.size.y - 11.0) * (A[0] - 1.07) / 0.27
			if k == sec.size() - 1:
				for i in 4:
					var u0 := F.position.x + (0.0 if i % 2 == 0 else 8.0)
					_tri(op, [tr * pa[i], tr * pa[(i + 1) % 4], tr * pointe], [_uva(u0, va), _uva(u0 + 7.9, va), _uva(u0 + 4.0, F.end.y - 0.5)], os_, tr * Vector3(0, A[0], 0))
				break
			var Bs: Array = sec[k + 1]
			var pb := [Vector3(-Bs[1], Bs[0], 0), Vector3(0, Bs[0], Bs[2]), Vector3(Bs[1], Bs[0], 0), Vector3(0, Bs[0], -Bs[2])]
			var vb: float = F.position.y + 10.0 + (F.size.y - 11.0) * (Bs[0] - 1.07) / 0.27
			for i in 4:
				var u0 := F.position.x + (0.0 if i % 2 == 0 else 8.0)
				_quad(op, tr * pa[i], tr * pa[(i + 1) % 4], tr * pb[(i + 1) % 4], tr * pb[i], _uva(u0, va), _uva(u0 + 7.9, va), _uva(u0 + 7.9, vb), _uva(u0, vb), os_, tr * Vector3(0, (A[0] + Bs[0]) * 0.5, 0))

	# ------------------------------------------------------------ assemblage : atlas du gardien
	func construire(skin: Skin) -> MeshInstance3D:
		var mi := super.construire(skin)
		var s := 0
		for d: Dictionary in [op, dec]:
			if d["v"].is_empty():
				continue
			if d == op:
				mi.set_surface_override_material(s, GuerrierNordique.materiau(GardienTextures.tex("accessoires"), false, false, true))
			else:
				mi.set_surface_override_material(s, GuerrierNordique.materiau(GardienTextures.tex("decoupes"), true, true, false))
			s += 1
		return mi
