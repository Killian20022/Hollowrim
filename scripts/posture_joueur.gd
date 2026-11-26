class_name PostureJoueur
extends SkeletonModifier3D
## POSTURE DES JAMBES du corps du joueur (JoueurBase homme / femme ; chantier joueur_base, passe 2, 2026-11-26).
##
## Constat (outils/mesure_posture_joueur.gd) : le retargeting est EXACT (mêmes angles que l'ancien héros, image pour image), c'est
## le clip lui-même qui est accroupi. Les repos Quaternius des humains (Sword_Idle, Idle) sont une garde basse : genoux à 110-117°
## (Sword_Idle), chevilles écartées à 1,7-2 fois la largeur des hanches, pied droit tourné de 44° vers l'extérieur. Sous la cotte et
## le tabard de l'ancien héros ça ne se voyait pas ; sous le pantalon ajusté des nouveaux corps, ils ont l'air accroupis.
##
## Correction, sur les seules jambes et par-dessus le clip : aux repos (et un peu en garde / coup encaissé), cuisses ramenées vers
## leur orientation de repos du squelette (droites, pieds devant, dans le repère du MODÈLE : quelle que soit la rotation du bassin),
## mollets / pieds / orteils vers leur repos, et bassin relevé d'autant que les pieds sont descendus (le pied le plus bas reste au
## sol ; PiedsAuSol, après, le pose sur le relief). Le haut du corps garde le clip (respiration, garde de l'épée).
## Marche, trot, course : clips justes (genoux 150-170°, chevilles à 1,0x les hanches) : rien. Coups pilotés par CorpsCoupsTps
## (captures Mixamo / UAL2) : rien non plus (poids du geste), leurs appuis sont ceux de la capture.
## Critères (brief passe 2) : au repos chevilles <= hanches x 1,3, genoux >= 165°, pieds +-15°.

## part de correction selon le clip joué (absent = 0)
const POIDS := {
	&"Idle": 1.0, &"Sword_Idle": 1.0, &"Idle_Torch": 1.0, &"Idle_Talking": 1.0, &"Spell_Simple_Idle": 1.0,
	&"Spell_Simple_Enter": 1.0, &"Spell_Simple_Exit": 1.0, &"Spell_Simple_Shoot": 0.8, &"Pistol_Idle": 1.0,
	&"Sword_Attack": 0.85, &"Hit_Chest": 0.6, &"Hit_Head": 0.6, &"Punch_Jab": 0.5, &"Punch_Cross": 0.5,
}
const VITESSE := 8.0      # 1/s : fondu du poids quand le clip change
## Pose debout visée (plutôt qu'au garde-à-vous) : jambes très légèrement ouvertes (chevilles ~1,15 x les hanches), pointes à 8° vers
## l'extérieur ; repère du squelette : le perso regarde +Z, sa gauche est +X.
const ECART := 1.4        # degrés d'ouverture de chaque cuisse
const POINTES := 8.0      # degrés de rotation des jambes vers l'extérieur
const COTES := ["l", "r"]

var anim: AnimationPlayer
var poids := 0.0
## POINGS (passe 3) : formes « poing_l » / « poing_r » de la pièce « peau » (chaîne Blender) : la main qui tient quelque chose (arme,
## torche, bouclier, arc) se ferme sur sa fusée ; main libre ou sort : main sculptée, mi-ouverte. poing = {côté: 0..1}.
const CATEGORIES_FERMEES := ["arme", "arme_deux_mains", "bouclier", "torche"]
const VITESSE_POING := 10.0
var poing := {"l": 0.0, "r": 0.0}
var forcer_poings := {}      # tests / captures : {"l": 1.0} impose une main
var _peau: MeshInstance3D
var _formes := {}
var _coups: Node = null
var _bassin := -1
var _jambes := {}          # côté -> [cuisse, mollet, pied, orteil]

static func equiper(sq: Skeleton3D, ap: AnimationPlayer) -> PostureJoueur:
	var m := PostureJoueur.new()
	m.name = "PostureJoueur"
	m.anim = ap
	sq.add_child(m)
	sq.move_child(m, 0)         # avant les autres modificateurs (PiedsAuSol, ragdoll ; CorpsCoupsTps se place encore avant)
	m._bassin = sq.find_bone("pelvis")
	for c: String in COTES:
		m._jambes[c] = [sq.find_bone("thigh_" + c), sq.find_bone("calf_" + c), sq.find_bone("foot_" + c), sq.find_bone("ball_" + c)]
	return m

## Fermeture voulue de chaque main, d'après ce qu'elle tient (CorpsMainsTps.categorie, arc du joueur).
func _cibles_poings() -> Dictionary:
	var r := {"l": 0.0, "r": 0.0}
	var sq := get_skeleton()
	var corps: Node = sq.owner.get_parent() if sq != null and sq.owner != null else null
	var mt: Variant = corps.get("mains_tps") if corps != null else null
	if mt is Object and is_instance_valid(mt) and (mt as Object).has_method("categorie"):
		var cd := String(mt.call("categorie", "droite"))
		var cg := String(mt.call("categorie", "gauche"))
		r["r"] = 1.0 if cd in CATEGORIES_FERMEES else 0.0
		r["l"] = 1.0 if (cg in CATEGORIES_FERMEES or cd == "arme_deux_mains") else 0.0
		var j: Variant = corps.get("joueur")
		var arc: Variant = j.get("arc") if j is Object and is_instance_valid(j) else null
		if arc is Object and is_instance_valid(arc) and bool(arc.get("actif")):
			r["l"] = 1.0                 # l'arc dans le poing gauche
			r["r"] = 0.35                # main de corde : doigts en crochet
	for c: String in forcer_poings:
		r[c] = float(forcer_poings[c])
	return r

func _poings(dt: float) -> void:
	if _peau == null:
		var sq := get_skeleton()
		_peau = sq.find_child("peau", false, false) as MeshInstance3D if sq != null else null
		if _peau == null or _peau.mesh == null:
			_peau = null
			return
		for c: String in ["l", "r"]:
			_formes[c] = _peau.find_blend_shape_by_name("poing_" + c)
	var cibles := _cibles_poings()
	for c: String in ["l", "r"]:
		poing[c] = move_toward(float(poing[c]), float(cibles[c]), VITESSE_POING * dt) if dt > 0.0 else float(cibles[c])
		var k: int = _formes.get(c, -1)
		if k >= 0:
			_peau.set_blend_shape_value(k, poing[c])

func _cible() -> float:
	if anim == null or not anim.is_playing():
		return 0.0
	var w: float = POIDS.get(StringName(anim.current_animation), 0.0)
	if _coups == null or not is_instance_valid(_coups):
		_coups = null
		for c in get_skeleton().get_children():
			if c != self and c.has_method("poids_geste"):
				_coups = c
				break
	if _coups != null:
		w *= 1.0 - clampf(float(_coups.call("poids_geste")), 0.0, 1.0)
	return w

func _process_modification_with_delta(dt: float) -> void:
	var sq := get_skeleton()
	if sq == null or _bassin < 0:
		return
	_poings(dt)
	poids = move_toward(poids, _cible(), VITESSE * dt) if dt > 0.0 else _cible()
	if poids <= 0.001:
		return
	var w := smoothstep(0.0, 1.0, poids)
	var bas_avant := INF
	for c: String in COTES:
		bas_avant = minf(bas_avant, sq.get_bone_global_pose(_jambes[c][2]).origin.y)
	for c: String in COTES:
		var os_: Array = _jambes[c]
		# cuisse : orientation globale de repos (repère du modèle), le bassin peut être tourné
		var i: int = os_[0]
		var parent := sq.get_bone_global_pose(sq.get_bone_parent(i))
		var g := sq.get_bone_global_pose(i).basis.get_rotation_quaternion()
		var sg := 1.0 if c == "l" else -1.0
		var g_repos := Quaternion(Vector3.UP, deg_to_rad(sg * POINTES)) * Quaternion(Vector3.BACK, deg_to_rad(sg * ECART)) \
			* sq.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var g_but := g.slerp(g_repos, w)
		sq.set_bone_pose_rotation(i, (parent.basis.get_rotation_quaternion().inverse() * g_but).normalized())
		for k in range(1, os_.size()):
			var j: int = os_[k]
			if j < 0:
				continue
			sq.set_bone_pose_rotation(j, sq.get_bone_pose_rotation(j).slerp(sq.get_bone_rest(j).basis.get_rotation_quaternion(), w))
	var bas_apres := INF
	for c: String in COTES:
		bas_apres = minf(bas_apres, sq.get_bone_global_pose(_jambes[c][2]).origin.y)
	var dy := bas_avant - bas_apres
	if absf(dy) > 0.0001:
		var p := sq.get_bone_parent(_bassin)
		var haut := Vector3(0, dy, 0)
		if p >= 0:
			haut = sq.get_bone_global_pose(p).basis.inverse() * haut
		sq.set_bone_pose_position(_bassin, sq.get_bone_pose_position(_bassin) + haut)
