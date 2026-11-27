extends SceneTree
## MESURE « MAIN À L'ÉCRAN » pendant le combo léger, en 1re personne (chantier combat/combo3_cadrage, 2026-11-27).
## Défaut A de l'exe 8 : au 3e coup du combo à une main, la main qui tient l'arme passe sous le bas de l'écran ~7 images.
## Chaque combo (4 clics, --fixed-fps 60) est joué image par image dans scenes/test_magie.tscn ; à CHAQUE image, la main
## droite est projetée par la caméra du joueur (unproject_position, écran 1280x720) en plusieurs points du squelette : poignet
## (origine de hand_r), jointures (index_01 / pinky_01), bout des doigts repliés (middle_03), sur la pose AFFICHÉE (après les
## modificateurs du squelette : BoneAttachment3D de la main). Une image est « main hors champ »
## quand le CENTRE de la main (moyenne poignet + jointures) sort de l'écran ; « main coupée » quand un des points sort.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://outils/mesure_main_combo.gd -- --nouvelle
##         --sortie=<dossier> [--seq=epee,dague,...] [--images]   (--images : chaque image du combo en PNG)
## Lignes : « IMG seq n coup clip t cx cy marge_bas_px dedans/4 », « SEQ seq coup k : hors=… coupee=… marge_min=… » ;
## criteres.csv dans --sortie. Code 1 si une image du COUP 3 a la main hors champ (critère du défaut A : 0).
const SCENE := preload("res://scenes/test_magie.tscn")
const CLICS4 := {0: ["appuyer"], 3: ["relacher"], 28: ["appuyer"], 31: ["relacher"], 56: ["appuyer"], 59: ["relacher"], 84: ["appuyer"], 87: ["relacher"]}
## rythme posé : chaque clic après la fin du coup précédent (coup 3 lancé depuis la garde)
const CLICS4_LENT := {0: ["appuyer"], 3: ["relacher"], 40: ["appuyer"], 43: ["relacher"], 80: ["appuyer"], 83: ["relacher"], 120: ["appuyer"], 123: ["relacher"]}

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var m: MainSort
var sortie := ""
var _csv: PackedStringArray = ["sequence,image,coup,clip,t_clip,etat,poignet_x,poignet_y,centre_x,centre_y,marge_bas_px,points_dedans,recul_vm_y,frappe,angle_lame_deg"]
var _bilan: PackedStringArray = []
var _echec := 0
var _echec3 := 0   # coup 3 seul (défaut A)
var _angles3: Array = []   # angle de la lame à l'écran pendant la frappe du coup 3

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _seqs() -> Dictionary:
	return {
		"epee": ["epee", 2.4],
		"epee_lent": ["epee", 3.0, CLICS4_LENT],
		"epee_soldat": [CatalogueArmes.donnees("epee_soldat"), 2.4],
		"epee_longue": [CatalogueArmes.donnees("veilleuse"), 2.6],
		"dague": [CatalogueArmes.donnees("dague_acier"), 2.4],
		"masse": [CatalogueArmes.donnees("masse_cloutee"), 3.2],
		"marteau": [CatalogueArmes.donnees("marteau_guerre"), 3.2],
	}

func _monter() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	m = mains.magie
	if j.touche.is_connected(m._sur_touche):
		j.touche.disconnect(m._sur_touche)
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.visible = false
		cip.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("titre") != null:
		s.titre.visible = false
	if s.get("hud") != null:
		s.hud.visible = false

func _replacer() -> void:
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	j.velocity = Vector3.ZERO
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains._combo = 0
	mains.defense = DefenseJoueur.new()

func _os(nom: String) -> Vector3:
	var sq: Skeleton3D = mains._sq
	return sq.global_transform * sq.get_bone_global_pose(sq.find_bone(nom)).origin

func _sequence(nom: String, arme: Variant, duree: float, clics: Dictionary) -> void:
	m.equiper("droite", arme)
	m.equiper("gauche", "vide")
	_replacer()
	for i in 45:
		await process_frame
	var n := roundi(duree * 60.0)
	var garder := _arg("images") != ""
	var coup := 0
	var clip_prec := ""
	var par_coup := {}   # coup -> [images, hors, coupee, marge_min]
	for i in n:
		if clics.has(i):
			for a in clics[i]:
				if a == "appuyer":
					mains.entrees.appuyer()
				else:
					mains.entrees.relacher()
		await process_frame
		await RenderingServer.frame_post_draw
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		var taille := cam.get_viewport().get_visible_rect().size
		var en_coup: bool = mains.combat.etat == EtatCombat.ATTAQUE_LEGERE
		var clip: String = mains.anim.clip
		if en_coup and clip != clip_prec:
			coup += 1
		clip_prec = clip if en_coup else ""
		# main AFFICHÉE : get_bone_global_pose lu hors de la passe des modificateurs rend la pose SANS eux (suivi d'épaule de la
		# récupération, couche passive…) ; le BoneAttachment3D de la main (_accroche_d, qui porte l'arme) suit la pose finale.
		# Les doigts sont rigides dans le repère de la main : points de la main = repère affiché de hand_r × leur place locale.
		var sq: Skeleton3D = mains._sq
		var main_g: Transform3D = (mains._accroche_d as Node3D).global_transform
		var main_inv := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r"))).affine_inverse()
		var pts := [main_g.origin]
		for o in ["index_01_r", "pinky_01_r", "middle_03_r"]:
			pts.append(main_g * (main_inv * _os(o)))
		var dedans := 0
		var px: Array[Vector2] = []
		for p: Vector3 in pts:
			var e := cam.unproject_position(p)
			px.append(e)
			if not cam.is_position_behind(p) and e.x >= 0.0 and e.x <= taille.x and e.y >= 0.0 and e.y <= taille.y:
				dedans += 1
		var centre := (px[0] + px[1] + px[2]) / 3.0
		var marge := taille.y - centre.y   # > 0 : centre de la main au-dessus du bord bas
		var hors := centre.x < 0.0 or centre.x > taille.x or centre.y < 0.0 or centre.y > taille.y
		var bras: Node3D = mains.bras
		var recul: Vector3 = bras.get_meta("recul_vm", Vector3.ZERO)
		var etat: String = EtatCombat.NOMS[mains.combat.etat]
		# récupération (suivi puis retour) comptée avec le coup qu'elle termine, à part : « tout le long du coup »
		var en_recup: bool = mains.combat.etat == EtatCombat.RECUPERATION and coup > 0
		var k := coup if (en_coup or en_recup) else 0
		var acc := cam.unproject_position((mains._accroche_d as Node3D).global_position)
		# lame à l'écran : angle de la droite garde -> pointe depuis la verticale (+ = pointe penchée vers la GAUCHE, sens de la
		# taille droite -> gauche), sur l'épée affichée (repère de la main affichée × prise)
		var epee_g: Transform3D = main_g * mains.anim.prise
		var eg := cam.unproject_position(epee_g * mains._garde_lame)
		var ep := cam.unproject_position(epee_g * mains._pointe_lame)
		var ang_lame := rad_to_deg(atan2(-(ep.x - eg.x), -(ep.y - eg.y)))
		print("IMG %s %03d coup=%d clip=%s t=%.3f %s poignet=(%.0f,%.0f) centre=(%.0f,%.0f) marge_bas=%.0f px dedans=%d/4 accroche=(%.0f,%.0f) lame=%+.0f°%s" % [nom, i, k, clip, mains.anim.t, etat, px[0].x, px[0].y, centre.x, centre.y, marge, dedans, acc.x, acc.y, ang_lame, " HORS" if ((en_coup or en_recup) and hors) else ""])
		var en_frappe: bool = en_coup and mains._m.has("frappe") and mains.anim.t >= float(mains._m["frappe"]) and mains.anim.t <= float(mains._m.get("fin_frappe", mains._m["frappe"]))
		_csv.append("%s,%d,%d,%s,%.4f,%s,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%.4f,%d,%.1f" % [nom, i, k, clip, mains.anim.t, etat, px[0].x, px[0].y, centre.x, centre.y, marge, dedans, recul.y, 1 if en_frappe else 0, ang_lame])
		if en_frappe and k == 3:
			_angles3.append(ang_lame)
		if en_coup or en_recup:
			if not par_coup.has(k):
				par_coup[k] = [0, 0, 0, INF, clip, 0, 0, INF]
			var c: Array = par_coup[k]
			var o := 0 if en_coup else 5   # attaque : 0..3 ; récupération : 5..7
			c[o] += 1
			c[o + 1] += 1 if hors else 0
			if en_coup:
				c[2] += 1 if dedans < 4 else 0
			c[o + (3 if en_coup else 2)] = minf(c[o + (3 if en_coup else 2)], marge)
		if garder:
			var img := root.get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(sortie.path_join(nom))
			img.save_png(sortie.path_join(nom).path_join("%03d.png" % i))
	if not _angles3.is_empty():
		var smin := 999.0
		var som := 0.0
		for a in _angles3:
			smin = minf(smin, a)
			som += a
		var l3 := "LAME %-12s coup 3 frappe : %d images, angle moyen %+.0f°, minimum %+.0f° (+ = penchée vers la gauche)" % [nom, _angles3.size(), som / _angles3.size(), smin]
		print(l3)
		_bilan.append(l3)
	_angles3.clear()
	for k in par_coup:
		var c: Array = par_coup[k]
		var ligne := "SEQ %-12s coup %d (%s) : attaque images=%d main_hors=%d main_coupee=%d marge_bas_min=%.0f px | recuperation images=%d main_hors=%d marge_bas_min=%.0f px" % [nom, k, c[4], c[0], c[1], c[2], c[3], c[5], c[6], c[7]]
		print(ligne)
		_bilan.append(ligne)
		_echec += c[1] + c[6]
		if k == 3:
			_echec3 += c[1] + c[6]

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("user://mesure_main_combo"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	await _monter()
	if _arg("clips") != "":
		# diagnostic : trajectoire du poignet À L'ÉCRAN dans les clips seuls (cinématique directe des pistes, sans fondu ni
		# recul du viewmodel), arme « epee »
		m.equiper("droite", "epee")
		for i in 30:
			await process_frame
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		var taille := cam.get_viewport().get_visible_rect().size
		for c in _arg("clips").split(","):
			var lg: float = mains.anim.longueur(c)
			var t := 0.0
			while t <= lg + 1e-4:
				var main_t: Transform3D = mains.global_transform * mains.anim.pose_arme(c, t) * mains.anim.prise.affine_inverse()
				var e := cam.unproject_position(main_t.origin)
				print("CLIP %s t=%.3f poignet=(%.0f,%.0f) marge_bas=%.0f px" % [c, t, e.x, e.y, taille.y - e.y])
				t += 1.0 / 60.0
		quit(0)
		return
	var toutes := _seqs()
	var choix: Array = Array(_arg("seq", "").split(",", false)) if _arg("seq") != "" else toutes.keys()
	for q in choix:
		if not toutes.has(q):
			print("SEQ inconnue ", q)
			continue
		await _sequence(q, toutes[q][0], toutes[q][1], toutes[q][2] if toutes[q].size() > 2 else CLICS4)
	var f := FileAccess.open(sortie.path_join("criteres.csv"), FileAccess.WRITE)
	f.store_string("\n".join(_csv) + "\n")
	f.close()
	f = FileAccess.open(sortie.path_join("bilan.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_bilan) + "\n")
	f.close()
	print("MESURE_MAIN_COMBO tous coups : %d images main hors champ ; coup 3 : %d" % [_echec, _echec3])
	print("MESURE_MAIN_COUP3 " + ("OK" if _echec3 == 0 else "ECHEC (%d images)" % _echec3))
	quit(0 if _echec3 == 0 else 1)
