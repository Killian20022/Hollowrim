extends SceneTree
## Coût des chargements « à la volée » sur le fil principal (opti saccades 2026-11-20) : 1er load() (cache froid, dans ce processus) puis
## instanciation, fichier par fichier, pour les ressources que le jeu charge PENDANT la partie (musiques au changement de situation, bruitages
## au 1er son, modèles d'armes et d'armures à l'équipement).
##   godot --path . --script res://outils/mesure_chargements_vol.gd -- [--famille=musique,sons,armes,armures] [--seuil=1.0]
## Fenêtre conseillée (création réelle des maillages sur le GPU) ; --headless sous-estime les modèles.
## Sortie : « VOL <famille> <ms load> <ms inst> <chemin> » au-dessus du seuil, puis « VOL_BILAN <famille> n=.. total=.. pire=.. ».

func _init() -> void:
	_go.call_deferred()

func _arg(n: String, d := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d

func _fichiers(dossier: String, exts: Array, rec := true) -> Array:
	var r: Array = []
	var d := DirAccess.open(dossier)
	if d == null:
		return r
	for f in d.get_files():
		var f2 := f.trim_suffix(".remap").trim_suffix(".import")
		if f2.get_extension() in exts and not r.has(dossier.path_join(f2)):
			r.append(dossier.path_join(f2))
	if rec:
		for s in d.get_directories():
			r.append_array(_fichiers(dossier.path_join(s), exts, rec))
	return r

func _go() -> void:
	await process_frame
	var familles := _arg("famille", "musique,sons,armes,armures").split(",")
	var seuil := float(_arg("seuil", "1.0"))
	for fam in familles:
		var l: Array = []
		match fam:
			"musique": l = _fichiers("res://assets/musique", ["ogg"])
			"sons": l = _fichiers("res://assets/sons", ["wav", "ogg"], false)
			"armes":
				for t in _fichiers("res://data/armes", ["tres"]):
					var d: Resource = load(t)
					if d != null and d.get("modele") != null and String(d.get("modele")) != "":
						l.append(String(d.get("modele")))
			"armures": l = _fichiers("res://assets/modeles/armures/porte", ["glb"])
		var tot := 0.0
		var pire := 0.0
		var n := 0
		for c: String in l:
			if not ResourceLoader.exists(c) or ResourceLoader.has_cached(c):
				continue
			var t0 := Time.get_ticks_usec()
			var r: Resource = load(c)
			var t1 := Time.get_ticks_usec()
			var ti := 0.0
			if r is PackedScene:
				var inst := (r as PackedScene).instantiate()
				ti = (Time.get_ticks_usec() - t1) / 1000.0
				inst.free()
			var tl := (t1 - t0) / 1000.0
			tot += tl + ti
			pire = maxf(pire, tl + ti)
			n += 1
			if tl + ti >= seuil:
				print("VOL %-8s %7.2f %7.2f %s" % [fam, tl, ti, c])
			await process_frame
		print("VOL_BILAN %-8s n=%d total=%.1f ms pire=%.1f ms" % [fam, n, tot, pire])
	quit(0)
