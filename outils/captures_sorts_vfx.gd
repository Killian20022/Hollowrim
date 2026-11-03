extends SceneTree
## Captures en jeu des VISUELS « flamme tenue » et « éclairs de Force » (branche vfx/sorts_main), vue FPS et 3e personne,
## plusieurs instants par vue (l'animation). FENÊTRE (godot_slot.sh : hors écran), toujours avec --fixed-fps 60 :
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_sorts_vfx.gd -- --nouvelle \
##       --sortie=<dossier> --prefixe=<avant|apres> [--vues=feu_repos,elec_cible…]
##   → <dossier>/<prefixe>_<vue>_<k>.png (k = 0..N-1, taille 480×270 = rendu natif)
##   planche : godot --headless --path . --script res://outils/captures_sorts_vfx.gd -- --sortie=<dossier> \
##       --planche=<fichier.png> --colonnes=avant,apres [--vues=…]
##   → une ligne par vue ; pour chaque préfixe, ses N instants côte à côte.
## N'utilise que l'interface commune (MainSort.equiper/appuyer/relacher, placer_joueur, basculer_vue) : tourne aussi sur
## une version « avant ».

const SCENE := preload("res://scenes/test_magie.tscn")
const N := 3
const PAS := 7     # images de jeu entre deux instants (60 /s)
## vue -> [tps, sort gauche, action, cible, orbite° (tps)]
## action : "repos" (sort prêt, 1,2 s), "charge" (appui tenu 0,7 s), "lance" (relâché, instants après le départ),
## "canal" (appui tenu, instants à partir de 0,6 s de canalisation). cible : mannequin à 3,5 m, ou "vide" (ciel).
const VUES := {
	"feu_repos": [false, "boule_feu", "repos", "mannequin", 0.0],
	"feu_charge": [false, "boule_feu", "charge", "mannequin", 0.0],
	"feu_lance": [false, "boule_feu", "lance", "mannequin", 0.0],
	"elec_cible": [false, "arc_electrique", "canal", "mannequin", 0.0],
	"elec_vide": [false, "arc_electrique", "canal", "vide", 0.0],
	"tps_feu_repos": [true, "boule_feu", "repos", "mannequin", -125.0],
	"tps_elec_cible": [true, "arc_electrique", "canal", "mannequin", -115.0],
	"tps_elec_dos": [true, "arc_electrique", "canal", "mannequin", -25.0],
	"gros_feu_repos": [false, "boule_feu", "repos", "mannequin", 0.0, true],
	"gros_feu_lance": [false, "boule_feu", "lance", "mannequin", 0.0, true],
	"gros_elec": [false, "arc_electrique", "canal", "mannequin", 0.0, true],
	# flamme runique, main DROITE (7e champ), cadrage proche de references/flamme_runique.png (gros plan sur la paume)
	"fr_repos": [false, "boule_feu", "repos", "vide", 0.0, true, "droite"],
	"fr_incante": [false, "boule_feu", "incante", "vide", 0.0, true, "droite"],
	"fr_charge": [false, "boule_feu", "charge", "vide", 0.0, true, "droite"],
	"fr_marche": [false, "boule_feu", "marche", "vide", 0.0, true, "droite"],
	"fr_lance": [false, "boule_feu", "lance", "vide", 0.0, true, "droite"],
	"fr_retour": [false, "boule_feu", "retour", "vide", 0.0, true, "droite"],
	"fr_proche": [false, "boule_feu", "repos", "vide", 0.0, false, "droite"],
	"fr_glace": [false, "eclat_glace", "repos", "vide", 0.0, true, "droite"],
	"fr_elec": [false, "arc_electrique", "repos", "vide", 0.0, true, "droite"],
	# écoles runiques (glace, électricité, ténèbres), même cadrage que la flamme
	"ec_glace_repos": [false, "eclat_glace", "repos", "vide", 0.0, true, "droite"],
	"ec_glace_incante": [false, "eclat_glace", "incante", "vide", 0.0, true, "droite"],
	"ec_glace_charge": [false, "eclat_glace", "charge", "vide", 0.0, true, "droite"],
	"ec_glace_lance": [false, "eclat_glace", "lance", "vide", 0.0, true, "droite"],
	"ec_elec_repos": [false, "arc_electrique", "repos", "vide", 0.0, true, "droite"],
	"ec_elec_incante": [false, "arc_electrique", "incante", "vide", 0.0, true, "droite"],
	"ec_elec_charge": [false, "arc_electrique", "charge", "vide", 0.0, true, "droite"],
	"ec_elec_lance": [false, "arc_electrique", "lance", "vide", 0.0, true, "droite"],
	"ec_ten_repos": [false, "trait_ombre", "repos", "vide", 0.0, true, "droite"],
	"ec_ten_incante": [false, "trait_ombre", "incante", "vide", 0.0, true, "droite"],
	"ec_ten_charge": [false, "trait_ombre", "charge", "vide", 0.0, true, "droite"],
	"ec_ten_lance": [false, "trait_ombre", "lance", "vide", 0.0, true, "droite"],
	"fr_tps": [true, "boule_feu", "repos", "vide", -125.0, false, "droite"],
}

var s: Node3D
var j: CharacterBody3D
var m: MainSort
var sortie := ""
var cam_gp: Camera3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _vues() -> Array:
	var f := _arg("vues", "").split(",", false)
	var r: Array = []
	for v in VUES:
		if f.is_empty() or f.has(v):
			r.append(v)
	return r

func _go() -> void:
	sortie = _arg("sortie", "user://sorts_vfx")
	DirAccess.make_dir_recursive_absolute(sortie)
	if _arg("planche") != "":
		_planche()
		quit(0)
		return
	await _preparer()
	var pref := _arg("prefixe", "apres")
	for v in _vues():
		await _vue(v, pref)
	quit(0)

## Scène de test, crépuscule, interface masquée, caméra de gros plan (aussi utilisée par outils/film_ecoles_runiques.gd).
func _preparer() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	m = s.magie
	if m.eq.has_method("apprendre_tout"):
		m.eq.apprendre_tout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	# crépuscule (cadrage des références avant_bras_magie) : la lueur des sorts se lit
	var env: Environment = s.env
	env.background_color = Color(0.30, 0.27, 0.31)
	env.ambient_light_color = Color(0.52, 0.48, 0.56)
	env.ambient_light_energy = 0.42
	var so: DirectionalLight3D = s.soleil
	so.basis = Basis.looking_at(Vector3(-0.2, -0.25, 0.95), Vector3.UP)
	so.light_color = Color(1.0, 0.72, 0.52)
	so.light_energy = 0.55
	for n in root.find_children("*", "CanvasLayer", true, false):
		for c in n.get_children():
			var garder: bool = c is ColorRect and (c as ColorRect).material is ShaderMaterial
			if c is CanvasItem and not garder:
				(c as CanvasItem).visible = false
	for n in root.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for nom in ["mannequin2", "mannequin3"]:
		var mq = s.get(nom)
		if mq is Node3D:
			(mq as Node3D).global_position += Vector3(0, -50, 0)
	cam_gp = Camera3D.new()
	cam_gp.fov = 40.0
	cam_gp.near = 0.01
	s.add_child(cam_gp)

func _attendre(n: int) -> void:
	for i in n:
		j.mana = j.mana_max
		m.recharges.clear()
		await process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im   # taille de la fenêtre (couche fine de la magie au pixel de l'écran)

## Gros plan : de côté et un peu au-dessus de la paume gauche (vue FPS), cadré sur elle et ce qui en sort.
func _cadrer(main := "gauche") -> void:
	var p: Node3D = m.paume[main]
	if main == "droite":
		# vrai point de vue du joueur, zoomé sur la paume (comme references/flamme_runique.png) : les mains ne bougent pas
		var cible := p.global_position + Vector3(0.0, float(_arg("cible_y", "0.035")), 0.0)
		cam_gp.fov = float(_arg("fov", "40"))
		cam_gp.global_transform = Transform3D(Basis.looking_at(cible - j.camera.global_position, Vector3.UP), j.camera.global_position)
		return
	var b: Basis = j.camera.global_transform.basis
	var c := p.global_position - b.z * 0.25
	var pos := c - b.x * 0.55 + b.y * 0.12 + b.z * 0.25
	cam_gp.global_transform = Transform3D(Basis.looking_at(c - pos, Vector3.UP), pos)

func _vue(v: String, pref: String) -> void:
	var c: Array = VUES[v]
	var tps: bool = c[0]
	var main: String = c[6] if c.size() > 6 else "gauche"
	var autre := "gauche" if main == "droite" else "droite"
	m.relacher("gauche")
	m.relacher("droite")
	m.equiper(autre, "epee" if main == "gauche" else "")
	m.equiper(main, String(c[1]))
	if String(c[3]) == "vide":
		s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	else:
		s.placer_joueur(Vector3(0, 0, -1.75 + 3.5), 0.0, -2.0)
	if j.has_method("basculer_vue"):
		j.basculer_vue(tps)
	if not tps:
		j.camera.current = true
	if tps:
		j.camera_tp.set("_orbite", deg_to_rad(float(c[4])))
		j.camera_tp.recaler()
	await _attendre(75)
	var action: String = c[2]
	match action:
		"charge":
			m.appuyer(main)
			await _attendre(42)
		"incante":
			m.appuyer(main)
			await _attendre(8)
		"lance":
			m.appuyer(main)
			await _attendre(40)
			m.relacher(main)
			await _attendre(3)
		"canal":
			m.appuyer(main)
			await _attendre(36)
		"retour":
			m.appuyer(main)
			await _attendre(40)
			m.relacher(main)
			await _attendre(30)
		"marche":
			Input.action_press("avant")
			await _attendre(30)
	var gros: bool = c.size() > 5 and c[5]
	for k in N:
		if gros:
			_cadrer(main)
			cam_gp.current = true
		var im := await _image()
		im.save_png(sortie.path_join("%s_%s_%d.png" % [pref, v, k]))
		print("CAPTURE %s_%s_%d" % [pref, v, k])
		if k < N - 1:
			await _attendre(PAS)
	j.camera.current = true
	if tps:
		j.camera_tp.camera.current = true
	if action == "marche":
		Input.action_release("avant")
	m.relacher(main)
	await _attendre(150)

func _planche() -> void:
	var cols := _arg("colonnes", "avant,apres").split(",", false)
	var vues := _vues()
	var tw := 480
	var th := 270
	var marge := 6
	var p := Image.create(cols.size() * (N * tw + marge), vues.size() * th, false, Image.FORMAT_RGBA8)
	p.fill(Color(0.08, 0.07, 0.08))
	for r in vues.size():
		for ci in cols.size():
			for k in N:
				var f := sortie.path_join("%s_%s_%d.png" % [cols[ci], vues[r], k])
				var im := Image.load_from_file(f)
				if im == null:
					print("MANQUE ", f)
					continue
				im.convert(Image.FORMAT_RGBA8)
				if im.get_width() != tw or im.get_height() != th:
					im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
				p.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i(ci * (N * tw + marge) + k * tw, r * th))
	p.save_png(_arg("planche"))
	print("PLANCHE ", _arg("planche"))
