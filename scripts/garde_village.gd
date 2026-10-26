extends CharacterBody3D
## Garde de Skarnholt (lot D/gardes_village) : un Gardien nordique ENTIER (GardienNordique : casque à nasal, mailles, tabard du jarl,
## cape, lance, bouclier) avec une petite variante de visage / barbe / carrure (GardesVillage.creer_modele). Trois services :
##   - "poste" : debout à son poste (portes, longue maison, pied de la tour), tourné vers `cap` ; il suit le joueur de la tête et se
##     tourne vers lui s'il s'approche, puis reprend sa faction ;
##   - "ronde" : parcourt `route` (points monde, en boucle ou en aller-retour) le long de la palissade ou dans la rue, avec de courtes
##     haltes où il regarde autour ; la haute rue se prend par les rampes des escaliers comme le joueur ;
##   - "vigie" : dans le beffroi de la tour, sans physique (posé sur le plancher), il balaie l'horizon du regard.
## Jamais hostile au joueur. Quand un ennemi en combat entre près de lui dans le village (GardesVillage le signale : alerter()), il
## lui fait face en garde de combat (lance pointée) et crie l'alerte, puis reprend son service quand l'ennemi est loin ou mort.
## Il parle (touche E) : répliques de garde tirées de data/gardes.json, et interpelle parfois le joueur qui passe.
## Propriétés à poser AVANT add_child : donnees, modele, joueur, dialogue, route (Array de Vector3), gestion (GardesVillage).

enum { POSTE, MARCHE, HALTE, ALERTE, ECART }

const GRAVITE := 13.0
const MARCHE_V := 1.0           # m/s : pas de ronde, un peu plus posé que les villageois
const REF_MARCHE := 1.03        # vitesse que suppose le clip Walk (villageois.gd)
const ACCEL := 3.0
const ROT_MAX := 3.2
const ECART_DEPART := 0.5
const ECART_MAX := 1.0
const DIST_REGARD := 3.5        # à l'arrêt, il se tourne vers le joueur en deçà
const DIST_TETE := 6.0
const DIST_INTERPELLE := 5.0
const DIST_PARLER := 2.6
const DOT_PARLER := 0.85
const ARRIVEE := 0.35
const DIST_CEDER := 2.6         # en ronde, le joueur qui arrive en face à moins de 2,6 m : il s'écarte d'un pas et le laisse passer
const BLOCAGE_T := 2.5          # s sans avancer (en voulant avancer) = coincé : il passe au point suivant (compté dans `blocages`)

var donnees: Dictionary = {}
var modele: Node3D
var joueur: CharacterBody3D
var dialogue: Control
var route: Array = []           # de Vector3 (monde) ; [0] = poste pour un garde fixe
var gestion: Node               # GardesVillage : répliques communes, délai global des interpellations
var service := "poste"
var boucle := true
var cap := 0.0                  # rad
var deja_parle := false

var etat := POSTE
var anim: AnimationPlayer
var lod := 0                    # 0 : complet ; 1 : allégé (ni IK des pieds ni suivi de tête ni ombre) ; 2 : endormi (caché, gelé)
var blocages := 0               # nombre de fois où il a dû renoncer à un point (test_gardes_village)
var parcouru := 0.0             # distance parcourue (m)
var _anim := ""
var _t := 0.0
var _i := 1                     # point visé
var _sens := 1
var _vit := 0.0
var _avance := false
var _bloque := 0.0
var _halte := 0.0
var _var := 1.0
var _tete: Node                 # villageois.gd SuiviTete
var _pieds: PiedsAuSol
var _en_conversation := false
var _debut_conversation := 0.0
var _invite := false
var _delai_interpelle := 0.0
var _autour := 0.0
var _autour_duree := 4.0
var _autour_lacet := 0.0
var _delai_autour := 10.0
var _ennemi: Node3D = null
var _pos_prec := Vector3.ZERO
var _delai_parole := 0.0
var _parle := false
var _lignes_perso: Array = []
var _ecart_but := Vector3.ZERO
var _ecart_t := 0.0
var _apres_ecart := MARCHE

const SuiviTete := preload("res://scripts/villageois.gd").SuiviTete

func _ready() -> void:
	add_to_group("villageois")       # gel sous terre (monde._geler_exterieur), caméra qui ne bute pas dessus
	add_to_group("gardes_village")
	service = donnees.get("type", "poste")
	boucle = donnees.get("boucle", true)
	cap = deg_to_rad(float(donnees.get("cap", 0.0)))
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)   # rampes des escaliers ≤ 39°
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	forme.disabled = service == "vigie"   # la vigie est posée dans la boîte de collision de la tour
	add_child(forme)
	if modele == null:
		modele = GardesVillage.creer_modele(donnees)
	add_child(modele)
	anim = modele.get_node("Animations")
	rotation.y = cap
	_var = randf_range(0.93, 1.07)
	_delai_interpelle = randf_range(5.0, 30.0)
	_delai_autour = randf_range(5.0, 15.0)
	var sq: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if sq != null:
		_tete = SuiviTete.new()
		sq.add_child(_tete)
		if service != "vigie":
			_pieds = PiedsAuSol.equiper(modele, self) as PiedsAuSol
	_jouer("Idle", 0.0)
	if anim != null:
		anim.seek(randf() * 2.0)
	_pos_prec = global_position
	if service == "ronde" and route.size() > 1:
		etat = HALTE
		_halte = randf_range(0.5, 4.0)
		_i = 1
	_lignes_perso = donnees.get("lignes", [])

func nom_affiche() -> String:
	return donnees.get("nom", "Garde de Skarnholt")

func en_combat() -> bool:
	return false    # jamais compté « en combat » (HUD, gel sous terre)

## Répliques (touche E) : la 1re fois, ses lignes propres ; ensuite une réplique commune (de nuit si c'est la nuit).
func parler() -> Array:
	var lignes: Array = []
	if not deja_parle and not _lignes_perso.is_empty():
		lignes = _lignes_perso.duplicate()
	elif gestion != null:
		lignes = [gestion.replique("apres")]
	if lignes.is_empty() or str(lignes[0]) == "":
		lignes = ["Circule, voyageur."]
	deja_parle = true
	_en_conversation = true
	_debut_conversation = 0.0
	_vit = 0.0
	_parle = false
	_delai_parole = 0.8
	_jouer("Idle", 0.25)
	return lignes

func fin_conversation() -> void:
	_en_conversation = false
	_jouer("Idle", 0.3)

## Un ennemi en combat est entré près de lui (GardesVillage) : il lui fait face, lance pointée. null = fin de l'alerte.
func alerter(e: Node3D) -> void:
	if e == _ennemi:
		return
	var avant := _ennemi
	_ennemi = e
	if e != null and avant == null:
		etat = ALERTE
		_vit = 0.0
		_jouer("Sword_Idle", 0.2)
		if dialogue != null and is_instance_valid(dialogue) and gestion != null and joueur != null \
				and joueur.global_position.distance_to(global_position) < 25.0:
			dialogue.dire_au_passage(nom_affiche(), gestion.replique("alerte"))
	elif e == null and etat == ALERTE:
		etat = HALTE if service == "ronde" and route.size() > 1 else POSTE
		_halte = 1.5
		_jouer("Idle", 0.4)

## Niveau de détail (GardesVillage, toutes les 0,25 s, selon la distance au joueur).
func regler_lod(n: int) -> void:
	if n == lod:
		return
	lod = n
	if _pieds != null:
		_pieds.actif = n == 0
	if _tete != null:
		(_tete as SkeletonModifier3D).active = n == 0
	# ombre portée seulement de près (réglage d'origine de chaque pièce gardé en méta)
	for mi: GeometryInstance3D in modele.find_children("*", "GeometryInstance3D", true, false):
		if not mi.has_meta("ombre0"):
			mi.set_meta("ombre0", mi.cast_shadow)
		mi.cast_shadow = mi.get_meta("ombre0") if n == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = n < 2
	process_mode = Node.PROCESS_MODE_DISABLED if n == 2 else Node.PROCESS_MODE_INHERIT

func _jouer(nom: String, fondu := 0.2) -> void:
	if anim == null or _anim == nom or not anim.has_animation(nom):
		return
	_anim = nom
	anim.play(nom, fondu)
	if nom != "Walk":
		anim.speed_scale = _var

func _physics_process(dt: float) -> void:
	_t += dt
	if service == "vigie":
		_vigie(dt)
		return
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	var vers := Vector3.ZERO
	var dist := INF
	if joueur != null and is_instance_valid(joueur):
		vers = joueur.global_position - global_position
		vers.y = 0.0
		dist = vers.length()
	if _en_conversation:
		_debut_conversation += dt
		if joueur != null and not joueur.en_dialogue and _debut_conversation > 0.3:
			fin_conversation()
	var dir_cap := Vector3.ZERO      # direction de marche
	var vise := Vector3.ZERO         # direction où tourner le corps
	if _en_conversation:
		vise = vers / maxf(dist, 0.01)
		_parole(dt)
	else:
		match etat:
			ALERTE:
				if _ennemi != null and is_instance_valid(_ennemi):
					vise = _ennemi.global_position - global_position
					vise.y = 0.0
			POSTE:
				if dist < DIST_REGARD:
					vise = vers / maxf(dist, 0.01)
				else:
					vise = Vector3(sin(cap), 0, cos(cap))
				_regard_autour(dt)
			HALTE:
				_halte -= dt
				_regard_autour(dt)
				if dist < DIST_REGARD:
					vise = vers / maxf(dist, 0.01)
				if _halte <= 0.0:
					etat = MARCHE
					_t = 0.0
					_bloque = 0.0
			MARCHE:
				if _doit_ceder(vers, dist):
					_ceder(vers)
				else:
					dir_cap = _vers_point(dt)
					vise = dir_cap
			ECART:
				_ecart_t += dt
				var d := _ecart_but - global_position
				d.y = 0.0
				if d.length() > 0.2 and _ecart_t < 2.5:
					dir_cap = d.normalized()
					vise = dir_cap
				elif dist < DIST_REGARD:
					vise = vers / maxf(dist, 0.01)
				if _ecart_t > 2.0 and (dist > DIST_CEDER + 0.8 or _ecart_t > 7.0):
					etat = _apres_ecart
					_t = 0.0
					_bloque = 0.0
	var ecart_cap := 0.0
	if dir_cap != Vector3.ZERO:
		ecart_cap = absf(angle_difference(rotation.y, atan2(dir_cap.x, dir_cap.z)))
	if vise.length_squared() > 1e-4:
		var ecart := angle_difference(rotation.y, atan2(vise.x, vise.z))
		rotation.y += clampf(ecart * (1.0 - exp(-6.0 * dt)), -ROT_MAX * dt, ROT_MAX * dt)
	_avance = dir_cap != Vector3.ZERO and ecart_cap < (ECART_MAX if _vit > 0.05 else ECART_DEPART)
	_vit = move_toward(_vit, MARCHE_V * _var if _avance else 0.0, ACCEL * dt) if dir_cap != Vector3.ZERO else 0.0
	velocity.x = dir_cap.x * _vit
	velocity.z = dir_cap.z * _vit
	move_and_slide()
	var pas := global_position - _pos_prec
	pas.y = 0.0
	parcouru += pas.length()
	_pos_prec = global_position
	if etat == MARCHE or etat == ECART:
		if _vit > 0.1:
			_jouer("Walk", 0.3)
			anim.speed_scale = clampf(_vit / REF_MARCHE, 0.5, 1.6)
		elif not _avance:
			_jouer("Idle", 0.3)
	_regard_tete(dist)
	_interactions(dist, dt)

## Le joueur arrive en face (devant lui, à moins de DIST_CEDER) : il faut lui laisser le passage (escaliers, ruelles).
func _doit_ceder(vers: Vector3, dist: float) -> bool:
	if dist > DIST_CEDER or dist < 0.01 or route.size() < 2:
		return false
	var p: Vector3 = route[_i] - global_position
	p.y = 0.0
	if p.length() < 0.01:
		return false
	return p.normalized().dot(vers / dist) > 0.2

## Un pas de côté (1,1 m, du côté opposé au joueur, ou de l'autre côté si ce côté est pris), puis il attend que le joueur soit passé.
func _ceder(vers: Vector3) -> void:
	var p: Vector3 = route[_i] - global_position
	p.y = 0.0
	var lat := Vector3(p.z, 0.0, -p.x).normalized()
	if lat.dot(vers) > 0.0:
		lat = -lat
	var but := global_position + lat * 1.1
	if not _pas_libre(but):
		but = global_position - lat * 1.1
		if not _pas_libre(but):
			but = global_position
	_ecart_but = but
	_ecart_t = 0.0
	_apres_ecart = MARCHE
	etat = ECART
	_vit = 0.0

## Vrai si la capsule du garde tient en `p` (au-dessus du sol : marches et rampes ignorées ; corps vivants ignorés).
var _sonde: CapsuleShape3D
func _pas_libre(p: Vector3) -> bool:
	if _sonde == null:
		_sonde = CapsuleShape3D.new()
		_sonde.radius = 0.33
		_sonde.height = 1.2
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = _sonde
	qs.transform = Transform3D(Basis(), p + Vector3(0, 1.15, 0))
	qs.exclude = [get_rid()]
	for h in get_world_3d().direct_space_state.intersect_shape(qs, 4):
		if not (h["collider"] is CharacterBody3D):
			return false
	return true

## Point suivant de la ronde (boucle, ou aller-retour si `boucle` est faux) ; halte à chaque extrémité et à un point sur trois.
func _point_suivant() -> void:
	var n := route.size()
	if boucle:
		_i = (_i + 1) % n
	else:
		if _i + _sens >= n or _i + _sens < 0:
			_sens = -_sens
		_i += _sens
	var halte_ici: bool = (not boucle and (_i == 0 or _i == n - 1)) or (boucle and _i % 3 == 0)
	if halte_ici or randf() < 0.15:
		etat = HALTE
		_halte = randf_range(2.0, 5.0)
		_jouer("Idle", 0.3)

func _vers_point(dt: float) -> Vector3:
	if route.size() < 2:
		etat = POSTE
		return Vector3.ZERO
	var p: Vector3 = route[_i]
	var d := p - global_position
	d.y = 0.0
	var reelle := Vector2(velocity.x, velocity.z).length()
	_bloque = _bloque + dt if (_t > 1.0 and _avance and reelle < 0.15) else 0.0
	if d.length() < ARRIVEE:
		_t = 0.0
		_point_suivant()
		return Vector3.ZERO
	if _bloque > BLOCAGE_T:
		# coincé (le joueur en travers, un autre garde) : il renonce à ce point et vise le suivant
		_bloque = 0.0
		_t = 0.0
		if not _gene_par_un_corps():
			blocages += 1
			print_verbose("Garde %s coincé vers (%.1f ; %.1f)" % [name, p.x, p.z])
		_point_suivant()
		return Vector3.ZERO
	return d.normalized()

## Vrai si ce qui l'arrête est un corps vivant (joueur, villageois, autre garde) : il attend son tour, ce n'est pas un blocage.
func _gene_par_un_corps() -> bool:
	if joueur != null and joueur.global_position.distance_to(global_position) < 2.0:
		return true
	for k in get_slide_collision_count():
		if get_slide_collision(k).get_collider() is CharacterBody3D:
			return true
	return false

## Conversation : alterne Idle_Talking (lance droite, clip recalculé du Gardien) et Idle.
func _parole(dt: float) -> void:
	_delai_parole -= dt
	if _delai_parole > 0.0:
		return
	_parle = not _parle
	_delai_parole = randf_range(2.5, 4.5) if _parle else randf_range(1.0, 2.0)
	_jouer("Idle_Talking" if _parle else "Idle", 0.3)

func _regard_autour(dt: float) -> void:
	if _autour > 0.0:
		_autour -= dt
		return
	_delai_autour -= dt
	if _delai_autour <= 0.0:
		_delai_autour = randf_range(7.0, 16.0)
		_autour_duree = randf_range(3.0, 5.0)
		_autour = _autour_duree
		_autour_lacet = deg_to_rad(randf_range(35.0, 60.0)) * (1.0 if randf() < 0.5 else -1.0)

## Vigie : immobile dans le beffroi, balaie lentement l'horizon du regard (et regarde le joueur s'il monte l'escalier tout près).
func _vigie(dt: float) -> void:
	_regard_autour(dt)
	var dist := INF
	if joueur != null and is_instance_valid(joueur):
		dist = joueur.global_position.distance_to(global_position)
	_regard_tete(dist)

func _regard_tete(dist: float) -> void:
	if _tete == null or lod != 0:
		return
	var oeil := global_position + Vector3.UP * 1.6
	if etat == ALERTE and _ennemi != null and is_instance_valid(_ennemi):
		_tete.cible = _ennemi.global_position + Vector3.UP * 1.3
		_tete.voulu = true
	elif joueur != null and (dist < DIST_TETE or _en_conversation):
		var cam: Camera3D = joueur.camera if "camera" in joueur else null
		_tete.cible = cam.global_position if cam != null else joueur.global_position + Vector3.UP * 1.6
		_tete.voulu = true
	elif _autour > 0.0:
		var moitie := _autour > _autour_duree * 0.5
		var lacet := _autour_lacet if moitie else -_autour_lacet * 0.6
		_tete.cible = oeil + global_transform.basis * (Basis(Vector3.UP, lacet) * Vector3(0.0, 0.0, 4.0))
		_tete.voulu = true
	else:
		_tete.voulu = false

func _interactions(dist: float, dt: float) -> void:
	if dialogue == null or not is_instance_valid(dialogue) or joueur == null:
		return
	_delai_interpelle -= dt
	if dist < DIST_INTERPELLE and _delai_interpelle <= 0.0 and not _en_conversation and etat != ALERTE \
			and gestion != null and gestion.peut_interpeller():
		_delai_interpelle = randf_range(45.0, 90.0)
		dialogue.dire_au_passage(nom_affiche(), gestion.replique("nuit" if gestion.de_nuit() and randf() < 0.6 else "interpellations"))
	var veut := false
	var cam: Camera3D = joueur.camera
	if dist < DIST_PARLER and not _en_conversation and cam != null:
		var avant := -cam.global_transform.basis.z
		var cible := (global_position + Vector3.UP * 1.4 - cam.global_position).normalized()
		veut = avant.dot(cible) > DOT_PARLER
	if veut and not _invite:
		_invite = true
		dialogue.inviter(self)
	elif not veut and _invite:
		_invite = false
		dialogue.retirer_invite(self)
