extends Node3D
## Lot 2b — test headless à 2 instances (outils/test_monde_vivant.sh) : mêmes villageois des deux côtés, heure alignée (malgré un
## Engine.time_scale local), un PNJ qui marche chez l'hôte bouge chez l'invité, cible = joueur le plus proche.
## Arguments (après --) : --role=hote | --role=invite  --port=N

class FauxJoueur extends CharacterBody3D:
	var en_dialogue := false
	var mort := false
	var camera: Camera3D

const VILLAGEOIS := preload("res://scripts/villageois.gd")
const CYCLE := preload("res://scripts/cycle.gd")

var role := "hote"
var port := 24731
var cycle: Node
var joueur: FauxJoueur
var pnjs := {}      # id -> villageois
var mv: ReseauMondeVivant
var depart := {}    # id -> position au départ
var echecs := 0
var _fin := false

func _verifier(nom: String, ok: bool, detail := "") -> void:
	print("TEST ", "ok" if ok else "ECHEC", " : ", nom, "  ", detail)
	if not ok:
		echecs += 1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
	Effets.coop = true
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	f.shape = BoxShape3D.new()
	(f.shape as BoxShape3D).size = Vector3(200, 1, 200)
	sol.position.y = -0.5
	sol.add_child(f)
	add_child(sol)
	joueur = FauxJoueur.new()
	joueur.camera = Camera3D.new()
	joueur.add_child(joueur.camera)
	add_child(joueur)
	joueur.position = Vector3(0, 0.1, 0)
	cycle = Node.new()
	cycle.set_script(CYCLE)
	cycle.env = Environment.new()
	cycle.lumiere = DirectionalLight3D.new()
	cycle.ciel = ShaderMaterial.new()
	cycle.heure = 10.0 if role == "hote" else 3.0
	add_child(cycle)
	var liste: Array = VILLAGEOIS.charger()
	for i in 5:
		var p: CharacterBody3D = VILLAGEOIS.new()
		p.donnees = liste[i]
		p.joueur = joueur
		p.points = [Vector3(i * 6.0 - 12.0, 0.1, -10), Vector3(i * 6.0 - 12.0, 0.1, -25)]
		p.position = p.points[0]
		add_child(p)
		pnjs["v:" + String(liste[i].get("id", ""))] = p
	mv = ReseauMondeVivant.installer(self)
	Reseau.abonner("test_fin", _sur_fin)
	Reseau.abonner("test_resultat", _sur_resultat)
	Reseau.connexion_reussie.connect(func() -> void: print("COOP connecté à l'hôte"))
	Reseau.joueur_connecte.connect(func(i: int) -> void: print("COOP joueur connecté ", i))
	Reseau.connexion_echouee.connect(func() -> void:
		print("COOP connexion échouée, nouvel essai")
		await get_tree().create_timer(1.0).timeout
		Reseau.rejoindre("127.0.0.1", port))   # l'hôte n'écoute pas encore : on réessaie
	var err := Reseau.heberger(port) if role == "hote" else Reseau.rejoindre("127.0.0.1", port)
	print("COOP ", role, " réseau : ", error_string(err))
	if role == "hote":
		print("HOTE_PRET")
	await get_tree().create_timer(0.5).timeout
	for id in pnjs:
		depart[id] = (pnjs[id].points[0] as Vector3)   # point d'apparition (l'invité a déjà reçu l'état de l'hôte à ce stade)
	if role == "hote":
		for p in pnjs.values():
			p._prochaine_promenade = 0.1
		_boucle_hote()
	else:
		_boucle_invite()
	# garde-fou
	await get_tree().create_timer(60.0).timeout
	if not _fin:
		print("TEST ECHEC : délai dépassé")
		get_tree().quit(1)

func _avatar_invite(id: int) -> void:
	if true:
		# avatar factice de l'invité, posé près du 3e villageois, enregistré dans le registre
		var av := FauxJoueur.new()
		av.name = "Joueur_%d" % id
		av.camera = Camera3D.new()
		add_child(av)
		av.global_position = (pnjs.values()[2] as Node3D).global_position + Vector3(2, 0, 0)
		Reseau.registre.definir_noeud(id, av)

func _boucle_hote() -> void:
	var t := 0.0
	while Reseau.joueurs().size() < 2 and t < 40.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	_verifier("invité connecté", Reseau.joueurs().size() == 2)
	if Reseau.joueurs().size() == 2:
		_avatar_invite(Reseau.joueurs()[1])
	await get_tree().create_timer(9.0).timeout
	# cible = joueur le plus proche
	var av: Node = Reseau.registre.noeud(Reseau.joueurs()[1])
	var v2: Node3D = pnjs.values()[2]
	_verifier("cible du 3e villageois = avatar de l'invité (le plus proche)", ReseauMondeVivant.joueur_proche(v2.global_position, joueur) == av)
	var tous_ok := true
	for p in pnjs.values():
		var voulu: Node = joueur if p.global_position.distance_to(joueur.global_position) <= p.global_position.distance_to(av.global_position) else av
		tous_ok = tous_ok and ReseauMondeVivant.joueur_proche(p.global_position, joueur) == voulu
	_verifier("cible de chaque villageois = joueur le plus proche (local ou avatar)", tous_ok)
	_verifier("distance_joueurs prend l'avatar proche en compte", ReseauMondeVivant.distance_joueurs(v2.global_position, joueur.global_position) < 6.0)
	var bouge := 0
	var pos := {}
	for id in pnjs:
		pos[id] = (pnjs[id] as Node3D).global_position
		if pos[id].distance_to(depart[id]) > 1.5:
			bouge += 1
	_verifier("des villageois marchent chez l'hôte", bouge >= 1, "bougés=%d" % bouge)
	Reseau.envoyer_evenement("test_fin", 0, {"pos": pos, "h": cycle.heure, "j": cycle.jour, "bouge": bouge})
	await get_tree().create_timer(15.0).timeout
	if not _fin:
		_verifier("résultat de l'invité reçu", false)
		_terminer()

func _boucle_invite() -> void:
	var t := 0.0
	while not Reseau.est_en_ligne() or Reseau.joueurs().size() < 2:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if t > 30.0:
			break
	# ralenti LOCAL pendant quelques secondes : l'heure partagée ne doit pas en pâtir
	await get_tree().create_timer(2.0).timeout
	Engine.time_scale = 0.5
	await get_tree().create_timer(1.5).timeout
	Engine.time_scale = 1.0

func _sur_fin(expediteur: int, _id: Variant, d: Variant) -> void:
	if role != "invite" or expediteur != 1:
		return
	var ids: Array = pnjs.keys()
	ids.sort()
	_verifier("mêmes identifiants de PNJ enregistrés (>= 5)", mv.ids().size() >= 5 and mv.ids() == ids, str(mv.ids().size()))
	var pire := 0.0
	var bouge_ok := 0
	for id in d["pos"]:
		var n := pnjs[id] as Node3D
		pire = maxf(pire, n.global_position.distance_to(d["pos"][id]))
		if n.global_position.distance_to(depart[id]) > 1.0 and (d["pos"][id] as Vector3).distance_to(depart[id]) > 1.5:
			bouge_ok += 1
	_verifier("positions proches de l'hôte (écart max < 1,5 m)", pire < 1.5, "écart max %.2f m" % pire)
	_verifier("un PNJ qui bouge chez l'hôte bouge chez l'invité", d["bouge"] >= 1 and bouge_ok >= 1, "hôte=%d invité=%d" % [d["bouge"], bouge_ok])
	var dh := absf(fposmod(float(d["h"]) - cycle.heure + 12.0, 24.0) - 12.0)
	_verifier("heure alignée (< 0,03 h) malgré le ralenti local", dh < 0.03 and int(d["j"]) == cycle.jour, "écart %.4f h, jour %d/%d" % [dh, d["j"], cycle.jour])
	var marionnettes := true
	for p in pnjs.values():
		marionnettes = marionnettes and p.marionnette
	_verifier("PNJ en marionnettes chez l'invité", marionnettes)
	Reseau.envoyer_evenement("test_resultat", 0, {"echecs": echecs})
	await get_tree().create_timer(0.5).timeout
	_terminer()

func _sur_resultat(expediteur: int, _id: Variant, d: Variant) -> void:
	if role == "hote" and expediteur != 1:
		echecs += int(d["echecs"])
		_terminer()

func _terminer() -> void:
	if _fin:
		return
	_fin = true
	print("TEST ", "SUCCES" if echecs == 0 else "ECHEC global", " (", role, ")")
	get_tree().quit(0 if echecs == 0 else 1)
