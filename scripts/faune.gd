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
## Coop (lot 4d, docs/reseau_lot4d.md) : l'hôte détient la faune (apparitions, IA, mort) ; l'invité la voit en marionnettes.
const EV_SPAWN := "faune_spawn"
const EV_RETIRE := "faune_retire"
const EV_MORT := "faune_mort"
const PERTINENCE := 120.0

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
var _marion := false                 # invité : marionnettes, aucune logique d'apparition
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
	_reseau_installer()
	actualiser()

func _process(dt: float) -> void:
	if _marion:
		return
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
	if _marion or joueur == null or not is_instance_valid(joueur):
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
	var descs: Array = []
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
		var pos := Vector3(x, float(hauteur_de.call(x, z)) + 0.05, z)
		var b: Node = fabrique.call(String(t["espece"]), pos, a + PI, opts)
		b.set_meta("faune_territoire", slot)
		b.mort.connect(_a_la_mort.bind(slot, b))
		if complet:
			b.process_mode = Node.PROCESS_MODE_DISABLED
		membres.append(b)
		descs.append({"ident": ident, "espece": String(t["espece"]), "pos": pos, "lacet": a + PI, "opts": opts.duplicate()})
		_suivre_bete(b)
	actifs[slot] = membres
	_diffuser("spawn", {"slot": slot, "membres": descs})

func _a_la_mort(_id: String, slot: int, b: Node) -> void:
	_annoncer_mort(b)
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
			var idents: Array = []
			for b in vivantes:
				idents.append(String(b.ident))
				registre.erase(b.ident)
				b.queue_free()
			actifs.erase(slot)
			_diffuser("retire", {"slot": slot, "idents": idents})

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
		b.mort.connect(func(_id: String) -> void: _annoncer_mort(b))
		_suivre_bete(b)
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

# ------------------------------------------------------------------ coop (lot 4d) : marionnettes, apparitions, morts

func _reseau_installer() -> void:
	ReseauCorps.assurer()
	var r := ReseauCorps.R()
	if r == null:
		return
	add_to_group("faune_gestion")
	r.abonner(EV_SPAWN, _sur_spawn)
	r.abonner(EV_RETIRE, _sur_retire)
	r.abonner(EV_MORT, _sur_mort_bete)
	var rj := get_node_or_null("/root/Rejoindre")
	if rj != null:
		rj.call("contributeur", "faune", Callable(self, "exporter_reseau"), Callable(self, "importer_reseau"))
	if ReseauCorps.est_invite():
		basculer_reseau(true)

func _exit_tree() -> void:
	var r := ReseauCorps.R()
	if r != null:
		r.desabonner(EV_SPAWN, _sur_spawn)
		r.desabonner(EV_RETIRE, _sur_retire)
		r.desabonner(EV_MORT, _sur_mort_bete)

## Appelé par ReseauCorps quand le rôle change : invité = toutes les bêtes deviennent des marionnettes (les bêtes sauvages locales sont
## retirées : celles de l'hôte arrivent par « faune_spawn » et l'instantané « faune »), hôte / solo = l'IA reprend.
func basculer_reseau(invite: bool) -> void:
	if invite == _marion:
		return
	_marion = invite
	if invite:
		for slot: int in actifs.keys():
			for b in actifs[slot]:
				if is_instance_valid(b):
					registre.erase(b.ident)
					b.queue_free()
		actifs.clear()
	for e: Dictionary in domestiques:
		var b = e["bete"]
		if is_instance_valid(b):
			_marionnette(b, invite)

func _marionnette(b: Node, oui: bool) -> void:
	b.set_physics_process(not oui or b.est_mort)     # un cadavre garde son minuteur (libération après 30 s)
	b.set_process(not oui)
	if oui and b.process_mode == Node.PROCESS_MODE_DISABLED:
		b.process_mode = Node.PROCESS_MODE_INHERIT
		b.set_meta("faune_gele", false)
	if oui:
		b.velocity = Vector3.ZERO

func _diffuser(quoi: String, d: Dictionary) -> void:
	if not ReseauCorps.en_ligne() or not ReseauCorps.est_hote():
		return
	var rep := ReseauCorps._rep()
	if rep != null:
		rep.call("diffuser", "faune_" + quoi, int(d.get("slot", 0)), d, 0, false)

## Enregistre la bête auprès du réplicateur : l'hôte envoie pos / cap / clip, l'invité les applique (identifiant « b:<ident> »).
func _suivre_bete(b: Node) -> void:
	var rep := ReseauCorps._rep()
	if rep == null or String(b.ident) == "":
		return
	rep.call("enregistrer", "b:" + String(b.ident), b, Callable(self, "_etat_bete").bind(b), Callable(self, "_appliquer_bete").bind(b), PERTINENCE)
	if _marion:
		_marionnette(b, true)

func _etat_bete(b: Variant) -> Dictionary:
	if not is_instance_valid(b):
		return {}
	return {"pos": (b as Node3D).global_position, "a_lacet": (b as Node3D).rotation.y, "anim": String(b.anim.current_animation),
		"vit": float(b.anim.speed_scale), "mort": bool(b.est_mort)}

func _appliquer_bete(et: Dictionary, b: Variant) -> void:
	if not is_instance_valid(b) or bool(b.est_mort) or not et.has("pos"):
		return
	(b as Node3D).global_position = et["pos"]
	(b as Node3D).rotation.y = float(et["a_lacet"])
	b.velocity = Vector3.ZERO
	var clip := String(et["anim"])
	if clip != "" and b.anim.current_animation != clip and b.anim.has_animation(clip):
		b.anim.play(clip, 0.2)
	b.anim.speed_scale = float(et["vit"])

func _sur_spawn(exp: int, _id: Variant, d: Variant) -> void:
	if exp == 1 and _marion and d is Dictionary:
		_creer_groupe_distant(d)

func _creer_groupe_distant(g: Dictionary) -> void:
	var slot := int(g["slot"])
	if actifs.has(slot) or not fabrique.is_valid():
		return
	var membres: Array = []
	for m: Dictionary in g["membres"]:
		var ident := String(m["ident"])
		registre.erase(ident)
		var b: Node = fabrique.call(String(m["espece"]), m["pos"], float(m["lacet"]), (m["opts"] as Dictionary).duplicate())
		b.set_meta("faune_territoire", slot)
		b.mort.connect(_a_la_mort.bind(slot, b))
		membres.append(b)
		_suivre_bete(b)
	actifs[slot] = membres

func _sur_retire(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or not _marion or not (d is Dictionary):
		return
	var slot := int((d as Dictionary)["slot"])
	for b in actifs.get(slot, []):
		if is_instance_valid(b) and not b.est_mort:
			registre.erase(b.ident)
			b.queue_free()
	actifs.erase(slot)

## Hôte : une bête vient de mourir -> les invités rejouent sa mort (clip Death / MortAraignee) et obtiennent le même butin.
func _annoncer_mort(b: Node) -> void:
	if not ReseauCorps.en_ligne() or not ReseauCorps.est_hote() or String(b.ident) == "":
		return
	var pos := (b as Node3D).global_position
	var dir := Vector3.ZERO
	if joueur != null and is_instance_valid(joueur):
		dir = pos - joueur.global_position
		dir.y = 0.0
		dir = dir.normalized()
	var ident := String(b.ident)
	get_tree().create_timer(0.1).timeout.connect(func() -> void:     # le butin (bourse) est posé en fin de _mourir
		var contenu := {}
		var a_butin := false
		if is_instance_valid(b) and is_instance_valid(b.get("_butin")):
			contenu = (b.get("_butin").get("contenu") as Dictionary).duplicate()
			a_butin = true
		var rep := ReseauCorps._rep()
		if rep != null:
			rep.call("diffuser", EV_MORT, ident, {"pos": pos, "dir": dir, "contenu": contenu, "a_butin": a_butin}, 0, false))

func _sur_mort_bete(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or not _marion or not (d is Dictionary):
		return
	var b := ReseauCorps.trouver(String(id))
	if b == null or bool(b.est_mort):
		return
	var dd: Dictionary = d
	ReseauCorps.contenus[String(id)] = dd["contenu"] if bool(dd.get("a_butin", false)) else {"pieces": 0}
	(b as Node3D).global_position = dd["pos"]
	b.call("_mourir", (dd["pos"] as Vector3) - (dd["dir"] as Vector3), 20.0, false, {}, "legere")
	b.set_physics_process(true)

## Instantané pour un invité qui arrive en cours de partie : groupes sauvages actifs (les domestiques existent déjà des deux côtés).
func exporter_reseau() -> Dictionary:
	var gs: Array = []
	for slot: int in actifs:
		var ms: Array = []
		for b in _vivantes(slot):
			var opts := {"espece": b.espece, "ident": b.ident}
			if String(b.meute) != "":
				opts["meute"] = b.meute
			ms.append({"ident": String(b.ident), "espece": String(b.espece), "pos": b.global_position, "lacet": b.rotation.y, "opts": opts})
		if not ms.is_empty():
			gs.append({"slot": slot, "membres": ms})
	return {"groupes": gs}

func importer_reseau(d: Dictionary) -> void:
	if not _marion:
		return
	for g: Dictionary in d.get("groupes", []):
		_creer_groupe_distant(g)
