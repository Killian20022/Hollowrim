class_name Dallage
extends AbordsVillage
## C1b : chemins en DALLES nettes (référence exterieurs_v2_planche.png, vue 1 « chemin de montagne ») hors de la zone témoin.
## Réutilise le kit de dalles d'`AbordsVillage` (pierres irrégulières à joints, coins rabotés, liseré de neige au bord),
## mais le long d'une POLYLIGNE (u = abscisse curviligne, v = décalage latéral) au lieu d'un segment droit :
## - sentier témoin cercle (sortie du rectangle témoin `SolV2.RECT` → stèle) : le rectangle témoin reste tel quel,
##   les dalles apparaissent progressivement en en sortant ;
## - sentier stèle → porte du tertre, jusqu'aux 5 marches d'`AbordsTumulus`.
## Sous les dalles, le sol v2 (terre, gravier, neige mince) se voit dans les joints.
## Pas de collision (dalles de 2-5 cm, on marche dessus comme sur le sol). Option de pose `dallage=0` : sans ces dalles.
## Les pavés eux-mêmes (forme bombée, gris-bleu, neige) sont ceux du kit (`AbordsVillage._dalle`, `materiau_dalles`).

const DEMI := 0.95          # demi-largeur du dallage (m), plus étroit que l'entrée du village
const FONDU := 4.0          # m : les dalles se raréfient vers le début d'un tronçon

static var _noeuds: Array[Node3D] = []

var _cumul := PackedFloat32Array()
var _pts := PackedVector2Array()
var _u_debut := 0.0
var _u_fin := 0.0

static func poser(monde_: Node) -> void:
	_noeuds.clear()
	if not ZoneBiome.actif or monde_.chemins == null:
		return
	var ch: Chemins = monde_.chemins
	var debuts: PackedInt32Array = ch.debuts
	for l in debuts.size():
		var i0 := debuts[l]
		var i1 := (debuts[l + 1] if l + 1 < debuts.size() else ch.points.size()) - 1
		var pts := ch.points.slice(i0, i1 + 1)
		var cumul := PackedFloat32Array([0.0])
		for k in range(1, pts.size()):
			cumul.append(cumul[k - 1] + pts[k].distance_to(pts[k - 1]))
		var L := cumul[cumul.size() - 1]
		var u0 := 0.0
		var u1 := L
		if l == 0:
			# sentier du cercle : on commence à la sortie du rectangle témoin (le témoin reste tel quel)
			u0 = L
			for k in pts.size():
				if not SolV2.dans_rect(pts[k].x, pts[k].y, -0.5) and k > 0 and SolV2.dans_rect(pts[k - 1].x, pts[k - 1].y, -0.5):
					u0 = cumul[k]
			u1 = L - 0.6
		else:
			u1 = L - 4.4   # les 5 marches d'AbordsTumulus occupent les 4 derniers mètres
		if u1 - u0 < 2.0:
			continue
		var d := Dallage.new()
		d.name = "Dallage%d" % l
		d.monde = monde_
		d.rng.seed = (ZoneBiome.graine("dallage") + 7 * l) & 0x7fffffff
		d._pts = pts
		d._cumul = cumul
		d._u_debut = u0
		d._u_fin = u1
		monde_.add_child(d)
		d.set_process(false)   # pas de lanternes : rien à animer
		d._dalles_segment(u0, u1 + 7.5)   # +7,5 m : la raréfaction du kit (7 derniers mètres) tombe hors du tronçon
		d._finaliser_dalles()
		_noeuds.append(d)
		if monde_.has_method("_souffle"): await monde_._souffle()   # chargement étalé : une image entre deux sentiers (sans effet sinon)
	regler(monde_, true)

## Montre / cache les dalles des sentiers (option de pose `dallage=0`).
static func regler(_monde: Node, oui: bool) -> void:
	for n in _noeuds:
		if is_instance_valid(n):
			n.visible = oui


# --- repère curviligne -----------------------------------------------------------------------------------------

func _tangente(k: int) -> Vector2:
	var a := _pts[maxi(k - 1, 0)]
	var b := _pts[mini(k + 1, _pts.size() - 1)]
	return (b - a).normalized()

## (u, v) → point du monde : abscisse curviligne u le long de la polyligne, v à droite.
func _p(u: float, v: float) -> Vector2:
	var n := _pts.size()
	var k := clampi(_cumul.bsearch(u) - 1, 0, n - 2)
	var lseg := maxf(_cumul[k + 1] - _cumul[k], 0.001)
	var t := (u - _cumul[k]) / lseg
	var base := _pts[k].lerp(_pts[k + 1], t)   # hors des bouts : prolongé le long du premier / dernier segment
	var tg := _tangente(k).lerp(_tangente(k + 1), clampf(t, 0.0, 1.0)).normalized()
	return base + Vector2(-tg.y, tg.x) * v

func _l(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

## Filtre les pierres du kit : tronçon [u_debut, u_fin], largeur DEMI, raréfaction au début, rien dans le rectangle témoin.
func _dalle(poly: Array[Vector2], c2: Vector2, centre_v: float) -> void:
	if c2.x < _u_debut or c2.x > _u_fin:
		return
	if absf(c2.y - centre_v) > DEMI + 0.2 * sin(c2.x * 1.7):
		return
	var w := _p(c2.x, c2.y)
	if SolV2.dans_rect(w.x, w.y, -0.3):
		return
	var f := smoothstep(_u_debut, _u_debut + FONDU, c2.x)
	if rng.randf() > 0.15 + 0.85 * f:
		return
	super._dalle(poly, c2, centre_v)

func _finaliser_dalles() -> void:
	_mesh(_dalles, materiau_dalles(rng), false, "Dalles")
	print("Dallage %s : %d triangles de dalles (u %.1f → %.1f)" % [name, _dalles.v.size() / 3, _u_debut, _u_fin])
