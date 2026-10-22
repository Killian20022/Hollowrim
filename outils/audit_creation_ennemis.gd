extends SceneTree
## Coût de création des ennemis (thread principal) : 1re création, créations suivantes (même variante), et duplication d'un modèle déjà bâti.
##   godot --headless --path . --script res://outils/audit_creation_ennemis.gd -- --nouvelle
func _init() -> void:
	_go.call_deferred()

func _t(nom: String, f: Callable) -> Node:
	var t0 := Time.get_ticks_usec()
	var n = f.call()
	print("CREATION %-34s %7.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])
	return n

func _go() -> void:
	var app := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color.WHITE}}
	for i in 3:
		var h: Node3D = _t("Humain.creer seul (base du draugr) #%d" % i, func(): return Humain.creer({"corps": "homme", "barbe": false, "cheveux": "Hair_Long", "tenue": {"tunique": Color.WHITE, "pantalon": Color.WHITE}}))
		root.add_child(h)
	for i in 2:
		var d0: Node3D = _t("DraugrNordique.creer({}) #%d" % i, func(): return DraugrNordique.creer({}))
		root.add_child(d0)
	for i in 4:
		var id := "cr_test_%d" % i
		var n: Node3D = _t("DraugrNordique via Ennemis (sbire) #%d" % i, func(): return EnnemisNordiques.creer({"type": "sbire", "ident": id, "apparence": app}))
		root.add_child(n)
	for i in 3:
		var n: Node3D = _t("Ennemis (guerrier) #%d" % i, func(): return EnnemisNordiques.creer({"type": "guerrier", "ident": "cr_g_%d" % i, "apparence": app}))
		root.add_child(n)
	var modele: Node3D = EnnemisNordiques.creer({"type": "guerrier", "ident": "cr_g_0", "apparence": app})
	for i in 3:
		var d: Node = _t("duplicate() du modele #%d" % i, func(): return modele.duplicate())
		root.add_child(d)
	_t("SqueletteGuerrier.creer", func(): return SqueletteGuerrier.creer({"arme": "epee"}))
	_t("Personnage bandit (perso)", func(): return null)
	quit(0)
