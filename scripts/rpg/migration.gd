class_name Migration
extends RefCounted
## Migration des sauvegardes (docs/RPG.md §7). Fonctions PURES sur le dictionnaire lu du JSON, appelées par monde.charger()
## AVANT tous les importer(). Une sauvegarde v2 ne se charge pas dans un ancien exe (pas exigé).
## v1 -> v2 :
##   competences {niveaux {epee, parade, athletisme}, experience} -> progression.competences (noms canoniques : epee ->
##   une_main ; les 5 nouvelles à 15) ; niveau du personnage RECALCULÉ comme si les montées avaient eu lieu (+ XP des
##   quêtes déjà terminées), points d'arbre et choix d'attribut À DÉPENSER (rien d'attribué d'office) ;
##   inventaire.objets : alias d'identifiants (Inventaire.ALIAS) ; equipement_corps vide ; stockage vide.
##   Toutes les autres clés sont gardées telles quelles.

const VERSION := 2
const FICHIER_QUETES := "res://data/quetes.json"

## Version d'une sauvegarde (1 si absente : les toutes premières n'en avaient pas).
static func version_de(d: Dictionary) -> int:
	return int(d.get("version", 1))

## Amène `d` à la version courante (copie profonde : l'original n'est pas modifié). Version future : rendue telle quelle,
## avec un avertissement.
static func migrer(d: Dictionary, quetes := {}) -> Dictionary:
	var v := version_de(d)
	var r := d.duplicate(true)
	if v > VERSION:
		push_warning("Sauvegarde de version %d (ce jeu lit jusqu'à %d) : lecture au mieux." % [v, VERSION])
		return r
	if v < 2:
		r = vers_v2(r, quetes)
	return r

static func vers_v2(d: Dictionary, quetes := {}) -> Dictionary:
	var r := d.duplicate(true)
	var c: Dictionary = r.get("competences", {}) if r.get("competences", {}) is Dictionary else {}
	var niv_v1: Dictionary = c.get("niveaux", {})
	var xp_v1: Dictionary = c.get("experience", {})
	var niv := {}
	var xp := {}
	for nom in Progression.COMPETENCES:
		niv[nom] = Competences.DEPART
		xp[nom] = 0.0
	for k in niv_v1:
		var n := Progression.canonique(String(k))
		niv[n] = clampi(int(niv_v1[k]), Competences.DEPART, Competences.MAXIMUM)
	for k in xp_v1:
		xp[Progression.canonique(String(k))] = maxf(0.0, float(xp_v1[k]))
	# XP de niveau : montées de compétences + quêtes terminées
	var total := 0.0
	for nom in niv:
		total += Progression.xp_competence_jusqua(int(niv[nom]))
	total += xp_quetes_terminees(r.get("quetes", {}), quetes)
	var p := Progression.new()   # même règle de niveau que le jeu (Progression.gagner_xp)
	p.gagner_xp(total, false)
	r["progression"] = {
		"niveau": p.niveau, "xp_niveau": p.xp_niveau, "points_perk": p.points_perk, "points_attribut": p.points_attribut,
		"attributs": {"vie": 0, "magie": 0, "vigueur": 0}, "perks": {},
		"competences": {"niveaux": niv, "experience": xp},
	}
	r.erase("competences")
	# sac : alias d'identifiants renommés (aucun à ce jour)
	var inv: Dictionary = r.get("inventaire", {}) if r.get("inventaire", {}) is Dictionary else {}
	var a_renommer := false
	if inv.get("objets", {}) is Dictionary:
		for id in inv.get("objets", {}):
			a_renommer = a_renommer or Inventaire.ALIAS.has(String(id))
	if a_renommer:   # sinon le sac reste octet pour octet celui de la v1
		var o := {}
		for id in inv.get("objets", {}):
			var vrai := Inventaire.alias(String(id))
			o[vrai] = int(o.get(vrai, 0)) + int(inv["objets"][id])
		inv["objets"] = o
		r["inventaire"] = inv
	if not r.has("equipement_corps"):
		r["equipement_corps"] = {}
	if not r.has("stockage"):
		r["stockage"] = {"coffres": {}, "maison_achetee": false}
	r["version"] = 2
	return r

## XP des quêtes terminées d'un état de quêtes sauvegardé ({etat: {id: étapes faites}}). `quetes` = contenu de
## data/quetes.json (lu si vide). XP d'une quête = recompense.xp, sinon Progression.XP_QUETE_DEFAUT.
static func xp_quetes_terminees(etat_quetes: Variant, quetes := {}) -> float:
	if not etat_quetes is Dictionary:
		return 0.0
	if quetes.is_empty():
		var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_QUETES)) if FileAccess.file_exists(FICHIER_QUETES) else null
		quetes = lu if lu is Dictionary else {}
	var etat: Dictionary = etat_quetes.get("etat", {})
	var t := 0.0
	for q: Dictionary in quetes.get("quetes", []):
		var id := String(q.get("id", ""))
		var n: int = q.get("etapes", []).size()
		if n > 0 and int(etat.get(id, 0)) >= n:
			t += float(q.get("recompense", {}).get("xp", Progression.XP_QUETE_DEFAUT))
	return t
