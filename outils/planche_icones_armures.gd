extends SceneTree
## Planche des icônes 16 px des armures et bijoux (lot A RPG) : icône ×4 (nearest) + nom, sur vélin, rangée par matériau.
##   godot --path . --script res://outils/planche_icones_armures.gd -- <sortie.png>   (fenêtre : passer par godot_slot.sh)

const RANGS := [
	["Cuir", ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"]],
	["Fourrure", ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"]],
	["Fer", ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"]],
	["Acier nordique", ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"]],
	["Os de draugr", ["casque_os", "cuirasse_os", "gants_os", "bottes_os"]],
	["Rares / uniques", ["heaume_jarl", "cuirasse_gardiens", "gantelets_hrafn", "bottes_rodeur", "capuche_thaumaturge", "brigandine_braise"]],
	["Cou", ["amulette_givre", "amulette_ours", "amulette_arcaniste", "collier_portefaix"]],
	["Anneaux", ["anneau_coureur", "anneau_adepte", "anneau_braise", "anneau_orage", "anneau_berserker", "anneau_marchand"]],
]
const CASE := Vector2(150, 100)

func _init() -> void:
	_faire.call_deferred()

func _faire() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := "user://planche_icones_armures.png"
	for a in args:
		if a.ends_with(".png"):
			sortie = a
	var w := int(130 + CASE.x * 6 + 20)
	var h := int(20 + CASE.y * RANGS.size() + 10)
	var vp := SubViewport.new()   # la fenêtre du projet reste en 640x360 : rendu hors écran à la taille de la planche
	vp.size = Vector2i(w, h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#e8dcbe")
	fond.size = Vector2(w, h)
	vp.add_child(fond)
	for r in RANGS.size():
		var y := 20.0 + r * CASE.y
		var titre := Label.new()
		titre.text = RANGS[r][0]
		titre.position = Vector2(12, y + 26)
		titre.add_theme_color_override("font_color", Color("#9a2a1a"))
		titre.add_theme_font_size_override("font_size", 15)
		fond.add_child(titre)
		var ids: Array = RANGS[r][1]
		for i in ids.size():
			var id: String = ids[i]
			var f := Inventaire.objet(id)
			var x := 130.0 + i * CASE.x
			var t := TextureRect.new()
			t.texture = IconesCombat.icone(String(f.get("icone", "")))
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.size = Vector2(64, 64)
			t.position = Vector2(x + (CASE.x - 64) * 0.5, y)
			fond.add_child(t)
			var l := Label.new()
			var stat := ("%d" % int(f.get("armure", 0))) if f.has("armure") else ""
			l.text = "%s\n%s%s" % [String(f.get("nom", id)).replace(" du serment", ""), stat + " · " if stat != "" else "", "%s kg" % str(f.get("poids", 0))]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.position = Vector2(x, y + 62)
			l.size = Vector2(CASE.x, 28)
			l.add_theme_color_override("font_color", Color("#3a2414"))
			l.add_theme_font_size_override("font_size", 10)
			l.add_theme_constant_override("line_spacing", -3)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fond.add_child(l)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(sortie)
	print("planche : ", sortie, " ", img.get_size())
	quit(0)
