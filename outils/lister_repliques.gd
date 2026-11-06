extends SceneTree
## Outil de diagnostic des répliques filtrées (data/dialogue/repliques.json) : l'ORDRE masque des répliques, ce script le montre.
##  1. Pour un contexte donné, liste les répliques valides de chaque sujet (la première = celle qui serait dite, ◄) et, pour les
##     autres répliques du PNJ, le premier filtre qui les refuse.
##  2. Signale les répliques JAMAIS atteignables : filtres contradictoires, quête ou étape inconnue, ou masquées par une réplique
##     placée avant dont les filtres sont plus larges. Code de sortie 1 s'il y en a.
##   godot --headless --path . --script res://outils/lister_repliques.gd -- --pnj=chasseuse --quetes=anneau_givre:3 --heure=22
## Options (toutes facultatives) : --pnj=id  --sujet=quete|apres|salut (défaut : tous)  --heure=h  --jour=n
##   --quetes=id:index,id:index (index = étapes faites ; 0 = pas commencée)  --vus=evt,evt  --disposition=palier  --score=0-100
##   --rang=faction:n (rang du joueur)  --faction=  --lieu=  --marchand  --maison  --choix  --echouees=id,id  --seulement-analyse
## Sans --pnj, seule l'analyse du fichier est faite.

func _init() -> void:
	var a := _args()
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quetes.json"))
	var quetes: Dictionary = donnees if donnees is Dictionary else {}
	var liste := RepliquesFiltrees.charger()
	print("%d répliques dans %s" % [liste.size(), RepliquesFiltrees.FICHIER])
	if a.has("pnj"):
		_contexte_donne(a, quetes, liste)
	var mauvaises := RepliquesFiltrees.inatteignables(liste, quetes)
	print("\nRépliques jamais atteignables : %d" % mauvaises.size())
	for m: Dictionary in mauvaises:
		if not a.has("pnj") or String(m["id"]).begins_with(String(a["pnj"]) + ".") or _pnj_de(liste, String(m["id"])) == String(a["pnj"]):
			print("  - %s : %s" % [m["id"], m["raison"]])
	quit(1 if not mauvaises.is_empty() else 0)

func _pnj_de(liste: Array, id: String) -> String:
	for r: Dictionary in liste:
		if String(r.get("id", "")) == id:
			return String(r.get("filtres", {}).get("pnj", ""))
	return ""

func _args() -> Dictionary:
	var res := {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			res[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return res

func _contexte_donne(a: Dictionary, quetes: Dictionary, liste: Array) -> void:
	var index := {}
	for p in String(a.get("quetes", "")).split(",", false):
		var kv := p.split(":")
		index[kv[0]] = int(kv[1])
	var vus := {}
	for e in String(a.get("vus", "")).split(",", false):
		vus[e] = true
	var echecs := {}
	for e in String(a.get("echouees", "")).split(",", false):
		echecs[e] = true
	var rangs := {}
	if a.has("rang"):
		var kv := String(a["rang"]).split(":")
		rangs[kv[0]] = int(kv[1])
	var pnj := String(a["pnj"])
	var faction := String(a.get("faction", "garde" if pnj == "garde" else "village"))
	var ctx := {"pnj": pnj, "faction": faction, "lieu": String(a.get("lieu", "")), "marchand": a.has("marchand"),
		"heure": float(a.get("heure", 12.0)), "jour": int(a.get("jour", 1)), "disposition": String(a.get("disposition", "neutre")),
		"score": float(a.get("score", 50.0)), "rangs": rangs, "index": index, "echecs": echecs, "vus": vus, "quetes": quetes,
		"maison": a.has("maison"), "choix": a.has("choix")}
	print("\nContexte : %s" % JSON.stringify({"pnj": pnj, "faction": faction, "heure": ctx["heure"], "disposition": ctx["disposition"],
		"quetes": index, "vus": vus.keys(), "rangs": rangs}))
	for sujet: String in ["quete", "apres", "salut"]:
		if a.has("sujet") and a["sujet"] != sujet:
			continue
		var retenues := RepliquesFiltrees.choisir(sujet, ctx, liste)
		var ids := retenues.map(func(r: Dictionary) -> String: return String(r.get("id", "")))
		print("\nSujet « %s » : %s" % [sujet, (", ".join(PackedStringArray(ids)) if not ids.is_empty() else "aucune réplique valide")])
		for r: Dictionary in liste:
			if String(r.get("sujet", "")) != sujet:
				continue
			var f: Dictionary = r.get("filtres", {})
			if f.has("pnj") and not pnj in RepliquesFiltrees._liste(f["pnj"]) and not (sujet == "salut"):
				continue
			var ref := RepliquesFiltrees.refus(r, ctx)
			var id := String(r.get("id", ""))
			if ref == "":
				var t: Array = r.get("texte", [])
				print("  %s %s  « %s »%s" % ["◄" if id in ids else "  ", id, String(t[0]).left(60) if not t.is_empty() else "(effets seuls)",
					"  (valide mais masquée par une réplique placée avant)" if not id in ids else ""])
			else:
				print("     %s  refusée : %s" % [id, ref])
