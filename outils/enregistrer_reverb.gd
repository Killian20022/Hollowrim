extends SceneTree
## Preuve sonore de la reverb « Sous-terre » : joue le même pas de pierre et un coup de cloche sur le bus Effets dans chaque salle
## (dehors, maison, crypte, grotte) et enregistre la sortie du Master en WAV.
##   godot --headless --path . --script res://outils/enregistrer_reverb.gd -- <dossier de sortie>
func _init() -> void:
	_faire.call_deferred()

func _faire() -> void:
	var sortie := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	Mixage.creer()
	var rec := AudioEffectRecord.new()
	rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, rec)
	for salle: String in ["dehors", "maison", "crypte", "grotte"]:
		Mixage.zone_vers(salle, 0.0)
		print(salle, " : actif=", Mixage.reverb_active(), " wet=", Mixage.reverb().wet, " room=", Mixage.reverb().room_size)
		rec.set_recording_active(true)
		for nom: String in ["pas_pierre_00", "pas_pierre_02", "ui_quete_debut"]:
			var a := AudioStreamPlayer.new()
			a.stream = Sons.flux(nom)
			a.bus = Mixage.EFFETS
			root.add_child(a)
			a.play()
			await create_timer(1.3 if nom != "ui_quete_debut" else 2.6).timeout
		rec.set_recording_active(false)
		var w := rec.get_recording()
		print(salle, " : ", w.data.size(), " octets, ", w.get_length() if w.has_method("get_length") else -1, " s")
		w.save_to_wav(sortie.path_join("reverb_%s.wav" % salle))
		await create_timer(0.3).timeout
	quit(0)
