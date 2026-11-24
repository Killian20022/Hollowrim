class_name PvpVictime
extends Node
## PvP, côté VICTIME : enfant du joueur LOCAL (créé à la demande par PvpVictime.pour). Quand un autre joueur le saisit (lévitation,
## télékinésie) ou le projette (répulsion, attraction, lancer), le propriétaire perd le contrôle : ce nœud déplace le joueur
## (position autoritaire = point de saisie annoncé par l'attaquant via l'hôte), puis le fait voler en balistique après le relâchement.
##  - saisi : pas de saisie reçue depuis TENUE_MAX s -> il retombe.
##  - vol : gravité, glissement le long des surfaces ; un choc contre un mur ou le sol à plus de VITESSE_CHOC m/s fait des dégâts
##    d'impact limités (jamais mortels : 1 PV minimum, au plus PART_MAX_CHOC de la vie max) ; atterri : bref étourdissement (ralenti).
## Le nœud tourne APRÈS joueur.gd (priorité de traitement) : sa position finale l'emporte, puis le réseau la réplique comme d'habitude.

const TENUE_MAX := 0.6
const RAIDEUR := 6.0
const VITESSE_TENUE := 10.0
const GRAVITE := 13.0
const VITESSE_CHOC := 7.0
const K_CHOC := 1.6
const PART_MAX_CHOC := 0.35
const DUREE_VOL_MAX := 6.0
const VITESSE_MIN_REPOS := 2.5

var joueur: CharacterBody3D
var tenu := false
var en_vol := false
var _t_tenu := 0.0
var _t_vol := 0.0
var _cible := Vector3.ZERO
var _v := Vector3.ZERO
## Journal (tests) : "tenu", "lance", "choc <dégâts>", "atterri".
var journal: Array = []
var degats_impact_total := 0.0

static func pour(j: CharacterBody3D) -> PvpVictime:
	var n := j.get_node_or_null("PvpVictime") as PvpVictime
	if n == null:
		n = PvpVictime.new()
		n.name = "PvpVictime"
		n.joueur = j
		n.process_priority = 50
		n.process_physics_priority = 50
		j.add_child(n)
	return n

func occupe() -> bool:
	return tenu or en_vol

func _prendre_controle() -> void:
	if not occupe():
		joueur.set("en_dialogue", true)

func _rendre_controle() -> void:
	if not joueur.a_terre and not joueur.mort and not PauseCoop.occupe():
		joueur.set("en_dialogue", false)

func tenir(p: Vector3) -> void:
	if joueur.mort or joueur.a_terre:
		return
	if not tenu:
		_prendre_controle()
		_v = Vector3.ZERO
		journal.append("tenu")
		joueur.avis.emit("Un autre joueur vous soulève !")
	tenu = true
	en_vol = false
	_t_tenu = 0.0
	_cible = p

func lancer(v: Vector3) -> void:
	if joueur.mort or joueur.a_terre:
		return
	_prendre_controle()
	tenu = false
	en_vol = true
	_t_vol = 0.0
	_v = v
	if _v.y < 2.0 and v.length() > 3.0:
		_v.y = 2.0   # il décolle (sinon il touche le sol à l'image suivante)
	joueur.velocity = Vector3.ZERO
	journal.append("lance")

func _arreter() -> void:
	tenu = false
	en_vol = false
	_v = Vector3.ZERO
	joueur.velocity = Vector3.ZERO
	_rendre_controle()

## Brûlure (PvP) : `dps` PV/s pendant `duree` s (tics de 0,5 s), jamais mortelle ; une brûlure plus longue remplace la restante.
var _brule_t := 0.0
var _brule_dps := 0.0
var _brule_tic := 0.0

func bruler(duree: float, dps: float) -> void:
	_brule_t = maxf(_brule_t, duree)
	_brule_dps = maxf(_brule_dps, dps)
	journal.append("brule")

func _brulure(dt: float) -> void:
	_brule_t -= dt
	_brule_tic += dt
	if _brule_tic >= 0.5:
		_brule_tic -= 0.5
		var dg := minf(_brule_dps * 0.5, maxf(0.0, float(joueur.vie) - 1.0))
		if dg > 0.0 and not joueur.mort and not joueur.a_terre:
			joueur.vie = float(joueur.vie) - dg
			degats_impact_total += dg
			joueur.touche.emit(dg)
	if _brule_t <= 0.0:
		_brule_dps = 0.0
		_brule_tic = 0.0

func _physics_process(dt: float) -> void:
	if joueur != null and is_instance_valid(joueur) and _brule_t > 0.0:
		_brulure(dt)
	if joueur == null or not is_instance_valid(joueur) or not occupe():
		return
	if joueur.mort or joueur.a_terre:
		_arreter()
		return
	if tenu:
		_t_tenu += dt
		if _t_tenu > TENUE_MAX:
			lancer(Vector3.ZERO)   # plus de nouvelles : il retombe
			return
		var voulue := ((_cible - joueur.global_position) * RAIDEUR).limit_length(VITESSE_TENUE)
		_v = _v.lerp(voulue, 1.0 - exp(-dt * 8.0))
		var col := joueur.move_and_collide(_v * dt)
		if col != null:
			_v = _v.slide(col.get_normal()) * 0.8
		joueur.velocity = _v
		return
	# vol balistique
	_t_vol += dt
	_v.y -= GRAVITE * dt
	var col2 := joueur.move_and_collide(_v * dt)
	var au_sol := false
	if col2 != null:
		var n := col2.get_normal()
		var vn := -_v.dot(n)
		if vn > VITESSE_CHOC and _t_vol > 0.08:
			_choc(vn)
		_v = _v.slide(n) * (0.55 if n.y > 0.7 else 0.4)
		au_sol = n.y > 0.7
		joueur.move_and_collide(col2.get_remainder().slide(n))
	joueur.velocity = _v
	if (au_sol and _t_vol > 0.15 and _v.length() < VITESSE_MIN_REPOS) or _t_vol > DUREE_VOL_MAX:
		journal.append("atterri")
		joueur.ralentir(1.2, 0.5)
		_arreter()

## Choc à `vn` m/s contre une surface : dégâts limités, jamais mortels.
func _choc(vn: float) -> void:
	var dg := (vn - VITESSE_CHOC + 2.0) * K_CHOC
	var vmax := float(joueur.vie_max)
	dg = minf(dg, vmax * PART_MAX_CHOC)
	dg = minf(dg, maxf(0.0, float(joueur.vie) - 1.0))
	if dg <= 0.0:
		return
	joueur.vie = float(joueur.vie) - dg
	joueur.secousse = maxf(joueur.secousse, clampf(vn / 15.0, 0.4, 1.2))
	joueur.touche.emit(dg)
	degats_impact_total += dg
	journal.append("choc %.1f" % dg)
