class_name OngletCarte
extends OngletMenu
## Onglet CARTE du menu personnage (branche rpg/carte ; contrat docs/RPG.md §8, §13). « À la Skyrim un peu » :
## la vraie carte du monde actuel, maquette 3D du terrain vue de haut en perspective inclinée (CarteMonde, rendue dans un
## SubViewport, rendu PS1 : sommets accrochés, grain de bruit), avec nuages qui dérivent, brume de bord et courbes de niveau
## à l'encre ; par-dessus, à l'encre et à la cire du codex : lieux (découverts seulement : hud.lieux_vus, via Lieux),
## quêtes en cours (marqueur or, la quête suivie plus grande), le joueur (flèche vermillon orientée), légende, rose des
## vents, échelle, nom des lieux en Jacquard. Zoom et déplacement : souris (glisser, molette vers le curseur), clavier
## (ZQSD / flèches, + / -, Page préc. / suiv.), manette (sticks, gâchettes, croix). Espace / Y : centrer sur moi ;
## F / X : aller à la quête (suivante à chaque appui) ; L : légende.
## Aucune règle de jeu : lit monde / hud / quêtes / joueur, n'écrit rien.
## Branchement dans MenuPersonnage (lot C) : une ligne dans ONGLETS
##   {"id": "carte", "titre": "Carte", "script": "res://scripts/menu/onglet_carte.gd"}  (touche conseillée : M).

const ENCRE := Color("#2b1a1e")
const PALE := Color("#6a4229")
const RUBRIQUE := Color("#8a1c1c")
const RUBRIQUE_VIVE := Color("#b3341f")
const OR_VIF := Color("#e8a64a")
const OR_TERNI := Color("#b8762a")
const VELIN := Color("#e0d4b4")
const VELIN_CLAIR := Color("#e8e0c8")
const VELIN_SOMBRE := Color("#bb8a53")
const HALO := Color("#e8e0c8")

const PITCH := 55.0            # degrés sous l'horizon
const FOV := 30.0
const DIST_MIN := 38.0         # zoom serré (une maison remplit ~1/10 de la carte)
const VITESSE := 0.9           # fraction de la largeur visible par seconde (clavier, stick)
const ZOOM_PAS := 0.8

## Icônes 9x9 : « # » encre, « r » rubrique, « o » or, « . » vide (halo de vélin ajouté autour).
const ICONES := {
	"village": ["....#....", "...#r#...", "..#rrr#..", ".#rrrrr#.", "#########", ".#.....#.", ".#.##..#.", ".#.##..#.", ".#######."],
	"cercle": [".........", ".#.....#.", ".#..#..#.", ".#.###.#.", ".#.###.#.", "##.###.##", "##.###.##", "#########", "........."],
	"tertre": [".........", "...###...", "..#rrr#..", ".#rr#rr#.", "#rr###rr#", "#rr#.#rr#", "#rr#.#rr#", "#########", "........."],
	"grotte": [".........", "...###...", "..#####..", ".###.###.", ".##...##.", "###...###", "###...###", "#########", "........."],
	"feu": ["....o....", "...oo....", "...oro...", "..orrro..", "..orrro..", "...ooo...", ".#.....#.", "..##.##..", "....#...."],
	"moulin": ["#.......#", ".#.....#.", "..#...#..", "...###...", "...#.#...", "..#...#..", "..#...#..", "..#####..", "........."],
	"ferme": [".........", "....#....", "...#r#...", "..#rrr#..", ".#######.", ".#.....#.", ".#..#..#.", ".#######.", "........."],
	"lac": [".........", ".........", ".##..##..", "#..##..##", ".........", ".##..##..", "#..##..##", ".........", "........."],
	"chateau": ["#.#...#.#", "###...###", ".#.#.#.#.", ".#######.", ".#.....#.", ".#..#..#.", ".#.###.#.", ".#######.", "........."],
}

var quetes: Node = null        ## posé par la coquille si elle le connaît (sinon : hud.quetes)
var monde: Node = null
var carte: CarteMonde = null
var vue: SubViewport = null
var camera: Camera3D = null
var legende := true

var cible := Vector2.ZERO      ## centre visé (x, z monde)
var dist := 200.0              ## distance caméra visée
var _centre := Vector2.ZERO
var _dist := 200.0
var _h_ref := 0.0
var _dist_max := 400.0
var _t := 0.0
var _a_construire := false
var _indispo := ""
var _police: FontFile
var _gothique: FontFile
var _gothique_petit: FontFile
var _icones := {}              ## type -> ImageTexture
var _glisse := false
var _glisse_sol := Vector3.ZERO
var _curseur := Vector2(-1, -1)   ## position du curseur dans la carte (-1 : centre, manette / clavier)
var _quete_idx := -1
var _marqueurs: Array = []     ## [Vector2 écran, nom, sous-titre, ligne, rayon] : survol
var _survol: Array = []

func id_onglet() -> String:
	return "carte"

func titre() -> String:
	return "Carte"

func aide() -> Array:
	return [["ZQSD / Stick", "Déplacer"], ["Molette / Gâch.", "Zoom"], ["Espace / Y", "Me centrer"], ["F / X", "Quête"]]

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique(true)
	_gothique_petit = MenuStyle.police_gothique(false)
	for t: String in ICONES:
		_icones[t] = ImageTexture.create_from_image(icone(t))

## Icône d'un type de lieu (9x9 + halo de vélin d'un pixel : 11x11).
static func icone(type: String) -> Image:
	var motif: Array = ICONES.get(type, ICONES["village"])
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cols := {"#": ENCRE, "r": RUBRIQUE, "o": OR_VIF}
	for y in 9:
		for x in 9:
			var ch: String = motif[y][x]
			if cols.has(ch):
				img.set_pixel(x + 1, y + 1, cols[ch])
	var res := img.duplicate()
	for y in 11:
		for x in 11:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 11 and q.y < 11 and img.get_pixelv(q).a > 0.0:
					res.set_pixel(x, y, Color(HALO, 0.85))
					break
	return res

# ------------------------------------------------------------------ cycle de l'onglet

func ouvrir() -> void:
	_trouver_monde()
	if carte == null and _indispo == "":
		_a_construire = true
	elif carte != null:
		vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		centrer_joueur(true)
	_quete_idx = -1
	queue_redraw()

func fermer() -> void:
	_glisse = false
	if vue != null:
		vue.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _trouver_monde() -> void:
	if monde != null and is_instance_valid(monde):
		return
	monde = null
	var n: Node = joueur.get_parent() if joueur != null else null
	while n != null:
		if n.get("hauteurs_maillage") != null:
			monde = n
			break
		n = n.get_parent()
	if monde == null:
		_indispo = "Pas de carte en ce lieu."
	elif quetes == null:
		quetes = monde.get("quetes")

## Rectangle de la carte (repère de l'onglet).
func rect_carte() -> Rect2:
	var o := ((size - Vector2(640, 360)) * 0.5).max(Vector2.ZERO).floor()
	return Rect2(o + Vector2(20, 33), Vector2(600, 293))

func _construire() -> void:
	_a_construire = false
	var c := CarteMonde.new()
	if not c.construire(monde):
		c.free()
		_indispo = "Pas de carte en ce lieu."
		return
	carte = c
	vue = SubViewport.new()
	vue.name = "VueCarte"
	vue.own_world_3d = true
	vue.size = Vector2i(rect_carte().size)
	vue.msaa_3d = Viewport.MSAA_DISABLED
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(vue)
	vue.add_child(carte)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 2.0
	camera.far = 2000.0
	camera.current = true
	vue.add_child(camera)
	var ext := carte.demi * 2.0 + 24.0
	_dist_max = ext * sin(deg_to_rad(PITCH)) / (2.0 * tan(deg_to_rad(FOV) * 0.5))
	centrer_joueur(true)

# ------------------------------------------------------------------ vue (API : captures, tests)

## Regarde (x, z) à la distance `d` (bornée) ; `immediat` : sans glissement.
func regarder(c: Vector2, d: float, immediat := false) -> void:
	dist = clampf(d, DIST_MIN, _dist_max)
	cible = _borner(c)
	if immediat:
		_centre = cible
		_dist = dist
		_poser_camera()

func centrer_joueur(immediat := false) -> void:
	if monde == null:
		return
	var p := Lieux.position_joueur(monde)
	regarder(Vector2(p.x, p.z), _dist_max * 0.55 if immediat else dist, immediat)

## Aller à la quête suivante (quête suivie d'abord) ; renvoie son titre ("" sans quête).
func centrer_quete() -> String:
	var cq := Lieux.cibles_quetes(quetes, monde)
	if cq.is_empty():
		message.emit("!Aucune quête en cours.")
		return ""
	cq.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["suivie"] and not b["suivie"])
	_quete_idx = (_quete_idx + 1) % cq.size()
	var q: Dictionary = cq[_quete_idx]
	regarder(Vector2(q["pos"].x, q["pos"].z), minf(dist, _dist_max * 0.45))
	message.emit("%s : %s" % [q["titre"], q["objectif"]])
	return q["titre"]

func _borner(c: Vector2) -> Vector2:
	var b := (carte.demi + 10.0) if carte != null else 130.0
	return Vector2(clampf(c.x, -b, b), clampf(c.y, -b, b))

func _poser_camera() -> void:
	if camera == null:
		return
	_h_ref = lerpf(_h_ref, carte.hauteur(_centre.x, _centre.y), 0.25) if _h_ref != 0.0 else carte.hauteur(_centre.x, _centre.y)
	var p := deg_to_rad(PITCH)
	var t := Vector3(_centre.x, _h_ref, _centre.y)
	camera.position = t + Vector3(0, sin(p), cos(p)) * _dist
	camera.look_at(t, Vector3.UP)

## Point du relief (plan horizontal à la hauteur visée) sous la position `p` de la vue.
func _sol_sous(p: Vector2) -> Vector3:
	var o := camera.project_ray_origin(p)
	var d := camera.project_ray_normal(p)
	if absf(d.y) < 1e-4:
		return Vector3(_centre.x, _h_ref, _centre.y)
	var k := (_h_ref - o.y) / d.y
	return o + d * k

func _process(dt: float) -> void:
	if not visible:
		return
	if _a_construire:
		if size.x > 0:
			_construire()
		queue_redraw()
		return
	if carte == null:
		return
	_t += dt
	# clavier (touches physiques : ZQSD en AZERTY = WASD) et manette, en continu
	var dep := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dep.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dep.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dep.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dep.x += 1.0
	var zoom := 0.0
	for pad in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if s.length() > 0.2:
			dep += s
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP): dep.y -= 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN): dep.y += 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT): dep.x -= 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT): dep.x += 1.0
		var ry := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(ry) > 0.2:
			zoom += ry
		zoom += Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) - Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
	if dep != Vector2.ZERO:
		_curseur = Vector2(-1, -1)
		var largeur := 2.0 * _dist * tan(deg_to_rad(FOV) * 0.5) * (rect_carte().size.x / rect_carte().size.y)
		cible = _borner(cible + dep.limit_length(1.0) * largeur * VITESSE * 0.5 * dt)
	if absf(zoom) > 0.05:
		dist = clampf(dist * exp(zoom * 1.6 * dt), DIST_MIN, _dist_max)
	var k := 1.0 - exp(-12.0 * dt)
	_centre = _centre.lerp(cible, k)
	_dist = lerpf(_dist, dist, k)
	_poser_camera()
	var clair := clampf(inverse_lerp(DIST_MIN * 2.0, _dist_max, _dist), 0.0, 1.0)
	carte.regler_temps(_t, clair)
	queue_redraw()

# ------------------------------------------------------------------ entrées

func entree(e: InputEvent) -> bool:
	if carte == null:
		return false
	if e is InputEventKey and e.pressed:
		var k := e as InputEventKey
		match k.physical_keycode:
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				return true   # déplacement lu en continu dans _process
			KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP:
				dist = clampf(dist * ZOOM_PAS, DIST_MIN, _dist_max)
				return true
			KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN, KEY_6:
				dist = clampf(dist / ZOOM_PAS, DIST_MIN, _dist_max)
				return true
			KEY_SPACE, KEY_C:
				if not k.echo:
					centrer_joueur()
				return true
			KEY_F:
				if not k.echo:
					centrer_quete()
				return true
			KEY_L:
				if not k.echo:
					legende = not legende
				return true
		if k.keycode == KEY_PLUS:
			dist = clampf(dist * ZOOM_PAS, DIST_MIN, _dist_max)
			return true
		return false
	if e is InputEventJoypadMotion:
		var ax := (e as InputEventJoypadMotion).axis
		return ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	if e is InputEventJoypadButton:
		var b := (e as InputEventJoypadButton).button_index
		if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			return true
		if not e.pressed:
			return false
		if b == JOY_BUTTON_Y:
			centrer_joueur()
			return true
		if b == JOY_BUTTON_X:
			centrer_quete()
			return true
		if b == JOY_BUTTON_A:
			legende = not legende
			return true
	return false

## Souris : glisser = déplacer (le point saisi reste sous le curseur), molette = zoom vers le curseur.
func _gui_input(e: InputEvent) -> void:
	if carte == null or camera == null:
		return
	var r := rect_carte()
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		var dedans := r.has_point(mb.position)
		var pv := mb.position - r.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and dedans:
				_glisse = true
				_figer()
				_glisse_sol = _sol_sous(pv)
				accept_event()
			elif not mb.pressed and _glisse:
				_glisse = false
				accept_event()
		elif dedans and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_figer()
			var avant := _sol_sous(pv)
			var f := ZOOM_PAS if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_PAS
			_dist = clampf(_dist * f, DIST_MIN, _dist_max)
			dist = _dist
			_poser_camera()
			var apres := _sol_sous(pv)
			_centre = _borner(_centre + Vector2(avant.x - apres.x, avant.z - apres.z))
			cible = _centre
			_poser_camera()
			accept_event()
		elif dedans and mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			centrer_joueur()
			accept_event()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		_curseur = mm.position - r.position if r.has_point(mm.position) else Vector2(-1, -1)
		if _glisse:
			var ici := _sol_sous(mm.position - r.position)
			_centre = _borner(_centre + Vector2(_glisse_sol.x - ici.x, _glisse_sol.z - ici.z))
			cible = _centre
			_poser_camera()
			accept_event()
		queue_redraw()

## Fige le glissement en cours (la vue arrive à sa cible) avant une action souris immédiate.
func _figer() -> void:
	_centre = cible
	_dist = dist
	_poser_camera()

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var r := rect_carte()
	# cadre : double filet d'encre sur le vélin
	draw_rect(r.grow(4), ENCRE, false, 1.0)
	draw_rect(r.grow(2), PALE, false, 1.0)
	if _indispo != "" or carte == null:
		draw_rect(r, Color(VELIN, 0.6))
		var txt := _indispo if _indispo != "" else "On trace la carte…"
		_texte_centre(_gothique, r.get_center() + Vector2(0, 6), txt, MenuStyle.TITRE_GRAND, ENCRE)
		return
	draw_texture_rect(vue.get_texture(), r, false)
	# ombre de la reliure : la carte est peinte à cheval sur les deux pages
	var xr := floorf(size.x * 0.5) - 0.5
	for i in 6:
		var a := 0.22 * (1.0 - i / 6.0)
		draw_line(Vector2(xr - i, r.position.y), Vector2(xr - i, r.end.y), Color(0.1, 0.06, 0.04, a))
		draw_line(Vector2(xr + 1 + i, r.position.y), Vector2(xr + 1 + i, r.end.y), Color(0.1, 0.06, 0.04, a * 0.7))
	_marqueurs = []
	_dessiner_lieux(r)
	_dessiner_quetes(r)
	_dessiner_joueur(r)
	_dessiner_titre(r)
	_dessiner_rose(r)
	_dessiner_echelle(r)
	if legende:
		_dessiner_legende(r)
	_dessiner_survol(r)

## Position écran (repère de l'onglet) d'un point monde ; Vector2.INF si derrière la caméra.
func ecran(p: Vector3) -> Vector2:
	if camera == null or camera.is_position_behind(p):
		return Vector2.INF
	return rect_carte().position + camera.unproject_position(p)

func _sur_carte(q: Vector3) -> Vector3:
	return Vector3(q.x, carte.hauteur(q.x, q.z), q.z)

func _dessiner_lieux(r: Rect2) -> void:
	var hud: Node = monde.get("hud")
	var proche := _dist < _dist_max * 0.45
	for l: Dictionary in Lieux.liste():
		if not Lieux.decouvert(l["id"], hud):
			continue
		var p3 := Lieux.position(l["id"], monde)
		var lointain: bool = absf(p3.x) > carte.demi + CarteMonde.HORS or absf(p3.z) > carte.demi + CarteMonde.HORS
		var s := ecran(_sur_carte(p3)) if not lointain else Vector2.INF
		if lointain:
			# hors carte (château) : sur le bord, dans sa direction, avec une flèche
			var dir := Vector2(p3.x - _centre.x, p3.z - _centre.y).normalized()
			dir.y *= sin(deg_to_rad(PITCH))
			s = _bord(r, r.get_center() + dir.normalized() * 2000.0, 14.0)
			_fleche(s, dir.normalized(), ENCRE)
			s -= dir.normalized() * 10.0
		elif not r.grow(-4).has_point(s):
			continue
		var majeur: bool = l["majeur"]
		if not majeur and not proche and l["type"] != "feu":
			continue
		var ic: ImageTexture = _icones.get(l["type"])
		if ic != null and l["type"] != "lac":
			draw_texture(ic, (s - Vector2(5, 5)).floor())
		var nom: String = l["nom"]
		if majeur:
			_texte_halo(_gothique_petit, (s + Vector2(0, 16)).floor(), nom, MenuStyle.TITRE_PETIT, ENCRE, true, r)
		elif proche or l["type"] == "lac":
			_texte_halo(_police, (s + Vector2(0, 14 if l["type"] != "lac" else 4)).floor(), nom, 16, PALE, true, r)
		_marqueurs.append([s, nom, String(Lieux.TYPES.get(l["type"], "")), String(l["note"]), 8.0, p3])
	# bâtiments du village (noms des portes) quand on zoome
	if _dist < DIST_MIN * 2.2:
		var village: Node = monde.get("village")
		if village != null and village.get("interieurs") is Array:
			for it in village.interieurs:
				if it == null or not is_instance_valid(it) or it.get("racine") == null:
					continue
				var pr: Vector3 = (it.racine as Node3D).global_position
				var s := ecran(Vector3(pr.x, carte.hauteur(pr.x, pr.z) + 5.0, pr.z))
				if r.grow(-10).has_point(s):
					_texte_halo(_police, s.floor(), String(it.nom), 16, PALE, true, r)

func _dessiner_quetes(r: Rect2) -> void:
	var cq := Lieux.cibles_quetes(quetes, monde)
	var bond := 1.0 if fmod(_t, 1.0) < 0.5 else 0.0
	for q: Dictionary in cq:
		var p3: Vector3 = q["pos"]
		var s := ecran(Vector3(p3.x, carte.hauteur(p3.x, p3.z), p3.z))
		var grand: bool = q["suivie"]
		var dedans := r.grow(-8).has_point(s)
		if not dedans:
			var vers := Vector2(p3.x - _centre.x, (p3.z - _centre.y) * sin(deg_to_rad(PITCH))).normalized()
			s = _bord(r, s if s != Vector2.INF else r.get_center() + vers * 2000.0, 12.0)
			_fleche(s + vers * 7.0, vers, OR_TERNI)
		_banniere(s - Vector2(0, bond), grand)
		_marqueurs.append([s, String(q["titre"]), "Quête" + (" suivie" if grand else ""), String(q["objectif"]), 9.0, p3])

## Marqueur de quête : chevron d'or cerclé d'encre, pointe sur le lieu (grand = quête suivie).
func _banniere(s: Vector2, grand: bool) -> void:
	var k := 1.0 if grand else 0.75
	var pts := PackedVector2Array([s, s + Vector2(-5, -9) * k, s + Vector2(-5, -15) * k, s + Vector2(5, -15) * k, s + Vector2(5, -9) * k])
	var halo := PackedVector2Array()
	for p in pts:
		halo.append(s + (p - s) * 1.0 + (p - (s + Vector2(0, -10) * k)).normalized() * 1.5)
	draw_colored_polygon(halo, Color(HALO, 0.9))
	draw_colored_polygon(pts, OR_VIF if grand else OR_TERNI)
	pts.append(pts[0])
	draw_polyline(pts, ENCRE, 1.0)
	draw_rect(Rect2((s + Vector2(-1, -13) * k).floor(), Vector2(2, 2)), RUBRIQUE)

func _dessiner_joueur(r: Rect2) -> void:
	var j: Node3D = monde.get("joueur")
	if j == null:
		return
	var p := Lieux.position_joueur(monde)
	var p3 := _sur_carte(p)
	var s := ecran(p3)
	var avant := -j.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		avant = Vector3.FORWARD
	var s2 := ecran(p3 + avant.normalized() * 6.0)
	var dir := (s2 - s).normalized() if s2 != Vector2.INF and s != Vector2.INF else Vector2.UP
	if not r.grow(-6).has_point(s):
		var vers := Vector2(p.x - _centre.x, (p.z - _centre.y) * sin(deg_to_rad(PITCH))).normalized()
		s = _bord(r, s if s != Vector2.INF else r.get_center() + vers * 2000.0, 10.0)
		_fleche(s + vers * 6.0, vers, RUBRIQUE)
	var cote := Vector2(-dir.y, dir.x)
	var pointe := s + dir * 7.0
	var g := s - dir * 4.0 + cote * 4.5
	var d := s - dir * 4.0 - cote * 4.5
	var creux := s - dir * 1.5
	var tri := PackedVector2Array([pointe, g, creux, d])
	var halo := PackedVector2Array([pointe + dir * 1.6, g + (g - s).normalized() * 1.6, creux - dir * 1.4, d + (d - s).normalized() * 1.6])
	draw_colored_polygon(halo, Color(HALO, 0.95))
	draw_colored_polygon(tri, RUBRIQUE_VIVE)
	tri.append(pointe)
	draw_polyline(tri, ENCRE, 1.0)
	var ss := Lieux.sous_terre(monde)
	var nom := "Vous" if ss == "" else "Vous (sous terre)"
	_marqueurs.append([s, nom, "Votre position", _ou_suis_je(p), 8.0, p])

## Lieu le plus proche du joueur, en mots (« près de Skarnholt », « dans le Tertre de Svanhild »…).
func _ou_suis_je(p: Vector3) -> String:
	var ss := Lieux.sous_terre(monde)
	if ss != "":
		return "Sous terre : " + String(Lieux.lieu(ss)["nom"])
	var best := ""
	var bd := INF
	for l: Dictionary in Lieux.liste():
		var q: Vector2 = l["pos"]
		var dd := q.distance_to(Vector2(p.x, p.z))
		if dd < bd and absf(q.x) < 400.0:
			bd = dd
			best = l["nom"]
	if best == "":
		return ""
	return ("À " if bd < 25.0 else "Près de ") + best if bd < 70.0 else "Dans les bois"

func _dessiner_titre(r: Rect2) -> void:
	var t := "Val de Skarnholt"
	var l := _gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	var sous := _ou_suis_je(Lieux.position_joueur(monde))
	var ls := _police.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var cr := _arrondi(Rect2(r.position + Vector2(6, 6), Vector2(maxf(l, ls) + 16.0, 38.0)))
	_cartouche(cr)
	draw_string(_gothique, cr.position + Vector2(8, 20), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, RUBRIQUE)
	draw_string(_police, cr.position + Vector2(8, 33), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PALE)

## Rose des vents (le nord est toujours en haut).
func _dessiner_rose(r: Rect2) -> void:
	var c := (r.position + Vector2(r.size.x - 22, 26)).floor()
	draw_circle(c, 11.0, Color(VELIN, 0.85))
	draw_arc(c, 11.0, 0, TAU, 24, ENCRE, 1.0)
	draw_arc(c, 8.0, 0, TAU, 20, PALE, 1.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(3, 0), c + Vector2(-3, 0)]), RUBRIQUE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 10), c + Vector2(3, 0), c + Vector2(-3, 0)]), PALE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(10, 0), c + Vector2(0, 2), c + Vector2(0, -2)]), PALE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 0), c + Vector2(0, 2), c + Vector2(0, -2)]), PALE)
	_texte_centre(_gothique_petit, c + Vector2(0, -14), "N", MenuStyle.TITRE_PETIT, RUBRIQUE)

## Échelle (au centre de la vue) : 10, 25, 50 ou 100 m selon le zoom.
func _dessiner_echelle(r: Rect2) -> void:
	var c := r.size * 0.5
	var a := _sol_sous(c)
	var b := _sol_sous(c + Vector2(100, 0))
	var m_par_px := a.distance_to(b) / 100.0
	if m_par_px <= 0.0:
		return
	var metres := 10.0
	for m: float in [10.0, 25.0, 50.0, 100.0]:
		if m / m_par_px <= 90.0:
			metres = m
	var lpx := roundf(metres / m_par_px)
	var o := (r.end - Vector2(lpx + 18.0, 26.0)).floor()
	_cartouche(Rect2(o - Vector2(6, 4), Vector2(lpx + 12, 22)))
	draw_rect(Rect2(o + Vector2(0, 10), Vector2(lpx, 3)), ENCRE, false, 1.0)
	draw_rect(Rect2(o + Vector2(0, 10), Vector2(roundf(lpx * 0.5), 3)), ENCRE)
	draw_string(_police, o + Vector2(0, 7), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ENCRE)

func _dessiner_legende(r: Rect2) -> void:
	var hud: Node = monde.get("hud")
	var types: Array = []
	for l: Dictionary in Lieux.liste():
		if Lieux.decouvert(l["id"], hud) and not (l["type"] in types) and l["type"] != "lac":
			types.append(l["type"])
	var lignes := types.size() + 2
	var cr := _arrondi(Rect2(Vector2(r.position.x + 6, r.end.y - 10 - lignes * 11 - 16), Vector2(104, lignes * 11 + 18)))
	_cartouche(cr)
	draw_string(_gothique_petit, cr.position + Vector2(6, 12), "Légende", HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_PETIT, RUBRIQUE)
	var y := cr.position.y + 16.0
	for t: String in types:
		draw_texture(_icones[t], Vector2(cr.position.x + 4, y))
		draw_string(_police, Vector2(cr.position.x + 18, y + 9), String(Lieux.TYPES.get(t, t)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ENCRE)
		y += 11.0
	_banniere(Vector2(cr.position.x + 9, y + 11), false)
	draw_string(_police, Vector2(cr.position.x + 18, y + 9), "Quête en cours", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ENCRE)
	y += 11.0
	var s := Vector2(cr.position.x + 9, y + 5)
	draw_colored_polygon(PackedVector2Array([s + Vector2(0, -5), s + Vector2(4, 4), s + Vector2(0, 2), s + Vector2(-4, 4)]), RUBRIQUE_VIVE)
	draw_string(_police, Vector2(cr.position.x + 18, y + 9), "Vous", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ENCRE)

## Fiche du marqueur sous le curseur (souris), ou au centre (clavier, manette : petit réticule).
func _dessiner_survol(r: Rect2) -> void:
	var c := r.position + (_curseur if _curseur.x >= 0.0 else r.size * 0.5)
	if _curseur.x < 0.0:
		draw_line(c + Vector2(-4, 0), c + Vector2(-2, 0), Color(ENCRE, 0.7))
		draw_line(c + Vector2(2, 0), c + Vector2(4, 0), Color(ENCRE, 0.7))
		draw_line(c + Vector2(0, -4), c + Vector2(0, -2), Color(ENCRE, 0.7))
		draw_line(c + Vector2(0, 2), c + Vector2(0, 4), Color(ENCRE, 0.7))
	_survol = []
	var bd := INF
	for m: Array in _marqueurs:
		var dd := (m[0] as Vector2).distance_to(c)
		if dd < float(m[4]) + 4.0 and dd < bd:
			bd = dd
			_survol = m
	if _survol.is_empty():
		return
	var titre_ := String(_survol[1])
	var l1 := String(_survol[2])
	var j: Node3D = monde.get("joueur")
	if j != null and l1 != "Votre position":
		var d := Vector2(_survol[5].x, _survol[5].z).distance_to(Vector2(Lieux.position_joueur(monde).x, Lieux.position_joueur(monde).z))
		l1 += (" · " if l1 != "" else "") + ("%d m" % int(round(d / 5.0) * 5.0) if d < 1000.0 else "au loin")
	var l2 := String(_survol[3])
	var w := maxf(_gothique.get_string_size(titre_, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x,
		maxf(_police.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, _police.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)) + 16.0
	var cr := _arrondi(Rect2(Vector2(roundf(r.get_center().x - w * 0.5), r.end.y - (50 if l2 != "" else 38)), Vector2(w, 44 if l2 != "" else 32)))
	_cartouche(cr)
	_texte_centre(_gothique, Vector2(cr.get_center().x, cr.position.y + 19), titre_, MenuStyle.TITRE_GRAND, RUBRIQUE)
	_texte_centre(_police, Vector2(cr.get_center().x, cr.position.y + 30), l1, 16, PALE)
	if l2 != "":
		_texte_centre(_police, Vector2(cr.get_center().x, cr.position.y + 41), l2, 16, ENCRE)

# ------------------------------------------------------------------ outils de dessin

static func _arrondi(r: Rect2) -> Rect2:
	return Rect2(r.position.floor(), r.size.floor())

func _cartouche(cr: Rect2) -> void:
	draw_rect(cr, Color(VELIN_CLAIR, 0.92))
	draw_rect(cr, ENCRE, false, 1.0)
	draw_rect(cr.grow(-2), Color(VELIN_SOMBRE, 0.8), false, 1.0)

func _texte_centre(police: Font, c: Vector2, t: String, taille: int, col: Color) -> void:
	var l := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	draw_string(police, Vector2(roundf(c.x - l * 0.5), c.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)

## Texte centré sur `c` (ligne de base), cerné de vélin (lisible sur la neige comme sur la forêt), gardé dans la carte.
func _texte_halo(police: Font, c: Vector2, t: String, taille: int, col: Color, centre: bool, r: Rect2) -> void:
	var l := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var x := roundf(c.x - l * 0.5) if centre else c.x
	x = clampf(x, r.position.x + 3, r.end.x - l - 3)
	var p := Vector2(x, clampf(c.y, r.position.y + 12, r.end.y - 3))
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_string(police, p + d, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(HALO, 0.8))
	draw_string(police, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)

## Point du bord de `r` (rentré de `marge`) sur la demi-droite centre → `vers`.
func _bord(r: Rect2, vers: Vector2, marge: float) -> Vector2:
	var c := r.get_center()
	var d := vers - c
	if d.length() < 0.01:
		return c
	var demi := r.size * 0.5 - Vector2(marge, marge)
	var k := minf(demi.x / maxf(absf(d.x), 1e-3), demi.y / maxf(absf(d.y), 1e-3))
	return (c + d * minf(k, 1.0)).floor()

func _fleche(s: Vector2, dir: Vector2, col: Color) -> void:
	var cote := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([s + dir * 4.0, s - dir * 2.0 + cote * 3.0, s - dir * 2.0 - cote * 3.0]), col)
