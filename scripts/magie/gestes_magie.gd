class_name GestesMagie
extends RefCounted
## GESTES DES BRAS qui lancent un sort, joués depuis des captures Mixamo retargetées (data/magie/gestes_mixamo.json, écrit
## par sources_blender/scripts/gestes_magie.py ; méthode et choix des clips : docs/MAGIE.md, « Gestes Mixamo »).
## Une instance par MainSort ; `pose()` rend, pour une main, la pose du geste en cours au format de PosesIncantation
## (pos, paume, doigts, fermeture) + « coude » (pôle de l'IK) + « suivi » (raideur du ressort de main_sort), ou {} quand
## aucun geste ne joue : les poses fixes de PosesIncantation reprennent (repos, soin / protection, enchantement…).
##   incantation -> phase « entree » (u = t / sort.incantation) ; charge -> « tenue » (u = charge) ; canalisation ->
##   « boucle » (maintien bras tendu, aller-retour) ; après le lancer -> « depart », après un jet -> « fin » : ces deux
##   phases continuent pendant la récupération ET au repos jusqu'à leur dernière clé (= pose de repos), sans saut.

const FICHIER := "res://data/magie/gestes_mixamo.json"
## Raideur du ressort de la main (1/s) pendant un geste capturé (main_sort.gd : 16 pour les poses fixes).
const SUIVI := 34.0

## false : gestes coupés (anciennes poses fixes ; planches avant / après d'outils/captures_gestes_magie.gd).
static var actif := true
static var _donnees := {}

## Par main : geste en cours, phase, temps dans la phase (depart / fin).
var _etat := {"gauche": {"geste": "", "phase": "", "t": 0.0}, "droite": {"geste": "", "phase": "", "t": 0.0}}

static func donnees() -> Dictionary:
	if _donnees.is_empty() and FileAccess.file_exists(FICHIER):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		if d is Dictionary:
			_donnees = d.get("gestes", {})
	return _donnees

## Geste joué par un sort ("" = poses fixes : soin, protection, enchantement de la lame).
static func geste_de(s: DonneesSort, double: bool) -> String:
	if s == null or s.profil in ["soi", "lame"] or s.type == DonneesSort.Type.ENCHANT:
		return ""
	match s.type:
		DonneesSort.Type.CANALISE:
			return "double_jet" if double else "jet"
		DonneesSort.Type.ZONE:
			return "zone"
		DonneesSort.Type.CHARGE:
			return "double_charge" if double else "charge"
	return "double" if double else "lance"

## Pose du geste pour la main `m` (Incantation i, sort s), après `dt` ; {} = pas de geste.
func pose(m: String, i: Incantation, s: DonneesSort, dt: float) -> Dictionary:
	var e: Dictionary = _etat[m]
	if not actif or donnees().is_empty():
		e["phase"] = ""
		return {}
	match i.etat:
		Incantation.INCANTE, Incantation.CHARGE, Incantation.CANALISE:
			var g := geste_de(s, i.double)
			if g == "" or not donnees().has(g):
				e["phase"] = ""
				return {}
			e["geste"] = g
			if i.etat == Incantation.INCANTE:
				e["phase"] = "entree"
				return _echantillon(g, m, "entree", clampf(i.t / maxf(s.incantation, 0.01), 0.0, 1.0))
			if i.etat == Incantation.CHARGE:
				e["phase"] = "tenue"
				return _echantillon(g, m, "tenue", i.charge)
			e["phase"] = "boucle"
			return _boucle(g, m, maxf(i.t, 0.0))
		_:
			# après le lancer / la fin du jet : le geste finit sa course (jusqu'à la pose de repos), même au repos
			if i.interrompue:
				e["phase"] = ""
				return {}
			match String(e["phase"]):
				"entree", "tenue":
					e["phase"] = "depart" if _a(e["geste"], m, "depart") else "fin"
					e["t"] = 0.0
				"boucle":
					e["phase"] = "fin" if _a(e["geste"], m, "fin") else "depart"
					e["t"] = 0.0
				"depart", "fin":
					e["t"] = float(e["t"]) + dt
				_:
					return {}
			var g2 := String(e["geste"])
			var ph := String(e["phase"])
			var duree := float(donnees()[g2].get(ph + "_duree", 0.0))
			if float(e["t"]) >= duree or not _a(g2, m, ph):
				e["phase"] = ""
				return {}
			return _echantillon(g2, m, ph, float(e["t"]) / maxf(duree, 0.001))

## Vrai si la main joue encore un geste (lancer / fin de jet compris).
func en_cours(m: String) -> bool:
	return String(_etat[m]["phase"]) != ""

func oublier(m: String) -> void:
	_etat[m]["phase"] = ""

func _a(g: String, m: String, ph: String) -> bool:
	var d: Dictionary = donnees().get(g, {})
	return d.has(m) and (d[m] as Dictionary).has(ph)

## Pose interpolée de la phase `ph` à u ∈ [0, 1].
func _echantillon(g: String, m: String, ph: String, u: float) -> Dictionary:
	if not _a(g, m, ph):
		return {}
	var poses: Array = donnees()[g][m][ph]
	var x := clampf(u, 0.0, 1.0) * (poses.size() - 1)
	var i0 := int(floor(x))
	var i1 := mini(i0 + 1, poses.size() - 1)
	return _melange(poses[i0], poses[i1], x - i0)

## Maintien du jet : la boucle de la capture en aller-retour (pas de couture).
func _boucle(g: String, m: String, t: float) -> Dictionary:
	if not _a(g, m, "boucle"):
		return {}
	var duree := maxf(float(donnees()[g].get("boucle_duree", 1.0)), 0.1)
	var u := fmod(t, 2.0 * duree) / duree
	return _echantillon(g, m, "boucle", u if u <= 1.0 else 2.0 - u)

static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

static func _melange(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"pos": _v(a["pos"]).lerp(_v(b["pos"]), k), "paume": _v(a["paume"]).lerp(_v(b["paume"]), k).normalized(),
		"doigts": _v(a["doigts"]).lerp(_v(b["doigts"]), k).normalized(), "fermeture": lerpf(a["fermeture"], b["fermeture"], k),
		"coude": _v(a["coude"]).lerp(_v(b["coude"]), k), "suivi": SUIVI}
