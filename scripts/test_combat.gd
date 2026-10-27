extends Node3D
## Scène de test du combat (réutilisable, prompt §18) : scenes/test_combat.tscn.
## Joueur (vrais bras, vraie épée, vraie torche), mannequin d'entraînement qui affiche les dégâts, un draugr guerrier,
## un mur pour les collisions de la lame, éclairage clair, débogage (F3 : tracé de lame, état de combat, endurance).
## Lancement (fenêtre) :
##   godot --path <projet> res://scenes/test_combat.tscn -- [--nuit] [--draugr=actif|fige|aucun] [--debug-combat]
##        [--sans-zone] [--zone-draugr=fige|actif|aucun]   (zone de collisions à 12 m à droite : ZoneCollisions)
## Par défaut le draugr est actif (il traque et frappe) ; « fige » le laisse debout sans IA (cible immobile).
## Test automatique sans fenêtre : outils/test_combat_epee.gd (même scène).

const JOUEUR := preload("res://scripts/joueur.gd")
const DRAUGR := preload("res://scripts/draugr.gd")
const MANNEQUIN := preload("res://scripts/combat/mannequin.gd")
const HUD := preload("res://scripts/hud.gd")
const POST := preload("res://shaders/ps1_post.gdshader")

## Positions (le joueur part de l'origine, face à -Z).
const POS_MANNEQUIN := Vector3(0.0, 0.0, -1.75)
const POS_DRAUGR := Vector3(3.2, 0.0, -3.6)
## Mur : face tournée vers +X (à 3,05 m à gauche du point de départ : hors de portée des coups contre le mannequin).
const POS_MUR := Vector3(-3.2, 1.3, 1.0)
const TAILLE_MUR := Vector3(0.3, 2.6, 3.0)
## Zone de collisions (ZoneCollisions : murs fins, coin, porte, cibles serrées, poteau, draugrs) : à 12 m à droite.
## Présente en jeu (scène lancée à la main) sauf --sans-zone ; un script (test, capture) la demande par options["zone"].
const POS_ZONE := Vector3(12.0, 0.0, 0.0)

var joueur: CharacterBody3D
var mannequin: StaticBody3D
var draugr: CharacterBody3D
var mur: StaticBody3D
var zone: ZoneCollisions
var hud: Control
var inventaire_ui: InventaireMains
var soleil: DirectionalLight3D
var env: Environment
## Réglages imposés par un script (tests, captures) avant l'entrée dans l'arbre ; priment sur la ligne de commande.
var options := {}

func _args() -> Dictionary:
	var d := options.duplicate()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if not d.has(kv[0]):
			d[kv[0]] = kv[1] if kv.size() > 1 else ""
	return d

func _ready() -> void:
	var a := _args()
	_ambiance(a.has("nuit"))
	_sol()
	mur = _boite_statique(POS_MUR, TAILLE_MUR, Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.5), Vector2(3, 3)))
	mannequin = StaticBody3D.new()
	mannequin.set_script(MANNEQUIN)
	mannequin.position = POS_MANNEQUIN
	add_child(mannequin)
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	add_child(joueur)
	mannequin.set("joueur", joueur)
	_interface()
	var mode_draugr: String = a.get("draugr", "actif")
	if mode_draugr != "aucun":
		draugr = creer_draugr(POS_DRAUGR, mode_draugr == "fige")
	if a.has("zone") or (options.is_empty() and not a.has("sans-zone")):
		zone = ZoneCollisions.new()
		zone.joueur = joueur
		zone.mode_draugr = String(a.get("zone-draugr", "fige"))
		zone.position = POS_ZONE
		add_child(zone)

func creer_draugr(p: Vector3, fige: bool) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "guerrier"
	d.joueur = joueur
	d.hud = hud   # butin lâché à la mort (avis « + n pièces »)
	d.ident = "draugr_test"
	d.position = p
	d.rotation.y = atan2(p.x, p.z)   # tourné vers l'origine
	add_child(d)
	if fige:
		d.set_physics_process(false)
		d.set_process(false)
	return d

func _ambiance(nuit: bool) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06) if nuit else Color(0.55, 0.64, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.62)
	env.ambient_light_energy = 0.25 if nuit else 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.9
	for i in 7:
		env.set_glow_level(i, 1.0 if (i == 1 or i == 2) else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.basis = Basis.looking_at(Vector3(0.4, -0.75, -0.55), Vector3.UP)
	soleil.light_color = Color(0.62, 0.72, 1.0) if nuit else Color(1.0, 0.95, 0.86)
	soleil.light_energy = 0.35 if nuit else 1.25
	soleil.shadow_enabled = true
	add_child(soleil)

func _sol() -> void:
	_boite_statique(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Palette.materiau(Palette.tex("neige_pietinee", Palette.NEIGE_PIETINEE, 4, 0.5), Vector2(20, 20)))

func _boite_statique(p: Vector3, taille: Vector3, m: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = p
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	f.shape = bs
	b.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	return b

func _interface() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = POST
	rect.material = post
	calque.add_child(rect)
	hud = Control.new()
	hud.set_script(HUD)
	hud.joueur = joueur
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(hud)
	inventaire_ui = InventaireMains.new()   # inventaire des deux mains (I)
	inventaire_ui.joueur = joueur
	inventaire_ui.hud = hud
	add_child(inventaire_ui)
	var aide := Label.new()
	aide.text = "Clic gauche : coup léger (maintenir : lourd)   Clic droit : garde   T : torche   F3 : débogage"
	aide.add_theme_font_override("font", Palette.police())
	aide.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	aide.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
	aide.position = Vector2(6, 340)
	aide.visible = not _args().has("sans-aide")
	calque.add_child(aide)

## Place le joueur (tests, captures) : position au sol, lacet en degrés (0 = face à -Z), tangage en degrés.
func placer_joueur(p: Vector3, lacet_deg: float, tangage_deg := 0.0) -> void:
	joueur.global_position = p
	joueur.rotation.y = deg_to_rad(lacet_deg)
	joueur.tete.rotation.x = deg_to_rad(tangage_deg)
	joueur.velocity = Vector3.ZERO
