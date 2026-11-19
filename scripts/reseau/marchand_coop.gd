class_name MarchandCoop
extends RefCounted
## LOT 5a — commerce en coop. Le STOCK et l'OR de chaque marchand sont uniques (ceux de l'hôte) ; l'argent et le sac sont ceux du joueur LOCAL.
##  - Hôte / solo : Marchand.acheter / vendre inchangés ; après un échange réussi, `diffuser(id)` envoie l'état du marchand aux invités.
##  - Invité : Marchand.acheter_coop / vendre_coop contrôlent ce qu'il peut (pièces, place, ce que le marchand rachète) puis DEMANDENT à
##    l'hôte une quantité (`demander`). L'hôte, seul à toucher au stock, accorde min(demandé, disponible) — le premier arrivé l'obtient — et
##    répond avec l'état à jour ; l'invité règle alors ses pièces et son sac. Un objet unique ne peut donc être obtenu que par un seul.
## Évènements : march_demande (invité -> hôte), march_reponse (hôte -> demandeur), march_etat (hôte -> tous). Instantané « marchands » (Rejoindre).

const EV_DEMANDE := "march_demande"
const EV_REPONSE := "march_reponse"
const EV_ETAT := "march_etat"

static var _pret := false
static var _req := 0
static var _attente := {}      # numéro de demande -> Callable(accorde: int)

static func R() -> Node:
	return PauseCoop.R()

## Invité en ligne : le stock est celui de l'hôte.
static func invite() -> bool:
	var r := R()
	return r != null and r.est_en_ligne() and not r.est_hote()

static func brancher() -> void:
	var r := R()
	if _pret or r == null:
		return
	_pret = true
	r.abonner(EV_DEMANDE, MarchandCoop._sur_demande)
	r.abonner(EV_REPONSE, MarchandCoop._sur_reponse)
	r.abonner(EV_ETAT, MarchandCoop._sur_etat)
	var rj := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Rejoindre")
	if rj != null:
		rj.contributeur("marchands", Callable(MarchandCoop, "exporter"), Callable(MarchandCoop, "importer"))

static func reinitialiser() -> void:
	_attente.clear()
	_req = 0

## Invité : demande à l'hôte `k` exemplaires de `oid` (op « acheter », « vendre » ou « rendre_achat ») au prix unitaire `prix`.
## `rappel.call(accorde)` à la réponse (0 = refusé).
static func demander(op: String, id: String, oid: String, k: int, prix: int, rappel: Callable) -> void:
	brancher()
	_req += 1
	_attente[_req] = rappel
	R().envoyer_evenement(EV_DEMANDE, _req, {"op": op, "id": id, "oid": oid, "k": k, "prix": prix})

## Hôte : envoie l'état du marchand `id` (stock, or, période) à tous les invités.
static func diffuser(id: String) -> void:
	brancher()
	var r := R()
	if r != null and r.est_en_ligne() and r.est_hote():
		r.envoyer_evenement(EV_ETAT, id, _charge(id))
	_rafraichir(id)

static func _charge(id: String) -> Dictionary:
	var e: Dictionary = Marchand.etat(id)
	return {"heures": Marchand.heures, "etat": {"periode": int(e.get("periode", 0)), "or": int(e.get("or", 0)), "stock": (e.get("stock", {}) as Dictionary).duplicate()}}

static func _adopter(id: String, d: Dictionary) -> void:
	Marchand.heures = float(d.get("heures", Marchand.heures))
	var e: Variant = d.get("etat")
	if e is Dictionary:
		var s := {}
		for oid: String in (e.get("stock", {}) as Dictionary):
			if int(e["stock"][oid]) > 0:
				s[oid] = int(e["stock"][oid])
		Marchand.etats[id] = {"periode": int(e.get("periode", 0)), "or": int(e.get("or", 0)), "stock": s}

## La fenêtre de commerce ouverte sur ce marchand se redessine (stock changé par un autre joueur).
static func _rafraichir(id: String) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return
	var m := arbre.get_first_node_in_group(Marchand.GROUPE) as Marchand
	if m != null and m.ouvert and m.id_marchand == id:
		m._remplir()

# ---------------------------------------------------------------------------------------------------- hôte
## Arbitre une demande d'invité : seul l'hôte touche au stock. Renvoie la quantité accordée.
static func arbitrer(op: String, id: String, oid: String, k: int, prix: int) -> int:
	if not Marchand.est_marchand(id) or k <= 0:
		return 0
	var e: Dictionary = Marchand.etat(id)
	var s: Dictionary = e["stock"]
	match op:
		"acheter":
			var accorde := mini(k, int(s.get(oid, 0)))
			if accorde <= 0:
				return 0
			s[oid] = int(s[oid]) - accorde
			if int(s[oid]) <= 0:
				s.erase(oid)
			e["or"] = int(e["or"]) + accorde * prix
			return accorde
		"vendre":
			var accorde2 := mini(k, int(e["or"]) / maxi(1, prix))
			if accorde2 <= 0:
				return 0
			e["or"] = int(e["or"]) - accorde2 * prix
			s[oid] = int(s.get(oid, 0)) + accorde2
			return accorde2
		"rendre_achat":          # l'invité n'a finalement pas pu payer : le stock revient
			s[oid] = int(s.get(oid, 0)) + k
			e["or"] = maxi(0, int(e["or"]) - k * prix)
			return k
	return 0

static func _sur_demande(exp: int, req: Variant, d: Variant) -> void:
	var r := R()
	if r == null or not r.est_hote() or not (d is Dictionary):
		return
	var id := String(d["id"])
	var accorde := arbitrer(String(d["op"]), id, String(d["oid"]), int(d["k"]), int(d["prix"]))
	var rep := _charge(id)
	rep["k"] = accorde
	rep["id"] = id
	r.envoyer_evenement(EV_REPONSE, req, rep, exp)
	diffuser(id)

# ---------------------------------------------------------------------------------------------------- invité
static func _sur_reponse(exp: int, req: Variant, d: Variant) -> void:
	if exp != 1 or not (d is Dictionary):
		return
	var rappel: Variant = _attente.get(req)
	_attente.erase(req)
	if rappel is Callable and (rappel as Callable).is_valid():
		# l'état à jour d'abord (sinon la liste affichée garde l'ancien stock), puis le règlement chez l'invité
		_adopter(String(d.get("id", "")), d)
		(rappel as Callable).call(int(d.get("k", 0)))

static func _sur_etat(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or R() == null or R().est_hote() or not (d is Dictionary):
		return
	_adopter(String(id), d)
	_rafraichir(String(id))

## Instantané « rejoindre » : l'état de tous les marchands de l'hôte.
static func exporter() -> Dictionary:
	var r := {}
	for id: String in Marchand.etats:
		r[id] = _charge(id)
	return r

static func importer(d: Dictionary) -> void:
	var r := R()
	if r != null and r.est_hote():
		return
	for id: String in d:
		if d[id] is Dictionary:
			_adopter(id, d[id])

## Monde quitté : lâche les rappels statiques (lambdas du monde), libérés sinon après leur script à la sortie (plantage).
static func vider_rappels() -> void:
	_attente.clear()
