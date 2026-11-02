class_name CorpsMainsTps
extends Node
## MAINS DU CORPS à la 3e personne (branche tps/mains_sorts) : le corps visible (corps_joueur.gd) montre EXACTEMENT ce que tient chaque
## main à la 1re personne (EquipementMains, data/magie/regles_mains.json) — arme (vrai modèle de l'arme équipée), arme à deux mains,
## torche, bouclier, sort, main nue — et joue de vrais gestes d'incantation.
##
## Branchements (minimaux, dans corps_joueur.gd) : `mains_tps.installer(squelette)` à la création du modèle, `mains_tps.avancer(dt, vue_3)`
## chaque image, `torche_tenue()` (au lieu de mains.torche_sortie, VRAI aussi quand la main gauche tient un sort ou un bouclier :
## c'était la cause de « il garde la torche en main quand il lance des sorts ») et `clip_repos()` (attente sans épée = « Idle »).
## Dans main_sort.gd : `definir_paumes_effets` — à la 3e personne auras, runes, jets et projectiles partent des paumes du CORPS.
##
## Gestes : une COUCHE PAR BRAS (CoucheBras, SkeletonModifier3D après l'AnimationPlayer) remplace la chaîne clavicule → doigts du bras
## concerné par un clip capturé, le reste du corps garde la locomotion (marche, course, saut, coups d'épée de l'autre bras) :
##   - repos, sort en main    : Spell_Simple_Enter (Quaternius UAL1, CC0) figé main ouverte devant la hanche, lueur dans la paume ;
##   - incantation / charge   : Sort_Lancer1M (Mixamo « Standing 1H Magic Attack 01 ») — la main recule, paume ouverte, pendant la charge ;
##   - lancer (rapide/chargé) : suite du même clip, bras projeté vers l'avant puis retour ;
##   - jet continu (canalisé) : Sort_Jet2M (Mixamo « Standing 2H Magic Attack 03 ») bras tendu, tenu tant que le jet dure ;
##   - zone                   : Sort_Zone2M (Mixamo « Standing 2H Magic Area Attack 01 ») ;  enchantement : Spell_Simple_Shoot ;
##   - double incantation     : les deux mains suivent le même état, donc les deux bras font le geste (double jet : Sort_Souffle2M) ;
##   - torche                 : bras gauche de Idle_Torch (Quaternius) sur toute la locomotion (bras levé, flamme visible) ;
##   - bouclier               : même bras levé que la torche (les tenues Mixamo « sword and shield » le mettaient de chant) ;
##   - arme à deux mains      : Tenue_DeuxMains (Mixamo « great sword idle ») sur les deux bras + IK de la main gauche sur la poignée.
## La couche aligne l'orientation des os du bras dans le repère du PERSONNAGE (pas du buste) et la tourne vers la visée (lacet du corps
## en pas de côté, tangage de la tête) pendant la charge, le jet et le lancer. Clips : assets/modeles/humains/animations_sorts_tps.res
## (outils/zombie_retarget.gd --source=sorts_tps_mixamo.json puis outils/miroir_clips_tps.gd ; « _G » = miroir main gauche des clips
## Mixamo, « _D » = miroir main droite des Spell_Simple, qui sont de la main gauche).

const SORTS := preload("res://assets/modeles/humains/animations_sorts_tps.res")
## Prise de la main droite du corps (la même que corps_joueur.PRISE) : le modèle de l'arme y est décalé de son milieu de poignée.
const PRISE_D := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))
## Instants clés des clips (s), mesurés sur les positions des mains (outils de la branche) :
const LANCER_DEBUT := 0.19     # Sort_Lancer1M : main encore devant
const LANCER_ARME := 0.48      # main reculée au plus loin, paume ouverte (pose de charge)
const LANCER_DEPART := 0.62    # départ de la projection (le sort part au relâchement : on saute l'élan)
const LANCER_TENDU := 1.30     # bras tendu au bout du geste
const VITESSE_LANCER := 1.8
const JET_TENDU := 1.25        # Sort_Jet2M : bras tendus, tenus de 1,25 à 3,1 s
const JET_FIN := 3.10
const ZONE_HAUT := 0.99        # Sort_Zone2M : bras levés (charge) ; frappe vers le sol ~1,3 s
const ZONE_FIN := 2.0
const REPOS_SORT := 0.30       # Spell_Simple_Enter : main ouverte devant la hanche, écartée du corps (lueur visible de derrière)
const SOUFFLE_TENDU := 1.1     # Sort_Souffle2M (Mixamo « Standing 2H Magic Attack 04 ») : deux bras tendus de 1,1 à 2,6 s (double jet)
const SOUFFLE_FIN := 2.6

var corps: Node3D
var joueur: CharacterBody3D
var mains: Node3D
var sq: Skeleton3D
var couche: CoucheBras
## Paumes du corps (effets de magie à la 3e personne) et accroches des mains.
var paume := {"gauche": null, "droite": null}
var _accroche := {"gauche": null, "droite": null}
var _arme_d: Node3D          # copie du modèle de l'arme de la main droite (mains._modele_arme_d)
var _source_d: Node3D
var _objet_g: Node3D         # copie du bouclier tenu (mains._modele_gauche)
var _source_g: Node3D
## Arme à deux mains : la main gauche sur la poignée, sous la main droite (IK à deux os + orientation du poignet, comme à la 1re personne).
var _ik_g: TwoBoneIK3D
var _orient_g: SkeletonModifier3D
var _cible_g: Node3D      # repère voulu pour la main gauche (enfant de l'arme du corps)
var _pole_g: Node3D
var _vue_effets := -1
var _enchant_ecole := ""
var _t := 0.0

## Accroches, paumes et couche des bras sur le squelette du modèle (rappelé à la résurrection : modèle neuf).
func installer(squelette: Skeleton3D) -> void:
	sq = squelette
	_source_d = null
	_source_g = null
	_arme_d = null
	_objet_g = null
	_vue_effets = -1
	_enchant_ecole = ""
	for m in ["gauche", "droite"]:
		var c := "l" if m == "gauche" else "r"
		var a := BoneAttachment3D.new()
		a.name = "MainTps_" + m
		a.bone_name = "hand_" + c
		sq.add_child(a)
		_accroche[m] = a
		var p := Node3D.new()
		p.name = "PaumeTps_" + m
		p.position = _centre_paume(c)
		a.add_child(p)
		paume[m] = p
	couche = CoucheBras.new()
	couche.name = "CoucheBrasTps"
	sq.add_child(couche)
	couche.preparer(sq)
	# deux mains : IK du bras gauche (éteinte sinon), cible posée sur la poignée de l'arme du corps
	_cible_g = Node3D.new()
	_cible_g.name = "CibleMainG2M"
	_pole_g = Node3D.new()
	_pole_g.name = "CoudeG2M"
	_pole_g.position = Vector3(0.55, 0.85, 0.05)   # repère du modèle (regarde +Z, gauche = +X) : coude en dehors et bas
	corps.get("modele").add_child(_pole_g)
	sq.add_child(_cible_g)
	_ik_g = TwoBoneIK3D.new()
	_ik_g.name = "IKMainG2M"
	sq.add_child(_ik_g)
	_ik_g.set_setting_count(1)
	_ik_g.set_root_bone_name(0, "upperarm_l")
	_ik_g.set_middle_bone_name(0, "lowerarm_l")
	_ik_g.set_end_bone_name(0, "hand_l")
	_ik_g.set_target_node(0, _ik_g.get_path_to(_cible_g))
	_ik_g.set_pole_node(0, _ik_g.get_path_to(_pole_g))
	_ik_g.active = false
	_orient_g = SkeletonModifier3D.new()
	_orient_g.set_script(preload("res://scripts/orientation_main.gd"))
	_orient_g.name = "OrientMainG2M"
	_orient_g.set("os", "hand_l")
	_orient_g.set("cible", _cible_g)
	var pivot = corps.get("pivot_torche")
	_orient_g.set("prise", (pivot as Node3D).transform if pivot is Node3D else Transform3D())
	sq.add_child(_orient_g)
	_orient_g.active = false

## Centre de la paume dans le repère de l'os de la main : entre le poignet et la base du majeur, un peu vers l'intérieur de la main.
func _centre_paume(c: String) -> Vector3:
	var i := sq.find_bone("hand_" + c)
	var j := sq.find_bone("middle_01_" + c)
	if i < 0 or j < 0:
		return Vector3(0, 0.08, 0)
	var main := sq.get_bone_global_rest(i)
	var milieu := main.affine_inverse() * sq.get_bone_global_rest(j).origin
	return milieu * 0.7

func _magie() -> Node:
	return mains.get("magie") if mains != null else null

## Catégorie de ce que tient la main `m` (vide, arme, arme_deux_mains, sort, bouclier, torche), comme à la 1re personne.
func categorie(m: String) -> String:
	var mg := _magie()
	if mg != null and mg.eq != null:
		return mg.eq.categorie(m)
	var eqp = mains.get("equipement") if mains != null else null
	if eqp == null:
		return "vide"
	return EquipementMains.categorie_de(eqp.main_droite if m == "droite" else eqp.main_gauche)

## La torche est tenue (et allumée) seulement si la main gauche tient LA TORCHE (pas un sort, pas un bouclier).
func torche_tenue() -> bool:
	return categorie("gauche") == "torche"

## Attente sur place : garde d'épée seulement si la main droite tient une arme.
func clip_repos() -> String:
	return "Sword_Idle" if categorie("droite").begins_with("arme") else "Idle"

## Arme du corps (copie du modèle tenu à la 1re personne) ou null.
func arme_tenue() -> Node3D:
	return _arme_d

func avancer(dt: float, vue_3: bool) -> void:
	if sq == null or mains == null:
		return
	_t += dt
	_maj_arme_d()
	_maj_objet_g()
	_maj_deux_mains()
	_maj_effets(vue_3)
	var mort: bool = joueur.mort
	couche.active = not mort
	if mort:
		couche.oublier()
		return
	for m in ["gauche", "droite"]:
		_geste(m, dt)
	couche.visee = _visee()

# ------------------------------------------------------------------ objets tenus

## Copie « maillages seuls » d'un modèle tenu à la 1re personne (mêmes maillages et matériaux, ombres portées) : pas de scripts
## (sang de lame, traînée…) dupliqués.
static func _copie(source: Node3D) -> Node3D:
	var r := Node3D.new()
	r.name = "Copie_" + source.name
	for mi: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var c := MeshInstance3D.new()
		c.mesh = mi.mesh
		for k in mi.get_surface_override_material_count():
			c.set_surface_override_material(k, mi.get_surface_override_material(k))
		c.material_overlay = mi.material_overlay
		var t := Transform3D()
		var n: Node = mi
		while n != source and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		c.transform = t
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		r.add_child(c)
	return r

func _maj_arme_d() -> void:
	var cat := categorie("droite")
	var src: Node3D = mains.get("_modele_arme_d") if cat.begins_with("arme") else null
	if src != null and not is_instance_valid(src):
		src = null
	var ancienne = corps.get("arme_corps")   # épée fixe d'avant (epee_nordique.glb) : remplacée par le vrai modèle
	if ancienne is Node3D and is_instance_valid(ancienne):
		(ancienne as Node3D).visible = false
	if src == _source_d:
		return
	_source_d = src
	if _arme_d != null and is_instance_valid(_arme_d):
		_arme_d.queue_free()
	_arme_d = null
	_enchant_ecole = ""
	if src == null:
		return
	_arme_d = _copie(src)
	_arme_d.name = "ArmeTps"
	_accroche["droite"].add_child(_arme_d)
	_arme_d.transform = PRISE_D * Transform3D(Basis(), Vector3(0.0, -float(mains.get("_milieu_d")), 0.0))

## Arme à deux mains : main gauche sous la droite (à `ecart_mains` vers le pommeau), même sens de fusée.
func _maj_deux_mains() -> void:
	var oui: bool = categorie("droite") == "arme_deux_mains" and _arme_d != null and not joueur.mort
	_ik_g.active = oui
	_orient_g.active = oui
	if not oui:
		return
	var a: DonneesArme = mains.get("arme")
	var milieu := float(mains.get("_milieu_d"))
	var y := milieu - (a.ecart_mains if a != null else 0.1)
	var pivot = corps.get("pivot_torche")
	var prise_g: Transform3D = (pivot as Node3D).transform if pivot is Node3D else Transform3D()
	_cible_g.global_transform = _arme_d.global_transform * Transform3D(Basis(), Vector3(0, y, 0)) * prise_g.affine_inverse()

func _maj_objet_g() -> void:
	var src: Node3D = mains.get("_modele_gauche") if categorie("gauche") == "bouclier" else null
	if src != null and not is_instance_valid(src):
		src = null
	if src == _source_g:
		return
	_source_g = src
	if _objet_g != null and is_instance_valid(_objet_g):
		_objet_g.queue_free()
	_objet_g = null
	if src == null:
		return
	_objet_g = _copie(src)
	_objet_g.name = "BouclierTps"
	var pivot = corps.get("pivot_torche")   # même prise au poing gauche que la torche (corps_joueur._prise_gauche)
	_accroche["gauche"].add_child(_objet_g)
	var g = mains.get("equipement")
	var milieu: float = g.gauche_rangee.milieu_poignee if g != null else 0.0
	_objet_g.transform = ((pivot as Node3D).transform if pivot is Node3D else Transform3D()) * Transform3D(Basis(), Vector3(0, -milieu, 0))

## Effets de magie : depuis les paumes du corps à la 3e personne, depuis les mains FPS sinon. Enchantement de lame recopié sur l'arme du corps.
func _maj_effets(vue_3: bool) -> void:
	var mg := _magie()
	if mg == null:
		return
	var v := 1 if vue_3 else 0
	if v != _vue_effets:
		_vue_effets = v
		if vue_3:
			mg.definir_paumes_effets(paume["gauche"], paume["droite"])
		else:
			mg.definir_paumes_effets(null, null)
	var ench: Dictionary = mg.enchantement_actif() if mg.has_method("enchantement_actif") else {}
	var ecole := ""
	if not ench.is_empty() and _arme_d != null and vue_3:
		ecole = (ench["sort"] as DonneesSort).ecole
	if ecole != _enchant_ecole and _arme_d != null and not EffetsMagie.muet:
		var g := GestionMagie.obtenir()
		g.enchant_arme(_arme_d, _enchant_ecole if ecole == "" else ecole, ecole != "")
	_enchant_ecole = ecole

# ------------------------------------------------------------------ gestes des bras

## Nom du clip pour la main `m` : clips Mixamo de la main droite (miroir « _G »), Spell_Simple de la main gauche (miroir « _D »).
static func _clip_mixamo(base: String, m: String) -> String:
	return base + ("_G" if m == "gauche" else "")

static func _clip_simple(base: String, m: String) -> String:
	return base + ("_D" if m == "droite" else "")

func _anim(nom: String) -> Animation:
	if SORTS.has_animation(nom):
		return SORTS.get_animation(nom)
	var b := Humain.bibliotheque()
	return b.get_animation(nom) if b.has_animation(nom) else null

## Pose voulue du bras `m` : clip, instant, poids, vivacité du fondu, visée.
func _geste(m: String, _dt: float) -> void:
	var cat := categorie(m)
	var bouge := Vector2(joueur.velocity.x, joueur.velocity.z).length() > 0.4
	var frappe: bool = mains.combat.attaque()
	if categorie("droite") == "arme_deux_mains":
		# arme à deux mains : les deux bras dans la tenue « great sword idle » (Mixamo), la main gauche finit sur la poignée (IK) ;
		# pendant un coup, le clip de coup du corps entier reprend la main (branche des coups)
		var t2 := _anim("Tenue_DeuxMains")
		couche.regler(m, t2, fposmod(_t, t2.length), 0.0 if frappe else 1.0, 10.0, false)
		return
	match cat:
		"sort":
			_geste_sort(m, bouge)
		"torche":
			# bras gauche levé (Idle_Torch, Quaternius) pendant toute la locomotion ; s'écarte un peu pendant un coup d'épée (contrepoids)
			var a := _anim("Idle_Torch")
			couche.regler(m, a, fposmod(_t, a.length), 0.7 if frappe else 1.0, 12.0, false)
		"bouclier":
			# bouclier tenu au poing comme la torche (avant-bras levé, Idle_Torch) : la prise au poing du bouclier (mains.gd) le présente
			# face à l'avant dans cette pose ; les tenues Mixamo « sword and shield » le mettaient de chant (bouclier sanglé à l'avant-bras).
			# En garde : pose de garde du corps entier (Sword_Attack figé, corps_joueur).
			var garde: bool = mains.get("bloque")
			var b2 := _anim("Idle_Torch")
			couche.regler(m, b2, fposmod(_t, b2.length), 0.0 if garde else 1.0, 12.0, false)
		_:
			couche.regler(m, null, 0.0, 0.0, 10.0, false)

func _geste_sort(m: String, bouge: bool) -> void:
	var mg := _magie()
	var i: Incantation = mg.inc[m]
	var s: DonneesSort = mg.eq.sort(m)
	if s == null:
		couche.regler(m, null, 0.0, 0.0, 10.0, false)
		return
	var zone := s.type == DonneesSort.Type.ZONE
	var ench := s.type == DonneesSort.Type.ENCHANT
	var lancer := _anim(_clip_mixamo("Sort_Lancer1M", m))
	match i.etat:
		Incantation.INCANTE, Incantation.CHARGE:
			var k := clampf(i.t / maxf(s.incantation, 0.01), 0.0, 1.0)
			if i.etat == Incantation.CHARGE:
				k = 1.0
			if s.canalise():
				# droit vers le bras tendu (le lissage fait la montée) : l'entrée capturée balance d'abord les bras en arrière
				var jet := _anim(_clip_mixamo("Sort_Jet2M", m))
				couche.regler(m, jet, JET_TENDU, 1.0, 10.0, true)
			elif zone:
				var z := _anim(_clip_mixamo("Sort_Zone2M", m))
				couche.regler(m, z, lerpf(0.0, ZONE_HAUT, 0.5 * k + 0.5 * i.charge), 1.0, 14.0, false)
			elif ench:
				var e := _anim(_clip_simple("Spell_Simple_Enter", m))
				couche.regler(m, e, e.length * k, 1.0, 14.0, true)
			else:
				# la main recule paume ouverte pendant l'incantation puis la charge (tremble un peu à pleine charge)
				var p := 0.45 * k + (0.55 * i.charge if i.etat == Incantation.CHARGE else 0.0)
				var t := lerpf(LANCER_DEBUT, LANCER_ARME, p)
				if i.charge >= 1.0:
					t += sin(_t * 40.0) * 0.008
				couche.regler(m, lancer, t, 1.0, 14.0, true)
		Incantation.CANALISE:
			if i.double:   # double jet : les deux bras tendus, mains rapprochées (capture à deux mains)
				var so := _anim(_clip_mixamo("Sort_Souffle2M", m))
				couche.regler(m, so, SOUFFLE_TENDU + pingpong(maxf(i.t, 0.0) * 0.35, SOUFFLE_FIN - SOUFFLE_TENDU), 1.0, 16.0, true)
				return
			var jet := _anim(_clip_mixamo("Sort_Jet2M", m))
			var duree := JET_FIN - JET_TENDU
			var u := pingpong(maxf(i.t, 0.0) * 0.35, duree)
			couche.regler(m, jet, JET_TENDU + u, 1.0, 16.0, true)
		_:
			# après un départ : projection (ou frappe de zone, ou geste d'enchantement), puis retour à la pose de repos
			var d := i.depuis_lancement
			if i.etat == Incantation.RECUPERATION and d < 0.9 and not i.interrompue:
				if zone:
					var z := _anim(_clip_mixamo("Sort_Zone2M", m))
					couche.regler(m, z, minf(ZONE_HAUT + d * 1.6, ZONE_FIN), 1.0, 22.0, false)
					return
				if ench:
					var e := _anim(_clip_simple("Spell_Simple_Shoot", m))
					couche.regler(m, e, minf(d, e.length), 1.0, 18.0, false)
					return
				if not s.canalise():
					couche.regler(m, lancer, minf(LANCER_DEPART + d * VITESSE_LANCER, LANCER_TENDU), 1.0, 30.0, true)
					return
			var r := _anim(_clip_simple("Spell_Simple_Enter", m))
			couche.regler(m, r, REPOS_SORT, 0.75 if bouge else 0.9, 8.0, false)

## Rotation de visée (repère du squelette) : le bras qui incante vise où regarde la caméra, même quand le corps se tourne vers la marche
## (pas de côté : corps_joueur._lacet) ; tangage de la tête borné (la capture vise à l'horizontale).
func _visee() -> Basis:
	var lacet: float = corps.get("_lacet")
	var tangage: float = clampf(joueur.tete.rotation.x, deg_to_rad(-35.0), deg_to_rad(40.0))
	var inv := sq.global_basis.orthonormalized().inverse()
	var haut := (inv * Vector3.UP).normalized()
	var cote := (inv * joueur.global_basis.x).normalized()
	return Basis(haut, -lacet) * Basis(cote, tangage)

# ======================================================================== couche par bras

## Remplace la chaîne d'un bras (clavicule → doigts) par la pose d'un clip, fondue avec la pose déjà posée par l'AnimationPlayer.
## Clavicule, bras, avant-bras, main : orientation dans le repère du SQUELETTE (celle du clip, indépendante du buste de la locomotion),
## tournée par `visee` si demandé ; doigts et os de torsion : rotation locale du clip. Lissage exponentiel de la pose écrite (fondus
## entre clips et avec la locomotion sans saut) ; quand le poids retombe à 0 et que le bras a rejoint la locomotion, plus rien n'est écrit.
class CoucheBras extends SkeletonModifier3D:
	var visee := Basis()
	var _sq: Skeleton3D
	var _chaines := {}      # côté -> os du bras, parents d'abord
	var _orientes := {}     # côté -> os orientés dans le repère du squelette (clavicule, bras, avant-bras, main)
	var _ancetres := {}     # côté -> racine … main (calcul des orientations du clip)
	var _reglage := {"gauche": {}, "droite": {}}
	var _lisse := {"gauche": {}, "droite": {}}
	var _pistes := {}       # Animation -> {os: piste}

	func preparer(s: Skeleton3D) -> void:
		_sq = s
		for m in ["gauche", "droite"]:
			var c := "l" if m == "gauche" else "r"
			var clav := s.find_bone("clavicle_" + c)
			var chaine: Array[int] = []
			if clav >= 0:
				chaine.append(clav)
				var k := 0
				while k < chaine.size():
					for e in s.get_bone_children(chaine[k]):
						chaine.append(e)
					k += 1
			_chaines[m] = chaine
			var orientes := {}
			for n in ["clavicle_", "upperarm_", "lowerarm_", "hand_"]:
				var i := s.find_bone(n + c)
				if i >= 0:
					orientes[i] = n != "clavicle_"   # vrai : tourné par la visée
			_orientes[m] = orientes
			var anc: Array[int] = []
			var j := s.find_bone("hand_" + c)
			while j >= 0:
				anc.push_front(j)
				j = s.get_bone_parent(j)
			_ancetres[m] = anc

	func regler(m: String, a: Animation, t: float, w: float, vif: float, viser: bool) -> void:
		_reglage[m] = {"a": a, "t": t, "w": w if a != null else 0.0, "vif": vif, "viser": viser}

	func oublier() -> void:
		_lisse = {"gauche": {}, "droite": {}}
		for m in ["gauche", "droite"]:
			_reglage[m] = {}

	func _piste(a: Animation, os: int) -> int:
		if not _pistes.has(a):
			var d := {}
			for t in a.get_track_count():
				if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					var i := _sq.find_bone(String(a.track_get_path(t)).get_slice(":", 1))
					if i >= 0:
						d[i] = t
			_pistes[a] = d
		return int(_pistes[a].get(os, -1))

	func _locale(a: Animation, t: float, os: int) -> Quaternion:
		var p := _piste(a, os)
		if p < 0:
			return _sq.get_bone_rest(os).basis.get_rotation_quaternion()
		return a.rotation_track_interpolate(p, t)

	func _global_actuel(os: int) -> Basis:
		var b := Basis()
		var i := os
		while i >= 0:
			b = Basis(_sq.get_bone_pose_rotation(i)) * b
			i = _sq.get_bone_parent(i)
		return b

	func _process_modification_with_delta(dt: float) -> void:
		if _sq == null:
			return
		for m in ["gauche", "droite"]:
			var r: Dictionary = _reglage[m]
			var lisse: Dictionary = _lisse[m]
			var w: float = r.get("w", 0.0)
			if w <= 0.0 and lisse.is_empty():
				continue
			var a: Animation = r.get("a")
			var t: float = r.get("t", 0.0)
			var k := 1.0 - exp(-float(r.get("vif", 10.0)) * dt)
			# orientations du clip (repère du squelette) de la racine à la main
			var g_clip := {}
			if a != null:
				var g := Basis()
				for i in _ancetres[m]:
					g = g * Basis(_locale(a, t, i))
					g_clip[i] = g
			var ecart := 0.0
			var orientes: Dictionary = _orientes[m]
			for i in _chaines[m]:
				var base := _sq.get_bone_pose_rotation(i)
				var cible := base
				if a != null and w > 0.0:
					var voulue: Quaternion
					if orientes.has(i) and g_clip.has(i):
						var gv: Basis = g_clip[i]
						if orientes[i] and r.get("viser", false):
							gv = visee * gv
						var parent := _global_actuel(_sq.get_bone_parent(i))
						voulue = (parent.inverse() * gv).get_rotation_quaternion()
					else:
						voulue = _locale(a, t, i)
					cible = base.slerp(voulue.normalized(), w)
				var q: Quaternion = lisse.get(i, base)
				q = q.slerp(cible, k).normalized()
				ecart = maxf(ecart, q.angle_to(base))
				lisse[i] = q
				_sq.set_bone_pose_rotation(i, q)
			if w <= 0.0 and ecart < 0.01:
				lisse.clear()
