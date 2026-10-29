extends SceneTree
## Captures « finitions visuelles » (Croc-Rouge, râtelier de la forge, lame de Skarnholt en main, os de mort dans la crypte) : une partie par lancement.
##   --part=croc|forge|lame|os   --sortie=<dossier>
## Captures du lot L9 « objets uniques et armes exposées » (FENÊTRE hors écran via godot_slot.sh, --fixed-fps 60, --audio-driver Dummy).
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_objets_uniques.gd -- --nouvelle --paisible
##         --sortie=<dossier>
## Vues : chaque objet sur son présentoir (hache de Kolbeinn sur le trône, épée d'obsidienne au râtelier de l'armurerie, Épée de Skarnholt
## au râtelier de la forge, Croc-Rouge sur son chevalet dans la grotte), invite « Prendre » puis présentoir vide après la prise, lame
## de l'Épée de Skarnholt en main sous plusieurs angles (reflet qui glisse) + agrandissements x3 de la lame.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/objets_uniques"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String, zoom := Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())
	if zoom.size.x > 0:
		var z := img.get_region(zoom)
		z.resize(zoom.size.x * 3, zoom.size.y * 3, Image.INTERPOLATE_NEAREST)
		z.save_png(dossier.path_join(nom + "_x3.png"))

## Place le joueur à `dist` m de `cible` (direction horizontale `lacet` depuis la cible), au sol `sol_y`, et tourne la tête vers la cible.
func _regarder(cible: Vector3, dist: float, lacet: float, sol_y: float) -> void:
	var j: CharacterBody3D = m.joueur
	var d := Vector3(sin(lacet), 0, cos(lacet))
	j.global_position = Vector3(cible.x, sol_y + 0.05, cible.z) + d * dist
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(d.x, d.z)       # -Z du joueur vers la cible
	await _images(20)
	var cam: Camera3D = j.camera
	var v := cible - cam.global_position
	j.tete.rotation.x = atan2(v.y, Vector2(v.x, v.z).length())
	await _images(12)

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	var t: Node3D = m.tertre
	var inv: Inventaire = m.joueur.inventaire
	m.hud.aide_t = 0.0
	var part := String(args.get("part", "croc"))
	if part == "croc":
		var ga: Node3D = m.grotte_acces
		ga.attendre_exterieur()
		ga.obtenir()
		ga.montrer(true)
		m._aller_grotte("4,0,0,0")
		await _images(60)
		m.joueur.mains.visible = false
		var uh: ObjetUnique = ga.jeu.uniques["epee_hrafn"]
		var cp := uh.global_position + uh.global_basis.y * 0.42
		var cz := uh.global_basis.y.cross(Vector3.UP).normalized()
		await _regarder(cp, 2.2, atan2(cz.x, cz.z), cp.y - 0.885)
		await _capturer("4a_croc_rouge_chevalet", Rect2i(120, 60, 240, 140))
		await _regarder(cp, 2.0, atan2(cz.x, cz.z) + 0.45, cp.y - 0.885)
		await _capturer("4b_croc_rouge_chevalet_oblique", Rect2i(120, 60, 240, 140))
		await _regarder(cp, 1.3, atan2(cz.x, cz.z) + 0.5, cp.y - 0.885)
		await _capturer("4c_croc_rouge_pres_invite")
		await _regarder(cp, 2.2, atan2(-cz.x, -cz.z), cp.y - 0.885)
		await _capturer("4d_croc_rouge_autre_cote", Rect2i(120, 60, 240, 140))
	elif part == "forge":
		m.joueur.mains.visible = false
		m.quetes.etat["lames_brodd"] = 3
		m.quetes.change.emit()
		await _images(10)
		var uf: ObjetUnique = m.unique_forge
		var ip: Node3D = uf.get_parent().get_parent()
		if ip.has_method("basculer"):
			ip.basculer(true, false)
		var sp := uf.global_position + uf.global_basis.y * 0.42
		var ff := -(uf.global_basis.z)
		await _regarder(sp, 1.7, atan2(ff.x, ff.z) + 0.25, sp.y - 1.45)
		await _images(30)
		await _capturer("5a_skarnholt_ratelier_forge", Rect2i(120, 90, 240, 140))
		await _regarder(sp, 1.1, atan2(ff.x, ff.z) - 0.2, sp.y - 1.45)
		await _capturer("5b_skarnholt_ratelier_pres_invite", Rect2i(120, 90, 240, 140))
		ObjetUnique.prendre("epee_skarnholt", inv, null, uf)       # râtelier vide : on juge le bois seul
		await _regarder(sp, 1.2, atan2(ff.x, ff.z) + 0.15, sp.y - 1.45)
		await _capturer("5c_ratelier_vide", Rect2i(120, 90, 240, 140))
	elif part == "lame":
		inv.ajouter("epee_skarnholt")
		var eq: EquipementMains = m.joueur.mains.magie.eq
		eq.equiper("droite", "epee_skarnholt")
		m.joueur.mains.visible = true
		await _images(30)
		var j: CharacterBody3D = m.joueur
		var r0 := j.rotation.y
		for k in 6:
			j.rotation.y = r0 + (k - 2.5) * 0.12
			j.tete.rotation.x = -0.25 + k * 0.08
			await _images(8)
			var vp := root.get_viewport().get_visible_rect().size
			await _capturer("3_lame_en_main_angle%d" % k, Rect2i(int(vp.x * 0.45), int(vp.y * 0.2), int(vp.x * 0.5), int(vp.y * 0.75)))
	elif part == "os":
		t.attendre_donjon()
		t._basculer(true)
		await _images(90)
		var c: Node3D = t.crypte
		m.joueur.mains.visible = false
		var j: CharacterBody3D = m.joueur
		for lieu in [["ossuaire", Vector3(-21, 0.1, -12)], ["couloir", Vector3(0, 0.1, -10)]]:
			j.global_position = c.to_global(lieu[1])
			j.velocity = Vector3.ZERO
			t._gerer_zones()
			await _images(40)
			j.rotation.y = c.global_rotation.y + (PI if lieu[0] == "ossuaire" else 0.0)      # regard fixe (déterministe)
			j.tete.rotation.x = -0.35
			await _images(10)
			var cam: Camera3D = j.camera
			var av := -cam.global_basis.z
			av.y = 0.0
			av = av.normalized()
			var eo := EclatsOs.obtenir(m)
			for essai in 2:
				EclatsOs.mort_squelette(m, j.global_position + av * 2.2, av, 1.0)
				for k in 3:
					await _images([25, 50, 120][k])
					await _capturer("6_os_%s_%d_t%d" % [lieu[0], essai, k])
				var dehors := 0
				for i in EclatsOs.NB_MORT:
					var rb := eo.get_child(EclatsOs.TAILLE_POOL + i) as Node3D
					if rb.visible and (rb.global_position.distance_to(j.global_position) > 9.0):
						dehors += 1
				print("OS ", lieu[0], " essai ", essai, " : os hors décor/sous le sol = ", dehors, " sur ", eo.vivants())
	quit()
