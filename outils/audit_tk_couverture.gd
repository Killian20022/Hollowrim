extends SceneTree
## INVENTAIRE de la couverture télékinésie / casse (2026-11-23, étendu le 2026-11-24 « tk partout ») : quels props du monde sont saisissables,
## lesquels sont encore FONDUS dans le décor, par LIEU (village, abords, camp de départ, intérieurs, crypte / grottes).
##   godot --headless --path . --script res://outils/audit_tk_couverture.gd -- --nouvelle --audit-poses [--sortie=<fichier.txt>]
## Règle de classement : ObjetsVivants.mobile (UNE seule fonction, utilisée par tous les chemins de pose). Un prop fondu et « mobile » est
## un manque (objectif : 0) ; un prop fondu et fixe est un choix (liste FIXES d'ObjetsVivants : gros, structurel, luminaire…).
## Sort aussi les saisissables INCASSABLES (hors métal / pierre solide) : objectif 0.

const SCENE := preload("res://scenes/foret_test.tscn")
## src d'un fondu (PropsQuaternius.fondu) -> lieu
const LIEU_SRC := {"village": "village", "mv_sub": "village", "mv_q": "village", "lot_pq": "abords", "lot_pq_q": "abords", "camp_depart": "camp de départ",
	"int_q": "intérieurs", "int_xf": "intérieurs"}
## Matières qu'on accepte sans casse (métal massif)
const SOLIDES := ["fer"]

func _init() -> void:
	_run.call_deferred()

static func lieu_ident(ident: String) -> String:
	var l := ident.get_slice(":", 0)
	if l == "camp":
		return "camp de départ"
	if l.begins_with("lot_"):
		return "abords"
	if l == "village" or l.begins_with("pv_") or l.begins_with("marche_") or l.begins_with("etal_"):
		return "village"
	if l in ["halle", "sigrun", "chasseurs", "grima", "forge"]:
		return "intérieurs"
	return "crypte / grottes"

func _run() -> void:
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	for i in 60:
		await physics_frame
	var sortie: Array[String] = []
	var lieux := ["village", "abords", "camp de départ", "intérieurs", "crypte / grottes"]
	var sais := {}
	var genre_n := {}
	var total := 0
	var incassables := {}
	var nb_vivants := 0
	var nb_cassables := 0
	for n in get_nodes_in_group("telekinesable"):
		var ident := String(n.get("ident")) if n.get("ident") != null else "-"
		var l := lieu_ident(ident)
		sais[l] = int(sais.get(l, 0)) + 1
		var g := String(n.get("genre")) if n.get("genre") != null else n.get_class()
		genre_n[g] = int(genre_n.get(g, 0)) + 1
		total += 1
		if n is ObjetVivant:
			nb_vivants += 1
			var o := n as ObjetVivant
			if o.seuil_casse == INF and not (o.matiere in SOLIDES):
				var k := "%s [%s]" % [o.genre, o.matiere]
				incassables[k] = int(incassables.get(k, 0)) + 1
		elif n is Cassable:
			nb_cassables += 1
			var c := n as Cassable
			if c.genre == "objet" and CasseObjets.seuil(c.matiere_objet) == INF and not (c.matiere_objet in SOLIDES):
				var k2 := "objet [%s]" % c.matiere_objet
				incassables[k2] = int(incassables.get(k2, 0)) + 1
	var fondus := PropsQuaternius.audit
	var f_mobiles := {}      # lieu -> n
	var f_fixes := {}
	var liste_mobiles := {}  # "nom <src>" -> n
	for k: String in fondus:
		var nom := k.get_slice(" <", 0)
		var src := k.get_slice(" <", 1).trim_suffix(">")
		var l: String = LIEU_SRC.get(src, "crypte / grottes")
		var n_k := int(fondus[k])
		if ObjetsVivants.mobile(nom, true):
			f_mobiles[l] = int(f_mobiles.get(l, 0)) + n_k
			liste_mobiles[k] = n_k
		else:
			f_fixes[l] = int(f_fixes.get(l, 0)) + n_k
	sortie.append("AUDIT TELEKINESIE (règle ObjetsVivants.mobile ; tk_partout=%s, regle_unique=%s)" % [str(ObjetsVivants.tk_partout), str(ObjetsVivants.regle_unique)])
	sortie.append("SAISISSABLES total=%d (ObjetVivant %d, Cassable %d)" % [total, nb_vivants, nb_cassables])
	sortie.append("%-18s %12s %18s %14s" % ["lieu", "saisissables", "fondus MOBILES", "fondus fixes"])
	var tm := 0
	var tf := 0
	for l: String in lieux:
		sortie.append("%-18s %12d %18d %14d" % [l, int(sais.get(l, 0)), int(f_mobiles.get(l, 0)), int(f_fixes.get(l, 0))])
		tm += int(f_mobiles.get(l, 0))
		tf += int(f_fixes.get(l, 0))
	sortie.append("%-18s %12d %18d %14d" % ["TOTAL", total, tm, tf])
	sortie.append("COUVERTURE props mobiles : %.1f %% (%d saisissables / %d fondus mobiles)" % [100.0 * total / float(maxi(total + tm, 1)), total, tm])
	sortie.append("FONDUS MOBILES (à traiter, objectif 0) :")
	var cles := liste_mobiles.keys()
	cles.sort_custom(func(a, b): return liste_mobiles[a] > liste_mobiles[b])
	for c in cles:
		sortie.append("  %-38s %5d" % [c, liste_mobiles[c]])
	sortie.append("FONDUS FIXES (choix) :")
	var fx := {}
	for k: String in fondus:
		if not ObjetsVivants.mobile(k.get_slice(" <", 0), true):
			fx[k] = int(fondus[k])
	var ck := fx.keys()
	ck.sort_custom(func(a, b): return fx[a] > fx[b])
	for c in ck:
		sortie.append("  %-38s %5d" % [c, fx[c]])
	sortie.append("SAISISSABLES INCASSABLES (hors métal solide, objectif 0) : %s" % str(incassables))
	sortie.append("par genre : %s" % str(genre_n))
	for l in sortie:
		print(l)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			var f := FileAccess.open(a.substr(9), FileAccess.WRITE)
			f.store_string("\n".join(sortie) + "\n")
			f.close()
	quit()
