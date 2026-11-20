extends SceneTree
## Opti cpu_scripts (2026-11-20) : coût unitaire (µs par appel) de petites fonctions appelées par image par des dizaines de nœuds.
##   godot --headless --path . --script res://outils/banc_micro_cpu.gd
const N := 200000

func _init() -> void:
	_go.call_deferred()

func _mesurer(nom: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for i in N:
		f.call()
	var t := float(Time.get_ticks_usec() - t0) / N
	var t1 := Time.get_ticks_usec()
	var vide := func() -> void: pass
	for i in N:
		vide.call()
	var tv := float(Time.get_ticks_usec() - t1) / N
	print("MICRO %-48s %.3f µs/appel (appel vide déduit : %.3f)" % [nom, t - tv, tv])

func _go() -> void:
	if root.get_node_or_null("Reseau") == null:      # en --script, les autoloads ne sont pas créés : un Reseau hors ligne à la main
		var r: Node = load("res://scripts/reseau/reseau.gd").new()
		r.name = "Reseau"
		root.add_child(r)
	for k in 5:
		await process_frame
	_mesurer("ReseauMondeVivant.en_ligne()", func() -> void: ReseauMondeVivant.en_ligne())
	_mesurer("ReseauMondeVivant._r()", func() -> void: ReseauMondeVivant._r())
	_mesurer("PauseCoop.R()", func() -> void: PauseCoop.R())
	_mesurer("CombatCoop.R()", func() -> void: CombatCoop.R())
	var rn: Node = root.get_node("Reseau")
	_mesurer("rn.est_en_ligne() (nœud gardé)", func() -> void: rn.est_en_ligne())
	var np := NodePath("Reseau")
	_mesurer("root.get_node_or_null(NodePath const)", func() -> void: root.get_node_or_null(np))
	var d := {"a": 1, "interpellations": [1, 2]}
	_mesurer("dict.get(cle, [])", func() -> void: d.get("interpellations", []))
	var nd := Node3D.new()
	root.add_child(nd)
	_mesurer("Node3D.global_position", func() -> void: nd.global_position)
	_mesurer("is_instance_valid(nd)", func() -> void: is_instance_valid(nd))
	_mesurer("get_tree().get_nodes_in_group(vide)", func() -> void: get_nodes_in_group("ennemis"))
	var v := Vector3(1, 2, 3)
	_mesurer("ReseauMondeVivant.joueur_proche(v, null)", func() -> void: ReseauMondeVivant.joueur_proche(v, null))
	_mesurer("ReseauMondeVivant.distance_joueurs", func() -> void: ReseauMondeVivant.distance_joueurs(v, Vector3.ZERO))
	_mesurer("root.get_node_or_null(\"Reseau\")", func() -> void: root.get_node_or_null("Reseau"))
	quit(0)
