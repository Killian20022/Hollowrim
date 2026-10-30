class_name TraceLame
extends RefCounted
## Détection des coups par TRACÉ DE LAME : pendant la phase active, la lame est échantillonnée à pas de temps FIXE
## (PAS, indépendant des images par seconde) ; entre deux échantillons successifs, un rayon relie les positions de
## chaque point de la lame (garde → pointe prolongée de l'allonge). La zone de dégâts est donc le vrai mouvement de
## l'épée. Règles :
##   - une seule touche par cible et par coup (touches) ; au plus `max_cibles` cibles par coup ;
##   - le décor n'arrête la lame (événement « mur », rebond) que s'il est frappé FRANCHEMENT (comportement « Skyrim », retour
##     du 2026-10-29 soir « parfois je ne peux pas donner de coup d'épée dans un endroit pas si restreint ») : une grande
##     surface verticale (mur, porte, pas un petit objet), tournée vers le joueur, DANS L'AXE de la vue, à portée de la vraie
##     lame, à MI-COURSE de la frappe (jamais au départ). Sinon la lame passe : un mur de côté (couloir, chambranle) ou le sol
##     masquent seulement ce qui est derrière eux (jamais de touche à travers un mur) ; un petit objet de décor (urne fusionnée
##     au décor, caisse basse, banc) est traversé (la lame passe au-dessus / à travers) ;
##   - un « cassable » (urne, tonneau, caisse : calque 64) est brisé au passage et la lame CONTINUE (une fois par coup).
##   Ancien comportement (permissif = false) : le premier contact avec le décor arrêtait la lame — au départ d'un revers près
##   du mur d'un couloir, sur le sol, sur une urne, sur un chambranle.
## Cibles reconnues : nœud (ou ancêtre du collider) du groupe « ennemis » ou qui a recevoir_coup(), groupe « cassables ».

## Pas d'échantillonnage du tracé (s de temps de jeu) : 240 échantillons par seconde quel que soit le rendu.
const PAS := 1.0 / 240.0
## Calque physique du décor et des corps (joueur, ennemis, murs) ; les ragdolls (calque 16) ne bloquent pas la lame.
const MASQUE := 1 | Cassable.CALQUE      # décor + objets cassables (urnes, tonneaux : calque propre, franchissables)
## Normale (composante verticale) au-delà de laquelle une surface est un sol : la lame s'y arrête sans rebondir.
const SOL_NORMALE := 0.6

## --- Décor permissif (« Skyrim ») -------------------------------------------------------------------------------------
## Faux : ancien comportement (tout contact avec le décor arrête la lame) — comparaisons, tests d'avant.
static var permissif := true
## Part de la frappe (0 début, 1 fin de la phase active) où un mur franc peut faire rebondir la lame : jamais au départ.
const COURSE_MUR := Vector2(0.3, 0.85)
## Cône autour de l'axe de la vue (°) : le mur doit être frappé « dans l'axe », pas sur le côté de l'écran.
const CONE_MUR := 24.0
## Le mur doit faire face au joueur : normale · (−axe à plat) au-delà de ce seuil (≈ 50°).
const FACE_MUR := 0.64
## Distance (m, depuis l'œil) au-delà de laquelle la vraie lame ne touche pas le mur (les rayons, eux, vont jusqu'à la portée).
const PORTEE_MUR := 1.5
## Sondes de largeur (m) : une surface est « grande » (mur, porte) si au moins 3 des 4 sondes décalées de SONDE (gauche,
## droite, haut, bas) retrouvent le même plan ; sinon c'est un petit objet de décor (traversé).
const SONDE := 0.3
const SONDES_MIN := 3
## Direction du regard (monde) et part de la frappe : posées par mains.gd avant chaque échantillon.
var axe := Vector3.ZERO
var progression := 0.5
## Contacts de décor ignorés pendant ce coup (mesures, débogage) : surfaces masquantes et petits objets traversés.
var frolements := 0
var traverses := 0
var _q_sonde := PhysicsRayQueryParameters3D.new()
var _exclus_cass: Array[RID] = []

var touches := {}
var nb_cibles := 0
var arretee := false
var rayons := 0
## Segments parcourus (débogage) : paires de points monde, et points d'impact.
var debug_segments: Array = []
var debug_impacts: Array = []
var garder_debug := false
var _prec := PackedVector3Array()

func commencer() -> void:
	touches.clear()
	nb_cibles = 0
	arretee = false
	rayons = 0
	echantillons = 0
	requetes = 0
	vitesse = 0.0
	_prec = PackedVector3Array()
	frolements = 0
	traverses = 0
	_exclus_cass.clear()
	debug_segments.clear()
	debug_impacts.clear()

## Nœud qui reçoit le coup pour un collider touché, ou null (décor).
static func cible_de(objet: Object) -> Node:
	var n := objet as Node
	while n != null:
		if n.is_in_group("ennemis") or n.is_in_group("cassables") or n.is_in_group("cibles_combat"):
			return n
		n = n.get_parent()
	return null

## Résolution angulaire du balayage (rad, vue de l'œil) : écart maximal entre deux rayons voisins, le long de la lame comme
## entre deux instants. 2,5° = 4 cm à 1 m, 8,7 cm à 2 m : un poteau, une hampe ou un bras ne passent plus entre deux rayons
## (à 240 échantillons/s, la pointe d'un coup rapide balaie jusqu'à 30° d'un échantillon à l'autre : sans sous-pas, une
## cible à 1 m pouvait traverser l'arc sans être touchée). Modifiable (navigateur : 3,5° divise les rayons par ~2).
static var resolution := deg_to_rad(2.0)
## Plafonds des subdivisions (par échantillon : sous-instants ; par segment de lame : rayons intermédiaires).
static var sous_pas_max := 20
static var sous_lame_max := 10
## Pré-test par volume (pyramide) avant les sous-instants : faux = rayons denses partout (mesures, débogage).
static var pre_test_volume := true
## Vitesse angulaire minimale de la lame (°/s, pointe vue de l'œil, caméra comprise) pour BLESSER : une lame immobile ou
## presque (début de fenêtre, coup bloqué contre une cible) ne coupe pas ; les murs l'arrêtent toujours.
const VITESSE_MIN := 60.0

## Vitesse angulaire de la pointe au dernier échantillon (°/s) ; échantillons et rayons lancés (débogage, perf).
var vitesse := 0.0
var echantillons := 0
var requetes := 0
var _prec_oeil := Vector3.ZERO
var _volume := ConvexPolygonShape3D.new()
var _requete_volume := PhysicsShapeQueryParameters3D.new()
var _q := PhysicsRayQueryParameters3D.new()

## Un échantillon de la lame (points monde, garde → bout). Renvoie les événements :
## {type: "cible" | "mur" | "sol" | "cassable", point, normale, objet, collider, direction (mouvement de la lame), indice}.
## `radial` (coups en espace écran, mains._points_jeu) : nappe de rayons depuis l'œil entre l'échantillon précédent et
## celui-ci (_balayer : subdivisée à `resolution` le long de la lame et dans le temps) — le premier obstacle sur la ligne de
## visée est touché : un mur devant la cible l'arrête toujours. Sans `radial` : rayons latéraux entre deux échantillons.
func echantillonner(espace: PhysicsDirectSpaceState3D, points: PackedVector3Array, oeil: Vector3, exclus: Array[RID], max_cibles: int, radial := false) -> Array:
	var evts := []
	if arretee:
		return evts
	if radial:
		evts = _balayer(espace, points, oeil, exclus, max_cibles)
		if garder_debug:
			for e in evts:
				debug_impacts.append(e["point"])
		_prec = points
		_prec_oeil = oeil
		return evts
	if _prec.size() != points.size():
		_prec = points
		return evts
	for i in points.size():
		var a := _prec[i]
		var b := points[i]
		if garder_debug:
			debug_segments.append([a, b])
		if a.distance_squared_to(b) < 1e-10:
			continue
		var q := PhysicsRayQueryParameters3D.create(a, b, MASQUE, exclus)
		q.hit_from_inside = true
		var r := espace.intersect_ray(q)
		rayons += 1
		if r.is_empty():
			continue
		var cible := cible_de(r["collider"])
		var point: Vector3 = r["position"]
		var mouvement := (b - a).normalized()
		if cible == null or cible.is_in_group("cassables"):
			# sol (surface tournée vers le haut) : la lame s'y arrête sans rebond ; mur / décor : rebond
			var type := "cassable" if cible != null else ("sol" if (r["normal"] as Vector3).y > SOL_NORMALE else "mur")
			evts.append({"type": type, "point": point, "normale": r["normal"], "objet": cible if cible else r["collider"], "collider": r["collider"], "direction": mouvement, "indice": i})
			arretee = true
			break
		var id := cible.get_instance_id()
		if touches.has(id) or nb_cibles >= max_cibles:
			continue
		if cible.has_method("vivant") and not cible.vivant():
			continue
		# cible derrière le décor (lame passée de l'autre côté d'un mur contre lequel on se tient) : c'est le mur qui est touché
		var ex2: Array[RID] = exclus.duplicate()
		ex2.append(r["rid"])
		var q2 := PhysicsRayQueryParameters3D.create(oeil, point, MASQUE, ex2)
		var r2 := espace.intersect_ray(q2)
		rayons += 1
		if not r2.is_empty() and cible_de(r2["collider"]) == null:
			evts.append({"type": "mur", "point": r2["position"], "normale": r2["normal"], "objet": r2["collider"], "collider": r2["collider"], "direction": mouvement, "indice": i})
			arretee = true
			break
		touches[id] = true
		nb_cibles += 1
		evts.append({"type": "cible", "point": point, "normale": r["normal"], "objet": cible, "collider": r["collider"], "direction": mouvement, "indice": i})
	if garder_debug:
		for e in evts:
			debug_impacts.append(e["point"])
	_prec = points
	_prec_oeil = oeil
	return evts

## Balayage RADIAL (coups en espace écran) : la lame vue de l'œil, projetée à la portée, balaie une nappe de rayons entre
## l'échantillon précédent et celui-ci. Les rayons partent de l'œil (le premier obstacle sur la ligne de visée est touché :
## jamais à travers un mur). Chaque segment de lame (entre deux des 7 points) balaie une pyramide (œil → segment précédent
## → segment actuel) : si elle contient une CIBLE (pré-test par volume, intersect_shape), la nappe de ce segment est
## subdivisée dans le temps et le long de la lame (deux rayons voisins à moins de `resolution`) ; sinon seuls les rayons
## des points de la lame à l'instant de l'échantillon sont lancés (le décor, large, ne passe pas entre eux). Un coup dans le
## vide coûte ~7 rayons et 6 requêtes de volume par échantillon. Sous-instants parcourus dans l'ordre du temps : le premier
## contact (mur ou cible) l'emporte.
func _balayer(espace: PhysicsDirectSpaceState3D, points: PackedVector3Array, oeil: Vector3, exclus: Array[RID], max_cibles: int) -> Array:
	var evts := []
	var n := points.size()
	var prec_ok := _prec.size() == n and n >= 2
	echantillons += 1
	_q.collision_mask = MASQUE
	var ex: Array[RID] = exclus.duplicate()
	if permissif:
		ex.append_array(_exclus_cass)
	_q.exclude = ex
	# vitesse de la pointe (caméra comprise : une lame tenue immobile pendant qu'on pivote balaie bien le monde)
	vitesse = rad_to_deg((_prec[n - 1] - _prec_oeil).angle_to(points[n - 1] - oeil)) / PAS if prec_ok else INF
	var blesse := vitesse >= VITESSE_MIN
	var nt := 1
	if prec_ok:
		var amax := 0.0
		for i in n:
			amax = maxf(amax, (_prec[i] - _prec_oeil).angle_to(points[i] - oeil))
		nt = clampi(ceili(amax / resolution - 1e-6), 1, sous_pas_max)
	var denses := []
	for jseg in n - 1:
		var sommets := [_prec_oeil, oeil, _prec[jseg], _prec[jseg + 1], points[jseg], points[jseg + 1]] if prec_ok else [oeil, oeil, points[jseg], points[jseg + 1], points[jseg], points[jseg + 1]]
		# plus aucune cible possible (plafond atteint) : la nappe fine ne sert plus, seuls les murs arrêtent encore la lame
		denses.append(nb_cibles < max_cibles and (not pre_test_volume or _volume_cible(espace, sommets, exclus)))
	for sp in range(1, nt + 1):
		var f := float(sp) / float(nt)
		var o := _prec_oeil.lerp(oeil, f) if prec_ok else oeil
		var ligne := PackedVector3Array()
		for i in n:
			ligne.append(_prec[i].lerp(points[i], f) if prec_ok else points[i])
		for jseg in n - 1:
			var dense: bool = denses[jseg]
			if sp < nt and not dense:
				continue
			var nb := clampi(ceili((ligne[jseg] - o).angle_to(ligne[jseg + 1] - o) / resolution - 1e-6), 1, sous_lame_max) if dense else 1
			for bb in range(0 if jseg == 0 else 1, nb + 1):
				var u := float(bb) / float(nb)
				var p := ligne[jseg].lerp(ligne[jseg + 1], u)
				var mvt := (p - _prec[jseg].lerp(_prec[jseg + 1], u)).normalized() if prec_ok else Vector3.ZERO
				var e := _rayon(espace, o, p, max_cibles, blesse, mvt, jseg, sp < nt or bb not in [0, nb])
				if not e.is_empty():
					evts.append(e)
				if arretee:
					return evts
	return evts

## Un rayon œil → point de la nappe. Renvoie l'événement (cible nouvelle, mur, sol, cassable) ou {}.
func _rayon(espace: PhysicsDirectSpaceState3D, o: Vector3, p: Vector3, max_cibles: int, blesse: bool, mouvement: Vector3, indice: int, sous_pas: bool) -> Dictionary:
	_q.from = o
	_q.to = p
	var r := espace.intersect_ray(_q)
	rayons += 1
	if garder_debug:
		debug_segments.append([o, r["position"] if not r.is_empty() else p, 1 if sous_pas else 0])
	if r.is_empty():
		return {}
	if mouvement == Vector3.ZERO or not mouvement.is_finite():
		mouvement = (p - o).normalized()
	var cible := cible_de(r["collider"])
	if permissif:
		# décor : rebond seulement sur un mur franc ; un petit objet est traversé (le rayon repart derrière lui, 3 fois au
		# plus) ; une grande surface non franche (mur de côté, sol, chambranle) masque ce qui est derrière, sans arrêter
		var passes := 0
		while cible == null:
			var large := _surface_large(espace, o, r)
			if large and _mur_franc(o, r):
				arretee = true
				return {"type": "mur", "point": r["position"], "normale": r["normal"], "objet": r["collider"], "collider": r["collider"], "direction": mouvement, "indice": indice}
			# traversé seulement si c'est vraiment un PETIT objet (rien autour du point) : une arête de mur, un angle, un mur vu
			# par la tranche masquent (sinon le rayon repartirait de l'intérieur du mur et toucherait derrière)
			if large or passes >= 3 or not _petit_objet(espace, o, r):
				frolements += 1
				return {}
			traverses += 1
			passes += 1
			var d := (p - o).normalized()
			var dep: Vector3 = r["position"] + d * 0.02
			if (p - o).length() <= (dep - o).length():
				return {}
			_q.from = dep
			r = espace.intersect_ray(_q)
			rayons += 1
			_q.from = o
			if r.is_empty():
				return {}
			cible = cible_de(r["collider"])
		if cible.is_in_group("cassables"):
			# brisé au passage, la lame continue (exclu des rayons suivants de ce coup)
			_exclus_cass.append(r["rid"])
			var ex: Array[RID] = _q.exclude
			ex.append(r["rid"])
			_q.exclude = ex
			return {"type": "cassable", "point": r["position"], "normale": r["normal"], "objet": cible, "collider": r["collider"], "direction": mouvement, "indice": indice}
	if cible == null or cible.is_in_group("cassables"):
		var type := "cassable" if cible != null else ("sol" if (r["normal"] as Vector3).y > SOL_NORMALE else "mur")
		arretee = true
		return {"type": type, "point": r["position"], "normale": r["normal"], "objet": cible if cible else r["collider"], "collider": r["collider"], "direction": mouvement, "indice": indice}
	var id := cible.get_instance_id()
	if not blesse or touches.has(id) or nb_cibles >= max_cibles:
		return {}
	if cible.has_method("vivant") and not cible.vivant():
		return {}
	touches[id] = true
	nb_cibles += 1
	return {"type": "cible", "point": r["position"], "normale": r["normal"], "objet": cible, "collider": r["collider"], "direction": mouvement, "indice": indice}

## Le volume balayé par un segment de lame entre deux échantillons (pyramide de l'œil) contient-il une cible (groupe ennemis /
## cibles_combat, hors cassables) PAS ENCORE TOUCHÉE par ce coup ? Pyramide presque plate (lame vue dans son axe, premier échantillon) : vrai (on lance
## les rayons, pas de volume fiable).
func _volume_cible(espace: PhysicsDirectSpaceState3D, sommets: Array, exclus: Array[RID]) -> bool:
	var o: Vector3 = sommets[1]
	var v1: Vector3 = sommets[2] - o
	var v2: Vector3 = sommets[3] - o
	var v3: Vector3 = sommets[4] - o
	var v4: Vector3 = sommets[5] - o
	if maxf(absf(v1.cross(v2).dot(v3)), absf(v2.cross(v4).dot(v3))) < 1e-5:
		return true
	_volume.points = PackedVector3Array(sommets)
	_requete_volume.shape = _volume
	_requete_volume.transform = Transform3D()
	_requete_volume.collision_mask = MASQUE
	_requete_volume.exclude = exclus
	requetes += 1
	for h in espace.intersect_shape(_requete_volume, 8):
		var c := cible_de(h["collider"])
		if c != null and not c.is_in_group("cassables") and not touches.has(c.get_instance_id()):
			return true   # cible pas encore touchée par ce coup
	return false

## Mur FRANC (rebond) : grande surface verticale tournée vers le joueur, dans l'axe de la vue, à portée de la vraie lame, à
## mi-course de la frappe. `r` : résultat du rayon (position, normale).
func _mur_franc(o: Vector3, r: Dictionary) -> bool:
	if axe == Vector3.ZERO or progression < COURSE_MUR.x or progression > COURSE_MUR.y:
		return false
	var n: Vector3 = r["normal"]
	if absf(n.y) > 0.5:
		return false   # sol, voûte : jamais de rebond
	var vers: Vector3 = r["position"] - o
	if vers.length() > PORTEE_MUR or rad_to_deg(vers.angle_to(axe)) > CONE_MUR:
		return false
	var plat := Vector3(axe.x, 0.0, axe.z)
	if plat.length_squared() < 1e-6:
		return false
	return n.dot(-plat.normalized()) >= FACE_MUR

## Grande surface (mur, porte, sol) ou petit objet de décor ? Sondes parallèles au rayon, décalées de SONDE à gauche, à droite,
## en haut et en bas du point touché : une grande surface est retrouvée (même plan, même orientation) par SONDES_MIN d'entre elles.
## Le sol et la voûte (normale verticale) sont toujours grands.
func _surface_large(espace: PhysicsDirectSpaceState3D, o: Vector3, r: Dictionary) -> bool:
	var n: Vector3 = r["normal"]
	if absf(n.y) > SOL_NORMALE:
		return true
	if n == Vector3.ZERO:
		return true   # rayon parti de l'intérieur d'un solide : prudence, il masque
	var pt: Vector3 = r["position"]
	var d := (pt - o).normalized()
	var lat := n.cross(Vector3.UP).normalized()
	var haut := lat.cross(n).normalized()
	_q_sonde.collision_mask = 1
	_q_sonde.exclude = _q.exclude
	var ok := 0
	var k := 0
	for dec: Vector3 in [lat * SONDE, -lat * SONDE, haut * SONDE, -haut * SONDE]:
		k += 1
		_q_sonde.from = o + dec
		_q_sonde.to = pt + dec + d * 0.4
		var h := espace.intersect_ray(_q_sonde)
		rayons += 1
		if not h.is_empty() and absf(((h["position"] as Vector3) - pt).dot(n)) < 0.12 and (h["normal"] as Vector3).dot(n) > 0.8:
			ok += 1
		if ok >= SONDES_MIN or ok + (4 - k) < SONDES_MIN:
			break
	return ok >= SONDES_MIN

## Petit objet de décor (traversé par la lame) : au plus une des 4 sondes (gauche, droite, haut, bas, décalées de SONDE)
## rencontre une surface à moins de 0,6 m derrière le point touché. Une arête ou la tranche d'un mur, un angle, une urne collée
## au mur sont « entourés » : pas petits (ils masquent ce qui est derrière).
func _petit_objet(espace: PhysicsDirectSpaceState3D, o: Vector3, r: Dictionary) -> bool:
	var n: Vector3 = r["normal"]
	if n == Vector3.ZERO or absf(n.y) > SOL_NORMALE:
		return false
	var pt: Vector3 = r["position"]
	var d := (pt - o).normalized()
	var lat := d.cross(Vector3.UP).normalized()
	var haut := lat.cross(d).normalized()
	_q_sonde.collision_mask = 1
	_q_sonde.exclude = _q.exclude
	var autour := 0
	for dec: Vector3 in [lat * SONDE, -lat * SONDE, haut * SONDE, -haut * SONDE]:
		_q_sonde.from = o + dec
		_q_sonde.to = pt + dec + d * 0.6
		var h := espace.intersect_ray(_q_sonde)
		rayons += 1
		if not h.is_empty() and ((h["position"] as Vector3) - pt).dot(d) < 0.6:
			autour += 1
			if autour >= 2:
				return false
	return true
