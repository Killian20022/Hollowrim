class_name RetourImpact
## Retour des coups (sensation) : arrêt sur image, secousse de caméra, voile rouge bref, ralenti, sons par matière.
##   RetourImpact.jouer(noeud, ProfilImpact.de("lourd"), joueur)
##   RetourImpact.son_impact(noeud, matiere, profil, point, armure)
##   RetourImpact.eclat_rouge(noeud, force, duree)       uniform « eclat_rouge » du post-traitement ps1 (ps1_post.gdshader)
## Les sons sont ceux de assets/sons (Kenney CC0, déjà au dépôt), superposés et désaccordés pour varier.

## Coupe tout retour d'écran (tests sans fenêtre).
static var muet := false
## Arrêt sur image et ralenti actifs (false : tests à pas fixe ; RetourCoups.arret_actif, ancien réglage, coupe aussi).
static var arret_actif := true

static func temps_actif() -> bool:
	return arret_actif and RetourCoups.arret_actif

static func jouer(n: Node, p: ProfilImpact, joueur: Node) -> void:
	if n == null or not n.is_inside_tree() or p == null:
		return
	var arbre := n.get_tree()
	var temps := temps_actif()
	if p.arret > 0.0 and temps:
		Effets.arret_image(arbre, p.arret)
	if p.ralenti > 0.0 and temps:
		_ralenti_apres(arbre, p)
	if joueur != null and is_instance_valid(joueur) and "secousse" in joueur:
		joueur.secousse = maxf(float(joueur.secousse), p.secousse)
	if p.eclat_rouge > 0.0 and Sang.niveau() > 0:
		eclat_rouge(n, p.eclat_rouge, 0.35 + p.eclat_rouge * 0.5)

static func _ralenti_apres(arbre: SceneTree, p: ProfilImpact) -> void:
	await arbre.create_timer(p.arret, true, false, true).timeout
	Effets.ralenti(arbre, p.ralenti_echelle, p.ralenti)

## Matériau du post-traitement (variable « post » de la scène courante, ex. monde.gd).
static func post(n: Node) -> ShaderMaterial:
	var s := n.get_tree().current_scene
	if s != null and "post" in s and s.get("post") is ShaderMaterial:
		return s.get("post")
	for c in n.get_tree().root.get_children():
		if "post" in c and c.get("post") is ShaderMaterial:
			return c.get("post")
	return null

static func eclat_rouge(n: Node, force: float, duree := 0.45) -> void:
	if muet:
		return
	var m := post(n)
	if m == null:
		return
	var tw := n.get_tree().create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("eclat_rouge", v), force, 0.0, duree).set_ease(Tween.EASE_OUT)

## --- sons ---------------------------------------------------------------------------------------------------------
## Pack de combat CC0 (assets/sons/combat/, crédits dans assets/LICENCES.md) : variantes tirées au hasard sans répéter la dernière,
## hauteur ±6 %, et GAIN par fichier (mesuré : volume moyen ramené vers -19 dB, comme les bruitages Kenney déjà au dépôt).
const BANQUE := {
	"chair": ["combat/impacts/chair_01", "combat/impacts/chair_02", "combat/impacts/chair_03", "combat/impacts/chair_04", "combat/impacts/chair_05"],
	"chair_gore": ["combat/impacts/chair_gore_01", "combat/impacts/chair_gore_02", "combat/impacts/chair_gore_03", "combat/impacts/chair_gore_04", "combat/impacts/chair_gore_05", "combat/impacts/chair_gore_06"],
	"dechirure": ["combat/gore/dechirure_01", "combat/gore/dechirure_02", "combat/gore/dechirure_03", "combat/gore/dechirure_04", "combat/gore/dechirure_05", "combat/gore/dechirure_06"],
	"os": ["combat/impacts/os_01", "combat/impacts/os_02", "combat/impacts/os_03", "combat/impacts/os_04", "combat/impacts/os_05", "combat/impacts/os_06"],
	"armure": ["combat/impacts/armure_maille_01", "combat/impacts/armure_maille_02", "combat/impacts/armure_maille_03", "combat/impacts/armure_maille_04", "combat/impacts/armure_maille_05", "combat/impacts/armure_maille_06"],
	"bois": ["combat/impacts/bois_bouclier_01", "combat/impacts/bois_bouclier_02", "combat/impacts/bois_bouclier_03", "combat/impacts/bois_bouclier_04", "combat/impacts/bois_bouclier_05", "combat/impacts/bois_bouclier_06"],
	"pierre": ["combat/impacts/pierre_01", "combat/impacts/pierre_02", "combat/impacts/pierre_03", "combat/impacts/pierre_04", "combat/impacts/pierre_05"],
	"jet_sang": ["combat/gore/jet_sang_01", "combat/gore/jet_sang_02", "combat/gore/jet_sang_03", "combat/gore/jet_sang_04", "combat/gore/jet_sang_05", "combat/gore/jet_sang_06", "combat/gore/jet_sang_07"],
	"decapitation": ["combat/gore/decapitation_01", "combat/gore/decapitation_02", "combat/gore/decapitation_03", "combat/gore/decapitation_04", "combat/gore/decapitation_05"],
	"chute_pierre": ["combat/gore/chute_corps_pierre_01", "combat/gore/chute_corps_pierre_02", "combat/gore/chute_corps_pierre_03", "combat/gore/chute_corps_pierre_04", "combat/gore/chute_corps_pierre_05"],
	"chute_neige": ["combat/gore/chute_corps_neige_01", "combat/gore/chute_corps_neige_02", "combat/gore/chute_corps_neige_03", "combat/gore/chute_corps_neige_04", "combat/gore/chute_corps_neige_05"],
	"draugr_douleur": ["combat/voix/draugr_grognement_01", "combat/voix/draugr_grognement_02", "combat/voix/draugr_grognement_03", "combat/voix/draugr_grognement_04", "combat/voix/draugr_grognement_05", "combat/voix/draugr_grognement_06"],
	"draugr_mort": ["combat/voix/draugr_mort_01", "combat/voix/draugr_mort_02", "combat/voix/draugr_mort_03", "combat/voix/draugr_mort_04", "combat/voix/draugr_mort_05", "combat/voix/draugr_mort_06"],
	"douleur": ["combat/voix/douleur_01", "combat/voix/douleur_02", "combat/voix/douleur_03", "combat/voix/douleur_04", "combat/voix/douleur_05", "combat/voix/douleur_06"],
	"coup_de_grace": ["combat/signaux/coup_de_grace_01", "combat/signaux/coup_de_grace_02", "combat/signaux/coup_de_grace_03", "combat/signaux/coup_de_grace_04"],
	# lame du joueur (branche integration/H) : fouettés de l'épée, dégainer / rengainer, blocage lame contre lame, parade parfaite
	"fouette_leger": ["combat/lame/fouette_leger_01", "combat/lame/fouette_leger_02", "combat/lame/fouette_leger_03", "combat/lame/fouette_leger_04", "combat/lame/fouette_leger_05"],
	"fouette_lourd": ["combat/lame/fouette_lourd_01", "combat/lame/fouette_lourd_02", "combat/lame/fouette_lourd_03", "combat/lame/fouette_lourd_04", "combat/lame/fouette_lourd_05"],
	"degainer": ["combat/lame/degainer_01", "combat/lame/degainer_02", "combat/lame/degainer_03", "combat/lame/degainer_04", "combat/lame/degainer_05", "combat/lame/degainer_06"],
	"rengainer": ["combat/lame/rengainer_01", "combat/lame/rengainer_02", "combat/lame/rengainer_03", "combat/lame/rengainer_04", "combat/lame/rengainer_05"],
	"metal_blocage": ["combat/impacts/metal_blocage_01", "combat/impacts/metal_blocage_02", "combat/impacts/metal_blocage_03", "combat/impacts/metal_blocage_04", "combat/impacts/metal_blocage_05", "combat/impacts/metal_blocage_06"],
	"parade_parfaite": ["combat/impacts/parade_parfaite_01", "combat/impacts/parade_parfaite_02", "combat/impacts/parade_parfaite_03", "combat/impacts/parade_parfaite_04", "combat/impacts/parade_parfaite_05", "combat/impacts/parade_parfaite_06"],
}
const GAIN := {
	"combat/lame/degainer_01": -0.8,
	"combat/lame/degainer_02": 2.4,
	"combat/lame/degainer_03": 0.4,
	"combat/lame/degainer_04": 1.8,
	"combat/lame/degainer_05": -0.3,
	"combat/lame/degainer_06": 6.0,
	"combat/lame/fouette_leger_01": 3.3,
	"combat/lame/fouette_leger_02": 3.5,
	"combat/lame/fouette_leger_03": 0.3,
	"combat/lame/fouette_leger_04": 3.1,
	"combat/lame/fouette_leger_05": 1.7,
	"combat/lame/fouette_lourd_01": 5.0,
	"combat/lame/fouette_lourd_02": 4.9,
	"combat/lame/fouette_lourd_03": 6.0,
	"combat/lame/fouette_lourd_04": 3.9,
	"combat/lame/fouette_lourd_05": 2.9,
	"combat/lame/rengainer_01": 5.3,
	"combat/lame/rengainer_02": 6.0,
	"combat/lame/rengainer_03": 2.3,
	"combat/lame/rengainer_04": 0.1,
	"combat/lame/rengainer_05": -0.1,
	"combat/impacts/metal_blocage_01": -0.3,
	"combat/impacts/metal_blocage_02": 0.9,
	"combat/impacts/metal_blocage_03": 1.5,
	"combat/impacts/metal_blocage_04": 3.7,
	"combat/impacts/metal_blocage_05": 1.1,
	"combat/impacts/metal_blocage_06": 3.5,
	"combat/impacts/parade_parfaite_01": -1.0,
	"combat/impacts/parade_parfaite_02": -3.9,
	"combat/impacts/parade_parfaite_03": 4.4,
	"combat/impacts/parade_parfaite_04": 1.8,
	"combat/impacts/parade_parfaite_05": 0.6,
	"combat/impacts/parade_parfaite_06": 6.0,
	"combat/gore/chute_corps_neige_01": 0.5,
	"combat/gore/chute_corps_neige_02": -0.6,
	"combat/gore/chute_corps_neige_03": -0.7,
	"combat/gore/chute_corps_neige_04": -0.8,
	"combat/gore/chute_corps_neige_05": -0.6,
	"combat/gore/chute_corps_pierre_01": 5.0,
	"combat/gore/chute_corps_pierre_02": 2.7,
	"combat/gore/chute_corps_pierre_03": -0.8,
	"combat/gore/chute_corps_pierre_04": -0.9,
	"combat/gore/chute_corps_pierre_05": -1.7,
	"combat/gore/decapitation_01": 0.6,
	"combat/gore/decapitation_02": 0.3,
	"combat/gore/decapitation_03": -0.6,
	"combat/gore/decapitation_04": -2.2,
	"combat/gore/decapitation_05": -0.9,
	"combat/gore/dechirure_01": 0.3,
	"combat/gore/dechirure_02": -0.1,
	"combat/gore/dechirure_03": -2.6,
	"combat/gore/dechirure_04": -3.5,
	"combat/gore/dechirure_05": -1.4,
	"combat/gore/dechirure_06": -2.0,
	"combat/gore/jet_sang_01": 3.6,
	"combat/gore/jet_sang_02": 6.0,
	"combat/gore/jet_sang_03": 1.5,
	"combat/gore/jet_sang_04": 3.4,
	"combat/gore/jet_sang_05": 3.5,
	"combat/gore/jet_sang_06": 5.4,
	"combat/gore/jet_sang_07": 5.2,
	"combat/impacts/armure_maille_01": 5.2,
	"combat/impacts/armure_maille_02": 2.2,
	"combat/impacts/armure_maille_03": 3.3,
	"combat/impacts/armure_maille_04": 6.0,
	"combat/impacts/armure_maille_05": 6.0,
	"combat/impacts/armure_maille_06": 5.2,
	"combat/impacts/bois_bouclier_01": 6.0,
	"combat/impacts/bois_bouclier_02": 2.8,
	"combat/impacts/bois_bouclier_03": 4.2,
	"combat/impacts/bois_bouclier_04": 1.1,
	"combat/impacts/bois_bouclier_05": 1.4,
	"combat/impacts/bois_bouclier_06": 5.5,
	"combat/impacts/chair_01": 6.0,
	"combat/impacts/chair_02": 2.3,
	"combat/impacts/chair_03": -1.6,
	"combat/impacts/chair_04": -1.9,
	"combat/impacts/chair_05": -2.9,
	"combat/impacts/chair_gore_01": -0.7,
	"combat/impacts/chair_gore_02": 1.3,
	"combat/impacts/chair_gore_03": -0.1,
	"combat/impacts/chair_gore_04": -0.3,
	"combat/impacts/chair_gore_05": 3.1,
	"combat/impacts/chair_gore_06": 4.4,
	"combat/impacts/os_01": 4.7,
	"combat/impacts/os_02": 3.0,
	"combat/impacts/os_03": 2.6,
	"combat/impacts/os_04": 3.9,
	"combat/impacts/os_05": 3.6,
	"combat/impacts/os_06": 5.9,
	"combat/impacts/pierre_01": 2.3,
	"combat/impacts/pierre_02": 6.0,
	"combat/impacts/pierre_03": 2.0,
	"combat/impacts/pierre_04": 2.7,
	"combat/impacts/pierre_05": 3.9,
	"combat/signaux/coup_de_grace_01": 6.0,
	"combat/signaux/coup_de_grace_02": 6.0,
	"combat/signaux/coup_de_grace_03": 6.0,
	"combat/signaux/coup_de_grace_04": 6.0,
	"combat/voix/douleur_01": -5.0,
	"combat/voix/douleur_02": -2.8,
	"combat/voix/douleur_03": -2.5,
	"combat/voix/douleur_04": -3.7,
	"combat/voix/douleur_05": -0.8,
	"combat/voix/douleur_06": -1.2,
	"combat/voix/draugr_grognement_01": 0.7,
	"combat/voix/draugr_grognement_02": -0.6,
	"combat/voix/draugr_grognement_03": -1.3,
	"combat/voix/draugr_grognement_04": -1.7,
	"combat/voix/draugr_grognement_05": -1.9,
	"combat/voix/draugr_grognement_06": -0.1,
	"combat/voix/draugr_mort_01": -2.2,
	"combat/voix/draugr_mort_02": -3.4,
	"combat/voix/draugr_mort_03": -1.8,
	"combat/voix/draugr_mort_04": 2.1,
	"combat/voix/draugr_mort_05": 2.7,
	"combat/voix/draugr_mort_06": 3.8,
}
## Sol des chutes de corps : "" = deviné (sous terre, y < -8 : pierre ; sinon neige) ; "pierre" / "neige" imposé (scène de test).
static var sol_force := ""
static var _derniers := {}
static var _flux := {}
static var _precharge := false

## Charge tous les sons de la banque en tâche de fond (appelé à la création du premier composant de combat) : plus de lecture de
## fichier au moment d'un coup (un finisher sur 5 draugrs lisait ~20 fichiers dans la même image : pic de 200 ms).
static func precharger() -> void:
	if _precharge:
		return
	_precharge = true
	for cat: String in BANQUE:
		for nom: String in BANQUE[cat]:
			var ch := _chemin(nom)
			if ch != "":
				ResourceLoader.load_threaded_request(ch, "AudioStream")

static var _chemins := {}

static func _chemin(nom: String) -> String:
	if _chemins.has(nom):
		return _chemins[nom]
	var trouve := ""
	for ext in [".wav", ".ogg"]:   # .wav d'abord : lecture ~100x moins chère (une lecture Ogg Vorbis coûte ~2 ms de fil principal à son départ)
		var c: String = "res://assets/sons/" + nom + ext
		if ResourceLoader.exists(c):
			trouve = c
			break
	_chemins[nom] = trouve
	return trouve

## Flux d'un son préchargé ; null tant que sa lecture en tâche de fond n'est pas finie (le son est alors simplement sauté).
static func _flux_de(nom: String) -> AudioStream:
	if _flux.has(nom):
		return _flux[nom]
	var ch := _chemin(nom)
	if ch == "":
		_flux[nom] = null
		return null
	var st := ResourceLoader.load_threaded_get_status(ch)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	var a: AudioStream = ResourceLoader.load_threaded_get(ch) if st == ResourceLoader.THREAD_LOAD_LOADED else load(ch)
	_flux[nom] = a
	return a

## Joue une variante de la catégorie `cat` au point (gain par fichier + volume + hauteur).
## Au plus SONS_PAR_IMAGE sons de combat lancés dans une même image (5 finishers simultanés : pas de pic, et pas de bouillie sonore).
const SONS_PAR_IMAGE := 6
static var _image := -1
static var _n_image := 0

static func son(n: Node, cat: String, point: Vector3, volume := 0.0, hauteur := 1.0) -> void:
	var l: Array = BANQUE.get(cat, [])
	if l.is_empty() or n == null or not n.is_inside_tree():
		return
	var img := Engine.get_process_frames()
	if img != _image:
		_image = img
		_n_image = 0
	if _n_image >= SONS_PAR_IMAGE:
		return
	_n_image += 1
	var nom: String = l.pick_random()
	if l.size() > 1 and nom == _derniers.get(cat, ""):
		nom = l[(l.find(nom) + 1) % l.size()]
	_derniers[cat] = nom
	var s := _flux_de(nom)
	if s == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = volume + float(GAIN.get(nom, 0.0))
	a.unit_size = 5.0
	a.max_distance = 60.0
	a.pitch_scale = hauteur * randf_range(0.94, 1.06)
	if AudioServer.get_bus_index("Effets") >= 0:
		a.bus = "Effets"
	var scene := n.get_tree().current_scene
	(scene if scene else n.get_tree().root).add_child(a)
	a.global_position = point
	a.play()
	a.finished.connect(a.queue_free)

## Sons d'impact : chair (tranche, + chair éclatée et déchirure pour les gros coups), os (craquement), bois, mailles.
static func son_impact(n: Node, matiere: String, p: ProfilImpact, point: Vector3, armure := false) -> void:
	var v := p.volume_db if p else 0.0
	var nom := p.nom if p else "leger"
	var lourd := nom in ["lourd", "critique", "finisher"]
	match matiere:
		"os":
			son(n, "os", point, v, 0.9 if lourd else 1.0)
		"bois":
			son(n, "bois", point, v - 1.0)
		_:
			son(n, "chair", point, v)
			if lourd or nom == "moyen":
				son(n, "chair_gore", point, v - (0.0 if lourd else 4.0), 0.9 if lourd else 1.0)
			if nom in ["critique", "finisher"] and Sang.niveau() > 0:
				son(n, "dechirure", point, v - 2.0)
			if lourd and Sang.niveau() == 2:
				son(n, "jet_sang", point, v - 4.0)
	if armure:
		son(n, "armure", point, v - 2.0)

static func son_blocage(n: Node, point: Vector3, brise := false) -> void:
	son(n, "bois", point, 1.0)
	if brise:
		son(n, "armure", point, 2.0, 0.8)

## Signal sonore : la posture est brisée, finisher possible (carillon discret).
static func son_finisher_dispo(n: Node, point: Vector3) -> void:
	son(n, "coup_de_grace", point, 2.0)

static func son_finisher(n: Node, point: Vector3, matiere: String, decapitation := false) -> void:
	if decapitation and matiere == "chair" and Sang.niveau() > 0:
		son(n, "decapitation", point, 4.0)
	elif matiere == "os":
		son(n, "os", point, 5.0, 0.8)
		son(n, "os", point, 2.0, 1.1)
	else:
		son(n, "chair_gore", point, 4.0, 0.85)
		son(n, "dechirure", point, 2.0)

## Chute d'un corps (cadavre qui touche le sol).
static func son_chute(n: Node, point: Vector3) -> void:
	var sol := sol_force if sol_force != "" else ("pierre" if point.y < -8.0 else "neige")
	son(n, "chute_" + sol, point, 1.0)

## Cris : douleur (coup reçu), étourdi, agonie (mort). Draugrs : râles de mort-vivant ; vivants : voix humaine ; os : rien.
static func cri(n: Node, sorte: String, point: Vector3, matiere: String, mort_vivant := true) -> void:
	if matiere != "chair":
		if sorte == "mort":
			son(n, "os", point, 2.0, 0.75)
		return
	match sorte:
		"douleur":
			son(n, "draugr_douleur" if mort_vivant else "douleur", point, -2.0, 1.1 if mort_vivant else 1.0)
		"etourdi":
			son(n, "draugr_douleur" if mort_vivant else "douleur", point, 0.0, 0.85)
		"mort":
			son(n, "draugr_mort" if mort_vivant else "douleur", point, 0.0, 1.0 if mort_vivant else 0.85)
