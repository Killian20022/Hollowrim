class_name LanceurSorts
extends RefCounted
## Exécute les sorts (DonneesSort) : projectiles, éclairs en chaîne, jets canalisés, zones, soin, enchantement. Ne connaît
## que les TYPES de sorts (DonneesSort.Type / Portee), jamais un sort par son nom. Partagé par le joueur (vise les
## « ennemis ») et le mage ennemi (vise le « joueur »). Les dégâts passent par DegatsCombat.appliquer (statuts, réactions,
## combos : Elements) ; ceux qui visent le joueur par joueur.recevoir_coup (garde, parade, protection).

## Pas des dégâts d'un sort canalisé (s) : tics réguliers, indépendants des images par seconde.
const TIC_CANAL := 0.2
## Aide à la visée : une cible à moins de ce demi-angle (°) du réticule est visée en son centre.
const AIDE_VISEE := 5.0
## Explosion d'un projectile (rayon > 0) : part des dégâts reçue par les voisins.
const PART_EXPLOSION := 0.5
const PORTEE_PROJECTILE := 60.0

var lanceur: Node3D
var vise := "ennemis"
var cible_joueur: Node3D
## Horloge (s) et derniers coups de sort par cible (bonus « épée après sort » du guerrier-mage).
var horloge := 0.0
var derniers_coups := {}
## Journal des coups portés (tests) : [{sort, cible, degats, resultat}].
var journal: Array = []
var _accum := {}
static var _doubles := {}

func _init(l: Node3D = null, camp := "ennemis") -> void:
	lanceur = l
	vise = camp

func avancer(dt: float) -> void:
	horloge += dt

# ------------------------------------------------------------------ versions

## Version double d'un sort (mêmes données × multiplicateurs de `sort.double` ; clés « *_plus » ajoutées). En cache.
static func version_double(s: DonneesSort) -> DonneesSort:
	if s == null or s.double.is_empty():
		return s
	if _doubles.has(s.id) and _doubles[s.id][0] == s:
		return _doubles[s.id][1]
	var d := s.duplicate() as DonneesSort
	for k in s.double:
		var v = s.double[k]
		if String(k).ends_with("_plus"):
			var champ := String(k).trim_suffix("_plus")
			d.set(champ, int(d.get(champ)) + int(v))
		elif k == "cout":
			d.cout = s.cout * float(v)
			d.cout_par_seconde = s.cout_par_seconde * float(v)
		elif k == "reduction":
			d.reduction_physique = minf(0.9, s.reduction_physique * float(v))
			d.reduction_magique = minf(0.97, s.reduction_magique * float(v))
		elif d.get(k) != null:
			d.set(k, float(d.get(k)) * float(v))
	d.id = s.id
	_doubles[s.id] = [s, d]
	return d

## Coût de lancement (mana) selon la charge.
static func cout(s: DonneesSort, charge := 1.0) -> float:
	if s.se_charge():
		return s.cout * lerpf(s.cout_charge_min, 1.0, clampf(charge, 0.0, 1.0))
	return s.cout

static func facteur_charge(s: DonneesSort, charge: float) -> float:
	return lerpf(s.degats_charge_min, 1.0, clampf(charge, 0.0, 1.0)) if s.se_charge() else 1.0

# ------------------------------------------------------------------ visée

## Point visé depuis `oeil` le long de `avant` (premier obstacle, ou cible proche du réticule : aide à la visée).
## `couloir` > 0 (zones visées) : une cible à moins de `couloir` m de la ligne de visée, avant l'obstacle, est visée.
func viser(oeil: Vector3, avant: Vector3, portee: float, couloir := 0.0) -> Dictionary:
	var res := {"point": oeil + avant * portee, "normale": -avant, "cible": null, "decor": false}
	var monde := _monde()
	if monde != null:
		var q := PhysicsRayQueryParameters3D.create(oeil, oeil + avant * portee)
		q.exclude = _exclus_rids()
		var r := monde.intersect_ray(q)
		if not r.is_empty():
			res["point"] = r["position"]
			res["normale"] = r["normal"]
			res["decor"] = true
	if vise == "ennemis":
		var meilleur := AIDE_VISEE
		for c in Elements.cibles_dans(oeil, portee):
			var centre := Elements._centre(c)
			var a := rad_to_deg(avant.angle_to(centre - oeil))
			if a < meilleur and oeil.distance_to(centre) <= oeil.distance_to(res["point"]) + 0.6 and not _mur_entre(oeil, centre):
				meilleur = a
				res["cible"] = c
				res["point"] = centre
				res["normale"] = -avant
				res["decor"] = false
		if couloir > 0.0 and res["cible"] == null:
			var plus_pres := oeil.distance_to(res["point"]) + 0.6
			for c in Elements.cibles_dans(oeil, portee):
				var rel := Elements._centre(c) - oeil
				var t := rel.dot(avant)
				if t > 0.5 and t < plus_pres and (rel - avant * t).length() <= couloir and not _mur_entre(oeil, Elements._centre(c)):
					plus_pres = t
					res["cible"] = c
					res["point"] = Elements._centre(c)
					res["decor"] = false
	return res

func _monde() -> PhysicsDirectSpaceState3D:
	if lanceur == null or not lanceur.is_inside_tree():
		return null
	return lanceur.get_world_3d().direct_space_state

func _exclus_rids() -> Array[RID]:
	var ex: Array[RID] = []
	if lanceur is CollisionObject3D:
		ex.append((lanceur as CollisionObject3D).get_rid())
	for g in ["ennemis", "cibles_combat"]:
		for e in lanceur.get_tree().get_nodes_in_group(g):
			if e is CollisionObject3D:
				ex.append((e as CollisionObject3D).get_rid())
	if cible_joueur is CollisionObject3D:
		ex.append((cible_joueur as CollisionObject3D).get_rid())
	return ex

func _mur_entre(a: Vector3, b: Vector3) -> bool:
	var monde := _monde()
	if monde == null or a.distance_to(b) < 0.1:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = _exclus_rids()
	return not monde.intersect_ray(q).is_empty()

## Sol sous un point (zones visées) : 6 m plus bas au plus.
func _au_sol(p: Vector3) -> Vector3:
	var monde := _monde()
	if monde == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 6.0)
	q.exclude = _exclus_rids()
	var r := monde.intersect_ray(q)
	return r["position"] if not r.is_empty() else p

# ------------------------------------------------------------------ dégâts

## Un coup de sort sur une cible. `facteur` : charge, rebond, explosion…
func frapper(cible: Node, quantite: float, s: DonneesSort, point: Vector3, direction: Vector3, continu := false, stagger := -1.0) -> String:
	if cible == null or not is_instance_valid(cible):
		return ""
	var origine := lanceur.global_position if lanceur != null else point - direction
	var res := ""
	if vise == "joueur":
		# statuts sur le JOUEUR : gel = ralentissement (joueur.ralentir), choc = secousse, corruption = mana volé
		var opt := {"type": s.type_degats, "recul": 1.5 if continu else 2.5}
		if s.imparable > 0.0:
			opt["imparable"] = s.imparable
		match s.statut:
			"gel":
				opt["ralenti"] = Vector2(s.duree_statut, 1.0 - clampf(s.puissance_statut, 0.0, 0.8))
			"choc":
				opt["secousse"] = 0.6
		res = String(cible.recevoir_coup(quantite, origine, opt))
		if res == "touche" and s.vol_mana > 0.0 and cible.get("mana") != null:
			cible.set("mana", maxf(0.0, float(cible.get("mana")) - s.vol_mana))
	else:
		var st := s.stagger if stagger < 0.0 else stagger
		var info := {"type": s.type_degats, "ecole": s.ecole, "attaque": "sort", "sort": s.id, "stagger": st, "point": point,
			"direction": direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD, "lanceur": lanceur,
			"statut": s.statut, "duree_statut": s.duree_statut, "puissance_statut": s.puissance_statut, "drain": s.drain, "continu": continu}
		res = DegatsCombat.appliquer(cible, quantite, origine, st >= 24.0, info)
		if res in ["touche", "tue"]:
			derniers_coups[cible.get_instance_id()] = horloge
	journal.append({"sort": s.id, "cible": cible, "degats": quantite, "resultat": res, "continu": continu})
	return res

## Bonus du coup d'épée qui suit un sort sur la même cible (fenêtre, multiplicateur : regles_mains.json « epee_magie »).
func bonus_apres_sort(cible: Node, fenetre: float, bonus: float) -> float:
	var t = derniers_coups.get(cible.get_instance_id() if cible != null else 0)
	return bonus if t != null and horloge - float(t) <= fenetre else 1.0

# ------------------------------------------------------------------ lancement

## Lance un sort à départ (RAPIDE, CHARGE, ZONE, ENCHANT). `paume` : nœud d'où part le visuel ; `oeil`/`avant` : visée.
## Renvoie un résumé {genre, cibles…} (tests).
func lancer(s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3, charge := 1.0) -> Dictionary:
	var k := facteur_charge(s, charge)
	var depart := paume.global_position if paume != null else oeil
	match s.portee_mode:
		DonneesSort.Portee.PROJECTILE:
			return _projectiles(s, depart, oeil, avant, k)
		DonneesSort.Portee.CHAINE:
			return _chaine(s, depart, oeil, avant, k, s.rebonds)
		DonneesSort.Portee.ZONE_VISEE:
			var v := viser(oeil, avant, s.portee, 1.6)
			return _zone(s, _au_sol(v["point"]), k)
		DonneesSort.Portee.ZONE_SOI:
			return _zone(s, _au_sol(lanceur.global_position), k)
		DonneesSort.Portee.SOI:
			if s.soin > 0.0 and lanceur.has_method("soigner"):
				lanceur.soigner(s.soin * k)
			return {"genre": "soi"}
	return {}

func _projectiles(s: DonneesSort, depart: Vector3, oeil: Vector3, avant: Vector3, k: float) -> Dictionary:
	var v := viser(oeil, avant, PORTEE_PROJECTILE)
	var dir: Vector3 = (Vector3(v["point"]) - depart).normalized()
	var parent := lanceur.get_parent()
	var n := maxi(1, s.nombre)
	var tirs := []
	for i in n:
		var d := dir
		if n > 1:
			# éventail horizontal (éclats), plus un léger décalage vertical alterné
			var ang := deg_to_rad(s.ecart) * (float(i) - float(n - 1) * 0.5)
			d = dir.rotated(Vector3.UP, ang).rotated(dir.cross(Vector3.UP).normalized(), deg_to_rad(s.ecart * 0.3) * (1.0 if i % 2 == 0 else -1.0))
		var visuel := EffetsMagie.projectile_visuel(s.ecole, s.forme)
		var rappel := func(cible: Node, point: Vector3, normale: Vector3) -> void: _impact_projectile(s, k, cible, point, normale, d)
		var exclus: Array = [lanceur] if vise == "ennemis" else [lanceur]
		var p := ProjectileSort.tirer_sort(parent, depart, d, s.vitesse, visuel, rappel, exclus, s.traverse)
		p.genre = {"glace": "givre", "feu": "feu", "electricite": "foudre", "tenebres": "ombre"}.get(s.ecole, "sort")
		p.vise = vise
		p.cible_joueur = cible_joueur
		tirs.append(p)
	return {"genre": "projectile", "projectiles": tirs, "point": v["point"]}

func _impact_projectile(s: DonneesSort, k: float, cible: Node, point: Vector3, normale: Vector3, dir: Vector3) -> void:
	EffetsMagie.impact(s.ecole, point, normale, k * (1.6 if s.rayon > 0.0 else 0.8))
	if cible != null:
		frapper(cible, s.degats * k, s, point, dir, false, s.stagger * k)
	if s.rayon > 0.0:
		EffetsMagie.zone(s.ecole, point, s.rayon, 0.3)
		if vise == "ennemis":
			for c in Elements.cibles_dans(point, s.rayon):
				if c != cible:
					frapper(c, s.degats * k * PART_EXPLOSION, s, Elements._centre(c), Elements._centre(c) - point, false, s.stagger * k * 0.5)

func _chaine(s: DonneesSort, depart: Vector3, oeil: Vector3, avant: Vector3, k: float, rebonds: int) -> Dictionary:
	var v := viser(oeil, avant, s.portee)
	var points: Array[Vector3] = [depart]
	var touchees := []
	var premiere: Node = v["cible"]
	if premiere == null and vise == "ennemis":
		# l'éclair cherche une cible dans un cône plus large (12°) avant de partir dans le vide
		for c in Elements.cibles_dans(oeil, s.portee):
			if rad_to_deg(avant.angle_to(Elements._centre(c) - oeil)) < 12.0 and not _mur_entre(oeil, Elements._centre(c)):
				premiere = c
				break
	if premiere == null:
		points.append(v["point"])
		EffetsMagie.chaine(s.ecole, points)
		EffetsMagie.impact(s.ecole, v["point"], v["normale"], 0.6 * k)
		return {"genre": "chaine", "cibles": touchees}
	var courante: Node = premiere
	var degats := s.degats * k
	while courante != null:
		var c := Elements._centre(courante)
		points.append(c)
		touchees.append(courante)
		frapper(courante, degats, s, c, c - points[points.size() - 2], false, s.stagger * k)
		EffetsMagie.impact(s.ecole, c, (points[points.size() - 2] - c).normalized(), 0.7 * k)
		if touchees.size() > rebonds:
			break
		degats *= s.attenuation_rebond
		var suivante: Node = null
		for e in Elements.cibles_dans(c, s.distance_rebond):
			if not touchees.has(e) and not _mur_entre(c, Elements._centre(e)):
				suivante = e
				break
		courante = suivante
	EffetsMagie.chaine(s.ecole, points)
	return {"genre": "chaine", "cibles": touchees}

## Zone posée à un point choisi par l'appelant (sort de zone télégraphié du mage ennemi).
func zone_en(s: DonneesSort, centre: Vector3, k := 1.0) -> Dictionary:
	return _zone(s, centre, k)

func _zone(s: DonneesSort, centre: Vector3, k: float) -> Dictionary:
	EffetsMagie.zone(s.ecole, centre, s.rayon, maxf(s.duree_zone, 0.6))
	var touchees := []
	if s.duree_zone > 0.0:
		var z := ZoneMagie.new()
		z.rayon = s.rayon
		z.duree = s.duree_zone
		z.intervalle = s.intervalle_zone
		z.attraction = s.attraction
		z.rappel = func(c: Node) -> void: frapper(c, s.degats * k, s, Elements._centre(c), Elements._centre(c) - centre, true, s.stagger * k)
		lanceur.get_parent().add_child(z)
		z.global_position = centre
		return {"genre": "zone", "zone": z}
	if s.attraction > 0.0:
		ZoneMagie.attirer(centre, s.rayon * 1.6, s.attraction * 2.0)
	if vise == "joueur":
		if cible_joueur != null and not bool(cible_joueur.get("mort")):
			var rel := cible_joueur.global_position - centre
			var dy := absf(rel.y)
			rel.y = 0.0
			if rel.length() <= s.rayon + 0.2 and dy < 1.6:
				frapper(cible_joueur, s.degats * k, s, cible_joueur.global_position, cible_joueur.global_position - centre)
				touchees.append(cible_joueur)
		return {"genre": "zone", "cibles": touchees}
	for c in Elements.cibles_dans(centre, s.rayon):
		touchees.append(c)
		frapper(c, s.degats * k, s, Elements._centre(c), Elements._centre(c) - centre, false, s.stagger * k)
	return {"genre": "zone", "cibles": touchees}

# ------------------------------------------------------------------ canalisation

## Une image de canalisation (jet, arc, drain, soin, protection) ; `cle` : la main (tics séparés par main). Les dégâts
## tombent par tics de TIC_CANAL s. Renvoie les cibles touchées à ce tic (vide entre deux tics).
func canaliser(s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3, dt: float, cle: String) -> Array:
	var touchees := []
	if s.portee_mode == DonneesSort.Portee.SOI:
		if s.soin > 0.0 and lanceur.has_method("soigner"):
			lanceur.soigner(s.soin * dt)
		return touchees
	var v := viser(oeil, avant, s.portee)
	var fin: Vector3 = v["point"]
	var depart := paume.global_position if paume != null else oeil
	var portee_vue := minf(s.portee, depart.distance_to(fin) + 0.3)
	EffetsMagie.jet(s.ecole, paume, (fin - depart).normalized(), portee_vue, s.largeur, true)
	_accum[cle] = float(_accum.get(cle, 0.0)) + dt
	if float(_accum[cle]) < TIC_CANAL:
		return touchees
	_accum[cle] = float(_accum[cle]) - TIC_CANAL
	var q := s.degats * TIC_CANAL
	var st := s.stagger * TIC_CANAL
	if vise == "joueur":
		if cible_joueur != null and _dans_jet(oeil, avant, s, cible_joueur.global_position + Vector3(0, 1.0, 0)):
			frapper(cible_joueur, q, s, cible_joueur.global_position, avant, true, st)
			touchees.append(cible_joueur)
		return touchees
	var candidats := []
	for c in Elements.cibles_dans(oeil, s.portee + 0.5):
		if _dans_jet(oeil, avant, s, Elements._centre(c)) and not _mur_entre(oeil, Elements._centre(c)):
			candidats.append(c)
	var maxi_cibles := 1 + s.traverse
	for c in candidats:
		if touchees.size() >= maxi_cibles:
			break
		touchees.append(c)
		frapper(c, q, s, Elements._centre(c), avant, true, st)
	# rebonds (arc électrique double, drain multiple) depuis la première cible
	if s.rebonds > 0 and not touchees.is_empty():
		var pts: Array[Vector3] = [Elements._centre(touchees[0])]
		var courante: Node = touchees[0]
		var qq := q
		for i in s.rebonds:
			var suivante: Node = null
			for e in Elements.cibles_dans(Elements._centre(courante), s.distance_rebond):
				if not touchees.has(e):
					suivante = e
					break
			if suivante == null:
				break
			qq *= s.attenuation_rebond
			touchees.append(suivante)
			pts.append(Elements._centre(suivante))
			frapper(suivante, qq, s, Elements._centre(suivante), avant, true, st * 0.5)
			courante = suivante
		if pts.size() > 1:
			EffetsMagie.chaine(s.ecole, pts)
	return touchees

func arreter_jet(s: DonneesSort, paume: Node3D, cle: String) -> void:
	_accum.erase(cle)
	if s != null and paume != null:
		EffetsMagie.jet(s.ecole, paume, Vector3.FORWARD, 0.0, 0.0, false)

func _dans_jet(oeil: Vector3, avant: Vector3, s: DonneesSort, centre: Vector3) -> bool:
	var rel := centre - oeil
	var t := rel.dot(avant)
	if t < 0.0 or t > s.portee + 0.4:
		return false
	var perp := (rel - avant * t).length()
	# le jet s'élargit avec la distance (cône), plus le rayon du corps
	return perp <= s.largeur * 0.5 * (0.5 + 0.5 * t / maxf(s.portee, 0.1)) + 0.45
