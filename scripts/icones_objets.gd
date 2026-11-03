class_name IconesObjets
## ICÔNES D'OBJETS DESSINÉES DEPUIS LES MODÈLES 3D (outils/generer_icones.gd : rendu studio RenduObjet réduit en pixels nets,
## contour 1 px) : atlas assets/ui/icones/icones_16.png et icones_32.png, index icones.json. Remplacent les icônes pixel
## d'IconesCombat pour les OBJETS (menu Sac / Équipement / Magie, barre d'objets, coffre, boutique, forge, butin) ; les sorts et
## statuts gardent les icônes d'IconesCombat. Objet absent de l'atlas (pas de modèle : torche, clé de maison…) : null -> l'appelant
## garde l'ancienne icône (repli).
## API
##   IconesObjets.icone(id, 16) -> Texture2D ou null   (16 : registres, barre ; 32 : fiches détaillées)
##   IconesObjets.a(id) -> bool
##   IconesObjets.cle(id) -> String                     id de l'atlas (« epee » de la main -> epee_metal ; « id+2 » de la forge -> id)
##   IconesObjets.vider()                               à la fermeture (textures statiques, comme IconesCombat.vider)
## Régénérer : bash outils/generer_icones.sh

const DOSSIER := "res://assets/ui/icones/"
## Identifiants de main (EquipementMains) -> objet rendu.
const ALIAS := {"epee": "epee_metal"}

static var _index := {}       # id -> rang dans l'atlas
static var _colonnes := 16
static var _lu := false
static var _atlas := {}       # taille -> Texture2D
static var _cache := {}       # "taille:id" -> AtlasTexture

static func cle(id: String) -> String:
	var i := id.rfind("+")
	if i > 0 and id.substr(i + 1).is_valid_int():
		id = id.substr(0, i)
	var c := String(ALIAS.get(id, id))
	_lire()
	if not _index.has(c):
		# variante « enchante » d'une armure : même glb que sa base, donc même icône
		var b := String(Inventaire.objet(c).get("base", ""))
		if b != "" and _index.has(b):
			return b
	return c

static func _lire() -> void:
	if _lu:
		return
	_lu = true
	var chemin := DOSSIER + "icones.json"
	if not FileAccess.file_exists(chemin):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if not d is Dictionary:
		return
	_colonnes = int(d.get("colonnes", 16))
	var ids: Array = d.get("ids", [])
	for k in ids.size():
		_index[String(ids[k])] = k

static func a(id: String) -> bool:
	_lire()
	return _index.has(cle(id))

## Ids présents dans l'atlas (tests).
static func ids() -> Array:
	_lire()
	return _index.keys()

static func _atlas_de(taille: int) -> Texture2D:
	if _atlas.has(taille):
		return _atlas[taille]
	var chemin := DOSSIER + "icones_%d.png" % taille
	var tex: Texture2D = null
	if ResourceLoader.exists(chemin):
		tex = load(chemin) as Texture2D
	elif FileAccess.file_exists(chemin):      # atlas tout juste régénéré, pas encore importé
		var img := Image.load_from_file(ProjectSettings.globalize_path(chemin))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_atlas[taille] = tex
	return tex

## Icône `taille` px (16 ou 32) de l'objet `id`, ou null s'il n'a pas d'icône dessinée depuis son modèle.
static func icone(id: String, taille := 16) -> Texture2D:
	_lire()
	var c := cle(id)
	if not _index.has(c):
		return null
	var k := "%d:%s" % [taille, c]
	if _cache.has(k):
		return _cache[k]
	var atlas := _atlas_de(taille)
	if atlas == null:
		return null
	var n: int = _index[c]
	var t := AtlasTexture.new()
	t.atlas = atlas
	t.region = Rect2((n % _colonnes) * taille, (n / _colonnes) * taille, taille, taille)
	_cache[k] = t
	return t

## Icône 16 px d'un identifiant de MAIN ou de raccourci (barre d'objets) : objet dessiné s'il existe, sinon IconesCombat (sorts,
## main nue, torche…).
static func icone_main(id: String) -> Texture2D:
	if id != "":      # les sorts ne sont jamais dans l'atlas
		var t := icone(id, 16)
		if t != null:
			return t
	return IconesCombat.icone(id)

static func vider() -> void:
	_cache.clear()
	_atlas.clear()
