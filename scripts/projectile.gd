class_name Projectile
extends Node3D
## Flèche d'archer (bandit, squelette) : vol balistique léger, visible, arrêtée par le monde.
## Le joueur est touché via joueur.recevoir_coup(degats, origine) : garde et parade s'appliquent comme pour un coup d'épée
## (l'origine est prise sur la trajectoire, derrière la flèche, pour que « de face » soit juste).
##
##   Projectile.tirer(parent, depart, direction, tireur, degats) -> Projectile   (vitesse VITESSE m/s, chute GRAVITE m/s²)
##   Projectile.cap_visee(depart, cible, vitesse) -> Vector3  : direction qui compense la chute jusqu'à `cible`.
## Signaux : touche(resultat) avec "touche" | "bloque" | "parade" ; plante(position) quand elle se fiche dans le décor.
## Trait de GIVRE (mage nordique) : Projectile.tirer_givre(parent, depart, direction, tireur, degats, joueur) -> Projectile : éclat de
## glace lumineux, vol tendu (sans chute) et lent (VITESSE_GIVRE : on l'esquive d'un pas de côté), traînée de givre, petite lueur
## bleue ; au joueur : dégâts de glace + ralentissement bref (options de joueur.recevoir_coup) ; il se brise sur le décor.

signal touche(resultat: String)
signal plante(position_: Vector3)

const VITESSE := 40.0     # m/s : flèche d'archer ennemi (la visée compense la chute : Projectile.cap_visee)
const GRAVITE := 5.0
const VIE_VOL := 4.0     # s : au-delà, la flèche disparaît
const VIE_PLANTEE := 15.0 # s : une flèche fichée dans le décor reste visible un moment
const VIE_PLANTEE_JOUEUR := 60.0 # s : flèche du joueur fichée (non ramassable)
const VITESSE_GIVRE := 11.0
## Ralentissement infligé par un trait de givre qui touche : (durée s, facteur de vitesse).
const RALENTI_GIVRE := Vector2(1.8, 0.55)
const COULEUR_GIVRE := Color(0.62, 0.9, 1.6)

var vitesse := Vector3.ZERO
var degats := 10.0
var tireur: CollisionObject3D
var joueur: Node
var plantee := false
var resultat := ""       # "", "touche", "bloque", "parade", "mur"
## "fleche" ou "givre" ; chute appliquée (m/s²) ; options passées à joueur.recevoir_coup (seulement au joueur).
var genre := "fleche"
var gravite := GRAVITE
var options_coup := {}
## Flèche du joueur : peut-elle se ramasser une fois fichée ? (durée de vie au sol : VIE_RAMASSABLE)
var recuperable := false
const VIE_RAMASSABLE := 90.0
const PORTEE_RAMASSAGE := 1.7
## FLÈCHE DU JOUEUR (ArcJoueur) : vraie balistique — gravité terrestre, traînée quadratique légère, le nez suit la vitesse ;
## dégâts selon la vitesse à l'IMPACT : degats × (v / vitesse_reference)², au moins degats_min (énergie cinétique).
const GRAVITE_JOUEUR := 6.5      # chute « de jeu » : un tir horizontal à pleine tension (100 m/s) porte ~60-70 m avant de toucher le sol
const TRAINEE := 0.0003          # décélération = TRAINEE · v² (m/s² ; ~3 m/s² à 100 m/s)
## Flèche fichée dans un corps (ennemi, cadavre, mannequin) : elle y reste ce temps (s), elle suit l'os touché (animation et ragdoll).
const VIE_DANS_CORPS := 30.0
## TRAÎNÉE discrète : fine ligne qui s'estompe vite derrière une flèche en vol (style PS1) ; durée (s) et longueur maximale (m).
const TRAINEE_DUREE := 0.4
const TRAINEE_LONGUEUR := 14.0
const TRAINEE_COULEUR := Color(1.0, 0.8, 0.4)   # doré : se lit sur le ciel clair comme dans le noir
const TRAINEE_LARGEUR := 0.008     ## ruban tourné vers la caméra (une ligne de 1 px disparaissait en vue joueur)
const TRAINEE_LARGEUR_ECRAN := 0.010  ## largeur ~ distance caméra : ~4 px d'écran à toute distance (sinon invisible au loin)
const TRAINEE_FONDU_CAM := 1.5     ## m : invisible contre la caméra, pleine à 1,8 m
## Vue joueur : la flèche file dans l'axe du regard, la traînée se projetterait en un point. Près de la caméra, les points
## anciens sont donc écartés vers le bas-droite (la main) : la traînée se lit comme un sillage qui part de l'arc et converge vers la flèche.
const TRAINEE_ECART := 0.6         ## m, écart maximal (points les plus anciens, tout près de la caméra)
const TRAINEE_ECART_PORTEE := 28.0  ## m : au-delà, plus aucun écart (vue de côté inchangée)
var vitesse_reference := 46.0
var degats_min := 3.0
## Dégâts réellement infligés à l'impact (0 tant qu'elle vole) et vitesse à l'impact.
var degats_impact := 0.0
var vitesse_impact := 0.0
## Point d'impact et direction de vol à l'impact (flèche fichée).
var point_impact := Vector3.ZERO
var dir_impact := Vector3.ZERO
var _modele_fleche: Node3D
var _trainee: MeshInstance3D
var _trainee_pts: Array = []   # [Vector3, âge]
var _dans_corps := false
## Coop (lot 4c) : identifiant réseau (vide hors ligne) ; `distant` = copie d'un projectile tiré sur une autre machine (visuel seulement :
## ne blesse pas les ennemis, ne ramasse rien ; un projectile ENNEMI copié ne blesse que le joueur LOCAL). Voir reseau/reseau_projectiles.gd.
var id_reseau := ""
var distant := false
var _vibre := -1.0
var _t := 0.0
var _ex: Array[RID] = []

static func tirer(parent: Node, depart: Vector3, direction: Vector3, tireur_: CollisionObject3D, degats_ := 10.0, joueur_: Node = null) -> Projectile:
	var p := Projectile.new()
	p.degats = degats_
	p.tireur = tireur_
	p.joueur = joueur_
	p.vitesse = direction.normalized() * VITESSE
	parent.add_child(p)
	p.global_position = depart
	p._orienter()
	ReseauProjectiles.annoncer_ennemi(p, "fleche", VITESSE)
	return p

## Trait de givre du mage nordique (voir l'en-tête).
static func tirer_givre(parent: Node, depart: Vector3, direction: Vector3, tireur_: CollisionObject3D, degats_ := 14.0, joueur_: Node = null, vitesse_ := VITESSE_GIVRE) -> Projectile:
	var p := Projectile.new()
	p.genre = "givre"
	p.gravite = 0.0
	p.degats = degats_
	p.tireur = tireur_
	p.joueur = joueur_
	p.options_coup = {"ralenti": RALENTI_GIVRE, "type": "glace", "recul": 2.5}
	p.vitesse = direction.normalized() * vitesse_
	parent.add_child(p)
	p.global_position = depart
	p._orienter()
	ReseauProjectiles.annoncer_ennemi(p, "givre", vitesse_)
	return p

## Flèche DU JOUEUR (ArcJoueur) : touche les ennemis et les cibles (DegatsCombat.appliquer, comme un coup d'arme), jamais le joueur ;
## une flèche qui se fiche dans le décor peut se ramasser en passant dessus (`recuperable`, tirée au sort par l'arc).
static func tirer_joueur(parent: Node, depart: Vector3, direction: Vector3, tireur_: CollisionObject3D, degats_: float, vitesse_: float, recuperable_ := true) -> Projectile:
	var p := Projectile.new()
	p.genre = "fleche_joueur"
	p.degats = degats_
	p.tireur = tireur_
	p.joueur = tireur_
	p.recuperable = recuperable_
	p.gravite = GRAVITE_JOUEUR
	p.vitesse = direction.normalized() * vitesse_
	parent.add_child(p)
	p.global_position = depart
	p._orienter()
	return p

## Direction de tir qui compense la chute sur la durée du vol (vol quasi tendu : on remonte la visée de ½·g·t²).
static func cap_visee(depart: Vector3, cible: Vector3, vitesse_ := VITESSE) -> Vector3:
	var d := cible - depart
	var t := Vector2(d.x, d.z).length() / vitesse_
	d.y += 0.5 * GRAVITE * t * t
	return d.normalized()

func _ready() -> void:
	if genre == "givre":
		_construire_givre()
		if tireur != null:
			_ex.append(tireur.get_rid())
		return
	# flèche de chasseur (arc_chasseur.py) : l'ORIGINE du projectile est la POINTE (le raycast part de la pointe, la flèche
	# fichée s'enfonce par la pointe) ; le modèle (encoche à l'origine, pointe vers -z) est reculé de sa longueur.
	_modele_fleche = Node3D.new()
	add_child(_modele_fleche)
	var f := ArcModele.creer_fleche()
	f.position.z = ArcModele.longueur_pointe()
	_modele_fleche.add_child(f)
	_trainee = MeshInstance3D.new()
	_trainee.name = "Trainee"
	_trainee.top_level = true
	_trainee.mesh = ImmediateMesh.new()
	_trainee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.vertex_color_use_as_albedo = true
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.no_depth_test = false
	_trainee.material_override = mt
	_trainee.extra_cull_margin = 100.0
	add_child(_trainee)
	if tireur != null:
		_ex.append(tireur.get_rid())

## Éclat de glace : losange allongé (deux pyramides) lumineux, cœur blanc, traînée de cristaux, lueur bleue de 3 m.
func _construire_givre() -> void:
	var m := Palette.lueur(COULEUR_GIVRE)
	for k in 2:
		var pr := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.09
		c.height = 0.34 if k == 0 else 0.2
		c.radial_segments = 4
		c.rings = 1
		pr.mesh = c
		pr.material_override = m
		pr.rotation.x = -PI * 0.5 if k == 0 else PI * 0.5   # pointe vers l'avant (+z après look_at : -z), queue courte
		pr.position.z = -0.17 if k == 0 else 0.1
		add_child(pr)
	var coeur := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.05, 0.3)
	coeur.mesh = b
	coeur.material_override = Palette.lueur(Color(1.6, 1.8, 2.0))
	add_child(coeur)
	var trainee := GPUParticles3D.new()
	trainee.amount = 24
	trainee.lifetime = 0.45
	trainee.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	trainee.process_material = pm
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.04
	cube.material = Palette.lueur(COULEUR_GIVRE * 0.8)
	trainee.draw_pass_1 = cube
	add_child(trainee)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.8, 1.0)
	l.light_energy = 1.4
	l.omni_range = 3.0
	l.shadow_enabled = false
	add_child(l)

static func _materiau(couleur: Color, lueur: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = couleur.lerp(Color.WHITE, lueur * 0.35)
	return m

func _orienter() -> void:
	if vitesse.length() > 0.01:
		var haut := Vector3.UP if absf(vitesse.normalized().y) < 0.98 else Vector3.RIGHT
		look_at(global_position + vitesse, haut)

## Dégâts d'une flèche du joueur qui touche à la vitesse v (énergie cinétique).
func degats_pour(v: float) -> float:
	var k := clampf(v / maxf(vitesse_reference, 1.0), 0.0, 1.2)
	return maxf(degats_min, degats * k * k)

## Fichée : la flèche reste à l'angle de son vol, la pointe enfoncée selon la vitesse, et vibre un instant.
## `dans` : nœud qui la porte (os d'un corps : BoneAttachment3D, qui suit l'animation et le ragdoll) ; `enfonce_force` > 0 : profondeur de la pointe (m).
func _ficher(point: Vector3, dir_v: Vector3, v: float, dans: Node3D = null, enfonce_force := -1.0) -> void:
	point_impact = point
	dir_impact = dir_v
	vitesse_impact = v
	var enfonce := clampf(0.03 + 0.14 * v / 46.0, 0.03, 0.17) * (1.4 if dans != null else 1.0)
	if enfonce_force > 0.0:
		enfonce = enfonce_force
	global_position = point + dir_v * enfonce
	_orienter_vers(dir_v)
	if dans != null:
		var g := global_transform
		get_parent().remove_child(self)
		dans.add_child(self)
		global_transform = Transform3D(g.basis.orthonormalized(), g.origin)
		_dans_corps = true
	plantee = true
	_t = 0.0
	_vibre = 0.0 if v > 14.0 else -1.0

func _orienter_vers(d: Vector3) -> void:
	var haut := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT
	look_at(global_position + d, haut)

func _process(dt: float) -> void:
	_maj_trainee(dt)

## Traînée : points de la pointe (repère monde) vieillis, rognés à TRAINEE_LONGUEUR ; deux traits qui s'estompent. Elle finit de s'effacer une fois la flèche fichée.
func _maj_trainee(dt: float) -> void:
	if _trainee == null:
		return
	for p: Array in _trainee_pts:
		p[1] = float(p[1]) + dt
	if not plantee:
		_trainee_pts.append([global_position, 0.0])
	while not _trainee_pts.is_empty() and float((_trainee_pts[0] as Array)[1]) > TRAINEE_DUREE:
		_trainee_pts.pop_front()
	var im := _trainee.mesh as ImmediateMesh
	im.clear_surfaces()
	if _trainee_pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var pos_cam := cam.global_position if cam != null else global_position + Vector3.UP * 100.0
	var reste := TRAINEE_LONGUEUR
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trainee_pts.size()
	for i in range(n - 1, -1, -1):
		var a: Array = _trainee_pts[i]
		var pa: Vector3 = a[0]
		if i < n - 1:
			reste -= pa.distance_to((_trainee_pts[i + 1] as Array)[0])
			if reste < 0.0:
				break
		if cam != null:
			var ecart := TRAINEE_ECART * clampf(float(a[1]) / TRAINEE_DUREE * 2.5, 0.0, 1.0) * clampf(1.0 - pa.distance_to(pos_cam) / TRAINEE_ECART_PORTEE, 0.0, 1.0)
			pa += (cam.global_transform.basis.x * 0.8 - cam.global_transform.basis.y * 0.55) * ecart
		var vers: Vector3 = (_trainee_pts[mini(i + 1, n - 1)] as Array)[0] - (_trainee_pts[maxi(i - 1, 0)] as Array)[0]
		var lat := vers.cross(pos_cam - pa)
		lat = lat.normalized() * clampf(pa.distance_to(pos_cam) * TRAINEE_LARGEUR_ECRAN, TRAINEE_LARGEUR, 0.6) * 0.5 if lat.length() > 0.0001 else Vector3.ZERO
		var al := 0.95 * sqrt(clampf(1.0 - float(a[1]) / TRAINEE_DUREE, 0.0, 1.0)) * clampf(reste / TRAINEE_LONGUEUR + 0.2, 0.0, 1.0)
		al *= clampf((pa.distance_to(pos_cam) - 0.3) / TRAINEE_FONDU_CAM, 0.0, 1.0)
		var c := TRAINEE_COULEUR
		c.a = al
		im.surface_set_color(c)
		im.surface_add_vertex(pa + lat)
		im.surface_set_color(c)
		im.surface_add_vertex(pa - lat)
	im.surface_end()

func _physics_process(dt: float) -> void:
	_t += dt
	if _vibre >= 0.0 and _modele_fleche != null:
		_vibre += dt
		# vibration amortie de la hampe autour de la pointe fichée
		var a := 0.06 * exp(-_vibre * 9.0) * sin(_vibre * 55.0)
		_modele_fleche.rotation = Vector3(a, a * 0.6, 0.0)
		if _vibre > 0.6:
			_vibre = -1.0
			_modele_fleche.rotation = Vector3.ZERO
	if plantee:
		if genre == "fleche_joueur" and _dans_corps and _t > VIE_DANS_CORPS:
			queue_free()
			return
		if recuperable and joueur != null and is_instance_valid(joueur) and joueur.global_position.distance_to(global_position) < PORTEE_RAMASSAGE \
				and not bool(joueur.get("mort")):
			var inv: Variant = joueur.get("inventaire")
			if inv != null:
				inv.ajouter("fleche", 1)
				Sons.jouer_a(get_parent() if get_parent() else self, ["cloth1"], global_position, -10.0, 0.2)
				queue_free()
				return
		if _t > (VIE_RAMASSABLE if recuperable else (VIE_PLANTEE_JOUEUR if genre == "fleche_joueur" else VIE_PLANTEE)):
			queue_free()
		return
	if _t > VIE_VOL:
		queue_free()
		return
	vitesse.y -= gravite * dt
	if genre == "fleche_joueur":
		vitesse -= vitesse * TRAINEE * vitesse.length() * dt
	var de := global_position
	var vers := de + vitesse * dt
	# raycast de la pointe à sa position suivante (+ marge) : rien n'est sauté, même à pleine vitesse
	var marge := 0.05 if genre != "givre" else 0.4
	var q := PhysicsRayQueryParameters3D.create(de, vers + vitesse.normalized() * marge)
	var ex := _ex.duplicate()
	if genre != "fleche_joueur":   # les flèches ennemies traversent les autres ennemis ; celles du joueur les touchent
		for e in get_tree().get_nodes_in_group("ennemis"):
			if e is CollisionObject3D:
				ex.append((e as CollisionObject3D).get_rid())
	if not (genre == "fleche_joueur" and not distant and PvpCoop.actif()):   # PvP : la flèche du joueur touche les autres joueurs
		ex.append_array(ReseauProjectiles.exclus_avatars())   # coop : jamais de tir allié, la victime résout chez elle
	if distant and genre == "fleche_joueur":
		var loc := ReseauProjectiles.joueur_local() as CollisionObject3D   # flèche d'un autre joueur : ne blesse pas non plus le joueur local
		if loc != null:
			ex.append(loc.get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		global_position = vers
		_orienter()
		return
	var cible: Object = r["collider"]
	if genre == "fleche_joueur":
		var dir_v := vitesse.normalized()
		var v := vitesse.length()
		var p_imp: Vector3 = r["position"]
		vitesse_impact = v
		# le contact arrive sur la capsule (ou un os du ragdoll) : le VRAI point d'entrée est sur le corps (ImpactsLances.visee_corps),
		# l'os touché porte la flèche ; un tir qui frôle la capsule sans toucher le corps continue son vol
		var corps: Node3D = ImpactsLances._ennemi_de(cible as Node, joueur) if cible is Node else null
		if corps != null and corps != joueur:
			var vc := ImpactsLances.visee_corps(corps, p_imp, dir_v)
			if bool(vc["frole"]):
				_ignorer_corps(corps)
				global_position = p_imp + dir_v * 0.1
				return
			p_imp = vc["entree"]
			var vivant: bool = not corps.has_method("vivant") or bool(corps.vivant())
			if vivant and corps.has_method("recevoir_coup"):
				degats_impact = degats_pour(v)
				var info := {"type": "perforant", "point": p_imp, "direction": dir_v, "normale": r["normal"],
					"zone": DegatsCombat.zone(corps, p_imp), "attaque": "legere", "arme": "arc",
					"stagger": 0.35 * clampf(degats_impact / 36.0, 0.2, 1.0), "collider": corps, "affaibli": false, "charge": 0.0, "instant": 0.0}
				if distant:
					resultat = "touche"    # copie d'une flèche tirée ailleurs : visuel seulement
				elif PvpCoop.pvp_cible(corps):
					resultat = PvpCoop.coup_fleche(corps, degats_impact, p_imp, dir_v)   # PvP
				elif ReseauProjectiles.invite():
					resultat = "touche"    # invité : l'hôte valide et applique (proj_coup)
					ReseauProjectiles.envoyer_coup_fleche(self, corps, degats_impact, p_imp, dir_v, v)
				else:
					resultat = DegatsCombat.appliquer(corps, degats_impact, p_imp - dir_v * 2.0, false, info)
				if resultat == "":
					resultat = "touche"
				touche.emit(resultat)
				GerbePixels.emettre(self, p_imp, (-dir_v + Vector3.UP * 0.4).normalized(), "sang", 0.8)
			else:
				resultat = "touche"        # cadavre : la flèche s'y fiche sans dégâts
			# la flèche reste fichée DANS le corps : portée par l'os touché (suit l'animation et le ragdoll), sans se ramasser
			recuperable = false
			if is_instance_valid(corps) and corps.is_inside_tree():
				var porte: Node3D = vc["accroche"] if vc.get("accroche") != null else corps
				var prof := clampf(float(vc["vers_axe"]) * 0.85, 0.06, 0.22)
				_ficher(p_imp, dir_v, v, porte, prof)
				Sons.jouer_a(self, ["knifeSlice2"], p_imp, -8.0, 0.2)
			else:
				queue_free()
			return
		if cible != null and cible != joueur and cible.has_method("recevoir_coup"):
			degats_impact = degats_pour(v)
			var info2 := {"type": "perforant", "point": p_imp, "direction": dir_v, "normale": r["normal"],
				"zone": DegatsCombat.zone(cible as Node3D, p_imp), "attaque": "legere", "arme": "arc",
				"stagger": 0.35 * clampf(degats_impact / 36.0, 0.2, 1.0), "collider": cible, "affaibli": false, "charge": 0.0, "instant": 0.0}
			if distant:
				resultat = "touche"
			elif PvpCoop.pvp_cible(cible):
				resultat = PvpCoop.coup_fleche(cible as Node, degats_impact, p_imp, dir_v)   # PvP : l'hôte valide, la victime encaisse
			elif ReseauProjectiles.invite():
				resultat = "touche"
				ReseauProjectiles.envoyer_coup_fleche(self, cible as Node, degats_impact, p_imp, dir_v, v)
			else:
				resultat = DegatsCombat.appliquer(cible as Node, degats_impact, p_imp - dir_v * 2.0, false, info2)
			if resultat == "":
				resultat = "touche"
			touche.emit(resultat)
			GerbePixels.emettre(self, p_imp, (-dir_v + Vector3.UP * 0.4).normalized(), "sang", 0.8)
			recuperable = false
			if is_instance_valid(cible) and (cible as Node).is_inside_tree():
				_ficher(p_imp, dir_v, v, cible as Node3D)
				Sons.jouer_a(self, ["knifeSlice2"], p_imp, -8.0, 0.2)
			else:
				queue_free()
			return
		resultat = "mur"
		_ficher(p_imp, dir_v, v)
		plante.emit(p_imp)
		Sons.jouer_a(self, ["knifeSlice2"], p_imp, -8.0, 0.2)
		return
	global_position = r["position"] - vitesse.normalized() * 0.05
	if cible != null and cible.has_method("recevoir_coup") and cible is CharacterBody3D:
		var origine: Vector3 = global_position - vitesse.normalized() * 2.0
		if not options_coup.is_empty() and joueur != null and cible == joueur:
			resultat = cible.recevoir_coup(degats, origine, options_coup)
		else:
			resultat = cible.recevoir_coup(degats, origine)
		if resultat == "":
			resultat = "touche"
		touche.emit(resultat)
		if id_reseau != "":
			ReseauProjectiles.fin(id_reseau, global_position)   # coop : les copies chez les autres disparaissent
		if genre == "givre":
			_briser(resultat == "touche")
		elif resultat == "touche":
			GerbePixels.emettre(self, global_position, (-vitesse.normalized() + Vector3.UP * 0.4).normalized(), "sang", 0.8)
		queue_free()
		return
	if genre == "givre":
		# la glace se brise sur le décor (pas de trait fiché)
		resultat = "mur"
		plante.emit(global_position)
		_briser(false)
		queue_free()
		return
	resultat = "mur"
	plantee = true
	_t = 0.0
	set_physics_process(true)
	plante.emit(global_position)
	Sons.jouer_a(self, ["knifeSlice2"], global_position, -8.0, 0.2)

## Un tir qui frôle un corps (bord de la capsule) l'ignore pour le reste du vol : le corps et ses os de ragdoll sortent du rayon.
func _ignorer_corps(corps: Node) -> void:
	if corps is CollisionObject3D:
		_ex.append((corps as CollisionObject3D).get_rid())
	for pb in corps.find_children("*", "PhysicalBone3D", true, false):
		_ex.append((pb as PhysicalBone3D).get_rid())

## Éclatement du trait de givre : éclats de glace, buée, tintement.
func _briser(sur_joueur: bool) -> void:
	var d_g := (-vitesse.normalized() + Vector3.UP * 0.5).normalized() if vitesse.length() > 0.01 else Vector3.UP
	GerbePixels.emettre(self, global_position, d_g, "givre", 1.1 if sur_joueur else 0.9)
	GerbePixels.emettre(self, global_position, d_g, "givre_lueur", 0.7)
	Sons.jouer_a(get_parent() if get_parent() else self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position, -4.0, 0.15)
