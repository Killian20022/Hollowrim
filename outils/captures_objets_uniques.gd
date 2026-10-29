extends SceneTree
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
	t.attendre_donjon()
	t._basculer(true)
	await _images(90)
	m.joueur.mains.visible = false
	# --- 1. hache de Kolbeinn sur le trône (Jarl vaincu pour l'invite)
	var hache: ObjetUnique = t._uniques["unique_hache_kolbeinn"]
	if m.draugrs.has("jarl") and is_instance_valid(m.draugrs["jarl"]):      # le Jarl se tient devant son trône : hors champ
		m.draugrs["jarl"].global_position += Vector3(0, -50, 0)
	var assise: Transform3D = (t.crypte as Node3D).global_transform * (t.d2.get_meta("trone_assise") as Transform3D)
	var hp := hache.global_position
	var avant := assise.basis.z
	var la := atan2(avant.x, avant.z)
	await _regarder(assise.origin + avant * 0.4 - Vector3(0, 0.3, 0), 3.2, la - 0.45, assise.origin.y - 1.16)
	await _capturer("1a_hache_trone_loin")
	await _regarder(hp, 1.5, la + 0.5, assise.origin.y - 0.56)
	await _capturer("1b_hache_trone_pres")
	m.quetes.signaler("tue:jarl")
	await _images(10)
	await _capturer("1c_hache_invite_prendre")
	(t._inter["unique_hache_kolbeinn"] as Node3D).parler()
	await _images(20)
	await _capturer("1d_hache_prise_trone_vide")
	# --- 2. épée d'obsidienne au râtelier de l'armurerie
	var obs: ObjetUnique = t._uniques["unique_epee_obsidienne"]
	var op := obs.global_position + obs.global_basis.y * 0.42
	var fo := -(obs.global_basis.z)       # face du râtelier : vers la salle (repère de l'épée : z = -z du râtelier)
	await _regarder(op, 2.0, atan2(fo.x, fo.z), op.y - 1.45)
	await _capturer("2a_obsidienne_ratelier")
	await _regarder(op, 1.15, atan2(fo.x, fo.z) + 0.4, op.y - 1.45)
	await _capturer("2b_obsidienne_ratelier_pres")
	(t._inter["unique_epee_obsidienne"] as Node3D).parler()
	await _images(20)
	await _capturer("2c_obsidienne_prise_ratelier_vide")
	# --- 3. lame en main (Épée de Skarnholt) : reflet sous plusieurs angles
	inv.ajouter("epee_skarnholt")
	var eq: EquipementMains = m.joueur.mains.magie.eq
	eq.equiper("droite", "epee_skarnholt")
	m.joueur.mains.visible = true
	await _regarder(op + Vector3(0, 0, 0), 2.6, atan2(fo.x, fo.z), op.y - 1.45)
	await _images(30)
	var j: CharacterBody3D = m.joueur
	var r0 := j.rotation.y
	for k in 6:
		j.rotation.y = r0 + (k - 2.5) * 0.12
		j.tete.rotation.x = -0.25 + k * 0.08
		await _images(8)
		var vp := root.get_viewport().get_visible_rect().size
		await _capturer("3_lame_en_main_angle%d" % k, Rect2i(int(vp.x * 0.45), int(vp.y * 0.2), int(vp.x * 0.5), int(vp.y * 0.75)))
	m.joueur.mains.visible = false
	# --- 4. grotte : Croc-Rouge sur son chevalet
	var ga: Node3D = m.grotte_acces
	t._basculer(false)
	await _images(10)
	ga.attendre_exterieur()
	ga.obtenir()
	ga.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _images(60)
	var uh: ObjetUnique = ga.jeu.uniques["epee_hrafn"]
	var cp := uh.global_position + uh.global_basis.y * 0.42
	var cz := uh.global_basis.y.cross(Vector3.UP).normalized()      # perpendiculaire à la lame, à l'horizontale
	await _regarder(cp, 2.2, atan2(cz.x, cz.z), cp.y - 0.885)
	await _capturer("4a_croc_rouge_chevalet")
	await _regarder(cp, 1.3, atan2(cz.x, cz.z) + 0.5, cp.y - 0.885)
	await _capturer("4b_croc_rouge_chevalet_pres_invite")
	await _regarder(cp, 2.2, atan2(-cz.x, -cz.z), cp.y - 0.885)
	await _capturer("4c_croc_rouge_autre_cote")
	(ga.jeu.interactifs["unique_epee_hrafn"] as Node3D).parler()
	await _images(20)
	await _capturer("4d_croc_rouge_pris")
	# --- 5. forge : Épée de Skarnholt sur le râtelier (Brodd l'a forgée)
	inv.retirer("epee_skarnholt")
	m._sous_terre(false)
	ga.montrer(false)
	await _images(10)
	m.quetes.etat["lames_brodd"] = 3
	m.quetes.change.emit()
	var uf: ObjetUnique = m.unique_forge
	var ip: Node3D = uf.get_parent().get_parent()
	if ip.has_method("basculer"):
		ip.basculer(true, false)
	var sp := uf.global_position + uf.global_basis.y * 0.42
	var ff := -(uf.global_basis.z)
	await _regarder(sp, 1.7, atan2(ff.x, ff.z) + 0.25, sp.y - 1.45)
	await _images(30)
	await _capturer("5a_skarnholt_ratelier_forge")
	await _regarder(sp, 1.1, atan2(ff.x, ff.z) - 0.2, sp.y - 1.45)
	await _capturer("5b_skarnholt_ratelier_pres_invite")
	quit()
