extends SceneTree
## Banc de perf avec SEUILS : lit les journaux de outils/banc_perf.sh (audit_mesure_lieu.gd, N répétitions par lieu x heure), prend la
## MÉDIANE, écrit captures/perf/banc_<date>.json et compare à la référence versionnée outils/banc_perf_reference.json. Sans fenêtre.
##   godot --headless --path . --script res://outils/banc_perf.gd -- --logs=<dossier> [--ecrire-reference] [--sortie=<json>]
## Deux contrôles :
##  - MACHINE-INDÉPENDANT (toujours jugé) : appels de dessin et primitives (stables) : avertissement > tol_geo_avert, ÉCHEC > tol_geo_echec.
##  - GPU (gpu_med, gpu_p95 : dépend de la machine) : avertissement > +10 %, ÉCHEC > +25 %. Si la machine est chargée (un autre Godot actif
##    pendant une mesure) ou si les répétitions divergent de plus de 20 %, le verdict GPU est « NON CONCLUANT » (jamais un faux échec).
## Code de sortie = nombre d'ÉCHECS. Voir docs/BANC_PERF.md.
const REF := "res://outils/banc_perf_reference.json"
const TOL_GPU_AVERT := 0.10
const TOL_GPU_ECHEC := 0.25
const DISPERSION_MAX := 0.20
const TOL_GEO_AVERT := 0.04
const TOL_GEO_ECHEC := 0.08
const TOL_GEO_LIEU := {"combat": [0.15, 0.30], "foret": [0.06, 0.12]}   # [avert, échec] : scènes à contenu variable (ennemis, sorts ; arbres vus)
const LIEUX := ["temoin", "place", "foret", "grotte", "crypte", "combat"]

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _mediane(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return 0.0 if b.is_empty() else float(b[b.size() / 2])

func _champ(ligne: String, nom: String) -> float:
	var r := RegEx.new()
	r.compile(" " + nom + "=([0-9.]+)")
	var m := r.search(ligne)
	return float(m.get_string(1)) if m else -1.0

## {"temoin_nuit": {gpu_med, gpu_p95, appels, prims, dispersion, charge, reps, gpu_reps:[…]}}
func _lire(dossier: String) -> Dictionary:
	var res: Dictionary = {}
	for lieu in LIEUX:
		for h in [["jour", "12"], ["nuit", "21"]]:
			var gm: Array = []
			var g95: Array = []
			var ap: Array = []
			var pr: Array = []
			var charge := 0
			var mesure_ok := 0
			for rep in range(1, 10):
				var base := "%s/%s_%s_%d" % [dossier, lieu, h[1], rep]
				if not FileAccess.file_exists(base + ".log"):
					continue
				if FileAccess.file_exists(base + ".charge"):
					charge = maxi(charge, int(FileAccess.get_file_as_string(base + ".charge").strip_edges()))
				for ligne in FileAccess.get_file_as_string(base + ".log").split("\n"):
					if ligne.begins_with("LIEU %s heure=" % lieu) and ligne.contains("gpu_med="):
						gm.append(_champ(ligne, "gpu_med"))
						g95.append(_champ(ligne, "gpu_p95"))
						ap.append(_champ(ligne, "appels"))
						pr.append(_champ(ligne, "prims"))
						mesure_ok += 1
			var med := _mediane(gm)
			var disp := 0.0
			if gm.size() > 1 and med > 0.0:
				disp = (float(gm.max()) - float(gm.min())) / med
			res["%s_%s" % [lieu, h[0]]] = {
				"gpu_med": snappedf(med, 0.01), "gpu_p95": snappedf(_mediane(g95), 0.01),
				"appels": roundi(_mediane(ap)), "prims": roundi(_mediane(pr)),
				"dispersion_gpu": snappedf(disp, 0.001), "autres_godot_max": charge, "reps_valides": mesure_ok, "gpu_med_reps": gm,
			}
	return res

func _pct(v: float, r: float) -> float:
	return (v - r) / r if r > 0.0 else 0.0

func _lancer() -> void:
	var dossier := _arg("logs")
	if dossier == "":
		print("usage : -- --logs=<dossier de banc_perf.sh> [--ecrire-reference] [--sortie=fichier.json]")
		quit(2)
		return
	var mesures := _lire(dossier)
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REF)) if FileAccess.file_exists(REF) else {}
	var charge_globale := 0
	for k in mesures:
		charge_globale = maxi(charge_globale, int(mesures[k]["autres_godot_max"]))
	var sortie := _arg("sortie", "")
	if sortie == "":
		var d := Time.get_datetime_dict_from_system()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/perf"))
		sortie = ProjectSettings.globalize_path("res://captures/perf/banc_%04d-%02d-%02d_%02d%02d.json" % [d.year, d.month, d.day, d.hour, d.minute])
	var echecs := 0
	var avert := 0
	var inconclus := 0
	var lignes: Array = []
	var verdicts: Dictionary = {}
	var rl: Dictionary = ref.get("lieux", {})
	for k: String in mesures:
		var m: Dictionary = mesures[k]
		var v: Array = []
		if int(m["reps_valides"]) == 0:
			v.append("ÉCHEC mesure absente (le lancement a échoué : voir le journal)")
			echecs += 1
		elif rl.has(k):
			var r: Dictionary = rl[k]
			var lieu := k.split("_")[0]
			var tg: Array = TOL_GEO_LIEU.get(lieu, [TOL_GEO_AVERT, TOL_GEO_ECHEC])
			for champ in ["appels", "prims"]:
				var e := _pct(float(m[champ]), float(r[champ]))
				if absf(e) > float(tg[1]):
					v.append("ÉCHEC %s %+.1f %% (tol. %.0f %%)" % [champ, e * 100.0, float(tg[1]) * 100.0])
					echecs += 1
				elif absf(e) > float(tg[0]):
					v.append("avert. %s %+.1f %%" % [champ, e * 100.0])
					avert += 1
			var charge := int(m["autres_godot_max"]) > 0 or float(m["dispersion_gpu"]) > DISPERSION_MAX
			for champ in ["gpu_med", "gpu_p95"]:
				var e := _pct(float(m[champ]), float(r[champ]))
				if e > TOL_GPU_ECHEC or e > TOL_GPU_AVERT:
					if charge:
						v.append("NON CONCLUANT %s %+.1f %% (machine chargée ou bruitée : %d autre(s) Godot, dispersion %.0f %%)" % [champ, e * 100.0, int(m["autres_godot_max"]), float(m["dispersion_gpu"]) * 100.0])
						inconclus += 1
					elif e > TOL_GPU_ECHEC:
						v.append("ÉCHEC %s %+.1f %% (%.2f -> %.2f ms)" % [champ, e * 100.0, float(r[champ]), float(m[champ])])
						echecs += 1
					else:
						v.append("avert. %s %+.1f %%" % [champ, e * 100.0])
						avert += 1
		else:
			v.append("pas de référence pour ce lieu (--ecrire-reference)")
		verdicts[k] = v
		lignes.append("  %-14s gpu_med %6.2f  p95 %6.2f  appels %4d  prims %7d  disp. %2.0f %%  autres Godot %d  %s" % [
			k, m["gpu_med"], m["gpu_p95"], m["appels"], m["prims"], float(m["dispersion_gpu"]) * 100.0, m["autres_godot_max"], " ; ".join(v) if not v.is_empty() else "ok"])
	print("== Banc de perf (médiane de %s répétitions)" % str(mesures["temoin_nuit"]["reps_valides"]))
	for l in lignes:
		print(l)
	var d2 := {
		"date": Time.get_datetime_string_from_system(), "version_moteur": Engine.get_version_info()["string"],
		"autres_godot_max": charge_globale,
		"machine_chargee": charge_globale > 0,
		"verdict_gpu": "non concluant (machine chargée)" if charge_globale > 0 and inconclus > 0 else "jugé",
		"lieux": mesures, "verdicts": verdicts, "echecs": echecs, "avertissements": avert, "non_concluants": inconclus,
	}
	var fa := FileAccess.open(sortie, FileAccess.WRITE)
	fa.store_string(JSON.stringify(d2, "\t", false) + "\n")
	fa.close()
	print("JSON : ", sortie)
	if _arg("ecrire-reference") != "":
		var nl: Dictionary = {}
		for k in mesures:
			var m: Dictionary = mesures[k]
			nl[k] = {"gpu_med": m["gpu_med"], "gpu_p95": m["gpu_p95"], "appels": m["appels"], "prims": m["prims"]}
		ref["version"] = 1
		ref["date"] = Time.get_datetime_string_from_system()
		ref["moteur"] = Engine.get_version_info()["string"]
		ref["autres_godot_max_pendant_la_mesure"] = charge_globale
		ref["annotation_gpu"] = _arg("annotation", "GPU indicatif : à rétablir au calme (aucun autre Godot actif), voir docs/BANC_PERF.md" if charge_globale > 0 else "GPU mesuré machine calme")
		ref["lieux"] = nl
		var fr := FileAccess.open(REF, FileAccess.WRITE)
		fr.store_string(JSON.stringify(ref, "\t", false) + "\n")
		fr.close()
		print("référence écrite : ", REF)
		echecs = 0
	print("BANC : %d ÉCHEC(S), %d avertissement(s), %d point(s) GPU non concluant(s)" % [echecs, avert, inconclus])
	if echecs > 0:
		print("ECHECS : %d" % echecs)
	quit(echecs)
