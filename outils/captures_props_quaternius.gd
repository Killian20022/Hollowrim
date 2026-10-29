extends SceneTree
## ESSAI props Quaternius (branche essai/props_quaternius) : rendu DANS LE JEU (shader crypte, torche du joueur) des modules de
## assets/crypte/modules/props_quaternius.dat, par groupes posés devant le joueur à l'entrée de la crypte. Rien n'est intégré aux salles.
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_props_quaternius.gd -- --nouvelle --paisible
##         --sortie=<dossier>
const SCENE := preload("res://scenes/foret_test.tscn")
const DAT := "res://assets/crypte/modules/props_quaternius.dat"
## matières des props absentes de CrypteDecor.MAT_MODELE (sinon « mur0 »)
const MATS := {"lin": "lin", "laine": "laine", "jute": "jute", "or": "or", "os": "os", "toile": "toile", "argile": "argile", "noir": "noir", "lame": "lame"}
## groupes : [module, x (droite), z (vers le joueur), lacet en degrés, y]
const GROUPES := {
	"forge": [["q_enclume", 0.0, 0.0, 20, 0.0], ["q_pierre_aiguiser", -1.3, -0.3, 60, 0.0], ["q_etabli", 0.6, -1.2, 0, 0.0],
		["q_seau_fer", 0.8, 0.5, 0, 0.0], ["q_caisse", 1.9, -0.6, 15, 0.0], ["q_sac", 1.5, 0.4, 0, 0.0]],
	"auberge": [["q_grande_table", 0.0, -0.4, 0, 0.0], ["q_chaise", -0.6, 0.3, 180, 0.0], ["q_tabouret", 1.6, 0.2, 0, 0.0],
		["q_chope", -0.4, -0.3, 20, 0.81], ["q_chope", 0.5, -0.5, 70, 0.81], ["q_bougeoir_triple", 0.0, -0.4, 0, 0.81],
		["q_support_tonneau", -1.9, -1.2, 0, 0.0], ["q_seau_bois", 1.9, -0.9, 0, 0.0]],
	"alchimie": [["q_lutrin", -0.9, -0.3, 30, 0.0], ["q_etagere_fioles", 0.4, -1.1, 0, 0.0], ["q_cage", 1.6, -0.4, 20, 0.0],
		["q_pile_livres", 0.6, 0.2, 10, 0.0], ["q_parchemin", 0.2, 0.5, 40, 0.0], ["q_calice", 0.7, 0.2, 0, 0.21], ["q_chaudron", -0.3, 0.4, 0, 0.0]],
	"marche": [["q_etal", -1.0, -0.8, 10, 0.0], ["q_tonneau_pommes", 0.5, -0.1, 0, 0.0], ["q_cageot_pommes", 1.2, 0.4, -30, 0.0],
		["q_sac", -0.4, 0.4, 0, 0.0], ["q_caisse", 1.6, -0.9, 20, 0.0]],
}

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/props_quaternius"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	var t: Node3D = m.tertre
	m.hud.aide_t = 0.0
	t.attendre_donjon()
	t._basculer(true)
	await _images(90)
	var d2: CrypteDecor = t.d2
	CrypteDecor._charger_modeles()
	CrypteDecor._lire_dat(DAT)
	var j: CharacterBody3D = m.joueur
	j.mains.visible = false          # vue dégagée (la torche du joueur n'éclaire plus : lumière = braseros + appoint)
	var p0 := j.global_position
	var yaw := j.rotation.y
	var b := Basis(Vector3.UP, yaw)
	var avant := -b.z
	var centre := p0 + avant * 3.0
	for g: String in GROUPES:
		var poses: Array[Node3D] = []
		for e: Array in GROUPES[g]:
			var mi := d2.maillage_modele(String(e[0]), Vector3.ONE, MATS)
			if mi == null:
				continue
			root.add_child(mi)
			mi.global_position = centre + b * Vector3(float(e[1]), float(e[4]), float(e[2]))
			mi.global_rotation = Vector3(0, yaw + deg_to_rad(float(e[3])), 0)
			poses.append(mi)
		var lum := OmniLight3D.new()       # brasero hors champ : lumière chaude de la salle
		lum.light_color = Color(1.0, 0.62, 0.3)
		lum.light_energy = 1.6
		lum.omni_range = 7.0
		root.add_child(lum)
		lum.global_position = centre + b * Vector3(-1.5, 2.0, 1.0)
		poses.append(lum)
		await _images(20)
		j.global_position = p0
		j.velocity = Vector3.ZERO
		j.tete.rotation.x = -0.32
		await _images(20)
		await _capturer("jeu_%s_loin" % g)
		j.global_position = p0 + avant * 0.9 + b.x * 0.5
		j.tete.rotation.x = -0.42
		await _images(20)
		await _capturer("jeu_%s_pres" % g)
		for n in poses:
			n.queue_free()
		await _images(5)
	quit()
