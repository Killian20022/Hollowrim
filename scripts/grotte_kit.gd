class_name GrotteKit
extends RefCounted
## KIT DE DÉCOR MODULAIRE de la grotte (refonte « kit », d'après grottes_cryptes_5 / _6) : au lieu de grands volumes aux parois
## lisses et au sol nu, les salles vitrines sont ENCOMBRÉES à toutes les profondeurs par des pièces bas-poly réutilisables :
##   bloc_0..7      blocs de roche arrondis et bosselés (0,5 à 3 m une fois mis à l'échelle), calotte de givre sur le dessus
##   caillou_0..2   petits blocs (même famille, moins de faces) pour le bord du chemin
##   dalle_0..2     dalles plates givrées (terrasses du lac)
##   pan_0..3       ressauts / pans de paroi : 3-4 dalles empilées en gradins, plaquées contre les murs lisses pour les casser
##   stalag_0..3    stalagmites (élancée, massive, à satellites, trapue)       stalac_0..2  stalactites (longue, grappe de 3, large)
##   grappe_0..2    grappes de cristaux : prismes en éventail, cœur blanc-cyan (c_cristal_c), faces bleu vif émissives (c_cristal_v)
##   frange_0..1    franges de glaçons (rangée de 1 m de glaçons de longueurs variées)
##   + la cascade gelée (pièce unique, bâtie contre la paroi du fond) : orgues, draperies, ressauts et cône de glace au pied.
## Les gabarits sont fabriqués par code (graine fixe : identiques d'une partie à l'autre), une fois, puis posés en INSTANCES
## (MultiMesh, regroupées par case de 10 m : le rendu mobile limite à 8 lumières par objet). Toutes les pièces passent par
## shaders/grotte.gdshader (texture granuleuse projetée monde, occlusion peinte dans la couleur des sommets, givre des faces hautes ;
## les matières « k_* » du kit gardent une calotte de givre pleine sur les dessus : sol_plat = 0).
## Pose : graine de la zone, rejet des places occupées (disques au sol), jamais dans le chemin (|lat| - r ≥ VOIE), ni dans les
## couloirs réservés vers chaque accroche du jeu (ennemis, patrouilles, coffres, ressources, interactions, îlot), ni dans les réserves
## de Grotte (rampes et dalles des corniches), ni dans les jonctions. Les gros blocs et les stalagmites sont solides.
## Option : --sans-kit-grotte coupe tout (retour au décor v6 des modules).

const OPTION := "--sans-kit-grotte"
const GLB_ROCHES := "res://assets/grotte/modules/roches_v2.glb"   # v2 : modules rocheux modélisés dans Blender (sources_blender/scripts/grotte_roches_v2.py)
const OPTION_CODE := "--roches-code"                               # force les gabarits générés par code (comparaison avant/après)
const VOIE := 1.25            # demi-largeur du chemin gardée libre de tout le kit (m)
const GARDE := 2.3            # hauteur libre minimale sous une stalactite au-dessus de la zone de marche
const CASE := 10.0
const GRAPPE_C := Color(0.45, 0.8, 1.0)
const JOUR_C := Color(0.78, 0.86, 1.0)

static func actif() -> bool:
	return not OS.get_cmdline_user_args().has(OPTION)

var g: Grotte
var gab := {}                 # nom -> {"surf": {matière: tampon}, "h": hauteur, "prof": avancée hors du mur (pans)}
var _inst := {}               # "nom|cx,cz" -> Array[Transform3D]
var _occ: Array = []          # [Vector2 xz, rayon]
var _seg: Array = []          # [Vector2 a, Vector2 b, rayon]
var _fixes: Array = []        # v2 : places prises par les structures [id, Vector2 xz, rayon] : elles survivent à _reserver()
var _mats := {}
var nb_instances := 0
var nb_solides := 0
var nb_lum := 0
var stats := {}                # famille de gabarit -> nombre d'instances
var _cadres: Array = []        # passe 2 : poutres des étais de mine [Vector2 a, Vector2 b] (xz) : les stalactites les évitent
var nb_lanternes := 0          # passe 2 : lanternes posées par le kit (vraies lumières + lueurs seules)
var nb_lum_chaudes := 0        # passe 2 : dont vraies lumières
const LANT_C := Color(1.0, 0.56, 0.24)
var r := RandomNumberGenerator.new()

func _init(g_: Grotte) -> void:
	g = g_
	_gabarits()

# =================================================================== gabarits
static func _tampon() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "u": PackedVector2Array(), "i": PackedInt32Array()}

static func _S(G: Dictionary, nom: String) -> Dictionary:
	var s: Dictionary = G["surf"]
	if not s.has(nom):
		s[nom] = _tampon()
	return s[nom]

## Triangle à facette plate ; `dehors` : direction vers l'extérieur. Godot attend le sens horaire vu de la face avant.
static func _tri(S: Dictionary, a: Vector3, b: Vector3, c: Vector3, dehors: Vector3, ca: Color, cb: Color, cc: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var v: PackedVector3Array = S["v"]
	var nn: PackedVector3Array = S["n"]
	var co: PackedColorArray = S["c"]
	var uu: PackedVector2Array = S["u"]
	var ii: PackedInt32Array = S["i"]
	var i0 := v.size()
	if n.dot(dehors) < 0.0:
		n = -n
		v.append(a); v.append(b); v.append(c)
		co.append(ca); co.append(cb); co.append(cc)
		uu.append(ua); uu.append(ub); uu.append(uc)
	else:
		v.append(a); v.append(c); v.append(b)
		co.append(ca); co.append(cc); co.append(cb)
		uu.append(ua); uu.append(uc); uu.append(ub)
	nn.append(n); nn.append(n); nn.append(n)
	ii.append(i0); ii.append(i0 + 1); ii.append(i0 + 2)
	S["v"] = v; S["n"] = nn; S["c"] = co; S["u"] = uu; S["i"] = ii

## Icosphère unitaire subdivisée : [Array de Vector3, Array d'indices].
static func _ico(sub: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var P: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in P.size():
		P[i] = (P[i] as Vector3).normalized()
	var F: Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	for k in sub:
		var cache := {}
		var F2: Array = []
		for f in F.size() / 3:
			var idx: Array = [F[f * 3], F[f * 3 + 1], F[f * 3 + 2]]
			var m: Array = []
			for e in 3:
				var a: int = idx[e]
				var b: int = idx[(e + 1) % 3]
				var cle := Vector2i(mini(a, b), maxi(a, b))
				if not cache.has(cle):
					cache[cle] = P.size()
					P.append(((P[a] as Vector3) + (P[b] as Vector3)).normalized())
				m.append(cache[cle])
			F2.append_array([idx[0], m[0], m[2], idx[1], m[1], m[0], idx[2], m[2], m[1], m[0], m[1], m[2]])
		F = F2
	return [P, F]

## Ajoute un maillage lisse (normales moyennées) étoilé autour de `centre` à la surface S.
static func _lisse(S: Dictionary, Q: PackedVector3Array, F: Array, centre: Vector3, cols: PackedColorArray) -> void:
	var N := PackedVector3Array()
	N.resize(Q.size())
	var tris: Array = []
	for f in F.size() / 3:
		var a: int = F[f * 3]
		var b: int = F[f * 3 + 1]
		var c: int = F[f * 3 + 2]
		var n := (Q[b] - Q[a]).cross(Q[c] - Q[a])
		if n.dot((Q[a] + Q[b] + Q[c]) / 3.0 - centre) < 0.0:
			n = -n
			var t := b
			b = c
			c = t
		N[a] += n; N[b] += n; N[c] += n
		tris.append([a, b, c])
	var v: PackedVector3Array = S["v"]
	var nn: PackedVector3Array = S["n"]
	var co: PackedColorArray = S["c"]
	var uu: PackedVector2Array = S["u"]
	var ii: PackedInt32Array = S["i"]
	var i0 := v.size()
	for i in Q.size():
		v.append(Q[i])
		nn.append(N[i].normalized())
		co.append(cols[i])
		uu.append(Vector2.ZERO)
	for t: Array in tris:      # (b-a)x(c-a) vers l'extérieur = sens trigo ; Godot : sens horaire -> a, c, b
		ii.append(i0 + int(t[0])); ii.append(i0 + int(t[2])); ii.append(i0 + int(t[1]))
	S["v"] = v; S["n"] = nn; S["c"] = co; S["u"] = uu; S["i"] = ii

static func _bruit(graine: int) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.seed = graine
	nz.frequency = 1.0
	return nz

## Masse arrondie et bosselée (icosphère déformée) : renvoie [positions, faces, déplacement] dans le repère du gabarit.
static func _masse(graine: int, sub: int, taille: Vector3, bosses: float, aplat_bas: float, aplat_haut: float) -> Array:
	var nz := _bruit(graine)
	var ico := _ico(sub)
	var P: Array = ico[0]
	var Q := PackedVector3Array()
	var D := PackedFloat32Array()
	for v: Vector3 in P:
		var d := 1.0 + 0.2 * bosses * nz.get_noise_3dv(v * 1.4) + 0.08 * bosses * nz.get_noise_3dv(v * 3.4 + Vector3(17, 3, 5))
		var p := v * d
		if p.y < -aplat_bas:
			p.y = -aplat_bas + (p.y + aplat_bas) * 0.15
		if p.y > aplat_haut:
			p.y = aplat_haut + (p.y - aplat_haut) * 0.3
		Q.append(Vector3(p.x * taille.x, p.y * taille.y, p.z * taille.z))
		D.append(d)
	return [Q, ico[1], D]

## Couleurs d'une masse : occlusion (pied et creux sombres) + liseré de givre (alpha) sur les faces hautes, découpé au bruit.
static func _couleurs_masse(Q: PackedVector3Array, F: Array, D: PackedFloat32Array, centre: Vector3, graine: int, givre: float) -> PackedColorArray:
	var nz := _bruit(graine + 7)
	var N := PackedVector3Array()
	N.resize(Q.size())
	for f in F.size() / 3:
		var a: int = F[f * 3]
		var b: int = F[f * 3 + 1]
		var c: int = F[f * 3 + 2]
		var n := (Q[b] - Q[a]).cross(Q[c] - Q[a])
		if n.dot((Q[a] + Q[b] + Q[c]) / 3.0 - centre) < 0.0:
			n = -n
		N[a] += n; N[b] += n; N[c] += n
	var ymin := INF
	var ymax := -INF
	for p in Q:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var cols := PackedColorArray()
	for i in Q.size():
		var t := clampf((Q[i].y - ymin) / maxf(ymax - ymin, 0.01), 0.0, 1.0)
		var cav := clampf((D[i] - 0.84) / 0.32, 0.0, 1.0)
		var ao := lerpf(0.28, 1.0, pow(t, 0.6)) * (0.72 + 0.28 * cav)
		var n := N[i].normalized()
		var fr := smoothstep(0.42, 0.85, n.y) * smoothstep(0.25, 0.65, t) * clampf(0.75 + 0.9 * nz.get_noise_3dv(Q[i] * 3.0), 0.0, 1.25) * givre
		cols.append(Color(ao, ao * 0.99, ao * 1.02, 0.3 + fr * 0.95 if fr > 0.05 else 0.0))
	return cols

## v2 (pixel art marqué) : masse ANGULAIRE. Chaque sommet de l'icosphère reçoit son propre rayon (0,7 à 1,3) : arêtes vives,
## facettes plates de tailles inégales, plus rien de « galet » arrondi. Même interface que _masse.
static func _masse_ang(graine: int, sub: int, taille: Vector3, aplat_bas: float, aplat_haut: float) -> Array:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var nz := _bruit(graine)
	var ico := _ico(sub)
	var P: Array = ico[0]
	var Q := PackedVector3Array()
	var D := PackedFloat32Array()
	for v: Vector3 in P:
		var d := 0.8 + 0.34 * rg.randf() + 0.14 * nz.get_noise_3dv(v * 1.1)
		var p := v * d
		if p.y < -aplat_bas:
			p.y = -aplat_bas + (p.y + aplat_bas) * 0.1
		if p.y > aplat_haut:
			p.y = aplat_haut + (p.y - aplat_haut) * 0.35
		Q.append(Vector3(p.x * taille.x, p.y * taille.y, p.z * taille.z))
		D.append(d)
	return [Q, ico[1], D]

## Facettes PLATES : chaque face prend un ton parmi trois paliers selon son orientation (aplats nets, arête claire sur les faces
## tournées vers la lumière), le givre ne se pose que sur les faces hautes. `neige` >= 0 : masque de neige forcé (congères).
static func _facettes(S: Dictionary, Q: PackedVector3Array, F: Array, centre: Vector3, cols: PackedColorArray, graine: int, givre: float, neige := -1.0) -> void:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine + 91
	var lum := Vector3(0.35, 0.8, 0.45).normalized()
	for f in F.size() / 3:
		var ia: int = F[f * 3]
		var ib: int = F[f * 3 + 1]
		var ic: int = F[f * 3 + 2]
		var a := Q[ia]
		var b := Q[ib]
		var c := Q[ic]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var mid := (a + b + c) / 3.0
		var dehors := mid - centre
		if n.dot(dehors) < 0.0:
			n = -n
		var lit := clampf(n.dot(lum) * 0.5 + 0.5, 0.0, 1.0)
		var palier: float = [0.6, 0.8, 1.0][clampi(int(lit * 3.0 + rg.randf_range(-0.4, 0.4)), 0, 2)]
		var al := 0.0
		if neige >= 0.0:
			al = neige
		else:
			var fr := smoothstep(0.45, 0.8, n.y) * givre * rg.randf_range(0.7, 1.15)
			al = 0.3 + fr * 0.95 if fr > 0.05 else 0.0
		var ca := Color(cols[ia].r * palier, cols[ia].g * palier, cols[ia].b * palier, al)
		var cb := Color(cols[ib].r * palier, cols[ib].g * palier, cols[ib].b * palier, al)
		var cc := Color(cols[ic].r * palier, cols[ic].g * palier, cols[ic].b * palier, al)
		_tri(S, a, b, c, dehors, ca, cb, cc)

static func _g_bloc(graine: int, sub: int, ecrase: float, etire: float, givre := 1.0, aplat_haut := 0.75, mat := "k_roche_neige") -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var m := _masse_ang(graine, maxi(sub - 1, 0), Vector3(etire, ecrase, 1.0), 0.3, aplat_haut)
	var Q: PackedVector3Array = m[0]
	var rot := rg.randf() * TAU
	var rmax := 0.0
	var ymin := INF
	var ymax := -INF
	for i in Q.size():
		Q[i] = Q[i].rotated(Vector3.UP, rot)
		rmax = maxf(rmax, Vector2(Q[i].x, Q[i].z).length())
		ymin = minf(ymin, Q[i].y)
		ymax = maxf(ymax, Q[i].y)
	for i in Q.size():                      # emprise au sol : rayon 1 ; pied enfoncé de 6 cm
		Q[i] = (Q[i] - Vector3(0, ymin, 0)) / rmax - Vector3(0, 0.06, 0)
	var centre := Vector3(0, (ymax - ymin) / rmax * 0.4, 0)
	var G := {"surf": {}, "h": (ymax - ymin) / rmax, "prof": 0.0}
	_facettes(_S(G, mat), Q, m[1], centre, _couleurs_masse(Q, m[1], m[2], centre, graine, givre), graine, givre)
	return G

## Pan de paroi : 3-4 dalles bosselées empilées en gradins (les dessus forment des rebords givrés). +z = hors du mur.
static func _g_pan(graine: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 0.0, "prof": 0.0}
	var S := _S(G, "k_roche_neige")
	var y := 0.0
	var n := rg.randi_range(3, 4)
	var prof := 0.0
	for k in n:
		var W := rg.randf_range(0.6, 1.4) * (1.0 - 0.06 * k)
		var Dp := rg.randf_range(0.45, 0.95)
		var H := rg.randf_range(0.45, 1.1)
		var m := _masse_ang(graine * 13 + k, 1, Vector3(W, H * 0.6, Dp), 0.7, rg.randf_range(0.35, 0.7))
		var Q: PackedVector3Array = m[0]
		var off := Vector3(rg.randf_range(-0.5, 0.5), y + H * 0.42, Dp * 0.2 + float(n - k) * 0.1 * rg.randf_range(0.3, 1.6))
		var tourne := Basis(Vector3.UP, rg.randf_range(-0.35, 0.35)) * Basis(Vector3.FORWARD, rg.randf_range(-0.2, 0.2))
		for i in Q.size():
			Q[i] = tourne * Q[i] + off
		prof = maxf(prof, off.z + Dp)
		var centre := off
		_facettes(S, Q, m[1], centre, _couleurs_masse(Q, m[1], m[2], centre, graine + k, 1.0), graine + k, 1.0)
		y += H * rg.randf_range(0.62, 0.8)
	G["h"] = y + 0.3
	G["prof"] = prof
	return G

## ---- v1 (gabarits lisses d'origine), gardés UNIQUEMENT pour leurs dimensions : h et prof décident des solides et des places libres,
## donc des collisions, qui ne doivent pas bouger avec la v2.
static func _g_bloc_v1(graine: int, sub: int, ecrase: float, etire: float, givre := 1.0, aplat_haut := 0.75, mat := "k_roche_neige") -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var m := _masse(graine, sub, Vector3(etire, ecrase, 1.0), 1.0, 0.3, aplat_haut)
	var Q: PackedVector3Array = m[0]
	var rot := rg.randf() * TAU
	var rmax := 0.0
	var ymin := INF
	var ymax := -INF
	for i in Q.size():
		Q[i] = Q[i].rotated(Vector3.UP, rot)
		rmax = maxf(rmax, Vector2(Q[i].x, Q[i].z).length())
		ymin = minf(ymin, Q[i].y)
		ymax = maxf(ymax, Q[i].y)
	for i in Q.size():                      # emprise au sol : rayon 1 ; pied enfoncé de 6 cm
		Q[i] = (Q[i] - Vector3(0, ymin, 0)) / rmax - Vector3(0, 0.06, 0)
	var centre := Vector3(0, (ymax - ymin) / rmax * 0.4, 0)
	var G := {"surf": {}, "h": (ymax - ymin) / rmax, "prof": 0.0}
	_lisse(_S(G, mat), Q, m[1], centre, _couleurs_masse(Q, m[1], m[2], centre, graine, givre))
	return G

## Pan de paroi : 3-4 dalles bosselées empilées en gradins (les dessus forment des rebords givrés). +z = hors du mur.
static func _g_pan_v1(graine: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 0.0, "prof": 0.0}
	var S := _S(G, "k_roche_neige")
	var y := 0.0
	var n := rg.randi_range(3, 4)
	var prof := 0.0
	for k in n:
		var W := rg.randf_range(0.6, 1.4) * (1.0 - 0.06 * k)
		var Dp := rg.randf_range(0.45, 0.95)
		var H := rg.randf_range(0.45, 1.1)
		var m := _masse(graine * 13 + k, 1, Vector3(W, H * 0.6, Dp), 1.7, 0.7, rg.randf_range(0.35, 0.7))
		var Q: PackedVector3Array = m[0]
		var off := Vector3(rg.randf_range(-0.5, 0.5), y + H * 0.42, Dp * 0.2 + float(n - k) * 0.1 * rg.randf_range(0.3, 1.6))
		var tourne := Basis(Vector3.UP, rg.randf_range(-0.35, 0.35)) * Basis(Vector3.FORWARD, rg.randf_range(-0.2, 0.2))
		for i in Q.size():
			Q[i] = tourne * Q[i] + off
		prof = maxf(prof, off.z + Dp)
		var centre := off
		_lisse(S, Q, m[1], centre, _couleurs_masse(Q, m[1], m[2], centre, graine + k, 1.0))
		y += H * rg.randf_range(0.62, 0.8)
	G["h"] = y + 0.3
	G["prof"] = prof
	return G

## Concrétion tournée (stalagmite vers le haut, stalactite vers le bas), hauteur 1, rayon de pied `rb`, facettes plates.
static func _concretion(S: Dictionary, graine: int, base: Vector3, rb: float, h: float, bas: bool, givre: bool, tronque := false, cotes := 5, nr := 6) -> void:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var sg := -1.0 if bas else 1.0
	var phase := rg.randf() * TAU
	var nb := rg.randf_range(2.5, 4.5)
	var lean := Vector3(rg.randf_range(-1, 1), 0, rg.randf_range(-1, 1)) * h * rg.randf_range(0.02, 0.07)
	var a0 := rg.randf() * TAU
	var anneaux: Array = []
	var axe: Array = []
	var t_fin := 0.86 if tronque else 1.0
	for k in nr:
		var t := float(k) / float(nr - 1) * t_fin
		var c := base + Vector3(0, sg * h * t, 0) + lean * pow(t, 1.5)
		axe.append(c)
		var rad := rb * pow(1.0 - t, 0.85) * (1.0 + 0.18 * sin(t * PI * nb + phase) * (1.0 - t)) * (1.0 + 0.9 * pow(1.0 - t, 7.0))
		if tronque and k == nr - 1:
			rad = rb * 0.12
		var ring: Array = []
		if k == nr - 1 and not tronque:
			anneaux.append(ring)
			break
		for i in cotes:
			var a := a0 + TAU * (float(i) + rg.randf_range(-0.2, 0.2)) / float(cotes)
			var rr := rad * rg.randf_range(0.72, 1.2)
			ring.append(c + Vector3(cos(a) * rr, rg.randf_range(-0.25, 0.25) * h / float(nr), sin(a) * rr))
		anneaux.append(ring)
	for k in nr - 1:
		var t0 := float(k) / float(nr - 1)
		var t1 := float(k + 1) / float(nr - 1)
		var ao0 := lerpf(0.38, 1.0, t0) if not bas else lerpf(0.5, 0.85, t0)
		var ao1 := lerpf(0.38, 1.0, t1) if not bas else lerpf(0.5, 0.85, t1)
		var g0 := (0.3 + (t0 - 0.45) * 2.0) if givre and t0 > 0.5 else 0.0
		var g1 := (0.3 + (t1 - 0.45) * 2.0) if givre and t1 > 0.5 else 0.0
		var c0 := Color(ao0, ao0 * 0.99, ao0 * 1.02, g0)
		var c1 := Color(ao1, ao1 * 0.99, ao1 * 1.02, g1)
		var mid: Vector3 = ((axe[k] as Vector3) + (axe[k + 1] as Vector3)) * 0.5
		var A: Array = anneaux[k]
		var B: Array = anneaux[k + 1]
		for i in cotes:
			var j := (i + 1) % cotes
			if B.is_empty():
				var tip: Vector3 = axe[nr - 1]
				_tri(S, A[i], A[j], tip, ((A[i] as Vector3) + (A[j] as Vector3)) * 0.5 - mid, c0, c0, c1)
			else:
				var ctr := ((A[i] as Vector3) + (A[j] as Vector3) + (B[i] as Vector3) + (B[j] as Vector3)) * 0.25
				_tri(S, A[i], A[j], B[j], ctr - mid, c0, c0, c1)
				_tri(S, A[i], B[j], B[i], ctr - mid, c0, c1, c1)
	if tronque:                                 # dessus cassé : petit éventail plat (givré)
		var L: Array = anneaux[nr - 1]
		var top: Vector3 = axe[nr - 1]
		var cg := Color(1, 1, 1, 1.2 if givre else 0.0)
		for i in cotes:
			_tri(S, L[i], L[(i + 1) % cotes], top, Vector3(0, sg, 0), cg, cg, cg)

static func _g_stalag(graine: int, rb: float, satellites: int, tronque := false) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 1.0, "prof": 0.0}
	var S := _S(G, "k_roche_nu")
	_concretion(S, graine, Vector3(0, -0.08, 0), rb, 1.08, false, true, tronque)
	for k in satellites:
		var a := rg.randf() * TAU
		var d := rb * rg.randf_range(1.1, 1.8)
		_concretion(S, graine + 31 * (k + 1), Vector3(cos(a) * d, -0.05, sin(a) * d), rb * rg.randf_range(0.4, 0.6), rg.randf_range(0.22, 0.5), false, true)
	return G

static func _g_stalac(graine: int, rb: float, grappe: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 1.0, "prof": 0.0}
	var S := _S(G, "c_roche_nu")
	_concretion(S, graine, Vector3(0, 0.12, 0), rb, 1.12, true, false, false, 5, 5)
	for k in grappe:
		var a := TAU * float(k) / float(maxi(grappe, 1)) + rg.randf_range(-0.4, 0.4)
		var d := rb * rg.randf_range(1.2, 2.0)
		_concretion(S, graine + 17 * (k + 1), Vector3(cos(a) * d, 0.1, sin(a) * d), rb * rg.randf_range(0.45, 0.7), rg.randf_range(0.35, 0.75), true, false, false, 4, 4)
	return G

## Prisme de cristal hexagonal pointu (UV par face : la texture porte le dégradé et l'arête claire).
static func _prisme(S: Dictionary, base: Vector3, d: Vector3, rad: float, l: float, rg: RandomNumberGenerator) -> void:
	var u := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
	var w := d.cross(u)
	var a0 := rg.randf() * TAU
	var corps := l * rg.randf_range(0.72, 0.82)
	var pointe := base + d * l + (u * rg.randf_range(-0.2, 0.2) + w * rg.randf_range(-0.2, 0.2)) * rad
	var r1 := rad * rg.randf_range(0.9, 1.05)
	var v1 := corps / l
	var axe := base + d * l * 0.5
	var pied := Color(0.45, 0.45, 0.5, 0.0)
	var haut := Color(1, 1, 1, 0.0)
	var bout := Color(1.25, 1.25, 1.25, 0.0)
	for i in 6:
		var ra := u * cos(a0 + TAU * i / 6.0) + w * sin(a0 + TAU * i / 6.0)
		var rb := u * cos(a0 + TAU * (i + 1) / 6.0) + w * sin(a0 + TAU * (i + 1) / 6.0)
		var p0 := base + ra * rad
		var p1 := base + rb * rad
		var q0 := base + d * corps + ra * r1
		var q1 := base + d * corps + rb * r1
		var dh := (ra + rb).normalized()
		_tri(S, p0, p1, q1, dh, pied, pied, haut, Vector2(0, 1), Vector2(1, 1), Vector2(1, 1.0 - v1))
		_tri(S, p0, q1, q0, dh, pied, haut, haut, Vector2(0, 1), Vector2(1, 1.0 - v1), Vector2(0, 1.0 - v1))
		_tri(S, q0, q1, pointe, dh + d * 0.6, haut, haut, bout, Vector2(0, 1.0 - v1), Vector2(1, 1.0 - v1), Vector2(0.5, 0.0))

## Grappe de cristaux : 2-3 grands prismes de cœur presque droits, couronne de prismes bleu vif ouverte EN ÉVENTAIL (plan xy,
## face à +z), beaucoup de petits, quelques moyens. Taille 1 (le plus grand prisme ≈ 1 m).
static func _g_grappe(graine: int, eventail: float) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 1.0, "prof": 0.0}
	var Sc := _S(G, "c_cristal_c")
	var Sv := _S(G, "c_cristal_v")
	for k in rg.randi_range(2, 3):
		var d := (Vector3.UP + Vector3(rg.randf_range(-0.25, 0.25), 0, rg.randf_range(-0.15, 0.15))).normalized()
		var lk := rg.randf_range(0.78, 1.0)
		_prisme(Sc, Vector3(rg.randf_range(-0.06, 0.06), 0, rg.randf_range(-0.05, 0.05)) - d * lk * 0.1, d, rg.randf_range(0.08, 0.11), lk, rg)
	var n := rg.randi_range(13, 18)
	for k in n:
		var a := lerpf(-1.25, 1.25, (float(k) + rg.randf_range(0.0, 1.0)) / float(n)) * eventail
		var d := Vector3(sin(a), cos(a), rg.randf_range(-0.45, 0.45)).normalized()
		var f := pow(rg.randf(), 1.5) * (1.0 - 0.45 * absf(a) / 1.25)
		var lk := lerpf(0.2, 0.8, f)
		var base := Vector3(sin(a) * rg.randf_range(0.05, 0.22), 0, rg.randf_range(-0.12, 0.12))
		_prisme(Sv, base - d * lk * 0.15, d, lerpf(0.035, 0.085, f), lk, rg)
	return G

## v2 : aiguilles de glace (formations du lac, des couloirs) : 1 flèche + 1 à 3 satellites, prismes à 5 pans qui s'effilent en deux
## étages, flèche légèrement penchée. Trois tons par face (aplats), pas de texture : la matière c_glacon_c donne le bleu-blanc.
static func _g_pic(graine: int, n: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 1.0, "prof": 0.0}
	var S := _S(G, "c_glacon_c")
	for k in n:
		var a := rg.randf() * TAU
		var dd := 0.0 if k == 0 else rg.randf_range(0.14, 0.3)
		var base := Vector3(cos(a) * dd, -0.05, sin(a) * dd)
		var h := 1.0 if k == 0 else rg.randf_range(0.35, 0.72)
		var rad := 0.16 if k == 0 else rg.randf_range(0.075, 0.12)
		var pen := Vector3(rg.randf_range(-0.1, 0.1), 0.0, rg.randf_range(-0.1, 0.1)) * h
		var r0: Array = []
		var r1: Array = []
		var a0 := rg.randf() * TAU
		for i in 5:
			var ang := a0 + TAU * (float(i) + rg.randf_range(-0.18, 0.18)) / 5.0
			var rr := rad * rg.randf_range(0.8, 1.2)
			r0.append(base + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr))
			r1.append(base + Vector3(cos(ang) * rr * 0.7, h * 0.64, sin(ang) * rr * 0.7) + pen * 0.55)
		var tip := base + Vector3(0.0, h, 0.0) + pen
		for i in 5:
			var j := (i + 1) % 5
			var dh: Vector3 = ((r0[i] as Vector3) + (r0[j] as Vector3)) * 0.5 - base
			dh.y = 0.0
			var ton: float = [1.0, 0.82, 0.66][(i + k) % 3]
			var c0 := Color(0.28 * ton, 0.34 * ton, 0.46 * ton, 0.0)     # pied bleu ardoise -> corps bleu glace #9fb8dc -> pointe claire
			var c1 := Color(0.46 * ton, 0.58 * ton, 0.78 * ton, 0.0)
			var c2 := Color(0.66 * ton, 0.8 * ton, 1.0 * ton, 0.0)
			_tri(S, r0[i], r0[j], r1[j], dh, c0, c0, c1)
			_tri(S, r0[i], r1[j], r1[i], dh, c0, c1, c1)
			_tri(S, r1[i], r1[j], tip, dh + Vector3(0, 0.4, 0), c1, c1, c2)
	return G

## v2 : congère basse (neige poussée au bord du chemin) : dôme aplati à facettes, masque de neige plein, empreinte de rayon 1.
static func _g_neige(graine: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var m := _masse_ang(graine, 1, Vector3(1.0 + rg.randf() * 0.5, 0.2, 0.8 + rg.randf() * 0.3), 0.04, 0.5)
	var Q: PackedVector3Array = m[0]
	var rot := rg.randf() * TAU
	var rmax := 0.0
	var ymin := INF
	var ymax := -INF
	for i in Q.size():
		Q[i] = Q[i].rotated(Vector3.UP, rot)
		rmax = maxf(rmax, Vector2(Q[i].x, Q[i].z).length())
		ymin = minf(ymin, Q[i].y)
		ymax = maxf(ymax, Q[i].y)
	var cols := PackedColorArray()
	for i in Q.size():
		var t := clampf((Q[i].y - ymin) / maxf(ymax - ymin, 0.01), 0.0, 1.0)
		Q[i] = (Q[i] - Vector3(0, ymin, 0)) / rmax - Vector3(0, 0.03, 0)
		var ao := lerpf(0.58, 0.8, t)                          # neige bleutée (#9aa6be de la planche), plus de blanc pur
		cols.append(Color(ao * 0.82, ao * 0.9, ao * 1.02, 1.6))
	var G := {"surf": {}, "h": (ymax - ymin) / rmax, "prof": 0.0}
	_facettes(_S(G, "k_sol_neige"), Q, m[1], Vector3(0, 0.05, 0), cols, graine, 0.0, 1.6)
	return G

static func _g_frange(graine: int, n: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var G := {"surf": {}, "h": 1.0, "prof": 0.0}
	var S := _S(G, "c_glacon_c")
	for k in n:
		var x := lerpf(-0.5, 0.5, (float(k) + rg.randf_range(0.1, 0.9)) / float(n))
		var l := lerpf(0.1, 1.0, pow(rg.randf(), 1.7))
		var rad := 0.022 + 0.05 * l
		var top := Vector3(x, 0.05, rg.randf_range(-0.07, 0.07))
		var tip := top + Vector3(rg.randf_range(-0.03, 0.03), -l, rg.randf_range(-0.03, 0.03))
		var a0 := rg.randf() * TAU
		var mi := top.lerp(tip, 0.35)
		for i in 5:
			var aa := a0 + TAU * i / 5.0
			var bb := a0 + TAU * (i + 1) / 5.0
			var p0 := top + Vector3(cos(aa), 0, sin(aa)) * rad
			var p1 := top + Vector3(cos(bb), 0, sin(bb)) * rad
			var m0 := mi + Vector3(cos(aa), 0, sin(aa)) * rad * 0.6
			var m1 := mi + Vector3(cos(bb), 0, sin(bb)) * rad * 0.6
			var dh := Vector3(cos((aa + bb) * 0.5), 0, sin((aa + bb) * 0.5))
			var c0 := Color(0.9, 0.9, 0.92, 0)
			var c1 := Color(1.05, 1.05, 1.08, 0)
			_tri(S, p0, p1, m1, dh, c0, c0, c1)
			_tri(S, p0, m1, m0, dh, c0, c1, c1)
			_tri(S, m0, m1, tip, dh, c1, c1, Color(1.2, 1.2, 1.25, 0))
	return G

func _gabarits() -> void:
	var rg := RandomNumberGenerator.new()
	rg.seed = 52031
	for k in 8:
		gab["bloc_%d" % k] = _g_bloc(7100 + k * 37, 2, rg.randf_range(0.55, 0.9), rg.randf_range(1.0, 1.5))
	for k in 3:
		gab["caillou_%d" % k] = _g_bloc(7500 + k * 41, 1, rg.randf_range(0.5, 0.8), rg.randf_range(1.0, 1.4))
	for k in 3:
		gab["dalle_%d" % k] = _g_bloc(7700 + k * 43, 2, rg.randf_range(0.26, 0.34), rg.randf_range(1.2, 1.6), 1.7, 0.35, "k_terrasse")   # passe 2 : terrasses givrées plus claires
	for k in 4:
		gab["pan_%d" % k] = _g_pan(7900 + k * 53)
	gab["stalag_0"] = _g_stalag(8101, 0.15, 0)
	gab["stalag_1"] = _g_stalag(8102, 0.27, 1)
	gab["stalag_2"] = _g_stalag(8103, 0.2, 3)
	gab["stalag_3"] = _g_stalag(8104, 0.32, 2, true)
	gab["stalac_0"] = _g_stalac(8201, 0.11, 0)
	gab["stalac_1"] = _g_stalac(8202, 0.14, 3)
	gab["stalac_2"] = _g_stalac(8203, 0.24, 1)
	gab["grappe_0"] = _g_grappe(8301, 1.0)
	gab["grappe_1"] = _g_grappe(8302, 0.75)
	gab["grappe_2"] = _g_grappe(8303, 1.15)
	for k in 3:
		gab["pic_%d" % k] = _g_pic(8601 + k * 7, 2 + k)
		gab["neige_%d" % k] = _g_neige(8701 + k * 11)
	gab["frange_0"] = _g_frange(8401, 9)
	gab["frange_1"] = _g_frange(8402, 12)
	rg.seed = 52031                    # mêmes tirages qu'à l'origine : dimensions v1 de chaque gabarit
	for k in 8:
		gab["bloc_%d" % k]["dim_v1"] = _g_bloc_v1(7100 + k * 37, 2, rg.randf_range(0.55, 0.9), rg.randf_range(1.0, 1.5))
	for k in 3:
		gab["caillou_%d" % k]["dim_v1"] = _g_bloc_v1(7500 + k * 41, 1, rg.randf_range(0.5, 0.8), rg.randf_range(1.0, 1.4))
	for k in 3:
		gab["dalle_%d" % k]["dim_v1"] = _g_bloc_v1(7700 + k * 43, 2, rg.randf_range(0.26, 0.34), rg.randf_range(1.2, 1.6), 1.7, 0.35, "k_terrasse")
	for k in 4:
		gab["pan_%d" % k]["dim_v1"] = _g_pan_v1(7900 + k * 53)
	for nom: String in gab:
		if (gab[nom] as Dictionary).has("dim_v1"):
			var dv: Dictionary = gab[nom]["dim_v1"]
			gab[nom]["h"] = dv["h"]
			gab[nom]["prof"] = dv["prof"]
			(gab[nom] as Dictionary).erase("dim_v1")
	if not OS.get_cmdline_user_args().has(OPTION_CODE):
		_depuis_glb()

## v2 : remplace blocs, cailloux, dalles et pans par les modules Blender (enveloppes convexes anguleuses, couleurs cuites).
## Le .glb n'est lu que pour sa géométrie et ses couleurs de sommets : la matière reste celle du kit (shader de la grotte), donc
## aucun piège d'alpha 0 / tex_neige. Repli silencieux sur les gabarits par code si le fichier manque.
func _depuis_glb() -> void:
	if not ResourceLoader.exists(GLB_ROCHES):
		return
	var ps := load(GLB_ROCHES) as PackedScene
	if ps == null:
		return
	var racine := ps.instantiate()
	var lus := 0
	var pile: Array = [racine]
	while not pile.is_empty():
		var nd: Node = pile.pop_back()
		pile.append_array(nd.get_children())
		if not (nd is MeshInstance3D):
			continue
		var nom := String(nd.name)
		if not gab.has(nom) or not (nom.begins_with("bloc_") or nom.begins_with("caillou_") or nom.begins_with("dalle_") or nom.begins_with("pan_")):
			continue
		var mesh: Mesh = (nd as MeshInstance3D).mesh
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var S := _tampon()
		S["v"] = v
		S["n"] = arr[Mesh.ARRAY_NORMAL]
		var cols := PackedColorArray()
		if arr[Mesh.ARRAY_COLOR] != null:
			cols = arr[Mesh.ARRAY_COLOR]
		if cols.size() != v.size():
			cols.resize(v.size())
			cols.fill(Color(1, 1, 1, 0))
		S["c"] = cols
		var uu := PackedVector2Array()
		uu.resize(v.size())
		S["u"] = uu
		if arr[Mesh.ARRAY_INDEX] != null:
			S["i"] = arr[Mesh.ARRAY_INDEX]
		else:
			var ii := PackedInt32Array()
			for q in v.size():
				ii.append(q)
			S["i"] = ii
		# h et prof RESTENT ceux des gabarits par code : ils décident des solides (dalles > 33 cm, blocs…), donc des collisions, qui ne bougent pas
		var G := {"surf": {}, "h": float(gab[nom]["h"]), "prof": float(gab[nom]["prof"])}
		G["surf"]["k_terrasse" if nom.begins_with("dalle_") else "k_roche_neige"] = S
		gab[nom] = G
		lus += 1
	racine.free()
	print("kit grotte : %d modules rocheux Blender lus (%s)" % [lus, GLB_ROCHES])

# =================================================================== matières, instances
func _mat(nom: String) -> Material:
	if _mats.has(nom):
		return _mats[nom]
	var m: Material = g.decor.mat(nom)   # « k_* » : variante sans sol plat, créée par le décor (pas de duplicate() : lecture serveur bloquante en fil)
	_mats[nom] = m
	return m

func _add(nom: String, pos: Vector3, lacet: float, ech: Vector3, incl := Basis()) -> void:
	var b := Basis(Vector3.UP, lacet) * incl * Basis.from_scale(ech)
	var cle := "%s|%d,%d" % [nom, floori(pos.x / CASE), floori(pos.z / CASE)]
	if not _inst.has(cle):
		_inst[cle] = []
	(_inst[cle] as Array).append(Transform3D(b, pos))
	nb_instances += 1
	var fam := nom.get_slice("_", 0)
	stats[fam] = int(stats.get(fam, 0)) + 1

## Base qui oriente l'axe +y du gabarit selon `axe` (grappes penchées vers le chemin).
static func _vers(axe: Vector3) -> Basis:
	var y := axe.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)

func _instancier() -> void:
	var maillages := {}
	for nom: String in gab:
		var G: Dictionary = gab[nom]
		var m := ArrayMesh.new()
		for mat_nom: String in G["surf"]:
			var S: Dictionary = G["surf"][mat_nom]
			if (S["v"] as PackedVector3Array).is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = S["v"]
			arr[Mesh.ARRAY_NORMAL] = S["n"]
			arr[Mesh.ARRAY_COLOR] = S["c"]
			arr[Mesh.ARRAY_TEX_UV] = S["u"]
			arr[Mesh.ARRAY_INDEX] = S["i"]
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(m.get_surface_count() - 1, _mat(mat_nom))
		maillages[nom] = m
	for cle: String in _inst:
		var nom := cle.get_slice("|", 0)
		var xs: Array = _inst[cle]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = maillages[nom]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Kit_" + cle.replace("|", "_").replace(",", "_").replace("-", "m")
		g.add_child(mi)

func nb_triangles() -> int:
	var n := 0
	for cle: String in _inst:
		var G: Dictionary = gab[cle.get_slice("|", 0)]
		var t := 0
		for mat_nom: String in G["surf"]:
			t += (G["surf"][mat_nom]["i"] as PackedInt32Array).size() / 3
		n += t * (_inst[cle] as Array).size()
	return n

# =================================================================== places libres
static func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

static func _d_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _reserver_pt(id: String, s: float, lat: float, rr: float, couloir := true) -> void:
	var p := _xz(g.sol_en(id, s, lat))
	_occ.append([p, rr])
	if couloir:
		_seg.append([p, _xz(g.sol_en(id, s, 0.0)), 0.7])

## Couloirs vers toutes les accroches du jeu de la branche (et l'îlot), disques autour des accessoires posés par les modules.
func _reserver(id: String) -> void:
	_occ.clear()
	_seg.clear()
	for f: Array in _fixes:
		if f[0] == id:
			_occ.append([f[1], f[2]])
	for z: Dictionary in g.zones.values():
		if z["branche"] != id:
			continue
		for cle in ["ennemis", "coffres", "ressources", "interactions", "meca"]:
			for e: Dictionary in z.get(cle, []):
				_reserver_pt(id, float(e["s"]), float(e["lat"]), 0.9)
				var pts: Array = e.get("patrouille", [])
				for k in pts.size():
					var q: Array = pts[k]
					_reserver_pt(id, float(q[0]), float(q[1]), 1.0, false)
					if k > 0:
						var q0: Array = pts[k - 1]
						_seg.append([_xz(g.sol_en(id, float(q0[0]), float(q0[1]))), _xz(g.sol_en(id, float(q[0]), float(q[1]))), 0.9])
		var pr: Dictionary = z.get("params", {})
		if pr.has("ilot_s"):
			var si := float(pr["ilot_s"])
			var li := float(pr.get("ilot_lat", -9.0))
			var ri := float(pr.get("ilot_r", 3.0))
			_occ.append([_xz(g.sol_en(id, si, li)), ri + 1.3])
			_seg.append([_xz(g.sol_en(id, si, li)), _xz(g.sol_en(id, si, 0.0)), 1.5])
			_seg.append([_xz(g.sol_en(id, si, li)), _xz(g.sol_en(id, si - 4.0, -1.0)), 1.2])

func libre(id: String, s: float, lat: float, rr: float, serre := 0.85) -> bool:
	if absf(lat) - rr < VOIE or not g.hors_jonction(id, s):
		return false
	if s < 0.5 or s > g.longueur(id) - 0.5:
		return false
	if not g.libre(id, s, lat, rr * 0.7):
		return false
	var p := _xz(g.sol_en(id, s, lat))
	for e: Array in _seg:
		if _d_seg(p, e[0], e[1]) < rr + float(e[2]):
			return false
	for o: Array in _occ:
		if p.distance_to(o[0]) < (rr + float(o[1])) * serre:
			return false
	return true

## Parement du fond d'un cul-de-sac (dôme lisse) : pans tournés vers la salle, du sol à ~5 m, sur toute la largeur.
func _parer_fond(id: String, s_ref: float, cristaux: float) -> void:
	var T := g.tang(id, s_ref)
	T.y = 0.0
	T = T.normalized()
	var dl := g.demi_l(id, s_ref)
	var lat := -dl.x * 0.9
	while lat < dl.y * 0.9:
		var y0 := g.sol_en(id, s_ref, lat).y
		var hh := 0.0
		var etages := 0
		while etages < 4:
			var o := g.sol_en(id, s_ref, lat) + Vector3(0, hh + 0.45, 0)
			var hit := g.rayon(o, T, 10.0)
			if hit.is_empty():
				break
			var n: Vector3 = hit["n"]
			n.y = 0.0
			n = n.normalized() if n.length() > 0.2 else -T
			var ech := r.randf_range(0.8, 1.3)
			var nom := "pan_%d" % r.randi_range(0, 3)
			var p: Vector3 = (hit["p"] as Vector3) - n * 0.42 * ech
			p.y = y0 + hh - (0.15 if etages == 0 else 0.0)
			if etages == 0:
				var q := p + n * float(gab[nom]["prof"]) * ech * 0.5
				if not _libre_xz(_xz(q), ech * 0.7):
					hh += 1.2
					etages += 1
					continue
				_occ.append([_xz(q), ech * 0.75])
			_add(nom, p, atan2(n.x, n.z), Vector3(ech * r.randf_range(0.9, 1.3), ech, ech))
			_garnir_pan({"p": p, "n": n, "prof": float(gab[nom]["prof"]) * ech, "h": float(gab[nom]["h"]) * ech}, cristaux, etages > 0)
			hh += float(gab[nom]["h"]) * ech * r.randf_range(0.65, 0.85)
			etages += 1
		lat += r.randf_range(0.9, 1.4)

func _libre_xz(p: Vector2, rr: float) -> bool:
	for e: Array in _seg:
		if _d_seg(p, e[0], e[1]) < rr + float(e[2]):
			return false
	for o: Array in _occ:
		if p.distance_to(o[0]) < (rr + float(o[1])) * 0.7:
			return false
	return true

## Place libre au fond d'un cul-de-sac : le chemin n'y passe plus (seuls comptent les couloirs des accroches et l'occupation).
func _libre_fond(id: String, s: float, lat: float, rr: float) -> bool:
	var p := _xz(g.sol_en(id, s, lat))
	for e: Array in _seg:
		if _d_seg(p, e[0], e[1]) < rr + float(e[2]):
			return false
	for o: Array in _occ:
		if p.distance_to(o[0]) < (rr + float(o[1])) * 0.7:
			return false
	return true

func _occuper(id: String, s: float, lat: float, rr: float) -> void:
	_occ.append([_xz(g.sol_en(id, s, lat)), rr])

func _occuper_fixe(id: String, s: float, lat: float, rr: float) -> void:
	var p := _xz(g.sol_en(id, s, lat))
	_occ.append([p, rr])
	_fixes.append([id, p, rr])

## Distance latérale de la paroi (côté `cote`) à la hauteur h au-dessus du sol de l'axe, et point/normale du mur.
var _murs := {}
func _mur(id: String, s: float, cote: float, h: float) -> Dictionary:
	var cle := "%s|%d|%d|%d" % [id, roundi(s * 4.0), int(cote), roundi(h * 4.0)]
	if _murs.has(cle):
		return _murs[cle]
	var res := _mur_calc(id, s, cote, h)
	_murs[cle] = res
	return res

func _mur_calc(id: String, s: float, cote: float, h: float) -> Dictionary:
	var R := g.droite(id, s) * cote
	var o := g.sol_en(id, s, 0.0) + Vector3(0, h, 0)
	var hit := g.rayon(o, R, 25.0)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit["n"]
	n.y = 0.0
	if n.length() < 0.2:
		n = -R
	hit["nh"] = n.normalized()
	hit["lat"] = ((hit["p"] as Vector3) - o).dot(R)
	return hit

func _solide(p: Vector3, rayon: float, haut: float) -> void:
	g.decor.solide_rond(p + Vector3(0, haut * 0.5, 0), rayon, haut)
	nb_solides += 1

# =================================================================== poseurs
func _bloc(id: String, s: float, lat: float, rr: float, solide := true, petit := false) -> void:
	var nom := ("caillou_%d" % r.randi_range(0, 2)) if petit else ("bloc_%d" % r.randi_range(0, 7))
	var p := g.sol_en(id, s, lat)
	var e := rr * r.randf_range(0.9, 1.1)
	var eh := rr * r.randf_range(1.0, 1.5)
	_add(nom, p + Vector3(0, -0.04 * rr, 0), r.randf() * TAU, Vector3(e, eh, rr))
	_occuper(id, s, lat, rr)
	var h_b: float = float(gab[nom]["h"]) * eh
	if solide and rr >= 0.45:
		_solide(p, rr * 0.78, h_b * 0.85)
	if not petit and rr > 0.6 and r.randf() < 0.45:          # amas : un bloc plus petit posé dessus, de travers
		var a := r.randf() * TAU
		var r2 := rr * r.randf_range(0.4, 0.6)
		var q := p + Vector3(cos(a), 0, sin(a)) * rr * 0.35 + Vector3(0, h_b * 0.7, 0)
		_add("bloc_%d" % r.randi_range(0, 7), q, r.randf() * TAU, Vector3(r2, r2 * r.randf_range(0.9, 1.3), r2), Basis(Vector3(cos(a), 0, sin(a)), r.randf_range(-0.4, 0.4)))

func _stalagmite(id: String, s: float, lat: float, h: float, solide := true) -> float:
	var k := r.randi_range(0, 3)
	var nom := "stalag_%d" % k
	var p := g.sol_en(id, s, lat)
	var pt := g.plafond_en(id, s, lat)
	h = minf(h, 0.72 * (pt.y - p.y))
	if h < 0.6:
		return 0.0
	var e := h * r.randf_range(0.85, 1.2)
	var yaw := r.randf() * TAU
	var sty := GrotteDecor._style_en(g, id, s)
	if (sty == "glace" or sty == "cristaux") and GrotteDecor.hash2(p.x * 1.7, p.z * 2.3) < 0.4:
		_add("pic_%d" % (k % 3), p, yaw, Vector3(e * 0.8, h, e * 0.8))      # v2 : aiguille de glace (formation) au lieu de la roche
	else:
		_add(nom, p, yaw, Vector3(e, h, e))
	var rb: float = [0.15, 0.27, 0.2, 0.32][k] * e
	_occuper(id, s, lat, rb * 1.3)
	if solide and rb > 0.12:
		_solide(p, rb * 0.85, h * 0.6)
	return rb

func _stalactite(id: String, s: float, lat: float, lmax: float, marche := true) -> void:
	if g.faille_f(g.br[id], s) > 0.02:
		return
	if not _cadres.is_empty():
		var q := _xz(g.sol_en(id, s, lat))
		for e: Array in _cadres:
			if _d_seg(q, e[0], e[1]) < 0.75:
				return
	var pb := g.sol_en(id, s, lat)
	var pt := g.plafond_en(id, s, lat)
	var bas_min := pb.y + (GARDE if marche else 0.9)
	var l := minf(lmax, pt.y + 0.12 - bas_min)
	if l < 0.35:
		return
	var k := r.randi_range(0, 2)
	var e := l * r.randf_range(0.8, 1.15)
	_add("stalac_%d" % k, pt + Vector3(0, 0.1, 0), r.randf() * TAU, Vector3(e, l, e))

func _grappe(p: Vector3, taille: float, axe: Vector3, lacet := -999.0) -> void:
	var b := _vers(axe)
	var la := r.randf() * TAU if lacet < -900.0 else lacet
	# le plan de l'éventail (xy du gabarit) tourne autour de l'axe de pousse
	_add("grappe_%d" % r.randi_range(0, 2), p, 0.0, Vector3.ONE * taille, b * Basis(Vector3.UP, la))

func _frange(p: Vector3, dir: Vector3, long_: float, ech := 1.0) -> void:
	var la := atan2(-dir.z, dir.x) if dir.length() > 0.01 else 0.0      # axe x du gabarit le long de `dir`
	_add("frange_%d" % r.randi_range(0, 1), p, la, Vector3(long_, ech, 1.0))

## Pan de paroi plaqué contre le mur (côté `cote`) à la hauteur h ; rend {} ou {"p", "n", "ech", "prof"}.
func _pan(id: String, s: float, cote: float, h: float, ech: float, au_sol: bool) -> Dictionary:
	var m := _mur(id, s, cote, maxf(h, 0.4) + 0.4)
	if m.is_empty():
		return {}
	var n: Vector3 = m["nh"]
	var nom := "pan_%d" % r.randi_range(0, 3)
	var prof: float = float(gab[nom]["prof"]) * ech
	var lat_w: float = m["lat"]
	var lat_c := cote * (lat_w - prof * 0.45)
	if au_sol:
		if not libre(id, s, lat_c, ech * 0.75, 0.7):
			return {}
		_occuper(id, s, lat_c, ech * 0.8)
	elif h < 4.8 and not g.libre(id, s, cote * (lat_w - prof), 0.3):      # au-dessus d'une corniche : la tête des archers reste libre
		return {}
	var p: Vector3 = m["p"] - n * 0.42 * ech
	p.y = (g.sol_en(id, s, cote * (lat_w - 0.3)).y - 0.15) if au_sol else (g.sol_en(id, s, 0.0).y + h)
	_add(nom, p, atan2(n.x, n.z), Vector3(ech * r.randf_range(0.9, 1.3), ech * r.randf_range(0.85, 1.15), ech))
	return {"p": p, "n": n, "ech": ech, "prof": prof, "h": float(gab[nom]["h"]) * ech}

## Habille un pan : frange de glaçons sous son bord (pans en hauteur), grappe de cristaux sur son rebord.
func _garnir_pan(pn: Dictionary, cristaux: float, en_haut: bool) -> void:
	var n: Vector3 = pn["n"]
	var p: Vector3 = pn["p"]
	if en_haut and r.randf() < 0.55:
		_frange(p + n * float(pn["prof"]) * 0.7 + Vector3(0, 0.12, 0), n.cross(Vector3.UP), r.randf_range(0.8, 1.6), r.randf_range(0.6, 1.3))
	if cristaux > 0.0 and r.randf() < (0.4 if en_haut else 0.5) * cristaux:
		var top := p + n * float(pn["prof"]) * r.randf_range(0.3, 0.55) + Vector3(0, float(pn["h"]) * 0.8, 0)
		_grappe(top, r.randf_range(0.4, 0.85), (n * 0.8 + Vector3.UP).normalized())

# =================================================================== salle des cristaux (grottes_cryptes_6)
func _salle_cristaux(z: Dictionary) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	r.seed = int(z.get("graine", 1)) * 97 + 3
	_reserver(id)
	for q in [[s1 - 7.0, 2.0], [s1 - 9.0, 1.6], [s1 - 8.0, -1.6]]:     # os, arme, crâne du module
		_reserver_pt(id, float(q[0]), float(q[1]), 0.7, false)
	var L := g.longueur(id)
	var sa := maxf(s0 - 1.5, 0.6)
	var sb := minf(s1 + 0.2, L - 0.6)
	# 1. quatre grandes grappes éclairées : les SEULES lumières cyan de la salle
	for e: Array in [[s0 + 4.6, -1.0, 1.9], [s0 + 6.0, 1.0, 1.7], [s0 + 11.8, -1.0, 1.8], [s0 + 13.6, 1.0, 2.0]]:
		var s: float = e[0]
		var cote: float = e[1]
		var dl := g.demi_l(id, s)
		var lat: float = cote * maxf((dl.y if cote > 0.0 else dl.x) * 0.62, 2.4)
		var q := g.sol_en(id, s, lat)
		var vers_axe := g.sol_en(id, s, 0.0) - q
		vers_axe.y = 0.0
		vers_axe = vers_axe.normalized()
		var axe := (Vector3.UP * 1.4 + vers_axe).normalized()
		var t: float = e[2]
		_grappe(q + Vector3(0, -0.12, 0), t, axe, r.randf_range(-0.4, 0.4) + atan2(vers_axe.x, vers_axe.z))
		_grappe(q + vers_axe * t * 0.35 - Vector3(0, 0.05, 0), t * 0.45, (axe + vers_axe * 0.6).normalized())
		_occuper(id, s, lat, t * 0.45)
		if g.loin_du_jeu(id, s, lat, 0.5):
			_solide(q, 0.5, 1.4)
		g.decor.carte("halo_f", q + Vector3(0, 0.04, 0), Vector3.UP, t * 3.2, t * 3.2)
		var l := g.decor.lumiere(q + axe * t * 0.7, GRAPPE_C, 3.2, 6.5 + t * 1.8, 1.2, false)
		l.light_color = GRAPPE_C
		l.set_meta("grappe", true)
		g.nb_lumieres += 1
		nb_lum += 1
		# blocs qui l'enchâssent (derrière et sur les côtés)
		for j in 3:
			var ds := (float(j) - 1.0) * t * 0.9 + r.randf_range(-0.2, 0.2)
			var dlat := cote * (t * 0.55 + r.randf_range(0.0, 0.5)) * (1.0 if j != 1 else 1.3)
			var rr := t * r.randf_range(0.35, 0.55)
			if libre(id, s + ds, lat + dlat, rr, 0.55):
				_bloc(id, s + ds, lat + dlat, rr)
	_habiller_parois(id, sa, sb, 1.0)
	# 2. grappes moyennes et petites entre les blocs, près du chemin et contre les parois
	for k in 140:
		var s := r.randf_range(sa, sb)
		var cote := 1.0 if r.randf() < 0.5 else -1.0
		var dl := g.demi_l(id, s)
		var w := dl.y if cote > 0.0 else dl.x
		var lat := cote * r.randf_range(1.45, w * 0.95)
		var t := r.randf_range(0.45, 1.3) * (1.0 if absf(lat) > 2.2 else 0.7)
		if not libre(id, s, lat, t * 0.3, 0.6):
			continue
		var q := g.sol_en(id, s, lat)
		var vers_axe := g.sol_en(id, s, 0.0) - q
		vers_axe.y = 0.0
		_grappe(q - Vector3(0, 0.06, 0), t, (Vector3.UP * 1.5 + vers_axe.normalized()).normalized())
		_occuper(id, s, lat, t * 0.3)
	# 3. fond de la salle (cul-de-sac) : amas de blocs, stalagmites et grappes en travers, hors du couloir du coffre
	for k in 60:
		var s := r.randf_range(L - 3.2, L - 0.6)
		var dl := g.demi_l(id, s)
		var lat := r.randf_range(-dl.x * 0.9, dl.y * 0.9)
		var rr := r.randf_range(0.4, 1.1)
		if not _libre_fond(id, s, lat, rr):
			continue
		var tirage := r.randf()
		if tirage < 0.55:
			_bloc(id, s, lat, rr)
		elif tirage < 0.8:
			_stalagmite(id, s, lat, r.randf_range(1.2, 3.0))
		else:
			_grappe(g.sol_en(id, s, lat) - Vector3(0, 0.05, 0), rr * 1.2, (Vector3.UP * 1.4 - g.tang(id, s)).normalized())
			_occuper(id, s, lat, rr * 0.4)
	_parer_fond(id, L - 4.0, 1.0)
	# passe 2 : étais de mine, lanternes, marches (RNG à part, après tout ce qui est solide : aucune collision déplacée)
	_mine_cristaux(id, s0, L)
	_marches(id, s0 + 1.6, L - 3.6)
	# 4. stalactites partout (jamais à travers une poutre)
	for k in 110:
		var s := r.randf_range(sa, sb)
		var dl := g.demi_l(id, s)
		var lat := r.randf_range(-dl.x * 0.95, dl.y * 0.95)
		_stalactite(id, s, lat, lerpf(0.5, 3.4, pow(r.randf(), 1.4)), absf(lat) < 2.4)

## Habillage commun des deux salles, côté par côté : pans de paroi (au sol et en hauteur, franges de glaçons dessous),
## gros blocs à demi dans la paroi, blocs moyens, petits blocs au bord du chemin, stalagmites derrière, grappes posées sur les blocs.
func _habiller_parois(id: String, sa: float, sb: float, cristaux: float, cotes := [-1.0, 1.0], lat_min_g := 0.0) -> void:
	for cote: float in cotes:
		# parement : colonnes de pans empilés du sol jusqu'à 5-6 m (ressauts continus qui cassent la paroi lisse)
		var s := sa + r.randf_range(0.0, 0.8)
		while s < sb:
			var pn := _pan(id, s, cote, 0.0, r.randf_range(0.9, 1.5), true)
			var hh := r.randf_range(1.6, 2.4)
			if not pn.is_empty():
				hh = float(pn["h"]) * r.randf_range(0.7, 0.85)
				_garnir_pan(pn, cristaux, false)
			var m := _mur(id, s, cote, 1.0)
			var lat_w: float = float(m.get("lat", 3.0))
			var libre_h := g.plafond_en(id, s, cote * maxf(lat_w - 1.0, 0.5)).y - g.sol_en(id, s, 0.0).y
			var etages := 0
			while hh < minf(libre_h - 1.2, 6.5) and etages < 4:
				var pn2 := _pan(id, s + r.randf_range(-0.35, 0.35), cote, hh, r.randf_range(0.8, 1.3), false)
				if pn2.is_empty():
					hh += 0.8
				else:
					_garnir_pan(pn2, cristaux, true)
					hh += float(pn2["h"]) * r.randf_range(0.65, 0.85)
				etages += 1
			s += r.randf_range(1.2, 1.9)
		# gros blocs au pied de la paroi (à moitié dedans)
		s = sa + r.randf_range(0.0, 0.8)
		while s < sb:
			var m := _mur(id, s, cote, 0.5)
			if not m.is_empty():
				var rr := r.randf_range(0.9, 1.7)
				var lat := cote * (float(m["lat"]) - rr * 0.3)
				if absf(lat) > lat_min_g and libre(id, s, lat, rr, 0.55):
					_bloc(id, s, lat, rr)
					if cristaux > 0.0 and r.randf() < 0.35 * cristaux:
						var q := g.sol_en(id, s, lat - cote * rr * 0.3) + Vector3(0, rr * 0.9, 0)
						_grappe(q, r.randf_range(0.4, 0.75), (Vector3.UP * 1.2 - g.droite(id, s) * cote).normalized())
			s += r.randf_range(0.6, 1.1)
		# stalagmites entre les gros blocs et la paroi
		for k in int((sb - sa) * 1.6):
			var s2 := r.randf_range(sa, sb)
			var m := _mur(id, s2, cote, 0.5)
			if m.is_empty():
				continue
			var lat := cote * (float(m["lat"]) - r.randf_range(0.5, 2.2))
			var h := r.randf_range(1.0, 3.6)
			if absf(lat) > lat_min_g and libre(id, s2, lat, h * 0.22, 0.75):
				var rb := _stalagmite(id, s2, lat, h)
				if rb > 0.0 and r.randf() < 0.7:
					for j in r.randi_range(1, 3):        # éclats et petits blocs au pied
						var a := r.randf() * TAU
						var d := rb * r.randf_range(1.6, 2.6)
						if libre(id, s2 + sin(a) * d, lat + cos(a) * d, 0.25, 0.4):
							_bloc(id, s2 + sin(a) * d, lat + cos(a) * d, r.randf_range(0.2, 0.4), false, true)
		# blocs moyens dans la bande du milieu
		for k in int((sb - sa) * 4.0):
			var s2 := r.randf_range(sa, sb)
			var dl := g.demi_l(id, s2)
			var w := dl.y if cote > 0.0 else dl.x
			var rr := r.randf_range(0.45, 1.15)
			var lat := cote * r.randf_range(VOIE + rr * 0.8, maxf(w - 0.6, VOIE + rr + 0.2))
			if absf(lat) > lat_min_g and libre(id, s2, lat, rr, 0.62):
				_bloc(id, s2, lat, rr)
				if cristaux > 0.0 and r.randf() < 0.3 * cristaux:
					_grappe(g.sol_en(id, s2, lat) + Vector3(0, rr * 0.75, 0), r.randf_range(0.3, 0.6), (Vector3.UP * 1.3 - g.droite(id, s2) * cote).normalized())
		# stalagmites isolées dans la bande du milieu (silhouettes à toutes les profondeurs)
		for k in int((sb - sa) * 0.8):
			var s2 := r.randf_range(sa, sb)
			var lat := cote * r.randf_range(VOIE + 0.4, 3.5)
			var h := r.randf_range(0.8, 2.4)
			if absf(lat) > lat_min_g and libre(id, s2, lat, h * 0.2, 0.7):
				_stalagmite(id, s2, lat, h)
		# petits blocs au bord du chemin : le chemin « serpente » entre les masses
		for k in int((sb - sa) * 4.0):
			var s2 := r.randf_range(sa, sb)
			var rr := r.randf_range(0.18, 0.7)
			var lat := cote * r.randf_range(VOIE + rr, VOIE + rr + 1.0)
			if absf(lat) > lat_min_g and libre(id, s2, lat, rr, 0.75):
				_bloc(id, s2, lat, rr, true, rr < 0.4)

# =================================================================== caverne du lac (grottes_cryptes_5)
func _salle_lac(z: Dictionary) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	r.seed = int(z.get("graine", 1)) * 89 + 11
	_reserver(id)
	for q in [[s0 + 1.5, 2.4], [s0 + 7.0, 2.0], [s0 + 13.0, 1.6]]:      # caisse, os, arme du module
		_reserver_pt(id, float(q[0]), float(q[1]), 0.8, false)
	for zz: Dictionary in g.zones.values():          # lanternes possibles (GrotteDecor._retoucher_lumieres : poteau contre la paroi)
		var nl := int(zz.get("n_lum", 0))
		if zz["branche"] != id or nl <= 0:
			continue
		for k in nl:
			var sl := lerpf(float(zz["s"][0]), float(zz["s"][1]), (float(k) + 0.5) / float(nl))
			var cote := 1.0 if k % 2 == 0 else -1.0
			var dl := g.demi_l(id, sl)
			_reserver_pt(id, sl, cote * maxf((dl.y if cote > 0.0 else dl.x) - 0.55, 0.9), 0.9, false)
	for sl: float in [s0 + 7.0, s0 + 19.0, s0 + 29.0]:                   # lanternes de la rive (GrotteDecor._hab_lac)
		var rv := GrotteModules._rive(g, id, sl)
		if rv < 900.0:
			_reserver_pt(id, sl, rv + 0.9, 0.8, false)
	var L := g.longueur(id)
	var sa := maxf(s0 + 0.5, 0.6)
	var sb := minf(s1 - 0.3, L - 0.6)
	_cascade(z)
	# 2. terrasses givrées sur la rive : dalles en gradins vers la glace, franges de glaçons au rebord côté lac
	var st := sa + 1.0
	while st < sb - 2.0:
		var rv := GrotteModules._rive(g, id, st)
		if rv < 900.0:
			var vers_lac := g.sol_en(id, st, rv - 3.0) - g.sol_en(id, st, rv)
			vers_lac.y = 0.0
			vers_lac = vers_lac.normalized()
			for j in 3:
				var lat := rv + 0.6 - float(j) * 1.1 + r.randf_range(-0.2, 0.2)
				var rr := r.randf_range(0.8, 1.35) * (1.0 - 0.15 * j)
				if not libre(id, st, lat, rr, 0.7):
					continue
				var q := g.sol_en(id, st, lat)
				var y := maxf(q.y, g.lac_y) - 0.1
				var nom := "dalle_%d" % r.randi_range(0, 2)
				var eh := rr * r.randf_range(0.9, 1.3)
				_add(nom, Vector3(q.x, y, q.z), r.randf() * TAU, Vector3(rr, eh, rr))
				_occuper(id, st, lat, rr * 0.9)
				var h_d: float = float(gab[nom]["h"]) * eh
				if h_d > 0.33:
					_solide(Vector3(q.x, y, q.z), rr * 0.8, h_d)
				for f in r.randi_range(1, 2):
					var dir := vers_lac.rotated(Vector3.UP, r.randf_range(-0.9, 0.9))
					var bord := Vector3(q.x, y, q.z) + dir * rr * 0.92 + Vector3(0, h_d * 0.82, 0)
					_frange(bord, dir.cross(Vector3.UP), r.randf_range(0.7, 1.3), minf(h_d * 1.4, 0.8))
		st += r.randf_range(1.8, 3.0)
	# 1. forêt de stalagmites étagée côté lac : trois plans (près, milieu, fond), chacune avec un amas de blocs au pied
	var plans := [[2.4, 4.6, 1.6, 3.2, 16], [4.8, 8.2, 2.4, 4.8, 24], [8.5, 99.0, 3.5, 6.5, 30]]
	for pl: Array in plans:
		var faites := 0
		for k in 220:
			if faites >= int(pl[4]):
				break
			var s := r.randf_range(sa + 1.0, sb - 1.5)
			var dl := g.demi_l(id, s)
			var lat := -r.randf_range(float(pl[0]), minf(float(pl[1]), dl.x * 0.93))
			var h := r.randf_range(float(pl[2]), float(pl[3]))
			if absf(lat) > dl.x * 0.93 or not libre(id, s, lat, h * 0.2, 0.8):
				continue
			var rb := _stalagmite(id, s, lat, h)
			if rb <= 0.0:
				continue
			faites += 1
			for j in r.randi_range(2, 4):
				var a := r.randf() * TAU
				var d := rb * r.randf_range(1.5, 2.8)
				var rr := r.randf_range(0.25, 0.7)
				if libre(id, s + sin(a) * d, lat + cos(a) * d, rr, 0.45):
					_bloc(id, s + sin(a) * d, lat + cos(a) * d, rr, rr > 0.5)
	# 3. parois des deux côtés (pas de cristaux ici), côté droit : la corniche est protégée par les réserves
	_habiller_parois(id, sa, sb, 0.0)
	# 4. gros blocs au premier plan, au bord du chemin (cadre des vues de la rive)
	for k in 40:
		var s2 := r.randf_range(sa, sa + 9.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var rr := r.randf_range(0.7, 1.4)
		var lat := cote * r.randf_range(VOIE + rr + 0.05, VOIE + rr + 1.6)
		if libre(id, s2, lat, rr, 0.7):
			_bloc(id, s2, lat, rr)
	# 5. quelques grappes discrètes au bord de la glace (le cristal du lac reste une ressource à part)
	for k in 14:
		var s2 := r.randf_range(sa, sb)
		var rv := GrotteModules._rive(g, id, s2)
		if rv > 900.0:
			continue
		var lat := rv - r.randf_range(0.2, 2.0)
		if libre(id, s2, lat, 0.25, 0.6):
			_grappe(g.sol_en(id, s2, lat) - Vector3(0, 0.05, 0), r.randf_range(0.3, 0.6), Vector3(r.randf_range(-0.3, 0.3), 1, r.randf_range(-0.3, 0.3)))
	# 6. voûte : stalactites denses, longues au-dessus du lac
	for k in 260:
		var s2 := r.randf_range(sa, sb)
		var dl := g.demi_l(id, s2)
		var lat := r.randf_range(-dl.x * 0.95, dl.y * 0.95)
		_stalactite(id, s2, lat, lerpf(0.6, 4.5 if lat < -3.0 else 2.6, pow(r.randf(), 1.3)), true)
	# passe 2 : lanternes chaudes sur la rive d'en face (à gauche dans les vues du rivage), RNG à part
	_lanternes_lac(id, sa, sb)

## Passe 2 : poteaux à lanterne sur le bord rocheux d'en face du lac (grottes_cryptes_5 : lueurs orange sur la rive gauche).
## Une seule vraie lumière (la plus proche du rivage d'arrivée) ; les autres ne sont que flamme et halos. Non solides.
func _lanternes_lac(id: String, sa: float, sb: float) -> void:
	var d := g.decor
	var faites := 0
	for sl: float in [sa + 6.0, sa + 13.0, sa + 20.0]:
		if sl > sb - 3.0:
			break
		var dl := g.demi_l(id, sl)
		var lat := -dl.x + 0.6
		var trouve := false
		while lat < -3.5:
			var q := g.sol_en(id, sl, lat)
			if q.y > g.lac_y + 0.12 and g.libre(id, sl, lat, 0.25) and _libre_xz(_xz(q), 0.3):
				trouve = true
				break
			lat += 0.4
		if not trouve:
			continue
		var pied := g.sol_en(id, sl, lat)
		var vers := g.sol_en(id, sl, 0.0) - pied
		var f := d.poteau_lanterne(pied, vers, false)
		_occuper(id, sl, lat, 0.3)
		nb_lanternes += 1
		if faites == 0:
			var l := d.lumiere(f, LANT_C, 4.5, 9.0, 1.4, true)
			l.light_color = LANT_C
			l.set_meta("grappe", true)
			g.nb_lumieres += 1
			nb_lum_chaudes += 1
		else:
			var vh := vers
			vh.y = 0.0
			d.carte("halo", f, vh.normalized(), 1.3, 1.3)
		faites += 1

# =================================================================== passe 2 : mine des cristaux (grottes_cryptes_6)
## Étais de mine en enfilade le long du chemin : deux poteaux équarris (à ±1,8 m de l'axe, hors de la voie de 1,25 m), linteau
## massif à contrefiches (GrotteDecor._bois_etai), longerons et écharpes entre deux cadres, une lanterne de fer pendue à chaque
## linteau (côté alterné). Les trois premières portent une VRAIE lumière orange (flaque chaude sur le sol et les rochers du chemin) ;
## les suivantes ne sont que lueurs (flamme, halos additifs, flaque peinte au sol) : le rendu mobile limite les lumières par objet,
## et GrotteJeu n'en allume de toute façon que MAX_LUM. Rien n'est solide : aucune collision ni chemin de marche ne change.
func _mine_cristaux(id: String, s0: float, L: float) -> void:
	var d := g.decor
	var LAT := 1.8
	var H := 3.2
	var cibles := [s0 + 4.3, s0 + 7.9, s0 + 11.4, s0 + 14.8, s0 + 17.4]
	var prev: Array = []
	var k := 0
	var rm := RandomNumberGenerator.new()      # variations de l'enfilade (RNG à part : r n'est pas touché)
	rm.seed = 61033
	for sc: float in cibles:
		var s := -1.0
		for dec: float in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9]:
			if sc + dec < L - 2.2 and _poteau_libre(id, sc + dec, -LAT) and _poteau_libre(id, sc + dec, LAT):
				s = sc + dec
				break
		if s < 0.0:
			continue
		var R := g.droite(id, s)
		R.y = 0.0
		R = R.normalized()
		var T := g.tang(id, s)
		T.y = 0.0
		T = T.normalized()
		# retouche : enfilade irrégulière (écart des poteaux, hauteur, un poteau penché au pied décalé)
		var pa := g.sol_en(id, s + rm.randf_range(-0.12, 0.12), -LAT - rm.randf_range(-0.1, 0.15))
		var pb := g.sol_en(id, s + rm.randf_range(-0.12, 0.12), LAT + rm.randf_range(-0.1, 0.15))
		var haut := minf(pa.y, pb.y) + H + rm.randf_range(-0.15, 0.12)
		var ta := Vector3(pa.x, haut, pa.z)
		var tb := Vector3(pb.x, haut, pb.z)
		var pied_a := pa - Vector3(0, 0.15, 0)
		var pied_b := pb - Vector3(0, 0.15, 0)
		if k == 2:
			pied_a += T * 0.32 - R * 0.12          # étai penché : le pied a glissé, la tête tient le linteau
		d.prisme("bois", pied_a, ta, 0.15, 8)        # poteaux (redessinés équarris, cerclés de fer)
		d.prisme("bois", pied_b, tb, 0.15, 8)
		d.prisme("bois", ta - R * 0.3, tb + R * 0.3, 0.17, 8)          # linteau + contrefiches + chaîne
		_cadres.append([_xz(ta - R * 0.4), _xz(tb + R * 0.4)])
		if not prev.is_empty():
			for j in 2:
				var a0: Vector3 = prev[j]
				var a1: Vector3 = ta if j == 0 else tb
				d.prisme("bois", a0 + Vector3(0, 0.12, 0), a1 + Vector3(0, 0.12, 0), 0.1, 4)          # longeron
				var dir := (a1 - a0).normalized()
				d.prisme("bois", a0 - Vector3(0, 0.8, 0), a0 + dir * 0.75 + Vector3(0, 0.06, 0), 0.055, 4)   # jambes de force courtes
				d.prisme("bois", a1 - Vector3(0, 0.8, 0), a1 - dir * 0.75 + Vector3(0, 0.06, 0), 0.055, 4)
				_cadres.append([_xz(a0), _xz(a1)])
			if k == 1 or k == 3:                   # planches de garnissage posées sur les longerons, par endroits
				var a0: Vector3 = prev[0]
				var b0: Vector3 = prev[1]
				var lg := a0.distance_to(ta)
				var np := int(lg / 0.42)
				for q in np:
					if rm.randf() < 0.22:
						continue                   # planche manquante
					var t := (float(q) + 0.5) / float(np)
					var ga := a0.lerp(ta, t)
					var gb := b0.lerp(tb, t)
					var cpl := (ga + gb) * 0.5 + Vector3(0, 0.24 + rm.randf_range(-0.02, 0.02), 0)
					var dl_ := gb - ga
					d.boite("bois", cpl, Vector3(dl_.length() + rm.randf_range(0.1, 0.5), 0.05, rm.randf_range(0.22, 0.3)), atan2(dl_.x, dl_.z) - PI * 0.5 + rm.randf_range(-0.05, 0.05))
		prev = [ta, tb]
		# lanterne au linteau, côté alterné, à 0,6 m du poteau vers le chemin
		var cote := -1.0 if k % 2 == 0 else 1.0
		var t_side := ta if cote < 0.0 else tb
		var croc := t_side - R * cote * 0.62 - Vector3(0, 0.24, 0)
		var f := d.lanterne(croc, 0.32)
		nb_lanternes += 1
		if k < 3:
			var l := d.lumiere(f, LANT_C, 4.2, 8.5, 1.45, true)
			l.light_color = LANT_C
			l.set_meta("grappe", true)          # pas de retouche par GrotteDecor._retoucher_lumieres
			g.nb_lumieres += 1
			nb_lum_chaudes += 1
		else:
			d.carte("halo", f + Vector3(0, 0.05, 0), -T, 1.15, 1.15)                  # lueur lisible de loin (flamme + halos de la lanterne)
		k += 1

func _poteau_libre(id: String, s: float, lat: float) -> bool:
	if not g.hors_jonction(id, s) or not g.libre(id, s, lat, 0.25):
		return false
	var p := _xz(g.sol_en(id, s, lat))
	for e: Array in _seg:
		if _d_seg(p, e[0], e[1]) < 0.25 + float(e[2]) * 0.8:
			return false
	for o: Array in _occ:             # les petites pièces (grappes, cailloux) peuvent toucher un poteau ; pas les gros blocs
		if float(o[1]) > 0.55 and p.distance_to(o[0]) < (0.2 + float(o[1])) * 0.6:
			return false
	return true

## Marches de pierre (décor NON bloquant) sur la descente du chemin : dalles de 0,85 m posées au ras du sol (dessus à la hauteur
## moyenne du sol sous la dalle + 3 cm), nez de marche givré. Le sol reste la seule surface de marche (pente douce inchangée).
func _marches(id: String, sa: float, sb: float) -> void:
	var d := g.decor
	var rm := RandomNumberGenerator.new()
	rm.seed = 61057
	var s := sa
	var W := 1.05
	var n := 0
	while s < sb:
		var lg := rm.randf_range(0.75, 0.95)
		var s2 := minf(s + lg, sb)
		var ws := W + rm.randf_range(-0.1, 0.15)
		var c00 := g.sol_en(id, s, -ws)
		var c01 := g.sol_en(id, s, ws)
		var c10 := g.sol_en(id, s2, -ws)
		var c11 := g.sol_en(id, s2, ws)
		var y_min := minf(minf(c00.y, c01.y), minf(c10.y, c11.y))
		var y_max := maxf(maxf(c00.y, c01.y), maxf(c10.y, c11.y))
		if y_max - y_min > 0.35:          # sol trop chahuté : pas de marche ici
			s = s2 + 0.05
			continue
		var y := (c00.y + c01.y + c10.y + c11.y) * 0.25 + 0.035
		var j := func(p: Vector3, dy: float) -> Vector3:
			return Vector3(p.x, y + dy, p.z)
		var a: Vector3 = j.call(c00, rm.randf_range(-0.01, 0.015))
		var b: Vector3 = j.call(c01, rm.randf_range(-0.01, 0.015))
		var c: Vector3 = j.call(c11, rm.randf_range(-0.01, 0.015))
		var e: Vector3 = j.call(c10, rm.randf_range(-0.01, 0.015))
		var ref_h := (a + b + c + e) * 0.25 + Vector3(0, 1, 0)
		var nez := GrotteDecor.col(1.0, 1.0)         # nez de marche (bord aval, celui qui dépasse du sol) : clair, liseré de givre
		var dos := GrotteDecor.col(0.42, 0.0)        # fond de marche sombre : vue d'en haut, l'escalier se lit en bandes
		d.facette("k_sol_nu", a, b, c, ref_h, [dos, dos, nez], true, 2.0)
		d.facette("k_sol_nu", a, c, e, ref_h, [dos, nez, nez], true, 2.0)
		# contremarche côté aval (on descend vers s croissant : la face visible en montant regarde vers -T)
		var bas := 0.32
		var ref_av := (e + c) * 0.5 + (e - a).normalized() * 1.0
		var sombre := GrotteDecor.col(0.45, 0.0)
		d.facette("c_roche_nu", e, c, c - Vector3(0, bas, 0), ref_av, [nez, nez, sombre], true, 2.0)
		d.facette("c_roche_nu", e, c - Vector3(0, bas, 0), e - Vector3(0, bas, 0), ref_av, [nez, sombre, sombre], true, 2.0)
		n += 1
		s = s2 + rm.randf_range(0.02, 0.06)
	stats["marche"] = n

# =================================================================== cascade gelée (pièce unique)
## Bâtie contre la paroi du FOND de la caverne (face au rivage) : les colonnes suivent la roche (rayons contre la coque), s'élargissent
## vers le bas, débordent d'un ressaut à mi-hauteur ; orgues (colonnes qui s'arrêtent en grands glaçons), draperies sur les bords,
## ressaut de roche givré en tête, cône de glace et flaque gelée au pied.
func _cascade(z: Dictionary) -> void:
	var id: String = z["branche"]
	var s1: float = z["s"][1]
	var d := g.decor
	var s_dep := s1 - 8.0
	var dl := g.demi_l(id, s_dep)
	var lat_c := -minf(dl.x * 0.5, 7.0)
	var T := g.tang(id, s_dep)
	T.y = 0.0
	T = T.normalized()
	var o0 := g.sol_en(id, s_dep, lat_c)
	var y_ref := maxf(o0.y, g.lac_y)
	var hit := g.rayon(Vector3(o0.x, y_ref + 1.5, o0.z), T, 16.0)
	if hit.is_empty():
		push_warning("kit grotte : paroi du fond introuvable, cascade v6")
		d._cascade(g, id, s_dep)
		return
	var W0: Vector3 = hit["p"]
	var n: Vector3 = hit["n"]
	n.y = 0.0
	n = n.normalized() if n.length() > 0.2 else -T
	var lat_v := Vector3(n.z, 0, -n.x)
	var bas := g.rayon(W0 + n * 1.2 + Vector3(0, 2.0, 0), Vector3.DOWN, 12.0)
	var yb: float = (bas["p"] as Vector3).y if not bas.is_empty() else y_ref
	var haut := g.rayon(W0 + n * 0.6, Vector3.UP, 20.0)
	for recul: float in [1.5, 2.5, 3.5]:        # passe 2 : paroi en surplomb -> on cherche la voûte un peu en avant (chute plus haute)
		var h2 := g.rayon(W0 + n * recul, Vector3.UP, 20.0)
		if not h2.is_empty() and (haut.is_empty() or (h2["p"] as Vector3).y > (haut["p"] as Vector3).y):
			haut = h2
	var H := minf(((haut["p"] as Vector3).y - yb - 0.9) if not haut.is_empty() else 7.0, 11.0)     # passe 2 : jusqu'à 11 m (8 avant)
	var K := 0.72               # passe 2 (retouche) : chute ÉTROITE et haute (~4,8 m de large pour 8 à 11 m de haut) ; les tirages aléatoires restent les mêmes
	H = maxf(H, 3.5)
	var y_top := yb + H
	var t_res := 0.45          # ressaut à mi-hauteur
	# point de la paroi à (décalage latéral u, hauteur y) ; repli : plan vertical par W0
	var mur := func(u: float, y: float) -> Vector3:
		var o := W0 + lat_v * u + n * 3.0
		o.y = y
		var h2 := g.rayon(o, -n, 6.0)
		if h2.is_empty():
			return Vector3(W0.x, y, W0.z) + lat_v * u
		return h2["p"]
	# ressaut de tête : pans et blocs givrés en surplomb
	for k in 3:
		var u := ((float(k) - 1.0) * 1.1 + r.randf_range(-0.2, 0.2)) * K
		var p: Vector3 = mur.call(u, y_top - 0.3)
		_add("pan_%d" % r.randi_range(0, 3), p - n * 0.35 + Vector3(0, -0.2, 0), atan2(n.x, n.z), Vector3(1.0, 0.7, 0.9) * r.randf_range(0.9, 1.2))
	# ressaut du milieu : la glace en déborde
	var y_m := yb + H * t_res
	for k in 2:
		var u := ((float(k) - 0.5) * 1.6 + r.randf_range(-0.2, 0.2)) * K
		var p: Vector3 = mur.call(u, y_m)
		_add("bloc_%d" % r.randi_range(0, 7), p - n * 0.3 + Vector3(0, -0.45, 0), r.randf() * TAU, Vector3(1.0, 0.75, 1.0) * r.randf_range(0.8, 1.0))
	# colonnes : deux couches (fond c_glacon, devant c_glacon_c), éventail du haut (étroit) vers le bas (large)
	for couche in 2:
		var nom := "c_cascade" if couche == 0 else "c_cascade_c"
		var nb := 15 if couche == 0 else 18
		for j in nb:
			var u_b := lerpf(-3.3, 3.3, (float(j) + r.randf_range(0.2, 0.8)) / float(nb)) * K
			var u_t := u_b * (r.randf_range(0.4, 0.55) + 0.32)     # passe 2 : colonne presque droite (haute et étroite), même tirage
			var rad := r.randf_range(0.14, 0.32) * (1.0 if couche == 0 else 0.85) * 1.45
			var t_fin := 0.0
			if couche == 1 and r.randf() < 0.4:           # orgue : s'arrête en grand glaçon
				t_fin = r.randf_range(0.3, 0.7)
			if absf(u_b) > 2.8 * K and r.randf() < 0.6:   # draperie de bord : plus courte
				t_fin = maxf(t_fin, r.randf_range(0.45, 0.75))
			var top_off := r.randf_range(-0.25, 0.2)
			var pts: Array = []
			var rads: Array = []
			var nk := 16
			var phase := r.randf() * TAU
			for k in nk + 1:
				var t := 1.0 - float(k) / float(nk) * (1.0 - t_fin)      # t : 1 en haut -> t_fin (ou 0) en bas
				var y := yb + H * t + top_off * t
				var u := lerpf(u_b, u_t, pow(t, 0.8))
				var q: Vector3 = mur.call(u, y)
				var ep := (0.12 + 0.35 * (1.0 - t)) * (1.0 if couche == 1 else 0.6) + rad
				var deb := 0.75 * exp(-pow((t - t_res + 0.06) / 0.09, 2.0)) * (1.0 if couche == 1 else 0.7)   # débord sur le ressaut
				pts.append(q + n * (ep + deb))
				var rr := rad * (1.0 + 0.28 * sin(t * 23.0 + phase)) * (1.0 + 1.4 * pow(1.0 - t, 6.0) * (1.0 if t_fin == 0.0 else 0.0))
				rads.append(rr * (1.25 if absf(t - t_res + 0.08) < 0.08 else 1.0))
			_tube(nom, pts, rads, 6, 0.62 if couche == 0 else 0.8, 1.0, t_fin > 0.0)
	# franges sous le ressaut du milieu (là où la glace déborde)
	for k in 5:
		var u := lerpf(-1.8, 1.8, float(k) / 4.0) + r.randf_range(-0.2, 0.2)
		var p: Vector3 = mur.call(u * 0.75 * K, y_m - 0.25)
		_frange(p + n * (0.95 + r.randf_range(0.0, 0.3)), lat_v, r.randf_range(0.8, 1.4), r.randf_range(0.9, 1.6))
	# pied : cône de glace, cônes secondaires, flaque gelée
	var pied := Vector3(W0.x, yb, W0.z) + n * 1.1
	for k in 4:
		var u := (0.0 if k == 0 else r.randf_range(-2.0, 2.0)) * K
		var rc := (1.5 if k == 0 else r.randf_range(0.5, 0.9)) * 1.2
		var hc := (1.4 if k == 0 else r.randf_range(0.4, 0.8))
		var c := pied + lat_v * u + n * (0.0 if k == 0 else r.randf_range(-0.3, 0.6)) - Vector3(0, 0.05, 0)
		d.revolution("c_cascade_c", c, [Vector2(rc * 1.3, 0.0), Vector2(rc, hc * 0.3), Vector2(rc * 0.55, hc * 0.7), Vector2(rc * 0.22, hc), Vector2(0.0, hc * 1.05)], 8, r.randi(), 0.35, 0.0, 0.75, 1.0, 1.0)
	var nf := 10
	var rf := 4.2              # passe 2 : bassin gelé plus large, lisible au pied
	for k in nf:
		var a0 := TAU * k / nf
		var a1 := TAU * (k + 1) / nf
		var p0 := pied + Vector3(cos(a0) * rf * r.randf_range(0.8, 1.1), 0.03, sin(a0) * rf)
		var p1 := pied + Vector3(cos(a1) * rf, 0.03, sin(a1) * rf * r.randf_range(0.8, 1.1))
		d.facette("c_glace", pied + Vector3(0, 0.04, 0), p0, p1, pied + Vector3(0, 1, 0), [GrotteDecor.col(1.0), GrotteDecor.col(0.8), GrotteDecor.col(0.8)], true, 4.0)
	# jour bleuté qui tombe sur la cascade, lueur bleue de face
	_rideau(mur, yb, H, K, n, W0, lat_v)
	_brume_du_fond(W0, n, lat_v, yb)
	print("kit grotte : cascade %.1f m de haut, %.1f m de large au pied" % [H, 6.6 * K])
	var lj := d.lumiere(Vector3(W0.x, yb + H * 0.75, W0.z) + n * 1.5, JOUR_C, 1.8, 10.0, 1.2, false)
	lj.light_color = JOUR_C
	lj.set_meta("grappe", true)
	var lb := d.lumiere(Vector3(W0.x, yb + 2.4, W0.z) + n * 4.0, Color(0.5, 0.72, 1.0), 2.2, 9.0, 1.3, false)
	lb.light_color = Color(0.5, 0.72, 1.0)
	lb.set_meta("grappe", true)
	g.nb_lumieres += 2
	_occ.append([_xz(pied), 3.0])
	_solide(pied - Vector3(0, 0.1, 0), 1.1, 2.0)

## Passe 2 : rideau continu derrière les colonnes (plus de trous sombres : la cascade se lit comme une seule chute claire).
## Même éventail que les colonnes (étroit en haut, large en bas), cannelé un pas sur deux, plus clair vers le pied.
func _rideau(mur: Callable, yb: float, H: float, K: float, n: Vector3, W0: Vector3, lat_v: Vector3) -> void:
	var d := g.decor
	var nu := 10
	var nt := 12
	var grille: Array = []
	for i in nu + 1:
		var u_b := lerpf(-3.0, 3.0, float(i) / float(nu)) * K
		var ligne: Array = []
		for k in nt + 1:
			var t := 1.0 - float(k) / float(nt)
			var u := lerpf(u_b, u_b * 0.8, pow(t, 0.8))
			var q: Vector3 = mur.call(u, yb + H * t)
			var plan := W0 + lat_v * u + n * (0.8 + 0.35 * (1.0 - t))     # plan régulier : stries droites et nettes
			plan.y = yb + H * t
			var dq := (q - W0).dot(n)                                       # bosse de paroi qui avancerait plus loin : on la couvre
			ligne.append(plan + n * maxf(dq + 0.08 - (0.8 + 0.35 * (1.0 - t)), 0.0))
		grille.append(ligne)
	for i in nu:
		var f := 1.0 if i % 2 == 0 else 0.72      # stries verticales franches : bande claire / bande sombre (deux matières)
		var mat_s := "c_cascade_c" if i % 2 == 0 else "c_cascade"
		for k in nt:
			var t0 := 1.0 - float(k) / float(nt)
			var t1 := 1.0 - float(k + 1) / float(nt)
			var c0 := GrotteDecor.col(lerpf(0.95, 0.7, t0) * f)
			var c1 := GrotteDecor.col(lerpf(0.95, 0.7, t1) * f)
			var A: Vector3 = grille[i][k]
			var B: Vector3 = grille[i + 1][k]
			var C: Vector3 = grille[i + 1][k + 1]
			var D: Vector3 = grille[i][k + 1]
			var ref := (A + C) * 0.5 + n * 2.0
			d.facette(mat_s, A, B, C, ref, [c0, c0, c1], true, 1.0)
			d.facette(mat_s, A, C, D, ref, [c0, c1, c1], true, 1.0)

## Passe 2 : brume basse au pied de la cascade (nappes horizontales fixes, plus nombreuses vers le fond) ; rien sur la glace
## du lac, aucune animation. (La grande lueur additive de la 1re version est retirée : elle faisait de la chute un « fantôme ».)
func _brume_du_fond(W0: Vector3, n: Vector3, lat_v: Vector3, yb: float) -> void:
	# brume basse : nappes horizontales au ras de la glace et des rochers, de plus en plus nombreuses vers la cascade
	var d := g.decor
	var rb := RandomNumberGenerator.new()
	rb.seed = 61091
	for k in 9:
		var dist := rb.randf_range(1.0, 13.0)
		var o := Vector3(W0.x, yb, W0.z) + n * dist + lat_v * rb.randf_range(-7.0, 7.0)
		o.y = yb + rb.randf_range(0.25, 0.9) * (1.0 - dist / 20.0)
		var t := rb.randf_range(4.5, 7.5)
		var a := rb.randf() * TAU
		var uu := Vector3(cos(a), 0, sin(a)) * t * 0.5
		var vv := Vector3(-sin(a), 0, cos(a)) * t * 0.5
		d.quad("brume_g", o - uu - vv, o + uu - vv, o + uu + vv, o - uu + vv, Vector3.UP, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])

func _carte_brute(nom: String, v: PackedVector3Array, c: PackedColorArray, additif: bool) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additif:
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.disable_fog = true
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	sm.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = nom
	g.add_child(mi)

## Tube irrégulier le long d'une polyligne (haut -> bas), anneaux horizontaux à 6 côtés, cannelures plus sombres un côté sur deux.
func _tube(nom: String, pts: Array, rads: Array, cotes: int, ao_bas: float, ao_haut: float, pointe_bas: bool) -> void:
	var d := g.decor
	var a0 := r.randf() * TAU
	var anneaux: Array = []
	for k in pts.size():
		var ring: Array = []
		for i in cotes:
			var a := a0 + TAU * (float(i) + r.randf_range(-0.15, 0.15)) / float(cotes)
			ring.append((pts[k] as Vector3) + Vector3(cos(a), 0, sin(a)) * float(rads[k]) * r.randf_range(0.85, 1.15))
		anneaux.append(ring)
	var nk := pts.size()
	for k in nk - 1:
		var t0 := 1.0 - float(k) / float(nk - 1)
		var t1 := 1.0 - float(k + 1) / float(nk - 1)
		var ref: Vector3 = ((pts[k] as Vector3) + (pts[k + 1] as Vector3)) * 0.5
		var A: Array = anneaux[k]
		var B: Array = anneaux[k + 1]
		for i in cotes:
			var j := (i + 1) % cotes
			var f := 1.0 if i % 2 == 0 else 0.84
			var c0 := GrotteDecor.col(lerpf(ao_bas, ao_haut, t0) * f)
			var c1 := GrotteDecor.col(lerpf(ao_bas, ao_haut, t1) * f)
			d.facette(nom, A[i], A[j], B[j], ref, [c0, c0, c1], false, 1.0)
			d.facette(nom, A[i], B[j], B[i], ref, [c0, c1, c1], false, 1.0)
	var last: Array = anneaux[nk - 1]
	var pl: Vector3 = pts[nk - 1]
	var tip := pl + Vector3(0, -float(rads[nk - 1]) * (5.0 if pointe_bas else 0.6), 0)
	var cb := GrotteDecor.col(ao_bas)
	for i in cotes:
		d.facette(nom, last[i], last[(i + 1) % cotes], tip, pl + Vector3(0, 0.3, 0), [cb, cb, cb], false, 1.0)

# =================================================================== v2 : zones hors kit (entrée, boyau, mine, camp, cache…)
## Habillage ANGULAIRE des zones que le kit ne traitait pas : pans au pied des parois, blocs bas (NON solides : aucune collision de
## plus), congères et cailloux au bord du chemin, aiguilles de glace, quelques stalactites. Tout passe par `libre` (voie centrale,
## couloirs vers les accroches du jeu, réserves). `dens` : multiplicateur (le camp est plus sobre : on y combat).
func _generique(z: Dictionary) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var th := String(z.get("theme", ""))
	r.seed = int(z.get("graine", 1)) * 71 + 5
	_reserver(id)
	var L := g.longueur(id)
	var sa := maxf(s0, 0.6)
	var sb := minf(s1, L - 0.6)
	if sb - sa < 2.0:
		return
	var camp := th == "repaire"
	var dens := 0.6 if camp else 1.0
	var etais: Array = (z.get("params", {}) as Dictionary).get("etais", [])
	var sty := GrotteDecor._style_en(g, id, (sa + sb) * 0.5)
	var neige_p := 0.75 if sty == "neige" else (0.5 if (sty == "glace" or sty == "mousse") else (0.0 if camp else 0.32))
	for cote: float in [-1.0, 1.0]:
		# 1. ressauts de paroi au sol, et un étage en hauteur si la voûte le permet
		var s := sa + r.randf_range(0.0, 1.0)
		while s < sb:
			if r.randf() < dens:
				var pn := _pan(id, s, cote, 0.0, r.randf_range(0.8, 1.35), true)
				if not pn.is_empty():
					var hh := float(pn["h"]) * r.randf_range(0.7, 0.85)
					var libre_h := g.plafond_en(id, s, cote * 1.0).y - g.sol_en(id, s, 0.0).y
					if hh < libre_h - 1.6 and r.randf() < 0.6:
						var pn2 := _pan(id, s + r.randf_range(-0.3, 0.3), cote, hh, r.randf_range(0.8, 1.2), false)
						if not pn2.is_empty():
							_garnir_pan(pn2, 0.0, true)
			s += r.randf_range(1.4, 2.4)
		# 2. blocs bas au pied de la paroi (décor seul)
		s = sa + r.randf_range(0.0, 1.0)
		while s < sb:
			var m := _mur(id, s, cote, 0.5)
			if not m.is_empty() and r.randf() < dens:
				var rr := r.randf_range(0.5, 1.2)
				var lat := cote * (float(m["lat"]) - rr * 0.3)
				if libre(id, s, lat, rr, 0.6):
					_bloc(id, s, lat, rr, false)
			s += r.randf_range(0.9, 1.7)
		# 3. bord du chemin : cailloux anguleux + congères (le chemin « enneigé » se lit par ses bordures)
		s = sa + r.randf_range(0.0, 0.6)
		while s < sb:
			if g.hors_jonction(id, s):
				var dl := g.demi_l(id, s)
				var w := dl.y if cote > 0.0 else dl.x
				if r.randf() < 0.55 * dens:
					var rr := r.randf_range(0.16, 0.42)
					var lat := cote * (VOIE + rr + r.randf_range(0.05, 0.5))
					if absf(lat) < w - 0.4 and libre(id, s, lat, rr, 0.7):
						_bloc(id, s, lat, rr, false, true)
				if r.randf() < neige_p:
					var rn := r.randf_range(0.45, 1.0)
					var lat2 := cote * (VOIE + rn * 0.55 + r.randf_range(0.0, 0.7))
					if absf(lat2) < w - 0.3 and libre(id, s, lat2, rn * 0.6, 0.5):
						var q := g.sol_en(id, s, lat2)
						_add("neige_%d" % r.randi_range(0, 2), q + Vector3(0, -0.03, 0), r.randf() * TAU, Vector3(rn, rn * r.randf_range(0.8, 1.3), rn))
			s += r.randf_range(0.9, 1.8)
		# 4. aiguilles de glace contre la paroi (couloirs froids seulement)
		if sty == "neige" or sty == "glace" or sty == "strate":
			for k in int((sb - sa) * (0.06 if sty == "strate" else 0.12)):
				var s2 := r.randf_range(sa, sb)
				var m := _mur(id, s2, cote, 0.5)
				if m.is_empty():
					continue
				var lat := cote * (float(m["lat"]) - r.randf_range(0.5, 1.4))
				var h := r.randf_range(0.9, 2.2)
				if libre(id, s2, lat, h * 0.2, 0.7):
					var p := g.sol_en(id, s2, lat)
					if h > 0.72 * (g.plafond_en(id, s2, lat).y - p.y):
						continue
					_add("pic_%d" % r.randi_range(0, 2), p, r.randf() * TAU, Vector3(h * 0.8, h, h * 0.8))
					_occuper(id, s2, lat, h * 0.22)
	# 5. stalactites anguleuses (pas à travers un étai de mine)
	for k in int((sb - sa) * 0.35 * dens):
		var s3 := r.randf_range(sa, sb)
		var proche := false
		for se: float in etais:
			if absf(se - s3) < 1.1:
				proche = true
		if proche:
			continue
		var dl := g.demi_l(id, s3)
		var lat := r.randf_range(-dl.x * 0.92, dl.y * 0.92)
		_stalactite(id, s3, lat, lerpf(0.5, 2.4, pow(r.randf(), 1.4)), absf(lat) < 2.4)

# =================================================================== entrée
func habiller() -> void:
	var t0 := Time.get_ticks_msec()
	GrotteStructures.poser(self)                       # v2 : structures en bois et autel d'abord (leurs places survivent à _reserver)
	for z: Dictionary in g.def.get("zones", []):       # v2 : puis les zones hors kit (la salle du kit remet à zéro les réserves de sa branche)
		var th := String(z.get("theme", ""))
		if th == "cristaux" or (th == "lac" and String(z.get("role", "")) == "combat"):
			continue
		_generique(z)
	for z: Dictionary in g.def.get("zones", []):
		match String(z.get("theme", "")):
			"cristaux":
				_salle_cristaux(z)
			"lac":
				if String(z.get("role", "")) == "combat":
					_salle_lac(z)
	_instancier()
	print("kit grotte : %d instances, %d triangles, %d solides, %d lumières cyan, %d lanternes (%d lumières chaudes), %d ms %s" % [nb_instances, nb_triangles(), nb_solides, nb_lum, nb_lanternes, nb_lum_chaudes, Time.get_ticks_msec() - t0, stats])
