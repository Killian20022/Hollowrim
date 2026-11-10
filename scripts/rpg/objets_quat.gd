class_name ObjetsQuat
## OBJETS RAMASSABLES EN PROPS QUATERNIUS TEXTURÉS PS1 (props/objets_quat, 2026-11-10) : une fiche du registre (data/objets/*.json)
## qui porte `"modele_quat": "pq_*"` est DESSINÉE avec ce prop du Fantasy Props MegaKit (PropsQuat, data/props_quaternius.json) :
## au sol (ObjetMonde.creer), lâché (Lacher -> ObjetMonde.tas), sur un étal (ObjetMonde.exposer), en studio (icônes, aperçu du menu),
## et sur les tables / étagères des intérieurs et du marché (ObjetsVivants.peupler : objets volables, tenus en main par E maintenu).
## Les DONNÉES de jeu (id, prix, poids, effets, champ `modele`) ne changent pas : seul le visuel change ; collision et ramassage
## gardent leurs formes d'avant.
## Champs facultatifs de la fiche :
##   "teinte_quat": "#rrggbb"   recolore les sommets TEINTÉS du prop (liquide d'une fiole, couverture d'un livre : couleur de sommet
##                              saturée) vers cette teinte, luminance gardée (potion de mana bleue sur la même fiole que le soin) ;
##   "echelle_quat": 1.2        facteur sur la taille réelle du prop.
## `-- --props-quat-ancien` : anciens modèles partout (glb d'objets, primitives, props .dat q_*) — captures « avant », mesures A/B.

const ARG_ANCIEN := "--props-quat-ancien"
## Saturation au-delà de laquelle un sommet est « teinté » (liquide, cuir peint) et suit teinte_quat.
const SEUIL_TEINTE := 0.22

static var actif := not (ARG_ANCIEN in OS.get_cmdline_user_args())
static var _cache := {}
static var _verrou := Mutex.new()

## Prop pq_* de l'objet `oid`, ou "" (pas de champ, ancien mode demandé, prop absent du catalogue).
static func id_de(oid: String) -> String:
	if not actif:
		return ""
	var pq := String(Inventaire.objet(oid).get("modele_quat", ""))
	return pq if pq != "" and PropsQuat.existe(pq) else ""

static func a(oid: String) -> bool:
	return id_de(oid) != ""

## Teinte de recoloration de la fiche (alpha 0 = aucune).
static func teinte_de(oid: String) -> Color:
	var t := String(Inventaire.objet(oid).get("teinte_quat", ""))
	return Color(t) if t != "" else Color(0, 0, 0, 0)

static func echelle_de(oid: String) -> float:
	return float(Inventaire.objet(oid).get("echelle_quat", 1.0))

## Maillage de l'objet (prop pq_* de sa fiche, teinte appliquée), pivot au pied, taille réelle ; null si pas de prop. En cache.
static func maillage(oid: String, contexte := "crypte") -> ArrayMesh:
	var pq := id_de(oid)
	if pq == "":
		return null
	var t := teinte_de(oid)
	var base := PropsQuat.maillage(pq, contexte)
	if base == null or t.a == 0.0:
		return base
	var cle := "%s:%s:%s" % [pq, contexte, t.to_html()]
	_verrou.lock()
	var m: ArrayMesh = _cache.get(cle)
	_verrou.unlock()
	if m != null:
		return m
	m = ArrayMesh.new()
	for s in base.get_surface_count():
		var arr := base.surface_get_arrays(s)
		arr[Mesh.ARRAY_COLOR] = recolorer(arr[Mesh.ARRAY_COLOR], t)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(s, base.surface_get_material(s))
	_verrou.lock()
	_cache[cle] = m
	_verrou.unlock()
	return m

## Couleurs de sommet saturées -> teinte `t` (luminance gardée, saturation de `t`) ; les autres (bois, verre gris, bouchon) intactes.
static func recolorer(cols: Variant, t: Color) -> PackedColorArray:
	var c: PackedColorArray = cols if cols is PackedColorArray else PackedColorArray()
	var r := c.duplicate()
	var lt := t.get_luminance()
	for k in r.size():
		var v: Color = r[k]
		if v.s < SEUIL_TEINTE:
			continue
		var l := v.get_luminance()
		var n := t * (l / maxf(lt, 0.01))
		r[k] = Color(clampf(n.r, 0, 1), clampf(n.g, 0, 1), clampf(n.b, 0, 1), v.a)
	return r

## Nœud prêt à poser (pivot au pied, centré), échelle de la fiche appliquée ; null si l'objet n'a pas de prop.
static func noeud(oid: String, contexte := "crypte") -> MeshInstance3D:
	var m := maillage(oid, contexte)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Quat_" + id_de(oid)
	mi.mesh = m
	mi.scale = Vector3.ONE * echelle_de(oid)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Morceaux [[arrays, Material]] (repère du prop : pivot au pied, échelle de la fiche) pour ObjetsVivants (MultiMesh).
static func morceaux(oid: String, contexte := "interieur") -> Array:
	var m := maillage(oid, contexte)
	if m == null:
		return []
	var e := echelle_de(oid)
	var res := []
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		if e != 1.0:
			var v: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			for k in v.size():
				v[k] *= e
			arr[Mesh.ARRAY_VERTEX] = v
		res.append([arr, m.surface_get_material(s)])
	return res
