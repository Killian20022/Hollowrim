extends SceneTree
## Test headless de DÉTERMINISME de la génération (multijoueur : tous les joueurs doivent voir le même monde) :
##   godot --headless --path . --script res://outils/test_determinisme_monde.gd
## Génère DEUX fois les mêmes éléments en changeant la graine du RNG GLOBAL entre les deux (un randf()/randi() global dans la
## génération ferait diverger les hachages) : textures de la palette, villageois (cap, allure, étape de métier), gardes du village.
## Imprime « DETERMINISME OK » ou « DETERMINISME ECHEC » ; code de sortie 0 / 1.

class FauxJoueur extends CharacterBody3D:
	var en_dialogue := false
	var mort := false
	var camera: Camera3D

var _ok := true

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _hash_image(img: Image) -> int:
	return hash(img.get_data())

func _hash_palette() -> int:
	var h := 0
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1234
	h = hash([h, _hash_image(Palette.texture(64, Palette.NEIGE, 3, 1, 0.12, rng1).get_image())])
	h = hash([h, _hash_image(Palette.texture_terre().get_image())])
	h = hash([h, _hash_image(Palette.texture_neige_pietinee().get_image())])
	h = hash([h, _hash_image(Palette.texture_aiguilles_sol().get_image())])
	h = hash([h, _hash_image(Palette.texture_mousse().get_image())])
	h = hash([h, _hash_image(Palette.image(32, Palette.ACIER, 4, hash("acier") & 0xff, 0.3))])   # grain sans RNG fourni
	return h

## Hachage de l'état de génération des habitants (rotation, allure, étape de métier, minuteries tirées à la naissance).
var _dernier: Array = []

func _hash_habitants() -> int:
	var monde := Node3D.new()
	root.add_child(monde)
	var j := FauxJoueur.new()
	j.camera = Camera3D.new()
	j.add_child(j.camera)
	monde.add_child(j)
	var etat: Array = []
	var liste: Array = load("res://scripts/villageois.gd").charger()
	for i in liste.size():
		var p: CharacterBody3D = load("res://scripts/villageois.gd").new()
		p.donnees = liste[i]
		p.joueur = j
		p.points = [Vector3(i * 3.0 - 6.0, 0.1, -10), Vector3(i * 3.0 - 6.0, 0.1, -16)]
		p.position = p.points[0]
		monde.add_child(p)
		etat.append([str(liste[i].get("id", i)), p.rotation.y, p._var, p._marche, p._prochaine_promenade, p._delai_interpelle, p._delai_variete, p._m_i, p._m_t])
	var n := liste.size()
	_dernier = etat
	monde.free()
	return hash(etat) if n > 0 else -1

func _tester() -> void:
	seed(111)
	var a := _hash_palette()
	seed(999)
	var b := _hash_palette()
	_verif(a == b, "textures de la palette identiques (hachage %d)" % a)
	seed(111)
	var h1 := _hash_habitants()
	var e1 := _dernier
	await process_frame
	seed(999)
	var h2 := _hash_habitants()
	if h1 != h2:
		for i in e1.size():
			if e1[i] != _dernier[i]:
				print("  divergence : ", e1[i], " / ", _dernier[i])
	_verif(h1 != -1, "des villageois ont été générés")
	_verif(h1 == h2, "villageois identiques d'une génération à l'autre (hachages %d / %d)" % [h1, h2])
	print("DETERMINISME " + ("OK" if _ok else "ECHEC"))
	quit(0 if _ok else 1)
