extends SceneTree
## GÉNÉRATEUR D'ICÔNES D'OBJETS (hors ligne) : rend CHAQUE objet du registre qui a un modèle 3D (Inventaire.ids_connus() : armes
## du catalogue, armures, bijoux, consommables, ingrédients, tomes, quête, divers ; + objets de main hors registre : epee_metal,
## bouclier) avec RenduObjet (studio : clé chaude, contre froid), puis réduit l'image en icône de pixels nets :
##   rendu 256 px -> recadrage serré sur l'objet (alpha) -> réduction Lanczos prémultipliée -> alpha tranché (0 ou 1, pas de
##   flou ni de tramage) -> contour sombre 1 px (lisible sur le vélin du menu comme sur le cuir sombre de la barre).
## Deux tailles (640x360) : 16 px (registres du menu, barre d'objets, coffre, boutique, forge, butin) et 32 px (fiches détaillées
## de la boutique, de la forge et du butin). Sortie : assets/ui/icones/icones_16.png + icones_32.png (atlas, 16 colonnes) et
## assets/ui/icones/icones.json (ordre des ids) ; lus par IconesObjets (scripts/icones_objets.gd). Objet sans modèle (torche,
## clé de maison… repli « sacoche » d'ObjetMonde) : pas d'icône, le jeu garde l'ancienne icône pixel (IconesCombat).
## RÉGÉNÉRER (après l'arrivée de nouveaux modèles, ex. armures « sol ») — une seule commande, depuis WSL :
##   bash outils/generer_icones.sh            (rend, écrit l'atlas, puis réimporte)
## à la main : godot --path . --script res://outils/generer_icones.gd -- [--planche=<dossier>] [--ids=a,b,c]
##   --planche : écrit aussi planche_icones.png (anciennes | nouvelles ×4, par catégorie) et grandes.png (32 px ×4).
## Fenêtre nécessaire (un Godot --headless ne dessine rien) : godot_slot.sh l'envoie hors écran.

const DOSSIER := "res://assets/ui/icones/"
const TAILLES := [16, 32]
const COLONNES := 16
const RENDU := 256
## Contour : brun très sombre (encre de bistre), pas du noir pur.
const CONTOUR := Color("#1d140c")
## Objets de main hors registre (EquipementMains : « epee » = épée de métal ; bouclier nordique).
const HORS_REGISTRE := ["epee_metal", "bouclier"]

## Cadrage par catégorie : lacet / tangage (rad) de RenduObjet. Armes couchées vues de haut, en diagonale (pointe en haut à
## droite, comme les icônes classiques) ; le reste en 3/4 plongeant ; fioles et vivres debout un peu moins plongés.
const CADRAGES := {
	"arme": [-0.785, -1.38],
	"bouclier": [0.5, -1.0],
	"armure": [0.45, -0.95],
	"casque": [0.6, -0.4],
	"bijou": [0.55, -1.0],
	"potion": [0.55, -0.42],
	"tome": [0.5, -0.95],
	"autre": [0.6, -0.8],
}

## Objets posés face contre terre par ObjetMonde._coucher (axe mince -> vertical, sens arbitraire) : retournés pour l'icône.
const RETOURNES := ["bouclier"]
## Exposition du studio pour les icônes (RenduObjet.exposer) : petites et posées sur vélin clair, elles veulent plus de lumière.
const EXPOSITION := 1.7
## Seuil d'alpha après réduction : en dessous, transparent. Bas pour les bijoux (la chaîne d'une amulette tient en 1 px).
const SEUIL := 0.42
const SEUIL_FIN := 0.2
## Relevé des tons (gamma < 1) : cuirs et fourrures sombres restent lisibles sur le vélin ; les clairs ne bougent presque pas.
const GAMMA := 0.72

var _planche := ""
var _seuls: Array[String] = []

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--planche="):
			_planche = a.substr(10)
		elif a.begins_with("--ids="):
			for s in a.substr(6).split(",", false):
				_seuls.append(s)
	if DisplayServer.get_name() == "headless":
		printerr("generer_icones : fenêtre nécessaire (lancer sans --headless, via godot_slot.sh)")
		quit(1)
		return
	var ids := ids_a_rendre()
	if not _seuls.is_empty():
		ids = ids.filter(func(i: String) -> bool: return i in _seuls)
	var r := RenduObjet.creer(Vector2i(RENDU, RENDU))
	root.add_child(r)
	var icones := {}   # id -> {16: Image, 32: Image}
	var sans := []
	for id: String in ids:
		if not ObjetMonde.a_modele(id):
			sans.append(id)
			continue
		var c: Array = CADRAGES[cadrage_de(id)]
		r.montrer(id)
		r.exposer(EXPOSITION)
		if id in RETOURNES:
			r.orienter(Basis(Vector3.RIGHT, PI))
		r.lacet = c[0]
		r.tangage = c[1]
		r.cadrer()
		var img: Image = await r.image()
		var par := {}
		for t: int in TAILLES:
			par[t] = icone_depuis(img, t, SEUIL_FIN if cadrage_de(id) in ["bijou", "arme"] else SEUIL)
		icones[id] = par
	r.queue_free()
	print("ICONES ", icones.size(), " rendues ; sans modèle (ancienne icône gardée) : ", sans)
	if _seuls.is_empty():
		ecrire_atlas(icones)
	if _planche != "":
		planches(icones)
	await process_frame
	quit(0)

## Tous les objets à iconiser : registre + catalogue d'armes + objets de main hors registre.
static func ids_a_rendre() -> Array[String]:
	var ids := Inventaire.ids_connus()
	for h: String in HORS_REGISTRE:
		if not ids.has(h):
			ids.append(h)
	return ids

static func cadrage_de(id: String) -> String:
	var cat := Inventaire.categorie_de(id)
	var d := ObjetMonde._arme(id)
	if d != null and d.habillage == "bouclier":
		return "bouclier"
	if d != null or cat == "arme":
		return "arme"
	if cat == "armure":
		return "casque" if Inventaire.emplacement_de(id) == "tete" else "armure"
	if cat == "bijou" or ObjetMonde._genre_petit(id) != "":
		return "bijou"
	if id.begins_with("potion_") or id in ["pain_seigle", "viande_sechee", "coupe_argent"]:
		return "potion"
	if id.begins_with("tome_") or id in ["registre_hrafn", "journal_sigrun"]:
		return "tome"
	return "autre"

## Image de rendu (fond transparent) -> icône `t` x `t` : objet recadré serré dans (t-2) px, alpha tranché, contour 1 px.
static func icone_depuis(src: Image, t: int, seuil := SEUIL) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBAF)
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.02:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	var out := Image.create_empty(t, t, false, Image.FORMAT_RGBA8)
	if x1 < 0:
		return out
	# carré centré sur l'objet, prémultiplié (pas de frange sombre à la réduction)
	var cote := maxi(x1 - x0 + 1, y1 - y0 + 1)
	var carre := Image.create_empty(cote, cote, false, Image.FORMAT_RGBAF)
	var ox := (cote - (x1 - x0 + 1)) / 2
	var oy := (cote - (y1 - y0 + 1)) / 2
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := img.get_pixel(x, y)
			carre.set_pixel(x - x0 + ox, y - y0 + oy, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))
	var n := t - 2
	carre.resize(n, n, Image.INTERPOLATE_LANCZOS)
	var plein := {}
	for y in n:
		for x in n:
			var c := carre.get_pixel(x, y)
			if c.a < seuil:
				continue
			var a := maxf(c.a, 0.001)
			var col := Color(pow(clampf(c.r / a, 0, 1), GAMMA), pow(clampf(c.g / a, 0, 1), GAMMA), pow(clampf(c.b / a, 0, 1), GAMMA), 1.0)
			out.set_pixel(x + 1, y + 1, col)
			plein[Vector2i(x + 1, y + 1)] = true
	for y in t:
		for x in t:
			var p := Vector2i(x, y)
			if plein.has(p):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if plein.has(p + d):
					out.set_pixel(x, y, CONTOUR)
					break
	return out

## Atlas par taille (COLONNES colonnes, ordre de icones.json) + index.
static func ecrire_atlas(icones: Dictionary) -> void:
	var ids := icones.keys()
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var lignes := ceili(float(ids.size()) / COLONNES)
	for t: int in TAILLES:
		var atlas := Image.create_empty(COLONNES * t, maxi(1, lignes) * t, false, Image.FORMAT_RGBA8)
		for i in ids.size():
			atlas.blit_rect(icones[ids[i]][t], Rect2i(0, 0, t, t), Vector2i((i % COLONNES) * t, (i / COLONNES) * t))
		atlas.save_png(DOSSIER + "icones_%d.png" % t)
	var index := {"_doc": "Index des atlas d'icônes d'objets (outils/generer_icones.gd ; lu par IconesObjets). Ne pas éditer à la main.",
		"colonnes": COLONNES, "tailles": TAILLES, "ids": ids}
	var f := FileAccess.open(DOSSIER + "icones.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t"))
	f.close()
	print("ATLAS ", DOSSIER, " : ", ids.size(), " icônes x ", TAILLES)

## Planche de contrôle : par catégorie, ancienne icône (IconesCombat / MenuStyle) | nouvelle, ×4, sur vélin et sur cuir sombre.
func planches(icones: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_planche)
	var ids := icones.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := cadrage_de(a)
		var cb := cadrage_de(b)
		return a < b if ca == cb else ca < cb)
	var k := 4
	var case_l := 16 * k * 3 + 24      # ancienne | nouvelle (vélin) | nouvelle (cuir)
	var case_h := 16 * k + 8
	var cols := 4
	var lignes := ceili(float(ids.size()) / cols)
	var pl := Image.create_empty(cols * case_l, lignes * case_h, false, Image.FORMAT_RGBA8)
	pl.fill(Color("#2a2018"))
	var velin := Color("#e8d8b0")
	var cuir := Color("#1e1a17")
	for i in ids.size():
		var id: String = ids[i]
		var px := (i % cols) * case_l
		var py := (i / cols) * case_h
		var vieille := MenuStyle.icone_objet(id).get_image()
		var nouvelle: Image = icones[id][16]
		for j in 3:
			var fond := cuir if j == 2 else velin
			var rx := px + 4 + j * (16 * k + 8)
			pl.fill_rect(Rect2i(rx, py + 4, 16 * k, 16 * k), fond)
			var s: Image = (vieille if j == 0 else nouvelle).duplicate()
			s.convert(Image.FORMAT_RGBA8)
			s.resize(16 * k, 16 * k, Image.INTERPOLATE_NEAREST)
			pl.blend_rect(s, Rect2i(0, 0, 16 * k, 16 * k), Vector2i(rx, py + 4))
	pl.save_png(_planche.path_join("planche_icones.png"))
	# grandes (32 px ×3) sur vélin, avec le nom
	var g := Image.create_empty(cols * 2 * (32 * 3 + 8), ceili(float(ids.size()) / (cols * 2)) * (32 * 3 + 8), false, Image.FORMAT_RGBA8)
	g.fill(velin)
	for i in ids.size():
		var s: Image = (icones[ids[i]][32] as Image).duplicate()
		s.resize(96, 96, Image.INTERPOLATE_NEAREST)
		g.blend_rect(s, Rect2i(0, 0, 96, 96), Vector2i((i % (cols * 2)) * 104 + 4, (i / (cols * 2)) * 104 + 4))
	g.save_png(_planche.path_join("grandes_32.png"))
	var noms := FileAccess.open(_planche.path_join("ordre_planche.txt"), FileAccess.WRITE)
	noms.store_string("\n".join(PackedStringArray(ids)))
	noms.close()
	print("PLANCHE ", _planche)
