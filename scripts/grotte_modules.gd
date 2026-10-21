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

## Pointes (stalactites au plafond ou stalagmites au sol) : n tirages, hors du passage central si `ecart` > 0.
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
		if sol_:
			g.decor.pointe(nm, _p(g, id, s, lat) + Vector3(0, -0.05, 0), r.randf_range(0.12, rmax), r.randf_range(0.4, lmax), r.randi(), m)
		else:
			if g.faille_f(g.br[id], s) > 0.02:
				continue
			g.decor.pointe(nm, g.plafond_en(id, s, lat) + Vector3(0, 0.12, 0), r.randf_range(0.1, rmax), -r.randf_range(0.4, lmax), r.randi(), m)

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
		var solide := collision and hh >= 0.55 and g.libre(id, s, lat_r, rr * 0.8)
		g.decor.rocher(nom if nom != "" else _roche(sty), _p(g, id, s, lat_r), rr, hh, r.randi(), _masque(sty), solide, 6)

static func etai(g: Grotte, id: String, s: float) -> void:
	var dl := g.demi_l(id, s)
	var w1 := dl.x - 0.25
	var w2 := dl.y - 0.25
	var h := Grotte._interp((g.br[id] as Dictionary)["profil"], s, 4)
	var pa := _p(g, id, s, -w1)
	var pb := _p(g, id, s, w2)
	var R := g.droite(id, s)
	var haut := minf(pa.y, pb.y) + h - 0.55
	var d := g.decor
	d.prisme("bois", pa + Vector3(0, -0.1, 0), pa + Vector3(0, haut - pa.y, 0), 0.15, 8)
	d.prisme("bois", pb + Vector3(0, -0.1, 0), pb + Vector3(0, haut - pb.y, 0), 0.15, 8)
	d.prisme("bois", pa + Vector3(0, haut - pa.y, 0) - R * 0.3, pb + Vector3(0, haut - pb.y, 0) + R * 0.3, 0.17, 8)
	d.solide_rond(pa + Vector3(0, 1.0, 0), 0.15, 2.4)
	d.solide_rond(pb + Vector3(0, 1.0, 0), 0.15, 2.4)

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
	var dl := g.demi_l(id, s)
	if absf(lat) > (dl.y if lat > 0.0 else dl.x) - 1.3:          # trop près de la paroi (variante étroite) : le chariot se range au pied de la paroi, sans bloquer
		lat = signf(lat) * ((dl.y if lat > 0.0 else dl.x) - 1.3)
	var p := _p(g, id, s, lat)
	var T := g.tang(id, s)
	var R := g.droite(id, s)
	var lac := atan2(T.x, T.z)
	var d := g.decor
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

## Champignons lumineux : n pieds de hauteurs variées, chapeaux émissifs (matière cristal), sans collision.
static func champignons(g: Grotte, r: RandomNumberGenerator, p: Vector3, n: int) -> void:
	for k in n:
		var q := p + Vector3(r.randf_range(-0.45, 0.45), 0.0, r.randf_range(-0.45, 0.45))
		var hs := r.randf_range(0.14, 0.4)
		var rc := r.randf_range(0.08, 0.17)
		g.decor.tour("os", q, [Vector2(0.03, 0.0), Vector2(0.022, hs)], 5, 0.0, false)
		g.decor.revolution("c_cristal", q + Vector3(0, hs, 0), [Vector2(rc, 0.0), Vector2(rc * 1.05, 0.03), Vector2(rc * 0.7, 0.07), Vector2(0.0, 0.095)], 7, r.randi(), 0.2, 0.0, 0.85, 1.0, 1.0)

## Amas de cristaux de glace.
static func cristaux(g: Grotte, r: RandomNumberGenerator, p: Vector3, n: int, taille := 1.0) -> void:
	for j in n:
		g.decor.cristal(p + Vector3(r.randf_range(-0.5, 0.5), -0.08, r.randf_range(-0.5, 0.5)), r.randf_range(0.1, 0.3) * taille, r.randf_range(0.7, 2.2) * taille, r.randi(), 0.6)

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

static func lumieres(g: Grotte, z: Dictionary) -> void:
	var n: int = int(z.get("n_lum", 0))
	if n <= 0:
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
		d.congere(_p(g, id, s, cote * (dl.y if cote > 0 else dl.x) * r.randf_range(0.5, 0.85)), r.randf_range(1.3, 2.6), r.randf_range(0.25, 0.5), r.randi())
	rochers(g, r, id, s0 + 2.0, s1 - 1.0, int(5.0 * dens), 0.6, 1.2, true, "c_roche_neige")
	pointes(g, r, id, 5.0, 11.0, int(12.0 * dens), 0.2, 1.6, false, 0.0, "c_roche_glace")
	pointes(g, r, id, 12.0, s1, 3, 0.18, 0.8, false)
	d.trophee(_p(g, id, 13.0, -2.2), 1.7, 0.4)
	d.os_tas(_p(g, id, 12.6, 1.4), 3, 0.5)
	d.arme(_p(g, id, 11.0, 1.9) + Vector3(0, 0.02, 0), 0.8)
	d.caisse(_p(g, id, 9.5, -2.6), Vector3(0.8, 0.55, 0.55), 0.5)
	# poste du guetteur : table, tabouret, bougie (contre la paroi droite)
	var tp := _p(g, id, 10.0, 2.5)
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
	var charge := r.randi() % 3
	for s: float in p.get("chariots", []):
		if g.libre(id, s, lat_rail, 0.5):
			chariot(g, id, s, lat_rail, r, charge)
	match role:
		"combat":
			d.os_tas(_p(g, id, s0 + 5.0, -1.0), 7, 0.7)
			d.crane(_p(g, id, s0 + 5.3, -0.6), 1.0)
			d.arme(_p(g, id, s0 + 5.6, 0.3), 3.6)
			var tn := _p(g, id, s1 - 4.5, -2.1)
			d.tonneau(tn, 1.0)
			d.solide_rond(tn + Vector3(0, 0.5, 0), 0.38, 1.0)
			d.caisse(_p(g, id, s0 + 11.0, 2.3), Vector3(0.8, 0.5, 0.5), 0.15)
		"ressources":
			# poste des mineurs-bandits : table, tabourets, lit de camp, caisses, sacs de minerai, râtelier de pioches
			var tb := _p(g, id, s0 + 4.0, -1.2)
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
			d.os_tas(_p(g, id, s0 + 9.0, -1.0), 7, 0.7)
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
		"combat":
			# colonnes (repères) entre la glace et le plafond, du côté du lac
			for c in [[0.1, -6.5, 0.8], [0.32, -11.0, 1.0], [0.62, -9.0, 0.9], [0.86, -5.8, 0.75]]:
				var s: float = lerpf(s0, s1, float(c[0])) + r.randf_range(-1.0, 1.0)
				var lat: float = float(c[1]) * r.randf_range(0.9, 1.1)
				if not g.libre(id, s, lat, 1.0):
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
				d.rocher("c_roche_glace", _p(g, id, s, lat), rb, hb, r.randi(), 0.7, hb >= 0.55 and g.libre(id, s, lat, rb * 0.8), 6)
			for c in [[0.06, -3.5], [0.4, -4.4], [0.55, -3.0], [0.2, -9.0], [0.48, -8.0]]:     # cristaux au bord du lac
				var q := _p(g, id, lerpf(s0, s1, float(c[0])) + r.randf_range(-1.0, 1.0), float(c[1]))
				cristaux(g, r, q, 4, 0.7)
			d.os_tas(_p(g, id, s0 + 7.0, 2.0), 4, 0.6)
			d.arme(_p(g, id, s0 + 13.0, 1.6), 4.0)
			d.caisse(_p(g, id, s0 + 1.5, 2.4), Vector3(0.7, 0.5, 0.5), 0.9)
			for k in int(6.0 * dens):                        # champignons sur la corniche et le rivage
				var s := r.randf_range(s0 + 2.0, s1 - 6.0)
				champignons(g, r, _p(g, id, s, r.randf_range(3.0, 6.0)), 3)
			# faille du plafond : lumière du jour, rai oblique, flaque, projecteur étroit
			if g.br[id]["d"].has("faille"):
				var fa: Array = g.br[id]["d"]["faille"]
				var s_f := (float(fa[1]) + float(fa[2])) * 0.5
				var haut_f := g.plafond_en(id, s_f, 2.0)
				var bas_f := _p(g, id, s_f, -5.2)
				d.lumiere(haut_f + Vector3(0, 3.0, 0), Color(0.82, 0.9, 1.0), 1.6, 11.0, 1.4, false)
				g.nb_lumieres += 1
				d.projecteur(haut_f + Vector3(0.0, 4.5, 0.0), bas_f, Color(0.85, 0.93, 1.0), 6.0, 30.0, 17.0)
				d.rai_oblique(haut_f + Vector3(0.0, 5.2, 0.0), bas_f + Vector3(0, 0.05, 0), 1.9, 3.8)
				d.carte("flaque_g", bas_f + Vector3(0, 0.04, 0), Vector3.UP, 6.5, 6.5)
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
	var feu := _p(g, id, feu_s, 0.2)
	d.feu_camp(feu)
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		d.prisme("bois", feu + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), feu + Vector3(0, 1.25, 0), 0.028, 5)
	d.tour("fer", feu + Vector3(0, 0.7, 0), [Vector2(0.15, 0.0), Vector2(0.24, 0.1), Vector2(0.27, 0.26), Vector2(0.24, 0.34), Vector2(0.2, 0.36)], 8, 0.0, false)
	d.prisme("fer", feu + Vector3(0, 1.25, 0), feu + Vector3(0, 1.0, 0), 0.01, 4)
	g._l(id, feu_s, 0.4, 1.0, FEU_C, 4.6, 13.0, 1.4, true)
	for c in [[4.6, -4.5], [8.2, -4.6], [11.8, -4.4]]:
		d.couchage(_p(g, id, float(c[0]) + r.randf_range(-0.3, 0.3), float(c[1])), 1.57 + r.randf_range(-0.05, 0.05), r.randf() < 0.6)
	# caisses empilées, tonneaux et sacs au fond droit
	var base := _p(g, id, 14.6, 5.4)
	d.caisse(base, Vector3(0.9, 0.6, 0.6), 0.1)
	d.caisse(base + Vector3(1.0, 0, 0.1), Vector3(0.7, 0.5, 0.5), -0.2)
	d.caisse(base + Vector3(0.1, 0.6, 0), Vector3(0.7, 0.5, 0.5), 0.35)
	for k in 3:
		var q := _p(g, id, 13.0 + k * 1.1, 5.6)
		d.tonneau(q, 1.0)
		d.solide_rond(q + Vector3(0, 0.5, 0), 0.38, 1.0)
	for c in [[3.0, -5.3], [6.0, -5.5], [12.5, -5.3], [13.0, 4.0], [1.5, 4.8]]:
		d.sac(_p(g, id, float(c[0]), float(c[1])), r.randf_range(0.9, 1.3))
	# table, tabourets, bougie
	var tp := _p(g, id, 3.0, -2.4)
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
	d.pieces(_p(g, id, 13.4, -4.4), 12, 0.3)
	d.urne(_p(g, id, 11.5, -5.3), 0.9)
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
	# amas sur le sol : un monolithe, des amas
	var mono := _p(g, id, s1 - 5.0, -0.5)
	for k in 5:
		d.cristal(mono + Vector3(r.randf_range(-0.5, 0.5), -0.1, r.randf_range(-0.5, 0.5)), r.randf_range(0.35, 0.6), r.randf_range(2.6, 4.6), r.randi(), 0.35)
	for k in int(8.0 * dens):
		var s := r.randf_range(s0 + 1.0, s1 - 1.0)
		var dl := g.demi_l(id, s)
		var q := _p(g, id, s, r.randf_range(-dl.x, dl.y) * 0.75)
		for j in r.randi_range(4, 7):
			d.cristal(q + Vector3(r.randf_range(-0.6, 0.6), -0.08, r.randf_range(-0.6, 0.6)), r.randf_range(0.1, 0.32), r.randf_range(0.7, 2.4), r.randi(), 0.7)
	# cristaux sortant des parois et du plafond, penchés vers l'intérieur
	for k in int(9.0 * dens):
		var rg := _ring_proche(g, id, r.randf_range(s0 + 0.5, s1))
		var vtx: int = [3, 4, 5, 6, 7, 11, 12, 13, 14, 15][r.randi() % 10]
		var pv: Vector3 = (rg["pts"] as Array)[vtx]
		var vers_centre: Vector3 = ((rg["P"] as Vector3) + Vector3(0, float(rg["h"]) * 0.4, 0) - pv).normalized()
		for j in r.randi_range(2, 4):
			d.cristal(pv + vers_centre * 0.05, r.randf_range(0.1, 0.28), r.randf_range(0.6, 2.0), r.randi(), 0.5, (vers_centre + Vector3(0, 0.15, 0)).normalized())
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
