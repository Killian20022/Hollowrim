extends SceneTree
## Interaction crime x sommeil : un PNJ couché dans son lit est frappé puis agressé ;
##   - le 1er coup (avertissement, aucun dégât) le réveille : il se redresse (seq « redresser »), il n'encaisse pas le coup allongé ;
##   - le coup suivant convertit le PNJ en PnjCombat : le corps est pris DEBOUT (modèle remis à sa pose, lit libéré, plus de séquence de lit) ;
##   - le combattant pacifié rend le corps : le PNJ d'origine est visible, solide, debout, sans lit occupé, et Vie le replanifie.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_crime_sommeil.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	if m != null:
		m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	await _attendre(2.5)
	var vie: Vie = m.get_node_or_null("Vie")
	var cr: Crime = m.crime
	var j: CharacterBody3D = m.joueur
	_verif(vie != null and cr != null, "Vie et Crime présents")
	if vie == null or cr == null:
		_fin()
		return
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	# 3 h : heure sautée, les civils qui ont un lit y sont couchés
	m.cycle.heure = 3.0
	vie._heure_prec = -1.0
	vie.tick()
	await _attendre(0.5)
	var victimes: Array = []
	for cc: Dictionary in vie.civils:
		var nn: Node3D = cc["n"]
		if cc["id"] != "garde" and nn.au_lit() and nn.lit != null:
			victimes.append(nn)
	_verif(victimes.size() >= 2, "%d civils couchés dans un lit à 3 h" % victimes.size())
	if victimes.size() < 2:
		_fin()
		return
	# --- A. premier coup : avertissement, il se lève
	var a: Node3D = victimes[0]
	var lit_a: Lit = a.lit
	j.global_position = a.global_position + Vector3(0, 0.3, 1.2)
	await _attendre(0.3)
	var r1: String = a.recevoir_coup(10.0, j.global_position, false, {})
	_verif(r1 == "touche" and a.seq in ["redresser", "lever"], "coup sur un dormeur : avertissement (%s), il se redresse (seq « %s »)" % [r1, a.seq])
	# --- B. agression suivie : le corps passe au PnjCombat debout
	# l'avertissement est déjà consommé : le coup suivant est un vrai crime
	await _attendre(0.2)
	var r2: String = a.recevoir_coup(10.0, j.global_position, false, {})
	print("   2e coup -> « %s », dernier crime %s, horloge %.2f" % [r2, str(cr.dernier), cr._horloge])
	await _attendre(0.5)
	var cb: PnjCombat = cr.combattant_de(a)
	_verif(cb != null, "le coup suivant convertit le PNJ en combattant (%s)" % (cb.mode if cb else "aucun"))
	_verif(a.seq == "" and lit_a.occupants.all(func(o: Variant) -> bool: return o != a), "séquence de lit abandonnée, lit libéré")
	var mod: Node3D = cb.modele if cb != null else null
	var droit := mod != null and mod.global_transform.basis.y.dot(Vector3.UP) > 0.95
	_verif(droit, "le combattant est debout (haut du modèle %s)" % (str(mod.global_transform.basis.y) if mod else "?"))
	# --- C. calme : il rend le corps
	cr._gracier()
	cr.apaiser_tous()
	await _attendre(6.0)
	_verif(cr.combattants.is_empty() or cr.combattant_de(a) == null, "plus de combattant pour ce PNJ après l'apaisement")
	_verif(a.remplace == null and a.visible and not a._forme.disabled and a.seq == "", "le PNJ reprend son corps : visible, solide, hors du lit")
	_verif(a.modele != null and a.modele.get_parent() == a and a.modele.global_transform.basis.y.dot(Vector3.UP) > 0.95, "son modèle est rendu debout")
	await _attendre(2.0)
	vie.tick()
	await _attendre(1.0)
	_verif(is_instance_valid(a) and a.process_mode != Node.PROCESS_MODE_DISABLED, "Vie le replanifie (process actif)")
	_fin()
