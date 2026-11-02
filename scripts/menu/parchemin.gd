class_name Parchemin
## Direction A « parchemin et cuir enluminé » (maquettes Desktop\Skyrim captures\maquettes_menu\A_parchemin\, direction.js)
## portée en Godot pour l'écran logique 640x360 : codex ouvert (cuir à grain, couture, deux pages de vélin, reliure, plaques de
## fer à entrelacs or), encre brune, rubriques vermillon, médaillons / sceaux de cire, barres d'encre, filets, lettrines.
## LOT D (rpg/onglets) : outils de dessin partagés par onglet_competences / onglet_personnage / onglet_quetes / ecran_niveau.
## Statique, aucune règle de jeu. Les images sont rendues pixel par pixel (bruit de valeur + bruit fin, quantifiés sur les
## rampes ci-dessous : JAMAIS de tramage Bayer) ; l'appelant garde les textures (pas de ressource en variable statique :
## Godot plante à la fermeture, voir Palette.police).
## Le lot C (coquille MenuPersonnage, menu_style.gd) peut reprendre livre() pour le fond commun du menu et les signets.

const CUIR := [Color("#140c06"), Color("#3a2414"), Color("#5a3a20"), Color("#8a5a32")]
const VELIN := [Color("#92613a"), Color("#bb8a53"), Color("#cca066"), Color("#cdb88e"), Color("#d8c69e"), Color("#e0d4b4"), Color("#e8e0c8")]
const ENCRE := Color("#2b1a1e")       ## encre
const RUBRIQUE := Color("#8a1c1c")    ## rubrique vermillon
const RUBRIQUE_SOMBRE := Color("#5a1a1c")
const RUBRIQUE_VIVE := Color("#b3341f")
const PALE := Color("#6a4229")        ## encre pâlie
const OR_TERNI := Color("#b8762a")
const OR_VIF := Color("#e8a64a")
const OR_CLAIR := Color("#fcb53a")
const TEXTE_CUIR := Color("#cca066")  ## texte sur le cuir (en-tête, signets, touches)
const CLAIR := Color("#e8e0c8")       ## parchemin clair (sur ruban)
const SURLIGNE := Color("#cca066")    ## ligne de registre choisie
const SURLIGNE_BORD := Color("#8a5a32")
const FOND_BARRE := Color("#cdb88e")
const BOIS := Color("#8a5a32")        ## barre de niveau / compétence
const VIE := Color("#8a1c1c")
const VIGUEUR := Color("#1f5a3a")
const MAGIE := Color("#1f3a7a")
const FER := [Color("#0b0f1a"), Color("#3a4458"), Color("#56627a"), Color("#8a96ad")]
const TAILLE := 16                    ## police du corps (Palette.police, taille native)
const TITRE := 24                     ## Jacquard 24 (MenuStyle.police_gothique(true))

## Noms affichés des 8 compétences (Progression.COMPETENCES) et leur famille (sous-titre de la colonne).
const NOMS_COMPETENCES := {"une_main": "Une main", "deux_mains": "Deux mains", "parade": "Parade", "armure": "Armure",
	"destruction": "Destruction", "restauration": "Restauration", "furtivite": "Furtivité", "athletisme": "Athlétisme"}
const FAMILLES := {"une_main": "Martial", "deux_mains": "Martial", "parade": "Martial", "armure": "Martial",
	"destruction": "Arcanes", "restauration": "Arcanes", "furtivite": "Voie", "athletisme": "Voie"}

## Coin de fer (12x12) de menu_style.gd (_COIN_ORNE / _COULEURS_ORNE), repris tel quel par la maquette.
const _COIN := ["kkkkkkkkkkkk", "khhhhhhhhhkh", "khmoomoomskm", "khommommoskm", "khombmbmosks", "khmomomomskd",
	"khombmbmoskf", "khommommoskb", "khmoomoomskf", "khsssssssskf", "kkkkkkkkkkkf", "khmmsdfbffff"]
const _CC := {"k": "#0b0f1a", "h": "#8a96ad", "m": "#56627a", "s": "#3a4458", "d": "#1a2233", "o": "#e8a64a", "b": "#b8762a"}

static func nom_competence(nom: String) -> String:
	return String(NOMS_COMPETENCES.get(Progression.canonique(nom), nom.capitalize()))

## Lettres absentes de la police pixel (Kenney sans « œ », noms nordiques de l'arbre : ð, ý, í, ö…) remplacées par leur
## équivalent lisible, seulement si la police ne les a pas.
const _REMPLACE := {"œ": "oe", "Œ": "Oe", "æ": "ae", "Æ": "Ae", "ð": "d", "Ð": "D", "þ": "th", "Þ": "Th", "ý": "y", "Ý": "Y",
	"í": "i", "Í": "I", "ö": "o", "Ö": "O", "ó": "o", "á": "a", "ú": "u", "ø": "o", "å": "a", "ä": "a", "ü": "u"}
static func lisible(police: Font, s: String) -> String:
	var r := s
	for c: String in _REMPLACE:
		if r.contains(c) and not police.has_char(c.unicode_at(0)):
			r = r.replace(c, String(_REMPLACE[c]))
	return r

# ------------------------------------------------------------------ géométrie du livre (écran 640x360)

## Rectangle des deux pages de vélin (marges de la maquette 480x270 × 4/3).
static func pages(taille: Vector2) -> Rect2:
	return Rect2(13, 27, taille.x - 27, taille.y - 55)

## Abscisse de la reliure (milieu du livre).
static func reliure(taille: Vector2) -> float:
	return floorf(taille.x * 0.5) - 0.5

## Origine du contenu d'un onglet dessiné pour 640x360 (centré si l'écran logique est plus grand).
static func origine(taille: Vector2) -> Vector2:
	return ((taille - Vector2(640, 360)) * 0.5).max(Vector2.ZERO).floor()

# ------------------------------------------------------------------ images peintes

static func _bruit(graine: int, periode: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.seed = graine
	n.frequency = 1.0 / periode
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n

## Le codex ouvert plein écran : cuir, deux pages de vélin (ombre de reliure, bords brunis, taches), tranche des pages,
## couture en pointillés, plaques de fer aux coins. ~0,3 s à 640x360 : à garder par l'appelant.
static func livre(taille: Vector2i, graine := 7) -> Image:
	var W := taille.x
	var H := taille.y
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = graine
	var n1 := _bruit(graine, 12.0)
	var n2 := _bruit(graine + 1, 4.0)
	var n3 := _bruit(graine + 2, 30.0)
	var p := pages(Vector2(taille))
	var px0 := int(p.position.x)
	var py0 := int(p.position.y)
	var px1 := int(p.end.x) - 1
	var py1 := int(p.end.y) - 1
	var spine := reliure(Vector2(taille))
	var taches := [[80.0, 268.0, 21.0], [527.0, 85.0, 16.0], [400.0, 296.0, 12.0], [213.0, 53.0, 9.0]]
	for y in H:
		for x in W:
			var v := (n1.get_noise_2d(x, y) * 0.5 + 0.5) * 0.55 + (n2.get_noise_2d(x, y) * 0.5 + 0.5) * 0.25 + rnd.randf() * 0.2
			var g3 := n3.get_noise_2d(x, y) * 0.5 + 0.5
			if x < px0 or x > px1 or y < py0 or y > py1:
				var k := v * 0.8 + g3 * 0.35
				var bord := mini(mini(x, y), mini(W - 1 - x, H - 1 - y))
				if bord < 2:
					k -= 0.5
				elif bord < 4:
					k -= 0.15
				img.set_pixel(x, y, CUIR[0 if k < 0.32 else (1 if k < 0.62 else (2 if k < 0.86 else 3))])
				continue
			var t := 4.0 + (v - 0.5) * 3.2 + (g3 - 0.5) * 1.4
			var ds := absf(x - spine)
			if ds < 1.0: t -= 3.4
			elif ds < 3.0: t -= 2.2
			elif ds < 6.0: t -= 1.3
			elif ds < 11.0: t -= 0.6
			var db := mini(mini(x - px0, px1 - x), mini(y - py0, py1 - y))
			if db < 1: t -= 2.6
			elif db < 3: t -= 1.2
			elif db < 6: t -= 0.45
			for tc: Array in taches:
				var dd := Vector2(x - tc[0], (y - tc[1]) * 1.3).length() / float(tc[2])
				if dd < 1.0 and (n2.get_noise_2d(x, y) * 0.5 + 0.5) * 0.5 + 0.6 > dd:
					t -= 0.9
			img.set_pixel(x, y, VELIN[clampi(roundi(t), 0, 6)])
	# tranche des pages sous le vélin
	for x in range(px0 + 1, px1):
		if absf(x - spine) < 4.0:
			continue
		img.set_pixel(x, py1 + 1, VELIN[1] if x % 5 == 0 else VELIN[3])
		img.set_pixel(x, py1 + 2, VELIN[0] if x % 7 == 0 else VELIN[1])
		img.set_pixel(x, py1 + 3, CUIR[1])
	# couture en pointillés sur le cuir
	var fil := Color("#92613a")
	for x in range(6, W - 6):
		if x % 4 < 2:
			img.set_pixel(x, 4, fil)
			img.set_pixel(x, H - 5, fil)
	for y in range(6, H - 6):
		if y % 4 < 2:
			img.set_pixel(4, y, fil)
			img.set_pixel(W - 5, y, fil)
	_coins(img)
	return img

## Le codex en texture, partagé par le menu et toutes les fenêtres du livre (coffre, butin, marchand, forge) : une seule
## image par taille d'écran logique, gardée en méta de la racine de l'arbre (jamais en variable statique : voir plus haut).
## `n` : n'importe quel nœud dans l'arbre.
static func texture_livre(n: Node, taille: Vector2i) -> ImageTexture:
	var cle := "parchemin_livre_%dx%d" % [taille.x, taille.y]
	var racine: Node = n.get_tree().root if n.is_inside_tree() else null
	if racine != null and racine.has_meta(cle):
		return racine.get_meta(cle)
	var tex := ImageTexture.create_from_image(livre(taille))
	if racine != null:
		racine.set_meta(cle, tex)
	return tex

## Plaques de fer à nœud d'entrelacs aux quatre coins (miroir, reflet ↔ ombre sur les côtés retournés).
static func _coins(img: Image) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var sw := {"h": "s", "s": "h"}
	for y in 12:
		for x in 12:
			var ch: String = _COIN[y][x]
			if not _CC.has(ch):
				continue
			img.set_pixel(x, y, Color(_CC[ch]))
			var a := String(sw.get(ch, ch)) if (x == 1 or x == 9 or (y == 11 and x == 1)) else ch
			img.set_pixel(W - 1 - x, y, Color(_CC.get(a, _CC[ch])))
			var b := String(sw.get(ch, ch)) if (y == 1 or y == 9 or (x == 11 and y == 1)) else ch
			img.set_pixel(x, H - 1 - y, Color(_CC.get(b, _CC[ch])))
			img.set_pixel(W - 1 - x, H - 1 - y, Color(_CC.get(String(sw.get(ch, ch)), _CC[ch])))

## Une feuille de vélin seule (annonces), bords irréguliers brunis, sur fond transparent.
static func feuille(taille: Vector2i, graine := 11) -> Image:
	var W := taille.x
	var H := taille.y
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = graine
	var n1 := _bruit(graine, 10.0)
	var n2 := _bruit(graine + 1, 3.0)
	var bord := _bruit(graine + 3, 5.0)
	for y in H:
		for x in W:
			# contour déchiré : la marge rongée varie le long du bord (0 à 3 px)
			var marge := mini(mini(x, y), mini(W - 1 - x, H - 1 - y))
			var ronge := 1.5 + bord.get_noise_2d(x * 1.7, y * 1.7) * 1.6
			if marge < ronge:
				continue
			var v := (n1.get_noise_2d(x, y) * 0.5 + 0.5) * 0.6 + (n2.get_noise_2d(x, y) * 0.5 + 0.5) * 0.25 + rnd.randf() * 0.15
			var t := 4.2 + (v - 0.5) * 3.0
			var d := marge - ronge
			if d < 1.0: t -= 3.0
			elif d < 2.5: t -= 1.4
			elif d < 5.0: t -= 0.5
			img.set_pixel(x, y, VELIN[clampi(roundi(t), 0, 6)])
	return img

## Médaillon de perk 15x15 (maquette A_4) : « ok » = or plein gravé, « dispo » = sceau de cire rouge, « partiel » = sceau rouge
## cerclé d'or (rangs en cours), « non » = cercle à l'encre pâle (scellé). `sel` : anneau vermillon autour.
static func medaillon(etat: String, sel := false) -> Image:
	var N := 15
	var m := 7
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = etat.length() * 31
	for y in N:
		for x in N:
			var dx := x - m
			var dy := y - m
			var d := Vector2(dx, dy).length()
			if sel and d > 6.2 and d <= 7.2:
				img.set_pixel(x, y, RUBRIQUE)
				continue
			if etat == "ok":
				if d <= 5.3 and d > 4.4:
					img.set_pixel(x, y, ENCRE)
				elif d <= 4.4:
					img.set_pixel(x, y, OR_CLAIR if dx + dy < -2.5 else (OR_TERNI if dx + dy > 2.5 else OR_VIF))
			elif etat == "dispo" or etat == "partiel":
				var b := 5.0 + (0.6 if rnd.randf() < 0.5 else 0.0)
				if etat == "partiel" and d <= 5.6 and d > 4.6:
					img.set_pixel(x, y, OR_VIF)
				elif d <= b and d > b - 1.0:
					img.set_pixel(x, y, RUBRIQUE_SOMBRE)
				elif d <= b - 1.0:
					img.set_pixel(x, y, RUBRIQUE_SOMBRE if (d > 2.2 and d <= 3.2) else (RUBRIQUE_VIVE if dx + dy < -2 else RUBRIQUE))
			else:
				if d <= 5.3 and d > 4.4:
					img.set_pixel(x, y, VELIN[0])
				elif d <= 1.0:
					img.set_pixel(x, y, VELIN[1])
	if etat == "ok":
		for c: Vector2i in [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(-1, 1)]:
			img.set_pixelv(Vector2i(m, m) + c, ENCRE)
	return img

## Grand sceau de cire (annonce de niveau, onglet Personnage) : disque rouge au bord coulé, anneau en creux, reflet ; le
## chiffre est écrit par-dessus par l'appelant. Diamètre 2r+3 (coulures comprises).
static func sceau(r: int, graine := 5) -> Image:
	var N := r * 2 + 5
	var c := Vector2(N * 0.5 - 0.5, N * 0.5 - 0.5)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bord := _bruit(graine, 3.0)
	var grain := _bruit(graine + 1, 2.0)
	for y in N:
		for x in N:
			var v := Vector2(x, y) - c
			var d := v.length()
			var a := atan2(v.y, v.x)
			var rb := r + 0.6 + bord.get_noise_2d(cos(a) * 9.0, sin(a) * 9.0) * 1.8
			if d > rb:
				continue
			var col := RUBRIQUE
			var g := grain.get_noise_2d(x, y)
			if d > rb - 1.0:
				col = RUBRIQUE_SOMBRE
			elif absf(d - r * 0.72) < 0.7:
				col = RUBRIQUE_SOMBRE                     # anneau en creux de la matrice
			elif (v.x + v.y) < -r * 0.9 and d > r * 0.72:
				col = RUBRIQUE_VIVE                        # reflet en haut à gauche
			elif g > 0.45:
				col = RUBRIQUE_VIVE
			elif g < -0.55:
				col = RUBRIQUE_SOMBRE
			img.set_pixel(x, y, col)
	return img

# ------------------------------------------------------------------ traits d'encre sur une image (arbre, racines)

static func tracer(img: Image, a: Vector2i, b: Vector2i, ep: int, col: Color) -> void:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := -absi(b.y - y0)
	var sx := 1 if x0 < b.x else -1
	var sy := 1 if y0 < b.y else -1
	var e := dx + dy
	var W := img.get_width()
	var H := img.get_height()
	while true:
		for oy in ep:
			for ox in ep:
				var px := x0 - ep / 2 + ox
				var py := y0 - ep / 2 + oy
				if px >= 0 and py >= 0 and px < W and py < H:
					img.set_pixel(px, py, col)
		if x0 == b.x and y0 == b.y:
			break
		var e2 := 2 * e
		if e2 >= dy:
			e += dy
			x0 += sx
		if e2 <= dx:
			e += dx
			y0 += sy

## Bézier quadratique a → c (contrôle b) en segments entiers.
static func courbe(img: Image, a: Vector2, b: Vector2, c: Vector2, ep: int, col: Color) -> void:
	var p := Vector2i(a.round())
	for i in range(1, 17):
		var u := i / 16.0
		var q := Vector2i(((1.0 - u) * (1.0 - u) * a + 2.0 * u * (1.0 - u) * b + u * u * c).round())
		tracer(img, p, q, ep, col)
		p = q

# ------------------------------------------------------------------ dessin sur un CanvasItem

## Texte : `pos` = coin haut-gauche de la ligne (comme la maquette), la ligne de base est 11 px plus bas (police 16).
static func texte(ci: CanvasItem, police: Font, pos: Vector2, s: String, couleur := ENCRE, largeur := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, taille := TAILLE) -> void:
	ci.draw_string(police, Vector2(roundf(pos.x), roundf(pos.y) + 11.0), s, align, largeur, taille, couleur)

## Texte cerné de vélin clair (8 voisins) : les traits d'encre de l'arbre s'interrompent autour des lettres, comme dans un
## manuscrit, au lieu de les barrer.
static func texte_cerne(ci: CanvasItem, police: Font, pos: Vector2, s: String, couleur := ENCRE, cerne := Color("#d8c69e")) -> void:
	var b := Vector2(roundf(pos.x), roundf(pos.y) + 11.0)
	for d: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
		ci.draw_string(police, b + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, cerne)
	ci.draw_string(police, b, s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, couleur)

## Texte aligné à droite sur x1.
static func texte_droite(ci: CanvasItem, police: Font, x1: float, y: float, s: String, couleur := ENCRE) -> void:
	var l := police.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x
	texte(ci, police, Vector2(x1 - l, y), s, couleur)

static func largeur(police: Font, s: String, taille := TAILLE) -> float:
	return police.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

## Coupe un texte en lignes de `larg` px au plus (mots entiers ; un mot trop long reste seul sur sa ligne).
static func couper(police: Font, s: String, larg: float, taille := TAILLE) -> PackedStringArray:
	var lignes := PackedStringArray()
	for para in s.split("\n"):
		var cour := ""
		for mot in para.split(" ", false):
			var essai := mot if cour == "" else cour + " " + mot
			if cour != "" and largeur(police, essai, taille) > larg:
				lignes.append(cour)
				cour = mot
			else:
				cour = essai
		lignes.append(cour)
	return lignes

## Titre enluminé : lettrine or dans un carré vermillon (20x20 → 26x26 à 640) + reste du mot en Jacquard 24 à l'encre.
static func titre(ci: CanvasItem, gothique: Font, police: Font, pos: Vector2, s: String, sous := "") -> void:
	if s == "":
		return
	var l := s.substr(0, 1)
	lettrine(ci, gothique, Rect2(pos, Vector2(24, 24)), l)
	ci.draw_string(gothique, pos + Vector2(28, 19), s.substr(1), HORIZONTAL_ALIGNMENT_LEFT, -1, TITRE, ENCRE)
	if sous != "":
		var lt := largeur(gothique, s.substr(1), TITRE)
		texte(ci, police, pos + Vector2(32 + lt, 10), sous, PALE)

## Carré vermillon filet or, caractère or ombré (lettrine ; aussi le compteur de points avec la police du corps).
static func lettrine(ci: CanvasItem, police: Font, r: Rect2, s: String, taille := TITRE) -> void:
	ci.draw_rect(r, RUBRIQUE_SOMBRE)
	ci.draw_rect(r.grow(-1), RUBRIQUE)
	ci.draw_rect(r.grow(-1), OR_TERNI, false, 1.0)
	var l := largeur(police, s, taille)
	var base := r.position.y + (19.0 if taille == TITRE else 16.0)
	var x := roundf(r.position.x + (r.size.x - l) * 0.5)
	ci.draw_string(police, Vector2(x + 1, base + 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, RUBRIQUE_SOMBRE)
	ci.draw_string(police, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, OR_CLAIR)

## Barre d'encre (cadre encre, fond vélin, remplissage + reflet clair d'un pixel).
static func barre(ci: CanvasItem, r: Rect2, ratio: float, couleur: Color) -> void:
	ci.draw_rect(r, ENCRE)
	ci.draw_rect(r.grow(-1), FOND_BARRE)
	var w := roundf((r.size.x - 2.0) * clampf(ratio, 0.0, 1.0))
	if w > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(w, r.size.y - 2.0)), couleur)
		ci.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(w, 1)), Color(CLAIR, 0.55))

## Filet ornemental à l'encre pâle, petites croix vermillon aux bouts.
static func filet(ci: CanvasItem, x: float, y: float, larg: float) -> void:
	ci.draw_rect(Rect2(x, y, larg, 1), PALE)
	for cx: float in [x - 4.0, x + larg + 3.0]:
		ci.draw_rect(Rect2(cx, y - 2, 1, 5), RUBRIQUE)
		ci.draw_rect(Rect2(cx - 2, y, 5, 1), RUBRIQUE)
		ci.draw_rect(Rect2(cx - 1, y - 1, 3, 3), RUBRIQUE)

## Règle de registre (ligne claire sous une entrée).
static func regle(ci: CanvasItem, x: float, y: float, larg: float) -> void:
	ci.draw_rect(Rect2(x, y, larg, 1), SURLIGNE)

## Ligne de registre choisie : bande ocre, filet brun.
static func ligne_choisie(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, SURLIGNE)
	ci.draw_rect(r, SURLIGNE_BORD, false, 1.0)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), PALE)

## Ruban vermillon (marque-page, sélection dans la marge).
static func ruban(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, RUBRIQUE_SOMBRE)
	ci.draw_rect(r.grow(-1), RUBRIQUE)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), RUBRIQUE_VIVE)

## Signet de cuir (onglet) ; l'actif est un ruban rouge plus haut. Renvoie sa largeur.
static func signet(ci: CanvasItem, police: Font, x: float, s: String, actif: bool, marge := 18.0) -> float:
	var l := ceilf(largeur(police, s)) + marge
	var mx := roundf(marge * 0.5)
	if actif:
		var r := Rect2(x, 2, l, 26)
		ci.draw_rect(r, RUBRIQUE_SOMBRE)
		ci.draw_rect(r.grow(-1), RUBRIQUE)
		ci.draw_rect(Rect2(x + 1, 3, l - 2, 1), RUBRIQUE_VIVE)
		ci.draw_rect(Rect2(x + 1, 3, 1, 24), RUBRIQUE_VIVE)
		texte(ci, police, Vector2(x + mx, 8), s, CLAIR)
	else:
		var r := Rect2(x, 3, l, 21)
		ci.draw_rect(r, CUIR[0])
		ci.draw_rect(r.grow(-1), CUIR[1])
		ci.draw_rect(Rect2(x + 1, 4, l - 2, 1), CUIR[2])
		ci.draw_rect(Rect2(x + 1, 4, 1, 19), CUIR[2])
		texte(ci, police, Vector2(x + mx, 7), s, TEXTE_CUIR)
	return l

## Touche de fer (comme assets/ui/touche_e.svg) suivie de son action ; renvoie la largeur occupée.
static func touche(ci: CanvasItem, police: Font, pos: Vector2, k: String, action: String) -> float:
	var lk := ceilf(largeur(police, k)) + 6.0
	var r := Rect2(pos, Vector2(lk, 13))
	ci.draw_rect(r, FER[0])
	ci.draw_rect(r.grow(-1), FER[2])
	ci.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(lk - 2, 1)), FER[3])
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 2, lk - 2, 1), FER[1])
	texte(ci, police, pos + Vector2(3, 0), k, CLAIR)
	texte(ci, police, pos + Vector2(lk + 4, 0), action, TEXTE_CUIR)
	return lk + 4.0 + ceilf(largeur(police, action))

## Bandeau des touches centré sur le cuir du bas (y ≈ 340 à 640x360).
static func bandeau_touches(ci: CanvasItem, police: Font, taille: Vector2, lignes: Array) -> void:
	var tot := 0.0
	for l: Array in lignes:
		tot += ceilf(largeur(police, String(l[0]))) + 10.0 + ceilf(largeur(police, String(l[1]))) + 16.0
	var x := roundf((taille.x - tot + 16.0) * 0.5)
	for l: Array in lignes:
		x += touche(ci, police, Vector2(x, taille.y - 21), String(l[0]), String(l[1])) + 16.0
