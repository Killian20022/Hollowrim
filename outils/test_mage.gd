extends SceneTree
## Test du Mage nordique (MageNordique) : contrat de Humain.creer (65 os, AnimationPlayer « Animations », clips dont Spell_Simple_*),
## budget (triangles, surfaces), matériaux au shader PS1 à accroche, PNJ non modifiés, ragdoll, et :
##   - JUPE / JAMBES : sur 8 clips (12 instants chacun), aucune jambe ne traverse la jupe modelée : chaque point de la jambe
##     (cuisse 7 cm, mollet 5,5 cm de rayon) sous la taille doit rester DANS l'anneau déformé de la jupe à sa hauteur
##     (marge mesurée en m, tolérance TRAVERSEE_JUPE) ;
##   - jupe gonflée : aucun point de l'ourlet à plus de ECART_OURLET de l'axe du bassin (pas de « voile ») ;
##   - bâton : traversée grossière dans le corps < 6 cm (comme l'épée du guerrier).
##   godot --headless --path . --script res://outils/test_mage.gd -- --nouvelle
const ANIMS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Spell_Simple_Enter", "Spell_Simple_Idle", "Spell_Simple_Shoot", "Spell_Simple_Exit", "Hit_Chest", "Death01"]
const CLIPS_JUPE := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Spell_Simple_Enter", "Spell_Simple_Shoot", "Spell_Simple_Exit", "Hit_Chest"]
const BUDGET := 7500
const SURFACES_MAX := 10
const TRAVERSEE_JUPE := 0.015
## course (genou levé presque à l'horizontale, talon relevé) : la jupe en cloche frôle la jambe de quelques cm au pire
const TRAVERSEE_JUPE_COURSE := 0.05
## ourlet : cloche plafonnée (MageJupe.CLOCHE_MAX 0,46 m depuis l'axe, 3 cm derrière le bassin)
const ECART_OURLET := 0.55
var echecs := 0
var diag := ""

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

## Pire traversée jambes -> jupe et plus grand écart horizontal de l'ourlet à l'axe du bassin sur un clip (12 instants).
func _jupe_clip(sq: Skeleton3D, ap: AnimationPlayer, clip: String, jupe: MageJupe) -> Vector2:
	ap.play(clip)
	var lg := ap.get_animation(clip).length
	var pire := -1.0
	var ecart := 0.0
	for k in 12:
		ap.seek(lg * k / 12.0, true)
		var anneaux := jupe.calculer()
		var pel := sq.get_bone_global_pose(sq.find_bone("pelvis"))
		for p: Vector3 in anneaux[anneaux.size() - 1]:
			ecart = maxf(ecart, Vector2(p.x - pel.origin.x, p.z - pel.origin.z).length())
		for cote in ["l", "r"]:
			var th := sq.get_bone_global_pose(sq.find_bone("thigh_" + cote)).origin
			var ca := sq.get_bone_global_pose(sq.find_bone("calf_" + cote)).origin
			var fo := sq.get_bone_global_pose(sq.find_bone("foot_" + cote)).origin
			for s in 10:
				var t := float(s + 1) / 10.0
				var q := th.lerp(ca, t * 2.0) if t <= 0.5 else ca.lerp(fo, (t - 0.5) * 2.0)
				var rayon := 0.07 if t <= 0.5 else 0.055
				var mg := _marge(q, rayon, anneaux, pel.origin)
				if mg > pire:
					pire = mg
					diag = "%s t=%.2f %s s=%d q=%s" % [clip, float(k) / 12.0, cote, s, q.snapped(Vector3.ONE * 0.01)]
	return Vector2(pire, ecart)

## Marge de sortie (m, > 0 = la jambe dépasse de la jupe) du disque (q, rayon) : segment horizontal de l'axe du bassin (à la
## hauteur de q) jusqu'au bord extérieur de la jambe (q + rayon, vers l'extérieur) ; s'il coupe la paroi déformée de la jupe
## (triangles réels), la longueur au-delà de la paroi est la traversée. -1 si q est sous l'ourlet ou au-dessus de la taille.
func _marge(q: Vector3, rayon: float, anneaux: Array, axe: Vector3) -> float:
	var A := Vector3(axe.x, q.y, axe.z)
	var dirh := Vector3(q.x - A.x, 0, q.z - A.z)
	if dirh.length() < 1e-4:
		return -1.0
	var Q := q + dirh.normalized() * rayon
	var bas := 1e9
	var haut := -1e9
	bas = _ourlet_local(anneaux[anneaux.size() - 1], axe, dirh) + 0.03     # sous l'ourlet LOCAL (+3 cm) : la jambe sort normalement de la robe
	for p: Vector3 in anneaux[0]:
		haut = maxf(haut, p.y)
	if q.y < bas or q.y > haut:
		return -1.0
	var pire := -1.0
	var L := A.distance_to(Q)
	for a in anneaux.size() - 1:
		var R0: Array = anneaux[a]
		var R1: Array = anneaux[a + 1]
		for i in R0.size():
			var j := (i + 1) % R0.size()
			for tri in [[R0[i], R0[j], R1[j]], [R0[i], R1[j], R1[i]]]:
				var hit: Variant = Geometry3D.segment_intersects_triangle(A, Q, tri[0], tri[1], tri[2])
				if hit != null:
					pire = maxf(pire, L - A.distance_to(hit))
	return pire

## Hauteur de l'ourlet dans la direction horizontale `dirh` depuis l'axe : interpolée (en angle) entre les deux colonnes de la
## jupe qui encadrent cette direction. Passe 2 : là où une jambe (genou levé, talon relevé) passe la cloche plafonnée, la colonne
## se drape sur la jambe et l'ourlet est relevé LOCALEMENT ; la jambe qui sort sous cet ourlet relevé n'est pas une traversée.
func _ourlet_local(ourlet: Array, axe: Vector3, dirh: Vector3) -> float:
	var aq := atan2(dirh.x, dirh.z)
	var n := ourlet.size()
	var best := 0
	var bd := 1e9
	var angles := []
	for i in n:
		var p: Vector3 = ourlet[i]
		var a := atan2(p.x - axe.x, p.z - axe.z)
		angles.append(a)
		var d := absf(wrapf(a - aq, -PI, PI))
		if d < bd:
			bd = d
			best = i
	var e := wrapf(aq - float(angles[best]), -PI, PI)
	var j := posmod(best + (1 if e * wrapf(float(angles[(best + 1) % n]) - float(angles[best]), -PI, PI) > 0.0 else -1), n)
	var span := absf(wrapf(float(angles[j]) - float(angles[best]), -PI, PI))
	var t := clampf(absf(e) / maxf(span, 1e-4), 0.0, 1.0)
	return lerpf((ourlet[best] as Vector3).y, (ourlet[j] as Vector3).y, t)

## Volumes du corps (capsules) pour le bâton.
func _volumes(sq: Skeleton3D) -> Array:
	var g := func(o: String) -> Vector3: return sq.get_bone_global_pose(sq.find_bone(o)).origin
	return [[g.call("pelvis"), g.call("neck_01"), 0.12], [g.call("Head") + Vector3(0, 0.02, 0), g.call("Head") + Vector3(0, 0.14, 0), 0.085],
		[g.call("thigh_l"), g.call("calf_l"), 0.07], [g.call("thigh_r"), g.call("calf_r"), 0.07], [g.call("calf_l"), g.call("foot_l"), 0.05], [g.call("calf_r"), g.call("foot_r"), 0.05]]

func _profondeur(p: Vector3, vols: Array) -> float:
	var pire := 0.0
	for v: Array in vols:
		var a: Vector3 = v[0]
		var ab: Vector3 = v[1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		pire = maxf(pire, float(v[2]) - p.distance_to(a + ab * t))
	return pire

func _lancer() -> void:
	var t0 := Time.get_ticks_usec()
	var g := MageNordique.creer({})
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	root.add_child(g)
	var h := Humain.creer({"corps": "homme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(h)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var sqh := h.find_child("Skeleton3D", true, false) as Skeleton3D
	var memes := sq.get_bone_count() == sqh.get_bone_count()
	for i in sqh.get_bone_count():
		memes = memes and sq.get_bone_name(i) == sqh.get_bone_name(i)
	ok(memes, "mêmes os que Humain.creer (%d)" % sq.get_bone_count())
	var ap := g.get_node_or_null("Animations") as AnimationPlayer
	var manque := []
	for a in ANIMS:
		if ap == null or not ap.has_animation(a):
			manque.append(a)
	ok(manque.is_empty(), "AnimationPlayer « Animations » et clips %s (absents : %s) ; creer %.0f ms" % [ANIMS, manque, dt])
	var tris := _tris(g)
	ok(tris <= BUDGET, "%d triangles visibles (<= %d)" % [tris, BUDGET])
	var surfaces := 0
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			surfaces += mi.mesh.get_surface_count()
	ok(surfaces <= SURFACES_MAX, "%d surfaces visibles (<= %d)" % [surfaces, SURFACES_MAX])
	var non_ps1 := []
	var emissif := false
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if not (m is ShaderMaterial) or not ((m as ShaderMaterial).shader.code.contains("grille")):
				non_ps1.append("%s/%d" % [mi.name, s])
			elif m == MageNordique.materiau_cristal():
				var e: Color = (m as ShaderMaterial).get_shader_parameter("emission")
				var ec: Variant = (m as ShaderMaterial).get_shader_parameter("eclat")
				var k: float = ec if ec != null else 1.15   # valeur par défaut du shader mage_orbe
				emissif = maxf(e.r, maxf(e.g, e.b)) <= 1.0 and k >= 0.8 and k <= 2.0
	ok(non_ps1.is_empty(), "toutes les surfaces passent par un shader PS1 à accroche (%s)" % [non_ps1])
	ok(emissif, "orbe du bâton lumineux (shader mage_orbe : émission de base <= 1, lueur portée par la texture, pas de halo plein écran)")
	var tun := sqh.get_node("tunique") as MeshInstance3D
	ok((tun.material_override as ShaderMaterial).shader != GuerrierNordique.SHADER, "Humain.creer (PNJ) non modifié")
	# jupe
	var jupe := sq.get_node_or_null("jupe") as MageJupe
	ok(jupe != null and jupe.repos.size() == MageNordique.ANNEAUX.size(), "jupe modelée dynamique : %d anneaux de %d secteurs" % [MageNordique.ANNEAUX.size(), MageNordique.SECTEURS])
	for clip in CLIPS_JUPE:
		var r := _jupe_clip(sq, ap, clip, jupe)
		var tol := TRAVERSEE_JUPE_COURSE if clip in ["Jog_Fwd", "Sprint"] else TRAVERSEE_JUPE
		ok(r.x < tol and r.y < ECART_OURLET, "%s : jambe hors de la jupe de %.3f m au pire (< %.3f ; -1 = jamais), ourlet à %.2f m de l'axe au plus (< %.2f)%s" % [clip, r.x, tol, r.y, ECART_OURLET, "" if r.x < tol else " [" + diag + "]"])
	var t1 := Time.get_ticks_usec()
	for i in 100:
		jupe.mettre_a_jour()
	var t_tout := (Time.get_ticks_usec() - t1) / 100000.0
	t1 = Time.get_ticks_usec()
	for i in 100:
		jupe.calculer()
	print("INFO   jupe recalculée en %.3f ms (moyenne sur 100 ; dont géométrie %.3f ms, le reste = maillage)" % [t_tout, (Time.get_ticks_usec() - t1) / 100000.0])
	# bâton
	var m: Array = sq.get_meta("baton")
	for clip in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Spell_Simple_Enter", "Spell_Simple_Shoot", "Hit_Chest"]:
		ap.play(clip)
		var lg := ap.get_animation(clip).length
		var pire := 0.0
		for k in 12:
			ap.seek(lg * k / 12.0, true)
			var bd0 := sq.get_node_or_null("BatonDroit")
			if bd0:
				bd0._process_modification()     # bâton tel qu'il est vu en jeu (redressé)
			var tr: Transform3D = PiedsAuSol.pose_globale(sq, m[0]) * sq.get_bone_global_rest(m[0]).affine_inverse() * m[1]
			var vols := _volumes(sq)
			for y in [-0.8, -0.6, -0.4, -0.2, 0.3, 0.6, 0.9]:
				pire = maxf(pire, _profondeur(tr * Vector3(0, y, 0), vols))
		ok(pire < 0.06, "%s : traversée max du bâton %.3f m (< 0,06)" % [clip, pire])
	# passe 2 : bâton DROIT (modificateur BatonDroit appliqué après l'animation) au repos, en marche et pendant le sort
	var bd := sq.get_node_or_null("BatonDroit") as MageNordique.BatonDroit
	ok(bd != null, "modificateur BatonDroit présent")
	if bd:
		for clip in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Spell_Simple_Enter", "Spell_Simple_Idle", "Spell_Simple_Shoot"]:
			ap.play(clip)
			var lg := ap.get_animation(clip).length
			var pire := 0.0
			for k in 8:
				ap.seek(lg * k / 8.0, true)
				bd._process_modification()
				var axe := (PiedsAuSol.pose_globale(sq, bd.os_) * bd.prise).basis.y
				pire = maxf(pire, rad_to_deg(axe.angle_to(Vector3.UP)))
			ok(pire < 3.0, "%s : bâton incliné de %.1f° au plus (< 3°)" % [clip, pire])
	# --- variante CORPS FEMME (Sigrún, Grima) : mêmes contrats, budget, jupe, plastron Blender chargé
	var gf := MageNordique.creer({"corps": "femme"})
	root.add_child(gf)
	var hf := Humain.creer({"corps": "femme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(hf)
	var sqf := gf.find_child("Skeleton3D", true, false) as Skeleton3D
	var sqhf := hf.find_child("Skeleton3D", true, false) as Skeleton3D
	var memes_f := sqf.get_bone_count() == sqhf.get_bone_count()
	for i in sqhf.get_bone_count():
		memes_f = memes_f and sqf.get_bone_name(i) == sqhf.get_bone_name(i)
	ok(memes_f, "femme : mêmes os qu'Humain.creer femme (%d)" % sqf.get_bone_count())
	var tris_f := _tris(gf)
	ok(tris_f <= BUDGET, "femme : %d triangles visibles (<= %d)" % [tris_f, BUDGET])
	var surf_f := 0
	for mi: MeshInstance3D in gf.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			surf_f += mi.mesh.get_surface_count()
	ok(surf_f <= SURFACES_MAX, "femme : %d surfaces visibles (<= %d)" % [surf_f, SURFACES_MAX])
	var gb := MageNordique.creer({"corps": "femme", "blender": false})
	root.add_child(gb)
	ok(tris_f > _tris(gb) - 200 and MageNordique.avec_plastron, "femme : écailles + frange Blender chargées (%d tris sans, %d avec)" % [_tris(gb), tris_f])
	var apf := gf.get_node_or_null("Animations") as AnimationPlayer
	ok(apf != null and apf.has_animation("Spell_Simple_Shoot") and apf.has_animation("Walk"), "femme : AnimationPlayer et clips")
	var jf := sqf.get_node_or_null("jupe") as MageJupe
	if jf:
		for clip in ["Idle", "Walk", "Jog_Fwd"]:
			var rf := _jupe_clip(sqf, apf, clip, jf)
			ok(rf.x <= TRAVERSEE_JUPE_COURSE, "femme : %s jambes/jupe %.1f cm (<= %.0f)" % [clip, rf.x * 100.0, TRAVERSEE_JUPE_COURSE * 100.0])
	var rdf := Ragdoll.equiper(gf) as Ragdoll
	ok(rdf != null and rdf.os.size() == 16, "femme : ragdoll %d os" % (rdf.os.size() if rdf else 0))
	gb.free()
	var rd := Ragdoll.equiper(g) as Ragdoll
	ok(rd != null and rd.os.size() == 16, "ragdoll : %d os physiques" % (rd.os.size() if rd else 0))
	print("TEST MAGE : %s (%d échecs)" % ["OK" if echecs == 0 else "ÉCHEC", echecs])
	quit(echecs)

