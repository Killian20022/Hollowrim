class_name BeteQuat
extends EnnemiBase
## Bêtes et faune QUATERNIUS au rendu PS1 (persos/quaternius_jeu, 2026-11-04) : loup (hostile, en meute), araignée des cavernes
## (hostile, embuscade), cerf / biche / renard (faune NON hostile : broute, erre, fuit). Modèle : PersosQuat.creer (un maillage aux
## couleurs de la bible, AnimationPlayer « Animations », clips Idle / Walk / Run / Attack / Death / Hit (+ Eat, Idle_2 du pack
## « Ultimate Animated Animals ») et alias Jog_Fwd / Sword_Idle / Death01 / Hit_Chest du contrat des ennemis).
## Socle EnnemiBase : CombatEnnemi (dégâts, posture, sang), signal `mort` (sauvegarde : draugrs_morts), gel, butin.
## Différences avec les humanoïdes : pas de PiedsAuSol ni de ragdoll (squelettes d'animaux) : la mort joue le clip Death ; pas de
## finisher ni de démembrement.
##
## Création : monde.creer_ennemi(load("res://scripts/bete_quat.gd"), pos, lacet, {"espece": "loup", "ident": "...", "meute": "m1"})
## ou, dans les données des lieux, {"ia": "loup" | "araignee" | "cerf" | "biche" | "renard"} (monde.SCRIPTS_IA ; l'espèce est
## reprise du nom d'IA, voir EnnemisNordiques._fabriquer_ia).
## PRÉPARÉ pour le futur système d'apparition par biome / jour-nuit (NON codé ici) : ESPECES décrit chaque bête (hostile, meute,
## biomes, heures) ; un générateur n'aura qu'à tirer dans cette table et appeler monde.creer_ennemi.

enum { REPOS, ERRE, TRAQUE, ENCERCLE, ATTAQUE, TITUBE, FUITE }

## Fiche de chaque espèce. vitesses en m/s ; ref_* : vitesse que suppose le clip (pieds qui ne glissent pas) ; portee : morsure ;
## detection : il voit le joueur (hostile) ou s'effraie (faune) en deçà ; biomes / heures : pour le futur système d'apparition.
const ESPECES := {
	"loup": {"pq": "pq_loup2", "nom": "Loup", "vie": 48.0, "degats": 9.0, "rayon": 0.32, "haut": 0.85, "profil": "loup", "hostile": true,
		"marche": 1.25, "course": 6.4, "ref_marche": 1.15, "ref_course": 5.6, "detection": 20.0, "portee": 1.6, "impact": 0.55, "meute": true,
		"biomes": ["foret", "plaine_neige"], "heures": "nuit+", "groupe": [3, 5]},
	"araignee": {"pq": "pq_araignee", "nom": "Araignée des cavernes", "vie": 40.0, "degats": 11.0, "rayon": 0.55, "haut": 0.7, "profil": "araignee",
		"hostile": true, "marche": 1.1, "course": 4.6, "ref_marche": 1.1, "ref_course": 2.4, "detection": 10.0, "portee": 1.9, "impact": 0.5,
		"embuscade": true, "biomes": ["grotte", "crypte"], "heures": "toujours", "groupe": [1, 3]},
	"cerf": {"pq": "pq_cerf2", "nom": "Cerf", "vie": 32.0, "degats": 0.0, "rayon": 0.38, "haut": 1.6, "profil": "gibier", "hostile": false,
		"marche": 1.0, "course": 8.5, "ref_marche": 1.1, "ref_course": 7.0, "detection": 16.0, "impact": 1.1,
		"biomes": ["foret", "clairiere"], "heures": "jour+aube", "groupe": [1, 3]},
	"biche": {"pq": "pq_biche", "nom": "Biche", "vie": 26.0, "degats": 0.0, "rayon": 0.34, "haut": 1.3, "profil": "gibier", "hostile": false,
		"marche": 1.0, "course": 8.0, "ref_marche": 1.05, "ref_course": 6.6, "detection": 18.0, "impact": 0.9,
		"biomes": ["foret", "clairiere"], "heures": "jour+aube", "groupe": [1, 4]},
	"renard": {"pq": "pq_renard", "nom": "Renard", "vie": 14.0, "degats": 0.0, "rayon": 0.22, "haut": 0.45, "profil": "gibier", "hostile": false,
		"marche": 0.9, "course": 6.5, "ref_marche": 0.8, "ref_course": 5.0, "detection": 10.0, "impact": 0.3,
		"biomes": ["foret", "abords_village"], "heures": "crepuscule+nuit", "groupe": [1, 1]},
	# animaux domestiques du village (gen/animaux 2026-11-04) : paisibles, ne fuient que s'ils sont blessés, restent dans leur zone
	"cheval": {"pq": "pq_cheval", "nom": "Cheval", "vie": 60.0, "degats": 0.0, "rayon": 0.42, "haut": 1.6, "profil": "gibier", "hostile": false,
		"domestique": true, "marche": 1.2, "course": 7.5, "ref_marche": 1.3, "ref_course": 7.0, "detection": 0.0, "impact": 1.2,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 2]},
	"cheval_blanc": {"pq": "pq_cheval_blanc", "nom": "Cheval blanc", "vie": 60.0, "degats": 0.0, "rayon": 0.42, "haut": 1.6, "profil": "gibier",
		"hostile": false, "domestique": true, "marche": 1.2, "course": 7.5, "ref_marche": 1.3, "ref_course": 7.0, "detection": 0.0, "impact": 1.2,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 1]},
	"ane": {"pq": "pq_ane", "nom": "Âne", "vie": 40.0, "degats": 0.0, "rayon": 0.36, "haut": 1.3, "profil": "gibier", "hostile": false,
		"domestique": true, "marche": 1.0, "course": 5.5, "ref_marche": 1.1, "ref_course": 5.5, "detection": 0.0, "impact": 0.9,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 1]},
	"vache": {"pq": "pq_vache", "nom": "Vache", "vie": 50.0, "degats": 0.0, "rayon": 0.45, "haut": 1.4, "profil": "gibier", "hostile": false,
		"domestique": true, "marche": 0.8, "course": 5.0, "ref_marche": 1.0, "ref_course": 5.0, "detection": 0.0, "impact": 0.9,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 3]},
	"taureau": {"pq": "pq_taureau", "nom": "Taureau", "vie": 70.0, "degats": 0.0, "rayon": 0.5, "haut": 1.5, "profil": "gibier", "hostile": false,
		"domestique": true, "marche": 0.8, "course": 5.5, "ref_marche": 1.0, "ref_course": 5.5, "detection": 0.0, "impact": 1.0,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 1]},
	"husky": {"pq": "pq_husky", "nom": "Husky", "vie": 24.0, "degats": 0.0, "rayon": 0.24, "haut": 0.65, "profil": "gibier", "hostile": false,
		"domestique": true, "marche": 1.1, "course": 6.0, "ref_marche": 1.0, "ref_course": 5.5, "detection": 0.0, "impact": 0.4,
		"biomes": ["village"], "heures": "toujours", "groupe": [1, 2]},
}

var espece := ""
var meute := ""            # même valeur = même meute : une alerte réveille toute la meute
var rayon_errance := 7.0      # domestiques : posé par monde._betes (zone de l'enclos)
var etat := REPOS
var fiche: Dictionary = {}
var _cible_errance := Vector3.ZERO
var _t_choix := 0.0
var _cd_attaque := 0.0
var _coup_donne := false
var _angle_meute := 0.0
var _duree_titube := 0.4
var _repos := "Idle"
var _seuil_bond := 1.0
var attaques := 0          # morsures données (tests)

static func espece_de(nom_ia: String) -> String:
	return nom_ia if ESPECES.has(nom_ia) else "loup"

func _ready() -> void:
	if espece == "" or not ESPECES.has(espece):
		espece = espece_de(ident.get_slice("_", 0))
	fiche = ESPECES[espece]
	nom_affiche = String(fiche["nom"])
	vie_max = float(fiche["vie"])
	degats = float(fiche["degats"])
	taille = float(fiche["haut"]) / 1.8
	var mod := EnnemisNordiques.modele_ia(espece, ident)
	if mod == null:
		mod = PersosQuat.creer(String(fiche["pq"]))
	_equiper(mod, ProfilCible.pour(String(fiche["profil"])), float(fiche["rayon"]), float(fiche["haut"]), false)
	add_to_group("bete_quat")
	if not bool(fiche["hostile"]):
		add_to_group("faune")
	_angle_meute = randf() * TAU
	_cible_errance = origine
	_t_choix = randf_range(2.0, 8.0)
	_jouer("Idle", 0.0)
	anim.seek(randf() * 2.0, true)

# ------------------------------------------------------------------ contrat

func en_combat() -> bool:
	return bool(fiche.get("hostile", false)) and etat in [TRAQUE, ENCERCLE, ATTAQUE, TITUBE]

func alerter() -> void:
	degeler()
	if etat in [REPOS, ERRE]:
		_changer(TRAQUE if bool(fiche["hostile"]) else FUITE)

func point_impact() -> Vector3:
	return global_position + Vector3(0, float(fiche.get("impact", 0.6)), 0)

func finisher_possible(_j: Node3D) -> String:
	return ""      # aucune animation d'exécution pour les quadrupèdes

func _changer(e: int) -> void:
	etat = e
	_t = 0.0

func _contenu_butin() -> Dictionary:
	return {"pieces": randi_range(0, 3)} if bool(fiche["hostile"]) else {}

func _etat_coup() -> Dictionary:
	return {"peut_bloquer": false, "en_attaque": etat == ATTAQUE, "coup_donne": _coup_donne}

func _apres_degats(_r: Dictionary) -> void:
	if bool(fiche["hostile"]):
		_alerter_meute()
		if etat in [REPOS, ERRE]:
			_changer(TRAQUE)
	else:
		_changer(FUITE)

func _reagir(r: Dictionary, vers: Vector3) -> void:
	if not bool(fiche["hostile"]):
		return
	var reaction := String(r["reaction"])
	if reaction in ["lourd", "recul", "chute", "etourdi", "moyen"]:
		_recul = -vers.normalized() * (3.0 if reaction != "moyen" else 1.6) / maxf(combat.profil.poids, 0.3)
		_duree_titube = 0.55 if reaction != "moyen" else 0.35
		_changer(TITUBE)
		_jouer("Hit" if anim.has_animation("Hit") else "Idle", 0.05, true)

func _alerter_meute() -> void:
	if meute == "":
		return
	for b in get_tree().get_nodes_in_group("bete_quat"):
		if b != self and b.get("meute") == meute and b.vivant():
			b.alerter()

# ------------------------------------------------------------------ IA

func _ia(dt: float) -> void:
	if get_parent() != null and get_parent().get("pret") == false:      # monde en chargement : la bête attend au repos
		_bouger(dt, Vector3.ZERO, 0.0, "", Vector3.ZERO, 0.0, _repos)
		return
	_cd_attaque -= dt
	_t_choix -= dt
	var vj := _vers_joueur()
	var dist: float = vj["dist"]
	var dir: Vector3 = vj["dir"]
	var mort_j: bool = joueur.get("mort") == true
	var hostile := bool(fiche["hostile"])
	var det := float(fiche["detection"])
	var mv := Vector3.ZERO
	var vitesse := 0.0
	var loco := ""
	var face := Vector3.ZERO
	match etat:
		REPOS, ERRE:
			if hostile and not mort_j and dist < det * (0.6 if fiche.get("embuscade", false) else 1.0) and _voit(dt):
				_changer(TRAQUE)
				_alerter_meute()
				if espece == "loup":
					Sons.jouer_a(self, ["ambiance_loup"], global_position + Vector3.UP, -6.0, 0.15)
			elif not hostile and dist < det and (dist < det * 0.5 or _voit(dt)):
				_changer(FUITE)
			elif etat == REPOS:
				if _t_choix <= 0.0:
					_choisir_repos()
			else:
				var v := _cible_errance - global_position
				v.y = 0.0
				if v.length() < 0.6 or _t > 14.0:
					_changer(REPOS)
					_choisir_repos()
				else:
					mv = v.normalized()
					vitesse = float(fiche["marche"])
					loco = "Walk"
		TRAQUE:
			if mort_j or dist > det * 2.2:
				_retour()
			else:
				mv = dir
				face = dir
				vitesse = float(fiche["course"])
				loco = "Jog_Fwd" if anim.has_animation("Jog_Fwd") else "Walk"
				if fiche.get("meute", false) and _nb_meute() > 1 and dist < 5.0 and _cd_attaque > 0.0:
					_changer(ENCERCLE)
					_seuil_bond = randf_range(0.6, 1.8)
				elif dist < float(fiche["portee"]) + 0.3 and _cd_attaque <= 0.0:
					_attaquer()
		ENCERCLE:
			# meute : chacun tient un angle autour du joueur (≈ 3,2 m), puis bondit quand sa recharge est finie
			face = dir
			if mort_j or dist > det * 2.2:
				_retour()
			elif _cd_attaque <= 0.0 and _t > _seuil_bond:
				_changer(TRAQUE)
				_cd_attaque = 0.0
				if dist < float(fiche["portee"]) + 0.3:
					_attaquer()
			else:
				_angle_meute += dt * 0.45
				var autour := joueur.global_position + Vector3(sin(_angle_meute), 0, cos(_angle_meute)) * 3.2
				var v := autour - global_position
				v.y = 0.0
				if v.length() > 0.4:
					mv = v.normalized()
					vitesse = clampf(v.length() * 1.5, 0.8, 3.5)
					loco = "Walk" if vitesse < 2.2 else ("Jog_Fwd" if anim.has_animation("Jog_Fwd") else "Walk")
		ATTAQUE:
			face = dir
			var duree := _duree("Attack")
			if not _coup_donne and _t > duree * 0.42:
				_coup_donne = true
				var avant := global_transform.basis.z
				if dist < float(fiche["portee"]) + 0.5 and avant.dot(dir) > 0.4 and not mort_j:
					attaques += 1
					joueur.recevoir_coup(degats, global_position, {"recul": 3.0, "secousse": 0.35, "type": "physique"})
			if _t > duree:
				_cd_attaque = randf_range(1.2, 2.2) * (1.0 + 0.35 * (_nb_meute() - 1))   # meute : chacun son tour
				if fiche.get("meute", false) and _nb_meute() > 1:
					_changer(ENCERCLE)
					_seuil_bond = randf_range(0.6, 1.8)
				else:
					_changer(TRAQUE)
		TITUBE:
			if _t > _duree_titube:
				_changer(TRAQUE)
		FUITE:
			var loin := global_position - joueur.global_position
			loin.y = 0.0
			mv = loin.normalized() if loin.length() > 0.1 else -global_transform.basis.z
			vitesse = float(fiche["course"])
			loco = "Jog_Fwd" if anim.has_animation("Jog_Fwd") else "Walk"
			if dist > float(fiche["detection"]) * 2.5 and _t > 4.0:
				if not bool(fiche.get("domestique", false)):
					origine = global_position      # il se calme là où il s'est enfui (un domestique rentre chez lui)
				else:
					_cible_errance = origine
				_changer(REPOS)
				_choisir_repos()
	_bouger(dt, mv, vitesse, loco, face, 6.0 if hostile else 4.0, _repos)
	_vitesse_clip(loco)

## Vitesse des clips selon l'espèce (EnnemiBase règle Walk / Jog_Fwd sur les références humaines).
func _vitesse_clip(loco: String) -> void:
	if loco == "" or _vit < 0.05:
		return
	var ref := float(fiche["ref_course"]) if loco == "Jog_Fwd" or (loco == "Walk" and _vit > 2.0) else float(fiche["ref_marche"])
	anim.speed_scale = clampf(_vit / ref, 0.5, 2.0) * Statuts.facteur_vitesse(self)

func _retour() -> void:
	_cible_errance = origine
	_changer(ERRE)

func _attaquer() -> void:
	_changer(ATTAQUE)
	_coup_donne = false
	_vit = 0.0
	_jouer("Attack", 0.1, true)

func _nb_meute() -> int:
	if meute == "":
		return 1
	var n := 0
	for b in get_tree().get_nodes_in_group("bete_quat"):
		if b.get("meute") == meute and b.vivant():
			n += 1
	return n

## Au repos : regarde, broute (Eat) ou se gratte (Idle_2) ; de temps en temps il erre dans son rayon.
func _choisir_repos() -> void:
	_t_choix = randf_range(4.0, 11.0)
	var r := randf()
	if r < 0.35:
		var a := randf() * TAU
		_cible_errance = origine + Vector3(sin(a), 0, cos(a)) * randf_range(1.5, rayon_errance)
		_changer(ERRE)
		return
	if r < 0.65 and anim.has_animation("Eat") and not bool(fiche["hostile"]):
		_repos = "Eat"
	elif r < 0.8 and anim.has_animation("Idle_2"):
		_repos = "Idle_2"
	else:
		_repos = "Idle"
	_jouer(_repos, 0.4)

# ------------------------------------------------------------------ mort (sans ragdoll : clip Death)

func _mourir(origine_coup := Vector3.ZERO, _quantite := 20.0, _puissant := false, r: Dictionary = {}, sorte := "") -> void:
	if est_mort:
		return
	degeler()
	est_mort = true
	_t_mort = 0.0
	_sur_mort()
	mort.emit(ident)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	var dir := global_position - origine_coup
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	_jouer("Death" if anim.has_animation("Death") else "Death01", 0.1, true)
	anim.speed_scale = 1.0
	var point := point_impact()
	combat.effets_mort(r if not r.is_empty() else {"info": {"point": point, "direction": dir, "normale": -dir}}, sorte if sorte != "" else "legere", joueur)
	if bool(fiche["hostile"]) or not _contenu_butin().is_empty():
		_laisser_butin()
