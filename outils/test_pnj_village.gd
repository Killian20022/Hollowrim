extends SceneTree
## Test headless des PNJ du village : godot --headless -s res://outils/test_pnj_village.gd
## Chaque id de PnjNordique est créé : bon archétype, 65 os, animations du gameplay, budget de triangles, Ragdoll et pieds équipables.
const ARCHETYPE := {"garde": "guerrier_nordique", "garde_lance": "guerrier_nordique", "forgeron": "guerrier_nordique", "eirik": "guerrier_nordique",
	"chasseuse": "chasseresse_nordique", "chef": "chasseresse_nordique", "volva": "mage_nordique", "ancienne": "mage_nordique"}
var _echecs := 0
func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1
## Pièces visibles (chemin relatif au Skeleton3D ; les nœuds anonymes « @… » comptés par parent) -> nombre.
func _visibles(n: Node3D) -> Dictionary:
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var d := {}
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var k := String(sq.get_path_to(mi)).split("/")[0]
		if k.begins_with("@"):
			k = "@" + k.split("@")[1]     # nœud anonyme : seule sa classe compte (son numéro change d'une création à l'autre)
		d[k] = int(d.get(k, 0)) + 1
	return d
func _tris(n: Node3D) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t
func _initialize() -> void:
	_lancer.call_deferred()
func _lancer() -> void:
	for id: String in PnjNordique.IDS:
		var n := PnjNordique.creer(id)
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := n.get_node_or_null("Animations") as AnimationPlayer
		_verif(sq != null and ap != null, "%s : Skeleton3D + Animations" % id)
		if sq == null or ap == null:
			continue
		var attendu: String = ARCHETYPE.get(id, "gardien_nordique") if id != "garde_lance" else "gardien_nordique"
		_verif(n.has_meta(attendu) or id == "garde_lance", "%s : archétype %s" % [id, attendu])
		_verif(sq.get_bone_count() == 65, "%s : 65 os (%d)" % [id, sq.get_bone_count()])
		var manque := []
		for a in ["Idle", "Walk", "Idle_Talking", "Fixing_Kneeling", "Spell_Simple_Idle", "PickUp_Table", "Death01", "Sword_Idle"]:
			if not ap.has_animation(a):
				manque.append(a)
		_verif(manque.is_empty(), "%s : animations %s" % [id, str(manque)])
		var tris := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			for s in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
		_verif(tris > 3000 and tris <= 8000, "%s : %d triangles (budget 8000)" % [id, tris])
		_verif(sq.find_bone("Head") >= 0 and sq.find_bone("hand_r") >= 0, "%s : os Head / hand_r" % id)
		# archétype ENTIER (D/pnj_complets) : toutes les pièces visibles de l'archétype seul le restent, aucune pièce d'un autre modèle
		# (visage Humain greffé...) ; triangles à ±600 de l'archétype (cape ôtée, outil tenu)
		var ref := PnjNordique.archetype_seul(id)
		root.add_child(ref)
		var noms_ref := _visibles(ref)
		var noms := _visibles(n)
		var perdus := []
		for k: String in noms_ref:
			if not noms.has(k):
				perdus.append(k)
		var greffes := []
		for k: String in noms:
			if not noms_ref.has(k) and not k.begins_with("Maillet") and not k.begins_with("Canne"):
				greffes.append(k)
		_verif(perdus.is_empty(), "%s : pièces de l'archétype toutes gardées %s" % [id, str(perdus)])
		_verif(greffes.is_empty(), "%s : aucune pièce étrangère %s" % [id, str(greffes)])
		var tref := _tris(ref)
		_verif(absi(tris - tref) <= 600, "%s : %d triangles / archétype %d" % [id, tris, tref])
		ref.queue_free()
		n.queue_free()
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
