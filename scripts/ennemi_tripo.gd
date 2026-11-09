class_name EnnemiTripo
## Ennemis générés par Tripo (essai, branche essai/ennemis) : draugr guerrier, draugr archer, squelette guerrier, gobelin. MÊME squelette que les humains
## nordiques (65 os de homme_vetu.glb) donc mêmes clips (Humain.bibliotheque()), PiedsAuSol, Ragdoll… Modèles : sources_blender/scripts/tripo_ennemi_prep.py
## (allègement, texture 512) puis tripo_ennemi_rig.py (rig). Les armes Tripo sont RETIRÉES du modèle : on pose celles du jeu (épée, hache, masse, épée courte,
## arc) sur hand_r / hand_l. Yeux bleus : texels bleu franc de la texture rendus lumineux par le shader (voir SHADER_CODE).
## Actif avec l'argument utilisateur `--ennemis-tripo` ; sans lui le jeu est inchangé.
##   EnnemiTripo.creer("draugr" | "archer" | "squelette" | "gobelin", arme) -> Node3D (contrat de Humain.creer : Skeleton3D + AnimationPlayer « Animations »)
## Le gobelin est bâti à taille humaine (rig) puis réduit : méta « echelle_tripo » (0,667 -> ~1,2 m), appliquée par draugr.gd.

const MODELES := {
	"draugr": preload("res://assets/pnj/ennemis/tripo_draugr_rig.glb"),
	"archer": preload("res://assets/pnj/ennemis/tripo_archer_rig.glb"),
	"squelette": preload("res://assets/pnj/ennemis/tripo_squelette_rig.glb"),
	"gobelin": preload("res://assets/pnj/ennemis/tripo_gobelin_rig.glb"),
}
const ECHELLES := {"gobelin": 0.667}
const SHADER := preload("res://shaders/ps1_draugr.gdshader")
const LUEUR := Vector3(3.0, 5.4, 7.6)
## Réglage de clarté par modèle (le défaut Tripo : texture trop sombre sous le shader PS1).
const TEINTES := {"draugr": Color(0.95, 0.88, 0.8), "archer": Color(0.9, 0.9, 0.9), "squelette": Color(0.9, 0.9, 0.9), "gobelin": Color(0.95, 0.95, 0.95)}
## Agrandissement de l'arme (le draugr est plus massif que le joueur).
const ECH_ARME := {"draugr": 1.15, "archer": 1.0, "squelette": 1.0, "gobelin": 0.75}
const PRISE := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))
## Inclinaison de la lame autour de l'axe X de la main (degrés).
static var INCL := -35.0

static var _shader: Shader
static var _mats := {}
static var _centres := {}
static var _mx := Mutex.new()

static func actif() -> bool:
	return OS.get_cmdline_user_args().has("--ennemis-tripo")

static func _le_shader() -> Shader:
	if _shader == null:
		var s := Shader.new()
		var c := SHADER.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
		# yeux : texels bleu franc (r < 0,55, b > 0,9) lumineux, comme les sommets d'alpha < 1 du draugr ordinaire
		c = c.replace("float g = 1.0 - COLOR.a;", "float g = max(1.0 - COLOR.a, step(0.9, c.b) * step(c.r, 0.55) * step(c.r + 0.25, c.b));")
		s.code = c
		_shader = s
	return _shader

static func materiau(tex: Texture2D, id: String) -> ShaderMaterial:
	_mx.lock()
	var cle := "%s|%d" % [id, tex.get_rid().get_id()]
	var m: ShaderMaterial = _mats.get(cle)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = _le_shader()
		m.set_shader_parameter("tex_base", tex)
		m.set_shader_parameter("decoupe", false)
		m.set_shader_parameter("lueur", LUEUR)
		m.set_shader_parameter("appoint", DraugrNordique.APPOINT)
		m.set_shader_parameter("teinte", TEINTES.get(id, Color.WHITE))
		m.next_pass = GuerrierNordique.contour()
		Palette.suivre(m)
		Palette._appliquer(m, Palette._ps1_actif)
		_mats[cle] = m
	_mx.unlock()
	return m

static func vider() -> void:
	_mx.lock()
	_mats.clear()
	_centres.clear()
	_mx.unlock()

static func creer(id: String, arme := "") -> Node3D:
	var racine: Node3D = (MODELES[id] as PackedScene).instantiate()
	racine.name = "Tripo" + id.capitalize()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var corps: MeshInstance3D = null
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		corps = mi
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				mi.set_surface_override_material(s, materiau((src as BaseMaterial3D).albedo_texture, id))
		mi.extra_cull_margin = 0.5
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	var rd: SkeletonModifier3D = DraugrNordique.RAIDEUR.new()
	rd.name = "Raideur"
	if id == "gobelin":
		rd.set("voute_k", 4.0)         # démarche voûtée : le dos du modèle l'est déjà, la voûte s'ajoute aux clips
		rd.set("amortir", false)
	sq.add_child(rd)
	if arme == "arc":
		EnnemisNordiques._arc(sq)
	elif arme != "":
		_armer(sq, corps, id, arme)
	racine.set_meta("armes_nordiques", true)
	racine.set_meta("tripo_ennemi", id)
	if id == "draugr" or id == "archer":
		racine.set_meta("draugr_nordique", true)
	if ECHELLES.has(id):
		racine.set_meta("echelle_tripo", float(ECHELLES[id]))
	return racine

## Centre du poing droit du maillage (poids >= 0,5 sur hand_r), dans le repère de repos de hand_r.
static func centre_poing(sq: Skeleton3D, mi: MeshInstance3D, id: String) -> Vector3:
	_mx.lock()
	var deja: Variant = _centres.get(id)
	_mx.unlock()
	if deja != null:
		return deja
	var os_main := sq.find_bone("hand_r")
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var par := b.size() / maxi(v.size(), 1)
	var somme := Vector3.ZERO
	var n := 0
	for i in v.size():
		var p := 0.0
		for k in par:
			var nom: String = mi.skin.get_bind_name(b[i * par + k]) if mi.skin != null else ""
			if nom == "hand_r":
				p += w[i * par + k]
		if p >= 0.5:
			somme += v[i]
			n += 1
	var c := Vector3(-0.01, -0.08, 0.0)
	if n > 0:
		c = sq.get_bone_global_rest(os_main).affine_inverse() * (mi.transform * (somme / n))
	_mx.lock()
	_centres[id] = c
	_mx.unlock()
	return c

static func _armer(sq: Skeleton3D, corps: MeshInstance3D, id: String, arme: String) -> void:
	if arme == "epee":
		EnnemisNordiques._poser_arme(sq, "epee")
	else:
		EnnemisNordiques._poser_arme(sq, arme)
	var acc := sq.get_node("Arme") as BoneAttachment3D
	var a := acc.get_child(0) as Node3D
	var e: float = ECH_ARME.get(id, 1.0)
	var bs := PRISE.basis
	bs = Basis(Vector3.RIGHT, deg_to_rad(INCL)) * bs
	bs = bs.scaled(Vector3.ONE * e)
	var c := centre_poing(sq, corps, id)
	a.transform = Transform3D(bs, c - bs.y.normalized() * 0.04 * e)
