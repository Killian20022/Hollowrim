extends RefCounted
## Mesure du « pâté noir » du rayon noir (v4) : compare deux images du MÊME instant, rayon masqué / rayon visible (la main, le décor
## et les lumières sont identiques ; seul le nœud RayonNoir change). Sortie : part de l'écran où le rayon est PLUS SOMBRE que le fond.

static func lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

## Luminance moyenne par blocs de 2 x 2 px (images prises à temps GELÉ : aucun bruit d'image à image, plancher mesuré = 0).
static func blocs(im: Image) -> PackedFloat32Array:
	var w := im.get_width() / 2
	var h := im.get_height() / 2
	var res := PackedFloat32Array()
	res.resize(w * h)
	for by in h:
		for bx in w:
			var t := 0.0
			for y in 2:
				for x in 2:
					t += lum(im.get_pixel(bx * 2 + x, by * 2 + y))
			res[by * w + bx] = t / 4.0
	return res

## {sombre: % de l'écran (blocs de 2 px) plus sombre que le fond de plus de `eps`, tres_sombre: idem de plus de 0,5 × le fond,
##  clair: % plus clair, couvert: % modifié, bruit: % « plus sombre » mesuré entre deux images SANS rayon (plancher de la mesure)}.
static func comparer(sans: Image, avec: Image, sans2: Image = null, eps := 0.012) -> Dictionary:
	var a := blocs(sans)
	var b := blocs(avec)
	var n := a.size()
	var sombre := 0
	var tres := 0
	var clair := 0
	var touche := 0
	for i in n:
		var d := b[i] - a[i]
		if absf(d) > eps:
			touche += 1
		if d < -eps:
			sombre += 1
			if b[i] < a[i] * 0.5:
				tres += 1
		elif d > eps:
			clair += 1
	var bruit := 0.0
	if sans2 != null:
		var c := blocs(sans2)
		var nb := 0
		for i in n:
			if c[i] - a[i] < -eps:
				nb += 1
		bruit = 100.0 * nb / n
	return {"sombre": 100.0 * sombre / n, "tres_sombre": 100.0 * tres / n, "clair": 100.0 * clair / n, "couvert": 100.0 * touche / n, "bruit": bruit}

## Masque (ou rend) TOUS les visuels de la magie (calque CoucheMagie.CALQUE : rayon, cercle, noyau de la main, fumée, runes…) : la même
## image, sans l'effet. Le décor, les mains, les ennemis et les lumières ne changent pas.
static var _masques: Array = []

static func masquer(vu: bool, racine: Node = null) -> void:
	if vu:
		for e in _masques:
			if is_instance_valid(e[0]):
				(e[0] as VisualInstance3D).layers = e[1]
		_masques.clear()
		return
	var pile: Array = [racine]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n is VisualInstance3D and (((n as VisualInstance3D).layers & CoucheMagie.CALQUE) != 0):
			_masques.append([n, (n as VisualInstance3D).layers])
			(n as VisualInstance3D).layers &= ~CoucheMagie.CALQUE
		pile.append_array(n.get_children())

const INSTANTS := [0.017, 0.05, 0.083, 0.117, 0.15, 0.2, 0.3, 0.5, 1.0, 2.0]

## Déclenche le rayon (main gauche) et mesure à chaque instant ; `f` : le script de film (SceneTree avec magie, _dossier, _attendre).
static func mesurer(f, etiq: String) -> void:
	f.magie.raccourci_sort_gauche(RayonNoir.ID)
	await f._attendre(0.4)
	f.magie.appuyer("gauche")
	var garde := 0
	while RayonNoir.par_paume.is_empty() and garde < 120:   # t = 0 : le rayon apparaît (après le temps d'incantation)
		await f.process_frame
		garde += 1
	var t := 0.0
	var pire := 0.0
	var pire_t := 0.0
	var soutenu := 0.0
	for inst: float in INSTANTS:
		while t + 0.5 / 60.0 < inst:
			await f.process_frame
			t += 1.0 / 60.0
		# le temps est GELÉ (time_scale 0) : décor, mains, nuages et rayon identiques d'une image à l'autre ; seul le rayon est masqué
		Engine.time_scale = 0.0
		for i in 3:
			await f.process_frame
		var avec: Image = f.root.get_viewport().get_texture().get_image()
		masquer(false, f.root)
		for i in 3:
			await f.process_frame
		var sans: Image = f.root.get_viewport().get_texture().get_image()
		await f.process_frame
		var sans2: Image = f.root.get_viewport().get_texture().get_image()
		masquer(true)
		Engine.time_scale = 1.0
		var r := comparer(sans, avec, sans2)
		print("MESURE %s t=%.3f sombre=%.2f%% tres_sombre=%.2f%% clair=%.1f%% couvert=%.1f%% bruit=%.2f%%" % [etiq, inst, r.sombre, r.tres_sombre, r.clair, r.couvert, r.bruit])
		if float(r.sombre) > pire:
			pire = float(r.sombre)
			pire_t = inst
		if inst >= 0.5:
			soutenu = maxf(soutenu, float(r.sombre))
		if f._dossier != "":
			avec.save_png(f._dossier.path_join("%s_%03d_avec.png" % [etiq, int(inst * 1000)]))
			sans.save_png(f._dossier.path_join("%s_%03d_sans.png" % [etiq, int(inst * 1000)]))
	print("MESURE_BILAN %s pire=%.2f%% (t=%.3f) soutenu=%.2f%%" % [etiq, pire, pire_t, soutenu])
	f.magie.relacher("gauche")
	await f._attendre(0.4)

# ------------------------------------------------------------------ film (60 images/s : le déclenchement se ralentit au montage)

static func att(f, sec: float) -> void:
	for i in maxi(1, roundi(sec * 60.0)):
		f.j.vie = f.j.vie_max
		await f.process_frame

## Tourne la tête vers `p` en `sec` s (lissé), à 60 images/s.
static func regarder(f, p: Vector3, sec: float) -> void:
	var n := maxi(1, roundi(sec * 60.0))
	var y0: float = f.j.rotation.y
	var x0: float = f.j.tete.rotation.x
	var o: Vector3 = f.j.camera.global_position
	var d := p - o
	var y1 := atan2(-d.x, -d.z)
	var x1 := atan2(d.y, Vector2(d.x, d.z).length())
	for k in n:
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		f.j.rotation.y = lerp_angle(y0, y1, u)
		f.j.tete.rotation.x = lerpf(x0, x1, u)
		f.j.vie = f.j.vie_max
		await f.process_frame

## Film 1re personne : repos, DÉCLENCHEMENT (« DEBUT_TIR <s> » = instant de la touche, pour le ralenti), tenu, balayage, relâchement.
## `points` : trois points à viser (départ, puis deux balayages).
static func film(f, points: Array) -> void:
	f.magie.raccourci_sort_gauche(RayonNoir.ID)
	await regarder(f, points[0], 0.5)
	await att(f, 0.6)
	print("DEBUT_TIR %.3f" % (Engine.get_process_frames() / 60.0))
	f.magie.appuyer("gauche")
	await att(f, 1.6)
	await regarder(f, points[1], 1.6)
	await att(f, 0.3)
	await regarder(f, points[2], 1.4)
	await att(f, 0.3)
	print("FIN_TIR %.3f" % (Engine.get_process_frames() / 60.0))
	f.magie.relacher("gauche")
	await att(f, 0.9)

# ------------------------------------------------------------------ FPS

static func _moy(l: Array) -> String:
	if l.is_empty():
		return "-"
	l.sort()
	var t := 0.0
	for v in l:
		t += float(v)
	return "moy %.0f FPS, p5 %.0f FPS (%d images)" % [1.0e6 / (t / l.size()), 1.0e6 / float(l[int(l.size() * 0.95)]), l.size()]

## FPS réels (plafond levé), même scène : repos, 1re demi-seconde après le déclenchement, rayon tenu.
static func perf(f) -> void:
	Engine.max_fps = 0
	f.magie.raccourci_sort_gauche(RayonNoir.ID)
	for i in 120:
		await f.process_frame
	var repos: Array = []
	var decl: Array = []
	var tenu: Array = []
	var t0 := Time.get_ticks_usec()
	for i in 240:
		await f.process_frame
		var t1 := Time.get_ticks_usec()
		repos.append(t1 - t0)
		t0 = t1
	f.magie.appuyer("gauche")
	var garde := 0
	while RayonNoir.par_paume.is_empty() and garde < 200:
		await f.process_frame
		garde += 1
	t0 = Time.get_ticks_usec()
	for i in 60:
		await f.process_frame
		var t1 := Time.get_ticks_usec()
		decl.append(t1 - t0)
		t0 = t1
	for i in 60:
		await f.process_frame
	t0 = Time.get_ticks_usec()
	for i in 360:
		await f.process_frame
		var t1 := Time.get_ticks_usec()
		tenu.append(t1 - t0)
		t0 = t1
	print("PERF repos : ", _moy(repos))
	print("PERF déclenchement (60 premières images) : ", _moy(decl))
	print("PERF tenu : ", _moy(tenu))
	f.magie.relacher("gauche")
