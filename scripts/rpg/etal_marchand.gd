class_name EtalMarchand
extends Node3D
## ÉTALS des marchands du village (lot L8, data/marchands.json) : quelques pièces de leur STOCK DU MOMENT exposées en 3D sur une
## table (ObjetMonde.exposer), pour voir les objets en jeu avant d'ouvrir la boutique (« Commercer » reste la seule façon d'acheter).
##   - Brodd (forgeron) : table à tréteaux contre la façade de la forge, sous la fenêtre (repère du nœud « Forge » du village, hors
##     de la porte) ; armes couchées, armures, bijoux ;
##   - Grima (ancienne) : petite table près du puits, à côté de son poste ; fioles, livres, vivres.
## Le choix suit Marchand.stock(id) (réassort tous les 2 jours) : relu toutes les PERIODE s, reconstruit seulement s'il change ;
## au plus MAX_PIECES, variées (une par famille avant d'en doubler une), ordre stable. Hook : Monde._uniques_village → poser_village.

const PERIODE := 3.0
const MAX_PIECES := 5
## id du marchand -> pose : « forge » = repère du nœud Forge (local), « monde » = coordonnées monde (x, z ; sol relu) ; table [largeur, profondeur, hauteur].
const ETALS := {
	"forgeron": {"repere": "forge", "pos": Vector3(-1.2, 0.0, 4.3), "lacet": 0.0, "table": Vector3(1.7, 0.62, 1.0)},
	"ancienne": {"repere": "monde", "pos": Vector3(45.9, 0.0, 38.2), "lacet": -0.45, "table": Vector3(1.1, 0.55, 0.74)},
}

var id_marchand := ""
var table := Vector3(1.4, 0.6, 0.75)
var _plateau: Node3D
var _vu := "?"
var _t := 0.0

## Pose les étals des marchands connus dans le village (après le bâti). Renvoie les étals posés.
static func poser_village(village: Node3D, monde: Node = null) -> Array[EtalMarchand]:
	var res: Array[EtalMarchand] = []
	if village == null:
		return res
	for mid: String in ETALS:
		if not Marchand.est_marchand(mid):
			continue
		var e: Dictionary = ETALS[mid]
		var parent: Node3D = village
		if String(e["repere"]) == "forge":
			parent = village.find_child("Forge", true, false) as Node3D
			if parent == null:
				continue
		var et := EtalMarchand.new()
		et.name = "Etal_" + mid
		et.id_marchand = mid
		et.table = e["table"]
		parent.add_child(et)
		var p: Vector3 = e["pos"]
		if parent == village:                      # coordonnées MONDE (comme Village.lieux) : sol relu au point
			p.y = float(monde.hauteur(p.x, p.z)) if monde != null and monde.has_method("hauteur") else village.global_position.y
			et.global_position = p
		else:
			et.position = p
		et.rotation.y = float(e["lacet"])
		res.append(et)
	return res

func _ready() -> void:
	_construire_table()
	actualiser()

func _process(dt: float) -> void:
	_t += dt
	if _t >= PERIODE:
		_t = 0.0
		actualiser()

## Pièces exposées pour le stock `stock` ({id: n}) : objets à modèle 3D, une par famille (catégorie + emplacement) d'abord.
static func choisir(stock: Dictionary, max_pieces := MAX_PIECES) -> Array[String]:
	var ids: Array = stock.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return _rang(a) < _rang(b) or (_rang(a) == _rang(b) and a < b))   # armes, bouclier, petites pièces
	var res: Array[String] = []
	var familles := {}
	for passe in 2:
		for oid: String in ids:
			if res.size() >= max_pieces:
				return res
			if oid in res or int(stock[oid]) <= 0 or not ObjetMonde.a_modele(oid) or Inventaire.emplacement_de(oid) == "torse":
				continue
			var fam := Inventaire.categorie_de(oid) + ":" + Inventaire.emplacement_de(oid) + ":" + oid.get_slice("_", 0)
			if passe == 0 and familles.has(fam):
				continue
			if Inventaire.categorie_de(oid) == "arme" and not _bouclier(oid) and _nb_longues(res) >= MAX_LONGUES:
				continue                       # le plateau ne tient que deux armes couchées
			familles[fam] = true
			res.append(oid)
	return res

const MAX_LONGUES := 2

## Ordre d'exposition : armes d'abord (un forgeron montre ses lames), bouclier, petites pièces d'armure, le reste. Les pièces de
## torse (cuirasses, armures) ne vont pas sur un plateau : il faudrait un mannequin.
static func _rang(oid: String) -> int:
	if Inventaire.categorie_de(oid) == "arme":
		return 1 if _bouclier(oid) else 0
	if Inventaire.categorie_de(oid) == "armure":
		return 2
	return 3

static func _bouclier(oid: String) -> bool:
	return CatalogueArmes.connu(oid) and CatalogueArmes.famille_de(oid) == "bouclier"

static func _nb_longues(ids: Array[String]) -> int:
	var n := 0
	for oid in ids:
		if Inventaire.categorie_de(oid) == "arme" and not _bouclier(oid):
			n += 1
	return n

func pieces() -> Array[String]:
	return choisir(Marchand.stock(id_marchand))

func actualiser() -> void:
	var ex := pieces()
	var cle := ",".join(ex)
	if cle == _vu:
		return
	_vu = cle
	if _plateau != null:
		_plateau.queue_free()
	_plateau = Node3D.new()
	_plateau.name = "Pieces"
	_plateau.position = Vector3(0, table.y, 0)
	add_child(_plateau)
	ObjetMonde.exposer(_plateau, ex, table.x - 0.12, table.z - 0.1, "etal")

## Table à tréteaux : plateau de planches, deux tréteaux en X, traverse ; matériaux bois du shader_matiere.
func _construire_table() -> void:
	var em := EpeesLongues.materiaux()
	var planches: Material = em["planches"]
	var bois: Material = em["bois"]
	var l := table.x
	var h := table.y
	var p := table.z
	_boite(Vector3(l, 0.05, p), Vector3(0, h - 0.025, 0), planches)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (l * 0.5 - 0.16)
		for sz: float in [-1.0, 1.0]:
			var pied := _boite(Vector3(0.06, h * 1.08, 0.06), Vector3(x, h * 0.48, sz * p * 0.28), bois)
			pied.rotation.x = sz * 0.32
		_boite(Vector3(0.06, 0.06, p * 0.9), Vector3(x, h - 0.08, 0), bois)
	_boite(Vector3(l - 0.3, 0.05, 0.05), Vector3(0, h * 0.35, 0), bois)
	var corps := StaticBody3D.new()      # on ne traverse pas l'étal
	var forme := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(l, h, p)
	forme.shape = bx
	forme.position = Vector3(0, h * 0.5, 0)
	corps.add_child(forme)
	add_child(corps)

func _boite(t: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PrimGeo.maillage(PrimGeo.boite(t))
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
