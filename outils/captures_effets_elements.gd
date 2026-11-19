extends SceneTree
## Captures de l'EFFET PASSIF D'ÉLÉMENT des lames (EffetElementLame, docs/EFFETS_ELEMENTS.md) dans scenes/test_combat.tscn.
## FENÊTRE hors écran (godot_slot.sh) :
##   godot --path . --resolution 960x540 --fixed-fps 30 --audio-driver Dummy --script res://outils/captures_effets_elements.gd --
##         --nouvelle --sortie=<dossier> [--parties=images,film,planche] [--elements=feu,glace,electricite,tenebres]
## images : <dossier>/brut/<element>_<vue>.png ; vues : jour_fps, nuit_fps, nuit_charge, jour_tps, nuit_gros_plan, nuit_sol, nuit_sans
##          (nuit_sans = même vue que nuit_fps, effet coupé : comparaison).
## film   : <dossier>/film/<element>_NNNN.png (nuit, repos puis coup léger puis charge et coup lourd ; à monter avec ffmpeg).
## planche: <dossier>/planche_effets_elements.png (une ligne par élément, une colonne par vue, dans l'ordre ci-dessus).
## Électricité : aucune arme du jeu ne la porte encore ; l'épée d'acier reçoit element_type = « electricite » pour la capture.
const DT := 1.0 / 30.0
const ARMES := {"feu": "epee_rubis", "glace": "epee_verre", "electricite": "epee_metal", "tenebres": "epee_obsidienne"}
const VUES := ["jour_fps", "nuit_fps", "nuit_charge", "jour_tps", "nuit_gros_plan", "nuit_sol", "nuit_sans"]

var s: Node
var j: CharacterBody3D
var mains: Node3D
var dossier := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		if j != null:
			j.vigueur = j.vigueur_max
		await process_frame

func _photo(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(dossier.path_join(nom))

func _donnees(el: String) -> DonneesArme:
	var id: String = ARMES[el]
	var d: DonneesArme = load("res://data/armes/%s.tres" % id) as DonneesArme
	if d.element_type != el:
		d = d.duplicate() as DonneesArme
		d.element_type = el
		d.element = "choc"
	return d

func _go() -> void:
	RetourImpact.muet = true
	dossier = _arg("sortie", "res://captures/effets_elements")
	DirAccess.make_dir_recursive_absolute(dossier.path_join("brut"))
	DirAccess.make_dir_recursive_absolute(dossier.path_join("film"))
	var els := _arg("elements", "feu,glace,electricite,tenebres").split(",")
	var parties := _arg("parties", "images,film,planche").split(",")
	if parties.has("images"):
		await _scene(false)
		for el in els:
			await _vues_jour(el)
		await _fin_scene()
		await _scene(true)
		for el in els:
			await _vues_nuit(el)
		await _fin_scene()
	if parties.has("film"):
		await _scene(true)
		for el in els:
			await _film(el)
		await _fin_scene()
	if parties.has("planche"):
		_planche(els)
	print("EFFETS_ELEMENTS particules vivantes max : ", EffetElementLame.particules)
	print("FIN_CAPTURES")
	quit(0)

func _scene(nuit: bool) -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if nuit:
		s.options["nuit"] = ""
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("hud") != null:
		s.hud.visible = false
	await _attendre(0.7)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)

func _fin_scene() -> void:
	s.queue_free()
	j = null
	await _attendre(0.3)

func _equiper(el: String) -> void:
	EffetElementLame.actif = true
	mains.equipement.equiper("droite", load("res://data/armes/main_vide.tres"))
	await _attendre(0.3)
	mains.equipement.equiper("droite", _donnees(el))
	await _attendre(1.4)
	print("EQUIPE %s : effets vivants %d, particules %d" % [el, EffetElementLame.vivants, EffetElementLame.particules])

func _vues_jour(el: String) -> void:
	await _equiper(el)
	await _photo("brut/%s_jour_fps.png" % el)
	j.basculer_vue(true)
	await _attendre(1.0)
	# 3e personne, caméra de côté à 1,4 m (la caméra de jeu, derrière l'épaule, cache l'arme tenue devant)
	var c3 := Camera3D.new()
	c3.fov = 45.0
	s.add_child(c3)
	var at: Node3D = j.corps.get("mains_tps").get("_arme_d")
	var cible: Vector3 = j.global_position + Vector3(0.0, 1.0, 0.0)
	if at != null:
		cible = at.global_transform * (mains.get("_garde_lame") as Vector3).lerp(mains.get("_pointe_lame"), 0.4)
	var o3 := cible + Vector3(0.9, 0.35, -0.9)
	c3.global_transform = Transform3D(Basis.looking_at(cible - o3, Vector3.UP), o3)
	c3.current = true
	await _attendre(0.6)
	await _photo("brut/%s_jour_tps.png" % el)
	c3.queue_free()
	j.basculer_vue(false)
	await _attendre(0.3)

func _vues_nuit(el: String) -> void:
	await _equiper(el)
	await _photo("brut/%s_nuit_fps.png" % el)
	# charge de l'attaque puissante, tenue (renfort de l'effet)
	mains.entrees.appuyer()
	await _attendre(1.6)
	await _photo("brut/%s_nuit_charge.png" % el)
	mains.entrees.relacher()
	await _attendre(1.6)
	# gros plan : caméra à 35 cm de la lame FPS
	var m: Node3D = mains.get("_modele_arme_d")
	var g: Vector3 = mains.get("_garde_lame")
	var p: Vector3 = mains.get("_pointe_lame")
	var milieu := m.global_transform * g.lerp(p, 0.55)
	var axe := (m.global_transform * p - m.global_transform * g).normalized()
	var cote := m.global_basis.z.normalized()      # normale du plat de la lame (+X tranchant, +Y lame)
	if cote.dot(j.camera.global_position - milieu) < 0.0:
		cote = -cote
	var cam := Camera3D.new()
	cam.fov = 45.0
	s.add_child(cam)
	var oeil := milieu + cote * 0.75
	cam.global_transform = Transform3D(Basis.looking_at(milieu - oeil, axe), oeil)
	cam.current = true
	await _attendre(0.5)
	await _photo("brut/%s_nuit_gros_plan.png" % el)
	cam.current = false
	cam.queue_free()
	j.camera.current = true
	# arme posée au sol devant le joueur (ObjetMonde « sol »), mains vides
	mains.equipement.equiper("droite", load("res://data/armes/main_vide.tres"))
	var d := _donnees(el)
	var v := ObjetMonde.visuel(ARMES[el], "sol", 3)
	s.add_child(v)
	v.global_position = Vector3(0.1, 0.0, 5.2)
	if d.element_type != (load("res://data/armes/%s.tres" % ARMES[el]) as DonneesArme).element_type:
		var mod := v.get_child(0).get_child(0) as Node3D
		EffetElementLame.poser(mod, d)
	var cs := Camera3D.new()
	cs.fov = 45.0
	s.add_child(cs)
	var os := v.global_position + Vector3(0.0, 0.75, 0.55)
	cs.global_transform = Transform3D(Basis.looking_at(v.global_position + Vector3(0, 0.05, 0) - os, Vector3.UP), os)
	cs.current = true
	await _attendre(1.5)
	await _photo("brut/%s_nuit_sol.png" % el)
	cs.queue_free()
	j.camera.current = true
	v.queue_free()
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	# comparaison : même vue que nuit_fps, effet coupé
	EffetElementLame.actif = false
	mains.equipement.equiper("droite", _donnees(el))
	await _attendre(1.4)
	await _photo("brut/%s_nuit_sans.png" % el)
	EffetElementLame.actif = true

func _film(el: String) -> void:
	await _equiper(el)
	var n := 0
	var plan := [[45, ""], [1, "appui"], [2, "relache"], [40, ""], [1, "appui"], [50, ""], [1, "relache"], [45, ""]]
	for etape: Array in plan:
		match String(etape[1]):
			"appui":
				mains.entrees.appuyer()
			"relache":
				mains.entrees.relacher()
		for k in int(etape[0]):
			j.vigueur = j.vigueur_max
			await process_frame
			await _photo("film/%s_%04d.png" % [el, n])
			n += 1

func _planche(els: Array) -> void:
	var w := 0
	var h := 0
	var imgs := {}
	for el: String in els:
		for v: String in VUES:
			var img := Image.load_from_file(dossier.path_join("brut/%s_%s.png" % [el, v]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			imgs[el + v] = img
			w = maxi(w, img.get_width())
			h = maxi(h, img.get_height())
	if imgs.is_empty():
		return
	var marge := 4
	var pl := Image.create(VUES.size() * (w + marge) + marge, els.size() * (h + marge) + marge, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.08, 0.08, 0.09))
	for r in els.size():
		for c in VUES.size():
			var cle: String = els[r] + VUES[c]
			if imgs.has(cle):
				var im: Image = imgs[cle]
				pl.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(marge + c * (w + marge), marge + r * (h + marge)))
	pl.save_png(dossier.path_join("planche_effets_elements.png"))
