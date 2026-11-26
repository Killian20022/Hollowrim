class_name EcranMulti
extends PanelContainer
## Panneau « Multijoueur » de l'écran titre (lot 5b) : Héberger, Rejoindre, salon (liste des joueurs), retour.
## Même habillage que les autres panneaux du titre (MenuStyle.theme_titre : panneau d'acier, boutons runiques, texte givre) ;
## tout se fait au clavier (Haut/Bas, Gauche/Droite sur le choix du monde, Entrée, Échap) et à la manette (croix, A, B) ; la saisie
## d'une adresse demande un clavier. Les textes sont en français.
##
## Vues : choix -> heberger | rejoindre -> (connexion) -> salon. Le salon liste les joueurs ; l'hôte y lance la partie (évènement
## « salon_lancer » à tous), un invité qui arrive après le lancement entre directement dans le monde.
## Signaux : `ferme` (retour au menu principal), `lancer_partie(role, nouveau, emplacement)` (l'écran titre charge le monde),
## `son(nom)` (survol, validation, retour : joués par l'écran titre).
## Reseau est lu par PauseCoop.R() (ce script est aussi chargé par des tests --script, où l'identifiant nu n'existe pas).

signal ferme
signal lancer_partie(role: String, nouveau: bool, emplacement: int)
signal son(nom: String)

const PORT_DEFAUT := 24565
const PORT_MIN := 1024
const PORT_MAX := 65535
const FICHIER_PREFS := "user://multijoueur.cfg"
const NOUVEAU_MONDE := -2   ## « emplacement » du choix « Nouveau monde »

## Enregistre le nom, la dernière adresse et le dernier port (tests : désactivé).
var persistance := true
var vue := ""   ## choix | heberger | rejoindre | connexion | salon (tests)

var _vues := {}
var _avis: Label
var _champ_nom_h: LineEdit
var _champ_port_h: LineEdit
var _case_pvp: CheckBox
var _champ_nom_r: LineEdit
var _champ_adresse: LineEdit
var _b_monde: Button
var _b_ouvrir: Button
var _b_connecter: Button
var _b_lancer: Button
var _b_choix_heberger: Button
var _b_choix_rejoindre: Button
var _liste_joueurs: VBoxContainer
var _titre_salon: Label
var _etat_salon: Label
var _texte_connexion: Label
var _emplacements: Array[int] = []
var _indice_monde := 0
var _role := ""   ## "hote" | "invite" | ""
var _abonne := false
## Jeu par Internet (relais Epic EOS, code de salon) : le transport EOS remplace ENet le temps de la connexion.
var _internet := false
var _eos: ReseauTransportEOS = null
var _transport_avant: ReseauTransport = null
var _code_salon := ""
var _operation := 0   ## numéro de la demande Internet en cours (une demande périmée est abandonnée)
var _b_choix_heberger_net: Button
var _b_choix_rejoindre_code: Button
var _etq_port: Label
var _etq_adresse: Label

# ---------- analyse des saisies (statique : testable sans interface) ----------

## « 192.168.1.20 », « 192.168.1.20:24565 », « mon-pc.local:25000 », « localhost » -> {ok, ip, port, erreur}.
static func analyser_adresse(texte: String, port_defaut := PORT_DEFAUT) -> Dictionary:
	var t := texte.strip_edges()
	var r := {"ok": false, "ip": "", "port": port_defaut, "erreur": ""}
	if t == "":
		r["erreur"] = "Saisir l'adresse de l'hôte (exemple : 192.168.1.20:24565)."
		return r
	if t.contains(" "):
		r["erreur"] = "L'adresse ne doit pas contenir d'espace."
		return r
	var hote := t
	if t.count(":") == 1:
		var morceaux := t.split(":")
		hote = morceaux[0]
		var p := analyser_port(morceaux[1])
		if not p["ok"]:
			r["erreur"] = p["erreur"]
			return r
		r["port"] = p["port"]
	elif t.count(":") > 1:
		r["erreur"] = "Adresse invalide : une seule fois « : » (IP:port). Les adresses IPv6 ne sont pas gérées."
		return r
	if hote == "":
		r["erreur"] = "Adresse invalide : l'adresse de l'hôte est vide avant le « : »."
		return r
	var groupes := hote.split(".")
	var tout_chiffres := true
	for g in groupes:
		if g == "" or not g.is_valid_int():
			tout_chiffres = false
	if tout_chiffres:   # écrite comme une IPv4 : doit en être une
		if groupes.size() != 4:
			r["erreur"] = "Adresse IP invalide : %d nombre(s) au lieu de 4 (exemple : 192.168.1.20)." % groupes.size()
			return r
		for g in groupes:
			if int(g) < 0 or int(g) > 255:
				r["erreur"] = "Adresse IP invalide : %s n'est pas compris entre 0 et 255." % g
				return r
			if g.length() > 3:
				r["erreur"] = "Adresse IP invalide : « %s » est trop long." % g
				return r
		r["ok"] = true
		r["ip"] = hote
		return r
	# nom d'hôte (localhost, mon-pc.local…)
	var motif := RegEx.new()
	motif.compile("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")
	if hote.length() > 253 or motif.search(hote) == null:
		r["erreur"] = "Adresse invalide : « %s » n'est ni une adresse IP ni un nom d'hôte." % hote
		return r
	r["ok"] = true
	r["ip"] = hote
	return r

static func analyser_port(texte: String) -> Dictionary:
	var t := texte.strip_edges()
	if t == "":
		return {"ok": true, "port": PORT_DEFAUT, "erreur": ""}
	if not t.is_valid_int():
		return {"ok": false, "port": 0, "erreur": "Port invalide : « %s » n'est pas un nombre." % t}
	var n := int(t)
	if n < PORT_MIN or n > PORT_MAX:
		return {"ok": false, "port": 0, "erreur": "Port invalide : il doit être compris entre %d et %d." % [PORT_MIN, PORT_MAX]}
	return {"ok": true, "port": n, "erreur": ""}

static func analyser_nom(texte: String) -> Dictionary:
	var t := texte.strip_edges()
	if t == "":
		return {"ok": false, "nom": "", "erreur": "Saisir un nom de joueur."}
	if t.length() > 20:
		return {"ok": false, "nom": "", "erreur": "Le nom est trop long (20 caractères au plus)."}
	for i in t.length():
		if t.unicode_at(i) < 32:
			return {"ok": false, "nom": "", "erreur": "Le nom contient un caractère interdit."}
	return {"ok": true, "nom": t, "erreur": ""}

## Message lisible pour un code d'erreur de Reseau.heberger / rejoindre.
static func texte_erreur(err: int, port: int) -> String:
	match err:
		ERR_CANT_CREATE:
			return "Impossible d'ouvrir le port %d : il est déjà utilisé (une autre partie ?) ou interdit." % port
		ERR_ALREADY_IN_USE:
			return "Une connexion est déjà ouverte."
	return "Connexion impossible (%s)." % error_string(err)

static func charger_prefs(chemin := FICHIER_PREFS) -> Dictionary:
	var c := ConfigFile.new()
	var r := {"nom": "", "adresse": "", "port": PORT_DEFAUT}
	if c.load(chemin) == OK:
		r["nom"] = String(c.get_value("multi", "nom", ""))
		r["adresse"] = String(c.get_value("multi", "adresse", ""))
		r["port"] = int(c.get_value("multi", "port", PORT_DEFAUT))
	return r

static func sauver_prefs(nom: String, adresse: String, port: int, chemin := FICHIER_PREFS) -> void:
	var c := ConfigFile.new()
	c.load(chemin)
	if nom != "":
		c.set_value("multi", "nom", nom)
	if adresse != "":
		c.set_value("multi", "adresse", adresse)
	c.set_value("multi", "port", port)
	c.save(chemin)

func _R() -> Node:
	return PauseCoop.R()

# ---------- construction ----------

func _ready() -> void:
	name = "PanneauMultijoueur"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(820, 0)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 16)
	add_child(pile)
	pile.add_child(_titre("Multijoueur"))
	_construire_choix(pile)
	_construire_heberger(pile)
	_construire_rejoindre(pile)
	_construire_connexion(pile)
	_construire_salon(pile)
	_avis = Label.new()
	_avis.name = "Avis"
	_avis.add_theme_color_override("font_color", Color("#ffb070"))
	_avis.add_theme_font_size_override("font_size", 24)
	_avis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avis.custom_minimum_size = Vector2(740, 0)
	pile.add_child(_avis)
	var prefs := charger_prefs() if persistance else {"nom": "", "adresse": "", "port": PORT_DEFAUT}
	var nom_defaut: String = prefs["nom"] if String(prefs["nom"]) != "" else "Joueur"
	_champ_nom_h.text = nom_defaut
	_champ_nom_r.text = nom_defaut
	_champ_adresse.text = String(prefs["adresse"])
	_champ_port_h.text = str(int(prefs["port"]))

func _exit_tree() -> void:
	_desabonner()

func _titre(texte: String) -> Label:
	var t := Label.new()
	t.text = texte.to_upper()
	t.add_theme_font_override("font", MenuStyle.police_capitales(600))
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", MenuStyle.GIVRE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t

func _etiquette(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", MenuStyle.LUEUR.lerp(MenuStyle.GIVRE, 0.4))
	return l

func _bouton(texte: String, action: Callable, nom := "") -> Button:
	var b := Button.new()
	b.text = texte
	if nom != "":
		b.name = nom
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 28)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: son.emit("survol"))
	b.pressed.connect(func() -> void:
		son.emit("validation")
		action.call())
	return b

func _champ(nom: String, indice: String, texte := "") -> LineEdit:
	var e := LineEdit.new()
	e.name = nom
	e.placeholder_text = indice
	e.text = texte
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_size_override("font_size", 28)
	e.max_length = 64
	e.context_menu_enabled = false
	e.virtual_keyboard_enabled = true
	e.select_all_on_focus = false
	var normal := MenuStyle._boite(Color(0.02, 0.03, 0.045, 0.9), MenuStyle.ACIER_SOMBRE, 1.5)
	var actif := MenuStyle._boite(Color(0.03, 0.06, 0.10, 0.95), MenuStyle.LUEUR, 2.0)
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", actif)
	e.add_theme_stylebox_override("read_only", normal)
	e.add_theme_color_override("font_color", MenuStyle.GIVRE)
	e.add_theme_color_override("font_placeholder_color", Color(MenuStyle.ETEINT, 0.9))
	e.add_theme_color_override("caret_color", MenuStyle.LUEUR)
	e.add_theme_color_override("selection_color", Color(MenuStyle.LUEUR, 0.35))
	e.focus_entered.connect(func() -> void: son.emit("survol"))
	e.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			e.accept_event()
			retour())
	return e

func _vue(nom: String, pile: VBoxContainer, ecart := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Vue_" + nom
	v.visible = false
	v.add_theme_constant_override("separation", ecart)
	pile.add_child(v)
	_vues[nom] = v
	return v

func _construire_choix(pile: VBoxContainer) -> void:
	var v := _vue("choix", pile, 18)
	var l := Label.new()
	l.text = "Jouer à deux, trois ou quatre : un joueur héberge le monde,\nles autres le rejoignent avec leur propre personnage."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 25)
	v.add_child(l)
	_b_choix_heberger = _bouton("Héberger une partie", func() -> void: _aller("heberger"), "BoutonHeberger")
	_b_choix_rejoindre = _bouton("Rejoindre une partie", func() -> void: _aller("rejoindre"), "BoutonRejoindre")
	_b_choix_heberger_net = _bouton("Héberger par Internet (code)", func() -> void: _choisir_internet(true), "BoutonHebergerInternet")
	_b_choix_rejoindre_code = _bouton("Rejoindre avec un code", func() -> void: _choisir_internet(false), "BoutonRejoindreCode")
	var retour_b := _bouton("Retour", retour, "BoutonRetour")
	var boutons_choix: Array[Button] = [_b_choix_heberger, _b_choix_rejoindre, _b_choix_heberger_net, _b_choix_rejoindre_code, retour_b]
	for b in boutons_choix:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(520, 0)
		v.add_child(b)
	v.set_meta("focus", _b_choix_heberger)
	v.set_meta("boutons", boutons_choix)

func _construire_heberger(pile: VBoxContainer) -> void:
	var v := _vue("heberger", pile)
	v.add_child(_etiquette("Monde à héberger (Gauche / Droite pour changer)"))
	_b_monde = _bouton("", func() -> void: _changer_monde(1), "ChoixMonde")
	_b_monde.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_b_monde.add_theme_font_size_override("font_size", 25)
	_b_monde.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left"):
			_b_monde.accept_event()
			_changer_monde(-1)
		elif ev.is_action_pressed("ui_right"):
			_b_monde.accept_event()
			_changer_monde(1))
	v.add_child(_b_monde)
	v.add_child(_etiquette("Votre nom"))
	_champ_nom_h = _champ("NomHote", "Nom du joueur")
	v.add_child(_champ_nom_h)
	_etq_port = _etiquette("Port (%d par défaut ; à ouvrir sur la box pour jouer par Internet)" % PORT_DEFAUT)
	v.add_child(_etq_port)
	_champ_port_h = _champ("PortHote", str(PORT_DEFAUT))
	v.add_child(_champ_port_h)
	_case_pvp = CheckBox.new()
	_case_pvp.name = "CasePvp"
	_case_pvp.text = "Combat entre joueurs (PvP) : sorts, télékinésie et flèches touchent les autres joueurs"
	_case_pvp.focus_mode = Control.FOCUS_ALL
	_case_pvp.add_theme_font_size_override("font_size", 22)
	_case_pvp.button_pressed = (not PvpCoop.arg_sans_pvp()) and PvpCoop.charger_reglage()
	_case_pvp.focus_entered.connect(func() -> void: son.emit("survol"))
	v.add_child(_case_pvp)
	_b_ouvrir = _bouton("Ouvrir la partie", _ouvrir_partie, "BoutonOuvrir")
	var retour_b := _bouton("Retour", retour, "BoutonRetourHeberger")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 30)
	h.add_child(_b_ouvrir)
	h.add_child(retour_b)
	v.add_child(h)
	v.set_meta("focus", _b_monde)
	v.set_meta("boutons", [_b_monde, _champ_nom_h, _champ_port_h, _case_pvp, _b_ouvrir, retour_b])
	_champ_nom_h.text_submitted.connect(func(_t: String) -> void: _champ_port_h.grab_focus())
	_champ_port_h.text_submitted.connect(func(_t: String) -> void: _b_ouvrir.grab_focus())

func _construire_rejoindre(pile: VBoxContainer) -> void:
	var v := _vue("rejoindre", pile)
	_etq_adresse = _etiquette("Adresse de l'hôte (IP:port)")
	v.add_child(_etq_adresse)
	_champ_adresse = _champ("Adresse", "exemple : 192.168.1.20:%d" % PORT_DEFAUT)
	v.add_child(_champ_adresse)
	v.add_child(_etiquette("Votre nom"))
	_champ_nom_r = _champ("NomInvite", "Nom du joueur")
	v.add_child(_champ_nom_r)
	_b_connecter = _bouton("Se connecter", _connecter, "BoutonConnecter")
	var retour_b := _bouton("Retour", retour, "BoutonRetourRejoindre")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 30)
	h.add_child(_b_connecter)
	h.add_child(retour_b)
	v.add_child(h)
	v.set_meta("focus", _champ_adresse)
	v.set_meta("boutons", [_champ_adresse, _champ_nom_r, _b_connecter, retour_b])
	_champ_adresse.text_submitted.connect(func(_t: String) -> void: _champ_nom_r.grab_focus())
	_champ_nom_r.text_submitted.connect(func(_t: String) -> void: _b_connecter.grab_focus())

func _construire_connexion(pile: VBoxContainer) -> void:
	var v := _vue("connexion", pile, 22)
	_texte_connexion = Label.new()
	_texte_connexion.text = "Connexion à l'hôte…"
	_texte_connexion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte_connexion.add_theme_font_size_override("font_size", 28)
	v.add_child(_texte_connexion)
	var annuler := _bouton("Annuler", retour, "BoutonAnnuler")
	annuler.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(annuler)
	v.set_meta("focus", annuler)
	v.set_meta("boutons", [annuler])

func _construire_salon(pile: VBoxContainer) -> void:
	var v := _vue("salon", pile)
	_titre_salon = _etiquette("Joueurs")
	_titre_salon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_titre_salon)
	_liste_joueurs = VBoxContainer.new()
	_liste_joueurs.name = "ListeJoueurs"
	_liste_joueurs.add_theme_constant_override("separation", 6)
	v.add_child(_liste_joueurs)
	_etat_salon = Label.new()
	_etat_salon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etat_salon.add_theme_font_size_override("font_size", 24)
	_etat_salon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_salon.custom_minimum_size = Vector2(740, 0)
	v.add_child(_etat_salon)
	_b_lancer = _bouton("Lancer la partie", _lancer_hote, "BoutonLancer")
	var quitter := _bouton("Quitter le salon", retour, "BoutonQuitterSalon")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 30)
	h.add_child(_b_lancer)
	h.add_child(quitter)
	v.add_child(h)
	v.set_meta("focus", _b_lancer)
	v.set_meta("boutons", [_b_lancer, quitter])

# ---------- navigation ----------

## Ouvre le panneau sur le choix Héberger / Rejoindre (appelé par l'écran titre).
func ouvrir() -> void:
	_avis.text = ""
	_actualiser_mondes()
	_aller("choix")

func _aller(nom: String) -> void:
	vue = nom
	if nom == "choix" and (_internet or _eos != null):
		_abandonner_internet()
	for k in _vues:
		(_vues[k] as Control).visible = k == nom
	_avis.text = ""
	_etq_port.visible = not _internet
	_champ_port_h.visible = not _internet
	_etq_adresse.text = "Code du salon (6 caractères, donné par l'hôte)" if _internet else "Adresse de l'hôte (IP:port)"
	_champ_adresse.placeholder_text = "exemple : K7PQ4X" if _internet else "exemple : 192.168.1.20:%d" % PORT_DEFAUT
	_b_ouvrir.text = "Ouvrir le salon" if _internet else "Ouvrir la partie"
	_b_connecter.text = "Rejoindre le salon" if _internet else "Se connecter"
	if nom == "heberger":
		_actualiser_mondes()
	if nom == "salon":
		_maj_salon()
	var v: Control = _vues[nom]
	var liste: Array = v.get_meta("boutons")
	for i in liste.size():   # parcours Haut/Bas en boucle (les champs de saisie en font partie)
		var c: Control = liste[i]
		c.focus_neighbor_top = c.get_path_to(liste[(i - 1 + liste.size()) % liste.size()])
		c.focus_neighbor_bottom = c.get_path_to(liste[(i + 1) % liste.size()])
	(v.get_meta("focus") as Control).grab_focus.call_deferred()

## Échap / B / « Retour » : remonte d'un cran ; depuis le choix, referme le panneau.
func retour() -> void:
	son.emit("retour")
	match vue:
		"heberger", "rejoindre":
			_aller("choix")
		"connexion":
			_quitter_reseau()
			_aller("rejoindre")
		"salon":
			var cible := "heberger" if _role == "hote" else "rejoindre"
			_quitter_reseau()
			_aller(cible)
		_:
			ferme.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		retour()

# ---------- Héberger ----------

func _actualiser_mondes() -> void:
	_emplacements.clear()
	for e: int in Sauvegardes.tous():
		if Sauvegardes.valide(e):
			_emplacements.append(e)
	_emplacements.append(NOUVEAU_MONDE)
	var recent := Sauvegardes.plus_recent()
	_indice_monde = maxi(0, _emplacements.find(recent)) if recent >= 0 else _emplacements.size() - 1
	_maj_texte_monde()

func _changer_monde(pas: int) -> void:
	_indice_monde = (_indice_monde + pas + _emplacements.size()) % _emplacements.size()
	son.emit("survol")
	_maj_texte_monde()

func texte_monde(emplacement: int) -> String:
	if emplacement == NOUVEAU_MONDE:
		return "Nouveau monde"
	var r := Sauvegardes.resume(emplacement)
	var t: String = Sauvegardes.ligne(r)
	if not r["vide"] and float(r["heure"]) >= 0.0:
		t += " — %dh%02d" % [int(float(r["heure"])) % 24, int(fmod(float(r["heure"]), 1.0) * 60.0)]
	return t

func _maj_texte_monde() -> void:
	var e: int = _emplacements[_indice_monde]
	_b_monde.text = ("‹  %s  ›" % texte_monde(e)) if _emplacements.size() > 1 else texte_monde(e)

## Emplacement de monde actuellement choisi (NOUVEAU_MONDE = partie neuve).
func monde_choisi() -> int:
	return _emplacements[_indice_monde] if not _emplacements.is_empty() else NOUVEAU_MONDE

func _ouvrir_partie() -> void:
	var n := analyser_nom(_champ_nom_h.text)
	if not n["ok"]:
		_avis.text = n["erreur"]
		_champ_nom_h.grab_focus()
		return
	if _internet:
		_ouvrir_salon_internet(n["nom"])
		return
	var p := analyser_port(_champ_port_h.text)
	if not p["ok"]:
		_avis.text = p["erreur"]
		_champ_port_h.grab_focus()
		return
	var r := _R()
	r.set("nom_joueur", n["nom"])
	var err: int = r.call("heberger", int(p["port"]))
	if err != OK:
		_avis.text = texte_erreur(err, int(p["port"]))
		return
	r.set("infos_partie", {"lancee": false, "monde": texte_monde(monde_choisi())})
	if persistance:
		sauver_prefs(n["nom"], "", int(p["port"]))
	PvpCoop.definir(_case_pvp.button_pressed, persistance)   # réglage de l'hôte, diffusé aux invités
	_role = "hote"
	_abonner()
	_aller("salon")

## joueur_base : appelé avec la suite du lancement quand l'hôte lance un NOUVEAU monde (l'écran titre y ouvre le choix du personnage,
## puis appelle la suite) ; non défini = lancement direct. Les invités ne sont prévenus (salon_lancer) qu'une fois le choix validé.
var choix_avant_lancement: Callable

func _lancer_hote() -> void:
	if _role != "hote":
		return
	if monde_choisi() == NOUVEAU_MONDE and choix_avant_lancement.is_valid():
		choix_avant_lancement.call(_lancer_hote_suite)
		return
	_lancer_hote_suite()

func _lancer_hote_suite() -> void:
	if _role != "hote":
		return
	var r := _R()
	var infos: Dictionary = r.get("infos_partie")
	infos["lancee"] = true
	r.set("infos_partie", infos)
	r.call("envoyer_evenement", "salon_lancer", 0, {})
	var e := monde_choisi()
	_desabonner()
	lancer_partie.emit("hote", e == NOUVEAU_MONDE, e)

# ---------- Rejoindre ----------

func _connecter() -> void:
	if _internet:
		_rejoindre_salon_internet()
		return
	var a := analyser_adresse(_champ_adresse.text)
	if not a["ok"]:
		_avis.text = a["erreur"]
		_champ_adresse.grab_focus()
		return
	var n := analyser_nom(_champ_nom_r.text)
	if not n["ok"]:
		_avis.text = n["erreur"]
		_champ_nom_r.grab_focus()
		return
	var r := _R()
	r.set("nom_joueur", n["nom"])
	var err: int = r.call("rejoindre", String(a["ip"]), int(a["port"]))
	if err != OK:
		_avis.text = texte_erreur(err, int(a["port"]))
		return
	if persistance:
		sauver_prefs(n["nom"], _champ_adresse.text.strip_edges(), int(a["port"]))
	_role = "invite"
	_abonner()
	_texte_connexion.text = "Connexion à %s:%d…" % [a["ip"], a["port"]]
	_aller("connexion")

func _sur_reussie() -> void:
	if _role != "invite":
		return
	var infos: Variant = _R().get("infos_hote")
	if infos is Dictionary and bool((infos as Dictionary).get("lancee", false)):
		_desabonner()
		lancer_partie.emit("invite", false, -1)   # partie déjà lancée : on rejoint en cours
		return
	_aller("salon")

func _sur_echec() -> void:
	if _role != "invite":
		return
	var msg := String(_R().get("derniere_erreur"))
	_aller("rejoindre")
	_avis.text = msg if msg != "" else "Connexion impossible."

func _sur_lancer(expediteur: int, _id: Variant, _d: Variant) -> void:
	if _role == "invite" and expediteur == 1:
		_desabonner()
		lancer_partie.emit("invite", false, -1)

func _sur_perdu(id: int) -> void:
	# l'hôte part pendant l'attente dans le salon
	if _role == "invite" and id == 1 and vue == "salon":
		var msg := String(_R().get("derniere_erreur"))
		_aller("rejoindre")
		_avis.text = msg if msg != "" else "L'hôte a fermé la partie."

# ---------- salon ----------

func _maj_salon() -> void:
	if _liste_joueurs == null:
		return
	for c in _liste_joueurs.get_children():
		_liste_joueurs.remove_child(c)
		c.queue_free()
	var r := _R()
	var ids: Array = r.call("joueurs")
	var moi: int = r.call("mon_id")
	_titre_salon.text = "Joueurs connectés : %d / %d" % [ids.size(), int(r.call("max_joueurs"))]
	for id: int in ids:
		var nom := String((r.get("registre") as Object).call("infos", id).get("nom", "Joueur"))
		var etiquettes := PackedStringArray()
		if id == 1:
			etiquettes.append("hôte")
		if id == moi:
			etiquettes.append("vous")
		var l := Label.new()
		l.name = "Joueur%d" % id
		l.text = "◆  %s%s" % [nom, ("   (%s)" % ", ".join(etiquettes)) if not etiquettes.is_empty() else ""]
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", MenuStyle.GIVRE if id == moi else MenuStyle.ARGENT)
		_liste_joueurs.add_child(l)
	var hote := _role == "hote"
	_b_lancer.visible = hote
	if hote and _code_salon != "":
		_etat_salon.text = "CODE DU SALON :  %s\nDonnez ce code aux autres joueurs (ils choisissent « Rejoindre avec un code »).\nLancer la partie quand tout le monde est là ; un joueur peut aussi rejoindre ensuite." % _code_salon
	else:
		_etat_salon.text = ("Communiquer l'adresse IP et le port (%d) aux autres joueurs.\nLancer la partie quand tout le monde est là ; un joueur peut aussi rejoindre ensuite." % _port_hote()) if hote \
		else "En attente du lancement de la partie par l'hôte…"
	(_vues["salon"] as Control).set_meta("focus", _b_lancer if hote else (_vues["salon"] as Control).get_meta("boutons")[1])

# ---------- Internet (relais Epic EOS) ----------

## Clic sur « Héberger par Internet » / « Rejoindre avec un code » : vérifie que EOS est utilisable, sinon explique quoi faire.
func _choisir_internet(heberger: bool) -> void:
	var t := ReseauTransportEOS.new()
	if not t.disponible():
		_avis.text = t.aide_configuration()
		return
	_eos = t
	_internet = true
	_aller("heberger" if heberger else "rejoindre")

## Revient à ENet : ferme le salon EOS éventuel et rend à Reseau son transport d'origine.
func _abandonner_internet() -> void:
	_operation += 1
	if _eos != null:
		_eos.fermer_salon_async()   # coroutine : lancée sans attendre
	_restaurer_transport()
	_eos = null
	_internet = false
	_code_salon = ""

func _installer_transport_eos() -> void:
	var r := _R()
	if _transport_avant == null:
		_transport_avant = r.get("transport")
	r.set("transport", _eos)

func _restaurer_transport() -> void:
	if _transport_avant != null:
		_R().set("transport", _transport_avant)
		_transport_avant = null

func _ouvrir_salon_internet(nom: String) -> void:
	_operation += 1
	var mon_op := _operation
	var t := _eos
	t.nom_joueur = nom
	_b_ouvrir.disabled = true
	_avis.text = "Connexion au relais Epic…"
	var code: String = await t.ouvrir_salon_async()
	if mon_op != _operation or not is_inside_tree():
		return   # annulé entre-temps
	_b_ouvrir.disabled = false
	if code == "":
		_avis.text = t.message if t.message != "" else "Impossible d'ouvrir le salon."
		return
	_installer_transport_eos()
	var r := _R()
	r.set("nom_joueur", nom)
	var err: int = r.call("heberger", 0)
	if err != OK:
		_avis.text = t.message if t.message != "" else texte_erreur(err, 0)
		t.fermer_salon_async()
		_restaurer_transport()
		return
	r.set("infos_partie", {"lancee": false, "monde": texte_monde(monde_choisi())})
	if persistance:
		sauver_prefs(nom, "", PORT_DEFAUT)
	_code_salon = code
	_role = "hote"
	_abonner()
	_aller("salon")

func _rejoindre_salon_internet() -> void:
	var code := ReseauSalonCode.normaliser(_champ_adresse.text)
	if code == "":
		_avis.text = "Code invalide : 6 caractères (lettres sans I, L, O, et chiffres de 2 à 9), par exemple K7PQ4X."
		_champ_adresse.grab_focus()
		return
	var n := analyser_nom(_champ_nom_r.text)
	if not n["ok"]:
		_avis.text = n["erreur"]
		_champ_nom_r.grab_focus()
		return
	_operation += 1
	var mon_op := _operation
	var t := _eos
	t.nom_joueur = n["nom"]
	_b_connecter.disabled = true
	_avis.text = "Recherche du salon %s…" % code
	var trouve: bool = await t.rejoindre_salon_async(code)
	if mon_op != _operation or not is_inside_tree():
		return
	_b_connecter.disabled = false
	if not trouve:
		_avis.text = t.message if t.message != "" else "Salon introuvable."
		return
	_installer_transport_eos()
	var r := _R()
	r.set("nom_joueur", n["nom"])
	var err: int = r.call("rejoindre", "", 0)
	if err != OK:
		_avis.text = t.message if t.message != "" else texte_erreur(err, 0)
		t.fermer_salon_async()
		_restaurer_transport()
		return
	if persistance:
		sauver_prefs(n["nom"], "", PORT_DEFAUT)
	_role = "invite"
	_abonner()
	_texte_connexion.text = "Connexion au salon %s (relais Epic)…" % code
	_aller("connexion")

func _port_hote() -> int:
	return int(analyser_port(_champ_port_h.text)["port"]) if _champ_port_h != null else PORT_DEFAUT

# ---------- réseau ----------

func _abonner() -> void:
	if _abonne:
		return
	_abonne = true
	var r := _R()
	r.connect("joueur_connecte", _sur_joueur)
	r.connect("joueur_deconnecte", _sur_joueur_parti)
	r.connect("connexion_reussie", _sur_reussie)
	r.connect("connexion_echouee", _sur_echec)
	r.call("abonner", "salon_lancer", _sur_lancer)

func _desabonner() -> void:
	if not _abonne:
		return
	_abonne = false
	var r := _R()
	if r == null:
		return
	for sig in [["joueur_connecte", _sur_joueur], ["joueur_deconnecte", _sur_joueur_parti], ["connexion_reussie", _sur_reussie], ["connexion_echouee", _sur_echec]]:
		if r.is_connected(sig[0], sig[1]):
			r.disconnect(sig[0], sig[1])
	r.call("desabonner", "salon_lancer", _sur_lancer)

func _sur_joueur(_id: int) -> void:
	if vue == "salon":
		_maj_salon()

func _sur_joueur_parti(id: int) -> void:
	if vue == "salon":
		_maj_salon()
	_sur_perdu(id)

## Coupe la connexion (retour hors ligne) et arrête d'écouter.
func _quitter_reseau() -> void:
	_desabonner()
	var r := _R()
	if r != null and bool(r.call("est_en_ligne")):
		r.call("deconnecter")
	if _eos != null:   # jeu par Internet : ferme le salon et rend ENet à Reseau
		_operation += 1
		_eos.fermer_salon_async()
		_restaurer_transport()
		_code_salon = ""
	_role = ""
