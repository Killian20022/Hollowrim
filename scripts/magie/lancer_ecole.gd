class_name LancerEcole
extends Node3D
## LANCER des écoles runiques (glace, électricité, ténèbres) : le sort lancé NAÎT de l'énergie tenue au repos (mêmes couleurs,
## mêmes cristaux / arcs / fumée, mêmes runes) au lieu d'apparaître d'un coup. Classe de base (socle commun) : puffs en monde
## (nuages de NoyauEcole.Bouffees), cycle de vie, API de pilotage. Sous-classes : LancerGlace, LancerElec, LancerTenebres.
##
## API (à brancher depuis l'enchaînement repos → lancer → fin ; voir docs/MAGIE_LANCER_ECOLES.md) :
##   LancerEcole.projectile(ecole, forme)      nœud à donner à ProjectileSort.tirer_sort (le projectile le pilote : voir plus bas)
##   LancerEcole.creer(ecole, forme)           nœud autonome (outils, jets) ; puis demarrer / maintenir / terminer
##   demarrer(progression)                     le sort naît de la main (progression 0..1 : charge atteinte → taille de l'effet)
##   maintenir(tete, direction)                chaque image tant que le sort vit (point de la tête, sens du déplacement)
##   terminer(point)                           fin : l'effet se défait (traînée qui s'efface, givre qui se reforme) puis se libère seul
##   reformer(main, centre)  [statique, par école]  le repos se reforme dans la main (fin du lancer)
##   LancerEcole.combiner(main_g, main_d, point_fusion, intensite)  double magie, même sort dans les deux mains : deux flux
##                                              qui convergent vers `point_fusion` et fusionnent en UN seul, plus large
##   LancerEcole.depart(ecole, main, direction, k)  « geste de départ » seul (jets, chaînes, orages : pas de projectile)
## Rendu : calque de la couche fine (CoucheMagie.CALQUE) comme les noyaux d'école ; gros pixels (paliers francs des shaders
## magie_bouffee / magie_cristal) ; aucun effet sur l'eau.

enum Phase { REPOS, NAISSANCE, VOL, FIN }

const SH_BOUFFEE := preload("res://shaders/magie_bouffee.gdshader")
## Durée (s) de la naissance : la tête reste liée à la main (les puffs de la main s'y rassemblent) pendant ce temps.
const DUREE_NAISSANCE := 0.26
const PAS_SEMIS := 0.11        # m entre deux puffs semés le long du trajet (aucun trou à 34 m/s)
const MAX_SEMIS := 8           # puffs semés par image au plus

var ecole := "glace"
var forme := "eclat"
var phase: int = Phase.REPOS
var intensite := 1.0
var double := false
## Paumes d'origine (1 ou 2) : nœuds suivis ; point de fusion de la double magie (monde) ou Vector3.INF.
var mains: Array[Node3D] = []
var fusion := Vector3.INF
var tete := Vector3.ZERO
var dir := Vector3.FORWARD
var origine := Vector3.ZERO
var t := 0.0
var t_fin := 0.0
var duree_fin := 0.9
## Suit le nœud parent (un projectile) : la tête est sa position.
var suit_parent := false
## Geste (sans projectile) : tête immobile (rayon : au centre du cercle) et durée avant la fin (s).
var fixe := false
var duree_geste := DUREE_NAISSANCE + 0.05
var _prec := Vector3.INF
var _graine := 0.0
var _mix: NoyauEcole.Bouffees
var _add: NoyauEcole.Bouffees
var _p: Array = []             # puffs en monde (voir _semer)
var _runes: RunesOrbite
var _libre := false
var _debut_fait := false

## Nœud prêt à l'emploi pour une école (null si l'école n'a pas de lancer propre : feu, soin, protection).
static func creer(ecole_: String, forme_ := "") -> LancerEcole:
	var n: LancerEcole = null
	match ecole_:
		"glace":
			n = LancerGlace.new()
		"electricite":
			n = LancerElec.new()
		"tenebres":
			n = LancerTenebres.new()
		_:
			return null
	n.ecole = ecole_
	n.forme = forme_
	n.name = "Lancer" + ecole_.capitalize()
	return n

## Le visuel d'un PROJECTILE de sort (remplace GestionMagie.projectile_visuel pour ces écoles). Pilotage automatique par
## ProjectileSort (`demarrer` au tir, `maintenir` à chaque image, `terminer` à l'impact). Détecte seul la double magie.
static func projectile(ecole_: String, forme_: String) -> Node3D:
	var n := creer(ecole_, forme_)
	if n == null:
		return null
	n.suit_parent = true
	var g := GestionMagie.obtenir()
	n.double = g != null and bool(g._double.get(ecole_, false))
	return n

## Double magie : même sort dans les deux mains. Deux flux partent des paumes, convergent vers `point_fusion` et fusionnent en
## un seul, plus large (un seul anneau de runes commun). `intensite` ~1 (0,5 à 1,5). Renvoie le nœud (déjà démarré, ajouté à
## la scène courante) : la tête fusionnée suit `maintenir(tete, dir)` comme un sort simple, ou reste au point de fusion.
static func combiner(main_g: Node3D, main_d: Node3D, point_fusion: Vector3, intensite_ := 1.0, ecole_ := "glace", forme_ := "eclat") -> LancerEcole:
	var n := creer(ecole_, forme_)
	if n == null:
		return null
	n.double = true
	n.mains = [main_g, main_d]
	n.fusion = point_fusion
	_scene().add_child(n)
	n.global_position = point_fusion
	n.tete = point_fusion
	n.demarrer(intensite_)
	return n

## « Geste de départ » d'un sort sans projectile (souffle de givre, arc, chaîne, orage, drain, rayon) : la tête fictive part de
## la main dans `direction` à 7 m/s pendant la naissance puis s'éteint ; la main et ce qui la tient se rassemblent dedans.
static func depart(ecole_: String, main: Node3D, direction: Vector3, k := 1.0) -> LancerEcole:
	if ecole_ == "electricite" and main != null and is_instance_valid(main):
		var l := mains_de(ecole_, main.global_position)
		return LancerElec.tension(main, main.global_position + direction.normalized() * 4.0, k, 0.45, l[1] if l.size() > 1 and l[0] == main else null)
	var n := creer(ecole_, "geste")
	if n == null or main == null or not is_instance_valid(main):
		return null
	n.mains = [main]
	n.double = false
	_scene().add_child(n)
	n.global_position = main.global_position
	n.tete = main.global_position
	n.dir = direction.normalized()
	n.demarrer(k)
	n.set_meta("geste", true)
	return n

static func _scene() -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.current_scene if arbre.current_scene != null else arbre.root

## Les paumes qui tiennent un sort de cette école, les plus proches de `pos` d'abord (lecture de GestionMagie._auras).
static func mains_de(ecole_: String, pos: Vector3, rayon := 0.7) -> Array[Node3D]:
	var res: Array[Node3D] = []
	var g := GestionMagie.obtenir()
	if g == null:
		return res
	var l: Array = []
	for a: Dictionary in g._auras.values():
		if a.ecole == ecole_ and g.valide(a.main):
			var d := (a.main as Node3D).global_position.distance_to(pos)
			if d <= rayon:
				l.append([d, a.main])
	l.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e in l:
		res.append(e[1])
	return res

# ---------------------------------------------------------------- cycle de vie

func _ready() -> void:
	top_level = true
	_graine = randf() * 10.0
	_construire()

## À surcharger : crée les maillages et nuages de l'école.
func _construire() -> void:
	pass

## À surcharger : chaque image (dt, base de la caméra).
func _maj(_dt: float, _cb: Basis) -> void:
	pass

## À surcharger : au départ (puffs de la main qui se rassemblent, éclat de naissance).
func _naissance() -> void:
	pass

## À surcharger : à la fin.
func _fin() -> void:
	pass

func demarrer(progression := 1.0) -> void:
	intensite = clampf(progression, 0.3, 1.6)
	phase = Phase.NAISSANCE
	t = 0.0
	_debut_fait = true
	if suit_parent and get_parent() is Node3D:
		tete = (get_parent() as Node3D).global_position
		if get_parent() is Projectile:
			var v: Vector3 = (get_parent() as Projectile).vitesse
			if v.length() > 0.01:
				dir = v.normalized()
	elif tete == Vector3.ZERO:
		tete = global_position
	origine = tete
	if mains.is_empty():
		var l := mains_de(ecole, tete)
		if not l.is_empty():
			mains.append(l[0])
			if double and l.size() > 1:
				mains.append(l[1])
	if double and mains.size() > 1 and fusion == Vector3.INF:
		fusion = tete
	_naissance()
	if suit_parent and not mains.is_empty() and is_inside_tree():
		# BRANCHEMENT PROVISOIRE (fin du lancer) : 0,4 s après le départ, le repos se reforme dans la main (à remplacer par la récupération de MainSort)
		get_tree().create_timer(0.4).timeout.connect(_reformer_mains.bind(mains.duplicate()))

func _reformer_mains(l: Array) -> void:
	for m in l:
		if is_instance_valid(m) and (m as Node).is_inside_tree():
			match ecole:
				"glace":
					LancerGlace.reformer(m)
				"electricite":
					LancerElec.reformer(m)
				"tenebres":
					LancerTenebres.reformer(m)

func maintenir(tete_: Vector3, direction: Vector3) -> void:
	tete = tete_
	if direction.length() > 0.001:
		dir = direction.normalized()
	if phase == Phase.REPOS:
		demarrer(intensite)
	global_position = tete

func terminer(_point := Vector3.INF) -> void:
	if phase == Phase.FIN:
		return
	phase = Phase.FIN
	t_fin = 0.0
	# le projectile va être libéré : on passe dans la scène pour que la traînée s'efface d'elle-même
	suit_parent = false
	var p := get_parent()
	if p != null and p != _scene():
		var xf := global_transform
		p.remove_child(self)
		_scene().add_child(self)
		global_transform = xf
	_fin()

## Libère le nœud et ses nuages tout de suite (changement de scène, tests).
func arreter() -> void:
	_libre = true
	queue_free()

func _exit_tree() -> void:
	if _runes != null and is_instance_valid(_runes) and not _runes.is_queued_for_deletion():
		_runes.queue_free()

func _process(dt: float) -> void:
	if phase == Phase.REPOS and not _debut_fait:
		return
	dt = minf(dt, 0.05)
	t += dt
	if phase == Phase.FIN:
		t_fin += dt
	else:
		if suit_parent and get_parent() is Node3D:
			tete = (get_parent() as Node3D).global_position
		if get_meta("geste", false):
			if not fixe:
				tete += dir * 7.0 * dt * (1.0 - smoothstep(0.1, DUREE_NAISSANCE, t))
			if t > duree_geste:
				terminer(tete)
		global_position = tete
		if _prec != Vector3.INF and tete.distance_to(_prec) > 0.003 and suit_parent:
			dir = dir.lerp((tete - _prec).normalized(), 0.8).normalized()
		if phase == Phase.NAISSANCE and t >= DUREE_NAISSANCE:
			phase = Phase.VOL
	var cam := get_viewport().get_camera_3d()
	var cb := cam.global_basis if cam != null else Basis.IDENTITY
	_maj(dt, cb)
	_prec = tete
	var g := GestionMagie.obtenir()
	if g != null and g.couche != null:
		g.couche.demander()
	if phase == Phase.FIN and t_fin >= duree_fin and _p.is_empty():
		queue_free()

# ---------------------------------------------------------------- aides

func intensite_k() -> float:
	return lerpf(0.85, 1.15, clampf(intensite, 0.0, 1.5) / 1.5)

## Progression 0..1 de la naissance (lissée).
func naiss() -> float:
	return smoothstep(0.0, DUREE_NAISSANCE, t)

static func h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Base dont l'axe Y est `d` (cristaux : pointe vers +Y).
static func base_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

## Deux vecteurs perpendiculaires à `d`.
static func perp(d: Vector3) -> Array[Vector3]:
	var u := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	return [u, d.cross(u).normalized()]

func nuage(n: int, mat: ShaderMaterial) -> NoyauEcole.Bouffees:
	var b := NoyauEcole.Bouffees.new(n, mat)
	b.mi.top_level = true
	b.mi.custom_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	add_child(b.mi)
	return b

static func mat_bouffee(mode: int, pal: Array, dechire := 0.75, eclat := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_BOUFFEE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("dechire", dechire)
	m.set_shader_parameter("eclat", eclat)
	for k in 4:
		m.set_shader_parameter(["c_a", "c_b", "c_c", "c_d"][k], Color(pal[k]))
	m.render_priority = mode
	return m

## Runes de l'école qui accompagnent la tête (même RunesOrbite que la main, sans noyau).
func runes_tete(echelle: float, germe := 0.2) -> void:
	_runes = RunesOrbite.new()
	_runes.name = "RunesLancer"
	_runes.ecole = ecole
	_runes.suivi = self
	_runes.centre_force = 0.0
	_runes.avec_lueurs = false
	_runes.echelle = echelle
	_runes.germe = germe
	_runes.intensite = 1.0
	_runes.etat = 3
	_runes.double = double
	_scene().add_child(_runes)

## Un puff (nuage, filament, cœur, braise) :
##   pos, vel (m/s), grav (m/s²), freine (1/s), vie (s), s0/s1 (taille début/fin, m), a (opacité max), ton (0 sombre … 1 clair),
##   sorte (0 nuage, 1 filament, 2 cœur, 3 braise ; 0-1 en mélange alpha, 2-3 en additif), long (filament : longueur m),
##   suit : durée (s) pendant laquelle il est attiré vers la tête (ou `vers`), puis libéré avec `vel2`.
func semer(d: Dictionary) -> void:
	var e := {"pos": Vector3.ZERO, "vel": Vector3.ZERO, "grav": 0.0, "freine": 1.0, "vie": 0.8, "s0": 0.05, "s1": 0.1, "a": 0.5,
		"ton": 0.5, "sorte": 0, "long": 0.2, "suit": 0.0, "vers": Vector3.INF, "vel2": Vector3.ZERO, "age": 0.0, "h": randf(), "delai": 0.0}
	e.merge(d, true)
	if _p.size() < 420:
		_p.append(e)

## Avance et dessine les puffs (tous : mélange alpha dans `_mix`, additifs dans `_add`).
func puffs(dt: float, cb: Basis, amorti_al := 1.0) -> void:
	var lot_m: Array = []
	var lot_a: Array = []
	var i := _p.size() - 1
	while i >= 0:
		var e: Dictionary = _p[i]
		if float(e.delai) > 0.0:
			e.delai = float(e.delai) - dt
			i -= 1
			continue
		e.age = float(e.age) + dt
		var age: float = e.age
		if age >= float(e.vie):
			_p.remove_at(i)
			i -= 1
			continue
		var pos: Vector3 = e.pos
		var vel: Vector3 = e.vel
		if age < float(e.suit):
			var vers: Vector3 = tete if (e.vers as Vector3) == Vector3.INF else e.vers
			var k := 1.0 - exp(-dt * (5.0 + 14.0 * age / maxf(float(e.suit), 0.01)))
			pos = pos.lerp(vers, k)
			vel = vel.lerp(Vector3.ZERO, 0.5)
		else:
			if float(e.suit) > 0.0 and age - dt < float(e.suit):
				vel = e.vel2
			vel *= exp(-dt * float(e.freine))
			vel.y -= float(e.grav) * dt
			pos += vel * dt
		e.pos = pos
		e.vel = vel
		var p := age / float(e.vie)
		var sorte: int = e.sorte
		var s := lerpf(float(e.s0), float(e.s1), p)
		var al := float(e.a) * smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.55, 1.0, p)) * amorti_al
		var hh: float = e.h
		match sorte:
			1:
				var v := vel if vel.length() > 0.05 else dir
				var ang := atan2(v.dot(cb.y), v.dot(cb.x))
				var lg := float(e.long) * (1.0 - 0.5 * p)
				lot_m.append([pos, NoyauEcole._bb(cb, ang, lg, lg * 0.11), Color(1, 1, 1, al), Color(hh, float(e.ton), 1.0, 0.0)])
			2:
				lot_a.append([pos, NoyauEcole._bb(cb, 0.0, s, s), Color(1, 1, 1, al), Color(hh, 1.0, 2.0, 0.0)])
			3:
				lot_a.append([pos, NoyauEcole._bb(cb, 0.0, s, s), Color(1, 1, 1, al), Color(hh, float(e.ton), 3.0, 0.0)])
			_:
				lot_m.append([pos, NoyauEcole._bb(cb, hh * TAU, s, s * 0.85), Color(1, 1, 1, al), Color(hh, lerpf(float(e.ton), float(e.ton) * 0.6, p), 0.0, 0.0)])
		i -= 1
	if _mix != null:
		_mix.ecrire(lot_m, cb)
	if _add != null:
		_add.ecrire(lot_a, cb, false)

## Positions semées entre l'image précédente et celle-ci (pas de trou à grande vitesse) : appelle `f(pos)` pour chacune.
func le_long(f: Callable, pas := PAS_SEMIS) -> void:
	if _prec == Vector3.INF:
		f.call(tete)
		return
	var d := tete.distance_to(_prec)
	var n := clampi(int(d / pas), 0, MAX_SEMIS)
	if n == 0:
		if d > 0.0 and randf() < d / pas:
			f.call(tete)
		return
	for k in n:
		f.call(_prec.lerp(tete, float(k + 1) / n))

## Lumière de la tête (pool de GestionMagie).
func lumiere(couleur: Color, energie: float, portee := 5.0) -> void:
	var g := GestionMagie.obtenir()
	if g != null:
		g.lumiere("lancer%d" % get_instance_id(), tete, couleur, energie, portee, 3.0)

## Position d'une paume (monde), ou `repli` si elle a disparu.
func pos_main(i: int, repli: Vector3) -> Vector3:
	if i < mains.size() and is_instance_valid(mains[i]) and mains[i].is_inside_tree():
		return mains[i].global_position
	return repli
