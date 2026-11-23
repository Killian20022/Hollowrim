class_name ObjetVivant
extends RigidBody3D
## UN PETIT OBJET DE DÉCOR VIVANT (chope, assiette, pain, pomme, livre…) : corps rigide simple fabriqué par ObjetsVivants (fabrique unique,
## scripts/objets_vivants.gd), dessiné par une instance d'un MultiMesh partagé (même prop Quaternius, mêmes matières que le décor validé).
##   - DORT par défaut : `freeze` (corps statique, coût nul) ; réveillé au contact du joueur, d'un coup de lame (frapper), d'un sort
##     (souffle), d'un voisin qui bouge, ou quand on le saisit ; se rendort (re-gelé) dès qu'il est immobile ~0,35 s ;
##   - calque Cassable.CALQUE (64) : touché par la lame (TraceLame.MASQUE) et les sorts, franchissable par le joueur et les PNJ (masque 1)
##     qu'il voit pourtant (masque 1 | 64) : on le pousse en marchant dedans ;
##   - propriété : meta « proprietaire » du premier ancêtre qui la porte (intérieur, étal) ; prendre un objet possédé = vol (ObjetsVivants).
## Origine du corps = centre de la boîte du prop ; `visuel_local` ramène au repère du prop (pivot au sol, échelle de la pose).

const SEUIL_LIN := 0.08
const SEUIL_ANG := 0.2
const DUREE_REPOS := 0.35
const DUREE_ERRANCE := 5.0     ## un objet réveillé qui ne fait plus que rouler / tournoyer sur place (< SEUIL_ERRANCE m/s) se rendort après ce délai
const SEUIL_ERRANCE := 0.25

var ident := ""
var oid := ""
var genre := ""
var mm: MultiMesh
var idx := -1
var visuel_local := Transform3D.IDENTITY
## Repère d'origine (repère du parent) : rappel si l'objet se perd (chute sous le sol) et position « non déplacé » de la sauvegarde.
var depart := Transform3D.IDENTITY
var deplace := false
var coince := false       ## posé DANS un volume de collision du décor (étagère pleine) : ne se réveille que saisi
var tenu := false
var _repos := 0.0
var _errance := 0.0
var _taille := Vector3.ONE
var _roule := false        ## forme ronde (pomme, chou) : roule, se rendort dès qu'elle n'avance presque plus
var _son_t := 0
## Élan en attente (impulsion, couple) : appliqué au pas de physique suivant par ObjetsVivants (un corps tout juste dégelé ignore
## une impulsion reçue dans la même image).
var elan := Vector3.ZERO
var couple := Vector3.ZERO
## Cassables partout (2026-11-23) : matière (CasseObjets.MATIERES) et seuil d'énergie de casse ; `meuble` = mobilier léger (tonneau,
## caisse, chaise…) : pas d'invite « Prendre », pas poussé par le joueur, et s'il `bloque` il est sur le calque 1 (le joueur et les PNJ
## s'y heurtent comme à l'ancien solide du décor). `contenu` : table de butin versée à la casse (« caisse », « tonneau »…) ;
## `liquide` : une flaque s'étale. `casse` : brisé (état sauvegardé, clé « casse » d'ObjetsVivants.etats).
var matiere := ""
var seuil_casse := INF
var meuble := false
var bloque := false
var contenu := ""
var liquide := false
var casse := false
var _v_prec := Vector3.ZERO

func _init() -> void:
	collision_layer = Cassable.CALQUE
	collision_mask = 1 | Cassable.CALQUE
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.15
	angular_damp = 2.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.85
	pm.bounce = 0.05
	physics_material_override = pm
	add_to_group("objets_vivants")
	if CasseObjets.actif:
		add_to_group("telekinesable")
	body_entered.connect(_contact)

## Forme simple : boîte, cylindre ou sphère de la taille `t` (m), centrée.
func monter_forme(forme: String, t: Vector3) -> void:
	_taille = t
	var cs := CollisionShape3D.new()
	_roule = forme == "sphere"
	if _roule:
		angular_damp = 4.0      # pas de résistance au roulement dans le moteur : une pomme roulerait sans fin
	match forme:
		"sphere":
			var s := SphereShape3D.new()
			s.radius = maxf(0.025, minf(t.x, minf(t.y, t.z)) * 0.5)
			cs.shape = s
		"cyl":
			var c := CylinderShape3D.new()
			c.radius = maxf(0.02, maxf(t.x, t.z) * 0.5)
			c.height = maxf(0.03, t.y)
			cs.shape = c
		_:
			var b := BoxShape3D.new()
			b.size = Vector3(maxf(t.x, 0.03), maxf(t.y, 0.03), maxf(t.z, 0.03))
			cs.shape = b
	add_child(cs)

func nom_objet() -> String:
	return String(Inventaire.objet(oid).get("nom", oid))

func valeur() -> int:
	return int(Inventaire.objet(oid).get("valeur", 0))

## Propriétaire hérité : meta « proprietaire » de l'objet lui-même, sinon du premier ancêtre (intérieur, étal) ; "" = libre.
func proprietaire() -> String:
	var n: Node = self
	while n != null:
		if n.has_meta("proprietaire"):
			return String(n.get_meta("proprietaire"))
		n = n.get_parent()
	return ""

func endormi() -> bool:
	return freeze

## Réveil : corps dynamique. `force` passe outre le contrôle « coincé dans le décor » (objet saisi).
func reveiller(force := false) -> bool:
	if tenu or not is_inside_tree():
		return false
	if not freeze:
		return true
	if not force and (coince or _dans_le_decor()):
		coince = true
		return false
	coince = false
	freeze = false
	sleeping = false
	contact_monitor = true
	max_contacts_reported = 4
	_repos = 0.0
	_errance = 0.0
	ObjetsVivants.eveille(self)
	reveiller_voisins()
	return true

## Réveille les objets endormis qui le touchent (cuisse posée dans l'assiette, chopes serrées) : sinon ils le tiendraient comme un
## mur (un objet gelé est un corps statique).
func reveiller_voisins() -> void:
	if not is_inside_tree():
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = _taille + Vector3.ONE * 0.06
	q.shape = b
	q.transform = Transform3D(global_transform.basis.orthonormalized(), global_transform.origin)
	q.collision_mask = Cassable.CALQUE
	q.exclude = [get_rid()]
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 12):
		var c: Object = r.get("collider")
		if c is ObjetVivant and (c as ObjetVivant).freeze and not (c as Node).has_meta("pris"):
			(c as ObjetVivant).reveiller()

## Rendormi (gelé là où il est) ; la sauvegarde retient sa place s'il a bougé.
func endormir() -> void:
	if freeze:
		return
	freeze = true
	contact_monitor = false
	elan = Vector3.ZERO
	couple = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if not deplace and get_parent() is Node3D:
		var p := (get_parent() as Node3D).global_transform.affine_inverse() * global_transform
		deplace = p.origin.distance_to(depart.origin) > 0.01 or not p.basis.is_equal_approx(depart.basis)
	actualiser_visuel()

## Instance du MultiMesh à la place du corps (repère du MultiMeshInstance3D, frère du corps).
func actualiser_visuel() -> void:
	if mm == null or idx < 0 or not is_inside_tree():
		return
	var p := get_parent() as Node3D
	mm.set_instance_transform(idx, p.global_transform.affine_inverse() * global_transform * visuel_local)

## Pas encore immobile : compteur de repos (appelé par ObjetsVivants pour les objets réveillés, à chaque pas de physique).
func veiller(dt: float) -> bool:
	actualiser_visuel()
	_v_prec = linear_velocity
	if elan != Vector3.ZERO or couple != Vector3.ZERO:
		apply_central_impulse(elan)
		apply_torque_impulse(couple)
		elan = Vector3.ZERO
		couple = Vector3.ZERO
		_repos = 0.0
		return false
	if tenu:
		return false
	if linear_velocity.length() < SEUIL_LIN and (angular_velocity.length() < SEUIL_ANG or _roule):
		_repos += dt
	else:
		_repos = 0.0
	# chope qui tourne sur son pied sans jamais passer sous le seuil angulaire : lente et sans élan, elle finit par se rendormir
	_errance = _errance + dt if linear_velocity.length() < SEUIL_ERRANCE else 0.0
	return _repos >= DUREE_REPOS or _errance >= DUREE_ERRANCE

## Un voisin endormi touché par un objet en mouvement se réveille (pile d'assiettes, chopes renversées en chaîne).
func _contact(autre: Node) -> void:
	if freeze or casse:
		return
	if seuil_casse < INF and not tenu:      # chute, choc contre le décor : casse si l'énergie perdue dépasse le seuil de la matière
		var dv := _v_prec - linear_velocity
		if dv.length() > 2.0 and recevoir_choc(dv, mass, global_position):
			return
	var v := linear_velocity.length()
	if autre is ObjetVivant and (autre as ObjetVivant).freeze and v > 0.25:
		(autre as ObjetVivant).reveiller()
	if v > 1.6 and Time.get_ticks_msec() - _son_t > 250:      # choc sur la table, le plancher : petit bruit de vaisselle
		_son_t = Time.get_ticks_msec()
		Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position, clampf(-26.0 + v * 2.0, -26.0, -12.0), 0.15)

## Le corps (forme réduite) entre-t-il dans un volume de collision fixe du décor ? (objets posés sur une étagère pleine)
func _dans_le_decor() -> bool:
	var espace := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = _taille * Vector3(0.7, 0.5, 0.7)
	q.shape = b
	q.transform = Transform3D(global_transform.basis.orthonormalized(), global_transform.origin + Vector3(0, _taille.y * 0.15, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	for r: Dictionary in espace.intersect_shape(q, 4):
		var c: Object = r.get("collider")
		if c is StaticBody3D:
			return true
	return false

## Facteur de vitesse d'un même élan selon la masse (un couteau part plus vite qu'un seau), borné : rien ne part comme une balle.
func legerete() -> float:
	return clampf(1.0 / sqrt(maxf(mass, 0.05)), 0.7, 1.4)

## Coup de lame (TraceLame, mains._resoudre_impact « cassable ») : l'objet est projeté, la lame continue (vrai).
func frapper(puissant: bool, origine: Vector3) -> bool:
	if casse:
		return false
	if seuil_casse < INF and (CasseObjets.COUP_PUISSANT if puissant else CasseObjets.COUP_LEGER) >= seuil_casse:
		casser(true, origine, (global_position - origine).normalized() * 3.0)
		return true
	if not reveiller():
		return false
	var d := global_position - origine
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var v := (3.5 if puissant else 2.2) * legerete() * (clampf(6.0 / mass, 0.08, 1.0) if meuble else 1.0)
	elan += (d * v + Vector3.UP * v * 0.45) * mass
	couple += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02 * mass
	if meuble:
		CasseObjets.son_choc(self, matiere, global_position, CasseObjets.COUP_PUISSANT if puissant else CasseObjets.COUP_LEGER)
	else:
		Sons.jouer_a(self, ["impactPlate_medium_000", "impactPlate_medium_001"], global_position, -12.0)
	return true

## Souffle d'un sort (point d'impact `de`, force en m/s pour 1 kg, atténuée par la distance).
func souffle(de: Vector3, force: float, rayon: float) -> void:
	var d := global_position - de
	var k := clampf(1.0 - d.length() / maxf(rayon, 0.01), 0.15, 1.0)
	if not reveiller():
		return
	d = d.normalized() if d.length() > 0.01 else Vector3.UP
	var v := force * k * legerete() * (clampf(10.0 / mass, 0.15, 1.0) if meuble else 1.0)
	elan += (d + Vector3.UP * 0.6).normalized() * v * mass
	couple += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03 * mass

## Poussé par le joueur qui marche dedans (le joueur ne le voit pas : masque 1) : petit élan dans le sens de la marche.
func pousser(vitesse: Vector3) -> void:
	if not reveiller():
		return
	var v := Vector3(vitesse.x, 0.0, vitesse.z)
	elan += v.limit_length(2.5) * 0.6 * mass + Vector3.UP * 0.4 * mass

# ------------------------------------------------------------------------------------------------ télékinésie et casse (contrats)

## Masse vue par la télékinésie (kg) : le gros mobilier fixe n'est pas un ObjetVivant ; ici c'est la vraie masse.
func masse_telekinesie() -> float:
	return mass

## Saisi (ou relâché) par la télékinésie : réveillé même coincé dans le décor, ne se rendort pas tant qu'il est tenu.
func saisi_telekinesie(saisi: bool) -> void:
	if casse or has_meta("pris"):
		return
	if saisi:
		reveiller(true)
		tenu = true
		_repos = 0.0
		_errance = 0.0
	else:
		tenu = false

## Choc (ImpactsLances.objet_touche, chute) : énergie ½·m·v² contre le seuil de la matière. Vrai si l'objet est brisé.
## Sous le seuil : simple bruit de choc (bois qui cogne, fer qui sonne) si le choc est notable.
func recevoir_choc(vitesse: Vector3, masse_choc: float, point: Vector3) -> bool:
	if casse or has_meta("pris") or not CasseObjets.actif:
		return false
	var e := CasseObjets.energie(vitesse, masse_choc)
	if e < seuil_casse:
		if e > 15.0 and Time.get_ticks_msec() - _son_t > 200:
			_son_t = Time.get_ticks_msec()
			CasseObjets.son_choc(self, matiere, point, e)
		return false
	casser(true, point, vitesse)
	return true

func est_casse() -> bool:
	return casse

## Brise l'objet : son instance du MultiMesh disparaît, ses morceaux (découpe du modèle) sont projetés, gerbe, poussière, son, contenu
## versé (butin, liquide). `avec_effets` faux : état relu d'une sauvegarde ou d'un instantané (rien ne vole). `distant` : la casse vient
## d'un autre joueur (pas renvoyée sur le réseau).
func casser(avec_effets: bool, point: Vector3, vitesse := Vector3.ZERO, distant := false) -> void:
	if casse:
		return
	casse = true
	var t_debut := Time.get_ticks_usec()
	var xf := global_transform * visuel_local      # repère du modèle (échelle comprise) avant de le cacher
	var v_objet := linear_velocity if not freeze else Vector3.ZERO
	var centre := global_position
	var pied := Vector3(centre.x, centre.y - _taille.y * 0.5, centre.z)
	tenu = false
	if not freeze:
		endormir()
	ObjetsVivants.noter_casse(self)
	if is_inside_tree() and process_mode != Node.PROCESS_MODE_DISABLED:
		reveiller_voisins()      # ce qui reposait dessus retombe
	collision_layer = 0
	collision_mask = 0
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	if mm != null and idx >= 0:
		mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ZERO), transform.origin))
	if not avec_effets:
		return
	var parent := get_parent() as Node3D
	var t0 := Time.get_ticks_usec()
	CasseObjets.eclater(parent, mm.mesh if mm != null else null, xf, matiere, mass, point, v_objet + vitesse * 0.35, ident.hash())
	var t1 := Time.get_ticks_usec()
	CasseObjets.effets(parent, centre, pied, point, matiere, maxf(_taille.x, maxf(_taille.y, _taille.z)), liquide)
	var t2 := Time.get_ticks_usec()
	if contenu != "":
		CasseObjets.verser_butin(parent, ident, contenu, pied)
	CasseObjets.derniere_mesure = {"eclats_ms": (t1 - t0) / 1000.0, "effets_ms": (t2 - t1) / 1000.0, "butin_ms": (Time.get_ticks_usec() - t2) / 1000.0}
	var proprio := proprietaire()
	if proprio != "" and not distant:      # bien d'un PNJ brisé : comme un vol (témoins, prime), règles du lot crime
		var crime := get_tree().get_first_node_in_group("crime")
		if crime != null and crime.has_method("signaler_vol"):
			crime.signaler_vol(self, proprio, centre)
	if not distant:
		ObjetsVivants.diffuser_casse(self, point, vitesse)
	CasseObjets.derniere_mesure["total_ms"] = (Time.get_ticks_usec() - t_debut) / 1000.0
