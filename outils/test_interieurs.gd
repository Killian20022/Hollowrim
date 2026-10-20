extends SceneTree
## Test headless des intérieurs enterables de Skarnholt (lot « kit intérieur »), sans fenêtre :
##   godot --headless --path . --script res://outils/test_interieurs.gd -- --nouvelle
## Pour chacune des cinq maisons (halle, sigrun, chasseurs, grima, forge) une capsule de joueur (rayon 0,35, haut 1,8) :
##   1. porte FERMÉE : ne peut pas entrer ;
##   2. porte ouverte : entre par la porte, atteint l'intérieur, reste sur le plancher ;
##   3. ressort par la porte ;
##   4. poussée contre les murs depuis l'intérieur (fond, ouest, est) puis depuis l'extérieur : ne traverse jamais ;
##   5. l'objet « porte » (touche E) existe, l'intérieur n'est visible et éclairé que de près.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _marcheur(pos: Vector3) -> CharacterBody3D:
	var w := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	w.add_child(cap)
	root.add_child(w)
	w.global_position = pos
	return w

## Marche en ligne droite vers `cible` (plan horizontal) ; vrai si arrivé à 0,3 m avant `pas` images.
func _aller(w: CharacterBody3D, cible: Vector3, pas := 500, vitesse := 3.5) -> bool:
	for i in pas:
		var d := cible - w.global_position
		d.y = 0.0
		if d.length() < 0.3:
			return true
		d = d.normalized()
		w.velocity.x = d.x * vitesse
		w.velocity.z = d.z * vitesse
		w.velocity.y -= 20.0 / 60.0
		w.move_and_slide()
		if w.is_on_floor():
			w.velocity.y = 0.0
		await physics_frame
	return false

## Pousse dans la direction locale `dir` du bâtiment pendant `pas` images (sans cible).
func _pousser(w: CharacterBody3D, ip: Interieur, dir: Vector3, pas := 200, vitesse := 3.5) -> void:
	var dg := (ip.global_transform.basis * dir).normalized()
	for i in pas:
		w.velocity.x = dg.x * vitesse
		w.velocity.z = dg.z * vitesse
		w.velocity.y -= 20.0 / 60.0
		w.move_and_slide()
		if w.is_on_floor():
			w.velocity.y = 0.0
		await physics_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	var v: Node3D = m.village
	for i in 300:
		if v.prets:
			break
		await physics_frame
	_verif(v.prets, "les intérieurs sont construits après le chargement (une maison par image)")
	m.joueur.set_physics_process(false)    # le joueur reste au point où on le pose (la caméra sert à la fermeture automatique)
	_verif(v.interieurs.size() == 5, "5 intérieurs enterables (trouvés : %d)" % v.interieurs.size())
	for id in ["halle", "sigrun", "chasseurs", "grima", "forge"]:
		await _tester_maison(v, id)
	await _tester_visibilite(v)
	await _tester_pnj(v)
	print("ECHEC total : %d" % _echecs if _echecs > 0 else "TOUT OK")
	quit(1 if _echecs > 0 else 0)

func _tester_maison(v: Node3D, id: String) -> void:
	var ip: Interieur = v.interieur(id)
	_verif(ip != null, "[%s] intérieur trouvé" % id)
	if ip == null:
		return
	var px := ip.porte_locale.x
	var zp := ip.porte_locale.z - 0.05              # plan de la porte
	var y := ip.sol_y + 0.15
	var dehors := ip.to_global(Vector3(px, y, zp + 2.8))
	var dedans := ip.to_global(Vector3(px, y, zp - 1.5))
	var seuil := ip.to_global(Vector3(px, y, zp + 0.2))
	_verif(ip.interactif != null, "[%s] objet « porte » (touche E) posé : « %s »" % [id, ip.nom])
	_verif(not ip.ouverte, "[%s] porte fermée au départ" % id)

	# la porte se referme toute seule quand le joueur s'éloigne : il faut donc le garder près d'elle
	m.joueur.global_position = ip.to_global(Vector3(px, y, zp + 6.0))
	# 1. porte fermée
	var w := _marcheur(dehors)
	for i in 10:
		await physics_frame
	var arrive := await _aller(w, dedans, 260)
	var loc := ip.to_local(w.global_position)
	_verif(not arrive and loc.z > zp - 0.2, "[%s] porte fermée : bloqué dehors (z local %.2f, plan de la porte %.2f)" % [id, loc.z, zp])
	# 2. porte ouverte
	ip.basculer(true, false)
	for i in 50:
		await physics_frame
	w.global_position = dehors
	w.velocity = Vector3.ZERO
	var a1 := await _aller(w, seuil, 300)
	var a2 := await _aller(w, dedans, 300)
	loc = ip.to_local(w.global_position)
	_verif(a1 and a2, "[%s] porte ouverte : franchit le seuil et atteint l'intérieur (z local %.2f)" % [id, loc.z])
	_verif(ip.dedans(loc), "[%s] la capsule est bien DANS l'emprise (x %.2f, z %.2f)" % [id, loc.x, loc.z])
	_verif(absf(loc.y - ip.sol_y) < 0.2, "[%s] debout sur le plancher (y local %.2f, sol %.2f)" % [id, loc.y, ip.sol_y])
	# 3. ressort
	var r1 := await _aller(w, seuil, 300)
	var r2 := await _aller(w, dehors, 300)
	loc = ip.to_local(w.global_position)
	_verif(r1 and r2 and not ip.dedans(loc), "[%s] ressort par la porte (z local %.2f)" % [id, loc.z])
	# 4. murs depuis l'intérieur : fond (-Z), ouest (-X) puis est (+X), sans traverser
	var limites := Vector2(ip.demi.x + 0.35, ip.demi.y + 0.35)
	for dir in [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		w.global_position = ip.to_global(Vector3(px * 0.5, y, zp - 1.5))
		w.velocity = Vector3.ZERO
		await _pousser(w, ip, dir, 240)
		loc = ip.to_local(w.global_position)
		_verif(absf(loc.x) < limites.x + 0.15 and loc.z > -limites.y - 0.15 and loc.z < zp + 0.2, "[%s] poussée vers %s depuis l'intérieur : reste dedans (x %.2f, z %.2f)" % [id, dir, loc.x, loc.z])
	# murs depuis l'extérieur : on pousse vers le centre depuis chaque côté
	for dep in [Vector3(ip.demi.x + 2.0, y, -0.4), Vector3(-ip.demi.x - 2.0, y, -0.4), Vector3(-0.4, y, -ip.demi.y - 2.0)]:
		w.global_position = ip.to_global(dep)
		w.velocity = Vector3.ZERO
		for i in 6:
			await physics_frame
		var vers := Vector3(-dep.x, 0, -dep.z).normalized() if absf(dep.z) < 1.0 else Vector3(0, 0, -dep.z).normalized()
		await _pousser(w, ip, vers, 240)
		loc = ip.to_local(w.global_position)
		_verif(not ip.dedans(loc, -0.1), "[%s] poussée vers l'intérieur depuis %s : reste dehors (x %.2f, z %.2f)" % [id, dep, loc.x, loc.z])
	w.queue_free()
	# fermeture automatique : le joueur s'éloigne à 30 m, la porte se referme et se bloque de nouveau
	ip.basculer(true, false)
	m.joueur.global_position = ip.to_global(Vector3(px, y, zp + 30.0))
	for i in 60:
		await physics_frame
	_verif(not ip.ouverte and not ip.bloc_porte.disabled, "[%s] à 30 m, la porte se referme et bloque de nouveau" % id)

func _tester_visibilite(v: Node3D) -> void:
	var ip: Interieur = v.interieur("halle")
	var j: CharacterBody3D = m.joueur
	j.set_physics_process(false)
	# dedans : visible et éclairé
	j.global_position = ip.to_global(Vector3(0, ip.sol_y + 0.2, 1.0))
	for i in 40:
		await process_frame
	var visibles := 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).visible and (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(ip.racine.visible and visibles == ip.lumieres.size() and visibles > 0, "halle : dedans, l'intérieur est visible et ses %d lumières sont allumées" % ip.lumieres.size())
	# loin : tout éteint
	j.global_position = ip.to_global(Vector3(0, 0.2, 60.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(not ip.racine.visible and visibles == 0, "halle : à 50 m, l'intérieur est masqué et toutes les lumières éteintes (%d allumées)" % visibles)
	# à 12 m : visible mais lumières éteintes (> 8 m de l'emprise)
	j.global_position = ip.to_global(Vector3(0, 0.2, ip.demi.y + 11.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(ip.racine.visible and visibles == 0, "halle : à 11 m, l'intérieur est visible (par les fenêtres) mais sans lumière locale (%d)" % visibles)
	# à 5 m : lumières allumées
	j.global_position = ip.to_global(Vector3(0, 0.2, ip.demi.y + 5.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(visibles == ip.lumieres.size(), "halle : à 5 m, les %d lumières sont allumées" % visibles)
	# budget : au plus 8 lumières locales par bâtiment
	for id in ["halle", "sigrun", "chasseurs", "grima", "forge"]:
		var n := (v.interieur(id) as Interieur).lumieres.size()
		_verif(n <= 8, "[%s] %d lumières locales (≤ 8, limite du renderer mobile)" % [id, n])

## Le forgeron vit dans sa forge : il y reste (jamais coincé dans un mur, ni sous le sol) ; les autres villageois
## ne sont dans aucun bâtiment.
func _tester_pnj(v: Node3D) -> void:
	for i in 240:
		await physics_frame
	var forge: Interieur = v.interieur("forge")
	var n := 0
	for p in get_nodes_in_group("villageois"):
		var id: String = p.donnees.get("id", "")
		for ip in v.interieurs:
			var loc: Vector3 = ip.to_local(p.global_position)
			var dans: bool = ip.dedans(loc, 0.3) and loc.y < 3.0
			if id == "forgeron" and ip == forge:
				_verif(ip.dedans(loc, 0.0) and loc.y > -0.1 and loc.y < 0.6, "forgeron dans la forge, sur le sol (x %.2f, y %.2f, z %.2f)" % [loc.x, loc.y, loc.z])
				n += 1
			elif dans:
				_verif(false, "%s est dans « %s » (x %.2f, z %.2f)" % [id, ip.nom, loc.x, loc.z])
	_verif(n == 1, "le forgeron a été trouvé")
