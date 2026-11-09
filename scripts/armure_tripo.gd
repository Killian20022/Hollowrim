class_name ArmureTripo
## ESSAI Tripo (branche essai/maison) : l'armure dorée Tripo COMPLÈTE (casque, cuirasse à épaulières et manches, gantelets, jambières,
## bottes) HABILLÉE sur le squelette humain du jeu : assets/essai_tripo/armure_complete.glb (sources_blender/scripts/armure_tripo_rig.py,
## repartie de la planche Tripo : vue de face de chaque pièce, mise à l'échelle d'un homme de 1,81 m, poids lissés transférés du corps).
## Deux maillages habillés, greffés sur le Skeleton3D du modèle (mêmes noms d'os, poses de liaison du GLB) :
##   « armure »      or bruni + cuir sombre (atlas 512 recuit), shader ps1 ;
##   « sous_couche » le corps ramené derrière l'armure, en cuir sombre (comble coudes, genoux, aisselles, cou en marche) ;
##   « canon_l/_r » les brassards des avant-bras, pièces RIGIDES accrochées aux os lowerarm (BoneAttachment3D).
## Le corps d'origine (peau, yeux, cheveux, barbe, sous-vêtement) est masqué : l'armure couvre tout.
## `equiper(modele)` retourne les MeshInstance3D ajoutés.
const GLB := "res://assets/essai_tripo/armure_complete.glb"
const TEX := "res://assets/essai_tripo/armure_complete_tex.png"
## Teinte de l'or (multiplie l'atlas : or bruni du rendu Tripo, un peu relevé pour rester lisible sous le shader ps1).
const TEINTE := Color(0.5, 0.43, 0.34)
## Lueur propre de l'or, PROPORTIONNELLE à sa couleur (et non un ajout plat) : à contre-jour, de dos ou de profil, les lames gardent
## leurs reflets clairs sur fond brun au lieu de virer au brun uni, sans délaver la face au soleil.
const LUEUR := Vector3(0.7, 0.63, 0.52)
## Cuir de la sous-couche, sombre : il se lit comme l'ombre entre les plaques (omoplates, aisselles), pas comme une pièce.
const TEINTE_MAILLES := Color(0.42, 0.36, 0.3)
static var _mat: ShaderMaterial
static var _shader: Shader

## Shader perso du jeu dont l'émission est multipliée par l'albédo (EMISSION = emission * ALBEDO), en DOUBLE FACE : les pièces
## Tripo sont des plaques à une seule surface ; l'intérieur des manchettes évasées montre l'or au lieu du cuir sombre de dessous.
static func shader_or() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = Humain.shader_perso(true).code.replace("EMISSION = emission +", "EMISSION = emission * ALBEDO +")
	return _shader
static var _mat_mailles: ShaderMaterial

static func materiau() -> ShaderMaterial:
	if _mat == null:
		_mat = Palette.materiau(load(TEX) as Texture2D, Vector2.ONE, TEINTE, false)
		_mat.shader = shader_or()
		_mat.set_shader_parameter("emission", LUEUR)
		_mat.set_shader_parameter("tex_neige", load(TEX) as Texture2D)   # pas de neige sur l'armure (elle blanchissait l'or)
	return _mat

static func materiau_mailles() -> ShaderMaterial:
	if _mat_mailles == null:
		var tex := PersonnagesTextures.tex("tunique_cuir_b")
		_mat_mailles = Palette.materiau(tex, Vector2(2.0, 2.0), TEINTE_MAILLES, false)
		_mat_mailles.shader = Humain.shader_perso(false)
		_mat_mailles.set_shader_parameter("tex_neige", tex)
	return _mat_mailles

static func equiper(modele: Node3D, _cacher := true) -> Array:
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return []
	for c in sq.find_children("*", "MeshInstance3D", false, false):
		(c as MeshInstance3D).visible = false
	var src := (load(GLB) as PackedScene).instantiate()
	var res: Array = []
	for nom in ["armure", "sous_couche"]:
		var mi0 := src.find_child(nom, true, false) as MeshInstance3D
		if mi0 == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Armure_" + nom
		mi.mesh = mi0.mesh
		mi.skin = mi0.skin
		mi.material_override = materiau() if nom == "armure" else materiau_mailles()
		sq.add_child(mi)
		mi.skeleton = NodePath("..")
		res.append(mi)
	# canons des avant-bras : pièces RIGIDES (brassards), accrochées aux os lowerarm_l / lowerarm_r par un BoneAttachment3D, comme
	# l'épée des gardes ; aucune déformation. Le maillage est aux coordonnées de la pose de repos du GLB : sa transformation sous
	# l'attache est la pose de liaison de l'os dans la peau de l'armure (même placement que si elle était habillée à 100 % sur l'os).
	var peau := (src.find_child("armure", true, false) as MeshInstance3D).skin if src.find_child("armure", true, false) != null else null
	for cote in ["l", "r"]:
		var mc := src.find_child("canon_" + cote, true, false) as MeshInstance3D
		if mc == null or peau == null:
			continue
		var lie := Transform3D.IDENTITY
		for i in peau.get_bind_count():
			if peau.get_bind_name(i) == "lowerarm_" + cote or (peau.get_bind_name(i) == "" and sq.get_bone_name(peau.get_bind_bone(i)) == "lowerarm_" + cote):
				lie = peau.get_bind_pose(i)
		var acc := BoneAttachment3D.new()
		acc.name = "Canon_" + cote
		acc.bone_name = "lowerarm_" + cote
		sq.add_child(acc)
		var mi := MeshInstance3D.new()
		mi.name = "Armure_canon_" + cote
		mi.mesh = mc.mesh
		mi.material_override = materiau()
		mi.transform = lie
		acc.add_child(mi)
		res.append(mi)
	src.free()
	return res
