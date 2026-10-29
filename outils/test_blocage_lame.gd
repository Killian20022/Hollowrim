extends SceneTree
## Test sans fenêtre : « parfois je ne peux pas donner de coup d'épée dans un endroit pas si restreint » (retour du 2026-10-29
## soir, references/combat_epee/prompt_coups_gore_2026-10-29.md). Les 4 coups validés (combo diag_dg → revers_gd → estoc_combo,
## puissant « lourd ») dans des lieux étroits bâtis à côté de scenes/test_combat.tscn, mannequin à 1,5 m devant :
##   couloir      couloir de crypte de 2,2 m (murs à ±1,1 m), joueur au milieu, regard dans l'axe
##   pres_mur_d   même couloir, joueur à 0,4 m du mur de droite ; pres_mur_g : à 0,4 m du mur de gauche
##   urnes        2 urnes + 1 tonneau CASSABLES (CrypteDecor, calque 64) entre le joueur et le mannequin
##   decor        petits objets de décor NON cassables (urnes fusionnées au décor, caisse basse, banc) dans le MÊME corps que
##                les murs (comme le décor de la crypte, fusionné par cases de 8 m)
##   regard_bas   couloir, regard baissé de 35° : la lame passe près du sol
##   embrasure    porte de 1,2 m à 0,8 m devant (chambranles de chaque côté), mannequin derrière
## Avancée sur l'armé (AccompagnementCoup, jeu en temps normal) : 0,25 à 0,7 m en terrain libre selon le coup ; face au mur à
## 0,6 m, le joueur ne le traverse pas (move_and_slide) ; devant un mannequin à 1,4 m, il s'arrête à ~0,9 m de lui.
## Attendu (comportement « Skyrim ») : le coup part TOUJOURS, ne rebondit pas, ne s'arrête pas, touche le mannequin ; les cassables
## balayés sont brisés. Contrôle : face_mur (mur plein à 1 m, dans l'axe) : la lame rebondit, mais à MI-COURSE (jamais au départ).
##   godot --headless --path . --script res://outils/test_blocage_lame.gd -- --nouvelle
const SCENE := preload("res://scenes/test_combat.tscn")
const GESTES := ["diag_dg", "revers_gd", "estoc_combo", "lourd"]
const ORIGINE := Vector3(-12.0, 0.0, 6.0)     # loin du mannequin, du mur et de la zone de collisions de la scène
const LIEUX := ["couloir", "pres_mur_d", "pres_mur_g", "urnes", "decor", "regard_bas", "embrasure", "face_mur"]

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _lieu: Node3D
var _cible: StaticBody3D
var _cassables: Array = []

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _boite(corps: StaticBody3D, centre: Vector3, taille: Vector3) -> void:
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	f.shape = bs
	f.position = centre
	corps.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.position = centre
	corps.add_child(mi)

## Bâtit le lieu (repère : joueur à l'origine du lieu, regard vers -Z).
func _batir(nom: String) -> void:
	if _lieu != null:
		_lieu.free()
	_cassables.clear()
	_lieu = Node3D.new()
	_lieu.position = ORIGINE
	s.add_child(_lieu)
	var corps := StaticBody3D.new()     # décor fusionné : murs ET petits objets dans le même corps (calque 1)
	_lieu.add_child(corps)
	if nom != "face_mur" and nom != "embrasure":
		_boite(corps, Vector3(-1.1 - 0.15, 1.5, -2.0), Vector3(0.3, 3.0, 9.0))
		_boite(corps, Vector3(1.1 + 0.15, 1.5, -2.0), Vector3(0.3, 3.0, 9.0))
		_boite(corps, Vector3(0, 3.0 + 0.15, -2.0), Vector3(2.8, 0.3, 9.0))   # voûte basse (3 m)
	match nom:
		"face_mur":
			_boite(corps, Vector3(0, 1.5, -1.0 - 0.15), Vector3(4.0, 3.0, 0.3))
		"embrasure":
			_boite(corps, Vector3(-0.6 - 0.75, 1.5, -0.8), Vector3(1.5, 3.0, 0.3))
			_boite(corps, Vector3(0.6 + 0.75, 1.5, -0.8), Vector3(1.5, 3.0, 0.3))
			_boite(corps, Vector3(0, 2.6, -0.8), Vector3(1.2, 0.8, 0.3))   # linteau (porte de 2,2 m)
		"decor":
			_boite(corps, Vector3(0.5, 0.35, -1.1), Vector3(0.45, 0.7, 0.45))    # urne / caisse basse (non cassable)
			_boite(corps, Vector3(-0.45, 0.3, -1.15), Vector3(0.35, 0.6, 0.35))  # urne
			_boite(corps, Vector3(-0.75, 0.45, -1.4), Vector3(0.5, 0.9, 1.2))     # banc / sarcophage bas contre le mur
		"urnes":
			var racine := Node3D.new()
			_lieu.add_child(racine)
			var dc := StaticBody3D.new()
			racine.add_child(dc)
			var d := CrypteDecor.new(racine, dc)
			d.cass_actif = true
			d.urne(Vector3(0.4, 0.0, -1.15), 1.3)
			d.urne(Vector3(-0.45, 0.0, -1.2), 1.2)
			d.tonneau(Vector3(0.7, 0.0, -1.45), 1.0)
			d.finir()
			for c in racine.find_children("*", "Cassable", true, false):
				_cassables.append(c)
	await physics_frame
	await physics_frame

func _placer(nom: String) -> void:
	var x: float = {"pres_mur_d": 1.1 - 0.4, "pres_mur_g": -1.1 + 0.4}.get(nom, 0.0)
	# urnes : regard un peu baissé (comme quand on vise une urne posée au sol)
	s.placer_joueur(ORIGINE + Vector3(x, 0, 0), 0.0, {"regard_bas": -35.0, "urnes": -20.0}.get(nom, 0.0))
	# mannequin : 1,5 m devant le joueur (2 m derrière la porte de l'embrasure) ; derrière le mur plein, il ne doit rien recevoir
	_cible.global_position = ORIGINE + Vector3(x, 0, -2.0 if nom in ["embrasure", "face_mur"] else -1.5)
	_cible.coups.clear()
	var mc: CombatEnnemi = _cible.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	j.vigueur = j.vigueur_max
	j.secousse = 0.0
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._souris_recente = Vector2.ZERO
	mains.defense = DefenseJoueur.new()
	for i in 30:
		mains.avancer(1.0 / 60.0)
	await physics_frame
	await physics_frame

## Un coup du geste (60 i/s). Renvoie {rebond, arret, issue, touches, frac (instant de l'arrêt / durée de la phase active),
## casses}.
func _coup(geste: String) -> Dictionary:
	var dt := 1.0 / 60.0
	var lourd := geste == "lourd"
	mains.entrees.appuyer()
	var tenu := true
	var t := 0.0
	var rebond := false
	var arret := false
	var frac := -1.0
	for k in 70:
		if tenu and t >= (0.6 if lourd else 0.05) - 1e-9:
			mains.entrees.relacher()
			tenu = false
		mains.avancer(dt)
		if k == 0 and not lourd and mains._geste_nom != geste:
			mains._geste_nom = geste
			mains._preparer_geste(false)
		if lourd and mains.combat.etat == EtatCombat.CHARGE_LOURDE:
			mains._lourd_nom = geste
		if mains._actif_lance and mains.trace.arretee and not arret:   # (avant la phase active : état du coup précédent)
			arret = true
			frac = mains._instant_impact / maxf(mains._duree_active, 1e-4)
		rebond = rebond or mains.combat.etat == EtatCombat.DESEQUILIBRE
		t += dt
	var casses := 0
	for c in _cassables:
		if c.est_casse():
			casses += 1
	return {"rebond": rebond, "arret": arret, "issue": mains._issue_arret, "touches": _cible.coups.size(), "frac": frac, "casses": casses}

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	ButinTables.reinitialiser()
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	_cible = s.mannequin
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var bilan := {}
	for lieu in LIEUX:
		print("-- ", lieu)
		for g in GESTES:
			await _batir(lieu)
			await _placer(lieu)
			var r := await _coup(g)
			bilan["%s/%s" % [lieu, g]] = r
			print("CAS %-11s %-12s rebond %-3s arrêt %-3s (%s, à %3d %% de la frappe)  mannequin %d  cassables brisés %d/%d" % [lieu, g,
				"oui" if r["rebond"] else "non", "oui" if r["arret"] else "non", r["issue"], roundi(r["frac"] * 100.0), r["touches"], r["casses"], _cassables.size()])
			if lieu == "face_mur":
				_verif(r["rebond"] and r["frac"] >= 0.25 and r["touches"] == 0, "face_mur %s : rebond à mi-course (%d %% de la frappe, jamais au départ), rien derrière" % [g, roundi(r["frac"] * 100.0)])
			else:
				_verif(not r["rebond"] and r["issue"] != "arret" and r["touches"] >= 1, "%s %s : le coup part et va au bout (pas de rebond ni d'arrêt), mannequin touché (%d)" % [lieu, g, r["touches"]])
			if lieu == "urnes":
				_verif(r["casses"] >= 1, "urnes %s : cassables balayés brisés (%d/%d), la lame continue" % [g, r["casses"], _cassables.size()])
	await _tester_elan()
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

## Avancée sur l'armé, jeu en temps normal (mains._process, joueur._physics_process) : terrain libre puis face au mur.
func _tester_elan() -> void:
	print("-- avancée sur l'armé")
	mains.pas_manuel = false
	for lieu in ["libre", "mur", "cible"]:
		for g in ["diag_dg", "estoc_combo", "lourd"]:
			await _batir("face_mur" if lieu == "mur" else "embrasure")
			# libre : 3 m devant la porte ; mur : face au mur plein (face à 1 m de l'origine du lieu), à 0,6 m de lui
			var depart := ORIGINE + (Vector3(0, 0, -0.4) if lieu == "mur" else Vector3(0, 0, 3.0))
			if lieu == "cible":
				await _batir("embrasure")
			s.placer_joueur(depart, 0.0)
			# cible : mannequin à 1,4 m devant (on ne s'avance pas dedans) ; sinon hors du chemin
			_cible.global_position = depart + Vector3(0, 0, -1.4) if lieu == "cible" else ORIGINE + Vector3(4.0, 0, 9.0)
			mains.combat.forcer(EtatCombat.REPOS)
			mains._combo = 0
			j.vigueur = j.vigueur_max
			for i in 20:
				await physics_frame
			var p0 := j.global_position
			mains.entrees.appuyer()
			for k in 70:
				if k == (36 if g == "lourd" else 3):
					mains.entrees.relacher()
				if k == 1 and g != "lourd":
					mains._geste_nom = g
					mains._preparer_geste(false)
				if g == "lourd" and mains.combat.etat == EtatCombat.CHARGE_LOURDE:
					mains._lourd_nom = g
				await physics_frame
			var av := -(j.global_position.z - p0.z)
			if lieu == "libre":
				_verif(av >= 0.25 and av <= 0.7, "avancée %s en terrain libre : %.2f m (0,25 à 0,7)" % [g, av])
			elif lieu == "cible":
				var dc := Vector2(j.global_position.x - _cible.global_position.x, j.global_position.z - _cible.global_position.z).length()
				_verif(dc >= 1.0, "avancée %s vers un mannequin à 1,4 m : on s'arrête devant lui (centre à %.2f m, ≥ 1,0)" % [g, dc])
			else:
				var face := ORIGINE.z - 1.0
				_verif(j.global_position.z > face + 0.2, "avancée %s face au mur : bloquée par le mur (pieds à %.2f m de la face)" % [g, j.global_position.z - face])
	mains.pas_manuel = true
