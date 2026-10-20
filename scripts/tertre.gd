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
var d: CrypteDecor
var _flamme_pixel: MeshInstance3D
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
	crypte.visible = false      # tant qu'on est dehors, ni rendu ni lumières (le décor reste solide)

func _process(dt: float) -> void:
	_t += dt
	if d != null and dedans:
		d.vaciller(_t)
	_flamme_main()
	if not dedans and joueur.global_position.distance_to(porte_dehors) < 9.0:
		quetes.signaler("lieu:tertre")
	if _lueur_tombe:
		var cible := 3.2 if _anneau_rendu else 1.6 + sin(_t * 1.3) * 0.3
		_lueur_tombe.light_energy = lerpf(_lueur_tombe.light_energy, cible, 1.0 - exp(-2.0 * dt))
	# Svanhild se lève quand on approche du sarcophage avec l'anneau
	if dedans and not _svanhild_levee and joueur.inventaire.a("anneau_givre"):
		if joueur.global_position.distance_to(crypte.to_global(Vector3(0, 0, -50))) < 8.0:
			_lever_svanhild()

## Sous terre, la flamme de la torche tenue en main devient un sprite pixel art (les grosses particules
## additives faisaient une tache blanche carrée sans glow) ; dehors, tout est remis comme avant.
func _flamme_main() -> void:
	var mains: Node = joueur.mains
	if mains == null or d == null:
		return
	if dedans and _flamme_pixel == null and mains.porte_torche != null:
		_flamme_pixel = d.flamme_sur(mains.porte_torche, Vector3(0, 0.53, 0.0), 0.5)
	if _flamme_pixel == null:
		return
	_flamme_pixel.visible = dedans and mains.torche_lumiere.visible
	for i in mains.flammes.size():
		if i != 3:                               # on garde les étincelles ; cœur, corps, langues et fumée cèdent la place au sprite
			mains.flammes[i].visible = not dedans

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
	# lot 5 : façade et butte en pierre / neige pixel art (16 texels/m) ; la crypte garde ses matériaux
	var m_facade := TexturesBati.m_roche(Color(0.8, 0.79, 0.84))
	var m_porte_dalle := TexturesBati.m_roche(Color(0.42, 0.42, 0.5))
	butte.material_override = TexturesBati.m_neige_toit()
	butte.scale = Vector3(1, 0.42, 1)
	butte.position = Vector3(0, -0.6, -6.5)
	add_child(butte)
	var corps_dehors := StaticBody3D.new()
	add_child(corps_dehors)
	# collision = faces de la sphère visible (même échelle, même décalage) : on peut gravir la butte
	var xf_butte := Transform3D(Basis.from_scale(butte.scale), butte.position)
	var faces := PackedVector3Array()
	for v in s.get_faces():
		faces.append(xf_butte * v)
	var dome := ConcavePolygonShape3D.new()
	dome.set_faces(faces)
	dome.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "CollisionDome"
	cs.shape = dome
	corps_dehors.add_child(cs)
	# façade : deux pierres dressées, un linteau, une dalle sombre pour la porte
	for x in [-1.3, 1.3]:
		_boite(self, Vector3(0.8, 3.0, 0.8), Transform3D(Basis(), Vector3(x, 1.3, -0.4)), m_facade, corps_dehors)
	_boite(self, Vector3(3.6, 0.7, 1.0), Transform3D(Basis(), Vector3(0, 3.0, -0.4)), m_facade, corps_dehors)
	_boite(self, Vector3(1.9, 2.6, 0.2), Transform3D(Basis(), Vector3(0, 1.2, -0.75)), m_porte_dalle, corps_dehors)
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
## Lot 7a : toute la construction visible (murs, voûtes, piliers, mobilier, lumières) est dans CrypteDecor ;
## ici ne restent que le plan, les collisions d'origine (refaites à l'identique par CrypteDecor), les
## interactions, les gardiens et le corps d'Eirik.

func _construire_crypte() -> void:
	var t0 := Time.get_ticks_msec()
	d = CrypteDecor.new(crypte, corps)
	_entree()
	_couloir_niches()
	_salle_piliers()
	_alcove()
	_couloir_herse()
	_tombeau()
	var t1 := Time.get_ticks_msec()
	d.finir()
	print("Crypte (lot 7a) : plan %d ms + finition %d ms = %d ms" % [t1 - t0, Time.get_ticks_msec() - t1, Time.get_ticks_msec() - t0])

func _toiles(coins: Array, haut: float) -> void:
	# coins : [x, z, vers_x, vers_z] (directions le long des deux murs qui forment le coin)
	for c in coins:
		d.toile(Vector3(c[0], haut, c[1]), Vector3(c[2], 0, 0), Vector3(0, 0, c[3]))

func _entree() -> void:
	d.salle(-3, 3, 4, -6, 3.6, [["nord", 0.0, 3.2]], 0.0, "mur0")
	# escalier qui remonte vers la sortie (décor, contre le mur sud) et passage sombre au-dessus
	for i in 4:
		d.boite("dalle0", Vector3(0, 0.15 * (4 - i), 3.4 - i * 0.6), Vector3(3.0, 0.3 * (4 - i), 0.6))
	d.quad("noir", Vector3(-1.0, 1.2, 3.69), Vector3(1.0, 1.2, 3.69), Vector3(1.0, 3.0, 3.69), Vector3(-1.0, 3.0, 3.69), Vector3(0, 0, -1))
	d.boite("mur0", Vector3(-1.2, 2.1, 3.62), Vector3(0.4, 1.8, 0.16))
	d.boite("mur0", Vector3(1.2, 2.1, 3.62), Vector3(0.4, 1.8, 0.16))
	d.boite("mur0", Vector3(0, 3.1, 3.62), Vector3(2.8, 0.4, 0.16))
	_interactif(crypte, Vector3(0, 1.6, 1.5), "Sortie", "Sortir du tertre", func() -> Array: return _passer(false))
	for z in [2.0, 0.0, -2.0, -4.0]:
		d.poutre(-2.7, 2.7, 3.45, z)
	d.brasero(Vector3(-2.3, 0, -5.2))
	d.brasero(Vector3(2.3, 0, -5.2))
	d.applique(Vector3(-2.7, 0, 0.0), Vector3(1, 0, 0), 2.1, 5.0, 1.7)
	d.applique(Vector3(2.7, 0, 0.0), Vector3(-1, 0, 0), 2.1, 5.0, 1.7)
	d.urne(Vector3(-2.2, 0, -3.4), 1.0)
	d.urne(Vector3(2.15, 0, -3.1), 0.8)
	d.os_tas(Vector3(-1.9, 0, 2.7), 3, 0.3)
	d.arme(Vector3(-1.4, 0, -1.4), 0.6)
	_toiles([[-2.7, 3.7, 1, -1], [2.7, 3.7, -1, -1], [-2.7, -5.7, 1, 1], [2.7, -5.7, -1, 1]], 3.6)

func _niche(x_plan: float, z: float, vers_x: float) -> void:
	# niche à gardien : encadrement épais, tablette, crâne et urne
	var x := x_plan + vers_x * 0.08
	d.boite("mur0", Vector3(x, 1.1, z - 0.7), Vector3(0.16, 2.2, 0.24))
	d.boite("mur0", Vector3(x, 1.1, z + 0.7), Vector3(0.16, 2.2, 0.24))
	d.boite("mur0", Vector3(x, 2.25, z), Vector3(0.16, 0.3, 1.64))
	d.boite("mur1", Vector3(x_plan + vers_x * 0.13, 0.95, z), Vector3(0.26, 0.1, 1.2))
	d.crane(Vector3(x_plan + vers_x * 0.15, 1.0, z - 0.25), atan2(vers_x, 0.0))
	d.urne(Vector3(x_plan + vers_x * 0.15, 1.0, z + 0.3), 0.7)
	d.os_tas(Vector3(x_plan + vers_x * 0.45, 0.0, z), 2, 0.3)

func _couloir_niches() -> void:
	d.salle(-1.6, 1.6, -6, -18, 3.0, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2]], 0.0, "mur1")
	for z in [-7.0, -11.0, -15.0]:
		d.arc("mur0", "x", 0.0, z, 2.6, 1.4, 1.3, 0.32, 0.45)
		for x in [-1.15, 1.15]:
			d.boite("mur0", Vector3(x, 0.7, z), Vector3(0.3, 1.4, 0.45))
	_niche(1.3, -13.0, -1.0)
	_niche(1.3, -16.8, -1.0)
	_niche(-1.3, -9.0, 1.0)
	_niche(-1.3, -16.8, 1.0)
	d.applique(Vector3(1.3, 0, -9.0), Vector3(-1, 0, 0), 1.9, 4.6, 1.5)
	d.applique(Vector3(-1.3, 0, -13.0), Vector3(1, 0, 0), 1.9, 4.6, 1.5)
	_gardien("sbire", Vector3(-1.0, 0, -11.0), PI * 0.5, true)
	_gardien("sbire", Vector3(1.0, 0, -15.0), -PI * 0.5, true)
	d.arme(Vector3(0.5, 0, -8.6), 1.1)
	d.os_tas(Vector3(0.85, 0, -12.3), 3, 0.3)
	_toiles([[-1.3, -6.3, 1, -1], [1.3, -17.7, -1, 1], [-1.3, -17.7, 1, 1]], 3.0)

func _salle_piliers() -> void:
	d.salle(-7, 7, -18, -32, 4.6, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2], ["ouest", -25.0, 3.0]], 0.0, "mur0")
	# voie processionnelle gravée au centre (modules de 4 m)
	for k in 3:
		d.boite("gravure", Vector3(0, 0.015, -20.3 - k * 4.0), Vector3(2.0, 0.03, 4.0), 0.0, true, Vector3(1.0, 0, 20.3 + k * 4.0))
	for x in [-3.5, 3.5]:
		for z in [-21.5, -28.5]:
			d.pilier(x, z, 4.6, 0.9)
	# arcs doubleaux entre les piliers, et de chaque pilier au contrefort du mur
	for z in [-21.5, -28.5]:
		d.arc("mur0", "x", 0.0, z, 6.1, 3.6, 0.65, 0.35, 0.5)
		for s in [-1.0, 1.0]:
			d.arc("mur0", "x", s * 4.8, z, 3.2, 3.6, 0.65, 0.35, 0.5)
			d.contrefort(s * 6.45, z, 4.6, -s, 0.0, 0.7, 0.5)
	for x in [-3.5, 3.5]:
		d.arc("mur0", "z", x, -25.0, 6.1, 3.6, 0.65, 0.35, 0.5)
	d.brasero(Vector3(-6.0, 0, -19.0))
	d.brasero(Vector3(6.0, 0, -31.0))
	d.brasero(Vector3(6.0, 0, -19.0))
	d.applique(Vector3(-6.2, 0, -21.5), Vector3(1, 0, 0), 2.3, 5.5, 1.8)
	d.applique(Vector3(-6.2, 0, -28.5), Vector3(1, 0, 0), 2.3, 5.5, 1.8)
	d.applique(Vector3(6.2, 0, -28.5), Vector3(-1, 0, 0), 2.3, 5.5, 1.8, false)
	d.applique(Vector3(6.2, 0, -21.5), Vector3(-1, 0, 0), 2.3, 5.5, 1.8, false)
	# mobilier : sarcophages et coffre contre le mur du fond, armes et ossements
	d.sarcophage(Vector3(-4.7, 0, -31.15), Vector3(2.2, 0.7, 0.9), 0.0)
	d.sarcophage(Vector3(4.0, 0, -31.15), Vector3(2.2, 0.7, 0.9), 0.0)
	d.coffre(Vector3(-6.2, 0, -30.9), PI * 0.5)
	d.urne(Vector3(-6.2, 0, -26.0), 1.0)
	d.os_tas(Vector3(-4.0, 0, -26.8), 5, 0.6)
	d.arme(Vector3(2.0, 0, -22.8), 2.3)
	d.arme(Vector3(-2.5, 0, -19.4), 0.4)
	d.crane(Vector3(3.5, 0.0, -22.4), 0.8)
	d.crane(Vector3(-3.1, 0.0, -29.4), 2.4)
	d.oculus(Vector3(0, 4.6, -25.0), 1.4)
	d.rai(Vector3(0, 0.0, -25.0), 4.55, 1.5)
	d.flaque_froide(Vector3(0, 0.0, -25.0), 3.2)
	d.lumiere(Vector3(0, 1.3, -25.0), Color(0.55, 0.75, 1.0), 0.7, 4.5, 1.8, false)
	d.poussiere(Vector3(0, 2.3, -25.0), Vector3(0.7, 2.2, 0.7), 22)
	_gardien("guerrier", Vector3(-4.0, 0, -26.0), 0.4, false)
	_gardien("sbire", Vector3(3.0, 0, -24.0), 2.0, true)
	_gardien("sbire", Vector3(-2.0, 0, -30.0), -0.8, true)
	_toiles([[-6.7, -18.3, 1, -1], [6.7, -18.3, -1, -1], [-6.7, -31.7, 1, 1], [6.7, -31.7, -1, 1]], 4.6)

func _alcove() -> void:
	d.salle(-11, -7, -23, -27, 3.0, [["est", -25.0, 3.0]], 0.0, "mur2")
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
	d.coffre(Vector3(-10.2, 0, -26.4), 0.0)
	d.table(Vector3(-9.0, 0, -23.75), 0.0)
	d.bougie(Vector3(-9.35, 0.795, -23.8))      # la chandelle d'Eirik
	d.etagere(Vector3(-8.5, 0, -26.53), 0.0, 1.7, 2.0)
	d.applique(Vector3(-10.7, 0, -25.0), Vector3(1, 0, 0), 2.1, 4.2, 1.2)
	d.arme(Vector3(-8.2, 0, -24.9), 2.6)
	d.os_tas(Vector3(-10.2, 0, -24.0), 2, 0.25)
	_toiles([[-10.7, -23.3, 1, -1], [-7.3, -26.7, -1, 1]], 3.0)

func _couloir_herse() -> void:
	d.salle(-1.6, 1.6, -32, -42, 3.2, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2]], 0.0, "mur2")
	for z in [-34.5, -36.5, -38.5, -40.5]:
		d.poutre(-1.3, 1.3, 3.05, z)
	herse = Node3D.new()
	herse.position = Vector3(0, 0, -33.0)
	crypte.add_child(herse)
	var corps_herse := StaticBody3D.new()
	herse.add_child(corps_herse)
	for i in 7:
		d.instance_boite(herse, "fer", Vector3(0.08, 3.1, 0.08), Vector3(-1.35 + i * 0.45, 1.55, 0))
	for y in [0.6, 1.8, 2.8]:
		d.instance_boite(herse, "fer", Vector3(3.0, 0.08, 0.08), Vector3(0, y, 0))
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
	d.instance_boite(levier, "fer", Vector3(0.2, 0.5, 0.3), Vector3.ZERO)
	var manche := d.instance_boite(levier, "bois", Vector3(0.06, 0.6, 0.06), Vector3(-0.15, 0.25, 0))
	manche.rotation = Vector3(0, 0, 0.5)
	_manche = manche
	_interactif(crypte, Vector3(6.3, 1.1, -25.0), "Levier", "Tirer le levier", _tirer_levier, func() -> bool: return not _herse_ouverte)
	d.applique(Vector3(1.3, 0, -37.5), Vector3(-1, 0, 0), 1.9, 4.5, 1.5)
	d.os_tas(Vector3(-0.8, 0, -34.7), 4, 0.35)
	d.arme(Vector3(0.5, 0, -39.0), 1.0)
	d.urne(Vector3(-1.0, 0, -41.2), 0.9)
	d.urne(Vector3(1.0, 0, -41.0), 0.8)
	_toiles([[-1.3, -32.3, 1, -1], [1.3, -41.7, -1, 1]], 3.2)

func _tombeau() -> void:
	d.salle(-8, 8, -42, -58, 6.0, [["sud", 0.0, 3.2]], 0.0, "mur0")
	# voie gravée jusqu'à l'estrade, estrade (collision d'origine), marche, sarcophage
	for k in 2:
		d.boite("gravure", Vector3(0, 0.015, -44.3 - k * 4.0), Vector3(2.0, 0.03, 4.0), 0.0, true, Vector3(1.0, 0, 44.3 + k * 4.0))
	d.boite_pleine("dalle0", Vector3(0, 0.2, -51.0), Vector3(6.0, 0.4, 5.0))
	d.boite("mur1", Vector3(0, 0.1, -48.2), Vector3(4.0, 0.2, 0.6))
	d.boite_pleine("mur0", Vector3(0, 0.9, -51.5), Vector3(1.6, 1.0, 3.0))
	d.boite("mur1", Vector3(0, 0.52, -51.5), Vector3(1.9, 0.24, 3.3))
	d.boite("gravure", Vector3(0, 1.48, -51.5), Vector3(1.8, 0.18, 3.2))
	_boite(crypte, Vector3(1.0, 0.04, 2.2), Transform3D(Basis(), Vector3(0, 1.58, -51.5)), Palette.lueur(Color(0.4, 1.1, 1.6)))
	for x in [-6.5, 6.5]:
		for z in [-44.0, -56.0]:
			d.pilier(x, z, 6.0, 1.0)
	for z in [-44.0, -56.0]:
		d.arc("mur0", "x", 0.0, z, 12.0, 4.6, 1.0, 0.4, 0.6, 12)
	for x in [-6.5, 6.5]:
		d.arc("mur0", "z", x, -50.0, 11.0, 4.6, 1.0, 0.4, 0.6, 12)
	for z in [-46.0, -54.0]:
		d.contrefort(7.45, z, 6.0, -1.0, 0.0, 0.7, 0.5)
		d.contrefort(-7.45, z, 6.0, 1.0, 0.0, 0.7, 0.5)
	_lueur_tombe = OmniLight3D.new()
	_lueur_tombe.light_color = Color(0.4, 0.8, 1.0)
	_lueur_tombe.light_energy = 1.6
	_lueur_tombe.omni_range = 10.0
	_lueur_tombe.omni_attenuation = 1.5
	_lueur_tombe.position = Vector3(0, 3.0, -51.5)
	crypte.add_child(_lueur_tombe)
	d.brasero(Vector3(-5.0, 0, -45.0))
	d.brasero(Vector3(5.0, 0, -45.0))
	d.applique(Vector3(7.2, 0, -46.0), Vector3(-1, 0, 0), 2.6, 5.5, 1.8)
	d.applique(Vector3(-7.2, 0, -46.0), Vector3(1, 0, 0), 2.6, 5.5, 1.8)
	d.applique(Vector3(7.2, 0, -54.0), Vector3(-1, 0, 0), 2.6, 5.5, 1.8, false)
	d.applique(Vector3(-7.2, 0, -54.0), Vector3(1, 0, 0), 2.6, 5.5, 1.8, false)
	d.oculus(Vector3(0, 6.0, -51.5), 1.8)
	d.rai(Vector3(0, 1.7, -51.5), 4.25, 1.7)
	d.flaque_froide(Vector3(0, 0.41, -51.0), 5.0)
	d.poussiere(Vector3(0, 3.6, -51.5), Vector3(0.9, 2.0, 1.4), 30)
	d.urne(Vector3(7.1, 0, -50.0), 1.1)
	d.urne(Vector3(-7.1, 0, -50.0), 1.1)
	d.crane(Vector3(2.3, 0.4, -49.2), -0.6)
	d.crane(Vector3(-2.3, 0.4, -49.0), 0.7)
	d.os_tas(Vector3(-4.6, 0, -53.0), 4, 0.5)
	d.os_tas(Vector3(4.8, 0, -56.0), 3, 0.5)
	d.arme(Vector3(3.2, 0, -47.0), 0.3)
	d.arme(Vector3(-3.4, 0, -53.6), 2.2)
	_gardien("guerrier", Vector3(-3.0, 0, -45.5), PI, true, true)
	_gardien("guerrier", Vector3(3.0, 0, -45.5), PI, true, true)
	_givre(Vector3(0, 1.6, -51.5))
	_interactif(crypte, Vector3(0, 1.4, -49.6), "Inscription", "Lire l’inscription", func() -> Array: return quetes.texte("inscription_tombe"), func() -> bool: return not _peut_rendre())
	_interactif(crypte, Vector3(0, 1.4, -49.6), "Svanhild", "Replacer l’anneau sur le sarcophage", _rendre_anneau, _peut_rendre)
	_toiles([[-7.7, -41.7, 1, -1], [7.7, -41.7, -1, -1], [-7.7, -57.7, 1, 1], [7.7, -57.7, -1, 1]], 6.0)

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
		crypte.visible = true
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
		crypte.visible = vers_dedans
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
