extends SceneTree
## Outil : carte ASCII des biomes de la faune (scripts/faune.gd) sur le vrai monde + territoires tirés.
##   godot --headless --path . -s res://outils/faune_carte.gd -- --nouvelle --paisible
## F forêt, c clairière, . plaine de neige, a abords du village, V village ; chiffres/lettres = territoires (L loup, C cerf, B biche, R renard).
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var m: Node3D = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	var fa: Faune = m.faune
	var cnt := {}
	var terr := {}
	for t: Dictionary in fa.territoires:
		terr[Vector2i(roundi(t["x"] / 4.0), roundi(t["z"] / 4.0))] = String(t["espece"]).left(1).to_upper()
		cnt[t["biome"]] = int(cnt.get(t["biome"], 0)) + 1
	var dens := []
	for z in range(-120, 124, 4):
		var ligne := ""
		for x in range(-120, 124, 4):
			var k := Vector2i(x / 4, z / 4)
			if terr.has(k):
				ligne += terr[k]
				continue
			var b := fa.biome_en(float(x), float(z))
			ligne += {"foret": "F", "clairiere": "c", "plaine_neige": ".", "abords_village": "a", "village": "V"}.get(b, "?")
			if absf(x) < 112 and absf(z) < 112:
				dens.append(fa.densite_arbres(float(x), float(z)))
		print(ligne)
	for t: Dictionary in fa.territoires:
		print("TERR %02d %-7s %-14s x=%6.1f z=%6.1f groupe=%d u=%.2f" % [t["id"], t["espece"], t["biome"], t["x"], t["z"], t["groupe"], t["u"]])
	dens.sort()
	print("densité (arbres / 24x24 m) : p10 %d p25 %d p50 %d p75 %d p90 %d max %d" % [dens[dens.size() / 10], dens[dens.size() / 4], dens[dens.size() / 2], dens[dens.size() * 3 / 4], dens[dens.size() * 9 / 10], dens[-1]])
	print("territoires par biome : ", cnt, " total ", fa.territoires.size(), " ; arbres ", m.arbres.size())
	quit(0)
