extends SceneTree
## Captures EN JEU des factions jouables (fenêtre, via godot_slot.sh : hors écran) : fiche « Factions » du menu du personnage,
## dialogue de Haldor (chef de la Garde) : promotion REFUSÉE (ce qui manque) puis ACCEPTÉE.
##   godot --path . --script res://outils/capture_rangs.gd -- --nouvelle --paisible --res=640x360 --sortie=<dossier absolu>
var monde: Node

func _init() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame

func _photo(sortie: String, nom: String) -> void:
	await _attendre(0.5)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if String(p.donnees.get("id", "")) == id:
			return p
	return null

## Parle au chef et montre chaque réplique de la réponse, une image par réplique (machine à écrire terminée).
func _repliques(sortie: String, prefixe: String, choix: String, garde: Node3D, lignes_a_montrer: Array) -> void:
	var d: Control = monde.dialogue
	d.engager(garde)
	await _attendre(0.3)
	for k in 60:
		if d._choix_vis or not d._ouvert:
			break
		d._texte.visible_characters = d._texte.text.length()
		d._t = 99.0
		await process_frame
		if d._choix_vis or not d._ouvert:
			break
		d._suite()
		await process_frame
	d._t = 99.0
	d._texte.visible_characters = d._texte.text.length()
	var textes: Array = d._options.map(func(o: Dictionary) -> String: return String(o["texte"]))
	d._choisir(textes.find(choix) if textes.has(choix) else 0)
	await _attendre(0.2)
	await _photo(sortie, prefixe + "_choix")
	d._valider_choix()
	await _attendre(0.4)
	for i in d._lignes.size():
		d._index = i
		d._afficher_ligne()
		d._texte.visible_characters = d._texte.text.length()
		d._t = 99.0
		if i in lignes_a_montrer:
			await _photo(sortie, "%s_%d" % [prefixe, i + 1])
	d._fermer()

func _lancer() -> void:
	await _attendre(7.0)
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/rangs"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var j: CharacterBody3D = monde.joueur
	var rg: Rangs = monde.rangs
	j.mains.visible = false
	monde.cycle.heure = 12.0
	monde.cycle._process(0.0)
	j.vie_max = 100000.0
	j.vie = 100000.0
	# état de départ : Garde (Veilleur, 28), Cercle (non membre, 12), Chasseurs (Rabatteur, 14)
	rg.adherer("garde_jarl")
	rg.ajouter_reputation("garde_jarl", 28.0)
	rg.ajouter_reputation("cercle_sigrun", 12.0)
	rg.adherer("chasseurs")
	rg.ajouter_reputation("chasseurs", 14.0)
	j.progression.competences.niveaux["epee"] = 19
	monde.inventaire_ui.ouvrir("factions")
	await _photo(sortie, "fiche_factions")
	monde.inventaire_ui.fermer()
	await _attendre(0.5)
	# dialogue : refus puis acceptation
	var garde := _pnj("garde")
	garde.set_physics_process(false)
	var dir := Vector3(sin(garde.global_rotation.y), 0, cos(garde.global_rotation.y))
	j.global_position = garde.global_position + dir * 1.8 + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(dir.x, dir.z)
	j.tete.rotation.x = atan2(garde.global_position.y + 1.6 - j.tete.global_position.y, 1.8)
	await _attendre(1.0)
	rg._rep["garde_jarl"] = 6.0   # réputation ET compétence insuffisantes : le refus dit les deux
	await _repliques(sortie, "refus", "Demander une promotion", garde, [0, 1, 2])
	# la Garde a accepté Veilleur il y a < 7 jours : on laisse passer le temps, on s'entraîne
	Marchand.avancer(24.0 * 8.0)
	rg.ajouter_reputation("garde_jarl", 30.0)
	j.progression.competences.niveaux["epee"] = 31
	j.progression.competences.niveaux["parade"] = 31
	j.inventaire.ajouter("potion_soin", 0)
	await _attendre(0.5)
	await _repliques(sortie, "accepte", "Demander une promotion", garde, [0, 1])
	monde.inventaire_ui.ouvrir("factions")
	await _photo(sortie, "fiche_factions_apres")
	quit(0)
