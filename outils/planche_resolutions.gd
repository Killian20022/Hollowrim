extends SceneTree
## Planche du test de résolution (audit graphique) : lignes = vues (entree, crypte, grotte), colonnes = résolutions.
##   godot --headless --path . --script res://outils/planche_resolutions.gd -- <dossier audit_res> <sortie.png> [apercu.png]
## Lit <dossier>/<WxH>/<vue>.png (captures ×2 de outils/audit_resolutions.sh) et les lignes VUE de <dossier>/<WxH>/lot.log.
## Cases de 1920x1080 : chaque pixel interne vaut exactement 4, 3 ou 2 pixels (480, 640, 960) — rien n'est lissé.
## L'aperçu (optionnel) est la même planche au tiers (Lanczos), pour un coup d'œil.
const RES := ["480x270", "640x360", "960x540"]
const VUES := ["entree", "crypte", "grotte"]
const LC := 1920
const HC := 1080
const HB := 34
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)
const EXTRA := {
	"X": [17, 17, 10, 4, 10, 17, 17], ".": [0, 0, 0, 0, 0, 12, 12], "/": [1, 1, 2, 4, 8, 16, 16],
	"=": [0, 0, 31, 0, 31, 0, 0], "K": [17, 18, 20, 24, 20, 18, 17], "W": [17, 17, 17, 21, 21, 21, 10],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31], ":": [0, 12, 12, 0, 12, 12, 0],
}
var glyphes: Dictionary

func _init() -> void:
	glyphes = (load("res://outils/planche.gd") as Script).get_script_constant_map()["GLYPHES"].duplicate()
	glyphes.merge(EXTRA)
	var a := OS.get_cmdline_user_args()
	var dossier: String = a[0]
	var planche := Image.create(LC * RES.size(), (HC + HB) * VUES.size(), false, Image.FORMAT_RGB8)
	planche.fill(FOND)
	for c in RES.size():
		var mesures := _mesures(dossier.path_join(RES[c]).path_join("lot.log"))
		for l in VUES.size():
			var x := c * LC
			var y := l * (HC + HB)
			var f := dossier.path_join(RES[c]).path_join(VUES[l] + ".png")
			var im := Image.load_from_file(f)
			if im != null:
				im.convert(Image.FORMAT_RGB8)
				im.resize(LC, HC, Image.INTERPOLATE_NEAREST)
				planche.blit_rect(im, Rect2i(0, 0, LC, HC), Vector2i(x, y + HB))
			var m: String = mesures.get(VUES[l], "")
			_texte(planche, ("%s  %s  %s" % [VUES[l], RES[c], m]).to_upper(), Vector2i(x + 12, y + 6), 3)
	planche.save_png(a[1])
	print("planche : ", a[1], " ", planche.get_size())
	if a.size() > 2:
		var ap := planche.duplicate() as Image
		ap.resize(planche.get_width() / 3, planche.get_height() / 3, Image.INTERPOLATE_LANCZOS)
		ap.save_png(a[2])
		print("apercu : ", a[2], " ", ap.get_size())
	quit()

## « VUE i pos=(x,y,z) gpu_ms=… appels=… » → vue selon l'altitude (dehors > 0, crypte ≈ -140, grotte ≈ -220).
func _mesures(log: String) -> Dictionary:
	var r := {}
	for ligne in FileAccess.get_file_as_string(log).split("\n"):
		if not ligne.begins_with("VUE "):
			continue
		var y := float(ligne.get_slice("pos=(", 1).get_slice(",", 1))
		var vue := "entree" if y > -50.0 else ("crypte" if y > -180.0 else "grotte")
		var gpu := ligne.get_slice("gpu_ms=", 1).get_slice(" ", 0)
		var app := ligne.get_slice("appels=", 1).get_slice(" ", 0)
		r[vue] = "GPU %s MS  APPELS %s" % [gpu, app]
	return r

func _texte(img: Image, s: String, pos: Vector2i, k: int) -> void:
	var x := pos.x
	for ch in s:
		var g: Array = glyphes.get(ch, glyphes[" "])
		for ligne in 7:
			for col in 5:
				if (int(g[ligne]) >> (4 - col)) & 1:
					img.fill_rect(Rect2i(x + col * k, pos.y + ligne * k, k, k), TEXTE)
		x += 6 * k
