class_name EnnemiBase
extends CharacterBody3D
## Socle des ennemis à IA de combat qui ne sont pas des draugrs (troll de givre, mage nordique…). Mêmes briques que draugr.gd
## (docs/DEGATS.md) sans le dupliquer : composant CombatEnnemi (dégâts, posture, réactions, sang, plaies, finishers), mort en
## ragdoll (morts variées, décapitation, butin, signal `mort` pour la sauvegarde), déplacement (rotation bornée, alignement,
## recul, contournement par rayons, immobile = move_and_slide espacé), ligne de vue, gel hors salle active, télégraphes au sol.
## Chaque ennemi garde SA machine d'états (_ia) et surcharge les crochets :
##   _etat_coup() -> Dictionary   état transmis à CombatEnnemi.analyser ("en_attaque", "coup_donne", "peut_bloquer")
##   _reagir(r, vers)             applique la réaction (r["reaction"] : leger, moyen, lourd, recul, chute, etourdi, bloque)
##   _apres_degats(r)             juste après les dégâts (régénération, rage…)
##   _finisher_permis() -> bool   faux pendant un pouvoir
##   _special_mort(sorte, r)      effets propres à la mort (tremblement, explosion de givre…)
##   _contenu_butin() -> Dictionary
## Contrat public identique aux draugrs : vivant(), en_combat(), recevoir_coup(degats, origine, puissant, info), alerter(),
## finisher_possible(joueur), subir_finisher(categorie, info), point_impact(), peut_geler()/geler()/degeler() ; signal mort(ident) ;
## propriétés lues par le HUD (vie, vie_max, nom_affiche). Création dans le monde : monde.creer_ennemi(script, position, lacet, options).

signal mort(ident: String)

const BUTIN := preload("res://scripts/butin.gd")
const GRAVITE := 13.0
const ACCEL := 8.0
const IMMO_PERIODE := 0.4
## Vitesses du corps supposées par les clips (outils/mesure_pas.gd) : speed_scale = vitesse réelle / référence (pieds sans glisse).
const REF_MARCHE := 1.03
const REF_COURSE := 6.0
const REF_SPRINT := 7.5
const DUREE_CADAVRE := 30.0

var joueur: CharacterBody3D
var hud: Control
var quetes: Node
var ident := ""
var nom_affiche := "Ennemi"
var vie := 100.0
var vie_max := 100.0
var degats := 15.0
## Réglages facultatifs posés avant add_child (monde.creer_ennemi, scènes de test).
var vie_imposee := 0.0
var degats_imposes := 0.0
var contourne := true
var modele: Node3D
var anim: AnimationPlayer
var combat: CombatEnnemi
var origine := Vector3.ZERO
var est_mort := false
## Échelle de la créature (hauteur de la capsule, des yeux pour la ligne de vue).
var taille := 1.0
var _t := 0.0                 # durée dans l'état courant (remis à 0 par _changer des sous-classes)
var _t_mort := 0.0
var _t_sans_coup := 999.0     # durée depuis le dernier coup reçu
var _anim := ""
var _var := 1.0
var _vit := 0.0
var _recul := Vector3.ZERO
var _mailles: Array[MeshInstance3D] = []
var _pieds: PiedsAuSol
var _ragdoll: Ragdoll
var _immo := 0.0
var _gele := false
var _mode_avant := Node.PROCESS_MODE_INHERIT
var _los := true
var _t_los := 0.0
var _telegraphes: Array[Node3D] = []
var _mult_force_mort := 1.0
# contournement (comme draugr._eviter)
var _cote := 1.0
var _tenue := 0.0
var _dir_evit := Vector3.ZERO
var _detour := 0.0
var _dernier := Vector3.ZERO
var _t_bloque := 0.0

## Branche le modèle et le composant de combat (à appeler dans le _ready de l'ennemi, après avoir réglé vie_max / degats).
func _equiper(mod: Node3D, profil: ProfilCible, rayon: float, haut: float, pieds := true) -> void:
	add_to_group("ennemis")
	if vie_imposee > 0.0:
		vie_max = vie_imposee
	if degats_imposes > 0.0:
		degats = degats_imposes
	vie = vie_max
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = rayon
	capsule.height = haut
	forme.shape = capsule
	forme.position.y = haut * 0.5
	add_child(forme)
	modele = mod
	add_child(modele)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		_mailles.append(mi)
	if pieds:
		_pieds = PiedsAuSol.equiper(modele, self) as PiedsAuSol
	anim = modele.get_node("Animations")
	combat = CombatEnnemi.equiper(self, modele, profil)
	_var = randf_range(0.94, 1.06)
	origine = global_position
	_immo = randf() * IMMO_PERIODE

# ------------------------------------------------------------------ contrat public

func vivant() -> bool:
	return not est_mort

func en_combat() -> bool:
	return false

func alerter() -> void:
	degeler()

## Point visé par l'épée de mains.gd (défaut : torse, côté joueur ; les grandes créatures le surchargent).
func point_impact() -> Vector3:
	return global_position + Vector3(0, 1.0 * taille, 0)

func peut_geler() -> bool:
	return not est_mort and not en_combat()

func est_gele() -> bool:
	return _gele

func geler() -> void:
	if _gele or est_mort or not peut_geler():
		return
	_gele = true
	_mode_avant = process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false

func degeler() -> void:
	if not _gele:
		return
	_gele = false
	process_mode = _mode_avant
	visible = true

# ------------------------------------------------------------------ crochets (surchargés)

func _etat_coup() -> Dictionary:
	return {"peut_bloquer": false, "en_attaque": false, "coup_donne": false}

func _reagir(_r: Dictionary, _vers: Vector3) -> void:
	pass

func _apres_degats(_r: Dictionary) -> void:
	pass

func _finisher_permis() -> bool:
	return true

func _special_mort(_sorte: String, _r: Dictionary) -> void:
	pass

func _sur_mort() -> void:
	pass

func _contenu_butin() -> Dictionary:
	return {"pieces": randi_range(4, 14)}

func _ia(_dt: float) -> void:
	pass

# ------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	_t += dt
	_t_sans_coup += dt
	if est_mort:
		_t_mort += dt
		if _t_mort > DUREE_CADAVRE:
			queue_free()
		return
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	if joueur == null or not is_instance_valid(joueur):
		return
	_ia(dt)

## Distance et direction horizontales vers le joueur ; un étage d'écart (> 3,5 m) = hors d'atteinte (1000 m).
func _vers_joueur() -> Dictionary:
	var v := joueur.global_position - global_position
	var dy := absf(v.y)
	v.y = 0.0
	var d := v.length()
	var dir := v / d if d > 0.01 else global_transform.basis.z
	if dy > 3.5 * maxf(taille, 1.0):
		d = 1000.0
	return {"dist": d, "dir": dir}

## Déplacement d'une image (fin de _ia). `dir` : direction de marche ; `face` : direction à regarder (ZERO = garder l'orientation) ;
## `loco` : clip de marche ("" = sur place, `repos` joué) ; `libre` : marche dans n'importe quel sens par rapport au regard (recul,
## pas de côté : clip Walk à l'envers ou ralenti), sinon il ne court ni de dos ni de travers (pivote d'abord, comme draugr.gd).
func _bouger(dt: float, dir: Vector3, vitesse: float, loco: String, face: Vector3, vitesse_rot: float, repos := "Idle", libre := false) -> void:
	if contourne and loco != "" and vitesse > 0.0:
		dir = _eviter(dir, dt)
	else:
		_detour = 0.0
		_t_bloque = 0.0
	var ecart := 0.0
	var regard := face if face != Vector3.ZERO else (dir if loco != "" and not libre else Vector3.ZERO)
	if regard.length() > 0.01:
		var cible := atan2(regard.x, regard.z)
		ecart = angle_difference(rotation.y, cible)
		var pas := ecart * (1.0 - exp(-8.0 * dt))
		rotation.y += clampf(pas, -vitesse_rot * dt, vitesse_rot * dt)
	if libre and loco != "":
		_vit = move_toward(_vit, vitesse, ACCEL * dt)
		var avant := global_transform.basis.z
		var f := dir.dot(Vector3(avant.x, 0, avant.z).normalized())
		_jouer(loco)
		var ref := REF_COURSE if loco == "Jog_Fwd" else (REF_SPRINT if loco == "Sprint" else REF_MARCHE)
		var s := clampf(_vit / ref, 0.4, 1.6)
		anim.speed_scale = s * (-1.0 if f < -0.3 else 1.0) * (0.85 if absf(f) < 0.3 else 1.0)
	else:
		var aligne := 1.0 if face != Vector3.ZERO and loco == "" else clampf(1.0 - (absf(angle_difference(rotation.y, atan2(dir.x, dir.z))) - 0.3) / 1.0, 0.0, 1.0)
		if loco != "" and aligne >= 0.25:
			_vit = move_toward(_vit, vitesse * aligne, ACCEL * dt)
			_jouer(loco)
			var ref := REF_COURSE if loco == "Jog_Fwd" else (REF_SPRINT if loco == "Sprint" else REF_MARCHE)
			anim.speed_scale = clampf(_vit / ref, 0.4, 1.6)
		else:
			_vit = 0.0
			if loco != "" or repos != "":
				_jouer(repos if repos != "" else "Idle")
	_recul = _recul.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	var fv := Statuts.facteur_vitesse(self)   # magie : gel (docs/MAGIE.md)
	if fv < 1.0 and loco != "" and _vit > 0.01:   # la marche vient d'être réglée : jamais cumulé d'une image à l'autre
		anim.speed_scale *= fv
	velocity.x = dir.x * _vit * fv + _recul.x
	velocity.z = dir.z * _vit * fv + _recul.z
	if absf(velocity.x) + absf(velocity.z) < 0.01 and velocity.y > -0.01 and is_on_floor() and _immo < IMMO_PERIODE:
		_immo += dt
		return
	_immo = 0.0
	move_and_slide()

func _jouer(nom: String, fondu := 0.15, forcer := false) -> void:
	if _anim == nom and not forcer:
		return
	_anim = nom
	if forcer:
		anim.stop()
	anim.play(nom, fondu)
	if nom not in ["Walk", "Jog_Fwd", "Sprint"]:
		anim.speed_scale = _var if nom in ["Idle", "Sword_Idle", "Spell_Simple_Idle", "Crouch_Idle"] else 1.0

func _duree(nom: String) -> float:
	return anim.get_animation(nom).length if anim.has_animation(nom) else 1.0

## Éclair blanc du coup reçu (instance shader « eclair » des matériaux ps1_perso ; temps réel).
func _eclair(force := 0.25) -> void:
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_method(func(v: float) -> void:
		for mi in _mailles:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("eclair", v), force, 0.0, 0.08)

# ------------------------------------------------------------------ perception

func _ligne_de_vue_vers(de: Vector3, vers_p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, vers_p)
	var ex: Array[RID] = [get_rid()]
	if joueur != null:
		ex.append(joueur.get_rid())
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D and e != self:
			ex.append((e as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _ligne_de_vue() -> bool:
	return _ligne_de_vue_vers(global_position + Vector3(0, 1.5 * taille, 0), joueur.global_position + Vector3(0, 1.2, 0))

## Ligne de vue vers le joueur, rafraîchie 5 fois par seconde.
func _voit(dt: float) -> bool:
	_t_los -= dt
	if _t_los <= 0.0:
		_t_los = 0.2
		_los = _ligne_de_vue()
	return _los

## Rayon horizontal à hauteur de genou : libre si rien (hors lui, le joueur et les autres ennemis) ne le coupe.
func _libre(d: Vector3, longueur: float, de := Vector3.INF) -> bool:
	if de == Vector3.INF:
		de = global_position + Vector3(0, 0.55, 0)
	var q := PhysicsRayQueryParameters3D.create(de, de + d * longueur)
	var ex: Array[RID] = [get_rid()]
	if joueur != null:
		ex.append(joueur.get_rid())
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is CollisionObject3D and e != self:
			ex.append((e as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Sol sous un point (rayon vertical) : position du sol ou Vector3.INF.
func _sol_sous(p: Vector3, haut := 2.0, bas := 4.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, haut, 0), p - Vector3(0, bas, 0))
	var ex: Array[RID] = [get_rid()]
	if joueur != null:
		ex.append(joueur.get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else Vector3.INF

## Direction corrigée pour longer les obstacles (même méthode que draugr._eviter : rayons ±35°, ±70°, ±110°, côté mémorisé,
## détour forcé si coincé).
func _eviter(dir: Vector3, dt: float) -> Vector3:
	var avance := global_position.distance_to(_dernier)
	_dernier = global_position
	if _vit > 0.3 and avance < _vit * dt * 0.3:
		_t_bloque += dt
	else:
		_t_bloque = maxf(_t_bloque - dt, 0.0)
	if _t_bloque > 0.4:
		_t_bloque = 0.0
		_cote = -_cote
		_detour = 0.7
	if _detour > 0.0:
		_detour -= dt
		var forc := dir.rotated(Vector3.UP, _cote * 1.2)
		if _libre(forc, 1.0):
			return forc
	if _tenue > 0.0:
		_tenue -= dt
		if _libre(_dir_evit, 1.0):
			return _dir_evit
		_tenue = 0.0
	if _libre(dir, 1.4):
		return dir
	for a in [0.6, 1.2, 1.9]:
		for c in [_cote, -_cote]:
			var d := dir.rotated(Vector3.UP, c * a)
			if _libre(d, 1.2):
				_cote = c
				_dir_evit = d
				_tenue = 0.7
				return d
	_dir_evit = dir.rotated(Vector3.UP, _cote * 2.4)
	_tenue = 0.5
	return _dir_evit

# ------------------------------------------------------------------ télégraphes au sol

## Disque d'alerte posé au sol (zone d'un coup à venir) : anneau extérieur net dès le départ (la limite à quitter) et disque
## intérieur qui se remplit en `duree` s. Rendu sans lumière, transparent ; effacé par _effacer_telegraphe (ou à la mort).
func _disque_sol(centre: Vector3, rayon: float, duree: float, couleur := Color(0.55, 0.85, 1.0)) -> Node3D:
	var sol := _sol_sous(centre)
	var racine := Node3D.new()
	racine.name = "Telegraphe"
	get_parent().add_child(racine)
	racine.global_position = (sol if sol != Vector3.INF else centre) + Vector3(0, 0.05, 0)
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = rayon - 0.12
	t.outer_radius = rayon
	t.rings = 32
	t.ring_segments = 4
	anneau.mesh = t
	anneau.scale = Vector3(1, 0.15, 1)
	var ma := _mat_telegraphe(Color(couleur.r, couleur.g, couleur.b, 0.85))
	anneau.material_override = ma
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(anneau)
	var disque := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = 0.02
	c.radial_segments = 32
	c.rings = 1
	disque.mesh = c
	var md := _mat_telegraphe(Color(couleur.r, couleur.g, couleur.b, 0.12))
	disque.material_override = md
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disque.scale = Vector3(0.1, 1, 0.1)
	racine.add_child(disque)
	var tw := racine.create_tween()
	tw.set_parallel(true)
	tw.tween_property(disque, "scale", Vector3.ONE, duree)
	tw.tween_property(md, "albedo_color:a", 0.42, duree)
	_telegraphes.append(racine)
	return racine

## Bande d'alerte au sol (trajectoire d'une charge) : rectangle de `longueur` m devant `depart`, dans la direction `dir`.
func _bande_sol(depart: Vector3, dir: Vector3, longueur: float, largeur: float, duree: float, couleur := Color(0.55, 0.85, 1.0)) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Telegraphe"
	get_parent().add_child(racine)
	var sol := _sol_sous(depart)
	racine.global_position = (sol if sol != Vector3.INF else depart) + Vector3(0, 0.05, 0)
	racine.rotation.y = atan2(dir.x, dir.z)
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(largeur, 0.02, longueur)
	mi.mesh = b
	mi.position.z = longueur * 0.5
	var m := _mat_telegraphe(Color(couleur.r, couleur.g, couleur.b, 0.1))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(mi)
	var tw := racine.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, duree)
	_telegraphes.append(racine)
	return racine

func _mat_telegraphe(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _effacer_telegraphe(n: Node3D, duree := 0.35) -> void:
	_telegraphes.erase(n)
	if not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.set_parallel(true)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as StandardMaterial3D
		if m:
			tw.tween_property(m, "albedo_color:a", 0.0, duree)
	tw.chain().tween_callback(n.queue_free)

## Pics de glace qui jaillissent du sol (onde du troll, sort de zone du mage) puis fondent ; décor pur (pas de collision).
func _pics_glace(centre: Vector3, rayon: float, nombre: int, hauteur := 0.9) -> void:
	var sol := _sol_sous(centre)
	var base := (sol if sol != Vector3.INF else centre)
	var m := Palette.lueur(Color(0.7, 0.92, 1.35))
	var racine := Node3D.new()
	get_parent().add_child(racine)
	racine.global_position = base
	for k in nombre:
		var a := TAU * float(k) / nombre + randf_range(-0.2, 0.2)
		var r := rayon * sqrt(randf_range(0.15, 1.0))
		var pic := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = randf_range(0.07, 0.16)
		c.height = hauteur * randf_range(0.6, 1.3)
		c.radial_segments = 4
		c.rings = 1
		pic.mesh = c
		pic.material_override = m
		pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		racine.add_child(pic)
		pic.position = Vector3(cos(a) * r, -c.height * 0.5, sin(a) * r)
		pic.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		var tw := pic.create_tween()
		tw.tween_property(pic, "position:y", c.height * 0.4, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(randf_range(0.7, 1.1))
		tw.tween_property(pic, "position:y", -c.height * 0.6, 0.6)
	var tf := racine.create_tween()
	tf.tween_interval(2.2)
	tf.tween_callback(racine.queue_free)

# ------------------------------------------------------------------ coups reçus

## Appelé par l'épée du joueur (et les tests). Renvoie "bloque", "touche" ou "tue" ; `info` : contrat de l'épée FPS (docs/DEGATS.md).
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant := false, info: Dictionary = {}) -> String:
	if est_mort:
		return ""
	degeler()
	var vers := origine_coup - global_position
	vers.y = 0.0
	var e := _etat_coup()
	e["de_face"] = vers.normalized().dot(global_transform.basis.z) > 0.3
	e["surpris"] = not en_combat() and not e["de_face"]   # attaque furtive (ReglagesCombat.FURTIF)
	e["hauteur_visee"] = CombatEnnemi.hauteur_visee(joueur, self)
	var r := combat.analyser(quantite, origine_coup, puissant, info, e)
	_t_sans_coup = 0.0
	if r["bloque"]:
		combat.effets_blocage(r, false)
		_reagir(r, vers)
		return "bloque"
	# finisher PROVISOIRE (comme draugr.gd, en attendant l'animation FPS de l'épée) : un coup lourd sur une cible ouverte l'achève
	if String(r["info"]["attaque"]) in ["lourde", "chargee_max", "contre"] and joueur != null:
		var cat := finisher_possible(joueur)
		if cat != "":
			return subir_finisher(cat, r["info"])
	vie -= float(r["degats"])
	_eclair()
	if r["brise_garde"]:
		combat.effets_blocage(r, true)
	combat.effets_impact(r, joueur)
	_apres_degats(r)
	if vie <= 0.0:
		vie = 0.0
		_mourir_coup(r)
		return "tue"
	if String(r["reaction"]) == "etourdi" and combat.etourdi <= 0.0:
		combat.briser_posture()
	_reagir(r, vers)
	return "touche"

func finisher_possible(j: Node3D) -> String:
	if est_mort or combat == null or not _finisher_permis():
		return ""
	return combat.finisher_possible(j, vie, vie_max)

func subir_finisher(categorie: String, info: Dictionary = {}) -> String:
	if est_mort:
		return ""
	var o: Vector3 = info.get("origine", joueur.global_position if joueur else global_position - global_transform.basis.z)
	var i := CalculDegats.completer(info, self, vie, o, true, combat.hauteur)
	i["attaque"] = "finisher"
	i["categorie"] = categorie
	var r := {"info": i, "degats": vie, "stagger": 999.0, "critique": true, "impact": "finisher", "bloque": false, "brise_garde": false, "reaction": "finisher", "finisher": categorie}
	vie = 0.0
	if not info.has("finisher_nom"):
		_eclair()   # finisher aligné : l'éclair a déjà eu lieu au contact de la lame
	_mourir_coup(r, "finisher")
	return "tue"

func _mourir_coup(r: Dictionary, sorte := "") -> void:
	var i: Dictionary = r["info"]
	_mourir(i["origine"], float(r["degats"]), bool(i.get("puissant", false)), r, sorte if sorte != "" else combat.type_mort(r))

## Mort (même déroulé que draugr._mourir) : ragdoll projeté dans le sens du coup, morts variées (CombatEnnemi.type_mort),
## décapitation des finishers de taille, effets de mort, butin et signal `mort` (sauvegarde) DANS TOUS LES CAS.
func _mourir(origine_coup := Vector3.ZERO, quantite := 20.0, puissant := false, r: Dictionary = {}, sorte := "") -> void:
	if est_mort:
		return
	degeler()
	est_mort = true
	_t_mort = 0.0
	_sur_mort()
	for n in _telegraphes.duplicate():
		_effacer_telegraphe(n, 0.2)
	mort.emit(ident)
	collision_layer = 0
	collision_mask = 0
	var vitesse_avant := Vector3(velocity.x, 0.0, velocity.z).limit_length(6.0)
	velocity = Vector3.ZERO
	if _pieds:
		_pieds.actif = false
	var dir := global_position - origine_coup
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	if sorte == "":
		sorte = "lourde" if puissant else "legere"
	var info: Dictionary = r.get("info", {})
	var categorie := String(r.get("finisher", ""))
	var force := (350.0 if puissant else 120.0) * clampf(quantite / (34.0 if puissant else 14.0), 0.7, 1.6)
	var haut := String(info.get("zone", "")) == "tete"
	var point: Vector3 = info.get("point", global_position + Vector3(0.0, (1.5 if haut else 1.15) * taille, 0.0) - dir * 0.2)
	var os_touche := "Head" if haut else "spine_03"
	var montee := 0.15
	var decapiter := false
	match sorte:
		"legere":
			force = 100.0
		"titubante":
			force = 70.0
		"lourde":
			force = maxf(force, 330.0)
		"recul":
			force = 520.0
			montee = 0.25
		"chute":
			force = 300.0
			os_touche = "calf_l" if randf() < 0.5 else "calf_r"
			montee = 0.05
		"puissant":
			force = 680.0
			montee = 0.35
		"finisher":
			# réglages selon le finisher joué (épée plantée : s'effondre ; décapitation ; coup de grâce au sol…)
			var rf := combat.reglage_mort_finisher(categorie, info)
			force = float(rf["force"])
			montee = float(rf["montee"])
			os_touche = String(rf["os"])
			decapiter = bool(rf["decapiter"])
	# démembrement (coups d'épée : tête, bras, jambe, coupe en deux ; Demembrement.choisir) ; tirage fait à la mort
	var membre := "" if decapiter else Demembrement.choisir(combat, r, sorte)
	if membre == "tete":
		membre = ""
		decapiter = true
	elif membre == "moitie":
		force *= 0.45   # coupé en deux : le haut du corps s'affaisse, il ne s'envole pas
	# sorts : le feu carbonise le corps (parfois un bras en cendres), la glace fait éclater un membre gelé
	var effet_sort := Demembrement.effet_sort(combat, r) if sorte != "finisher" and not decapiter and membre == "" else ""
	if combat.profil.nom.begins_with("troll"):
		modele.set_meta("gore_echelle", 2.0)
	force *= _mult_force_mort
	var lancer := func() -> void:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_ragdoll = Ragdoll.equiper(modele) as Ragdoll
		if _ragdoll:
			if joueur:
				_ragdoll.ignorer(joueur)
			_ragdoll.endormir_apres(4.0)
			_ragdoll.declencher(dir * force + Vector3.UP * force * montee, point, os_touche, vitesse_avant)
		else:
			_jouer("Death01", 0.1, true)
		if decapiter:
			var imp := (Vector3(info.get("direction", dir)) * 0.6 + dir * 0.4 + Vector3.UP * 0.7).normalized() * 16.0
			Decapitation.decapiter(modele, imp, combat.profil.couleur_sang, combat.profil.sang, combat.profil.matiere)
		elif membre != "":
			var imp_m := (Vector3(info.get("direction", dir)) * 0.7 + dir * 0.3 + Vector3.UP * 0.5).normalized() * 16.0
			Demembrement.trancher(modele, membre, imp_m, combat.profil.couleur_sang, Demembrement.matiere_de(combat.profil))
		if effet_sort != "":
			Demembrement.appliquer_sort(modele, effet_sort, combat, (Vector3(info.get("direction", dir)) + Vector3.UP * 0.3).normalized())
	if sorte == "titubante":
		_jouer(combat.anim_coup(), 0.05, true)   # selon la zone touchée
		anim.speed_scale = 0.7
		get_tree().create_timer(0.38).timeout.connect(lancer)
	else:
		lancer.call()
	if combat.reaction_os:
		combat.reaction_os.active = sorte == "titubante"
	if sorte == "finisher":
		RetourImpact.son_finisher(self, point, combat.profil.matiere, decapiter)
	combat.effets_mort(r if not r.is_empty() else {"info": {"point": point, "direction": dir, "normale": -dir}}, sorte, joueur)
	_special_mort(sorte, r)
	_laisser_butin()

func _laisser_butin() -> void:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	b.nom_corps = nom_affiche       # L3 : titre de la fenêtre de butin
	b.contenu = _contenu_butin()
	get_parent().add_child(b)
	b.global_position = global_position + global_transform.basis.z * 0.6
