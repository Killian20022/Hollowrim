extends SceneTree
## Captures EN JEU des factions vivantes (fenêtre, via godot_slot.sh : hors écran) :
##   - le MÊME PNJ à deux rangs (Ylva : Rabatteur puis Maître de la chasse ; Haldor : Veilleur puis Champion du jarl) ;
##   - le journal d'une quête de faction terminée (« La peau du troll », entrées datées) ;
##   - la fiche Factions avant puis après un crime vu (agression + vol, puis meurtre : exclusion).
##   godot --path . --script res://outils/captures_factions_vivantes.gd -- --nouvelle --paisible --res=1280x720 --sortie=<dossier absolu>
var monde: Node

func _init() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	monde.set_meta("test", true)
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

func _etat(d: Dictionary) -> void:
	var rep := {}
	var rang := {}
	var der := {}
	for f: String in d:
		rep[f] = float(d[f][0])
		rang[f] = int(d[f][1])
		der[f] = 0.0
	monde.rangs.restaurer({"rep": rep, "rang": rang, "dernier": der})

## Place le joueur devant le PNJ, lui parle, laisse la machine à écrire finir la 1re réplique et photographie.
func _parler(sortie: String, id: String, nom: String) -> void:
	var j: CharacterBody3D = monde.joueur
	var v := _pnj(id)
	v.set_physics_process(false)
	v.deja_parle = true
	var dir := Vector3(sin(v.global_rotation.y), 0, cos(v.global_rotation.y))
	j.global_position = v.global_position + dir * 1.8 + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(dir.x, dir.z)
	j.tete.rotation.x = atan2(v.global_position.y + 1.6 - j.tete.global_position.y, 1.8)
	await _attendre(0.8)
	var d: Control = monde.dialogue
	d.engager(v)
	await _attendre(0.5)
	d._texte.visible_characters = d._texte.text.length()
	d._t = 99.0
	print("DIALOGUE ", id, " : ", d._lignes[0] if d._lignes.size() > 0 else "-")
	await _photo(sortie, nom)
	d._fermer()
	await _attendre(0.4)

func _lancer() -> void:
	await _attendre(7.0)
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/factions_vivantes"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var j: CharacterBody3D = monde.joueur
	var rg: Rangs = monde.rangs
	var q: Node = monde.quetes
	var cr: Crime = Crime.trouver(monde)
	j.mains.visible = false
	monde.cycle.heure = 12.0
	monde.cycle._process(0.0)
	j.vie_max = 100000.0
	j.vie = 100000.0
	# 1. le même PNJ à deux rangs
	_etat({"chasseurs": [5.0, 0]})
	await _parler(sortie, "chasseuse", "ylva_rang0")
	_etat({"chasseurs": [60.0, 3]})
	await _parler(sortie, "chasseuse", "ylva_rang3")
	_etat({"garde_jarl": [5.0, 0]})
	await _parler(sortie, "garde", "haldor_rang0")
	_etat({"garde_jarl": [80.0, 4]})
	await _parler(sortie, "garde", "haldor_rang4")
	# 2. une quête de faction jouée jusqu'au bout, journal daté
	q.importer({})
	_etat({"chasseurs": [40.0, 2]})
	monde.cycle.jour = 4
	monde.cycle.heure = 9.0
	q.repliques("chasseuse", _pnj("chasseuse"))               # Ylva propose la quête
	monde.cycle.jour = 5
	monde.cycle.heure = 16.5
	q.signaler("tue:troll_lac")
	j.inventaire.ajouter("fourrure_troll", 1)
	monde.cycle.jour = 6
	monde.cycle.heure = 10.0
	q.repliques("chasseuse", _pnj("chasseuse"))               # elle la reçoit : récompense
	monde.cycle._process(0.0)
	monde.inventaire_ui.ouvrir("quetes")
	var ong = monde.inventaire_ui.onglet("quetes")
	ong.choix = "peau_troll"
	ong.queue_redraw()
	await _photo(sortie, "journal_peau_troll")
	monde.inventaire_ui.fermer()
	await _attendre(0.4)
	# 3. la fiche Factions avant / après un crime vu
	_etat({"garde_jarl": [28.0, 2], "chasseurs": [14.0, 0]})
	cr.perdue_factions.clear()
	monde.inventaire_ui.ouvrir("factions")
	await _photo(sortie, "factions_avant")
	monde.inventaire_ui.fermer()
	await _attendre(0.3)
	cr._commettre("agression", 40.0, [])
	cr._commettre("vol", 5.0, [])
	monde.inventaire_ui.ouvrir("factions")
	await _photo(sortie, "factions_apres_agression_vol")
	monde.inventaire_ui.fermer()
	await _attendre(0.3)
	cr._commettre("meurtre", 1000.0, [])
	monde.inventaire_ui.ouvrir("factions")
	await _photo(sortie, "factions_apres_meurtre")
	quit(0)
