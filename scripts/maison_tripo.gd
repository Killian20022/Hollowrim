class_name MaisonTripo
## ESSAI Tripo (branche essai/maison) : l'auberge « h2 » reçoit un extérieur Tripo (cottage nordique allégé, 3 500 tri, texture cuite 512 px)
## et un intérieur de taverne Tripo (3 000 tri, 512 px) à la place du bâti procédural. Emprise, porte, coque de collisions et données
## (data/batiments.json) restent celles de l'auberge : seule l'apparence change. `-- --sans-tripo` rend le bâti d'avant.
## Réglages d'ajustement : `--tripo-rot=°` (lacet du cottage), `--tripo-dx=m`, `--tripo-dz=m` (décalage), `--tripo-irot=°` (lacet de la taverne).
static var actif := not (OS.get_cmdline_user_args().has("--sans-tripo") or OS.get_cmdline_user_args().has("--h2-ancien"))
const EXT := "res://assets/essai_tripo/cottage.glb"
const INT := "res://assets/essai_tripo/taverne.glb"

static func arg(nom: String, defaut: float) -> float:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + nom + "="):
			return float(s.get_slice("=", 1))
	return defaut

## Passe un modèle au shader ps1 du jeu (double face, métal éteint) ; `neige` : le dessus (alpha de sommet 0) prend la texture de neige.
static func ps1(racine: Node, teinte := Color(1.25, 1.25, 1.25), double_face := true) -> void:
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				mi.set_surface_override_material(s, Palette.materiau(tex, Vector2.ONE, teinte, double_face))

static func aabb(n: Node3D) -> AABB:
	var r := AABB()
	var premier := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := n.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		r = b if premier else r.merge(b)
		premier = false
	return r

## Place `n` (enfant de `parent`) : boîte ajustée à `taille` (X, Y, Z), centre en XZ = `centre`, pied à `y`.
static func ajuster(n: Node3D, parent: Node3D, taille: Vector3, centre: Vector3, y: float, lacet_deg: float) -> void:
	parent.add_child(n)
	var tourne := absf(fmod(absf(lacet_deg), 180.0) - 90.0) < 1.0
	n.rotation.y = deg_to_rad(lacet_deg)
	n.scale = Vector3.ONE
	var b := aabb(n)
	var tx := b.size.z if tourne else b.size.x
	var tz := b.size.x if tourne else b.size.z
	n.scale = Vector3(taille.x / tx, taille.y / b.size.y, taille.z / tz)
	var c := b.get_center()
	var c2 := Basis(Vector3.UP, deg_to_rad(lacet_deg)) * (c * n.scale)
	n.position = Vector3(centre.x - c2.x, y - (b.position.y * n.scale.y), centre.z - c2.z)

static func exterieur(p: Node3D, L: float, W: float, y_pied: float) -> void:
	var n := (load(EXT) as PackedScene).instantiate() as Node3D
	n.name = "CottageTripo"
	ps1(n, Color(1.45, 1.45, 1.45), false)
	var rot := arg("tripo-rot", 0.0)
	ajuster(n, p, Vector3(L + 2.2, 6.4, W + 2.0), Vector3(arg("tripo-dx", 0.0), 0, arg("tripo-dz", 0.0)), y_pied, rot)

static func interieur(b: Interieurs, pl: Dictionary) -> void:
	var n := (load(INT) as PackedScene).instantiate() as Node3D
	n.name = "TaverneTripo"
	ps1(n, Color(1.5, 1.5, 1.5))
	var ax: float = pl["ax"]
	var az: float = pl["az"]
	# enceinte de la pièce : murs et plafond en planches (la coque du cottage n'a pas d'envers lisible : neige de toit vue d'en dessous)
	var F := Interieurs.F
	var hp := 2.3
	b.bx(Vector3(0, F + hp + 0.04, 0), Vector3(ax * 2.0 + 0.4, 0.2, az * 2.0 + 0.4), "bois_sombre")
	for sg in [-1.0, 1.0]:
		b.bx(Vector3(sg * (ax + 0.04), F + hp * 0.5, 0), Vector3(0.08, hp, az * 2.0 + 0.4), "bois")
		b.bx(Vector3(0, F + hp * 0.5, sg * (az + 0.04)), Vector3(ax * 2.0 + 0.4, hp, 0.08), "bois")
	for k in range(-2, 3):
		b.bx(Vector3(k * ax * 0.45, F + hp - 0.08, 0), Vector3(0.14, 0.14, az * 2.0), "bois_sombre")
	ajuster(n, b._p(), Vector3(ax * 2.0 - 0.1, 2.2, az * 2.0 - 0.1), Vector3.ZERO, Interieurs.F, arg("tripo-irot", 0.0))
