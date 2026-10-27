class_name SonsMagie
## SONS de la magie (branche magie/sons) : charge (boucle douce), lancement, jet continu (boucle), impact, mana insuffisant,
## réactions, double incantation, enchantement. Écoles : feu, glace, electricite, tenebres (+ soin, protection).
## Branché sans toucher aux visuels : EffetsMagie appelle ces fonctions (mêmes arguments), LanceurSorts.lancer pour le départ du
## sort, MainSort._refuser pour « Pas assez de mana ». Le mage ennemi passe par les mêmes appels : sons spatialisés (3D) sur
## SA main / SA position.
##
## PERF (piège connu : un .ogg décodé au départ coûtait ~1,9 ms) : tout est en .wav PCM court (assets/sons/magie, fabriqués par
## outils/sons_magie/generer.py), préchargé en tâche de fond (precharger(), appelé par PrechauffeCombat.caches()). Les sons
## sont joués par un POOL de lecteurs créés une fois (12 coups + 8 boucles) : aucun nœud ni flux créé par sort.
## Volume : bus « Effets » (réglé dans Options) quand il existe.

const ECOLES := ["feu", "glace", "electricite", "tenebres", "soin", "protection"]
const REACTIONS := ["vapeur", "decharge", "decharge_incendiaire", "cristaux_corrompus", "flammes_obscures", "arcs_violets"]
const DOSSIER := "res://assets/sons/magie/"
const N_COUPS := 12
const N_BOUCLES := 8
const COUPS_PAR_IMAGE := 5
const DB_SILENCE := -50.0
## Réglage par catégorie (dB) : les fichiers sont normalisés (coups -3 dBFS crête ; boucles -8/-10), la balance se fait ici.
const VOL_LANCER := -1.0
const VOL_IMPACT := 0.0
const VOL_REACTION := 1.0
const VOL_DOUBLE := -2.0
const VOL_REFUS := -4.0
const VOL_CHARGE_MIN := -26.0
const VOL_CHARGE_MAX := -9.0
const VOL_JET := -3.0
const HAUTEUR_DOUBLE := {"feu": 0.85, "glace": 1.15, "electricite": 1.0, "tenebres": 0.7, "soin": 1.2, "protection": 0.95}

## Compteurs d'appels (tests) ; `joues` = lectures réellement lancées ; `sync` = flux chargés en synchrone (doit rester 0 après precharger()).
static var appels := {}
static var joues := 0
static var sync := 0
static var _flux := {}
static var _precharge := false
static var _noeud: Noeud = null
static var _derniere := {}      # cle -> dernier instant (ms)
static var _derniere_var := {}  # nom de la 1re variante -> dernière variante jouée

# ------------------------------------------------------------------ noms de fichiers

static func ecole_sure(e: String) -> String:
	return e if e in ECOLES else "feu"

static func noms_ecole(e: String, evenement: String) -> Array:
	return ["magie/%s_%s_1" % [e, evenement], "magie/%s_%s_2" % [e, evenement]]

## Tables de noms construites UNE fois (pas de formatage de chaîne ni de tableau par sort).
static var _tab := {}

static func _tables() -> void:
	if not _tab.is_empty():
		return
	for e: String in ECOLES:
		_tab[e] = {"lancer": noms_ecole(e, "lancer"), "impact": noms_ecole(e, "impact"), "charge": "magie/charge_" + e, "jet": "magie/jet_" + e,
			"c_lancer": "lancer_" + e, "c_impact": "impact_" + e, "c_zone": "zone_" + e, "c_chaine": "chaine_" + e, "c_enchant": "enchant_" + e}
	for r: String in REACTIONS:
		_tab[r] = {"nom": "magie/reaction_" + r, "cle": "reaction_" + r}

static func _t(e: String) -> Dictionary:
	if _tab.is_empty():
		_tables()
	return _tab[e]

## Tous les fichiers (sans extension, relatifs à assets/sons/) que la magie peut jouer.
static func tous_les_noms() -> Array:
	var l: Array = []
	for e: String in ECOLES:
		l.append_array(noms_ecole(e, "lancer"))
		l.append_array(noms_ecole(e, "impact"))
		l.append("magie/charge_" + e)
		l.append("magie/jet_" + e)
	for r: String in REACTIONS:
		l.append("magie/reaction_" + r)
	l.append("magie/refus_mana")
	l.append("magie/double")
	return l

static func _chemin(nom: String) -> String:
	return "res://assets/sons/" + nom + ".wav"

## Lance la lecture en tâche de fond de tous les sons (PrechauffeCombat.caches()).
static func precharger() -> void:
	if _precharge:
		return
	_precharge = true
	for nom: String in tous_les_noms():
		ResourceLoader.load_threaded_request(_chemin(nom), "AudioStream")

static func flux(nom: String) -> AudioStreamWAV:
	if _flux.has(nom):
		return _flux[nom]
	var ch := _chemin(nom)
	var s: AudioStreamWAV = null
	if _precharge and ResourceLoader.load_threaded_get_status(ch) == ResourceLoader.THREAD_LOAD_LOADED:
		s = ResourceLoader.load_threaded_get(ch) as AudioStreamWAV
	elif _precharge and ResourceLoader.load_threaded_get_status(ch) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null   # pas encore prêt : le son est sauté plutôt que de bloquer l'image
	else:
		s = load(ch) as AudioStreamWAV
		sync += 1
	_flux[nom] = s
	return s

static func _compter(f: String) -> void:
	appels[f] = int(appels.get(f, 0)) + 1

static func _actif() -> bool:
	return not EffetsMagie.muet

static func _n() -> Noeud:
	if _noeud != null and is_instance_valid(_noeud) and not _noeud.is_queued_for_deletion():
		return _noeud
	_noeud = Noeud.new()
	_noeud.name = "SonsMagie"
	GestionMagie.obtenir().add_child(_noeud)
	return _noeud

static func _variante(noms: Array) -> String:
	var cle: String = noms[0]
	var i := randi() % noms.size()
	if noms.size() > 1 and i == int(_derniere_var.get(cle, -1)):
		i = (i + 1) % noms.size()
	_derniere_var[cle] = i
	return noms[i]

static func _oeil() -> Vector3:
	var arbre := Engine.get_main_loop() as SceneTree
	var cam: Camera3D = arbre.root.get_viewport().get_camera_3d() if arbre != null else null
	return cam.global_position if cam != null else Vector3.ZERO

## Un coup : `ecart` = délai minimal (s) entre deux lectures du même `cle`.
static func _coup(nom: String, pos: Vector3, vol: float, hauteur := 1.0, cle := "", ecart := 0.05) -> void:
	if not _actif():
		return
	if cle != "":
		var t := Time.get_ticks_msec()
		if t - int(_derniere.get(cle, -100000)) < int(ecart * 1000.0):
			return
		_derniere[cle] = t
	_n().coup(nom, pos, vol, hauteur)

# ------------------------------------------------------------------ appels (mêmes arguments que le contrat EffetsMagie)

## Départ d'un sort (LanceurSorts.lancer) : `k` = facteur de charge (1 = normal).
static func lancement(ecole: String, pos: Vector3, k := 1.0) -> void:
	_compter("lancement")
	var t := _t(ecole_sure(ecole))
	_coup(_variante(t["lancer"]), pos, VOL_LANCER + 3.0 * clampf(k - 1.0, -0.5, 1.0), randf_range(0.95, 1.05), t["c_lancer"], 0.06)

static func impact(ecole: String, pos: Vector3, force: float) -> void:
	_compter("impact")
	var t := _t(ecole_sure(ecole))
	var f := clampf(force, 0.3, 3.0)
	_coup(_variante(t["impact"]), pos, VOL_IMPACT + clampf(3.5 * log(f), -6.0, 4.0), clampf(1.12 - 0.12 * f, 0.88, 1.1) * randf_range(0.97, 1.03), t["c_impact"], 0.06)

static func zone(ecole: String, pos: Vector3, rayon: float) -> void:
	_compter("zone")
	var t := _t(ecole_sure(ecole))
	_coup(_variante(t["impact"]), pos, VOL_IMPACT + 2.0, clampf(1.1 - 0.04 * rayon, 0.8, 1.0), t["c_zone"], 0.15)

static func chaine(ecole: String, points: Array) -> void:
	_compter("chaine")
	if points.size() < 2:
		return
	var t := _t(ecole_sure(ecole))
	_coup(_variante(t["lancer"]), points[0], VOL_LANCER - 3.0, randf_range(1.0, 1.12), t["c_chaine"], 0.15)

static func reaction(nom: String, pos: Vector3) -> void:
	_compter("reaction")
	if nom in REACTIONS:
		var t := _t(nom)
		_coup(t["nom"], pos, VOL_REACTION, randf_range(0.96, 1.04), t["cle"], 0.1)

static func double(ecole: String, actif: bool) -> void:
	_compter("double")
	if actif:
		var e := ecole_sure(ecole)
		_coup("magie/double", _oeil(), VOL_DOUBLE, float(HAUTEUR_DOUBLE.get(e, 1.0)), "double", 0.2)

static func enchant(ecole: String, pos: Vector3, actif: bool) -> void:
	_compter("enchant")
	if actif:
		var t := _t(ecole_sure(ecole))
		_coup(_variante(t["lancer"]), pos, VOL_LANCER - 4.0, 0.9, t["c_enchant"], 0.2)

static func refus_mana() -> void:
	_compter("refus_mana")
	_coup("magie/refus_mana", _oeil(), VOL_REFUS, randf_range(0.96, 1.04), "refus_mana", 0.25)

## Boucle de charge portée par `main` (appelé à chaque changement d'intensité : 0 = éteinte).
static func aura(main: Node3D, ecole: String, intensite: float) -> void:
	_compter("aura")
	if not _actif() or main == null:
		return
	_n().boucle(main.get_instance_id() * 2, main, _t(ecole_sure(ecole))["charge"], intensite, true)

## Boucle de jet : à appeler chaque image tant que `actif` (s'éteint seule 0,25 s après le dernier appel).
static func jet(ecole: String, origine: Node3D, actif: bool) -> void:
	_compter("jet")
	if not _actif() or origine == null:
		return
	_n().boucle(origine.get_instance_id() * 2 + 1, origine, _t(ecole_sure(ecole))["jet"], 1.0 if actif else 0.0, false)

static func tout_arreter() -> void:
	if _noeud != null and is_instance_valid(_noeud):
		_noeud.tout_couper()

# ------------------------------------------------------------------ nœud porteur des pools

class Voix:
	var lecteur: AudioStreamPlayer3D
	var cle := -1
	var cible: Node3D = null
	var objectif := SonsMagie.DB_SILENCE
	var actuel := SonsMagie.DB_SILENCE
	var expire := 0.0      # fin d'une boucle de jet (s, horloge du nœud) ; 0 = pas d'expiration
	var depuis := 0.0      # horloge au départ (vol du plus ancien)
	var nom := ""

class Noeud extends Node:
	var coups: Array[AudioStreamPlayer3D] = []
	var depart_coup: Array[float] = []
	var boucles: Array[Voix] = []
	var horloge := 0.0
	var _img := -1
	var _n_img := 0
	var _bus: StringName = &"Master"

	func _init() -> void:
		process_priority = 101
		for i in SonsMagie.N_COUPS:
			coups.append(_lecteur())
			depart_coup.append(0.0)
		for i in SonsMagie.N_BOUCLES:
			var v := Voix.new()
			v.lecteur = _lecteur()
			boucles.append(v)

	func _lecteur() -> AudioStreamPlayer3D:
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 5.0
		a.max_distance = 60.0
		a.volume_db = SonsMagie.DB_SILENCE
		add_child(a)
		return a

	func _ready() -> void:
		if AudioServer.get_bus_index("Effets") >= 0:
			_bus = &"Effets"
		for a in coups:
			a.bus = _bus
		for v in boucles:
			v.lecteur.bus = _bus

	func coup(nom: String, pos: Vector3, vol: float, hauteur: float) -> void:
		if not is_inside_tree():
			return
		var img := Engine.get_process_frames()
		if img != _img:
			_img = img
			_n_img = 0
		if _n_img >= SonsMagie.COUPS_PAR_IMAGE:
			return
		var s := SonsMagie.flux(nom)
		if s == null:
			return
		_n_img += 1
		var k := 0
		var plus_ancien := INF
		for i in coups.size():
			if not coups[i].playing:
				k = i
				plus_ancien = -INF
				break
			if depart_coup[i] < plus_ancien:
				plus_ancien = depart_coup[i]
				k = i
		var a := coups[k]
		depart_coup[k] = horloge
		a.stream = s
		a.volume_db = vol
		a.pitch_scale = hauteur
		a.global_position = pos
		a.play()
		SonsMagie.joues += 1

	## Démarre / règle / coupe la boucle de clé `cle`. `intensite` 0 = fondu de sortie. `aura` : volume selon l'intensité (0..1,5) ;
	## sinon jet (volume fixe, expire 0,25 s après le dernier appel).
	func boucle(cle: int, cible: Node3D, nom: String, intensite: float, aura: bool) -> void:
		if not is_inside_tree():
			return
		var v: Voix = null
		for b in boucles:
			if b.cle == cle:
				v = b
				break
		if v == null:
			if intensite <= 0.01:
				return
			var plus_bas := INF
			for b in boucles:
				if b.cle == -1:
					v = b
					break
				if b.objectif < plus_bas:
					plus_bas = b.objectif
					v = b
			v.cle = cle
			v.cible = cible
			v.depuis = horloge
			v.actuel = SonsMagie.DB_SILENCE
			v.lecteur.volume_db = SonsMagie.DB_SILENCE
		if intensite <= 0.01:
			v.objectif = SonsMagie.DB_SILENCE
			v.expire = 0.0
			return
		if v.nom != nom or not v.lecteur.playing:
			var s := SonsMagie.flux(nom)
			if s == null:
				v.cle = -1
				return
			v.nom = nom
			v.lecteur.stream = s
			v.lecteur.play(randf() * 0.5)
			SonsMagie.joues += 1
		if aura:
			var k := clampf(intensite / 1.2, 0.0, 1.0)
			v.objectif = lerpf(SonsMagie.VOL_CHARGE_MIN, SonsMagie.VOL_CHARGE_MAX, k)
			v.lecteur.pitch_scale = 0.9 + 0.25 * clampf(intensite, 0.0, 1.5)
			v.expire = 0.0
		else:
			v.objectif = SonsMagie.VOL_JET
			v.lecteur.pitch_scale = 1.0
			v.expire = horloge + 0.25
		if v.cible != null and is_instance_valid(v.cible) and v.cible.is_inside_tree():
			v.lecteur.global_position = v.cible.global_position

	func tout_couper() -> void:
		for v in boucles:
			v.objectif = SonsMagie.DB_SILENCE
			v.expire = 0.0
		for a in coups:
			a.stop()

	func _process(dt: float) -> void:
		horloge += dt
		for v in boucles:
			if v.cle == -1:
				continue
			if v.expire > 0.0 and horloge > v.expire:
				v.objectif = SonsMagie.DB_SILENCE
				v.expire = 0.0
			var cible_ok := v.cible != null and is_instance_valid(v.cible) and v.cible.is_inside_tree()
			if not cible_ok and v.objectif > SonsMagie.DB_SILENCE:
				v.objectif = SonsMagie.DB_SILENCE   # la main (ou le mage) a disparu
			elif cible_ok:
				v.lecteur.global_position = v.cible.global_position
			# fondu : montée 40 dB/s, descente 70 dB/s
			if v.actuel < v.objectif:
				v.actuel = minf(v.actuel + 40.0 * dt, v.objectif)
			elif v.actuel > v.objectif:
				v.actuel = maxf(v.actuel - 70.0 * dt, v.objectif)
			v.lecteur.volume_db = v.actuel
			if v.objectif <= SonsMagie.DB_SILENCE and v.actuel <= SonsMagie.DB_SILENCE:
				v.lecteur.stop()
				v.cle = -1
				v.cible = null
