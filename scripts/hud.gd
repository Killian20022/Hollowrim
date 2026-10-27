extends Control
## HUD pixel art : boussole en haut, barre de l'ennemi frappé, avis, panneau Tab.
## Vie / mana / endurance, mains, statuts et raccourcis : enfant HudCombat (scripts/hud_combat.gd), qui s'efface
## quand tout est plein, comme dans Skyrim.
## Positions RELATIVES à `size` (écran logique, voir EchelleUi) : juste à 480x270, 640x360 et 960x540.
## Tailles des éléments : voir assets/ui/LISEZMOI.md.
## Captures : --hud-demo (barres et avis affichés), --hud-cible (barre d'ennemi), --hud-panneau (panneau Tab).

const CADRE := preload("res://assets/ui/barre_cadre.svg")
const BOUSSOLE := preload("res://assets/ui/boussole.svg")
const REPERE := preload("res://assets/ui/boussole_repere.svg")
const LETTRES := preload("res://assets/ui/lettres_boussole.svg")
const RETICULE := preload("res://assets/ui/reticule.svg")
const ENNEMI := preload("res://assets/ui/indicateur_degat.svg")
const HUD_COMBAT := preload("res://scripts/hud_combat.gd")

const VIE := [Color("#e0574a"), Color("#b8322a"), Color("#7a1c1c")]
const VIGUEUR := [Color("#5fc27f"), Color("#2f8a56"), Color("#1f5a3a")]
const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")
const TAILLE_POLICE := Palette.TAILLE_POLICE   # taille native de la police pixel (voir Palette.police)
const PX_PAR_DEGRE := 0.8  # 150 px de bandeau ≈ 190° visibles
const MARGE := 16.0  # marge des barres sur les bords

var joueur: CharacterBody3D
var lieux: Array = []  # [position, couleur] : points d'intérêt sur la boussole
var combat_ui: Control  # HudCombat (barres, mains, statuts, raccourcis)
var _a_cible := 0.0
var _cible: Node = null
var _avis: Array = []  # [texte, temps restant] : « Épée : niveau 16 »…
var _police: FontFile
var _cadre: StyleBoxTexture
var panneau_ouvert := false
var quetes: Node = null
var _demo := false
var _demo_cible := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police = Palette.police()
	process_mode = Node.PROCESS_MODE_ALWAYS  # le panneau marche jeu en pause
	_cadre = StyleBoxTexture.new()
	_cadre.texture = load("res://assets/ui/dialogue_cadre.svg")
	_cadre.set_texture_margin_all(8)
	_cadre.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_cadre.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	EchelleUi.appliquer(self)
	combat_ui = Control.new()
	combat_ui.set_script(HUD_COMBAT)
	combat_ui.joueur = joueur
	add_child(combat_ui)
	var args := OS.get_cmdline_user_args()
	_demo = args.has("--hud-demo")
	_demo_cible = args.has("--hud-cible")
	panneau_ouvert = args.has("--hud-panneau")
	if panneau_ouvert:  # capture : un sac bien rempli pour vérifier la mise en page (jamais sauvegardé : mode capture)
		(func() -> void:
			for id in ["os_draugr", "poussiere_tombe", "minerai_fer", "minerai_argent", "cristal_givre", "champignon_lumineux",
					"relique_offrande", "lame_antique", "amulette_givre", "ecaille_dragon", "hache_kolbeinn", "cle_archives", "registre_hrafn"]:
				joueur.inventaire.ajouter(id, 2)
			joueur.inventaire.pieces = 137).call_deferred()
	if _demo:
		avis("Épée : niveau 16")
		avis("Partie sauvegardée")
	joueur.competences.niveau_gagne.connect(func(nom: String, niveau: int) -> void:
		avis("%s : niveau %d" % [Competences.NOMS[nom], niveau])
		Sons.jouer(self, ["sword-unsheathe"], -10.0))

## Message en haut à gauche, qui s'efface au bout de quelques secondes.
func avis(texte: String) -> void:
	_avis.append([texte, 4.0])
	if _avis.size() > 4:
		_avis.pop_front()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_TAB and not joueur.mort and not joueur.en_dialogue:
		panneau_ouvert = not panneau_ouvert
		get_tree().paused = panneau_ouvert
		Sons.jouer(self, ["cloth1", "cloth2"], -10.0)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	EchelleUi.appliquer(self)
	if joueur == null:
		return
	if joueur.ennemi_vise != null:
		_cible = joueur.ennemi_vise
		joueur.ennemi_vise = null
		_a_cible = 4.0
	_a_cible -= dt
	for a in _avis:
		a[1] -= dt
	if _demo:
		for a in _avis:
			a[1] = 4.0
	_avis = _avis.filter(func(a: Array) -> bool: return a[1] > 0.0)
	if _cible != null and not is_instance_valid(_cible):
		_cible = null
	queue_redraw()

func _barre(pos: Vector2, ratio: float, couleurs: Array, alpha: float) -> void:
	if alpha < 0.02:
		return
	var blanc := Color(1, 1, 1, alpha)
	draw_rect(Rect2(pos + Vector2(3, 2), Vector2(74, 3)), Color(FOND, alpha))
	# la barre se vide vers le centre
	var largeur := roundi(74.0 * clampf(ratio, 0.0, 1.0))
	var x := pos.x + 3.0 + floorf((74 - largeur) * 0.5)
	for ligne in 3:
		draw_rect(Rect2(x, pos.y + 2 + ligne, largeur, 1), Color(couleurs[ligne], alpha))
	draw_texture(CADRE, pos, blanc)

## Abscisse du centre de l'écran (entière : pixels nets).
func _cx() -> float:
	return floorf(size.x * 0.5)

func _draw() -> void:
	if joueur == null:
		return
	var cx := _cx()
	# --- boussole (bandeau 160 px centré) ---
	draw_texture(BOUSSOLE, Vector2(cx - 80, 4))
	var cap := rad_to_deg(-joueur.rotation.y)
	for i in 8:
		var dx := wrapf(i * 45.0 - cap, -180.0, 180.0) * PX_PAR_DEGRE
		if absf(dx) > 72.0:
			continue
		var x := floorf(cx + dx)
		if i % 2 == 0:
			draw_texture_rect_region(LETTRES, Rect2(x - 2, 6, 5, 7), Rect2((i / 2) * 6, 0, 5, 7))
		else:
			draw_rect(Rect2(x, 8, 1, 3), Color("#8a96ad"))
	for lieu in lieux:
		_marqueur(lieu[0], null, lieu[1])
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.en_combat() and e.global_position.distance_to(joueur.global_position) < 50.0:
			_marqueur(e.global_position, ENNEMI, Color.WHITE)
	draw_texture(REPERE, Vector2(cx - 2, 0))

	# --- réticule (5x5 centré) ; les barres sont dessinées par HudCombat ---
	draw_texture(RETICULE, Vector2(cx - 2, floorf(size.y * 0.5) - 2), Color(1, 1, 1, 0.7))
	for i in (0 if panneau_ouvert else _avis.size()):  # le panneau les masquerait à moitié
		var alpha := clampf(_avis[i][1], 0.0, 1.0)
		var pos := Vector2(8, 46 + i * 12)
		draw_string(_police, pos + Vector2(1, 1), _avis[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(FOND, alpha))
		draw_string(_police, pos, _avis[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(PARCHEMIN, alpha))
	var a_cible := 0.0  # la barre de l'ennemi prend la place de l'objectif (ils se chevauchaient)
	if _cible != null and _a_cible > 0.0:
		a_cible = clampf(_a_cible, 0.0, 1.0)
		_barre(Vector2(cx - 40, 19), _cible.vie / _cible.vie_max, VIE, a_cible)
	elif _demo_cible:
		a_cible = 1.0
		_barre(Vector2(cx - 40, 19), 0.6, VIE, 1.0)
	# objectif de la quête la plus récente, discret sous la boussole
	if quetes != null and not panneau_ouvert and a_cible < 0.98:
		var obj: Array = quetes.objectifs()
		if not obj.is_empty():
			var texte: String = "> " + obj[-1][1]
			var l := _police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
			var a := 0.6 * (1.0 - a_cible)
			draw_string(_police, Vector2(roundf(cx - l * 0.5) + 1, 28), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(FOND, 1.0 - a_cible))
			draw_string(_police, Vector2(roundf(cx - l * 0.5), 27), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(PARCHEMIN, a))
	if panneau_ouvert:
		_panneau()

func _texte(pos: Vector2, texte: String, couleur := PARCHEMIN, largeur := -1.0) -> void:
	draw_string(_police, pos + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, TAILLE_POLICE, FOND)
	draw_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, TAILLE_POLICE, couleur)

## Panneau du personnage (Tab) : compétences et quêtes à gauche, sac à droite.
## Centré ; il s'élargit quand l'écran logique est plus grand (360x180 à 480x270, 440x220 à 640x360).
func _panneau() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(FOND, 0.45))
	var t := Vector2(clampf(size.x - 200.0, 360.0, 440.0), clampf(size.y - 140.0, 180.0, 220.0)).floor()
	var o := ((size - t) * 0.5).floor()
	draw_style_box(_cadre, Rect2(o, t))
	var gx := o.x + 16.0                  # colonne de gauche
	var dx := o.x + floorf(t.x * 0.53)    # colonne de droite
	var pied := o.y + t.y - 14.0          # ligne du bas
	var larg_g := dx - gx - 8.0
	var larg_d := o.x + t.x - 12.0 - dx
	_texte(Vector2(gx, o.y + 22), "Compétences", OR)
	var y := o.y + 40.0
	var c: Competences = joueur.competences
	for nom in Competences.NOMS:
		_texte(Vector2(gx, y), "%s  %d" % [Competences.NOMS[nom], c.niveaux[nom]])
		draw_rect(Rect2(gx, y + 3, 100, 2), Color("#1a2233"))
		draw_rect(Rect2(gx, y + 3, roundi(100 * c.progression(nom)), 2), Color("#6f9be8"))
		y += 22.0
	_texte(Vector2(dx, o.y + 22), "Sac", OR)
	var inv: Inventaire = joueur.inventaire
	y = o.y + 40.0
	_texte(Vector2(dx, y), "Pièces : %d" % inv.pieces)
	y += 13.0
	if inv.objets.is_empty():
		_texte(Vector2(dx, y), "(vide)", Color(PARCHEMIN, 0.5))
	var ids: Array = inv.objets.keys()
	var place := maxi(1, int((pied - 13.0 - y) / 13.0) + 1)  # lignes disponibles au-dessus du pied
	for i in ids.size():
		if i == place - 1 and ids.size() > place:
			_texte(Vector2(dx, y), "… et %d autres" % (ids.size() - i), Color(PARCHEMIN, 0.6))
			break
		_texte(Vector2(dx, y), "%s  x%d" % [inv.nom(ids[i]), inv.objets[ids[i]]], PARCHEMIN, larg_d)
		y += 13.0
	if quetes != null:
		var yq := maxf(o.y + 110.0, o.y + 40.0 + 22.0 * Competences.NOMS.size() + 4.0)
		_texte(Vector2(gx, yq), "Quêtes", OR)
		for q in quetes.objectifs():
			var lignes := _couper("> " + q[1], larg_g)
			for i in lignes.size():
				yq += 13.0
				if yq > pied - 13.0:
					break
				_texte(Vector2(gx + (0.0 if i == 0 else 8.0), yq), lignes[i], PARCHEMIN, larg_g)
	_texte(Vector2(dx, pied), "Poids : %.1f" % inv.poids(), Color(PARCHEMIN, 0.7))
	_texte(Vector2(gx, pied), "Tab : fermer", Color(PARCHEMIN, 0.5))
	var c2 = get_tree().current_scene.get("cycle") if get_tree().current_scene else null
	if c2:
		_texte(Vector2(gx + floorf((dx - gx) * 0.55), pied), c2.texte_heure(), Color(PARCHEMIN, 0.7))

## Coupe un texte en lignes de largeur <= larg (aux espaces).
func _couper(texte: String, larg: float) -> PackedStringArray:
	var res := PackedStringArray()
	var ligne := ""
	for mot in texte.split(" ", false):
		var essai := mot if ligne == "" else ligne + " " + mot
		if ligne != "" and _police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x > larg - 8.0:
			res.append(ligne)
			ligne = mot
		else:
			ligne = essai
	if ligne != "":
		res.append(ligne)
	return res

func _marqueur(pos: Vector3, tex: Texture2D, couleur: Color) -> void:
	var d := pos - joueur.global_position
	var dx := wrapf(rad_to_deg(atan2(d.x, -d.z)) - rad_to_deg(-joueur.rotation.y), -180.0, 180.0) * PX_PAR_DEGRE
	if absf(dx) > 72.0:
		return
	var x := floorf(_cx() + dx)
	if tex != null:
		draw_texture(tex, Vector2(x - 2, 7))
	else:
		draw_rect(Rect2(x - 1, 8, 3, 3), Color("#0b0f1a"))
		draw_rect(Rect2(x, 9, 1, 1), couleur)
