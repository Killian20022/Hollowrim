extends SceneTree
## Planche de comparaison de la barre d'objets + boussole (avant / propositions a, b, c), composée dans un SubViewport :
##   godot --path . --script res://outils/planche_barre.gd -- --dossier=<captures/barre> --sortie=<png> [--zoom]
## Lit <dossier>/<colonne>/<vue>.png (1280x720) ; cellules réduites de moitié (= résolution logique 640x360).
## --zoom : bandes boussole + barre à 1:1 (pixels réels) au lieu des vues entières.

const COLS := [
	["avant", "AVANT : barre de fer, 10 cases"],
	["a", "A (préférée) : cartouche + ruban"],
	["b", "B : rangée fine permanente"],
	["c", "C : éventail de 5"],
]
const LIGNES := [
	["jour", "Jour, village"],
	["nuit", "Nuit, torche"],
	["crypte", "Crypte sombre"],
	["combat", "En combat (démo)"],
	["change", "Changement\nde raccourci"],
]

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

## Dossier d'image d'une cellule (colonne, ligne).
func _source(col: String, ligne: String) -> String:
	match ligne:
		"combat":
			return "combat_ancienne/crypte" if col == "avant" else "combat_%s/crypte" % col
		"change":
			match col:
				"avant": return "combat_ancienne/nuit"
				"a": return "a_deploye/nuit"
				_: return "combat_%s/nuit" % col
	match col:
		"avant": return "avant/" + ligne
		"a": return "a_repos/" + ligne
		_: return col + "/" + ligne

func _label(parent: Control, texte: String, pos: Vector2, taille: int, couleur: Color) -> void:
	var l := Label.new()
	l.text = texte
	l.position = pos
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)

func _go() -> void:
	var dossier := _arg("dossier", "res://captures/barre")
	var sortie := _arg("sortie", dossier.path_join("planche.png"))
	var zoom := OS.get_cmdline_user_args().has("--zoom")
	var cw := 640
	var ch := 360
	var marge_g := 170
	var haut := 70
	var lignes: Array = LIGNES
	if zoom:
		cw = 800
		ch = 130
		lignes = [["jour", "Jour"], ["crypte", "Crypte"], ["combat", "Combat"], ["change", "Changement"]]
	var vp := SubViewport.new()
	vp.size = Vector2i(marge_g + COLS.size() * (cw + 10), haut + lignes.size() * (ch + 10) + 40)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#1a120c")
	fond.size = Vector2(vp.size)
	vp.add_child(fond)
	_label(fond, "Hollowrim : barre d'objets + boussole, 3 propositions (style cuir enluminé). Choix en jeu : --barre=a|b|c|ancienne",
		Vector2(16, 8), 22, Color("#e8e0c8"))
	for c in COLS.size():
		_label(fond, COLS[c][1], Vector2(marge_g + c * (cw + 10), 40), 20, Color("#fcb53a") if COLS[c][0] == "a" else Color("#cca066"))
	for r in lignes.size():
		var y := haut + r * (ch + 10)
		_label(fond, lignes[r][1], Vector2(10, y + ch * 0.5 - 14), 18, Color("#cca066"))
		for c in COLS.size():
			var chemin := dossier.path_join(_source(COLS[c][0], lignes[r][0]) + ".png")
			var img := Image.load_from_file(chemin)
			if img == null or img.is_empty():
				_label(fond, "(manque " + chemin.get_file() + ")", Vector2(marge_g + c * (cw + 10), y), 16, Color.RED)
				continue
			if zoom:
				# boussole (haut) et barre (bas), 1:1
				img.convert(Image.FORMAT_RGBA8)
				var w := img.get_width()
				var bande := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
				bande.fill(Color("#1a120c"))
				bande.blit_rect(img, Rect2i(w / 2 - cw / 2, 0, cw, 46), Vector2i(0, 0))
				bande.blit_rect(img, Rect2i(w / 2 - cw / 2, img.get_height() - 80, cw, 80), Vector2i(0, 50))
				img = bande
			else:
				img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = Vector2(marge_g + c * (cw + 10), y)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fond.add_child(tr)
	_label(fond, "A : au repos un seul cartouche (mains tenues, G / D, sceau = touche) ; le ruban des 10 touches se déroule au changement puis se replie (2,2 s). "
		+ "B : 10 cases toujours là, estompées au repos. C : cartouche + 2 voisins de chaque côté, en arc.",
		Vector2(16, vp.size.y - 34), 16, Color("#cca066"))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	out.save_png(sortie)
	print("PLANCHE ", sortie, " ", out.get_size())
	quit(0)
