extends Control
## Interface de combat (enfant de hud.gd, dessinée en _draw, pixels entiers, positions relatives à `size`) :
##   - bas gauche : statuts actifs (rangée d'icônes 8x8 + durée), puis VIE (rouge), MANA (bleue), ENDURANCE (verte)
##     empilées, chacune précédée d'un losange dans un cadre de fer (planche combat_epee, « INTERFACE EN JEU ») ;
##   - bas centre : barre de raccourcis 1-8 (cases 18 px, icônes 16x16, numéros 3x5 dessous), encadrée par les deux
##     emplacements de main (G à gauche, D à droite, cases 24 px) : icône de ce que tient la main, jauge de CHARGE
##     verticale côté extérieur, RECHARGE en voile sombre qui descend, « x2 » doré en double incantation,
##     icône assombrie + liseré rouge si le mana manque pour le sort.
## Tout s'efface hors combat quand les ressources sont pleines (comme hud.gd), réapparaît au moindre changement.
## Lecture seule du joueur : aucune logique de jeu ici.
## Icônes : IconesCombat (scripts/icones_combat.gd).
##
## ===== CONTRAT DE DONNÉES (supposé ; l'agent logique s'y aligne). Tout est facultatif : membre absent = défaut. =====
## Lu par `joueur.get(nom)` à chaque image (donc propriétés ou variables du joueur ; jamais de méthode appelée) :
##   vie, vie_max, vigueur, vigueur_max : float (existent déjà). L'endurance affichée = vigueur / vigueur_max.
##   mana, mana_max : float (défaut : barre pleine, 100/100).
##   charge_gauche, charge_droite : float 0..1 (charge/canalisation du sort de cette main ; 0 = rien ; 1 = prêt).
##   recharges : Dictionary. Clés : "gauche" / "droite" (prioritaires) ou l'id de ce que tient la main ("boule_feu"…).
##     Valeur : float = SECONDES RESTANTES (le HUD retient la plus grande valeur vue depuis le début de la recharge
##     comme durée totale), ou Dictionary {"restant": s, "total": s}. 0 ou clé absente = disponible.
##   statuts_actifs : Array. Éléments : Dictionary {"nom": String, "duree": float (s restantes), "duree_max": float}
##     ou simple String (statut sans durée). Noms connus : brulure, gel, choc, corruption, soin, protection,
##     enchant_feu, enchant_glace, enchant_electricite, enchant_tenebres (alias tolérés : voir IconesCombat.ALIAS_STATUTS).
##     Clignote pendant les 2 dernières secondes. 8 icônes au plus.
##   raccourcis : Array de 8 ids ("" = case vide) ; raccourci_choisi : int 0..7 (-1 = aucune).
## Signal (si `joueur.has_signal`) : etat_mains_change(gauche: Dictionary, droite: Dictionary), émis à chaque
##   changement d'équipement. Clés lues : "id" (String : "boule_feu", "epee", "torche", "bouclier", "" = main nue),
##   "nom" (String), "ecole" ("feu", "glace", "electricite", "tenebres", "soin", "protection" ou ""),
##   "type" ("sort" | "arme" | "objet" | "vide"), "cout" (float, mana par lancer), "deux_mains" (bool : la case de
##   gauche montre alors la même icône, estompée). Tant qu'aucun signal n'est reçu : droite = épée, gauche = torche si
##   `joueur.mains.torche_sortie`, sinon main nue (état actuel du jeu).
## Double incantation = les deux mains de type "sort" avec le même id.
## ===================================================================================================================
## Démo (captures) : argument --hud-combat-demo ou `demo = true` (valeurs animées) ; `demo_t >= 0` fige l'instant ;
## --hud-combat-double (ou `demo_double = true`) : boule de feu dans les deux mains. --hud-demo (hud.gd) : tout visible.

const VIE := [Color("#e0574a"), Color("#b8322a"), Color("#7a1c1c")]
const MANA := [Color("#6f9be8"), Color("#2f5fb8"), Color("#1f3a7a")]
const ENDURANCE := [Color("#5fc27f"), Color("#2f8a56"), Color("#1f5a3a")]
const FOND := Color("#0b0f1a")
const PARCHEMIN := Color("#e8e0c8")
const OR := Color("#e8a64a")
const OR_SOMBRE := Color("#a8702a")
const FER := Color("#56627a")
const FER_CLAIR := Color("#8a96ad")
const FER_SOMBRE := Color("#3a4458")
const BLEU_GAUCHE := Color("#6f9be8")
const ROUGE_MANQUE := Color("#c8382a")
const CADRE := preload("res://assets/ui/barre_cadre.svg")
const MARGE := 16.0
const CASE := 18          # case de raccourci (1 px de cadre + icône 16)
const ECART := 2
const MAIN := 24          # emplacement de main
const NB := 8
## Chiffres et lettres 3x5 (bits de gauche à droite, ligne par ligne).
const MINI := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"G": ["111", "100", "101", "101", "111"], "D": ["110", "101", "101", "101", "110"],
	"x": ["000", "101", "010", "101", "000"],
}
const VIDE := {"id": "", "nom": "", "ecole": "", "type": "vide", "cout": 0.0, "deux_mains": false}

var joueur: Node
var demo := false
var demo_double := false
var demo_t := -1.0

var gauche: Dictionary = {}
var droite: Dictionary = {}
var _signal_recu := false
var _a_vie := 0.0
var _a_mana := 0.0
var _a_end := 0.0
var _a_mains := 0.0
var _a_barre := 0.0
var _t_mains := 0.0        # secondes d'affichage restantes après un changement d'équipement
var _t_barre := 0.0        # idem après un changement de raccourci
var _choisi_prec := -2
var _totaux := {}          # clé de recharge → durée totale retenue
var _horloge := 0.0
var _force_visible := false
# valeurs lues (ou démo) pour l'image en cours
var _v := {}
var nb_dessins := 0     # appels à _draw (tests)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true   # le panneau Tab de hud.gd passe par-dessus
	var args := OS.get_cmdline_user_args()
	demo = demo or args.has("--hud-combat-demo")
	demo_double = demo_double or args.has("--hud-combat-double")
	_force_visible = args.has("--hud-demo")
	if joueur != null and joueur.has_signal("etat_mains_change"):
		joueur.connect("etat_mains_change", _sur_mains)

func _exit_tree() -> void:
	IconesCombat.vider()

func _sur_mains(g: Dictionary, d: Dictionary) -> void:
	_signal_recu = true
	gauche = g
	droite = d
	_t_mains = 3.0
	_t_barre = 3.0

## Lecture tolérante d'un membre du joueur.
func _lire(nom: String, defaut: Variant) -> Variant:
	if joueur == null:
		return defaut
	var v: Variant = joueur.get(nom)
	return defaut if v == null else v

func _process(dt: float) -> void:
	_horloge += dt
	if joueur == null and not demo:
		return
	_lire_etat(dt)
	var combat := false
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.has_method("en_combat") and e.en_combat():
			combat = true
			break
	_t_mains = maxf(0.0, _t_mains - dt)
	_t_barre = maxf(0.0, _t_barre - dt)
	if _v.choisi != _choisi_prec:
		if _choisi_prec != -2:
			_t_barre = 3.0
			_t_mains = 3.0
		_choisi_prec = _v.choisi
	var actif_mains: bool = _v.charge_g > 0.0 or _v.charge_d > 0.0 or _v.rech_g > 0.0 or _v.rech_d > 0.0
	var k := 1.0 - exp(-5.0 * dt)
	# les trois barres apparaissent ensemble (pas de trou dans la pile) dès que l'une n'est pas pleine
	var barres: bool = combat or actif_mains or _v.vie < _v.vie_max - 0.5 or _v.mana < _v.mana_max - 0.5 or _v.vig < _v.vig_max - 0.5
	_a_vie = lerpf(_a_vie, 1.0 if barres else 0.0, k)
	_a_mana = _a_vie
	_a_end = _a_vie
	_a_mains = lerpf(_a_mains, 1.0 if (combat or actif_mains or _t_mains > 0.0) else 0.0, k)
	_a_barre = lerpf(_a_barre, 1.0 if (combat or _t_barre > 0.0) else 0.0, k)
	if demo or _force_visible:
		_a_vie = 1.0; _a_mana = 1.0; _a_end = 1.0; _a_mains = 1.0; _a_barre = 1.0
	queue_redraw()

## Remplit _v (valeurs de l'image) depuis le joueur ou la démo.
func _lire_etat(dt: float) -> void:
	if demo:
		_etat_demo()
		return
	var g := gauche
	var d := droite
	if not _signal_recu:
		var m: Variant = _lire("mains", null)
		var torche: bool = m != null and is_instance_valid(m) and bool(m.get("torche_sortie"))
		d = {"id": "epee", "nom": "Épée", "type": "arme"}
		g = {"id": "torche", "nom": "Torche", "type": "objet"} if torche else VIDE
		gauche = g
		droite = d
	var rech: Variant = _lire("recharges", {})
	var racc: Variant = _lire("raccourcis", null)
	if not (racc is Array):
		racc = [str(d.get("id", "")), str(g.get("id", "")), "", "", "", "", "", ""]
	var st: Variant = _lire("statuts_actifs", [])
	_v = {
		"vie": float(_lire("vie", 100.0)), "vie_max": maxf(1.0, float(_lire("vie_max", 100.0))),
		"vig": float(_lire("vigueur", 100.0)), "vig_max": maxf(1.0, float(_lire("vigueur_max", 100.0))),
		"mana": float(_lire("mana", 100.0)), "mana_max": maxf(1.0, float(_lire("mana_max", 100.0))),
		"charge_g": clampf(float(_lire("charge_gauche", 0.0)), 0.0, 1.0),
		"charge_d": clampf(float(_lire("charge_droite", 0.0)), 0.0, 1.0),
		"rech_g": _recharge(rech, "gauche", str(g.get("id", ""))),
		"rech_d": _recharge(rech, "droite", str(d.get("id", ""))),
		"statuts": st if st is Array else [],
		"raccourcis": racc,
		"choisi": int(_lire("raccourci_choisi", -1)),
	}

## Ratio de recharge restant (0 = disponible, 1 = vient de commencer) d'une main.
func _recharge(rech: Variant, cote: String, id: String) -> float:
	if not (rech is Dictionary):
		return 0.0
	var cle := cote if rech.has(cote) else id
	if cle == "" or not rech.has(cle):
		_totaux.erase(cote)
		return 0.0
	var val: Variant = rech[cle]
	var restant := 0.0
	var total := 0.0
	if val is Dictionary:
		restant = float(val.get("restant", 0.0))
		total = float(val.get("total", 0.0))
	else:
		restant = float(val)
	if restant <= 0.0:
		_totaux.erase(cote)
		return 0.0
	if total <= 0.0:
		total = maxf(float(_totaux.get(cote, 0.0)), restant)
		_totaux[cote] = total
	return clampf(restant / total, 0.0, 1.0)

func _etat_demo() -> void:
	var t := demo_t if demo_t >= 0.0 else _horloge
	var sort := {"id": "boule_feu", "nom": "Boule de feu", "ecole": "feu", "type": "sort", "cout": 25.0}
	gauche = sort
	droite = sort if demo_double else {"id": "epee", "nom": "Épée", "type": "arme"}
	_v = {
		"vie": 72.0, "vie_max": 100.0, "vig": 55.0 + 20.0 * sin(t * 0.7), "vig_max": 100.0,
		"mana": 50.0 + 40.0 * sin(t * 0.9), "mana_max": 100.0,
		"charge_g": fmod(t * 0.5, 1.25) if fmod(t * 0.5, 1.25) < 1.0 else 1.0,
		"charge_d": fmod(t * 0.5 + 0.4, 1.0) if demo_double else 0.0,
		"rech_g": 0.0, "rech_d": 0.0 if demo_double else maxf(0.0, 1.0 - fmod(t * 0.4, 1.6)),
		"statuts": [
			{"nom": "brulure", "duree": 6.0, "duree_max": 8.0},
			{"nom": "enchant_feu", "duree": 20.0 - fmod(t, 20.0), "duree_max": 30.0},
			{"nom": "gel", "duree": 2.0 - fmod(t * 0.5, 2.0), "duree_max": 5.0},
		],
		"raccourcis": ["epee", "boule_feu", "lance_givre", "arc_electrique", "trait_ombre", "soin", "protection", ""],
		"choisi": 1,
	}

# ---------------------------------------------------------------- dessin
func _draw() -> void:
	if _v.is_empty():
		return
	nb_dessins += 1
	var bas := size.y - 14.0
	# --- barres empilées en bas à gauche ---
	_ligne_barre(Vector2(MARGE, bas - 20), _v.vie / _v.vie_max, VIE, _a_vie)
	_ligne_barre(Vector2(MARGE, bas - 10), _v.mana / _v.mana_max, MANA, _a_mana)
	_ligne_barre(Vector2(MARGE, bas), _v.vig / _v.vig_max, ENDURANCE, _a_end)
	_statuts(Vector2(MARGE + 1, bas - 34))
	# --- raccourcis au centre, mains de part et d'autre ---
	var cx := floorf(size.x * 0.5)
	var larg := NB * CASE + (NB - 1) * ECART
	var x0 := cx - floorf(larg * 0.5)
	var y_case := size.y - 28.0
	_raccourcis(Vector2(x0, y_case), _a_barre)
	var y_main := size.y - 31.0
	var double := _type(gauche) == "sort" and _type(droite) == "sort" and str(gauche.get("id", "")) == str(droite.get("id", "")) \
		and str(gauche.get("id", "")) != ""
	_main(Vector2(x0 - 8 - MAIN, y_main), gauche, _v.charge_g, _v.rech_g, -1, double, _a_mains)
	_main(Vector2(x0 + larg + 8, y_main), droite, _v.charge_d, _v.rech_d, 1, double, _a_mains)

func _type(m: Dictionary) -> String:
	var t := str(m.get("type", ""))
	if t == "":
		var id := str(m.get("id", ""))
		t = "vide" if id == "" else ("sort" if IconesCombat.ecole_de(id) != "" else "arme")
	return t

func _ecole(m: Dictionary) -> String:
	var e := str(m.get("ecole", ""))
	return e if e != "" else IconesCombat.ecole_de(str(m.get("id", "")))

## Losange 9x9 (cadre de fer, cœur coloré) + barre 80x7 qui se vide vers le centre (comme hud.gd).
func _ligne_barre(pos: Vector2, ratio: float, couleurs: Array, alpha: float) -> void:
	if alpha < 0.02:
		return
	var c := pos + Vector2(4, 3)   # centre du losange (la barre fait 7 px : centre en y+3)
	for dy in range(-4, 5):
		var r := 4 - absi(dy)
		draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(FOND, alpha))
	for dy in range(-3, 4):
		var r := 3 - absi(dy)
		draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(FER_CLAIR if dy < 0 else FER, alpha))
	for dy in range(-2, 3):
		var r := 2 - absi(dy)
		draw_rect(Rect2(c.x - r, c.y + dy, 2 * r + 1, 1), Color(couleurs[1] if dy >= 0 else couleurs[0], alpha))
	draw_rect(Rect2(c.x, c.y + 2, 1, 1), Color(couleurs[2], alpha))
	draw_rect(Rect2(c.x - 1, c.y - 1, 1, 1), Color(1, 1, 1, 0.55 * alpha))
	# barre
	var p := pos + Vector2(11, 0)
	draw_rect(Rect2(p + Vector2(3, 2), Vector2(74, 3)), Color(FOND, 0.85 * alpha))
	var largeur := roundi(74.0 * clampf(ratio, 0.0, 1.0))
	var x := p.x + 3.0 + floorf((74 - largeur) * 0.5)
	for ligne in 3:
		draw_rect(Rect2(x, p.y + 2 + ligne, largeur, 1), Color(couleurs[ligne], alpha))
	draw_texture(CADRE, p, Color(1, 1, 1, alpha))

## Rangée des statuts actifs : icône 8x8 sur fond sombre, durée = trait de 1 px dessous ; clignote à la fin.
func _statuts(pos: Vector2) -> void:
	var n := 0
	for s in _v.statuts:
		if n >= 8:
			break
		var nom := ""
		var duree := -1.0
		var duree_max := 0.0
		if s is Dictionary:
			nom = str(s.get("nom", ""))
			duree = float(s.get("duree", -1.0))
			duree_max = float(s.get("duree_max", 0.0))
		else:
			nom = str(s)
		if nom == "":
			continue
		var a := 1.0
		if duree >= 0.0 and duree < 2.0 and fmod(_horloge, 0.4) < 0.2:
			a = 0.35
		var p := pos + Vector2(n * 11, 0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(10, 10)), Color(FOND, 0.6))
		draw_texture(IconesCombat.icone_statut(nom), p, Color(1, 1, 1, a))
		if duree >= 0.0 and duree_max > 0.0:
			var l := roundi(8.0 * clampf(duree / duree_max, 0.0, 1.0))
			draw_rect(Rect2(p + Vector2(0, 10), Vector2(8, 1)), Color(FOND, 0.8))
			draw_rect(Rect2(p + Vector2(0, 10), Vector2(l, 1)), Color(IconesCombat.accent(IconesCombat.ecole_statut(nom)), a))
		n += 1

## Cadre nordique (contour sombre, biseau de fer, rivets d'or aux coins).
func _cadre(r: Rect2, alpha: float, liser: Color) -> void:
	draw_rect(r, Color(FOND, alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(FER_SOMBRE, alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(FER_CLAIR, alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), Color(FER, alpha))
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color(FOND, 0.88 * alpha))
	if liser.a > 0.0:
		var l := Color(liser, liser.a * alpha)
		var q := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
		draw_rect(Rect2(q.position, Vector2(q.size.x, 1)), l)
		draw_rect(Rect2(q.position + Vector2(0, q.size.y - 1), Vector2(q.size.x, 1)), l)
		draw_rect(Rect2(q.position, Vector2(1, q.size.y)), l)
		draw_rect(Rect2(q.position + Vector2(q.size.x - 1, 0), Vector2(1, q.size.y)), l)
	for coin in [Vector2(1, 1), Vector2(r.size.x - 2, 1), Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, r.size.y - 2)]:
		draw_rect(Rect2(r.position + coin, Vector2(1, 1)), Color(OR, alpha))

## Emplacement de main : sens = -1 (gauche, jauge à gauche) ou 1 (droite, jauge à droite).
func _main(pos: Vector2, m: Dictionary, charge: float, recharge: float, sens: int, double: bool, alpha: float) -> void:
	if alpha < 0.02:
		return
	var id := str(m.get("id", ""))
	var ecole := _ecole(m)
	var accent := IconesCombat.accent(ecole)
	var est_sort := _type(m) == "sort"
	var manque: bool = est_sort and float(m.get("cout", 0.0)) > _v.mana + 0.01
	var lis := Color(0, 0, 0, 0)
	if manque:
		lis = Color(ROUGE_MANQUE, 0.9)
	elif double:
		lis = Color(OR, 0.9)
	elif est_sort:
		lis = Color(accent, 0.45)
	var r := Rect2(pos, Vector2(MAIN, MAIN))
	_cadre(r, alpha, lis)
	# icône (main gauche vide alors que la droite tient une arme à deux mains : même icône estompée)
	var icone_id := id
	var a_icone := alpha
	if sens < 0 and id == "" and bool(droite.get("deux_mains", false)):
		icone_id = str(droite.get("id", ""))
		a_icone *= 0.4
	var teinte := Color(0.55, 0.42, 0.42, a_icone) if manque else Color(1, 1, 1, a_icone)
	var p_icone := pos + Vector2(4, 4)
	draw_texture(IconesCombat.icone(icone_id), p_icone, teinte)
	# recharge : voile qui se retire vers le bas
	if recharge > 0.0:
		var h := ceili(16.0 * recharge)
		draw_rect(Rect2(p_icone, Vector2(16, h)), Color(FOND, 0.72 * alpha))
		draw_rect(Rect2(p_icone + Vector2(0, h), Vector2(16, 1)), Color(PARCHEMIN, 0.5 * alpha))
	# jauge de charge (côté extérieur) : 3 px de large, se remplit de bas en haut
	if est_sort or charge > 0.0:
		var gx := pos.x - 5 if sens < 0 else pos.x + MAIN + 2
		draw_rect(Rect2(gx, pos.y, 3, MAIN), Color(FOND, 0.85 * alpha))
		draw_rect(Rect2(gx + 1, pos.y + 1, 1, MAIN - 2), Color(FER_SOMBRE, alpha))
		var hc := roundi((MAIN - 2) * clampf(charge, 0.0, 1.0))
		if hc > 0:
			var pleine := charge >= 0.999
			var c := PARCHEMIN if (pleine and fmod(_horloge, 0.5) < 0.25) else accent
			draw_rect(Rect2(gx + 1, pos.y + MAIN - 1 - hc, 1, hc), Color(c, alpha))
	# lettre de la main sous le cadre, « x2 » doré au-dessus en double incantation
	_mini("G" if sens < 0 else "D", pos + Vector2(MAIN / 2 - 1, MAIN + 1), Color(PARCHEMIN, 0.85 * alpha))
	if double:
		var px := pos + Vector2(MAIN - 9, -4)
		draw_rect(Rect2(px - Vector2(1, 1), Vector2(9, 7)), Color(FOND, 0.9 * alpha))
		_mini("x", px, Color(OR, alpha))
		_mini("2", px + Vector2(4, 0), Color(OR, alpha))

## Barre des raccourcis 1-8 : case choisie = cadre parchemin ; case tenue en main = liseré (or à droite, bleu à gauche).
func _raccourcis(pos: Vector2, alpha: float) -> void:
	if alpha < 0.02:
		return
	var ids: Array = _v.raccourcis
	var id_g := str(gauche.get("id", ""))
	var id_d := str(droite.get("id", ""))
	for i in NB:
		var id := str(ids[i]) if i < ids.size() else ""
		var p := pos + Vector2(i * (CASE + ECART), 0)
		var r := Rect2(p, Vector2(CASE, CASE))
		var choisi: bool = i == _v.choisi
		draw_rect(r, Color(PARCHEMIN if choisi else FOND, alpha))
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(16, 16)), Color(FOND, (0.8 if id != "" else 0.55) * alpha))
		if id != "":
			draw_texture(IconesCombat.icone(id), p + Vector2(1, 1), Color(1, 1, 1, alpha if (choisi or id == id_g or id == id_d) else 0.8 * alpha))
		# liseré de main : 2 px sous la case
		var en_d := id != "" and id == id_d
		var en_g := id != "" and id == id_g
		if en_d and en_g:
			draw_rect(Rect2(p + Vector2(0, CASE), Vector2(CASE / 2, 1)), Color(BLEU_GAUCHE, alpha))
			draw_rect(Rect2(p + Vector2(CASE / 2, CASE), Vector2(CASE / 2, 1)), Color(OR, alpha))
		elif en_d or en_g:
			draw_rect(Rect2(p + Vector2(0, CASE), Vector2(CASE, 1)), Color(OR if en_d else BLEU_GAUCHE, alpha))
		var num := str(i + 1)
		var c := OR if choisi else Color(PARCHEMIN, 0.85)
		_mini(num, p + Vector2(CASE / 2 - 1, CASE + 3), Color(c, c.a * alpha))

## Petit glyphe 3x5 cerné de sombre (lisible sur la neige comme dans la nuit).
func _mini(ch: String, pos: Vector2, couleur: Color) -> void:
	var g: Array = MINI.get(ch, MINI["x"])
	var ombre := Color(FOND, 0.8 * couleur.a)
	for y in 5:
		for x in 3:
			if g[y][x] == "1":
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]:
					var q: Vector2 = Vector2(x, y) + d
					if q.x < 0 or q.x > 2 or q.y < 0 or q.y > 4 or g[int(q.y)][int(q.x)] != "1":
						draw_rect(Rect2(pos + q, Vector2(1, 1)), ombre)
	for y in 5:
		for x in 3:
			if g[y][x] == "1":
				draw_rect(Rect2(pos + Vector2(x, y), Vector2(1, 1)), couleur)
