extends SceneTree
## Assemble les planches de la passe vetements du gardien (jetable).
const R := "C:/Users/lopezk19/Desktop/Skyrim captures/refonte/persos/gardien/vetements/"
const REF := "C:/Users/lopezk19/Downloads/Image ChatGPT 21 oct. 2026, 14_01_58-4.png"
func _init() -> void:
	_go.call_deferred()
func _l(p: String) -> Image:
	var i := Image.load_from_file(p)
	i.convert(Image.FORMAT_RGB8)
	return i
func _cell(dst: Image, src: Image, x: int, y: int, w: int, h: int) -> void:
	var s := src.duplicate() as Image
	s.resize(w, h, Image.INTERPOLATE_LANCZOS)
	dst.blit_rect(s, Rect2i(0, 0, w, h), Vector2i(x, y))
func _go() -> void:
	var ref := _l(REF)
	# 1. reference | avant | apres, 2 m face / 3-4 / dos
	var rows := [["p2_face", "v_2m_face"], ["p2_34", "v_2m_34"], ["p2_dos", "v_2m_dos"]]
	_planche("planche_ref_avant_apres_2m.png", rows, ref, 640, 360)
	var gros := [["g_torse", "v_torse"], ["g_ceinture", "v_ceinture"], ["g_bas", "v_bas"], ["g_bottes", "v_bottes"], ["g_dos", "v_dos"]]
	_planche("planche_gros_plans_1m.png", gros, ref, 640, 360)
	# distances
	var d := Image.create(3 * 427, 4 * 240, false, Image.FORMAT_RGB8)
	var r := 0
	for m in ["4", "8"]:
		for c in 3:
			var v: String = ["face", "34", "dos"][c]
			_cell(d, _l(R + "avant/p%s_%s.png" % [m, v]), c * 427, r * 240, 427, 240)
			_cell(d, _l(R + "apres3g/v_%sm_%s_crepuscule.png" % [m, v]), c * 427, (r + 1) * 240, 427, 240)
		r += 2
	d.save_png(R + "planche_4m_8m_avant_apres.png")
	var an := ["Walk_25", "Walk_75", "Sprint_40", "Sword_Idle_30", "Sword_Attack_35", "Sword_Attack_60", "Hit_Chest_40", "Death01_60"]
	var a := Image.create(4 * 480, 2 * 270, false, Image.FORMAT_RGB8)
	for i in an.size():
		_cell(a, _l(R + "apres3g/a_%s_crepuscule.png" % an[i]), (i % 4) * 480, (i / 4) * 270, 480, 270)
	a.save_png(R + "planche_animations.png")
	quit()
func _planche(nom: String, rows: Array, ref: Image, w: int, h: int) -> void:
	var rw := int(h * ref.get_width() / float(ref.get_height()))
	var has_ref := nom.contains("ref")
	var off := rw if has_ref else 0
	var im := Image.create(off + 2 * w, rows.size() * h, false, Image.FORMAT_RGB8)
	for i in rows.size():
		if has_ref:
			_cell(im, ref, 0, i * h, rw, h)
		_cell(im, _l(R + "avant/%s.png" % rows[i][0]), off, i * h, w, h)
		_cell(im, _l(R + "apres3g/%s_crepuscule.png" % rows[i][1]), off + w, i * h, w, h)
	im.save_png(R + nom)
