extends Node
## Autoload « Replicateur » : réplication des entités (lot 2a). Voir docs/reseau_lot2.md.
## L'hôte envoie l'état binaire des entités enregistrées (par identifiant stable, par pertinence de distance, ~15 Hz,
## unreliable_ordered) ; l'invité les applique en marionnettes, interpolées ~100 ms en retard. Hors ligne : inerte.

const PERIODE := 1.0 / 15.0
const PERTINENCE_DEFAUT := 90.0
const DELAI_INTERP := 0.1
const RAPPEL := 1.0            # un état inchangé est renvoyé au plus toutes les RAPPEL s
const PAQUET_MAX := 3000       # octets (approx.) par RPC AVANT compression ZSTD (≈ 1000 après) : de gros lots se compriment mieux (clés répétées)
const TAMPON_MAX := 30
const DIST_MI := 40.0          # au-delà : un état sur 2 (7,5 Hz) ; au-delà de DIST_BAS : un sur 4 (le tampon d'interpolation lisse ces entités lointaines)
const DIST_BAS := 70.0
const PAS_POS := 1.0 / 64.0    # quantification des positions et des réels (multiples de 2^-n : exacts en float32, 4 octets, états inchangés détectés)
const PAS_REEL := 1.0 / 128.0

var _ent := {}      # id -> {noeud, four, appl, pert}
var _tampons := {}  # id -> Array [t, etat]   (invité)
var _envoye := {}   # pair -> {id: [octets, t]}   (hôte)
var _acc := 0.0
var _tick := 0

func _ready() -> void:
	Reseau.joueur_connecte.connect(func(_id: int) -> void: _envoye.erase(_id))
	Reseau.joueur_deconnecte.connect(func(_id: int) -> void: _envoye.erase(_id))

# ---------- API ----------

func enregistrer(id: Variant, noeud: Node, fournisseur: Callable, appliquer: Callable, pertinence_m: float = PERTINENCE_DEFAUT) -> void:
	_ent[id] = {"noeud": noeud, "four": fournisseur, "appl": appliquer, "pert": pertinence_m}
	_tampons.erase(id)

func retirer(id: Variant) -> void:
	_ent.erase(id)
	_tampons.erase(id)
	for p in _envoye:
		(_envoye[p] as Dictionary).erase(id)

func est_enregistre(id: Variant) -> bool:
	return _ent.has(id)

## Vrai chez un invité : l'entité y est une marionnette (IA coupée).
func est_marionnette() -> bool:
	return Reseau.est_en_ligne() and not Reseau.est_hote()

## Hôte : l'entité `id` est-elle dans la zone de pertinence du pair ?
func est_pertinent(id: Variant, pair: int) -> bool:
	var e: Dictionary = _ent.get(id, {})
	return not e.is_empty() and _pertinent(e, _pos_pair(pair))

## Évènement ponctuel : appliqué en local (si `local`) puis envoyé (Reseau.envoyer_evenement est call_remote).
func diffuser(type: String, id: Variant = 0, donnees: Variant = null, vers: int = 0, local: bool = true) -> void:
	if local:
		Reseau.emettre_local(type, id, donnees)
	Reseau.envoyer_evenement(type, id, donnees, vers)

# ---------- hôte : envoi ----------

func _pos_pair(pair: int) -> Variant:
	var n := Reseau.registre.noeud(pair)
	return (n as Node3D).global_position if n is Node3D else null

func _pertinent(e: Dictionary, pos: Variant) -> bool:
	if pos == null or float(e["pert"]) <= 0.0 or not (e["noeud"] is Node3D):
		return true
	return ((e["noeud"] as Node3D).global_position - (pos as Vector3)).length() <= float(e["pert"])

func _physics_process(dt: float) -> void:
	if not Reseau.est_en_ligne() or not Reseau.est_hote():
		return
	var pairs := multiplayer.get_peers()
	if pairs.is_empty():
		return
	_acc += dt
	if _acc < PERIODE:
		return
	_acc = 0.0
	_tick += 1
	var maintenant := Time.get_ticks_msec() / 1000.0
	var octets := {}   # id -> PackedByteArray (encodé une fois par tick)
	# opti 2026-11-20 (physique_reseau_exe) : n'encoder QUE les entités qu'au moins un pair recevra à ce tick (pertinente pour lui et
	# à sa cadence) ; le reste (PNJ, bêtes et ennemis lointains : la grande majorité du monde) n'appelle plus son fournisseur ni
	# var_to_bytes. Envois identiques octet pour octet. `-- --sans-opti-replication` : toutes les entités encodées (comportement d'avant).
	var tri := not _sans_opti
	var pos_pairs: Array = []
	if tri:
		for pair in pairs:
			pos_pairs.append(_pos_pair(pair))
	for id in _ent.keys():
		var e: Dictionary = _ent[id]
		if not is_instance_valid(e["noeud"]) or not (e["four"] as Callable).is_valid():
			retirer(id)
			continue
		if tri and not _attendu(id, e, pos_pairs):
			continue
		octets[id] = var_to_bytes(_quantifier((e["four"] as Callable).call()))
	for pair in pairs:
		var pos: Variant = _pos_pair(pair)
		var vus: Dictionary = _envoye.get(pair, {})
		_envoye[pair] = vus
		var lot: Array = []
		var taille := 0
		if tri:   # entité non encodée sortie de la zone du pair : oubliée comme avant (renvoyée en entier à son retour)
			for id in vus.keys():
				if not octets.has(id) and _ent.has(id) and not _pertinent(_ent[id], pos):
					vus.erase(id)
		for id in octets:
			if not _pertinent(_ent[id], pos):
				vus.erase(id)
				continue
			var cadence := _cadence(_ent[id], pos)
			if cadence > 1 and (_tick + int(hash(id))) % cadence != 0:
				continue
			var b: PackedByteArray = octets[id]
			var v: Array = vus.get(id, [])
			if not v.is_empty() and v[0] == b and maintenant - float(v[1]) < RAPPEL:
				continue
			vus[id] = [b, maintenant]
			lot.append([id, b])
			taille += b.size() + 12
			if taille >= PAQUET_MAX:
				_recevoir_etats.rpc_id(pair, _emballer(lot))
				lot = []
				taille = 0
		if not lot.is_empty():
			_recevoir_etats.rpc_id(pair, _emballer(lot))

# ---------- invité : réception et application ----------

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _recevoir_etats(donnees: PackedByteArray) -> void:
	var w: Variant = bytes_to_var(donnees)
	var lot: Variant = bytes_to_var((w[1] as PackedByteArray).decompress(int(w[0]), FileAccess.COMPRESSION_ZSTD)) if w is Array else null
	if not (lot is Array):
		return
	var t := Time.get_ticks_msec() / 1000.0
	for it in lot:
		var id: Variant = it[0]
		if not _ent.has(id):
			continue
		var etat: Variant = bytes_to_var(it[1])
		if not _tampons.has(id):
			_tampons[id] = []
		var tp: Array = _tampons[id]
		tp.append([t, etat])
		if tp.size() > TAMPON_MAX:
			tp.pop_front()

func _process(_dt: float) -> void:
	if _tampons.is_empty() or not est_marionnette():
		return
	var t := Time.get_ticks_msec() / 1000.0 - DELAI_INTERP
	for id in _tampons.keys():
		var e: Dictionary = _ent.get(id, {})
		if e.is_empty() or not (e["appl"] as Callable).is_valid():
			continue
		var etat: Variant = _lire(_tampons[id], t)
		if etat is Dictionary:
			(e["appl"] as Callable).call(etat)

func _lire(tp: Array, t: float) -> Variant:
	if tp.is_empty():
		return null
	if t <= tp[0][0]:
		return tp[0][1]
	for i in range(tp.size() - 1):
		var b: Array = tp[i + 1]
		if t <= b[0]:
			var a: Array = tp[i]
			return _melanger(a[1], b[1], clampf((t - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0))
	return tp[-1][1]

## Interpolation générique : float / Vector2 / Vector3 lerp ; clé « a_… » = angle ; le reste = valeur la plus récente.
func _melanger(a: Variant, b: Variant, k: float, angle := false) -> Variant:
	if a is Dictionary and b is Dictionary:
		var r := {}
		for cle in b:
			r[cle] = _melanger((a as Dictionary)[cle], b[cle], k, String(cle).begins_with("a_")) if (a as Dictionary).has(cle) else b[cle]
		return r
	if typeof(a) == typeof(b):
		match typeof(a):
			TYPE_FLOAT:
				return lerp_angle(a, b, k) if angle else lerpf(a, b, k)
			TYPE_VECTOR2, TYPE_VECTOR3:
				return a.lerp(b, k)
	return b

func _emballer(lot: Array) -> PackedByteArray:
	var b := var_to_bytes(lot)
	return var_to_bytes([b.size(), b.compress(FileAccess.COMPRESSION_ZSTD)])

## Réduit la précision (sans effet visible) : positions au 1/64 m, réels au 1/128. Les valeurs restent exactes en float32 (4 octets au lieu de 8)
## et l'état d'une entité qui ne bouge plus est identique d'un tick à l'autre (donc non renvoyé avant RAPPEL).
func _quantifier(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = (v as Dictionary).duplicate()
		for k in d:
			var x: Variant = d[k]
			if x is Vector3:
				d[k] = (x as Vector3).snappedf(PAS_POS)
			elif x is float:
				d[k] = snappedf(x, PAS_REEL)
		return d
	return v

var _sans_opti := "--sans-opti-replication" in OS.get_cmdline_user_args()

## Vrai si au moins un pair (positions `pos_pairs`) recevra l'entité à ce tick : pertinente pour lui et à sa cadence.
func _attendu(id: Variant, e: Dictionary, pos_pairs: Array) -> bool:
	var h := int(hash(id))
	for pos in pos_pairs:
		if _pertinent(e, pos):
			var cadence := _cadence(e, pos)
			if cadence <= 1 or (_tick + h) % cadence == 0:
				return true
	return false

## Un état sur `cadence` pour les entités lointaines du pair.
func _cadence(e: Dictionary, pos: Variant) -> int:
	if pos == null or not (e["noeud"] is Node3D):
		return 1
	var dist := ((e["noeud"] as Node3D).global_position - (pos as Vector3)).length()
	return 4 if dist > DIST_BAS else (2 if dist > DIST_MI else 1)
