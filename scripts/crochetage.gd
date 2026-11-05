class_name Crochetage
extends CanvasLayer
## Mini-jeu de CROCHETAGE à la Skyrim, adapté PS1 (crime.gd ; ouvert par Crime.demander_crochetage). Une serrure de fer sur une page de
## vélin (cadre de cuir, filet d'or : style du HUD et des fenêtres du jeu), vue de face :
##   - le CROCHET pivote dans le trou de serrure (souris, Q / D, flèches, croix de la manette) sur 180° ;
##   - maintenir E (ou Espace, Z, A de la manette) TOURNE la serrure avec la clé de tension : elle ne tourne à fond que si le crochet est
##     dans la bonne zone (angle secret, largeur selon le verrou et la compétence Furtivité) ; près de la zone elle tourne en partie ;
##   - forcer une serrure qui bloque fait trembler puis CASSER le crochet (un crochet de moins : objet « crochet » du sac) ;
##   - Échap / clic droit / B : renoncer. Le jeu est en pause pendant le mini-jeu.
## Verrous 1-4 : Apprenti, Adepte, Expert, Maître (zone de 34°, 22°, 13°, 7° ; casse en 1,4 / 1,0 / 0,75 / 0,55 s de force).
## Réussi : meta « verrou » = 0, cible.deverrouiller() si elle existe, signal Crime.crochetage_fini(cible, vrai), pratique de Furtivité.

const NOMS := ["", "Apprenti", "Adepte", "Expert", "Maître"]
const LARGEUR := [0.0, 34.0, 22.0, 13.0, 7.0]       # degrés : zone où la serrure tourne à fond
const CASSE := [0.0, 1.4, 1.0, 0.75, 0.55]          # s de force contre une serrure bloquée avant que le crochet casse
const PARTIELLE := 50.0                             # degrés au-delà de la zone où la serrure tourne encore un peu
const VITESSE_TOURNER := 1.6                        # part de tour par seconde
const VITESSE_RETOUR := 3.0
const VITESSE_CLAVIER := 90.0                       # degrés par seconde (Q / D)
const SENSIBILITE := 0.35                           # degrés par pixel de souris

var crime: Node
var joueur: CharacterBody3D
var ouvert := false
var cible: Node3D
var verrou := 1
var angle := 0.0                 # crochet, degrés (-90 gauche, 0 haut, 90 droite)
var angle_secret := 0.0
var largeur := 30.0
var tour := 0.0                  # rotation de la serrure 0..1 (1 = ouverte)
var force := 0.0                 # 0..1 : le crochet casse à 1
var casses := 0                  # crochets cassés pendant cette tentative
var resultat := ""               # « ouvert », « abandon », « sans_crochet »
var tourne := false              # maintenu (clavier) ou imposé (tests)
var _vue: Control
var _police: FontFile
var _titre: FontFile
var _page: Texture2D
var _souris := Input.MOUSE_MODE_CAPTURED
var _t := 0.0
var _secousse := 0.0
var _ferme_t := -1.0

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vue = Control.new()
	_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vue.visible = false
	_vue.draw.connect(_dessiner)
	add_child(_vue)
	_police = Palette.police()
	_titre = MenuStyle.police_gothique(true)

## Commence le crochetage de `cible` (verrou 1-4). Faux si déjà ouvert ou sans crochet.
func ouvrir(c: Node3D, niveau: int) -> bool:
	if ouvert or joueur == null or joueur.inventaire.nombre("crochet") <= 0:
		return false
	cible = c
	verrou = clampi(niveau, 1, 4)
	var bonus := 0.0
	var prog: Variant = joueur.get("progression")
	if prog is Progression:
		bonus = (prog as Progression).competences.bonus("furtivite")
	largeur = LARGEUR[verrou] * (1.0 + 0.6 * bonus)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(c.get_instance_id()) + str(Time.get_ticks_usec()))
	angle_secret = rng.randf_range(-90.0 + largeur * 0.5, 90.0 - largeur * 0.5)
	if c.has_meta("angle_secret"):
		angle_secret = float(c.get_meta("angle_secret"))     # serrure qui garde son secret entre deux tentatives (démo, tests)
	else:
		c.set_meta("angle_secret", angle_secret)
	angle = 0.0
	tour = 0.0
	force = 0.0
	casses = 0
	resultat = ""
	tourne = false
	ouvert = true
	_ferme_t = -1.0
	if _page == null:
		_page = ImageTexture.create_from_image(Parchemin.feuille(Vector2i(256, 176), 19))
	_vue.visible = true
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sons.jouer(self, ["cloth1"], -12.0)
	return true

func fermer(res: String) -> void:
	if not ouvert:
		return
	ouvert = false
	resultat = res
	tourne = false
	_vue.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris
	var reussi := res == "ouvert"
	if reussi and cible != null and is_instance_valid(cible):
		cible.set_meta("verrou", 0)
		cible.remove_meta("angle_secret")
		if cible.has_method("deverrouiller"):
			cible.deverrouiller()
		var prog: Variant = joueur.get("progression")
		if prog is Progression:
			(prog as Progression).pratiquer("furtivite", 4.0 * verrou)
	if crime != null and is_instance_valid(cible):
		crime.crochetage_fini.emit(cible, reussi)

## Rotation que permet l'angle actuel du crochet (1 dans la zone, décroissante sur PARTIELLE degrés autour, 0 au-delà).
func ouverture_max() -> float:
	var ecart := absf(angle - angle_secret) - largeur * 0.5
	if ecart <= 0.0:
		return 1.0
	return clampf(1.0 - ecart / PARTIELLE, 0.0, 0.92)

## Une image du mini-jeu (appelée par _process ; les tests l'appellent à pas fixe).
func pas(dt: float) -> void:
	if not ouvert:
		return
	if tourne:
		var lim := ouverture_max()
		tour = move_toward(tour, lim, VITESSE_TOURNER * dt)
		if tour >= 0.999:
			Sons.jouer(self, ["doorOpen_1"], -8.0, 0.05, &"", 1.5)
			fermer("ouvert")
			return
		if tour >= lim - 0.002:
			force += dt / CASSE[verrou]          # la serrure bloque : on force sur le crochet
			_secousse = 1.0
			if force >= 1.0:
				_casser()
	else:
		tour = move_toward(tour, 0.0, VITESSE_RETOUR * dt)
		force = maxf(0.0, force - dt * 1.5)
	_secousse = maxf(0.0, _secousse - dt * 6.0)

func _casser() -> void:
	casses += 1
	force = 0.0
	tour = 0.0
	tourne = false
	joueur.inventaire.retirer("crochet", 1)
	Sons.jouer(self, ["impactPlate_medium_000", "impactPlate_medium_001"], -6.0, 0.1, &"", 1.6)
	if joueur.inventaire.nombre("crochet") <= 0:
		fermer("sans_crochet")

## Tests : place le crochet à `deg` puis tourne pendant `duree` s (pas de 1/60 s). Renvoie le résultat ou « bloque ».
func essayer(deg: float, duree: float) -> String:
	angle = clampf(deg, -90.0, 90.0)
	tourne = true
	var n := int(duree * 60.0)
	var casse_avant := casses
	for i in n:
		pas(1.0 / 60.0)
		if not ouvert:
			return resultat
		if casses > casse_avant:
			return "casse"
	tourne = false
	pas(1.0 / 60.0)
	return "bloque"

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	if e is InputEventMouseMotion:
		if not tourne:
			angle = clampf(angle + (e as InputEventMouseMotion).relative.x * SENSIBILITE, -90.0, 90.0)
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		fermer("abandon")
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
		fermer("abandon")
	elif e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		fermer("abandon")
	get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not ouvert:
		return
	_t += dt
	EchelleUi.appliquer(_vue)
	var tient := Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) \
		or Input.is_physical_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if DisplayServer.get_name() != "headless" and not get_meta("pilote", false):
		tourne = tient
	if not tourne:
		var sens := 0.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
			sens -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
			sens += 1.0
		sens += Input.get_joy_axis(0, JOY_AXIS_LEFT_X) if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.2 else 0.0
		angle = clampf(angle + sens * VITESSE_CLAVIER * dt, -90.0, 90.0)
	if not get_meta("pilote", false):
		pas(dt)
	_vue.queue_redraw()

# ------------------------------------------------------------------ dessin (pixels logiques, EchelleUi)

func _dessiner() -> void:
	var s := _vue.size
	var taille := Vector2(256, 176)
	var o := ((s - taille) * 0.5).floor()
	# voile sombre sur le jeu, cadre de cuir à filet d'or, page de vélin
	_vue.draw_rect(Rect2(Vector2.ZERO, s), Color(Parchemin.FER[0], 0.55))
	_vue.draw_rect(Rect2(o - Vector2(5, 5), taille + Vector2(10, 10)), Parchemin.CUIR[0])
	_vue.draw_rect(Rect2(o - Vector2(4, 4), taille + Vector2(8, 8)), Parchemin.CUIR[1])
	_vue.draw_rect(Rect2(o - Vector2(2, 2), taille + Vector2(4, 4)), Parchemin.OR_TERNI, false, 1.0)
	_vue.draw_texture(_page, o)
	# titre
	var titre := "Crochetage"
	var lt := _titre.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	_vue.draw_string(_titre, Vector2(roundf(o.x + taille.x * 0.5 - lt * 0.5), o.y + 22), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, Parchemin.RUBRIQUE)
	# serrure
	var c := (o + Vector2(taille.x * 0.5, 86)).floor()
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * (1.0 if _secousse > 0.3 and fmod(_t, 0.1) < 0.05 else 0.0)
	_vue.draw_circle(c + Vector2(2, 2), 40, Color(Parchemin.CUIR[0], 0.5))
	_vue.draw_circle(c, 40, Parchemin.FER[0])
	_vue.draw_circle(c, 38, Parchemin.FER[1])
	_vue.draw_circle(c, 33, Parchemin.FER[2])
	_vue.draw_arc(c, 36, 0.0, TAU, 32, Parchemin.FER[0], 1.0)
	for k in 8:          # rivets
		var a := TAU * k / 8.0 + PI / 8.0
		var r := (c + Vector2(cos(a), sin(a)) * 36.0).round()
		_vue.draw_rect(Rect2(r - Vector2(1, 1), Vector2(2, 2)), Parchemin.FER[3])
	# barillet qui tourne (rotation 0 → 90°)
	var rot := tour * PI * 0.5
	_vue.draw_circle(c, 22, Parchemin.FER[1])
	_vue.draw_arc(c, 22, 0.0, TAU, 28, Parchemin.FER[0], 1.0)
	var trou := PackedVector2Array()
	for p: Vector2 in [Vector2(-3, -10), Vector2(3, -10), Vector2(3, -4), Vector2(6, 12), Vector2(-6, 12), Vector2(-3, -4)]:
		trou.append(c + p.rotated(rot))
	_vue.draw_colored_polygon(trou, Parchemin.FER[0])
	_vue.draw_circle(c + Vector2(0, -8).rotated(rot), 5, Parchemin.FER[0])
	# clé de tension (en bas, tourne avec le barillet)
	var t0 := c + Vector2(0, 10).rotated(rot)
	var t1 := c + Vector2(0, 44).rotated(rot)
	_vue.draw_line(t0, t1, Parchemin.CUIR[0], 3.0)
	_vue.draw_line(t0, t1, Parchemin.FER[3], 1.0)
	_vue.draw_line(t1, t1 + Vector2(14, 0).rotated(rot), Parchemin.FER[3], 2.0)
	# crochet : de l'extérieur vers le trou, selon l'angle (0 = en haut)
	var a_cro := deg_to_rad(angle) - PI * 0.5
	var dirc := Vector2(cos(a_cro), sin(a_cro))
	var bout := c + dirc * 6.0 + jit
	var queue := c + dirc * 56.0 + jit
	var teinte: Color = Parchemin.FER[3].lerp(Parchemin.RUBRIQUE_VIVE, clampf(force, 0.0, 1.0))
	_vue.draw_line(queue, bout, Parchemin.CUIR[0], 3.0)
	_vue.draw_line(queue, bout, teinte, 1.0)
	_vue.draw_line(bout, bout + dirc.rotated(PI * 0.5) * 3.0, teinte, 1.0)       # pointe recourbée
	_vue.draw_rect(Rect2((queue - Vector2(2, 2)).round(), Vector2(4, 4)), Parchemin.CUIR[2])  # manche de bois
	# textes
	var l1 := "Verrou : %s" % NOMS[verrou]
	var l2 := "Crochets : %d" % (joueur.inventaire.nombre("crochet") if joueur != null else 0)
	_vue.draw_string(_police, Vector2(o.x + 12, o.y + taille.y - 26), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE, Parchemin.ENCRE)
	var l2w := _police.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x
	_vue.draw_string(_police, Vector2(o.x + taille.x - 12 - l2w, o.y + taille.y - 26), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE, Parchemin.RUBRIQUE if casses > 0 else Parchemin.ENCRE)
	var aide := "Souris/Q D : crochet   E : tourner   Échap"
	var lw := _police.get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x
	_vue.draw_string(_police, Vector2(roundf(o.x + taille.x * 0.5 - lw * 0.5), o.y + taille.y - 10), aide, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE, Parchemin.PALE)
