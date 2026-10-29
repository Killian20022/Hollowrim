class_name Demembrement
## DÉMEMBREMENT à la mort (étape 1 : draugrs et bandits, squelette RIG18 / Quaternius) : bras, avant-bras, jambe, mollet,
## coupe en deux au bassin ; la tête passe par Decapitation (même technique, déjà en place).
##   var membre := Demembrement.choisir(combat, r, sorte)      # "" (rien) ou une clé de MEMBRES, selon le coup
##   Demembrement.trancher(modele, membre, impulsion, couleur, matiere)   -> RigidBody3D (le morceau) ou null
## Technique (sans maillage découpé à l'avance : marche sur tous les gabarits et toutes les tenues) :
##   - CORPS : un modificateur (MembreTranche, DERNIER du squelette, après le ragdoll) écrase l'os coupé (échelle ~0) : le membre
##     entier se replie sur l'articulation → moignon ; « os seul » (bassin de la coupe en deux) : l'os est écrasé SANS ses
##     enfants (échelle et position des enfants compensées : l'échelle uniforme commute avec la rotation, c'est exact) ;
##   - MORCEAU : copie des maillages visibles avec une peau (Skin) refaite où les attaches du membre gardent leur pose du moment
##     et toutes les autres se replient sur le point de coupe ; posé sur un squelette d'un seul os, dans un corps rigide léger
##     lancé dans le sens du coup ; il reste au sol DUREE s ;
##   - CAPUCHONS de moignon des deux côtés (chair sombre du draugr, chair rouge du bandit, os blanc au centre) et JET de sang en
##     gros pixels (GerbePixels « sang_jet » / « draugr_jet ») qui pulse du moignon, gouttes et traces au sol (Sang.trace).
## Coût : corps rigides, squelettes et maillages des morceaux viennent d'un POOL (TAILLE_POOL emplacements recyclés, le plus
## ancien d'abord) ; seule la peau (Skin, quelques dizaines d'attaches) est dupliquée à chaque coupe.

const DUREE := 30.0
const TAILLE_POOL := 6
const MAILLAGES_MAX := 12          # maillages copiés par morceau (le corps nordique en a ~8)
const CALQUE_CADAVRES := 16

## Membres : os coupé, os de mesure de la longueur (bout du morceau), masse (kg), rayon de la coupe (m), os seul (sans enfants).
const MEMBRES := {
	"bras_l": {"os": "upperarm_l", "bout": "hand_l", "masse": 3.5, "rayon": 0.055},
	"bras_r": {"os": "upperarm_r", "bout": "hand_r", "masse": 3.5, "rayon": 0.055},
	"avantbras_l": {"os": "lowerarm_l", "bout": "hand_l", "masse": 1.8, "rayon": 0.045},
	"avantbras_r": {"os": "lowerarm_r", "bout": "hand_r", "masse": 1.8, "rayon": 0.045},
	"jambe_l": {"os": "thigh_l", "bout": "foot_l", "masse": 9.0, "rayon": 0.085},
	"jambe_r": {"os": "thigh_r", "bout": "foot_r", "masse": 9.0, "rayon": 0.085},
	"mollet_l": {"os": "calf_l", "bout": "foot_l", "masse": 4.0, "rayon": 0.065},
	"mollet_r": {"os": "calf_r", "bout": "foot_r", "masse": 4.0, "rayon": 0.065},
	# coupe en deux : le haut du corps reste le ragdoll (bras, tête) ; bassin + jambes partent en morceau
	"moitie": {"os": "pelvis", "garde": "spine_01", "bout": "foot_l", "masse": 22.0, "rayon": 0.15},
}

## Chances de démembrement à la mort par l'épée (niveau complet ; × CHANCE_REDUIT au niveau « réduit »).
const CHANCE := {"legere": 0.35, "titubante": 0.35, "lourde": 0.6, "recul": 0.6, "chute": 0.6, "puissant": 1.0}
## Coup puissant : part des coupes en deux (les autres fois, membre selon la hauteur et le sens de la lame). Avis du 2026-10-29.
const PART_MOITIE := 1.0 / 3.0
const CHANCE_REDUIT := 0.5
## Couleurs des capuchons (chair, lèvre de la plaie, os) par matière de corps.
const CHAIRS := {
	"draugr": [Color("#5a2a1c"), Color("#2e0807"), Color("#d2c9ad")],
	"chair": [Color("#8a1a14"), Color("#3a0605"), Color("#efe7d0")],
	# squelette : os cassé (cassure claire, bord sombre, moelle sèche au centre)
	"os": [Color("#d2c9ad"), Color("#6b6452"), Color("#8f8670")],
	# membre gelé éclaté : glace blanc-bleu (palette Givre), cœur de chair figée
	"glace": [Color("#a8d8f8"), Color("#5f9fe8"), Color("#e8f6ff")],
	# membre réduit en cendres : charbon, braise au bord, os calciné
	"cendre": [Color("#2a2018"), Color("#b3341f"), Color("#6b6452")],
}

## Chance imposée (tests, captures) : < 0 = règles du jeu.
static var chance_forcee := -1.0
## Membre imposé (tests, captures) : "" = selon le coup.
static var membre_force := ""
## Durée de vie des morceaux (tests : plus court).
static var duree := DUREE
## Tirages propres (le hasard des salles et du butin n'est pas consommé).
static var _rng := RandomNumberGenerator.new()
static var _pool: Array[Dictionary] = []
static var _suivant := 0
static var _mats_capuchon := {}
static var _maillage_capuchon: ArrayMesh
## Horloge de jeu (s) des morceaux : avancée par le gestionnaire des jets (temps du jeu, pas l'horloge murale).
static var horloge := 0.0
## Compteur de coupes (tests, mesures).
static var coupes := 0

class MembreTranche extends SkeletonModifier3D:
	## Os écrasés avec tout leur sous-arbre.
	var ecrases: PackedInt32Array = []
	## Os écrasés seuls ; enfants à compenser (même index dans `compenses`).
	var seuls: PackedInt32Array = []
	var compenses: Array[PackedInt32Array] = []
	const E := 0.002
	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq == null:
			return
		for os in ecrases:
			sq.set_bone_pose_scale(os, Vector3.ONE * E)
		for k in seuls.size():
			sq.set_bone_pose_scale(seuls[k], Vector3.ONE * E)
			for c in compenses[k]:
				sq.set_bone_pose_position(c, sq.get_bone_pose_position(c) / E)
				sq.set_bone_pose_scale(c, sq.get_bone_pose_scale(c) / E)

static func niveau() -> int:
	return Sang.niveau()

## Membres déjà coupés de ce modèle.
static func coupes_de(modele: Node3D) -> Array:
	return modele.get_meta("membres_coupes", []) if modele != null else []

static func peut(modele: Node3D, membre: String) -> bool:
	if modele == null or not MEMBRES.has(membre) or coupes_de(modele).has(membre) or modele.has_meta("coupe_moitie"):
		return false
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return false
	var d: Dictionary = MEMBRES[membre]
	return sq.find_bone(d["os"]) >= 0 and sq.find_bone(d["bout"]) >= 0 and (not d.has("garde") or sq.find_bone(d["garde"]) >= 0)

# ------------------------------------------------------------------ choix selon le coup

## Profils démembrables : draugrs, bandits (étape 1), squelettes et troll de givre (étape 2). `sorts` : pour les effets de sort
## (feu, glace), mêmes profils.
static func profil_demembrable(p: ProfilCible, _sorts := false) -> bool:
	if p == null:
		return false
	return p.nom.begins_with("draugr") or p.nom == "bandit" or p.nom == "squelette" or p.nom.begins_with("troll")

## Matière des coupes d'un profil : "draugr", "os" (squelette) ou "chair" (vivants, troll).
static func matiere_de(p: ProfilCible) -> String:
	if p.matiere == "os":
		return "os"
	return "draugr" if p.nom.begins_with("draugr") else "chair"

## Membres possibles par profil : le troll ne perd que la tête et les bras (jambes trop massives, pas de coupe en deux).
static func membres_autorises(p: ProfilCible) -> Array:
	if p != null and p.nom.begins_with("troll"):
		return ["tete", "bras_l", "bras_r", "avantbras_l", "avantbras_r"]
	return ["tete"] + MEMBRES.keys()

## Membre tranché par ce coup mortel ("" = aucun ; "tete" = à confier à Decapitation). `combat` : CombatEnnemi de la victime,
## `r` : résultat du coup (info : point, direction de la lame, zone, attaque, type), `sorte` : type de mort (CombatEnnemi.type_mort).
static func choisir(combat: CombatEnnemi, r: Dictionary, sorte: String) -> String:
	var niv := niveau()
	if niv == 0 or combat == null or not profil_demembrable(combat.profil) or combat.modele == null:
		return ""
	var i: Dictionary = r.get("info", {})
	# coups d'arme blanche du joueur seulement (mains.gd : « instant », « charge ») ; pas les flèches ni les pièges ; les finishers
	# gardent leur mort propre (décapitation, épée plantée : le corps reste entier)
	if i.is_empty() or not (i.has("instant") or i.has("charge")) or String(i.get("attaque", "")) == "finisher":
		return ""
	if i.has("ecole") or bool(i.get("continu", false)) or String(i.get("type", "tranchant")) != "tranchant":
		return ""   # sorts, coups contondants : pas de membre tranché (étape 2 : feu, glace)
	if String(i.get("mort_finisher", "")) == "decapite":
		return ""   # la décapitation du finisher passe par son propre chemin
	var chance := chance_forcee if chance_forcee >= 0.0 else float(CHANCE.get(sorte, 0.35)) * (1.0 if niv == 2 else CHANCE_REDUIT)
	if _rng.randf() >= chance:
		return ""
	if membre_force != "":
		return membre_force if membre_force in membres_autorises(combat.profil) else ""
	var autorises := membres_autorises(combat.profil)
	if sorte == "puissant" and niv == 2 and _rng.randf() < PART_MOITIE and peut(combat.modele, "moitie") and "moitie" in autorises:
		return "moitie"
	var m := membre_du_coup(combat.corps, combat.modele, combat.hauteur, i)
	if not m in autorises:
		# troll : coup bas → le bras du même côté
		m = "bras_" + m.right(1) if m.right(2) in ["_l", "_r"] else ""
	return m

## Membre visé d'après la hauteur et le sens de la lame : horizontal haut → tête ; diagonale / buste → bras (le plus proche
## du point) ; bas → jambe (mollet si très bas). La coupe en deux est tirée à part (coup puissant, PART_MOITIE).
static func membre_du_coup(corps: Node3D, modele: Node3D, hauteur: float, i: Dictionary) -> String:
	var point: Vector3 = i.get("point", corps.global_position + Vector3.UP * hauteur * 0.6)
	var dir: Vector3 = i.get("direction", Vector3.ZERO)
	var rel := (point.y - corps.global_position.y) / maxf(hauteur, 0.5)
	var vertical := absf(dir.normalized().y) if dir.length() > 0.01 else 0.4
	var zone := String(i.get("zone", ""))
	var choix := ""
	if zone == "tete" or rel >= 0.8 or (rel >= 0.68 and vertical < 0.35):
		choix = "tete"
	elif zone == "jambes" or rel < 0.42:
		choix = ("mollet_" if rel < 0.24 else "jambe_") + _cote(corps, modele, point, "thigh")
	else:
		var c := _cote(corps, modele, point, "upperarm")
		var avant := _plus_proche_de(modele, point, "lowerarm_" + c, "upperarm_" + c)
		choix = ("avantbras_" if avant else "bras_") + c
	if choix == "tete" and not Decapitation.peut(modele):
		choix = "bras_" + _cote(corps, modele, point, "upperarm")
	return choix

## Côté ("l" / "r") du membre le plus proche du point d'impact.
static func _cote(corps: Node3D, modele: Node3D, point: Vector3, os: String) -> String:
	var al := _accroche(modele, os + "_l")
	var ar := _accroche(modele, os + "_r")
	if al != null and ar != null:
		return "l" if point.distance_squared_to(al.global_position) < point.distance_squared_to(ar.global_position) else "r"
	# sans accroches : le côté du point dans le repère du corps (gauche du modèle = +X local)
	return "l" if (modele.global_transform.affine_inverse() * point).x > 0.0 else "r"

static func _plus_proche_de(modele: Node3D, point: Vector3, a: String, b: String) -> bool:
	var na := _accroche(modele, a)
	var nb := _accroche(modele, b)
	if na == null or nb == null:
		return false
	return point.distance_squared_to(na.global_position) < point.distance_squared_to(nb.global_position)

static func _accroche(modele: Node3D, os: String) -> Node3D:
	if modele == null or not modele.has_meta("plaies_accroches"):
		return null
	for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
		if is_instance_valid(a) and a.bone_name == os:
			return a
	return null

# ------------------------------------------------------------------ coupe

## Tranche `membre` (clé de MEMBRES) : le corps garde un moignon, le morceau part dans un corps rigide lancé par `impulsion`
## (N·s). `matiere_chair` : "draugr", "chair" (bandit, troll) ou "os" (squelette : pas de sang, éclats d'os, craquement).
## `mode` : "coupe" (lame : le morceau tombe), "glace" (membre gelé qui ÉCLATE en cristaux : pas de morceau), "cendre" (feu :
## le membre s'effrite en cendres et braises). Renvoie le corps rigide du morceau (null si impossible ou sans morceau).
static func trancher(modele: Node3D, membre: String, impulsion: Vector3, couleur: Color, matiere_chair := "chair", mode := "coupe") -> RigidBody3D:
	if not peut(modele, membre) or not modele.is_inside_tree():
		return null
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var d: Dictionary = MEMBRES[membre]
	var racine := sq.find_bone(d["os"])
	var garde := sq.find_bone(d["garde"]) if d.has("garde") else -1
	var k_rayon := float(modele.get_meta("gore_echelle", 1.0))   # troll : membres plus épais
	# os du morceau : la racine et son sous-arbre, sauf le sous-arbre gardé (moitié : la colonne reste au corps)
	var dans := {}
	_sous_arbre(sq, racine, garde, dans)
	Plaies.preparer(modele)
	# repère visible de la racine (accroche à jour) ; poses relatives des os du morceau au moment de la coupe
	var p_racine := sq.get_bone_global_pose(racine)
	var t_racine := sq.global_transform * p_racine
	var acc := _accroche(modele, d["os"])
	if acc != null:
		t_racine = acc.global_transform
	var inv_racine := p_racine.affine_inverse()
	# point de coupe (repère de la racine) : l'articulation ; moitié : la base de la colonne
	var coupe_local := Vector3.ZERO
	if garde >= 0:
		coupe_local = inv_racine * sq.get_bone_global_pose(garde).origin
	var bout := inv_racine * sq.get_bone_global_pose(sq.find_bone(d["bout"])).origin
	if membre == "moitie":
		var bout2 := inv_racine * sq.get_bone_global_pose(sq.find_bone("foot_r")).origin
		bout = (bout + bout2) * 0.5
	var axe := bout.normalized() if bout.length() > 0.01 else Vector3.UP
	var chairs: Array = CHAIRS.get(mode if mode != "coupe" else matiere_chair, CHAIRS["chair"])
	var r_coupe := float(d["rayon"]) * k_rayon
	var rb: RigidBody3D = null
	var sk: Skeleton3D = null
	var t_bout_morceau := Transform3D(_base_vers(-axe if garde < 0 else coupe_local.normalized()), coupe_local)
	if mode == "coupe":
		rb = _morceau(modele, sq, d, membre, dans, t_racine, inv_racine, coupe_local, bout, axe, k_rayon)
		sk = rb.get_node("Skeleton3D") as Skeleton3D
		_capuchon(sk, t_bout_morceau, chairs, r_coupe)
	# corps : le membre se replie (dernier modificateur, après le ragdoll)
	var mt := sq.get_node_or_null("MembreTranche") as MembreTranche
	if mt == null:
		mt = MembreTranche.new()
		mt.name = "MembreTranche"
		sq.add_child(mt)
	sq.move_child(mt, -1)
	if garde >= 0:
		var enfants := PackedInt32Array()
		for c in sq.get_bone_children(racine):
			if c == garde:
				enfants.append(c)
			else:
				mt.ecrases.append(c)   # jambes : écrasées entières
		mt.seuls.append(racine)
		mt.compenses.append(enfants)
	else:
		mt.ecrases.append(racine)
	# pièces accrochées au membre gelé ou réduit en cendres (épée, bouclier) : elles tombent au sol, libres
	if mode != "coupe":
		_lacher_pieces(sq, dans)
	# capuchon du corps
	var t_moignon: Transform3D
	var accroche_corps: Node3D
	if garde >= 0:
		# moitié : capuchon sous le haut du corps, porté par la base de la colonne, tourné vers le bas
		accroche_corps = _accroche_os(modele, sq, d["garde"])
		t_moignon = Transform3D(_base_vers(Vector3.DOWN), Vector3.ZERO)
	else:
		var parent := sq.get_bone_parent(racine)
		accroche_corps = _accroche_os(modele, sq, sq.get_bone_name(parent))
		var repos := sq.get_bone_rest(racine)
		t_moignon = Transform3D(_base_vers(repos.basis.y), repos.origin)
	if accroche_corps != null:
		_capuchon(accroche_corps, t_moignon, chairs, r_coupe)
	# effets selon la matière et le mode
	var origine := t_racine.origin
	var milieu := t_racine * (bout * 0.5)
	var dir_coup := (impulsion.normalized() + Vector3.UP * 0.4).normalized()
	var k_cam := attenuation_camera(modele, origine)
	match mode:
		"glace":
			# le membre gelé éclate : gerbe de cristaux le long du membre, lueur froide, éclats de glace
			GerbePixels.emettre(modele, milieu, dir_coup, "givre", 2.8 * k_cam)
			GerbePixels.emettre(modele, origine, Vector3.UP, "givre_lueur", 1.6 * k_cam)
			GerbePixels.emettre(modele, t_racine * bout, dir_coup, "givre", 1.6 * k_cam)
			RetourImpact.son(modele, "glace_eclate", milieu, 0.0)
		"cendre":
			# le membre carbonisé s'effrite : cendres qui retombent et braises qui montent
			GerbePixels.emettre(modele, milieu, Vector3.UP, "poussiere", 2.6 * k_cam)
			GerbePixels.emettre(modele, milieu, Vector3.UP, "braise", 2.0 * k_cam)
			RetourImpact.son(modele, "carbonise", milieu, -2.0)
		_:
			if matiere_chair == "os":
				# squelette : l'os casse net, éclats d'os, pas de sang
				GerbePixels.emettre(modele, origine, dir_coup, "os", 1.8 * k_cam)
				RetourImpact.son(modele, "os_brise", origine, 0.0)
			else:
				var mat_jet := "draugr_jet" if matiere_chair == "draugr" else "sang_jet"
				RetourImpact.son(modele, "membre_tranche", origine, 0.0)
				if Sang.actif():
					var duree_jet := (2.6 if niveau() == 2 else 1.0) * (1.4 if membre == "moitie" else 1.0)
					if accroche_corps != null:
						Jets.lancer(accroche_corps, t_moignon, mat_jet, couleur, duree_jet, 1.5 if membre == "moitie" else 1.0)
					Jets.lancer(sk, t_bout_morceau, mat_jet, couleur, duree_jet * 0.35, 0.7)
					GerbePixels.emettre(modele, origine, dir_coup, mat_jet, 1.7 * k_cam)
					# éclaboussures au sol et sur le mur proche, dans le sens du coup (traces plafonnées de Sang)
					Sang._traces_giclee(modele, origine, impulsion.normalized(), 2.2 if niveau() == 2 else 1.0, couleur, niveau())
					RetourImpact.son(modele, "giclee", origine, -3.0)
					if membre == "moitie" and accroche_corps != null:
						boyaux(modele, accroche_corps, t_moignon, origine, matiere_chair, r_coupe)
				else:
					GerbePixels.emettre(modele, origine, dir_coup, "poussiere", 1.6 * k_cam)
	if rb != null:
		_traces_morceau(rb, couleur, matiere_chair != "os" and Sang.actif())
		# vitesse imposée (et non une impulsion) : un bras ne part pas plus loin qu'une jambe ; le morceau tombe près du corps
		var vitesse := {"moitie": 1.1, "jambe_l": 1.8, "jambe_r": 1.8}.get(membre, 2.4) as float
		rb.linear_velocity = impulsion.normalized() * vitesse
		rb.angular_velocity = Vector3(_rng.randf_range(-7, 7), _rng.randf_range(-4, 4), _rng.randf_range(-7, 7)) * (0.35 if membre == "moitie" else 1.0)
		modele.set_meta("morceau_" + membre, rb)
	var l := coupes_de(modele).duplicate()
	l.append(membre)
	modele.set_meta("membres_coupes", l)
	if membre == "moitie":
		modele.set_meta("coupe_moitie", true)
	modele.set_meta("mode_" + membre, mode)
	coupes += 1
	return rb

## Morceau tranché : emplacement du pool, forme, copies des maillages (peau refaite), pièces accrochées au membre.
static func _morceau(modele: Node3D, sq: Skeleton3D, d: Dictionary, membre: String, dans: Dictionary, t_racine: Transform3D,
		inv_racine: Transform3D, coupe_local: Vector3, bout: Vector3, axe: Vector3, k_rayon: float) -> RigidBody3D:
	var echelle := t_racine.basis.get_scale().x
	var slot := _emplacement(modele)
	var rb: RigidBody3D = slot["rb"]
	var sk: Skeleton3D = slot["sk"]
	var monde := modele.get_tree().current_scene if modele.get_tree().current_scene else modele.get_tree().root
	if rb.get_parent() != monde:
		if rb.get_parent():
			rb.get_parent().remove_child(rb)
		monde.add_child(rb)
	rb.freeze = false
	rb.visible = true
	rb.process_mode = Node.PROCESS_MODE_INHERIT
	rb.mass = float(d["masse"]) * k_rayon * k_rayon
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	rb.global_transform = Transform3D(t_racine.basis.orthonormalized(), t_racine.origin)
	sk.global_transform = t_racine
	# forme : capsule de la racine au bout du membre (pose du moment)
	var cs: CollisionShape3D = slot["cs"]
	var cap: CapsuleShape3D = cs.shape
	var rayon := float(d["rayon"]) * k_rayon * echelle
	var longueur := maxf(bout.length() * echelle, rayon * 2.2)
	cap.radius = rayon
	cap.height = longueur + rayon
	cs.transform = Transform3D(_base_vers(axe), axe * bout.length() * echelle * 0.5)
	# maillages : copies (pool) avec une peau où seul le membre garde ses attaches
	var mis: Array = slot["mis"]
	var n := 0
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if n >= MAILLAGES_MAX:
			break
		if not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		var copie: MeshInstance3D = mis[n]
		n += 1
		copie.mesh = mi.mesh
		copie.skin = _peau_morceau(mi.skin, sq, dans, inv_racine, coupe_local)
		copie.material_override = mi.material_override
		copie.material_overlay = mi.material_overlay if mi.material_overlay != null and mi.material_overlay.resource_name == "carbonise" else null
		for s in copie.get_surface_override_material_count():
			copie.set_surface_override_material(s, null)
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m != null:
				copie.set_surface_override_material(s, m)
		copie.cast_shadow = mi.cast_shadow
		copie.layers = mi.layers & ~Plaies.CALQUE
		Decapitation._copier_instances(mi, copie)
		copie.visible = true
	for k in range(n, mis.size()):
		(mis[k] as MeshInstance3D).visible = false
		(mis[k] as MeshInstance3D).mesh = null
	# pièces accrochées aux os du morceau (épée dans la main coupée, bouclier) : elles partent avec lui
	for a in sq.get_children():
		if a is BoneAttachment3D and not String(a.name).begins_with("Plaies_") and dans.has(sq.find_bone((a as BoneAttachment3D).bone_name)):
			for piece in a.get_children():
				if piece is Node3D and not (piece is Decal) and not String(piece.name).begins_with("Capuchon"):
					var g := (piece as Node3D).global_transform
					piece.reparent(sk, false)
					(piece as Node3D).global_transform = g
					(slot["pieces"] as Array).append(piece)
	Jets.obtenir(modele)   # horloge de jeu des morceaux (et jets)
	slot["fin"] = horloge + duree
	slot["modele"] = modele
	return rb

## Membre gelé / en cendres : les armes tenues tombent (corps rigide simple, plus de main pour les tenir).
static func _lacher_pieces(sq: Skeleton3D, dans: Dictionary) -> void:
	var monde := sq.get_tree().current_scene if sq.get_tree().current_scene else sq.get_tree().root
	for a in sq.get_children():
		if a is BoneAttachment3D and not String(a.name).begins_with("Plaies_") and dans.has(sq.find_bone((a as BoneAttachment3D).bone_name)):
			for piece in a.get_children():
				if piece is Node3D and not (piece is Decal) and not String(piece.name).begins_with("Capuchon"):
					var g := (piece as Node3D).global_transform
					var rb := RigidBody3D.new()
					rb.name = "PieceLachee"
					rb.collision_layer = CALQUE_CADAVRES
					rb.collision_mask = 1
					rb.mass = 2.0
					var cs := CollisionShape3D.new()
					var b := BoxShape3D.new()
					b.size = Vector3(0.12, 0.12, 0.6)
					cs.shape = b
					rb.add_child(cs)
					monde.add_child(rb)
					rb.global_transform = Transform3D(g.basis.orthonormalized(), g.origin)
					piece.reparent(rb, true)
					rb.get_tree().create_timer(DUREE).timeout.connect(rb.queue_free)

# ------------------------------------------------------------------ boyaux (coupe en deux)

const BOYAUX := "res://assets/modeles/gore/boyaux.glb"
static var _boyaux := {}
static var _mat_boyaux := {}
## Pendants accrochés aux moignons : le gestionnaire des jets les garde pendus vers le bas (balancement amorti).
static var pendants: Array = []

static func _maillages_boyaux() -> Dictionary:
	if not _boyaux.is_empty():
		return _boyaux
	var sc := load(BOYAUX) as PackedScene
	if sc == null:
		return {}
	var n := sc.instantiate()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		_boyaux[String(mi.name)] = mi.mesh
	n.free()
	return _boyaux

static func mat_boyaux(matiere_chair: String) -> ShaderMaterial:
	if _mat_boyaux.has(matiere_chair):
		return _mat_boyaux[matiere_chair]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ps1_gore.gdshader")
	# draugr : chair desséchée telle que peinte ; vivant (bandit) : plus rouge et plus mouillé
	m.set_shader_parameter("teinte", Color(1, 1, 1) if matiere_chair == "draugr" else Color(1.25, 0.72, 0.68))
	m.set_shader_parameter("mouille", 0.45 if matiere_chair == "draugr" else 0.8)
	_mat_boyaux[matiere_chair] = m
	return m

## Boyaux de la coupe en deux : anses qui pendent du moignon (suivent le haut du corps, toujours pendues vers le bas) et un
## tas posé au sol sous la coupe ; bruit de chair qui se déchire.
static func boyaux(modele: Node3D, accroche: Node3D, t_moignon: Transform3D, origine: Vector3, matiere_chair: String, r_coupe: float) -> void:
	var b := _maillages_boyaux()
	if b.is_empty():
		return
	var m := mat_boyaux(matiere_chair)
	var k := r_coupe / 0.15
	var pend := MeshInstance3D.new()
	pend.name = "BoyauxPendants"
	pend.mesh = b.get("BoyauxPendants")
	pend.material_override = m
	pend.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	accroche.add_child(pend)
	pend.transform = t_moignon
	pend.set_meta("k", k)
	pend.set_meta("balance", Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)))
	pendants.append(pend)
	var r := Sang.sol_sous(modele, origine, 0.4, 2.5)
	if not r.is_empty():
		var tas := MeshInstance3D.new()
		tas.name = "BoyauxTas"
		tas.mesh = b.get("BoyauxTas")
		tas.material_override = m
		tas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Sang.gestion(modele).add_child(tas)
		var y: Vector3 = r["normal"]
		var x := y.cross(Vector3.FORWARD).normalized() if absf(y.z) < 0.9 else y.cross(Vector3.RIGHT).normalized()
		tas.global_transform = Transform3D(Basis(x, y, x.cross(y)).rotated(y, _rng.randf() * TAU).scaled(Vector3.ONE * k), r["position"] + y * 0.005)
		# il s'étale en tombant, puis disparaît avec les traces (même durée)
		tas.scale = Vector3(0.3, 0.3, 0.3) * k
		var tw := tas.create_tween()
		tw.tween_property(tas, "scale", Vector3.ONE * k, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_interval(Sang.DUREE_TRACE)
		tw.tween_property(tas, "scale", Vector3(0.05, 0.05, 0.05), 4.0)
		tw.tween_callback(tas.queue_free)
	RetourImpact.son(modele, "boyaux", origine, -2.0)

# ------------------------------------------------------------------ sorts : feu (carbonise), glace (membre gelé éclate)

## Effet de mort d'un sort : "feu" (corps carbonisé, parfois un membre en cendres), "glace" (un membre gelé éclate) ou "".
static func effet_sort(combat: CombatEnnemi, r: Dictionary) -> String:
	if combat == null or not profil_demembrable(combat.profil, true):
		return ""
	var i: Dictionary = r.get("info", {})
	var e := String(i.get("ecole", ""))
	var t := String(i.get("type", ""))
	if e == "feu" or t == "feu":
		return "feu"
	if e == "glace" or t == "glace" or t == "givre":
		return "glace"
	return ""

## Applique l'effet du sort à la mort (après le ragdoll). Feu : le corps noircit par taches (voile carbonisé), braises ;
## CHANCE_CENDRE d'un bras réduit en cendres. Glace : CHANCE_GLACE qu'un membre (bras, jambe, tête) éclate.
const CHANCE_CENDRE := 0.4
const CHANCE_GLACE := 0.6
static func appliquer_sort(modele: Node3D, effet: String, combat: CombatEnnemi, dir: Vector3) -> String:
	if modele == null or not modele.is_inside_tree():
		return ""
	var mat := matiere_de(combat.profil)
	var membres := membres_autorises(combat.profil)
	match effet:
		"feu":
			carboniser(modele)
			if niveau() > 0 and chance_forcee != 0.0 and _rng.randf() < (CHANCE_CENDRE if chance_forcee < 0.0 else chance_forcee):
				var m: String = membre_force if membre_force != "" else ["bras_l", "bras_r", "avantbras_l", "avantbras_r"].pick_random()
				if m in membres and trancher(modele, m, dir, combat.profil.couleur_sang, mat, "cendre") == null and not coupes_de(modele).has(m):
					return ""
				return m if m in membres else ""
		"glace":
			if niveau() > 0 and chance_forcee != 0.0 and _rng.randf() < (CHANCE_GLACE if chance_forcee < 0.0 else chance_forcee):
				var choix := ["bras_l", "bras_r", "jambe_l", "jambe_r", "avantbras_l", "avantbras_r", "mollet_l", "mollet_r"].filter(func(x: String) -> bool: return x in membres)
				var m: String = membre_force if membre_force != "" else (choix.pick_random() if not choix.is_empty() else "")
				if m != "" and m in membres:
					trancher(modele, m, dir, combat.profil.couleur_sang, mat, "glace")
					return m
	return ""

## Voile carbonisé (material_overlay, shaders/carbonise.gdshader) : taches de charbon qui gagnent le corps en 1,6 s, braises.
## Un maillage qui porte déjà un voile (feu d'ImpactCorps en cours) le reçoit dès que ce voile est retiré.
static var _mat_carbonise: ShaderMaterial
static func carboniser(modele: Node3D) -> void:
	if modele == null or modele.has_meta("carbonise"):
		return
	modele.set_meta("carbonise", true)
	if _mat_carbonise == null:
		_mat_carbonise = ShaderMaterial.new()
		_mat_carbonise.shader = preload("res://shaders/carbonise.gdshader")
		_mat_carbonise.resource_name = "carbonise"
	var mailles: Array = []
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Capuchon") or mi.name.begins_with("Boyaux"):
			continue
		mailles.append(mi)
	_poser_voile(modele, mailles, 12)
	var tw := modele.create_tween()
	tw.tween_method(func(v: float) -> void:
		for mi: MeshInstance3D in mailles:
			if is_instance_valid(mi) and mi.material_overlay == _mat_carbonise:
				mi.set_instance_shader_parameter("carbonise", v), 0.0, 1.0, 1.6)
	var centre := modele.global_position + Vector3.UP * 0.9
	for k in 3:
		tw.tween_callback(func() -> void:
			if is_instance_valid(modele) and modele.is_inside_tree():
				GerbePixels.emettre(modele, centre + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)), Vector3.UP, "braise", 1.2))
		tw.tween_interval(0.7)
	RetourImpact.son(modele, "carbonise", centre, -4.0)

static func _poser_voile(modele: Node3D, mailles: Array, essais: int) -> void:
	var reste: Array = []
	for mi: MeshInstance3D in mailles:
		if not is_instance_valid(mi):
			continue
		if mi.material_overlay == null:
			mi.material_overlay = _mat_carbonise
			mi.set_instance_shader_parameter("carbonise", 0.0)
		elif mi.material_overlay != _mat_carbonise:
			reste.append(mi)
	if not reste.is_empty() and essais > 0 and is_instance_valid(modele) and modele.is_inside_tree():
		modele.get_tree().create_timer(0.5).timeout.connect(func() -> void:
			_poser_voile(modele, reste, essais - 1)
			for mi: MeshInstance3D in reste:
				if is_instance_valid(mi) and mi.material_overlay == _mat_carbonise:
					mi.set_instance_shader_parameter("carbonise", 1.0))

## Allègement des gerbes tout près de la caméra (elles masquaient le corps) : 0,4 à moins de 1,8 m, 1 au-delà de 4 m.
static func attenuation_camera(n: Node, point: Vector3) -> float:
	var cam := n.get_viewport().get_camera_3d() if n != null and n.is_inside_tree() else null
	if cam == null:
		return 1.0
	return clampf(remap(cam.global_position.distance_to(point), 1.8, 4.0, 0.4, 1.0), 0.4, 1.0)

static func _sous_arbre(sq: Skeleton3D, os: int, garde: int, dans: Dictionary) -> void:
	if os == garde:
		return
	dans[os] = true
	for c in sq.get_bone_children(os):
		_sous_arbre(sq, c, garde, dans)

## Peau du morceau : B' = P_racine⁻¹ · P_os · B (pose du moment, repère de la racine) pour les os du morceau ; les autres
## attaches écrasent leurs sommets sur le point de coupe.
static func _peau_morceau(src: Skin, sq: Skeleton3D, dans: Dictionary, inv_racine: Transform3D, coupe_local: Vector3) -> Skin:
	var s := src.duplicate() as Skin
	var ecrase := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), coupe_local)
	for i in s.get_bind_count():
		var nom := String(s.get_bind_name(i))
		var os := sq.find_bone(nom) if nom != "" else s.get_bind_bone(i)
		s.set_bind_name(i, "Racine")
		s.set_bind_bone(i, 0)
		if os >= 0 and dans.has(os):
			s.set_bind_pose(i, inv_racine * sq.get_bone_global_pose(os) * src.get_bind_pose(i))
		else:
			s.set_bind_pose(i, ecrase)
	return s

## Accroche (BoneAttachment3D) d'un os : celle de Plaies si elle existe, sinon une neuve (une par os et par corps).
static func _accroche_os(modele: Node3D, sq: Skeleton3D, os: String) -> Node3D:
	var a := _accroche(modele, os)
	if a != null:
		return a
	var nom := "Moignon_" + os
	var b := sq.get_node_or_null(nom) as BoneAttachment3D
	if b == null:
		b = BoneAttachment3D.new()
		b.name = nom
		b.bone_name = os
		sq.add_child(b)
		var i := sq.find_bone(os)
		b.global_transform = sq.global_transform * sq.get_bone_global_pose(i)
	return b

static func _base_vers(axe: Vector3) -> Basis:
	return Decapitation._base_vers(axe)

# ------------------------------------------------------------------ pool des morceaux

static func _emplacement(modele: Node3D) -> Dictionary:
	_pool = _pool.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["rb"]))
	var t := horloge
	var choisi: Dictionary = {}
	for s in _pool:
		if float(s["fin"]) <= t:
			choisi = s
			break
	if choisi.is_empty() and _pool.size() < TAILLE_POOL:
		choisi = _creer_emplacement()
		_pool.append(choisi)
	if choisi.is_empty():
		var vieux := _pool[0]
		for s in _pool:
			if float(s["fin"]) < float(vieux["fin"]):
				vieux = s
		choisi = vieux
	_liberer(choisi)
	return choisi

## Prépare le pool à l'avance (apparition des ennemis) : aucun nœud créé à la première coupe.
static func prechauffer() -> void:
	while _pool.size() < TAILLE_POOL:
		_pool.append(_creer_emplacement())

static func _creer_emplacement() -> Dictionary:
	var rb := RigidBody3D.new()
	rb.name = "MorceauCoupe"
	rb.collision_layer = CALQUE_CADAVRES
	rb.collision_mask = 1
	rb.angular_damp = 1.6
	rb.linear_damp = 0.1
	rb.continuous_cd = true
	rb.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.95
	pm.bounce = 0.1
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	rb.add_child(cs)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	sk.add_bone("Racine")
	rb.add_child(sk)
	var mis: Array = []
	for i in MAILLAGES_MAX:
		var mi := MeshInstance3D.new()
		mi.name = "Maille%d" % i
		mi.custom_aabb = AABB(Vector3(-1.2, -1.2, -1.2), Vector3(2.4, 2.4, 2.4))
		mi.visible = false
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
		mis.append(mi)
	rb.freeze = true
	rb.visible = false
	rb.process_mode = Node.PROCESS_MODE_DISABLED
	return {"rb": rb, "cs": cs, "sk": sk, "mis": mis, "fin": 0.0, "pieces": [], "modele": null}

## Rend l'emplacement : morceau précédent effacé (capuchons, jets, pièces rapportées), corps rigide figé et caché.
static func _liberer(s: Dictionary) -> void:
	var rb: RigidBody3D = s["rb"]
	var sk: Skeleton3D = s["sk"]
	for p in s["pieces"]:
		if is_instance_valid(p):
			(p as Node).queue_free()
	s["pieces"] = []
	for c in sk.get_children():
		if not (c in (s["mis"] as Array)):
			sk.remove_child(c)   # sorti tout de suite : le capuchon suivant garde son nom
			c.queue_free()
	for mi: MeshInstance3D in s["mis"]:
		mi.visible = false
		mi.mesh = null
		mi.skin = null
	if rb.contact_monitor:
		for cn in rb.body_entered.get_connections():
			rb.body_entered.disconnect(cn["callable"])
		rb.contact_monitor = false
	rb.freeze = true
	rb.visible = false
	s["fin"] = 0.0

## Libère les morceaux dont le temps est écoulé (appelé par le jet du corps et par les tests ; sinon au prochain coup).
static func entretenir() -> void:
	var t := horloge
	for s in _pool:
		if is_instance_valid(s["rb"]) and float(s["fin"]) > 0.0 and float(s["fin"]) <= t:
			_liberer(s)

## Morceaux visibles (tests).
static func morceaux_actifs() -> int:
	var n := 0
	for s in _pool:
		if is_instance_valid(s["rb"]) and (s["rb"] as RigidBody3D).visible:
			n += 1
	return n

# ------------------------------------------------------------------ capuchons de moignon

## Capuchon : disque irrégulier (8 pans) en couleurs de sommet, texels nets : chair autour, lèvre sombre, os blanc au centre.
static func _capuchon(parent: Node3D, t: Transform3D, chairs: Array, rayon: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Capuchon"
	mi.mesh = maillage_capuchon()
	mi.material_override = mat_capuchon(chairs)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var r := rayon / maxf(parent.global_transform.basis.get_scale().x, 0.001)   # rayon en mètres, quelle que soit l'échelle du parent
	mi.transform = t * Transform3D(Basis.from_scale(Vector3(r, r, r)), Vector3.ZERO)
	return mi

## Maillage unitaire (rayon 1, normale +Y) : couleur de sommet = canal (R : chair, G : lèvre, B : os), teinté par le matériau.
static func maillage_capuchon() -> ArrayMesh:
	if _maillage_capuchon != null:
		return _maillage_capuchon
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pans := 8
	var r_ext := [1.0, 0.86, 1.08, 0.92, 1.0, 0.82, 1.1, 0.9]
	var c_chair := Color(1, 0, 0)
	var c_levre := Color(0, 1, 0)
	var c_os := Color(0, 0, 1)
	for k in pans:
		var a0 := TAU * k / pans
		var a1 := TAU * (k + 1) / pans
		var e0 := Vector3(cos(a0), 0, sin(a0)) * float(r_ext[k])
		var e1 := Vector3(cos(a1), 0, sin(a1)) * float(r_ext[(k + 1) % pans])
		var m0 := Vector3(cos(a0), 0.25, sin(a0)) * 0.62
		var m1 := Vector3(cos(a1), 0.25, sin(a1)) * 0.62
		var o0 := Vector3(cos(a0), 0, sin(a0)) * 0.22 + Vector3(0, 0.45, 0)
		var o1 := Vector3(cos(a1), 0, sin(a1)) * 0.22 + Vector3(0, 0.45, 0)
		# anneau extérieur : bord de chair (lèvre sombre) → chair
		_tri(st, [e0, e1, m1], [c_levre, c_levre, c_chair])
		_tri(st, [e0, m1, m0], [c_levre, c_chair, c_chair])
		# anneau intérieur : chair → os
		_tri(st, [m0, m1, o1], [c_chair, c_chair, c_os])
		_tri(st, [m0, o1, o0], [c_chair, c_os, c_os])
		# os : bout plat
		_tri(st, [o0, o1, Vector3(0, 0.5, 0)], [c_os, c_os, c_os])
	st.generate_normals()
	_maillage_capuchon = st.commit()
	return _maillage_capuchon

static func _tri(st: SurfaceTool, p: Array, c: Array) -> void:
	# sens : face vers +Y
	for k in [0, 2, 1]:
		st.set_color(c[k])
		st.add_vertex(p[k])

static func mat_capuchon(chairs: Array) -> ShaderMaterial:
	var cle := str(chairs)
	if _mats_capuchon.has(cle):
		return _mats_capuchon[cle]
	# couleurs PLATES par canal dominant (trois aplats francs, comme un texel PS1), sommets accrochés comme le corps
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ps1_gore.gdshader")
	m.set_shader_parameter("par_canal", true)
	m.set_shader_parameter("c_chair", chairs[0])
	m.set_shader_parameter("c_levre", chairs[1])
	m.set_shader_parameter("c_os", chairs[2])
	_mats_capuchon[cle] = m
	return m

## Traces de sang quand le morceau touche le sol (au plus 3).
static func _traces_morceau(rb: RigidBody3D, couleur: Color, sang := true) -> void:
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var reste := [3]
	rb.body_entered.connect(func(_b: Node) -> void:
		if reste[0] <= 0 or not is_instance_valid(rb) or not rb.visible:
			return
		if reste[0] == 3:
			RetourImpact.son(rb, "chute_membre", rb.global_position, -4.0 + minf(rb.linear_velocity.length(), 4.0))   # le membre tombe
		reste[0] -= 1
		if not sang:
			return
		var r := Sang.sol_sous(rb, rb.global_position, 0.3, 0.8)
		if not r.is_empty():
			Sang.trace(rb, r["position"], r["normal"], rb.linear_velocity, _rng.randf_range(0.2, 0.34), couleur, "giclure"))

# ------------------------------------------------------------------ jets des moignons (pool)

## Jets de sang des moignons : UN nœud par scène tient TAILLE émetteurs GPUParticles3D (gros pixels de GerbePixels, matières
## « sang_jet » / « draugr_jet ») ; chaque image, un jet actif suit son accroche (os du corps ou du morceau) et pulse au rythme
## du cœur (amount_ratio), quelques gouttes laissent des traces au sol. Il libère aussi les morceaux arrivés en fin de vie.
class Jets extends Node3D:
	const TAILLE := 6
	const PARTICULES := 48
	const BATTEMENT := 0.42
	static var _instance: Jets
	var _em: Array[GPUParticles3D] = []
	var _actifs: Array[Dictionary] = []   # un par émetteur : {} = libre
	var _entretien := 0.0

	static func obtenir(n: Node) -> Jets:
		if is_instance_valid(_instance) and _instance.is_inside_tree():
			return _instance
		if n == null or not n.is_inside_tree():
			return null
		var arbre := n.get_tree()
		var j := Jets.new()
		j.name = "JetsMoignons"
		(arbre.current_scene if arbre.current_scene else arbre.root).add_child(j)
		_instance = j
		return j

	static func lancer(accroche: Node3D, local: Transform3D, matiere: String, couleur: Color, duree: float, force := 1.0) -> void:
		var j := obtenir(accroche)
		if j != null:
			j._lancer(accroche, local, matiere, couleur, duree, force)

	func _ready() -> void:
		GerbePixels._preparer_ressources()
		for i in TAILLE:
			var p := GPUParticles3D.new()
			p.amount = PARTICULES
			p.lifetime = 0.75
			p.explosiveness = 0.0
			p.local_coords = false
			p.emitting = false
			p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.process_material = GerbePixels._pm("sang_jet", false)
			p.draw_pass_1 = GerbePixels._quad_mix
			add_child(p)
			_em.append(p)
			_actifs.append({})

	func _lancer(accroche: Node3D, local: Transform3D, matiere: String, couleur: Color, duree: float, force: float) -> void:
		var i := -1
		var plus_vieux := 0
		for k in TAILLE:
			if _actifs[k].is_empty():
				i = k
				break
			if float(_actifs[k]["t"]) > float(_actifs[plus_vieux]["t"]):
				plus_vieux = k
		if i < 0:
			i = plus_vieux
		var p := _em[i]
		var pm := GerbePixels._pm(matiere if GerbePixels.MATIERES.has(matiere) else "sang_jet", force >= 1.2)
		if p.process_material != pm:
			p.process_material = pm
		p.global_transform = (accroche.global_transform * local).orthonormalized()
		p.amount_ratio = 1.0
		p.restart()
		p.emitting = true
		_actifs[i] = {"acc": accroche, "local": local, "t": 0.0, "duree": duree, "force": force, "couleur": couleur, "gouttes": 0}

	## Boyaux pendants : toujours pendus vers le bas (monde), quel que soit le haut du corps couché, avec un balancement amorti.
	func _pendre(dt: float) -> void:
		var l: Array = Demembrement.pendants
		for k in range(l.size() - 1, -1, -1):
			var p: Variant = l[k]
			if not is_instance_valid(p) or not (p as Node3D).is_inside_tree():
				l.remove_at(k)
				continue
			var mi := p as MeshInstance3D
			var bal: Vector3 = mi.get_meta("balance")
			bal = bal.lerp(Vector3.ZERO, clampf(dt * 0.8, 0.0, 1.0))
			mi.set_meta("balance", bal)
			var t := Demembrement.horloge
			var bas := (Vector3.DOWN + Vector3(sin(t * 3.1) * bal.x, 0, cos(t * 2.7) * bal.z)).normalized()
			var b := Demembrement._base_vers(-bas)   # +Y du maillage = vers la coupe (les anses descendent le long de -Y)
			mi.global_basis = b.scaled(Vector3.ONE * float(mi.get_meta("k")))

	## Jets en cours (tests).
	func actifs() -> int:
		var n := 0
		for a in _actifs:
			if not a.is_empty():
				n += 1
		return n

	func _process(dt: float) -> void:
		Demembrement.horloge += dt
		_entretien -= dt
		if _entretien <= 0.0:
			_entretien = 0.25
			Demembrement.entretenir()
		_pendre(dt)
		for k in TAILLE:
			var a := _actifs[k]
			if a.is_empty():
				continue
			var p := _em[k]
			var acc: Node3D = a["acc"] if is_instance_valid(a["acc"]) else null
			a["t"] = float(a["t"]) + dt
			var t := float(a["t"])
			var d := float(a["duree"])
			if acc == null or not acc.is_inside_tree() or not acc.is_visible_in_tree() or t >= d:
				p.emitting = false
				_actifs[k] = {}
				continue
			p.global_transform = (acc.global_transform * (a["local"] as Transform3D)).orthonormalized()
			# battement : une poussée forte puis un filet, de plus en plus faible
			var phase := fmod(t, BATTEMENT) / BATTEMENT
			var usure := 1.0 - t / d * 0.75
			p.amount_ratio = clampf((1.0 if phase < 0.3 else 0.22) * usure * float(a["force"]), 0.05, 1.0)
			# gouttes au sol devant le jet (au plus 4 traces par jet)
			var nb := int(a["gouttes"])
			if nb < 4 and t > (nb + 0.6) * d / 4.5:
				a["gouttes"] = nb + 1
				var dj := p.global_transform.basis.y.normalized()
				var vers := p.global_position + Vector3(dj.x, 0, dj.z) * Demembrement._rng.randf_range(0.25, 0.8)
				var r := Sang.sol_sous(p, vers, 1.5, 3.0)
				if not r.is_empty():
					Sang.trace(p, r["position"], r["normal"], Vector3(dj.x, 0, dj.z), Demembrement._rng.randf_range(0.18, 0.32), a["couleur"], "giclure")
