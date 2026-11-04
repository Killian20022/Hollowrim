extends "res://outils/captures_sorts_vfx.gd"
## Captures / film du LANCER des écoles runiques (glace, électricité, ténèbres) : repos → lancer → vol / jet → impact → fin, en
## simple et en double. Pilote le VRAI jeu (MainSort.appuyer / relacher, scène test_magie), donc les effets branchés provisoirement
## (projectile_sort.gd, effets_magie.gd, rayon_neant.gd). FENÊTRE : via /tmp/godot_slot.sh (hors écran), toujours --fixed-fps 60 :
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_lancer_ecoles.gd -- --nouvelle \
##       --sortie=<dossier> [--scen=glace_eclat,ten_rayon…] [--cam=gros|fps|suit|tps] [--double] [--film] [--combiner=glace]
## Planche par scénario : <sortie>/<scen>[_double]_<cam>.png (4 colonnes, 480x270) ; --film : <sortie>/<scen>…/f_00000.png (30 /s).
## Scénario : [sort, actions…] ; action = [images à tenir appuyé] puis relâché ; PAS = images entre deux vignettes.

const SCEN := {
	# sort, images tenues appuyé, images après le relâchement
	"glace_eclat": ["eclat_glace", 6, 44],
	"glace_lance": ["lance_givre", 40, 50],
	"glace_souffle": ["souffle_givre", 48, 36],
	"elec_arc": ["arc_electrique", 48, 36],
	"elec_chaine": ["chaine_eclairs", 6, 50],
	"elec_orage": ["orage_runique", 70, 56],
	"ten_trait": ["trait_ombre", 6, 44],
	"ten_drain": ["drain_vie", 48, 36],
	"ten_rayon": ["rayon_neant", 100, 70],
	"glace_nova": ["nova_gelee", 8, 50],
	"elec_tempete": ["tempete_statique", 8, 50],
	"ten_explosion": ["explosion_obscure", 60, 56],
}
const TPS_PAS := 3

var _cam := "gros"

func _go() -> void:
	sortie = _arg("sortie", "user://lancer_ecoles")
	DirAccess.make_dir_recursive_absolute(sortie)
	_cam = _arg("cam", "gros")
	if _arg("taille") != "" and DisplayServer.get_name() != "headless":
		var wh := _arg("taille").split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	await _preparer()
	var film := _arg("film") != ""
	var l := _arg("scen", "").split(",", false)
	var dbl := _arg("double") != ""
	if _arg("combiner") != "":
		await _combiner(_arg("combiner"), film)
		quit(0)
		return
	for nom in SCEN:
		if not l.is_empty() and not l.has(nom):
			continue
		await _scenario(nom, dbl, film)
	quit(0)

func _equiper(sort: String, dbl: bool) -> Array:
	m.relacher("gauche")
	m.relacher("droite")
	var mains: Array = ["gauche", "droite"] if dbl else ["droite"]
	if dbl:
		m.equiper("gauche", sort)
		m.equiper("droite", sort)
	else:
		m.equiper("gauche", "")
		m.equiper("droite", sort)
	return mains

func _regler_cam(cam: String, main: String) -> void:
	match cam:
		"gros":
			_cadrer(main)
			cam_gp.current = true
		"suit":
			var pr := _projectile()
			var eye: Vector3 = j.camera.global_position
			var tgt: Vector3 = pr.global_position if pr != null else (m.paume[main] as Node3D).global_position + (-j.camera.global_basis.z) * 0.9
			cam_gp.fov = float(_arg("fov_vol", "50"))
			cam_gp.global_transform = Transform3D(Basis.looking_at(tgt - eye, Vector3.UP), eye)
			cam_gp.current = true
		"fps":
			j.camera.current = true
		"tps":
			pass

func _scenario(nom: String, dbl: bool, film: bool) -> void:
	var c: Array = SCEN[nom]
	var mains := _equiper(String(c[0]), dbl)
	var main: String = "double" if dbl else "droite"
	s.placer_joueur(Vector3(0, 0, -1.75 + 3.5), 0.0, -2.0)   # mannequin à 3,5 m
	if _cam == "tps" and j.has_method("basculer_vue"):
		j.basculer_vue(true)
		j.camera_tp.set("_orbite", deg_to_rad(-125.0))
		j.camera_tp.recaler()
	elif j.has_method("basculer_vue"):
		j.basculer_vue(false)
		j.camera.current = true
	await _attendre(75)
	var imgs: Array[Image] = []
	var dossier := sortie.path_join("%s%s_%s" % [nom, "_double" if dbl else "", _cam])
	if film:
		DirAccess.make_dir_recursive_absolute(dossier)
	var n_film := 0
	var tot := 0
	var pas := int(_arg("pas", "4"))
	# repos (2 vignettes), puis appui, tenue, relâchement, suite
	var plan: Array = [["repos", 8], ["appui", int(c[1])], ["relache", int(c[2])]]
	for ph in plan:
		match String(ph[0]):
			"appui":
				for h in mains:
					m.appuyer(h)
			"relache":
				for h in mains:
					m.relacher(h)
		for k in int(ph[1]):
			await _attendre(1)
			tot += 1
			var garde := (not film and tot % pas == 0) or (film and tot % 2 == 0)
			if garde:
				_regler_cam(_cam, main if _cam == "gros" else "droite")
				var im := await _image()
				if film:
					im.save_png(dossier.path_join("f_%05d.png" % n_film))
					n_film += 1
				else:
					imgs.append(im)
	if not film:
		_planche_scen(imgs, sortie.path_join("%s%s_%s.png" % [nom, "_double" if dbl else "", _cam]))
	else:
		print("FILM %s %d images" % [dossier, n_film])
	for h in mains:
		m.relacher(h)
	RunesOrbite.forcer_charge = -1.0
	j.camera.current = true
	await _attendre(120)

func _planche_scen(imgs: Array[Image], fichier: String) -> void:
	var cols := 4
	var tw := 480
	var th := 270
	var rows := int(ceil(float(imgs.size()) / cols))
	var p := Image.create(cols * tw, maxi(rows, 1) * th, false, Image.FORMAT_RGBA8)
	p.fill(Color(0.08, 0.07, 0.08))
	for i in imgs.size():
		var im := imgs[i]
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	p.save_png(fichier)
	print("PLANCHE ", fichier, " ", imgs.size())

## Double magie : `LancerEcole.combiner` piloté directement (deux flux → un seul), puis la tête fusionnée part vers l'avant.
func _combiner(ecole: String, film: bool) -> void:
	var sort := {"glace": "eclat_glace", "electricite": "arc_electrique", "tenebres": "trait_ombre"}[ecole] as String
	_equiper(sort, true)
	s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	j.camera.current = true
	await _attendre(75)
	var pg: Node3D = m.paume["gauche"]
	var pd: Node3D = m.paume["droite"]
	var avant: Vector3 = -j.camera.global_basis.z
	var fusion := (pg.global_position + pd.global_position) * 0.5 + avant * 0.55 + Vector3.UP * 0.05
	var imgs: Array[Image] = []
	var dossier := sortie.path_join("combiner_%s_%s" % [ecole, _cam])
	if film:
		DirAccess.make_dir_recursive_absolute(dossier)
	var n := LancerEcole.combiner(pg, pd, fusion, 1.0, ecole, "eclat")
	var tete := fusion
	var nf := 0
	for k in 70:
		await _attendre(1)
		if k > 14:
			tete += avant * 0.07
		n.maintenir(tete, avant)
		if k == 54:
			n.terminer(tete)
		if (not film and k % 4 == 0) or (film and k % 2 == 0):
			_cadrer("double")
			cam_gp.current = true
			var im := await _image()
			if film:
				im.save_png(dossier.path_join("f_%05d.png" % nf))
				nf += 1
			else:
				imgs.append(im)
	if not film:
		_planche_scen(imgs, sortie.path_join("combiner_%s.png" % ecole))
	await _attendre(40)
