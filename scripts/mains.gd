extends Node3D
## Mains du joueur (enfant de la caméra) : arme de la main droite, objet de la main gauche (torche).
## Clic gauche court : coup léger (combo de directions). Maintenir : charge puis coup lourd au relâchement.
## Clic droit maintenu : garde (une garde levée juste avant l'impact = parade). T : sortir / ranger la torche.
## F3 (ou --debug-combat) : débogage (tracé de lame, état de combat, endurance).
##
## Architecture du combat (scripts/combat/, règles et valeurs : docs/COMBAT.md) :
##   EntreesCombat     entrées horodatées + mémoire d'entrée          EtatCombat     machine à états (Idle … Equip)
##   Equipement        main droite / main gauche (DonneesArme)        DonneesArme    stats, modèle, prise, pose de repos
##   ProfilsAnimation  gestes d'attaque, poses de garde / sprint      MouvementsPassifs  respiration, marche, sprint, saut…
##   TraceLame         détection par tracé de lame (pas fixe)         DegatsCombat   calcul et application des dégâts
##   RetourCoups       sons, étincelles, arrêt sur image, secousse
## Ce script orchestre : il lit les entrées, fait avancer la machine à états, pose les mains (IK) et lance le tracé.
## L'interface publique d'avant est conservée : etat (ancien enum, lu par corps_joueur.gd), bloque, temps_garde,
## torche_sortie, _puissant, attaquer(), encaisser(), pivot_epee, pivot_torche, porte_torche, _accroche_d/_g.

const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const ORIENTATION := preload("res://scripts/orientation_main.gd")
const DEBOGAGE := preload("res://scripts/combat/debogage_combat.gd")
## Milieu de la poignée de l'épée de départ (désormais lu dans DonneesArme.milieu_poignee).
const MILIEU_POIGNEE := 0.03

## Ancien état des mains, toujours exposé (corps_joueur.gd, tests) : dérivé de la machine à états.
enum { REPOS, ARMER, CHARGE, FRAPPE, RETOUR, GARDE, ENCAISSE }

## Durée d'appui au-delà de laquelle le coup devient lourd (s).
const SEUIL_CHARGE := 0.28
## Durée de charge (au-delà du seuil) pour atteindre le plafond (s).
const CHARGE_MAX := 0.9
## Fenêtre de parade : début de la garde pendant lequel un coup reçu est paré (s) — lue par joueur.recevoir_coup.
const FENETRE_PARADE := 0.3
## Fenêtre de combo par défaut (un geste sans « enchainement ») : début (s) et fin (part de la récupération).
const DELAI_COMBO := 0.06
## Mouvement de souris récent (pixels, oubli exponentiel ~0,1 s) au-delà duquel il choisit la direction du coup.
const SEUIL_SOURIS := 40.0
## Vitesses locales du joueur (m/s) qui choisissent la direction : de côté → horizontal, en avant → vertical,
## en arrière → estoc.
const SEUIL_COTE := 1.2
const SEUIL_AVANT := 1.5
const SEUIL_RECUL := 1.2
const DUREE_ENCAISSE := 0.18
const DUREE_REBOND := 0.30
## Coup affaibli (endurance insuffisante) : gestes ralentis de ce facteur.
const LENTEUR_AFFAIBLI := 0.75

var joueur: CharacterBody3D
var combat := EtatCombat.new()
var entrees := EntreesCombat.new()
var equipement := Equipement.new()
var passifs := MouvementsPassifs.new()
var trace := TraceLame.new()
## Arme de la main droite (raccourci de equipement.main_droite).
var arme: DonneesArme
var temps_garde := 0.0
## Tests : _process ne fait plus rien, le test appelle avancer(dt) lui-même (pas de temps imposé).
var pas_manuel := false
var debug_combat := false

## Garde levée (garde, parade, impact encaissé) : lu par joueur.gd.
var bloque: bool:
	get:
		return combat.etat in [EtatCombat.GARDE, EtatCombat.PARADE]
var torche_sortie: bool:
	get:
		return equipement.gauche_sortie()
	set(v):
		if v != equipement.gauche_sortie():
			equipement.basculer_gauche()
## Ancien état (REPOS, ARMER, CHARGE, FRAPPE, RETOUR, GARDE, ENCAISSE). Écrire GARDE impose une garde d'une image
## (tests de parade), REPOS la relâche.
var etat: int:
	get:
		return _etat_ancien()
	set(v):
		if v == GARDE or v == ENCAISSE:
			entrees.forcer_garde(0.05)
			if not combat.defense():
				combat.forcer(EtatCombat.PARADE)
				temps_garde = 0.0
		elif v == REPOS:
			entrees.forcer_garde(0.0)
			combat.forcer(EtatCombat.REPOS)
## Coup en cours lourd (lu par corps_joueur.gd pour la vitesse de l'animation 3e personne).
var _puissant := false

var _geste := {}
var _geste_nom := ""
var _combo := 0
## Côté où le dernier coup a fini (+1 droite, -1 gauche, 0 centre) et dernier geste : continuité des enchaînements.
var _cote_fin := 0
var _geste_prec := ""
var _souris_recente := Vector2.ZERO
var _lourd := false
var _affaibli := false
var _charge := 0.0
var _charge_signalee := false
var _t_geste := 0.0          # temps dans le geste (préparation + phase active), arrêté pendant l'attente du relâchement
var _duree_prep := 0.1
var _duree_active := 0.17
var _duree_recup := 0.3
var _t_trace := 0.0          # temps de phase active déjà échantillonné par le tracé
var _actif_lance := false    # phase active commencée (endurance payée, tracé lancé)
var _t_actif_prec := 0.0
var _issue_arret := ""
var _instant_impact := 0.0
var _depart := Transform3D()
var _pose_courante := Transform3D()
var _pose_fin := Transform3D()
var _depuis_coup := 9.0
var _encaisse := 0.0
var _cam_prec := Transform3D()
var _cam_prec_ok := false
var _pose_figee := ""
var _baisse := 0.0
var _baisse_torche := 0.0
var _respiration := 0.0
var _debogage: Node
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
var _cible_d: Node3D
## Pôles des coudes (IK) : leur position règle l'axe de l'avant-bras, donc l'inclinaison possible de l'arme.
var _coude_d: Node3D
var _coude_g: Node3D
var _orient_d: SkeletonModifier3D
var _modele_arme_d: Node3D
## Matériau de la lame tenue (teinte, lueur de charge) et segment tranchant lu dans le modèle.
var _lame: ShaderMaterial
var _garde_lame := Vector3(0, 0.1, 0)
var _pointe_lame := Vector3(0, 0.84, 0)
var _doigts := {}
var torche_lumiere: OmniLight3D
var flammes: Array[GPUParticles3D] = []
var _visuels_torche: Array = []   # sprite de flamme et halo (lot 6)
var _halo_mat: ShaderMaterial
var _scint := 0.0

func _ready() -> void:
	arme = equipement.main_droite
	# les pivots ne portent plus rien : ce sont les cibles que les mains suivent (IK)
	pivot_epee = Node3D.new()
	add_child(pivot_epee)
	_pose_courante = _pose_repos()
	pivot_epee.transform = _pose_courante
	pivot_torche = Node3D.new()
	add_child(pivot_torche)
	pivot_torche.transform = _pose_torche()
	_bras()
	equipement.change.connect(_sur_equipement)
	joueur.inventaire.change.connect(func() -> void: equipement.choisir_selon_inventaire(joueur.inventaire))
	equipement.choisir_selon_inventaire(joueur.inventaire)
	_installer_arme()
	porte_torche = Node3D.new()
	_accroche_g.add_child(porte_torche)
	porte_torche.transform = PRISE_G
	_torche()
	Jeu.option("affichage", "reduire_mouvements")   # charge les options si besoin
	combat.change.connect(_sur_changement_etat)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mains="):
			_pose_figee = a.substr(8)
		elif a == "--debug-combat":
			basculer_debogage(true)

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

## Modèle de l'arme de la main droite, chargé depuis sa DonneesArme (chemin du modèle + point de prise) : changer
## d'épée = changer de ressource. La prise, la cible de l'IK et l'orientation du poignet suivent le milieu de poignée.
func _installer_arme() -> void:
	arme = equipement.main_droite
	passifs.poids = maxf(arme.poids, 0.5)
	if is_instance_valid(_modele_arme_d):
		_modele_arme_d.queue_free()
		_modele_arme_d = null
	PRISE_D = _calculer_prise("r", arme.milieu_poignee)
	_cible_d.transform = PRISE_D.affine_inverse()
	_coude_d.position = arme.repos_coude
	_orient_d.deviation_max = deg_to_rad(arme.deviation_poignet)
	var g_coude := equipement.gauche_rangee.repos_coude
	_coude_g.position = Vector3(-g_coude.x, g_coude.y, g_coude.z)
	_orient_d.prise = PRISE_D
	_lame = _acier
	_garde_lame = arme.garde
	_pointe_lame = arme.pointe
	if arme.modele != "" and ResourceLoader.exists(arme.modele):
		var scene: PackedScene = load(arme.modele)
		_modele_arme_d = scene.instantiate()
		if arme.habillage == "epees_longues":
			EpeesLongues.habiller(_modele_arme_d)
			_lame = _copie_lame(_modele_arme_d, EpeesLongues.materiaux().get(arme.materiau_lame))
		else:
			_habiller(_modele_arme_d)
		_accroche_d.add_child(_modele_arme_d)
		_accroche_d.move_child(_modele_arme_d, 0)
		_modele_arme_d.transform = PRISE_D
		if arme.reperes_du_modele:
			var g := _repere(_modele_arme_d, "garde")
			var p := _repere(_modele_arme_d, "pointe")
			if g != Vector3.INF and p != Vector3.INF and g.distance_to(p) > 0.1:
				_garde_lame = g
				_pointe_lame = p
	if _lame != null:
		if arme.teinte.a > 0.0:
			_lame.set_shader_parameter("teinte", arme.teinte)
		_lame.set_shader_parameter("emission", arme.emission)

## Copie du matériau de lame posée sur l'arme du joueur (teinte, lueur de charge sans toucher aux autres épées).
func _copie_lame(racine: Node, partage: Material) -> ShaderMaterial:
	if partage == null:
		return null
	var copie := partage.duplicate() as ShaderMaterial
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(k) == partage:
				mi.set_surface_override_material(k, copie)
	return copie

## Position d'un nœud vide du modèle dans son repère (avant l'entrée dans l'arbre), INF s'il n'existe pas.
func _repere(racine: Node3D, nom: String) -> Vector3:
	var n := racine.find_child(nom, true, false) as Node3D
	if n == null:
		return Vector3.INF
	var t := Transform3D()
	while n != null and n != racine:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t.origin

func _sur_equipement(main: String) -> void:
	if main == "droite":
		_installer_arme()
		if combat.calme():
			combat.changer(EtatCombat.EQUIPER)
	else:
		Sons.jouer(self, ["cloth1", "cloth2"], -8.0)

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
	_cible_d = cible_d
	var cible_g := Node3D.new()
	pivot_torche.add_child(cible_g)
	cible_g.transform = PRISE_G.affine_inverse()
	var coude_d := Node3D.new()
	add_child(coude_d)
	coude_d.position = Vector3(0.8, -0.9, -0.1)
	var coude_g := Node3D.new()
	add_child(coude_g)
	coude_g.position = Vector3(-0.8, -0.9, -0.1)
	_coude_d = coude_d
	_coude_g = coude_g
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
		if i == 0:
			_orient_d = o
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


# --- poses ------------------------------------------------------------------------------

func _profil() -> Dictionary:
	return ProfilsAnimation.profil(arme.profil)

func _pose_repos() -> Transform3D:
	var a: DonneesArme = arme if arme != null else equipement.main_droite
	return ProfilsAnimation.transform_pose([a.repos_poignee, a.repos_lame, a.repos_fil])

## Torche (ou objet de la main gauche) : pose de repos de sa DonneesArme, en miroir côté gauche.
func _pose_torche() -> Transform3D:
	var g: DonneesArme = equipement.gauche_rangee
	return ProfilsAnimation.transform_pose([g.repos_poignee, g.repos_lame, g.repos_fil], -1.0)

## Pose nommée (outils de réglage, --mains=nom) : repos, armer, charge, frappe, garde, encaisse, sprint.
func _pose(nom: String, sens := 1.0) -> Transform3D:
	var p := _profil()
	match nom:
		"repos":
			return _pose_repos()
		"armer", "frappe", "milieu":
			var g := ProfilsAnimation.geste(arme.profil, p["combo"][0])
			var cle: String = {"armer": "armer", "frappe": "fin", "milieu": "milieu"}[nom]
			return ProfilsAnimation.transform_pose(g[cle], sens)
	return ProfilsAnimation.transform_pose(p.get(nom, p["garde"]), sens)

# --- entrées ----------------------------------------------------------------------------

func _peut_agir() -> bool:
	return joueur != null and not joueur.mort and not joueur.en_dialogue

func _unhandled_input(e: InputEvent) -> void:
	if not _peut_agir() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventMouseMotion:
		passifs.souris(e.screen_relative)
		noter_souris(e.screen_relative)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			entrees.appuyer()
		else:
			entrees.relacher()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_T:
		equipement.basculer_gauche()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F3:
		basculer_debogage(not debug_combat)

## Pour les tests automatiques et les scripts de scène : un coup complet sans souris.
func attaquer(puissant := false) -> void:
	entrees.appuyer()
	await get_tree().create_timer(0.35 if puissant else 0.09).timeout
	entrees.relacher()

## Appelé par joueur.recevoir_coup quand la garde encaisse un coup.
func encaisser() -> void:
	_encaisse = DUREE_ENCAISSE

func basculer_debogage(actif: bool) -> void:
	debug_combat = actif
	trace.garder_debug = actif
	if actif and _debogage == null:
		_debogage = DEBOGAGE.new()
		_debogage.mains = self
		add_child(_debogage)
	if _debogage != null:
		_debogage.montrer(actif)

# --- machine à états --------------------------------------------------------------------

func _etat_ancien() -> int:
	match combat.etat:
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE:
			return ARMER if _t_geste < _duree_prep else FRAPPE
		EtatCombat.CHARGE_LOURDE:
			return CHARGE
		EtatCombat.RECUPERATION:
			return RETOUR
		EtatCombat.GARDE, EtatCombat.PARADE:
			return ENCAISSE if _encaisse > 0.0 else GARDE
		EtatCombat.DESEQUILIBRE:
			return ENCAISSE
	return REPOS

func _sur_changement_etat(_ancien: int, nouveau: int) -> void:
	if nouveau in [EtatCombat.PARADE, EtatCombat.REPOS, EtatCombat.MOUVEMENT]:
		_encaisse = 0.0
	_depart = _pose_courante

## Mouvement de souris (pixels d'écran) : lu pour choisir la direction du prochain coup.
func noter_souris(d: Vector2) -> void:
	_souris_recente += d

## Direction du coup léger selon le contexte (phase 4) : souris balayée → horizontal dans son sens, souris tirée vers
## le bas → vertical ; sinon déplacement : de côté → horizontal dans le sens du pas, en avant → vertical, en arrière →
## estoc ; à l'arrêt → combo 1-2-3 du profil. Renvoie [geste, contextuel].
func _choisir_geste() -> Array:
	var p := _profil()
	var gestes: Dictionary = p["gestes"]
	var loc := joueur.global_transform.basis.inverse() * joueur.velocity
	var sx := _souris_recente.x
	var sy := _souris_recente.y
	var choix := ""
	if absf(sx) > SEUIL_SOURIS and absf(sx) > absf(sy) * 1.5:
		choix = "horizontale_gd" if sx > 0.0 else "horizontale"
	elif sy > SEUIL_SOURIS and sy > absf(sx) * 1.5:
		choix = "verticale_l"
	elif absf(loc.x) > SEUIL_COTE and absf(loc.x) > absf(loc.z):
		choix = "horizontale_gd" if loc.x > 0.0 else "horizontale"
	elif loc.z < -SEUIL_AVANT:
		choix = "verticale_l"
	elif loc.z > SEUIL_RECUL:
		choix = "estoc"
	if choix != "" and gestes.has(choix):
		return [choix, true]
	var combo: Array = p["combo"]
	return [combo[_combo % combo.size()], false]

## Démarre un coup (léger d'abord : il deviendra lourd si le bouton reste tenu au-delà du seuil). `enchaine` : l'appui
## tombe dans la fenêtre de combo du coup précédent (le combo continue, le geste repart du côté où l'autre a fini).
func _commencer_attaque(enchaine := false) -> void:
	if not arme.est_arme():
		return
	if not enchaine:
		_combo = 0
		_cote_fin = 0
		_geste_prec = ""
	if not combat.changer(EtatCombat.ATTAQUE_LEGERE):
		return
	var c := _choisir_geste()
	var nom: String = c[0]
	var depart := int(ProfilsAnimation.geste(arme.profil, nom).get("cotes", [0, 0])[0])
	# continuité : un geste qui partirait du côté opposé à la fin du précédent est remplacé par son miroir (combo à
	# l'arrêt), ou un geste contextuel répété alterne de sens (pas de côté prolongé : gauche-droite-gauche…)
	if enchaine and _cote_fin != 0 and depart != 0 and depart != _cote_fin and ProfilsAnimation.MIROIRS.has(nom):
		if not c[1] or nom == _geste_prec:
			nom = ProfilsAnimation.MIROIRS[nom]
			depart = -depart
	_geste_nom = nom
	_preparer_geste(false)
	if enchaine and depart != 0 and depart == _cote_fin:
		_duree_prep *= 0.75   # la lame est déjà du bon côté : transition plus courte

func _preparer_geste(lourd: bool) -> void:
	_lourd = lourd
	_puissant = lourd
	_geste = ProfilsAnimation.geste(arme.profil, _geste_nom)
	_t_geste = 0.0
	_t_trace = 0.0
	_actif_lance = false
	_affaibli = false
	_charge_signalee = false
	if not lourd:
		_charge = 0.0
	var v := maxf(arme.vitesse, 0.1)
	_duree_prep = float(_geste["preparation"]) / v
	_duree_active = float(_geste["active"]) / v
	_duree_recup = float(_geste["recuperation"]) / v
	_depart = _pose_courante
	if lourd:
		_duree_prep = 0.06 / v   # la lame est déjà armée par la charge : départ presque immédiat

## Lancement de la phase active : on paie l'endurance ici. Pas assez d'endurance = coup AFFAIBLI (dégâts ×0,5,
## geste ralenti, jamais puissant) — le coup part toujours, le joueur n'est jamais bloqué sans réponse.
func _lancer_phase_active() -> void:
	var cout := arme.cout_lourd if _lourd else arme.cout_leger
	_affaibli = joueur.vigueur < cout
	if _affaibli:
		_puissant = false
		_duree_active /= LENTEUR_AFFAIBLI
		_duree_recup /= LENTEUR_AFFAIBLI
	joueur.depenser(cout)
	trace.commencer()
	_cam_prec_ok = false
	Sons.jouer(self, ["swing", "swing2", "swing3"], -2.0 if _lourd else -5.0, 0.12)

func _finir_geste() -> void:
	_pose_fin = _pose_courante
	_combo += 1
	_cote_fin = int(_geste.get("cotes", [0, 0])[1])
	_geste_prec = _geste_nom
	_depuis_coup = 0.0
	combat.changer(EtatCombat.RECUPERATION)

## La lame est arrêtée (mur, bouclier, cassable qui tient) : rebond, petite ouverture.
func _rebondir() -> void:
	_pose_fin = _pose_courante
	_cote_fin = 0
	_depuis_coup = 0.0
	combat.changer(EtatCombat.DESEQUILIBRE)

func _process(dt: float) -> void:
	if joueur == null or pas_manuel:
		return
	avancer(dt)

## Une image de combat (dt en s de jeu). Appelée par _process, ou par un test à pas imposé (pas_manuel).
func avancer(dt: float) -> void:
	_reposer_doigts()
	_respiration += dt
	_depuis_coup += dt
	entrees.garde_tenue = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _peut_agir()
	if not _peut_agir():
		entrees.attaque_tenue = false
		entrees.tampon = -1.0
	entrees.avancer(dt)
	combat.avancer(dt)
	_souris_recente *= exp(-10.0 * dt)
	_encaisse = maxf(0.0, _encaisse - dt)

	var veut_garde: bool = entrees.veut_garde() and not joueur.mort
	var plat := Vector3(joueur.velocity.x, 0.0, joueur.velocity.z)
	var vitesse_sol := plat.length()
	var cible := _pose_repos()
	var raideur := 10.0
	var en_geste := false
	match combat.etat:
		EtatCombat.REPOS, EtatCombat.MOUVEMENT:
			combat.changer(EtatCombat.MOUVEMENT if vitesse_sol > 0.4 else EtatCombat.REPOS)
			if veut_garde:
				entrees.tampon = -1.0
				if combat.changer(EtatCombat.PARADE):
					temps_garde = 0.0
			elif entrees.consommer():
				_commencer_attaque()
			if combat.calme():
				cible = cible.interpolate_with(ProfilsAnimation.transform_pose(_profil()["sprint"]), passifs.sprint)
		EtatCombat.PARADE, EtatCombat.GARDE:
			entrees.tampon = -1.0   # pas d'attaque normale en garde
			temps_garde += dt
			cible = ProfilsAnimation.transform_pose(_profil()["encaisse" if _encaisse > 0.0 else "garde"])
			raideur = 25.0 if _encaisse > 0.0 else 18.0
			if not veut_garde:
				combat.changer(EtatCombat.REPOS)
			elif combat.etat == EtatCombat.PARADE and temps_garde >= FENETRE_PARADE:
				combat.changer(EtatCombat.GARDE)
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE:
			en_geste = true
			_avancer_geste(dt)
		EtatCombat.CHARGE_LOURDE:
			cible = ProfilsAnimation.transform_pose(_profil()["charge"])
			raideur = 7.0
			if entrees.attaque_tenue:
				_charge = clampf((entrees.duree_appui() - SEUIL_CHARGE) / CHARGE_MAX, 0.0, 1.0)
			if _charge >= 1.0 and not _charge_signalee:
				_charge_signalee = true
				RetourCoups.charge_max(self, _lame, arme.emission)
			# tremblement discret à pleine charge
			if _charge >= 1.0:
				cible.origin += Vector3(sin(_respiration * 47.0), cos(_respiration * 53.0), 0.0) * 0.0025 * passifs.amplitude
			if not entrees.attaque_tenue:
				combat.changer(EtatCombat.ATTAQUE_LOURDE)
				_geste_nom = _profil()["lourd"]
				_preparer_geste(true)
		EtatCombat.RECUPERATION:
			var k := clampf(combat.t / _duree_recup, 0.0, 1.0)
			_pose_courante = _pose_fin.interpolate_with(_pose_repos(), k * k * (3.0 - 2.0 * k))
			en_geste = true
			var fen: Array = _geste.get("enchainement", [DELAI_COMBO, 1.0])
			if combat.t >= float(fen[0]) and entrees.consommer():
				_commencer_attaque(combat.t <= float(fen[1]) * _duree_recup)
			elif veut_garde and combat.t > 0.12:
				if combat.changer(EtatCombat.PARADE):
					temps_garde = 0.0
			elif k >= 1.0:
				combat.changer(EtatCombat.REPOS)
		EtatCombat.DESEQUILIBRE:
			# rebond : la main recule un peu dans le sens inverse du coup, puis revient au repos
			var k := clampf(combat.t / DUREE_REBOND, 0.0, 1.0)
			var recul := _pose_fin
			recul.origin += (Vector3(0.0, -0.03, 0.08) + (_pose_repos().origin - _pose_fin.origin) * 0.3) * sin(minf(k * 2.0, 1.0) * PI * 0.5)
			_pose_courante = recul.interpolate_with(_pose_repos(), smoothstep(0.35, 1.0, k))
			en_geste = true
			if k >= 1.0:
				combat.changer(EtatCombat.REPOS)
		EtatCombat.EQUIPER:
			# l'arme passe sous l'écran puis remonte
			var k := clampf(combat.t / 0.45, 0.0, 1.0)
			cible.origin.y -= sin(k * PI) * 0.35
			raideur = 30.0
			if k >= 1.0:
				combat.changer(EtatCombat.REPOS)
	if not en_geste:
		_pose_courante = _pose_courante.interpolate_with(cible, 1.0 - exp(-raideur * dt))

	# animations passives (respiration, marche, sprint, saut, inertie)
	passifs.amplitude = 0.35 if bool(Jeu.option("affichage", "reduire_mouvements")) else 1.0
	var locale := joueur.global_transform.basis.inverse() * Vector3(joueur.velocity.x, joueur.velocity.y, joueur.velocity.z)
	passifs.avancer(dt, locale, joueur.is_on_floor(), combat.calme() or combat.defense())
	if _pose_figee != "":
		_pose_courante = _pose(_pose_figee, 1.0)
		pivot_epee.transform = _pose_courante
	else:
		pivot_epee.transform = passifs.decalage_d * _pose_courante

	# pendant une conversation, on baisse les armes
	_baisse = lerpf(_baisse, 0.45 if joueur.en_dialogue else 0.0, 1.0 - exp(-6.0 * dt))
	position = Vector3(0.0, -_baisse, 0.0)
	_poser_torche(dt)
	_cam_prec = _transform_monde()
	_cam_prec_ok = true

## Préparation (vers la pose armée), attente du relâchement (le coup peut devenir lourd), phase active avec tracé.
func _avancer_geste(dt: float) -> void:
	var tenu := combat.etat == EtatCombat.ATTAQUE_LEGERE and entrees.attaque_tenue
	if tenu and entrees.duree_appui() >= SEUIL_CHARGE:
		combat.changer(EtatCombat.CHARGE_LOURDE)
		return
	_t_geste = minf(_t_geste + dt, _duree_prep) if tenu else _t_geste + dt
	if not _actif_lance:
		if _t_geste < _duree_prep or tenu:
			# bouton encore tenu : la lame reste armée jusqu'au relâchement ou au seuil de charge
			var k := clampf(_t_geste / _duree_prep, 0.0, 1.0)
			_pose_courante = _depart.interpolate_with(ProfilsAnimation.transform_pose(_geste["armer"]), 1.0 - (1.0 - k) * (1.0 - k))
			return
		_actif_lance = true
		_t_actif_prec = 0.0
		_lancer_phase_active()
	var t_actif := minf(_t_geste - _duree_prep, _duree_active)
	var t_prec := _t_actif_prec
	_t_actif_prec = t_actif
	_pose_courante = _pose_active(t_actif)
	var arret := _tracer(t_prec, t_actif)
	if arret >= 0.0:
		_pose_courante = _pose_active(arret)
		if _issue_arret == "arret":
			_finir_geste()
		else:
			_rebondir()
		return
	if t_actif >= _duree_active:
		_finir_geste()

func _pose_active(t_actif: float) -> Transform3D:
	return ProfilsAnimation.pose_active(_geste, ProfilsAnimation.courbe_active(t_actif / _duree_active))

func _transform_monde() -> Transform3D:
	return (get_parent() as Node3D).global_transform * transform

## Tracé de lame entre t0 et t1 (temps de phase active), à pas FIXE TraceLame.PAS : les échantillons tombent aux
## mêmes instants du geste quelle que soit la durée de l'image. Renvoie l'instant d'arrêt de la lame (mur, sol,
## bouclier, cassable ; _issue_arret dit lequel) ou -1.
func _tracer(t0: float, t1: float) -> float:
	var fen: Array = _geste["fenetre"]
	var debut := float(fen[0]) * _duree_active
	var fin := float(fen[1]) * _duree_active
	var monde_now := _transform_monde()
	var monde_avant := _cam_prec if _cam_prec_ok else monde_now
	var espace := get_world_3d().direct_space_state
	var exclus: Array[RID] = [joueur.get_rid()]
	var points_arme := arme.points_lame(_garde_lame, _pointe_lame)
	var oeil := (get_parent() as Node3D).global_position
	var max_cibles := maxi(arme.multi_cibles, 1)
	var k := int(ceil(maxf(_t_trace, debut) / TraceLame.PAS - 1e-6))
	while true:
		var ts := k * TraceLame.PAS
		if ts > minf(t1, fin) + 1e-9:
			break
		_t_trace = ts + 1e-6
		k += 1
		var f := 1.0 if t1 <= t0 else clampf((ts - t0) / (t1 - t0), 0.0, 1.0)
		var xf := monde_avant.interpolate_with(monde_now, f) * passifs.decalage_d * _pose_active(ts)
		var pts := PackedVector3Array()
		for p in points_arme:
			pts.append(xf * p)
		_instant_impact = ts
		for e in trace.echantillonner(espace, pts, oeil, exclus, max_cibles):
			var issue := _resoudre_impact(e)
			if issue != "":
				_issue_arret = issue
				return ts
	return -1.0

## Applique un événement du tracé ; renvoie "" (la lame continue), "rebond" (mur, bouclier, cassable qui tient) ou
## "arret" (sol : la lame s'y arrête, le geste se termine sans rebond).
func _resoudre_impact(e: Dictionary) -> String:
	match e["type"]:
		"cible":
			var cible: Node = e["objet"]
			var degats := DegatsCombat.calculer(arme, _lourd, _charge, _affaibli, joueur.competences.multiplicateur_degats(), equipement.bonus_trophee(joueur.inventaire))
			var r := DegatsCombat.appliquer(cible, degats, joueur.global_position, _puissant, _info_coup(e))
			if cible.is_in_group("ennemis") or cible.is_in_group("cibles_combat"):
				joueur.ennemi_vise = cible   # barre de vie de la cible (HUD)
			if r == "touche" or r == "tue":
				joueur.competences.pratiquer("epee", 1.8 if _lourd else 1.0)
				RetourCoups.touche(joueur, _lourd)
			elif r == "bloque":
				RetourCoups.bloque(joueur)
				trace.arretee = true
				return "rebond"
		"cassable":
			var c: Node = e["objet"]
			var cede: bool = c.has_method("frapper") and c.frapper(_puissant, joueur.global_position)
			if cede:
				RetourCoups.touche(joueur, true)
			else:
				RetourCoups.mur(joueur, e["point"], e["normale"], arme.materiau_impact)
				return "rebond"
		"mur":
			RetourCoups.mur(joueur, e["point"], e["normale"], arme.materiau_impact)
			return "rebond"
		"sol":
			RetourCoups.mur(joueur, e["point"], e["normale"], "bois" if arme.materiau_impact == "bois" else arme.materiau_impact)
			return "arret"
	return ""

## Informations du coup transmises à la cible (contrat commun avec combat/degats_gore, voir DegatsCombat).
func _info_coup(e: Dictionary) -> Dictionary:
	var attaque := "legere"
	if _lourd:
		attaque = "chargee_max" if _charge >= 1.0 else "lourde"
	var stagger := arme.desequilibre_lourd * (1.0 + _charge * 0.5) if _lourd else arme.desequilibre_leger
	if _affaibli:
		stagger *= DegatsCombat.AFFAIBLI
	return {
		"type": arme.type_degats, "point": e["point"], "direction": e["direction"], "normale": e["normale"],
		"zone": DegatsCombat.zone(e["objet"] as Node3D, e["point"]), "attaque": attaque, "arme": arme.id,
		"stagger": stagger, "collider": e["collider"], "affaibli": _affaibli, "charge": _charge,
		"instant": _instant_impact,   # temps de phase active de l'impact (s), sur la grille du tracé
	}

## Torche : pose de repos (miroir), suit les animations passives ; baissée pendant la garde, rangée avec T, recule
## un peu pendant les coups (contrepoids).
func _poser_torche(dt: float) -> void:
	var baisse := 0.0
	if bloque:
		baisse = 0.14
	if combat.attaque() or combat.etat == EtatCombat.RECUPERATION:
		baisse = 0.04
	if not torche_sortie:
		baisse = 0.5
	_baisse_torche = lerpf(_baisse_torche, baisse, 1.0 - exp(-8.0 * dt))
	var p := _pose_torche()
	p.origin += Vector3(0.0, -_baisse_torche, _baisse_torche * 0.2)
	pivot_torche.transform = passifs.decalage_g * p
	var allumee := torche_sortie or _baisse_torche < 0.36
	for fl in flammes:
		fl.emitting = allumee
	for n: Node3D in _visuels_torche:
		n.visible = allumee
	torche_lumiere.visible = allumee
	# lumière vacillante : sinus incommensurables + scintillement par paliers (14 par seconde), sans hasard par image
	var palier := floorf(_respiration * 14.0)
	var scint := fposmod(sin(palier * 12.9898) * 43758.5453, 1.0)
	torche_lumiere.light_energy = 1.4 + sin(_respiration * 13.0) * 0.12 + sin(_respiration * 29.0) * 0.08 + scint * 0.14
	_halo_mat.set_shader_parameter("intensite", 0.65 + (torche_lumiere.light_energy - 1.4) * 0.7)
