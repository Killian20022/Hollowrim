class_name ArcJoueur
extends Node3D
## ARC DU JOUEUR (réglages : data/arc/arc_joueur.json). Équiper l'arc_chasseur (Sac > Armes, ou touche B) : le sabre est rangé,
## clic gauche MAINTENU = bander (zoom léger, marche ralentie, tension 0..1 en ~1 s), relâché = tirer une flèche du sac
## (id « fleche ») : Projectile.tirer_joueur, dégâts et vitesse selon la tension. Pas de flèche : pas de bandage (avis + son).
## Un relâché sous la tension minimale annule le tir sans perdre de flèche. Une flèche fichée dans le décor se ramasse en
## passant dessus (Projectile.recuperable, tirée au sort). Première personne : modèle calé sur la caméra (gants compris) ;
## troisième : le même modèle suit la main gauche du corps (clips Pistol_Aim_Neutral / Pistol_Shoot de la bibliothèque).
## Les tests pilotent l'arc sans souris : appuyer() / relacher(), `tenu_force`.

signal tir(info: Dictionary)
signal sans_fleche
signal change(actif: bool)

enum { REPOS, BANDE, RECUP }
const FICHIER := "res://data/arc/arc_joueur.json"

static var _r := {}

var joueur: CharacterBody3D
var actif := false
var etat := REPOS
var tension := 0.0
var tenu_force := false
var dernier_tir := {}
var tirs := 0
## Pas de souris réelle (tests, films) : seul `tenu_force` compte.
var souris_reelle := true
var _t_bande := 0.0
var _t_recup := 0.0
var _avis_donne := false
var _fov_base := -1.0
var _vm: ArcModele
var _tp: ArcModele
var _clip_tir := 0.0

static func reglages() -> Dictionary:
	if _r.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_r = d if d is Dictionary else {"_defaut": true}
	return _r

static func reglage(cle: String, defaut: float) -> float:
	return float(reglages().get(cle, defaut))

static func est_arc(id: String) -> bool:
	return id == String(reglages().get("id_arc", "arc_chasseur"))

func _id_fleche() -> String:
	return String(reglages().get("id_fleche", "fleche"))

func fleches() -> int:
	var inv: Variant = joueur.get("inventaire")
	return int(inv.nombre(_id_fleche())) if inv != null else 0

func _ready() -> void:
	name = "ArcJoueur"
	_vm = ArcModele.new()
	_vm.avec_mains()
	_vm.visible = false
	_vm.position = Vector3(-0.2, -0.2, -0.62)
	_vm.rotation_degrees = Vector3(0, 8, 8)
	joueur.camera.add_child(_vm)
	_tp = ArcModele.new()
	_tp.visible = false
	add_child(_tp)
	set_physics_process(true)

# ------------------------------------------------------------------ équipement

## Équipe l'arc (il faut l'arc au sac). "" ou la raison du refus.
func equiper() -> String:
	var inv: Variant = joueur.get("inventaire")
	if inv == null or not inv.a(String(reglages().get("id_arc", "arc_chasseur"))):
		return "Pas d'arc dans le sac."
	if actif:
		return ""
	actif = true
	_actualiser_vue()
	change.emit(true)
	return ""

func ranger() -> void:
	if not actif:
		return
	_annuler()
	actif = false
	_actualiser_vue()
	change.emit(false)

func basculer() -> String:
	if actif:
		ranger()
		return ""
	return equiper()

## Reprise de la vue (appelée aussi par joueur.basculer_vue).
func _actualiser_vue() -> void:
	var tp: bool = joueur.troisieme
	if joueur.mains != null:
		joueur.mains.visible = not tp and not actif
	_vm.visible = actif and not tp
	_tp.visible = actif and tp
	var corps: Node3D = joueur.corps
	if corps != null and corps.get("arme_corps") != null:
		corps.arme_corps.visible = not actif
	if not actif and _fov_base > 0.0:
		joueur.camera.fov = _fov_base
		_fov_base = -1.0

func vue_changee() -> void:
	_actualiser_vue()

func _unhandled_input(e: InputEvent) -> void:
	if joueur.mort or joueur.en_dialogue or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_B:
		var r := basculer()
		if r != "":
			joueur.avis.emit(r)

# ------------------------------------------------------------------ entrées

func appuyer() -> void:
	tenu_force = true

func relacher() -> void:
	tenu_force = false

func _tenu() -> bool:
	if joueur.mort or joueur.en_dialogue:
		return false
	return tenu_force or (souris_reelle and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

## Facteur de vitesse de marche du joueur (joueur.gd) : ralenti pendant le bandage.
func facteur_vitesse() -> float:
	if etat != BANDE:
		return 1.0
	return lerpf(1.0, reglage("vitesse_marche", 0.55), clampf(tension * 2.0, 0.0, 1.0))

## Clip du corps (corps_joueur.gd) : "" = marche normale.
func clip_tps() -> String:
	if not actif:
		return ""
	if etat == BANDE:
		return "Pistol_Aim_Neutral"
	if _clip_tir > 0.0:
		return "Pistol_Shoot"
	return ""

# ------------------------------------------------------------------ logique

func _physics_process(dt: float) -> void:
	if not actif:
		return
	if not joueur.inventaire.a(String(reglages().get("id_arc", "arc_chasseur"))):
		ranger()   # arc vendu ou lâché
		return
	_clip_tir = maxf(0.0, _clip_tir - dt)
	var tenu := _tenu()
	match etat:
		REPOS:
			if tenu:
				if fleches() <= 0:
					if not _avis_donne:
						_avis_donne = true
						joueur.avis.emit("Plus de flèches.")
						Sons.jouer(self, ["cloth1"], -14.0)
						sans_fleche.emit()
				else:
					etat = BANDE
					_t_bande = 0.0
					tension = 0.0
					_fov_base = joueur.camera.fov
					Sons.jouer(self, ["creak1"], -16.0, 0.1, &"", 1.4)
			else:
				_avis_donne = false
		BANDE:
			_t_bande += dt
			tension = clampf(_t_bande / maxf(reglage("temps_plein", 0.95), 0.05), 0.0, 1.0)
			if not tenu:
				if tension < reglage("tension_min", 0.12) or fleches() <= 0:
					_annuler()
				else:
					_tirer()
		RECUP:
			_t_recup -= dt
			tension = maxf(0.0, tension - dt * 6.0)
			if _t_recup <= 0.0:
				etat = REPOS
				tension = 0.0
				_avis_donne = tenu   # un clic tenu à la fin d'un tir ne ré-affiche pas l'avis en boucle
	_zoom(dt)
	_modeles()

func _annuler() -> void:
	etat = REPOS
	tension = 0.0
	_t_bande = 0.0
	if _fov_base > 0.0:
		joueur.camera.fov = _fov_base

func _zoom(dt: float) -> void:
	if _fov_base <= 0.0:
		return
	var cible := _fov_base - reglage("fov_zoom", 10.0) * (tension if etat == BANDE else 0.0)
	joueur.camera.fov = lerpf(joueur.camera.fov, cible, 1.0 - exp(-14.0 * dt))
	if etat == REPOS and absf(joueur.camera.fov - _fov_base) < 0.05:
		joueur.camera.fov = _fov_base
		_fov_base = -1.0

func _modele() -> ArcModele:
	return _tp if joueur.troisieme else _vm

func _modeles() -> void:
	var enc := etat == BANDE
	_vm.regler(tension, enc)
	_tp.regler(tension, enc)
	if joueur.troisieme:
		_placer_tp()
	var corps: Node3D = joueur.corps
	if corps != null and corps.get("arme_corps") != null:
		corps.arme_corps.visible = false

## Troisième personne : l'arc suit la main gauche du corps, debout, tourné comme la visée (lacet du joueur + tangage de la tête).
func _placer_tp() -> void:
	var corps: Node3D = joueur.corps
	var sq: Skeleton3D = corps.modele.find_child("Skeleton3D", true, false) if corps != null and corps.modele != null else null
	var main := Vector3(-0.2, 1.4, -0.5)
	var os_ := sq.find_bone("hand_l") if sq != null else -1
	if os_ >= 0:
		main = joueur.global_transform.affine_inverse() * (sq.global_transform * sq.get_bone_global_pose(os_).origin)
		if etat != BANDE:
			main += Vector3(0.0, 0.0, -0.05)
	var basis_ := Basis.from_euler(Vector3(joueur.tete.rotation.x if etat == BANDE else 0.0, 0.0, 0.0))
	var base_joueur: Transform3D = joueur.global_transform
	_tp.global_transform = Transform3D(base_joueur.basis * basis_, base_joueur * main)

# ------------------------------------------------------------------ tir

func _tirer() -> void:
	var inv: Variant = joueur.inventaire
	inv.retirer(_id_fleche(), 1)
	var t := tension
	var degats := lerpf(reglage("degats_min", 7.0), reglage("degats_max", 36.0), t)
	var vit := lerpf(reglage("vitesse_min", 13.0), reglage("vitesse_max", 34.0), t)
	var cam: Camera3D = joueur.camera
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 90.0)
	q.exclude = [joueur.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var cible: Vector3 = r["position"] if not r.is_empty() else o + d * 60.0
	var depart := _modele().pointe()
	if depart.distance_to(o) < 0.2 or depart.distance_squared_to(cible) < 1.0:
		depart = o + d * 0.7
	var dir := Projectile.cap_visee(depart, cible, vit) if depart.distance_to(cible) > 2.0 else (cible - depart).normalized()
	var recup := randf() < reglage("fleche_recuperable", 0.6)
	var p := Projectile.tirer_joueur(joueur.get_parent(), depart, dir, joueur, degats, vit, recup)
	dernier_tir = {"tension": t, "degats": degats, "vitesse": vit, "projectile": p, "depart": depart, "direction": dir}
	tirs += 1
	Sons.jouer(self, ["knifeSlice2"], -6.0, 0.1, &"", 0.7 + 0.5 * t)
	etat = RECUP
	_t_recup = reglage("recuperation", 0.42)
	_clip_tir = _t_recup
	_t_bande = 0.0
	tir.emit(dernier_tir)
