extends SceneTree
## BANC « BOT MAGE » (nuit 2026-11-05, docs/MAGIE.md « Équilibrage »). Pendant magique de outils/test_menace_bot.gd : un bot qui ne
## porte QUE des sorts (aucune épée) combat de VRAIS draugrs (104 PV) dans scenes/test_combat.tscn.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_mage_bot.gd -- [--n=6] [--config=feu_s] [--trace] [--film=…]
## Configurations : <école>_<s|d> (simple = sort dans la main droite ; double = le même sort dans les deux mains, appuis simultanés).
##   feu : boule de feu (chargée)      glace : éclat de glace (rapide)      electricite : arc électrique (canalisé)
##   tenebres : trait d'ombre (rapide) + variantes : feu_jet, glace_lance, electricite_chaine, tenebres_drain (simples).
## Comportement (même vision de l'ennemi que le bot de mêlée, aucune triche) :
##   - face à l'ennemi le plus proche, tire dès que le sort est prêt et la portée bonne (charge tenue jusqu'au bout) ;
##   - recule à 2,6 m/s (marche arrière, sans vigueur ; fond de salle à 1,5 m) quand un ennemi est à moins de 4 m ou que la mana est vide, pour regagner
##     de la mana (7 /s après 1,2 s sans dépense) et de la distance — le draugr court à 3,4 m/s : le recul retarde, ne protège pas ;
##   - esquive (pas de côté) ~0,1 s avant l'impact d'un geste ennemi proche, comme le bot « esquive » de la mêlée.
## Mesures : durée, vie perdue, mana restante, mana dépensée, ennemis tués. SEUILS : voir _verifier().
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const CONFIGS := {
	"feu_s": ["boule_feu", false], "feu_d": ["boule_feu", true],
	"glace_s": ["eclat_glace", false], "glace_d": ["eclat_glace", true],
	"electricite_s": ["arc_electrique", false], "electricite_d": ["arc_electrique", true],
	"tenebres_s": ["trait_ombre", false], "tenebres_d": ["trait_ombre", true],
	"feu_jet": ["jet_flammes", false], "glace_lance": ["lance_givre", false],
	"electricite_chaine": ["chaine_eclairs", false], "tenebres_drain": ["drain_vie", false],
}
const BASE := ["feu_s", "feu_d", "glace_s", "glace_d", "electricite_s", "electricite_d", "tenebres_s", "tenebres_d"]
const SIMPLES := ["feu_s", "glace_s", "electricite_s", "tenebres_s"]
const VARIANTES := ["feu_jet", "glace_lance", "electricite_chaine", "tenebres_drain"]
const KITE := 2.6   # marche arrière (plus lente que la marche avant 3,2 m/s)
const MUR_Z := 1.5   # fond de la salle : à 1,5 m derrière le joueur, le recul s'arrête là (couloir / petite salle de donjon)
const DIST_KITE := 4.0
const DUREE_MAX := 30.0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var n := 6
var config := ""
var trace := false
var variantes := false   # --variantes : ajoute jet de flammes, lance de givre, chaîne d'éclairs, drain de vie (contre 1 draugr)
var dist_depart := 5.4   # --dist=<m> : distance de départ du premier draugr (5,4 m : celle du banc de mêlée ; la mêlée y tue en ~3,6 s)
var sans_esquive := false   # --sans-esquive : ne se défend jamais (pendant du bot « spam » de la mêlée)
var statique := false   # --statique : le mage ne recule jamais (il tient sa place et esquive) ; sinon il recule (voir plus haut)
var seul_nb := 0   # --nb=2 : seulement les essais contre 2 draugrs (mise au point)
var film := ""
var _ok := true

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--config="): config = a.substr(9)
		elif a == "--trace": trace = true
		elif a == "--statique": statique = true
		elif a == "--sans-esquive": sans_esquive = true
		elif a.begins_with("--dist="): dist_depart = float(a.substr(7))
		elif a == "--variantes": variantes = true
		elif a.begins_with("--nb="): seul_nb = int(a.substr(5))
		elif a.begins_with("--film="): film = a.substr(7)
	_go.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(k := 1) -> void:
	for i in k:
		if film == "":
			mains.avancer(DT)
		await physics_frame

func _vivants(liste: Array) -> Array:
	return liste.filter(func(d): return is_instance_valid(d) and d.etat != d.MORT)

func _impact(d: Node) -> float:
	if d._lourd:
		return ReglagesCombat.MENACE_LOURD_ANNONCE
	var duree: float = d._duree(d._attaque) / d._rythme
	var f := 0.42
	var a: Animation = d.anim.get_animation(d._clip(d._attaque))
	if a.has_meta("impact") and float(a.get_meta("impact")) > 0.0:
		f = float(a.get_meta("impact"))
	return duree * f

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	seed(20261105)
	for i in 30:
		await physics_frame
	if film == "":
		mains.pas_manuel = true
	s.mannequin.position = Vector3(-8, 0, -8)
	var res := {}
	var liste: Array = [config] if config != "" else (BASE + VARIANTES if variantes else BASE)
	var explicite := config != "" or statique or sans_esquive
	for c in liste:
		res[c + "_1"] = []
		for e in (0 if seul_nb == 2 else n):
			res[c + "_1"].append(await _essai(c, 1, e))
		if (BASE.has(c) or config != "") and seul_nb != 1:
			res[c + "_2"] = []
			for e in (1 if seul_nb == 2 and trace else maxi(n / 2, 2)):
				res[c + "_2"].append(await _essai(c, 2, e))
		if trace:
			break
	if not explicite:
		# 2e passe : le mage NAÏF (il tient sa place et ne se défend jamais : pendant du bot « spam » de la mêlée), sorts simples
		statique = true
		sans_esquive = true
		for c in SIMPLES:
			res["naif_" + c + "_1"] = []
			for e in n:
				res["naif_" + c + "_1"].append(await _essai(c, 1, e))
			res["naif_" + c + "_2"] = []
			for e in maxi(n / 2, 2):
				res["naif_" + c + "_2"].append(await _essai(c, 2, e))
	_verifier(res)
	print("TEST_MAGE_BOT ", "OK" if _ok else "ECHECS")
	quit(0 if _ok else 1)

func _moy(l: Array, cle: String) -> float:
	var t := 0.0
	for r in l:
		t += float(r[cle])
	return t / maxf(l.size(), 1)

func _tues(l: Array, nb: int) -> float:
	return _moy(l, "tues") / float(nb)

func _bilan(k: String, l: Array, nb: int) -> void:
	print("BILAN %-22s n=%d  durée=%.1fs  PV perdus=%.1f  mana restante=%.0f  mana dépensée=%.0f  tués=%.0f %%  morts=%.0f %%" % [k, l.size(), _moy(l, "duree"), _moy(l, "degats"), _moy(l, "mana"), _moy(l, "depense"), _tues(l, nb) * 100.0, _moy(l, "mort") * 100.0])

func _verifier(res: Dictionary) -> void:
	for k in res:
		_bilan(k, res[k], 2 if k.ends_with("_2") else 1)
	# SEUILS. Référence mêlée (outils/test_menace_bot.gd, bot qui spamme, même distance de départ 5,4 m) : 1 draugr en 3,6 s pour ~23 PV,
	# 2 draugrs en 5,7 s pour ~50 PV. Le mage doit VALOIR cela sans l'écraser : plus lent au corps à corps, bien plus sûr à distance.
	# 1) Le mage qui gère sa distance (recule, esquive) : tue 1 et 2 draugrs, sans mourir, avec de la mana en réserve.
	for c in BASE:
		var un: Array = res.get(c + "_1", [])
		var deux: Array = res.get(c + "_2", [])
		if un.is_empty():
			continue
		_verif(_tues(un, 1) >= 0.9, "%s : tue 1 draugr seul (%.0f %%)" % [c, _tues(un, 1) * 100.0])
		_verif(_moy(un, "duree") >= 1.5 and _moy(un, "duree") <= 14.0, "%s : 1,5 à 14 s pour 1 draugr (%.1f s ; la mêlée du bot : 3,6 s)" % [c, _moy(un, "duree")])
		_verif(_moy(un, "degats") <= 25.0, "%s : ≤ 25 PV perdus contre 1 draugr (%.1f ; la mêlée du bot : 23)" % [c, _moy(un, "degats")])
		if c.ends_with("_s"):
			_verif(_moy(un, "mana") >= 20.0, "%s : il reste ≥ 20 de mana après 1 draugr (%.0f ; un sort simple coûte 55-70 par draugr)" % [c, _moy(un, "mana")])
		if not deux.is_empty():
			_verif(_moy(deux, "mort") <= 0.0, "%s : survit à 2 draugrs (morts %.0f %%)" % [c, _moy(deux, "mort") * 100.0])
			_verif(_tues(deux, 2) >= 0.9, "%s : tue les 2 draugrs (%.0f %%)" % [c, _tues(deux, 2) * 100.0])
			_verif(_moy(deux, "degats") <= 40.0, "%s : ≤ 40 PV perdus contre 2 draugrs (%.1f)" % [c, _moy(deux, "degats")])
	# 2) Le mage NAÏF (immobile, ne se défend jamais) : la magie ne dispense pas de jouer (pas mieux que la mêlée du bot qui spamme).
	var ouverts := []
	var duos := []
	for c in SIMPLES:
		if res.has("naif_" + c + "_1"):
			ouverts.append_array(res["naif_" + c + "_1"])
			duos.append_array(res["naif_" + c + "_2"])
	if not ouverts.is_empty():
		_verif(_tues(ouverts, 1) >= 0.9, "mage naïf, 1 draugr : il gagne (%.0f %%)" % (_tues(ouverts, 1) * 100.0))
		_verif(_moy(ouverts, "duree") >= 3.0 and _moy(ouverts, "duree") <= 8.0, "mage naïf, 1 draugr : 3 à 8 s (%.1f s ; mêlée du bot : 3,6 s) : jamais plus rapide que la mêlée" % _moy(ouverts, "duree"))
		_verif(_moy(ouverts, "degats") <= 25.0, "mage naïf, 1 draugr : ≤ 25 PV perdus (%.1f ; mêlée : 23)" % _moy(ouverts, "degats"))
		_verif(_moy(duos, "degats") >= 15.0, "mage naïf, 2 draugrs : ≥ 15 PV perdus en moyenne (%.1f ; mêlée : 50) : 2 draugrs restent dangereux" % _moy(duos, "degats"))
		_verif(_moy(duos, "mort") <= 0.25, "mage naïf, 2 draugrs : meurt dans ≤ 25 %% des essais (%.0f %%)" % (_moy(duos, "mort") * 100.0))
		_verif(_tues(duos, 2) >= 0.5, "mage naïf, 2 draugrs : tue les deux dans ≥ 50 %% des cas (%.0f %%)" % (_tues(duos, 2) * 100.0))

## Bouton(s) du sort : appuis, maintien, relâchement selon le type (le bot lit seulement l'état public de MainSort).
func _tirer(sort: DonneesSort, double: bool, dist: float, mana_ok: bool, ctx: Dictionary) -> void:
	var mains_l: Array = ["droite", "gauche"] if double else ["droite"]
	var m0: Incantation = magie.inc["droite"]
	var portee: float = minf(sort.portee, 14.0) * (float(sort.double.get("portee", 1.0)) if double else 1.0)
	var voulu: bool = dist < portee * 0.92 and mana_ok
	match sort.type:
		DonneesSort.Type.CANALISE:
			for m in mains_l:
				var i: Incantation = magie.inc[m]
				if voulu and not i.tenu and i.libre():
					magie.appuyer(m)
				elif not voulu and i.tenu:
					magie.relacher(m)
		DonneesSort.Type.CHARGE:
			for m in mains_l:
				var i: Incantation = magie.inc[m]
				if i.tenu and (i.etat == Incantation.CHARGE and i.charge >= 0.99 or not voulu and i.etat != Incantation.INCANTE):
					magie.relacher(m)
				elif voulu and not i.tenu and i.libre() and ctx["rel"] <= 0:
					magie.appuyer(m)
		_:
			# rapide : appui, relâchement après 2 images (les deux mains dans la même image pour la double)
			if ctx["rel"] > 0:
				ctx["rel"] -= 1
				if ctx["rel"] == 0:
					for m in mains_l:
						magie.relacher(m)
			elif voulu and m0.libre() and (not double or magie.inc["gauche"].libre()) and magie.recharges.get(sort.id, 0.0) <= 0.0:
				for m in mains_l:
					magie.appuyer(m)
				ctx["rel"] = 2

func _essai(nom: String, nb: int, idx: int) -> Dictionary:
	var cfg: Array = CONFIGS[nom]
	var sort: DonneesSort = magie.eq.sort_par_id(cfg[0])
	var double: bool = cfg[1]
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	magie.eq.equiper("gauche", "vide")
	magie.eq.equiper("droite", cfg[0])
	if double:
		magie.eq.equiper("gauche", cfg[0])
	if j.mort:
		j.ressusciter(Vector3.ZERO, 0.0)   # l'essai précédent s'est mal terminé : on repart d'un joueur vivant
	s.placer_joueur(Vector3.ZERO, 0.0)
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	j.mana = j.mana_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.forcer_garde(0.0)
	mains.entrees.tampon = -1.0
	var liste := []
	for k in nb:
		var d := CharacterBody3D.new()
		d.set_script(load("res://scripts/draugr.gd"))
		d.type = "draugr"
		d.joueur = j
		d.hud = s.hud
		d.ident = "mage_%s_%d_%d" % [nom, idx, k]
		d.position = Vector3(2.0 + idx * 0.37 + k * 1.6, 0, -dist_depart - k * 1.5)
		d.rotation.y = atan2(d.position.x, d.position.z)
		s.add_child(d)
		liste.append(d)
	await _pas(5)
	var vie0: float = j.vie
	var mana0: float = j.mana
	var depense := 0.0
	var mana_prec: float = j.mana
	var t_ := 0.0
	var ctx := {"rel": 0}
	var t_esquive := -1.0
	var cout_min := float(sort.double.get("cout", 1.0)) if double else 1.0   # facteur de la double incantation
	cout_min *= maxf(LanceurSorts.cout(sort, 0.0), sort.cout_par_seconde * 0.5)
	var attend_mana := false   # hystérésis : après un manque, on ne retire qu'avec de quoi lancer plusieurs sorts
	while t_ < DUREE_MAX and not _vivants(liste).is_empty() and j.vie > 0.0:
		var cible: Node3D = null
		var dmin := 1e9
		for d in _vivants(liste):
			var dd: float = (d.global_position - j.global_position).length()
			if dd < dmin:
				dmin = dd
				cible = d
		var dv: Vector3 = cible.global_position - j.global_position
		var dist := Vector2(dv.x, dv.z).length()
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-dv.x, -dv.z), 0.5)
		j.tete.rotation.x = atan2(-0.5, maxf(dist, 1.0))   # la poitrine du draugr (~1,1 m) depuis l'œil (~1,6 m)
		# mana : on repart tirer quand il y a de quoi lancer ~2 sorts (un sort chargé de 26 ne part pas avec 10)
		if j.mana < cout_min:
			attend_mana = true
		elif j.mana >= cout_min * 2.0:
			attend_mana = false
		# déplacement : recul si un ennemi est trop près, ou si la mana est vide (on temporise)
		if j.esquive_t < 0.0:
			j.velocity = Vector3.ZERO
			var dir := Vector3(dv.x, 0, dv.z).normalized()
			var proche := dist < DIST_KITE and not statique
			if (proche or attend_mana) and not statique:
				if j.global_position.z < MUR_Z:
					j.global_position -= dir * KITE * DT * (1.0 if proche else 0.6)
			elif dist > minf(sort.portee, 14.0) * 0.85:
				j.global_position += dir * KITE * DT
		# esquive d'un geste ennemi proche (~0,1 s avant l'impact)
		for d in _vivants(liste):
			var dd: float = Vector2(d.global_position.x - j.global_position.x, d.global_position.z - j.global_position.z).length()
			if d.etat == d.ATTAQUE and dd < 3.4 and not d._coup_donne:
				var avant: float = _impact(d) - d._t
				if not sans_esquive and avant <= 0.12 and avant > -0.02 and j.esquive_t < 0.0 and t_ - t_esquive > 0.25:
					t_esquive = t_
					var somme := 0.0
					for e in _vivants(liste):
						somme += (e.global_position - j.global_position).dot(j.global_transform.basis.x)
					j.esquiver(Vector2(-signf(somme) if absf(somme) > 0.1 else 1.0, 0))
		_tirer(sort, double, dist, not attend_mana, ctx)
		if trace and int(t_ * 60.0) % 12 == 0:
			var ds := []
			for d in _vivants(liste):
				ds.append("pv%.0f/d%.1f/e%d" % [d.vie, (d.global_position - j.global_position).length(), d.etat])
			print("TRACE t=%.2f dist=%.1f mana=%.0f vie=%.0f inc=%s/%s %s" % [t_, dist, j.mana, j.vie, magie.inc["droite"].nom(), magie.inc["gauche"].nom(), str(ds)])
		await _pas(1)
		t_ += DT
		if j.mana < mana_prec:
			depense += mana_prec - j.mana
		mana_prec = j.mana
	var tues := 0
	for d in liste:
		if not is_instance_valid(d) or d.etat == d.MORT:
			tues += 1
	magie.relacher("droite")
	magie.relacher("gauche")
	var r := {"duree": t_, "degats": vie0 - maxf(j.vie, 0.0), "mana": j.mana, "depense": depense, "tues": tues, "mort": 1.0 if j.vie <= 0.0 else 0.0}
	print("ESSAI %s ennemis=%d essai=%d durée=%.1fs PV perdus=%.0f mana restante=%.0f dépensée=%.0f tués=%d/%d%s" % [nom, nb, idx, t_, r["degats"], j.mana, depense, tues, nb, " MORT" if r["mort"] > 0 else ""])
	for d in liste:
		if is_instance_valid(d):
			d.queue_free()
	await _pas(30)
	return r
