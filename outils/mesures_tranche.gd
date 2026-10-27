extends SceneTree
## Tenue « tranche » et traînée de lame : mesures image par image (et planches) dans scenes/test_combat.tscn.
##   godot --path . --script res://outils/mesures_tranche.gd -- [--images --sortie=<dossier>] [--seq=repos,marche,...]
##     [--arme=epee_or]
## Par image (60 i/s) : angle du plat avec l'œil (normale du plat / axe caméra → milieu de lame ; 0 = plat face caméra,
## 90 = tranche pure), part apparente du plat (cos de cet angle : largeur du plat vue / largeur maximale), garde et pointe
## à l'écran (x, y ∈ [-1, 1], +y en haut), « fil » pendant les coups (angle normale du plat / mouvement du milieu de
## lame à l'écran ; 90 = le tranchant mène, 0 = le plat mène), et écart traînée / lame (px sur 480x270) : la pointe et le
## milieu de l'échantillon de traînée le plus récent comparés à la vraie lame affichée (modèle accroché à l'os hand_r).
## --images : capture chaque image ; planche <sortie>/<seq>.png (vignettes légendées) + <seq>_reference.png (planche
## du jeu à côté de la bande « Animations et gameplay » de la référence planche_combat_epee_1100.jpg).
## Séquences : repos, marche, sprint, garde, combo (A → B → C), horizontale, revers, estoc, puissante, puissante_avant,
## puissante_droite, puissante_arriere, armes (repos des 5 épées).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const REFERENCE := "C:/Users/lopezk19/Jeux/references/combat_epee/planche_combat_epee_1100.jpg"
const REFERENCE_TENUE := "C:/Users/lopezk19/Jeux/references/combat_epee/tenue_epee_droite_1100.jpg"
const ARMES := ["epee_metal", "epee_or", "epee_rubis", "epee_verre", "epee_obsidienne"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var images_on := false
var l: Label
var _milieu_prec := Vector2.INF
var _mil3 := Vector3.ZERO
var _mil3_ok := false
var _vitesse := Vector3.ZERO
var resume := {}
var _coups: Array = []   # images de la frappe et du suivi (planche en grand)

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
	for i in 30:
		await process_frame
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)

func _placer() -> void:
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.7), 0.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	_vitesse = Vector3.ZERO
	for i in 50:
		mains.avancer(DT)
	await process_frame
	_milieu_prec = Vector2.INF
	_mil3_ok = false

func _ecran(p: Vector3) -> Vector2:
	var cam: Camera3D = j.camera
	var taille := root.get_viewport().get_visible_rect().size
	if cam.is_position_behind(p):
		return Vector2(-9, -9)
	var e := cam.unproject_position(p) / taille * 2.0 - Vector2.ONE
	return Vector2(e.x, -e.y)

## Écart écran en pixels 480x270 entre deux points écran normalisés.
func _px(a: Vector2, b: Vector2) -> float:
	return ((a - b) * Vector2(240, 135)).length()

func _mesure() -> Dictionary:
	var cam: Camera3D = j.camera
	var xf: Transform3D = mains._modele_arme_d.global_transform
	var g: Vector3 = xf * mains._garde_lame
	var t: Vector3 = xf * mains._pointe_lame
	var mil := (g + t) * 0.5
	var z := xf.basis.z.normalized()
	var oeil := (cam.global_position - mil).normalized()
	var plat := rad_to_deg(acos(clampf(absf(z.dot(oeil)), 0.0, 1.0)))
	var gd: Vector2 = _ecran(g)
	var pd: Vector2 = _ecran(t)
	var v := (pd - gd) * Vector2(16.0, 9.0)   # pixels (16:9)
	# angle de la lame avec la verticale de l'écran (degrés ; + = pointe penchée vers la gauche / le centre)
	var vert := rad_to_deg(atan2(-v.x, v.y)) if v.y > 0.0 else 180.0
	var r := {"vert": vert, "poing_d": _ecran(mains._modele_arme_d.global_position), "poing_g": _ecran(mains.porte_torche.global_position), "plat": plat, "part": absf(z.dot(oeil)), "garde": _ecran(g), "pointe": _ecran(t), "milieu": _ecran(mil)}
	# fil : angle entre la normale du plat et le mouvement 3D du milieu de lame (repère de la caméra) ; 90 = le
	# tranchant mène, 0 = le plat mène
	var mc: Vector3 = cam.global_transform.affine_inverse() * mil
	var zc: Vector3 = cam.global_transform.basis.inverse() * z
	r["fil"] = -1.0
	if _mil3_ok and (mc - _mil3).length() > 0.004:
		r["fil"] = rad_to_deg(acos(clampf(absf(zc.normalized().dot((mc - _mil3).normalized())), 0.0, 1.0)))
	_mil3 = mc
	_mil3_ok = true
	var me: Vector2 = r["milieu"]
	_milieu_prec = me
	# traînée : échantillon le plus récent (repère des mains) comparé à la lame affichée
	r["ecart_pointe"] = -1.0
	r["ecart_milieu"] = -1.0
	var ech: Array = mains.trainee._ech
	if not ech.is_empty():
		var e: Array = ech[ech.size() - 1]
		if mains.trainee._horloge - float(e[0]) < 0.02:
			var m: Transform3D = mains.global_transform
			var tg: Vector3 = m * (e[1] as Vector3)
			var tp: Vector3 = m * (e[2] as Vector3)
			r["ecart_pointe"] = _px(_ecran(tp), r["pointe"])
			r["ecart_milieu"] = _px(_ecran((tg + tp) * 0.5), r["milieu"])
		r["nb_trainee"] = ech.size()
	# cinématique directe du clip (ce que le tracé et la traînée échantillonnent) / pose affichée (fondus compris)
	var fk: Transform3D = mains.global_transform * mains.anim.pose_arme(mains.anim.clip, mains.anim.t)
	var af: Transform3D = mains.global_transform * mains.anim.pose_affichee()
	r["ecart_fk"] = _px(_ecran(fk * mains._pointe_lame), _ecran(af * mains._pointe_lame))
	r["larg"] = _largeur_apparente(gd, pd)
	return r

## Largeur apparente de la lame (px sur 480x270) à mi-longueur : sommets de la maille « lame » pris entre 40 et 55 %
## de la lame, projetés, étendue perpendiculaire à la lame vue à l'écran (tranche + plat en biais + épaisseur).
var _sommets_lame := {}
func _largeur_apparente(gd: Vector2, pd: Vector2) -> float:
	var mi: MeshInstance3D = null
	for n in mains._modele_arme_d.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).begins_with("lame"):
			mi = n
			break
	if mi == null:
		return -1.0
	if not _sommets_lame.has(mi.mesh):
		var g: Vector3 = mains._garde_lame
		var t: Vector3 = mains._pointe_lame
		var pts := PackedVector3Array()
		var loc: Transform3D = mains._modele_arme_d.global_transform.affine_inverse() * mi.global_transform
		for k in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
				var q: Vector3 = loc * v
				var f: float = (q - g).dot(t - g) / (t - g).length_squared()
				if f > 0.40 and f < 0.55:
					pts.append(q)
		_sommets_lame[mi.mesh] = pts
	var dir := ((pd - gd) * Vector2(240, 135)).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var lo := INF
	var hi := -INF
	var xf: Transform3D = mains._modele_arme_d.global_transform
	for q: Vector3 in _sommets_lame[mi.mesh]:
		var e := _ecran(xf * q) * Vector2(240, 135)
		lo = minf(lo, e.dot(perp))
		hi = maxf(hi, e.dot(perp))
	return hi - lo if hi > lo else -1.0

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

func _cumul(seq: String, etape: String, m: Dictionary) -> void:
	var cle := seq + " " + etape
	if not resume.has(cle):
		resume[cle] = {"plat": [], "fil": [], "ep": [], "em": [], "mx": [], "my": [], "vert": []}
	var c: Dictionary = resume[cle]
	c["plat"].append(m["plat"])
	c["vert"].append(m["vert"])
	if m["fil"] >= 0.0:
		c["fil"].append(m["fil"])
	if m["ecart_pointe"] >= 0.0:
		c["ep"].append(m["ecart_pointe"])
		c["em"].append(m["ecart_milieu"])
	c["mx"].append((m["milieu"] as Vector2).x)
	c["my"].append((m["milieu"] as Vector2).y)

func _vue(seq: String, n: int, ms: float, images: Array) -> void:
	await process_frame   # squelette et accroche de l'épée mis à jour (ce que l'image montre)
	var m := _mesure()
	var geste: String = mains._geste_nom if mains.combat.etat not in [EtatCombat.REPOS, EtatCombat.MOUVEMENT] else seq
	var et := _etape()
	_cumul(seq, et, m)
	print("MESURE %s #%02d %-13s %-7s %4dms clip %-14s t=%.3f plat %4.1f part %3d%% vert %5.1f poings d %s g %s fil %5.1f garde %s pointe %s trainee pointe %5.1fpx milieu %5.1fpx fk %5.1fpx larg %4.1fpx" % [seq, n, geste, et, roundi(ms), mains.anim.clip, mains.anim.t, m["plat"], roundi(100.0 * m["part"]), m["vert"], (m["poing_d"] as Vector2).snapped(Vector2.ONE * 0.01), (m["poing_g"] as Vector2).snapped(Vector2.ONE * 0.01), m["fil"], (m["garde"] as Vector2).snapped(Vector2.ONE * 0.01), (m["pointe"] as Vector2).snapped(Vector2.ONE * 0.01), m["ecart_pointe"], m["ecart_milieu"], m["ecart_fk"], m["larg"]])
	if images_on:
		l.text = "%s #%02d %s %s %dms\nplat/oeil %d deg (plat %d%%) vert %d%s" % [seq, n, geste, et, roundi(ms), roundi(m["plat"]), roundi(100.0 * m["part"]), roundi(m["vert"]), (" fil %d" % roundi(m["fil"])) if m["fil"] >= 0.0 else ""]
		await RenderingServer.frame_post_draw
		images.append(root.get_viewport().get_texture().get_image())
		if et in ["frappe", "suivi"] or (et == "tension" and seq != "garde"):
			_coups.append(images[images.size() - 1])

func _planche(nom: String, images: Array, colonnes := 8) -> void:
	if images.is_empty():
		return
	var w := 320
	var h := 180
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for k in images.size():
		var im: Image = images[k]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % colonnes) * w, (k / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	# à côté de la référence : bande « animations et gameplay » de la planche (même largeur)
	var ref := Image.load_from_file(REFERENCE)
	ref.convert(Image.FORMAT_RGBA8)
	var bande := ref.get_region(Rect2i(0, 300, 1100, 165))
	bande.resize(p.get_width(), roundi(165.0 * p.get_width() / 1100.0), Image.INTERPOLATE_BILINEAR)
	var q := Image.create(p.get_width(), p.get_height() + bande.get_height(), false, Image.FORMAT_RGBA8)
	q.blit_rect(bande, Rect2i(Vector2i.ZERO, bande.get_size()), Vector2i.ZERO)
	q.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(0, bande.get_height()))
	q.save_png(sortie.path_join(nom + "_reference.png"))
	print("PLANCHE ", nom, " ", images.size(), " images")

func _sequence(nom: String, actions: Dictionary, duree: float, geste_force := "", tous := 1) -> void:
	await _placer()
	_coups = []
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
						mains.entrees.forcer_garde(duree)
					"vitesse_avant":
						_vitesse = Vector3(0, 0, -3.2)
					"vitesse_droite":
						_vitesse = Vector3(3.2, 0, 0)
					"vitesse_arriere":
						_vitesse = Vector3(0, 0, 2.5)
					"marche":
						_vitesse = Vector3(0, 0, -2.2)
					"sprint":
						_vitesse = Vector3(0, 0, -6.0)
					"arret":
						_vitesse = Vector3.ZERO
		j.velocity = _vitesse
		mains.avancer(DT)
		if i == 1 and geste_force != "":
			mains._geste_nom = geste_force
			mains._preparer_geste(false)
		if i % tous == 0:
			await _vue(nom, i / tous + 1, i * DT * 1000.0, images)
		else:
			await process_frame
	_vitesse = Vector3.ZERO
	j.velocity = Vector3.ZERO
	if images_on and nom in ["repos", "marche", "garde", "sprint"] and not images.is_empty():
		_cote_a_cote(nom + "_tenue_reference", images[images.size() - 1])
	if not _coups.is_empty():
		await _planche_grande(nom + "_frappe", _coups)
	_coups = []
	await _planche(nom, images)

## Planche en grand (480x270 par vignette) des images de la frappe : pour juger la traînée.
func _planche_grande(nom: String, images: Array, colonnes := 5) -> void:
	var w := 480
	var h := 270
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for k in images.size():
		var im: Image = (images[k] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % colonnes) * w, (k / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))

## Image du jeu à côté de la référence de tenue (même hauteur 540).
func _cote_a_cote(nom: String, jeu: Image) -> void:
	var a := jeu.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	a.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var ref := Image.load_from_file(REFERENCE_TENUE)
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var p := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
	p.blit_rect(a, Rect2i(0, 0, 960, 540), Vector2i.ZERO)
	p.blit_rect(ref, Rect2i(0, 0, 960, 540), Vector2i(960, 0))
	p.save_png(sortie.path_join(nom + ".png"))
	a.save_png(sortie.path_join(nom.replace("_tenue_reference", "") + "_jeu.png"))

func _armes() -> void:
	var images := []
	for a in ARMES:
		mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % a))
		await _placer()
		for i in 40:
			mains.avancer(DT)
		await _vue("armes_" + a, 1, 0.0, images)
	mains.equipement.equiper("droite", load("res://data/armes/epee_metal.tres"))
	await _planche("armes", images, 5)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/tranche_trainee"))
	images_on = _arg("images") != ""
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	await _monter()
	mains.pas_manuel = true
	if _arg("arme") != "":
		mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % _arg("arme")))
	var seqs := Array(_arg("seq", "repos,marche,sprint,garde,combo,horizontale,revers,estoc,puissante,armes").split(",", false))
	for q in seqs:
		match q:
			"repos":
				await _sequence("repos", {}, 0.5, "", 6)
			"marche":
				await _sequence("marche", {0: ["marche"]}, 1.0, "", 4)
			"sprint":
				await _sequence("sprint", {0: ["sprint"]}, 1.0, "", 4)
			"garde":
				await _sequence("garde", {0: ["garde"]}, 0.6, "", 3)
			"combo":
				await _sequence("combo", {0: ["appuyer"], 2: ["relacher"], 26: ["appuyer"], 28: ["relacher"], 50: ["appuyer"], 52: ["relacher"]}, 1.45)
			"puissante":
				await _sequence("puissante", {0: ["appuyer"], 52: ["relacher"]}, 1.5)
			"puissante_avant":
				await _sequence("puissante_avant", {0: ["appuyer", "vitesse_avant"], 20: ["arret"], 52: ["relacher"]}, 1.5)
			"puissante_droite":
				await _sequence("puissante_droite", {0: ["appuyer", "vitesse_droite"], 20: ["arret"], 52: ["relacher"]}, 1.5)
			"puissante_arriere":
				await _sequence("puissante_arriere", {0: ["appuyer", "vitesse_arriere"], 20: ["arret"], 52: ["relacher"]}, 1.5)
			"horizontale", "revers", "estoc":
				var g: String = {"horizontale": "horizontale", "revers": "diag_gd", "estoc": "estoc"}[q]
				await _sequence(q, {0: ["appuyer"], 2: ["relacher"]}, 0.55, g)
			"armes":
				await _armes()
	var cles := resume.keys()
	cles.sort()
	for c in cles:
		var d: Dictionary = resume[c]
		var f := func(a: Array) -> String:
			return "-" if a.is_empty() else "%.0f..%.0f" % [a.min(), a.max()]
		var f2 := func(a: Array) -> String:
			return "-" if a.is_empty() else "%.2f..%.2f" % [a.min(), a.max()]
		print("RESUME %-26s vert %-9s plat %-8s fil %-8s ecart_trainee pointe %-8s milieu %-8s milieu_x %-11s milieu_y %s" % [c, f.call(d["vert"]), f.call(d["plat"]), f.call(d["fil"]), f.call(d["ep"]), f.call(d["em"]), f2.call(d["mx"]), f2.call(d["my"])])
	quit()
