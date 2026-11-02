extends SceneTree
## Film des coups d'arme à la 3e PERSONNE (branche tps/coups), vue de jeu (caméra derrière l'épaule), contre deux draugrs :
## combo 1-2-3-4 au rythme des clics, coups puissants dans les 4 directions (arrêt, en avançant, pas à droite, en reculant),
## blocage tenu + coup encaissé, claymore (combo + puissant), hache, masse. Ne cite aucune classe propre à tps/coups : le
## même script tourne sur biome/zone-temoin (avant/après honnête, mêmes entrées).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_coups_tps.gd -- --nouvelle
##         [--titre=après] [--orbite=60 (caméra tournée autour du joueur, degrés)] [--seulement=combo,puissants,garde,claymore,lourdes]
##         [--sans-draugrs=1 (planches de contrôle : rien devant la caméra tournée)]
const DT := 1.0 / 60.0
const POS_J := Vector3(0.0, 0.0, 7.0)

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label
var draugrs: Array[CharacterBody3D] = []
var _texte_base := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	for i in roundi(sec / DT):
		for d in draugrs:
			if is_instance_valid(d):
				d._recharge = 99.0
		var clip: String = mains.anim.reel(mains.anim.clip) if mains.anim.clip != "" else ""
		l.text = "%s — %s   [%s]" % [_arg("titre", ""), _texte_base, clip]
		await process_frame

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 500)
	calque.add_child(l)

func _poser_draugrs() -> void:
	for d in draugrs:
		if is_instance_valid(d):
			d.queue_free()
	draugrs.clear()
	if _arg("sans-draugrs", "") != "":
		return
	for x in [-0.7, 0.75]:
		var p := POS_J + Vector3(x, 0.0, -2.0)
		var d: CharacterBody3D = s.creer_draugr(p, false)
		d.rotation.y = atan2(p.x - POS_J.x, p.z - POS_J.z)
		d._bouclier = 0.0
		d.combat.profil.chance_blocage = 0.0
		d.vie_max = 900.0
		d.vie = 900.0
		d.combat.profil.posture_max = 9999.0
		d.combat.posture = 9999.0
		draugrs.append(d)

func _replacer() -> void:
	_poser_draugrs()
	s.placer_joueur(POS_J, 0.0, -6.0)
	j.camera_tp.recaler()
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	j.vigueur = j.vigueur_max
	await _attendre(0.5)

func _combo(n: int, intervalle := 0.47) -> void:
	for k in n:
		mains.entrees.appuyer()
		await _attendre(0.05)
		mains.entrees.relacher()
		await _attendre(intervalle - 0.05)

func _puissant(direction := "") -> void:
	if direction != "":
		Input.action_press(direction)
		await _attendre(0.25)
	mains.entrees.appuyer()
	await _attendre(0.8)
	if direction != "":
		Input.action_release(direction)
	mains.entrees.relacher()
	await _attendre(1.3)

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if id != "" else Equipement.new().main_droite)
	await _attendre(0.8)

func _parties() -> Array:
	var p := _arg("seulement", "combo,puissants,garde,claymore,lourdes")
	return p.split(",")

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-6.0, 0.0, -6.0)
	_etiquette(s)
	j.basculer_vue(true)
	var orb := _arg("orbite", "")
	if orb != "":
		j.camera_tp._orbite = deg_to_rad(float(orb))
		j.camera_tp.bras.position = Vector3.ZERO
	await _attendre(0.7)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
	var parties := _parties()
	if parties.has("combo"):
		await _replacer()
		_texte_base = "combo 1-2-3-4 (clics en rythme)"
		await _combo(4)
		await _attendre(0.8)
	if parties.has("puissants"):
		for d: Array in [["", "puissant à l'arrêt"], ["avant", "puissant en avançant"], ["droite", "puissant pas à droite"], ["arriere", "puissant en reculant"]]:
			await _replacer()
			_texte_base = d[1]
			await _puissant(d[0])
	if parties.has("garde"):
		await _replacer()
		_texte_base = "blocage tenu, coup encaissé"
		mains.entrees.forcer_garde(2.2)
		await _attendre(0.9)
		mains.encaisser()
		await _attendre(1.6)
	if parties.has("claymore"):
		await _equiper("claymore")
		await _replacer()
		_texte_base = "claymore : combo"
		await _combo(3, 0.75)
		await _attendre(0.9)
		_texte_base = "claymore : puissant"
		await _puissant()
		_texte_base = "claymore : blocage"
		mains.entrees.forcer_garde(1.4)
		await _attendre(1.6)
	if parties.has("lourdes"):
		for a: Array in [["hache_guerre", "hache"], ["masse_cloutee", "masse"]]:
			await _equiper(a[0])
			await _replacer()
			_texte_base = a[1] + " : combo"
			await _combo(3, 0.6)
			await _attendre(0.6)
			_texte_base = a[1] + " : puissant"
			await _puissant()
		await _equiper("")
	print("FIN_SEQUENCE")
	quit(0)
