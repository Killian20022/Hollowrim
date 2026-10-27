extends SceneTree
## Test sans fenêtre de la défense du joueur (phase 3, docs/COMBAT.md) dans la scène scenes/test_combat.tscn :
##   bash outils/tous_les_tests.sh test_defense
## 1. Garde orientée : coup de face bloqué (réduction et coût d'endurance de l'arme), de dos et à 75° non bloqués, à 45° bloqué.
## 2. Garde brisée : endurance insuffisante → une partie du coup passe, le joueur titube, garde impossible ~1 s puis possible.
## 3. Anti-spam : relever la garde trop souvent réduit la fenêtre de parade ; après un temps calme elle revient.
## 4. Parade parfaite contre la VRAIE attaque d'un draugr → « parade », aucun dégât, draugr déséquilibré (posture, fenêtre
##    apres_parade, titube/étourdi), fenêtre de contre-attaque ouverte.
## 5. Contre-attaque : geste « contre » depuis la garde, attaque « contre » (dégâts ×1,3, stagger de contre), critique selon
##    les règles seulement.
## 6. Finisher depuis le joueur : clic sur un draugr ouvert → séquence FPS ≤ 0,8 s → subir_finisher → décapité, mort.
## 7. Pas de finisher dans le dos d'un ennemi étourdi (coup normal) ; 8. finisher sur le mannequin (la tête s'envole).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

## n pas de 1/60 s : le combat du joueur (pas manuel) puis le moteur (draugrs, physique).
func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT)
		await physics_frame

func _reset(pos: Vector3, lacet: float) -> void:
	s.placer_joueur(pos, lacet)
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	j.competences = Competences.new()
	mains.entrees.forcer_garde(0.0)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains.combat.forcer(EtatCombat.REPOS)
	mains._titube_garde = false
	mains.defense = DefenseJoueur.new()
	await _pas(3)

func _clic() -> void:
	mains.entrees.appuyer()
	await _pas(2)
	mains.entrees.relacher()

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var red: float = Competences.new().reduction_parade()
	var arme: DonneesArme = mains.arme

	# --- 1. garde orientée
	print("-- garde orientée")
	await _reset(Vector3.ZERO, 0.0)   # face à -Z
	mains.entrees.forcer_garde(60.0)
	await _pas(20)
	_verif(mains.combat.etat == EtatCombat.GARDE and mains.bloque, "garde levée puis tenue (état %s)" % mains.combat.nom())
	var o := j.global_position
	var vie0: float = j.vie
	var vig0: float = j.vigueur
	var r: String = j.recevoir_coup(20.0, o + Vector3(0, 0, -1.5))
	var attendu := 20.0 * (1.0 - arme.reduction_garde) * red
	_verif(r == "bloque" and absf(vie0 - j.vie - attendu) < 0.01, "de face : bloqué, %.2f dégâts passent (attendu %.2f, réduction %d %%)" % [vie0 - j.vie, attendu, roundi(arme.reduction_garde * 100)])
	_verif(absf(vig0 - j.vigueur - 20.0 * DefenseJoueur.COUT_BLOCAGE * red * arme.cout_garde) < 0.01, "coût d'endurance du coup bloqué : %.1f" % (vig0 - j.vigueur))
	vie0 = j.vie
	r = j.recevoir_coup(20.0, o + Vector3(0, 0, 1.5))
	_verif(r == "touche" and absf(vie0 - j.vie - 20.0) < 0.01, "de dos : pas de blocage (%s, -%.0f)" % [r, vie0 - j.vie])
	vie0 = j.vie
	r = j.recevoir_coup(10.0, o + Vector3(sin(deg_to_rad(45.0)), 0, -cos(deg_to_rad(45.0))) * 1.5)
	_verif(r == "bloque", "à 45° devant : bloqué (%s)" % r)
	r = j.recevoir_coup(10.0, o + Vector3(sin(deg_to_rad(75.0)), 0, -cos(deg_to_rad(75.0))) * 1.5)
	_verif(r == "touche", "à 75° (hors du cône de 120°) : touché (%s)" % r)

	# --- 2. garde brisée
	print("-- garde brisée")
	await _reset(Vector3.ZERO, 0.0)
	mains.entrees.forcer_garde(60.0)
	await _pas(20)
	j.vigueur = 5.0
	vie0 = j.vie
	r = j.recevoir_coup(20.0, o + Vector3(0, 0, -1.5))
	_verif(r == "touche" and absf(vie0 - j.vie - 20.0 * DefenseJoueur.PART_BRISEE) < 0.01 and j.vigueur <= 0.0, "endurance insuffisante : garde brisée, %.0f dégâts passent, endurance %.0f" % [vie0 - j.vie, j.vigueur])
	_verif(mains.combat.etat == EtatCombat.DESEQUILIBRE and mains._titube_garde and mains.defense.brisee > 0.0, "le joueur titube (Staggered), garde impossible %.1f s" % mains.defense.brisee)
	await _pas(1)
	var pose_brisee: Transform3D = mains._pose_courante
	j.vigueur = j.vigueur_max
	await _pas(30)
	_verif(not mains.bloque, "0,5 s après : garde toujours impossible (bouton tenu)")
	await _pas(42)
	_verif(mains.bloque, "1,2 s après : la garde revient (état %s)" % mains.combat.nom())
	_verif(pose_brisee.origin.y < GestesDefense.pose("garde").origin.y - 0.02, "pose de garde brisée : l'épée est rabattue vers le bas (y %.2f)" % pose_brisee.origin.y)

	# --- 3. anti-spam
	print("-- anti-spam")
	await _reset(Vector3.ZERO, 0.0)
	var fen := []
	for i in 4:
		mains.entrees.forcer_garde(0.12)
		await _pas(2)
		fen.append(snappedf(mains.defense.fenetre, 0.001))
		await _pas(16)
	_verif(absf(fen[0] - DefenseJoueur.FENETRE_PARADE) < 1e-4 and fen[3] < fen[0] - 0.1, "garde relevée 4 fois en 1,2 s : fenêtre de parade %s" % [fen])
	await _pas(70)
	mains.entrees.forcer_garde(0.12)
	await _pas(2)
	_verif(absf(mains.defense.fenetre - DefenseJoueur.FENETRE_PARADE) < 1e-4, "après 1,2 s de calme : fenêtre entière (%.3f)" % mains.defense.fenetre)
	await _pas(10)

	# --- 4. parade parfaite contre la vraie attaque du draugr
	print("-- parade parfaite")
	var d: CharacterBody3D = s.draugr
	d.combat.profil.chance_blocage = 0.0
	await _reset(Vector3(0, 0, 0), 0.0)
	d.global_position = Vector3(0, 0, -1.5)
	d.rotation.y = 0.0
	d.vie = 400.0
	d.vie_max = 400.0
	d.set_physics_process(true)
	d.set_process(true)
	d._recharge = 0.0
	d._changer(d.TRAQUE)
	var posture0: float = d.combat.ratio_posture()
	var leve := false
	var t_garde := -1.0
	var t := 0.0
	for i in 240:
		if not leve and d.etat == d.ATTAQUE:
			var duree: float = d._duree(d._attaque) / d._rythme
			if d._t >= duree * 0.42 - 0.07:
				mains.entrees.forcer_garde(0.7)
				leve = true
				t_garde = t
		if mains.defense.nb_parades > 0:
			break
		await _pas(1)
		t += DT
	_verif(leve and mains.defense.nb_parades == 1 and j.vie >= j.vie_max - 0.01, "garde levée %.2f s avant l'impact du draugr : parade parfaite, aucun dégât (vie %.0f)" % [t - t_garde, j.vie])
	await _pas(1)
	_verif(d.combat.fenetre_parade > 0.0 and d.combat.ratio_posture() < posture0 - 0.3, "draugr déséquilibré : posture %d %% → %d %%, fenêtre apres_parade %.1f s" % [roundi(posture0 * 100), roundi(d.combat.ratio_posture() * 100), d.combat.fenetre_parade])
	_verif(d.etat in [d.TITUBE, d.ETOURDI], "le draugr est ouvert (titube / étourdi : état %d)" % d.etat)
	_verif(mains.defense.contre > 0.0, "fenêtre de contre-attaque ouverte (%.2f s)" % mains.defense.contre)

	# --- 5. contre-attaque depuis la garde
	print("-- contre-attaque")
	var vie_d: float = d.vie
	var vu_contre := false
	mains.entrees.appuyer()
	for i in 3:
		await _pas(1)
		vu_contre = vu_contre or mains.combat.etat == EtatCombat.CONTRE
	mains.entrees.relacher()
	for i in 30:
		await _pas(1)
		vu_contre = vu_contre or mains.combat.etat == EtatCombat.CONTRE
	var dr: Dictionary = d.combat.dernier_resultat
	var di: Dictionary = dr.get("info", {})
	_verif(vu_contre and mains._geste_nom == "contre", "clic pendant la garde, juste après la parade : geste « contre » (état Counter)")
	_verif(d.vie < vie_d and di.get("attaque") == "contre" and absf(float(di.get("stagger", 0.0)) - DegatsCombat.stagger(arme, "contre")) < 0.01, "contre touché : %.1f dégâts, attaque %s, stagger %.0f" % [vie_d - d.vie, di.get("attaque"), float(di.get("stagger", 0.0))])
	var crit_regle: bool = String(di.get("zone", "")) == "tete" or d.combat.au_sol
	_verif(bool(dr.get("critique", true)) == crit_regle, "pas de critique automatique : critique=%s (zone %s)" % [dr.get("critique"), di.get("zone")])
	print("   contre : réaction %s, posture %d %%, impact %s" % [dr.get("reaction"), roundi(d.combat.ratio_posture() * 100), dr.get("impact")])

	# --- 6. finisher depuis le joueur (draugr ouvert, de face)
	print("-- finisher")
	await _pas(30)
	if d.finisher_possible(j) == "":
		d.combat.briser_posture()
		d._etourdir()
	d.set_physics_process(false)
	var cat: String = d.finisher_possible(j)
	_verif(cat != "", "draugr achevable : catégorie « %s »" % cat)
	j.vigueur = j.vigueur_max
	j.rotation.y = deg_to_rad(25.0)   # regard un peu à côté : le verrou de caméra doit le ramener sur la cible
	await _pas(1)
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	_verif(mains.combat.etat == EtatCombat.FINISHER, "clic (léger) sur la cible ouverte : séquence finisher (état %s)" % mains.combat.nom())
	var duree_fin := 0.0
	var ecart_frappe := 99.0
	while mains.combat.etat in [EtatCombat.FINISHER, EtatCombat.RECUPERATION] and duree_fin < 2.0:
		var avant_frappe: bool = not mains._fin_frappe
		await _pas(1)
		duree_fin += DT
		if avant_frappe and mains._fin_frappe:
			var cam: Camera3D = j.camera
			var v: Vector3 = mains._point_finisher() - cam.global_position
			ecart_frappe = rad_to_deg((-cam.global_transform.basis.z).angle_to(v))
	_verif(duree_fin <= 0.8 + 1e-3, "séquence FPS complète en %.2f s (≤ 0,8 s)" % duree_fin)
	_verif(ecart_frappe < 12.0, "caméra verrouillée sur la cible à l'impact (écart %.1f°)" % ecart_frappe)
	await _pas(10)
	_verif(not d.vivant() and mains.dernier_finisher.get("resultat") == "tue", "subir_finisher(« %s ») : draugr tué" % cat)
	_verif(d.modele.has_meta("decapite") and d.modele.get_meta("tete_coupee", null) != null, "décapité : tête détachée en corps rigide")

	# --- 7. dans le dos : pas de finisher
	print("-- dans le dos")
	var d2: CharacterBody3D = s.creer_draugr(Vector3(4.0, 0.0, -5.0), true)
	await _pas(5)
	d2.rotation.y = 0.0   # tourné vers +Z
	d2.combat.briser_posture()
	d2._etourdir()
	await _reset(d2.global_position + Vector3(0, 0, -1.4), 180.0)   # derrière lui, face à +Z (vers son dos)
	_verif(mains._chercher_finisher().is_empty(), "derrière un draugr étourdi : aucun finisher proposé")
	await _clic()
	_verif(mains.combat.etat != EtatCombat.FINISHER and d2.vivant(), "le clic donne un coup normal (état %s)" % mains.combat.nom())
	await _pas(40)
	d2.queue_free()

	# --- 8. mannequin
	print("-- mannequin")
	var mq: Mannequin = s.mannequin
	await _reset(mq.global_position + Vector3(0, 0, 1.6), 0.0)
	mq.combat.briser_posture()
	await _clic()
	_verif(mains.combat.etat == EtatCombat.FINISHER, "mannequin à posture brisée : finisher")
	await _pas(40)
	_verif(not mq.tete.visible and mq.vivant(), "mannequin : la tête s'envole, il reste debout")

	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
