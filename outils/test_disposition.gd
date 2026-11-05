extends SceneTree
## Disposition des PNJ (scripts/disposition.gd) et réputation légale (scripts/crime.gd) dans le vrai monde, à midi :
##   - accueil selon la réputation et la prime : neutre (rien d'ajouté), chaleureux (salut en tête), froid, refus de parler (et de
##     commercer) quand la prime est forte ; mémoire d'un coup reçu, d'une quête rendue ; sauvegarde de la mémoire ;
##   - prix du marchand (Brodd) : moins cher avec une bonne réputation, plus cher avec une mauvaise ;
##   - récidive (prime ×1,5 à réputation 0), réputation rendue en purgeant sa peine, remontée lente vers 50 ;
##   - arme brandie : rien quand elle est au repos ; un civil fait une remarque ; un garde avertit, avertit encore, puis attaque
##     (crime « menace ») ; rien pendant un combat légitime (garde hostile) ;
##   - plaider à l'arrestation : choix proposé, échec (prime majorée, dialogue rouvert sans 2e plaidoyer), réussite (prime levée).
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_disposition.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
const GARDE := 5          # mains.gd : enum { REPOS, ARMER, CHARGE, FRAPPE, RETOUR, GARDE, ENCAISSE }
var m: Node3D
var cr: Crime
var dp: Disposition
var j: CharacterBody3D
var _echecs := 0
var _brandir := false

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Attend `s` s de jeu ; le joueur est soigné, et garde sa lame levée si `_brandir` (garde imposée à chaque image, comme le clic droit).
func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		if j != null:
			j.vie = j.vie_max
			if _brandir:
				j.mains.etat = GARDE
		await physics_frame

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id:
			return v
	return null

func _devant(n: Node3D, d: float) -> void:
	var av := n.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var p := n.global_position + av * d
	p.y = m.hauteur(p.x, p.z) + 0.1
	j.global_position = p
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(-av.x, -av.z) + PI

func _salut(cle: String, palier: String) -> Array:
	return (dp.d.get(cle, {}) as Dictionary).get(palier, [])

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
	dp = cr.disposition if cr != null else null
	_verif(dp != null and Disposition.courante == dp, "Disposition branchée sous Crime (data/disposition.json lu : %d clés)" % (dp.d.size() if dp else 0))
	if dp == null:
		_fin()
		return
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.heure = 12.0
	await _attendre(1.0)
	var brodd := _pnj("forgeron")
	_verif(brodd != null, "Brodd (forgeron, marchand) trouvé")
	if brodd == null:
		_fin()
		return
	# ------------------------------------------------------------------ accueil selon réputation et prime
	var cle := cr.cle_pnj(brodd)
	cr.reputation[Crime.JURIDICTION] = 50.0
	_verif(dp.palier(brodd) == "neutre" and String(dp.accueil(brodd).get("salut", "x")) == "", "réputation 50, sans prime : neutre, aucun salut ajouté")
	cr.reputation[Crime.JURIDICTION] = 90.0
	_devant(brodd, 1.6)
	await _attendre(0.1)
	var ok_o: bool = m.dialogue.engager(brodd)
	var l0 := String(m.dialogue._lignes[0]) if ok_o and not m.dialogue._lignes.is_empty() else ""
	_verif(ok_o and _salut("salut", "chaleureux").has(l0) and m.dialogue._marchand == "forgeron",
		"réputation 90 : chaleureux, salut en tête (« %s ») et commerce ouvert" % l0)
	m.dialogue._fermer()
	await _attendre(0.2)
	cr.reputation[Crime.JURIDICTION] = 25.0
	_verif(dp.palier(brodd) == "froid", "réputation 25 : froid")
	cr.reputation[Crime.JURIDICTION] = 50.0
	cr.ajouter_prime(60.0)
	ok_o = m.dialogue.engager(brodd)
	l0 = String(m.dialogue._lignes[0]) if ok_o and not m.dialogue._lignes.is_empty() else ""
	_verif(ok_o and m.dialogue._lignes.size() == 1 and m.dialogue._options.is_empty() and m.dialogue._marchand == "",
		"prime 60 : il refuse de parler et de commercer (« %s »)" % l0)
	m.dialogue._fermer()
	cr.primes[Crime.JURIDICTION] = 0.0
	await _attendre(0.2)
	# ------------------------------------------------------------------ mémoire : coup reçu, aide, sauvegarde
	dp.noter(brodd, "coup")
	_verif(float(dp.memoire.get(cle, 0.0)) < 0.0 and dp.score(brodd) < 35.0 and dp.palier(brodd) == "froid",
		"coup reçu : il s'en souvient (mémoire %.0f, score %.0f, %s)" % [float(dp.memoire.get(cle, 0.0)), dp.score(brodd), dp.palier(brodd)])
	var ex := cr.exporter()
	dp.memoire.clear()
	cr.restaurer(JSON.parse_string(JSON.stringify(ex)))
	_verif(absf(float(dp.memoire.get(cle, 0.0)) - float((ex["disposition"] as Dictionary).get(cle, 0.0))) < 0.01, "sauvegarde : mémoire des PNJ relue")
	dp.memoire.clear()
	dp._sur_quete("anneau_givre")
	_verif(float(dp.memoire.get("pnj:chef", 0.0)) > 0.0, "quête rendue : sa donneuse (Gunnhild) s'en souvient (+%.0f)" % float(dp.memoire.get("pnj:chef", 0.0)))
	dp.memoire.clear()
	# ------------------------------------------------------------------ prix du marchand
	cr.reputation[Crime.JURIDICTION] = 50.0
	var a50 := Marchand.prix_achat("forgeron", "epee_or")
	var v50 := Marchand.prix_vente("forgeron", "epee_or")
	cr.reputation[Crime.JURIDICTION] = 100.0
	var a100 := Marchand.prix_achat("forgeron", "epee_or")
	var v100 := Marchand.prix_vente("forgeron", "epee_or")
	cr.reputation[Crime.JURIDICTION] = 0.0
	var a0 := Marchand.prix_achat("forgeron", "epee_or")
	var v0 := Marchand.prix_vente("forgeron", "epee_or")
	_verif(a100 < a50 and a50 < a0 and v100 > v50 and v50 > v0,
		"prix de l'épée d'or chez Brodd : achat %d / %d / %d, rachat %d / %d / %d (réputation 100 / 50 / 0)" % [a100, a50, a0, v100, v50, v0])
	cr.reputation[Crime.JURIDICTION] = 50.0
	_verif(absf(Disposition.mod_prix("forgeron")) < 0.001, "réputation 50 : prix de la fiche, inchangés")
	# ------------------------------------------------------------------ récidive, peine purgée, remontée vers 50
	_verif(absf(cr.facteur_recidive() - 1.0) < 0.001, "récidive : ×1 à réputation 50")
	cr.reputation[Crime.JURIDICTION] = 0.0
	cr.primes[Crime.JURIDICTION] = 0.0
	cr._commettre("vol", 10.0, [])
	_verif(cr.prime() == 15.0, "récidiviste (réputation 0) : vol de 10 → prime %.0f (×1,5)" % cr.prime())
	cr.primes[Crime.JURIDICTION] = 0.0
	cr.reputation[Crime.JURIDICTION] = 30.0
	cr.perdue[Crime.JURIDICTION] = 20.0
	cr.ajouter_prime(10.0)
	cr.aller_en_prison()
	await _attendre(0.3)
	_verif(cr.reputation_de() >= 40.0 and cr.reputation_de() < 41.5, "peine purgée : la moitié de la réputation perdue revient (30 → %.1f)" % cr.reputation_de())
	cr.reputation[Crime.JURIDICTION] = 40.0
	cr.normaliser_reputation(48.0)
	_verif(absf(cr.reputation_de() - 42.0) < 0.01, "2 jours : la réputation basse remonte vers 50 (40 → %.1f)" % cr.reputation_de())
	cr.reputation[Crime.JURIDICTION] = 80.0
	cr.normaliser_reputation(48.0)
	_verif(cr.reputation_de() == 80.0, "une bonne réputation ne s'use pas (80)")
	cr.reputation[Crime.JURIDICTION] = 50.0
	m.cycle.heure = 12.0
	await _attendre(0.5)
	# ------------------------------------------------------------------ arme brandie devant un civil
	var civil: Node3D = null
	for id in ["hab_chasseur_1", "hab_paysan_1", "hab_chasseur_2", "hab_paysan_2", "hab_paysan_3", "chasseuse", "forgeron", "ancienne"]:
		var n := _pnj(id)
		if n == null or not n.visible:
			continue
		_devant(n, 4.0)
		await _attendre(0.1)
		if cr.voit(n, j.global_position):
			civil = n
			break
	_verif(civil != null, "un civil voit le joueur à 4 m (%s)" % (civil.nom_affiche() if civil else "aucun"))
	if civil != null:
		dp.remarques = 0
		dp._remarque_t.clear()
		_brandir = false
		await _attendre(1.5)
		_verif(not dp.menace() and dp.remarques == 0, "arme au repos : personne ne dit rien")
		_brandir = true
		await _attendre(1.0)
		_verif(dp.menace() and dp.remarques >= 1, "lame levée devant %s : remarque (%d), menace %s" % [civil.nom_affiche(), dp.remarques, dp.menace()])
		_brandir = false
		await _attendre(7.0)
	# ------------------------------------------------------------------ arme brandie devant un garde
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = null
	for x in gv.gardes:
		if x.service == "poste" and String(x.donnees.get("id", "")) == "halle_o":
			g = x
	_verif(g != null, "garde de la longue maison trouvé")
	if g == null:
		_fin()
		return
	_devant(g, 5.0)
	dp.avertis.clear()
	cr.hostile[Crime.JURIDICTION] = true             # combat légitime (la garde est déjà en guerre) : aucune remontrance
	_brandir = true
	await _attendre(1.0)
	_verif(dp.avertis.is_empty(), "garde déjà hostile (combat) : pas d'avertissement pour l'arme")
	cr.hostile[Crime.JURIDICTION] = false
	_brandir = false
	await _attendre(0.5)
	_devant(g, 5.0)
	_brandir = true
	await _attendre(1.0)
	var iid := g.get_instance_id()
	_verif(dp.avertis.has(iid) and int(dp.avertis[iid]["niveau"]) == 1, "lame levée à 5 m d'un garde : « Range ton arme » (%s)" % dp.derniere_reaction)
	await _attendre(4.5)
	_verif(dp.avertis.has(iid) and int(dp.avertis[iid]["niveau"]) == 2, "on persiste : dernier avertissement (%s)" % dp.derniere_reaction)
	var p0 := cr.prime()
	await _attendre(4.5)
	var cg := cr.combattant_de(g)
	_verif(cg != null and cg.mode == "hostile" and cr.dernier.get("type") == "menace" and cr.prime() >= p0 + 14.5,
		"on persiste encore : le garde attaque (%s), crime « %s », prime %.2f" % [cg.mode if cg else "aucun", cr.dernier.get("type"), cr.prime()])
	_verif(not cr.est_hostile(), "la menace ne lève pas toute la garde (un seul garde attaque)")
	# ------------------------------------------------------------------ il propose de se rendre ; plaider : échec puis réussite
	_brandir = false
	j.inventaire.pieces = 500
	var ouvert := false
	for i in 20 * 60:
		j.vie = j.vie_max
		await physics_frame
		if j.en_dialogue and cr.arrestation != null:
			ouvert = await _jusquaux_choix()
			break
	_verif(ouvert, "arme baissée, sans frapper : le garde propose de se rendre (dialogue d'arrestation)")
	var opts: Array = m.dialogue._options
	var i_pl := -1
	for k in opts.size():
		if String(opts[k]["texte"]).begins_with("Plaider"):
			i_pl = k
	_verif(i_pl == 1, "choix : %s" % " / ".join(opts.map(func(o): return String(o["texte"]))))
	cr.reputation[Crime.JURIDICTION] = 10.0
	var pr := cr.prime()
	var ch := cr.chance_plaider()
	_verif(ch == 5.0, "réputation 10 : chance de plaider bornée à 5 %% (%.0f)" % ch)
	m.dialogue._fermer()                            # comme un choix validé : la boîte se ferme, puis l'action
	var libre := cr.plaider(50.0)
	await process_frame
	await process_frame
	_verif(not libre and absf(cr.prime() - ceilf(pr * 1.5)) < 0.01, "plaidoyer raté (jet 50) : prime %.0f → %.0f (×1,5)" % [pr, cr.prime()])
	_verif(j.en_dialogue and cr.arrestation != null and not cr.est_hostile(), "le garde reprend l'arrestation (pas une résistance)")
	await _jusquaux_choix()
	var sans := true
	for o: Dictionary in m.dialogue._options:
		sans = sans and not String(o["texte"]).begins_with("Plaider")
	_verif(sans and m.dialogue._options.size() == 3, "plus de 2e plaidoyer : %s" % " / ".join(m.dialogue._options.map(func(o): return String(o["texte"]))))
	m.dialogue._choisir(0)
	m.dialogue._valider_choix()
	await _attendre(0.5)
	_verif(cr.prime() == 0.0 and cr.combattants.is_empty(), "amende payée : prime 0, garde rendu à son poste")
	# échec bas (jet < 25) : prime doublée
	cr.ajouter_prime(20.0)
	cr.reputation[Crime.JURIDICTION] = 10.0
	await _arreter(g)
	m.dialogue._fermer()
	cr.plaider(10.0)
	await process_frame
	_verif(absf(cr.prime() - 40.0) < 0.5, "plaidoyer raté (jet 10 < 25) : prime 20 → %.0f (×2)" % cr.prime())
	await _jusquaux_choix()
	m.dialogue._choisir(0)
	m.dialogue._valider_choix()
	await _attendre(0.5)
	# réussite
	cr.ajouter_prime(20.0)
	cr.reputation[Crime.JURIDICTION] = 95.0
	var ok_a := await _arreter(g)
	ch = cr.chance_plaider()
	_verif(ok_a and ch > 80.0, "réputation 95, prime 20 : chance de plaider %.0f %%" % ch)
	j.inventaire.ajouter("coupe_argent", 1)
	cr.voles["coupe_argent"] = 1
	m.dialogue._fermer()
	libre = cr.plaider(1.0)
	await _attendre(0.5)
	_verif(libre and cr.prime() == 0.0 and cr.combattants.is_empty() and not j.en_dialogue, "plaidoyer réussi : relâché, prime levée, garde à son poste")
	_verif(j.inventaire.nombre("coupe_argent") == 1, "relâché : rien de saisi (rien n'est prouvé)")
	_fin()

## La machine à écrire du dialogue jusqu'aux choix.
func _jusquaux_choix() -> bool:
	for k in 400:
		await process_frame
		if m.dialogue._choix_vis or not m.dialogue._ouvert:
			break
		m.dialogue._suite()
	return m.dialogue._choix_vis

## Garde converti en « arrete » ; attend le dialogue d'arrestation (15 s au plus) et ses choix.
func _arreter(g: Node3D) -> bool:
	var c := cr.convertir(g, "arrete")
	if c == null:
		return false
	for i in 15 * 60:
		j.vie = j.vie_max
		await physics_frame
		if j.en_dialogue and cr.arrestation != null:
			return await _jusquaux_choix()
	return false

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
