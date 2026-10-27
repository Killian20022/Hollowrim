class_name MainSort
extends Node
## Magie du joueur et des deux mains (point d'accroche UNIQUE dans mains.gd : `mains.magie`). Docs : docs/MAGIE.md.
##   - EquipementMains : contenu de chaque main (arme, sort, bouclier, torche, vide, deux mains) et règles de
##     compatibilité data-driven (data/magie/regles_mains.json) ; raccourcis 1-0 (data/magie/raccourcis.json).
##   - Entrées : action « main_droite » (clic gauche) → main droite ; « main_gauche » (clic droit) → main gauche, SAUF si la
##     règle « garde » s'applique (main gauche vide / torche / bouclier et épée à droite…) : clic droit = GARDE comme avant.
##     Maintien = charger / canaliser ; relâcher = sort chargé ; les deux boutons dans la fenêtre de synchronisation
##     (0,15 s) avec le même sort = DOUBLE INCANTATION.
##   - Incantation (une par main) : machine à états ; LanceurSorts : exécution ; Elements / Statuts : dégâts, statuts,
##     réactions, combos (chemin unique DegatsCombat.appliquer).
##   - Poses FPS des mains qui incantent (PosesIncantation) appliquées APRÈS la pose de l'épée (mains.avancer), par
##     IK + orientation de la main + doigts : le geste de l'épée n'est jamais modifié.
##   - Contrat visuel : EffetsMagie (agent effets) ; HUD : signaux / propriétés du joueur (joueur.gd).

const MAINS := ["gauche", "droite"]
const ORIENTATION := preload("res://scripts/orientation_main.gd")

var mains: Node3D
var joueur: CharacterBody3D
var eq: EquipementMains
var lanceur: LanceurSorts
var inc := {"gauche": Incantation.new(), "droite": Incantation.new()}
## Recharges en cours {id_sort: s restantes} (lu par le HUD).
var recharges := {}
## Enchantement de la lame : {"sort": DonneesSort, "reste": s} ou vide.
var enchantement := {}
## Dernière raison de refus par main (HUD : « pourquoi c'est indisponible »).
var refus := {"gauche": "", "droite": ""}
var horloge := 0.0
## Journal des événements (tests) : [[horloge, texte]].
var journal: Array = []
var regles := {}

var paume := {"gauche": null, "droite": null}
var _orient := {"gauche": null, "droite": null}
var _pose := {"gauche": {}, "droite": {}}
var _xf := {"gauche": Transform3D(), "droite": Transform3D()}
var _xf_ok := {"gauche": false, "droite": false}
var _repere_main := {"gauche": Basis(), "droite": Basis()}
var _doigts_repos := {}
var _bouclier: Node3D
var _aura := {"gauche": 0.0, "droite": 0.0}
var _ecole_aura := {"gauche": "", "droite": ""}
var _arme_enchantee: Node3D

func _ready() -> void:
	name = "Magie"
	joueur = mains.joueur
	Elements.joueur = joueur
	regles = EquipementMains._lire(EquipementMains.FICHIER_REGLES)
	eq = EquipementMains.new(mains.equipement, joueur.inventaire)
	eq.change.connect(_sur_change)
	lanceur = LanceurSorts.new(joueur, "ennemis")
	for m in MAINS:
		inc[m].main = m
	_actions()
	_preparer_os()
	joueur.touche.connect(_sur_touche)
	_signaler()

## Actions reconfigurables (InputMap) : main_droite, main_gauche, raccourci_1 … raccourci_0.
func _actions() -> void:
	var boutons := {"main_droite": MOUSE_BUTTON_LEFT, "main_gauche": MOUSE_BUTTON_RIGHT}
	for a in boutons:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var e := InputEventMouseButton.new()
			e.button_index = boutons[a]
			InputMap.action_add_event(a, e)
	var touches := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	for i in touches.size():
		var a := "raccourci_%d" % ((i + 1) % 10)
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var e := InputEventKey.new()
			e.physical_keycode = touches[i]
			InputMap.action_add_event(a, e)

# ------------------------------------------------------------------ entrées

## Appelé par mains._unhandled_input AVANT l'épée : vrai = l'événement est pris par la magie (l'épée ne le voit pas).
func intercepter(e: InputEvent) -> bool:
	if e is InputEventKey and e.pressed and not e.echo:
		for i in 10:
			if e.is_action_pressed("raccourci_%d" % ((i + 1) % 10)):
				raccourci(i)
				return true
		return false
	if not (e is InputEventMouseButton or e is InputEventKey or e is InputEventJoypadButton):
		return false
	if e.is_action("main_droite"):
		var cat := eq.categorie("droite")
		if cat.begins_with("arme"):
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				return false   # l'épée lit le clic gauche elle-même (mains.gd)
			if e.is_pressed():
				mains.entrees.appuyer()
			else:
				mains.entrees.relacher()
			return true
		if cat == "sort":
			if e.is_pressed():
				appuyer("droite")
			else:
				relacher("droite")
		return true   # main vide, bouclier… : rien (jamais une « épée invisible »)
	if e.is_action("main_gauche"):
		if eq.clic_droit_garde():
			return false   # garde (lue par garde_tenue)
		if eq.categorie("gauche") == "sort":
			if e.is_pressed():
				appuyer("gauche")
			else:
				relacher("gauche")
		return true
	return false

## Garde demandée (lue par mains.avancer) : bouton de la main gauche tenu ET règle « garde » de regles_mains.json.
func garde_tenue() -> bool:
	return eq.clic_droit_garde() and Input.is_action_pressed("main_gauche")

## Arme qui pare (le bouclier s'il est porté) : lu par mains.defendre.
func arme_de_garde(defaut: DonneesArme) -> DonneesArme:
	return eq.arme_de_garde(defaut)

func raccourci(i: int) -> void:
	for m in MAINS:
		_couper(m, false)
	var refuses := eq.raccourci(i)
	for r in refuses:
		_refuser(r[0], r[1])
	if i < eq.raccourcis.size():
		_noter("raccourci %s : %s" % [eq.raccourcis[i].get("touche", ""), eq.raccourcis[i].get("nom", "")])

func equiper(main: String, quoi: Variant) -> String:
	_couper(main, false)
	var r := eq.equiper(main, quoi)
	if r != "":
		_refuser(main, r)
	return r

# ------------------------------------------------------------------ incantation

## Appui sur le bouton d'une main qui tient un sort.
func appuyer(main: String) -> void:
	var i: Incantation = inc[main]
	i.tenu = true
	var s := eq.sort(main)
	if s == null:
		return
	if not i.libre():
		if i.etat == Incantation.RECUPERATION:
			i.tampon = horloge
		return
	var raison := _raison_indisponible(main, s)
	if raison == "memoriser":
		i.tampon = horloge   # coup d'épée en cours : l'appui est mémorisé (tampon_sort)
		return
	if raison != "":
		i.tenu = false
		_refuser(main, raison)
		return
	_commencer(main, s)

func relacher(main: String) -> void:
	inc[main].tenu = false

func _commencer(main: String, s: DonneesSort) -> void:
	var i: Incantation = inc[main]
	i.sort = s
	i.changer(Incantation.INCANTE)
	i.tampon = -1.0
	refus[main] = ""
	# double incantation : l'autre main a commencé LE MÊME sort il y a moins de la fenêtre de synchronisation
	var o: Incantation = inc[eq.autre(main)]
	var fenetre := float(regles.get("double", {}).get("fenetre", 0.15))
	if o.etat == Incantation.INCANTE and o.sort == s and o.t <= fenetre and not o.double and not s.double.is_empty():
		o.double = true
		o.meneuse = true
		i.double = true
		i.meneuse = false
		i.t = o.t
		EffetsMagie.double(s.ecole, true)
		_noter("double %s" % s.id)
	_noter("incante %s %s" % [main, s.id])

## "" = possible ; "memoriser" = coup d'épée en cours (appui gardé) ; sinon raison lisible du refus.
func _raison_indisponible(main: String, s: DonneesSort) -> String:
	if joueur.mort or joueur.en_dialogue:
		return "Impossible maintenant."
	if recharges.get(s.id, 0.0) > 0.0:
		return "Recharge : %.1f s" % recharges[s.id]
	var besoin := s.cout_par_seconde * 0.25 if s.canalise() else LanceurSorts.cout(s, 0.0)
	if joueur.mana + 0.001 < besoin:
		return "Pas assez de mana."
	if s.type == DonneesSort.Type.ENCHANT and eq.refus(main, s) != "":
		return eq.refus(main, s)
	# deux sorts différents à la fois : règles « simultane »
	var o: Incantation = inc[eq.autre(main)]
	if o.active() and o.sort != null:
		for r: Dictionary in regles.get("simultane", {}).get("incompatibles", []):
			if (r["a"] == s.id and r["b"] == o.sort.id) or (r["b"] == s.id and r["a"] == o.sort.id):
				return String(r.get("raison", "Incompatible avec l'autre main."))
	# épée + magie : pas de sort pendant un coup d'épée, ni au tout début de sa récupération
	var em: Dictionary = regles.get("epee_magie", {})
	if eq.categorie(eq.autre(main)).begins_with("arme"):
		var c: EtatCombat = mains.combat
		if c.attaque() and not em.get("sort_pendant_attaque", false):
			return "memoriser"
		if c.etat == EtatCombat.RECUPERATION and c.t < float(em.get("sort_apres_recuperation", 0.35)) * float(mains.get("_duree_recup")):
			return "memoriser"
		if c.etat == EtatCombat.DESEQUILIBRE:
			return "Déséquilibré."
	return ""

func _refuser(main: String, raison: String) -> void:
	if raison.begins_with("Pas assez de mana") or raison.begins_with("Mana épuisé"):
		SonsMagie.refus_mana()
	refus[main] = raison
	joueur.action_refusee.emit(main, raison)
	_noter("refus %s : %s" % [main, raison])

## Coupe l'incantation d'une main. `interruption` : par un coup reçu (récupération plus longue, message).
func _couper(main: String, interruption: bool) -> void:
	var i: Incantation = inc[main]
	if i.etat == Incantation.REPOS:
		return
	var s := i.sort
	lanceur.arreter_jet(s, paume[main], main)
	if i.double:
		EffetsMagie.double(s.ecole if s != null else "", false)
		i.double = false
		var autre := eq.autre(main)
		var o: Incantation = inc[autre]
		if o.double:
			o.double = false
			if o.active():
				lanceur.arreter_jet(o.sort, paume[autre], autre)
				o.duree_recup = 0.25
				o.changer(Incantation.RECUPERATION)
	if i.active():
		i.duree_recup = 0.5 if interruption else 0.2
		i.interrompue = interruption
		i.changer(Incantation.RECUPERATION)
	if interruption:
		_refuser(main, "Incantation interrompue.")

func interrompre(cause := "coup") -> void:
	for m in MAINS:
		if inc[m].active():
			_couper(m, true)
	_noter("interrompu (%s)" % cause)

## Coup reçu (signal joueur.touche) : coupe une incantation dont le seuil est atteint (la protection n'est jamais coupée).
func _sur_touche(degats: float) -> void:
	for m in MAINS:
		var i: Incantation = inc[m]
		if i.active() and i.sort != null and degats >= i.sort.seuil_interruption:
			_couper(m, true)

func charge(main: String) -> float:
	var i: Incantation = inc[main]
	if i.etat == Incantation.CHARGE:
		return i.charge
	return 0.0

# ------------------------------------------------------------------ une image

## Appelée par mains.avancer à la FIN de chaque image (après la pose de l'épée).
func avancer(dt: float) -> void:
	horloge += dt
	lanceur.avancer(dt)
	for k in recharges.keys():
		recharges[k] = float(recharges[k]) - dt
		if recharges[k] <= 0.0:
			recharges.erase(k)
	_avancer_enchantement(dt)
	var deux_canal: bool = inc["gauche"].etat == Incantation.CANALISE and inc["droite"].etat == Incantation.CANALISE and not inc["gauche"].double
	for m in MAINS:
		_avancer_main(m, dt, deux_canal)
	if inc["gauche"].active() or inc["droite"].active():
		joueur.retenir_mana()
	_poser_mains(dt)

func _avancer_main(m: String, dt: float, deux_canal: bool) -> void:
	var i: Incantation = inc[m]
	var s := eq.sort(m)
	i.t += dt
	i.depuis_lancement += dt
	if s == null:
		if i.etat != Incantation.REPOS:
			_couper(m, false)
			i.changer(Incantation.REPOS)
		_aura_vers(m, "", 0.0, dt)
		return
	if i.sort != null and i.sort != s and i.etat != Incantation.REPOS:
		_couper(m, false)
	# épée + magie : une attaque d'épée coupe la canalisation de l'autre main (règle attaque_coupe_canalisation)
	if i.etat == Incantation.CANALISE and eq.categorie(eq.autre(m)).begins_with("arme") and mains.combat.attaque() \
			and regles.get("epee_magie", {}).get("attaque_coupe_canalisation", true):
		_couper(m, false)
	var suiveuse := i.double and not i.meneuse
	var o: Incantation = inc[eq.autre(m)]
	if suiveuse:
		# la main suiveuse reprend l'état de la meneuse ; si la meneuse a fini, elle se repose
		if not o.double:
			i.double = false
			i.changer(Incantation.RECUPERATION if i.active() else i.etat)
		else:
			i.etat = o.etat
			i.charge = o.charge
			i.depuis_lancement = o.depuis_lancement
			if not i.tenu and o.tenu and i.etat in [Incantation.CHARGE, Incantation.CANALISE]:
				o.tenu = false   # double : relâcher l'une des deux mains termine le sort
		_aura_vers(m, s.ecole, _intensite(o, s) if o.double else 0.0, dt)
		return
	var sd := LanceurSorts.version_double(s) if i.double else s
	if i.double and not o.tenu and i.etat in [Incantation.CHARGE, Incantation.CANALISE]:
		i.tenu = false
	match i.etat:
		Incantation.REPOS:
			if i.tampon >= 0.0 and horloge - i.tampon <= float(regles.get("epee_magie", {}).get("tampon_sort", 0.35)):
				if _raison_indisponible(m, s) == "":
					_commencer(m, s)
			elif i.tampon >= 0.0:
				i.tampon = -1.0
		Incantation.INCANTE:
			if i.t >= s.incantation:
				if s.canalise():
					if i.tenu:
						i.changer(Incantation.CANALISE)
						_noter("canalise %s %s%s" % [m, s.id, " double" if i.double else ""])
					else:
						# un appui bref sur un sort canalisé : courte bouffée (0,25 s)
						i.changer(Incantation.CANALISE)
						i.t = -0.25
				elif s.se_charge():
					if i.tenu:
						i.changer(Incantation.CHARGE)
					else:
						_lancer(m, sd, 0.0)
				else:
					_lancer(m, sd, 1.0)
		Incantation.CHARGE:
			var tc := maxf(s.temps_charge, 0.01)
			i.charge = clampf(i.t / tc, 0.0, 1.0)
			if not i.tenu:
				_lancer(m, sd, i.charge)
		Incantation.CANALISE:
			var mult := float(regles.get("simultane", {}).get("mult_deux_canalisations", 1.15)) if deux_canal else 1.0
			var cout := sd.cout_par_seconde * dt * mult
			if not joueur.depenser_mana(cout):
				_couper(m, false)
				_refuser(m, "Mana épuisé.")
				return
			var vue := _vue()
			lanceur.canaliser(sd, paume[m], vue[0], vue[1], dt, m)
			if not i.tenu and i.t >= 0.0:
				_couper(m, false)
				_noter("fin canalisation %s" % m)
		Incantation.RECUPERATION:
			if i.t >= i.duree_recup:
				var tampon := i.tampon
				i.changer(Incantation.REPOS)
				i.tampon = tampon
	_aura_vers(m, s.ecole, _intensite(i, s), dt)
	if i.double and i.etat in [Incantation.RECUPERATION, Incantation.REPOS]:
		EffetsMagie.double(s.ecole, false)
		i.double = false

func _intensite(i: Incantation, s: DonneesSort) -> float:
	var k := 0.35
	match i.etat:
		Incantation.INCANTE:
			k = 0.35 + 0.4 * clampf(i.t / maxf(s.incantation, 0.01), 0.0, 1.0)
		Incantation.CHARGE:
			k = 0.6 + 0.4 * i.charge
		Incantation.CANALISE:
			k = 1.0
		Incantation.RECUPERATION:
			k = 0.25
	return k * (1.5 if i.double else 1.0)

func _aura_vers(m: String, ecole: String, k: float, _dt: float) -> void:
	if ecole != _ecole_aura[m] or absf(k - _aura[m]) > 0.02:
		_aura[m] = k
		_ecole_aura[m] = ecole
		if paume[m] != null:
			EffetsMagie.aura_main(paume[m], ecole, k)

## Œil et direction de visée (caméra du joueur).
func _vue() -> Array:
	var cam: Camera3D = joueur.camera
	return [cam.global_position, -cam.global_transform.basis.z]

func _lancer(m: String, s: DonneesSort, charge: float) -> void:
	var i: Incantation = inc[m]
	var cout := LanceurSorts.cout(s, charge)
	if not joueur.depenser_mana(cout):
		# pas assez pour la charge atteinte : on lance ce que le mana permet (au minimum la charge nulle)
		var c0 := LanceurSorts.cout(s, 0.0)
		if s.se_charge() and joueur.mana >= c0:
			charge = clampf((joueur.mana - c0) / maxf(LanceurSorts.cout(s, 1.0) - c0, 0.01), 0.0, 1.0)
			joueur.depenser_mana(LanceurSorts.cout(s, charge))
		else:
			_couper(m, false)
			_refuser(m, "Pas assez de mana.")
			return
	if s.type == DonneesSort.Type.ENCHANT:
		_enchanter(s)
	else:
		var vue := _vue()
		lanceur.lancer(s, paume[m], vue[0], vue[1], charge)
	if s.recharge > 0.0:
		recharges[s.id] = s.recharge
	i.depuis_lancement = 0.0
	i.duree_recup = s.recuperation
	i.changer(Incantation.RECUPERATION)
	if i.double:
		i.double = true   # la suiveuse suit jusqu'à la fin de la récupération
	_noter("lance %s %s charge=%.2f%s" % [m, s.id, charge, " double" if i.double else ""])

# ------------------------------------------------------------------ enchantement (phase 5)

func _enchanter(s: DonneesSort) -> void:
	if not enchantement.is_empty() and is_instance_valid(_arme_enchantee):
		EffetsMagie.enchant_arme(_arme_enchantee, (enchantement["sort"] as DonneesSort).ecole, false)
	enchantement = {"sort": s, "reste": s.duree_enchant}
	var a = mains.get("_modele_arme_d")
	_arme_enchantee = a if is_instance_valid(a) else null
	if _arme_enchantee != null:
		EffetsMagie.enchant_arme(_arme_enchantee, s.ecole, true)
	_noter("enchantement %s" % s.id)

func enchantement_actif() -> Dictionary:
	if enchantement.is_empty() or not eq.categorie("droite").begins_with("arme"):
		return {}
	return enchantement

func _avancer_enchantement(dt: float) -> void:
	if enchantement.is_empty():
		return
	enchantement["reste"] = float(enchantement["reste"]) - dt
	if not is_instance_valid(_arme_enchantee):
		_arme_enchantee = null   # le modèle de l'épée a été libéré (changement d'arme)
	var arme_v = mains.get("_modele_arme_d")
	var arme: Node3D = arme_v if is_instance_valid(arme_v) else null
	if float(enchantement["reste"]) <= 0.0 or not eq.categorie("droite").begins_with("arme"):
		if _arme_enchantee != null:
			EffetsMagie.enchant_arme(_arme_enchantee, (enchantement["sort"] as DonneesSort).ecole, false)
		enchantement = {}
		_arme_enchantee = null
		_noter("fin enchantement")
	elif arme != _arme_enchantee and arme != null:
		# l'épée a changé de modèle (Skarnholt…) : l'enchantement passe sur la nouvelle
		_arme_enchantee = arme
		EffetsMagie.enchant_arme(arme, (enchantement["sort"] as DonneesSort).ecole, true)

## Bonus du coup d'épée qui suit un sort sur la même cible (Elements.avant_coup).
func bonus_apres_sort(cible: Node) -> float:
	var em: Dictionary = regles.get("epee_magie", {})
	return lanceur.bonus_apres_sort(cible, float(em.get("fenetre_combo_apres_sort", 1.2)), float(em.get("bonus_combo_apres_sort", 1.15)))

# ------------------------------------------------------------------ protection

## Coup reçu par le joueur (joueur.recevoir_coup) : une protection canalisée de face en absorbe une part contre du mana.
func absorber(degats: float, origine: Vector3, options: Dictionary) -> float:
	for m in MAINS:
		var i: Incantation = inc[m]
		var s := eq.sort(m)
		if s == null or i.etat != Incantation.CANALISE or s.reduction_physique <= 0.0 or (i.double and not i.meneuse):
			continue
		var sd := LanceurSorts.version_double(s) if i.double else s
		var vers := origine - joueur.global_position
		vers.y = 0.0
		var avant := -joueur.global_transform.basis.z
		if vers.length() > 0.01 and rad_to_deg(avant.angle_to(vers.normalized())) > sd.cone * 0.5:
			continue
		var magique := String(options.get("type", "")) in ["feu", "glace", "electricite", "tenebres", "magique"]
		var part := sd.reduction_magique if magique else sd.reduction_physique
		var absorbe := degats * part
		var cout := absorbe * sd.mana_par_absorbe
		if joueur.mana < cout:
			absorbe = joueur.mana / maxf(sd.mana_par_absorbe, 0.001)
			cout = joueur.mana
		joueur.depenser_mana(cout)
		EffetsMagie.impact("protection", joueur.global_position + Vector3(0, 1.4, 0) + vers.normalized() * 0.6, vers.normalized(), absorbe / 10.0)
		_noter("protection absorbe %.1f" % absorbe)
		return degats - absorbe
	return degats

## Effets actifs du joueur (HUD) : protection, enchantement, double, lenteur.
func statuts_actifs() -> Array:
	var r := []
	for m in MAINS:
		var i: Incantation = inc[m]
		if i.etat == Incantation.CANALISE and i.sort != null and i.sort.ecole == "protection":
			r.append({"nom": "protection", "duree": -1.0, "ecole": "protection"})
		if i.double and i.meneuse and i.sort != null:
			r.append({"nom": "double", "duree": -1.0, "ecole": i.sort.ecole})
	if not enchantement.is_empty():
		var s: DonneesSort = enchantement["sort"]
		r.append({"nom": s.id, "duree": float(enchantement["reste"]), "ecole": s.ecole})
	if joueur.lenteur > 0.0:
		r.append({"nom": "lenteur", "duree": joueur.lenteur, "ecole": "glace"})
	return r

# ------------------------------------------------------------------ HUD et sauvegarde

func _sur_change(_main: String) -> void:
	_signaler()

func _signaler() -> void:
	joueur.etat_mains_change.emit(eq.resume("gauche"), eq.resume("droite"))

func exporter() -> Dictionary:
	var d := eq.exporter()
	d["mana"] = joueur.mana
	if not enchantement.is_empty():
		d["enchantement"] = [(enchantement["sort"] as DonneesSort).id, enchantement["reste"]]
	return d

func importer(d: Dictionary) -> void:
	if d.is_empty():
		return
	eq.importer(d)
	joueur.mana = clampf(float(d.get("mana", joueur.mana_max)), 0.0, joueur.mana_max)
	var en: Array = d.get("enchantement", [])
	if en.size() == 2 and eq.sort_par_id(String(en[0])) != null:
		_enchanter(eq.sort_par_id(String(en[0])))
		enchantement["reste"] = float(en[1])
	_signaler()

func _noter(texte: String) -> void:
	journal.append([snappedf(horloge, 0.001), texte])
	if journal.size() > 400:
		journal.pop_front()

# ------------------------------------------------------------------ poses des mains (fichier PosesIncantation)

## Repères de l'os de chaque main (doigts, paume) et nœuds « paume » d'où partent les sorts.
func _preparer_os() -> void:
	var sq: Skeleton3D = mains.get("_sq")
	if sq == null:
		return
	for m in MAINS:
		var c := "l" if m == "gauche" else "r"
		var i01 := sq.find_bone("middle_01_" + c)
		var i02 := sq.find_bone("middle_02_" + c)
		var ii := sq.find_bone("index_01_" + c)
		var ip := sq.find_bone("pinky_01_" + c)
		if i01 < 0 or i02 < 0 or ii < 0 or ip < 0:
			continue
		var r01 := sq.get_bone_rest(i01)
		var d := r01.origin.normalized()
		var doigts: Dictionary = mains.get("_doigts")
		var poing01: Quaternion = doigts.get(i01, r01.basis.get_rotation_quaternion())
		var bout_poing := r01.origin + Basis(poing01) * sq.get_bone_rest(i02).origin
		var bout_ouvert := r01.origin + r01.basis * sq.get_bone_rest(i02).origin
		var n := bout_poing - bout_ouvert
		n = (n - d * n.dot(d)).normalized()
		_repere_main[m] = Basis(d, n.cross(d).normalized(), n).orthonormalized()   # colonnes : doigts, travers, paume
		# nœud « paume » : au creux de la main, un peu devant la paume
		var p := Node3D.new()
		p.name = "Paume_" + m
		var accroche: Node3D = mains.get("_accroche_g" if m == "gauche" else "_accroche_d")
		accroche.add_child(p)
		p.position = (r01.origin * 0.55 + sq.get_bone_rest(ii).origin * 0.15 + sq.get_bone_rest(ip).origin * 0.15) + n * 0.035
		paume[m] = p
	for i in sq.get_bone_count():
		var nom := sq.get_bone_name(i)
		if nom.begins_with("thumb") or nom.begins_with("index") or nom.begins_with("middle") or nom.begins_with("ring") or nom.begins_with("pinky"):
			_doigts_repos[i] = sq.get_bone_rest(i).basis.get_rotation_quaternion()
	for o in sq.get_children():
		if o is SkeletonModifier3D and o.get_script() == ORIENTATION:
			_orient["gauche" if String(o.get("os")) == "hand_l" else "droite"] = o

## Pose voulue d'une main ({} = la main n'est pas à nous : épée, torche… restent à mains.gd).
func _pose_voulue(m: String) -> Dictionary:
	var cat := eq.categorie(m)
	var o := eq.autre(m)
	if cat == "bouclier":
		return PosesIncantation.pose("bouclier_garde" if mains.bloque else "bouclier", m)
	if cat != "sort":
		return {}
	var i: Incantation = inc[m]
	var s := eq.sort(m)
	var p := PosesIncantation.pour(i.nom(), s.profil if s != null else "paume", i.charge, i.depuis_lancement, i.t, m)
	# l'épée de l'autre main frappe : la main du sort s'écarte (contrepoids), sauf si elle canalise
	if eq.categorie(o).begins_with("arme") and (mains.combat.attaque() or mains.combat.etat == EtatCombat.RECUPERATION) and i.etat != Incantation.CANALISE:
		var k := 1.0 if mains.combat.attaque() else clampf(1.0 - mains.combat.t / maxf(float(mains.get("_duree_recup")), 0.05), 0.0, 1.0)
		p = PosesIncantation.melange(p, PosesIncantation.pose("ecartee", m), k * 0.85)
	if i.double:
		p = p.duplicate()
		var v: Vector3 = p["pos"]
		p["pos"] = v + Vector3(PosesIncantation.RAPPROCHE_DOUBLE * (1.0 if m == "gauche" else -1.0), 0.0, 0.0)
	if i.etat in [Incantation.CANALISE] or (i.etat == Incantation.CHARGE and i.charge >= 1.0):
		p = p.duplicate()
		p["pos"] = Vector3(p["pos"]) + Vector3(sin(horloge * 53.0), cos(horloge * 47.0), 0.0) * PosesIncantation.TREMBLE
	return p

func _poser_mains(dt: float) -> void:
	var sq: Skeleton3D = mains.get("_sq")
	if sq == null:
		return
	var ik_d = mains.get("_ik_d")   # bras droit : clips à images clés, sauf quand un sort l'occupe (IK allumée ici)
	for m in MAINS:
		var p := _pose_voulue(m)
		var o = _orient[m]
		var pivot: Node3D = mains.get("pivot_torche" if m == "gauche" else "pivot_epee")
		if m == "droite":
			if ik_d != null:
				ik_d.active = not p.is_empty()
				var couche = mains.get("_couche_passive")
				if ik_d.active and couche != null:
					couche.decalage = Transform3D()   # passifs déjà dans la cible (dec ci-dessous) : pas de double couche
			if o != null:
				o.active = not p.is_empty()
		if p.is_empty():
			_xf_ok[m] = false
			if o != null:
				o.angle_min = -1.0
				o.angle_max = -1.0
				o.flexion_max = deg_to_rad(55.0)
			continue
		# repère voulu de la main (caméra) : colonnes doigts / travers / paume, comme _repere_main
		var dg: Vector3 = (p["doigts"] as Vector3).normalized()
		var pa: Vector3 = (p["paume"] as Vector3)
		pa = (pa - dg * pa.dot(dg)).normalized()
		var voulu: Basis = Basis(dg, pa.cross(dg).normalized(), pa) * _repere_main[m].inverse()
		var xf := Transform3D(voulu.orthonormalized(), p["pos"])
		if not _xf_ok[m]:
			_xf[m] = xf
			_xf_ok[m] = true
		var k := 1.0 - exp(-16.0 * dt)
		var a: Transform3D = _xf[m]
		_xf[m] = Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(xf.basis.get_rotation_quaternion(), k)), a.origin.lerp(xf.origin, k))
		var passifs = mains.get("passifs")
		var dec: Transform3D = passifs.decalage_g if m == "gauche" else passifs.decalage_d
		var prise: Transform3D = mains.get("PRISE_G" if m == "gauche" else "PRISE_D")
		pivot.transform = dec * _xf[m] * prise
		if o != null:
			o.angle_min = 0.0
			o.angle_max = PI
			o.flexion_max = PI
		var coude: Node3D = mains.get("_coude_g" if m == "gauche" else "_coude_d")
		coude.position = Vector3(-0.75 if m == "gauche" else 0.75, -0.55, 0.25)
		_poser_doigts(sq, m, float(p["fermeture"]))
	# objets de la main gauche : torche seulement si c'est elle ; bouclier dessiné ici (pas de modèle .glb)
	var porte: Node3D = mains.get("porte_torche")
	if porte != null:
		porte.visible = eq.categorie("gauche") == "torche"
	_afficher_bouclier(eq.categorie("gauche") == "bouclier")

func _poser_doigts(sq: Skeleton3D, m: String, fermeture: float) -> void:
	var suffixe := "_l" if m == "gauche" else "_r"
	var poings: Dictionary = mains.get("_doigts")
	for i in _doigts_repos:
		if not sq.get_bone_name(i).ends_with(suffixe):
			continue
		var q: Quaternion = _doigts_repos[i]
		sq.set_bone_pose_rotation(i, q.slerp(poings.get(i, q), clampf(fermeture, 0.0, 1.0)))

func _afficher_bouclier(oui: bool) -> void:
	if not oui:
		if _bouclier != null:
			_bouclier.visible = false
		return
	if _bouclier == null:
		var accroche: Node3D = mains.get("_accroche_g")
		_bouclier = Node3D.new()
		_bouclier.name = "Bouclier"
		accroche.add_child(_bouclier)
		var bois := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.3
		c.bottom_radius = 0.3
		c.height = 0.035
		c.radial_segments = 14
		c.rings = 1
		bois.mesh = c
		var mb := StandardMaterial3D.new()
		mb.albedo_color = Color(0.36, 0.24, 0.14)
		bois.material_override = mb
		_bouclier.add_child(bois)
		var umbo := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.07
		sp.height = 0.07
		sp.radial_segments = 8
		sp.rings = 3
		umbo.mesh = sp
		var mu := StandardMaterial3D.new()
		mu.albedo_color = Color(0.55, 0.56, 0.6)
		mu.metallic = 0.8
		umbo.material_override = mu
		umbo.position = Vector3(0, 0.02, 0)
		_bouclier.add_child(umbo)
	_bouclier.visible = true
	# disque tourné vers l'avant (face au coup), centré devant le poing : repère voulu dans l'espace des mains, ramené dans
	# celui de la main (le bouclier ne dépend pas de l'orientation du poignet)
	var garde: bool = mains.bloque
	var normale := Vector3(0.25, 0.05, -1.0).normalized() if garde else Vector3(0.55, 0.15, -1.0).normalized()
	var haut := (Vector3.UP - normale * normale.dot(Vector3.UP)).normalized()
	var voulu := Transform3D(Basis(haut.cross(-normale).normalized(), -normale, -haut).orthonormalized(), (_xf["gauche"] as Transform3D).origin + normale * 0.07)
	_bouclier.transform = (_xf["gauche"] as Transform3D).affine_inverse() * voulu
