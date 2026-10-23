class_name GrotteModules
extends RefCounted
## Modules de décor du kit « grotte » : chaque ZONE de données (theme x role, voir grotte_donnees.gd) appelle `poser`, qui pose le décor
## (concrétions, étais, rails, chariots, champignons, campement, cristaux…) et réserve un passage libre. Aucun module ne contient de
## coordonnées propres à un lieu : tout vient de la zone (branche, intervalle de s, densité, params) et de sa GRAINE (RNG propre :
## même identité, détails différents d'une grotte à l'autre). Les points d'accroche du gameplay (ennemis, coffres, ressources,
## interactions) sont déclarés dans les données de la zone et créés par Grotte._accroches_zone / GrotteJeu.
##
## Thèmes : entree, boyau, carrefour, mine, lac, repaire, cristaux, cache.   Rôles : combat, repos, tresor, recit, ressources, secret,
## transition, calme, respiration.   Variantes (tirées de la graine de la zone) : nombre et position des concrétions, choix du jeu de
## décor dans la liste du thème (ex. chariot chargé de fer ou d'argent), côté du passage dans un éboulement, teinte des lumières.
## Réglages `params` reconnus : etais [s], rails [s0, s1], chariots [s], cote_baie (-1 gauche / +1 droite), passage (largeur du passage
## dans l'éboulement, m), rideau (s du portique de peaux), ilot_s / ilot_lat / ilot_r.

const FEU_C := Color(1.0, 0.56, 0.24)

## Lumières de la zone : n_lum points répartis sur l'intervalle, teinte tirée dans [couleur mini, couleur maxi].
const LUM := {
	"entree": [2.4, 12.0, 3.6], "boyau": [1.5, 6.5, 1.0], "carrefour": [1.8, 8.5, 1.8], "mine": [1.5, 7.0, 1.5],
	"lac": [1.7, 10.0, 2.2], "repaire": [2.0, 9.0, 1.8], "cristaux": [2.3, 9.0, 2.2], "cache": [1.8, 6.5, 1.5],
}

# ------------------------------------------------------------------ outils
static func _rg(z: Dictionary) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(z.get("graine", 1))
	return r

## Point du sol pour du décor : le décalage latéral est ramené à 0,6 m de la paroi au plus près (largeurs variables, pincement des jonctions).
static func _p(g: Grotte, id: String, s: float, lat: float) -> Vector3:
	var dl := g.demi_l(id, s)
	var lo := -dl.x + 0.6
	var hi := dl.y - 0.6
	if hi > lo:
		lat = clampf(lat, lo, hi)
	return g.sol_en(id, s, lat)

static func _lacet(g: Grotte, id: String, s: float) -> float:
	var T := g.tang(id, s)
	return atan2(T.x, T.z)

static func _ring_proche(g: Grotte, id: String, s: float) -> Dictionary:
	var rings: Array = (g.br[id] as Dictionary)["anneaux"]
	var best: Dictionary = rings[0]
	for r: Dictionary in rings:
		if absf(float(r["s"]) - s) < absf(float(best["s"]) - s):
			best = r
	return best

## Nom de la matière de roche d'une branche à l'abscisse s (cailloux, rochers, pointes).
static func _style(g: Grotte, id: String, s: float) -> String:
	var sty := "nu"
	for m: Array in ((g.br[id] as Dictionary)["d"] as Dictionary).get("matieres", [[999.0, "nu"]]):
		sty = String(m[1])
		if s < float(m[0]):
			break
	return sty

static func _roche(sty: String) -> String:
	match sty:
		"neige":
			return "c_roche_neige"
		"mousse":
			return "c_roche_mousse"
		"glace", "cristaux":
			return "c_roche_glace"
		"strate":
			return "c_strate_mousse"
		"camp":
			return "c_strate_suie"
	return "c_roche_nu"

static func _masque(sty: String) -> float:
	match sty:
		"neige":
			return 0.4
		"mousse", "strate":
			return 0.45
		"glace", "cristaux":
			return 0.8
	return 0.0

## Concrétion (stalagmite si h > 0, stalactite si h < 0) : profil en gouttes (bourrelets de coulée), pied évasé qui se fond dans le
## sol, légère inclinaison, 6 à 8 côtés, 4 à 11 anneaux selon la hauteur. Stalagmite : tête givrée (masque croissant vers la pointe).
static func concretion(g: Grotte, nom: String, base: Vector3, r: float, h: float, graine: int, masque := 0.0, givre_tete := 0.4) -> void:
	g.decor.objet_debut("stalagmite" if h > 0.0 else "stalactite")
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var cotes := 6 if r > 0.22 else 5
	var hh := absf(h)
	var sg := signf(h)
	var nr := clampi(int(hh / 0.5) + 3, 4, 7)
	var lean := Vector3(rg.randf_range(-1.0, 1.0), 0.0, rg.randf_range(-1.0, 1.0)) * hh * rg.randf_range(0.02, 0.08)
	var phase := rg.randf() * TAU
	var nb := rg.randf_range(2.0, 4.5)
	var a0 := rg.randf() * TAU
	var anneaux: Array = []
	var axe: Array = []
	for k in nr:
		var t := float(k) / float(nr - 1)
		var c := base + Vector3(0.0, sg * hh * t, 0.0) + lean * pow(t, 1.5)
		axe.append(c)
		if k == nr - 1:
			break
		var rad := r * pow(1.0 - t, 0.8) * (1.0 + 0.17 * sin(t * PI * nb + phase) * (1.0 - t)) * (1.0 + 0.8 * pow(1.0 - t, 8.0))
		var ring: Array = []
		for i in cotes:
			var a := a0 + TAU * (float(i) + rg.randf_range(-0.22, 0.22)) / float(cotes)
			var rr := rad * rg.randf_range(0.8, 1.16)
			ring.append(c + Vector3(cos(a) * rr, rg.randf_range(-0.3, 0.3) * hh / float(nr), sin(a) * rr))
		anneaux.append(ring)
	var tip: Vector3 = axe[nr - 1]
	for k in nr - 1:
		var t0 := float(k) / float(nr - 1)
		var t1 := float(k + 1) / float(nr - 1)
		var ao0 := lerpf(0.5, 1.0, t0) if sg > 0.0 else lerpf(0.55, 0.92, t0)
		var ao1 := lerpf(0.5, 1.0, t1) if sg > 0.0 else lerpf(0.55, 0.92, t1)
		var gv := givre_tete if sg > 0.0 else 0.0
		var c0 := GrotteDecor.col(ao0, masque + gv * t0 * t0)
		var c1 := GrotteDecor.col(ao1, masque + gv * t1 * t1)
		var ref: Vector3 = ((axe[k] as Vector3) + (axe[k + 1] as Vector3)) * 0.5
		var A: Array = anneaux[k]
		for i in cotes:
			var j := (i + 1) % cotes
			if k + 1 >= anneaux.size():
				g.decor.facette(nom, A[i], A[j], tip, ref, [c0, c0, c1], false, 2.0)
			else:
				var B: Array = anneaux[k + 1]
				g.decor.facette(nom, A[i], A[j], B[j], ref, [c0, c0, c1], false, 2.0)
				g.decor.facette(nom, A[i], B[j], B[i], ref, [c0, c1, c1], false, 2.0)
	g.decor.objet_fin()

## Pointes (stalactites au plafond ou stalagmites au sol) : n tirages, hors du passage central si `ecart` > 0. Les grandes
## stalagmites (≥ 1,1 m) sont entourées de 2 ou 3 petites et deviennent solides si elles ne gênent aucun passage ; une stalagmite
## ne dépasse pas 70 % de la hauteur libre, une stalactite au-dessus du passage s'arrête à 2,2 m du sol.
static func pointes(g: Grotte, r: RandomNumberGenerator, id: String, s0: float, s1: float, n: int, rmax: float, lmax: float, sol_: bool, ecart := 0.0, nom := "") -> void:
	for k in n:
		var s := r.randf_range(s0, s1)
		var dl := g.demi_l(id, s)
		var lat := r.randf_range(-minf(dl.x, 12.5), minf(dl.y, 12.5)) * 0.92
		if absf(lat) < ecart:
			continue
		var sty := _style(g, id, s)
		var nm := nom if nom != "" else _roche(sty)
		var m := _masque(sty)
		var pb := _p(g, id, s, lat)
		var pt := g.plafond_en(id, s, lat)
		var libre_h := pt.y - pb.y
		if sol_:
			var rr := r.randf_range(0.12, rmax) * 1.15
			var hh := r.randf_range(0.4, lmax) * r.randf_range(1.0, 1.7)
			hh = minf(hh, 0.7 * libre_h)
			rr = minf(rr, maxf(hh * 0.32, 0.1))
			if hh < 0.25:
				continue
			var gc := r.randi()
			var ok_c := g.decor.roche_libre(pb, rr * 0.8, hh)          # lot D : pas de stalagmite dans un objet ni sur une apparition
			if ok_c:
				concretion(g, nm, pb + Vector3(0, -0.06, 0), rr, hh, gc, m)
			if hh >= 1.1:
				for j in r.randi_range(2, 3):
					var a := r.randf() * TAU
					var d := rr * r.randf_range(1.4, 2.6)
					var q := g.sol_en(id, s + sin(a) * d, lat + cos(a) * d)
					if absf(q.y - pb.y) < 0.5:
						var r2 := rr * r.randf_range(0.3, 0.55)
						var h2 := hh * r.randf_range(0.2, 0.45)
						var g2 := r.randi()
						if ok_c and g.decor.roche_libre(q, r2 * 0.8, h2):
							concretion(g, nm, q + Vector3(0, -0.05, 0), r2, h2, g2, m)
				var w_c := dl.y if lat > 0.0 else dl.x
				if ok_c and rr >= 0.28 and absf(lat) > 0.62 * w_c and g.loin_du_jeu(id, s, lat, rr):     # près de la paroi seulement
					g.decor.solide_rond(pb + Vector3(0, hh * 0.35, 0), rr * 0.8, hh * 0.7)
		else:
			if g.faille_f(g.br[id], s) > 0.02:
				continue
			var hh2 := r.randf_range(0.4, lmax) * r.randf_range(1.0, 1.5)
			var bas_min := pb.y + (2.2 if absf(lat) < 1.6 else 0.6)
			hh2 = minf(hh2, pt.y + 0.12 - bas_min)
			if hh2 < 0.2:
				continue
			var rr2 := minf(r.randf_range(0.1, rmax), maxf(hh2 * 0.22, 0.06))
			concretion(g, nm, pt + Vector3(0, 0.15, 0), rr2, -hh2, r.randi(), m)
			# draperie : 2 à 4 stalactites fines alignées à côté des grandes
			if hh2 > 0.9 and r.randf() < 0.5:
				var dir := r.randf() * TAU
				for j in r.randi_range(2, 4):
					var off := (float(j) + 1.0) * rr2 * 1.3
					var q2 := g.plafond_en(id, s + sin(dir) * off, lat + cos(dir) * off)
					var lq := minf(hh2 * r.randf_range(0.35, 0.8), q2.y + 0.1 - bas_min)
					if lq > 0.15:
						concretion(g, nm, q2 + Vector3(0, 0.12, 0), rr2 * r.randf_range(0.35, 0.6), -lq, r.randi(), m)

## Nez des piliers de jonction (fourches et confluents) : une masse rocheuse irrégulière, allongée dans le pilier, du sol à la voûte.
## Le nez géométrique de la coque est une arête verticale nette (le relief y est éteint : les deux galeries sœurs s'y rejoignent) ;
## la masse la cache. Collision étroite (rayon 0,4 m) au droit du nez.
static func nez_piliers(g: Grotte) -> void:
	var vus := {}
	for id: String in g.ordre:
		var b: Dictionary = g.br[id]
		var d: Dictionary = b["d"]
		for fin in [false, true]:
			var cle := "pince_fin" if fin else "pince_deb"
			if not d.has(cle):
				continue
			var par: String = (d[cle] as Dictionary)["vers" if fin else "de"]
			var cle_v := "%s|%s" % [par, fin]
			if vus.has(cle_v):
				continue
			vus[cle_v] = true
			var pr: Dictionary = b["pr_fin"] if fin else b["pr_deb"]
			var P: Vector3 = pr["P"]
			var T: Vector3 = pr["T"]
			var sens := -1.0 if fin else 1.0                  # vers l'intérieur du pilier
			var haut: float = ((pr["pts"] as Array)[9] as Vector3).y
			var sty := _style(g, par, float(pr["s"]))
			_masse_nez(g, _roche(sty), P, T * sens, haut, hash(cle_v), _masque(sty))
			for f_nez: float in [0.5, 1.4, 2.3]:                                # lot D : rien ne se pose dans le nez du pilier (masse allongée)
				g.decor._empreinte(P + T * sens * f_nez + Vector3(0, -0.3, 0), 1.35, haut - P.y + 0.6)
			g.decor.solide_rond(P + T * sens * 0.3 + Vector3(0, 1.0, 0), 0.4, 2.0)

static func _masse_nez(g: Grotte, nom: String, P: Vector3, T: Vector3, haut: float, graine: int, masque: float) -> void:
	g.decor.objet_debut("nez")
	var rg := RandomNumberGenerator.new()
	rg.seed = graine
	var R := T.cross(Vector3.UP).normalized()
	var y0 := P.y - 0.25
	var H := haut - y0 + 0.4
	var nr := clampi(int(H / 0.45) + 2, 4, 16)
	var cotes := 9
	var anneaux: Array = []
	for k in nr:
		var t := float(k) / float(nr - 1)
		var y := y0 + H * t
		var lat := 0.55 + 0.25 * sin(t * 7.0 + rg.randf()) + 0.35 * pow(absf(2.0 * t - 1.0), 3.0)    # étranglement au milieu, évasé en haut et en bas
		var lon := 1.5
		var c := P + T * (lon * 0.62) + Vector3(0, y - P.y, 0)
		var ring: Array = []
		for i in cotes:
			var a := TAU * (float(i) + rg.randf_range(-0.2, 0.2)) / float(cotes)
			var jr := rg.randf_range(0.8, 1.2)
			ring.append(c + T * cos(a) * lon * jr + R * sin(a) * lat * jr + Vector3(0, rg.randf_range(-0.1, 0.1), 0))
		anneaux.append(ring)
	for k in nr - 1:
		var t0 := float(k) / float(nr - 1)
		var t1 := float(k + 1) / float(nr - 1)
		var c0 := GrotteDecor.col(lerpf(0.55, 0.95, sin(t0 * PI)), masque)
		var c1 := GrotteDecor.col(lerpf(0.55, 0.95, sin(t1 * PI)), masque)
		var A: Array = anneaux[k]
		var B: Array = anneaux[k + 1]
		var ref := P + T * 0.93 + Vector3(0, y0 + H * (t0 + t1) * 0.5 - P.y, 0)
		for i in cotes:
			var j := (i + 1) % cotes
			g.decor.facette(nom, A[i], A[j], B[j], ref, [c0, c0, c1], false, 2.0)
			g.decor.facette(nom, A[i], B[j], B[i], ref, [c0, c1, c1], false, 2.0)
	g.decor.objet_fin()

## Éboulis au pied des parois : amas de 3 à 7 blocs anguleux, en partie enterrés, contre la paroi (sans collision : on les longe).
static func eboulis_pied(g: Grotte, r: RandomNumberGenerator, id: String, s0: float, s1: float, n: int, nom := "") -> void:
	for k in n:
		var s := r.randf_range(s0 + 0.5, s1 - 0.5)
		if not g.hors_jonction(id, s):
			continue
		var cote := 1.0 if r.randf() < 0.5 else -1.0
		var dl := g.demi_l(id, s)
		var w := dl.y if cote > 0.0 else dl.x
		if w < 1.6:
			continue
		var sty := _style(g, id, s)
		var nm := nom if nom != "" else _roche(sty)
		var m := _masque(sty)
		for j in r.randi_range(3, 7):
			var sj := s + r.randf_range(-0.9, 0.9)
			var lj := cote * w * r.randf_range(0.78, 0.97)
			var q := g.sol_en(id, clampf(sj, 0.3, g.longueur(id) - 0.3), lj)
			var rb := r.randf_range(0.09, 0.42) * (1.0 if j > 0 else 1.4)
			g.decor.rocher(nm, q + Vector3(0, -rb * 0.25, 0), rb, rb * r.randf_range(0.6, 1.05), r.randi(), m * 0.9 + 0.1, false, r.randi_range(4, 6))

## Gros blocs tombés de la voûte (repères), solides quand ils ne gênent aucun passage.
static func blocs(g: Grotte, r: RandomNumberGenerator, id: String, s0: float, s1: float, n: int, rmin: float, rmax: float, nom := "") -> void:
	for k in n:
		var s := r.randf_range(s0 + 1.0, s1 - 1.0)
		if not g.hors_jonction(id, s):
			continue
		var dl := g.demi_l(id, s)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := dl.y if cote > 0.0 else dl.x
		if w < 2.4:
			continue
		var lat := cote * w * r.randf_range(0.45, 0.75)
		var rb := r.randf_range(rmin, rmax)
		var hb := rb * r.randf_range(0.7, 1.1)
		var sty := _style(g, id, s)
		var solide := g.loin_du_jeu(id, s, lat, rb * 0.8)
		g.decor.rocher(nom if nom != "" else _roche(sty), _p(g, id, s, lat) + Vector3(0, -0.1, 0), rb, hb, r.randi(), _masque(sty) + 0.15, solide and hb >= 0.55, 5)
		for j in r.randi_range(1, 3):                    # éclats autour
			var a := r.randf() * TAU
			var q := g.sol_en(id, s + sin(a) * rb * 1.5, lat + cos(a) * rb * 1.5)
			g.decor.rocher(nom if nom != "" else _roche(sty), q + Vector3(0, -0.05, 0), rb * r.randf_range(0.2, 0.4), rb * r.randf_range(0.15, 0.35), r.randi(), _masque(sty), false, 5)

## Rochers contre les parois (collision pour les plus gros).
static func rochers(g: Grotte, r: RandomNumberGenerator, id: String, s0: float, s1: float, n: int, rmin: float, rmax: float, collision := true, nom := "") -> void:
	for k in n:
		var s := r.randf_range(s0, s1)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var dl := g.demi_l(id, s)
		var w := dl.y if cote > 0.0 else dl.x
		var sty := _style(g, id, s)
		var rr := r.randf_range(rmin, rmax)
		var hh := rr * r.randf_range(0.8, 1.1)
		var lat_r := cote * minf(w, 12.0) * r.randf_range(0.55, 0.88)
		var solide := collision and hh >= 0.55 and g.loin_du_jeu(id, s, lat_r, rr * 0.8)
		g.decor.rocher(nom if nom != "" else _roche(sty), _p(g, id, s, lat_r), rr, hh, r.randi(), _masque(sty), solide, 6)

static func etai(g: Grotte, id: String, s: float) -> void:
	g.decor.objet_debut("etai")
	var dl := g.demi_l(id, s)
	var w1 := dl.x - 0.25
	var w2 := dl.y - 0.25
	var h := Grotte._interp((g.br[id] as Dictionary)["profil"], s, 4)
	var d := g.decor
	var pa: Vector3 = d.pose_objet(_p(g, id, s, -w1), 0.24, 0.24, 0.0, 2.4, GrotteDecor.PLANTE, 0.4)["p"]     # lot D : poteaux hors de la paroi
	var pb: Vector3 = d.pose_objet(_p(g, id, s, w2), 0.24, 0.24, 0.0, 2.4, GrotteDecor.PLANTE, 0.4)["p"]
	var R := g.droite(id, s)
	var haut := minf(pa.y, pb.y) + h - 0.55
	d.prisme("bois", pa + Vector3(0, -0.1, 0), pa + Vector3(0, haut - pa.y, 0), 0.15, 8)
	d.prisme("bois", pb + Vector3(0, -0.1, 0), pb + Vector3(0, haut - pb.y, 0), 0.15, 8)
	d.prisme("bois", pa + Vector3(0, haut - pa.y, 0) - R * 0.3, pb + Vector3(0, haut - pb.y, 0) + R * 0.3, 0.17, 8)
	d.solide_rond(pa + Vector3(0, 1.0, 0), 0.15, 2.4)
	d.solide_rond(pb + Vector3(0, 1.0, 0), 0.15, 2.4)
	d._empreinte(pa, 0.25, 2.4)
	d._empreinte(pb, 0.25, 2.4)
	g.decor.objet_fin()

## Rails de mine (deux fers + traverses) le long de la branche, à `lat0` de l'axe ; sans collision (on marche dessus).
static func rails(g: Grotte, id: String, s0: float, s1: float, lat0: float) -> void:
	var s := s0
	while s < s1 - 0.7:
		var s2 := minf(s + 1.2, s1)
		var T := g.tang(id, s + 0.6)
		var R := g.droite(id, s + 0.6)
		for dl: float in [-0.45, 0.45]:
			var a := _p(g, id, s, lat0 + dl) + Vector3(0, 0.07, 0)
			var b := _p(g, id, s2, lat0 + dl) + Vector3(0, 0.07, 0)
			g.decor.prisme("fer", a, b, 0.03, 4)
		var m := _p(g, id, s + 0.6, lat0) + Vector3(0, 0.03, 0)
		g.decor.boite("bois", m, Vector3(1.15, 0.06, 0.15), atan2(T.x, T.z))
		R = R
		s = s2

static func chariot(g: Grotte, id: String, s: float, lat: float, r: RandomNumberGenerator, charge := 0) -> void:
	g.decor.objet_debut("chariot")
	var dl := g.demi_l(id, s)
	if absf(lat) > (dl.y if lat > 0.0 else dl.x) - 1.3:          # trop près de la paroi (variante étroite) : le chariot se range au pied de la paroi, sans bloquer
		lat = signf(lat) * ((dl.y if lat > 0.0 else dl.x) - 1.3)
	var T := g.tang(id, s)
	var R := g.droite(id, s)
	var lac := atan2(T.x, T.z)
	var d := g.decor
	var pz := d.pose_objet(_p(g, id, s, lat), 0.55, 0.85, lac, 1.1, GrotteDecor.INCLINE)       # lot D : collé au sol, incliné sur la pente
	var p: Vector3 = pz["p"]
	var x0 := d._incliner(pz)
	d._prof_pose += 1
	d.boite("bois", p + Vector3(0, 0.55, 0), Vector3(0.95, 0.5, 1.5), lac)
	for dz: float in [-0.62, 0.62]:
		d.boite("fer", p + T * dz + Vector3(0, 0.55, 0), Vector3(1.0, 0.55, 0.05), lac)
	d.boite("fer", p + Vector3(0, 0.82, 0), Vector3(1.0, 0.04, 1.56), lac)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var c := p + R * sx + T * sz + Vector3(0, 0.2, 0)
			d.prisme("fer", c - R * 0.05, c + R * 0.05, 0.2, 8)
	# chargement : fer ou argent selon la variante, ou vide
	if charge == 1:
		d.rocher("c_strate_suie", p + Vector3(0, 0.78, 0), 0.5, 0.32, r.randi(), 0.0, false, 6)
		d.boite("fer", p + Vector3(0.1, 1.05, 0.1), Vector3(0.28, 0.12, 0.22), r.randf() * TAU)
	elif charge == 2:
		d.rocher("c_roche_nu", p + Vector3(0, 0.78, 0), 0.5, 0.3, r.randi(), 0.0, false, 6)
		d.boite("lame", p + Vector3(-0.1, 1.0, -0.05), Vector3(0.3, 0.08, 0.22), r.randf() * TAU)
	d.solide_rond(p + Vector3(0, 0.55, 0), 0.62, 1.1)
	d.xf = x0
	d._prof_pose -= 1
	d._empreinte(p, 0.75, 1.1)
	g.decor.objet_fin()

## Champignons lumineux : n pieds de hauteurs variées, chapeaux émissifs (matière cristal), sans collision.
static func champignons(g: Grotte, r: RandomNumberGenerator, p: Vector3, n: int) -> void:
	g.decor.objet_debut("champignons")
	for k in n:
		var q := p + Vector3(r.randf_range(-0.45, 0.45), 0.0, r.randf_range(-0.45, 0.45))
		var saute := false
		if g.decor.regles_pose:                          # lot D : chaque pied sur le sol (ni dans la roche, ni en l'air au bord d'une dalle)
			var yq := g.sol_objet(q.x, q.z, q.y + 0.35)
			saute = yq < q.y - 0.25
			if yq > -1e8:
				q.y = yq - 0.01
		var hs := r.randf_range(0.14, 0.4)
		var rc := r.randf_range(0.08, 0.17)
		var gq := r.randi()
		if saute:
			continue
		g.decor.tour("os", q, [Vector2(0.03, 0.0), Vector2(0.022, hs)], 5, 0.0, false)
		g.decor.revolution("c_cristal", q + Vector3(0, hs, 0), [Vector2(rc, 0.0), Vector2(rc * 1.05, 0.03), Vector2(rc * 0.7, 0.07), Vector2(0.0, 0.095)], 7, gq, 0.2, 0.0, 0.85, 1.0, 1.0)
	g.decor.objet_fin()

## Amas de cristaux de glace.
static func cristaux(g: Grotte, r: RandomNumberGenerator, p: Vector3, n: int, taille := 1.0) -> void:
	g.decor.objet_debut("cristaux")
	for j in n:
		var q := p + Vector3(r.randf_range(-0.5, 0.5), -0.08, r.randf_range(-0.5, 0.5))
		if g.decor.regles_pose:                          # lot D : pied de la grappe sur le sol (enfoncé de 8 cm, pas plus)
			var yq := g.sol_objet(q.x, q.z, q.y + 0.43)
			if yq > -1e8:
				q.y = yq - 0.08
		g.decor.cristal(q, r.randf_range(0.1, 0.3) * taille, r.randf_range(0.7, 2.2) * taille, r.randi(), 0.6)
	g.decor.objet_fin()

# ------------------------------------------------------------------ props des points d'accroche
static func prop_ressource(g: Grotte, res: Dictionary, p: Vector3, z: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(String(res["id"])) + int(z.get("graine", 0))
	match String(res["genre"]):
		"minerai_fer":
			g.decor.rocher("c_strate_suie", p, 0.55, 0.6, r.randi(), 0.0, false, 6)
			for k in 3:
				g.decor.boite("fer", p + Vector3(r.randf_range(-0.3, 0.3), r.randf_range(0.25, 0.7), r.randf_range(-0.3, 0.3)), Vector3(0.22, 0.1, 0.16), r.randf() * TAU)
		"minerai_argent":
			g.decor.rocher("c_roche_nu", p, 0.55, 0.6, r.randi(), 0.0, false, 6)
			for k in 4:
				g.decor.boite("lame", p + Vector3(r.randf_range(-0.3, 0.3), r.randf_range(0.2, 0.7), r.randf_range(-0.3, 0.3)), Vector3(0.2, 0.06, 0.14), r.randf() * TAU)
		"cristal_givre":
			cristaux(g, r, p, 4, 0.8)
		"champignon_lumineux":
			champignons(g, r, p, 4)

static func prop_interaction(g: Grotte, it: Dictionary, p: Vector3, z: Dictionary) -> void:
	var d := g.decor
	match String(it.get("prop", "")):
		"journal":
			d.os_tas(p + Vector3(-0.7, 0, 0.4), 4, 0.5)
			d.sac(p + Vector3(0.8, 0, -0.3), 1.0)
			d.sac(p + Vector3(1.2, 0, 0.3), 0.8)
			d.arme(p + Vector3(-0.2, 0.02, -0.9), 2.2)
			d.rocher("c_roche_glace", p + Vector3(0, -0.02, 0), 0.4, 0.34, 777, 0.7, false, 6)
			d.boite("parchemin", p + Vector3(0, 0.34, 0), Vector3(0.3, 0.025, 0.22), 0.4)
			d.bougie(p + Vector3(0.35, 0.3, 0.1))
		"registre":
			d.table(p + Vector3(0, 0, 0), 0.2)
			d.boite("parchemin", p + Vector3(0.0, 0.82, 0.0), Vector3(0.32, 0.04, 0.24), 0.5)
			d.tabouret(p + Vector3(0.0, 0, 0.9))
			d.solide(p + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8))

# ------------------------------------------------------------------ dispatch
static func poser(g: Grotte, z: Dictionary) -> void:
	var r := _rg(z)
	g.decor.rng.seed = int(z.get("graine", 1))
	var theme: String = z.get("theme", "")
	var role: String = z.get("role", "")
	match theme:
		"entree":
			_entree(g, z, r)
		"boyau":
			_boyau(g, z, r)
		"carrefour":
			_carrefour(g, z, r)
		"mine":
			_mine(g, z, r, role)
		"lac":
			_lac(g, z, r, role)
		"repaire":
			_repaire(g, z, r, role)
		"cristaux":
			_cristaux(g, z, r)
		"cache":
			_cache(g, z, r)
	_relief_zone(g, z)

## Relief commun à toutes les zones (RNG à part : le décor des thèmes ne bouge pas) : éboulis au pied des parois, gros blocs dans les
## salles larges, colonnes dans les grandes salles, stalactites fines supplémentaires (la voûte n'est jamais nue).
static func _relief_zone(g: Grotte, z: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(z.get("graine", 1)) * 31 + 7
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var lg := s1 - s0
	var dens: float = float(z.get("densite", 1.0))
	var theme: String = z.get("theme", "")
	var role: String = z.get("role", "")
	var camp := theme == "repaire" and role != "transition"
	var kit := GrotteKit.actif() and (theme == "cristaux" or theme == "lac" and role == "combat")   # blocs et colonnes : pièces du kit
	eboulis_pied(g, r, id, s0, s1, int(lg * (0.25 if camp else 0.45) * dens))
	if kit:
		pointes(g, r, id, s0, s1, int(lg * 0.4 * dens), 0.16, 1.1, false)
		return
	if not camp and theme != "cache":
		blocs(g, r, id, s0, s1, int(lg * 0.08 * dens), 0.5, 1.0)
	pointes(g, r, id, s0, s1, int(lg * 0.7 * dens), 0.16, 1.1, false)
	if theme == "mine" and role == "ressources" or theme == "cristaux" or theme == "carrefour":
		for k in (2 if theme != "carrefour" else 1):
			var s := r.randf_range(s0 + 2.0, s1 - 2.0)
			var dl := g.demi_l(id, s)
			var cote := 1.0 if k % 2 == 0 else -1.0
			var lat := cote * (dl.y if cote > 0.0 else dl.x) * r.randf_range(0.62, 0.78)
			var rc := r.randf_range(0.45, 0.65)
			if not g.loin_du_jeu(id, s, lat, rc * 1.8) or (dl.y if cote > 0.0 else dl.x) < 3.5:
				continue
			var pb := _p(g, id, s, lat)
			var pt := g.plafond_en(id, s, lat)
			var sty := _style(g, id, s)
			g.decor.colonne(_roche(sty), pb.x, pb.z, pb.y - 0.2, pt.y + 0.1, rc, r.randi(), _masque(sty) + 0.2)

static func lumieres(g: Grotte, z: Dictionary) -> void:
	var n: int = int(z.get("n_lum", 0))
	if n <= 0 or GrotteKit.actif() and z.get("theme", "") == "cristaux":     # kit : 4 lumières cyan, portées par ses grandes grappes
		return
	var r := _rg(z)
	r.randf()
	var id: String = z["branche"]
	var teinte: Array = z.get("teinte", [Color(0.6, 0.8, 1.0), Color(0.6, 0.8, 1.0)])
	var cfg: Array = LUM.get(z.get("theme", ""), [1.6, 8.0, 1.6])
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	for k in n:
		var s := lerpf(s0, s1, (float(k) + 0.5) / float(n))
		var lat := 0.5 * (1.0 if k % 2 == 0 else -1.0)
		var col: Color = (teinte[0] as Color).lerp(teinte[1], r.randf())
		var chaud := col.r > 0.9 and col.b < 0.5
		g._l(id, s, lat, float(cfg[2]), col, float(cfg[0]) * r.randf_range(0.9, 1.1), float(cfg[1]) * r.randf_range(0.92, 1.08), 1.5, chaud)

# ------------------------------------------------------------------ entrée, boyau, carrefour
static func _entree(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var d := g.decor
	# congères et rochers enneigés contre les parois (macro), glaçons à la bouche (méso), marqueur des bandits (micro)
	for k in int(9.0 * dens):
		var s := r.randf_range(s0 + 1.0, s1 + 1.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var dl := g.demi_l(id, s)
		var lat_c := cote * (dl.y if cote > 0 else dl.x) * r.randf_range(0.5, 0.85)
		var r_c := r.randf_range(1.3, 2.6)
		var h_c := r.randf_range(0.25, 0.5)
		var gr_c := r.randi()
		var pc := _p(g, id, s, lat_c)
		if d.pres_apparition(pc, r_c * 0.75 + 0.45):     # lot D : pas de congère sous les pieds d'un ennemi qui apparaît
			continue
		d.congere(pc, r_c, h_c, gr_c)
	rochers(g, r, id, s0 + 2.0, s1 - 1.0, int(5.0 * dens), 0.6, 1.2, true, "c_roche_neige")
	pointes(g, r, id, 5.0, 11.0, int(12.0 * dens), 0.2, 1.6, false, 0.0, "c_roche_glace")
	pointes(g, r, id, 12.0, s1, 3, 0.18, 0.8, false)
	d.trophee(_p(g, id, 13.0, -2.2), 1.7, 0.4)
	d.os_tas(_p(g, id, 12.6, 1.4), 3, 0.5)
	d.arme(_p(g, id, 11.0, 1.9) + Vector3(0, 0.02, 0), 0.8)
	d.caisse(_p(g, id, 9.5, -2.6), Vector3(0.8, 0.55, 0.55), 0.5)
	# poste du guetteur : table, tabouret, bougie (contre la paroi droite)
	var tp: Vector3 = d.pose_objet(_p(g, id, 10.0, 2.5), 0.55, 0.33, 0.3, 0.8, GrotteDecor.DROIT)["p"]
	d.table(tp, 0.3)
	d.tabouret(tp + Vector3(-0.7, 0, 0.6))
	d.bougie(tp + Vector3(0.3, 0.8, 0.05))
	d.solide(tp + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8))

static func _boyau(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var d := g.decor
	pointes(g, r, id, s0 + 0.5, s1, int(22.0 * dens), 0.16, 0.9, false, 0.0, "c_roche_nu")
	pointes(g, r, id, s0 + 1.0, s1, int(12.0 * dens), 0.14, 0.5, true, 0.7, "c_roche_mousse")
	rochers(g, r, id, s0 + 1.0, s1 - 1.0, int(5.0 * dens), 0.3, 0.55, false, "c_roche_mousse")
	d.os_tas(_p(g, id, s0 + r.randf_range(8.0, 12.0), 0.3), 5, 0.5)
	d.arme(_p(g, id, s0 + r.randf_range(2.0, 4.0), -0.6), r.randf() * TAU)
	d.caisse(_p(g, id, s1 - 1.5, 1.1), Vector3(0.6, 0.42, 0.45), 0.2)

static func _carrefour(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var d := g.decor
	pointes(g, r, id, s0, s1, 8, 0.25, 1.2, false)
	pointes(g, r, id, s0, s1, 4, 0.2, 0.7, true, 1.8)
	# foyer éteint (halte) contre la paroi gauche, deux torches aux murs, deux poteaux indicateurs (mine à droite, lac à gauche)
	var f := _p(g, id, s0 + 2.0, -2.8)
	for k in 7:
		var a := TAU * k / 7.0
		d.rocher("c_roche_nu", f + Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55), 0.17, 0.16, r.randi(), 0.2, false, 5)
	for k in 3:
		var a := 0.5 + k * 2.1
		d.prisme("fer", f + Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3), f + Vector3(-cos(a) * 0.28, 0.15, -sin(a) * 0.28), 0.05, 5)
	d.os_tas(f + Vector3(0.8, 0, 0.5), 3, 0.3)
	for sg: float in [-1.0, 1.0]:
		var p := g.mur_en(id, s0 + 1.4, sg)
		d.applique(p, -g.droite(id, s0 + 1.4) * sg, _p(g, id, s0 + 1.4, sg * 3.0).y + 2.0, 5.0, 1.7, true)
		var pp := _p(g, id, s1 - 1.2, sg * (g.demi_l(id, s1 - 1.2).y - 1.1))
		d.prisme("bois", pp + Vector3(0, -0.1, 0), pp + Vector3(0, 2.0, 0), 0.06, 5)
		var lac := _lacet(g, id, s1 - 1.2) + sg * 0.5
		d.boite("bois", pp + Vector3(0, 1.8, 0) + g.droite(id, s1 - 1.2) * sg * 0.28, Vector3(0.7, 0.2, 0.04), lac)
		d.solide_rond(pp + Vector3(0, 1.0, 0), 0.08, 2.0)
		if sg > 0.0:
			d.arme(pp + Vector3(0.5, 0.02, 0.3), 1.0)         # pioche rouillée : la mine
		else:
			d.crane(pp + Vector3(0.4, 0.0, 0.2), 0.5)

# ------------------------------------------------------------------ vieille mine
static func _mine(g: Grotte, z: Dictionary, r: RandomNumberGenerator, role: String) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var p: Dictionary = z.get("params", {})
	var d := g.decor
	var n_len := int(s1 - s0)
	pointes(g, r, id, s0, s1, int(float(n_len) * 1.2 * dens), 0.2, 1.0, false)
	pointes(g, r, id, s0 + 0.5, s1, int(float(n_len) * 0.6 * dens), 0.2, 0.8, true, 1.0)
	rochers(g, r, id, s0 + 1.0, s1 - 1.0, int(float(n_len) * 0.4 * dens), 0.35, 0.8, true)
	for s: float in p.get("etais", []):
		if g.hors_jonction(id, s):
			etai(g, id, s)
	var rl: Array = p.get("rails", [])
	var lat_rail := 1.1 * (1.0 if r.randf() < 0.5 else -1.0)
	if rl.size() >= 2:
		rails(g, id, float(rl[0]), float(rl[1]), lat_rail)
	_parois_mine(g, z)
	var charge := r.randi() % 3
	for s: float in p.get("chariots", []):
		if g.libre(id, s, lat_rail, 0.5):
			chariot(g, id, s, lat_rail, r, charge)
	match role:
		"combat":
			d.os_tas(_p(g, id, s0 + 5.0, -1.0), 3, 0.5)
			d.crane(_p(g, id, s0 + 5.3, -0.6), 1.0)
			d.arme(_p(g, id, s0 + 5.6, 0.3), 3.6)
			var tn := _p(g, id, s1 - 4.5, -2.1)
			d.tonneau(tn, 1.0)
			d.solide_rond(tn + Vector3(0, 0.5, 0), 0.38, 1.0)
			d.caisse(_p(g, id, s0 + 11.0, 2.3), Vector3(0.8, 0.5, 0.5), 0.15)
		"ressources":
			# poste des mineurs-bandits : table, tabourets, lit de camp, caisses, sacs de minerai, râtelier de pioches
			var tb: Vector3 = d.pose_objet(_p(g, id, s0 + 4.0, -1.2), 0.55, 0.33, 0.4, 0.8, GrotteDecor.DROIT)["p"]
			d.table(tb, 0.4)
			d.tabouret(tb + Vector3(-0.8, 0, 0.6))
			d.tabouret(tb + Vector3(0.8, 0, -0.5))
			d.bougie(tb + Vector3(0.0, 0.8, 0.0))
			d.solide(tb + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8))
			d.couchage(_p(g, id, s0 + 15.5, -4.6), 1.57, r.randf() < 0.5)
			d.ratelier(_p(g, id, s0 + 9.0, 5.6), -PI * 0.5)
			var base := _p(g, id, s1 - 4.0, 4.4)
			d.caisse(base, Vector3(0.9, 0.6, 0.6), 0.1)
			d.caisse(base + Vector3(1.0, 0, 0.1), Vector3(0.7, 0.5, 0.5), -0.2)
			d.caisse(base + Vector3(0.1, 0.6, 0), Vector3(0.7, 0.5, 0.5), 0.35)
			for k in 4:
				d.sac(_p(g, id, s0 + 2.0 + k * 3.0, 5.3 - float(k % 2) * 0.4), r.randf_range(0.9, 1.3))
			d.tonneau(_p(g, id, s1 - 2.2, -5.2), 1.0)
			d.solide_rond(_p(g, id, s1 - 2.2, -5.2) + Vector3(0, 0.5, 0), 0.38, 1.0)
			rails(g, id, s0 + 1.0, s1 - 1.0, lat_rail)
			chariot(g, id, s0 + 7.0, lat_rail, r, 1)
			chariot(g, id, s0 + 13.0, lat_rail, r, 2)
		"secret":
			_eboulis(g, z, r)
		"repos":
			d.os_tas(_p(g, id, s0 + 3.0, 1.4), 3, 0.4)
			if g.libre(id, s0 + 5.5, -2.0, 0.4):
				d.tonneau(_p(g, id, s0 + 5.5, -2.0), 1.0)
				d.solide_rond(_p(g, id, s0 + 5.5, -2.0) + Vector3(0, 0.5, 0), 0.38, 1.0)
		"recit":
			d.os_tas(_p(g, id, s0 + 9.0, -1.0), 3, 0.5)
			d.crane(_p(g, id, s0 + 9.3, -0.6), 1.0)
			d.arme(_p(g, id, s0 + 9.6, 0.3), 3.6)
			d.caisse(_p(g, id, s0 + 15.0, 2.1), Vector3(0.8, 0.5, 0.5), 0.15)
			d.caisse(_p(g, id, s0 + 15.8, 2.2), Vector3(0.6, 0.42, 0.45), 0.5)

## Éboulement : un mur de blocs ferme la baie latérale, avec un passage (variante : position) ; arêtes de blocs au bord du couloir.
static func _eboulis(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var p: Dictionary = z.get("params", {})
	var cote := float(p.get("cote_baie", -1))
	var passage := float(p.get("passage", 1.5))
	var d := g.decor
	var s_gap := r.randf_range(s0 + 4.5, s1 - 4.5)
	var s := s0 + 1.5
	while s < s1 - 1.0:
		var dl := g.demi_l(id, s)
		var w_baie := (dl.y if cote > 0.0 else dl.x)
		if absf(s - s_gap) >= passage * 0.5 + 0.75:
			var lat := cote * 2.3
			var rr := r.randf_range(0.82, 1.0)
			d.rocher("c_roche_nu", _p(g, id, s, lat), rr, rr * 1.1, r.randi(), 0.0, true, 6)
			d.rocher("c_roche_nu", _p(g, id, s + 0.5, lat + cote * 0.4) + Vector3(0, 0.7, 0), rr * 0.7, rr * 0.8, r.randi(), 0.0, false, 6)
		# amas de gravats dans la baie (derrière le mur)
		if r.randf() < 0.6:
			d.rocher("c_roche_nu", _p(g, id, s, cote * r.randf_range(3.2, maxf(w_baie - 0.8, 3.4))), r.randf_range(0.3, 0.6), r.randf_range(0.25, 0.5), r.randi(), 0.0, false, 5)
		s += 1.15
	# poutres brisées et blocs tombés au bord du couloir
	for k in 4:
		var sb := r.randf_range(s0 + 1.0, s1 - 1.0)
		var a := _p(g, id, sb, -cote * 2.2) + Vector3(0, 0.15, 0)
		d.prisme("bois", a, a + g.tang(id, sb) * r.randf_range(1.0, 1.8) + Vector3(0, r.randf_range(0.3, 1.0), 0), 0.13, 6)
	for k in 3:
		var sb := r.randf_range(s0 + 1.0, s1 - 1.0)
		d.rocher("c_roche_nu", _p(g, id, sb, -cote * r.randf_range(2.2, 2.8)), r.randf_range(0.35, 0.55), r.randf_range(0.3, 0.5), r.randi(), 0.0, false, 5)
	d.os_tas(_p(g, id, s_gap, cote * 3.4), 4, 0.5)       # le passage est discrètement signalé par des os

# ------------------------------------------------------------------ caverne du lac
static func _lac(g: Grotte, z: Dictionary, r: RandomNumberGenerator, role: String) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var d := g.decor
	var p: Dictionary = z.get("params", {})
	match role:
		"transition":
			pointes(g, r, id, s0 + 0.5, s1, int(14.0 * dens), 0.16, 0.9, false, 0.0, "c_roche_mousse")
			pointes(g, r, id, s0 + 1.0, s1, int(8.0 * dens), 0.14, 0.5, true, 0.8, "c_roche_mousse")
			rochers(g, r, id, s0 + 1.0, s1 - 1.0, int(5.0 * dens), 0.3, 0.55, false, "c_roche_mousse")
			for k in int(5.0 * dens):                  # champignons au pied des parois
				var s := r.randf_range(s0 + 1.0, s1 - 1.0)
				var cote := 1.0 if k % 2 == 0 else -1.0
				var dl := g.demi_l(id, s)
				champignons(g, r, _p(g, id, s, cote * (dl.y if cote > 0 else dl.x) * 0.8), r.randi_range(2, 4))
		"combat" when GrotteKit.actif():
			# kit : forêt, blocs, terrasses, cristaux et cascade sont des pièces du kit (GrotteKit._salle_lac) ; restent les accessoires
			d.os_tas(_p(g, id, s0 + 7.0, 2.0), 4, 0.6)
			d.arme(_p(g, id, s0 + 13.0, 1.6), 4.0)
			d.caisse(_p(g, id, s0 + 1.5, 2.4), Vector3(0.7, 0.5, 0.5), 0.9)
			_faille(g, id)
		"combat":
			# colonnes (repères) entre la glace et le plafond, du côté du lac
			for c in [[0.1, -6.5, 0.8], [0.32, -11.0, 1.0], [0.62, -9.0, 0.9], [0.86, -5.8, 0.75]]:
				var s: float = lerpf(s0, s1, float(c[0])) + r.randf_range(-1.0, 1.0)
				var lat: float = float(c[1]) * r.randf_range(0.9, 1.1)
				if not g.loin_du_jeu(id, s, lat, 1.0):
					continue
				var pb := _p(g, id, s, lat)
				var pt := g.plafond_en(id, s, lat)
				d.colonne("c_roche_glace", pb.x, pb.z, pb.y - 0.2, pt.y + 0.1, float(c[2]), r.randi(), 0.7)
			pointes(g, r, id, s0, s1, int(34.0 * dens), 0.5, 2.8, false, 0.0, "c_roche_glace")
			pointes(g, r, id, s0 + 0.5, s1, int(30.0 * dens), 0.4, 1.9, true, 1.4, "c_roche_glace")
			for k in int(12.0 * dens):                       # blocs sur la glace et le rivage
				var s := r.randf_range(s0 + 1.0, s1 - 4.0)
				var lat := r.randf_range(-12.0, 3.0)
				if absf(lat) < 1.4:
					continue
				var rb := r.randf_range(0.5, 1.3)
				var hb := rb * r.randf_range(0.8, 1.2)
				d.rocher("c_roche_glace", _p(g, id, s, lat), rb, hb, r.randi(), 0.7, hb >= 0.55 and g.loin_du_jeu(id, s, lat, rb * 0.8), 6)
			for c in [[0.06, -3.5], [0.4, -4.4], [0.55, -3.0], [0.2, -9.0], [0.48, -8.0]]:     # cristaux au bord du lac
				var q := _p(g, id, lerpf(s0, s1, float(c[0])) + r.randf_range(-1.0, 1.0), float(c[1]))
				cristaux(g, r, q, 4, 0.7)
			d.os_tas(_p(g, id, s0 + 7.0, 2.0), 4, 0.6)
			d.arme(_p(g, id, s0 + 13.0, 1.6), 4.0)
			d.caisse(_p(g, id, s0 + 1.5, 2.4), Vector3(0.7, 0.5, 0.5), 0.9)
			for k in int(6.0 * dens):                        # champignons sur la corniche et le rivage
				var s := r.randf_range(s0 + 2.0, s1 - 6.0)
				champignons(g, r, _p(g, id, s, r.randf_range(3.0, 6.0)), 3)
			_foret_lac(g, z)
			_faille(g, id)
		"recit":
			var sl: float = float(p.get("ilot_s", (s0 + s1) * 0.5))
			var la: float = float(p.get("ilot_lat", -9.0))
			var rr: float = float(p.get("ilot_r", 3.0))
			g.ilot(id, sl, la, rr, 0.55)
			var c := _p(g, id, sl, la)
			var top := c.y + 0.55
			for k in 3:                                      # les restes de l'expédition : os, sacs, outils, couchage de fortune
				var a := TAU * (float(k) + r.randf()) / 3.0
				var q := Vector3(c.x + cos(a) * rr * 0.55, top, c.z + sin(a) * rr * 0.55)
				d.os_tas(q, 4, 0.4)
				d.sac(q + Vector3(0.5, 0, 0.3), 1.0)
			d.arme(Vector3(c.x + 0.8, top + 0.02, c.z - 1.0), r.randf() * TAU)
			d.arme(Vector3(c.x - 1.1, top + 0.02, c.z + 0.6), r.randf() * TAU)
			d.couchage(Vector3(c.x - 1.4, top, c.z - 1.3), 0.7, false)
			for k in 5:
				cristaux(g, r, _p(g, id, sl + r.randf_range(-4.0, 4.0), la + r.randf_range(-4.0, 4.0)), 3, 0.5)


## Faille du plafond : lumière du jour, flaque, projecteur étroit.
static func _faille(g: Grotte, id: String) -> void:
	var d := g.decor
	if not g.br[id]["d"].has("faille"):
		return
	var fa: Array = g.br[id]["d"]["faille"]
	var s_f := (float(fa[1]) + float(fa[2])) * 0.5
	var haut_f := g.plafond_en(id, s_f, 2.0)
	var bas_f := _p(g, id, s_f, -5.2)
	d.lumiere(haut_f + Vector3(0, 3.0, 0), Color(0.82, 0.9, 1.0), 1.6, 11.0, 1.4, false)
	g.nb_lumieres += 1
	d.projecteur(haut_f + Vector3(0.0, 4.5, 0.0), bas_f, Color(0.85, 0.93, 1.0), 6.0, 30.0, 17.0)
	d.carte("halo_f", haut_f + Vector3(0.0, -0.25, 0.0), Vector3.DOWN, 5.0, 5.0)     # lueur douce à l'ouverture (plus de rai en plaque)
	d.carte("flaque_g", bas_f + Vector3(0, 0.04, 0), Vector3.UP, 6.5, 6.5)

# ------------------------------------------------------------------ camp de Hrafn et abords
static func _repaire(g: Grotte, z: Dictionary, r: RandomNumberGenerator, role: String) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var d := g.decor
	var p: Dictionary = z.get("params", {})
	if role == "transition":
		pointes(g, r, id, s0, s1, int(12.0 * dens), 0.22, 1.0, false, 0.0, "c_strate_suie")
		if p.has("rideau"):
			rideau(g, id, float(p["rideau"]))
		else:                                                  # abords du camp : crânes sur piques, pieux
			d.trophee(_p(g, id, s1 - 2.0, -3.0), 1.9, 0.5)
			d.trophee(_p(g, id, s1 - 1.4, 3.0), 1.7, -0.6)
			d.os_tas(_p(g, id, s1 - 4.5, 1.2), 4, 0.5)
			d.applique(g.mur_en(id, s1 - 3.0, -1.0), g.droite(id, s1 - 3.0), _p(g, id, s1 - 3.0, -3.0).y + 2.0, 5.0, 1.7, true)
		return
	# --- camp : feu, marmite, couchages, caisses, table, râteliers, trophées, butin
	var feu_s := 8.0 + r.randf_range(-0.6, 0.6)
	var feu: Vector3 = d.pose_objet(_p(g, id, feu_s, 0.2), 0.75, 0.75, 0.0, 0.3, GrotteDecor.DROIT)["p"]
	d.feu_camp(feu)
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		d.prisme("bois", feu + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), feu + Vector3(0, 1.25, 0), 0.028, 5)
	d.tour("fer", feu + Vector3(0, 0.7, 0), [Vector2(0.15, 0.0), Vector2(0.24, 0.1), Vector2(0.27, 0.26), Vector2(0.24, 0.34), Vector2(0.2, 0.36)], 8, 0.0, false)
	d.prisme("fer", feu + Vector3(0, 1.25, 0), feu + Vector3(0, 1.0, 0), 0.01, 4)
	g._l(id, feu_s, 0.4, 1.0, FEU_C, 4.6, 13.0, 1.4, true)
	for c in [[4.6, -4.5], [8.2, -4.6]]:      # finitions : 3e couchage retiré (masquait le grand autel)
		d.couchage(_p(g, id, float(c[0]) + r.randf_range(-0.3, 0.3), float(c[1])), 1.57 + r.randf_range(-0.05, 0.05), r.randf() < 0.6)
	# caisses empilées, tonneaux et sacs au fond droit
	var base := _p(g, id, 14.6, 5.4)
	d.caisse(base, Vector3(0.9, 0.6, 0.6), 0.1)
	d.caisse(base + Vector3(1.0, 0, 0.1), Vector3(0.7, 0.5, 0.5), -0.2)
	d.caisse(base + Vector3(0.1, 0.6, 0), Vector3(0.7, 0.5, 0.5), 0.35)
	for k in 3:
		var pq := d.pose_objet(_p(g, id, 13.0 + k * 1.1, 5.6), 0.38, 0.38, 0.0, 1.0, GrotteDecor.INCLINE)
		if not pq["ok"]:
			continue
		var q: Vector3 = pq["p"]
		d.tonneau(q, 1.0)
		d.solide_rond(q + Vector3(0, 0.5, 0), 0.38, 1.0)
	for c in [[3.0, -5.3], [6.0, -5.5], [13.0, 4.0], [1.5, 4.8]]:
		d.sac(_p(g, id, float(c[0]), float(c[1])), r.randf_range(0.9, 1.3))
	# table, tabourets, bougie
	var tp: Vector3 = d.pose_objet(_p(g, id, 3.0, -2.4), 0.55, 0.33, 0.4, 0.8, GrotteDecor.DROIT)["p"]
	d.table(tp, 0.4)
	d.tabouret(tp + Vector3(-0.8, 0, 0.6))
	d.tabouret(tp + Vector3(0.8, 0, -0.5))
	d.bougie(tp + Vector3(0.0, 0.8, 0.0))
	d.solide(tp + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8))
	d.ratelier(_p(g, id, 14.8, -5.65), -PI * 0.5)
	d.ratelier(_p(g, id, 2.0, -5.65), -PI * 0.5)
	# butin et trophées
	var cb := _p(g, id, 14.6, -3.6)
	d.pieces(cb + Vector3(0.9, 0, 0.5), 18, 0.35)
	d.trophee(_p(g, id, 1.0, -3.8), 1.9, 0.5)
	d.trophee(_p(g, id, 1.0, 3.6), 1.7, -0.6)
	d.os_tas(_p(g, id, 7.0, 1.8), 6, 0.6)
	d.os_tas(_p(g, id, 10.4, -1.4), 4, 0.5)
	d.arme(_p(g, id, 6.8, -1.2), 0.9)
	d.arme(_p(g, id, 9.5, 1.6), 3.9)
	d.crane(_p(g, id, 7.0, 1.5), 2.0)
	d.crane(_p(g, id, 9.0, -2.0), 0.6)
	d.applique(g.mur_en(id, 4.0, -1.0), g.droite(id, 4.0), _p(g, id, 4.0, -3.0).y + 2.0, 5.0, 1.8, true)
	d.applique(g.mur_en(id, 13.0, 1.0), -g.droite(id, 13.0), _p(g, id, 13.0, 3.0).y + 2.0, 5.0, 1.8, true)
	pointes(g, r, id, 0.5, s1, int(14.0 * dens), 0.25, 1.0, false, 0.0, "c_strate_suie")
	rochers(g, r, id, 1.0, s1 - 1.0, int(5.0 * dens), 0.45, 0.9, true, "c_strate_suie")

## Goulet du camp : portique de bois et rideau de peaux fendu (on passe par la fente, sans collision) : il ferme la vue sur la salle
## des cristaux, dont le bleu se découpait comme un portail depuis le camp.
static func rideau(g: Grotte, id: String, s: float) -> void:
	var T := g.tang(id, s)
	var lacet := atan2(T.x, T.z)
	var dl := g.demi_l(id, s)
	var haut := Grotte._interp((g.br[id] as Dictionary)["profil"], s, 4)
	var bas := _p(g, id, s, 0.0)
	var dd := g.droite(id, s)
	var d := g.decor
	for sg: float in [-1.0, 1.0]:
		var w: float = dl.y if sg > 0.0 else dl.x
		var pied: Vector3 = bas + dd * sg * (w - 0.12)
		d.boite("bois", pied + Vector3(0, (haut - 0.3) * 0.5, 0), Vector3(0.24, haut - 0.3, 0.24), lacet)
		var larg := w - 0.12 + 0.25
		var centre: Vector3 = bas + dd * sg * ((w - 0.12 - 0.25) * 0.5) + T * sg * 0.1
		d.boite("peau", centre + Vector3(0, 1.65, 0), Vector3(larg, 3.3, 0.07), lacet)
		d.boite("peau", centre + T * sg * 0.07 + Vector3(0, 1.4, 0), Vector3(larg * 0.9, 2.8, 0.05), lacet + sg * 0.04)
	var centre_h: Vector3 = bas + dd * (dl.y - dl.x) * 0.5
	d.boite("bois", centre_h + Vector3(0, haut - 0.5, 0), Vector3(dl.x + dl.y, 0.22, 0.24), lacet)
	d.boite("peau", centre_h + Vector3(0, haut - 1.05, 0), Vector3(dl.x + dl.y - 0.3, 0.9, 0.07), lacet)

# ------------------------------------------------------------------ fond aux cristaux
static func _cristaux(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var dens: float = float(z.get("densite", 1.0))
	var d := g.decor
	if GrotteKit.actif():
		# kit : grappes, blocs, pans, stalagmites et stalactites sont des pièces du kit (GrotteKit._salle_cristaux)
		frange_voute(g, r, id, s0 + 1.5, s0 + 8.0, 20, "c_roche_glace")
		d.os_tas(_p(g, id, s1 - 7.0, 2.0), 5, 0.5)
		d.arme(_p(g, id, s1 - 9.0, 1.6), 2.2)
		d.crane(_p(g, id, s1 - 8.0, -1.6), 2.5)
		return
	# 5e passe (grottes_cryptes_6) : chemin BORDÉ des deux côtés de massifs de cristaux. 4 énormes au premier plan (prismes 1-2 m
	# en éventail, seules à porter une lumière cyan), des moyennes au pied des parois, d'autres en hauteur sur les parois.
	var enormes := [[s0 + 4.6, -1.0, 1.9], [s0 + 6.0, 1.0, 1.7], [s0 + 11.8, -1.0, 1.8], [s0 + 13.6, 1.0, 2.0]]
	for e: Array in enormes:
		var s: float = e[0]
		var cote: float = e[1]
		var dl := g.demi_l(id, s)
		var lat: float = cote * (dl.y if cote > 0.0 else dl.x) * 0.66
		var q := _p(g, id, s, lat)
		var vers_axe := (_p(g, id, s, 0.0) - q).normalized()
		d.grosse_grappe(q + Vector3(0, -0.15, 0), float(e[2]), r.randi(), (Vector3.UP * 1.3 + vers_axe).normalized())
		g.nb_lumieres += 1
		if g.loin_du_jeu(id, s, lat, 0.5):
			d.solide_rond(q + Vector3(0, 0.7, 0), 0.5, 1.4)
	var moyennes := [[s0 + 2.2, 1.0], [s0 + 8.6, -1.0], [s0 + 9.4, 1.0], [s0 + 16.0, -1.0], [s0 + 17.2, 1.0], [s0 + 19.0, -1.0]]
	for e: Array in moyennes:
		var s: float = float(e[0]) + r.randf_range(-0.4, 0.4)
		var cote: float = e[1]
		var dl := g.demi_l(id, s)
		var q := _p(g, id, s, cote * (dl.y if cote > 0.0 else dl.x) * r.randf_range(0.76, 0.88))
		d.grosse_grappe(q + Vector3(0, -0.1, 0), r.randf_range(0.6, 0.95), r.randi(), (Vector3.UP * 1.3 + (_p(g, id, s, 0.0) - q).normalized()).normalized(), false)
	for k in 6:                                                 # grappes en hauteur sur les parois, penchées vers le chemin
		var rg := _ring_proche(g, id, s0 + 2.0 + float(k) * 3.2 + r.randf_range(-0.6, 0.6))
		var vtx: int = [4, 5, 13, 14, 6, 12][k]
		var pv: Vector3 = (rg["pts"] as Array)[vtx]
		var centre: Vector3 = (rg["P"] as Vector3) + Vector3(0, float(rg["h"]) * 0.4, 0)
		var hit := g.rayon(centre, pv - centre, 40.0)
		if not hit.is_empty():
			pv = hit["p"]
		var vers_centre: Vector3 = (centre - pv).normalized()
		d.grosse_grappe(pv - vers_centre * 0.1, r.randf_range(0.55, 0.85), r.randi(), (vers_centre + Vector3(0, 0.35, 0)).normalized(), false)
	# rochers givrés au premier plan (profondeur), voûte : frange de stalactites près de la caméra
	for k in 5:
		var s := s0 + 2.5 + float(k) * 1.6 + r.randf_range(-0.3, 0.3)
		var dl := g.demi_l(id, s)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var lat := cote * (dl.y if cote > 0.0 else dl.x) * r.randf_range(0.45, 0.58)
		var rb := r.randf_range(0.45, 0.75)
		d.rocher("c_roche_neige", _p(g, id, s, lat) + Vector3(0, -0.1, 0), rb, rb * r.randf_range(0.8, 1.1), r.randi(), 1.0, g.loin_du_jeu(id, s, lat, rb), 6)
	frange_voute(g, r, id, s0 + 1.5, s0 + 8.0, 34, "c_roche_glace")
	pointes(g, r, id, s0 - 1.0, s1, int(26.0 * dens), 0.35, 2.4, false, 0.0, "c_roche_glace")
	pointes(g, r, id, s0, s1, int(12.0 * dens), 0.25, 1.2, true, 1.3, "c_roche_glace")
	rochers(g, r, id, s0, s1 - 1.0, int(6.0 * dens), 0.4, 0.9, true, "c_roche_glace")
	d.os_tas(_p(g, id, s1 - 7.0, 2.0), 5, 0.5)
	d.arme(_p(g, id, s1 - 9.0, 1.6), 2.2)
	d.crane(_p(g, id, s1 - 8.0, -1.6), 2.5)

# ------------------------------------------------------------------ cachette de Hrafn
static func _cache(g: Grotte, z: Dictionary, r: RandomNumberGenerator) -> void:
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var d := g.decor
	pointes(g, r, id, s0, s1, 10, 0.2, 0.8, false)
	# marchandises volées : balles, caisses, tonneaux, urnes ; couchage et râtelier de Hrafn
	for k in 5:
		var q := _p(g, id, s0 + 7.0 + k * 1.6, (3.2 + r.randf_range(0.0, 0.5)) * (1.0 if k % 2 == 0 else -1.0))
		d.caisse(q, Vector3(r.randf_range(0.6, 0.9), r.randf_range(0.45, 0.6), 0.55), r.randf_range(-0.4, 0.4))
		if k % 2 == 0:
			d.caisse(q + Vector3(0, 0.55, 0), Vector3(0.6, 0.45, 0.5), r.randf_range(-0.4, 0.4))
	for k in 4:
		d.sac(_p(g, id, s0 + 6.0 + k * 2.2, -3.4 + r.randf_range(-0.3, 0.3)), r.randf_range(0.9, 1.3))
	for k in 3:
		var q := _p(g, id, s0 + 10.0 + k * 1.5, 3.9)
		d.tonneau(q, 1.0)
		d.solide_rond(q + Vector3(0, 0.5, 0), 0.38, 1.0)
	d.urne(_p(g, id, s1 - 3.0, 2.8), 1.0)
	d.couchage(_p(g, id, s1 - 5.5, 3.2), 0.2, true)
	d.ratelier(_p(g, id, s1 - 2.0, 0.0) + Vector3(0, 0, 0), -PI * 0.5 + _lacet(g, id, s1 - 2.0) - PI)
	d.pieces(_p(g, id, s1 - 4.0, -2.2), 20, 0.4)
	d.applique(g.mur_en(id, s0 + 9.0, -1.0), g.droite(id, s0 + 9.0), _p(g, id, s0 + 9.0, -3.0).y + 1.9, 4.5, 1.7, true)


# ------------------------------------------------------------------ 5e passe : frange de stalactites à la voûte
## Stalactites denses et serrées entre sa et sb, sur toute la largeur (2,3 m de garde au-dessus du chemin, 0,8 m ailleurs),
## chacune entourée de 2 à 4 plus petites : le « premier plan haut » des références (grottes_cryptes_5 / 6).
static func frange_voute(g: Grotte, r: RandomNumberGenerator, id: String, sa: float, sb: float, n: int, nom := "c_roche_nu") -> void:
	for k in n:
		var s := r.randf_range(sa, sb)
		var dl := g.demi_l(id, s)
		var lat := r.randf_range(-dl.x * 0.9, dl.y * 0.9)
		if g.faille_f(g.br[id], s) > 0.02:
			continue
		var pb := _p(g, id, s, lat)
		var pt := g.plafond_en(id, s, lat)
		var bas_min := pb.y + (2.3 if absf(lat) < 1.8 else 0.9)
		var lq := minf(r.randf_range(1.2, 5.0), pt.y + 0.1 - bas_min)     # longues : elles doivent entrer dans le cadre près de la caméra
		if lq < 0.4:
			continue
		var rq := minf(lq * r.randf_range(0.08, 0.12), 0.45)
		concretion(g, nom, pt + Vector3(0, 0.15, 0), rq, -lq, r.randi(), 0.0)
		for j in r.randi_range(2, 4):
			var a := r.randf() * TAU
			var off := rq * r.randf_range(1.6, 3.2)
			var q := g.plafond_en(id, s + sin(a) * off, lat + cos(a) * off)
			var l2 := minf(lq * r.randf_range(0.3, 0.7), q.y + 0.1 - bas_min)
			if l2 > 0.2:
				concretion(g, nom, q + Vector3(0, 0.12, 0), rq * r.randf_range(0.4, 0.7), -l2, r.randi(), 0.0)

# ------------------------------------------------------------------ 3e passe : silhouettes (mine, lac)
## Rive du lac : premier écart latéral (côté gauche) où le sol rejoint la glace ; 999 si pas de lac à cet endroit.
static func _rive(g: Grotte, id: String, s: float) -> float:
	var dl := g.demi_l(id, s)
	var lat := -0.5
	while lat > -dl.x + 0.4:
		if g.sol_en(id, s, lat).y < g.lac_y + 0.08:
			return lat
		lat -= 0.4
	return 999.0

## Mine : casse la régularité du tunnel. Pans de roche saillants à demi enfoncés dans la paroi, blocs, éboulement partiel au pied
## d'une paroi, planches de soutènement plaquées contre la roche (entre les étais).
static func _parois_mine(g: Grotte, z: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(z.get("graine", 1)) * 53 + 11
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var d := g.decor
	var etais: Array = (z.get("params", {}) as Dictionary).get("etais", [])
	var s := s0 + r.randf_range(0.5, 2.0)
	var k := 0
	while s < s1 - 1.0:
		if g.hors_jonction(id, s):
			var cote := 1.0 if r.randf() < 0.5 else -1.0
			var dl := g.demi_l(id, s)
			var w := dl.y if cote > 0.0 else dl.x
			var sty := _style(g, id, s)
			var nm := _roche(sty)
			var pres_etai := false
			for se: float in etais:
				if absf(se - s) < 1.3:
					pres_etai = true
			var tirage := r.randf()
			if tirage < 0.45:
				# pan saillant : grand rocher haut, aux trois quarts dans la paroi
				var rr := r.randf_range(0.6, 1.1)
				var q := g.sol_en(id, s, cote * (w + rr * 0.35))
				d.rocher(nm, q + Vector3(0, -0.2, 0), rr, r.randf_range(1.4, 2.6), r.randi(), _masque(sty) + 0.15, false, 5)
				if g.libre(id, s, cote * (w - rr * 0.6), 0.3):
					d.solide_rond(g.sol_en(id, s, cote * (w - rr * 0.3)) + Vector3(0, 0.9, 0), rr * 0.45, 1.8)
			elif tirage < 0.7 and not pres_etai:
				# planches de soutènement plaquées contre la paroi, liteau en travers
				var mp := g.mur_en(id, s, cote)
				if mp != Vector3.ZERO:
					var R := g.droite(id, s) * cote
					var T := g.tang(id, s)
					var pied := g.sol_en(id, s, cote * (w - 0.15))
					var lac := atan2(T.x, T.z)
					var n := r.randi_range(3, 5)
					var h := r.randf_range(1.6, 2.3)
					for j in n:
						var o := T * ((float(j) - (n - 1) * 0.5) * 0.24) - R * 0.12
						var hj := h * r.randf_range(0.85, 1.0)
						d.boite("planches", Vector3(mp.x, pied.y + hj * 0.5 - 0.05, mp.z) + o, Vector3(0.05, hj, 0.22), lac)
					for yy: float in [0.5, h - 0.35]:
						d.boite("bois", Vector3(mp.x, pied.y + yy, mp.z) - R * 0.17, Vector3(0.07, 0.1, n * 0.24 + 0.2), lac)
			elif tirage < 0.85:
				# éboulement partiel : tas de blocs au pied de la paroi
				for j in r.randi_range(5, 9):
					var sj := s + r.randf_range(-1.2, 1.2)
					var lj := cote * w * r.randf_range(0.7, 0.98)
					var q := g.sol_en(id, sj, lj)
					var rb := r.randf_range(0.15, 0.55) * (1.5 if j == 0 else 1.0)
					d.rocher(nm, q + Vector3(0, -rb * 0.2, 0), rb, rb * r.randf_range(0.6, 1.1), r.randi(), _masque(sty), false, r.randi_range(4, 6))
		s += r.randf_range(1.8, 3.2)
		k += 1

## Grande caverne du lac (grottes_cryptes_5) : forêt de hautes stalagmites sombres à tête givrée, étagée en profondeur côté lac ;
## stalactites en dents de scie à la voûte ; terrasses de rochers plats givrés au bord de l'eau.
static func _foret_lac(g: Grotte, z: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(z.get("graine", 1)) * 71 + 5
	var id: String = z["branche"]
	var s0: float = z["s"][0]
	var s1: float = z["s"][1]
	var d := g.decor
	# 4e passe : stalagmites massives et coniques (base large), têtes givrées, en trois plans de profondeur (près, milieu, fond)
	var plans := [[2.8, 4.8, 1.8, 3.0, 8], [5.2, 8.5, 2.8, 4.6, 12], [9.0, 99.0, 3.5, 6.0, 14]]
	for pl: Array in plans:
		var faites := 0
		for k in 140:
			if faites >= int(pl[4]):
				break
			var s := r.randf_range(s0 + 2.0, s1 - 2.0)
			var dl := g.demi_l(id, s)
			var lat := -r.randf_range(float(pl[0]), minf(float(pl[1]), dl.x * 0.95))
			if absf(lat) > dl.x * 0.95:
				continue
			var hh0 := r.randf_range(float(pl[2]), float(pl[3]))
			var rr0 := hh0 * r.randf_range(0.16, 0.22)
			if not g.loin_du_jeu(id, s, lat, rr0 * 0.8):
				continue
			var pb := _p(g, id, s, lat)
			var pt := g.plafond_en(id, s, lat)
			var hh := minf(hh0, 0.8 * (pt.y - pb.y))
			if hh < 1.6:
				continue
			var rr := rr0 * hh / hh0
			concretion(g, "c_roche_nu", pb + Vector3(0, -0.15, 0), rr, hh, r.randi(), 0.0, 0.75)
			# tête givrée : calotte basse posée sous la pointe (le givre ne prend que sur les faces tournées vers le haut)
			var rt := rr * pow(0.2, 0.8) * 1.5
			d.rocher("c_roche_neige", pb + Vector3(0, hh * 0.8 - 0.15, 0), rt, rt * 0.9, r.randi(), 1.0, false, 6)
			d.solide_rond(pb + Vector3(0, hh * 0.3, 0), rr * 0.75, hh * 0.6)
			for j in r.randi_range(1, 3):                       # petites au pied
				var a := r.randf() * TAU
				var q := pb + Vector3(cos(a), 0, sin(a)) * rr * r.randf_range(1.3, 2.0)
				concretion(g, "c_roche_nu", q + Vector3(0, -0.1, 0), rr * r.randf_range(0.3, 0.45), hh * r.randf_range(0.2, 0.35), r.randi(), 0.0, 0.75)
			faites += 1
	# dents de scie à la voûte au-dessus du lac
	for k in 40:
		var s := r.randf_range(s0 + 1.0, s1 - 1.0)
		var dl := g.demi_l(id, s)
		var lat := -r.randf_range(1.0, dl.x * 0.9)
		if g.faille_f(g.br[id], s) > 0.02:
			continue
		var pb := _p(g, id, s, lat)
		var pt := g.plafond_en(id, s, lat)
		var bas_min := pb.y + (2.3 if absf(lat) < 1.8 else 0.8)
		var lq := minf(r.randf_range(1.0, 3.2), pt.y + 0.1 - bas_min)
		if lq < 0.5:
			continue
		var rq := lq * r.randf_range(0.1, 0.15)
		concretion(g, "c_roche_nu", pt + Vector3(0, 0.15, 0), rq, -lq, r.randi(), 0.0)
		var dir := r.randf() * TAU
		for j in r.randi_range(2, 4):
			var off := (float(j) + 1.0) * rq * 1.6
			var q := g.plafond_en(id, s + sin(dir) * off, lat + cos(dir) * off)
			var l2 := minf(lq * r.randf_range(0.3, 0.75), q.y + 0.1 - bas_min)
			if l2 > 0.2:
				concretion(g, "c_roche_nu", q + Vector3(0, 0.12, 0), rq * r.randf_range(0.4, 0.7), -l2, r.randi(), 0.0)
	# terrasses : dalles de roche plates givrées en gradins sur la rive, glaçons pendus aux rebords côté lac
	var s := s0 + 3.0
	while s < s1 - 3.0:
		var rv := _rive(g, id, s)
		if rv < 900.0 and g.libre(id, s, rv, 0.2):
			var vers_lac := (_p(g, id, s, rv - 3.0) - _p(g, id, s, rv)).normalized()
			vers_lac.y = 0.0
			vers_lac = vers_lac.normalized()
			for j in 2:
				var q := g.sol_en(id, s + r.randf_range(-0.6, 0.6), rv + 0.3 - float(j) * 0.9)
				var rb := r.randf_range(0.8, 1.3) * (1.0 - 0.2 * j)
				var hb := r.randf_range(0.42, 0.6) * (1.0 - 0.3 * j)
				var base := Vector3(q.x, maxf(q.y, g.lac_y) - 0.12 + 0.2 * (1 - j), q.z)
				var prof := [Vector2(rb * 0.8, -0.1), Vector2(rb * 0.9, hb * 0.5), Vector2(rb * 1.05, hb * 0.85), Vector2(rb * 0.98, hb), Vector2(rb * 0.55, hb * 1.04), Vector2(0.0, hb * 1.05)]
				d.revolution("c_roche_neige", base, prof, 7, r.randi(), 0.3, 1.0, 0.62, 1.0, 3.0)
				for k in r.randi_range(3, 6):               # frange de glaçons sous le rebord, côté lac
					var a := r.randf_range(-1.1, 1.1)
					var dir := vers_lac.rotated(Vector3.UP, a)
					var top := base + dir * rb * 1.0 + Vector3(0, hb * 0.82, 0)
					d.pointe("c_glacon", top, r.randf_range(0.03, 0.07), -r.randf_range(0.15, minf(0.45, hb * 0.75)), r.randi(), 0.0, 5)
		s += r.randf_range(2.2, 3.6)
	frange_voute(g, r, id, s0 + 1.5, s0 + 9.5, 40, "c_roche_nu")
