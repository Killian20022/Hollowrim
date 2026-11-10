extends SceneTree
## Précalcul (une fois, résultat commité) des VARIANTES DE LIVRÉE des gardes Tripo (lot tripo/gardiens) : pour chaque corps (lancier, épée,
## archer), 3 textures dérivées de la texture Tripo d'origine (assets/pnj/tripo_*_rig_tripo_*_512.png, jamais modifiée) :
##   v1 « lie-de-vin » : rouge du tabard plus sombre, tirant sur le pourpre ; fer inchangé ;
##   v2 « garance »    : rouge rouille, moins saturé ; fer et cuir noircis ;
##   v3 « passé »      : rouge délavé par l'hiver (saturation x0,45, tiré vers le rouge brique : sans reflet rose) ; fer un peu plus clair.
## Seuls les pixels ROUGES (tabard, cape, liserés) et, selon la variante, les gris (fer) changent ; peau et fourrure brunes restent.
## Sorties : assets/pnj/tripo_<corps>_v<n>.png (importées comme la texture d'origine : sans compression VRAM, mipmaps).
##   godot --headless --path . --script res://outils/generer_variantes_gardes_tripo.gd
const CORPS := {
	"tripo_garde_lance": "res://assets/pnj/tripo_garde_lance_rig_tripo_garde_lance_512.png",
	"tripo_garde_epee": "res://assets/pnj/tripo_garde_epee_rig_tripo_garde_epee_512.png",
	"tripo_archer": "res://assets/pnj/tripo_archer_rig_tripo_archer_512.png",
}
## [teinte visée du rouge (0-1, -1 = garder), facteur de saturation du rouge, facteur de valeur du rouge, facteur de valeur des gris (fer)]
const CRAMOISI := 0.955
const VARIANTES := [
	[0.955, 0.85, 0.55, 1.0],
	[0.035, 0.62, 0.80, 0.72],
	[0.985, 0.45, 0.85, 1.12],
]

func _init() -> void:
	for id: String in CORPS:
		var src := Image.load_from_file(ProjectSettings.globalize_path(CORPS[id]))
		src.convert(Image.FORMAT_RGBA8)
		for n in VARIANTES.size():
			var v: Array = VARIANTES[n]
			var im := src.duplicate() as Image
			var rouges := 0
			for y in im.get_height():
				for x in im.get_width():
					var c := im.get_pixel(x, y)
					var h := c.h
					var s := c.s
					var val := c.v
					# poids du rouge : teinte à moins de 0,04 du cramoisi Tripo (0,955, mesuré : RVB moyen 96,26,45 ; fondu jusqu'à 0,06 ; les cuirs bruns, vers 0,06-0,1,
					# restent hors du masque), saturation > 0,48 (fondu dès 0,32), pas les noirs
					var dh := absf(h - CRAMOISI)
					dh = minf(dh, 1.0 - dh)
					var w := clampf((0.06 - dh) / 0.02, 0.0, 1.0) * clampf((s - 0.32) / 0.16, 0.0, 1.0) * clampf((val - 0.06) / 0.08, 0.0, 1.0)
					var c2 := c
					if w > 0.0:
						rouges += 1
						var h2: float = h if float(v[0]) < 0.0 else float(v[0])
						var r := Color.from_hsv(h2, clampf(s * float(v[1]), 0.0, 1.0), clampf(val * float(v[2]), 0.0, 1.0), c.a)
						c2 = c.lerp(r, w)
					elif s < 0.14 and absf(float(v[3]) - 1.0) > 0.001:
						var g := clampf((0.14 - s) / 0.06, 0.0, 1.0)
						var f := lerpf(1.0, float(v[3]), g)
						c2 = Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)
					im.set_pixel(x, y, c2)
			var sortie := "res://assets/pnj/%s_v%d.png" % [id, n + 1]
			im.save_png(ProjectSettings.globalize_path(sortie))
			print("%s : %d pixels rouges recolorés (%.1f %%)" % [sortie, rouges, 100.0 * rouges / float(im.get_width() * im.get_height())])
	quit(0)
