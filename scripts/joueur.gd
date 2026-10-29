extends CharacterBody3D
## Joueur à la première personne : marche, course, saut, balancement de tête,
## vie, vigueur, coups reçus. Les touches sont physiques : ZQSD sur AZERTY = WASD sur QWERTY.

signal touche(degats: float)
signal deces
## Magie (scripts/magie/, docs/MAGIE.md) — contrat avec le HUD (agent effets) : contenu des deux mains (Dictionary :
## genre "sort" / "arme" / "bouclier" / "torche" / "vide", id, nom, ecole, type, cout…) à chaque changement.
signal etat_mains_change(gauche: Dictionary, droite: Dictionary)
## Action refusée (main "gauche" / "droite", raison lisible : « Pas assez de mana », « Recharge », …).
signal action_refusee(main: String, raison: String)

const MAINS := preload("res://scripts/mains.gd")
const CORPS := preload("res://scripts/corps_joueur.gd")
const CAMERA_TP := preload("res://scripts/camera_tp.gd")

const VITESSE := 3.2
const COURSE := 6.5
const SAUT := 4.4
const GRAVITE := 13.0
const SENSIBILITE := 0.0022
const LIMITE := 108.0  # bord du terrain jouable
const COUT_COURSE := 12.0  # vigueur par seconde
const CHUTE_DEHORS := 25.0   # filet anti-chute : sous le terrain de plus de 25 m (dehors)
const CHUTE_SOUS_TERRE := -260.0   # sous terre (la grotte descend à -228,4 m)

var vie := 100.0
var vie_max := 100.0
const VIE_BASE := 100.0
const BONUS_BENEDICTION := 10.0

## Bénédiction des ancêtres (choix « respecter les offrandes », quetes.gd) : +10 vie max permanents, jamais cumulés.
func regler_benediction(active: bool, soigner := false) -> void:
	vie_max = VIE_BASE + (BONUS_BENEDICTION if active else 0.0)
	if soigner and active:
		vie = minf(vie_max, vie + BONUS_BENEDICTION)
	vie = minf(vie, vie_max)
var vigueur := 100.0
var vigueur_max := 100.0
## Mana (magie) : payé par les sorts, régénéré REGEN_MANA/s après DELAI_MANA s sans dépense ni incantation.
var mana := 100.0
var mana_max := 100.0
const REGEN_MANA := 7.0
const DELAI_MANA := 1.2
var _repos_mana := 0.0
## Lus par le HUD (agent effets) : charge 0..1 de chaque main, recharges {id_sort: s restantes}, effets actifs du
## joueur [{nom, duree, ecole}] (protection, enchantement, lenteur…). Tenus par mains.magie (MainSort).
var charge_gauche: float:
	get:
		return mains.magie.charge("gauche") if mains != null and mains.get("magie") != null else 0.0
var charge_droite: float:
	get:
		return mains.magie.charge("droite") if mains != null and mains.get("magie") != null else 0.0
var recharges: Dictionary:
	get:
		return mains.magie.recharges if mains != null and mains.get("magie") != null else {}
var statuts_actifs: Array:
	get:
		var st: Array = mains.magie.statuts_actifs() if mains != null and mains.get("magie") != null else []
		return st + potions.statuts() if not potions.actifs.is_empty() else st
## Barre de raccourcis du HUD (8 cases) : une icône par raccourci de data/magie/raccourcis.json (main gauche, sinon droite).
var raccourcis: Array:
	get:
		var r: Array = []
		var eq: Variant = mains.magie.eq if mains != null and mains.get("magie") != null else null
		if eq != null:
			for e: Dictionary in eq.raccourcis:
				var id := String(e.get("gauche", "vide"))
				if id == "vide":
					id = String(e.get("droite", ""))
				r.append("" if id == "vide" else id)
		r.resize(8)
		for i in 8:
			if r[i] == null:
				r[i] = ""
		return r
var mort := false
var en_dialogue := false  # posé par la boîte de dialogue : ni marche ni combat
var secousse := 0.0
## Tassement de la caméra (coup 3, coup lourd : mains.gd) : 1 → 0 en ~0,18 s, la vue plonge un instant puis revient.
var tassement := 0.0
var ennemi_vise: Node = null
## Dernier coup subi (pour la chute du corps à la mort) : origine de l'attaquant et dégâts.
var origine_dernier_coup := Vector3.ZERO
var degats_dernier_coup := 0.0
## Ralentissement (givre du mage, onde du troll) : durée restante (s) et facteur de vitesse (le plus fort l'emporte).
var lenteur := 0.0
var lenteur_facteur := 1.0
var competences := Competences.new()
var inventaire := Inventaire.new()
## Potions et nourriture en cours (effets progressifs, délais) : scripts/effets_potions.gd.
var potions := EffetsPotions.new()
## Poids du sac au-dessus de la capacité : marche lente, pas de course. `avis` : texte pour le HUD (branché par le monde).
signal avis(texte: String)
const LENTEUR_SURCHARGE := 0.6
var surcharge := false
var _t_avis_surcharge := 0.0

var tete: Node3D
var camera: Camera3D
var mains: Node3D
var corps: Node3D  # corps visible à la troisième personne
var camera_tp: Node3D
var troisieme := false  # V : bascule première / troisième personne
var _pas := 0.0
var _dernier_pas := 0
var _repos_vigueur := 0.0
var _recul := Vector3.ZERO
var _bruit_secousse := FastNoiseLite.new()
## Caméra « corps » (scripts/combat/camera_corps.gd) : balancement de tête, saut / atterrissage, accompagnement des
## attaques, micro-secousse des impacts, coup reçu ; ressorts critiques à pas fixe, options du menu (CameraCorps.facteurs).
var camera_corps := CameraCorps.new()
var _secousse_prec := 0.0
var _t := 0.0

func _ready() -> void:
	_actions()
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)
	tete = Node3D.new()
	tete.position.y = 1.62
	add_child(tete)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 90.0  # lot 7 : au-delà de la fin du brouillard (75 m max) rien n'est visible
	tete.add_child(camera)
	camera.current = true
	mains = Node3D.new()
	mains.set_script(MAINS)
	mains.joueur = self
	camera.add_child(mains)
	corps = Node3D.new()
	corps.set_script(CORPS)
	corps.joueur = self
	corps.mains = mains
	add_child(corps)
	camera_tp = Node3D.new()
	camera_tp.set_script(CAMERA_TP)
	camera_tp.joueur = self
	add_child(camera_tp)
	for a in OS.get_cmdline_user_args():
		if a == "--vue=3":
			basculer_vue(true)
	_bruit_secousse.frequency = 2.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## V : passe de la première à la troisième personne. La caméra de la tête reste en place
## (hors champ) : les coups d'épée et les invites partent donc toujours des yeux du joueur.
func basculer_vue(troisieme_personne: bool) -> void:
	troisieme = troisieme_personne
	mains.visible = not troisieme
	corps.definir_vue(troisieme)
	if troisieme:
		camera_tp.recaler()
		camera_tp.camera.current = true
	else:
		camera.current = true

func _actions() -> void:
	var touches := {
		"avant": [KEY_W, KEY_UP], "arriere": [KEY_S, KEY_DOWN],
		"gauche": [KEY_A, KEY_LEFT], "droite": [KEY_D, KEY_RIGHT],
		"saut": [KEY_SPACE], "course": [KEY_SHIFT],
	}
	for nom in touches:
		if InputMap.has_action(nom):
			continue
		InputMap.add_action(nom)
		for touche_clavier in touches[nom]:
			var e := InputEventKey.new()
			e.physical_keycode = touche_clavier
			InputMap.action_add_event(nom, e)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not mort and not en_dialogue:
		# screen_relative : non réduit par l'agrandissement du rendu 480x270
		var k := SENSIBILITE * Jeu.sensibilite   # options du joueur (menu Options)
		rotate_y(-e.screen_relative.x * k)
		tete.rotation.x = clampf(tete.rotation.x - e.screen_relative.y * k * (-1.0 if Jeu.inverser_y else 1.0), -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_V:
		basculer_vue(not troisieme)
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Paie `quantite` de mana si possible (sinon rien n'est retiré) ; la régénération reprend DELAI_MANA s après.
func depenser_mana(quantite: float) -> bool:
	if quantite <= 0.0:
		return true
	if mana + 0.001 < quantite:
		return false
	mana = maxf(0.0, mana - quantite)
	_repos_mana = DELAI_MANA
	return true

## Retient la régénération de mana (incantation en cours).
func retenir_mana() -> void:
	_repos_mana = maxf(_repos_mana, DELAI_MANA)

## Soin (sort de soin, drain, combo « moisson »).
func soigner(quantite: float) -> void:
	if mort or quantite <= 0.0:
		return
	vie = minf(vie_max, vie + quantite)

## Retire de la vigueur ; la récupération reprend une seconde après.
func depenser(quantite: float) -> void:
	vigueur = maxf(0.0, vigueur - quantite)
	_repos_vigueur = 1.0

## Appelé par un ennemi qui frappe. Renvoie "parade", "bloque" ou "touche".
## `options` (facultatif ; troll de givre, mage nordique) : "imparable" (part 0..1 des dégâts qui traverse la garde ; > 0 = pas de
## parade possible, le coup « se pare mal »), "recul" (m/s, 4 par défaut), "ralenti" (Vector2(durée s, facteur de vitesse)),
## "secousse" (minimum de secousse de caméra).
func recevoir_coup(degats: float, origine: Vector3, options := {}) -> String:
	if mort:
		return ""
	var vers := origine - global_position
	vers.y = 0.0
	# magie : protection (sort canalisé de face) — absorbe une part du coup contre du mana ; un coup encaissé peut couper
	# une incantation (MainSort._sur_touche, signal touche)
	if mains.get("magie") != null:
		degats = mains.magie.absorber(degats, origine, options)
		if degats <= 0.0:
			return "bloque"
	# garde (phase 3, mains.defendre / DefenseJoueur) : cône de 120° devant, réduction et coût selon l'arme tenue, parade
	# parfaite dans la fenêtre (anti-spam), garde brisée quand l'endurance ne suffit plus (une partie du coup passe).
	# Coup « imparable » (troll de givre, mage nordique) : pas de parade parfaite possible, et une part du coup traverse la garde.
	var imparable := float(options.get("imparable", 0.0))
	var g: Dictionary = mains.defendre(degats, origine, imparable > 0.0)
	if not g.is_empty():
		var parade: bool = g["issue"] == "parade"
		competences.pratiquer("parade", 0.6 + degats * 0.08 + (0.6 if parade else 0.0))
		if g["issue"] != "brisee":
			vie = maxf(minf(vie, 1.0), vie - float(g["degats"]))   # un coup bloqué ne tue pas
			if imparable > 0.0:
				# la part imparable passe la garde (elle peut tuer), recul atténué
				vie -= degats * imparable
				_recul = -vers.normalized() * float(options.get("recul", 4.0)) * 0.6
				secousse = maxf(secousse, float(options.get("secousse", 0.5)))
				touche.emit(degats * imparable)
				if vie <= 0.0:
					vie = 0.0
					mort = true
					deces.emit()
					return "touche"
			if options.has("ralenti"):
				var rl: Vector2 = options["ralenti"]
				ralentir(rl.x * 0.5, rl.y)   # ralentissement atténué par la garde
			return String(g["issue"])
		degats = float(g["degats"])
	vie -= degats
	origine_dernier_coup = origine
	degats_dernier_coup = degats
	secousse = maxf(secousse, maxf(0.7, float(options.get("secousse", 0.0))))
	_recul = -vers.normalized() * float(options.get("recul", 4.0))
	camera_corps.coup_recu(global_transform.basis.inverse() * vers, degats / 30.0)
	_secousse_prec = secousse   # pas un impact du joueur (CameraCorps.impact)
	if options.has("ralenti"):
		var rl: Vector2 = options["ralenti"]
		ralentir(rl.x, rl.y)
	touche.emit(degats)
	Sons.jouer(self, ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"], 0.0)
	if vie <= 0.0:
		vie = 0.0
		mort = true
		deces.emit()
	return "touche"

## Ralentit le joueur `duree` s (vitesse × `facteur`) ; un ralentissement plus fort ou plus long remplace le précédent.
func ralentir(duree: float, facteur: float) -> void:
	if lenteur <= 0.0 or facteur <= lenteur_facteur:
		lenteur_facteur = facteur
	lenteur = maxf(lenteur, duree)

var _point_sur := Vector3.ZERO
var _point_sur_valide := false
var _t_point_sur := 0.0

## Filet anti-chute : mémorise ~1 fois par seconde un point sûr (au sol) ; sous le seuil, retour à ce point sans pénalité.
func _filet(dt: float) -> void:
	var monde := get_parent()
	if monde == null or not monde.has_method("hauteur"):
		return
	var p := global_position
	# sous terre : drapeau du monde, ou profondeur (crypte -140, grotte -214 : toujours sous -100 ; un test peut y téléporter sans drapeau)
	var sous_terre: bool = monde.get("_sous_terre_actif") == true or p.y < -100.0
	var seuil: float = CHUTE_SOUS_TERRE if sous_terre else float(monde.hauteur(p.x, p.z)) - CHUTE_DEHORS
	if p.y < seuil:
		var cible: Vector3 = _point_sur if _point_sur_valide else Vector3(monde.get("depart_joueur"))
		if cible == Vector3.ZERO:
			return
		global_position = cible + Vector3(0, 0.2, 0)
		velocity = Vector3.ZERO
		push_warning("Filet anti-chute : joueur ramené à %s" % cible)
		return
	_t_point_sur -= dt
	if _t_point_sur <= 0.0 and is_on_floor() and not mort:
		_t_point_sur = 1.0
		_point_sur = p
		_point_sur_valide = true

func ressusciter(lieu: Vector3, lacet: float) -> void:
	position = lieu
	rotation.y = lacet
	tete.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	vie = vie_max
	vigueur = vigueur_max
	mana = mana_max
	mort = false
	potions.vider()

## Surcharge (poids du sac > capacité) : avis au passage, et un rappel si on tente de courir.
func _surcharge(dt: float) -> void:
	_t_avis_surcharge -= dt
	var lourd := inventaire.surcharge()
	if lourd != surcharge:
		surcharge = lourd
		avis.emit(("Surchargé (%.0f / %.0f) : marche lente, course impossible." % [inventaire.poids(), inventaire.capacite()]) if lourd else "Vous n'êtes plus surchargé.")
		_t_avis_surcharge = 6.0
	elif lourd and _t_avis_surcharge <= 0.0 and Input.is_action_just_pressed("course") and not mort:
		_t_avis_surcharge = 4.0
		avis.emit("Surchargé : impossible de courir (%.0f / %.0f)." % [inventaire.poids(), inventaire.capacite()])

func _physics_process(dt: float) -> void:
	_t += dt
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	elif Input.is_action_just_pressed("saut") and not mort and not en_dialogue and vigueur > 5.0:
		velocity.y = SAUT
		depenser(6.0)
	var entree := Vector2.ZERO if (mort or en_dialogue) else Input.get_vector("gauche", "droite", "avant", "arriere")
	var dir := (transform.basis * Vector3(entree.x, 0.0, entree.y)).normalized()
	potions.avancer(self, dt)
	_surcharge(dt)
	var court: bool = Input.is_action_pressed("course") and vigueur > 0.0 and entree.y < 0.0 and not mains.bloque and not surcharge
	var vitesse := COURSE if court else VITESSE
	if surcharge:
		vitesse *= LENTEUR_SURCHARGE
	if mains.bloque:
		vitesse *= 0.5
	if lenteur > 0.0:
		lenteur -= dt
		vitesse *= lenteur_facteur
		if lenteur <= 0.0:
			lenteur_facteur = 1.0
	if court and dir != Vector3.ZERO:
		vigueur = maxf(0.0, vigueur - COUT_COURSE * competences.cout_course() * dt)
		competences.pratiquer("athletisme", dt * 0.12)
		_repos_vigueur = 0.6
	var cible := dir * vitesse + _recul
	_recul = _recul.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * dt))
	var reactivite := 1.0 - exp(-(10.0 if is_on_floor() else 2.0) * dt)
	velocity.x = lerpf(velocity.x, cible.x, reactivite)
	velocity.z = lerpf(velocity.z, cible.z, reactivite)
	move_and_slide()
	position.x = clampf(position.x, -LIMITE, LIMITE)
	position.z = clampf(position.z, -LIMITE, LIMITE)
	_filet(dt)

	# récupération
	_repos_vigueur -= dt
	if _repos_vigueur <= 0.0:
		vigueur = minf(vigueur_max, vigueur + 22.0 * dt)
	if not mort:
		vie = minf(vie_max, vie + 0.8 * dt)
	_repos_mana -= dt
	if _repos_mana <= 0.0 and not mort:
		mana = minf(mana_max, mana + REGEN_MANA * dt)

	# pas dans la neige
	var vitesse_sol := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and vitesse_sol > 0.3:
		_pas += dt * vitesse_sol * 2.4
		var n := floori(_pas / PI)
		if n != _dernier_pas:
			_dernier_pas = n
			Sons.jouer(self, ["footstep_snow_000", "footstep_snow_001", "footstep_snow_002", "footstep_snow_003", "footstep_snow_004"], -12.0 if not court else -8.0, 0.1)
	# caméra « corps » (CameraCorps) : options Mouvement de tête / Secousses, « Réduire les mouvements » compris
	var f := CameraCorps.facteurs()
	camera_corps.tete = f["tete"]
	camera_corps.secousses = f["secousses"]
	secousse = maxf(0.0, secousse - dt * 1.8)
	# un coup du joueur qui porte fait monter la secousse (profils d'impact) : petit recul de la vue, amorti si puissant
	if secousse > _secousse_prec + 0.05 and mains != null and mains.get("combat") != null \
			and (mains.combat.attaque() or mains.combat.etat == EtatCombat.RECUPERATION):
		camera_corps.impact(secousse)
	_secousse_prec = secousse
	camera_corps.avancer(dt, vitesse_sol if not mort else 0.0, _pas, is_on_floor(), velocity.y, secousse, global_position.y)
	if mort:
		# on s'effondre
		tete.rotation.z = lerpf(tete.rotation.z, 1.2, 1.0 - exp(-3.0 * dt))
		camera.position = camera.position.lerp(Vector3(0, -1.2, 0), 1.0 - exp(-12.0 * dt))
	else:
		camera.position = camera_corps.position
	camera.rotation = camera_corps.rotation
	camera.h_offset = camera_corps.decalage.x
	camera.v_offset = camera_corps.decalage.y
	if tassement > 0.0:
		tassement = maxf(0.0, tassement - dt * 5.5)
		camera.v_offset -= sin(minf(tassement, 1.0) * PI) * 0.035 * float(f["secousses"])
	var cam_tp: Camera3D = camera_tp.camera
	cam_tp.h_offset = camera.h_offset
	cam_tp.v_offset = camera.v_offset
	cam_tp.rotation.z = camera.rotation.z
