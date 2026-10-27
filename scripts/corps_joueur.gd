extends Node3D
## Corps visible du joueur à la troisième personne (homme Quaternius vêtu, épée à la main
## droite, torche à la main gauche). Les animations suivent l'état du joueur et de ses mains.
## À la première personne il reste en place, invisible, mais continue de projeter son ombre.

const EPEE := preload("res://assets/modeles/joueur/epee_nordique.glb")
## Prise de l'épée dans la main droite : la même que celle du draugr.
const PRISE := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))

# vitesses au sol (m/s) pour lesquelles chaque cycle de marche a été animé : accordent les pas
const V_MARCHE := 1.3
const V_TROT := 3.0
const V_SPRINT := 5.2
# image de Sword_Attack où l'épée est levée (armer) et où elle protège (garde)
const IMG_ARMER := 0.28
const IMG_GARDE := 1.05

var joueur: CharacterBody3D
var mains: Node3D
var modele: Node3D
var anim: AnimationPlayer
var pivot_torche: Node3D
var flammes: Array[GPUParticles3D] = []
var lumiere: OmniLight3D

var _vue_3 := false
var _cle := ""        # animation + image tenue en cours
var _action := ""      # animation ponctuelle en cours (coup, blessure, atterrissage)
var _fin_action := 0.0
var _etat_mains := -1
var _au_sol := true
var _en_l_air := 0.0
var _mort_jouee := false
var _lacet := 0.0      # orientation du modèle par rapport au joueur (pas de côté, recul)
var _tenir := -1.0     # si >= 0 : image maintenue de l'animation courante
var _t := 0.0
var _debug := ""
var _mailles: Array[MeshInstance3D] = []
var _pieds: PiedsAuSol
var _ragdoll: Ragdoll

func _ready() -> void:
	_creer_modele()
	joueur.touche.connect(_touche)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="):
			_debug = a.substr(7)  # captures : --anim=Nom:temps fige une image d'animation

## Ancienne tenue du joueur (corps Humain : tunique bleue, mante grise, cuirs), avant le héros « garde amélioré » (HerosSkarnholt) ;
## gardée pour les outils de comparaison (outils/compter_tris_persos.gd).
const APPARENCE := {
	"corps": "homme",
	"tenue": {
		"tunique": Color(0.35, 0.4, 0.55), "pantalon": Color(0.8, 0.75, 0.7), "bottes": Color.WHITE,
		"ceinture": Color.WHITE, "mante": Color(1.1, 1.0, 0.95), "brassards": Color.WHITE, "gants": Color.WHITE, "manchettes": Color.WHITE, "sacoche": Color.WHITE,
	},
	"etoffes": {"tunique": "bleu", "mante": "gris", "pantalon": "brun", "bottes": "cuir_a", "ceinture": "cuir_a", "brassards": "cuir_c", "gants": "cuir_a", "manchettes": "gris", "sacoche": "cuir_a"},
	"cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.42, 0.28, 0.17), "barbe": true,
}

## Construit (ou reconstruit, à la résurrection) le modèle vêtu, ses accessoires et ses pieds.
func _creer_modele() -> void:
	# héros « garde de Skarnholt amélioré » (HerosSkarnholt, base GardienNordique, cache disque des corps) ; --persos-kit : personnage de
	# base unifié (PersoDefs.joueur). Équipement (bouclier, casque) : options de HerosSkarnholt.creer.
	var t0 := Time.get_ticks_usec()
	modele = Personnage.creer(PersoDefs.joueur()) if Personnage.kit_actif() else HerosSkarnholt.creer({})
	if Chrono.actif:
		print("CHRONO   corps du joueur %.1f ms (cache lus=%d)" % [(Time.get_ticks_usec() - t0) / 1000.0, CachePersos.lus])
	modele.rotation.y = PI  # le modèle regarde +Z, le joueur -Z
	add_child(modele)
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	_pieds = PiedsAuSol.equiper(modele, joueur) as PiedsAuSol
	_epee(squelette)
	_torche(squelette)
	anim = modele.get_node("Animations")
	anim.animation_finished.connect(_fini)
	_mailles.assign(modele.find_children("*", "MeshInstance3D", true, false))
	_cle = ""
	_jouer("Sword_Idle", 0.0)
	definir_vue(_vue_3)

## Mort : le corps tombe en ragdoll, projeté dans le sens du dernier coup reçu.
func _chuter() -> void:
	var dir: Vector3 = joueur.global_position - joueur.origine_dernier_coup
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else joueur.global_transform.basis.z
	var force := clampf(joueur.degats_dernier_coup * 8.0, 100.0, 400.0)
	var vitesse := Vector3(joueur.velocity.x, 0.0, joueur.velocity.z).limit_length(6.0)
	_ragdoll = Ragdoll.equiper(modele) as Ragdoll
	if _ragdoll == null:
		_action = "Death01"
		_jouer("Death01", 0.15, 1.0, 0.0, -1.0, true)
		return
	_ragdoll.ignorer(joueur)
	_ragdoll.endormir_apres(4.0)
	_ragdoll.declencher(dir * force + Vector3.UP * force * 0.15, joueur.global_position + Vector3(0, 1.2, 0) - dir * 0.2, "spine_03", vitesse)

## true : troisième personne (corps visible) ; false : première personne (ombre seule).
func definir_vue(troisieme: bool) -> void:
	_vue_3 = troisieme
	for mi in _mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if troisieme else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _epee(squelette: Skeleton3D) -> void:
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = "hand_r"
	squelette.add_child(accroche)
	var arme: Node3D = EPEE.instantiate()
	arme.transform = PRISE
	accroche.add_child(arme)
	# acier et cuir en matériaux PS1, par nom de matériau Blender (comme les mains)
	var acier := Palette.tex("acier", Palette.ACIER, 4, 0.3)
	var mats := {
		"lame": Palette.materiau(acier, Vector2.ONE, Color(0.9, 0.95, 1.05)),
		"fer": Palette.materiau(acier, Vector2(2, 2), Color(0.5, 0.52, 0.6)),
		"cuir": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(1, 2)),
	}
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	for mi: MeshInstance3D in arme.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var nom := mat.resource_name.get_slice(".", 0) if mat else ""
			if mats.has(nom):
				mi.set_surface_override_material(i, mats[nom])

## Prise d'un objet long dans la main gauche (torche) : même calcul que la prise de l'épée (outils/calcul_prise.gd), avec les os du côté gauche.
## Le RIG18 du kit (--persos-kit) n'a pas de doigts : transformation relevée une fois avec ce calcul, dans le repère de `hand_l`.
const PRISE_GAUCHE := Transform3D(Basis(Vector3(-0.999251, 0.038329, 0.00529), Vector3(0.014458, 0.243068, 0.969902), Vector3(0.03589, 0.969252, -0.24344)), Vector3(0.007936, 0.142938, 0.002241))

func _prise_gauche(squelette: Skeleton3D) -> Transform3D:
	if squelette.find_bone("index_01_l") < 0:
		return PRISE_GAUCHE
	var p := func(n: String) -> Vector3: return squelette.get_bone_global_rest(squelette.find_bone(n)).origin
	var main: Transform3D = squelette.get_bone_global_rest(squelette.find_bone("hand_l"))
	var index: Vector3 = p.call("index_01_l")
	var auri: Vector3 = p.call("pinky_01_l")
	var milieu: Vector3 = p.call("middle_01_l")
	var bout: Vector3 = p.call("middle_03_l")
	var axe := (index - auri).normalized()
	var doigts := (bout - milieu).normalized()
	var z := (doigts - axe * doigts.dot(axe)).normalized()
	var x := axe.cross(z)
	var poignee := (index + auri) * 0.5 + doigts * 0.035
	return main.affine_inverse() * Transform3D(Basis(x, axe, z), poignee)

func _torche(squelette: Skeleton3D) -> void:
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = "hand_l"
	squelette.add_child(accroche)
	pivot_torche = Node3D.new()
	pivot_torche.transform = _prise_gauche(squelette)
	accroche.add_child(pivot_torche)

	# même torche que celle de la vue à la première personne (scripts/torche.gd, lot 6) : manche, tête, flamme sprite, halo
	var t := Torche.construire(pivot_torche)
	flammes.assign(t["flamme"])
	lumiere = t["lumiere"]
	lumiere.light_energy = 0.0

# --- animations ------------------------------------------------------------------

func _jouer(nom: String, fondu := 0.2, vitesse := 1.0, depart := -1.0, tenir := -1.0, forcer := false) -> void:
	anim.speed_scale = vitesse
	var cle := "%s|%s" % [nom, tenir]
	if _cle == cle and not forcer:
		return
	_cle = cle
	_tenir = tenir
	anim.play(nom, fondu)
	if depart >= 0.0:
		anim.seek(depart, false)

func _fini(nom: StringName) -> void:
	if nom == &"Death01":
		return
	_action = ""

func _touche(_degats: float) -> void:
	if joueur.mort:
		return
	_action = "Hit_Chest"
	_fin_action = _t + 0.45
	_jouer("Hit_Chest", 0.05, 1.0, 0.0, -1.0, true)

func _coup() -> void:
	var puissant: bool = mains._puissant
	var vitesse := 1.4 if puissant else 1.8
	if mains.get("_geste_nom") == "estoc":
		# estoc : seule animation de poussée droit devant de la bibliothèque (pas d'animation d'épée par direction)
		_action = "Punch_Jab"
		_fin_action = _t + 0.87 / 1.6
		_jouer("Punch_Jab", 0.06, 1.6, 0.0, -1.0, true)
		return
	_action = "Sword_Attack"
	_fin_action = _t + (1.3 - IMG_ARMER) / vitesse
	_jouer("Sword_Attack", 0.06, vitesse, IMG_ARMER, -1.0, true)

func _process(dt: float) -> void:
	if joueur == null or mains == null:
		return
	_t += dt
	if _debug != "":
		var d := _debug.split(":")
		anim.play(d[0])
		anim.seek(float(d[1]), true)
		anim.pause()
		return
	# reflet de la torche et de la lumière : seulement visibles à la troisième personne
	var allumee: bool = mains.torche_sortie
	pivot_torche.visible = allumee
	for f in flammes:
		f.emitting = allumee and _vue_3
	lumiere.visible = allumee and _vue_3
	lumiere.light_energy = 1.4 + sin(_t * 13.0) * 0.12 + sin(_t * 29.0) * 0.08 + randf() * 0.12

	if joueur.mort:
		if not _mort_jouee:
			_mort_jouee = true
			_chuter()
		_lacet = lerp_angle(_lacet, 0.0, 1.0 - exp(-8.0 * dt))
		modele.rotation.y = PI + _lacet
		return
	if _mort_jouee:
		# résurrection : le corps ragdoll est remplacé par un modèle neuf
		_mort_jouee = false
		_action = ""
		_cle = ""
		if _ragdoll != null:
			_ragdoll = null
			modele.queue_free()
			_creer_modele()

	# image tenue (armer, garde)
	if _tenir >= 0.0 and anim.current_animation_position > _tenir:
		anim.seek(_tenir, false)

	var etat: int = mains.etat
	if etat != _etat_mains:
		if etat == mains.FRAPPE:
			_coup()
		_etat_mains = etat

	var plat := Vector2(joueur.velocity.x, joueur.velocity.z)
	var vitesse := plat.length()
	var sol := joueur.is_on_floor()
	if sol:
		if not _au_sol and _en_l_air > 0.25 and vitesse < 1.5 and _action == "":
			_action = "Jump_Land"
			_fin_action = _t + 0.3
			_jouer("Jump_Land", 0.08, 2.2, 0.15, -1.0, true)
		_en_l_air = 0.0
	else:
		_en_l_air += dt
		if _au_sol and joueur.velocity.y > 1.0 and _action == "":
			_action = "Jump_Start"
			_fin_action = _t + 0.35
			_jouer("Jump_Start", 0.1, 2.4, 0.0, -1.0, true)
	_au_sol = sol

	if _action != "" and _t >= _fin_action:
		_action = ""

	var but_lacet := 0.0
	if _action == "":
		but_lacet = _locomotion(plat, vitesse, sol, etat)
	_lacet = lerp_angle(_lacet, but_lacet, 1.0 - exp(-10.0 * dt))
	modele.rotation.y = PI + _lacet

## Choisit l'animation de déplacement ; renvoie l'angle de pas de côté du modèle.
func _locomotion(plat: Vector2, vitesse: float, sol: bool, etat: int) -> float:
	if not sol and _en_l_air > 0.2:
		_jouer("Jump", 0.2)
		return 0.0
	var arme_levee: bool = etat in [mains.ARMER, mains.CHARGE]
	if arme_levee:
		_jouer("Sword_Attack", 0.1, 1.0, IMG_ARMER, IMG_ARMER)
		return 0.0
	if mains.bloque and vitesse < 0.5:
		_jouer("Sword_Attack", 0.12, 1.0, IMG_GARDE, IMG_GARDE)
		return 0.0
	if vitesse < 0.4:
		_jouer("Idle_Torch" if mains.torche_sortie else "Sword_Idle", 0.25)
		return 0.0
	# direction du mouvement dans le repère du joueur : 0 = en avant, ±π = en arrière
	var local := joueur.global_transform.basis.inverse() * Vector3(plat.x, 0.0, plat.y)
	var angle := atan2(local.x, -local.z)
	var recul := absf(angle) > deg_to_rad(110.0)
	if recul:
		angle -= signf(angle) * PI
	var nom := "Walk"
	var ref := V_MARCHE
	if vitesse > 4.8:
		nom = "Sprint"
		ref = V_SPRINT
	elif vitesse > 2.3:
		nom = "Jog_Fwd"
		ref = V_TROT
	var echelle := vitesse / ref
	_jouer(nom, 0.2, -echelle if recul else echelle)
	# le corps se tourne vers la direction de marche (pas de côté, pas en arrière)
	return -clampf(angle, deg_to_rad(-65.0), deg_to_rad(65.0))
