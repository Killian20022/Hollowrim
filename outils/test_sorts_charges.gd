extends SceneTree
## Test sans fenêtre de la CHARGE COMMUNE des sorts lancés (ChargeSort, data/magie/charge_sorts.json ; docs/MAGIE.md) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_sorts_charges.gd -- --nouvelle
## Pour chaque projectile chargé (boule de feu, éclat de glace, lance de givre, trait d'ombre) : tap = petit tir (dégâts, coût,
## taille du projectile au plus bas), charge pleine = ×2 en dégâts et en coût, projectile plus gros, signal « charge pleine »
## (son + éclat) une seule fois, maintien prolongé sans surcharge ; le projectile part vers le viseur (et touche la cible visée,
## pas une autre) ; le joueur ralentit pendant la charge ; la charge s'arrête à ce que le mana permet ; les sorts hors famille
## (chaîne d'éclairs, soin, jet) restent instantanés / canalisés.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const SORTS := ["boule_feu", "eclat_glace", "lance_givre", "trait_ombre"]

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		mains.avancer(DT)
		await physics_frame

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	magie.lanceur.journal.clear()
	magie.journal.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	for m in [s.mannequin, s.mannequin2, s.mannequin3]:
		m.total = 0.0
		m.coups.clear()
		var st := Statuts.de(m, false)
		if st != null:
			st.actifs.clear()
			st.recharge_reaction = 0.0
		var mc: CombatEnnemi = m.combat
		mc.posture = mc.profil.posture_max
		mc.etourdi = 0.0
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	await physics_frame
	await physics_frame

## Tourne le joueur (lacet) et la tête (tangage) pour que le centre de l'écran vise le centre de `cible`.
func _viser(cible: Node3D) -> void:
	var c := Elements._centre(cible)
	for k in 3:
		var o: Vector3 = j.camera.global_position
		var d := c - o
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _projectiles() -> Array:
	return root.find_children("*", "ProjectileSort", true, false).filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())

## Un tir : appui tenu `tenu` s (0 = tap d'une image), relâché ; mesure coût, projectile au départ et dégâts du premier coup.
func _tir(id: String, tenu: float, cible: Node3D) -> Dictionary:
	await _reset()
	await _viser(cible)
	var avant := _projectiles().size()
	var m0: float = j.mana
	var cp0 := int(EffetsMagie.appels.get("charge_pleine", 0))
	var vit := 1.0
	magie.appuyer("droite")
	await _sim(maxf(tenu, DT))
	vit = magie.facteur_vitesse()
	var charge := magie.charge("droite")
	magie.relacher("droite")
	var proj: Array = []
	var depart_ok := false
	var vise := Vector3.ZERO
	for k in 30:   # un tap part à la fin de l'incantation (0,16 s)
		await _sim(DT)
		proj = _projectiles()
		if proj.size() > avant:
			depart_ok = true
			break
	var cout: float = m0 - j.mana
	var r := {"cout": cout, "charge": charge, "vitesse": vit, "projectiles": proj.size() - avant, "taille": 0.0, "angle": 180.0,
		"pleines": int(EffetsMagie.appels.get("charge_pleine", 0)) - cp0, "parti": depart_ok}
	if depart_ok:
		var p: ProjectileSort = proj[proj.size() - 1]
		r["taille"] = p.taille
		var visuel_taille := 1.0
		for c in p.get_children():
			if c is LancerEcole:
				visuel_taille = (c as LancerEcole).taille
		r["taille_visuel"] = visuel_taille
		# direction de départ du projectile du MILIEU (éclats : éventail autour de la visée) contre la ligne paume → cible
		var milieu: ProjectileSort = proj[avant + (proj.size() - avant) / 2]
		vise = Elements._centre(cible) - milieu.global_position
		r["angle"] = rad_to_deg(milieu.vitesse.angle_to(vise))
	await _sim(1.2)
	var direct := 0.0
	var autres := 0.0
	for e in magie.lanceur.journal:
		if e["sort"] != id:
			continue
		if e["cible"] == cible:
			direct = maxf(direct, float(e["degats"]))
		else:
			autres += float(e["degats"])
	r["degats"] = direct
	r["autres"] = autres
	for l in magie.journal:
		if String(l[1]).begins_with("lance droite " + id):
			r["journal"] = String(l[1])
	return r

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	_reglages()
	for id in SORTS:
		await _famille(id)
	await _visee()
	await _mana_limite()
	await _hors_famille()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

func _reglages() -> void:
	var r := ChargeSort.reglages()
	_verif(not r.has("_defaut"), "réglages lus : %s" % ChargeSort.FICHIER)
	var tp := ChargeSort.reglage("temps_plein", 0.0)
	_verif(tp >= 1.0 and tp <= 1.4, "temps de pleine charge réglable : %.2f s (+ incantation)" % tp)
	for id in SORTS:
		var sd: DonneesSort = magie.eq.sort_par_id(id)
		_verif(sd != null and ChargeSort.projectile(sd) and sd.se_charge(), "%s : famille « projectile chargé » (mécanisme commun)" % id)
		if sd != null:
			_verif(absf(ChargeSort.temps_plein(sd) - tp) < 0.001, "%s : même temps de charge que les autres (%.2f s)" % [id, ChargeSort.temps_plein(sd)])
	# pulsation par paliers francs (pas de sinus lisse) : quelques valeurs distinctes seulement
	var vals := {}
	for k in 120:
		vals[snappedf(ChargeSort.pulsation(k / 60.0), 0.001)] = true
	_verif(vals.size() <= 4 and vals.size() >= 2 and ChargeSort.pulsation(0.0) >= 0.99, "pulsation de la charge pleine : %d paliers, départ au plus haut" % vals.size())

func _famille(id: String) -> void:
	var sd: DonneesSort = magie.eq.sort_par_id(id)
	magie.equiper("gauche", "vide")
	magie.equiper("droite", id)
	var cible: Node3D = s.mannequin
	var tap := await _tir(id, 0.0, cible)
	var plein := await _tir(id, sd.incantation + ChargeSort.temps_plein(sd) + 0.25, cible)
	var long := await _tir(id, 3.2, cible)
	print("  %s : tap %.1f dgt %.1f mana taille %.2f | plein %.1f dgt %.1f mana taille %.2f | 3,2 s %.1f dgt %.1f mana" % [id,
		tap["degats"], tap["cout"], tap["taille"], plein["degats"], plein["cout"], plein["taille"], long["degats"], long["cout"]])
	_verif(tap["parti"] and tap["charge"] < 0.05 and tap["pleines"] == 0, "%s : un tap lance un petit tir (charge %.2f), sans signal de charge pleine" % [id, tap["charge"]])
	_verif(absf(tap["degats"] - sd.degats * ChargeSort.reglage("part_degats_tap", 0.5)) < 0.05 * sd.degats, "%s : tap = %.1f dégâts (%.0f %% de %.0f)" % [id, tap["degats"], 100.0 * ChargeSort.reglage("part_degats_tap", 0.5), sd.degats])
	_verif(plein["parti"] and ChargeSort.pleine(plein["charge"]) and plein["pleines"] == 1, "%s : pleine charge atteinte (%.2f), signal « charge pleine » une fois" % [id, plein["charge"]])
	var rapport: float = plein["degats"] / maxf(tap["degats"], 0.01)
	_verif(rapport > 1.9 and rapport < 2.1, "%s : pleine charge = ×%.2f des dégâts du tap (%.1f contre %.1f)" % [id, rapport, plein["degats"], tap["degats"]])
	var rc: float = plein["cout"] / maxf(tap["cout"], 0.01)
	_verif(rc > 1.8 and rc < 2.2 and absf(plein["cout"] - sd.cout) < 0.6, "%s : coût %.1f au tap, %.1f à pleine charge (×%.2f)" % [id, tap["cout"], plein["cout"], rc])
	_verif(plein["taille"] > tap["taille"] * 1.6, "%s : projectile plus gros à pleine charge (×%.2f contre ×%.2f)" % [id, plein["taille"], tap["taille"]])
	if sd.ecole != "feu":
		_verif(absf(plein["taille_visuel"] - plein["taille"]) < 0.01, "%s : le visuel du lancer (LancerEcole) suit la taille (%.2f)" % [id, plein["taille_visuel"]])
	_verif(plein["vitesse"] < 0.9, "%s : le joueur ralentit pendant la charge (×%.2f)" % [id, plein["vitesse"]])
	_verif(long["pleines"] == 1 and absf(long["degats"] - plein["degats"]) < 0.01 and absf(long["cout"] - plein["cout"]) < 0.6,
		"%s : maintenu 3,2 s = même tir qu'à pleine charge (pas de surcharge : %.1f dgt, %.1f mana)" % [id, long["degats"], long["cout"]])
	_verif(plein["angle"] < 3.0 and tap["angle"] < 3.0, "%s : le projectile part vers le viseur (écart %.1f° / %.1f°)" % [id, tap["angle"], plein["angle"]])
	_verif(plein["projectiles"] == maxi(1, sd.nombre), "%s : %d projectile(s)" % [id, plein["projectiles"]])
	await _sim(0.3)
	_verif(is_equal_approx(magie.facteur_vitesse(), 1.0), "%s : vitesse normale après le tir" % id)

## Visée : on vise le mannequin de gauche (au fond) puis celui de droite ; le tir chargé part vers le viseur et touche celui-là.
func _visee() -> void:
	magie.equiper("gauche", "vide")
	magie.equiper("droite", "boule_feu")
	for nom in ["mannequin2", "mannequin3"]:
		var cible: Node3D = s.get(nom)
		var r := await _tir("boule_feu", 1.6, cible)
		var autre_touche := false
		for e in magie.lanceur.journal:
			if e["cible"] == s.mannequin:
				autre_touche = true
		_verif(r["degats"] > 0.0 and not autre_touche and r["angle"] < 3.0, "visée : boule chargée sur %s (%.1f dégâts, écart %.1f°), le mannequin du milieu épargné" % [nom, r["degats"], r["angle"]])

## Mana juste au-dessus du tap : la charge plafonne à ce qui est payable, rien n'est refusé, le mana ne passe jamais sous 0.
func _mana_limite() -> void:
	var sd: DonneesSort = magie.eq.sort_par_id("lance_givre")
	magie.equiper("gauche", "vide")
	magie.equiper("droite", "lance_givre")
	await _reset()
	await _viser(s.mannequin)
	var dispo := LanceurSorts.cout(sd, 0.0) + (sd.cout - LanceurSorts.cout(sd, 0.0)) * 0.4
	j.mana = dispo
	magie.appuyer("droite")
	await _sim(2.0)
	var c := magie.charge("droite")
	magie.relacher("droite")
	await _sim(0.1)
	_verif(c > 0.3 and c < 0.5 and j.mana >= -0.01 and j.mana < 1.0, "mana limité (%.1f) : la charge plafonne à %.2f, tout le mana payé (reste %.1f)" % [dispo, c, j.mana])
	await _sim(1.0)

## Hors famille : la chaîne d'éclairs part sans attendre, le soin se canalise, aucun ralenti ni signal de charge pleine.
func _hors_famille() -> void:
	magie.equiper("gauche", "vide")
	magie.equiper("droite", "chaine_eclairs")
	await _reset()
	await _viser(s.mannequin)
	magie.appuyer("droite")
	await _sim(0.3)
	var lance := false
	for l in magie.journal:
		if String(l[1]).begins_with("lance droite chaine_eclairs"):
			lance = true
	_verif(lance and is_equal_approx(magie.facteur_vitesse(), 1.0), "chaîne d'éclairs : reste instantanée (part pendant l'appui, pas de ralenti)")
	magie.relacher("droite")
	await _sim(0.5)
	magie.equiper("droite", "soin")
	await _reset()
	j.vie = 40.0
	magie.appuyer("droite")
	await _sim(1.0)
	_verif(magie.inc["droite"].etat == Incantation.CANALISE and j.vie > 45.0, "soin : toujours canalisé tant qu'on tient (%.1f PV)" % j.vie)
	magie.relacher("droite")
	await _sim(0.4)
	var sd: DonneesSort = magie.eq.sort_par_id("rayon_neant")
	_verif(not ChargeSort.projectile(sd) and absf(ChargeSort.temps_plein(sd) - sd.temps_charge) < 0.001, "rayon du néant : sort à charge à part (garde ses %.1f s et ses dégâts)" % sd.temps_charge)
	_verif(FileAccess.file_exists("res://assets/sons/magie/charge_pleine.wav") and SonsMagie.flux(SonsMagie.SON_PLEINE) != null, "son « charge pleine » présent et lisible")
