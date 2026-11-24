extends "res://outils/video_impacts_lances.gd"
## FILM des PROJECTILES : arme de bandit lancée (télékinésie : lame stabilisée nez en avant) qui se plante dans un bandit ; flèches du joueur
## (traînée discrète, fichées DANS le corps à l'os touché, qui suivent le ragdoll). Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --write-movie <x.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/video_projectiles_plantes.gd -- --nouvelle
##         [--sortie=<dossier des captures>] [--plans=arme,fleche,ragdoll] [--prefixe=apres]
## Légendes en bas de l'image ; ralenti à l'impact ; captures PNG rapprochées (<prefixe>_<plan>.png).

var legende: Label
var prefixe := "apres"

func _go() -> void:
	sortie = _arg("sortie", "")
	prefixe = _arg("prefixe", "apres")
	ralenti = _arg("sans-ralenti") == ""
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "nuit": ""}
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mannequin.position = Vector3(30, 0, 30)
	s.mur.position = Vector3(30, 1.3, 30)
	s.placer_joueur(Vector3(15, 0, 15), 180.0)
	s.hud.visible = false
	Sang.niveau_force = 2
	_salle()
	_tournage()
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	s.add_child(cam)
	cam.make_current()
	var cl := CanvasLayer.new()
	cl.layer = 50
	legende = Label.new()
	legende.add_theme_font_size_override("font_size", 14)
	legende.add_theme_color_override("font_outline_color", Color.BLACK)
	legende.add_theme_constant_override("outline_size", 8)
	legende.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legende.offset_top = -34
	legende.offset_left = 14
	cl.add_child(legende)
	root.add_child(cl)
	for p in _arg("plans", "arme,fleche,ragdoll").split(","):
		match p:
			"arme":
				await _plan_arme()
			"fleche":
				await _plan_fleche()
			"ragdoll":
				await _plan_ragdoll()
	_temps(1.0)
	quit(0)

func _titre(t: String) -> void:
	legende.text = t

func _plan_arme() -> void:
	_titre("Arme de bandit lancée (télékinésie) : elle se plante dans le corps")
	var b := _ennemi("bandit", Vector3(0.2, 0, -3.0), 400.0)
	_camera(Vector3(0.0, 1.62, 0.2), Vector3(0.2, 1.25, -3.0))
	await _attendre(0.9)
	var cible := b.global_position + Vector3(0, 1.3, 0)
	var o: RigidBody3D = LANCEUR.jeter(s, "hache_guerre", _main(), cible, 24.0, s.joueur)
	(o.get_node("SuiviLancer") as SuiviLancer).stabiliser = true      # comme la télékinésie
	await _attendre(maxf(_main().distance_to(cible) / 24.0 - 0.12, 0.0))
	_temps(0.3)
	await _attendre(0.35)
	_temps(1.0)
	await _attendre(0.4)
	await _attendre(0.3)
	var ab := ImpactsLances.axe_monde(o, o.donnees_arme())
	var pt: Vector3 = ab[1]
	var dehors: Vector3 = (Vector3(ab[0]) - pt).normalized()      # du corps vers la poignée (côté tireur)
	var lat := dehors.cross(Vector3.UP).normalized()
	var cm: Vector3 = Vector3(ab[0]) - dehors * 0.15
	_camera(cm + dehors * 0.9 + lat * 0.45 + Vector3(0, 0.2, 0), cm)
	await _attendre(0.25)
	await _capture(prefixe + "_arme")
	print("arme : ", ImpactsLances.dernier.get("issue", "?"), " plantee=", ImpactsLances.plantee(o))
	await _nettoyer([b, o])

func _tirer_fleche(vers: Vector3, v: float) -> Projectile:
	var de := _main()
	var f := Projectile.tirer_joueur(s, de, (vers - de).normalized(), s.joueur, 36.0, v, false)
	f.vitesse_reference = 100.0
	return f

func _plan_fleche() -> void:
	_titre("Flèche : traînée discrète, fichée DANS le corps")
	var b := _ennemi("bandit", Vector3(0.1, 0, -4.8), 900.0)
	_camera(Vector3(0.35, 1.7, 0.4), Vector3(0.1, 1.2, -4.8))
	await _attendre(0.9)
	var cible := b.global_position + Vector3(0.0, 1.25, 0)
	var f := _tirer_fleche(cible, 70.0)
	await _attendre(0.07)
	_temps(0.25)
	await _attendre(0.4)
	_temps(1.0)
	var sortant: Vector3 = -f.dir_impact
	var lat := sortant.cross(Vector3.UP).normalized()
	var pf: Vector3 = f.global_position + sortant * 0.35
	_camera(pf + sortant * 0.9 + lat * 0.5 + Vector3(0, 0.15, 0), pf)
	await _attendre(0.25)
	await _capture(prefixe + "_fleche")
	print("fleche : plantee=", f.plantee, " dans_corps=", f.get("_dans_corps"), " parent=", f.get_parent().name)
	await _nettoyer([b, f])

func _plan_ragdoll() -> void:
	_titre("Flèches dans un ennemi abattu : elles suivent le ragdoll")
	var b := _ennemi("bandit", Vector3(0.1, 0, -4.2), 60.0)
	_camera(Vector3(0.5, 1.7, 0.4), Vector3(0.1, 1.0, -4.2))
	await _attendre(0.8)
	var fl: Array = []
	for k in 3:
		fl.append(_tirer_fleche(b.global_position + Vector3(0.0, 1.3 - 0.2 * k, 0), 80.0))
		await _attendre(0.25)
	await _attendre(2.2)
	var cr := b.global_position + Vector3(0, 0.3, 0)
	var osr: Node3D = (fl[0] as Projectile).get_parent() as Node3D if is_instance_valid(fl[0]) else null
	if osr != null:
		cr = osr.global_position
	_travelling(cr + Vector3(-0.9, 0.9, 1.1), cr, 1.2)
	await _attendre(1.6)
	await _capture(prefixe + "_ragdoll")
	for f in fl:
		if is_instance_valid(f):
			print("ragdoll : fleche dans_corps=", f._dans_corps)
	await _nettoyer([b] + fl)
