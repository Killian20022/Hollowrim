class_name MortAraignee
## Mort CRÉDIBLE de l'araignée des cavernes (retours exe 5) : le clip « Death » du pack Quaternius retourne le corps de 180° SANS le
## descendre (le Body reste à hauteur de marche, 0,82 du rig) et laisse la moitié des pattes tendues vers le sol : un cadavre ventre en
## l'air perché sur des échasses. On ne joue donc plus ce clip : une animation est CALCULÉE à la mort, depuis la pose du moment :
##   0-0,18 s  spasme : les pattes se contractent, le corps tombe d'un quart ;
##   0,18-0,9 s  elle bascule sur le dos (roulis de 90° puis 180° autour de son axe avant, du côté opposé au coup) en descendant ;
##   0,9-1,15 s  les pattes finissent de se replier sur le ventre (dernier frémissement), puis plus rien ne bouge.
## Les pattes se replient segment par segment autour de l'axe horizontal de chaque patte (fémur, tibia, tarse) jusqu'à des angles
## CIBLES dans le plan de la patte (CIBLES), quelle que soit la pose de départ ; retournées, elles se recroquevillent sur le ventre. Le
## corps se pose : sa hauteur finale est calculée sur le MAILLAGE (sommets du céphalothorax, de l'abdomen et de la tête, repère des os
## par les bind poses de la peau) pour que le dos touche le sol, sans s'y enfoncer.
##   MortAraignee.animation(squelette, chemin_squelette, cote) -> Animation (une par cadavre : elle part de la pose courante)

## Directions finales (degrés) du fémur, du tibia et du tarse dans le plan vertical de la patte, AVANT le retournement : 0 = à
## l'horizontale vers l'extérieur, -90 = vers le bas (le ventre), -180 = à l'horizontale vers le centre. Fémur un peu sous l'horizontale,
## tibia replié sous le ventre, tarse ramené vers le milieu : une fois l'araignée sur le dos, les pattes se referment au-dessus d'elle.
const CIBLES := [-35.0, -150.0, -195.0]
const DUREE := 1.15
const OS_CORPS := ["Body", "Abdomen", "Thorax", "Head"]
const JEU := 0.015                     # le dos se pose à 1,5 cm du sol (repère du rig) : ni dans le sol ni au-dessus

static var _sommets := {}             # maillage -> [[os, position dans le repère de l'os]…] (sommets du corps)

## Chaînes des pattes : [fémur, tibia, tarse] (« FrontLeg.L », « FrontLeg2.L », « FrontLeg3.L »…).
static func pattes(sq: Skeleton3D) -> Array:
	var r: Array = []
	for i in sq.get_bone_count():
		var n := sq.get_bone_name(i)
		if n.contains("Leg") and not n.contains("Leg2") and not n.contains("Leg3"):
			var b := n.replace("Leg", "Leg2")
			var c := n.replace("Leg", "Leg3")
			if sq.find_bone(b) >= 0 and sq.find_bone(c) >= 0:
				r.append([i, sq.find_bone(b), sq.find_bone(c)])
	return r

## Sommets du corps (os dominant dans OS_CORPS), exprimés dans le repère de leur os (bind pose de la peau).
static func _sommets_corps(sq: Skeleton3D) -> Array:
	var mi: MeshInstance3D = null
	for m: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		mi = m
		break
	if mi == null:
		for m: MeshInstance3D in sq.get_parent().find_children("*", "MeshInstance3D", true, false):
			mi = m
			break
	if mi == null or mi.mesh == null or mi.skin == null:
		return []
	var cle := mi.mesh.get_instance_id()
	if _sommets.has(cle):
		return _sommets[cle]
	var skin := mi.skin
	var bind := {}
	for k in skin.get_bind_count():
		var os := skin.get_bind_bone(k)
		if os < 0:
			os = sq.find_bone(skin.get_bind_name(k))
		bind[k] = [os, skin.get_bind_pose(k)]
	var corps := {}
	for n: String in OS_CORPS:
		corps[sq.find_bone(n)] = true
	var r: Array = []
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var os_v = a[Mesh.ARRAY_BONES]
		var po_v = a[Mesh.ARRAY_WEIGHTS]
		if os_v == null or po_v == null or v.is_empty():
			continue
		var par := int(os_v.size() / v.size())
		for i in range(0, v.size(), 2):         # un sommet sur deux suffit (le maillage est dense sur le corps)
			var best := -1
			var pb := 0.0
			for k in par:
				if float(po_v[i * par + k]) > pb:
					pb = float(po_v[i * par + k])
					best = int(os_v[i * par + k])
			if not bind.has(best):
				continue
			var os: int = bind[best][0]
			if corps.has(os):
				r.append([os, (bind[best][1] as Transform3D) * v[i]])
	_sommets[cle] = r
	return r

## Animation de mort à partir de la pose COURANTE de `sq` (globales des os exprimées dans le repère du modèle). `chemin` : chemin du squelette vu de l'AnimationPlayer (« Armature/Skeleton3D »).
## `cote` : +1 / -1, sens du roulis (l'araignée bascule loin du coup).
## `racine` : nœud racine du modèle (sol à y = 0, Y vers le haut) ; les calculs se font dans SON repère, le rig Blender étant Z en haut.
static func animation(sq: Skeleton3D, chemin: String, cote := 1.0, racine_modele: Node3D = null) -> Animation:
	var n := sq.get_bone_count()
	var m := Transform3D.IDENTITY
	if racine_modele != null and racine_modele.is_inside_tree() and sq.is_inside_tree():
		m = racine_modele.global_transform.affine_inverse() * sq.global_transform
	else:
		var x: Node = sq
		while x != null and x != racine_modele and x is Node3D:
			m = (x as Node3D).transform * m
			x = x.get_parent()
	var g: Array[Transform3D] = []
	var loc: Array[Transform3D] = []
	for i in n:
		g.append(m * sq.get_bone_global_pose(i))
		loc.append(sq.get_bone_pose(i))
	var body := sq.find_bone("Body")
	var racine := sq.get_bone_parent(body)
	var g_rac: Transform3D = g[racine] if racine >= 0 else m
	# --- repli des pattes (repère du squelette, corps non retourné) : rotations autour de l'axe horizontal de chaque patte
	var plie := {}           # facteur -> {os: local}
	var tarses := {}         # facteur -> {tarse: global replié (corps non retourné)}
	# os « pied » (cibles d'IK du rig Blender, enfants de Root) : la pointe des tarses leur est attachée dans la peau ; s'ils restent au
	# sol, la pointe de chaque patte s'étire jusqu'à eux en longues aiguilles (c'était aussi le défaut du clip Death). Chaque pied suit
	# donc rigidement le tarse de sa patte (le plus proche de sa pointe).
	var pieds := {}          # tarse -> pied
	for ch: Array in pattes(sq):
		var pointe: Vector3 = g[ch[2]].origin + g[ch[2]].basis.y * g[ch[1]].origin.distance_to(g[ch[2]].origin)
		var meilleur := -1
		var dm := INF
		for i in n:
			if sq.get_bone_name(i).contains("Foot") and g[i].origin.distance_to(pointe) < dm:
				dm = g[i].origin.distance_to(pointe)
				meilleur = i
		if meilleur >= 0:
			pieds[ch[2]] = meilleur
	for f: float in [0.5, 0.85, 1.0, 1.06]:
		var poses := {}
		var tg := {}
		for ch: Array in pattes(sq):
			var p1: Vector3 = g[ch[0]].origin
			var o3: Vector3 = g[ch[2]].origin + g[ch[2]].basis.y * g[ch[1]].origin.distance_to(g[ch[2]].origin)
			var dehors := Vector3(o3.x - p1.x, 0.0, o3.z - p1.z)
			if dehors.length() < 0.001:
				continue
			dehors = dehors.normalized()
			var axe := Vector3.UP.cross(dehors).normalized()      # +angle autour de `axe` : la direction descend (vers le ventre)
			var cumuls: Array[float] = []
			for k in 3:
				var d: Vector3 = (g[ch[k + 1]].origin - g[ch[k]].origin) if k < 2 else g[ch[2]].basis.y
				var phi := atan2(d.dot(Vector3.UP), d.dot(dehors))
				var c := phi - deg_to_rad(float(CIBLES[k]))
				if c < -0.5:
					c += TAU
				cumuls.append(c * f)
			var nouv: Array[Transform3D] = []
			var prec_o := Vector3.ZERO
			for k in 3:
				var os: int = ch[k]
				var o: Vector3 = g[os].origin
				if k > 0:
					o = prec_o + Basis(axe, cumuls[k - 1]) * (g[os].origin - g[ch[k - 1]].origin)
				nouv.append(Transform3D(Basis(axe, cumuls[k]) * g[os].basis, o))
				prec_o = o
			var g_body: Transform3D = g[sq.get_bone_parent(ch[0])]
			poses[ch[0]] = g_body.affine_inverse() * nouv[0]
			poses[ch[1]] = nouv[0].affine_inverse() * nouv[1]
			poses[ch[2]] = nouv[1].affine_inverse() * nouv[2]
			tg[ch[2]] = nouv[2]
		plie[f] = poses
		tarses[f] = tg
	# --- corps : roulis autour de l'axe avant (+Z du rig), descente jusqu'à poser le dos
	# axe avant : du milieu des pattes arrière vers le milieu des pattes avant (le repère de l'os Body n'est pas celui de la bête)
	var avant := Vector3.BACK
	var av_sum := Vector3.ZERO
	for ch: Array in pattes(sq):
		var nom := sq.get_bone_name(ch[0])
		if nom.begins_with("Front"):
			av_sum += g[ch[0]].origin
		elif nom.begins_with("Back"):
			av_sum -= g[ch[0]].origin
	av_sum.y = 0.0
	if av_sum.length() > 0.001:
		avant = av_sum.normalized()
	var h_fin := _hauteur_posee(sq, g, body, avant, cote)
	var cles := [[0.0, 0.0, 0.0, 0.0], [0.18, 0.0, 0.25, 0.5], [0.55, 90.0, 0.62, 0.85], [0.9, 180.0, 1.0, 1.0], [DUREE, 180.0, 1.0, 1.06]]
	var a := Animation.new()
	a.length = DUREE
	a.loop_mode = Animation.LOOP_NONE
	# toutes les pistes de rotation (les os non animés gardent la pose de départ : rien ne saute)
	var pistes := {}
	for i in n:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [chemin, sq.get_bone_name(i)]))
		pistes[i] = t
	var tp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tp, NodePath("%s:Body" % chemin))
	var pistes_pieds := {}
	for tarse: int in pieds:
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [chemin, sq.get_bone_name(pieds[tarse])]))
		pistes_pieds[tarse] = t
	var y0 := g[body].origin.y
	for c: Array in cles:
		var temps: float = c[0]
		var roulis := deg_to_rad(float(c[1])) * cote
		var desc: float = c[2]
		var f: float = c[3]
		var pos_g := g[body].origin
		pos_g.y = lerpf(y0, h_fin, desc)
		var bt := Transform3D(Basis(avant, roulis) * g[body].basis, pos_g)
		var q_pieds := {}
		for tarse: int in pieds:
			var pied: int = pieds[tarse]
			var t_pre: Transform3D = (tarses[f] as Dictionary).get(tarse, g[tarse]) if tarses.has(f) else g[tarse]
			var g_pied := bt * g[body].affine_inverse() * t_pre * g[tarse].affine_inverse() * g[pied]
			var l_pied := g[sq.get_bone_parent(pied)].affine_inverse() * g_pied if sq.get_bone_parent(pied) >= 0 else m.affine_inverse() * g_pied
			q_pieds[pied] = l_pied.basis.get_rotation_quaternion()
			a.position_track_insert_key(pistes_pieds[tarse], temps, l_pied.origin)
		for i in n:
			var q := loc[i].basis.get_rotation_quaternion()
			if i == body:
				var gb := Transform3D(Basis(avant, roulis) * g[body].basis, g[body].origin)
				q = (g_rac.affine_inverse() * gb).basis.get_rotation_quaternion()
			elif q_pieds.has(i):
				q = q_pieds[i]
			elif f > 0.0 and plie.has(f) and (plie[f] as Dictionary).has(i):
				q = ((plie[f] as Dictionary)[i] as Transform3D).basis.get_rotation_quaternion()
			a.rotation_track_insert_key(pistes[i], temps, q)
		a.position_track_insert_key(tp, temps, g_rac.affine_inverse() * pos_g)
	return a

## Hauteur (repère du squelette) du Body retourné pour que le point le plus bas du corps soit à JEU au-dessus du sol (y = 0 du rig).
static func _hauteur_posee(sq: Skeleton3D, g: Array[Transform3D], body: int, avant: Vector3, cote: float) -> float:
	var verts := _sommets_corps(sq)
	var gb := Transform3D(Basis(avant, PI * cote) * g[body].basis, g[body].origin)
	var bas := INF
	if verts.is_empty():
		return g[body].origin.y * 0.32
	# os du corps retournés : Body tourné, les autres suivent par leur pose locale
	var gp := {body: gb}
	for nom: String in OS_CORPS:
		var i := sq.find_bone(nom)
		if i == body or i < 0:
			continue
		var chaine: Array[int] = []
		var k := i
		while k != body and k >= 0:
			chaine.push_front(k)
			k = sq.get_bone_parent(k)
		var t := gb
		for c in chaine:
			t = t * sq.get_bone_pose(c)
		gp[i] = t
	for vs: Array in verts:
		var os: int = vs[0]
		if gp.has(os):
			bas = minf(bas, ((gp[os] as Transform3D) * (vs[1] as Vector3)).y)
	return g[body].origin.y - (bas - JEU)
