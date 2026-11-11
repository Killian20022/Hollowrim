extends SceneTree
## Test sans fenêtre du CONTRÔLE DE MODÈLE (outils/controle_modele_lib.gd, docs/CONTROLE_MODELE.md) :
##   godot --headless --path . --script res://outils/test_controle_modele.gd
## 1. modèles validés du jeu (garde Tripo à l'épée, armure de verre v2, armure dorée v10) : CONTROLE OK ;
## 2. sensibilité sur le modèle validé : budget trop bas, os étiré (piste d'échelle), main arrachée (piste de position) : chacun doit être refusé ;
## 3. cas connus mauvais, si leurs fichiers sont présents (dossier voisin « nordique_controle_essais », voir docs) : garde à l'épée v2b
##    (52855e04 : avant-bras en tige, main gauche détachée) refusé ; armure de verre 919c26e5 (éclat de 6 faces près du poignet droit) refusé.
const CM := preload("res://outils/controle_modele_lib.gd")
const ESSAIS := "res://../nordique_controle_essais/"

var _ok := true

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _controle(n: Node3D, o := {}) -> Dictionary:
	root.add_child(n)
	var c = CM.new(n, o)
	var r: Dictionary = c.controler()
	n.queue_free()
	return r

## Contrôle avec une Animation d'essai « Essai » ajoutée aux clips.
func _controle_piste(n: Node3D, piste: Callable, o := {}) -> Dictionary:
	root.add_child(n)
	var c = CM.new(n, o)
	c.collecter()
	var a := Animation.new()
	a.length = 1.0
	piste.call(a)
	c.anims["Essai"] = a
	c.poser_neutre()
	var pos0: PackedVector3Array = c.sommets_poses()
	c.calculer_groupes()
	var b: Dictionary = c.controle_bras(["Essai"], 2)
	n.queue_free()
	return b

func _tester() -> void:
	# 1. modèles validés
	for spec: String in ["garde:tripo_garde_epee", "garde:tripo_garde_verre", "dore"]:
		var n := CM.charger(spec)
		_verif(n != null, "%s : modèle chargé" % spec)
		if n == null:
			continue
		var r := _controle(n)
		_verif(r["ok"], "%s : CONTROLE OK (%s)" % [spec, "; ".join(r["echecs"])])
		_verif(r["tris"]["total"] > 1000, "%s : %d triangles comptés" % [spec, r["tris"]["total"]])
	# 2. sensibilité (armure de verre validée)
	var r := _controle(CM.charger("garde:tripo_garde_verre"), {"budget_tris": 5000})
	_verif(not r["ok"] and r["echecs"].any(func(e): return String(e).begins_with("triangles")), "budget de 5 000 triangles : refusé (%d)" % r["tris"]["total"])
	var b := _controle_piste(CM.charger("garde:tripo_garde_verre"), func(a: Animation):
		var t := a.add_track(Animation.TYPE_SCALE_3D)
		a.track_set_path(t, NodePath("Skeleton3D:lowerarm_r"))
		a.scale_track_insert_key(t, 0.0, Vector3(1.0, 1.35, 1.0)))
	_verif(not b["r"]["ok"] and float(b["r"]["etirement_os_max"]) > 0.15, "avant-bras étiré de 35 %% : refusé (os %.0f %%, géométrie %.0f %%)" % [float(b["r"]["etirement_os_max"]) * 100, float(b["r"]["etirement_geo_max"]) * 100])
	_verif(b["l"]["ok"], "le bras gauche, intact, reste accepté")
	b = _controle_piste(CM.charger("garde:tripo_garde_verre"), func(a: Animation):
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:hand_l"))
		a.position_track_insert_key(t, 0.0, Vector3(0, 0.45, 0)))      # main reculée à 45 cm du coude (os de repos : 24 cm) : arrachée de ~20 cm
	_verif(not b["l"]["ok"], "main arrachée de ~20 cm : refusée (%s)" % "; ".join(b["l"]["echecs"]).left(200))
	# 3. cas connus mauvais (fichiers optionnels)
	var dossier := ProjectSettings.globalize_path("res://").path_join("../nordique_controle_essais/").simplify_path()
	var f1 := dossier.path_join("epee_v2b.glb")
	if FileAccess.file_exists(f1):
		var rr := _controle(CM.charger(f1))
		_verif(not rr["ok"] and rr["echecs"].any(func(e): return String(e).contains("sans géométrie")), "garde à l'épée v2b (52855e04) : refusée, main gauche détachée (%s)" % "; ".join(rr["echecs"]).left(160))
	else:
		print("SAUTE  garde à l'épée v2b : fichier absent (", f1, ")")
	var f2 := dossier.path_join("verre_919c.glb")
	if FileAccess.file_exists(f2):
		var rr := _controle(CM.charger(f2))
		_verif(not rr["ok"] and rr["echecs"].any(func(e): return String(e).begins_with("éclat flottant : 6 faces")), "armure de verre 919c26e5 : refusée, éclat de 6 faces près du poignet droit (%s)" % "; ".join(rr["echecs"]).left(160))
	else:
		print("SAUTE  armure de verre 919c : fichier absent (", f2, ")")
	print("TEST CONTROLE MODELE : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
