extends SceneTree
## Test sans fenêtre du SANG V2 (combat/sang_v2) dans scenes/test_combat.tscn :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_sang_v2.gd -- --nouvelle
## - lame du joueur : variante de shader avec le masque de sang ; le sang s'ACCUMULE coup après coup, sèche puis s'EFFACE ;
##   rien avec la magie ni avec le gore à 0 ;
## - giclée qui TACHE un ennemi voisin (dans le sens de la lame), pas un ennemi éloigné ;
## - entaille qui COULE (images successives) et GOUTTE (GouttesSang), plafond des taches par corps.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")

var s: Node3D
var echecs := 0
var _n := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _ennemi(pos: Vector3) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "guerrier"
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "test_sang_v2_%d" % _n
	d.position = pos
	d.rotation.y = atan2(-pos.x, -pos.z) + PI
	s.add_child(d)
	d.vie = 3000.0
	d.vie_max = 3000.0
	d.combat.profil.chance_blocage = 0.0
	return d

func _info(d: Node3D, dir: Vector3, extra := {}) -> Dictionary:
	var vers: Vector3 = s.joueur.global_position - d.global_position
	vers.y = 0.0
	vers = vers.normalized()
	var i := {"type": "tranchant", "point": d.global_position + Vector3(0, 1.25, 0) + vers * 0.2, "direction": dir.normalized(),
		"normale": vers, "attaque": "legere", "instant": 0.1, "charge": 0.0, "arme": "epee_metal"}
	i.merge(extra, true)
	return i

func _frames(n: int) -> void:
	for k in n:
		await physics_frame

func _lancer() -> void:
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _frames(20)
	var lame := SangLame.instance
	ok(is_instance_valid(lame) and lame.mat != null and lame.mat.shader.code.contains("sang_quantite"), "lame du joueur : variante de shader avec le sang")
	ok(lame != null and lame.mat.shader.code.contains("reflet_couleur"), "la variante garde le reflet de lame (L9)")
	ok(lame != null and is_equal_approx(lame.quantite, 0.0), "lame propre au départ")
	# trois draugrs : A frappé, B voisin à droite (sens de la lame), C loin
	var a := _ennemi(Vector3(0, 0, -1.6))
	var b := _ennemi(Vector3(0.95, 0, -1.75))
	var c := _ennemi(Vector3(-4.0, 0, -4.5))
	for e in [a, b, c]:
		e.set_physics_process(false)
	await _frames(20)
	a.recevoir_coup(5.0, s.joueur.global_position, false, _info(a, Vector3(1, -0.2, 0)))
	var q1 := lame.quantite
	ok(q1 > 0.05, "un coup qui saigne dépose du sang sur la lame (%.2f)" % q1)
	for k in 3:
		await _frames(8)
		a.recevoir_coup(5.0, s.joueur.global_position, false, _info(a, Vector3(1, -0.2, 0)))
	var q4 := lame.quantite
	ok(q4 > q1 * 2.5, "le sang s'accumule à chaque coup (%.2f → %.2f)" % [q1, q4])
	ok(float(lame.mat.get_shader_parameter("sang_quantite")) > 0.3, "le matériau reçoit la quantité (%.2f)" % float(lame.mat.get_shader_parameter("sang_quantite")))
	await _frames(40)
	ok(Plaies.nombre_taches(b.modele) >= 1, "la giclée tache le draugr voisin (%d tache(s))" % Plaies.nombre_taches(b.modele))
	ok(Plaies.nombre_taches(b.modele) <= Plaies.MAX_TACHES, "plafond des taches par corps (%d ≤ %d)" % [Plaies.nombre_taches(b.modele), Plaies.MAX_TACHES])
	ok(Plaies.nombre_taches(c.modele) == 0, "le draugr éloigné n'est pas taché")
	ok(Plaies.nombre(a.modele) + Plaies.nombre_taches(a.modele) <= 8, "au plus 8 décals sur la victime (limite Mobile)")
	# entaille qui coule et goutte
	var plaies: Array = a.modele.get_meta("plaies", [])
	var d0: Decal = plaies.back() if not plaies.is_empty() else null
	var tex0: Texture2D = d0.texture_albedo if d0 else null
	var v2 := []
	for v in 3:
		for e in Plaies.ETAPES:
			v2.append(Sang.texture_entaille(v, e))
	ok(d0 != null and v2.has(tex0) and tex0 != v2[Plaies.ETAPES - 1], "entaille v2 posée (image d'écoulement en cours)")
	var g0 := GouttesSang.lachees
	await _frames(240)
	ok(is_instance_valid(d0) and d0.texture_albedo != tex0, "l'entaille coule (image d'écoulement changée)")
	ok(GouttesSang.lachees > g0, "des gouttes tombent des plaies et de la lame (%d)" % (GouttesSang.lachees - g0))
	var im0 := Sang.texture_entaille(0, 0).get_image()
	var im5 := Sang.texture_entaille(0, Plaies.ETAPES - 1).get_image()
	ok(_opaques(im5) > _opaques(im0) + 10, "les coulures s'allongent (%d → %d texels)" % [_opaques(im0), _opaques(im5)])
	ok(_fente_identique(im0, im5), "la fente ne bouge pas d'une image à l'autre")
	# effacement : séchage puis disparition
	var qa := lame.quantite
	for k in 12:
		lame._process(1.0)
	ok(lame.sec > 0.5 and lame.quantite < qa, "le sang sèche et commence à s'effacer (sec %.2f, %.2f → %.2f)" % [lame.sec, qa, lame.quantite])
	for k in 40:
		lame._process(1.0)
	ok(lame.quantite == 0.0 and float(lame.mat.get_shader_parameter("sang_quantite")) == 0.0, "le sang s'est effacé de la lame")
	# un nouveau coup après séchage : sang frais par-dessus
	a.recevoir_coup(5.0, s.joueur.global_position, false, _info(a, Vector3(1, -0.2, 0)))
	ok(lame.quantite > 0.05 and lame.sec < 0.5, "nouveau coup : sang frais (%.2f, sec %.2f)" % [lame.quantite, lame.sec])
	lame.nettoyer()
	# magie : pas de sang sur la lame
	a.recevoir_coup(5.0, s.joueur.global_position, false, _info(a, Vector3(1, -0.2, 0), {"ecole": "destruction", "type": "feu"}))
	ok(lame.quantite == 0.0, "un sort ne salit pas la lame")
	# gore à 0 : rien
	Sang.niveau_force = 0
	var tb := Plaies.nombre_taches(b.modele)
	a.recevoir_coup(5.0, s.joueur.global_position, false, _info(a, Vector3(1, -0.2, 0)))
	await _frames(40)
	ok(lame.quantite == 0.0, "gore désactivé : lame propre")
	ok(Sang.tacher_voisins(a, a.global_position + Vector3(0, 1.2, 0), Vector3.RIGHT, 2.0, Color(0.3, 0.03, 0.02)) == 0, "gore désactivé : aucune tache sur les voisins (%d)" % tb)
	Sang.niveau_force = -1
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)

func _opaques(im: Image) -> int:
	var n := 0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.5:
				n += 1
	return n

## Les texels des lèvres et du cœur (palette « sombre ») des 14 premiers rangs sont les mêmes à toutes les étapes.
func _fente_identique(a: Image, b: Image) -> bool:
	var levre := Color(Sang.PALETTE_PLAIE["sombre"]["levre"])
	var coeur := Color(Sang.PALETTE_PLAIE["sombre"]["coeur"])
	var vus := 0
	for y in 14:
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			if ca.is_equal_approx(levre) or ca.is_equal_approx(coeur):
				vus += 1
				if not b.get_pixel(x, y).is_equal_approx(ca):
					return false
	return vus > 20
