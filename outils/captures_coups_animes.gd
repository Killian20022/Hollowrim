extends SceneTree
## Preuves visuelles des coups animés à la main (bras droit joué par ses clips, AnimateurBras) dans scenes/test_combat.tscn.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_coups_animes.gd -- --sortie=<dossier> [--seq=combo,puissante,garde,...]
##     planches IMAGE PAR IMAGE (60 i/s, pas fixe) : <sortie>/<seq>.png, chaque vignette légendée (geste, étape, temps,
##     % de lame visible à l'écran, angle du plat avec l'œil) ; lignes MESURE imprimées.
##     Séquences : combo (A → B → C enchaînés), puissante (charge puis balayage), puissante_avant / _droite / _arriere,
##     garde (levée, parade parfaite, coup encaissé), contre, horizontale, revers, estoc.
##   ... -- --repos --sortie=<dossier> : pose de repos (jour) à côté de la référence (planche_combat_epee_1100.jpg),
##     angle de roulis mesuré (plat de la lame / direction de l'œil).
##   godot --path . --write-movie <fichier.avi> --fixed-fps 60 --script res://outils/captures_coups_animes.gd -- --film
##     [--ralenti=0.25] : combo A-B-C sur le mannequin, attaque puissante, garde avec parade parfaite, en continu.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const REFERENCE := "C:/Users/lopezk19/Jeux/references/combat_epee/planche_combat_epee_1100.jpg"

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _monter() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _placer() -> void:
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.7), 0.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	for i in 50:
		mains.avancer(DT)
	await process_frame
	await process_frame

## [% de la lame dans l'écran (devant la caméra), angle du plat avec l'œil (0 = plat face caméra, 90 = tranche),
## garde écran, pointe écran].
func _mesure() -> Array:
	var cam: Camera3D = j.camera
	var taille := root.get_viewport().get_visible_rect().size
	var xf: Transform3D = mains._modele_arme_d.global_transform
	var g: Vector3 = xf * mains._garde_lame
	var t: Vector3 = xf * mains._pointe_lame
	var vus := 0
	for i in 25:
		var p := g.lerp(t, i / 24.0)
		if cam.is_position_behind(p):
			continue
		var e := cam.unproject_position(p)
		if e.x >= 0 and e.y >= 0 and e.x < taille.x and e.y < taille.y:
			vus += 1
	var z := xf.basis.z.normalized()
	var oeil := (cam.global_position - (g + t) * 0.5).normalized()
	var plat := rad_to_deg(acos(clampf(absf(z.dot(oeil)), 0.0, 1.0)))
	var ge := Vector2(-9, -9) if cam.is_position_behind(g) else cam.unproject_position(g) / taille * 2.0 - Vector2.ONE
	var pe := Vector2(-9, -9) if cam.is_position_behind(t) else cam.unproject_position(t) / taille * 2.0 - Vector2.ONE
	return [100.0 * vus / 25.0, plat, Vector2(ge.x, -ge.y), Vector2(pe.x, -pe.y)]

func _etape() -> String:
	match mains.combat.etat:
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CONTRE:
			return "frappe" if mains._actif_lance else ("tension" if mains._t_geste >= mains._duree_prep else "arme")
		EtatCombat.RECUPERATION:
			return "suivi" if mains.combat.t < mains._duree_suivi else "retour"
		EtatCombat.CHARGE_LOURDE:
			return "charge"
		EtatCombat.GARDE, EtatCombat.PARADE:
			return mains.anim.clip
	return EtatCombat.NOMS[mains.combat.etat]

## Une image : légende + mesure + capture.
func _vue(seq: String, n: int, ms: float) -> Image:
	var m := _mesure()
	var geste: String = mains._geste_nom if mains.combat.etat != EtatCombat.REPOS else "repos"
	l.text = "%s #%02d %s %s %dms (clip %s %.3f)\nlame %d%%  plat %d deg" % [seq, n, geste, _etape(), roundi(ms), mains.anim.clip, mains.anim.t, roundi(m[0]), roundi(m[1])]
	print("MESURE %s #%02d %-14s %-8s %4dms clip %-14s t=%.3f lame %3d%% plat %2d garde %s pointe %s" % [seq, n, geste, _etape(), roundi(ms), mains.anim.clip, mains.anim.t, roundi(m[0]), roundi(m[1]), (m[2] as Vector2).snapped(Vector2.ONE * 0.01), (m[3] as Vector2).snapped(Vector2.ONE * 0.01)])
	await process_frame
	return await _image()

func _planche(nom: String, images: Array, colonnes := 8) -> void:
	var w := 320
	var h := 180
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for k in images.size():
		var im: Image = images[k]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % colonnes) * w, (k / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " ", images.size(), " images")

## Séquence pas à pas : `script` = [[image, action], …] (actions : appuyer, relacher, garde, coup_face, finir) ;
## capture chaque image (ou une sur `tous`) jusqu'à `duree` s.
func _sequence(nom: String, actions: Dictionary, duree: float, tous := 1, geste_force := "") -> void:
	await _placer()
	var images := []
	var n := roundi(duree / DT)
	for i in n:
		if actions.has(i):
			for a in actions[i]:
				match a:
					"appuyer":
						mains.entrees.appuyer()
					"relacher":
						mains.entrees.relacher()
					"garde":
						mains.entrees.forcer_garde(1.2)
					"coup_face":
						j.recevoir_coup(8.0, j.global_position + Vector3(0, 0, -1.4))
					"vitesse_avant":
						j.velocity = Vector3(0, 0, -3.2)
					"vitesse_droite":
						j.velocity = Vector3(3.2, 0, 0)
					"vitesse_arriere":
						j.velocity = Vector3(0, 0, 2.5)
					"arret":
						j.velocity = Vector3.ZERO
					"contre":
						mains.defense.contre = 0.6
		mains.avancer(DT)
		if i == 1 and geste_force != "":
			mains._geste_nom = geste_force
			mains._preparer_geste(false)
		if i % tous == 0:
			images.append(await _vue(nom, images.size() + 1, i * DT * 1000.0))
		else:
			await process_frame
	j.velocity = Vector3.ZERO
	await _planche(nom, images)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/coups_animes"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	await _monter()
	if _arg("film") != "":
		await _film(float(_arg("ralenti", "1")))
		quit()
		return
	mains.pas_manuel = true
	if _arg("repos") != "":
		await _repos()
		quit()
		return
	var seqs := Array(_arg("seq", "combo,puissante,garde").split(",", false))
	for q in seqs:
		match q:
			"combo":
				# A pressé, B pressé pendant la récupération de A, C pendant celle de B ; chaque image à 60 i/s
				await _sequence("combo", {0: ["appuyer"], 2: ["relacher"], 26: ["appuyer"], 28: ["relacher"], 50: ["appuyer"], 52: ["relacher"]}, 1.45)
			"puissante":
				await _sequence("puissante", {0: ["appuyer"], 52: ["relacher"]}, 1.6, 1)
			"puissante_avant":
				await _sequence("puissante_avant", {0: ["appuyer", "vitesse_avant"], 20: ["arret"], 52: ["relacher"]}, 1.6, 2)
			"puissante_droite":
				await _sequence("puissante_droite", {0: ["appuyer", "vitesse_droite"], 20: ["arret"], 52: ["relacher"]}, 1.6, 2)
			"puissante_arriere":
				await _sequence("puissante_arriere", {0: ["appuyer", "vitesse_arriere"], 20: ["arret"], 52: ["relacher"]}, 1.6, 2)
			"garde":
				await _sequence("garde", {0: ["garde"], 6: ["coup_face"], 40: ["coup_face"]}, 1.2, 1)
			"contre":
				await _sequence("contre", {0: ["garde"], 20: ["contre", "appuyer"], 22: ["relacher"]}, 1.0, 1)
			"horizontale", "revers", "estoc":
				var g: String = {"horizontale": "horizontale", "revers": "diag_gd", "estoc": "estoc"}[q]
				await _sequence(q, {0: ["appuyer"], 2: ["relacher"]}, 0.55, 1, g)
	quit()

## Repos à côté de la référence (même hauteur), angle de roulis mesuré.
func _repos() -> void:
	await _placer()
	for i in 60:
		mains.avancer(DT)
	l.text = ""
	var m := _mesure()
	var jeu := await _image()
	jeu.convert(Image.FORMAT_RGBA8)
	var h := 540
	jeu.resize(roundi(jeu.get_width() * h / float(jeu.get_height())), h, Image.INTERPOLATE_BILINEAR)
	var ref := Image.load_from_file(REFERENCE)
	ref.convert(Image.FORMAT_RGBA8)
	# vignette « épée en métal » de la planche (coin haut gauche) et « interface en jeu » (bas gauche)
	var a := ref.get_region(Rect2i(0, 40, 216, 230))
	a.resize(roundi(216 * h / 230.0), h, Image.INTERPOLATE_BILINEAR)
	var b := ref.get_region(Rect2i(0, 470, 515, 263))
	b.resize(roundi(515 * h / 263.0), h, Image.INTERPOLATE_BILINEAR)
	var p := Image.create(jeu.get_width() + a.get_width() + b.get_width(), h, false, Image.FORMAT_RGBA8)
	p.blit_rect(jeu, Rect2i(Vector2i.ZERO, jeu.get_size()), Vector2i.ZERO)
	p.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(jeu.get_width(), 0))
	p.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(jeu.get_width() + a.get_width(), 0))
	p.save_png(sortie.path_join("repos_reference.png"))
	jeu.save_png(sortie.path_join("repos_jeu.png"))
	print("REPOS lame %d %% visible, plat / oeil %.1f deg (0 = plat face caméra, 90 = tranche), garde %s pointe %s" % [roundi(m[0]), m[1], m[2], m[3]])

## Film en continu (Movie Maker, temps réel du jeu ; ralenti < 1 : Engine.time_scale).
func _film(ralenti: float) -> void:
	await _placer()
	mains.pas_manuel = false
	Engine.time_scale = ralenti
	var attendre := func(sec: float) -> void:
		await create_timer(sec, true, false, false).timeout
	l.text = "Coups legers A - B - C (enchaines)"
	await attendre.call(0.6)
	for k in 3:
		mains.entrees.appuyer()
		await attendre.call(0.05)
		mains.entrees.relacher()
		await attendre.call(0.40)
	await attendre.call(0.9)
	l.text = "Attaque puissante (maintien)"
	mains.entrees.appuyer()
	await attendre.call(0.9)
	mains.entrees.relacher()
	await attendre.call(1.4)
	l.text = "Garde, parade parfaite, coup encaisse"
	mains.entrees.forcer_garde(1.6)
	await attendre.call(0.1)
	j.recevoir_coup(8.0, j.global_position + Vector3(0, 0, -1.4))
	await attendre.call(0.7)
	j.recevoir_coup(8.0, j.global_position + Vector3(0, 0, -1.4))
	await attendre.call(1.2)
	Engine.time_scale = 1.0
