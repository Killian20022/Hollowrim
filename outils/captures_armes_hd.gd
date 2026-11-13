extends SceneTree
## Armes HD (branche armes/hybrides_hd) : planches avant (modèle d'origine) / après (modèle HD du catalogue) de n'importe quelle
## arme du catalogue + planche « famille ». Avant = AVANT[id] (glb ou tscn d'origine, gardés) ; après = CatalogueArmes.donnees(id).
## FENÊTRE hors écran (godot_slot.sh) :
##   godot --path . --resolution 960x540 --audio-driver Dummy --script res://outils/captures_armes_hd.gd --
##         --nouvelle --sortie=<dossier> --etiquette=avant|apres [--armes=a,b] [--parties=studio,fps,nuit,famille,assembler]
##         [--famille=nom]
## studio  : <dossier>/brut/<etiq>_<id>_<vue>.png : entiere (plat), entiere_34, garde (ou tête), pommeau (ou talon), lame ;
##           + sil_face / sil_profil (superposition) ; « MESURE tris ». Cadrage commun : la boîte du modèle d'origine.
## fps     : brut/<etiq>_<id>_fps_jour.png (scène test_combat, jour) ; nuit : brut/<etiq>_<id>_fps_nuit.png (nuit, torche).
## famille : <dossier>/famille_<nom>_<etiq>_plat|34|poignees.png (toutes les armes de --armes, même échelle).
## assembler : <dossier>/<id>_avant_apres.png (avant en haut, après en bas, 7 vues) + <id>_superposition_rouge_avant_cyan_apres.png.
const DT := 1.0 / 60.0
const ARMES := ["garde_du_guet", "dent_d_or", "veilleuse", "crocs_de_cendre", "larme_de_givre", "coeur_de_braise", "sang_du_roi",
		"croc_de_givre"]
const VUES := ["entiere", "entiere_34", "garde", "pommeau", "lame", "fps_jour", "fps_nuit"]
const H := "res://assets/modeles/armes/hybrides/"
const I := "res://assets/modeles/armes/integrees/"
## Modèles d'origine (« avant »), gardés pour le retour arrière.
const AVANT := {
	"garde_du_guet": H + "h1_garde_du_guet.glb", "dent_d_or": H + "h2_dent_d_or.glb", "veilleuse": H + "h3_veilleuse.glb",
	"crocs_de_cendre": H + "h4_crocs_de_cendre.glb", "larme_de_givre": H + "h5_larme_de_givre.glb",
	"coeur_de_braise": H + "h6_coeur_de_braise.glb", "sang_du_roi": H + "h7_sang_du_roi.glb", "croc_de_givre": H + "h8_croc_de_givre.glb",
	"hache_guerre": I + "hache_guerre.tscn", "hachette": I + "hachette.tscn", "masse_cloutee": I + "masse_cloutee.tscn",
	"marteau_guerre": I + "marteau_guerre.tscn", "grand_marteau": I + "grand_marteau.tscn", "bouclier_cercle": I + "bouclier_cercle.tscn",
	"ecu_chevalier": I + "ecu_chevalier.tscn",
}

var s: Node
var j: CharacterBody3D
var mains: Node3D
var dossier := ""
var etiq := ""

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

func _go() -> void:
	RetourImpact.muet = true
	dossier = _arg("sortie", "res://captures/armes_hd")
	etiq = _arg("etiquette", "x")
	DirAccess.make_dir_recursive_absolute(dossier.path_join("brut"))
	var armes := _arg("armes", ",".join(ARMES)).split(",")
	var parties := _arg("parties", "studio,fps,nuit,famille,assembler").split(",")
	if parties.has("studio"):
		for id in armes:
			await _studio(id)
	if parties.has("famille"):
		await _famille(armes)
	if parties.has("fps"):
		await _fps(armes, false)
	if parties.has("nuit"):
		await _fps(armes, true)
	if parties.has("assembler"):
		for id in armes:
			_assembler(id)
	print("FIN_CAPTURES")
	quit(0)

# ------------------------------------------------------------------ studio (fond neutre, lumière fixe)
func _studio_vp(taille := Vector2i(480, 270)) -> Array:
	var vp := SubViewport.new()
	vp.size = taille
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3d44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a0")
	env.ambient_light_energy = 0.5
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-30, -35, 0)
	sol.light_energy = 1.3
	vp.add_child(sol)
	var cam := Camera3D.new()
	vp.add_child(cam)
	return [vp, cam]

func _habiller(m: Node3D, habillage := "") -> void:
	if habillage == "claymore":
		ClaymoreMateriaux.habiller(m)
	else:
		EpeesLongues.habiller(m)

func _modele(id: String, e := "") -> Node3D:
	var ee := etiq if e == "" else e
	var a: DonneesArme = CatalogueArmes.donnees(id)
	var chemin: String = AVANT.get(id, a.modele) if ee == "avant" else a.modele
	var m: Node3D = (load(chemin) as PackedScene).instantiate()
	_habiller(m, a.habillage)
	return m

func _local(e: Node, n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != e:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _boite(m: Node3D) -> AABB:
	var b := AABB()
	var premier := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var bb := _local(m, mi) * mi.get_aabb()
		b = bb if premier else b.merge(bb)
		premier = false
	return b

func _tris(m: Node3D) -> int:
	var tris := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for sidx in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sidx)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris

func _repere(m: Node3D, nom: String) -> Vector3:
	var n := m.find_child(nom, true, false)
	return _local(m, n).origin if n else Vector3.ZERO

func _repere_y(m: Node3D, nom: String, defaut: float) -> float:
	var n := m.find_child(nom, true, false)
	return _local(m, n).origin.y if n else defaut

func _vue(vp: SubViewport) -> Image:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	return img

func _studio(id: String) -> void:
	var r := _studio_vp()
	var vp: SubViewport = r[0]
	var cam: Camera3D = r[1]
	var m := _modele(id)
	vp.add_child(m)
	var b := _boite(m)
	print("MESURE %s %s tris=%d longueur=%.3f y[%.3f ; %.3f] largeur=%.3f epaisseur=%.3f garde=%.3f pointe=%.3f" % [etiq, id, _tris(m), b.size.y, b.position.y, b.end.y, b.size.x, b.size.z, _repere_y(m, "garde", 0.17), _repere_y(m, "pointe", 0.0)])
	var ref := _modele(id, "avant")    # cadrage commun : la boîte du modèle d'origine (vues identiques d'une ligne à l'autre)
	b = _boite(ref)
	ref.free()
	var lg := b.size.y
	var yc := b.get_center().y
	var yg := _repere_y(m, "garde", 0.17)
	var k := clampf(lg / 1.05, 0.5, 1.4)    # dague : caméra plus proche
	var yp := b.position.y
	var ylame := yg + (b.end.y - yg) * 0.35
	var vues := [
		["entiere", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(0, 0, -PI / 2), Vector3(-yc, 0, 0)],
		["entiere_34", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(deg_to_rad(55), 0, -PI / 2), Vector3(-yc, 0, 0)],
		["garde", false, 38.0, Vector3(0.13 * k, yg + 0.03 * k, 0.30 * k), Vector3(0, yg - 0.02 * k, 0), Vector3(0, deg_to_rad(18), 0), Vector3.ZERO],
		["pommeau", false, 36.0, Vector3(-0.08 * k, yp + 0.09 * k, 0.24 * k), Vector3(0, yp + 0.05 * k, 0), Vector3(0, deg_to_rad(-20), 0), Vector3.ZERO],
		["lame", false, 40.0, Vector3(0.07 * k, yg + 0.15 * k, 0.17 * k), Vector3(0, yg + 0.19 * k, 0), Vector3(0, deg_to_rad(18), 0), Vector3.ZERO],
		# silhouettes pour la superposition original / v2 : face (plat) et profil (tranche), même caméra, sans rotation 3/4
		["sil_face", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(0, 0, -PI / 2), Vector3(-yc, 0, 0)],
		["sil_profil", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(PI / 2, 0, -PI / 2), Vector3(-yc, 0, 0)],
	]
	var donnees: DonneesArme = CatalogueArmes.donnees(id)
	var reg := _repere(m, "garde")
	if donnees.categorie == DonneesArme.Categorie.BOUCLIER:    # face avant vers la caméra (+x du montage), dos, bord, umbo
		var t := maxf(b.size.y, b.size.z)
		var cb := b.get_center()
		var av := -PI / 2
		vues = [
			["entiere", true, t * 1.15, Vector3(0, cb.y, 3), Vector3(0, cb.y, 0), Vector3(0, av, 0), Vector3(0, 0, -cb.z)],
			["entiere_34", true, t * 1.15, Vector3(0, cb.y, 3), Vector3(0, cb.y, 0), Vector3(deg_to_rad(-15), av + deg_to_rad(40), 0), Vector3(0, 0, 0)],
			["garde", false, 34.0, Vector3(0.10, cb.y + t * 0.30, 0.42), Vector3(0, cb.y + t * 0.36, 0), Vector3(0, av + deg_to_rad(25), 0), Vector3(0, 0, 0)],
			["pommeau", true, t * 1.15, Vector3(0, cb.y, 3), Vector3(0, cb.y, 0), Vector3(0, -av, 0), Vector3(0, 0, 0)],
			["lame", false, 34.0, Vector3(0.08, cb.y + 0.03, 0.40), Vector3(0, cb.y, 0), Vector3(0, av + deg_to_rad(20), 0), Vector3(0, 0, 0)],
			["sil_face", true, t * 1.15, Vector3(0, cb.y, 3), Vector3(0, cb.y, 0), Vector3(0, av, 0), Vector3(0, 0, 0)],
			["sil_profil", true, t * 1.15, Vector3(0, cb.y, 3), Vector3(0, cb.y, 0), Vector3(0, 0, 0), Vector3(0, 0, 0)],
		]
	elif not AVANT.has(id) or not String(AVANT[id]).contains("hybrides"):   # armes d'hast courtes : tête, talon, tranchant / face
		var yh := (yg + b.end.y) * 0.5
		var hx := reg.x + 0.04
		var th := maxf(b.end.y - yg, 0.2)
		vues[2] = ["garde", false, 38.0, Vector3(hx + 0.18 * th, yh + 0.06 * th, 0.75 * th + 0.12), Vector3(hx, yh, 0), Vector3(0, deg_to_rad(20), 0), Vector3.ZERO]
		vues[4] = ["lame", false, 34.0, Vector3(hx + 0.22 * th, yh + 0.12 * th, 0.40 * th + 0.08), Vector3(hx + 0.05, yh - 0.02, 0), Vector3(0, deg_to_rad(-35), 0), Vector3.ZERO]
	for v in vues:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL if v[1] else Camera3D.PROJECTION_PERSPECTIVE
		if v[1]:
			cam.size = v[2]
		else:
			cam.fov = v[2]
		cam.position = v[3]
		cam.look_at(v[4])
		m.rotation = v[5]
		m.position = v[6]
		await _attendre(0.15)
		_vue(vp).save_png(dossier.path_join("brut/%s_%s_%s.png" % [etiq, id, v[0]]))
	vp.queue_free()
	await _attendre(0.05)

# ------------------------------------------------------------------ famille (même échelle)
func _famille(ids: Array) -> void:
	var nom := _arg("famille", "hybrides")
	var r := _studio_vp(Vector2i(640, 360))
	var vp: SubViewport = r[0]
	var cam: Camera3D = r[1]
	var pas := 3.6 / ids.size()
	var x := -1.8 + pas * 0.5
	if ids.size() < 8:
		pas = 4.0 / ids.size()
		x = -2.0 + pas * 0.5
	var ms: Array[Node3D] = []
	for id in ids:
		var m := _modele(id)
		vp.add_child(m)
		m.position = Vector3(x, -0.85, 0)
		ms.append(m)
		x += pas
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.05 if ids.size() >= 8 else 2.3
	for v in [["plat", 0.0], ["34", 38.0]]:
		cam.position = Vector3(0, 0.05, 3)
		cam.look_at(Vector3(0, 0.05, 0))
		for i in ms.size():
			var bq := CatalogueArmes.donnees(ids[i]).categorie == DonneesArme.Categorie.BOUCLIER
			ms[i].rotation = Vector3(0, deg_to_rad(v[1]) + (PI / 2 if bq else 0.0), 0)
		await _attendre(0.2)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img.save_png(dossier.path_join("famille_%s_%s_%s.png" % [nom, etiq, v[0]]))
		print("PLANCHE ", dossier.path_join("famille_%s_%s_%s.png" % [nom, etiq, v[0]]))
	# gardes et pommeaux côte à côte (perspective, même distance)
	var imgs: Array[Image] = []
	for i in ms.size():
		for m in ms:
			m.visible = false
		var m := ms[i]
		m.visible = true
		m.position = Vector3.ZERO
		m.rotation = Vector3(0, deg_to_rad(12) + (PI / 2 if CatalogueArmes.donnees(ids[i]).categorie == DonneesArme.Categorie.BOUCLIER else 0.0), 0)
		var yg := _repere_y(m, "garde", 0.17)
		var b := _boite(m)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 34.0
		var yc := (yg + b.position.y) * 0.5
		var dist := 0.30 + (yg - b.position.y) * 0.9
		cam.position = Vector3(0.10, yc + 0.03, dist)
		cam.look_at(Vector3(0, yc, 0))
		await _attendre(0.15)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
	var w := imgs[0].get_width()
	var h := imgs[0].get_height()
	var nc := 4
	var pl := Image.create(w * nc, h * ceili(imgs.size() / float(nc)), false, Image.FORMAT_RGBA8)
	pl.fill(Color("#3a3d44"))
	for i in imgs.size():
		pl.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % nc) * w, (i / nc) * h))
	pl.save_png(dossier.path_join("famille_%s_%s_poignees.png" % [nom, etiq]))
	print("PLANCHE ", dossier.path_join("famille_%s_%s_poignees.png" % [nom, etiq]))
	vp.queue_free()
	await _attendre(0.05)

# ------------------------------------------------------------------ 1re personne, en jeu (jour, ou nuit à la torche)
## Le modèle « avant » est mis en place en changeant le chemin du modèle de la DonneesArme (copie) : même pose, mêmes repères.
func _fps(armes: Array, nuit: bool) -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	var o := {"draugr": "aucun", "sans-aide": ""}
	if nuit:
		o["nuit"] = ""
	s.options = o
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
	for id in armes:
		var a: DonneesArme = CatalogueArmes.donnees(id).duplicate()
		if etiq == "avant":
			a.modele = AVANT.get(id, a.modele)
		if a.categorie == DonneesArme.Categorie.BOUCLIER:     # bouclier au bras gauche, épée de soldat en main droite
			mains.equipement.equiper("droite", CatalogueArmes.donnees("epee_soldat"))
			await _attendre(0.3)
			mains.equipement.equiper("gauche", a)
		else:
			mains.equipement.equiper("droite", a)
		await _attendre(1.4)
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join("brut/%s_%s_fps_%s.png" % [etiq, id, "nuit" if nuit else "jour"]))
	s.queue_free()
	j = null
	await _attendre(0.1)

# ------------------------------------------------------------------ planche avant / après
func _bloc(e: String, id: String, w: int, h: int) -> Image:
	var bloc := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	bloc.fill(Color("#202226"))
	for i in VUES.size():
		var p := dossier.path_join("brut/%s_%s_%s.png" % [e, id, VUES[i]])
		if not FileAccess.file_exists(p):
			continue
		var im := Image.load_from_file(p)
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		bloc.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	return bloc

func _assembler(id: String) -> void:
	var w := 480
	var h := 270
	var lignes := ["avant", "apres"]
	var pl := Image.create(w * VUES.size(), h * 2 + 8, false, Image.FORMAT_RGBA8)
	pl.fill(Color("#f2c200"))
	for li in lignes.size():
		for i in VUES.size():
			var p := dossier.path_join("brut/%s_%s_%s.png" % [lignes[li], id, VUES[i]])
			if not FileAccess.file_exists(p):
				continue
			var im := Image.load_from_file(p)
			im.convert(Image.FORMAT_RGBA8)
			im.resize(w, h, Image.INTERPOLATE_BILINEAR)
			pl.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(i * w, li * (h + 8)))
	pl.save_png(dossier.path_join("%s_avant_apres.png" % id))
	print("PLANCHE ", dossier.path_join("%s_avant_apres.png" % id))
	# superposition des silhouettes : avant en rouge, après en cyan, recouvrement en blanc
	var fond := Color("#3a3d44")
	var sup: Array[Image] = []
	for v in ["sil_face", "sil_profil"]:
		var pa := dossier.path_join("brut/avant_%s_%s.png" % [id, v])
		var pb := dossier.path_join("brut/apres_%s_%s.png" % [id, v])
		if not (FileAccess.file_exists(pa) and FileAccess.file_exists(pb)):
			continue
		var ia := Image.load_from_file(pa)
		var ib := Image.load_from_file(pb)
		var o := Image.create(ia.get_width(), ia.get_height(), false, Image.FORMAT_RGBA8)
		var n_a := 0
		var n_b := 0
		var n_ab := 0
		for y in ia.get_height():
			for x in ia.get_width():
				var ca := ia.get_pixel(x, y)
				var cb := ib.get_pixel(x, y)
				var ma := absf(ca.r - fond.r) + absf(ca.g - fond.g) + absf(ca.b - fond.b) > 0.03
				var mb := absf(cb.r - fond.r) + absf(cb.g - fond.g) + absf(cb.b - fond.b) > 0.03
				n_a += int(ma)
				n_b += int(mb)
				n_ab += int(ma and mb)
				o.set_pixel(x, y, Color.WHITE if ma and mb else (Color("#e03a3a") if ma else (Color("#3ad0e0") if mb else Color("#202226"))))
		print("SILHOUETTE %s %s : avant %d px, apres %d px, commun %d px (%.0f %% de l'avant couvert, %.0f %% de l'apres dans l'avant)" % [
			id, v, n_a, n_b, n_ab, 100.0 * n_ab / maxi(1, n_a), 100.0 * n_ab / maxi(1, n_b)])
		sup.append(o)
	if sup.size() == 2:
		var w2 := sup[0].get_width()
		var h2 := sup[0].get_height()
		var s2 := Image.create(w2, h2 * 2 + 8, false, Image.FORMAT_RGBA8)
		s2.fill(Color("#f2c200"))
		s2.blit_rect(sup[0], Rect2i(0, 0, w2, h2), Vector2i(0, 0))
		s2.blit_rect(sup[1], Rect2i(0, 0, w2, h2), Vector2i(0, h2 + 8))
		s2.save_png(dossier.path_join("%s_superposition_rouge_avant_cyan_apres.png" % id))
		print("PLANCHE ", dossier.path_join("%s_superposition_rouge_avant_cyan_apres.png" % id))
