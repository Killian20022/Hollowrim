class_name Sommeil
extends Node
## Lits, sommeil et attente (lot « sommeil », retours exe 5). Frère de Vie, branché par une ligne dans monde._villageois().
##   - pose un `Lit` sur chaque Marker3D du groupe « emplacement_lit » (meta « proprietaire », « largeur », « longueur », « peau »,
##     « foyer » ; -Z = pied, origine = centre au sol), y compris ceux ajoutés plus tard (balayage toutes les secondes) ;
##   - attribue les lits aux civils (Vie) : le sien (propriétaire), sinon une place libre d'un lit sans propriétaire de son foyer ;
##   - joueur : un lit (E) ou « Attendre » (action « attendre », T) ouvre la fenêtre en parchemin (1 à 24 h) ; fondu au noir, le temps
##     avance (cycle), PNJ (Vie), faune et marchands sont posés à la nouvelle heure, vie / magie / vigueur se refont, bonus « reposé » ;
##     refusé en combat ou si un ennemi rôde ; dormir dans le lit d'un autre : un témoin éveillé le signale au nœud du groupe « crime »
##     (`signaler_intrusion(lit, proprietaire)`) s'il existe ;
##   - sauvegarde (clé `sommeil`) : bonus de repos en cours, lits loués. Les dormeurs se recalculent depuis l'heure (Vie).

const GROUPE_MARQUEURS := "emplacement_lit"
const R_ENNEMI := 25.0            # m : un hostile vivant plus près interdit de dormir / d'attendre
const R_TEMOIN := 14.0            # m : un PNJ éveillé plus près voit l'intrusion (dans le même intérieur s'il y en a un)
const REPOS := {"repose": {"nom": "Reposé", "bonus": 0.10, "duree": 8.0}, "bien_repose": {"nom": "Bien reposé", "bonus": 0.15, "duree": 12.0}}
const HEURES_REPOS := 4           # au moins tant d'heures de sommeil pour être reposé
const T_FONDU := 0.8

var monde: Node3D
var joueur: CharacterBody3D
var village: Node3D
var lits: Array = []              # Lit
var _reserve := {}                # "<instance du lit>:<place>" -> id du civil
var _attrib := {}                 # id du civil -> [Lit, place]
var _scan_t := 0.0
var fenetre: FenetreSommeil
var repos := ""                   # "" | "repose" | "bien_repose"
var repos_reste := 0.0            # heures de jeu
var _h_prec := -1.0
var _en_cours := false            # fondu en cours
var _ecran: CanvasLayer
var _noir: ColorRect
var _texte: Label
var dernier := {}                 # dernier sommeil (tests) : {heures, mode, h0, h1, lit, temoin}

signal dormi(heures: int, mode: String)

static func installer(monde_: Node3D) -> Sommeil:
	var s := Sommeil.new()
	s.name = "Sommeil"
	s.monde = monde_
	s.joueur = monde_.get("joueur")
	s.village = monde_.get("village")
	monde_.add_child(s)
	return s

static func trouver(n: Node) -> Sommeil:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group("sommeil") as Sommeil

func _ready() -> void:
	add_to_group("sommeil")
	process_mode = Node.PROCESS_MODE_ALWAYS          # la fenêtre met l'arbre en pause ; le fondu tourne hors pause
	fenetre = FenetreSommeil.new()
	fenetre.choisi.connect(_sur_choix)
	add_child(fenetre)
	_ecran = CanvasLayer.new()
	_ecran.layer = 47
	add_child(_ecran)
	_noir = ColorRect.new()
	_noir.color = Color(0, 0, 0, 0)
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecran.add_child(_noir)
	_texte = MenuStyle.etiquette("", Parchemin.TEXTE_CUIR)
	_texte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texte.add_theme_font_override("font", MenuStyle.police_gothique(true))
	_texte.add_theme_font_size_override("font_size", Parchemin.TITRE)
	_texte.modulate.a = 0.0
	_ecran.add_child(_texte)
	scanner()

func _process(dt: float) -> void:
	if get_tree().paused:
		return
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 1.0
		scanner()
	# bonus de repos : décompté en heures de jeu
	var c: Node = monde.get("cycle") if monde != null else null
	if c != null:
		var h := float(c.heure)
		if _h_prec >= 0.0 and repos != "":
			var dh := fposmod(h - _h_prec, 24.0)
			if dh < 2.0:
				repos_reste -= dh
				if repos_reste <= 0.0:
					_fin_repos()
		_h_prec = h

func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed("attendre", false) or get_tree().paused or _en_cours or fenetre.ouvert:
		return
	if joueur == null or joueur.mort or bool(joueur.get("en_dialogue")) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return
	var hud: Node = monde.get("hud")
	if hud != null and hud.get("panneau_ouvert"):
		return
	get_viewport().set_input_as_handled()
	demander("attendre")

# ======================================================================================================== lits

## Pose un Lit sur chaque marqueur qui n'en a pas encore (appelé toutes les secondes : les intérieurs se posent par étapes).
func scanner() -> void:
	if not is_inside_tree():
		return
	var nouveaux := false
	for m: Node in get_tree().get_nodes_in_group(GROUPE_MARQUEURS):
		var mk := m as Node3D
		if mk == null or not mk.is_inside_tree() or mk.has_meta("lit_pose"):
			continue
		mk.set_meta("lit_pose", true)
		if _doublon(mk.global_position):
			continue        # un autre lot a posé un marqueur au même endroit : un seul lit
		var mats: Dictionary = village.get("mats_int") if village != null and village.get("mats_int") is Dictionary else {}
		var l := Lit.creer(float(mk.get_meta("largeur", 1.0)), String(mk.get_meta("proprietaire", "")), mats, String(mk.get_meta("peau", "peau")),
			float(mk.get_meta("longueur", Lit.LONG)))
		l.foyer = String(mk.get_meta("foyer", "")) if mk.has_meta("foyer") else _foyer_de(mk)
		if l.proprietaire == "auberge":
			l.loue = String(mk.get_meta("loue", "false")) == "true"
		mk.add_child(l)
		_interactif(l)
		lits.append(l)
		l.tree_exiting.connect(_oublier.bind(l))     # contenu d'un intérieur à la demande libéré : le lit sort de la liste
		_rattacher(l)
		nouveaux = true
		_reserve.clear()           # nouvelles places : attributions refaites au prochain coucher
		_attrib.clear()
	var v: Node = monde.get("vie") if nouveaux and monde != null else null
	if v != null and v.has_method("lits_poses"):
		v.lits_poses()             # intérieur posé à la demande : ses dormeurs cachés se couchent dans leur lit

## Lit retiré de l'arbre (intérieur à la demande déchargé) : il n'est plus proposé à personne ; il sera reposé au rechargement.
func _oublier(l: Lit) -> void:
	lits.erase(l)
	for id: String in _attrib.keys():
		if _attrib[id][0] == l:
			_attrib.erase(id)
	var pre := "%d:" % l.get_instance_id()
	for cle: String in _reserve.keys():
		if cle.begins_with(pre):
			_reserve.erase(cle)

## Intérieur à la demande rechargé (BatimentsOuverts) : son lit est un nouveau `Lit` ; le civil resté couché dans l'ancien (libéré
## avec le contenu pendant que le joueur était loin) y est rattaché, à sa place.
func _rattacher(l: Lit) -> void:
	for n: Node in get_tree().get_nodes_in_group("villageois"):
		if not n.has_method("au_lit") or not n.au_lit() or is_instance_valid(n.get("lit")):
			continue
		var k := int(n.get("place_lit"))
		if k < l.places() and l.occupants[k] == null and (n as Node3D).global_position.distance_to(l.global_position) < 1.6:
			n.set("lit", l)
			l.occupants[k] = n

func _doublon(p: Vector3) -> bool:
	for l: Lit in lits:
		if is_instance_valid(l) and l.global_position.distance_to(p) < 0.8:
			return true
	return false

## Bâtiment du marqueur : l'intérieur (Interieur) qui le contient, sous son id de village (halle, sigrun…).
func _foyer_de(n: Node) -> String:
	var p := n.get_parent()
	while p != null and not (p is Interieur):
		p = p.get_parent()
	if p == null:
		return ""
	if (p as Interieur).id != "":
		return (p as Interieur).id
	if village == null or not village.has_method("interieur"):
		return ""
	var noms: Dictionary = village.get("NOMS_BATIMENTS") if village.get("NOMS_BATIMENTS") is Dictionary else {}
	for id: String in noms:
		if village.interieur(id) == p:
			return id
	return String((p as Interieur).nom)

func interieur_de(l: Lit) -> Interieur:
	var p := l.get_parent()
	while p != null and not (p is Interieur):
		p = p.get_parent()
	return p as Interieur

func _interactif(l: Lit) -> void:
	var dlg: Control = monde.get("dialogue")
	if joueur == null or dlg == null:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dlg
	it.nom = l.nom_affiche(_noms())
	it.verbe = "Dormir"
	it.rayon = 1.7
	it.position = Vector3(0, 0.75, 0)
	it.condition = func() -> bool: return not _en_cours and l.place_libre() >= 0
	it.action = func() -> Array:
		it.nom = l.nom_affiche(_noms())
		demander("dormir", l)
		return []
	l.add_child(it)
	l.interactif = it

## Noms affichés des PNJ (id -> nom) pour « Lit de Sigrún ».
func _noms() -> Dictionary:
	var d := {}
	for n: Node in get_tree().get_nodes_in_group("villageois"):
		if n.get("donnees") is Dictionary:
			d[String(n.donnees.get("id", ""))] = String(n.donnees.get("nom", ""))
	return d

## Lit et place d'un civil : son lit (propriétaire), sinon une place d'un lit libre de son foyer ; [] s'il n'y en a pas (il dort caché).
func lit_pour(id: String, foyer: String) -> Array:
	scanner()                    # marqueurs posés depuis le dernier balayage (intérieurs posés par étapes)
	if _attrib.has(id):
		var a: Array = _attrib[id]
		if is_instance_valid(a[0]):
			return a
	var choix: Array = []
	for l: Lit in lits:
		if is_instance_valid(l) and l.a_pour_proprietaire(id):
			var k := mini(l.proprietaires.find(id), l.places() - 1)
			choix = [l, k]
			break
	if choix.is_empty() and foyer != "":
		for l: Lit in lits:
			if not is_instance_valid(l) or l.foyer != foyer or not l.libre():
				continue
			for k in l.places():
				var cle := "%d:%d" % [l.get_instance_id(), k]
				if not _reserve.has(cle):
					choix = [l, k]
					break
			if not choix.is_empty():
				break
	if choix.is_empty():
		return []
	_reserve["%d:%d" % [choix[0].get_instance_id(), choix[1]]] = id
	_regler_cotes(choix[0])
	_attrib[id] = choix
	return choix

## Côté par où l'on monte dans chaque place : celui où un corps tient debout (pas contre un mur, ni dans un meuble).
func _regler_cotes(l: Lit) -> void:
	if l.has_meta("cotes_regles") or not l.is_inside_tree():
		return
	l.set_meta("cotes_regles", true)
	var ip := interieur_de(l)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	var espace := l.get_world_3d().direct_space_state
	for i in l.places():
		var pref: float = l.cotes_libres[i]
		var ok := {}
		for cote in [pref, -pref]:
			var p := l.pose_assise(i, cote).origin
			p += l.pose_assise(i, cote).basis.z * 0.12
			var dedans := ip == null or ip.dedans(ip.to_local(p), -0.2)
			var qs := PhysicsShapeQueryParameters3D.new()
			qs.shape = capsule
			qs.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
			qs.exclude = [l.get_rid()]
			var libre := true
			for h in espace.intersect_shape(qs, 6):
				if not (h["collider"] is CharacterBody3D):
					libre = false
					break
			ok[cote] = dedans and libre
		l.cotes_libres[i] = pref if ok[pref] or not ok[-pref] else -pref

## Point juste derrière la porte du foyer (dedans, 1,1 m), et centre de la porte (monde).
func porte_interieure(foyer: String) -> Vector3:
	var ip: Interieur = village.interieur(foyer) if village != null and village.has_method("interieur") else null
	if ip == null:
		return Vector3.ZERO
	return ip.to_global(Vector3(ip.porte_locale.x, ip.sol_y, ip.porte_locale.z - 1.15))

func centre_porte(foyer: String) -> Vector3:
	var ip: Interieur = village.interieur(foyer) if village != null and village.has_method("interieur") else null
	return ip.to_global(Vector3(ip.porte_locale.x, ip.sol_y, ip.porte_locale.z)) if ip != null else Vector3.ZERO

# ======================================================================================================== joueur

## Raison du refus ("" = possible) de dormir (`lit`) ou d'attendre (lit null).
func refus(lit: Lit = null) -> String:
	var verbe := "dormir" if lit != null else "attendre"
	if joueur == null or joueur.mort:
		return "Impossible maintenant."
	if _en_cours:
		return "Impossible maintenant."
	if monde.has_method("en_combat") and monde.en_combat():
		return "Impossible de %s en plein combat." % verbe
	if ennemi_proche() != null:
		return "Impossible de %s : des ennemis rôdent tout près." % verbe
	if lit != null and lit.place_libre() < 0:
		return "Ce lit est occupé."
	if lit == null and not joueur.is_on_floor():
		return "Impossible d'attendre en l'air."
	return ""

## Hostile vivant à moins de R_ENNEMI m (ni faune paisible, ni garde du village).
func ennemi_proche() -> Node3D:
	var p := joueur.global_position
	for e: Node in get_tree().get_nodes_in_group("ennemis"):
		var n3 := e as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.visible and not (e.has_method("en_combat") and e.en_combat()):
			continue
		if e.is_in_group("faune") or e.is_in_group("gardes_village"):
			continue
		if e.has_method("vivant") and not e.vivant():
			continue
		if n3.process_mode == Node.PROCESS_MODE_DISABLED:
			continue        # gelé (loin, sous terre) : il ne rôde pas
		if n3.global_position.distance_to(p) < R_ENNEMI and absf(n3.global_position.y - p.y) < 8.0:
			return n3
	return null

## Ouvre la fenêtre « Dormir » (lit) ou « Attendre » ; refus = avis du HUD.
func demander(mode: String, lit: Lit = null) -> String:
	var r := refus(lit)
	if r != "":
		_avis(r)
		return r
	var c: Node = monde.get("cycle")
	var sous := lit.nom_affiche(_noms()) if lit != null else "Laisser passer le temps"
	if lit != null and _intrus(lit):
		sous += " — ce n'est pas le vôtre"
	fenetre.ouvrir(mode, sous, float(c.heure) if c != null else 12.0, 8 if mode == "dormir" else 1, lit)
	return ""

func _sur_choix(heures: int, mode: String, lit: Lit) -> void:
	executer(heures, mode, lit)

## Fondu au noir, temps qui passe, fondu retour (asynchrone). Renvoie le refus éventuel.
func executer(heures: int, mode: String, lit: Lit = null) -> String:
	var r := refus(lit if mode == "dormir" else null)
	if r != "":
		_avis(r)
		return r
	_en_cours = true
	joueur.en_dialogue = true            # ni marche ni combat pendant le fondu
	if lit != null:
		var k := lit.place_libre()
		if k >= 0:
			lit.occupants[k] = joueur
	var t := create_tween()
	t.tween_property(_noir, "color:a", 1.0, T_FONDU)
	t.tween_callback(func() -> void:
		passer_temps(heures, mode, lit)
		_texte.text = _texte_duree(heures, mode))
	t.tween_property(_texte, "modulate:a", 1.0, 0.35)
	t.tween_interval(1.1)
	t.tween_property(_texte, "modulate:a", 0.0, 0.35)
	t.tween_property(_noir, "color:a", 0.0, T_FONDU)
	t.tween_callback(func() -> void:
		_en_cours = false
		joueur.en_dialogue = false
		if lit != null:
			lit.liberer(joueur)
		_bilan(heures, mode))
	return ""

static func _texte_duree(h: int, mode: String) -> String:
	var mots := ["", "Une heure", "Deux heures", "Trois heures", "Quatre heures", "Cinq heures", "Six heures", "Sept heures", "Huit heures",
		"Neuf heures", "Dix heures", "Onze heures", "Douze heures"]
	var d := String(mots[h]) if h < mots.size() else "%d heures" % h
	return "%s plus tard…" % d if mode == "attendre" else "Vous dormez. %s plus tard…" % d

func _bilan(heures: int, mode: String) -> void:
	if mode == "dormir" and repos != "":
		_avis("%s : expérience des compétences +%d %% pendant %d h." % [REPOS[repos]["nom"], int(REPOS[repos]["bonus"] * 100.0), int(REPOS[repos]["duree"])])
	dormi.emit(heures, mode)

## Le cœur, synchrone (tests) : avance l'horloge de `heures`, pose le monde à la nouvelle heure, régénère, bonus, témoin.
func passer_temps(heures: int, mode: String, lit: Lit = null) -> Dictionary:
	heures = clampi(heures, 1, 24)
	var c: Node = monde.get("cycle")
	var h0 := float(c.heure) if c != null else 12.0
	var h1 := fposmod(h0 + heures, 24.0)
	var temoin := _temoin(lit) if lit != null and _intrus(lit) else null
	if temoin != null:      # intrusion vue : signalée AVANT le saut d'heure (ensuite les PNJ sont replacés à leur poste et le témoin n'est plus là)
		var crime := get_tree().get_first_node_in_group("crime")
		if crime != null and crime.has_method("signaler_intrusion"):
			crime.signaler_intrusion(lit, lit.proprietaire if lit.proprietaire != "joueur" else "chef")
	if c != null:
		c.avancer_a(h1)
		c._process(0.0)                  # éclairage de la nouvelle heure tout de suite (cycle gelé à l'intérieur)
	_h_prec = h1
	# marchands : heures écoulées (réassort) ; l'horloge du marchand repart de la nouvelle heure
	Marchand.avancer(float(heures))
	var mch: Node = monde.get("marchand")
	if mch != null and mch.has_method("recaler_horloge"):
		mch.recaler_horloge()
	# faune : temps de repeuplement, puis un tour complet à la nouvelle heure
	var fa: Node = monde.get("faune")
	if fa != null:
		fa.temps += float(heures)
		fa.actualiser()
	# PNJ : saut d'heure (placement direct : au lit, au poste, au feu)
	var v: Node = monde.get("vie")
	if v != null:
		v._heure_prec = -1.0
		v.tick()
	# régénération : un sommeil refait tout ; l'attente, un huitième par heure
	var part := 1.0 if mode == "dormir" else clampf(heures / 8.0, 0.0, 1.0)
	joueur.vie = minf(joueur.vie_max, joueur.vie + (joueur.vie_max - joueur.vie) * part)
	joueur.mana = minf(joueur.mana_max, joueur.mana + (joueur.mana_max - joueur.mana) * part)
	joueur.vigueur = minf(joueur.vigueur_max, joueur.vigueur + (joueur.vigueur_max - joueur.vigueur) * part)
	# repos
	if mode == "dormir" and heures >= HEURES_REPOS and lit != null:
		_debut_repos("bien_repose" if _a_soi(lit) or (lit.libre() and Rangs.repos_bien()) else "repose")
	dernier = {"heures": heures, "mode": mode, "h0": h0, "h1": h1, "lit": lit, "temoin": temoin, "vie": joueur.vie}
	return dernier

## Lit du joueur (maison achetée) ou lit loué : bien reposé, jamais une intrusion.
func _a_soi(l: Lit) -> bool:
	return ("joueur" in l.proprietaires and Stockage.maison_achetee) or (l.proprietaire == "auberge" and l.loue)

## Dormir là est une intrusion : le lit a un propriétaire qui n'est pas le joueur (lit libre, loué ou à soi : non).
func _intrus(l: Lit) -> bool:
	if l.libre() or _a_soi(l):
		return false
	return true

## Premier PNJ éveillé qui voit le joueur se coucher dans ce lit (même intérieur, ou à moins de R_TEMOIN m dehors).
func _temoin(l: Lit) -> Node3D:
	var ip := interieur_de(l)
	for n: Node in get_tree().get_nodes_in_group("villageois") + get_tree().get_nodes_in_group("gardes_village"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.visible:
			continue
		if n.has_method("est_endormi") and n.est_endormi():
			continue
		var p := n3.global_position
		if ip != null:
			if not ip.dedans(ip.to_local(p), 0.2):
				continue
		elif p.distance_to(l.global_position) > R_TEMOIN:
			continue
		var dlg: Control = monde.get("dialogue")
		if dlg != null and n.has_method("nom_affiche"):
			dlg.dire_au_passage(n.nom_affiche(), "Hé ! Ce lit n'est pas à vous !")
		return n3
	return null

func _debut_repos(cle: String) -> void:
	if repos == "bien_repose" and cle == "repose":
		cle = "bien_repose"
	repos = cle
	repos_reste = float(REPOS[cle]["duree"])
	Progression.bonus_repos = float(REPOS[cle]["bonus"])

func _fin_repos() -> void:
	repos = ""
	repos_reste = 0.0
	Progression.bonus_repos = 0.0

func _avis(t: String) -> void:
	var hud: Node = monde.get("hud") if monde != null else null
	if hud != null and hud.has_method("avis"):
		hud.avis(t)

# ======================================================================================================== sauvegarde

func exporter() -> Dictionary:
	var loues: Array = []
	for l: Lit in lits:
		if is_instance_valid(l) and l.loue:
			loues.append([snappedf(l.global_position.x, 0.01), snappedf(l.global_position.z, 0.01)])
	return {"v": 1, "repos": repos, "reste": repos_reste, "loues": loues}

func restaurer(d: Dictionary) -> void:
	var r := String(d.get("repos", ""))
	if REPOS.has(r) and float(d.get("reste", 0.0)) > 0.0:
		_debut_repos(r)
		repos_reste = float(d["reste"])
	else:
		_fin_repos()
	for p: Variant in d.get("loues", []):
		if p is Array and (p as Array).size() == 2:
			for l: Lit in lits:
				if is_instance_valid(l) and Vector2(l.global_position.x - float(p[0]), l.global_position.z - float(p[1])).length() < 0.3:
					l.loue = true
