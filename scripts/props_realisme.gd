class_name PropsRealisme
## props/realisme_v5 (2026-11-19) : retour utilisateur sur les props Quaternius v5 des INTÉRIEURS et des SOUTERRAINS (« certains font plus
## jouet qu'autre chose ; il faut que ça colle au décor, rajoute des détails, que ce soit réaliste »). Trois leviers, sans nouvel atlas :
##   1. patine des matériaux partagés des atlas pq_* (contexte intérieur, crypte, grotte) : teinte + saturation ramenées vers le bois
##      patiné du bâti, occlusion cuite creusée (ao_gamma), taches de crasse en volume (usure), poussière sur les dessus et moisissure
##      sous terre (uniformes ajoutés à ps1_interieur.gdshader et crypte.gdshader, neutres par défaut : le reste du décor ne change pas) ;
##   2. retour à l'ancien modèle là où il était plus crédible (voir docs/PROPS_REMPLACEMENT.md, « Props v5 : réalisme ») ;
##   3. détails d'usage (cendres et tison devant les foyers, couverts entamés, miettes, peau jetée ; souterrains : objets renversés).
## L'EXTÉRIEUR n'est pas touché (contexte « exterieur » inchangé).
## `-- --sans-realisme-v5` rend exactement la v5 d'avant ce lot (captures « v5 actuel », mesures A/B).

static var actif := not ("--sans-realisme-v5" in OS.get_cmdline_user_args())

## Intérieurs (ps1_interieur) : atlas -> [teinte, saturation, usure, ao_gamma]. Bois : le pq_bois sortait plus clair, plus orangé et plus
## propre que les planches et rondins de la pièce (teinte 0,95-0,97) : ramené au bois sombre des meubles (bois_sombre 0,74).
const INTERIEUR := {
	"pq_bois": [Color(0.8, 0.72, 0.66), 0.74, 0.45, 1.2],      # ao_gamma 1,2 : à 1,6 le fond des étagères tombait au noir
	"pq_fer": [Color(0.7, 0.7, 0.72), 0.5, 0.45, 1.4],
	"pq_fer_v": [Color(0.8, 0.75, 0.68), 0.75, 0.5, 1.4],      # pierre, os, cire, terre cuite : plus de blanc « plastique » (crânes)
	"pq_tissu": [Color(0.84, 0.79, 0.74), 0.75, 0.45, 1.3],
	"pq_tissu_v": [Color(0.84, 0.79, 0.74), 0.75, 0.45, 1.3],
	"pq_props": [Color(0.8, 0.74, 0.68), 0.72, 0.5, 1.4],
	"pq_props_v": [Color(0.8, 0.74, 0.68), 0.72, 0.5, 1.4],
	"pq_page": [Color(0.86, 0.8, 0.72), 0.8, 0.35, 1.2],
}

## Sous terre (crypte.gdshader, matériaux de CrypteDecor / GrotteDecor) : la teinte et la saturation de props/maximum (PQ_TEINTE, 0,62)
## restent ; on ajoute [usure, poussière, moisi, ao_gamma, crasse]. Crasse 0 : la bande de pied de crypte.gdshader se cale sur le
## sol du niveau principal (y0) ; les props des étages inférieurs du donjon (alpha 1) sortiraient tout sombres. Le pied sombre vient
## de l'occlusion cuite (ao_gamma la creuse).
const CRYPTE := [0.6, 0.55, 0.18, 1.5, 0.0]
const GROTTE := [0.6, 0.3, 0.35, 1.5, 0.0]
## Bois et fer sous terre : la teinte grise de props/maximum (0,78 / 0,72 / 0,68, saturation 0,62), patinée en plus, faisait virer le bois
## au bleu-violet sous l'ambiante froide de la crypte (coffre de la niche d'Eirik, coffres des dépôts : « caisse bleue ») : bois brun
## chaud, fer sombre.
const SOUS_TERRE_ATLAS := {"pq_bois": [Color(0.86, 0.7, 0.56), 0.9], "pq_fer": [Color(0.62, 0.6, 0.58), 0.5]}
## Toiles d'araignée (pq_tissu_v) : pas de poussière grise par-dessus (elles SONT la poussière) ; atlas de tissu sous terre un peu moins.
const TISSU_SOUS_TERRE := 0.5

static func regler_interieur(m: ShaderMaterial, atlas: String) -> void:
	if not actif or not INTERIEUR.has(atlas):
		return
	var r: Array = INTERIEUR[atlas]
	m.set_shader_parameter("teinte", r[0])
	m.set_shader_parameter("saturation", r[1])
	m.set_shader_parameter("usure", r[2])
	m.set_shader_parameter("ao_gamma", r[3])

static func regler_sous_terre(m: ShaderMaterial, atlas: String, grotte: bool) -> void:
	if not actif:
		return
	var r: Array = GROTTE if grotte else CRYPTE
	var k := TISSU_SOUS_TERRE if atlas.begins_with("pq_tissu") else 1.0
	if SOUS_TERRE_ATLAS.has(atlas):
		m.set_shader_parameter("teinte", SOUS_TERRE_ATLAS[atlas][0])
		m.set_shader_parameter("saturation", SOUS_TERRE_ATLAS[atlas][1])
	m.set_shader_parameter("usure", float(r[0]) * k)
	m.set_shader_parameter("poussiere", float(r[1]) * k)
	m.set_shader_parameter("moisi", float(r[2]))
	m.set_shader_parameter("ao_gamma", r[3])
	m.set_shader_parameter("crasse", r[4])

# ------------------------------------------------------------------------------------------------ détails d'usage (intérieurs)
## Pas de tirage de `b.rng` (le reste de la pièce ne bouge pas) : bruit stable tiré de la position.
static func _h(p: Vector3, k: int) -> float:
	return fposmod(sin(p.x * 12.9898 + p.z * 78.233 + float(k) * 37.719) * 43758.5453, 1.0)

static func details() -> bool:
	return actif and Interieurs.v5()

## Petit biais de pose (rad, ±`ampl`) pour les meubles déplaçables (bancs, coffres) : rien n'est parfaitement d'équerre dans une pièce
## habitée ; 0 sans les détails (v5 d'avant, --sans-props-v5).
static func biais(p: Vector3, ampl := 0.05) -> float:
	return (_h(p, 300) - 0.5) * 2.0 * ampl if details() else 0.0

## Âtre : cendres et escarbilles tombées devant la bouche du foyer (flocons de cendre, morceaux de charbon, tison à demi brûlé) ;
## `p` = milieu du bord de l'âtre au sol (y absolu du plancher), `n` = vers la pièce, `larg` = largeur de la bouche. Rien de solide
## (au ras du sol, le joueur et les PNJ passent dessus).
static func cendres(b: Interieurs, p: Vector3, n: Vector3, larg: float) -> void:
	if not details():
		return
	var t := Vector3(n.z, 0, -n.x)
	var lac := atan2(n.x, n.z)
	for k in 6:
		var u := (_h(p, k) - 0.5) * larg
		var d := 0.05 + _h(p, k + 20) * 0.55
		var c := p + t * u + n * d
		var s := 0.08 + _h(p, k + 40) * 0.16
		b.bx(Vector3(c.x, p.y + 0.004 + 0.001 * k, c.z), Vector3(s, 0.008, s * (0.6 + _h(p, k + 60) * 0.6)), "cendre", lac + _h(p, k + 80) * 3.0)
	for k in 4:
		var u := (_h(p, k + 100) - 0.5) * larg * 1.2
		var d := 0.1 + _h(p, k + 120) * 0.7
		var c := p + t * u + n * d
		var s := 0.03 + _h(p, k + 140) * 0.03
		b.bx(Vector3(c.x, p.y + s * 0.5, c.z), Vector3(s, s * 0.8, s * 1.2), "charbon", _h(p, k + 160) * 3.0)
	# tison : bout de bûche noirci roulé hors du feu
	var ct := p + t * ((_h(p, 200) - 0.5) * larg * 0.6) + n * 0.25
	b.rondin(Vector3(ct.x, p.y + 0.045, ct.z), lac + PI * 0.5 + (_h(p, 201) - 0.5) * 1.2, 0.32, 0.045, 9700 + int(_h(p, 202) * 50.0), "rondin_sombre")
	b.bx(Vector3(ct.x, p.y + 0.05, ct.z) + t * 0.15, Vector3(0.07, 0.08, 0.09), "charbon", lac)

## Table servie et entamée : miettes et quignon, chope renversée et sa flaque, os rongé ; `c` = centre du plateau (y = dessus),
## `bz` = repère de la table (X le long du plateau). `long` : longueur du plateau.
static func table_entamee(b: Interieurs, c: Vector3, bz: Basis, long: float) -> void:
	if not details():
		return
	var lac := bz.get_euler().y
	for k in 7:
		var q := c + bz * Vector3((_h(c, k) - 0.5) * long * 0.6, 0, (_h(c, k + 10) - 0.5) * 0.45)
		var s := 0.012 + _h(c, k + 30) * 0.014
		b.bx(Vector3(q.x, c.y + s * 0.5, q.z), Vector3(s, s * 0.7, s * 1.3), "mie_q" if k % 3 else "pain_q", _h(c, k + 50) * 3.0)
	b.nq("q_tranche_pain", c + bz * Vector3(-0.05, 0.01, 0.22), lac + 0.8, 0.8)
	# chope couchée (renversée) au bout du plateau et flaque sombre de bière (places libres de _table : couverts à ±0,55 m)
	var pc := c + bz * Vector3(long * 0.5 - 0.2, 0, 0.05)
	if PropsQuaternius.existe("q_chope"):
		b.couche("q_chope", pc, lac + 0.6 + _h(c, 70), 0.13)
	b.bx(pc + bz * Vector3(-0.12, 0.002, -0.04), Vector3(0.2, 0.004, 0.13), "eau", lac + 0.3)
	b.os_sol(c + bz * Vector3(-long * 0.5 + 0.22, 0.012, -0.1), lac + 1.1)

## Peau jetée en travers d'un banc (fourrure froissée posée sur l'assise) ; `p` = dessus de l'assise.
static func peau_jetee(b: Interieurs, p: Vector3, lacet: float, mat := "peau_sombre") -> void:
	if not details():
		return
	b.toile_plate(p + Vector3(0, 0.012, 0), Vector2(0.55, 0.5), lacet + 0.25, mat)

# ------------------------------------------------------------------------------------------------ retours à l'ancien
## Crypte : coffres de décor coffre_a/b/c (niche d'Eirik) : l'ancien coffre maison (planches brunes, ferrures, couvercle bombé) revient ;
## le pq_coffre_ferme y restait une boîte lisse et violacée sous la lumière de la crypte, même patiné (planches réalisme_souterrains).
static func ancien_crypte(nom: String) -> bool:
	return actif and nom.begins_with("coffre_")

## Lits : le lit procédural (montants, chevet haut, paillasse, fourrure drapée) revient à la place du pq_lit étiré au cadre (caisse
## lisse, bord bleuté, « jouet » à côté des PNJ ; planches réalisme_intérieurs).
static func lit_ancien() -> bool:
	return actif
