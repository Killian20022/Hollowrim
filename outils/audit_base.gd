extends RefCounted
## Aides communes des outils d'audit de bugs (outils/audit_*.gd). Aucune dépendance au jeu.
## Chaque outil remplit un `Rapport` (liste de problèmes {cat, grav, x, y, z, msg}) puis l'écrit en JSON dans
## captures/audit/<nom>.json ; outils/audit_carte.gd les assemble en carte PNG vue de dessus et en tableau.
## Gravités : "bloquant" (impossible de continuer / chute dans le vide), "gênant", "cosmetique", "info".

static func dossier() -> String:
	var d := ProjectSettings.globalize_path("res://captures/audit")
	DirAccess.make_dir_recursive_absolute(d)
	return d

class Rapport:
	var nom := ""
	var items: Array = []
	var stats := {}
	func _init(n: String) -> void:
		nom = n
	func ajouter(cat: String, grav: String, p: Vector3, msg: String, extra := {}) -> void:
		var e := {"cat": cat, "grav": grav, "x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01), "msg": msg}
		for k in extra:
			e[k] = extra[k]
		items.append(e)
		print("[%s] %s | %s (%.1f, %.1f, %.1f) %s" % [grav, cat, nom, p.x, p.y, p.z, msg])
	func ecrire() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/audit"))
		var f := FileAccess.open(ProjectSettings.globalize_path("res://captures/audit") + "/" + nom + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"nom": nom, "stats": stats, "problemes": items}, "\t"))
		f.close()
		var par := {}
		for e in items:
			par[e["grav"]] = int(par.get(e["grav"], 0)) + 1
		print("RAPPORT %s : %d problème(s) %s ; stats %s" % [nom, items.size(), str(par), str(stats)])

## Regroupe des cases (Vector2i → vrai) en grappes connexes (8 voisins). Renvoie Array de Array[Vector2i].
static func grappes(cases: Dictionary) -> Array:
	var vu := {}
	var res: Array = []
	for c: Vector2i in cases:
		if vu.has(c):
			continue
		var g: Array = []
		var pile: Array = [c]
		vu[c] = true
		while not pile.is_empty():
			var k: Vector2i = pile.pop_back()
			g.append(k)
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n := Vector2i(k.x + dx, k.y + dz)
					if cases.has(n) and not vu.has(n):
						vu[n] = true
						pile.append(n)
		res.append(g)
	return res

static func boite(g: Array, pas: float, origine: Vector2) -> Dictionary:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var s := Vector2.ZERO
	for k: Vector2i in g:
		var p := origine + Vector2(k.x, k.y) * pas
		mn = mn.min(p)
		mx = mx.max(p)
		s += p
	return {"centre": s / maxf(g.size(), 1), "min": mn, "max": mx, "n": g.size()}
