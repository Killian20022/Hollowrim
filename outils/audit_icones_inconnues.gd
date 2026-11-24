extends SceneTree
## AUDIT : objets dont l'icône finale est le losange « ? » (motif « inconnu » d'IconesCombat). Pas d'atlas 3D ET motif inconnu.
##   godot --headless --path . --script res://outils/audit_icones_inconnues.gd -- --nouvelle
## Sortie : « AUDIT_ICONES n_sans_icone / n_total » + la liste par catégorie. Code 1 s'il en reste.
func _init() -> void:
	_lancer.call_deferred()

## Motif qu'utiliserait MenuStyle.icone_pixel (même logique) ; "inconnu" = losange « ? ».
static func motif_de(id: String) -> String:
	var f := Inventaire.objet(id)
	var m := String(f.get("icone", ""))
	if m == "":
		m = String(MenuStyle.ICONE_OBJET.get(id, ""))
	if m == "" and (IconesCombat.connu(id) or MenuStyle.MOTIFS_MENU.has(id)):
		m = id
	if m == "" and not f.is_empty():
		m = String(MenuStyle.ICONE_DEFAUT.get(String(f.get("categorie", "")), "inconnu"))
	if m == "":
		m = "inconnu"
	if not (IconesCombat.connu(m) or MenuStyle.MOTIFS_MENU.has(m)):
		m = "inconnu"
	return m

func _lancer() -> void:
	var gen: Script = load("res://outils/generer_icones.gd")
	var ids: Array = gen.call("ids_a_rendre")
	# + ids vus dans les tables de butin, stocks de marchands, quêtes et appels ajouter() (outils/_ids_candidats.txt)
	var vus := {}
	for i in ids:
		vus[i] = true
	if FileAccess.file_exists("res://outils/_ids_candidats.txt"):
		for l in FileAccess.get_file_as_string("res://outils/_ids_candidats.txt").split("\n", false):
			if not vus.has(l) and l != "pieces":
				ids.append(l)
				vus[l] = true
	var sorts := {}
	# + sorts du joueur (onglet Magie, barre des mains) : data/sorts/*.tres
	for f in DirAccess.get_files_at("res://data/sorts"):
		if f.ends_with(".tres"):
			var sid := f.get_basename()
			sorts[sid] = true
			if not vus.has(sid):
				ids.append(sid)
				vus[sid] = true
	var par := {}
	var n := 0
	for id: String in ids:
		if IconesObjets.a(id):
			continue
		var motif := String(Inventaire.objet(id).get("icone", ""))
		var vit := not sorts.has(id) and not IconesCombat.connu(motif if motif != "" else id)       # fenêtres marchand/coffre/butin : motif de la fiche, sinon losange de rareté
		if OS.get_cmdline_user_args().has("--detail"):
			print("SANS_ATLAS ", id, " cat=", Inventaire.categorie_de(id), " icone_fiche=", motif, " menu=", motif_de(id), " vitrine_losange=", vit)
		if motif_de(id) == "inconnu" or vit:
			n += 1
			var c := Inventaire.categorie_de(id)
			if not par.has(c):
				par[c] = []
			par[c].append(id)
	for c in par:
		print("  ", c, " (", par[c].size(), ") : ", ", ".join(PackedStringArray(par[c])))
	print("AUDIT_ICONES ", n, " / ", ids.size())
	quit(1 if n > 0 else 0)
