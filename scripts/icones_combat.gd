class_name IconesCombat
extends RefCounted
## Icônes pixel du combat (HUD, plus tard inventaire) : 16x16 pour ce que tient une main (armes, objets, 14 sorts),
## 8x8 pour les statuts actifs. Dessinées en motifs ASCII (ci-dessous) → Image → ImageTexture (filtre nearest à
## l'affichage : les Control de l'interface dessinent en pixels entiers, échelle EchelleUi entière).
## Motifs : '.' = transparent ; '1'..'5' = palette de l'école (sombre → clair) ; lettres = couleurs fixes (FIXES).
## Le contour (couleur 0 de la palette) est ajouté tout seul autour de chaque pixel plein (voisinage 4) :
## laisser 1 px vide sur les bords du motif.
## Les motifs ont été composés avec un petit générateur (formes + dégradés) puis retouchés ; on peut les éditer à la main.
## Cache statique : appeler IconesCombat.vider() à la fermeture (fait par HudCombat._exit_tree), sinon les textures
## seraient libérées après le moteur de rendu (même piège que Palette.vider).

## Palettes : [contour, 1 sombre, 2, 3, 4, 5 clair]. Feu rouge → orange → jaune → crème ; glace blancs → bleus ;
## électricité bleu-violet → blanc ; ténèbres violets → noir (référentiel de magie).
const PALETTES := {
	"feu": ["#2a0d08", "#7a1c10", "#c8381a", "#f07a22", "#ffc844", "#fff2c0"],
	"glace": ["#0b1a33", "#1f4a8a", "#3a7fd0", "#7fc0f0", "#c8ecff", "#ffffff"],
	"electricite": ["#120a30", "#3a2a9a", "#5a5ae0", "#8aa0ff", "#c8d8ff", "#ffffff"],
	"tenebres": ["#07040f", "#2a0f45", "#4a1f7a", "#7a3fc0", "#b07aef", "#e8d0ff"],
	"soin": ["#1a1408", "#6a5218", "#a88a2a", "#e8c050", "#f4dc80", "#fff8d8"],
	"protection": ["#0b1426", "#2a3f66", "#4a6a9a", "#8ab0d8", "#c8e0f4", "#ffffff"],
	"metal": ["#0b0f1a", "#3a4458", "#56627a", "#8a96ad", "#c8d0dc", "#ffffff"],
	"cuir": ["#140c06", "#3a2414", "#5a3a20", "#8a5a32", "#b07a48", "#d8a878"],
}
const FIXES := {
	"k": "#0b0f1a", "d": "#3a4458", "m": "#56627a", "l": "#8a96ad", "s": "#c8d0dc", "w": "#f4f6fa",
	"b": "#4a2e18", "B": "#7a4e2a", "g": "#e8a64a", "G": "#a8702a", "r": "#e0473a", "R": "#8a1c1c",
	"v": "#7fc87a", "V": "#3f8a4a",
}
## Couleur d'accent par école (jauges de charge, liserés, barre de durée des statuts).
const ACCENTS := {
	"feu": "#f07a22", "glace": "#7fc0f0", "electricite": "#8aa0ff", "tenebres": "#b07aef",
	"soin": "#e8c050", "protection": "#8ab0d8", "": "#c8d0dc",
}
## Noms de statuts tolérés → motif.
const ALIAS_STATUTS := {
	"brule": "brulure", "feu": "brulure", "gele": "gel", "ralenti": "gel", "glace": "gel", "electrocute": "choc",
	"electricite": "choc", "corrompu": "corruption", "tenebres": "corruption", "regeneration": "soin", "bouclier": "protection", "lenteur": "gel",
}

static var _cache := {}

## Icône 16x16 de ce que tient une main (ids de MOTIFS ; "" = main nue). Repli (losange « ? ») si l'id est inconnu.
static func icone(id: String) -> Texture2D:
	if id == "":
		id = "vide"
	if not MOTIFS.has(id):
		id = "inconnu"
	return _texture("m:" + id, MOTIFS[id])

## Icône 8x8 d'un statut (brulure, gel, choc, corruption, soin, protection, enchant_<école>…). Repli : petit losange.
static func icone_statut(nom: String) -> Texture2D:
	var id: String = ALIAS_STATUTS.get(nom, nom)
	if not MOTIFS_STATUTS.has(id):
		id = "inconnu"
	return _texture("s:" + id, MOTIFS_STATUTS[id])

static func connu(id: String) -> bool:
	return MOTIFS.has(id) and id != "inconnu"

## École d'un id de main (palette de son motif) : "feu", "glace"…, "" pour les armes et objets.
static func ecole_de(id: String) -> String:
	if not MOTIFS.has(id) or id == "torche":
		return ""
	var p: String = MOTIFS[id][0]
	return "" if p == "metal" or p == "cuir" else p

## École d'un statut (couleur de sa barre de durée).
static func ecole_statut(nom: String) -> String:
	var id: String = ALIAS_STATUTS.get(nom, nom)
	if MOTIFS_STATUTS.has(id):
		var p: String = MOTIFS_STATUTS[id][0]
		return "" if p == "metal" else p
	return ""

static func accent(ecole: String) -> Color:
	return Color(ACCENTS.get(ecole, ACCENTS[""]))

static func vider() -> void:
	_cache.clear()

static func _texture(cle: String, motif: Array) -> Texture2D:
	if _cache.has(cle):
		return _cache[cle]
	var tex := ImageTexture.create_from_image(image(motif))
	_cache[cle] = tex
	return tex

## Image RGBA8 d'un motif [palette, lignes], contour compris.
static func image(motif: Array) -> Image:
	var pal: Array = PALETTES[motif[0]]
	var lignes: Array = motif[1]
	var h := lignes.size()
	var w: int = (lignes[0] as String).length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var plein := {}
	for y in h:
		var l: String = lignes[y]
		for x in w:
			var c := l[x]
			if c == ".":
				continue
			plein[Vector2i(x, y)] = true
			img.set_pixel(x, y, Color(pal[int(c)]) if c.is_valid_int() else Color(FIXES.get(c, "#ff00ff")))
	var contour := Color(pal[0])
	for y in h:
		for x in w:
			if plein.has(Vector2i(x, y)):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if plein.has(Vector2i(x, y) + d):
					img.set_pixel(x, y, contour)
					break
	return img

const MOTIFS := {
	"jet_flammes": ["feu", [
		"................",
		"............2...",
		"............222.",
		"........21.2333.",
		".......23323433.",
		".....2234334444.",
		"...233444444555.",
		".44455555555555.",
		".44455555555555.",
		"...233444444555.",
		".....2234334444.",
		".......23323433.",
		"........2..2333.",
		"..........1.222.",
		"............2...",
		"................",
	]],
	"boule_feu": ["feu", [
		"................",
		"................",
		".......23333....",
		"......2334443...",
		".....223455543..",
		".....223555543..",
		".....223455543..",
		".....223445433..",
		"....1222333332..",
		"...1..2222222...",
		"..1..3322222....",
		".1..3..1........",
		"...3..1.........",
		"..2..1..........",
		"....1...........",
		"................",
	]],
	"explosion_incendiaire": ["feu", [
		"..........2.....",
		".........2......",
		".....2...2......",
		".....2...3......",
		"2.....3333......",
		".223.33443322...",
		"....3345543.....",
		"....34555543....",
		"....34555543....",
		"..2223455433.2..",
		".....334433...2.",
		".....3.332......",
		".........2......",
		".....2..........",
		"....2...........",
		"................",
	]],
	"eclat_glace": ["glace", [
		"................",
		"................",
		".............5..",
		"...........45...",
		"...45....4452...",
		"..552...4452....",
		".552..44452.....",
		"....4444522.....",
		"....445522......",
		"...445522.......",
		"...455222.......",
		"...55222...55...",
		"..552....455....",
		"........452.....",
		"........5.......",
		"................",
	]],
	"lance_givre": ["glace", [
		"................",
		"..............5.",
		"............45..",
		".........44452..",
		"........44452...",
		"........44522...",
		"........45222...",
		".......45222....",
		".....4.52.......",
		"....4.32........",
		".....32.........",
		"....32...4......",
		"...32...4.......",
		"..32............",
		".32.............",
		"................",
	]],
	"nova_gelee": ["glace", [
		"................",
		"................",
		"................",
		"................",
		".......55.......",
		".......55.......",
		".......55.......",
		".......55.......",
		"...55..55.......",
		"...55.4552.55...",
		"...55.4552.55...",
		"...55.4552.55...",
		"..45524552.55...",
		".34552455245523.",
		".33333333333333.",
		"................",
	]],
	"arc_electrique": ["electricite", [
		"................",
		"................",
		"................",
		"................",
		".........3....3.",
		"....3...353..353",
		"...353.35353353.",
		"..353533535353..",
		".35335353.343...",
		"353..343..234...",
		".3...242...242..",
		"......422...422.",
		"......242...242.",
		"......242....2..",
		".......2........",
		"................",
	]],
	"chaine_eclairs": ["electricite", [
		"................",
		"............2...",
		"...........333..",
		"..........23432.",
		"........2.5333..",
		".......3335.2...",
		"......234325....",
		".......33355....",
		".......52.......",
		".....55.........",
		"...25.5.........",
		"..333...........",
		".23432..........",
		"..333...........",
		"...2............",
		"................",
	]],
	"tempete_statique": ["electricite", [
		"..........2.....",
		"....222222222...",
		"..222332233322..",
		".22223322333222.",
		".11122222222211.",
		"..111111112111..",
		"...3531111.343..",
		"...353.353.343..",
		"..3533.353.3343.",
		"..3555333534443.",
		"...35335553343..",
		"...3533353.343..",
		"..335..353..343.",
		"..353...533..3..",
		"...3....353.....",
		".........3......",
	]],
	"trait_ombre": ["tenebres", [
		"................",
		"................",
		"................",
		"................",
		"........22333...",
		"..111..2234443..",
		".....112234543..",
		".2222222234543..",
		"......22234443..",
		"...22212223332..",
		".11.....22222...",
		"................",
		"................",
		"................",
		"................",
		"................",
	]],
	"drain_vie": ["tenebres", [
		"................",
		"...........R....",
		"..........Rrr...",
		".........Rrrrr..",
		".........Rrrrr..",
		".........Rrrrr..",
		".......22RRRRR..",
		"......2..3RRR...",
		"...222.33.2.....",
		"..2...3.22......",
		".34433.2........",
		".4554.2.........",
		".45542..........",
		".3443...........",
		"................",
		"................",
	]],
	"explosion_obscure": ["tenebres", [
		"................",
		"................",
		"................",
		"................",
		"................",
		".......44.......",
		".......44.......",
		"....44.44.......",
		"....44.44.44....",
		"....44.44.44....",
		"..444422224444..",
		"..444223322444..",
		"..444235532444..",
		"..434235532444..",
		".22222222222222.",
		"......2222......",
	]],
	"soin": ["soin", [
		"................",
		".......VV.......",
		"....VVVVVVVV....",
		"...VVV5533VVV...",
		"..VVvv5533vvVV..",
		"..VVvv5533vvVV..",
		"..V5555533333V..",
		".VV5555533333VV.",
		".VV3333333333VV.",
		"..V3333333333V..",
		"..VVvv3333vvVV..",
		"..VVvv3333vvVV..",
		"...VVV3333VVV...",
		"....VVVVVVVV....",
		".......VV.......",
		"................",
	]],
	"protection": ["protection", [
		"................",
		".11111111111111.",
		".12222222222221.",
		".12333353333321.",
		".12333353333321.",
		".12353353353321.",
		".12335355353321.",
		".12333555333321.",
		".12333353333321.",
		".12333353333321.",
		"..123335333321..",
		"..122333333221..",
		"...1223333221...",
		"....12233221....",
		".....122221.....",
		"......1111......",
	]],
	"epee": ["metal", [
		"................",
		"............ws..",
		"...........wsl..",
		"..........wsl...",
		".........wsl....",
		"........wsl.....",
		".......wsl......",
		"..G...wsl.......",
		"...g.wsl........",
		"....gsl.........",
		"....bgg.........",
		"...bB.gG........",
		"..bB...G........",
		".gB.............",
		".gg.............",
		"................",
	]],
	"torche": ["feu", [
		"................",
		"........4.......",
		".......43.......",
		"......4334......",
		".....435534.....",
		".....345543.....",
		".....234432.....",
		"......2332......",
		".....mllllm.....",
		"......dmmd......",
		"......bBBb......",
		".......bB.......",
		".......bB.......",
		".......bB.......",
		".......bb.......",
		"................",
	]],
	"bouclier": ["metal", [
		"................",
		".......mm.......",
		"....mmmbBmmm....",
		"...mmBbbgBbmm...",
		"..mmBBbbBBbbmm..",
		"..mbBBbbBBbbBm..",
		"..mbBBllllbbBm..",
		".mbbBBlsslbbBBm.",
		".mbgBBlsslbbgBm.",
		"..mbBBllllbbBm..",
		"..mbBBbbBBbbBm..",
		"..mmBBbbBBbbmm..",
		"...mmBbbgBbmm...",
		"....mmmbBmmm....",
		".......mm.......",
		"................",
	]],
	"vide": ["cuir", [
		"................",
		"................",
		"......3.3.......",
		".....3434.3.....",
		".....3434343....",
		".....34343434...",
		".3...34343434...",
		".43..34343434...",
		"..43.3444444....",
		"..344444444.....",
		"...34444442.....",
		"....3444432.....",
		".....24432......",
		".....23332......",
		"................",
		"................",
	]],
	"inconnu": ["metal", [
		"................",
		"................",
		".......mm.......",
		"......mssm......",
		".....mssssm.....",
		"....msskkslm....",
		"...mssssskllm...",
		"..mssssskllllm..",
		"..mssssklllllm..",
		"...mssllllllm...",
		"....mllklllm....",
		".....mllllm.....",
		"......mllm......",
		".......mm.......",
		"................",
		"................",
	]],
}

const MOTIFS_STATUTS := {
	"brulure": ["feu", [
		"...3....",
		"..343...",
		"..3443..",
		".34543..",
		".345543.",
		".245542.",
		"..2442..",
		"........",
	]],
	"gel": ["glace", [
		"...4....",
		".4.4.4..",
		"..454...",
		"4455544.",
		"..454...",
		".4.4.4..",
		"...4....",
		"........",
	]],
	"choc": ["electricite", [
		"....44..",
		"...44...",
		"..445...",
		".55554..",
		"...54...",
		"..45....",
		"..4.....",
		"........",
	]],
	"corruption": ["tenebres", [
		"..333...",
		".3...3..",
		".3.44.3.",
		".3.4.3..",
		".3.443..",
		"..3.....",
		"...333..",
		"........",
	]],
	"soin": ["soin", [
		"..33....",
		"..53....",
		"533333..",
		"333333..",
		"..33....",
		"..33....",
		"........",
		"........",
	]],
	"protection": ["protection", [
		"1111111.",
		"1335331.",
		"1355531.",
		"1335331.",
		".13531..",
		"..131...",
		"...1....",
		"........",
	]],
	"enchant_feu": ["feu", [
		"......5.",
		".....45.",
		"....45..",
		"...45...",
		"g.45....",
		".gg.....",
		".bg.....",
		"b.......",
	]],
	"enchant_glace": ["glace", [
		"......5.",
		".....45.",
		"....45..",
		"...45...",
		"g.45....",
		".gg.....",
		".bg.....",
		"b.......",
	]],
	"enchant_electricite": ["electricite", [
		"......5.",
		".....45.",
		"....45..",
		"...45...",
		"g.45....",
		".gg.....",
		".bg.....",
		"b.......",
	]],
	"enchant_tenebres": ["tenebres", [
		"......5.",
		".....45.",
		"....45..",
		"...45...",
		"g.45....",
		".gg.....",
		".bg.....",
		"b.......",
	]],
	"inconnu": ["metal", [
		"...l....",
		"..lsl...",
		".lsssl..",
		"lsswssl.",
		".lsssl..",
		"..lsl...",
		"...l....",
		"........",
	]],
}
