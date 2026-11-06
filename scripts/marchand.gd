class_name Marchand
extends CanvasLayer
## Lot L8 « marchands » (docs/BUTIN.md §9, INSPIRATION_IGNITE §2.18) : Brodd le forgeron et Grima, la doyenne du puits.
##   - données : data/marchands.json (bourse, prix d'achat / de rachat, ce que chacun rachète, stock tiré à graine fixe) ;
##   - ÉTAT (statique, comme ButinTables) : `heures` = heures de jeu écoulées depuis le début de la partie (suivies sur cycle.heure),
##     `etats[id]` = {or, stock {id: n}, periode} ; le stock et la bourse sont tirés à nouveau à chaque période de
##     `renouvellement_jours` jours de jeu (graine « marchand:<id>:<période> », ButinTables.graine) ; sauvegardé par monde.gd (« marchands ») ;
##   - prix : achat = valeur x achat (arrondi au-dessus), rachat = valeur x vente (arrondi au-dessous, 1 au moins) ;
##   - jamais vendables : valeur 0 (objets de quête), `invendables`, objet demandé par une étape « objet:<id>>=n » d'une quête en cours ;
##   - BOUTIQUE (une instance, créée par monde._interface, groupe « marchand ») : ouverte depuis le dialogue (option « Commercer ») ;
##     onglets Acheter / Vendre, une carte par objet (icône, nom en couleur de rareté, effet, nombre, prix + pièce), or du joueur et
##     bourse du marchand, délai avant le réassort ; jeu en PAUSE ;
##     clavier : E / Entrée / Espace = un ; R = toute la pile ; Tab, flèches gauche/droite, Q/D = onglet ; flèches haut/bas, Z/S,
##     molette = choisir ; Échap, clic droit = fermer ; manette : A = un, Y = la pile, LB/RB ou croix gauche/droite = onglet,
##     croix haut/bas = choisir, B = fermer ; souris : survol, clic sur une carte ou un onglet.
## Lot E (RPG) : fenêtre dans la direction A « parchemin et cuir enluminé » (LivreParchemin, maquettes A_parchemin) : signets
## Acheter / Vendre, page gauche = l'étal ou le sac (registre, marge des CATÉGORIES du registre Inventaire.CATEGORIES : C / X manette /
## clic pour filtrer), page droite = fiche de l'objet choisi, prix, bourse, réassort ; objets de quête : Inventaire.est_quete ;
## clé d'effet « prix » (docs/RPG.md §3) : fraction en faveur du joueur (achat moins cher, rachat plus cher), 0 par défaut.

const GROUPE := "marchand"
const FICHIER := "res://data/marchands.json"
const ONGLETS := ["Acheter", "Vendre"]
const DUREE_AVIS := 2.2
## Noms des catégories du registre (marge de la boutique).
const NOMS_CATEGORIES := {"": "Tout", "arme": "Armes", "armure": "Armures", "bijou": "Bijoux", "consommable": "Potions", "ingredient": "Ingrédients", "quete": "Quête", "divers": "Divers"}

## Heures de jeu écoulées depuis le début de la partie (sauvegardées).
static var heures := 0.0
## État de chaque marchand : {or: int, stock: {id: n}, periode: int}.
static var etats := {}
static var _donnees := {}
static var _lu := false

var joueur: CharacterBody3D
var hud: Control
## Monde (pour cycle et quetes, créés après l'interface) ; facultatif (tests).
var monde: Node
var ouvert := false
var id_marchand := ""
var titre := ""
## 0 = Acheter, 1 = Vendre.
var onglet := 0
## Filtre de catégorie (Inventaire.CATEGORIES ; "" = tout).
var categorie := ""
## Cartes affichées : [{id, n, prix, refus}] (refus : "" ou raison : objet de quête, n'en veut pas).
var lignes: Array[Dictionary] = []
var choix := 0

var _livre: LivreParchemin
var _haut := 0
var _souris := Input.MOUSE_MODE_CAPTURED
var _avis := ""
var _avis_couleur := LivreParchemin.ENCRE
var _avis_t := 0.0
var _heure_vue := -1.0

# ------------------------------------------------------------------ données et état (statique)

static func donnees() -> Dictionary:
	if not _lu:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_donnees = d if d is Dictionary else {}
		_lu = true
	return _donnees

static func fiche(id: String) -> Dictionary:
	return donnees().get("marchands", {}).get(id, {})

static func ids() -> Array:
	return donnees().get("marchands", {}).keys()

static func est_marchand(id: String) -> bool:
	return not fiche(id).is_empty()

## Id de marchand d'un PNJ (villageois : donnees.id), "" s'il ne commerce pas.
static func pour_pnj(pnj: Node) -> String:
	if pnj == null or not is_instance_valid(pnj):
		return ""
	var d: Variant = pnj.get("donnees")
	var id := String((d as Dictionary).get("id", "")) if d is Dictionary else ""
	return id if est_marchand(id) else ""

static func periode_de(id: String, h := -1.0) -> int:
	var jours := maxf(0.01, float(fiche(id).get("renouvellement_jours", 2)))
	return floori((heures if h < 0.0 else h) / (24.0 * jours))

## Heures de jeu avant le prochain réassort.
static func heures_avant_reassort(id: String) -> float:
	var jours := maxf(0.01, float(fiche(id).get("renouvellement_jours", 2)))
	return (periode_de(id) + 1) * 24.0 * jours - heures

## État courant (stock tiré, ou retiré si la période a changé).
static func etat(id: String) -> Dictionary:
	var p := periode_de(id)
	var e: Dictionary = etats.get(id, {})
	if e.is_empty() or int(e.get("periode", -1)) != p:
		e = {"periode": p, "or": int(fiche(id).get("or", 0)), "stock": stock_tire(id, p)}
		etats[id] = e
	return e

## Stock d'une période (même période = même stock : graine fixe).
static func stock_tire(id: String, periode: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ButinTables.graine("marchand:%s:%d" % [id, periode])
	var s := {}
	for ent: Dictionary in fiche(id).get("stock", []):
		var oid := String(ent.get("id", ""))
		var chance := int(ent.get("chance", 100))
		var tirage := rng.randi_range(1, 100)
		var v: Variant = ent.get("n", 1)
		var n := rng.randi_range(int(v[0]), int(v[1])) if v is Array else int(v)
		if tirage <= chance and n > 0 and Inventaire.connu(oid):
			s[oid] = int(s.get(oid, 0)) + n
	return s

static func or_de(id: String) -> int:
	return int(etat(id).get("or", 0))

static func stock(id: String) -> Dictionary:
	return etat(id).get("stock", {})

## Clé d'effet « prix » du joueur courant (bijoux, perks : docs/RPG.md §3), bornée à 0..0,5 ; 0 sans joueur.
static func bonus_prix() -> float:
	var p := Progression.courante()
	return clampf(p.bonus("prix"), 0.0, 0.5) if p != null else 0.0

## Part en faveur du joueur chez le marchand `id` : bonus « prix » (bijoux, perks) + disposition du marchand (réputation, prime,
## mémoire : Disposition.mod_prix, ±15 %) + remise du rang de faction (Rangs.remise), bornée à -0,5..0,6.
static func faveur(id: String) -> float:
	return clampf(bonus_prix() + Disposition.mod_prix(id) + Rangs.remise(id), -0.5, 0.6)

static func prix_achat(id: String, oid: String) -> int:
	return maxi(1, ceili(float(Inventaire.objet(oid).get("valeur", 0)) * float(fiche(id).get("achat", 1.1)) * (1.0 - faveur(id)) - 0.0001))

static func prix_vente(id: String, oid: String) -> int:
	return maxi(1, floori(float(Inventaire.objet(oid).get("valeur", 0)) * float(fiche(id).get("vente", 0.4)) * (1.0 + faveur(id)) + 0.0001))

## Objet de quête (jamais vendable) : Inventaire.est_quete (drapeau du registre), valeur 0, liste `invendables`, objet demandé
## par une quête en cours.
static func de_quete(oid: String, quetes: Node = null) -> bool:
	if Inventaire.est_quete(oid) or int(Inventaire.objet(oid).get("valeur", 0)) <= 0 or oid in donnees().get("invendables", []):
		return true
	if quetes != null and is_instance_valid(quetes) and quetes.get("donnees") is Dictionary:
		for q: Dictionary in quetes.donnees.get("quetes", []):
			if not quetes.en_cours(String(q.get("id", ""))):
				continue
			for et: Dictionary in q.get("etapes", []):
				for dec: String in String(et.get("declencheur", "")).split("|"):
					if dec.begins_with("objet:") and dec.substr(6).split(">=")[0] == oid:
						return true
	return false

static func rachete(id: String, oid: String) -> bool:
	var a: Array = fiche(id).get("achete", [])
	return a.is_empty() or oid in a or Forge.base_de(oid) in a or Inventaire.categorie_de(oid) in a   # objet forgé : comme sa base

## Raison pour laquelle le marchand ne rachète pas cet objet ("" = possible).
static func refus_vente(id: String, oid: String, quetes: Node = null) -> String:
	if de_quete(oid, quetes):
		return "Objet de quête : invendable."
	if not rachete(id, oid):
		return "Ça ne l'intéresse pas."
	return ""

## Achète `n` objets (ou moins si le stock ou l'or manque : au moins un, sinon refus). Renvoie la raison du refus ("" = fait).
static func acheter(id: String, inv: Inventaire, oid: String, n := 1) -> String:
	var e := etat(id)
	var s: Dictionary = e["stock"]
	var dispo := int(s.get(oid, 0))
	if dispo <= 0:
		return "Plus en stock."
	var prix := prix_achat(id, oid)
	var k := mini(mini(n, dispo), inv.pieces / prix)
	if k <= 0:
		return "Pas assez de pièces (%d)." % prix
	var place: int = inv.place_pour(oid)
	if place <= 0:
		return "Trop lourd : sac %d / %d." % [roundi(inv.poids()), roundi(inv.capacite())]
	k = mini(k, place)
	inv.pieces -= k * prix
	inv.ajouter(oid, k)
	s[oid] = dispo - k
	if int(s[oid]) <= 0:
		s.erase(oid)
	e["or"] = int(e["or"]) + k * prix
	return ""

## Vend `n` objets du sac (ou moins si la bourse du marchand manque). Ce qui est vendu rejoint son stock jusqu'au réassort.
static func vendre(id: String, inv: Inventaire, oid: String, n := 1, quetes: Node = null) -> String:
	var r := refus_vente(id, oid, quetes)
	if r != "":
		return r
	var a := inv.nombre(oid)
	if a <= 0:
		return "Plus dans le sac."
	var e := etat(id)
	var prix := prix_vente(id, oid)
	var k := mini(mini(n, a), int(e["or"]) / prix)
	if k <= 0:
		return "Sa bourse est vide (%d pièces)." % int(e["or"])
	inv.retirer(oid, k)
	inv.ajouter("pieces", k * prix)
	e["or"] = int(e["or"]) - k * prix
	var s: Dictionary = e["stock"]
	s[oid] = int(s.get(oid, 0)) + k
	return ""

## Fait passer le temps de jeu (heures).
static func avancer(dh: float) -> void:
	if dh > 0.0:
		heures += dh

static func exporter() -> Dictionary:
	var e := {}
	for id: String in etats:
		var d: Dictionary = etats[id]
		e[id] = {"periode": int(d.get("periode", 0)), "or": int(d.get("or", 0)), "stock": (d.get("stock", {}) as Dictionary).duplicate()}
	return {"heures": heures, "etats": e}

static func importer(d: Dictionary) -> void:
	reinitialiser()
	heures = maxf(0.0, float(d.get("heures", 0.0)))
	var e: Dictionary = d.get("etats", {})
	for id: String in e:
		if not est_marchand(id) or not e[id] is Dictionary:
			continue
		var s := {}
		var st: Variant = e[id].get("stock", {})
		if st is Dictionary:
			for oid: String in st:
				if Inventaire.connu(oid) and int(st[oid]) > 0:
					s[oid] = int(st[oid])
		etats[id] = {"periode": int(e[id].get("periode", 0)), "or": int(e[id].get("or", 0)), "stock": s}

static func reinitialiser() -> void:
	heures = 0.0
	etats = {}

## Erreurs des données (test) : objets inconnus, marchand sans villageois, objet vendable que personne ne rachète.
static func verifier() -> Array[String]:
	var err: Array[String] = []
	for id: String in ids():
		for ent: Dictionary in fiche(id).get("stock", []):
			if not Inventaire.connu(String(ent.get("id", ""))):
				err.append("%s : objet inconnu %s" % [id, ent.get("id", "")])
			elif int(Inventaire.objet(String(ent["id"])).get("valeur", 0)) <= 0:
				err.append("%s : objet sans valeur en rayon %s" % [id, ent["id"]])
		for a: String in fiche(id).get("achete", []):
			if not Inventaire.connu(a) and not a in Inventaire.CATEGORIES:
				err.append("%s : « achete » inconnu %s" % [id, a])
	return err

# ------------------------------------------------------------------ boutique

static func trouver(n: Node) -> Marchand:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as Marchand

func _ready() -> void:
	layer = 44   # comme la fenêtre de butin : au-dessus du HUD, sous l'inventaire (45) et le menu pause (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUPE)
	_livre = LivreParchemin.new()
	_livre.visible = false
	_livre.dessin = _dessiner
	add_child(_livre)

func _quetes() -> Node:
	return monde.get("quetes") if monde != null and is_instance_valid(monde) else null

## Ouvre la boutique du marchand `id` (false si inconnu ou déjà ouverte).
func ouvrir(id: String, nom := "") -> bool:
	if ouvert or joueur == null or not est_marchand(id):
		return false
	id_marchand = id
	titre = String(fiche(id).get("titre", nom if nom != "" else id))
	onglet = 0
	categorie = ""
	choix = 0
	_haut = 0
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
	Sons.jouer(self, ["handleCoins", "handleCoins2"], -12.0)
	return true

func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_livre.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _souris if _souris != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED

func changer_onglet(o: int) -> void:
	if not ouvert:
		return
	var n := posmod(o, ONGLETS.size())
	if n != onglet:
		onglet = n
		categorie = ""
		choix = 0
		_haut = 0
		_remplir()
		Sons.jouer(self, ["cloth1"], -16.0)

## Catégories présentes dans l'onglet (ordre de Inventaire.CATEGORIES), précédées de "" (tout).
func categories() -> Array[String]:
	var vues := {}
	var src: Dictionary = stock(id_marchand) if onglet == 0 else joueur.inventaire.objets
	for oid: String in src:
		if int(src[oid]) > 0:
			vues[Inventaire.categorie_de(oid)] = true
	var r: Array[String] = [""]
	for c: String in Inventaire.CATEGORIES:
		if vues.has(c):
			r.append(c)
	return r

func changer_categorie(c: String) -> void:
	if c != categorie:
		categorie = c
		choix = 0
		_haut = 0
		_remplir()
		Sons.jouer(self, ["cloth1"], -18.0)

func categorie_suivante(sens := 1) -> void:
	var l := categories()
	changer_categorie(l[posmod(l.find(categorie) + sens, l.size())])

## Recalcule les lignes de l'onglet (après une transaction : la ligne choisie reste, ou la suivante).
func _remplir() -> void:
	lignes.clear()
	var inv: Inventaire = joueur.inventaire
	if not categorie in categories():
		categorie = ""
	if onglet == 0:
		# ordre de l'étal = ordre de data/marchands.json (stable après un chargement), puis ce que le joueur a vendu
		var ordre: Array = (fiche(id_marchand).get("stock", []) as Array).map(func(en: Dictionary) -> String: return String(en.get("id", "")))
		var st := stock(id_marchand)
		var cles: Array = st.keys()
		cles.sort_custom(func(a: String, b: String) -> bool:
			var ia := ordre.find(a)
			var ib := ordre.find(b)
			ia = ia if ia >= 0 else 1000
			ib = ib if ib >= 0 else 1000
			return ia < ib if ia != ib else a < b)
		for oid: String in cles:
			if categorie == "" or Inventaire.categorie_de(oid) == categorie:
				lignes.append({"id": oid, "n": int(st[oid]), "prix": prix_achat(id_marchand, oid), "refus": ""})
	else:
		var bas: Array[Dictionary] = []
		for oid: String in inv.objets:
			if int(inv.objets[oid]) <= 0 or (categorie != "" and Inventaire.categorie_de(oid) != categorie):
				continue
			var r := refus_vente(id_marchand, oid, _quetes())
			var l := {"id": oid, "n": int(inv.objets[oid]), "prix": prix_vente(id_marchand, oid), "refus": r}
			if r == "":
				lignes.append(l)
			else:
				bas.append(l)    # invendables en bas, grisés
		lignes.append_array(bas)
	choix = clampi(choix, 0, maxi(0, lignes.size() - 1))
	_suivre()
	_livre.rafraichir()

## Transaction sur la ligne i (n = 1, ou toute la pile si `tout`). Renvoie la raison du refus ("" = fait).
func traiter(i := -1, tout := false) -> String:
	if i < 0:
		i = choix
	if not ouvert or i < 0 or i >= lignes.size():
		return "Rien à choisir."
	var l: Dictionary = lignes[i]
	var oid := String(l["id"])
	var n := int(l["n"]) if tout else 1
	var inv: Inventaire = joueur.inventaire
	var avant := inv.pieces
	var r := acheter(id_marchand, inv, oid, n) if onglet == 0 else vendre(id_marchand, inv, oid, n, _quetes())
	if r != "":
		_annoncer(r, LivreParchemin.RUBRIQUE)
		Sons.jouer(self, ["cloth1"], -14.0)
	else:
		var k := absi(inv.pieces - avant) / maxi(1, int(l["prix"]))
		_annoncer(("%s x%d : -%d pièces" if onglet == 0 else "%s x%d : +%d pièces") % [inv.nom(oid), k, absi(inv.pieces - avant)], LivreParchemin.VERT)
		Sons.jouer(self, ["handleCoins", "handleCoins2"], -6.0)
		choix = i
		_remplir()
	return r

func _annoncer(t: String, c: Color) -> void:
	_avis = t
	_avis_couleur = c
	_avis_t = DUREE_AVIS
	_livre.rafraichir()

func _choisir(i: int) -> void:
	if lignes.is_empty():
		return
	var n := clampi(i, 0, lignes.size() - 1)
	if n != choix:
		choix = n
		_suivre()
		_livre.rafraichir()

func _max_lignes() -> int:
	return maxi(3, int((_livre.hauteur() - 64.0 - 52.0) / LivreParchemin.LIGNE))

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
		vp.set_input_as_handled()      # aucune touche du jeu sous la boutique (E, Tab, I, F5, chiffres…)
		if not k.pressed:
			return
		if k.echo and not (k.physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]):
			return
		match k.physical_keycode:
			KEY_ESCAPE:
				fermer()
			KEY_TAB:
				changer_onglet(onglet + 1)
			KEY_LEFT, KEY_A:
				changer_onglet(onglet - 1)
			KEY_RIGHT, KEY_D:
				changer_onglet(onglet + 1)
			KEY_C:
				categorie_suivante(-1 if k.shift_pressed else 1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				traiter()
			KEY_R:
				traiter(-1, true)
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
				traiter()
			JOY_BUTTON_Y:
				traiter(-1, true)
			JOY_BUTTON_X:
				categorie_suivante()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
				changer_onglet(onglet - 1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
				changer_onglet(onglet + 1)
			JOY_BUTTON_DPAD_UP:
				_choisir(choix - 1)
			JOY_BUTTON_DPAD_DOWN:
				_choisir(choix + 1)
	elif e is InputEventMouseMotion:
		vp.set_input_as_handled()
		var z := _livre.zone((e as InputEventMouseMotion).position)
		if z.begins_with("carte:"):
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
				if z.begins_with("carte:"):
					traiter(int(z.substr(6)))
				elif z.begins_with("onglet:"):
					changer_onglet(int(z.substr(7)))
				elif z.begins_with("cat:"):
					changer_categorie(z.substr(4))
				elif z == "un":
					traiter()
				elif z == "tout":
					traiter(-1, true)
				elif z == "categorie":
					categorie_suivante()
				elif z == "fermer":
					fermer()

# ------------------------------------------------------------------ temps et dessin

func _process(dt: float) -> void:
	# temps de jeu : suit l'horloge du cycle (arrêtée pendant la pause) ; un saut de plus de 6 h (chargement, capture) ne compte pas
	var cy: Variant = monde.get("cycle") if monde != null and is_instance_valid(monde) else null
	if cy is Node and is_instance_valid(cy):
		var h := float((cy as Node).get("heure"))
		if _heure_vue >= 0.0:
			var dh := fposmod(h - _heure_vue, 24.0)
			if dh < 6.0:
				avancer(dh)
		_heure_vue = h
	if not ouvert:
		return
	if _livre.echelle():
		_suivre()
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_livre.rafraichir()

## Après un chargement : l'horloge saute, on repart de l'heure lue.
func recaler_horloge() -> void:
	_heure_vue = -1.0

static func duree_texte(h: float) -> String:
	var hh := maxi(1, ceili(h - 0.0001))
	if hh < 24:
		return "%d h" % hh
	return "%d j %d h" % [hh / 24, hh % 24] if hh % 24 != 0 else "%d j" % (hh / 24)

## Effet / résumé d'un objet (une ligne).
func _description(id: String) -> String:
	if Consommables.est(id):
		return Consommables.description(id)
	var base := Forge.base_de(id)
	if CatalogueArmes.connu(base):
		return CatalogueArmes.resume(base) if Forge.niveau_de(id) == 0 else "%s, forgée +%d" % [CatalogueArmes.resume(base), Forge.niveau_de(id)]
	var f := Inventaire.objet(id)
	if float(f.get("armure", 0)) > 0.0:
		return "Armure %d" % roundi(float(f["armure"]))
	return String(f.get("description", ""))

func _dessiner(L: LivreParchemin) -> void:
	if not ouvert:
		return
	var inv: Inventaire = joueur.inventaire
	var e := etat(id_marchand)
	var W := L.size.x
	var H := L.hauteur()
	var m := L.milieu()
	L.en_tete(titre, "Poids %s / %d" % [LivreParchemin.kg(inv.poids()), roundi(inv.capacite())])
	L.onglets(ONGLETS, onglet)
	# --- page gauche : marge des catégories, registre
	var cats := categories()
	var y := 56.0
	for c: String in cats:
		var on := c == categorie
		var nb := 0
		var src: Dictionary = stock(id_marchand) if onglet == 0 else inv.objets
		for oid: String in src:
			if int(src[oid]) > 0 and (c == "" or Inventaire.categorie_de(oid) == c):
				nb += 1
		if on:
			L.ruban(Rect2(14, y - 2, 74, 12))
		L.texte(17, y, NOMS_CATEGORIES.get(c, c), LivreParchemin.CLAIR if on else LivreParchemin.PALE)
		L.texte_d(86, y, str(nb), LivreParchemin.CLAIR if on else LivreParchemin.PALE)
		L.zones["cat:" + c] = Rect2(14, y - 2, 74, 12)
		y += 14.0
	L.encre.draw_rect(Rect2(90, 52, 1, H - 52 - 66), LivreParchemin.RUBRIQUE)
	L.titre(19, 24, "Comptoir" if onglet == 0 else "Sac", "du marchand" if onglet == 0 else "à vendre")
	var X := 94.0
	var LG := m - 8.0 - X - 4.0
	L.texte(X + 18, 52 - 9, "Objet", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG - 40, 52 - 9, "Nb", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG, 52 - 9, "Prix", LivreParchemin.RUBRIQUE)
	L.regle(X, 52, LG)
	var vis := mini(lignes.size(), _max_lignes())
	if lignes.is_empty():
		var vide := "Étal vide. Revenez dans %s." % duree_texte(heures_avant_reassort(id_marchand)) if onglet == 0 else "Rien à vendre dans votre sac."
		L.paragraphe(X + 4, 62, LG - 8, vide, LivreParchemin.PALE)
	for k in vis:
		var i := _haut + k
		var l: Dictionary = lignes[i]
		var id := String(l["id"])
		var refus := String(l["refus"])
		var yl := 55.0 + k * LivreParchemin.LIGNE
		var r := Rect2(X, yl, LG, 17)
		L.ligne(r, i == choix, refus != "")
		L.zones["carte:%d" % i] = r
		L.icone(id, Vector2(X + 1, yl + 1), 16.0, 0.6 if refus != "" else 1.0)
		L.pastille(Vector2(X + 19, yl + 7), ButinTables.rarete_de(id))
		var c_nom := LivreParchemin.PALE if refus != "" else LivreParchemin.ENCRE
		L.texte(X + 25, yl + 4, L.couper(inv.nom(id), LG - 25 - 76), c_nom)
		if int(l["n"]) > 1:
			L.texte_d(X + LG - 40, yl + 4, "x%d" % int(l["n"]), LivreParchemin.PALE)
		if refus == "":
			var peut := (inv.pieces >= int(l["prix"])) if onglet == 0 else (int(e["or"]) >= int(l["prix"]))
			L.texte_d(X + LG, yl + 4, str(int(l["prix"])), LivreParchemin.OR_TERNI if peut else LivreParchemin.RUBRIQUE)
		else:
			L.sceau(Vector2(X + LG - 6, yl + 8))
		L.regle(X, yl + 17, LG)
	if lignes.size() > vis:
		if _haut > 0:
			L.texte(X + LG - 26, 52 - 9, "^", LivreParchemin.RUBRIQUE)
		if _haut + vis < lignes.size():
			L.texte(X + LG + 2, 55.0 + (vis - 1) * LivreParchemin.LIGNE + 4.0, "v", LivreParchemin.RUBRIQUE)
	L.texte(19, H - 54, "Pièces", LivreParchemin.OR_TERNI)
	L.prix(m - 14.0, H - 54, inv.pieces)
	if onglet == 0:
		L.texte(19, H - 42, "Stock limité, réassort dans %s." % duree_texte(heures_avant_reassort(id_marchand)), LivreParchemin.PALE)
	else:
		L.texte(19, H - 42, "Rachat à %d %% de la valeur." % roundi(float(fiche(id_marchand).get("vente", 0.4)) * (1.0 + faveur(id_marchand)) * 100.0), LivreParchemin.PALE)
	# --- page droite : fiche de l'objet choisi, bourse du marchand
	var X2 := m + 12.0
	var LD := W - 17.0 - X2
	if choix < lignes.size():
		var l: Dictionary = lignes[choix]
		var id := String(l["id"])
		var f := Inventaire.objet(id)
		var cadre := Rect2(X2, 26, 38, 38)
		L.encre.draw_rect(cadre, Color("#1f2a44"))
		L.encre.draw_rect(cadre, LivreParchemin.ENCRE, false, 1.0)
		L.encre.draw_rect(cadre.grow(-1), Color("#e8a64a"), false, 1.0)
		L.icone(id, Vector2(X2 + 3, 29), 32)
		L.titre_simple(X2 + 44, 24, inv.nom(id), LivreParchemin.ENCRE, LD - 44)
		var rar := ButinTables.rarete_de(id)
		L.texte(X2 + 44, 46, String(NOMS_CATEGORIES.get(Inventaire.categorie_de(id), "Objet")), LivreParchemin.PALE)
		L.texte(X2 + 44, 57, String(ButinTables.NOMS_RARETE.get(rar, rar)).capitalize(), LivreParchemin.RARETE.get(rar, LivreParchemin.ENCRE))
		L.filet(X2 + 8, 72, LD - 16)
		var yd := L.paragraphe(X2, 79, LD, _description(id), LivreParchemin.ENCRE, 4)
		yd = maxf(yd + 4.0, 112.0)
		var lignes_fiche: Array = [["Poids", "%s kg" % LivreParchemin.kg(float(f.get("poids", 0.0)))], ["Valeur", str(int(f.get("valeur", 0)))]]
		if Forge.niveau_de(id) > 0:
			lignes_fiche.append(["Forge", "+%d (Brodd)" % Forge.niveau_de(id)])
		if joueur.get("equipement_corps") != null and joueur.equipement_corps.est_equipe(id):
			lignes_fiche.append(["Porté", "sera retiré si vendu"])
		for lf: Array in lignes_fiche:
			L.texte(X2, yd, lf[0], LivreParchemin.RUBRIQUE)
			L.texte(X2 + 64, yd, lf[1])
			L.regle(X2, yd + 10, LD)
			yd += 12.0
		yd += 6.0
		L.filet(X2 + 8, yd, LD - 16)
		yd += 8.0
		var refus := String(l["refus"])
		if refus != "":
			L.texte(X2, yd, L.couper(refus, LD), LivreParchemin.RUBRIQUE)
		else:
			L.texte(X2, yd, "Prix d'achat" if onglet == 0 else "Il vous en donne", LivreParchemin.RUBRIQUE)
			var peut := (inv.pieces >= int(l["prix"])) if onglet == 0 else (int(e["or"]) >= int(l["prix"]))
			L.prix(X2 + LD, yd, int(l["prix"]), LivreParchemin.OR_TERNI if peut else LivreParchemin.RUBRIQUE)
			if int(l["n"]) > 1:
				yd += 12.0
				L.texte(X2, yd, "La pile (x%d)" % int(l["n"]), LivreParchemin.PALE)
				L.prix(X2 + LD, yd, int(l["prix"]) * int(l["n"]), LivreParchemin.PALE)
	L.texte(X2, H - 54, "Bourse du marchand", LivreParchemin.PALE)
	L.prix(X2 + LD, H - 54, int(e["or"]), LivreParchemin.ENCRE)
	if _avis_t > 0.0:
		L.texte(X2, H - 42, L.couper(_avis, LD), _avis_couleur)
	L.touches([["E", "Acheter" if onglet == 0 else "Vendre", "un"], ["R", "Toute la pile", "tout"], ["C", "Catégorie", "categorie"],
		["Tab", ONGLETS[1 - onglet], "onglet:%d" % (1 - onglet)], ["Échap", "Fermer", "fermer"]])
