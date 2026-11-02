class_name FenetreButin
extends CanvasLayer
## Lot L3 « fenêtre de butin » (docs/BUTIN.md §8, INSPIRATION_IGNITE §2.18) : à l'ouverture d'un coffre ou à la fouille d'un corps, la
## liste des OBJETS du contenant (les pièces, elles, jaillissent et vont seules au sac : scripts/butin.gd, ligne « + N pièces » du titre).
##   - une ligne par objet : icône (motif IconesCombat de objets.json, sinon losange de la couleur de rareté), nom en couleur de
##     rareté (ButinTables.COULEURS_RARETE), nombre et poids en police du corps (Kenney) ; fiche de la ligne choisie (rareté, valeur,
##     effet d'un consommable) ; poids du sac en pied ;
##   - PRENDRE un objet : E, Entrée, Espace, clic gauche, A (manette) ; TOUT PRENDRE : R, Y (manette), clic sur « Tout prendre » ;
##     choisir : flèches, Z/S (touches physiques W/S), molette, survol, croix ; FERMER : Échap, Tab, clic droit, B (manette) ;
##   - jeu en PAUSE pendant qu'elle est ouverte (comme l'inventaire) ; la gerbe de pièces d'un coffre continue (PROCESS_MODE_ALWAYS) ;
##   - la prise passe par ButinTables.prendre (un unique déjà pris devient des pièces) ; l'objet est retiré du dictionnaire du
##     CONTENANT (`objets`, passé par référence) : ce qui n'est pas pris y reste (coffre : ButinTables.restes, sauvegardé ; corps :
##     butin.gd) ; `fin` est appelé à la fermeture. Tout pris = fermeture seule.
## Style : cadre ornementé du lot L7 (MenuStyle.cadre_orne), titre en Jacquard 24 (MenuStyle.police_gothique), texte et chiffres en
## Palette.police, surbrillance bleue des boutons de MenuStyle ; dessin en pixels entiers (EchelleUi), comme le panneau Tab du HUD.
## Une seule instance, créée par monde._interface ; les contenants la trouvent par FenetreButin.trouver(noeud).
## Lot E (RPG) : dessin dans la direction A « parchemin et cuir enluminé » (LivreParchemin, comme la fenêtre coffre ↔ sac) ;
## coffres du monde = prendre seulement (rien ne se range ici) ; logique de prise inchangée.

const GROUPE := "fenetre_butin"
const LIGNE := 14.0
const MAX_LIGNES := 8
const ORDRE_RARETE := {"unique": 0, "rare": 1, "peu_commun": 2, "commun": 3}
const FER := Color("#3a4458")

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
var titre := ""
## Pièces versées à l'ouverture (affichées à côté du titre ; déjà dans le sac).
var pieces := 0
## Lignes affichées : [{id, n, rarete}] (ordre : rareté décroissante puis ordre du contenant).
var lignes: Array[Dictionary] = []
var choix := 0

var _objets: Dictionary = {}
var _fin: Callable
var _livre: LivreParchemin
var _haut := 0        # première ligne visible (défilement)
var _souris := Input.MOUSE_MODE_CAPTURED

static func trouver(n: Node) -> FenetreButin:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as FenetreButin

## Coffre ouvert (tertre.gd, grotte_jeu.gd : _ouvrir_coffre) : fenêtre sur les objets restés dans le coffre (ButinTables.restes[cle]) ;
## à la fermeture, le coffre n'est plus proposé s'il est vide, sinon il devient « Fouiller le coffre ». Sans fenêtre (scène sans
## interface) : tout va au sac (repli).
static func fouiller(n: Node, cle: String, nom: String, n_or: int, it: Node3D, joueur_: CharacterBody3D, hud_: Control) -> void:
	var objets: Dictionary = ButinTables.reste(cle)
	var maj := func() -> void:
		if objets.is_empty():
			ButinTables.restes.erase(cle)
		if it != null and is_instance_valid(it):
			it.actif = ButinTables.a_reste(cle)
			it.verbe = "Fouiller le coffre"
			if not it.actif and it.get("dialogue") != null:
				it.dialogue.retirer_invite(it)
	if objets.is_empty():
		maj.call()
		return
	var f := trouver(n)
	if f == null or not f.ouvrir(nom, objets, n_or, maj):
		var liste: Array = []
		for id: String in objets:
			liste.append({"id": id, "n": int(objets[id]), "rarete": ButinTables.rarete_de(id)})
		for o: Dictionary in ButinTables.prendre(joueur_.inventaire, liste):
			if hud_ != null:
				hud_.avis("+ %d %s" % [int(o["n"]), joueur_.inventaire.nom(String(o["id"]))])
		objets.clear()
		maj.call()

func _ready() -> void:
	layer = 44   # au-dessus du HUD, sous l'inventaire (45) et le menu pause (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUPE)
	_livre = LivreParchemin.new()
	_livre.visible = false
	_livre.dessin = _dessiner
	add_child(_livre)

## Ouvre la fenêtre sur `objets` ({id: n}, modifié en place à chaque prise). Rien à montrer : false (rien n'est ouvert).
func ouvrir(nom: String, objets: Dictionary, pieces_versees := 0, fin := Callable()) -> bool:
	if ouvert or joueur == null:
		return false
	lignes.clear()
	var i := 0
	for id: String in objets:
		if id == "pieces" or int(objets[id]) <= 0:
			continue
		lignes.append({"id": id, "n": int(objets[id]), "rarete": ButinTables.rarete_de(id), "i": i})
		i += 1
	if lignes.is_empty():
		return false
	lignes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = ORDRE_RARETE.get(a["rarete"], 3)
		var rb: int = ORDRE_RARETE.get(b["rarete"], 3)
		return ra < rb if ra != rb else int(a["i"]) < int(b["i"]))
	titre = nom
	pieces = pieces_versees
	_objets = objets
	_fin = fin
	choix = 0
	_haut = 0
	ouvert = true
	if hud != null and hud.get("panneau_ouvert"):
		hud.panneau_ouvert = false
	get_tree().paused = true
	_souris = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_livre.visible = true
	_livre.echelle()
	_livre.rafraichir()
	Sons.jouer(self, ["cloth1", "cloth2"], -10.0)
	return true

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_livre.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	var f := _fin
	_fin = Callable()
	_objets = {}
	if f.is_valid():
		f.call()

## Prend la ligne i (toute la pile) ; renvoie ce qui est arrivé dans le sac [{id, n, rarete}].
func prendre(i := -1) -> Array[Dictionary]:
	if i < 0:
		i = choix
	if not ouvert or i < 0 or i >= lignes.size():
		return []
	var l: Dictionary = lignes[i]
	# poids : on ne prend que ce que le sac peut porter (le reste demeure dans le contenant)
	var place: int = joueur.inventaire.place_pour(String(l["id"]))
	if place < int(l["n"]):
		if hud != null:
			hud.avis("Trop lourd : sac %d / %d" % [roundi(joueur.inventaire.poids()), roundi(joueur.inventaire.capacite())])
		if place <= 0:
			return []
		var part: Dictionary = l.duplicate()
		part["n"] = place
		var rp := ButinTables.prendre(joueur.inventaire, [part])
		for o: Dictionary in rp:
			if hud != null:
				hud.avis("+ %d %s" % [int(o["n"]), joueur.inventaire.nom(String(o["id"]))])
		l["n"] = int(l["n"]) - place
		_objets[String(l["id"])] = int(l["n"])
		Sons.jouer(self, ["cloth1", "cloth2"], -8.0)
		_livre.rafraichir()
		return rp
	var res := ButinTables.prendre(joueur.inventaire, [l])
	for o: Dictionary in res:
		if hud != null:
			hud.avis("+ %d %s" % [int(o["n"]), joueur.inventaire.nom(String(o["id"]))])
	_objets.erase(String(l["id"]))
	lignes.remove_at(i)
	Sons.jouer(self, ["cloth1", "cloth2"], -8.0)
	if lignes.is_empty():
		fermer()
	else:
		choix = clampi(choix, 0, lignes.size() - 1)
		_suivre()
		_livre.rafraichir()
	return res

func tout_prendre() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var i := 0
	while ouvert and i < lignes.size():
		var avant := lignes.size()
		res.append_array(prendre(i))
		if ouvert and lignes.size() >= avant:   # ligne gardée (sac plein) : on passe à la suivante
			i += 1
	return res

func _choisir(i: int) -> void:
	if lignes.is_empty():
		return
	var n := clampi(i, 0, lignes.size() - 1)
	if n != choix:
		choix = n
		_suivre()
		_livre.rafraichir()

## Lignes visibles : MAX_LIGNES en 480x270, davantage en 640x360 (la page est plus haute).
func _max_lignes() -> int:
	return maxi(MAX_LIGNES, int((_livre.hauteur() - 64.0 - 74.0) / LivreParchemin.LIGNE))

func _suivre() -> void:
	var m := _max_lignes()
	if choix < _haut:
		_haut = choix
	elif choix >= _haut + m:
		_haut = choix - m + 1
	_haut = clampi(_haut, 0, maxi(0, lignes.size() - m))

# ------------------------------------------------------------------ entrées

func _input(e: InputEvent) -> void:
	if not ouvert:
		return
	var vp := get_viewport()
	if e is InputEventKey:
		var k := e as InputEventKey
		vp.set_input_as_handled()      # aucune touche du jeu sous la fenêtre (E, Tab, I, F5, chiffres…)
		if not k.pressed:
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			return
		match k.physical_keycode:
			KEY_ESCAPE, KEY_TAB:
				fermer()
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				prendre()
			KEY_R:
				tout_prendre()
			KEY_UP, KEY_W:
				_choisir(choix - 1)
			KEY_DOWN, KEY_S:
				_choisir(choix + 1)
	elif e is InputEventJoypadButton:
		vp.set_input_as_handled()
		if not e.pressed:
			return
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				prendre()
			JOY_BUTTON_Y:
				tout_prendre()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_DPAD_UP:
				_choisir(choix - 1)
			JOY_BUTTON_DPAD_DOWN:
				_choisir(choix + 1)
	elif e is InputEventMouseMotion:
		vp.set_input_as_handled()
		var z := _livre.zone((e as InputEventMouseMotion).position)
		if z.begins_with("ligne:"):
			_choisir(int(z.substr(6)))
	elif e is InputEventMouseButton:
		vp.set_input_as_handled()
		var b := e as InputEventMouseButton
		if not b.pressed:
			return
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_choisir(choix - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_choisir(choix + 1)
			MOUSE_BUTTON_RIGHT:
				fermer()
			MOUSE_BUTTON_LEFT:
				var z := _livre.zone(b.position)
				if z.begins_with("ligne:"):
					prendre(int(z.substr(6)))
				elif z == "prendre":
					prendre()
				elif z == "tout":
					tout_prendre()
				elif z == "fermer":
					fermer()

# ------------------------------------------------------------------ dessin

func _process(_dt: float) -> void:
	if ouvert and _livre.echelle():
		_suivre()

static func poids_texte(p: float) -> String:
	if p <= 0.0:
		return "-"
	return ("%d" % roundi(p)) if absf(p - roundf(p)) < 0.05 else ("%.1f" % p).replace(".", ",")

## Lot E : codex de la direction A. Page gauche = le contenant (registre Objet / Nb / Kg), page droite = fiche de la ligne
## choisie (icône, nom, rareté, effet, valeur) et poids du sac avant / après la prise.
func _dessiner(L: LivreParchemin) -> void:
	if not ouvert:
		return
	var inv: Inventaire = joueur.inventaire
	var W := L.size.x
	var H := L.hauteur()
	var m := L.milieu()
	var niv := 1
	var prog: Variant = joueur.get("progression")
	if prog != null:
		niv = int(prog.niveau)
	L.en_tete("Voyageur · niveau %d" % niv, "Poids %s / %d" % [LivreParchemin.kg(inv.poids()), roundi(inv.capacite())])
	# --- page gauche : le contenant
	var X := 17.0
	var LG := m - 8.0 - X - 6.0
	var mots := titre.split(" ", false, 1)
	L.titre(19, 24, L.couper(mots[0] if mots.size() > 0 else titre, LG - 80), mots[1] if mots.size() > 1 else "")
	if pieces > 0:
		L.texte_d(X + LG, 30, "+ %d pièces" % pieces, LivreParchemin.OR_TERNI)
	L.texte(X + 18, 52, "Objet", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG - 34, 52, "Nb", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG, 52, "Kg", LivreParchemin.RUBRIQUE)
	L.regle(X, 61, LG)
	var vis := mini(lignes.size(), _max_lignes())
	for k in vis:
		var i := _haut + k
		var l: Dictionary = lignes[i]
		var id := String(l["id"])
		var y := 64.0 + k * LivreParchemin.LIGNE
		var r := Rect2(X, y, LG, 17)
		L.ligne(r, i == choix)
		L.zones["ligne:%d" % i] = r
		L.icone(id, Vector2(X + 1, y + 1))
		L.pastille(Vector2(X + 19, y + 7), String(l["rarete"]))
		L.texte(X + 25, y + 4, L.couper(inv.nom(id), LG - 25 - 76), LivreParchemin.ENCRE)
		if int(l["n"]) > 1:
			L.texte_d(X + LG - 34, y + 4, "x%d" % int(l["n"]), LivreParchemin.PALE)
		L.texte_d(X + LG, y + 4, LivreParchemin.kg(float(Inventaire.objet(id).get("poids", 0.0)) * int(l["n"])))
		L.regle(X, y + 17, LG)
	if lignes.size() > vis:
		if _haut > 0:
			L.texte(X + LG - 6, 42, "^", LivreParchemin.RUBRIQUE)
		if _haut + vis < lignes.size():
			L.texte(X + LG + 3, 64.0 + (vis - 1) * LivreParchemin.LIGNE + 4.0, "v", LivreParchemin.RUBRIQUE)
	L.texte(19, H - 54, "%d objet%s" % [lignes.size(), "s" if lignes.size() > 1 else ""], LivreParchemin.PALE)
	L.texte(19, H - 40, "Prendre seulement : on ne range rien ici.", LivreParchemin.PALE)
	if choix < lignes.size():
		L.fleche(64.0 + (choix - _haut) * LivreParchemin.LIGNE, true)
	# --- page droite : fiche
	var X2 := m + 12.0
	var LD := W - 17.0 - X2
	var delta := 0.0
	if choix < lignes.size():
		var l: Dictionary = lignes[choix]
		var id := String(l["id"])
		var f := Inventaire.objet(id)
		var rar := String(l["rarete"])
		var cadre := Rect2(X2, 26, 38, 38)
		L.encre.draw_rect(cadre, Color("#1f2a44"))
		L.encre.draw_rect(cadre, LivreParchemin.ENCRE, false, 1.0)
		L.encre.draw_rect(cadre.grow(-1), Color("#e8a64a"), false, 1.0)
		L.icone(id, Vector2(X2 + 3, 29), 32)
		L.titre_simple(X2 + 44, 24, inv.nom(id), LivreParchemin.ENCRE, LD - 44)
		var nr := String(ButinTables.NOMS_RARETE.get(rar, rar))
		L.texte(X2 + 44, 46, nr.substr(0, 1).to_upper() + nr.substr(1), LivreParchemin.RARETE.get(rar, LivreParchemin.ENCRE))
		L.filet(X2 + 8, 72, LD - 16)
		var desc := Consommables.description(id) if Consommables.est(id) else (CatalogueArmes.resume(id) if CatalogueArmes.connu(id) else String(f.get("description", "")))
		var yd := maxf(L.paragraphe(X2, 79, LD, desc, LivreParchemin.ENCRE, 5) + 4.0, 112.0)
		for lf: Array in [["Poids", "%s kg" % LivreParchemin.kg(float(f.get("poids", 0.0)))], ["Valeur", str(int(f.get("valeur", 0)))]]:
			L.texte(X2, yd, lf[0], LivreParchemin.RUBRIQUE)
			L.texte(X2 + 64, yd, lf[1], LivreParchemin.OR_TERNI if lf[0] == "Valeur" else LivreParchemin.ENCRE)
			L.regle(X2, yd + 10, LD)
			yd += 12.0
		delta = float(f.get("poids", 0.0)) * mini(int(l["n"]), maxi(0, inv.place_pour(id)))
	var yb := H - 66.0
	var cap := inv.capacite()
	var avant := inv.poids()
	L.texte(X2 + 2, yb, "Poids", LivreParchemin.RUBRIQUE)
	L.barre(X2 + 36, yb + 1, LD - 36 - 64, avant / maxf(1.0, cap), Color("#8a5a32"), (avant + delta) / maxf(1.0, cap) if delta > 0.0 else -1.0)
	L.texte_d(X2 + LD, yb, "%s/%d" % [LivreParchemin.kg(avant), roundi(cap)])
	if delta > 0.0:
		var apres := "Après : %s / %d" % [LivreParchemin.kg(avant + delta), roundi(cap)]
		L.texte(X2 + 2, yb + 14, apres)
		L.texte(X2 + 2 + L.larg(apres) + 14, yb + 14, "+%s kg" % LivreParchemin.kg(delta), LivreParchemin.RUBRIQUE)
	L.texte(X2 + 2, yb + 26, "Pièces %s" % LivreParchemin.nombre(inv.pieces), LivreParchemin.OR_TERNI)
	L.touches([["E", "Prendre", "prendre"], ["R", "Tout prendre", "tout"], ["Échap", "Fermer", "fermer"]])
