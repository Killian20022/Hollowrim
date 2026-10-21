extends Node3D
## Test visuel : forêt nordique de nuit (brouillard, neige, aurore, rendu PS1).
## Tout est généré par code pour l'instant ; les vrais modèles viendront de Blender.
##
## Capture d'écran sans jouer (pour les tests) :
##   godot --path . -- --capture=C:/chemin/image.png [--pose=x,z,lacet,tangage] [--sans-ps1]
##   [--heure=12] [--sans-particules] [--paisible] [--biome=ancien|nouveau]
##   LOT : godot --path . --disable-vsync -- --captures=poses.txt --sortie=dossier [--paisible --sans-particules --sans-mains --attente=200]
##   (plusieurs vues en un lancement ; format du fichier : voir _lot_captures plus bas ; sauvegarde de test : voir fichier_sauvegarde)

const TAILLE := 240.0           # côté du terrain (m)
const CASES := 120              # cases par côté
const MORCEAU := 30             # cases par morceau de terrain (4x4 morceaux)
const RAYON_CLAIRIERE := 9.0
const CERCLE := Vector3(-38.0, 0.0, -34.0)  # cercle de pierres runiques
const VILLAGE := Vector3(44.0, 0.0, 40.0)   # Skarnholt

const CIEL := preload("res://shaders/ciel_nuit.gdshader")
const POST := preload("res://shaders/ps1_post.gdshader")
const JOUEUR := preload("res://scripts/joueur.gd")
const DRAUGR := preload("res://scripts/draugr.gd")
const HUD := preload("res://scripts/hud.gd")
const VILLAGE_SCRIPT := preload("res://scripts/village.gd")
const CYCLE := preload("res://scripts/cycle.gd")
const VILLAGEOIS := preload("res://scripts/villageois.gd")
const DIALOGUE := preload("res://scripts/dialogue.gd")
const QUETES := preload("res://scripts/quetes.gd")
const TERTRE := preload("res://scripts/tertre.gd")
const GROTTE_ACCES := preload("res://scripts/grotte_acces.gd")
const DRAGON := preload("res://scripts/dragon.gd")
const TUMULUS := Vector3(-38.0, 0.0, -48.0)  # façade du tertre, au nord du cercle

var bruit := FastNoiseLite.new()
var bruit_detail := FastNoiseLite.new()
var bruit_densite := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var h_centre := 0.0
var h_cercle := 0.0
var h_tumulus := 0.0  # hauteur au pied de la façade du tertre (lot C)
const TUMULUS_DISQUE := Vector2(-38.0, -54.5)  # centre du disque aplani derrière la façade
var h_village := 0.0
var h_grotte := 0.0  # niveau de la terrasse devant la bouche de la grotte (relief d'avant l'aplanissement)
var grotte_acces: Node3D
var village: Node3D
var cycle: Node
var arriere_plan: Node3D  # montagnes/château lointains (ArrierePlan), masqués sous terre
var calque: CanvasLayer
var dialogue: Control
var quetes: Node
var tertre: Node3D
var chemins: Chemins
var arbres: Array = []  # transforms de tous les arbres (pour Sol)
var mat_terrain: ShaderMaterial
var dragon: CharacterBody3D = null
var dragon_vaincu := false
var _env: Environment
var _ciel: ShaderMaterial

var tex_neige: ImageTexture
var tex_roche: ImageTexture
var tex_aiguilles: ImageTexture
var tex_ecorce: ImageTexture

var joueur: CharacterBody3D
var neige: GPUParticles3D
var feu_lumiere: OmniLight3D
var post: ShaderMaterial
var aide: Label
var hud: Control
var sbire: CharacterBody3D
var depart_joueur := Vector3.ZERO
var draugrs := {}  # identifiant → draugr
var _minuterie_sauvegarde := 0.0
const SAUVEGARDE_REELLE := "user://sauvegarde.json"
## La vraie partie reste sur sauvegarde.json ; tout lancement avec arguments utilisateur (après « -- »),
## en --script ou sans fenêtre (tests, captures, --nouvelle…) lit et écrit sauvegarde_test_<dossier>.json :
## un fichier par copie du projet, pour que les tests de deux worktrees lancés en même temps ne s'écrasent pas.
static func fichier_test() -> String:
	return "user://sauvegarde_test_%08x.json" % (hash(ProjectSettings.globalize_path("res://")) & 0xffffffff)
static func fichier_sauvegarde() -> String:
	var args := OS.get_cmdline_args()
	if OS.get_cmdline_user_args().size() > 0 or "--script" in args or "-s" in args or DisplayServer.get_name() == "headless":
		return fichier_test()
	return SAUVEGARDE_REELLE
var _t := 0.0

var _audio_vent: AudioStreamGeneratorPlayback
var _audio_feu: AudioStreamGeneratorPlayback
var _brun := 0.0
var _brun2 := 0.0
var _crepite := 0.0
var _t_audio := 0.0

func _ready() -> void:
	Chrono.demarre()
	Prechargement.lancer()
	# variante du biome, lue AVANT toute génération (--biome=… ou set_meta("biome", …))
	var biome: String = str(get_meta("biome")) if has_meta("biome") else str(_arguments().get("biome", "nouveau"))
	ZoneBiome.actif = (biome == "nouveau")
	rng.seed = 1234
	bruit.seed = 7
	bruit.frequency = 0.009
	bruit.fractal_octaves = 4
	bruit_detail.seed = 11
	bruit_detail.frequency = 0.06
	bruit_densite.seed = 3
	bruit_densite.frequency = 0.02
	h_centre = _hauteur_brute(0.0, 0.0)
	for k in 8:
		var a := TAU * k / 8.0
		h_village += _hauteur_brute(VILLAGE.x + cos(a) * 30.0, VILLAGE.z + sin(a) * 30.0) / 8.0
		h_cercle += _hauteur_brute(CERCLE.x + cos(a) * 16.0, CERCLE.z + sin(a) * 16.0) / 8.0
	h_grotte = _hauteur_ancienne(GrotteAcces.SITE.x - 1.0, GrotteAcces.SITE.y)
	chemins = Chemins.new(self)
	if ZoneBiome.actif:
		h_tumulus = _hauteur_sans_tumulus(TUMULUS.x, TUMULUS.z)

	tex_neige = Palette.pailleter(Palette.texture(64, Palette.NEIGE, 3, 1, 0.12, rng), 0.012)
	Palette.tex_neige = tex_neige
	tex_roche = Palette.texture(32, Palette.ROCHE, 4, 2, 0.45, rng)
	tex_aiguilles = Palette.texture(32, Palette.AIGUILLES, 8, 3, 0.7, rng)
	tex_ecorce = Palette.texture(32, Palette.ECORCE, 4, 4, 0.4, rng)
	_chrono("textures de base")

	_environnement()
	_lune()
	if not _arguments().has("sans-arriere-plan"):  # --sans-arriere-plan : mesures A/B de performance
		arriere_plan = ArrierePlan.creer(self)
		add_child(arriere_plan)
	_terrain()
	_chrono("terrain")
	arbres = Vegetation.creer(self)
	_chrono("arbres (placement+modeles+MultiMesh)")
	Rochers.creer(self)
	SousBois.creer(self)  # lot E : après les rochers (touffes collées aux pierres)
	CercleRunique.creer(self)
	_chrono("rochers+sous-bois+cercle")
	Sol.appliquer(mat_terrain, self, arbres)
	_chrono("carte de sol")
	DetailsSol.creer(self)  # lot 3 : cailloux du sol (après la carte de sol)
	_village()
	_chrono("village (bati)")
	_feu_de_camp()
	_joueur()
	_chrono("joueur")
	_neige()
	_interface()
	_draugrs()
	_villageois()
	_chrono("villageois")
	_guerrier_pilote()
	_mage_pilote()
	_chasseresse_pilote()
	_gardien_pilote()
	_troll_pilote()
	_draugr_pilote()
	_tertre()
	_chrono("tertre+crypte")
	_grotte_acces()
	_chrono("entree de la grotte")
	AbordsTumulus.creer(self)  # lot F : abords du tertre (après sa création)
	if _arguments().has("res"):  # essai de résolution interne (captures) : --res=640x360 ; ne change pas le défaut du projet
		var wh := String(_arguments()["res"]).split("x")
		get_window().content_scale_size = Vector2i(int(wh[0]), int(wh[1]))
	if not _arguments().has("capture"):
		_musique()
	if not _arguments().has("capture") and not _arguments().has("nouvelle"):
		charger()
	if not _arguments().has("capture"):
		_audio()
	_cacher_particules()
	_cacher_particules()
	_rendre_paisible()
	_capture()
	Chrono.total()
	_aller_crypte()
	_aller_interieur()
	if _arguments().has("grotte") and not _arguments().has("capture"):
		_aller_grotte(_arguments()["grotte"])

func _chrono(etape: String) -> void:
	Chrono.marque(etape)

# --- relief ---------------------------------------------------------------

func _hauteur_brute(x: float, z: float) -> float:
	var h := bruit.get_noise_2d(x, z) * 14.0 + bruit_detail.get_noise_2d(x, z) * 1.0
	# collines sur le pourtour : une cuvette boisée
	h += smoothstep(70.0, 118.0, Vector2(x, z).length()) * 24.0
	return h

## Vrai si (x, z) est à moins de `marge` m du sentier qui relie le feu à la porte du village.
func _pres_du_chemin(x: float, z: float, marge: float) -> bool:
	var porte := Vector2(VILLAGE.x, VILLAGE.z) - Vector2(VILLAGE.x, VILLAGE.z).normalized() * 22.0
	var debut := Vector2(VILLAGE.x, VILLAGE.z).normalized() * (RAYON_CLAIRIERE - 2.0)
	var p := Vector2(x, z)
	var t := clampf((p - debut).dot(porte - debut) / (porte - debut).length_squared(), 0.0, 1.0)
	return p.distance_to(debut.lerp(porte, t)) < marge

func _village() -> void:
	village = Node3D.new()
	village.set_script(VILLAGE_SCRIPT)
	village.position = Vector3(VILLAGE.x, h_village, VILLAGE.z)
	var vers_feu := -Vector2(VILLAGE.x, VILLAGE.z).normalized()
	village.rotation.y = atan2(vers_feu.x, vers_feu.y)
	add_child(village)

## Relief d'avant le biome (identique au bit près) : seule référence hors de la zone témoin.
func _hauteur_ancienne(x: float, z: float) -> float:
	var h := _hauteur_brute(x, z)
	# clairière du feu et clairière du cercle aplanies
	h = lerpf(h_centre, h, smoothstep(RAYON_CLAIRIERE, RAYON_CLAIRIERE + 14.0, Vector2(x, z).length()))
	h = lerpf(h_cercle, h, smoothstep(9.0, 26.0, Vector2(x - CERCLE.x, z - CERCLE.z).length()))
	h = lerpf(h_village, h, smoothstep(25.0, 38.0, Vector2(x - VILLAGE.x, z - VILLAGE.z).length()))
	return h

## Relief de la zone sans chemin ni tumulus : plateaux du feu et du cercle à bords bruités (lot C).
func hauteur_sans_chemin(x: float, z: float) -> float:
	var m := ZoneBiome.masque(x, z)
	if m <= 0.0 or chemins == null:
		return _hauteur_ancienne(x, z)
	var h := _hauteur_brute(x, z)
	var d_feu := chemins.distance_bruitee(x, z, Vector2(x, z).length(), m)
	h = lerpf(h_centre, h, smoothstep(RAYON_CLAIRIERE, RAYON_CLAIRIERE + 14.0, d_feu))
	var d_cercle := chemins.distance_bruitee(x, z, Vector2(x - CERCLE.x, z - CERCLE.z).length(), m)
	h = lerpf(h_cercle, h, smoothstep(9.0, 26.0, d_cercle))
	return lerpf(h_village, h, smoothstep(25.0, 38.0, Vector2(x - VILLAGE.x, z - VILLAGE.z).length()))

## Avec chemins (profil lissé sur 4 m + ornière) mais sans l'aplanissement du tumulus.
func _hauteur_sans_tumulus(x: float, z: float) -> float:
	var m := ZoneBiome.masque(x, z)
	var h := hauteur_sans_chemin(x, z)
	var dist := chemins.distance(x, z)
	if dist < Chemins.LARGEUR_PROFIL.x:
		var w := smoothstep(Chemins.LARGEUR_PROFIL.x, Chemins.LARGEUR_PROFIL.y, dist) * m * 0.85
		h = lerpf(h, chemins.hauteur_axe(x, z), w)
		h -= Chemins.ORNIERE * smoothstep(1.0, 0.2, dist) * m
	return h

func hauteur(x: float, z: float) -> float:
	var m := ZoneBiome.masque(x, z)
	if m <= 0.0 or chemins == null:
		return GrotteAcces.aplani(x, z, _hauteur_ancienne(x, z), h_grotte)
	var h := _hauteur_sans_tumulus(x, z)
	# tumulus : disque plat (r ≤ 8) à la hauteur du pied de la façade, raccord jusqu'à r 14
	var r := Vector2(x - TUMULUS_DISQUE.x, z - TUMULUS_DISQUE.y).length()
	return lerpf(h, lerpf(h_tumulus, h, smoothstep(8.0, 14.0, r)), m)

# --- ambiance ----------------------------------------------------------------

func _environnement() -> void:
	var ciel := ShaderMaterial.new()
	ciel.shader = CIEL
	var sky := Sky.new()
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.62)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true  # lot 7 : brouillard en profondeur, réglé chaque image par cycle.gd (appliquer_brume)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.075, 0.13)
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	# halos de flammes nets : seuls les niveaux serrés (2 et 3) restent, plus de voile large
	for i in 7:
		env.set_glow_level(i, 1.0 if (i == 1 or i == 2) else 0.0)

	_env = env
	_ciel = ciel
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _lune() -> void:
	# lune haute au nord-est, face au joueur à l'apparition : contre-jour sur la neige
	var vers_lune := Vector3(0.35, 0.55, -0.75).normalized()
	var lune := DirectionalLight3D.new()
	lune.basis = Basis.looking_at(-vers_lune, Vector3.UP)
	lune.light_color = Color(0.62, 0.72, 1.0)
	lune.light_energy = 0.75
	lune.shadow_enabled = true
	lune.shadow_bias = 0.08
	lune.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	lune.directional_shadow_max_distance = 62.0  # lot 7 : ombres jusqu'à la fin du brouillard de nuit claire
	add_child(lune)
	cycle = Node.new()
	cycle.set_script(CYCLE)
	cycle.env = _env
	cycle.lumiere = lune
	cycle.ciel = _ciel
	cycle.appliquer_brume()
	var h: String = _arguments().get("heure", "")
	if h != "":
		cycle.heure = float(h)
	add_child(cycle)
	# en capture, le temps reste figé (images comparables), même avec une heure imposée
	if _arguments().has("capture"):
		cycle.process_mode = Node.PROCESS_MODE_DISABLED
		cycle._process(0.0)  # applique l'éclairage (de l'heure demandée, sinon celle de départ) une fois

# --- terrain -----------------------------------------------------------------

func _terrain() -> void:
	var n := CASES + 1
	var pas := TAILLE / CASES
	var demi := TAILLE * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = hauteur(i * pas - demi, j * pas - demi)

	var m := Palette.materiau(tex_roche)
	m.set_shader_parameter("uv_monde", true)
	m.set_shader_parameter("monde_echelle", 0.11)
	m.set_shader_parameter("tex_macro", Palette.texture_macro())
	m.set_shader_parameter("macro_force", 1.0)
	mat_terrain = m
	# terrain découpé en morceaux : chacun reçoit ses propres lumières (8 max par objet
	# avec le rendu Mobile) et les morceaux hors champ ne sont pas dessinés
	var corps := StaticBody3D.new()
	add_child(corps)
	for mj in range(0, CASES, MORCEAU):
		for mi_ in range(0, CASES, MORCEAU):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(mj, mj + MORCEAU + 1):
				for i in range(mi_, mi_ + MORCEAU + 1):
					var hg := hs[j * n + maxi(i - 1, 0)]
					var hd := hs[j * n + mini(i + 1, n - 1)]
					var hh := hs[maxi(j - 1, 0) * n + i]
					var hb := hs[mini(j + 1, n - 1) * n + i]
					var normale := Vector3(hg - hd, 2.0 * pas, hh - hb).normalized()
					var x := i * pas - demi
					var z := j * pas - demi
					# la roche affleure sur les pentes raides ; un peu de bruit casse la limite
					var roche := 1.0 - normale.y + bruit_detail.get_noise_2d(x * 3.0, z * 3.0) * 0.12
					var clair := 0.93 + bruit_detail.get_noise_2d(x * 0.7, z * 0.7) * 0.07
					# neige tassée sur le chemin du feu au village
					if _pres_du_chemin(x, z, 1.4 + bruit_detail.get_noise_2d(x * 2.0, z * 2.0) * 0.6):
						clair *= 0.84
					st.set_color(Color(clair, clair, clair, 1.0 if roche > 0.2 else 0.0))
					st.set_normal(normale)
					st.add_vertex(Vector3(x, hs[j * n + i], z))
			var cote := MORCEAU + 1
			for j in MORCEAU:
				for i in MORCEAU:
					var a := j * cote + i
					var b := a + 1
					var c := a + cote
					var d := c + 1
					st.add_index(a); st.add_index(b); st.add_index(c)
					st.add_index(b); st.add_index(d); st.add_index(c)
			var mesh := st.commit()
			var morceau := MeshInstance3D.new()
			morceau.mesh = mesh
			morceau.material_override = m
			add_child(morceau)
			var forme := CollisionShape3D.new()
			forme.shape = mesh.create_trimesh_shape()
			corps.add_child(forme)

# --- feu de camp ---------------------------------------------------------------

func _feu_de_camp() -> void:
	var sol := Vector3(0, h_centre, 0)
	var m_bois := Palette.materiau(tex_ecorce, Vector2(1, 2))
	var m_pierre := TexturesBati.m_roche()   # lot 5
	var buche := CylinderMesh.new()
	buche.top_radius = 0.08
	buche.bottom_radius = 0.1
	buche.height = 1.1
	buche.radial_segments = 6
	buche.rings = 1
	for i in 5:
		var a := TAU * i / 5.0
		var mi := MeshInstance3D.new()
		mi.mesh = buche
		mi.material_override = m_bois
		var b := Basis(Vector3(-sin(a), 0, cos(a)), 0.55)
		mi.transform = Transform3D(b, sol + Vector3(cos(a) * 0.25, 0.42, sin(a) * 0.25))
		add_child(mi)
	var caillou := SphereMesh.new()
	caillou.radius = 0.16
	caillou.height = 0.22
	caillou.radial_segments = 6
	caillou.rings = 3
	for i in 9:
		var a := TAU * i / 9.0
		var mi := MeshInstance3D.new()
		mi.mesh = caillou
		mi.material_override = m_pierre
		mi.position = sol + Vector3(cos(a) * 0.62, 0.04, sin(a) * 0.62)
		mi.rotation.y = a
		add_child(mi)
	# deux troncs couchés pour s'asseoir
	var banc := CylinderMesh.new()
	banc.top_radius = 0.22
	banc.bottom_radius = 0.24
	banc.height = 2.4
	banc.radial_segments = 7
	banc.rings = 1
	var corps := StaticBody3D.new()
	add_child(corps)
	for a in [0.4, 2.6]:
		var mi := MeshInstance3D.new()
		mi.mesh = banc
		mi.material_override = m_bois
		# couché (axe X), tangent au cercle autour du feu
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3(0, 0, 1), PI * 0.5)
		mi.transform = Transform3D(b, sol + Vector3(cos(a) * 2.6, 0.18, sin(a) * 2.6))
		add_child(mi)
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.23
		cyl.height = 2.4
		forme.shape = cyl
		forme.transform = mi.transform
		corps.add_child(forme)

	feu_lumiere = OmniLight3D.new()
	feu_lumiere.light_color = Color(1.0, 0.55, 0.22)
	feu_lumiere.light_energy = 3.0
	feu_lumiere.omni_range = 14.0
	feu_lumiere.omni_attenuation = 1.4
	feu_lumiere.position = sol + Vector3(0, 0.9, 0)
	add_child(feu_lumiere)

	add_child(_particules_feu(sol, 70, 1.0, Vector2(0.32, 0.32), 1.6, 0.25, [Color(3.0, 2.2, 0.8), Color(2.6, 1.0, 0.25), Color(1.2, 0.25, 0.05), Color(0.3, 0.05, 0.0, 0.0)]))
	add_child(_particules_feu(sol, 18, 2.8, Vector2(0.06, 0.06), 1.8, 0.35, [Color(3.0, 1.8, 0.6), Color(2.0, 0.6, 0.1), Color(1.0, 0.2, 0.0, 0.0)]))

func _particules_feu(sol: Vector3, nombre: int, duree: float, taille: Vector2, vitesse: float, rayon: float, couleurs: Array) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.position = sol + Vector3(0, 0.15, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rayon
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = vitesse * 0.6
	pm.initial_velocity_max = vitesse
	pm.gravity = Vector3(0.15, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var g := Gradient.new()
	var decalages := PackedFloat32Array()
	for i in couleurs.size():
		decalages.append(float(i) / (couleurs.size() - 1))
	g.offsets = decalages
	g.colors = PackedColorArray(couleurs)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = taille
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	return p

# --- joueur, neige, interface ------------------------------------------------

func _joueur() -> void:
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	add_child(joueur)
	var depart := Vector3(2.5, 0, 8.5)
	var lacet := atan2(depart.x, depart.z)  # regarde le feu
	var tangage := 0.12
	var pose: String = _arguments().get("pose", "")
	if pose != "":
		var v := pose.split_floats(",")
		depart = Vector3(v[0], 0, v[1])
		lacet = deg_to_rad(v[2])
		tangage = deg_to_rad(v[3]) if v.size() > 3 else 0.0
	joueur.position = Vector3(depart.x, hauteur(depart.x, depart.z) + 0.1, depart.z)
	joueur.rotation.y = lacet
	joueur.tete.rotation.x = tangage
	depart_joueur = joueur.position
	joueur.touche.connect(_joueur_touche)
	joueur.deces.connect(_joueur_mort)

func _joueur_touche(_degats: float) -> void:
	if _paisible():
		return  # --paisible : pas de vignette de dégâts
	var t := create_tween()
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("degat", v), 0.8, 0.0, 0.6)

func _joueur_mort() -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("fondu", v), 0.0, 1.0, 2.0)
	t.tween_interval(1.5)
	t.tween_callback(func() -> void:
		tertre.reinitialiser()            # mort dans la crypte : ennemis, bourses et portes selon la sauvegarde
		grotte_acces.reinitialiser()      # mort sous terre : la grotte se referme, le monde reprend sa lumière
		joueur.ressusciter(depart_joueur, atan2(depart_joueur.x, depart_joueur.z)))
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("fondu", v), 1.0, 0.0, 1.5)

# --- villageois ------------------------------------------------------------------

func _villageois() -> void:
	dialogue = Control.new()
	dialogue.set_script(DIALOGUE)
	dialogue.joueur = joueur
	calque.add_child(dialogue)
	quetes = Node.new()
	quetes.set_script(QUETES)
	quetes.joueur = joueur
	quetes.hud = hud
	add_child(quetes)
	hud.quetes = quetes
	village.activer_interieurs(joueur, dialogue)   # portes des maisons (touche E)
	var promenade: Array = village.promenade
	var rng_pts := RandomNumberGenerator.new()
	rng_pts.seed = 20261020          # promenades des villageois reproductibles (captures)
	for d in VILLAGEOIS.charger():
		var poste: Vector3 = village.lieux.get(d.get("lieu", "place"), village.lieux["place"])
		var points: Array[Vector3] = [poste]
		if not village.sedentaires.has(d.get("lieu", "place")):   # le forgeron reste dans sa forge (porte fermée la nuit, murs)
			for p in promenade.duplicate():
				if p != poste and rng_pts.randf() < 0.4 and points.size() < 4:
					points.append(p)
		var v := CharacterBody3D.new()
		v.set_script(VILLAGEOIS)
		v.donnees = d
		v.joueur = joueur
		v.dialogue = dialogue
		v.quetes = quetes
		v.points = points
		v.position = poste + Vector3(0, 0.05, 0)
		add_child(v)

# --- guerrier pilote (refonte des personnages) ------------------------------------

## --guerrier-pilote[=x,z,lacet°] : Guerrier nordique pilote (GuerrierNordique) debout en Idle près de l'entrée du village,
## pour les captures en jeu ; par défaut à 4 m devant la pose commune « entree » (outils/poses_refonte.txt), tourné vers elle.
## --guerrier-casque : casque à nasal ; --guerrier-anim=Nom : animation (Sword_Idle par défaut : debout, garde basse armée). Aucun effet sans l'option.
## Dans un lot --captures : type de vue `pilote d,az°[,cible_y]` (caméra à d m du guerrier, az = 0 de face, 180 de dos)
## et options de ligne `anim=Nom:t` (pose figée à la fraction t du clip), `decal=m` (caméra décalée sur le côté).
const PILOTE_DEFAUT := Vector3(24.76, 22.51, -132.3)
var pilote: Node3D

func _guerrier_pilote() -> void:
	if not _arguments().has("guerrier-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["guerrier-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	pilote = GuerrierNordique.creer({"casque": _arguments().has("guerrier-casque")})
	add_child(pilote)
	pilote.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	pilote.rotation.y = deg_to_rad(p.z)
	var ap := pilote.get_node("Animations") as AnimationPlayer
	ap.play(String(_arguments().get("guerrier-anim", "Sword_Idle")))
	if _arguments().has("capture"):
		_pilote_animer(String(_arguments().get("guerrier-anim", "Sword_Idle")), 0.25)

## --chasseresse-pilote[=x,z,lacet°] : Chasseresse nordique (ChasseresseNordique), même usage que --guerrier-pilote (vues « pilote »)
## et --chasseresse-anim=Nom (Idle par défaut) ; avec --guerrier-pilote en plus, elle se tient à 1,3 m à la droite du guerrier (côte à côte).
func _chasseresse_pilote() -> void:
	if not _arguments().has("chasseresse-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["chasseresse-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	var c := ChasseresseNordique.creer({})
	add_child(c)
	if pilote != null:
		var q := pilote.global_position - pilote.global_basis.x * 1.3
		p = Vector3(q.x, q.z, rad_to_deg(pilote.rotation.y))
	else:
		pilote = c
	c.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	c.rotation.y = deg_to_rad(p.z)
	var an := String(_arguments().get("chasseresse-anim", "Idle"))
	var ap := c.get_node("Animations") as AnimationPlayer
	ap.play(an)
	if _arguments().has("capture") or _arguments().has("captures"):
		ap.seek(ap.get_animation(an).length * 0.3, true)
		ap.pause()
## --draugr-pilote[=x,z,lacet°] : Draugr nordique (DraugrNordique) debout au même endroit (ou x,z,lacet) ; --draugr-anim=Nom
## (Sword_Idle par défaut). Seul, il devient le « pilote » des vues `pilote` de --captures ; avec --guerrier-pilote, il se
## tient à côté (comparaison de famille) et le guerrier reste le pilote. Aucun effet sans l'option.
func _draugr_pilote() -> void:
	if not _arguments().has("draugr-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["draugr-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	var d := DraugrNordique.creer({})
	add_child(d)
	d.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	d.rotation.y = deg_to_rad(p.z)
	var anim := String(_arguments().get("draugr-anim", "Sword_Idle"))
	(d.get_node("Animations") as AnimationPlayer).play(anim)
	if pilote == null:
		pilote = d
		if _arguments().has("capture"):
			_pilote_animer(anim, 0.25)

func _pilote_animer(nom: String, t: float) -> void:
	var ap := pilote.get_node("Animations") as AnimationPlayer
	if not ap.has_animation(nom):
		push_error("guerrier pilote : animation inconnue " + nom)
		return
	ap.play(nom)
	ap.seek(ap.get_animation(nom).length * t, true)
	ap.pause()

## --mage-pilote[=x,z,lacet°] : Mage nordique (MageNordique) au même poste que le guerrier pilote ; devient la cible des vues
## « pilote » (le guerrier, s'il est là aussi, est posé 1,1 m à sa gauche, même orientation : planche de famille).
## --mage-anim=Nom : animation (Idle par défaut ; signature : Spell_Simple_Shoot). Aucun effet sans l'option.
func _mage_pilote() -> void:
	if not _arguments().has("mage-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["mage-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	var guerrier := pilote
	pilote = MageNordique.creer({})
	add_child(pilote)
	pilote.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	pilote.rotation.y = deg_to_rad(p.z)
	if guerrier:
		var q := pilote.global_position + pilote.global_basis.x * 1.1
		guerrier.global_position = Vector3(q.x, hauteur(q.x, q.z), q.z)
		guerrier.rotation.y = pilote.rotation.y
	var nom := String(_arguments().get("mage-anim", "Idle"))
	(pilote.get_node("Animations") as AnimationPlayer).play(nom)
	if _arguments().has("capture"):
		_pilote_animer(nom, 0.25)
## --gardien-pilote[=x,z,lacet°] : Gardien nordique (GardienNordique), même emplacement par défaut que le guerrier pilote ; seul, il
## devient la cible des vues « pilote » ; avec --guerrier-pilote, il se tient à côté (comparaison de famille). --gardien-anim=Nom (Idle =
## garde en faction par défaut). Aucun effet sans l'option.
var gardien: Node3D

func _gardien_pilote() -> void:
	if not _arguments().has("gardien-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["gardien-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	gardien = GardienNordique.creer({})
	add_child(gardien)
	gardien.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	gardien.rotation.y = deg_to_rad(p.z)
	var nom := String(_arguments().get("gardien-anim", "Idle"))
	var ap := gardien.get_node("Animations") as AnimationPlayer
	ap.play(nom)
	if _arguments().has("capture"):
		ap.seek(ap.get_animation(nom).length * 0.25, true)
		ap.pause()
	if pilote == null:
		pilote = gardien
## --troll-pilote[=x,z,lacet°] : Troll de givre (TrollGivre) à la place du guerrier pour les vues « pilote » (le guerrier, s'il est
## demandé aussi, reste à sa place : planche d'échelle). --troll-anim=Nom (Idle par défaut). Vue grotte + option `troll=d` : le troll
## est posé à d m devant la caméra, tourné vers elle. Aucun effet sans l'option.
func _troll_pilote() -> void:
	if not _arguments().has("troll-pilote"):
		return
	var p := PILOTE_DEFAUT
	var a: String = _arguments()["troll-pilote"]
	if a != "":
		var f := a.split_floats(",")
		p = Vector3(f[0], f[1], f[2] if f.size() > 2 else p.z)
	pilote = TrollGivre.creer({})
	add_child(pilote)
	pilote.global_position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	pilote.rotation.y = deg_to_rad(p.z)
	_pilote_animer(String(_arguments().get("troll-anim", "Idle")), 0.25)

func _troll_grotte(d: float, anim: String) -> void:
	var av := -joueur.global_basis.z
	av.y = 0.0
	var pos := joueur.global_position + av.normalized() * d
	var r := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 4.0))
	pilote.global_position = r["position"] if r else pos
	pilote.rotation.y = atan2(-av.x, -av.z)   # face (+Z) tournée vers la caméra
	var an := anim.split(":")
	_pilote_animer(an[0], float(an[1]) if an.size() > 1 else 0.25)

# --- le tertre ----------------------------------------------------------------------

func _tertre() -> void:
	tertre = Node3D.new()
	tertre.set_script(TERTRE)
	tertre.monde = self
	tertre.joueur = joueur
	tertre.dialogue = dialogue
	tertre.quetes = quetes
	tertre.hud = hud
	tertre.position = Vector3(TUMULUS.x, hauteur(TUMULUS.x, TUMULUS.z), TUMULUS.z)
	tertre.porte_dehors = tertre.position + Vector3(0, 0, 2.8)
	tertre.orientation = PI  # en sortant, on regarde vers le cercle, au sud
	add_child(tertre)
	tertre.entree.connect(_sous_terre)
	# le sommeil de Svanhild rescellé, un dragon de givre vient tourner au-dessus du hameau
	quetes.change.connect(func() -> void:
		if quetes.etat.get("anneau_givre", 0) >= 6 and dragon == null and not dragon_vaincu:
			_dragon())
	hud.lieux.append([tertre.porte_dehors, Color("#6fd8ff")])

## Entrée de la grotte des bandits (flanc est) : bouche de roche, passage fondu, grotte bâtie en fil d'exécution.
func _grotte_acces() -> void:
	grotte_acces = Node3D.new()
	grotte_acces.set_script(GROTTE_ACCES)
	grotte_acces.monde = self
	grotte_acces.joueur = joueur
	grotte_acces.dialogue = dialogue
	grotte_acces.quetes = quetes
	grotte_acces.hud = hud
	grotte_acces.position = Vector3(GrotteAcces.SITE.x, h_grotte, GrotteAcces.SITE.y)
	grotte_acces.rotation.y = GrotteAcces.LACET
	add_child(grotte_acces)
	grotte_acces.entree.connect(func(dedans: bool) -> void:
		_sous_terre(dedans)
		if dedans:
			grotte_acces.grotte.ambiance(_env))
	hud.lieux.append([grotte_acces.porte_dehors, Color("#ffb347")])

func _dragon() -> void:
	dragon = CharacterBody3D.new()
	dragon.set_script(DRAGON)
	dragon.joueur = joueur
	dragon.hud = hud
	dragon.centre = Vector3(VILLAGE.x, h_village, VILLAGE.z)
	dragon.hauteur_sol = hauteur
	if _paisible():
		dragon.process_mode = Node.PROCESS_MODE_DISABLED  # --paisible : dragon figé
	dragon.vaincu.connect(func() -> void:
		dragon_vaincu = true
		quetes.signaler("tue:dragon")
		hud.avis("Le dragon de givre est vaincu"))
	add_child(dragon)
	hud.avis("Un rugissement fait trembler la forêt…")

## Sous terre : ni lune, ni neige, ni ciel ; une brume noire et froide.
func _sous_terre(dedans: bool) -> void:
	cycle.lumiere.visible = not dedans
	if arriere_plan != null:
		arriere_plan.visible = not dedans
	neige.visible = not dedans
	cycle.process_mode = Node.PROCESS_MODE_DISABLED if dedans else Node.PROCESS_MODE_INHERIT
	_env.background_mode = Environment.BG_COLOR if dedans else Environment.BG_SKY
	_env.background_color = Color(0.0, 0.0, 0.0)
	# Lot 7a : pénombre bleutée lisible (ambiant plus clair), brume courte et froide, pas de glow (halos nets,
	# dessinés dans la crypte) et tramage du post-traitement adouci (le Bayer 4x4 grésille dans le sombre).
	_env.glow_enabled = not dedans
	_sous_terre_actif = dedans
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL if dedans else Environment.FOG_MODE_DEPTH
	post.set_shader_parameter("tramage", 0.45 if dedans else 1.0)
	post.set_shader_parameter("etal_mix", 0.45 if dedans else 1.0)  # lot 2 : étalonnage atténué sous terre
	if dedans:
		_env.ambient_light_color = Color(0.40, 0.45, 0.62)
		_env.ambient_light_energy = 0.9
		_env.fog_light_color = Color(0.03, 0.045, 0.08)
		_env.fog_density = 0.028
		_env.fog_height_density = 0.0
		_env.fog_sky_affect = 1.0
	else:
		cycle._process(0.0)

# --- draugrs ---------------------------------------------------------------------

func _draugr(type: String, x: float, z: float, dort: bool, lacet := 0.0) -> CharacterBody3D:
	return creer_draugr(type, Vector3(x, hauteur(x, z) + 0.05, z), lacet, dort)

## Crée un draugr ; `options` règle ses propriétés (ident, echelle, vie_imposee, debout…) et les options de donjon documentées
## en tête de draugr.gd : patrouille (Array[Vector3] monde), archer, poste, degats_tir, reveil_evt, boss ("svanhild"|"hrafn"|"jarl").
func creer_draugr(type: String, position_: Vector3, lacet: float, dort: bool, options := {}) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = type
	d.dort = dort and not _arguments().has("reveiller")
	d.joueur = joueur
	d.hud = hud
	d.ident = options["boss"] if (options.has("boss") and not options.has("ident")) else "%s_%d" % [type, draugrs.size()]
	d.quetes = quetes
	for cle in options:
		d.set(cle, options[cle])
	draugrs[d.ident] = d
	d.position = position_
	d.rotation.y = lacet
	d.mort.connect(func(id: String) -> void: quetes.signaler("tue:" + id))
	add_child(d)
	return d

func _draugrs() -> void:
	# trois gardiens endormis au cercle de pierres, un guerrier debout à l'entrée
	_draugr("guerrier", CERCLE.x + 2.6, CERCLE.z + 1.2, true, 2.0)
	_draugr("sbire", CERCLE.x - 2.2, CERCLE.z + 2.6, true, -0.6)
	_draugr("sbire", CERCLE.x + 0.6, CERCLE.z - 3.0, true, 3.4)
	_draugr("guerrier", CERCLE.x + 9.0, CERCLE.z + 9.0, false, 0.8)
	# un rôdeur dans la forêt, entre le feu et le cercle
	sbire = _draugr("sbire", -16.0, -15.0, false, 0.6)

func _neige() -> void:
	neige = GPUParticles3D.new()
	neige.amount = 5000
	neige.lifetime = 9.0
	neige.preprocess = 9.0
	neige.local_coords = false
	neige.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.35, -1, 0.15)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.1, -0.25, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	neige.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.albedo_color = Color(0.85, 0.9, 1.0)
	# un flocon collé à l'objectif deviendrait un gros carré : il s'efface en tramage
	mq.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mq.distance_fade_min_distance = 0.4
	mq.distance_fade_max_distance = 1.5
	q.material = mq
	neige.draw_pass_1 = q
	add_child(neige)
	neige.global_position = joueur.global_position + Vector3(0, 10, 0)

func _interface() -> void:
	calque = CanvasLayer.new()
	add_child(calque)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST
	rect.material = post
	calque.add_child(rect)
	aide = Label.new()
	aide.text = "ZQSD : marcher   Maj : courir   Espace : sauter\nClic gauche : frapper (maintenir = coup puissant)\nClic droit : garde   T : torche   V : vue   P : effet PS1   Échap : souris"
	aide.add_theme_font_size_override("font_size", 8)
	aide.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
	aide.position = Vector2(6, 18)
	hud = Control.new()
	hud.set_script(HUD)
	hud.joueur = joueur
	hud.lieux = [[Vector3(CERCLE.x, 0, CERCLE.z), Color("#6fd8ff")], [Vector3.ZERO, Color("#e8a64a")]]
	calque.add_child(hud)
	calque.add_child(aide)
	if _arguments().has("capture"):
		aide.visible = false
	if _arguments().has("sans-ps1"):
		_basculer_ps1()

func _basculer_ps1() -> void:
	var actif: bool = not post.get_shader_parameter("actif")
	post.set_shader_parameter("actif", actif)
	Palette.regler_ps1(actif)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_P:
				_basculer_ps1()
			KEY_F5:
				sauvegarder()
				hud.avis("Partie sauvegardée")
			KEY_F9:
				# on relance le jeu plutôt que la scène : recréer le monde dans le même
				# processus fait planter Godot (modèles importés rechargés en double)
				if FileAccess.file_exists(fichier_sauvegarde()):
					OS.set_restart_on_exit(true, OS.get_cmdline_args())
					get_tree().quit()

func _exit_tree() -> void:
	Palette.vider()
	TexturesBati.vider()
	Humain.vider()
	Sons.vider()

func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST and not _arguments().has("capture"):
		sauvegarder()

# --- sauvegarde ------------------------------------------------------------------

func sauvegarder() -> void:
	if joueur.mort:
		return
	var morts := []
	for id in draugrs:
		if not is_instance_valid(draugrs[id]) or not draugrs[id].vivant():
			morts.append(id)
	for id in tertre.morts_charges:        # gardiens du donjon tués dans une partie précédente et pas (encore) réapparus
		if not morts.has(id):
			morts.append(id)
	for id in grotte_acces.morts_charges:  # idem pour les bandits de la grotte
		if not morts.has(id):
			morts.append(id)
	var parles := []
	for v in get_tree().get_nodes_in_group("villageois"):
		if v.get("deja_parle"):
			parles.append(v.donnees.get("id", ""))
	var donnees := {
		"version": 1,
		"joueur": {
			"position": [joueur.position.x, joueur.position.y, joueur.position.z],
			"lacet": joueur.rotation.y, "vie": joueur.vie, "vigueur": joueur.vigueur,
		},
		"heure": cycle.heure,
		"competences": joueur.competences.exporter(),
		"quetes": quetes.exporter(),
		"herse": tertre._herse_ouverte,
		"dragon_vaincu": dragon_vaincu,
		"inventaire": joueur.inventaire.exporter(),
		"draugrs_morts": morts,
		"villageois_parles": parles,
	}
	var f := FileAccess.open(fichier_sauvegarde(), FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees, "\t"))

func charger() -> void:
	if not FileAccess.file_exists(fichier_sauvegarde()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(fichier_sauvegarde()))
	if not d is Dictionary:
		push_warning("Sauvegarde illisible, nouvelle partie.")
		return
	var j: Dictionary = d.get("joueur", {})
	var p: Array = j.get("position", [])
	if p.size() == 3:
		joueur.position = Vector3(p[0], p[1] + 0.2, p[2])
	joueur.rotation.y = float(j.get("lacet", joueur.rotation.y))
	joueur.vie = float(j.get("vie", joueur.vie_max))
	joueur.vigueur = float(j.get("vigueur", joueur.vigueur_max))
	cycle.heure = float(d.get("heure", cycle.heure))
	joueur.competences.importer(d.get("competences", {}))
	joueur.inventaire.importer(d.get("inventaire", {}))
	dragon_vaincu = bool(d.get("dragon_vaincu", false))
	quetes.importer(d.get("quetes", {}))
	tertre.restaurer(bool(d.get("herse", false)))
	grotte_acces.morts_charges = d.get("draugrs_morts", [])
	grotte_acces.restaurer()      # sauvegardé dans la grotte : on y revient (position du fichier)
	tertre.morts_charges = d.get("draugrs_morts", [])      # le donjon de la crypte ne refait pas ceux-là
	for id in d.get("draugrs_morts", []):
		if draugrs.has(id):
			draugrs[id].queue_free()
			draugrs.erase(id)
	var parles: Array = d.get("villageois_parles", [])
	for v in get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id", "") in parles:
			v.deja_parle = true

func _process(dt: float) -> void:
	_t += dt
	_brume_locale(dt)
	if cycle != null and joueur != null and not _sous_terre_actif:
		cycle.orienter_brume(-joueur.camera.global_transform.basis.z)  # lot 2 : brouillard chaud côté soleil couchant
	neige.global_position = joueur.global_position + Vector3(0, 10, 0)
	# le feu vacille : deux sinus désaccordés + un peu de hasard
	feu_lumiere.light_energy = 3.2 + sin(_t * 11.0) * 0.25 + sin(_t * 23.7) * 0.18 + randf() * 0.25
	if _t > 14.0 and aide.modulate.a > 0.0:
		aide.modulate.a = maxf(0.0, aide.modulate.a - dt * 0.5)
	_remplir_audio()
	_minuterie_sauvegarde += dt
	if _minuterie_sauvegarde > 120.0 and not _arguments().has("capture"):
		_minuterie_sauvegarde = 0.0
		sauvegarder()

## Lot 7 : distance du brouillard variable. Creux et forêt dense : la brume se resserre (jusqu'à -35 %) ;
## crêtes : elle se dégage (jusqu'à +25 %), récompense d'exploration. Lissé sur ~1,5 s ; `net` = sans lissage (captures).
var _brume_t := 0.0
func _brume_locale(dt: float, net := false) -> void:
	if cycle == null or joueur == null or _sous_terre_actif:
		return  # sous terre, la crypte ou la grotte règlent leur propre brume
	_brume_t -= dt
	if _brume_t > 0.0 and not net:
		cycle.local = lerpf(cycle.local, _brume_cible, minf(dt * 0.8, 1.0))
		if abs(cycle.local - _brume_cible) > 0.002:
			cycle.appliquer_brume()
		return
	_brume_t = 0.4
	var p := joueur.global_position
	var moy := 0.0
	for k in 8:
		var a := k * TAU / 8.0
		moy += hauteur(p.x + cos(a) * 20.0, p.z + sin(a) * 20.0) / 8.0
	var relief := clampf((p.y - moy) * 0.05, -0.2, 0.25)
	var n := 0
	for t: Transform3D in arbres:
		var dx := t.origin.x - p.x
		var dz := t.origin.z - p.z
		if dx * dx + dz * dz < 196.0:  # 14 m
			n += 1
	var foret := -0.15 * clampf(n / 24.0, 0.0, 1.0)
	_brume_cible = 1.0 + relief + foret
	if net:
		cycle.local = _brume_cible
		cycle.appliquer_brume()

var _brume_cible := 1.0
var _sous_terre_actif := false

func _musique() -> void:
	var m := Node.new()
	m.set_script(preload("res://scripts/musique.gd"))
	m.monde = self
	add_child(m)

# --- son : vent et crépitement générés en direct -------------------------------

## Les `AudioStreamGenerator` du vent et du feu ne sont JAMAIS libérés avant la fin du processus (`reference()` : un
## compteur de références volontairement jamais rendu, ~44 Ko chacun). Raison : `AudioStreamGeneratorPlayback` ne tient qu'un
## POINTEUR BRUT vers son générateur, et le fil audio mixe encore le fondu de sortie de la lecture quelques millisecondes
## après la libération du lecteur (fermeture du monde, fin d'un test). Générateur libéré trop tôt = lecture d'une mémoire
## libérée = plantage natif aléatoire (code de sortie 5 sous Windows alors que « TOUT OK » est déjà affiché).
func _audio() -> void:
	var vent := AudioStreamPlayer.new()
	var gv := AudioStreamGenerator.new()
	gv.mix_rate = 22050
	gv.buffer_length = 0.25
	gv.reference()   # jamais rendu : voir le commentaire de _audio()
	vent.stream = gv
	vent.volume_db = -8.0
	add_child(vent)
	vent.play()
	_audio_vent = vent.get_stream_playback()

	var feu := AudioStreamPlayer3D.new()
	var gf := AudioStreamGenerator.new()
	gf.mix_rate = 22050
	gf.buffer_length = 0.25
	gf.reference()
	feu.stream = gf
	feu.unit_size = 2.5
	feu.position = feu_lumiere.position
	add_child(feu)
	feu.play()
	_audio_feu = feu.get_stream_playback()

func _remplir_audio() -> void:
	if _audio_vent == null:
		return
	var n := mini(_audio_vent.get_frames_available(), _audio_feu.get_frames_available())
	for i in n:
		_t_audio += 1.0 / 22050.0
		var blanc := randf() * 2.0 - 1.0
		# vent : bruit brun filtré, rafales lentes
		_brun = clampf(_brun * 0.996 + blanc * 0.03, -1.0, 1.0)
		_brun2 = _brun2 * 0.9 + _brun * 0.1
		var rafale := 0.45 + 0.55 * absf(sin(_t_audio * 0.23) * sin(_t_audio * 0.071 + 1.3))
		var v := _brun2 * 1.6 * rafale
		_audio_vent.push_frame(Vector2(v, v * 0.92))
		# feu : petits claquements secs sur un souffle grave
		_crepite *= 0.93
		if randf() < 0.0012:
			_crepite = randf_range(0.3, 1.0)
		var f := blanc * _crepite * 0.8 + _brun * 0.25
		_audio_feu.push_frame(Vector2(f, f))

# --- capture pour les tests ------------------------------------------------------

func _arguments() -> Dictionary:
	var res := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var parts := a.substr(2).split("=", true, 1)
			res[parts[0]] = parts[1] if parts.size() > 1 else ""
	if res.has("captures") and not res.has("capture"):
		res["capture"] = ""  # --captures=<fichier> : mode capture (temps figé, ni musique ni sauvegarde)
	return res

## --dans=bat,x,z,lacet°,tangage°[,ouvert] : se place dans (ou devant) une maison (hors capture : mesures de performance, essais ;
## repère du bâtiment, lacet 0 = vers -Z).
func _aller_interieur() -> void:
	var a: String = _arguments().get("dans", "")
	if a == "" or _arguments().has("capture"):
		return
	var p := a.split(",")
	var ip: Interieur = village.interieur(p[0])
	if ip == null or p.size() < 5:
		return
	if p.size() > 5 and p[5] == "ouvert":
		ip.basculer(true, false)
	joueur.global_position = ip.to_global(Vector3(float(p[1]), ip.sol_y + 0.12, float(p[2])))
	joueur.rotation.y = ip.global_rotation.y + deg_to_rad(float(p[3]))
	joueur.tete.rotation.x = deg_to_rad(float(p[4]))

## Ouvre des portes du donjon sans animation (captures, essais) : « s1,s2,s3,secret,herse ».
func _ouvrir_donjon(liste: String) -> void:
	for id in liste.split(","):
		if id == "herse":
			tertre.herse.position.y = 2.9
		elif id != "":
			tertre.quetes.vus["crypte:" + id] = true
	tertre._etat_donjon()

## --crypte=x,z,lacet°,tangage° : descend dans la crypte et s'y place (mesures de performance, essais ; repère de la crypte).
func _aller_crypte() -> void:
	var a: String = _arguments().get("crypte", "")
	if a == "" or _arguments().has("capture"):
		return
	tertre._passer(true)
	await get_tree().create_timer(1.3).timeout
	var cp: PackedStringArray = a.split(",")
	joueur.global_position = tertre.crypte.to_global(Vector3(float(cp[0]), float(cp[4]) + 0.1 if cp.size() > 4 else 0.1, float(cp[1])))
	joueur.rotation.y = tertre.crypte.global_rotation.y + deg_to_rad(float(cp[2]))
	joueur.tete.rotation.x = deg_to_rad(float(cp[3]))

## Grotte vitrine (lot grotte, scripts/grotte.gd) : construite à la demande sous le monde (y = -220), sans entrée.
## --grotte=s,décalage,lacet°,tangage° (hors capture) ou --scenario=grotte --gpose=… : s = mètres le long du parcours (0-124),
## décalage latéral (+ = droite), lacet 0 = vers le fond.
var grotte: Node

func _aller_grotte(pose: String) -> void:
	grotte = grotte_acces.obtenir()
	grotte_acces.montrer(true)
	_sous_terre(true)
	grotte.ambiance(_env)
	var p := pose.split_floats(",")
	joueur.global_position = grotte.monde_sol(p[0], p[1]) + Vector3(0, 0.1, 0)
	joueur.rotation.y = grotte.cap_monde(p[0]) + deg_to_rad(p[2])
	joueur.tete.rotation.x = deg_to_rad(p[3])

## --sans-particules : cache neige et flammes (feu, torches) pour comparer des captures au pixel près.
func _cacher_particules() -> void:
	if not _arguments().has("sans-particules"):
		return
	for p in find_children("*", "GPUParticles3D", true, false):
		p.visible = false

func _paisible() -> bool:
	return _arguments().has("paisible")

## --paisible : draugrs figés à leur point d'apparition (modèles visibles), dragon figé,
## pas de dégâts au joueur ; captures avant/après comparables. N'affecte pas les draugrs
## créés ensuite par un scénario (mort, galerie…).
func _rendre_paisible() -> void:
	if not _paisible():
		return
	for id in draugrs:
		draugrs[id].process_mode = Node.PROCESS_MODE_DISABLED

func _capture() -> void:
	var chemin: String = _arguments().get("capture", "")
	while _arguments().has("capture") and not village.prets:   # les intérieurs se construisent en fil : une capture ne part qu'une fois tout posé
		await get_tree().process_frame
	if _arguments().has("captures"):
		await _lot_captures(String(_arguments()["captures"]))
		return
	if chemin == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in (int(_arguments().get("attente", "90"))):
		await get_tree().process_frame
	_cacher_particules()
	if _arguments().has("sans-mains"):
		joueur.mains.visible = false  # captures de décor (lot 2 : arbres) sans les bras FPS
		for i in 3:
			await get_tree().process_frame
	if _arguments().has("test-combat"):
		await _test_combat()
	if _arguments().has("scenario"):
		await _scenario(_arguments()["scenario"])
	if _arguments().has("camera-debug"):
		# filme le joueur de côté (réglage des bras à la 1re personne)
		var c := Camera3D.new()
		add_child(c)
		var cam: Camera3D = joueur.camera
		c.global_position = cam.to_global(Vector3(1.4, 0.2, -0.9))
		c.look_at(cam.to_global(Vector3(0.0, -0.25, -0.35)))
		c.current = true
		for i in 5:
			await get_tree().process_frame
	if _arguments().has("camera-main"):
		# gros plan sur une main (vérifier la prise) : --camera-main=d|g,dessus|dessous|dehors|dedans|face|joueur
		var c := Camera3D.new()
		add_child(c)
		c.fov = 40.0
		c.near = 0.01
		var reglage: PackedStringArray = String(_arguments()["camera-main"]).split(",")
		var accroche: Node3D = joueur.mains._accroche_g if reglage[0] == "g" else joueur.mains._accroche_d
		var cam: Camera3D = joueur.camera
		var centre := accroche.global_position
		var dirs := {"dessus": Vector3(0, 1, 0.2), "dessous": Vector3(0, -1, 0.2), "dehors": Vector3(1, 0, 0), "dedans": Vector3(-1, 0, 0), "face": Vector3(0, 0, -1), "joueur": Vector3(0, 0.3, 1)}
		var d: Vector3 = cam.global_transform.basis * (dirs.get(reglage[1] if reglage.size() > 1 else "dehors", Vector3.RIGHT) as Vector3).normalized()
		c.global_position = centre + d * (float(reglage[2]) if reglage.size() > 2 else 0.32)
		var haut := cam.global_transform.basis.y if absf(d.dot(cam.global_transform.basis.y)) < 0.9 else -cam.global_transform.basis.z
		c.look_at(centre, haut)
		c.current = true
		for i in 5:
			await get_tree().process_frame
	print("FPS : ", Engine.get_frames_per_second(), " joueur=", joueur.global_position, " lacet=", joueur.rotation.y, " tangage=", joueur.tete.rotation.x, " cam=", joueur.camera.global_position)
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(chemin)
	get_tree().quit()

## --captures=<fichier> : plusieurs captures en UN lancement (monde construit une fois).
## Une ligne par vue : `nom type coords [option=valeur …]` ; `#` = commentaire. Types :
##   monde x,z,lacet°,tangage°      crypte x,z,lacet°,tangage° (repère de la crypte)
##   grotte s,décalage,lacet°,tangage°      scenario <nom> (village, place, forge, dialogue…)
##   interieur x,z,lacet°,tangage° bat=halle|sigrun|chasseurs|grima|forge [ouvert]  (repère du bâtiment ; lacet 0 = vers -Z)
## Options : heure=12 (sinon l'heure de départ, nuit) · sans-mains · torche-eteinte · attente=N images.
## --attente= vaut pour la 1re vue ; les suivantes attendent --attente-suite= (20) images.
## Les PNG vont dans --sortie=<dossier> (ou à côté du fichier de poses), nommés <nom>.png.
## Ordre imposé : monde, puis scénarios, puis crypte, puis grotte (on ne ressort pas du sous-sol).
## Les options globales (--paisible, --sans-particules, --sans-mains, --sans-hud, --attente=) valent pour toutes les vues.
func _lot_captures(fichier: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var texte := FileAccess.get_file_as_string(fichier)
	if texte == "":
		push_error("--captures : fichier de poses introuvable ou vide : " + fichier)
		get_tree().quit(1)
		return
	var sortie: String = _arguments().get("sortie", fichier.get_base_dir())
	DirAccess.make_dir_recursive_absolute(sortie)
	var rang := {"monde": 0, "interieur": 0, "pilote": 0, "scenario": 1, "crypte": 2, "grotte": 3}
	var vues: Array = []
	for ligne in texte.split("\n"):
		var m := ligne.strip_edges().split(" ", false)
		if m.size() < 3 or m[0].begins_with("#"):
			continue
		var v := {"nom": m[0], "type": m[1], "coords": m[2], "opt": {}}
		for k in range(3, m.size()):
			var kv := m[k].split("=", true, 1)
			v["opt"][kv[0]] = kv[1] if kv.size() > 1 else ""
		vues.append(v)
	vues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rang.get(a["type"], 0) < rang.get(b["type"], 0))
	var heure_depart: float = cycle.heure
	var depart := _etat_lumiere()
	var attente_globale := int(_arguments().get("attente", "90"))
	var attente_suite := int(_arguments().get("attente-suite", "20"))
	var mains_globales := _arguments().has("sans-mains")
	var torche_masque: int = joueur.mains.torche_lumiere.light_cull_mask
	if _arguments().has("sans-hud"):   # --sans-hud : ni boussole ni répliques (planches de personnages)
		hud.visible = false
		if dialogue:
			dialogue.visible = false
	var dessous := ""
	var t0 := Time.get_ticks_msec()
	var n := 0
	for v in vues:
		var opt: Dictionary = v["opt"]
		var type: String = v["type"]
		var c := PackedFloat64Array()
		if type != "scenario":
			c = String(v["coords"]).split_floats(",")
		if type == "monde" or type == "scenario" or type == "interieur" or type == "pilote":
			if dessous != "":
				push_error("--captures : vue monde/scénario « %s » après le sous-sol, ignorée" % v["nom"])
				continue
			if opt.has("heure"):
				cycle.heure = float(opt["heure"])
				cycle._process(0.0)
			else:
				cycle.heure = heure_depart
				cycle._process(0.0)  # lot 2 : le lancement isolé applique aussi cycle._process à l'heure de départ
			if type == "monde":
				joueur.global_position = Vector3(c[0], hauteur(c[0], c[1]) + 0.1, c[1])
				joueur.rotation.y = deg_to_rad(c[2])
				joueur.tete.rotation.x = deg_to_rad(c[3]) if c.size() > 3 else 0.0
				joueur.velocity = Vector3.ZERO
				_brume_locale(0.0, true)
			elif type == "pilote":
				# guerrier pilote : caméra à c[0] m, azimut c[1]° (0 = de face), visant c[2] m au-dessus de ses pieds (1,0 par défaut)
				if pilote == null:
					push_error("--captures : vue « pilote » sans --guerrier-pilote")
					continue
				var an := String(opt.get("anim", String(_arguments().get("guerrier-anim", "Sword_Idle")))).split(":")
				_pilote_animer(an[0], float(an[1]) if an.size() > 1 else 0.25)
				var pp := pilote.global_position
				var dir := pilote.global_basis.z.rotated(Vector3.UP, deg_to_rad(c[1]))
				dir.y = 0.0
				var pos := pp + dir.normalized() * c[0]
				if opt.has("decal"):     # décalage latéral de la caméra (m) : contrôle de scintillement
					pos += dir.cross(Vector3.UP).normalized() * float(opt["decal"])
				pos.y = hauteur(pos.x, pos.z) + 0.1
				joueur.global_position = pos
				var vers := pp - pos
				joueur.rotation.y = atan2(-vers.x, -vers.z)
				var oeil_y := pos.y + 1.62
				var cible_y := pp.y + (c[2] if c.size() > 2 else 1.0)
				joueur.tete.rotation.x = atan2(cible_y - oeil_y, Vector2(vers.x, vers.z).length())
				joueur.velocity = Vector3.ZERO
				_brume_locale(0.0, true)
			elif type == "interieur":
				# lot « kit intérieur » : `nom interieur x,z,lacet°,tangage° bat=halle|sigrun|chasseurs|grima|forge [ouvert]` (repère du bâtiment)
				var ip: Interieur = village.interieur(String(opt.get("bat", "halle")))
				ip.basculer(opt.has("ouvert"), false)
				joueur.global_position = ip.to_global(Vector3(c[0], ip.sol_y + 0.12, c[1]))
				joueur.rotation.y = ip.global_rotation.y + deg_to_rad(c[2])
				joueur.tete.rotation.x = deg_to_rad(c[3]) if c.size() > 3 else 0.0
				joueur.velocity = Vector3.ZERO
				_brume_locale(0.0, true)
		elif type == "crypte":
			if dessous == "":
				tertre._passer(true)
				await get_tree().create_timer(1.3).timeout
				dessous = "crypte"
			if opt.has("ouvre"):     # ouvre=s1,s2,s3,secret,herse : portes ouvertes (captures du donjon) ; y optionnel en 5e coordonnée
				_ouvrir_donjon(String(opt["ouvre"]))
			joueur.global_position = tertre.crypte.to_global(Vector3(c[0], c[4] + 0.1 if c.size() > 4 else 0.1, c[1]))
			joueur.rotation.y = tertre.crypte.global_rotation.y + deg_to_rad(c[2])
			joueur.tete.rotation.x = deg_to_rad(c[3])
			joueur.velocity = Vector3.ZERO
		elif type == "grotte":
			if dessous != "grotte":
				if dessous == "crypte":
					tertre.crypte.visible = false  # on quitte la crypte pour la grotte (autre lieu sous terre)
				grotte = grotte_acces.obtenir()
				grotte_acces.montrer(true)
				_sous_terre(true)
				grotte.ambiance(_env)
				dessous = "grotte"
			joueur.global_position = grotte.monde_sol(c[0], c[1]) + Vector3(0, 0.1, 0)
			joueur.rotation.y = grotte.cap_monde(c[0]) + deg_to_rad(c[2])
			joueur.tete.rotation.x = deg_to_rad(c[3])
			joueur.velocity = Vector3.ZERO
			if opt.has("troll") and pilote:
				_troll_grotte(float(opt["troll"]), String(opt.get("anim", "Idle")))
		else:
			push_error("--captures : type inconnu « %s » (vue %s)" % [type, v["nom"]])
			continue
		joueur.mains.torche_lumiere.light_cull_mask = 0 if opt.has("torche-eteinte") else torche_masque
		joueur.mains.visible = not (mains_globales or opt.has("sans-mains"))
		# 1re vue : attente complète (compilation des shaders, stabilisation) ; les suivantes : --attente-suite (20 images)
		var att: int = int(opt["attente"]) if opt.has("attente") else (attente_globale if n == 0 else mini(attente_globale, attente_suite))
		for i in att:
			await get_tree().process_frame
		_cacher_particules()
		if type == "scenario":
			await _scenario(String(v["coords"]))
		for i in 3:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(sortie.path_join(String(v["nom"]) + ".png"))
		n += 1
		print("CAPTURE ", v["nom"], " (", type, ") joueur=", joueur.global_position)
	print("LOT : %d captures en %.1f s" % [n, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit()

func _etat_lumiere() -> Dictionary:
	return {
		"basis": cycle.lumiere.basis, "couleur": cycle.lumiere.light_color, "energie": cycle.lumiere.light_energy,
		"amb": _env.ambient_light_color, "amb_e": _env.ambient_light_energy,
		"brume": _env.fog_light_color, "dens": _env.fog_density, "local": cycle.local,
		"horizon": cycle._horizon, "fin_base": cycle._fin_base, "expo": _env.tonemap_exposure, "seuil_glow": _env.glow_hdr_threshold,
		"ciel_horizon": _ciel.get_shader_parameter("horizon_courant"), "ciel_haut": _ciel.get_shader_parameter("haut_courant"),
		"jour": _ciel.get_shader_parameter("jour"), "soleil": _ciel.get_shader_parameter("soleil"),
	}

func _restaurer_lumiere(e: Dictionary) -> void:
	cycle.lumiere.basis = e["basis"]
	cycle.lumiere.light_color = e["couleur"]
	cycle.lumiere.light_energy = e["energie"]
	_env.ambient_light_color = e["amb"]
	_env.ambient_light_energy = e["amb_e"]
	_env.fog_light_color = e["brume"]
	_env.fog_density = e["dens"]
	cycle.local = e["local"]
	cycle._horizon = e["horizon"]
	cycle._fin_base = e["fin_base"]
	_env.tonemap_exposure = e["expo"]
	_env.glow_hdr_threshold = e["seuil_glow"]
	_ciel.set_shader_parameter("horizon_courant", e["ciel_horizon"])
	_ciel.set_shader_parameter("haut_courant", e["ciel_haut"])
	cycle.appliquer_brume()
	_ciel.set_shader_parameter("jour", e["jour"])
	_ciel.set_shader_parameter("soleil", e["soleil"])

## Test automatique : le joueur se place face au rôdeur et enchaîne des coups.
func _test_combat() -> void:
	var cible := sbire.global_position + Vector3(0, 0, 2.2).rotated(Vector3.UP, sbire.rotation.y)
	joueur.global_position = cible
	joueur.look_at(Vector3(sbire.global_position.x, joueur.global_position.y, sbire.global_position.z))
	joueur.tete.rotation.x = -0.1
	for i in 30:
		await get_tree().physics_frame
	print("draugr : etat=", sbire.etat, " vie=", sbire.vie)
	var coups: Array = _arguments().get("test-combat", "lpll").split("")
	for c in coups:
		joueur.mains.attaquer(c == "p")
		await get_tree().create_timer(0.75).timeout
		print("coup ", c, " -> draugr etat=", sbire.etat, " vie=", sbire.vie, " | joueur vie=", snappedf(joueur.vie, 0.1), " vigueur=", snappedf(joueur.vigueur, 0.1))
	joueur.mains.attaquer(false)
	await get_tree().create_timer(0.16).timeout

func _viser(cible: Vector3) -> void:
	var cam: Vector3 = joueur.camera.global_position
	joueur.look_at(Vector3(cible.x, joueur.global_position.y, cible.z))
	var d: Vector3 = cible - cam
	joueur.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _placer(pos: Vector3, cible: Vector3) -> void:
	joueur.global_position = Vector3(pos.x, hauteur(pos.x, pos.z) + 0.1, pos.z) if pos.y > -50.0 else pos
	_viser(cible)

## Mises en scène pour les captures : --scenario=village|place|forge|dialogue|crypte|tombe|dragon
func _scenario(nom: String) -> void:
	var v := village
	match nom:
		"village":
			_placer(v.to_global(Vector3(0, 0, 30)), v.to_global(Vector3(0, 2.5, 0)))
		"place":
			_placer(v.to_global(Vector3(4, 0, 7)), v.to_global(Vector3(0, 2.2, -12)))
		"interieur":
			# --bat=halle|sigrun|chasseurs|grima|forge --ipose=x,z,lacet°,tangage° (repère du bâtiment ; lacet 0 = vers -Z)
			# [--ouvert] porte ouverte ; [--ext] pose exprimée hors du bâtiment (même repère)
			var ip: Interieur = v.interieur(String(_arguments().get("bat", "halle")))
			var a: PackedStringArray = String(_arguments().get("ipose", "0,0,0,0")).split(",")
			if _arguments().has("ouvert"):
				ip.basculer(true, false)
			joueur.global_position = ip.to_global(Vector3(float(a[0]), ip.sol_y + 0.12, float(a[1])))
			joueur.rotation.y = ip.global_rotation.y + deg_to_rad(float(a[2]))
			joueur.tete.rotation.x = deg_to_rad(float(a[3]) if a.size() > 3 else 0.0)
			for i in 40:
				await get_tree().process_frame
		"forge":
			_placer(v.to_global(Vector3(-6, 0, 9)), v.to_global(Vector3(-12.5, 1.2, 6)))
		"dialogue":
			var chef: Node3D
			for p in get_tree().get_nodes_in_group("villageois"):
				if p.donnees.get("id") == "chef":
					chef = p
			chef.set_physics_process(false)
			var devant := chef.global_position + Vector3(0, 0, 2.0)
			_placer(devant, chef.global_position + Vector3(0, 1.5, 0))
			await get_tree().create_timer(0.3).timeout
			dialogue._ouvrir(chef)
			await get_tree().create_timer(2.5).timeout
		"mort":
			# un draugr tué d'un coup puissant venu de la gauche de l'image : il doit tomber à plat sur la pente
			var x0 := 5.0
			var z0 := -7.0
			var dm := creer_draugr("guerrier", Vector3(x0, hauteur(x0, z0) + 0.05, z0), 0.0, false)
			dm.set_physics_process(false)
			joueur.global_position = Vector3(40, hauteur(40, 40) + 0.1, 40)
			var c := Camera3D.new()
			add_child(c)
			c.global_position = Vector3(x0 + 2.0, hauteur(x0, z0) + 1.1, z0 + 3.3)
			c.look_at(Vector3(x0 + 2.0, hauteur(x0, z0) + 0.1, z0))
			c.current = true
			await get_tree().create_timer(0.5).timeout
			dm.etat = dm.GARDE
			dm.vie = 1.0
			dm.recevoir_coup(40.0, dm.global_position + Vector3(-1.8, 0, 0), true)
			await get_tree().create_timer(3.5).timeout
		"galerie":
			# habitants côte à côte devant le feu (lot 4 : les vraies tenues du jeu, dont un draugr) ; --galerie=chef,garde,... pour choisir
			var ids: PackedStringArray = String(_arguments().get("galerie", "forgeron,chef,volva,garde,draugr")).split(",")
			var tenues: Array = []
			for id in ids:
				if id == "draugr":
					tenues.append({"corps": "homme", "draugr": true, "casque": "casque_draugr", "etoffes": {"tunique": "mailles_rouille", "brassards": "draugr"},
						"tenue": {"tunique": Color.WHITE, "ceinture": Color.WHITE, "brassards": Color.WHITE, "mante": Color.WHITE, "bottes": Color.WHITE, "epaulieres": Color.WHITE, "pteruges": Color.WHITE, "cape_courte": Color.WHITE}})
				elif VILLAGEOIS.APPARENCES.has(id):
					tenues.append(VILLAGEOIS.APPARENCES[id])
			for i in tenues.size():
				var h := Humain.creer(tenues[i])
				add_child(h)
				var x := -1.6 * (tenues.size() - 1) * 0.5 + i * 1.6
				h.global_position = Vector3(x, hauteur(x, -4.6), -4.6)
				h.rotation.y = 0.0
				(h.get_node("Animations") as AnimationPlayer).play(["Idle", "Idle_Talking", "Idle", "Idle_Talking", "Sword_Idle"][i % 5])
			joueur.mains.visible = false
			_placer(Vector3(0, 0, -1.3), Vector3(0, 1.1, -4.6))
			await get_tree().create_timer(1.0).timeout
		"crypte", "tombe":
			tertre._passer(true)
			await get_tree().create_timer(1.3).timeout
			if _arguments().has("cpose"):
				# --cpose=x,z,lacet,tangage (repère de la crypte ; lacet 0 = vers -Z) ; --sans-torche
				var cp: PackedStringArray = String(_arguments()["cpose"]).split(",")
				if _arguments().has("couvre"):      # --couvre=s1,s2,s3,secret,herse : portes ouvertes (captures du donjon)
					_ouvrir_donjon(String(_arguments()["couvre"]))
				joueur.global_position = tertre.crypte.to_global(Vector3(float(cp[0]), float(cp[4]) + 0.1 if cp.size() > 4 else 0.1, float(cp[1])))
				joueur.rotation.y = tertre.crypte.global_rotation.y + deg_to_rad(float(cp[2]))
				joueur.tete.rotation.x = deg_to_rad(float(cp[3]))
				if _arguments().has("torche-eteinte"):
					joueur.mains.torche_lumiere.light_cull_mask = 0
				await get_tree().create_timer(0.8).timeout
			elif nom == "crypte":
				_placer(tertre.crypte.to_global(Vector3(2, 0.1, -19.5)), tertre.crypte.to_global(Vector3(-3, 1.4, -28)))
			else:
				joueur.inventaire.ajouter("anneau_givre")
				_placer(tertre.crypte.to_global(Vector3(0, 0.1, -65.0)), tertre.crypte.to_global(Vector3(0, 1.8, -72.0)))
				await get_tree().create_timer(2.5).timeout
		"grotte":
			_aller_grotte(_arguments().get("gpose", "4,0,0,-5"))
			await get_tree().create_timer(0.8).timeout
		"dragon", "dragon_sol", "dragon_loin":
			_dragon()
			_placer(v.to_global(Vector3(0, 0, 4)), dragon.global_position)
			for i in (3000 if nom == "dragon_sol" else 30):
				await get_tree().process_frame
				_viser(dragon.global_position + Vector3(0, 1.5, 0))
				if nom != "dragon" and dragon.nom_etat() == "AU_SOL":
					break
			if nom == "dragon_loin":
				# recul pour voir toute la silhouette ; le dragon est figé pour la photo
				var dir := (joueur.global_position - dragon.global_position)
				dir.y = 0.0
				var loin := dragon.global_position + dir.normalized().rotated(Vector3.UP, 0.6) * 22.0
				joueur.set_physics_process(false)
				joueur.global_position = Vector3(loin.x, hauteur(loin.x, loin.z) + 5.0, loin.z)
				_viser(dragon.global_position + Vector3(0, 2.0, 0))
				await get_tree().create_timer(0.5).timeout
				dragon.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 20:
		await get_tree().process_frame
		if nom.begins_with("dragon"):
			_viser(dragon.global_position + Vector3(0, 2.0 if nom == "dragon_loin" else 1.5, 0))
