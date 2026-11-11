extends SceneTree
## Planches du TABARD de la garde de Skarnholt (GardeMaison, livrée « tabard_skarnholt ») : scène de combat de jour (test_combat),
## fenêtre hors écran (godot_slot.sh). Par garde : face, 3/4, profil, dos au repos ; gros plans du tabard en marche (4 instants, profil
## et 3/4), en course, en coup (épée ou lance), de dos ; mesure de traversée jambes / tabard sur les clips (distance des sommets du bas
## des pans aux segments cuisse et mollet, en repère du squelette, peau calculée sur le CPU).
##   godot --path . --resolution 960x540 --script res://outils/planches_tabard.gd -- --nouvelle --sortie=<dossier> [--ids=so,ronde_rue,haldor] [--sans-tabard]
const IDS := ["so", "ronde_rue", "haldor"]
var s: Node
var cam: Camera3D
var l: Label
var sortie := "user://tabard"
var ids: Array = IDS

func _init() -> void:
	_go.call_deferred()

func _attendre(n := 2) -> void:
	for i in n:
		await process_frame

func _donnees(id: String) -> Dictionary:
	var d := GardesVillage.donnees()
	if id == "haldor":
		var h: Dictionary = (d.get("haldor", {}) as Dictionary).duplicate()
		h["id"] = "haldor"
		h["type"] = "poste"
		return h
	for g: Dictionary in d["gardes"]:
		if String(g.get("id", "")) == id:
			return g
	return {}

func _soleil() -> void:
	var avant := -cam.global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	s.soleil.global_transform = Transform3D(Basis.looking_at((avant + Vector3(0, -0.85, 0)).normalized(), Vector3.UP), Vector3.ZERO)

func _photo(texte: String, region := Rect2i()) -> Image:
	_soleil()
	l.text = texte
	l.position = Vector2(region.position) + Vector2(6, 4)
	l.size = Vector2(maxf(region.size.x, 300) - 12, 0)
	await _attendre(3)
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	if im.get_height() != 540:
		im.resize(960, 540, Image.INTERPOLATE_NEAREST)
	if region.size != Vector2i.ZERO:
		im = im.get_region(region)
	return im

func _clip(mod: Node3D, noms: Array) -> String:
	var ap := mod.get_node("Animations") as AnimationPlayer
	for n: String in noms:
		if ap.has_animation(n):
			return n
	return "Idle"

func _poser(mod: Node3D, clip: String, t: float) -> void:
	var ap := mod.get_node("Animations") as AnimationPlayer
	var c := clip if ap.has_animation(clip) else "Idle"
	ap.play(c, 0.0)
	ap.seek(fmod(t, ap.get_animation(c).length - 0.01), true)
	ap.pause()

func _cadrer(deg: float, dist: float, h: float, hc: float, fov := 40.0) -> void:
	var dir := Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg)))
	cam.fov = fov
	cam.global_position = dir * dist + Vector3(0, hc, 0)
	cam.look_at(Vector3(0, h, 0), Vector3.UP)

## Sommets du bas des pans (repos : y < 0,80, extérieurs) avec leurs os et poids.
func _sommets_bas(lv: MeshInstance3D) -> Array:
	var r := []
	var a := lv.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var nb := bo.size() / v.size()
	for i in v.size():
		if v[i].y < 0.80 and absf(v[i].z) > 0.1:
			var os_ := []
			for k in nb:
				if w[i * nb + k] > 0.0:
					os_.append([bo[i * nb + k], w[i * nb + k]])
			r.append([v[i], os_])
	return r

func _peau(sq: Skeleton3D, lv: MeshInstance3D, p: Vector3, os_: Array) -> Vector3:
	var q := Vector3.ZERO
	for o: Array in os_:
		var b := int(o[0])
		var os_sq := sq.find_bone(lv.skin.get_bind_name(b))
		q += (sq.get_bone_global_pose(os_sq) * lv.skin.get_bind_pose(b) * p) * float(o[1])
	return q

static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Plus petite distance (m) du bas des pans aux axes des cuisses / mollets sur un clip (24 instants) ; rayon de la jambe armée ~0,085.
func _mesure(mod: Node3D, clip: String, lv: MeshInstance3D = null) -> Array:
	var sq := mod.find_child("Skeleton3D", true, false) as Skeleton3D
	if lv == null:
		lv = GardeMaison.livree(mod)
	if lv == null:
		return [-1.0, 0]
	var bas := _sommets_bas(lv)
	var ap := mod.get_node("Animations") as AnimationPlayer
	var dmin := 9.0
	var sous := 0
	var detail := {}
	var n := 24
	for k in n:
		_poser(mod, clip, ap.get_animation(clip).length * k / n if ap.has_animation(clip) else 0.0)
		sq.force_update_all_bone_transforms()
		var segs := []
		for c in ["l", "r"]:
			segs.append([sq.get_bone_global_pose(sq.find_bone("thigh_" + c)).origin, sq.get_bone_global_pose(sq.find_bone("calf_" + c)).origin])
			segs.append([sq.get_bone_global_pose(sq.find_bone("calf_" + c)).origin, sq.get_bone_global_pose(sq.find_bone("foot_" + c)).origin])
		for e: Array in bas:
			var q := _peau(sq, lv, e[0], e[1])
			for sg: Array in segs:
				var d := _dist_seg(q, sg[0], sg[1])
				dmin = minf(dmin, d)
				if d < 0.075:
					sous += 1
					var cle := "%s_%s_%s" % ["face" if (e[0] as Vector3).z > 0 else "dos", "cuisse" if segs.find(sg) % 2 == 0 else "mollet", str(snappedf((e[0] as Vector3).y, 0.05))]
					detail[cle] = int(detail.get(cle, 0)) + 1
	if not detail.is_empty():
		print("   detail ", clip, " ", detail)
	return [dmin, sous]

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--ids="):
			ids = a.substr(6).split(",")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _attendre(5)
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	s.joueur.global_position = Vector3(0, 0, 18)
	s.joueur.visible = false
	s.joueur.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("mur") != null:
		s.mur.visible = false
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var calque := CanvasLayer.new()
	calque.layer = 60
	root.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calque.add_child(l)
	cam = Camera3D.new()
	s.add_child(cam)
	cam.make_current()
	for id: String in ids:
		var g := _donnees(id)
		if g.is_empty():
			print("INCONNU ", id)
			continue
		var mod := GardeMaison.creer(g)
		s.add_child(mod)
		mod.global_position = Vector3.ZERO
		await _attendre(4)
		var ap := mod.get_node("Animations") as AnimationPlayer
		var marche := "Walk"
		var course := _clip(mod, ["Jog_Fwd", "Run", "Sprint"])
		var coup := "Lance_Estoc" if GardeMaison.arme_de(g) == "lance" else "Sword_Attack"
		# mesures de traversée (avant les photos : poses figées)
		var mes := ""
		for c: String in [marche, course, coup, "Idle"]:
			var r := _mesure(mod, c)
			mes += "%s %.3f m%s  " % [c, r[0], "" if r[1] == 0 else " (%d sous 7,5 cm)" % r[1]]
			print("MESURE ", id, " ", c, " distance min bas des pans / axe des jambes ", r[0], " ; instants x sommets sous 0,075 : ", r[1])
			var av := mod.get_node_or_null("ArmureVisible") as ArmureVisible
			if av != null and av.maillage("torse") != null:
				var rj := _mesure(mod, c, av.maillage("torse"))
				print("MESURE_JUPE ", id, " ", c, " (jupe de la cuirasse, même mesure) ", rj[0], " ; ", rj[1])
		var role := GardeMaison.role_de(g)
		var titre := "%s [%s] %s + tabard" % [id, role, ", ".join(GardeMaison.pieces_portees(mod))]
		var vues: Array = []
		_poser(mod, "Idle", 0.6)
		var cadre := Rect2i(300, 0, 360, 540)
		for v: Array in [[0.0, "face"], [35.0, "3/4"], [90.0, "profil"], [180.0, "dos"]]:
			_cadrer(v[0], 3.3, 0.95, 1.25)
			vues.append(await _photo(id + "  " + String(v[1]) + ("\n" + titre if v[1] == "face" else ""), cadre))
		var gros: Array = []
		var cg := Rect2i(240, 30, 480, 480)
		var lm := ap.get_animation(marche).length if ap.has_animation(marche) else 1.0
		for k in 4:
			_poser(mod, marche, lm * k / 4.0)
			_cadrer(-90.0 if k % 2 == 0 else -35.0, 1.7, 0.9, 1.15, 50.0)
			gros.append(await _photo("marche %d/4 (%s)" % [k + 1, "profil" if k % 2 == 0 else "3/4"], cg))
		var lc := ap.get_animation(course).length if ap.has_animation(course) else 1.0
		_poser(mod, course, lc * 0.25)
		_cadrer(-70.0, 1.8, 0.95, 1.2, 50.0)
		gros.append(await _photo("course (%s)" % course, cg))
		_poser(mod, course, lc * 0.75)
		_cadrer(150.0, 1.8, 0.95, 1.2, 50.0)
		gros.append(await _photo("course, arriere 3/4", cg))
		var la := ap.get_animation(coup).length if ap.has_animation(coup) else 1.0
		_poser(mod, coup, la * 0.45)
		_cadrer(-25.0, 1.9, 1.05, 1.3, 50.0)
		gros.append(await _photo("coup (%s)" % coup, cg))
		_poser(mod, "Idle", 0.6)
		_cadrer(0.0, 1.0, 1.2, 1.3, 45.0)
		gros.append(await _photo("gros plan : arbre brode, ceinture", cg))
		_cadrer(180.0, 1.2, 1.05, 1.3, 45.0)
		gros.append(await _photo("gros plan : dos, ourlet", cg))
		# planche : 4 vues en haut, 9 gros plans (3 x 3)
		var pl := Image.create(1440, 540 + 1440 + 40, false, Image.FORMAT_RGB8)
		pl.fill(Color(0.08, 0.08, 0.1))
		for i in vues.size():
			pl.blit_rect(vues[i], Rect2i(Vector2i.ZERO, vues[i].get_size()), Vector2i(i * 360, 0))
		for i in gros.size():
			var im: Image = gros[i]
			pl.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % 3) * 480, 540 + (i / 3) * 480))
		pl.save_png(sortie.path_join("planche_tabard_%s.png" % id))
		print("PLANCHE ", id, "  ", titre, "  ", mes)
		mod.queue_free()
		await _attendre(2)
	print("FIN planches")
	quit()
