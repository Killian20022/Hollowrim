extends Node3D
## Mains du joueur (enfant de la caméra) : arme de la main droite, objet de la main gauche (torche).
## Clic gauche court : coup léger (combo de directions). Maintenir : charge puis coup lourd au relâchement.
## Clic droit maintenu : garde (une garde levée juste avant l'impact = parade). T : sortir / ranger la torche.
## F3 (ou --debug-combat) : débogage (tracé de lame, état de combat, endurance).
##
## Architecture du combat (scripts/combat/, règles et valeurs : docs/COMBAT.md) :
##   EntreesCombat     entrées horodatées + mémoire d'entrée          EtatCombat     machine à états (Idle … Equip)
##   Equipement        main droite / main gauche (DonneesArme)        DonneesArme    stats, modèle, prise, pose de repos
##   ProfilsAnimation  gestes d'attaque (clip, fenêtres, combo)       MouvementsPassifs  respiration, marche, sprint, saut…
##   AnimateurBras     ANIMATIONS À IMAGES CLÉS du bras droit (clés d'os authorées dans Blender, AnimationPlayer)
##   TraceLame         détection par tracé de lame (pas fixe)         DegatsCombat   calcul et application des dégâts
##   RetourCoups       sons, étincelles, arrêt sur image, secousse
## Ce script orchestre : il lit les entrées, fait avancer la machine à états, choisit et cadence le clip du bras droit
## (fondus courts), pose la couche additive des mouvements passifs, l'IK de la main gauche (torche) et lance le tracé.
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
## Fenêtre de parade parfaite (s) : réglée dans DefenseJoueur (anti-spam compris) ; gardée ici pour l'ancienne interface.
const FENETRE_PARADE := DefenseJoueur.FENETRE_PARADE
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
## Réactivité (docs/COMBAT_LATENCE.md) : fondu d'entrée d'un coup dont le clip part de la pose affichée (s de clip), et
## écart de pointe (px de l'écran 480×270) en dessous duquel on le considère « parti de la pose affichée ».
const FONDU_VIF := 0.03
const FONDU_PROCHE := 12.0

var joueur: CharacterBody3D
## Bras droit animé par clés (AnimateurBras) et couche additive des mouvements passifs (decalage_bras.gd).
var anim := AnimateurBras.new()
var _couche_passive: SkeletonModifier3D
var _clip := ""                 # clip du geste en cours (coups, contre, finisher)
var _m := {}                    # ses marqueurs (s de clip)
var _lourd_nom := "lourd"       # attaque puissante choisie au début de la charge (selon le déplacement)
var _offset_d := Transform3D()  # décalage additif ponctuel (dégainer, rebond, tremblement de charge)
var combat := EtatCombat.new()
var entrees := EntreesCombat.new()
var equipement := Equipement.new()
var passifs := MouvementsPassifs.new()
var trace := TraceLame.new()
## Arme de la main droite (raccourci de equipement.main_droite).
var arme: DonneesArme
## Défense (phase 3) : garde orientée, garde brisée, parade parfaite, fenêtre de contre-attaque (scripts/combat/defense_joueur.gd).
var defense := DefenseJoueur.new()
## Temps depuis la levée de la garde (ancienne interface : lu / remis à zéro par les tests).
var temps_garde: float:
	get:
		return defense.temps_garde
	set(v):
		defense.temps_garde = v
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
## Magie et deux mains (scripts/magie/main_sort.gd, docs/MAGIE.md) : SEUL point d'accroche — entrées interceptées avant
## l'épée, garde selon les règles des deux mains, pose des mains qui incantent appliquée après celle de l'épée.
var magie: Node

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
var _duree_tenue := 0.0       # pose armée tenue, lisible (2-3 images)
var _duree_suivi := 0.07      # dépassement après B, au début de la récupération
## Coups conçus EN ESPACE ÉCRAN (passe 4, docs/COMBAT.md) : pendant les coups, la main suit EXACTEMENT la pose du geste
## (poignet libre, orientation_main sans borne) et le coude est placé à chaque image pour que l'avant-bras prolonge la
## poignée À L'ÉCRAN (_pole_ecran) : aucune cassure de poignet visible, quelle que soit l'orientation 3D.
## Anciennes constantes du poignet rigide (passe 3), gardées pour les outils.
const ANGLE_COUP := 40.0
const DEVIATION_COUP := 15.0
const FLEXION_COUP := 15.0
## Allonge maximale du bras (part de épaule → main) : au-delà, l'épaule DROITE glisse vers la main (os upperarm_r
## déplacé, hors écran ; le bras gauche ne bouge pas).
## (0,85 : le coude reste plié, l'avant-bras peut s'aligner sur la poignée à l'écran).
const ALLONGE_BRAS := 0.85
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
# phase 3 : contre-attaque, garde brisée, parade parfaite, finisher
var _contre := false            # le geste en cours est une contre-attaque (attaque « contre »)
var _titube_garde := false      # le déséquilibre en cours vient d'une garde brisée (pas d'un rebond de lame)
var _parade_eclat := 0.0        # s restantes du geste de parade parfaite (la lame chasse l'arme adverse)
var _fin_cible: Node3D
var _fin_cat := ""
var _fin_geste := {}
var _fin_t := 0.0
var _fin_frappe := false
## Dernier finisher lancé par le joueur : {cible, categorie, resultat} (débogage, tests).
var dernier_finisher := {}
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
## IK du bras DROIT, INACTIVE par défaut (les clips pilotent ce bras) : seule la magie l'allume quand la main droite
## incante (main_sort.gd, _poser_mains), pour poser la main sur pivot_epee par-dessus le clip.
var _ik_d: TwoBoneIK3D
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
## Traînée de lame pixel (TraineeLame) et suivi de son échantillonnage à pas fixe.
var trainee: TraineeLame
var _t_trainee := 0.0
## Bras : repère de base, épaule droite (repère du nœud bras), longueurs du bras et de l'avant-bras, angle du coude
## autour de l'axe épaule → main (continuité d'une image à l'autre).
var _bras_base := Transform3D()
var _epaule_bras := Vector3.ZERO
var _l_bras := 0.3
var _l_avant_bras := 0.27
var _angle_coude := 0.0
var _decalage_bras := Vector3.ZERO
var _os_epaule := -1
var _repos_epaule := Vector3.ZERO
## Dernier écart (degrés) entre avant-bras et poignée à l'écran visé par _pole_ecran (outils de mesure).
var ecart_coude := 0.0
var coude_vise := Vector3.ZERO

func _ready() -> void:
	arme = equipement.main_droite
	# les pivots ne portent plus rien : ce sont les cibles que les mains suivent (IK)
	pivot_epee = Node3D.new()
	add_child(pivot_epee)
	pivot_torche = Node3D.new()
	add_child(pivot_torche)
	pivot_torche.transform = _pose_torche()
	_bras()
	anim.jouer("repos", 0.0)
	_pose_courante = anim.pose_affichee()
	pivot_epee.transform = _pose_courante
	equipement.change.connect(_sur_equipement)
	joueur.inventaire.change.connect(func() -> void: equipement.choisir_selon_inventaire(joueur.inventaire))
	equipement.choisir_selon_inventaire(joueur.inventaire)
	_installer_arme()
	porte_torche = Node3D.new()
	_accroche_g.add_child(porte_torche)
	porte_torche.transform = PRISE_G
	_torche()
	trainee = TraineeLame.new()
	add_child(trainee)
	trainee.couleurs(arme.couleur_trainee, arme.couleur_trainee_coeur)
	Jeu.option("affichage", "reduire_mouvements")   # charge les options si besoin
	combat.change.connect(_sur_changement_etat)
	RetourImpact.precharger()   # sons de lame, de blocage et de parade (pack de combat)
	magie = preload("res://scripts/magie/main_sort.gd").new()
	magie.mains = self
	add_child(magie)

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
	# bras du héros assortis à son corps (HerosSkarnholt) : manches de mailles d'acier, brassards, gants de cuir sombre, revers de fourrure
	_mats.merge(HerosSkarnholt.materiaux_fps(), true)
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
	regler_poignet(false)
	var g_coude := equipement.gauche_rangee.repos_coude
	_coude_g.position = Vector3(-g_coude.x, g_coude.y, g_coude.z)
	_orient_d.prise = PRISE_D
	anim.prise = PRISE_D
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
	if trainee != null:
		trainee.couleurs(arme.couleur_trainee, arme.couleur_trainee_coeur)
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
	_bras_base = bras.transform
	var rel := Transform3D()
	var n: Node = _sq
	while n != null and n != bras:
		rel = (n as Node3D).transform * rel
		n = n.get_parent()
	var os_e := rel * _sq.get_bone_global_rest(_sq.find_bone("upperarm_r")).origin
	var os_c := rel * _sq.get_bone_global_rest(_sq.find_bone("lowerarm_r")).origin
	var os_m := rel * _sq.get_bone_global_rest(_sq.find_bone("hand_r")).origin
	_epaule_bras = os_e
	_os_epaule = _sq.find_bone("upperarm_r")
	_repos_epaule = _sq.get_bone_rest(_os_epaule).origin
	_l_bras = os_e.distance_to(os_c)
	_l_avant_bras = os_c.distance_to(os_m)
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
	# IK à deux os : main GAUCHE seulement (torche, plus tard sorts). Le bras droit est joué par ses animations à images
	# clés (AnimateurBras) ; son IK et son orienteur de poignet ne servent plus (orienteur gardé inactif : réglages d'arme).
	var ik := TwoBoneIK3D.new()
	_sq.add_child(ik)
	ik.set_setting_count(1)
	ik.set_root_bone_name(0, "upperarm_l")
	ik.set_middle_bone_name(0, "lowerarm_l")
	ik.set_end_bone_name(0, "hand_l")
	ik.set_target_node(0, ik.get_path_to(cible_g))
	ik.set_pole_node(0, ik.get_path_to(coude_g))
	# IK droite de secours, éteinte : n'agit que lorsqu'un sort occupe la main droite (MainSort l'active)
	_ik_d = TwoBoneIK3D.new()
	_sq.add_child(_ik_d)
	_ik_d.set_setting_count(1)
	_ik_d.set_root_bone_name(0, "upperarm_r")
	_ik_d.set_middle_bone_name(0, "lowerarm_r")
	_ik_d.set_end_bone_name(0, "hand_r")
	_ik_d.set_target_node(0, _ik_d.get_path_to(cible_d))
	_ik_d.set_pole_node(0, _ik_d.get_path_to(coude_d))
	_ik_d.active = false
	for i in 2:
		var o := SkeletonModifier3D.new()
		o.set_script(ORIENTATION)
		o.os = ["hand_r", "hand_l"][i]
		o.cible = [cible_d, cible_g][i]
		o.prise = [PRISE_D, PRISE_G][i]
		_sq.add_child(o)
		if i == 0:
			_orient_d = o
			o.active = false
	_accroche_d = BoneAttachment3D.new()
	_accroche_d.bone_name = "hand_r"
	_sq.add_child(_accroche_d)
	_accroche_g = BoneAttachment3D.new()
	_accroche_g.bone_name = "hand_l"
	_sq.add_child(_accroche_g)
	# animations du bras droit + couche additive des mouvements passifs (après l'animation, avant l'affichage)
	anim.base = _bras_base
	anim.prise = PRISE_D
	anim.installer(bras, _sq)
	GestesDefense.animateur = anim
	_couche_passive = SkeletonModifier3D.new()
	_couche_passive.set_script(preload("res://scripts/combat/decalage_bras.gd"))
	_sq.add_child(_couche_passive)

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

## Pose de repos de l'épée (repère des mains) : première image du clip « repos ».
func _pose_repos() -> Transform3D:
	return anim.pose_arme("repos", 0.0)

## Torche (ou objet de la main gauche) : pose de repos de sa DonneesArme, en miroir côté gauche.
func _pose_torche() -> Transform3D:
	var g: DonneesArme = equipement.gauche_rangee
	return ProfilsAnimation.transform_pose([g.repos_poignee, g.repos_lame, g.repos_fil], -1.0)

## Pose nommée (outils de réglage, --mains=nom) → [clip, temps] : repos, armer, milieu, frappe, suivi (coup A), charge,
## garde, encaisse, parade, sprint.
func _clip_pose(nom: String) -> Array:
	var ma := anim.marqueurs("coup_a")
	match nom:
		"armer":
			return ["coup_a", float(ma["arme"])]
		"milieu":
			return ["coup_a", (float(ma["frappe"]) + float(ma["fin_frappe"])) * 0.5]
		"frappe":
			return ["coup_a", float(ma["fin_frappe"])]
		"suivi":
			return ["coup_a", float(ma["suivi"])]
		"charge":
			return ["charge_lourd", anim.longueur("charge_lourd")]
		"encaisse":
			return ["encaisse", 0.05]
		"parade":
			return ["parade", 0.04]
		"garde", "sprint", "repos", "garde_brisee":
			return [nom, 0.15 if nom == "garde_brisee" else 0.0]
	return ["repos", 0.0]

func _pose(nom: String, _sens := 1.0) -> Transform3D:
	var c := _clip_pose(nom)
	return anim.pose_arme(c[0], c[1])

# --- entrées ----------------------------------------------------------------------------

func _peut_agir() -> bool:
	return joueur != null and not joueur.mort and not joueur.en_dialogue

func _unhandled_input(e: InputEvent) -> void:
	if not _peut_agir() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if magie != null and magie.intercepter(e):
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
		EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CONTRE:
			return ARMER if _t_geste < _duree_prep + _duree_tenue else FRAPPE
		EtatCombat.FINISHER:
			return ARMER if _fin_t < GestesDefense.FINISHER["elan"] else FRAPPE
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

## Attaque puissante selon le déplacement au début de la charge (comme Skyrim) : à l'arrêt, grand balayage horizontal
## droite → gauche ; en avançant, vertical par-dessus ; de côté, balayage vers ce côté ; en reculant, coup de pommeau.
func _choisir_lourd() -> String:
	var lourds: Dictionary = _profil().get("lourds", {})
	var loc := joueur.global_transform.basis.inverse() * joueur.velocity
	var choix := "arret"
	if absf(loc.x) > SEUIL_COTE and absf(loc.x) > absf(loc.z):
		choix = "droite" if loc.x > 0.0 else "gauche"
	elif loc.z < -SEUIL_AVANT:
		choix = "avant"
	elif loc.z > SEUIL_RECUL:
		choix = "arriere"
	return String(lourds.get(choix, _profil()["lourd"]))

## Démarre un coup (léger d'abord : il deviendra lourd si le bouton reste tenu au-delà du seuil). `enchaine` : l'appui
## tombe dans la fenêtre de combo du coup précédent (le combo continue, le geste repart du côté où l'autre a fini).
func _commencer_attaque(enchaine := false) -> void:
	if not arme.est_arme():
		return
	# phase 3 : juste après une parade parfaite → contre-attaque (elle consomme l'ouverture « apres_parade » de la cible
	# touchée : le finisher ne suit que si la posture casse) ; sinon un ennemi ouvert à portée → finisher
	if defense.contre > 0.0 and _commencer_contre():
		return
	if _tenter_finisher():
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
	_contre = false
	_geste = GestesDefense.geste(_geste_nom) if GestesDefense.GESTES.has(_geste_nom) else ProfilsAnimation.geste(arme.profil, _geste_nom)
	_t_geste = 0.0
	_t_trace = 0.0
	_actif_lance = false
	_issue_arret = ""
	_affaibli = false
	_charge_signalee = false
	if not lourd:
		_charge = 0.0
	# durées du geste = instants du clip (marqueurs, s à vitesse 1) divisés par la vitesse de l'arme
	_clip = String(_geste["clip"])
	_m = anim.marqueurs(_clip)
	var v := maxf(arme.vitesse, 0.1)
	_duree_prep = maxf(float(_m["arme"]), 1e-3) / v
	_duree_tenue = (float(_m["frappe"]) - float(_m["arme"])) / v
	_duree_active = (float(_m["fin_frappe"]) - float(_m["frappe"])) / v
	_duree_suivi = (float(_m["suivi"]) - float(_m["fin_frappe"])) / v
	_duree_recup = (float(_m["fin"]) - float(_m["fin_frappe"])) / v
	# profil de l'arme (docs/COMBAT.md, « Profils des 5 épées ») : préparation et récupération propres, en plus de la vitesse
	_duree_prep *= maxf(arme.preparation, 0.1)
	_duree_tenue *= maxf(arme.preparation, 0.1)
	_duree_suivi *= maxf(arme.recuperation, 0.1)
	_duree_recup *= maxf(arme.recuperation, 0.1)
	_depart = _pose_courante
	# fondu court depuis la pose affichée, terminé avant la frappe (l'image = le tracé pendant la phase active).
	# Réactivité (docs/COMBAT_LATENCE.md) : si le clip part de la pose affichée (coup lancé depuis le repos, pointe à moins
	# de FONDU_PROCHE px), fondu de FONDU_VIF seulement — le fondu long atténuait les premières images du geste.
	var fondu := minf(0.08, maxf(float(_m["frappe"]), 0.02) * 0.7)
	if _ecart_px(_pose_courante, anim.pose_arme(_clip, 0.0)) < FONDU_PROCHE:
		fondu = minf(fondu, FONDU_VIF)
	anim.jouer(_clip, fondu)

## Écart (pixels de l'écran 480×270) entre les pointes de deux poses de l'épée (repère des mains).
func _ecart_px(a: Transform3D, b: Transform3D) -> float:
	var ea := ProfilsAnimation.vers_ecran(transform * (a * _pointe_lame))
	var eb := ProfilsAnimation.vers_ecran(transform * (b * _pointe_lame))
	return ((ea - eb) * Vector2(240.0, 135.0)).length()

## Réactivité (docs/COMBAT_LATENCE.md) : le coup qui vient de partir avance DÉJÀ dans l'image de l'appui (ou du relâchement
## de la charge ; avant : il ne
## bougeait qu'à l'image suivante, 1 image de retard : 17 ms à 60 i/s, 33 ms à 30 i/s).
func _reponse_immediate(dt: float) -> void:
	if combat.etat in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.CONTRE]:
		_avancer_geste(dt)

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
	trainee.couper()
	_t_trainee = 0.0
	_echantillon_trainee(_couche() * _pose_active(0.0), 0.0)
	_cam_prec_ok = false
	# fouetté de lame (pack de combat, catégories lame/) : lourd pour le coup lourd et la contre-attaque
	var fort := _lourd or _contre
	var son := (arme.son_fouette_lourd if arme.son_fouette_lourd != "" else "fouette_lourd") if fort else (arme.son_fouette if arme.son_fouette != "" else "fouette_leger")
	RetourImpact.son(self, son, (get_parent() as Node3D).global_position, -1.0 if fort else -4.0, arme.hauteur_son)

func _finir_geste() -> void:
	if _geste.has("tassement") and "tassement" in joueur:
		joueur.tassement = maxf(joueur.tassement, float(_geste["tassement"]) * (0.6 if _affaibli else 1.0))
	_pose_fin = _pose_courante
	_combo += 1
	_cote_fin = int(_geste.get("cotes", [0, 0])[1])
	_geste_prec = _geste_nom
	_depuis_coup = 0.0
	combat.changer(EtatCombat.RECUPERATION)

## La lame est arrêtée (mur, bouclier, cassable qui tient) : rebond, petite ouverture.
func _rebondir() -> void:
	trainee.couper()
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
	_offset_d = Transform3D()
	entrees.garde_tenue = (magie.garde_tenue() if magie != null else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and _peut_agir()
	if not _peut_agir():
		entrees.attaque_tenue = false
		entrees.tampon = -1.0
	entrees.avancer(dt)
	combat.avancer(dt)
	defense.avancer(dt)
	_parade_eclat = maxf(0.0, _parade_eclat - dt)
	_souris_recente *= exp(-10.0 * dt)
	_encaisse = maxf(0.0, _encaisse - dt)

	var veut_garde: bool = entrees.veut_garde() and not joueur.mort and defense.peut_garder()
	var plat := Vector3(joueur.velocity.x, 0.0, joueur.velocity.z)
	var vitesse_sol := plat.length()
	match combat.etat:
		EtatCombat.REPOS, EtatCombat.MOUVEMENT:
			combat.changer(EtatCombat.MOUVEMENT if vitesse_sol > 0.4 else EtatCombat.REPOS)
			if veut_garde:
				entrees.tampon = -1.0
				if combat.changer(EtatCombat.PARADE):
					defense.lever()
			elif entrees.consommer():
				_commencer_attaque()
				_reponse_immediate(dt)
			if combat.calme():
				_tenir("sprint" if passifs.sprint > 0.5 else "repos", 0.22, dt)
		EtatCombat.PARADE, EtatCombat.GARDE:
			# pas d'attaque normale en garde : seulement la contre-attaque (après une parade parfaite) ou un finisher
			if entrees.tampon >= 0.0 and (defense.contre > 0.0 or not _chercher_finisher().is_empty()):
				entrees.consommer()
				_commencer_attaque()
			else:
				entrees.tampon = -1.0
			if combat.defense():
				# garde tenue ; choc de parade parfaite / coup encaissé : clips courts lancés par defendre(), puis retour
				if anim.clip in ["parade", "encaisse"] and not anim.fini():
					anim.avancer(dt)
				else:
					_tenir("garde", 0.12 if anim.clip not in ["parade", "encaisse"] else 0.06, dt)
				if not veut_garde:
					combat.changer(EtatCombat.REPOS)
				elif combat.etat == EtatCombat.PARADE and not defense.en_parade():
					combat.changer(EtatCombat.GARDE)
		EtatCombat.CONTRE, EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE:
			_avancer_geste(dt)
		EtatCombat.FINISHER:
			_avancer_finisher(dt)
		EtatCombat.CHARGE_LOURDE:
			# armé de l'attaque puissante (clip « charge_* »), tenu jusqu'au relâchement
			anim.avancer(dt)
			if entrees.attaque_tenue:
				_charge = clampf((entrees.duree_appui() - SEUIL_CHARGE) / CHARGE_MAX, 0.0, 1.0)
			if _charge >= 1.0 and not _charge_signalee:
				_charge_signalee = true
				RetourCoups.charge_max(self, _lame, arme.emission)
			# tremblement discret à pleine charge
			if _charge >= 1.0:
				_offset_d.origin = Vector3(sin(_respiration * 47.0), cos(_respiration * 53.0), 0.0) * 0.0025 * passifs.amplitude
			if not entrees.attaque_tenue:
				combat.changer(EtatCombat.ATTAQUE_LOURDE)
				_geste_nom = _lourd_nom
				_preparer_geste(true)
				_reponse_immediate(dt)
		EtatCombat.RECUPERATION:
			# suivi (dépassement après la frappe) puis retour au repos : la fin du clip du geste
			var k := clampf(combat.t / maxf(_duree_recup, 0.01), 0.0, 1.0)
			var t0 := maxf(combat.t - dt, 0.0)
			anim.regler(_t_recup(combat.t))
			if t0 < _duree_suivi and _issue_arret == "":
				# traînée du suivi, échantillonnée à pas fixe entre l'image précédente et celle-ci
				var t1 := minf(combat.t, _duree_suivi)
				var nb := maxi(1, ceili((t1 - t0) / TraceLame.PAS))
				for i in nb:
					var ti := t0 + (t1 - t0) * float(i + 1) / float(nb)
					_echantillon_trainee(_couche() * anim.pose_arme(_clip, _t_recup(ti)), combat.t - ti)
			var fen: Array = _geste.get("enchainement", [DELAI_COMBO, 1.0])
			if combat.t >= float(fen[0]) and entrees.consommer():
				_commencer_attaque(combat.t <= float(fen[1]) * _duree_recup)
				_reponse_immediate(dt)
			elif veut_garde and combat.t > 0.12:
				if combat.changer(EtatCombat.PARADE):
					defense.lever()
			elif k >= 1.0:
				combat.changer(EtatCombat.REPOS)
				_tenir("repos", 0.1, 0.0)
		EtatCombat.DESEQUILIBRE when _titube_garde:
			# garde brisée : clip « garde_brisee » (épée rabattue en bas à droite, puis retour au repos)
			var k := clampf(combat.t / DefenseJoueur.TITUBE, 0.0, 1.0)
			if anim.clip != "garde_brisee":
				anim.jouer("garde_brisee", 0.0)
			anim.regler(k * anim.longueur("garde_brisee"))
			if k >= 1.0:
				_titube_garde = false
				combat.changer(EtatCombat.REPOS)
		EtatCombat.DESEQUILIBRE:
			# rebond (lame arrêtée) : la pose se fige un instant, la main recule, puis le bras revient au repos
			var k := clampf(combat.t / DUREE_REBOND, 0.0, 1.0)
			if combat.t >= 0.06:
				_tenir("repos", 0.2, dt)
			_offset_d.origin = Vector3(0.0, -0.03, 0.08) * sin(minf(k * 2.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.35, 1.0, k))
			if k >= 1.0:
				combat.changer(EtatCombat.REPOS)
		EtatCombat.EQUIPER:
			# l'arme passe sous l'écran puis remonte
			var k := clampf(combat.t / 0.45, 0.0, 1.0)
			_tenir("repos", 0.15, dt)
			_offset_d.origin.y = -sin(k * PI) * 0.35
			if k >= 1.0:
				combat.changer(EtatCombat.REPOS)

	# animations passives (respiration, marche, sprint, saut, inertie) : couche additive par-dessus le clip
	passifs.amplitude = 0.35 if bool(Jeu.option("affichage", "reduire_mouvements")) else 1.0
	var locale := joueur.global_transform.basis.inverse() * Vector3(joueur.velocity.x, joueur.velocity.y, joueur.velocity.z)
	passifs.avancer(dt, locale, joueur.is_on_floor(), combat.calme() or combat.defense())
	var couche := _couche()
	if _pose_figee != "":
		var c := _clip_pose(_pose_figee)
		if anim.clip != c[0]:
			anim.jouer(c[0], 0.0)
		anim.regler(c[1])
		couche = Transform3D()
	_couche_passive.decalage = _bras_base.affine_inverse() * couche * _bras_base
	_pose_courante = anim.pose_affichee()
	pivot_epee.transform = couche * _pose_courante
	trainee.avancer(dt)

	# pendant une conversation, on baisse les armes
	_baisse = lerpf(_baisse, 0.45 if joueur.en_dialogue else 0.0, 1.0 - exp(-6.0 * dt))
	position = Vector3(0.0, -_baisse, 0.0)
	_poser_torche(dt)
	if magie != null:
		magie.avancer(dt)
	_cam_prec = _transform_monde()
	_cam_prec_ok = true

## Couche additive du bras droit (repère des mains) : mouvements passifs × décalage ponctuel de l'état.
func _couche() -> Transform3D:
	return passifs.decalage_d * _offset_d

## Pose tenue / boucle d'attente : lance le clip s'il n'est pas déjà joué (fondu), puis l'avance.
func _tenir(nom: String, fondu: float, dt: float) -> void:
	if anim.clip != nom:
		anim.jouer(nom, fondu)
	else:
		anim.avancer(dt)

## Temps du clip du geste pendant la préparation (armé, puis tension tenue jusqu'au début de la frappe).
func _t_prep(t: float) -> float:
	var a := float(_m["arme"])
	if t <= _duree_prep:
		return a * t / maxf(_duree_prep, 1e-4)
	return a + (float(_m["frappe"]) - a) * clampf((t - _duree_prep) / maxf(_duree_tenue, 1e-4), 0.0, 1.0)

## Temps du clip pendant la frappe (t : temps de phase active, s de jeu).
func _t_actif(t: float) -> float:
	return float(_m["frappe"]) + (float(_m["fin_frappe"]) - float(_m["frappe"])) * clampf(t / maxf(_duree_active, 1e-4), 0.0, 1.0)

## Temps du clip pendant la récupération (suivi puis retour au repos).
func _t_recup(t: float) -> float:
	return float(_m["fin_frappe"]) + (float(_m["fin"]) - float(_m["fin_frappe"])) * clampf(t / maxf(_duree_recup, 1e-4), 0.0, 1.0)

## Réglage immédiat du poignet (installation de l'arme, outils).
func regler_poignet(coup: bool) -> void:
	_orient_d.angle_min = deg_to_rad(ANGLE_COUP - DEVIATION_COUP) if coup else deg_to_rad(90.0 - arme.deviation_poignet)
	_orient_d.angle_max = deg_to_rad(ANGLE_COUP + DEVIATION_COUP) if coup else deg_to_rad(90.0 + arme.deviation_poignet)
	_orient_d.flexion_max = deg_to_rad(FLEXION_COUP if coup else 55.0)

## Préparation (vers la pose armée), attente du relâchement (le coup peut devenir lourd), phase active avec tracé.
func _avancer_geste(dt: float) -> void:
	var tenu := combat.etat == EtatCombat.ATTAQUE_LEGERE and entrees.attaque_tenue
	if tenu and entrees.duree_appui() >= SEUIL_CHARGE:
		if combat.changer(EtatCombat.CHARGE_LOURDE):
			# l'attaque puissante se choisit ici (selon le déplacement) : son armé se voit pendant la charge
			_lourd_nom = _choisir_lourd()
			anim.jouer(String(ProfilsAnimation.geste(arme.profil, _lourd_nom)["charge"]), 0.1)
		return
	var fin_prep := _duree_prep + _duree_tenue
	_t_geste = minf(_t_geste + dt, fin_prep) if tenu else _t_geste + dt
	if not _actif_lance:
		if _t_geste < fin_prep or tenu:
			# préparation vers A, puis A tenue un court instant (lisible) ; bouton encore tenu : la lame reste armée
			# jusqu'au relâchement ou au seuil de charge
			anim.regler(_t_prep(_t_geste))
			return
		_actif_lance = true
		_t_actif_prec = 0.0
		_lancer_phase_active()
	var t_actif := minf(_t_geste - fin_prep, _duree_active)
	var t_prec := _t_actif_prec
	_t_actif_prec = t_actif
	var arret := _tracer(t_prec, t_actif)
	anim.regler(_t_actif(arret if arret >= 0.0 else t_actif))
	# traînée : échantillons à pas fixe jusqu'à l'instant courant (ou l'arrêt de la lame)
	var t_fin_trainee := arret if arret >= 0.0 else t_actif
	while _t_trainee + TraceLame.PAS <= t_fin_trainee + 1e-9:
		_t_trainee += TraceLame.PAS
		_echantillon_trainee(_couche() * _pose_active(_t_trainee), t_actif - _t_trainee)
	if arret >= 0.0:
		if _issue_arret == "arret":
			_finir_geste()
		else:
			_rebondir()
		return
	if t_actif >= _duree_active:
		_finir_geste()

## Échantillon de la traînée : garde et pointe de la lame pour une pose (repère des mains), daté de `retard` s.
func _echantillon_trainee(pose: Transform3D, retard: float) -> void:
	trainee.ajouter(pose * _garde_lame, pose * _pointe_lame, retard)

## Pose de l'épée (repère des mains, sans couche passive) au temps t de la frappe : le clip du geste, recalculé par
## cinématique directe sur ses pistes (AnimateurBras.pose_arme) — ce que l'image montre au même instant.
func _pose_active(t_actif: float) -> Transform3D:
	return anim.pose_arme(_clip, _t_actif(t_actif))

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
	var oeil_local := transform.affine_inverse() * Vector3.ZERO   # œil (caméra) dans le repère des mains
	var max_cibles := maxi(arme.multi_cibles, 1)
	var k := int(ceil(maxf(_t_trace, debut) / TraceLame.PAS - 1e-6))
	while true:
		var ts := k * TraceLame.PAS
		if ts > minf(t1, fin) + 1e-9:
			break
		_t_trace = ts + 1e-6
		k += 1
		var f := 1.0 if t1 <= t0 else clampf((ts - t0) / (t1 - t0), 0.0, 1.0)
		var monde := monde_avant.interpolate_with(monde_now, f)
		var xf := monde * _couche() * _pose_active(ts)
		var oeil := monde * oeil_local
		var pts := _points_jeu(xf, points_arme, oeil)
		_instant_impact = ts
		for e in trace.echantillonner(espace, pts, oeil, exclus, max_cibles, true):
			var issue := _resoudre_impact(e)
			if issue != "":
				_issue_arret = issue
				return ts
	return -1.0

## Points de jeu du tracé (monde) : chaque point de la lame VUE À L'ÉCRAN (garde → pointe) est projeté le long de son
## rayon de visée jusqu'à la portée de l'arme — la lame balaie l'écran en travers à 0,5-1 m de l'œil : ce qu'elle
## couvre à l'écran, dans la portée, est touché (cohérent avec l'image, indépendant des images par seconde). Le premier
## point (garde) reste à portee_garde : les rayons latéraux près de la main ne fouillent pas le décor lointain.
func _points_jeu(xf: Transform3D, _points_arme: PackedVector3Array, oeil: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var nb := maxi(arme.points_trace, 7)
	for i in nb:
		var p := xf * _garde_lame.lerp(_pointe_lame, float(i) / float(nb - 1))
		var dist := arme.portee_garde if i == 0 else arme.portee
		var v := p - oeil
		pts.append(oeil + v.normalized() * maxf(dist, v.length()))
	return pts

## Applique un événement du tracé ; renvoie "" (la lame continue), "rebond" (mur, bouclier, cassable qui tient) ou
## "arret" (sol : la lame s'y arrête, le geste se termine sans rebond).
func _resoudre_impact(e: Dictionary) -> String:
	match e["type"]:
		"cible":
			var cible: Node = e["objet"]
			var degats := DegatsCombat.calculer(arme, _lourd, _charge, _affaibli, joueur.competences.multiplicateur_degats(), equipement.bonus_trophee(joueur.inventaire)) * float(_geste.get("force", 1.0))
			var info := _info_coup(e)
			degats += _element(cible, info)
			var r := DegatsCombat.appliquer(cible, degats, joueur.global_position, _puissant, info)
			if cible.is_in_group("ennemis") or cible.is_in_group("cibles_combat"):
				joueur.ennemi_vise = cible   # barre de vie de la cible (HUD)
			# arrêt sur image / secousse / voile rouge : UNE source, les profils d'impact (ProfilImpact). Les cibles équipées
			# d'un CombatEnnemi (draugrs, mannequin) les jouent elles-mêmes avec le profil calculé ; les autres (dragon…) ici.
			var gere: bool = cible.get("combat") is CombatEnnemi
			if gere and _contre:
				(cible.get("combat") as CombatEnnemi).fenetre_parade = 0.0   # l'ouverture de la parade est dépensée par la contre-attaque
			if r == "touche" or r == "tue":
				joueur.competences.pratiquer("epee", 1.8 if _lourd or _contre else 1.0)
				if not gere:
					RetourCoups.touche(joueur, _lourd or _contre)
			elif r == "bloque":
				if not gere:
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

## Effet élémentaire de la lame (DonneesArme.element) : ajoute à `info` le statut à poser (Elements.apres_coup le pose si
## le coup porte) et renvoie les dégâts de l'élément (× résistance de la cible, × 0,5 si le coup est affaibli). Une lame
## enchantée par la magie remplace ce statut (Elements.avant_coup écrit le sien par-dessus).
func _element(cible: Node, info: Dictionary) -> float:
	if arme.element == "" or (arme.element_lourd_seulement and not (_lourd or _contre)):
		return 0.0
	info["statut"] = arme.element
	info["duree_statut"] = arme.element_duree
	info["puissance_statut"] = arme.element_puissance
	info["element_arme"] = arme.element_type
	var d := arme.element_degats * (Elements.resistance(cible, arme.element_type) if arme.element_type != "" else 1.0)
	return d * (DegatsCombat.AFFAIBLI if _affaibli else 1.0)

## Informations du coup transmises à la cible (contrat commun avec combat/degats_gore, voir DegatsCombat).
func _info_coup(e: Dictionary) -> Dictionary:
	var attaque := "legere"
	if _lourd:
		attaque = "chargee_max" if _charge >= 1.0 else "lourde"
	elif _contre:
		attaque = "contre"
	var stagger := DegatsCombat.stagger(arme, attaque, _charge)
	if _affaibli:
		stagger *= DegatsCombat.AFFAIBLI
	return {
		"type": arme.type_degats, "point": e["point"], "direction": e["direction"], "normale": e["normale"],
		"zone": DegatsCombat.zone(e["objet"] as Node3D, e["point"]), "attaque": attaque, "arme": arme.id,
		"stagger": stagger, "collider": e["collider"], "affaibli": _affaibli, "charge": _charge,
		"instant": _instant_impact,   # temps de phase active de l'impact (s), sur la grille du tracé
	}

# --- phase 3 : défense, contre-attaque, finishers -----------------------------------------------

## Coup reçu par le joueur (appelé par joueur.recevoir_coup) : garde levée ET attaquant dans le cône de garde → parade
## parfaite, blocage ou garde brisée (DefenseJoueur). Renvoie {} si la garde ne joue pas (dos, garde baissée), sinon
## {issue, degats (qui passent), cout}. Sons et étincelles distincts ; l'endurance est dépensée ici.
func defendre(degats: float, origine: Vector3, sans_parade := false) -> Dictionary:
	if not bloque or not DefenseJoueur.couvre(joueur, origine):
		return {}
	var r := defense.encaisser(degats, joueur.vigueur, magie.arme_de_garde(arme) if magie != null else arme, joueur.competences.reduction_parade(), origine, sans_parade)
	joueur.depenser(float(r["cout"]))
	var point := pivot_epee.global_position + (get_parent() as Node3D).global_transform.basis * Vector3(-0.25, 0.12, -0.15)
	match String(r["issue"]):
		"parade":
			# parade parfaite : tintement clair (parade_parfaite), gerbe d'étincelles, la lame chasse l'arme adverse ;
			# l'attaquant est déséquilibré (draugr : combat.subir_parade() sur le retour « parade ») ; fenêtre de contre-attaque
			_parade_eclat = 0.14
			_encaisse = 0.0
			anim.jouer("parade", 0.02)
			RetourImpact.son(self, "parade_parfaite", point, 2.0)
			Effets.eclats(self, point, Color(3.2, 2.6, 1.2), 18, 3.2, true)
			if RetourImpact.temps_actif():
				Effets.arret_image(get_tree(), 0.06)
			joueur.secousse = maxf(joueur.secousse, 0.18)
		"bloque":
			_encaisse = DUREE_ENCAISSE
			anim.jouer("encaisse", 0.02)
			RetourImpact.son(self, "metal_blocage", point, 0.0)
			Effets.eclats(self, point, Color(3.0, 2.2, 0.8), 9, 2.4, true)
			joueur.secousse = maxf(joueur.secousse, 0.35)
		"brisee":
			# garde brisée : choc plus sourd, l'épée est rabattue, le joueur titube ; garde impossible ~1 s
			RetourImpact.son(self, "metal_blocage", point, 3.0, 0.8)
			Effets.eclats(self, point, Color(3.0, 2.0, 0.7), 12, 2.8, true)
			joueur.secousse = maxf(joueur.secousse, 0.55)
			_pose_fin = _pose_courante
			_titube_garde = true
			_encaisse = 0.0
			combat.forcer(EtatCombat.DESEQUILIBRE)
			anim.jouer("garde_brisee", 0.0)
	return r

## Contre-attaque (fenêtre DefenseJoueur.FENETRE_CONTRE après une parade parfaite) : geste « contre » (GestesDefense),
## attaque « contre » (CalculDegats : dégâts × 1,3, stagger de contre, profil d'impact lourd ; critique seulement selon
## les règles habituelles, pas automatique). Renvoie faux si la machine à états refuse.
func _commencer_contre() -> bool:
	if not combat.changer(EtatCombat.CONTRE):
		return false
	defense.contre = 0.0
	_geste_nom = "contre"
	_preparer_geste(false)
	_contre = true
	_combo = 0
	_cote_fin = 0
	return true

## Cible achevable devant le joueur : {cible, categorie} ou {}. Conditions : finisher_possible(joueur) non vide (portée,
## hauteur, état — CombatEnnemi), cible devant la caméra (cône ±50°), joueur de face ou de côté par rapport à elle (pas
## dans son dos), rien entre les deux (rayon sur le décor).
const PORTEE_FINISHER := 2.6
const CONE_FINISHER := 50.0
func _chercher_finisher() -> Dictionary:
	if joueur == null or arme == null or not arme.est_arme():
		return {}
	var cam := get_parent() as Node3D
	var avant := -cam.global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized()
	var meilleur := {}
	var d_min := INF
	for groupe in ["ennemis", "cibles_combat"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if not (n is Node3D) or not n.has_method("finisher_possible") or not n.has_method("subir_finisher"):
				continue
			if n.has_method("vivant") and not n.vivant():
				continue
			var c := n as Node3D
			var v := c.global_position - joueur.global_position
			v.y = 0.0
			var d := v.length()
			if d > PORTEE_FINISHER or d >= d_min:
				continue
			if d > 0.3 and v.normalized().dot(avant) < cos(deg_to_rad(CONE_FINISHER)):
				continue
			var face := c.global_transform.basis.z
			if d > 0.3 and absf(Vector2(face.x, face.z).angle_to(Vector2(-v.x, -v.z))) > deg_to_rad(140.0):
				continue   # dans le dos de la cible
			var cat := String(n.finisher_possible(joueur))
			if cat == "":
				continue
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, c.global_position + Vector3(0, 1.1, 0), 1, [joueur.get_rid()])
			var h := get_world_3d().direct_space_state.intersect_ray(q)
			if not h.is_empty() and h["collider"] != c and cam.global_position.distance_to(h["position"]) < d - 0.45:
				continue   # un mur entre les deux
			meilleur = {"cible": c, "categorie": cat}
			d_min = d
	return meilleur

## Lance un finisher si une cible est achevable (appelé au clic, léger ou lourd). Séquence FPS courte et paramétrable
## (GestesDefense.FINISHER, ≤ 0,8 s) : élan avec ralenti léger et caméra verrouillée sur la cible, coup, suivi.
func _tenter_finisher() -> bool:
	var f := _chercher_finisher()
	if f.is_empty() or not combat.changer(EtatCombat.FINISHER):
		return false
	_fin_cible = f["cible"]
	_fin_cat = f["categorie"]
	_fin_geste = GestesDefense.geste(GestesDefense.geste_finisher(_fin_cat))
	_fin_t = 0.0
	_fin_frappe = false
	_depart = _pose_courante
	_clip = String(_fin_geste["clip"])
	_m = anim.marqueurs(_clip)
	anim.jouer(_clip, 0.08)
	_contre = false
	_lourd = true
	_puissant = true
	_geste_nom = "finisher"
	entrees.attaque_tenue = false   # le bouton tenu ne charge pas un coup lourd après le finisher
	entrees.tampon = -1.0
	joueur.depenser(arme.cout_leger)
	if RetourImpact.temps_actif():
		Effets.ralenti(get_tree(), GestesDefense.FINISHER_RALENTI, float(GestesDefense.FINISHER["elan"]) / GestesDefense.FINISHER_RALENTI)
	RetourImpact.son(self, "fouette_lourd", (get_parent() as Node3D).global_position, 1.0, 0.92)
	return true

## Point visé par le finisher : le cou (finisher de taille) ou le buste au sol (coup de grâce).
func _point_finisher() -> Vector3:
	var c := _fin_cible
	var cb: Variant = c.get("combat")
	var h: float = (cb as CombatEnnemi).hauteur if cb is CombatEnnemi else 1.8
	if _fin_cat == "sol":
		return c.global_position + Vector3(0, 0.25, 0)
	return c.global_position + Vector3(0, h * 0.84, 0)

func _avancer_finisher(dt: float) -> void:
	var e := GestesDefense.FINISHER
	var elan := float(e["elan"])
	var coup := float(e["coup"])
	var frappe := float(_m["frappe"])
	var fin_frappe := float(_m["fin_frappe"])
	_fin_t += dt
	var valide := is_instance_valid(_fin_cible) and _fin_cible.is_inside_tree()
	if valide and not _fin_frappe:
		_verrouiller_camera(dt)
	if _fin_t < elan:
		anim.regler(frappe * _fin_t / elan)
		return
	var s := clampf((_fin_t - elan) / coup, 0.0, 1.0)
	anim.regler(frappe + (fin_frappe - frappe) * s)
	# traînée de lame du coup, échantillonnée à pas fixe (comme les coups)
	if _fin_t - dt < elan:
		trainee.couper()
		_t_trainee = 0.0
	var t_coup := minf(_fin_t - elan, coup)
	while _t_trainee + TraceLame.PAS <= t_coup + 1e-9:
		_t_trainee += TraceLame.PAS
		_echantillon_trainee(_couche() * anim.pose_arme(_clip, frappe + (fin_frappe - frappe) * _t_trainee / coup), t_coup - _t_trainee)
	if not _fin_frappe and s >= 0.5:
		_frapper_finisher()
		if "tassement" in joueur:
			joueur.tassement = maxf(joueur.tassement, 1.0)
	if _fin_t >= elan + coup:
		if not _fin_frappe:
			_frapper_finisher()
		# suivi et retour au repos : la récupération habituelle (sans fenêtre de combo avant 0,12 s), fin du clip
		_geste = _fin_geste.duplicate()
		_geste["enchainement"] = [0.12, 0.9]
		_pose_fin = _pose_courante
		_duree_suivi = float(_m["suivi"]) - fin_frappe
		_duree_recup = float(_m["fin"]) - fin_frappe
		_issue_arret = ""
		_depuis_coup = 0.0
		_combo = 0
		_cote_fin = 0
		combat.changer(EtatCombat.RECUPERATION)

## Verrou bref de la caméra : le regard (lacet du joueur, tangage de la tête) rejoint vite le point visé.
func _verrouiller_camera(dt: float) -> void:
	var cam := get_parent() as Node3D
	var v := _point_finisher() - cam.global_position
	var plat := Vector2(v.x, v.z).length()
	if plat < 0.05:
		return
	var k := 1.0 - exp(-GestesDefense.FINISHER_VERROU * dt)
	joueur.rotation.y = lerp_angle(joueur.rotation.y, atan2(-v.x, -v.z), k)
	if "tete" in joueur and joueur.tete != null:
		joueur.tete.rotation.x = lerpf(joueur.tete.rotation.x, clampf(atan2(v.y, plat), -1.2, 0.6), k)

## Impact du finisher : subir_finisher(catégorie, info) — la cible joue sa mort spéciale (décapitation, coup de grâce) et
## le profil d'impact « finisher » (arrêt, secousse, voile rouge, ralenti).
func _frapper_finisher() -> void:
	_fin_frappe = true
	if not is_instance_valid(_fin_cible) or (_fin_cible.has_method("vivant") and not _fin_cible.vivant()):
		return
	var cam := get_parent() as Node3D
	var b := cam.global_transform.basis
	# direction de la lame au contact : mouvement de la pointe dans le clip autour de l'instant de l'impact
	var tf := (float(_m["frappe"]) + float(_m["fin_frappe"])) * 0.5
	var dir := b * (anim.pose_arme(_clip, tf + 0.02) * _pointe_lame - anim.pose_arme(_clip, tf - 0.02) * _pointe_lame)
	var point := _point_finisher()
	var vers := point - joueur.global_position
	vers.y = 0.0
	var info := {
		"type": arme.type_degats, "point": point, "direction": dir.normalized(), "normale": -vers.normalized(),
		"zone": "torse" if _fin_cat == "sol" else "tete", "attaque": "finisher", "arme": arme.id, "stagger": 999.0,
		"collider": _fin_cible, "origine": joueur.global_position, "puissant": arme.poids >= 2.4,
	}
	var r := String(_fin_cible.subir_finisher(_fin_cat, info))
	dernier_finisher = {"cible": _fin_cible, "categorie": _fin_cat, "resultat": r}
	joueur.competences.pratiquer("epee", 2.5)
	joueur.ennemi_vise = _fin_cible

## Torche : pose de repos (miroir), suit les animations passives ; baissée pendant la garde, rangée avec T, recule
## un peu pendant les coups (contrepoids).
func _poser_torche(dt: float) -> void:
	var baisse := 0.0
	if bloque:
		baisse = 0.14
	if combat.attaque() or combat.etat == EtatCombat.RECUPERATION:
		baisse = 0.3   # contrepoids : la torche s'abaisse et s'écarte, la lame balaie l'écran devant elle
	if not torche_sortie:
		baisse = 0.5
	# l'abaissement de combat est vif (la torche dégage avant que la lame ne passe), le retour plus doux
	_baisse_torche = lerpf(_baisse_torche, baisse, 1.0 - exp(-(18.0 if baisse > _baisse_torche and baisse < 0.5 else 8.0) * dt))
	var p := _pose_torche()
	p.origin += Vector3(-minf(_baisse_torche, 0.3) * 0.5, -_baisse_torche, _baisse_torche * 0.2)
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
