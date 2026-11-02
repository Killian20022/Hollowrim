class_name ArmureVisible
extends Node
## ARMURE PORTÉE VISIBLE (branche rpg/armures_legeres, convention conception_rpg/CONVENTION_ARMURES_3D.md) : écoute
## EquipementCorps.change et habille le corps du joueur à la 3e personne (corps_joueur.gd) avec le modèle porté de chaque pièce
## de tête / torse / mains / pieds : assets/modeles/armures/porte/<id>.glb (maillage SKINNÉ sur le squelette du héros, mêmes noms
## d'os : il est rattaché au Skeleton3D du corps et suit toutes ses animations). Pièce sans glb : rien ne change (le héros garde sa
## tenue). Ce qu'une pièce recouvre est MASQUÉ sur le héros (copie filtrée des maillages, l'original est remis quand on l'ôte) :
##   tete  : casque, crête, camail, cheveux (la barbe et le visage restent) ;
##   torse : cotte (triangles qui ont un sommet à |x| < 0,405 : la manche au-delà, sous le coude, reste), mante, plastron, épaulières, col, tabard, pèlerine, ceinture, surcot ;
##   mains : tout ce qui dépasse |x| = 0,58 en pose de repos (gants, revers fourrés, brassards, bout des manches) ;
##   pieds : bottes, revers fourrés, bas du pantalon (sous y = 0,40).
## 1re personne : les bras FPS (mains.gd, matières ab_* d'AvantBras) prennent la matière des gants / gantelets portés.
## Matériaux : texture cuite du glb (alpha = brillance) + preset de matière (cuir, fourrure, os, fer, acier, or) rendu par le shader
## « matière » des armes (EpeesLongues.shader_matiere : ps1 + reflets en paliers), contour des personnages.
##   ArmureVisible.equiper(corps, squelette, equipement_corps, mains) -> ArmureVisible   (corps_joueur._creer_modele)
##   ArmureVisible.instancier_sol(id) -> Node3D      (pièce posée au sol / présentoir, null si pas de glb)

const PORTE := "res://assets/modeles/armures/porte/"
const SOL := "res://assets/modeles/armures/sol/"
const EMPLACEMENTS := ["tete", "torse", "mains", "pieds"]
## Seuils de masquage (pose de repos du héros, repère du squelette : y haut, z devant).
const MAINS_X := 0.58
const TORSE_X := 0.405
const PIEDS_Y := 0.40
const PIEDS_Y_ACC := 0.47
const TETE_Y := 1.585
const CAMAIL_Y := 1.46
const CAMAIL_BAS_TORSE := 1.62
const TORSE_PANTALON_Y := 0.71	# sommet le plus haut du triangle (gros triangles du pantalon)
## Mèches de la nuque (cheveux sous le casque du héros) qui tombent dans le col d'une pièce de torse.
const TORSE_CHEVEUX_Y := 1.575

## Preset par nom de matériau Blender (même sens que EpeesLongues.MATIERES ; l'alpha de la texture porte la brillance).
const MATIERES := {
	"cuir": {"teinte": Color(1.04, 1.0, 0.98), "bord": 0.14, "poli": 0.22},
	"fourrure": {"teinte": Color(1.02, 1.0, 0.98), "bord": 0.05, "poli": 0.05},
	"os": {"teinte": Color(1.02, 1.0, 0.97), "bord": 0.10, "poli": 0.30},
	"fer": {"teinte": Color(1.0, 1.0, 1.02), "metal": 0.5, "poli": 0.35, "reflet": Color(0.95, 0.96, 1.0)},
	"acier": {"teinte": Color(1.04, 1.04, 1.06), "metal": 0.75, "poli": 0.7, "reflet": Color(0.94, 0.98, 1.05)},
	"or": {"teinte": Color(1.0, 1.0, 1.0), "metal": 0.72, "poli": 0.6, "reflet": Color(1.06, 0.9, 0.62)},
}
## Matière FPS (AvantBras) remplacée par famille de gants : clé de matière ab_* -> nom de matière du glb ou "" (inchangé).
const FPS_GANTS := ["ab_gant"]
const FPS_BRASSARD := ["ab_cuir", "ab_tresse", "ab_fourrure"]
const FPS_PLAQUES := ["ab_metal", "ab_fer"]

var squelette: Skeleton3D
var equipement: EquipementCorps
var mains: Node      # mains.gd (bras de la 1re personne), peut être null
var vue_3 := true
var _portees := {}            # emplacement -> MeshInstance3D posé sur le squelette
var _originaux := {}          # MeshInstance3D du héros -> Mesh d'origine
var _cheveux_visibles := {}   # MeshInstance3D -> visibilité d'origine
var _fps_origine := {}        # [MeshInstance3D, surface] -> matériau d'origine
var _fps_id := ""
static var _mats := {}        # chemin du glb -> {nom_matière: ShaderMaterial}
static var _filtres := {}     # clé (maillage + zones) -> ArrayMesh filtré

static func equiper(parent: Node, sq: Skeleton3D, eq: EquipementCorps, bras: Node = null) -> ArmureVisible:
	var a: ArmureVisible = parent.get_node_or_null("ArmureVisible")
	if a == null:
		a = ArmureVisible.new()
		a.name = "ArmureVisible"
		parent.add_child(a)
	a.mains = bras
	a.installer(sq, eq)
	return a

## Chemin du modèle porté : champ « modele_porte » de la fiche (data/objets/armures.json), sinon la convention porte/<id>.glb.
static func chemin_porte(id: String) -> String:
	return String(Inventaire.objet(id).get("modele_porte", PORTE + id + ".glb")) if Inventaire.connu(id) else PORTE + id + ".glb"

static func chemin_sol(id: String) -> String:
	return String(Inventaire.objet(id).get("modele_sol", SOL + id + ".glb")) if Inventaire.connu(id) else SOL + id + ".glb"

static func a_modele(id: String) -> bool:
	return id != "" and ResourceLoader.exists(chemin_porte(id))

## (Re)branche le système sur un squelette (le corps est reconstruit à la résurrection) : tout est réappliqué.
func installer(sq: Skeleton3D, eq: EquipementCorps) -> void:
	if equipement != null and equipement != eq and equipement.change.is_connected(_sur_change):
		equipement.change.disconnect(_sur_change)
	squelette = sq
	equipement = eq
	_portees.clear()
	_originaux.clear()
	_cheveux_visibles.clear()
	if equipement != null and not equipement.change.is_connected(_sur_change):
		equipement.change.connect(_sur_change)
	appliquer()

func _sur_change(e: String) -> void:
	if e in EMPLACEMENTS:
		appliquer()

## Pose les modèles portés de toutes les pièces et met à jour le masquage et les bras FPS.
func appliquer() -> void:
	if squelette == null or not is_instance_valid(squelette):
		return
	for e in EMPLACEMENTS:
		_poser(e)
	_masquer()
	_habiller_fps()
	definir_vue(vue_3)

## Identifiant porté et visible (glb présent) à un emplacement, "" sinon.
func porte(e: String) -> String:
	var mi: MeshInstance3D = _portees.get(e)
	return String(mi.get_meta("armure_id")) if mi != null and is_instance_valid(mi) else ""

func maillage(e: String) -> MeshInstance3D:
	var mi: MeshInstance3D = _portees.get(e)
	return mi if mi != null and is_instance_valid(mi) else null

func definir_vue(troisieme: bool) -> void:
	vue_3 = troisieme
	for e in _portees:
		var mi: MeshInstance3D = _portees[e]
		if is_instance_valid(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if troisieme else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _poser(e: String) -> void:
	var id := equipement.objet_a(e) if equipement != null else ""
	var ancien: MeshInstance3D = _portees.get(e)
	if ancien != null and is_instance_valid(ancien):
		if String(ancien.get_meta("armure_id", "")) == id:
			return
		ancien.queue_free()
		ancien.get_parent().remove_child(ancien)
	_portees.erase(e)
	if not a_modele(id):
		return
	var mi := charger_porte(id)
	if mi == null:
		return
	mi.name = "armure_" + e
	mi.set_meta("armure_id", id)
	mi.set_meta("armure_emplacement", e)
	squelette.add_child(mi)
	mi.skeleton = NodePath("..")
	_portees[e] = mi

## Maillage porté d'une pièce, prêt à rattacher à un Skeleton3D du héros (skin du glb, liaisons par NOM d'os ; matériaux habillés).
static func charger_porte(id: String) -> MeshInstance3D:
	var ps := load(chemin_porte(id)) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	var src: MeshInstance3D = null
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			src = mi
			break
	if src == null:
		inst.free()
		return null
	src.get_parent().remove_child(src)
	src.owner = null
	inst.free()
	src.transform = Transform3D.IDENTITY
	_habiller_maillage(src, chemin_porte(id))
	return src

## Pièce posée au sol / présentoir (glb statique, pivot au sol), matériaux habillés ; null si absente.
static func instancier_sol(id: String) -> Node3D:
	if not ResourceLoader.exists(chemin_sol(id)):
		return null
	var n: Node3D = (load(chemin_sol(id)) as PackedScene).instantiate()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		_habiller_maillage(mi, chemin_sol(id))
	n.name = "armure_sol_" + id
	return n

static func _habiller_maillage(mi: MeshInstance3D, cle: String) -> void:
	if not _mats.has(cle):
		var d := {}
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else "cuir"
			var tex: Texture2D = (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else null
			d[s] = materiau(nom, tex)
		_mats[cle] = d
	var mats: Dictionary = _mats[cle]
	for s in mi.mesh.get_surface_count():
		if mats.has(s):
			mi.set_surface_override_material(s, mats[s])

## Matériau PS1 « matière » d'une pièce (texture cuite, alpha = brillance) + contour des personnages.
static func materiau(nom: String, tex: Texture2D) -> ShaderMaterial:
	var p: Dictionary = MATIERES.get(nom, MATIERES["cuir"])
	if tex == null:
		tex = Palette.tex("cuir", Palette.CUIR, 4, 0.5)
	var m := Palette.materiau(tex, Vector2.ONE, p.get("teinte", Color.WHITE))
	m.shader = EpeesLongues.shader_matiere(false)
	m.set_shader_parameter("tex_neige", tex)    # couleurs de sommet du glb d'alpha nul : pas de neige
	m.set_shader_parameter("mt_boite", 0.0)
	for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
		m.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
	m.set_shader_parameter("mt_opacite", 1.0)
	m.set_shader_parameter("mt_reflet", p.get("reflet", Color.WHITE))
	m.set_shader_parameter("reflet_force", 0.0)
	m.set_shader_parameter("reflet_fil", 0.0)
	m.next_pass = GuerrierNordique.contour()
	m.resource_name = "armure_" + nom
	return m

# ------------------------------------------------------------------------------------------------------------- masquage
## Zones recouvertes par les pièces réellement posées.
func zones() -> Array:
	var z := []
	for e in EMPLACEMENTS:
		if maillage(e) != null:
			z.append(e)
	return z

func _masquer() -> void:
	var z := zones()
	var cle_z := ",".join(z)
	for mi: MeshInstance3D in squelette.find_children("*", "MeshInstance3D", false, false):
		if mi.has_meta("armure_id"):
			continue
		var nom := String(mi.name)
		if nom.begins_with("Hair_Long"):
			if not _cheveux_visibles.has(mi):
				_cheveux_visibles[mi] = mi.visible
			mi.visible = bool(_cheveux_visibles[mi]) and not z.has("tete")
		if not mi.visible and not _originaux.has(mi):
			continue
		if not _originaux.has(mi):
			_originaux[mi] = mi.mesh
		var orig: Mesh = _originaux[mi]
		if z.is_empty() or not _concerne(nom, z):
			mi.mesh = orig
			continue
		var cle := "%d|%s" % [orig.get_instance_id(), cle_z]
		if not _filtres.has(cle):
			_filtres[cle] = _filtrer(orig, nom, z)
		mi.mesh = _filtres[cle]

static func _concerne(nom: String, z: Array) -> bool:
	match nom:
		"tunique":
			return z.has("torse") or z.has("mains")
		"mante", "Hair_Long":
			return z.has("torse")
		"brassards", "peau":
			return z.has("mains")
		"bottes":
			return z.has("pieds")
		"pantalon":
			return z.has("pieds") or z.has("torse")
		"accessoires":
			return true
	return false

static func _dans(r: Rect2i, u: Vector2) -> bool:
	return u.x >= r.position.x and u.y >= r.position.y and u.x < r.end.x and u.y < r.end.y

## true si le triangle (centre c au repos, centre UV u en texels de l'atlas des accessoires) est recouvert.
static func recouvert(nom: String, surface: int, c: Vector3, u: Vector2, z: Array, haut := -INF, x_min := INF) -> bool:
	if haut == -INF:
		haut = c.y
	if x_min == INF:
		x_min = absf(c.x)
	if z.has("mains") and absf(c.x) > MAINS_X and nom in ["tunique", "brassards", "peau", "accessoires"]:
		return true
	if z.has("pieds"):
		if nom == "bottes":
			return true
		if nom == "pantalon" and c.y < PIEDS_Y:
			return true
		if nom == "accessoires" and c.y < PIEDS_Y_ACC:
			return true
	var acc := nom == "accessoires" and surface == 0
	var oeil := acc and _dans(GuerrierTextures.R_OEIL, u)
	var casque := acc and (_dans(GardienTextures.R_CASQUE, u) or _dans(GardienTextures.R_BANDEAU, u))
	var camail := acc and _dans(GuerrierTextures.R_PLASTRON, u) and c.y > CAMAIL_Y
	if z.has("tete") and nom == "accessoires" and not oeil and (casque or camail or c.y > TETE_Y):
		return true
	if z.has("torse"):
		if camail and c.y < CAMAIL_BAS_TORSE:
			return true     # bas du camail du casque, étalé sur le col : sous la pièce de torse
		if nom == "pantalon" and haut > TORSE_PANTALON_Y:
			return true     # haut du pantalon (hanches) : sous la pièce de torse, il passerait au travers quand la cuisse se lève
		if nom == "tunique" and x_min < TORSE_X:     # sommet le plus proche du corps : les grands triangles de la manche
			return true
		if nom == "mante":
			return true
		if nom == "Hair_Long" and c.y < TORSE_CHEVEUX_Y:
			return true
		if nom == "accessoires":
			if surface == 1:
				return true
			if not oeil and not casque and not camail and c.y > 0.55 and c.y < TETE_Y and absf(c.x) < 0.45:
				return true
	return false

## Copie du maillage sans les triangles recouverts (mêmes surfaces, mêmes sommets : les matériaux surchargés restent valables).
static func _filtrer(orig: Mesh, nom: String, z: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	for s in orig.get_surface_count():
		var a := orig.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var atlas := Vector2(GuerrierTextures.ATLAS) if s == 0 else Vector2(GuerrierTextures.DECOUPES)
		var garde := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			var u := Vector2.ZERO
			if not uv.is_empty():
				u = (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0 * atlas
			if not recouvert(nom, s, c, u, z, maxf(v[idx[t]].y, maxf(v[idx[t + 1]].y, v[idx[t + 2]].y)), minf(absf(v[idx[t]].x), minf(absf(v[idx[t + 1]].x), absf(v[idx[t + 2]].x)))):
				garde.append(idx[t])
				garde.append(idx[t + 1])
				garde.append(idx[t + 2])
		if garde.is_empty():
			garde = PackedInt32Array([0, 0, 0])     # surface gardée (index des matériaux surchargés), sans aire
		a[Mesh.ARRAY_INDEX] = garde
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(s, orig.surface_get_material(s))
	return m

# ------------------------------------------------------------------------------------------------------------- 1re personne
func _habiller_fps() -> void:
	if mains == null or not is_instance_valid(mains):
		return
	var bras: Node = mains.get("bras")
	if bras == null:
		return
	var id := equipement.objet_a("mains") if equipement != null else ""
	if not a_modele(id):
		id = ""
	_fps_id = id
	# remettre les matières d'origine
	for k in _fps_origine:
		var mi: MeshInstance3D = k[0]
		if is_instance_valid(mi):
			mi.set_surface_override_material(k[1], _fps_origine[k])
	_fps_origine.clear()
	if id == "":
		return
	var mats := materiaux_fps(id)
	for mi: MeshInstance3D in bras.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else ""
			if mats.has(nom):
				_fps_origine[[mi, s]] = mi.get_surface_override_material(s)
				mi.set_surface_override_material(s, mats[nom])

## Matières des bras FPS pour une paire de gants portée : texture et matière du glb, tons de la pièce (gants, revers, plaques).
static func materiaux_fps(id: String) -> Dictionary:
	var famille := id.get_slice("_", 1)
	# bras FPS aux UV propres et répétées : on garde leurs textures, teintées vers la matière portée
	var d := {}
	var teintes := {
		"cuir": [Color(1.0, 0.78, 0.6), Color(0.95, 0.8, 0.66), Color(0.8, 0.7, 0.6)],
		"fourrure": [Color(0.95, 0.8, 0.64), Color(1.25, 1.18, 1.05), Color(0.8, 0.7, 0.6)],
		"os": [Color(0.55, 0.5, 0.48), Color(0.62, 0.55, 0.5), Color(1.35, 1.25, 1.05)],
	}
	var t: Array = teintes.get(famille, teintes["cuir"])
	var ab := AvantBras.materiaux()
	for k in FPS_GANTS:
		d[k] = _teinter(ab[k], t[0])
	for k in FPS_BRASSARD:
		d[k] = _teinter(ab[k], t[1])
	for k in FPS_PLAQUES:
		d[k] = _teinter(ab[k], t[2])
	return d

static func _teinter(m: ShaderMaterial, c: Color) -> ShaderMaterial:
	var m2 := m.duplicate() as ShaderMaterial
	var t0: Variant = m.get_shader_parameter("teinte")
	m2.set_shader_parameter("teinte", (t0 if t0 is Color else Color.WHITE) * c)
	return m2
