extends SceneTree
## Captures ÉLECTRICITÉ / GLACE / TÉNÈBRES / PROJECTILES SUR LE CORPS (socle ImpactCorps, agent B, docs/MAGIE_IMPACT_CORPS.md) :
## galerie de la magie (crypte de nuit, vraie main gauche du héros, draugrs DraugrNordique). Les sorts sont rejoués comme
## les envoie la logique (LanceurSorts) : jet chaque image + statut à chaque tic ; projectile qui vole à sa vitesse puis
## EffetsMagie.impact(point, -direction, force) et le statut ; chaîne : chaine + impact + statut ; nova : statut gel.
##   godot --path . --script res://outils/captures_impact_ecoles.gd -- --sortie=<dossier> [--cas=elec_face,...]
##       [--sans-impact-corps] (rendu d'AVANT) [--cote] (vue de côté en plus) [--detail-sorts=retro|moyen|eleve]
##       [--film=<cas>] : une image toutes les 2 images (30 i/s) du cas, pour une vidéo ralentie (ffmpeg)
## Lancer par /tmp/godot_slot.sh (fenêtre hors écran), 1280x720.

const GALERIE := preload("res://scenes/galerie_magie.tscn")
## nom : {e école, k genre (jet / proj / chaine / nova), l lacet (°), d durée du jet (s), t instants (s), a animation,
##        chute (s, ragdoll), forme, v vitesse, n nombre, st statut, sd durée du statut, sp puissance, f force, tirs (s)}
const CAS := {
	"elec_face": {"e": "electricite", "k": "jet", "l": 0.0, "d": 2.0, "t": [0.3, 1.3], "st": "choc", "sd": 0.5},
	"elec_trois_quarts": {"e": "electricite", "k": "jet", "l": 45.0, "d": 2.0, "t": [1.3], "st": "choc", "sd": 0.5},
	"elec_profil": {"e": "electricite", "k": "jet", "l": 90.0, "d": 2.0, "t": [1.3], "st": "choc", "sd": 0.5},
	"elec_marche": {"e": "electricite", "k": "jet", "l": 20.0, "d": 2.4, "t": [1.0, 1.9], "a": "Walk", "st": "choc", "sd": 0.5},
	"elec_chute": {"e": "electricite", "k": "jet", "l": 0.0, "d": 3.2, "t": [1.15, 1.6, 2.6], "chute": 0.8, "st": "choc", "sd": 0.5},
	"elec_apres": {"e": "electricite", "k": "jet", "l": 15.0, "d": 1.4, "t": [1.2, 1.6, 2.2, 3.4, 5.0], "st": "choc", "sd": 0.5},
	"elec_chaine": {"e": "electricite", "k": "chaine", "l": 10.0, "d": 0.0, "t": [0.16, 0.3, 0.6, 1.4, 3.0], "st": "choc", "sd": 0.5, "f": 0.7, "tirs": [0.1]},
	"glace_lance": {"e": "glace", "k": "proj", "l": 0.0, "t": [0.25, 0.45, 1.2, 3.6, 4.6], "forme": "lance", "v": 30.0, "n": 1, "st": "gel", "sd": 3.0, "sp": 0.45, "f": 0.8, "tirs": [0.1]},
	"glace_eclat": {"e": "glace", "k": "proj", "l": 0.0, "t": [0.22, 0.4, 1.2], "forme": "eclat", "v": 34.0, "n": 3, "st": "gel", "sd": 2.5, "sp": 0.25, "f": 0.8, "tirs": [0.1]},
	"glace_trois_quarts": {"e": "glace", "k": "proj", "l": 45.0, "t": [0.45, 1.2], "forme": "lance", "v": 30.0, "n": 1, "st": "gel", "sd": 3.0, "sp": 0.45, "f": 0.8, "tirs": [0.1]},
	"glace_profil": {"e": "glace", "k": "proj", "l": 90.0, "t": [0.45, 1.2], "forme": "lance", "v": 30.0, "n": 1, "st": "gel", "sd": 3.0, "sp": 0.45, "f": 0.8, "tirs": [0.1]},
	"glace_marche": {"e": "glace", "k": "proj", "l": 20.0, "t": [0.6, 1.5], "a": "Walk", "forme": "lance", "v": 30.0, "n": 1, "st": "gel", "sd": 3.0, "sp": 0.45, "f": 0.8, "tirs": [0.1, 0.9]},
	"glace_chute": {"e": "glace", "k": "proj", "l": 0.0, "t": [1.15, 1.6, 2.6], "chute": 0.8, "forme": "lance", "v": 30.0, "n": 1, "st": "gel", "sd": 3.0, "sp": 0.45, "f": 0.8, "tirs": [0.1, 0.5]},
	"glace_nova": {"e": "glace", "k": "nova", "l": 0.0, "t": [0.3, 0.8, 2.0, 4.4, 5.6], "st": "gel", "sd": 4.0, "sp": 0.55, "tirs": [0.1]},
	"drain_face": {"e": "tenebres", "k": "jet", "l": 0.0, "d": 2.0, "t": [0.4, 1.3], "st": "corruption", "sd": 3.0},
	"drain_trois_quarts": {"e": "tenebres", "k": "jet", "l": 45.0, "d": 2.0, "t": [1.3], "st": "corruption", "sd": 3.0},
	"drain_profil": {"e": "tenebres", "k": "jet", "l": 90.0, "d": 2.0, "t": [1.3], "st": "corruption", "sd": 3.0},
	"drain_marche": {"e": "tenebres", "k": "jet", "l": 20.0, "d": 2.4, "t": [1.0, 1.9], "a": "Walk", "st": "corruption", "sd": 3.0},
	"drain_chute": {"e": "tenebres", "k": "jet", "l": 0.0, "d": 3.2, "t": [1.15, 1.6, 2.6], "chute": 0.8, "st": "corruption", "sd": 3.0},
	"drain_apres": {"e": "tenebres", "k": "jet", "l": 15.0, "d": 1.4, "t": [1.2, 1.7, 2.6, 4.6, 6.4], "st": "corruption", "sd": 3.0},
	"ombre_trait": {"e": "tenebres", "k": "proj", "l": 0.0, "t": [0.2, 0.4, 1.4, 5.4, 6.6], "forme": "trait", "v": 30.0, "n": 1, "st": "corruption", "sd": 5.0, "f": 0.8, "tirs": [0.1]},
	"ombre_trait_profil": {"e": "tenebres", "k": "proj", "l": 90.0, "t": [0.4, 1.4], "forme": "trait", "v": 30.0, "n": 1, "st": "corruption", "sd": 5.0, "f": 0.8, "tirs": [0.1]},
	# jet de flammes (socle + FeuCorps) : la couverture grandit avec la durée du jet, puis brûlure (film ralenti : --film=feu_face)
	"feu_face": {"e": "feu", "k": "jet", "l": 0.0, "d": 2.4, "t": [0.3, 1.2, 2.3, 3.4], "st": "brulure", "sd": 3.0},
	"boule_face": {"e": "feu", "k": "proj", "l": 0.0, "t": [0.3, 0.45, 0.8, 2.2, 4.5], "forme": "boule", "v": 24.0, "n": 1, "st": "brulure", "sd": 3.0, "f": 1.6, "zone": 2.2, "tirs": [0.1]},
	"boule_trois_quarts": {"e": "feu", "k": "proj", "l": 45.0, "t": [0.45, 0.8], "forme": "boule", "v": 24.0, "n": 1, "st": "brulure", "sd": 3.0, "f": 1.6, "zone": 2.2, "tirs": [0.1]},
}

var g: Node3D
var sortie := ""
var cote := false
var cam_cote: Camera3D
var film := ""
var _projs: Array = []      # {n: Node3D, dir, v, cas, fait}

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	sortie = _arg("sortie", "res://captures/impact_ecoles")
	cote = _arg("cote") != ""
	film = _arg("film")
	ImpactCorps.actif = _arg("sans-impact-corps") == ""
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	g = GALERIE.instantiate()
	root.add_child(g)
	current_scene = g
	for k in 90:
		await process_frame
	# maillages des draugrs lus d'avance (comme en jeu : préchauffe), sinon le premier cas tourne sur le repli en capsules
	var t0 := Time.get_ticks_msec()
	while not SurfaceCorps.pret(g.cibles[1]) and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	var liste := _arg("cas")
	if film != "":
		liste = film
	for nom: String in CAS:
		if liste != "" and not liste.split(",").has(nom):
			continue
		await _cas(nom)
	print("CAPTURES_IMPACT_ECOLES fini : ", sortie, " ", EffetsMagie.stats(), " ", ImpactCorps.stats())
	quit()

func _cas(nom: String) -> void:
	var c: Dictionary = CAS[nom]
	var ecole: String = c.e
	var cibles: Array = g.cibles
	var d: Node3D = cibles[1]
	EffetsMagie.tout_arreter()
	for k in 40:
		await process_frame
	for x: Node3D in cibles:
		x.visible = x == d
	d.position = Vector3(0.0, 0.0, -4.3)
	d.rotation = Vector3(0.0, deg_to_rad(float(c.l)), 0.0)
	var ap := d.find_child("Animations", true, false) as AnimationPlayer
	var anim: String = c.get("a", "Idle")
	if ap != null and ap.has_animation(anim):
		ap.play(anim)
	for k in 20:
		await process_frame
	var t := 0.0
	var instants: Array = (c.t as Array).duplicate()
	var duree := float(c.get("d", 0.0))
	var tirs: Array = (c.get("tirs", []) as Array).duplicate()
	var tombe := false
	var paume_g: Node3D = g.paume_g
	var fin := float(instants.back()) + 0.1
	var t_statut := -1.0
	var image := 0
	while t < fin:
		var dt := 1.0 / 60.0
		t += dt
		var actif: bool = c.k == "jet" and t > 0.05 and t < duree
		if c.has("a") and anim == "Walk":
			d.position += Basis(Vector3.UP, d.rotation.y).z * dt * 0.9
		if c.has("chute") and t > float(c.chute) and not tombe:
			tombe = true
			var rd := Ragdoll.equiper(d) as Ragdoll
			if rd != null:
				rd.declencher(Vector3(0.3, 0.6, -1.0) * 60.0, d.global_position + Vector3.UP * 1.3)
		var vise: Vector3 = d.global_position + Vector3.UP * (1.1 if not tombe else 0.5)
		var dir := (vise - paume_g.global_position).normalized()
		EffetsMagie.aura_main(paume_g, ecole, 1.0 if (actif or c.k != "jet") else 0.4)
		if c.k == "jet":
			EffetsMagie.jet(ecole, paume_g, dir, 8.0, 0.6, actif)
			# la logique pose le statut à chaque tic (0,2 s) du jet
			if actif and t > 0.2 and t - t_statut >= 0.2:
				t_statut = t
				_statut(d, c)
		elif not tirs.is_empty() and t >= float(tirs[0]):
			tirs.pop_front()
			match String(c.k):
				"proj":
					_tirer(c, paume_g.global_position, dir)
				"chaine":
					# même ordre que LanceurSorts._chaine : coup (statut) et impact sur chaque cible, puis la chaîne
					var centre := Elements._centre(d)
					_statut(d, c)
					EffetsMagie.impact(ecole, centre, (paume_g.global_position - centre).normalized(), float(c.f))
					EffetsMagie.chaine(ecole, [paume_g.global_position, centre] as Array[Vector3])
				"nova":
					EffetsMagie.zone(ecole, paume_g.global_position + Vector3.DOWN * 1.3, 4.5, 0.6)
					_statut(d, c)
		_voler(dt, d)
		await process_frame
		image += 1
		if film != "" and image % 2 == 0:
			await _capturer("%s_film_%04d" % [nom, image / 2], d, false)
		if not instants.is_empty() and t >= float(instants[0]):
			await _capturer("%s_%.2f" % [nom, float(instants[0])], d, cote)
			instants.pop_front()
	EffetsMagie.aura_main(paume_g, ecole, 0.0)
	for st in ["brulure", "gel", "choc", "corruption"]:
		EffetsMagie.statut_cible(d, st, 0.0)
	var sts := Statuts.de(d, false)
	if sts != null:
		for st in ["brulure", "gel", "choc", "corruption"]:
			sts.retirer(st)
	if tombe:
		var neuf := DraugrNordique.creer({})
		g.add_child(neuf)
		neuf.add_to_group("cibles_magie")
		cibles[1] = neuf
		d.queue_free()

func _statut(d: Node3D, c: Dictionary) -> void:
	if c.st == "gel":
		# le gel passe par Statuts (sa puissance règle la couverture du givre)
		Statuts.de(d).appliquer("gel", float(c.sd), float(c.get("sp", 0.3)))
	else:
		EffetsMagie.statut_cible(d, String(c.st), float(c.sd))

## Projectile comme ProjectileSort : visuel EffetsMagie, vol tendu, touche quand il passe à moins de 0,55 m du centre du
## corps (point le plus proche de la trajectoire), puis impact (normale = -direction), zone éventuelle et statut.
func _tirer(c: Dictionary, depart: Vector3, dir: Vector3) -> void:
	var n := int(c.get("n", 1))
	for i in n:
		var dd := dir
		if n > 1:
			var ang := deg_to_rad(4.0) * (float(i) - float(n - 1) * 0.5)
			dd = dir.rotated(Vector3.UP, ang)
		var v := EffetsMagie.projectile_visuel(String(c.e), String(c.forme))
		var racine := Node3D.new()
		g.add_child(racine)
		racine.add_child(v)
		racine.global_position = depart
		_projs.append({"n": racine, "dir": dd, "v": float(c.v), "cas": c})

func _voler(dt: float, d: Node3D) -> void:
	var i := _projs.size() - 1
	while i >= 0:
		var p: Dictionary = _projs[i]
		var n: Node3D = p.n
		var de := n.global_position
		var vers: Vector3 = de + (p.dir as Vector3) * float(p.v) * dt
		var centre := Elements._centre(d)
		var proche := Geometry3D.get_closest_point_to_segment(centre, de, vers)
		if proche.distance_to(centre) <= 0.55:
			var c: Dictionary = p.cas
			EffetsMagie.impact(String(c.e), proche, -(p.dir as Vector3), float(c.f))
			if c.has("zone"):
				EffetsMagie.zone(String(c.e), proche, float(c.zone), 0.3)
			_statut(d, c)
			n.queue_free()
			_projs.remove_at(i)
		elif de.length() > 40.0:
			n.queue_free()
			_projs.remove_at(i)
		else:
			n.global_position = vers
		i -= 1

func _capturer(nom: String, d: Node3D, avec_cote: bool) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	img.save_png(sortie.path_join(nom + ".png"))
	if film == "":
		print("CAPTURE ", nom, " ", EffetsMagie.stats().particules, " part. ; corps ", ImpactCorps.stats())
	if _arg("debug") != "" and ImpactCorps.instance != null:
		for fo: ImpactCorps.Foyer in ImpactCorps.instance.foyers:
			if not fo.libre:
				print("  foyer ", fo.id, " ", fo.ecole, " imp_i=", fo.d.get("imp_i"), " imp=", fo.d.get("imp"), " rayon=", fo.d.get("rayon"), " gel=", fo.d.get("gel"), " o=", fo.origine(), " ec=", fo.d.get("_ec"))
	if avec_cote:
		if cam_cote == null:
			cam_cote = Camera3D.new()
			cam_cote.fov = 50.0
			g.add_child(cam_cote)
		var c0 := root.get_camera_3d()
		var cible := d.global_position + Vector3.UP * 1.0
		cam_cote.global_position = cible + Vector3(2.6, 0.5, 1.2)
		cam_cote.look_at(cible)
		cam_cote.make_current()
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(sortie.path_join(nom + "_cote.png"))
		if c0 != null:
			c0.make_current()
