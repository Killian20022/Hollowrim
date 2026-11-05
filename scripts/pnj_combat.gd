class_name PnjCombat
extends EnnemiBase
## PNJ du village qui PREND LES ARMES, vient ARRÊTER le joueur ou FUIT (système de crime, scripts/crime.gd). Il prend le corps (modèle,
## pieds posés, squelette) du PNJ d'origine — garde_village.gd ou villageois.gd, mis en sommeil par remplacer() — et le lui rend
## (restaurer()) une fois calmé : amende payée, peine purgée, prime éteinte, joueur parti. Socle EnnemiBase : CombatEnnemi (dégâts,
## posture, réactions, sang), mort en ragdoll, butin, barre de vie du HUD ; il ne double rien du combat des ennemis.
## Modes :
##   « hostile » : il court sur le joueur et frappe (garde : estoc de lance, Haldor : épée, civil : poings) ; groupe « ennemis » ;
##   « arrete »  : un garde marche vers le joueur et, au contact, ouvre le dialogue d'arrestation (Crime.proposer_arrestation) ;
##   « fuite »   : un civil frêle frappé court loin du joueur, puis se calme.
## En « arrete » et « fuite » il est du groupe « cibles_combat » (la lame du joueur le touche) mais pas « ennemis » (Vie ne fait pas fuir
## les civils devant un garde qui arrête quelqu'un).

enum { ATTENTE, COURSE, ATTAQUE, TITUBE }

const COURSE_V := 4.2
const MARCHE_V := 1.4
const DIST_ARRET := 2.1
const CALME_LOIN := 30.0         # m : au-delà, un civil hostile ou en fuite se calme au bout de CALME_T s
const CALME_T := 12.0
const RECHARGE := Vector2(1.3, 2.1)

var pnj: Node3D                  # PNJ d'origine (en sommeil tant que ce combattant existe)
var crime: Crime
var mode := "hostile"
var est_garde := false
var rends_toi := false           # arrestation proposée par un garde hostile (« Rends-toi ! »)
var etat := ATTENTE
var attaques := 0                # coups portés au joueur (tests)
var _clips: Array = ["Sword_Attack"]
var _portee := 1.9
var _cd := 0.0
var _coup_donne := false
var _clip := ""
var _calme_t := 0.0
var _propose := false
var _t_mode := 0.0
var _duree_titube := 0.4
var _loin_arret := 0.0

## Remplace `p` (PNJ du village) par un combattant au même endroit, dans le mode voulu.
static func convertir(p: Node3D, mode_: String, cr: Crime) -> PnjCombat:
	if p == null or not p.is_inside_tree() or p.get("modele") == null:
		return null
	var c := PnjCombat.new()
	c.pnj = p
	c.crime = cr
	c.mode = mode_
	c.joueur = cr.joueur
	c.hud = cr.hud
	c.est_garde = cr.est_garde(p)
	c.nom_affiche = String(p.nom_affiche()) if p.has_method("nom_affiche") else "Villageois"
	c.ident = "crime_" + cr.cle_pnj(p)
	c.name = "Combat_" + p.name
	var parent := p.get_parent()
	var xf := Transform3D(Basis(Vector3.UP, p.global_rotation.y), p.global_position + Vector3(0, 0.05, 0))
	parent.add_child(c)
	c.global_transform = xf
	return c

func _ready() -> void:
	var mod: Node3D = pnj.modele
	pnj.remplacer(self)                      # caché, sans collision, process coupé ; il garde ses données
	mod.get_parent().remove_child(mod)
	var garde_lance := est_garde and pnj.is_in_group("gardes_village")
	vie_max = ReglagesCombat.vie("guerrier" if est_garde else "sbire")
	degats = ReglagesCombat.degats("guerrier" if est_garde else "sbire")
	_equiper(mod, ProfilCible.pour("bandit"), 0.35, 1.8, false)
	_pieds = pnj.get("_pieds")
	if _pieds != null:
		_pieds.corps = self
		_pieds.actif = true
	anim = modele.get_node("Animations")
	if garde_lance and anim.has_animation("Lance_Estoc"):
		_clips = ["Lance_Estoc"]
		_portee = 2.4
	elif est_garde:
		_clips = ["Sword_Attack"]
	else:
		_clips = []
		for n in ["Punch_Cross", "Punch_Jab", "Sword_Attack", "Attack"]:
			if anim.has_animation(n):
				_clips.append(n)
		_portee = 1.5
	if _clips.is_empty():
		_clips = ["Idle"]
	contourne = true
	_regler_groupes()
	_jouer(_repos(), 0.2)
	_cd = randf_range(0.3, 0.8)

# ------------------------------------------------------------------ contrat

func en_combat() -> bool:
	return mode == "hostile" and not est_mort

func parler() -> Array:
	return crime.lignes_arrestation(rends_toi)

func options_dialogue() -> Array:
	return crime.options_arrestation()

## Le dialogue se ferme : un choix fait l'a déjà réglé ; sinon (Échap, joueur parti) c'est une résistance. Vérifié APRÈS l'action du choix.
func fin_conversation() -> void:
	(func() -> void:
		if is_instance_valid(self) and crime != null and crime.arrestation == self:
			crime.arrestation_interrompue(self)).call_deferred()

func changer_mode(m: String) -> void:
	if est_mort or m == mode:
		return
	mode = m
	_t_mode = 0.0
	_propose = false
	_calme_t = 0.0
	if m != "arrete":
		rends_toi = false
	etat = COURSE if m == "hostile" else ATTENTE
	_regler_groupes()

func _regler_groupes() -> void:
	if mode == "hostile":
		add_to_group("ennemis")
		remove_from_group("cibles_combat")
	else:
		remove_from_group("ennemis")
		add_to_group("cibles_combat")

## Rend son corps au PNJ d'origine, à sa place actuelle, puis disparaît.
func pacifier() -> void:
	if est_mort:
		return
	if crime != null:
		crime.retirer(self)
	if pnj == null or not is_instance_valid(pnj):
		queue_free()
		return
	var mod := modele
	remove_child(mod)
	if combat != null and is_instance_valid(combat.reaction_os):
		combat.reaction_os.queue_free()
	var cap := rotation.y
	var pos := global_position
	pnj.restaurer(mod, pos, cap)
	set_physics_process(false)
	queue_free()

# ------------------------------------------------------------------ crochets d'EnnemiBase

func _etat_coup() -> Dictionary:
	return {"peut_bloquer": est_garde and etat != ATTAQUE, "en_attaque": etat == ATTAQUE, "coup_donne": _coup_donne}

func _apres_degats(_r: Dictionary) -> void:
	if crime != null:
		crime.signaler_agression(self)

func _reagir(r: Dictionary, vers: Vector3) -> void:
	var reaction := String(r.get("reaction", ""))
	if reaction in ["lourd", "recul", "chute", "etourdi", "moyen", "leger"]:
		_recul = -vers.normalized() * (2.6 if reaction != "leger" else 1.0)
		_duree_titube = 0.5 if reaction in ["lourd", "recul", "chute", "etourdi"] else 0.3
		etat = TITUBE
		_t = 0.0
		_jouer(combat.anim_coup() if combat != null else "Hit_Chest", 0.05, true)

func _sur_mort() -> void:
	if crime != null:
		crime.retirer(self)
		crime.signaler_meurtre(self)
	if pnj != null and is_instance_valid(pnj):
		if crime != null:
			crime.oublier(pnj)
		pnj.queue_free()              # le PNJ d'origine meurt avec lui (gardes et Vie ignorent les nœuds libérés)
		pnj = null

func _contenu_butin() -> Dictionary:
	return {"pieces": randi_range(8, 25) if est_garde else randi_range(2, 12)}

func _finisher_permis() -> bool:
	return mode == "hostile"

# ------------------------------------------------------------------ IA

func _repos() -> String:
	if mode == "hostile" and anim.has_animation("Sword_Idle"):
		return "Sword_Idle"
	return "Idle"

func _ia(dt: float) -> void:
	_t_mode += dt
	_cd -= dt
	var vj := _vers_joueur()
	var dist: float = vj["dist"]
	var dir: Vector3 = vj["dir"]
	var mort_j: bool = joueur.get("mort") == true
	var mv := Vector3.ZERO
	var vitesse := 0.0
	var loco := ""
	var face := Vector3.ZERO
	if etat == TITUBE:
		if _t > _duree_titube:
			etat = COURSE
			_t = 0.0
		_bouger(dt, Vector3.ZERO, 0.0, "", Vector3.ZERO, 0.0, "")
		return
	if etat == ATTAQUE:
		face = dir
		var duree := _duree(_clip)
		if not _coup_donne and _t > duree * 0.42:
			_coup_donne = true
			var avant := global_transform.basis.z
			if dist < _portee + 0.5 and avant.dot(dir) > 0.35 and not mort_j and not crime.treve:
				attaques += 1
				joueur.recevoir_coup(degats, global_position, {"recul": 3.0, "secousse": 0.3, "type": "physique"})
		if _t > duree:
			etat = COURSE
			_t = 0.0
			_cd = randf_range(RECHARGE.x, RECHARGE.y)
		_bouger(dt, Vector3.ZERO, 0.0, "", face, 8.0, "")      # pas de clip de repos : le geste joue jusqu'au bout
		return
	match mode:
		"hostile":
			if mort_j or (crime != null and crime.treve):
				face = dir
			elif dist > _portee:
				mv = dir
				face = dir
				vitesse = COURSE_V if dist > 3.0 else MARCHE_V * 1.4
				loco = "Jog_Fwd" if vitesse > 2.0 and anim.has_animation("Jog_Fwd") else "Walk"
			else:
				face = dir
				if _cd <= 0.0 and absf(angle_difference(rotation.y, atan2(dir.x, dir.z))) < 0.6:
					_attaquer()
			if not est_garde:
				_calme(dt, dist)
		"arrete":
			if mort_j:
				pass
			elif dist > DIST_ARRET:
				mv = dir
				face = dir
				vitesse = COURSE_V * 0.8 if dist > 7.0 else MARCHE_V
				loco = "Jog_Fwd" if vitesse > 2.0 and anim.has_animation("Jog_Fwd") else "Walk"
				_loin_arret = _loin_arret + dt if dist > 35.0 else 0.0
				if _loin_arret > 10.0:
					pacifier()                   # hors d'atteinte : il renonce (la prime reste, un autre garde le reconnaîtra)
					return
			else:
				face = dir
				if not _propose and crime != null and _t_mode > 0.4:
					_propose = crime.proposer_arrestation(self)
		"fuite":
			var loin := global_position - joueur.global_position
			loin.y = 0.0
			mv = loin.normalized() if loin.length() > 0.1 else -global_transform.basis.z
			vitesse = COURSE_V * 0.9
			loco = "Jog_Fwd" if anim.has_animation("Jog_Fwd") else "Walk"
			_calme(dt, dist)
	_bouger(dt, mv, vitesse, loco, face, 7.0, _repos())

## Civil hostile ou en fuite : loin du joueur assez longtemps, il se calme et redevient lui-même.
func _calme(dt: float, dist: float) -> void:
	_calme_t = _calme_t + dt if dist > CALME_LOIN or joueur.get("mort") == true else 0.0
	if _calme_t > CALME_T:
		pacifier()

func _attaquer() -> void:
	etat = ATTAQUE
	_t = 0.0
	_coup_donne = false
	_vit = 0.0
	_clip = String(_clips.pick_random())
	_jouer(_clip, 0.1, true)
