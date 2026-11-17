class_name Resilience
extends Node
## LOT 7 — résilience réseau : mesures (RTT, perte, débit), surveillance de liaison, reconnexion automatique, nettoyage des départs, compensation de latence.
## Nœud « /root/Resilience » créé par ReseauTransportENet (Resilience.preparer) à la première hébergement / connexion, même chemin sur toutes les machines
## (RPC de ping). Aucun autoload, aucun changement de project.godot. Voir docs/reseau_lot7.md.
## Scripts préchargés par des tests « -s » : l'autoload Reseau est résolu à l'exécution (R()), jamais par son identifiant nu.
##
## SIGNAUX (interface vers l'interface du jeu / la sauvegarde 5b) :
##   message(texte)                     texte à afficher au joueur (FR)
##   reconnexion_tentative(n, max)      essai n sur max en cours
##   reconnexion_reussie(ancien_id, nouvel_id)   liaison rétablie, personnage repris
##   reconnexion_abandonnee(texte)      3 échecs : retour au titre demandé (fait si retour_titre_auto)
##   retour_titre_demande(texte)        idem, pour une interface qui gère elle-même le retour
##   joueur_parti(id)                    (hôte) un invité a disparu ; menaces / cibles nettoyées
## L'évènement « l'hôte est parti » à brancher pour sauvegarder le personnage : Reseau.hote_perdu(raison) (émis AVANT le retour en solo : l'état du joueur est intact).

signal message(texte: String)
signal reconnexion_tentative(n: int, maximum: int)
signal reconnexion_reussie(ancien_id: int, nouvel_id: int)
signal reconnexion_abandonnee(texte: String)
signal retour_titre_demande(texte: String)
signal joueur_parti(id: int)
signal rtt_mis_a_jour(pair: int, ms: float)

# ------------------------------------------------------------------------------------------------ réglages (modifiables par les tests)
const ESSAIS_MAX := 3
const FICHIER_MESSAGE := "user://reseau_message.txt"   # message laissé à l'écran titre après un retour forcé (la relance perd les variables statiques)
const SURCOUT_PAQUET := 40          # o : IP/UDP (28) + en-têtes ENet (~12), pour estimer le débit « sur le fil »
const VITESSE_JOUEUR := 7.0         # m/s : course + élan
const VITESSE_ENNEMI := 6.0         # m/s
const TOLERANCE_MAX_M := 5.0

static var geler_ennemis := true     # hôte perdu : les marionnettes sont figées pendant la reconnexion (sinon l'IA locale reprend un état à moitié répliqué)
static var compensation := true     # compensation de latence de CombatCoop (portée / cadence)
static var message_en_attente := ""  # dernier message de retour forcé (dans le processus ; entre deux relances : message_titre())
static var derniere_raison := ""

var periode_ping := 1.0             # s ; les tests passent à 0,25
var silence_max := 12.0             # s sans aucune réponse d'un pair -> liaison déclarée morte (un écran de chargement ne doit pas faire expulser un joueur)
var timeout_enet := Vector3i(16, 3000, 10000)  # limite, minimum ms, maximum ms (ENet par défaut : 32, 5000, 30000)
var pause_essais := 2.0             # s avant chaque essai de reconnexion
var delai_confirmation := 4.0       # s pour recevoir un pong après la reconnexion
var auto_reconnexion := true
var retour_titre_auto := true
var afficher_metriques := false     # journal [RESEAU] toutes les 5 s (--debug-reseau)

var rtt := {}                       # pair -> ms (moyenne lissée)
var rtt_min := {}
var rtt_max := {}
var pings_envoyes := {}             # pair -> n
var pongs_recus := {}
var pings_vol := {}                 # pair -> {seq: instant d'envoi} (pings sans réponse encore)
var pings_expires := {}             # pair -> n pings restés sans réponse plus de 2 s (= perdus, aller ou retour)
var derniere_reponse := {}          # pair -> s (ticks)
var rtt_enet := {}                  # pair -> ms vu par ENet (sans le retard simulé)
var perte_enet := {}                # pair -> fraction vue par ENet
var wrapper: SimulateurReseau
var cible_ip := ""
var cible_port := 0
var est_hote_enveloppe := true
var reconnexion_en_cours := false
var id_avant_perte := 0
var historique_debit: Array = []    # [{t, env, rec, env_pair, rec_pair}] 1 par seconde (borné)
var pic_env := 0.0
var pic_rec := 0.0
var nom_joueur_local := ""

var _seq := 0
var _t_ping := 0.0
var _t_mesure := 0.0
var _t_log := 0.0
var _prec: Dictionary = {}
var _marque: Dictionary = {}
var _etat_attente := {}

# ------------------------------------------------------------------------------------------------ installation

static func _arbre() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func R() -> Node:
	var a := _arbre()
	return a.root.get_node_or_null("Reseau") if a != null else null

static func instance() -> Resilience:
	var a := _arbre()
	return a.root.get_node_or_null("Resilience") as Resilience if a != null else null

## Appelé par le transport ENet : enveloppe le pair (simulateur + compteurs), pose les temporisations, crée le nœud. Renvoie le pair à utiliser.
static func preparer(pair: MultiplayerPeer, hote: bool, ip: String, port: int) -> MultiplayerPeer:
	var w := SimulateurReseau.envelopper(pair)
	var a := _arbre()
	if a == null:
		return w
	var n := instance()
	if n == null:
		n = Resilience.new()
		n.name = "Resilience"
		a.root.add_child.call_deferred(n)
	n.wrapper = w
	n.est_hote_enveloppe = hote
	if not hote:
		n.cible_ip = ip
		n.cible_port = port
	n._prec = w.compteurs()
	w.peer_connected.connect(n._pair_pret.bind(w))
	return w

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--debug-reseau" or a == "--metriques":
			afficher_metriques = true
	var r := R()
	if r != null:
		if r.has_signal("hote_perdu"):
			r.hote_perdu.connect(_sur_hote_perdu)
		r.joueur_deconnecte.connect(_sur_joueur_parti)
		r.connexion_reussie.connect(func() -> void: _etat_attente["connecte"] = true)
		r.connexion_echouee.connect(func() -> void: _etat_attente["echec"] = true)
		r.abonner("res_reprise", _sur_reprise)
	set_process(true)

func _pair_pret(id: int, w: SimulateurReseau) -> void:
	derniere_reponse[id] = _maintenant()
	pings_envoyes[id] = 0
	pongs_recus[id] = 0
	pings_vol.erase(id)
	pings_expires.erase(id)
	var p: Object = w.pair_enet(id)
	if p != null and p.has_method("set_timeout"):
		p.call("set_timeout", timeout_enet.x, timeout_enet.y, timeout_enet.z)

static func _maintenant() -> float:
	return Time.get_ticks_msec() / 1000.0

# ------------------------------------------------------------------------------------------------ boucle : ping, mesures, surveillance

func _process(dt: float) -> void:
	var r := R()
	if r == null:
		return
	if r.est_en_ligne():
		id_avant_perte = r.mon_id()
	if not r.est_en_ligne() or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_t_ping += dt
	if _t_ping >= periode_ping:
		_t_ping = 0.0
		_seq += 1
		for p in multiplayer.get_peers():
			pings_envoyes[p] = int(pings_envoyes.get(p, 0)) + 1
			if not pings_vol.has(p):
				pings_vol[p] = {}
			(pings_vol[p] as Dictionary)[_seq] = _maintenant()
			_ping.rpc_id(p, _seq, Time.get_ticks_usec())
	_t_mesure += dt
	if _t_mesure >= 1.0:
		_mesurer(_t_mesure)
		_t_mesure = 0.0
		_surveiller(r)
	if afficher_metriques:
		_t_log += dt
		if _t_log >= 5.0:
			_t_log = 0.0
			print(resume())

@rpc("any_peer", "call_remote", "unreliable")
func _ping(seq: int, t_usec: int) -> void:
	var de := multiplayer.get_remote_sender_id()
	derniere_reponse[de] = _maintenant()
	_pong.rpc_id(de, seq, t_usec)

@rpc("any_peer", "call_remote", "unreliable")
func _pong(seq: int, t_usec: int) -> void:
	var de := multiplayer.get_remote_sender_id()
	if pings_vol.has(de):
		(pings_vol[de] as Dictionary).erase(seq)
	derniere_reponse[de] = _maintenant()
	pongs_recus[de] = int(pongs_recus.get(de, 0)) + 1
	var ms := (Time.get_ticks_usec() - t_usec) / 1000.0
	rtt[de] = ms if not rtt.has(de) else lerpf(float(rtt[de]), ms, 0.25)
	rtt_min[de] = minf(float(rtt_min.get(de, 1.0e9)), ms)
	rtt_max[de] = maxf(float(rtt_max.get(de, 0.0)), ms)
	rtt_mis_a_jour.emit(de, float(rtt[de]))

func _mesurer(dt: float) -> void:
	var t := _maintenant()
	for p in pings_vol:
		var d: Dictionary = pings_vol[p]
		for q in d.keys():
			if t - float(d[q]) > 2.0:
				d.erase(q)
				pings_expires[p] = int(pings_expires.get(p, 0)) + 1
	if wrapper == null:
		return
	var c := wrapper.compteurs()
	var env := float(int(c["env_octets"]) - int(_prec.get("env_octets", 0))) / dt
	var rec := float(int(c["rec_octets"]) - int(_prec.get("rec_octets", 0))) / dt
	var env_p := {}
	var rec_p := {}
	for p in (c["env_par_pair"] as Dictionary):
		env_p[p] = float(int((c["env_par_pair"] as Dictionary)[p]) - int((_prec.get("env_par_pair", {}) as Dictionary).get(p, 0))) / dt
	for p in (c["rec_par_pair"] as Dictionary):
		rec_p[p] = float(int((c["rec_par_pair"] as Dictionary)[p]) - int((_prec.get("rec_par_pair", {}) as Dictionary).get(p, 0))) / dt
	var pk_env := float(int(c["env_paquets"]) - int(_prec.get("env_paquets", 0))) / dt
	var pk_rec := float(int(c["rec_paquets"]) - int(_prec.get("rec_paquets", 0))) / dt
	_prec = c
	historique_debit.append({"t": _maintenant(), "env": env, "rec": rec, "env_pair": env_p, "rec_pair": rec_p, "pk_env": pk_env, "pk_rec": pk_rec})
	if historique_debit.size() > 600:
		historique_debit.pop_front()
	pic_env = maxf(pic_env, env)
	pic_rec = maxf(pic_rec, rec)
	for p in multiplayer.get_peers():
		var pe: Object = wrapper.pair_enet(p)
		if pe != null:
			rtt_enet[p] = float(pe.call("get_statistic", ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			perte_enet[p] = float(pe.call("get_statistic", ENetPacketPeer.PEER_PACKET_LOSS)) / 65536.0

## Surveillance : un pair qui ne répond plus à rien depuis `silence_max` s est déconnecté ; chez l'invité, la perte de l'hôte est déclarée.
func _surveiller(r: Node) -> void:
	var t := _maintenant()
	if r.est_hote():
		for p in multiplayer.get_peers():
			if t - float(derniere_reponse.get(p, t)) > silence_max:
				derniere_raison = "silence"
				print("[RESEAU] pair %d muet depuis %.0f s : déconnecté" % [p, silence_max])
				multiplayer.multiplayer_peer.disconnect_peer(p, true)
				derniere_reponse.erase(p)
	elif not reconnexion_en_cours and multiplayer.get_peers().has(1):
		if t - float(derniere_reponse.get(1, t)) > silence_max:
			derniere_raison = "silence"
			print("[RESEAU] hôte muet depuis %.0f s : liaison déclarée perdue" % silence_max)
			r.call("_serveur_perdu")

# ------------------------------------------------------------------------------------------------ mesures : lecture

## Moyenne du débit entre deux appels de marquer() / bilan() (octets/s, charge utile ; « filaire » = + SURCOUT_PAQUET par paquet).
func marquer() -> void:
	_marque = {"t": _maintenant(), "c": wrapper.compteurs() if wrapper != null else {}}

func bilan() -> Dictionary:
	if wrapper == null or _marque.is_empty():
		return {}
	var dt := maxf(_maintenant() - float(_marque["t"]), 0.001)
	var c0: Dictionary = _marque["c"]
	var c1 := wrapper.compteurs()
	var env := float(int(c1["env_octets"]) - int(c0["env_octets"]))
	var rec := float(int(c1["rec_octets"]) - int(c0["rec_octets"]))
	var pk_env := int(c1["env_paquets"]) - int(c0["env_paquets"])
	var pk_rec := int(c1["rec_paquets"]) - int(c0["rec_paquets"])
	var par_pair := {}
	for p in (c1["env_par_pair"] as Dictionary):
		par_pair[p] = float(int((c1["env_par_pair"] as Dictionary)[p]) - int((c0["env_par_pair"] as Dictionary).get(p, 0))) / dt
	return {"duree": dt, "env_o_s": env / dt, "rec_o_s": rec / dt, "env_filaire_o_s": (env + pk_env * SURCOUT_PAQUET) / dt,
		"rec_filaire_o_s": (rec + pk_rec * SURCOUT_PAQUET) / dt, "pk_env_s": pk_env / dt, "pk_rec_s": pk_rec / dt, "env_par_pair_o_s": par_pair,
		"perdus_sim": int(c1["perdus_sim"]) - int(c0["perdus_sim"]), "retransmis_sim": int(c1["retransmis_sim"]) - int(c0["retransmis_sim"])}

## Perte mesurée par les pings (aller + retour) d'un pair : pings restés sans réponse plus de 2 s / pings jugés (réponses + expirés).
## Un aller-retour sur un lien à p % de perte par sens perd 1 - (1 - p)² des pings.
func perte_mesuree(pair: int) -> float:
	var perdus := int(pings_expires.get(pair, 0))
	var repondus := int(pongs_recus.get(pair, 0))
	if perdus + repondus <= 0:
		return 0.0
	return float(perdus) / float(perdus + repondus)

func resume() -> String:
	var s := "[RESEAU] "
	for p in rtt:
		s += "rtt(%d)=%.0f ms (min %.0f max %.0f, ENet %.0f) perte_ping=%.0f%% " % [p, float(rtt[p]), float(rtt_min[p]), float(rtt_max[p]), float(rtt_enet.get(p, 0.0)), perte_mesuree(p) * 100.0]
	if not historique_debit.is_empty():
		var h: Dictionary = historique_debit[-1]
		s += "env=%.1f Ko/s rec=%.1f Ko/s (pic %.1f / %.1f)" % [float(h["env"]) / 1024.0, float(h["rec"]) / 1024.0, pic_env / 1024.0, pic_rec / 1024.0]
	if wrapper != null:
		s += " sim_perdus=%d retransmis=%d" % [wrapper.perdus_sim, wrapper.retransmis_sim]
	return s

# ------------------------------------------------------------------------------------------------ HÔTE : départ d'un invité

func _sur_joueur_parti(id: int) -> void:
	var r := R()
	derniere_reponse.erase(id)
	rtt.erase(id)
	if r == null or id == 1:
		return
	if r.est_hote():
		_nettoyer_depart.call_deferred(id)

## Menace du parti retirée des ennemis, cible rechoisie, projectiles / butin laissés en place (appartiennent au monde de l'hôte).
func _nettoyer_depart(id: int) -> void:
	var a := _arbre()
	if a == null:
		return
	var n := 0
	for ident in CombatCoop.ids():
		var e := CombatCoop.ennemi(String(ident))
		if e == null or not is_instance_valid(e):
			continue
		var m: Dictionary = e.get_meta("coop_menace", {})
		if m.erase(id):
			e.set_meta("coop_menace", m)
		var cible: Variant = e.get("joueur")
		if not (cible is Node) or not is_instance_valid(cible) or not (cible as Node).is_inside_tree() or CombatCoop.pair_de(cible) == 0:
			e.set_meta("coop_t_cible", 0.0)
			var loc := CombatCoop.joueur_local()
			if loc != null:
				e.set("joueur", loc)
				var ls: Variant = e.get("lanceur_sorts")
				if ls != null:
					ls.set("cible_joueur", loc)
			n += 1
	derniere_raison = "parti"
	joueur_parti.emit(id)
	message.emit("Un compagnon a quitté la partie.")
	if afficher_metriques:
		print("[RESEAU] joueur %d parti : %d ennemi(s) retargeté(s)" % [id, n])

# ------------------------------------------------------------------------------------------------ INVITÉ : hôte perdu, reconnexion

func _sur_hote_perdu(raison: String) -> void:
	if derniere_raison == "":
		derniere_raison = raison
	var r := R()
	if r == null or reconnexion_en_cours:
		return
	if geler_ennemis:
		_geler_ennemis(true)
	nom_joueur_local = String(r.registre.infos(id_avant_perte).get("nom", nom_joueur_local))
	if not auto_reconnexion or cible_ip == "" or est_hote_enveloppe:
		_abandonner.call_deferred("Connexion à l'hôte perdue.")
		return
	_reconnecter.call_deferred(id_avant_perte)

## Fige (ou libère) l'IA des ennemis enregistrés chez cet invité. Hôte perdu = Reseau repasse en solo : sans cela chaque marionnette redevient une IA locale
## au milieu d'un état répliqué (ex. draugr en ATTAQUE sans `_attaque` : erreurs de script à chaque image).
func _geler_ennemis(geler: bool) -> void:
	for ident in CombatCoop.ids():
		var e := CombatCoop.ennemi(String(ident))
		if e != null and is_instance_valid(e):
			e.set_physics_process(not geler)

func _reconnecter(ancien_id: int) -> void:
	var r := R()
	reconnexion_en_cours = true
	message.emit("Connexion à l'hôte perdue. Tentative de reconnexion…")
	for n in range(1, ESSAIS_MAX + 1):
		reconnexion_tentative.emit(n, ESSAIS_MAX)
		await get_tree().create_timer(pause_essais).timeout
		_etat_attente = {}
		if r.rejoindre(cible_ip, cible_port) != OK:
			continue
		var t0 := _maintenant()
		var conf := -1.0
		var ok := false
		while _maintenant() - t0 < delai_confirmation + 4.0:
			await get_tree().process_frame
			if _etat_attente.has("echec"):
				break
			if _etat_attente.has("connecte"):
				if conf < 0.0:
					conf = _maintenant()
					pongs_recus[1] = 0
					_ping.rpc_id(1, 0, Time.get_ticks_usec())
				if int(pongs_recus.get(1, 0)) > 0:
					ok = true
					break
				if _maintenant() - conf > delai_confirmation:
					break
		if ok:
			reconnexion_en_cours = false
			derniere_raison = ""
			if geler_ennemis:
				_geler_ennemis(false)   # marionnettes de nouveau (elles ne simulent rien : voir CombatCoop)
			var nouvel := int(r.call("mon_id"))
			r.envoyer_evenement("res_reprise", nouvel, {"ancien": ancien_id, "nom": nom_joueur_local})
			message.emit("Reconnecté à l'hôte.")
			reconnexion_reussie.emit(ancien_id, nouvel)
			return
		r.deconnecter()   # essai raté : on repart d'un état propre (ne ré-émet pas hote_perdu)
	_abandonner("Impossible de rejoindre l'hôte après %d essais. Retour au titre." % ESSAIS_MAX)

func _abandonner(texte: String) -> void:
	reconnexion_en_cours = false
	message_en_attente = texte
	message.emit(texte)
	reconnexion_abandonnee.emit(texte)
	retour_titre_demande.emit(texte)
	# Retour au titre = relance du processus (Jeu.relancer : le monde ne peut pas être recréé dans le même processus). Jamais en mode outil :
	# un test ou une capture (arguments utilisateur / --script) garde sa scène et lit le signal.
	if retour_titre_auto and not Jeu.mode_outil():
		var f := FileAccess.open(FICHIER_MESSAGE, FileAccess.WRITE)
		if f != null:
			f.store_string(texte)
			f.close()
		Jeu.relancer()

## À appeler par l'écran titre au démarrage : renvoie (et efface) le message laissé par un retour forcé (« Impossible de rejoindre l'hôte… »), "" sinon.
static func message_titre() -> String:
	if not FileAccess.file_exists(FICHIER_MESSAGE):
		return ""
	var t := FileAccess.get_file_as_string(FICHIER_MESSAGE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER_MESSAGE))
	return t

## HÔTE : un invité reconnecté annonce qui il était. L'ancien avatar (peut-être encore là si ENet n'a pas encore expiré) est débranché,
## les infos du registre (nom…) sont reportées sur le nouvel identifiant.
func _sur_reprise(expediteur: int, _id: Variant, d: Variant) -> void:
	var r := R()
	if r == null or not r.est_hote() or not (d is Dictionary):
		return
	var ancien := int(d.get("ancien", 0))
	if ancien > 1 and ancien != expediteur:
		var infos: Dictionary = r.registre.infos(ancien)
		for k in infos:
			r.registre.definir_info(expediteur, k, infos[k])
		if multiplayer.get_peers().has(ancien):
			multiplayer.multiplayer_peer.disconnect_peer(ancien, true)
	if d.has("nom") and String(d["nom"]) != "":
		r.registre.definir_info(expediteur, "nom", String(d["nom"]))

# ------------------------------------------------------------------------------------------------ compensation de latence (CombatCoop)

static var _ts_prec := {}    # clé "pair|ennemi" -> horodatage émetteur du dernier coup accepté
static var _arr_prec := {}   # idem -> instant d'arrivée du dernier coup accepté (anti-triche)
static var _recents := {}    # idem -> arrivées des coups acceptés sur la dernière seconde
static var refus_cadence := 0
static var refus_portee := 0

## Portée de validation supplémentaire (m) : l'avatar vu par l'hôte est en retard de (RTT/2 + 100 ms d'interpolation), l'ennemi vu par l'invité de même.
static func tolerance_portee(pair: int) -> float:
	if not compensation:
		return 0.0
	var n := instance()
	var ms := float(n.rtt.get(pair, 0.0)) if n != null else 0.0
	return minf((VITESSE_JOUEUR + VITESSE_ENNEMI) * (ms * 0.0005 + 0.1), TOLERANCE_MAX_M)

## Cadence minimale entre deux coups d'un même invité sur le même ennemi. L'ARRIVÉE ne mesure pas la cadence de l'émetteur (un paquet perdu puis
## retransmis retient les suivants, qui arrivent ensemble) : si le coup porte l'horodatage « t » de l'émetteur, on compare ces horodatages. Garde-fou : au plus
## 12 coups acceptés par seconde et par cible.
static func cadence_trop_rapide(cle: String, d: Variant, arrivee_ms: int, cadence_ms: int) -> bool:
	var ts: Variant = (d as Dictionary).get("t") if d is Dictionary else null
	var trop := false
	if not compensation or ts == null:
		trop = arrivee_ms - int(_arr_prec.get(cle, -100000)) < cadence_ms
	else:
		trop = int(ts) - int(_ts_prec.get(cle, -100000)) < cadence_ms
		var l: Array = _recents.get(cle, [])
		while not l.is_empty() and arrivee_ms - int(l[0]) > 1000:
			l.pop_front()
		if l.size() >= 12:
			trop = true
		if not trop:
			l.append(arrivee_ms)
		_recents[cle] = l
	if trop:
		refus_cadence += 1
	else:
		_arr_prec[cle] = arrivee_ms
		if ts != null:
			_ts_prec[cle] = int(ts)
	return trop
