class_name Vie
extends Node
## Village vivant (lot vie_pnj, P1-P3). Frère de GardesVillage : branché par UNE ligne dans monde._villageois() (Vie.peupler(self)).
##   - UNE horloge à 2 Hz (pas de _process par PNJ) : lit cycle.heure, évalue l'emploi du temps de chaque civil (EmploiDuTemps), décide ;
##   - P1 planning : poste de travail le jour, soirée au feu / à la longue maison, il RENTRE chez lui (porte du bâtiment) et DORT
##     (caché, sans collision, process coupé : modèle des gardes) jusqu'au réveil ; heure sautée (captures, tests, sommeil) ou civil
##     hors de vue (> 90 m) : il se pose directement à sa place, sans marche ;
##   - P2 réactions : un loup / draugr / bandit hostile à moins de R_DANGER m, ou un combat à moins de R_DANGER m, fait fuir les civils
##     vers l'abri le plus proche (porte d'un bâtiment) ; ils en sortent DELAI_RETOUR s après la fin du danger. Petit bus d'événements
##     (signal `evenement`, types « danger » / « combat » / « alarme ») que GardesVillage écoute pour alerter les gardes ;
##   - P3 dialogue : replique_contextuelle() (data/vie/repliques.json) selon danger récent, soirée, retour d'abri ;
##   - LOD global des civils : complet < 22 m, allégé < 90 m, endormi (caché, gelé) au-delà (seuils de GardesVillage) ;
##   - sauvegarde minimale (`vie`) : l'emploi du temps recalcule tout depuis l'heure ; seul le compteur d'alarmes est gardé.
## Marchands et services (forgeron, Grima) : ouverts jusqu'à leur coucher tardif (22 h 20) ; la nuit ils dorment, mais s'approcher de leur
## porte (moins de R_FRAPPE m) fait répondre leur voix à travers le bois (réplique « porte »).

signal evenement(type: String, pos: Vector3, rayon: float, source: Node)

const DONNEES_REPLIQUES := "res://data/vie/repliques.json"
const PAS := 0.5                     # s : horloge (2 Hz)
const R_DANGER := 15.0               # m : un hostile ou un combat à moins de R_DANGER d'un civil le fait fuir
const R_SORTIE := 22.0               # m : tant qu'un danger rôde à moins de R_SORTIE de son abri, il y reste
const DELAI_RETOUR := 9.0            # s sans danger avant de sortir de l'abri
const R_FRAPPE := 2.4                # m : distance de la porte où l'on « frappe » la nuit
const DELAI_FRAPPE := 25.0
const MEMOIRE_DANGER := 180.0        # s : un danger de moins de 3 min colore les dialogues
const MEMOIRE_RETOUR := 90.0
const SAUT_HEURE := 0.5              # h : un saut d'heure plus grand que ça (l'horloge naturelle fait 0,01 h par tick) = placement direct
const FEUX := {"nuit_debut": 18.5, "nuit_fin": 6.5}

var monde: Node3D
var joueur: CharacterBody3D
var village: Node3D
var civils: Array = []               # dictionnaires : n (nœud), id, f (fiche), mode, fuit, danger_t, porte (Vector3), abri (id bâtiment)
var alarmes := 0                     # nombre de fuites déclenchées (sauvegardé)
var dernier_danger := -1.0e9         # horloge (s) du dernier danger vu
var dernier_danger_pos := Vector3.ZERO
var _horloge := 0.0
var _acc := 0.0
var _heure_prec := -1.0
var _frappe_t := 0.0
var _portes := {}                    # id bâtiment -> {"pos": Vector3 devant la porte, "dir": Vector3 sortant}
var _repliques := {}
var _menaces_prec := {}              # instance_id -> true : danger déjà annoncé sur le bus
var _annonce_t := {}
var tick_ms := 0.0                   # dernière durée d'un tick (perf)

static func peupler(monde_: Node3D) -> Vie:
	if monde_.get("village") == null or OS.get_cmdline_user_args().has("--sans-vie"):
		return null
	var v := Vie.new()
	v.name = "Vie"
	v.monde = monde_
	v.joueur = monde_.joueur
	v.village = monde_.village
	monde_.add_child(v)
	v._enregistrer()
	var gv: Node = monde_.get_node_or_null("GardesVillage")
	if gv != null:
		v.evenement.connect(gv.sur_evenement)      # le bus alerte aussi les gardes
	return v

## Civils = tous les villageois.gd du groupe « villageois » (les gardes ont leur propre gestionnaire).
func _enregistrer() -> void:
	for id in ["halle", "sigrun", "chasseurs", "grima", "forge"]:
		var ip: Interieur = village.interieur(id)
		if ip == null:
			continue
		var local := Vector3(ip.porte_locale.x, 0.0, ip.porte_locale.z + 1.3)
		var p := ip.to_global(local)
		p.y = float(monde.hauteur(p.x, p.z))
		var dir := (ip.global_transform.basis * Vector3(0, 0, 1))
		dir.y = 0.0
		_portes[id] = {"pos": p, "dir": dir.normalized()}
	for n in get_tree().get_nodes_in_group("villageois"):
		ajouter(n)
	if FileAccess.file_exists(DONNEES_REPLIQUES):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES_REPLIQUES))
		if j is Dictionary:
			_repliques = j
	print("Vie : %d civils, %d portes" % [civils.size(), _portes.size()])

## Inscrit un civil (appelé aussi par monde._naissances_differees pour les villageois nés après le chargement).
func ajouter(n: Node) -> void:
	if n == null or n.is_in_group("gardes_village") or not n.has_method("rentrer"):
		return
	for c in civils:
		if c["n"] == n:
			return
	var d: Dictionary = n.donnees
	var id: String = d.get("id", "")
	n.vie = self
	civils.append({"n": n, "id": id, "f": EmploiDuTemps.fiche(id, String(d.get("type", ""))), "mode": "", "fuit": false,
		"danger_t": -1.0e9, "porte": Vector3.ZERO, "abri": "", "retour_t": -1.0e9})

func de_nuit() -> bool:
	var h := _heure()
	return h >= FEUX["nuit_debut"] or h < FEUX["nuit_fin"]

func _heure() -> float:
	var c: Node = monde.get("cycle") if monde != null else null
	return float(c.heure) if c != null else 12.0

func _process(dt: float) -> void:
	_horloge += dt
	if joueur == null or not is_instance_valid(joueur) or monde.get("_sous_terre_actif"):
		return   # sous terre, le monde gèle tout le groupe « villageois »
	_acc -= dt
	if _acc > 0.0:
		return
	_acc = PAS
	var t0 := Time.get_ticks_usec()
	tick()
	tick_ms = (Time.get_ticks_usec() - t0) / 1000.0

## Un tick de l'horloge (appelable à la main dans les tests).
func tick() -> void:
	var heure := _heure()
	var saut := _heure_prec < 0.0 or absf(angle_difference(_heure_prec / 24.0 * TAU, heure / 24.0 * TAU)) / TAU * 24.0 > SAUT_HEURE
	_heure_prec = heure
	var menaces := _menaces()
	_annoncer(menaces)
	var pj := joueur.global_position
	for c: Dictionary in civils:
		var n: Node3D = c["n"]
		if not is_instance_valid(n):
			continue
		# niveau de détail (les dormeurs sont déjà cachés)
		if not n.est_endormi():
			var d := pj.distance_to(n.global_position)
			n.regler_lod(0 if d < GardesVillage.DIST_COMPLET else (1 if d < GardesVillage.DIST_ALLEGE else 2))
		_evaluer(c, heure, menaces, saut)
	_frapper(heure)

# ======================================================================================================== danger (P2)
## Ennemis hostiles vivants (ni faune ni domestiques) : ceux qui combattent, ou qui sont assez près d'un civil pour l'inquiéter.
func _menaces() -> Array:
	var out: Array = []
	var actuels := {}
	for e: Node in get_tree().get_nodes_in_group("ennemis"):
		var n3 := e as Node3D
		if n3 == null or not n3.is_inside_tree() or e.is_in_group("faune") or e.is_in_group("gardes_village"):
			continue
		if e.has_method("vivant") and not e.vivant():
			continue
		out.append(n3)
		var combat: bool = e.has_method("en_combat") and e.en_combat()
		var id := e.get_instance_id()
		if combat and not _menaces_prec.has(id):
			emettre("combat", n3.global_position, R_DANGER, n3)
		actuels[id] = true
	_menaces_prec = actuels
	return out

## « danger » sur le bus (au plus toutes les 2 s par ennemi) pour chaque hostile à moins de 25 m d'un civil : les gardes le prennent en compte.
func _annoncer(menaces: Array) -> void:
	for e: Node3D in menaces:
		var id := e.get_instance_id()
		if _horloge < float(_annonce_t.get(id, -1.0e9)) + 2.0:
			continue
		for c: Dictionary in civils:
			var n: Node3D = c["n"]
			if is_instance_valid(n) and n.global_position.distance_to(e.global_position) < 25.0:
				_annonce_t[id] = _horloge
				emettre("danger", e.global_position, 25.0, e)
				break

## Publie un événement sur le bus (les gardes, les civils et les tests l'écoutent).
func emettre(type: String, pos: Vector3, rayon: float, source: Node = null) -> void:
	if type == "combat" or type == "danger":
		dernier_danger = _horloge
		dernier_danger_pos = pos
	evenement.emit(type, pos, rayon, source)

## Menace la plus proche d'un civil : hostile à moins de R_DANGER (plan horizontal, étage compris), ou en combat à moins de R_DANGER.
func _danger_proche(pos: Vector3, menaces: Array) -> Node3D:
	var best: Node3D = null
	var dmin := R_DANGER
	for e: Node3D in menaces:
		if absf(e.global_position.y - pos.y) > 6.0:
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d < dmin:
			dmin = d
			best = e
	return best

func _evaluer(c: Dictionary, heure: float, menaces: Array, saut: bool) -> void:
	var n: Node3D = c["n"]
	if n.occupe():
		return
	var veilleur := String(c["f"].get("toujours", "")) != ""
	# --- danger
	if not veilleur and not (n.est_endormi() and not c["fuit"]):
		var e := _danger_proche(n.global_position, menaces)
		if e != null:
			c["danger_t"] = _horloge
			dernier_danger = _horloge
			dernier_danger_pos = e.global_position
			if not c["fuit"]:
				_fuir(c, e, saut)
			return
	if c["fuit"]:
		_fin_abri(c, menaces, saut)
		return
	# --- planning
	var m := EmploiDuTemps.mode(c["f"], heure, String(c["id"]))
	if m != c["mode"] or saut:
		_transition(c, m, saut)

func _fuir(c: Dictionary, e: Node3D, instant: bool) -> void:
	var n: Node3D = c["n"]
	var abri := _abri_proche(n.global_position)
	if abri == "":
		return
	c["fuit"] = true
	c["abri"] = abri
	c["mode"] = "abri"
	alarmes += 1
	var porte := _porte_de(abri, String(c["id"]))
	c["porte"] = porte
	emettre("alarme", n.global_position, R_DANGER, e)
	var loin: bool = instant or n.lod == 2
	if loin:
		n.installer(porte, true)
	else:
		n.rentrer(porte, true, _via(n, porte), true)

func _abri_proche(pos: Vector3) -> String:
	var best := ""
	var dmin := INF
	for id: String in _portes:
		var p: Vector3 = _portes[id]["pos"]
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < dmin:
			dmin = d
			best = id
	return best

func _fin_abri(c: Dictionary, menaces: Array, instant: bool) -> void:
	var n: Node3D = c["n"]
	# encore en route vers l'abri, ou caché : on attend la fin du danger
	if _horloge - float(c["danger_t"]) < DELAI_RETOUR:
		return
	var porte: Vector3 = c["porte"]
	for e: Node3D in menaces:
		if Vector2(e.global_position.x - porte.x, e.global_position.z - porte.z).length() < R_SORTIE:
			c["danger_t"] = _horloge   # il rôde encore près de l'abri
			return
	c["fuit"] = false
	c["retour_t"] = _horloge
	c["mode"] = ""         # replanifié tout de suite
	var m := EmploiDuTemps.mode(c["f"], _heure(), String(c["id"]))
	if n.est_endormi() and m == "maison":
		c["mode"] = "maison"    # il est rentré pour la nuit de toute façon : il reste dans l'abri
		return
	_transition(c, m, instant)

# ======================================================================================================== planning (P1)
func _transition(c: Dictionary, m: String, instant: bool) -> void:
	var n: Node3D = c["n"]
	c["mode"] = m
	var id := String(c["id"])
	var f: Dictionary = c["f"]
	var maison := String(f.get("maison", ""))
	var loin: bool = instant or n.lod == 2
	if m == "maison":
		if n.est_endormi():
			return
		var porte := _porte_de(maison, id)
		if maison == "" or porte == Vector3.ZERO:
			return                                    # pas de maison : il reste là
		c["porte"] = porte
		if loin:
			n.installer(porte, true)
		else:
			n.rentrer(porte, true, _via(n, porte))
		return
	# poste ou soir : on sort d'abord si on dormait
	if n.est_endormi():
		var sortie: Vector3 = c["porte"] if c["porte"] != Vector3.ZERO else _porte_de(maison, id)
		n.reveiller(sortie)
	var soir := String(f.get("soir", "poste"))
	if m == "soir" and soir != "poste":
		var spot := _spot_soir(soir, id)
		if spot.has("pos"):
			if loin:
				n.installer(spot["pos"], false, false, "Idle_Talking", spot["cap"])
			else:
				n.rentrer(spot["pos"], false, _via(n, spot["pos"]), false, false, "Idle_Talking", spot["cap"])
			return
	# poste de jour (ou « soir » au poste : service, veilleur)
	var poste: Vector3 = n.points[0]
	if n.global_position.distance_to(poste) < 0.6:
		n.installer(poste, false, true)
	elif loin:
		n.installer(poste, false, true)
	else:
		n.rentrer(poste, false, _via(n, poste), false, true)

## Point devant la porte du bâtiment `bat`, décalé sur le côté selon l'id (ils ne s'empilent pas à la porte).
func _porte_de(bat: String, id: String) -> Vector3:
	if not _portes.has(bat):
		return Vector3.ZERO
	var p: Vector3 = _portes[bat]["pos"]
	var dir: Vector3 = _portes[bat]["dir"]
	var cote := dir.cross(Vector3.UP)
	var k := (id.hash() % 5) - 2
	return p + cote * (0.35 * k) + dir * (0.15 * (id.hash() % 3))

## Place autour du feu / de la longue maison : sur un cercle de 1,8 à 2,8 m, face au centre. {"pos", "cap"} ou {}.
func _spot_soir(lieu: String, id: String) -> Dictionary:
	var centre := Vector3.ZERO
	var extra: Dictionary = EmploiDuTemps.donnees().get("lieux_extra", {})
	if extra.has(lieu):
		var a: Array = extra[lieu]
		centre = Vector3(float(a[0]), 0.0, float(a[1]))
		centre.y = float(monde.hauteur(centre.x, centre.z))
	elif village.lieux.has(lieu):
		centre = village.lieux[lieu]
	else:
		return {}
	var h := id.hash()
	var ang := float(h % 628) / 100.0
	var r := 1.8 + float((h / 7) % 11) * 0.1
	var off := Vector3(cos(ang), 0.0, sin(ang)) * r
	var pos := centre + off
	pos.y = float(monde.hauteur(pos.x, pos.z))
	return {"pos": pos, "cap": atan2(-off.x, -off.z)}

## Points intermédiaires si la ligne droite est barrée (passe par la place, plateau dégagé du village).
func _via(n: Node3D, but: Vector3) -> Array:
	var a := n.global_position
	if n.chemin_libre(a, but):
		return []
	var hub: Vector3 = village.lieux.get("place", Vector3.ZERO)
	if hub != Vector3.ZERO and n.chemin_libre(a, hub):
		return [hub]
	return []

# ======================================================================================================== porte (la nuit)
func _frapper(_heure_: float) -> void:
	if _horloge < _frappe_t:
		return
	var pj := joueur.global_position
	for id: String in _portes:
		var p: Vector3 = _portes[id]["pos"]
		if Vector2(p.x - pj.x, p.z - pj.z).length() > R_FRAPPE or absf(p.y - pj.y) > 3.0:
			continue
		var dormeurs: Array = []
		for c: Dictionary in civils:
			if is_instance_valid(c["n"]) and c["n"].est_endormi() and String(c["f"].get("maison", "")) == id and not c["fuit"]:
				dormeurs.append(c)
		if dormeurs.is_empty():
			continue
		# priorité aux services (ils répondent à la porte) ; sinon le premier qui dort
		var qui: Dictionary = dormeurs[0]
		for c: Dictionary in dormeurs:
			if String(c["f"].get("profil", "")) == "service":
				qui = c
		var l := _ligne(qui["n"], "porte")
		if l != "" and monde.get("dialogue") != null:
			monde.dialogue.dire_au_passage(qui["n"].nom_affiche(), l)
			_frappe_t = _horloge + DELAI_FRAPPE
		return

# ======================================================================================================== dialogue (P3)
func _ligne(n: Node, ctx: String) -> String:
	var d: Dictionary = n.donnees
	var sources: Array = [
		(_repliques.get("pnj", {}) as Dictionary).get(String(d.get("id", "")), {}),
		(_repliques.get("types", {}) as Dictionary).get(String(d.get("type", "")), {}),
		_repliques.get("communes", {}),
	]
	for s: Dictionary in sources:
		var l: Array = s.get(ctx, [])
		if not l.is_empty():
			return String(l.pick_random())
	return ""

## Contexte du moment pour `n` : danger récent > retour d'abri > soirée / nuit. "" = pas de réplique particulière.
func contexte_de(n: Node) -> String:
	if _horloge - dernier_danger < MEMOIRE_DANGER:
		return "danger"
	for c: Dictionary in civils:
		if c["n"] == n and _horloge - float(c["retour_t"]) < MEMOIRE_RETOUR:
			return "retour"
	if de_nuit():
		return "nuit"
	return ""

func replique_contextuelle(n: Node) -> String:
	var ctx := contexte_de(n)
	return _ligne(n, ctx) if ctx != "" else ""

# ======================================================================================================== sauvegarde
func exporter() -> Dictionary:
	return {"v": 1, "alarmes": alarmes}

func restaurer(d: Dictionary) -> void:
	alarmes = maxi(0, int(d.get("alarmes", 0)))

## Civil par id (tests, captures).
func civil(id: String) -> Dictionary:
	for c: Dictionary in civils:
		if c["id"] == id:
			return c
	return {}
