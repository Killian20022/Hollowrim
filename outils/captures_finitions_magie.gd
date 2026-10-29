extends SceneTree
## Planches image par image des FINITIONS DE MAGIE (scenes/test_magie.tscn), à bout portant ou de loin.
## FENÊTRE (via godot_slot.sh : hors écran), toujours avec --fixed-fps 60 (une vignette = une image de jeu à 60 /s) :
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_finitions_magie.gd -- \
##       --sort=<id> --planche=<fichier.png> [--cible=mannequin|draugr|vide] [--dist=1.75] [--de=0] [--pas=1] [--n=12]
##       [--tenue=1.5] [--zoom=<x,y,l,h> (zone de l'écran 0..1 agrandie)] [--masque=ic|ic<k>|gm] [--detail-sorts=…]
##     --sort : jet_flammes, arc_electrique, souffle_givre (canalisés : appui tenu --tenue s) ; eclat_glace, chaine_eclairs…
##       (rapides : appui bref). Main gauche.
##     --de / --pas / --n : vignettes à partir de l'image --de, toutes les --pas images. Image 0 = l'appui (sorts rapides) ou
##       la PREMIÈRE image de canalisation (sorts canalisés : la durée de l'incantation varie ; --de < 0 = images d'avant).
##     --cible : mannequin (devant le joueur à --dist m), draugr (draugr figé à --dist m), vide (ciel et neige).
##     --masque : mise au point. ic = particules d'ImpactCorps cachées, ic<k> = seulement l'émetteur k (0..5) des foyers,
##       gm = particules de GestionMagie cachées (ImpactCorps gardé), fine = enveloppe procédurale (gerbe_fine) cachée, nom:<a>+<b> = celles dont le chemin finit par a, b…
##   ... -- --film --sort=<id> [...] avec --write-movie <fichier.avi> : film du même scénario (1,2 s avant l'appui).

const SCENE := preload("res://scenes/test_magie.tscn")

var s: Node3D
var m: MainSort
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _go() -> void:
	var cible := _arg("cible", "mannequin")
	s = SCENE.instantiate()
	s.options = {"draugr": "fige" if cible == "draugr" else "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	m = s.magie
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	var sort := _arg("sort", "jet_flammes")
	m.equiper("droite", "epee")
	m.equiper("gauche", sort)
	var dist := float(_arg("dist", "1.75"))
	match cible:
		"draugr":
			var d: Node3D = s.draugr
			s.placer_joueur(d.global_position + Vector3(0, 0, dist), 0.0)
			# les mannequins hors du champ
			for mq in [s.mannequin, s.mannequin2, s.mannequin3]:
				(mq as Node3D).global_position += Vector3(0, -50, 0)
		"vide":
			s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 4.0)
		_:
			s.placer_joueur(Vector3(0, 0, -1.75 + dist), 0.0)
	s.joueur.mana = s.joueur.mana_max
	m.recharges.clear()
	for i in 40:
		await process_frame
	if _arg("film") != "":
		await _film(sort)
	else:
		await _planche(sort, _arg("planche", "user://planche_finitions.png"))
	quit(0)

func _canalise(sort: String) -> bool:
	var ds: Resource = load("res://data/sorts/%s.tres" % sort)
	return ds != null and int(ds.get("type")) == DonneesSort.Type.CANALISE

func _masquer() -> void:
	var mq := _arg("masque")
	if mq == "":
		return
	var ic: Node = ImpactCorps.instance
	if mq.begins_with("ic") and ic != null and is_instance_valid(ic):
		var k := int(mq.substr(2)) if mq.length() > 2 else -1
		for f in ic.foyers:
			for i in f.em.size():
				if k < 0 or i == k:
					(f.em[i].p as GPUParticles3D).visible = false
	elif mq.begins_with("nom:"):
		for n in root.find_children("*", "GPUParticles3D", true, false):
			for x in mq.substr(4).split("+"):
				if String(n.get_path()).ends_with(x) or String(n.get_path()).contains(x + "/"):
					(n as GPUParticles3D).visible = false
	elif mq == "fine":
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if n.has_meta("gerbe_fine"):
				(n as MeshInstance3D).visible = false
	elif mq == "gm":
		var gm := GestionMagie.obtenir()
		for n in gm.find_children("*", "GPUParticles3D", true, false):
			if ic == null or not ic.is_ancestor_of(n):
				(n as GPUParticles3D).visible = false

func _vignette() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var zoom := _arg("zoom")
	if zoom != "":
		var z := zoom.split(",")
		var w := img.get_width()
		var h := img.get_height()
		img = img.get_region(Rect2i(int(float(z[0]) * w), int(float(z[1]) * h), int(float(z[2]) * w), int(float(z[3]) * h)))
	img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	return img

func _planche(sort: String, fichier: String) -> void:
	var de := int(_arg("de", "0"))
	var pas := maxi(1, int(_arg("pas", "1")))
	var n := int(_arg("n", "12"))
	var tenue := int(float(_arg("tenue", "1.5")) * 60.0)
	var vignettes: Array[Image] = []
	var avant: Array = []      # sorts canalisés, --de < 0 : dernières images avant le début de la canalisation
	var f := 0                 # images depuis l'appui
	var t0 := -1               # première image « canalise » (sorts canalisés) ; 0 (l'appui) pour les autres
	m.appuyer("gauche")
	var canal := _canalise(sort)
	if not canal:
		t0 = 0
	while vignettes.size() < n and f < 600:
		if f == (t0 + tenue if canal and t0 >= 0 else 5) and (not canal or t0 >= 0):
			m.relacher("gauche")
		s.joueur.mana = s.joueur.mana_max
		_masquer()
		var inc: Incantation = m.inc["gauche"]
		if canal and t0 < 0 and inc.nom() == "canalise":
			t0 = f
			for x in avant:
				if int(x[0]) - t0 >= de and (int(x[0]) - t0 - de) % pas == 0 and vignettes.size() < n:
					vignettes.append(x[1])
		var k := f - t0 if t0 >= 0 else -1000
		l.text = "%s  image %+d (%.3f s)  %s" % [sort, k, k / 60.0, inc.nom()] if t0 >= 0 else "%s  %s" % [sort, inc.nom()]
		var veut := t0 >= 0 and k >= de and (k - de) % pas == 0
		var garde := canal and t0 < 0 and de < 0
		if veut or garde:
			await RenderingServer.frame_post_draw
			var img := _vignette()
			if veut:
				vignettes.append(img)
				_journal(k)
			else:
				avant.append([f, img])
				if avant.size() > -de:
					avant.pop_front()
		else:
			await process_frame
		f += 1
	m.relacher("gauche")
	var cols := 4
	var p := Image.create(480 * cols, 270 * ceili(vignettes.size() / float(cols)), false, Image.FORMAT_RGBA8)
	for i in vignettes.size():
		p.blit_rect(vignettes[i], Rect2i(0, 0, 480, 270), Vector2i((i % cols) * 480, (i / cols) * 270))
	p.save_png(fichier)
	print("PLANCHE ", fichier)

## Journal par vignette : particules actives d'ImpactCorps (par émetteur) et du jet.
func _journal(image: int) -> void:
	var ic: Node = ImpactCorps.instance
	var t := "IMAGE %d" % image
	if ic != null and is_instance_valid(ic):
		for f in ic.foyers:
			if not f.libre:
				var e := []
				for x in f.em:
					e.append("%d:%s%.2f" % [x.n, "+" if x.on else "-", x.ratio])
				t += "  foyer %d %s nb_pts=%d %s" % [f.id, f.ecole, int(f.params[10]) if f.params.size() > 10 else -1, " ".join(e)]
	print(t)
	if _arg("inventaire") != "" and image == int(_arg("inventaire")):
		var gm := GestionMagie.obtenir()
		for j in gm._jets.values():
			print("JET cible=%s bb=%s fin=%s touche=%s" % [j.cible, j.gerbe_bb, j.fin_pos, j.touche])
			if j.cible != null:
				for v in (j.cible as Node).find_children("*", "VisualInstance3D", true, false):
					print("  VISUEL %s %s aabb=%s" % [v.get_path(), v.get_class(), (v as VisualInstance3D).get_aabb()])
		for n in root.find_children("*", "GPUParticles3D", true, false):
			var g := n as GPUParticles3D
			if g.emitting and g.is_visible_in_tree():
				var sh := ""
				if g.process_material is ShaderMaterial:
					sh = (g.process_material as ShaderMaterial).shader.resource_path.get_file()
				elif g.process_material != null:
					sh = "ppm"
				print("INVENTAIRE %s n=%d r=%.2f vie=%.2f %s pos=%s" % [g.get_path(), g.amount, g.amount_ratio, g.lifetime, sh, g.global_position])

func _film(sort: String) -> void:
	l.text = sort + " : declenchement"
	await create_timer(1.2, true, false, false).timeout
	m.appuyer("gauche")
	var canal := _canalise(sort)
	for i in int(float(_arg("tenue", "2.0")) * 60.0) if canal else 6:
		s.joueur.mana = s.joueur.mana_max
		_masquer()
		await process_frame
	m.relacher("gauche")
	l.text = sort + " : fin"
	await create_timer(1.4, true, false, false).timeout
