extends CharacterBody3D
## Villageois : habitant du hameau (modèles KayKit animés, comme les draugrs).
## Il reste à son poste avec une petite activité, se promène de temps en temps,
## interpelle le joueur qui passe et lui parle quand on le regarde (touche E).
## Propriétés à poser AVANT add_child : donnees, joueur, dialogue, points.

## RENTRE / DORT (lot vie_pnj) : RENTRE = il rejoint un but donné par `Vie` (maison, abri, feu du soir, poste du matin) ; DORT = il est
## entré dans un bâtiment (caché, sans collision, process coupé) jusqu'à ce que `Vie` le réveille.
enum { POSTE, ALLER, PAUSE, RETOUR, RENTRE, DORT }

const GRAVITE := 13.0
const MARCHE := 1.1
const DIST_REGARD := 4.0
const DIST_INTERPELLE := 5.0
const DIST_PARLER := 2.6
const DOT_PARLER := 0.85
## Vitesse du corps que suppose l'animation Walk de la bibliothèque (mesurée avec
## outils/mesure_pas.gd : pied d'appui, 1,03 m/s en médiane). anim.speed_scale = vitesse réelle / REF_MARCHE
## évite que les pieds glissent.
const REF_MARCHE := 1.03
const COURSE := 3.6  # m/s, fuite devant un danger (RENTRE « vite »)
const REF_COURSE := 3.2  # vitesse que suppose le clip Jog_Fwd à speed_scale 1 (estimation : pas de mesure dédiée)
const ACCEL := 3.0  # m/s², départ et arrêt progressifs
const ROT_MAX := 3.5  # rad/s, vitesse de rotation maximale du corps
const ECART_DEPART := 0.5  # il ne part que presque aligné (rad) ; il continue jusqu'à ECART_MAX
const ECART_MAX := 1.0
const DIST_TETE := 5.0  # la tête suit le joueur en deçà
const LACET_TETE := deg_to_rad(60.0)
const TANGAGE_TETE := deg_to_rad(25.0)
## Activité au poste selon le lieu (une animation en boucle ; "PickUp" = ponctuelle).
const ACTIVITES := {
	"forge": "Fixing_Kneeling",
	"puits": "Idle",
	"place": "Spell_Simple_Idle",
	"enclos": "PickUp_Table",
	"longue_maison": "Idle",
	"porte": "Idle",
}

## Modificateur de squelette : oriente cou et tête vers un point du monde, avec lissage et
## limites (±60° de lacet, ±25° de tangage). S'applique après l'animation.
class SuiviTete extends SkeletonModifier3D:
	var cible := Vector3.ZERO  # point à regarder (repère du monde)
	var voulu := false
	var lacet := 0.0
	var tangage := 0.0
	var _cou := -1
	var _tete := -1

	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq == null:
			return
		if _tete < 0:
			_tete = sq.find_bone("Head")
			_cou = sq.find_bone("neck_01")
			if _tete < 0:
				return
		var dt := get_process_delta_time()
		var but_l := 0.0
		var but_t := 0.0
		if voulu:
			var d := sq.global_transform.affine_inverse() * cible - sq.get_bone_global_pose(_tete).origin
			var plan := Vector2(d.x, d.z).length()
			if plan > 0.3:
				but_l = clampf(atan2(d.x, d.z), -LACET_TETE, LACET_TETE)
				but_t = clampf(atan2(d.y, plan), -TANGAGE_TETE, TANGAGE_TETE)
		var k := 1.0 - exp(-5.0 * dt)
		lacet = lerp_angle(lacet, but_l, k)
		tangage = lerpf(tangage, but_t, k)
		if absf(lacet) < 0.002 and absf(tangage) < 0.002:
			return
		# 40 % sur le cou, 60 % sur la tête
		_tourner(sq, _cou, 0.4)
		_tourner(sq, _tete, 0.6)

	func _tourner(sq: Skeleton3D, os: int, part: float) -> void:
		if os < 0:
			return
		var rot := Basis(Vector3.UP, lacet * part) * Basis(Vector3.RIGHT, -tangage * part)
		var parent := sq.get_bone_parent(os)
		var pb := sq.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		var voulue := rot * sq.get_bone_global_pose(os).basis
		sq.set_bone_pose_rotation(os, (pb.inverse() * voulue).orthonormalized().get_rotation_quaternion())

var donnees: Dictionary = {}
var joueur: CharacterBody3D
var dialogue: Control
var points: Array = []  # de Vector3
var deja_parle := false
var quetes: Node = null  # posé par le monde
var vie: Node = null     # Vie (posé par Vie.peupler) : répliques contextuelles, horloge du village

var etat := POSTE
var modele: Node3D
var anim: AnimationPlayer
var _anim := ""
var _t := 0.0
var _prochaine_promenade := 20.0
var _delai_interpelle := 0.0
var _delai_activite := 0.0
var _en_conversation := false
var _debut_conversation := 0.0
var _bloque := 0.0
var _prog_t := 0.0               # RENTRE : temps depuis la dernière mesure d'approche
var _prog_d := INF               # RENTRE : distance au point visé à cette mesure
var _invite := false
var _var := 1.0  # variation personnelle de rythme (animations de repos)
var _marche := MARCHE  # vitesse de marche personnelle
var _vit := 0.0  # vitesse de marche actuelle
var _avance := false
var _tete: SuiviTete
var _delai_variete := 12.0
var _variete_fin := 0.0  # durée restante d'une petite animation de repos
var _autour := 0.0  # durée restante d'un regard circulaire
var _autour_lacet := 0.0
var _autour_duree := 4.0
var _parle := false  # conversation : Idle_Talking (vrai) ou Idle
var _delai_parole := 0.0
var lod := 0                     # 0 complet ; 1 allégé (ni IK des pieds, ni suivi de tête, ni ombre) ; 2 endormi (caché, gelé) — réglé par Vie
var _forme: CollisionShape3D
var _route: Array = []           # RENTRE : points à suivre (le dernier est le but)
var _entre := false              # RENTRE : à l'arrivée, il entre dans le bâtiment (DORT)
var _vite := false               # RENTRE : il court
var _poste_vie: Variant = null   # Vector3 : poste du moment fixé par Vie (feu du soir), null = son poste de jour
var _act_vie := ""               # activité du poste du moment (soirée)
var _cap_arrivee := NAN
var remplace: Node = null  # PnjCombat (crime.gd) qui a pris son corps : il dort tant que celui-ci se bat, fuit ou se calme
var _pieds: PiedsAuSol  # pieds posés sur le terrain (coupé à genoux, assis ou allongé)
## Animations où le corps est près du sol ou assis : l'IK des jambes les déformerait.
const SANS_PIEDS := ["Fixing_Kneeling"]

## Lit res://data/villageois.json et renvoie la liste des villageois (vide si absent ou invalide).
static func charger() -> Array:
	var chemin := "res://data/villageois.json"
	if not FileAccess.file_exists(chemin):
		push_warning("Villageois : fichier introuvable : " + chemin)
		return []
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		push_warning("Villageois : lecture impossible : " + chemin)
		return []
	var json: Variant = JSON.parse_string(f.get_as_text())
	if not (json is Dictionary) or not (json as Dictionary).get("villageois") is Array:
		push_warning("Villageois : JSON invalide : " + chemin)
		return []
	var liste: Array = (json as Dictionary)["villageois"]
	liste.append_array(habitants())
	liste.append_array(habitants_essai())
	return liste

## Habitants anonymes du village (persos/quaternius_jeu, 2026-11-04) : paysans, fermières, chasseurs ; dérivés des archétypes validés
## (PnjNordique.HABITANTS, clé « pnj »), mêmes routines, dialogues et sauvegarde (par id) que les villageois nommés. res://data/habitants.json ;
## `--sans-habitants` : aucun ; `--persos-anciens` : mêmes habitants aux mêmes postes, corps Humain.creer (« ancien »).
static func habitants() -> Array:
	var chemin := "res://data/habitants.json"
	if OS.get_cmdline_user_args().has("--sans-habitants") or not FileAccess.file_exists(chemin):
		return []
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if not (json is Dictionary) or not (json as Dictionary).get("habitants") is Array:
		push_warning("Villageois : JSON invalide : " + chemin)
		return []
	var communs: Dictionary = (json as Dictionary).get("roles", {})
	var out: Array = []
	for h: Dictionary in (json as Dictionary)["habitants"]:
		var d := h.duplicate(true)
		var r: Dictionary = communs.get(String(d.get("type", "")), {})
		for cle in ["role", "interpellations", "lignes", "apres", "nom"]:
			if not d.has(cle) and r.has(cle):
				d[cle] = r[cle]
		var anc: Dictionary = d.get("ancien", {})      # JSON -> types de Humain.creer (couleurs)
		if anc.get("teinte_cheveux") is Array:
			var tc: Array = anc["teinte_cheveux"]
			anc["teinte_cheveux"] = Color(float(tc[0]), float(tc[1]), float(tc[2]))
		if anc.get("tenue") is Dictionary:
			for k in anc["tenue"]:
				anc["tenue"][k] = Color.WHITE
		out.append(d)
	return out

## Habitants SUPPLÉMENTAIRES de data/habitants_tripo.json (lancier, garde, archer Tripo en plus des gardes : films v2), seulement avec
## l'argument `--gardes-tripo-en-plus`. En jeu normal les gardes Tripo REMPLACENT trois gardes (gardes_village.gd) et le jarl Tripo le chef
## (_ready), voir ModelesTripo. Mêmes champs que data/habitants.json (textes compris : pas de « roles » communs).
static func habitants_essai() -> Array:
	var chemin := "res://data/habitants_tripo.json"
	var args := OS.get_cmdline_user_args()
	if not args.has("--gardes-tripo-en-plus") or not ModelesTripo.actif("gardes") or not FileAccess.file_exists(chemin):
		return []
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if json is Dictionary and (json as Dictionary).get("habitants") is Array:
		var out: Array = []
		for h: Variant in (json as Dictionary)["habitants"]:
			if String((h as Dictionary).get("pnj", "")) == "jarl_tripo":
				continue      # le jarl Tripo n'est plus un habitant de plus : il remplace le chef (villageois._ready)
			out.append(h)      # lancier, garde, archer en habitants supplémentaires (films v2)
		return out
	push_warning("Villageois : JSON invalide : " + chemin)
	return []

func _ready() -> void:
	add_to_group("villageois")
	add_to_group("cibles_combat")    # la lame et les sorts du joueur le touchent (Crime : avertissement, puis agression)
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)
	_forme = forme

	var id: String = donnees.get("id", "")
	# corps Humain (Quaternius) par défaut ; --persos-kit : personnage de base unifié (PersoDefs)
	if id == "chef" and ModelesTripo.actif("jarl") and not ModelesTripo.ancien_impose(donnees):      # jarl Tripo Gunnar (scripts/jarl_tripo.gd) par défaut : même id (dialogue, quêtes, factions, sommeil), autre corps ; ancien : --modeles-anciens=jarl
		modele = JarlTripo.creer()
	elif donnees.has("pnj"):       # habitant anonyme (data/habitants.json) : dérivé d'un archétype nordique validé, ou l'ancien corps Humain pour l'avant/après
		modele = Humain.creer(donnees.get("ancien", APPARENCES["chef"])) if PersosQuat.anciens() else PnjNordique.creer(String(donnees["pnj"]))
	elif Personnage.kit_actif():
		modele = Personnage.creer(PersoDefs.villageois(id))
	elif not PnjNordique.ancien() and id in PnjNordique.IDS:
		modele = PnjNordique.creer(id)
	else:
		modele = Humain.creer(APPARENCES.get(id, APPARENCES["chef"]))
	add_child(modele)
	anim = modele.get_node("Animations")
	if points.is_empty():
		points.append(global_position)
	rotation.y = deg_to_rad(float(donnees["cap"])) if donnees.has("cap") else randf() * TAU     # "cap" (degrés, 0 = vers +Z) : le forgeron fait face à son enclume
	_prochaine_promenade = randf_range(8.0, 40.0)
	_delai_interpelle = randf_range(0.0, 15.0)
	_var = randf_range(0.93, 1.07)
	_marche = MARCHE * randf_range(0.92, 1.08)
	_delai_variete = randf_range(8.0, 20.0)
	var squelette: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	if squelette != null:
		_tete = SuiviTete.new()
		squelette.add_child(_tete)
		_pieds = PiedsAuSol.equiper(modele, self) as PiedsAuSol
	_activite(true)
	if anim != null:
		anim.seek(randf() * 2.0)

## Allure de chaque habitant (corps Humain : couleurs de la tenue, étoffes, cheveux) ; aussi la galerie du monde (monde.gd, scénario « galerie »).
## Avec --persos-kit, les villageois utilisent PersoDefs.villageois() à la place.
const C := Color.WHITE
const APPARENCES := {
	# Gunnar, le chef : longue robe bleue brodée sur tunique de lin, manteau de fourrure blanche, bijoux de cuir clair
	"chef": {"corps": "femme", "tenue": {"tunique": C, "robe": C, "mante": C, "brassards": C, "pantalon": C, "bottes": C, "ceinture": C},
		"etoffes": {"tunique": "lin", "robe": "bleu", "mante": "blanc", "pantalon": "bleu", "bottes": "cuir_c", "ceinture": "cuir_c", "brassards": "cuir_c"},
		"cheveux": "Hair_Long", "teinte_cheveux": Color(1.0, 0.82, 0.55)},
	# Brodd, le forgeron : épaules nues sous un tablier de cuir, avant-bras gantés, bourse
	"forgeron": {"corps": "homme", "tenue": {"tunique": C, "tablier": C, "brassards": C, "gants": C, "pantalon": C, "bottes": C, "ceinture": C, "sacoche": C},
		"etoffes": {"tunique": "brun", "tablier": "cuir_b", "pantalon": "noir", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "cuir_b", "gants": "cuir_b", "sacoche": "cuir_b"},
		"cheveux": "Hair_Buzzed", "barbe": true, "teinte_cheveux": Color(0.35, 0.22, 0.12), "peau": Color(0.95, 0.8, 0.72)},
	# la chasseuse : capuche verte, fourrure brune, carquois et bourse
	"chasseuse": {"corps": "femme", "tenue": {"tunique": C, "capuche": C, "mante": C, "brassards": C, "gants": C, "pantalon": C, "bottes": C, "ceinture": C, "carquois": C, "sacoche": C},
		"etoffes": {"tunique": "vert", "capuche": "vert", "mante": "brun", "pantalon": "brun", "bottes": "cuir_a", "ceinture": "cuir_a", "brassards": "cuir_a", "gants": "cuir_a", "carquois": "cuir_a", "sacoche": "cuir_a"},
		"cheveux": "Hair_Buns", "teinte_cheveux": Color(0.85, 0.38, 0.2)},
	# Sigrún, la völva : longue robe, cape à capuche violette, pas d'armure
	"volva": {"corps": "femme", "tenue": {"tunique": C, "robe": C, "capuche": C, "cape": C, "bottes": C, "ceinture": C, "pantalon": C, "sacoche": C},
		"etoffes": {"tunique": "violet", "robe": "gris", "capuche": "violet", "cape": "gris", "pantalon": "gris", "bottes": "cuir_b", "ceinture": "cuir_c", "sacoche": "cuir_c"},
		"cheveux": "Hair_Long", "teinte_cheveux": Color(1.15, 1.15, 1.2), "peau": Color(0.9, 0.85, 0.85)},
	# garde : tunique rouge, épaulières et jupe de lanières, cape courte, gantelets de fer
	"garde": {"corps": "homme", "tenue": {"tunique": C, "cape_courte": C, "epaulieres": C, "pteruges": C, "brassards": C, "gants": C, "pantalon": C, "bottes": C, "ceinture": C},
		"etoffes": {"tunique": "rouge", "cape_courte": "gris", "epaulieres": "fer", "pteruges": "cuir_b", "pantalon": "gris", "bottes": "cuir_b", "ceinture": "cuir_b", "brassards": "fer", "gants": "cuir_b"},
		"cheveux": "Hair_SimpleParted", "barbe": true, "teinte_cheveux": Color(0.55, 0.38, 0.22), "casque": "casque_nasal", "bouclier": true},
	# Grima, l'ancienne : robe de lin, châle de laine et foulard
	"ancienne": {"corps": "femme", "tenue": {"tunique": C, "robe": C, "capuche": C, "mante": C, "bottes": C, "ceinture": C, "pantalon": C},
		"etoffes": {"tunique": "lin", "robe": "gris", "capuche": "lin", "mante": "gris", "pantalon": "lin", "bottes": "cuir_c", "ceinture": "cuir_c"},
		"cheveux": "Hair_Buns", "teinte_cheveux": Color(1.1, 1.1, 1.1), "peau": Color(0.92, 0.84, 0.8)},
}

func nom_affiche() -> String:
	return donnees.get("nom", "Villageois")

## Appelé par le dialogue : renvoie les répliques (1re fois puis « apres »).
func parler() -> Array:
	if seq != "":
		return _parler_reveille()
	# la première fois il se présente ; ses répliques de quête viennent ensuite
	var lignes: Array = [] if deja_parle else donnees.get("lignes", []).duplicate()
	var de_quete: Array = quetes.repliques(donnees.get("id", ""), self) if quetes != null else []
	if not de_quete.is_empty():
		lignes += de_quete
	elif deja_parle:
		# « après » selon l'état du monde (data/dialogue/repliques.json, sujet « apres » : anneau rendu, Hrafn mort, choix moral, maison…), sinon les fixes
		var selon_etat: Array = quetes.apres(donnees.get("id", ""), self) if quetes != null else []
		lignes = selon_etat if not selon_etat.is_empty() else donnees.get("apres", [])
	if lignes.is_empty():
		lignes = donnees.get("lignes", ["…"])
	# le rang du joueur dans une faction se sent : une réplique de rang (data/dialogue/repliques.json, sujet « rang ») ouvre la conversation
	var du_rang: Array = quetes.rang(donnees.get("id", ""), self) if quetes != null else []
	if not du_rang.is_empty():
		lignes = (du_rang + lignes) if deja_parle else (lignes + du_rang)
	# lot vie_pnj P3 : une réplique selon le contexte (danger récent, soirée, retour d'un abri) en tête de la conversation
	var ctx: String = vie.replique_contextuelle(self) if vie != null and vie.has_method("replique_contextuelle") else ""
	if ctx != "":
		lignes = [ctx] + lignes
	deja_parle = true
	_en_conversation = true
	_debut_conversation = 0.0
	etat = POSTE
	_t = 0.0
	_variete_fin = 0.0
	_autour = 0.0
	_parle = false
	_delai_parole = 1.2  # il fait d'abord un geste d'accueil (Interact), puis il parle
	_jouer("Interact", 0.25)
	return lignes

## Facultatif : le dialogue peut prévenir de la fin (sinon détecté via joueur.en_dialogue).
func fin_conversation() -> void:
	_en_conversation = false
	_activite()

func _jouer(nom: String, fondu := 0.2) -> void:
	if anim == null or _anim == nom or not anim.has_animation(nom):
		return
	_anim = nom
	anim.play(nom, fondu)
	if _pieds != null:
		_pieds.actif = not (nom in SANS_PIEDS or nom.begins_with("Sit") or nom.begins_with("Lie") or nom.begins_with("Couche") or nom.begins_with("Death"))
	if nom != "Walk":  # Walk est réglé à chaque image sur la vitesse réelle
		anim.speed_scale = _var

## Activité du poste : « activite » des données (habitants) sinon celle du lieu.
func _act() -> String:
	if _act_vie != "":
		return _act_vie
	return String(donnees.get("activite", ACTIVITES.get(donnees.get("lieu", ""), "Idle")))

## Animation d'activité du poste (PickUp : ponctuelle, entre deux Idle).
func _activite(immediat := false) -> void:
	var nom := _act()
	if nom == "PickUp_Table":
		nom = "Idle"
		_delai_activite = randf_range(4.0, 9.0)
	_jouer(nom, 0.0 if immediat else 0.3)

func _physics_process(dt: float) -> void:
	if etat == DORT:
		if seq != "":
			_au_lit(dt)      # lot sommeil : s'asseoir, s'allonger, dormir, se lever (le corps ne bouge plus : pas de move_and_slide)
		return
	_t += dt
	_images_physique += 1
	if not _points_filtres and _images_physique >= 3:
		_filtrer_points()   # la physique du village est en place
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	if joueur == null or not is_instance_valid(joueur):
		move_and_slide()
		return
	var vers := joueur.global_position - global_position
	vers.y = 0.0
	var dist := vers.length()
	var dir := vers / dist if dist > 0.01 else Vector3.ZERO

	# la conversation se termine d'elle-même quand le dialogue rend la main au joueur
	if _en_conversation:
		_debut_conversation += dt
		if not joueur.en_dialogue and _debut_conversation > 0.3:
			fin_conversation()

	var cap := Vector3.ZERO  # direction de marche
	if _en_conversation:
		_t = 0.0
		_variete_fin = 0.0
		_autour = 0.0
		_parole(dt)
	else:
		match etat:
			POSTE:
				_t_poste(dt)
				_variete(dt)
				_eveille(dt)
			ALLER:
				cap = _vers_point(points[_cible_index()], dt)
			PAUSE:
				if _t > _duree_pause:
					etat = RETOUR
					_t = 0.0
			RETOUR:
				cap = _vers_point(poste(), dt)
			RENTRE:
				cap = _vers_but(dt)
				_portes_en_route()
		if cap == Vector3.ZERO and etat == POSTE and anim != null and _anim == "Idle" \
				and _act() == "PickUp_Table":
			_delai_activite -= dt
			if _delai_activite <= 0.0:
				_jouer("PickUp_Table", 0.2)
				_delai_activite = randf_range(6.0, 14.0)
				get_tree().create_timer(anim.get_animation("PickUp_Table").length).timeout.connect(_activite)

	# orientation : face au joueur à l'arrêt (conversation ou proche), sinon dans le sens de la marche.
	# Jamais face au joueur en marchant : le corps regarde où il va (la tête suit le joueur).
	var vise := Vector3.ZERO
	if _en_conversation or (cap == Vector3.ZERO and dist < DIST_REGARD):
		vise = dir
	elif cap != Vector3.ZERO:
		vise = cap
	var ecart_cap := 0.0
	if cap != Vector3.ZERO:
		ecart_cap = absf(angle_difference(rotation.y, atan2(cap.x, cap.z)))
	if vise != Vector3.ZERO:
		var ecart := angle_difference(rotation.y, atan2(vise.x, vise.z))
		var pas := ecart * (1.0 - exp(-6.0 * dt))
		rotation.y += clampf(pas, -ROT_MAX * dt, ROT_MAX * dt)

	# il ne part que lorsqu'il est à peu près tourné vers sa destination (demi-tour sur place)
	_avance = cap != Vector3.ZERO and ecart_cap < (ECART_MAX if _vit > 0.05 else ECART_DEPART)
	var v_max := (COURSE if _vite else _marche) if etat == RENTRE else _marche
	_vit = move_toward(_vit, v_max if _avance else 0.0, (ACCEL * 2.0 if _vite else ACCEL) * dt) if cap != Vector3.ZERO else 0.0
	velocity.x = cap.x * _vit
	velocity.z = cap.z * _vit
	if etat == DORT:
		return      # il vient d'entrer (coucher() coupe le process, donc retire le corps de l'espace) : plus de move_and_slide dans cette image
	move_and_slide()

	if cap != Vector3.ZERO:  # en déplacement : Walk si ça avance, Idle si demi-tour
		if etat in [ALLER, RETOUR, RENTRE]:
			if _vit > 0.1:
				if _vite and anim.has_animation("Jog_Fwd"):
					_jouer("Jog_Fwd", 0.2)
					anim.speed_scale = clampf(_vit / REF_COURSE, 0.6, 1.5)
				else:
					_jouer("Walk", 0.3)
					anim.speed_scale = clampf(_vit / REF_MARCHE, 0.5, 1.6)
			elif not _avance:
				_jouer("Idle", 0.3)
	_regard_tete(dist)
	_interactions(dist, dt)

## Conversation : alterne Idle_Talking (2,5 à 5 s) et Idle (1 à 2,5 s).
func _parole(dt: float) -> void:
	_delai_parole -= dt
	if _delai_parole > 0.0:
		return
	_parle = not _parle
	_delai_parole = randf_range(2.5, 5.0) if _parle else randf_range(1.0, 2.5)
	_jouer("Idle_Talking" if _parle else "Idle", 0.3)

## Repos : toutes les 8 à 20 s, un petit geste (Interact, Idle_Talking court) ou un regard autour,
## puis retour à l'activité du poste.
func _variete(dt: float) -> void:
	if _variete_fin > 0.0:
		_variete_fin -= dt
		if _variete_fin <= 0.0:
			_activite()
	if _autour > 0.0:
		_autour -= dt
	_delai_variete -= dt
	if _delai_variete > 0.0 or _variete_fin > 0.0 or _autour > 0.0 or anim == null:
		return
	_delai_variete = randf_range(8.0, 20.0)
	var base_repos: bool = _act() in ["Idle", "PickUp_Table"] and _anim == "Idle"
	var choix: Array = ["autour", "autour"]
	if base_repos:
		choix += ["Interact", "Idle_Talking"]
	var c: String = choix.pick_random()
	if c == "autour":
		_autour_duree = randf_range(3.0, 5.0)
		_autour = _autour_duree
		_autour_lacet = deg_to_rad(randf_range(35.0, 60.0)) * (1.0 if randf() < 0.5 else -1.0)
	elif anim.has_animation(c):
		_variete_fin = anim.get_animation(c).length if c == "Interact" else randf_range(2.5, 3.5)
		_jouer(c, 0.25)

var _points_filtres := false
var _images_physique := 0
var _capsule_promenade: CapsuleShape3D

## Un point est libre si une capsule de 0,35 x 1,8 m y tient (hors autres corps vivants).
func _libre(p: Vector3) -> bool:
	if _capsule_promenade == null:
		_capsule_promenade = CapsuleShape3D.new()
		_capsule_promenade.radius = 0.35
		_capsule_promenade.height = 1.8
	var monde := get_parent()
	var y: float = float(monde.hauteur(p.x, p.z)) if monde != null and monde.has_method("hauteur") else p.y
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = _capsule_promenade
	qs.transform = Transform3D(Basis(), Vector3(p.x, y + 1.05, p.z))
	for h in get_world_3d().direct_space_state.intersect_shape(qs, 8):
		var c: Node = h["collider"]
		if c is CharacterBody3D or (c.get_parent() == monde and c.get_child_count() > 8):
			continue   # autres corps vivants et terrain (enfant direct du monde) : pas des obstacles
		return false
	return true

func _segment_libre(a: Vector3, b: Vector3) -> bool:
	var pas := maxi(int(Vector2(a.x - b.x, a.z - b.z).length() / 0.5), 1)
	for i in pas + 1:
		if not _libre(a.lerp(b, float(i) / pas)):
			return false
	return true

## Une seule fois (la physique du village est alors en place) : ne garde que les points de promenade joignables en ligne droite
## depuis le poste (et entre eux, dans l'ordre), sans traverser un mur ou un bâtiment.
func _filtrer_points() -> void:
	_points_filtres = true
	if points.size() < 2:
		return
	_capsule_promenade = CapsuleShape3D.new()
	_capsule_promenade.radius = 0.35
	_capsule_promenade.height = 1.8
	var gardes: Array = [points[0]]
	for i in range(1, points.size()):
		var q: Vector3 = points[i]
		if _segment_libre(points[0], q) and _segment_libre(gardes[gardes.size() - 1], q):
			gardes.append(q)
	points = gardes

func _t_poste(_dt: float) -> void:
	if _t >= _prochaine_promenade and points.size() > 1 and _poste_vie == null:
		etat = ALLER
		_t = 0.0
		_bloque = 0.0
		_variete_fin = 0.0
		_autour = 0.0
	elif _t >= _prochaine_promenade:
		_t = 0.0
		_prochaine_promenade = randf_range(15.0, 40.0)

var _cible := 1
var _duree_pause := 3.0

func _cible_index() -> int:
	return clampi(_cible, 0, points.size() - 1)

## Avance vers p ; renvoie la direction (ZERO une fois arrivé ou coincé).
func _vers_point(p: Vector3, dt: float) -> Vector3:
	var d := p - global_position
	d.y = 0.0
	var vitesse_reelle := Vector2(velocity.x, velocity.z).length()
	_bloque = _bloque + dt if (_t > 1.0 and _avance and vitesse_reelle < 0.2) else 0.0
	if d.length() < 0.25 or _bloque > 2.0 or _t > 40.0:
		_bloque = 0.0
		if etat == ALLER:
			# petite pause sur place puis retour au poste
			etat = PAUSE
			_t = 0.0
			_duree_pause = randf_range(2.0, 5.0)
			_jouer("Idle", 0.3)
		else:
			etat = POSTE
			_t = 0.0
			_prochaine_promenade = randf_range(15.0, 40.0)
			_cible = 1 + randi() % maxi(points.size() - 1, 1)
			_activite()
		return Vector3.ZERO
	return d.normalized()

## Tête : suit le joueur en deçà de DIST_TETE (ou pendant la conversation), sinon un éventuel
## regard autour ; sinon revient droit devant.
func _regard_tete(dist: float) -> void:
	if _tete == null:
		return
	var oeil := global_position + Vector3.UP * 1.55
	if joueur != null and (dist < DIST_TETE or _en_conversation):
		var cam: Camera3D = joueur.camera if "camera" in joueur else null
		_tete.cible = cam.global_position if cam != null else joueur.global_position + Vector3.UP * 1.6
		_tete.voulu = true
	elif _autour > 0.0:
		var moitie := _autour > _autour_duree * 0.5
		var lacet := _autour_lacet if moitie else -_autour_lacet * 0.6
		_tete.cible = oeil + global_transform.basis * (Basis(Vector3.UP, lacet) * Vector3(0.0, 0.0, 4.0))
		_tete.voulu = true
	else:
		_tete.voulu = false

func _interactions(dist: float, dt: float) -> void:
	if dialogue == null or not is_instance_valid(dialogue):
		return
	# interpellation au passage
	_delai_interpelle -= dt
	var phrases: Array = donnees.get("interpellations", [])
	if dist < DIST_INTERPELLE and _delai_interpelle <= 0.0 and not phrases.is_empty() and not _en_conversation:
		_delai_interpelle = 40.0
		var selon := Disposition.interpellation(self)    # froid, chaleureux ou fermé selon la réputation (scripts/disposition.gd)
		dialogue.dire_au_passage(nom_affiche(), selon if selon != "" else phrases.pick_random())
	# invite « E Parler » si le joueur est proche et regarde ce villageois
	var veut := false
	var cam: Camera3D = joueur.camera
	if dist < DIST_PARLER and not _en_conversation and cam != null:
		var avant := -cam.global_transform.basis.z
		var cible := (global_position + Vector3.UP * 1.4 - cam.global_position).normalized()
		veut = avant.dot(cible) > DOT_PARLER
	if veut and not _invite:
		_invite = true
		dialogue.inviter(self)
	elif not veut and _invite:
		_invite = false
		dialogue.retirer_invite(self)

# --- lot vie_pnj : rentrée, sommeil, abri (pilotés par Vie) ---------------------------------------------------------

## Poste du moment : celui que Vie a fixé (feu du soir), sinon son poste de jour.
func poste() -> Vector3:
	return (_poste_vie as Vector3) if _poste_vie is Vector3 else points[0]

func est_endormi() -> bool:
	return etat == DORT

## Couché (ou en train de se coucher / de se lever) dans un lit visible.
func au_lit() -> bool:
	return etat == DORT and seq != ""

func occupe() -> bool:
	return _en_conversation or remplace != null

## Le trajet en ligne droite de a à b est-il libre (capsule de 0,35 x 1,8 m) ? Réservé à Vie.
func chemin_libre(a: Vector3, b: Vector3) -> bool:
	return _segment_libre(a, b)

## Va à `but` en suivant `via` ; arrivé, il entre dans le bâtiment (`entre`, DORT) ou se pose là : poste du moment avec `activite` et `cap`
## (radians, NAN = inchangé). `poste_jour` : le but est son poste habituel. Refusé pendant une conversation.
func rentrer(but: Vector3, entre: bool, via: Array = [], vite := false, poste_jour := false, activite := "", cap := NAN) -> void:
	if seq in ["redresser", "lever"]:
		_apres_lever = [but, entre, via, vite, poste_jour, activite, cap]   # il finit de se lever, puis repart
		return
	if _en_conversation:
		return
	if not entre:
		_eveil_t = 0.0
	_route = via.duplicate()
	_route.append(but)
	_entre = entre
	_vite = vite
	_poste_vie = null if poste_jour else but
	_act_vie = "" if poste_jour else activite
	_cap_arrivee = deg_to_rad(float(donnees["cap"])) if poste_jour and donnees.has("cap") else cap
	etat = RENTRE
	_t = 0.0
	_bloque = 0.0
	_prog_t = 0.0
	_prog_d = INF
	_variete_fin = 0.0
	_autour = 0.0

## Instantané (heure sautée, hors de vue) : il est déjà arrivé.
func installer(but: Vector3, entre: bool, poste_jour := false, activite := "", cap := NAN) -> void:
	if seq != "":
		_quitter_lit()      # placement direct : il quitte le lit sans animation
	rentrer(but, entre, [], false, poste_jour, activite, cap)
	_en_conversation = false
	global_position = but + Vector3(0, 0.05, 0)
	_instant = true
	_arrive()
	_instant = false

func _vers_but(dt: float) -> Vector3:
	if _route.is_empty():
		_arrive()
		return Vector3.ZERO
	var p: Vector3 = _route[0]
	var d := p - global_position
	d.y = 0.0
	var vitesse_reelle := Vector2(velocity.x, velocity.z).length()
	_bloque = _bloque + dt if (_t > 1.0 and _avance and vitesse_reelle < 0.2) else 0.0
	# lot sommeil : pietine sans approcher (il glisse contre un autre corps, ou tourne sur place) : coincé aussi
	_prog_t += dt
	var pietine := false
	if _prog_t > 5.0:
		pietine = _prog_d - d.length() < 0.3
		_prog_t = 0.0
		_prog_d = d.length()
	var dernier := _route.size() == 1
	if d.length() < (0.45 if dernier else 0.8) or _bloque > 3.0 or pietine or _t > 120.0:
		var coince := _bloque > 3.0 or pietine or _t > 120.0
		_bloque = 0.0
		_prog_t = 0.0
		_prog_d = INF
		if coince:
			global_position = Vector3(p.x, global_position.y + 0.05, p.z)   # coincé : il se pose au point visé plutôt que de rester planté
		_route.pop_front()
		if dernier:
			_arrive()
		return Vector3.ZERO
	return d.normalized()

func _arrive() -> void:
	_portes_route.clear()
	_vite = false
	_vit = 0.0
	velocity = Vector3(0, velocity.y, 0)
	if _entre:
		if lit != null and is_instance_valid(lit):
			coucher_au_lit(_instant)
		else:
			coucher()
		return
	etat = POSTE
	_t = 0.0
	_prochaine_promenade = randf_range(15.0, 40.0)
	if not is_nan(_cap_arrivee):
		rotation.y = _cap_arrivee
	_jouer("Idle", 0.0)
	_activite()

## Entre dans le bâtiment : caché, sans collision, process coupé (Vie le réveille).
func coucher() -> void:
	etat = DORT
	_route.clear()
	_en_conversation = false
	if _invite and dialogue != null and is_instance_valid(dialogue):
		_invite = false
		dialogue.retirer_invite(self)
	visible = false
	if _forme != null:
		_forme.set_deferred("disabled", true)
	process_mode = Node.PROCESS_MODE_DISABLED

## Sort devant la porte `pos` : visible, solide, et il repart (RETOUR vers son poste du moment tant que Vie ne lui donne pas autre chose).
func reveiller(pos: Vector3, instant := true) -> void:
	if seq != "":
		if not instant and seq in ["assoir", "assis", "allonger", "dort"]:
			_sortie_lit = pos
			_se_lever(false)        # il se lève, sort par la porte, puis suit ce que Vie lui demande (rentrer() mis en attente)
			return
		_quitter_lit()
	global_position = pos + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	visible = true
	if _forme != null:
		_forme.set_deferred("disabled", false)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)   # APRÈS la réactivation (différée) de la forme : un corps sans forme active n'est dans aucun espace (Jolt : « Parameter "space" is null » en move_and_slide)
	lod = 0
	etat = POSTE
	_entre = false
	_anim = ""
	_t = 0.0
	_jouer("Idle", 0.0)

## Niveau de détail (comme les gardes) : 2 = caché et gelé loin du joueur. Sans effet sur un dormeur.
func regler_lod(n: int) -> void:
	if n == lod or etat == DORT or remplace != null:
		return
	lod = n
	if _pieds != null:
		_pieds.actif = n == 0 and not (_anim in SANS_PIEDS)
	if _tete != null:
		(_tete as SkeletonModifier3D).active = n == 0
	for mi: GeometryInstance3D in modele.find_children("*", "GeometryInstance3D", true, false):
		if not mi.has_meta("ombre0"):
			mi.set_meta("ombre0", mi.cast_shadow)
		mi.cast_shadow = mi.get_meta("ombre0") if n == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = n < 2
	process_mode = Node.PROCESS_MODE_DISABLED if n == 2 else Node.PROCESS_MODE_INHERIT

# --- crime (scripts/crime.gd) -------------------------------------------------------------------------------------------

## Coup de la lame ou d'un sort du joueur : Crime décide (avertissement, agression : il se défend ou fuit, la garde accourt).
func recevoir_coup(degats: float, origine: Vector3, puissant := false, info: Dictionary = {}) -> String:
	var cr := Crime.trouver(self)
	return cr.coup_sur_pnj(self, degats, origine, puissant, info) if cr != null else ""

## Un PnjCombat prend son corps : caché, sans collision, process coupé (Vie le laisse : occupe()).
func remplacer(c: Node) -> void:
	if seq != "":
		_quitter_lit()          # couché / assis au bord de son lit : il se lève d'un coup (lit libéré, modèle redressé) avant de céder son corps
	_eveil_t = 0.0
	remplace = c
	_en_conversation = false
	_route.clear()
	if _invite and dialogue != null and is_instance_valid(dialogue):
		_invite = false
		dialogue.retirer_invite(self)
	if _tete != null:
		(_tete as SkeletonModifier3D).active = false
	visible = false
	if _forme != null:
		_forme.set_deferred("disabled", true)
	process_mode = Node.PROCESS_MODE_DISABLED

## Le combattant rend le corps : il reprend sa vie là où il est (Vie le replanifie au tick suivant).
func restaurer(mod: Node3D, pos: Vector3, lacet: float) -> void:
	remplace = null
	if mod.get_parent() != self:
		add_child(mod)
	modele = mod
	global_position = pos + Vector3(0, 0.05, 0)
	rotation.y = lacet
	velocity = Vector3.ZERO
	visible = true
	if _forme != null:
		_forme.set_deferred("disabled", false)
	if _pieds != null:
		_pieds.corps = self
		_pieds.actif = true
	if _tete != null:
		(_tete as SkeletonModifier3D).active = true
	lod = 0
	etat = POSTE
	_entre = false
	_anim = ""
	_t = 0.0
	_jouer("Idle", 0.2)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if vie != null and vie.has_method("civil"):
		var c: Dictionary = vie.civil(String(donnees.get("id", "")))
		if not c.is_empty():
			c["mode"] = ""       # replanifié au prochain tick de Vie (retour au poste du moment)
			c["fuit"] = false
# --- lot sommeil : lit, coucher, lever (pilotés par Vie, lits posés par Sommeil) -----------------------------------------
## Le soir, s'il a un lit (Sommeil.lit_pour), il passe la porte (qu'il ouvre et referme), va au bord de son lit, s'assoit (Sitting_Enter),
## s'allonge (bascule du corps autour du bassin, clip « Couche_Dort » : pose couchée et respiration lente), dort ; le matin il se
## redresse, se lève (Sitting_Exit) et ressort. Couché : visible, sans collision (le cadre du lit en a une), sans move_and_slide.
## Réveillé (on lui parle, combat ou bruit tout près), il se lève, réagit, puis se recouche si c'est encore la nuit.
const CLIP_COUCHE := "Couche_Dort"
const T_ALLONGER := 1.6          # s : bascule assis -> couché (et l'inverse)
const DIST_LIT := 16.0           # m : au-delà, le dormeur est caché et gelé (l'intérieur l'est aussi au-delà de 13 m)
const EVEIL_PARLER := 7.0        # s debout après une conversation de nuit, avant de se recoucher
const EVEIL_SURSAUT := 35.0      # s debout après un bruit, un combat
const BASSIN_DEBOUT := Vector3(0.0, 0.88, -0.09)  # bassin du clip Idle (repère du modèle ; mesuré sur le rig UAL), avant toute mesure
const BASSIN_ASSIS := Vector3(0.0, 0.54, -0.33)   # bassin du clip Sitting_Idle : siège à ~0,44 m
const DY_ASSIS := 0.06           # la paillasse est à 0,50 m : le modèle assis est rehaussé d'autant

var lit: Lit = null              # lit attribué (Sommeil) ; null : il dort caché dans le bâtiment (sans lit)
var place_lit := 0
var cote_lit := 0.0              # 0 = côté libre du lit
var porte_int_lit := Vector3.ZERO   # point juste derrière la porte de son foyer (Sommeil)
var seq := ""                    # "" | assoir | assis | allonger | dort | redresser | lever
var _seq_t := 0.0
var _seq_d := 1.0
var _xf_m0 := Transform3D()      # transform du modèle debout (repère du corps)
var _xf_m_couche := Transform3D()
var _xf_m_assis := Transform3D()
var _o_debout := BASSIN_DEBOUT
var _o_assis := BASSIN_ASSIS
var _xf_assis := Transform3D()   # corps assis au bord (monde)
var _rot_depart := 0.0
var _pos_depart := Vector3.ZERO
var _apres_lever: Array = []
var _sortie_lit := Vector3.ZERO
var _eveil_t := 0.0
var _instant := false
var _portes_route: Array = []    # [{ip, p}] portes à franchir sur la route
var _porte_ouverte: Interieur = null
var _ip_foyer: Interieur = null
var _centre_porte_foyer := Vector3.ZERO
var _porte_p := Vector3.ZERO

## Sommeil attribue un lit (place, côté) et le point derrière la porte du foyer.
func attribuer_lit(l: Lit, place: int, porte_int := Vector3.ZERO, ip: Interieur = null, centre_porte := Vector3.ZERO) -> void:
	lit = l
	place_lit = place
	porte_int_lit = porte_int
	_ip_foyer = ip
	_centre_porte_foyer = centre_porte
	cote_lit = 0.0

## Point (monde) où il se tient debout avant de s'asseoir sur son lit.
func abord_lit() -> Vector3:
	return lit.point_abord(place_lit, cote_lit) if lit != null else global_position

## La route passe par la porte d'un intérieur : il l'ouvre à 1,9 m et la referme derrière lui.
func traverser(ip: Interieur, centre: Vector3) -> void:
	if ip != null:
		_portes_route.append({"ip": ip, "p": centre})

func _portes_en_route() -> void:
	var p := global_position
	for e: Dictionary in _portes_route:
		var ip: Interieur = e["ip"]
		var c: Vector3 = e["p"]
		if is_instance_valid(ip) and Vector2(c.x - p.x, c.z - p.z).length() < 1.9:
			if not ip.ouverte:
				ip.basculer(true)
			_porte_ouverte = ip           # ouverte par lui ou trouvée ouverte : il la refermera derrière lui
			_porte_p = c
	_refermer_porte()

## Referme la porte qu'il a ouverte dès qu'il en est à 2,4 m, si le joueur n'est pas dans l'embrasure.
func _refermer_porte() -> void:
	if _porte_ouverte == null:
		return
	if not is_instance_valid(_porte_ouverte) or not _porte_ouverte.ouverte:
		_porte_ouverte = null
		return
	var p := global_position
	if Vector2(_porte_p.x - p.x, _porte_p.z - p.z).length() < 2.4:
		return
	if joueur != null and is_instance_valid(joueur) and Vector2(_porte_p.x - joueur.global_position.x, _porte_p.z - joueur.global_position.z).length() < 2.2:
		return
	for v: Node in get_tree().get_nodes_in_group("villageois"):
		var v3 := v as Node3D
		if v3 != self and v3.visible and v3.get("etat") == RENTRE and Vector2(_porte_p.x - v3.global_position.x, _porte_p.z - v3.global_position.z).length() < 2.6:
			return          # un autre arrive ou sort : il laisse la porte ouverte (le dernier la refermera)
	_porte_ouverte.basculer(false)
	_porte_ouverte = null
	_portes_route = _portes_route.filter(func(e: Dictionary) -> bool: return Vector2(e["p"].x - p.x, e["p"].z - p.z).length() < 6.0)

## Position du bassin (repère du modèle), mesurée sur le squelette tel qu'il est animé.
func _bassin_local() -> Vector3:
	var sq: Skeleton3D = modele.find_child("Skeleton3D", true, false) if modele != null else null
	if sq == null:
		return Vector3.INF
	var i := sq.find_bone("pelvis")
	if i < 0:
		return Vector3.INF
	return modele.global_transform.affine_inverse() * (sq.global_transform * sq.get_bone_global_pose(i).origin)

## Clip couché (une fois par bibliothèque) : la pose de l'Idle figée, et une respiration lente (4,4 s) sur le haut du dos et les épaules.
func _assurer_clip_couche() -> bool:
	if anim == null:
		return false
	if anim.has_animation(CLIP_COUCHE):
		return true
	if not anim.has_animation("Idle"):
		return false
	var src := anim.get_animation("Idle")
	var a := Animation.new()
	a.length = 4.4
	a.loop_mode = Animation.LOOP_LINEAR
	var souffle := {"spine_02": 0.035, "spine_03": 0.03, "clavicle_l": -0.025, "clavicle_r": -0.025, "neck_01": -0.02}
	for t in src.get_track_count():
		var ty := src.track_get_type(t)
		var chemin := src.track_get_path(t)
		var os := String(chemin.get_concatenated_subnames())
		var k := a.add_track(ty)
		a.track_set_path(k, chemin)
		match ty:
			Animation.TYPE_ROTATION_3D:
				var q := src.rotation_track_interpolate(t, 0.0)
				if souffle.has(os):
					var r := Quaternion(Vector3.RIGHT, float(souffle[os]))
					a.rotation_track_insert_key(k, 0.0, q)
					a.rotation_track_insert_key(k, 1.9, q * r)
					a.rotation_track_insert_key(k, 4.4, q)
				else:
					a.rotation_track_insert_key(k, 0.0, q)
			Animation.TYPE_POSITION_3D:
				a.position_track_insert_key(k, 0.0, src.position_track_interpolate(t, 0.0))
			Animation.TYPE_SCALE_3D:
				a.scale_track_insert_key(k, 0.0, src.scale_track_interpolate(t, 0.0))
			_:
				a.remove_track(k)
	var lib := anim.get_animation_library("")
	if lib == null:
		return false
	if not lib.has_animation(CLIP_COUCHE):
		lib.add_animation(CLIP_COUCHE, a)
	return true

## Se couche dans son lit : assis au bord puis allongé (instant : directement couché, heure sautée ou hors de vue).
func coucher_au_lit(instant := false) -> void:
	if lit == null or not is_instance_valid(lit):
		coucher()
		return
	if lit.occupants[place_lit] != self:
		if lit.occupants[place_lit] != null and is_instance_valid(lit.occupants[place_lit]):
			var autre := lit.place_libre()
			if autre < 0:
				coucher()        # lit pris (par le joueur) : il dort caché, comme avant
				return
			place_lit = autre
		lit.occupants[place_lit] = self
	etat = DORT
	_route.clear()
	_eveil_t = 0.0
	_en_conversation = false
	if _invite and dialogue != null and is_instance_valid(dialogue):
		_invite = false
		dialogue.retirer_invite(self)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	lod = 0
	velocity = Vector3.ZERO
	_vit = 0.0
	if _forme != null:
		_forme.set_deferred("disabled", true)
	if _pieds != null:
		_pieds.actif = false
	if _tete != null:
		(_tete as SkeletonModifier3D).active = false
	if seq == "":
		_xf_m0 = modele.transform
	_xf_m_assis = Transform3D(_xf_m0.basis, _xf_m0.origin + Vector3.UP * DY_ASSIS)
	_assurer_clip_couche()
	_xf_assis = lit.pose_assise(place_lit, cote_lit)
	_pos_depart = global_position
	_rot_depart = rotation.y
	var b := _bassin_local()
	if b != Vector3.INF and not instant and _anim in ["Idle", "Walk", "Idle_Talking", ""]:
		_o_debout = b
	if instant:
		_poser_assis()
		_xf_m_couche = _couche_local()
		modele.transform = _xf_m_couche
		_anim = ""
		_jouer(CLIP_COUCHE, 0.0)
		anim.seek(randf() * 4.0, true)
		seq = "dort"
		return
	seq = "assoir"
	_seq_t = 0.0
	_anim = ""
	_jouer("Sitting_Enter", 0.25)
	_seq_d = anim.get_animation("Sitting_Enter").length if anim.has_animation("Sitting_Enter") else 0.8

func _poser_assis() -> void:
	global_position = _xf_assis.origin
	var f := _xf_assis.basis.z
	rotation.y = atan2(f.x, f.z)

## Transform du modèle couché, dans le repère du corps (le corps est déjà posé assis au bord).
func _couche_local() -> Transform3D:
	var xf := global_transform.affine_inverse() * lit.pose_couchee(place_lit)
	return Transform3D(xf.basis.orthonormalized().scaled_local(_xf_m0.basis.get_scale()), xf.origin)

## Pose intermédiaire assis (k = 0) -> couché (k = 1) : le bassin glisse en arc (au-dessus du long pan), le corps pivote autour de lui.
func _pose_mi(k: float) -> Transform3D:
	var a := _xf_m_assis
	var b := _xf_m_couche
	var pa := a * _o_assis
	var pb := b * _o_debout
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), k)
	var bas := Basis(q).scaled_local(_xf_m0.basis.get_scale())
	var o := _o_assis.lerp(_o_debout, k)
	var p := pa.lerp(pb, k) + Vector3.UP * sin(PI * k) * 0.14
	return Transform3D(bas, p - bas * o)

func _au_lit(dt: float) -> void:
	_seq_t += dt
	if _en_conversation:
		_debut_conversation += dt
		if joueur != null and not joueur.en_dialogue and _debut_conversation > 0.3:
			_en_conversation = false
			if seq == "":
				_activite()
	match seq:
		"assoir":
			var k := clampf(_seq_t / 0.35, 0.0, 1.0)
			global_position = _pos_depart.lerp(_xf_assis.origin, k)
			var f := _xf_assis.basis.z
			rotation.y = lerp_angle(_rot_depart, atan2(f.x, f.z), k)
			modele.transform = _xf_m0.interpolate_with(_xf_m_assis, smoothstep(0.3, 1.0, _seq_t / _seq_d))
			if _seq_t >= _seq_d:
				_poser_assis()
				modele.transform = _xf_m_assis
				seq = "assis"
				_seq_t = 0.0
				_jouer("Sitting_Idle", 0.2)
		"assis":
			if _seq_t > 0.6:
				var b := _bassin_local()
				if b != Vector3.INF:
					_o_assis = b
				_xf_m_couche = _couche_local()
				seq = "allonger"
				_seq_t = 0.0
				_jouer(CLIP_COUCHE, T_ALLONGER * 0.8)
		"allonger":
			var k := smoothstep(0.0, T_ALLONGER, _seq_t)
			modele.transform = _pose_mi(k)
			if _seq_t >= T_ALLONGER:
				modele.transform = _xf_m_couche
				seq = "dort"
				_seq_t = 0.0
		"dort":
			_invite_lit()
		"redresser":
			var k := 1.0 - smoothstep(0.0, T_ALLONGER, _seq_t)
			modele.transform = _pose_mi(k)
			if _seq_t >= T_ALLONGER:
				modele.transform = _xf_m_assis
				seq = "lever"
				_seq_t = 0.0
				_jouer("Sitting_Exit", 0.2)
				_seq_d = anim.get_animation("Sitting_Exit").length if anim.has_animation("Sitting_Exit") else 0.8
		"lever":
			modele.transform = _xf_m_assis.interpolate_with(_xf_m0, smoothstep(0.0, 0.7, _seq_t / _seq_d))
			if _seq_t >= _seq_d:
				_fin_lever()
	_refermer_porte()

## Commence à se lever (redressement puis Sitting_Exit) ; `sursaut` : réveillé dans la nuit, il reste debout puis se recouche.
func _se_lever(sursaut: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	lod = 0
	if sursaut:
		_sortie_lit = Vector3.ZERO
	match seq:
		"dort", "allonger":
			_xf_m_couche = modele.transform if seq == "allonger" else _xf_m_couche
			seq = "redresser"
			_seq_t = 0.0
			_jouer("Sitting_Idle", T_ALLONGER * 0.7)
		"assoir", "assis":
			seq = "lever"
			_seq_t = 0.0
			_jouer("Sitting_Exit", 0.2)
			_seq_d = anim.get_animation("Sitting_Exit").length if anim.has_animation("Sitting_Exit") else 0.8

## Debout à côté du lit : il redevient un corps solide, puis repart (route en attente), ou reste éveillé un moment.
func _fin_lever() -> void:
	seq = ""
	if lit != null and is_instance_valid(lit):
		lit.liberer(self)
	modele.transform = _xf_m0
	if _forme != null:
		_forme.set_deferred("disabled", false)
	if _pieds != null:
		_pieds.actif = lod == 0
	if _tete != null:
		(_tete as SkeletonModifier3D).active = lod == 0
	etat = POSTE
	_t = 0.0
	_anim = ""
	_jouer("Idle", 0.15)
	var reste := _apres_lever
	_apres_lever = []
	if not reste.is_empty() and _sortie_lit != Vector3.ZERO:
		var via: Array = []
		if porte_int_lit != Vector3.ZERO:
			via.append(porte_int_lit)
		via.append(_sortie_lit)
		via.append_array(reste[2])
		_sortie_lit = Vector3.ZERO
		rentrer(reste[0], reste[1], via, reste[3], reste[4], reste[5], reste[6])
		traverser(_ip_foyer, _centre_porte_foyer)
		return
	_poste_vie = global_position        # éveillé : il reste là, sans promenade, puis se recouche
	_act_vie = "Idle"
	if _eveil_t <= 0.0:
		_eveil_t = EVEIL_PARLER if _en_conversation else EVEIL_SURSAUT

## Quitte le lit sans animation (placement direct).
func _quitter_lit() -> void:
	if lit != null and is_instance_valid(lit):
		lit.liberer(self)
	if seq != "" and modele != null:
		modele.transform = _xf_m0
	seq = ""
	_apres_lever = []
	if _pieds != null:
		_pieds.actif = true
	if _tete != null:
		(_tete as SkeletonModifier3D).active = true
	_anim = ""

## Éveillé la nuit : une fois le délai écoulé (et la conversation finie), il se recouche si Vie le veut encore à la maison.
func _eveille(dt: float) -> void:
	if lit == null or _eveil_t <= 0.0 or _en_conversation:
		return
	_eveil_t -= dt
	if _eveil_t > 0.0:
		return
	_eveil_t = 0.0
	if vie != null and vie.has_method("mode_de") and vie.mode_de(self) == "maison":
		rentrer(abord_lit(), true, [])

## Réveil brusque (bruit, combat tout près) : il se lève et s'inquiète à voix haute.
func reveiller_en_sursaut() -> void:
	if not seq in ["dort", "allonger", "assis", "assoir"]:
		return
	_eveil_t = EVEIL_SURSAUT
	_se_lever(true)
	if dialogue != null and is_instance_valid(dialogue) and joueur != null and global_position.distance_to(joueur.global_position) < 14.0:
		var l: String = vie.call("_ligne", self, "reveil") if vie != null else ""
		dialogue.dire_au_passage(nom_affiche(), l if l != "" else "Hein ? Qu'est-ce que c'est que ce vacarme ?")

## On lui parle pendant qu'il dort : il se redresse, grommelle, puis se recouchera.
func _parler_reveille() -> Array:
	var l: String = vie.call("_ligne", self, "reveil") if vie != null else ""
	_eveil_t = EVEIL_PARLER
	if seq in ["dort", "allonger", "assis", "assoir"]:
		_se_lever(true)
	_en_conversation = true
	_debut_conversation = 0.0
	return [l if l != "" else "Hmm… Quoi ? On ne peut plus dormir en paix ?", "Revenez demain, voulez-vous."]

func texte_action() -> String:
	return ("Réveiller %s" if seq == "dort" else "Parler à %s") % nom_affiche()

## Invite « E Réveiller » : le joueur est tout près et regarde sa tête, sur l'oreiller.
func _invite_lit() -> void:
	if dialogue == null or not is_instance_valid(dialogue) or joueur == null or not is_instance_valid(joueur):
		return
	var tete := modele.global_transform * Vector3(0, 1.55, 0)
	var veut := false
	var cam: Camera3D = joueur.camera
	if cam != null and Vector2(joueur.global_position.x - tete.x, joueur.global_position.z - tete.z).length() < DIST_PARLER:
		veut = (-cam.global_transform.basis.z).dot((tete - cam.global_position).normalized()) > 0.8
	if veut and not _invite:
		_invite = true
		dialogue.inviter(self)
	elif not veut and _invite:
		_invite = false
		dialogue.retirer_invite(self)

## Niveau de détail d'un dormeur couché (Vie) : caché et gelé au-delà de DIST_LIT m (les murs le cachent de toute façon).
func lod_lit(d: float) -> void:
	if seq != "dort":
		return
	var cache := d > DIST_LIT
	if cache == (lod == 2):
		return
	lod = 2 if cache else 0
	visible = not cache
	process_mode = Node.PROCESS_MODE_DISABLED if cache else Node.PROCESS_MODE_INHERIT
	if cache and _invite and dialogue != null and is_instance_valid(dialogue):
		_invite = false
		dialogue.retirer_invite(self)
