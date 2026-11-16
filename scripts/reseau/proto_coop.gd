class_name ProtoCoop
extends Node
## LOT 1 — prototype coop 2 joueurs dans scenes/test_combat.tscn (docs : PLAN_MULTIJOUEUR.md).
## Lancement : « -- --coop=hote » (héberge) ou « -- --coop=<ip> » (rejoint) ; [--coop-port=N] ; sans --coop : solo inchangé.
## Test automatique headless : ajouter --coop-test (voir outils/test_coop_proto.sh).
## - Chaque machine simule SON joueur (est_local) et envoie sa position à 20 Hz ; les autres sont des avatars « Joueur_<peer_id> »
##   (joueur.gd, est_local = false, corps 3e personne) interpolés à ~100 ms.
## - Le draugr : l'hôte détient l'IA (cible = joueur le plus proche), l'invité n'a qu'une marionnette interpolée.
## - L'objet ramassable et la porte : voir proto_monde.gd (l'hôte arbitre).
## - Finishers / ralentis : désactivés (Effets.coop).

const PORT := 24565
const PERIODE_ENVOI := 1.0 / 20.0
const PERIODE_ETAT_ENNEMI := 1.0 / 15.0
const PERIODE_CIBLE := 0.25

var scene: Node3D
var joueur: CharacterBody3D
var draugr: CharacterBody3D
var mode := ""
var port := PORT
var est_hote := false
var monde: ProtoMonde
var avatars := {}   # peer_id -> ProtoAvatar
var _tampon_draugr := ProtoTampon.new()
var _t_envoi := 0.0
var _t_etat := 0.0
var _t_cible := 0.0
var test: ProtoTest
var captures: Node   # proto_captures.gd (preload : pas de class_name, le cache des classes n'a pas à être régénéré)

## Appelé par test_combat._ready (une fois tout créé). Renvoie null en solo.
static func installer(sc: Node3D, args: Dictionary) -> ProtoCoop:
	if not args.has("coop"):
		return null
	var p := ProtoCoop.new()
	p.name = "ProtoCoop"   # même chemin sur toutes les machines (RPC)
	p.scene = sc
	p.joueur = sc.get("joueur")
	p.draugr = sc.get("draugr")
	p.mode = String(args["coop"])
	p.port = int(args.get("coop-port", PORT))
	p.est_hote = p.mode == "hote"
	if args.has("coop-test"):
		p.test = ProtoTest.new()
		p.test.coop = p
	if args.has("coop-captures"):   # outils/captures_coop.sh : scénario de captures (rendu réel)
		p.captures = preload("res://scripts/reseau/proto_captures.gd").new()
		p.captures.coop = p
		p.captures.dossier = String(args["coop-captures"])
	sc.add_child(p)
	return p

func _ready() -> void:
	Effets.coop = true
	var err := Reseau.heberger(port) if est_hote else Reseau.rejoindre(mode, port)
	print("COOP ", "hote" if est_hote else "invite", " réseau: ", error_string(err))
	if err != OK:
		push_error("COOP : connexion impossible")
	Reseau.joueur_connecte.connect(_sur_connecte)
	Reseau.joueur_deconnecte.connect(_sur_deconnecte)
	monde = ProtoMonde.new()
	monde.joueur = joueur
	scene.add_child(monde)
	Reseau.abonner("coup", _sur_coup)
	Reseau.abonner("draugr_mort", _sur_draugr_mort)
	if not est_hote:
		joueur.global_position = Vector3(-1.5, 0.0, 0.5)   # ne pas apparaître dans l'hôte
		if draugr != null:
			draugr.set_physics_process(false)   # marionnette : l'IA est chez l'hôte
	elif draugr != null:
		draugr.mort.connect(func(_i: String) -> void: Reseau.emettre("draugr_mort", "draugr_test", null))
	if test != null:
		add_child(test)
	if captures != null:
		add_child(captures)

func _sur_connecte(id: int) -> void:
	print("COOP joueur connecté ", id)
	_avatar(id)

func _sur_deconnecte(id: int) -> void:
	if avatars.has(id):
		(avatars[id] as ProtoAvatar).noeud.queue_free()
		avatars.erase(id)

func _avatar(id: int) -> ProtoAvatar:
	if id == Reseau.mon_id():
		return null
	if not avatars.has(id):
		var a := ProtoAvatar.creer(scene, id, Vector3(0, -100, 0))   # caché sous le sol jusqu au premier instantané
		avatars[id] = a
		if est_hote:
			a.noeud.coup_distant.connect(func(d: float, o: Vector3, opt: Dictionary) -> void: _coup_vers(id, d, o, opt))
	return avatars[id]

# --- avatars ---------------------------------------------------------------------------------------
@rpc("any_peer", "unreliable")
func _etat_joueur(pos: Vector3, lacet: float, tangage: float, vel: Vector3, accroupi: bool) -> void:
	var de := multiplayer.get_remote_sender_id()
	var a := _avatar(de)
	if a != null:
		a.recevoir(pos, lacet, tangage, vel, accroupi)
	if est_hote:   # relais vers les autres invités (id de l'émetteur ajouté)
		for autre in multiplayer.get_peers():
			if autre != de:
				_etat_joueur_relais.rpc_id(autre, de, pos, lacet, tangage, vel, accroupi)

@rpc("authority", "unreliable")
func _etat_joueur_relais(de: int, pos: Vector3, lacet: float, tangage: float, vel: Vector3, accroupi: bool) -> void:
	var a := _avatar(de)
	if a != null:
		a.recevoir(pos, lacet, tangage, vel, accroupi)

# --- draugr ----------------------------------------------------------------------------------------
@rpc("authority", "unreliable")
func _etat_draugr(pos: Vector3, lacet: float, vie: float) -> void:
	_tampon_draugr.pousser(pos, lacet, vie)

func _sur_draugr_mort(expediteur: int, _id: Variant, _d: Variant) -> void:
	if expediteur == 1 and not est_hote and is_instance_valid(draugr):
		draugr.queue_free()
		draugr = null

## Cible = le joueur (local ou avatar) le plus proche du draugr.
func _retarget() -> void:
	var meilleur: CharacterBody3D = joueur
	var dmin := draugr.global_position.distance_squared_to(joueur.global_position)
	for a: ProtoAvatar in avatars.values():
		var d := draugr.global_position.distance_squared_to(a.noeud.global_position)
		if d < dmin:
			dmin = d
			meilleur = a.noeud
	draugr.joueur = meilleur

# --- coups encaissés par un avatar : la victime décide -------------------------------------------------
func _coup_vers(id: int, degats: float, origine: Vector3, options: Dictionary) -> void:
	var propre := {}
	for k in options:
		if typeof(options[k]) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			propre[k] = options[k]
	Reseau.emettre("coup", "draugr_test", {"degats": degats, "origine": origine, "options": propre}, id)

func _sur_coup(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur == 1 and not est_hote:
		var r: String = joueur.recevoir_coup(float(d["degats"]), d["origine"], d["options"])
		print("COOP coup reçu de l'hôte -> ", r)

func _physics_process(dt: float) -> void:
	for a: ProtoAvatar in avatars.values():
		a.avancer()
	if not Reseau.est_en_ligne() or Reseau.joueurs().size() < 2:
		return
	_t_envoi += dt
	if _t_envoi >= PERIODE_ENVOI:
		_t_envoi = 0.0
		_etat_joueur.rpc(joueur.global_position, joueur.rotation.y, joueur.tete.rotation.x, joueur.velocity, joueur.accroupi)
	if draugr == null or not is_instance_valid(draugr):
		return
	if est_hote:
		_t_cible += dt
		if _t_cible >= PERIODE_CIBLE:
			_t_cible = 0.0
			_retarget()
		_t_etat += dt
		if _t_etat >= PERIODE_ETAT_ENNEMI:
			_t_etat = 0.0
			_etat_draugr.rpc(draugr.global_position, draugr.rotation.y, draugr.vie)
	else:
		var r := _tampon_draugr.lire()
		if not r.is_empty():
			draugr.global_position = r["pos"]
			draugr.rotation.y = r["lacet"]
			draugr.vie = r["extra"]
