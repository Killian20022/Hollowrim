class_name Forge
extends CanvasLayer
## Forge de Brodd (lot E, Q8 a : pas d'usure) : améliorer une arme ou une armure du sac de +1 à +3 contre des pièces ET des
## minerais (enfin une utilité au fer, à l'argent et au cristal de givre).
##   - RÈGLES (statiques) : l'amélioration est dans l'IDENTIFIANT de l'instance (« epee_soldat+2 », docs/RPG.md §2) ;
##     Inventaire.objet(« id+n ») → fiche_amelioree (nom « … +2 », valeur relevée, armure relevée, champs `base`, `amelioration`,
##     `degats_mult`) ; une arme tenue reçoit une DonneesArme dupliquée aux dégâts relevés (donnees_arme), posée dans
##     EquipementMains.objets_supplementaires tant qu'elle est dans le sac (synchroniser : aucune ligne de equipement_mains.gd
##     touchée) ; une armure passe par EquipementCorps (armure_totale lit la fiche relevée) ;
##   - améliorer garde l'objet équipé (main ou emplacement de corps) : l'ancien quitte le sac, le nouveau est rééquipé ;
##   - refus : objet de quête, unique à part (épée de Skarnholt : arme « epee » du joueur), hache sans modèle, déjà +3, pièces
##     ou minerais manquants ;
##   - FENÊTRE (une instance, créée par ServicesPnj, option « Forge » du dialogue de Brodd) : direction A (LivreParchemin) ;
##     page gauche = registre des objets améliorables (signets Armes / Armures), page droite = avant → après et le prix ;
##     clavier : E / Entrée = améliorer ; Tab, Q/D (A/D physiques), flèches gauche/droite = signet ; haut/bas, Z/S, molette =
##     choisir ; Échap, clic droit = fermer ; manette : A = améliorer, LB/RB = signet, croix = choisir, B = fermer.

const GROUPE := "forge"
const NIVEAU_MAX := 3
## Multiplicateur de dégâts par niveau (+0 .. +3).
const MULT_DEGATS := [1.0, 1.1, 1.2, 1.35]
## Fraction d'armure ajoutée par niveau (au moins +n points).
const ARMURE_PAR_NIVEAU := 0.15
## Valeur marchande : +25 % par niveau.
const VALEUR_PAR_NIVEAU := 0.25
## Prix du niveau visé (index = niveau visé) : pièces = fixe + part de la valeur de base ; minerais exigés.
const COUTS := [
	{},
	{"fixe": 30, "part": 0.2, "minerais": {"minerai_fer": 2}},
	{"fixe": 60, "part": 0.4, "minerais": {"minerai_fer": 3, "minerai_argent": 1}},
	{"fixe": 120, "part": 0.75, "minerais": {"minerai_argent": 2, "cristal_givre": 1}},
]
## Jamais améliorés : l'épée de Skarnholt est l'arme « epee » du joueur (Equipement.choisir_selon_inventaire) ; la hache de
## Kolbeinn n'a pas encore de modèle tenu (lot A).
const EXCLUS := ["epee_skarnholt", "hache_kolbeinn"]
const DOSSIER_ARMES := "res://data/armes/%s.tres"
const SIGNETS := ["Armes", "Armures"]

static var _fiches := {}
static var _armes := {}

# ------------------------------------------------------------------ identifiants

## Identifiant de base (« epee_soldat+2 » → « epee_soldat »).
static func base_de(id: String) -> String:
	var i := id.rfind("+")
	if i > 0 and id.substr(i + 1).is_valid_int():
		return id.substr(0, i)
	return id

## Niveau d'amélioration (0 si aucun).
static func niveau_de(id: String) -> int:
	var i := id.rfind("+")
	if i > 0 and id.substr(i + 1).is_valid_int():
		return int(id.substr(i + 1))
	return 0

static func id_de(base: String, n: int) -> String:
	return base if n <= 0 else "%s+%d" % [base, n]

## Fiche d'un objet amélioré (appelée par Inventaire.objet pour « id+n ») ; {} si la base est inconnue ou n hors 1..3.
static func fiche_amelioree(id: String) -> Dictionary:
	if _fiches.has(id):
		return _fiches[id]
	var n := niveau_de(id)
	var base := base_de(id)
	if n < 1 or n > NIVEAU_MAX or base == id:
		return {}
	var f0 := Inventaire.objet(base)
	if f0.is_empty():
		return {}
	var f := f0.duplicate(true)
	f["nom"] = "%s +%d" % [String(f0.get("nom", base)), n]
	f["valeur"] = roundi(float(f0.get("valeur", 0)) * (1.0 + VALEUR_PAR_NIVEAU * n))
	f["base"] = base
	f["amelioration"] = n
	f["degats_mult"] = MULT_DEGATS[n]
	if float(f0.get("armure", 0)) > 0.0:
		f["armure"] = float(f0["armure"]) + armure_ajoutee(float(f0["armure"]), n)
	_fiches[id] = f
	return f

static func armure_ajoutee(armure: float, n: int) -> float:
	return maxf(float(n), roundf(armure * ARMURE_PAR_NIVEAU * n))

# ------------------------------------------------------------------ armes tenues

## DonneesArme de base d'une arme (catalogue ou data/armes/<id>.tres), null si l'objet ne se tient pas en main.
static func arme_de_base(base: String) -> DonneesArme:
	if CatalogueArmes.connu(base):
		return CatalogueArmes.donnees(base)
	var ch := DOSSIER_ARMES % base
	if base.is_valid_filename() and ResourceLoader.exists(ch):
		return load(ch) as DonneesArme
	return null

## DonneesArme d'une arme améliorée (dupliquée, dégâts × MULT_DEGATS[n]) ; une seule ressource par identifiant (Equipement
## compare les ressources par identité).
static func donnees_arme(id: String) -> DonneesArme:
	if _armes.has(id):
		return _armes[id]
	var n := niveau_de(id)
	var b := arme_de_base(base_de(id))
	if b == null or n < 1:
		return b
	var d := b.duplicate() as DonneesArme
	d.id = id
	d.nom = String(fiche_amelioree(id).get("nom", d.nom))
	d.degats_leger = b.degats_leger * MULT_DEGATS[n]
	d.degats_lourd = b.degats_lourd * MULT_DEGATS[n]
	if b.categorie == DonneesArme.Categorie.BOUCLIER:
		d.reduction_garde = minf(0.95, b.reduction_garde + 0.03 * n)
	_armes[id] = d
	return d

static func _eq(joueur: Node) -> Object:
	if joueur == null or not is_instance_valid(joueur):
		return null
	var mains: Variant = joueur.get("mains")
	if mains == null:
		return null
	var magie: Variant = (mains as Node).get("magie")
	if magie == null:
		return null
	return (magie as Node).get("eq")

## Armes améliorées du sac → EquipementMains.objets_supplementaires (équipables, sauvegardées par leur identifiant) ; celles
## qui ont quitté le sac en sortent (et la main qui la tenait se vide).
static func synchroniser(joueur: Node) -> void:
	var eq: Object = _eq(joueur)
	if eq == null:
		return
	var inv: Inventaire = joueur.inventaire
	var sup: Dictionary = eq.get("objets_supplementaires")
	for id: String in inv.objets:
		if niveau_de(id) > 0 and not sup.has(id) and donnees_arme(id) != null:
			sup[id] = donnees_arme(id)
	for id: String in sup.keys():
		if niveau_de(String(id)) > 0 and not inv.a(String(id)):
			sup.erase(id)
			for m in ["gauche", "droite"]:
				if String((eq.get("mains") as Dictionary)[m].get("id", "")) == String(id):
					eq.call("equiper", m, "vide")

# ------------------------------------------------------------------ règles

static func est_armure(id: String) -> bool:
	return float(Inventaire.objet(id).get("armure", 0)) > 0.0

static func est_arme(id: String) -> bool:
	return Inventaire.categorie_de(id) == "arme" and arme_de_base(base_de(id)) != null

## "" si l'objet peut monter d'un niveau (sans regarder la bourse), sinon la raison.
static func refus_objet(id: String) -> String:
	var base := base_de(id)
	if not Inventaire.connu(id):
		return "Objet inconnu."
	if Inventaire.est_quete(base):
		return "Objet de quête : Brodd n'y touche pas."
	if base in EXCLUS:
		return "Brodd ne touche pas à cette pièce-là."
	if not est_arme(id) and not est_armure(id):
		return "Ni arme ni armure."
	if niveau_de(id) >= NIVEAU_MAX:
		return "Déjà au plus haut (+3)."
	return ""

## Prix du niveau suivant : {pieces, minerais {id: n}, niveau}.
static func cout(id: String) -> Dictionary:
	var n := mini(niveau_de(id) + 1, NIVEAU_MAX)
	var c: Dictionary = COUTS[n]
	var v := float(Inventaire.objet(base_de(id)).get("valeur", 0))
	return {"niveau": n, "pieces": int(c["fixe"]) + roundi(v * float(c["part"])), "minerais": (c["minerais"] as Dictionary).duplicate()}

## "" si le sac `inv` permet d'améliorer `id` maintenant, sinon la raison.
static func refus(inv: Inventaire, id: String) -> String:
	if inv == null or not inv.a(id):
		return "Plus dans le sac."
	var r := refus_objet(id)
	if r != "":
		return r
	var c := cout(id)
	if inv.pieces < int(c["pieces"]):
		return "Il manque %d pièces." % (int(c["pieces"]) - inv.pieces)
	for m: String in c["minerais"]:
		if inv.nombre(m) < int(c["minerais"][m]):
			return "Il manque %s (%d / %d)." % [inv.nom(m).to_lower(), inv.nombre(m), int(c["minerais"][m])]
	return ""

## Améliore un exemplaire de `id` dans le sac du joueur (paie pièces et minerais) ; renvoie "" ou la raison. L'objet équipé
## (main ou corps) le reste sous son nouvel identifiant. `joueur` peut être un simple Inventaire (tests de règles).
static func ameliorer(joueur: Object, id: String) -> String:
	var inv: Inventaire = joueur if joueur is Inventaire else joueur.get("inventaire")
	var r := refus(inv, id)
	if r != "":
		return r
	var neuf := id_de(base_de(id), niveau_de(id) + 1)
	var eq: Object = null if joueur is Inventaire else _eq(joueur as Node)
	var corps: EquipementCorps = null if joueur is Inventaire else joueur.get("equipement_corps")
	var mains_tenant: Array[String] = []
	if eq != null:
		for m in ["gauche", "droite"]:
			if String((eq.get("mains") as Dictionary)[m].get("id", "")) == id:
				mains_tenant.append(m)
	var empl := ""
	if corps != null and corps.est_equipe(id):
		empl = Inventaire.emplacement_de(id)
	var c := cout(id)
	inv.pieces -= int(c["pieces"])
	for m: String in c["minerais"]:
		inv.retirer(m, int(c["minerais"][m]))
	inv.ajouter(neuf, 1)
	if eq != null:
		synchroniser(joueur as Node)     # la variante est équipable avant que l'ancienne ne quitte le sac
	inv.retirer(id, 1)                   # l'ancien quitte le sac (EquipementCorps le retire de son emplacement)
	if not inv.a(id):
		for m in mains_tenant:
			eq.call("equiper", m, neuf)
		if empl != "" and corps != null:
			corps.equiper(neuf)
	if eq != null:
		synchroniser(joueur as Node)
	return ""

## Objets du sac que Brodd peut voir (armes ou armures, hors quête), du signet `signet` (0 armes, 1 armures).
static func candidats(inv: Inventaire, signet := 0) -> Array[String]:
	var r: Array[String] = []
	for id: String in inv.objets:
		if int(inv.objets[id]) <= 0 or Inventaire.est_quete(base_de(id)) or base_de(id) in EXCLUS:
			continue
		if (signet == 0 and est_arme(id)) or (signet == 1 and est_armure(id)):
			r.append(id)
	r.sort_custom(func(a: String, b: String) -> bool:
		var na := Inventaire.objet(a).get("nom", a) as String
		var nb := Inventaire.objet(b).get("nom", b) as String
		return na < nb)
	return r

## Dégâts léger / lourd (arme) après le niveau `n` ; [] si l'objet ne se tient pas.
static func degats(id: String) -> Array:
	var d := donnees_arme(id) if niveau_de(id) > 0 else arme_de_base(id)
	if d == null:
		return []
	return [roundi(d.degats_leger), roundi(d.degats_lourd)]

# ------------------------------------------------------------------ fenêtre

var joueur: CharacterBody3D
var hud: Control
var ouvert := false
var signet := 0
var lignes: Array[String] = []
var choix := 0

var _livre: LivreParchemin
var _haut := 0
var _souris := Input.MOUSE_MODE_CAPTURED
var _avis := ""
var _avis_bon := false
var _avis_t := 0.0

static func trouver(n: Node) -> Forge:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as Forge

func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUPE)
	_livre = LivreParchemin.new()
	_livre.visible = false
	_livre.dessin = _dessiner
	add_child(_livre)

func ouvrir() -> bool:
	if ouvert or joueur == null:
		return false
	ouvert = true
	signet = 0
	choix = 0
	_haut = 0
	_avis_t = 0.0
	_remplir()
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

func changer_signet(s: int) -> void:
	var n := posmod(s, SIGNETS.size())
	if n != signet:
		signet = n
		choix = 0
		_haut = 0
		_remplir()

func _remplir() -> void:
	lignes = candidats(joueur.inventaire, signet)
	choix = clampi(choix, 0, maxi(0, lignes.size() - 1))
	_suivre()
	_livre.rafraichir()

## Améliore la ligne choisie ; renvoie "" ou la raison.
func traiter(i := -1) -> String:
	if i < 0:
		i = choix
	if not ouvert or i < 0 or i >= lignes.size():
		return "Rien à choisir."
	var id := lignes[i]
	var r := ameliorer(joueur, id)
	if r != "":
		_annoncer(r, false)
		Sons.jouer(self, ["cloth1"], -14.0)
		return r
	var neuf := id_de(base_de(id), niveau_de(id) + 1)
	_annoncer("%s : forgé." % joueur.inventaire.nom(neuf), true)
	Sons.jouer(self, ["impactMetal_heavy_000", "impactMetal_heavy_001"], -6.0)
	_remplir()
	var k := lignes.find(neuf)
	if k >= 0:
		choix = k
		_suivre()
	_livre.rafraichir()
	return ""

func _annoncer(t: String, bon: bool) -> void:
	_avis = t
	_avis_bon = bon
	_avis_t = 2.4
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
	return maxi(3, int((_livre.size.y - 64.0 - 52.0) / LivreParchemin.LIGNE))

func _suivre() -> void:
	var m := _max_lignes()
	if choix < _haut:
		_haut = choix
	elif choix >= _haut + m:
		_haut = choix - m + 1
	_haut = clampi(_haut, 0, maxi(0, lignes.size() - m))

func _process(dt: float) -> void:
	if not ouvert:
		return
	if _livre.echelle():
		_suivre()
	if _avis_t > 0.0:
		_avis_t -= dt
		if _avis_t <= 0.0:
			_livre.rafraichir()

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
			KEY_TAB, KEY_RIGHT, KEY_D:
				changer_signet(signet + 1)
			KEY_LEFT, KEY_A:
				changer_signet(signet - 1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				traiter()
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
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				fermer()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
				changer_signet(signet - 1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
				changer_signet(signet + 1)
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
					_choisir(int(z.substr(6)))
				elif z.begins_with("onglet:"):
					changer_signet(int(z.substr(7)))
				elif z == "forger":
					traiter()
				elif z == "signet":
					changer_signet(signet + 1)
				elif z == "fermer":
					fermer()

func _dessiner(L: LivreParchemin) -> void:
	if not ouvert:
		return
	var inv: Inventaire = joueur.inventaire
	var W := L.size.x
	var H := L.size.y
	var m := L.milieu()
	var niv := 1
	var prog: Variant = joueur.get("progression")
	if prog != null:
		niv = int(prog.niveau)
	L.en_tete("Voyageur · niveau %d" % niv, "Pièces %s" % LivreParchemin.nombre(inv.pieces))
	L.onglets(SIGNETS, signet)
	# --- page gauche : registre
	var X := 14.0
	var LG := m - 8.0 - X - 14.0
	L.titre(16, 24, "Forge", "de Brodd")
	L.texte_d(X + LG, 30, "Skarnholt", LivreParchemin.OR_TERNI)
	L.texte(X + 18, 52, "Objet", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG - 34, 52, "Niv.", LivreParchemin.RUBRIQUE)
	L.texte_d(X + LG, 52, "Kg", LivreParchemin.RUBRIQUE)
	L.regle(X, 61, LG)
	var vis := mini(lignes.size(), _max_lignes())
	if lignes.is_empty():
		L.paragraphe(X + 4, 72, LG - 8, "Rien à forger dans votre sac." if signet == 0 else "Aucune armure dans votre sac.", LivreParchemin.PALE)
	for k in vis:
		var i := _haut + k
		var id := lignes[i]
		var y := 64.0 + k * LivreParchemin.LIGNE
		var r := Rect2(X, y, LG, 17)
		var plein := niveau_de(id) >= NIVEAU_MAX
		L.ligne(r, i == choix, plein)
		L.zones["ligne:%d" % i] = r
		L.icone(id, Vector2(X + 1, y + 1))
		L.pastille(Vector2(X + 19, y + 7), ButinTables.rarete_de(base_de(id)))
		L.texte(X + 25, y + 4, L.couper(inv.nom(id), LG - 25 - 70), LivreParchemin.PALE if plein else LivreParchemin.ENCRE)
		if inv.nombre(id) > 1:
			L.texte_d(X + LG - 58, y + 4, "x%d" % inv.nombre(id), LivreParchemin.PALE)
		var n := niveau_de(id)
		L.texte_d(X + LG - 34, y + 4, "+%d" % n if n > 0 else "-", LivreParchemin.RUBRIQUE if n > 0 else LivreParchemin.PALE)
		L.texte_d(X + LG, y + 4, LivreParchemin.kg(float(Inventaire.objet(id).get("poids", 0.0))))
		L.regle(X, y + 17, LG)
	if lignes.size() > vis:
		if _haut > 0:
			L.texte(X + LG + 2, 64, "^", LivreParchemin.RUBRIQUE)
		if _haut + vis < lignes.size():
			L.texte(X + LG + 2, 64.0 + (vis - 1) * LivreParchemin.LIGNE + 6.0, "v", LivreParchemin.RUBRIQUE)
	L.texte(16, H - 54, "Sans usure : ce qui est forgé l'est pour toujours.", LivreParchemin.PALE)
	L.texte(16, H - 42, "Fer, argent, cristal de givre : Brodd en vend aussi.", LivreParchemin.PALE)
	# --- page droite : avant -> après, prix
	var X2 := m + 12.0
	var LD := W - 14.0 - X2
	if choix < lignes.size():
		var id := lignes[choix]
		var n := niveau_de(id)
		var cadre := Rect2(X2, 26, 38, 38)
		L.encre.draw_rect(cadre, Color("#1f2a44"))
		L.encre.draw_rect(cadre, LivreParchemin.ENCRE, false, 1.0)
		L.encre.draw_rect(cadre.grow(-1), Color("#e8a64a"), false, 1.0)
		L.icone(id, Vector2(X2 + 3, 29), 32)
		L.titre_simple(X2 + 44, 24, String(Inventaire.objet(base_de(id)).get("nom", id)), LivreParchemin.ENCRE, LD - 44)
		var rar := ButinTables.rarete_de(base_de(id))
		L.texte(X2 + 44, 46, String(ButinTables.NOMS_RARETE.get(rar, rar)).capitalize(), LivreParchemin.RARETE.get(rar, LivreParchemin.ENCRE))
		if n >= NIVEAU_MAX:
			L.texte(X2 + 44, 57, "Amélioré +3 : rien de plus à forger.", LivreParchemin.PALE)
		else:
			L.texte(X2 + 44, 57, ("+%d" % n if n > 0 else "Sans amélioration") + "  ->  +%d" % (n + 1), LivreParchemin.RUBRIQUE)
		L.filet(X2 + 8, 72, LD - 16)
		var y := 80.0
		var suivant := id_de(base_de(id), mini(n + 1, NIVEAU_MAX))
		if est_arme(id):
			var a := degats(id)
			var b := degats(suivant)
			L.texte(X2, y, "Dégâts", LivreParchemin.RUBRIQUE)
			L.texte(X2 + 64, y, "%d / %d" % [a[0], a[1]])
			if n < NIVEAU_MAX:
				L.texte(X2 + 120, y, "->  %d / %d" % [b[0], b[1]], LivreParchemin.VERT)
			y += 12.0
		if est_armure(id):
			L.texte(X2, y, "Armure", LivreParchemin.RUBRIQUE)
			L.texte(X2 + 64, y, str(roundi(float(Inventaire.objet(id).get("armure", 0)))))
			if n < NIVEAU_MAX:
				L.texte(X2 + 120, y, "->  %d" % roundi(float(Inventaire.objet(suivant).get("armure", 0))), LivreParchemin.VERT)
			y += 12.0
		L.texte(X2, y, "Valeur", LivreParchemin.RUBRIQUE)
		L.texte(X2 + 64, y, str(int(Inventaire.objet(id).get("valeur", 0))), LivreParchemin.OR_TERNI)
		if n < NIVEAU_MAX:
			L.texte(X2 + 120, y, "->  %d" % int(Inventaire.objet(suivant).get("valeur", 0)), LivreParchemin.OR_TERNI)
		y += 16.0
		L.filet(X2 + 8, y, LD - 16)
		y += 8.0
		if n < NIVEAU_MAX:
			var c := cout(id)
			L.texte(X2, y, "Il faut", LivreParchemin.RUBRIQUE)
			y += 13.0
			var assez := inv.pieces >= int(c["pieces"])
			L.piece(Vector2(X2 + 4, y + 1))
			L.texte(X2 + 16, y, "%s pièces" % LivreParchemin.nombre(int(c["pieces"])), LivreParchemin.ENCRE if assez else LivreParchemin.RUBRIQUE)
			L.texte_d(X2 + LD, y, "vous : %s" % LivreParchemin.nombre(inv.pieces), LivreParchemin.PALE if assez else LivreParchemin.RUBRIQUE)
			y += LivreParchemin.LIGNE
			for mi: String in c["minerais"]:
				var besoin := int(c["minerais"][mi])
				var a_mi := inv.nombre(mi)
				L.icone(mi, Vector2(X2, y - 4), 16)
				L.texte(X2 + 18, y, "x%d  %s" % [besoin, inv.nom(mi)], LivreParchemin.ENCRE if a_mi >= besoin else LivreParchemin.RUBRIQUE)
				L.texte_d(X2 + LD, y, "vous : %d" % a_mi, LivreParchemin.PALE if a_mi >= besoin else LivreParchemin.RUBRIQUE)
				y += LivreParchemin.LIGNE
	# avis (dernière forge ou refus), puis touches
	if _avis_t > 0.0:
		L.texte(X2, H - 42, L.couper(_avis, LD), LivreParchemin.VERT if _avis_bon else LivreParchemin.RUBRIQUE)
	elif choix < lignes.size():
		var r := refus(inv, lignes[choix])
		if r != "":
			L.texte(X2, H - 42, L.couper(r, LD), LivreParchemin.RUBRIQUE)
		else:
			L.texte(X2, H - 42, "Brodd attend votre signal.", LivreParchemin.PALE)
	L.touches([["E", "Forger", "forger"], ["Tab", SIGNETS[1 - signet], "signet"], ["Échap", "Fermer", "fermer"]])
