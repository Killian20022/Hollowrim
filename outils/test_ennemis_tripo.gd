extends SceneTree
## Test sans fenêtre des ennemis Tripo (scripts/ennemi_tripo.gd) : chaque corps est créé, 65 os, clips de l'IA, budget de triangles, arme en main
## (BoneAttachment hand_r), matériau PS1, échelle ; le gobelin fait ~1,2 m ; EnnemisNordiques et squelette() les renvoient avec --ennemis-tripo.
##   godot --headless --path . --script res://outils/test_ennemis_tripo.gd -- --ennemis-tripo --nouvelle
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01", "Pistol_Aim_Neutral", "Pistol_Shoot"]
var echecs := 0

func ok(c: bool, msg: String) -> void:
	print(("OK     " if c else "ECHEC  ") + msg)
	if not c:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _hauteur(n: Node3D, sq: Skeleton3D) -> float:
	var h := 0.0
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		h = maxf(h, mi.get_aabb().end.y)
	return h * n.scale.y

func _lancer() -> void:
	ok(EnnemiTripo.actif(), "option --ennemis-tripo reconnue")
	var cas := [["draugr", "epee"], ["draugr", "hache"], ["archer", "arc"], ["squelette", "epee"], ["squelette", "hache"], ["gobelin", "epee_courte"]]
	for c: Array in cas:
		var n := EnnemiTripo.creer(c[0], c[1])
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sq != null and sq.get_bone_count() == 65, "%s/%s : 65 os (%d)" % [c[0], c[1], sq.get_bone_count()])
		var ap := n.get_node("Animations") as AnimationPlayer
		var manque: Array = []
		for a: String in ANIMS:
			if not ap.has_animation(a):
				manque.append(a)
		ok(manque.is_empty(), "%s/%s : clips de l'IA présents %s" % [c[0], c[1], manque])
		var t := _tris(n)
		ok(t < 9500, "%s/%s : %d triangles" % [c[0], c[1], t])
		ok(n.has_meta("armes_nordiques"), "%s : arme posée (méta)" % c[0])
		if c[1] != "arc":
			ok(sq.get_node_or_null("Arme") != null, "%s/%s : arme en main (hand_r)" % [c[0], c[1]])
		var h := _hauteur(n, sq)
		print("       hauteur du maillage : %.2f m, échelle méta %s" % [h, n.get_meta("echelle_tripo", 1.0)])
		var ech: float = n.get_meta("echelle_tripo", 1.0)
		ok((h * ech > 1.1 and h * ech < 1.35) if c[0] == "gobelin" else (h > 1.7 and h < 2.0), "%s : taille cohérente (%.2f m)" % [c[0], h * ech])
		ap.play("Walk")
		ap.advance(0.4)
		n.queue_free()
	# intégration : spec EnnemisNordiques (draugr, archer) et squelette
	for sp: Dictionary in [{"type": "guerrier", "ident": "g0", "apparence": {"corps": "homme", "draugr": true, "tenue": {}}}, {"type": "sbire", "archer": true, "ident": "s2", "apparence": {"corps": "homme", "draugr": true, "tenue": {}}}]:
		var n := EnnemisNordiques.creer(sp)
		ok(n != null and n.has_meta("tripo_ennemi") and n.has_meta("draugr_nordique"), "EnnemisNordiques.creer(%s) -> corps Tripo %s" % [sp["ident"], n.get_meta("variante", "")])
		if n:
			n.free()
	var sqn := EnnemisNordiques.squelette({"type": "squelette", "ident": "sq1"})
	ok(sqn.has_meta("tripo_ennemi"), "EnnemisNordiques.squelette -> corps Tripo (%s)" % sqn.get_meta("variante", ""))
	sqn.free()
	print("RESULTAT : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
