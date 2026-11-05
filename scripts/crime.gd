class_name Crime
extends Node
## CRIME ET JUSTICE à la Skyrim (retours exe 5) : un nœud du monde (groupe « crime »), branché par UNE ligne dans monde._villageois()
## (Crime.peupler(self)), après les gardes et Vie. Les autres systèmes l'appellent par son API publique (Crime.trouver(n)) :
##   signaler_vol(objet, proprietaire, position) -> bool       un objet possédé vient d'être pris (vrai = vu)
##   signaler_intrusion(lieu, proprietaire) -> bool             le joueur entre (ou crochète) là où il n'a rien à faire
##   signaler_agression(victime) -> String                      un coup sur un PNJ du village (« avertissement », « agression », « combat »)
##   signaler_meurtre(victime) -> bool                          un PNJ du village tué par le joueur
##   demander_crochetage(cible) -> bool                         porte ou coffre à meta « verrou » 0-4 et « proprietaire » : mini-jeu
## TÉMOINS : PNJ éveillés du village (villageois, habitants, gardes) à portée de vue (R_VUE, moitié de nuit sans torche, moitié si le joueur
## est accroupi), dans leur cône de vision (CONE, sauf à moins de R_OUIE : ils entendent) et en ligne de vue (rayon sur le décor).
## Sans témoin, rien n'est détecté. Une prime par juridiction (Skarnholt) et une réputation (0-100) ; la prime baisse avec les heures de jeu.
## RÉACTIONS : le propriétaire volé sous ses yeux l'attaque (sauf les frêles, qui fuient et appellent la garde) ; un témoin civil crie et
## appelle la garde ; un garde témoin vient ARRÊTER le joueur (PnjCombat mode « arrete » : amende, geôle ou résistance). Frapper un garde
## (ou résister, ou tuer devant témoin) rend TOUS les gardes de la juridiction hostiles : ceux qui entendent l'alerte (R_VOIX) tout de
## suite, les autres DELAI_LOIN s plus tard ; ils accourent. Un coup isolé sur un PNJ (frappe perdue) = avertissement, pas une agression.
## Un PNJ frappé devient un PnjCombat (scripts/pnj_combat.gd : socle EnnemiBase, mêmes dégâts, sang et mort que les ennemis) qui rend
## son corps au PNJ d'origine une fois calmé. Sauvegarde : clé « crime » (primes, réputation, hostilité, objets volés, PNJ tués).

signal prime_change(juridiction: String, prime: float)
signal crime_commis(type: String, juridiction: String, temoins: int)
signal crochetage_fini(cible: Node3D, reussi: bool)

const GROUPE := "crime"
const DONNEES := "res://data/crime.json"
const JURIDICTION := "skarnholt"
const NOM_JURIDICTION := "Skarnholt"
const PRIMES := {"vol": 5.0, "intrusion": 5.0, "crochetage": 5.0, "agression": 40.0, "meurtre": 1000.0}
const PART_VALEUR := 0.5            # vol : prime = max(5, valeur × 0,5)
const PERTE_REPUTATION := {"vol": 2.0, "intrusion": 1.0, "crochetage": 1.0, "agression": 8.0, "meurtre": 30.0}
const R_VUE := 20.0                 # m : un PNJ voit le joueur jusqu'à 20 m de jour
const NUIT_VUE := 0.5               # de nuit, sans torche allumée : moitié
const ACCROUPI_VUE := 0.5           # joueur accroupi (s'il le peut) : moitié
const R_OUIE := 2.5                 # m : en deçà, il entend (pas de cône)
const CONE := 70.0                  # demi-angle du cône de vision (degrés)
const R_VOIX := 24.0                # m : un garde à portée de voix de l'alerte est prévenu tout de suite
const DELAI_LOIN := Vector2(2.5, 6.0)   # s : les gardes hors de portée de voix sont prévenus plus tard (selon la distance)
const MEMOIRE_AVERT := 30.0         # s : un 2e coup sur le même PNJ dans ce délai = agression
const MEMOIRE_AGRESSION := 90.0     # s : une même victime n'ajoute pas deux fois la prime d'agression
const BAISSE_HEURE := 0.04          # la prime perd 4 % par heure de jeu (au moins BAISSE_MIN)
const BAISSE_MIN := 0.5
const SE_RENDRE := 8.0              # s sans frapper personne : un garde hostile proche propose de se rendre
const DIST_VUE_ARRET := 14.0        # m : un garde qui reconnaît le joueur recherché vient l'arrêter
const PROCHES := 16.0               # m : rayon des proches d'une victime
## Costauds (attaquent plutôt que fuir) et frêles (fuient même volés sous leurs yeux), par id ou type de PNJ.
const COSTAUDS := ["forgeron", "garde", "chasseuse", "paysan", "chasseur", "chasseresse", "eirik"]
const FRELES := ["volva", "ancienne", "paysanne"]

var monde: Node3D
var joueur: CharacterBody3D
var dialogue: Control
var hud: Control
var primes := {}                    # juridiction -> prime (pièces)
var reputation := {}                # juridiction -> 0..100 (50 au départ)
var hostile := {}                   # juridiction -> vrai : la garde attaque à vue
var voles := {}                     # id d'objet -> nombre d'objets volés dans le sac (confisqués à l'arrestation)
var morts: Array = []               # clés des PNJ tués (« garde:so », « pnj:forgeron ») : ils restent morts
var combattants: Array = []         # PnjCombat actifs
var dernier := {}                   # dernier crime ou avertissement (tests) : {type, temoins, prime}
var avertissements := 0
var crimes_vus := 0
var derniere_vue_bloquee: Node = null   # ce qui a caché le joueur au dernier regard bloqué (débogage)
var crochetage: Crochetage
var treve := false                  # dialogue d'arrestation ouvert : les combattants suspendent leurs coups
var arrestation: Node = null        # PnjCombat qui propose l'arrestation
var _textes := {}
var _avert := {}                    # instance_id -> horloge du dernier coup isolé
var _agresses := {}                 # instance_id -> horloge de l'agression comptée
var _alertes: Array = []            # [{"t": horloge, "n": garde}] : gardes à prévenir plus tard
var _horloge := 0.0
var _heure_prec := -1.0
var _dernier_coup := -1.0e9         # horloge du dernier coup porté par le joueur sur un PNJ
var _derniere_resistance := -1.0e9
var _t_ronde := 0.0
var _loin_t := 0.0

static func trouver(n: Node) -> Crime:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as Crime

static func peupler(monde_: Node3D) -> Crime:
	if monde_.get("village") == null:
		return null
	var c := Crime.new()
	c.name = "Crime"
	c.monde = monde_
	c.joueur = monde_.joueur
	c.dialogue = monde_.dialogue
	c.hud = monde_.hud
	monde_.add_child(c)
	return c

func _ready() -> void:
	add_to_group(GROUPE)
	if FileAccess.file_exists(DONNEES):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
		if j is Dictionary:
			_textes = j
	crochetage = Crochetage.new()
	crochetage.crime = self
	crochetage.joueur = joueur
	add_child(crochetage)
	DemoCrime.poser(self)       # coffres verrouillés du village (et, avec --demo-crime, une porte verrouillée)
	if joueur != null and joueur.has_signal("deces"):
		joueur.deces.connect(apaiser_tous)    # mort du joueur : chacun retourne à sa place (la prime et l'hostilité restent)

# ======================================================================================================== API publique

## Un objet possédé (par `proprietaire` : id de PNJ ou nom) vient d'être pris à `position`. Vrai si quelqu'un l'a vu.
## L'objet pris est marqué volé dans tous les cas (confisqué à l'arrestation).
func signaler_vol(objet: Node3D, proprietaire: String, position: Vector3) -> bool:
	var id := _id_objet(objet)
	var n := 1
	if objet != null and objet.get("nombre") != null:
		n = maxi(1, int(objet.get("nombre")))
	elif objet != null and objet.has_meta("nombre"):
		n = maxi(1, int(objet.get_meta("nombre")))
	if id != "":
		voles[id] = int(voles.get(id, 0)) + n
	var temoins := temoins_de(joueur.global_position if joueur != null else position)
	if temoins.is_empty():
		_noter("vol", 0, 0.0)
		return false
	var valeur := float(Inventaire.objet(id).get("valeur", 10)) * n if id != "" else 10.0
	var p := maxf(PRIMES["vol"], ceilf(valeur * PART_VALEUR))
	_commettre("vol", p, temoins)
	var proprio := _pnj_par_id(proprietaire)
	var gardes_vus: Array = []
	for t: Node3D in temoins:
		if est_garde(t):
			gardes_vus.append(t)
		elif t == proprio:
			_dire(t, "vol_proprietaire")
			if _frele(t):
				_fuir(t)
			else:
				convertir(t, "hostile")       # le propriétaire volé sous ses yeux attaque
		else:
			_dire(t, "vol_temoin")
			_fuir(t)
	for g: Node3D in gardes_vus:
		_dire(g, "vol_garde")
	_poursuivre(gardes_vus, position)
	return true

## Le joueur est entré (ou crochète) là où `proprietaire` ne le veut pas. Vrai si quelqu'un l'a vu.
func signaler_intrusion(lieu: Node3D, proprietaire: String) -> bool:
	return _intrusion(lieu, proprietaire, "intrusion")

## Coup du joueur sur un PNJ du village. « avertissement » (coup isolé : frappe perdue), « agression » (prime, réactions), « combat »
## (déjà en combat ou déjà compté), « » (rien à faire).
func signaler_agression(victime: Node) -> String:
	if victime == null or not is_instance_valid(victime):
		return ""
	_dernier_coup = _horloge
	var c := combattant_de(victime)
	var cible: Node3D = (c if c != null else victime) as Node3D
	if c != null and c.est_mort:
		return ""
	if c != null and c.mode == "hostile":
		return "combat"            # il se bat déjà : chaque coup n'est pas un nouveau crime
	var iid := _cle_instance(victime)
	if _horloge - float(_agresses.get(iid, -1.0e9)) < MEMOIRE_AGRESSION:
		_reagir_victime(cible)
		return "combat"
	var en_service := c != null and c.mode == "arrete"     # frapper le garde qui t'arrête n'a rien d'accidentel
	if not en_service and _horloge - float(_avert.get(iid, -1.0e9)) > MEMOIRE_AVERT:
		_avert[iid] = _horloge
		avertissements += 1
		_dire(cible, "avertissement")
		dernier = {"type": "avertissement", "temoins": 0, "prime": 0.0}
		return "avertissement"
	_agresses[iid] = _horloge
	var temoins := temoins_de(cible.global_position)
	if not temoins.has(cible):
		temoins.append(cible)
	_commettre("agression", PRIMES["agression"], temoins)
	if est_garde(cible):
		_dire(cible, "garde_hostile")
		guerre(cible.global_position, temoins)
		return "agression"
	_dire(cible, "agression_victime")
	_reagir_victime(cible)
	var gardes_vus: Array = []
	for t: Node3D in temoins:
		if t == cible:
			continue
		if est_garde(t):
			gardes_vus.append(t)
		elif t.global_position.distance_to(cible.global_position) < PROCHES and not _frele(t):
			convertir(t, "hostile")           # un proche costaud prend sa défense
		else:
			_dire(t, "agression_temoin")
			_fuir(t)
	_poursuivre(gardes_vus, cible.global_position)
	return "agression"

## Coup du joueur (lame, sort) reçu par un PNJ du village (garde_village / villageois.recevoir_coup) : avertissement sans dégâts (il
## bronche), sinon le coup passe au PnjCombat qui a pris son corps (dégâts, sang, mort).
func coup_sur_pnj(p: Node3D, degats: float, origine: Vector3, puissant: bool, info: Dictionary) -> String:
	var r := signaler_agression(p)
	var c := combattant_de(p)
	if r == "avertissement":
		degats = 0.0
	if c != null and r != "avertissement":
		return c.recevoir_coup(degats, origine, puissant, info)
	if r == "avertissement":
		var a: AnimationPlayer = p.get("anim")
		if a != null and a.has_animation("Hit_Chest"):
			var avant := String(a.current_animation)
			a.play("Hit_Chest", 0.05)
			a.queue(avant if avant != "" and avant != "Hit_Chest" else "Idle")
		return "bloque" if est_garde(p) else "touche"     # le garde pare de son bouclier ; le civil encaisse sans mal
	return ""

## Un PNJ du village tué par le joueur. Vrai si le meurtre a été vu (prime, toute la garde hostile).
func signaler_meurtre(victime: Node) -> bool:
	if victime == null:
		return false
	var cle := cle_pnj(victime)
	if cle != "" and not morts.has(cle):
		morts.append(cle)
	var pos: Vector3 = (victime as Node3D).global_position if victime is Node3D else joueur.global_position
	var temoins := temoins_de(pos)
	temoins.erase(victime)
	if victime is PnjCombat:
		temoins.erase((victime as PnjCombat).pnj)
	if temoins.is_empty():
		_noter("meurtre", 0, 0.0)
		return false
	_commettre("meurtre", PRIMES["meurtre"], temoins)
	for t: Node3D in temoins:
		_dire(t, "meurtre" if est_garde(t) else "agression_temoin")
		if not est_garde(t):
			_fuir(t)
	guerre(pos, temoins)
	return true

## Porte ou coffre verrouillé (meta « verrou » 1-4, « proprietaire ») : ouvre le mini-jeu de crochetage. Vrai si le mini-jeu s'ouvre
## (ou si ce n'était pas verrouillé : signal émis tout de suite, réussi). Faux sans crochet (avis à l'écran).
func demander_crochetage(cible: Node3D) -> bool:
	if cible == null:
		return false
	var verrou := int(cible.get_meta("verrou", 0))
	if verrou <= 0:
		crochetage_fini.emit(cible, true)
		return true
	if joueur.inventaire.nombre("crochet") <= 0:
		_avis("Il te faut un crochet (forge de Brodd).")
		return false
	if not crochetage.ouvrir(cible, verrou):
		return false
	# crocheter sous les yeux de quelqu'un = intrusion (vue au premier geste)
	_intrusion(cible, String(cible.get_meta("proprietaire", "")), "crochetage")
	return true

# ======================================================================================================== prime, réputation

func prime(juridiction := JURIDICTION) -> float:
	return float(primes.get(juridiction, 0.0))

func reputation_de(juridiction := JURIDICTION) -> float:
	return float(reputation.get(juridiction, 50.0))

func est_hostile(juridiction := JURIDICTION) -> bool:
	return bool(hostile.get(juridiction, false))

func ajouter_prime(p: float, juridiction := JURIDICTION) -> void:
	primes[juridiction] = maxf(0.0, prime(juridiction) + p)
	prime_change.emit(juridiction, prime(juridiction))

## Prime + réputation + compte rendu du crime (vu par `temoins`).
func _commettre(type: String, p: float, temoins: Array) -> void:
	crimes_vus += 1
	ajouter_prime(p)
	reputation[JURIDICTION] = clampf(reputation_de() - float(PERTE_REPUTATION.get(type, 2.0)), 0.0, 100.0)
	_noter(type, temoins.size(), p)
	_avis("%s vu : prime de %d pièces à %s" % [_nom_crime(type), roundi(prime()), NOM_JURIDICTION])
	crime_commis.emit(type, JURIDICTION, temoins.size())
	var v: Node = monde.get("vie") if monde != null else null
	if v != null and v.has_method("emettre"):
		v.emettre("crime", joueur.global_position, R_VOIX, joueur)     # bus de Vie (les gardes n'écoutent que danger / combat / alarme)

func _noter(type: String, n: int, p: float) -> void:
	dernier = {"type": type, "temoins": n, "prime": p}

func _nom_crime(type: String) -> String:
	return {"vol": "Vol", "intrusion": "Intrusion", "crochetage": "Crochetage", "agression": "Agression", "meurtre": "Meurtre"}.get(type, type)

func _intrusion(lieu: Node3D, proprietaire: String, type: String) -> bool:
	var temoins := temoins_de(joueur.global_position)
	if temoins.is_empty():
		_noter(type, 0, 0.0)
		return false
	_commettre(type, PRIMES[type], temoins)
	var proprio := _pnj_par_id(proprietaire)
	var gardes_vus: Array = []
	for t: Node3D in temoins:
		if est_garde(t):
			gardes_vus.append(t)
		else:
			_dire(t, "crochetage" if type == "crochetage" else "intrusion")
			if t != proprio:
				_fuir(t)
	_poursuivre(gardes_vus, lieu.global_position if lieu != null else joueur.global_position)
	return true

# ======================================================================================================== témoins

## PNJ éveillés du village qui VOIENT `pos` (le joueur, en général) : portée (jour / nuit / accroupi), cône de vision, ligne de vue.
func temoins_de(pos: Vector3) -> Array:
	var r: Array = []
	for n: Node3D in pnj_actifs():
		if voit(n, pos):
			r.append(n)
	return r

## PNJ du village qui peuvent témoigner ou réagir : villageois, habitants, gardes (hors vigie du beffroi) et combattants, éveillés.
func pnj_actifs() -> Array:
	var r: Array = []
	for n in get_tree().get_nodes_in_group("villageois"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.visible or n3.get("remplace") != null:
			continue
		if n3.has_method("est_endormi") and n3.est_endormi():
			continue
		if n3.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		r.append(n3)
	for c: PnjCombat in combattants:
		if is_instance_valid(c) and not c.est_mort:
			r.append(c)
	return r

func portee_vue() -> float:
	var p := R_VUE
	if de_nuit() and not _eclaire():
		p *= NUIT_VUE
	if joueur != null and joueur.get("accroupi") == true:
		p *= ACCROUPI_VUE
	return p

## `n` voit-il `pos` ? (yeux à 1,6 m ; visé : la tête du joueur à 1,5 m, sinon sa taille à 0,9 m — un établi ne le cache qu'à moitié)
func voit(n: Node3D, pos: Vector3) -> bool:
	var oeil := n.global_position + Vector3.UP * 1.6
	var cible := pos + Vector3.UP * 1.5
	var v := cible - oeil
	var d := v.length()
	if d > portee_vue():
		return false
	var ouie := R_OUIE * (0.5 if joueur != null and joueur.get("accroupi") == true else 1.0)
	if d > ouie:
		var avant := n.global_transform.basis.z
		var h := Vector2(v.x, v.z)
		if h.length() > 0.01 and Vector2(avant.x, avant.z).normalized().dot(h.normalized()) < cos(deg_to_rad(CONE)):
			return false
	var exclus: Array[RID] = []
	if n is CollisionObject3D:
		exclus.append((n as CollisionObject3D).get_rid())
	if joueur != null:
		exclus.append(joueur.get_rid())
	for haut: float in [1.5, 0.9]:
		var c := pos + Vector3.UP * haut
		if _vue_libre(n, oeil, c, exclus):
			return true
	return false

func _vue_libre(n: Node3D, oeil: Vector3, cible: Vector3, exclus: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(oeil, cible, 1, exclus)
	var hit := n.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(cible) < 0.6 or hit["collider"] is CharacterBody3D:
		return true
	derniere_vue_bloquee = hit["collider"] as Node
	return false

func de_nuit() -> bool:
	var c: Node = monde.get("cycle") if monde != null else null
	if c == null:
		return false
	var h := float(c.heure)
	return h >= 19.0 or h < 6.5

## Torche allumée dans la main gauche du joueur (un sort ou un bouclier n'éclaire pas).
func _eclaire() -> bool:
	var m: Node = joueur.get("mains") if joueur != null else null
	var eq: Variant = m.get("equipement") if m != null else null
	return eq != null and eq.get("main_gauche") == Equipement.TORCHE

# ======================================================================================================== réactions

## Gardes, Haldor compris (villageois de type garde) et combattants issus d'un garde.
func est_garde(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is PnjCombat:
		return (n as PnjCombat).est_garde
	if n.is_in_group("gardes_village"):
		return true
	var d: Variant = n.get("donnees")
	return d is Dictionary and (String((d as Dictionary).get("id", "")) == "garde" or String((d as Dictionary).get("type", "")) == "garde")

func _frele(n: Node) -> bool:
	var d: Variant = n.get("donnees") if not (n is PnjCombat) else (n as PnjCombat).pnj.get("donnees")
	if not (d is Dictionary):
		return false
	var id := String((d as Dictionary).get("id", ""))
	var type := String((d as Dictionary).get("type", ""))
	if est_garde(n):
		return false
	for k: String in FRELES:
		if id == k or type == k:
			return true
	for k: String in COSTAUDS:
		if id == k or type == k:
			return false
	return true       # par défaut (cheffe, inconnus) : on fuit et on appelle la garde

## La victime d'une agression : un costaud se défend, un frêle fuit (dans les deux cas il devient un PnjCombat : il peut mourir).
func _reagir_victime(v: Node3D) -> void:
	if v is PnjCombat:
		var c := v as PnjCombat
		if c.mode != "hostile" and (c.est_garde or not _frele(c)):
			c.changer_mode("hostile")
		return
	convertir(v, "fuite" if _frele(v) else "hostile")

func _fuir(n: Node3D) -> void:
	if n is PnjCombat:
		return
	var v: Node = monde.get("vie") if monde != null else null
	if v == null or not v.has_method("civil"):
		return
	var d: Variant = n.get("donnees")
	if not (d is Dictionary):
		return
	var c: Dictionary = v.civil(String((d as Dictionary).get("id", "")))
	if not c.is_empty() and not bool(c.get("fuit", false)):
		v._fuir(c, joueur, false)      # Vie : il court vers l'abri le plus proche, en sort quand le danger est loin

## Gardes témoins d'un vol / d'une intrusion / d'une agression de civil : ils viennent arrêter le joueur (tous hostiles si la garde l'est
## déjà). Sans garde témoin, le plus proche à portée de voix de l'alerte accourt (un civil a crié).
func _poursuivre(gardes_vus: Array, pos: Vector3) -> void:
	if est_hostile():
		guerre(pos, gardes_vus)
		return
	if gardes_vus.is_empty():
		var g := _garde_proche(pos, R_VOIX * 2.0)
		if g != null:
			gardes_vus = [g]
	for g: Node3D in gardes_vus:
		if g is PnjCombat:
			if (g as PnjCombat).mode != "hostile":
				(g as PnjCombat).changer_mode("arrete")
		elif _peut_combattre(g):
			convertir(g, "arrete")

func _garde_proche(pos: Vector3, rayon: float) -> Node3D:
	var best: Node3D = null
	var dmin := rayon
	for g: Node3D in gardes():
		if not _peut_combattre(g) and not (g is PnjCombat):
			continue
		var d := g.global_position.distance_to(pos)
		if d < dmin:
			dmin = d
			best = g
	return best

## Tous les gardes de la juridiction (GardesVillage + Haldor + combattants issus de gardes).
func gardes() -> Array:
	var r: Array = []
	var gv: Node = monde.get_node_or_null("GardesVillage") if monde != null else null
	if gv != null:
		for g in gv.gardes:
			if is_instance_valid(g) and g.get("remplace") == null:
				r.append(g)
	for n in get_tree().get_nodes_in_group("villageois"):
		if is_instance_valid(n) and not n.is_in_group("gardes_village") and est_garde(n) and n.get("remplace") == null:
			r.append(n)
	for c: PnjCombat in combattants:
		if is_instance_valid(c) and c.est_garde and not c.est_mort:
			r.append(c)
	return r

func _peut_combattre(g: Node) -> bool:
	if g == null or not is_instance_valid(g) or not g.is_inside_tree():
		return false
	if g.get("service") == "vigie":
		return false               # la vigie reste dans son beffroi (elle crie l'alerte)
	if g.has_method("est_endormi") and g.est_endormi():
		return false
	return g.get("remplace") == null

## TOUTE la garde de la juridiction devient hostile : `proches` (témoins) et ceux à portée de voix de `pos` tout de suite, les autres
## après DELAI_LOIN (selon la distance). La vigie crie l'alerte.
func guerre(pos: Vector3, proches: Array = []) -> void:
	hostile[JURIDICTION] = true
	treve = false
	for g: Node3D in gardes():
		if g is PnjCombat:
			(g as PnjCombat).changer_mode("hostile")
			continue
		if g.get("service") == "vigie":
			_dire(g, "vigie")
			continue
		if not _peut_combattre(g):
			continue
		var d := g.global_position.distance_to(pos)
		if proches.has(g) or d < R_VOIX:
			convertir(g, "hostile")
		elif not _en_attente(g):
			var k := clampf((d - R_VOIX) / 120.0, 0.0, 1.0)
			_alertes.append({"t": _horloge + lerpf(DELAI_LOIN.x, DELAI_LOIN.y, k), "n": g})

func _en_attente(g: Node) -> bool:
	for a: Dictionary in _alertes:
		if a["n"] == g:
			return true
	return false

## Le PnjCombat qui a pris le corps de `n` (ou `n` lui-même s'il en est un), sinon null.
func combattant_de(n: Node) -> PnjCombat:
	if n is PnjCombat:
		return n as PnjCombat
	var r: Variant = n.get("remplace")
	return r as PnjCombat if r is PnjCombat and is_instance_valid(r) else null

## Le PNJ `n` prend les armes (« hostile »), vient arrêter (« arrete ») ou fuit en courant (« fuite ») : PnjCombat qui reprend son corps.
func convertir(n: Node3D, mode: String) -> PnjCombat:
	var c := combattant_de(n)
	if c != null:
		c.changer_mode(mode)
		return c
	if not n.has_method("remplacer") or not n.is_inside_tree():
		return null
	c = PnjCombat.convertir(n, mode, self)
	if c != null:
		combattants.append(c)
		if mode == "hostile" and est_garde(n) and est_hostile():
			_dire(c, "garde_accourt" if n.global_position.distance_to(joueur.global_position) > 12.0 else "garde_hostile")
	return c

## Tous les combattants rendent leur corps aux PNJ (amende payée, peine purgée, prime éteinte).
func apaiser_tous() -> void:
	for c: PnjCombat in combattants.duplicate():
		if is_instance_valid(c) and not c.est_mort:
			c.pacifier()
	_alertes.clear()

## Un PNJ du village est mort : retiré des listes des gardes et de Vie (leurs boucles typées ne tolèrent pas un nœud libéré).
func oublier(p: Node) -> void:
	var gv: Node = monde.get_node_or_null("GardesVillage") if monde != null else null
	if gv != null:
		gv.gardes.erase(p)
	var v: Node = monde.get("vie") if monde != null else null
	if v != null and v.get("civils") is Array:
		for c: Dictionary in (v.civils as Array).duplicate():
			if c["n"] == p:
				v.civils.erase(c)

func retirer(c: PnjCombat) -> void:
	combattants.erase(c)
	if arrestation == c:
		arrestation = null
		treve = false

# ======================================================================================================== arrestation

## Un garde arrive au contact du joueur recherché : dialogue d'arrestation (amende / geôle / résister). Faux si un dialogue est ouvert.
func proposer_arrestation(g: PnjCombat) -> bool:
	if dialogue == null or not is_instance_valid(dialogue) or joueur.mort or joueur.en_dialogue:
		return false
	if prime() < 1.0:
		_dire(g, "pardon")
		g.pacifier()
		return false
	arrestation = g
	treve = true
	if dialogue.has_method("engager") and dialogue.engager(g):
		return true
	arrestation = null
	treve = false
	return false

func lignes_arrestation(rends_toi := false) -> Array:
	var l: Array = (_textes.get("rends_toi" if rends_toi else "arrestation", []) as Array).duplicate()
	if l.is_empty():
		l = ["Halte ! Ta prime s'élève à %p pièces."]
	for i in l.size():
		l[i] = String(l[i]).replace("%p", str(roundi(prime())))
	return l

## Choix du dialogue d'arrestation (Dialogue : liste de choix « seul », sans Au revoir).
func options_arrestation() -> Array:
	var p := ceili(prime())
	var o: Array = []
	if joueur.inventaire.pieces >= p:
		o.append({"texte": "Payer l'amende (%d pièces)" % p, "action": payer_amende, "seul": true})
	else:
		o.append({"texte": "Payer l'amende (%d pièces) : trop pauvre" % p, "action": _trop_pauvre, "seul": true})
	o.append({"texte": "Aller en geôle", "action": aller_en_prison, "seul": true})
	o.append({"texte": "Résister", "action": resister, "seul": true})
	return o

func _trop_pauvre() -> void:
	_avis("Tu n'as que %d pièces : en geôle." % joueur.inventaire.pieces)
	aller_en_prison()

## Le dialogue d'arrestation s'est fermé sans choix (Échap, joueur parti) : c'est une résistance.
func arrestation_interrompue(g: PnjCombat) -> void:
	if arrestation == g:
		resister()

func payer_amende() -> bool:
	var p := ceili(prime())
	if joueur.inventaire.pieces < p:
		return false
	joueur.inventaire.retirer("pieces", p)
	var n := _confisquer()
	_dire(arrestation, "amende")
	_gracier()
	_avis("Amende payée : %d pièces.%s" % [p, (" %d objets volés saisis." % n) if n > 0 else ""])
	return true

## Geôle : le temps avance (12 h + 1 jour par 100 pièces de prime, 4 jours au plus), perte légère d'expérience, objets volés saisis, sortie
## devant la longue maison. Renvoie les heures purgées.
func aller_en_prison() -> float:
	var p := prime()
	var heures := clampf(12.0 + p / 100.0 * 24.0, 12.0, 96.0)
	var n := _confisquer()
	var prog: Progression = joueur.get("progression")
	if prog != null:
		prog.xp_niveau *= 0.85                        # perte légère : 15 % de la barre de niveau
		for k in prog.competences.experience:
			prog.competences.experience[k] = float(prog.competences.experience[k]) * 0.6
		prog.change.emit()
	_dire(arrestation, "prison")
	_gracier()
	var c: Node = monde.get("cycle")
	if c != null:
		c.heure = fposmod(float(c.heure) + heures, 24.0)
	var sortie := sortie_geole()
	joueur.global_position = sortie
	joueur.velocity = Vector3.ZERO
	joueur.vie = joueur.vie_max
	if hud != null and hud.has_method("annonce"):
		hud.annonce("Peine purgée", "%d heures en geôle%s" % [roundi(heures), (", %d objets saisis" % n) if n > 0 else ""])
	return heures

func sortie_geole() -> Vector3:
	var v: Node = monde.get("village")
	var p := Vector3(44.0, 0.0, 36.0)
	if v != null and v.get("lieux") is Dictionary and (v.lieux as Dictionary).has("longue_maison"):
		p = v.lieux["longue_maison"]
	p.y = float(monde.hauteur(p.x, p.z)) + 0.3 if monde.has_method("hauteur") else p.y + 0.3
	return p

func resister() -> void:
	_derniere_resistance = _horloge
	_dernier_coup = _horloge
	var g := arrestation
	arrestation = null
	treve = false
	if g != null and is_instance_valid(g):
		_dire(g, "resister")
	guerre(joueur.global_position, [g] if g != null else [])

func _gracier() -> void:
	primes[JURIDICTION] = 0.0
	hostile[JURIDICTION] = false
	arrestation = null
	treve = false
	prime_change.emit(JURIDICTION, 0.0)
	apaiser_tous()

## Objets volés retirés du sac ; renvoie leur nombre.
func _confisquer() -> int:
	var total := 0
	for id: String in voles.keys():
		var n := mini(int(voles[id]), joueur.inventaire.nombre(id))
		if n > 0:
			joueur.inventaire.retirer(id, n)
			total += n
	voles.clear()
	return total

# ======================================================================================================== horloge

func _process(dt: float) -> void:
	_horloge += dt
	if monde == null or joueur == null or not is_instance_valid(joueur):
		return
	_temps_de_jeu()
	# gardes prévenus en retard (hors de portée de voix)
	if not _alertes.is_empty():
		for a: Dictionary in _alertes.duplicate():
			if _horloge >= float(a["t"]):
				_alertes.erase(a)
				var g: Node3D = a["n"] as Node3D if is_instance_valid(a["n"]) else null
				if g != null and est_hostile() and _peut_combattre(g):
					convertir(g, "hostile")
	_t_ronde -= dt
	if _t_ronde > 0.0:
		return
	_t_ronde = 0.5
	_ronde()

## Prime qui baisse avec les heures de jeu (sommeil, geôle, attente compris).
func _temps_de_jeu() -> void:
	var c: Node = monde.get("cycle")
	if c == null:
		return
	var h := float(c.heure)
	if _heure_prec < 0.0:
		_heure_prec = h
		return
	var ecart := fposmod(h - _heure_prec, 24.0)
	_heure_prec = h
	if ecart <= 0.0 or ecart > 23.0:
		return
	baisser_prime(ecart)

## La prime perd BAISSE_HEURE par heure de jeu (au moins BAISSE_MIN pièce par heure) ; éteinte, la garde oublie.
func baisser_prime(heures: float) -> void:
	for j: String in primes.keys():
		var p := float(primes[j])
		if p <= 0.0:
			continue
		var baisse := maxf(p * (1.0 - pow(1.0 - BAISSE_HEURE, heures)), BAISSE_MIN * heures)
		primes[j] = maxf(0.0, p - baisse)
		if float(primes[j]) < 1.0:
			primes[j] = 0.0
			hostile[j] = false
			if j == JURIDICTION and arrestation == null:
				apaiser_tous()
		prime_change.emit(j, float(primes[j]))

## Toutes les 0,5 s : PNJ tués qui renaissent (sauvegarde, naissances différées), gardes qui reconnaissent un joueur recherché, garde
## hostile qui propose de se rendre, combattants trop loin qui se calment.
func _ronde() -> void:
	for n in get_tree().get_nodes_in_group("villageois"):
		if morts.has(cle_pnj(n)) and n.get("remplace") == null:
			oublier(n)
			n.queue_free()
	if joueur.mort:
		return
	var pj := joueur.global_position
	# loin du village (≈ 250 m du centre) : les combattants rentrent chez eux (la prime et l'hostilité restent)
	var centre := Vector3(44.0, pj.y, 40.0)
	_loin_t = _loin_t + 0.5 if pj.distance_to(centre) > 250.0 else 0.0
	if _loin_t > 30.0 and not combattants.is_empty():
		apaiser_tous()
	var p := prime()
	if p >= 1.0 and arrestation == null and not joueur.en_dialogue:
		for g: Node3D in gardes():
			if g is PnjCombat or not _peut_combattre(g):
				continue
			if g.global_position.distance_to(pj) < (portee_vue() if est_hostile() else DIST_VUE_ARRET) and voit(g, pj):
				convertir(g, "hostile" if est_hostile() else "arrete")
	# se rendre : plus aucun coup porté depuis SE_RENDRE s, un garde hostile tout près propose l'arrestation
	if est_hostile() and arrestation == null and not joueur.en_dialogue and _horloge - _dernier_coup > SE_RENDRE \
			and _horloge - _derniere_resistance > 20.0:
		var best: PnjCombat = null
		var dmin := 3.2
		for c: PnjCombat in combattants:
			if is_instance_valid(c) and c.est_garde and not c.est_mort and c.mode == "hostile":
				var d := c.global_position.distance_to(pj)
				if d < dmin:
					dmin = d
					best = c
		if best != null:
			best.rends_toi = true
			best.changer_mode("arrete")

# ======================================================================================================== utilitaires

## Clé stable d'un PNJ du village (sauvegarde des morts) : « garde:<id> » ou « pnj:<id> ».
func cle_pnj(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	if n is PnjCombat:
		return cle_pnj((n as PnjCombat).pnj)
	var d: Variant = n.get("donnees")
	if not (d is Dictionary):
		return ""
	var id := String((d as Dictionary).get("id", ""))
	if id == "":
		return ""
	return ("garde:" if n.is_in_group("gardes_village") else "pnj:") + id

func _cle_instance(n: Node) -> int:
	var c := combattant_de(n)
	if c != null and is_instance_valid(c.pnj):
		return c.pnj.get_instance_id()
	return n.get_instance_id()

func _pnj_par_id(id: String) -> Node3D:
	if id == "":
		return null
	for n in get_tree().get_nodes_in_group("villageois"):
		var d: Variant = n.get("donnees")
		if d is Dictionary and (String((d as Dictionary).get("id", "")) == id or String((d as Dictionary).get("nom", "")) == id):
			var c := combattant_de(n)
			return c if c != null else n as Node3D
	return null

func _id_objet(o: Node) -> String:
	if o == null:
		return ""
	for k in ["id_objet", "objet", "id"]:
		if o.has_meta(k):
			return String(o.get_meta(k))
	for k in ["id_objet", "objet_id", "id"]:
		var v: Variant = o.get(k)
		if v is String and v != "":
			return v
	return ""

func _dire(n: Node, cle: String) -> void:
	if n == null or not is_instance_valid(n) or dialogue == null or not is_instance_valid(dialogue):
		return
	var l: Array = _textes.get(cle, [])
	if l.is_empty():
		return
	dialogue.dire_au_passage(nom_de(n), String(l.pick_random()).replace("%p", str(roundi(prime()))))

## Nom affiché d'un PNJ (méthode des villageois et gardes, propriété des combattants).
static func nom_de(n: Node) -> String:
	if n.has_method("nom_affiche"):
		return String(n.nom_affiche())
	var v: Variant = n.get("nom_affiche")
	return String(v) if v != null else "?"

func replique(cle: String) -> String:
	var l: Array = _textes.get(cle, [])
	return String(l.pick_random()) if not l.is_empty() else ""

func _avis(t: String) -> void:
	if hud != null and hud.has_method("avis"):
		hud.avis(t)

# ======================================================================================================== sauvegarde

func exporter() -> Dictionary:
	return {"v": 1, "primes": primes.duplicate(), "reputation": reputation.duplicate(), "hostile": hostile.duplicate(),
		"voles": voles.duplicate(), "morts": morts.duplicate()}

func restaurer(d: Dictionary) -> void:
	apaiser_tous()
	primes = (d.get("primes", {}) as Dictionary).duplicate() if d.get("primes") is Dictionary else {}
	reputation = (d.get("reputation", {}) as Dictionary).duplicate() if d.get("reputation") is Dictionary else {}
	hostile = (d.get("hostile", {}) as Dictionary).duplicate() if d.get("hostile") is Dictionary else {}
	voles = {}
	if d.get("voles") is Dictionary:
		for id in d["voles"]:
			voles[String(id)] = int(d["voles"][id])
	morts = (d.get("morts", []) as Array).duplicate() if d.get("morts") is Array else []
	_heure_prec = -1.0
