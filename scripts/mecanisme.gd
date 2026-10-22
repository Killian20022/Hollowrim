class_name Mecanisme
extends RefCounted
## Mécanismes et énigmes des donjons (statues à orienter, braseros à allumer dans l'ordre, socles de sceaux, mur fragile).
## Chaque fabrique renvoie un Node3D posé à l'origine de `parent` (les positions sont dans le repère de `parent`).
##
## API (le dernier paramètre facultatif `ctx` est un Dictionnaire) :
##   Mecanisme.statues(parent, positions, solution, ident, on_resolu, ctx := {}) -> Node3D
##   Mecanisme.braseros(parent, positions, ordre, ident, on_resolu, ctx := {}) -> Node3D
##   Mecanisme.socles(parent, positions, objets, ident, on_complet, ctx := {}) -> Node3D
##   Mecanisme.mur_fragile(parent, pos, taille, lacet, ident, on_casse, ctx := {}) -> Node3D
##   Mecanisme.restaurer_tout(racine) : relit quetes.vus pour tous les mécanismes sous `racine` (à appeler à la mort / au rechargement).
## `ctx` (tout est facultatif) : "joueur", "dialogue", "quetes" ; sinon trouvés en remontant les parents (monde, tertre : propriétés
## joueur / dialogue / quetes). Pour mur_fragile : "materiau" (Material du mur voisin, pour se fondre dans le décor).
## Convention : positions des statues, braseros et socles = SOL sous l'objet ; mur_fragile : pos = CENTRE du volume (taille = volume entier).
## Statues : orientation k = k quarts de tour dans le sens horaire vu du dessus, depuis le nord (-Z) : 0 = -Z, 1 = +X, 2 = +Z, 3 = -X.
## `on_resolu` / `on_complet` / `on_casse` (sans argument) sont appelés à la résolution ET à la création si l'état est déjà acquis
## dans quetes.vus (partie chargée) : Mecanisme.restauration vaut alors true pendant l'appel (pas de son ni d'animation côté appelant).
## Événements quetes.vus : "meca:<ident>:resolu" (statues, braseros, socles complets), "meca:<ident>:s<i>" (socle i garni),
## "meca:<ident>:casse" (mur). L'état non résolu (orientations, braseros allumés) n'est PAS sauvegardé : remis à zéro par restaurer().

static var restauration := false

static func statues(parent: Node, positions: Array, solution: Array, ident: String, on_resolu: Callable, ctx := {}) -> Node3D:
	var n := Statues.new()
	n.positions = positions
	n.solution = solution
	n.on_fini = on_resolu
	return _poser(n, parent, ident, ctx)

static func braseros(parent: Node, positions: Array, ordre: Array, ident: String, on_resolu: Callable, ctx := {}) -> Node3D:
	var n := Braseros.new()
	n.positions = positions
	n.ordre = ordre
	n.on_fini = on_resolu
	return _poser(n, parent, ident, ctx)

static func socles(parent: Node, positions: Array, objets: Array, ident: String, on_complet: Callable, ctx := {}) -> Node3D:
	var n := Socles.new()
	n.positions = positions
	n.objets = objets
	n.on_fini = on_complet
	return _poser(n, parent, ident, ctx)

static func mur_fragile(parent: Node, pos: Vector3, taille: Vector3, lacet: float, ident: String, on_casse: Callable, ctx := {}) -> Node3D:
	var n := Mur.new()
	n.pos = pos
	n.taille = taille
	n.lacet = lacet
	n.on_fini = on_casse
	return _poser(n, parent, ident, ctx)

static func _poser(n: Base, parent: Node, ident: String, ctx: Dictionary) -> Node3D:
	n.ident = ident
	n.ctx = ctx
	n.name = "meca_" + ident.validate_node_name()
	n.construire()
	parent.add_child(n)
	return n

static func restaurer_tout(racine: Node) -> void:
	for n in racine.get_tree().get_nodes_in_group("mecanismes"):
		if is_instance_valid(n) and racine.is_ancestor_of(n) and n.has_method("restaurer"):
			n.restaurer()

# ------------------------------------------------------------------ outils partagés (utilisés aussi par Piege)
## Matériau PS1 d'une palette ; `tex` peut être une texture déjà peinte.
static func materiau(palette: Array, nom: String, echelle := Vector2.ONE, teinte := Color.WHITE) -> ShaderMaterial:
	return Palette.materiau(Palette.tex(nom, palette, 4, 0.45), echelle, teinte)

## Texture de pierre (ou autre palette) traversée de fissures noires (marches aléatoires, jamais de damier).
static func texture_fissures(palette: Array, graine: int, nombre := 6, taille := 64) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var img := Palette.texture(taille, palette, 4, graine, 0.45).get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.clear_mipmaps()
	var sombre := Color("#07080b")
	for k in nombre:
		var p := Vector2(rng.randf() * taille, rng.randf() * taille)
		var a := rng.randf() * TAU
		var branches := [[p, a, 22 + rng.randi() % 20]]
		while not branches.is_empty():
			var b: Array = branches.pop_back()
			var q: Vector2 = b[0]
			var ang: float = b[1]
			for i in int(b[2]):
				ang += rng.randf_range(-0.55, 0.55)
				q += Vector2(cos(ang), sin(ang))
				var px := int(q.x) % taille
				var py := int(q.y) % taille
				img.set_pixel(px if px >= 0 else px + taille, py if py >= 0 else py + taille, sombre)
				if rng.randf() < 0.05 and branches.size() < 4:
					branches.append([q, ang + rng.randf_range(-1.0, 1.0), 8 + rng.randi() % 8])
	return ImageTexture.create_from_image(img)

static func boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func cylindre(parent: Node3D, r_bas: float, r_haut: float, h: float, pos: Vector3, mat: Material, cotes := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r_bas
	c.top_radius = r_haut
	c.height = h
	c.radial_segments = cotes
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func collision(parent: Node3D, centre: Vector3, taille: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = centre
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

## Particules de petits cubes nets (poussière, givre) : pas de fondu, comme les étincelles de la torche.
static func particules(parent: Node3D, pos: Vector3, couleur: Color, nombre: int, duree: float, vitesse: float, direction: Vector3, ecart: float, boite_emission: Vector3, taille := 0.03) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.position = pos
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = boite_emission
	pm.direction = direction
	pm.spread = ecart
	pm.initial_velocity_min = vitesse * 0.6
	pm.initial_velocity_max = vitesse
	pm.gravity = Vector3(0, 0.05, 0)
	p.process_material = pm
	var q := BoxMesh.new()
	q.size = Vector3.ONE * taille
	q.material = Palette.lueur(couleur)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

# ------------------------------------------------------------------ socle commun
class Base extends Node3D:
	var ident := ""
	var ctx := {}
	var on_fini := Callable()
	var joueur: CharacterBody3D
	var dialogue: Control
	var quetes: Node
	var _vus_local := {}
	var _mats := {}
	var _inters: Array = []

	func construire() -> void:
		pass

	func _ready() -> void:
		add_to_group("mecanismes")
		joueur = ctx.get("joueur", _chercher("joueur"))
		dialogue = ctx.get("dialogue", _chercher("dialogue"))
		quetes = ctx.get("quetes", _chercher("quetes"))
		_interactions()
		restaurer()

	func _interactions() -> void:
		pass

	func restaurer() -> void:
		pass

	func _chercher(prop: String) -> Object:
		var n: Node = get_parent()
		while n != null:
			if prop in n and n.get(prop) != null:
				return n.get(prop)
			n = n.get_parent()
		return null

	func mat(palette: Array, nom: String, echelle := Vector2.ONE, teinte := Color.WHITE) -> ShaderMaterial:
		var cle := "%s|%s|%s" % [nom, echelle, teinte]
		if not _mats.has(cle):
			_mats[cle] = Mecanisme.materiau(palette, nom, echelle, teinte)
		return _mats[cle]

	func vu(evt: String) -> bool:
		return quetes.vus.has(evt) if quetes != null else _vus_local.has(evt)

	func signaler(evt: String) -> void:
		if quetes != null:
			quetes.signaler(evt)
		else:
			_vus_local[evt] = true

	func oublier(evt: String) -> void:
		if quetes != null:
			quetes.vus.erase(evt)
		_vus_local.erase(evt)

	func interactif(pos: Vector3, nom: String, verbe: String, action: Callable, condition := Callable(), rayon := 2.3) -> Node3D:
		if joueur == null or dialogue == null:
			return null
		var it := Node3D.new()
		it.set_script(preload("res://scripts/interactif.gd"))
		it.joueur = joueur
		it.dialogue = dialogue
		it.nom = nom
		it.verbe = verbe
		it.condition = condition
		it.action = action
		it.rayon = rayon
		it.position = pos
		add_child(it)
		_inters.append(it)
		return it

	func fin(lignes: Array) -> Array:
		if on_fini.is_valid():
			on_fini.call()
		return lignes

	func fin_restauree() -> void:
		Mecanisme.restauration = true
		if on_fini.is_valid():
			on_fini.call()
		Mecanisme.restauration = false

	func son(noms: Array, pos: Vector3, volume := 0.0) -> void:
		if is_inside_tree():
			Sons.jouer_a(self, noms, to_global(pos), volume)

	func secousse(v: float) -> void:
		if joueur != null:
			joueur.secousse = maxf(joueur.secousse, v)

# ------------------------------------------------------------------ statues
class Statues extends Base:
	var positions: Array = []
	var solution: Array = []
	var etat: Array = []              # orientation actuelle de chaque statue (0..3)
	var resolu := false
	var _depart: Array = []
	var _pivots: Array = []
	var _angles: Array = []

	## Direction horizontale vers laquelle regarde une statue d'orientation k.
	static func direction(k: int) -> Vector3:
		var a := k * PI / 2.0
		return Vector3(sin(a), 0.0, -cos(a))

	func construire() -> void:
		var pierre := mat(Palette.ROCHE, "meca_statue", Vector2(1, 1), Color(0.9, 0.92, 1.0))
		var pierre_s := mat(Palette.ROCHE, "meca_statue", Vector2(1, 2), Color(0.72, 0.74, 0.8))
		var rune := Palette.lueur(Color(0.5, 0.85, 1.0))
		for i in positions.size():
			var p: Vector3 = positions[i]
			Mecanisme.boite(self, Vector3(1.0, 0.3, 1.0), p + Vector3(0, 0.15, 0), pierre_s)
			Mecanisme.collision(self, p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
			var piv := Node3D.new()
			piv.position = p + Vector3(0, 0.3, 0)
			add_child(piv)
			Mecanisme.cylindre(piv, 0.34, 0.26, 0.9, Vector3(0, 0.45, 0), pierre)               # corps
			Mecanisme.boite(piv, Vector3(0.78, 0.2, 0.34), Vector3(0, 0.98, 0), pierre)          # épaules
			Mecanisme.cylindre(piv, 0.17, 0.17, 0.3, Vector3(0, 1.23, 0), pierre)                # tête casquée
			Mecanisme.boite(piv, Vector3(0.05, 0.12, 0.2), Vector3(0, 1.4, 0.0), pierre_s)       # cimier
			Mecanisme.boite(piv, Vector3(0.16, 0.16, 0.66), Vector3(0.0, 0.98, -0.5), pierre)    # bras tendu : il montre la direction
			Mecanisme.boite(piv, Vector3(0.1, 0.1, 0.06), Vector3(0, 0.98, -0.85), pierre_s)     # main/pointe
			Mecanisme.boite(piv, Vector3(0.1, 0.03, 0.1), Vector3(0, 1.3, -0.15), rune)          # petite rune sur le front : repère du devant
			_pivots.append(piv)
			var k0: int = (int(solution[i]) + 1 + (i % 3)) % 4        # jamais la bonne orientation au départ
			_depart.append(k0)
			etat.append(k0)
			_angles.append(-k0 * PI / 2.0)
			piv.rotation.y = _angles[i]

	func _interactions() -> void:
		for i in positions.size():
			var p: Vector3 = positions[i]
			interactif(p + Vector3(0, 1.1, 0), "Statue", "Faire pivoter la statue", _tourner_action.bind(i), func() -> bool: return not resolu)

	func _tourner_action(i: int) -> Array:
		tourner(i)
		if resolu:
			return ["Les statues s’immobilisent. Dans la pierre, un mécanisme sourd se déclenche."]
		return []

	func orientation(i: int) -> int:
		return etat[i]

	func est_resolu() -> bool:
		return resolu

	## Un quart de tour (sens horaire). Renvoie vrai si l'énigme vient d'être résolue.
	func tourner(i: int) -> bool:
		if resolu:
			return false
		etat[i] = (int(etat[i]) + 1) % 4
		_angles[i] -= PI / 2.0
		var piv: Node3D = _pivots[i]
		if is_inside_tree():
			create_tween().tween_property(piv, "rotation:y", _angles[i], 0.35).set_trans(Tween.TRANS_SINE)
		else:
			piv.rotation.y = _angles[i]
		son(["impactPlate_medium_000", "creak1"], positions[i] + Vector3(0, 1, 0), -3.0)
		secousse(0.1)
		if _juste():
			resolu = true
			signaler("meca:%s:resolu" % ident)
			son(["doorOpen_1"], positions[i], 2.0)
			secousse(0.4)
			if on_fini.is_valid():
				on_fini.call()
			return true
		return false

	func _juste() -> bool:
		for i in positions.size():
			if int(etat[i]) != int(solution[i]) % 4:
				return false
		return true

	func _placer(k: Array) -> void:
		for i in positions.size():
			etat[i] = k[i]
			_angles[i] = -int(k[i]) * PI / 2.0
			(_pivots[i] as Node3D).rotation.y = _angles[i]

	func restaurer() -> void:
		if vu("meca:%s:resolu" % ident):
			if not resolu:
				_placer(solution.map(func(v: int) -> int: return v % 4))
				resolu = true
				fin_restauree()
		elif not resolu:
			_placer(_depart)

# ------------------------------------------------------------------ braseros
class Braseros extends Base:
	var positions: Array = []
	var ordre: Array = []
	var allumes: Array = []           # indices des braseros allumés, dans l'ordre où on les a allumés
	var resolu := false
	var _flammes: Array = []
	var _braises: Array = []
	var _lumieres: Array = []
	var _inter_i: Array = []
	var _mat_braise_eteinte: StandardMaterial3D
	var _mat_braise_vive: StandardMaterial3D

	func construire() -> void:
		var pierre := mat(Palette.ROCHE, "meca_brasero", Vector2(1, 1), Color(0.85, 0.87, 0.95))
		var fer := mat(Palette.ACIER, "meca_fer", Vector2(1, 1), Color(0.6, 0.62, 0.68))
		_mat_braise_eteinte = Palette.lueur(Color(0.1, 0.08, 0.08))
		_mat_braise_vive = Palette.lueur(Color(1.0, 0.45, 0.12))
		for i in positions.size():
			var p: Vector3 = positions[i]
			Mecanisme.cylindre(self, 0.34, 0.28, 0.14, p + Vector3(0, 0.07, 0), pierre)
			Mecanisme.cylindre(self, 0.11, 0.14, 0.7, p + Vector3(0, 0.49, 0), pierre)
			Mecanisme.cylindre(self, 0.22, 0.42, 0.3, p + Vector3(0, 0.99, 0), fer)               # vasque
			Mecanisme.cylindre(self, 0.44, 0.44, 0.06, p + Vector3(0, 1.12, 0), fer)             # rebord
			var br := Mecanisme.cylindre(self, 0.36, 0.36, 0.04, p + Vector3(0, 1.1, 0), Palette.lueur(Color.BLACK))
			br.material_override = _mat_braise_eteinte
			_braises.append(br)
			Mecanisme.collision(self, p + Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7))
			var fl := Torche.flamme_fixe(self, p + Vector3(0, 1.14, 0), 1.7, float(i) * 0.37)
			fl.visible = false
			_flammes.append(fl)
			var l := OmniLight3D.new()
			l.position = p + Vector3(0, 1.7, 0)
			l.light_color = Color(1.0, 0.62, 0.3)
			l.light_energy = 0.0
			l.omni_range = 5.5
			l.shadow_enabled = false
			add_child(l)
			_lumieres.append(l)

	func _interactions() -> void:
		for i in positions.size():
			var it := interactif((positions[i] as Vector3) + Vector3(0, 1.1, 0), "Brasero", "Allumer le brasero", _activer.bind(i), func() -> bool: return not resolu, 2.0)
			_inter_i.append(it)

	func est_resolu() -> bool:
		return resolu

	func est_allume(i: int) -> bool:
		return allumes.has(i)

	func _activer(i: int) -> Array:
		return activer(i)

	## Allume ou éteint le brasero i. Renvoie les lignes de dialogue éventuelles.
	func activer(i: int) -> Array:
		if resolu:
			return []
		if allumes.has(i):
			# éteindre : ce brasero et tous ceux allumés après lui
			allumes = allumes.slice(0, allumes.find(i))
			_maj()
			son(["cloth2"], positions[i] + Vector3(0, 1, 0), -4.0)
			return []
		if int(ordre[allumes.size()]) == i:
			allumes.append(i)
			_maj()
			son(["knifeSlice2"], positions[i] + Vector3(0, 1, 0), -6.0)
			if allumes.size() == ordre.size():
				resolu = true
				signaler("meca:%s:resolu" % ident)
				son(["doorOpen_1"], positions[i], 2.0)
				secousse(0.35)
				return fin(["Les flammes s’élèvent d’un seul souffle. Quelque part, la pierre cède."])
			return []
		# mauvais ordre : tout s'éteint
		allumes.clear()
		_maj()
		son(["impactPlate_medium_001"], positions[i] + Vector3(0, 1, 0), 0.0)
		secousse(0.2)
		return ["Le brasero prend… puis toutes les flammes s’éteignent d’un souffle glacé. Ce n’était pas le bon ordre."]

	func _maj() -> void:
		for i in positions.size():
			var on: bool = allumes.has(i)
			(_flammes[i] as Node3D).visible = on
			(_braises[i] as MeshInstance3D).material_override = _mat_braise_vive if on else _mat_braise_eteinte
			(_lumieres[i] as OmniLight3D).light_energy = 1.8 if on else 0.0
			var it: Node3D = _inter_i[i] if i < _inter_i.size() else null
			if it != null:
				it.verbe = "Éteindre le brasero" if on else "Allumer le brasero"

	func restaurer() -> void:
		if vu("meca:%s:resolu" % ident):
			if not resolu:
				allumes = ordre.duplicate()
				resolu = true
				_maj()
				fin_restauree()
		elif not resolu:
			allumes.clear()
			_maj()

# ------------------------------------------------------------------ socles de sceaux
class Socles extends Base:
	var positions: Array = []
	var objets: Array = []
	var poses: Array = []
	var complet := false
	var _fragments: Array = []
	var _lumieres: Array = []

	func construire() -> void:
		var pierre := mat(Palette.ROCHE, "meca_socle", Vector2(1, 1), Color(0.85, 0.88, 0.98))
		var grave := mat(Palette.ACIER, "meca_socle_haut", Vector2(1, 1), Color(0.55, 0.6, 0.7))
		for i in positions.size():
			var p: Vector3 = positions[i]
			Mecanisme.boite(self, Vector3(0.9, 0.2, 0.9), p + Vector3(0, 0.1, 0), pierre)
			Mecanisme.boite(self, Vector3(0.62, 0.8, 0.62), p + Vector3(0, 0.6, 0), pierre)
			Mecanisme.boite(self, Vector3(0.82, 0.14, 0.82), p + Vector3(0, 1.07, 0), grave)
			Mecanisme.boite(self, Vector3(0.28, 0.03, 0.28), p + Vector3(0, 1.16, 0), Palette.lueur(Color(0.05, 0.05, 0.07)))   # creux du fragment
			Mecanisme.collision(self, p + Vector3(0, 0.6, 0), Vector3(0.9, 1.2, 0.9))
			var f := Node3D.new()
			f.position = p + Vector3(0, 1.3, 0)
			f.visible = false
			add_child(f)
			var couleur := _couleur(String(objets[i]))
			Mecanisme.boite(f, Vector3(0.16, 0.3, 0.06), Vector3.ZERO, Palette.lueur(couleur), Vector3(0.2, 0.4, 0.3))
			Mecanisme.boite(f, Vector3(0.08, 0.18, 0.05), Vector3(0.07, -0.05, 0.02), Palette.lueur(couleur.darkened(0.25)), Vector3(0.0, 0.7, -0.5))
			var l := OmniLight3D.new()
			l.light_color = couleur
			l.light_energy = 0.9
			l.omni_range = 3.0
			l.shadow_enabled = false
			f.add_child(l)
			_fragments.append(f)
			poses.append(false)

	static func _couleur(id: String) -> Color:
		if id.contains("givre"):
			return Color(0.55, 0.85, 1.0)
		if id.contains("eau"):
			return Color(0.3, 0.8, 0.75)
		return Color(0.88, 0.82, 0.62)

	func _interactions() -> void:
		for i in positions.size():
			interactif((positions[i] as Vector3) + Vector3(0, 1.2, 0), "Socle du sceau", "Poser le fragment", _poser.bind(i), func() -> bool: return not poses[i])

	func est_complet() -> bool:
		return complet

	func _poser(i: int) -> Array:
		return poser(i)

	## Pose l'objet attendu sur le socle i s'il est dans le sac (il est consommé). Renvoie les lignes de dialogue.
	func poser(i: int) -> Array:
		if poses[i]:
			return []
		var id: String = objets[i]
		if joueur == null or not joueur.inventaire.a(id):
			return ["Un creux à la forme d’un éclat de sceau. Il y manque : %s." % Inventaire.OBJETS[id]["nom"]]
		joueur.inventaire.retirer(id)
		_garnir(i)
		signaler("meca:%s:s%d" % [ident, i])
		son(["impactPlate_medium_000", "sword-unsheathe"], positions[i] + Vector3(0, 1, 0), -2.0)
		secousse(0.2)
		if not poses.has(false):
			complet = true
			signaler("meca:%s:resolu" % ident)
			son(["doorOpen_1"], positions[i], 2.0)
			secousse(0.45)
			return fin(["Le dernier fragment se scelle. Les trois sceaux sont rétablis, la porte de pierre s’ébranle."])
		return []

	func _garnir(i: int) -> void:
		poses[i] = true
		(_fragments[i] as Node3D).visible = true

	func restaurer() -> void:
		for i in positions.size():
			if vu("meca:%s:s%d" % [ident, i]) and not poses[i]:
				_garnir(i)
		if not complet and not poses.has(false) and not positions.is_empty():
			complet = true
			fin_restauree()

# ------------------------------------------------------------------ mur fragile
class Mur extends Base:
	var pos := Vector3.ZERO
	var taille := Vector3.ONE
	var lacet := 0.0
	var casse := false
	var _mesh: MeshInstance3D
	var _corps: StaticBody3D
	var _poussiere: GPUParticles3D
	var _indice_t := 0.0

	func construire() -> void:
		position = pos
		rotation.y = lacet
		var m: Material = ctx.get("materiau", null)
		if m == null:
			var sm := Palette.materiau(Mecanisme.texture_fissures(Palette.ROCHE, 4242 + ident.hash() % 1000, 7), Vector2(maxf(taille.x, taille.z) * 0.5, taille.y * 0.5), Color(0.92, 0.93, 1.0))
			m = sm
		_mesh = Mecanisme.boite(self, taille, Vector3.ZERO, m)
		_corps = Mecanisme.collision(self, Vector3.ZERO, taille)
		if ctx.get("fissures", false):
			_fissurer()
		# courant d'air : un filet de poussière monte du pied du mur, de chaque côté
		_poussiere = Mecanisme.particules(self, Vector3(0, -taille.y * 0.5 + 0.1, 0), Color(0.55, 0.53, 0.5), 10, 3.0, 0.18, Vector3.UP, 25.0, Vector3(taille.x * 0.4, 0.05, taille.z * 0.7), 0.025)
		add_to_group("cassables")

	## Indice visible (grotte) : fissures sombres en zigzag sur les deux faces, sans toucher à la collision ni à la solution.
	func _fissurer() -> void:
		var noir := Mecanisme.materiau(Palette.ROCHE, "meca_gravats", Vector2.ONE, Color(0.06, 0.06, 0.08))
		var rng := RandomNumberGenerator.new()
		rng.seed = ident.hash()
		for face in [1.0, -1.0]:
			for k in 3:
				var x := (k - 1) * taille.x * 0.28 + rng.randf_range(-0.2, 0.2)
				var y := taille.y * 0.5 - 0.15
				for j in 7:
					var ang := rng.randf_range(-0.5, 0.5)
					var l := rng.randf_range(0.28, 0.5)
					Mecanisme.boite(self, Vector3(0.05, l, 0.02), Vector3(x, y - l * 0.5, face * (taille.z * 0.5 + 0.012)), noir, Vector3(0, 0, ang))
					x += sin(-ang) * l
					y -= cos(ang) * l
					if y < -taille.y * 0.5 + 0.1:
						break
	func est_casse() -> bool:
		return casse

	## Point du mur le plus proche d'un point donné (pour la portée du coup de mains.gd).
	func point_proche(o: Vector3) -> Vector3:
		var l := to_local(o)
		var h := taille * 0.5
		return to_global(Vector3(clampf(l.x, -h.x, h.x), clampf(l.y, -h.y, h.y), clampf(l.z, -h.z, h.z)))

	## Appelé par mains.gd. Renvoie vrai si le mur cède.
	func frapper(puissant: bool, _origine: Vector3) -> bool:
		if casse:
			return false
		if not puissant:
			son(["impactPlate_medium_001"], Vector3.ZERO, -8.0)
			var t := Time.get_ticks_msec() / 1000.0
			if dialogue != null and t - _indice_t > 4.0:
				_indice_t = t
				dialogue.dire_au_passage("Vous", "Ça sonne creux… Il faudrait un coup plus puissant pour le faire céder.")
			return false
		casser(true)
		return true

	func casser(avec_effets := true) -> void:
		if casse:
			return
		casse = true
		remove_from_group("cassables")
		signaler("meca:%s:casse" % ident)
		_corps.queue_free()
		_mesh.visible = false
		_poussiere.emitting = false
		var gris := Color(0.5, 0.48, 0.45)
		var gravats := Mecanisme.materiau(Palette.ROCHE, "meca_gravats", Vector2.ONE, Color(0.9, 0.9, 0.95))
		var rng := RandomNumberGenerator.new()
		rng.seed = ident.hash()
		for i in 5:
			var s := rng.randf_range(0.12, 0.3)
			Mecanisme.boite(self, Vector3(s, s * 0.7, s), Vector3(rng.randf_range(-taille.x * 0.4, taille.x * 0.4), -taille.y * 0.5 + s * 0.35, rng.randf_range(-taille.z * 1.2, taille.z * 1.2)), gravats, Vector3(rng.randf(), rng.randf(), rng.randf()))
		if avec_effets and is_inside_tree():
			Effets.eclats(self, global_position, gris, 40, 3.0)
			Effets.eclats(self, global_position + Vector3(0, taille.y * 0.2, 0), Color(0.7, 0.68, 0.64), 24, 1.5)
			son(["impactPlate_medium_000", "impactWood_heavy_000"], Vector3.ZERO, 4.0)
			secousse(0.6)
			fin([])
		elif not avec_effets:
			fin_restauree()

	func restaurer() -> void:
		if vu("meca:%s:casse" % ident) and not casse:
			casser(false)
