extends SceneTree
## Mesure du coût de création des PNJ du village (PnjNordique.creer) : godot --headless -s res://outils/mesure_pnj.gd
## [-- --detail] (détail par étape des archétypes). Les PNJ créés restent vivants (comme en jeu : les glb restent en cache).
var _vivants: Array = []
func _initialize() -> void:
	_lancer.call_deferred()
func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0
func _lancer() -> void:
	var detail := OS.get_cmdline_user_args().has("--detail")
	GuerrierNordique.chrono = detail
	ChasseresseNordique.chrono = detail
	MageNordique.chrono = detail
	var t0 := Time.get_ticks_usec()
	for c: String in Humain.CORPS.values():
		t0 = Time.get_ticks_usec()
		var ps: PackedScene = load(c)
		print("PNJ load %-50s %7.1f ms" % [c.get_file(), _ms(t0)])
		_vivants.append(ps)
		for k in 2:
			t0 = Time.get_ticks_usec()
			var n: Node = ps.instantiate()
			print("PNJ instantiate %-43s %7.1f ms" % [c.get_file(), _ms(t0)])
			_vivants.append(n)
	t0 = Time.get_ticks_usec()
	Humain.bibliotheque()
	print("PNJ bibliotheque %7.1f ms" % _ms(t0))
	var t_tot := Time.get_ticks_usec()
	for passe in 2:
		for id: String in ["chef", "forgeron", "chasseuse", "volva", "ancienne", "garde", "garde_lance"]:
			t0 = Time.get_ticks_usec()
			var n := PnjNordique.creer(id)
			print("PNJ passe %d %-12s %7.1f ms" % [passe + 1, id, _ms(t0)])
			_vivants.append(n)
	print("PNJ total %7.1f ms" % _ms(t_tot))
	for n in _vivants:
		if n is Node:
			n.free()
	quit()
