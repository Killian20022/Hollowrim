extends SceneTree
## Planche des icônes AVANT | APRÈS (atlas 32 px) des objets passés en props Quaternius (modele_quat), sans fenêtre :
##   godot --headless --path . --script res://outils/planche_icones_quat.gd -- --avant=<dossier atlas d'avant> --sortie=<png>
## Une ligne par objet (ordre alphabétique, imprimé) : icône d'avant ×4 | icône d'après ×4, sur vélin clair puis sur cuir sombre.

const T := 32
const K := 4
const VELIN := Color("#e9dcc0")
const CUIR := Color("#2a1f16")

func _init() -> void:
	var avant := ""
	var sortie := "res://captures/objets_quat/planche_icones.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--avant="):
			avant = a.substr(8)
		elif a.begins_with("--sortie="):
			sortie = a.substr(9)
	var ids: Array = []
	for oid: String in Inventaire.ids_connus():
		if String(Inventaire.objet(oid).get("modele_quat", "")) != "":
			ids.append(oid)
	ids.sort()
	var ia := _index(avant.path_join("icones.json"))
	var ib := _index("res://assets/ui/icones/icones.json")
	var aa := Image.load_from_file(avant.path_join("icones_32.png"))
	var ab := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/icones/icones_32.png"))
	var col := 4
	var case_w := (T * K) * 4 + 30
	var case_h := T * K + 10
	var rangs := ceili(float(ids.size()) / col)
	var img := Image.create(col * case_w, rangs * case_h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#14110d"))
	for n in ids.size():
		var oid: String = ids[n]
		var x0 := (n % col) * case_w
		var y0 := (n / col) * case_h
		var k := 0
		for fond: Color in [VELIN, CUIR]:
			for paire: Array in [[aa, ia], [ab, ib]]:
				var r := Rect2i(x0 + k * T * K + (k / 2) * 10, y0, T * K, T * K)
				img.fill_rect(r, fond)
				var idx: Dictionary = paire[1]
				if paire[0] != null and idx.has(oid):
					var c := int(idx[oid])
					var cols := int(idx.get("_colonnes", 16))
					var ic := (paire[0] as Image).get_region(Rect2i((c % cols) * T, (c / cols) * T, T, T))
					ic.resize(T * K, T * K, Image.INTERPOLATE_NEAREST)
					img.blend_rect(ic, Rect2i(0, 0, T * K, T * K), r.position)
				k += 1
		print("ICONE %d %s (avant %s)" % [n, oid, "oui" if ia.has(oid) else "non"])
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	img.save_png(sortie)
	print("PLANCHE ", sortie)
	quit(0)

func _index(chemin: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var r := {}
	if d is Dictionary:
		var ids: Array = d.get("ids", [])
		for k in ids.size():
			r[String(ids[k])] = k
		r["_colonnes"] = int(d.get("colonnes", 16))
	return r
