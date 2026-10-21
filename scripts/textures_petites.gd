class_name TexturesPetites
## Lot « petites textures » : matières du bâti PS1 (shader ps1_bati, 64 texels/m) qui n'existent pas dans PeintureBati :
## roche des menhirs / du tertre / des abords (`roche_e`) et os des offrandes (`os_e`, même dessin que l'os de la crypte).
## Précalculées par outils/generer_petites.gd dans assets/petites/<nom>.res (+ `_relief.res`), repli : calcul à la volée.
## Les matériaux passent par TexturesBati.materiau_e (neige `neige_e`, fondu 64 -> 32 texels/m) : rien à modifier dans les
## fichiers du bâti, le cache de TexturesBati est simplement alimenté ici.

const DOSSIER := "res://assets/petites/"

static func fabriques() -> Dictionary:
	return {
		"roche_e": func() -> Array: return PeintureBati._net(PeintureBati.roche(5211, 256, 5, 1.0, 1.0, 2)),
		"os_e": func() -> Array: return [CrypteTextures.os_image(), null],
	}

## Alimente le cache de TexturesBati pour `nom` (une seule fois ; refait après TexturesBati.vider()).
static func _charge(nom: String) -> void:
	if TexturesBati._cache.has(nom):
		return
	var base: Texture2D
	var rel: Texture2D = null
	if ResourceLoader.exists(DOSSIER + nom + ".res"):
		base = load(DOSSIER + nom + ".res")
		if ResourceLoader.exists(DOSSIER + nom + "_relief.res"):
			rel = load(DOSSIER + nom + "_relief.res")
	else:
		var r: Array = (fabriques()[nom] as Callable).call()
		base = PeintureBati.avec_mips(r[0])
		if r[1] != null:
			rel = PeintureBati.relief_mips(r[1])
	TexturesBati._cache[nom] = [base, rel if rel != null else TexturesBati.relief_neutre()]

static func m_roche_e(teinte := Color.WHITE) -> ShaderMaterial:
	_charge("roche_e")
	return TexturesBati.materiau_e("roche_e", teinte)

static func m_os_e(teinte := Color.WHITE) -> ShaderMaterial:
	_charge("os_e")
	return TexturesBati.materiau_e("os_e", teinte, 0.0)

## Écrit assets/petites/*.res (appelé par outils/generer_petites.gd).
static func cuire() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var f := fabriques()
	for nom: String in f:
		var r: Array = (f[nom] as Callable).call()
		ResourceSaver.save(PeintureBati.avec_mips(r[0]), DOSSIER + nom + ".res")
		if r[1] != null:
			ResourceSaver.save(PeintureBati.relief_mips(r[1]), DOSSIER + nom + "_relief.res")
