extends SceneTree
## Test headless : après la mort du boss (Svanhild), l'écran ne doit pas trembler à l'infini (bug : _porte_haut était appelée
## à chaque image depuis tertre._process → tween + joueur.secousse relancés sans fin). Trois cas :
##   A. mort en jeu : les portes du tombeau et de l'arène s'ouvrent UNE fois (une secousse), puis secousse et caméra reviennent à 0 ;
##   B. partie chargée après la mort, donjon pas encore intégré (démarrage réel) : portes ouvertes à l'intégration, sans secousse ;
##   C. partie rechargée après la mort, donjon déjà intégré (portes refermées) : restaurer() les rouvre instantanément, sans secousse.
## Aucun fichier de sauvegarde n'est touché (état importé à la main).
## godot --headless --path . --script outils/test_secousse_boss.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _scene() -> Node3D:
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	for i in 5:
		await physics_frame
	return s

## Joueur dans l'arène, donjon complet.
func _descendre(s: Node3D) -> void:
	var t = s.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	t.dedans = true
	t.crypte.visible = true
	s.joueur.global_position = t.crypte.to_global(Vector3(-21, 0.1, -12))
	for i in 4:
		t._gerer_zones()
		await physics_frame

## Ennemis de la crypte figés : un coup reçu (joueur.recevoir_coup → secousse 0,7) ne doit pas fausser la mesure.
func _calmer(s: Node3D) -> void:
	for id in s.draugrs:
		var e = s.draugrs[id]
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED

## Somme des secousses / décalages caméra (1re et 3e personne).
func _agitation(s: Node3D) -> float:
	var j = s.joueur
	var cam: Camera3D = j.camera
	var tp: Camera3D = j.camera_tp.camera
	return j.secousse + absf(cam.h_offset) + absf(cam.v_offset) + absf(cam.rotation.z) \
		+ absf(tp.h_offset) + absf(tp.v_offset) + absf(tp.rotation.z)

func _portes_ouvertes(s: Node3D, cas: String) -> void:
	for id in ["tombe", "arene"]:
		var y: float = s.tertre.donjon.portes[id].position.y
		_verif(absf(y - 3.2) < 0.05, "%s : porte %s ouverte (y=%.3f)" % [cas, id, y])

func _tester() -> void:
	# --- A. mort du boss en jeu ---
	m = await _scene()
	await _descendre(m)
	_calmer(m)
	var t = m.tertre
	_verif(t._donjon_pret(), "A : donjon prêt")
	var y_ferme := {}
	for id in ["tombe", "arene"]:
		y_ferme[id] = t.donjon.portes[id].position.y
	_calmer(m)
	var vie0: float = m.joueur.vie
	m.joueur.secousse = 0.0
	m.quetes.signaler("tue:svanhild")
	var max_debut := 0.0
	var pire := 0.0
	for i in 600:                           # 10 s à 60 Hz
		_calmer(m)
		await physics_frame
		if i < 30:
			max_debut = maxf(max_debut, m.joueur.secousse)
		if i > 240:                         # après 4 s : tout doit être calmé (secousse 0,4 → 0 en 0,22 s ; porte 2,2 s)
			pire = maxf(pire, _agitation(m))
	print("A : secousse=%.4f agitation=%.4f pire(4-10 s)=%.6f max(0-0,5 s)=%.3f vie %.1f→%.1f" % [m.joueur.secousse, _agitation(m), pire, max_debut, vie0, m.joueur.vie])
	_verif(max_debut > 0.3, "A : une secousse à l'ouverture des portes")
	_verif(pire == 0.0, "A : plus aucune secousse ni décalage caméra 4 s après la mort du boss")
	_portes_ouvertes(m, "A")
	m.quetes.signaler("tue:svanhild")       # événement répété : pas de nouvelle ouverture (portes déjà en haut)
	await physics_frame
	_verif(m.joueur.secousse == 0.0, "A : événement répété sans effet")

	# --- C. rechargement après la mort, donjon déjà intégré, portes refermées ---
	for id in ["tombe", "arene"]:
		var p: Node3D = t.donjon.portes[id]
		p.position.y = y_ferme[id]
		p.remove_meta("en_ouverture")
	m.quetes.importer({"etat": m.quetes.etat.duplicate(), "vus": m.quetes.vus.keys(), "journal": m.quetes.journal.duplicate()})
	t.restaurer(false)
	_portes_ouvertes(m, "C (tout de suite)")
	var pire_c := 0.0
	for i in 120:
		_calmer(m)
		await physics_frame
		pire_c = maxf(pire_c, _agitation(m))
	_verif(pire_c == 0.0, "C : aucune secousse (pire=%.6f)" % pire_c)
	m.queue_free()
	for i in 3:
		await physics_frame

	# --- B. partie chargée après la mort, donjon pas encore intégré ---
	m = await _scene()
	t = m.tertre
	print("B : donjon prêt avant import = %s" % str(t.donjon != null and t._donjon_pret()))
	m.quetes.importer({"etat": {}, "vus": ["tue:svanhild", "lieu:tertre"], "journal": []})
	t.restaurer(false)
	m.joueur.secousse = 0.0
	await _descendre(m)
	_verif(t._donjon_pret(), "B : donjon prêt")
	_portes_ouvertes(m, "B")
	var pire_b := 0.0
	for i in 120:
		_calmer(m)
		await physics_frame
		pire_b = maxf(pire_b, _agitation(m))
	_verif(pire_b == 0.0, "B : aucune secousse (pire=%.6f)" % pire_b)
	_portes_ouvertes(m, "B (2 s après)")

	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
