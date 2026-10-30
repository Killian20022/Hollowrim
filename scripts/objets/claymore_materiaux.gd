class_name ClaymoreMateriaux
## Matériaux RÉALISTES de la claymore longue (branche combat/claymore_2mains, retour utilisateur du 2026-10-30 : « la claymore
## ressemble trop à un jouet en plastique, il faut la rendre plus réelle »). À PART de EpeesLongues (que l'agent armes/realisme
## retouche pour les autres épées) : EpeesLongues.habiller pose d'abord les matériaux communs, puis on remplace, par nom de
## matériau Blender :
##   rubis -> « rubis profond » : cristal sombre et TRANSLUCIDE (même logique que le verre de Larme-de-Givre : shader verre de
##            EpeesLongues, alpha + bord rasant plus clair), nuages internes, fractures fines, inclusions sombres, biseaux et fil
##            clairs, petits éclats nets (pas de rouge bonbon uniforme) ;
##   fer   -> fer usé : rayures en biais, piqûres, crasse dans les creux, arêtes biseautées plus claires ;
##   cuir  -> cuir tressé à grain, couture (points clairs) le long de la fusée et du talon gainé.
## Tout passe par le shader ps1 (Palette.materiau / EpeesLongues.shader_verre) ; textures pixel 32 px, bruit à seuil (pas de Bayer).

const RUBIS := ["#070002", "#120104", "#1e0207", "#2c040b", "#3e0710", "#560c16", "#741520", "#9a2630", "#c85a5c", "#f4c4bc"]
const FER := ["#0b0c0f", "#14161a", "#1d2025", "#272b31", "#33383f", "#424850", "#565d66", "#6f7780", "#929aa3", "#bcc3ca"]
const CUIR := ["#0e0804", "#180e07", "#24150b", "#311d10", "#402716", "#51321d", "#663f25", "#7e5030", "#9c6840"]

static var _mats := {}

## EpeesLongues.habiller puis matériaux réalistes de la claymore.
static func habiller(racine: Node, ombres := false) -> void:
	EpeesLongues.habiller(racine, ombres)
	var mats := materiaux()
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in mailles:
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else ""
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var rubis := Palette.materiau(ImageTexture.create_from_image(_rubis()), Vector2.ONE, Color(1.18, 0.96, 0.96))
	rubis.shader = EpeesLongues.shader_verre()
	rubis.set_shader_parameter("opacite", 0.86)
	rubis.set_shader_parameter("lueur", 0.11)
	_mats = {
		"rubis": rubis,
		"fer": Palette.materiau(ImageTexture.create_from_image(_fer()), Vector2.ONE, Color(0.95, 0.95, 1.02)),
		"cuir": Palette.materiau(ImageTexture.create_from_image(_cuir()), Vector2.ONE, Color(1.0, 0.97, 0.94)),
	}
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return _mats

static func _c(r: Array, l: float, x: int, y: int) -> Color:
	return Color(r[ObjetsTextures._ton(l, r.size(), x, y, 0.35)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

## Rubis 32 x 128 (u en travers de la lame, v le long) : fond sombre à nuages internes, gouttière plus profonde, biseaux plus
## clairs, fil vif, fractures fines en biais, inclusions noires, quelques éclats nets d'un pixel.
static func _rubis() -> Image:
	var W := 32
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var nuage := ObjetsTextures._vn(x / 6.0, y / 9.0, 6, 15, 41) * 0.6 + ObjetsTextures._vn(x / 3.0, y / 4.0, 11, 32, 43) * 0.4
			var l := 0.32 + nuage * 0.26
			if au < 0.26:
				l -= 0.06                                            # gouttière : plus profonde, plus sombre
			elif au > 0.64 and au <= 0.9:
				l += 0.10 + 0.06 * float(int(v * 40.0) % 2)          # biseaux : facettes en paliers
			if au > 0.9:
				l = 0.66 + 0.1 * _h(x, int(v * 30.0), 7)             # fil du tranchant, plus clair
			var diag := fmod(v * 9.0 - u * 1.3 + _h(int(v * 5.0), 0, 47) * 3.0, 1.0)
			if diag > 0.485 and diag < 0.505 and au < 0.85:
				l += 0.16                                            # fractures internes fines
			var hh := _h(x, y, 53)
			if hh > 0.985:
				l = 0.05                                             # inclusions sombres
			elif hh < 0.006 and au > 0.3:
				l = 0.97                                             # éclats nets, petits
			if v < 0.04:
				l *= 0.6
			img.set_pixel(x, y, _c(RUBIS, clampf(l, 0.0, 0.999), x, y))
	return img

## Fer usé 32 x 32 : grain, rayures en biais (plus claires), piqûres et crasse sombres, arêtes (bords de la texture) biseautées.
static func _fer() -> Image:
	var N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var nuage := ObjetsTextures._vn(x / 5.0, y / 5.0, 7, 7, 61)
			var l := 0.30 + nuage * 0.16 + (_h(x, y, 62) - 0.5) * 0.06
			if nuage < 0.32:
				l -= 0.10                                            # crasse dans les creux
			for k in 7:                                              # rayures fines en biais
				var a := _h(k, 0, 63) * PI
				var d := absf((x - N * _h(k, 1, 64)) * sin(a) - (y - N * _h(k, 2, 65)) * cos(a))
				var long := absf((x - N * _h(k, 1, 64)) * cos(a) + (y - N * _h(k, 2, 65)) * sin(a))
				if d < 0.5 and long < 4.0 + 6.0 * _h(k, 3, 66):
					l += 0.22
			if _h(x, y, 67) > 0.95:
				l -= 0.14                                            # piqûres
			if y <= 1 or y >= N - 2:
				l += 0.20                                            # arêtes biseautées plus claires
			img.set_pixel(x, y, _c(FER, clampf(l, 0.0, 0.999), x, y))
	return img

## Cuir 32 x 64 : tressage en biais, grain, couture (points clairs) au milieu.
static func _cuir() -> Image:
	var W := 32
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var l := 0.38 + ObjetsTextures._vn(x / 4.0, y / 4.0, 8, 16, 71) * 0.14 + (_h(x, y, 72) - 0.5) * 0.10
			var bande := posmod(x + y, 8)
			if bande == 0:
				l -= 0.18                                            # creux entre deux lanières
			elif bande < 3:
				l += 0.08                                            # bombé de la lanière
			if x == 15 or x == 16:
				l = 0.16                                             # couture : sillon
				if posmod(y, 4) == (0 if x == 15 else 2):
					l = 0.78                                         # points de couture clairs
			img.set_pixel(x, y, _c(CUIR, clampf(l, 0.0, 0.999), x, y))
	return img
