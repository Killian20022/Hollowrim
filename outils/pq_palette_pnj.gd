extends SceneTree
## Palette des PNJ EXISTANTS (persos/quaternius_jeu, 2026-11-04) : échantillonne les étoffes, cuirs, fourrures et cheveux déjà en jeu
## (assets/pnj/*.res : tenues teintes des PNJ nommés et de la garde, outils/generer_pnj.gd) et en tire les couleurs dominantes
## (k-moyennes par texture, pondérées par la surface). La chaîne pq_convertir.py accroche les tissus et pelages Quaternius DESSUS
## (clé « accroche »: "pnj" de habitants.json) : mêmes couleurs que les villageois, gardes et draugrs à côté.
##   godot --headless --path . --script res://outils/pq_palette_pnj.gd
## Sortie : sources_blender/persos_quaternius/palette_pnj.json (+ palette_pnj.png, nuancier) ; à relancer si les tenues changent.
const DOSSIER := "res://assets/pnj"
const SORTIE := "res://sources_blender/persos_quaternius/palette_pnj"
const K := 5

func _init() -> void:
	var couleurs: Array = []      # [Color, poids, source]
	var peaux: Array = []         # teints des PNJ (visages montrés) : la peau des habitants s'y accroche
	for f in DirAccess.get_files_at(DOSSIER):
		if not f.ends_with(".res") or f.contains("yeux"):
			continue
		var r := load(DOSSIER + "/" + f)
		var img: Image = null
		if r is Image:
			img = (r as Image).duplicate()
		elif r is Texture2D:
			img = (r as Texture2D).get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() > 64:
			img.resize(64, 64 * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
		var px: Array = []
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					px.append(c)
		if px.size() < 16:
			continue
		for g: Array in _kmoyennes(px, K):
			if f.contains("peau"):
				if g[1] > 0.08:
					peaux.append("#" + (g[0] as Color).to_html(false))
			else:
				couleurs.append([g[0], g[1], f.get_basename()])
	# fusion des quasi-doublons (distance < 0.035) : poids cumulés
	var fus: Array = []
	for c: Array in couleurs:
		var deja := false
		for g: Array in fus:
			if _d(g[0], c[0]) < 0.035:
				g[1] += c[1]
				deja = true
				break
		if not deja:
			fus.append(c.duplicate())
	fus.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var out: Array = []
	for g: Array in fus:
		if g[1] < 0.02:
			continue
		var c: Color = g[0]
		out.append({"hex": "#" + c.to_html(false), "poids": snappedf(g[1], 0.001), "source": g[2], "v": snappedf(c.v, 0.01), "s": snappedf(c.s, 0.01)})
	var fa := FileAccess.open(SORTIE + ".json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"note": "outils/pq_palette_pnj.gd : couleurs des tenues des PNJ en jeu (assets/pnj), sRGB", "couleurs": out, "peaux": peaux}, " "))
	fa.close()
	var nuancier := Image.create(16 * 12, 16 * ((out.size() + 11) / 12), false, Image.FORMAT_RGBA8)
	for i in out.size():
		nuancier.fill_rect(Rect2i((i % 12) * 16, (i / 12) * 16, 16, 16), Color.html(out[i]["hex"]))
	nuancier.save_png(SORTIE + ".png")
	print("PALETTE_PNJ %d couleurs -> %s.json" % [out.size(), SORTIE])
	quit(0)

func _d(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## k-moyennes déterministes : [[centre, part des pixels], ...]
func _kmoyennes(px: Array, k: int) -> Array:
	var centres: Array = []
	for i in k:
		centres.append(px[int((i + 0.5) * px.size() / k)])
	var comptes := []
	for it in 8:
		var sommes := []
		comptes = []
		for i in k:
			sommes.append(Vector3.ZERO)
			comptes.append(0)
		for c: Color in px:
			var bi := 0
			var bd := 9.0
			for i in k:
				var d := _d(c, centres[i])
				if d < bd:
					bd = d
					bi = i
			sommes[bi] += Vector3(c.r, c.g, c.b)
			comptes[bi] += 1
		for i in k:
			if comptes[i] > 0:
				var m: Vector3 = sommes[i] / comptes[i]
				centres[i] = Color(m.x, m.y, m.z)
	var r: Array = []
	for i in k:
		if comptes[i] > 0:
			r.append([centres[i], float(comptes[i]) / px.size()])
	return r
