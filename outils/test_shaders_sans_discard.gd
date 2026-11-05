extends SceneTree
## Test sans fenêtre : généralisation de test_terrain_sans_discard à TOUS les shaders (shaders/*.gdshader[inc], outils/*.gdshader).
## Un `discard` désactive le test de profondeur précoce sur tout ce que le shader dessine (terrain : ×1,9 de GPU dehors, 2026-11-05).
## Règles :
##  1. ps1.gdshader (sol, bâti, arbres : surfaces plein écran) : aucun discard hors #ifdef RELIEF_COUCHE.
##  2. aucun shader ne GAGNE de discard : le nombre par fichier est comparé à la liste versionnée outils/banc_perf_reference.json
##     (clé « discards » : effets, découpes d'alpha, magie… autorisés AU NIVEAU actuel). Un nouveau discard demande de relire ce test
##     et de régénérer la liste (--maj), c'est-à-dire de décider en connaissance de cause.
##   godot --headless --path . --script res://outils/test_shaders_sans_discard.gd [-- --maj]
const REF := "res://outils/banc_perf_reference.json"
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

func _fichiers(dossier: String, sortie: Array) -> void:
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(".gdshader") or f.ends_with(".gdshaderinc"):
			sortie.append(dossier.path_join(f))
	for d in DirAccess.get_directories_at(dossier):
		if not d.begins_with("."):
			_fichiers(dossier.path_join(d), sortie)

## Pour chaque `discard;` hors commentaire : la pile des #ifdef/#ifndef qui l'entourent.
func _discards(code: String) -> Array:
	var piles: Array = []
	var trouves: Array = []
	for ligne in code.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("#ifdef ") or l.begins_with("#ifndef ") or l.begins_with("#if "):
			piles.append(l)
		elif l.begins_with("#endif") and not piles.is_empty():
			piles.pop_back()
		if l.split("//")[0].contains("discard;"):
			trouves.append(piles.duplicate())
	return trouves

func _lancer() -> void:
	var fichiers: Array = []
	_fichiers("res://shaders", fichiers)
	_fichiers("res://outils", fichiers)
	fichiers.sort()
	var compte: Dictionary = {}
	for f: String in fichiers:
		var d := _discards(FileAccess.get_file_as_string(f))
		if not d.is_empty():
			compte[f.trim_prefix("res://")] = d.size()
	# 1. shader commun
	var piles := _discards(FileAccess.get_file_as_string("res://shaders/ps1.gdshader"))
	var propre := true
	for pile: Array in piles:
		if not pile.has("#ifdef RELIEF_COUCHE"):
			propre = false
	verifier(propre, "ps1.gdshader : aucun discard hors #ifdef RELIEF_COUCHE (%d dans la couche de neige)" % piles.size())
	# 2. liste versionnée
	var ref: Dictionary = {}
	if FileAccess.file_exists(REF):
		ref = JSON.parse_string(FileAccess.get_file_as_string(REF))
	if "--maj" in OS.get_cmdline_user_args():
		ref["discards"] = compte
		var fa := FileAccess.open(REF, FileAccess.WRITE)
		fa.store_string(JSON.stringify(ref, "\t", false) + "\n")
		fa.close()
		print("liste des discards mise à jour : %d fichiers" % compte.size())
	var autorises: Dictionary = ref.get("discards", {})
	verifier(not autorises.is_empty(), "liste des discards autorisés présente dans banc_perf_reference.json")
	for f: String in compte:
		var nb: int = autorises.get(f, 0)
		verifier(int(compte[f]) <= nb, "%s : %d discard(s), autorisés %d%s" % [f, compte[f], nb, "" if nb > 0 else " (NOUVEAU fichier avec discard : coût du test de profondeur précoce, voir docs/BANC_PERF.md)"])
	# 3. variantes fabriquées par code (replace "discard;") : le sol/plans ne doivent pas en AJOUTER
	var ajout := FileAccess.get_file_as_string("res://scripts/personnage.gd").contains("//DECOUPE\", \"if (t.a < 0.5) { discard; }\")")
	verifier(ajout, "personnage.gd : seule découpe d'alpha injectée connue (les persos, pas le sol)")
	print("ECHECS : %d" % echecs)
	quit(echecs)
