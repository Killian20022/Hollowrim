class_name AvatarsCoop
extends Node
## LOT 4b — gestionnaire des AVATARS DISTANTS (production ; proto_coop.gd garde le sien pour le prototype du lot 1).
## À poser sous le MÊME parent, avec le MÊME nom (« AvatarsCoop »), sur toutes les machines (RPC par chemin) :
##     var a := AvatarsCoop.installer(monde, joueur_local, "Nom du joueur")
## - Chaque machine envoie l'état compact de SON joueur à 20 Hz (RPC non fiable) ; l'hôte le relaie aux autres invités (étoile ENet).
##   Les états des joueurs sont des états « propriétaire -> hôte -> autres » : le Replicateur (autorité = hôte) ne convient pas, on
##   reprend seulement son principe (lecture interpolée à ~100 ms, état binaire compact) dans AvatarDistant.
## - L'équipement (mains + armure + nom) part en évènement fiable « avatar_equip » à chaque changement et toutes les REPETITION s
##   (un joueur qui arrive reçoit ainsi tout sans protocole de rattrapage) ; l'hôte relaie.
## - L'avatar d'un pair est créé à son premier évènement / état, retiré à sa déconnexion.
## - Mort / à terre : les drapeaux de l'état compact suffisent (aucun évènement dédié) ; ATerre continue de tenir le registre « à terre ».

const PERIODE := 1.0 / 20.0
const SONDE := 0.25           # s : relevé de l'équipement local (envoi seulement s'il change)
const REPETITION := 2.5       # s : renvoi périodique de l'équipement

var joueur: CharacterBody3D
var parent_avatars: Node
var nom_local := ""
var avatars := {}             # peer_id -> AvatarDistant
var equip_recus := {}         # peer_id -> dernier dictionnaire reçu (relais de l'hôte vers les arrivants)
var _acc := 0.0
var _acc_sonde := 0.0
var _depuis_envoi := 0.0
var _equip_envoye := {}

static func installer(parent: Node, j: CharacterBody3D, nom_joueur := "") -> AvatarsCoop:
	var a := AvatarsCoop.new()
	a.name = "AvatarsCoop"   # même chemin sur toutes les machines (RPC)
	a.joueur = j
	a.parent_avatars = parent
	a.nom_local = nom_joueur
	parent.add_child(a)
	return a

func _r() -> Node:
	return PauseCoop.R()

func _ready() -> void:
	_r().abonner("avatar_equip", _sur_equip)
	_r().joueur_deconnecte.connect(_sur_deconnecte)
	if nom_local == "":
		nom_local = "Joueur %d" % _r().mon_id()

func _exit_tree() -> void:
	var r := _r()
	if r != null:
		r.desabonner("avatar_equip", _sur_equip)

## Avatar du pair `id` (créé au besoin) ; null pour soi-même.
func avatar(id: int) -> AvatarDistant:
	if id == _r().mon_id() or id <= 0:
		return null
	if not avatars.has(id) or not is_instance_valid((avatars[id] as AvatarDistant).noeud):
		var nom_reg := String(_r().registre.infos(id).get("nom", ""))
		avatars[id] = AvatarDistant.creer(parent_avatars, id, nom_reg)
		if equip_recus.has(id):
			(avatars[id] as AvatarDistant).appliquer_equipement(equip_recus[id])
	return avatars[id]

func _sur_deconnecte(id: int) -> void:
	if avatars.has(id):
		(avatars[id] as AvatarDistant).liberer()
		avatars.erase(id)
	equip_recus.erase(id)

# ------------------------------------------------------------------------------------------------ état compact

@rpc("any_peer", "call_remote", "unreliable")
func _etat(e: Array) -> void:
	var de := multiplayer.get_remote_sender_id()
	_recevoir(de, e)
	if _r().est_hote():   # relais vers les autres invités (id de l'émetteur ajouté)
		for autre in multiplayer.get_peers():
			if autre != de:
				_etat_relais.rpc_id(autre, de, e)

@rpc("authority", "call_remote", "unreliable")
func _etat_relais(de: int, e: Array) -> void:
	_recevoir(de, e)

func _recevoir(de: int, e: Array) -> void:
	if e.size() < 8:
		return
	var a := avatar(de)
	if a != null:
		a.recevoir(e)

# ------------------------------------------------------------------------------------------------ équipement

func _sur_equip(expediteur: int, id: Variant, d: Variant) -> void:
	var pair := int(id)
	if not (d is Dictionary) or pair == _r().mon_id():
		return
	equip_recus[pair] = d
	var a := avatar(pair)
	if a != null:
		a.appliquer_equipement(d)
	if _r().est_hote():   # relais vers les autres invités (id d'origine conservé)
		for autre in multiplayer.get_peers():
			if autre != expediteur:
				_r().envoyer_evenement("avatar_equip", pair, d, autre)

func _envoyer_equipement(force: bool) -> void:
	var d := AvatarDistant.capturer_equipement(joueur, nom_local)
	if force or d != _equip_envoye:
		_equip_envoye = d
		_depuis_envoi = 0.0
		_r().registre.definir_info(_r().mon_id(), "nom", nom_local)
		_r().envoyer_evenement("avatar_equip", _r().mon_id(), d)

# ------------------------------------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	var r := _r()
	for a: AvatarDistant in avatars.values():
		a.avancer(dt)
	if r == null or not r.est_en_ligne() or r.joueurs().size() < 2 or joueur == null or not is_instance_valid(joueur):
		return
	_acc += dt
	if _acc >= PERIODE:
		_acc = 0.0
		_etat.rpc(AvatarDistant.capturer(joueur))
	_acc_sonde += dt
	_depuis_envoi += dt
	if _acc_sonde >= SONDE:
		_acc_sonde = 0.0
		_envoyer_equipement(_depuis_envoi >= REPETITION)
