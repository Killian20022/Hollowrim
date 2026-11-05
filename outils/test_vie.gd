extends SceneTree
## Lot vie_pnj (P1-P3) : le village vit, dort, fuit et se souvient.
##   - planning à 8 h / 13 h (au poste) / 20 h (soirée) / 23 h / 3 h (tous endormis, cachés, sans collision, sauf Haldor) / réveil ;
##   - rentrée à pied (RENTRE puis DORT) et sortie à pied, sans téléportation quand l'heure avance normalement ;
##   - fuite devant un hostile à moins de 15 m, gardes alertés par le bus, retour une fois le danger passé ;
##   - répliques contextuelles (nuit, danger) et voix à travers la porte la nuit ;
##   - sauvegarde : clé `vie` (compteur d'alarmes), absente d'une ancienne sauvegarde = sans erreur.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_vie.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var vie: Vie
var _echecs := 0
var _evts: Array = []

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame

## Heure sautée : placement direct de tout le monde (comme au chargement d'une partie).
func _heure(h: float) -> void:
	m.cycle.heure = h
	vie.tick()
	await _attendre(0.2)

func _nb(f: Callable) -> int:
	var k := 0
	for c: Dictionary in vie.civils:
		if f.call(c):
			k += 1
	return k

## Réveillé, visible, et soit à moins de 3 m de son poste, soit en promenade (ALLER / PAUSE / RETOUR : 1, 2, 3) comme avant le lot.
func _a_son_poste(c: Dictionary) -> bool:
	var n: Node3D = c["n"]
	if n.est_endormi() or not n.visible:
		return false
	return n.global_position.distance_to(n.points[0]) < 3.0 or n.etat in [1, 2, 3]

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 10:
		await physics_frame
	vie = m.get_node_or_null("Vie")
	_verif(vie != null and m.vie == vie, "nœud Vie branché dans le monde (frère de GardesVillage)")
	if vie == null:
		_fin()
		return
	_verif(vie.civils.size() == 16, "16 civils enregistrés (6 nommés + 10 habitants) : %d" % vie.civils.size())
	var j: CharacterBody3D = m.joueur
	j.global_position = Vector3(44.0, m.hauteur(44.0, 40.0) + 0.2, 40.0)
	j.velocity = Vector3.ZERO
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED     # l'heure ne bouge que si le test la bouge
	var bus_ok := [false]
	vie.evenement.connect(func(t: String, _p: Vector3, _r: float, _s: Node) -> void:
		_evts.append(t))

	# --- planning : fenêtres horaires (calcul pur)
	for h in [8.0, 13.0]:
		var tous := true
		for c: Dictionary in vie.civils:
			tous = tous and EmploiDuTemps.mode(c["f"], h, c["id"]) == "poste"
		_verif(tous, "%.0f h : tous les civils sont en mode « poste »" % h)
	var soir := 0
	for c: Dictionary in vie.civils:
		if EmploiDuTemps.mode(c["f"], 20.0, c["id"]) == "soir":
			soir += 1
	_verif(soir == 15, "20 h : 15 civils en soirée (Haldor veille) : %d" % soir)
	for h in [23.0, 3.0]:
		var n := 0
		for c: Dictionary in vie.civils:
			if EmploiDuTemps.mode(c["f"], h, c["id"]) == "maison":
				n += 1
		_verif(n == 15, "%.0f h : 15 civils en mode « maison » : %d" % [h, n])

	# --- 8 h et 13 h : au poste
	for h in [8.0, 13.0]:
		await _heure(h)
		var loin := _nb(func(c: Dictionary) -> bool: return (c["n"] as Node3D).global_position.distance_to(c["n"].points[0]) > 2.5 or c["n"].est_endormi() or not c["n"].visible)
		_verif(loin == 0, "%.0f h : tous visibles et à moins de 2,5 m de leur poste (%d en défaut)" % [h, loin])

	# --- 20 h : soirée
	await _heure(20.0)
	var endormis := _nb(func(c: Dictionary) -> bool: return c["n"].est_endormi())
	var au_feu := 0
	var feu := Vector3(36.0, 0.0, 39.0)
	for c: Dictionary in vie.civils:
		var p: Vector3 = c["n"].global_position
		if String(c["f"].get("soir", "poste")) == "feu" and Vector2(p.x - feu.x, p.z - feu.z).length() < 3.2:
			au_feu += 1
	_verif(endormis == 0, "20 h : personne ne dort encore (%d)" % endormis)
	_verif(au_feu >= 6, "20 h : au moins 6 civils autour du feu de la place (%d)" % au_feu)
	var chef: Node3D = vie.civil("chef")["n"]
	_verif(chef.global_position.distance_to(m.village.lieux["longue_maison"]) < 3.5, "20 h : Gunnhild devant la longue maison")
	var brodd: Node3D = vie.civil("forgeron")["n"]
	_verif(brodd.global_position.distance_to(brodd.points[0]) < 1.0 and not brodd.est_endormi(), "20 h : le forgeron est encore à sa forge (services ouverts)")

	# --- 23 h et 3 h : le village est vide
	for h in [23.0, 3.0]:
		await _heure(h)
		var dort := _nb(func(c: Dictionary) -> bool: return c["n"].est_endormi())
		var caches := _nb(func(c: Dictionary) -> bool: return c["n"].est_endormi() and not c["n"].visible and c["n"].process_mode == Node.PROCESS_MODE_DISABLED and c["n"]._forme.disabled)
		var veille: Node3D = vie.civil("garde")["n"]
		_verif(dort == 15 and caches == 15, "%.0f h : 15 civils dorment, cachés, gelés et sans collision (%d / %d)" % [h, dort, caches])
		_verif(not veille.est_endormi() and veille.visible, "%.0f h : Haldor tient la porte" % h)

	# --- 7 h : réveil, tout le monde ressort
	await _heure(7.0)
	var sorti := _nb(func(c: Dictionary) -> bool: return not c["n"].est_endormi() and c["n"].visible and not c["n"]._forme.disabled and c["n"].process_mode == Node.PROCESS_MODE_INHERIT)
	_verif(sorti == 16, "7 h : tout le monde est réveillé, visible, solide et actif (%d / 16)" % sorti)

	# --- rentrée à pied (heure qui avance par petits pas : RENTRE puis DORT, sans téléportation)
	await _heure(21.0)
	var avant := {}
	for c: Dictionary in vie.civils:
		avant[c["id"]] = (c["n"] as Node3D).global_position
	var vus_rentre := 0
	for pas in [21.4, 21.8, 22.2, 22.6]:
		m.cycle.heure = pas
		vie.tick()
		await _attendre(1.0)
		vus_rentre = maxi(vus_rentre, _nb(func(c: Dictionary) -> bool: return c["n"].etat == 4))     # RENTRE
	_verif(vus_rentre >= 5, "rentrée : au moins 5 civils vus en train de rentrer à pied (état RENTRE) : %d" % vus_rentre)
	var chemin_ok := true
	for c: Dictionary in vie.civils:
		if c["n"].etat == 4 and c["id"] != "":
			var d: float = (c["n"] as Node3D).global_position.distance_to(avant[c["id"]])
			chemin_ok = chemin_ok and d < 30.0
	await _attendre(60.0)
	var dort2 := _nb(func(c: Dictionary) -> bool: return c["n"].est_endormi())
	_verif(dort2 == 15, "rentrée : 15 civils ont fini par s'endormir à la porte de leur bâtiment (%d)" % dort2)
	var coince := _nb(func(c: Dictionary) -> bool: return c["n"].etat == 4)
	_verif(coince == 0, "rentrée : personne n'est resté en route (%d)" % coince)

	# --- voix à travers la porte (marchands) : on frappe chez le forgeron
	m.cycle.heure = 23.5
	vie.tick()
	var pf: Vector3 = vie._portes["forge"]["pos"]
	j.global_position = Vector3(pf.x, pf.y + 0.2, pf.z)
	vie._frappe_t = 0.0
	vie._frapper(23.5)
	var st: String = m.dialogue._sous_titre.text
	_verif(st.begins_with("Brodd") and st.length() > 12, "la nuit, à sa porte, le forgeron répond : « %s »" % st)
	j.global_position = Vector3(44.0, m.hauteur(44.0, 40.0) + 0.2, 40.0)

	# --- réveil à pied
	await _heure(5.0)
	_verif(_nb(func(c: Dictionary) -> bool: return c["n"].est_endormi()) == 15, "5 h : ils dorment encore")
	for pas in [5.4, 5.8, 6.2, 6.6, 7.0, 7.4]:
		m.cycle.heure = pas
		vie.tick()
		await _attendre(1.0)
	await _attendre(45.0)
	var au_poste := _nb(func(c: Dictionary) -> bool: return _a_son_poste(c))
	_verif(au_poste == 16, "réveil à pied : les 16 civils sont à leur poste ou en promenade autour (%d)" % au_poste)

	# --- fuite devant un hostile (P2) : faux loup à 10 m du centre
	await _heure(12.0)
	_evts.clear()
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nfunc en_combat() -> bool:\n\treturn false\nfunc vivant() -> bool:\n\treturn true\n"
	sc.reload()
	var loup := Node3D.new()
	loup.set_script(sc)
	loup.add_to_group("ennemis")
	m.add_child(loup)
	loup.global_position = Vector3(44.0, m.hauteur(44.0, 40.0), 31.0)
	await _attendre(1.5)
	var attendus := 0
	var fuient := 0
	for c: Dictionary in vie.civils:
		var p: Vector3 = (c["n"] as Node3D).global_position
		var d := Vector2(p.x - loup.global_position.x, p.z - loup.global_position.z).length()
		if c["id"] != "garde" and d < 14.0:
			attendus += 1
			if c["fuit"]:
				fuient += 1
	_verif(attendus >= 2, "loup au centre : au moins 2 civils à moins de 14 m (%d)" % attendus)
	_verif(fuient == attendus, "tous les civils proches fuient (%d / %d)" % [fuient, attendus])
	_verif(_evts.has("alarme") and _evts.has("danger"), "le bus d'événements a vu « danger » et « alarme » : %s" % str(_evts.slice(0, 4)))
	_verif(not vie.civil("garde")["fuit"], "Haldor ne fuit pas")
	var gv: Node = m.get_node("GardesVillage")
	var alerte := 0
	for g: Node in gv.gardes:
		if g.etat == 3:
			alerte += 1
	_verif(alerte >= 1, "les gardes sont alertés par le bus : %d en alerte" % alerte)
	await _attendre(12.0)
	var abris := _nb(func(c: Dictionary) -> bool: return c["fuit"] and c["n"].est_endormi())
	_verif(abris >= fuient, "les fuyards sont à l'abri (%d / %d)" % [abris, fuient])
	_verif(vie.alarmes >= fuient, "compteur d'alarmes : %d" % vie.alarmes)
	var ligne_danger: String = vie.replique_contextuelle(chef)
	_verif(ligne_danger != "" and vie.contexte_de(chef) == "danger", "dialogue : contexte « danger » (« %s »)" % ligne_danger)
	var repl: Dictionary = vie._repliques
	var danger_chef: Array = repl["pnj"]["chef"]["danger"]
	_verif(ligne_danger in danger_chef, "dialogue : réplique propre à Gunnhild")
	# retour une fois le danger passé
	loup.queue_free()
	await _attendre(DELAI_RETOUR_S + 4.0)
	var encore := _nb(func(c: Dictionary) -> bool: return c["fuit"])
	_verif(encore == 0, "danger passé : plus personne ne fuit (%d)" % encore)
	await _attendre(50.0)
	var revenus := _nb(func(c: Dictionary) -> bool: return _a_son_poste(c))
	for c: Dictionary in vie.civils:
		var dd: float = (c["n"] as Node3D).global_position.distance_to(c["n"].points[0])
		if dd >= 3.0 or c["n"].est_endormi():
			print("   hors poste : %s à %.1f m, état %d, route %d, fuit %s, mode %s" % [c["id"], dd, c["n"].etat, c["n"]._route.size(), c["fuit"], c["mode"]])
	_verif(revenus == 16, "danger passé : les 16 civils sont de retour à leur poste ou en promenade (%d / 16)" % revenus)

	# --- dialogues contextuels
	vie.dernier_danger = -1.0e9
	for c: Dictionary in vie.civils:
		c["retour_t"] = -1.0e9
	m.cycle.heure = 20.0
	vie._heure_prec = 20.0
	var l_nuit: Array = chef.parler()
	chef.fin_conversation()
	var nuits: Array = repl["pnj"]["chef"]["nuit"]
	_verif(l_nuit.size() >= 2 and String(l_nuit[0]) in nuits, "20 h : Gunnhild ouvre sur une réplique de soirée (« %s »)" % str(l_nuit[0]))
	m.cycle.heure = 12.0
	var l_jour: Array = chef.parler()
	chef.fin_conversation()
	_verif(String(l_jour[0]) not in nuits and String(l_jour[0]) not in danger_chef, "12 h, calme : ses répliques d'origine (« %s »)" % str(l_jour[0]))
	var pay: Node = vie.civil("hab_paysan_1")["n"]
	vie.dernier_danger = vie._horloge
	var l_p: Array = pay.parler()
	pay.fin_conversation()
	var danger_types: Array = repl["types"]["paysan"]["danger"]
	_verif(String(l_p[0]) in danger_types, "paysan : réplique de type après un danger (« %s »)" % str(l_p[0]))
	vie.dernier_danger = -1.0e9

	# --- sauvegarde
	var n_alarmes := vie.alarmes
	var d := JSON.parse_string(JSON.stringify(vie.exporter())) as Dictionary
	vie.alarmes = 0
	vie.restaurer(d)
	_verif(vie.alarmes == n_alarmes and n_alarmes > 0, "sauvegarde : alarmes %d restaurées (aller-retour JSON)" % n_alarmes)
	vie.restaurer({})
	_verif(vie.alarmes == 0, "ancienne sauvegarde (sans clé vie) : pas d'erreur, compteur à 0")
	m.sauvegarder()
	var fich: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	var sv: Variant = JSON.parse_string(FileAccess.get_file_as_string(fich))
	_verif(sv is Dictionary and (sv as Dictionary).get("vie") is Dictionary and int(sv["vie"].get("v", 0)) == 1, "le fichier de sauvegarde contient « vie » : %s" % str((sv as Dictionary).get("vie")))
	_fin()

const DELAI_RETOUR_S := 9.0

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
