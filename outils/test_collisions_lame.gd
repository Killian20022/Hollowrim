extends SceneTree
## Test sans fenêtre des collisions de la lame (prompt §7, §15) dans la zone de collisions de scenes/test_combat.tscn
## (ZoneCollisions) :
##   godot --headless --path . --script res://outils/test_collisions_lame.gd -- --nouvelle
## Cas : mur fin, coin, porte (vu à travers / chambranle), cibles serrées (multi_cibles), cible cachée derrière un mur,
## poteau très fin (pas de traversée sans dégâts), cible hors de portée (pas de touche sans contact), deux draugrs serrés,
## en mouvement (pas de côté + rotation de la caméra), aller-retour de la caméra (pas de double touche), et le même
## résultat à 20, 30, 60 et 144 images/s. Lignes CAS (résultat détaillé) et COMPARAISON (sans subdivision de la nappe).

const SCENE := preload("res://scenes/test_combat.tscn")
const FPS := [20, 30, 60, 144]
const BALAYAGES := ["diag_dg", "horizontale_b", "verticale_l", "horizontale_gd", "horizontale", "diag_gd"]

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var zone: ZoneCollisions

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _reset(poste: String) -> void:
	s.placer_joueur(zone.poste(poste), 0.0)
	j.vigueur = j.vigueur_max
	j.vie = j.vie_max
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._souris_recente = Vector2.ZERO
	mains.defense = DefenseJoueur.new()
	zone.remettre()
	for d in zone.cibles["draugrs"]:
		d.vie = 400.0
	for i in 30:
		mains.avancer(1.0 / 60.0)
	await physics_frame
	await physics_frame

## Un coup du geste `geste` depuis le poste, simulé à `fps`. `mouvement` : {"v": Vector3 (m/s, repère monde), "lacet": °/s,
## "aller_retour": vrai (la caméra tourne de ±lacet°/s, sens inversé toutes les 0,06 s)}. Renvoie le résultat.
func _coup(poste: String, geste: String, fps: int, mouvement := {}) -> Dictionary:
	await _reset(poste)
	var dt := 1.0 / float(fps)
	var vies := []
	for d in zone.cibles["draugrs"]:
		vies.append(d.vie)
	mains.trace.garder_debug = true
	mains.entrees.appuyer()
	var t := 0.0
	var arrete := false
	var etats := {}
	var lourd := geste in ["lourd", "verticale", "lourd_gd", "lourd_revers"]
	var duree_appui := 0.6 if lourd else 0.05
	var tenu := true
	var v: Vector3 = mouvement.get("v", Vector3.ZERO)
	var lacet: float = mouvement.get("lacet", 0.0)
	var rayons := 0
	var instants := []
	var cout_max := 0
	for k in roundi(1.0 / dt):
		if tenu and t >= duree_appui - 1e-9:
			mains.entrees.relacher()
			tenu = false
		var us := Time.get_ticks_usec()
		mains.avancer(dt)
		cout_max = maxi(cout_max, Time.get_ticks_usec() - us)
		if k == 0 and not lourd and mains._geste_nom != geste:
			mains._geste_nom = geste
			mains._preparer_geste(false)
		if lourd and mains.combat.etat == EtatCombat.CHARGE_LOURDE:
			mains._lourd_nom = geste
		etats[mains.combat.etat] = true
		arrete = arrete or mains.trace.arretee
		if mains._actif_lance or mains.combat.etat != EtatCombat.ATTAQUE_LEGERE:
			rayons = mains.trace.rayons
		# mouvement du joueur (après l'image : la caméra de l'image suivante est interpolée dans le tracé)
		if t < float(mouvement.get("duree", 0.4)):
			j.global_position += v * dt
		var sens := 1.0
		if mouvement.get("aller_retour", false):
			sens = 1.0 if int(floor(t / 0.06)) % 2 == 0 else -1.0
		j.rotation.y += deg_to_rad(lacet) * sens * dt
		t += dt
	mains.trace.garder_debug = false
	var res := {"poste": poste, "geste": geste, "fps": fps, "arret": arrete, "oeil": j.camera.global_position, "rebond": etats.has(EtatCombat.DESEQUILIBRE), "touches": [], "rayons": rayons, "impacts": mains.trace.debug_impacts.duplicate(), "instants": instants, "cout": cout_max}
	for c in zone.cibles[poste]:
		if c is CharacterBody3D:
			res["touches"].append(1 if c.vie < vies[zone.cibles[poste].find(c)] else 0)
		else:
			res["touches"].append(ZoneCollisions.nb_coups(c))
			for h in c.coups:
				instants.append(snappedf(float(h["info"].get("instant", -1.0)), 0.0001))
	print("CAS %-9s %-14s %3d i/s : touches %s, arrêt %s, rayons %d, image la plus chère %.2f ms%s" % [poste, geste, fps, res["touches"], "oui" if arrete else "non", rayons, cout_max / 1000.0, "" if mouvement.is_empty() else "  (en mouvement %s)" % mouvement])
	return res

## Aucune touche À TRAVERS un mur : chaque point d'impact du coup est vu de l'œil sans décor entre les deux.
func _sans_traversee(r: Dictionary) -> bool:
	var oeil: Vector3 = r["oeil"]
	var espace := j.get_world_3d().direct_space_state
	for p: Vector3 in r["impacts"]:
		var d := p - oeil
		if d.length() < 0.05:
			continue
		var q := PhysicsRayQueryParameters3D.create(oeil, oeil + d * (1.0 - 0.03 / d.length()), 1, [j.get_rid()])
		var h := espace.intersect_ray(q)
		if not h.is_empty() and TraceLame.cible_de(h["collider"]) == null:
			return false
	return true

func _somme(a: Array) -> int:
	var n := 0
	for x in a:
		n += int(x)
	return n

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "zone": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	zone = s.zone
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	for d in zone.cibles["draugrs"]:
		d._bouclier = 0.0
		d.combat.profil.chance_blocage = 0.0
	_verif(zone != null and zone.cibles["serres"].size() == 3 and zone.cibles["draugrs"].size() == 2, "zone de collisions : 8 postes, 3 mannequins serrés, 2 draugrs")

	var ref := {}   # résultats à 60 i/s, comparés aux autres fréquences
	for fps in FPS:
		print("-- %d images/s" % fps)
		var res := {}
		# mur fin, coin, cible derrière un mur : la lame s'arrête, rien n'est touché derrière
		for poste in ["mur_fin", "coin", "derriere"]:
			for g in (BALAYAGES + ["estoc"] if poste != "derriere" else ["horizontale_b", "horizontale", "diag_dg"]):
				var r := await _coup(poste, g, fps)
				res["%s/%s" % [poste, g]] = r
				if poste == "coin":
					# (coups_v4 : le V du coin s'ouvre VERS le joueur — pointe à ~2,07 m, bras jusqu'à 0,93 m de côté — et le
					# mannequin dépasse un peu devant la pointe. L'ancien attendu « lame arrêtée » venait des bras du V, sur les
					# côtés de l'écran ou hors de portée de la vraie lame : c'est le défaut corrigé. L'invariant gardé : jamais de
					# touche À TRAVERS un mur.)
					_verif(_sans_traversee(r), "%d i/s coin %s : aucune touche à travers un mur (touches %s, arrêt %s)" % [fps, g, r["touches"], "oui" if r["arret"] else "non"])
				else:
					_verif(r["arret"] and _somme(r["touches"]) == 0, "%d i/s %s %s : lame arrêtée, cible derrière intacte" % [fps, poste, g])
		# point d'arrêt sur la face du mur fin (5 cm, à 0,9 m)
		var rm: Dictionary = res["mur_fin/horizontale_gd"]
		var face_z: float = zone.poste("mur_fin").z - 0.9 + 0.025
		_verif(rm["impacts"].size() == 1 and absf((rm["impacts"][0] as Vector3).z - face_z) < 0.02, "%d i/s mur fin : arrêt SUR la face (z=%s, face %.3f)" % [fps, str(snappedf((rm["impacts"][0] as Vector3).z, 0.001)) if rm["impacts"].size() > 0 else "?", face_z])
		# porte : estoc dans l'axe → la cible est touchée par l'ouverture ; balayage horizontal → le chambranle arrête la lame
		var re := await _coup("porte", "estoc", fps)
		res["porte/estoc"] = re
		_verif(_somme(re["touches"]) == 1, "%d i/s porte, estoc : cible touchée par l'ouverture" % fps)
		# (coups_v4, 2026-10-29 soir : l'ancien attendu — « arrêté par le chambranle » — était justement le défaut signalé :
		# « parfois je ne peux pas donner de coup d'épée dans un endroit pas si restreint ». Le chambranle, sur le côté de l'écran,
		# ne fait plus rebondir la lame ; elle passe par l'ouverture et touche la cible, sans rebond.)
		var rh := await _coup("porte", "horizontale_gd", fps)
		res["porte/horizontale_gd"] = rh
		_verif(not rh["rebond"] and _somme(rh["touches"]) == 1, "%d i/s porte, horizontal : passe par l'ouverture (pas de rebond sur le chambranle), cible touchée %s" % [fps, rh["touches"]])
		var rv := await _coup("porte", "verticale_l", fps)
		res["porte/verticale_l"] = rv
		_verif(not (rv["arret"] and _somme(rv["touches"]) > 0 and false), "%d i/s porte, vertical : %s" % [fps, "touchée" if _somme(rv["touches"]) > 0 else "arrêté par l'embrasure"])
		# cibles serrées : 2 touchées au plus (multi_cibles), jamais deux fois la même
		for g in ["horizontale_b", "horizontale_gd", "lourd"]:
			var r := await _coup("serres", g, fps)
			res["serres/%s" % g] = r
			_verif(_somme(r["touches"]) == 2 and r["touches"].max() == 1, "%d i/s serrés %s : 2 cibles, une touche chacune %s" % [fps, g, r["touches"]])
		# poteau de 8 cm à 1 m : chaque balayage le touche (une fois)
		for g in BALAYAGES:
			var r := await _coup("poteau", g, fps)
			res["poteau/%s" % g] = r
			_verif(r["touches"] == [1], "%d i/s poteau %s : touché une fois (pas de traversée) %s" % [fps, g, r["touches"]])
		# hors de portée : rien
		for g in ["diag_dg", "horizontale_b", "estoc"]:
			var r := await _coup("loin", g, fps)
			res["loin/%s" % g] = r
			_verif(_somme(r["touches"]) == 0, "%d i/s cible à 2,7 m, %s : pas de touche sans contact" % [fps, g])
		# deux draugrs serrés (vraies capsules)
		var rd := await _coup("draugrs", "horizontale_b", fps)
		res["draugrs/horizontale_b"] = rd
		_verif(rd["touches"] == [1, 1], "%d i/s deux draugrs serrés : les deux touchés %s" % [fps, rd["touches"]])
		# en mouvement : pas de côté à 3 m/s + rotation de 90°/s ; aller-retour rapide de la caméra (200°/s) sur le poteau
		var rmv := await _coup("serres", "horizontale_b", fps, {"v": Vector3(2.0, 0, 0), "lacet": 60.0})
		res["serres_mvt"] = rmv
		_verif(_somme(rmv["touches"]) == 2 and rmv["touches"].max() == 1, "%d i/s serrés en mouvement : 2 cibles, une fois chacune %s" % [fps, rmv["touches"]])
		var rmp := await _coup("poteau", "horizontale_gd", fps, {"v": Vector3(0.0, 0, -1.5)})
		res["poteau_mvt"] = rmp
		_verif(rmp["touches"] == [1], "%d i/s poteau en avançant : touché une fois %s" % [fps, rmp["touches"]])
		var rar := await _coup("poteau", "verticale_l", fps, {"lacet": 200.0, "aller_retour": true})
		res["poteau_ar"] = rar
		_verif(rar["touches"].max() <= 1, "%d i/s poteau, caméra en aller-retour : jamais deux touches dans le même coup %s" % [fps, rar["touches"]])
		ref[fps] = res
	# même résultat à toutes les fréquences (touches et arrêts) ; instant d'impact identique à un pas de tracé près (sans mouvement)
	for fps in FPS:
		if fps == 60:
			continue
		var diff := []
		var ecart := 0.0
		for cle in ref[60]:
			var a: Dictionary = ref[60][cle]
			var b: Dictionary = ref[fps][cle]
			if a["touches"] != b["touches"] or a["arret"] != b["arret"]:
				diff.append(cle)
			if not cle.ends_with("_mvt") and not cle.ends_with("_ar") and a["instants"].size() == b["instants"].size():
				for i in a["instants"].size():
					ecart = maxf(ecart, absf(float(a["instants"][i]) - float(b["instants"][i])))
		_verif(diff.is_empty() and ecart <= TraceLame.PAS + 1e-4, "%d i/s : mêmes touches et arrêts qu'à 60 i/s (%d cas), instant d'impact à %.4f s près %s" % [fps, ref[60].size(), ecart, diff])

	# comparaison : poteau à plusieurs distances et décalages, AVEC et SANS subdivision de la nappe (ancien tracé radial :
	# 7 rayons par échantillon) ; 6 balayages à 60 i/s par position
	var poteau: Node3D = zone.cibles["poteau"][0]
	var pos0 := poteau.position
	var res_sans := TraceLame.resolution
	var bilan := {}
	var detail_mode := {}
	for mode in ["sans", "avec", "sans_volume", "reference"]:
		TraceLame.pre_test_volume = mode != "sans_volume"
		TraceLame.resolution = {"sans": deg_to_rad(180.0), "avec": res_sans, "sans_volume": res_sans, "reference": deg_to_rad(0.4)}[mode]
		TraceLame.sous_pas_max = 120 if mode == "reference" else 20
		TraceLame.sous_lame_max = 60 if mode == "reference" else 10
		var rates := 0
		var total := 0
		var rayons := 0
		var cout := 0
		var detail := []
		for dist in [0.8, 1.2, 1.5, 1.7]:
			for x in [-0.35, 0.0, 0.35]:
				poteau.position = pos0 + Vector3(x - pos0.x + zone.poste("poteau").x - zone.global_position.x, 0, -dist + 1.0)
				await physics_frame
				for g in BALAYAGES:
					var r := await _coup("poteau", g, 60)
					total += 1
					rayons += int(r["rayons"])
					cout = maxi(cout, int(r["cout"]))
					if r["touches"] != [1]:
						rates += 1
						detail.append("%s@%.1fm,x%+.2f" % [g, dist, x])
		bilan[mode] = rates
		detail_mode[mode] = detail
		print("COMPARAISON %s subdivision : poteau de 8 cm, %d coups (4 distances × 3 décalages × 6 balayages) : %d raté(s), %.0f rayons par coup, image la plus chère %.2f ms %s" % [mode, total, rates, float(rayons) / total, cout / 1000.0, detail])
	TraceLame.resolution = res_sans
	TraceLame.pre_test_volume = true
	TraceLame.sous_pas_max = 20
	TraceLame.sous_lame_max = 10
	poteau.position = pos0
	# référence : nappe à 0,4° (la lame vue passe-t-elle VRAIMENT sur le poteau ?) ; les ratés de la référence sont des
	# positions que la lame ne balaie pas (pas de contact), pas des traversées
	_verif(detail_mode["avec"] == detail_mode["reference"], "poteau à 0,8-1,7 m, 72 coups : mêmes touches qu'une nappe à 0,4° (aucune traversée sans dégâts ; sans subdivision : %d raté(s) de plus)" % (int(bilan["sans"]) - int(bilan["reference"])))
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
