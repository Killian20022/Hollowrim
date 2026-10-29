extends SceneTree
## Test headless : mort du joueur dans la crypte. La crypte revient à un état cohérent avec la sauvegarde : gardiens tués
## absents seulement s'ils sont dans la sauvegarde, les autres réapparaissent ; coffre ouvert = contenu déjà versé au sac (L2 :
## plus de bourse à ramasser), il reste ouvert et ne se rouvre pas (pas de double) ;
## portes ouvertes conservées (événements de quête) ; joueur dehors, crypte cachée. Aucun fichier de sauvegarde n'est touché
## (liste des morts sauvegardés imposée). godot --headless --path . --script outils/test_crypte_mort.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _vivants_cr() -> Array:
	var r := []
	for id: String in m.draugrs:
		if id.begins_with("cr_") and is_instance_valid(m.draugrs[id]):
			r.append(id)
	return r

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	var t = m.tertre
	t.attendre_donjon()
	for i in 3:
		await physics_frame
	var c: Node3D = t.crypte
	# on entre dans la crypte (sans le fondu), devant l'ossuaire
	t.dedans = true
	c.visible = true
	var etats := []
	t.entree.connect(func(d: bool) -> void: etats.append(d))
	m.joueur.global_position = c.to_global(Vector3(-21, 0.1, -12))
	for i in 4:
		t._gerer_zones()
		await physics_frame
	var ids: Array = _vivants_cr()
	print("gardiens apparus : ", ids)
	_verif(ids.size() >= 2, "des gardiens de la crypte sont apparus (%d)" % ids.size())
	var a: String = ids[0]
	var b: String = ids[1]
	# deux gardiens tués ; seul `a` est dans la sauvegarde
	for id in [a, b]:
		m.draugrs[id]._mourir()
	_verif(not m.draugrs[a].vivant() and not m.draugrs[b].vivant(), "deux gardiens tués")
	# coffre ouvert (L2 : pièces versées tout de suite, gerbe en vol) ; porte S1 ouverte
	var or0: int = m.joueur.inventaire.pieces
	t._ouvrir_coffre("cof_ossuaire", {"pieces": 34}, Vector3(-28.2, 0, -24.7))
	t._ouvrir_porte("s1")
	var n_gerbe := 0
	for n in c.get_children():
		if n.get_script() == preload("res://scripts/butin.gd"):
			n_gerbe += 1
	_verif(n_gerbe == 1 and t.quetes.vus.has("crypte:cof_ossuaire") and m.joueur.inventaire.pieces == or0 + 34, "coffre ouvert : +34 pièces versées, gerbe de pièces en vol")
	m.joueur.mort = true
	t.reinitialiser([a])
	for i in 3:
		await physics_frame
	_verif(not t.dedans and not c.visible, "crypte cachée, joueur dehors (dedans = false)")
	_verif(etats == [false], "signal d'entrée émis une fois avec « dehors »")
	_verif(not m.draugrs.has(a) and t.morts_charges.has(a), "gardien sauvegardé comme tué : reste mort")
	_verif(not m.draugrs.has(b) and not t.morts_charges.has(b), "gardien tué non sauvegardé : retiré, à refaire")
	_verif(t.quetes.vus.has("crypte:cof_ossuaire") and m.joueur.inventaire.pieces == or0 + 34, "mort : le coffre ouvert reste ouvert, pièces gardées (rien à reperdre, pas de double)")
	var reste := 0
	for n in c.get_children():
		if n.has_meta("coffre") and not n.is_queued_for_deletion():
			reste += 1
	_verif(reste == 0, "aucune bourse flottante dans la crypte")
	_verif(t.quetes.vus.has("crypte:s1") and absf((t.donjon.portes["s1"] as Node3D).position.y - 3.2) < 0.05, "porte S1 toujours ouverte (événement de quête acquis)")
	# retour dans la crypte : le gardien non sauvegardé réapparaît vivant, l'autre non
	t.dedans = true
	c.visible = true
	m.joueur.global_position = c.to_global(Vector3(-21, 0.1, -12))
	for i in 4:
		t._gerer_zones()
		await physics_frame
	_verif(m.draugrs.has(b) and m.draugrs[b].vivant(), "gardien non sauvegardé réapparu vivant")
	_verif(not m.draugrs.has(a), "gardien sauvegardé comme tué : toujours absent")
	# les gardiens de la partie d'origine (couloir des niches, salle de préparation, salle rituelle) sont réinitialisés comme les autres (bug corrigé)
	t.dedans = true
	c.visible = true
	m.joueur.global_position = c.to_global(Vector3(0, 0.1, -20))
	for i in 12:
		t._gerer_zones()
		await physics_frame
	var orig := ["cr_niches_2", "cr_prep_1", "cr_prep_2", "cr_prep_3", "cr_rituelle_1"]   # (cr_niches_1 est « tué et sauvegardé » plus haut)
	var tous := true
	for id in orig:
		tous = tous and m.draugrs.has(id) and is_instance_valid(m.draugrs[id])
	_verif(tous, "les gardiens de la partie d'origine passent par la file d'apparition du donjon (identifiants fixes)")
	m.draugrs["cr_niches_2"]._mourir()
	m.draugrs["cr_prep_2"]._mourir()
	m.joueur.mort = true
	t.reinitialiser([])
	for i in 3:
		await physics_frame
	_verif(not m.draugrs.has("cr_niches_2") and not m.draugrs.has("cr_prep_2") and not m.draugrs.has("cr_prep_1"), "mort du joueur : gardiens d'origine retirés (tués ou non), à refaire")
	t.dedans = true
	c.visible = true
	m.joueur.mort = false
	m.joueur.global_position = c.to_global(Vector3(0, 0.1, -20))
	for i in 12:
		t._gerer_zones()
		await physics_frame
	_verif(m.draugrs.has("cr_niches_2") and m.draugrs["cr_niches_2"].vivant() and m.draugrs.has("cr_prep_2") and m.draugrs["cr_prep_2"].vivant(), "gardiens d'origine réapparus vivants (non sauvegardés comme tués)")
	# chemin complet : la mort passe par le monde (fondu, puis réinitialisation, puis résurrection)
	m.joueur.mort = true
	m._joueur_mort()
	await create_timer(5.0).timeout
	_verif(not t.dedans and not c.visible and not m.joueur.mort, "mort via le monde : crypte réinitialisée, joueur ressuscité dehors")
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)
