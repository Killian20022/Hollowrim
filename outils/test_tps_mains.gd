extends SceneTree
## Test sans fenêtre des MAINS DU CORPS à la 3e personne (scripts/corps_mains_tps.gd, branche tps/mains_sorts) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_tps_mains.gd -- --nouvelle
## - torche du corps (modèle, flamme, lumière) visible SEULEMENT si la main gauche tient la torche (pas avec un sort ni un bouclier) ;
## - arme du corps = copie du modèle réellement équipé (mêmes maillages), absente avec un sort ou la main nue ; épée fixe d'origine cachée ;
## - bouclier du corps présent avec le bouclier ;
## - 3e personne : auras / jets / projectiles partent des paumes du CORPS ; 1re personne : des mains FPS ;
## - gestes : la main qui incante quitte sa pose de repos (charge : main reculée ; jet : bras tendu devant, à hauteur d'épaule ; lancer :
##   bras projeté), sans saut d'une image à l'autre ; l'autre bras n'est pas touché ;
## - arme à deux mains : main gauche sur la poignée ;
## - caméra : épaule droite contre un mur, la caméra reste devant le mur (le bras du ressort part du centre de la tête) ;
## - visée à la 3e personne : rayon de la caméra à l'épaule (centre de l'écran).

const DT := 1.0 / 60.0
## Saut maximal admis de la main du corps entre deux images à 60 i/s (m).
const SAUT_MAX := 0.12

var _ok := true
var _n := 0
var s: Node
var j: CharacterBody3D
var mains: Node3D
var mg: MainSort
var corps: Node3D
var tps: CorpsMainsTps
var sq: Skeleton3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		j.mana = j.mana_max
		await process_frame

## Poses APRÈS les modificateurs (couche des bras, IK) : lues dans le signal skeleton_updated (hors de ce signal,
## get_bone_global_pose rend la pose de l'AnimationPlayer seule).
var _mains_monde := {"gauche": Vector3.ZERO, "droite": Vector3.ZERO}

func _releve() -> void:
	for m in ["gauche", "droite"]:
		var i := sq.find_bone("hand_l" if m == "gauche" else "hand_r")
		_mains_monde[m] = sq.global_transform * sq.get_bone_global_pose(i).origin

## Main du corps dans le repère du joueur (x droite, y haut, -z devant).
func _main(m: String) -> Vector3:
	return j.global_transform.affine_inverse() * Vector3(_mains_monde[m])

func _equiper(m: String, id: String) -> void:
	var r: String = mg.equiper(m, id)
	if r != "":
		print("REFUS ", m, " ", id, " : ", r)

func _tester() -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	mg = mains.magie
	mg.eq.apprendre_tout()
	corps = j.corps
	tps = corps.mains_tps
	sq = tps.sq
	sq.skeleton_updated.connect(_releve)
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, 0.0)
	j.basculer_vue(true)
	_verif(tps != null and sq != null, "corps_mains_tps installé sur le corps")
	await _images(20)
	await _objets()
	await _effets()
	await _gestes()
	await _deux_mains()
	await _camera_mur()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

func _objets() -> void:
	_equiper("droite", "epee")
	_equiper("gauche", "torche")
	await _images(10)
	_verif(corps.pivot_torche.visible and corps.lumiere.visible, "torche en main gauche : torche et lumière du corps visibles")
	for id in ["jet_flammes", "bouclier", "vide"]:
		_equiper("gauche", id)
		await _images(6)
		_verif(not corps.pivot_torche.visible and not corps.lumiere.visible, "main gauche = %s : plus de torche ni de lumière sur le corps (mains.torche_sortie = %s)" % [id, mains.torche_sortie])
	_equiper("gauche", "bouclier")
	await _images(4)
	var b: Node3D = tps.get("_objet_g")
	_verif(b != null and b.is_visible_in_tree(), "bouclier en main gauche : bouclier sur le corps")
	_equiper("gauche", "vide")
	await _images(4)
	_verif(tps.get("_objet_g") == null, "main gauche nue : plus de bouclier")
	var a := tps.arme_tenue()
	var src: Node3D = mains.get("_modele_arme_d")
	var n_src := src.find_children("*", "MeshInstance3D", true, false).size() if src != null else -1
	var n_a := a.find_children("*", "MeshInstance3D", true, false).size() if a != null else -2
	_verif(a != null and n_a == n_src, "épée : le corps tient le modèle équipé (%d maillages, FPS %d)" % [n_a, n_src])
	_verif(not corps.arme_corps.visible, "épée fixe d'origine (epee_nordique.glb) cachée")
	var mesh_a := (a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh if a != null else null
	var mesh_s := (src.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh if src != null else null
	_verif(mesh_a != null and mesh_a == mesh_s, "même maillage que l'arme de la 1re personne (%s)" % [mains.arme.id])
	_equiper("droite", "boule_feu")
	await _images(6)
	_verif(tps.arme_tenue() == null, "sort en main droite : plus d'arme sur le corps")
	_equiper("droite", "vide")
	await _images(6)
	_verif(tps.arme_tenue() == null and tps.clip_repos() == "Idle", "main droite nue : pas d'arme, attente sans garde d'épée")
	_equiper("droite", "epee")
	await _images(6)
	_verif(tps.clip_repos() == "Sword_Idle", "épée : attente en garde (Sword_Idle)")

func _effets() -> void:
	_equiper("gauche", "jet_flammes")
	await _images(4)
	_verif(mg._p("gauche") == tps.paume["gauche"], "3e personne : effets de la main gauche depuis la paume du corps")
	j.basculer_vue(false)
	await _images(2)
	_verif(mg._p("gauche") == mg.paume["gauche"], "1re personne : effets depuis la paume FPS")
	j.basculer_vue(true)
	await _images(2)
	_verif(mg._p("droite") == tps.paume["droite"], "retour 3e personne : paume du corps (main droite aussi)")
	# la paume suit la main du corps
	var d: float = (tps.paume["gauche"] as Node3D).global_position.distance_to(_mains_monde["gauche"])
	_verif(d < 0.15, "paume du corps à %.3f m de l'os de la main gauche" % d)

## Suit la main `m` pendant `n` images : [pire saut, position finale].
func _suivre(m: String, n: int) -> Array:
	var prec := _main(m)
	var pire := 0.0
	for i in n:
		j.mana = j.mana_max
		await process_frame
		var p := _main(m)
		if p.distance_to(prec) > SAUT_MAX:
			print("  saut image %d : %s -> %s (%s)" % [i, prec.snappedf(0.01), p.snappedf(0.01), mg.inc[m].nom()])
		pire = maxf(pire, p.distance_to(prec))
		prec = p
	return [pire, prec]

func _gestes() -> void:
	_equiper("droite", "epee")
	_equiper("gauche", "jet_flammes")
	await _images(40)
	var repos := _main("gauche")
	var droite_repos := _main("droite")
	print("  main gauche au repos (sort tenu) : ", repos.snappedf(0.01))
	# jet continu : bras tendu devant à hauteur d'épaule
	mg.appuyer("gauche")
	var r := await _suivre("gauche", 60)
	var jet: Vector3 = r[1]
	print("  main gauche en jet : ", jet.snappedf(0.01))
	_verif(jet.z < -0.55 and jet.z < repos.z - 0.08 and jet.y > 1.15, "jet : bras tendu devant (z %.2f -> %.2f), à hauteur d'épaule (y %.2f)" % [repos.z, jet.z, jet.y])
	_verif(float(r[0]) < SAUT_MAX, "jet : pas de saut de la main (pire %.3f m / image)" % r[0])
	_verif(_main("droite").distance_to(droite_repos) < 0.12, "jet de la main gauche : le bras droit (épée) ne bouge pas (%.3f m)" % _main("droite").distance_to(droite_repos))
	mg.relacher("gauche")
	r = await _suivre("gauche", 60)
	_verif(float(r[0]) < SAUT_MAX and (r[1] as Vector3).distance_to(repos) < 0.12, "fin du jet : retour à la pose de repos sans saut (%.3f m de la pose)" % (r[1] as Vector3).distance_to(repos))
	# charge puis lancer
	_equiper("gauche", "boule_feu")
	await _images(30)
	repos = _main("gauche")
	mg.appuyer("gauche")
	r = await _suivre("gauche", 60)
	var charge: Vector3 = r[1]
	print("  main gauche en charge : ", charge.snappedf(0.01))
	_verif(charge.z > repos.z + 0.1, "charge : la main recule paume ouverte (z %.2f -> %.2f)" % [repos.z, charge.z])
	mg.relacher("gauche")
	var plus_loin := charge.z
	var prec := _main("gauche")
	var pire := 0.0
	for i in 30:
		await process_frame
		var p := _main("gauche")
		pire = maxf(pire, p.distance_to(prec))
		prec = p
		plus_loin = minf(plus_loin, p.z)
	_verif(plus_loin < charge.z - 0.4, "lancer : bras projeté vers l'avant (z %.2f -> %.2f)" % [charge.z, plus_loin])
	_verif(pire < 0.2, "lancer : geste vif mais continu (pire %.3f m / image)" % pire)
	await _images(60)
	# main droite (miroir) avec la torche à gauche
	_equiper("gauche", "torche")
	_equiper("droite", "arc_electrique")
	await _images(40)
	var rd := _main("droite")
	mg.appuyer("droite")
	r = await _suivre("droite", 60)
	_verif((r[1] as Vector3).z < -0.55 and (r[1] as Vector3).y > 1.15, "main droite : jet bras droit tendu (z %.2f -> %.2f)" % [rd.z, (r[1] as Vector3).z])
	_verif(corps.pivot_torche.visible, "sort à droite : la torche reste en main gauche")
	mg.relacher("droite")
	await _images(30)

func _deux_mains() -> void:
	_equiper("gauche", "vide")
	_equiper("droite", "claymore_longue")
	await _images(30)
	_verif(tps.arme_tenue() != null, "claymore : arme sur le corps")
	var cible: Node3D = tps.get("_cible_g")
	var d := cible.global_position.distance_to(_mains_monde["gauche"])
	print("  2 mains : cible ", (j.global_transform.affine_inverse() * cible.global_position).snappedf(0.01), " main g ", _main("gauche").snappedf(0.01), " main d ", _main("droite").snappedf(0.01), " ik ", tps.get("_ik_g").active)
	_verif(d < 0.08, "arme à deux mains : main gauche sur la poignée (%.3f m)" % d)
	_verif(not corps.pivot_torche.visible, "arme à deux mains : pas de torche")

func _camera_mur() -> void:
	# mur de test_combat : face tournée vers +X en x = -3,05 (z de -0,5 à 2,5) ; joueur tourné vers +Z (lacet 180°) : le mur est à sa droite
	s.placer_joueur(Vector3(-2.72, 0.0, 1.0), 180.0, 0.0)
	j.camera_tp.recaler()
	await _images(20)
	var c: Vector3 = j.camera_tp.camera.global_position
	_verif(c.x > -3.03, "caméra, épaule droite contre un mur : devant le mur (x caméra %.2f, face du mur -3,05)" % c.x)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, 0.0)
	j.camera_tp.recaler()
	await _images(10)
	var v: Array = mg._vue()
	var cam: Camera3D = j.camera_tp.camera
	var avant := -cam.global_transform.basis.z
	_verif((v[1] as Vector3).distance_to(avant) < 0.01 and (v[0] as Vector3).distance_to(j.camera.global_position) < 0.7, "visée 3e personne : axe de la caméra à l'épaule, œil près de la tête (%.2f m)" % (v[0] as Vector3).distance_to(j.camera.global_position))
