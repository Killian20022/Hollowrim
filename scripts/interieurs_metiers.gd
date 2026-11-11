extends RefCounted
## PropsMax v3 : les bâtiments ouverts (BatimentsOuverts) reçoivent, APRÈS leur mobilier de fonction, quelques coins de MÉTIER
## (props texturés pq_* et q_* fondus dans les lots de la pièce, aucun nœud par prop) posés contre les murs par le même
## répartiteur (`Murs` : porte, débattement du vantail, fenêtres et meubles déjà posés dégagés ; le milieu de la pièce reste libre
## pour le joueur et les PNJ). Uniquement en mode pq : `--props-quat-ancien` rend la pièce d'avant à l'identique. Aucune lumière
## ajoutée (budget de 8 lumières par maillage), aucun tirage de `b.rng` (le reste de la pièce ne bouge pas).
##
## Une composition : [long (le long du mur), prof (depuis le mur), haut (monte au-dessus des appuis de fenêtre), items] ; un item :
## [nom, dx (le long du mur, depuis le centre), dz (depuis la face du mur), lacet°, h (0 = au sol, sinon au-dessus du plancher),
## solide, échelle (1 par défaut)]. Noms spéciaux : « cadre_peau », « raquette », « peau » (pièces maison des chasseurs).

const U_SECHOIR := [1.3, 0.25, true, [["cadre_peau", 0.0, 0.12, 0.0, 0.0, false]]]
const U_PEAU := [1.05, 0.1, true, [["peau", -0.15, 0.03, 0.0, 1.55, false], ["raquette", 0.42, 0.04, 0.0, 1.3, false]]]
const U_PIEGE := [0.7, 0.5, false, [["q_piege_ours", -0.08, 0.26, 18.0, 0.0, false], ["pq_corde_1", 0.2, 0.3, 0.0, 0.0, false]]]
const U_CAISSE_CORDE := [0.78, 0.72, false, [["pq_caisse", 0.0, 0.35, 4.0, 0.0, true], ["pq_corde_1", -0.05, 0.36, 30.0, 0.71, false],
	["q_hachette", 0.16, 0.3, 80.0, 0.71, false]]]
const U_CAISSE_SAC := [0.78, 0.72, false, [["pq_caisse", 0.0, 0.35, -5.0, 0.0, true], ["pq_sac", 0.0, 0.35, 25.0, 0.71, false]]]
const U_CAISSES := [0.78, 0.72, false, [["pq_caisse", 0.0, 0.35, 3.0, 0.0, true], ["pq_caisse", 0.02, 0.35, -14.0, 0.71, false]]]
const U_BOIS := [0.95, 0.82, false, [["buches", 0.0, 0.4, 0.0, 0.0, false]]]
const U_TONNEAU := [0.8, 0.78, false, [["pq_tonneau", 0.0, 0.38, 0.0, 0.0, true]]]
const U_POMMES := [0.8, 0.78, false, [["pq_tonneau_pommes", 0.0, 0.38, 0.0, 0.0, true]]]
const U_SAC := [0.65, 0.58, false, [["pq_sac", 0.0, 0.28, 15.0, 0.0, true]]]
const U_SACS := [1.15, 0.6, false, [["pq_sac", -0.28, 0.29, 10.0, 0.0, true], ["pq_sac", 0.3, 0.29, -30.0, 0.0, true]]]
const U_CAGEOT := [0.78, 0.58, false, [["pq_cageot_carottes", 0.0, 0.28, 4.0, 0.0, true], ["q_chou", -0.12, 0.28, 0.0, 0.41, false],
	["q_chou", 0.14, 0.26, 50.0, 0.41, false]]]
const U_CAGEOTS := [0.78, 0.45, false, [["pq_cageot_vide", 0.0, 0.22, 6.0, 0.0, true], ["pq_cageot_vide", 0.0, 0.22, -4.0, 0.18, false],
	["pq_cageot_pommes", 0.0, 0.22, 10.0, 0.36, false]]]
const U_SEAU := [0.5, 0.45, false, [["pq_seau_bois", 0.0, 0.22, 0.0, 0.0, false]]]
const U_OUTILS := [0.95, 0.2, true, [["pq_pioche", -0.2, 0.08, 0.0, 0.0, false], ["pq_hache_outil", 0.33, 0.05, 0.0, 0.0, false]]]
const U_SUPPORT := [1.3, 0.72, false, [["pq_support_tonneau", 0.0, 0.34, 0.0, 0.0, true]]]
const U_ETABLI := [2.0, 1.0, false, [["pq_etabli", 0.0, 0.5, 0.0, 0.0, true]]]
const U_ARMES := [0.78, 0.72, false, [["pq_caisse", 0.0, 0.35, -6.0, 0.0, true], ["pq_bouclier_bois", 0.0, 0.36, 4.0, 0.7, false]]]
const MAX_COINS := 6

## Coins par métier, par ordre de priorité (les trappeurs et chasseurs : séchoir, peaux, pièges ; les paysans : grain, légumes,
## outils, bois ; le meunier : farine ; le grenier : caisses et pommes) ; au plus MAX_COINS par pièce, chacun là où il tient.
static func coins(pl: Dictionary) -> Array:
	var id := String(pl["id"])
	var chasseur := false
	for h in BatimentsOuverts.donnees(id).get("habitants", []):
		if String(h).contains("chass"):
			chasseur = true
	match String(pl["fonction"]):
		"maison":
			if chasseur:
				return [["séchoir", U_SECHOIR], ["peaux", U_PEAU], ["pièges", U_PIEGE], ["caisse", U_CAISSE_CORDE], ["bois", U_BOIS], ["sac", U_SAC]]
			return [["sacs", U_SACS], ["légumes", U_CAGEOT], ["outils", U_OUTILS], ["bois", U_BOIS], ["cageots", U_CAGEOTS], ["seau", U_SEAU]]
		"ferme":
			return [["sacs", U_SACS], ["légumes", U_CAGEOT], ["outils", U_OUTILS], ["tonneaux", U_SUPPORT], ["cageots", U_CAGEOTS], ["bois", U_BOIS]]
		"moulin", "moulin_vent":
			return [["sacs", U_SACS], ["caisse", U_CAISSE_SAC], ["tonneaux", U_SUPPORT], ["sacs_2", U_SACS], ["cageots", U_CAGEOTS], ["caisse_2", U_CAISSE_SAC]]
		"grenier":
			return [["caisses", U_CAISSES], ["pommes", U_POMMES], ["cageots", U_CAGEOTS], ["sacs", U_SACS], ["caisse", U_CAISSE_SAC]]
		"grange":
			return [["établi", U_ETABLI], ["outils", U_OUTILS], ["sacs", U_SACS], ["bois", U_BOIS], ["seau", U_SEAU]]
		"etable":
			return [["seau", U_SEAU], ["sac", U_SAC], ["seau_2", U_SEAU]]
		"tour":
			return [["armes", U_ARMES], ["tonneau", U_TONNEAU]]
	return []

static func habiller(b: Interieurs, pl: Dictionary, murs) -> void:
	if not PropsQuaternius.pq:
		return
	var F := Interieurs.F
	var poses := 0
	for c: Array in coins(pl):
		if poses >= MAX_COINS:
			break
		var d: Array = c[1]
		var r: Dictionary = murs.poser_ou(["-Z", "+X", "-X", "+Z"], float(d[0]), float(d[1]), bool(d[2]))
		if r.is_empty():
			if OS.get_cmdline_user_args().has("--interieurs-debug"):
				print("PropsMaxInt : %s / %s refusé (pas de mur libre)" % [pl["id"], c[0]])
			continue
		var n: Vector3 = r["n"]
		var tg := Vector3(n.z, 0, -n.x)
		var mur: Vector3 = (r["pos"] as Vector3) - n * (float(d[1]) * 0.5 + 0.03)
		var lacet: float = r["lacet"]
		for it: Array in d[3]:
			var nom: String = it[0]
			var p := mur + tg * float(it[1]) + n * float(it[2])
			var h := float(it[4])
			p.y = F + h if h > 0.0 else 0.0
			var lac := lacet + deg_to_rad(float(it[3]))
			match nom:
				"cadre_peau":
					InterieursMaisons._cadre_peau(b, Vector3(p.x, 0.0, p.z), lac)
				"raquette":
					InterieursMaisons._raquette(b, p, lac)
				"buches":
					_buches(b, p, lac)
				"peau":
					b.peau_murale(p, lac, 0.8, 1.0, "peau_sombre")
				_:
					b.q(nom, p, lac, float(it[6]) if it.size() > 6 else 1.0, {}, bool(it[5]))
		poses += 1
		if OS.get_cmdline_user_args().has("--interieurs-debug"):
			print("PropsMaxInt : %s / %s posé mur %s t=%.2f mur=(%.2f,%.2f) n=(%.0f,%.0f) a=(%.2f,%.2f)" % [pl["id"], c[0], _mur(n), float(r["t"]), mur.x, mur.z, n.x, n.z, float(pl["ax"]), float(pl["az"])])

static func _mur(n: Vector3) -> String:
	if n.z > 0.5:
		return "-Z"
	if n.z < -0.5:
		return "+Z"
	return "-X" if n.x > 0.5 else "+X"

## Bûches de chauffage empilées contre le mur (3 + 2 + 1 rondins de 0,75 m, bois de rondin maison), bouts sciés vers la pièce (lisibles),
## et leur boîte de collision.
static func _buches(b: Interieurs, p: Vector3, lacet: float) -> void:
	var F := Interieurs.F
	var bz := Basis(Vector3.UP, lacet)
	var r := 0.125     # > 0,12 : rondin maison (BatiGeo), pas la bûche Quaternius étirée
	var g := 9100 + int(absf(p.x) * 37.0 + absf(p.z) * 11.0)
	for rang in 3:
		for k in 3 - rang:
			var dz := (k - (2 - rang) * 0.5) * r * 2.05
			var c := p + bz * Vector3(dz, 0, 0) + Vector3(0, F + r + rang * r * 1.75, 0)
			b.rondin(c, lacet + PI * 0.5, 0.75, r * (1.0 + 0.06 * ((k + rang) % 2)), g + rang * 3 + k)      # bout des bûches vers la pièce
	b.solide(p + Vector3(0, F + 0.3, 0), Vector3(0.78, 0.6, 0.76), lacet)
