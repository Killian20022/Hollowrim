class_name ReseauMondeVivant
extends Node
## LOT 2b — monde vivant en réseau : villageois, gardes, heure du jour, météo (docs/reseau_lot2b.md).
##  - L'HÔTE détient l'IA (villageois.gd, garde_village.gd, Vie, GardesVillage) ; chez l'INVITÉ chaque PNJ est une marionnette
##    (`marionnette = true` : ni IA ni physique) dont position, cap, clip d'animation, visibilité et pose du corps viennent du réplicateur.
##  - Les plannings (Vie / EmploiDuTemps) ne tournent que chez l'hôte, depuis l'heure du cycle ; l'hôte est le maître de l'heure : il la diffuse
##    chaque seconde (évènement « mv_heure » : heure, jour, tempête) et l'invité corrige sa dérive (Cycle compense Engine.time_scale en ligne).
##  - Cible des PNJ = joueur le plus proche (joueur_proche / distance_joueurs) via Reseau.registre.noeud(id) + le joueur local.
## Utilise les autoloads du lot 2a : `Replicateur` (enregistrer) et `Rejoindre` (contributeur), résolus à l'exécution.
## Solo : ne fait rien (aucune marionnette, aucun envoi) et joueur_proche() renvoie le joueur local.
## À reporter au lot 5 : crime / prime par joueur (Crime : un seul dictionnaire), PnjCombat issu d'un villageois (remplace), conversations E des invités.

## Autoload Reseau, résolu à l'exécution : villageois.gd / garde_village.gd / cycle.gd dépendent de cette classe et sont parfois compilés
## (preload) par des tests en `-s` AVANT l'enregistrement des autoloads : un identifiant `Reseau` nu y serait une erreur de compilation.
static func _r() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Reseau")

static func en_ligne() -> bool:
	var r := _r()
	return r != null and r.est_en_ligne()

const PERIODE_SCAN := 1.0
const PERIODE_HEURE := 1.0
const SEUIL_SAUT := 0.3     # h : au-delà, l'invité saute à l'heure de l'hôte ; en deçà, il rattrape la moitié de l'écart à chaque message
const PERTINENCE := 120.0   # m : un PNJ plus loin d'un invité ne lui est pas envoyé (2a)

var monde: Node
var _entites := {}     # id (String) -> Node
var _marionnettes := false
var _en_ligne_prec := false
var _hote_prec := true
var _t_scan := 0.0
var _t_heure := 0.0

## Installe le nœud sous le monde (appelé par monde.gd après Vie.peupler). `monde.cycle` doit exister.
static func installer(monde_: Node) -> ReseauMondeVivant:
	var r := ReseauMondeVivant.new()
	r.name = "ReseauMondeVivant"
	r.monde = monde_
	monde_.add_child(r)
	return r

# ---------- cibles : joueur le plus proche (statique : appelé par villageois.gd / garde_village.gd / vie.gd) ----------

## Joueur (local ou avatar) le plus proche de `pos` ; `local` = le joueur local (renvoyé tel quel hors ligne).
static func joueur_proche(pos: Vector3, local: CharacterBody3D) -> CharacterBody3D:
	if not en_ligne():
		return local
	var meilleur := local
	var dmin := INF
	if local != null and is_instance_valid(local):
		dmin = pos.distance_squared_to(local.global_position)
	for id in _r().registre.ids():
		var n := _r().registre.noeud(id) as CharacterBody3D
		if n == null or n == local or not n.is_inside_tree():
			continue
		if "mort" in n and n.mort:
			continue
		var d := pos.distance_squared_to(n.global_position)
		if d < dmin:
			dmin = d
			meilleur = n
	return meilleur

## Distance de `pos` au joueur le plus proche (niveaux de détail : un PNJ proche d'un invité n'est pas gelé chez l'hôte). `pj_local` : position du joueur local.
static func distance_joueurs(pos: Vector3, pj_local: Vector3) -> float:
	var d := pos.distance_to(pj_local)
	if not en_ligne():
		return d
	for id in _r().registre.ids():
		var n := _r().registre.noeud(id) as Node3D
		if n != null and n.is_inside_tree():
			d = minf(d, pos.distance_to(n.global_position))
	return d

# ---------- autoloads du lot 2a (résolus à l'exécution : voir _r()) ----------

func _replicateur() -> Node:
	return get_node("/root/Replicateur")

func _rejoindre() -> Node:
	return get_node("/root/Rejoindre")

# ---------- cycle de vie ----------

func _ready() -> void:
	_r().abonner("mv_heure", _sur_heure)
	_rejoindre().call("contributeur", "monde_vivant", Callable(self, "exporter"), Callable(self, "importer"))
	_scanner()

func _exit_tree() -> void:
	_r().desabonner("mv_heure", _sur_heure)

func _cycle() -> Node:
	return monde.get("cycle") as Node if monde != null else null

func _process(dt: float) -> void:
	var en_ligne: bool = _r().est_en_ligne()
	if en_ligne != _en_ligne_prec or _r().est_hote() != _hote_prec:
		_en_ligne_prec = en_ligne
		_hote_prec = _r().est_hote()
		_basculer(en_ligne and not _r().est_hote())
	if not en_ligne:
		return
	_t_scan -= dt
	if _t_scan <= 0.0:
		_t_scan = PERIODE_SCAN
		_scanner()
	if _r().est_hote():
		_t_heure -= dt
		if _t_heure <= 0.0 and _r().joueurs().size() > 1:
			_t_heure = PERIODE_HEURE
			_r().envoyer_evenement("mv_heure", 0, exporter())

## Passe tous les PNJ (et l'IA centrale : Vie, GardesVillage) en marionnettes (invité) ou les rend à l'IA (hôte / solo).
func _basculer(marionnettes: bool) -> void:
	_marionnettes = marionnettes
	for n: Node in _entites.values():
		if is_instance_valid(n):
			n.set("marionnette", marionnettes)
	for nom in ["Vie", "GardesVillage"]:
		var c := monde.get_node_or_null(nom) if monde != null else null
		if c != null:
			c.set_process(not marionnettes)
			c.set_physics_process(not marionnettes)

# ---------- enregistrement des PNJ ----------

## Identifiant réseau stable (même génération déterministe chez tous) : « v:<id> » (villageois), « g:<nom> » (garde).
static func id_de(n: Node) -> String:
	if n.is_in_group("gardes_village"):
		return "g:" + String(n.name)
	var d: Variant = n.get("donnees")
	if d is Dictionary and (d as Dictionary).has("id"):
		return "v:" + String((d as Dictionary)["id"])
	return "v:%s@%d" % [n.name, hash(Vector3(snappedf(n.position.x, 0.01), 0.0, snappedf(n.position.z, 0.01)))]

func _scanner() -> void:
	for n: Node in get_tree().get_nodes_in_group("villageois"):
		if not (n is CharacterBody3D) or not n.has_method("_jouer") or not n.is_inside_tree():
			continue
		var id := id_de(n)
		if _entites.get(id) == n:
			continue
		_entites[id] = n
		n.set("marionnette", _marionnettes)
		_replicateur().call("enregistrer", id, n, Callable(self, "_etat_pnj").bind(n), Callable(self, "_appliquer_pnj").bind(n), PERTINENCE)
	if _marionnettes:
		_basculer(true)   # nouveaux nés (naissance différée) : Vie / GardesVillage restent coupés

## Liste des ids connus (tests, rejoindre).
func ids() -> Array:
	var r := _entites.keys()
	r.sort()
	return r

func noeud(id: String) -> Node:
	return _entites.get(id)

## État envoyé par l'hôte (petit : nombres, Vector3, String courte). `a_` = angle (interpolé en angle par 2a).
func _etat_pnj(n: Node3D) -> Dictionary:
	var e := {"pos": n.global_position, "a_lacet": n.rotation.y, "vis": n.visible}
	var anim: AnimationPlayer = n.get("anim")
	if anim != null:
		e["anim"] = String(n.get("_anim"))
		e["vit"] = anim.speed_scale
	var m: Node3D = n.get("modele")
	if m != null:
		e["mo"] = m.position          # pose du corps (couché, assis…) : le modèle se déplace dans le repère du corps
		e["mq"] = m.quaternion
	return e

## Application chez l'invité (état interpolé par le réplicateur).
func _appliquer_pnj(e: Dictionary, n: Node3D) -> void:
	if not _marionnettes or not is_instance_valid(n):
		return
	n.global_position = e["pos"]
	n.rotation.y = float(e["a_lacet"])
	n.visible = bool(e["vis"])
	var anim: AnimationPlayer = n.get("anim")
	if anim != null and e.has("anim"):
		var nom: String = e["anim"]
		if nom != "":
			n.call("_jouer", nom, 0.2)
		anim.speed_scale = float(e["vit"])
	var m: Node3D = n.get("modele")
	if m != null and e.has("mo"):
		m.position = e["mo"]
		m.quaternion = e["mq"]

# ---------- heure et météo : l'hôte est le maître ----------

## Instantané (diffusion périodique ET rejoindre en cours de partie).
func exporter() -> Dictionary:
	var c := _cycle()
	if c == null:
		return {}
	return {"h": float(c.get("heure")), "j": int(c.get("jour")), "t": float(c.get("tempete"))}

func importer(d: Dictionary) -> void:
	if d.is_empty() or _r().est_hote():
		return
	var c := _cycle()
	if c == null:
		return
	var h_loc := float(c.get("heure"))
	var err := fposmod(float(d["h"]) - h_loc + 12.0, 24.0) - 12.0
	c.set("jour", int(d["j"]))
	c.set("heure", fposmod(float(d["h"]) if absf(err) > SEUIL_SAUT else h_loc + err * 0.5, 24.0))
	c.set("tempete", float(d["t"]))

func _sur_heure(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur == 1 and d is Dictionary:
		importer(d)
