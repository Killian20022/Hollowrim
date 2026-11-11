class_name AbordsProps
## props/maximum v3 (2026-11-11) : compositions des abords (champs, fermes, lisières, chemins, cercle runique, tumulus, entrée de la
## grotte). Props texturés pq_* et, quand le MegaKit n'a pas la pièce (charrette, tente, rondins, souche, poutre), les q_* du kit
## Medieval Village, tous fondus en UN maillage + UN corps statique par composition (PropsQuaternius.lot_pq) : aucun nœud par prop.
## La nature maison (rochers, buissons, touffes, cairns, os) n'est pas touchée : les compositions s'en écartent.
## Mode pq seulement : `-- --props-quat-ancien` rend exactement l'état d'avant.
##
## Une composition : [nom, items, ancres] ; ancre [x, z, lacet°] en monde ; chaque ancre est essayée telle quelle puis glissée de
## ±1 et ±2 m (le long de son axe X puis Z). Item : [id, droite, devant, lacet°, hauteur, solide, échelle, tangage°, roulis°]
## (repère de la composition, l'avant des props regarde +Z). Échelle : nombre (uniforme) ; Vector3 seulement pour le bois de charpente
## (poutre, planches) mis à longueur comme les travées de barrière (AbordsQ.base_segment). hauteur > 0.05 : posé à cette hauteur au-dessus de l'item au sol le plus
## proche (pas de contrôle d'emprise). Une ancre est refusée si un item au sol touche un arbre, un chemin, une pente trop forte, un corps
## physique (rochers, barrières, bâti, autres compositions) ou une composition déjà posée.

const PORTEE := 70.0          # les lots disparaissent au-delà (brouillard)
const PENTE_MAX := 0.57       # écart de sol maximal sous un petit item (m) : il est posé à mi-pente, flotte ou s'enfonce de ~0,1 m au plus
const PENTE_GRAND := 0.9      # sous un grand item solide (charrette, tente) : il est incliné comme le terrain (≤ ~15°)

## Charrette abandonnée au bord d'un champ : roue côté champ, sacs de grain renversés, tonneau, pioche couchée dans la neige.
const CHARRETTE := [["q_chariot", 0.0, 0.0, 0.0, 0.0, true], ["pq_sac", 1.05, 0.55, 30.0, 0.0, false], ["pq_sac", 1.25, -0.2, -60.0, 0.0, false, 1.0, 0.0, 80.0],
	["pq_tonneau", -1.15, 0.9, 0.0, 0.0, true], ["pq_pioche", -1.1, -0.6, 70.0, 0.0, false, 1.0, 90.0], ["pq_seau_bois", 0.9, 1.25, 0.0, 0.0, false]]
## Épouvantail : perche, traverse, sac en tête, haillon de toile.
const EPOUVANTAIL := [["q_poutre_ronde", 0.0, 0.0, 0.0, 0.0, true, Vector3(2.15, 1, 1), 0.0, 90.0], ["q_poutre_ronde", 0.0, 0.0, 0.0, 1.45, false, Vector3(1.36, 1, 1)],
	["pq_sac", 0.0, 0.0, 15.0, 1.72, false, 0.62], ["pq_banniere_2_toile", 0.0, 0.08, 0.0, 0.42, false, 0.56]]
## Bûcher de bois de chauffage contre une lisière : rondins empilés en trois rangs, billot (souche) et hache plantée, bûches.
const BUCHER := [["q_rondin", 0.0, 0.0, 0.0, 0.0, true], ["q_rondin", 0.0, 0.42, 4.0, 0.0, false], ["q_rondin", 0.0, -0.42, -3.0, 0.0, false],
	["q_rondin", 0.05, 0.21, 2.0, 0.36, false], ["q_rondin", -0.05, -0.21, -2.0, 0.36, false], ["q_rondin", 0.0, 0.0, 6.0, 0.72, false],
	["q_souche", 1.75, 0.55, 30.0, 0.0, true, 0.62], ["q_hache_camp", 1.78, 0.55, 75.0, 0.38, false, 1.0, 0.0, 12.0],
	["q_buche", 1.3, 1.25, 50.0, 0.0, false], ["q_buche", 1.6, 1.15, -20.0, 0.0, false], ["q_buche", 2.2, 0.95, 80.0, 0.0, false]]
## Campement de chasseur : tente, foyer éteint et marmite, rondin-banc, séchoir (deux perches et traverse) et prises, pièges, sac, corde.
const CAMP_CHASSEUR := [["q_tente", 0.0, 0.0, 0.0, 0.0, true, 0.8], ["q_feu_bois", 0.3, 3.0, 0.0, 0.0, false], ["q_marmite_camp", 0.35, 3.05, 20.0, 0.12, false],
	["q_rondin", -1.25, 3.3, 75.0, 0.0, true], ["q_poutre_ronde", 2.2, 1.0, 0.0, 0.0, true, Vector3(1.65, 1, 1), 0.0, 90.0], ["q_poutre_ronde", 2.2, 2.6, 0.0, 0.0, true, Vector3(1.65, 1, 1), 0.0, 90.0],
	["q_poutre_ronde", 2.2, 1.8, 90.0, 1.5, false, Vector3(1.75, 1, 1)], ["q_viande", 2.2, 1.5, 0.0, 1.32, false, 1.6, 90.0], ["q_viande", 2.2, 2.0, 0.0, 1.3, false, 1.6, 90.0],
	["q_poisson", 2.2, 2.3, 90.0, 1.28, false, 1.4, 0.0, 90.0], ["q_piege_ours", -1.8, 1.4, 20.0, 0.0, false], ["q_piege_ours", -2.0, 0.6, -35.0, 0.0, false],
	["pq_sac", 1.15, -0.6, 25.0, 0.0, false], ["pq_corde_3", -0.9, 2.2, 0.0, 0.0, false], ["pq_seau_bois", 1.0, 3.4, 0.0, 0.0, false],
	["q_hache_camp", -0.7, 3.65, 0.0, 0.0, false, 1.0, 90.0]]
## Récolte rentrée au portail d'un champ : sacs debout, cageots de carottes et de pommes, seau, tonneau de pommes.
const RECOLTE := [["pq_tonneau_pommes", 0.0, 0.0, 0.0, 0.0, true], ["pq_sac", 0.8, 0.1, 20.0, 0.0, false], ["pq_sac", 1.3, -0.15, -30.0, 0.0, false],
	["pq_cageot_carottes", -0.85, 0.15, 10.0, 0.0, false], ["pq_cageot_pommes", -0.85, 0.15, -5.0, 0.32, false], ["pq_seau_bois", 0.45, 0.75, 0.0, 0.0, false],
	["pq_cageot_vide", -0.4, 0.85, 40.0, 0.0, false]]
## Offrandes au pied de la stèle du cercle runique et devant le tertre : urne, vases, coupe, bougies éteintes, pain, pommes, pièces.
const OFFRANDES := [["pq_vase_4", -0.45, 0.0, 0.0, 0.0, false], ["pq_urne_brisee", 0.5, 0.05, 30.0, 0.0, false], ["pq_calice", 0.0, 0.25, 0.0, 0.0, false],
	["pq_bougie_2", -0.2, 0.45, 0.0, 0.0, false], ["pq_bougie_1", 0.22, 0.42, 0.0, 0.0, false], ["pq_bougie_2", -0.75, 0.3, 0.0, 0.0, false],
	["q_pain", 0.3, 0.6, 70.0, 0.0, false], ["q_pomme", -0.05, 0.62, 0.0, 0.0, false], ["q_pomme", 0.08, 0.7, 0.0, 0.0, false],
	["pq_tas_pieces", 0.62, 0.45, 0.0, 0.0, false]]
## Poteau indicateur à la fourche des chemins : poteau, deux planches clouées en flèche, lanterne murale éteinte.
const POTEAU := [["q_poutre_ronde", 0.0, 0.0, 0.0, 0.0, true, Vector3(2.2, 1, 1), 0.0, 90.0], ["q_planches_sol", 0.3, 0.1, 90.0, 1.72, false, Vector3(0.2, 1, 0.34), 0.0, 90.0],
	["q_planches_sol", -0.28, 0.1, 96.0, 1.4, false, Vector3(0.18, 1, 0.3), 0.0, 90.0], ["pq_lanterne_murale", 0.0, 0.1, 0.0, 0.95, false]]
## Réserve des bandits devant la grotte : caisses empilées, tonneau, sacs, bûches.
const RESERVE_BANDITS := [["pq_caisse", 0.0, 0.0, 8.0, 0.0, true], ["pq_caisse_fer", 0.72, 0.05, -10.0, 0.0, true], ["pq_caisse", 0.3, 0.0, -20.0, 0.71, false],
	["pq_tonneau", -0.85, 0.15, 0.0, 0.0, true], ["pq_sac", 0.4, 0.75, 35.0, 0.0, false], ["q_buche", -0.4, 0.9, 70.0, 0.0, false], ["q_buche", -0.2, 1.05, 20.0, 0.0, false]]

## Lieux : [nom, composition, ancres [x, z, lacet°]].
const LIEUX := [
	["charrette_champ_a", CHARRETTE, [[92.4, 34.8, 0.0], [92.0, 38.4, 15.0], [91.8, 31.5, -10.0], [86.0, 52.0, 90.0], [86.2, 29.6, 20.0], [87.5, 28.5, 35.0]]],
	["charrette_champ_c", CHARRETTE, [[72.0, -6.5, 180.0], [71.8, -9.5, 170.0], [63.0, -13.0, 90.0], [63.0, -0.8, 90.0]]],
	["epouvantail_a", EPOUVANTAIL, [[83.5, 35.2, 20.0], [82.0, 34.0, 20.0]]],
	["epouvantail_b", EPOUVANTAIL, [[81.0, 45.8, -15.0], [79.5, 45.0, -15.0]]],
	["recolte_champ_b", RECOLTE, [[74.4, 45.5, 90.0], [74.4, 47.5, 90.0], [81.0, 51.6, 0.0]]],
	["recolte_champ_c", RECOLTE, [[55.6, -8.6, -90.0], [55.6, -5.5, -90.0], [64.0, -12.8, 180.0]]],
	["bucher_ferme_b", BUCHER, [[64.5, 6.5, 0.0], [58.5, 8.5, 30.0], [65.5, 1.0, 90.0], [57.0, 0.5, 0.0]]],
	["bucher_ferme_a", BUCHER, [[75.0, 21.5, 0.0], [83.0, 20.0, 0.0], [75.5, 26.5, 90.0]]],
	["bucher_feu", BUCHER, [[8.5, -7.5, 30.0], [-9.0, 6.5, -40.0], [6.0, 9.5, 150.0]]],
	["camp_chasseur", CAMP_CHASSEUR, [[-14.0, -27.0, 45.0], [-10.0, -24.0, 40.0], [-24.5, -13.5, 60.0], [6.0, -19.0, 0.0], [-20.0, 4.0, 90.0]]],
	["offrandes_cercle", OFFRANDES, [[-38.0, -32.4, 180.0], [-36.5, -32.8, 160.0], [-39.5, -32.8, 200.0], [-38.0, -35.6, 0.0]]],
	["offrandes_tumulus", OFFRANDES, [[-36.2, -46.4, 170.0], [-39.8, -46.4, 190.0], [-35.6, -45.2, 160.0], [-40.4, -45.2, 200.0]]],
	["poteau_cercle", POTEAU, [[-6.0, -4.2, 225.0], [-8.5, -5.0, 220.0], [-4.0, -8.5, 225.0]]],
	["poteau_tumulus", POTEAU, [[-32.6, -38.8, 200.0], [-33.6, -41.6, 200.0], [-36.8, -38.4, 160.0]]],
	["poteau_grotte", POTEAU, [[79.0, 26.6, 150.0], [74.5, 29.5, 120.0], [82.5, 26.0, 160.0]]],
	["reserve_grotte", RESERVE_BANDITS, [[86.5, -21.5, 120.0], [88.0, -32.5, 60.0], [85.5, -30.0, 90.0], [97.0, -21.0, 210.0]]],
]

static func creer(monde: Node3D) -> void:
	if not PropsQuaternius.v3 or monde.village == null:      # `--sans-props-v3` : les abords de la v2 (A/B)
		return
	var tree := monde.get_tree()
	await tree.physics_frame      # les corps posés pendant la construction entrent dans l'espace physique
	await tree.physics_frame
	var racine := Node3D.new()
	racine.name = "AbordsProps"
	monde.add_child(racine)
	var posees: Array = []      # disques [Vector2, rayon] des items au sol déjà posés
	var nb := 0
	var t0 := Time.get_ticks_msec()
	for l: Array in LIEUX:
		var fait := false
		for a: Array in l[2] + _spirale(l[2][0]):
			for gl: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				var lac := deg_to_rad(float(a[2]))
				var b := Basis(Vector3.UP, lac)
				var o := Vector3(float(a[0]), 0, float(a[1])) + b * Vector3(gl.x, 0, gl.y)
				var raison := _essai(monde, l[1], o, lac, posees)
				if raison == "":
					_poser(monde, racine, String(l[0]), l[1], o, lac, posees)
					print("PropsMax : abords, composition posée %s (%.1f, %.1f) lacet %.0f sol %.2f" % [l[0], o.x, o.z, float(a[2]), monde.hauteur(o.x, o.z)])
					fait = true
					nb += 1
					break
				elif "--compos-debug" in OS.get_cmdline_user_args():
					print("PropsMax debug abords : %s (%.1f, %.1f) %s" % [l[0], o.x, o.z, raison])
			if fait:
				break
		if not fait:
			push_warning("PropsMax : abords, composition refusée partout : " + String(l[0]))
	print("PropsMax : abords, %d compositions en %d ms" % [nb, Time.get_ticks_msec() - t0])

## Dernier recours (terrain en pente autour des ancres choisies) : couronnes de 3, 5 et 7 m autour de la première ancre, même lacet.
## Les glissements de ±1/±2 m s'y appliquent aussi : chaque essai est bon marché (quelques requêtes), l'ordre reste déterministe.
static func _spirale(a: Array) -> Array:
	var r: Array = []
	for d: float in [3.0, 5.0, 7.0]:
		for k in 8:
			var t := TAU * float(k) / 8.0 + d * 0.3
			r.append([float(a[0]) + cos(t) * d, float(a[1]) + sin(t) * d, float(a[2])])
	return r

## Repère monde d'un item (pied), sans la hauteur.
static func _xf_item(it: Array, o: Vector3, lac: float) -> Transform3D:
	var e := Vector3.ONE
	if it.size() > 6:
		e = it[6] if it[6] is Vector3 else Vector3.ONE * float(it[6])
	var b := Basis(Vector3.UP, lac) * Basis(Vector3.UP, deg_to_rad(float(it[3])))
	if it.size() > 7 and float(it[7]) != 0.0:
		b = b * Basis(Vector3.RIGHT, deg_to_rad(float(it[7])))
	if it.size() > 8 and float(it[8]) != 0.0:
		b = b * Basis(Vector3.BACK, deg_to_rad(float(it[8])))
	var p := o + Basis(Vector3.UP, lac) * Vector3(float(it[1]), 0, float(it[2]))
	return Transform3D(b * Basis.from_scale(e), p)

## Coins (x, z) de la boîte de l'item en monde.
static func _coins(id: String, xf: Transform3D) -> Array:
	var bb := PropsQuaternius.boite(id)
	var r: Array = []
	for cx: float in [bb.position.x, bb.end.x]:
		for cy: float in [bb.position.y, bb.end.y]:
			for cz: float in [bb.position.z, bb.end.z]:
				var w := xf * Vector3(cx, cy, cz)
				r.append(Vector2(w.x, w.z))
	return r

static func _essai(monde: Node3D, items: Array, o: Vector3, lac: float, posees: Array) -> String:
	var espace: PhysicsDirectSpaceState3D = monde.get_world_3d().direct_space_state
	var terrain: Object = monde.get_meta("corps_terrain", null)
	for it: Array in items:
		if float(it[4]) > 0.05:
			continue
		var id := String(it[0])
		if not PropsQuaternius.existe(id):
			return "absent " + id
		var xf := _xf_item(it, o, lac)
		var cs := _coins(id, xf)
		var mn := Vector2(INF, INF)
		var mx := -mn
		for c: Vector2 in cs:
			mn = mn.min(c)
			mx = mx.max(c)
		var centre := (mn + mx) * 0.5
		var r := maxf((mx - mn).length() * 0.5, 0.15)
		var hmin := INF
		var hmax := -INF
		for c: Vector2 in [mn, mx, Vector2(mn.x, mx.y), Vector2(mx.x, mn.y), centre]:
			var h: float = monde.hauteur(c.x, c.y)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		if hmax - hmin > (PENTE_GRAND if _grand(it, r) else PENTE_MAX):
			return "pente %s %.2f (r %.1f)" % [id, hmax - hmin, r]
		if monde.arbres_autour(Vector3(centre.x, 0, centre.y), r + 0.8) > 0:
			return "arbre " + id
		if monde.chemins != null and monde.chemins.distance(centre.x, centre.y) < r + 2.0:
			return "chemin " + id
		if monde._pres_du_chemin(centre.x, centre.y, r + 2.2):
			return "sentier " + id
		for ct: Array in RuesVillage.CHEMINS_TERRE:
			if RuesVillage._d_polyligne(centre, ct[0]) < float(ct[1]) * 0.5 + r + 0.6:
				return "chemin de terre " + id
		for pd: Array in posees:
			if centre.distance_to(pd[0]) < r + float(pd[1]) - 0.1:
				return "composition " + id
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		var bb := PropsQuaternius.boite(id)
		bs.size = Vector3(mx.x - mn.x + 0.2, maxf(bb.size.y * xf.basis.get_scale().y, 0.3), mx.y - mn.y + 0.2)
		q.shape = bs
		q.transform = Transform3D(Basis(), Vector3(centre.x, hmax + 0.15 + bs.size.y * 0.5, centre.y))
		q.collide_with_areas = false
		if terrain != null:
			q.exclude = [(terrain as CollisionObject3D).get_rid()]
		for hit: Dictionary in espace.intersect_shape(q, 8):
			if hit.get("collider") is CharacterBody3D or hit.get("collider") is RigidBody3D:
				continue
			return "corps %s %s" % [id, str(hit.get("collider").name) if hit.get("collider") != null else "?"]
	return ""

static func _poser(monde: Node3D, racine: Node3D, nom: String, items: Array, o: Vector3, lac: float, posees: Array) -> void:
	var poses: Array = []
	var pieds: Array = []      # [centre (x, z), y du dessus] des items au sol, pour les items posés dessus
	for it: Array in items:
		if float(it[4]) > 0.05:
			continue
		var id := String(it[0])
		var xf := _xf_item(it, o, lac)
		var cs := _coins(id, xf)
		var mn := Vector2(INF, INF)
		var mx := -mn
		for c: Vector2 in cs:
			mn = mn.min(c)
			mx = mx.max(c)
		var centre := (mn + mx) * 0.5
		var h := INF
		for c: Vector2 in [mn, mx, Vector2(mn.x, mx.y), Vector2(mx.x, mn.y), centre]:
			h = minf(h, monde.hauteur(c.x, c.y))
		var ht: float = monde.hauteur(centre.x, centre.y)
		var y := lerpf(h, ht, 0.5) - 0.03     # à moitié de la pente : un coin s'enfonce, aucun ne flotte de plus de quelques cm
		if _grand(it, maxf((mx - mn).length() * 0.5, 0.15)):
			xf = _incline(monde, id, xf)      # grand item : suit le terrain, posé par le milieu de son dessous
			var bb := PropsQuaternius.boite(id)
			var dessous := xf * Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
			y = monde.hauteur(dessous.x, dessous.z) - 0.04
			xf.origin.y += y - dessous.y
		else:
			xf.origin.y = y - _bas(id, xf)
		poses.append([id, xf, bool(it[5])])
		pieds.append([Vector2(xf.origin.x, xf.origin.z), y])
		posees.append([centre, maxf((mx - mn).length() * 0.5, 0.15)])
	for it: Array in items:
		if float(it[4]) <= 0.05:
			continue
		var xf := _xf_item(it, o, lac)
		var q := Vector2(xf.origin.x, xf.origin.z)
		var y0 := 0.0
		var dmin := INF
		for pd: Array in pieds:
			var dd: float = q.distance_to(pd[0])
			if dd < dmin:
				dmin = dd
				y0 = float(pd[1])
		xf.origin.y = y0 + float(it[4]) - _bas(String(it[0]), xf)
		poses.append([String(it[0]), xf, bool(it[5])])
	var mi := PropsQuaternius.lot_pq(racine, nom, poses, "exterieur", monde.village)
	if mi != null:
		mi.visibility_range_end = PORTEE
		mi.visibility_range_end_margin = 4.0

## Grand item solide (charrette, tente, rondin-banc) : incliné comme le terrain au lieu d'être posé à plat à mi-pente.
static func _grand(it: Array, r: float) -> bool:
	return bool(it[5]) and r > 1.0

## Incline le repère de l'item selon la pente du terrain mesurée aux bouts de ses deux axes (normale du plan moyen).
static func _incline(monde: Node3D, id: String, xf: Transform3D) -> Transform3D:
	var bb := PropsQuaternius.boite(id)
	var c := xf * bb.get_center()
	var ax := xf.basis.x * (bb.size.x * 0.5)
	var az := xf.basis.z * (bb.size.z * 0.5)
	ax.y = 0.0
	az.y = 0.0
	var lx := maxf(ax.length(), 0.2)
	var lz := maxf(az.length(), 0.2)
	var gx := (float(monde.hauteur(c.x + ax.x, c.z + ax.z)) - float(monde.hauteur(c.x - ax.x, c.z - ax.z))) / (2.0 * lx)
	var gz := (float(monde.hauteur(c.x + az.x, c.z + az.z)) - float(monde.hauteur(c.x - az.x, c.z - az.z))) / (2.0 * lz)
	var n := (Vector3.UP - ax / lx * gx - az / lz * gz).normalized()
	var q := Quaternion(Vector3.UP, n)
	return Transform3D(Basis(q) * xf.basis, xf.origin)

## Point le plus bas de la boîte de l'item sous son origine (une poutre dressée, une planche tournée) : posé sur ce point.
static func _bas(id: String, xf: Transform3D) -> float:
	var bb := PropsQuaternius.boite(id)
	var lo := INF
	for cx: float in [bb.position.x, bb.end.x]:
		for cy: float in [bb.position.y, bb.end.y]:
			for cz: float in [bb.position.z, bb.end.z]:
				lo = minf(lo, (xf.basis * Vector3(cx, cy, cz)).y)
	return lo
