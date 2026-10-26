class_name CrypteDecor
extends RefCounted
## Décor de la crypte (lot 7a) : structure modulaire, mobilier, petits objets, lumières.
##
## Principes (règles de l'utilisateur + bible) :
## - grille de 1, 2 et 4 m ; les surfaces sont des quads par morceaux de 4 m au plus ; UV = position en mètres
##   divisée par la taille de tuile → densité de texels UNIFORME (mesurée le 2026-10-26 : 128 texels/m murs, dalles et pierre v2, 64 pour la
##   voûte et pour tous les objets — bois, fer, lame, gravure, argile, os, parchemin, tissus laine/lin/jute — comme les maisons C7b) ;
## - le maillage est fusionné par cellule de 8 m et par matériau : peu d'appels de dessin, culling par cellule, et
##   moins de 8 lumières par objet (limite du renderer mobile) ;
## - aucune collision n'est ajoutée au passage du joueur : les collisions d'origine (sol, plafond, murs, linteaux,
##   piliers, estrade, sarcophage) sont refaites à l'identique ; seules quelques pièces contre les murs en ont une ;
## - lumières : OmniLight3D courtes et fortement atténuées, sans ombre ; flammes = sprites pixel art animés ;
##   halos = cartes additives à anneaux posterisés (net, pas de glow).

const CASE := 8.0
const FEU := Color(1.0, 0.56, 0.24)

const TUILE := {
	"mur0": 4.0, "mur1": 4.0, "mur2": 4.0, "dalle0": 4.0, "dalle1": 4.0, "voute": 4.0,
	"bois": 2.0, "fer": 1.0, "lame": 1.0, "gravure": 2.0, "argile": 1.0, "os": 1.0, "parchemin": 1.0, "laine": 1.0, "lin": 1.0, "jute": 1.0,
	"toile": 1.0, "noir": 1.0, "halo": 1.0, "halo_f": 1.0, "rai": 1.0, "braise": 1.0,
	# donjon (agrandissement) : pierre givrée / glace, ossuaire, or
	"mur3": 4.0, "mur4": 4.0, "dalle3": 4.0, "dalle4": 4.0, "ossuaire": 4.0, "or": 0.5, "neige": 2.0,
	"entrelacs": 1.0, "sceau": 1.0, "brume": 1.0,
	# crypte v2 : dalles irrégulières, pierre nue des modules Blender, givre en décalque
	"dalle_v2": 4.0, "pierre_v2": 2.0, "statue_v2": 2.0, "givre_sol": 1.0, "flaque": 1.0, "flaque_bord": 1.0, "flaque_reflet": 1.0,
}
## Refonte « crypte matière » (références grottes_cryptes_2/3) : feu plus orangé, ambiant écrasé dans les matériaux de la crypte
## (ombres presque noires, la torche et les braseros gardent toute leur force). La grotte (GrotteDecor) garde les anciennes valeurs.
## Préréglages de DIRECTION_ARTISTIQUE §6 (torche, brasero, bougie, rune) ; ambiant ramené vers « Ambiance donjon » (≈ x 0,45).
# 4e passe : feu ambré (plus de vert) — le rouge-orangé de la torche + le bleu de l'ambiant (sans vert) donnaient une pierre ROSÉE
const FEU_CRYPTE := Color(1.0, 0.66, 0.36)       # torche
const FEU_BRASERO := Color(1.0, 0.62, 0.32)
## Pierre de la crypte : léger filtre vert-neutre (coupe un peu le rouge du feu et le bleu de l'ambiant) → brun-gris froid hors des flaques.
const TEINTE_PIERRE := Color(0.82, 0.97, 0.93)
const PIERRE_NEUTRE := ["mur0", "mur1", "mur2", "mur3", "dalle0", "dalle1", "dalle3", "voute", "ossuaire", "gravure", "entrelacs", "dalle_v2", "pierre_v2"]
const FEU_BOUGIE := Color(1.0, 0.66, 0.36)
const RUNE := Color(0.35, 0.80, 1.0)
const AMBIANT_CRYPTE := 1.6
const AMBIANT_V2 := 2.6              # crypte v2 : pierre des modules Blender et dalles irrégulières
const TEINTE_PIERRE_V2 := Color(1.0, 1.12, 1.18)
## C4 (2026-10-23) : statues un peu mieux éclairées SANS lumière de plus (budget : 7 par salle, 8 par maillage) : leur pierre reçoit
## plus d'ambiant (la silhouette se détache dans l'ombre bleue) et une teinte un peu plus claire et chaude que les murs.
const AMBIANT_STATUE := 4.4
const TEINTE_STATUE := Color(1.12, 1.16, 1.18)
## C4b (2026-10-23) : les statues restaient des silhouettes sombres là où le budget de lumières ne laisse pas de spot. Leur pierre reçoit
## une « lueur » d'hémisphère calculée dans le shader (aucune lumière, quelques instructions) : froide d'en haut (le bleu de la crypte
## sur la capuche et les épaules), tiède d'en bas (reflet des bougies du socle), modulée par l'albédo et l'occlusion cuite → plis et
## capuche se lisent dans l'ombre, comme sur la planche (vues 1, 4, 6).
const LUEUR_STATUE_HAUT := Vector3(0.11, 0.14, 0.2)
const LUEUR_STATUE_BAS := Vector3(0.05, 0.028, 0.012)
## Matières qui réutilisent la texture d'une autre (même dessin, réglages d'éclairage différents).
const ALIAS_TEXTURE := {"statue_v2": "pierre_v2"}
const GAIN_LUMIERE := 1.7          # pierre plus sombre (rampe donjon) : les feux portent plus loin et plus fort
const GRILLE_CRYPTE := 180.0      # accroche des sommets : H / 2 à 640 x 360 (DIRECTION_ARTISTIQUE §3)

const CRYPTE_SHADER := preload("res://shaders/crypte.gdshader")
const FLAMME_SHADER := preload("res://shaders/crypte_flamme.gdshader")

var racine: Node3D
var corps: StaticBody3D
var rng := RandomNumberGenerator.new()

var _mats := {}
var _tex := {}
var _bufs := {}
var _fait := {}
var lumieres: Array = []       # [OmniLight3D, énergie, phase]
var toutes: Array = []         # toutes les OmniLight3D du décor (allumées selon la position du joueur, voir tertre.gd)
var pos_lum: Dictionary = {}   # OmniLight3D -> [position, portée] notées à la pose (lumiere_possible les lit depuis le fil du donjon sans toucher aux nœuds déjà dans l'arbre)
var _flammes_def: Array = []    # [position, échelle, phase] : fusionnées en MultiMesh par cellule dans finir()
var _nb_pieces := 0
## Donjon : remplace une matière par une autre dans quad() (« mur0 » -> « mur4 » : tout un décor passe en glace d'un coup).
var theme := {}
## Hauteur du sol sous les sommets, codée dans l'alpha de la couleur de sommet (1 + y/20, y relatif au sol de la crypte) :
## le shader en tire la bande de crasse du pied de mur, pour les étages et les escaliers.
var niveau_a := 1.0
## Transformation courante (kit de donjon) : un module est écrit en repère LOCAL (centre de la salle, +z vers le sud) ; `xf` le pose dans le
## repère de la crypte (translation, quarts de tour, miroir gauche/droite). Tout passe par quad(), solide(), lumiere(), flamme()… qui l'appliquent.
var xf := Transform3D.IDENTITY

const RELIEF := {"entrelacs": 1.0, "mur0": 0.75, "mur1": 0.75, "mur2": 0.75, "dalle0": 0.8, "dalle1": 0.8, "voute": 0.7, "bois": 0.8, "fer": 0.7, "gravure": 1.0,
	"mur3": 0.8, "mur4": 0.9, "dalle3": 0.8, "dalle4": 0.9, "ossuaire": 1.0, "dalle_v2": 0.85, "pierre_v2": 0.7, "statue_v2": 0.7}
const AVEC_MIPS := ["mur0", "mur1", "mur2", "dalle0", "voute", "bois", "fer", "lame", "gravure", "argile", "os", "parchemin", "toile", "laine", "lin", "jute",
	"mur3", "mur4", "dalle3", "dalle4", "ossuaire", "or", "neige", "entrelacs", "dalle_v2", "pierre_v2", "statue_v2", "givre_sol"]
const SANS_MIPS := ["halo", "rai", "flamme"]

## Crypte v2 (C4) : réglages du module en cours, posés par DonjonKit.module() (remis à zéro après chaque module).
var v2 := false                 # le module en cours est en style v2 : pilier, arc, sarcophage, statue passent par les modules Blender
var module_id := ""             # identifiant du module en cours (étiquette des emplacements d'eau)
var saillie_cb := Callable()    # (point local, normale) -> décalage : les objets accrochés au mur avancent devant les panneaux de maçonnerie
var nb_bannieres := 0           # bannières posées (le kit v2 n'en ajoute pas dans une salle qui en a déjà)
var occupations: Array = []     # [point local, demi-largeur] : objets plaqués au mur (râteliers, étagères, panneaux d'os) que les panneaux v2 évitent
var est_crypte := false   # vrai pour la crypte elle-même (pas pour GrotteDecor, qui hérite de cette classe)
## RNG des détails ajoutés par la refonte matière (givre, glaçons, niches, lustres…) : séparé de `rng` pour ne pas déplacer
## le décor existant (gravats à collision, statues) tiré après eux.
var rng_deco := RandomNumberGenerator.new()

# ------------------------------------------------------------------ registre d'audit (outils/audit_interpenetrations.gd)
## Rempli SEULEMENT quand `CrypteDecor.audit_actif` est vrai (l'outil d'audit le pose avant de bâtir le lieu) : tout ce qui est écrit
## entre objet_debut(genre, id) et objet_fin() forme un objet (sommets + solides) ; les appels imbriqués se fondent dans l'objet le
## plus extérieur. Hors audit : un test d'entier par triangle, rien d'autre (rendu et collisions inchangés).
static var audit_actif := false
var objets_audit: Array = []          # {"genre", "id", "v": PackedVector3Array (triangles, repère du lieu), "solides": Array[AABB]}
var _obj_n := 0                       # profondeur d'imbrication (0 = aucun objet ouvert)
var _obj_genre := ""
var _obj_id := ""
var _obj_v := PackedVector3Array()
var _obj_s: Array = []

func objet_debut(genre: String, id := "") -> void:
	if not audit_actif:
		return
	if _obj_n == 0:
		_obj_genre = genre
		_obj_id = id
		_obj_v = PackedVector3Array()
		_obj_s = []
	_obj_n += 1

func objet_fin() -> void:
	if _obj_n == 0:
		return
	_obj_n -= 1
	if _obj_n == 0 and (not _obj_v.is_empty() or not _obj_s.is_empty()):
		objets_audit.append({"genre": _obj_genre, "id": _obj_id, "v": _obj_v, "solides": _obj_s})
		_obj_v = PackedVector3Array()
		_obj_s = []

func _audit_solide(centre: Vector3, taille: Vector3) -> void:
	_obj_s.append(AABB(centre - taille * 0.5, taille))

var _taches := {}    # nom -> id de tâche ; les images sont peintes dans des fils d'exécution pendant que le plan se construit
var _images := {}    # nom -> Image (tableau d'un seul élément par tâche : pas d'écriture concurrente dans un même conteneur)

## Journal des objets posés (outils/audit_interpenetrations.gd --lieu=crypte) : INACTIF en jeu (une comparaison d'entier par quad).
## Chaque objet de haut niveau (sarcophage, urne, statue, module Blender…) encadré par j0()/j1() laisse une entrée :
## {t: type, mod: module, lacet: lacet du repère de mesure, min/max: bornes des sommets DANS ce repère (repère de la crypte tourné),
##  cs: collisions créées par l'objet}. Les objets imbriqués (bougies d'un autel, socle d'une statue) comptent dans l'objet extérieur.
static var journal_actif := false
const SANS_BORNES := ["halo", "halo_f", "rai", "brume", "flamme"]      # cartes additives : ne comptent pas dans l'encombrement
var journal: Array = []
var _j_prof := 0
var _j_cur: Dictionary = {}
var _j_inv := Basis.IDENTITY
var _j_min := Vector3.ZERO
var _j_max := Vector3.ZERO
var _j_n := 0
var _j_cases := {}           # grands modules Blender (arches, degrés, panneaux) : bornes par case de 1 m du repère de l'objet (forme creuse lisible)

## Emprises au sol du module en cours (repère LOCAL du module, remis à zéro avec `occupations`) : chaque meuble ou objet posé au sol
## y note sa boîte (centre, demi-tailles x/z dans son repère, lacet, haut). Sert à ne rien poser DANS un objet déjà là (décor tiré au
## hasard, éléments v2), et aux panneaux / piliers engagés v2 qui contournent ce qui est adossé au mur (audit des interpénétrations).
var emprises: Array = []        # [Vector3 centre (y = sol), Vector2 demi, lacet, haut, type]
var voisin: CrypteDecor = null  # décor partagé (le donjon voit les lumières du tertre : limite de 8 par maillage)
var muet := false               # vrai : les primitives tirent leurs nombres mais n'émettent rien (DonjonKit.differer)

var murs_cb := Callable()       # (pos locale, demi-tailles, lacet) -> décalage : écarte un meuble du soubassement (DonjonKit._ecart_murs)

var _poussees: Array = []       # [position d'origine, décalage, demi-tailles, lacet] des meubles écartés du mur (module en cours)

## Petit objet posé SUR un meuble écarté du mur (bougie sur un autel, crâne sur une table…) : suit le meuble.
func _suivre(pos: Vector3) -> Vector3:
	for e: Array in _poussees:
		var o: Vector3 = e[0]
		if pos.y > o.y + 0.2 and pos.y < o.y + 2.5 and dist_emprise([o, (e[2] as Vector2) + Vector2(0.08, 0.08), e[3]], pos) <= 0.0:
			return pos + (e[1] as Vector3)
	return pos

## Meuble posé contre un mur : avancé juste assez pour que son dos ne rentre pas dans le soubassement ni dans le mur (audit 2026-10-23).
func _ecarter(pos: Vector3, demi: Vector2, lacet := 0.0) -> Vector3:
	if muet or not murs_cb.is_valid():
		return pos
	var dec: Vector3 = murs_cb.call(pos, demi, lacet)
	if dec != Vector3.ZERO:
		_poussees.append([pos, dec, demi, lacet])
	return pos + dec

## Ajouter une lumière (repère de la crypte, portée R) garde-t-il chaque maillage de 8 m qu'elle touche à 8 lumières au plus ?
## (les maillages fusionnés sont découpés en cases de 8 m, comme _buf ; test_crypte vérifie la même règle)
func lumiere_possible(p: Vector3, R: float, maxi_ := 8) -> bool:
	var toutes_l: Array = toutes.duplicate()
	if voisin != null:
		toutes_l.append_array(voisin.toutes)
	for cx in range(floori((p.x - R) / CASE), floori((p.x + R) / CASE) + 1):
		for cz in range(floori((p.z - R) / CASE), floori((p.z + R) / CASE) + 1):
			var cell := AABB(Vector3(cx * CASE, p.y - 3.0, cz * CASE), Vector3(CASE, 6.0, CASE))
			var q := Vector3(clampf(p.x, cell.position.x, cell.end.x), p.y, clampf(p.z, cell.position.z, cell.end.z))
			if q.distance_to(p) > R:
				continue
			var n := 1
			for l: OmniLight3D in toutes_l:
				# position et portée notées à la pose : les lumières du voisin (tertre) sont dans l'arbre, illisibles depuis le fil du donjon
				var info: Array = pos_lum.get(l, voisin.pos_lum.get(l, []) if voisin != null else [])
				if info.is_empty():
					continue     # toute lumière passe par ajouter_lumiere : jamais de lecture de nœud ici (fil du donjon)
				var lp: Vector3 = info[0]
				var portee: float = info[1]
				var ql := Vector3(clampf(lp.x, cell.position.x, cell.end.x), clampf(lp.y, cell.position.y, cell.end.y), clampf(lp.z, cell.position.z, cell.end.z))
				if ql.distance_to(lp) <= portee:
					n += 1
			if n > maxi_:
				return false
	return true

func emprise(type: String, pos: Vector3, demi: Vector2, lacet := 0.0, haut := 1.0) -> void:
	if muet:
		return
	emprises.append([pos, demi, lacet, haut, type])

## Distance horizontale d'un point au bord d'une emprise (0 si dedans).
static func dist_emprise(e: Array, p: Vector3) -> float:
	var c: Vector3 = e[0]
	var dm: Vector2 = e[1]
	var b := Basis(Vector3.UP, -float(e[2]))
	var q := b * Vector3(p.x - c.x, 0.0, p.z - c.z)
	var dx := maxf(0.0, absf(q.x) - dm.x)
	var dz := maxf(0.0, absf(q.z) - dm.y)
	return sqrt(dx * dx + dz * dz)

## Un disque de rayon r centré en p (repère local) ne touche aucune emprise (à `marge` près) ; `sauf` : types ignorés.
func emprise_libre(p: Vector3, r: float, marge := 0.05, sauf: Array = []) -> bool:
	for e: Array in emprises:
		if absf(float((e[0] as Vector3).y) - p.y) > 2.0 or e[4] in sauf:
			continue
		if dist_emprise(e, p) < r + marge:
			return false
	return true

func j0(type: String, lacet := 0.0) -> void:
	objet_debut(type)      # registre commun de l'outil d'audit (branche grotte)
	if not journal_actif or muet:
		return
	_j_prof += 1
	if _j_prof > 1:
		return
	var f := xf.basis * Vector3(sin(lacet), 0.0, cos(lacet))
	var lw := atan2(f.x, f.z)
	_j_inv = Basis(Vector3.UP, -lw)
	_j_min = Vector3(INF, INF, INF)
	_j_max = Vector3(-INF, -INF, -INF)
	_j_cur = {"t": type, "mod": module_id, "lacet": lw, "n0": corps.get_child_count(), "gid": _j_n}
	_j_n += 1
	_j_cases = {}

func j1() -> void:
	objet_fin()
	if not journal_actif or muet or _j_prof <= 0:
		return
	_j_prof -= 1
	if _j_prof > 0 or _j_min.x == INF:
		return
	_j_cur["min"] = _j_min
	_j_cur["max"] = _j_max
	var cs: Array = []
	var enf := corps.get_children()
	for i in range(int(_j_cur["n0"]), enf.size()):
		cs.append(enf[i])
	_j_cur["cs"] = cs
	if _j_cases.is_empty():
		journal.append(_j_cur)
		return
	for k in _j_cases:
		var e := _j_cur.duplicate()
		e["min"] = _j_cases[k][0]
		e["max"] = _j_cases[k][1]
		e["partie"] = true
		e["gmin"] = _j_min
		e["gmax"] = _j_max
		journal.append(e)

func _jtri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var qa := _j_inv * a
	var qb := _j_inv * b
	var qc := _j_inv * c
	var m := (qa + qb + qc) / 3.0
	var k := Vector2i(floori(m.x), floori(m.z))
	var bc: Array = _j_cases.get(k, [])
	if bc.is_empty():
		bc = [qa, qa]
		_j_cases[k] = bc
	bc[0] = (bc[0] as Vector3).min(qa).min(qb).min(qc)
	bc[1] = (bc[1] as Vector3).max(qa).max(qb).max(qc)
	_j_min = _j_min.min(qa).min(qb).min(qc)
	_j_max = _j_max.max(qa).max(qb).max(qc)

func _jp(p: Vector3) -> void:
	var q := _j_inv * p
	_j_min = _j_min.min(q)
	_j_max = _j_max.max(q)

func _init(parent: Node3D, solide: StaticBody3D, partage: CrypteDecor = null) -> void:
	racine = parent
	corps = solide
	rng.seed = 7007
	est_crypte = get_script() == CrypteDecor
	rng_deco.seed = 4242
	voisin = partage
	if partage != null:
		# second décor (le donjon, bâti dans un fil d'exécution) : mêmes images, déjà peintes ; ses propres matériaux
		partage.attendre_tout()
		_images = partage._images
		_tex = partage._tex.duplicate()
		rng.seed = 7013
		return
	for nom in AVEC_MIPS + SANS_MIPS:
		var cible: Array = [null]
		_images[nom] = cible
		_taches[nom] = WorkerThreadPool.add_task(_peindre.bind(nom, cible))

func _peindre(nom: String, cible: Array) -> void:
	# précalculées par outils/generer_crypte.gd dans assets/crypte/*.res (version vérifiée) ; repli : calcul
	var base := "%s/%s" % [CrypteTextures.DOSSIER, nom]
	if ResourceLoader.exists(base + ".res"):
		var a: Image = ResourceLoader.load(base + ".res")
		if a != null and a.get_meta("version", -1) == CrypteTextures.VERSION:
			cible[0] = a
			cible.append(ResourceLoader.load(base + "_nm.res") if ResourceLoader.exists(base + "_nm.res") else null)
			return
	var paire := CrypteTextures.paire(nom)
	cible[0] = CrypteTextures.mips_image(paire[0]) if nom in AVEC_MIPS else paire[0]
	cible.append(paire[1])      # carte de pentes (ou null) ; ses mipmaps linéaires sont déjà générées

func _attendre(nom: String) -> void:
	if _taches.has(nom):
		FilVerrou.attendre(_taches[nom])
		_taches.erase(nom)

func attendre_tout() -> void:
	for nom in _taches.keys():
		_attendre(nom)

# ------------------------------------------------------------------ matériaux
func mat(nom: String) -> Material:
	if _mats.has(nom):
		return _mats[nom]
	var m: Material
	match nom:
		"noir":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(0.015, 0.02, 0.03)
			m = s
		"braise":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(1.0, 0.42, 0.1)
			m = s
		"sceau":
			var s := StandardMaterial3D.new()        # runes et sceaux magiques : bleu froid lumineux (seul accent bleu saturé)
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(0.25, 0.82, 0.82)    # rampe « Runes cyan » (#3fd0d0)
			m = s
		"brume":
			var s := StandardMaterial3D.new()        # nappes de brume au ras du sol : cartes additives très faibles
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			s.albedo_texture = _texture("halo")
			s.albedo_color = Color(0.16, 0.2, 0.26)
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.disable_receive_shadows = true
			m = s
		"flaque", "flaque_bord", "flaque_reflet":
			var s := StandardMaterial3D.new()        # PLACEHOLDER de l'eau (crypte v2) : l'eau stylisée viendra du système d'eau (branche eau/prototype)
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = {"flaque": Color(0.05, 0.1, 0.16), "flaque_bord": Color(0.13, 0.17, 0.22), "flaque_reflet": Color(0.3, 0.42, 0.56)}[nom]
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.disable_receive_shadows = true
			m = s
		"halo", "rai", "halo_f":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			s.albedo_texture = _texture("halo" if nom == "halo_f" else nom)
			if nom == "halo_f":
				s.albedo_color = Color(0.35, 0.6, 1.0)
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.no_depth_test = false
			s.disable_receive_shadows = true
			m = s
		_:
			var sm := ShaderMaterial.new()
			if nom == "mur4" or nom == "dalle4":
				sm.set_shader_parameter("emission", Vector3(0.012, 0.034, 0.056))     # la glace garde un fond bleu dans le noir
			elif nom == "or":
				sm.set_shader_parameter("emission", Vector3(0.03, 0.02, 0.003))
				sm.set_shader_parameter("crasse", 0.0)
				sm.set_shader_parameter("teinte", Color(0.7, 0.64, 0.58))
			var sh := CRYPTE_SHADER
			if nom == "givre_sol":
				var s3 := Shader.new()
				s3.code = CRYPTE_SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
				sh = s3
				sm.set_shader_parameter("decoupe", 0.5)
				sm.set_shader_parameter("crasse", 0.0)
				sm.set_shader_parameter("emission", Vector3(0.012, 0.02, 0.03))
			if nom == "toile":
				var s2 := Shader.new()
				s2.code = CRYPTE_SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
				sh = s2
				sm.set_shader_parameter("decoupe", 0.5)
				sm.set_shader_parameter("crasse", 0.0)
				sm.set_shader_parameter("emission", Vector3(0.06, 0.08, 0.1))
			sm.shader = sh
			var nom_tex: String = ALIAS_TEXTURE.get(nom, nom)
			sm.set_shader_parameter("tex_base", _texture(nom_tex))
			var nm := _pentes(nom_tex)
			if nm != null:
				sm.set_shader_parameter("tex_nm", nm)
				sm.set_shader_parameter("relief", RELIEF.get(nom, 1.0))
			if nom == "fer" or nom == "lame":
				sm.set_shader_parameter("crasse", 0.0)
			if est_crypte:
				sm.set_shader_parameter("ambiant", AMBIANT_CRYPTE)
				sm.set_shader_parameter("grille", GRILLE_CRYPTE)
				if nom == "neige":
					sm.set_shader_parameter("emission", Vector3(0.0, 0.0, 0.0))
					sm.set_shader_parameter("crasse", 0.0)
				elif nom == "mur4":
					sm.set_shader_parameter("emission", Vector3(0.012, 0.03, 0.05))
				if nom in PIERRE_NEUTRE:
					sm.set_shader_parameter("teinte", TEINTE_PIERRE)
				if nom == "pierre_v2" or nom == "dalle_v2":      # crypte v2 : plus de fond bleuté (planche : pierre lisible dans l'ombre)
					sm.set_shader_parameter("ambiant", AMBIANT_V2)
					sm.set_shader_parameter("teinte", TEINTE_PIERRE_V2)
				elif nom == "statue_v2":
					sm.set_shader_parameter("ambiant", AMBIANT_STATUE)
					sm.set_shader_parameter("teinte", TEINTE_STATUE)
					sm.set_shader_parameter("lueur_haut", LUEUR_STATUE_HAUT)     # C4b : modelé lisible sans lumière (voir LUEUR_STATUE_HAUT)
					sm.set_shader_parameter("lueur_bas", LUEUR_STATUE_BAS)
			m = sm
	_mats[nom] = m
	return m

func _pentes(nom: String) -> ImageTexture:
	_attendre(nom)
	var cible: Array = _images[nom]
	if cible.size() < 2 or cible[1] == null:
		return null
	return ImageTexture.create_from_image(cible[1])

func _texture(nom: String) -> ImageTexture:
	if not _tex.has(nom):
		_attendre(nom)
		var cible: Array = _images[nom]
		_tex[nom] = ImageTexture.create_from_image(cible[0])    # halo, rai, flamme : sans mipmaps (alpha en paliers)
	return _tex[nom]

# ------------------------------------------------------------------ accumulateur de maillage
## Index rapide (matière → case → tampon) : évite de formater une clé texte à chaque quad (le bâti du donjon en fait ~200 000).
var _bufs_vite := {}

func _buf(c: Vector3, nom: String) -> Dictionary:
	var k := Vector3i(floori(c.x / CASE), floori(c.z / CASE), 1 if c.y < -3.0 else 0)      # l'étage inférieur a ses propres maillages
	var par_nom: Dictionary = _bufs_vite.get(nom, {})
	if par_nom.is_empty():
		_bufs_vite[nom] = par_nom
	var b: Dictionary = par_nom.get(k, {})
	if b.is_empty():
		var cle := "%d,%d,%d|%s" % [k.x, k.y, k.z, nom]
		if not _bufs.has(cle):
			_bufs[cle] = {"nom": nom, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}
		b = _bufs[cle]
		par_nom[k] = b
	return b

func _uv(p: Vector3, n: Vector3, tuile: float) -> Vector2:
	var a := n.abs()
	var uv: Vector2
	if a.y >= a.x and a.y >= a.z:
		uv = Vector2(p.x, p.z)
	elif a.x >= a.z:
		uv = Vector2(p.z, -p.y)
	else:
		uv = Vector2(p.x, -p.y)
	return uv / tuile

func _tri(b: Dictionary, a: Vector3, bb: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ca := Color.WHITE, cb := Color.WHITE, cc := Color.WHITE) -> void:
	if muet:
		return
	var geo := (bb - a).cross(c - a)
	var v: PackedVector3Array = b["v"]
	var nn: PackedVector3Array = b["n"]
	var uu: PackedVector2Array = b["u"]
	var co: PackedColorArray = b["c"]
	if _obj_n > 0:
		_obj_v.append(a); _obj_v.append(bb); _obj_v.append(c)
	if niveau_a != 1.0:
		ca.a *= niveau_a
		cb.a *= niveau_a
		cc.a *= niveau_a
	if geo.dot(n) > 0.0:    # Godot : face avant = sens horaire
		v.append(a); v.append(c); v.append(bb)
		uu.append(ua); uu.append(uc); uu.append(ub)
		co.append(ca); co.append(cc); co.append(cb)
	else:
		v.append(a); v.append(bb); v.append(c)
		uu.append(ua); uu.append(ub); uu.append(uc)
		co.append(ca); co.append(cb); co.append(cc)
	nn.append(n); nn.append(n); nn.append(n)

## Quad a-b-c-d (ordre de contour), normale n ; UV imposés ou calculés depuis les positions p_uv.
func quad(nom_: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uvs: Array = [], p_uv: Array = [], cols: Array = []) -> void:
	if muet:
		return
	if uvs.is_empty() and cols.is_empty():
		if p_uv.is_empty():
			_quad_p(nom_, a, b, c, d, n, a, b, c, d)
		else:
			_quad_p(nom_, a, b, c, d, n, p_uv[0], p_uv[1], p_uv[2], p_uv[3])
		return
	var nom: String = theme.get(nom_, nom_) if not theme.is_empty() else nom_
	var t: float = TUILE.get(nom, 1.0)
	var u: Array = uvs
	if u.is_empty():
		var pp: Array = p_uv if not p_uv.is_empty() else [a, b, c, d]
		u = [_uv(pp[0], n, t), _uv(pp[1], n, t), _uv(pp[2], n, t), _uv(pp[3], n, t)]
	if xf != Transform3D.IDENTITY:        # UV calculés en repère local (texture continue dans le module), sommets posés ensuite
		a = xf * a
		b = xf * b
		c = xf * c
		d = xf * d
		n = xf.basis * n
	var centre := (a + b + c + d) * 0.25
	if _j_prof > 0 and not nom in SANS_BORNES:
		_jp(a); _jp(b); _jp(c); _jp(d)
	var buf := _buf(centre, nom)
	if cols.is_empty():
		cols = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	_tri(buf, a, b, c, n, u[0], u[1], u[2], cols[0], cols[1], cols[2])
	_tri(buf, a, c, d, n, u[0], u[2], u[3], cols[0], cols[2], cols[3])

## Chemin rapide de quad() (le plus fréquent : UV tirés des positions pa..pd, sommets blancs) : aucun tableau temporaire,
## les deux triangles écrits d'un coup. Même résultat, sommet pour sommet, que quad().
## `n_uv` : normale qui choisit la projection des UV, dans le MÊME repère que pa..pd (boîte tournée : normale non tournée) ;
## par défaut `n` (UV tirés des positions posées).
func _quad_p(nom_: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, pa: Vector3, pb: Vector3, pc: Vector3, pd: Vector3, n_uv := Vector3.ZERO) -> void:
	if muet:
		return
	var nom: String = theme.get(nom_, nom_) if not theme.is_empty() else nom_
	var t: float = TUILE.get(nom, 1.0)
	var np := n if n_uv == Vector3.ZERO else n_uv
	var ua := _uv(pa, np, t)
	var ub := _uv(pb, np, t)
	var uc := _uv(pc, np, t)
	var ud := _uv(pd, np, t)
	if xf != Transform3D.IDENTITY:
		a = xf * a
		b = xf * b
		c = xf * c
		d = xf * d
		n = xf.basis * n
	if _j_prof > 0 and not nom in SANS_BORNES:
		_jp(a); _jp(b); _jp(c); _jp(d)
	if _obj_n > 0:
		_obj_v.append(a); _obj_v.append(b); _obj_v.append(c); _obj_v.append(a); _obj_v.append(c); _obj_v.append(d)
	var buf := _buf((a + b + c + d) * 0.25, nom)
	var v: PackedVector3Array = buf["v"]
	var nn: PackedVector3Array = buf["n"]
	var uu: PackedVector2Array = buf["u"]
	var co: PackedColorArray = buf["c"]
	var w := Color(1, 1, 1, niveau_a)
	if (b - a).cross(c - a).dot(n) > 0.0:
		v.append(a); v.append(c); v.append(b)
		uu.append(ua); uu.append(uc); uu.append(ub)
	else:
		v.append(a); v.append(b); v.append(c)
		uu.append(ua); uu.append(ub); uu.append(uc)
	if (c - a).cross(d - a).dot(n) > 0.0:
		v.append(a); v.append(d); v.append(c)
		uu.append(ua); uu.append(ud); uu.append(uc)
	else:
		v.append(a); v.append(c); v.append(d)
		uu.append(ua); uu.append(uc); uu.append(ud)
	for k in 6:
		nn.append(n)
		co.append(w)

const _FACES := [
	[Vector3.RIGHT, [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
	[Vector3.LEFT, [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
	[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3.DOWN, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
	[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
	[Vector3.FORWARD, [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
]

## Boîte pleine (6 faces) ; UV = position en mètres dans le repère de la boîte (points NON tournés + `decal`), projection choisie
## avec la normale NON tournée (L0 2026-10-26 : la normale tournée étirait la texture en stries au-delà de ±45° de lacet : trône, coffres, lits…).
func boite(nom: String, centre: Vector3, taille: Vector3, lacet := 0.0, sans_dessous := false, decal := Vector3.ZERO) -> void:
	var h := taille * 0.5
	var basis := Basis(Vector3.UP, lacet)
	for f in _FACES:
		var n: Vector3 = f[0]
		if sans_dessous and n == Vector3.DOWN:
			continue
		var pts: Array = f[1]
		var p0: Vector3 = pts[0] * h
		var p1: Vector3 = pts[1] * h
		var p2: Vector3 = pts[2] * h
		var p3: Vector3 = pts[3] * h
		var cd := centre + decal
		_quad_p(nom, centre + basis * p0, centre + basis * p1, centre + basis * p2, centre + basis * p3, basis * n, cd + p0, cd + p1, cd + p2, cd + p3, n)
	_nb_pieces += 1

## Boîte autonome (pièces mobiles : herse, levier) : maillage propre, UV en mètres comme le reste.
func instance_boite(parent: Node3D, nom: String, taille: Vector3, pos: Vector3, lacet := 0.0) -> MeshInstance3D:
	var buf := {"nom": nom, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}
	var h := taille * 0.5
	var t: float = TUILE.get(nom, 1.0)
	for f in _FACES:
		var n: Vector3 = f[0]
		var pts: Array = f[1]
		var q: Array = []
		var u: Array = []
		for p: Vector3 in pts:
			q.append(p * h)
			u.append(_uv(p * h, n, t))
		_tri(buf, q[0], q[1], q[2], n, u[0], u[1], u[2])
		_tri(buf, q[0], q[2], q[3], n, u[0], u[2], u[3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = buf["v"]
	arr[Mesh.ARRAY_NORMAL] = buf["n"]
	arr[Mesh.ARRAY_TEX_UV] = buf["u"]
	arr[Mesh.ARRAY_COLOR] = buf["c"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(nom)
	mi.position = xf * pos
	mi.rotation.y = lacet + xf.basis.get_euler().y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func solide(centre: Vector3, taille: Vector3) -> void:
	if muet:
		return
	var bs := BoxShape3D.new()
	bs.size = (xf.basis * taille).abs() if xf != Transform3D.IDENTITY else taille      # quarts de tour : la boîte reste alignée sur les axes
	var cs := CollisionShape3D.new()
	cs.shape = bs
	cs.position = xf * centre
	corps.add_child(cs)
	if _obj_n > 0:
		_audit_solide(cs.position, bs.size)

## Boîte visible ET solide (collision identique à l'ancienne _boite).
func boite_pleine(nom: String, centre: Vector3, taille: Vector3) -> void:
	boite(nom, centre, taille)
	solide(centre, taille)

## Solide de révolution (pilier octogonal, urne, tonneau, brasero) : profil [Vector2(rayon, y)] de bas en haut.
func tour(nom: String, base: Vector3, profil: Array, cotes := 8, decal := -1.0, sommet := true) -> void:
	var t: float = TUILE.get(nom, 1.0)
	var d: float = PI / cotes if decal < 0.0 else decal
	for k in profil.size() - 1:
		var p0: Vector2 = profil[k]
		var p1: Vector2 = profil[k + 1]
		for i in cotes:
			var a0 := d + TAU * i / cotes
			var a1 := d + TAU * (i + 1) / cotes
			var q0 := base + Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var q1 := base + Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var q2 := base + Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var q3 := base + Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var milieu := (q0 + q1 + q2 + q3) * 0.25
			var sortant := Vector3(milieu.x - base.x, 0, milieu.z - base.z).normalized()
			var n := (q1 - q0).cross(q3 - q0).normalized()
			if n.dot(sortant) < 0.0:
				n = -n
			var cote := 2.0 * maxf(p0.x, p1.x) * sin(PI / cotes)
			var u0 := (i * cote) / t
			var u1 := ((i + 1) * cote) / t
			quad(nom, q0, q1, q2, q3, n, [Vector2(u0, -p0.y / t), Vector2(u1, -p0.y / t), Vector2(u1, -p1.y / t), Vector2(u0, -p1.y / t)])
	if sommet:
		var top: Vector2 = profil[profil.size() - 1]
		if top.x > 0.001:
			var c := base + Vector3(0, top.y, 0)
			var b := _buf(xf * c, nom)
			for i in cotes:
				var a0 := d + TAU * i / cotes
				var a1 := d + TAU * (i + 1) / cotes
				var q0 := c + Vector3(cos(a0) * top.x, 0, sin(a0) * top.x)
				var q1 := c + Vector3(cos(a1) * top.x, 0, sin(a1) * top.x)
				if _j_prof > 0:
					_jp(xf * q0)
				_tri(b, xf * c, xf * q0, xf * q1, xf.basis * Vector3.UP, _uv(c, Vector3.UP, t), _uv(q0, Vector3.UP, t), _uv(q1, Vector3.UP, t))
	_nb_pieces += 1

## Arche (rib) : `plan` "x" = l'arche franchit un vide le long de X (extrudée le long de Z), "z" = l'inverse.
## Largeur libre w, naissance à la hauteur ys, flèche f (sommet à ys+f) ; brisée si f >= w/2, sinon segmentaire.
func arc(nom: String, plan: String, cx: float, cz: float, w: float, ys: float, f: float, ep := 0.32, prof := 0.45, seg := 8) -> void:
	j0("arc")
	if v2:      # crypte v2 : arc en voussoirs (module Blender) étiré à la portée et à la flèche demandées
		var g: Array = ["arche_2p0", 2.0, 1.0] if w <= 3.0 else (["arche_4p0", 4.0, 2.2] if w <= 7.0 else ["arche_10p7", 10.7, 2.3])
		modele(g[0], Vector3(cx, ys, cz), 0.0 if plan == "x" else PI * 0.5, Vector3(w / float(g[1]), f / float(g[2]), clampf(prof / 0.5, 0.7, 1.3)))
		j1()
		return
	var t: float = TUILE.get(nom, 1.0)
	var intr: Array = []     # Vector2(u, y) de gauche à droite
	var extr: Array = []
	var demi := w * 0.5
	if f >= demi:
		var xc := (w * w / 4.0 - f * f) / w      # centre de l'arc droit (≤ 0 : sur la gauche)
		var R := demi - xc
		var a1 := atan2(f, -xc)
		for s in range(0, seg + 1):              # moitié gauche : de la naissance au sommet (arc miroir)
			var a := a1 * float(s) / seg
			intr.append(Vector2(-(xc + R * cos(a)), ys + R * sin(a)))
			extr.append(Vector2(-(xc + (R + ep) * cos(a)), ys + (R + ep) * sin(a)))
		for s in range(seg - 1, -1, -1):         # moitié droite : du sommet à la naissance
			var a := a1 * float(s) / seg
			intr.append(Vector2(xc + R * cos(a), ys + R * sin(a)))
			extr.append(Vector2(xc + (R + ep) * cos(a), ys + (R + ep) * sin(a)))
	else:
		var yc := (f * f - demi * demi) / (2.0 * f)
		var R := f - yc
		var a_s := atan2(-yc, demi)
		for s in range(0, 2 * seg + 1):
			var a := lerpf(PI - a_s, a_s, float(s) / (2 * seg))
			intr.append(Vector2(R * cos(a), ys + yc + R * sin(a)))
			extr.append(Vector2((R + ep) * cos(a), ys + yc + (R + ep) * sin(a)))
	var cen := Vector2(0.0, ys)
	var hd := prof * 0.5
	for k in intr.size() - 1:
		var i0: Vector2 = intr[k]
		var i1: Vector2 = intr[k + 1]
		var e0: Vector2 = extr[k]
		var e1: Vector2 = extr[k + 1]
		var m3 := func(p: Vector2, wz: float) -> Vector3:
			return Vector3(cx + p.x, p.y, cz + wz) if plan == "x" else Vector3(cx + wz, p.y, cz + p.x)
		var nz := Vector3(0, 0, 1) if plan == "x" else Vector3(1, 0, 0)
		var s0 := float(k) * 0.4
		var s1 := float(k + 1) * 0.4
		# faces avant et arrière
		for sg in [1.0, -1.0]:
			var pa: Vector3 = m3.call(i0, hd * sg)
			var pb: Vector3 = m3.call(i1, hd * sg)
			var pc: Vector3 = m3.call(e1, hd * sg)
			var pd: Vector3 = m3.call(e0, hd * sg)
			quad(nom, pa, pb, pc, pd, nz * sg)
		# intrados et extrados
		var mi := (i0 + i1) * 0.5
		var dir_i := Vector2(0, ys) - mi
		if f < demi:
			dir_i = Vector2(0, ys + (f * f - demi * demi) / (2.0 * f)) - mi
		var ni2 := dir_i.normalized()
		var nint: Vector3 = Vector3(ni2.x, ni2.y, 0) if plan == "x" else Vector3(0, ni2.y, ni2.x)
		var ia: Vector3 = m3.call(i0, -hd)
		var ib: Vector3 = m3.call(i1, -hd)
		var ic: Vector3 = m3.call(i1, hd)
		var id_: Vector3 = m3.call(i0, hd)
		quad(nom, ia, ib, ic, id_, nint, [Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, prof / t * 1.0), Vector2(s0, prof / t * 1.0)])
		var ea: Vector3 = m3.call(e0, -hd)
		var eb: Vector3 = m3.call(e1, -hd)
		var ec: Vector3 = m3.call(e1, hd)
		var ed: Vector3 = m3.call(e0, hd)
		quad(nom, ea, eb, ec, ed, -nint, [Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, prof / t), Vector2(s0, prof / t)])
	_nb_pieces += 1
	j1()

## Occlusion ambiante cuite dans les sommets : 1 = rien, `fond` au contact. Teinte un peu froide (l'ombre est bleutée).
func _ao(d: float, portee: float, fond: float) -> Color:
	var t := clampf(d / portee, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var f := lerpf(fond, 1.0, t)
	return Color(f, f, minf(1.0, f + 0.07 * (1.0 - f)))

## Points de coupe d'un segment [a, b] : bords, bords + marge, puis pas de 4 m au plus ; sans doublons proches.
func _coupes(a: float, b: float, marges: Array) -> Array:
	var pts := [a, b]
	for m: float in marges:
		if b - a > 2.0 * m + 0.1:
			pts.append(a + m)
			pts.append(b - m)
	pts.sort()
	var res := [pts[0]]
	for k in range(1, pts.size()):
		if pts[k] - res[res.size() - 1] > 0.05:
			res.append(pts[k])
	var out := [res[0]]
	for k in range(1, res.size()):
		var n := maxi(1, int(ceil((res[k] - out[out.size() - 1]) / 4.0 - 0.001)))
		var d0: float = out[out.size() - 1]
		for j in range(1, n + 1):
			out.append(lerpf(d0, res[k], float(j) / n))
	return out

# ------------------------------------------------------------------ surfaces modulaires (pas de 4 m), AO cuite
func plan_h(nom: String, x0: float, x1: float, z0: float, z1: float, y: float, vers_haut: bool, marge := 0.9, fond := 0.5) -> void:
	var n := Vector3.UP if vers_haut else Vector3.DOWN
	var xs := _coupes(x0, x1, [marge])
	var zs := _coupes(z0, z1, [marge])
	var col := func(x: float, z: float) -> Color:
		return _ao(minf(minf(x - x0, x1 - x), minf(z - z0, z1 - z)), marge, fond)
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			quad(nom, Vector3(xs[i], y, zs[j]), Vector3(xs[i + 1], y, zs[j]), Vector3(xs[i + 1], y, zs[j + 1]), Vector3(xs[i], y, zs[j + 1]), n, [], [],
				[col.call(xs[i], zs[j]), col.call(xs[i + 1], zs[j]), col.call(xs[i + 1], zs[j + 1]), col.call(xs[i], zs[j + 1])])

## Mur vertical ; `axe` "x" : le mur s'étend le long de X à z = fixe (normale ±Z) ; "z" : le long de Z à x = fixe.
## Coins (extrémités du pan) et haut du mur assombris (sommets) ; le pied l'est par le shader.
func plan_v(nom: String, axe: String, fixe: float, a0: float, a1: float, y0: float, y1: float, signe: float) -> void:
	if a1 - a0 < 0.01 or y1 - y0 < 0.01:
		return
	var s := _coupes(a0, a1, [0.7])
	var ys := _coupes(y0, y1, [0.8])
	var col := func(a: float, y: float) -> Color:
		var f := _ao(minf(a - a0, a1 - a), 0.7, 0.55) * _ao(y1 - y, 0.8, 0.5)
		if y0 > 0.5:     # dessous d'un linteau : l'angle avec le mur est sombre aussi
			f *= _ao(y - y0, 0.5, 0.7)
		return f
	for i in s.size() - 1:
		for j in ys.size() - 1:
			var ya: float = ys[j]
			var yb: float = ys[j + 1]
			var cc := [col.call(s[i], ya), col.call(s[i + 1], ya), col.call(s[i + 1], yb), col.call(s[i], yb)]
			if axe == "x":
				quad(nom, Vector3(s[i], ya, fixe), Vector3(s[i + 1], ya, fixe), Vector3(s[i + 1], yb, fixe), Vector3(s[i], yb, fixe), Vector3(0, 0, signe), [], [], cc)
			else:
				quad(nom, Vector3(fixe, ya, s[i]), Vector3(fixe, ya, s[i + 1]), Vector3(fixe, yb, s[i + 1]), Vector3(fixe, yb, s[i]), Vector3(signe, 0, 0), [], [], cc)

func _pas(a: float, b: float, pas := 4.0) -> Array:
	var n := maxi(1, int(ceil((b - a) / pas - 0.001)))
	var r := []
	for i in n + 1:
		r.append(lerpf(a, b, float(i) / n))
	return r

# ------------------------------------------------------------------ pièce rectangulaire
## Remplace l'ancien _salle : mêmes collisions (sol, plafond, murs, linteaux), surfaces refaites.
## ouvertures : [côté, centre, largeur] avec côté nord (z mini) / sud (z maxi) / ouest (x mini) / est (x maxi).
func salle(x0: float, x1: float, z0: float, z1: float, h: float, ouvertures: Array, y := 0.0, mur := "mur0") -> void:
	var xmin := minf(x0, x1)
	var xmax := maxf(x0, x1)
	var zmin := minf(z0, z1)
	var zmax := maxf(z0, z1)
	var cx := (xmin + xmax) * 0.5
	var cz := (zmin + zmax) * 0.5
	var lx := xmax - xmin
	var lz := zmax - zmin
	# --- collisions : strictement celles d'origine
	solide(Vector3(cx, y - 0.2, cz), Vector3(lx + 0.6, 0.4, lz + 0.6))
	solide(Vector3(cx, y + h + 0.2, cz), Vector3(lx + 0.6, 0.4, lz + 0.6))
	for cote in ["nord", "sud", "ouest", "est"]:
		var horizontal: bool = cote in ["nord", "sud"]
		var fixe: float = (zmin if cote == "nord" else zmax) if horizontal else (xmin if cote == "ouest" else xmax)
		var debut: float = xmin if horizontal else zmin
		var fin: float = xmax if horizontal else zmax
		var morceaux := [[debut, fin]]
		for o in ouvertures:
			if o[0] != cote:
				continue
			var nouveaux := []
			for m in morceaux:
				var a: float = o[1] - o[2] * 0.5
				var b: float = o[1] + o[2] * 0.5
				if b <= m[0] or a >= m[1]:
					nouveaux.append(m)
				else:
					if a > m[0]:
						nouveaux.append([m[0], a])
					if b < m[1]:
						nouveaux.append([b, m[1]])
			morceaux = nouveaux
		if h > 3.0:
			for o in ouvertures:
				if o[0] == cote:
					solide(Vector3(o[1], y + (3.0 + h) * 0.5, fixe) if horizontal else Vector3(fixe, y + (3.0 + h) * 0.5, o[1]),
						Vector3(o[2], h - 3.0, 0.6) if horizontal else Vector3(0.6, h - 3.0, o[2]))
		for m in morceaux:
			var longueur: float = m[1] - m[0]
			if longueur < 0.05:
				continue
			var milieu: float = (m[0] + m[1]) * 0.5
			solide(Vector3(milieu, y + h * 0.5, fixe) if horizontal else Vector3(fixe, y + h * 0.5, milieu),
				Vector3(longueur + 0.6, h, 0.6) if horizontal else Vector3(0.6, h, longueur + 0.6))
	# --- surfaces visibles : sol, plafond, faces intérieures des murs, embrasures
	var xa := xmin + 0.3
	var xb := xmax - 0.3
	var za := zmin + 0.3
	var zb := zmax - 0.3
	plan_h("dalle0", xa, xb, za, zb, y, true)
	plan_h("voute", xa, xb, za, zb, y + h, false)
	var ho := minf(h, 3.0)
	var idx := 0
	for cote in ["nord", "sud", "ouest", "est"]:
		var horizontal: bool = cote in ["nord", "sud"]
		var plan: float = {"nord": zmin + 0.3, "sud": zmax - 0.3, "ouest": xmin + 0.3, "est": xmax - 0.3}[cote]
		var signe: float = 1.0 if cote in ["nord", "ouest"] else -1.0
		var a0: float = xa if horizontal else za
		var a1: float = xb if horizontal else zb
		var libres := [[a0, a1]]
		var clairs: Array = []
		for o in ouvertures:
			if o[0] != cote:
				continue
			var ca: float = o[1] - o[2] * 0.5 + 0.3
			var cb: float = o[1] + o[2] * 0.5 - 0.3
			clairs.append([ca, cb, o.size() > 3 and o[3]])      # 4e élément : ouverture secrète (pas de cadre, relief de mur)
			var nouveaux := []
			for m in libres:
				if cb <= m[0] or ca >= m[1]:
					nouveaux.append(m)
				else:
					if ca > m[0]:
						nouveaux.append([m[0], ca])
					if cb < m[1]:
						nouveaux.append([cb, m[1]])
			libres = nouveaux
		for m in libres:
			plan_v(_var_mur(mur, idx), "x" if horizontal else "z", plan, m[0], m[1], y, y + h, signe)
			idx += 1
		var axe := "x" if horizontal else "z"
		var fixe_mur: float = plan - signe * 0.3      # axe du mur (le plan visible est à 0,3 m vers l'intérieur)
		for c in clairs:
			if h > 3.0:
				plan_v(_var_mur(mur, idx), axe, plan, c[0], c[1], y + 3.0, y + h, signe)
				idx += 1
			# embrasure : jambages, seuil et dessous de linteau (une seule fois par ouverture)
			var w0 := xf * (Vector3(c[0], y, fixe_mur) if horizontal else Vector3(fixe_mur, y, c[0]))      # clé en repère de la crypte : deux modules voisins partagent l'embrasure
			var w1 := xf * (Vector3(c[1], y, fixe_mur) if horizontal else Vector3(fixe_mur, y, c[1]))
			var cle := "%.1f,%.1f,%.1f|%.1f,%.1f" % [minf(w0.x, w1.x), minf(w0.z, w1.z), y, maxf(w0.x, w1.x), maxf(w0.z, w1.z)]
			var deja := _fait.has(cle)
			_fait[cle] = true
			for e in ([] if deja else [c[0], c[1]]):
				var sg: float = 1.0 if e == c[0] else -1.0   # normale vers le passage
				if horizontal:
					quad(mur, Vector3(e, y, fixe_mur - 0.3), Vector3(e, y, fixe_mur + 0.3), Vector3(e, y + ho, fixe_mur + 0.3), Vector3(e, y + ho, fixe_mur - 0.3), Vector3(sg, 0, 0))
				else:
					quad(mur, Vector3(fixe_mur - 0.3, y, e), Vector3(fixe_mur + 0.3, y, e), Vector3(fixe_mur + 0.3, y + ho, e), Vector3(fixe_mur - 0.3, y + ho, e), Vector3(0, 0, sg))
			if deja:
				if not c[2]:
					_cadre(horizontal, plan, signe, c[0], c[1], ho, y)
				continue
			if est_crypte and not c[2]:      # seuil de pierre à deux marches (9 cm, décor sans collision : franchissable) sous le passage
				var mc: float = (c[0] + c[1]) * 0.5
				var lw: float = c[1] - c[0] + 0.3
				boite("mur1", Vector3(mc, y + 0.045, fixe_mur) if horizontal else Vector3(fixe_mur, y + 0.045, mc), Vector3(lw, 0.09, 0.62) if horizontal else Vector3(0.62, 0.09, lw), 0.0, true)
				for sp: float in [-1.0, 1.0]:
					var q := fixe_mur + sp * 0.47
					boite("mur0", Vector3(mc, y + 0.022, q) if horizontal else Vector3(q, y + 0.022, mc), Vector3(lw - 0.1, 0.045, 0.32) if horizontal else Vector3(0.32, 0.045, lw - 0.1), 0.0, true)
					givre_dessus(Vector3(mc + sp * lw * 0.3, y + 0.045, q) if horizontal else Vector3(q, y + 0.045, mc + sp * lw * 0.3), Vector2(0.5, 0.2) if horizontal else Vector2(0.2, 0.5), 0.0)
			if horizontal:
				quad("dalle0", Vector3(c[0], y, fixe_mur - 0.3), Vector3(c[1], y, fixe_mur - 0.3), Vector3(c[1], y, fixe_mur + 0.3), Vector3(c[0], y, fixe_mur + 0.3), Vector3.UP)
				quad("voute", Vector3(c[0], y + ho, fixe_mur - 0.3), Vector3(c[1], y + ho, fixe_mur - 0.3), Vector3(c[1], y + ho, fixe_mur + 0.3), Vector3(c[0], y + ho, fixe_mur + 0.3), Vector3.DOWN)
			else:
				quad("dalle0", Vector3(fixe_mur - 0.3, y, c[0]), Vector3(fixe_mur + 0.3, y, c[0]), Vector3(fixe_mur + 0.3, y, c[1]), Vector3(fixe_mur - 0.3, y, c[1]), Vector3.UP)
				quad("voute", Vector3(fixe_mur - 0.3, y + ho, c[0]), Vector3(fixe_mur + 0.3, y + ho, c[0]), Vector3(fixe_mur + 0.3, y + ho, c[1]), Vector3(fixe_mur - 0.3, y + ho, c[1]), Vector3.DOWN)
			# cadre de porte épais : deux jambages et un linteau en saillie sur le mur
			if not c[2]:
				_cadre(horizontal, plan, signe, c[0], c[1], ho, y)
			else:
				_relief_mur(horizontal, plan, signe, c[0], c[1], y, h)
		# soubassement en deux assises irrégulières, corniche à trois ressauts sur corbeaux, pierres en saillie
		for m in libres:
			_relief_mur(horizontal, plan, signe, m[0], m[1], y, h)
	if est_crypte:       # 4e passe : toiles d'araignée dans les angles hauts
		for cn: Array in [[xa, za, 1.0, 1.0], [xb, za, -1.0, 1.0], [xa, zb, 1.0, -1.0], [xb, zb, -1.0, -1.0]]:
			if rng_deco.randf() < 0.75:
				toile(Vector3(cn[0], y + h - 0.02, cn[1]), Vector3(cn[2], 0, 0), Vector3(0, 0, cn[3]), rng_deco.randf_range(0.7, 1.3))

## Relief géométrique d'un pan de mur : pierres de soubassement de profondeur variable, corniche (ressauts + corbeaux),
## quelques pierres d'assise en saillie (alignées sur les assises de 0,5 m de la texture).
func _relief_mur(horizontal: bool, plan: float, signe: float, a0: float, a1: float, y: float, h: float) -> void:
	var dos := func(a: float, y_c: float, lon: float, ep: float, haut: float, nom: String) -> void:
		var c := Vector3(a, y + y_c, plan + signe * (ep * 0.5)) if horizontal else Vector3(plan + signe * (ep * 0.5), y + y_c, a)
		j0("relief_mur")      # journal : une entrée par pierre (soubassement, corniche), pas une bande englobante
		boite(nom, c, Vector3(lon, haut, ep) if horizontal else Vector3(ep, haut, lon))
		j1()
	var a := a0
	while a < a1 - 0.05:                                 # assise basse : 0,3 m, saillie 0,10 à 0,20
		var l := minf(rng.randf_range(0.7, 1.5), a1 - a)
		dos.call(a + l * 0.5, 0.15 + rng.randf_range(-0.01, 0.01), l - 0.02, rng.randf_range(0.10, 0.20), 0.3 + rng.randf_range(-0.03, 0.03), "mur1" if rng.randf() < 0.4 else "mur0")
		a += l
	a = a0 + rng.randf_range(0.0, 0.5)
	while a < a1 - 0.05:                                 # seconde assise : 0,3 à 0,62, saillie 0,04 à 0,09
		var l := minf(rng.randf_range(0.9, 1.7), a1 - a)
		dos.call(a + l * 0.5, 0.46, l - 0.02, rng.randf_range(0.04, 0.09), 0.32, "mur0" if rng.randf() < 0.6 else "mur1")
		a += l
	var kc := 2.0 if est_crypte else 1.0                 # 2e passe : corniche nettement saillante dans la crypte
	dos.call((a0 + a1) * 0.5, h - 0.1, a1 - a0, 0.12 * kc, 0.2, "mur0")      # corniche : trois ressauts
	dos.call((a0 + a1) * 0.5, h - 0.3, a1 - a0, 0.07 * kc, 0.2, "mur1")
	dos.call((a0 + a1) * 0.5, h - 0.45, a1 - a0, 0.035 * kc, 0.12, "mur0")
	a = a0 + 0.9                                         # corbeaux sous la corniche
	while a < a1 - 0.5:
		dos.call(a, h - 0.38, 0.3, 0.2, 0.26, "mur1")
		a += 2.0
	if a1 - a0 > 1.6:                                    # pierres d'assise en saillie
		for k in int((a1 - a0) / 2.6):
			var cen := rng.randf_range(a0 + 0.8, a1 - 0.8)
			var rang := rng.randi_range(1, maxi(1, int(minf(h, 3.0) / 0.5) - 3))
			dos.call(cen, rang * 0.5 + 0.25, rng.randf_range(0.7, 1.2), rng.randf_range(0.04, 0.09), 0.48, "mur1" if rng.randf() < 0.5 else "mur2")
	if est_crypte:
		_givre_mur(horizontal, plan, signe, a0, a1, y, h)

## Refonte matière : givre sur les arêtes hautes et glaçons (références) ; RNG séparé (rng_deco) : le décor existant ne bouge pas.
## - salles hautes (h >= 3,5) : bandeau mouluré en saillie à h - 1,1, croûte de givre dessus, glaçons dessous ;
## - partout : glaçons sous les corbeaux de la corniche, givre sur la lèvre du soubassement.
func _givre_mur(horizontal: bool, plan: float, signe: float, a0: float, a1: float, y: float, h: float) -> void:
	if a1 - a0 < 0.6:
		return
	var gele := not theme.is_empty()                  # thèmes givre / glace : beaucoup plus de glace
	var pt := func(a: float, yy: float, ret: float) -> Vector3:
		return Vector3(a, yy, plan + signe * ret) if horizontal else Vector3(plan + signe * ret, yy, a)
	var dim := func(lon: float, haut: float, ep: float) -> Vector3:
		return Vector3(lon, haut, ep) if horizontal else Vector3(ep, haut, lon)
	var lon := a1 - a0
	var am := (a0 + a1) * 0.5
	if h >= 3.5:
		var yb := y + h - 1.1
		boite("mur1", pt.call(am, yb - 0.06, 0.08), dim.call(lon, 0.12, 0.16), 0.0, false)
		boite("mur0", pt.call(am, yb + 0.06, 0.11), dim.call(lon, 0.12, 0.22), 0.0, true)
		var a := a0
		while a < a1 - 0.2:
			var l := minf(rng_deco.randf_range(0.8, 2.2), a1 - a)
			givre_dessus(pt.call(a + l * 0.5, yb + 0.12, 0.11), Vector2(l, 0.22) if horizontal else Vector2(0.22, l), 0.05)
			a += l + rng_deco.randf_range(0.0, 0.6)
		glacons_arete(pt.call(a0 + 0.1, yb - 0.12, 0.2), pt.call(a1 - 0.1, yb - 0.12, 0.2), 2.0 if gele else 1.0, 0.8 if gele else 0.55)
	glacons_arete(pt.call(a0 + 0.3, y + h - 0.5, 0.2), pt.call(a1 - 0.3, y + h - 0.5, 0.2), 1.7 if gele else 0.9, 0.7 if gele else 0.5)
	if est_crypte:       # 4e passe : givre visible d'en bas sur les ressauts de la corniche et le bandeau, glaçons longs épars
		var vv := Vector3(0, 0, signe) if horizontal else Vector3(signe, 0, 0)
		givre_levre(pt.call(a0, y + h - 0.2, 0.24), pt.call(a1, y + h - 0.2, 0.24), vv, 0.05, 0.85)
		givre_levre(pt.call(a0, y + h - 0.4, 0.14), pt.call(a1, y + h - 0.4, 0.14), vv, 0.035, 0.6)
		if h >= 3.5:
			givre_levre(pt.call(a0, y + h - 0.98, 0.22), pt.call(a1, y + h - 0.98, 0.22), vv, 0.05, 0.85)
		var ag := a0 + rng_deco.randf_range(0.3, 1.2)
		while ag < a1 - 0.3:
			glacon_sous(pt.call(ag, y + h - 0.2, 0.2), rng_deco.randf_range(0.7, 1.3), 0.06)
			ag += rng_deco.randf_range(1.2, 2.6)
	# lèvre du soubassement : givre en plaques discontinues (pas une ligne blanche continue)
	var a := a0
	while a < a1 - 0.3:
		var l := minf(rng_deco.randf_range(0.4, 1.3), a1 - a)
		if rng_deco.randf() < (0.7 if gele else 0.2):
			givre_dessus(pt.call(a + l * 0.5, y + 0.3, 0.13), Vector2(l, 0.1) if horizontal else Vector2(0.1, l), 0.02)
		a += l + rng_deco.randf_range(0.1, 0.9)

func _var_mur(base: String, i: int) -> String:
	if base == "mur0":
		return "mur0" if i % 3 != 2 else "mur1"
	if base == "mur1":
		return "mur1" if i % 2 == 0 else "mur0"
	return base

func _cadre(horizontal: bool, plan: float, signe: float, ca: float, cb: float, ho: float, y: float) -> void:
	if est_crypte:
		_cadre_massif(horizontal, plan, signe, ca, cb, ho, y)
		return
	var p_in := plan + signe * 0.08
	for k in 2:
		var lado := ca - 0.22 if k == 0 else cb + 0.22
		if horizontal:
			boite("mur0", Vector3(lado, y + ho * 0.5, p_in), Vector3(0.44, ho, 0.16))
		else:
			boite("mur0", Vector3(p_in, y + ho * 0.5, lado), Vector3(0.16, ho, 0.44))
	var l := cb - ca + 0.88
	var m := (ca + cb) * 0.5
	if horizontal:
		boite("mur0", Vector3(m, y + ho - 0.2, p_in + signe * 0.03), Vector3(l, 0.4, 0.22))
	else:
		boite("mur0", Vector3(p_in + signe * 0.03, y + ho - 0.2, m), Vector3(0.22, 0.4, l))

## 2e passe : passage à linteau MASSIF (références) — jambages en harpe (blocs alternés), corbeaux, linteau de 0,6 m en
## saillie de 0,3 m, clé, givre dessus, frange de glaçons dessous. Rien n'entre dans le passage (tout est hors de [ca, cb]).
func _cadre_massif(horizontal: bool, plan: float, signe: float, ca: float, cb: float, ho: float, y: float) -> void:
	var P := func(a: float, yy: float, ret: float) -> Vector3:
		return Vector3(a, yy, plan + signe * ret) if horizontal else Vector3(plan + signe * ret, yy, a)
	var D := func(l: float, hh: float, ep: float) -> Vector3:
		return Vector3(l, hh, ep) if horizontal else Vector3(ep, hh, l)
	for k in 2:
		var sg := -1.0 if k == 0 else 1.0
		var bord := ca if k == 0 else cb
		var yy := 0.0
		var i := 0
		while yy < ho - 0.6:
			var hb := minf(0.48 if i % 2 == 0 else 0.4, ho - 0.6 - yy)
			var lb := 0.62 if i % 2 == 0 else 0.44
			boite("mur0" if i % 3 != 1 else "mur1", P.call(bord + sg * lb * 0.5, y + yy + hb * 0.5, 0.12), D.call(lb - 0.02, hb - 0.02, 0.24))
			yy += hb
			i += 1
		boite("mur1", P.call(bord + sg * 0.05, y + ho - 0.7, 0.2), D.call(0.42, 0.22, 0.4))      # corbeau
	var l := cb - ca + 1.4
	var m := (ca + cb) * 0.5
	boite("mur0", P.call(m, y + ho - 0.3, 0.16), D.call(l, 0.6, 0.32))
	boite("mur1", P.call(m, y + ho - 0.3, 0.33), D.call(0.42, 0.72, 0.06))                   # clé
	givre_dessus(P.call(m, y + ho, 0.16), Vector2(l, 0.32) if horizontal else Vector2(0.32, l), 0.05)
	glacons_arete(P.call(ca - 0.6, y + ho - 0.62, 0.3), P.call(cb + 0.6, y + ho - 0.62, 0.3), 1.7 if not theme.is_empty() else 1.1, 0.4)

## Pilastre engagé (décor seul, sans collision) : `pied` = pied du mur au sol, `vers` = normale du mur vers la pièce, `hp` = hauteur.
## Base moulurée givrée, fût 0,5 x 0,22 à panneau d'entrelacs, chapiteau à ressauts, glaçons.
func pilastre_mur(pied: Vector3, vers: Vector3, hp: float) -> void:
	j0("pilastre_mur", atan2(vers.x, vers.z))
	var v := vers.normalized()
	var dr := Vector3(-v.z, 0, v.x)
	var horiz := absf(v.z) > 0.5          # mur le long de x
	var D := func(l: float, hh: float, ep: float) -> Vector3:
		return Vector3(l, hh, ep) if horiz else Vector3(ep, hh, l)
	var P := func(yy: float, ret: float) -> Vector3:
		return pied + v * ret + Vector3(0, yy, 0)
	boite("mur1", P.call(hp * 0.5, 0.11), D.call(0.5, hp, 0.22), 0.0, true)
	boite("mur0", P.call(0.22, 0.15), D.call(0.68, 0.44, 0.3), 0.0, true)
	boite("mur1", P.call(0.5, 0.13), D.call(0.6, 0.12, 0.26), 0.0, true)
	givre_dessus(P.call(0.44, 0.26), Vector2(0.6, 0.06) if horiz else Vector2(0.06, 0.6), 0.02)
	boite("mur1", P.call(hp - 0.3, 0.14), D.call(0.6, 0.14, 0.28), 0.0, false)
	boite("mur0", P.call(hp - 0.11, 0.17), D.call(0.74, 0.22, 0.34), 0.0, false)
	givre_dessus(P.call(hp, 0.17), Vector2(0.74, 0.32) if horiz else Vector2(0.32, 0.74), 0.04)
	glacons_arete(P.call(hp - 0.22, 0.33) - dr * 0.33, P.call(hp - 0.22, 0.33) + dr * 0.33, 1.6, 0.45)
	givre_levre(P.call(hp, 0.34) - dr * 0.37, P.call(hp, 0.34) + dr * 0.37, v, 0.05, 1.0)
	var hpan := minf(1.5, hp - 1.4)
	if hpan > 0.5:
		var cc: Vector3 = P.call(0.75 + hpan * 0.5, 0.225)
		var hy := Vector3(0, hpan * 0.5, 0)
		quad("entrelacs", cc - dr * 0.18 - hy, cc + dr * 0.18 - hy, cc + dr * 0.18 + hy, cc - dr * 0.18 + hy, v, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	j1()

# ------------------------------------------------------------------ structure : piliers, contreforts, poutres
## Pilier (refonte matière, références grottes_cryptes_2/3) : fût carré à arêtes abattues, socle mouluré givré, chapiteau à
## ressauts, et sur chaque face un panneau d'ENTRELACS en losanges (un ou deux panneaux superposés selon la hauteur).
## Collision = la boîte d'origine (largeur x h x largeur), inchangée.
func pilier(x: float, z: float, h: float, largeur := 0.9, y := 0.0) -> void:
	j0("pilier")
	if v2:      # crypte v2 : pilier isolé en assises de blocs (module Blender), MÊME collision
		var base := "pilier_libre_8" if h > 6.5 else "pilier_libre_5"
		var bh := 8.0 if h > 6.5 else 5.0
		var bw := 1.2 if h > 6.5 else 1.0
		modele(base, Vector3(x, y, z), 0.0, Vector3(largeur / bw, h / bh, largeur / bw))
		solide(Vector3(x, y + h * 0.5, z), Vector3(largeur, h, largeur))
		j1()
		return
	if not est_crypte:
		_pilier_octo(x, z, h, largeur, y)
		j1()
		return
	var w := largeur
	var c := Vector3(x, 0, z)
	var hs := 0.42                                     # socle
	var hc := 0.62                                     # chapiteau
	boite("mur1", c + Vector3(0, y + 0.13, 0), Vector3(w + 0.34, 0.26, w + 0.34), 0.0, true)
	boite("mur0", c + Vector3(0, y + 0.33, 0), Vector3(w + 0.18, 0.16, w + 0.18), 0.0, true)
	givre_dessus(c + Vector3(0, y + 0.26, 0), Vector2(w + 0.34, w + 0.34), 0.08)
	# fût : noyau + quatre arêtes abattues (bandes en biais)
	var y0 := y + hs
	var y1 := y + h - hc
	boite("mur0", c + Vector3(0, (y0 + y1) * 0.5, 0), Vector3(w - 0.02, y1 - y0, w - 0.02), 0.0, true)
	var ch := 0.09
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		boite("mur1", c + Vector3(cos(a), 0, sin(a)) * (w * 0.5 * 1.414 - ch * 0.45) + Vector3(0, (y0 + y1) * 0.5, 0), Vector3(ch * 1.414, y1 - y0, ch), -a + PI * 0.5, true)
	# panneaux d'entrelacs sur les quatre faces, légèrement en relief, cadre de pierre autour
	var hp := y1 - y0 - 0.24
	var nb := 2 if hp > 2.2 else 1
	var lp := w - 0.2
	for f in 4:
		var n := Vector3(0, 0, 1).rotated(Vector3.UP, f * PI * 0.5)
		var dr := Vector3.UP.cross(n).normalized()
		var plan := c + n * (w * 0.5 + 0.005)
		for j in nb:
			var ya := y0 + 0.12 + hp * j / nb + 0.04
			var yb := y0 + 0.12 + hp * (j + 1) / nb - 0.04
			var a := plan - dr * lp * 0.5 + Vector3(0, ya, 0)
			var b := plan + dr * lp * 0.5 + Vector3(0, ya, 0)
			quad("entrelacs", a, b, b + Vector3(0, yb - ya, 0), a + Vector3(0, yb - ya, 0), n, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	# chapiteau : trois ressauts qui s'élargissent vers le haut, givre sur l'arête basse
	boite("mur1", c + Vector3(0, y1 + 0.08, 0), Vector3(w + 0.1, 0.16, w + 0.1), 0.0, true)
	boite("mur0", c + Vector3(0, y1 + 0.26, 0), Vector3(w + 0.24, 0.2, w + 0.24), 0.0, true)
	boite("mur1", c + Vector3(0, y1 + 0.49, 0), Vector3(w + 0.38, 0.26, w + 0.38), 0.0, true)
	solide(Vector3(x, y + h * 0.5, z), Vector3(largeur, h, largeur))
	j1()

## Ancien pilier octogonal (gardé pour GrotteDecor et toute sous-classe qui n'est pas la crypte).
func _pilier_octo(x: float, z: float, h: float, largeur := 0.9, y := 0.0) -> void:
	var r := largeur * 0.5 / cos(PI / 8.0)
	var prof := [
		Vector2(r * 1.32, y), Vector2(r * 1.32, y + 0.26), Vector2(r * 1.1, y + 0.36), Vector2(r, y + 0.52),
		Vector2(r, y + h - 0.62), Vector2(r * 1.1, y + h - 0.5), Vector2(r * 1.32, y + h - 0.38), Vector2(r * 1.32, y + h),
	]
	tour("mur0", Vector3(x, 0, z), prof, 8, PI / 8.0)
	var yb := y + h * 0.5
	tour("mur1", Vector3(x, 0, z), [Vector2(r * 1.06, yb - 0.1), Vector2(r * 1.06, yb + 0.1)], 8, PI / 8.0, false)
	solide(Vector3(x, y + h * 0.5, z), Vector3(largeur, h, largeur))

# ------------------------------------------------------------------ givre, glaçons, toiles, brume, lustres (refonte matière)
## Croûte de givre posée sur une surface horizontale (centre = dessus de la surface), bords déchiquetés : 2 à 3 plaques
## de « neige » décalées, la plus petite un peu plus épaisse. `deb` = débord au-delà de la surface (lèvre qui pend).
func givre_dessus(centre: Vector3, taille: Vector2, deb := 0.04, lacet := 0.0) -> void:
	var nb := 2 + rng_deco.randi_range(0, 1)
	for k in nb:
		var sx := taille.x * rng_deco.randf_range(0.55, 1.0) + (deb if k == 0 else 0.0)
		var sz := taille.y * rng_deco.randf_range(0.55, 1.0) + (deb if k == 0 else 0.0)
		var ox := (taille.x + deb - sx) * rng_deco.randf_range(-0.5, 0.5)
		var oz := (taille.y + deb - sz) * rng_deco.randf_range(-0.5, 0.5)
		var ep := 0.04 + 0.025 * k
		boite("neige", centre + Basis(Vector3.UP, lacet) * Vector3(ox, ep * 0.5, oz), Vector3(sx, ep, sz), lacet, true)

## Lèvre de givre (4e passe, références : arêtes hautes blanches, lisibles D'EN BAS) : bande blanche discontinue posée en haut de la face
## avant d'une arête horizontale (a → b), un peu en saillie, avec de petites coulures. `vers` = normale de la face avant.
func givre_levre(a: Vector3, b: Vector3, vers: Vector3, haut := 0.045, densite := 0.75) -> void:
	var l := a.distance_to(b)
	if l < 0.2:
		return
	var dr := (b - a) / l
	var le_long_x := absf(dr.x) >= absf(dr.z)
	var v := vers.normalized()
	var t := 0.0
	while t < l - 0.1:
		var lp := minf(rng_deco.randf_range(0.3, 1.1), l - t)
		if rng_deco.randf() < densite:
			var hh := haut * rng_deco.randf_range(0.7, 1.4)
			var c := a + dr * (t + lp * 0.5) + v * 0.015 - Vector3(0, hh * 0.5, 0)
			boite("neige", c, Vector3(lp, hh, 0.035) if le_long_x else Vector3(0.035, hh, lp), 0.0, true)
			if rng_deco.randf() < 0.5:        # coulure
				var q := a + dr * (t + rng_deco.randf_range(0.1, 0.9) * lp) + v * 0.02 - Vector3(0, hh, 0)
				boite("neige", q - Vector3(0, 0.03, 0), Vector3(0.03, 0.06, 0.03), 0.0, true)
		t += lp + rng_deco.randf_range(0.0, 0.35)

## Glaçon : cône effilé de glace (6 pans) pendu sous `haut`.
func glacon_sous(haut: Vector3, longueur := 0.5, r := 0.06) -> void:
	if est_crypte:       # crypte : glaçons très nombreux → cône allégé (4 pans, 2 tronçons : 48 sommets au lieu de 90)
		tour("mur4", haut + Vector3(0, -longueur, 0), [Vector2(0.0, 0.0), Vector2(r * 0.6, longueur * 0.5), Vector2(r, longueur)], 4, rng_deco.randf() * 1.2, false)
		return
	tour("mur4", haut + Vector3(0, -longueur, 0), [Vector2(0.0, 0.0), Vector2(r * 0.4, longueur * 0.35), Vector2(r * 0.8, longueur * 0.75), Vector2(r, longueur)], 5, rng_deco.randf() * 1.2, false)

## Rangée de glaçons le long d'une arête horizontale (de `a` à `b`, à la hauteur de l'arête) ; `densite` = glaçons par mètre.
func glacons_arete(a: Vector3, b: Vector3, densite := 1.0, lmax := 0.55) -> void:
	var l := a.distance_to(b)
	var n := int(l * densite + rng_deco.randf())
	for k in n:
		var t := rng_deco.randf()
		var lon := lmax * rng_deco.randf_range(0.25, 1.0)
		glacon_sous(a.lerp(b, t), lon, 0.025 + lon * 0.08)
		if rng_deco.randf() < 0.45:     # grappe : un ou deux petits à côté
			glacon_sous(a.lerp(b, clampf(t + rng_deco.randf_range(-0.04, 0.04), 0.0, 1.0)), lon * 0.45, 0.02 + lon * 0.04)

## Nappe de brume au ras du sol : quelques cartes additives horizontales qui se chevauchent (aucune particule).
func brume(centre: Vector3, ext: Vector2, nombre := 5) -> void:
	for k in nombre:
		var p := centre + Vector3(rng_deco.randf_range(-ext.x, ext.x), 0.12 + 0.1 * rng_deco.randf(), rng_deco.randf_range(-ext.y, ext.y))
		var w := rng_deco.randf_range(2.6, 4.6)
		carte("brume", p, Vector3.UP, w, w * rng_deco.randf_range(0.6, 1.0))

## Lustre de fer à bougies pendu à une chaîne : cercle de fer à 8 pans, bougies, flammes, halo ; une lumière courte si demandé.
func lustre(plafond: Vector3, chute := 1.2, rayon := 0.55, avec_lumiere := true) -> void:
	j0("lustre")
	var c := plafond - Vector3(0, chute, 0)
	chaine(plafond, c + Vector3(0, 0.55, 0))
	for k in 3:
		var a := TAU * k / 3.0
		chaine(c + Vector3(0, 0.55, 0), c + Vector3(cos(a) * rayon * 0.92, 0.04, sin(a) * rayon * 0.92))
	tour("fer", c, [Vector2(rayon, -0.04), Vector2(rayon, 0.04)], 8, PI / 8.0, false)
	tour("fer", c, [Vector2(rayon * 0.82, 0.04), Vector2(rayon * 0.82, -0.04)], 8, PI / 8.0, false)
	tour("fer", c - Vector3(0, 0.05, 0), [Vector2(0.0, -0.25), Vector2(0.06, -0.1), Vector2(0.03, 0.0)], 6, 0.0, false)     # pointe sous le cercle
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		var p := c + Vector3(cos(a) * rayon * 0.91, 0.04, sin(a) * rayon * 0.91)
		tour("os", p, [Vector2(0.03, 0.0), Vector2(0.028, 0.1 + 0.05 * (k % 2))], 5, 0.0, true)       # bougie de suif
		flamme(p + Vector3(0, 0.12 + 0.05 * (k % 2), 0), 0.55)
	carte("halo", c + Vector3(0, 0.15, 0), Vector3.UP, 1.8, 1.8)
	if avec_lumiere:
		lumiere(c + Vector3(0, 0.3, 0), FEU_BOUGIE, 1.3, 6.0, 1.7)
	j1()

## Sceau runique : losange gravé dont les traits luisent en bleu (accent froid des références), sur un mur ; petite lumière bleue.
func sceau(centre: Vector3, vers: Vector3, taille := 0.7, avec_lumiere := true, portee := 5.0) -> void:
	j0("sceau", atan2(vers.x, vers.z))
	var n := vers.normalized()
	var dr: Vector3 = _axes(n)[0]
	var p := centre + n * 0.02
	var t := taille * 0.5
	var ep := 0.035
	for k in 4:                                   # losange extérieur, losange intérieur
		var a0 := PI * 0.5 * k
		var a1 := PI * 0.5 * (k + 1)
		for r: float in [t, t * 0.55]:
			var q0 := Vector2(cos(a0), sin(a0)) * r
			var q1 := Vector2(cos(a1), sin(a1)) * r
			var m := (q0 + q1) * 0.5
			var dq := q1 - q0
			_rect("sceau", p, dr, Vector3.UP, m.x, m.y, dq.length() + ep, ep, atan2(dq.y, dq.x), n)
	_rect("sceau", p, dr, Vector3.UP, 0.0, 0.0, ep, taille * 0.9, 0.0, n)       # trait vertical (rune Is)
	carte("halo_f", p + n * 0.05, n, taille * 2.6, taille * 2.6)
	if avec_lumiere:
		lumiere(p + n * 0.5, RUNE, 0.9, portee, 1.5, false)
	j1()

func contrefort(x: float, z: float, h: float, sens_x: float, sens_z: float, l := 0.7, p := 0.5) -> void:
	j0("contrefort")
	# pilier engagé contre un mur : (sens_x, sens_z) = direction du mur vers la pièce
	var dx := p if absf(sens_x) > 0.5 else l
	var dz := p if absf(sens_z) > 0.5 else l
	boite("mur0", Vector3(x, h * 0.5, z), Vector3(dx, h, dz))
	boite("mur1", Vector3(x + sens_x * 0.06, h - 0.2, z + sens_z * 0.06), Vector3(dx + 0.12 if absf(sens_x) > 0.5 else dx + 0.12, 0.4, dz + 0.12))
	boite("mur1", Vector3(x + sens_x * 0.06, 0.2, z + sens_z * 0.06), Vector3(dx + 0.12, 0.4, dz + 0.12))
	solide(Vector3(x, h * 0.5, z), Vector3(dx, h, dz))
	j1()

func poutre(x0: float, x1: float, y: float, z: float, ep := 0.3) -> void:
	j0("poutre")
	if est_crypte:       # 3e passe : plus de poutres de bois dans la crypte → doubleau de pierre sur corbeaux, givre et glaçons
		boite("mur0", Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, ep + 0.06, ep + 0.08))
		boite("mur1", Vector3((x0 + x1) * 0.5, y - (ep + 0.06) * 0.5 - 0.04, z), Vector3(x1 - x0 - 0.2, 0.08, ep - 0.04))
		for sx: float in [x0 + 0.16, x1 - 0.16]:
			boite("mur1", Vector3(sx, y - ep * 0.5 - 0.3, z), Vector3(0.32, 0.5, ep + 0.14))
			boite("mur0", Vector3(sx, y - ep * 0.5 - 0.62, z), Vector3(0.22, 0.16, ep + 0.04))
		glacons_arete(Vector3(x0 + 0.4, y - (ep + 0.06) * 0.5 - 0.08, z), Vector3(x1 - 0.4, y - (ep + 0.06) * 0.5 - 0.08, z), 1.2, 0.4)
		j1()
		return
	boite("bois", Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, ep, ep))
	boite("fer", Vector3(x0 + 0.05, y, z), Vector3(0.04, ep + 0.06, ep + 0.06))
	boite("fer", Vector3(x1 - 0.05, y, z), Vector3(0.04, ep + 0.06, ep + 0.06))
	j1()

# ------------------------------------------------------------------ lumière
func lumiere(pos: Vector3, couleur: Color, energie: float, portee: float, att := 1.7, vacille := true) -> OmniLight3D:
	if muet:
		if vacille:
			rng.randf()      # même tirage qu'une lumière posée
		return null
	var l := OmniLight3D.new()
	l.light_color = couleur
	if est_crypte:
		energie *= GAIN_LUMIERE
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = att * (1.3 if est_crypte else 1.0)     # 4e passe : flaques de feu plus serrées, pierre froide entre elles
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20.0
	l.distance_fade_length = 6.0
	l.position = xf * pos
	ajouter_lumiere(l)     # avant add_child : position lue hors de l'arbre
	racine.add_child(l)
	if vacille:
		lumieres.append([l, energie, rng.randf() * 10.0])
	return l

## Inscrit une OmniLight3D dans `toutes` en notant sa position et sa portée (à appeler AVANT qu'un fil ne lise le décor).
func ajouter_lumiere(l: OmniLight3D) -> void:
	toutes.append(l)
	pos_lum[l] = [l.position, l.omni_range]

## Flamme en sprite pixel art (fusionnée en MultiMesh par cellule dans finir()) ; `echelle` 1 = torche, 1,7 = brasero.
func flamme(pos: Vector3, echelle := 1.0) -> void:
	if muet:
		rng.randf()      # même tirage qu'une flamme émise
		return
	_flammes_def.append([xf * pos, echelle, rng.randf() * 4.0])

func _mat_flamme() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = FLAMME_SHADER
	sm.set_shader_parameter("atlas", ObjetsTextures.tex("flamme"))    # même atlas que la torche tenue
	return sm

## Même flamme, isolée, accrochée à un parent (torche tenue en main).
func flamme_sur(parent: Node3D, pos: Vector3, echelle := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	mi.mesh = q
	var sm := _mat_flamme()
	sm.set_shader_parameter("echelle_u", echelle)
	mi.material_override = sm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Carte additive (halo, rai) : centre, normale horizontale ou verticale, largeur x hauteur.
func carte(nom: String, centre: Vector3, normale: Vector3, w: float, h: float) -> void:
	var n := normale.normalized()
	var droite := Vector3.UP.cross(n)
	var haut := Vector3.UP
	if absf(n.y) > 0.9:
		droite = Vector3.RIGHT
		haut = Vector3.FORWARD
	else:
		droite = droite.normalized()
	var a := centre - droite * w * 0.5 - haut * h * 0.5
	var b := centre + droite * w * 0.5 - haut * h * 0.5
	var c := centre + droite * w * 0.5 + haut * h * 0.5
	var d := centre - droite * w * 0.5 + haut * h * 0.5
	var n_obj := _obj_n          # carte (halo, rai, flaque) : décalque sans volume, hors du registre d'audit
	_obj_n = 0
	quad(nom, a, b, c, d, n, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	_obj_n = n_obj

## Applique murale : platine, bras, coupelle, torche goudronnée, flamme, halo net sur le mur, lumière courte.
func applique(plan_mur: Vector3, vers: Vector3, haut := 2.1, portee := 5.0, energie := 1.9, avec_lumiere := true) -> void:
	j0("applique", atan2(vers.x, vers.z))
	var d := vers.normalized()
	var lacet := atan2(d.x, d.z)
	var p := Vector3(plan_mur.x, haut, plan_mur.z)
	boite("fer", p + d * 0.03, Vector3(0.16, 0.36, 0.06), lacet)
	boite("fer", p + d * 0.17 - Vector3(0, 0.06, 0), Vector3(0.05, 0.05, 0.32), lacet)
	tour("fer", p + d * 0.32 - Vector3(0, 0.1, 0), [Vector2(0.05, 0.0), Vector2(0.075, 0.12)], 6, -1.0, false)
	tour("bois", p + d * 0.32 - Vector3(0, 0.08, 0), [Vector2(0.03, 0.0), Vector2(0.035, 0.3)], 6, -1.0, true)
	tour("bois", p + d * 0.32 + Vector3(0, 0.12, 0), [Vector2(0.045, 0.0), Vector2(0.062, 0.1)], 6, -1.0, false)
	flamme(p + d * 0.32 + Vector3(0, 0.2, 0), 1.6)
	carte("halo", p + d * 0.13 + Vector3(0, 0.3, 0), d, 1.4, 1.4)
	if avec_lumiere:
		lumiere(p + d * 0.5 + Vector3(0, 0.45, 0), FEU_CRYPTE if est_crypte else FEU, energie, portee, 1.5 if est_crypte else 1.8)
	j1()

func brasero(pos: Vector3, froid := false) -> void:  # froid : lumière bleue (inutilisée dans la crypte actuelle)
	j0("brasero")
	pos = _ecarter(pos, Vector2(0.47, 0.47))
	emprise("brasero", pos, Vector2(0.47, 0.47), 0.0, 0.92)
	var prof := [Vector2(0.36, 0.0), Vector2(0.32, 0.1), Vector2(0.24, 0.36), Vector2(0.26, 0.66), Vector2(0.44, 0.74), Vector2(0.5, 0.9), Vector2(0.42, 0.92)]
	tour("mur0", pos, prof, 8, PI / 8.0, false)
	tour("fer", pos + Vector3(0, 0.0, 0), [Vector2(0.505, 0.78), Vector2(0.505, 0.9)], 8, PI / 8.0, false)   # cerclage
	tour("braise", pos + Vector3(0, 0.84, 0), [Vector2(0.4, 0.0), Vector2(0.4, 0.0)], 8, PI / 8.0, true)
	flamme(pos + Vector3(0, 0.9, 0), 1.7)
	carte("halo", pos + Vector3(0, 0.02, 0), Vector3.UP, 3.4, 3.4)
	lumiere(pos + Vector3(0, 1.4, 0), Color(0.45, 0.75, 1.0) if froid else (FEU_BRASERO if est_crypte else FEU), 2.4, 5.8, 1.7 if not est_crypte else 1.4)
	j1()

# ------------------------------------------------------------------ mobilier (Méso)
func sarcophage(pos: Vector3, taille: Vector3, lacet := 0.0, collision := true) -> void:
	ObjPierreStatuaire.sarcophage(self, pos, taille, lacet, collision)

func coffre(pos: Vector3, lacet := 0.0, collision := true) -> void:
	ObjPetitMobilier.coffre(self, pos, lacet, collision)

func bougie(pos: Vector3, avec_lumiere := true) -> void:
	ObjPetitMobilier.bougie(self, pos, avec_lumiere)

func urne(pos: Vector3, e := 1.0, cotes := 8) -> void:
	ObjPetitMobilier.urne(self, pos, e, cotes)

func tonneau(pos: Vector3, e := 1.0) -> void:
	ObjPetitMobilier.tonneau(self, pos, e)

func table(pos: Vector3, lacet := 0.0) -> void:
	ObjPetitMobilier.table(self, pos, lacet)

func etagere(pos: Vector3, lacet: float, largeur := 1.8, haut := 2.0) -> void:
	ObjMobilierBois.etagere(self, pos, lacet, largeur, haut)

# ------------------------------------------------------------------ petits objets (Micro)
func crane(pos: Vector3, lacet := 0.0) -> void:
	ObjPetitMobilier.crane(self, pos, lacet)

func os_tas(pos: Vector3, n := 4, rayon := 0.4) -> void:
	ObjPetitMobilier.os_tas(self, pos, n, rayon)

func arme(pos: Vector3, lacet := 0.0) -> void:
	ObjPetitMobilier.arme(self, pos, lacet)

func toile(coin: Vector3, a: Vector3, b: Vector3, l := 1.1) -> void:
	j0("toile")
	# triangle incliné : le coin, un point le long du mur A, un point le long du mur B plus bas
	var p0 := coin
	var p1 := coin + a.normalized() * l - Vector3(0, 0.1 * l, 0)
	var p2 := coin + b.normalized() * l - Vector3(0, 0.85 * l, 0)
	var n := (p1 - p0).cross(p2 - p0).normalized()
	p0 = xf * p0
	p1 = xf * p1
	p2 = xf * p2
	n = xf.basis * n
	if _j_prof > 0:
		_jp(p0); _jp(p1); _jp(p2)
	var buf := _buf((p0 + p1 + p2) / 3.0, "toile")
	_tri(buf, p0, p1, p2, n, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
	j1()

func rai(pos_bas: Vector3, haut: float, largeur := 1.4) -> void:
	j0("rai")
	for k in 2:
		var n := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		carte("rai", pos_bas + Vector3(0, haut * 0.5, 0), n, largeur, haut)
	j1()

## Flaque de lumière froide au sol sous un rai.
func flaque_froide(pos: Vector3, diametre := 3.0) -> void:
	j0("flaque_froide")
	if v2:
		eau_slot(pos, diametre * 0.5, "flaque_froide")
	carte("halo_f", pos + Vector3(0, 0.02, 0), Vector3.UP, diametre, diametre)
	j1()

func oculus(pos: Vector3, cote := 1.6) -> void:
	j0("oculus")
	# trou carré au plafond : fond noir, cadre de pierre en saillie
	quad("noir", pos + Vector3(-cote * 0.5, -0.01, -cote * 0.5), pos + Vector3(cote * 0.5, -0.01, -cote * 0.5), pos + Vector3(cote * 0.5, -0.01, cote * 0.5), pos + Vector3(-cote * 0.5, -0.01, cote * 0.5), Vector3.DOWN)
	for s in [-1.0, 1.0]:
		boite("mur1", pos + Vector3(s * (cote * 0.5 + 0.12), -0.08, 0), Vector3(0.24, 0.16, cote + 0.48))
		boite("mur1", pos + Vector3(0, -0.08, s * (cote * 0.5 + 0.12)), Vector3(cote, 0.16, 0.24))
	j1()

func poussiere(centre: Vector3, ext: Vector3, nombre := 28) -> void:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = 7.0
	p.position = xf * centre
	ext = (xf.basis * ext).abs()
	p.visibility_aabb = AABB(-ext - Vector3.ONE, ext * 2.0 + Vector3(2, 2, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3.ZERO
	FilVerrou.sur_fil_principal(p, &"set_process_material", [pm])   # matériaux neufs : compilés sur le fil principal (voir FilVerrou.sur_fil_principal)
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.022)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.albedo_color = Color(0.7, 0.8, 1.0, 0.8)
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	FilVerrou.sur_fil_principal(p, &"set_draw_pass_mesh", [0, q])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(p)


# ------------------------------------------------------------------ récit : statues, bannières, gravures, pillage (kit de donjon)
## Repère d'un plan décoré : [droite, haut] pour une normale `vers` (mur vertical ou sol/plafond).
func _axes(vers: Vector3) -> Array:
	var n := vers.normalized()
	if absf(n.y) > 0.9:
		return [Vector3.RIGHT, Vector3.FORWARD * signf(n.y)]
	var dr := Vector3.UP.cross(n).normalized()
	return [dr, Vector3.UP]

## Rectangle tourné dans un plan (décalque) : centre c, axes dr/ha, décalé de (cx, cy), taille w x h, angle ang.
func _rect(nom: String, c: Vector3, dr: Vector3, ha: Vector3, cx: float, cy: float, w: float, h: float, ang: float, n: Vector3, col := Color.WHITE) -> void:
	var s := sin(ang)
	var co := cos(ang)
	var pts: Array = []
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx := k.x * w * 0.5
		var ly := k.y * h * 0.5
		pts.append(c + dr * (cx + lx * co - ly * s) + ha * (cy + lx * s + ly * co))
	quad(nom, pts[0], pts[1], pts[2], pts[3], n, [], [], [col, col, col, col])

## Cercle rituel GRAVÉ au sol (crypte v2) : anneaux fins de petits tronçons (72 par anneau) + 12 repères radiaux, à la place des douze grosses
## barres de l'emblème « cercle » (les « gros carrés » clairs vus du sol). Teinte froide et sombre : la gravure se lit, elle ne brille pas.
func cercle_grave(centre: Vector3, rayon: float, teinte := Color(0.46, 0.5, 0.58)) -> void:
	var n := Vector3.UP
	var dr: Vector3 = _axes(n)[0]
	var ha: Vector3 = _axes(n)[1]
	var c := centre + Vector3(0, 0.02, 0)
	for anneau: Array in [[rayon, 0.07, 72], [rayon * 1.32, 0.045, 96], [rayon * 0.62, 0.035, 56]]:
		var R: float = anneau[0]
		var seg: int = anneau[2]
		var long := TAU * R / seg * 1.12
		for k in seg:
			var a := TAU * k / seg
			_rect("gravure", c, dr, ha, cos(a) * R, sin(a) * R, long, anneau[1], a + PI * 0.5, n, teinte)
	for k in 12:
		var a := TAU * k / 12.0
		var R := rayon * 0.97
		_rect("gravure", c, dr, ha, cos(a) * R * 1.16, sin(a) * R * 1.16, rayon * 0.34, 0.05, a, n, teinte)

## Barres [cx, cy, w, h, angle] d'un symbole sur [-0.5, 0.5] : sceaux (os, givre, eau), formes des énigmes, scènes des gravures.
func _symbole(sujet: String) -> Array:
	var r: Array = []
	match sujet:
		"cercle":
			for k in 12:
				var a := TAU * k / 12.0
				r.append([cos(a) * 0.34, sin(a) * 0.34, 0.07, 0.2, a + PI * 0.5])
		"disque":
			r.append([0.0, 0.0, 0.5, 0.5, 0.0])
			r.append([0.0, 0.0, 0.5, 0.5, PI * 0.25])
		"triangle":
			r.append([0.0, -0.25, 0.72, 0.08, 0.0])
			r.append([-0.18, 0.03, 0.66, 0.08, 1.0])
			r.append([0.18, 0.03, 0.66, 0.08, -1.0])
		"croix":
			r.append([0.0, 0.0, 0.09, 0.78, 0.0])
			r.append([0.0, 0.0, 0.78, 0.09, 0.0])
			r.append([0.0, 0.0, 0.24, 0.24, PI * 0.25])
		"vague":
			for row in [-1, 0, 1]:
				for k in 4:
					var up := k % 2 == 0
					r.append([-0.3 + k * 0.2, row * 0.22 + (0.05 if up else -0.05), 0.24, 0.06, 0.4 if up else -0.4])
		"eau":
			for row in [-1, 0, 1]:
				for k in 5:
					var up := k % 2 == 0
					r.append([-0.32 + k * 0.16, row * 0.2 + (0.04 if up else -0.04), 0.2, 0.06, 0.45 if up else -0.45])
		"os":
			r.append([0.0, 0.12, 0.44, 0.38, 0.0])
			r.append([0.0, -0.1, 0.24, 0.12, 0.0])
			r.append([0.0, -0.3, 0.8, 0.08, 0.55])
			r.append([0.0, -0.3, 0.8, 0.08, -0.55])
		"givre":
			for k in 3:
				r.append([0.0, 0.0, 0.84, 0.07, PI * k / 3.0])
			for k in 6:
				var a := TAU * k / 6.0
				r.append([cos(a) * 0.3, sin(a) * 0.3, 0.2, 0.05, a + 1.0])
				r.append([cos(a) * 0.3, sin(a) * 0.3, 0.2, 0.05, a - 1.0])
		"soleil":
			r.append([0.0, 0.0, 0.34, 0.34, 0.0])
			r.append([0.0, 0.0, 0.34, 0.34, PI * 0.25])
			for k in 8:
				var a := TAU * k / 8.0
				r.append([cos(a) * 0.38, sin(a) * 0.38, 0.16, 0.05, a])
		"couronne":
			r.append([0.0, -0.18, 0.72, 0.14, 0.0])
			for k in [-1, 0, 1]:
				r.append([k * 0.27, 0.1, 0.1, 0.4, 0.0])
				r.append([k * 0.27, 0.34, 0.14, 0.1, PI * 0.25])
		"navire":
			r.append([0.0, -0.22, 0.72, 0.1, 0.0])
			r.append([-0.38, -0.12, 0.2, 0.08, 0.9])
			r.append([0.38, -0.12, 0.2, 0.08, -0.9])
			r.append([0.0, 0.05, 0.05, 0.6, 0.0])
			r.append([0.17, 0.1, 0.3, 0.42, 0.0])
		"hache":
			r.append([0.0, -0.05, 0.07, 0.86, 0.3])
			r.append([0.13, 0.25, 0.32, 0.3, 0.3])
		"epee":
			r.append([0.0, 0.08, 0.07, 0.74, 0.0])
			r.append([0.0, -0.2, 0.42, 0.07, 0.0])
			r.append([0.0, -0.34, 0.1, 0.12, 0.0])
		_:
			r.append([0.0, 0.0, 0.4, 0.4, 0.0])
	return r

## Emblème gravé : plaque de pierre sombre et symbole clair en relief (matière « os », teintable). `vers` = normale du plan (mur, ou UP pour le sol).
func embleme(sujet: String, centre: Vector3, vers: Vector3, taille := 0.9, teinte := Color(0.95, 0.88, 0.7)) -> void:
	j0("embleme", atan2(vers.x, vers.z))
	var n := vers.normalized()
	centre += _saillie(centre, n, 0.33)
	var ax := _axes(n)
	var dr: Vector3 = ax[0]
	var ha: Vector3 = ax[1]
	_rect("mur2", centre + n * 0.012, dr, ha, 0.0, 0.0, taille * 1.2, taille * 1.2, 0.0, n, Color(0.3, 0.3, 0.36))
	for b: Array in _symbole(sujet):
		_rect("os", centre + n * 0.026, dr, ha, b[0] * taille, b[1] * taille, b[2] * taille, b[3] * taille, b[4], n, teinte)
	j1()

## Bas-relief : plusieurs symboles sur une frise (liste de sujets) ; sert aux fresques et aux gravures murales.
func frise(sujets: Array, centre: Vector3, vers: Vector3, taille := 0.9, pas := 1.2, teinte := Color(0.95, 0.88, 0.7)) -> void:
	j0("frise", atan2(vers.x, vers.z))
	var n := vers.normalized()
	centre += _saillie(centre, n, 0.33)
	var cb := saillie_cb
	saillie_cb = Callable()      # les emblèmes de la frise suivent son cadre (déjà avancé)
	var dr: Vector3 = _axes(n)[0]
	var x0 := -(sujets.size() - 1) * pas * 0.5
	for i in sujets.size():
		embleme(sujets[i], centre + dr * (x0 + i * pas), n, taille, teinte)
	# cadre de la frise
	var ha: Vector3 = _axes(n)[1]
	var l := (sujets.size() - 1) * pas + taille * 1.5
	_rect("mur0", centre + n * 0.006, dr, ha, 0.0, 0.0, l, taille * 1.5, 0.0, n, Color(0.7, 0.7, 0.78))
	saillie_cb = cb
	j1()

## Socle de pierre (collision). `taille` = largeur x hauteur x profondeur.
func socle(pos: Vector3, taille := Vector3(0.9, 0.9, 0.9), lacet := 0.0, mat := "mur1") -> void:
	ObjPierreStatuaire.socle(self, pos, taille, lacet, mat)

## Statue de pierre sur socle (visage vers +Z local, tourné de `lacet`). type : guerrier (casque, lance, bouclier), jarl (couronne, épée plantée),
## ancetre (capuche, mains jointes), gardienne (voile).
func statue(pos: Vector3, lacet := 0.0, e := 1.0, type := "guerrier", collision := true, mat := "mur1") -> void:
	ObjPierreStatuaire.statue(self, pos, lacet, e, type, collision, mat)

## Bannière accrochée à une tringle : `haut` = point du mur (hauteur de la tringle), `vers` = normale vers la pièce, usure 0 intacte, 1 déchirée, 2 en lambeaux.
func banniere(haut: Vector3, vers: Vector3, long := 1.7, larg := 0.75, couleur := Color(0.62, 0.3, 0.26), sujet := "", usure := 1, teinte_embleme := Color(0.9, 0.85, 0.7)) -> void:
	ObjMobilierBois.banniere(self, haut, vers, long, larg, couleur, sujet, usure, teinte_embleme)

## Chaîne verticale (maillons alternés) du point `haut` au point `bas`.
func chaine(haut: Vector3, bas: Vector3) -> void:
	j0("chaine")
	var l := haut.distance_to(bas)
	var nb := maxi(2, int(l / 0.1))
	for i in nb:
		var p := haut.lerp(bas, (i + 0.5) / nb)
		boite("fer", p, Vector3(0.06, 0.12, 0.025) if i % 2 == 0 else Vector3(0.025, 0.12, 0.06))
	j1()

## Table d'embaumement : dalle de pierre sur deux piliers, rigole, bandelettes, bol d'huiles ; `corps` : dépouille enveloppée dessus.
func table_embaumement(pos: Vector3, lacet := 0.0, corps := false) -> void:
	ObjPierreStatuaire.table_embaumement(self, pos, lacet, corps)

## Barricade de planches, tonneaux et table renversée en travers d'un passage (largeur `largeur`) ; `trou` > 0 : brèche de cette largeur,
## décalée de `decal` le long du passage (jamais bloquée : les deux blocs de collision laissent la brèche libre).
func barricade(pos: Vector3, lacet := 0.0, largeur := 3.0, trou := 1.3, decal := 0.0) -> void:
	ObjMobilierBois.barricade(self, pos, lacet, largeur, trou, decal)

## Lit de caserne : cadre de bois, paillasse, couverture (teinte) ; collision.
func lit(pos: Vector3, lacet := 0.0, teinte := Color(0.5, 0.4, 0.36)) -> void:
	ObjMobilierBois.lit(self, pos, lacet, teinte)

## Râtelier d'armes contre un mur (dos vers -Z local) : épées, lances, haches.
func ratelier_armes(pos: Vector3, lacet := 0.0, largeur := 1.8) -> void:
	ObjMobilierBois.ratelier_armes(self, pos, lacet, largeur)

## Bouclier rond accroché au mur (octogone de bois cerclé de fer).
func bouclier_mural(centre: Vector3, vers: Vector3, rayon := 0.32, teinte := Color(0.6, 0.4, 0.3)) -> void:
	ObjMobilierBois.bouclier_mural(self, centre, vers, rayon, teinte)

## Autel de chapelle : massif de pierre, nappe, dessus gravé, deux bougies sans lumière.
func autel(pos: Vector3, lacet := 0.0, largeur := 2.0) -> void:
	ObjPierreStatuaire.autel(self, pos, lacet, largeur)

## Bassin : margelle de pierre (collision, h de haut) et surface noire en retrait.
func bassin(centre: Vector3, w: float, p: float, h := 0.5) -> void:
	ObjPierreStatuaire.bassin(self, centre, w, p, h)

## Parchemins, feuillets et livres éparpillés au sol (archives pillées).
func parchemins_epars(centre: Vector3, rayon: float, n := 12) -> void:
	ObjPetitMobilier.parchemins_epars(self, centre, rayon, n)

## Étagère renversée (cadre couché et rayons obliques) : décor d'archives en ruine.
func etagere_renversee(pos: Vector3, lacet := 0.0, largeur := 1.8) -> void:
	ObjMobilierBois.etagere_renversee(self, pos, lacet, largeur)

## Tas de gravats (roche effondrée) : cône irrégulier et blocs ; collision facultative.
func gravats(pos: Vector3, r := 1.0, h := 0.7, avec_collision := true, mat := "mur2") -> void:
	ObjPetitMobilier.gravats(self, pos, r, h, avec_collision, mat)

## Fissures noires qui courent sur un mur (mur fragile : on les voit, et la poussière au pied).
func fissures(centre: Vector3, vers: Vector3, larg := 2.0, haut := 2.6, n := 3, sol := 0.0, avec_gravats := true) -> void:
	var nv := vers.normalized()
	centre += _saillie(centre, nv, 0.27)
	var ax := _axes(nv)
	for k in n:
		var x := -larg * 0.35 + k * larg * 0.35 + rng.randf_range(-0.1, 0.1)
		var y := haut * 0.5
		for j in 6:
			var ang := PI * 0.5 + rng.randf_range(-0.5, 0.5)
			var l := rng.randf_range(0.25, 0.5)
			_rect("noir", centre + nv * 0.02, ax[0], ax[1], x, y - haut * 0.5 + 0.0, 0.03, l, ang - PI * 0.5, nv)
			x += cos(ang) * l * 0.5
			y -= l * 0.55
			if y < 0.1:
				break
	var pg := Vector3(centre.x, sol, centre.z) + nv * 0.5
	var m0 := muet
	muet = m0 or not avec_gravats or not emprise_libre(pg, 0.35, 0.05)      # pas dans un sarcophage, un trône… (tirages faits quand même : la suite ne bouge pas)
	gravats(pg, 0.35, 0.18, false, "mur1")
	muet = m0      # au pied du mur, au sol de l'étage (était y = 0 : gravats en l'air à l'étage −6)

## Dalle de pression fendue : cadre de fissures autour (la dalle elle-même est celle du piège) ; os et fléchette brisée devant.
func dalle_fendue(pos: Vector3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_rect("noir", pos + Vector3(0, 0.017, 0) + b * Vector3(cos(a) * 0.62, 0, sin(a) * 0.62), Vector3.RIGHT, Vector3.FORWARD, 0.0, 0.0, 0.05, 0.5, a + lacet, Vector3.UP)
	os_tas(pos + b * Vector3(0.1, 0, 1.0), 3, 0.35)
	boite("bois", pos + b * Vector3(-0.4, 0.015, 1.3), Vector3(0.3, 0.015, 0.015), lacet + 0.8)

## Sarcophage au couvercle poussé de côté (pillage) : la cuve noire apparaît.
func sarcophage_pille(pos: Vector3, taille: Vector3, lacet := 0.0) -> void:
	ObjPierreStatuaire.sarcophage_pille(self, pos, taille, lacet)

## Sac de pillard éventré (étoffe, pièces, os) et coffre forcé (couvercle dressé derrière, serrure arrachée).
func sac_dechire(pos: Vector3, lacet := 0.0) -> void:
	ObjPetitMobilier.sac_dechire(self, pos, lacet)

func coffre_force(pos: Vector3, lacet := 0.0) -> void:
	ObjPetitMobilier.coffre_force(self, pos, lacet)

## Tapis processionnel (étoffe teintée, deux liserés) posé au sol.
func tapis(centre: Vector3, taille: Vector2, lacet := 0.0, teinte := Color(0.5, 0.2, 0.2)) -> void:
	ObjMobilierBois.tapis(self, centre, taille, lacet, teinte)

## Trône (estrade à deux degrés, siège, haut dossier, accoudoirs) ; collision. `mat` : « mur4 » pour la glace.
func trone(pos: Vector3, lacet := 0.0, mat := "mur1") -> void:
	ObjPierreStatuaire.trone(self, pos, lacet, mat)

## Boîte pleine tournée : visible et solide (la collision reste alignée sur les axes : quarts de tour seulement).
func boite_pleine_l(nom: String, centre: Vector3, taille: Vector3, lacet := 0.0) -> void:
	boite(nom, centre, taille, lacet)
	var s := Basis(Vector3.UP, lacet) * taille
	solide(centre, Vector3(absf(s.x), taille.y, absf(s.z)))

# ------------------------------------------------------------------ vie et fin
## Lumières qui vacillent : trois fréquences + un tirage par pas de 1/12 s (le feu « saute » comme en pixel art).
# ------------------------------------------------------------------ modules Blender (crypte v2)
## Les modules de sources_blender/scripts/crypte_modules_v2.py sont lus dans crypte_v2.dat (FileAccess : sûr dans le fil de
## construction ; un .glb relu ici bloquerait le fil) puis versés dans les MÊMES tampons que les quads (fusion par cellule de 8 m et par
## matière : aucun nœud en plus). UV triplanaires en mètres (même densité de texels que les murs) ; couleurs de sommet = ton x occlusion cuits.
const MODELES_DAT := "res://assets/crypte/modules/crypte_v2.dat"
const MAT_MODELE := {"pierre": "pierre_v2", "fer": "fer", "cire": "os", "bois": "bois", "givre": "neige", "gravure": "gravure"}      # C4b : givre en plaques, inscriptions
static var _modeles := {}            # "module__matiere" -> {"v": PackedVector3Array, "c": PackedColorArray}
static var _modeles_de := {}         # module -> [matières]
static var _modeles_verrou := Mutex.new()
## Drapeau (et non `_modeles.is_empty()`) : d'autres décors peuvent verser leurs propres modules dans _modeles / _modeles_de
## (GrotteDecor.objet, grotte_objets.dat) avant ou après ce premier chargement sans l'empêcher ni être effacés.
static var _modeles_charges := false

static func _charger_modeles() -> void:
	_modeles_verrou.lock()
	if not _modeles_charges:
		_modeles_charges = true
		for chemin: String in [MODELES_DAT, OBJETS_DAT]:
			_lire_dat(chemin)
	_modeles_verrou.unlock()

## Lots L2/L3 objets : mobilier de la crypte et de la grotte (sources_blender/scripts/objets_donjon.py), même format que crypte_v2.dat.
const OBJETS_DAT := "res://assets/crypte/modules/objets_donjon.dat"

static func _lire_dat(chemin: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f != null:
		var n := f.get_32()
		for _k in n:
			var nom := f.get_buffer(f.get_8()).get_string_from_utf8()
			var nb := f.get_32()
			var fl := f.get_buffer(nb * 28).to_float32_array()
			var v := PackedVector3Array()
			var c := PackedColorArray()
			v.resize(nb)
			c.resize(nb)
			for q in nb:
				var o := q * 7
				v[q] = Vector3(fl[o], fl[o + 1], fl[o + 2])
				c[q] = Color(fl[o + 3], fl[o + 4], fl[o + 5], 1.0)
			_modeles[nom] = {"v": v, "c": c}
			var parts := nom.split("__")
			if not _modeles_de.has(parts[0]):
				_modeles_de[parts[0]] = []
			(_modeles_de[parts[0]] as Array).append(parts[1])

static func modele_existe(nom: String) -> bool:
	_charger_modeles()
	return _modeles_de.has(nom)

## Pose un module Blender : pos (repère local du module en cours), lacet (autour de y), échelle ; `mats` remplace une matière
## du module (ex. {"pierre": "mur1"}). Renvoie les points de flamme du module (déjà posés, mêmes repères que `pos`).
## C4 (2026-10-23) : version rapide (les ~300 000 triangles de la crypte entière) : sommets dans l'ordre de Godot et normales cuits une
## fois par module (_modele_cache), transformés en bloc (Transform3D * PackedVector3Array), un seul tampon par pose (case de 8 m du
## point de pose), UV triplanaires en mètres calculés dans le repère de la crypte.
static var _cache_modeles := {}      # "module__matiere|alpha|miroir" -> {"v", "n", "c"} (sommets a, c, b ; normale répétée 3 fois)

func _modele_cache(cle_mat: String, alpha: float, miroir: bool) -> Dictionary:
	var cle := "%s|%.3f|%d" % [cle_mat, alpha, 1 if miroir else 0]
	_modeles_verrou.lock()
	var r: Dictionary = _cache_modeles.get(cle, {})
	if r.is_empty():
		var data: Dictionary = _modeles[cle_mat]
		var v: PackedVector3Array = data["v"]
		var cc: PackedColorArray = data["c"]
		var ov := PackedVector3Array()
		var on := PackedVector3Array()
		var oc := PackedColorArray()
		for q in range(0, v.size(), 3):
			var a := v[q]
			var b := v[q + 1]
			var c := v[q + 2]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-12:
				continue
			n = n.normalized()
			var ca := cc[q]
			var cb := cc[q + 1]
			var c3 := cc[q + 2]
			ca.a = alpha
			cb.a = alpha
			c3.a = alpha
			if miroir:      # la pose inverse l'orientation : ordre a, b, c
				ov.append(a); ov.append(b); ov.append(c)
				oc.append(ca); oc.append(cb); oc.append(c3)
			else:           # face avant = sens horaire (comme _tri)
				ov.append(a); ov.append(c); ov.append(b)
				oc.append(ca); oc.append(c3); oc.append(cb)
			on.append(n); on.append(n); on.append(n)
		var bmin := Vector3(INF, INF, INF)
		var bmax := -bmin
		for q in v.size():
			bmin = bmin.min(v[q])
			bmax = bmax.max(v[q])
		r = {"v": ov, "n": on, "c": oc, "taille": (bmax - bmin) if v.size() > 0 else Vector3.ZERO, "bmin": bmin, "bmax": bmax}
		_cache_modeles[cle] = r
	_modeles_verrou.unlock()
	return r

const _PREFIXES_STRUCTURE := ["pilier_", "colonne_", "arche_", "pan_mur", "lustre", "marches_", "degres_", "estrade_"]
static func _est_structure(nom: String) -> bool:
	for p: String in _PREFIXES_STRUCTURE:
		if nom.begins_with(p):
			return true
	return false

## Lots L2/L3 : une matière absente de MAT_MODELE garde son nom si c'est une matière du décor (bois, os, argile…) ; mats["@<matière>"] =
## Color teinte les sommets de cette matière du module (bannières, boucliers peints) ; emp = false : pas d'emprise propre (l'objet qui
## pose le module a déjà la sienne : os, crânes, mobilier).
func modele(nom: String, pos: Vector3, lacet := 0.0, ech := Vector3.ONE, mats := {}, emp := true) -> Array:
	if muet:
		return []
	j0(nom, lacet)
	_charger_modeles()
	var points: Array = []
	if not _modeles_de.has(nom):
		push_warning("module Blender introuvable : " + nom)
		j1()
		return points
	var b := Basis(Vector3.UP, lacet) * Basis.from_scale(ech)
	var T := xf * Transform3D(b, pos)
	var TN := Transform3D(T.basis.inverse().transposed(), Vector3.ZERO)
	var miroir := T.basis.determinant() < 0.0
	var centre := T.origin
	var e_min := Vector3(INF, INF, INF)
	var e_max := -e_min
	for mat: String in _modeles_de[nom]:
		if mat == "pts":
			var v: PackedVector3Array = (_modeles["%s__pts" % nom] as Dictionary)["v"]
			for q in range(0, v.size(), 3):
				points.append(pos + b * v[q])
			continue
		var cible: String = mats.get(mat, MAT_MODELE.get(mat, mat if TUILE.has(mat) else "mur0"))
		var nom_mat: String = theme.get(cible, cible) if not theme.is_empty() else cible
		var inv := 1.0 / float(TUILE.get(nom_mat, 1.0))
		var cm := _modele_cache("%s__%s" % [nom, mat], niveau_a, miroir)
		var cols: PackedColorArray = cm["c"]
		if mats.has("@" + mat):
			var te: Color = mats["@" + mat]
			cols = cols.duplicate()
			for q in cols.size():
				cols[q] = Color(cols[q].r * te.r, cols[q].g * te.g, cols[q].b * te.b, cols[q].a)
		if cm.has("bmin"):
			e_min = e_min.min(cm["bmin"])
			e_max = e_max.max(cm["bmax"])
		var wv: PackedVector3Array = T * (cm["v"] as PackedVector3Array)
		if _j_prof == 1 and maxf((cm["taille"] as Vector3).x * absf(ech.x), (cm["taille"] as Vector3).z * absf(ech.z)) > 2.5:
			for q in range(0, wv.size(), 3):
				_jtri(wv[q], wv[q + 1], wv[q + 2])
		elif _j_prof > 0:
			for q in wv.size():
				_jp(wv[q])
		if _obj_n > 0:      # registre d'audit (outils/audit_interpenetrations.gd) : les sommets du module comptent dans l'objet ouvert
			_obj_v.append_array(wv)
		var wn: PackedVector3Array = TN * (cm["n"] as PackedVector3Array)
		var nb := wv.size()
		var uv := PackedVector2Array()
		uv.resize(nb)
		for q in range(0, nb, 3):
			var nq := wn[q]
			var ax := absf(nq.x)
			var ay := absf(nq.y)
			var az := absf(nq.z)
			var p0 := wv[q]
			var p1 := wv[q + 1]
			var p2 := wv[q + 2]
			if ay >= ax and ay >= az:
				uv[q] = Vector2(p0.x, p0.z) * inv
				uv[q + 1] = Vector2(p1.x, p1.z) * inv
				uv[q + 2] = Vector2(p2.x, p2.z) * inv
			elif ax >= az:
				uv[q] = Vector2(p0.z, -p0.y) * inv
				uv[q + 1] = Vector2(p1.z, -p1.y) * inv
				uv[q + 2] = Vector2(p2.z, -p2.y) * inv
			else:
				uv[q] = Vector2(p0.x, -p0.y) * inv
				uv[q + 1] = Vector2(p1.x, -p1.y) * inv
				uv[q + 2] = Vector2(p2.x, -p2.y) * inv
		var tl: Vector3 = (cm["taille"] as Vector3) * ech.abs()
		if maxf(tl.x, maxf(tl.y, tl.z)) > 3.0:
			# grand module (arches, degrés, panneaux larges) : triangle par triangle dans la case de 8 m de son centre, comme les quads —
			# un seul tampon élargirait l'AABB du maillage et lui ferait toucher plus de 8 lumières (limite du rendu mobile)
			var cc2: PackedColorArray = cols
			for q in range(0, nb, 3):
				var bt := _buf((wv[q] + wv[q + 1] + wv[q + 2]) / 3.0, nom_mat)
				var tv: PackedVector3Array = bt["v"]
				var tn: PackedVector3Array = bt["n"]
				var tu: PackedVector2Array = bt["u"]
				var tc: PackedColorArray = bt["c"]
				for j in 3:
					tv.append(wv[q + j])
					tn.append(wn[q + j])
					tu.append(uv[q + j])
					tc.append(cc2[q + j])
			continue
		var bf := _buf(centre, nom_mat)
		var bv: PackedVector3Array = bf["v"]
		var bn: PackedVector3Array = bf["n"]
		var bu: PackedVector2Array = bf["u"]
		var bc: PackedColorArray = bf["c"]
		bv.append_array(wv)
		bn.append_array(wn)
		bu.append_array(uv)
		bc.append_array(cols)
	if emp and e_min.x != INF and not _est_structure(nom):
		var ec := ((e_min + e_max) * 0.5) * ech
		var ce := pos + Basis(Vector3.UP, lacet) * Vector3(ec.x, 0.0, ec.z)
		emprise(nom, ce, Vector2(absf((e_max.x - e_min.x) * ech.x), absf((e_max.z - e_min.z) * ech.z)) * 0.5, lacet, (e_max.y - e_min.y) * ech.y)
	j1()
	return points

## D/crypte_restes (2026-10-26) : module Blender en MeshInstance3D AUTONOME, pour les pièces des mécanismes (statue qui pivote,
## brasero qui s'allume) qui ne peuvent pas être fondues dans les tampons du décor. Une surface par matière (matériaux de la crypte,
## mat()), UV triplanaires calculées dans le repère du module (la pierre tourne avec la pièce). Ni emprise ni journal : la collision
## reste celle du mécanisme. `mats` comme modele() (ex. {"pierre": "statue_v2"}).
func maillage_modele(nom: String, ech := Vector3.ONE, mats := {}) -> MeshInstance3D:
	_charger_modeles()
	if not _modeles_de.has(nom):
		push_warning("module Blender introuvable : " + nom)
		return null
	var am := ArrayMesh.new()
	var T := Transform3D(Basis.from_scale(ech), Vector3.ZERO)
	var TN := Transform3D(T.basis.inverse().transposed(), Vector3.ZERO)
	var miroir := T.basis.determinant() < 0.0
	for m: String in _modeles_de[nom]:
		if m == "pts":
			continue
		var cible: String = mats.get(m, MAT_MODELE.get(m, "mur0"))
		var nom_mat: String = theme.get(cible, cible) if not theme.is_empty() else cible
		var inv := 1.0 / float(TUILE.get(nom_mat, 1.0))
		var cm := _modele_cache("%s__%s" % [nom, m], 1.0, miroir)
		var wv: PackedVector3Array = T * (cm["v"] as PackedVector3Array)
		var wn: PackedVector3Array = TN * (cm["n"] as PackedVector3Array)
		var uv := PackedVector2Array()
		uv.resize(wv.size())
		for q in wv.size():
			uv[q] = _uv(wv[q], wn[q - q % 3], 1.0) * inv
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = wv
		arr[Mesh.ARRAY_NORMAL] = wn
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = cm["c"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, mat(nom_mat))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.name = nom
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Givre au sol en décalque irrégulier (texture « givre_sol », alpha découpé) : remplace les plaques de neige du sol.
func givre_decal(centre: Vector3, taille: Vector2, lacet := 0.0) -> void:
	j0("givre_decal", lacet)
	var b := Basis(Vector3.UP, lacet)
	var hx := taille.x * 0.5
	var hz := taille.y * 0.5
	var a := centre + b * Vector3(-hx, 0.007, -hz)
	var bb := centre + b * Vector3(hx, 0.007, -hz)
	var c := centre + b * Vector3(hx, 0.007, hz)
	var d := centre + b * Vector3(-hx, 0.007, hz)
	quad("givre_sol", a, bb, c, d, Vector3.UP)
	j1()

## Flaque PLACEHOLDER (polygone irrégulier plat, sombre) à l'emplacement d'une future eau : l'eau stylisée du système d'eau
## (branche eau/prototype) la remplacera. Les emplacements sont aussi mémorisés dans `eau_slots` (centre, rayon, repère local).
## C4 : chaque emplacement = {centre (repère de la crypte), rayon, module (identifiant de salle), genre ("flaque" | "vasque" | "bassin" |
## "flaque_froide"), taille (Vector2, bassins rectangulaires : largeur x profondeur EN REPÈRE DE LA CRYPTE)}. Lu par tertre.eau_slots().
var eau_slots: Array = []

func eau_slot(centre: Vector3, rayon: float, genre := "flaque", taille := Vector2.ZERO) -> void:
	var t := taille
	if taille != Vector2.ZERO and xf != Transform3D.IDENTITY:
		var tt := (xf.basis * Vector3(taille.x, 0, taille.y)).abs()
		t = Vector2(tt.x, tt.z)
	eau_slots.append({"centre": xf * centre, "rayon": rayon, "module": module_id, "genre": genre, "taille": t})

## Décalage d'un objet accroché au mur (crypte v2 : devant les panneaux de maçonnerie) ; zéro hors v2 ou loin d'un mur.
func _saillie(p: Vector3, n: Vector3, avance: float) -> Vector3:
	if not saillie_cb.is_valid() or absf(n.y) > 0.5:
		return Vector3.ZERO
	return saillie_cb.call(p, n, avance)

func flaque(centre: Vector3, rayon: float, graine := 1, forme := Vector2(1.0, 0.75)) -> void:
	j0("flaque")
	emprise("flaque", centre, Vector2(rayon * forme.x, rayon * forme.y) * 1.1, 0.0, 0.0)
	eau_slot(centre, rayon, "flaque")
	var r := RandomNumberGenerator.new()
	r.seed = graine * 977
	var n := 14
	var rr: Array = []
	for k in n:
		rr.append(rayon * r.randf_range(0.7, 1.1))
	# bord mouillé (anneau clair sous la surface), surface sombre, deux reflets en fines lignes (placeholder : l'eau stylisée viendra du système d'eau)
	for couche: Array in [["flaque_bord", 1.14, 0.009], ["flaque", 1.0, 0.012]]:
		var pts: Array = []
		for k in n:
			var a := TAU * k / n
			pts.append(centre + Vector3(cos(a) * rr[k] * couche[1] * forme.x, couche[2], sin(a) * rr[k] * couche[1] * forme.y))
		for k in n:
			quad(couche[0], centre + Vector3(0, couche[2], 0), pts[k], pts[(k + 1) % n], pts[(k + 1) % n], Vector3.UP)
	for k in 2:
		var a := r.randf_range(-0.5, 0.5)
		var c := centre + Vector3(r.randf_range(-0.3, 0.3) * rayon * forme.x, 0.016, r.randf_range(-0.3, 0.3) * rayon * forme.y)
		var l := rayon * r.randf_range(0.3, 0.5)
		var d := Vector3(cos(a), 0, sin(a)) * l * 0.5
		var w := Vector3(-sin(a), 0, cos(a)) * 0.02
		quad("flaque_reflet", c - d - w, c + d - w, c + d + w, c - d + w, Vector3.UP)
	j1()

func vaciller(t: float) -> void:
	for l in lumieres:
		var ph: float = l[2]
		var pas := floorf(t * 12.0 + ph * 3.0)
		var h := fposmod(sin(pas * 12.9898 + ph) * 43758.5453, 1.0)
		var f := 0.84 + sin(t * 6.3 + ph) * 0.06 + sin(t * 15.1 + ph * 2.0) * 0.04 + (h - 0.5) * 0.12
		(l[0] as OmniLight3D).light_energy = l[1] * f

## Construit les maillages fusionnés (un par cellule de 8 m et par matériau).
func finir() -> void:
	attendre_tout()
	for cle in _bufs:
		var b: Dictionary = _bufs[cle]
		var v: PackedVector3Array = b["v"]
		if v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = b["n"]
		arr[Mesh.ARRAY_TEX_UV] = b["u"]
		arr[Mesh.ARRAY_COLOR] = b["c"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat(b["nom"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Decor_" + String(cle).replace("|", "_").replace(",", "_").replace("-", "m")
		racine.add_child(mi)
	_bufs.clear()
	_bufs_vite.clear()
	var par_case := {}
	for f in _flammes_def:
		var p: Vector3 = f[0]
		var cle := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
		if not par_case.has(cle):
			par_case[cle] = []
		par_case[cle].append(f)
	for cle in par_case:
		var liste: Array = par_case[cle]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.center_offset = Vector3(0, 0.5, 0)
		mm.mesh = q
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, liste[i][0]))
			mm.set_instance_custom_data(i, Color(liste[i][2], liste[i][1], 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat_flamme()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Flammes_%d_%d" % [cle.x, cle.y]
		racine.add_child(mmi)
	_flammes_def.clear()
