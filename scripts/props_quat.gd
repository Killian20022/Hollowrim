class_name PropsQuat
## Props du Fantasy Props MegaKit (Quaternius, CC0) en version TEXTURÉE PS1 (props/quaternius, 2026-11-10) : glb de
## assets/modeles/props_quat/<catégorie>/pq_*.glb produits par sources_blender/scripts/props_quaternius.py, catalogue
## data/props_quaternius.json (dimensions, collision, props actuels qu'ils peuvent remplacer).
## Les glb n'embarquent AUCUNE image : chaque surface porte un matériau nommé « pq_<atlas> » ; ce module pose à la place UN
## matériau partagé par (atlas, contexte) : shader ps1 du jeu (dehors : neige qui tient sur le dessus, double face), ps1_interieur
## (dedans : ambiante propre, UV du maillage) ou crypte (ps1 sans neige). Couleur de sommet = teinte x occlusion x pied (alpha 1).
## Usage :
##   var n := PropsQuat.instancier("pq_tonneau")                  # Node3D prêt à poser (origine au pied, centre de l'emprise)
##   var m := PropsQuat.maillage("pq_chaise", "interieur")        # ArrayMesh à matériaux partagés (MultiMesh, lots)
##   PropsQuat.infos("pq_coffre")                                 # entrée du catalogue (dimensions, collision, remplace…)
##   PropsQuat.corps("pq_coffre", parent, transform)              # StaticBody3D de la collision simple du catalogue

const CATALOGUE := "res://data/props_quaternius.json"
const TEXTURES := "res://assets/modeles/props_quat/textures/"
const CONTEXTES := ["exterieur", "interieur", "crypte"]

static var _cat := {}
static var _mats := {}
static var _maillages := {}
static var _verrou := Mutex.new()

static func catalogue() -> Dictionary:
	_verrou.lock()
	if _cat.is_empty():
		var f := FileAccess.open(CATALOGUE, FileAccess.READ)
		if f == null:
			push_error("PropsQuat : %s introuvable" % CATALOGUE)
		else:
			var d: Variant = JSON.parse_string(f.get_as_text())
			for e: Dictionary in (d["props"] if d is Dictionary else d):
				_cat[e["id"]] = e
	var r := _cat
	_verrou.unlock()
	return r

static func ids() -> Array:
	return catalogue().keys()

static func infos(id: String) -> Dictionary:
	return catalogue().get(id, {})

static func existe(id: String) -> bool:
	return catalogue().has(id)

## Texture d'atlas (filtre plus proche ; mipmaps seulement dedans, par ps1_interieur).
static func _texture(atlas: String) -> Texture2D:
	return load(TEXTURES + atlas + ".png") as Texture2D

## Matériau partagé d'un atlas (« pq_bois », « pq_fer_v »…) pour un contexte : un seul par paire, créé à la première demande.
static func materiau(atlas: String, contexte := "exterieur") -> Material:
	var cle := atlas + ":" + contexte
	_verrou.lock()
	var m: Material = _mats.get(cle)
	_verrou.unlock()
	if m != null:
		return m
	var tex := _texture(atlas)
	if contexte == "interieur":
		var mi := ShaderMaterial.new()
		mi.shader = Interieurs.SHADER
		mi.set_shader_parameter("tex_base", tex)
		mi.set_shader_parameter("tex_neige", tex)
		mi.set_shader_parameter("uv_maillage", true)
		mi.set_shader_parameter("relief", 0.0)
		mi.set_shader_parameter("proche", Vector2(40.0, 60.0))     # pas de tramage de mip (UV de trim : il mouchetait le plateau des tables)
		mi.set_shader_parameter("ambiant", Interieurs.AMBIANT)
		Palette.suivre(mi)
		m = mi
	else:
		var me := Palette.materiau(tex, Vector2.ONE, Color.WHITE, true)
		if contexte == "crypte":
			me.set_shader_parameter("tex_neige", tex)      # pas de neige sous terre
		m = me
	_verrou.lock()
	_mats[cle] = m
	_verrou.unlock()
	return m

static func _fichier(id: String) -> String:
	var e := infos(id)
	return String(e.get("fichier", "")) if not e.is_empty() else ""

## Maillage du prop, matériaux partagés posés (mis en cache par (id, contexte)).
static func maillage(id: String, contexte := "exterieur") -> ArrayMesh:
	var cle := id + ":" + contexte
	_verrou.lock()
	var mm: ArrayMesh = _maillages.get(cle)
	_verrou.unlock()
	if mm != null:
		return mm
	var chemin := _fichier(id)
	if chemin == "" or not ResourceLoader.exists(chemin):
		push_error("PropsQuat : prop inconnu ou glb absent : %s" % id)
		return null
	var sc := (load(chemin) as PackedScene).instantiate()
	var src: MeshInstance3D = sc if sc is MeshInstance3D else sc.find_children("*", "MeshInstance3D", true, false)[0]
	var base: Mesh = src.mesh
	mm = ArrayMesh.new()
	for s in base.get_surface_count():
		var arr := base.surface_get_arrays(s)
		mm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var nom := base.surface_get_material(s).resource_name if base.surface_get_material(s) else "pq_bois"
		mm.surface_set_material(s, materiau(nom, contexte))
	sc.free()
	_verrou.lock()
	_maillages[cle] = mm
	_verrou.unlock()
	return mm

## Nœud prêt à poser (MeshInstance3D, ombres coupées comme le reste du décor).
static func instancier(id: String, contexte := "exterieur") -> MeshInstance3D:
	var m := maillage(id, contexte)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Collision simple du catalogue (boîte / cylindre ; rien pour les petits objets) sous `parent`, à `t`.
static func corps(id: String, parent: Node3D, t: Transform3D) -> StaticBody3D:
	var c: Dictionary = infos(id).get("collision", {})
	var forme: Shape3D
	var y := 0.0
	match String(c.get("type", "aucune")):
		"boite":
			var b := BoxShape3D.new()
			var tl: Array = c["taille"]
			b.size = Vector3(tl[0], tl[1], tl[2])
			forme = b
			y = float(c["centre_y"])
		"cylindre":
			var cy := CylinderShape3D.new()
			cy.radius = float(c["rayon"])
			cy.height = float(c["hauteur"])
			forme = cy
			y = cy.height * 0.5
		_:
			return null
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.position.y = y
	sb.add_child(cs)
	sb.transform = t
	parent.add_child(sb)
	return sb

# ------------------------------------------------------------------------------------------------ essai (scène témoin)
## Scène témoin `-- --essai-props-quat` (captures seulement, rien n'est posé sans l'option) : un groupe de props TEXTURÉS sur la place
## (à côté des props actuels du marché) et un groupe dans un intérieur. Réglages : `--essai-pq-ext=x,z,lacet°` (point de vue dehors,
## le groupe est posé 4,5 m devant) et `--essai-pq-int=bat,x,z,lacet°` (repère du bâtiment, groupe 2,4 m devant).
## Entrées : [id, droite (m), devant (m), lacet (°), hauteur au-dessus du sol (m)].
const ESSAI_EXT := [["pq_etal", -0.9, 1.4, 180, 0.0], ["pq_tonneau", 1.25, 1.0, 0, 0.0], ["pq_tonneau_pommes", 2.0, 0.3, 30, 0.0],
	["pq_caisse", -2.6, 0.7, 15, 0.0], ["pq_cageot_carottes", -2.6, 0.7, 5, 0.7], ["pq_sac", 0.55, 0.1, 0, 0.0],
	["pq_banc", 0.0, -1.2, 10, 0.0], ["pq_seau_bois", 1.45, -0.4, 0, 0.0], ["pq_corde_2", -1.6, -0.6, 40, 0.0],
	["pq_support_tonneau", 3.2, 1.6, -20, 0.0], ["pq_bourse", 0.1, -1.2, 30, 0.45], ["pq_banniere", -3.8, 1.8, 160, 0.0]]
const ESSAI_INT := [["pq_grande_table", 0.0, 0.0, 0, 0.0], ["pq_chaise", -0.55, 0.75, 180, 0.0], ["pq_chaise", 0.6, -0.75, 10, 0.0],
	["pq_tabouret", 1.6, 0.4, 0, 0.0], ["pq_chope", -0.4, 0.15, 20, 0.76], ["pq_chope", 0.35, -0.2, 70, 0.76],
	["pq_assiette", -0.75, 0.2, 0, 0.76], ["pq_bougeoir_triple", 0.05, 0.0, 0, 0.76], ["pq_pile_livres", 0.95, 0.1, 15, 0.76],
	["pq_coffre", -1.9, -0.6, 80, 0.0], ["pq_tonneau", 2.1, -0.7, 0, 0.0], ["pq_seau_bois", 1.7, 0.95, 0, 0.0]]

static func _arg(nom: String, defaut: String) -> PackedStringArray:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--" + nom + "="):
			return String(a).get_slice("=", 1).split(",")
	return defaut.split(",")

static func essai(monde: Node) -> void:
	var e := _arg("essai-pq-ext", "46,36,-56")
	var p := Vector3(float(e[0]), 0, float(e[1]))
	var lacet := deg_to_rad(float(e[2]))
	var b := Basis(Vector3.UP, lacet)          # lacet 0 = vers -Z (convention des poses)
	var c := p + (-b.z) * 4.5
	var n := 0
	for x: Array in ESSAI_EXT:
		var mi := instancier(String(x[0]), "exterieur")
		if mi == null:
			continue
		var q := c + b.x * float(x[1]) + (-b.z) * float(x[2])
		q.y = float(monde.call("hauteur", q.x, q.z)) + float(x[4])
		monde.add_child(mi)
		mi.global_position = q
		mi.global_rotation = Vector3(0, lacet + PI + deg_to_rad(float(x[3])), 0)     # face au point de vue
		n += 1
	var i := _arg("essai-pq-int", "halle,0,3,0")
	var ip: Node3D = monde.get("village").call("interieur", i[0]) if monde.get("village") != null else null
	if ip != null:
		var bi := Basis(Vector3.UP, deg_to_rad(float(i[3])))
		var ci := Vector3(float(i[1]), 0, float(i[2])) + (-bi.z) * 2.4
		var sol: float = float(ip.get("sol_y"))
		for x: Array in ESSAI_INT:
			var mi := instancier(String(x[0]), "interieur")
			if mi == null:
				continue
			ip.add_child(mi)
			mi.position = ci + bi.x * float(x[1]) + (-bi.z) * float(x[2]) + Vector3(0, sol + float(x[4]), 0)
			mi.rotation = Vector3(0, deg_to_rad(float(i[3])) + PI + deg_to_rad(float(x[3])), 0)
			n += 1
	print("PropsQuat : essai, %d props posés (dehors %s, dedans %s)" % [n, e, i])
