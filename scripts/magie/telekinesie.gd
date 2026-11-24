class_name Telekinesie
extends Node
## TÉLÉKINÉSIE (sort « telekinesie », école « esprit », DonneesSort.Portee.TELEKINESIE) : maintenir le bouton en visant un objet
## SAISISSABLE l'arrache du sol (petit à-coup, poussière) puis le fait léviter devant la main ; relâcher le LANCE vers le réticule.
## Un nœud par MainSort (enfant « Telekinesie ») ; MainSort l'appelle depuis la machine à états de la main (état CANALISE).
##
## Objets saisissables (contrat docs/MAGIE.md, « Télékinésie ») :
##   - groupe `telekinesable` : RigidBody3D, ou nœud qui sait se changer en corps (`corps_telekinesie() -> RigidBody3D`) ;
##     méthodes facultatives : `masse_telekinesie() -> float`, `saisi_telekinesie(saisi: bool)`, `donnees_arme() -> DonneesArme` ;
##   - armes posées (ObjetMonde d'une arme, arme lâchée par un ennemi mort : meta « tk_arme ») : changées en ArmeLancee (scripts/combat/arme_lancee.gd) ;
##   - REPLI tant que la branche « cassables partout » n'est pas fusionnée : les petits objets vivants (ObjetVivant).
## Impact d'un objet lancé : `ImpactsLances.objet_touche(objet, cible, point, normale, vitesse, lanceur)` (branche impacts) s'il
## existe ; sinon REPLI minimal : dégâts par LanceurSorts.frapper (masse × vitesse, ou dégâts lourds de l'arme), arme plantée
## (ou qui traverse si elle tue), choc transmis par `recevoir_choc` / `frapper` des cassables.
## Mana : arrachement `cout + cout_par_kg × masse` (quasi gratuit), drain `cout_par_seconde + drain_par_kg × masse` par seconde, lancer `cout_lancer + cout_lancer_par_kg × masse` ; plus de mana =
## l'objet tombe. Refus lisibles : « Trop lourd. », « Pas assez de mana. ».
## `-- --sans-telekinesie` : le sort n'existe pas (ni raccourci, ni sort connu) — comportement d'avant.

const ECOLE := "esprit"
## Visuels de la main (aura, runes, son de charge) : ceux de l'école « protection » (bleu pâle) ; l'école « esprit » n'a pas
## (encore) d'aura propre dans GestionMagie.
const ECOLE_VISUELLE := "protection"
const GROUPE := "telekinesable"
## Aide à la visée de la saisie : demi-angle (°) autour du réticule, élargi de la taille apparente de l'objet.
const AIDE_VISEE := 9.0
## Aide à la visée du lancer : un ennemi à moins de ce demi-angle (°) du réticule est visé en son centre.
const AIDE_LANCER := 8.0
const PORTEE_LANCER := 40.0
## Arrachement : durée (s) de l'à-coup vers le haut avant que le ressort ne prenne l'objet.
const ARRACHE := 0.16
const VITESSE_ARRACHE := 2.6
## Ressort amorti de la tenue : raideur (1/s, vitesse voulue = écart × RAIDEUR), amorti (1/s), vitesse maximale (m/s).
const RAIDEUR := 7.5
const AMORTI := 9.0
const VITESSE_TENUE := 16.0
## Décalage de l'objet tenu vers le côté de la main (m) et un peu sous la ligne de visée.
const COTE := 0.28
const BAS := 0.12
## Tremblement (m) et rotation lente (rad/s) de l'objet tenu.
const TREMBLE := 0.014
const ROTATION_LENTE := 0.55
## Coincé derrière le décor : lâché après ce délai à plus de ECART_MAX m de sa place voulue.
const ECART_MAX := 3.5
const DUREE_COINCE := 0.6
## Contact rapide d'un objet lancé (m/s) : seuil de l'impact (contrat ImpactsLances) ; durée de suivi d'un lancer (s).
const VITESSE_IMPACT := 6.0
const DUREE_LANCER := 3.5
## Pas de lancer avant ce temps de tenue (s) : un appui bref fait tomber l'objet à ses pieds.
const TENUE_MIN := 0.12
## Molette : pas de distance (m).
const PAS_MOLETTE := 0.25
## Masse d'une arme posée qui n'en dit rien (kg).
const MASSE_ARME := 1.6
## Réseau : période des positions d'un objet tenu (s).
const PERIODE_RESEAU := 0.1
const EV_SAISIE := "tk_saisie"
const EV_TENU := "tk_tenu"
const EV_LANCER := "tk_lancer"
const EV_LACHER := "tk_lacher"

## Couleurs « esprit » : bleu pâle, cœur blanc (lueur, fil, étincelles).
const BLEU := Color("#8cc4f0")
const BLANC := Color("#f2faff")
const SH_COQUE := preload("res://shaders/magie_telekinesie.gdshader")

static var actif := not ("--sans-telekinesie" in OS.get_cmdline_user_args())

var magie: MainSort
var joueur: CharacterBody3D
## Par main : objet tenu et son état ({} = rien).
var tenue := {"gauche": {}, "droite": {}}
## Objet visé (surbrillance) par main.
var visee := {"gauche": null, "droite": null}
## Objets lancés suivis (impacts) : [{corps, t, prec, v_prec, touches, arme, sort, masse, rayon, traine, plante}].
var lances: Array = []
## Journal des événements (tests) : [[horloge, texte]] ; dernier refus.
var journal: Array = []
var dernier_refus := ""
var horloge := 0.0
var _refus_t := {}
var _survol_t := 0.0
var _coques := {}        # id du nœud -> {noeud, mis: [MeshInstance3D], propre: [MeshInstance3D], force}
var _sort_arme: DonneesSort
var _impacts_script: Variant = null
var _impacts_cherche := false
var _reseau_t := 0.0

func _init(m: MainSort = null) -> void:
	magie = m
	name = "Telekinesie"

func _ready() -> void:
	joueur = magie.joueur if magie != null else null
	_presets()
	_brancher_reseau()

func _noter(t: String) -> void:
	journal.append([horloge, t])
	if journal.size() > 200:
		journal.pop_front()

static func est_sort(s: DonneesSort) -> bool:
	return s != null and s.portee_mode == DonneesSort.Portee.TELEKINESIE

func tient(m: String) -> bool:
	var e: Dictionary = tenue[m]
	return not e.is_empty() and is_instance_valid(e.get("corps"))

func objet_tenu(m: String) -> RigidBody3D:
	return tenue[m].get("corps") if tient(m) else null

# ====================================================================== candidats

## Tous les objets que la télékinésie peut saisir (groupe `telekinesable` ; repli : objets vivants du décor).
func candidats() -> Array:
	var res: Array = []
	if not is_inside_tree():
		return res
	var vus := {}
	for n in get_tree().get_nodes_in_group(GROUPE):
		if n is Node3D and is_instance_valid(n) and (n as Node3D).is_visible_in_tree():
			res.append(n)
			vus[n.get_instance_id()] = true
	for o in ObjetsVivants.tous:
		if is_instance_valid(o) and not vus.has(o.get_instance_id()) and not (o as Node).has_meta("pris") and (o as Node).is_inside_tree():
			res.append(o)
	return res

## Centre (monde) d'un candidat.
static func centre(n: Node3D) -> Vector3:
	if n.has_method("centre_telekinesie"):
		return n.centre_telekinesie()
	if n is Cassable:
		return n.global_position + Vector3.UP * (n as Cassable).haut * 0.5   # origine au pied de l'objet
	if n is RigidBody3D:
		return n.global_position
	if not n.has_meta("tk_centre"):
		var b := _boite_locale(n)
		n.set_meta("tk_centre", b.get_center())
		n.set_meta("tk_rayon", maxf(b.size.length() * 0.5, 0.08))
	return n.global_transform * Vector3(n.get_meta("tk_centre"))

static func rayon(n: Node3D) -> float:
	if n.has_meta("tk_rayon"):
		return float(n.get_meta("tk_rayon"))
	var b := _boite_locale(n)
	var r := maxf(b.size.length() * 0.5, 0.08)
	n.set_meta("tk_rayon", r)
	return r

## Boîte englobante des maillages de `n` dans son repère.
static func _boite_locale(n: Node3D) -> AABB:
	var b := AABB()
	var premier := true
	var inv := n.global_transform.affine_inverse()
	var liste: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		liste.append(n)
	for v in liste:
		var mi := v as MeshInstance3D
		if mi.mesh == null:
			continue
		var bb := (inv * mi.global_transform) * mi.mesh.get_aabb()
		b = bb if premier else b.merge(bb)
		premier = false
	if premier:
		if n is ObjetVivant and (n as ObjetVivant).mm != null and (n as ObjetVivant).mm.mesh != null:
			return (n as ObjetVivant).visuel_local * (n as ObjetVivant).mm.mesh.get_aabb()
		for c in n.find_children("*", "CollisionShape3D", true, false):
			var cs := c as CollisionShape3D
			if cs.shape != null:
				var d := cs.shape.get_debug_mesh().get_aabb()
				var bb2 := (inv * cs.global_transform) * d
				b = bb2 if premier else b.merge(bb2)
				premier = false
	if premier:
		b = AABB(Vector3(-0.15, -0.15, -0.15), Vector3(0.3, 0.3, 0.3))
	return b

static func masse_de(n: Node) -> float:
	if n.has_method("masse_telekinesie"):
		return float(n.masse_telekinesie())
	if n.has_meta("tk_arme"):
		return MASSE_ARME
	if n is RigidBody3D:
		return (n as RigidBody3D).mass
	return 5.0

static func arme_de(n: Node) -> DonneesArme:
	if n == null or not is_instance_valid(n):
		return null
	if n.has_method("donnees_arme"):
		return n.donnees_arme()
	if n.has_meta("tk_arme"):
		return ArmesEnnemis.donnees_arme(String(n.get_meta("tk_arme")))
	return null

## Objet visé : le plus proche du réticule (aide généreuse : un objet un peu à côté du réticule est pris), à portée, sans mur entre l'œil
## et lui. null = rien. Un seul passage sur le groupe, rejets les moins chers d'abord (distance, angle), puis visibilité (≤ 6 candidats).
func viser(oeil: Vector3, avant: Vector3, portee: float) -> Node3D:
	if not is_inside_tree():
		return null
	var tries: Array = []
	var loin := (portee + 2.5) * (portee + 2.5)
	var vus := {}
	var sources: Array = get_tree().get_nodes_in_group(GROUPE)
	if not CasseObjets.actif:      # repli : objets vivants du décor hors groupe
		sources = sources + ObjetsVivants.tous
	for n in sources:
		var nd := n as Node3D
		if nd == null or not is_instance_valid(nd) or vus.has(nd.get_instance_id()):
			continue
		vus[nd.get_instance_id()] = true
		if (nd.global_position - oeil).length_squared() > loin or nd.has_meta("pris") or not nd.is_inside_tree() or tenu_par_moi(nd):
			continue
		var c := centre(nd)
		var d := c - oeil
		var dist := d.length()
		if dist > portee or dist < 0.3 or d.dot(avant) <= 0.0:
			continue
		var a := rad_to_deg(avant.angle_to(d))
		var marge := AIDE_VISEE + rad_to_deg(atan(rayon(nd) / dist))
		if a > marge or not nd.is_visible_in_tree():
			continue
		tries.append([a / marge + dist * 0.01, nd, c])
	tries.sort_custom(func(x, y): return x[0] < y[0])
	for t in tries.slice(0, 6):
		if _visible(oeil, t[2], t[1]):
			return t[1]
	return null

func tenu_par_moi(n: Node) -> bool:
	for m in tenue:
		var e: Dictionary = tenue[m]
		if not e.is_empty() and (e.get("corps") == n or e.get("source") == n):
			return true
	return false

func _visible(oeil: Vector3, c: Vector3, n: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(oeil, c, 1)
	var ex: Array[RID] = []
	if joueur is CollisionObject3D:
		ex.append((joueur as CollisionObject3D).get_rid())
	if n is CollisionObject3D:
		ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	var espace := n.get_world_3d().direct_space_state
	var r_n := rayon(n)
	# indulgent : le centre, puis un point au-dessus (objet posé derrière un rebord, sur un meuble, dans une pile)
	for dy in [0.0, minf(r_n, 0.45)]:
		var cible: Vector3 = c + Vector3.UP * dy
		q.to = cible
		var r := espace.intersect_ray(q)
		if r.is_empty():
			return true
		var col: Object = r.get("collider")
		if col == n or (col is Node and n.is_ancestor_of(col)):
			return true
		if (r["position"] as Vector3).distance_to(cible) < r_n + 0.2:
			return true
	return false

# ====================================================================== survol (surbrillance), appelé chaque image par MainSort

## Main `m` qui tient le sort sans rien porter : surbrillance de l'objet visé (10 fois par seconde au repos, chaque image en canalisant).
func survoler(m: String, oeil: Vector3, avant: Vector3, s: DonneesSort, chaque_image: bool) -> void:
	if tient(m):
		_poser_visee(m, null)
		return
	_survol_t -= get_process_delta_time()
	if not chaque_image and _survol_t > 0.0:
		return
	_survol_t = 0.1
	_poser_visee(m, viser(oeil, avant, s.portee))

func _poser_visee(m: String, n: Node3D) -> void:
	var ancien = visee[m]
	if ancien == n:
		return
	visee[m] = n
	if ancien != null and is_instance_valid(ancien) and not tenu_par_moi(ancien):
		_coque_force(ancien, 0.0)
	if n != null:
		_coque_force(n, 0.45)

func oublier_visee(m: String) -> void:
	_poser_visee(m, null)

# ====================================================================== maintien (état CANALISE de la main)

## Une image de maintien : cherche, saisit, tient. Renvoie "" ou une raison qui COUPE la main (« Mana épuisé. »).
func maintenir(m: String, s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3, dt: float) -> String:
	var e: Dictionary = tenue[m]
	if e.is_empty() or not is_instance_valid(e.get("corps")):
		if not e.is_empty():
			tenue[m] = {}
		survoler(m, oeil, avant, s, true)
		var n = visee[m]
		if n != null and is_instance_valid(n):
			_essayer_saisie(m, n, s, paume, oeil, avant)
		return ""
	e["oeil"] = oeil
	e["avant"] = avant
	e["paume"] = paume
	e["t"] = float(e["t"]) + dt
	var drain := (s.cout_par_seconde + s.drain_par_kg * float(e["masse"])) * dt * Progression.facteur_cout_sort(ECOLE)
	if not joueur.depenser_mana(drain):
		lacher(m)
		_noter("mana épuisé")
		return "Mana épuisé."
	_effets_tenue(m, e, dt)
	return ""

func _refuser(m: String, raison: String) -> void:
	if horloge - float(_refus_t.get(m + raison, -9.0)) < 1.2:
		return
	_refus_t[m + raison] = horloge
	dernier_refus = raison
	_noter("refus " + raison)
	if magie != null:
		magie.call("_refuser", m, raison)

func _essayer_saisie(m: String, n: Node3D, s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3) -> void:
	var masse := masse_de(n)
	if masse > s.masse_max:
		_refuser(m, "Trop lourd.")
		return
	var cout := (s.cout + s.cout_par_kg * masse) * Progression.facteur_cout_sort(ECOLE)
	if joueur.mana + 0.001 < cout:
		_refuser(m, "Pas assez de mana.")
		return
	var corps := _corps_de(n)
	if corps == null:
		return
	joueur.depenser_mana(cout)
	saisir(m, corps, n, masse, oeil, avant, paume)

## Corps rigide d'un candidat (arme posée : changée en ArmeLancee).
func _corps_de(n: Node3D) -> RigidBody3D:
	if n is RigidBody3D:
		return n
	if n.has_method("corps_telekinesie"):
		return n.corps_telekinesie()
	if n.has_meta("tk_arme"):
		return arme_depuis_visuel(n)
	return null

## Arme posée (ObjetMonde d'une arme, arme lâchée par un ennemi mort : meta « tk_arme ») changée en ArmeLancee au même endroit,
## couchée comme le visuel ; la source disparaît (l'arme quitte le butin du corps : pas de double).
static func arme_depuis_visuel(v: Node3D) -> ArmeLancee:
	if v == null or not is_instance_valid(v) or not v.is_inside_tree():
		return null
	var oid := String(v.get_meta("tk_arme", ""))
	var a := ArmeLancee.creer(oid)
	if a == null:
		return null
	var b := _boite_locale(v)
	var c := v.global_transform * b.get_center()
	var axe_l := Vector3.RIGHT
	var t := b.size
	if t.y >= t.x and t.y >= t.z:
		axe_l = Vector3.UP
	elif t.z >= t.x:
		axe_l = Vector3.BACK
	var dir := (v.global_basis * axe_l).normalized()
	var monde: Node = v.get_tree().current_scene if v.get_tree().current_scene != null else v.get_tree().root
	monde.add_child(a)
	a.global_position = c
	_orienter_pointe(a, dir, 1.0)
	var butin: Node = v.get_parent() if v.get_parent() != null and v.get_parent().has_meta("arme_sol") else null
	if butin != null:
		var contenu = butin.get("contenu")
		if contenu is Dictionary and (contenu as Dictionary).has(oid):
			var nb := int(contenu[oid]) - 1
			if nb <= 0:
				(contenu as Dictionary).erase(oid)
			else:
				contenu[oid] = nb
		butin.remove_meta("arme_sol")
	v.queue_free()
	return a

## Saisit `corps` (déjà payé) : arrachement, objet sans gravité, collisions gardées (sauf avec le joueur).
func saisir(m: String, corps: RigidBody3D, source: Node, masse: float, oeil: Vector3, avant: Vector3, paume: Node3D = null) -> void:
	_poser_visee(m, null)
	if source != null and source != corps and is_instance_valid(source):
		_coque_retirer(source)
	if corps is ObjetVivant:
		(corps as ObjetVivant).reveiller(true)
		(corps as ObjetVivant).tenu = true
	if corps.has_method("saisi_telekinesie"):
		corps.saisi_telekinesie(true)
	corps.freeze = false
	corps.sleeping = false
	corps.can_sleep = false
	corps.gravity_scale = 0.0
	if joueur is PhysicsBody3D:
		corps.add_collision_exception_with(joueur)
	_sortir_des_lances(corps)
	var dist := clampf(oeil.distance_to(corps.global_position), magie_sort().distance_min if magie_sort() != null else 1.3, 2.4)
	var e := {"corps": corps, "source": source, "masse": masse, "t": 0.0, "dist": lerpf(dist, magie_sort().distance_tenue if magie_sort() != null else 2.0, 0.6),
		"oeil": oeil, "avant": avant, "paume": paume, "coince": 0.0, "arme": arme_de(corps), "axe": Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)).normalized(),
		"phase": randf() * TAU, "fx": {}}
	if e["arme"] != null:
		e["dist"] = 1.65   # une arme, fine, se tient plus près pour qu'on la lise de toute sa longueur
	tenue[m] = e
	corps.linear_velocity = Vector3.UP * VITESSE_ARRACHE / sqrt(maxf(masse / 4.0, 0.25))
	corps.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * 1.6
	if corps.get("tenu") != null and not (corps is ObjetVivant):
		corps.set("tenu", true)
	_effets_saisie(m, e)
	_noter("saisie %s %.1f kg" % [corps.name, masse])
	_reseau_saisie(corps)

func magie_sort() -> DonneesSort:
	if magie == null:
		return null
	for m in ["gauche", "droite"]:
		var s := magie.eq.sort(m)
		if est_sort(s):
			return s
	return null

## Lâche l'objet tenu par `m` (il retombe, sans élan).
func lacher(m: String) -> void:
	var e: Dictionary = tenue[m]
	tenue[m] = {}
	if e.is_empty():
		return
	_effets_fin(e)
	var corps: RigidBody3D = e.get("corps")
	if corps == null or not is_instance_valid(corps):
		return
	_rendre_gravite(corps)
	corps.linear_velocity = corps.linear_velocity.limit_length(2.0)
	# un objet lâché reste suivi un instant (il peut tomber sur un ennemi) puis retrouve sa vie normale
	var l := _suivi(corps, e, false)
	l["coque_t"] = 0.4
	lances.append(l)
	_suivre_impacts(corps, false)
	_noter("lâché %s" % corps.name)
	_reseau_lacher(corps)

func _rendre_gravite(corps: RigidBody3D) -> void:
	corps.gravity_scale = 1.0
	corps.can_sleep = true
	if corps is ObjetVivant:
		(corps as ObjetVivant).tenu = false
	elif corps.get("tenu") != null:
		corps.set("tenu", false)
	if corps.has_method("saisi_telekinesie"):
		corps.saisi_telekinesie(false)

## Relâchement du bouton : lance l'objet tenu (vrai) ; un objet saisi depuis moins de TENUE_MIN est lâché.
func relacher(m: String, s: DonneesSort, oeil: Vector3, avant: Vector3) -> bool:
	var e: Dictionary = tenue[m]
	if e.is_empty() or not is_instance_valid(e.get("corps")):
		tenue[m] = {}
		return false
	if float(e["t"]) < TENUE_MIN:
		lacher(m)
		return false
	lancer(m, s, oeil, avant)
	return true

## Facteur de charge du lancer d'après la durée de tenue (0..1).
static func charge_de(s: DonneesSort, t: float) -> float:
	return clampf((t - 0.2) / maxf(s.temps_charge_lancer, 0.05), 0.0, 1.0)

## Vitesse de lancer (m/s) pour une charge et une masse.
static func vitesse_lancer(s: DonneesSort, charge: float, masse: float) -> float:
	return lerpf(s.vitesse_lancer_min, s.vitesse_lancer_max, charge) * clampf(pow(4.0 / maxf(masse, 0.1), 0.3), 0.5, 1.25)

func lancer(m: String, s: DonneesSort, oeil: Vector3, avant: Vector3) -> void:
	var e: Dictionary = tenue[m]
	tenue[m] = {}
	var corps: RigidBody3D = e["corps"]
	var masse := float(e["masse"])
	var charge := charge_de(s, float(e["t"]))
	# coût du lancer (modéré, jamais bloquant : sans assez de mana, on paie ce qui reste)
	var c_lancer := (s.cout_lancer + s.cout_lancer_par_kg * masse) * Progression.facteur_cout_sort(ECOLE)
	joueur.depenser_mana(minf(c_lancer, float(joueur.mana)))
	var v := vitesse_lancer(s, charge, masse)
	var depart := corps.global_position
	var but := _but_lancer(oeil, avant, depart, corps)
	var dir: Vector3 = but - depart
	var d := dir.length()
	var vit := avant * v
	if d > 0.05:
		# trajectoire balistique corrigée : la gravité est compensée pour arriver sur le point visé
		var t_vol := d / v
		vit = dir / t_vol + Vector3.UP * 0.5 * 9.8 * t_vol
		vit = vit.limit_length(v * 1.15)
	_effets_fin(e)
	_rendre_gravite(corps)
	corps.linear_velocity = vit
	var arme := arme_de(corps)
	if arme != null:
		corps.angular_velocity = Vector3.ZERO
		_orienter_pointe(corps, vit, 0.35)
	else:
		corps.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * clampf(6.0 / sqrt(maxf(masse, 0.5)), 1.0, 7.0)
	corps.set_meta("lance_par", joueur)
	corps.set_meta("lance_jusqu_a", horloge + DUREE_LANCER)
	var l := _suivi(corps, e, true)
	l["charge"] = charge
	lances.append(l)
	_suivre_impacts(corps, arme != null)
	_effets_lancer(corps, vit, charge)
	SonsMagie.telekinesie_lancer(depart, 0.7 + 0.5 * charge)
	_noter("lancer %s v=%.1f charge=%.2f" % [corps.name, vit.length(), charge])
	_reseau_lancer(corps, vit)

## Point visé par le lancer : centre de l'ennemi le plus proche du réticule (aide), sinon ce que touche le rayon du réticule.
func _but_lancer(oeil: Vector3, avant: Vector3, depart: Vector3, lance: RigidBody3D = null) -> Vector3:
	var but := oeil + avant * PORTEE_LANCER
	var q := PhysicsRayQueryParameters3D.create(oeil, but)
	var ex: Array[RID] = []
	if lance != null:
		ex.append(lance.get_rid())   # l'objet lancé lui-même (déjà sorti de la tenue) ne doit pas arrêter le rayon
	if joueur is CollisionObject3D:
		ex.append((joueur as CollisionObject3D).get_rid())
	for m in tenue:
		if tient(m):
			ex.append((tenue[m]["corps"] as RigidBody3D).get_rid())
	q.exclude = ex
	var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		but = r["position"]
	var meilleur := AIDE_LANCER
	for c in PvpCoop.cibles(oeil, PORTEE_LANCER):
		var ce := Elements._centre(c)
		var a := rad_to_deg(avant.angle_to(ce - oeil))
		if a < meilleur and oeil.distance_to(ce) <= oeil.distance_to(but) + 1.0 and _sans_mur(depart, ce, c, lance):
			meilleur = a
			but = ce
	return but

func _sans_mur(a: Vector3, b: Vector3, cible: Node, lance: RigidBody3D = null) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var ex: Array[RID] = []
	if lance != null:
		ex.append(lance.get_rid())
	if joueur is CollisionObject3D:
		ex.append((joueur as CollisionObject3D).get_rid())
	if cible is CollisionObject3D:
		ex.append((cible as CollisionObject3D).get_rid())
	for m in tenue:
		if tient(m):
			ex.append((tenue[m]["corps"] as RigidBody3D).get_rid())
	q.exclude = ex
	var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty() or (r["position"] as Vector3).distance_to(b) < 0.7

## Fiche de suivi d'un objet lancé (`vol` : lancé ; sinon simplement lâché).
func _suivi(corps: RigidBody3D, e: Dictionary, vol: bool) -> Dictionary:
	if not corps.has_meta("tk_contact"):
		corps.set_meta("tk_contact", true)
		corps.contact_monitor = true
		corps.max_contacts_reported = maxi(corps.max_contacts_reported, 4)
		corps.body_entered.connect(_contact.bind(corps))
	return {"corps": corps, "t": 0.0, "prec": corps.global_position, "v_prec": corps.linear_velocity, "touches": {}, "vol": vol,
		"arme": arme_de(corps), "masse": float(e.get("masse", corps.mass)), "rayon": _rayon_corps(corps), "traine": e.get("fx", {}).get("traine"),
		"plante": null, "repos": 0.0, "charge": 0.0}

func _sortir_des_lances(corps: RigidBody3D) -> void:
	for i in range(lances.size() - 1, -1, -1):
		if lances[i]["corps"] == corps:
			_fin_suivi(lances[i], false)
			lances.remove_at(i)

static func _rayon_corps(corps: RigidBody3D) -> float:
	var r := 0.1
	for c in corps.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			var sh := (c as CollisionShape3D).shape
			if sh is BoxShape3D:
				var z := (sh as BoxShape3D).size
				r = maxf(r, minf(maxf(z.x, z.z), z.y) * 0.5 + 0.03)
			elif sh is SphereShape3D:
				r = maxf(r, (sh as SphereShape3D).radius)
			elif sh is CylinderShape3D:
				r = maxf(r, (sh as CylinderShape3D).radius)
			elif sh is CapsuleShape3D:
				r = maxf(r, (sh as CapsuleShape3D).radius)
	return r

# ====================================================================== physique

func _physics_process(dt: float) -> void:
	horloge += dt
	for m in tenue:
		var e: Dictionary = tenue[m]
		if e.is_empty():
			continue
		if not is_instance_valid(e.get("corps")):
			_effets_fin(e)
			tenue[m] = {}
			continue
		_tenir(m, e, dt)
	_suivre_lances(dt)
	_reseau_tenu(dt)

## Ressort amorti vers le point de tenue (devant la main, décalé de son côté), tremblement et rotation lente.
func _tenir(m: String, e: Dictionary, dt: float) -> void:
	var corps: RigidBody3D = e["corps"]
	var oeil: Vector3 = e["oeil"]
	var avant: Vector3 = e["avant"]
	var droite := avant.cross(Vector3.UP).normalized() if absf(avant.y) < 0.98 else Vector3.RIGHT
	var haut := droite.cross(avant).normalized()
	var cote := -1.0 if m == "gauche" else 1.0
	var t := float(e["t"])
	var ph := float(e["phase"])
	var cible := oeil + avant * float(e["dist"]) + droite * COTE * cote - haut * (BAS if e["arme"] == null else -0.02)
	cible += Vector3(sin(t * 7.3 + ph), sin(t * 5.1 + ph * 2.0), sin(t * 6.7 + ph * 3.0)) * TREMBLE
	cible += Vector3.UP * 0.04 * sin(t * 1.7 + ph)   # flottement
	corps.sleeping = false
	if t < ARRACHE:
		return   # l'à-coup d'arrachement (vitesse posée à la saisie) joue seul
	var ecart := cible - corps.global_position
	var voulue := (ecart * RAIDEUR).limit_length(VITESSE_TENUE)
	corps.linear_velocity = corps.linear_velocity.lerp(voulue, 1.0 - exp(-dt * AMORTI))
	# objet ATTIRÉ vers la main à vive allure (jusqu'à VITESSE_TENUE) : s'il traverse un ennemi (saisi dans son dos, par exemple), il le
	# percute, lui fait des dégâts selon son énergie et casse ; suivi seulement près d'un ennemi (pas de casse contre le décor en tenue)
	if DegatsObjets.actif and corps.linear_velocity.length() >= VITESSE_IMPACT and corps.get_node_or_null("SuiviLancer") == null \
			and not Elements.cibles_dans(corps.global_position, 2.5).is_empty():
		ImpactsLances.suivre(corps, joueur, 0.8)
	if e["arme"] != null:
		# arme : couchée EN TRAVERS du regard, pointe vers le centre et un peu en avant (lisible de toute sa longueur, comme
		# l'épée qui lévite de la référence) ; elle pivote vers la cible au lancer
		_orienter_pointe(corps, droite * (-cote) * 0.8 + avant * 0.6 + Vector3.UP * 0.04 * sin(t * 1.3 + ph), 1.0 - exp(-dt * 4.0))
	else:
		var axe: Vector3 = e["axe"]
		corps.angular_velocity = corps.angular_velocity.lerp(axe * ROTATION_LENTE, 1.0 - exp(-dt * 2.5))
	e["coince"] = float(e["coince"]) + dt if ecart.length() > ECART_MAX else 0.0
	if float(e["coince"]) > DUREE_COINCE:
		_noter("coincé")
		lacher(m)

## Tourne une arme (repère : +Y le long de la lame, origine au centre) pour que sa pointe suive `dir` ; k = part de rattrapage
## (1 = d'un coup). Rotation posée directement (pas de couple) : la lame ne vrille pas.
static func _orienter_pointe(corps: RigidBody3D, dir: Vector3, k: float) -> void:
	if dir.length() < 0.01:
		return
	var y := _axe_lame(corps)
	var d := dir.normalized()
	var axe := y.cross(d)
	var ang := y.angle_to(d)
	corps.angular_velocity = corps.angular_velocity * 0.5
	if axe.length() < 1e-5 or ang < 1e-4:
		return
	var b := Basis(Quaternion(axe.normalized(), ang * clampf(k, 0.0, 1.0))) * corps.global_basis
	var c := corps.global_position
	corps.global_basis = b.orthonormalized()
	corps.global_position = c

## Axe de la lame (prise -> pointe) en repère monde : celui d'ImpactsLances (nœuds « prise » / « pointe » d'ArmeLancee).
static func _axe_lame(corps: RigidBody3D) -> Vector3:
	var d := arme_de(corps)
	if d != null:
		var ab := ImpactsLances.axe_monde(corps, d)
		var a: Vector3 = Vector3(ab[1]) - Vector3(ab[0])
		if a.length() > 0.01:
			return a.normalized()
	return corps.global_basis.y.normalized()

# ====================================================================== objets lancés : impacts

func _suivre_lances(dt: float) -> void:
	var i := lances.size() - 1
	while i >= 0:
		var l: Dictionary = lances[i]
		var corps = l["corps"]
		if corps == null or not is_instance_valid(corps):
			_fin_suivi(l, false)
			lances.remove_at(i)
			i -= 1
			continue
		var c := corps as RigidBody3D
		l["t"] = float(l["t"]) + dt
		var p := c.global_position
		var v := c.linear_velocity
		if c.has_meta("plantee"):
			# plantée par ImpactsLances (corps, mur) : le vol est fini
			_fin_suivi(l, false)
			lances.remove_at(i)
			i -= 1
			continue
		if l["plante"] != null:
			_suivre_plante(l)
		elif _impacts() != null:
			pass   # ImpactsLances.suivre (SuiviLancer) détecte les contacts, stabilise la lame et appelle objet_touche
		else:
			if bool(l["vol"]) and l["arme"] != null and v.length() > 3.0:
				_orienter_pointe(c, v, clampf(float(l["t"]) / 0.1, 0.35, 1.0))   # une arme lancée vole pointe en avant (pivote en 0,1 s)
			var vp: Vector3 = l["v_prec"]
			if vp.length() > VITESSE_IMPACT or v.length() > VITESSE_IMPACT:
				_balayer(l, l["prec"], p, vp if vp.length() > v.length() else v)
		l["prec"] = c.global_position
		l["v_prec"] = c.linear_velocity
		l["repos"] = float(l["repos"]) + dt if c.linear_velocity.length() < 0.6 else 0.0
		var fini := float(l["t"]) > DUREE_LANCER or (float(l["repos"]) > 0.4 and l["plante"] == null)
		if l["plante"] != null and float(l["t"]) < 12.0:
			fini = false
		if fini:
			_fin_suivi(l, true)
			lances.remove_at(i)
		i -= 1

## Ennemis traversés par le segment a -> b (capsule verticale de chaque cible) : un impact par cible.
func _balayer(l: Dictionary, a: Vector3, b: Vector3, v: Vector3) -> void:
	var r := float(l["rayon"])
	for cible in PvpCoop.cibles(b, 2.5 + a.distance_to(b)):
		if (l["touches"] as Dictionary).has(cible.get_instance_id()):
			continue
		var n3 := cible as Node3D
		var ech: float = float(cible.get("echelle")) if cible.get("echelle") != null else 1.0
		var pied := n3.global_position + Vector3.UP * 0.25 * ech
		var tete := n3.global_position + Vector3.UP * 1.75 * ech
		var pts := Geometry3D.get_closest_points_between_segments(a, b, pied, tete)
		var rc := 0.32 * ech
		if (pts[0] as Vector3).distance_to(pts[1]) <= r + rc:
			(l["touches"] as Dictionary)[cible.get_instance_id()] = true
			var point: Vector3 = (pts[1] as Vector3) + ((pts[0] as Vector3) - (pts[1] as Vector3)).limit_length(rc)
			var normale := ((pts[0] as Vector3) - (pts[1] as Vector3)).normalized() if (pts[0] as Vector3).distance_to(pts[1]) > 0.01 else -v.normalized()
			toucher(l, cible, point, normale, v)
			if l["plante"] != null:
				return

## Contact physique d'un objet suivi avec le décor (ou un corps) : impact rapide -> contrat ImpactsLances / casse.
func _contact(autre: Node, corps: RigidBody3D) -> void:
	if _impacts() != null:
		return   # SuiviLancer s'en charge (pas de double appel)
	for l: Dictionary in lances:
		if l["corps"] != corps or l["plante"] != null:
			continue
		var v: Vector3 = l["v_prec"]
		if v.length() < VITESSE_IMPACT or (l["touches"] as Dictionary).has(autre.get_instance_id()):
			return
		if PvpCoop.cibles(corps.global_position, 0.1).has(autre):
			return   # les ennemis sont touchés par _balayer (une fois chacun)
		(l["touches"] as Dictionary)[autre.get_instance_id()] = true
		toucher(l, autre, corps.global_position, -v.normalized(), v)
		return

## UN impact : la branche « impacts » (ImpactsLances.objet_touche) s'il existe, sinon le repli minimal.
func toucher(l: Dictionary, cible: Node, point: Vector3, normale: Vector3, v: Vector3) -> void:
	var corps: RigidBody3D = l["corps"]
	_noter("impact %s -> %s v=%.1f" % [corps.name, cible.name, v.length()])
	if PvpCoop.pvp_cible(cible) and _impacts() == null:
		# PvP (repli sans ImpactsLances ; sinon ImpactsLances._appliquer route vers PvpCoop) : objet / arme télékinésés qui percutent un autre joueur (l'hôte valide, la victime encaisse ; l'objet casse comme sur un mur)
		if corps.has_method("recevoir_choc"):
			corps.recevoir_choc(v, float(l["masse"]), point)
		PvpCoop.coup_objet(cible, degats_repli(float(l["masse"]), v.length(), l["arme"]), point, v)
		corps.linear_velocity = v.bounce(normale if normale.length() > 0.1 else -v.normalized()) * 0.25 + Vector3.UP * 1.0
		return
	var imp: Variant = _impacts()
	if imp != null:
		imp.objet_touche(corps, cible, point, normale, v, joueur)
		return
	_repli_impact(l, cible, point, normale, v)

## Lâché ou lancé : la détection des contacts passe à ImpactsLances.suivre (SuiviLancer) ; une arme lancée y est stabilisée nez en avant.
func _suivre_impacts(corps: RigidBody3D, arme: bool) -> void:
	var imp: Variant = _impacts()
	if imp == null:
		return
	var sv: Node = imp.suivre(corps, joueur, DUREE_LANCER)
	if sv != null and arme:
		sv.set("stabiliser", true)
	_noter("suivi ImpactsLances %s" % corps.name)

## Classe ImpactsLances (branche impacts) si elle est dans le projet, sinon null.
func _impacts() -> Variant:
	if not _impacts_cherche:
		_impacts_cherche = true
		for c: Dictionary in ProjectSettings.get_global_class_list():
			if String(c.get("class", "")) == "ImpactsLances":
				_impacts_script = load(String(c["path"]))
				break
	return _impacts_script

## Dégâts d'un objet lancé sans la branche impacts : masse × vitesse (contondant) ou dégâts lourds de l'arme (tranchant).
static func degats_repli(masse: float, vitesse: float, arme: DonneesArme) -> float:
	# repères : chaise de 7 kg à 20 m/s ≈ 22, tonneau de 28 kg à 10 m/s ≈ 35, chope à 30 m/s ≈ 2 ; épée (lourd 28) à 30 m/s ≈ 35
	# (~1,5 à 2 dégâts par point de mana, comme les sorts : docs/MAGIE.md, « Équilibrage »)
	if arme != null:
		return arme.degats_lourd * clampf(vitesse / 24.0, 0.5, 1.4)
	return clampf(0.22 * pow(maxf(masse, 0.05), 0.83) * vitesse, 2.0, 70.0)

func _repli_impact(l: Dictionary, cible: Node, point: Vector3, normale: Vector3, v: Vector3) -> void:
	var corps: RigidBody3D = l["corps"]
	var masse := float(l["masse"])
	var arme: DonneesArme = l["arme"]
	# l'objet lancé lui-même encaisse le choc (contrat cassables)
	if corps.has_method("recevoir_choc"):
		corps.recevoir_choc(v, masse, point)
	var est_cible := PvpCoop.cibles(point, 3.0).has(cible)
	if not est_cible:
		if cible.has_method("recevoir_choc"):
			cible.recevoir_choc(v, masse, point)
		elif cible.has_method("frapper") and (cible is Cassable or cible is ObjetVivant):
			cible.frapper(masse * v.length() > 30.0, point - v.normalized())
		return
	var s := _sort_impact(arme != null)
	var dg := degats_repli(masse, v.length(), arme)
	var st := clampf(masse * v.length() * 0.15, 8.0, 40.0) if arme == null else 20.0
	var res := ""
	if magie != null:
		res = magie.lanceur.frapper(cible, dg, s, point, v.normalized(), false, st)
	elif cible.has_method("recevoir_coup"):
		res = String(DegatsCombat.appliquer(cible, dg, point - v, st >= 24.0, {"type": s.type_degats, "attaque": "sort", "sort": s.id, "point": point, "direction": v.normalized(), "stagger": st}))
	_noter("repli dégâts %.1f (%s)" % [dg, res])
	if arme != null and res != "tue" and is_instance_valid(cible) and cible is Node3D:
		_planter(l, cible as Node3D, point, v)
	elif arme != null:
		corps.linear_velocity = v * 0.6   # elle tue : elle traverse et continue
	else:
		# l'objet rebondit sur le corps, sonné
		corps.linear_velocity = v.bounce(normale if normale.length() > 0.1 else -v.normalized()) * 0.25 + Vector3.UP * 1.0

## Sort fictif des dégâts de repli (type contondant ; arme : tranchant).
func _sort_impact(arme: bool) -> DonneesSort:
	var s := magie_sort()
	if s == null:
		s = load("res://data/sorts/telekinesie.tres") as DonneesSort
	if not arme:
		return s
	if _sort_arme == null:
		_sort_arme = s.duplicate() as DonneesSort
		_sort_arme.type_degats = "tranchant"
	return _sort_arme

## Repli : l'arme se plante dans la cible (suit son nœud) jusqu'à sa mort ou 12 s.
func _planter(l: Dictionary, cible: Node3D, point: Vector3, v: Vector3) -> void:
	var corps: RigidBody3D = l["corps"]
	corps.linear_velocity = Vector3.ZERO
	corps.angular_velocity = Vector3.ZERO
	corps.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	corps.freeze = true
	var h := corps.global_basis.y.normalized()
	corps.global_position = point - h * 0.12 + v.normalized() * 0.05
	l["plante"] = cible
	l["local"] = cible.global_transform.affine_inverse() * corps.global_transform
	_effets_fin_vol(l)

func _suivre_plante(l: Dictionary) -> void:
	var cible = l["plante"]
	var corps: RigidBody3D = l["corps"]
	var vivante: bool = cible != null and is_instance_valid(cible) and not (cible.has_method("vivant") and not cible.vivant()) and cible.get("est_mort") != true
	if vivante:
		corps.global_transform = (cible as Node3D).global_transform * (l["local"] as Transform3D)
		return
	l["plante"] = null
	corps.freeze = false
	corps.linear_velocity = Vector3.DOWN * 0.5
	l["t"] = DUREE_LANCER - 1.0

func _fin_suivi(l: Dictionary, normal: bool) -> void:
	_effets_fin_vol(l)
	var corps = l["corps"]
	if corps == null or not is_instance_valid(corps):
		return
	if joueur is PhysicsBody3D:
		(corps as RigidBody3D).remove_collision_exception_with(joueur)
	(corps as RigidBody3D).can_sleep = true
	if normal and corps.has_method("au_repos_telekinesie"):
		corps.au_repos_telekinesie()   # AVANT le retrait des métas : ArmeLancee y relit « lance_par » (erreur get_meta sinon)
	if (corps as Node).has_meta("lance_par"):
		(corps as Node).remove_meta("lance_par")
		(corps as Node).remove_meta("lance_jusqu_a")

# ====================================================================== effets (DA PS1 : couche fine des sorts, pas de tramage)

## Réglages de particules propres à la télékinésie (ajoutés au catalogue PresetsMagie au premier usage).
static func _presets() -> void:
	if PresetsMagie.R.has("tk_objet"):
		return
	var esprit := ["#f2faff", "#c8e6fa", "#8cc4f0", "#5a8ec8"]
	var R: Dictionary = PresetsMagie.R
	# étincelles fines qui s'élèvent de l'objet tenu (forme : boîte de l'objet, ajustée à la saisie)
	R["tk_objet"] = {"add": true, "n": 22, "vie": 0.9, "forme": "boite", "ext": Vector3(0.2, 0.2, 0.2), "dir": Vector3.UP, "ecart": 70.0, "vit": Vector2(0.02, 0.15), "grav": Vector3(0, 0.12, 0), "taille": Vector2(0.005, 0.01), "rampe": esprit, "eclat": 1.3, "cap": 3.0, "turb": Vector2(0.1, 0.3), "turb_echelle": 3.0}
	# arrachement : poussière au sol (anneau qui s'écarte) et gerbe d'étincelles
	R["tk_poussiere"] = {"n": 18, "vie": 0.8, "expl": 0.9, "forme": "disque", "r": 0.22, "dir": Vector3.UP, "ecart": 80.0, "vit": Vector2(0.2, 0.8), "radiale_v": Vector2(0.5, 1.2), "amort": Vector2(1.5, 3.0), "grav": Vector3(0, 0.1, 0), "taille": Vector2(0.035, 0.08), "courbe": "bosse", "rampe": ["#6e6a6470", "#5a565250", "#46423f30"], "eclat": 0.9, "cap": 9.0}
	R["tk_arrache"] = {"add": true, "n": 12, "vie": 0.4, "expl": 1.0, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.6, 2.2), "amort": Vector2(2.0, 4.0), "taille": Vector2(0.006, 0.014), "rampe": esprit, "eclat": 1.4, "cap": 3.0}
	# lancer : éclat au départ et traînée (repère du monde, émetteur qui suit l'objet)
	R["tk_lancer"] = {"add": true, "n": 14, "vie": 0.35, "expl": 1.0, "forme": "sphere", "r": 0.1, "ecart": 180.0, "vit": Vector2(1.0, 3.0), "amort": Vector2(3.0, 5.0), "taille": Vector2(0.007, 0.016), "rampe": esprit, "eclat": 2.0, "cap": 3.0}
	R["tk_traine"] = {"add": true, "n": 24, "vie": 0.4, "forme": "sphere", "r": 0.05, "ecart": 180.0, "vit": Vector2(0.0, 0.25), "taille": Vector2(0.006, 0.014), "courbe": "descend", "rampe": ["#ffffff", "#f2faff", "#c8e6fa", "#8cc4f0", "#5a8ec8"], "eclat": 2.0, "cap": 3.0}

func _g() -> GestionMagie:
	return GestionMagie.obtenir() if not EffetsMagie.muet else null

func _effets_saisie(m: String, e: Dictionary) -> void:
	var corps: RigidBody3D = e["corps"]
	_coque_force(corps, 1.0)
	SonsMagie.telekinesie_saisie(corps.global_position, float(e["masse"]))
	SonsMagie.telekinesie_tenue(corps, 1.0)
	var g := _g()
	if g == null:
		return
	var b := _boite_locale(corps)
	var ext := (b.size * 0.5 + Vector3.ONE * 0.04).clamp(Vector3.ONE * 0.05, Vector3.ONE * 1.2)
	var xf := Transform3D(Basis(), b.get_center())
	var fx: Dictionary = e["fx"]
	var pm: ParticleProcessMaterial = g._pm("tk_objet", PresetsMagie.R["tk_objet"], {"ext": Vector3(snappedf(ext.x, 0.05), snappedf(ext.y, 0.05), snappedf(ext.z, 0.05))})
	fx["aura"] = g.emettre("tk_objet", corps, xf, true, clampf(ext.length() / 0.35, 0.6, 2.0), -1.0, pm)
	# poussière au pied de l'objet (s'il reposait au sol) et gerbe d'étincelles
	var pied := corps.global_position - Vector3.UP * (b.size.y * 0.5)
	var q := PhysicsRayQueryParameters3D.create(corps.global_position, pied - Vector3.UP * 0.4, 1)
	q.exclude = [corps.get_rid()]
	var r := corps.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		g.emettre("tk_poussiere", null, Transform3D(Basis(), r["position"] + Vector3.UP * 0.03))
	g.emettre("tk_arrache", null, Transform3D(Basis(), corps.global_position), false, 0.5)
	g.lumiere("tk_arrache%d" % corps.get_instance_id(), corps.global_position, BLANC, 0.5, 2.0, 3.0, 0.15)

func _effets_tenue(m: String, e: Dictionary, _dt: float) -> void:
	var corps: RigidBody3D = e["corps"]
	var t := float(e["t"])
	var s := magie_sort()
	var charge := charge_de(s, t) if s != null else 0.0
	# lueur qui pulse doucement, plus vive quand le lancer est chargé
	_coque_force(corps, 0.75 + 0.15 * sin(t * 6.0) + 0.35 * charge + (0.35 if e["arme"] != null else 0.0))
	SonsMagie.telekinesie_tenue(corps, 0.6 + 0.4 * charge)
	var g := _g()
	if g == null:
		return
	g.lumiere("tk_tenu%d" % corps.get_instance_id(), corps.global_position, BLEU, 0.15 + 0.3 * charge, 2.0, 2.0, 0.12)

func _effets_lancer(corps: RigidBody3D, vit: Vector3, charge: float) -> void:
	_coque_force(corps, 1.2)
	var g := _g()
	if g == null:
		return
	g.emettre("tk_lancer", null, Transform3D(Basis(), corps.global_position), false, 0.8 + 0.6 * charge)
	g.lumiere("tk_lancer%d" % corps.get_instance_id(), corps.global_position, BLANC, 0.6, 3.0, 3.0, 0.12)
	for l: Dictionary in lances:
		if l["corps"] == corps:
			l["traine"] = g.emettre("tk_traine", corps, Transform3D.IDENTITY, true, clampf(vit.length() / 18.0, 0.5, 1.4))
			l["coque_t"] = 0.6

func _effets_fin(e: Dictionary) -> void:
	var fx: Dictionary = e.get("fx", {})
	var g := _g()
	if g != null:
		if fx.get("aura") != null:
			g.arreter(fx["aura"])
	fx.clear()
	var corps = e.get("corps")
	if corps != null and is_instance_valid(corps):
		SonsMagie.telekinesie_tenue(corps, 0.0)
		# la lueur s'éteint en fondu pendant le vol (voir _effets_fin_vol)
		_coque_force(corps, 0.9)

func _effets_fin_vol(l: Dictionary) -> void:
	var g := _g()
	if g != null and l.get("traine") != null:
		g.arreter(l["traine"])
	l["traine"] = null
	var corps = l.get("corps")
	if corps != null and is_instance_valid(corps):
		_coque_retirer(corps)

func _process(dt: float) -> void:
	# fondu de la lueur des objets lancés
	for l: Dictionary in lances:
		var corps = l.get("corps")
		if corps == null or not is_instance_valid(corps) or not l.has("coque_t"):
			continue
		l["coque_t"] = float(l["coque_t"]) - dt
		_coque_force(corps, maxf(float(l["coque_t"]) / 0.6, 0.0) * 1.1)

# ---------------------------------------------------------------------- lueur de l'objet (coque additive, voir magie_telekinesie.gdshader)

func _coque_force(n: Node, force: float) -> void:
	if n == null or not is_instance_valid(n) or EffetsMagie.muet:
		return
	var id := n.get_instance_id()
	if force <= 0.001:
		_coque_retirer(n)
		return
	var c: Dictionary = _coques.get(id, {})
	if c.is_empty():
		c = _coque_creer(n)
		_coques[id] = c
	if absf(float(c["force"]) - force) < 0.01:
		return
	c["force"] = force
	(c["mat"] as ShaderMaterial).set_shader_parameter("force", force)

func _coque_creer(n: Node) -> Dictionary:
	var m := ShaderMaterial.new()
	m.shader = SH_COQUE
	m.set_shader_parameter("couleur", BLEU)
	m.set_shader_parameter("coeur", BLANC)
	var c := {"noeud": n, "mis": [], "propres": [], "mat": m, "force": -1.0}
	var liste: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		liste.append(n)
	var grille := 135.0
	for v in liste:
		var mi := v as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.material_overlay != null or mi.has_meta("tk_coque"):
			continue
		mi.material_overlay = m
		(c["mis"] as Array).append(mi)
		if (c["mis"] as Array).size() >= 16:
			break
	if (c["mis"] as Array).is_empty() and n is ObjetVivant and (n as ObjetVivant).mm != null and (n as ObjetVivant).mm.mesh != null:
		# objet vivant : dessiné par un MultiMesh partagé ; la coque est une copie du maillage posée sur le corps
		var o := n as ObjetVivant
		var mi := MeshInstance3D.new()
		mi.name = "CoqueTk"
		mi.set_meta("tk_coque", true)
		mi.mesh = o.mm.mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = o.visuel_local
		o.add_child(mi)
		(c["propres"] as Array).append(mi)
	m.set_shader_parameter("grille", grille)
	return c

func _coque_retirer(n: Node) -> void:
	if n == null:
		return
	var id := n.get_instance_id()
	var c: Dictionary = _coques.get(id, {})
	_coques.erase(id)
	if c.is_empty():
		return
	for mi in c["mis"]:
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == c["mat"]:
			(mi as MeshInstance3D).material_overlay = null
	for mi in c["propres"]:
		if is_instance_valid(mi):
			(mi as Node).queue_free()

## Tout arrêter (sort déséquipé, mort, changement de scène).
func tout_lacher() -> void:
	for m in tenue:
		lacher(m)
		oublier_visee(m)

func _exit_tree() -> void:
	for id in _coques.keys():
		var c: Dictionary = _coques[id]
		if is_instance_valid(c.get("noeud")):
			_coque_retirer(c["noeud"])

# ====================================================================== réseau (coop, docs/RESEAU_BILAN.md)
## L'objet est repéré sur les autres machines par son identifiant (ObjetVivant.ident, ou chemin dans la scène : le monde est bâti
## de la même façon partout). Saisie / positions de tenue (10 /s) / lancer / lâcher sont annoncés ; chaque machine fait voler sa
## copie ; seuls les impacts de la copie du LANCEUR comptent (dégâts : LanceurSorts.frapper, qui délègue à l'hôte pour un invité).

func _reseau() -> Node:
	return ReseauProjectiles.reseau() if ReseauProjectiles.en_ligne() else null

func _brancher_reseau() -> void:
	var r := ReseauProjectiles.reseau()
	if r == null or not r.has_method("abonner"):
		return
	r.abonner(EV_SAISIE, _sur_saisie)
	r.abonner(EV_TENU, _sur_tenu)
	r.abonner(EV_LANCER, _sur_lancer)
	r.abonner(EV_LACHER, _sur_lacher)

static func ident_de(n: Node) -> String:
	if n is ObjetVivant and (n as ObjetVivant).ident != "":
		return "ov:" + (n as ObjetVivant).ident
	if n.has_meta("ident_tk"):
		return String(n.get_meta("ident_tk"))
	var sc := n.get_tree().current_scene if n.is_inside_tree() else null
	return ("p:" + String(sc.get_path_to(n))) if sc != null else ""

func _trouver(id: String) -> RigidBody3D:
	if id.begins_with("ov:"):
		for o in ObjetsVivants.tous:
			if is_instance_valid(o) and "ov:" + (o as ObjetVivant).ident == id:
				return o
		return null
	if id.begins_with("p:") and get_tree().current_scene != null:
		return get_tree().current_scene.get_node_or_null(NodePath(id.substr(2))) as RigidBody3D
	return null

func _envoyer(type: String, corps: Node, d: Dictionary) -> void:
	var r := _reseau()
	if r == null or joueur.get("est_local") == false:
		return
	var id := ident_de(corps)
	if id == "":
		return
	r.envoyer_evenement(type, id, d)

func _reseau_saisie(corps: RigidBody3D) -> void:
	_envoyer(EV_SAISIE, corps, {"p": corps.global_position})

func _reseau_lancer(corps: RigidBody3D, v: Vector3) -> void:
	_envoyer(EV_LANCER, corps, {"p": corps.global_position, "q": corps.global_basis.get_rotation_quaternion(), "v": v, "w": corps.angular_velocity})

func _reseau_lacher(corps: RigidBody3D) -> void:
	_envoyer(EV_LACHER, corps, {"p": corps.global_position, "v": corps.linear_velocity})

func _reseau_tenu(dt: float) -> void:
	if _reseau() == null:
		return
	_reseau_t -= dt
	if _reseau_t > 0.0:
		return
	_reseau_t = PERIODE_RESEAU
	for m in tenue:
		if tient(m):
			var c: RigidBody3D = tenue[m]["corps"]
			_envoyer(EV_TENU, c, {"p": c.global_position, "q": c.global_basis.get_rotation_quaternion()})

## Hôte : relaie aux autres invités (l'événement ne revient jamais à l'émetteur).
func _relayer(expediteur: int, type: String, id: Variant, d: Variant) -> void:
	var r := _reseau()
	if r != null and r.has_method("est_hote") and r.est_hote():
		for pair in r.joueurs():
			if pair != expediteur and pair != r.mon_id():
				r.envoyer_evenement(type, id, d, pair)

func _sur_saisie(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_SAISIE, id, d)
	var c := _trouver(String(id))
	if c == null:
		return
	if c is ObjetVivant:
		(c as ObjetVivant).reveiller(true)
	c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	c.freeze = true
	_coque_force(c, 1.0)

func _sur_tenu(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_TENU, id, d)
	var c := _trouver(String(id))
	if c == null or not (d is Dictionary):
		return
	c.global_transform = Transform3D(Basis(d.get("q", Quaternion())), d.get("p", c.global_position))
	if c is ObjetVivant:
		(c as ObjetVivant).actualiser_visuel()

func _sur_lancer(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_LANCER, id, d)
	var c := _trouver(String(id))
	if c == null or not (d is Dictionary):
		return
	_coque_force(c, 0.0)
	c.freeze = false
	c.global_transform = Transform3D(Basis(d.get("q", Quaternion())), d.get("p", c.global_position))
	c.linear_velocity = d.get("v", Vector3.ZERO)
	c.angular_velocity = d.get("w", Vector3.ZERO)

func _sur_lacher(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_LACHER, id, d)
	var c := _trouver(String(id))
	if c == null or not (d is Dictionary):
		return
	_coque_force(c, 0.0)
	c.freeze = false
	c.global_position = d.get("p", c.global_position)
	c.linear_velocity = d.get("v", Vector3.ZERO)
