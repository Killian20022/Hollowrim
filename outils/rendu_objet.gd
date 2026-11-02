class_name RenduObjet
extends SubViewport
## OUTIL DE RENDU PAR OBJET : studio photo d'UN objet du registre (ObjetMonde.visuel, pose « studio », taille réelle) dans un
## SubViewport à monde propre, FOND TRANSPARENT, caméra cadrée automatiquement sur sa boîte, éclairage fixe (clé chaude, contre
## froid, ambiance), rendu PS1 (matériaux ps1 / shader_matiere ; petite résolution agrandie au plus proche = pixels nets).
## Sert à : l'aperçu 3D tournant du menu (TextureRect sur get_texture()), les nouvelles icônes (image() -> PNG), les planches.
##
## API
##   var r := RenduObjet.creer(Vector2i(96, 96))   # taille de rendu (px) ; ajouter r à l'arbre (n'importe où) avant de dessiner
##   add_child(r)
##   r.montrer("anneau_braise")                     # pose l'objet, recadre ; lacet / tangage / marge / zoom réglables avant ou après
##   r.lacet = 0.6 ; r.tangage = -0.6 ; r.cadrer()  # angle de vue (rad) : lacet autour de Y, tangage (négatif = vu de dessus)
##   r.tourner = 0.8                                # aperçu de menu : tour lent (rad / s) ; 0 = fixe
##   TextureRect.texture = r.get_texture()          # aperçu vivant
##   r.exposer(1.5) ; r.orienter(Basis(Vector3.RIGHT, PI))   # plus de lumière ; retourner l'objet (face contre terre)
##   var img: Image = await r.image()               # une image (attend un dessin) : fond transparent (alpha)
##   await r.enregistrer("user://icone.png", 4)     # PNG agrandi ×4 au plus proche
##   await RenduObjet.png(arbre_ou_noeud, "amulette_ours", "res://captures/x.png", Vector2i(128, 128), 3)   # tout-en-un
## Notes : un Godot SANS fenêtre (--headless) ne dessine rien (image vide) ; lancer avec fenêtre via godot_slot.sh (hors écran).
## Rien de global n'est modifié (monde 3D propre : own_world_3d) : utilisable pendant une partie (menu) sans toucher la scène.

var lacet := 0.65
var tangage := -0.62
var marge := 1.12          # > 1 : de l'air autour de l'objet
var champ := 28.0          # angle de champ vertical (degrés) : faible = peu de déformation
var tourner := 0.0
var fond := Color(0, 0, 0, 0)
var id := ""

var _scene: Node3D
var _objet: Node3D
var _env: Environment
var _cle: DirectionalLight3D
var _contre: DirectionalLight3D
var _cam: Camera3D
var _centre := Vector3.ZERO
var _rayon := 0.2

static func creer(taille := Vector2i(96, 96)) -> RenduObjet:
	var r := RenduObjet.new()
	r.size = taille
	return r

func _init() -> void:
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_scene = Node3D.new()
	_scene.name = "Studio"
	add_child(_scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fond
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	_scene.add_child(we)
	var cle := DirectionalLight3D.new()       # clé chaude, en haut à gauche
	cle.light_color = Color(1.0, 0.92, 0.8)
	cle.light_energy = 1.35
	cle.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-38), 0)
	_scene.add_child(cle)
	_cle = cle
	var contre := DirectionalLight3D.new()    # contre-jour froid : détache le bord
	contre.light_color = Color(0.7, 0.8, 1.0)
	contre.light_energy = 0.6
	contre.rotation = Vector3(deg_to_rad(-20), deg_to_rad(150), 0)
	_scene.add_child(contre)
	_contre = contre
	_cam = Camera3D.new()
	_cam.current = true
	_scene.add_child(_cam)

## Pose l'objet `oid` (remplace le précédent) et recadre.
func montrer(oid: String) -> void:
	id = oid
	if _objet != null:
		_objet.queue_free()
	_objet = ObjetMonde.visuel(oid, "studio")
	_scene.add_child(_objet)
	var b := ObjetMonde.boite(_objet, _objet.transform)
	_centre = b.get_center()
	_rayon = maxf(b.size.length() * 0.5, 0.005)
	cadrer()

## Exposition du studio : multiplie la clé, le contre-jour et l'ambiance (1 = réglage d'origine). Les icônes (petites, posées sur
## le vélin clair du menu) veulent plus de lumière que l'aperçu : outils/generer_icones.gd.
func exposer(k: float, ambiance := -1.0) -> void:
	_cle.light_energy = 1.35 * k
	_contre.light_energy = 0.6 * k
	_env.ambient_light_energy = 0.55 * (k if ambiance < 0.0 else ambiance)

## Tourne l'OBJET (pas la caméra) puis recadre : ex. bouclier posé face contre terre -> Basis(Vector3.RIGHT, PI).
func orienter(b: Basis) -> void:
	if _objet == null:
		return
	_objet.transform = Transform3D(b, Vector3.ZERO) * _objet.transform
	var bb := ObjetMonde.boite(_objet, _objet.transform)
	_centre = bb.get_center()
	_rayon = maxf(bb.size.length() * 0.5, 0.005)
	cadrer()

## Recadre la caméra sur l'objet selon lacet / tangage / marge / champ.
func cadrer() -> void:
	_cam.fov = champ
	_cam.near = maxf(_rayon * 0.05, 0.001)
	_cam.far = _rayon * 40.0 + 2.0
	var d := _rayon * marge / sin(deg_to_rad(champ) * 0.5)
	var dir := Vector3(sin(lacet) * cos(tangage), -sin(tangage), cos(lacet) * cos(tangage))
	var pos := _centre + dir * d
	_cam.transform = Transform3D(Basis.looking_at(_centre - pos, Vector3.UP), pos)     # sans look_at : marche hors de l'arbre

func _process(dt: float) -> void:
	if tourner != 0.0 and _objet != null:
		lacet += tourner * dt
		cadrer()

## Image du prochain dessin (fond transparent).
func image() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_texture().get_image()

## PNG agrandi `facteur` fois au plus proche voisin (pixels nets).
func enregistrer(chemin: String, facteur := 1) -> Error:
	var img: Image = await image()
	if facteur > 1:
		img.resize(img.get_width() * facteur, img.get_height() * facteur, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	return img.save_png(chemin)

## Tout-en-un : crée un studio sous `hote` (nœud ou SceneTree), rend `oid` en PNG, libère le studio.
static func png(hote: Object, oid: String, chemin: String, taille := Vector2i(96, 96), facteur := 1) -> Error:
	var r := creer(taille)
	var parent: Node = (hote as SceneTree).root if hote is SceneTree else hote as Node
	parent.add_child(r)
	r.montrer(oid)
	var e: Error = await r.enregistrer(chemin, facteur)
	r.queue_free()
	return e
