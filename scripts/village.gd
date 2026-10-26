extends Node3D
## Skarnholt : hameau nordique entouré d'une palissade.
## Repère local : sol plat en y = 0, +Z = la porte (tournée vers le feu de camp).
## Expose `lieux` (postes des villageois, en coordonnées monde) et `promenade`.

const RAYON := 22.0          # palissade
const DEMI_PORTE := 2.4      # demi-largeur de l'ouverture

var lieux := {}
var promenade: Array[Vector3] = []
var sedentaires: Array[String] = ["forge"]   # postes intérieurs : on n'en sort pas se promener

var corps: StaticBody3D
var rng := RandomNumberGenerator.new()
var _flammes: Array = []  # [OmniLight3D, énergie de base, décalage]
var _t := 0.0

var m_planches: ShaderMaterial
var m_poutres: ShaderMaterial
var m_poutres_h: ShaderMaterial
var m_neige: ShaderMaterial
var m_toit: ShaderMaterial
var m_rondins: ShaderMaterial
var m_bout: ShaderMaterial
var m_ame: ShaderMaterial
var m_roche: ShaderMaterial
var m_soubassement: ShaderMaterial    # D/neige_murs : remplissage des soubassements et socles (pierre chaude des murs de soutènement)
var m_brute_soub: ShaderMaterial      # pierres brutes en saillie des soubassements, teinte chaude
var m_brute: ShaderMaterial
var m_pierre_fine: ShaderMaterial
var m_fer: ShaderMaterial
var m_foin: ShaderMaterial
var m_cuir: ShaderMaterial
var m_ecorce: ShaderMaterial
var m_palissade: ShaderMaterial
var m_fenetre: ShaderMaterial
var m_braises: ShaderMaterial
var m_eau: ShaderMaterial
var m_glace: ShaderMaterial
var mats_int: Dictionary                 # matières d'intérieur (Interieurs.materiaux)
var interieurs: Array[Interieur] = []    # un par bâtiment enterable : longue maison, 3 maisons, forge
var _nuit_vitre := -1.0
## Refonte « entrée du village » (bâti) : toits raides à neige épaisse débordante, pignons à colombages et têtes de
## dragon, fenêtres de pignon, fumée en pixels, palissade de pieux taillés. `--sans-refonte-bati` = ancien bâti (A/B).
var _sans_refonte := "--sans-refonte-bati" in OS.get_cmdline_user_args()
const PENTE_TOIT := 53.0          # degrés (pente des toits des maisons : raide, comme l'image de référence)
const RELEVE_EGOUT := 0.3         # l'égout est à y0 - 0,3 m (au lieu de 0,5) : on passe sous le rouleau de neige
const EPAISSEUR_NEIGE := 0.42
var m_colombage: ShaderMaterial   # poutres sombres des pignons, planches de rive, têtes de dragon
var m_vitre_ext: ShaderMaterial   # vitrage vu du dehors : lueur réglée par l'heure (faible le jour)
var m_fen_pignon: ShaderMaterial  # fenêtre de pignon émissive (même réglage)
var _fumees: Array[StandardMaterial3D] = []
var _vitres: Node3D
const TEINTE_COLOMBAGE := Color(0.44, 0.4, 0.4)
const LUEUR := Color(0.988, 0.71, 0.227)   # vitre émissive #fcb53a (DIRECTION_ARTISTIQUE §6, préréglage « lanterne »)
## Passe 4 : halos chauds des fenêtres et matière commune des fumées (modulés par la nuit dans `_process`).
var _mat_halo: StandardMaterial3D
var _mat_fumee: StandardMaterial3D
var _nuit_halo := -1.0
var avec_habillage := not OS.get_cmdline_user_args().has("--sans-habillage-maisons")   # A/B de coût et d'aspect
## Le mobilier des intérieurs se construit dans UN fil de travail, hors de l'arbre (un `Interieur` temporaire reçoit lots, flammes
## et lumières), puis est posé par petites tâches de ≤ BUDGET_INT_US µs par image sur le fil principal : plus aucune image de
## 40-700 ms au chargement (les maisons sont invisibles de loin, le joueur démarre à plus de 13 m des portes).
const BUDGET_INT_US := 1500
var _jobs: Array = []                    # [Interieurs, Callable] : travaux du fil
var _fil := -1                           # tâche WorkerThreadPool
var _mutex := Mutex.new()
var _faits: Array = []                   # [Interieur réel, Interieur temporaire, collisions] construits, à poser
var _coll_fil: Array = []                # collisions demandées par le fil : [parent, forme, transform local]
var _a_poser: Array[Callable] = []       # petites tâches de pose (fil principal)
var _nb_poses := 0
var prets := false           # vrai quand tous les intérieurs sont construits et posés
signal interieurs_prets
## Village v2 (C7b) : monde (relief), emprises des bâtiments (replacement sûr au chargement), pieux et grilles de la palissade
## prolongée (tests), ailes du moulin à vent (animées).
var _monde: Node
var emprises: Array = []                 # [Node3D pivot, Vector2 demi-emprise, Vector2 décalage local, Interieur ou null]
var pieux_v2: Array[Vector3] = []        # pieds des pieux (monde)
var grilles_v2: Array = []               # [Vector3 pied (monde), niveau d'eau] : pieux fins des 2 grilles d'eau
var ailes_moulin: Node3D
const PORTES_V2 := [1, 3, 6]             # indices de ReliefVillage.PALISSADE : porte SO (inchangée), N, E
const GRILLES_V2 := [9, 15]              # grille E (65 ; 61,5) et grille O (19,5 ; 61,5)

## Vrai quand _ready a tout bâti (chargement étalé : _ready rend la main entre ses étapes, voir `_souffle`).
var bati := false
signal bati_fini

func _ready() -> void:
	_monde = get_parent()   # avant tout : `_souffle` passe par le monde (VillageBati lit aussi v._monde)
	rng.seed = 99
	corps = StaticBody3D.new()
	add_child(corps)
	# Lot « bâti 3 » : matières extérieures peintes à 64 texels/m (textures `_e`, neige `neige_e`), relief sur la normale, mipmaps nearest (TexturesBati)
	m_planches = TexturesBati.m_planches_e(Color(0.95, 0.93, 0.92))      # planches horizontales
	m_poutres = TexturesBati.m_bois_debout_e(Color(0.92, 0.9, 0.88))      # poteaux, portes, caisses (fil vertical)
	m_poutres_h = TexturesBati.m_planches_e(Color(0.9, 0.87, 0.85))       # solives, rives, dessous de toit
	m_rondins = TexturesBati.m_rondins_e(Color(1.4, 1.32, 1.24))
	m_bout = TexturesBati.m_bout_rondin()
	m_ame = TexturesBati.m_planches_e(Color(0.3, 0.29, 0.32))             # fond sombre derrière les rondins (joints)
	m_neige = TexturesBati.m_neige_toit_e()
	m_toit = TexturesBati.m_tourbe_e()                                    # toits : alpha 0 = neige, 1 = tourbe sombre
	# E/pierre_chaude : murs des maisons en pierre, tour-clocher, murets de la forge et socle du moulin en pierre CHAUDE (était
	# pierre_seche_e gris-bleu (1.3, 1.28, 1.32)), cohérente avec les soutènements (pierre_mur_e (1.62, 1.47, 1.3)) et les soubassements
	m_roche = TexturesBati.materiau_e("pierre_maison_e", Color(1.58, 1.45, 1.3))
	m_soubassement = TexturesBati.m_pierre_mur_e(Color(1.5, 1.38, 1.24))
	m_brute_soub = TexturesBati.m_pierre_brute_e(Color(1.32, 1.2, 1.06))
	m_brute = TexturesBati.m_pierre_brute_e(Color(1.56, 1.36, 1.08))      # chaînages, linteaux, cordons : teinte chaude (base roche bleutée → compensée) (était (1.18, 1.16, 1.2))
	m_pierre_fine = TexturesBati.m_pierre_fine_e(Color(1.4, 1.3, 1.18))   # socle de la tour, fûts de cheminée : teinte chaude (était (1.25, 1.23, 1.27))
	m_fer = TexturesBati.m_fer_e(Color(0.8, 0.82, 0.9))
	m_foin = TexturesBati.m_foin_e(Color(0.85, 0.85, 0.8))
	m_cuir = TexturesBati.m_cuir_e(Color(1.3, 1.15, 1.0))
	m_ecorce = TexturesBati.m_ecorce()
	m_palissade = TexturesBati.m_bois_debout_e(Color(1.1, 0.98, 0.88))     # pieux : bois grisé à 64 texels/m (l'écorce d'arbre ne lit qu'à 16)
	m_fenetre = TexturesBati.m_fenetre()
	m_braises = TexturesBati.m_braises()
	m_glace = TexturesBati.m_glace_e()
	m_eau = Palette.materiau(Palette.tex("eau", ["#05070c", "#0a0f18", "#101824", "#162030"], 4, 0.3))
	m_colombage = ShaderMaterial.new()   # étiquette : rejoint le lot `m_poutres_h`, assombri par la couleur de sommet (`_ajouter`)
	m_fen_pignon = TexturesBati.m_fenetre()
	_vitres = _pivot(Vector3.ZERO, 0.0)  # tous les vitrages vus du dehors : UN maillage (au lieu d'un par fenêtre)
	_vitres.name = "Vitrages"

	Chrono.marque("  village : matières bâti")
	await _souffle()
	mats_int = Interieurs.materiaux()
	m_vitre_ext = mats_int["vitre"]
	if not _sans_refonte:
		m_vitre_ext = (mats_int["vitre"] as ShaderMaterial).duplicate()
		Palette.materiaux.append(m_vitre_ext)
	Chrono.marque("  village : matières intérieur")
	await _souffle()
	# Village v2 (lot C7b, plan docs/PLAN_VILLAGE_V2.md) : tout est placé en coordonnées MONDE (x est, z sud) ; le nœud du
	# village garde son repère (porte SO en local (0, 0, RAYON), tournée vers le feu) et le sol du plateau (y local 0).
	_palissade_v2()
	_porte()
	_porte_v2(ReliefVillage.PALISSADE[PORTES_V2[1]], PI)          # porte N (vers la grotte)
	_porte_v2(ReliefVillage.PALISSADE[PORTES_V2[2]], PI * 0.5)    # porte E (vers les fermes)
	Chrono.marque("  village : palissade+portes")
	await _souffle()
	# les 5 intérieurs sans chargement, déplacés (mobilier inchangé : même repère local)
	var y0 := global_position.y
	var halle := _maison_monde(44.0, 21.0, 0.0, 14.0, 7.0, 2.2, 3.2, "halle")              # longue maison de la cheffe, porte au sud sur la place
	await _souffle()
	_maison_monde(59.5, 47.0, PI, 8.0, 5.5, 2.0, 2.4, "sigrun")                              # la voyante, porte au nord
	await _souffle()
	_maison_monde(63.0, 29.0, -PI * 0.5, 8.0, 5.5, 2.0, 2.4, "chasseurs")                   # famille de chasseurs, porte à l'ouest
	await _souffle()
	_maison_monde(28.0, 47.0, PI * 0.5, 7.0, 5.0, 1.9, 2.2, "grima")                         # la doyenne, porte à l'est sur la place
	Chrono.marque("  village : 4 maisons")
	await _souffle()
	var forge := _forge(_repere(27.0, 36.0, PI * 0.5, y0).origin, PI * 0.5 - rotation.y)   # forge ouverte à l'est sur la rue principale
	VillageBati.forge_ouverte(self, forge)
	Chrono.marque("  village : forge")
	await _souffle()
	var enclos := _enclos(_repere(66.5, 41.3, -PI * 0.5, y0).origin, -PI * 0.5 - rotation.y)  # enclos et séchoirs d'Ylva, ouverts à l'ouest
	# (puits, brasero de la place, tonneaux, caisses et tas de bois : lot C7a, scripts/mobilier_village.gd)
	await VillageBati.construire(self)
	Chrono.marque("  village : bâti v2 (façades, tour, moulins, fermes)")
	await _souffle()
	_finaliser()
	Chrono.marque("  village : maillages fusionnés")
	_lancer_fil()

	var postes := {
		"longue_maison": halle.to_global(Vector3(1.2, 0, 4.6)),     # devant la porte de la halle (même repère qu'avant)
		"forge": forge.to_global(Vector3(0.30, 0.0, 0.05)),          # repère de la forge : à genoux à 65 cm de l'enclume (local -0,35 ; 0,05)
		"puits": Vector3(44.6, y0, 39.6),
		"place": Vector3(39.5, y0, 42.0),
		"enclos": enclos.to_global(Vector3(-2.5, 0, 3.5)),
		"porte": to_global(Vector3(2.2, 0, RAYON - 2.4)),            # 2,4 m à l'intérieur de la porte SO (inchangé)
	}
	for nom in postes:
		lieux[nom] = postes[nom]
		if nom != "forge":
			promenade.append(lieux[nom])   # personne d'autre ne se promène dans la forge
	# promenade sur le plateau seulement (aucun point sur les escaliers ni hors de l'enceinte) : pont, quai, moulin, place
	for p: Vector2 in [Vector2(44, 55), Vector2(34, 57.6), Vector2(30, 57), Vector2(40, 33), Vector2(48.5, 40.5), Vector2(38, 44.5)]:
		promenade.append(Vector3(p.x, y0, p.y))
	bati = true
	bati_fini.emit()

## Chargement étalé (Monde._souffle) : rend une image entre deux étapes du bâti pour que l'écran de chargement reste animé.
## Hors chargement étalé (tests, outils), ne rend pas la main : _ready reste d'un seul bloc. Rien ne part dans un fil ici
## (matériaux, maillages et nœuds créés sur le fil principal, dans le même ordre : rendu identique).
func _souffle() -> void:
	if _monde != null and _monde.has_method("_souffle"):
		await _monde._souffle()

## Pose les objets « porte » (touche E) des bâtiments ; appelé par le monde quand joueur et dialogue existent.
func activer_interieurs(joueur: CharacterBody3D, dialogue: Control) -> void:
	for ip in interieurs:
		ip.activer(joueur, dialogue)

## Intérieur dont le nom d'id est `id` (« halle », « sigrun », « chasseurs », « grima », « forge »).
func interieur(id: String) -> Interieur:
	for ip in interieurs:
		if ip.nom == NOMS_BATIMENTS[id]:
			return ip
	return null

func _process(dt: float) -> void:
	_t += dt
	if ailes_moulin != null:
		ailes_moulin.rotation.z -= dt * 0.42   # ailes du moulin à vent : un tour toutes les ~15 s
	if _chauffe_images >= 0:
		if _chauffe_images == 0:
			_prechauffer()
		_chauffe_images += 1
		if _chauffe_images > 3 and _chauffe != null:
			_chauffe.queue_free()
			_chauffe = null
			_chauffe_images = -1
	if not prets and _fil >= 0:
		_poser_interieurs()
	# vitrages : s'allument la nuit (vus du dehors)
	var cyc = get_parent().get("cycle") if get_parent() != null else null
	if cyc != null and mats_int.has("vitre"):
		var n: float = 1.0 - cyc.clarte()
		if absf(n - _nuit_vitre) > 0.01:
			_nuit_vitre = n
			(mats_int["vitre"] as ShaderMaterial).set_shader_parameter("nuit", n)
			if not _sans_refonte:
				m_vitre_ext.set_shader_parameter("nuit", n)
				_regler_lueurs(n)
	if cyc != null and _mat_halo != null and _mat_fumee != null:
		var nh: float = 1.0 - cyc.clarte()
		if absf(nh - _nuit_halo) > 0.01:
			_nuit_halo = nh
			_mat_halo.albedo_color = Color(1.0, 0.6, 0.24) * lerpf(0.0, 1.0, smoothstep(0.1, 0.8, nh))
			_mat_fumee.albedo_color = Color.WHITE.lerp(Color(0.5, 0.52, 0.62), smoothstep(0.1, 0.9, nh))
	for f in _flammes:
		var l: OmniLight3D = f[0]
		var k: float = f[2]
		l.light_energy = f[1] * (0.9 + sin(_t * 9.0 + k) * 0.06 + sin(_t * 21.3 + k * 2.0) * 0.04 + randf() * 0.06)

# --- briques ---------------------------------------------------------------------

## Lots fusionnés (socle technique §1) : chaque pièce de bâtiment est ajoutée à un maillage unique par
## (pivot, matériau) au lieu d'un MeshInstance3D par pièce ; `_finaliser()` crée les maillages à la fin.
var _lots := {}   # "pivot|matériau" -> {"parent", "mat", "v", "n", "i"}
var _arrays_cache := {}

func _arrays_de(cle: String, fabrique: Callable) -> Array:
	if not _arrays_cache.has(cle):
		_arrays_cache[cle] = fabrique.call()
	return _arrays_cache[cle]

## Occlusion peinte au pied de tout ce qui touche le sol (y local 0 = sol du village) : le bas des murs, des
## poteaux et des pierres s'assombrit (éclaboussures, ombre de contact).
func _ao_pied(y: float) -> float:
	return 0.66 + 0.34 * smoothstep(0.0, 0.8, y)

func _ajouter(parent: Node3D, arrays: Array, xf: Transform3D, mat: Material, ao_sol := true) -> void:
	if arrays.size() <= Mesh.ARRAY_NORMAL or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_NORMAL] == null:
		return   # tableau vide ou incomplet : rien à ajouter (jamais d'erreur de type)
	var sombre := mat == m_colombage and m_colombage != null
	if sombre:
		mat = m_poutres_h
	var xf_lot := xf
	if parent.has_meta("fusion") and mat != m_brute:
		# pivot d'un groupe fusionné (sauf les moellons chanfreinés, gardés par bâtiment : voir _finaliser) : la pièce est exprimée dans le repère du groupe (l'occlusion au pied reste au pivot)
		var g: Node3D = parent.get_meta("fusion")
		xf_lot = g.transform.affine_inverse() * parent.transform * xf
		parent = g
	var cle := "%d|%d" % [parent.get_instance_id(), mat.get_instance_id()]
	if not _lots.has(cle):
		_lots[cle] = {"parent": parent, "mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var lot: Dictionary = _lots[cle]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	# les tableaux « Packed » sont des valeurs : on les sort du dictionnaire, on les remplit, on les range
	var v: PackedVector3Array = lot["v"]
	var n: PackedVector3Array = lot["n"]
	var uvs: PackedVector2Array = lot["u"]
	var cols: PackedColorArray = lot["c"]
	var uv_src: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var c_src: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var ii: PackedInt32Array = lot["i"]
	var base := v.size()
	var pivot_y := 0.0   # le pivot du bâtiment est posé au sol : y local = hauteur au-dessus du sol
	for k in verts.size():
		var pw := xf * verts[k]
		v.append(xf_lot * verts[k])
		n.append((xf_lot.basis * norms[k]).normalized())
		uvs.append(uv_src[k] if k < uv_src.size() else Vector2.ZERO)
		var c := c_src[k] if k < c_src.size() else Color.WHITE
		if sombre:
			c = Color(c.r * TEINTE_COLOMBAGE.r, c.g * TEINTE_COLOMBAGE.g, c.b * TEINTE_COLOMBAGE.b, c.a)
		if ao_sol:
			var g := _ao_pied(pw.y - pivot_y)
			c = Color(c.r * g, c.g * g, c.b * g, c.a)
		cols.append(c)
	if index.is_empty():
		for k in verts.size():
			ii.append(base + k)
	else:
		for k in index:
			ii.append(base + k)
	lot["v"] = v
	lot["n"] = n
	lot["u"] = uvs
	lot["c"] = cols
	lot["i"] = ii

func _finaliser() -> void:
	for cle in _lots:
		var lot: Dictionary = _lots[cle]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lot["v"]
		arrays[Mesh.ARRAY_NORMAL] = lot["n"]
		arrays[Mesh.ARRAY_TEX_UV] = lot["u"]
		arrays[Mesh.ARRAY_COLOR] = lot["c"]
		arrays[Mesh.ARRAY_INDEX] = lot["i"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = lot["mat"]
		if (lot["parent"] as Node3D).get_parent() is Interieur or lot["parent"] == _vitres:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # l'intérieur ne projette rien (coût de l'ombre du soleil)
		elif (lot["parent"] as Node3D).has_meta("fusion"):
			# bâti v2 (C7b) : moellons chanfreinés d'UN bâtiment (la moitié des triangles du bâti) : sans ombre propre (posés
			# sur des murs pleins qui la projettent), masqués au-delà de 70 m (les murs restent : brume, silhouette inchangée)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 70.0
		elif (lot["parent"] as Node3D).has_meta("groupe_v2") and lot["mat"] in [m_glace, m_fer]:
			# bâti v2 (C7b) : glaçons et ferrures plaqués sur des murs pleins
			# qui projettent déjà l'ombre → pas d'ombre propre (perf : passes d'ombre du soleil)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(lot["parent"] as Node3D).add_child(mi)
	_lots.clear()
	_arrays_cache.clear()

func _boite(parent: Node3D, taille: Vector3, xf: Transform3D, mat: Material, solide := false) -> void:
	var arrays := _arrays_de("boite%s" % taille, func() -> Array: return PrimGeo.boite(taille))
	_ajouter(parent, arrays, xf, mat)
	if solide:
		_collision(parent, BoxShape3D.new(), xf, taille)

func _cylindre(parent: Node3D, r_haut: float, r_bas: float, h: float, xf: Transform3D, mat: Material, cotes := 6, solide := false) -> void:
	var arrays := _arrays_de("cyl%f|%f|%f|%d" % [r_haut, r_bas, h, cotes], func() -> Array: return PrimGeo.cylindre(r_haut, r_bas, h, cotes))
	_ajouter(parent, arrays, xf, mat)
	if solide:
		var forme := CylinderShape3D.new()
		forme.radius = maxf(r_haut, r_bas)
		forme.height = h
		_collision(parent, forme, xf, Vector3.ZERO)

func _collision(parent: Node3D, forme: Shape3D, xf: Transform3D, taille: Vector3) -> void:
	if forme is BoxShape3D:
		forme.size = taille
	if not parent.is_inside_tree():
		_coll_fil.append([parent, forme, xf])   # construction hors de l'arbre (fil) : posée plus tard sur le fil principal
		return
	var cs := CollisionShape3D.new()
	cs.shape = forme
	corps.add_child(cs)
	# la forme est rangée sous le corps du village : on repasse en repère du village
	cs.transform = corps.global_transform.affine_inverse() * parent.global_transform * xf

# --- intérieurs : construction en fil, pose étalée ------------------------------------

func _differer(ib: Interieurs, travail: Callable) -> void:
	_jobs.append([ib, travail])

func _lancer_fil() -> void:
	if not _jobs.is_empty():
		_fil = WorkerThreadPool.add_task(_construire_interieurs)

## Fil de travail : un intérieur après l'autre. Ne touche ni à l'arbre ni aux nœuds du village (seulement aux lots, au cache de
## tableaux et à un `Interieur` temporaire jeté ensuite).
func _construire_interieurs() -> void:
	FilVerrou.prendre()
	for j in _jobs:
		var ib: Interieurs = j[0]
		var reel: Interieur = ib.ip
		var t := Interieur.new()
		t.nom = reel.nom
		t.demi = reel.demi
		t.sol_y = reel.sol_y
		t.porte_locale = reel.porte_locale
		ib.ip = t
		_coll_fil = []
		(j[1] as Callable).call()
		_finaliser()
		ib.ip = reel
		_mutex.lock()
		_faits.append([reel, t, _coll_fil])
		_mutex.unlock()
	FilVerrou.rendre()

func _poser_interieurs() -> void:
	var debut := Time.get_ticks_usec()
	while true:
		if _a_poser.is_empty():
			_mutex.lock()
			var f = _faits.pop_front() if not _faits.is_empty() else null
			_mutex.unlock()
			if f == null:
				break
			_planifier_pose(f[0], f[1], f[2])
		else:
			_a_poser.pop_front().call()
		if Time.get_ticks_usec() - debut > BUDGET_INT_US:
			break
	if Chrono.actif:
		print("CHRONO pose interieurs : %.2f ms (reste %d taches, %d faits, %d poses)" % [(Time.get_ticks_usec() - debut) / 1000.0, _a_poser.size(), _faits.size(), _nb_poses])
	if _nb_poses == _jobs.size() and _a_poser.is_empty():
		FilVerrou.attendre(_fil)
		_fil = -1
		prets = true
		interieurs_prets.emit()

## Découpe la pose d'un intérieur construit en fil : un enfant du contenu par tâche, collisions par paquets de 24.
func _planifier_pose(reel: Interieur, t: Interieur, colls: Array) -> void:
	for c in t.racine.get_children():
		_a_poser.append(func() -> void:
			t.racine.remove_child(c)
			reel.racine.add_child(c))
	_a_poser.append(func() -> void:
		for l in t.lumieres:
			(l[0] as OmniLight3D).visible = reel._allume
		reel.lumieres.append_array(t.lumieres))
	for i in range(0, colls.size(), 24):
		var paquet := colls.slice(i, i + 24)
		_a_poser.append(func() -> void:
			for c in paquet:
				var parent: Node3D = reel.racine if c[0] == t.racine else c[0]
				var cs := CollisionShape3D.new()
				cs.shape = c[1]
				corps.add_child(cs)
				cs.transform = corps.global_transform.affine_inverse() * parent.global_transform * (c[2] as Transform3D))
	_a_poser.append(func() -> void:
		t.free()
		_nb_poses += 1)

## Préchauffage des shaders d'intérieur (ps1_interieur, ps1_vitre, flammes, halos additifs) : un triangle minuscule par shader,
## posé 3 images devant la caméra du joueur, pendant la toute première image (déjà longue : compilation du reste de la scène).
## Sans lui, la compilation tombait à la 1re vue d'un intérieur ou 0,5 s après le départ (3 images de 35 à 60 ms).
## Mêmes formats de sommets, mêmes réglages de matière que le vrai contenu (`Interieurs.finir`, `_finaliser`) : mêmes pipelines.
var _chauffe: Node3D
var _chauffe_images := 0

func _prechauffer() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_chauffe = Node3D.new()
	_chauffe.position = Vector3(0, 0, -0.5)
	var tri := PackedVector3Array([Vector3(-0.004, -0.004, 0), Vector3(0.004, -0.004, 0), Vector3(0, 0.004, 0)])
	var nor := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0)])
	var col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tri
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var vus := {}
	var mats: Array = []
	for k in mats_int:
		var m: ShaderMaterial = mats_int[k]
		if not vus.has(m.shader):
			vus[m.shader] = true
			mats.append(m)
	var s := StandardMaterial3D.new()    # halos et rais additifs (réglages de Interieurs.finir)
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.vertex_color_use_as_albedo = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.disable_receive_shadows = true
	mats.append(s)
	for m in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chauffe.add_child(mi)
	var fm := MultiMesh.new()    # flammes : plan + données d'instance
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_custom_data = true
	fm.mesh = PrimGeo.maillage(PrimGeo.plan(Vector2(1, 1), Vector3(0, 0.5, 0)))
	fm.instance_count = 1
	fm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(0.01, 0.01, 0.01)), Vector3.ZERO))
	var fs := ShaderMaterial.new()
	fs.shader = Interieurs.FLAMME_SHADER
	var fi := MultiMeshInstance3D.new()
	fi.multimesh = fm
	fi.material_override = fs
	fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chauffe.add_child(fi)
	cam.add_child(_chauffe)

func _exit_tree() -> void:
	if _fil >= 0:
		FilVerrou.attendre(_fil)
		_fil = -1

func _pivot(position_: Vector3, lacet: float) -> Node3D:
	var n := Node3D.new()
	n.position = position_
	n.rotation.y = lacet
	add_child(n)
	return n

# --- village v2 : repères monde, groupes fusionnés, emprises ---------------------------------------------------

## Hauteur du sol EXACT (maillage du terrain) en (x, z) monde.
func h_sol(x: float, z: float) -> float:
	if _monde != null and _monde.has_method("hauteur") and "TAILLE" in _monde:
		return DetailsSol.hauteur_maillage(_monde, x, z)
	return global_position.y

## Repère LOCAL (au village) d'un objet posé en (x, y, z) monde, tourné de `lacet` (monde ; 0 = +Z local vers le sud).
func _repere(x: float, z: float, lacet: float, y := NAN) -> Transform3D:
	var yy := h_sol(x, z) if is_nan(y) else y
	return global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP, lacet), Vector3(x, yy, z))

## Pivot d'un bâtiment en coordonnées monde. Avec `fusion`, ses pièces rejoignent les lots du groupe (un maillage par
## matière pour tout le groupe : quelques appels de dessin pour 6 façades) ; collisions, fumées et vitrages restent à lui.
func pivot_monde(x: float, z: float, lacet: float, y := NAN, fusion: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.transform = _repere(x, z, lacet, y)
	add_child(n)
	if fusion != null:
		n.set_meta("fusion", fusion)
	return n

func groupe_fusion(nom: String) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	g.set_meta("groupe_v2", true)
	add_child(g)
	return g

## Emprise au sol d'un bâtiment (repère du pivot) : sert au replacement sûr au chargement.
func _emprise(p: Node3D, demi: Vector2, decalage := Vector2.ZERO, ip: Interieur = null) -> void:
	emprises.append([p, demi, decalage, ip])

## Vrai si (x, z) monde est libre : ni dans l'eau, ni dans un bâtiment (marge `m`), ni sur la palissade.
func point_libre(x: float, z: float, m := 0.5) -> bool:
	if not is_nan(ReliefVillage.niveau_eau(x, z)):
		return false
	if absf(ReliefVillage.distance_palissade(x, z)) < m + 0.3:
		return false
	for e in emprises:
		var l: Vector3 = (e[0] as Node3D).global_transform.affine_inverse() * Vector3(x, (e[0] as Node3D).global_position.y, z)
		var d: Vector2 = e[1]
		var c: Vector2 = e[2]
		if absf(l.x - c.x) < d.x + m and absf(l.z - c.y) < d.y + m:
			return false
	return true

## Replacement sûr au chargement d'une sauvegarde (les joueurs ont pu sauver dans l'ancien village) : une position dans un
## bâtiment (hors de la pièce d'un intérieur), dans l'eau, sur la palissade ou sous le sol est ramenée au point libre le plus
## proche (spirale de 0,5 m), posée sur le sol. Sous terre (crypte, grotte) et loin du village : inchangée.
func position_sure(p: Vector3) -> Vector3:
	if p.y < -100.0 or not ReliefVillage.BOITE.grow(10.0).has_point(Vector2(p.x, p.z)):
		return p
	for e in emprises:
		var ip: Interieur = e[3]
		if ip != null and ip.dedans(ip.to_local(p), -0.3):
			var l := ip.to_local(p)
			return ip.to_global(Vector3(l.x, ip.sol_y + 0.1, l.z))   # dans la pièce d'un intérieur : on y reste, sur le plancher
	var h := h_sol(p.x, p.z)
	if point_libre(p.x, p.z):
		return Vector3(p.x, maxf(p.y, h + 0.1), p.z)
	for r in range(1, 80):
		var rr := r * 0.5
		var n := maxi(8, int(TAU * rr / 0.5))
		for k in n:
			var a := TAU * k / n
			var x := p.x + cos(a) * rr
			var z := p.z + sin(a) * rr
			if point_libre(x, z, 0.7):
				return Vector3(x, h_sol(x, z) + 0.15, z)
	return Vector3(p.x, h + 0.15, p.z)

func _feu(parent: Node3D, position_: Vector3, taille: float, energie: float, portee: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.22)
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.3
	l.position = position_ + Vector3(0, 0.25, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	parent.add_child(l)
	_flammes.append([l, energie, rng.randf() * 10.0])
	var p := GPUParticles3D.new()
	p.amount = int(18 * taille) + 8
	p.lifetime = 0.5 + taille * 0.3
	p.position = position_
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * taille
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5 * taille
	pm.initial_velocity_max = 0.9 * taille
	pm.gravity = Vector3(0, 0.6, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	g.colors = PackedColorArray([Color(3.0, 2.3, 0.9), Color(2.6, 1.0, 0.25), Color(1.2, 0.25, 0.05), Color(0.3, 0.05, 0.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09) * taille
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	parent.add_child(p)

## Fumée de cheminée (passe 4) : petites bouffées en pixels (texture 10 × 10 à bord en paliers, filtrage nearest, aucun flou),
## lentes et légères, qui grossissent peu, chauffées de rouge près de la bouche et grisées en montant, poussées par un vent doux.
func _fumee(parent: Node3D, position_: Vector3) -> void:
	if not _sans_refonte:
		_fumee_pixels(parent, position_)
		return
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.position = position_
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.14
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.12, 0.03, 0.05)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.55))
	courbe.add_point(Vector2(1, 2.4))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.95, 0.62, 0.4, 0.0), Color(0.9, 0.62, 0.48, 0.8), Color(0.66, 0.7, 0.8, 0.7), Color(0.55, 0.6, 0.72, 0.38), Color(0.45, 0.5, 0.62, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.26)
	if _mat_fumee == null:
		_mat_fumee = StandardMaterial3D.new()
		_mat_fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_fumee.vertex_color_use_as_albedo = true
		_mat_fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fumee.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat_fumee.albedo_texture = _texture_bouffee()
		_mat_fumee.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat_fumee.disable_receive_shadows = true
	q.material = _mat_fumee
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)

## Bouffée de fumée 16 × 16 en pixels (filtrage au plus proche) : disque bosselé, alpha en 3 paliers (pas de dégradé
## lisse, pas de tramage en damier : les bords sont découpés par un bruit fixe). Partagée par toutes les cheminées.
static var _tex_bouffee: ImageTexture
static func _bouffee() -> ImageTexture:
	if _tex_bouffee != null:
		return _tex_bouffee
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 7707
	var bosses: Array = []
	for k in 5:
		bosses.append([Vector2(r.randf_range(4.5, 11.5), r.randf_range(4.5, 11.5)), r.randf_range(3.0, 5.0)])
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := 0.0
			for b in bosses:
				d = maxf(d, 1.0 - p.distance_to(b[0]) / float(b[1]))
			d += (r.randf() - 0.5) * 0.18
			var a := 0.0
			if d > 0.55:
				a = 1.0
			elif d > 0.3:
				a = 0.66
			elif d > 0.1:
				a = 0.33
			var l := 0.86 + 0.14 * clampf(1.0 - (y - 4.0) / 10.0, 0.0, 1.0)   # dessous un peu plus sombre
			img.set_pixel(x, y, Color(l, l, l * 1.02, a))
	_tex_bouffee = ImageTexture.create_from_image(img)
	return _tex_bouffee

## Fumée de cheminée légère (refonte bâti) : 22 bouffées en pixels qui montent, grossissent et dérivent avec le vent ;
## teinte réglée par l'heure (`_regler_lueurs`). Coût : une GPUParticles3D par cheminée (5 au village).
func _fumee_pixels(parent: Node3D, position_: Vector3, force := 1.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(26 * force)
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = position_
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(22, 20, 22))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.55
	pm.initial_velocity_max = 0.8
	pm.damping_min = 0.02
	pm.damping_max = 0.05
	pm.gravity = Vector3(0.22, 0.06, 0.09)   # panache qui monte haut puis se couche dans le vent
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.8
	pm.scale_max = 1.25
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.35))
	courbe.add_point(Vector2(0.4, 1.6))
	courbe.add_point(Vector2(1, 3.4))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.06, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.albedo_texture = _bouffee()
	mq.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mq.albedo_color = Color(0.6, 0.62, 0.7)
	q.material = mq
	_fumees.append(mq)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
## Bouffée de fumée en pixels : disque irrégulier de 10 × 10, alpha en trois paliers (cœur, bord, frange), blanc.
static func _texture_bouffee() -> ImageTexture:
	var n := 10
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for y in n:
		for x in n:
			var d := Vector2(x - (n - 1) * 0.5, y - (n - 1) * 0.5).length() / (n * 0.5) + (r.randf() - 0.5) * 0.28
			var a := 1.0 if d < 0.45 else (0.55 if d < 0.7 else (0.22 if d < 0.92 else 0.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Pignon triangulaire plein (visible des deux côtés), dans le plan YZ.
func _pignon(parent: Node3D, x: float, y0: float, demi_largeur: float, hauteur_: float) -> void:
	var a := Vector3(x, y0, -demi_largeur)
	var b := Vector3(x, y0, demi_largeur)
	var c := Vector3(x, y0 + hauteur_, 0)
	var v := PackedVector3Array([a, b, c, b, a, c])
	var n := PackedVector3Array()
	var n1 := (b - a).cross(c - a).normalized()
	for k in 3:
		n.append(n1)
	for k in 3:
		n.append(-n1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	_ajouter(parent, arrays, Transform3D(), m_poutres)

# --- bâtiments ---------------------------------------------------------------------
# Lot 5. Structure modulaire (grille de 2 m : contreforts, bouts de solives, poteaux) ; textures en mètres
# (TexturesBati) : la même densité de pixels sur la pierre, le bois et la neige.

## Pile de moellons : `taille` (x, y, z) en rangs de ~34 cm de moellons de 40 à 75 cm aux joints décalés (même approche que
## `Interieurs.pile` : pierres plus petites, chanfrein et gauchissement réduits ; la matière est projetée en MÈTRES par le
## shader, donc aucune texture n'est étirée) ; collision = une boîte.
func _pile(parent: Node3D, pos: Vector3, taille: Vector3, graine: int, mat: Material, solide := false, neige_haut := 0.5, lacet := 0.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var rangs := maxi(1, roundi(taille.y / 0.34))
	var hh := taille.y / rangs
	var basis := Basis(Vector3.UP, lacet)
	for k in rangs:
		var x := -taille.x * 0.5 - r.randf_range(0.0, 0.3)
		while x < taille.x * 0.5:
			var w := r.randf_range(0.4, 0.75)
			var x0 := maxf(x, -taille.x * 0.5)
			var x1 := minf(x + w, taille.x * 0.5)
			x += w * 0.98
			if x1 - x0 < 0.16:
				continue
			var c := Vector3((x0 + x1) * 0.5, -taille.y * 0.5 + hh * (k + 0.5), r.randf_range(-0.025, 0.025))
			_ajouter(parent, BatiGeo.bloc(Vector3(x1 - x0, hh * 1.03, taille.z), r.randi(), 0.13, 0.045, neige_haut if k == rangs - 1 else 0.0, 0.66).arrays(), Transform3D(basis, pos + basis * c), mat)
	if solide:
		_collision(parent, BoxShape3D.new(), Transform3D(basis, pos), taille)

## Corps du poteau : cylindre à 8 pans (pas de cube ni de colonne ronde lisse).
func _poteau(parent: Node3D, pos: Vector3, rayon: float, h: float, mat: Material, solide := false) -> void:
	_cylindre(parent, rayon, rayon, h, Transform3D(Basis(), pos + Vector3(0, h * 0.5, 0)), mat, 8, solide)

## Torche murale : console de fer, manche, flamme ÉMISSIVE (pas de lumière : budget du socle technique §2) ;
## `reelle` = vraie OmniLight (une seule dans le village : la lanterne de la longue maison).
func _torche_murale(parent: Node3D, pos: Vector3, vers: float, reelle := false) -> void:
	# `vers` = +1 (mur vers +Z) ou -1 : sens de la saillie
	_boite(parent, Vector3(0.07, 0.07, 0.3), Transform3D(Basis(), pos + Vector3(0, -0.15, 0.13 * vers)), m_fer)
	_boite(parent, Vector3(0.07, 0.5, 0.07), Transform3D(Basis(Vector3.RIGHT, 0.25 * vers), pos + Vector3(0, 0.05, 0.28 * vers)), m_poutres)
	var haut := pos + Vector3(0, 0.38, 0.34 * vers)
	_boite(parent, Vector3(0.14, 0.2, 0.14), Transform3D(Basis(Vector3.UP, 0.4), haut), m_braises)
	_boite(parent, Vector3(0.08, 0.14, 0.08), Transform3D(Basis(Vector3.UP, 0.2), haut + Vector3(0, 0.15, 0)), m_braises)
	Torche.flamme_fixe(parent, haut + Vector3(0, 0.2, 0), 1.3, absf(sin(pos.x * 12.9898 + pos.z * 78.233)) * 4.0)   # même flamme que partout (lot 6bis)
	if reelle:
		_feu(parent, haut, 0.6, 1.4, 7.0)

## Stalactites de glace sous un égout : pyramides pendantes, une par ~35 cm.
func _stalactites(parent: Node3D, x0: float, x1: float, y: float, z: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := x0
	if _sans_refonte:
		while x < x1:
			var l := r.randf_range(0.1, 0.32)
			var w := r.randf_range(0.04, 0.06)
			var h := Vector3(x, y, z)
			var c := [h + Vector3(-w, 0, -w), h + Vector3(w, 0, -w), h + Vector3(w, 0, w), h + Vector3(-w, 0, w)]
			var pointe := h + Vector3(0, -l, 0)
			for i in 4:
				st.add_vertex(c[i])
				st.add_vertex(c[(i + 1) % 4])
				st.add_vertex(pointe)
			x += r.randf_range(0.28, 0.5)
	else:
		# refonte bâti : glaçons fins en grappes (quelques longs, beaucoup de courts), trous entre les grappes
		while x < x1:
			if r.randf() < 0.3:
				x += r.randf_range(0.4, 1.1)   # pas de glace sous ce bout d'égout
				continue
			var l := r.randf_range(0.06, 0.2) if r.randf() < 0.7 else r.randf_range(0.25, 0.55)
			var w := r.randf_range(0.02, 0.035) + l * 0.05
			var h := Vector3(x, y + r.randf_range(-0.03, 0.03), z + r.randf_range(-0.04, 0.04))
			var c := [h + Vector3(-w, 0, -w * 0.6), h + Vector3(w, 0, -w * 0.6), h + Vector3(0, 0, w)]
			var milieu := h + Vector3(r.randf_range(-0.01, 0.01), -l * 0.45, 0)
			var cm := [milieu + Vector3(-w * 0.45, 0, -w * 0.3), milieu + Vector3(w * 0.45, 0, -w * 0.3), milieu + Vector3(0, 0, w * 0.5)]
			var pointe := h + Vector3(r.randf_range(-0.015, 0.015), -l, 0)
			for i in 3:
				var i2 := (i + 1) % 3
				for v in [c[i], c[i2], cm[i2], c[i], cm[i2], cm[i], cm[i], cm[i2], pointe]:
					st.add_vertex(v)
			x += r.randf_range(0.07, 0.22)
	st.generate_normals()
	_ajouter(parent, st.commit_to_arrays(), Transform3D(), m_glace)

## Bloc de pierre irrégulier (chanfreiné, facettes plates) ajouté au lot (parent, matière).
func _bloc(parent: Node3D, taille: Vector3, graine: int, pos: Vector3, mat: Material, lacet := 0.0, neige := 0.0, chanfrein := 0.22, jitter := 0.07, solide := false) -> void:
	_ajouter(parent, BatiGeo.bloc(taille, graine, chanfrein, jitter, neige).arrays(), Transform3D(Basis(Vector3.UP, lacet), pos), mat)
	if solide:
		_collision(parent, BoxShape3D.new(), Transform3D(Basis(Vector3.UP, lacet), pos), taille)

## Rondin à 8 pans : fût (matière rondins) + deux bouts (matière bout_rondin). `lacet` PI/2 = le long de Z.
## Si `interieur` est donné (rondin d'un mur de maison), le fût est coupé en deux : la moitié tournée vers `dehors`
## (+1 ou -1 selon Z local du rondin) reste à l'extérieur, l'autre (vue de la pièce) rejoint l'intérieur et prend la
## matière « intérieur » (pas de lumière ambiante du ciel dans la pièce).
func _rondin(parent: Node3D, pos: Vector3, lacet: float, longueur: float, rayon: float, graine: int, teinte := 1.0, sag := 0.02, interieur: Interieur = null, dehors := 1.0) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = graine
	var r := BatiGeo.rondin(longueur, rayon, graine, sag, rr.randi_range(0, 3), rr.randf() * 8.0, teinte)
	var xf := Transform3D(Basis(Vector3.UP, lacet), pos)
	if interieur == null:
		_ajouter(parent, (r[0] as BatiGeo.Maillage).arrays(), xf, m_rondins)
	else:
		var fut: BatiGeo.Maillage = r[0]
		var ext := BatiGeo.Maillage.new()
		var dedans := BatiGeo.Maillage.new()
		for i in range(0, fut.v.size(), 3):
			var cible := ext if fut.n[i].z * dehors > -0.3 else dedans
			for k in 3:
				cible.v.append(fut.v[i + k])
				cible.n.append(fut.n[i + k])
				cible.uv.append(fut.uv[i + k])
				cible.c.append(fut.c[i + k])
		_ajouter(parent, ext.arrays(), xf, m_rondins)
		_ajouter(interieur.racine, dedans.arrays(), xf, mats_int["rondin"])
	_ajouter(parent, (r[1] as BatiGeo.Maillage).arrays(), xf, m_bout)

## Soubassement : remplissage en retrait + pierres brutes en saillie irrégulière (5 à 15 cm), dessus à ~0,4 m.
func _soubassement(p: Node3D, L: float, W: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	_boite(p, Vector3(L + 0.42, 0.75, W + 0.42), Transform3D(Basis(), Vector3(0, 0.025, 0)), m_soubassement)
	for cote in 4:
		var horiz := cote < 2
		var sgn := -1.0 if cote % 2 == 0 else 1.0
		var long_ := (L if horiz else W) + 0.5
		var demi := (W if horiz else L) * 0.5
		var t := -long_ * 0.5
		while t < long_ * 0.5:
			var lg := r.randf_range(0.55, 1.05)
			var hh := r.randf_range(0.55, 0.72)
			var prof := r.randf_range(0.36, 0.52)
			var saillie := r.randf_range(0.02, 0.15)
			var haut := r.randf_range(0.38, 0.5)
			var a := t + lg * 0.5
			t += lg * 0.96
			if horiz and sgn > 0.0 and absf(a) < 1.45:
				continue   # les marches de la porte
			var ext := demi + 0.15 + saillie - prof * 0.5 + 0.05
			var pos := Vector3(a, haut - hh * 0.5, sgn * ext) if horiz else Vector3(sgn * ext, haut - hh * 0.5, a)
			var taille := Vector3(lg, hh, prof) if horiz else Vector3(prof, hh, lg)
			_bloc(p, taille, r.randi(), pos, m_brute_soub, 0.0, 0.22, 0.2, 0.08)

## Hauteur d'une rangée de rondins (lit k) et rangées traversées par les fenêtres.
const LITS_FENETRE := [4, 5]
func _y_lit(k: int, h_murs: float) -> float:
	var nk := roundi((h_murs - 0.30) / 0.25) + 1
	return 0.4 + 0.15 + k * (h_murs - 0.30) / (nk - 1)

## Intervalles [a, b] d'une rangée de longueur [-xl, xl] une fois ôtées les ouvertures `coupes` ([x0, x1]).
func _segments(xl: float, coupes: Array) -> Array:
	var segs := []
	var x := -xl
	var tri := coupes.duplicate()
	tri.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in tri:
		if c[0] > x + 0.05:
			segs.append([x, c[0]])
		x = maxf(x, c[1])
	if xl > x + 0.05:
		segs.append([x, xl])
	return segs

## Murs en rondins de 30 cm à 8 pans, empilés tous les 25 cm, croisés aux angles (bouts qui dépassent de 28 cm,
## alternés d'un lit à l'autre) ; ouverture de la porte (1,2 × 2 m) dans le long pan +Z, fenêtres de 0,7 × 0,55 m
## (lits 4 et 5) aux abscisses `fenetres` des deux longs pans. Chaque rondin est coupé aux ouvertures ; sa moitié
## visible de la pièce passe dans `ip` (matière d'intérieur).
func _murs_rondins(p: Node3D, ip: Interieur, L: float, W: float, h_murs: float, graine: int, fenetres: Array, demi_porte := 0.62) -> int:
	var nk := roundi((h_murs - 0.30) / 0.25) + 1
	for k in nk:
		var y := _y_lit(k, h_murs)
		var long_deborde := k % 2 == 0
		var xl := L * 0.5 + (0.15 + 0.28 if long_deborde else 0.0)
		var zl := W * 0.5 + (0.0 if long_deborde else 0.15 + 0.28)
		# sous les rives : le haut des murs est dans l'ombre du toit, le pied est sali
		var teinte := 1.0 - 0.2 * smoothstep(nk - 4.0, nk - 1.0, k)
		var g := graine * 100 + k * 8
		var fen: Array = []
		if k in LITS_FENETRE:
			for x in fenetres:
				fen.append([x - 0.35, x + 0.35])
		for cote in [-1.0, 1.0]:
			var coupes := fen.duplicate()
			if cote > 0.0 and k <= nk - 2:
				coupes.append([-demi_porte, demi_porte])
			var n := 0
			for seg in _segments(xl, coupes):
				_rondin(p, Vector3((seg[0] + seg[1]) * 0.5, y, cote * W * 0.5), 0.0, seg[1] - seg[0], 0.15, g + 1 + n * 3 + int(cote + 1.0) * 11, teinte, 0.02, ip, cote)
				n += 1
			_rondin(p, Vector3(cote * L * 0.5, y, 0), PI * 0.5, zl * 2.0, 0.15, g + 5 + int(cote), teinte, 0.02, ip, cote)
	return nk

## Âme du mur (fond sombre vu dans les joints entre rondins) : quatre cloisons de 20 cm au plan des murs, percées de
## la porte et des fenêtres (le mur n'est plus un bloc plein : la pièce est creuse).
func _ame(p: Node3D, L: float, W: float, h_murs: float, fenetres: Array, demi_porte := 0.62) -> void:
	var y_haut := 0.4 + h_murs
	var fy0 := _y_lit(LITS_FENETRE[0], h_murs) - 0.15
	var fy1 := _y_lit(LITS_FENETRE[1], h_murs) + 0.15
	for cote in [-1.0, 1.0]:
		var coupes: Array = []
		for x in fenetres:
			coupes.append([x - 0.35, x + 0.35, fy0, fy1])
		if cote > 0.0:
			coupes.append([-demi_porte, demi_porte, 0.4, 0.4 + 2.0])
		var bords := [-L * 0.5, L * 0.5]
		for c in coupes:
			bords.append(c[0])
			bords.append(c[1])
		bords.sort()
		for i in bords.size() - 1:
			var xa: float = bords[i]
			var xb: float = bords[i + 1]
			if xb - xa < 0.01:
				continue
			var xm := (xa + xb) * 0.5
			var morceaux := [[0.4, y_haut]]
			for c in coupes:
				if xm > c[0] and xm < c[1]:
					morceaux = []
					if c[2] > 0.41:
						morceaux.append([0.4, c[2]])
					morceaux.append([c[3], y_haut])
			for mo in morceaux:
				_boite(p, Vector3(xb - xa, mo[1] - mo[0], 0.2), Transform3D(Basis(), Vector3(xm, (mo[0] + mo[1]) * 0.5, cote * W * 0.5)), m_ame)
	for cote in [-1.0, 1.0]:
		_boite(p, Vector3(0.2, h_murs, W), Transform3D(Basis(), Vector3(cote * L * 0.5, 0.4 + h_murs * 0.5, 0)), m_ame)

## Fenêtre encadrée de 0,7 × 0,55 m (linteau, appui en saillie, jambages), vitrage TRANSLUCIDE (plan `ps1_vitre`) et
## volet entrouvert ; `face` = +1 (côté +Z) ou -1. Le cadre côté pièce est posé par `Interieurs.fenetre_cadre`.
func _fenetre_cadre(p: Node3D, x: float, y: float, z: float, face: float) -> void:
	_vitre(p, Vector3(x, y, z - 0.17 * face), Vector2(0.7, 0.55), 0.0 if face > 0.0 else PI)
	_boite(p, Vector3(0.92, 0.1, 0.16), Transform3D(Basis(), Vector3(x, y + 0.325, z + 0.05 * face)), m_poutres_h)
	_boite(p, Vector3(0.96, 0.08, 0.26), Transform3D(Basis(Vector3.RIGHT, 0.12 * face), Vector3(x, y - 0.33, z + 0.09 * face)), m_poutres_h)
	for fx in [-0.4, 0.4]:
		_boite(p, Vector3(0.1, 0.62, 0.15), Transform3D(Basis(), Vector3(x + fx, y, z + 0.045 * face)), m_poutres_h)
	# volet entrouvert
	_boite(p, Vector3(0.34, 0.56, 0.04), Transform3D(Basis(Vector3.UP, 1.1 * face * signf(x + 0.001)), Vector3(x + 0.62 * signf(x + 0.001), y, z + 0.18 * face)), m_poutres)

## Un pan de toit : planches dessous, chevrons qui dépassent, dalle de neige à épaisseur (BatiGeo.dalle_neige),
## rives croisées en cornes. `Rp` = point du faîte, `d` = vecteur faîte → égout (x nul). Renvoie le repère du pan.
## `trou` = (x0, x1) : trou à fumée au faîte (premier rang de la dalle, planches et chevrons coupés).
func _pan(p: Node3D, Rp: Vector3, d: Vector3, Lx: float, graine: int, L_murs: float, cornes := true, trou := Vector2.ZERO, epaisse := false) -> Transform3D:
	var Sl := d.length()
	var t := d / Sl
	var nrm := Vector3(0, t.z, -t.y)
	if nrm.y < 0.0:
		nrm = -nrm
	var bx := Vector3.RIGHT * (1.0 if d.z > 0.0 else -1.0)
	var xf := Transform3D(Basis(bx, nrm, t), Rp)
	var sh := Sl / 5.0     # profondeur du trou : un rang de la dalle
	if trou == Vector2.ZERO:
		_boite(p, Vector3(Lx - 0.1, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3(0, -0.05, Sl * 0.5)), m_poutres_h)
	else:
		var xa := -Lx * 0.5 + 0.05
		var xb := Lx * 0.5 - 0.05
		_boite(p, Vector3(trou.x - xa, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3((xa + trou.x) * 0.5, -0.05, Sl * 0.5)), m_poutres_h)
		_boite(p, Vector3(xb - trou.y, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3((trou.y + xb) * 0.5, -0.05, Sl * 0.5)), m_poutres_h)
		var lm := Sl + 0.06 - sh
		_boite(p, Vector3(trou.y - trou.x, 0.09, lm), xf * Transform3D(Basis(), Vector3((trou.x + trou.y) * 0.5, -0.05, sh + lm * 0.5)), m_poutres_h)
	var x := -Lx * 0.5 + 0.2
	while x <= Lx * 0.5 - 0.15:
		var dans := trou != Vector2.ZERO and x > trou.x - 0.06 and x < trou.y + 0.06
		var l_ch := Sl + 0.3 - (sh if dans else 0.0)
		var s_c := Sl * 0.5 + 0.04 + (sh * 0.5 if dans else 0.0)
		_boite(p, Vector3(0.11, 0.17, l_ch), xf * Transform3D(Basis(), Vector3(x, -0.15, s_c)), m_poutres_h)
		x += 0.9
	if epaisse and not _sans_refonte:
		# refonte bâti : neige ÉPAISSE qui déborde de l'égout et des rives (image de référence)
		_ajouter(p, BatiGeo.dalle_neige_epaisse(Lx, Sl, graine, EPAISSEUR_NEIGE, 0.26, 0.2, trou).surface_get_arrays(0), xf, m_toit)
	else:
		_ajouter(p, BatiGeo.dalle_neige(Lx, Sl, graine, 0.22, 0.05, trou).surface_get_arrays(0), xf, m_toit)
		# congères d'abords : seulement sur l'ancien bâti (la neige épaisse de la refonte les remplace)
		if avec_habillage:
			_neige_toit(p, xf, Lx, Sl, graine, trou)
	if cornes:
		for bout in [-1.0, 1.0]:
			var rive := Transform3D(Basis(bx, nrm, t), Rp + bx * (bout * (Lx * 0.5 - 0.1)) + nrm * 0.02)
			if epaisse and not _sans_refonte:
				# planche de rive plus haute, sombre, sous le rouleau de neige
				_boite(p, Vector3(0.15, 0.4, Sl + 0.2), rive * Transform3D(Basis(), Vector3(0, -0.08, Sl * 0.5 + 0.02)), m_colombage)
			else:
				_boite(p, Vector3(0.14, 0.3, Sl + 0.5), rive * Transform3D(Basis(), Vector3(0, -0.02, Sl * 0.5 - 0.15)), m_poutres_h)
	return xf

## Passe 4 : neige qui tient sur un pan : congères en gros boudins posés sur la pente (volume, silhouette au faîte) et
## bourrelet qui déborde à l'égout par tronçons irréguliers. Générateur local : aucun tirage partagé.
func _neige_toit(p: Node3D, xf: Transform3D, Lx: float, Sl: float, graine: int, trou: Vector2) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine * 131 + 17
	var k := 0
	for i in int(Lx / 1.6) + 2:
		var x := r.randf_range(-Lx * 0.5 + 0.8, Lx * 0.5 - 0.8)
		if trou != Vector2.ZERO and x > trou.x - 0.7 and x < trou.y + 0.7:
			continue
		var ts := r.randf_range(0.28, 0.9)
		var lon := r.randf_range(0.7, 1.5)
		var ray := r.randf_range(0.1, 0.17)
		var roul := BatiGeo.rondin(lon, ray, graine * 17 + k, 0.03, 0, 0.0, 1.0)
		var b := Basis(Vector3.UP, r.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, r.randf_range(-0.2, 0.2))
		_ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), xf * Transform3D(b, Vector3(x, 0.19 + 0.06 * ts, Sl * ts)), m_neige)
		k += 1
	var x := -Lx * 0.5 + 0.3
	while x < Lx * 0.5 - 0.5:
		var lon := r.randf_range(0.8, 2.2)
		lon = minf(lon, Lx * 0.5 - 0.3 - x)
		if lon > 0.4:
			var roul := BatiGeo.rondin(lon, r.randf_range(0.13, 0.2), graine * 19 + k, 0.04, 0, 0.0, 1.0)
			_ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), xf * Transform3D(Basis(), Vector3(x + lon * 0.5, 0.1, Sl + 0.03)), m_neige)
			k += 1
		x += lon + r.randf_range(0.3, 1.2)

## Toit en deux pans (lot 5, 2e passe) : chevrons qui dépassent, planches dessous, dalle de neige à épaisseur et à
## bord irrégulier (tourbe sombre à la lèvre), faîtière en rondin dont les bouts sortent des pignons et rouleau
## de neige au faîte ; rives croisées en cornes. `trou` : trou à fumée (voir `_pan`) ; la faîtière et le rouleau
## s'interrompent de part et d'autre.
func _toit(p: Node3D, L: float, W: float, y0: float, faite: float, graine: int, trou := Vector2.ZERO, releve := 0.5) -> Vector2:
	var avancee := 0.78
	var Rp := Vector3(0, y0 + faite, 0)
	var eave_z := W * 0.5 + avancee
	var Lx := L + 1.5
	var bas_y := y0 - releve
	var epaisse := not _sans_refonte
	for cote in [-1.0, 1.0]:
		var xf := _pan(p, Rp, Vector3(0, bas_y - Rp.y, cote * eave_z), Lx, graine * 7 + int(cote) + 3, L, true, trou, epaisse)
		if epaisse:
			# glaçons sous le rouleau de neige débordant (et non plus sous la planche d'égout)
			var Sl := Vector2(bas_y - Rp.y, eave_z).length()
			var bord := xf * Vector3(0, -0.02, Sl + 0.16)
			_stalactites(p, -L * 0.5 - 0.4, L * 0.5 + 0.4, bord.y, bord.z, graine * 31 + int(cote))
		else:
			_stalactites(p, -L * 0.5 - 0.5, L * 0.5 + 0.5, bas_y - 0.12, cote * (eave_z + 0.06), graine * 31 + int(cote))
	# faîtière : rondin qui dépasse des pignons + rouleau de neige
	var morceaux: Array = [[-(L + 2.1) * 0.5, (L + 2.1) * 0.5]]
	var rouleaux: Array = [[-(L + 1.5) * 0.5, (L + 1.5) * 0.5]]
	if trou != Vector2.ZERO:
		morceaux = [[-(L + 2.1) * 0.5, trou.x - 0.05], [trou.y + 0.05, (L + 2.1) * 0.5]]
		rouleaux = [[-(L + 1.5) * 0.5, trou.x - 0.1], [trou.y + 0.1, (L + 1.5) * 0.5]]
	var k := 0
	for m in morceaux:
		_rondin(p, Rp + Vector3((m[0] + m[1]) * 0.5, 0.02, 0), 0.0, m[1] - m[0], 0.13, graine + 9 + k, 1.0, 0.03)
		k += 1
	for m in rouleaux:
		var r_roul := 0.19 if _sans_refonte else 0.3
		var roul := BatiGeo.rondin(m[1] - m[0], r_roul, graine + 11 + k, 0.05, 0, 0.0, 1.0)
		_ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), Transform3D(Basis(), Rp + Vector3((m[0] + m[1]) * 0.5, 0.2 if _sans_refonte else 0.38, 0)), m_neige)
		k += 1
	return Vector2(eave_z, bas_y)

## Passe 4 : habillage visible par-dessus la palissade (purement visuel : ni collision, ni porte, ni intérieur).
## Lucarne éclairée dans chaque pignon (la façade des longs pans est cachée par la palissade, les pignons ne le sont pas),
## halos chauds en paliers autour de toutes les fenêtres (additifs, éteints le jour, modulés par la nuit).
func _habiller_maison(p: Node3D, L: float, W: float, y0: float, faite: float, fen: Array, yf: float) -> void:
	if _mat_halo == null:
		_mat_halo = StandardMaterial3D.new()
		_mat_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_halo.albedo_texture = _texture_halo()
		_mat_halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat_halo.albedo_color = Color(0, 0, 0)
		_mat_halo.disable_receive_shadows = true
	var halos: Array = []   # [position, lacet, taille]
	# lucarnes de pignon : vitrage émissif 0,56 × 0,5 m, cadre de bois, appui enneigé
	var yl := y0 + faite * 0.36
	# (la refonte bâti a déjà ses fenêtres de pignon : on ne double pas les lucarnes, seulement l'ancien bâti en reçoit)
	for cote in ([] if not _sans_refonte else [-1.0, 1.0]):
		var x: float = cote * (L * 0.5 + 0.17)
		var lacet: float = cote * PI * 0.5
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.56, 0.5)
		mi.mesh = q
		mi.material_override = m_fenetre
		mi.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(x, yl, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(mi)
		var xc: float = x + cote * 0.04
		_boite(p, Vector3(0.1, 0.1, 0.78), Transform3D(Basis(), Vector3(xc, yl + 0.3, 0)), m_poutres_h)
		_boite(p, Vector3(0.14, 0.09, 0.84), Transform3D(Basis(), Vector3(xc + cote * 0.02, yl - 0.29, 0)), m_poutres_h)
		for fz in [-0.33, 0.33]:
			_boite(p, Vector3(0.1, 0.5, 0.1), Transform3D(Basis(), Vector3(xc, yl, fz)), m_poutres_h)
		_boite(p, Vector3(0.1, 0.5, 0.06), Transform3D(Basis(), Vector3(xc + cote * 0.01, yl, 0)), m_poutres_h)   # meneau
		_boite(p, Vector3(0.2, 0.05, 0.8), Transform3D(Basis(), Vector3(xc + cote * 0.04, yl - 0.23, 0)), m_neige)   # neige sur l'appui
		halos.append([Vector3(x + cote * 0.22, yl, 0), lacet, Vector2(1.7, 1.5)])
	# halos des fenêtres des longs pans (vus de côté, ou à travers la porte de la palissade)
	for x in fen:
		for face in [1.0, -1.0]:
			halos.append([Vector3(x, yf, face * (W * 0.5 + 0.3)), 0.0 if face > 0.0 else PI, Vector2(1.6, 1.3)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for h in halos:
		var b := Basis(Vector3.UP, h[1])
		var sz: Vector2 = h[2]
		var c: Vector3 = h[0]
		var pts := [Vector3(-sz.x, -sz.y, 0) * 0.5, Vector3(sz.x, -sz.y, 0) * 0.5, Vector3(sz.x, sz.y, 0) * 0.5, Vector3(-sz.x, sz.y, 0) * 0.5]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(c + b * pts[k])
	var mh := MeshInstance3D.new()
	mh.mesh = st.commit()
	mh.material_override = _mat_halo
	mh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mh)

## Halo de fenêtre : rectangle arrondi de 16 × 16 px, intensité en quatre paliers (aucun dégradé lisse), ambre.
static func _texture_halo() -> ImageTexture:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - (n - 1) * 0.5, y - (n - 1) * 0.5) / (n * 0.5)
			var r := pow(pow(absf(d.x), 2.6) + pow(absf(d.y), 2.6), 1.0 / 2.6)
			var i := 0.95 if r < 0.34 else (0.6 if r < 0.54 else (0.3 if r < 0.74 else (0.12 if r < 0.93 else 0.0)))
			img.set_pixel(x, y, Color(i, i, i, 1.0))
	return ImageTexture.create_from_image(img)

## Cheminée de pierre : fût en petits moellons, chaînages d'angle en gros blocs alternés, base évasée, chapeau
## enneigé qui déborde.
func _cheminee(p: Node3D, xch: float, y_base: float, h_ch: float, graine: int) -> void:
	_boite(p, Vector3(0.72, h_ch, 0.72), Transform3D(Basis(), Vector3(xch, y_base + h_ch * 0.5, 0)), m_pierre_fine)
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var n := int(h_ch / 0.3)
	for i in n:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var gros := (i + (0 if sx * sz > 0 else 1)) % 2 == 0
				var sc := Vector3(0.3 if gros else 0.22, 0.29, 0.22 if gros else 0.3)   # chaînage d'angle : moellons de 22 à 30 cm
				_bloc(p, sc, r.randi(), Vector3(xch + sx * 0.35, y_base + 0.15 + i * 0.3, sz * 0.35), m_brute, 0.0, 0.0, 0.16, 0.06)
	_bloc(p, Vector3(1.05, 0.5, 1.05), r.randi(), Vector3(xch, y_base + 0.0, 0), m_brute, 0.0, 0.0, 0.18, 0.05)
	_bloc(p, Vector3(1.12, 0.2, 1.12), r.randi(), Vector3(xch, y_base + h_ch + 0.05, 0), m_brute, 0.0, 1.0, 0.25, 0.04)

# --- refonte « entrée du village » : pignons, têtes de dragon, lanterne de la halle, lueurs ------------------------

## Pièce de bois droite de `a` à `b` (dans un plan x = constante) : section `ep` (x : épaisseur, y : largeur).
func _piece(p: Node3D, a: Vector3, b: Vector3, ep: Vector2, mat: Material) -> void:
	var z := (b - a)
	var lg := z.length()
	if lg < 0.01:
		return
	z /= lg
	var x := Vector3.RIGHT
	var y := z.cross(x).normalized()
	_boite(p, Vector3(ep.x, ep.y, lg), Transform3D(Basis(x, y, z), (a + b) * 0.5), mat)

## Quad émissif (fenêtre de pignon) tourné vers +X·cote, UV 0..1 (la tuile de vitrage le couvre exactement).
func _quad_x(p: Node3D, c: Vector3, larg: float, haut: float, cote: float, mat: Material) -> void:
	var dz := larg * 0.5 * cote
	var a := c + Vector3(0, -haut * 0.5, dz)
	var b := c + Vector3(0, -haut * 0.5, -dz)
	var d := c + Vector3(0, haut * 0.5, -dz)
	var e := c + Vector3(0, haut * 0.5, dz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, d, b, a, e, d])   # ordre horaire vu du dehors (face avant)
	var n := Vector3(cote, 0, 0)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n, n, n, n])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)])
	_ajouter(_vitres, arrays, p.transform, mat, false)

## Quad émissif tourné vers +Z·cote (fenêtre de la lanterne de la halle), même lot que les vitrages.
func _quad_z(p: Node3D, c: Vector3, larg: float, haut: float, cote: float, mat: Material) -> void:
	var dx := larg * 0.5 * cote
	var a := c + Vector3(-dx, -haut * 0.5, 0)
	var b := c + Vector3(dx, -haut * 0.5, 0)
	var d := c + Vector3(dx, haut * 0.5, 0)
	var e := c + Vector3(-dx, haut * 0.5, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, d, b, a, e, d])   # ordre horaire vu du dehors
	var n := Vector3(0, 0, cote)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n, n, n, n])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)])
	_ajouter(_vitres, arrays, p.transform, mat, false)

## Pignon nordique (image de référence) : colombages sombres en saillie sur les planches debout (entrait, poinçon,
## contrefiches, traverse), petite fenêtre à croisillons qui luit le soir, et au faîte les planches de rive qui se
## CROISENT et finissent en têtes de dragon sculptées (coiffées de neige).
func _pignon_decor(p: Node3D, cote: float, L: float, W: float, y0: float, faite: float, releve: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var xg := cote * (L * 0.5 + 0.06)
	var hw := W * 0.5 + 0.1
	var larg_a := func(y: float) -> float: return hw * (1.0 - (y - y0) / faite)
	var ep := Vector2(0.11, 0.18)
	# entrait au pied du pignon
	_boite(p, Vector3(0.13, 0.22, hw * 2.0 + 0.1), Transform3D(Basis(), Vector3(xg, y0 + 0.1, 0)), m_colombage)
	# fenêtre de pignon (0,62 × 0,5 m) à croisillons, cadre épais, appui
	var yw := y0 + minf(1.05, faite * 0.27)
	var fw := Vector2(0.62, 0.5)
	_quad_x(p, Vector3(xg + cote * 0.02, yw, 0), fw.x, fw.y, cote, m_fen_pignon)
	_boite(p, Vector3(0.06, fw.y, 0.05), Transform3D(Basis(), Vector3(xg + cote * 0.04, yw, 0)), m_colombage)
	_boite(p, Vector3(0.06, 0.05, fw.x), Transform3D(Basis(), Vector3(xg + cote * 0.04, yw, 0)), m_colombage)
	for sz in [-1.0, 1.0]:
		_boite(p, Vector3(0.14, fw.y + 0.16, 0.1), Transform3D(Basis(), Vector3(xg, yw, sz * (fw.x * 0.5 + 0.05))), m_colombage)
	_boite(p, Vector3(0.14, 0.1, fw.x + 0.3), Transform3D(Basis(), Vector3(xg, yw + fw.y * 0.5 + 0.05, 0)), m_colombage)
	_boite(p, Vector3(0.2, 0.08, fw.x + 0.34), Transform3D(Basis(Vector3.BACK, 0.0), Vector3(xg + cote * 0.04, yw - fw.y * 0.5 - 0.04, 0)), m_colombage)
	# traverse au-dessus de la fenêtre, poinçon jusqu'au faîte, contrefiches de l'entrait vers la traverse
	var yb := yw + fw.y * 0.5 + 0.28
	var lb: float = larg_a.call(yb)
	_boite(p, Vector3(0.12, 0.18, lb * 2.0), Transform3D(Basis(), Vector3(xg, yb, 0)), m_colombage)
	_piece(p, Vector3(xg, yb, 0), Vector3(xg, y0 + faite - 0.2, 0), ep, m_colombage)
	for sz in [-1.0, 1.0]:
		_piece(p, Vector3(xg, y0 + 0.2, sz * (hw - 0.35)), Vector3(xg, yb - 0.05, sz * (fw.x * 0.5 + 0.12)), ep, m_colombage)
		# petits liens obliques au-dessus de la traverse
		var yl := yb + (y0 + faite - yb) * 0.42
		_piece(p, Vector3(xg, yb + 0.05, sz * (lb - 0.25)), Vector3(xg, yl, sz * 0.08), Vector2(0.1, 0.14), m_colombage)
	# têtes de dragon : prolongement des planches de rive au-delà du faîte, croisées en X
	var xr := cote * (L * 0.5 + 0.75 - 0.1)
	var eave_z := W * 0.5 + 0.78
	var phi := atan2(faite + releve, eave_z)
	var Rf := Vector3(xr, y0 + faite + 0.12, 0)
	for c in [-1.0, 1.0]:
		var d := Vector3(0, sin(phi), -c * cos(phi))
		var a := Rf - d * 0.15
		var b := Rf + d * 0.85
		_piece(p, a, b, Vector2(0.14, 0.22), m_colombage)
		_dragon(p, b, phi, -c, r)

## Tête de dragon sculptée (plan x = constante) : depuis `b`, le cou part à l'angle `phi` (au-dessus de l'horizontale,
## vers z de signe `sens`), s'enroule vers l'horizontale, puis crâne, museau, mâchoire ouverte, corne, neige sur la tête.
func _dragon(p: Node3D, b: Vector3, phi: float, sens: float, r: RandomNumberGenerator, t := 1.0) -> void:
	var c := -sens
	var angles := [phi - deg_to_rad(28.0), phi - deg_to_rad(62.0)]
	var pt := b
	for k in angles.size():
		var dd := Vector3(0, sin(angles[k]), -c * cos(angles[k]))
		var q: Vector3 = pt + dd * 0.24 * t
		_piece(p, pt - dd * 0.03 * t, q, Vector2(0.13, 0.2 - k * 0.02) * t, m_colombage)
		pt = q
	var ah := deg_to_rad(r.randf_range(-12.0, 4.0))
	var dh := Vector3(0, sin(ah), -c * cos(ah))
	var up := Vector3(0, cos(ah), c * sin(ah))
	var tete := pt + dh * 0.14 * t
	_piece(p, pt - dh * 0.04 * t, pt + dh * 0.3 * t, Vector2(0.14, 0.22) * t, m_colombage)                           # crâne
	_piece(p, pt + (dh * 0.26 + up * 0.03) * t, pt + dh * 0.5 * t, Vector2(0.11, 0.12) * t, m_colombage)             # museau
	_piece(p, pt + (dh * 0.12 - up * 0.1) * t, pt + (dh * 0.42 - up * 0.18) * t, Vector2(0.09, 0.06) * t, m_colombage) # mâchoire ouverte
	_piece(p, tete + up * 0.1 * t, tete + (up * 0.24 - dh * 0.2) * t, Vector2(0.05, 0.06) * t, m_colombage)          # corne
	_piece(p, tete + (up * 0.12 + dh * 0.02) * t, pt + (up * 0.17 + dh * 0.32) * t, Vector2(0.15, 0.05) * t, m_neige) # neige sur la tête

## Lanterne de fumée de la halle : le toit raide enveloppe la gaine de l'intérieur (qui s'arrête à l'ancien faîte) ;
## une tourelle de planches debout l'enferme et la prolonge au-dessus du nouveau faîte, petit toit enneigé sur poteaux
## (la fumée sort entre les deux).
func _lanterne_fumee(p: Node3D, trou: Vector2, W: float, y0: float, faite: float, faite_int: float, releve: float, graine: int) -> void:
	var eave_z := W * 0.5 + 0.78
	var tanp := (faite + releve) / eave_z
	var zh := eave_z / 5.0 + 0.36
	var x0 := trou.x - 0.3
	var x1 := trou.y + 0.3
	var xc := (x0 + x1) * 0.5
	var lg := x1 - x0
	var y_faite := y0 + faite
	var ybot := minf(y_faite - zh * tanp - 0.25, y0 + faite_int + 0.42)
	var ytop := maxf(y_faite + 0.45, y0 + faite_int + 1.75)
	var h := ytop - ybot
	for cz in [-1.0, 1.0]:
		_boite(p, Vector3(lg + 0.1, h, 0.1), Transform3D(Basis(), Vector3(xc, (ybot + ytop) * 0.5, cz * zh)), m_poutres)
		_boite(p, Vector3(lg + 0.22, 0.14, 0.18), Transform3D(Basis(), Vector3(xc, ytop, cz * zh)), m_colombage)
	for ex in [x0, x1]:
		_boite(p, Vector3(0.1, h, zh * 2.0 + 0.1), Transform3D(Basis(), Vector3(ex, (ybot + ytop) * 0.5, 0)), m_poutres)
		_boite(p, Vector3(0.18, 0.14, zh * 2.0 + 0.22), Transform3D(Basis(), Vector3(ex, ytop, 0)), m_colombage)
		for cz in [-1.0, 1.0]:
			_poteau(p, Vector3(ex, ytop, cz * zh), 0.06, 0.42, m_colombage)
	var yr := ytop + 0.42
	_pan(p, Vector3(xc, yr + 0.45, 0), Vector3(0, -0.5, zh + 0.3), lg + 0.5, graine + 4600, lg, false)
	_pan(p, Vector3(xc, yr + 0.45, 0), Vector3(0, -0.5, -(zh + 0.3)), lg + 0.5, graine + 4601, lg, false)
	if _sans_refonte:
		_fumee(p, Vector3(xc, ytop + 0.25, 0))
	else:
		_fumee_pixels(p, Vector3(xc, ytop + 0.25, 0), 1.4)
		# fenêtres chaudes sur les grandes faces de la lanterne (vues depuis la porte du village)
		for cz in [-1.0, 1.0]:
			for fx in [-lg * 0.25, lg * 0.25]:
				var c := Vector3(xc + fx, ytop - 0.3, cz * (zh + 0.06))
				_quad_z(p, c, 0.42, 0.34, cz, m_fen_pignon)
				_boite(p, Vector3(0.52, 0.06, 0.08), Transform3D(Basis(), c + Vector3(0, 0.2, 0)), m_colombage)
				_boite(p, Vector3(0.56, 0.06, 0.14), Transform3D(Basis(), c + Vector3(0, -0.2, cz * 0.03)), m_colombage)
				_boite(p, Vector3(0.04, 0.34, 0.05), Transform3D(Basis(), c + Vector3(0, 0, cz * 0.01)), m_colombage)

## Lueur des fenêtres vues du dehors selon l'heure (`n` = 1 - clarté du ciel) : presque éteintes en plein jour,
## franches au crépuscule et la nuit (sources chaudes contre l'ambiance bleue, sans lumière dynamique).
func _regler_lueurs(n: float) -> void:
	var k := lerpf(0.22, 1.0, smoothstep(0.12, 0.6, n))
	m_vitre_ext.set_shader_parameter("lueur", LUEUR * (0.7 * k))
	m_fen_pignon.set_shader_parameter("emission", LUEUR * (1.15 * k))
	m_fen_pignon.set_shader_parameter("teinte", Color(1, 1, 1) * lerpf(0.5, 1.0, k))
	var cf := Color(0.84, 0.86, 0.92).lerp(Color(0.5, 0.56, 0.7), smoothstep(0.2, 0.8, n))
	for mq in _fumees:
		mq.albedo_color = cf

## Noms affichés (porte) des bâtiments enterables.
const NOMS_BATIMENTS := {
	"halle": "Halle de Gunnhild",
	"sigrun": "Maison de Sigrún la Voyante",
	"chasseurs": "Maison des chasseurs",
	"grima": "Maison de Grima Cendrefroide",
	"forge": "Forge de Brodd",
}

## Abscisses des fenêtres (sur les deux longs pans) d'une maison de longueur L.
func _fenetres_de(longueur: float) -> Array:
	return [-longueur * 0.26, longueur * 0.26]

## Maison nordique (lot 5, 2e passe) : soubassement de pierres brutes en saillie, murs de rondins à 8 pans croisés
## aux angles sur âme sombre, contreforts de pierre, toit à épaisseur (chevrons, faîtière, rives en cornes,
## stalactites), cheminée de pierre appareillée, porte renforcée de fer dans un cadre épais, deux marches,
## fenêtres encadrées à volet, torche murale et fumée.
## Lot « kit intérieur » : la maison est CREUSE et ENTERABLE (murs de rondins vus des deux côtés, plancher, plafond sous
## charpente, porte sur charnière, fenêtres ouvertes aux carreaux translucides) ; l'intérieur (`Interieur` + `Interieurs`)
## dépend de `id` : halle (longue maison), sigrun, chasseurs, grima.
func _maison(centre: Vector3, lacet: float, longueur: float, largeur: float, h_murs: float, faite: float, id: String) -> Node3D:
	var cheffe := id == "halle"
	var p := _pivot(centre, lacet)
	p.name = "Maison_" + id
	h_murs = maxf(h_murs, 2.3)   # porte de 2 m + linteau : 9 lits de rondins
	var y0 := 0.4 + h_murs
	var graine := int(absf(centre.x) * 13.0 + absf(centre.z) * 7.0) + 1
	var ip := Interieur.new()
	ip.name = "Interieur"
	ip.nom = NOMS_BATIMENTS[id]
	ip.demi = Vector2(longueur * 0.5 - 0.15, largeur * 0.5 - 0.15)
	ip.porte_locale = Vector3(0, 1.4, largeur * 0.5 + 0.05)
	p.add_child(ip)
	interieurs.append(ip)
	var ib := Interieurs.new(self, ip, mats_int, longueur, largeur, h_murs, faite)
	# refonte bâti : le toit EXTÉRIEUR est plus raide (PENTE_TOIT) et son égout plus haut ; l'intérieur (plafond sous
	# charpente, gaine de fumée) garde `faite` : le nouveau toit l'enveloppe entièrement (plans plus hauts partout).
	var faite_int := faite
	var releve := 0.5
	if not _sans_refonte:
		releve = RELEVE_EGOUT
		faite = (largeur * 0.5 + 0.78) * tan(deg_to_rad(PENTE_TOIT)) - releve
	var fen := _fenetres_de(longueur)
	_soubassement(p, longueur, largeur, graine)
	_ame(p, longueur, largeur, h_murs, fen)
	_murs_rondins(p, ip, longueur, largeur, h_murs, graine, fen)
	for cote in [-1.0, 1.0]:
		_pignon(p, cote * longueur * 0.5, y0, largeur * 0.5 + 0.1, faite)
		if not _sans_refonte:
			_pignon_decor(p, cote, longueur, largeur, y0, faite, releve, graine + int(cote) * 17)
	# contreforts de pierre sur les longs pans, à (L/2 - 1)
	var rc := RandomNumberGenerator.new()
	rc.seed = graine + 77
	for cote in [-1.0, 1.0]:
		for xc in [-(longueur * 0.5 - 1.0), longueur * 0.5 - 1.0]:
			var zc: float = cote * (largeur * 0.5 + 0.15 + 0.3)
			for i in 4:
				var s := 0.64 - i * 0.05
				_bloc(p, Vector3(s, 0.44 - i * 0.02, s * 0.9), rc.randi(), Vector3(xc + rc.randf_range(-0.03, 0.03), 0.3 + i * 0.4, zc), m_brute, rc.randf_range(-0.06, 0.06), 0.05, 0.2, 0.07)
			_bloc(p, Vector3(0.72, 0.2, 0.66), rc.randi(), Vector3(xc, 1.95, zc), m_brute, 0.0, 1.0, 0.3, 0.05)
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(xc, 1.1, zc)), Vector3(0.76, 2.2, 0.72))
	_coque_collisions(p, longueur, largeur, y0, faite_int)
	# trou à fumée de la halle : deux cases de la dalle, de part et d'autre du faîte
	var trou := Vector2.ZERO
	if cheffe:
		trou = BatiGeo.trou_cases(longueur + 1.5, -1.0, 2)
	var eave := _toit(p, longueur, largeur, y0, faite, graine, trou, releve)
	if cheffe:
		ib.gaine_fumee(trou)
		if _sans_refonte:
			_fumee(p, Vector3((trou.x + trou.y) * 0.5, y0 + faite + 1.3, 0))
		else:
			_lanterne_fumee(p, trou, largeur, y0, faite, faite_int, releve, graine)
	else:
		var xch := longueur * 0.15
		var h_ch := faite + (0.7 if _sans_refonte else 0.95)
		_cheminee(p, xch, y0 - 0.2, h_ch, graine + 5)
		_fumee(p, Vector3(xch, y0 + h_ch + 0.2, 0))
	# porte (côté +Z) : cadre épais, vantail sur charnière (planches debout, bandes de fer, anneau), marches de 20 cm
	var zf := largeur * 0.5 + 0.17
	for jx in [-0.7, 0.7]:
		_boite(p, Vector3(0.2, 2.05, 0.34), Transform3D(Basis(), Vector3(jx, 0.4 + 1.02, largeur * 0.5 + 0.01)), m_poutres_h)
	_boite(p, Vector3(1.8, 0.2, 0.36), Transform3D(Basis(), Vector3(0, 0.4 + 2.1, largeur * 0.5 + 0.01)), m_poutres_h)
	var charniere := _vantail(p, Vector3(-0.6, 0.4, largeur * 0.5), 1.2, 2.0)
	ip.vantaux.append([charniere, -1.75])
	_bloc(p, Vector3(1.95, 0.2, 0.62), rc.randi(), Vector3(0, 0.1, zf + 0.5), m_brute, 0.0, 0.5, 0.2, 0.05)
	_bloc(p, Vector3(1.65, 0.2, 0.42), rc.randi(), Vector3(0, 0.3, zf + 0.26), m_brute, 0.0, 0.5, 0.2, 0.05)
	_rampe_porte(p, Vector3(0, 0, largeur * 0.5), 1.8)
	_bloc_porte(ip, p, Vector3(0, 0.4 + 1.25, largeur * 0.5), Vector3(1.24, 2.5, 0.3))
	# fenêtres (cadre extérieur ici, cadre intérieur par Interieurs)
	var yf := (_y_lit(LITS_FENETRE[0], h_murs) + _y_lit(LITS_FENETRE[1], h_murs)) * 0.5
	for x in fen:
		for face in [1.0, -1.0]:
			_fenetre_cadre(p, x, yf, face * (largeur * 0.5 + 0.17), face)
			ib.fenetre_cadre(x, yf, face * (largeur * 0.5 + 0.17), face)
	if avec_habillage:
		_habiller_maison(p, longueur, largeur, y0, faite, fen, yf)
	# torche murale à droite de la porte
	_torche_murale(p, Vector3(1.25, 0.4 + 1.45, zf + 0.03), 1.0, cheffe)   # une vraie lumière à la porte de la halle (comme avant)
	if cheffe:
		# boucliers peints accrochés au mur, de part et d'autre de la porte, et bancs
		for x in [-2.6, -1.7, 1.9, 2.7]:
			_cylindre(p, 0.38, 0.38, 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.06)), m_cuir if x < 0 else m_fer, 8)
			_cylindre(p, 0.09, 0.09, 0.09, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.1)), m_fer, 8)
		_banc(p, Vector3(-2.2, 0, zf + 0.75), 2.0)
		_banc(p, Vector3(2.2, 0, zf + 0.75), 2.0)
	# l'intérieur (plafond, mobilier, lumières) : construit après le chargement, une maison par image
	Chrono.marque("  maison %s : coque extérieure" % id)
	_differer(ib, func() -> void:
		ib.coque(id)
		ib.contenu(id)
		ib.finir())
	_emprise(p, Vector2(longueur * 0.5 + 0.3, largeur * 0.5 + 0.3), Vector2.ZERO, ip)
	return p

## Maison enterable posée en coordonnées MONDE (x, z) sur le plateau, `lacet` monde (0 = porte vers +Z/sud).
func _maison_monde(x: float, z: float, lacet: float, longueur: float, largeur: float, h_murs: float, faite: float, id: String) -> Node3D:
	return _maison(_repere(x, z, lacet, global_position.y).origin, lacet - rotation.y, longueur, largeur, h_murs, faite, id)

## Vantail de porte sur charnière : planches debout, deux bandes de fer cloutées, anneau. `pos` = axe de la charnière.
func _vantail(parent: Node3D, pos: Vector3, larg: float, haut: float, cote := 1.0) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	parent.add_child(h)
	var x := cote * larg * 0.5
	_boite(h, Vector3(larg - 0.06, haut, 0.1), Transform3D(Basis(), Vector3(x, haut * 0.5, 0)), m_poutres)
	for by in [0.22, haut * 0.74]:
		_boite(h, Vector3(larg - 0.06, 0.13, 0.04), Transform3D(Basis(), Vector3(x, by, 0.07)), m_fer)
		_boite(h, Vector3(larg - 0.06, 0.13, 0.04), Transform3D(Basis(), Vector3(x, by, -0.07)), m_fer)
		for rx in [-0.4, 0.0, 0.4]:
			_boite(h, Vector3(0.04, 0.04, 0.03), Transform3D(Basis(), Vector3(x + rx * larg / 1.2, by, 0.09)), m_fer)
	_boite(h, Vector3(0.09, 0.22, 0.05), Transform3D(Basis(), Vector3(x + cote * (larg * 0.5 - 0.2), haut * 0.5, 0.1)), m_fer)
	_boite(h, Vector3(0.09, 0.22, 0.05), Transform3D(Basis(), Vector3(x + cote * (larg * 0.5 - 0.2), haut * 0.5, -0.1)), m_fer)
	return h

## Rampe de collision sous les deux marches de la porte (le joueur n'a pas de montée de marche) : de 0 à F sur 1 m.
func _rampe_porte(p: Node3D, plan: Vector3, larg: float) -> void:
	var f := ConvexPolygonShape3D.new()
	var y := Interieurs.F
	f.points = PackedVector3Array([
		Vector3(-larg * 0.5, 0, 1.0), Vector3(larg * 0.5, 0, 1.0), Vector3(-larg * 0.5, y, 0.0), Vector3(larg * 0.5, y, 0.0),
		Vector3(-larg * 0.5, 0, 0.0), Vector3(larg * 0.5, 0, 0.0)])
	_collision(p, f, Transform3D(Basis(), plan + Vector3(0, 0, 0.1)), Vector3.ZERO)

## Blocage de la porte fermée (désactivé à l'ouverture).
func _bloc_porte(ip: Interieur, p: Node3D, pos: Vector3, taille: Vector3) -> void:
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), pos), taille)
	ip.bloc_porte = corps.get_child(corps.get_child_count() - 1) as CollisionShape3D

## Collisions de la coque : plancher, quatre murs creux (ouverture de la porte côté +Z), linteau, sommet.
func _coque_collisions(p: Node3D, L: float, W: float, y0: float, faite: float, demi_porte := 0.62, epaisseur := 0.5) -> void:
	var haut := y0 + faite + 0.5
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, Interieurs.F * 0.5 - 0.3, 0)), Vector3(L - 0.2, Interieurs.F + 0.6, W + 0.3))
	# longs pans (le long de X) : décalés vers l'extérieur de 0,1 m pour ne pas rogner la pièce
	for cote in [-1.0, 1.0]:
		var zc: float = cote * (W * 0.5 + 0.1)
		if cote > 0.0:
			var xa := demi_porte
			var xb := L * 0.5 + 0.3
			for sx in [-1.0, 1.0]:
				_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(sx * (xa + xb) * 0.5, haut * 0.5, zc)), Vector3(xb - xa, haut, epaisseur))
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (2.4 + haut) * 0.5, zc)), Vector3(demi_porte * 2.0, haut - 2.4, epaisseur))
		else:
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, haut * 0.5, zc)), Vector3(L + 0.6, haut, epaisseur))
		_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(cote * (L * 0.5 + 0.1), haut * 0.5, 0)), Vector3(epaisseur, haut, W + 0.6))

## Vitrage : quad orienté vers +Z (lacet 0) ou -Z (lacet PI), UV 0..1 (la texture de vitrage le couvre exactement).
func _vitre(parent: Node3D, pos: Vector3, taille: Vector2, lacet: float) -> void:
	if not _sans_refonte:
		# refonte : tous les vitrages dans le lot `_vitres` (repère du village) : ~17 appels de dessin en moins
		var hx := taille.x * 0.5
		var hy := taille.y * 0.5
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		# ordre horaire vu de +Z (face avant de Godot), comme le QuadMesh d'avant
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-hx, -hy, 0), Vector3(hx, hy, 0), Vector3(hx, -hy, 0), Vector3(-hx, -hy, 0), Vector3(-hx, hy, 0), Vector3(hx, hy, 0)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)])
		var xf := (parent.transform if parent.get_parent() == self else (transform.affine_inverse() * parent.global_transform)) * Transform3D(Basis(Vector3.UP, lacet), pos)
		_ajouter(_vitres, arrays, xf, m_vitre_ext, false)
		return
	var q := QuadMesh.new()
	q.size = taille
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m_vitre_ext
	mi.transform = Transform3D(Basis(Vector3.UP, lacet), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Banc : planche épaisse sur deux pieds.
func _banc(parent: Node3D, pos: Vector3, longueur: float) -> void:
	_boite(parent, Vector3(longueur, 0.1, 0.4), Transform3D(Basis(), pos + Vector3(0, 0.5, 0)), m_poutres_h)
	for dx in [-0.42, 0.42]:
		_boite(parent, Vector3(0.1, 0.5, 0.36), Transform3D(Basis(), pos + Vector3(dx * longueur * 0.5 / 0.42 * 0.8, 0.25, 0)), m_poutres)

## Palissade prolongée (C7b, plan v2 : 228 m, ReliefVillage.PALISSADE) : pieux BAS taillés (visuel validé, passe 3 : ~1,5 m,
## pointe enneigée) qui SUIVENT LE TERRAIN un par un (la haute rue et la tour sont dans l'enceinte) ; 3 portes (SO inchangée,
## N, E) et 2 grilles d'eau là où passe la rivière. COLLISION de chaque pieu inchangée : un cylindre de 3,6 m (rayon 0,22)
## centré à 1,8 m au-dessus du sol du pieu. Grilles : pieux fins (rayon 0,08) tous les 0,42 m, plantés dans le lit, 3 lisses,
## collision en cylindres de rayon 0,15 sur 3,6 m depuis le fond (l'eau passe, pas le joueur).
func _palissade_v2() -> void:
	var pts: Array = ReliefVillage.PALISSADE
	var n := pts.size()
	var loc := RandomNumberGenerator.new()
	loc.seed = 70313
	var variantes: Array[ArrayMesh] = []
	for k in 4:
		variantes.append(_pieu_taille(loc))
	var xf_v: Array = [[], [], [], []]
	var forme := CylinderShape3D.new()
	forme.radius = 0.22
	forme.height = 3.6
	var forme_g := CylinderShape3D.new()
	forme_g.radius = 0.15
	forme_g.height = 3.6
	var inv := global_transform.affine_inverse()
	var portes: Array[Vector2] = []
	for i in PORTES_V2:
		portes.append(pts[i])
	var grilles: Array[Vector2] = []
	for i in GRILLES_V2:
		grilles.append(pts[i])
	var rangs: Array = []      # suites de pieux contigus (pieds monde) : liens de corde
	var rang: Array = []
	var rang_g: Array = []     # suite de pieux de grille
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var nb := maxi(1, roundi(a.distance_to(b) / 0.42))
		var dir := (b - a).normalized()
		for k in nb:
			var q := a.lerp(b, float(k) / nb)
			var porte := false
			for g in portes:
				if q.distance_to(g) < 2.45:
					porte = true
			var grille := false
			for g in grilles:
				if q.distance_to(g) < 7.0:
					var r := ReliefVillage.riviere(q.x, q.y)
					if not r.is_empty() and float(r["distance"]) < float(r["demi_largeur"]) + 0.35:
						grille = true
			if porte or grille:
				if rang.size() > 1:
					rangs.append(rang)
				rang = []
			if porte:
				continue
			if grille:
				var eau: float = ReliefVillage.riviere(q.x, q.y)["eau"]
				var fond := h_sol(q.x, q.y)
				grilles_v2.append([Vector3(q.x, fond, q.y), eau])
				rang_g.append([Vector3(q.x, fond, q.y), eau, dir])
				var csg := CollisionShape3D.new()
				csg.shape = forme_g
				csg.position = inv * Vector3(q.x, fond + 1.8 - 0.2, q.y)
				corps.add_child(csg)
				continue
			if rang_g.size() > 0:
				_grille_eau(rang_g)
				rang_g = []
			var y := h_sol(q.x, q.y)
			var pw := Vector3(q.x, y, q.y)
			pieux_v2.append(pw)
			rang.append(pw)
			# hauteur 0,88-1,12 × la variante (~1,5 m), lacet libre, léger dévers (générateur local)
			var ang := atan2(dir.x, dir.y)
			var sy := loc.randf_range(0.88, 1.12)
			var bw := Basis(Vector3.UP, loc.randf() * TAU)
			bw = Basis(Vector3(cos(ang), 0, -sin(ang)), loc.randf_range(-0.035, 0.035)) * Basis(Vector3(sin(ang), 0, cos(ang)), loc.randf_range(-0.02, 0.02)) * bw
			bw = bw.scaled(Vector3(1, sy, 1))
			var jit := Vector3(-dir.y, 0, dir.x) * loc.randf_range(-0.04, 0.04)
			xf_v[loc.randi() % 4].append(Transform3D(inv.basis * bw, inv * (pw + jit)))
			var cs := CollisionShape3D.new()
			cs.shape = forme
			cs.position = inv * (pw + Vector3(0, 1.8, 0))
			corps.add_child(cs)
	if rang_g.size() > 0:
		_grille_eau(rang_g)
	if rang.size() > 1:
		rangs.append(rang)
	# la palissade est fermée : le dernier rang rejoint le premier s'il n'y a ni porte ni grille entre eux
	if rangs.size() > 1 and (rangs[0][0] as Vector3).distance_to(rangs[-1][-1]) < 0.6:
		var dernier: Array = rangs.pop_back()
		dernier.append_array(rangs[0])
		rangs[0] = dernier
	for k in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variantes[k]
		mm.instance_count = xf_v[k].size()
		for i in xf_v[k].size():
			mm.set_instance_transform(i, xf_v[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "PieuxBas%d" % k
		mmi.multimesh = mm
		add_child(mmi)
	_liens_v2(rangs, [0.42, 0.98])

## Grille d'eau : pieux fins plantés dans le lit, trois lisses (bas, milieu, haut) qui suivent la grille, pointes enneigées.
func _grille_eau(rang: Array) -> void:
	var p := _pivot(Vector3.ZERO, 0.0)
	p.name = "GrilleEau"
	var inv := global_transform.affine_inverse()
	var r := RandomNumberGenerator.new()
	r.seed = 6100 + rang.size()
	var haut_max := -INF
	for e in rang:
		haut_max = maxf(haut_max, float(e[1]) + 1.3)
	for e in rang:
		var pied: Vector3 = e[0]
		var h := haut_max - pied.y + 0.5
		var c := inv * (pied + Vector3(0, h * 0.5 - 0.5, 0))
		_cylindre(p, 0.075, 0.09, h, Transform3D(Basis(Vector3.UP, r.randf() * TAU), c), m_palissade, 6)
		_cylindre(p, 0.0, 0.075, 0.22, Transform3D(Basis(), inv * (pied + Vector3(0, h - 0.5 + 0.11, 0))), m_neige, 6)
	# lisses : d'un bout à l'autre de la grille, à 3 hauteurs fixes au-dessus de l'eau la plus haute
	var a: Vector3 = rang[0][0]
	var b: Vector3 = rang[-1][0]
	for dy in [-0.9, -0.15, 0.55]:
		var ya: float = haut_max + dy
		var pa := Vector3(a.x, ya, a.z)
		var pb := Vector3(b.x, ya, b.z)
		var lg := pa.distance_to(pb) + 0.4
		var d := (pb - pa).normalized()
		var ang := atan2(d.x, d.z)
		_boite(p, Vector3(0.11, 0.13, lg), inv * Transform3D(Basis(Vector3.UP, ang), (pa + pb) * 0.5), m_poutres_h)
		if dy > 0.5:
			_boite(p, Vector3(0.16, 0.06, lg), inv * Transform3D(Basis(Vector3.UP, ang), (pa + pb) * 0.5 + Vector3(0, 0.09, 0)), m_neige)
	# deux gros poteaux d'about (sur les berges)
	for e in [rang[0], rang[-1]]:
		var pied: Vector3 = e[0]
		var dd: Vector3 = (b - a).normalized() * (-0.45 if e == rang[0] else 0.45)
		var q := pied + Vector3(dd.x, 0, dd.z)
		var yq := h_sol(q.x, q.z)
		var h := haut_max + 0.9 - yq
		_cylindre(p, 0.2, 0.22, h, Transform3D(Basis(), inv * Vector3(q.x, yq + h * 0.5 - 0.3, q.z)), m_palissade, 7)

## Liens de corde (côté intérieur) d'un pieu au suivant, à hauteur constante au-dessus du pied de chaque pieu.
func _liens_v2(rangs: Array, hauteurs: Array) -> void:
	var inv := global_transform.affine_inverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rg in rangs:
		for i in rg.size() - 1:
			var a: Vector3 = rg[i]
			var b: Vector3 = rg[i + 1]
			if a.distance_to(b) > 1.2:
				continue
			var d := (b - a)
			d.y = 0.0
			d = d.normalized()
			var nrm := Vector3(-d.z, 0, d.x)
			var m := (a + b) * 0.5
			if not ReliefVillage.dans_enceinte(m.x + nrm.x * 0.6, m.z + nrm.z * 0.6):
				nrm = -nrm
			for hy in hauteurs:
				var p0: Vector3 = inv * (a + nrm * 0.2 + Vector3(0, hy, 0))
				var p1: Vector3 = inv * (b + nrm * 0.2 + Vector3(0, hy, 0))
				var dv := Vector3(0, 0.07, 0)
				var nl: Vector3 = inv.basis * nrm
				for tri in [[p0 - dv, p1 - dv, p1 + dv], [p0 - dv, p1 + dv, p0 + dv]]:
					for v: Vector3 in tri:
						st.set_normal(nl)
						st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "LiensPalissade"
	mi.mesh = st.commit()
	mi.material_override = m_foin
	add_child(mi)

## Pieu taillé à la hache : fût à 7 pans irréguliers (rayon ~0,17 m, de -0,3 à ~1,15 m), pointe à 4-5 facettes jusqu'à
## ~1,55 m, pointe un peu décentrée. Couleur de sommet : rgb = usure/occlusion (pied et fentes sombres, arêtes de la taille
## plus claires), alpha 0 = neige sur le haut de la pointe (bord irrégulier). Faces à plat (taille franche).
func _pieu_taille(loc: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(m_palissade)
	var n := 7
	var hf := loc.randf_range(1.08, 1.2)                # haut du fût (début de la taille)
	var hp := hf + loc.randf_range(0.36, 0.46)           # sommet de la pointe
	var r_bas: Array[float] = []
	var r_haut: Array[float] = []
	var ang: Array[float] = []
	for k in n:
		ang.append(TAU * (k + loc.randf_range(-0.2, 0.2)) / n)
		var r := loc.randf_range(0.155, 0.19)
		r_bas.append(r * 1.04)
		r_haut.append(r * loc.randf_range(0.93, 1.0))
	var pointe := Vector3(loc.randf_range(-0.04, 0.04), hp, loc.randf_range(-0.04, 0.04))
	# taille : chaque pan du haut est biseauté à une hauteur différente (coups de hache), puis converge vers la pointe
	var bis: Array[float] = []
	for k in n:
		bis.append(hf + loc.randf_range(-0.07, 0.05))
	var neige_h := hp - loc.randf_range(0.25, 0.31)     # au-dessus : neige (lisible même à contre-jour)
	var ombre_pied := Color(0.55, 0.52, 0.5, 1)
	for k in n:
		var k2 := (k + 1) % n
		var d0 := Vector3(cos(ang[k]), 0, sin(ang[k]))
		var d1 := Vector3(cos(ang[k2]), 0, sin(ang[k2]))
		var a0 := d0 * r_bas[k] + Vector3(0, -0.3, 0)
		var a1 := d1 * r_bas[k2] + Vector3(0, -0.3, 0)
		var b0 := d0 * r_haut[k] + Vector3(0, bis[k], 0)
		var b1 := d1 * r_haut[k2] + Vector3(0, bis[k2], 0)
		var usure := loc.randf_range(0.78, 1.0)          # pans plus ou moins grisés par les intempéries
		var ch := Color(usure, usure * 0.97, usure * 0.95, 1)
		var cp := Color(ombre_pied.r * usure, ombre_pied.g * usure, ombre_pied.b * usure, 1)
		_tri_plat(st, [a0, a1, b1], [cp, cp, ch])
		_tri_plat(st, [a0, b1, b0], [cp, ch, ch])
		# pointe : bois frais de la taille un peu plus clair ; neige au-dessus de neige_h (bord découpé par pan)
		var clair := Color(minf(usure * 1.12, 1.15), usure * 1.05, usure * 0.98, 1)
		var cb0 := clair
		var cb1 := clair
		var nh := neige_h + loc.randf_range(-0.05, 0.04)
		var m0 := b0.lerp(pointe, clampf((nh - b0.y) / (pointe.y - b0.y), 0.12, 0.8))
		var m1 := b1.lerp(pointe, clampf((nh + loc.randf_range(-0.04, 0.04) - b1.y) / (pointe.y - b1.y), 0.12, 0.8))
		var blanc := Color(1, 1, 1, 0)
		_tri_plat(st, [b0, b1, m1], [cb0, cb1, clair])
		_tri_plat(st, [b0, m1, m0], [cb0, clair, clair])
		_tri_plat(st, [m0, m1, pointe], [blanc, blanc, blanc])
	return st.commit()

func _tri_plat(st: SurfaceTool, p: Array, cols: Array) -> void:
	var nrm: Vector3 = (p[2] - p[0]).cross(p[1] - p[0]).normalized()
	for i in 3:
		st.set_normal(nrm)
		st.set_color(cols[i])
		st.add_vertex(p[i])

func _porte() -> void:
	_porte_en(_pivot(Vector3(0, 0, RAYON), 0.0), true)

## Portes N et E de la palissade prolongée (C7b) : même modèle que la porte SO, sans torches (lanterne émissive à la poutre).
func _porte_v2(c: Vector2, lacet: float) -> void:
	var p := pivot_monde(c.x, c.y, lacet, h_sol(c.x, c.y))
	p.name = "Porte_%d" % roundi(c.x)
	_porte_en(p, false)

func _porte_en(p: Node3D, torches: bool) -> void:
	for cote in [-1.0, 1.0]:
		var x: float = cote * (DEMI_PORTE + 0.15)
		# poteau octogonal sur un socle de pierre, tête de dragon sculptée au sommet
		_bloc(p, Vector3(1.05, 0.55, 1.05), 4500 + int(x * 3.0), Vector3(x, 0.1, 0), m_brute, 0.1, 0.4, 0.2, 0.07)
		_cylindre(p, 0.3, 0.34, 5.4, Transform3D(Basis(), Vector3(x, 2.5, 0)), m_poutres, 8, true)
		if _sans_refonte:
			_boite(p, Vector3(0.3, 0.3, 0.8), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(x, 5.3, 0.35)), m_poutres_h)
			_boite(p, Vector3(0.22, 0.22, 0.4), Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x, 5.45, 0.75)), m_poutres_h)
		else:
			# tête de dragon sculptée au sommet du poteau, tournée vers les arrivants (+Z), neige sur la tête du poteau
			var rd := RandomNumberGenerator.new()
			rd.seed = 4520 + int(cote)
			_piece(p, Vector3(x, 5.0, 0.0), Vector3(x, 5.55, 0.12), Vector2(0.26, 0.3), m_colombage)
			_dragon(p, Vector3(x, 5.5, 0.12), deg_to_rad(70.0), 1.0, rd, 1.3)
			_cylindre(p, 0.33, 0.36, 0.14, Transform3D(Basis(), Vector3(x, 5.24, 0)), m_neige, 8)
		# contrefiche : jambe de force entre le poteau et la poutre
		_boite(p, Vector3(0.16, 1.3, 0.16), Transform3D(Basis(Vector3.BACK, -cote * 0.75), Vector3(x - cote * 0.55, 4.2, 0)), m_poutres)
		if torches:
			# torche fixée au poteau, côté intérieur
			_boite(p, Vector3(0.07, 0.6, 0.07), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(x - cote * 0.05, 2.5, -0.42)), m_ecorce)
			_feu(p, Vector3(x - cote * 0.05, 2.9, -0.55), 0.8, 1.5, 9.0)
	if not torches:
		VillageBati.lanterne(self, p, Vector3(0, 4.49, 0.32), 0.0)   # lanterne pendue sous la poutre, côté dehors
	_boite(p, Vector3(DEMI_PORTE * 2 + 1.2, 0.42, 0.42), Transform3D(Basis(), Vector3(0, 4.7, 0)), m_poutres_h)
	if _sans_refonte:
		_boite(p, Vector3(DEMI_PORTE * 2 + 1.4, 0.22, 0.66), Transform3D(Basis(), Vector3(0, 5.0, 0)), m_neige)
	else:
		# rouleau de neige épais et bosselé sur la poutre (déborde des deux côtés)
		var roul := BatiGeo.rondin(DEMI_PORTE * 2 + 1.5, 0.26, 4530, 0.06, 0, 0.0, 1.0)
		_ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), Transform3D(Basis().scaled(Vector3(1.0, 0.72, 1.35)), Vector3(0, 5.02, 0)), m_neige, false)
		_ajouter(p, (roul[1] as BatiGeo.Maillage).arrays(), Transform3D(Basis().scaled(Vector3(1.0, 0.72, 1.35)), Vector3(0, 5.02, 0)), m_neige, false)

## Forge de Brodd (lot « kit intérieur » : fermée et enterable). Appentis de 5 × 4 m : quatre poteaux octogonaux, toit à
## une pente, mur de fond en pierre, murs latéraux de pierre sèche, façade de planches (double porte à deux vantaux,
## fenêtre à volet relevé). Foyer, enclume, soufflet, bac de trempe, réserves : `InterieurForge`.
## Repère local : -Z = le fond (foyer), +Z = la façade ; le sol est au niveau du village (y = 0), sans marche.
func _forge(centre: Vector3, lacet := PI * 0.5) -> Node3D:
	var p := _pivot(centre, lacet)
	p.name = "Forge"
	var ip := Interieur.new()
	ip.name = "Interieur"
	ip.nom = NOMS_BATIMENTS["forge"]
	ip.demi = Vector2(2.1, 1.7)
	ip.porte_locale = Vector3(1.35, 1.3, 1.85)
	ip.sol_y = 0.04
	p.add_child(ip)
	interieurs.append(ip)
	var ib := Interieurs.new(self, ip, mats_int, 4.2, 3.4, 2.0, 0.6)
	# poteaux octogonaux (le mur de pierre les enserre) et toit à une pente
	for x in [-2.4, 2.4]:
		for z in [-1.8, 1.8]:
			_poteau(p, Vector3(x, 0, z), 0.13, 2.7 if z < 0 else 2.2, m_poutres, false)
	_pan(p, Vector3(0, 2.72, -2.3), Vector3(0, -0.63, 4.55), 5.9, 4242, 5.0, false)
	for z in [-1.8, 1.8]:   # sablières
		_boite(p, Vector3(5.2, 0.22, 0.26), Transform3D(Basis(), Vector3(0, 2.7 if z < 0 else 2.2, z) + Vector3(0, -0.12, 0)), m_poutres_h)
	# mur de fond en pierre derrière le foyer, avec contreforts
	_pile(p, Vector3(0, 1.2, -2.0), Vector3(4.8, 2.4, 0.5), 4301, m_brute, true)
	for x in [-2.4, 0.0, 2.4]:
		_pile(p, Vector3(x, 1.0, -2.4), Vector3(0.6, 2.0, 0.3), 4310 + int(x), m_brute, false, 1.0)   # contreforts : côté dehors seulement
	# murs latéraux : pierre sèche en trois tronçons qui suivent la pente du toit (plein haut sous les chevrons)
	var tronc := [[-2.0, -0.6, 2.4], [-0.6, 0.8, 2.2], [0.8, 1.9, 2.04]]
	for sx in [-1.0, 1.0]:
		var k := 0
		for t in tronc:
			var zc: float = (t[0] + t[1]) * 0.5
			_pile(p, Vector3(sx * 2.4, t[2] * 0.5, zc), Vector3(0.4, t[2], t[1] - t[0]), 4400 + k + int(sx + 1.0) * 5, m_roche, true, 0.0)
			k += 1
	# façade de planches : de part et d'autre de la porte (x de 0,55 à 2,15), fenêtre à gauche (x de -1,9 à -0,9)
	var haut_f := 2.05
	var fe := [-1.9, -0.9, 1.1, 1.85]    # fenêtre : x0, x1, y0, y1
	_boite(p, Vector3(0.55, haut_f, 0.16), Transform3D(Basis(), Vector3(-2.175, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.45, haut_f, 0.16), Transform3D(Basis(), Vector3(-0.175, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.0, fe[2], 0.16), Transform3D(Basis(), Vector3(-1.4, fe[2] * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.0, haut_f - fe[3], 0.16), Transform3D(Basis(), Vector3(-1.4, (haut_f + fe[3]) * 0.5, 1.8)), m_poutres, false)
	_boite(p, Vector3(0.3, haut_f, 0.16), Transform3D(Basis(), Vector3(2.3, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.6, haut_f - 1.95, 0.16), Transform3D(Basis(), Vector3(1.35, (haut_f + 1.95) * 0.5, 1.8)), m_poutres_h, false)   # linteau
	# vitrage translucide (plan ps1_vitre) + meneau : la fenêtre n'est plus un trou
	_vitre(p, Vector3(-1.4, (fe[2] + fe[3]) * 0.5, 1.8), Vector2(1.0, fe[3] - fe[2]), 0.0)
	_boite(p, Vector3(0.05, fe[3] - fe[2], 0.08), Transform3D(Basis(), Vector3(-1.4, (fe[2] + fe[3]) * 0.5, 1.8)), m_poutres)
	# volet de la fenêtre : relevé en auvent sur un bâton
	_boite(p, Vector3(1.0, 0.04, 0.7), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(-1.4, fe[3] + 0.28, 2.1)), m_poutres_h)
	_boite(p, Vector3(0.04, 0.04, 0.6), Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(-1.85, 1.65, 2.2)), m_poutres)
	_boite(p, Vector3(1.0, 0.1, 0.22), Transform3D(Basis(), Vector3(-1.4, fe[2] - 0.03, 1.86)), m_poutres_h)   # appui
	for fx in [-1.95, -0.85]:
		_boite(p, Vector3(0.1, fe[3] - fe[2] + 0.2, 0.2), Transform3D(Basis(), Vector3(fx, (fe[2] + fe[3]) * 0.5, 1.82)), m_poutres_h)
	# double porte (deux vantaux sur charnière) : 1,6 m × 1,95 m, blocage de collision tant qu'elle est fermée
	var ha := _vantail(p, Vector3(0.55, 0.0, 1.8), 0.8, 1.95, 1.0)
	var hb := _vantail(p, Vector3(2.15, 0.0, 1.8), 0.8, 1.95, -1.0)
	ip.vantaux.append([ha, -1.75])
	ip.vantaux.append([hb, 1.75])
	_bloc_porte(ip, p, Vector3(1.35, 1.0, 1.8), Vector3(1.6, 2.0, 0.3))
	# dalle de seuil
	_bloc(p, Vector3(2.0, 0.08, 0.7), 4470, Vector3(1.35, 0.03, 2.25), m_brute, 0.0, 0.3, 0.2, 0.04)
	# cheminée au-dessus de la hotte (la hotte et le foyer sont dans l'intérieur)
	_pile(p, Vector3(-0.8, 2.3, -1.5), Vector3(0.7, 1.6, 0.7), 4322, m_brute, false, 1.0)
	_fumee(p, Vector3(-0.8, 3.2, -1.5))
	# torche à gauche de la porte, au dehors
	_torche_murale(p, Vector3(0.2, 1.5, 1.93), 1.0, false)
	# doublage intérieur (pierre sèche, matière d'intérieur) et mobilier : après le chargement
	_differer(ib, func() -> void:
		for sx in [-1.0, 1.0]:
			var k := 0
			for t in tronc:
				ib.bx(Vector3(sx * 2.155, t[2] * 0.5, (t[0] + t[1]) * 0.5), Vector3(0.1, t[2], t[1] - t[0]), "seche")   # doublage plat : la texture de pierre (64 texels/m) porte les joints ; l'ancien `pile` ne posait aucun bloc (épaisseur en X < 0,2 m) et laissait voir la pierre du dehors
				k += 1
		ib.bx(Vector3(0, 1.2, -1.7), Vector3(4.2, 2.4, 0.1), "seche")
		for x in [-2.4, 0.0, 2.4]:      # contreforts côté pièce : matière d'intérieur, sans neige
			ib.pile(Vector3(x, 1.0, -1.5), Vector3(0.6, 2.0, 0.3), 4310 + int(x), "brute")
		ib.fenetre_cadre(-1.4, (fe[2] + fe[3]) * 0.5, 1.72, 1.0, 0.5, (fe[3] - fe[2]) * 0.5)
		ib.contenu("forge")
		ib.finir())
	_emprise(p, Vector2(2.6, 2.6), Vector2(0, -0.3), ip)
	return p

func _puits(centre: Vector3) -> void:
	var p := _pivot(centre, 0.3)
	# margelle : deux rangs de moellons posés en cercle (collision d'origine : cylindre)
	var forme := CylinderShape3D.new()
	forme.radius = 1.0
	forme.height = 0.85
	_collision(p, forme, Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3.ZERO)
	var r := RandomNumberGenerator.new()
	r.seed = 4401
	for rang in 2:
		var n := 11
		for i in n:
			var a := TAU * (i + rang * 0.5) / n + r.randf_range(-0.05, 0.05)
			var pos := Vector3(sin(a) * 0.98, 0.2 + rang * 0.4, cos(a) * 0.98)
			_bloc(p, Vector3(0.62, 0.42, 0.42), r.randi(), pos, m_brute, a, 0.5 if rang == 1 else 0.0, 0.2, 0.08)
	_cylindre(p, 0.78, 0.78, 0.04, Transform3D(Basis(), Vector3(0, 0.78, 0)), m_eau, 8)
	for x in [-1.05, 1.05]:
		_poteau(p, Vector3(x, 0, 0), 0.1, 2.0, m_poutres)
	_cylindre(p, 0.09, 0.09, 2.3, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.7, 0)), m_poutres_h, 8)
	_pan(p, Vector3(0, 2.4, 0), Vector3(0, -0.55, 0.85), 2.7, 4402, 2.2, false)
	_pan(p, Vector3(0, 2.4, 0), Vector3(0, -0.55, -0.85), 2.7, 4403, 2.2, false)
	_cylindre(p, 0.16, 0.13, 0.25, Transform3D(Basis(), Vector3(0.3, 1.25, 0)), m_poutres, 8)
	_boite(p, Vector3(0.02, 0.4, 0.02), Transform3D(Basis(), Vector3(0.3, 1.5, 0)), m_cuir)   # corde du seau

func _brasero(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	_cylindre(p, 0.35, 0.45, 0.8, Transform3D(Basis(), Vector3(0, 0.4, 0)), m_pierre_fine, 8, true)
	_cylindre(p, 0.6, 0.35, 0.3, Transform3D(Basis(), Vector3(0, 0.95, 0)), m_fer, 8)
	_boite(p, Vector3(0.6, 0.06, 0.6), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 1.08, 0)), m_braises)
	_feu(p, Vector3(0, 1.12, 0), 1.6, 2.4, 11.0)
	# poteau sculpté octogonal sur un socle de pierre
	_bloc(p, Vector3(0.75, 0.34, 0.75), 4510, Vector3(1.6, 0.05, -0.6), m_brute, 0.3, 0.4, 0.2, 0.07)
	_cylindre(p, 0.16, 0.2, 3.6, Transform3D(Basis(), Vector3(1.6, 1.8, -0.6)), m_poutres, 8, true)
	for i in 3:
		_boite(p, Vector3(0.44, 0.22, 0.44), Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(1.6, 1.4 + i * 0.85, -0.6)), m_poutres_h)

## Lot L7 : pieux, lisses, meules de foin et séchoir en modules Blender (mobilier_village.py) fondus avec le bâti ; mêmes positions et
## mêmes collisions qu'avant (lisses basses solides, pieux et meules sans collision).
func _enclos(centre: Vector3, lacet := 0.0) -> Node3D:
	var p := _pivot(centre, lacet)
	var demi := Vector2(3.5, 2.5)
	var r := RandomNumberGenerator.new()
	r.seed = 6610
	for x in range(-7, 8):
		for z in [-demi.y, demi.y]:
			if x % 2 == 0 and not (z > 0 and absi(x) < 2):
				MobilierVillage.poser_dans(self, p, "enclos_poteau", Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(x * 0.5, 0, z)))
	for z in range(-5, 6):
		for x in [-demi.x, demi.x]:
			if z % 2 == 0:
				MobilierVillage.poser_dans(self, p, "enclos_poteau", Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(x, 0, z * 0.5)))
	for y in [0.5, 1.0]:
		var lisses := [[Vector3(0, y, -demi.y), demi.x * 2, 0.0], [Vector3(-demi.x, y, 0), demi.y * 2, PI * 0.5], [Vector3(demi.x, y, 0), demi.y * 2, PI * 0.5]]
		for cote in [-1.0, 1.0]:
			lisses.append([Vector3(cote * 2.4, y, demi.y), 2.2, 0.0])
		for l: Array in lisses:
			var b := Basis(Vector3.UP, float(l[2]))
			MobilierVillage.poser_dans(self, p, "enclos_lisse", Transform3D(b * Basis.from_scale(Vector3(float(l[1]), 1.0, 1.0)), l[0]))
			if y < 0.6:
				_collision(p, BoxShape3D.new(), Transform3D(Basis(), l[0]), Vector3(float(l[1]), 0.1, 0.1) if l[2] == 0.0 else Vector3(0.1, 0.1, float(l[1])))
	# meules de foin et séchoir à peaux
	for pos in [Vector3(-2.0, 0, -1.2), Vector3(-0.6, 0, -1.6), Vector3(1.8, 0, -1.0)]:
		MobilierVillage.poser_dans(self, p, "meule_foin", Transform3D(Basis(Vector3.UP, pos.x * 1.3), pos))
	MobilierVillage.poser_dans(self, p, "sechoir_peaux", Transform3D(Basis(), Vector3(0, 0, demi.y + 2.2)))
	return p

## Tonneau cerclé (module tonneau_c de mobilier_village.py, lot L7) ; même collision qu'avant (cylindre r 0,3 x 0,8).
func _tonneau(parent: Node3D, pos: Vector3) -> void:
	MobilierVillage.poser_dans(self, parent, "tonneau_c", Transform3D(Basis(Vector3.UP, pos.x * 2.1), pos))
	var forme := CylinderShape3D.new()
	forme.radius = 0.3
	forme.height = 0.8
	_collision(parent, forme, Transform3D(Basis(), pos + Vector3(0, 0.4, 0)), Vector3.ZERO)

func _accessoires() -> void:
	var racine := _pivot(Vector3.ZERO, 0.0)
	for pos in [Vector3(-7.4, 0, -9.0), Vector3(-6.7, 0, -9.4), Vector3(13.5, 0, 3.2), Vector3(-14.5, 0, 9.0)]:
		_tonneau(racine, pos)
	for pos in [Vector3(7.5, 0, -8.6), Vector3(-13.2, 0, 2.0), Vector3(3.0, 0, 16.5)]:
		var t := rng.randf_range(0.5, 0.75)
		_boite(racine, Vector3(t, t, t), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos + Vector3(0, t * 0.5, 0)), m_poutres, true)
		# coffre ferré : cerclage de fer
		_boite(racine, Vector3(t + 0.02, 0.06, t + 0.02), Transform3D(Basis(Vector3.UP, 0.0), pos + Vector3(0, t * 0.5, 0)), m_fer)
	# tas de bois de chauffage contre les maisons
	for base in [Vector3(-7.6, 0, -15.6), Vector3(8.6, 0, 9.8)]:
		for rang in 3:
			for k in 6 - rang:
				var pos: Vector3 = base + Vector3((k + rang * 0.5) * 0.3, 0.14 + rang * 0.26, 0)
				_cylindre(racine, 0.13, 0.13, 1.1, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos), m_ecorce, 6)
		_collision(racine, BoxShape3D.new(), Transform3D(Basis(), base + Vector3(0.8, 0.4, 0)), Vector3(2.0, 0.8, 1.1))
