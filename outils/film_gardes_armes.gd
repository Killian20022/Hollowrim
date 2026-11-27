extends SceneTree
## Film de la GARDE / BLOCAGE de chaque arme (branche combat/gardes_toutes_armes) : pour chaque arme, en vue 1re personne puis
## 3e personne (caméra de face-côté) : repos, montée en garde, garde tenue, coup bloqué (encaisse), parade parfaite, sortie.
##   godot --path . --fixed-fps 60 --write-movie f.avi --resolution 1280x720 --script res://outils/film_gardes_armes.gd
##         -- --nouvelle [--armes=epee_metal,hache_guerre] [--vues=1p,3p] [--titre=APRES] [--gardes-anciennes]
const SCENE := preload("res://scenes/test_combat.tscn")
var DT := 1.0 / 60.0   # --fps=<n> : pas de jeu par image (120 + --fixed-fps 120 lu à 30 : ralenti x0,25)
const ARMES := ["epee_metal", "dague_acier", "veilleuse", "claymore", "hache_guerre", "hachette", "masse_cloutee", "marteau_guerre", "grand_marteau"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var l: Label
var _cam: Camera3D
var _titre := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _images(n: int, garde := false, texte := "") -> void:
	if texte != "":
		l.text = _titre + texte
	for i in roundi(n / 60.0 / DT):   # n : images à 60 i/s (même durée de jeu quel que soit --fps)
		if garde:
			mains.entrees.forcer_garde(0.2)
		j.vigueur = j.vigueur_max
		mains.avancer(DT)
		if _cam != null:
			var p := j.global_position
			var avant := -j.global_transform.basis.z
			var droite := j.global_transform.basis.x
			_cam.global_position = p + avant * 2.3 + droite * 1.0 + Vector3.UP * 1.55
			_cam.look_at(p + Vector3.UP * 1.25 + droite * 0.1, Vector3.UP)
		await process_frame

func _sequence(id: String, vue: String) -> void:
	var nom := "%s  [%s]" % [id, "1re personne" if vue == "1p" else "3e personne"]
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else load("res://data/armes/%s.tres" % id))
	await _images(10, false)
	# armes à une main : la torche reste en main gauche (on vérifie que la garde ne la cache pas)
	if not mains.arme.deux_mains and not mains.torche_sortie:
		mains.torche_sortie = true
	await _images(30, false, nom + " : repos")
	await _images(70, true, nom + " : garde (clic droit)")
	var origine := j.global_position + (-j.global_transform.basis.z) * 2.0
	mains.defendre(10.0, origine, true)
	await _images(45, true, nom + " : coup bloqué")
	mains.entrees.forcer_garde(0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _images(20, false, nom + " : repos")
	mains.entrees.forcer_garde(0.2)
	await _images(2, true, nom + " : parade parfaite")
	mains.defendre(10.0, origine)
	await _images(40, true)
	await _images(40, false, nom + " : sortie de garde")

func _go() -> void:
	DT = 1.0 / float(_arg("fps", "60"))
	_titre = _arg("titre", "")
	if _titre != "":
		_titre += " — "
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	if s.get("mannequin") != null:
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
		s.mannequin.global_position = Vector3(40, 0, 40)
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	l = Label.new()
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	cl.add_child(l)
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var armes: Array = ARMES if _arg("armes") == "" else Array(_arg("armes").split(","))
	for vue in Array(_arg("vues", "1p,3p").split(",")):
		j.basculer_vue(vue == "3p")
		if vue == "3p":
			_cam = Camera3D.new()
			_cam.fov = 50.0
			root.add_child(_cam)
			_cam.make_current()
		for id in armes:
			await _sequence(id, vue)
		if _cam != null:
			_cam.queue_free()
			_cam = null
	quit(0)
