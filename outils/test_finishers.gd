extends SceneTree
## Test sans fenêtre des FINISHERS alignés (scripts/combat/finishers.gd, sequence_finisher.gd) dans scenes/test_combat.tscn :
##   bash outils/tous_les_tests.sh test_finishers
## 1. Choix selon le contexte : de face → épée plantée (puis variété), dans le dos → « dos », de côté → décapitation,
##    à terre → coup plongé ; troll / mannequin → ancien finisher court.
## 2. Pour chaque finisher × chaque gabarit (draugr guerrier, draugr sbire, squelette, bandit humain) : séquence complète
##    (1,0-1,6 s), cible tuée, LAME DANS LE CORPS pendant la phase plantée (pointe dans le volume du torse ≥ 90 % des images,
##    garde toujours dehors), décapitation pour la coupe (chair), victime alignée (pieds au sol), joueur tenu en place.
## 3. Sang : jet pulsé + plaie + flaque (chair, gore complet) ; gore désactivé : ni plaie ni sang ni décapitation.
## 4. Coût CPU de l'image du contact et de la mort (préchauffé / non).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT)
		await physics_frame

func _reset() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0)
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains.combat.forcer(EtatCombat.REPOS)
	await _pas(3)

## Ennemi de draugr.gd (« guerrier », « sbire », « squelette », « bandit » = sbire à apparence humaine), sans IA.
func _ennemi(genre: String, pos: Vector3, lacet: float) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = j
	d.hud = s.hud
	d.ident = "test_fin_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 300.0
	d.vie_max = 300.0
	d.combat.profil.chance_blocage = 0.0
	return d

func _ouvrir(d: CharacterBody3D, sol: bool) -> void:
	d.vie = d.vie_max * 0.4   # équilibrage (ReglagesCombat) : finisher sur posture brisée / au sol seulement à vie ≤ 50 %
	if sol:
		d._chuter(Vector3.ZERO)
		d.combat.au_sol = true
		d.set_physics_process(true)
		await _pas(40)       # Death01 accélérée : le corps est à terre
		d.set_physics_process(false)
		d.combat.au_sol = true
	else:
		d.combat.briser_posture()
		d._etourdir()
		d.set_physics_process(false)

## Lance le finisher (clic) et le suit jusqu'au retour au repos ; renvoie {duree, nom, seq, cpu_max}.
func _jouer() -> Dictionary:
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	var r := {"entre": mains.combat.etat == EtatCombat.FINISHER, "nom": String(mains.dernier_finisher.get("nom", "")), "duree": 0.0, "cpu_max": 0.0}
	var p0 := j.global_position
	var bouge := 0.0
	var ecart_sol := 0.0
	var seq: SequenceFinisher = mains._seq
	while mains.combat.etat == EtatCombat.FINISHER and r["duree"] < 3.0:
		var t0 := Time.get_ticks_usec()
		mains.avancer(DT)
		r["cpu_max"] = maxf(float(r["cpu_max"]), (Time.get_ticks_usec() - t0) / 1000.0)
		await physics_frame
		r["duree"] += DT
		bouge = maxf(bouge, j.global_position.distance_to(p0))
	r["seq"] = seq
	r["bouge"] = bouge
	if seq != null:
		for p: Dictionary in seq._plans:
			ecart_sol = maxf(ecart_sol, float(p["ecart_sol"]))
	r["ecart_sol"] = ecart_sol
	await _pas(50)
	return r

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.mannequin.position = Vector3(30, 0, 30)

	# --- 1. choix selon le contexte
	print("-- choix")
	Finishers.dernier = ""
	Finishers.force = ""
	var d := _ennemi("guerrier", Vector3(0, 0, -1.8), 0.0)
	await _pas(5)
	await _ouvrir(d, false)
	_verif(Finishers.choisir(d, "etourdi", j) == "plantee", "de face, étourdi : épée plantée d'abord")
	Finishers.dernier = "plantee"
	_verif(Finishers.choisir(d, "etourdi", j) == "pommeau", "de face, ensuite : pommeau puis estoc (variété)")
	_verif(Finishers.choisir(d, "lateral", j) == "decapitation", "pris de côté : décapitation latérale")
	_verif(Finishers.choisir(d, "sol", j) == "plonge", "à terre : coup plongé")
	d.rotation.y = PI
	_verif(Finishers.choisir(d, "etourdi", j) == "dos", "dans son dos : épée plantée dans le dos")
	await _reset()
	_verif(not mains._chercher_finisher().is_empty(), "dans le dos d'un ennemi étourdi : finisher proposé")
	_verif(Finishers.choisir(s.mannequin, "etourdi", j) == "", "mannequin (sans squelette) : ancien finisher court")
	d.queue_free()
	await _pas(2)

	# --- 2. chaque finisher × chaque gabarit
	var cas := [["plantee", false, 0.0], ["dos", false, PI], ["pommeau", false, 0.0], ["decapitation", false, 0.0], ["plonge", true, 0.0]]
	var genres := ["guerrier", "sbire", "squelette", "bandit"]
	var cpu_premier := -1.0
	for g: String in genres:
		for c: Array in cas:
			var nom: String = c[0]
			print("-- %s / %s" % [nom, g])
			Finishers.force = nom
			await _reset()
			var e := _ennemi(g, Vector3(0.15, 0, -1.7), c[2])
			await _pas(5)
			await _ouvrir(e, c[1])
			var mod: Node3D = e.modele
			var r := await _jouer()
			if cpu_premier < 0.0:
				cpu_premier = float(r["cpu_max"])
			var seq: SequenceFinisher = r["seq"]
			_verif(r["entre"] and r["nom"] == nom, "%s/%s : séquence « %s » lancée" % [nom, g, r["nom"]])
			_verif(float(r["duree"]) >= 0.3 and float(r["duree"]) <= 1.6, "%s/%s : geste jusqu'au suivi en %.2f s" % [nom, g, r["duree"]])
			_verif(not e.vivant() and mains.dernier_finisher.get("resultat") == "tue", "%s/%s : cible tuée" % [nom, g])
			_verif(float(r["bouge"]) < 0.01, "%s/%s : joueur tenu en place (%.3f m)" % [nom, g, r["bouge"]])
			_verif(float(r["ecart_sol"]) < 0.06, "%s/%s : victime alignée les pieds au sol (écart %.3f m)" % [nom, g, r["ecart_sol"]])
			if seq != null and nom != "decapitation":
				var me: Dictionary = seq.mesure
				var n := int(me["images"])
				_verif(n >= 10 and int(me["dedans"]) >= int(n * 0.9), "%s/%s : pointe DANS le torse %d/%d images (dist. max à l'axe %.3f m, rayon %.2f)" % [nom, g, me["dedans"], n, me["dist_max"], me["rayon"]])
				_verif(int(me["garde_dehors"]) == n, "%s/%s : garde hors du corps %d/%d" % [nom, g, me["garde_dehors"], n])
				if g != "squelette":
					_verif(Plaies.nombre(mod) >= 1, "%s/%s : plaie persistante (%d)" % [nom, g, Plaies.nombre(mod)])
			if nom == "decapitation" and g != "squelette":
				_verif(mod.has_meta("decapite"), "%s/%s : décapité" % [nom, g])
			e.queue_free()
			await _pas(2)
	print("   coût CPU de l'image la plus chère, 1er finisher : %.1f ms" % cpu_premier)

	# --- 3. gore désactivé
	print("-- gore désactivé")
	Sang.niveau_force = 0
	for nom in ["plantee", "decapitation"]:
		Finishers.force = nom
		await _reset()
		var e := _ennemi("sbire", Vector3(0, 0, -1.7), 0.0)
		await _pas(5)
		await _ouvrir(e, false)
		var mod: Node3D = e.modele
		var r := await _jouer()
		_verif(r["nom"] == nom and not e.vivant() and Plaies.nombre(mod) == 0 and not mod.has_meta("decapite"), "gore 0, %s : achevé sans plaie ni décapitation" % nom)
		e.queue_free()
		await _pas(2)
	Sang.niveau_force = 2
	Finishers.force = ""

	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
