class_name TraceLame
extends RefCounted
## Détection des coups par TRACÉ DE LAME : pendant la phase active, la lame est échantillonnée à pas de temps FIXE
## (PAS, indépendant des images par seconde) ; entre deux échantillons successifs, un rayon relie les positions de
## chaque point de la lame (garde → pointe prolongée de l'allonge). La zone de dégâts est donc le vrai mouvement de
## l'épée. Règles :
##   - une seule touche par cible et par coup (touches) ; au plus `max_cibles` cibles par coup ;
##   - un mur / le décor arrête la lame (événement « mur », rebond) ; le sol l'arrête sans rebond (« sol ») ;
##   - une cible vue à travers un mur (rayon œil → point d'impact coupé par le décor) compte comme le mur ;
##   - un « cassable » (mur fragile des donjons) arrête la lame et reçoit le coup.
## Cibles reconnues : nœud (ou ancêtre du collider) du groupe « ennemis » ou qui a recevoir_coup(), groupe « cassables ».

## Pas d'échantillonnage du tracé (s de temps de jeu) : 240 échantillons par seconde quel que soit le rendu.
const PAS := 1.0 / 240.0
## Calque physique du décor et des corps (joueur, ennemis, murs) ; les ragdolls (calque 16) ne bloquent pas la lame.
const MASQUE := 1
## Normale (composante verticale) au-delà de laquelle une surface est un sol : la lame s'y arrête sans rebondir.
const SOL_NORMALE := 0.6

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
	_prec = PackedVector3Array()
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

## Un échantillon de la lame (points monde, garde → bout). Renvoie les événements :
## {type: "cible" | "mur" | "sol" | "cassable", point, normale, objet, collider, direction (mouvement de la lame), indice}.
func echantillonner(espace: PhysicsDirectSpaceState3D, points: PackedVector3Array, oeil: Vector3, exclus: Array[RID], max_cibles: int) -> Array:
	var evts := []
	if arretee:
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
	return evts
