class_name Lacher
extends RefCounted
## LÂCHER un objet du sac (inventaire I) : il tombe devant le joueur dans un petit SAC AU SOL, ramassable par « Fouiller » (E) comme le
## butin d'un corps (scripts/butin.gd, fenêtre de butin FenetreButin). Réutilise le butin existant : le sac au sol est un Butin sans pièces
## dont la clé « lache:<n> » le fait SAUVEGARDER avec la partie (ButinTables.restes / corps, repris par Butin.restaurer).
## Non lâchables : objets uniques (rarete « unique ») et objets de quête (valeur 0 hors consommables, ou « quete »: true fiche).

const NOM := "Objet lâché"
const DISTANCE := 1.1

## "" si `id` peut être lâché, sinon la raison (message clair pour l'inventaire).
static func refus(id: String) -> String:
	var o := Inventaire.objet(id)
	if o.is_empty():
		return "Objet inconnu."
	var nom := String(o.get("nom", id))
	if String(o.get("rarete", "")) == "unique":
		return "%s est un objet unique : on ne s'en défait pas." % nom
	if bool(o.get("quete", false)) or (Inventaire.categorie_de(id) != "consommable" and float(o.get("valeur", 0)) <= 0.0):
		return "%s est un objet de quête : impossible de le lâcher." % nom
	return ""

## Lâche `n` exemplaires de `id` devant le joueur. Renvoie "" (fait) ou la raison du refus.
static func lacher(joueur: CharacterBody3D, hud: Control, id: String, n: int) -> String:
	if joueur == null or not is_instance_valid(joueur):
		return "Impossible ici."
	var inv: Inventaire = joueur.inventaire
	var r := refus(id)
	if r != "":
		return r
	n = clampi(n, 1, inv.nombre(id))
	if inv.nombre(id) <= 0:
		return "Vous n'en avez pas."
	var parent := joueur.get_parent()
	if parent == null:
		return "Impossible ici."
	inv.retirer(id, n)
	var b := Node3D.new()
	b.set_script(preload("res://scripts/butin.gd"))
	b.joueur = joueur
	b.hud = hud
	b.nom_corps = NOM
	b.contenu = {id: n}
	b.cle_sauvegarde = "lache:%d_%d" % [Time.get_unix_time_from_system() as int, Time.get_ticks_usec()]
	parent.add_child(b)
	b.global_position = _point(joueur)
	return ""

## Devant le joueur (selon la caméra), posé sur le sol (rayon vers le bas ; le joueur est exclu).
static func _point(joueur: CharacterBody3D) -> Vector3:
	var av := -joueur.global_basis.z
	var cam: Variant = joueur.get("camera")
	if cam is Camera3D:
		av = -(cam as Camera3D).global_basis.z
	av.y = 0.0
	av = av.normalized() if av.length() > 0.05 else Vector3.FORWARD
	var p := joueur.global_position + av * DISTANCE
	var espace := joueur.get_world_3d().direct_space_state
	var haut := Vector3(p.x, joueur.global_position.y + 1.0, p.z)
	var q := PhysicsRayQueryParameters3D.create(haut, haut - Vector3(0, 3.0, 0))
	q.exclude = [joueur.get_rid()]
	var res := espace.intersect_ray(q)
	if res.is_empty():
		return Vector3(p.x, joueur.global_position.y, p.z)
	# mur entre le joueur et le point : le sac tombe à ses pieds
	var m := PhysicsRayQueryParameters3D.create(joueur.global_position + Vector3(0, 0.6, 0), Vector3(p.x, joueur.global_position.y + 0.6, p.z))
	m.exclude = [joueur.get_rid()]
	if not espace.intersect_ray(m).is_empty():
		return joueur.global_position
	return res["position"]

## Petit sac de toile noué (boule aplatie + goulot), posé sur le nœud : visible sur le Butin « lache: ».
static func habiller(noeud: Node3D) -> void:
	var img := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color("#6a5236"))
	img.set_pixel(1, 0, Color("#4a3824"))
	var tex := ImageTexture.create_from_image(img)
	var mat := Palette.materiau(tex)
	mat.set_shader_parameter("tex_neige", tex)
	var corps := SphereMesh.new()
	corps.radius = 0.2
	corps.height = 0.3
	corps.radial_segments = 8
	corps.rings = 4
	var cou := SphereMesh.new()
	cou.radius = 0.07
	cou.height = 0.12
	cou.radial_segments = 6
	cou.rings = 3
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = corps if k == 0 else cou
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, 0.15, 0) if k == 0 else Vector3(0, 0.33, 0)
		noeud.add_child(mi)
