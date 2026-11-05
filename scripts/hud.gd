extends Control
## HUD pixel art : boussole en haut, NOM + barre de l'ennemi frappé ou visé (statut et « Étourdi » dessous), chiffres de dégâts
## (option, ChiffresDegats), avis. Le panneau Tab dessiné ici est remplacé (lot C) par le menu du personnage
## (MenuPersonnage / InventaireMains : Tab, I, K, J) ; `panneau_ouvert` en est le reflet.
## Vie / mana / endurance, mains, statuts et raccourcis : enfant HudCombat (scripts/hud_combat.gd), qui s'efface
## quand tout est plein, comme dans Skyrim.
## Positions RELATIVES à `size` (écran logique, voir EchelleUi) : juste à 480x270, 640x360 et 960x540.
## Tailles des éléments : voir assets/ui/LISEZMOI.md.
## Captures : --hud-demo (barres et avis affichés), --hud-cible (barre d'ennemi), --hud-panneau (menu du personnage ouvert),
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
const CUIR := preload("res://scripts/hud_cuir.gd")
## Boussole « cuir enluminé » (styles a, b, c de HudCuir) : demi-largeur utile (px) et hauteur du bandeau.
const BOUSSOLE_DEMI := 84.0

const VIE := [Color("#e0574a"), Color("#b8322a"), Color("#7a1c1c")]
const VIGUEUR := [Color("#5fc27f"), Color("#2f8a56"), Color("#1f5a3a")]
const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")
const TAILLE_POLICE := Palette.TAILLE_POLICE   # taille native de la police pixel (voir Palette.police)
const PX_PAR_DEGRE := 0.8  # 150 px de bandeau ≈ 190° visibles
const MARGE := 16.0  # marge des barres sur les bords

var joueur: CharacterBody3D
## Points d'intérêt de la boussole : [position: Vector3, couleur: Color, genre := "lieu", nom := ""].
## genre : "lieu" (losange plein), "quete" (sceau vermillon, reste collé au bord quand il sort du champ), "maison" (losange
## creux). Liste normalisée pour les autres écrans (onglet Carte) : marqueurs().
var lieux: Array = []
## Monde (monde.gd) : la boussole lit alors le registre Lieux au lieu de `lieux` (marqueurs()).
var monde: Node = null
var _marqueurs: Array = []
var _marqueurs_t := 0.0
const COULEURS_LIEUX := {"village": Color("#e8a64a"), "cercle": Color("#6fd8ff"), "tertre": Color("#6fd8ff"),
	"grotte": Color("#ffb347"), "feu": Color("#e8a64a"), "chateau": Color("#c8c0b0")}
var combat_ui: Control  # HudCombat (barres, mains, statuts, raccourcis)
var ecran_niveau: EcranNiveau  # RPG lot D : annonce de niveau (sceau) + gains de compétence discrets
var _a_cible := 0.0
var _cible: Node = null
var _avis: Array = []  # [texte, temps restant] : « Épée : niveau 16 »…
var _police: FontFile
var _gothique: FontFile   # Jacquard 24 (police des titres) : nom de l'ennemi, titres du panneau et de l'aide, annonces centrées
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
const OR_SOMBRE_OBJ := Color("#a8702a")
## Objectif de quête sous la boussole : discret, ravivé OBJECTIF_DUREE s quand il change (quetes.gd → objectif_change()).
const OBJECTIF_DUREE := 4.0
var _objectif_t := 0.0
var aide_lignes: Array = construire_aide()

## Lignes de l'aide : les touches RÉELLES du joueur (Touches : suivent le remappage et la disposition du clavier).
static func construire_aide() -> Array:
	return [[Touches.libelle_deplacement(), "marcher"], [Touches.libelle("course"), "courir"], [Touches.libelle("saut"), "sauter"],
		["Clic gauche", "frapper"], ["Clic droit", "parer"], [Touches.libelle("interagir"), "agir"], [Touches.libelle("menu"), "menu"],
		[Touches.libelle("inventaire"), "sac"], ["1 - 0", "raccourcis"], [Touches.libelle("torche"), "torche"],
		[Touches.libelle("vue"), "vue"], ["Échap", "pause"]]
var aide_t := 0.0          # secondes d'affichage restantes (fondu sur la dernière)
var aide_forcee := false   # F1
## Menu du personnage (MenuPersonnage, posé par lui-même) : `panneau_ouvert` lit son état ; l'écrire l'ouvre ou le ferme
## (fenêtre de butin, boutique, menu pause le ferment). Sans menu (scènes de test) : simple drapeau.
var menu: Node = null
var _panneau_brut := false
var panneau_ouvert: bool:
	get:
		return bool(menu.get("ouvert")) if menu != null and is_instance_valid(menu) else _panneau_brut
	set(v):
		if menu != null and is_instance_valid(menu):
			if v:
				menu.call("ouvrir", "")
			else:
				menu.call("fermer")
		else:
			_panneau_brut = v
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
	_gothique = MenuStyle.police_gothique(true)
	process_mode = Node.PROCESS_MODE_ALWAYS  # le panneau marche jeu en pause
	_cadre = MenuStyle.cadre_orne()
	EchelleUi.appliquer(self)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # grain du cuir de la boussole
	combat_ui = Control.new()
	combat_ui.set_script(HUD_COMBAT)
	combat_ui.joueur = joueur
	add_child(combat_ui)
	var args := OS.get_cmdline_user_args()
	_demo = args.has("--hud-demo")
	_demo_cible = args.has("--hud-cible")
	if args.has("--hud-panneau"):  # capture : un sac bien rempli, menu du personnage ouvert (jamais sauvegardé : mode capture)
		(func() -> void:
			for id in ["os_draugr", "poussiere_tombe", "minerai_fer", "minerai_argent", "cristal_givre", "champignon_lumineux",
					"relique_offrande", "lame_antique", "amulette_givre", "ecaille_dragon", "hache_kolbeinn", "cle_archives", "registre_hrafn"]:
				joueur.inventaire.ajouter(id, 2)
			joueur.inventaire.pieces = 137
			await get_tree().create_timer(0.5, true).timeout
			panneau_ouvert = true).call_deferred()
	if _demo:
		avis("+ 22 Pièces")
		avis("Partie sauvegardée")
	_demo_annonce = args.has("--hud-annonce")
	if _demo_annonce:
		annonce("Tertre de Svanhild", "Lieu découvert", PARCHEMIN)
	if args.has("--hud-aide"):
		aide_forcee = true
	# RPG lot D : niveau du personnage = feuille « Niveau supérieur » au sceau de cire ; gain de compétence = bande discrète
	# à droite (scripts/menu/ecran_niveau.gd), plus d'annonce centrée pour les compétences.
	ecran_niveau = EcranNiveau.new()
	ecran_niveau.joueur = joueur
	add_child(ecran_niveau)
	var prog = joueur.get("progression")
	if prog is Progression:
		prog.niveau_competence.connect(ecran_niveau.annoncer_competence)
		prog.niveau_perso.connect(ecran_niveau.annoncer_niveau)
	else:
		joueur.competences.niveau_gagne.connect(ecran_niveau.annoncer_competence)

## Début de partie (monde.gd, une fois la sauvegarde relue) : découverte des lieux active, aide des touches pour AIDE_DUREE s.
func demarrer(avec_aide := true) -> void:
	decouverte_active = true
	_decouverte_t = 0.0
	if avec_aide:
		aide_t = AIDE_DUREE

## Lieu nommé : annoncé au centre (« Lieu découvert ») la première fois que le joueur entre dans `rayon` m.
func lieu_nomme(pos: Vector3, rayon: float, nom: String) -> void:
	lieux_nommes.append([pos, rayon, nom])

## Ennemi dont la barre est à l'écran (visé ou frappé), null sinon : déclencheur de l'aide « premier combat » (aides.gd).
func cible_actuelle() -> Node:
	return _cible if _cible != null and is_instance_valid(_cible) and _a_cible > 0.0 else null

## Nouvel objectif de quête : il n'est plus répété en haut à gauche (doublon) ; la ligne sous la boussole est ravivée.
func objectif_change() -> void:
	_objectif_t = OBJECTIF_DUREE
	_marqueurs_t = 0.0   # le sceau de quête de la boussole suit tout de suite la nouvelle étape

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
	if e.is_action_pressed("aide", false):
		aide_lignes = construire_aide()   # touches modifiées depuis l'ouverture de l'aide
		aide_forcee = not (aide_forcee or aide_t > 0.0)
		aide_t = 0.0
		get_viewport().set_input_as_handled()
		return

func _process(dt: float) -> void:
	EchelleUi.appliquer(self)
	_objectif_t = maxf(0.0, _objectif_t - dt)
	_marqueurs_t -= dt
	if joueur == null:
		return
	if joueur.ennemi_vise != null:
		var ev: Node = joueur.ennemi_vise
		joueur.ennemi_vise = null
		if is_instance_valid(ev) and ev.get("remplace") is Node and is_instance_valid(ev.remplace):
			ev = ev.remplace          # PNJ du village qui a pris les armes (crime.gd : PnjCombat) : sa barre de vie
		if is_instance_valid(ev) and "vie_max" in ev:   # un PNJ seulement averti n'a pas de barre (villageois.vie = horloge Vie)
			_cible = ev
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
	if not _annonces.is_empty() and not panneau_ouvert and not get_tree().paused:   # figée sous le menu pause / l'inventaire
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
	if CUIR.style() != "ancienne":
		CUIR.jauge(self, pos, ratio, couleurs, alpha)
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
	# --- boussole ---
	if CUIR.style() == "ancienne":
		_boussole_fer(cx)
	else:
		_boussole_cuir(cx, CUIR.style())

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
			var vif := clampf(_objectif_t, 0.0, 1.0)   # ravivé puis fondu vers la teinte discrète
			var a := lerpf(0.55, 1.0, vif) * (1.0 - a_cible)
			# cartouche sombre sous la ligne (liseré d'or fin) : lisible sur la neige comme sur le feuillage clair
			var cart := Rect2(roundf(cx - l * 0.5) - 5.0, 18.0, ceilf(l) + 10.0, 13.0)
			draw_rect(cart, Color(FOND, 0.62 * a))
			draw_rect(Rect2(cart.position, Vector2(cart.size.x, 1)), Color(OR_SOMBRE_OBJ, 0.7 * a))
			draw_rect(Rect2(cart.position + Vector2(0, cart.size.y - 1), Vector2(cart.size.x, 1)), Color(OR_SOMBRE_OBJ, 0.7 * a))
			MenuStyle.texte_detoure(self, _police, Vector2(roundf(cx - l * 0.5), 27), texte, TAILLE_POLICE, PARCHEMIN, a, true)
	_dessiner_annonce(cx)
	_dessiner_aide()

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
	if _annonces.is_empty() or panneau_ouvert or get_tree().paused:
		return 0.0
	var t: float = _annonces[0][3]
	return clampf(minf(t / 0.25, (_annonces[0][4] - t) / 0.6), 0.0, 1.0)

## Texte de l'annonce en cours (« titre|sous-titre »), vide sans annonce (tests).
func annonce_courante() -> String:
	return "" if _annonces.is_empty() else "%s|%s" % [_annonces[0][0], _annonces[0][1]]

## Ligne de base du titre de l'annonce : au tiers haut, mais jamais au-dessus de y = 104 (sous les 4 avis de gauche, y 46..82).
func _y_annonce() -> float:
	return maxf(104.0, floorf(size.y * 0.3))

## Rectangle occupé par l'annonce en cours (titre, filet, sous-titre).
func _rect_annonce() -> Rect2:
	if _annonces.is_empty():
		return Rect2()
	var lt := _gothique.get_string_size(_annonces[0][0], HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	var demi := floorf(clampf(lt * 0.5 + 10.0, 40.0, 150.0)) + 6.0
	var ls := _police.get_string_size(_annonces[0][1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x * 0.5
	demi = maxf(demi, ls + 2.0)
	return Rect2(_cx() - demi, _y_annonce() - 20.0, demi * 2.0, 50.0)

## Annonce centrée au tiers haut de l'écran : titre gothique 24 px détouré, filet or à losanges, sous-titre dessous.
func _dessiner_annonce(cx: float) -> void:
	var a := alpha_annonce()
	if a <= 0.01:
		return
	var an: Array = _annonces[0]
	var y := _y_annonce()
	var lt := _gothique.get_string_size(an[0], HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	MenuStyle.texte_detoure(self, _gothique, Vector2(roundf(cx - lt * 0.5), y), an[0], MenuStyle.TITRE_GRAND, an[2], a, true)
	var demi := floorf(clampf(lt * 0.5 + 10.0, 40.0, 150.0))
	MenuStyle.dessiner_filet(self, cx, y + 8.0, demi, a)
	if String(an[1]) != "":
		var ls := _police.get_string_size(an[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		MenuStyle.texte_detoure(self, _police, Vector2(roundf(cx - ls * 0.5), y + 22.0), an[1], TAILLE_POLICE, PARCHEMIN, 0.9 * a)

## L'aide des touches est-elle à l'écran (début de partie ou F1, ni panneau ni dialogue) ?
func aide_visible() -> bool:
	return (aide_forcee or aide_t > 0.0) and not panneau_ouvert and not get_tree().paused and not bool(joueur.get("en_dialogue")) \
		and not aide_lignes.is_empty()

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
	var pied := "%s : masquer" % Touches.libelle("aide")
	larg = maxf(larg, _police.get_string_size(pied, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x)
	var t := Vector2(ceilf(larg) + 28.0, 59.0 + 10.0 * aide_lignes.size())
	var o := Vector2(floorf(size.x - t.x - 6.0), 36.0)
	if Rect2(o, t).intersects(_rect_annonce()):   # petit écran (480x270) : l'annonce passe devant, l'aide s'efface le temps de l'annonce
		a *= 1.0 - alpha_annonce()
		if a <= 0.01:
			return
	_page_alpha(Rect2(o, t), a)   # page de vélin dans un cadre de cuir, comme le menu du personnage
	draw_string(_gothique, o + Vector2(14, 27), "Commandes", HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, Color(Parchemin.RUBRIQUE, a))
	draw_rect(Rect2(o.x + 12.0, o.y + 31.0, t.x - 24.0, 1), Color(Parchemin.OR_TERNI, 0.8 * a))
	var y := o.y + 42.0
	for l: Array in aide_lignes:
		draw_string(_police, Vector2(o.x + 14.0, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(Parchemin.RUBRIQUE, a))
		draw_string(_police, Vector2(o.x + 22.0 + col, y), l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(Parchemin.ENCRE, a))
		y += 10.0
	draw_string(_police, Vector2(o.x + 14.0, y + 4.0), pied, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(Parchemin.PALE, a))

## Page de vélin cerclée de cuir et d'un filet d'or (encart « Commandes »), en fondu.
func _page_alpha(r: Rect2, a: float) -> void:
	draw_rect(r, Color(Parchemin.CUIR[0], 0.95 * a))
	draw_rect(r.grow(-1.0), Color(Parchemin.CUIR[1], a))
	draw_rect(r.grow(-3.0), Color(Parchemin.OR_TERNI, a))
	draw_rect(r.grow(-4.0), Color(Parchemin.VELIN[5], a))
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8.0, 1)), Color(Parchemin.VELIN[3], a))
	draw_rect(Rect2(r.position + Vector2(4, r.size.y - 5.0), Vector2(r.size.x - 8.0, 1)), Color(Parchemin.VELIN[3], a))

## Cadre en fondu (fin de l'aide) : même boîte, modulée.
func _cadre_alpha(r: Rect2, a: float) -> void:
	_cadre.modulate_color = Color(1, 1, 1, a)
	draw_style_box(_cadre, r)
	_cadre.modulate_color = Color.WHITE

## Barre de l'ennemi (lot L6) : NOM centré au-dessus (gothique pixel du lot L7, or pour un boss), barre de vie, statut actif en dessous.
func _barre_cible(cx: float, nom: String, ratio: float, statut: String, boss: bool, alpha: float) -> void:
	# gothique 24 px sous la boussole (y 4..15) : capitales vers y 20, jambages (g, p) au-dessus de la barre
	var l := _gothique.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x
	MenuStyle.texte_detoure(self, _gothique, Vector2(roundf(cx - l * 0.5), 34), nom, MenuStyle.TITRE_GRAND, OR if boss else PARCHEMIN, alpha)
	_barre(Vector2(cx - 40, 40), ratio, VIE, alpha)
	if statut != "":
		var ls := _police.get_string_size(statut, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		var ps := Vector2(roundf(cx - ls * 0.5), 57)
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

## Boussole d'avant (bandeau de fer 160 px, style « ancienne »).
func _boussole_fer(cx: float) -> void:
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
	for m: Dictionary in marqueurs():
		_marqueur(m["pos"], null, m["couleur"])
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.en_combat() and e.global_position.distance_to(joueur.global_position) < 50.0:
			_marqueur(e.global_position, ENNEMI, Color.WHITE)
	draw_texture(REPERE, Vector2(cx - 2, 0))

## Marqueurs de la boussole et de la carte, normalisés : [{pos: Vector3, couleur: Color, genre: String, nom: String}].
## Source : le registre UNIQUE Lieux (scripts/rpg/lieux.gd, partagé avec l'onglet Carte) dès que `monde` est posé
## (monde.gd) : lieux majeurs découverts + feu de camp, et la cible de la quête suivie (genre « quete », sceau vermillon).
## Sans monde (scènes de test) : la liste `lieux`. Les ennemis en combat n'y sont pas (dessinés à part, en direct).
func marqueurs() -> Array:
	if monde != null:
		if _marqueurs_t <= 0.0:
			_marqueurs_t = 0.5   # registre relu deux fois par seconde (cibles de quête : PNJ qui marchent, étape suivante)
			_marqueurs = marqueurs_registre()
		return _marqueurs
	var res := []
	for l: Array in lieux:
		res.append({"pos": l[0], "couleur": l[1] if l.size() > 1 else OR, "genre": str(l[2]) if l.size() > 2 else "lieu",
			"nom": str(l[3]) if l.size() > 3 else ""})
	return res

## Marqueurs lus dans Lieux (voir marqueurs()).
func marqueurs_registre() -> Array:
	var res := []
	for l: Dictionary in Lieux.liste():
		if not (l["majeur"] or l["id"] == "feu") or not Lieux.decouvert(l["id"], self):
			continue
		res.append({"pos": Lieux.position(l["id"], monde), "couleur": COULEURS_LIEUX.get(l["type"], OR), "genre": "lieu",
			"nom": l["nom"]})
	for c: Dictionary in Lieux.cibles_quetes(quetes, monde):
		if c["suivie"]:
			res.append({"pos": c["pos"], "couleur": Color("#c8402e"), "genre": "quete", "nom": c["titre"]})
	return res

## Écart horizontal (px) d'une direction de cap `deg` par rapport au regard.
func _dx_cap(deg: float) -> float:
	return wrapf(deg - rad_to_deg(-joueur.rotation.y), -180.0, 180.0) * PX_PAR_DEGRE

func _dx_pos(pos: Vector3) -> float:
	var d := pos - joueur.global_position
	return _dx_cap(rad_to_deg(atan2(d.x, -d.z)))

## Boussole « cuir enluminé » : a = bandeau de cuir effilé à filets d'or ; b = fil d'or sans fond, lettres ombrées ;
## c = bande de vélin à l'encre (N vermillon), embouts de cuir. Points cardinaux N E S O (N mis en avant), intercardinaux
## en traits, graduations de 15° ; marqueurs : lieux (losange de leur couleur), quête (sceau vermillon collé au bord hors
## champ), ennemis en combat à moins de 50 m (losange rouge). Repère central : pointe d'or au-dessus du bandeau.
func _boussole_cuir(cx: float, st: String) -> void:
	var demi := BOUSSOLE_DEMI
	var y := 3.0
	var h := 11.0
	var x0 := cx - demi - 6
	var larg := 2 * demi + 12
	var lettre_c: Color = CUIR.SUR_CUIR
	var nord_c: Color = CUIR.LETTRINE_OR
	var tic_c: Color = Color(CUIR.SUR_CUIR, 0.75)
	var ombre := true
	match st:
		"a":
			# bandeau de cuir : corps plein, puis 10 px qui s'effacent à chaque bout (pas d'embout dur)
			var corps := Rect2(x0 + 10, y, larg - 20, h)
			draw_rect(Rect2(corps.position - Vector2(0, 1), Vector2(corps.size.x, h + 2)), Color(CUIR.NOIR, 0.55))
			draw_texture_rect(CUIR.cuir(), corps, true, Color(1, 1, 1, 0.82))
			for k in 10:
				var a := (10 - k) / 11.0
				for cote in [-1, 1]:
					var x: float = corps.position.x - 1 - k if cote < 0 else corps.end.x + k
					draw_rect(Rect2(x, y - 1, 1, h + 2), Color(CUIR.NOIR, 0.55 * a))
					draw_texture_rect_region(CUIR.cuir(), Rect2(x, y, 1, h), Rect2(fmod(x, 64.0), 0, 1, h), Color(1, 1, 1, 0.82 * a))
					draw_rect(Rect2(x, y, 1, 1), Color(CUIR.OR_TERNI, 0.9 * a))
					draw_rect(Rect2(x, y + h - 1, 1, 1), Color(CUIR.OR_SOMBRE, 0.9 * a))
			draw_rect(Rect2(corps.position, Vector2(corps.size.x, 1)), Color(CUIR.OR_TERNI, 0.9))
			draw_rect(Rect2(corps.position + Vector2(0, h - 1), Vector2(corps.size.x, 1)), Color(CUIR.OR_SOMBRE, 0.9))
		"b":
			# fil d'or sous les lettres, qui s'efface aux bouts
			for k in int(larg):
				var t: float = absf(k - larg * 0.5) / (larg * 0.5)
				var a := clampf((1.0 - t) * 3.0, 0.0, 1.0)
				draw_rect(Rect2(x0 + k, y + h, 1, 1), Color(CUIR.NOIR, 0.6 * a))
				draw_rect(Rect2(x0 + k, y + h - 1, 1, 1), Color(CUIR.OR_TERNI, 0.95 * a))
			lettre_c = CUIR.CLAIR
			tic_c = Color(CUIR.OR_CLAIR, 0.85)
		"c":
			# bande de vélin, embouts de cuir à filet d'or
			var bande := Rect2(x0 + 4, y, larg - 8, h)
			draw_rect(bande.grow(1), Color(CUIR.NOIR, 0.7))
			draw_texture_rect(CUIR.velin(), bande, true, Color(1, 1, 1, 0.9))
			draw_rect(Rect2(bande.position, Vector2(bande.size.x, 1)), Color(CUIR.OR_TERNI, 0.9))
			draw_rect(Rect2(bande.position + Vector2(0, h - 1), Vector2(bande.size.x, 1)), Color(CUIR.OR_SOMBRE, 0.9))
			for cote in [-1, 1]:
				var r := Rect2(x0 - 1 if cote < 0 else x0 + larg - 6, y - 2, 7, h + 4)
				CUIR.plaque(self, r, 1.0, CUIR.OR_TERNI)
				CUIR.losange(self, r.get_center().floor(), CUIR.CIRE_CLAIRE, 1.0)
			lettre_c = CUIR.ENCRE
			nord_c = CUIR.RUBRIQUE
			tic_c = Color(CUIR.ENCRE, 0.7)
			ombre = false
	# graduations de 15° (points) et intercardinaux (traits)
	for i in 24:
		var dx := _dx_cap(i * 15.0)
		if absf(dx) > demi - 2 or i % 6 == 0:
			continue
		var x := floorf(cx + dx)
		var fondu := clampf((demi - absf(dx)) / 14.0, 0.0, 1.0)
		if i % 3 == 0:
			if ombre:
				draw_rect(Rect2(x - 1, y + 3, 3, 5), Color(CUIR.NOIR, 0.5 * fondu))
			draw_rect(Rect2(x, y + 4, 1, 3), Color(tic_c, tic_c.a * fondu))
		else:
			draw_rect(Rect2(x, y + 5, 1, 1), Color(tic_c, 0.6 * tic_c.a * fondu))
	# points cardinaux (police pixel du corps : un pixel de police = un pixel logique)
	var noms := ["N", "E", "S", "O"]
	for i in 4:
		var dx := _dx_cap(i * 90.0)
		if absf(dx) > demi - 3:
			continue
		var fondu := clampf((demi - absf(dx)) / 14.0, 0.0, 1.0)
		var l := _police.get_string_size(noms[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE).x
		var p := Vector2(floorf(cx + dx - l * 0.5 + 0.5), y + 9)
		var c: Color = nord_c if i == 0 else lettre_c
		if ombre:
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_string(_police, p + o, noms[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(CUIR.NOIR, 0.85 * fondu))
		draw_string(_police, p, noms[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_POLICE, Color(c, fondu))
	# marqueurs
	for m: Dictionary in marqueurs():
		var dx := _dx_pos(m["pos"])
		var quete: bool = m["genre"] == "quete"
		if absf(dx) > demi - 3:
			if not quete:
				continue
			dx = signf(dx) * (demi - 3)
		var pos := Vector2(floorf(cx + dx), y + h + 3)
		if quete:   # sceau sur le bandeau (dessous, il mordait sur la ligne de l'objectif)
			CUIR.sceau(self, "x", Vector2(pos.x, y + floorf(h * 0.5)), 1.0)
		else:
			CUIR.losange(self, pos, m["couleur"], 1.0, m["genre"] == "maison")
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.en_combat() and e.global_position.distance_to(joueur.global_position) < 50.0:
			var dx := _dx_pos(e.global_position)
			if absf(dx) <= demi - 3:
				CUIR.losange(self, Vector2(floorf(cx + dx), y + h + 3), Color("#d8402e"), 1.0)
	# repère central : pointe d'or au-dessus du bandeau
	for k in 3:
		draw_rect(Rect2(cx - 2 + k - 1, y - 3 + k, 5 - 2 * k + 2, 1), Color(CUIR.NOIR, 0.85))
	for k in 3:
		draw_rect(Rect2(cx - 2 + k, y - 3 + k, 5 - 2 * k, 1), Color(CUIR.LETTRINE_OR if k < 2 else CUIR.OR_TERNI, 1.0))
