class_name SortsEsprit
extends Node
## SORTS DE L'ESPRIT autour de la télékinésie (école « esprit », docs/MAGIE.md, « Sorts de l'esprit ») :
##   - RÉPULSION (Portee.REPULSION, type CHARGE) : maintenir charge, relâcher envoie une onde de choc en cône devant la main ;
##     ennemis et objets projetés selon la charge et leur masse / puissance ; un ennemi projeté contre un mur prend un choc, un
##     objet fragile projeté casse (contrat `recevoir_choc`). Coût selon la charge (MainSort._lancer, ChargeSort).
##   - LÉVITATION D'ENNEMI (Portee.LEVITATION, type CANALISE) : maintenir en visant un ennemi le soulève ; il se débat en l'air et
##     suit le regard (plus lourdement qu'un objet) ; relâcher le PROJETTE (chocs contre les murs, les autres ennemis, les
##     cassables). Coût selon la PUISSANCE de l'ennemi (PV max × poids : faible pour un squelette, énorme pour un troll),
##     drain continu ; mana à 0 = il retombe ; les chefs refusent (« Trop puissant. »), les très forts brisent l'emprise.
##   - ATTRACTION (Portee.ATTRACTION, type RAPIDE) : un point lancé qui s'arrête au premier obstacle et aspire ennemis et objets
##     pendant quelques secondes (vortex, comme ZoneMagie.attirer mais en l'air), puis relâche tout d'un coup (petite explosion
##     de répulsion : les objets s'entrechoquent et cassent). Coût fixe + supplément par ennemi aspiré (selon sa puissance).
## Un nœud par MainSort (enfant « SortsEsprit »). Les ennemis pris (lévitation, vol, vortex) ont leur _physics_process coupé
## (IA et gravité) le temps du vol ; ce nœud les déplace (move_and_collide) et le leur RAND toujours à l'atterrissage, renversés
## (draugr : CHUTE puis il se relève ; troll : SONNE ; autres : réaction lourde) : pas d'IA bloquée.
## `-- --sans-sorts-esprit` : les trois sorts n'existent pas (ni connus, ni raccourcis) — comportement d'avant.

const ECOLE := "esprit"
const IDS := ["repulsion", "levitation", "attraction"]
const GRAVITE := 13.0
## Lévitation : aide à la visée (demi-angle °, élargi de la taille apparente), raideur / amorti / vitesse max du ressort
## (plus lourd que la télékinésie : 7,5 / 9 / 16), montée de l'arrachement (s, m/s), distance de tenue (m).
const AIDE_VISEE := 9.0
const RAIDEUR := 4.2
const AMORTI := 5.5
const VITESSE_TENUE := 8.0
const ARRACHE := 0.4
const VITESSE_ARRACHE := 2.2
const DIST_TENUE := 4.2
const DIST_MIN := 3.0
const HAUTEUR_TENUE := 0.45
## Puissance au-delà de laquelle l'ennemi se dégage : il tient au plus EMPRISE / puissance s (troll : ~1 s).
const SEUIL_RESISTE := 3.0
const EMPRISE := 8.0
## Pas de lancer avant ce temps de tenue (s) : un appui bref le laisse retomber.
const TENUE_MIN := 0.2
## Chocs : vitesse d'impact (m/s, contre la surface) à partir de laquelle un ennemi projeté prend des dégâts ; dégâts par m/s
## au-delà ; chute : vitesse verticale sans dégâts, dégâts par m/s au-delà.
const VITESSE_CHOC := 4.5
const K_CHOC := 1.0
const VITESSE_CHUTE := 7.0
const K_CHUTE := 1.5
## Budget de dégâts PHYSIQUES d'un même vol (murs, sol, objets : somme des chocs subis par l'ennemi projeté) : au plus cette part de ses PV
## max, jamais un coup fatal à lui seul, sauf choc ÉNORME (vitesse d'impact >= VITESSE_ENORME : chute de falaise, mur à pleine vitesse).
const PART_VOL_MAX := 0.6
const VITESSE_ENORME := 22.0
const FACTEUR_LEVITATION := 0.7
## Durée maximale d'un vol (s) : l'ennemi est rendu à son IA quoi qu'il arrive.
const DUREE_VOL := 3.0
## Vitesse minimale (m/s) pour qu'un ennemi décolle ; en dessous il titube seulement (recul).
const VITESSE_DECOLLE := 3.5
## Objets projetés : vitesse au-delà de laquelle leurs contacts comptent (contrat ImpactsLances, comme la télékinésie).
const VITESSE_IMPACT := 6.0
## Vitesse maximale (m/s) d'un objet aspiré vers le centre du vortex (9 avant : une caisse tirée dans le dos d'un ennemi arrivait mollement).
const VITESSE_ASPIRE := 14.0
const PERIODE_RESEAU := 0.1
const EV_ONDE := "es_onde"
const EV_VORTEX := "es_vortex"
const EV_ENNEMI := "es_ennemi"
const EV_OBJETS := "es_objets"

const BLEU := Color("#8cc4f0")
const BLANC := Color("#f2faff")

static var actif := not ("--sans-sorts-esprit" in OS.get_cmdline_user_args())

var magie: MainSort
var joueur: CharacterBody3D
## Lévitation : par main, l'ennemi tenu et son état ({} = rien) ; ennemi visé (surbrillance).
var emprise := {"gauche": {}, "droite": {}}
var visee := {"gauche": null, "droite": null}
## Ennemis contrôlés par ce nœud : id d'instance -> fiche {e, mode ("tenu" | "vol" | "attire"), v, t, touches, ...}.
var vols := {}
## Vortex d'attraction en cours : [{noeud, pos, cible, phase ("vol" | "actif"), t, s, pris, objets, fx}].
var vortex: Array = []
## Journal (tests) : [[horloge, texte]] ; dernier refus ; derniers coûts payés (tests, doc).
var journal: Array = []
var dernier_refus := ""
var dernier_cout := 0.0
var horloge := 0.0
var _refus_t := {}
var _reseau_t := 0.0
var _dernier_but_ennemi := false
## Ragdoll de projection + relevé capturé (scripts/magie/ragdoll_esprit.gd) ; null avec --sans-ragdoll-esprit.
var rag: RagdollEsprit

func _init(m: MainSort = null) -> void:
	magie = m
	name = "SortsEsprit"

func _ready() -> void:
	joueur = magie.joueur if magie != null else null
	_presets()
	_brancher_reseau()
	if RagdollEsprit.actif:
		rag = RagdollEsprit.new(self)
		add_child(rag)

func _noter(t: String) -> void:
	journal.append([horloge, t])
	if journal.size() > 300:
		journal.pop_front()

static func est_sort(s: DonneesSort) -> bool:
	return s != null and s.portee_mode in [DonneesSort.Portee.REPULSION, DonneesSort.Portee.LEVITATION, DonneesSort.Portee.ATTRACTION]

static func est_canalise(s: DonneesSort) -> bool:
	return s != null and s.portee_mode == DonneesSort.Portee.LEVITATION

func _tk() -> Telekinesie:
	return magie.tk if magie != null else null

# ====================================================================== puissance des ennemis (coûts)

## PUISSANCE d'un ennemi : PV max (sans l'échelle de la coop) / 100 × poids de son profil (posture, recul). Squelette 0,52,
## draugr 1,04, draugr guerrier 1,49, troll 8,4 (tableau : docs/MAGIE.md, « Sorts de l'esprit »).
static func puissance(e: Node) -> float:
	var vm := float(e.get("vie_max")) if e.get("vie_max") != null else 100.0
	vm /= maxf(float(e.get_meta("coop_facteur", 1.0)), 0.01)
	var poids := 1.0
	var c: Variant = e.get("combat")
	if c is CombatEnnemi and (c as CombatEnnemi).profil != null:
		poids = (c as CombatEnnemi).profil.poids
	return snappedf(vm / 100.0 * poids, 0.01)

## Chef (draugr nommé : `boss` non vide, groupe « boss », dragon) : la lévitation refuse, la répulsion ne fait que l'ébranler.
static func est_chef(e: Node) -> bool:
	var b: Variant = e.get("boss")
	if (b is String and b != "") or (b is bool and b):
		return true
	if e.is_in_group("boss") or e.is_in_group("chefs"):
		return true
	var sc: Script = e.get_script()
	return sc != null and sc.resource_path.get_file().begins_with("dragon")

## Mana de l'emprise (lévitation) : `cout + cout_puissance × P^0,75` à la saisie, `cout_par_seconde + drain_puissance × P^0,75` /s.
static func cout_levitation(s: DonneesSort, p: float) -> float:
	return s.cout + s.cout_puissance * pow(maxf(p, 0.05), 0.75)

static func drain_levitation(s: DonneesSort, p: float) -> float:
	return s.cout_par_seconde + s.drain_puissance * pow(maxf(p, 0.05), 0.75)

## Supplément de l'attraction par ennemi aspiré.
static func supplement_attraction(s: DonneesSort, p: float) -> float:
	return s.cout_puissance * pow(maxf(p, 0.05), 0.75)

## Durée maximale de l'emprise (s) : illimitée sous SEUIL_RESISTE.
static func duree_emprise(p: float) -> float:
	return INF if p <= SEUIL_RESISTE else EMPRISE / p

static func vivant(e: Variant) -> bool:
	if e == null or not is_instance_valid(e) or not (e as Node).is_inside_tree():
		return false
	if (e as Node).has_method("vivant"):
		return bool(e.vivant())
	return e.get("est_mort") != true

## Hauteur du centre du corps au-dessus de ses pieds (m).
static func demi_hauteur(e: Node3D) -> float:
	return clampf(Elements._centre(e).y - e.global_position.y, 0.4, 2.5)

func _local(e: Node) -> bool:
	return not bool(e.get("marionnette"))

# ====================================================================== cibles

func _cibles(centre: Vector3, rayon: float) -> Array:
	var res: Array = []
	for c in Elements.cibles_dans(centre, rayon):
		if c is CharacterBody3D and not ReseauProjectiles.est_avatar(c) and c != joueur and vivant(c):
			res.append(c)
	return res

## Objets mobiles (télékinésie : groupe `telekinesable`, objets vivants) dans `rayon`.
func _objets(centre: Vector3, rayon: float) -> Array:
	var res: Array = []
	var tk := _tk()
	var liste: Array = tk.candidats() if tk != null else []
	if tk == null:
		for n in get_tree().get_nodes_in_group(Telekinesie.GROUPE):
			liste.append(n)
		for o in ObjetsVivants.tous:
			if is_instance_valid(o) and (o as Node).is_inside_tree():
				liste.append(o)
	for n in liste:
		if n is Node3D and is_instance_valid(n) and Telekinesie.centre(n).distance_to(centre) <= rayon + Telekinesie.rayon(n):
			if tk != null and tk.tenu_par_moi(n):
				continue
			res.append(n)
	return res

func _sans_mur(a: Vector3, b: Vector3, cible: Node = null) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var ex: Array[RID] = []
	if joueur is CollisionObject3D:
		ex.append((joueur as CollisionObject3D).get_rid())
	if cible is CollisionObject3D:
		ex.append((cible as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty() or (r["position"] as Vector3).distance_to(b) < 0.6

## Ennemi visé par la lévitation : le plus proche du réticule (aide douce), à portée, visible.
func viser_ennemi(oeil: Vector3, avant: Vector3, portee: float) -> Node3D:
	var tries: Array = []
	for c: Node3D in _cibles(oeil, portee):
		if _tenu(c) or (rag != null and rag.en_vol(c)):
			continue
		var ce := Elements._centre(c)
		var d := ce - oeil
		var dist := d.length()
		if dist < 0.8 or d.dot(avant) <= 0.0:
			continue
		var a := rad_to_deg(avant.angle_to(d))
		var marge := AIDE_VISEE + rad_to_deg(atan(0.45 / dist))
		if a <= marge:
			tries.append([a / marge + dist * 0.01, c, ce])
	tries.sort_custom(func(x, y): return x[0] < y[0])
	for t in tries.slice(0, 3):
		if _sans_mur(oeil, t[2], t[1]):
			return t[1]
	return null

func _tenu(e: Node) -> bool:
	for m in emprise:
		if not (emprise[m] as Dictionary).is_empty() and emprise[m].get("e") == e:
			return true
	return false

func tient(m: String) -> bool:
	var em: Dictionary = emprise[m]
	return not em.is_empty() and vivant(em.get("e"))

func ennemi_tenu(m: String) -> Node3D:
	return emprise[m].get("e") if tient(m) else null

func _refuser(m: String, raison: String) -> void:
	if horloge - float(_refus_t.get(m + raison, -9.0)) < 1.2:
		return
	_refus_t[m + raison] = horloge
	dernier_refus = raison
	_noter("refus " + raison)
	if magie != null:
		magie.call("_refuser", m, raison)

# ====================================================================== surbrillance (lueur de la télékinésie)

func _lueur(n: Node, f: float) -> void:
	var tk := _tk()
	if tk != null and n != null and is_instance_valid(n):
		tk._coque_force(n, f * 0.6)   # coque d'ennemi encore plus discrète

var _prep_t := 0.0
## Un sort de l'esprit en main : les ragdolls des ennemis proches sont construits d'avance (RagdollEsprit.preparer, un par image).
func preparer_ragdolls(dt: float) -> void:
	_prep_t -= dt
	if rag == null or joueur == null or _prep_t > 0.0:
		return
	_prep_t = 0.3
	for c in _cibles(joueur.global_position, 14.0):
		if _local(c):
			rag.preparer(c)

var _survol_t := 0.0
func survoler(m: String, oeil: Vector3, avant: Vector3, s: DonneesSort, chaque_image := false) -> void:
	if not est_canalise(s) or tient(m):
		_poser_visee(m, null)
		return
	_survol_t -= get_physics_process_delta_time()
	if not chaque_image and _survol_t > 0.0:
		return
	_survol_t = 0.1
	_poser_visee(m, viser_ennemi(oeil, avant, s.portee))

func _poser_visee(m: String, n: Node3D) -> void:
	var ancien = visee[m]
	if ancien == n:
		return
	visee[m] = n
	if ancien != null and is_instance_valid(ancien) and not _tenu(ancien) and not vols.has(ancien.get_instance_id()):
		_lueur(ancien, 0.0)
	if n != null:
		_lueur(n, 0.4)

func oublier_visee(m: String) -> void:
	_poser_visee(m, null)

# ====================================================================== contrôle des ennemis (vol, tenue, vortex)

## Prend l'ennemi en main : IA et gravité coupées, pieds libres, pas de collision avec le joueur. Idempotent.
func _prendre(e: CharacterBody3D, mode: String) -> Dictionary:
	var id := e.get_instance_id()
	if rag != null and rag.contient(e):
		rag.abandonner(e)   # il se relevait (ou volait) en ragdoll : ce sort le reprend tel quel
	if vols.has(id):
		var f0: Dictionary = vols[id]
		f0["mode"] = mode
		f0["t"] = 0.0
		return f0
	e.set_physics_process(false)
	var pieds: Variant = e.get("_pieds")
	if pieds is Node and is_instance_valid(pieds) and pieds.get("actif") != null:
		e.set_meta("es_pieds", bool(pieds.get("actif")))
		pieds.set("actif", false)
	e.velocity = Vector3.ZERO
	if e.get("_recul") is Vector3:
		e.set("_recul", Vector3.ZERO)
	if joueur is PhysicsBody3D:
		e.add_collision_exception_with(joueur)
	var f := {"e": e, "mode": mode, "v": Vector3.ZERO, "t": 0.0, "touches": {}, "p": puissance(e), "debat": 0.0, "lacet": e.rotation.y,
		"draugr": e.has_method("_chuter"), "h": demi_hauteur(e), "sort": null}
	vols[id] = f
	_noter("prise %s (%s, P=%.2f)" % [e.name, mode, float(f["p"])])
	return f

## Rend l'ennemi à son IA (atterri, mort, sorti du vortex) ; `renverser` : il est mis à terre (puis se relève).
func _rendre(f: Dictionary, renverser: bool) -> void:
	var e: CharacterBody3D = f["e"]
	vols.erase(e.get_instance_id() if is_instance_valid(e) else 0)
	if not is_instance_valid(e):
		return
	_lueur(e, 0.0)
	SonsMagie.telekinesie_tenue(e, 0.0)
	e.rotation.x = 0.0
	e.rotation.z = 0.0
	if joueur is PhysicsBody3D:
		e.remove_collision_exception_with(joueur)
	e.velocity = Vector3.ZERO
	var plat: Vector3 = Vector3(f["v"].x, 0.0, f["v"].z)
	if e.has_meta("es_pieds"):
		var pieds: Variant = e.get("_pieds")
		var voulu := bool(e.get_meta("es_pieds"))
		e.remove_meta("es_pieds")
		if e.has_method("_regler_pieds"):
			e.call("_regler_pieds")
		elif pieds is Node and is_instance_valid(pieds):
			pieds.set("actif", voulu)
	e.set_physics_process(true)
	if vivant(e) and renverser:
		_renverser(e, f, plat)
	_noter("rendu %s%s" % [e.name, " (renversé)" if renverser else ""])

## Rend l'ennemi pris (tenu, aspiré) au RagdollEsprit qui le projette : sorti des vols sans lui rendre son IA (le relevé s'en charge).
func _liberer(e: CharacterBody3D) -> void:
	vols.erase(e.get_instance_id())
	_lueur(e, 0.0)
	SonsMagie.telekinesie_tenue(e, 0.0)
	if joueur is PhysicsBody3D:
		e.remove_collision_exception_with(joueur)
	if e.has_meta("es_pieds"):
		e.remove_meta("es_pieds")

## À terre : le draugr est déjà en CHUTE (posée au décollage) et glisse un peu ; le troll est sonné ; les autres reçoivent une
## réaction lourde (EnnemiBase._reagir). Tous se relèvent et reprennent leur IA.
func _renverser(e: CharacterBody3D, f: Dictionary, plat: Vector3) -> void:
	if bool(f["draugr"]):
		if int(e.get("etat")) != int(e.get_script().get_script_constant_map().get("CHUTE", -1)):
			e.call("_chuter", plat * 0.3)
		else:
			if e.get("_recul") is Vector3:
				e.set("_recul", plat.limit_length(4.0) * 0.4)
			# la chute (Death01) a joué pendant le vol : son horloge reprend là où en est l'animation (il se relève à l'heure)
			if e.has_method("_duree") and e.get("_t") != null:
				var d_chute := float(e.call("_duree", "Death01")) / 1.6
				e.set("_t", minf(float(f.get("t_vol", 0.0)), d_chute))
		return
	var cst: Dictionary = e.get_script().get_script_constant_map() if e.get_script() != null else {}
	if cst.has("SONNE") and e.has_method("_changer"):
		e.call("_changer", cst["SONNE"])
		if e.has_method("_jouer"):
			e.call("_jouer", "Hit_Head", 0.05, true)
		if e.get("anim") is AnimationPlayer:
			(e.get("anim") as AnimationPlayer).speed_scale = 0.5
		return
	if e.has_method("_reagir"):
		var vers := -plat if plat.length() > 0.1 else e.global_transform.basis.z
		e.call("_reagir", {"reaction": "lourd", "interrompt": true, "info": {}, "degats": 0.0}, vers)

## Projette l'ennemi (vitesse initiale `v`, m/s) : il vole, percute, retombe, se relève. Un ennemi trop lent ne décolle pas
## (il recule). Pour un invité de la coop, l'hôte applique (événement).
func projeter(e: CharacterBody3D, v: Vector3, s: DonneesSort) -> void:
	if not vivant(e):
		return
	if not _local(e):
		_envoyer_ennemi(e, "projeter", {"v": v})
		return
	if v.length() < VITESSE_DECOLLE and not vols.has(e.get_instance_id()):
		if e.get("_recul") is Vector3:
			e.set("_recul", Vector3(v.x, 0.0, v.z) * 1.4)
		return
	if v.y < 2.2:
		v.y = 2.2   # il décolle (sinon il touche le sol à l'image suivante)
	if rag != null and rag.prendre(e, v, s):
		_liberer(e)   # ragdoll de projection : le corps vole en physique puis se relève (RagdollEsprit)
		return
	var f := _prendre(e, "vol")
	f["v"] = v
	f["sort"] = s
	f["touches"] = {}
	e.global_position += Vector3.UP * 0.06
	_debut_vol(e, f)

func _debut_vol(e: CharacterBody3D, f: Dictionary) -> void:
	f["t_vol"] = 0.0
	if bool(f["draugr"]):
		var cst: Dictionary = e.get_script().get_script_constant_map()
		if int(e.get("etat")) != int(cst.get("CHUTE", -1)):
			e.call("_chuter", Vector3.ZERO)   # Death01 : il bascule en arrière pendant le vol
	elif e.has_method("_jouer"):
		e.call("_jouer", _clip_coup(e), 0.05, true)

func _clip_coup(e: Node) -> String:
	var a: Variant = e.get("anim")
	for nom in ["Hit_Chest", "Hit_Head", "Hit_Stomach", "Hit_Back"]:
		if a is AnimationPlayer and (a as AnimationPlayer).has_animation(nom):
			return nom
	return String(e.get("_anim")) if e.get("_anim") != null else ""

func _physics_process(dt: float) -> void:
	horloge += dt
	for id in vols.keys():
		if not vols.has(id):
			continue
		var f: Dictionary = vols[id]
		var e = f["e"]
		if not is_instance_valid(e) or not (e as Node).is_inside_tree():
			vols.erase(id)
			continue
		if not vivant(e):
			_rendre(f, false)   # mort en vol : son ragdoll a pris le relais
			continue
		f["t"] = float(f["t"]) + dt
		f["t_vol"] = float(f.get("t_vol", 0.0)) + dt
		match String(f["mode"]):
			"tenu":
				_tenir(f, dt)
			"attire":
				_attirer(f, dt)
			"distant":
				_tenir_distant(f, dt)
			_:
				_voler(f, dt)
	_avancer_vortex(dt)
	_reseau_tenu(dt)

## Vol balistique : gravité, glissement contre ce qu'il percute (chocs), atterrissage.
func _voler(f: Dictionary, dt: float) -> void:
	var e: CharacterBody3D = f["e"]
	var v: Vector3 = f["v"]
	v.y -= GRAVITE * dt
	var reste := v * dt
	for k in 3:
		var col := e.move_and_collide(reste)
		if col == null:
			break
		var n := col.get_normal()
		var autre: Object = col.get_collider()
		var vn := -v.dot(n)
		if n.y > 0.6:
			# sol : dégâts de chute selon la vitesse verticale, poussière, il est rendu à son IA (renversé)
			if vn > VITESSE_CHUTE:
				_frapper(e, degats_vol(f, e, (vn - VITESSE_CHUTE) * K_CHUTE, vn), col.get_position(), Vector3.DOWN, 30.0, f.get("sort"))
			_effet_choc(col.get_position(), n, clampf(vn / 10.0, 0.3, 1.2), true)
			_chocs_objets(f, e.global_position + Vector3.UP * float(f["h"]) * 0.6, Vector3(v.x, -absf(v.y), v.z))
			f["v"] = v
			_rendre(f, true)
			return
		if vn > VITESSE_CHOC:
			_choc(f, autre, col.get_position(), n, v, vn)
		v = (v - n * v.dot(n) * 1.25) * 0.75   # rebond mou sur le mur / l'autre corps
		reste = col.get_remainder().slide(n)
	# un autre ennemi sur la trajectoire (les corps des ennemis ne se bloquent pas toujours entre eux) : choc
	if v.length() > VITESSE_CHOC:
		var ce := e.global_position + Vector3.UP * float(f["h"])
		for c: CharacterBody3D in _cibles(ce, 1.8):
			if c == e or (f["touches"] as Dictionary).has(c.get_instance_id()) or (rag != null and rag.en_vol(c)):
				continue
			var dc := Elements._centre(c)
			if Vector2(ce.x - dc.x, ce.z - dc.z).length() < 0.8 and absf(ce.y - dc.y) < 1.3:
				var nn := (ce - dc)
				nn.y = 0.0
				_choc(f, c, (ce + dc) * 0.5, nn.normalized() if nn.length() > 0.01 else -v.normalized(), v, v.length())
				v *= 0.45
	# objets traversés (urnes, tonneaux, meubles : leur calque n'arrête pas toujours un corps d'ennemi) : choc, casse, poussés
	if v.length() > VITESSE_CHOC:
		_chocs_objets(f, e.global_position + Vector3.UP * float(f["h"]), v)
	f["v"] = v
	_agiter(f, dt, 0.7)
	if float(f["t"]) > DUREE_VOL:
		_rendre(f, true)

## Choc d'un ennemi projeté contre un mur, un autre ennemi, un objet : dégâts au projeté et à ce qu'il percute.
func _choc(f: Dictionary, autre: Object, point: Vector3, n: Vector3, v: Vector3, vn: float) -> void:
	var e: CharacterBody3D = f["e"]
	var touches: Dictionary = f["touches"]
	var cle := autre.get_instance_id() if autre != null else 0
	if touches.has(cle):
		return
	touches[cle] = true
	var dg := (vn - VITESSE_CHOC * 0.5) * K_CHOC
	if autre is StaticBody3D:
		# contre un mur : une part de la vie max (un garde en armure à pleine vie en perd ~40-50 % à pleine charge, il survit et se relève)
		dg += float(e.get("vie_max")) * 0.28 * clampf(vn / 12.0, 0.0, 1.2) if e.get("vie_max") != null else 0.0
	var s: DonneesSort = f.get("sort")
	var dg_autre := dg * 0.8
	dg = degats_vol(f, e, dg, vn)
	_noter("choc %s -> %s v=%.1f dg=%.1f" % [e.name, (autre as Node).name if autre is Node else "?", vn, dg])
	_frapper(e, dg, point, -n, 32.0, s)
	var masse := 70.0 * maxf(float(f["p"]), 0.4)
	if autre is CharacterBody3D and Elements.cibles_dans(point, 3.0).has(autre) and autre != joueur and not ReseauProjectiles.est_avatar(autre):
		# un ennemi projeté dans un autre : les deux encaissent, l'autre est emporté (s'il n'est pas un chef)
		_frapper(autre, dg_autre, point, v.normalized(), 30.0, s)
		if not est_chef(autre as Node) and vivant(autre):
			projeter(autre, Vector3(v.x, 0.0, v.z) * 0.55 / sqrt(maxf(puissance(autre), 0.4)) + Vector3.UP * 3.0, s)
	elif autre is Node and (autre as Node).has_method("recevoir_choc"):
		(autre as Node).call("recevoir_choc", v, masse, point)
	elif autre is RigidBody3D:
		var rb := autre as RigidBody3D
		if rb is ObjetVivant:
			(rb as ObjetVivant).reveiller(true)
		rb.freeze = false
		rb.linear_velocity += v * clampf(masse / maxf(rb.mass * 6.0, 1.0), 0.3, 1.2)
		_suivre_objet(rb, rb.mass)
	elif autre is Node and (autre as Node).has_method("frapper") and (autre is Cassable or autre is ObjetVivant):
		(autre as Node).call("frapper", true, point - v.normalized())
	_effet_choc(point, n, clampf(vn / 10.0, 0.4, 1.4), false)

## Objets touchés par le corps d'un ennemi en vol (une fois chacun) : `recevoir_choc` (casse selon l'énergie), sinon poussés.
func _chocs_objets(f: Dictionary, centre: Vector3, v: Vector3) -> void:
	var touches: Dictionary = f["touches"]
	var h := float(f["h"])
	var masse := 70.0 * maxf(float(f["p"]), 0.4)
	for o in _objets(centre, h + 0.4):
		var oc := Telekinesie.centre(o)
		if touches.has(o.get_instance_id()) or Vector2(oc.x - centre.x, oc.z - centre.z).length() > 0.45 + Telekinesie.rayon(o) or absf(oc.y - centre.y) > h + 0.3:
			continue
		if o is RigidBody3D and not (o as RigidBody3D).freeze and (o as RigidBody3D).linear_velocity.length() > 4.0:
			continue   # objet déjà projeté (relâchement du vortex, onde) : il vole de son côté, ses propres chocs comptent
		touches[o.get_instance_id()] = true
		_noter("choc objet %s v=%.1f" % [o.name, v.length()])
		var casse := false
		if o.has_method("recevoir_choc"):
			casse = bool(o.call("recevoir_choc", v, masse, oc))
		if not casse and is_instance_valid(o):
			_pousser_objet(o, v * 0.7 + Vector3.UP * 1.5)

## Dégâts physiques que l'ennemi du vol `f` (fiche de vols ou de RagdollEsprit) peut encore subir : `dg` borné par le budget du vol.
## Lévitation lancée / lâchée : FACTEUR_LEVITATION (écrasement léger à moyen ; la Répulsion garde ses dégâts validés).
func degats_vol(f: Dictionary, e: Node, dg: float, vn: float) -> float:
	var so: Variant = f.get("sort")
	if so is DonneesSort and (so as DonneesSort).portee_mode == DonneesSort.Portee.LEVITATION:
		dg *= FACTEUR_LEVITATION
	if vn >= VITESSE_ENORME or e.get("vie_max") == null:
		return dg
	var deja := float(f.get("subi", 0.0))
	var reste := maxf(0.0, PART_VOL_MAX * float(e.get("vie_max")) - deja)
	dg = minf(dg, reste)
	f["subi"] = deja + dg
	return dg

## Dégâts d'un choc (chemin des sorts : LanceurSorts.frapper, perks, résistances, réseau).
func _frapper(cible: Node, dg: float, point: Vector3, dir: Vector3, st: float, s: DonneesSort) -> String:
	if cible == null or not is_instance_valid(cible) or dg <= 0.5:
		return ""
	if s == null:
		s = _sort("repulsion")
	if s == null:
		return ""
	if magie != null and magie.lanceur != null:
		return magie.lanceur.frapper(cible, dg, s, point, dir, false, st)
	if cible.has_method("recevoir_coup"):
		return String(DegatsCombat.appliquer(cible, dg, point - dir, true, {"type": s.type_degats, "attaque": "sort", "sort": s.id, "point": point, "direction": dir, "stagger": st}))
	return ""

func _sort(id: String) -> DonneesSort:
	if magie != null and magie.eq != null:
		var s := magie.eq.sort_par_id(id)
		if s != null:
			return s
	var ch := "res://data/sorts/%s.tres" % id
	return load(ch) as DonneesSort if ResourceLoader.exists(ch) else null

## L'ennemi se débat (en l'air, tenu, aspiré) : coups encaissés rejoués, membres qui battent (ReactionOs), corps qui tangue.
func _agiter(f: Dictionary, dt: float, force: float) -> void:
	var e: CharacterBody3D = f["e"]
	var t := float(f["t"])
	var ph := float(e.get_instance_id() % 97) * 0.37
	e.rotation.z = sin(t * 5.3 + ph) * 0.12 * force
	e.rotation.x = sin(t * 4.1 + ph * 2.0) * 0.09 * force
	f["debat"] = float(f["debat"]) - dt
	if float(f["debat"]) > 0.0:
		return
	f["debat"] = randf_range(0.35, 0.65)
	if String(f["mode"]) != "vol" or not bool(f["draugr"]):
		if e.has_method("_jouer"):
			var a: Variant = e.get("anim")
			var noms: Array = []
			for nom in ["Hit_Chest", "Hit_Head", "Hit_Stomach", "Hit_Back", "Hit_Shoulder_L", "Hit_Shoulder_R"]:
				if a is AnimationPlayer and (a as AnimationPlayer).has_animation(nom):
					noms.append(nom)
			if not noms.is_empty():
				e.call("_jouer", noms[randi() % noms.size()], 0.08, true)
				if a is AnimationPlayer:
					(a as AnimationPlayer).speed_scale = randf_range(0.7, 1.0)
	var c: Variant = e.get("combat")
	if c is CombatEnnemi and (c as CombatEnnemi).reaction_os != null:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
		(c as CombatEnnemi).reaction_os.frapper_zone(dir, 0.55 * force, ["torse", "bras", "jambes", "tete"][randi() % 4], false)

# ====================================================================== LÉVITATION (état CANALISE de la main)

## Une image de maintien : cherche, saisit, tient. "" ou une raison qui COUPE la main.
func maintenir(m: String, s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3, dt: float) -> String:
	var em: Dictionary = emprise[m]
	if em.is_empty() or not vivant(em.get("e")):
		if not em.is_empty():
			lacher(m)
		survoler(m, oeil, avant, s, true)
		var n = visee[m]
		if n != null and is_instance_valid(n):
			_essayer_emprise(m, n, s, paume, oeil, avant)
		return ""
	em["oeil"] = oeil
	em["avant"] = avant
	em["paume"] = paume
	em["t"] = float(em["t"]) + dt
	var p := float(em["p"])
	var drain := drain_levitation(s, p) * dt * Progression.facteur_cout_sort(ECOLE)
	if not joueur.depenser_mana(drain):
		lacher(m)
		_noter("mana épuisé")
		return "Mana épuisé."
	if float(em["t"]) > duree_emprise(p):
		lacher(m, true)
		_noter("emprise brisée")
		return "Il brise l'emprise !"
	_effets_tenue(m, em, dt)
	return ""

func _essayer_emprise(m: String, e: Node3D, s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3) -> void:
	if not (e is CharacterBody3D):
		return
	if est_chef(e):
		_refuser(m, "Trop puissant.")
		return
	var p := puissance(e)
	if p > s.puissance_max:
		_refuser(m, "Trop puissant.")
		return
	var cout := cout_levitation(s, p) * Progression.facteur_cout_sort(ECOLE)
	if joueur.mana + 0.001 < cout:
		_refuser(m, "Pas assez de mana.")
		return
	joueur.depenser_mana(cout)
	dernier_cout = cout
	_poser_visee(m, null)
	var em := {"e": e, "p": p, "t": 0.0, "oeil": oeil, "avant": avant, "paume": paume, "fx": {},
		"dist": clampf(oeil.distance_to(Elements._centre(e)), DIST_MIN, DIST_TENUE) + clampf(SortsEsprit.demi_hauteur(e) - 0.9, 0.0, 1.0), "sol": e.global_position.y}
	emprise[m] = em
	if _local(e):
		var f := _prendre(e as CharacterBody3D, "tenu")
		f["sort"] = s
		f["v"] = Vector3.UP * VITESSE_ARRACHE
		f["main"] = m
	else:
		_envoyer_ennemi(e, "tenir", {"p": e.global_position})
	_effets_emprise(m, em)
	_noter("emprise %s P=%.2f coût %.1f" % [e.name, p, cout])

## Point (ses pieds) où l'ennemi tenu est attiré : son centre sur la ligne du regard, à `dist`, les pieds au moins HAUTEUR_TENUE
## au-dessus du sol d'où il a été arraché (il ne retouche pas terre), au plus 1,1 m au-dessus (pas collé au plafond).
func _point_tenue(em: Dictionary, f: Dictionary) -> Vector3:
	var oeil: Vector3 = em["oeil"]
	var avant: Vector3 = em["avant"]
	var c := oeil + avant * float(em["dist"])
	var pieds := c - Vector3.UP * float(f["h"])
	var sol := float(em.get("sol", pieds.y - HAUTEUR_TENUE))
	pieds.y = clampf(pieds.y, sol + HAUTEUR_TENUE, sol + 1.1)
	return pieds

func _em_de(e: Node) -> Dictionary:
	for m in emprise:
		var em: Dictionary = emprise[m]
		if not em.is_empty() and em.get("e") == e:
			return em
	return {}

## Ressort amorti (lourd) vers le point de tenue ; il tangue et se débat ; bute contre le décor.
func _tenir(f: Dictionary, dt: float) -> void:
	var e: CharacterBody3D = f["e"]
	var em := _em_de(e)
	if em.is_empty():
		f["mode"] = "vol"
		return
	var t := float(f["t"])
	var v: Vector3 = f["v"]
	if t < ARRACHE:
		v = v.lerp(Vector3.UP * VITESSE_ARRACHE, 1.0 - exp(-dt * 6.0))   # arraché du sol : il monte d'abord
	else:
		var cible := _point_tenue(em, f)
		cible += Vector3(sin(t * 2.3), sin(t * 1.7) * 0.6, cos(t * 2.0)) * 0.06
		var voulue := ((cible - e.global_position) * RAIDEUR).limit_length(VITESSE_TENUE / sqrt(maxf(float(f["p"]), 0.6)))
		v = v.lerp(voulue, 1.0 - exp(-dt * AMORTI))
	var col := e.move_and_collide(v * dt)
	if col != null:
		v = v.slide(col.get_normal()) * 0.8
		e.move_and_collide(col.get_remainder().slide(col.get_normal()))
	f["v"] = v
	# il fait face au joueur en tournant lentement, se débat
	var vers := joueur.global_position - e.global_position
	if vers.length() > 0.1:
		f["lacet"] = lerp_angle(float(f["lacet"]), atan2(vers.x, vers.z), 1.0 - exp(-dt * 1.5))
		e.rotation.y = float(f["lacet"])
	_agiter(f, dt, 1.0)

## Hôte : ennemi tenu par un INVITÉ (positions reçues à 10 /s) ; sans nouvelle depuis 0,5 s, il retombe.
func _tenir_distant(f: Dictionary, dt: float) -> void:
	var e: CharacterBody3D = f["e"]
	f["t_distant"] = float(f.get("t_distant", 0.0)) + dt
	if float(f["t_distant"]) > 0.5:
		f["mode"] = "vol"
		f["touches"] = {}
		_debut_vol(e, f)
		return
	var voulue := ((Vector3(f["cible"]) - e.global_position) * RAIDEUR).limit_length(VITESSE_TENUE)
	var v: Vector3 = (f["v"] as Vector3).lerp(voulue, 1.0 - exp(-dt * AMORTI))
	var col := e.move_and_collide(v * dt)
	if col != null:
		v = v.slide(col.get_normal()) * 0.8
	f["v"] = v
	_agiter(f, dt, 1.0)

## Relâchement : projette l'ennemi tenu vers le réticule (vrai) ; un appui bref le laisse retomber.
func relacher(m: String, s: DonneesSort, oeil: Vector3, avant: Vector3) -> bool:
	var em: Dictionary = emprise[m]
	if em.is_empty() or not vivant(em.get("e")):
		emprise[m] = {}
		return false
	if float(em["t"]) < TENUE_MIN:
		lacher(m)
		return false
	var e: CharacterBody3D = em["e"]
	var p := float(em["p"])
	var charge := clampf((float(em["t"]) - 0.3) / maxf(s.temps_charge_lancer, 0.05), 0.0, 1.0)
	var vit := lerpf(s.vitesse_lancer_min, s.vitesse_lancer_max, charge) * clampf(1.0 / sqrt(maxf(p, 0.2)), 0.4, 1.3)
	var depart := Elements._centre(e)
	var but := _but(oeil, avant, depart, e)
	if not bool(_dernier_but_ennemi):
		but += Vector3.UP * clampf(demi_hauteur(e) * 0.7, 0.3, 1.2)   # visé sur le décor : le corps (et non son centre) y arrive
	var dir := but - depart
	var v := avant * vit
	if dir.length() > 0.1:
		var t_vol := dir.length() / vit
		v = dir / t_vol + Vector3.UP * 0.5 * GRAVITE * t_vol
		v = v.limit_length(vit * 1.2)
	emprise[m] = {}
	_effets_fin(em)
	SonsMagie.telekinesie_lancer(depart, 0.8 + 0.5 * charge)
	_eclat(depart, 1.0 + charge * 0.5)
	if _local(e):
		projeter(e, v, s)
	else:
		_envoyer_ennemi(e, "projeter", {"v": v})
	_noter("lancer %s v=%.1f charge=%.2f" % [e.name, v.length(), charge])
	return true

## Lâche l'ennemi tenu (il retombe) ; `secoue` : il s'est dégagé (petit bond).
func lacher(m: String, secoue := false) -> void:
	var em: Dictionary = emprise[m]
	emprise[m] = {}
	if em.is_empty():
		return
	_effets_fin(em)
	var e = em.get("e")
	if not vivant(e):
		return
	var v := Vector3.ZERO
	if vols.has(e.get_instance_id()):
		v = (vols[e.get_instance_id()]["v"] as Vector3).limit_length(2.0)
	if secoue:
		v += Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1))
		_eclat(Elements._centre(e), 0.7)
	if _local(e):
		if rag != null and rag.prendre(e, v, _sort("levitation")):
			_liberer(e)   # lâché : il retombe en ragdoll et se relève
		else:
			var f := _prendre(e, "vol")
			f["v"] = v
			f["touches"] = {}
			_debut_vol(e, f)
	else:
		_envoyer_ennemi(e, "lacher", {"v": v})
	_noter("lâché %s%s" % [e.name, " (dégagé)" if secoue else ""])

## Point visé : ennemi le plus proche du réticule (hors celui qu'on lance), sinon ce que touche le rayon du réticule.
func _but(oeil: Vector3, avant: Vector3, depart: Vector3, exclu: Node) -> Vector3:
	var but := oeil + avant * 40.0
	var q := PhysicsRayQueryParameters3D.create(oeil, but)
	var ex: Array[RID] = []
	if joueur is CollisionObject3D:
		ex.append((joueur as CollisionObject3D).get_rid())
	if exclu is CollisionObject3D:
		ex.append((exclu as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		but = r["position"]
	var meilleur := 8.0
	_dernier_but_ennemi = false
	for c in _cibles(oeil, 40.0):
		if c == exclu:
			continue
		var ce := Elements._centre(c)
		var a := rad_to_deg(avant.angle_to(ce - oeil))
		if a < meilleur and oeil.distance_to(ce) <= oeil.distance_to(but) + 1.0 and _sans_mur(depart, ce, c):
			meilleur = a
			but = ce
			_dernier_but_ennemi = true
	return but

func tout_lacher() -> void:
	for m in emprise:
		lacher(m)
		oublier_visee(m)

# ====================================================================== RÉPULSION (sort à charge, au relâchement)

## Courbe de puissance de la Répulsion : paliers sensibles selon le maintien (c = charge 0..1 = durée / temps_charge, 3 s).
## tap → 0 ; ~0,3 s → 0,13 ; ~1 s → 0,42 (poussée forte) ; ~2 s → 0,75 ; 3 s → 1 (onde dévastatrice).
const PALIERS_REPULSION := [[0.0, 0.0], [0.1, 0.13], [0.34, 0.42], [0.67, 0.75], [1.0, 1.0]]

static func niveau_repulsion(charge: float) -> float:
	var c := clampf(charge, 0.0, 1.0)
	for i in range(1, PALIERS_REPULSION.size()):
		var a: Array = PALIERS_REPULSION[i - 1]
		var b: Array = PALIERS_REPULSION[i]
		if c <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (c - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
	return 1.0

## Réglages de l'onde pour une charge 0..1 : niveau (courbe à paliers), force (m/s, ennemi de puissance 1), portée (m), demi-angle du cône (°).
## Portée et largeur du cône montent avec le niveau comme la force.
static func reglage_repulsion(s: DonneesSort, charge: float) -> Dictionary:
	var n := niveau_repulsion(charge)
	var cone_max := s.angle_cone_max if s.angle_cone_max > 0.0 else s.angle_cone
	return {"n": n, "force": lerpf(s.force_min, s.force_max, n), "portee": lerpf(s.portee_min, s.portee, n), "cone": lerpf(s.angle_cone, cone_max, n)}

## Onde de choc en cône devant la main (charge 0..1, mana déjà payé par MainSort._lancer). Renvoie le résumé (tests).
func repulsion(s: DonneesSort, charge: float, paume: Node3D, oeil: Vector3, avant: Vector3, distant := false) -> Dictionary:
	var c := clampf(charge, 0.0, 1.0)
	var rg := reglage_repulsion(s, c)
	var n: float = rg["n"]   # niveau de puissance (courbe à paliers) : tout ce qui suit en dépend
	var portee: float = rg["portee"]
	var force: float = rg["force"]
	var demi := deg_to_rad(float(rg["cone"]))
	var plat := Vector3(avant.x, 0.0, avant.z).normalized() if Vector2(avant.x, avant.z).length() > 0.05 else -joueur.global_basis.z
	var depart := EffetsMagie.pos_origine(paume) if paume != null else oeil
	var res := {"ennemis": [], "objets": [], "portee": portee, "charge": c, "niveau": n, "force": force}
	_effets_onde(depart, avant, portee, n, demi)
	if not distant:
		SonsMagie.esprit_onde(depart, 0.7 + 0.6 * n)
		_envoyer(EV_ONDE, "onde", {"p": depart, "a": avant, "c": n})
	var dg := s.degats * lerpf(s.degats_charge_min, 1.0, n)
	if not distant:
		for e: CharacterBody3D in _cibles(oeil, portee + 1.0):
			var ce := Elements._centre(e)
			var d := ce - oeil
			var dh := Vector3(d.x, 0.0, d.z)
			if dh.length() > portee + 0.5 or (dh.length() > 0.6 and plat.angle_to(dh) > demi) or absf(d.y) > 3.0:
				continue
			if not _sans_mur(oeil, ce, e):
				continue
			var k := clampf(1.0 - 0.4 * dh.length() / maxf(portee, 0.1), 0.55, 1.0)
			var p := puissance(e)
			var dir := (dh.normalized() if dh.length() > 0.3 else plat).lerp(plat, 0.35).normalized()
			var vit := force * k * clampf(1.0 / sqrt(maxf(p, 0.1)), 0.3, 1.15)
			if est_chef(e):
				vit *= 0.25
			_frapper(e, dg * k, ce, dir, lerpf(18.0, s.stagger, n) * k, s)
			if vivant(e):
				projeter(e, dir * vit + Vector3.UP * vit * lerpf(0.3, 0.42, n), s)
			(res["ennemis"] as Array).append(e)
	for o in _objets(oeil, portee + 0.5):
		var oc := Telekinesie.centre(o)
		var d2 := oc - oeil
		var dh2 := Vector3(d2.x, 0.0, d2.z)
		if dh2.length() > portee or (dh2.length() > 0.5 and plat.angle_to(dh2) > demi * 1.1) or absf(d2.y) > 2.5:
			continue
		var k2 := clampf(1.0 - 0.4 * dh2.length() / maxf(portee, 0.1), 0.55, 1.0)
		var masse := Telekinesie.masse_de(o)
		var vo := force * 1.25 * k2 * clampf(pow(4.0 / maxf(masse, 0.1), 0.3), 0.5, 1.3)
		var dir2 := (dh2.normalized() if dh2.length() > 0.3 else plat).lerp(plat, 0.3).normalized()
		if _pousser_objet(o, dir2 * vo + Vector3.UP * vo * 0.3, distant):
			(res["objets"] as Array).append(o)
	if not distant:
		_reseau_objets(res["objets"])
		_noter("répulsion charge=%.2f niveau=%.2f force=%.1f portée=%.1f ennemis=%d objets=%d" % [c, n, force, portee, (res["ennemis"] as Array).size(), (res["objets"] as Array).size()])
	return res

## Met un objet en mouvement (le réveille, le change en corps si besoin) et le fait suivre par la télékinésie pour ses impacts
## (ennemis touchés, casse contre les murs). Faux si l'objet ne peut pas bouger.
func _pousser_objet(o: Node3D, v: Vector3, distant := false) -> bool:
	var corps: RigidBody3D = null
	var tk := _tk()
	if o is RigidBody3D:
		corps = o
	elif tk != null:
		corps = tk._corps_de(o)
	if corps == null or not is_instance_valid(corps):
		if o.has_method("recevoir_choc"):
			o.call("recevoir_choc", v, 5.0, Telekinesie.centre(o))
			return true
		return false
	if corps is ObjetVivant:
		(corps as ObjetVivant).reveiller(true)
	elif corps.has_method("reveiller"):
		corps.call("reveiller")   # Cassable : corps gelé qui se réveille (masque du décor)
	corps.freeze = false
	corps.sleeping = false
	corps.linear_velocity = v
	corps.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * clampf(5.0 / sqrt(maxf(corps.mass, 0.5)), 1.0, 6.0)
	if not distant:
		_suivre_objet(corps, Telekinesie.masse_de(corps))
	return true

## Suivi des impacts d'un objet mis en mouvement (le mécanisme de la télékinésie : ImpactsLances, recevoir_choc).
func _suivre_objet(corps: RigidBody3D, masse: float) -> void:
	var tk := _tk()
	if tk == null or not is_instance_valid(corps):
		return
	tk._sortir_des_lances(corps)
	if joueur is PhysicsBody3D:
		corps.add_collision_exception_with(joueur)
	corps.set_meta("lance_par", joueur)
	corps.set_meta("lance_jusqu_a", tk.horloge + Telekinesie.DUREE_LANCER)
	var l := tk._suivi(corps, {"masse": masse}, true)
	l["coque_t"] = 0.5
	tk.lances.append(l)

# ====================================================================== ATTRACTION (sort lancé : un point qui aspire)

func attraction(s: DonneesSort, paume: Node3D, oeil: Vector3, avant: Vector3, distant_vers := Vector3.INF) -> Dictionary:
	var depart := EffetsMagie.pos_origine(paume) if paume != null else oeil + avant * 0.5
	var cible := distant_vers
	if cible == Vector3.INF:
		var v := magie.lanceur.viser(oeil, avant, s.portee, 1.2) if magie != null else {"point": oeil + avant * s.portee, "normale": -avant}
		cible = Vector3(v["point"]) + Vector3(v.get("normale", -avant)) * 0.6
		if v.get("cible") != null and is_instance_valid(v.get("cible")):
			cible = Elements._centre(v["cible"]) + Vector3.UP * 0.2   # sur un ennemi : le vortex s'ouvre sur lui
		# pas trop bas : le vortex flotte à hauteur de torse au-dessus du sol
		var q := PhysicsRayQueryParameters3D.create(cible + Vector3.UP * 0.5, cible + Vector3.DOWN * 3.0, 1)
		var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			cible.y = maxf(cible.y, (r["position"] as Vector3).y + 1.6)
		_envoyer(EV_VORTEX, "vortex", {"p": depart, "c": cible})
		SonsMagie.lancement(Telekinesie.ECOLE_VISUELLE, depart, 0.8)
	var vx := {"pos": depart, "cible": cible, "phase": "vol", "t": 0.0, "s": s, "pris": {}, "objets": {}, "fx": {}, "distant": distant_vers != Vector3.INF}
	vortex.append(vx)
	_effets_vortex_vol(vx)
	_noter("attraction lancée vers %s" % str(cible.snappedf(0.1)))
	return vx

func _avancer_vortex(dt: float) -> void:
	var i := vortex.size() - 1
	while i >= 0:
		var vx: Dictionary = vortex[i]
		vx["t"] = float(vx["t"]) + dt
		var s: DonneesSort = vx["s"]
		if String(vx["phase"]) == "vol":
			var p: Vector3 = vx["pos"]
			var c: Vector3 = vx["cible"]
			var pas := s.vitesse * dt
			if p.distance_to(c) <= pas or float(vx["t"]) > 2.0:
				vx["pos"] = c
				vx["phase"] = "actif"
				vx["t"] = 0.0
				_effets_vortex_ouvre(vx)
			else:
				vx["pos"] = p + (c - p).normalized() * pas
			_effets_vortex_suivre(vx)
		else:
			_aspirer(vx, dt)
			_effets_vortex_suivre(vx)
			if float(vx["t"]) >= s.duree_vortex:
				_relacher_vortex(vx)
				vortex.remove_at(i)
		i -= 1

## Une image du vortex : capture des ennemis (payée, selon leur puissance) et des objets, puis tourbillon vers le centre.
func _aspirer(vx: Dictionary, dt: float) -> void:
	var s: DonneesSort = vx["s"]
	var centre: Vector3 = vx["pos"]
	var montee := clampf(float(vx["t"]) / 0.4, 0.0, 1.0)
	var pris: Dictionary = vx["pris"]
	if not bool(vx["distant"]):
		for e: CharacterBody3D in _cibles(centre, s.rayon):
			var id := e.get_instance_id()
			if pris.has(id) or _tenu(e) or (rag != null and rag.en_vol(e)):
				continue
			if not _sans_mur(centre, Elements._centre(e), e):
				continue
			var p := puissance(e)
			if est_chef(e) or p > s.puissance_max:
				pris[id] = {"e": e, "lourd": true}   # chef : tiré au sol (recul), pas soulevé
				continue
			var sup := supplement_attraction(s, p) * Progression.facteur_cout_sort(ECOLE)
			if not joueur.depenser_mana(sup):
				pris[id] = {"e": e, "lourd": true}
				_noter("attraction : pas de mana pour %s" % e.name)
				continue
			dernier_cout += sup
			pris[id] = {"e": e, "lourd": false}
			if _local(e):
				var f := _prendre(e, "attire")
				f["vortex"] = vx
				f["sort"] = s
				f["angle"] = atan2(e.global_position.z - centre.z, e.global_position.x - centre.x)
				_debut_vol(e, f)
				_lueur(e, 0.8)
			_noter("aspiré %s P=%.2f supplément %.1f" % [e.name, p, sup])
		for id2 in pris:
			var d: Dictionary = pris[id2]
			if bool(d["lourd"]) and vivant(d["e"]) and d["e"].get("_recul") is Vector3:
				var w: Vector3 = centre - (d["e"] as Node3D).global_position
				w.y = 0.0
				if w.length() > 0.8:
					d["e"].set("_recul", w.normalized() * s.attraction * 0.5)
	# objets : aspirés en spirale (sans gravité), ils s'entrechoquent au centre
	var objets: Dictionary = vx["objets"]
	for o in _objets(centre, s.rayon * 1.2):
		var id3: int = o.get_instance_id()
		if objets.has(id3):
			continue
		var corps: RigidBody3D = o if o is RigidBody3D else (_tk()._corps_de(o) if _tk() != null else null)
		if corps == null or Telekinesie.masse_de(corps) > 80.0:
			continue
		if corps is ObjetVivant:
			(corps as ObjetVivant).reveiller(true)
			(corps as ObjetVivant).tenu = true
		if corps.has_method("saisi_telekinesie"):
			corps.saisi_telekinesie(true)   # Cassable : réveillé, pas regelé tant qu'il est pris
		corps.freeze = false
		corps.can_sleep = false
		corps.gravity_scale = 0.0
		objets[id3] = corps
		_lueur(corps, 0.6)
	for id4 in objets.keys():
		var rb = objets[id4]
		if rb == null or not is_instance_valid(rb):
			objets.erase(id4)
			continue
		var corps2 := rb as RigidBody3D
		var r := corps2.global_position - centre
		var tang := Vector3.UP.cross(r).normalized() if Vector2(r.x, r.z).length() > 0.05 else Vector3.RIGHT
		var voulu := -r * 2.6 + tang * 3.2 * clampf(r.length(), 0.3, 1.5) + Vector3.UP * sin(float(vx["t"]) * 3.0 + float(id4 % 7)) * 0.6
		corps2.linear_velocity = corps2.linear_velocity.lerp(voulu.limit_length(VITESSE_ASPIRE) * montee, 1.0 - exp(-dt * 3.0))
		if not bool(vx["distant"]) and DegatsObjets.actif and corps2.linear_velocity.length() >= VITESSE_IMPACT and corps2.get_node_or_null("SuiviLancer") == null \
				and not Elements.cibles_dans(corps2.global_position, 2.5).is_empty():
			_suivre_vortex(vx, corps2)   # objet qui fonce vers le centre (tiré dans le dos d'un ennemi) : ses impacts comptent (dégâts, casse)
		corps2.angular_velocity = corps2.angular_velocity.lerp(tang * 4.0, 1.0 - exp(-dt * 2.0))
		corps2.sleeping = false

## Suivi des impacts d'un objet aspiré qui fonce (SuiviLancer : balayage de sa forme, ImpactsLances.objet_touche ; il s'éteint seul sous
## 4 m/s, donc l'orbite lente autour du centre ne fait aucun dégât, et reprend dès que l'objet repasse VITESSE_IMPACT).
func _suivre_vortex(vx: Dictionary, corps: RigidBody3D) -> void:
	if not is_instance_valid(corps):
		return
	if joueur is PhysicsBody3D:
		corps.add_collision_exception_with(joueur)
	corps.set_meta("lance_par", joueur)
	corps.set_meta("lance_jusqu_a", horloge + Telekinesie.DUREE_LANCER)
	ImpactsLances.suivre(corps, joueur, float((vx["s"] as DonneesSort).duree_vortex) + 1.0)

## Ennemi aspiré : il tourne autour du centre en se rapprochant, soulevé, en se débattant.
func _attirer(f: Dictionary, dt: float) -> void:
	var e: CharacterBody3D = f["e"]
	var vx: Dictionary = f.get("vortex", {})
	if vx.is_empty() or not vortex.has(vx):
		f["mode"] = "vol"
		return
	var centre: Vector3 = vx["pos"]
	var s: DonneesSort = vx["s"]
	var t := float(f["t"])
	f["angle"] = float(f["angle"]) + dt * lerpf(0.6, 2.2, clampf(t / 1.2, 0.0, 1.0))
	if not f.has("r0"):
		f["r0"] = clampf(Vector2(e.global_position.x - centre.x, e.global_position.z - centre.z).length(), 0.8, s.rayon)
	var r_orbite := lerpf(float(f["r0"]), 0.75, smoothstep(0.0, 1.0, clampf(t / 1.0, 0.0, 1.0)))
	var cible := centre + Vector3(cos(float(f["angle"])), 0.0, sin(float(f["angle"]))) * r_orbite
	cible.y = centre.y - float(f["h"]) - 0.35 + sin(t * 2.1) * 0.12   # le corps pend sous le centre, pieds décollés
	var voulue := ((cible - e.global_position) * 5.0).limit_length(s.attraction / sqrt(maxf(float(f["p"]), 0.6)))
	var v: Vector3 = (f["v"] as Vector3).lerp(voulue, 1.0 - exp(-dt * 5.0))
	var col := e.move_and_collide(v * dt)
	if col != null:
		v = v.slide(col.get_normal()) * 0.8
	f["v"] = v
	_agiter(f, dt, 0.9)

## Fin du vortex : tout est relâché d'un coup (petite explosion de répulsion) ; les objets volent et cassent.
func _relacher_vortex(vx: Dictionary) -> void:
	var s: DonneesSort = vx["s"]
	var centre: Vector3 = vx["pos"]
	_effets_vortex_fin(vx)
	SonsMagie.esprit_vortex_fin(centre)
	var n_e := 0
	for id in (vx["pris"] as Dictionary):
		var d: Dictionary = vx["pris"][id]
		var e = d["e"]
		if not vivant(e):
			continue
		var w: Vector3 = (e as Node3D).global_position + Vector3.UP * 0.5 - centre
		var dir := Vector3(w.x, 0.0, w.z).normalized() if Vector2(w.x, w.z).length() > 0.1 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var p := puissance(e)
		_frapper(e, s.degats, Elements._centre(e), dir, 26.0, s)
		if bool(d["lourd"]) or not vivant(e):
			continue
		var vit := s.force_max / sqrt(maxf(p, 0.45))
		var f: Dictionary = vols.get((e as Node).get_instance_id(), {})
		if not f.is_empty():
			f.erase("vortex")
		projeter(e, dir * vit + Vector3.UP * vit * 0.45, s)
		n_e += 1
	var n_o := 0
	for id2 in (vx["objets"] as Dictionary):
		var rb = vx["objets"][id2]
		if rb == null or not is_instance_valid(rb):
			continue
		var corps := rb as RigidBody3D
		corps.gravity_scale = 1.0
		corps.can_sleep = true
		if corps is ObjetVivant:
			(corps as ObjetVivant).tenu = false
		if corps.has_method("saisi_telekinesie"):
			corps.saisi_telekinesie(false)
		_lueur(corps, 0.0)
		var w2 := corps.global_position - centre
		var dir2 := (w2.normalized() if w2.length() > 0.1 else Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized())
		dir2 = (dir2 + Vector3.UP * 0.25).normalized()
		var masse := Telekinesie.masse_de(corps)
		corps.linear_velocity = dir2 * s.force_max * 1.2 * clampf(pow(4.0 / maxf(masse, 0.1), 0.3), 0.4, 1.3)
		if not bool(vx["distant"]):
			_suivre_objet(corps, masse)
		n_o += 1
	_noter("attraction relâchée : %d ennemis, %d objets projetés" % [n_e, n_o])

# ====================================================================== effets (DA PS1 : couche fine des sorts, pas de tramage)

static func _presets() -> void:
	if PresetsMagie.R.has("es_onde"):
		return
	var esprit := ["#f2faff", "#c8e6fa", "#8cc4f0", "#5a8ec8"]
	var R: Dictionary = PresetsMagie.R
	# onde de choc : gerbe d'étincelles fines qui file dans le cône (direction -Z du repère d'émission), freinée à la portée
	R["es_onde"] = {"add": true, "n": 16, "vie": 0.4, "expl": 1.0, "forme": "sphere", "r": 0.12, "dir": Vector3(0, 0, -1), "ecart": 32.0, "vit": Vector2(7.0, 16.0), "amort": Vector2(10.0, 18.0), "taille": Vector2(0.004, 0.008), "courbe": "descend", "rampe": ["#c8d6e0", "#8fa3b4", "#5f7284"], "eclat": 0.8, "cap": 3.0}
	# voile d'air (motes plus grosses, douces) qui accompagne l'onde
	R["es_voile"] = {"add": true, "n": 6, "vie": 0.4, "expl": 1.0, "forme": "sphere", "r": 0.2, "dir": Vector3(0, 0, -1), "ecart": 30.0, "vit": Vector2(4.0, 9.0), "amort": Vector2(6.0, 9.0), "taille": Vector2(0.04, 0.08), "courbe": "bosse", "rampe": ["#8cc4f030", "#5a8ec822", "#3a5a9010"], "eclat": 0.7, "cap": 9.0}
	# poussière soulevée au sol par l'onde
	R["es_poussiere"] = {"n": 16, "vie": 0.9, "expl": 0.9, "forme": "disque", "r": 0.35, "dir": Vector3.UP, "ecart": 70.0, "vit": Vector2(0.3, 1.0), "radiale_v": Vector2(0.6, 1.6), "amort": Vector2(1.5, 3.0), "grav": Vector3(0, 0.1, 0), "taille": Vector2(0.04, 0.09), "courbe": "bosse", "rampe": ["#6e6a6470", "#5a565250", "#46423f30"], "eclat": 0.9, "cap": 9.0}
	# orbe du vortex en vol
	R["es_orbe"] = {"add": true, "n": 14, "vie": 0.35, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.05, 0.4), "taille": Vector2(0.007, 0.015), "courbe": "descend", "rampe": ["#ffffff", "#f2faff", "#c8e6fa", "#8cc4f0"], "eclat": 1.4, "cap": 3.0}
	# vortex ouvert : étincelles fines aspirées vers le centre depuis une sphère (accélération radiale négative)
	R["es_vortex"] = {"add": true, "n": 45, "vie": 0.8, "forme": "surface", "r": 2.6, "ecart": 180.0, "vit": Vector2(0.0, 0.2), "radial": Vector2(-9.0, -6.0), "taille": Vector2(0.006, 0.013), "courbe": "monte", "rampe": ["#5a8ec8", "#8cc4f0", "#c8e6fa", "#f2faff"], "eclat": 1.3, "cap": 3.0}
	# cœur du vortex : motes douces qui palpitent
	R["es_coeur"] = {"add": true, "n": 8, "vie": 0.6, "forme": "sphere", "r": 0.25, "ecart": 180.0, "vit": Vector2(0.0, 0.3), "taille": Vector2(0.03, 0.07), "courbe": "bosse", "rampe": ["#f2faff90", "#8cc4f060", "#5a8ec830"], "eclat": 0.8, "cap": 9.0}
	# relâchement : éclat d'étincelles dans toutes les directions
	R["es_eclat"] = {"add": true, "n": 14, "vie": 0.4, "expl": 1.0, "forme": "sphere", "r": 0.3, "ecart": 180.0, "vit": Vector2(4.0, 10.0), "amort": Vector2(5.0, 9.0), "taille": Vector2(0.007, 0.016), "courbe": "descend", "rampe": esprit, "eclat": 1.4, "cap": 3.0}
	# choc d'un ennemi projeté contre un mur / le sol : poussière et éclats de pierre gris
	R["es_choc"] = {"n": 20, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.2, "dir": Vector3.UP, "ecart": 75.0, "vit": Vector2(0.6, 2.2), "amort": Vector2(2.0, 4.0), "grav": Vector3(0, -1.2, 0), "taille": Vector2(0.03, 0.07), "courbe": "bosse", "rampe": ["#7a746c80", "#5e5a5460", "#46423f30"], "eclat": 0.9, "cap": 9.0}

func _g() -> GestionMagie:
	return GestionMagie.obtenir() if not EffetsMagie.muet else null

## Repère dont -Z regarde `dir`.
static func _base_vers(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var haut := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(d, haut)

func _eclat(pos: Vector3, k: float) -> void:
	var g := _g()
	if g == null:
		return
	g.emettre("tk_arrache", null, Transform3D(Basis(), pos), false, k)
	g.lumiere("es_eclat%d" % (randi() % 1000), pos, BLANC, 0.5 * k, 3.0, 2.5, 0.12)

func _effets_onde(depart: Vector3, avant: Vector3, portee: float, c: float, demi: float) -> void:
	var g := _g()
	if g == null:
		return
	var b := _base_vers(avant)
	var echelle := portee / 6.0
	g.emettre("es_onde", null, Transform3D(b, depart + avant * 0.2), false, 0.6 + 0.7 * c, -1.0,
		g._pm("es_onde", PresetsMagie.R["es_onde"], {"ecart": snappedf(rad_to_deg(demi), 1.0), "vit": Vector2(5.0, 11.0 + 7.0 * c) * maxf(echelle, 0.6)}))
	g.emettre("es_voile", null, Transform3D(b, depart + avant * 0.35), false, 0.7 + 0.5 * c)
	# anneaux de l'onde : fins, translucides, qui s'étendent en s'éloignant (le premier à 1,8 m : pas un écran devant la caméra)
	var reg := {"couleur": "#8cc4f0", "coeur": "#f2faff", "anneau": 0.94, "epaisseur": 0.012, "texels": 110.0, "eclat": 0.6, "opacite": 0.06}
	g.disque(depart + avant * 1.8, avant, 0.25, 0.8 + 0.5 * c, 0.26, reg, false, false, 0.7)
	var reg2 := reg.duplicate()
	reg2["epaisseur"] = 0.01
	reg2["opacite"] = 0.04
	g.disque(depart + avant * (3.0 + 1.5 * c), avant, 0.5, 1.4 + 1.2 * c, 0.36, reg2, false, false, 0.7)
	g.lumiere("es_onde", depart + avant * 1.2, BLANC, 0.6 + 0.6 * c, 4.0 + portee * 0.5, 3.0, 0.16)
	# poussière soulevée au sol dans le cône
	var plat := Vector3(avant.x, 0.0, avant.z).normalized()
	for k in 3 + int(round(5.0 * c)):
		var p := depart + plat * (1.2 + (k % 4) * portee * 0.22 + int(k / 4) * 0.8) + plat.cross(Vector3.UP) * randf_range(-0.6, 0.6) * k
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 3.0, 1)
		var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			g.emettre("es_poussiere", null, Transform3D(Basis(), r["position"] + Vector3.UP * 0.04), false, 0.6 + 0.6 * c)

func _effet_choc(point: Vector3, n: Vector3, k: float, sol: bool) -> void:
	var g := _g()
	RetourImpact.son(joueur, "chute_pierre", point, -4.0 + 6.0 * clampf(k, 0.0, 1.0), 0.8 + 0.3 * randf())
	if g == null:
		return
	g.emettre("es_choc", null, Transform3D(GestionMagie.base_normale(n) if not sol else Basis(), point + n * 0.05), false, k)

func _effets_emprise(m: String, em: Dictionary) -> void:
	var e: Node3D = em["e"]
	_lueur(e, 1.0)
	SonsMagie.esprit_emprise(e.global_position)
	SonsMagie.telekinesie_tenue(e, 1.0)
	var g := _g()
	if g == null:
		return
	var fx: Dictionary = em["fx"]
	var h := demi_hauteur(e)
	var xf := Transform3D(Basis(), Vector3.UP * h)
	var ext := Vector3(0.35, h * 0.9, 0.35)
	fx["aura"] = g.emettre("tk_objet", e, xf, true, 1.8, -1.0, g._pm("tk_objet", PresetsMagie.R["tk_objet"], {"ext": Vector3(0.35, snappedf(ext.y, 0.05), 0.35)}))
	g.emettre("tk_poussiere", null, Transform3D(Basis(), e.global_position + Vector3.UP * 0.04), false, 1.2)

func _effets_tenue(_m: String, em: Dictionary, _dt: float) -> void:
	var e: Node3D = em["e"]
	var t := float(em["t"])
	_lueur(e, 0.8 + 0.15 * sin(t * 6.0))
	SonsMagie.telekinesie_tenue(e, 0.7)
	var g := _g()
	if g != null:
		g.lumiere("es_tenu%d" % e.get_instance_id(), Elements._centre(e), BLEU, 0.2, 2.6, 2.0, 0.12)

func _effets_fin(em: Dictionary) -> void:
	var fx: Dictionary = em.get("fx", {})
	var g := _g()
	if g != null:
		if fx.get("aura") != null:
			g.arreter(fx["aura"])
	fx.clear()
	var e = em.get("e")
	if e != null and is_instance_valid(e):
		SonsMagie.telekinesie_tenue(e, 0.0)
		_lueur(e, 0.6)

func _effets_vortex_vol(vx: Dictionary) -> void:
	var g := _g()
	if g == null:
		return
	var fx: Dictionary = vx["fx"]
	var n := Node3D.new()
	n.name = "VortexEsprit"
	var sc := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	sc.add_child(n)
	n.global_position = vx["pos"]
	fx["noeud"] = n
	fx["orbe"] = g.emettre("es_orbe", n, Transform3D.IDENTITY, true)
	g.emettre("tk_lancer", null, Transform3D(Basis(), vx["pos"]), false, 0.5)

func _effets_vortex_ouvre(vx: Dictionary) -> void:
	var s: DonneesSort = vx["s"]
	var fx: Dictionary = vx["fx"]
	var n: Node3D = fx.get("noeud")
	if n != null and is_instance_valid(n):
		SonsMagie.esprit_vortex(n, 1.0)
	var g := _g()
	if g == null:
		return
	if fx.get("orbe") != null:
		g.arreter(fx["orbe"])
	if n == null or not is_instance_valid(n):
		return
	fx["tourbillon"] = g.emettre("es_vortex", n, Transform3D.IDENTITY, true, 1.0, -1.0, g._pm("es_vortex", PresetsMagie.R["es_vortex"], {"r": snappedf(s.rayon * 0.6, 0.1)}))
	fx["coeur"] = g.emettre("es_coeur", n, Transform3D.IDENTITY, true)
	# cœur spiralé face caméra et anneau spiralé au sol, qui tournent pendant toute la durée
	var d1 := g.disque(vx["pos"], Vector3.UP, 0.35, 0.6, s.duree_vortex, {"couleur": "#8cc4f0", "coeur": "#f2faff", "anneau": 0.6, "epaisseur": 0.12, "spirale": 0.9, "texels": 72.0, "eclat": 1.0, "remplissage": 0.0, "tourne": 0.7, "opacite": 0.12}, false, true, 0.15)
	if not d1.is_empty():
		d1["suivre"] = n
	var q := PhysicsRayQueryParameters3D.create(vx["pos"], Vector3(vx["pos"]) + Vector3.DOWN * 4.0, 1)
	var r := joueur.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		g.disque(r["position"], Vector3.UP, s.rayon * 0.75, s.rayon * 0.3, s.duree_vortex, {"couleur": "#5a8ec8", "coeur": "#c8e6fa", "anneau": 0.85, "epaisseur": 0.03, "spirale": 0.6, "texels": 40.0 * s.rayon, "eclat": 0.8, "opacite": 0.18, "tourne": 0.45}, false, false, 0.2)
	g.emettre("es_eclat", null, Transform3D(Basis(), vx["pos"]), false, 0.4)

func _effets_vortex_suivre(vx: Dictionary) -> void:
	var fx: Dictionary = vx["fx"]
	var n: Node3D = fx.get("noeud")
	if n != null and is_instance_valid(n):
		n.global_position = vx["pos"]
	var g := _g()
	if g != null:
		var puls := 0.35 + 0.1 * sin(float(vx["t"]) * 9.0) if String(vx["phase"]) == "actif" else 0.3
		g.lumiere("es_vortex%d" % vx.hash(), vx["pos"], BLEU, puls, 4.5 if String(vx["phase"]) == "actif" else 2.5, 3.0, 0.12)

func _effets_vortex_fin(vx: Dictionary) -> void:
	var s: DonneesSort = vx["s"]
	var fx: Dictionary = vx["fx"]
	var n: Node3D = fx.get("noeud")
	var g := _g()
	if g != null:
		for k in ["tourbillon", "coeur", "orbe"]:
			if fx.get(k) != null:
				g.arreter(fx[k])
		g.emettre("es_eclat", null, Transform3D(Basis(), vx["pos"]), false, 0.8)
		g.emettre("es_voile", null, Transform3D(_base_vers(Vector3.UP), vx["pos"]), false, 0.7)
		g.disque(vx["pos"], Vector3.UP, 0.3, s.rayon * 0.9, 0.4, {"couleur": "#8cc4f0", "coeur": "#f2faff", "anneau": 0.94, "epaisseur": 0.025, "texels": 30.0 * s.rayon, "eclat": 1.0, "opacite": 0.3}, false, true, 0.7)
		g.lumiere("es_vortex_fin", vx["pos"], BLANC, 1.0, 5.0, 3.0, 0.18)
	if n != null and is_instance_valid(n):
		SonsMagie.esprit_vortex(n, 0.0)
		n.get_tree().create_timer(0.6).timeout.connect(n.queue_free)

func _exit_tree() -> void:
	for m in emprise:
		emprise[m] = {}
	for id in vols.keys():
		if vols.has(id):
			_rendre(vols[id], false)

# ====================================================================== réseau (coop, docs/RESEAU_BILAN.md)
## L'HÔTE détient l'IA des ennemis : ses vols sont répliqués tels quels (position, lacet, animation : CombatCoop._etat). Un
## INVITÉ ne déplace pas ses marionnettes : il demande à l'hôte (es_ennemi : projeter / tenir à 10 /s / lâcher), qui applique le vol
## chez lui (chocs et dégâts calculés par l'hôte). Onde, vortex et objets poussés : annoncés (es_onde, es_vortex, es_objets) et
## rejoués chez les autres (visuel + objets locaux), sans effet sur les ennemis (l'hôte s'en charge).

func _reseau() -> Node:
	return ReseauProjectiles.reseau() if ReseauProjectiles.en_ligne() else null

func _brancher_reseau() -> void:
	var r := ReseauProjectiles.reseau()
	if r == null or not r.has_method("abonner"):
		return
	r.abonner(EV_ONDE, _sur_onde)
	r.abonner(EV_VORTEX, _sur_vortex)
	r.abonner(EV_ENNEMI, _sur_ennemi)
	r.abonner(EV_OBJETS, _sur_objets)

func _envoyer(type: String, id: String, d: Dictionary) -> void:
	var r := _reseau()
	if r == null or joueur.get("est_local") == false:
		return
	r.envoyer_evenement(type, id, d)

func _envoyer_ennemi(e: Node, op: String, d: Dictionary) -> void:
	if not e.has_meta("coop_id"):
		return
	var dd := d.duplicate()
	dd["op"] = op
	_envoyer(EV_ENNEMI, String(e.get_meta("coop_id")), dd)

func _relayer(expediteur: int, type: String, id: Variant, d: Variant) -> void:
	var r := _reseau()
	if r != null and r.has_method("est_hote") and r.est_hote():
		for pair in r.joueurs():
			if pair != expediteur and pair != r.mon_id():
				r.envoyer_evenement(type, id, d, pair)

func _reseau_objets(liste: Array) -> void:
	if _reseau() == null or liste.is_empty():
		return
	var tab: Array = []
	for o in liste:
		if is_instance_valid(o):
			var id := Telekinesie.ident_de(o)
			if id != "" and o is RigidBody3D:
				tab.append([id, (o as RigidBody3D).global_position, (o as RigidBody3D).linear_velocity])
	if not tab.is_empty():
		_envoyer(EV_OBJETS, "objets", {"l": tab})

## Invité : positions de tenue des ennemis qu'il lévite (l'hôte les applique).
func _reseau_tenu(dt: float) -> void:
	if _reseau() == null:
		return
	_reseau_t -= dt
	if _reseau_t > 0.0:
		return
	_reseau_t = PERIODE_RESEAU
	for m in emprise:
		var em: Dictionary = emprise[m]
		if em.is_empty() or not vivant(em.get("e")) or _local(em["e"]):
			continue
		var f := {"h": demi_hauteur(em["e"])}
		_envoyer_ennemi(em["e"], "tenir", {"p": _point_tenue(em, f)})

func _sur_onde(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_ONDE, id, d)
	if not (d is Dictionary):
		return
	var a: Vector3 = d.get("a", Vector3.FORWARD)
	var s := _sort("repulsion")
	if s != null:
		var nr := float(d.get("c", 0.5))   # niveau de puissance (déjà passé par la courbe)
		var cone_max := s.angle_cone_max if s.angle_cone_max > 0.0 else s.angle_cone
		_effets_onde(d.get("p", Vector3.ZERO), a, lerpf(s.portee_min, s.portee, nr), nr, deg_to_rad(lerpf(s.angle_cone, cone_max, nr)))
		SonsMagie.esprit_onde(d.get("p", Vector3.ZERO), 0.7 + 0.6 * nr)

func _sur_vortex(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_VORTEX, id, d)
	var s := _sort("attraction")
	if s != null and d is Dictionary:
		var vx := {"pos": d.get("p", Vector3.ZERO), "cible": d.get("c", Vector3.ZERO), "phase": "vol", "t": 0.0, "s": s, "pris": {}, "objets": {}, "fx": {}, "distant": true}
		vortex.append(vx)
		_effets_vortex_vol(vx)

func _sur_objets(expediteur: int, id: Variant, d: Variant) -> void:
	_relayer(expediteur, EV_OBJETS, id, d)
	var tk := _tk()
	if tk == null or not (d is Dictionary):
		return
	for x in d.get("l", []):
		var c := tk._trouver(String(x[0]))
		if c != null:
			if c is ObjetVivant:
				(c as ObjetVivant).reveiller(true)
			c.freeze = false
			c.global_position = x[1]
			c.linear_velocity = x[2]

## Hôte : un invité projette / tient / lâche un ennemi.
func _sur_ennemi(expediteur: int, id: Variant, d: Variant) -> void:
	var r := _reseau()
	if r == null or not r.est_hote() or not (d is Dictionary):
		return
	var e := CombatCoop.ennemi(String(id)) as CharacterBody3D
	if e == null or not vivant(e):
		return
	match String(d.get("op", "")):
		"projeter", "lacher":
			projeter(e, d.get("v", Vector3.ZERO), _sort("levitation"))
		"tenir":
			var f := _prendre(e, "distant")
			f["cible"] = d.get("p", e.global_position)
			f["t_distant"] = 0.0
