extends "res://scripts/combat/scene_test_degats.gd"
## Scène de test du Troll de givre et du Mage nordique (IA de combat, branche ennemis/troll_mage) : arène de neige 44 x 44 m avec
## piliers (ligne de vue, contournement, mur pour la charge du troll), joueur factice avec silhouette de guerrier, post-traitement
## ps1. Un PILOTE automatique combat chaque ennemi comme un joueur : il s'approche, PARE le balayage du troll, SORT du disque de
## l'onde de choc, ESQUIVE la charge et les traits de givre d'un pas de côté, quitte le disque du sort de zone, poursuit le mage
## qui se téléporte, frappe (léger / lourd / chargé) jusqu'au finisher (décapitation).
##   godot --path . res://scenes/test_troll_mage.tscn -- --nouvelle [--seul=troll|mage] [--vue=obs|fps] [--captures=<dossier>]
##       [--vie=<pv de l'ennemi>] [--fin=s] [--debug=0]       (--write-movie <fichier.avi> --fixed-fps 30 : vidéo Movie Maker)
##   --test : aucun ennemi ni pilote (outils/test_troll_ia.gd, outils/test_mage_ia.gd s'en servent comme décor).

const TROLL := preload("res://scripts/troll_givre_ia.gd")
const MAGE := preload("res://scripts/mage_nordique_ia.gd")

var silhouette: Node3D
var _sil_anim: AnimationPlayer
var _sil_clip := ""
var _cible: Node3D
var _mode := ""
var _cd_coup := 0.0
var _n_coups := 0
var _esquive := Vector3.ZERO
var _t_esquive := 0.0
var _t_combat := 0.0
var _fin_combat := -1.0
var _captures_faites := {}
var _actif := false
var draugrs := {}     # comme monde.draugrs : ident -> ennemi (sauvegarde des morts)

func _decor() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.46, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.68)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation = Vector3(deg_to_rad(-42), deg_to_rad(35), 0)
	soleil.light_color = Color(1.0, 0.93, 0.84)
	soleil.light_energy = 1.05
	soleil.shadow_enabled = true
	add_child(soleil)
	var neige := Palette.tex("sol_neige_test", Palette.NEIGE, 4, 0.3)
	var pierre := Palette.tex("sol_pierre_test", ["#2c2a2a", "#3c3836", "#4e4844", "#625a54"], 4, 0.5)
	_bloc(Vector3(44.0, 0.2, 44.0), Vector3(0, -0.1, 0), neige, Vector2(22, 22))
	# piliers / rochers : ligne de vue du mage, mur pour la charge du troll
	for p: Vector3 in [Vector3(-7, 0, -4), Vector3(6, 0, -9), Vector3(9, 0, 5), Vector3(-10, 0, 8), Vector3(0, 0, -16)]:
		_bloc(Vector3(1.6, 3.2, 1.6), p + Vector3(0, 1.6, 0), pierre, Vector2(2, 3))
	_bloc(Vector3(44.0, 3.0, 0.6), Vector3(0, 1.5, -22.0), pierre, Vector2(22, 3))

func _cibles() -> void:
	if _arg("test") != "":
		return
	_mode = _arg("seul", "troll")
	var vie := float(_arg("vie", "0"))
	if _mode == "mage":
		_cible = creer_ennemi(MAGE, Vector3(0, 0.05, -10.0), {"ident": "mage_test", "vie_imposee": vie})
	else:
		_cible = creer_ennemi(TROLL, Vector3(0, 0.05, -12.0), {"ident": "troll_test", "vie_imposee": vie})
	_cible.rotation.y = 0.0
	cibles.append(_cible)
	_silhouette()

## Crée un ennemi à IA (EnnemiBase) comme monde.creer_ennemi : enregistré dans `draugrs`.
func creer_ennemi(script: Script, pos: Vector3, options := {}) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(script)
	d.joueur = joueur
	d.hud = hud
	d.ident = String(options.get("ident", "ennemi_%d" % get_child_count()))
	d.name = d.ident
	for cle in options:
		d.set(cle, options[cle])
	draugrs[d.ident] = d
	d.position = pos
	add_child(d)
	return d

## Silhouette du joueur factice (guerrier nordique) : lisible dans la vue d'observateur.
func _silhouette() -> void:
	silhouette = GuerrierNordique.creer({})
	joueur.add_child(silhouette)
	silhouette.rotation.y = PI
	_sil_anim = silhouette.get_node_or_null("Animations") as AnimationPlayer
	_sil_jouer("Sword_Idle")

func _sil_jouer(clip: String, forcer := false) -> void:
	if _sil_anim == null or (clip == _sil_clip and not forcer) or not _sil_anim.has_animation(clip):
		return
	_sil_clip = clip
	_sil_anim.play(clip, 0.12)

# ------------------------------------------------------------------ pilote

func _pilote() -> void:
	await _attendre(1.0)
	_actif = true
	if _cible == null:
		return

func _physics_process(dt: float) -> void:
	if not _actif or _cible == null or not is_instance_valid(_cible):
		return
	_t_combat += dt
	_cd_coup -= dt
	_t_esquive -= dt
	var c := _cible
	var v := c.global_position - joueur.global_position
	v.y = 0.0
	var dist := v.length()
	var dir := v / maxf(dist, 0.01)
	if c.vivant():
		joueur.rotation.y = lerp_angle(joueur.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * dt))
	var mv := Vector3.ZERO
	var vitesse := 3.2
	joueur.garde = ""
	if not c.vivant():
		if _fin_combat < 0.0:
			_fin_combat = _t_combat
			print("PILOTE %s mort apres %.1f s, %d coups" % [_mode, _t_combat, _n_coups])
		if _t_combat - _fin_combat > 0.6 and not _captures_faites.has("mort"):
			_captures_faites["mort"] = true
			capturer.call_deferred("%s_mort" % _mode)
		if _t_combat - _fin_combat > 2.2:
			# gros plan sur le cadavre (ragdoll, plaies, flaque)
			var bassin: Node3D = c.combat._accroche("pelvis") if c.combat else null
			var pc: Vector3 = bassin.global_position if is_instance_valid(bassin) else c.global_position
			obs.global_position = obs.global_position.lerp(pc + Vector3(1.6, 1.7, 1.8), 1.0 - exp(-3.0 * dt))
			obs.look_at(pc, Vector3.UP)
			if _t_combat - _fin_combat > 3.4 and not _captures_faites.has("cadavre"):
				_captures_faites["cadavre"] = true
				capturer.call_deferred("%s_cadavre" % _mode)
		if _t_combat - _fin_combat > maxf(4.0, float(_arg("fin", "0"))):
			_actif = false
			get_tree().quit(0)
	elif _t_combat > 90.0:
		print("PILOTE délai dépassé, ", _mode, " vie=", c.vie)
		_actif = false
		get_tree().quit(1)
	elif _mode == "troll":
		mv = _pilote_troll(c, dist, dir)
	else:
		mv = _pilote_mage(c, dist, dir)
		vitesse = 4.2
	if _t_esquive > 0.0:
		mv = _esquive
		vitesse = 4.5
	var lent: float = joueur.lenteur_facteur if joueur.lenteur > 0.0 else 1.0
	joueur.global_position += mv * vitesse * lent * dt
	joueur.global_position.y = 0.0
	if joueur.garde != "":
		_sil_jouer("Sword_Idle")
	elif mv != Vector3.ZERO:
		_sil_jouer("Jog_Fwd")
		_sil_anim.speed_scale = clampf(vitesse * lent / 6.0 * 1.6, 0.5, 1.4)
	elif _sil_clip == "Jog_Fwd":
		_sil_anim.speed_scale = 1.0
		_sil_jouer("Sword_Idle")
	if c.vivant():
		_suivre_camera(dt)

func _esquiver(d: Vector3, duree: float) -> void:
	_esquive = d.normalized()
	_t_esquive = duree

func _coup(c: Node3D, motif: String, zone := "torse") -> void:
	if _cd_coup > 0.0:
		return
	_n_coups += 1
	frapper(c, motif, zone, _n_coups % 5 != 4)    # un coup sur cinq sans info (compatibilité mains.gd)
	_cd_coup = 0.55 if motif == "legere" else 0.95
	if _sil_anim:
		_sil_anim.speed_scale = 1.3
		_sil_jouer("Sword_Attack", true)
		_sil_clip = "Sword_Attack"
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _sil_clip == "Sword_Attack":
				_sil_anim.speed_scale = 1.0
				_sil_jouer("Sword_Idle"))

func _pilote_troll(c: Node3D, dist: float, dir: Vector3) -> Vector3:
	var e: int = c.etat
	if _t_combat < 6.0 and e in [c.GARDE, c.TRAQUE]:
		return -dir if dist < 10.0 else Vector3.ZERO     # il tient la distance : le troll charge
	if e == c.ECRASE and not c._coup_donne:
		var rel: Vector3 = joueur.global_position - c._centre_onde
		rel.y = 0.0
		_capture_unique("troll_ecrase_alerte", 0.5 < c._t)
		if rel.length() < c.RAYON_ONDE + 1.0:
			return rel.normalized() if rel.length() > 0.05 else -dir   # sortir du disque
		return Vector3.ZERO
	if e == c.ECRASE and c._coup_donne:
		_capture_unique("troll_onde", c._t > c.DUREE_ARMEMENT_ECRASE + 0.08)
		if dist > 2.0:
			return dir                                   # fenêtre de punition : il revient frapper
		_coup(c, "lourde", "torse")
		return Vector3.ZERO
	if e == c.CHARGE_ANNONCE:
		_capture_unique("troll_charge_annonce", c._t > 0.5)
		if c._t > 0.45 and _t_esquive <= 0.0:
			_esquiver(dir.cross(Vector3.UP) * (1.0 if int(c._t * 10) % 2 == 0 else -1.0), 0.9)
		return Vector3.ZERO
	if e == c.CHARGE:
		_capture_unique("troll_charge", c._t > 0.3)
		return Vector3.ZERO
	if e == c.BALAYAGE and not c._coup_donne:
		_capture_unique("troll_balayage_armement", c._t > c._t_impact * 0.6)
		if c._t > c._t_impact - 0.35:
			joueur.garde = "parade" if _n_coups % 3 != 2 else "bloque"
		return Vector3.ZERO
	if e == c.RAGE:
		_capture_unique("troll_rage", c._t > 0.7)
		return -dir if dist < 3.0 else Vector3.ZERO
	if e in [c.ETOURDI, c.SONNE, c.TITUBE]:
		_capture_unique("troll_etourdi", e == c.ETOURDI and c._t > 0.4 and c.rage)
		if dist > 2.0:
			return dir
		# vidéo : pas d'exécution avant la rage (on veut la voir), ensuite le coup lourd achève
		_coup(c, "lourde" if (c.rage or c.finisher_possible(joueur) == "") and _n_coups % 2 == 0 else "legere", "torse")
		return Vector3.ZERO
	if dist > 2.3:
		return dir
	if dist < 1.6:
		return -dir
	var motif := ["legere", "lourde", "legere", "chargee_max"][_n_coups % 4] as String
	if not c.rage and c.finisher_possible(joueur) != "":
		motif = "legere"
	_coup(c, motif, ["torse", "bras", "torse", "jambes"][_n_coups % 4])
	if _n_coups == 3:
		_capture_unique("troll_impact", true)
	return Vector3.ZERO

func _pilote_mage(c: Node3D, dist: float, dir: Vector3) -> Vector3:
	var e: int = c.etat
	var observe := _t_combat < 11.0
	# trait de givre en vol vers le joueur : pas de côté perpendiculaire à sa course
	for p in get_children():
		if p is Projectile and (p as Projectile).genre == "givre" and not (p as Projectile).plantee:
			var pr := p as Projectile
			var vers := joueur.global_position + Vector3(0, 1.1, 0) - pr.global_position
			if vers.length() < 8.0 and vers.normalized().dot(pr.vitesse.normalized()) > 0.85 and _t_esquive <= 0.0:
				_capture_unique("mage_trait_vol", true)
				var lat := pr.vitesse.cross(Vector3.UP)
				lat.y = 0.0
				_esquiver(lat * (1.0 if _n_coups % 2 == 0 else -1.0), 0.65)
	if e == c.INCANTE:
		_capture_unique("mage_incante", c._t > 0.6)
	if e == c.ZONE and not c._coup_donne:
		_capture_unique("mage_zone_alerte", c._t > 0.8)
		var rel: Vector3 = joueur.global_position - c._centre_zone
		rel.y = 0.0
		if rel.length() < c.RAYON_ZONE + 0.8 and c._t > 0.5:
			return rel.normalized() if rel.length() > 0.05 else dir.cross(Vector3.UP)
	if e == c.ZONE and c._coup_donne:
		_capture_unique("mage_zone_pics", c._t > c.ANNONCE_ZONE + 0.06)
	if e == c.TELEPORT:
		_capture_unique("mage_teleport", c._t > 0.3)
	if observe:
		# il reste à portée des sorts (9-10 m) en se décalant : traits et sort de zone à esquiver
		var lat := dir.cross(Vector3.UP) * (1.0 if int(_t_combat / 2.5) % 2 == 0 else -1.0)
		return (lat * 0.6 + dir * clampf(dist - 9.5, -1.0, 1.0)).normalized() * 0.7
	if e in [c.ETOURDI, c.TITUBE, c.CHUTE] or (dist < 2.2 and e != c.TELEPORT):
		if dist > 2.0:
			return dir
		var motif := "legere" if _n_coups % 3 != 2 else "lourde"
		_coup(c, motif, "torse" if _n_coups % 4 != 3 else "tete")
		if _n_coups == 2:
			_capture_unique("mage_impact", true)
		return Vector3.ZERO
	return dir

func _capture_unique(nom: String, cond: bool) -> void:
	if cond and not _captures_faites.has(nom):
		_captures_faites[nom] = true
		capturer.call_deferred(nom)

func _suivre_camera(dt: float) -> void:
	if vue != "obs" or _cible == null or not is_instance_valid(_cible):
		return
	var arriere := joueur.global_transform.basis.z
	arriere.y = 0.0
	arriere = arriere.normalized()
	var droite := arriere.cross(Vector3.UP)
	var recul := 3.8 if _mode == "troll" else 3.2
	var voulu := joueur.global_position + arriere * recul + Vector3(0, 2.1, 0) - droite * 1.3
	var k := 1.0 - exp(-4.0 * dt)
	obs.global_position = obs.global_position.lerp(voulu, k) if _t_combat > 0.1 else voulu
	var mi := joueur.global_position.lerp(_cible.global_position, 0.45) + Vector3(0, 1.3, 0)
	obs.look_at(mi, Vector3.UP)
