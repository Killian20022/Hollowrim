class_name LivreParchemin
extends Control
## Fenêtres du lot E (coffre ↔ sac, butin, marchand, forge) posées sur le MÊME codex que le menu du personnage : la base
## unique est `Parchemin` (scripts/menu/parchemin.gd). Ce nœud n'en est que l'adaptateur :
##   - fond : `Parchemin.texture_livre()` (cuir, couture, deux pages de vélin, reliure, plaques de fer : la même image que le
##     menu, partagée par toutes les fenêtres et le menu, peinte une fois par taille d'écran) ;
##   - cadre : en-tête sur le cuir, signets (`Parchemin.signet`) et bandeau des touches de fer (`Parchemin.touche`) aux mêmes
##     places que dans le menu ;
##   - encre des pages : `dessin` (Callable(livre)) appelé à chaque dessin. Les fenêtres écrivent dans le repère des pages
##     (décalé de DY vers le bas, hauteur utile `hauteur()`), avec les outils ci-dessous (couleurs et motifs de Parchemin) ;
##   - repère LOGIQUE (EchelleUi : 480x270 ou 640x360) ; `zones` : rectangles cliquables du dernier dessin (repère des pages),
##     nommés par l'appelant ; `zone(p)` traduit la souris (cadre compris).
## Polices : Kenney (corps, chiffres) et Jacquard 24 (titres) ; une copie par instance (jamais en statique).

const ENCRE := Parchemin.ENCRE
const RUBRIQUE := Parchemin.RUBRIQUE     # vermillon des rubriques
const PALE := Parchemin.PALE             # encre pâlie
const OR_TERNI := Parchemin.OR_TERNI
const SUR_CUIR := Parchemin.TEXTE_CUIR   # texte sur le cuir
const CLAIR := Parchemin.CLAIR           # parchemin clair (sur ruban)
const CIRE := Parchemin.RUBRIQUE_SOMBRE
const CIRE_CLAIRE := Parchemin.RUBRIQUE_VIVE
const LETTRINE_OR := Parchemin.OR_CLAIR
const VERT := Parchemin.VIGUEUR
const BLEU := Parchemin.MAGIE
const CUIR := Parchemin.CUIR
const VELIN_SOMBRE := Parchemin.FOND_BARRE
## Couleur d'encre par rareté (pastilles, noms) : lisible sur le vélin (maquette : RAR).
const RARETE := {"commun": Color("#56627a"), "peu_commun": Color("#1f5a3a"), "rare": Color("#1f3a7a"), "unique": Color("#b8762a")}
const LIGNE := 18.0
## Hauteur de ligne de texte : y donné = haut de la ligne ; la ligne de base de Kenney 16 est 8 px plus bas.
const BASE := 8.0
## Décalage vertical du repère des pages : les pages de Parchemin commencent 7 px plus bas (et finissent 7 px plus haut)
## que l'ancien livre du lot E, pour laisser la place aux signets du menu.
const DY := 7.0

var fond: TextureRect
var encre: Control
var dessin: Callable
var police: FontFile
var gothique: FontFile
var zones := {}
var _zones_cadre := {}
var _icones := {}
var _cadre := 0   # > 0 : on dessine le cadre (repère écran, sans décalage)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	police = Palette.police()
	gothique = MenuStyle.police_gothique(true)
	fond = TextureRect.new()
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.stretch_mode = TextureRect.STRETCH_KEEP
	fond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fond)
	encre = Control.new()
	encre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encre.set_anchors_preset(Control.PRESET_FULL_RECT)
	encre.draw.connect(_dessiner)
	add_child(encre)

## Applique l'échelle entière de l'interface ; true si la taille logique a changé.
func echelle() -> bool:
	var change := EchelleUi.appliquer(self)
	if change or fond.texture == null:
		fond.size = size
		encre.size = size
		fond.texture = Parchemin.texture_livre(self, Vector2i(size))
		encre.queue_redraw()
	return change

func rafraichir() -> void:
	encre.queue_redraw()

## Hauteur utile du repère des pages (à utiliser à la place de size.y par les fenêtres).
func hauteur() -> float:
	return size.y - 2.0 * DY

## Zone cliquable sous un point de l'écran (pixels de fenêtre → repère logique).
func zone(p: Vector2) -> String:
	var q := p / maxf(1.0, scale.x)
	for nom: String in _zones_cadre:
		if (_zones_cadre[nom] as Rect2).has_point(q):
			return nom
	var qp := q - Vector2(0, DY)
	for nom: String in zones:
		if (zones[nom] as Rect2).has_point(qp):
			return nom
	return ""

## Milieu (reliure) et bornes des pages, en x logiques.
func milieu() -> float:
	return floorf(size.x * 0.5)

func _dessiner() -> void:
	zones.clear()
	_zones_cadre.clear()
	_cadre = 0
	encre.draw_set_transform(Vector2(0, DY))
	if dessin.is_valid():
		dessin.call(self)
	encre.draw_set_transform(Vector2.ZERO)

## Le cadre (cuir, signets, touches) se dessine dans le repère de l'écran, comme le menu.
func _debut_cadre() -> void:
	_cadre += 1
	encre.draw_set_transform(Vector2.ZERO)

func _fin_cadre() -> void:
	_cadre -= 1
	if _cadre <= 0:
		_cadre = 0
		encre.draw_set_transform(Vector2(0, DY))

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

## Titre enluminé : lettrine de Parchemin (or dans un carré vermillon, 24 px), reste du mot en Jacquard 24, sous-titre pâli.
## Renvoie le x de fin.
func titre(x: float, y: float, mot: String, sous := "") -> float:
	if mot == "":
		return x
	Parchemin.lettrine(encre, gothique, Rect2(x, y - 2.0, 24, 24), mot.substr(0, 1))
	var reste := mot.substr(1)
	var xr := x + 28.0
	encre.draw_string(gothique, Vector2(xr, y + 17), reste, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, ENCRE)
	var fin := xr + ceilf(gothique.get_string_size(reste, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x)
	if sous != "":
		texte(fin + 4.0, y + 6.0, sous, PALE)
		fin += 4.0 + larg(sous)
	return fin

## Titre sans lettrine (nom d'objet en Jacquard 24).
func titre_simple(x: float, y: float, t: String, c := ENCRE, l := -1.0) -> void:
	while l > 0.0 and t.length() > 4 and gothique.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND).x > l:
		t = t.substr(0, t.length() - 2) + "…"
	encre.draw_string(gothique, Vector2(x, y + 19), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuStyle.TITRE_GRAND, c)

## Bandeau du haut, sur le cuir (mêmes places que l'en-tête du menu) : texte à gauche et à droite.
func en_tete(gauche: String, droite: String) -> void:
	_debut_cadre()
	Parchemin.texte(encre, police, Vector2(20, 8), gauche, SUR_CUIR)
	Parchemin.texte_droite(encre, police, size.x - 20.0, 8, droite, SUR_CUIR)
	_fin_cadre()

## Signets de cuir de Parchemin centrés en haut (l'actif en ruban rouge, dessiné en dernier : il mord sur la page),
## comme ceux du menu ; zones « onglet:i ».
func onglets(liste: Array, actif: int) -> void:
	_debut_cadre()
	var tot := 0.0
	for l: String in liste:
		tot += ceilf(Parchemin.largeur(police, l)) + 18.0 + 3.0
	var x := roundf(milieu() - (tot - 3.0) * 0.5)
	var x_actif := -1.0
	for i in liste.size():
		var l := ceilf(Parchemin.largeur(police, String(liste[i]))) + 18.0
		if i == actif:
			x_actif = x
		else:
			Parchemin.signet(encre, police, x, String(liste[i]), false)
		_zones_cadre["onglet:%d" % i] = Rect2(x, 2, l, 24)
		x += l + 3.0
	if x_actif >= 0.0:
		Parchemin.signet(encre, police, x_actif, String(liste[actif]), true)
	_fin_cadre()

## Touches de fer de Parchemin centrées sur le cuir du bas (comme le bandeau du menu) ; `liste` = [[touche, libellé, zone]] ;
## zones cliquables.
func touches(liste: Array) -> void:
	_debut_cadre()
	var tot := 0.0
	for t: Array in liste:
		tot += ceilf(Parchemin.largeur(police, String(t[0]))) + 10.0 + ceilf(Parchemin.largeur(police, String(t[1]))) + 16.0
	var x := roundf((size.x - tot + 16.0) * 0.5)
	var y := size.y - 21.0
	for t: Array in liste:
		var w := Parchemin.touche(encre, police, Vector2(x, y), String(t[0]), String(t[1]))
		if t.size() > 2 and String(t[2]) != "":
			_zones_cadre[String(t[2])] = Rect2(x - 2.0, y - 2.0, w + 4.0, 17.0)
		x += w + 16.0
	_fin_cadre()

## Fond d'une ligne de registre (choisie : la ligne de registre de Parchemin, comme le Sac du menu).
func ligne(r: Rect2, choisie: bool, grise := false) -> void:
	if choisie:
		Parchemin.ligne_choisie(encre, r)
	elif grise:
		encre.draw_rect(r, Color(VELIN_SOMBRE, 0.55))

func regle(x: float, y: float, l: float) -> void:
	Parchemin.regle(encre, x, y, l)

## Filet ornemental de Parchemin (encre pâle, petites croix vermillon aux bouts).
func filet(x: float, y: float, l: float) -> void:
	Parchemin.filet(encre, x, y, l)

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
	Parchemin.ruban(encre, r)

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
