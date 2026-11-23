extends SceneTree
## INVENTAIRE de la couverture télékinésie (2026-11-23) : quels props du monde sont saisissables, lesquels non.
##   godot --headless --path . --script res://outils/audit_tk_couverture.gd -- --nouvelle --audit-poses
## Affiche : objets du groupe `telekinesable` par lieu et genre ; poses de décor FONDUES (non physiques) par prop ; part saisissable.

const FIXES := ["table", "etal", "lit", "etabli", "etagere", "porte", "banniere", "bougie", "bougeoir", "torche", "lanterne", "corde", "chaine", "planches",
	"poutre", "brique", "bordure", "roc", "souche", "tronc", "chariot", "charrette", "tente", "rack", "enclume", "billot", "mannequin", "lutrin", "chevalet",
	"cloche", "buffet", "bibliotheque", "commode", "support", "puits", "abri", "cage", "pieux", "trappe", "barreaux", "tapis", "grille", "pilier",
	"colonne", "piedestal", "bq", "cheminee", "cadre", "garde", "auvent", "aisselier", "poteau", "escalier", "barriere", "feu"]
const FIXES_EXACT := ["coffre_or", "coffre_or_2", "coffre_d", "coffre_bombe", "coffre_lingots", "coffre", "coffre_2", "coffre_tiroirs", "tas_sacs", "pierre_aiguiser", "urne_brisee"]
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_run.call_deferred()

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
	var par_genre := {}
	var par_lieu := {}
	var total := 0
	for n in get_nodes_in_group("telekinesable"):
		var g := String(n.get("genre")) if n.get("genre") != null else n.get_class()
		var l := String(n.get("ident")).get_slice(":", 0) if n.get("ident") != null else "-"
		par_genre[g] = int(par_genre.get(g, 0)) + 1
		par_lieu[l] = int(par_lieu.get(l, 0)) + 1
		total += 1
	print("SAISISSABLES total=%d" % total)
	print("  par lieu : ", par_lieu)
	print("  par genre : ", par_genre)
	var fondus := PropsQuaternius.audit
	var cles := fondus.keys()
	cles.sort_custom(func(a, b): return fondus[a] > fondus[b])
	var nf := 0
	for c in cles:
		nf += int(fondus[c])
	print("FONDUS (non saisissables) total=%d, %d ids" % [nf, cles.size()])
	for c in cles:
		print("  %-28s %5d  %s" % [c, fondus[c], PropsQuaternius.boite(c).size])
	var ok := 0
	for k: String in fondus:
		var id := k.get_slice(" <", 0)
		var base := id.trim_prefix("pq_").trim_prefix("q_")
		if id.begins_with("bq_") or base in FIXES_EXACT or (base.get_slice("_", 0) in FIXES and base != "etabli_tiroirs") or PropsQuaternius.boite(id).size.length() > 1.6:
			continue
		ok += int(fondus[k])
	print("COUVERTURE props légers : %d saisissables / %d fondus légers = %.1f %%" % [total, ok, 100.0 * total / float(total + ok)])
	quit()
