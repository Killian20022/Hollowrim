extends Node3D
## Intégration lot 2 (outils/test_integration2.sh) : hôte + invité headless. L'hôte modifie le monde AVANT l'arrivée de l'invité
## (heure, coffre pris, état d'un contributeur Rejoindre) ; l'invité rejoint en cours de partie et doit : recevoir cet état,
## voir les PNJ répliqués (Replicateur), perdre le coffre déjà pris, partager « premier arrivé » sur un coffre neuf (1 seul gagnant) ;
## l'hôte doit voir l'avatar de l'invité (ProtoAvatar) inscrit au registre (joueur le plus proche).
## Arguments (après --) : --role=hote | --role=invite  --port=N

class FauxJoueur extends CharacterBody3D:
	var en_dialogue := false
	var mort := false
	var camera: Camera3D

class Quetes extends Node:
	var vus := {}

const VILLAGEOIS := preload("res://scripts/villageois.gd")
const CYCLE := preload("res://scripts/cycle.gd")

var role := "hote"
var port := 24751
var cycle: Node
var joueur: FauxJoueur
var pnjs := {}
var mv: ReseauMondeVivant
var quetes := Quetes.new()
var modif := 0
var gagnes := {}        # cle -> true (gagnée ici)
var perdus := {}
var echecs := 0
var _fin := false

func _verifier(nom: String, ok: bool, detail := "") -> void:
	print("TEST ", "ok" if ok else "ECHEC", " : ", nom, "  ", detail)
	if not ok:
		echecs += 1

func _reclamer(cle: String) -> void:
	ReseauLieux.reclamer(cle, func() -> void: gagnes[cle] = true, func() -> void: perdus[cle] = true)

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
	cycle.heure = 15.0 if role == "hote" else 3.0
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
	add_child(quetes)
	ReseauLieux.poser_quetes(quetes, ["integ:"])
	var rj := get_node("/root/Rejoindre")
	rj.call("contributeur", "integ2", func() -> Dictionary: return {"modif": modif}, func(d: Dictionary) -> void: modif = int(d.get("modif", 0)))
	Reseau.connexion_echouee.connect(func() -> void:
		await get_tree().create_timer(1.0).timeout
		Reseau.rejoindre("127.0.0.1", port))
	Reseau.abonner("test_resultat", _sur_resultat)
	Reseau.abonner("test_go", _sur_go)
	if role == "hote":
		# modifications AVANT l'arrivée de l'invité
		modif = 42
		for p in pnjs.values():
			p._prochaine_promenade = 0.1
		print("COOP hôte : ", error_string(Reseau.heberger(port)))
		_reclamer("integ:coffre")   # en ligne : l'hôte attribue la clé
		print("HOTE_PRET")
		_boucle_hote()
	else:
		print("COOP invité : ", error_string(Reseau.rejoindre("127.0.0.1", port)))
		_boucle_invite()
	await get_tree().create_timer(80.0).timeout
	if not _fin:
		print("TEST ECHEC : délai dépassé")
		get_tree().quit(1)

func _boucle_hote() -> void:
	_verifier("hôte : coffre pris localement (gagné)", gagnes.has("integ:coffre"))
	var t := 0.0
	while Reseau.joueurs().size() < 2 and t < 200.0:   # large : démarrage de l'invité lent sous charge
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	_verifier("invité connecté", Reseau.joueurs().size() == 2)
	if Reseau.joueurs().size() < 2:
		_terminer()
		return
	var id: int = Reseau.joueurs()[1]
	var av := ProtoAvatar.creer(self, id, (pnjs.values()[2] as Node3D).global_position + Vector3(2, 0, 0))
	_verifier("avatar de l'invité inscrit au registre", Reseau.registre.noeud(id) == av.noeud)
	await get_tree().create_timer(3.0).timeout
	var v2: Node3D = pnjs.values()[2]
	_verifier("joueur le plus proche du 3e PNJ = avatar de l'invité", ReseauMondeVivant.joueur_proche(v2.global_position, joueur) == av.noeud)
	# top : course sur un coffre neuf, des deux côtés en même temps
	Reseau.envoyer_evenement("test_go", 0, null)
	_reclamer("integ:c2")
	await get_tree().create_timer(2.0).timeout
	_verifier("hôte : un perdant s'il n'a pas gagné « c2 »", gagnes.has("integ:c2") != perdus.has("integ:c2"))
	await get_tree().create_timer(10.0).timeout
	if not _fin:
		_verifier("résultat de l'invité reçu", false)
		_terminer()

var _go := false
func _sur_go(expediteur: int, _id: Variant, _d: Variant) -> void:
	if role == "invite" and expediteur == 1:
		_go = true

func _boucle_invite() -> void:
	var t := 0.0
	while not (Reseau.est_en_ligne() and Reseau.joueurs().size() >= 2):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if t > 50.0:
			break
	await get_tree().create_timer(3.0).timeout    # instantané + quelques états du réplicateur
	_verifier("rejoindre : état du contributeur reçu (modif=42)", modif == 42, str(modif))
	_verifier("rejoindre : heure de l'hôte (15 h, pas 3 h)", absf(cycle.heure - 15.0) < 1.0, "%.2f" % cycle.heure)
	_verifier("PNJ marionnettes chez l'invité", pnjs.values().all(func(p): return p.marionnette))
	_verifier("mêmes ids de PNJ (Replicateur)", mv.ids().size() >= 5)
	_reclamer("integ:coffre")
	await get_tree().create_timer(1.0).timeout
	_verifier("coffre déjà pris par l'hôte : perdu chez l'invité", perdus.has("integ:coffre") and not gagnes.has("integ:coffre"))
	var tt := 0.0
	while not _go and tt < 20.0:
		await get_tree().create_timer(0.1).timeout
		tt += 0.1
	_reclamer("integ:c2")
	await get_tree().create_timer(2.0).timeout
	var bouge := 0
	for id in pnjs:
		var n := pnjs[id] as Node3D
		if n.global_position.distance_to((pnjs[id].points[0] as Vector3)) > 1.0:
			bouge += 1
	_verifier("des PNJ marchent chez l'invité (répliqués)", bouge >= 1, "bougés=%d" % bouge)
	Reseau.envoyer_evenement("test_resultat", 0, {"echecs": echecs, "c2": gagnes.has("integ:c2")})
	await get_tree().create_timer(0.5).timeout
	_terminer()

func _sur_resultat(expediteur: int, _id: Variant, d: Variant) -> void:
	if role == "hote" and expediteur != 1:
		echecs += int(d["echecs"])
		var total := (1 if gagnes.has("integ:c2") else 0) + (1 if d["c2"] else 0)
		_verifier("coffre neuf pris UNE seule fois (hôte + invité)", total == 1, "total=%d" % total)
		_terminer()

func _terminer() -> void:
	if _fin:
		return
	_fin = true
	print("TEST ", "SUCCES" if echecs == 0 else "ECHEC global", " (", role, ")")
	get_tree().quit(0 if echecs == 0 else 1)
