extends SceneTree
## Test sans fenêtre du BOUCLIER (main gauche) et des transitions de la main gauche, dans scenes/test_combat.tscn
## (mannequin à 1,5 m) :
##   godot --headless --path . --script res://outils/test_bouclier.gd -- --nouvelle
## Données (bouclier.tres → modèle, cône, recul, posture), affichage (repos bas à gauche, centre libre, garde levée devant),
## garde au bouclier (bloc, cône large, coût, recul, geste d'impact), parade parfaite (coup de bouclier, posture de
## l'attaquant), garde brisée réutilisée, épée : attaque garde baissée, combo, latence identique ; transitions sans saut
## (torche ↔ sort ↔ bouclier ↔ vide, sort ↔ épée à droite) ; sauvegarde. Le jeu tourne normalement (images réelles,
## --fixed-fps 60 dans tous_les_tests.sh) : les os des bras (IK) sont à jour à chaque image.

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: Node
var cam: Camera3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _reset() -> void:
	mains.entrees.forcer_garde(0.0)
	Input.action_release("main_gauche")
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	j.mana = j.mana_max
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	j._recul = Vector3.ZERO
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	s.placer_joueur(Vector3(0, 0, s.POS_MANNEQUIN.z + 1.5), 0.0)
	await _images(30)

## Coin du bouclier vu à l'écran (0..1) : 12 points du cerclage (repère du modèle : face en +X, disque dans le plan YZ).
func _cadre_bouclier() -> Rect2:
	var b: Node3D = mains._modele_gauche
	var vp := root.get_viewport().get_visible_rect().size
	var r := Rect2()
	for i in 12:
		var a := TAU * i / 12.0
		var p := b.global_transform * Vector3(0.034, 0.34 * cos(a), 0.34 * sin(a))
		if cam.is_position_behind(p):
			continue
		var e := (cam.unproject_position(p) / vp).clamp(Vector2(-0.2, -0.2), Vector2(1.2, 1.2))
		r = Rect2(e, Vector2.ZERO) if i == 0 else r.expand(e)
	return r

func _visible_ecran(r: Rect2) -> float:
	return r.intersection(Rect2(0, 0, 1, 1)).get_area()

func _centre(r: Rect2) -> float:
	var c := Rect2(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
	return r.intersection(c).get_area() / c.get_area() if r.intersects(c) else 0.0

## Position de la main (os, après IK) dans le repère caméra.
func _main(cote: String) -> Vector3:
	var acc: Node3D = mains._accroche_g if cote == "g" else mains._accroche_d
	return cam.global_transform.affine_inverse() * acc.global_position

## Plus grand déplacement d'une main entre deux images pendant `n` images (m).
func _saut_max(cote: String, n: int) -> float:
	var prec := _main(cote)
	var mx := 0.0
	for i in n:
		await process_frame
		var p := _main(cote)
		mx = maxf(mx, p.distance_to(prec))
		prec = p
	return mx

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	cam = j.camera
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _images(20)
	var eq: EquipementMains = magie.eq

	print("-- données")
	var b: DonneesArme = load("res://data/armes/bouclier.tres")
	_verif(b.id == "bouclier" and b.categorie == DonneesArme.Categorie.BOUCLIER and ResourceLoader.exists(b.modele), "bouclier.tres : catégorie BOUCLIER, modèle %s" % b.modele)
	_verif(b.angle_garde > DefenseJoueur.ANGLE_DEFENSE and b.recul_garde > 0.0 and b.posture_parade > Equipement.EPEE_METAL.posture_parade, "bouclier : cône %.0f° (épée %.0f°), recul %.1f m/s, posture parée %.0f %% (épée %.0f %%)" % [b.angle_garde, Equipement.EPEE_METAL.angle_garde, b.recul_garde, b.posture_parade * 100, Equipement.EPEE_METAL.posture_parade * 100])
	_verif(EquipementMains.BOUCLIER == b and EquipementMains.categorie_de(b) == "bouclier", "EquipementMains expose le bouclier (même ressource, catégorie « bouclier »)")

	print("-- affichage")
	await _reset()
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "bouclier")
	await _images(50)
	var mod: Node3D = mains._modele_gauche
	var tris := 0
	var mats := {}
	if mod != null:
		for mi: MeshInstance3D in mod.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(k)
				mats[mi.mesh.surface_get_material(k).resource_name] = m is ShaderMaterial
				tris += mi.mesh.surface_get_array_index_len(k) / 3
	_verif(mod != null and mod.visible and eq.categorie("gauche") == "bouclier", "bouclier_nordique.glb installé au poing gauche et visible")
	_verif(mats.size() == 4 and not mats.values().has(false), "matériaux PS1 posés par nom : %s (%d triangles)" % [mats.keys(), tris])
	_verif(magie._bouclier == mod, "MainSort._bouclier = le vrai bouclier (ancienne interface)")
	var r_repos := _cadre_bouclier()
	var g_repos := _main("g")
	_verif(r_repos.position.x < 0.2 and r_repos.end.y > 0.95 and r_repos.get_center().x < 0.3, "repos : bouclier en bas à gauche (cadre x %.2f-%.2f, y %.2f-%.2f)" % [r_repos.position.x, r_repos.end.x, r_repos.position.y, r_repos.end.y])
	_verif(_centre(r_repos) <= 0.0 and _visible_ecran(r_repos) <= 0.15, "repos : tiers central libre (%.1f %%), cadre visible ≤ 15 %% de l'écran (%.1f %%)" % [_centre(r_repos) * 100, _visible_ecran(r_repos) * 100])

	print("-- garde au bouclier")
	mains.entrees.forcer_garde(5.0)
	await _images(30)
	var r_garde := _cadre_bouclier()
	var g_garde := _main("g")
	_verif(mains.bloque and mains.garde_bouclier(), "clic droit tenu : garde levée au bouclier (état %s)" % mains.combat.nom())
	_verif(g_garde.y > g_repos.y + 0.05 and g_garde.x > g_repos.x + 0.1, "le bouclier se lève devant (main %.2f,%.2f → %.2f,%.2f)" % [g_repos.x, g_repos.y, g_garde.x, g_garde.y])
	_verif(r_garde.get_center().x < 0.5 and r_garde.position.y > 0.3, "garde : bouclier à gauche du centre, bord haut sous le haut du tiers central (cadre x %.2f-%.2f, y %.2f-%.2f)" % [r_garde.position.x, r_garde.end.x, r_garde.position.y, r_garde.end.y])
	_verif(mains.anim.clip == "repos", "garde au bouclier : l'épée reste au repos (clip %s, pas « garde »)" % mains.anim.clip)
	var red: float = j.competences.reduction_parade()
	var vie0: float = j.vie
	var vig0: float = j.vigueur
	var devant := j.global_position + Vector3(0, 0, -1.5)
	var r := String(j.recevoir_coup(20.0, devant))
	_verif(r == "bloque" and absf(vie0 - j.vie - 20.0 * (1.0 - b.reduction_garde) * red) < 0.01, "coup de face bloqué au bouclier : %.2f dégâts passent (95 %% absorbés)" % (vie0 - j.vie))
	_verif(absf(vig0 - j.vigueur - 20.0 * DefenseJoueur.COUT_BLOCAGE * red * b.cout_garde) < 0.01, "coût d'endurance du bloc : %.1f (× %.1f du bouclier)" % [vig0 - j.vigueur, b.cout_garde])
	_verif(j._recul.length() > b.recul_garde * 0.5 and j._recul.z > 0.0, "recul du joueur à l'impact (%.2f m/s, vers l'arrière)" % j._recul.length())
	_verif(int(mains.bouclier.joues.get("impact", 0)) == 1, "geste d'impact du bouclier joué")
	var g_imp := 0.0
	for i in 8:
		await process_frame
		g_imp = maxf(g_imp, g_garde.distance_to(_main("g")))
	_verif(g_imp > 0.03, "le bouclier encaisse (recule de %.2f m) puis revient" % g_imp)
	await _images(20)
	for ang in [75.0, 80.0, 100.0]:
		var dir := Vector3(sin(deg_to_rad(ang)), 0, -cos(deg_to_rad(ang)))
		r = String(j.recevoir_coup(5.0, j.global_position + dir * 1.5))
		var attendu := "bloque" if ang < b.angle_garde * 0.5 else "touche"
		_verif(r == attendu, "coup à %.0f° : %s (cône du bouclier %.0f°, épée %.0f°)" % [ang, r, b.angle_garde, DefenseJoueur.ANGLE_DEFENSE])
		j.vie = j.vie_max
		j.vigueur = j.vigueur_max
		await _images(10)

	print("-- parade parfaite : coup de bouclier")
	await _reset()
	mains.entrees.forcer_garde(5.0)
	await _images(4)
	var mc: CombatEnnemi = s.mannequin.combat
	var post0: float = mc.ratio_posture()
	r = String(j.recevoir_coup(20.0, devant))
	if r == "parade":
		mc.subir_parade()   # ce que font les ennemis sur un retour « parade »
	_verif(r == "parade" and j.vie >= j.vie_max - 0.01, "garde levée juste avant l'impact : parade parfaite (%s)" % r)
	_verif(int(mains.bouclier.joues.get("coup", 0)) == 1 and mains.defense.contre > 0.0, "coup de bouclier joué, fenêtre de contre-attaque ouverte (%.2f s)" % mains.defense.contre)
	_verif(post0 - mc.ratio_posture() >= b.posture_parade - 0.01 or mc.etourdi > 0.0, "l'attaquant est déséquilibré : posture %d %% → %d %% (épée : −45 %%)%s" % [roundi(post0 * 100), roundi(mc.ratio_posture() * 100), ", étourdi" if mc.etourdi > 0.0 else ""])
	_verif(is_equal_approx(CombatEnnemi.part_parade, 0.45), "part de posture remise à celle de l'épée après la parade")
	var g0 := _main("g")
	var avance := 0.0
	for i in 10:
		await process_frame
		avance = maxf(avance, g0.z - _main("g").z)
	_verif(avance > 0.04, "le bouclier part en avant (%.2f m)" % avance)

	print("-- garde brisée (réutilisée)")
	await _reset()
	mains.entrees.forcer_garde(5.0)
	await _images(25)
	j.vigueur = 1.0
	r = String(j.recevoir_coup(30.0, devant))
	await _images(2)
	_verif(r == "touche" and mains._titube_garde and mains._brisee_bouclier and mains.combat.etat == EtatCombat.DESEQUILIBRE, "endurance vide : garde brisée au bouclier, le joueur titube (%s, %s)" % [r, mains.combat.nom()])
	_verif(int(mains.bouclier.joues.get("brisee", 0)) == 1 and mains.anim.clip != "garde_brisee", "le bouclier est rabattu (l'épée ne joue pas « garde_brisee » : clip %s)" % mains.anim.clip)
	await _images(30)
	_verif(not mains.bloque and mains.defense.brisee > 0.0, "garde impossible un moment (%.2f s)" % mains.defense.brisee)
	await _images(60)
	_verif(mains.bloque, "puis la garde revient (bouton tenu)")

	print("-- épée avec bouclier")
	await _reset()
	var n0: int = s.mannequin.coups.size()
	mains.entrees.appuyer()
	await _images(3)
	mains.entrees.relacher()
	await _images(50)
	_verif(s.mannequin.coups.size() - n0 == 1, "garde baissée : le coup d'épée part et touche (%d)" % (s.mannequin.coups.size() - n0))
	mains.entrees.forcer_garde(5.0)
	await _images(20)
	n0 = s.mannequin.coups.size()
	mains.entrees.appuyer()
	await _images(3)
	mains.entrees.relacher()
	await _images(30)
	_verif(not mains.combat.attaque() and s.mannequin.coups.size() == n0, "garde levée : pas d'attaque (hors contre-attaque)")
	mains.entrees.forcer_garde(0.0)
	await _reset()
	# combo : trois coups enchaînés dans la fenêtre
	var gestes: Array = []
	for k in 3:
		mains.entrees.appuyer()
		await _images(2)
		mains.entrees.relacher()
		gestes.append(mains._geste_nom)
		while mains.combat.etat != EtatCombat.RECUPERATION:
			await process_frame
		await _images(6)
	_verif(gestes.size() == 3 and gestes[0] != gestes[1] and gestes[1] != gestes[2], "combo normal avec le bouclier : %s" % [gestes])
	await _images(60)
	# latence : mêmes durées de préparation et départ dans l'image de l'appui, torche ou bouclier
	var prep := {}
	var depart := {}
	for g in ["torche", "bouclier"]:
		await _reset()
		magie.equiper("gauche", g)
		await _images(40)
		mains.entrees.appuyer()
		await process_frame
		prep[g] = mains._duree_prep + mains._duree_tenue
		depart[g] = mains.combat.attaque() and mains._t_geste > 0.0
		mains.entrees.relacher()
		await _images(60)
	_verif(is_equal_approx(prep["torche"], prep["bouclier"]) and depart["bouclier"], "latence des coups inchangée : préparation %.3f s (torche %.3f s), le coup avance dès l'image de l'appui" % [prep["bouclier"], prep["torche"]])

	print("-- transitions de la main gauche (plus grand déplacement d'une image à l'autre, 60 i/s)")
	await _reset()
	magie.equiper("gauche", "torche")
	await _images(40)
	var sauts := {}
	var suite := [["torche → sort", "gauche", "jet_flammes"], ["sort → bouclier", "gauche", "bouclier"], ["bouclier → sort", "gauche", "eclat_glace"],
		["sort → torche", "gauche", "torche"], ["torche → bouclier", "gauche", "bouclier"], ["bouclier → torche", "gauche", "torche"]]
	for c in suite:
		magie.equiper(c[1], c[2])
		sauts[c[0]] = await _saut_max("g", 45)
	mains.equipement.basculer_gauche()
	sauts["torche rangée (T)"] = await _saut_max("g", 45)
	mains.equipement.basculer_gauche()
	sauts["torche ressortie (T)"] = await _saut_max("g", 45)
	magie.equiper("droite", "arc_electrique")
	sauts["droite : épée → sort"] = await _saut_max("d", 45)
	magie.equiper("droite", "epee")
	sauts["droite : sort → épée"] = await _saut_max("d", 45)
	var pire := 0.0
	for k in sauts:
		print("SAUT %-24s %.3f m" % [k, sauts[k]])
		pire = maxf(pire, sauts[k])
	_verif(pire < 0.09, "aucun saut de main aux changements d'objet (pire %.3f m en une image, seuil 0,09)" % pire)

	print("-- main gauche qui incante : repos bas à gauche")
	await _reset()
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "jet_flammes")
	await _images(50)
	var vp := root.get_viewport().get_visible_rect().size
	var paume: Node3D = magie.paume["gauche"]
	var e := cam.unproject_position(paume.global_position) / vp
	var e_d := cam.unproject_position(mains._accroche_d.global_position) / vp
	_verif(e.x < 0.33 and e.y > 0.66, "repos du sort : paume dans le tiers bas gauche (%.2f, %.2f), main droite en (%.2f, %.2f)" % [e.x, e.y, e_d.x, e_d.y])
	_verif(cam.global_position.distance_to(paume.global_position) > 0.25 and paume.global_position.distance_to(mains._accroche_d.global_position) > 0.3, "ni la caméra ni la main droite traversées (%.2f m, %.2f m)" % [cam.global_position.distance_to(paume.global_position), paume.global_position.distance_to(mains._accroche_d.global_position)])

	print("-- sauvegarde")
	magie.equiper("gauche", "bouclier")
	await _images(5)
	var d: Dictionary = JSON.parse_string(JSON.stringify(magie.exporter()))
	magie.equiper("gauche", "torche")
	await _images(5)
	magie.importer(d)
	await _images(20)
	_verif(eq.categorie("gauche") == "bouclier" and is_instance_valid(mains._modele_gauche) and mains._modele_gauche.visible, "sauvegarde : le bouclier revient au bras gauche (%s)" % d.get("gauche"))

	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
