extends Node3D
## Mains du joueur (enfant de la caméra) : épée à droite, torche à gauche.
## Clic gauche : coup léger (les coups alternent droite/gauche). Maintenir : coup puissant.
## Clic droit maintenu : garde (une garde levée juste avant l'impact = parade).
## T : sortir / ranger la torche.


const EPEE_NORDIQUE := preload("res://assets/modeles/joueur/epee_nordique.glb")
const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const ORIENTATION := preload("res://scripts/orientation_main.gd")
## Milieu de la poignée de l'épée le long de la lame (pommeau sous 0,005, garde au-dessus
## de 0,075) : l'index touche la garde, l'auriculaire mord sur le pommeau, à la viking.
const MILIEU_POIGNEE := 0.03
const POS_TORCHE := Vector3(-0.34, -0.44, -0.62)

enum { REPOS, ARMER, CHARGE, FRAPPE, RETOUR, GARDE, ENCAISSE }

const DEGATS_LEGER := 14.0
const DEGATS_PUISSANT := 34.0
const COUT_LEGER := 8.0
const COUT_PUISSANT := 26.0
const SEUIL_CHARGE := 0.28  # durée d'appui au-delà de laquelle le coup devient puissant

# poses de l'épée, à la manière de Skyrim (repère caméra : +X droite, +Y haut, -Z devant) :
# [position de la poignée, direction de la lame, côté du tranchant]. Coup de droite à gauche :
# armé au-dessus de l'épaule droite, tranchant en avant, la lame balaie devant soi et finit
# en bas à gauche. Le coup inverse utilise la pose miroir.
const POSES := {
	"repos": [Vector3(0.26, -0.30, -0.56), Vector3(-0.22, 0.82, -0.55), Vector3(-0.3, 0.0, -1.0)],
	"armer": [Vector3(0.36, -0.12, -0.58), Vector3(0.45, 0.85, 0.28), Vector3(0.28, 0.0, -0.45)],
	"charge": [Vector3(0.40, -0.06, -0.52), Vector3(0.45, 0.85, 0.36), Vector3(0.36, 0.0, -0.45)],
	"frappe": [Vector3(-0.16, -0.30, -0.60), Vector3(-0.85, -0.12, -0.50), Vector3(-0.50, 0.0, 0.85)],
	"garde": [Vector3(0.10, -0.20, -0.50), Vector3(-0.85, 0.42, -0.25), Vector3(0.0, 0.5, -1.0)],
	"encaisse": [Vector3(0.14, -0.13, -0.42), Vector3(-0.85, 0.52, -0.08), Vector3(0.0, 0.5, -1.0)],
}

var joueur: CharacterBody3D
var bloque := false
var temps_garde := 0.0
var torche_sortie := true

var etat := REPOS
var _t := 0.0
var _appui := -1.0
var _sens := 1.0
var _puissant := false
var _touche_faite := false
var _depuis_coup := 9.0
var _depart := Transform3D()
var _balance := Vector2.ZERO
var _respiration := 0.0
var _pose_figee := ""
var _baisse := 0.0
## Prises de l'épée et de la torche dans les mains (repère des os hand_r / hand_l),
## calculées sur le poing fermé (voir _calculer_prise).
var PRISE_D := Transform3D()
var PRISE_G := Transform3D()
var _acier: ShaderMaterial
var _mats := {}

var pivot_epee: Node3D
var pivot_torche: Node3D
var porte_torche: Node3D
var bras: Node3D
var _sq: Skeleton3D
var _accroche_d: BoneAttachment3D
var _accroche_g: BoneAttachment3D
var _doigts := {}
var torche_lumiere: OmniLight3D
var flammes: Array[GPUParticles3D] = []
var _visuels_torche: Array = []   # sprite de flamme et halo (lot 6)
var _halo_mat: ShaderMaterial
var _scint := 0.0

func _ready() -> void:
	# les pivots ne portent plus rien : ce sont les cibles que les mains suivent (IK)
	pivot_epee = Node3D.new()
	add_child(pivot_epee)
	pivot_epee.transform = _pose("repos")
	_depart = pivot_epee.transform
	pivot_torche = Node3D.new()
	pivot_torche.position = POS_TORCHE
	pivot_torche.rotation_degrees = Vector3(-14, 0, -12)
	add_child(pivot_torche)
	_bras()
	var epee := _modele_epee()
	_accroche_d.add_child(epee)
	epee.transform = PRISE_D
	joueur.inventaire.change.connect(_teinte_epee)
	porte_torche = Node3D.new()
	_accroche_g.add_child(porte_torche)
	porte_torche.transform = PRISE_G
	_torche()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mains="):
			_pose_figee = a.substr(8)

## Lame : acier, gorge centrale plus sombre, tranchants clairs (u = travers, v = longueur).
func _texture_lame() -> ImageTexture:
	var base := Palette.tex("acier", Palette.ACIER, 4, 0.3).get_image()
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var u := (x + 0.5) / 32.0
			var c := base.get_pixel(x, y % 32)
			if u < 0.09 or u > 0.91:
				c = Color("#d6dde8")            # fil du tranchant
			elif u > 0.36 and u < 0.64:
				c = c.darkened(0.35)            # gorge
				if (x + y) % 7 == 0:
					c = c.lightened(0.15)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Cuir de la poignée : bandes obliques de lanière.
func _texture_poignee() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var cuir := [Color("#24170e"), Color("#352316"), Color("#4a3220")]
	for y in 32:
		for x in 32:
			var bande := (x + y * 2) % 8
			img.set_pixel(x, y, cuir[0] if bande == 0 else (cuir[2] if bande < 3 else cuir[1]))
	return ImageTexture.create_from_image(img)

## Matériaux PS1 de l'équipement du joueur, par nom de matériau Blender.
func _materiaux_equipement() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_acier = Palette.materiau(ObjetsTextures.tex("lame"), Vector2.ONE, Color(1.3, 1.3, 1.38))
	_mats = {
		"lame": _acier,
		"fer": Palette.materiau(ObjetsTextures.tex("fer"), Vector2.ONE, Color(0.9, 0.9, 0.95)),
		"cuir": Palette.materiau(ObjetsTextures.tex("tresse"), Vector2.ONE),
		"gant": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(3, 3), Color(1.05, 0.95, 0.88), true),
		"brassard": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(2, 2), Color(0.7, 0.66, 0.66), true),
		"fourrure": Palette.materiau(ObjetsTextures.tex("fourrure"), Vector2(2, 1), Color(1.05, 1.0, 0.95), true),
		"tunique": Palette.materiau(ObjetsTextures.tex("manche"), Vector2(2, 1), Color.WHITE, true),
		"gants": Palette.materiau(ObjetsTextures.tex("gant"), Vector2(2, 1), Color(0.86, 0.78, 0.72), true),
		"brassards": Palette.materiau(ObjetsTextures.tex("brassard"), Vector2(2, 1), Color(1.0, 0.96, 0.96), true),
		"manche": Palette.materiau(Palette.tex("laine", ["#1a1d26", "#22262f", "#2b303b", "#353b48"], 4, 0.6), Vector2(2, 3), Color.WHITE, true),
		# peau des bras et des mains sous l'étoffe (bras_fps.glb) : bouche les fissures manche/brassard/gant
		"sous_couche": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(3, 3), Color(0.8, 0.72, 0.68)),
	}
	# les fichiers exportés de Blender portent des couleurs de sommet d'alpha nul, que le
	# shader lirait comme « neige » : la texture de neige devient la texture de base
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return _mats

func _habiller(racine: Node) -> void:
	var mats := _materiaux_equipement()
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	if racine is MeshInstance3D:
		mailles.append(racine)
	for mi: MeshInstance3D in mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else ""
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])

func _modele_epee() -> Node3D:
	var e: Node3D = EPEE_NORDIQUE.instantiate()
	_habiller(e)
	return e

## Vrais bras : manches, brassards et gants du corps du joueur, sur son squelette, placés
## pour que les yeux du squelette soient la caméra. L'IK à deux os (épaule, coude) amène
## chaque main sur sa cible ; l'arme et la torche sont tenues par les os des mains.
func _bras() -> void:
	bras = BRAS.instantiate()
	add_child(bras)
	_sq = bras.find_child("Skeleton3D", true, false)
	_habiller(bras)
	for mi: MeshInstance3D in bras.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
	# modèle tourné vers -Z (la caméra), yeux sur l'origine de la caméra
	var tete := _sq.get_bone_global_rest(_sq.find_bone("Head")).origin
	var yeux := tete + Vector3(0, 0.07, 0.1)
	var tour := Basis(Vector3.UP, PI)
	bras.transform = Transform3D(tour, -(tour * yeux) + Vector3(0, -0.1, -0.24))
	_poings()
	PRISE_D = _calculer_prise("r", MILIEU_POIGNEE)
	PRISE_G = _calculer_prise("l", 0.0)
	# cibles des mains et du coude
	var cible_d := Node3D.new()
	pivot_epee.add_child(cible_d)
	cible_d.transform = PRISE_D.affine_inverse()
	var cible_g := Node3D.new()
	pivot_torche.add_child(cible_g)
	cible_g.transform = PRISE_G.affine_inverse()
	var coude_d := Node3D.new()
	add_child(coude_d)
	coude_d.position = Vector3(0.8, -0.9, -0.1)
	var coude_g := Node3D.new()
	add_child(coude_g)
	coude_g.position = Vector3(-0.8, -0.9, -0.1)
	var ik := TwoBoneIK3D.new()
	_sq.add_child(ik)
	ik.set_setting_count(2)
	for i in 2:
		var c: String = ["r", "l"][i]
		ik.set_root_bone_name(i, "upperarm_" + c)
		ik.set_middle_bone_name(i, "lowerarm_" + c)
		ik.set_end_bone_name(i, "hand_" + c)
		ik.set_target_node(i, ik.get_path_to([cible_d, cible_g][i]))
		ik.set_pole_node(i, ik.get_path_to([coude_d, coude_g][i]))
	for i in 2:
		var o := SkeletonModifier3D.new()
		o.set_script(ORIENTATION)
		o.os = ["hand_r", "hand_l"][i]
		o.cible = [cible_d, cible_g][i]
		o.prise = [PRISE_D, PRISE_G][i]
		_sq.add_child(o)
	_accroche_d = BoneAttachment3D.new()
	_accroche_d.bone_name = "hand_r"
	_sq.add_child(_accroche_d)
	_accroche_g = BoneAttachment3D.new()
	_accroche_g.bone_name = "hand_l"
	_sq.add_child(_accroche_g)

## Prise d'un objet dans le poing fermé (repère de l'os de la main) : axe passant par le
## creux de chaque doigt, de l'auriculaire vers l'index ; le +X de l'objet (tranchant,
## quillons de la garde) dans le sens des jointures. `milieu` : point de l'objet (le long
## de son +Y) qui doit être au centre du poing.
func _calculer_prise(cote: String, milieu: float) -> Transform3D:
	var main := _pose_os("hand_" + cote).affine_inverse()
	var creux: Array[Vector3] = []
	for d in ["index", "middle", "ring", "pinky"]:
		var p1 := main * _pose_os("%s_01_%s" % [d, cote]).origin
		var p2 := main * _pose_os("%s_02_%s" % [d, cote]).origin
		var p3 := main * _pose_os("%s_03_%s" % [d, cote]).origin
		# sous la première phalange (rayon du doigt + rayon de la poignée), entre la paume
		# et le bout des doigts repliés
		creux.append(Vector3((p1.x + p3.x) * 0.5, minf(p1.y, p2.y) - 0.009 - 0.018, p1.z))
	var centre := (creux[0] + creux[1] + creux[2] + creux[3]) * 0.25
	var axe := (creux[0] - creux[3]).normalized()
	var jointures := (Vector3.UP - axe * axe.dot(Vector3.UP)).normalized()
	return Transform3D(Basis(jointures, axe, jointures.cross(axe)), centre - axe * milieu)

func _pose_os(nom: String) -> Transform3D:
	var i := _sq.find_bone(nom)
	var t := Transform3D()
	while i >= 0:
		t = _sq.get_bone_pose(i) * t
		i = _sq.get_bone_parent(i)
	return t

## Doigts refermés : pose des poings prise dans l'animation de coup de poing.
func _poings() -> void:
	var ap := AnimationPlayer.new()
	bras.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	ap.play("Punch_Cross")
	ap.seek(0.0, true)
	var doigts := {}
	for i in _sq.get_bone_count():
		var n := _sq.get_bone_name(i)
		if n.begins_with("thumb") or n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") or n.begins_with("pinky"):
			doigts[i] = _sq.get_bone_pose_rotation(i)
	ap.stop()
	ap.queue_free()
	_sq.reset_bone_poses()
	_doigts = doigts
	_reposer_doigts()

## Réappliquée à chaque image : sans animation, le squelette ne serait jamais marqué
## « modifié » et l'IK des bras ne tournerait pas.
func _reposer_doigts() -> void:
	for i in _doigts:
		_sq.set_bone_pose_rotation(i, _doigts[i])

func _teinte_epee() -> void:
	if _acier != null and joueur.inventaire.a("epee_skarnholt"):
		_acier.set_shader_parameter("teinte", Color(1.15, 1.05, 0.85))
		_acier.set_shader_parameter("emission", Color(0.05, 0.04, 0.02))

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(uc); st.add_vertex(c)

func _torche() -> void:
	var t := Torche.construire(porte_torche)
	flammes.assign(t["flamme"])
	torche_lumiere = t["lumiere"]
	_visuels_torche = t["visuels"]
	_halo_mat = t["halo_mat"]

func _pose(nom: String, sens := 1.0) -> Transform3D:
	var p: Vector3 = POSES[nom][0]
	var lame: Vector3 = POSES[nom][1]
	var fil: Vector3 = POSES[nom][2]
	if sens < 0.0:
		p.x = -p.x
		lame.x = -lame.x
		fil.x = -fil.x
	# repère de l'épée : +Y le long de la lame, +X vers le tranchant
	var y := lame.normalized()
	var x := (fil - y * fil.dot(y)).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), p)

func _unhandled_input(e: InputEvent) -> void:
	if joueur == null or joueur.mort or joueur.en_dialogue or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventMouseMotion:
		_balance += Vector2(e.screen_relative.x, e.screen_relative.y) * 0.00035
		_balance = _balance.limit_length(0.05)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and etat in [REPOS, RETOUR] and not bloque:
			_appui = 0.0
			_changer(ARMER)
		elif not e.pressed and _appui >= 0.0:
			_puissant = _appui >= SEUIL_CHARGE
			_appui = -1.0
			if etat in [ARMER, CHARGE]:
				_lancer_coup()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_T:
		torche_sortie = not torche_sortie
		Sons.jouer(self, ["cloth1", "cloth2"], -8.0)

func attaquer(puissant := false) -> void:
	## Pour les tests automatiques : un coup complet sans souris.
	_puissant = puissant
	_changer(ARMER)
	await get_tree().create_timer(0.35 if puissant else 0.09).timeout
	_lancer_coup()

func _lancer_coup() -> void:
	var cout := COUT_PUISSANT if _puissant else COUT_LEGER
	if joueur.vigueur <= 0.0:
		_puissant = false
	joueur.depenser(cout)
	Sons.jouer(self, ["swing", "swing2", "swing3"], -2.0 if _puissant else -5.0, 0.12)
	_changer(FRAPPE)

func _changer(nouvel: int) -> void:
	etat = nouvel
	_t = 0.0
	_depart = pivot_epee.transform
	if nouvel == FRAPPE:
		_touche_faite = false

func encaisser() -> void:
	_changer(ENCAISSE)

func _process(dt: float) -> void:
	if joueur == null:
		return
	_reposer_doigts()
	_t += dt
	_depuis_coup += dt
	_respiration += dt
	if _appui >= 0.0:
		_appui += dt
	if _pose_figee != "":
		pivot_epee.transform = _pose(_pose_figee, 1.0)
		etat = -1

	var veut_garde: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not joueur.mort
	if veut_garde and etat == REPOS:
		_changer(GARDE)
		temps_garde = 0.0
	bloque = etat in [GARDE, ENCAISSE]
	if bloque:
		temps_garde += dt

	var cible := _pose("repos")
	var vitesse := 10.0
	match etat:
		ARMER:
			cible = _pose("armer", _sens)
			vitesse = 22.0
			if _appui >= SEUIL_CHARGE:
				_changer(CHARGE)
		CHARGE:
			cible = _pose("charge", _sens)
			vitesse = 6.0
		FRAPPE:
			var duree := 0.2 if _puissant else 0.15
			var k := clampf(_t / duree, 0.0, 1.0)
			pivot_epee.transform = _depart.interpolate_with(_pose("frappe", _sens), ease(k, 0.45))
			if not _touche_faite and k >= 0.45:
				_touche_faite = true
				_tester_coup()
			if k >= 1.0:
				_changer(RETOUR)
				_sens = -_sens
				_depuis_coup = 0.0
		RETOUR:
			vitesse = 9.0
			if _t > 0.3:
				_changer(REPOS)
				if _depuis_coup > 0.9:
					_sens = 1.0
		GARDE:
			cible = _pose("garde")
			vitesse = 18.0
			if not veut_garde:
				_changer(REPOS)
		ENCAISSE:
			cible = _pose("encaisse")
			vitesse = 25.0
			if _t > 0.18:
				_changer(GARDE if veut_garde else REPOS)
	if etat != FRAPPE and _pose_figee == "":
		pivot_epee.transform = pivot_epee.transform.interpolate_with(cible, 1.0 - exp(-vitesse * dt))

	# inertie de la souris et respiration
	_balance = _balance.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * dt))
	var souffle := sin(_respiration * 1.6) * 0.006
	# pendant une conversation, on baisse les armes
	_baisse = lerpf(_baisse, 0.45 if joueur.en_dialogue else 0.0, 1.0 - exp(-6.0 * dt))
	position = Vector3(-_balance.x, _balance.y + souffle - _baisse, 0.0)

	# torche : baissée pendant la garde, rangée avec T
	var y_torche := -0.44
	if bloque:
		y_torche = -0.58
	if not torche_sortie:
		y_torche = -0.95
	pivot_torche.position.y = lerpf(pivot_torche.position.y, y_torche, 1.0 - exp(-8.0 * dt))
	var allumee := torche_sortie or pivot_torche.position.y > -0.8
	for f in flammes:
		f.emitting = allumee
	for n: Node3D in _visuels_torche:
		n.visible = allumee
	torche_lumiere.visible = allumee
	# lumière vacillante : sinus incommensurables + scintillement par paliers (14 par seconde), sans hasard par image
	var palier := floorf(_respiration * 14.0)
	var scint := fposmod(sin(palier * 12.9898) * 43758.5453, 1.0)
	torche_lumiere.light_energy = 1.4 + sin(_respiration * 13.0) * 0.12 + sin(_respiration * 29.0) * 0.08 + scint * 0.14
	_halo_mat.set_shader_parameter("intensite", 0.65 + (torche_lumiere.light_energy - 1.4) * 0.7)

## Multiplicateur des armes uniques portées (épée de Skarnholt ×1,35 ; hache de Kolbeinn ×1,25 ; pas de cumul).
func _bonus_arme() -> float:
	var b := 1.0
	if joueur.inventaire.a("epee_skarnholt"):
		b = 1.35
	if joueur.inventaire.a("hache_kolbeinn"):
		b = maxf(b, 1.25)
	return b

func _tester_coup() -> void:
	var cam := get_parent() as Node3D
	var origine := cam.global_position
	var face := -cam.global_transform.basis.z
	var face_plate := Vector2(face.x, face.z).normalized()
	var portee := 2.7 if _puissant else 2.3
	var resultat := ""
	for e in get_tree().get_nodes_in_group("ennemis"):
		if not e.vivant():
			continue
		var cible_coup: Vector3 = e.point_impact() if e.has_method("point_impact") else e.global_position + Vector3(0, 1.0, 0)
		var v: Vector3 = cible_coup - origine
		var d := v.length()
		if d > portee + 0.4:
			continue
		if d > 0.9 and Vector2(v.x, v.z).normalized().dot(face_plate) < 0.5:
			continue
		var base := DEGATS_PUISSANT if _puissant else DEGATS_LEGER
		base *= _bonus_arme()
		var r: String = e.recevoir_coup(base * joueur.competences.multiplicateur_degats(), joueur.global_position, _puissant)
		if r == "touche" or r == "tue":
			joueur.competences.pratiquer("epee", 1.8 if _puissant else 1.0)
		joueur.ennemi_vise = e
		if r == "bloque" and resultat == "":
			resultat = "bloque"
		elif r != "bloque":
			resultat = "touche"
	# éléments cassables (mur fragile…) : groupe « cassables », méthode frapper(puissant, origine) ; ne change rien pour les ennemis
	for c in get_tree().get_nodes_in_group("cassables"):
		if not is_instance_valid(c) or not c.has_method("frapper"):
			continue
		# point du cassable le plus proche des yeux (méthode facultative : sinon son origine)
		var centre: Vector3 = c.point_proche(origine) if c.has_method("point_proche") else c.global_position
		var vc: Vector3 = centre - origine
		if vc.length() > portee + 0.3:
			continue
		if vc.length() > 0.9 and Vector2(vc.x, vc.z).normalized().dot(face_plate) < 0.5:
			continue
		if c.frapper(_puissant, joueur.global_position) and resultat == "":
			resultat = "touche"
	if resultat == "touche":
		Effets.arret_image(get_tree(), 0.11 if _puissant else 0.06)
		joueur.secousse = maxf(joueur.secousse, 0.5 if _puissant else 0.25)
	elif resultat == "bloque":
		# l'épée rebondit sur le bouclier
		_changer(ENCAISSE)
		joueur.secousse = maxf(joueur.secousse, 0.3)
