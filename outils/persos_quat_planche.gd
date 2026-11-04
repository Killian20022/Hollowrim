extends SceneTree
## Présentation des persos Quaternius PS1 (essai/persos_quaternius) : planche ORIGINAL | PS1, échelle en vue de jeu à côté du héros et d'un draugr,
## animations (images pour un film). Fenêtre hors écran via godot_slot.sh :
##   godot --path . --script res://outils/persos_quat_planche.gd -- --sortie=<dossier> [--mode=planche|echelle|anims|tout] [--seul=pq_loup,pq_geant]
const W := 640
const H := 400
const POST := preload("res://shaders/ps1_post.gdshader")
const REF := "C:/Users/lopezk19/Jeux/references/quaternius_persos/"
const OUTFITS := REF + "modular-character-outfits-fantasy/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/"
const UBC := "res://assets/modeles/humains/"
const ANIMAUX := REF + "ultimate_animated_animals/FBX/"
const ORIGINAUX := {
	"pq_villageois": [OUTFITS + "Male_Peasant.gltf", UBC + "Superhero_Male_FullBody.gltf", UBC + "cheveux/Hair_SimpleParted.gltf"],
	"pq_villageoise": [OUTFITS + "Female_Peasant.gltf", UBC + "Superhero_Female_FullBody.gltf", UBC + "cheveux/Hair_Buns.gltf"],
	"pq_chasseur": [OUTFITS + "Male_Ranger.gltf", UBC + "Superhero_Male_FullBody.gltf", UBC + "cheveux/Hair_Buzzed.gltf"],
	"pq_chasseresse": [OUTFITS + "Female_Ranger.gltf", UBC + "Superhero_Female_FullBody.gltf", UBC + "cheveux/Hair_Long.gltf"],
	"pq_loup": [REF + "polypizza_cc0/Wolf_P1gU3Qkr9r.glb"],
	"pq_araignee": [REF + "polypizza_cc0/Spider_yRYJiAJyiM.glb"],
	"pq_geant": [REF + "polypizza_cc0/Giant_BldaiPtyJa.glb"],
	"pq_squelette": [REF + "polypizza_cc0/Skeleton_DM4QScSmbS.glb"],
	"pq_cerf": [REF + "polypizza_cc0/Stag_tQdzbZ1Cmw.glb"],
	"pq_spectre": [REF + "polypizza_cc0/Ghost_Iip30bDHmu.glb"],
	# secondaires (2026-11-04, sources_blender/persos_quaternius/secondaires.json) : FBX « Ultimate », chargés par FBXDocument
	"pq_cheval": [ANIMAUX + "Horse.fbx"],
	"pq_cheval_blanc": [ANIMAUX + "Horse_White.fbx"],
	"pq_vache": [ANIMAUX + "Cow.fbx"],
	"pq_taureau": [ANIMAUX + "Bull.fbx"],
	"pq_ane": [ANIMAUX + "Donkey.fbx"],
	"pq_husky": [ANIMAUX + "Husky.fbx"],
	"pq_yeti": [REF + "ultimate_monsters/Big/FBX/Yeti.fbx"],
	"pq_chevalier": [REF + "knight_character/FBX/KnightCharacter.fbx"],
}

## id -> [hauteur du dessin du héros pour l'échelle (m)] : seulement pour info
var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var sortie := ""
var post: ColorRect

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _charger_brut(chemin: String) -> Node3D:
	if chemin.begins_with("res://"):
		return (load(chemin) as PackedScene).instantiate()
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	if chemin.get_extension().to_lower() == "fbx":
		st = FBXState.new()
		doc = FBXDocument.new()
	var err := doc.append_from_file(chemin, st)
	if err != OK:
		push_error("gltf %s : %d" % [chemin, err])
		return Node3D.new()
	return doc.generate_scene(st) as Node3D

func _original(id: String) -> Node3D:
	var n := Node3D.new()
	for c: String in ORIGINAUX[id]:
		n.add_child(_charger_brut(c))
	return n

## Dimensions nominales (largeur d'encombrement, hauteur, m) : l'AABB d'un maillage skinné est celle de la pose de liaison, pas de la pose vue.
const DIMS := {"pq_villageois": Vector2(0.9, 1.84), "pq_villageoise": Vector2(0.9, 1.8), "pq_chasseur": Vector2(0.9, 1.87), "pq_chasseresse": Vector2(0.9, 1.8),
	"pq_loup": Vector2(1.5, 0.9), "pq_araignee": Vector2(2.6, 1.1), "pq_geant": Vector2(1.7, 3.3), "pq_demon": Vector2(1.4, 2.3),
	"pq_squelette": Vector2(0.9, 1.85), "pq_cerf": Vector2(1.5, 1.9), "pq_spectre": Vector2(1.3, 1.9),
	"pq_cheval": Vector2(2.7, 2.2), "pq_cheval_blanc": Vector2(2.7, 2.2), "pq_vache": Vector2(2.8, 1.5), "pq_taureau": Vector2(3.0, 1.6),
	"pq_ane": Vector2(1.7, 1.3), "pq_husky": Vector2(1.0, 0.65), "pq_yeti": Vector2(1.9, 2.6), "pq_chevalier": Vector2(1.0, 1.9)}
## originaux FBX : unités de l'auteur (cm, x100…) -> ramenés à la hauteur du PS1 pour la comparaison
## quadrupèdes « Ultimate » : le glb regarde +z (face caméra) ; tournés de profil (tête à gauche, comme l'original FBX)
const PROFIL := ["pq_cheval", "pq_cheval_blanc", "pq_vache", "pq_taureau", "pq_ane", "pq_husky"]
const NORMALISER := ["pq_cheval", "pq_cheval_blanc", "pq_vache", "pq_taureau", "pq_ane", "pq_husky", "pq_yeti", "pq_chevalier"]

func _dim(n: Node3D) -> Vector2:
	return DIMS.get(String(n.get_meta("pq", "")), Vector2(1.0, 1.8))

func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var premier := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		a = b if premier else a.merge(b)
		premier = false
	return a

func _anim(n: Node3D, nom: String, t := 0.3) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if ap == null:
		ap = n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	var cible := nom
	if not ap.has_animation(cible):
		cible = "Idle"
	if ap.has_animation(cible):
		ap.play(cible)
		ap.seek(ap.get_animation(cible).length * t, true)
		ap.pause()

func _lancer() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/persos_quat"))
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.45, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.66)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.shadow_enabled = true
	soleil.light_color = Color(1.0, 0.68, 0.42)
	soleil.light_energy = 1.3
	soleil.rotation_degrees = Vector3(-24, -50, 0)
	sv.add_child(soleil)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	sol.mesh = pm
	sol.material_override = Palette.materiau(Palette.tex("neige_galerie", Palette.NEIGE, 4, 0.4), Vector2(40, 40))
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	var calque := CanvasLayer.new()
	sv.add_child(calque)
	post = ColorRect.new()
	post.size = Vector2(W, H)
	var pmat := ShaderMaterial.new()
	pmat.shader = POST
	pmat.set_shader_parameter("vignette", 0.0)
	post.material = pmat
	calque.add_child(post)
	var mode := _arg("mode", "tout")
	var ids: Array = ORIGINAUX.keys()
	var seul := _arg("seul", "")
	if seul != "":
		ids = seul.split(",")
	if mode in ["planche", "tout"]:
		await _planche(ids)
	if mode in ["echelle", "tout"]:
		await _echelle(ids)
	if mode in ["anims", "tout"]:
		await _anims(ids)
	if mode == "film":
		await _film(ids)
	print("PERSOS_QUAT fini : ", sortie)
	quit(0)

func _photo(centre: Vector3, dist: float, az_deg := 20.0, haut_cam := 0.0) -> Image:
	var az := deg_to_rad(az_deg)
	cam.global_position = centre + Vector3(sin(az) * dist, haut_cam, cos(az) * dist)
	cam.look_at(centre, Vector3.UP)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _assembler(vues: Array, colonnes: int, nom: String) -> void:
	var lignes := (vues.size() + colonnes - 1) / colonnes
	var pl := Image.create(W * colonnes, H * lignes, false, Image.FORMAT_RGBA8)
	for i in vues.size():
		pl.blit_rect(vues[i], Rect2i(0, 0, W, H), Vector2i((i % colonnes) * W, (i / colonnes) * H))
	pl.save_png(sortie + "/" + nom)

## ORIGINAL (gauche, matériaux d'origine) | PS1 (droite) : une image par perso + planche.
func _planche(ids: Array) -> void:
	var vues: Array = []
	for id: String in ids:
		var o := _original(id)
		var p := PersosQuat.creer(id)
		sv.add_child(o)
		sv.add_child(p)
		var ap_name: String = "Idle"
		_anim(p, PersosQuat.clip(id, "idle"))
		_anim(o, "Idle")
		await process_frame
		var ho := _aabb(o)
		var hp := _aabb(p)
		var ech := _dim(p).y
		var ecart := _dim(p).x * 0.9 + 0.5
		o.position.x = -ecart
		p.position.x = ecart
		o.rotation.y = 0.0
		p.rotation.y = -PI * 0.5 if id in PROFIL else 0.0
		await process_frame
		if id in NORMALISER:
			var ao := _aabb(o)
			if ao.size.y > 0.01:
				o.scale = Vector3.ONE * (ech / ao.size.y)
				await process_frame
				o.position.y -= _aabb(o).position.y
		hp = _aabb(p)
		print("ECHELLE %-16s PS1 hauteur=%.2f largeur=%.2f prof=%.2f | original hauteur=%.2f" % [id, hp.size.y, hp.size.x, hp.size.z, _aabb(o).size.y])
		var d := maxf(ech * 2.3, ecart * 2.6)
		var img: Image = await _photo(Vector3(0, ech * 0.5, 0), d, 18.0, ech * 0.1)
		img.save_png(sortie + "/planche_%s.png" % id)
		vues.append(img)
		o.queue_free()
		p.queue_free()
		await process_frame
	_assembler(vues, 2, "planche_originaux_vs_ps1.png")

func _draugr() -> Node3D:
	var app := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6), "haillons": Color.WHITE}}
	return EnnemisNordiques.creer({"type": "sbire", "ident": "sbire_1", "apparence": app})

func _heros() -> Node3D:
	var h := Humain.creer({"corps": "homme", "tenue": {"tunique": Color(0.45, 0.4, 0.35), "pantalon": Color(0.35, 0.3, 0.28), "bottes": Color(0.5, 0.5, 0.5), "mante": Color(0.4, 0.4, 0.45)}, "cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.5, 0.35, 0.2)})
	return h

## Vue de jeu : héros, draugr existant, puis les persos PS1 côte à côte (échelle et cohérence).
func _echelle(ids: Array) -> void:
	var refs: Array[Node3D] = []
	var h := _heros()
	var dr := _draugr()
	sv.add_child(h)
	sv.add_child(dr)
	_anim(h, "Idle")
	_anim(dr, "Sword_Idle")
	refs = [h, dr]
	var groupes := [
		["pq_villageois", "pq_chasseresse", "pq_chasseur", "pq_villageoise"],
		["pq_loup", "pq_squelette", "pq_geant"],
		["pq_araignee", "pq_cerf", "pq_spectre"],
		["pq_cheval", "pq_cheval_blanc", "pq_ane"],
		["pq_vache", "pq_taureau", "pq_husky"],
		["pq_chevalier", "pq_yeti"],
	]
	var vues: Array = []
	for g: Array in groupes:
		if g.filter(func(i: String) -> bool: return ids.has(i)).is_empty():
			continue
		var noeuds: Array[Node3D] = []
		var x := -2.2
		h.position = Vector3(x, 0, 0)
		dr.position = Vector3(x + 1.0, 0, 0)
		x += 2.3
		for id: String in g:
			if not ids.has(id):
				continue
			var p := PersosQuat.creer(id)
			sv.add_child(p)
			_anim(p, PersosQuat.clip(id, "idle"))
			await process_frame
			var lg := _dim(p).x
			p.position = Vector3(x + lg * 0.5, 0, 0)
			if id in PROFIL:
				p.rotation.y = -PI * 0.5
			x += lg + 0.5
			noeuds.append(p)
		var largeur := x + 2.2
		var centre := Vector3(largeur * 0.5 - 2.2, 1.3, 0)
		var img: Image = await _photo(centre, maxf(largeur * 0.82, 5.0), 6.0, 0.4)
		vues.append(img)
		img.save_png(sortie + "/echelle_%d.png" % vues.size())
		for n in noeuds:
			n.queue_free()
		await process_frame
	_assembler(vues, 1, "echelle_vue_de_jeu.png")
	h.queue_free()
	dr.queue_free()

## Séquences d'animation : idle, marche, attaque, mort (images de la planche et du film).
func _anims(ids: Array) -> void:
	for id: String in ids:
		var p := PersosQuat.creer(id)
		sv.add_child(p)
		await process_frame
		var ech := _dim(p).y
		var vues: Array = []
		for role: String in ["idle", "marche", "attaque", "mort"]:
			var nom := PersosQuat.clip(id, role)
			var ap := p.find_child("Animations", true, false) as AnimationPlayer
			if not ap.has_animation(nom):
				continue
			ap.play(nom)
			for t in [0.15, 0.5, 0.85]:
				ap.seek(ap.get_animation(nom).length * t, true)
				ap.pause()
				await process_frame
				var im: Image = await _photo(Vector3(0, ech * 0.5, 0), maxf(ech * 2.4 + _dim(p).x, 3.0), 25.0, ech * 0.1)
				vues.append(im)
		if not vues.is_empty():
			_assembler(vues, 3, "anims_%s.png" % id)
		p.queue_free()
		await process_frame

## FILM (avec --write-movie <film.avi> --fixed-fps 30 --resolution 1280x720) : groupes de persos animés, idle -> marche -> attaque -> mort.
func _film(ids: Array) -> void:
	sv.size = Vector2i(1280, 720)
	post.size = Vector2(1280, 720)
	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.size = Vector2(1280, 720)
	root.add_child(tr)
	var lab := Label.new()
	lab.position = Vector2(24, 18)
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 8)
	root.add_child(lab)
	var groupes := [
		["pq_villageois", "pq_chasseresse", "pq_chasseur", "pq_villageoise"],
		["pq_loup", "pq_araignee", "pq_squelette"],
		["pq_geant", "pq_cerf", "pq_spectre"],
	]
	for g: Array in groupes:
		var noeuds: Array[Node3D] = []
		var x := 0.0
		var largeurs: Array[float] = []
		for id: String in g:
			var p := PersosQuat.creer(id)
			sv.add_child(p)
			await process_frame
			largeurs.append(maxf(_dim(p).x, 1.0))
			noeuds.append(p)
		var total := 0.0
		for l in largeurs:
			total += l + 0.8
		x = -total * 0.5
		for i in noeuds.size():
			noeuds[i].position.x = x + largeurs[i] * 0.5 + 0.4
			x += largeurs[i] + 0.8
		var haut := 1.0
		for n in noeuds:
			haut = maxf(haut, _dim(n).y)
		var centre := Vector3(0, haut * 0.4, 0)
		var dist := maxf(total * 0.85, haut * 2.4)
		cam.global_position = centre + Vector3(0, haut * 0.15, dist)
		cam.look_at(centre, Vector3.UP)
		for role in ["idle", "marche", "attaque", "mort"]:
			lab.text = "%s  [%s]" % [", ".join(g).replace("pq_", ""), role]
			var duree := 1.5
			for n in noeuds:
				var nom := PersosQuat.clip(String(n.get_meta("pq")), role)
				var ap := n.find_child("Animations", true, false) as AnimationPlayer
				if ap.has_animation(nom):
					ap.play(nom, 0.1)
					if role in ["attaque", "mort"]:
						duree = maxf(duree, ap.get_animation(nom).length + 0.4)
			for f in int(duree * 30.0):
				await process_frame
		for n in noeuds:
			n.queue_free()
		await process_frame
	print("FILM_FIN")
