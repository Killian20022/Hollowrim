extends SceneTree
## Captures du FEU SUR LE CORPS (socle ImpactCorps, docs/MAGIE_IMPACT_CORPS.md) : galerie de la magie (crypte de nuit, vraie
## main gauche du héros, draugrs DraugrNordique), jet de flammes simple ou double sur le draugr du milieu.
##   godot --path . --script res://outils/captures_impact_feu.gd -- --sortie=<dossier> [--cas=face,trois_quarts,...]
##       [--sans-impact-corps]   rendu d'AVANT (gerbe en boîte + voile de statut) pour les planches avant | après
##       [--seul-corps]          jet et aura masqués : on ne voit que ce qui naît sur le corps (mise au point)
##       [--sans-voile] [--sans-coque]  mise au point : voile / coque éteints
##       [--cote]                ajoute une vue de côté (caméra à 3 m) de chaque capture : contrôle de la silhouette
##       [--detail-sorts=retro|moyen|eleve]  (défaut : élevé, comme la galerie)
## Cas : face, trois_quarts, profil, marche, attaque, chute, brulure, double. Une image par instant listé dans CAS.
## La fenêtre est mise en 1280x720 (planches) ; lancer par /tmp/godot_slot.sh (fenêtre hors écran).

const GALERIE := preload("res://scenes/galerie_magie.tscn")
## nom : [lacet du draugr (°, 0 = face au joueur), durée du jet (s), instants de capture (s), double]
const CAS := {
	"face": [0.0, 2.0, [0.45, 1.3], false],
	"trois_quarts": [45.0, 2.0, [1.3], false],
	"profil": [90.0, 2.0, [1.3], false],
	"marche": [20.0, 2.4, [1.0, 1.9], false],
	"attaque": [0.0, 2.4, [0.9, 1.6], false],
	"chute": [0.0, 3.2, [1.15, 1.6, 2.6], false],
	"brulure": [15.0, 1.4, [1.2, 1.9, 3.0, 4.8, 8.5], false],
	"double": [0.0, 2.0, [1.3], true],
}

var g: Node3D
var sortie := ""
var cote := false
var cam_cote: Camera3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	sortie = _arg("sortie", "res://captures/impact_feu")
	cote = _arg("cote") != ""
	ImpactCorps.actif = _arg("sans-impact-corps") == ""
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	g = GALERIE.instantiate()
	root.add_child(g)
	current_scene = g
	for k in 90:
		await process_frame
	var liste := _arg("cas")
	for nom: String in CAS:
		if liste != "" and not liste.split(",").has(nom):
			continue
		await _cas(nom)
	print("CAPTURES_IMPACT_FEU fini : ", sortie, " ", EffetsMagie.stats(), " ", ImpactCorps.stats())
	quit()

func _cas(nom: String) -> void:
	var c: Array = CAS[nom]
	var cibles: Array = g.cibles
	var d: Node3D = cibles[1]
	# remise à zéro : le draugr revient à sa place, debout, sans ragdoll
	EffetsMagie.tout_arreter()
	for k in 40:
		await process_frame
	for x: Node3D in cibles:
		x.visible = x == d or nom == "double"
	d.position = Vector3(0.0, 0.0, -4.3)
	d.rotation = Vector3(0.0, deg_to_rad(float(c[0])), 0.0)
	var ap := d.find_child("Animations", true, false) as AnimationPlayer
	var anim: String = {"marche": "Walk", "attaque": "Sword_Attack"}.get(nom, "Idle")
	if ap != null and ap.has_animation(anim):
		ap.play(anim)
		if nom == "attaque":
			ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	for k in 20:
		await process_frame
	var t := 0.0
	var instants: Array = (c[2] as Array).duplicate()
	var duree := float(c[1])
	var dbl: bool = c[3]
	var tombe := false
	var paume_g: Node3D = g.paume_g
	var paume_d: Node3D = g.paume_d
	var fin := maxf(duree, float(instants.back())) + 0.1
	EffetsMagie.double("feu", dbl)
	while t < fin:
		var dt := 1.0 / 60.0
		t += dt
		var actif := t > 0.05 and t < duree
		if nom == "marche":
			d.position += Basis(Vector3.UP, d.rotation.y).z * dt * 0.5
		if nom == "chute" and t > 0.8 and not tombe:
			tombe = true
			var rd := Ragdoll.equiper(d) as Ragdoll
			if rd != null:
				rd.declencher(Vector3(0.3, 0.6, -1.0) * 60.0, d.global_position + Vector3.UP * 1.3)
		var vise: Vector3 = d.global_position + Vector3.UP * (1.1 if not tombe else 0.5)
		EffetsMagie.aura_main(paume_g, "feu", 1.0 if t < duree + 0.3 else 0.0)
		EffetsMagie.jet("feu", paume_g, (vise - paume_g.global_position).normalized(), 7.0, 1.0, actif)
		if dbl:
			EffetsMagie.aura_main(paume_d, "feu", 1.0)
			EffetsMagie.jet("feu", paume_d, (vise - paume_d.global_position).normalized(), 7.0, 1.0, actif)
		if _arg("seul-corps") != "":
			for j: Dictionary in GestionMagie.instance._jets.values():
				for p in j.emit:
					(p as Node3D).visible = false
				if j.flux != null and is_instance_valid(j.flux):
					(j.flux as Node3D).visible = false
			for a: Dictionary in GestionMagie.instance._auras.values():
				(a.ancre as Node3D).visible = false
		if _arg("sans-voile") != "" and ImpactCorps.instance != null:
			ImpactCorps.instance.mat_voile.set_shader_parameter("eclat", 0.0)
		if _arg("sans-coque") != "" and ImpactCorps.instance != null:
			ImpactCorps.instance.mat_coque.set_shader_parameter("plein", false)
			ImpactCorps.instance.mat_coque.set_shader_parameter("eclat", 0.0)
		if _arg("debug-coque") != "" and ImpactCorps.instance != null:
			ImpactCorps.instance.mat_coque.set_shader_parameter("plein", true)
		if _arg("debug-poids") != "" and ImpactCorps.instance != null:
			for fo: ImpactCorps.Foyer in ImpactCorps.instance.foyers:
				ImpactCorps.instance.uniformes(fo, "poids_min", 1.0)
		# la logique pose la brûlure à chaque tic du jet (3 s, comme data/sorts/jet_flammes)
		if actif and t > 0.3:
			EffetsMagie.statut_cible(d, "brulure", 3.0)
		await process_frame
		if not instants.is_empty() and t >= float(instants[0]):
			await _capturer("%s_%.1f" % [nom, float(instants[0])], d)
			instants.pop_front()
	EffetsMagie.aura_main(paume_g, "feu", 0.0)
	EffetsMagie.aura_main(paume_d, "feu", 0.0)
	EffetsMagie.double("feu", false)
	EffetsMagie.statut_cible(d, "brulure", 0.0)
	if tombe:
		# un ragdoll ne se relève pas : on remplace le draugr pour les cas suivants
		var neuf := DraugrNordique.creer({})
		g.add_child(neuf)
		neuf.add_to_group("cibles_magie")
		cibles[1] = neuf
		d.queue_free()

func _capturer(nom: String, d: Node3D) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	img.save_png(sortie.path_join(nom + ".png"))
	if _arg("debug-lum") != "":
		for l: OmniLight3D in GestionMagie.instance._lumieres:
			print("  lum vis=", l.visible, " e=", l.light_energy, " portee=", l.omni_range, " dist_corps=", l.global_position.distance_to(d.global_position + Vector3.UP * 1.0))
		for l in g.find_children("*", "Light3D", true, false):
			if not GestionMagie.instance._lumieres.has(l):
				print("  autre lum ", l.name, " ", l.get_class(), " e=", (l as Light3D).light_energy, " vis=", (l as Light3D).is_visible_in_tree())
	if _arg("debug") != "" and ImpactCorps.instance != null:
		for fo: ImpactCorps.Foyer in ImpactCorps.instance.foyers:
			if fo.libre:
				continue
			var su := fo.surface
			print("  foyer ", fo.id, " nb=", su.nb, " repli=", su.repli(), " bas=", su.bas, " haut=", su.haut, " p0=", su.pos[0] if su.nb > 0 else Vector3.ZERO, " p5=", su.pos[mini(5, su.nb - 1)], " o=", fo.origine(), " d=", fo.d.get("imp"), " kj=", fo.d.get("k_jet"))
			for e: ImpactCorps.Emetteur in fo.em:
				print("    em vis=", e.p.visible, " emit=", e.p.emitting, " n=", e.p.amount, " r=", e.p.amount_ratio, " pos=", e.p.global_position, " calques=", e.p.layers, " vie=", e.p.lifetime, " intree=", e.p.is_inside_tree())
	print("CAPTURE ", nom, " ", img.get_size(), " ", EffetsMagie.stats().particules, " part. ; corps ", ImpactCorps.stats())
	if cote:
		if cam_cote == null:
			cam_cote = Camera3D.new()
			cam_cote.fov = 50.0
			g.add_child(cam_cote)
		var c0 := root.get_camera_3d()
		var cible := d.global_position + Vector3.UP * 1.0
		cam_cote.global_position = cible + Vector3(2.6, 0.5, 1.2)
		cam_cote.look_at(cible)
		cam_cote.make_current()
		# l'occlusion de la couche fine reprojette la profondeur de l'image précédente : quelques images après la bascule
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(sortie.path_join(nom + "_cote.png"))
		if c0 != null:
			c0.make_current()
