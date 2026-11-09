extends SceneTree
## Crochetage (scripts/crochetage.gd, Crime.demander_crochetage, DemoCrime) dans le vrai monde :
##   - sans crochet : refusé ; serrure non verrouillée : ouverte d'office ;
##   - coffre verrouillé de la longue maison (Adepte) : E ouvre le mini-jeu (jeu en pause) ; crochet hors de la zone + forcer = il CASSE
##     (un crochet de moins) ; près de la zone la serrure tourne en partie ; dans la zone elle tourne à fond = ouverte (meta verrou 0,
##     signal crochetage_fini, Furtivité pratiquée) ; ensuite « Fouiller le coffre » : le contenu passe au sac, marqué VOLÉ ;
##   - difficulté : zone plus étroite et crochet plus fragile du verrou 1 au 4 ; crocheter sous les yeux d'un PNJ = intrusion (prime).
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_crochetage.gd -- --nouvelle --paisible --demo-crime
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var cr: Crime
var j: CharacterBody3D
var _echecs := 0
var _fini := []

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 30:
		await physics_frame
	cr = Crime.trouver(m)
	j = m.joueur
	m.cycle.heure = 12.0
	_verif(cr != null and cr.crochetage != null, "Crime et mini-jeu de crochetage en place")
	if cr == null:
		_fin()
		return
	cr.crochetage_fini.connect(func(c: Node3D, ok: bool) -> void: _fini.append([c, ok]))
	_verif(Inventaire.connu("crochet"), "objet « crochet » au registre (%s)" % Inventaire.objet("crochet").get("nom", "?"))
	# --- coffre de démo
	var ip: Node3D = m.village.interieur("halle")
	var coffre: Node3D = ip.find_child("coffre_gunnhild", true, false) if ip != null else null
	_verif(coffre != null and int(coffre.get_meta("verrou", 0)) == 2, "coffre verrouillé de Gunnar (Adepte) posé dans la longue maison")
	if coffre == null:
		_fin()
		return
	_verif(coffre.texte_action() == "Crocheter le coffre (Adepte)", "invite : « %s »" % coffre.texte_action())
	# --- sans crochet
	j.inventaire.objets.erase("crochet")
	var ouvre := cr.demander_crochetage(coffre)
	_verif(not ouvre and not cr.crochetage.ouvert, "sans crochet : refusé")
	# --- non verrouillé
	var libre := Node3D.new()
	m.add_child(libre)
	_verif(cr.demander_crochetage(libre) and _fini.size() == 1 and _fini[0][1], "serrure sans verrou : ouverte d'office")
	# --- mini-jeu
	j.inventaire.ajouter("crochet", 3)
	j.global_position = coffre.global_position + coffre.global_basis.z * 0.0 + Vector3(-1.0, 0.0, 0.0)
	var p0 := cr.prime()
	var lignes: Array = coffre.parler()      # touche E
	_verif(lignes.is_empty() and cr.crochetage.ouvert and paused, "E : mini-jeu ouvert, jeu en pause")
	var ck: Crochetage = cr.crochetage
	ck.set_meta("pilote", true)
	var secret := ck.angle_secret
	var faux := secret + 70.0 if secret < 0.0 else secret - 70.0
	var r1 := ck.essayer(faux, 3.0)
	_verif(r1 == "casse" and j.inventaire.nombre("crochet") == 2, "crochet loin de la zone + forcer : il casse (%s, reste %d)" % [r1, j.inventaire.nombre("crochet")])
	ck.angle = secret + ck.largeur * 0.5 + 15.0
	var partiel := ck.ouverture_max()
	_verif(partiel > 0.2 and partiel < 0.9, "près de la zone : la serrure tourne en partie (%.2f)" % partiel)
	var r2 := ck.essayer(secret, 3.0)
	_verif(r2 == "ouvert" and not ck.ouvert and not paused, "crochet dans la zone : serrure ouverte, pause levée")
	_verif(int(coffre.get_meta("verrou", 0)) == 0 and _fini.size() == 2 and _fini[1][0] == coffre and _fini[1][1], "verrou à 0, signal crochetage_fini(coffre, vrai)")
	_verif(coffre.texte_action() == "Fouiller le coffre", "invite : « %s »" % coffre.texte_action())
	_verif(j.progression.competences.experience.get("furtivite", 0.0) > 0.0 or j.progression.competence("furtivite") > 15, "Furtivité pratiquée")
	var pieces0: int = j.inventaire.pieces
	var l2: Array = coffre.parler()
	_verif(j.inventaire.pieces == pieces0 + 40 and j.inventaire.nombre("coupe_argent") >= 1, "fouillé : 40 pièces et une coupe d'argent (%s)" % str(l2))
	_verif(int(cr.voles.get("coupe_argent", 0)) == 1, "le contenu est marqué volé (confisqué à l'arrestation)")
	print("  prime avant %.0f, après %.0f (témoins : %d)" % [p0, cr.prime(), int(cr.dernier.get("temoins", 0))])
	# --- difficulté selon le verrou
	var largeurs: Array = []
	var casse_t: Array = []
	for v in range(1, 5):
		var s := Node3D.new()
		s.set_meta("verrou", v)
		m.add_child(s)
		j.inventaire.ajouter("crochet", 2)
		ck.ouvrir(s, v)
		largeurs.append(ck.largeur)
		var a := ck.angle_secret + (80.0 if ck.angle_secret < 0.0 else -80.0)
		ck.angle = a
		ck.tourne = true
		var n := 0
		while ck.casses == 0 and n < 600:
			ck.pas(1.0 / 60.0)
			n += 1
		casse_t.append(n / 60.0)
		ck.fermer("abandon")
	print("  zones : ", largeurs, " ; casse en (s) : ", casse_t)
	_verif(largeurs[0] > largeurs[1] and largeurs[1] > largeurs[2] and largeurs[2] > largeurs[3], "zone plus étroite du verrou 1 au 4")
	_verif(casse_t[0] > casse_t[1] and casse_t[1] > casse_t[2] and casse_t[2] > casse_t[3], "crochet plus fragile du verrou 1 au 4")
	# --- porte verrouillée de démo (--demo-crime)
	var porte_ip: Node3D = m.village.interieur("sigrun")
	if porte_ip != null and porte_ip.has_meta("verrou"):
		_verif(porte_ip.interactif.texte_action().begins_with("Crocheter la porte"), "porte de démo : « %s »" % porte_ip.interactif.texte_action())
	# --- crocheter sous les yeux d'un PNJ = intrusion
	var vu_par: Node3D = null
	for v in get_nodes_in_group("villageois"):
		if not ("donnees" in v) or not v.visible or v.is_in_group("gardes_village"):
			continue
		var av: Vector3 = v.global_transform.basis.z
		av.y = 0.0
		var pj: Vector3 = v.global_position + av.normalized() * 3.0
		pj.y = m.hauteur(pj.x, pj.z) + 0.1
		j.global_position = pj
		await _attendre(0.1)
		if cr.voit(v, pj):
			vu_par = v
			break
	if vu_par != null:
		var serrure := Node3D.new()
		serrure.set_meta("verrou", 1)
		serrure.set_meta("proprietaire", String(vu_par.donnees.get("id", "")))
		m.add_child(serrure)
		serrure.global_position = j.global_position
		var pr := cr.prime()
		cr.demander_crochetage(serrure)
		_verif(cr.prime() > pr and cr.dernier.get("type") == "crochetage", "crochetage vu par %s : intrusion, prime %.0f → %.0f" % [vu_par.nom_affiche(), pr, cr.prime()])
		cr.crochetage.fermer("abandon")
	else:
		_verif(false, "aucun villageois ne voit le joueur à 3 m devant lui")
	_fin()

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	paused = false
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
