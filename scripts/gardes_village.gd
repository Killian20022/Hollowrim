class_name GardesVillage
extends Node
## Gardes de Skarnholt (lot D/gardes_village) : une quinzaine de gardes au village en plus de Haldor (garde nommé de la porte SO,
## inchangé, data/villageois.json). Module à part, branché par UNE ligne dans monde._villageois() : GardesVillage.peupler(self).
##   - data/gardes.json : postes fixes (2 par porte avec Haldor, longue maison, pied de la tour), vigie du beffroi, rondes (palissade,
##     rue, haute rue) en points monde, répliques communes (interpellations, nuit, après, alerte) et lignes propres à chacun ;
##   - scripts/garde_village.gd : comportement d'un garde (poste, ronde, vigie, conversation, alerte) ;
##   - ici : création des modèles (Gardien nordique entier + variante légère), niveau de détail selon la distance, alerte quand un
##     ennemi en combat entre dans l'enceinte, délai global des interpellations.
## Apparence : la livrée validée du Gardien (casque à nasal, mailles, tabard et cape bleus du jarl, lance, bouclier rond) sur TOUS les
## gardes ; seules changent la teinte de la barbe et des cheveux, celle de la peau, la barbe (rasée chez deux jeunes) et la carrure
## (taille 0,95 à 1,05, largeur ±4 %). Bouclier au bras aux postes, dans le dos en ronde. Aucune pièce d'un autre modèle.
## Nuit (19 h – 6 h 30) : les gardes de ronde allument une torche (main gauche ; lumière sans ombre, éteinte au-delà de 30 m).
## Performances : complet à moins de 22 m (IK des pieds, suivi de tête, ombre portée), allégé jusqu'à 90 m, endormi au-delà
## (caché, process coupé) ; gelés sous terre avec les villageois (groupe « villageois »).

const DONNEES := "res://data/gardes.json"
const GARDE := preload("res://scripts/garde_village.gd")
const DIST_COMPLET := 22.0
const DIST_ALLEGE := 90.0
const PAS_LOD := 0.25
const PAS_ALERTE := 0.5
const DIST_ALERTE := 18.0          # un ennemi en combat à moins de 18 m d'un garde, dans l'enceinte (+ 6 m), le met en garde
const DELAI_INTERPELLE := 14.0     # entre deux interpellations de gardes (tous gardes confondus)

## Barbes et cheveux (teinte du matériau), teints de peau (multiplicateur) : variantes des gardes, indexées par data/gardes.json.
const POILS := [Color(0.70, 0.56, 0.46), Color(1.05, 0.86, 0.55), Color(0.95, 0.55, 0.32), Color(0.42, 0.30, 0.22), Color(0.80, 0.78, 0.76), Color(0.30, 0.24, 0.20)]
const PEAUX := [Color(1, 1, 1), Color(0.93, 0.88, 0.86), Color(1.04, 0.98, 0.95), Color(0.90, 0.80, 0.74)]

var monde: Node3D
var joueur: CharacterBody3D
var gardes: Array = []
var _textes := {}
var _t_lod := 0.0
var _t_alerte := 0.0
var _t_parole := 0.0
static var _mats := {}
static var _bases := {}   # bouclier -> Gardien de référence (hors arbre, jamais affiché)
static var _cache_donnees := {}

## Lit data/gardes.json (vide si absent ou invalide).
static func donnees() -> Dictionary:
	if not _cache_donnees.is_empty():
		return _cache_donnees
	if not FileAccess.file_exists(DONNEES):
		push_warning("Gardes : fichier introuvable : " + DONNEES)
		return {}
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if not (json is Dictionary) or not (json as Dictionary).get("gardes") is Array:
		push_warning("Gardes : JSON invalide : " + DONNEES)
		return {}
	_cache_donnees = json
	return json

## Points (x, z) d'un garde : son poste, ou les points de sa ronde (le premier est le point de départ).
static func route_de(g: Dictionary) -> Array:
	var r: Array = []
	if g.has("route"):
		for p: Array in g["route"]:
			r.append(Vector2(float(p[0]), float(p[1])))
	elif g.has("pos"):
		r.append(Vector2(float(g["pos"][0]), float(g["pos"][1])))
	return r

## Crée les gardes du village (après les villageois : dialogue, joueur et village prêts). Renvoie le gestionnaire (enfant du monde).
static func peupler(monde_: Node3D) -> GardesVillage:
	var d := donnees()
	if d.is_empty() or monde_.get("village") == null:
		return null
	var gv := GardesVillage.new()
	gv.name = "GardesVillage"
	gv.monde = monde_
	gv.joueur = monde_.joueur
	gv._textes = d
	monde_.add_child(gv)
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	for g: Dictionary in d["gardes"]:
		var pts := route_de(g)
		if pts.is_empty():
			continue
		var route: Array = []
		for p: Vector2 in pts:
			route.append(Vector3(p.x, monde_.hauteur(p.x, p.y), p.y))
		var v := CharacterBody3D.new()
		v.set_script(GARDE)
		v.name = "Garde_" + String(g.get("id", "?"))
		v.donnees = g
		v.joueur = monde_.joueur
		v.dialogue = monde_.dialogue
		v.gestion = gv
		v.route = route
		v.modele = creer_modele(g)
		if g.get("type", "poste") == "vigie":
			v.position = _place_vigie(monde_.village, g)
		else:
			v.position = route[0] + Vector3(0, 0.05, 0)
		monde_.add_child(v)
		gv.gardes.append(v)
	for b: Node in _bases.values():
		if is_instance_valid(b):
			b.free()      # les copies gardent les maillages et matières partagés
	_bases.clear()
	print("Gardes : %d gardes au village (+ Haldor), créés en %d ms" % [gv.gardes.size(), (Time.get_ticks_usec() - t0) / 1000])
	return gv

## Vigie du beffroi : sur le plancher de la tour-clocher (repère TourClocher : +Z local = nord, plancher à y 11,68), côté `beffroi`.
static func _place_vigie(village: Node3D, g: Dictionary) -> Vector3:
	var tour: Node3D = village.find_child("TourClocher", true, false)
	var b: Array = g.get("beffroi", [0.0, 1.45])
	if tour == null:
		var p := route_de(g)[0] as Vector2
		return Vector3(p.x, 24.0, p.y)
	return tour.to_global(Vector3(float(b[0]), 11.68, float(b[1])))

# ======================================================================================================== apparence
## Modèle d'un garde : le Gardien nordique ENTIER (bouclier au bras aux postes, dans le dos en ronde) + variante légère.
## g : "poil" (index de POILS), "peau" (index de PEAUX), "rase" (sans barbe), "taille", "largeur".
static func creer_modele(g: Dictionary) -> Node3D:
	var bouclier: String = g.get("bouclier", "dos" if g.get("type", "poste") == "ronde" else "bras")
	# un Gardien construit par variante de bouclier (≈ 0,4 s chacun), puis copié (maillages, peaux et matières partagés)
	if not _bases.has(bouclier) or not is_instance_valid(_bases[bouclier]):
		_bases[bouclier] = GardienNordique.creer({"bouclier": bouclier, "lance": true})
	var n := (_bases[bouclier] as Node3D).duplicate() as Node3D
	n.name = "GardeSkarnholt"
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var ip := clampi(int(g.get("poil", 0)), 0, POILS.size() - 1)
	var ik := clampi(int(g.get("peau", 0)), 0, PEAUX.size() - 1)
	var barbe: MeshInstance3D = sq.get_node_or_null("Hair_Beard")
	if barbe != null:
		if g.get("rase", false):
			barbe.visible = false
		elif ip != 0:
			barbe.material_override = _mat_teinte(barbe.material_override, "barbe_%d" % ip, POILS[ip])
	var cheveux: MeshInstance3D = sq.get_node_or_null("Hair_Long")
	if cheveux != null and ip != 0:
		# cheveux un peu plus clairs que la barbe, comme le réglage du Gardien (0,78 / 0,70)
		cheveux.material_override = _mat_teinte(cheveux.material_override, "cheveux_%d" % ip, POILS[ip] * Color(1.1, 1.1, 1.05))
	var peau: MeshInstance3D = sq.get_node_or_null("peau")
	if peau != null and ik != 0 and peau.mesh != null:
		for s in peau.mesh.get_surface_count():
			var m := peau.get_surface_override_material(s)
			if m is ShaderMaterial:
				var te: Variant = (m as ShaderMaterial).get_shader_parameter("teinte")
				peau.set_surface_override_material(s, _mat_teinte(m, "peau_%d_%d" % [ik, s], (te if te is Color else Color.WHITE) * PEAUX[ik]))
	var h := clampf(float(g.get("taille", 1.0)), 0.9, 1.1)
	var l := clampf(float(g.get("largeur", 1.0)), 0.92, 1.08)
	n.scale = Vector3(h * l, h, h * l)
	return n

## Torche de garde (Torche du joueur) tenue dans la main gauche (os hand_l) ; null sans cet os. Lumière sans ombre, plus douce que celle
## du joueur, éteinte au-delà de 30 m (fondu natif de Godot).
static func equiper_torche(modele: Node3D) -> Node3D:
	var sq: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if sq == null or sq.find_bone("hand_l") < 0:
		return null
	var acc := BoneAttachment3D.new()
	acc.bone_name = "hand_l"
	sq.add_child(acc)
	var t3 := Node3D.new()
	t3.name = "TorcheGarde"
	acc.add_child(t3)
	var t := Torche.construire(t3)
	var lum: OmniLight3D = t["lumiere"]
	lum.light_energy = 1.2
	lum.omni_range = 8.0
	lum.distance_fade_enabled = true
	lum.distance_fade_begin = 24.0
	lum.distance_fade_length = 6.0
	for p: GPUParticles3D in t["flamme"]:
		p.emitting = true
	return t3

## Cale la torche dans la pose courante (bras le long du corps) : manche vertical, penché de 18° vers l'avant, poing en bas.
static func caler_torche(t3: Node3D, modele: Node3D) -> void:
	var acc := t3.get_parent() as Node3D
	var voulu := Transform3D(modele.global_basis.orthonormalized() * Basis(Vector3.RIGHT, deg_to_rad(18.0)), acc.global_position)
	t3.transform = acc.global_transform.affine_inverse() * voulu
	t3.position = t3.basis * Vector3(0, -0.04, 0.02)

## Matériau `m` dupliqué avec la teinte `c` (partagé entre gardes de même variante : clé).
static func _mat_teinte(m: Material, cle: String, c: Color) -> Material:
	if not (m is ShaderMaterial):
		return m
	if not _mats.has(cle):
		var m2 := (m as ShaderMaterial).duplicate() as ShaderMaterial
		m2.set_shader_parameter("teinte", c)
		Palette.materiaux.append(m2)
		Palette._appliquer(m2, Palette._ps1_actif)
		_mats[cle] = m2
	return _mats[cle]

# ======================================================================================================== répliques
## Une réplique commune au hasard (« interpellations », « nuit », « apres », « alerte »).
func replique(cle: String) -> String:
	var l: Array = _textes.get(cle, [])
	return str(l.pick_random()) if not l.is_empty() else ""

func de_nuit() -> bool:
	var c: Node = monde.get("cycle") if monde != null else null
	if c == null:
		return false
	var h := float(c.heure)
	return h >= 19.0 or h < 6.5

## Un seul garde interpelle à la fois (sinon la quinzaine de gardes couvrirait les villageois).
func peut_interpeller() -> bool:
	if _t_parole > 0.0:
		return false
	_t_parole = DELAI_INTERPELLE
	return true

func _process(dt: float) -> void:
	_t_parole -= dt
	if joueur == null or not is_instance_valid(joueur):
		return
	if monde.get("_sous_terre_actif"):
		return   # sous terre, le monde gèle tout le groupe « villageois »
	_t_lod -= dt
	if _t_lod <= 0.0:
		_t_lod = PAS_LOD
		var pj := joueur.global_position
		var nuit := de_nuit()
		for g: Node3D in gardes:
			if not is_instance_valid(g):
				continue
			var d := pj.distance_to(g.global_position)
			g.regler_lod(0 if d < DIST_COMPLET else (1 if d < DIST_ALLEGE else 2))
			g.regler_torche(nuit)
	_t_alerte -= dt
	if _t_alerte <= 0.0:
		_t_alerte = PAS_ALERTE
		_alertes()

## Ennemis en combat dans l'enceinte (ou à ses abords) : chaque garde éveillé à moins de DIST_ALERTE de l'un d'eux lui fait face.
func _alertes() -> void:
	var menaces: Array = []
	for e: Node in get_tree().get_nodes_in_group("ennemis"):
		var n3 := e as Node3D
		if n3 == null or not n3.is_inside_tree() or not e.has_method("en_combat") or not e.en_combat():
			continue
		if e.has_method("vivant") and not e.vivant():
			continue
		var p := n3.global_position
		if ReliefVillage.dans_enceinte(p.x, p.z, 6.0):
			menaces.append(n3)
	for g: Node3D in gardes:
		if not is_instance_valid(g):
			continue
		if g.lod == 2:
			g.alerter(null)
			continue
		var proche: Node3D = null
		var dmin := DIST_ALERTE
		for e: Node3D in menaces:
			var d := e.global_position.distance_to(g.global_position)
			if d < dmin:
				dmin = d
				proche = e
		g.alerter(proche)
