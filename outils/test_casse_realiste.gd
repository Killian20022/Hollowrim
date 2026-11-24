extends SceneTree
## CASSE RÉALISTE (2026-11-24) : chaque famille d'objet casse à sa manière (scripts/casse_objets.gd, MATIERES « decoupe ») :
##   bûche / rondin / tronc : fendus en 2 moitiés (3 au plus) de taille crédible ; chaise, tabouret, banc, cageot : 3 à 6 pièces ;
##   tonneau : ≥ 8 morceaux ; manche (pelle), chope : cassés en 2 ; sac : déchiré en 2 ; pomme : 2 ; citrouille : 3 ; livres : incassables ;
##   fer : incassable ; seuils : une bûche lancée doucement ne casse pas.
##   godot --headless --path . --script res://outils/test_casse_realiste.gd -- --nouvelle

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

## Morceaux du prop `nom` découpés pour `matiere` : [{c, t, part}] (découpe de données, comme en jeu dans le fil de fond).
func _decouper(nom: String, matiere: String) -> Array:
	var src := ObjetsVivants.morceaux_q(nom, func(_m: String) -> Material: return StandardMaterial3D.new())
	if src.is_empty():
		return []
	return CasseObjets._decouper_donnees(src, matiere)

func _parts(d: Array) -> String:
	var s := []
	for m: Dictionary in d:
		s.append("%.2f" % float(m["part"]))
	return ", ".join(s)

func _tester() -> void:
	await process_frame
	var cas := [
		# [prop, matière, min, max, libellé]
		["q_buche", "buche", 2, 3], ["q_rondin", "rondin", 2, 3], ["q_tronc", "tronc", 2, 2],
		["q_chaise", "meuble_leger", 3, 6], ["q_tabouret", "meuble_leger", 3, 6], ["q_banc", "meuble", 3, 6], ["q_cageot_vide", "cageot", 3, 6],
		["q_tonneau", "tonneau", 8, 12], ["q_jarre", "poterie", 4, 8],
		["q_pelle", "bois_outil", 2, 2], ["q_chope", "bois_fin", 2, 2], ["q_pomme", "nourriture", 2, 2], ["q_citrouille", "citrouille", 3, 3],
		["q_sac", "tissu", 2, 2], ["q_bouclier_bois", "bouclier", 2, 3],
	]
	for c: Array in cas:
		var d := _decouper(String(c[0]), String(c[1]))
		if d.is_empty():
			print("INFO   %s : modèle absent (ignoré)" % c[0])
			continue
		print("INFO   %s (%s) : %d morceaux, parts [%s]" % [c[0], c[1], d.size(), _parts(d)])
		_verif(d.size() >= int(c[2]) and d.size() <= int(c[3]), "%s (%s) : %d morceaux (attendu %d à %d)" % [c[0], c[1], d.size(), int(c[2]), int(c[3])])
		if String(c[1]) in ["buche", "rondin", "tronc"]:
			var p0 := float(d[0]["part"])
			_verif(absf(p0 - 0.5) < 0.1 and (d[0]["t"] as Vector3).length() > 0.03, "%s : moitiés de taille crédible (part %.2f)" % [c[0], p0])
		for m: Dictionary in d:
			_verif((m["t"] as Vector3).length() > 0.02, "%s : aucun morceau minuscule" % c[0])
			break
	# seuils : bûche lancée doucement rebondit, choc fort ou coup puissant la fend ; papier et fer incassables ; tissu : seuil élevé
	var e_doux := CasseObjets.energie(Vector3(0, 0, -4.0), 4.0)
	_verif(e_doux < CasseObjets.seuil("buche"), "bûche lancée à 4 m/s (%.0f J) : rebondit (seuil %.0f J)" % [e_doux, CasseObjets.seuil("buche")])
	_verif(CasseObjets.energie(Vector3(0, 0, -10.0), 4.0) >= CasseObjets.seuil("buche"), "bûche à 10 m/s (200 J) : se fend")
	_verif(CasseObjets.COUP_PUISSANT >= CasseObjets.seuil("buche"), "coup puissant (%.0f J) : fend une bûche" % CasseObjets.COUP_PUISSANT)
	_verif(CasseObjets.COUP_LEGER < CasseObjets.seuil("buche") and CasseObjets.COUP_PUISSANT < CasseObjets.seuil("tronc"), "coup léger : ne fend pas la bûche ; coup puissant : pas un tronc")
	_verif(not CasseObjets.fragile("papier") and not CasseObjets.fragile("fer"), "papier et fer : incassables")
	_verif(CasseObjets.seuil("tissu") > CasseObjets.seuil("bois_leger") and CasseObjets.seuil("tissu_leger") > CasseObjets.seuil("bois_leger"), "tissu : seuil élevé")
	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
