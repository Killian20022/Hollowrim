extends SceneTree
## Cout CPU des ressorts : temps de traitement par image (Performance.TIME_PROCESS) de 12 volvas qui marchent (robe + cape longue + capuche :
## 4 chaines chacune, 7 collisions), simulation active puis inactive, 400 images chacune, 3 alternances.
##   godot --path . --script res://outils/mesure_ressorts.gd -- --nouvelle
func _init() -> void:
	_lancer.call_deferred()

func _mesurer(actif: bool, n: int) -> float:
	var scene := Node3D.new()
	root.add_child(scene)
	var skels: Array[Skeleton3D] = []
	for i in n:
		var m := Personnage.creer(PersoDefs.villageois("volva"))
		scene.add_child(m)
		m.position = Vector3((i % 6) * 1.2 - 3.0, 0, (i / 6) * 1.5)
		var ap := m.get_node("Animations") as AnimationPlayer
		ap.play("Walk")
		var sq := m.find_child("Skeleton3D", true, false) as Skeleton3D
		(m.get_node("PersoRessorts") as PersoRessorts).simulateur.active = actif
		(m.get_node("PersoRessorts") as PersoRessorts).set_process(false)
		skels.append(sq)
	for i in 40:
		await process_frame
	var somme := 0.0
	for i in 400:
		await process_frame
		somme += Performance.get_monitor(Performance.TIME_PROCESS)
	var ms := somme / 400.0 * 1000.0
	scene.queue_free()
	await process_frame
	return ms

func _lancer() -> void:
	var avec := 0.0
	var sans := 0.0
	for k in 3:
		sans += await _mesurer(false, 12)
		avec += await _mesurer(true, 12)
	print("MESURE RESSORTS : 12 volvas, temps de process par image : avec ressorts %.3f ms, sans %.3f ms -> %.3f ms par PNJ (moyenne de 3 x 400 images)" % [avec / 3.0, sans / 3.0, (avec - sans) / 3.0 / 12.0])
	quit(0)
