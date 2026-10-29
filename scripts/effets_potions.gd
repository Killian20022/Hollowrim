class_name EffetsPotions
extends RefCounted
## Effets en cours des potions et de la nourriture (Consommables) : chaque stat rendue (vie, mana, vigueur) est versée
## progressivement sur `duree` secondes, plus un délai de réutilisation par famille (soin, mana, endurance, nourriture)
## contre le spam. Tenu par le joueur (`joueur.potions`), avancé dans Joueur._physics_process (donc figé en pause), vidé à la mort.
## Non sauvegardé (une partie rechargée repart sans effet ni délai). Affichage : `statuts()` est ajouté à
## `Joueur.statuts_actifs`, la rangée d'icônes + trait de durée du HudCombat les montre sans toucher au HUD.

const STATS := ["vie", "mana", "vigueur"]
const STATUTS := {"vie": "pot_vie", "mana": "pot_mana", "vigueur": "pot_vigueur"}
## Délai (s) avant de reboire la même famille.
const DELAIS := {"soin": 3.0, "mana": 3.0, "endurance": 3.0, "nourriture": 2.0}

## [{"stat", "reste" (points à verser), "taux" (points/s), "duree", "duree_max"}]
var actifs: Array[Dictionary] = []
## famille → secondes restantes
var delais := {}

func demarrer(id: String) -> void:
	var e := Consommables.effets(id)
	var duree := maxf(0.5, float(e.get("duree", 4.0)))
	for k: String in STATS:
		if e.has(k):
			actifs.append({"stat": k, "reste": float(e[k]), "taux": float(e[k]) / duree, "duree": duree, "duree_max": duree})
	var f := famille(id)
	delais[f] = float(DELAIS.get(f, 3.0))

static func famille(id: String) -> String:
	return String(Consommables.effets(id).get("famille", "soin"))

## Secondes avant de pouvoir reboire cette famille (0 = possible).
func delai(id: String) -> float:
	return float(delais.get(famille(id), 0.0))

## Points de `stat` encore à venir (pour ne pas boire une potion qui n'apporterait rien).
func en_attente(stat: String) -> float:
	var t := 0.0
	for a in actifs:
		if a["stat"] == stat:
			t += float(a["reste"])
	return t

func vider() -> void:
	actifs.clear()
	delais.clear()

func avancer(joueur: Node, dt: float) -> void:
	for f: String in delais.keys():
		delais[f] = float(delais[f]) - dt
		if float(delais[f]) <= 0.0:
			delais.erase(f)
	if actifs.is_empty():
		return
	if joueur.get("mort"):
		vider()
		return
	for i in range(actifs.size() - 1, -1, -1):
		var a: Dictionary = actifs[i]
		var pas := minf(float(a["reste"]), float(a["taux"]) * dt)
		a["duree"] = float(a["duree"]) - dt
		if float(a["duree"]) <= 0.0:
			pas = float(a["reste"])
		a["reste"] = float(a["reste"]) - pas
		match String(a["stat"]):
			"vie":
				joueur.soigner(pas)
			"mana":
				joueur.mana = minf(float(joueur.mana_max), float(joueur.mana) + pas)
			"vigueur":
				joueur.vigueur = minf(float(joueur.vigueur_max), float(joueur.vigueur) + pas)
		if float(a["duree"]) <= 0.0 or float(a["reste"]) <= 0.001:
			actifs.remove_at(i)

## Au format de Joueur.statuts_actifs : [{"nom", "duree", "duree_max"}].
func statuts() -> Array:
	var r: Array = []
	for a in actifs:
		r.append({"nom": STATUTS[a["stat"]], "duree": maxf(0.0, float(a["duree"])), "duree_max": float(a["duree_max"])})
	return r
