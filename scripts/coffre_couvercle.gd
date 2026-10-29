class_name CoffreCouvercle
extends Node3D
## Lot L1 « coffre à couvercle » (docs/INSPIRATION_IGNITE.md §2.6) : COUVERCLE d'un coffre en deux pièces. La cuve (et l'or qu'elle
## contient) est fondue dans les tampons du décor (ObjPetitMobilier.coffre, deux_pieces) ; le couvercle est ce nœud, posé sur la
## CHARNIÈRE ARRIÈRE (origine du module « coffre_couvercle_x » / « coffre_royal_couvercle »), maillage en enfant tourné autour de x.
##   - ouvrir() : bascule en 0,5 s (courbe en S jusqu'à 106 % puis petit rebond vers l'angle final) ; lueur chaude BRÈVE depuis
##     l'intérieur : OmniLight3D (préréglage Bougie, 0,6 s, sans ombre) SEULEMENT si CrypteDecor.lumiere_possible le permet (≤ 8
##     lumières par maillage), puis halo additif sur l'or qui s'éteint en 0,9 s ; rien ne reste allumé ensuite.
##   - ouvrir(true) : ouvert d'un coup (partie chargée : l'état vient de quetes.vus, voir tertre._etat_donjon / GrotteJeu._etat).
##   - fermer() : refermé d'un coup (mort du joueur avant d'avoir ramassé la bourse : le coffre redevient pillable).
## Aucun _process hors de l'animation. Le butin reste tiré par ButinTables ; l'or de la cuve est un décor (rien à ramasser).
## Lot L3 : l'OR de la cuve (module « coffre_or_x » / « coffre_royal_or », nappe + pièces + objet posé) n'est plus fondu dans les
## tampons : c'est un maillage enfant de ce nœud, qui S'ENFONCE sous le fond de la cuve pendant que les pièces jaillissent
## (OR_DEBUT → OR_FIN) puis disparaît : un coffre pillé est vide. Ouvert d'emblée (partie chargée) : pas d'or ; refermé : l'or revient.

const ANGLE := 1.75          # rad (≈ 100°) : couvercle un peu au-delà de la verticale
const DUREE := 0.5
const T_HAUT := 0.36         # fin de la montée en S (106 %), puis rebond jusqu'à DUREE
const DEPASSE := 1.06
const LUEUR_DUREE := 0.6
const HALO_DUREE := 0.9
const LUEUR_PORTEE := 1.8
const OR_DEBUT := 0.2        # s : l'or commence à s'enfoncer (les premières pièces sont en l'air)
const OR_FIN := 1.1          # s : l'or est sous le fond de la cuve, caché

var decor: CrypteDecor       # pour lumiere_possible (lumières de la case et du voisin)
var lueur_pos := Vector3.ZERO      # intérieur de la cuve, repère du parent (= racine du décor)
var modele := ""                   # module Blender du couvercle (« coffre_couvercle_b », « coffre_royal_couvercle »)
var ouvert := false
var _maillage: MeshInstance3D
var _t := -1.0
var _lueur: OmniLight3D
var _halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _halo_taille := Vector2(0.8, 0.5)
var _or: MeshInstance3D      # L3 : or de la cuve (null si le module manque)
var _or_base := Vector3.ZERO
var _or_couches := 1
var _or_creux := 0.0         # profondeur d'enfoncement (hauteur de l'or + 1 cm : son sommet passe sous le fond de la cuve)

## Couvercle prêt à poser sous la racine du décor (`info` : retour de CrypteDecor.coffre(…, deux_pieces) / coffre_royal) ; null si
## le module manque. À appeler sur le fil principal (matériaux du décor).
static func creer(dcr: CrypteDecor, info: Dictionary) -> CoffreCouvercle:
	if info.is_empty():
		return null
	var mi := dcr.maillage_modele(String(info["modele"]))
	if mi == null:
		return null
	var c := CoffreCouvercle.new()
	c.name = "Couvercle_" + String(info["modele"])
	c.transform = info["xf"]
	c.decor = dcr
	c.lueur_pos = info["lueur"]
	c.modele = String(info["modele"])
	if String(info["modele"]).begins_with("coffre_royal"):
		c._halo_taille = Vector2(1.05, 0.6)
	mi.visibility_range_end = CrypteDonjon.PORTEE_DESSIN + 2.0
	mi.visibility_range_end_margin = 3.0
	c._maillage = mi
	c.add_child(mi)
	if info.has("or"):              # L3 : or de la cuve, repère de la cuve = charnière - décalage
		var mo := dcr.maillage_modele(String(info["or"]))
		if mo != null:
			mo.name = "Or"
			mo.position = -(info["charniere"] as Vector3)
			mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mo.visibility_range_end = CrypteDonjon.PORTEE_DESSIN + 2.0
			mo.visibility_range_end_margin = 3.0
			c._or = mo
			c._or_base = mo.position
			c._or_creux = mo.get_aabb().size.y + 0.01
			c._or_couches = mo.layers
			c.add_child(mo)
	c.set_process(false)
	c.process_mode = Node.PROCESS_MODE_ALWAYS     # L3 : le couvercle finit de s'ouvrir sous la fenêtre de butin (jeu en pause)
	return c

## Angle actuel du couvercle (rad, 0 = fermé) : tests et captures.
func angle() -> float:
	return -_maillage.rotation.x if _maillage != null else 0.0

func _poser(f: float) -> void:
	_maillage.rotation = Vector3(-ANGLE * f, 0.0, 0.0)

func ouvrir(instant := false) -> void:
	if ouvert and not instant:
		return
	ouvert = true
	if instant:
		_finir_effets()
		_poser(1.0)
		_poser_or(1.0)
		_t = -1.0
		set_process(false)
		return
	_t = 0.0
	_effets()
	set_process(true)

func fermer() -> void:
	ouvert = false
	_finir_effets()
	_t = -1.0
	_poser(0.0)
	_poser_or(0.0)
	set_process(false)

## L3 : or enfoncé de f (0 = en place, 1 = sous le fond, caché).
func _poser_or(f: float) -> void:
	if _or == null:
		return
	var u := clampf(f, 0.0, 1.0)
	_or.position = _or_base - Vector3(0, _or_creux * u * u * (3.0 - 2.0 * u), 0)
	# caché par ses couches de rendu, pas par `visible` (SalleActive gère `visible` des maillages du décor salle par salle)
	_or.layers = _or_couches if u < 1.0 else 0

## Tests et captures : or de la cuve visible (pas encore pillé).
func or_visible() -> bool:
	return _or != null and _or.layers != 0

## Courbe d'ouverture : S (smoothstep) jusqu'à DEPASSE à T_HAUT, puis retour amorti à 1 (petit rebond) à DUREE.
static func courbe(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < T_HAUT:
		var u := t / T_HAUT
		return DEPASSE * u * u * (3.0 - 2.0 * u)
	if t < DUREE:
		var u := (t - T_HAUT) / (DUREE - T_HAUT)
		return DEPASSE - (DEPASSE - 1.0) * sin(u * PI * 0.5)
	return 1.0

## Captures (monde.gd, option coffres=id:T) : ouverture FIGÉE à T s (couvercle, lueur et halo dans l'état de cet instant).
func figer(t: float) -> void:
	fermer()
	ouvert = true
	_t = 0.0
	_effets()
	_t = t
	_maj()
	set_process(false)

func _process(dt: float) -> void:
	if _t < 0.0:
		set_process(false)
		return
	_t += dt
	_maj()

func _maj() -> void:
	_poser(courbe(_t))
	_poser_or((_t - OR_DEBUT) / (OR_FIN - OR_DEBUT))
	if _lueur != null:
		var k := clampf(_t / 0.12, 0.0, 1.0) * clampf(1.0 - (_t - 0.12) / (LUEUR_DUREE - 0.12), 0.0, 1.0)
		_lueur.light_energy = Lumieres.BOUGIE["energie"] * 2.2 * k
		if _t >= LUEUR_DUREE:
			_lueur.queue_free()
			_lueur = null
	if _halo != null:
		var a := clampf(_t / 0.1, 0.0, 1.0) * clampf(1.0 - (_t - 0.1) / (HALO_DUREE - 0.1), 0.0, 1.0)
		_halo_mat.albedo_color = Color(1.0, 0.62, 0.26) * (0.75 * a)
		_halo.position.y = lueur_pos.y + 0.03 + 0.12 * clampf(_t / HALO_DUREE, 0.0, 1.0)
		if _t >= HALO_DUREE:
			_halo.queue_free()
			_halo = null
	if _t >= maxf(maxf(DUREE, OR_FIN), maxf(LUEUR_DUREE, HALO_DUREE)):
		_t = -1.0
		_poser(1.0)
		_poser_or(1.0)
		set_process(false)

func _effets() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	# lumière brève : seulement si la case et ses voisines restent à 8 lumières par maillage (limite du rendu mobile)
	if decor != null and decor.lumiere_possible(lueur_pos, LUEUR_PORTEE):
		_lueur = OmniLight3D.new()
		_lueur.light_color = Lumieres.BOUGIE["couleur"]
		_lueur.light_energy = 0.0
		_lueur.omni_range = LUEUR_PORTEE
		_lueur.omni_attenuation = Lumieres.BOUGIE["att"]
		_lueur.shadow_enabled = false
		_lueur.position = lueur_pos + Vector3(0, 0.08, 0)
		parent.add_child(_lueur)
	# halo additif sur l'or (matière « halo » du décor, teinte animée sur une copie : aucun nouveau shader)
	if decor != null:
		var base := decor.mat("halo") as StandardMaterial3D
		if base != null:
			_halo_mat = base.duplicate() as StandardMaterial3D
			_halo_mat.albedo_color = Color(0, 0, 0)
			var q := PlaneMesh.new()
			q.size = _halo_taille
			_halo = MeshInstance3D.new()
			_halo.mesh = q
			_halo.material_override = _halo_mat
			_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_halo.position = lueur_pos + Vector3(0, 0.03, 0)
			_halo.rotation.y = transform.basis.get_euler().y      # lacet du coffre (repère du parent)
			parent.add_child(_halo)

func _finir_effets() -> void:
	if _lueur != null:
		_lueur.queue_free()
		_lueur = null
	if _halo != null:
		_halo.queue_free()
		_halo = null
