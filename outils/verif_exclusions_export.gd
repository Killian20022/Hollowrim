extends SceneTree
## Vérifie que les filtres d'exclusion de l'export (export_presets.cfg, preset 0) n'écartent rien que le jeu charge.
##   Godot --headless --path <projet> --script res://outils/verif_exclusions_export.gd
## 1. dépendances : chaque ressource exportée (non exclue) est ouverte par ResourceLoader.get_dependencies ; une dépendance
##    exclue = ERREUR (le jeu exporté ne la trouverait pas) ;
## 2. chemins écrits en dur : toute chaîne res://… des .gd / .json / .tscn / .tres exportés qui tombe sur un fichier exclu
##    (ou un préfixe avant un « % » de format, ex. cheveux/%s.gltf) = ERREUR.
## Sortie : « EXCLUSIONS OK (n fichiers exclus) » ou la liste des fautes, code de sortie 1.

## Chemins exclus connus et sans risque : repli de données de démo, lu seulement si le fichier existe (préexistant, outils/*).
const TOLERES := ["res://outils/donnees_test/arbre_demo.json"]

var _excl: PackedStringArray = []
var _incl: PackedStringArray = []
var _fichiers: PackedStringArray = []

func _initialize() -> void:
	_lire_filtres()
	_lister("res://")
	var exclus := {}
	for f in _fichiers:
		if _exclu(f):
			exclus[f] = true
	var fautes: PackedStringArray = []
	var nb_deps := 0
	var re := RegEx.create_from_string("res://[^\"'\\s)\\]]+")
	for f in _fichiers:
		if exclus.has(f):
			continue
		var ext := f.get_extension()
		if FileAccess.file_exists(f + ".import") or ext in ["tscn", "tres", "res", "scn"]:
			for d in ResourceLoader.get_dependencies(f):
				nb_deps += 1
				var p := d.get_slice("::", d.get_slice_count("::") - 1)
				if p.begins_with("uid://"):
					p = ResourceUID.get_id_path(ResourceUID.text_to_id(p)) if ResourceUID.has_id(ResourceUID.text_to_id(p)) else p
				if exclus.has(p):
					fautes.append("dépendance exclue : %s -> %s" % [f, p])
		if ext in ["gd", "json", "tscn", "tres", "cfg"]:
			var txt := FileAccess.get_file_as_string(f)
			for m: RegExMatch in re.search_all(txt):
				var c := m.get_string()
				if c in TOLERES:
					continue
				if c.contains("%"):
					var motif := RegEx.create_from_string("%[0-9.]*[sdif]").sub(c, "*", true)
					for e in exclus:
						if String(e).matchn(motif):
							fautes.append("chemin formaté vers un fichier exclu : %s : %s (ex. %s)" % [f, c, e])
							break
				elif exclus.has(c) or exclus.has(c.trim_suffix(".import")):
					fautes.append("chemin en dur exclu : %s : %s" % [f, c])
	for d in ResourceLoader.get_dependencies("res://assets/modeles/armures/sol/armure_cuir.glb"):
		print("  exemple sol/armure_cuir.glb -> ", d)
	if fautes.is_empty():
		print("EXCLUSIONS OK (%d fichiers exclus sur %d, %d dépendances vérifiées)" % [exclus.size(), _fichiers.size(), nb_deps])
		quit(0)
	else:
		for x in fautes:
			print("ERREUR ", x)
		print("EXCLUSIONS EN FAUTE : %d" % fautes.size())
		quit(1)

func _lire_filtres() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for p in String(cfg.get_value("preset.0", "exclude_filter", "")).split(",", false):
		_excl.append(p.strip_edges())
	for p in String(cfg.get_value("preset.0", "include_filter", "")).split(",", false):
		_incl.append(p.strip_edges())

## Même règle que l'export de Godot : le filtre est comparé au chemin relatif (sans res://) et au chemin complet.
func _exclu(f: String) -> bool:
	var rel := f.trim_prefix("res://")
	for p in _excl:
		if rel.matchn(p) or f.matchn(p):
			return true
	return false

func _lister(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	if FileAccess.file_exists(dossier.path_join(".gdignore")):
		return
	for sd in d.get_directories():
		if sd.begins_with("."):
			continue
		_lister(dossier.path_join(sd))
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		_fichiers.append(dossier.path_join(f))
