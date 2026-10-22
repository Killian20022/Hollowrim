extends Node3D
## Le tertre de Svanhild : un tumulus au nord du cercle runique et, sous terre, la crypte.
## La crypte est construite très en dessous du monde ; y entrer téléporte le joueur
## (fondu au noir) et coupe la lune, la neige et le cycle du ciel.
##
## Plan de la crypte (repère local, l'entrée regarde +Z, on s'enfonce vers -Z) : vestibule (fresque des trois sceaux) → couloir des niches →
## salle de préparation des morts (levier) → herse → salle rituelle (trois socles, porte scellée) → antichambre → arène de Svanhild
## (sarcophage, z = -72) → tombeau (choix moral). Ailes : ossuaire / galerie des ancêtres (sceau des Os), salle des glaces / quartiers / trône
## (sceau du Givre), étage −1 : archives, chapelle, cisterne (sceau de l'Eau). Plan complet : docs/DONJONS.md.
## Le vestibule, l'alcôve d'Eirik et le couloir de la herse (pièces uniques) sont bâtis ici ; tout le reste est assemblé par
## scripts/crypte_donjon.gd avec le kit de modules scripts/donjon_kit.gd, dans un fil d'exécution. Voir docs/MISSION_GRAPHISME.md, « Crypte agrandie ».

signal entree(dedans: bool)

const PROFONDEUR := -140.0
const SARCO := Vector3(0, 0, -72)          # sarcophage de Svanhild (arène)
const BUTIN := preload("res://scripts/butin.gd")

var monde: Node3D
var joueur: CharacterBody3D
var dialogue: Control
var quetes: Node
var hud: Control
var porte_dehors := Vector3.ZERO   # posé par le monde : devant la porte du tumulus
var orientation := 0.0             # lacet de la façade du tumulus

var crypte: Node3D
var corps: StaticBody3D
var dedans := false
var herse: Node3D
var _herse_ouverte := false
var _svanhild: CharacterBody3D = null
var _svanhild_levee := false
var _anneau_rendu := false
var _lueur_tombe: OmniLight3D
var _manche: Node3D
var d: CrypteDecor
var d2: CrypteDecor                 # décor du donjon (fil d'exécution)
var donjon: CrypteDonjon
var _tache := -1
var _cont: Node3D
var _inter := {}                    # id -> interactif du donjon
var _file_gardiens: Array = []
const BUDGET_POSE_US := 1500        # pose étalée du donjon : ≤ 1,5 ms par image
const BUDGET_POSE_NOIR_US := 8000   # pendant le fondu au noir de l'entrée (écran noir) : on pose plus vite, sans figer l'image
var _entree_en_attente := false     # entrée demandée avant la fin du bâti : l'écran reste noir, les images continuent
var _etapes_fin: Array = []         # fin de l'intégration (interactions, gardiens, un mécanisme par image, état) : Callables en file
var _reste_donjon: Array = []       # enfants du donjon encore hors de l'arbre
var _t_pose := 0
var morts_charges: Array = []       # draugrs tués d'une partie chargée (posé par le monde) : on ne les refait pas
var _pas_zone := 0.0
var _vu_vestibule := false
var _vu_trone := false
var _flamme_pixel: MeshInstance3D
var _t := 0.0

var m_pierre: ShaderMaterial
var m_dalle: ShaderMaterial
var m_poutre: ShaderMaterial
var m_fer: ShaderMaterial
var m_neige: ShaderMaterial

func _ready() -> void:
	m_pierre = Palette.materiau(Palette.tex("pierre_crypte", ["#1c1f26", "#272b34", "#323743", "#3f4553"], 4, 0.5), Vector2(2, 2))
	m_dalle = Palette.materiau(Palette.tex("dalle", ["#15171c", "#1e2128", "#282c35", "#333844"], 2, 0.35), Vector2(4, 4))
	m_poutre = Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(0.5, 2), Color(0.6, 0.58, 0.56))
	m_fer = Palette.materiau(Palette.tex("acier", Palette.ACIER, 4, 0.3), Vector2.ONE, Color(0.4, 0.42, 0.5))
	m_neige = Palette.materiau(Palette.tex_neige, Vector2(4, 4))
	_tumulus()
	crypte = Node3D.new()
	# sous le cercle runique, dans les limites de la carte (±108 m)
	crypte.position = Vector3(global_position.x, PROFONDEUR, global_position.z + 25.0)
	monde.add_child(crypte)
	corps = StaticBody3D.new()
	crypte.add_child(corps)
	_construire_crypte()
	crypte.visible = false      # tant qu'on est dehors, ni rendu ni lumières (le décor reste solide)

func _process(dt: float) -> void:
	_t += dt
	if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
		_integrer_donjon()
	elif not _reste_donjon.is_empty() or not _etapes_fin.is_empty():
		_poser_donjon(BUDGET_POSE_NOIR_US if _entree_en_attente else BUDGET_POSE_US)
	elif _entree_en_attente and _tache < 0:
		_entree_en_attente = false
		_basculer(true)
	if d != null and dedans:
		d.vaciller(_t)
		if d2 != null:
			d2.vaciller(_t)
		_pas_zone -= dt
		if _pas_zone <= 0.0:
			_pas_zone = 0.25
			_gerer_zones()
	_flamme_main()
	if not dedans and joueur.global_position.distance_to(porte_dehors) < 9.0:
		quetes.signaler("lieu:tertre")
	if _lueur_tombe:
		var cible := 3.6 if _anneau_rendu else 2.4 + sin(_t * 1.3) * 0.4
		_lueur_tombe.light_energy = lerpf(_lueur_tombe.light_energy, cible, 1.0 - exp(-2.0 * dt))
	# la mort de Svanhild ouvre la porte du tombeau (et lève le sceau de l'arène si l'on y est entré autrement)
	if dedans and donjon != null and _donjon_pret() and quetes.vus.has("tue:svanhild"):
		_porte_haut("tombe")
		_porte_haut("arene")
	# Svanhild se lève quand on approche du sarcophage avec l'anneau
	if dedans and not _svanhild_levee and joueur.inventaire.a("anneau_givre"):
		if joueur.global_position.distance_to(crypte.to_global(SARCO)) < 8.0:
			_lever_svanhild()

## Sous terre, la flamme de la torche tenue en main devient un sprite pixel art (les grosses particules
## additives faisaient une tache blanche carrée sans glow) ; dehors, tout est remis comme avant.
func _flamme_main() -> void:
	return   # lot 6 : la torche tenue porte déjà son sprite de flamme partout (scripts/torche.gd)
	@warning_ignore("unreachable_code")
	var mains: Node = joueur.mains
	if mains == null or d == null:
		return
	if dedans and _flamme_pixel == null and mains.porte_torche != null:
		_flamme_pixel = d.flamme_sur(mains.porte_torche, Vector3(0, 0.53, 0.0), 0.5)
	if _flamme_pixel == null:
		return
	_flamme_pixel.visible = dedans and mains.torche_lumiere.visible
	for i in mains.flammes.size():
		if i != 3:                               # on garde les étincelles ; cœur, corps, langues et fumée cèdent la place au sprite
			mains.flammes[i].visible = not dedans

# --- extérieur ---------------------------------------------------------------------

func _tumulus() -> void:
	# butte de terre enneigée, posée sur le sol (le nœud est au pied de la façade)
	var butte := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 7.5
	s.height = 15.0
	s.radial_segments = 12
	s.rings = 6
	butte.mesh = s
	# lot 5 : façade et butte en pierre / neige pixel art (16 texels/m) ; la crypte garde ses matériaux
	var m_facade := TexturesPetites.m_roche_e(Color(0.8, 0.79, 0.84))
	var m_porte_dalle := TexturesPetites.m_roche_e(Color(0.42, 0.42, 0.5))
	butte.material_override = TexturesBati.m_neige_toit_e()
	butte.scale = Vector3(1, 0.6, 1)                # refonte crypte : butte reculée et plus haute, derrière la façade monumentale
	butte.position = Vector3(0, -0.6, -15.0)
	add_child(butte)
	var corps_dehors := StaticBody3D.new()
	add_child(corps_dehors)
	# collision = faces de la sphère visible (même échelle, même décalage) : on peut gravir la butte
	var xf_butte := Transform3D(Basis.from_scale(butte.scale), butte.position)
	var faces := PackedVector3Array()
	for v in s.get_faces():
		faces.append(xf_butte * v)
	var dome := ConcavePolygonShape3D.new()
	dome.set_faces(faces)
	dome.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "CollisionDome"
	cs.shape = dome
	corps_dehors.add_child(cs)
	# façade : pierres levées, linteau, jambages, dalle de porte (lot 5, 2e passe : FacadeTertre)
	FacadeTertre.construire(self, corps_dehors, m_facade, m_porte_dalle)
	# runes qui luisent sur le linteau
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 0.8
	lueur.omni_range = 5.0
	lueur.position = Vector3(0, 2.6, 0.6)
	add_child(lueur)
	var runes := _boite(self, Vector3(2.2, 0.12, 0.04), Transform3D(Basis(), Vector3(0, 3.0, 0.16)), Palette.lueur(Color(0.5, 1.4, 1.9)))
	runes.name = "Runes"
	_interactif(self, Vector3(0, 1.2, 0.3), "Tertre de Svanhild", "Entrer dans le tertre", func() -> Array: return _passer(true))

# --- crypte --------------------------------------------------------------------------
## Lot 7a : toute la construction visible (murs, voûtes, piliers, mobilier, lumières) est dans CrypteDecor ;
## ici ne restent que le plan, les collisions d'origine (refaites à l'identique par CrypteDecor), les
## interactions, les gardiens et le corps d'Eirik.

func _construire_crypte() -> void:
	var t0 := Time.get_ticks_msec()
	d = CrypteDecor.new(crypte, corps)
	_entree()
	_alcove()
	_couloir_herse()
	_sarcophage_arene()
	var t1 := Time.get_ticks_msec()
	d.finir()
	CrypteDonjon.limiter_portee(crypte)   # portée de dessin ~30 m
	print("Crypte (lot 7a) : plan %d ms + finition %d ms = %d ms" % [t1 - t0, Time.get_ticks_msec() - t1, Time.get_ticks_msec() - t0])
	# donjon : bâti en parallèle, hors de l'arbre ; intégré dès qu'il est prêt (au plus tard à l'entrée dans la crypte)
	_cont = Node3D.new()
	_cont.name = "Donjon"
	var corps2 := StaticBody3D.new()
	_cont.add_child(corps2)
	d2 = CrypteDecor.new(_cont, corps2, d)
	donjon = CrypteDonjon.new(d2)
	_tache = WorkerThreadPool.add_task(_batir_donjon.bind(donjon, d2))

## Le fil ne touche qu'à ses deux arguments (jamais à la scène ni aux membres du tertre : le monde peut être libéré pendant qu'il tourne).
func _batir_donjon(dj: CrypteDonjon, decor: CrypteDecor) -> void:
	FilVerrou.prendre()
	var t0 := Time.get_ticks_msec()
	dj.construire()
	decor.finir()
	FilVerrou.rendre()
	print("Donjon : bâti en %d ms (fil d'exécution)" % (Time.get_ticks_msec() - t0))

## Sortie du jeu / fin d'un test pendant la construction : on attend le fil (sinon fuites de ressources).
func _exit_tree() -> void:
	if _tache >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1
		if _cont != null and is_instance_valid(_cont) and not _cont.is_inside_tree():
			_cont.free()
	for c in _reste_donjon:
		if is_instance_valid(c) and not c.is_inside_tree():
			c.free()
	_reste_donjon.clear()
	_etapes_fin.clear()

## Donjon bâti, posé et intégré (interactions, mécanismes, état) ?
func _donjon_pret() -> bool:
	return _tache < 0 and _reste_donjon.is_empty() and _etapes_fin.is_empty()

## À l'entrée dans la crypte : tout le donjon doit être là tout de suite (pose complète, sans budget).
func attendre_donjon() -> void:
	_integrer_donjon()
	_poser_donjon(0)

## Le fil a fini : le nœud « Donjon » (≈ 1 100 enfants : lumières, murs, portes, flammes) entre dans l'arbre VIDE, puis ses enfants
## sont posés par tranches de BUDGET_POSE_US par image (poser les 1 356 nœuds d'un coup coûtait une image de ~40 ms en pleine marche).
func _integrer_donjon() -> void:
	if _tache < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_tache)
	_tache = -1
	_t_pose = Time.get_ticks_msec()
	CrypteDonjon.limiter_portee(_cont)   # portée de dessin ~30 m (fil principal : get_aabb interroge le serveur de rendu, blocage dans un fil)
	_reste_donjon = _cont.get_children()
	for c in _reste_donjon:
		_cont.remove_child(c)
	_reste_donjon.reverse()          # pop_back = ordre d'origine
	crypte.add_child(_cont)
	_poser_donjon(BUDGET_POSE_US)

## budget_us = 0 : tout, tout de suite (entrée, tests, partie chargée sous terre) ; sinon pose par tranches, puis les étapes de
## fin (interactions, gardiens, mécanismes un par image : un piège coûte jusqu'à ~85 ms à créer) sur les images suivantes.
func _poser_donjon(budget_us: int) -> void:
	var debut := Time.get_ticks_usec()
	if not _reste_donjon.is_empty():
		while not _reste_donjon.is_empty():
			_cont.add_child(_reste_donjon.pop_back())
			if budget_us > 0 and Time.get_ticks_usec() - debut > budget_us:
				return
		_etapes_fin = _plan_fin()
		if budget_us > 0:
			return
	while not _etapes_fin.is_empty():
		(_etapes_fin.pop_front() as Callable).call()
		if budget_us > 0:
			return

func _plan_fin() -> Array:
	var e: Array = [func() -> void:
		for it in donjon.interactions:
			_creer_interaction(it)
		for g in donjon.gardiens:
			_file_gardiens.append(g)]
	for a in donjon.meca:
		e.append(_poser_meca.bind(a))
	e.append(_finir_donjon)
	return e

func _finir_donjon() -> void:
	var t0 := _t_pose
	_etat_donjon()
	print("Donjon : intégré en %d ms (%d interactions, %d gardiens, %d mécanismes, %d lumières)" % [Time.get_ticks_msec() - t0, donjon.interactions.size(), donjon.gardiens.size(), donjon.meca.size(), d2.toutes.size()])

## Pièges et mécanismes du donjon (classes Piege et Mecanisme) : posés sous `crypte` ; leurs états sont dans quetes.vus (« meca:<ident>:… »).
func _poser_meca(a: Dictionary) -> void:
	var id: String = a["id"]
	var ctx := {"joueur": joueur, "dialogue": dialogue, "quetes": quetes}
	match a["genre"]:
		"dalle_flechettes":
			Piege.dalle_flechettes(crypte, a["pos_dalle"], a["pos_bouche"], a["dir"], id, ctx)
		"souffle_givre":
			Piege.souffle_givre(crypte, a["pos"], a["dir"], a["longueur"], a["periode"], id, ctx)
		"statues":
			Mecanisme.statues(crypte, a["positions"], a["solution"], id, _ouvrir_secret, ctx)
		"braseros":
			Mecanisme.braseros(crypte, a["positions"], a["ordre"], id, Callable(), ctx)
		"socles":
			Mecanisme.socles(crypte, a["positions"], a["objets"], id, _ouvrir_arene, ctx)
		"mur_fragile":
			ctx["materiau"] = d.mat(a.get("materiau", "mur0"))      # même pierre que le mur voisin
			Mecanisme.mur_fragile(crypte, a["pos"], a["taille"], a["lacet"], id, Callable(), ctx)

## Rend au donjon l'état d'une partie chargée (portes ouvertes, coffres vidés, mur pivoté, arène et tombeau).
func _etat_donjon() -> void:
	for id in _inter:
		var it: Node3D = _inter[id]
		if it.get_meta("genre_donjon", "") == "coffre" and quetes.vus.has("crypte:" + id):
			it.actif = false
	for id in ["s1", "s2"]:
		if quetes.vus.has("crypte:" + id) and donjon.portes.has(id):
			(donjon.portes[id] as Node3D).position.y = 3.2
	if quetes.vus.has("crypte:secret") and donjon.portes.has("secret"):          # anciennes parties : le crâne pivotant
		(donjon.portes["secret"] as Node3D).rotation.y = -PI * 0.5
	if quetes.vus.has("tue:svanhild"):                                           # Svanhild déjà vaincue : plus de sceau, tombeau accessible
		_porte_haut("arene", true)
		_porte_haut("tombe", true)

## Lève (ou baisse) une porte coulissante du donjon, avec animation sauf à la restauration.
func _porte_haut(id: String, instant := false) -> void:
	if not donjon.portes.has(id):
		return
	var p: Node3D = donjon.portes[id]
	if absf(p.position.y - 3.2) < 0.05:
		return
	if instant or Mecanisme.restauration:
		p.position.y = 3.2
		return
	var t := create_tween()
	t.tween_property(p, "position:y", 3.2, 2.2).set_trans(Tween.TRANS_SINE)
	Sons.jouer_a(self, ["impactMetal_heavy_000", "doorOpen_1"], p.global_position, 2.0)
	joueur.secousse = 0.4

## Rappelé par les socles (aussi à la restauration) : les trois sceaux sont rétablis, la porte de l'arène s'ouvre.
func _ouvrir_arene() -> void:
	quetes.signaler("meca:socles_rituel:complet")
	_porte_haut("arene")

func _creer_interaction(it: Dictionary) -> void:
	var id: String = it["id"]
	var genre: String = it["genre"]
	var non: String = it.get("condition_non", "")
	var requiert: Array = it.get("requiert", [])
	var interdit: Array = it.get("interdit", [])
	var evt: String = it.get("evt", "")
	var cond := Callable()
	if non != "" or not requiert.is_empty() or not interdit.is_empty() or evt != "":
		cond = func() -> bool:
			if non != "" and quetes.vus.has("crypte:" + non):
				return false
			for k: String in requiert:
				if not quetes.vus.has(k):
					return false
			for k: String in interdit:
				if quetes.vus.has(k):
					return false
			return evt == "" or not quetes.vus.has(evt)
	var action: Callable
	match genre:
		"texte":
			var lignes: Array = it.get("texte", [])
			var cle: String = it.get("cle", "")
			var plus: Array = it.get("plus", [])
			action = func() -> Array:
				if cle == "":
					return lignes
				var l: Array = quetes.texte(cle).duplicate()
				l.append_array(plus)
				return l
		"porte":
			action = func() -> Array: return _ouvrir_porte(id)
		"secret":
			action = func() -> Array: return _ouvrir_secret()
		"fragment":
			action = func() -> Array: return _prendre_fragment(it)
		"choix":
			var choix: String = it["choix"]
			action = func() -> Array: return _choisir(choix)
		_:
			var butin: Dictionary = it["butin"]
			var lieu: Vector3 = it["coffre"]
			action = func() -> Array: return _ouvrir_coffre(id, butin, lieu)
			cond = func() -> bool: return not quetes.vus.has("crypte:" + id)
	var n := _interactif(crypte, it["pos"], it["nom"], it["verbe"], action, cond, genre == "coffre")
	n.set_meta("genre_donjon", genre)
	_inter[id] = n

func _ouvrir_porte(id: String) -> Array:
	quetes.signaler("crypte:" + id)
	var p: Node3D = donjon.portes[id]
	var t := create_tween()
	t.tween_property(p, "position:y", 3.2, 1.6).set_trans(Tween.TRANS_SINE)
	Sons.jouer_a(self, ["impactMetal_heavy_000", "impactPlate_medium_000"], p.global_position, 1.0)
	joueur.secousse = 0.2
	return []

## Rappelé par les statues (aussi à la restauration) : le mur pivotant de la galerie des ancêtres s'ouvre sur le trésor.
func _ouvrir_secret() -> Array:
	quetes.signaler("crypte:secret")
	var p: Node3D = donjon.portes["secret"]
	if Mecanisme.restauration:
		p.rotation.y = -PI * 0.5
		return []
	var t := create_tween()
	t.tween_property(p, "rotation:y", -PI * 0.5, 2.2).set_trans(Tween.TRANS_SINE)
	Sons.jouer_a(self, ["impactPlate_medium_000", "creak1"], p.global_position, 1.5)
	joueur.secousse = 0.35
	return []

## Fragment de sceau : objet de l'inventaire (quetes signale « ramasse:<objet> » tout seul : les gardiens `reveil_evt` se réveillent) + marqueur.
func _prendre_fragment(it: Dictionary) -> Array:
	var objet: String = it["objet"]
	quetes.signaler(it["evt"])
	joueur.inventaire.ajouter(objet)
	hud.avis("+ " + joueur.inventaire.nom(objet))
	joueur.secousse = 0.3
	Sons.jouer_a(self, ["impactPlate_medium_000"], crypte.to_global(it["pos"]), 0.0)
	return it["texte"]

## Choix moral devant les offrandes royales (définitif, géré par quetes.choisir) : piller (or, reliques, « vague_gardiens ») ou respecter (bénédiction).
func _choisir(choix: String) -> Array:
	if not quetes.choisir(choix):
		return []
	joueur.secousse = 0.4
	return quetes.texte("choix_piller" if choix == "piller_offrandes" else "choix_respecter")

func _ouvrir_coffre(id: String, contenu: Dictionary, lieu: Vector3) -> Array:
	quetes.signaler("crypte:" + id)
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	b.contenu = contenu.duplicate()
	b.set_meta("coffre", id)         # pour rendre le coffre si le joueur meurt avant d'avoir ramassé la bourse
	crypte.add_child(b)
	b.position = lieu + Vector3(0, 0.7, 0)
	Sons.jouer_a(self, ["doorOpen_1", "handleCoins"], crypte.to_global(lieu), -2.0)
	return []

## Toutes les 0,25 s : lumières (et gardiens du donjon) selon la position du joueur. Seules les lumières proches sont allumées
## (jamais plus d'une vingtaine) ; les gardiens d'une zone n'apparaissent que lorsque le joueur s'en approche.
func _gerer_zones() -> void:
	var pj := joueur.global_position
	for decor in [d, d2]:
		if decor == null:
			continue
		for l: OmniLight3D in decor.toutes:
			var gp := l.global_position
			var dy := gp.y - pj.y
			var meme_etage := (gp.y < crypte.global_position.y - 3.0) == (pj.y < crypte.global_position.y - 3.0)
			l.visible = (meme_etage or absf(dy) < 3.2) and absf(dy) < 6.0 and Vector2(gp.x - pj.x, gp.z - pj.z).length() < 26.0
	# lieux de quête : vestibule et salle du trône (le Jarl parle à qui entre, s'il est encore là)
	var pl := crypte.to_local(pj)
	if not _vu_vestibule and absf(pl.x) < 3.0 and pl.z > -6.0 and pl.z < 4.0 and absf(pl.y) < 3.0:
		_vu_vestibule = true
		quetes.signaler("lieu:vestibule_crypte")
	if not _vu_trone and pl.x > 43.0 and pl.x < 59.0 and pl.z > -38.0 and pl.z < -22.0 and absf(pl.y) < 3.0:
		_vu_trone = true
		quetes.signaler("lieu:salle_trone")
		var jarl = monde.draugrs.get("jarl")
		if jarl != null and is_instance_valid(jarl) and jarl.vivant():
			var lj: Array = quetes.texte("jarl_reveil")
			if not lj.is_empty():
				dialogue.dire_au_passage("Kolbeinn", lj[0])
	var n := 0
	var i := 0
	while i < _file_gardiens.size() and n < 2:
		var g: Dictionary = _file_gardiens[i]
		var zr: Rect2 = Rect2()
		var zy := 0.0
		for z in donjon.zones:
			if z["nom"] == g["zone"]:
				zr = z["rect"]
				zy = z["y"]
		var c := crypte.to_global(Vector3(zr.get_center().x, zy, zr.get_center().y))
		if absf(c.y - pj.y) < 8.0 and Vector2(c.x - pj.x, c.z - pj.z).length() < 34.0 + zr.size.length() * 0.25:
			var extra: Dictionary = (g["extra"] as Dictionary).duplicate()
			var si: String = extra.get("si", "")
			if si != "" and not quetes.vus.has(si):          # gardiens conditionnés (ex. serment après un pillage) : restent en file
				i += 1
				continue
			extra.erase("si")
			_file_gardiens.remove_at(i)
			if not morts_charges.has(g["ident"]):
				var opts := {"debout": g["debout"], "ident": g["ident"]}
				for k in extra:
					opts[k] = extra[k]
				if extra.has("patrouille"):
					var pts: Array = []
					for q: Vector3 in extra["patrouille"]:
						pts.append(crypte.to_global(q))
					opts["patrouille"] = pts
				var dr: CharacterBody3D = monde.creer_draugr(g["type"], crypte.to_global(g["pos"] + Vector3(0, 0.05, 0)), g["lacet"], g["dort"], opts)
				if monde._paisible():
					dr.process_mode = Node.PROCESS_MODE_DISABLED
			n += 1
		else:
			i += 1

func _toiles(coins: Array, haut: float) -> void:
	# coins : [x, z, vers_x, vers_z] (directions le long des deux murs qui forment le coin)
	for c in coins:
		d.toile(Vector3(c[0], haut, c[1]), Vector3(c[2], 0, 0), Vector3(0, 0, c[3]))

func _entree() -> void:
	d.salle(-3, 3, 4, -6, 3.6, [["nord", 0.0, 3.2], ["est", -2.0, 3.2]], 0.0, "mur0")
	# escalier qui remonte vers la sortie (décor, contre le mur sud) et passage sombre au-dessus
	for i in 4:
		d.boite("dalle0", Vector3(0, 0.15 * (4 - i), 3.4 - i * 0.6), Vector3(3.0, 0.3 * (4 - i), 0.6))
	d.quad("noir", Vector3(-1.0, 1.2, 3.69), Vector3(1.0, 1.2, 3.69), Vector3(1.0, 3.0, 3.69), Vector3(-1.0, 3.0, 3.69), Vector3(0, 0, -1))
	d.boite("mur0", Vector3(-1.2, 2.1, 3.62), Vector3(0.4, 1.8, 0.16))
	d.boite("mur0", Vector3(1.2, 2.1, 3.62), Vector3(0.4, 1.8, 0.16))
	d.boite("mur0", Vector3(0, 3.1, 3.62), Vector3(2.8, 0.4, 0.16))
	_interactif(crypte, Vector3(0, 1.6, 1.5), "Sortie", "Sortir du tertre", func() -> Array: return _passer(false))
	# doubleaux de pierre (CrypteDecor.poutre dans la crypte) retombant sur des pilastres sculptés (décor seul, sans collision)
	for z in [2.4, 0.8, -1.4, -4.6]:
		d.poutre(-2.7, 2.7, 3.45, z)
	for p: Array in [[-2.7, 2.4], [-2.7, 0.8], [2.7, 2.4], [2.7, 0.8], [-2.7, -1.4], [-2.7, -4.6], [2.7, -4.6]]:
		d.pilastre_mur(Vector3(p[0], 0, p[1]), Vector3(-signf(p[0]), 0, 0), 2.7)
	d.brasero(Vector3(-2.3, 0, -5.2))
	d.brasero(Vector3(2.3, 0, -5.2))
	d.applique(Vector3(-2.7, 0, 0.0), Vector3(1, 0, 0), 2.1, 5.0, 1.7)
	d.applique(Vector3(2.7, 0, 0.0), Vector3(-1, 0, 0), 2.1, 5.0, 1.7)
	d.urne(Vector3(-2.2, 0, -3.4), 1.0)
	d.urne(Vector3(2.15, 0, -4.4), 0.8)
	d.os_tas(Vector3(-1.9, 0, 2.7), 3, 0.3)
	d.arme(Vector3(-1.4, 0, -1.4), 0.6)
	_toiles([[-2.7, 3.7, 1, -1], [2.7, 3.7, -1, -1], [-2.7, -5.7, 1, 1], [2.7, -5.7, -1, 1]], 3.6)
	# fresque des trois sceaux (Os, Givre, Eau) sur le mur ouest : l'objectif de la crypte se lit dès l'entrée
	d.frise(["os", "givre", "eau"], Vector3(-2.68, 1.85, -2.9), Vector3(1, 0, 0), 0.8, 1.15)
	_interactif(crypte, Vector3(-2.2, 1.4, -2.9), "Fresque des trois sceaux", "Examiner la fresque", func() -> Array: return quetes.texte("fresque_sceaux"))

func _alcove() -> void:
	d.salle(-11, -7, -23, -27, 3.0, [["est", -25.0, 3.0]], 0.0, "mur2")
	var eirik: Node3D = PnjNordique.creer("eirik") if not PnjNordique.ancien() else Humain.creer({"corps": "homme", "cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.85, 0.55, 0.3), "peau": Color(0.75, 0.75, 0.8),
		"tenue": {"tunique": Color(0.4, 0.5, 0.42), "pantalon": Color(0.6, 0.55, 0.5), "bottes": Color.WHITE, "ceinture": Color.WHITE, "mante": Color(0.9, 0.85, 0.8)}})
	eirik.position = Vector3(-9.3, 0.02, -25.0)
	eirik.rotation.y = 1.2
	crypte.add_child(eirik)
	var ap: AnimationPlayer = eirik.get_node("Animations")
	ap.play("Death01")
	ap.seek(ap.get_animation("Death01").length - 0.05, true)
	ap.pause()
	_interactif(crypte, Vector3(-9.3, 0.6, -25.0), "Note d’Eirik", "Fouiller le corps d’Eirik", _fouiller_eirik, Callable(), true)
	d.coffre(Vector3(-10.2, 0, -26.4), 0.0)
	d.table(Vector3(-9.0, 0, -23.75), 0.0)
	d.bougie(Vector3(-9.35, 0.795, -23.8))      # la chandelle d'Eirik
	d.etagere(Vector3(-8.5, 0, -26.53), 0.0, 1.7, 2.0)
	d.applique(Vector3(-10.7, 0, -25.0), Vector3(1, 0, 0), 2.1, 4.2, 1.2)
	d.arme(Vector3(-8.2, 0, -24.9), 2.6)
	d.os_tas(Vector3(-10.2, 0, -24.0), 2, 0.25)
	_toiles([[-10.7, -23.3, 1, -1], [-7.3, -26.7, -1, 1]], 3.0)

func _couloir_herse() -> void:
	d.salle(-1.6, 1.6, -32, -42, 3.2, [["sud", 0.0, 3.2], ["nord", 0.0, 3.2]], 0.0, "mur2")
	for z in [-34.5, -36.5, -38.5, -40.5]:
		d.poutre(-1.3, 1.3, 3.05, z)
	for p: Array in [[-1.3, -34.5], [1.3, -34.5], [-1.3, -36.5], [-1.3, -38.5], [-1.3, -40.5], [1.3, -40.5]]:
		d.pilastre_mur(Vector3(p[0], 0, p[1]), Vector3(-signf(p[0]), 0, 0), 2.3)
	herse = Node3D.new()
	herse.position = Vector3(0, 0, -33.0)
	crypte.add_child(herse)
	var corps_herse := StaticBody3D.new()
	herse.add_child(corps_herse)
	for i in 7:
		d.instance_boite(herse, "fer", Vector3(0.08, 3.1, 0.08), Vector3(-1.35 + i * 0.45, 1.55, 0))
	for y in [0.6, 1.8, 2.8]:
		d.instance_boite(herse, "fer", Vector3(3.0, 0.08, 0.08), Vector3(0, y, 0))
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 3.2, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = bs
	cs.position = Vector3(0, 1.6, 0)
	corps_herse.add_child(cs)
	# levier, contre le mur est de la salle des piliers
	var levier := Node3D.new()
	levier.position = Vector3(6.55, 1.1, -25.0)
	crypte.add_child(levier)
	d.instance_boite(levier, "fer", Vector3(0.2, 0.5, 0.3), Vector3.ZERO)
	var manche := d.instance_boite(levier, "bois", Vector3(0.06, 0.6, 0.06), Vector3(-0.15, 0.25, 0))
	manche.rotation = Vector3(0, 0, 0.5)
	_manche = manche
	_interactif(crypte, Vector3(6.3, 1.1, -25.0), "Levier", "Tirer le levier", _tirer_levier, func() -> bool: return not _herse_ouverte)
	d.applique(Vector3(1.3, 0, -37.5), Vector3(-1, 0, 0), 1.9, 4.5, 1.5)
	d.os_tas(Vector3(-0.8, 0, -34.7), 4, 0.35)
	d.arme(Vector3(0.5, 0, -39.0), 1.0)
	d.urne(Vector3(-1.0, 0, -41.2), 0.9)
	d.urne(Vector3(1.0, 0, -41.0), 0.8)
	_toiles([[-1.3, -32.3, 1, -1], [1.3, -41.7, -1, 1]], 3.2)

## Sarcophage de Svanhild, dans l'arène (les degrés de l'estrade sont dans le donjon) : mêmes formes que l'ancien tombeau.
func _sarcophage_arene() -> void:
	var o := Vector3(0, 0.2, 0)         # dessus du troisième degré = 0,6 ; l'ancien socle était à 0,4
	d.boite_pleine("mur0", Vector3(0, 0.9, -72.0) + o, Vector3(1.6, 1.0, 3.0))
	d.boite("mur1", Vector3(0, 0.52, -72.0) + o + Vector3(0, 0, 0), Vector3(1.9, 0.24, 3.3))
	d.boite("gravure", Vector3(0, 1.48, -72.0) + o, Vector3(1.8, 0.18, 3.2))
	_boite(crypte, Vector3(1.0, 0.04, 2.2), Transform3D(Basis(), Vector3(0, 1.78, -72.0)), Palette.lueur(Color(0.4, 1.1, 1.6)))
	_lueur_tombe = OmniLight3D.new()
	_lueur_tombe.light_color = Color(0.4, 0.8, 1.0)
	_lueur_tombe.light_energy = 2.4          # lot 7a (2e passe) : source froide propre, basse, qui rase les flancs du sarcophage
	_lueur_tombe.omni_range = 8.5
	_lueur_tombe.omni_attenuation = 1.4
	_lueur_tombe.position = Vector3(0, 2.3, -69.6)
	crypte.add_child(_lueur_tombe)
	d.toutes.append(_lueur_tombe)
	_givre(Vector3(0, 1.8, -72.0))
	var pos := SARCO + Vector3(0, 1.6, 1.9)
	_interactif(crypte, pos, "Inscription", "Lire l’inscription", func() -> Array: return quetes.texte("inscription_tombe"), func() -> bool: return not _peut_rendre())
	_interactif(crypte, pos, "Svanhild", "Replacer l’anneau sur le sarcophage", _rendre_anneau, _peut_rendre)

func _fouiller_eirik() -> Array:
	joueur.inventaire.ajouter("anneau_givre")
	joueur.inventaire.ajouter("amulette_eirik")
	hud.avis("+ Anneau de givre")
	hud.avis("+ Amulette d’Eirik")
	quetes.signaler("ramasse:anneau_givre")
	quetes.signaler("ramasse:amulette_eirik")
	return quetes.texte("note_eirik")

func _tirer_levier() -> Array:
	_herse_ouverte = true
	var t := create_tween()
	t.tween_property(_manche, "rotation:z", -0.5, 0.3)
	t.tween_property(herse, "position:y", 2.9, 2.5).set_trans(Tween.TRANS_SINE)
	Sons.jouer_a(self, ["impactMetal_heavy_000", "impactPlate_medium_000"], herse.global_position, 2.0)
	joueur.secousse = 0.3
	return []

func _rendre_anneau() -> Array:
	joueur.inventaire.retirer("anneau_givre")
	_anneau_rendu = true
	quetes.signaler("lieu:tombe_svanhild")
	joueur.secousse = 0.4
	Sons.jouer(self, ["sword-unsheathe"], -4.0)
	return []

## Remet le tertre dans l'état d'une partie chargée.
func restaurer(herse_ouverte: bool) -> void:
	if herse_ouverte:
		_herse_ouverte = true
		herse.position.y = 2.9
		_manche.rotation.z = -0.5
	_svanhild_levee = quetes.vus.has("tue:svanhild")
	_anneau_rendu = quetes.vus.has("lieu:tombe_svanhild")
	if quetes.vus.has("ramasse:anneau_givre"):
		for it in crypte.get_children():
			if it.get("verbe") == "Fouiller le corps d’Eirik":
				it.actif = false
	# l'état du donjon (portes, coffres, mécanismes) est rendu à son intégration : _finir_donjon()
	# partie sauvegardée sous terre
	if joueur.global_position.y < PROFONDEUR * 0.5 and joueur.global_position.y > GrotteAcces.SEUIL_Y:   # plus bas : la grotte (y ≈ -220)
		attendre_donjon()
		dedans = true
		crypte.visible = true
		entree.emit.call_deferred(true)

## Mort du joueur sous terre : la crypte revient à un état cohérent avec la sauvegarde. Les gardiens tués ne restent morts que
## s'ils le sont dans le fichier de sauvegarde (`morts` : liste imposée, sinon lue dans le fichier) ; les autres sont retirés
## puis remis dans la file d'apparition. Une bourse de coffre non ramassée est perdue : le coffre se referme (rejouable).
## Portes, herse et mur secret suivent les événements des quêtes (qui, eux, restent acquis, comme l'inventaire).
func reinitialiser(morts: Variant = null) -> void:
	if not dedans:
		return
	var sauves: Array = morts if morts is Array else _morts_sauvegardes()
	morts_charges = sauves.duplicate()
	if donjon != null:
		for g in donjon.gardiens:
			var id: String = g["ident"]
			if monde.draugrs.has(id):
				if is_instance_valid(monde.draugrs[id]):
					monde.draugrs[id].queue_free()
				monde.draugrs.erase(id)
		_file_gardiens.clear()
		for g in donjon.gardiens:
			_file_gardiens.append(g)
	if _svanhild != null and is_instance_valid(_svanhild) and _svanhild.vivant():
		monde.draugrs.erase("svanhild")
		_svanhild.queue_free()
		_svanhild = null
		_svanhild_levee = quetes.vus.has("tue:svanhild")
	for b in crypte.get_children():
		if b.has_meta("coffre"):
			var id: String = b.get_meta("coffre")
			b.queue_free()
			quetes.vus.erase("crypte:" + id)
			if _inter.has(id):
				(_inter[id] as Node3D).actif = true
	_etat_donjon()
	Mecanisme.restaurer_tout(crypte)      # statues et braseros repartent de zéro ; états acquis relus dans quetes.vus
	dedans = false
	crypte.visible = false
	entree.emit(false)

func _morts_sauvegardes() -> Array:
	var f: String = monde.fichier_sauvegarde()
	if FileAccess.file_exists(f):
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Dictionary:
			return d.get("draugrs_morts", [])
	return []

func _peut_rendre() -> bool:
	return not _anneau_rendu and joueur.inventaire.a("anneau_givre") and _svanhild_levee and (_svanhild == null or not is_instance_valid(_svanhild) or not _svanhild.vivant())

func _lever_svanhild() -> void:
	_svanhild_levee = true
	_svanhild = monde.creer_draugr("guerrier", crypte.to_global(SARCO + Vector3(0, 0.45, 3.4)), PI, true, {
		"ident": "svanhild", "echelle": 1.12, "boss": "svanhild",
		"apparence": {"corps": "femme", "casque": "couronne_givre", "cheveux": "Hair_Long", "teinte_cheveux": Color(1.1, 1.15, 1.25), "tenue": {"tunique": Color.WHITE, "haillons": Color.WHITE, "cape": Color.WHITE, "mante": Color.WHITE, "brassards": Color.WHITE, "ceinture": Color.WHITE, "bottes": Color.WHITE, "epaulieres": Color.WHITE},
			"etoffes": {"tunique": "draugr", "haillons": "draugr", "cape": "draugr", "mante": "blanc", "epaulieres": "draugr"}},
		"vie_imposee": 260.0, "degats_imposes": 24.0, "nom_affiche": "Svanhild, Dame de givre",
	})
	var lignes: Array = quetes.texte("svanhild_reveil")
	for i in lignes.size():
		get_tree().create_timer(0.4 + i * 3.6).timeout.connect(func() -> void: dialogue.dire_au_passage("Svanhild", lignes[i]))
	_svanhild.mort.connect(func(_id: String) -> void:
		# l'événement « tue:svanhild » est déjà signalé par le monde à chaque mort de draugr
		var fin: Array = quetes.texte("svanhild_defaite")
		if not fin.is_empty():
			dialogue.dire_au_passage("Svanhild", fin[0]))

# --- passage dehors / dedans -----------------------------------------------------------

func _passer(vers_dedans: bool) -> Array:
	if _entree_en_attente:
		return []
	var t := create_tween()
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 0.0, 1.0, 0.5)
	t.tween_callback(func() -> void:
		# donjon pas encore prêt (entrée juste après le chargement) : on ne fige plus l'image en attendant le fil ; l'écran reste
		# noir, le fil finit, la pose et l'intégration se font par tranches (_process), puis on bascule exactement comme avant
		if vers_dedans and not _donjon_pret() and not _entree_synchrone():
			_entree_en_attente = true
			return
		_basculer(vers_dedans))
	Sons.jouer(self, ["doorOpen_1", "creak1"], -4.0)
	return []

## Outils de capture et de mesure de monde.gd (--captures, --crypte, --scenario) : ils se placent 1,3 s après _passer(true) ;
## on garde pour eux l'entrée bloquante d'origine (l'image figée n'y gêne pas).
func _entree_synchrone() -> bool:
	var a: Dictionary = monde._arguments()
	return a.has("capture") or a.has("crypte") or a.has("scenario")

## Bascule dehors / dedans (sous l'écran noir du fondu), puis retour de l'image.
func _basculer(vers_dedans: bool) -> void:
	if vers_dedans:
		attendre_donjon()
	dedans = vers_dedans
	crypte.visible = vers_dedans
	if vers_dedans:
		joueur.global_position = crypte.to_global(Vector3(0, 0.1, 0.5))
		joueur.rotation.y = crypte.global_rotation.y
	else:
		joueur.global_position = porte_dehors + Vector3(0, 0.2, 0)
		joueur.rotation.y = orientation
	joueur.velocity = Vector3.ZERO
	entree.emit(vers_dedans)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 1.0, 0.0, 0.6)

# --- briques --------------------------------------------------------------------------

func _boite(parent: Node3D, taille: Vector3, xf: Transform3D, mat: Material, solide: StaticBody3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if solide != null:
		var bs := BoxShape3D.new()
		bs.size = taille
		var cs := CollisionShape3D.new()
		cs.shape = bs
		solide.add_child(cs)
		cs.global_transform = mi.global_transform
	return mi

func _interactif(parent: Node3D, pos: Vector3, nom: String, verbe: String, action: Callable, condition := Callable(), unique := false) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = verbe
	it.condition = condition
	it.action = action
	it.unique = unique
	it.position = pos
	parent.add_child(it)
	return it

func _givre(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 3.0
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.1, 1.4)
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.05, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = Palette.lueur(Color(0.7, 1.3, 1.8))
	(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.draw_pass_1 = q
	crypte.add_child(p)
