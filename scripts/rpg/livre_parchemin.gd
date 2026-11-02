class_name LivreParchemin
extends Control
## Fenêtres du lot E (coffre ↔ sac, butin, marchand, forge) dans la direction A « parchemin et cuir enluminé » : un codex ouvert
## plein écran (maquette Desktop/Skyrim captures/maquettes_menu/A_parchemin/, direction.js ; png/A_3_coffre.png).
##   - fond : shaders/livre_parchemin.gdshader (cuir à grain, couture, deux pages de vélin, reliure au milieu, tranche) ;
##   - encre : `dessin` (Callable(livre)) appelé à chaque dessin, avec les outils ci-dessous (lettrine, signets de cuir, lignes de
##     registre, règles, filets, barres d'encre, ruban vermillon, flèche de transfert, touches de fer) ; plaques de fer aux coins ;
##   - repère LOGIQUE (EchelleUi : 480x270 ou 640x360) : la mise en page se recalcule d'après `size` (pages = tout l'écran) ;
##   - `zones` : rectangles cliquables du dernier dessin (repère logique), nommés par l'appelant ; `zone(p)` traduit la souris.
## Polices : Kenney (corps, chiffres) et Jacquard 24 (titres) ; une copie par instance (jamais en statique).

const SHADER := preload("res://shaders/livre_parchemin.gdshader")
const ENCRE := Color("#2b1a1e")
const RUBRIQUE := Color("#8a1c1c")       # vermillon des rubriques
const PALE := Color("#6a4229")           # encre pâlie
const OR_TERNI := Color("#b8762a")
const SUR_CUIR := Color("#cca066")       # texte sur le cuir
const CLAIR := Color("#e8e0c8")          # parchemin clair (sur ruban)
const CIRE := Color("#5a1a1c")
const CIRE_CLAIRE := Color("#b3341f")
const LETTRINE_OR := Color("#fcb53a")
const VERT := Color("#1f5a3a")
const BLEU := Color("#1f3a7a")
const CUIR := [Color("#140c06"), Color("#3a2414"), Color("#5a3a20"), Color("#8a5a32")]
const VELIN_SOMBRE := Color("#cdb88e")
## Couleur d'encre par rareté (pastilles, noms) : lisible sur le vélin (maquette : RAR).
const RARETE := {"commun": Color("#56627a"), "peu_commun": Color("#1f5a3a"), "rare": Color("#1f3a7a"), "unique": Color("#b8762a")}
const LIGNE := 18.0
## Hauteur de ligne de texte : y donné = haut de la ligne ; la ligne de base de Kenney 16 est 8 px plus bas.
const BASE := 8.0

var fond: ColorRect
var encre: Control
var dessin: Callable
var police: FontFile
var gothique: FontFile
var zones := {}
var _icones := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	police = Palette.police()
	gothique = MenuStyle.police_gothique(true)
	fond = ColorRect.new()
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	fond.material = m
	add_child(fond)
	encre = Control.new()
	encre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encre.set_anchors_preset(Control.PRESET_FULL_RECT)
	encre.draw.connect(_dessiner)
	add_child(encre)

## Applique l'échelle entière de l'interface ; true si la taille logique a changé.
func echelle() -> bool:
	var change := EchelleUi.appliquer(self)
	if change:
		fond.size = size
		encre.size = size
		(fond.material as ShaderMaterial).set_shader_parameter("taille", size)
		encre.queue_redraw()
	return change

func rafraichir() -> void:
	encre.queue_redraw()

## Zone cliquable sous un point de l'écran (pixels de fenêtre → repère logique).
func zone(p: Vector2) -> String:
	var q := p / maxf(1.0, scale.x)
	for nom: String in zones:
		if (zones[nom] as Rect2).has_point(q):
			return nom
	return ""

## Milieu (reliure) et bornes des pages, en x logiques.
func milieu() -> float:
	return floorf(size.x * 0.5)

func _dessiner() -> void:
	zones.clear()
	_coins()
	if dessin.is_valid():
		dessin.call(self)

# ------------------------------------------------------------------ outils d'encre

func larg(t: String) -> float:
	return ceilf(police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE).x)

## Texte (y = haut de la ligne, comme la maquette).
func texte(x: float, y: float, t: String, c := ENCRE) -> void:
	encre.draw_string(police, Vector2(x, y + BASE), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.TAILLE_POLICE, c)

## Texte aligné à droite sur `xd`.
func texte_d(xd: float, y: float, t: String, c := ENCRE) -> void:
	texte(xd - larg(t), y, t, c)

func texte_centre(xc: float, y: float, t: String, c := ENCRE) -> void:
	texte(floorf(xc - larg(t) * 0.5), y, t, c)

## Coupe `t` (points de suspension) pour tenir dans `l` pixels.
func couper(t: String, l: float) -> String:
	while t.length() > 4 and larg(t) > l:
		t = t.substr(0, t.length() - 2) + "…"
	return t

## Coupe un texte en lignes de `l` pixels au plus (mots entiers).
func lignes_de(t: String, l: float) -> PackedStringArray:
	var res := PackedStringArray()
	var cur := ""
	for mot in t.split(" ", false):
		var essai := mot if cur == "" else cur + " " + mot
		if larg(essai) > l and cur != "":
			res.append(cur)
			cur = mot
		else:
			cur = essai
	if cur != "":
		res.append(cur)
	return res

## Paragraphe (lignes de 10 px) ; renvoie le y sous le dernier.
func paragraphe(x: float, y: float, l: float, t: String, c := ENCRE, max_lignes := 6) -> float:
	var ls := lignes_de(t, l)
	for i in mini(ls.size(), max_lignes):
		texte(x, y, ls[i], c)
		y += 10.0
	return y

## Titre enluminé : lettrine or dans un carré vermillon, reste du mot en Jacquard 24 à l'encre, sous-titre pâli.
func titre(x: float, y: float, mot: String, sous := "") -> float:
	encre.draw_rect(Rect2(x, y, 20, 20), RUBRIQUE)
	encre.draw_rect(Rect2(x, y, 20, 20), CIRE, false, 1.0)
	encre.draw_rect(Rect2(x + 1, y + 1, 18, 18), OR_TERNI, false, 1.0)
	var l0 := mot.substr(0, 1)
	var wl := ceilf(gothique.get_string_size(l0, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x)
	var px := x + floorf((20.0 - wl) * 0.5) + 1.0
	encre.draw_string(gothique, Vector2(px + 1, y + 18), l0, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, CIRE)
	encre.draw_string(gothique, Vector2(px, y + 17), l0, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, LETTRINE_OR)
	var reste := mot.substr(1)
	var xr := x + 23.0
	encre.draw_string(gothique, Vector2(xr, y + 19), reste, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, ENCRE)
	var fin := xr + ceilf(gothique.get_string_size(reste, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x)
	if sous != "":
		texte(fin + 4.0, y + 7.0, sous, PALE)
		fin += 4.0 + larg(sous)
	return fin

## Titre sans lettrine (nom d'objet en Jacquard 24).
func titre_simple(x: float, y: float, t: String, c := ENCRE, l := -1.0) -> void:
	while l > 0.0 and t.length() > 4 and gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x > l:
		t = t.substr(0, t.length() - 2) + "…"
	encre.draw_string(gothique, Vector2(x, y + 19), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, c)

## Bandeau du haut, sur le cuir : texte à gauche et à droite.
func en_tete(gauche: String, droite: String) -> void:
	texte(16, 7, gauche, SUR_CUIR)
	texte_d(size.x - 16.0, 7, droite, SUR_CUIR)

## Signets de cuir centrés en haut (l'actif en ruban rouge) ; zones « onglet:i ».
func onglets(liste: Array, actif: int) -> void:
	var largs: Array[float] = []
	var tot := 0.0
	for l: String in liste:
		var w := larg(l) + 16.0
		largs.append(w)
		tot += w
	tot += 4.0 * (liste.size() - 1)
	var x := roundf(milieu() - tot * 0.5)
	for i in liste.size():
		var w := largs[i]
		var on := i == actif
		var r := Rect2(x, 1.0 if on else 2.0, w, 23.0 if on else 17.0)
		encre.draw_rect(r, RUBRIQUE if on else CUIR[1])
		encre.draw_rect(r, CIRE if on else CUIR[0], false, 1.0)
		encre.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w - 2, 1)), CIRE_CLAIRE if on else CUIR[2])
		encre.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), CIRE_CLAIRE if on else CUIR[2])
		texte(x + 8.0, r.position.y + (5.0 if on else 4.0), liste[i], CLAIR if on else SUR_CUIR)
		zones["onglet:%d" % i] = r
		x += w + 4.0

## Touches de fer centrées en bas ; `liste` = [[touche, libellé, zone]] ; zones cliquables.
func touches(liste: Array) -> void:
	var y := size.y - 16.0
	var items: Array = []
	var tot := 0.0
	for t: Array in liste:
		var wk := maxf(11.0, larg(t[0]) + 5.0)
		var w := wk + 4.0 + larg(t[1])
		items.append([wk, w])
		tot += w
	tot += 12.0 * (liste.size() - 1)
	var x := roundf(milieu() - tot * 0.5)
	for i in liste.size():
		var t: Array = liste[i]
		var wk: float = items[i][0]
		var w: float = items[i][1]
		var rk := Rect2(x, y, wk, 11.0)
		encre.draw_rect(rk, Color("#56627a"))
		encre.draw_rect(rk, Color("#0b0f1a"), false, 1.0)
		encre.draw_rect(Rect2(x + 1, y + 1, wk - 2, 1), Color("#8a96ad"))
		encre.draw_rect(Rect2(x + 1, y + 1, 1, 9), Color("#8a96ad"))
		encre.draw_rect(Rect2(x + 1, y + 9, wk - 2, 1), Color("#3a4458"))
		texte_centre(x + wk * 0.5, y + 1.0, t[0], CLAIR)
		texte(x + wk + 4.0, y + 1.0, t[1], SUR_CUIR)
		if t.size() > 2 and String(t[2]) != "":
			zones[String(t[2])] = Rect2(x - 2.0, y - 2.0, w + 4.0, 15.0)
		x += w + 12.0

## Fond d'une ligne de registre (choisie : vélin foncé encadré).
func ligne(r: Rect2, choisie: bool, grise := false) -> void:
	if choisie:
		encre.draw_rect(r, Color("#cca066"))
		encre.draw_rect(r, Color("#8a5a32"), false, 1.0)
		encre.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), PALE)
	elif grise:
		encre.draw_rect(r, Color(VELIN_SOMBRE, 0.55))

func regle(x: float, y: float, l: float) -> void:
	encre.draw_rect(Rect2(x, y, l, 1), Color("#cca066"))

## Filet ornemental à l'encre, terminé par deux petites croix vermillon.
func filet(x: float, y: float, l: float) -> void:
	encre.draw_rect(Rect2(x, y, l, 1), PALE)
	for cx in [x - 6.0, x + l + 1.0]:
		encre.draw_rect(Rect2(cx + 2, y - 2, 1, 5), RUBRIQUE)
		encre.draw_rect(Rect2(cx, y, 5, 1), RUBRIQUE)
		encre.draw_rect(Rect2(cx + 1, y - 1, 3, 3), RUBRIQUE)

## Barre d'encre (6 px) ; `marque` (0..1, -1 = aucune) : petit trait vermillon (poids après transfert).
func barre(x: float, y: float, l: float, ratio: float, c: Color, marque := -1.0) -> void:
	encre.draw_rect(Rect2(x, y, l, 6), VELIN_SOMBRE)
	var w := roundf((l - 2.0) * clampf(ratio, 0.0, 1.0))
	if w > 0.0:
		encre.draw_rect(Rect2(x + 1, y + 1, w, 4), c)
		encre.draw_rect(Rect2(x + 1, y + 1, w, 1), Color(CLAIR, 0.55))
	encre.draw_rect(Rect2(x, y, l, 6), ENCRE, false, 1.0)
	if marque >= 0.0:
		encre.draw_rect(Rect2(x + 1.0 + roundf((l - 2.0) * clampf(marque, 0.0, 1.0)) - 1.0, y + 1, 2, 4), RUBRIQUE)

func ruban(r: Rect2) -> void:
	encre.draw_rect(r, RUBRIQUE)
	encre.draw_rect(r, CIRE, false, 1.0)
	encre.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), CIRE_CLAIRE)

## Flèche de transfert (ruban + pointe) qui enjambe la reliure, à la hauteur `y` d'une ligne ; vers la droite ou la gauche.
func fleche(y: float, vers_droite: bool) -> void:
	var m := milieu()
	var yf := y + 4.0
	if vers_droite:
		ruban(Rect2(m - 11.0, yf, 14, 9))
		for i in 6:
			encre.draw_rect(Rect2(m + 3.0 + i, yf - 1.0 + i, 1, 11 - 2 * i), RUBRIQUE)
	else:
		ruban(Rect2(m - 3.0, yf, 14, 9))
		for i in 6:
			encre.draw_rect(Rect2(m - 4.0 - i, yf - 1.0 + i, 1, 11 - 2 * i), RUBRIQUE)

## Sceau de cire (objet de quête : on le garde sur soi).
func sceau(c: Vector2) -> void:
	for dy in range(-3, 4):
		var w := 7 - 2 * maxi(0, absi(dy) - 1)
		encre.draw_rect(Rect2(c.x - floorf(w * 0.5), c.y + dy, w, 1), RUBRIQUE)
	encre.draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), CIRE)
	encre.draw_rect(Rect2(c.x - 2, c.y - 3, 2, 1), CIRE_CLAIRE)

## Pastille de rareté 3x3.
func pastille(p: Vector2, rarete: String) -> void:
	encre.draw_rect(Rect2(p, Vector2(3, 3)), RARETE.get(rarete, RARETE["commun"]))

## Icône d'un objet (motif IconesCombat de la fiche, sinon losange de rareté), cadrée sur `cote` px.
func icone(id: String, p: Vector2, cote := 16.0, alpha := 1.0) -> void:
	var tex := icone_de(id)
	if tex == null:
		return
	var ts := tex.get_size()
	var k := maxf(1.0, floorf(cote / maxf(ts.x, ts.y)))
	var t := ts * k
	encre.draw_texture_rect(tex, Rect2(p + ((Vector2(cote, cote) - t) * 0.5).floor(), t), false, Color(1, 1, 1, alpha))

func icone_de(id: String) -> Texture2D:
	if id == "pieces":
		return null
	var base := Forge.base_de(id)
	var motif := String(Inventaire.objet(id).get("icone", base))
	if Inventaire.categorie_de(id) == "arme" and not IconesCombat.connu(motif):
		motif = "epee"
	if IconesCombat.connu(motif):
		return IconesCombat.icone(motif)
	var rar := ButinTables.rarete_de(base)
	var cle := "l:" + rar
	if not _icones.has(cle):
		_icones[cle] = MenuStyle._icone_losange(9, Color(ButinTables.COULEURS_RARETE.get(rar, "#c8d0dc")), false)
	return _icones[cle]

## Pièce d'or 7x7 (coin haut-gauche p).
func piece(p: Vector2) -> void:
	var sombre := Color("#7a4a16")
	var clair := Color("#ffe6a0")
	for r: Array in [[0, 2, 3], [1, 1, 5], [2, 0, 7], [3, 0, 7], [4, 0, 7], [5, 1, 5], [6, 2, 3]]:
		encre.draw_rect(Rect2(p.x + r[1], p.y + r[0], r[2], 1), sombre)
	for r: Array in [[1, 2, 3], [2, 1, 5], [3, 1, 5], [4, 1, 5], [5, 2, 3]]:
		encre.draw_rect(Rect2(p.x + r[1], p.y + r[0], r[2], 1), MenuStyle.OR)
	encre.draw_rect(Rect2(p.x + 2, p.y + 2, 1, 2), clair)

## Nombre de pièces aligné à droite (pièce comprise) ; renvoie le bord gauche.
func prix(xd: float, y: float, v: int, c := OR_TERNI) -> float:
	var t := nombre(v)
	var x := xd - larg(t)
	texte(x, y, t, c)
	piece(Vector2(x - 10.0, y + 1.0))
	return x - 10.0

## « 1 280 » (espace des milliers).
static func nombre(v: int) -> String:
	var s := str(absi(v))
	var r := ""
	while s.length() > 3:
		r = " " + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + r

## Poids lisible : 9,2 / 16,0 (une décimale, virgule).
static func kg(p: float) -> String:
	return ("%.1f" % p).replace(".", ",")

# ------------------------------------------------------------------ coins

const _CC := {"k": Color("#0b0f1a"), "h": Color("#8a96ad"), "m": Color("#56627a"), "s": Color("#3a4458"), "d": Color("#1a2233"),
	"o": Color("#e8a64a"), "b": Color("#b8762a")}

## Plaques de fer à nœud d'entrelacs aux quatre coins (motif de MenuStyle._COIN_ORNE, miroir ; reflet ↔ ombre retournés).
func _coins() -> void:
	var W := size.x
	var H := size.y
	var sw := {"h": "s", "s": "h"}
	for y in 12:
		var ligne_c: String = MenuStyle._COIN_ORNE[y]
		for x in 12:
			var ch := ligne_c[x]
			if not _CC.has(ch):
				continue
			encre.draw_rect(Rect2(x, y, 1, 1), _CC[ch])
			var c2: String = sw.get(ch, ch) if (x == 1 or x == 9) else ch
			encre.draw_rect(Rect2(W - 1 - x, y, 1, 1), _CC[c2])
			var c3: String = sw.get(ch, ch) if (y == 1 or y == 9) else ch
			encre.draw_rect(Rect2(x, H - 1 - y, 1, 1), _CC[c3])
			encre.draw_rect(Rect2(W - 1 - x, H - 1 - y, 1, 1), _CC[sw.get(ch, ch)])
