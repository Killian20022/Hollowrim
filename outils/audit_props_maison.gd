extends SceneTree
## Audit des objets « maison » restants dans les souterrains (grottes, entrée de grotte, crypte, donjon, tertre) : boîtes primitives et
## modules Blender maison (hors structures) posés par genre d'objet de haut niveau, par lieu. Mesure AVANT / APRÈS un remplacement.
##   godot --headless --path . --script res://outils/audit_props_maison.gd -- --nouvelle --paisible [--sortie=<fichier.txt>]
## Sortie : une ligne « lieu | genre | boîtes | modules maison (nom x n) », puis le total par lieu.
const SCENE := "res://scenes/foret_test.tscn"

func _init() -> void:
	CrypteDecor.audit_actif = true      # active objet_debut() : le genre de l'objet en cours
	CrypteDecor.stats_maison_actif = true
	_go.call_deferred()

func _go() -> void:
	var sortie := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	var m: Node3D = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 90:
		await physics_frame
	if m.tertre != null:
		m.tertre.attendre_donjon()
	var n := 0
	while m.grotte_acces != null and not m.grotte_acces.fonds_prets() and n < 6000:      # grotte (extérieur + intérieur) bâtie en fil
		await physics_frame
		n += 1
	for i in 30:
		await physics_frame
	var lignes: PackedStringArray = []
	var _ignore := ["dallage_", "eboulis_", "dalles_", "niche_os", "oss_", "os_court", "os_long", "racine_voute", "maillon", "chaines_grappe", "bougies_grappe",
		"applique_fer", "brasero_v2", "candelabre_l8", "cage_suspendue", "lanterne_fer", "tringle_", "bassin_"]      # architecture, ossuaire, luminaires : validés, gardés
	var totaux := {}
	var cles: Array = CrypteDecor.stats_maison.keys()
	cles.sort()
	for k: String in cles:
		var d: Dictionary = CrypteDecor.stats_maison[k]
		var lieu := k.split("|")[0]
		var nb_b := int(d.get("boite", 0))
		var mods: PackedStringArray = []
		var nb_m := 0
		for c: String in d:
			var ig := false
			for pre: String in _ignore:
				if c.begins_with("module:" + pre):
					ig = true
			if ig:
				continue
			if c.begins_with("module:"):
				mods.append("%s x%d" % [c.substr(7), d[c]])
				nb_m += int(d[c])
		lignes.append("%-26s | %-22s | boites %4d | modules %3d %s" % [lieu, k.split("|")[1], nb_b, nb_m, ", ".join(mods)])
		var t: Array = totaux.get(lieu, [0, 0])
		t[0] += nb_b
		t[1] += nb_m
		totaux[lieu] = t
	lignes.append("--- TOTAUX (boites, modules maison) par lieu")
	for l: String in totaux:
		lignes.append("TOTAL %-26s boites %5d  modules %4d" % [l, totaux[l][0], totaux[l][1]])
	var txt := "\n".join(lignes)
	print(txt)
	if sortie != "":
		var f := FileAccess.open(sortie, FileAccess.WRITE)
		f.store_string(txt + "\n")
	quit(0)
