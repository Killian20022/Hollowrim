extends SceneTree
## AUDIT « VIDE DU BRAS » en 1re personne (chantier combat/bras_vide_1p, 2026-11-25). Retour utilisateur : « en vue 1re
## personne, quand je donne un coup, on voit le vide du bras ».
## Chaque coup est joué image par image (--fixed-fps 60) dans scenes/test_magie.tscn ; à CHAQUE image, en plus du rendu normal,
## une copie de détection des bras (mêmes maillages skinnés, même squelette, calque 17 seul) est rendue dans un SubViewport
## à la caméra du joueur (même fov, même near) : face AVANT = vert, face ARRIÈRE = rouge (le bleu code la matière). Une face
## arrière visible = on regarde l'INTÉRIEUR du maillage (manche coupée, bout ouvert, coupe par le plan proche de la caméra).
## Le compte de pixels rouges (en % de l'écran, image 640x360) est imprimé par image, par matière, et les pires images sont
## gardées (rendu normal + carte de détection) pour la planche avant/après.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://outils/audit_bras_vide.gd -- --nouvelle --sortie=<dossier>
##         [--seq=epee,hache,...] [--images] [--gants=gants_fer_x]   (--images : chaque image en PNG pour les films ralentis)
## Lignes : « IMAGE seq n rouge% detail », « SEQ seq max% moy% images_touchees », « TOTAL ... » ; code 1 si une image dépasse
## --seuil (défaut 0 pixel : critère du brief, aucun pixel d'intérieur de bras).
const SCENE := preload("res://scenes/test_magie.tscn")
const CALQUE_DET := 1 << 16
## Pièces à UNE face, double face voulue (pas des volumes) : mèches de fourrure, boucles, rivets, plaques et sangles plates
## posées sur le brassard. Leur dos montre la même matière (jamais le vide ni l intérieur du bras) : compté à part (jaune).
const CARTES := ["ab_fourrure", "ab_fer", "ab_sangle", "ab_metal"]
const MATS := ["ab_gant", "ab_cuir", "ab_tresse", "ab_metal", "ab_fer", "ab_sangle", "ab_fourrure", "tunique", "sous_couche"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var m: MainSort
var sortie := ""
var dv: SubViewport
var dcam: Camera3D
var _copies: Array[MeshInstance3D] = []
var _sources := {}   # copie de détection -> maillage du jeu (pour recopier son fondu)
var _mat_det := {}
var _pires: Array = []      # [rouge, seq, n, image normale, image détection]
var _bilan: PackedStringArray = []
var _max_global := 0
var _seuil := 0
var _coeur_img := 0
var _tache_img := 0
var _tache_global := 0
var _manche_proche_img := 0.0
var _manche_proche_global := 0.0
var _coeur_global := 0
var _pos0 := Vector3.ZERO
var _lacet0 := 0.0
var _lut := PackedInt32Array()   # bleu (0-255, sRVB) -> indice de matière (0 = inconnue)

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _shader_det() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, depth_draw_opaque;
uniform float code = 0.0;
uniform bool carte = false;
const float TRAME_OEIL[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
instance uniform float fondu_bras = 1.0;   // même fondu en trame que le bras du jeu (AvantBras.regler_fondu), recopié
void fragment() {
	ivec2 q_oeil = ivec2(FRAGCOORD.xy) % 4;
	if (fondu_bras < 0.999 && fondu_bras < (TRAME_OEIL[q_oeil.y * 4 + q_oeil.x] + 0.5) / 16.0) {
		discard;
	}
	// vert du dos : position le long du bras (UV.y de la manche, 0 = épaule, 3,2 = coude) pour situer un défaut
	// rouge faible sur la face avant : bras à moins de 0,25 m de l'œil (« objet géant près de l'œil »)
	float proche = length(VERTEX) < 0.25 ? 0.12 : 0.0;
	ALBEDO = FRONT_FACING ? vec3(proche, 1.0, code) : (carte ? vec3(1.0, 1.0, code) : vec3(1.0, clamp(UV.y / 1.6, 0.0, 1.0) * 0.05, code));
}
"""
	return sh

var _mat_noir: ShaderMaterial
func _noir() -> ShaderMaterial:
	if _mat_noir == null:
		_mat_noir = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, fog_disabled;\nvoid fragment() { ALBEDO = vec3(0.0); }\n"
		_mat_noir.shader = sh
	return _mat_noir

func _materiau_det(nom: String) -> ShaderMaterial:
	if not _mat_det.has(nom):
		var k := MATS.find(nom) + 1
		var mm := ShaderMaterial.new()
		mm.shader = _shader_det()
		mm.set_shader_parameter("code", float(k) / 10.0)
		# fourrure : mèches en CARTES à une face, double face voulue (pas un volume) : leur dos est compté à part (jaune)
		mm.set_shader_parameter("carte", nom in CARTES)
		_mat_det[nom] = mm
	return _mat_det[nom]

## Copies de détection de tous les maillages de bras 1P (épée/sorts : mains.bras ; arc : arc._bras).
func _installer_copies() -> void:
	for c in _copies:
		if is_instance_valid(c):
			c.queue_free()
	_copies.clear()
	var racines: Array = [mains.bras]
	if j.arc != null and j.arc.get("_bras") != null:
		racines.append(j.arc._bras)
	for r: Node in racines:
		for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
			if mi.get_meta("det_bras", false):
				continue
			# les armes / torche / arc (tenus par BoneAttachment3D, sans peau) ne sont pas le bras : copies NOIRES, qui
			# cachent le bras là où l'arme le cache à l'écran (comme le fond, elles ne comptent pas)
			var occultant := mi.skin == null and _arg("armes") == ""   # --armes : les armes sont contrôlées aussi (code « ? »)
			var c := mi.duplicate() as MeshInstance3D
			c.set_meta("det_bras", true)
			c.layers = CALQUE_DET
			c.material_overlay = null
			c.material_override = null
			for k in c.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(k)
				var nom := mat.resource_name.get_slice(".", 0) if mat else ""
				c.set_surface_override_material(k, _noir() if occultant else _materiau_det(nom))
			mi.get_parent().add_child(c)
			c.transform = mi.transform
			c.skeleton = mi.skeleton
			c.skin = mi.skin
			_copies.append(c)
			_sources[c] = mi

func _faire_lut() -> void:
	_lut.resize(256)
	for b in 256:
		var best := 0
		var ecart := 999.0
		for k in MATS.size() + 1:
			var attendu := Color(0, 0, float(k) / 10.0).linear_to_srgb().b * 255.0
			if absf(attendu - b) < ecart:
				ecart = absf(attendu - b)
				best = k
		_lut[b] = best

func _monter() -> void:
	_faire_lut()
	if _arg("monde") != "":
		# conditions de VRAI jeu : le monde (foret_test : WorldEnvironment, brouillard, post-process, détail réglé)
		s = load("res://scenes/foret_test.tscn").instantiate()
		s.set_meta("test", true)
	else:
		s = SCENE.instantiate()
		s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in (600 if _arg("monde") != "" else 40):
		await process_frame
	m = mains.magie
	if m.eq.has_method("apprendre_tout"):
		m.eq.apprendre_tout()
	if j.touche.is_connected(m._sur_touche):
		j.touche.disconnect(m._sur_touche)
	# monde : pose de départ gardée (et tournée de --lacet degrés) ; chaque séquence y revient
	_pos0 = j.global_position
	_lacet0 = j.rotation.y + deg_to_rad(float(_arg("lacet", "0")))
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.visible = false
		cip.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("titre") != null:
		s.titre.visible = false
	if s.get("hud") != null:
		s.hud.visible = false
	if _arg("gants") != "":
		j.inventaire.ajouter(_arg("gants"), 1)
		j.equipement_corps.equiper(_arg("gants"))
		for i in 5:
			await process_frame
	dv = SubViewport.new()
	dv.size = root.get_visible_rect().size
	dv.transparent_bg = false
	dv.msaa_3d = Viewport.MSAA_DISABLED
	dv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(dv)
	dcam = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	dcam.environment = env
	dcam.cull_mask = CALQUE_DET
	dv.add_child(dcam)
	dcam.current = true
	_installer_copies()

func _suivre_camera() -> void:
	if _arg("near") != "":
		for cam: Camera3D in s.find_children("*", "Camera3D", true, false):
			cam.near = float(_arg("near"))
	var c: Camera3D = get_root().get_viewport().get_camera_3d()
	if c == null:
		c = j.camera
	dcam.global_transform = c.global_transform
	dcam.fov = c.fov
	dcam.near = c.near
	dcam.far = c.far
	dcam.keep_aspect = c.keep_aspect
	# la caméra du jeu ne voit jamais les copies de détection
	for c2: MeshInstance3D in _copies:
		if is_instance_valid(c2) and _sources.has(c2) and is_instance_valid(_sources[c2]) and c2.mesh.get_surface_count() > 0 \
				and (c2.get_surface_override_material(0) as ShaderMaterial).shader.code.contains("fondu_bras"):
			var a := float((_sources[c2] as MeshInstance3D).get_meta("fondu_bras", 1.0))
			if absf(float(c2.get_meta("fondu_bras", 1.0)) - a) > 0.001:
				c2.set_meta("fondu_bras", a)
				c2.set_instance_shader_parameter("fondu_bras", a)
	for cam: Camera3D in s.find_children("*", "Camera3D", true, false):
		cam.cull_mask &= ~CALQUE_DET
		if _arg("near") != "":   # essai : plan proche imposé à toutes les caméras du jeu
			cam.near = float(_arg("near"))

## Une image : avance le jeu d'une image (fixed-fps), rend, compte les pixels rouges de la détection.
func _image(seq: String, n: int, garder_images: bool) -> int:
	_suivre_camera()
	await process_frame
	_suivre_camera()
	await RenderingServer.frame_post_draw
	var det := dv.get_texture().get_image()
	det.convert(Image.FORMAT_RGB8)
	var w := det.get_width()
	var h := det.get_height()
	var rouges := 0
	var cartes := 0
	var proches := 0
	var proches_manche := 0
	var aire_manche := 0
	var pos_manche := 0.0
	var par := {}
	var donnees := det.get_data()
	for i in range(0, donnees.size(), 3):
		var r := donnees[i]
		var g := donnees[i + 1]
		if g > 150 and r < 135 and _lut[donnees[i + 2]] == MATS.find("tunique") + 1:
			aire_manche += 1
		if g > 150 and r > 55 and r < 135:
			proches += 1
			if _lut[donnees[i + 2]] == MATS.find("tunique") + 1:
				proches_manche += 1
		if r > 150 and g > 150:
			cartes += 1
		elif r > 150 and g < 90:
			rouges += 1
			var best: int = _lut[donnees[i + 2]]
			var nom: String = "?" if best == 0 else MATS[best - 1]
			if nom == "tunique":
				pos_manche += Color(0, float(g) / 255.0, 0).srgb_to_linear().g / 0.05
			par[nom] = int(par.get(nom, 0)) + 1
	# rouges « de contour » : un pixel rouge touchant le fond (noir) est le bord d'une silhouette fermée, où la face arrière
	# gagne parfois un pixel sur la face avant (tramage du contour, même matière à l'écran) ; un VIDE (manche ouverte, poignet
	# béant) fait une tache rouge avec un coeur. « coeur » = rouges dont les 8 voisins sont du bras : c'est le critère.
	var coeur := 0
	var tache := 0
	if rouges > 0:
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := (y * w + x) * 3
				if not (donnees[i] > 150 and donnees[i + 1] < 90):
					continue
				var plein := true
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var k: int = ((y + dy) * w + x + dx) * 3
						if donnees[k] < 40 and donnees[k + 1] < 40:
							plein = false
				if plein:
					coeur += 1
				# « tache » : rouge dont les 4 voisins sont rouges aussi (une fente de 1-2 px, couture ou contour, disparaît ;
				# un vide d'au moins 3 px de large reste)
				var r4 := true
				for d: int in [-3, 3, -w * 3, w * 3]:
					if not (donnees[i + d] > 150 and donnees[i + d + 1] < 90):
						r4 = false
				if r4:
					tache += 1
	var pct := 100.0 * rouges / float(w * h)
	var detail := ""
	if par.has("tunique"):
		detail += " manche_pos=%.2f(0 epaule,1 coude)" % (pos_manche / float(par["tunique"]))
	for k in par:
		detail += " %s=%d" % [k, par[k]]
	if _arg("trace-near") != "":
		print("NEAR ", root.get_viewport().get_camera_3d().near)
	var fondu_min := 1.0
	for c2 in _sources:
		if is_instance_valid(_sources[c2]):
			fondu_min = minf(fondu_min, float((_sources[c2] as MeshInstance3D).get_meta("fondu_bras", 1.0)))
	detail += " fondu=%.2f d_os=%.2f/%.2f" % [fondu_min, float(mains._sq.get_meta("d_os_l", 9.0)), float(mains._sq.get_meta("d_os_r", 9.0))]
	print("IMAGE %s %03d rouge=%d px (%.3f %%) coeur=%d tache=%d%s cartes_decor=%d proche25cm=%.2f%% manche_proche=%.2f%% manche_aire=%.2f%% etat=%s" % [seq, n, rouges, pct, coeur, tache, detail, cartes, 100.0 * proches / float(w * h), 100.0 * proches_manche / float(w * h), 100.0 * aire_manche / float(w * h), _etat()])
	if rouges > 0 or garder_images:
		var norm := root.get_viewport().get_texture().get_image()
		norm.convert(Image.FORMAT_RGB8)
		if garder_images:
			DirAccess.make_dir_recursive_absolute(sortie.path_join(seq))
			norm.save_png(sortie.path_join(seq).path_join("%03d.png" % n))
			det.save_png(sortie.path_join(seq).path_join("%03d_det.png" % n))
		if rouges > 0:
			_pires.append([rouges, seq, n, norm, det, par])
			_pires.sort_custom(func(a, b): return a[0] > b[0])
			if _pires.size() > 24:
				_pires.resize(24)
	_coeur_img = coeur
	_tache_img = tache
	_manche_proche_img = 100.0 * proches_manche / float(w * h)
	return rouges

func _etat() -> String:
	var t := ""
	if mains.combat.etat != EtatCombat.REPOS:
		t = String(mains._geste_nom) + "/" + EtatCombat.NOMS[mains.combat.etat]
	else:
		t = "repos"
	return t

func _replacer() -> void:
	if s.has_method("placer_joueur"):
		s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	else:
		j.global_position = _pos0
		j.rotation.y = _lacet0
		j.tete.rotation.x = 0.0
	j.velocity = Vector3.ZERO
	j.vie = j.vie_max
	j.mana = 9999.0
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	m.relacher("gauche")
	m.relacher("droite")
	m.recharges.clear()

## Séquence : `actions` = {image: [action...]} ; jouée `duree` s, chaque image comptée.
func _sequence(nom: String, droite: Variant, gauche: Variant, actions: Dictionary, duree: float) -> void:
	if droite != null:
		m.equiper("droite", droite)
	if gauche != null:
		m.equiper("gauche", gauche)
	_replacer()
	for i in 45:
		await process_frame
	_installer_copies()
	var n := roundi(duree * 60.0)
	var total := 0
	var maxi := 0
	var touchees := 0
	var coeur_max := 0
	var tache_max := 0
	var manche_proche_max := 0.0
	var garder := _arg("images") != ""
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
					"fin_garde":
						mains.entrees.forcer_garde(0.0)
					"coup_face":
						j.recevoir_coup(8.0, j.global_position + Vector3(0, 0, -1.4))
					"contre":
						mains.defense.contre = 0.6
					"vitesse_avant":
						j.velocity = Vector3(0, 0, -3.2)
					"vitesse_droite":
						j.velocity = Vector3(3.2, 0, 0)
					"vitesse_gauche":
						j.velocity = Vector3(-3.2, 0, 0)
					"vitesse_arriere":
						j.velocity = Vector3(0, 0, 2.5)
					"arret":
						j.velocity = Vector3.ZERO
					"sort_d":
						m.appuyer("droite")
					"sort_d_fin":
						m.relacher("droite")
					"sort_g":
						m.appuyer("gauche")
					"sort_g_fin":
						m.relacher("gauche")
					"arc_eq":
						j.inventaire.ajouter("arc_chasseur", 1)
						j.inventaire.ajouter("fleche", 20)
						j.arc.souris_reelle = false
						j.arc.equiper()
					"arc_tendre":
						j.arc.appuyer()
					"arc_lacher":
						j.arc.relacher()
					"arc_copies":
						_installer_copies()
					"bouclier_coup":
						mains.entrees.forcer_garde(1.2)
		var r := await _image(nom, i, garder)
		coeur_max = maxi_i(coeur_max, _coeur_img)
		tache_max = maxi_i(tache_max, _tache_img)
		manche_proche_max = maxf(manche_proche_max, _manche_proche_img)
		total += r
		maxi = maxi if maxi > r else r
		if r > 0:
			touchees += 1
	_max_global = maxi if maxi > _max_global else _max_global
	_coeur_global = maxi_i(_coeur_global, coeur_max)
	_tache_global = maxi_i(_tache_global, tache_max)
	_manche_proche_global = maxf(_manche_proche_global, manche_proche_max)
	var px := float(dv.size.x * dv.size.y)
	var ligne := "SEQ %-22s images=%d touchees=%d max=%d px (%.3f %%) moy=%.1f px coeur_max=%d px tache_max=%d px manche_proche_max=%.2f %%" % [nom, n, touchees, maxi, 100.0 * maxi / px, total / float(n), coeur_max, tache_max, manche_proche_max]
	print(ligne)
	_bilan.append(ligne)
	j.velocity = Vector3.ZERO
	mains.entrees.forcer_garde(0.0)
	m.relacher("gauche")
	m.relacher("droite")

const CLICS4 := {0: ["appuyer"], 3: ["relacher"], 28: ["appuyer"], 31: ["relacher"], 56: ["appuyer"], 59: ["relacher"], 84: ["appuyer"], 87: ["relacher"]}
const LOURD := {0: ["appuyer"], 52: ["relacher"]}

func _seqs() -> Dictionary:
	var epee := "epee"
	return {
		"epee_combo": [epee, "vide", CLICS4, 2.4],
		"epee_lourd": [epee, "vide", LOURD, 1.7],
		"epee_lourd_avant": [epee, "vide", {0: ["appuyer", "vitesse_avant"], 14: ["arret"], 52: ["relacher"]}, 1.7],
		"epee_lourd_droite": [epee, "vide", {0: ["appuyer", "vitesse_droite"], 14: ["arret"], 52: ["relacher"]}, 1.7],
		"epee_lourd_arriere": [epee, "vide", {0: ["appuyer", "vitesse_arriere"], 14: ["arret"], 52: ["relacher"]}, 1.7],
		"epee_garde_contre": [epee, "vide", {0: ["garde"], 8: ["coup_face"], 22: ["contre", "appuyer"], 25: ["relacher"]}, 1.4],
		"epee_torche_combo": [epee, "torche", CLICS4, 2.4],
		"hache_combo": [CatalogueArmes.donnees("hache_guerre"), "vide", CLICS4, 3.0],
		"hache_lourd": [CatalogueArmes.donnees("hache_guerre"), "vide", LOURD, 2.0],
		"hachette_combo": [CatalogueArmes.donnees("hachette"), "vide", CLICS4, 3.0],
		"masse_combo": [CatalogueArmes.donnees("masse_cloutee"), "vide", CLICS4, 3.2],
		"marteau_combo": [CatalogueArmes.donnees("marteau_guerre"), "vide", CLICS4, 3.2],
		"grand_marteau_combo": [CatalogueArmes.donnees("grand_marteau"), "vide", CLICS4, 4.0],
		"dague_combo": [CatalogueArmes.donnees("dague_acier"), "vide", CLICS4, 2.4],
		"epee_longue_combo": [CatalogueArmes.donnees("veilleuse"), "vide", CLICS4, 2.6],
		"claymore_combo": [CatalogueArmes.donnees("claymore"), "vide", CLICS4, 3.2],
		"claymore_lourd": [CatalogueArmes.donnees("claymore"), "vide", LOURD, 2.2],
		"mains_nues": ["vide", "vide", CLICS4, 2.4],
		"bouclier_combo": [epee, "bouclier", CLICS4, 2.4],
		"bouclier_garde_coup": [epee, "bouclier", {0: ["garde"], 10: ["coup_face"], 40: ["coup_face"], 60: ["fin_garde"], 62: ["appuyer"], 65: ["relacher"]}, 1.8],
		"sort_feu_d": ["boule_feu", "vide", {0: ["sort_d"], 50: ["sort_d_fin"]}, 1.8],
		"sort_jet_flammes_d": ["jet_flammes", "vide", {0: ["sort_d"], 60: ["sort_d_fin"]}, 1.6],
		"sort_glace_d": ["eclat_glace", "vide", {0: ["sort_d"], 4: ["sort_d_fin"], 50: ["sort_d"], 54: ["sort_d_fin"]}, 1.8],
		"sort_lance_givre_d": ["lance_givre", "vide", {0: ["sort_d"], 50: ["sort_d_fin"]}, 1.8],
		"sort_foudre_d": ["arc_electrique", "vide", {0: ["sort_d"], 50: ["sort_d_fin"]}, 1.6],
		"sort_ombre_d": ["trait_ombre", "vide", {0: ["sort_d"], 4: ["sort_d_fin"]}, 1.4],
		"sort_rayon_noir_d": ["rayon_noir", "vide", {0: ["sort_d"], 70: ["sort_d_fin"]}, 1.8],
		"sort_repulsion_d": ["repulsion", "vide", {0: ["sort_d"], 40: ["sort_d_fin"]}, 1.6],
		"sort_nova_g": ["epee", "nova_gelee", {0: ["sort_g"], 40: ["sort_g_fin"]}, 1.6],
		"sort_orage_g": ["epee", "orage_runique", {0: ["sort_g"], 50: ["sort_g_fin"]}, 1.8],
		"sort_feu_g_epee": ["epee", "boule_feu", {0: ["sort_g"], 50: ["sort_g_fin"], 70: ["appuyer"], 73: ["relacher"]}, 2.2],
		"sort_doubles": ["boule_feu", "boule_feu", {0: ["sort_d", "sort_g"], 50: ["sort_d_fin", "sort_g_fin"]}, 1.8],
		"arc_tir": ["vide", "vide", {0: ["arc_eq"], 30: ["arc_copies"], 40: ["arc_tendre"], 130: ["arc_lacher"], 170: ["arc_tendre"], 250: ["arc_lacher"]}, 4.8],
	}

func _planche() -> void:
	if _pires.is_empty():
		return
	var w := 320
	var h := 180
	var col := 4
	var n := mini(_pires.size(), 12)
	var p := Image.create(w * col, h * 2 * ceili(n / float(col)), false, Image.FORMAT_RGB8)
	for k in n:
		var e: Array = _pires[k]
		var a: Image = (e[3] as Image).duplicate()
		var d: Image = (e[4] as Image).duplicate()
		a.resize(w, h, Image.INTERPOLATE_NEAREST)
		d.resize(w, h, Image.INTERPOLATE_NEAREST)
		var x := (k % col) * w
		var y := (k / col) * h * 2
		p.blit_rect(a, Rect2i(0, 0, w, h), Vector2i(x, y))
		p.blit_rect(d, Rect2i(0, 0, w, h), Vector2i(x, y + h))
	p.save_png(sortie.path_join("pires_images.png"))
	var f := FileAccess.open(sortie.path_join("pires_images.txt"), FileAccess.WRITE)
	for k in n:
		var e: Array = _pires[k]
		f.store_line("%d  %s #%03d  %d px  %s" % [k + 1, e[1], e[2], e[0], str(e[5])])
		(e[3] as Image).save_png(sortie.path_join("pire_%02d_%s_%03d.png" % [k + 1, e[1], e[2]]))
		(e[4] as Image).save_png(sortie.path_join("pire_%02d_%s_%03d_det.png" % [k + 1, e[1], e[2]]))
	f.close()

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("user://audit_bras_vide"))
	_seuil = int(_arg("seuil", "0"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	await _monter()
	var toutes := _seqs()
	var choix: Array = Array(_arg("seq", "").split(",", false)) if _arg("seq") != "" else toutes.keys()
	for q in choix:
		if not toutes.has(q):
			print("SEQ inconnue ", q)
			continue
		var c: Array = toutes[q]
		await _sequence(q, c[0], c[1], c[2], c[3])
		if q == "arc_tir":
			j.arc.ranger()
	_planche()
	var f := FileAccess.open(sortie.path_join("bilan.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_bilan) + "\n")
	f.close()
	print("TOTAL max=%d px (contour compris), coeur_max=%d px, tache_max=%d px, manche_a_moins_de_25cm_max=%.2f %% de l'écran (critère <= 8) sur %d sequences" % [_max_global, _coeur_global, _tache_global, _manche_proche_global, choix.size()])
	print("AUDIT_BRAS_VIDE " + ("OK" if _coeur_global <= _seuil else "ECHEC"))
	quit(0 if _coeur_global <= _seuil else 1)

static func maxi_i(a: int, b: int) -> int:
	return a if a > b else b
