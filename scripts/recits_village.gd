class_name RecitsVillage
extends Node
## Décor et indices des quêtes sans combat de Skarnholt (data/quetes.json : « grenier_maigre », « fil_rouge » ;
## docs/ACCUEIL_ET_QUETES.md). Aucune règle ici : les quêtes avancent par les événements qu'on signale à scripts/quetes.gd.
## - Serrure du grenier commun (bâtiment « grenier », Gunnar) : « Examiner la serrure » → indice:grenier_serrure.
## - Grange de l'est (« grange_a ») : une trappe sous la paille ; « Fouiller la paille » → le bâton de taille de Gunnar
##   (ramasse:baton_taille). Conséquence visible : après la vérité dite à Grima, la trappe reste ouverte et deux sacs
##   ont disparu ; après le silence, la paille la recouvre de nouveau.
## Posé par monde.gd après les intérieurs du village (Recits.poser) ; repères locaux des intérieurs (porte côté +Z).

const QUETE_GRENIER := "grenier_maigre"
## Trappe dans la grange de l'est, repère local de l'intérieur (X = grand axe, Z = largeur, sol à Interieurs.F).
const TRAPPE_LOCAL := Vector3(1.0, 0.0, 0.6)
## Repli (bâtiments non ouverts : --bati-ancien) : coordonnées monde des deux points.
const SERRURE_MONDE := Vector2(58.9, 22.9)
const TRAPPE_MONDE := Vector2(86.9, 25.5)

var monde: Node
var quetes: Node
var serrure: Node3D
var paille: Node3D
var trappe_fermee: Node3D
var trappe_ouverte: Node3D
var _t := 0.0
var _etat := ""

static func poser(m: Node) -> RecitsVillage:
	var r := RecitsVillage.new()
	r.name = "RecitsVillage"
	r.monde = m
	r.quetes = m.get("quetes")
	m.add_child(r)
	r._construire()
	return r

func _index() -> int:
	return int(quetes.index(QUETE_GRENIER)) if quetes != null else 0

func _construire() -> void:
	var village: Node = monde.get("village")
	var ig: Node3D = village.interieur("grenier") if village != null and village.has_method("interieur") else null
	var ia: Node3D = village.interieur("grange_a") if village != null and village.has_method("interieur") else null
	# --- serrure du grenier : devant la porte, à hauteur de main
	serrure = _interactif("Grenier commun", "Examiner la serrure", 2.4)
	if ig != null:
		var pl: Vector3 = ig.get("porte_locale")
		serrure.position = pl + Vector3(0, -0.3, 0.55)
		ig.add_child(serrure)
	else:
		serrure.position = _sol(SERRURE_MONDE) + Vector3(0, 1.2, 0)
		monde.add_child(serrure)
	serrure.condition = func() -> bool: return _index() >= 1
	serrure.action = _examiner_serrure
	# --- trappe de la grange de l'est
	var racine := Node3D.new()
	racine.name = "TrappeGrange"
	if ia != null:
		racine.position = TRAPPE_LOCAL + Vector3(0, Interieurs.F, 0)
		ia.add_child(racine)
	else:
		racine.position = _sol(TRAPPE_MONDE)
		monde.add_child(racine)
	_trappe(racine)
	paille = _interactif("Paille de la grange", "Fouiller la paille", 1.6)
	paille.position = Vector3(0, 0.45, 0)
	paille.condition = func() -> bool: return _index() >= 2
	paille.action = _fouiller_paille
	racine.add_child(paille)
	_actualiser()

func _sol(p: Vector2) -> Vector3:
	var h: float = monde.hauteur(p.x, p.y) if monde.has_method("hauteur") else 0.0
	return Vector3(p.x, h, p.y)

func _interactif(nom: String, verbe: String, rayon: float) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = monde.get("joueur")
	it.dialogue = monde.get("dialogue")
	it.nom = nom
	it.verbe = verbe
	it.rayon = rayon
	return it

## Trappe : fermée (planches au ras de la paille) ou ouverte (vantail relevé, trou sombre, sacs au fond).
func _trappe(racine: Node3D) -> void:
	var bois := TexturesBati.m_planches(Color(0.78, 0.66, 0.52))
	var sombre := TexturesBati.m_planches(Color(0.10, 0.08, 0.07))
	var toile := TexturesBati.m_cuir(Color(1.25, 1.12, 0.92))
	trappe_fermee = Node3D.new()
	racine.add_child(trappe_fermee)
	_boite(trappe_fermee, Vector3(1.0, 0.05, 0.8), Vector3(0, 0.07, 0), bois)   # au-dessus de la paille (dessus à F + 0,055)
	_boite(trappe_fermee, Vector3(0.9, 0.02, 0.06), Vector3(0, 0.105, -0.2), bois)   # barres de la trappe
	_boite(trappe_fermee, Vector3(0.9, 0.02, 0.06), Vector3(0, 0.105, 0.2), bois)
	trappe_ouverte = Node3D.new()
	trappe_ouverte.visible = false
	racine.add_child(trappe_ouverte)
	_boite(trappe_ouverte, Vector3(0.96, 0.03, 0.76), Vector3(0, 0.07, 0), sombre)
	var vantail := _boite(trappe_ouverte, Vector3(1.0, 0.05, 0.8), Vector3(0, 0.42, -0.42), bois)
	vantail.rotation.x = deg_to_rad(-78.0)
	for k in 2:   # deux sacs restés au bord : les autres sont partis au puits
		var s := _boite(trappe_ouverte, Vector3(0.42, 0.38, 0.3), Vector3(0.75 + 0.18 * k, 0.19, 0.25 - 0.4 * k), toile)
		s.rotation.y = 0.4 + 0.7 * k

func _boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _examiner_serrure() -> Array:
	if _index() == 1:
		quetes.signaler("indice:grenier_serrure")
		return ["La serrure est intacte. Pas une rayure. Quelqu’un l’a même graissée, il n’y a pas longtemps : le fer ne grince plus.",
			"Sur les marches gelées, quelques balles d’orge. Elles filent vers l’est, vers les fermes, et se perdent dans la neige tassée.",
			"Deux clés ouvrent ce grenier. Gunnar en porte une. Haldor, à la porte du hameau, porte l’autre."]
	return ["Une serrure graissée de frais, et des balles d’orge vers l’est. Il n’y a rien de plus à lire ici."]

func _fouiller_paille() -> Array:
	var inv: Inventaire = monde.joueur.inventaire
	if _index() == 2 and not inv.a("baton_taille"):
		inv.ajouter("baton_taille", 1)   # le sac signale « ramasse:baton_taille » (quetes.gd)
		var hud: Node = monde.get("hud")
		if hud != null:
			hud.avis("+ " + inv.nom("baton_taille"))
		return ["Sous la paille, le sol sonne creux. Une trappe, aux gonds huilés comme la serrure du grenier.",
			"Dessous, onze sacs d’orge rangés au sec, marqués de la rune du hameau. Pas jetés là : rangés, comme dans un cellier.",
			"Contre le dernier sac, un bâton de taille. Un cran par sac, et des encoches pour les semaines, jusqu’au dégel. La rune de Gunnar est brûlée dans le bois."]
	match _etat:
		"verite":
			return ["La trappe est restée ouverte. Il ne reste au fond que l’odeur de l’orge, et deux sacs qu’on n’a pas encore emportés."]
		"silence":
			return ["La paille a été remise en place, bien égale. On ne devinerait rien, si l’on ne savait pas."]
	return ["Onze sacs au sec, sous la paille. Je les laisse où ils sont."]

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	_actualiser()

## Trappe ouverte seulement après la vérité ; sinon fermée (sous la paille).
func _actualiser() -> void:
	var e := ""
	if quetes != null and quetes.vus.has("issue:grenier_maigre:verite"):
		e = "verite"
	elif quetes != null and quetes.vus.has("issue:grenier_maigre:silence"):
		e = "silence"
	_etat = e
	trappe_fermee.visible = e != "verite"
	trappe_ouverte.visible = e == "verite"
