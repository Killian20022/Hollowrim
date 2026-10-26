extends SceneTree
## Outil hors jeu : fabrique toutes les textures du décor animé du menu à partir de la peinture de référence
## (textures/menu_decor/_source/reference.png, 1672×941, dossier ignoré par Godot donc non exporté).
##   godot --headless --path . --script res://scripts/menu_decor/outils/preparer.gd [-- --seulement=masques]
## Écrit dans textures/menu_decor/ :
##   fond_sans_logo.png  1920×1080 : boutons peints ET logo bouchés (texture utilisée par la scène)
##   fond_avec_logo.png  1920×1080 : boutons bouchés, logo peint conservé (fourni pour l'UI, non chargé par la scène)
##   logo_peint.png      recadrage RGBA du logo peint (alpha = masque adouci), posé par-dessus fond_sans_logo
##   masque_logo.png / masque_cristal.png  1920×1080 en niveaux de gris
##   cristal_halo.png    lueur bleue du cristal (additive)
##   masques_a.png 960×540 : R lac, G lumières chaudes (flammes 1, fenêtres ~0,45), B runes bleues, A cascade
##   masques_b.png 960×540 : R profondeur (0 ciel → 1 premier plan), G sapins (balancement), B halo des lumières, A ciel (nuages)
##   masques_c.png 960×540 : R brume, G halo des runes, B logo élargi, A reflets du lac
##   bruit.png 256×256 (bruits raccordables), flocon.png, flocon_flou.png, fumee.png
## Toutes les coordonnées écrites ici sont celles de la référence 1672×941.

const SW := 1672
const SH := 941
const W := 1920
const H := 1080
const MW := 960
const MH := 540
const DOSSIER := "res://textures/menu_decor/"

var _src: Image

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var seulement := ""
	for a in args:
		if a.begins_with("--seulement="):
			seulement = a.get_slice("=", 1)
	_src = Image.load_from_file(ProjectSettings.globalize_path(DOSSIER + "_source/reference.png"))
	_src.convert(Image.FORMAT_RGBF)
	if seulement == "" or seulement == "fond":
		_fabriquer_fonds()
		print("fonds : ", Time.get_ticks_msec() - t0, " ms")
	if seulement == "" or seulement == "masques":
		_fabriquer_masques()
		print("masques : ", Time.get_ticks_msec() - t0, " ms")
	if seulement == "" or seulement == "petites":
		_fabriquer_petites()
	print("FINI en ", Time.get_ticks_msec() - t0, " ms")
	quit()

# =====================================================================================================
# Fonds : bouchage des boutons, bouchage du logo, agrandissement
# =====================================================================================================

func _fabriquer_fonds() -> void:
	var img := _src.duplicate() as Image
	_boucher_boutons(img)
	var avec_logo := img.duplicate() as Image
	var m_logo := _masque_logo_source(avec_logo)
	var m_cristal := _masque_cristal_source(avec_logo)
	var sans_logo := img.duplicate() as Image
	_boucher_logo(sans_logo, m_logo)
	var g_avec := _agrandir(avec_logo)
	var g_sans := _agrandir(sans_logo)
	_sauver_rgb(g_avec, "fond_avec_logo.png")
	_sauver_rgb(g_sans, "fond_sans_logo.png")
	# masques pleine taille
	var ml := _agrandir_masque(m_logo, W, H)
	var mc := _agrandir_masque(m_cristal, W, H)
	_sauver_gris(ml, W, H, "masque_logo.png")
	_sauver_gris(mc, W, H, "masque_cristal.png")
	# logo peint recadré : alpha = masque adouci
	var r := _rect_ech(Rect2(490, 8, 724, 290), float(W) / SW)
	var logo := Image.create(int(r.size.x), int(r.size.y), false, Image.FORMAT_RGBA8)
	for y in int(r.size.y):
		for x in int(r.size.x):
			var gx := int(r.position.x) + x
			var gy := int(r.position.y) + y
			var c := g_avec.get_pixel(gx, gy)
			c.a = ml[gy * W + gx]
			logo.set_pixel(x, y, c)
	logo.save_png(ProjectSettings.globalize_path(DOSSIER + "logo_peint.png"))
	print("logo_peint rect (px du fond 1920) : ", r)
	# halo du cristal (additif) : masque flouté, teinté bleu, recadré 256×256 autour du centre
	var cx := 0.0; var cy := 0.0; var n := 0.0
	for y in H:
		for x in W:
			var v: float = mc[y * W + x]
			if v > 0.5:
				cx += x * v; cy += y * v; n += v
	cx /= maxf(n, 1.0); cy /= maxf(n, 1.0)
	print("centre du cristal (px du fond 1920) : ", Vector2(cx, cy))
	var T := 256
	var halo := PackedFloat32Array(); halo.resize(T * T)
	for y in T:
		for x in T:
			var gx := int(cx) - T / 2 + x
			var gy := int(cy) - T / 2 + y
			if gx >= 0 and gx < W and gy >= 0 and gy < H:
				halo[y * T + x] = mc[gy * W + gx]
	var large := _flou(halo, T, T, 18)
	var proche := _flou(halo, T, T, 4)
	var him := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var d := Vector2(x - T / 2.0, y - T / 2.0).length() / (T / 2.0)
			var bord := clampf(1.0 - d, 0.0, 1.0)
			var v := clampf(large[y * T + x] * 2.2 + proche[y * T + x] * 0.9, 0.0, 1.0) * smoothstep(0.0, 0.35, bord)
			him.set_pixel(x, y, Color(0.35 + 0.5 * proche[y * T + x], 0.7 + 0.25 * proche[y * T + x], 1.0, v))
	him.save_png(ProjectSettings.globalize_path(DOSSIER + "cristal_halo.png"))

## Bouchage des 5 boutons peints et du rail vertical (zone x 88-512, y 318-722 de la référence).
func _boucher_boutons(img: Image) -> void:
	var zone := Rect2i(40, 280, 560, 500) # zone de travail (avec marge)
	var zw := zone.size.x; var zh := zone.size.y
	# masque dur des boutons (1 = à boucher)
	var m := PackedFloat32Array(); m.resize(zw * zh)
	var rects := [Rect2(84, 318, 48, 404), Rect2(104, 364, 406, 356), Rect2(100, 358, 414, 90)]
	for y in zh:
		for x in zw:
			var p := Vector2(zone.position.x + x, zone.position.y + y)
			for rr in rects:
				if (rr as Rect2).has_point(p):
					m[y * zw + x] = 1.0
	var sous := img.get_region(zone)
	# 1) remplissage lisse (membrane) depuis les bords
	var lisse := _pousser_tirer(sous, m)
	# 2) calque cloné
	var clone := lisse.duplicate() as Image
	for y in zh:
		var gy := zone.position.y + y
		for x in zw:
			var gx := zone.position.x + x
			if m[y * zw + x] < 0.5 and _rampe(gx, gy) <= 0.0:
				continue
			var c: Color
			if gx >= 300 and gx < 352:
				c = _poteau(img, gx, gy)
			else:
				# pente enneigée semée de sapins (prise à droite du grand sapin, x 548-720 / y 548-688),
				# répétée en miroir alterné (raccords symétriques, sans couture), assombrie vers la gauche (ombre de la potence)
				c = _pente(img, gx, gy)
				if gx >= 440:
					# moitié gauche du grand sapin : miroir de sa moitié droite (axe x≈508), fondu vers la pente
					var mir := img.get_pixel(clampi(1016 - gx, 0, SW - 1), gy)
					c = c.lerp(mir, smoothstep(440.0, 470.0, gx))
				# ombre de la potence : plus sombre vers la gauche (rail compris), comme vu à travers les panneaux
				c = c.darkened(0.18 + 0.3 * clampf((470.0 - gx) / 340.0, 0.0, 1.0))
				# contraste relevé : la pente donneuse est lointaine (voile bleuté), ici on est au premier plan
				c = Color(maxf(0.0, (c.r - 0.14) * 1.35 + 0.11), maxf(0.0, (c.g - 0.14) * 1.35 + 0.11), maxf(0.0, (c.b - 0.14) * 1.35 + 0.11))
			clone.set_pixel(x, y, c)
	# 3) transfert : basses fréquences du lisse + détails du clone (sauf poteau et rail, gardés tels quels)
	var bas_clone := _passe_bas(clone, 20)
	var bas_lisse := _passe_bas(lisse, 20)
	var douce := _flou(m, zw, zh, 5)
	for y in zh:
		var gy := zone.position.y + y
		for x in zw:
			var gx := zone.position.x + x
			var k := maxf(smoothstep(0.0, 0.55, douce[y * zw + x]), _rampe(gx, gy))
			if k <= 0.001:
				continue
			var c := clone.get_pixel(x, y)
			if not (gx >= 300 and gx < 352):
				# garder la structure du clone mais raccorder sa teinte moyenne à celle des bords
				var b := bas_clone.get_pixel(x, y)
				var l := bas_lisse.get_pixel(x, y)
				var raccord := clampf(1.0 - _distance_bord(x, y, m, zw, zh) / 64.0, 0.0, 1.0)
				var cc := Color(c.r - b.r + l.r, c.g - b.g + l.g, c.b - b.b + l.b)
				c = c.lerp(cc, raccord)
			c = Color(maxf(c.r, 0.0), maxf(c.g, 0.0), maxf(c.b, 0.0))
			var o := img.get_pixel(gx, gy)
			# reste de lueur bleue du bouton « Continuer » autour de la zone : on la désature
			img.set_pixel(gx, gy, o.lerp(c, k))
	_eteindre_lueur_bleue(img, Rect2i(80, 340, 450, 120), m, zone)

## Fondu vers l'extérieur là où le fond voisin est de même nature (pente au-dessus à droite du poteau, bas de la zone) :
## évite la ligne droite au raccord. Pas de fondu sur la bannière, les poteaux ni les rochers de gauche.
func _rampe(gx: int, gy: int) -> float:
	if gx >= 352 and gx < 445 and gy < 364 and gy >= 344:
		return smoothstep(344.0, 364.0, gy)
	if gy > 720 and gy <= 736 and gx >= 136 and gx < 510 and not (gx >= 300 and gx < 352):
		return 1.0 - smoothstep(720.0, 736.0, gy)
	return 0.0

## Pente enneigée semée de sapins : patchs pris au hasard dans la zone donneuse (x 552-688, y 552-686), mêlés par poids doux
## (cellules de 56 px, tentes de 64 px de rayon, retournement horizontal aléatoire) : ni couture ni symétrie répétée.
const DON := Rect2i(552, 552, 136, 134)
var _cellules := {}

func _pente(img: Image, gx: int, gy: int) -> Color:
	var pas := 56
	var ci := floori((gx - 132) / float(pas)); var cj := floori((gy - 352) / float(pas))
	var somme := Color(0, 0, 0, 0)
	var poids := 0.0
	for j in range(cj - 1, cj + 2):
		for i in range(ci - 1, ci + 2):
			var centre := Vector2(132 + i * pas + pas * 0.5, 352 + j * pas + pas * 0.5)
			var d := Vector2(gx, gy) - centre
			var w := maxf(0.0, 1.0 - absf(d.x) / 64.0) * maxf(0.0, 1.0 - absf(d.y) / 64.0)
			if w <= 0.0:
				continue
			var cle := Vector2i(i, j)
			if not _cellules.has(cle):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(cle) ^ 0x5a17
				_cellules[cle] = [Vector2(rng.randf_range(DON.position.x + 30, DON.end.x - 30), rng.randf_range(DON.position.y + 30, DON.end.y - 30)), rng.randf() < 0.5]
			var cel: Array = _cellules[cle]
			var dd := d
			if cel[1]:
				dd.x = -dd.x
			var s: Vector2 = cel[0] + dd
			var sx := _reflet(int(s.x), DON.position.x, DON.end.x - 1)
			var sy := _reflet(int(s.y), DON.position.y, DON.end.y - 1)
			w = w * w * w * w
			somme += img.get_pixel(sx, sy) * w
			poids += w
	return somme / poids

func _reflet(v: int, a: int, b: int) -> int:
	var n := b - a
	var u := posmod(v - a, 2 * n)
	return a + (u if u <= n else 2 * n - u)

## Colonne du poteau droit de la potence (x 300-352) : texture du poteau prise au-dessus (y 250-362) et répétée.
func _poteau(img: Image, gx: int, gy: int) -> Color:
	var periode := 104
	var dy := (gy - 362) % periode
	var a := img.get_pixel(gx, 258 + dy)
	var b := img.get_pixel(gx, 258 + (dy + periode / 2) % periode)
	var t := absf(float(dy) / periode * 2.0 - 1.0) # fondu entre deux copies décalées : pas de couture
	var c := a.lerp(b, smoothstep(0.3, 0.7, t))
	return c.darkened(clampf((gy - 362) / 900.0, 0.0, 0.3))

func _distance_bord(x: int, y: int, m: PackedFloat32Array, zw: int, zh: int) -> float:
	# distance approchée (pas de 4 px) au pixel connu le plus proche dans les 4 directions
	var d := 0.0
	var best := 999.0
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		d = 0.0
		var px := x; var py := y
		while px >= 0 and px < zw and py >= 0 and py < zh and m[py * zw + px] > 0.5 and d < best:
			px += dir.x * 4; py += dir.y * 4; d += 4.0
		best = minf(best, d)
	return best

func _eteindre_lueur_bleue(img: Image, r: Rect2i, m: PackedFloat32Array, zone: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			var exces := c.b - maxf(c.r, c.g) * 1.15
			if exces > 0.05 and c.s > 0.45:
				var gris := (c.r + c.g) * 0.5
				img.set_pixel(x, y, Color(c.r, c.g, lerpf(c.b, maxf(gris * 1.25, c.g), clampf(exces * 3.0, 0.0, 0.85))))

## Masque du logo (pixels argentés, contours, lignes fines et cristal), en coordonnées source, valeurs 0..1 adoucies.
func _masque_logo_source(img: Image) -> PackedFloat32Array:
	var m := PackedFloat32Array(); m.resize(SW * SH)
	var zone := Rect2i(492, 10, 720, 290)
	var lum := PackedFloat32Array(); lum.resize(SW * SH)
	for y in SH:
		for x in SW:
			lum[y * SW + x] = img.get_pixel(x, y).get_luminance()
	var bas := _flou(lum, SW, SH, 10)
	# 1) cœur : métal clair peu saturé, filets fins, cristal
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var i := y * SW + x
			var c := img.get_pixel(x, y)
			var v := 0.0
			if x > 1000 and y > 242:
				continue # neige des montagnes sous le M : pas du logo
			if c.s < 0.28 and lum[i] > 0.5:
				v = 1.0
			if lum[i] - bas[i] > 0.1 and c.s < 0.3 and lum[i] > 0.33:
				v = 1.0
			if c.b > 0.45 and c.b - c.r > 0.2 and c.s > 0.45:
				v = 1.0
			m[i] = v
	# grains isolés (flocons peints, bords de nuages) retirés
	var f := _flou(m, SW, SH, 2)
	for i in m.size():
		m[i] = 1.0 if f[i] > 0.12 else 0.0
	# 2) enveloppe : élargie de ~16 px (avale l'ombre portée sombre du logo), puis fermée (intérieurs des lettres)
	f = _flou(m, SW, SH, 5)
	for i in m.size():
		m[i] = 1.0 if f[i] > 0.03 else 0.0
	f = _flou(m, SW, SH, 5)
	for i in m.size():
		m[i] = 1.0 if f[i] > 0.6 else 0.0
	_boucher_trous(m, zone)
	var e := _flou(m, SW, SH, 4)
	for i in m.size():
		m[i] = clampf(e[i] * 2.0, 0.0, 1.0)
	return m

func _masque_cristal_source(img: Image) -> PackedFloat32Array:
	var m := PackedFloat32Array(); m.resize(SW * SH)
	for y in range(90, 215):
		for x in range(790, 890):
			var c := img.get_pixel(x, y)
			if c.b > 0.4 and c.b - c.r > 0.15 and c.s > 0.35:
				m[y * SW + x] = clampf((c.s - 0.35) * 4.0, 0.0, 1.0) * clampf((c.b - 0.4) * 4.0, 0.0, 1.0)
	return _flou(m, SW, SH, 1)

## Bouchage du logo : membrane lisse (dégradé du ciel pris aux bords) + nuages de bruit fractal teintés par la membrane.
func _boucher_logo(img: Image, m_logo: PackedFloat32Array) -> void:
	var zone := Rect2i(440, 0, 820, 340)
	var zw := zone.size.x; var zh := zone.size.y
	var m := PackedFloat32Array(); m.resize(zw * zh)
	for y in zh:
		for x in zw:
			m[y * zw + x] = 1.0 if m_logo[(zone.position.y + y) * SW + zone.position.x + x] > 0.02 else 0.0
	var sous := img.get_region(zone)
	var lisse := _pousser_tirer(sous, m)
	var lisse2 := _passe_bas(lisse, 8)
	var nuages := FastNoiseLite.new()
	nuages.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nuages.frequency = 0.006
	nuages.fractal_octaves = 5
	nuages.fractal_gain = 0.55
	nuages.seed = 7
	for y in zh:
		for x in zw:
			var k := m_logo[(zone.position.y + y) * SW + zone.position.x + x]
			if k <= 0.0:
				continue
			var l := lisse2.get_pixel(x, y)
			# nuages étirés horizontalement ; plus contrastés en haut (masses sombres), plus doux vers le couchant
			var n := nuages.get_noise_2d(x * 0.55, y * 1.25)
			var haut := clampf(1.0 - y / 300.0, 0.25, 1.0)
			var g := 1.0 + n * 0.55 * haut
			var c := Color(l.r * g, l.g * g, l.b * (1.0 + n * 0.4 * haut))
			# liseré clair des nuages (lumière du couchant par en dessous)
			var bord := clampf((n - 0.15) * 4.0, 0.0, 1.0) * (1.0 - clampf((n - 0.35) * 4.0, 0.0, 1.0))
			c = c.lerp(Color(0.62, 0.48, 0.55), bord * 0.18 * (1.0 - haut * 0.5))
			var gx := zone.position.x + x; var gy := zone.position.y + y
			img.set_pixel(gx, gy, img.get_pixel(gx, gy).lerp(c, k))

## Agrandissement 1672×941 → 1920×1080 : Lanczos puis renforcement de netteté léger (masque flou, rayon ~1 px).
func _agrandir(img: Image) -> Image:
	var g := img.duplicate() as Image
	g.resize(W, H, Image.INTERPOLATE_LANCZOS)
	var d := g.get_data().to_float32_array()
	var o := d.duplicate()
	var quantite := 0.55
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := (y * W + x) * 3
			for c in 3:
				var centre := d[i + c]
				var voisins := (d[i + c - 3] + d[i + c + 3] + d[i + c - W * 3] + d[i + c + W * 3]) * 0.125 \
					+ (d[i + c - 3 - W * 3] + d[i + c + 3 - W * 3] + d[i + c - 3 + W * 3] + d[i + c + 3 + W * 3]) * 0.0625
				var flou := centre * 0.25 + voisins
				var delta := centre - flou
				# seuil : on ne renforce pas le grain fin de compression (évite le bruit)
				if absf(delta) < 0.004:
					delta = 0.0
				o[i + c] = clampf(centre + delta * quantite, 0.0, 1.0)
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBF, o.to_byte_array())

func _agrandir_masque(m: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var im := _image_gris(m, SW, SH)
	im.resize(w, h, Image.INTERPOLATE_CUBIC)
	var o := PackedFloat32Array(); o.resize(w * h)
	var d := im.get_data().to_float32_array()
	for i in w * h:
		o[i] = clampf(d[i], 0.0, 1.0)
	return o

# =====================================================================================================
# Masques d'animation (960×540)
# =====================================================================================================

func _fabriquer_masques() -> void:
	var fond := Image.load_from_file(ProjectSettings.globalize_path(DOSSIER + "fond_sans_logo.png"))
	fond.convert(Image.FORMAT_RGBF)
	fond.resize(MW, MH, Image.INTERPOLATE_LANCZOS)
	var k := float(MW) / SW # source → masque
	var n := MW * MH
	var lac := PackedFloat32Array(); lac.resize(n)
	var lum_chaude := PackedFloat32Array(); lum_chaude.resize(n)
	var runes := PackedFloat32Array(); runes.resize(n)
	var cascade := PackedFloat32Array(); cascade.resize(n)
	var reflets := PackedFloat32Array(); reflets.resize(n)
	# zones dessinées à la main (coordonnées source)
	var z_lac := _poly([Vector2(818, 698), Vector2(1000, 692), Vector2(1110, 700), Vector2(1236, 704), Vector2(1298, 718),
		Vector2(1300, 812), Vector2(1250, 845), Vector2(1190, 885), Vector2(1100, 905), Vector2(990, 900), Vector2(900, 880),
		Vector2(840, 858), Vector2(812, 800)], k, 2)
	var z_bateaux := _poly([Vector2(1106, 718), Vector2(1302, 716), Vector2(1302, 818), Vector2(1160, 818), Vector2(1112, 780)], k, 0)
	var z_barques := _poly([Vector2(1012, 724), Vector2(1112, 722), Vector2(1112, 768), Vector2(1012, 768)], k, 0)
	var z_cascade := _poly([Vector2(1238, 474), Vector2(1310, 470), Vector2(1314, 570), Vector2(1240, 572)], k, 1)
	var z_cascade2 := _poly([Vector2(1306, 322), Vector2(1396, 322), Vector2(1396, 398), Vector2(1306, 398)], k, 1)
	var z_ciel := _horizon_ciel(k)
	var z_runes := _poly_union([
		[Vector2(1250, 40), Vector2(1450, 40), Vector2(1450, 310), Vector2(1250, 310)], # château
		[Vector2(10, 690), Vector2(180, 690), Vector2(180, 941), Vector2(10, 941)], # menhir gauche
		[Vector2(360, 800), Vector2(440, 800), Vector2(440, 900), Vector2(360, 900)], # menhir du milieu
	], k)
	# flammes vives (vacillement fort) : lanternes, brasero, lanternes du port
	var z_flammes := _poly_union([
		[Vector2(352, 140), Vector2(430, 140), Vector2(430, 280), Vector2(352, 280)],
		[Vector2(1570, 550), Vector2(1645, 550), Vector2(1645, 665), Vector2(1570, 665)],
		[Vector2(470, 720), Vector2(575, 720), Vector2(575, 810), Vector2(470, 810)],
	], k)
	# montagnes éclairées par le couchant : orangées mais ce ne sont pas des lumières
	var z_monts := _poly_union([
		[Vector2(430, 200), Vector2(1240, 200), Vector2(1240, 345), Vector2(430, 345)],
		[Vector2(1236, 0), Vector2(1672, 0), Vector2(1672, 60), Vector2(1450, 60), Vector2(1450, 200), Vector2(1236, 200)],
	], k)
	for y in MH:
		for x in MW:
			var i := y * MW + x
			var c := fond.get_pixel(x, y)
			var l := c.get_luminance()
			# --- lac : pixels d'eau (bleus sombres) ou reflets chauds, hors bois sombre (poteaux, coques)
			var zl := z_lac[i] * (1.0 - z_bateaux[i]) * (1.0 - z_barques[i])
			if zl > 0.0:
				var eau := 0.0
				if c.b >= c.r * 0.92:
					eau = 1.0
				elif l > 0.3:
					eau = 0.9
				elif l < 0.12:
					eau = 0.35
				lac[i] = zl * eau
				if l > 0.3 and c.r > c.b:
					reflets[i] = zl * clampf((l - 0.3) * 3.0, 0.0, 1.0)
			# --- lumières chaudes : orangé/jaune vif, hors ciel (coucher de soleil)
			var chaud := (c.h < 0.17 or c.h > 0.97) and c.v > 0.42 and c.s > 0.3
			if chaud and z_ciel[i] < 0.5 and z_monts[i] < 0.5:
				var v := smoothstep(0.42, 0.85, c.v) * smoothstep(0.3, 0.65, c.s)
				lum_chaude[i] = v * lerpf(0.45, 1.0, z_flammes[i])
			# --- runes : bleu saturé et lumineux
			if z_runes[i] > 0.0 and c.b > 0.45 and c.s > 0.5 and c.b > c.g * 1.05:
				runes[i] = z_runes[i] * clampf((c.s - 0.5) * 4.0, 0.0, 1.0) * clampf((c.b - 0.45) * 3.0, 0.0, 1.0)
			# --- cascade : eau claire dans la zone de la chute
			var zc := maxf(z_cascade[i], z_cascade2[i] * 0.7)
			if zc > 0.0 and l > 0.32 and c.s < 0.4:
				cascade[i] = zc * clampf((l - 0.32) * 4.0, 0.0, 1.0)
	lac = _flou(lac, MW, MH, 1)
	cascade = _flou(cascade, MW, MH, 1)
	var halo := _flou(lum_chaude, MW, MH, 9)
	var halo2 := _flou(lum_chaude, MW, MH, 22)
	for i in n:
		halo[i] = clampf(halo[i] * 2.5 + halo2[i] * 3.0, 0.0, 1.0)
	var halo_runes := _flou(runes, MW, MH, 7)
	for i in n:
		halo_runes[i] = clampf(halo_runes[i] * 3.0, 0.0, 1.0)
	# --- profondeur (0 ciel → 1 premier plan), adoucie puis recalée sur les contours de l'image (filtre guidé)
	var prof := _profondeur(k)
	var guide := PackedFloat32Array(); guide.resize(n)
	for i in n:
		guide[i] = fond.get_pixel(i % MW, i / MW).get_luminance()
	prof = _filtre_guide(guide, _flou(prof, MW, MH, 2), MW, MH, 5, 0.002)
	# --- sapins : cimes seulement (poids croissant vers le sommet)
	var sapins := PackedFloat32Array(); sapins.resize(n)
	var cimes := [
		[Vector2(508, 275), 300.0, 70.0], # grand sapin à droite du menu
		[Vector2(1458, 202), 420.0, 120.0], # grand sapin devant le château
		[Vector2(1588, 84), 330.0, 95.0], # sapin tout à droite
	]
	for cm in cimes:
		var sommet: Vector2 = cm[0] * k
		var haut: float = cm[1] * k
		var demi: float = cm[2] * k
		for y in range(int(sommet.y), mini(MH, int(sommet.y + haut))):
			var t := (y - sommet.y) / haut
			var larg := demi * (0.25 + 0.75 * t)
			for x in range(maxi(0, int(sommet.x - larg)), mini(MW, int(sommet.x + larg))):
				var bord := 1.0 - absf(x - sommet.x) / larg
				sapins[y * MW + x] = maxf(sapins[y * MW + x], (1.0 - t) * smoothstep(0.0, 0.4, bord))
	sapins = _flou(sapins, MW, MH, 3)
	# --- ciel (nuages) : sous l'horizon on coupe, et pas trop près des silhouettes
	var ciel := _flou(z_ciel, MW, MH, 4)
	for i in n:
		ciel[i] = smoothstep(0.55, 1.0, ciel[i])
	# --- brume : nappes dans la vallée, au pied du château, sur le lac
	var brume := _poly_union([
		[Vector2(560, 450), Vector2(1010, 440), Vector2(1010, 535), Vector2(560, 540)],
		[Vector2(640, 600), Vector2(1240, 590), Vector2(1240, 715), Vector2(640, 720)],
		[Vector2(1180, 540), Vector2(1400, 540), Vector2(1400, 665), Vector2(1180, 665)],
		[Vector2(470, 352), Vector2(1000, 345), Vector2(1000, 410), Vector2(470, 420)],
	], k)
	brume = _flou(brume, MW, MH, 18)
	# --- logo élargi (pour ne pas faire bouger le ciel sous le logo peint)
	var logo_l := PackedFloat32Array(); logo_l.resize(n)
	var ml_img := Image.load_from_file(ProjectSettings.globalize_path(DOSSIER + "masque_logo.png"))
	ml_img.convert(Image.FORMAT_RF)
	ml_img.resize(MW, MH, Image.INTERPOLATE_BILINEAR)
	var mld := ml_img.get_data().to_float32_array()
	for i in n:
		logo_l[i] = mld[i]
	logo_l = _flou(logo_l, MW, MH, 10)
	for i in n:
		logo_l[i] = clampf(logo_l[i] * 4.0, 0.0, 1.0)
	_sauver_rgba(lac, lum_chaude, runes, cascade, "masques_a.png")
	_sauver_rgba(prof, sapins, halo, ciel, "masques_b.png")
	_sauver_rgba(brume, halo_runes, logo_l, reflets, "masques_c.png")

## Ciel : 1 au-dessus de la ligne d'horizon (crêtes des montagnes, château), en coordonnées masque.
func _horizon_ciel(k: float) -> PackedFloat32Array:
	var crete := [Vector2(0, 0), Vector2(430, 0), Vector2(430, 236), Vector2(470, 262), Vector2(520, 292), Vector2(580, 318),
		Vector2(660, 326), Vector2(756, 342), Vector2(805, 336), Vector2(852, 326), Vector2(916, 300), Vector2(980, 272),
		Vector2(1020, 248), Vector2(1060, 262), Vector2(1110, 238), Vector2(1125, 236), Vector2(1168, 240), Vector2(1216, 252),
		Vector2(1236, 150), Vector2(1240, 0)]
	return _poly(crete, k, 0)

## Profondeur par zones (coordonnées source) ; les zones dessinées ensuite recouvrent les précédentes.
func _profondeur(k: float) -> PackedFloat32Array:
	var n := MW * MH
	var p := PackedFloat32Array(); p.resize(n)
	var ciel := _horizon_ciel(k)
	for i in n:
		p[i] = 0.12 if ciel[i] > 0.5 else 0.22 # ciel / montagnes lointaines
	var zones := [
		[0.32, [Vector2(1236, 0), Vector2(1672, 0), Vector2(1672, 520), Vector2(1236, 520)]], # château, montagnes de droite
		[0.42, [Vector2(450, 380), Vector2(1040, 330), Vector2(1048, 224), Vector2(1236, 224), Vector2(1240, 640), Vector2(450, 650)]], # village, falaise
		[0.5, [Vector2(600, 550), Vector2(1310, 560), Vector2(1310, 910), Vector2(600, 910)]], # pont, lac, barques
		[0.5, [Vector2(120, 360), Vector2(445, 360), Vector2(445, 700), Vector2(120, 700)]], # derrière le menu (bouché)
		[0.68, [Vector2(470, 270), Vector2(545, 270), Vector2(590, 720), Vector2(430, 720)]], # grand sapin à droite du menu
		[0.75, [Vector2(1300, 200), Vector2(1530, 200), Vector2(1530, 800), Vector2(1300, 800)]], # grand sapin devant le château
		[0.85, [Vector2(1530, 80), Vector2(1672, 80), Vector2(1672, 400), Vector2(1530, 480)]], # sapin de droite
		[1.0, [Vector2(1425, 537), Vector2(1672, 346), Vector2(1672, 941), Vector2(1425, 941)]], # cabane
		[1.0, [Vector2(1300, 728), Vector2(1560, 728), Vector2(1560, 941), Vector2(1300, 941)]], # tonneaux
		[1.0, [Vector2(0, 0), Vector2(108, 0), Vector2(108, 470), Vector2(132, 600), Vector2(180, 660), Vector2(180, 941), Vector2(0, 941)]],
		[1.0, [Vector2(95, 18), Vector2(440, 78), Vector2(440, 126), Vector2(95, 84)]], # poutre
		[1.0, [Vector2(112, 60), Vector2(310, 60), Vector2(310, 372), Vector2(112, 372)]], # bannière
		[1.0, [Vector2(298, 84), Vector2(356, 84), Vector2(356, 790), Vector2(298, 790)]], # poteau droit
		[1.0, [Vector2(350, 92), Vector2(432, 92), Vector2(432, 284), Vector2(350, 284)]], # lanterne
		[0.92, [Vector2(408, 640), Vector2(712, 640), Vector2(712, 812), Vector2(408, 812)]], # appentis du brasero
		[1.0, [Vector2(0, 700), Vector2(410, 700), Vector2(410, 735), Vector2(700, 790), Vector2(860, 860), Vector2(1300, 900),
			Vector2(1672, 900), Vector2(1672, 941), Vector2(0, 941)]], # rochers, menhirs, neige du bas
		[0.85, [Vector2(670, 715), Vector2(845, 715), Vector2(860, 880), Vector2(670, 880)]], # chemin et barrière
	]
	for z in zones:
		var v: float = z[0]
		var m := _poly(z[1], k, 0)
		for i in n:
			if m[i] > 0.5:
				p[i] = v
	return p

# =====================================================================================================
# Petites textures : bruit, flocons, fumée
# =====================================================================================================

func _fabriquer_petites() -> void:
	var T := 256
	var bruits: Array = []
	var reglages := [[0.012, 4, 11], [0.03, 3, 23], [0.06, 2, 37], [0.02, 5, 51]]
	for r in reglages:
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.frequency = r[0]
		nz.fractal_octaves = r[1]
		nz.seed = r[2]
		var im := nz.get_seamless_image(T, T, false, false, 0.1, true)
		im.convert(Image.FORMAT_L8)
		bruits.append(im)
	var b := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			b.set_pixel(x, y, Color((bruits[0] as Image).get_pixel(x, y).r, (bruits[1] as Image).get_pixel(x, y).r,
				(bruits[2] as Image).get_pixel(x, y).r, (bruits[3] as Image).get_pixel(x, y).r))
	b.save_png(ProjectSettings.globalize_path(DOSSIER + "bruit.png"))
	_disque("flocon.png", 32, 0.32, 0.55)
	_disque("flocon_flou.png", 64, 0.1, 0.95)
	# fumée : tache douce irrégulière
	var F := 64
	var nz2 := FastNoiseLite.new()
	nz2.frequency = 0.09
	nz2.fractal_octaves = 3
	var f := Image.create(F, F, false, Image.FORMAT_RGBA8)
	for y in F:
		for x in F:
			var d := Vector2(x - F / 2.0 + 0.5, y - F / 2.0 + 0.5).length() / (F / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * (nz2.get_noise_2d(x, y) * 0.5 + 0.5))
			f.set_pixel(x, y, Color(1, 1, 1, a))
	f.save_png(ProjectSettings.globalize_path(DOSSIER + "fumee.png"))

func _disque(nom: String, T: int, coeur: float, bord: float) -> void:
	var im := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var d := Vector2(x - T / 2.0 + 0.5, y - T / 2.0 + 0.5).length() / (T / 2.0)
			var a := 1.0 - smoothstep(coeur, bord, d)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	im.save_png(ProjectSettings.globalize_path(DOSSIER + nom))

# =====================================================================================================
# Outils d'image
# =====================================================================================================

## Remplissage « pousser-tirer » : moyenne pondérée multi-échelle des pixels connus (m < 0.5) vers les inconnus (m ≥ 0.5).
func _pousser_tirer(img: Image, m: PackedFloat32Array) -> Image:
	var w := img.get_width(); var h := img.get_height()
	var niveaux: Array = []
	var cur := Image.create(w, h, false, Image.FORMAT_RGBAF)
	for y in h:
		for x in w:
			var k := 1.0 - m[y * w + x]
			var c := img.get_pixel(x, y)
			cur.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, k))
	niveaux.append(cur)
	while cur.get_width() > 2 and cur.get_height() > 2:
		var nxt := cur.duplicate() as Image
		nxt.resize(maxi(1, cur.get_width() / 2), maxi(1, cur.get_height() / 2), Image.INTERPOLATE_BILINEAR)
		niveaux.append(nxt)
		cur = nxt
	# remontée
	var plein := niveaux[niveaux.size() - 1] as Image
	_normaliser(plein)
	for li in range(niveaux.size() - 2, -1, -1):
		var fin := niveaux[li] as Image
		var up := plein.duplicate() as Image
		up.resize(fin.get_width(), fin.get_height(), Image.INTERPOLATE_BILINEAR)
		var d := fin.get_data().to_float32_array()
		var u := up.get_data().to_float32_array()
		for i in range(0, d.size(), 4):
			var a := clampf(d[i + 3], 0.0, 1.0)
			if d[i + 3] > 1.0:
				d[i] /= d[i + 3]; d[i + 1] /= d[i + 3]; d[i + 2] /= d[i + 3]
			d[i] = d[i] + (1.0 - a) * u[i]
			d[i + 1] = d[i + 1] + (1.0 - a) * u[i + 1]
			d[i + 2] = d[i + 2] + (1.0 - a) * u[i + 2]
			d[i + 3] = 1.0
		plein = Image.create_from_data(fin.get_width(), fin.get_height(), false, Image.FORMAT_RGBAF, d.to_byte_array())
	plein.convert(Image.FORMAT_RGBF)
	return plein

func _normaliser(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.0001:
				im.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, 1.0))

## Passe-bas approché : réduction puis agrandissement bicubique (facteur = rayon approximatif en px).
func _passe_bas(img: Image, rayon: int) -> Image:
	var b := img.duplicate() as Image
	b.resize(maxi(1, img.get_width() / rayon), maxi(1, img.get_height() / rayon), Image.INTERPOLATE_BILINEAR)
	b.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_CUBIC)
	return b

## Flou de boîte séparable répété 3 fois (≈ gaussien) sur un tableau de flottants.
func _flou(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	if r <= 0:
		return src.duplicate()
	var a := src.duplicate()
	var b := PackedFloat32Array(); b.resize(w * h)
	for _passe in 3:
		_boite_h(a, b, w, h, r)
		_boite_v(b, a, w, h, r)
	return a

func _boite_h(s: PackedFloat32Array, d: PackedFloat32Array, w: int, h: int, r: int) -> void:
	var inv := 1.0 / (2 * r + 1)
	for y in h:
		var o := y * w
		var acc := 0.0
		for x in range(-r, r + 1):
			acc += s[o + clampi(x, 0, w - 1)]
		for x in w:
			d[o + x] = acc * inv
			acc += s[o + mini(x + r + 1, w - 1)] - s[o + maxi(x - r, 0)]

func _boite_v(s: PackedFloat32Array, d: PackedFloat32Array, w: int, h: int, r: int) -> void:
	var inv := 1.0 / (2 * r + 1)
	for x in w:
		var acc := 0.0
		for y in range(-r, r + 1):
			acc += s[clampi(y, 0, h - 1) * w + x]
		for y in h:
			d[y * w + x] = acc * inv
			acc += s[mini(y + r + 1, h - 1) * w + x] - s[maxi(y - r, 0) * w + x]

## Filtre guidé (He et al.) : recale le masque p sur les contours de l'image guide I.
func _filtre_guide(I: PackedFloat32Array, p: PackedFloat32Array, w: int, h: int, r: int, eps: float) -> PackedFloat32Array:
	var n := w * h
	var Ip := PackedFloat32Array(); Ip.resize(n)
	var II := PackedFloat32Array(); II.resize(n)
	for i in n:
		Ip[i] = I[i] * p[i]
		II[i] = I[i] * I[i]
	var mI := _boite(I, w, h, r); var mp := _boite(p, w, h, r)
	var mIp := _boite(Ip, w, h, r); var mII := _boite(II, w, h, r)
	var a := PackedFloat32Array(); a.resize(n)
	var b := PackedFloat32Array(); b.resize(n)
	for i in n:
		var cov := mIp[i] - mI[i] * mp[i]
		var v := mII[i] - mI[i] * mI[i]
		a[i] = cov / (v + eps)
		b[i] = mp[i] - a[i] * mI[i]
	var ma := _boite(a, w, h, r); var mb := _boite(b, w, h, r)
	var q := PackedFloat32Array(); q.resize(n)
	for i in n:
		q[i] = clampf(ma[i] * I[i] + mb[i], 0.0, 1.0)
	return q

func _boite(s: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var t := PackedFloat32Array(); t.resize(w * h)
	var o := PackedFloat32Array(); o.resize(w * h)
	_boite_h(s, t, w, h, r)
	_boite_v(t, o, w, h, r)
	return o

## Polygone (coordonnées source) rastérisé à la taille des masques, flouté de `flou` px.
func _poly(pts: Array, k: float, flou: int) -> PackedFloat32Array:
	var m := PackedFloat32Array(); m.resize(MW * MH)
	var pp := PackedVector2Array()
	for p in pts:
		pp.append((p as Vector2) * k)
	var bb := Rect2(pp[0], Vector2.ZERO)
	for p in pp:
		bb = bb.expand(p)
	for y in range(maxi(0, int(bb.position.y) - 1), mini(MH, int(bb.end.y) + 2)):
		for x in range(maxi(0, int(bb.position.x) - 1), mini(MW, int(bb.end.x) + 2)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pp):
				m[y * MW + x] = 1.0
	return _flou(m, MW, MH, flou) if flou > 0 else m

func _poly_union(liste: Array, k: float) -> PackedFloat32Array:
	var m := PackedFloat32Array(); m.resize(MW * MH)
	for pts in liste:
		var p := _poly(pts, k, 0)
		for i in m.size():
			m[i] = maxf(m[i], p[i])
	return m

func _rect_ech(r: Rect2, k: float) -> Rect2:
	return Rect2((r.position * k).floor(), (r.size * k).ceil())

func _image_gris(m: PackedFloat32Array, w: int, h: int) -> Image:
	return Image.create_from_data(w, h, false, Image.FORMAT_RF, m.to_byte_array())

func _sauver_rgb(img: Image, nom: String) -> void:
	var c := img.duplicate() as Image
	c.convert(Image.FORMAT_RGB8)
	c.save_png(ProjectSettings.globalize_path(DOSSIER + nom))

func _sauver_gris(m: PackedFloat32Array, w: int, h: int, nom: String) -> void:
	var im := _image_gris(m, w, h)
	im.convert(Image.FORMAT_L8)
	im.save_png(ProjectSettings.globalize_path(DOSSIER + nom))

func _sauver_rgba(r: PackedFloat32Array, g: PackedFloat32Array, b: PackedFloat32Array, a: PackedFloat32Array, nom: String) -> void:
	var im := Image.create(MW, MH, false, Image.FORMAT_RGBA8)
	var d := PackedByteArray(); d.resize(MW * MH * 4)
	for i in MW * MH:
		d[i * 4] = int(clampf(r[i], 0.0, 1.0) * 255.0 + 0.5)
		d[i * 4 + 1] = int(clampf(g[i], 0.0, 1.0) * 255.0 + 0.5)
		d[i * 4 + 2] = int(clampf(b[i], 0.0, 1.0) * 255.0 + 0.5)
		d[i * 4 + 3] = int(clampf(a[i], 0.0, 1.0) * 255.0 + 0.5)
	im.set_data(MW, MH, false, Image.FORMAT_RGBA8, d)
	im.save_png(ProjectSettings.globalize_path(DOSSIER + nom))

## Remplit les trous fermés d'un masque binaire (intérieur des O, des R…) : tout ce que l'extérieur de la zone n'atteint pas.
func _boucher_trous(m: PackedFloat32Array, zone: Rect2i) -> void:
	var z := zone.grow(4)
	var vu := PackedByteArray(); vu.resize(SW * SH)
	var pile: Array[int] = []
	for x in range(z.position.x, z.end.x):
		pile.append(z.position.y * SW + x); pile.append((z.end.y - 1) * SW + x)
	for y in range(z.position.y, z.end.y):
		pile.append(y * SW + z.position.x); pile.append(y * SW + z.end.x - 1)
	while not pile.is_empty():
		var i: int = pile.pop_back()
		if vu[i] == 1 or m[i] > 0.5:
			continue
		vu[i] = 1
		var x := i % SW; var y := i / SW
		if x > z.position.x: pile.append(i - 1)
		if x < z.end.x - 1: pile.append(i + 1)
		if y > z.position.y: pile.append(i - SW)
		if y < z.end.y - 1: pile.append(i + SW)
	for y in range(z.position.y, z.end.y):
		for x in range(z.position.x, z.end.x):
			var i := y * SW + x
			if vu[i] == 0:
				m[i] = 1.0
