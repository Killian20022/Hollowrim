class_name SimulateurReseau
extends MultiplayerPeerExtension
## LOT 7 — enveloppe d'un MultiplayerPeer (ENet) qui (1) simule latence / gigue / perte à l'ENVOI, (2) compte paquets et octets, (3) permet un « trou noir »
## (coupure réseau simulée) et une coupure franche. Posée par ReseauTransportENet (une ligne) ; aucun autre fichier ne la voit : SceneMultiplayer
## parle à ce wrapper comme à un MultiplayerPeer ordinaire.
##
## LIGNE DE COMMANDE (arguments utilisateur, après « -- ») :
##   --sim-latence=ms   RTT simulé : chaque processus retarde ses envois de latence/2 (les deux processus doivent donc passer le même drapeau)
##   --sim-gigue=ms     gigue (±) ajoutée au délai d'un paquet, aussi en RTT (appliquée /2 par sens)
##   --sim-perte=%      perte par sens et par paquet ; --sim-graine=n pour reproduire
## MODÈLE de perte :
##   - non fiable (UNRELIABLE, UNRELIABLE_ORDERED) : le paquet est perdu pour de bon ;
##   - fiable : ENet retransmet -> le paquet n'est pas perdu mais arrive avec un retard de retransmission (max(2,5 x RTT, 120 ms) par essai perdu).
##     L'ordre des flux fiables et ordonnés est conservé (le retard d'un paquet retient les suivants du même flux : blocage de tête de file réel d'ENet).
## LIMITE : l'enveloppe se place AU-DESSUS d'ENet. ENet ne voit donc ni retard ni perte : ses propres mesures (RTT, perte, temporisations) restent celles de
## la boucle locale, et une « coupure » simulée ne déclenche pas les temporisations d'ENet (c'est la surveillance de Resilience qui la détecte). La
## coupure réelle se teste en tuant un processus. La réception n'est pas retardée (le retard de chaque sens est appliqué par l'émetteur).

const GIGUE_PAQUET := 12.0   # ms : ordre de grandeur de la gigue ajoutée au délai de retransmission

var interne: MultiplayerPeer
var latence_ms := 0.0
var gigue_ms := 0.0
var perte_pct := 0.0
var trou_noir := false       # vrai : tout est jeté (envoi ET réception) ; la liaison ENet reste « vivante »
var pairs: Array[int] = []

# compteurs (cumulés depuis la création)
var env_paquets := 0
var env_octets := 0
var rec_paquets := 0
var rec_octets := 0
var perdus_sim := 0          # paquets non fiables jetés par la simulation
var retransmis_sim := 0      # paquets fiables « perdus puis retransmis » (retard ajouté)
var env_par_pair := {}       # pair -> octets (charge utile) ; 0 diffusé est compté pour chaque pair connecté
var rec_par_pair := {}

var _cible := 0
var _canal := 0
var _mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _file: Array = []        # [échéance_ms, cible, canal, mode, octets]
var _fin_flux := {}          # clé flux -> dernière échéance (ordre conservé)
var _rng := RandomNumberGenerator.new()
var _dernier_recu_peer := 0

# ------------------------------------------------------------------------------------------------ paramètres globaux (ligne de commande)

static var _params := {}
static var _params_lus := false
static var coupe_globale := false   # trou noir appliqué à tous les wrappers (existants et futurs), posé par les tests

static func parametres() -> Dictionary:
	if not _params_lus:
		_params_lus = true
		_params = {"latence": 0.0, "gigue": 0.0, "perte": 0.0, "graine": -1}
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--sim-latence="):
				_params["latence"] = float(a.substr(14))
			elif a.begins_with("--sim-gigue="):
				_params["gigue"] = float(a.substr(12))
			elif a.begins_with("--sim-perte="):
				_params["perte"] = float(a.substr(12))
			elif a.begins_with("--sim-graine="):
				_params["graine"] = int(a.substr(13))
	return _params

## Change les paramètres EN COURS DE ROUTE (tests) : s'applique aux wrappers à venir ; les existants les relisent via `appliquer_a`.
static func definir(latence: float, gigue: float, perte: float) -> void:
	parametres()
	_params["latence"] = latence
	_params["gigue"] = gigue
	_params["perte"] = perte
	for w in _vivants:
		if is_instance_valid(w):
			w.appliquer_params()

static var _vivants: Array = []

static func envelopper(pair: MultiplayerPeer) -> SimulateurReseau:
	var s := SimulateurReseau.new()
	s.interne = pair
	s.appliquer_params()
	var g: int = int(parametres()["graine"])
	if g >= 0:
		s._rng.seed = g
	else:
		s._rng.randomize()
	pair.peer_connected.connect(s._pair_connecte)
	pair.peer_disconnected.connect(s._pair_deconnecte)
	_vivants.append(s)
	return s

func appliquer_params() -> void:
	var p := parametres()
	latence_ms = float(p["latence"])
	gigue_ms = float(p["gigue"])
	perte_pct = float(p["perte"])

func actif() -> bool:
	return latence_ms > 0.0 or gigue_ms > 0.0 or perte_pct > 0.0

func _pair_connecte(id: int) -> void:
	if not pairs.has(id):
		pairs.append(id)
	peer_connected.emit(id)

func _pair_deconnecte(id: int) -> void:
	if not pairs.has(id):
		return   # déjà annoncé (voir _disconnect_peer) : pas de doublon
	pairs.erase(id)
	peer_disconnected.emit(id)

## Pair ENet (ENetPacketPeer) d'un pair connecté, ou null (autre transport).
func pair_enet(id: int) -> Object:
	if interne is ENetMultiplayerPeer:
		return (interne as ENetMultiplayerPeer).get_peer(id)
	return null

# ------------------------------------------------------------------------------------------------ MultiplayerPeerExtension

func _get_packet_script() -> PackedByteArray:
	var de := interne.get_packet_peer()   # ENet : renvoie l'émetteur du PROCHAIN paquet, donc avant get_packet
	var b := interne.get_packet()
	rec_paquets += 1
	rec_octets += b.size()
	rec_par_pair[de] = int(rec_par_pair.get(de, 0)) + b.size()
	return b

func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	if trou_noir or coupe_globale:
		perdus_sim += 1
		return OK
	var cibles: Array[int] = []
	if _cible == 0:
		cibles.assign(pairs)
	elif _cible < 0:
		for p in pairs:
			if p != -_cible:
				cibles.append(p)
	else:
		cibles.append(_cible)
	for p in cibles:
		env_paquets += 1
		env_octets += p_buffer.size()
		env_par_pair[p] = int(env_par_pair.get(p, 0)) + p_buffer.size()
	if not actif():
		return _envoyer_interne(_cible, _canal, _mode, p_buffer)
	var fiable := _mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var ordonne := fiable or _mode == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	var maintenant := Time.get_ticks_msec()
	var rtt := latence_ms
	var delai := latence_ms * 0.5 + gigue_ms * 0.5 * _rng.randf_range(-1.0, 1.0)
	if perte_pct > 0.0:
		var p := perte_pct / 100.0
		if fiable:
			var essais := 0
			while _rng.randf() < p and essais < 6:
				essais += 1
				delai += maxf(2.5 * rtt, 120.0) + _rng.randf() * GIGUE_PAQUET
			if essais > 0:
				retransmis_sim += 1
		elif _rng.randf() < p:
			perdus_sim += 1
			return OK
	delai = maxf(delai, 0.0)
	var echeance := float(maintenant) + delai
	if ordonne:
		var cle := "%d|%d|%d" % [_cible, _canal, _mode]
		echeance = maxf(echeance, float(_fin_flux.get(cle, 0.0)))
		_fin_flux[cle] = echeance
	_file.append([echeance, _cible, _canal, _mode, p_buffer])
	return OK

func _envoyer_interne(cible: int, canal: int, mode: int, octets: PackedByteArray) -> Error:
	interne.set_target_peer(cible)
	interne.transfer_channel = canal
	interne.transfer_mode = mode as MultiplayerPeer.TransferMode
	return interne.put_packet(octets)

func _vider(tout := false) -> void:
	if _file.is_empty():
		return
	var maintenant := float(Time.get_ticks_msec())
	var reste: Array = []
	for it: Array in _file:
		if tout or float(it[0]) <= maintenant:
			_envoyer_interne(int(it[1]), int(it[2]), int(it[3]), it[4])
		else:
			reste.append(it)
	_file = reste

func _get_available_packet_count() -> int:
	if trou_noir or coupe_globale:
		_jeter_recus()
		return 0
	return interne.get_available_packet_count()

func _jeter_recus() -> void:
	while interne.get_available_packet_count() > 0:
		interne.get_packet()
		perdus_sim += 1

func _get_max_packet_size() -> int:
	return interne.get_max_packet_size()

func _get_packet_peer() -> int:
	return interne.get_packet_peer()

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return interne.get_packet_mode()

func _get_packet_channel() -> int:
	return interne.get_packet_channel()

func _set_transfer_channel(p_channel: int) -> void:
	_canal = p_channel

func _get_transfer_channel() -> int:
	return _canal

func _set_transfer_mode(p_mode: MultiplayerPeer.TransferMode) -> void:
	_mode = p_mode

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode as MultiplayerPeer.TransferMode

func _set_target_peer(p_peer: int) -> void:
	_cible = p_peer

func _is_server() -> bool:
	return interne.get_unique_id() == 1

func _poll() -> void:
	interne.poll()
	_vider()

func _close() -> void:
	_vider(true)
	interne.close()

func _disconnect_peer(p_peer: int, p_force: bool) -> void:
	_vider(true)
	interne.disconnect_peer(p_peer, p_force)
	# ENet n'émet PAS peer_disconnected pour une déconnexion décidée localement : sans cela SceneMultiplayer garde le pair (« Invalid target peer »,
	# fantôme chez les autres invités). On l'annonce ici ; le garde de _pair_deconnecte évite le doublon si ENet l'émet aussi.
	if pairs.has(p_peer):
		_pair_deconnecte.call_deferred(p_peer)

func _get_unique_id() -> int:
	return interne.get_unique_id()

func _set_refuse_new_connections(p_enable: bool) -> void:
	interne.refuse_new_connections = p_enable

func _is_refusing_new_connections() -> bool:
	return interne.refuse_new_connections

func _is_server_relay_supported() -> bool:
	return interne.is_server_relay_supported()

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return interne.get_connection_status()

# ------------------------------------------------------------------------------------------------ mesures

## Instantané des compteurs (pour calculer des débits par différence).
func compteurs() -> Dictionary:
	return {"env_paquets": env_paquets, "env_octets": env_octets, "rec_paquets": rec_paquets, "rec_octets": rec_octets,
		"perdus_sim": perdus_sim, "retransmis_sim": retransmis_sim, "env_par_pair": env_par_pair.duplicate(), "rec_par_pair": rec_par_pair.duplicate()}
