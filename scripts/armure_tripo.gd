class_name ArmureTripo
## ESSAI Tripo (branche essai/maison) : l'armure dorée Tripo (assets/essai_tripo/armure.glb : casque, torse, gantelet, jambière, botte) PORTÉE
## par un humanoïde du jeu (Gardien nordique / corps du joueur) : chaque pièce est rigide, accrochée à l'os correspondant par un
## BoneAttachment3D. Les transformations sont calculées une fois dans la pose de repos (T) du squelette, donc indépendantes de la
## convention d'axes des os : pièce posée en espace modèle, puis ramenée dans le repère de l'os. Les pièces de gauche sont réfléchies
## (miroir X du modèle) pour la droite.
## `equiper(modele)` retourne les BoneAttachment3D créés ; `cacher` liste les maillages de l'habit d'origine masqués dessous.
const GLB := "res://assets/essai_tripo/armure.glb"
## Maillages de la livrée du Gardien remplacés par l'armure (le reste : peau, pantalon, tunique, cape… reste visible dessous).
const CACHES := ["plastron", "epaulieres", "brassards", "bottes", "gants", "capuche", "manchettes", "pteruges", "ceinture"]
## Réglages par pièce (côté gauche) : os, os de fin (null : centre fixe), t (position entre les deux), décalage (m, espace modèle),
## axe de la pièce (vers l'os de fin), échelle (x, y, z) dans le repère de la pièce, lacet (° autour de l'axe), miroir natif.
const PIECES := {
	"casque": {"os": "Head", "fin": "", "off": Vector3(0, 0.1, 0.025), "echelle": Vector3(2.1, 1.65, 1.95), "lacet": 0.0, "retourne": false, "cotes": false},
	"torse": {"os": "spine_03", "fin": "", "off": Vector3(0, 1.27, -0.018), "echelle": Vector3(2.8, 2.6, 3.3), "lacet": 0.0, "retourne": false, "cotes": false, "abs": true},
	"gantelet": {"os": "lowerarm_l", "fin": "hand_l", "t": 0.55, "off": Vector3.ZERO, "echelle": Vector3(2.2, 1.1, 1.65), "lacet": 0.0, "retourne": true, "cotes": true},
	"jambiere": {"os": "calf_l", "fin": "foot_l", "t": 0.5, "off": Vector3(0, 0, -0.01), "echelle": Vector3(2.6, 1.75, 1.75), "lacet": 180.0, "retourne": false, "cotes": true},
	"botte": {"os": "foot_l", "fin": "", "off": Vector3(0, -0.0015, 0.0975), "echelle": Vector3(2.1, 1.3, 2.0), "lacet": 180.0, "retourne": false, "cotes": true},
}
static var _mat: ShaderMaterial
static var _reglages := PIECES.duplicate(true)

## Matériau or « champagne » lisible : la texture Tripo (bronze sombre) est relevée (gamma + gain) et tirée vers le champagne ; shader ps1.
static func materiau() -> ShaderMaterial:
	if _mat != null:
		return _mat
	var src := load("res://assets/essai_tripo/armure_armure_tex.png") as Texture2D
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var champagne := Color(0.93, 0.78, 0.47)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.r * 0.3 + c.g * 0.5 + c.b * 0.2
			var v := clampf(pow(l, 0.66) * 1.18, 0.0, 1.0)
			var o := Color(champagne.r * v, champagne.g * v, champagne.b * v, c.a)
			img.set_pixel(x, y, c.lerp(o, 0.8) if c.a > 0.0 else c)
	_mat = Palette.materiau(ImageTexture.create_from_image(img), Vector2.ONE, Color(1.0, 0.98, 0.92), true)
	_mat.set_shader_parameter("emission", Vector3(0.06, 0.047, 0.02))
	return _mat

static func _os(sq: Skeleton3D, nom: String) -> Transform3D:
	return sq.get_bone_global_rest(sq.find_bone(nom))

## Transformation de la pièce `nom` (côté gauche) en espace squelette, pose de repos.
static func _repere(sq: Skeleton3D, r: Dictionary) -> Transform3D:
	var o: Transform3D = _os(sq, r["os"])
	var centre := o.origin
	var axe := Vector3.UP
	if r.get("fin", "") != "":
		var f: Transform3D = _os(sq, r["fin"])
		centre = o.origin.lerp(f.origin, float(r.get("t", 0.5)))
		axe = (f.origin - o.origin).normalized()
		if absf(axe.y) < 0.5:
			pass   # bras : Y de la pièce le long du bras
	if r.get("abs", false):
		centre = Vector3.ZERO
	centre += r["off"]
	var avant := Vector3(0, 0, 1)
	var z := (avant - axe * avant.dot(axe)).normalized()
	var x := axe.cross(z)
	var b := Basis(x, axe, z)
	if axe.y > 0.5 or axe.y < -0.5:
		# jambes : Y de la pièce vers le haut (la fin est plus bas)
		b = Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, 0, 1))
		if r.get("retourne", false):
			b = b * Basis(Vector3.UP, PI)
	b = b * Basis(Vector3.UP, deg_to_rad(float(r.get("lacet", 0.0))))
	if r.get("retourne", false) and absf(axe.y) <= 0.5:
		b = b * Basis(Vector3.FORWARD, PI)
	b = b * Basis.from_scale(r["echelle"])
	return Transform3D(b, centre)

static func equiper(modele: Node3D, cacher := true) -> Array:
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return []
	if cacher:
		for n: String in CACHES:
			var mi := sq.get_node_or_null(n) as MeshInstance3D
			if mi != null:
				mi.visible = false
	var src := (load(GLB) as PackedScene).instantiate()
	var res: Array = []
	for nom: String in _reglages:
		var r: Dictionary = _reglages[nom]
		var mi0 := src.find_child(nom, true, false) as MeshInstance3D
		if mi0 == null:
			continue
		var T := _repere(sq, r)
		var cotes: Array = ["_l", "_r"] if r["cotes"] else [""]
		for c: String in cotes:
			var t := T
			var os: String = r["os"]
			if c == "_r":
				t = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) * T
				os = os.trim_suffix("_l") + "_r"
			var acc := BoneAttachment3D.new()
			acc.name = "Armure_" + nom + c
			acc.bone_name = os
			sq.add_child(acc)
			var mi := MeshInstance3D.new()
			mi.mesh = mi0.mesh
			mi.name = nom
			mi.material_override = materiau()
			mi.transform = _os(sq, os).affine_inverse() * t
			acc.add_child(mi)
			res.append(acc)
	src.free()
	return res
