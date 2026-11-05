class_name ObjetsVivants
extends Node3D
## OBJETS DE DÉCOR VIVANTS (retours exe 5 : « faire vivre les verres, la nourriture… », comme dans Skyrim) : FABRIQUE UNIQUE et gestion.
##
## RECENSEMENT (2026-11-05) — petits objets du décor, tous des props Quaternius fondus dans les lots (aucun nœud par objet) :
##   - intérieurs (halle de Gunnhild, maisons de Sigrún, des chasseurs, de Grima, forge de Brodd) : Interieurs.q / qf / nq et les
##     raccourcis chope, assiette, bol, cruche, livre, parchemin, mets, fromage ;
##   - marché (MobilierVillage.POSES_Q / POSES_L4) : primeurs, viandes, poissons, bouteilles des trois étals ;
##   - étals de Brodd et de Grima (EtalMarchand) : pièces du stock exposées (glb / primitives d'ObjetMonde).
## Les objets PENDUS (viandes, herbes, saucisses sous l'auvent : _q_xf), les bougies à flamme, les gros meubles et les jarres restent du décor.
##
## FABRIQUE : Interieurs / MobilierVillage demandent `capte(prop)` puis rangent une `spec` (prop, transformation, matières DÉJÀ résolues du
## décor) au lieu de fondre le prop ; `peupler(parent, specs, lieu)` crée, par apparence (prop + matières), UN MultiMesh (un appel de dessin
## par apparence et par pièce) et un ObjetVivant (corps rigide gelé) par objet. Même maillage, mêmes matériaux que le décor validé.
## Les fiches d'objet : data/objets/decor.json (prop_q / mats_q : ObjetMonde.visuel dessine le même prop, icônes et objets lâchés).
##
## VIE : ObjetVivant dort (gelé) ; réveil au contact du joueur, coup de lame, sort (souffle_a), voisin ; rendormi à l'arrêt ; au-delà de
## PORTEE_ACTIVE (25 m) de la caméra tout objet réveillé est rendormi sur place, et les MultiMesh ne sont plus dessinés.
## INTERACTION : regarder un objet (rayon depuis la caméra, ≤ PORTEE_PRISE) → invite « Prendre <nom> (valeur) », « Voler … » en rouge s'il
## a un propriétaire ; E bref = prendre (au sac, ButinTables.prendre) ; E maintenu = saisir (l'objet suit le regard), E relâché = lâcher,
## clic gauche pendant la saisie = lancer. PRENDRE un objet possédé : Conteneur.noter_vol + groupe « crime » → signaler_vol(objet,
## propriétaire, position) s'il existe (la réaction est l'affaire du lot crime).
## SAUVEGARDE (clé « objets_vivants » de Monde) : objets pris (heure de jeu, Marchand.heures) et objets déplacés (transformation locale).
## Les denrées d'un étal du marché (meta « reassort_jours ») reviennent à leur place après ce nombre de jours de jeu.
## `-- --sans-objets-vivants` : tout reste fondu dans le décor comme avant (captures « avant », mesures A/B).

const PORTEE_ACTIVE := 25.0
const PORTEE_PRISE := 2.6
const DUREE_SAISIE := 0.3
const DIST_TENU := 1.25
const VITESSE_LANCER := 9.0
const ROUGE := Color(0.93, 0.33, 0.27)
const PARCHEMIN := Color("#e9dcc0")

static var actif := not ("--sans-objets-vivants" in OS.get_cmdline_user_args())

## prop du décor -> objet du registre (data/objets/decor.json ; pain et potions existants).
const OBJETS := {"q_chope": "chope", "q_assiette": "assiette_etain", "q_ecuelle": "ecuelle", "q_ecuelle_2": "ecuelle", "q_marmite": "pot_argile",
	"q_vase_2": "cruche", "q_vase_4": "cruche", "q_couteau_f": "couteau_table", "q_fourchette_f": "fourchette", "q_cuillere_bois": "cuillere_bois",
	"q_livre_7": "livre_relie", "q_parchemin": "parchemin", "q_seau_bois": "seau_bois", "q_seau_fer": "seau_fer", "q_pierre_aiguiser": "pierre_aiguiser",
	"q_chandelier_table": "chandelier", "q_pomme": "pomme", "q_pomme_verte": "pomme", "q_chou": "chou", "q_navet": "navet", "q_carotte": "carotte",
	"q_pain": "pain_seigle", "q_tranche_pain": "tranche_pain", "q_cuisse": "cuisse_rotie", "q_viande": "viande_crue", "q_lard": "lard",
	"q_saucisse": "saucisse", "q_saucisse_crue": "saucisse", "q_poisson": "poisson", "q_oeuf": "oeuf", "q_oeuf_blanc": "oeuf",
	"q_champignon": "champignon", "q_bouteille_1": "hydromel", "q_bouteille_2": "hydromel", "q_bouteille": "hydromel",
	"q_potion_1": "potion_soin", "q_potion_4": "potion_mana", "fromage": "fromage"}
## Forme de collision (défaut : boîte de l'emprise du prop).
const FORMES := {"q_pomme": "sphere", "q_pomme_verte": "sphere", "q_chou": "sphere", "q_oeuf": "sphere", "q_oeuf_blanc": "sphere",
	"q_chope": "cyl", "q_bouteille_1": "cyl", "q_bouteille_2": "cyl", "q_bouteille": "cyl", "q_vase_2": "cyl", "q_vase_4": "cyl", "q_seau_bois": "cyl",
	"q_seau_fer": "cyl", "q_marmite": "cyl", "q_assiette": "cyl", "q_ecuelle": "cyl", "q_ecuelle_2": "cyl", "fromage": "cyl", "q_chandelier_table": "cyl",
	"q_potion_1": "cyl", "q_potion_4": "cyl"}

static var tous: Array = []          ## ObjetVivant créés (les libérés sont retirés au passage)
static var _eveilles: Array = []
## État de la partie : ident -> {"pris": heure de jeu} ou {"p": [x, y, z, qx, qy, qz, qw]} (repère du parent).
static var etats := {}
static var _maillages := {}          ## apparence -> ArrayMesh
static var _boites := {}             ## genre -> AABB (repère du prop)
static var _mats_int := {}

var joueur: CharacterBody3D
var dialogue: Control
var hud: Control
var _visee: ObjetVivant
var _proxy: Visee
var _e_t := -1.0
var _tenu: ObjetVivant
var _dist_tenu := DIST_TENU
var _acc := 0.0

## Cible de l'invite « E » (boîte de dialogue) : posée sur l'objet visé ; toujours prioritaire sur le plus proche.
class Visee extends Node3D:
	var gestion: Node
	func nom_affiche() -> String:
		return gestion.call("_nom_visee")
	func texte_action() -> String:
		return gestion.call("_texte_visee")
	func prioritaire() -> bool:
		return true
	func couleur_invite() -> Color:
		return gestion.call("_couleur_visee")
	func parler() -> Array:      # manette (A) : la boîte de dialogue appelle parler() ; le clavier passe par _input (E bref / maintenu)
		gestion.call("_prendre_visee")
		return []

# ------------------------------------------------------------------------------------------------ fabrique (statique)

static func capte(nom: String) -> bool:
	return actif and OBJETS.has(nom) and Inventaire.connu(String(OBJETS[nom]))

## Spec d'un objet : `genre` (prop), `xf` (repère du futur parent, échelle comprise), `morceaux` = [[arrays, Material]] (repère du prop).
static func spec(genre: String, xf: Transform3D, morceaux: Array) -> Dictionary:
	return {"genre": genre, "xf": xf, "morceaux": morceaux}

## Morceaux d'un prop Quaternius, matière du prop -> Material par `choisir` (Callable(matière: String) -> Material).
static func morceaux_q(nom: String, choisir: Callable) -> Array:
	var res := []
	for m: Array in PropsQuaternius.morceaux(nom):
		res.append([m[1], choisir.call(String(m[0]))])
	return res

## Meule de fromage entamée (même géométrie que Interieurs.fromage : meule de 22 cm, quartier), repère du prop (pivot au sol).
static func morceaux_fromage(mat: Material) -> Array:
	var meule := _deplacer(PrimGeo.cylindre(0.11, 0.11, 0.09, 8), Transform3D(Basis(), Vector3(0, 0.045, 0)))
	var quartier := _deplacer(PrimGeo.boite(Vector3(0.09, 0.06, 0.06)), Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.17, 0.03, 0.02)))
	return [[meule, mat], [quartier, mat]]

static func _deplacer(a: Array, xf: Transform3D) -> Array:
	var r := a.duplicate()
	var v: PackedVector3Array = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	for k in v.size():
		v[k] = xf * v[k]
		n[k] = (xf.basis * n[k]).normalized()
	r[Mesh.ARRAY_VERTEX] = v
	r[Mesh.ARRAY_NORMAL] = n
	return r

## Matières des intérieurs (Interieurs.materiaux), une seule copie (objets lâchés, icônes) ; le village prête les siennes s'il existe.
static func materiaux_interieur() -> Dictionary:
	if _mats_int.is_empty():
		_mats_int = Interieurs.materiaux()
	return _mats_int

## Morceaux d'un objet du registre par sa fiche (prop_q, mats_q) ; [] sans prop.
static func morceaux_objet(oid: String) -> Array:
	var f := Inventaire.objet(oid)
	var M := materiaux_interieur()
	if oid == "fromage":
		return morceaux_fromage(M["fromage_q"])
	var nom := String(f.get("prop_q", ""))
	if nom == "" or not PropsQuaternius.existe(nom):
		return []
	var mats: Dictionary = f.get("mats_q", {})
	return morceaux_q(nom, func(m: String) -> Material: return M.get(String(mats.get(m, Interieurs.MATS_Q.get(m, "bois"))), M["bois"]))

## Boîte du prop (repère du prop) d'après ses morceaux.
static func boite_morceaux(morceaux: Array) -> AABB:
	var bb := AABB()
	var premier := true
	for m: Array in morceaux:
		for p: Vector3 in (m[0] as Array)[Mesh.ARRAY_VERTEX]:
			if premier:
				bb = AABB(p, Vector3.ZERO)
				premier = false
			else:
				bb = bb.expand(p)
	return bb

static func _cle(genre: String, morceaux: Array) -> String:
	var c := genre
	for m: Array in morceaux:
		c += "|%d" % (m[1] as Object).get_instance_id()
	return c

static func maillage(cle: String, morceaux: Array) -> ArrayMesh:
	if _maillages.has(cle):
		return _maillages[cle]
	var am := ArrayMesh.new()
	for m: Array in morceaux:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m[0])
		am.surface_set_material(am.get_surface_count() - 1, m[1])
	_maillages[cle] = am
	return am

## Crée les objets de `specs` sous `parent` (pièce d'un intérieur, étal…) ; `lieu` préfixe les identifiants (sauvegarde). Fil principal.
static func peupler(parent: Node3D, specs: Array, lieu: String) -> Array:
	var res := []
	if specs.is_empty() or parent == null:
		return res
	var groupes := {}          # apparence -> [morceaux, [[spec, ident]]]
	var compte := {}
	for s: Dictionary in specs:
		var g := String(s["genre"])
		var k := int(compte.get(g, 0))
		compte[g] = k + 1
		var cle := _cle(g, s["morceaux"])
		if not groupes.has(cle):
			groupes[cle] = [s["morceaux"], []]
		(groupes[cle][1] as Array).append([s, "%s:%s:%d" % [lieu, g, k]])
	for cle: String in groupes:
		var morceaux: Array = groupes[cle][0]
		var liste: Array = groupes[cle][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = maillage(cle, morceaux)
		mm.instance_count = liste.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Vivants_" + cle.get_slice("|", 0)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = PORTEE_ACTIVE
		parent.add_child(mmi)
		for i in liste.size():
			var s: Dictionary = liste[i][0]
			var o := _corps(s, morceaux)
			o.ident = liste[i][1]
			o.mm = mm
			o.idx = i
			o.name = "Vivant_%s_%d" % [String(s["genre"]), i]
			parent.add_child(o)
			mm.set_instance_transform(i, o.transform * o.visuel_local)
			tous.append(o)
			_appliquer(o)
			res.append(o)
	return res

## Pièce exposée sur l'étal d'un marchand (EtalMarchand, visuel d'ObjetMonde déjà posé) : enveloppée d'un corps gelé à sa place.
## La prendre la retire du STOCK du marchand (le réassort de Marchand la ramène) ; pas d'état propre dans la sauvegarde.
static func piece_d_etal(v: Node3D, marchand: String) -> ObjetVivant:
	var oid := String(v.get_meta("oid", ""))
	var parent := v.get_parent() as Node3D
	if oid == "" or parent == null or not Inventaire.connu(oid):
		return null
	var bb := ObjetMonde.boite(v, v.transform)
	var o := ObjetVivant.new()
	o.genre = "etal"
	o.oid = oid
	o.ident = "etal_%s:%s" % [marchand, oid]
	o.set_meta("marchand", marchand)
	o.mass = clampf(float(Inventaire.objet(oid).get("poids", 1.0)), 0.1, 6.0)
	o.transform = Transform3D(Basis(), bb.get_center())
	o.depart = o.transform
	o.monter_forme("boite", bb.size * 0.94)
	parent.add_child(o)
	v.reparent(o, true)
	return o

static func _corps(s: Dictionary, morceaux: Array) -> ObjetVivant:
	var g := String(s["genre"])
	if not _boites.has(g):
		_boites[g] = boite_morceaux(morceaux)
	var bb: AABB = _boites[g]
	var xf: Transform3D = s["xf"]
	var sc := xf.basis.get_scale().abs()
	var r := xf.basis.orthonormalized()
	var c := bb.get_center() * sc
	var o := ObjetVivant.new()
	o.genre = g
	o.oid = String(OBJETS.get(g, g))
	o.mass = clampf(float(Inventaire.objet(o.oid).get("poids", 0.3)), 0.05, 4.0)
	o.visuel_local = Transform3D(Basis.from_scale(sc), -c)
	o.depart = Transform3D(r, xf.origin + r * c)
	o.transform = o.depart
	o.monter_forme(String(FORMES.get(g, "boite")), bb.size * sc * 0.94)
	return o

# ------------------------------------------------------------------------------------------------ état (sauvegarde)

static func exporter() -> Dictionary:
	var d := {}
	var vivants := {}
	for o: ObjetVivant in _vivants():
		vivants[o.ident] = true
	for ident: String in etats:      # objets pris, et états d'objets pas encore créés (intérieurs posés après le chargement)
		if (etats[ident] as Dictionary).has("pris") or not vivants.has(ident):
			d[ident] = etats[ident]
	for o: ObjetVivant in _vivants():
		if o.has_meta("pris"):
			continue
		if not o.freeze:
			o.endormir()
		if o.deplace:
			var t := o.transform
			var q := t.basis.get_rotation_quaternion()
			d[o.ident] = {"p": [t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w]}
	return d

static func importer(d: Dictionary) -> void:
	etats = d.duplicate(true)
	for o: ObjetVivant in _vivants():
		_appliquer(o)

## Nouvelle partie : aucun objet pris ni déplacé (les objets déjà créés de cette scène sont remis à leur place).
static func reinitialiser() -> void:
	etats = {}
	for o: ObjetVivant in _vivants():
		_appliquer(o)

## Contenu d'un intérieur à la demande libéré (Interieur.decharger) : les objets déplacés de `parent` gardent leur place dans `etats`
## (les pris y sont déjà), puis ils sortent de la liste ; `peupler` les recrée à l'identique (mêmes identifiants) au rechargement.
static func liberer(parent: Node) -> void:
	var r := []
	for o in tous:
		if not is_instance_valid(o):
			continue
		if not parent.is_ancestor_of(o):
			r.append(o)
			continue
		_eveilles.erase(o)
		if o.has_meta("pris"):
			continue
		if not o.freeze:
			o.endormir()
		if o.deplace:
			var t: Transform3D = o.transform
			var q := t.basis.get_rotation_quaternion()
			etats[o.ident] = {"p": [t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w]}
	tous = r

static func _vivants() -> Array:
	var r := []
	for o in tous:
		if is_instance_valid(o):
			r.append(o)
	tous = r
	return r

## Applique l'état connu (pris, déplacé, ou à sa place d'origine) à un objet créé.
static func _appliquer(o: ObjetVivant) -> void:
	var st: Dictionary = etats.get(o.ident, {})
	if st.has("pris"):
		if _revient(o, float(st["pris"])):
			etats.erase(o.ident)
			_restaurer(o)
		else:
			_retirer(o)
		return
	if o.has_meta("pris"):
		_restaurer(o)
	if not o.freeze:
		o.endormir()
	if st.has("p"):
		var p: Array = st["p"]
		o.transform = Transform3D(Basis(Quaternion(p[3], p[4], p[5], p[6])), Vector3(p[0], p[1], p[2]))
		o.deplace = true
	elif o.deplace:
		o.transform = o.depart
		o.deplace = false
	if o.mm != null:
		o.mm.set_instance_transform(o.idx, o.transform * o.visuel_local)

## Denrée d'un étal (meta « reassort_jours » sur un ancêtre) prise depuis assez longtemps : elle revient.
static func _revient(o: ObjetVivant, h_pris: float) -> bool:
	var n: Node = o
	while n != null:
		if n.has_meta("reassort_jours"):
			return Marchand.heures - h_pris >= float(n.get_meta("reassort_jours")) * 24.0
		n = n.get_parent()
	return false

static func _retirer(o: ObjetVivant) -> void:
	if not o.freeze:
		o.endormir()
	if o.is_inside_tree() and o.process_mode != Node.PROCESS_MODE_DISABLED:
		o.reveiller_voisins()      # ce qui reposait dessus (cuisse dans l'assiette) retombe
	o.set_meta("pris", true)
	o.collision_layer = 0
	o.collision_mask = 0
	o.process_mode = Node.PROCESS_MODE_DISABLED
	o.visible = false
	if o.mm != null:
		o.mm.set_instance_transform(o.idx, Transform3D(Basis.from_scale(Vector3.ZERO), o.transform.origin))

static func _restaurer(o: ObjetVivant) -> void:
	o.remove_meta("pris")
	o.collision_layer = Cassable.CALQUE
	o.collision_mask = 1 | Cassable.CALQUE
	o.process_mode = Node.PROCESS_MODE_INHERIT
	o.visible = true
	o.transform = o.depart
	o.deplace = false
	if o.mm != null:
		o.mm.set_instance_transform(o.idx, o.transform * o.visuel_local)

static func eveille(o: ObjetVivant) -> void:
	if not _eveilles.has(o):
		_eveilles.append(o)

## Souffle d'un sort au point `p` : les objets à moins de `rayon` m sont réveillés et projetés.
static func souffle_a(p: Vector3, rayon := 1.4, force := 4.0) -> int:
	var n := 0
	for o: ObjetVivant in _vivants():
		if o.has_meta("pris") or not o.is_inside_tree():
			continue
		if o.global_position.distance_to(p) < rayon:
			o.souffle(p, force, rayon)
			n += 1
	return n

# ------------------------------------------------------------------------------------------------ gestion (nœud du monde)

static func creer(monde: Node) -> ObjetsVivants:
	var g := ObjetsVivants.new()
	g.name = "ObjetsVivants"
	g.joueur = monde.get("joueur")
	g.dialogue = monde.get("dialogue")
	g.hud = monde.get("hud")
	monde.add_child(g)
	return g

func _ready() -> void:
	_proxy = Visee.new()
	_proxy.name = "Visee"
	_proxy.gestion = self
	add_child(_proxy)

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func _process(dt: float) -> void:
	_acc += dt
	if _acc > 5.0:      # réassort des étals pendant la partie
		_acc = 0.0
		for o: ObjetVivant in _vivants():
			if o.has_meta("pris") and etats.has(o.ident) and _revient(o, float((etats[o.ident] as Dictionary).get("pris", 0.0))):
				etats.erase(o.ident)
				_restaurer(o)
	if joueur == null or dialogue == null:
		return
	_viser()
	if _e_t >= 0.0:
		_e_t += dt
		if _e_t >= DUREE_SAISIE:
			_e_t = -1.0
			if _visee != null:
				saisir(_visee)

## Objet sous le réticule (rayon caméra, décor compris : un mur devant l'objet le cache).
func _viser() -> void:
	var v: ObjetVivant = null
	var cam := _camera()
	if cam != null and _tenu == null and not joueur.mort and not joueur.en_dialogue:
		var o := cam.global_position
		var q := PhysicsRayQueryParameters3D.create(o, o - cam.global_transform.basis.z * PORTEE_PRISE, 1 | Cassable.CALQUE, [joueur.get_rid()])
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty() and r["collider"] is ObjetVivant and not (r["collider"] as Node).has_meta("pris"):
			v = r["collider"]
	_visee = v
	if v != null:
		_proxy.global_position = v.global_position
		dialogue.inviter(_proxy)
	else:
		dialogue.retirer_invite(_proxy)
		_e_t = -1.0

func _nom_visee() -> String:
	return _visee.nom_objet() if _visee != null else ""

func _texte_visee() -> String:
	if _visee == null:
		return ""
	return "%s %s (%d)" % ["Voler" if _visee.proprietaire() != "" else "Prendre", _visee.nom_objet(), _visee.valeur()]

func _couleur_visee() -> Color:
	return ROUGE if _visee != null and _visee.proprietaire() != "" else PARCHEMIN

func _prendre_visee() -> void:
	if _visee != null:
		prendre(_visee)

func _est_e(e: InputEvent) -> bool:
	return (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_E) or e.is_action("interagir")

func _input(e: InputEvent) -> void:
	if joueur == null or joueur.mort or joueur.en_dialogue:
		return
	if e is InputEventKey and (e as InputEventKey).echo:
		return
	if _est_e(e):
		if e.is_pressed():
			if _tenu != null:
				lacher()
				get_viewport().set_input_as_handled()
			elif _visee != null and dialogue.invite_courante() == _proxy:
				_e_t = 0.0
				get_viewport().set_input_as_handled()
		else:
			if _tenu != null:
				lacher()
				get_viewport().set_input_as_handled()
			elif _e_t >= 0.0:
				_e_t = -1.0
				if _visee != null:
					prendre(_visee)
				get_viewport().set_input_as_handled()
	elif _tenu != null and e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and e.is_pressed():
		lancer()
		get_viewport().set_input_as_handled()

## Met l'objet au sac. Objet possédé : marqué volé au sac et signalé au lot crime (groupe « crime », signaler_vol) s'il existe.
func prendre(o: ObjetVivant) -> bool:
	if o == null or o.has_meta("pris") or joueur == null:
		return false
	var inv: Inventaire = joueur.inventaire
	var proprio := o.proprietaire()
	var res := ButinTables.prendre(inv, [{"id": o.oid, "n": 1, "rarete": ButinTables.rarete_de(o.oid)}])
	if res.is_empty():
		return false
	if proprio != "":
		inv.noter_vol(o.oid, 1)
		var crime := get_tree().get_first_node_in_group("crime")
		if crime != null and crime.has_method("signaler_vol"):
			crime.signaler_vol(o, proprio, o.global_position)
	if o.has_meta("marchand"):      # pièce d'étal : sort du stock du marchand
		var st := Marchand.stock(String(o.get_meta("marchand")))
		st[o.oid] = int(st.get(o.oid, 0)) - 1
		if int(st[o.oid]) <= 0:
			st.erase(o.oid)
	else:
		etats[o.ident] = {"pris": Marchand.heures}
	if _tenu == o:
		_tenu = null
	o.tenu = false
	_retirer(o)
	Sons.interface(get_tree().current_scene if get_tree().current_scene != null else get_tree().root, ["ui_ramasse"], -9.0)
	if hud != null and hud.has_method("avis"):
		hud.avis(("Volé : %s" if proprio != "" else "%s ajouté") % o.nom_objet())
	return true

## Saisie (E maintenu) : l'objet suit le regard à DIST_TENU m, sans gravité.
func saisir(o: ObjetVivant) -> bool:
	if o == null or o.has_meta("pris") or not o.reveiller(true):
		return false
	_tenu = o
	o.tenu = true
	o.gravity_scale = 0.0
	o.add_collision_exception_with(joueur)      # tenu devant soi : ne bute pas contre son porteur
	var cam := _camera()      # tenu à la distance où on l'a saisi (comme dans Skyrim), dans des bornes de bras
	_dist_tenu = clampf(cam.global_position.distance_to(o.global_position), 0.7, DIST_TENU) if cam != null else DIST_TENU
	dialogue.retirer_invite(_proxy)
	return true

func lacher() -> void:
	if _tenu == null:
		return
	var o := _tenu
	_tenu = null
	if is_instance_valid(o):
		o.tenu = false
		o.gravity_scale = 1.0
		o.remove_collision_exception_with(joueur)
		o.linear_velocity = o.linear_velocity.limit_length(2.5)

func lancer() -> void:
	if _tenu == null:
		return
	var o := _tenu
	lacher()
	var cam := _camera()
	if cam != null and is_instance_valid(o):
		o.linear_velocity = -cam.global_transform.basis.z * clampf(VITESSE_LANCER / sqrt(maxf(o.mass, 0.1)), 4.0, 10.0) + Vector3.UP * 0.8
		o.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
		Sons.jouer_a(self, ["cloth1"], o.global_position, -12.0)

func objet_tenu() -> ObjetVivant:
	return _tenu

func objet_vise() -> ObjetVivant:
	return _visee

func _physics_process(dt: float) -> void:
	var cam := _camera()
	var oeil := cam.global_position if cam != null else Vector3(1e5, 0, 1e5)
	# objet saisi : suit le regard (vitesse vers la cible, rotation amortie) ; trop loin (coincé derrière le décor) : lâché
	if _tenu != null:
		if not is_instance_valid(_tenu) or cam == null:
			_tenu = null
		else:
			var cible := oeil - cam.global_transform.basis.z * _dist_tenu
			var d := cible - _tenu.global_position
			if d.length() > 2.4:
				lacher()
			else:
				_tenu.linear_velocity = (d * 14.0).limit_length(9.0)
				_tenu.angular_velocity *= 0.8
	# objets réveillés : visuel suivi, rendormis à l'arrêt, au loin, ou rappelés s'ils sont tombés sous le sol
	var i := _eveilles.size() - 1
	while i >= 0:
		var o: ObjetVivant = _eveilles[i] if is_instance_valid(_eveilles[i]) else null
		if o == null or o.freeze:
			_eveilles.remove_at(i)
		elif o.global_position.distance_to(oeil) > PORTEE_ACTIVE:
			o.endormir()
			_eveilles.remove_at(i)
		elif o.get_parent() is Node3D and o.position.y < o.depart.origin.y - 3.0:
			o.endormir()
			o.transform = o.depart
			o.deplace = false
			o.actualiser_visuel()
			_eveilles.remove_at(i)
		elif o.veiller(dt):
			o.endormir()
			_eveilles.remove_at(i)
		i -= 1
	# le joueur marche dans un objet endormi : il est poussé (le joueur ne le voit pas, masque 1)
	if joueur != null and not joueur.mort:
		var v: Vector3 = joueur.velocity
		var pj := joueur.global_position
		if Vector2(v.x, v.z).length() > 0.6:
			for x in tous:
				if not is_instance_valid(x):
					continue
				var o: ObjetVivant = x
				if not o.freeze or o.coince or o.has_meta("pris"):
					continue
				var p := o.global_position
				var h := p.y - pj.y
				if h < -0.2 or h > 0.9:
					continue
				if Vector2(p.x - pj.x, p.z - pj.z).length() < 0.42:
					o.pousser(v)
