class_name RagdollEsprit
extends Node
## RAGDOLL DE PROJECTION puis RELEVÉ des sorts de l'esprit (Répulsion, Lévitation lâchée ou lancée, relâchement de l'Attraction ;
## docs/MAGIE.md, « Ragdoll de projection »). Un nœud enfant de SortsEsprit (« RagdollEsprit »).
##
##  1. VOL : l'ennemi VIVANT passe en ragdoll physique (Ragdoll.gd, le même que celui des morts) depuis sa pose animée, avec la vitesse de
##     l'onde et un basculement (le haut du corps emporté plus vite que les jambes) ; il vole, tournoie, heurte murs, tonneaux et autres
##     ennemis (chocs de SortsEsprit : dégâts, `recevoir_choc`, ennemi percuté emporté), retombe et glisse (frottement réduit).
##     Son IA, sa gravité et sa capsule sont coupées le temps du vol ; il est « au sol » (CHUTE : pas de titubement si on le frappe).
##  2. REPOS : vitesse de tous les os < 0,6 m/s pendant 0,3 s (au plus tôt 0,7 s, au plus tard 3,2 s après l'impulsion).
##  3. RELEVÉ : sur le dos ou sur le ventre (sens du torse), clip CAPTURÉ Releve_Dos / Releve_Ventre (Mixamo, zombie pack « stand up » et
##     « stand up (3) », outils/zombie_retarget.gd ; aucune pose écrite à la main). Le corps est replacé pour que le bassin de la 1re image
##     du clip tombe sous le bassin du ragdoll (lacet du clip aligné sur l'axe bassin -> tête du corps couché, pieds sur le sol mesuré) ;
##     la pose du ragdoll est capturée puis fondue vers le clip en FONDU s (modificateur FonduPose, après l'animation) : ni saut ni
##     téléportation visibles. Le clip est joué ×VITESSE_RELEVE, puis l'IA reprend (TRAQUE).
##  Mort pendant le vol : le ragdoll continue et devient le cadavre (draugr._mourir réutilise le même Ragdoll).
##  Plafond : PLAFOND ragdolls en vol à la fois ; au-delà (ou ennemi sans squelette humain : troll), le vol cinématique d'avant.
##  Rien ne tourne au repos (process coupé tant qu'aucun corps n'est suivi).
##  Coop : l'hôte simule ; il envoie `es_ragdoll` (vol : vitesse, basculement ; relevé : position, lacet, clip) et chaque invité rejoue
##  un ragdoll local cosmétique (sans dégâts) puis le même relevé à la place que l'hôte a choisie (limite : trajectoires proches, pas
##  identiques ; la place finale est celle de l'hôte).
## `-- --sans-ragdoll-esprit` : comportement d'avant (vol cinématique, chute Death01).

static var actif := not ("--sans-ragdoll-esprit" in OS.get_cmdline_user_args())

const PLAFOND := 6
const CLIP_DOS := "Releve_Dos"
const CLIP_VENTRE := "Releve_Ventre"
const VITESSE_RELEVE := 1.6
const FONDU := 0.3
const TEMPS_MIN := 0.7
const TEMPS_MAX := 2.4
const REPOS_V := 0.35       # m/s : centre du corps
const REPOS_OS := 1.2       # m/s : os le plus rapide (une main qui ballotte encore)
const REPOS_T := 0.2
const FROTTEMENT := 0.45
const ROULIS := 3.0
const TONUS := 0.35
const EV := "es_ragdoll"
const ATTENTE_HOTE := 5.0

var es: SortsEsprit
## instance_id -> fiche du corps suivi (phase "vol" ou "releve")
var corps := {}
## Journal (tests) : un Dictionary par relevé {nom, clip, ventre, t_vol, ...} et par fin {nom, fini, t_total}.
var journal: Array = []
## Profil (--mesure) : étape -> [nombre, total µs, max µs].
static var profil := {}
static func _prof(nom: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	var d: Array = profil.get(nom, [0, 0, 0])
	d[0] += 1
	d[1] += t1 - t0
	d[2] = maxi(d[2], t1 - t0)
	profil[nom] = d
	return t1

func _init(s: SortsEsprit = null) -> void:
	es = s
	name = "RagdollEsprit"

func _ready() -> void:
	set_physics_process(false)
	var r := ReseauProjectiles.reseau()
	if r != null and r.has_method("abonner"):
		r.abonner(EV, _sur_reseau)

## Ennemi à squelette humain (draugr.gd : draugrs, bandits, squelettes) muni des deux relevés capturés ; ni chef ni troll.
static func compatible(e: Node) -> bool:
	if not (e is CharacterBody3D) or not e.has_method("_changer") or not e.has_method("_jouer"):
		return false
	var m: Variant = e.get("modele")
	var a: Variant = e.get("anim")
	if not (m is Node3D) or not (a is AnimationPlayer):
		return false
	if not (a as AnimationPlayer).has_animation(CLIP_DOS) or not (a as AnimationPlayer).has_animation(CLIP_VENTRE):
		return false
	var sq := (m as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null or sq.find_bone("pelvis") < 0 or sq.find_bone("spine_03") < 0 or sq.find_bone("Head") < 0:
		return false
	if SortsEsprit.est_chef(e):
		return false
	var cst: Dictionary = e.get_script().get_script_constant_map()
	return cst.has("TRAQUE") and cst.has("CHUTE")

func contient(e: Variant) -> bool:
	return e != null and is_instance_valid(e) and corps.has((e as Object).get_instance_id())

func en_vol(e: Variant) -> bool:
	return contient(e) and String(corps[(e as Object).get_instance_id()]["phase"]) == "vol"

func phase(e: Variant) -> String:
	return String(corps[(e as Object).get_instance_id()]["phase"]) if contient(e) else ""

func nb_en_vol() -> int:
	var n := 0
	for id in corps:
		if String(corps[id]["phase"]) == "vol":
			n += 1
	return n

func _noter(t: String) -> void:
	if es != null:
		es._noter("ragdoll " + t)

# ====================================================================== VOL

## Projette `e` en ragdoll à la vitesse `v` (m/s). Faux si impossible (interrupteur, pas de squelette humain, plafond) : l'appelant
## garde alors son vol cinématique. Déjà en vol : la nouvelle impulsion s'ajoute. En train de se relever : il repart en ragdoll.
func prendre(e: CharacterBody3D, v: Vector3, s: DonneesSort, cosmetique := false) -> bool:
	if not actif or e == null or not compatible(e):
		return false
	var id := e.get_instance_id()
	var fi: Dictionary = corps.get(id, {})
	if not fi.is_empty() and String(fi["phase"]) == "vol":
		# déjà en l'air : l'impulsion s'ajoute, sans dépasser la plus forte des deux (pas d'emballement entre corps de la même onde)
		var v_avant: Vector3 = _centre_masse(fi["rd"])[1]
		_pousser(fi, v, true)
		var plafond_v := maxf(v.length(), v_avant.length()) * 1.1
		var v_apres: Vector3 = _centre_masse(fi["rd"])[1]
		if v_apres.length() > plafond_v:
			var k := plafond_v / v_apres.length()
			for pb: PhysicalBone3D in (fi["rd"] as Ragdoll).os.values():
				pb.linear_velocity *= k
		fi["sort"] = s
		fi["touches"] = {}
		fi["t_repos"] = 0.0
		fi["t"] = minf(float(fi["t"]), 0.2)
		return true
	if fi.is_empty() and nb_en_vol() >= PLAFOND:
		_noter("plafond atteint (%d) : vol cinématique pour %s" % [PLAFOND, e.name])
		return false
	var modele: Node3D = e.get("modele")
	var tp := Time.get_ticks_usec()
	var rd := Ragdoll.equiper(modele) as Ragdoll
	tp = _prof("prendre_equiper", tp)
	if rd == null:
		return false
	if fi.is_empty():
		var c0: Variant = e.get("combat")
		fi = {"e": e, "rd": rd, "couche": e.collision_layer, "masque": e.collision_mask, "h": SortsEsprit.demi_hauteur(e),
			"p": SortsEsprit.puissance(e), "reaction": c0 is CombatEnnemi and (c0 as CombatEnnemi).reaction_os != null and (c0 as CombatEnnemi).reaction_os.active,
			"t_total": 0.0, "n_vols": 0}
		corps[id] = fi
	else:
		_retirer_fondu(fi)   # relevé interrompu : il repart de la pose où il en est
	fi["phase"] = "vol"
	fi["t"] = 0.0
	fi["t_repos"] = 0.0
	fi["touches"] = {}
	fi["sort"] = s
	fi["cosmetique"] = cosmetique
	fi["n_vols"] = int(fi["n_vols"]) + 1
	fi["y0"] = e.global_position.y
	e.set_physics_process(false)
	e.velocity = Vector3.ZERO
	if e.get("_recul") is Vector3:
		e.set("_recul", Vector3.ZERO)
	e.collision_layer = 0
	e.collision_mask = 0
	var chute := int(e.get_script().get_script_constant_map()["CHUTE"])
	if not cosmetique and int(e.get("etat")) != chute:
		e.call("_changer", chute)
	elif e.has_method("_regler_pieds"):
		e.call("_regler_pieds")
	var c: Variant = e.get("combat")
	if c is CombatEnnemi:
		(c as CombatEnnemi).au_sol = true
		if (c as CombatEnnemi).reaction_os != null:
			(c as CombatEnnemi).reaction_os.active = false
	tp = _prof("prendre_etat", tp)
	if es != null and es.joueur is PhysicsBody3D:
		rd.ignorer(es.joueur)
	rd.declencher(Vector3.ZERO, Vector3.ZERO, "pelvis", Vector3.ZERO, true)   # l'ombre fusionnée reste (skinnée au même squelette)
	tp = _prof("prendre_declencher", tp)
	fi["au_sol"] = false
	for pb: PhysicalBone3D in rd.os.values():
		pb.linear_damp = 0.15
		pb.angular_damp = 3.0
		pb.friction = FROTTEMENT
		pb.can_sleep = false   # un os endormi ne suivrait plus son corps si la racine bouge (coop : position répliquée)
		PhysicsServer3D.body_set_enable_continuous_collision_detection(pb.get_rid(), true)   # main à 17 m/s : pas à travers le mur
	tp = _prof("prendre_ccd_reglages", tp)
	fi["pose_ref"] = _pose_relative(rd)
	_pousser(fi, v, false)
	tp = _prof("prendre_pose_pousser", tp)
	e.set("_anim", "es_ragdoll")
	e.set_meta("es_centre", _centre_masse(rd)[0])
	set_physics_process(true)
	if not cosmetique and not bool(e.get("marionnette")):
		_annoncer(e, {"op": "vol", "v": v, "w": fi.get("w", Vector3.ZERO)})
	_noter("vol %s v=%.1f (%d en vol)" % [e.name, v.length(), nb_en_vol()])
	return true

## Vitesse de tout le corps + basculement : le haut du corps part plus vite que les jambes (rotation autour de l'axe horizontal
## perpendiculaire à la poussée), un peu de vrille. `ajout` : s'ajoute au mouvement en cours (seconde onde).
func _pousser(fi: Dictionary, v: Vector3, ajout: bool, w_impose := Vector3.INF) -> void:
	var rd: Ragdoll = fi["rd"]
	var plat := Vector3(v.x, 0.0, v.z)
	var w := Vector3.ZERO
	if w_impose != Vector3.INF:
		w = w_impose
	elif plat.length() > 0.3:
		var k := clampf(v.length() / 8.0, 0.4, 1.25)
		w = Vector3.UP.cross(plat.normalized()) * ROULIS * k + Vector3.UP * randf_range(-1.2, 1.2) * k
	fi["w"] = w
	var com: Vector3 = _centre_masse(rd)[0]
	for pb: PhysicalBone3D in rd.os.values():
		var vb := v + w.cross(pb.global_position - com)
		if ajout:
			pb.linear_velocity += vb
			pb.angular_velocity += w
		else:
			pb.linear_velocity = vb
			pb.angular_velocity = w

## [centre de masse, vitesse du centre de masse, vitesse du plus rapide des os]
func _centre_masse(rd: Ragdoll) -> Array:
	var com := Vector3.ZERO
	var vc := Vector3.ZERO
	var m := 0.0
	var vmax := 0.0
	for pb: PhysicalBone3D in rd.os.values():
		com += pb.global_position * pb.mass
		vc += pb.linear_velocity * pb.mass
		m += pb.mass
		vmax = maxf(vmax, pb.linear_velocity.length())
	m = maxf(m, 0.001)
	return [com / m, vc / m, vmax]

## Orientation de chaque os physique par rapport à son parent physique, au départ (tonus : le corps garde un peu sa tenue).
func _pose_relative(rd: Ragdoll) -> Dictionary:
	var res := {}
	for nom: String in rd.os:
		var par := String(rd._infos[nom]["parent"])
		if par == "" or not rd.os.has(par):
			continue
		var pb: PhysicalBone3D = rd.os[nom]
		var pp: PhysicalBone3D = rd.os[par]
		res[nom] = (pp.global_basis.get_rotation_quaternion().inverse() * pb.global_basis.get_rotation_quaternion()).normalized()
	return res

## Tonus musculaire : chaque os est ramené doucement vers son orientation de départ par rapport à son parent (le corps ne se désarticule
## pas en vol), de moins en moins à mesure que le vol dure (il s'affaisse en touchant le sol).
func _tonus(fi: Dictionary, dt: float) -> void:
	var rd: Ragdoll = fi["rd"]
	var ref: Dictionary = fi["pose_ref"]
	var k := TONUS * clampf(1.0 - float(fi["t"]) / 1.6, 0.0, 1.0)
	if bool(fi.get("au_sol", false)):
		k *= 0.3
	for nom: String in ref:
		var pb: PhysicalBone3D = rd.os[nom]
		var pp: PhysicalBone3D = rd.os[String(rd._infos[nom]["parent"])]
		var qp := pp.global_basis.get_rotation_quaternion()
		var voulu := (qp * (ref[nom] as Quaternion)).normalized()
		var err := (voulu * pb.global_basis.get_rotation_quaternion().inverse()).normalized()
		if err.w < 0.0:
			err = -err
		var ang := err.get_angle()
		if ang < 0.02:
			continue
		var corr := err.get_axis().normalized() * ang * k / maxf(dt, 0.001) * 0.12
		var rel := pb.angular_velocity - pp.angular_velocity
		pb.angular_velocity = pp.angular_velocity + rel.lerp(corr, clampf(k, 0.0, 1.0))

var _releves_image := 0
## Ennemis dont le ragdoll est à construire d'avance (sort de l'esprit en main), un par image.
var _a_preparer: Array = []

## Construit d'avance le ragdoll (os physiques, en veille : sans collision) des ennemis proches, un par image, pour que l'impulsion ne
## paie pas ~1,7 ms de construction par corps la même image.
func preparer(e: Node) -> void:
	if not actif or not is_instance_valid(e) or _a_preparer.has(e) or contient(e):
		return
	var m: Variant = e.get("modele")
	if not (m is Node3D) or (m as Node3D).get_node_or_null("Ragdoll") != null or not compatible(e):
		return
	_a_preparer.append(e)
	set_physics_process(true)

func _preparer_un() -> void:
	while not _a_preparer.is_empty():
		var e: Variant = _a_preparer.pop_front()
		if not is_instance_valid(e) or not SortsEsprit.vivant(e):
			continue
		var tp := Time.get_ticks_usec()
		var rd := Ragdoll.equiper((e as Node).get("modele")) as Ragdoll
		if rd != null and not rd.actif:
			rd.mettre_en_veille()
		_prof("preparer", tp)
		return

func _physics_process(dt: float) -> void:
	_releves_image = 0
	_preparer_un()
	for id in corps.keys():
		if not corps.has(id):
			continue
		var fi: Dictionary = corps[id]
		if not is_instance_valid(fi["e"]) or not (fi["e"] as Node).is_inside_tree():
			corps.erase(id)
			continue
		var e: CharacterBody3D = fi["e"]
		if not SortsEsprit.vivant(e):
			_mort(fi)
			continue
		fi["t"] = float(fi["t"]) + dt
		fi["t_total"] = float(fi["t_total"]) + dt
		if String(fi["phase"]) == "vol":
			var tv := Time.get_ticks_usec()
			_vol(fi, dt)
			_prof("vol_image", tv)
		else:
			_suivre_releve(fi)
	if corps.is_empty() and _a_preparer.is_empty():
		set_physics_process(false)

func _vol(fi: Dictionary, dt: float) -> void:
	var e: CharacterBody3D = fi["e"]
	var rd: Ragdoll = fi["rd"]
	var cm := _centre_masse(rd)
	var com: Vector3 = cm[0]
	var vc: Vector3 = cm[1]
	e.set_meta("es_centre", com)
	# perf : les balayages (ennemis, objets : 2 images sur 4 en décalé selon le corps ; sol : 1 sur 3) ne tournent pas à chaque image
	var tour := (Engine.get_physics_frames() + e.get_instance_id()) % 12
	if not bool(fi["cosmetique"]):
		var vp: Vector3 = fi.get("v_prec", vc)
		if vp.length() > SortsEsprit.VITESSE_CHOC and (vp - vc).length() > 2.5:
			_choc_decor(fi, com, vp)
		if vc.length() > SortsEsprit.VITESSE_CHOC and tour % 2 == 0:
			_chocs_ennemis(fi, com, vc)
			es._chocs_objets(fi, com, vc)
	fi["v_prec"] = vc
	# au sol (bassin bas, plus de montée) : il glisse puis s'arrête (amorti relevé : il ne roule pas sans fin)
	var pel: Vector3 = (rd.os["pelvis"] as PhysicalBone3D).global_position
	if not bool(fi.get("au_sol", false)) and float(fi["t"]) > 0.35 and vc.y < 1.0 and tour % 3 == 0 and pel.y - _sol(e, pel, pel.y - 0.2) < 0.4:
		fi["au_sol"] = true
		for pb: PhysicalBone3D in rd.os.values():
			pb.linear_damp = 0.9
			pb.angular_damp = 5.0
	_tonus(fi, dt)
	# repos (ou délai dépassé) : il se relève ; l'invité attend le relevé de l'hôte (repli au bout de ATTENTE_HOTE s)
	if float(fi["t"]) > TEMPS_MIN and vc.length() < REPOS_V and float(cm[2]) < REPOS_OS:
		fi["t_repos"] = float(fi["t_repos"]) + dt
	else:
		fi["t_repos"] = 0.0
	var pret := float(fi["t_repos"]) >= REPOS_T or float(fi["t"]) > TEMPS_MAX
	if bool(fi["cosmetique"]):
		pret = float(fi["t"]) > ATTENTE_HOTE
	# filet : corps passé sous le sol (ne devrait pas arriver) -> relevé tout de suite, au-dessus du point de départ
	if com.y < float(fi["y0"]) - 4.0:
		_noter("ECHEC filet : %s sous le sol (y=%.1f)" % [e.name, com.y])
		pret = true
	if pret and _releves_image < 1:
		_releves_image += 1   # perf : un relevé par image (capture + 1re image du clip ~1,5 ms) ; les autres attendent l'image suivante
		relever(fi)

## Perte brutale de vitesse : le corps a heurté quelque chose. Rayon le long de la vitesse d'avant pour savoir quoi (mur, sol, tonneau,
## autre ennemi) ; chocs et dégâts de SortsEsprit (une fois par chose touchée).
func _choc_decor(fi: Dictionary, com: Vector3, vp: Vector3) -> void:
	var e: CharacterBody3D = fi["e"]
	var dir := vp.normalized()
	var q := PhysicsRayQueryParameters3D.create(com - dir * 0.25, com + dir * 1.3, 1 | Cassable.CALQUE)
	var ex: Array[RID] = [e.get_rid()]
	if es.joueur is CollisionObject3D:
		ex.append((es.joueur as CollisionObject3D).get_rid())
	q.exclude = ex
	var r := e.get_world_3d().direct_space_state.intersect_ray(q)
	var n: Vector3
	var point: Vector3
	var autre: Object = null
	if r.is_empty():
		# rien sur l'axe de la vitesse : ce sont les jambes ou la tête qui ont accroché ; la normale est l'opposé de la vitesse
		n = -dir
		point = com + dir * 0.4
	else:
		n = r["normal"]
		point = r["position"]
		autre = r["collider"]
	var vn := -vp.dot(n)
	if n.y > 0.6:
		var touches: Dictionary = fi["touches"]
		if not touches.has("sol"):
			touches["sol"] = true
			if vn > SortsEsprit.VITESSE_CHUTE:
				es._frapper(e, (vn - SortsEsprit.VITESSE_CHUTE) * SortsEsprit.K_CHUTE, point, Vector3.DOWN, 30.0, fi.get("sort"))
			es._effet_choc(point, n, clampf(vn / 10.0, 0.3, 1.2), true)
		return
	if vn > SortsEsprit.VITESSE_CHOC:
		es._choc(fi, autre, point, n, vp, vn)

## Un autre ennemi sur la trajectoire (sa capsule n'arrête pas toujours les os) : les deux encaissent, l'autre est emporté.
func _chocs_ennemis(fi: Dictionary, com: Vector3, v: Vector3) -> void:
	var e: CharacterBody3D = fi["e"]
	for c: CharacterBody3D in es._cibles(com, 1.8):
		if c == e or (fi["touches"] as Dictionary).has(c.get_instance_id()) or en_vol(c):
			continue   # un autre corps en vol : ils partent ensemble de la même onde (ses os ne heurtent pas les nôtres)
		var dc := Elements._centre(c)
		if Vector2(com.x - dc.x, com.z - dc.z).length() < 0.8 and absf(com.y - dc.y) < 1.3:
			var nn := com - dc
			nn.y = 0.0
			es._choc(fi, c, (com + dc) * 0.5, nn.normalized() if nn.length() > 0.01 else -v.normalized(), v, v.length())
			for pb: PhysicalBone3D in (fi["rd"] as Ragdoll).os.values():
				pb.linear_velocity *= 0.6

# ====================================================================== RELEVÉ

## Ordre des os, parents d'abord.
static func _ordre(sq: Skeleton3D) -> Array[int]:
	var res: Array[int] = []
	var pile: Array = Array(sq.get_parentless_bones())
	while not pile.is_empty():
		var i: int = pile.pop_front()
		res.append(i)
		for c in sq.get_bone_children(i):
			pile.append(c)
	return res

## Sol sous `p` (décor, pas les capsules des personnages) ; `defaut` si rien.
func _sol(e: Node3D, p: Vector3, defaut: float) -> float:
	var espace := e.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for essai in 4:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 2.5, 1, ex)
		var r := espace.intersect_ray(q)
		if r.is_empty():
			return defaut
		if r["collider"] is CharacterBody3D:
			ex.append((r["collider"] as CharacterBody3D).get_rid())
			continue
		return (r["position"] as Vector3).y
	return defaut

## Sur le ventre ? (le devant du torse regarde vers le bas)
static func sur_le_ventre(rd: Ragdoll, e: Node3D) -> bool:
	var sq := rd.squelette
	var i := sq.find_bone("spine_03")
	var repos := (sq.global_basis * sq.get_bone_global_rest(i).basis).orthonormalized()
	var devant_local := repos.inverse() * e.global_basis.z.normalized()
	var w: Transform3D = rd.pose_monde("spine_03")
	return (w.basis.orthonormalized() * devant_local).y < 0.0

## Le ragdoll est posé : pose capturée, corps replacé sous le clip de relevé (dos ou ventre), fondu vers le clip. `impose` (coop,
## invité) : {pos, lacet, clip} choisis par l'hôte.
func relever(fi: Dictionary, impose := {}) -> void:
	var e: CharacterBody3D = fi["e"]
	var rd: Ragdoll = fi["rd"]
	var sq := rd.squelette
	var a: AnimationPlayer = e.get("anim")
	var tp := Time.get_ticks_usec()
	var ordre := _ordre(sq)
	var n := sq.get_bone_count()
	# 1. pose affichée (monde) de chaque os : physique = son corps, sinon parent affiché × pose locale animée
	var W: Array[Transform3D] = []
	W.resize(n)
	var G := sq.global_transform
	for i in ordre:
		var pw: Variant = rd.pose_monde(sq.get_bone_name(i))
		if pw != null:
			W[i] = pw
		else:
			var p := sq.get_bone_parent(i)
			W[i] = (W[p] if p >= 0 else G) * sq.get_bone_pose(i)
	var ventre := sur_le_ventre(rd, e)
	var clip := CLIP_VENTRE if ventre else CLIP_DOS
	if impose.has("clip"):
		clip = String(impose["clip"])
		ventre = clip == CLIP_VENTRE
	tp = _prof("releve_capture", tp)
	# 2. fin de la physique, 1re image du clip
	rd.arreter()
	tp = _prof("releve_arreter", tp)
	for pb: PhysicalBone3D in rd.os.values():
		pb.friction = 1.0
		pb.can_sleep = true
		pb.linear_damp = 0.15
		pb.angular_damp = 3.0
		PhysicsServer3D.body_set_enable_continuous_collision_detection(pb.get_rid(), false)
	a.play(clip, 0.0)
	a.seek(0.0, true)
	a.speed_scale = VITESSE_RELEVE
	e.set("_anim", clip)
	tp = _prof("releve_clip_seek", tp)
	var ip := sq.find_bone("pelvis")
	var ih := sq.find_bone("Head")
	var p0 := sq.get_bone_global_pose(ip).origin
	var h0 := sq.get_bone_global_pose(ih).origin
	var K := e.global_transform.affine_inverse() * G
	# 3. place : lacet du clip aligné sur l'axe bassin -> tête du corps couché, bassin du clip sous celui du ragdoll, pieds au sol
	var axe_clip := K.basis * (h0 - p0)
	axe_clip.y = 0.0
	var axe_rd := W[ih].origin - W[ip].origin
	axe_rd.y = 0.0
	var lacet := e.rotation.y
	if axe_clip.length() > 0.15 and axe_rd.length() > 0.15:
		lacet = axe_clip.signed_angle_to(axe_rd, Vector3.UP)
	var B := Basis(Vector3.UP, lacet)
	var pos := W[ip].origin - B * (K * p0)
	pos.y = _sol(e, W[ip].origin, e.global_position.y)
	var decale := 0.0
	if not impose.has("pos"):
		# le relevé finit debout à `pos` (Releve_Ventre : 1,2 m du bassin, côté pieds) : place libre et atteignable depuis le bassin, sinon
		# on rapproche du bassin (le fondu, allongé, absorbe le décalage)
		var vers := W[ip].origin - pos
		vers.y = 0.0
		var d0 := vers.length()
		var k := 0.0
		while k <= d0 + 0.01 and not _place_libre(e, pos + vers.normalized() * k if d0 > 0.01 else pos, W[ip].origin, fi):
			k += 0.1
		if k > 0.0 and d0 > 0.01:
			decale = minf(k, d0)
			pos += vers.normalized() * decale
			pos.y = _sol(e, pos + Vector3.UP * 0.3, pos.y)
	if impose.has("pos"):
		pos = impose["pos"]
		lacet = float(impose["lacet"])
		B = Basis(Vector3.UP, lacet)
	e.global_transform = Transform3D(B, pos)
	tp = _prof("releve_placement", tp)
	var G2 := sq.global_transform
	# 4. poses locales capturées dans le nouveau repère (racines sans os physique : laissées à l'animation)
	var poses := {}
	for i in ordre:
		var p := sq.get_bone_parent(i)
		var physique := rd.os.has(sq.get_bone_name(i))
		var loc: Transform3D
		if p < 0:
			if not physique:
				W[i] = G2 * sq.get_bone_global_pose(i)
				continue
			loc = G2.affine_inverse() * W[i]
		else:
			loc = W[p].affine_inverse() * W[i]
		poses[i] = [loc.origin, loc.basis.orthonormalized().get_rotation_quaternion()]
	var fondu := FonduPose.new()
	fondu.name = "FonduReleve"
	fondu.poses = poses
	fondu.duree = FONDU + clampf(decale, 0.0, 1.2) * 0.3   # place décalée (mur) : fondu un peu plus long, le corps glisse au lieu de sauter
	sq.add_child(fondu)
	tp = _prof("releve_poses_fondu", tp)
	fi["fondu"] = fondu
	fi["phase"] = "releve"
	fi["clip"] = clip
	fi["t_vol"] = fi["t"]
	fi["t"] = 0.0
	fi["duree"] = a.get_animation(clip).length / VITESSE_RELEVE
	e.collision_layer = int(fi["couche"])   # on le heurte (et on le frappe) pendant qu'il se relève
	e.remove_meta("es_centre")
	journal.append({"nom": String(e.name), "e": e, "clip": clip, "ventre": ventre, "t_vol": float(fi["t_vol"]), "pos": pos,
		"bassin_rd": W[ip].origin, "decale": decale})
	if not bool(fi["cosmetique"]) and not bool(e.get("marionnette")):
		_annoncer(e, {"op": "releve", "pos": pos, "lacet": lacet, "clip": clip})
	_noter("relevé %s : %s (vol %.2f s)" % [e.name, clip, float(fi["t_vol"])])

## La capsule tient debout à `pos` (rien du décor dedans) et on y va depuis le bassin couché sans traverser de mur.
func _place_libre(e: CharacterBody3D, pos: Vector3, bassin: Vector3, fi: Dictionary) -> bool:
	var espace := e.get_world_3d().direct_space_state
	var ex: Array[RID] = [e.get_rid()]
	if es.joueur is CollisionObject3D:
		ex.append((es.joueur as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(bassin + Vector3.UP * 0.35, pos + Vector3.UP * 0.6, 1, ex)
	var r := espace.intersect_ray(q)
	if not r.is_empty() and not (r["collider"] is CharacterBody3D):
		return false
	var forme := CapsuleShape3D.new()
	forme.radius = 0.3
	forme.height = 1.5
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = forme
	qs.transform = Transform3D(Basis(), pos + Vector3.UP * 0.9)
	qs.collision_mask = 1
	qs.exclude = ex
	for h in espace.intersect_shape(qs, 4):
		if not (h["collider"] is CharacterBody3D):
			return false
	return true

func _suivre_releve(fi: Dictionary) -> void:
	var a: AnimationPlayer = (fi["e"] as Node).get("anim")
	if a != null and String(a.current_animation) == String(fi["clip"]):
		a.speed_scale = VITESSE_RELEVE
	if float(fi["t"]) >= float(fi["duree"]) * 0.97:
		_finir(fi)

## Debout : l'IA reprend (TRAQUE), capsule et pieds rendus.
func _finir(fi: Dictionary) -> void:
	var e: CharacterBody3D = fi["e"]
	var tp := Time.get_ticks_usec()
	_retirer_fondu(fi)
	corps.erase(e.get_instance_id())
	_rendre_etat(fi)
	tp = _prof("finir_etat", tp)
	var a: AnimationPlayer = e.get("anim")
	if a != null:
		a.speed_scale = 1.0
	if not bool(e.get("marionnette")):
		var cst: Dictionary = e.get_script().get_script_constant_map()
		e.call("_changer", int(cst["TRAQUE"]))
		e.call("_jouer", "Sword_Idle", 0.45)   # sans « forcer » : stop() ramènerait le relevé à sa 1re image (couché) le temps du fondu
		if e.get("_recharge") != null:
			e.set("_recharge", 0.5)
	elif e.has_method("_regler_pieds"):
		e.call("_regler_pieds")
	var pieds: Variant = e.get("_pieds")
	if pieds is PiedsAuSol and is_instance_valid(pieds):
		(pieds as PiedsAuSol)._decal = [0.0, 0.0]   # décalages d'avant le vol (autre sol, soulevé) : périmés
	e.set_physics_process(true)
	_prof("finir_ia", tp)
	journal.append({"nom": String(e.name), "e": e, "fini": true, "t_total": float(fi["t_total"])})
	_noter("debout %s (%.2f s en tout)" % [e.name, float(fi["t_total"])])

func _rendre_etat(fi: Dictionary) -> void:
	var e: CharacterBody3D = fi["e"]
	e.collision_layer = int(fi["couche"])
	e.collision_mask = int(fi["masque"])
	if e.has_meta("es_centre"):
		e.remove_meta("es_centre")
	var c: Variant = e.get("combat")
	if c is CombatEnnemi:
		(c as CombatEnnemi).au_sol = false
		if (c as CombatEnnemi).reaction_os != null:
			(c as CombatEnnemi).reaction_os.active = bool(fi["reaction"])
	if es != null and es.joueur is PhysicsBody3D:
		e.remove_collision_exception_with(es.joueur)
	var m: Variant = e.get("modele")
	if m is Node3D and (m as Node3D).find_child("OmbreFusion", true, false) == null:
		_ombre.call_deferred(m)   # ombre défaite (démembrement…) : refusionnée

static func _ombre(m: Node3D) -> void:
	var tp := Time.get_ticks_usec()
	if is_instance_valid(m):
		FusionOmbre.equiper(m)
	_prof("ombre_refusion", tp)

func _retirer_fondu(fi: Dictionary) -> void:
	if not is_instance_valid(fi.get("fondu")):
		fi.erase("fondu")
		return
	var f: Variant = fi.get("fondu")
	if f != null:
		(f as Node).get_parent().remove_child(f)
		(f as Node).queue_free()
	fi.erase("fondu")

## Mort pendant le vol ou le relevé : le ragdoll (celui de draugr._mourir) reste, c'est le cadavre.
func _mort(fi: Dictionary) -> void:
	var e: CharacterBody3D = fi["e"]
	_retirer_fondu(fi)
	corps.erase(e.get_instance_id())
	var rd: Ragdoll = fi["rd"]
	for pb: PhysicalBone3D in rd.os.values():
		pb.friction = 1.0
		pb.can_sleep = true
		pb.linear_damp = 0.15
		pb.angular_damp = 3.0
		PhysicsServer3D.body_set_enable_continuous_collision_detection(pb.get_rid(), false)
	if e.has_meta("es_centre"):
		e.remove_meta("es_centre")
	e.set_physics_process(true)   # cycle du cadavre (draugr : MORT, fouille, disparition)
	journal.append({"nom": String(e.name), "e": e, "mort": true, "phase": String(fi["phase"])})
	_noter("mort en %s : %s reste en ragdoll (cadavre)" % [String(fi["phase"]), e.name])

## Un autre sort reprend l'ennemi (lévitation, vortex) : on le lâche tel quel.
func abandonner(e: Node) -> void:
	if not contient(e):
		return
	var fi: Dictionary = corps[e.get_instance_id()]
	_retirer_fondu(fi)
	corps.erase(e.get_instance_id())
	if String(fi["phase"]) == "vol":
		(fi["rd"] as Ragdoll).arreter()
	for pb: PhysicalBone3D in (fi["rd"] as Ragdoll).os.values():
		pb.friction = 1.0
		pb.can_sleep = true
		pb.linear_damp = 0.15
		pb.angular_damp = 3.0
		PhysicsServer3D.body_set_enable_continuous_collision_detection(pb.get_rid(), false)
	_rendre_etat(fi)

func _exit_tree() -> void:
	for id in corps.keys():
		var fi: Dictionary = corps[id]
		if is_instance_valid(fi["e"]) and is_instance_valid(fi.get("fondu")):
			_retirer_fondu(fi)
	corps.clear()

# ====================================================================== coop

func _annoncer(e: Node, d: Dictionary) -> void:
	if es == null or not e.has_meta("coop_id"):
		return
	es._envoyer(EV, String(e.get_meta("coop_id")), d)

## Invité : l'hôte a projeté (ragdoll local cosmétique, sans dégâts) ou relevé (même place, même clip) un ennemi.
func _sur_reseau(_expediteur: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var e := CombatCoop.ennemi(String(id)) as CharacterBody3D
	if e == null or not SortsEsprit.vivant(e) or not bool(e.get("marionnette")):
		return
	match String(d.get("op", "")):
		"vol":
			if prendre(e, d.get("v", Vector3.ZERO), null, true) and d.has("w"):
				_pousser(corps[e.get_instance_id()], d.get("v", Vector3.ZERO), false, d["w"])
		"releve":
			if contient(e) and phase(e) == "vol":
				relever(corps[e.get_instance_id()], d)

# ====================================================================== fondu ragdoll -> clip

## Modificateur de squelette (après l'animation) : part de la pose capturée du ragdoll et rejoint l'animation en `duree` s.
class FonduPose extends SkeletonModifier3D:
	var poses := {}
	var duree := 0.3
	var t := 0.0

	func _process_modification_with_delta(delta: float) -> void:
		var sq := get_skeleton()
		if sq == null:
			return
		t += delta
		var u := smoothstep(0.0, 1.0, clampf(t / maxf(duree, 0.01), 0.0, 1.0))
		if u >= 1.0:
			return
		for i: int in poses:
			var c: Array = poses[i]
			sq.set_bone_pose_rotation(i, (c[1] as Quaternion).slerp(sq.get_bone_pose_rotation(i), u))
			sq.set_bone_pose_position(i, (c[0] as Vector3).lerp(sq.get_bone_pose_position(i), u))
