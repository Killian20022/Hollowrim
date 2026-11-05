class_name Faune
extends Node
## Faune vivante (lot F1 + F2 + F3 partiel, nuit du 2026-11-05) : apparition des bêtes sauvages par biome et par heure, vie des
## domestiques (étable / enclos le soir, sommeil, husky suiveur), LOD des bêtes lointaines. Fiche : data/vie/faune.json ; espèces,
## biomes, heures et tailles de groupe : BeteQuat.ESPECES (champs `biomes`, `heures`, `groupe`).
##
## Nœud AUTONOME (enfant du monde, comme GardesVillage) : il lit lui-même `cycle.heure`, aucune horloge ni aucun autre nœud requis.
## - TERRITOIRES : au démarrage, ~44 points tirés avec une graine dédiée (ZoneBiome.graine("faune") ; ni monde.rng ni randf global :
##   le reste du monde ne change pas), chacun avec son biome, son espèce, la taille de son groupe et un tirage `u` ∈ [0, 1).
##   Un territoire est « de service » à l'heure h si u < poids_heure(espèce.heures, h) : poids 1 dans la plage de l'espèce, `hors_plage`
##   (0,2) ailleurs (« plutôt la nuit », pas « jamais le jour »). Même graine, même carte → mêmes territoires (test_faune).
## - APPARITION : toutes les 1,5 s au plus une bête / un groupe, d'un territoire de service entre 46 et 105 m du joueur et HORS de son
##   champ de vision, sous des plafonds (9 bêtes en tout, par espèce). Un groupe repart (supprimé) à plus de 135 m, ou quand son heure
##   est passée et que le joueur ne le voit pas. Création : monde.creer_ennemi (via `fabrique`), idents « faune_<territoire>_<membre> ».
## - REPEUPLEMENT : un territoire dont une bête a été tuée reste vide 24 h de jeu (≈ 40 min réelles), puis reprend, hors de vue.
##   Sauvegarde : exporter() / importer() (clé « faune » de la sauvegarde) ; les bêtes sauvages tuées ne vont PAS dans draugrs_morts.
## - DOMESTIQUES : créés ici (liste de la fiche). 19 h : ils rejoignent l'abri de la fiche (aucun étable aujourd'hui, `abris` est vide)
##   sinon se regroupent contre le côté fermé de leur enclos ; 21 h : ils dorment (tête basse, clip Eat au quart de vitesse) ; 6 h : ils
##   se réveillent, 7 h : ils reprennent leur place. Le husky suit le joueur qui passe à moins de 3,5 m dans le village et rentre chez
##   lui si l'un ou l'autre s'éloigne de plus de 52 m du village.
## - LOD : une bête à plus de 90 m (ou toutes, sous terre) est figée (process coupé) tant qu'elle n'est pas en combat.
## - `complet` (--paisible) : peuple tout ce qui convient à l'heure dans 105 m du joueur, sans plafond ni contrainte de vue, domestiques
##   posés d'emblée à leur place de l'heure ; `actualiser()` force le tour (captures qui changent l'heure ou la pose).

const FICHE := "res://data/vie/faune.json"
const PERIODES := {"aube": [5.0, 8.0], "jour": [8.0, 17.0], "crepuscule": [17.0, 20.0], "nuit": [20.0, 5.0]}
const PAS := 0.5          # s entre deux tours de la logique (2 Hz)

var monde: Node
var joueur: Node3D
var cycle: Object                    # `heure` (h, 0-24)
var fabrique: Callable               # (espece, position, lacet rad, options) -> bête
var registre: Dictionary = {}        # monde.draugrs : les bêtes sauvages en sortent quand elles meurent ou repartent
var biome_de: Callable               # (x, z) -> "foret" | "clairiere" | "plaine_neige" | "abords_village" | "village"
var hauteur_de: Callable             # (x, z) -> y
var accepte: Callable                # (x, z) -> bool : terrain praticable (pente, décor)
var complet := false
var fiche: Dictionary = {}
var territoires: Array = []
var actifs := {}                     # territoire -> Array de bêtes
var tues := {}                       # territoire -> heure de jeu cumulée de la mort
var temps := 0.0                     # heures de jeu cumulées (repeuplement)
var domestiques: Array = []          # [{"bete", "def", "phase"}]
var _rng := RandomNumberGenerator.new()
var _h_prec := -1.0
var _t := 0.0
var _t_spawn := 0.0
var _grille := {}
var _seuils := [0.0, 0.0]            # (arbres dans 24x24 m) : clairière ≥ [0], forêt ≥ [1]

# ------------------------------------------------------------------ fonctions pures (testées)

static func charger_fiche() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHE))
	return d if d is Dictionary else {}

static func dans_periode(periode: String, h: float, marge := 0.0) -> bool:
	var r: Array = PERIODES[periode]
	var a := fposmod(float(r[0]) - marge, 24.0)
	var b := fposmod(float(r[1]) + marge, 24.0)
	h = fposmod(h, 24.0)
	return (h >= a and h < b) if a < b else (h >= a or h < b)

## Poids d'une espèce à l'heure h : 1 dans sa plage, `hors` ailleurs. « toujours » ; « jour+aube » = deux périodes ; un « + » final
## (« nuit+ ») élargit la plage d'une heure de chaque côté.
static func poids_heure(heures: String, h: float, hors := 0.2) -> float:
	if heures == "toujours":
		return 1.0
	var etendu := heures.ends_with("+")
	for p in heures.trim_suffix("+").split("+"):
		if PERIODES.has(p) and dans_periode(p, h, 1.0 if etendu else 0.0):
			return 1.0
	return hors

## Phase de la journée d'un domestique : jour (7-19), soir (19-21), nuit (21-6), aube (6-7).
static func phase_domestique(h: float, f: Dictionary) -> String:
	h = fposmod(h, 24.0)
	var soir := float(f.get("soir", 19.0))
	var nuit := float(f.get("nuit", 21.0))
	var aube := float(f.get("aube", 6.0))
	var jour := float(f.get("jour", 7.0))
	if h >= nuit or h < aube:
		return "nuit"
	if h >= soir:
		return "soir"
	if h < jour:
		return "aube"
	return "jour"

static func especes_sauvages() -> Array:
	var r := []
	for nom: String in BeteQuat.ESPECES:
		if not bool(BeteQuat.ESPECES[nom].get("domestique", false)):
			r.append(nom)
	return r

## Territoires de la carte : déterministes (graine dédiée), RNG propre. `biome_de` et `accepte` décrivent le terrain.
static func generer_territoires(f: Dictionary, biome_de: Callable, accepte: Callable) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine(String(f.get("graine", "faune")))
	var n := int(f.get("territoires", 40))
	var zone := float(f.get("zone", 110.0))
	var espace := float(f.get("espacement", 26.0))
	var res: Array = []
	var aff: Dictionary = f.get("affinites", {})
	for essai in n * 40:
		if res.size() >= n:
			break
		var x := rng.randf_range(-zone, zone)
		var z := rng.randf_range(-zone, zone)
		var ok := true
		for i: Dictionary in f.get("interdits", []):
			if Vector2(x - float(i["x"]), z - float(i["z"])).length() < float(i["r"]):
				ok = false
		for t: Dictionary in res:
			if Vector2(x - t["x"], z - t["z"]).length() < espace:
				ok = false
		if not ok or not accepte.call(x, z):
			continue
		var biome: String = biome_de.call(x, z)
		var choix: Array = []
		var poids: Array = []
		for nom in especes_sauvages():
			var fi: Dictionary = BeteQuat.ESPECES[nom]
			if biome in fi["biomes"]:
				choix.append(nom)
				poids.append(float(aff.get(nom, {}).get(biome, 1.0)))
		if choix.is_empty():
			continue
		var total := 0.0
		for p: float in poids:
			total += p
		var tirage := rng.randf() * total
		var k := 0
		while k < choix.size() - 1 and tirage > poids[k]:
			tirage -= poids[k]
			k += 1
		var g: Array = BeteQuat.ESPECES[choix[k]]["groupe"]
		res.append({"id": res.size(), "espece": choix[k], "biome": biome, "x": x, "z": z,
			"groupe": rng.randi_range(int(g[0]), int(g[1])), "u": rng.randf()})
	return res

# ------------------------------------------------------------------ mise en route

func demarrer() -> void:
	fiche = charger_fiche()
	_rng.seed = ZoneBiome.graine("faune_vie")
	if not biome_de.is_valid():
		_construire_grille()
		biome_de = Callable(self, "biome_en")
	if not accepte.is_valid():
		accepte = func(_x: float, _z: float) -> bool: return true
	territoires = generer_territoires(fiche, biome_de, accepte)
	_creer_domestiques()
	_h_prec = float(cycle.get("heure"))
	actualiser()

func _process(dt: float) -> void:
	_t += dt
	if _t < PAS:
		return
	var h := float(cycle.get("heure"))
	temps += fposmod(h - _h_prec, 24.0) if _h_prec >= 0.0 else 0.0
	_h_prec = h
	_t_spawn += _t
	_t = 0.0
	_tour()

## Un tour complet tout de suite (captures, tests).
func actualiser() -> void:
	_h_prec = float(cycle.get("heure"))
	_t_spawn = 99.0
	_tour()

func _tour() -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var h := float(cycle.get("heure"))
	var p := joueur.global_position
	var sous_terre: bool = monde != null and monde.get("_sous_terre_actif") == true
	_domestiques(h, p)
	_nettoyer(h, p)
	if not sous_terre:
		_peupler(h, p)
	_lod(p, sous_terre)

# ------------------------------------------------------------------ biomes (arbres du monde)

func _construire_grille() -> void:
	_grille.clear()
	for t: Transform3D in monde.arbres:
		var c := Vector2i(floori(t.origin.x / 8.0), floori(t.origin.z / 8.0))
		_grille[c] = int(_grille.get(c, 0)) + 1
	_seuils = [float(fiche.get("seuil_clairiere", 6.0)), float(fiche.get("seuil_foret", 22.0))]

func densite_arbres(x: float, z: float) -> float:
	var c := Vector2i(floori(x / 8.0), floori(z / 8.0))
	var n := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			n += int(_grille.get(c + Vector2i(dx, dz), 0))
	return float(n)

func biome_en(x: float, z: float) -> String:
	var v: Dictionary = fiche["village"]
	var d := Vector2(x - float(v["x"]), z - float(v["z"])).length()
	if d < 40.0:
		return "village"
	var n := densite_arbres(x, z)
	if d < float(v["rayon"]) + 14.0 and n < _seuils[1]:
		return "abords_village"
	if n >= _seuils[1]:
		return "foret"
	if n >= _seuils[0]:
		return "clairiere"
	return "plaine_neige"

# ------------------------------------------------------------------ bêtes sauvages

func en_service(t: Dictionary, h: float) -> bool:
	var a: Dictionary = fiche["apparition"]
	return float(t["u"]) < poids_heure(String(BeteQuat.ESPECES[t["espece"]]["heures"]), h, float(a["hors_plage"]))

func _vivantes(slot: int) -> Array:
	var r := []
	for b in actifs.get(slot, []):
		if is_instance_valid(b) and b.vivant():
			r.append(b)
	return r

func _nb(espece := "") -> int:
	var n := 0
	for slot: int in actifs:
		for b in _vivantes(slot):
			if espece == "" or b.espece == espece:
				n += 1
	return n

func _vu(pos: Vector3) -> bool:
	var cam = joueur.get("camera")
	return cam is Camera3D and (cam as Camera3D).is_position_in_frustum(pos)

func _peupler(h: float, p: Vector3) -> void:
	var a: Dictionary = fiche["apparition"]
	if not complet and _t_spawn < float(a["cadence"]):
		return
	var candidats: Array = []
	for t: Dictionary in territoires:
		if actifs.has(int(t["id"])) or not en_service(t, h):
			continue
		if tues.has(int(t["id"])) and temps - float(tues[int(t["id"])]) < float(a["regen_heures"]):
			continue
		var d := Vector2(float(t["x"]) - p.x, float(t["z"]) - p.z).length()
		if d > float(a["dist_max"]) or (not complet and d < float(a["dist_min"])):
			continue
		if not complet:
			var y: float = hauteur_de.call(float(t["x"]), float(t["z"]))
			if _vu(Vector3(float(t["x"]), y + 1.0, float(t["z"]))):
				continue
			var pl: Dictionary = fiche["plafonds"]
			if _nb() + int(t["groupe"]) > int(pl["total"]) or _nb(String(t["espece"])) + int(t["groupe"]) > int(pl.get(t["espece"], 99)):
				continue
		candidats.append(t)
	if candidats.is_empty():
		return
	_t_spawn = 0.0
	if complet:
		for t: Dictionary in candidats:
			_creer_groupe(t)
	else:
		_creer_groupe(candidats[_rng.randi() % candidats.size()])

func _creer_groupe(t: Dictionary) -> void:
	var slot := int(t["id"])
	var n := int(t["groupe"])
	var membres: Array = []
	for k in n:
		var a := TAU * k / maxf(n, 1.0) + float(t["u"]) * TAU
		var r := 0.0 if n == 1 else 2.5
		var x := float(t["x"]) + sin(a) * r
		var z := float(t["z"]) + cos(a) * r
		var ident := "faune_%03d_%d" % [slot, k]
		registre.erase(ident)
		var opts := {"espece": t["espece"], "ident": ident}
		if n > 1 or bool(BeteQuat.ESPECES[t["espece"]].get("meute", false)):
			opts["meute"] = "faune_%03d" % slot
		var b: Node = fabrique.call(String(t["espece"]), Vector3(x, float(hauteur_de.call(x, z)) + 0.05, z), a + PI, opts)
		b.set_meta("faune_territoire", slot)
		b.mort.connect(_a_la_mort.bind(slot, b))
		if complet:
			b.process_mode = Node.PROCESS_MODE_DISABLED
		membres.append(b)
	actifs[slot] = membres

func _a_la_mort(_id: String, slot: int, b: Node) -> void:
	tues[slot] = temps
	registre.erase(b.ident)      # une bête sauvage tuée ne reste pas « morte pour toujours » : le territoire se repeuple (exporter)

func _nettoyer(h: float, p: Vector3) -> void:
	var a: Dictionary = fiche["apparition"]
	for slot: int in actifs.keys():
		var vivantes := _vivantes(slot)
		if vivantes.is_empty():
			actifs.erase(slot)
			continue
		var t: Dictionary = territoires[slot]
		var proche := 1.0e9
		var combat := false
		var vue := false
		for b in vivantes:
			proche = minf(proche, Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length())
			combat = combat or b.en_combat()
			vue = vue or _vu(b.global_position + Vector3.UP)
		if combat:
			continue
		var oubli := proche > float(a["dist_oubli"])
		var heure_passee := not en_service(t, h) and proche > float(a["dist_min"]) * 0.8 and not vue
		if complet:
			oubli = proche > float(a["dist_max"]) + 5.0
			heure_passee = not en_service(t, h)
		if oubli or heure_passee:
			for b in vivantes:
				registre.erase(b.ident)
				b.queue_free()
			actifs.erase(slot)

func _lod(p: Vector3, sous_terre: bool) -> void:
	if complet:
		return
	var dist_gel := float(fiche["apparition"]["dist_gel"])
	var toutes: Array = []
	for slot: int in actifs:
		toutes.append_array(_vivantes(slot))
	for e: Dictionary in domestiques:
		if is_instance_valid(e["bete"]) and e["bete"].vivant():
			toutes.append(e["bete"])
	for b in toutes:
		var d := Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length()
		var geler: bool = sous_terre or d > dist_gel
		if b.get_meta("faune_gele", false) == geler:
			continue
		if geler and b.en_combat():
			continue
		b.process_mode = Node.PROCESS_MODE_DISABLED if geler else Node.PROCESS_MODE_INHERIT
		b.set_meta("faune_gele", geler)

# ------------------------------------------------------------------ domestiques

func _creer_domestiques() -> void:
	var f: Dictionary = fiche["domestiques"]
	for d: Dictionary in f["liste"]:
		var x := float(d["x"])
		var z := float(d["z"])
		var b: Node = fabrique.call(String(d["espece"]), Vector3(x, float(hauteur_de.call(x, z)) + 0.05, z), deg_to_rad(float(d["lacet"])),
			{"espece": d["espece"], "ident": d["ident"], "rayon_errance": float(d["rayon"])})
		if complet:
			b.process_mode = Node.PROCESS_MODE_DISABLED
		domestiques.append({"bete": b, "def": d, "phase": "", "maison": Vector3(x, 0.0, z)})

## Où la bête passe la soirée et la nuit : abri de la fiche s'il en existe un qui l'accueille, sinon sa place contre l'enclos.
func couche_de(d: Dictionary) -> Vector3:
	var e := String(d.get("enclos", ""))
	var place := int(d.get("place", 0))
	for ab: Dictionary in fiche.get("abris", []):
		if String(d["espece"]) in ab.get("accueille", []):
			var pa: Array = ab["pos"]
			return Vector3(float(pa[0]) + 0.7 * (place - 1), 0.0, float(pa[1]))
	if e != "":
		var liste: Array = fiche["domestiques"]["enclos"][e]["couche"]
		var c: Array = liste[place % liste.size()]
		return Vector3(float(c[0]), 0.0, float(c[1]))
	return Vector3(float(d["x"]), 0.0, float(d["z"]))

func _domestiques(h: float, p: Vector3) -> void:
	var f: Dictionary = fiche["domestiques"]
	var phase := phase_domestique(h, f)
	var v: Dictionary = fiche["village"]
	var dv_joueur := Vector2(p.x - float(v["x"]), p.z - float(v["z"])).length()
	for e: Dictionary in domestiques:
		var b = e["bete"]   # non typé : la bête peut avoir été libérée (is_instance_valid juste après)
		if not is_instance_valid(b) or not b.vivant():
			continue
		var d: Dictionary = e["def"]
		if bool(d.get("suiveur", false)):
			_husky(e, b, p, dv_joueur, float(v["rayon"]))
		var maison: Vector3 = e["maison"]
		var couche := couche_de(d)
		if e["phase"] != phase and not b.suit_joueur:
			var avant: String = e["phase"]
			e["phase"] = phase
			var soir := phase in ["soir", "nuit"]
			var cible := couche if soir else maison
			var y := float(hauteur_de.call(cible.x, cible.z)) + 0.05
			if complet or avant == "":
				# pose directe (premier tour ou captures) : la bête est déjà à sa place de l'heure, au repos ou couchée
				b.global_position = Vector3(cible.x, y, cible.z)
				b.velocity = Vector3.ZERO
				b.aller_a(Vector3(cible.x, y, cible.z), 0.6 if soir else float(d["rayon"]))
				b._changer(BeteQuat.REPOS)
				if phase == "nuit":
					b.coucher()
				else:
					b.reveiller()
					b._choisir_repos()
				b.anim.seek(_rng.randf() * 2.0, true)
			elif phase == "aube" or phase == "jour":
				b.reveiller()
				b.aller_a(maison, float(d["rayon"]))
			else:
				b.aller_a(couche, 0.6)
		elif phase == "nuit" and not b.dort and not b.suit_joueur:
			var reste := Vector2(b.global_position.x - couche.x, b.global_position.z - couche.z).length()
			if reste < 1.4 and b.etat == BeteQuat.REPOS:
				b.coucher()

func _husky(e: Dictionary, b: Node, p: Vector3, dv_joueur: float, rayon_village: float) -> void:
	var dist := Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length()
	var dv_bete := Vector2(b.global_position.x - float(fiche["village"]["x"]), b.global_position.z - float(fiche["village"]["z"])).length()
	if not b.suit_joueur:
		if dist < 3.5 and dv_joueur < rayon_village:
			b.suit_joueur = true
	elif dv_joueur > rayon_village or dv_bete > rayon_village or dist > 35.0:
		b.suit_joueur = false     # il rentre à sa place (BeteQuat, état SUIT -> ERRE vers `origine`)
		e["phase"] = "?"     # phase à réévaluer (hors pose directe du premier tour)

# ------------------------------------------------------------------ sauvegarde

func exporter() -> Dictionary:
	var t := {}
	for slot: int in tues:
		t[str(slot)] = snappedf(float(tues[slot]), 0.01)
	return {"temps": snappedf(temps, 0.01), "tues": t}

func importer(d: Dictionary) -> void:
	temps = float(d.get("temps", 0.0))
	tues.clear()
	var t: Dictionary = d.get("tues", {})
	for k in t:
		tues[int(k)] = float(t[k])
