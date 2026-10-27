extends EnnemiBase
## IA de combat du Mage nordique (ennemi à distance) — modèle : MageNordique.creer (scripts/mage_nordique.gd, inchangé). Socle :
## EnnemiBase (CombatEnnemi, sang, plaies, décapitation, ragdoll, butin, signal mort). Profil : ProfilCible « mage_nordique » (aucune
## armure, posture faible : chaque coup l'interrompt ; résiste au givre, craint le feu ; finisher « rapide » dès 30 % de vie).
##
## Comportement :
##   - garde ses distances (7-13 m) : recule face au joueur (marche à reculons), se décale de côté, se rapproche pour retrouver la
##     ligne de vue (raycast, 5 fois par seconde) ; contourne les obstacles comme les bandits (EnnemiBase._eviter).
##   - TRAIT DE GIVRE (Projectile.tirer_givre) : orbe qui grossit dans la main gauche ~0,9 s (lueur, bourdonnement), visée figée
##     0,25 s avant le tir ; trait lent (11 m/s), évitable d'un pas de côté ; dégâts de glace + ralentissement du joueur 1,8 s.
##   - SORT DE ZONE : disque d'alerte sous les pieds du joueur (1,4 s), puis pics de glace : dégâts + ralentissement 2,5 s.
##   - TÉLÉPORT COURT quand le joueur colle (< 2,6 m) : tourbillon de givre 0,35 s, il réapparaît à 7-9 m (sol, ligne de vue).
##   - corps à corps faible (coup de bâton) si le joueur le colle et que le téléport se recharge.
## Réactions : un coup moyen (même léger : seuil 7) interrompt le sort et le fait tituber ; coup lourd aux jambes = renversé
## (finisher « sol ») ; posture vide = étourdi. Mort marquée : son cristal éclate (explosion de givre, éclair bleu), puis le corps.
##
## Options (posées avant add_child, monde.creer_ennemi) : vie_imposee, degats_imposes, ident, degats_givre, degats_zone.

enum { GARDE, TRAQUE, INCANTE, ZONE, TELEPORT, BATON, TITUBE, ETOURDI, CHUTE }

const DETECTION := 20.0
const ABANDON := 45.0
const DIST_MIN := 5.5
const DIST_IDEALE := 9.0
const DIST_MAX := 13.0
const DIST_COLLE := 2.6
const MARCHE := 1.35
const RECUL := 1.7
const COURSE := 3.2
const ARMEMENT_TRAIT := 0.95
const ANNONCE_ZONE := 1.4
const RAYON_ZONE := 2.4
const COULEUR := Color(0.62, 0.9, 1.6)

var etat := GARDE
var degats_givre := 14.0
var degats_zone := 22.0
var _recharge := 1.0
var _cd_zone := 3.0
var _cd_tp := 0.0
var _cote_pas := 1.0
var _t_cote := 0.0
var _coup_donne := false
var _cible_tir := Vector3.ZERO
var _centre_zone := Vector3.ZERO
var _alerte: Node3D
var _orbe: MeshInstance3D
var _orbe_lueur: OmniLight3D
var _main_g: BoneAttachment3D
var _duree_titube := 0.55
var _releve := false
var _coince := 0.0
var _pos_prec := Vector3.ZERO
var tirs := 0                    # traits lancés (tests)
var teleports := 0
var zones := 0

func _ready() -> void:
	nom_affiche = "Mage nordique"
	vie_max = 70.0
	degats = 6.0           # bâton : corps à corps faible
	var mod := MageNordique.creer({})
	_equiper(mod, ProfilCible.pour("mage_nordique"), 0.36, 1.8)
	if degats_imposes > 0.0:
		degats_givre = degats_imposes
	_preparer_orbe()
	_pos_prec = global_position
	_cote_pas = 1.0 if randf() < 0.5 else -1.0
	_jouer("Idle", 0.0)
	anim.seek(randf() * 2.0, true)

func en_combat() -> bool:
	return etat != GARDE

func alerter() -> void:
	degeler()
	if etat == GARDE:
		_changer(TRAQUE)

func _changer(e: int) -> void:
	etat = e
	_t = 0.0
	if _pieds:
		var voulu := e != CHUTE
		if _pieds.actif != voulu:
			_pieds.actif = voulu

## Orbe de givre dans la main gauche (caché hors incantation).
func _preparer_orbe() -> void:
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null or sq.find_bone("hand_l") < 0:
		return
	_main_g = BoneAttachment3D.new()
	_main_g.name = "MainSort"
	_main_g.bone_name = "hand_l"
	sq.add_child(_main_g)
	_orbe = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 6
	s.rings = 3
	_orbe.mesh = s
	_orbe.material_override = Palette.lueur(COULEUR)
	_orbe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orbe.position = Vector3(0, 0.1, 0.06)
	_orbe.visible = false
	_main_g.add_child(_orbe)
	_orbe_lueur = OmniLight3D.new()
	_orbe_lueur.light_color = Color(0.55, 0.8, 1.0)
	_orbe_lueur.omni_range = 3.5
	_orbe_lueur.light_energy = 0.0
	_orbe_lueur.visible = false
	_main_g.add_child(_orbe_lueur)

func _orbe_montrer(k: float) -> void:
	if _orbe == null:
		return
	_orbe.visible = k > 0.0
	_orbe_lueur.visible = k > 0.0
	_orbe.scale = Vector3.ONE * lerpf(0.3, 1.3, clampf(k, 0.0, 1.0))
	_orbe_lueur.light_energy = 1.8 * clampf(k, 0.0, 1.0)

func _main_gauche() -> Vector3:
	if _main_g != null and is_instance_valid(_main_g):
		return _main_g.global_position
	return global_position + Vector3(0, 1.4, 0) + global_transform.basis.z * 0.4

# ------------------------------------------------------------------ IA

func _ia(dt: float) -> void:
	_recharge -= dt
	_cd_zone -= dt
	_cd_tp -= dt
	var vj := _vers_joueur()
	var dist: float = vj["dist"]
	var dir: Vector3 = vj["dir"]
	var mort_j: bool = joueur.get("mort") == true
	var mv := Vector3.ZERO
	var vitesse := 0.0
	var loco := ""
	var face := Vector3.ZERO
	var rot := 5.0
	var libre := false
	match etat:
		GARDE:
			var retour := origine - global_position
			retour.y = 0.0
			if retour.length() > 1.5:
				mv = retour.normalized()
				vitesse = MARCHE
				loco = "Walk"
			if dist < DETECTION and not mort_j and (dist < 8.0 or _voit(dt)):
				_changer(TRAQUE)
				_recharge = 0.6
				Sons.jouer_a(self, ["cloth1", "cloth2"], global_position + Vector3.UP, 0.0, 0.1)
		TRAQUE:
			face = dir
			var voit := _voit(dt)
			var av := global_position.distance_to(_pos_prec)
			_pos_prec = global_position
			if _vit > 0.4 and av < _vit * dt * 0.3:
				_coince += dt
			else:
				_coince = maxf(0.0, _coince - dt * 0.5)
			_t_cote -= dt
			if _t_cote <= 0.0 or _coince > 0.5:
				_t_cote = randf_range(1.6, 3.0)
				_cote_pas = -_cote_pas
				_coince = 0.0
			if mort_j or dist > ABANDON:
				_changer(GARDE)
			elif dist < DIST_COLLE and _cd_tp <= 0.0:
				_lancer_teleport()
			elif dist < 1.9 and _recharge <= 0.0:
				_lancer_baton()
			elif not voit or dist > DIST_MAX:
				# retrouver la ligne de vue / la portée : il s'approche (contournement des obstacles)
				mv = dir
				vitesse = COURSE if dist > DIST_MAX + 4.0 else MARCHE
				loco = "Jog_Fwd" if dist > DIST_MAX + 4.0 else "Walk"
				face = Vector3.ZERO
			elif _recharge <= 0.0 and dist >= DIST_COLLE:
				if _cd_zone <= 0.0 and randf() < 0.6:
					_lancer_zone()
				else:
					_lancer_trait()
			elif dist < DIST_MIN:
				# trop près : il recule face au joueur (en biais si un obstacle le bloque)
				mv = (-dir + dir.cross(Vector3.UP) * _cote_pas * (0.9 if _coince > 0.2 else 0.35)).normalized()
				vitesse = RECUL
				loco = "Walk"
				libre = true
			else:
				# à bonne distance : pas chassés de côté (cible mouvante), en gardant la distance idéale
				var lat := dir.cross(Vector3.UP) * _cote_pas
				var rad := dir * clampf((dist - DIST_IDEALE) * 0.3, -0.6, 0.6)
				mv = (lat + rad).normalized()
				vitesse = MARCHE * 0.8
				loco = "Walk"
				libre = true
		INCANTE:
			# orbe qui grossit (lisible), visée suivie puis figée 0,25 s avant le tir : un pas de côté au bon moment l'évite
			if not _coup_donne and dist < DIST_COLLE and _cd_tp <= 0.0:
				_interrompre()     # le joueur arrive au contact : il abandonne le sort et se téléporte
				_lancer_teleport()
				return
			face = dir if _t < ARMEMENT_TRAIT - 0.25 else Vector3.ZERO
			if _t < ARMEMENT_TRAIT - 0.25:
				_cible_tir = joueur.global_position + Vector3(0, 1.15, 0)
			if not _coup_donne:
				_orbe_montrer(_t / ARMEMENT_TRAIT)
				if _t > 0.53 and _anim == "Spell_Simple_Enter":
					_jouer("Spell_Simple_Idle", 0.1)
			if not _coup_donne and _t >= ARMEMENT_TRAIT:
				_coup_donne = true
				_tirer()
			if _t >= ARMEMENT_TRAIT + 0.5:
				_jouer("Spell_Simple_Exit", 0.1, true)
				_recharge = randf_range(1.8, 2.6)
				_changer(TRAQUE)
		ZONE:
			face = dir
			if not _coup_donne and dist < DIST_COLLE and _cd_tp <= 0.0:
				_interrompre()
				_lancer_teleport()
				return
			rot = 2.0
			if _t > 0.53 and _anim == "Spell_Simple_Enter":
				_jouer("Spell_Simple_Idle", 0.1)
			if not _coup_donne:
				_orbe_montrer(0.6 + 0.4 * sin(_t * 18.0))
			if not _coup_donne and _t >= ANNONCE_ZONE:
				_coup_donne = true
				_declencher_zone()
			if _t >= ANNONCE_ZONE + 0.45:
				_recharge = randf_range(1.2, 1.8)
				_cd_zone = randf_range(7.0, 9.0)
				_changer(TRAQUE)
		TELEPORT:
			if not _coup_donne and _t >= 0.35:
				_coup_donne = true
				_teleporter()
			if _t >= 0.6:
				_recharge = 0.5
				_changer(TRAQUE)
		BATON:
			var d_att := _duree("Sword_Attack")
			face = dir if _t < d_att * 0.35 else Vector3.ZERO
			rot = 8.0
			if not _coup_donne and _t >= d_att * 0.42:
				_coup_donne = true
				Sons.jouer_a(self, ["swing", "swing2"], global_position + Vector3.UP, -6.0, 0.2)
				var f := global_transform.basis.z
				if dist < 2.0 and dir.dot(Vector3(f.x, 0, f.z).normalized()) > 0.4:
					var r: String = joueur.recevoir_coup(degats, global_position)
					if r == "parade":
						combat.subir_parade()
						if combat.etourdi > 0.0:
							_etourdir()
						else:
							_tituber(-dir * 1.5, 0.8)
						return
			if _t >= d_att * 0.92:
				_recharge = randf_range(1.0, 1.6)
				_changer(TRAQUE)
		TITUBE:
			if _t >= _duree_titube:
				_changer(TRAQUE)
		ETOURDI:
			if _t > 0.5 and _anim != "Idle":
				_jouer("Idle", 0.3)
				anim.speed_scale = 0.45
			if combat.etourdi <= 0.0:
				anim.speed_scale = 1.0
				_recharge = 0.4
				_changer(TRAQUE)
		CHUTE:
			# renversé (comme draugr.gd) : Death01 accélérée, au sol ~1,3 s (finisher « sol »), se relève
			var d_chute := _duree("Death01") / 1.6
			if not _releve and _t >= d_chute + 1.3:
				_releve = true
				combat.au_sol = false
				anim.speed_scale = 1.4
				anim.play_backwards("Death01")
				_anim = "releve"
			elif not _releve and _t >= d_chute * 0.6:
				combat.au_sol = true
			if _releve and _t >= d_chute + 1.3 + _duree("Death01") / 1.4 * 0.95:
				anim.speed_scale = 1.0
				_releve = false
				_recharge = 0.3
				_changer(TRAQUE)
	_bouger(dt, mv if mv != Vector3.ZERO else dir, vitesse, loco, face, rot, "Idle" if etat in [GARDE, TRAQUE] else "", libre)

# ------------------------------------------------------------------ sorts

func _lancer_trait() -> void:
	_coup_donne = false
	_changer(INCANTE)
	_jouer("Spell_Simple_Enter", 0.1, true)
	_cible_tir = joueur.global_position + Vector3(0, 1.15, 0)
	Sons.jouer_a(self, ["cloth1", "cloth2"], global_position + Vector3.UP * 1.4, -2.0, 0.1)
	Effets.eclats(self, _main_gauche(), COULEUR, 6, 1.0, true)

func _tirer() -> void:
	_jouer("Spell_Simple_Shoot", 0.05, true)
	var depart := _main_gauche() + global_transform.basis.z * 0.25
	var d := (_cible_tir - depart).normalized()
	Projectile.tirer_givre(get_parent(), depart, d, self, degats_givre, joueur)
	tirs += 1
	_orbe_montrer(0.0)
	Effets.eclats(self, depart, COULEUR, 10, 2.0, true)
	Sons.jouer_a(self, ["swing2", "swing3"], depart, -2.0, 0.1)

func _lancer_zone() -> void:
	_coup_donne = false
	_changer(ZONE)
	_jouer("Spell_Simple_Enter", 0.1, true)
	_centre_zone = joueur.global_position
	_alerte = _disque_sol(_centre_zone, RAYON_ZONE, ANNONCE_ZONE, Color(0.5, 0.82, 1.0))
	Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP * 1.4, -6.0, 0.1)

func _declencher_zone() -> void:
	zones += 1
	_jouer("Spell_Simple_Shoot", 0.05, true)
	_orbe_montrer(0.0)
	if is_instance_valid(_alerte):
		_effacer_telegraphe(_alerte, 0.25)
	_alerte = null
	_pics_glace(_centre_zone, RAYON_ZONE * 0.95, 12, 1.1)
	Effets.eclats(self, _centre_zone + Vector3(0, 0.3, 0), COULEUR, 24, 4.0, true)
	Effets.eclats(self, _centre_zone + Vector3(0, 0.2, 0), Color(0.9, 0.94, 1.0), 16, 3.0)
	Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], _centre_zone, 2.0, 0.1)
	if joueur.get("mort") == true:
		return
	var rel := joueur.global_position - _centre_zone
	var dy := absf(rel.y)
	rel.y = 0.0
	if rel.length() <= RAYON_ZONE + 0.2 and dy < 1.6:
		joueur.recevoir_coup(degats_zone, _centre_zone + Vector3(0, 0, 0.01), {"imparable": 0.5, "ralenti": Vector2(2.5, 0.5), "recul": 2.0})

func _lancer_teleport() -> void:
	_coup_donne = false
	_changer(TELEPORT)
	_jouer("Spell_Simple_Enter", 0.05, true)
	anim.speed_scale = 1.6
	Effets.eclats(self, global_position + Vector3(0, 1.0, 0), COULEUR, 18, 2.5, true)
	Sons.jouer_a(self, ["mnstr5", "mnstr6"], global_position + Vector3.UP, -4.0, 0.15)

## Point d'arrivée du téléport : 7-9 m du joueur, du sol sous les pieds, la ligne de vue sur le joueur, pas trop loin de son poste.
func point_teleport() -> Vector3:
	var pj := joueur.global_position
	var depuis := global_position - pj
	depuis.y = 0.0
	var base := atan2(depuis.x, depuis.z) if depuis.length() > 0.1 else randf() * TAU
	for k in 12:
		var a := base + (float(k + 1) / 2) * 0.5 * (1.0 if k % 2 == 0 else -1.0)
		var r := randf_range(7.0, 9.0)
		var p := pj + Vector3(sin(a), 0, cos(a)) * r
		var sol := _sol_sous(p, 3.0, 5.0)
		if sol == Vector3.INF or absf(sol.y - global_position.y) > 2.5:
			continue
		if sol.distance_to(origine) > 22.0:
			continue
		if not _ligne_de_vue_vers(sol + Vector3(0, 1.5, 0), pj + Vector3(0, 1.2, 0)):
			continue
		# place libre (rien à hauteur de buste autour)
		if not (_libre(Vector3.RIGHT, 0.5, sol + Vector3(-0.25, 1.0, 0)) and _libre(Vector3.BACK, 0.5, sol + Vector3(0, 1.0, -0.25))):
			continue
		return sol
	return Vector3.INF

func _teleporter() -> void:
	var p := point_teleport()
	if p == Vector3.INF:
		_cd_tp = 2.0     # nulle part où aller : il se défend au bâton
		_recharge = 0.0
		return
	var avant := global_position
	Effets.eclats(self, avant + Vector3(0, 1.0, 0), COULEUR, 24, 3.5, true)
	Effets.eclats(self, avant + Vector3(0, 0.3, 0), Color(0.9, 0.94, 1.0), 14, 2.0)
	global_position = p + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	_vit = 0.0
	var vj := _vers_joueur()
	rotation.y = atan2(Vector3(vj["dir"]).x, Vector3(vj["dir"]).z)
	Effets.eclats(self, global_position + Vector3(0, 1.0, 0), COULEUR, 24, 3.5, true)
	Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position + Vector3.UP, -2.0, 0.1)
	_cd_tp = randf_range(6.5, 8.0)
	teleports += 1

func _lancer_baton() -> void:
	_coup_donne = false
	_changer(BATON)
	_jouer("Sword_Attack", 0.1, true)

# ------------------------------------------------------------------ coups reçus

func _etat_coup() -> Dictionary:
	return {"peut_bloquer": false, "en_attaque": etat in [INCANTE, ZONE, BATON, TELEPORT], "coup_donne": _coup_donne}

func _apres_degats(_r: Dictionary) -> void:
	if etat == GARDE:
		_changer(TRAQUE)

func _finisher_permis() -> bool:
	return etat != TELEPORT

func _interrompre() -> void:
	_orbe_montrer(0.0)
	if is_instance_valid(_alerte):
		_effacer_telegraphe(_alerte, 0.2)
	_alerte = null

func _reagir(r: Dictionary, vers: Vector3) -> void:
	var reaction := String(r["reaction"])
	if etat in [ETOURDI, CHUTE]:
		return
	if reaction == "etourdi" or combat.etourdi > 0.0:
		_interrompre()
		_etourdir()
		return
	var recul := -vers.normalized() / maxf(combat.profil.poids, 0.3)
	match reaction:
		"chute":
			_interrompre()
			_recul = recul * 2.5
			_releve = false
			_changer(CHUTE)
			_jouer("Death01", 0.08, true)
			anim.speed_scale = 1.6
		"recul":
			_interrompre()
			_tituber(recul * 6.0, 0.85)
		"lourd":
			_interrompre()
			_tituber(recul * 3.5, 0.7)
		"moyen":
			_interrompre()
			_tituber(recul * 1.8, 0.55)
		_:
			if etat not in [INCANTE, ZONE] or r["interrompt"]:
				_interrompre()
				_tituber(recul * 0.8, 0.32)

func _tituber(recul: Vector3, duree: float) -> void:
	_recul = recul
	_duree_titube = duree
	_changer(TITUBE)
	_jouer(["Hit_Chest", "Hit_Head"].pick_random(), 0.05, true)
	anim.speed_scale = clampf(0.55 / duree, 0.6, 1.6)

func _etourdir() -> void:
	_recul = Vector3.ZERO
	_changer(ETOURDI)
	_jouer("Hit_Head", 0.05, true)
	anim.speed_scale = 0.6

# ------------------------------------------------------------------ mort

func _sur_mort() -> void:
	_interrompre()

## Mort marquée : le givre qu'il retenait se libère — éclatement du cristal et de l'orbe (explosion d'éclats lumineux, pics de glace
## sous lui, éclair bleu bref), cri humain ; puis le ragdoll et le sang (CombatEnnemi).
func _special_mort(_sorte: String, _r: Dictionary) -> void:
	if _orbe:
		_orbe.visible = false
		_orbe_lueur.visible = false
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var cristal := global_position + Vector3(0, 2.0, 0)
	if sq != null and sq.find_bone("hand_r") >= 0:
		cristal = (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r"))).origin + Vector3(0, 0.7, 0)
	Effets.eclats(self, cristal, COULEUR, 30, 5.0, true)
	Effets.eclats(self, global_position + Vector3(0, 1.2, 0), Color(0.9, 0.95, 1.0), 20, 3.0)
	_pics_glace(global_position, 1.3, 8, 0.7)
	Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], cristal, 4.0, 0.05)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.8, 1.0)
	l.light_energy = 5.0
	l.omni_range = 7.0
	get_parent().add_child(l)
	l.global_position = cristal
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func _contenu_butin() -> Dictionary:
	var c := {"pieces": randi_range(10, 25), "cristal_givre": 1}
	if randf() < 0.3:
		c["amulette_givre"] = 1
	return c
