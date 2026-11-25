extends SceneTree
## [pnj/realisme_v1] Précalcule les images repeintes par RealismePnj (visages, étoffes usées, mèches, yeux) dans assets/pnj/realisme/ :
## au lancement du jeu elles sont relues (version + empreinte de l'image source) au lieu d'être repeintes (~1 s par PNJ en GDScript).
## À relancer après toute modif de realisme_pnj.gd / visage_pnj.gd (RealismePnj.VERSION++) ou des textures des archétypes :
##   godot --headless --path . --script res://outils/generer_realisme_pnj.gd
func _initialize() -> void:
	_l.call_deferred()

func _l() -> void:
	CachePersos.actif = false
	RealismePnj.enregistrer = true
	var t0 := Time.get_ticks_msec()
	for id: String in RealismePnj.PROFILS:
		if id.begins_with("bandit"):
			continue
		PnjNordique._creer(id).free()
	# bandits (EnnemisNordiques._def_corps) : casque / bouclier n'influent pas sur les étoffes, une variante de chaque suffit
	for c in [false, true]:
		var n := GuerrierNordique.creer({"casque": c, "bouclier": "", "epee": false})
		RealismePnj.appliquer(n, "bandit")
		n.free()
	for h in [true, false]:
		var a := ChasseresseNordique.creer({"corps": "homme"} if h else {})
		RealismePnj.appliquer(a, "bandit_archer_h" if h else "bandit_archere")
		a.free()
	# gardes maison : visages
	var gd := GardesVillage.donnees()
	for g in gd.get("gardes", []):
		if g is Dictionary:
			GardeMaison.creer(g).free()
	if gd.has("haldor"):
		GardeMaison.creer(gd["haldor"]).free()
	var nb := DirAccess.get_files_at(ProjectSettings.globalize_path(RealismePnj.DOSSIER)).size()
	print("REALISME_PNJ précalculé : %d fichiers en %.1f s" % [nb, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
