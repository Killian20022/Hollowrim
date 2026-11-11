extends SceneTree
const CM := preload("res://outils/controle_modele_lib.gd")
## CONTRÔLE AUTOMATIQUE d'un modèle rigué (PNJ / armures Tripo) : à lancer AVANT de montrer un modèle (docs/CONTROLE_MODELE.md).
##   godot --headless --path . --script res://outils/controle_modele.gd -- --modele=<.glb | res://scène | garde:<id> | dore> \
##       [--clips=Idle,Walk,Sword_Idle,Sword_Attack] [--images=5] [--budget=12000] [--json=<rapport.json>] [--seuil.<nom>=<valeur>] [--planche=<png>]
## --modele accepte plusieurs valeurs séparées par « ; ». Code de sortie : 0 = CONTROLE OK pour tous, 1 = au moins un CONTROLE ECHEC.
## --planche (PNG de gros plans des bras, face / profil, repos + premier clip) demande une fenêtre : lancer SANS --headless, via godot_slot.sh (hors écran).
## La logique est dans outils/controle_modele_lib.gd (ControleModele).

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var o := {}
	var modeles: Array = []
	var json_sortie := ""
	var planche := ""
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--") or not a.contains("="):
			continue
		var k := a.get_slice("=", 0).substr(2)
		var v := a.substr(a.find("=") + 1)
		match k:
			"modele":
				for m in v.split(";", false):
					modeles.append(m)
			"clips":
				o["clips"] = Array(v.split(",", false))
			"images":
				o["images"] = int(v)
			"budget":
				o["budget_tris"] = int(v)
			"json":
				json_sortie = v
			"planche":
				planche = v
			_:
				if k.begins_with("seuil."):
					o[k.substr(6)] = float(v)
	if modeles.is_empty():
		print("usage : --modele=<chemin .glb | res://... | garde:<id> | dore> [--clips=A,B] [--images=N] [--budget=N] [--json=f.json] [--planche=f.png] [--seuil.<nom>=x]")
		quit(2)
		return
	var tout_ok := true
	var rapports := {}
	for spec: String in modeles:
		var n: Node3D = CM.charger(spec)
		if n == null:
			print("CONTROLE ECHEC  ", spec, " : modèle illisible")
			tout_ok = false
			continue
		root.add_child(n)
		var t0 := Time.get_ticks_msec()
		var c = CM.new(n, o)
		var rap: Dictionary = c.controler()
		rap["modele"] = spec
		rap["duree_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
		rapports[spec] = rap
		_afficher(spec, rap)
		if not rap["ok"]:
			tout_ok = false
		if planche != "":
			await _planche(c, planche if modeles.size() == 1 else planche.get_basename() + "_" + spec.get_file().get_basename() + ".png")
		n.queue_free()
	if json_sortie != "":
		var f := FileAccess.open(json_sortie, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rapports if rapports.size() > 1 else rapports.values()[0], "  "))
			f.close()
			print("rapport JSON : ", json_sortie)
	quit(0 if tout_ok else 1)

func _afficher(spec: String, rap: Dictionary) -> void:
	print("----------------------------------------------------------------")
	print("MODELE ", spec, "   (", rap.get("duree_s", 0), " s)")
	if rap.has("tris"):
		var t: Dictionary = rap["tris"]
		print("  triangles : %d / budget %d  %s" % [t["total"], t["budget"], "ok" if t["ok"] else "HORS BUDGET"])
		var co: Dictionary = rap["composantes"]
		print("  composantes connexes : %d (la plus petite : %d faces) ; éclats < seuil : %d dont %d près des bras ; arêtes ouvertes : %d boucles, %d petits trous ; non-manifold : %d" % [
			co["composantes"], co["faces_min"], co["eclats"].size(), co["eclats_proches"].size(), co["bords_ouverts_boucles"], co["petits_trous"].size(), co["aretes_non_manifold"]])
		for e: Dictionary in co["eclats"]:
			print("     éclat %2d faces  centre %s  taille %s  os %s  pièce %s  à %.1f cm du bras/main" % [e["faces"], e["centre"], e["taille"], e["os"], e["piece"], float(e["distance_main_avant_bras"]) * 100])
		for cote in rap["bras"]:
			var b: Dictionary = rap["bras"][cote]
			var r: Dictionary = b["repos"]
			print("  bras %s : os haut/avant/main = %s m ; géométrie = %s m ; largeur avant-bras %.3f, main %.3f -> rapport %.2f ; avant-bras coude %.3f / poignet %.3f ; écart max sans géométrie %.1f cm (au repos %.1f)" % [
				cote, _fmt(r["os"]), _fmt(r["geo"]), r["largeur_avant"], r["largeur_main"], b["rapport_largeur"], r["largeur_coude"], r["largeur_poignet"], float(b["ecart_max"]) * 100, float(r["ecart"]) * 100])
			print("          étirement max sur %d images : os %.1f %%, géométrie %.1f %% (%s)" % [b["poses"].size(), float(b["etirement_os_max"]) * 100, float(b["etirement_geo_max"]) * 100, b["etirement_geo_pose"]])
		if rap.has("arme"):
			var a: Dictionary = rap["arme"]
			print("  arme (sur %s) : poignée à %.1f cm de la paume (max) ; lame à %.0f° - %.0f° de l'avant-bras" % [a["os"], float(a["distance_poignee_paume_max"]) * 100, a["angle_lame_avant_bras_min"], a["angle_lame_avant_bras_max"]])
	for w in rap.get("avertissements", []):
		print("  attention : ", w)
	for e in rap.get("echecs", []):
		print("  ECHEC : ", e)
	print(("CONTROLE OK" if rap["ok"] else "CONTROLE ECHEC"), "  ", spec)

func _fmt(a: Array) -> String:
	return "[" + ", ".join(a.map(func(x): return "%.3f" % x)) + "]"

## Planche de gros plans des bras : colonnes = face puis dessus ; lignes = bras gauche au repos, bras droit au repos, puis les deux au milieu du
## premier clip. Chaque cellule : 384 px, caméra orthographique centrée sur coude -> base du majeur. Demande un rendu (pas de --headless).
func _planche(c, chemin: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("planche ignorée : lancer sans --headless (godot_slot.sh ouvre la fenêtre hors écran)")
		return
	var lum := DirectionalLight3D.new()
	lum.rotation_degrees = Vector3(-40, 25, 0)
	root.add_child(lum)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.2, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root.add_child(env)
	var lignes: Array = []      # [pose, côté]
	var clip_nom := ""
	for nom in c.anims:
		clip_nom = nom
		break
	var cotes: Array = c.os_bras.keys()
	for cote in cotes:
		lignes.append(["repos", cote])
	if clip_nom != "":
		for cote in cotes:
			lignes.append([clip_nom, cote])
	const T := 384
	var feuille := Image.create(T * 2, T * lignes.size(), false, Image.FORMAT_RGB8)
	for r in lignes.size():
		var pose: String = lignes[r][0]
		var cote: String = lignes[r][1]
		if pose == "repos":
			c.poser_neutre()
		else:
			var a: Animation = c.anims[pose]
			c.poser_clip(a, a.length * 0.5, pose)
		var d: Dictionary = c.os_bras[cote]
		var sq: Skeleton3D = c.sq
		var m: Transform3D = sq.global_transform
		var p1: Vector3 = m * c.gp(d["avant"]).origin
		var p2: Vector3 = m * c.gp(d["bout"]).origin
		var centre: Vector3 = (p1 + p2) * 0.5 + (m.basis * c.gp(d["main"]).basis.y).normalized() * 0.04
		for col in 2:
			var vp := SubViewport.new()
			vp.size = Vector2i(T, T)
			vp.own_world_3d = false
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 0.62
			cam.far = 10.0
			vp.add_child(cam)
			root.add_child(vp)
			var dir := Vector3(0, 0, 1) if col == 0 else Vector3(0, 1, 0)      # face (devant du perso) / dessus
			cam.global_position = centre + dir * 3.0
			cam.look_at(centre, Vector3.UP if col == 0 else Vector3(0, 0, -1))
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			if img != null:
				img.convert(Image.FORMAT_RGB8)
				feuille.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(col * T, r * T))
			vp.queue_free()
	c.poser_neutre()
	feuille.save_png(chemin)
	print("planche : ", chemin, " (", lignes.size(), " lignes : ", " / ".join(lignes.map(func(l): return "%s %s" % [l[1], l[0]])), " ; colonnes face | dessus)")
	lum.queue_free()
	env.queue_free()
