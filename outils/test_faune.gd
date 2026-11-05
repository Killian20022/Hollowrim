extends SceneTree
## Test sans fenêtre de la faune vivante (scripts/faune.gd, data/vie/faune.json) :
##   godot --headless --path . -s res://outils/test_faune.gd -- --nouvelle --test
## A. fonctions pures : plages d'heures, phases des domestiques, territoires (biomes respectés, déterminisme, graine dédiée) ;
## B. nœud Faune dans scenes/test_troll_mage.tscn : apparition par heure (loups la nuit, cerfs à l'aube), plafond, distance, hors de
##    vue, repeuplement après une mort, sauvegarde ; C. domestiques : place de jour, enclos le soir, sommeil, réveil, husky suiveur.

const SCENE := preload("res://scenes/test_troll_mage.tscn")
const BETE := preload("res://scripts/bete_quat.gd")

class CycleBidon extends RefCounted:
	var heure := 12.0

var _ok := 0
var _ko := 0
var sc: Node3D
var j: CharacterBody3D
var cyc := CycleBidon.new()

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## Biomes synthétiques : quadrillage de 24 m tiré par ZoneBiome.alea_pos (aucune dépendance au monde réel).
func _biome(x: float, z: float) -> String:
	var u := ZoneBiome.alea_pos(floorf(x / 24.0), floorf(z / 24.0), 5)
	return "foret" if u < 0.4 else ("clairiere" if u < 0.7 else ("plaine_neige" if u < 0.9 else "abords_village"))

func _tester() -> void:
	RetourImpact.muet = true
	var f := Faune.charger_fiche()
	_verif(not f.is_empty() and f["domestiques"]["liste"].size() == 7, "fiche data/vie/faune.json lue (7 domestiques)")

	# --- A. heures
	_verif(Faune.poids_heure("nuit+", 23.0) == 1.0 and Faune.poids_heure("nuit+", 19.5) == 1.0 and Faune.poids_heure("nuit+", 12.0) == 0.2, "loup « nuit+ » : plein à 23 h et 19 h 30, 0,2 à midi")
	_verif(Faune.poids_heure("aube+crepuscule", 6.0) == 1.0 and Faune.poids_heure("aube+crepuscule", 18.0) == 1.0 and Faune.poids_heure("aube+crepuscule", 12.0) == 0.2 and Faune.poids_heure("aube+crepuscule", 23.0) == 0.2, "cerf : aube et crépuscule seulement")
	_verif(Faune.poids_heure("toujours", 3.0) == 1.0, "« toujours » : 1")
	_verif(Faune.phase_domestique(12.0, f["domestiques"]) == "jour" and Faune.phase_domestique(20.0, f["domestiques"]) == "soir" and Faune.phase_domestique(23.0, f["domestiques"]) == "nuit"
		and Faune.phase_domestique(3.0, f["domestiques"]) == "nuit" and Faune.phase_domestique(6.5, f["domestiques"]) == "aube", "phases : 12 h jour, 20 h soir, 23 h et 3 h nuit, 6 h 30 aube")

	# --- A. territoires
	var biome := Callable(self, "_biome")
	var tout := func(_x: float, _z: float) -> bool: return true
	var t1 := Faune.generer_territoires(f, biome, tout)
	var t2 := Faune.generer_territoires(f, biome, tout)
	_verif(t1.size() >= 30 and JSON.stringify(t1) == JSON.stringify(t2), "territoires : %d, identiques à chaque génération (graine ZoneBiome.graine(\"faune\"))" % t1.size())
	var f2 := f.duplicate(true)
	f2["graine"] = "autre"
	_verif(JSON.stringify(Faune.generer_territoires(f2, biome, tout)) != JSON.stringify(t1), "une autre graine donne d'autres territoires")
	var n_rng := RandomNumberGenerator.new()
	n_rng.seed = 99
	var avant := n_rng.randi()
	n_rng.seed = 99
	Faune.generer_territoires(f, biome, tout)
	_verif(n_rng.randi() == avant, "le tirage n'utilise aucun RNG partagé")
	var bons := true
	var bad := ""
	var especes := {}
	var tous_dehors := true
	for t: Dictionary in t1:
		var fi: Dictionary = BeteQuat.ESPECES[t["espece"]]
		especes[t["espece"]] = int(especes.get(t["espece"], 0)) + 1
		if not (t["biome"] in fi["biomes"]) or bool(fi.get("domestique", false)):
			bons = false
			bad = "%s en %s" % [t["espece"], t["biome"]]
		if t["groupe"] < fi["groupe"][0] or t["groupe"] > fi["groupe"][1]:
			bons = false
			bad = "groupe " + t["espece"]
		for i: Dictionary in f["interdits"]:
			if Vector2(t["x"] - i["x"], t["z"] - i["z"]).length() < i["r"]:
				tous_dehors = false
	_verif(bons, "chaque territoire respecte les biomes et la taille de groupe de l'espèce %s" % bad)
	_verif(tous_dehors and not especes.has("araignee"), "aucun territoire dans les zones interdites ; l'araignée (grotte) n'est jamais tirée en surface")
	_verif(especes.size() >= 3, "au moins trois espèces réparties : %s" % str(especes))
	var loups_nuit := 0
	var loups_jour := 0
	var cerfs_aube := 0
	var cerfs_midi := 0
	for t: Dictionary in t1:
		var hh: String = BeteQuat.ESPECES[t["espece"]]["heures"]
		if t["espece"] == "loup":
			loups_nuit += 1 if float(t["u"]) < Faune.poids_heure(hh, 23.0, 0.2) else 0
			loups_jour += 1 if float(t["u"]) < Faune.poids_heure(hh, 12.0, 0.2) else 0
		elif t["espece"] in ["cerf", "biche"]:
			cerfs_aube += 1 if float(t["u"]) < Faune.poids_heure(hh, 6.0, 0.2) else 0
			cerfs_midi += 1 if float(t["u"]) < Faune.poids_heure(hh, 12.0, 0.2) else 0
	_verif(loups_nuit > loups_jour, "loups de service : %d à 23 h > %d à midi" % [loups_nuit, loups_jour])
	_verif(cerfs_aube > cerfs_midi, "cerfs et biches de service : %d à 6 h > %d à midi" % [cerfs_aube, cerfs_midi])

	# --- B. nœud Faune
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 1, 600)
	cs.shape = bs
	sol.add_child(cs)
	sol.position = Vector3(0, -0.5, 0)
	sc.add_child(sol)
	j = sc.joueur
	j.global_position = Vector3(0, 0, 0)
	cyc.heure = 22.0
	var fa := Faune.new()
	fa.joueur = j
	fa.cycle = cyc
	fa.registre = sc.draugrs
	fa.hauteur_de = func(_x: float, _z: float) -> float: return 0.0
	fa.biome_de = biome
	fa.accepte = tout
	fa.fabrique = func(espece: String, pos: Vector3, lacet: float, options: Dictionary) -> Node:
		var b: CharacterBody3D = sc.creer_ennemi(BETE, pos, options)
		b.rotation.y = lacet
		return b
	sc.add_child(fa)
	fa.demarrer()
	fa.set_process(false)
	var pl: Dictionary = f["plafonds"]
	var dmin: float = f["apparition"]["dist_min"]
	var max_n := 0
	var trop_pres := false
	var idents_uniques := true
	for k in 40:
		fa._t_spawn = 99.0
		fa._tour()
		max_n = maxi(max_n, fa._nb())
		for slot: int in fa.actifs:
			for b in fa.actifs[slot]:
				if Vector2(b.global_position.x - j.global_position.x, b.global_position.z - j.global_position.z).length() < dmin - 8.0:
					trop_pres = true
	var seen := {}
	for slot: int in fa.actifs:
		for b in fa.actifs[slot]:
			if seen.has(b.ident):
				idents_uniques = false
			seen[b.ident] = true
	_verif(fa._nb() > 0, "22 h : des bêtes sont apparues (%d, espèces %s)" % [fa._nb(), str(_comptes(fa))])
	_verif(max_n <= int(pl["total"]), "plafond total respecté (max %d ≤ %d)" % [max_n, int(pl["total"])])
	for e in _comptes(fa):
		_verif(_comptes(fa)[e] <= int(pl.get(e, 99)), "plafond %s : %d ≤ %d" % [e, _comptes(fa)[e], int(pl.get(e, 99))])
	_verif(not trop_pres and idents_uniques, "aucune bête à moins de %d m du joueur à l'apparition ; idents uniques" % int(dmin - 8.0))
	var nuit_loups: int = _comptes(fa).get("loup", 0)
	var nuit_gibier: int = _comptes(fa).get("cerf", 0) + _comptes(fa).get("biche", 0)
	# l'aube : les loups repartent (hors de vue), le gibier arrive
	cyc.heure = 12.0
	for k in 40:
		fa._t_spawn = 99.0
		fa._tour()
		await _frames(2)
	var midi_loups: int = _comptes(fa).get("loup", 0)
	var hors_service := 0
	for slot: int in fa.actifs:
		if not fa.en_service(fa.territoires[slot], 12.0):
			hors_service += 1
	_verif(hors_service == 0 and midi_loups <= int(pl["loup"]), "midi : seuls les territoires encore de service sont occupés (%d loups, 0,2 de chance chacun ; %d la nuit)" % [midi_loups, nuit_loups])
	cyc.heure = 6.0
	for k in 40:
		fa._t_spawn = 99.0
		fa._tour()
		await _frames(2)
	var aube_gibier: int = _comptes(fa).get("cerf", 0) + _comptes(fa).get("biche", 0)
	_verif(aube_gibier >= 1 or nuit_gibier == 0 and aube_gibier == 0 and f["plafonds"]["total"] > 0, "6 h : du gibier (cerfs/biches) : %d" % aube_gibier)

	# repeuplement : une bête tuée vide son territoire 24 h de jeu
	var cible: BeteQuat = null
	var slot_c := -1
	for slot: int in fa.actifs:
		for b in fa.actifs[slot]:
			if cible == null:
				cible = b
				slot_c = slot
	if cible != null:
		cible.recevoir_coup(999.0, j.global_position, true, {})
		await _frames(5)
		_verif(fa.tues.has(slot_c) and not sc.draugrs.has(cible.ident), "bête tuée : territoire %d noté, retiré des morts permanents (draugrs)" % slot_c)
		var sauv: Dictionary = fa.exporter()
		var fb := Faune.new()
		fb.importer(JSON.parse_string(JSON.stringify(sauv)))
		_verif(fb.tues.has(slot_c) and is_equal_approx(fb.temps, fa.temps), "exporter/importer : territoire dépeuplé et temps conservés")
		fb.free()
		fa.actifs.erase(slot_c)
		var avant_t := fa.temps
		fa.temps = avant_t + 1.0
		var vide := true
		for k in 8:
			fa._t_spawn = 99.0
			fa._tour()
			if fa.actifs.has(slot_c):
				vide = false
		_verif(vide, "1 h après la mort : le territoire reste vide")
		fa.temps = avant_t + 30.0
		cyc.heure = fa.territoires[slot_c]["u"] * 0.0 + (23.0 if fa.territoires[slot_c]["espece"] == "loup" else 6.0)
		# territoire de nouveau disponible (le tour peut en choisir un autre : on teste l'éligibilité)
		var t_c: Dictionary = fa.territoires[slot_c]
		var regen := fa.temps - float(fa.tues[slot_c]) >= float(f["apparition"]["regen_heures"])
		_verif(regen, "30 h après la mort : le repeuplement est de nouveau permis (%s en %s)" % [t_c["espece"], t_c["biome"]])
	else:
		_verif(false, "aucune bête vivante pour tester la mort")

	# --- C. domestiques
	for slot: int in fa.actifs.keys():
		for b in fa.actifs[slot]:
			if is_instance_valid(b):
				b.queue_free()
	fa.actifs.clear()
	j.global_position = Vector3(63.0, 0.0, 36.0)       # au village : le husky peut suivre
	var dom := {}
	for e: Dictionary in fa.domestiques:
		dom[e["def"]["espece"]] = e
	_verif(fa.domestiques.size() == 7, "7 domestiques créés")
	cyc.heure = 12.0
	fa.actualiser()
	fa._tour()
	var vache: BeteQuat = dom["vache"]["bete"]
	var maison: Vector3 = dom["vache"]["maison"]
	_verif(vache.etat in [BeteQuat.REPOS, BeteQuat.ERRE] and not vache.dort, "12 h : la vache est à sa place, éveillée")
	# le soir : tous rejoignent leur coin d'enclos
	cyc.heure = 19.5
	for k in 3:
		fa._tour()
	await _frames(1500)
	var couche := fa.couche_de(dom["vache"]["def"])
	var ok_soir := true
	var loin := ""
	for e: Dictionary in fa.domestiques:
		if String(e["def"].get("enclos", "")) != "":
			var c := fa.couche_de(e["def"])
			var d: float = Vector2(e["bete"].global_position.x - c.x, e["bete"].global_position.z - c.z).length()
			if d > 1.8:
				ok_soir = false
				loin = "%s à %.1f m" % [e["def"]["ident"], d]
	_verif(ok_soir, "19 h 30 + 25 s : vaches, taureau, chevaux, âne regroupés contre l'enclos %s" % loin)
	# la nuit : ils dorment
	cyc.heure = 22.0
	for k in 3:
		fa._tour()
	await _frames(240)
	for k in 3:
		fa._tour()
	var dorment := 0
	for e: Dictionary in fa.domestiques:
		if e["bete"].dort:
			dorment += 1
	_verif(dorment >= 6, "22 h : %d domestiques dorment (clip %s, vitesse %.2f)" % [dorment, vache.anim.current_animation, vache.anim.speed_scale])
	_verif(vache.dort and vache.anim.current_animation == "Eat" and vache.anim.speed_scale < 0.5, "la vache dort : tête basse, clip Eat au ralenti")
	# réveil à l'aube : les couches se vident, retour à la place de jour à 7 h
	cyc.heure = 6.5
	for k in 3:
		fa._tour()
	_verif(not vache.dort and is_equal_approx(vache.anim.speed_scale, 1.0), "6 h 30 : la vache est réveillée")
	cyc.heure = 7.5
	for k in 3:
		fa._tour()
	await _frames(1500)
	var dm := Vector2(vache.global_position.x - maison.x, vache.global_position.z - maison.z).length()
	_verif(dm < vache.rayon_errance + 1.5, "7 h 30 + 25 s : la vache a repris sa place de jour (à %.1f m)" % dm)

	# --- C. husky suiveur
	var husky: BeteQuat = dom["husky"]["bete"]
	cyc.heure = 12.0
	for k in 3:
		fa._tour()
	await _frames(60)
	j.global_position = husky.global_position + Vector3(2.0, 0, 0)
	fa._tour()
	_verif(husky.suit_joueur, "joueur à 2 m dans le village : le husky se met à le suivre")
	j.global_position = husky.global_position + Vector3(14.0, 0, 0)
	await _frames(200)
	var dh := Vector2(husky.global_position.x - j.global_position.x, husky.global_position.z - j.global_position.z).length()
	_verif(husky.etat == BeteQuat.SUIT and dh < 6.0, "husky : suit le joueur qui s'éloigne (écart %.1f m, état %d)" % [dh, husky.etat])
	j.global_position = Vector3(63.0 + 70.0, 0.0, 36.0)       # hors du village
	for k in 4:
		fa._tour()
		await _frames(30)
	_verif(not husky.suit_joueur, "joueur hors du village : le husky cesse de suivre")
	j.global_position = Vector3(63.0, 0.0, 36.0)
	await _frames(1200)
	var dhome := Vector2(husky.global_position.x - 59.0, husky.global_position.z - 32.2).length()
	_verif(dhome < 6.0 or husky.etat in [BeteQuat.ERRE, BeteQuat.REPOS], "husky : revenu vers sa place (à %.1f m)" % dhome)

	print("\nFAUNE : %d OK, %d ÉCHEC(S)" % [_ok, _ko])
	quit(1 if _ko > 0 else 0)

func _comptes(fa: Faune) -> Dictionary:
	var r := {}
	for slot: int in fa.actifs:
		for b in fa._vivantes(slot):
			r[b.espece] = int(r.get(b.espece, 0)) + 1
	return r
