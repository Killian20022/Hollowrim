class_name FenetreCoffre
extends CanvasLayer
## Fenêtre de TRANSFERT coffre sûr ↔ sac (lot E, Q9 c), fidèle à la maquette A_3 (Desktop/Skyrim captures/maquettes_menu/png/
## A_3_coffre.png, direction A « parchemin et cuir enluminé ») : un codex ouvert, page gauche = le coffre (loué chez Grima, ou
## celui de la maison), page droite = le sac ; ruban vermillon qui enjambe la reliure sur la ligne choisie, vers la page d'arrivée.
##   - signets « Coffre » / « Sac » : la page active (Tab, flèches gauche/droite, Q/D physiques A/D, LB/RB, clic sur une page) ;
##   - E / Entrée / Espace / A (manette) = prendre ou ranger 1 (pièces : 100) ; Maj+E / X = toute la pile ; R / Y = tout prendre
##     ou tout ranger ; haut/bas, Z/S, molette, survol = choisir ; Échap, clic droit, B = fermer ; clic gauche sur une ligne = 1 ;
##   - poids du sac AVANT / APRÈS le transfert choisi (barre d'encre et trait vermillon), contenu du coffre (sans limite) ;
##   - objets de quête : jamais rangés (Stockage.refus_transfert) : sceau de cire, ligne grisée, raison en vermillon ;
##   - jeu en PAUSE ; règles : Stockage (transferer) ; le sac peut dépasser sa capacité (surcharge, jamais bloqué) ;
##   - une arme tenue rangée au coffre quitte la main (sinon on la tiendrait encore depuis le coffre).
## Une instance, créée par ServicesPnj ; ouverte par l'objet « coffre » posé dans l'intérieur (E).

const GROUPE := "fenetre_coffre"
const SIGNETS := ["Coffre", "Sac"]
const PAS_PIECES := 100

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
var id_coffre := ""
var coffre: Conteneur
## 0 = page du coffre (prendre), 1 = page du sac (ranger).
var cote := 0
var lignes := [[], []]        # ids par page (« pieces » en tête si la page a des pièces)
var choix := [0, 0]

var _livre: LivreParchemin
var _haut := [0, 0]
var _souris := Input.MOUSE_MODE_CAPTURED
var _avis := ""
var _avis_bon := false
var _avis_t := 0.0

static func trouver(n: Node) -> FenetreCoffre:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as FenetreCoffre

func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUPE)
	_livre = LivreParchemin.new()
	_livre.visible = false
	_livre.dessin = _dessiner
	add_child(_livre)

## Ouvre le coffre sûr `id` (Stockage.COFFRES) ; false s'il est inconnu, fermé (maison pas achetée) ou déjà ouvert.
func ouvrir(id: String) -> bool:
	if ouvert or joueur == null or not Stockage.accessible(id):
		return false
	id_coffre = id
	coffre = Stockage.conteneur(id)
	cote = 0 if not coffre.vide() else 1
	choix = [0, 0]
	_haut = [0, 0]
	_avis_t = 0.0
	ouvert = true
	_remplir()
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_livre.visible = true
	_livre.echelle()
	_livre.rafraichir()
	Sons.jouer(self, ["doorOpen_1", "creak1"], -14.0)
	return true

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_livre.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED

func _sac() -> Inventaire:
	return joueur.inventaire

func _source() -> Conteneur:
	return coffre if cote == 0 else _sac()

func _dest() -> Conteneur:
	return _sac() if cote == 0 else coffre

## Lignes de chaque page : pièces d'abord, puis les objets dans l'ordre d'arrivée ; au sac, les objets de quête en bas.
func _remplir() -> void:
	for c in 2:
		var k: Conteneur = coffre if c == 0 else _sac()
		var l: Array = []
		if k.pieces > 0:
			l.append("pieces")
		var bas: Array = []
		for id: String in k.objets:
			if int(k.objets[id]) <= 0:
				continue
			if c == 1 and Inventaire.est_quete(id):
				bas.append(id)
			else:
				l.append(id)
		l.append_array(bas)
		lignes[c] = l
		choix[c] = clampi(choix[c], 0, maxi(0, l.size() - 1))
	_suivre()
	_livre.rafraichir()

func changer_cote(c: int) -> void:
	var n := posmod(c, 2)
	if n != cote:
		cote = n
		_suivre()
		_livre.rafraichir()
		Sons.jouer(self, ["cloth1"], -16.0)

## Identifiant choisi sur la page active ("" si vide).
func choisi() -> String:
	var l: Array = lignes[cote]
	return String(l[choix[cote]]) if choix[cote] < l.size() else ""

## Combien d'exemplaires bouge une action : 1 (100 pour les pièces) ou toute la pile.
func _quantite(id: String, pile: bool) -> int:
	var dispo := _source().nombre(id)
	if pile:
		return dispo
	return mini(dispo, PAS_PIECES if id == "pieces" else 1)

## Transfert de la ligne choisie (ou `i`) vers l'autre page : 1 ou toute la pile. "" si fait, sinon la raison.
func transferer(pile := false, i := -1) -> String:
	if not ouvert:
		return "Fermé."
	if i >= 0:
		choix[cote] = clampi(i, 0, maxi(0, (lignes[cote] as Array).size() - 1))
	var id := choisi()
	if id == "":
		return _refus("Rien à %s." % ("prendre" if cote == 0 else "ranger"))
	var n := _quantite(id, pile)
	var r := Stockage.transferer(_source(), _dest(), id, n)
	if r != "":
		return _refus(r)
	_apres_transfert(id)
	_annoncer("%s %s x%s" % ["Pris :" if cote == 0 else "Rangé :", _nom(id), LivreParchemin.nombre(n)], true)
	Sons.jouer(self, ["handleCoins", "handleCoins2"] if id == "pieces" else ["cloth1", "cloth2"], -8.0)
	_remplir()
	return ""

## Tout prendre (page du coffre) ou tout ranger (page du sac, sauf les objets de quête). Renvoie le nombre de lignes bougées.
func tout() -> int:
	if not ouvert:
		return 0
	var n := 0
	var refus := 0
	for id: String in (lignes[cote] as Array).duplicate():
		var r := Stockage.transferer(_source(), _dest(), id, _source().nombre(id))
		if r == "":
			n += 1
			_apres_transfert(id)
		else:
			refus += 1
	if n > 0:
		_annoncer(("Tout pris" if cote == 0 else "Tout rangé") + (" (objets de quête gardés sur vous)" if refus > 0 else "."), true)
		Sons.jouer(self, ["cloth1", "cloth2"], -6.0)
	elif refus > 0:
		_refus("Objet de quête : on le garde sur soi.")
	_remplir()
	return n

## Une arme rangée qui était en main quitte la main ; le sac trop lourd le dit.
func _apres_transfert(id: String) -> void:
	if cote == 1:
		var eq: Object = Forge._eq(joueur)
		if eq != null and not _sac().a(id):
			for m in ["gauche", "droite"]:
				if String((eq.get("mains") as Dictionary)[m].get("id", "")) == id:
					eq.call("equiper", m, "vide")
	elif _sac().surcharge() and hud != null and hud.has_method("avis"):
		hud.avis("Sac trop lourd : vous marcherez lentement.")

func _nom(id: String) -> String:
	return "pièces" if id == "pieces" else _sac().nom(id)

func _refus(r: String) -> String:
	_annoncer(r, false)
	Sons.jouer(self, ["cloth1"], -16.0)
	return r

func _annoncer(t: String, bon: bool) -> void:
	_avis = t
	_avis_bon = bon
	_avis_t = 2.4
	_livre.rafraichir()

func _choisir(i: int) -> void:
	var l: Array = lignes[cote]
	if l.is_empty():
		return
	var n := clampi(i, 0, l.size() - 1)
	if n != choix[cote]:
		choix[cote] = n
		_suivre()
		_livre.rafraichir()

func _max_lignes() -> int:
	return maxi(3, int((_livre.hauteur() - 64.0 - 74.0) / LivreParchemin.LIGNE))

func _suivre() -> void:
	var m := _max_lignes()
	for c in 2:
		var n := (lignes[c] as Array).size()
		if choix[c] < _haut[c]:
			_haut[c] = choix[c]
		elif choix[c] >= _haut[c] + m:
			_haut[c] = choix[c] - m + 1
		_haut[c] = clampi(_haut[c], 0, maxi(0, n - m))

# ------------------------------------------------------------------ entrées

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	var vp := get_viewport()
	if e is InputEventKey:
		var k := e as InputEventKey
		vp.set_input_as_handled()
		if not k.pressed:
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			return
		match k.physical_keycode:
			KEY_ESCAPE:
				fermer()
			KEY_TAB:
				changer_cote(cote + 1)
			KEY_LEFT, KEY_A:
				changer_cote(0)
			KEY_RIGHT, KEY_D:
				changer_cote(1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				transferer(k.shift_pressed)
			KEY_R:
				tout()
			KEY_UP, KEY_W:
				_choisir(choix[cote] - 1)
			KEY_DOWN, KEY_S:
				_choisir(choix[cote] + 1)
	elif e is InputEventJoypadButton:
		vp.set_input_as_handled()
		if not e.pressed:
			return
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				transferer()
			JOY_BUTTON_X:
				transferer(true)
			JOY_BUTTON_Y:
				tout()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
				changer_cote(0)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
				changer_cote(1)
			JOY_BUTTON_DPAD_UP:
				_choisir(choix[cote] - 1)
			JOY_BUTTON_DPAD_DOWN:
				_choisir(choix[cote] + 1)
	elif e is InputEventMouseMotion:
		vp.set_input_as_handled()
		var z := _livre.zone((e as InputEventMouseMotion).position)
		if z.begins_with("ligne:"):
			var p := z.substr(6).split(":")
			if int(p[0]) != cote:
				changer_cote(int(p[0]))
			_choisir(int(p[1]))
	elif e is InputEventMouseButton:
		vp.set_input_as_handled()
		var b := e as InputEventMouseButton
		if not b.pressed:
			return
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_choisir(choix[cote] - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_choisir(choix[cote] + 1)
			MOUSE_BUTTON_RIGHT:
				fermer()
			MOUSE_BUTTON_LEFT:
				var z := _livre.zone(b.position)
				if z.begins_with("ligne:"):
					var p := z.substr(6).split(":")
					changer_cote(int(p[0]))
					transferer(b.shift_pressed, int(p[1]))
				elif z.begins_with("onglet:"):
					changer_cote(int(z.substr(7)))
				elif z == "un":
					transferer()
				elif z == "pile":
					transferer(true)
				elif z == "tout":
					tout()
				elif z == "signet":
					changer_cote(cote + 1)
				elif z == "fermer":
					fermer()

# ------------------------------------------------------------------ dessin

func _process(dt: float) -> void:
	if not ouvert:
		return
	if _livre.echelle():
		_suivre()
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_livre.rafraichir()

func _poids_ligne(k: Conteneur, id: String) -> float:
	return 0.0 if id == "pieces" else float(Inventaire.objet(id).get("poids", 0.0)) * k.nombre(id)

## Registre d'une page : en-têtes Objet / Nb / Kg, lignes de 18 px, ligne choisie (si page active).
func _liste(L: LivreParchemin, c: int, X: float, LG: float) -> void:
	var k: Conteneur = coffre if c == 0 else _sac()
	L.texte(X + 18, 52, "Objet", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG - 34, 52, "Nb", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG, 52, "Kg", LivreParchemin.RUBRIQUE)
	L.regle(X, 61, LG)
	var l: Array = lignes[c]
	var m := _max_lignes()
	var vis := mini(l.size(), m)
	if l.is_empty():
		L.paragraphe(X + 4, 70, LG - 8, "Le coffre est vide." if c == 0 else "Votre sac est vide.", LivreParchemin.PALE)
	for j in vis:
		var i: int = _haut[c] + j
		var id := String(l[i])
		var y := 64.0 + j * LivreParchemin.LIGNE
		var r := Rect2(X, y, LG, 17)
		var quete := c == 1 and id != "pieces" and Inventaire.est_quete(id)
		L.ligne(r, c == cote and i == choix[c], quete)
		L.zones["ligne:%d:%d" % [c, i]] = r
		if id == "pieces":
			L.piece(Vector2(X + 5, y + 5))
		else:
			L.icone(id, Vector2(X + 1, y + 1), 16.0, 0.6 if quete else 1.0)
		var n := k.nombre(id)
		var nom := "Pièces" if id == "pieces" else k.nom(id)
		var c_nom := LivreParchemin.OR_TERNI if id == "pieces" else (LivreParchemin.PALE if quete else LivreParchemin.ENCRE)
		L.texte(X + 20, y + 4, L.couper(nom, LG - 20 - 76), c_nom)
		if quete:
			L.sceau(Vector2(X + LG - 64, y + 8))
		if n > 1:
			L.texte_d(X + LG - 34, y + 4, "x" + LivreParchemin.nombre(n), LivreParchemin.PALE)
		if id != "pieces":
			L.texte_d(X + LG, y + 4, LivreParchemin.kg(_poids_ligne(k, id)))
		L.regle(X, y + 17, LG)
	if l.size() > vis:
		if _haut[c] > 0:
			L.texte(X + LG - 6, 52, "^", LivreParchemin.RUBRIQUE)
		if _haut[c] + vis < l.size():
			L.texte(X + LG + 3, 64.0 + (vis - 1) * LivreParchemin.LIGNE + 4.0, "v", LivreParchemin.RUBRIQUE)

func _dessiner(L: LivreParchemin) -> void:
	if not ouvert:
		return
	var sac := _sac()
	var W := L.size.x
	var H := L.hauteur()
	var mi := L.milieu()
	var niv := 1
	var prog: Variant = joueur.get("progression")
	if prog != null:
		niv = int(prog.niveau)
	L.en_tete("Voyageur · niveau %d" % niv, "Poids %s / %d" % [LivreParchemin.kg(sac.poids()), roundi(sac.capacite())])
	L.onglets(SIGNETS, cote)
	var X := 17.0
	var LG := mi - 8.0 - X - 6.0
	var X2 := mi + 8.0
	var LD := W - 17.0 - X2
	L.zones["page:0"] = Rect2(X, 20, LG, H - 60)
	# --- page gauche : le coffre
	var maison := id_coffre == "coffre_maison"
	var fin_titre := L.titre(19, 24, "Coffre", "de la maison" if maison else "loué chez Grima")
	if not maison and fin_titre + 8.0 + L.larg("Skarnholt") <= X + LG:   # 480x270 : pas la place, on l'omet
		L.texte_d(X + LG, 30, "Skarnholt", LivreParchemin.OR_TERNI)
	_liste(L, 0, X, LG)
	var nb := coffre.objets.size()
	L.texte(19, H - 54, "%d objet%s" % [nb, "s" if nb > 1 else ""], LivreParchemin.PALE)
	L.texte_d(X + LG, H - 54, "Contenu %s kg" % LivreParchemin.kg(coffre.poids()))
	L.texte(19, H - 40, "Sans limite de poids : le coffre ne s'use pas.", LivreParchemin.PALE)
	# --- page droite : le sac
	L.titre(X2 + 4, 24, "Sac", "du voyageur")
	_liste(L, 1, X2, LD)
	# flèche de transfert sur la ligne choisie de la page active (vers la page d'arrivée)
	var lc: Array = lignes[cote]
	var jc: int = choix[cote] - _haut[cote]
	if not lc.is_empty() and jc >= 0 and jc < _max_lignes():
		L.fleche(64.0 + jc * LivreParchemin.LIGNE, cote == 0)
	# poids avant / après le transfert choisi (1 exemplaire)
	var cap := sac.capacite()
	var avant := sac.poids()
	var id := choisi()
	var delta := 0.0
	if id != "" and id != "pieces":
		var w := float(Inventaire.objet(id).get("poids", 0.0)) * _quantite(id, false)
		delta = w if cote == 0 else -w
	var refus := ""
	if id != "":
		refus = Stockage.refus_transfert(_source(), _dest(), id, maxi(1, _quantite(id, false)))
	var yb := H - 66.0
	L.texte(X2 + 2, yb, "Poids", LivreParchemin.RUBRIQUE)
	var cbarre := Color("#8a5a32") if avant <= cap else LivreParchemin.RUBRIQUE
	L.barre(X2 + 36, yb + 1, LD - 36 - 64, avant / maxf(1.0, cap), cbarre, (avant + delta) / maxf(1.0, cap) if delta != 0.0 and refus == "" else -1.0)
	L.texte_d(X2 + LD, yb, "%s/%d" % [LivreParchemin.kg(avant), roundi(cap)])
	if delta != 0.0 and refus == "":
		var apres := "Après : %s / %d" % [LivreParchemin.kg(avant + delta), roundi(cap)]
		L.texte(X2 + 2, yb + 14, apres, LivreParchemin.RUBRIQUE if avant + delta > cap else LivreParchemin.ENCRE)
		L.texte(X2 + 2 + L.larg(apres) + 14, yb + 14, ("+%s kg" if delta > 0.0 else "-%s kg") % LivreParchemin.kg(absf(delta)), LivreParchemin.RUBRIQUE if delta > 0.0 else LivreParchemin.VERT)
	elif refus != "":
		L.texte(X2 + 2, yb + 14, L.couper(refus, LD - 4), LivreParchemin.RUBRIQUE)
	L.texte(X2 + 2, yb + 26, "Pièces %s" % LivreParchemin.nombre(sac.pieces), LivreParchemin.OR_TERNI)
	if _avis_t > 0.0:
		L.texte_d(X2 + LD, yb + 26, L.couper(_avis, LD - 90), LivreParchemin.VERT if _avis_bon else LivreParchemin.RUBRIQUE)
	# touches
	var pile := 1
	if id != "":
		pile = _source().nombre(id)
	var verbe := "Prendre" if cote == 0 else "Ranger"
	L.touches([["E", "%s %d" % [verbe, mini(pile, PAS_PIECES) if id == "pieces" else 1], "un"],
		["Maj+E", "%s %s" % [verbe, LivreParchemin.nombre(pile)], "pile"],
		["R", "Tout prendre" if cote == 0 else "Tout ranger", "tout"],
		["Tab", SIGNETS[1 - cote], "signet"], ["Échap", "Fermer", "fermer"]])
