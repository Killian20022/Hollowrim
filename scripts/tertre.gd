extends Node3D
## Le tertre de Svanhild : un tumulus au nord du cercle runique et, sous terre, la crypte.
## La crypte est construite très en dessous du monde ; y entrer téléporte le joueur
## (fondu au noir) et coupe la lune, la neige et le cycle du ciel.
##
## Plan de la crypte (repère local, l'entrée regarde +Z, on s'enfonce vers -Z) :
##   entrée (escalier) → couloir des niches → salle des piliers (corps d'Eirik à l'ouest,
##   levier à l'est) → herse → tombeau de Svanhild.

signal entree(dedans: bool)

const PROFONDEUR := -140.0

var monde: Node3D
var joueur: CharacterBody3D
var dialogue: Control
var quetes: Node
var hud: Control
var porte_dehors := Vector3.ZERO   # posé par le monde : devant la porte du tumulus
var orientation := 0.0             # lacet de la façade du tumulus

var crypte: Node3D
var corps: StaticBody3D
var dedans := false
var herse: Node3D
var _herse_ouverte := false
var _svanhild: CharacterBody3D = null
var _svanhild_levee := false
var _anneau_rendu := false
var _lueur_tombe: OmniLight3D
var _manche: Node3D
var _flammes: Array = []
var _t := 0.0

var m_pierre: ShaderMaterial
var m_dalle: ShaderMaterial
var m_poutre: ShaderMaterial
var m_fer: ShaderMaterial
var m_neige: ShaderMaterial

func _ready() -> void:
	m_pierre = Palette.materiau(Palette.tex("pierre_crypte", ["#1c1f26", "#272b34", "#323743", "#3f4553"], 4, 0.5), Vector2(2, 2))
	m_dalle = Palette.materiau(Palette.tex("dalle", ["#15171c", "#1e2128", "#282c35", "#333844"], 2, 0.35), Vector2(4, 4))
	m_poutre = Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(0.5, 2), Color(0.6, 0.58, 0.56))
	m_fer = Palette.materiau(Palette.tex("acier", Palette.ACIER, 4, 0.3), Vector2.ONE, Color(0.4, 0.42, 0.5))
	m_neige = Palette.materiau(Palette.tex_neige, Vector2(4, 4))
	_tumulus()
	crypte = Node3D.new()
	# sous le cercle runique, dans les limites de la carte (±108 m)
	crypte.position = Vector3(global_position.x, PROFONDEUR, global_position.z + 25.0)
	monde.add_child(crypte)
	corps = StaticBody3D.new()
	crypte.add_child(corps)
	_construire_crypte()

func _process(dt: float) -> void:
	_t += dt
	for f in _flammes:
		f[0].light_energy = f[1] * (0.85 + sin(_t * 7.0 + f[2]) * 0.08 + randf() * 0.07)
	if not dedans and joueur.global_position.distance_to(porte_dehors) < 9.0:
		quetes.signaler("lieu:tertre")
	if _lueur_tombe:
		var cible := 3.2 if _anneau_rendu else 1.6 + sin(_t * 1.3) * 0.3
		_lueur_tombe.light_energy = lerpf(_lueur_tombe.light_energy, cible, 1.0 - exp(-2.0 * dt))
	# Svanhild se lève quand on approche du sarcophage avec l'anneau
	if dedans and not _svanhild_levee and joueur.inventaire.a("anneau_givre"):
		if joueur.global_position.distance_to(crypte.to_global(Vector3(0, 0, -50))) < 8.0:
			_lever_svanhild()

# --- extérieur ---------------------------------------------------------------------

func _tumulus() -> void:
	# butte de terre enneigée, posée sur le sol (le nœud est au pied de la façade)
	var butte := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 7.5
	s.height = 15.0
	s.radial_segments = 12
	s.rings = 6
	butte.mesh = s
	butte.material_override = m_neige
	butte.scale = Vector3(1, 0.42, 1)
	butte.position = Vector3(0, -0.6, -6.5)
	add_child(butte)
	var corps_dehors := StaticBody3D.new()
	add_child(corps_dehors)
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.8
	cyl.height = 4.0
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position = Vector3(0, 1.0, -6.5)
	corps_dehors.add_child(cs)
	# façade : deux pierres dressées, un linteau, une dalle sombre pour la porte
	for x in [-1.3, 1.3]:
		_boite(self, Vector3(0.8, 3.0, 0.8), Transform3D(Basis(), Vector3(x, 1.3, -0.4)), m_pierre, corps_dehors)
	_boite(self, Vector3(3.6, 0.7, 1.0), Transform3D(Basis(), Vector3(0, 3.0, -0.4)), m_pierre, corps_dehors)
	_boite(self, Vector3(1.9, 2.6, 0.2), Transform3D(Basis(), Vector3(0, 1.2, -0.75)), m_dalle, corps_dehors)
	# runes qui luisent sur le linteau
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 0.8
	lueur.omni_range = 5.0
	lueur.position = Vector3(0, 2.6, 0.6)
	add_child(lueur)
	var runes := _boite(self, Vector3(2.2, 0.12, 0.04), Transform3D(Basis(), Vector3(0, 3.0, 0.11)), Palette.lueur(Color(0.5, 1.4, 1.9)))
	runes.name = "Runes"
	_interactif(self, Vector3(0, 1.2, 0.3), "Tertre de Svanhild", "Entrer dans le tertre", func() -> Array: return _passer(true))

# --- crypte --------------------------------------------------------------------------

## Pièce rectangulaire : sol, plafond et quatre murs, avec des ouvertures [côté, centre, largeur].
func _salle(x0: float, x1: float, z0: float, z1: float, h: float, ouvertures: Array, y := 0.0) -> void:
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var lx := absf(x1 - x0)
	var lz := absf(z1 - z0)
	_boite(crypte, Vector3(lx + 0.6, 0.4, lz + 0.6), Transform3D(Basis(), Vector3(cx, y - 0.2, cz)), m_dalle, corps)
	_boite(crypte, Vector3(lx + 0.6, 0.4, lz + 0.6), Transform3D(Basis(), Vector3(cx, y + h + 0.2, cz)), m_pierre, corps)
	for cote in ["nord", "sud", "ouest", "est"]:
		var horizontal: bool = cote in ["nord", "sud"]
		var fixe: float = (minf(z0, z1) if cote == "nord" else maxf(z0, z1)) if horizontal else (minf(x0, x1) if cote == "ouest" else maxf(x0, x1))
		var debut: float = minf(x0, x1) if horizontal else minf(z0, z1)
		var fin: float = maxf(x0, x1) if horizontal else maxf(z0, z1)
		var morceaux := [[debut, fin]]
		for o in ouvertures:
			if o[0] != cote:
				continue
			var nouveaux := []
			for m in morceaux:
				var a: float = o[1] - o[2] * 0.5
				var b: float = o[1] + o[2] * 0.5
				if b <= m[0] or a >= m[1]:
					nouveaux.append(m)
				else:
					if a > m[0]:
						nouveaux.append([m[0], a])
					if b < m[1]:
						nouveaux.append([b, m[1]])
			morceaux = nouveaux
		# linteaux : les passages font 3 m de haut, la pièce peut être plus haute
		if h > 3.0:
			for o in ouvertures:
				if o[0] == cote:
					var pos_l := Vector3(o[1], y + (3.0 + h) * 0.5, fixe) if horizontal else Vector3(fixe, y + (3.0 + h) * 0.5, o[1])
					var taille_l := Vector3(o[2], h - 3.0, 0.6) if horizontal else Vector3(0.6, h - 3.0, o[2])
					_boite(crypte, taille_l, Transform3D(Basis(), pos_l), m_pierre, corps)
		for m in morceaux:
			var longueur: float = m[1] - m[0]
			if longueur < 0.05:
				continue
			var milieu: float = (m[0] + m[1]) * 0.5
			var pos := Vector3(milieu, y + h * 0.5, fixe) if horizontal else Vector3(fixe, y + h * 0.5, milieu)
			var taille := Vector3(longueur + 0.6, h, 0.6) if horizontal else Vector3(0.6, h, longueur + 0.6)
			_boite(crypte, taille, Transform3D(Basis(), pos), m_pierre, corps)

func _construire_crypte() -> void:
	# entrée et escalier qui remonte vers la sortie
	_salle(-3, 3, 4, -6, 3.6, [["nord", 0.0, 3.2]])
	for i in 6:
		_boite(crypte, Vector3(3.0, 0.3 * (i + 1), 0.6), Transform3D(Basis(), Vector3(0, 0.15 * (i + 1), 3.6 - i * 0.6)), m_dalle)
	_interactif(crypte, Vector3(0, 1.6, 1.5), "Sortie", "Sortir du tertre", func() -> Array: return _passer(false))
	_brasero(Vector3(-2.3, 0, -5.2))
	_brasero(Vector3(2.3, 0, -5.2))

	# couloir des niches : des gardiens endormis debout contre les murs
	_salle(-1.6, 1.6, -6, -18, 3.0, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2]])
	for z in [-9.0, -13.0, -16.5]:
		for x in [-1.25, 1.25]:
			_boite(crypte, Vector3(0.3, 2.6, 1.2), Transform3D(Basis(), Vector3(x * 1.05, 1.3, z)), m_dalle)
	_gardien("sbire", Vector3(-1.0, 0, -11.0), PI * 0.5, true)
	_gardien("sbire", Vector3(1.0, 0, -15.0), -PI * 0.5, true)

	# salle des piliers
	_salle(-7, 7, -18, -32, 4.6, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2], ["ouest", -25.0, 3.0]])
	for x in [-3.5, 3.5]:
		for z in [-21.5, -28.5]:
			_boite(crypte, Vector3(0.9, 4.6, 0.9), Transform3D(Basis(), Vector3(x, 2.3, z)), m_pierre, corps)
	_brasero(Vector3(-6.0, 0, -19.0))
	_brasero(Vector3(6.0, 0, -31.0))
	_brasero(Vector3(6.0, 0, -19.0))
	_gardien("guerrier", Vector3(-4.0, 0, -26.0), 0.4, false)
	_gardien("sbire", Vector3(3.0, 0, -24.0), 2.0, true)
	_gardien("sbire", Vector3(-2.0, 0, -30.0), -0.8, true)

	# alcôve d'Eirik, à l'ouest
	_salle(-11, -7, -23, -27, 3.0, [["est", -25.0, 3.0]])
	var eirik := Humain.creer({"corps": "homme", "cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.85, 0.55, 0.3), "peau": Color(0.75, 0.75, 0.8),
		"tenue": {"tunique": Color(0.4, 0.5, 0.42), "pantalon": Color(0.6, 0.55, 0.5), "bottes": Color.WHITE, "ceinture": Color.WHITE, "mante": Color(0.9, 0.85, 0.8)}})
	eirik.position = Vector3(-9.3, 0.02, -25.0)
	eirik.rotation.y = 1.2
	crypte.add_child(eirik)
	var ap: AnimationPlayer = eirik.get_node("Animations")
	ap.play("Death01")
	ap.seek(ap.get_animation("Death01").length - 0.05, true)
	ap.pause()
	_interactif(crypte, Vector3(-9.3, 0.6, -25.0), "Note d’Eirik", "Fouiller le corps d’Eirik", _fouiller_eirik, Callable(), true)
	_flamme(crypte, Vector3(-10.4, 0.15, -23.6), 0.3, 0.6, 4.0)  # chandelle d'Eirik

	# couloir de la herse
	_salle(-1.6, 1.6, -32, -42, 3.2, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2]])
	herse = Node3D.new()
	herse.position = Vector3(0, 0, -33.0)
	crypte.add_child(herse)
	var corps_herse := StaticBody3D.new()
	herse.add_child(corps_herse)
	for i in 7:
		_boite(herse, Vector3(0.08, 3.1, 0.08), Transform3D(Basis(), Vector3(-1.35 + i * 0.45, 1.55, 0)), m_fer)
	for y in [0.6, 1.8, 2.8]:
		_boite(herse, Vector3(3.0, 0.08, 0.08), Transform3D(Basis(), Vector3(0, y, 0)), m_fer)
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 3.2, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = bs
	cs.position = Vector3(0, 1.6, 0)
	corps_herse.add_child(cs)
	# levier, contre le mur est de la salle des piliers
	var levier := Node3D.new()
	levier.position = Vector3(6.55, 1.1, -25.0)
	crypte.add_child(levier)
	_boite(levier, Vector3(0.2, 0.5, 0.3), Transform3D(), m_fer)
	var manche := _boite(levier, Vector3(0.06, 0.6, 0.06), Transform3D(Basis(Vector3.BACK, 0.5), Vector3(-0.15, 0.25, 0)), m_poutre)
	_manche = manche
	_interactif(crypte, Vector3(6.3, 1.1, -25.0), "Levier", "Tirer le levier", _tirer_levier, func() -> bool: return not _herse_ouverte)

	# tombeau de Svanhild
	_salle(-8, 8, -42, -58, 6.0, [["sud", 0.0, 3.2]])
	_boite(crypte, Vector3(6.0, 0.4, 5.0), Transform3D(Basis(), Vector3(0, 0.2, -51.0)), m_pierre, corps)
	_boite(crypte, Vector3(1.6, 1.0, 3.0), Transform3D(Basis(), Vector3(0, 0.9, -51.5)), m_pierre, corps)
	_boite(crypte, Vector3(1.8, 0.18, 3.2), Transform3D(Basis(), Vector3(0, 1.48, -51.5)), m_dalle)
	_boite(crypte, Vector3(1.0, 0.04, 2.2), Transform3D(Basis(), Vector3(0, 1.58, -51.5)), Palette.lueur(Color(0.4, 1.1, 1.6)))
	for x in [-6.5, 6.5]:
		for z in [-44.0, -56.0]:
			_boite(crypte, Vector3(1.0, 6.0, 1.0), Transform3D(Basis(), Vector3(x, 3.0, z)), m_pierre, corps)
	_lueur_tombe = OmniLight3D.new()
	_lueur_tombe.light_color = Color(0.4, 0.8, 1.0)
	_lueur_tombe.light_energy = 1.6
	_lueur_tombe.omni_range = 14.0
	_lueur_tombe.position = Vector3(0, 3.0, -51.5)
	crypte.add_child(_lueur_tombe)
	_brasero(Vector3(-5.0, 0, -45.0))
	_brasero(Vector3(5.0, 0, -45.0))
	_gardien("guerrier", Vector3(-3.0, 0, -45.5), PI, true, true)
	_gardien("guerrier", Vector3(3.0, 0, -45.5), PI, true, true)
	_givre(Vector3(0, 1.6, -51.5))
	_interactif(crypte, Vector3(0, 1.4, -49.6), "Inscription", "Lire l’inscription", func() -> Array: return quetes.texte("inscription_tombe"), func() -> bool: return not _peut_rendre())
	_interactif(crypte, Vector3(0, 1.4, -49.6), "Svanhild", "Replacer l’anneau sur le sarcophage", _rendre_anneau, _peut_rendre)

func _fouiller_eirik() -> Array:
	joueur.inventaire.ajouter("anneau_givre")
	joueur.inventaire.ajouter("amulette_eirik")
	hud.avis("+ Anneau de givre")
	hud.avis("+ Amulette d’Eirik")
	quetes.signaler("ramasse:anneau_givre")
	quetes.signaler("ramasse:amulette_eirik")
	return quetes.texte("note_eirik")

func _tirer_levier() -> Array:
	_herse_ouverte = true
	var t := create_tween()
	t.tween_property(_manche, "rotation:z", -0.5, 0.3)
	t.tween_property(herse, "position:y", 2.9, 2.5).set_trans(Tween.TRANS_SINE)
	Sons.jouer_a(self, ["impactMetal_heavy_000", "impactPlate_medium_000"], herse.global_position, 2.0)
	joueur.secousse = 0.3
	return []

func _rendre_anneau() -> Array:
	joueur.inventaire.retirer("anneau_givre")
	_anneau_rendu = true
	quetes.signaler("lieu:tombe_svanhild")
	joueur.secousse = 0.4
	Sons.jouer(self, ["sword-unsheathe"], -4.0)
	return []

## Remet le tertre dans l'état d'une partie chargée.
func restaurer(herse_ouverte: bool) -> void:
	if herse_ouverte:
		_herse_ouverte = true
		herse.position.y = 2.9
		_manche.rotation.z = -0.5
	_svanhild_levee = quetes.vus.has("tue:svanhild")
	_anneau_rendu = quetes.vus.has("lieu:tombe_svanhild")
	if quetes.vus.has("ramasse:anneau_givre"):
		for it in crypte.get_children():
			if it.get("verbe") == "Fouiller le corps d’Eirik":
				it.actif = false
	# partie sauvegardée sous terre
	if joueur.global_position.y < PROFONDEUR * 0.5:
		dedans = true
		entree.emit.call_deferred(true)

func _peut_rendre() -> bool:
	return not _anneau_rendu and joueur.inventaire.a("anneau_givre") and _svanhild_levee and (_svanhild == null or not is_instance_valid(_svanhild) or not _svanhild.vivant())

func _lever_svanhild() -> void:
	_svanhild_levee = true
	_svanhild = monde.creer_draugr("guerrier", crypte.to_global(Vector3(0, 0.05, -48.6)), PI, true, {
		"ident": "svanhild", "echelle": 1.12,
		"apparence": {"corps": "femme", "casque": "couronne_givre", "cheveux": "Hair_Long", "teinte_cheveux": Color(1.1, 1.15, 1.25), "tenue": {"tunique": Color(0.4, 0.45, 0.6), "mante": Color(0.8, 0.85, 0.95), "brassards": Color(0.8, 0.85, 0.9), "ceinture": Color(0.8, 0.8, 0.8), "bottes": Color(0.6, 0.6, 0.6)}},
		"vie_imposee": 260.0, "degats_imposes": 24.0, "nom_affiche": "Svanhild, Dame de givre",
	})
	var lignes: Array = quetes.texte("svanhild_reveil")
	for i in lignes.size():
		get_tree().create_timer(0.4 + i * 3.6).timeout.connect(func() -> void: dialogue.dire_au_passage("Svanhild", lignes[i]))
	_svanhild.mort.connect(func(_id: String) -> void:
		# l'événement « tue:svanhild » est déjà signalé par le monde à chaque mort de draugr
		var fin: Array = quetes.texte("svanhild_defaite")
		if not fin.is_empty():
			dialogue.dire_au_passage("Svanhild", fin[0]))

# --- passage dehors / dedans -----------------------------------------------------------

func _passer(vers_dedans: bool) -> Array:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 0.0, 1.0, 0.5)
	t.tween_callback(func() -> void:
		dedans = vers_dedans
		if vers_dedans:
			joueur.global_position = crypte.to_global(Vector3(0, 0.1, 0.5))
			joueur.rotation.y = crypte.global_rotation.y
		else:
			joueur.global_position = porte_dehors + Vector3(0, 0.2, 0)
			joueur.rotation.y = orientation
		joueur.velocity = Vector3.ZERO
		entree.emit(vers_dedans))
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 1.0, 0.0, 0.6)
	Sons.jouer(self, ["doorOpen_1", "creak1"], -4.0)
	return []

# --- briques --------------------------------------------------------------------------

func _boite(parent: Node3D, taille: Vector3, xf: Transform3D, mat: Material, solide: StaticBody3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if solide != null:
		var bs := BoxShape3D.new()
		bs.size = taille
		var cs := CollisionShape3D.new()
		cs.shape = bs
		solide.add_child(cs)
		cs.global_transform = mi.global_transform
	return mi

func _interactif(parent: Node3D, pos: Vector3, nom: String, verbe: String, action: Callable, condition := Callable(), unique := false) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = verbe
	it.condition = condition
	it.action = action
	it.unique = unique
	it.position = pos
	parent.add_child(it)
	return it

func _gardien(type: String, pos: Vector3, lacet: float, dort: bool, debout := false) -> void:
	monde.creer_draugr(type, crypte.to_global(pos + Vector3(0, 0.05, 0)), lacet, dort, {"debout": debout})

func _flamme(parent: Node3D, pos: Vector3, taille: float, energie: float, portee: float, couleur := Color(1.0, 0.55, 0.22)) -> void:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.position = pos + Vector3(0, 0.3, 0)
	parent.add_child(l)
	_flammes.append([l, energie, randf() * 10.0])
	var p := GPUParticles3D.new()
	p.amount = int(16 * taille) + 6
	p.lifetime = 0.5
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1 * taille
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5 * taille
	pm.initial_velocity_max = 0.9 * taille
	pm.gravity = Vector3(0, 0.6, 0)
	var g := Gradient.new()
	var froid := couleur.b > couleur.r
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	if froid:
		g.colors = PackedColorArray([Color(1.6, 2.6, 3.0), Color(0.4, 1.2, 2.2), Color(0.05, 0.2, 0.5, 0.0)])
	else:
		g.colors = PackedColorArray([Color(3.0, 2.3, 0.9), Color(2.0, 0.6, 0.15), Color(0.3, 0.05, 0.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1) * maxf(taille, 0.4)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	parent.add_child(p)

## Brasero de pierre aux flammes bleues des morts.
func _brasero(pos: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.45
	c.bottom_radius = 0.3
	c.height = 0.9
	c.radial_segments = 7
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m_pierre
	mi.position = pos + Vector3(0, 0.45, 0)
	crypte.add_child(mi)
	_flamme(crypte, pos + Vector3(0, 0.95, 0), 1.2, 1.6, 9.0, Color(0.35, 0.7, 1.0))

func _givre(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 3.0
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.1, 1.4)
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.05, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = Palette.lueur(Color(0.7, 1.3, 1.8))
	(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.draw_pass_1 = q
	crypte.add_child(p)
