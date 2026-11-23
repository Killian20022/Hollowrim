class_name RaisInterieur
extends Node3D
## Lumière intérieure v2 (2026-11-23, brief telekinesie_lumiere) : les rais de lumière d'un intérieur (shaders/rai_volume.gdshader).
## Une boîte cisaillée par ouverture (fenêtre vitrée, volets clos, porte, trou à fumée), posée par `Interieurs.finir()` dans le
## contenu de la maison (repère de l'intérieur). Toutes les 0,1 s, quand le contenu est visible :
## - DIRECTION : celle de l'astre (la lumière directionnelle du cycle : soleil de jour, lune la nuit) si l'ouverture lui fait face ;
##   sinon une lumière du ciel diffuse qui tombe en biais dans la pièce (aucune maison n'est sans rai de jour) ; fondu entre les deux ;
## - COULEUR et FORCE : la couleur de l'astre, réchauffée par la poussière (brume dorée), sa force ; le ciel bleuté selon la clarté
##   du jour ; la nuit, un clair de lune bleu, faible ; la porte ne laisse passer la lumière qu'ouverte (suit le vantail) ;
## - les appoints froids des fenêtres (OmniLight sans ombre, `Interieurs.FROID`) suivent le jour : plus forts et plus blancs de
##   jour, bleus et faibles la nuit (ils étaient fixes).
## Interrupteur : --sans-lumiere-v2 (aucun rai v2 : l'ancien rendu).

const SHADER := preload("res://shaders/rai_volume.gdshader")
const CHAUD := Color(1.0, 0.64, 0.33)     # la poussière dorée réchauffe la lumière du dehors
const CIEL := Color(0.86, 0.84, 0.8)        # jour diffus : neutre, à peine chaud (la poussière de la pièce)
const LUNE := Color(0.55, 0.66, 1.0)
const FORCES := {"fenetre": 1.0, "volets": 0.8, "porte": 0.85, "toit": 0.6}
const MOTIFS := {"fenetre": 1, "volets": 2, "porte": 0, "toit": 0}

static var _mat: ShaderMaterial
static var _cube: ArrayMesh

## [{c, n, t, w, h, type, mi, k (porte : ouverture lissée)}]
var ouvertures: Array = []
var ip: Interieur
var _acc := 1.0
var _cycle: Node
var _debug := OS.get_cmdline_user_args().has("--debug-lumiere-v2")

static func actif() -> bool:
	return not OS.get_cmdline_user_args().has("--sans-lumiere-v2")

static func materiau() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat

## Cube unité [0,1]³ (triangles, sans normales utiles : le shader est non éclairé).
static func cube() -> ArrayMesh:
	if _cube == null:
		var c := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]
		var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
		var v := PackedVector3Array()
		for f in faces:
			for i in [0, 1, 2, 0, 2, 3]:
				v.append(c[f[i]])
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		_cube = ArrayMesh.new()
		_cube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return _cube

## Construit les boîtes (hors de l'arbre : appelé dans le fil de construction des intérieurs).
func preparer(liste: Array) -> void:
	name = "RaisV2"
	for o: Dictionary in liste:
		var mi := MeshInstance3D.new()
		mi.mesh = cube()
		mi.material_override = materiau()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.set_instance_shader_parameter("motif", MOTIFS.get(o["type"], 0))
		mi.set_instance_shader_parameter("force", 0.0)
		mi.extra_cull_margin = 0.5
		add_child(mi)
		var oo := o.duplicate()
		oo["mi"] = mi
		oo["k"] = 0.0
		ouvertures.append(oo)

func _ready() -> void:
	var n := get_parent()
	while n != null and not (n is Interieur):
		n = n.get_parent()
	ip = n as Interieur
	_acc = 1.0

func _cycle_noeud() -> Node:
	if _cycle == null and ip != null and ip.village != null:
		var m: Node = ip.village.get("_monde")
		if m != null:
			_cycle = m.get("cycle")
	return _cycle

func _process(dt: float) -> void:
	if ip == null or not ip.racine.visible:
		return
	_acc += dt
	for o: Dictionary in ouvertures:        # la porte suit son vantail (fondu à l'ouverture)
		if o["type"] == "porte":
			o["k"] = move_toward(o["k"], 1.0 if ip.ouverte else 0.0, dt * 2.2)
	if _acc < 0.1:
		return
	_acc = 0.0
	maj()

## Clarté du jour vue de l'intérieur (0 nuit … 1 plein jour ; le crépuscule compte un peu).
static func jour_de(cy: Node) -> float:
	return clampf(maxf(float(cy.clarte()), float(cy.chaleur()) * 0.8), 0.0, 1.0)

## Met à jour direction, couleur et force de chaque rai (et les appoints froids des fenêtres).
func maj() -> void:
	var cy := _cycle_noeud()
	if cy == null:
		return
	if cy.process_mode == Node.PROCESS_MODE_DISABLED and cy.get("_lumiere_v2") == true:
		# temps figé (captures) : le cycle ne tourne plus, la brume intérieure suit quand même la caméra
		var dedans: bool = cy._camera_interieur()
		if dedans != cy._dans_interieur or absf(cy.interieur_k - (1.0 if dedans else 0.0)) > 0.01:
			cy._dans_interieur = dedans
			cy.interieur_k = 1.0 if dedans else 0.0
			cy.appliquer_brume()
	RenderingServer.global_shader_parameter_set("interieur_jour", jour_de(cy))
	var lum: DirectionalLight3D = cy.get("lumiere")
	var h: float = cy.get("heure")
	var clair: float = cy.clarte()
	var crep: float = cy.chaleur()
	var jour := clampf(maxf(clair, crep * 0.8), 0.0, 1.0)
	var est_soleil := h > 8.0 and h < 18.95
	var vers_l := Vector3(0, -1, 0)
	var e_astre := 0.0
	var c_astre := LUNE
	if lum != null and lum.visible:
		vers_l = (ip.global_basis.inverse() * (-lum.global_basis.z)).normalized()    # sens de propagation, repère de l'intérieur
		e_astre = lum.light_energy
		c_astre = lum.light_color
	var c_direct: Color = (c_astre * CHAUD) if est_soleil else (LUNE * 0.9)
	var i_direct := e_astre * (0.6 if est_soleil else 0.3)
	var i_ciel := lerpf(0.03, 0.22, jour)                 # nuit : un souffle de bleu ; jour couvert : rai pâle
	var c_ciel: Color = CIEL.lerp(Color(1.0, 0.8, 0.62), crep * 0.6)
	for o: Dictionary in ouvertures:
		var mi: MeshInstance3D = o["mi"]
		var n: Vector3 = o["n"]
		var typ: String = o["type"]
		var face := -vers_l.dot(n)
		var k := smoothstep(0.04, 0.3, face) if typ != "toit" else 1.0
		var d_ciel := (-n + Vector3(0, -0.62, 0)).normalized()
		var d := d_ciel.lerp(vers_l, k).normalized()
		if typ == "toit":
			d = Vector3(vers_l.x * 0.32, -1.0, vers_l.z * 0.32).normalized()     # par le trou du toit : presque d'aplomb, penché vers l'astre
			k = 1.0
		if d.y > -0.24:
			d = Vector3(d.x, -0.24, d.z).normalized()       # le rai descend toujours vers le sol
		if d.dot(-n) < 0.25 and typ != "toit":
			d = (d + (-n) * 0.5).normalized()
		var f: float = FORCES.get(typ, 1.0) * (i_direct * k + i_ciel * (1.0 - k))
		if typ == "porte":
			f *= o["k"]
		var col: Color = c_ciel.lerp(c_direct, k)
		# boîte : origine au coin bas gauche de l'ouverture (plan intérieur du mur), X = largeur, Y = hauteur, Z = rai
		var t: Vector3 = o["t"]
		var up := n.cross(t).normalized() if typ != "toit" else Vector3(0, 0, 1)
		if typ != "toit" and up.y < 0.0:
			up = -up
		var w: float = o["w"]
		var hh: float = o["h"]
		var c: Vector3 = o["c"]
		var y_bas := c.y - (hh * 0.5 if typ != "toit" else 0.0)
		var longueur := clampf((y_bas - Interieurs.F + 0.3) / maxf(-d.y, 0.05) + 0.6, 1.5, 11.0)
		var ux := t * w
		var vy := up * hh
		var org := c - ux * 0.5 - vy * 0.5
		var b := Basis(ux, vy, d * longueur)
		if b.determinant() < 0.0:
			b = Basis(-ux, vy, d * longueur)
			org = c + ux * 0.5 - vy * 0.5
		mi.transform = Transform3D(b, org)
		mi.set_instance_shader_parameter("dims", Vector3(w, hh, longueur))
		mi.set_instance_shader_parameter("couleur", Vector3(col.r, col.g, col.b))
		mi.set_instance_shader_parameter("force", f)
		mi.set_instance_shader_parameter("voile_k", lerpf(0.18, 1.0, k))
		mi.visible = f > 0.002
		if _debug:
			print("RAISV2 %s %s %s face=%.2f k=%.2f f=%.2f d=%s L=%.1f" % [ip.id, ip.nom, typ, face, k, f, d, longueur])
	_debug = false
	# appoints froids des fenêtres : jour plus clair et plus blanc, nuit bleue et faible
	for l in ip.lumieres:
		if float(l[2]) < 0.0 and is_instance_valid(l[0]):
			var ol: OmniLight3D = l[0]
			if not ol.has_meta("e_v1"):
				ol.set_meta("e_v1", float(l[1]))
			if ol.light_color.b > ol.light_color.r:      # appoint froid (FROID), pas une lueur chaude fixe
				ol.light_energy = float(ol.get_meta("e_v1")) * lerpf(0.55, 1.5, jour)
				ol.light_color = Interieurs.FROID.lerp(Color(0.9, 0.94, 1.0), jour * 0.6)
