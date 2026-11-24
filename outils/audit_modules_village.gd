extends SceneTree
## Audit des modules fondus du village (MobilierVillage.substitut) dans leur repère local : dessous au-dessus / au-dessous de y = 0 (flottant,
## enfoncé), jours entre pièces de structure (3-25 cm), débordement hors de l'emprise attendue. Headless, sans monde.
##   godot --headless --path . --script res://outils/audit_modules_village.gd
const MODS := ["banc", "tonneau_a", "tonneau_b", "tonneau_c", "caisse_a", "caisse_b", "caisse_c", "charrette", "forge_billot", "forge_meule", "tronc_banc",
	"sacs", "tas_bois", "etal", "banniere", "puits", "meule_foin", "sechoir_peaux", "feu_camp", "forge_foyer"]
const STRUCT := ["q_poutre_ronde", "q_rondin", "q_tronc", "q_bordure_1", "q_planches_sol", "q_buche"]

func _init() -> void:
	var total := 0
	for m: String in MODS:
		var items: Array = MobilierVillage.substitut(m)
		var boxes: Array = []
		var bas_min := INF
		for it: Array in items:
			if String(it[0]) == "":
				boxes.append(AABB())
				continue
			var bb := PropsQuaternius.boite(it[0], it[2] if it.size() > 2 else {})
			var xf: Transform3D = it[1]
			var r := AABB(xf * bb.position, Vector3.ZERO)
			for cx: float in [bb.position.x, bb.end.x]:
				for cy: float in [bb.position.y, bb.end.y]:
					for cz: float in [bb.position.z, bb.end.z]:
						r = r.expand(xf * Vector3(cx, cy, cz))
			boxes.append(r)
			bas_min = minf(bas_min, r.position.y)
		var l: Array = []
		if bas_min != INF and absf(bas_min) > 0.08:
			l.append("PIED du module à %.2f m du sol (y=0)" % bas_min)
		for i in items.size():
			if String(items[i][0]) == "":
				continue
			var b: AABB = boxes[i]
			var porte := false
			for j in items.size():
				if j == i or String(items[j][0]) == "":
					continue
				var o: AABB = boxes[j]
				var rec := b.position.x < o.end.x and b.end.x > o.position.x and b.position.z < o.end.z and b.end.z > o.position.z
				if rec and (absf(b.position.y - o.end.y) < 0.12 or (b.position.y > o.position.y and b.position.y < o.end.y)):
					porte = true
				var g := Vector3(maxf(maxf(o.position.x - b.end.x, b.position.x - o.end.x), 0.0), maxf(maxf(o.position.y - b.end.y, b.position.y - o.end.y), 0.0), maxf(maxf(o.position.z - b.end.z, b.position.z - o.end.z), 0.0)).length()
				if j > i and String(items[i][0]) in STRUCT and String(items[j][0]) in STRUCT and g > 0.03 and g < 0.25:
					l.append("JOUR %s / %s %.0f cm" % [items[i][0], items[j][0], g * 100.0])
			if not porte and b.position.y > 0.2 and b.position.y - bas_min > 0.2:
				l.append("FLOTTANT %s dessous à %.2f m" % [items[i][0], b.position.y])
		total += l.size()
		print("== %s (%d pièces) %d anomalies" % [m, items.size(), l.size()])
		for x: String in l:
			print("   ", x)
	print("TOTAL ", total)
	quit(0)
