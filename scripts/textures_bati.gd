class_name TexturesBati
## Lot 5 (pierre et bâtiments), 2e passe : matériaux « bâti ». Les textures sont PEINTES et cuites hors ligne
## par `PeintureBati` (`outils/cuire_bati.gd` → `assets/bati/<nom>.res` + `<nom>_relief.res`, mipmaps « vote de
## couleur ») ; ici on ne fait que les charger (repli : génération à la volée si le fichier manque) et les
## brancher sur le shader `ps1_bati` (32 texels/m, fondu tramé vers 16 texels/m, relief sur la normale).
## Anciens générateurs d'amas (pierre_seche, roche_brute, planches…) : remplacés par PeintureBati.

const SHADER := preload("res://shaders/ps1_bati.gdshader")

static var _cache := {}
static var _neutre: ImageTexture

## Relief neutre (pente nulle) pour les matières sans relief.
static func relief_neutre() -> ImageTexture:
	if _neutre == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.set_pixel(0, 0, Color(0.5, 0.5, 0.5))
		_neutre = ImageTexture.create_from_image(img)
	return _neutre

## [albédo, relief] par nom (cache). Relief neutre si la matière n'en a pas.
static func charge(nom: String) -> Array:
	if not _cache.has(nom):
		var chemin := PeintureBati.DOSSIER + nom + ".res"
		var base: Texture2D
		var rel: Texture2D = null
		if ResourceLoader.exists(chemin):
			base = load(chemin)
			if ResourceLoader.exists(PeintureBati.DOSSIER + nom + "_relief.res"):
				rel = load(PeintureBati.DOSSIER + nom + "_relief.res")
		else:
			var r: Array = (PeintureBati.fabriques()[nom] as Callable).call()
			base = PeintureBati.avec_mips(r[0])
			if r[1] != null:
				rel = PeintureBati.relief_mips(r[1])
		_cache[nom] = [base, rel if rel != null else relief_neutre()]
	return _cache[nom]

static func tex(nom: String) -> Texture2D:
	return charge(nom)[0]

## Matériau PS1 « bâti » par nom de texture. `texels` : 32 (défaut) ou 64 (petits détails).
static func materiau(nom: String, teinte := Color.WHITE, texels := 32.0, force_relief := 0.8) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var c := charge(nom)
	m.set_shader_parameter("tex_base", c[0])
	m.set_shader_parameter("tex_relief", c[1])
	var n := charge("neige")
	m.set_shader_parameter("tex_neige", n[0])
	m.set_shader_parameter("tex_neige_relief", n[1])
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("texels_par_m", texels)
	m.set_shader_parameter("relief", force_relief if (c[1] != relief_neutre()) else 0.0)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

static func vider() -> void:
	_cache.clear()
	_neutre = null

# --- les matières du jeu -----------------------------------------------------------------------------------

static func m_pierre_seche(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("pierre_seche", teinte)

## Pierre à petits moellons (assises de 6 à 10 texels) : puits, foyers, marches, contreforts, cheminées.
static func m_pierre_fine(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("pierre_fine", teinte)

static func m_roche(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("roche", teinte)

## Pierre brute sans assises (blocs isolés : soubassement, contreforts, margelle) : chaque bloc est UNE pierre.
static func m_pierre_brute(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("pierre_brute", teinte)

static func m_planches(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("planches_h", teinte)

static func m_bois_debout(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("planches_v", teinte)

## Rondins : UV du maillage en mètres (fil du bois dans le sens de la longueur).
static func m_rondins(teinte := Color.WHITE) -> ShaderMaterial:
	var m := materiau("rondins", teinte, 32.0, 0.9)
	m.set_shader_parameter("uv_metres", true)
	return m

static func m_bout_rondin(teinte := Color.WHITE) -> ShaderMaterial:
	var m := materiau("bout_rondin", teinte, 64.0, 0.0)
	m.set_shader_parameter("uv_metres", true)
	return m

static func m_fer(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("fer", teinte)

static func m_cuir(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("cuir", teinte)

static func m_foin(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("foin", teinte)

## Tourbe et racines : lèvre du toit (alpha de sommet 1) sous la neige (alpha 0).
static func m_tourbe(teinte := Color.WHITE) -> ShaderMaterial:
	return materiau("tourbe", teinte)

static func m_braises() -> ShaderMaterial:
	var m := materiau("braises")
	m.set_shader_parameter("emission", Color(1.6, 0.6, 0.15))
	m.set_shader_parameter("emission_texture", true)
	return m

static func m_fenetre() -> ShaderMaterial:
	var m := materiau("fenetre")
	m.set_shader_parameter("uv_maillage", true)   # le vitrage est un quad : la tuile 18 × 12 le couvre exactement
	m.set_shader_parameter("emission", Color(1.4, 0.92, 0.42))
	m.set_shader_parameter("emission_texture", true)
	return m

## Écorce des arbres (lot 2, inchangée), 16 texels/m, sans fondu ni relief.
static func m_ecorce(teinte := Color.WHITE) -> ShaderMaterial:
	if not _cache.has("ecorce"):
		_cache["ecorce"] = [PeintureBati.avec_mips(TexturesArbres.ecorce_epicea_image()), relief_neutre()]
	var m := materiau("neige", teinte, 16.0, 0.0)
	m.set_shader_parameter("tex_base", _cache["ecorce"][0])
	m.set_shader_parameter("proche", Vector2(100000.0, 200000.0))
	return m

static func m_neige_toit() -> ShaderMaterial:
	return materiau("neige", Color.WHITE, 32.0, 0.9)

static func m_glace() -> ShaderMaterial:
	return materiau("neige", Color(0.78, 0.92, 1.05), 32.0, 0.3)
