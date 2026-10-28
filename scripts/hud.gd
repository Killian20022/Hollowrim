extends Control
## HUD pixel art : boussole en haut, NOM + barre de l'ennemi frappé ou visé (statut et « Étourdi » dessous), chiffres de dégâts
## (option, ChiffresDegats), avis, panneau Tab.
## Vie / mana / endurance, mains, statuts et raccourcis : enfant HudCombat (scripts/hud_combat.gd), qui s'efface
## quand tout est plein, comme dans Skyrim.
## Positions RELATIVES à `size` (écran logique, voir EchelleUi) : juste à 480x270, 640x360 et 960x540.
## Tailles des éléments : voir assets/ui/LISEZMOI.md.
## Captures : --hud-demo (barres et avis affichés), --hud-cible (barre d'ennemi), --hud-panneau (panneau Tab),
## --hud-annonce (annonce centrée figée), --hud-aide (aide des touches affichée même en capture).
## Lot L7 : police des TITRES gothique pixel (MenuStyle.police_gothique : Jacquard, OFL) pour le nom de l'ennemi, les titres du
## panneau et les ANNONCES CENTRÉES (lieu découvert, nouvelle quête / quête terminée, niveau de compétence) ; AIDE DES TOUCHES
## dans un cartouche en haut à droite les 60 premières secondes, puis sur F1 ; cadre ornementé (MenuStyle.cadre_orne).
## L'invite d'action sous le réticule (« E  Ouvrir le coffre ») est dessinée par scripts/dialogue.gd.

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
var _gothique: FontFile     # Jacquard 12 : nom de l'ennemi, titres du panneau et de l'aide
var _gothique_g: FontFile   # Jacquard 24 : annonces centrées
var _cadre: StyleBoxTexture
## Annonces centrées : [titre, sous-titre, couleur, temps écoulé, durée] ; une à la fois, les suivantes attendent.
var _annonces: Array = []
const DUREE_ANNONCE := 2.6
var _demo_annonce := false
## Lieux nommés : [position, rayon (m), nom] ; le premier passage annonce « Lieu découvert ». lieux_vus est sauvegardé (monde.gd).
var lieux_nommes: Array = []
var lieux_vus := {}
var decouverte_active := false   # posé par monde.gd une fois la partie chargée (sinon : annonces au point d'apparition)
var _decouverte_t := 0.0
## Aide des touches : [touche, action] ; affichée AIDE_DUREE s au début de la partie (demarrer()), puis seulement sur F1.
const AIDE_DUREE := 60.0
var aide_lignes: Array = [["ZQSD", "marcher"], ["Maj", "courir"], ["Espace", "sauter"], ["Clic gauche", "frapper"],
	["Clic droit", "parer"], ["E", "agir"], ["I", "inventaire"], ["1 - 0", "raccourcis"], ["Tab", "sac et quêtes"],
	["T", "torche"], ["V", "vue"], ["Échap", "menu"]]
var aide_t := 0.0          # secondes d'affichage restantes (fondu sur la dernière)
var aide_forcee := false   # F1
var panneau_ouvert := false
var quetes: Node = null
var _demo := false
var _demo_cible := false
var _visee_t := 0.0
var _rayon := PhysicsRayQueryParameters3D.new()
## Noms des statuts écrits sous la barre de l'ennemi (Statuts.actifs) ; « Étourdi » = posture brisée (finisher possible).
const NOMS_STATUTS := {"brulure": "Brûlure", "brulure_obscure": "Flammes obscures", "gel": "Gel", "choc": "Choc", "corruption": "Corruption"}
## Portée (m) et demi-angle (rad, en plus du rayon de l'ennemi) de la visée qui affiche la barre d'un ennemi en combat.
const VISEE_PORTEE := 14.0
const VISEE_PERIODE := 0.12

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police = Palette.police()
	_gothique = MenuStyle.police_gothique()
	_gothique_g = MenuStyle.police_gothique(true)
	process_mode = Node.PROCESS_MODE_ALWAYS  # le panneau marche jeu en pause
	_cadre = MenuStyle.cadre_orne()
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
		avis("+ 22 Pièces")
		avis("Partie sauvegardée")
	_demo_annonce = args.has("--hud-annonce")
	if _demo_annonce:
		annonce("Tertre de Svanhild", "Lieu découvert", PARCHEMIN)
	if args.has("--hud-aide"):
		aide_forcee = true
	joueur.competences.niveau_gagne.connect(func(nom: String, niveau: int) -> void:
		annonce(Competences.NOMS[nom], "Niveau %d" % niveau)
		Sons.jouer(self, ["sword-unsheathe"], -10.0))

## Début de partie (monde.gd, une fois la sauvegarde relue) : découverte des lieux active, aide des touches pour AIDE_DUREE s.
func demarrer(avec_aide := true) -> void:
	decouverte_active = true
	_decouverte_t = 0.0
	if avec_aide:
		aide_t = AIDE_DUREE

## Lieu nommé : annoncé au centre (« Lieu découvert ») la première fois que le joueur entre dans `rayon` m.
func lieu_nomme(pos: Vector3, rayon: float, nom: String) -> void:
	lieux_nommes.append([pos, rayon, nom])

## Message en haut à gauche, qui s'efface au bout de quelques secondes.
## « Nouvelle quête : X » et « Quête terminée : X » (scripts/quetes.gd) deviennent des annonces centrées.
func avis(texte: String) -> void:
	for prefixe: String in ["Nouvelle quête : ", "Quête terminée : "]:
		if texte.begins_with(prefixe):
			annonce(prefixe.trim_suffix(" : "), texte.substr(prefixe.length()), OR if prefixe.begins_with("Nouvelle") else PARCHEMIN)
			return
	_avis.append([texte, 4.0])
	if _avis.size() > 4:
		_avis.pop_front()

## Annonce centrée (lot L7) : TITRE en gothique 24 px, filet ornemental, sous-titre en police du corps ; ~2,6 s avec fondu.
## Les annonces se suivent (au plus 4 en attente).
func annonce(titre: String, sous_titre := "", couleur := OR) -> void:
	_annonces.append([titre, sous_titre, couleur, 0.0, DUREE_ANNONCE])
	if _annonces.size() > 4:
		_annonces.remove_at(1)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F1:
		aide_forcee = not (aide_forcee or aide_t > 0.0)
		aide_t = 0.0
		get_viewport().set_input_as_handled()
		return
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
	_visee_t -= dt
	if _visee_t <= 0.0:
		_visee_t = VISEE_PERIODE
		var v := _ennemi_vise()
		if v != null:
			_cible = v
			_a_cible = maxf(_a_cible, 1.2)
	for a in _avis:
		a[1] -= dt
	if _demo:
		for a in _avis:
			a[1] = 4.0
	_avis = _avis.filter(func(a: Array) -> bool: return a[1] > 0.0)
	if not _annonces.is_empty() and not panneau_ouvert:
		_annonces[0][3] = 1.0 if _demo_annonce else _annonces[0][3] + dt
		if _annonces[0][3] >= _annonces[0][4]:
			_annonces.pop_front()
	if aide_t > 0.0 and not panneau_ouvert and not get_tree().paused:
		aide_t = maxf(0.0, aide_t - dt)
	if decouverte_active and not lieux_nommes.is_empty():
		_decouverte_t -= dt
		if _decouverte_t <= 0.0:
			_decouverte_t = 0.5
			_decouvrir()
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
		_barre_cible(cx, nom_ennemi(_cible), _cible.vie / _cible.vie_max, statut_ennemi(_cible), _est_boss(_cible), a_cible)
	elif _demo_cible:
		a_cible = 1.0
		_barre_cible(cx, "Draugr ancien", 0.6, "Brûlure", false, 1.0)
	if joueur.get("camera") is Camera3D:
		ChiffresDegats.dessiner(self, joueur.camera, _police)
	# objectif de la quête la plus récente, discret sous la boussole
	if quetes != null and not panneau_ouvert and a_cible < 0.98:
		var obj: Array = quetes.objectifs()
		if not obj.is_empty():
			var texte: String = "> " + obj[-1][1]
			var l := _police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
			var a := 0.6 * (1.0 - a_cible)
			draw_string(_police, Vector2(roundf(cx - l * 0.5) + 1, 28), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(FOND, 1.0 - a_cible))
			draw_string(_police, Vector2(roundf(cx - l * 0.5), 27), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(PARCHEMIN, a))
	_dessiner_annonce(cx)
	_dessiner_aide()
	if panneau_ouvert:
		_panneau()

## Premier passage dans un lieu nommé (à moins de 30 m en hauteur : la crypte est sous le cercle) → annonce « Lieu découvert ».
func _decouvrir() -> void:
	var p := joueur.global_position
	for l: Array in lieux_nommes:
		var c: Vector3 = l[0]
		if lieux_vus.has(l[2]) or absf(p.y - c.y) > 30.0 or Vector2(p.x - c.x, p.z - c.z).length() > float(l[1]):
			continue
		lieux_vus[l[2]] = true
		annonce(l[2], "Lieu découvert", PARCHEMIN)
		Sons.jouer(self, ["cloth1", "cloth2"], -12.0)

## Opacité de l'annonce en cours (0 si aucune) : fondu d'entrée 0,25 s, de sortie 0,6 s.
func alpha_annonce() -> float:
	if _annonces.is_empty() or panneau_ouvert:
		return 0.0
	var t: float = _annonces[0][3]
	return clampf(minf(t / 0.25, (_annonces[0][4] - t) / 0.6), 0.0, 1.0)

## Texte de l'annonce en cours (« titre|sous-titre »), vide sans annonce (tests).
func annonce_courante() -> String:
	return "" if _annonces.is_empty() else "%s|%s" % [_annonces[0][0], _annonces[0][1]]

## Annonce centrée au tiers haut de l'écran : titre gothique 24 px détouré, filet or à losanges, sous-titre dessous.
func _dessiner_annonce(cx: float) -> void:
	var a := alpha_annonce()
	if a <= 0.01:
		return
	var an: Array = _annonces[0]
	var y := floorf(size.y * 0.27)
	var lt := _gothique_g.get_string_size(an[0], HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	MenuStyle.texte_detoure(self, _gothique_g, Vector2(roundf(cx - lt * 0.5), y), an[0], MenuStyle.TITRE_GRAND, an[2], a, true)
	var demi := floorf(clampf(lt * 0.5 + 10.0, 40.0, 150.0))
	MenuStyle.dessiner_filet(self, cx, y + 8.0, demi, a)
	if String(an[1]) != "":
		var ls := _police.get_string_size(an[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		MenuStyle.texte_detoure(self, _police, Vector2(roundf(cx - ls * 0.5), y + 22.0), an[1], TAILLE_POLICE, PARCHEMIN, 0.9 * a)

## L'aide des touches est-elle à l'écran (début de partie ou F1, ni panneau ni dialogue) ?
func aide_visible() -> bool:
	return (aide_forcee or aide_t > 0.0) and not panneau_ouvert and not bool(joueur.get("en_dialogue")) and not aide_lignes.is_empty()

## Cartouche d'aide en haut à droite (sous la hauteur de l'objectif) : titre gothique, touche en or, action en parchemin.
func _dessiner_aide() -> void:
	if not aide_visible():
		return
	var a := 1.0 if aide_forcee else clampf(aide_t / 1.5, 0.0, 1.0)
	var col := 0.0
	var larg := 0.0
	for l: Array in aide_lignes:
		col = maxf(col, _police.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x)
	for l: Array in aide_lignes:
		larg = maxf(larg, col + 8.0 + _police.get_string_size(l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x)
	var pied := "F1 : " + ("masquer" if aide_forcee else "revoir")
	larg = maxf(larg, _police.get_string_size(pied, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x)
	var t := Vector2(ceilf(larg) + 28.0, 50.0 + 10.0 * aide_lignes.size())
	var o := Vector2(floorf(size.x - t.x - 6.0), 36.0)
	_cadre_alpha(Rect2(o, t), a)
	MenuStyle.texte_detoure(self, _gothique, o + Vector2(14, 21), "Commandes", MenuStyle.TITRE_PETIT, OR, a)
	var y := o.y + 33.0
	for l: Array in aide_lignes:
		MenuStyle.texte_detoure(self, _police, Vector2(o.x + 14.0, y), l[0], TAILLE_POLICE, OR, a)
		MenuStyle.texte_detoure(self, _police, Vector2(o.x + 22.0 + col, y), l[1], TAILLE_POLICE, PARCHEMIN, a)
		y += 10.0
	MenuStyle.texte_detoure(self, _police, Vector2(o.x + 14.0, y + 4.0), pied, TAILLE_POLICE, MenuStyle.GRIS, a)

## Cadre en fondu (fin de l'aide) : même boîte, modulée.
func _cadre_alpha(r: Rect2, a: float) -> void:
	_cadre.modulate_color = Color(1, 1, 1, a)
	draw_style_box(_cadre, r)
	_cadre.modulate_color = Color.WHITE

## Barre de l'ennemi (lot L6) : NOM centré au-dessus (gothique pixel du lot L7, or pour un boss), barre de vie, statut actif en dessous.
func _barre_cible(cx: float, nom: String, ratio: float, statut: String, boss: bool, alpha: float) -> void:
	var l := _gothique.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_PETIT).x
	MenuStyle.texte_detoure(self, _gothique, Vector2(roundf(cx - l * 0.5), 27), nom, MenuStyle.TITRE_PETIT, OR if boss else PARCHEMIN, alpha)
	_barre(Vector2(cx - 40, 30), ratio, VIE, alpha)
	if statut != "":
		var ls := _police.get_string_size(statut, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		var ps := Vector2(roundf(cx - ls * 0.5), 47)
		draw_string(_police, ps + Vector2(1, 1), statut, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(FOND, alpha))
		draw_string(_police, ps, statut, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(PARCHEMIN, 0.75 * alpha))

## Nom lisible d'un ennemi (propriété nom_affiche : « Draugr », « Draugr ancien », « Bandit », « Troll de givre »…).
static func nom_ennemi(e: Node) -> String:
	var n: Variant = e.get("nom_affiche") if e != null else null
	if n is Callable:
		n = (n as Callable).call()
	elif e != null and e.has_method("nom_affiche"):
		n = e.call("nom_affiche")
	return String(n) if n is String and String(n) != "" else "Ennemi"

## Statut écrit sous la barre : « Étourdi » (posture brisée), puis les statuts élémentaires actifs (Statuts).
static func statut_ennemi(e: Node) -> String:
	var morceaux := PackedStringArray()
	var c: Variant = e.get("combat")
	if c is CombatEnnemi and (c as CombatEnnemi).etourdi > 0.0:
		morceaux.append("Étourdi")
	var st := e.get_node_or_null(Statuts.NOM) as Statuts
	if st != null:
		for k: String in st.actifs:
			if NOMS_STATUTS.has(k):
				morceaux.append(NOMS_STATUTS[k])
	return " · ".join(morceaux)

static func _est_boss(e: Node) -> bool:
	var b: Variant = e.get("boss")
	if b is String:
		return String(b) != ""
	var c: Variant = e.get("combat")
	return c is CombatEnnemi and (c as CombatEnnemi).boss

## Ennemi en combat sous le réticule (≤ VISEE_PORTEE m, non caché par le décor) : sa barre s'affiche sans avoir à le frapper.
func _ennemi_vise() -> Node:
	var cam: Variant = joueur.get("camera")
	if not (cam is Camera3D) or not (cam as Camera3D).is_inside_tree():
		return null
	var o := (cam as Camera3D).global_position
	var f := -(cam as Camera3D).global_transform.basis.z
	var meilleur: Node3D = null
	var d_min := VISEE_PORTEE
	for e: Node in get_tree().get_nodes_in_group("ennemis"):
		var e3 := e as Node3D
		if e3 == null or not e3.is_visible_in_tree() or not ("vie" in e3) or float(e3.get("vie")) <= 0.0:
			continue
		if e3.has_method("en_combat") and not e3.en_combat():
			continue
		var c := e3.global_position + Vector3(0, 1.1, 0)
		var v := c - o
		var d := v.length()
		if d > d_min or d < 0.3:
			continue
		if f.angle_to(v) > atan2(0.45, d) + 0.03:
			continue
		meilleur = e3
		d_min = d
	if meilleur == null:
		return null
	var esp := (cam as Camera3D).get_world_3d().direct_space_state
	_rayon.from = o
	_rayon.to = meilleur.global_position + Vector3(0, 1.1, 0)
	_rayon.collision_mask = 1
	_rayon.exclude = [joueur.get_rid()]
	var r := esp.intersect_ray(_rayon)
	if not r.is_empty() and r["collider"] != meilleur and float((r["position"] as Vector3).distance_to(o)) < d_min - 0.6:
		return null
	return meilleur

func _texte(pos: Vector2, texte: String, couleur := PARCHEMIN, largeur := -1.0) -> void:
	draw_string(_police, pos + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, TAILLE_POLICE, FOND)
	draw_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, largeur, TAILLE_POLICE, couleur)

## Titre de panneau : gothique pixel 12 px, or, détouré.
func _titre(pos: Vector2, texte: String) -> void:
	MenuStyle.texte_detoure(self, _gothique, pos, texte, MenuStyle.TITRE_PETIT, OR)

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
	_titre(Vector2(gx, o.y + 22), "Compétences")
	var y := o.y + 40.0
	var c: Competences = joueur.competences
	for nom in Competences.NOMS:
		_texte(Vector2(gx, y), "%s  %d" % [Competences.NOMS[nom], c.niveaux[nom]])
		draw_rect(Rect2(gx, y + 3, 100, 2), Color("#1a2233"))
		draw_rect(Rect2(gx, y + 3, roundi(100 * c.progression(nom)), 2), Color("#6f9be8"))
		y += 22.0
	_titre(Vector2(dx, o.y + 22), "Sac")
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
		_titre(Vector2(gx, yq), "Quêtes")
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
