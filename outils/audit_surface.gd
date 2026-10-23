extends RefCounted
## Passe D — collecteur SURFACE de outils/audit_interpenetrations.gd (--lieu=village|exterieur) : objets enfoncés, flottants,
## imbriqués, dans l'eau, sur les chemins, dans les bâtiments. Appelé par l'audit commun (même interface : --max, --poses,
## code de sortie = nombre de cas graves) ; rapport JSON en plus : captures/audit/interpenetrations_<lieu>.json.
## Deux familles d'objets :
##  1. COLLISIONS (StaticBody3D hors terrain) = mobilier, clôtures, rochers à collision, piles, intérieurs :
##     flottant  : rayons verticaux sous la base (5 points de l'emprise) : aucun appui à moins de 5 cm (hors plateaux/lisses
##                 minces et intérieurs : collisions simplifiées) ;
##     enfoncé   : le relief (maillage exact) recouvre plus de 40 % de la hauteur d'un petit objet (mobilier, piles) ;
##     imbriqué  : points d'échantillon de la forme qui tombent dans la forme d'un AUTRE objet (meta « objet » posée par
##                 MobilierVillage, sinon voisinage dans le même corps), part ≥ 25 % (≥ 60 % sans étiquette).
##  2. DÉCOR SANS COLLISION (MultiMesh d'Instanciation, relevés par Instanciation.journal : marche aussi sans fenêtre) :
##     flottant, dans l'eau (lac/rivière), sur un chemin ou dans les pavés, dans l'emprise d'un bâtiment, dans une collision.
## Gravités : 2 grave (visible et net), 1 moyen (visible de près), 0 léger (info).
const Base := preload("res://outils/audit_base.gd")
const PRES := 0.05            # appui toléré sous une base (m)

var m: Node3D
var lieu := "village"
var R: Base.Rapport
var cas: Array = []           # {grav, cat, genre, id, p, mesure, txt} (format de l'audit commun)
var ss: PhysicsDirectSpaceState3D
var ter: RID
var sols := {}                # RID → vrai : corps qui servent de sol (terrain, glace du lac)
var eau: Node = null
var compte := {}              # "cat/grav" → n

func _ajout(cat: String, grav: String, p: Vector3, msg: String, mesure := 0.0) -> void:
	R.ajouter(cat, grav, p, msg)
	var nom := msg.get_slice(" : ", 0).get_slice(" dans ", 0).get_slice(" sur ", 0)
	cas.append({"grav": {"grave": 2, "moyen": 1, "mineur": 0}.get(grav, 0), "cat": cat, "genre": nom.get_slice(" (", 0).get_slice("#", 0).get_slice("/", 0),
		"id": nom, "p": p, "mesure": mesure, "txt": msg})
	var k := "%s/%s" % [cat, grav]
	compte[k] = int(compte.get(k, 0)) + 1

# ------------------------------------------------------------------ zones

func _dans_zone(x: float, z: float, y := 0.0) -> bool:
	match lieu:
		"village":
			return y > -60.0 and ReliefVillage.dans_enceinte(x, z, 3.0)
		"exterieur":
			return y > -60.0 and absf(x) <= 112.0 and absf(z) <= 112.0 and not ReliefVillage.dans_enceinte(x, z, 3.0)
		"crypte":
			return y < -60.0 and y > -200.0
		"grotte":
			return y < -60.0 and (m.grotte_acces == null or Vector2(x, z).distance_to(Vector2(m.grotte_acces.global_position.x, m.grotte_acces.global_position.z)) < 400.0)
	return false

func hm(x: float, z: float) -> float:
	return DetailsSol.hauteur_maillage(m, x, z)

## Emprise d'un bâtiment du village (pivot, demi, décalage) contenant (x, z) : nom du pivot, ou "".
func _batiment(x: float, z: float, marge := 0.0) -> String:
	if m.village == null:
		return ""
	for e: Array in m.village.emprises:
		var piv: Node3D = e[0]
		if not is_instance_valid(piv):
			continue
		var l := piv.global_transform.affine_inverse() * Vector3(x, piv.global_position.y, z)
		var demi: Vector2 = e[1]
		var dec: Vector2 = e[2]
		if absf(l.x - dec.x) < demi.x - marge and absf(l.z - dec.y) < demi.y - marge:
			return String(piv.name)
	for e in VillageBati.EXTERIEURS:
		var l2 := Vector2(x - float(e[0]), z - float(e[1])).rotated(deg_to_rad(float(e[4])))
		if absf(l2.x) < float(e[2]) * 0.5 - marge and absf(l2.y) < float(e[3]) * 0.5 - marge:
			return "ferme(%.0f,%.0f)" % [float(e[0]), float(e[1])]
	return ""

## Chemin sous (x, z) à `marge` près : "" ou le nom du chemin (« témoin », « feu-village », « rue », « place », « palier », « terre »).
func _chemin(x: float, z: float, marge: float) -> String:
	var p := Vector2(x, z)
	if m.chemins != null and m.chemins.distance(x, z) < 1.2 + marge:
		return "témoin"
	if m._pres_du_chemin(x, z, 1.3 + marge):
		return "feu-village"
	if RuesVillage._d_polygone(p, RuesVillage.PLACE) < marge or Geometry2D.is_point_in_polygon(p, PackedVector2Array(RuesVillage.PLACE)):
		return "place"
	for r: Array in RuesVillage.RUES:
		if RuesVillage._d_polyligne(p, r[0]) < float(r[1]) * 0.5 + marge:
			return "rue"
	for pr: Rect2 in RuesVillage.PALIERS:
		if pr.grow(marge).has_point(p):
			return "palier"
	if RuesVillage.COULOIR.grow(marge).has_point(p):
		return "escalier"
	for c: Array in RuesVillage.CHEMINS_TERRE:
		if RuesVillage._d_polyligne(p, c[0]) < float(c[1]) * 0.5 + marge:
			return "terre"
	return ""

## Profondeur d'eau sous (x, z) (lac ou rivière ; 0 au sec), avec le nom de l'eau.
func _eau(x: float, z: float, h: float) -> Array:
	if eau == null:
		return [0.0, ""]
	if eau.dans_lac(x, z) and h < EauVillage.LAC_NIVEAU:
		return [EauVillage.LAC_NIVEAU - h, "lac"]
	var f: float = eau.fond_riviere(x, z)
	if f < 999.0:
		var n: float = eau.niveau_riviere(x, z)
		if n - h > 0.05:
			return [n - h, "rivière"]
	return [0.0, ""]

# ------------------------------------------------------------------ formes

## Boîte locale d'une forme simple (centrée sur l'origine de la forme).
func _aabb_locale(f: Shape3D) -> AABB:
	if f is BoxShape3D:
		var s: Vector3 = (f as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if f is CylinderShape3D:
		var c := f as CylinderShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2, c.height, c.radius * 2))
	if f is CapsuleShape3D:
		var k := f as CapsuleShape3D
		return AABB(Vector3(-k.radius, -k.height * 0.5, -k.radius), Vector3(k.radius * 2, k.height, k.radius * 2))
	if f is SphereShape3D:
		var r: float = (f as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2)
	if f is ConvexPolygonShape3D:
		var pts := (f as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		var b := AABB(pts[0], Vector3.ZERO)
		for q in pts:
			b = b.expand(q)
		return b
	return AABB()

## Points d'échantillon à l'intérieur d'une forme (repère local), 3×3×3 resserrés à 70 %.
func _echantillons(f: Shape3D) -> PackedVector3Array:
	var b := _aabb_locale(f)
	var out := PackedVector3Array()
	var cyl := f is CylinderShape3D or f is CapsuleShape3D
	for i in 3:
		for j in 3:
			for k in 3:
				var t := Vector3(i, j, k) * 0.5 - Vector3.ONE * 0.5   # -0.5..0.5
				var p := b.get_center() + t * b.size * 0.7
				if cyl and Vector2(t.x, t.z).length() > 0.5:
					continue
				out.append(p)
	return out

class Forme:
	var noeud: CollisionShape3D
	var corps: CollisionObject3D
	var xf: Transform3D
	var boite: AABB          # monde
	var groupe: String
	var nom: String

func _nom_objet(cs: CollisionShape3D, co: CollisionObject3D) -> String:
	if cs.has_meta("objet"):
		return String(cs.get_meta("objet"))
	var parent := co.get_parent()
	return "%s/%s" % [parent.name if parent != null else "?", co.name]

func _formes() -> Array:
	var res: Array = []
	for co: CollisionObject3D in m.find_children("*", "StaticBody3D", true, false):
		if co.get_rid() == ter:
			continue
		for cs in co.get_children():
			if not (cs is CollisionShape3D) or (cs as CollisionShape3D).disabled or (cs as CollisionShape3D).shape == null:
				continue
			var sh := (cs as CollisionShape3D).shape
			if sh is ConcavePolygonShape3D or sh is HeightMapShape3D or sh is WorldBoundaryShape3D:
				continue
			var f := Forme.new()
			f.noeud = cs
			f.corps = co
			f.xf = (cs as CollisionShape3D).global_transform
			f.boite = f.xf * _aabb_locale(sh)
			var c := f.boite.get_center()
			if not _dans_zone(c.x, c.z, c.y):
				continue
			f.nom = _nom_objet(cs, co)
			f.groupe = String(cs.get_meta("objet")) if cs.has_meta("objet") else ""
			res.append(f)
	return res

func _meme_objet(a: Forme, b: Forme) -> bool:
	if a.groupe != "" or b.groupe != "":
		return a.groupe == b.groupe
	# sans étiquette : pièces voisines d'un même corps (un poteau et sa traverse, les planches d'une table)
	return a.corps == b.corps and a.boite.get_center().distance_to(b.boite.get_center()) < 1.2

func _petit(f: Forme) -> bool:
	var s := f.boite.size
	return maxf(s.x, s.z) <= 3.6 and s.y <= 4.6 and s.x * s.y * s.z <= 8.0

## Appui le plus haut sous (x, y0, z) (tout corps), ou -INF.
func _appui(x: float, y0: float, z: float, exclure: Array[RID]) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y0, z), Vector3(x, y0 - 3.0, z))
	q.exclude = exclure
	var r := ss.intersect_ray(q)
	return -INF if r.is_empty() else (r["position"] as Vector3).y

func _controler_formes() -> void:
	var formes := _formes()
	var par_noeud := {}
	for f: Forme in formes:
		par_noeud[f.noeud] = f
	var n_petits := 0
	for f: Forme in formes:
		if not _petit(f):
			continue
		n_petits += 1
		var b := f.boite
		var c := b.get_center()
		var bas := b.position.y
		var dans_bat := _batiment(c.x, c.z, 0.2) != ""
		# --- flottant : aucun appui sous la base (5 points)
		var ecart := INF
		var hx := b.size.x * 0.3
		var hz := b.size.z * 0.3
		var h_rel := -INF
		var dep := minf(0.02, b.size.y * 0.3)   # départ juste au-dessus de la base : un plancher affleurant est vu
		for d: Vector2 in [Vector2.ZERO, Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
			var a := maxf(_appui(c.x + d.x, bas + dep, c.z + d.y, []), hm(c.x + d.x, c.z + d.y))   # base enterrée = appuyée
			ecart = minf(ecart, bas - a)
			h_rel = maxf(h_rel, hm(c.x + d.x, c.z + d.y))
		# plateaux, lisses, planches (≤ 15 cm) : portés par des pieds sans collision ; intérieurs : collisions simplifiées
		# (piles de tonneaux couchés en cylindres debout) → relecture visuelle seulement
		var mince := minf(b.size.y, minf(b.size.x, b.size.z)) <= 0.15
		if not mince and not dans_bat and ecart > PRES and ecart < 2.9 and bas - h_rel < 1.2:
			var grav := "grave" if ecart > 0.2 else ("moyen" if ecart > 0.1 else "mineur")
			_ajout("flottant", grav, c, "%s : base %.2f m au-dessus de tout appui (forme %s %.1f×%.1f×%.1f)" % [f.nom, ecart, f.noeud.shape.get_class(), b.size.x, b.size.y, b.size.z])
		# --- enfoncé dans le relief (petits objets dehors)
		var structure := f.corps.name in ["CollisionsRues", "CollisionsArbres", "CollisionsRochers"] or f.corps.get_parent() is Node and f.corps.get_parent().name == "SolV2Decor"
		# enfoncé : mobilier (étiqueté) et petits objets du village (piles, tas de bois) ; les pierres (abords, composition,
		# gué) sont enfoncées à dessein
		var objet_village: bool = f.groupe != "" or (m.village != null and f.corps.get_parent() == m.village and b.size.y < 1.6)
		if not dans_bat and not structure and objet_village:
			var enf := h_rel - bas
			var part := enf / maxf(b.size.y, 0.01)
			if enf > 0.12 and part > 0.4 and bas > h_rel - 3.0:
				_ajout("enfonce", "grave" if part > 0.65 else "moyen", c, "%s : %.0f %% de la hauteur sous le relief (%.2f m)" % [f.nom, part * 100.0, enf])
		# --- imbriqué dans un autre objet
		var pts := _echantillons(f.noeud.shape)
		var dedans := {}
		for p in pts:
			var qp := PhysicsPointQueryParameters3D.new()
			qp.position = f.xf * p
			qp.collide_with_areas = false
			for r in ss.intersect_point(qp, 8):
				var co: CollisionObject3D = r["collider"]
				if co == null or sols.has(co.get_rid()) or co is CharacterBody3D or co is RigidBody3D:
					continue
				var own: Node = co.shape_owner_get_owner(co.shape_find_owner(int(r["shape"])))
				if own == f.noeud or not par_noeud.has(own):
					continue
				var g: Forme = par_noeud[own]
				if _meme_objet(f, g):
					continue
				dedans[own] = int(dedans.get(own, 0)) + 1
		for own in dedans:
			var part2 := float(dedans[own]) / float(pts.size())
			if part2 < 0.25:
				continue
			var g2: Forme = par_noeud[own]
			if f.noeud.get_instance_id() > own.get_instance_id() and _petit(g2):
				continue   # paire de deux petits objets : signalée une fois
			var sans_etiquette := f.groupe == "" and g2.groupe == "" and f.corps == g2.corps
			if sans_etiquette and part2 < 0.6:
				continue   # pièces d'une même construction (poteau dans une traverse, coin de mur) : seulement les cas nets
			var grav2 := "moyen" if sans_etiquette else ("grave" if part2 >= 0.5 else "moyen")
			_ajout("imbrique", grav2, c, "%s dans %s : %.0f %% de son volume" % [f.nom, g2.nom, part2 * 100.0])
	R.stats["formes"] = formes.size()
	R.stats["petits_objets"] = n_petits

# ------------------------------------------------------------------ décor (MultiMesh)

func _sorte(e: Dictionary, b: AABB, t := Transform3D()) -> String:
	var src := String(e.get("source", "?"))
	var h := b.size.y
	var larg := maxf(b.size.x, b.size.z)
	if e.has("mesh"):   # largeur sans l'effet de la rotation sur la boîte (même mesure que PosesDecor.filtrer)
		var bl: AABB = (e["mesh"] as Mesh).get_aabb()
		var sc := t.basis.get_scale()
		larg = maxf(bl.size.x * sc.x, bl.size.z * sc.z)
	if h > 3.0:
		return "arbre"
	if src.begins_with("details_sol"):
		return "caillou"
	if larg > 0.9 or h > 0.9:
		return "rocher" if (src.begins_with("rochers") or src.begins_with("sol_v2")) else ("buisson" if h > 0.6 else "souche")
	return "touffe" if h > 0.12 else "caillou"

const GROS := ["arbre", "rocher", "buisson", "souche"]

func _controler_decor() -> void:
	var n := 0
	var sources := {}
	var excl_sols: Array[RID] = []
	for rid in sols:
		excl_sols.append(rid)
	for e: Dictionary in Instanciation.journal:
		if not bool(e.get("principal", true)):
			continue
		var mesh: Mesh = e["mesh"]
		if mesh == null:
			continue
		var bl := mesh.get_aabb()
		for t: Transform3D in e["xfs"]:
			var p := t.origin
			if not _dans_zone(p.x, p.z, p.y):
				continue
			n += 1
			var b := t * bl
			var sorte := _sorte(e, b, t)
			var cle := "%s/%s" % [e["source"], sorte]
			sources[cle] = int(sources.get(cle, 0)) + 1
			var hc := hm(p.x, p.z)
			var bas := b.position.y
			var haut := b.end.y
			var r := clampf(minf(b.size.x, b.size.z) * 0.35, 0.05, 0.8)
			var hmin := hc
			var hmax := hc
			for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				var hh := hm(p.x + d.x, p.z + d.y)
				hmin = minf(hmin, hh)
				hmax = maxf(hmax, hh)
			var nom := "%s (%s)" % [sorte, e["source"]]
			# flottant : l'origine (pied) au-dessus du relief ; on accepte un appui physique (pont, quai, glace, dalle)
			# gros objets : écart au relief SOUS LE CENTRE (sur une pente, le bord aval décolle un peu : normal) ;
			# petits : au point le plus bas de l'emprise
			var pied := p.y if sorte == "arbre" else bas
			var ecart := pied - (hc if sorte in GROS else hmin)
			if ecart > 0.06:
				var appui := _appui(p.x, pied + 0.02, p.z, [])
				if appui > -INF and pied - appui < 0.06:
					ecart = 0.0
			if ecart > 0.06:
				var grav := "grave" if (ecart > 0.25 or (sorte in GROS and ecart > 0.12)) else ("moyen" if ecart > 0.12 else "mineur")
				_ajout("flottant", grav, p, "%s : pied %.2f m au-dessus du relief le plus bas sous lui" % [nom, ecart])
			# dans l'eau
			var w := _eau(p.x, p.z, hc)
			if float(w[0]) > 0.0:
				var prof: float = w[0]
				var grav_e := ""
				if sorte == "rocher":
					var niveau := EauVillage.LAC_NIVEAU if w[1] == "lac" else float(eau.niveau_riviere(p.x, p.z))
					if haut < niveau + 0.05:
						grav_e = "moyen"   # noyé sous la glace / la surface : scintille
				elif sorte == "caillou":
					grav_e = "mineur" if prof < 0.15 else "moyen"
				else:
					grav_e = "grave" if prof > 0.2 else "moyen"
				if grav_e != "":
					_ajout("dans_eau", grav_e, p, "%s dans le %s (%.2f m d'eau)" % [nom, w[1], prof])
			# sur un chemin / dans les pavés
			var rayon := 0.0
			if sorte in ["arbre", "rocher"]:
				rayon = clampf(minf(b.size.x, b.size.z) * 0.3, 0.2, 1.0)
			elif sorte in GROS:
				rayon = PosesDecor.RAYONS.get(sorte, 0.4)
			var ch := _chemin(p.x, p.z, rayon)
			if ch != "":
				if sorte in GROS:
					var dch: float = m.chemins.distance(p.x, p.z) if m.chemins != null else INF
					_ajout("sur_chemin", "grave", p, "%s sur le chemin « %s » (axe témoin à %.2f m, encombrement %.2f, h %.2f)" % [nom, ch, dch, rayon, b.size.y])
				elif ch in ["place", "rue", "palier", "escalier"]:
					_ajout("sur_chemin", "moyen", p, "%s dans les pavés (%s)" % [nom, ch])
			# sous la butte du tertre (collision concave : les requêtes de point ne la voient pas)
			var dome := Vector2(m.TUMULUS.x + PosesDecor.DOME_DECALAGE.x, m.TUMULUS.z + PosesDecor.DOME_DECALAGE.z)
			if lieu == "exterieur" and Vector2(p.x, p.z).distance_to(dome) < PosesDecor.DOME_RAYON - 0.2:
				_ajout("dans_collision", "grave" if sorte in GROS else "moyen", p, "%s enfoui sous la butte du tertre" % nom)
			# dans un bâtiment
			var bat := _batiment(p.x, p.z)
			if bat != "":
				_ajout("dans_batiment", "grave", p, "%s dans l'emprise de %s" % [nom, bat])
			# dans une collision (palissade, mur, mobilier, rocher à collision)
			var hauteurs := [0.3, 1.6] if sorte == "arbre" else [minf(0.15, b.size.y * 0.5)]
			for dy: float in hauteurs:
				var qp := PhysicsPointQueryParameters3D.new()
				qp.position = Vector3(p.x, maxf(hc, bas) + dy, p.z)
				var hits := ss.intersect_point(qp, 4)
				var autre := ""
				for hit in hits:
					var co: CollisionObject3D = hit["collider"]
					if co == null or sols.has(co.get_rid()) or co is CharacterBody3D or co is RigidBody3D:
						continue
					var own: Node = co.shape_owner_get_owner(co.shape_find_owner(int(hit["shape"])))
					if own is Node3D and Vector2((own as Node3D).global_position.x - p.x, (own as Node3D).global_position.z - p.z).length() < 0.45:
						continue   # sa propre collision (tronc, rocher)
					if co.name == "CollisionsArbres" and not sorte in GROS:
						continue   # touffe au pied d'un tronc : cachée
					autre = _nom_objet(own as CollisionShape3D, co) if own is CollisionShape3D else co.name
					break
				if autre != "":
					var grav_c := "grave" if sorte in GROS else "moyen"
					_ajout("dans_collision", grav_c, p, "%s dans la collision de %s" % [nom, autre])
					break
	R.stats["decor_instances"] = n
	R.stats["decor_sources"] = sources

# ------------------------------------------------------------------ maillages isolés (cercle runique, abords du tertre…)

func _controler_maillages() -> void:
	var n := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var chemin := String(mi.get_path())
		if not (chemin.contains("AbordsTumulus") or chemin.contains("Composition") or chemin.contains("Cercle")):
			continue
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		var c := b.get_center()
		if not _dans_zone(c.x, c.z, c.y) or maxf(b.size.x, b.size.z) > 6.0 or minf(b.size.x, minf(b.size.y, b.size.z)) < 0.02 or mi.get_parent() is MeshInstance3D:
			continue   # cartes plates (runes) et pièces portées par un autre maillage
		n += 1
		var bas := b.position.y
		var hmin := INF
		for d: Vector2 in [Vector2.ZERO, Vector2(b.size.x * 0.3, 0), Vector2(-b.size.x * 0.3, 0), Vector2(0, b.size.z * 0.3), Vector2(0, -b.size.z * 0.3)]:
			hmin = minf(hmin, hm(c.x + d.x, c.z + d.y))
		var ecart := bas - hmin
		if ecart > 0.08 and ecart < 3.0:
			var appui := _appui(c.x, bas - 0.01, c.z, [])
			if appui == -INF or bas - appui > 0.06:
				_ajout("flottant", "grave" if ecart > 0.2 else "moyen", c, "maillage %s : base %.2f m au-dessus du relief" % [mi.name, ecart])
	R.stats["maillages_isoles"] = n

# ------------------------------------------------------------------

## Lance les contrôles sur le monde déjà construit (Instanciation.journal doit avoir été ouvert AVANT l'instanciation).
func lancer(arbre: SceneTree, monde: Node3D, lieu_: String) -> Array:
	m = monde
	lieu = lieu_
	R = Base.Rapport.new("interpenetrations_" + lieu)
	# intérieurs posés en tâches différées
	var t_att := 0
	while m.village != null and not m.village.prets and t_att < 1200:
		await arbre.process_frame
		t_att += 1
	for i in 4:
		await arbre.physics_frame
	ss = m.get_world_3d().direct_space_state
	for c in m.get_children():
		if c is StaticBody3D and c.get_child_count() == 16 and (c.get_child(0) as CollisionShape3D).shape is ConcavePolygonShape3D:
			ter = c.get_rid()
	sols[ter] = true
	eau = m.get_node_or_null("EauVillage")
	var t0 := Time.get_ticks_msec()
	_controler_formes()
	_controler_decor()
	_controler_maillages()
	R.stats["duree_ms"] = Time.get_ticks_msec() - t0
	R.stats["par_categorie"] = compte
	var nb := {"grave": 0, "moyen": 0, "mineur": 0}
	for k: String in compte:
		var g := k.get_slice("/", 1)
		nb[g] = int(nb.get(g, 0)) + int(compte[k])
	R.stats["grave"] = nb["grave"]
	R.stats["moyen"] = nb["moyen"]
	R.stats["mineur"] = nb["mineur"]
	R.ecrire()
	print("INTERP %s grave=%d moyen=%d mineur=%d (%d ms) %s" % [lieu, nb["grave"], nb["moyen"], nb["mineur"], R.stats["duree_ms"], JSON.stringify(compte)])
	Instanciation.journal = null
	return cas

## Point de vue dégagé sur `p` (m du sol) : 8 directions × 2 distances, œil à 1,6 m du sol, hors collision, vue non coupée.
## Renvoie "x,z,lacet,tangage" (format des vues « monde »).
static func vue_vers(monde: Node3D, p: Vector3, dist := 3.5) -> String:
	var ss := monde.get_world_3d().direct_space_state
	var meilleur := ""
	var score_max := -INF
	for dd: float in [dist, dist * 1.6]:
		for k in 8:
			var a := TAU * k / 8.0 + 0.4
			var o := Vector2(p.x + cos(a) * dd, p.z + sin(a) * dd)
			var y_o: float = monde.hauteur(o.x, o.y) + 1.6
			var oeil := Vector3(o.x, y_o, o.y)
			var qp := PhysicsPointQueryParameters3D.new()
			qp.position = oeil
			if not ss.intersect_point(qp, 1).is_empty():
				continue
			var cible := p + Vector3(0, 0.25, 0)
			var q := PhysicsRayQueryParameters3D.create(oeil, cible)
			var r := ss.intersect_ray(q)
			var degage := r.is_empty() or (r["position"] as Vector3).distance_to(cible) < 0.6
			var score := (10.0 if degage else 0.0) - absf(y_o - p.y - 1.6) - dd * 0.2
			if score > score_max:
				score_max = score
				var d := Vector2(p.x, p.z) - o
				var lacet := rad_to_deg(atan2(-d.x, -d.y))
				var tangage := rad_to_deg(atan2(cible.y - y_o, d.length()))
				meilleur = "%.1f,%.1f,%.0f,%.0f" % [o.x, o.y, lacet, tangage]
	return meilleur

## Poses de capture (format --captures, vues « monde » de jour) des `nb` pires cas : 4 m au sud-est, regard sur l'objet.
static func ecrire_poses(monde: Node3D, liste: Array, chemin: String, nb: int, filtre := "") -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		return
	var pris: Array = []
	var k := 0
	for c: Dictionary in liste:
		if k >= nb:
			break
		if filtre != "" and String(c["cat"]) != filtre:
			continue
		var p: Vector3 = c["p"]
		var deja := false
		for q: Vector3 in pris:
			if q.distance_to(p) < 2.0:
				deja = true
		if deja:
			continue
		pris.append(p)
		f.store_line("cas%02d_%s monde %s heure=12" % [k, String(c["cat"]), vue_vers(monde, p)])
		k += 1
