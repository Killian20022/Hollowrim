extends SceneTree
## Crime et justice (scripts/crime.gd, scripts/pnj_combat.gd) dans le vrai monde, à midi :
##   - vol VU devant son propriétaire (un chasseur ou un paysan dehors) : prime, il attaque (PnjCombat hostile) ; vol NON VU : rien ;
##   - de nuit sans torche, un PNJ à 15 m ne voit plus le joueur ; de jour, si ; dans son dos, non ;
##   - un coup isolé sur un garde = avertissement ; le 2e = agression : TOUS les gardes (hors vigie) deviennent hostiles, ceux de loin
##     prévenus en retard, et ils accourent vers le joueur ;
##   - arrestation : un garde vient au contact, le dialogue propose amende / geôle / résister ; amende (pièces, objets volés saisis,
##     gardes rendus à leur service) ; plaider (choix présent : test_disposition) ; geôle (heures qui passent, XP en baisse, prime effacée) ; résister (garde hostile) ;
##   - la prime baisse avec les heures de jeu, puis s'éteint (la garde oublie) ; meurtre vu : prime de 1000, PNJ noté mort ;
##   - sauvegarde « crime » : exporter / restaurer.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_crime.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var cr: Crime
var j: CharacterBody3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Attend `s` s de jeu ; le joueur est soigné à chaque image (une garde entière le tuerait : réapparition au feu de camp).
func _attendre(s: float) -> void:
	for i in int(s * 60.0):
		if j != null:
			j.vie = j.vie_max
		await physics_frame

func _pnj(id: String) -> Node3D:
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == id:
			return v
	return null

## Place le joueur à `d` m devant `n` (dans son regard), face à lui.
func _devant(n: Node3D, d: float) -> void:
	var av := n.global_transform.basis.z
	av.y = 0.0
	av = av.normalized()
	var p := n.global_position + av * d
	p.y = m.hauteur(p.x, p.z) + 0.1
	j.global_position = p
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(-av.x, -av.z) + PI

func _reset() -> void:
	cr._gracier()
	cr.voles.clear()
	cr._avert.clear()
	cr._agresses.clear()
	await _attendre(0.5)

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
	_verif(cr != null, "nœud Crime branché dans le monde (groupe « crime »)")
	if cr == null:
		_fin()
		return
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.heure = 12.0
	await _attendre(2.0)
	# ------------------------------------------------------------------ témoins : jour, nuit, dos
	# un costaud dehors (chasseur, paysan) qui a la vue dégagée devant lui à 12 m
	var brodd: Node3D = null
	for id in ["hab_chasseur_1", "hab_paysan_1", "hab_chasseur_2", "hab_paysan_2", "hab_paysan_3", "chasseuse", "forgeron"]:
		var n := _pnj(id)
		if n == null or not n.visible:
			continue
		_devant(n, 12.0)
		await _attendre(0.1)
		if cr.voit(n, j.global_position):
			brodd = n
			break
		print("  %s : regard bloqué par %s" % [id, cr.derniere_vue_bloquee.get_path() if cr.derniere_vue_bloquee else "?"])
	_verif(brodd != null, "de jour, un villageois costaud (%s) voit le joueur à 12 m devant lui" % (brodd.nom_affiche() if brodd else "aucun"))
	if brodd == null:
		_fin()
		return
	var derriere := brodd.global_position - brodd.global_transform.basis.z * 6.0
	derriere.y = m.hauteur(derriere.x, derriere.z)
	_verif(not cr.voit(brodd, derriere), "dans son dos à 6 m : il ne voit pas")
	m.cycle.heure = 23.5
	j.mains.torche_sortie = false
	await _attendre(0.2)
	_verif(not cr.voit(brodd, j.global_position), "de nuit sans torche : à 12 m il ne voit plus (portée %.1f m)" % cr.portee_vue())
	j.mains.torche_sortie = true
	await _attendre(0.2)
	_verif(cr.portee_vue() > 15.0, "de nuit, torche allumée : on le voit de loin (portée %.1f m)" % cr.portee_vue())
	j.mains.torche_sortie = false
	m.cycle.heure = 12.0
	await _attendre(1.0)
	# ------------------------------------------------------------------ vol vu devant le propriétaire
	_devant(brodd, 3.0)
	await _attendre(0.1)
	var obj := Node3D.new()
	obj.set_meta("id_objet", "coupe_argent")
	m.add_child(obj)
	obj.global_position = j.global_position
	var id_b := String(brodd.donnees.get("id", ""))
	var vu := cr.signaler_vol(obj, id_b, obj.global_position)
	_verif(vu, "vol devant %s : vu (%d témoins)" % [brodd.nom_affiche(), int(cr.dernier.get("temoins", 0))])
	_verif(cr.prime() >= 17.0, "prime de vol : %.0f pièces (coupe d'argent 35 → 18)" % cr.prime())
	_verif(int(cr.voles.get("coupe_argent", 0)) == 1, "objet marqué volé")
	var cb := cr.combattant_de(brodd)
	_verif(cb != null and cb.mode == "hostile", "le propriétaire, volé sous ses yeux, attaque (PnjCombat %s)" % (cb.mode if cb else "aucun"))
	_verif(not brodd.visible and brodd.remplace != null, "le PNJ d'origine dort pendant le combat (corps pris par le combattant)")
	await _attendre(3.0)
	_verif(cb != null and is_instance_valid(cb) and cb.attaques > 0, "le propriétaire a frappé le joueur (%d coups)" % (cb.attaques if cb and is_instance_valid(cb) else 0))
	await _reset()
	_verif(cr.combattants.is_empty() and brodd.visible and brodd.remplace == null, "amende effacée : le propriétaire reprend son corps et sa vie")
	# ------------------------------------------------------------------ vol non vu
	var loin := _coin_desert()
	j.global_position = loin
	await _attendre(0.3)
	var p0 := cr.prime()
	var vu2 := cr.signaler_vol(obj, id_b, loin)
	_verif(not vu2 and cr.prime() == p0, "vol sans témoin (%.0f ; %.0f) : rien de détecté, prime %.0f" % [loin.x, loin.z, cr.prime()])
	_verif(cr.combattants.is_empty(), "vol non vu : personne ne réagit")
	await _reset()
	# ------------------------------------------------------------------ avertissement puis agression d'un garde
	var gv: Node = m.get_node("GardesVillage")
	var g: Node3D = null
	for x in gv.gardes:
		if x.service == "poste" and String(x.donnees.get("id", "")) == "halle_o":
			g = x
	_verif(g != null, "garde de la longue maison trouvé")
	_devant(g, 2.0)
	await _attendre(0.2)
	var r1 := String(g.recevoir_coup(12.0, j.global_position, false, {}))
	_verif(r1 == "bloque" and cr.dernier.get("type") == "avertissement" and cr.combattant_de(g) == null,
		"1er coup sur un garde : avertissement, pas d'agression (prime %.0f)" % cr.prime())
	var nb_gardes := 0
	var d_avant := 0.0
	for x: Node3D in cr.gardes():
		if x.get("service") != "vigie":
			nb_gardes += 1
			d_avant += x.global_position.distance_to(j.global_position)
	var r2 := String(g.recevoir_coup(12.0, j.global_position, false, {}))
	_verif(r2 == "touche" or r2 == "bloque", "2e coup : il porte (%s)" % r2)
	_verif(cr.est_hostile() and cr.prime() >= 40.0, "agression d'un garde : garde hostile, prime %.0f" % cr.prime())
	var tout_de_suite := _hostiles()
	_verif(tout_de_suite >= 1 and tout_de_suite < nb_gardes, "alerte : %d gardes hostiles tout de suite (portée de voix), %d prévenus plus tard" % [tout_de_suite, nb_gardes - tout_de_suite])
	await _attendre(8.0)
	var h := _hostiles()
	_verif(h >= nb_gardes, "8 s plus tard : TOUS les gardes hostiles (%d / %d)" % [h, nb_gardes])
	var d_apres := 0.0
	for c: PnjCombat in cr.combattants:
		if c.est_garde:
			d_apres += c.global_position.distance_to(j.global_position)
	_verif(d_apres < d_avant * 0.8, "ils accourent : distance totale au joueur %.0f m → %.0f m" % [d_avant, d_apres])
	var coups := 0
	for c: PnjCombat in cr.combattants:
		coups += c.attaques
	_verif(coups > 0, "les gardes frappent le joueur (%d coups)" % coups)
	_verif(not j.mort, "le joueur (soigné par le test) est toujours debout")
	await _reset()
	_verif(cr.combattants.is_empty() and not cr.est_hostile(), "gracié : tous les gardes rendus à leur service")
	await _attendre(1.0)
	# ------------------------------------------------------------------ arrestation : amende (sur la place, terrain dégagé)
	var place: Vector3 = m.village.lieux["place"]
	j.global_position = Vector3(place.x, m.hauteur(place.x, place.z) + 0.1, place.z)
	g.global_position = Vector3(place.x + 6.0, m.hauteur(place.x + 6.0, place.z) + 0.1, place.z)
	cr.ajouter_prime(50.0)
	j.inventaire.pieces = 120
	j.inventaire.ajouter("coupe_argent", 1)
	cr.voles["coupe_argent"] = 1
	var ok_d := await _arreter(g)
	_verif(ok_d, "un garde vient au contact et ouvre le dialogue d'arrestation")
	var opts: Array = m.dialogue._options
	_verif(opts.size() == 4 and String(opts[0]["texte"]).begins_with("Payer") and String(opts[1]["texte"]).begins_with("Plaider"), "choix : %s" % " / ".join(opts.map(func(o): return String(o["texte"]))))
	await _choisir(0)
	_verif(cr.prime() == 0.0 and j.inventaire.pieces == 70, "amende payée : prime 0, 120 → %d pièces" % j.inventaire.pieces)
	_verif(j.inventaire.nombre("coupe_argent") == 0, "objet volé confisqué")
	await _attendre(0.5)
	_verif(cr.combattants.is_empty() and g.visible and g.remplace == null, "le garde reprend son service")
	# ------------------------------------------------------------------ arrestation : geôle
	cr.primes[Crime.JURIDICTION] = 0.0
	cr.ajouter_prime(300.0)
	j.global_position = Vector3(place.x, m.hauteur(place.x, place.z) + 0.1, place.z)
	g.global_position = Vector3(place.x + 6.0, m.hauteur(place.x + 6.0, place.z) + 0.1, place.z)
	var xp0: float = j.progression.xp_niveau
	j.progression.xp_niveau = 80.0
	ok_d = await _arreter(g)
	var h0: float = m.cycle.heure
	_verif(ok_d, "arrestation (prime 300) : dialogue ouvert")
	await _choisir(2)   # Payer / Plaider / Geôle / Résister
	var ecart := fposmod(float(m.cycle.heure) - h0, 24.0)
	_verif(cr.prime() == 0.0 and absf(ecart - fposmod(84.0, 24.0)) < 0.5, "geôle (prime 300) : prime effacée, 12 + 72 = 84 h passent (heure %.1f → %.1f)" % [h0, m.cycle.heure])
	_verif(j.progression.xp_niveau < 80.0, "geôle : XP en baisse (80 → %.0f)" % j.progression.xp_niveau)
	_verif(j.global_position.distance_to(cr.sortie_geole()) < 1.0, "sortie de geôle devant la longue maison")
	j.progression.xp_niveau = xp0
	m.cycle.heure = 12.0
	await _attendre(1.0)
	# ------------------------------------------------------------------ arrestation : résister
	cr.ajouter_prime(20.0)
	j.global_position = Vector3(place.x, m.hauteur(place.x, place.z) + 0.1, place.z)
	g.global_position = Vector3(place.x + 6.0, m.hauteur(place.x + 6.0, place.z) + 0.1, place.z)
	ok_d = await _arreter(g)
	await _choisir(3)
	await _attendre(0.5)
	_verif(ok_d and cr.est_hostile() and _hostiles() >= 1, "résister : garde hostile (%d gardes armés)" % _hostiles())
	await _reset()
	# ------------------------------------------------------------------ la prime baisse avec le temps
	cr.ajouter_prime(100.0)
	m.cycle.heure = 12.0
	await _attendre(0.2)
	m.cycle.heure = 22.0
	await _attendre(0.2)
	var attendu := 100.0 * pow(0.96, 10.0)
	_verif(absf(cr.prime() - attendu) < 2.0, "10 h de jeu : prime 100 → %.1f (attendu %.1f)" % [cr.prime(), attendu])
	cr.hostile[Crime.JURIDICTION] = true
	for k in 6:
		m.cycle.heure = fposmod(float(m.cycle.heure) + 20.0, 24.0)
		await _attendre(0.1)
	_verif(cr.prime() == 0.0 and not cr.est_hostile(), "après 5 jours : prime éteinte, la garde oublie")
	m.cycle.heure = 12.0
	await _reset()
	# ------------------------------------------------------------------ civil : avertissement, puis il fuit ou se défend ; meurtre vu
	var ylva := _pnj("chasseuse")
	var grima := _pnj("ancienne")
	var cible: Node3D = grima if grima != null and grima.visible else ylva
	if cible != null:
		_devant(cible, 1.8)
		await _attendre(0.2)
		var ra := String(cible.recevoir_coup(10.0, j.global_position, false, {}))
		_verif(ra == "touche" and cr.dernier.get("type") == "avertissement", "civil frappé une fois : avertissement")
		cible.recevoir_coup(10.0, j.global_position, false, {})
		var cc := cr.combattant_de(cible)
		_verif(cc != null, "civil frappé deux fois : %s (%s)" % [cc.mode if cc else "?", cible.nom_affiche()])
		if cc != null:
			var cle := cr.cle_pnj(cible)
			var rm := String(cc.recevoir_coup(cc.vie + 50.0, j.global_position, true, {"attaque": "lourde"}))
			await _attendre(0.5)
			_verif(rm == "tue" and cr.morts.has(cle), "civil tué : noté mort (%s, %s)" % [rm, str(cr.morts)])
			_verif(not is_instance_valid(cible) or cible.is_queued_for_deletion(), "le PNJ d'origine disparaît avec lui")
			print("  dernier crime : ", cr.dernier)
	# ------------------------------------------------------------------ sauvegarde
	cr.ajouter_prime(33.0)
	cr.voles["collier_or"] = 2
	var ex := cr.exporter()
	var txt := JSON.stringify(ex)
	cr.primes.clear()
	cr.voles.clear()
	cr.restaurer(JSON.parse_string(txt))
	_verif(absf(cr.prime() - (ex["primes"] as Dictionary).get(Crime.JURIDICTION, 0.0)) < 0.01 and int(cr.voles.get("collier_or", 0)) == 2,
		"sauvegarde « crime » : prime %.0f et objets volés relus" % cr.prime())
	_fin()

## Garde converti en « arrete » ; attend que le dialogue d'arrestation s'ouvre (15 s au plus).
func _arreter(g: Node3D) -> bool:
	var c := cr.convertir(g, "arrete")
	if c == null:
		print("  conversion impossible : ", g.name, " remplace=", g.get("remplace"), " dans l'arbre=", g.is_inside_tree())
	for i in 15 * 60:
		j.vie = j.vie_max
		if i == 15 * 60 - 1 and is_instance_valid(c):
			print("  arrestation ratée : dist %.1f mode %s propose %s en_dialogue %s ouvert %s arrestation %s prime %.0f" % [
				c.global_position.distance_to(j.global_position) if is_instance_valid(c) else -1.0, c.mode if is_instance_valid(c) else "?",
				c._propose if is_instance_valid(c) else false, j.en_dialogue, m.dialogue._ouvert, cr.arrestation, cr.prime()])
		await physics_frame
		if j.en_dialogue and cr.arrestation != null:
			# la machine à écrire : jusqu'aux choix
			for k in 400:
				await process_frame
				if m.dialogue._choix_vis or not m.dialogue._ouvert:
					break
				m.dialogue._suite()
			if not m.dialogue._choix_vis:
				print("  dialogue sans choix : ouvert %s, ligne %d/%d, options %d, pnj %s, arrestation %s" % [m.dialogue._ouvert, m.dialogue._index,
					m.dialogue._lignes.size(), m.dialogue._options.size(), m.dialogue._pnj, cr.arrestation])
			return m.dialogue._choix_vis
	return false

func _choisir(i: int) -> void:
	m.dialogue._choisir(i)
	m.dialogue._valider_choix()
	await process_frame
	await process_frame

func _hostiles() -> int:
	var n := 0
	for c: PnjCombat in cr.combattants:
		if is_instance_valid(c) and c.est_garde and c.mode == "hostile" and not c.est_mort:
			n += 1
	return n

## Un point du terrain loin de tout PNJ (au moins 30 m).
func _coin_desert() -> Vector3:
	for k in 60:
		var a := TAU * k / 60.0
		var p := Vector3(44.0 + cos(a) * 95.0, 0.0, 40.0 + sin(a) * 95.0)
		p.y = m.hauteur(p.x, p.z) + 0.1
		var ok := true
		for n: Node3D in cr.pnj_actifs():
			if n.global_position.distance_to(p) < 30.0:
				ok = false
				break
		if ok:
			return p
	return Vector3(44.0, m.hauteur(44.0, 160.0) + 0.1, 160.0)

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
