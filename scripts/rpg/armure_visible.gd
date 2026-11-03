class_name ArmureVisible
extends Node
## ARMURE PORTÉE VISIBLE (branche rpg/armures_legeres, convention conception_rpg/CONVENTION_ARMURES_3D.md) : écoute
## EquipementCorps.change et habille le corps du joueur à la 3e personne (corps_joueur.gd) avec le modèle porté de chaque pièce
## de tête / torse / mains / pieds : assets/modeles/armures/porte/<id>.glb (maillage SKINNÉ sur le squelette du héros, mêmes noms
## d'os : il est rattaché au Skeleton3D du corps et suit toutes ses animations). Pièce sans glb : rien ne change (le héros garde sa
## tenue). Ce qu'une pièce recouvre est MASQUÉ sur le héros (copie filtrée des maillages, l'original est remis quand on l'ôte) :
##   tete  : casque, crête, camail, cheveux (la barbe et le visage restent) ;
##   torse : cotte (triangles qui ont un sommet à |x| < 0,415 : la manche au-delà, sous le coude, reste), mante, plastron, épaulières, col, tabard, pèlerine, ceinture, surcot ;
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
const TORSE_X := 0.415
## Torses à manches de mailles (armures lourdes de l'agent Y) : la cotte est coupée un peu plus loin sur l'épaule (le sommet de
## l'épaule, |x| = 0,42, ressortait de 17 à 20 mm dans le combo d'épée et le jet de sort à deux mains).
const TORSE_X_MANCHES := 0.445
const TORSES_MANCHES := ["cuirasse_fer", "cuirasse_acier_nordique", "cuirasse_gardiens", "brigandine_braise"]
const PIEDS_Y := 0.40
const PIEDS_Y_ACC := 0.58	# pans fourrés du héros au-dessus du genou (bottes hautes de l'agent Y) ; surface 0 seulement (la pèlerine reste)
const TETE_Y := 1.585
const CAPE_Y := 1.50
## Secteurs angulaires autour du bassin pour l'ourlet réel de la pièce de torse.
const SECTEURS := 16
## Masquages propres à une pièce (en plus de son emplacement) : la capuche du thaumaturge (agent Y) retombe en pèlerine sur le col de
## fourrure et la mante du héros, qui la traversaient (46 mm) quand elle est portée seule.
const MASQUES_PIECE := {"capuche_thaumaturge": ["cape"]}
const CAMAIL_Y := 1.46
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

## VARIANTE de matériau d'une pièce (champ « variante_materiau » de la fiche, ex. "enchante" pour les variantes enchantées qui
## reprennent le glb de leur pièce « base ») : ses matériaux prennent le preset `<matière>.<variante>` (MATIERES), sinon le preset
## de base avec une faible lueur (LUEUR_VARIANTE). "" = aucune.
const LUEUR_VARIANTE := 0.12
static func variante(id: String) -> String:
	return String(Inventaire.objet(id).get("variante_materiau", "")) if Inventaire.connu(id) else ""

## Pièce de base d'une variante (champ « base »), sinon l'id lui-même (chausses, tables par torse).
static func base_de(id: String) -> String:
	return String(Inventaire.objet(id).get("base", id)) if Inventaire.connu(id) else id

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
	_poser_chausses()
	_masquer()
	_habiller_fps()
	definir_vue(vue_3)

## CHAUSSES (décision du 2026-11-02) : une pièce de torse portée apporte des chausses assorties (dérivées du pantalon du héros, mêmes
## poids : sources_blender/armures/legeres/gen_legeres.py -- chausses) ; le pantalon, la cotte et les pans du héros disparaissent
## alors entièrement (plus d'étoffe qui traverse les jupes, silhouette nette). Avec des bottes, les chausses sont coupées à leur haut.
## Torse inconnu de la table : chausses de cuir.
const CHAUSSES := "res://assets/modeles/armures/chausses/"
const CHAUSSES_PAR_TORSE := {
	"armure_cuir": "cuir", "armure_fourrure": "fourrure", "cuirasse_os": "os",
	"cuirasse_fer": "fer", "cuirasse_acier_nordique": "acier", "cuirasse_gardiens": "gardiens", "brigandine_braise": "braise",
}

static func famille_chausses(id_torse: String) -> String:
	return String(CHAUSSES_PAR_TORSE.get(base_de(id_torse), "cuir")) if id_torse != "" else ""

func _poser_chausses() -> void:
	var fam := famille_chausses(porte("torse"))
	var chemin := CHAUSSES + fam + ".glb"
	var ancien: MeshInstance3D = _portees.get("jambes")
	if ancien != null and is_instance_valid(ancien):
		if String(ancien.get_meta("armure_id", "")) == "chausses_" + fam:
			return
		ancien.get_parent().remove_child(ancien)
		ancien.queue_free()
	_portees.erase("jambes")
	if fam == "" or not ResourceLoader.exists(chemin):
		return
	var mi := charger_chemin(chemin)
	if mi == null:
		return
	mi.name = "armure_jambes"
	mi.set_meta("armure_id", "chausses_" + fam)
	mi.set_meta("armure_emplacement", "jambes")
	mi.set_meta("maillage_origine", mi.mesh)
	squelette.add_child(mi)
	mi.skeleton = NodePath("..")
	_portees["jambes"] = mi

## Toutes les pièces posées (chausses comprises).
func maillages() -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	for e in _portees:
		var mi: MeshInstance3D = _portees[e]
		if is_instance_valid(mi):
			r.append(mi)
	return r

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
	return charger_chemin(chemin_porte(id), variante(id))

static func charger_chemin(chemin: String, var_mat := "") -> MeshInstance3D:
	var ps := load(chemin) as PackedScene
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
	_habiller_maillage(src, chemin, var_mat)
	return src

## Pièce posée au sol / présentoir (glb statique, pivot au sol), matériaux habillés ; null si absente.
static func instancier_sol(id: String) -> Node3D:
	if not ResourceLoader.exists(chemin_sol(id)):
		return null
	var n: Node3D = (load(chemin_sol(id)) as PackedScene).instantiate()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		_habiller_maillage(mi, chemin_sol(id), variante(id))
	n.name = "armure_sol_" + id
	return n

static func _habiller_maillage(mi: MeshInstance3D, chemin: String, var_mat := "") -> void:
	var cle := chemin + ("|" + var_mat if var_mat != "" else "")
	if not _mats.has(cle):
		var d := {}
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else "cuir"
			var tex: Texture2D = (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else null
			d[s] = materiau(nom, tex, var_mat)
		_mats[cle] = d
	var mats: Dictionary = _mats[cle]
	for s in mi.mesh.get_surface_count():
		if mats.has(s):
			mi.set_surface_override_material(s, mats[s])

## Matériau PS1 « matière » d'une pièce (texture cuite, alpha = brillance) + contour des personnages.
static func materiau(nom: String, tex: Texture2D, var_mat := "") -> ShaderMaterial:
	var p: Dictionary = MATIERES.get(nom, MATIERES["cuir"])
	if var_mat != "":
		if MATIERES.has(nom + "." + var_mat):
			p = MATIERES[nom + "." + var_mat]
		else:
			p = p.duplicate()
			p["lueur"] = maxf(float(p.get("lueur", 0.0)), LUEUR_VARIANTE)
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
	m.resource_name = "armure_" + nom + ("." + var_mat if var_mat != "" else "")
	return m

# ------------------------------------------------------------------------------------------------------------- masquage
## Zones recouvertes par les pièces réellement posées ; « cape » en plus quand la pièce de tête descend sur les épaules (capuche
## à pèlerine : son bas au repos est sous CAPE_Y) : le col de fourrure et la mante du héros passent alors dessous.
func zones() -> Array:
	var z := []
	for e in EMPLACEMENTS:
		if maillage(e) != null:
			z.append(e)
	if maillage("jambes") != null:
		z.append("jambes")
	var t := maillage("tete")
	if t != null and (t.get_aabb().position.y < CAPE_Y or MASQUES_PIECE.get(porte("tete"), []).has("cape")):
		z.append("cape")
	return z

## Limites RÉELLES des pièces portées (repos) : on ne masque que ce qu'elles recouvrent (pas de seuil global : une cuirasse courte
## ou des bottes basses laissent voir le pantalon dessous).
##   ourlets : bas de la pièce de torse PAR SECTEUR autour du bassin (16, fentes comblées), interpolé selon l'angle : la cotte, le
##             pantalon et les pans du héros sont COUPÉS à cette hauteur + 2 cm (ni trou sous un ourlet qui remonte, ni étoffe qui
##             dépasse sous un ourlet bas) ; « ourlet » = le plus haut ;
##   bottes : haut des bottes, prudent = le plus BAS des points hauts par secteur autour de chaque jambe.
func limites() -> Dictionary:
	var lim := {}
	var t := maillage("torse")
	if porte("torse") in TORSES_MANCHES:
		lim["torse_x"] = TORSE_X_MANCHES
	if t != null:
		var mins := {}
		for p: Vector3 in t.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			# hors des fentes de jupe (milieu devant / derrière, comblées par les secteurs voisins)
			if absf(p.x) < 0.26 and absf(p.x) > 0.045 and p.y < 1.1:
				var k := int(floor((atan2(p.x, p.z) + PI) / TAU * SECTEURS)) % SECTEURS
				mins[k] = minf(mins.get(k, INF), p.y)
		if not mins.is_empty():
			lim["ourlet"] = (mins.values() as Array).max()
			var h := PackedFloat32Array()
			h.resize(SECTEURS)
			for k in SECTEURS:
				if mins.has(k):
					h[k] = mins[k]
					continue
				var d := 1
				while not mins.has((k + d) % SECTEURS) and not mins.has((k - d + SECTEURS) % SECTEURS) and d < SECTEURS:
					d += 1
				h[k] = maxf(mins.get((k + d) % SECTEURS, -INF), mins.get((k - d + SECTEURS) % SECTEURS, -INF))
			lim["ourlets"] = h
	var b := maillage("pieds")
	if b != null:
		var maxs := {}
		for p: Vector3 in b.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if p.y > 0.7:
				continue
			var cx := 0.114 * signf(p.x)
			var k := int(floor((atan2(p.x - cx, p.z - 0.03) + PI) / TAU * 8.0)) + (100 if p.x > 0 else 0)
			maxs[k] = maxf(maxs.get(k, -INF), p.y)
		var h := INF
		for k in maxs:
			h = minf(h, maxs[k])
		if h < INF:
			lim["bottes"] = h
			lim["bottes_max"] = (maxs.values() as Array).max()
	return lim

func _masquer() -> void:
	var z := zones()
	var lim := limites()
	var cle_z := ",".join(z) + "|" + str(lim)
	var ch := maillage("jambes")
	if ch != null:
		var orig_ch: Mesh = ch.get_meta("maillage_origine")
		if lim.has("bottes"):
			var cle_ch := "%d|bottes|%.3f" % [orig_ch.get_instance_id(), lim["bottes"]]
			if not _filtres.has(cle_ch):
				var a := orig_ch.surface_get_arrays(0)
				var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				a = _couper(a, ix, float(lim["bottes"]) - 0.02, INF)
				var m := ArrayMesh.new()
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
				m.surface_set_material(0, orig_ch.surface_get_material(0))
				_filtres[cle_ch] = m
			ch.mesh = _filtres[cle_ch]
		else:
			ch.mesh = orig_ch
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
			_filtres[cle] = _filtrer(orig, nom, z, lim)
		mi.mesh = _filtres[cle]

## Hauteur de l'ourlet (pièce de torse) au-dessus du point p (interpolée entre secteurs).
static func ourlet_en(lim: Dictionary, p: Vector3) -> float:
	if not lim.has("ourlets"):
		return float(lim.get("ourlet", TORSE_PANTALON_Y))
	var h: PackedFloat32Array = lim["ourlets"]
	var f := (atan2(p.x, p.z) + PI) / TAU * SECTEURS - 0.5
	var k0 := int(floor(f))
	var t := f - k0
	return lerpf(h[posmod(k0, SECTEURS)], h[posmod(k0 + 1, SECTEURS)], t)

static func _concerne(nom: String, z: Array) -> bool:
	match nom:
		"tunique":
			return z.has("torse") or z.has("mains")
		"mante", "Hair_Long":
			return z.has("torse") or z.has("cape")
		"brassards", "peau":
			return z.has("mains")
		"bottes":
			return z.has("pieds")
		"pantalon":
			return z.has("pieds") or z.has("torse") or z.has("jambes")
		"accessoires":
			return true
	return false

static func _dans(r: Rect2i, u: Vector2) -> bool:
	return u.x >= r.position.x and u.y >= r.position.y and u.x < r.end.x and u.y < r.end.y

## true si le triangle (centre c au repos, centre UV u en texels de l'atlas des accessoires) est recouvert.
static func recouvert(nom: String, surface: int, c: Vector3, u: Vector2, z: Array, haut := -INF, x_min := INF, bas := INF, lim := {}) -> bool:
	if haut == -INF:
		haut = c.y
	if x_min == INF:
		x_min = absf(c.x)
	if bas == INF:
		bas = c.y
	var ourlet: float = lim.get("ourlet", TORSE_PANTALON_Y)
	var h_bottes: float = lim.get("bottes", PIEDS_Y_ACC)
	if z.has("mains") and absf(c.x) > MAINS_X and nom in ["tunique", "brassards", "peau", "accessoires"]:
		return true
	if z.has("pieds"):
		# seulement les triangles ENTIÈREMENT sous le haut des bottes portées
		if nom == "bottes":
			return true     # les bottes du héros disparaissent entièrement sous les bottes portées (sinon la semelle et la cheville percent)
		if nom == "pantalon" and haut < h_bottes - 0.015:
			return true
		if nom == "accessoires" and surface == 0 and (haut < h_bottes - 0.005 or (bas < h_bottes - 0.02 and c.y < h_bottes + 0.02)):
			return true     # revers fourrés des bottes du héros : y compris ceux qui dépassent juste au-dessus des bottes portées
		if nom == "accessoires" and surface == 1 and haut < float(lim.get("bottes_max", h_bottes)) - 0.005:
			return true     # pointe des pans (tabard) qui pend entre des bottes hautes
	var acc := nom == "accessoires" and surface == 0
	var oeil := acc and _dans(GuerrierTextures.R_OEIL, u)
	var casque := acc and (_dans(GardienTextures.R_CASQUE, u) or _dans(GardienTextures.R_BANDEAU, u))
	var camail := acc and _dans(GuerrierTextures.R_PLASTRON, u) and c.y > CAMAIL_Y
	if z.has("tete") and nom == "accessoires" and not oeil and (casque or camail or c.y > TETE_Y):
		return true
	if z.has("cape"):
		if nom == "mante":
			return true
		if acc and not oeil and not casque and c.y > 1.36 and c.y < TETE_Y and absf(c.x) < 0.34:
			return true     # col de fourrure, fibules, haut des épaulières : sous la pèlerine de la capuche
		if nom == "accessoires" and surface == 1 and c.z < 0.0:
			return true     # pèlerine du héros (dos) : elle passait à travers la pèlerine de la capuche
	if z.has("jambes"):
		# chausses portées : pantalon, cotte (hors manches) et pans du héros entièrement retirés
		if nom == "pantalon":
			return true
		if nom == "tunique" and x_min < float(lim.get("torse_x", TORSE_X)):
			return true
		if acc and not oeil and not casque and not camail and c.y > 0.40 and c.y < TETE_Y and absf(c.x) < 0.45:
			return true
	if z.has("torse"):
		if camail:
			return true     # camail du casque de base : il tombe sur le col et traverserait le haut de la pièce de torse (nuque)
		if nom == "pantalon" and bas > ourlet_en(lim, c) + 0.035:
			return true     # pantalon ENTIÈREMENT sous la pièce de torse (hanches) : il passerait au travers quand la cuisse se lève
		if nom == "tunique" and x_min < float(lim.get("torse_x", TORSE_X)) and bas > ourlet_en(lim, c) + 0.035:     # sous la pièce ; la jupe de mailles sous une cuirasse courte reste
			return true
		if nom == "mante":
			return true
		if nom == "Hair_Long" and c.y < TORSE_CHEVEUX_Y:
			return true
		if nom == "accessoires":
			if surface == 1:
				return true
			if not oeil and not casque and not camail and bas > maxf(0.40, ourlet_en(lim, c) + 0.01) and c.y < TETE_Y and absf(c.x) < 0.45:
				return true
	return false

## Copie du maillage sans les triangles recouverts (mêmes surfaces, mêmes sommets : les matériaux surchargés restent valables).
static func _filtrer(orig: Mesh, nom: String, z: Array, lim := {}) -> ArrayMesh:
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
		if nom == "pantalon" and (z.has("torse") or z.has("pieds")) and not z.has("jambes"):
			# pantalon : COUPÉ exactement aux bords des pièces (ses grands triangles traversaient l'ourlet ; les masquer entiers
			# laissait voir le fond à travers la cuisse) : on garde la tranche entre le haut des bottes et le bas de la pièce de torse
			var bas_g: float = lim.get("bottes", PIEDS_Y) - 0.02 if z.has("pieds") else -INF
			var haut_g: float = (0.02 if lim.has("ourlets") else float(lim.get("ourlet", TORSE_PANTALON_Y)) + 0.03) if z.has("torse") else INF
			a = _couper(a, idx, bas_g, haut_g, lim)
			if (a[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 0, 0])
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			m.surface_set_material(s, orig.surface_get_material(s))
			continue
		var a_couper := PackedInt32Array()
		var coupe_tunique := nom == "tunique" and z.has("torse") and not z.has("jambes")
		var torse_x: float = lim.get("torse_x", TORSE_X)
		var coupe_acc := nom == "accessoires" and s == 0 and z.has("torse") and lim.has("ourlets") and not z.has("jambes")
		for t in range(0, idx.size() - 2, 3):
			var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			if coupe_tunique and minf(absf(v[idx[t]].x), minf(absf(v[idx[t + 1]].x), absf(v[idx[t + 2]].x))) < torse_x and not (z.has("mains") and absf(c.x) > MAINS_X):
				# cotte sous la pièce de torse : coupée à l'ourlet réel (la jupe de mailles reste sous une cuirasse courte)
				a_couper.append_array([idx[t], idx[t + 1], idx[t + 2]])
				continue
			var u := Vector2.ZERO
			if not uv.is_empty():
				u = (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0 * atlas
			if coupe_acc and absf(c.x) < 0.45 and c.y < 1.2 and c.y > 0.40 and not _dans(GuerrierTextures.R_OEIL, u) \
					and minf(v[idx[t]].y, minf(v[idx[t + 1]].y, v[idx[t + 2]].y)) <= ourlet_en(lim, c) + 0.01 \
					and not (z.has("pieds") and maxf(v[idx[t]].y, maxf(v[idx[t + 1]].y, v[idx[t + 2]].y)) < float(lim.get("bottes", -INF)) - 0.005):
				a_couper.append_array([idx[t], idx[t + 1], idx[t + 2]])     # surcot, pans : coupés à l'ourlet réel
				continue
			var ys := [v[idx[t]].y, v[idx[t + 1]].y, v[idx[t + 2]].y]
			if not recouvert(nom, s, c, u, z, ys.max(), minf(absf(v[idx[t]].x), minf(absf(v[idx[t + 1]].x), absf(v[idx[t + 2]].x))), ys.min(), lim):
				garde.append(idx[t])
				garde.append(idx[t + 1])
				garde.append(idx[t + 2])
		if not a_couper.is_empty():
			a = _couper(a, a_couper, -INF, (0.01 if coupe_acc else 0.02) if lim.has("ourlets") else float(lim.get("ourlet", TORSE_PANTALON_Y)) + 0.02, lim)
			var ic: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			garde.append_array(ic)
		if garde.is_empty():
			garde = PackedInt32Array([0, 0, 0])     # surface gardée (index des matériaux surchargés), sans aire
		a[Mesh.ARRAY_INDEX] = garde
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(s, orig.surface_get_material(s))
	return m

## Découpe des triangles par les plans horizontaux y = bas et y = haut (on garde l'entre-deux) ; sommets créés interpolés (position,
## normale, tangente, couleur, UV, poids d'os mêlés et renormalisés).
static func _couper(a: Array, idx: PackedInt32Array, bas: float, haut: float, lim := {}) -> Array:
	var v: PackedVector3Array = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate() if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var tg: PackedFloat32Array = (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate() if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var col: PackedColorArray = (a[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate() if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uv: PackedVector2Array = (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate() if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var uv2: PackedVector2Array = (a[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).duplicate() if a[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var bo: PackedInt32Array = (a[Mesh.ARRAY_BONES] as PackedInt32Array).duplicate() if a[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var we: PackedFloat32Array = (a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).duplicate() if a[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var nv0 := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var nb := bo.size() / maxi(nv0, 1)
	var cache := {}
	var mi_ := func(i: int, j: int, t: float) -> int:
		var cle := Vector3(mini(i, j), maxi(i, j), snappedf(t if i < j else 1.0 - t, 0.0001))
		if cache.has(cle):
			return cache[cle]
		v.append(v[i].lerp(v[j], t))
		if not n.is_empty():
			n.append(n[i].lerp(n[j], t).normalized())
		if not tg.is_empty():
			for k in 4:
				tg.append(lerpf(tg[i * 4 + k], tg[j * 4 + k], t))
		if not col.is_empty():
			col.append(col[i].lerp(col[j], t))
		if not uv.is_empty():
			uv.append(uv[i].lerp(uv[j], t))
		if not uv2.is_empty():
			uv2.append(uv2[i].lerp(uv2[j], t))
		if nb > 0:
			var d := {}
			for k in nb:
				d[bo[i * nb + k]] = float(d.get(bo[i * nb + k], 0.0)) + we[i * nb + k] * (1.0 - t)
				d[bo[j * nb + k]] = float(d.get(bo[j * nb + k], 0.0)) + we[j * nb + k] * t
			var paires := []
			for b in d:
				paires.append([d[b], b])
			paires.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
			var somme := 0.0
			for k in mini(nb, paires.size()):
				somme += paires[k][0]
			for k in nb:
				bo.append(paires[k][1] if k < paires.size() else 0)
				we.append(paires[k][0] / maxf(somme, 1e-6) if k < paires.size() else 0.0)
		cache[cle] = v.size() - 1
		return v.size() - 1
	var sortie := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		var poly: Array = [idx[t], idx[t + 1], idx[t + 2]]
		for plan in [[bas, 1.0], [haut, -1.0]]:     # garder y >= bas, puis y <= haut (haut : + ourlet réel par secteur si lim)
			var h: float = plan[0]
			if is_inf(h) or poly.is_empty():
				continue
			var sg: float = plan[1]
			var parsecteur := sg < 0.0 and lim.has("ourlets")
			var res := []
			for k in poly.size():
				var i: int = poly[k]
				var j: int = poly[(k + 1) % poly.size()]
				var hi_ := ourlet_en(lim, v[i]) + h if parsecteur else h
				var hj_ := ourlet_en(lim, v[j]) + h if parsecteur else h
				var di := (v[i].y - hi_) * sg
				var dj := (v[j].y - hj_) * sg
				if di >= 0.0:
					res.append(i)
				if (di >= 0.0) != (dj >= 0.0):
					res.append(mi_.call(i, j, di / (di - dj)))
			poly = res
		for k in range(1, poly.size() - 1):
			sortie.append(poly[0])
			sortie.append(poly[k])
			sortie.append(poly[k + 1])
	var b := a.duplicate()
	b[Mesh.ARRAY_VERTEX] = v
	if not n.is_empty(): b[Mesh.ARRAY_NORMAL] = n
	if not tg.is_empty(): b[Mesh.ARRAY_TANGENT] = tg
	if not col.is_empty(): b[Mesh.ARRAY_COLOR] = col
	if not uv.is_empty(): b[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty(): b[Mesh.ARRAY_TEX_UV2] = uv2
	if nb > 0:
		b[Mesh.ARRAY_BONES] = bo
		b[Mesh.ARRAY_WEIGHTS] = we
	b[Mesh.ARRAY_INDEX] = sortie
	return b

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
		# gantelets des armures lourdes (rpg/armures_lourdes) : gant de cuir sombre sous les lames, plaques claires
		"fer": [Color(0.5, 0.48, 0.47), Color(0.6, 0.56, 0.52), Color(1.05, 1.05, 1.1)],
		"acier": [Color(0.56, 0.6, 0.68), Color(0.66, 0.66, 0.7), Color(1.2, 1.24, 1.32)],
		"hrafn": [Color(0.78, 0.36, 0.3), Color(0.7, 0.42, 0.36), Color(1.1, 1.1, 1.15)],   # cuir rouge sombre, ongles d'acier
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
