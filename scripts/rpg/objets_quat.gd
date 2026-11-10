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
##   "echelle_quat": 1.2        facteur sur la taille réelle du prop ;
##   "eclat_quat": 1.8          multiplie toutes les couleurs de sommet (métal clair : coupe d'argent sur l'atlas de fer sombre).
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

## Prop texturé pq_* converti du même modèle que le prop .dat `ancien` (champ « ancien » du catalogue), "" sinon.
static var _par_ancien := {}
static func pq_de_ancien(ancien: String) -> String:
	_verrou.lock()
	if _par_ancien.is_empty():
		for e: Dictionary in PropsQuat.catalogue().values():
			if String(e.get("ancien", "")) != "":
				_par_ancien[String(e["ancien"])] = String(e["id"])
		_par_ancien[""] = ""
	var r := String(_par_ancien.get(ancien, ""))
	_verrou.unlock()
	return r

static func a(oid: String) -> bool:
	return id_de(oid) != ""

## Teinte de recoloration de la fiche (alpha 0 = aucune).
static func teinte_de(oid: String) -> Color:
	var t := String(Inventaire.objet(oid).get("teinte_quat", ""))
	return Color(t) if t != "" else Color(0, 0, 0, 0)

static func echelle_de(oid: String) -> float:
	return float(Inventaire.objet(oid).get("echelle_quat", 1.0))

## Contexte « objet » (au sol, lâché, étal, studio, aperçu) : matériau ps1 de PropsQuat (contexte crypte : sans neige de texture)
## dupliqué une fois par atlas avec `neige_tient` = 0 — un objet posé ou lâché dehors n'a pas de calotte de neige procédurale
## (comme les glb d'objets d'avant) ; les contextes « interieur » / « exterieur » gardent les matériaux partagés du décor.
static var _mats_objet := {}
static func materiau_objet(m: Material) -> Material:
	if not m is ShaderMaterial:
		return m
	_verrou.lock()
	var r: Material = _mats_objet.get(m.get_instance_id())
	_verrou.unlock()
	if r != null:
		return r
	var d := (m as ShaderMaterial).duplicate() as ShaderMaterial
	d.set_shader_parameter("neige_tient", 0.0)
	Palette.suivre(d)
	_verrou.lock()
	_mats_objet[m.get_instance_id()] = d
	_verrou.unlock()
	return d

## Maillage de l'objet (prop pq_* de sa fiche, teinte appliquée), pivot au pied, taille réelle ; null si pas de prop. En cache.
## `contexte` : « objet » (défaut, sans neige), « interieur », « exterieur » ou « crypte » (PropsQuat.materiau).
## `pq_force` : un autre prop que celui de la fiche (ObjetsVivants : le prop texturé du MÊME modèle que le décor posé, ex. q_vase_4 ->
## pq_vase_4 pour une cruche), avec la teinte / l'éclat de la fiche.
static func maillage(oid: String, contexte := "objet", pq_force := "") -> ArrayMesh:
	var pq := id_de(oid)
	if pq == "":
		return null
	if pq_force != "" and PropsQuat.existe(pq_force):
		pq = pq_force
	var t := teinte_de(oid)
	var ec := float(Inventaire.objet(oid).get("eclat_quat", 1.0))
	var objet := contexte == "objet"
	var base := PropsQuat.maillage(pq, "crypte" if objet else contexte)
	if base == null or (t.a == 0.0 and ec == 1.0 and not objet):
		return base
	var cle := "%s:%s:%s:%.2f" % [pq, contexte, t.to_html(), ec]
	_verrou.lock()
	var m: ArrayMesh = _cache.get(cle)
	_verrou.unlock()
	if m != null:
		return m
	m = ArrayMesh.new()
	for s in base.get_surface_count():
		var arr := base.surface_get_arrays(s)
		var cols: PackedColorArray = recolorer(arr[Mesh.ARRAY_COLOR], t) if t.a > 0.0 else (arr[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
		if ec != 1.0:
			for k in cols.size():
				cols[k] = Color(cols[k].r * ec, cols[k].g * ec, cols[k].b * ec, cols[k].a)
		arr[Mesh.ARRAY_COLOR] = cols
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(s, materiau_objet(base.surface_get_material(s)) if objet else base.surface_get_material(s))
	_verrou.lock()
	_cache[cle] = m
	_verrou.unlock()
	return m

## Couleurs de sommet TEINTÉES -> teinte `t` (luminance gardée) : seuls les sommets saturés de la teinte DOMINANTE du prop (liquide
## d'une fiole, couverture d'un livre) changent ; bouchon, verre gris, ferrures et bois gardent leur couleur. Couleurs de sommet
## linéaires (glb) : `t` (sRVB de la fiche) passe en linéaire.
const ECART_TEINTE := 0.07
static func recolorer(cols: Variant, t: Color) -> PackedColorArray:
	var c: PackedColorArray = cols if cols is PackedColorArray else PackedColorArray()
	var r := c.duplicate()
	var dom := teinte_dominante(c)
	if dom < 0.0:
		return r
	var tl := t.srgb_to_linear()
	var lt := tl.get_luminance()
	for k in r.size():
		var v: Color = r[k]
		if not _de_la_teinte(v, dom):
			continue
		var n := tl * (v.get_luminance() / maxf(lt, 0.001))
		r[k] = Color(clampf(n.r, 0, 1), clampf(n.g, 0, 1), clampf(n.b, 0, 1), v.a)
	return r

static func _de_la_teinte(v: Color, dom: float) -> bool:
	if v.s < SEUIL_TEINTE:
		return false
	var d := absf(v.h - dom)
	return minf(d, 1.0 - d) <= ECART_TEINTE

## Teinte (0-1) la plus fréquente parmi les sommets saturés (cases de 1/24), -1 si aucun.
static func teinte_dominante(c: PackedColorArray) -> float:
	var cases := PackedInt32Array()
	cases.resize(24)
	var somme := PackedFloat32Array()
	somme.resize(24)
	for v in c:
		if v.s >= SEUIL_TEINTE:
			var i := int(v.h * 24.0) % 24
			cases[i] += 1
			somme[i] += v.h
	var best := -1
	for i in 24:
		if cases[i] > 0 and (best < 0 or cases[i] > cases[best]):
			best = i
	return somme[best] / cases[best] if best >= 0 else -1.0

## Nœud prêt à poser (pivot au pied, centré), échelle de la fiche appliquée ; null si l'objet n'a pas de prop.
static func noeud(oid: String, contexte := "objet") -> MeshInstance3D:
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
static func morceaux(oid: String, contexte := "interieur", pq_force := "") -> Array:
	var m := maillage(oid, contexte, pq_force)
	if m == null:
		return []
	var e := echelle_de(oid) if pq_force == "" or pq_force == id_de(oid) else 1.0
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
