extends SceneTree
## Génère assets/magie/givre_kenney_atlas.png (formes du souffle de givre, shaders/magie_givre.gdshader) à partir du
## Kenney Particle Pack (CC0, kenney.nl/assets/particle-pack) :
##   godot --headless --path . --script res://outils/generer_atlas_givre.gd -- [--source=<dossier PNG du pack>]
## Atlas 4×3 de 128², une seule composante (luminance) :
##   rangée 0 = volumes du souffle (smoke_01, 02, 04, 05 : flipbook fondu),
##   rangée 1 = tourbillons (twirl_01-03 : la brume qui roule) et brume de fin de vie (smoke_08),
##   rangée 2 = scintillements des cristaux (star_06, 07, 08, 04).

const SOURCE := "C:/Users/lopezk19/Jeux/references/kenney_particle_pack/PNG/"
const FORMES := [
	["smoke_01", "smoke_02", "smoke_04", "smoke_05"],
	["twirl_01", "twirl_02", "twirl_03", "smoke_08"],
	["star_06", "star_07", "star_08", "star_04"],
]
const T := 128

func _init() -> void:
	var src := SOURCE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--source="):
			src = a.trim_prefix("--source=")
	var atlas := Image.create(T * 4, T * 3, false, Image.FORMAT_L8)
	for r in 3:
		for c in 4:
			var f: String = src.path_join(FORMES[r][c] + ".png")
			var im := Image.load_from_file(f)
			if im == null or im.is_empty():
				push_error("forme introuvable : " + f)
				quit(1)
				return
			im.convert(Image.FORMAT_RGBA8)
			im.resize(T, T, Image.INTERPOLATE_LANCZOS)
			im.convert(Image.FORMAT_L8)
			atlas.blit_rect(im, Rect2i(0, 0, T, T), Vector2i(c * T, r * T))
	atlas.save_png("res://assets/magie/givre_kenney_atlas.png")
	print("givre_kenney_atlas.png écrit (%d×%d)" % [atlas.get_width(), atlas.get_height()])
	quit()
