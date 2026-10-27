extends EnnemiBase
## IA de combat du Troll de givre (mini-boss lourd) — modèle : TrollGivre.creer (scripts/troll_givre.gd, inchangé). Socle commun :
## EnnemiBase (CombatEnnemi, sang, plaies, décapitation, ragdoll, butin, signal mort). Profil : ProfilCible « troll_givre »
## (beaucoup de vie, armure faible, posture très haute, vulnérable au feu, presque insensible au givre).
##
## Coups (tous TÉLÉGRAPHIÉS, lents, dévastateurs) :
##   BALAYAGE  griffes en arc large (Troll_Griffes ralenti à l'armement ~1,2 s, grognement) : 3,4 m, ±80°. PARABLE : une parade le
##             déséquilibre (−45 % de posture, titube 1 s ; posture vide = étourdi, finisher).
##   ECRASE    poing écrasé au sol (Jump_Start ralenti puis Jump_Land) : disque d'alerte au sol 1,25 s devant lui, puis onde de choc
##             (éclats et pics de glace, tremblement) : 3 m de rayon. SE PARE MAL (60 % des dégâts traversent la garde, ralenti) :
##             il faut sortir du disque. Il reste planté 0,9 s après (fenêtre de punition).
##   CHARGE    6-15 m, ligne de vue : il s'accroupit en rugissant 0,9 s (bande d'alerte au sol, direction figée le dernier quart),
##             puis fonce droit 8,5 m/s. Esquivable de côté ; se bloque mal (35 % traverse) ; contre un mur il s'assomme (1,6 s).
## RAGE à mi-vie (une fois) : rugissement 1,8 s (intouchable en posture), posture pleine, ensuite +30 % de vitesse, gestes +20 %,
## temps de recharge ×0,6. RÉGÉNÉRATION : 6 PV/s après 5 s sans être frappé — coupée 8 s par un coup de FEU (info.type "feu").
## Réactions : hyper-armure des coups légers (seule la flexion procédurale), titube aux coups moyens/lourds hors pouvoir, étourdi
## quand la posture cède. Mort lourde : chute violente (ragdoll), tremblement de caméra, nuage de neige ; décapitation en finisher.
##
## Options (posées avant add_child, monde.creer_ennemi) : vie_imposee, degats_imposes, ident, dort (accroupi, réveil à 9 m).

enum { GARDE, TRAQUE, BALAYAGE, ECRASE, CHARGE_ANNONCE, CHARGE, SONNE, RAGE, TITUBE, ETOURDI, DORT, REVEIL }

const DETECTION := 18.0
const ABANDON := 45.0
const PORTEE_BALAYAGE := 3.4
const ANGLE_BALAYAGE := 0.17      # cos(80°)
const RAYON_ONDE := 3.0
const AVANCE_ONDE := 2.0          # centre de l'onde devant lui
const DUREE_ARMEMENT_ECRASE := 1.25
const MARCHE := 1.3
const COURSE := 3.6
const VITESSE_CHARGE := 8.5
const DUREE_CHARGE := 1.7
const ANNONCE_CHARGE := 0.9
const REGEN := 6.0                # PV/s
const REGEN_DELAI := 5.0
const SANS_REGEN_FEU := 8.0

var etat := GARDE
var dort := false
var degats_onde := 40.0
var degats_charge := 30.0
var rage := false
var _coup_donne := false
var _recharge := 0.8
var _cd_ecrase := 2.0
var _cd_charge := 3.0
var _brule := 0.0                 # s restantes sans régénération (feu)
var _t_regen_fx := 0.0
var _charge_dir := Vector3.ZERO
var _charge_touche := false
var _charge_bloque := 0.0
var _pos_prec := Vector3.ZERO
var _alerte: Node3D
var _centre_onde := Vector3.ZERO
var _duree_titube := 0.6
var _t_impact := 1.0
var regeneres := 0.0              # PV regagnés (débogage, tests)
var derniere_attaque := ""

func _ready() -> void:
	nom_affiche = "Troll de givre"
	vie_max = 420.0
	degats = 30.0
	taille = 1.45
	_mult_force_mort = 1.15
	var mod := TrollGivre.creer({})
	_equiper(mod, ProfilCible.pour("troll_givre"), 0.75, 2.5, false)
	if degats_imposes > 0.0:
		degats_onde = degats_imposes * 1.33
		degats_charge = degats_imposes
	_pos_prec = global_position
	if dort:
		etat = DORT
		_jouer("Crouch_Idle", 0.0)
	else:
		_jouer("Idle", 0.0)
		anim.seek(randf() * 2.0, true)

func en_combat() -> bool:
	return etat not in [GARDE, DORT]

func alerter() -> void:
	degeler()
	if etat == GARDE:
		_changer(TRAQUE)
	elif etat == DORT:
		_reveiller()

## Le troll est large : l'épée de mains.gd vise sa surface côté joueur, à hauteur de poitrine.
func point_impact() -> Vector3:
	var v := Vector3.ZERO
	if joueur != null:
		v = joueur.global_position - global_position
		v.y = 0.0
		v = v.normalized() * 0.6 if v.length() > 0.01 else Vector3.ZERO
	return global_position + Vector3(0, 1.45, 0) + v

func _changer(e: int) -> void:
	etat = e
	_t = 0.0

func _reveiller() -> void:
	_changer(REVEIL)
	_jouer("Idle", 0.5)
	Sons.jouer_a(self, ["ambiance_rugissement1", "ambiance_rugissement2"], global_position + Vector3.UP * 2.0, 0.0, 0.1)

## Multiplicateur de rythme (rage).
func _rythme() -> float:
	return 1.2 if rage else 1.0

# ------------------------------------------------------------------ IA

func _ia(dt: float) -> void:
	_recharge -= dt
	_cd_ecrase -= dt
	_cd_charge -= dt
	_brule = maxf(0.0, _brule - dt)
	_regenerer(dt)
	var vj := _vers_joueur()
	var dist: float = vj["dist"]
	var dir: Vector3 = vj["dir"]
	var mort_j: bool = joueur.get("mort") == true
	var vit_mult := 1.3 if rage else 1.0
	var mv := Vector3.ZERO
	var vitesse := 0.0
	var loco := ""
	var face := Vector3.ZERO
	var rot := 3.2
	var repos := "Idle"
	match etat:
		DORT:
			repos = "Crouch_Idle"
			if dist < 9.0 and not mort_j:
				_reveiller()
		REVEIL:
			face = dir
			if _t > 1.0:
				_changer(TRAQUE)
		GARDE:
			var retour := origine - global_position
			retour.y = 0.0
			if retour.length() > 1.5:
				mv = retour.normalized()
				vitesse = MARCHE
				loco = "Walk"
			if dist < DETECTION and not mort_j and (dist < 9.0 or _voit(dt)):
				_changer(TRAQUE)
				Sons.jouer_a(self, ["ambiance_rugissement1", "ambiance_rugissement2"], global_position + Vector3.UP * 2.0, -2.0, 0.1)
		TRAQUE:
			face = dir
			if mort_j or dist > ABANDON:
				_changer(GARDE)
			elif not rage and vie <= vie_max * 0.5:
				_lancer_rage()
			elif _cd_charge <= 0.0 and dist > 6.0 and dist < 15.0 and _recharge <= 0.0 and _voit(dt):
				_lancer_charge(dir)
			elif dist <= PORTEE_BALAYAGE - 0.5 and _recharge <= 0.0:
				if _cd_ecrase <= 0.0 and (dist < 2.6 and randf() < 0.55 or derniere_attaque == "balayage"):
					_lancer_ecrase(dir)
				else:
					_lancer_balayage()
			elif dist > PORTEE_BALAYAGE - 0.6:
				mv = dir
				vitesse = (COURSE if dist > 5.0 else MARCHE) * vit_mult
				loco = "Jog_Fwd" if dist > 5.0 else "Walk"
		BALAYAGE:
			# armement ralenti (le geste se lit), il se vise jusqu'aux 2/3 de l'armement puis frappe là où il visait
			face = dir if _t < _t_impact * 0.66 else Vector3.ZERO
			rot = 2.6
			if not _coup_donne and _t >= _t_impact:
				_coup_donne = true
				anim.speed_scale = 1.0 * _rythme()
				_frapper_balayage()
				if etat != BALAYAGE:
					return
			if _t >= _t_impact + (_duree("Troll_Griffes") * 0.58) / _rythme():
				_recharge = randf_range(1.4, 2.2) * (0.6 if rage else 1.0)
				_changer(TRAQUE)
		ECRASE:
			if not _coup_donne and _t >= DUREE_ARMEMENT_ECRASE / _rythme():
				_coup_donne = true
				_jouer("Jump_Land", 0.05, true)
				anim.speed_scale = 1.3
				_onde()
			if _t >= DUREE_ARMEMENT_ECRASE / _rythme() + 0.9:
				_recharge = randf_range(1.0, 1.6) * (0.6 if rage else 1.0)
				_cd_ecrase = randf_range(5.0, 7.0) * (0.6 if rage else 1.0)
				_changer(TRAQUE)
		CHARGE_ANNONCE:
			# accroupi, rugit ; il suit le joueur des yeux puis fige la direction (dernier quart) : un pas de côté suffit
			if _t < ANNONCE_CHARGE * 0.72:
				_charge_dir = dir
				face = dir
				rot = 4.0
				if is_instance_valid(_alerte):
					_alerte.rotation.y = atan2(dir.x, dir.z)
					_alerte.global_position = Vector3(global_position.x, _alerte.global_position.y, global_position.z)
			if _t >= ANNONCE_CHARGE:
				_changer(CHARGE)
				_jouer("Sprint", 0.08, true)
				_charge_touche = false
				_charge_bloque = 0.0
				_pos_prec = global_position
				if is_instance_valid(_alerte):
					_effacer_telegraphe(_alerte, 0.6)
				Sons.jouer_a(self, ["giant4", "giant5"], global_position + Vector3.UP, 2.0, 0.1)
		CHARGE:
			mv = _charge_dir
			face = _charge_dir
			_vit = VITESSE_CHARGE * vit_mult
			velocity.x = _charge_dir.x * _vit
			velocity.z = _charge_dir.z * _vit
			anim.speed_scale = 1.1
			move_and_slide()
			_t_pas_charge(dt)
			if not _charge_touche and not mort_j:
				var rel := joueur.global_position - global_position
				rel.y = 0.0
				var devant := rel.dot(_charge_dir)
				var lateral := (rel - _charge_dir * devant).length()
				if devant > -0.3 and devant < 1.9 and lateral < 1.4 and absf(joueur.global_position.y - global_position.y) < 2.0:
					_charge_touche = true
					var r: String = joueur.recevoir_coup(degats_charge, global_position, {"imparable": 0.35, "recul": 11.0, "secousse": 0.8})
					RetourImpact.son(self, "chair", joueur.global_position + Vector3.UP, 0.0, 0.8)
					if r != "touche":
						Effets.eclats(self, joueur.global_position + Vector3(0, 1.2, 0), Color(3.0, 2.2, 0.8), 10, 2.5, true)
			if etat != CHARGE:
				return
			if _t >= DUREE_CHARGE or _charge_touche and _t > 0.25:
				_vit = 2.0
				_recharge = randf_range(1.2, 1.8) * (0.6 if rage else 1.0)
				_cd_charge = randf_range(9.0, 12.0) * (0.6 if rage else 1.0)
				_changer(TRAQUE)
			return
		SONNE:
			# assommé contre un mur : il chancelle (posture entamée : c'est le moment de frapper)
			if _t > 0.4 and _anim != "Idle":
				_jouer("Idle", 0.3)
				anim.speed_scale = 0.4
			if _t >= 1.6:
				_recharge = 0.5
				_changer(TRAQUE)
		RAGE:
			face = dir
			rot = 1.5
			if _t >= 0.55 and _t - dt < 0.55:
				_cri_rage()
			if _t >= 1.8:
				_recharge = 0.3
				_cd_charge = minf(_cd_charge, 1.0)
				_changer(TRAQUE)
		TITUBE:
			if _t >= _duree_titube:
				_changer(TRAQUE)
		ETOURDI:
			if _t > 0.5 and _anim != "Idle":
				_jouer("Idle", 0.3)
				anim.speed_scale = 0.4
			if combat.etourdi <= 0.0:
				anim.speed_scale = 1.0
				_recharge = 0.6
				_changer(TRAQUE)
	_bouger(dt, mv if mv != Vector3.ZERO else dir, vitesse, loco, face, rot, repos)

## Charge : bloqué net (mur, rocher) = il s'assomme.
func _t_pas_charge(dt: float) -> void:
	var av := Vector2(global_position.x - _pos_prec.x, global_position.z - _pos_prec.z).length()
	_pos_prec = global_position
	if _t > 0.2 and av < VITESSE_CHARGE * dt * 0.3:
		_charge_bloque += dt
	else:
		_charge_bloque = 0.0
	if _charge_bloque > 0.12 and not _charge_touche:
		_changer(SONNE)
		_vit = 0.0
		_recul = -_charge_dir * 2.5
		_jouer("Hit_Head", 0.05, true)
		anim.speed_scale = 0.5
		combat.posture = maxf(0.0, combat.posture - combat.profil.posture_max * 0.4)
		RetourImpact.son(self, "chute_pierre", global_position + _charge_dir + Vector3.UP, 2.0, 0.7)
		Effets.eclats(self, global_position + _charge_dir * 0.9 + Vector3(0, 1.6, 0), Color(0.85, 0.9, 1.0), 20, 3.5)
		_secouer(0.6, 10.0)
		derniere_attaque = "charge_mur"

# ------------------------------------------------------------------ attaques

func _lancer_balayage() -> void:
	derniere_attaque = "balayage"
	_coup_donne = false
	_changer(BALAYAGE)
	_jouer("Troll_Griffes", 0.12, true)
	# l'armement (42 % du clip) est joué à 0,55 : ~1,2 s pour lire le geste et lever la garde
	var arm := _duree("Troll_Griffes") * 0.42
	anim.speed_scale = 0.55 * _rythme()
	_t_impact = arm / (0.55 * _rythme())
	Sons.jouer_a(self, ["giant1", "giant2", "giant3"], global_position + Vector3.UP * 2.0, 0.0, 0.12)
	_eclair(0.25)

func _frapper_balayage() -> void:
	Sons.jouer_a(self, ["swing", "swing2", "swing3"], global_position + Vector3.UP * 1.5, 0.0, 0.1)
	if joueur.get("mort") == true:
		return
	var vj := _vers_joueur()
	var face := global_transform.basis.z
	face.y = 0.0
	if float(vj["dist"]) > PORTEE_BALAYAGE or Vector3(vj["dir"]).dot(face.normalized()) < ANGLE_BALAYAGE:
		return
	var r: String = joueur.recevoir_coup(degats, global_position, {"recul": 7.0, "secousse": 0.75})
	if r == "parade":
		# parade réussie : le troll est déséquilibré (posture −45 %, fenêtre « apres_parade ») ; posture vide = étourdi
		combat.subir_parade()
		if combat.etourdi > 0.0:
			_etourdir()
		else:
			_tituber(-Vector3(vj["dir"]) * 1.0, 1.0)
	elif r == "touche":
		RetourImpact.son(self, "chair", joueur.global_position + Vector3.UP * 1.2, -2.0, 0.85)

func _lancer_ecrase(dir: Vector3) -> void:
	derniere_attaque = "ecrase"
	_coup_donne = false
	rotation.y = atan2(dir.x, dir.z)
	_changer(ECRASE)
	_jouer("Jump_Start", 0.1, true)
	anim.speed_scale = _duree("Jump_Start") / (DUREE_ARMEMENT_ECRASE / _rythme()) * 0.95
	_centre_onde = global_position + dir * AVANCE_ONDE
	_alerte = _disque_sol(_centre_onde, RAYON_ONDE, DUREE_ARMEMENT_ECRASE / _rythme())
	Sons.jouer_a(self, ["giant4", "giant5"], global_position + Vector3.UP * 2.0, 0.0, 0.1)

## Onde de choc du poing au sol : dégâts dans le disque (se pare mal), éclats et pics de glace, tremblement alentour.
func _onde() -> void:
	if is_instance_valid(_alerte):
		_effacer_telegraphe(_alerte, 0.25)
	_pics_glace(_centre_onde, RAYON_ONDE * 0.9, 14, 1.0)
	for k in 6:
		var a := TAU * k / 6.0
		Effets.eclats(self, _centre_onde + Vector3(cos(a), 0.2, sin(a)) * RAYON_ONDE * 0.6, Color(0.7, 0.9, 1.5), 10, 4.5, true)
	Effets.eclats(self, _centre_onde + Vector3(0, 0.2, 0), Color(0.9, 0.93, 1.0), 26, 5.0)
	Sons.jouer_a(self, ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"], _centre_onde, 4.0, 0.1)
	RetourImpact.son(self, "chute_pierre", _centre_onde, 3.0, 0.6)
	_secouer(0.85, 12.0)
	if joueur.get("mort") == true:
		return
	var rel := joueur.global_position - _centre_onde
	var dy := absf(rel.y)
	rel.y = 0.0
	if rel.length() <= RAYON_ONDE + 0.3 and dy < 1.6:
		joueur.recevoir_coup(degats_onde, _centre_onde, {"imparable": 0.6, "recul": 9.0, "ralenti": Vector2(1.2, 0.6), "secousse": 1.0})

func _lancer_charge(dir: Vector3) -> void:
	derniere_attaque = "charge"
	_charge_dir = dir
	_changer(CHARGE_ANNONCE)
	_jouer("Crouch_Idle", 0.15, true)
	anim.speed_scale = 1.6
	_alerte = _bande_sol(global_position, dir, 13.0, 1.9, ANNONCE_CHARGE)
	Sons.jouer_a(self, ["ambiance_rugissement1", "ambiance_rugissement2"], global_position + Vector3.UP * 2.0, 2.0, 0.08)
	_eclair(0.3)

func _lancer_rage() -> void:
	rage = true
	_changer(RAGE)
	_jouer("Crouch_Idle", 0.2, true)
	anim.speed_scale = 0.8
	combat.posture = combat.profil.posture_max
	Sons.jouer_a(self, ["ambiance_rugissement1", "ambiance_rugissement2"], global_position + Vector3.UP * 2.0, 4.0, 0.05)

func _cri_rage() -> void:
	_jouer("Spell_Simple_Shoot", 0.1, true)
	anim.speed_scale = 0.45
	for k in 3:
		Effets.eclats(self, global_position + Vector3(0, 1.4 + k * 0.4, 0), Color(0.65, 0.9, 1.6), 22, 5.0, true)
	Effets.eclats(self, global_position + Vector3(0, 0.3, 0), Color(0.9, 0.93, 1.0), 30, 4.0)
	_secouer(0.6, 14.0)
	_eclair(0.8)

## Tremblement de la caméra du joueur, décroissant avec la distance (portée en m).
func _secouer(force: float, portee: float) -> void:
	if joueur == null or not ("secousse" in joueur):
		return
	var d := joueur.global_position.distance_to(global_position)
	if d < portee:
		joueur.secousse = maxf(float(joueur.secousse), force * (1.0 - d / portee * 0.7))

# ------------------------------------------------------------------ régénération

func _regenerer(dt: float) -> void:
	if vie >= vie_max or _t_sans_coup < REGEN_DELAI or _brule > 0.0:
		return
	var avant := vie
	vie = minf(vie_max, vie + REGEN * dt)
	regeneres += vie - avant
	_t_regen_fx -= dt
	if _t_regen_fx <= 0.0:
		_t_regen_fx = 0.9
		Effets.eclats(self, global_position + Vector3(randf_range(-0.4, 0.4), 1.5, randf_range(-0.4, 0.4)), Color(0.75, 0.95, 1.3), 6, 1.2, true)

# ------------------------------------------------------------------ coups reçus

func _etat_coup() -> Dictionary:
	return {"peut_bloquer": false, "en_attaque": etat in [BALAYAGE, ECRASE, CHARGE], "coup_donne": _coup_donne}

func _apres_degats(r: Dictionary) -> void:
	if String(r["info"].get("type", "")) == "feu":
		_brule = SANS_REGEN_FEU
		Effets.eclats(self, r["info"]["point"], Color(3.0, 1.4, 0.4), 10, 2.0, true)
	if etat in [DORT, GARDE, REVEIL]:
		_changer(TRAQUE)

func _finisher_permis() -> bool:
	return etat not in [DORT, RAGE]

## Mini-boss : pas d'exécution « apres_parade » (une parade suivie d'un coup lourd ne tue pas 420 PV) ; seulement étourdi
## (posture brisée), pris de côté étourdi, ou presque mort (« rapide »).
func finisher_possible(j: Node3D) -> String:
	var c := super(j)
	return "" if c == "apres_parade" else c

func _reagir(r: Dictionary, vers: Vector3) -> void:
	var reaction := String(r["reaction"])
	if reaction == "etourdi" or (combat.etourdi > 0.0 and etat != ETOURDI and etat != RAGE):
		if etat == RAGE:
			return
		_nettoyer_alerte()
		_etourdir()
		return
	if etat in [RAGE, ECRASE, CHARGE, CHARGE_ANNONCE, ETOURDI, SONNE]:
		return   # pouvoir lancé, étourdi ou assommé : seule la flexion procédurale
	var recul := -vers.normalized() / maxf(combat.profil.poids, 0.3)
	match reaction:
		"lourd", "recul":
			_tituber(recul * 3.0, 0.7)
		"moyen":
			if etat != BALAYAGE or r["interrompt"]:
				_tituber(recul * 1.5, 0.45)
		_:
			pass   # hyper-armure : les coups légers ne le font pas tituber

func _tituber(recul: Vector3, duree: float) -> void:
	_nettoyer_alerte()
	_recul = recul
	_duree_titube = duree
	_changer(TITUBE)
	_jouer(["Hit_Chest", "Hit_Head"].pick_random(), 0.05, true)
	anim.speed_scale = clampf(0.45 / duree, 0.45, 1.2)

func _etourdir() -> void:
	_recul = Vector3.ZERO
	_changer(ETOURDI)
	_jouer("Hit_Head", 0.05, true)
	anim.speed_scale = 0.45

func _nettoyer_alerte() -> void:
	if is_instance_valid(_alerte):
		_effacer_telegraphe(_alerte, 0.2)
	_alerte = null

# ------------------------------------------------------------------ mort

func _sur_mort() -> void:
	_nettoyer_alerte()

## Mort lourde : la masse s'écrase (tremblement à l'impact), nuage de neige et de givre, râle grave.
func _special_mort(sorte: String, _r: Dictionary) -> void:
	RetourImpact.son(self, "draugr_mort", global_position + Vector3.UP * 2.0, 3.0, 0.6)
	var moi := self
	get_tree().create_timer(0.75 if sorte != "titubante" else 1.1).timeout.connect(func() -> void:
		if not is_instance_valid(moi) or not moi.is_inside_tree():
			return
		var p := moi.global_position
		var bassin := moi.combat._accroche("pelvis") if moi.combat else null
		if is_instance_valid(bassin):
			p = bassin.global_position
		moi._secouer(1.0, 14.0)
		Effets.eclats(moi, Vector3(p.x, moi.global_position.y + 0.2, p.z), Color(0.9, 0.93, 1.0), 36, 4.0)
		Effets.eclats(moi, Vector3(p.x, moi.global_position.y + 0.4, p.z), Color(0.65, 0.88, 1.4), 16, 3.0, true)
		RetourImpact.son(moi, "chute_pierre", p, 4.0, 0.55)
		Sons.jouer_a(moi, ["impactPunch_heavy_000", "impactPunch_heavy_001"], p, 3.0, 0.05))

func _contenu_butin() -> Dictionary:
	var c := {"pieces": randi_range(25, 45), "fourrure_troll": 1}
	if randf() < 0.6:
		c["croc_troll"] = randi_range(1, 2)
	if randf() < 0.35:
		c["cristal_givre"] = 1
	return c
