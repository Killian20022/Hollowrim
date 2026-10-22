class_name EnnemisNordiques
## Ennemis humanoïdes = archétypes nordiques + VARIANTE légère (brief_pnj_nordiques.md). Aucun nouveau corps :
##   draugrs (épée / archer / patrouille)  -> DraugrNordique  (bouclier ou non, arme, état de décomposition, archer = arc en main)
##   boss Svanhild / jarl gelé             -> DraugrNordique  « boss » (couronne, givre, plus imposant ; l'échelle vient de draugr.gd)
##   bandits vivants                       -> GuerrierNordique (cuirs sombres dépareillés, cape brune, casque cabossé ou tête nue, hache / épée)
##   archers bandits                       -> ChasseresseNordique (variante sombre ; PoseArcher de l'archétype joue la visée / le tir)
##   Hrafn                                 -> GuerrierNordique chef bandit (casque nasal, mante de fourrure brune)
## Les archétypes ne sont pas modifiés : les variantes sont des retouches APRÈS création (matériaux clonés avec une teinte, arme
## remplacée par un BoneAttachment3D sur hand_r, couronne sur Head). `--pnj-anciens` (argument utilisateur) remet Humain.creer.
##
##   EnnemisNordiques.creer({"type", "archer", "boss", "ident", "apparence"}) -> Node3D (null si --pnj-anciens)
## Contrat de Humain.creer conservé (Skeleton3D 65 os + AnimationPlayer « Animations »). Méta « armes_nordiques » : l'arme est déjà posée.

const PRISE := Transform3D(Basis(Vector3(-0.999251, -0.038334, -0.005288), Vector3(-0.014458, 0.24307, 0.969901), Vector3(-0.035895, 0.969252, -0.243442)), Vector3(-0.007936, 0.142938, 0.002241))
const FER := ["#1b1a1a", "#34302d", "#4f4741", "#6d6459"]
const ROUILLE := ["#2a1c14", "#3b2a1e", "#4f3a2a", "#5e5048"]
const BOIS := ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"]
const GIVRE := ["#5d7f98", "#8fb4cc", "#c4e0f0", "#eaf6ff"]
const OR_TERNE := ["#3a2c10", "#66501c", "#8e7330", "#b8993e"]

static var _clones := {}
static var _mat := {}
static var _anciens := -1

static func anciens() -> bool:
	if _anciens < 0:
		_anciens = 1 if OS.get_cmdline_user_args().has("--pnj-anciens") else 0
	return _anciens == 1

static func vider() -> void:
	_clones.clear()
	_mat.clear()

# ======================================================================================================== aiguillage
static func creer(spec := {}) -> Node3D:
	if anciens():
		return null
	var boss: String = spec.get("boss", "")
	var app: Dictionary = spec.get("apparence", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = String(spec.get("ident", "")).hash()
	var bandit: bool = app.has("tenue") and not bool(app.get("draugr", true))
	var n: Node3D
	if boss == "hrafn":
		n = _hrafn(rng)
	elif boss == "svanhild" or boss == "jarl":
		n = _boss_draugr(boss, rng)
	elif bandit and spec.get("archer", false):
		n = _bandit_archer(rng)
	elif bandit:
		n = _bandit(rng, app)
	else:
		n = _draugr(rng, bool(spec.get("archer", false)), String(spec.get("type", "sbire")))
	n.set_meta("armes_nordiques", true)
	n.set_meta("variante", String(n.get_meta("variante", "")))
	return n

static func _sq(n: Node3D) -> Skeleton3D:
	return n.find_child("Skeleton3D", true, false) as Skeleton3D

# ======================================================================================================== draugrs
## Draugr ordinaire : décomposition (teinte), bouclier ou non, arme (épée / hache / arc).
static func _draugr(rng: RandomNumberGenerator, archer: bool, type: String) -> Node3D:
	var etat := rng.randi() % 4
	var arme := "epee"
	var bouclier := "bras"
	if type == "sbire":
		bouclier = "" if rng.randf() < 0.7 else "dos"
		arme = ["epee", "hache", "epee"][rng.randi() % 3] as String
	elif rng.randf() < 0.3:
		arme = "hache"
	if archer:
		bouclier = ""
		arme = "arc"
	var n := DraugrNordique.creer({"bouclier": bouclier, "epee": arme == "epee"})
	var sq := _sq(n)
	var teintes: Array[Color] = [Color(1, 1, 1), Color(0.86, 1.02, 0.9), Color(0.72, 0.7, 0.68), Color(0.88, 0.98, 1.12)]
	_teinter_tout(n, teintes[etat])
	if arme == "hache" or arme == "masse":
		_poser_arme(sq, arme, rng)
	elif arme == "arc":
		_arc(sq)
	n.set_meta("variante", "draugr_%s_%s_%s" % [["os_sec", "moisi", "cendre", "gele"][etat], arme, bouclier])
	return n

## Chefs draugrs : couronne, givre, plus imposants (l'échelle ×1,1 est posée par draugr.gd / _regler_boss).
static func _boss_draugr(boss: String, rng: RandomNumberGenerator) -> Node3D:
	var n := DraugrNordique.creer({"bouclier": "bras" if boss == "jarl" else "", "epee": true})
	var sq := _sq(n)
	if boss == "svanhild":
		_teinter_tout(n, Color(0.82, 1.0, 1.28))
		_couronne(sq, "givre")
		_cape_royale(sq, Color(0.5, 0.66, 0.95))
	else:
		_teinter_tout(n, Color(0.92, 0.98, 1.1))
		_couronne(sq, "cornes")
		_cape_royale(sq, Color(0.55, 0.15, 0.15))
	n.set_meta("variante", "boss_" + boss)
	return n

# ======================================================================================================== bandits
const TENUES_BANDIT := [
	{"tun": Color(0.62, 0.5, 0.4), "pan": Color(0.75, 0.62, 0.5), "bot": Color(0.7, 0.62, 0.55), "cape": Color(1.55, 1.0, 0.6), "ch": Color(0.55, 0.42, 0.3)},
	{"tun": Color(0.5, 0.52, 0.5), "pan": Color(0.6, 0.55, 0.62), "bot": Color(0.6, 0.55, 0.5), "cape": Color(1.0, 0.95, 0.9), "ch": Color(0.8, 0.62, 0.4)},
	{"tun": Color(0.7, 0.58, 0.42), "pan": Color(0.5, 0.48, 0.5), "bot": Color(0.55, 0.45, 0.38), "cape": Color(1.2, 0.8, 0.55), "ch": Color(0.35, 0.3, 0.26)},
	{"tun": Color(0.45, 0.4, 0.38), "pan": Color(0.62, 0.52, 0.42), "bot": Color(0.5, 0.46, 0.44), "cape": Color(1.4, 0.9, 0.7), "ch": Color(0.7, 0.66, 0.6)},
]

static func _bandit(rng: RandomNumberGenerator, app: Dictionary) -> Node3D:
	var casque := rng.randf() < 0.45 or String(app.get("casque", "")) != ""
	var arme: String = ["hache", "epee", "hache", "masse"][rng.randi() % 4]
	var bouclier: String = ["", "", "dos"][rng.randi() % 3]
	var n := GuerrierNordique.creer({"casque": casque, "bouclier": bouclier, "epee": false})
	var sq := _sq(n)
	var t: Dictionary = TENUES_BANDIT[rng.randi() % TENUES_BANDIT.size()]
	_teinter_piece(sq, "tunique", t["tun"])
	_teinter_piece(sq, "pantalon", t["pan"])
	_teinter_piece(sq, "bottes", t["bot"])
	_teinter_piece(sq, "brassards", Color(0.7, 0.62, 0.55))
	_teinter_piece(sq, "mante", Color(0.8, 0.7, 0.6))
	_teinter_piece(sq, "Hair_Long", t["ch"])
	_teinter_piece(sq, "Hair_Beard", t["ch"])
	_teinter_acc(sq, Color(0.74, 0.68, 0.62), t["cape"])
	_poser_arme(sq, arme, rng)
	n.set_meta("variante", "bandit_%s_%s" % [arme, "casque" if casque else "tete_nue"])
	return n

static func _bandit_archer(rng: RandomNumberGenerator) -> Node3D:
	var n := ChasseresseNordique.creer({})
	var sq := _sq(n)
	var s := rng.randi() % 3
	var f: Color = [Color(0.62, 0.58, 0.55), Color(0.5, 0.52, 0.5), Color(0.66, 0.55, 0.45)][s]
	_teinter_piece(sq, "tunique", f)
	_teinter_piece(sq, "pantalon", f * Color(0.9, 0.9, 0.95))
	_teinter_piece(sq, "bottes", Color(0.7, 0.62, 0.55))
	_teinter_piece(sq, "brassards", Color(0.7, 0.62, 0.55))
	_teinter_piece(sq, "mante", Color(0.8, 0.7, 0.6))
	_teinter_piece(sq, "Hair_Long", [Color(0.4, 0.34, 0.3), Color(0.7, 0.5, 0.36), Color(0.28, 0.24, 0.22)][s])
	_teinter_acc(sq, Color(0.66, 0.62, 0.58), Color(0.7, 0.66, 0.62))
	n.set_meta("variante", "archer_bandit_%d" % s)
	return n

## Hrafn : chef bandit — GuerrierNordique casqué, mante de fourrure brune sombre, cape brune, lame à l'épée de l'archétype.
static func _hrafn(rng: RandomNumberGenerator) -> Node3D:
	var n := GuerrierNordique.creer({"casque": true, "bouclier": "dos", "epee": true})
	var sq := _sq(n)
	_teinter_piece(sq, "tunique", Color(0.55, 0.46, 0.38))
	_teinter_piece(sq, "pantalon", Color(0.55, 0.52, 0.52))
	_teinter_piece(sq, "bottes", Color(0.62, 0.55, 0.5))
	_teinter_piece(sq, "mante", Color(0.7, 0.55, 0.42))
	_teinter_piece(sq, "Hair_Long", Color(0.3, 0.27, 0.25))
	_teinter_piece(sq, "Hair_Beard", Color(0.3, 0.27, 0.25))
	_teinter_acc(sq, Color(0.8, 0.74, 0.68), Color(1.45, 0.85, 0.5))
	n.set_meta("variante", "hrafn")
	return n

# ======================================================================================================== teintes
## Clone partagé d'un matériau avec une teinte multipliée (même matériau + même teinte = même clone).
static func _cloner(m: ShaderMaterial, f: Color) -> ShaderMaterial:
	var k := "%d|%s" % [m.get_instance_id(), f.to_html()]
	if _clones.has(k):
		return _clones[k]
	var c := m.duplicate() as ShaderMaterial
	var te: Variant = m.get_shader_parameter("teinte")
	c.set_shader_parameter("teinte", (te if te is Color else Color.WHITE) * f)
	Palette.materiaux.append(c)
	Palette._appliquer(c, Palette._ps1_actif)
	_clones[k] = c
	return c

static func _teinter(mi: MeshInstance3D, f: Color, seulement := "") -> void:
	if mi == null or mi.mesh == null:
		return
	if mi.material_override is ShaderMaterial:
		mi.material_override = _cloner(mi.material_override, f)
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s)
		if m == null:
			m = mi.mesh.surface_get_material(s)
		if m is ShaderMaterial:
			var dec: bool = (m as ShaderMaterial).get_shader_parameter("decoupe") == true
			if seulement == "op" and dec or seulement == "dec" and not dec:
				continue
			mi.set_surface_override_material(s, _cloner(m, f))

static func _teinter_piece(sq: Skeleton3D, nom: String, f: Color) -> void:
	_teinter(sq.get_node_or_null(nom) as MeshInstance3D, f)

static func _teinter_acc(sq: Skeleton3D, op: Color, dec: Color) -> void:
	var mi := sq.get_node_or_null("accessoires") as MeshInstance3D
	_teinter(mi, op, "op")
	_teinter(mi, dec, "dec")

## Toutes les pièces visibles du corps (draugr : décomposition / givre).
static func _teinter_tout(n: Node3D, f: Color) -> void:
	for mi: MeshInstance3D in _sq(n).find_children("*", "MeshInstance3D", false, false):
		if mi.visible:
			_teinter(mi, f)

# ======================================================================================================== armes
static func _boite(st: SurfaceTool, c: Vector3, h: Vector3, rot := Basis.IDENTITY) -> void:
	for a in 3:
		for sgn: float in [-1.0, 1.0]:
			var u := Vector3.ZERO
			var v := Vector3.ZERO
			u[(a + 1) % 3] = 1.0
			v[(a + 2) % 3] = 1.0
			var n := Vector3.ZERO
			n[a] = sgn
			var hu: float = h[(a + 1) % 3]
			var hv: float = h[(a + 2) % 3]
			var p := [c + rot * (n * h[a] - u * hu - v * hv), c + rot * (n * h[a] + u * hu - v * hv), c + rot * (n * h[a] + u * hu + v * hv), c + rot * (n * h[a] - u * hu + v * hv)]
			var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			var ordre := [0, 1, 2, 0, 2, 3] if sgn > 0.0 else [0, 2, 1, 0, 3, 2]
			st.set_normal(rot * n)
			for i: int in ordre:
				st.set_uv(uvs[i])
				st.add_vertex(p[i])

## Coin de fer (tête de hache) : dos épais en x=0, tranchant fin en x=lg ; le tranchant (demi-hauteur h_tr) est plus long que le dos (h_dos).
static func _coin(st: SurfaceTool, o: Vector3, lg: float, h_dos: float, h_tr: float, ep: float) -> void:
	var P := [o + Vector3(0, -h_dos, -ep), o + Vector3(0, -h_dos, ep), o + Vector3(0, h_dos, ep), o + Vector3(0, h_dos, -ep),
		o + Vector3(lg, -h_tr, 0), o + Vector3(lg, h_tr, 0)]
	var T := [[0, 3, 2], [0, 2, 1], [0, 4, 5], [0, 5, 3], [1, 2, 5], [1, 5, 4], [0, 1, 4], [3, 5, 2]]
	var c := o + Vector3(lg * 0.4, 0, 0)
	for t: Array in T:
		var a: Vector3 = P[t[0]]
		var b: Vector3 = P[t[1]]
		var d: Vector3 = P[t[2]]
		var n := (b - a).cross(d - a).normalized()
		if n.dot((a + b + d) / 3.0 - c) < 0.0:
			var tmp := b
			b = d
			d = tmp
			n = -n
		st.set_normal(n)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(a)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(b)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(d)

static func _materiau(cle: String, pal: Array, em := Color.BLACK) -> ShaderMaterial:
	if not _mat.has(cle):
		var m := Palette.materiau(Palette.tex(cle, pal, 4, 0.7), Vector2(1, 3), Color.WHITE, true)
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
		if em != Color.BLACK:
			m.set_shader_parameter("emission", em)
		_mat[cle] = m
	return _mat[cle]

## Maillage d'arme : repère de l'épée du joueur (poignée à l'origine, pointe vers +Y).
static func _arme_mesh(nom: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var bois := SurfaceTool.new()
	bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fer := SurfaceTool.new()
	fer.begin(Mesh.PRIMITIVE_TRIANGLES)
	match nom:
		"hache":
			_boite(bois, Vector3(0, 0.34, 0), Vector3(0.016, 0.40, 0.016))
			_boite(fer, Vector3(0, 0.755, 0), Vector3(0.012, 0.02, 0.012))      # pointe de manche
			_coin(fer, Vector3(0.012, 0.68, 0), 0.15, 0.07, 0.15, 0.022)         # tranchant biseauté, plus long que le dos
			_boite(fer, Vector3(-0.02, 0.68, 0), Vector3(0.022, 0.04, 0.02))     # talon
		"masse":
			_boite(bois, Vector3(0, 0.30, 0), Vector3(0.016, 0.34, 0.016))
			for k in 4:
				var r := Basis(Vector3.UP, k * PI / 4.0)
				_boite(fer, Vector3(0, 0.67, 0), Vector3(0.012, 0.075, 0.045), r)
			_boite(fer, Vector3(0, 0.75, 0), Vector3(0.012, 0.03, 0.012))
		"epee_courte":
			_boite(bois, Vector3(0, 0.05, 0), Vector3(0.017, 0.07, 0.017))
			_boite(fer, Vector3(0, 0.125, 0), Vector3(0.07, 0.015, 0.016))
			_boite(fer, Vector3(0, 0.45, 0), Vector3(0.025, 0.31, 0.005))
	for st: SurfaceTool in [bois, fer]:
		st.generate_tangents()
		st.commit(mesh)
	mesh.surface_set_material(0, _materiau("arme_bois", BOIS))
	mesh.surface_set_material(1, _materiau("arme_fer", ROUILLE if nom != "epee_courte" else FER))
	return mesh

static func _poser_arme(sq: Skeleton3D, nom: String, rng: RandomNumberGenerator) -> void:
	var acc := BoneAttachment3D.new()
	acc.name = "Arme"
	acc.bone_name = "hand_r"
	sq.add_child(acc)
	if nom == "epee":
		var src: Node3D = (load("res://assets/modeles/joueur/epee_nordique.glb") as PackedScene).instantiate()
		src.transform = PRISE
		acc.add_child(src)
		var rouille := _materiau("arme_rouille", ROUILLE)
		for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = rouille
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _arme_mesh(nom)
	mi.transform = PRISE
	acc.add_child(mi)

## Arc en main (draugr archer) : le maillage « arc » du squelette-guerrier, même rig, repris sur le squelette humain.
static func _arc(sq: Skeleton3D) -> void:
	var src: Node3D = SqueletteGuerrier.creer({"arme": "arc"})
	var arc: MeshInstance3D = null
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) == "arc":
			arc = mi
	if arc != null:
		var copie := MeshInstance3D.new()
		copie.mesh = arc.mesh
		copie.skin = arc.skin
		copie.name = "arc"
		sq.add_child(copie)
		copie.skeleton = NodePath("..")
		var bois := _materiau("arc_bois", BOIS)
		for s in copie.mesh.get_surface_count():
			copie.set_surface_override_material(s, bois)
	src.free()

# ======================================================================================================== boss
## Couronne posée sur le casque (os Head) : givre = pointes fines et hautes ; cornes = diadème + deux cornes.
static func _couronne(sq: Skeleton3D, genre: String) -> void:
	var tete := sq.get_bone_global_rest(sq.find_bone("Head"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cen := Vector3(0.0, 1.835, -0.012)
	if genre == "givre":
		for i in 9:
			var a := TAU * i / 9.0
			var p := cen + Vector3(sin(a), 0.0, cos(a)) * 0.108
			var h := 0.15 if i % 2 == 0 else 0.095
			_boite(st, p + Vector3(0, h * 0.5, 0), Vector3(0.013, h * 0.5, 0.013), Basis(Vector3.UP, a))
		_boite(st, cen + Vector3(0, 0.01, 0), Vector3(0.112, 0.014, 0.112))
	else:
		for s: float in [-1.0, 1.0]:
			_boite(st, cen + Vector3(s * 0.15, 0.06, 0), Vector3(0.018, 0.075, 0.018), Basis(Vector3.BACK, s * -0.4))
			_boite(st, cen + Vector3(s * 0.21, 0.15, 0), Vector3(0.015, 0.07, 0.015), Basis(Vector3.BACK, s * -0.9))
		_boite(st, cen + Vector3(0, 0.01, 0), Vector3(0.115, 0.016, 0.115))
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, _materiau("couronne_" + genre, GIVRE if genre == "givre" else OR_TERNE, Color(0.25, 0.45, 0.6) if genre == "givre" else Color(0.08, 0.06, 0.02)))
	var acc := BoneAttachment3D.new()
	acc.name = "Couronne"
	acc.bone_name = "Head"
	sq.add_child(acc)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = tete.affine_inverse()
	acc.add_child(mi)

## Cape royale pourrie : un rideau d'étoffe fendu dans le dos (suit spine_03), pas de ressort (draugr = lambeaux raides).
static func _cape_royale(sq: Skeleton3D, couleur: Color) -> void:
	var rest := sq.get_bone_global_rest(sq.find_bone("spine_03"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# panneaux étagés (haut -> bas) légèrement déchirés, dans le dos (z < 0)
	var hauts := [1.50, 1.12, 0.72, 0.36]
	var larg := [0.20, 0.23, 0.21, 0.17]
	for i in 3:
		var y0: float = hauts[i]
		var y1: float = hauts[i + 1]
		_boite(st, Vector3(0, (y0 + y1) * 0.5, -0.17 - 0.015 * i), Vector3(larg[i], (y0 - y1) * 0.5, 0.008))
	st.generate_tangents()
	var mesh := st.commit()
	var cle := "cape_royale_" + couleur.to_html()
	if not _mat.has(cle):
		var m := Palette.materiau(Palette.tex(cle, ["#0e1018", "#1a1d29", "#262b3c", "#363c52"], 4, 0.8), Vector2(1, 3), couleur, true)
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
		_mat[cle] = m
	mesh.surface_set_material(0, _mat[cle])
	var acc := BoneAttachment3D.new()
	acc.name = "CapeRoyale"
	acc.bone_name = "spine_03"
	sq.add_child(acc)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = rest.affine_inverse()
	acc.add_child(mi)

## Position de la main qui tient l'arc (départ de la flèche), en repère monde ; Vector3.INF si le squelette n'a pas la main.
static func main_de_tir(modele: Node3D) -> Vector3:
	var sq := _sq(modele) if modele else null
	if sq == null:
		return Vector3.INF
	var i := sq.find_bone("hand_l")
	if i < 0:
		return Vector3.INF
	return sq.global_transform * sq.get_bone_global_pose(i).origin
