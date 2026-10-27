class_name EffetsMagie
## CONTRAT entre la logique de la magie (branche magie/sorts) et ses visuels (branche magie/effets, qui remplace ce
## fichier). Ici : VERSION DE SECOURS, bouchons simples (sphères, boîtes et lueurs colorées, unshaded, compatibles Web)
## pour tester la logique sans attendre les vrais effets. Les signatures sont figées : ne pas les changer.
## Écoles : "feu", "glace", "electricite", "tenebres", "soin", "protection".
##
##   aura_main(main, ecole, intensite)                     0 = éteinte ; charge = intensité croissante (0..1, 1,5 en double)
##   jet(ecole, origine, direction, portee, largeur, actif) canalisé, appelé à chaque image tant qu'actif ; actif=false l'éteint
##   projectile_visuel(ecole, forme) -> Node3D              "boule", "eclat", "lance", "trait", "orbe" ; la logique le déplace
##   impact(ecole, position, normale, force)
##   zone(ecole, position, rayon, duree)                    nova, explosion, tempête
##   chaine(ecole, points)                                  chaîne d'éclairs, drain multi
##   statut_cible(cible, statut, duree)                     brulure, gel, choc, corruption (duree 0 = retiré)
##   enchant_arme(arme, ecole, actif)
##   reaction(nom, position, rayon)                         vapeur, decharge, flammes_obscures…
##   double(ecole, actif)                                   effet supplémentaire de double incantation

const COULEURS := {
	"feu": Color(1.0, 0.45, 0.1), "glace": Color(0.55, 0.85, 1.0), "electricite": Color(0.62, 0.62, 1.0),
	"tenebres": Color(0.6, 0.2, 0.95), "soin": Color(1.0, 0.9, 0.5), "protection": Color(0.7, 0.85, 1.0),
	"brulure": Color(1.0, 0.45, 0.1), "brulure_obscure": Color(0.55, 0.1, 0.7), "gel": Color(0.55, 0.85, 1.0),
	"choc": Color(0.62, 0.62, 1.0), "corruption": Color(0.6, 0.2, 0.95),
	"vapeur": Color(0.9, 0.92, 0.95), "decharge": Color(0.7, 0.8, 1.0), "decharge_incendiaire": Color(1.0, 0.7, 0.4),
	"cristaux_corrompus": Color(0.5, 0.4, 1.0), "flammes_obscures": Color(0.5, 0.1, 0.6), "arcs_violets": Color(0.75, 0.35, 1.0),
}

static var _materiaux := {}
static var _jets := {}
## Désactive tout rendu (tests sans fenêtre qui comptent les appels) : les appels sont comptés quand même.
static var muet := false
## Compteur d'appels par fonction (tests : le contrat est bien appelé).
static var appels := {}

static func couleur(nom: String) -> Color:
	return COULEURS.get(nom, Color(1, 1, 1))

static func _compter(f: String) -> void:
	appels[f] = int(appels.get(f, 0)) + 1

static func _racine() -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return null
	return arbre.current_scene if arbre.current_scene != null else arbre.root

static func _mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var cle := "%s_%.2f" % [c.to_html(), alpha]
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiaux[cle] = m
	return _materiaux[cle]

static func _sphere(r: float, c: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = _mat(c, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _ephemere(n: Node3D, duree: float, grossir := 1.0) -> void:
	var tw := n.create_tween()
	if grossir != 1.0:
		tw.tween_property(n, "scale", n.scale * grossir, duree)
	else:
		tw.tween_interval(duree)
	tw.tween_callback(n.queue_free)

# ------------------------------------------------------------------ contrat

static func aura_main(main: Node3D, ecole: String, intensite: float) -> void:
	_compter("aura_main")
	if main == null or not is_instance_valid(main):
		return
	var a := main.get_node_or_null("AuraMagie") as MeshInstance3D
	if intensite <= 0.0:
		if a != null:
			a.queue_free()
		return
	if muet:
		return
	if a == null:
		a = _sphere(0.035, couleur(ecole), 0.75)
		a.name = "AuraMagie"
		main.add_child(a)
		var l := OmniLight3D.new()
		l.light_color = couleur(ecole)
		l.omni_range = 1.2
		l.shadow_enabled = false
		a.add_child(l)
	a.material_override = _mat(couleur(ecole), 0.75)
	a.scale = Vector3.ONE * (0.6 + intensite * 1.4)
	(a.get_child(0) as OmniLight3D).light_energy = 0.4 + intensite * 1.2

static func jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif: bool) -> void:
	_compter("jet")
	var cle := origine.get_instance_id() if origine != null else 0
	var n: MeshInstance3D = _jets.get(cle)
	if n != null and not is_instance_valid(n):
		n = null
	if not actif or muet or origine == null or not is_instance_valid(origine):
		if n != null:
			n.queue_free()
		_jets.erase(cle)
		return
	if n == null:
		n = MeshInstance3D.new()
		var b := CylinderMesh.new()
		b.top_radius = 0.5
		b.bottom_radius = 0.12
		b.height = 1.0
		b.radial_segments = 6
		b.rings = 1
		n.mesh = b
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := _racine()
		if r == null:
			return
		r.add_child(n)
		_jets[cle] = n
	n.material_override = _mat(couleur(ecole), 0.55)
	var d := direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var o := origine.global_position
	var haut := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	var base := Basis.looking_at(d, haut)   # -Z = d
	# cylindre le long de Y : on le couche le long de -Z (direction), centré à mi-portée
	n.global_transform = Transform3D(base * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(largeur, portee, largeur)), o + d * portee * 0.5)

static func projectile_visuel(ecole: String, forme: String) -> Node3D:
	_compter("projectile_visuel")
	var n := Node3D.new()
	n.name = "Projectile_%s_%s" % [ecole, forme]
	if muet:
		return n
	var c := couleur(ecole)
	match forme:
		"eclat", "lance":
			var mi := MeshInstance3D.new()
			var b := PrismMesh.new()
			var l := 0.35 if forme == "eclat" else 0.9
			b.size = Vector3(0.08, l, 0.08) if forme == "eclat" else Vector3(0.14, l, 0.14)
			mi.mesh = b
			mi.material_override = _mat(c)
			mi.rotation.x = -PI * 0.5   # pointe vers -Z (sens du vol)
			n.add_child(mi)
		"trait":
			var mi2 := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.06, 0.06, 0.6)
			mi2.mesh = bx
			mi2.material_override = _mat(c)
			n.add_child(mi2)
		_:
			n.add_child(_sphere(0.16 if forme == "boule" else 0.12, c))
	var lu := OmniLight3D.new()
	lu.light_color = c
	lu.light_energy = 1.2
	lu.omni_range = 3.0
	lu.shadow_enabled = false
	n.add_child(lu)
	return n

static func impact(ecole: String, position: Vector3, normale: Vector3, force: float) -> void:
	_compter("impact")
	if muet:
		return
	var r := _racine()
	if r == null:
		return
	var s := _sphere(0.07, couleur(ecole), 0.6)
	r.add_child(s)
	s.global_position = position + normale * 0.05
	_ephemere(s, 0.18, 1.0 + 1.5 * clampf(force, 0.2, 2.0))

static func zone(ecole: String, position: Vector3, rayon: float, duree: float) -> void:
	_compter("zone")
	if muet:
		return
	var r := _racine()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = 0.08
	c.radial_segments = 16
	c.rings = 1
	mi.mesh = c
	mi.material_override = _mat(couleur(ecole), 0.45)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = position + Vector3(0, 0.05, 0)
	_ephemere(mi, maxf(duree, 0.35))

static func chaine(ecole: String, points: Array[Vector3]) -> void:
	_compter("chaine")
	if muet or points.size() < 2:
		return
	var r := _racine()
	if r == null:
		return
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.04, 0.04, maxf(a.distance_to(b), 0.01))
		mi.mesh = bx
		mi.material_override = _mat(couleur(ecole))
		r.add_child(mi)
		var haut := Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis.looking_at(b - a, haut), (a + b) * 0.5)
		_ephemere(mi, 0.18)

static func statut_cible(cible: Node3D, statut: String, duree: float) -> void:
	_compter("statut_cible")
	if cible == null or not is_instance_valid(cible):
		return
	var nom := "Statut_" + statut
	var n := cible.get_node_or_null(nom) as Node3D
	if duree <= 0.0:
		if n != null:
			n.queue_free()
		return
	if muet:
		return
	if n == null:
		n = _sphere(0.09, couleur(statut), 0.85)
		n.name = nom
		cible.add_child(n)
		var k := cible.get_child_count() % 4
		n.position = Vector3(-0.3 + 0.2 * k, 2.15, 0)
	n.set_meta("fin", Time.get_ticks_msec() + int(duree * 1000.0))

static func enchant_arme(arme: Node3D, ecole: String, actif: bool) -> void:
	_compter("enchant_arme")
	if arme == null or not is_instance_valid(arme):
		return
	var n := arme.get_node_or_null("EnchantMagie") as Node3D
	if not actif:
		if n != null:
			n.queue_free()
		return
	if muet:
		return
	if n == null:
		n = Node3D.new()
		n.name = "EnchantMagie"
		arme.add_child(n)
		for i in 4:
			var s := _sphere(0.02, couleur(ecole), 0.8)
			s.position = Vector3(0, 0.25 + i * 0.17, 0)
			n.add_child(s)
		var l := OmniLight3D.new()
		l.light_color = couleur(ecole)
		l.light_energy = 0.8
		l.omni_range = 1.0
		l.position = Vector3(0, 0.5, 0)
		n.add_child(l)

static func reaction(nom: String, position: Vector3, rayon: float) -> void:
	_compter("reaction")
	if muet:
		return
	var r := _racine()
	if r == null:
		return
	var s := _sphere(rayon * 0.25, couleur(nom), 0.35)
	r.add_child(s)
	s.global_position = position
	_ephemere(s, 0.35, 2.0)

static func double(ecole: String, actif: bool) -> void:
	_compter("double")
	if muet:
		return
	var r := _racine()
	if r == null:
		return
	var n := r.get_node_or_null("DoubleMagie")
	if not actif:
		if n != null:
			n.queue_free()
		return
	if n == null:
		var l := OmniLight3D.new()
		l.name = "DoubleMagie"
		l.light_color = couleur(ecole)
		l.light_energy = 2.0
		l.omni_range = 5.0
		l.shadow_enabled = false
		r.add_child(l)
		var cam := r.get_viewport().get_camera_3d() if r.get_viewport() else null
		if cam != null:
			l.global_position = cam.global_position + cam.global_transform.basis * Vector3(0, -0.2, -0.6)
