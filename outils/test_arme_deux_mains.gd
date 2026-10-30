extends SceneTree
## Test sans fenêtre : armes à DEUX MAINS (famille « deux_mains », branche combat/claymore_2mains) — claymore n°05 et hybride
## Cœur-de-Braise (n°6, repère « prise » lu dans le modèle). (À ne pas confondre avec test_deux_mains.gd : configurations
## main droite / main gauche, épée + torche / sort / bouclier.)
##   1. équipement : main gauche libérée (torche rangée, cachée), profil deux_mains, tenues remplacées (repos → repos_2m…) ;
##   2. prise : dans chaque pose clé (repos, garde, armés, frappes, suivis, charge), le centre du poing GAUCHE est sur la poignée,
##      sous le poing droit (écart ≤ 4,5 cm de la cible, un demi-poing — pire mesuré 4 cm au suivi du coup 2, poignet gauche en butée ; poing gauche plus près du pommeau que le droit) ;
##   3. combo : diagonale → horizontal → vertical (clips c2_a, c2_b, c2_c) touchent le mannequin à 1,7 m (TraceLame) ; dégâts du
##      coup léger > ceux de l'épée de métal ; un coup dure ≥ 1,4 × le coup d'épée équivalent ; puissante (lourd_2m) touche ;
##   4. blocage à deux mains : clip garde_2m, un coup de 30 venu de face est bloqué (≤ 15 % passent).
##   godot --headless --path . --script res://outils/test_arme_deux_mains.gd -- --nouvelle
const SCENE := preload("res://scenes/test_combat.tscn")
const ARMES := ["claymore_longue", "claymore", "coeur_de_braise"]
const POSES := ["repos_2m:0.0", "garde_2m:0.0", "sprint_2m:0.0", "encaisse_2m:0.06", "c2_a:0.30", "c2_a:0.50", "c2_a:0.60",
	"c2_a:0.80", "c2_b:0.20", "c2_b:0.42", "c2_b:0.52", "c2_b:0.70", "c2_c:0.40", "c2_c:0.60", "c2_c:0.72", "c2_c:0.88",
	"charge_2m:0.70", "lourd_2m:0.30"]
const ORIGINE := Vector3(-12.0, 0.0, 6.0)
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _cible: StaticBody3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		mains.avancer(DT)
		await process_frame

func _remettre() -> void:
	s.placer_joueur(ORIGINE, 0.0, 0.0)
	_cible.global_position = ORIGINE + Vector3(0, 0, -1.7)
	_cible.coups.clear()
	var mc: CombatEnnemi = _cible.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	j.vigueur = j.vigueur_max
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._souris_recente = Vector2.ZERO
	mains.defense = DefenseJoueur.new()
	await _images(30)
	await physics_frame
	await physics_frame

## Un coup (60 i/s) : appui bref ou maintenu (puissante) ; s'arrête au retour au calme (ou dans la fenêtre de combo si
## `enchaine` : le coup suivant est alors lancé par l'appelant). Renvoie {clip, touches, degats, duree (s de jeu)}.
func _coup(lourd: bool, enchaine := false) -> Dictionary:
	var n0: int = _cible.coups.size()
	mains.entrees.appuyer()
	var tenu := true
	var t := 0.0
	var clip := ""
	var fin := -1.0
	for k in 240:
		if tenu and t >= (1.0 if lourd else 0.05) - 1e-9:
			mains.entrees.relacher()
			tenu = false
		mains.avancer(DT)
		await process_frame
		if mains.combat.etat in [EtatCombat.ATTAQUE_LEGERE, EtatCombat.ATTAQUE_LOURDE]:
			clip = mains._clip
		t += DT
		if enchaine and clip != "" and mains.combat.etat == EtatCombat.RECUPERATION and mains.combat.t > 0.15:
			fin = t
			break
		if not tenu and mains.combat.calme() and clip != "":
			fin = t
			break
	var degats := 0.0
	for i in range(n0, _cible.coups.size()):
		degats += float(_cible.coups[i]["degats"])
	return {"clip": clip, "touches": _cible.coups.size() - n0, "degats": degats, "duree": fin}

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
	# référence : durée et dégâts du coup 1 à l'épée de métal (une main)
	await _remettre()
	var ref := await _coup(false)
	print("REF épée de métal : %s, %d touche(s), dégâts %.1f, durée %.2f s" % [ref["clip"], ref["touches"], ref["degats"], ref["duree"]])
	for id in ARMES:
		print("-- ", id)
		mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % id))
		await _images(40)
		var a: DonneesArme = mains.arme
		_verif(a.deux_mains and a.profil == "deux_mains", "%s : arme à deux mains, profil « deux_mains »" % id)
		_verif(mains.equipement.main_gauche.categorie == DonneesArme.Categorie.VIDE and not mains.porte_torche.visible,
			"%s : main gauche libérée, torche rangée et cachée" % id)
		_verif(mains.anim.reel("repos") == "repos_2m" and mains.anim.reel("garde") == "garde_2m",
			"%s : tenues remplacées (repos → %s, garde → %s)" % [id, mains.anim.reel("repos"), mains.anim.reel("garde")])
		print("   centre du poing droit le long de la lame : %.3f m (repère du modèle)" % mains._milieu_d)
		# 2. prise à deux mains dans chaque pose clé
		var pire := 0.0
		var pire_nom := ""
		var ordre_ok := true
		for p in POSES:
			mains._pose_figee = p
			await _images(4)
			var poing_g: Vector3 = mains._accroche_g.global_transform * mains.PRISE_G.origin
			var poing_d: Vector3 = mains._accroche_d.global_transform * (mains.PRISE_D * Vector3(0.0, mains._milieu_d, 0.0))
			var cible: Vector3 = mains.to_global(mains.pivot_torche.position)
			var e := poing_g.distance_to(cible)
			# poing gauche plus près du pommeau : sa coordonnée le long de la lame est sous celle du poing droit
			var axe: Vector3 = (mains.global_transform.basis * mains.pivot_epee.transform.basis.y).normalized()
			var dy := (poing_d - poing_g).dot(axe)
			ordre_ok = ordre_ok and dy > 0.05
			print("   POSE %-16s écart poing gauche / poignée %.1f cm, poings écartés de %.1f cm le long de la lame" % [p, e * 100.0, dy * 100.0])
			if e > pire:
				pire = e
				pire_nom = p
		mains._pose_figee = ""
		_verif(pire <= 0.045, "%s : poing gauche sur la poignée dans les %d poses clés (pire %.1f cm, %s)" % [id, POSES.size(), pire * 100.0, pire_nom])
		_verif(ordre_ok, "%s : poing gauche sous le poing droit (vers le pommeau) dans toutes les poses" % id)
		# 3. combo + puissante
		await _remettre()
		var clips: Array[String] = []
		for k in 3:
			var r := await _coup(false, k < 2)
			clips.append(r["clip"])
			_verif(r["touches"] >= 1, "%s : coup %d (%s) touche le mannequin à 1,7 m (%d touche(s), dégâts %.1f)" % [id, k + 1, r["clip"], r["touches"], r["degats"]])
			if k == 2:
				pass
		await _remettre()
		var r1 := await _coup(false)
		_verif(r1["degats"] > ref["degats"], "%s : coup léger plus fort qu'à l'épée de métal (%.1f > %.1f)" % [id, r1["degats"], ref["degats"]])
		_verif(r1["duree"] >= ref["duree"] * 1.4, "%s : coup plus lent, plus d'inertie (%.2f s ≥ 1,4 × %.2f s)" % [id, r1["duree"], ref["duree"]])
		_verif(clips == ["c2_a", "c2_b", "c2_c"], "%s : combo diagonale → horizontal → vertical (%s)" % [id, ", ".join(clips)])
		await _remettre()
		var rl := await _coup(true)
		_verif(rl["clip"] == "lourd_2m" and rl["touches"] >= 1, "%s : puissante %s touche (%d, dégâts %.1f)" % [id, rl["clip"], rl["touches"], rl["degats"]])
		# 4. blocage à deux mains (après la fenêtre de parade parfaite)
		await _remettre()
		mains.entrees.forcer_garde(2.0)
		await _images(30)
		var garde_clip: String = mains.anim.reel(mains.anim.clip)
		var rb: Dictionary = mains.defendre(30.0, j.global_position + j.global_transform.basis * Vector3(0, 1.2, -1.5))
		_verif(garde_clip == "garde_2m" and String(rb.get("issue", "")) == "bloque" and float(rb.get("degats", 99.0)) <= 30.0 * 0.15,
			"%s : blocage à deux mains (%s) : %s, %.1f / 30 passent" % [id, garde_clip, rb.get("issue", "?"), float(rb.get("degats", -1.0))])
		await _images(30)
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
