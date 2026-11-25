extends SceneTree
## Test sans fenêtre : l'arc ne bloque plus le changement d'arme / de sort, et en 3e personne une main qui tient un sort n'affiche
## plus l'arme ni le bouclier d'avant :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_arc_equipement.gd
## 1. arc équipé (repos, bandé, après un tir, 1re et 3e personne) -> épée, sort (main droite / gauche), main nue, torche, raccourcis,
##    menu (InventaireMains), entrées clavier réelles : l'arc est rangé, l'équipement demandé est en main ; puis retour à l'arc.
## 2. 3e personne, pour chaque combinaison de mains (sort/sort, sort/arme, arme/bouclier, arc, mains nues) : aucune arme ni bouclier
##    visible sur le corps pour une main qui tient un sort ou rien.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var arc: ArcJoueur
var mg: MainSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		j.mana = j.mana_max
		j.mains.avancer(DT)
		await physics_frame
	await process_frame

func _touche(code: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = p
		j.mains._unhandled_input(e)

## Met l'arc dans l'état voulu : "repos", "bande" (tension > 0.5), "apres_tir".
func _etat_arc(etat: String) -> void:
	if not arc.actif:
		_verif(arc.equiper() == "" and arc.actif, "arc équipé (%s)" % etat)
	match etat:
		"bande":
			arc.appuyer()
			await _sim(0.8)
		"apres_tir":
			arc.appuyer()
			await _sim(0.8)
			arc.relacher()
			await _sim(0.3)
	await _sim(0.1)

func _tenu(m: String) -> String:
	return String(mg.eq.mains[m].get("id", "vide"))

## Corps (3e personne) : noms des objets d'arme ou de bouclier visibles.
func _visibles_corps() -> Array:
	var t: CorpsMainsTps = j.corps.mains_tps
	var r := []
	for nom in ["_arme_d", "_objet_g"]:
		var o: Variant = t.get(nom)
		if o is Node3D and is_instance_valid(o) and (o as Node3D).is_visible_in_tree():
			r.append(nom)
	var f: Variant = j.corps.get("arme_corps")
	if f is Node3D and is_instance_valid(f) and (f as Node3D).is_visible_in_tree():
		r.append("arme_corps")
	return r

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	arc = j.arc
	arc.souris_reelle = false
	mg = j.mains.magie
	mg.eq.apprendre_tout()
	s.mannequin.position = Vector3(0, 0, -9)
	j.mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 30)
	for i in 20:
		await physics_frame
	await _changements()
	await _corps()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

func _changements() -> void:
	var cas := {
		"menu : épée": func() -> void: s.inventaire_ui.equiper("droite", "epee"),
		"menu : sort main droite": func() -> void: s.inventaire_ui.equiper("droite", "boule_feu"),
		"menu : sort main gauche": func() -> void: s.inventaire_ui.equiper("gauche", "jet_flammes"),
		"menu : bouclier": func() -> void: s.inventaire_ui.equiper("gauche", "bouclier"),
		"menu : main nue": func() -> void: s.inventaire_ui.retirer_main("droite"),
		"raccourci 1": func() -> void: await _touche(KEY_1),
		"raccourci 2": func() -> void: await _touche(KEY_2),
		"magie directe": func() -> void: mg.equiper("gauche", "boule_feu"),
		"touche X (télékinésie)": func() -> void: await _touche(KEY_X),
	}
	for vue in [false, true]:
		j.basculer_vue(vue)
		for etat in ["repos", "bande", "apres_tir"]:
			for nom in cas:
				mg.equiper("droite", "epee")
				mg.equiper("gauche", "vide")
				if arc.actif:
					arc.ranger()
				await _sim(0.05)
				await _etat_arc(etat)
				var avant := "%s|%s" % [_tenu("gauche"), _tenu("droite")]
				await cas[nom].call()
				await _sim(0.1)
				var tag := "%s, %s, arc %s" % ["3e pers." if vue else "1re pers.", nom, etat]
				_verif(not arc.actif, "%s : l'arc est rangé" % tag)
				if nom.begins_with("menu : épée") or nom == "raccourci 1" or nom == "raccourci 2":
					_verif(j.mains._peut_agir(), "%s : l'épée reprend la main" % tag)
				else:
					_verif("%s|%s" % [_tenu("gauche"), _tenu("droite")] != avant or nom.begins_with("raccourci"), "%s : l'équipement demandé est en main (%s|%s)" % [tag, _tenu("gauche"), _tenu("droite")])
				# retour à l'arc : possible
				var r: String = s.inventaire_ui.equiper("droite", "arc_chasseur")
				await _sim(0.1)
				_verif(arc.actif and r == "", "%s : retour à l'arc" % tag)
				arc.ranger()
	# l'arc seul, sans rien d'autre : la touche B le range et le ressort
	j.basculer_vue(false)

func _combos() -> Array:
	return [
		["sort/sort", "boule_feu", "jet_flammes", false],
		["sort/arme", "epee", "jet_flammes", false],
		["arme/sort", "boule_feu", "torche", false],
		["arme/bouclier", "epee", "bouclier", false],
		["bouclier+sort droit", "boule_feu", "bouclier", false],
		["arc", "epee", "bouclier", true],
		["mains nues", "vide", "vide", false],
		["sort/main nue", "boule_feu", "vide", false],
		["arme/main nue", "epee", "vide", false],
	]

func _corps() -> void:
	j.basculer_vue(true)
	for c in _combos():
		if arc.actif:
			arc.ranger()
		# d'abord épée + bouclier (état « d'avant »), puis la combinaison
		mg.equiper("droite", "epee")
		mg.equiper("gauche", "bouclier")
		await _sim(0.2)
		if c[3]:
			arc.equiper()
		else:
			mg.equiper("droite", c[1])
			mg.equiper("gauche", c[2])
		await _sim(0.3)
		var v := _visibles_corps()
		var dr := String(c[1])
		var ga := String(c[2])
		var arme_ok: bool = (dr == "epee" and not c[3])
		var boucl_ok: bool = (ga == "bouclier" and not c[3])
		var attendu := []
		if arme_ok:
			attendu.append("_arme_d")
		if boucl_ok:
			attendu.append("_objet_g")
		var ok := true
		for n in v:
			if not attendu.has(n):
				ok = false
		for n in attendu:
			if not v.has(n):
				ok = false
		_verif(ok, "3e personne, %s (%s / %s) : visibles %s, attendus %s" % [c[0], dr, ga, v, attendu])
