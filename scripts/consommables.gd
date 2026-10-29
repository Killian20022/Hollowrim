class_name Consommables
extends RefCounted
## Potions et nourriture (catégorie « consommable » de data/butin/objets.json) : empilées dans le sac, utilisées depuis
## l'inventaire (I, catégorie Potions) ou par un raccourci 1-0 (entrée {"conso": id} de EquipementMains.raccourcis).
## Effets branchés sur les vraies stats du joueur : vie (joueur.soigner), mana (joueur.mana / mana_max), vigueur
## (joueur.vigueur / vigueur_max), apprendre (sort ajouté à EquipementMains.sorts_connus). Vie / mana / vigueur sont versées
## PROGRESSIVEMENT (EffetsPotions, `joueur.potions` : durée et famille dans `effets`) ; le sort appris est immédiat.
## Une potion qui ne servirait à rien (stat déjà pleine, sort déjà connu) est refusée et reste dans le sac.

const NOMS_EFFETS := {"vie": "vie", "mana": "mana", "vigueur": "endurance"}

static func est(id: String) -> bool:
	return Inventaire.categorie_de(id) == "consommable"

static func effets(id: String) -> Dictionary:
	return Inventaire.objet(id).get("effets", {})

## Texte d'une ligne pour la fiche : « Rend 40 de vie, 20 d'endurance. » / « Apprend le sort Boule de feu. »
static func description(id: String) -> String:
	var e := effets(id)
	var parts: Array[String] = []
	for k in ["vie", "mana", "vigueur"]:
		if e.has(k):
			parts.append("%d %s" % [int(e[k]), ("d’" if k == "vigueur" else "de ") + String(NOMS_EFFETS[k])])
	var t := ""
	if not parts.is_empty():
		t = "Rend " + ", ".join(parts) + ((" en %d s." % int(e["duree"])) if e.has("duree") else ".")
	if e.has("apprendre"):
		var s: Resource = load(EquipementMains.DOSSIER_SORTS % String(e["apprendre"])) if ResourceLoader.exists(EquipementMains.DOSSIER_SORTS % String(e["apprendre"])) else null
		t += ("" if t == "" else " ") + "Apprend le sort %s." % (String(s.get("nom")) if s != null else String(e["apprendre"]))
	return t

static func _famille_txt(f: String) -> String:
	return {"soin": "une autre potion de soin", "mana": "une autre potion de mana", "endurance": "une autre potion d’endurance", "nourriture": "reprendre de la nourriture"}.get(f, "recommencer")

static func _eq(joueur: Node) -> EquipementMains:
	var m: Variant = joueur.get("mains")
	if m == null or not is_instance_valid(m):
		return null
	var mg: Variant = m.get("magie")
	return mg.eq if mg != null else null

## Raison pour laquelle on ne peut pas l'utiliser maintenant ("" = possible).
static func refus(joueur: Node, id: String) -> String:
	if joueur == null:
		return "Personne pour l'utiliser."
	if not est(id):
		return "Cet objet ne s'utilise pas."
	var inv: Inventaire = joueur.inventaire
	if not inv.a(id):
		return "Vous n'en avez plus."
	if joueur.get("mort"):
		return "Trop tard."
	var e := effets(id)
	var pot: EffetsPotions = joueur.get("potions")
	if pot != null and e.has("famille") and pot.delai(id) > 0.0:
		return "Trop tôt pour %s (%d s)." % [_famille_txt(EffetsPotions.famille(id)), ceili(pot.delai(id))]
	if e.has("apprendre"):
		var eq := _eq(joueur)
		if eq == null:
			return "Impossible d'apprendre un sort ici."
		if eq.sorts_connus.has(String(e["apprendre"])):
			return "Vous connaissez déjà ce sort."
		return ""
	var utile := false
	var att := func(k: String) -> float: return pot.en_attente(k) if pot != null else 0.0
	if e.has("vie") and float(joueur.vie) + att.call("vie") < float(joueur.vie_max) - 0.01:
		utile = true
	if e.has("mana") and float(joueur.mana) + att.call("mana") < float(joueur.mana_max) - 0.01:
		utile = true
	if e.has("vigueur") and float(joueur.vigueur) + att.call("vigueur") < float(joueur.vigueur_max) - 0.01:
		utile = true
	if not utile:
		var noms: Array[String] = []
		for k in ["vie", "mana", "vigueur"]:
			if e.has(k):
				noms.append(String(NOMS_EFFETS[k]))
		return "Déjà au maximum (%s)." % ", ".join(noms)
	return ""

## Utilise un exemplaire : effets appliqués, retiré du sac. Renvoie "" ou la raison du refus.
static func utiliser(joueur: Node, id: String) -> String:
	var r := refus(joueur, id)
	if r != "":
		return r
	var e := effets(id)
	if joueur.get("potions") != null:
		(joueur.potions as EffetsPotions).demarrer(id)
	if e.has("apprendre"):
		var eq := _eq(joueur)
		eq.sorts_connus.append(String(e["apprendre"]))
		eq.sorts_connus.sort()
	(joueur.inventaire as Inventaire).retirer(id)
	Sons.jouer(joueur, ["cloth1", "cloth2"], -10.0)
	return ""
