class_name FinisherSubi
## Côté ENNEMI des finishers multiples (docs/DEGATS.md, « Finishers — API ») : ce qui se passe dans le corps pendant que le
## joueur joue son geste (mains._avancer_finisher, GestesDefense.FINISHERS). Partagé par draugr.gd et ennemi_base.gd :
##   ennemi.preparer_finisher(type, info)        l'ennemi se fige (plus d'IA, plus de déplacement), le joueur l'aligne
##   ennemi.finisher_contact(phase, info)        "pommeau" (coup au visage), "entree" (la lame entre et reste), "retrait"
##   ennemi.subir_finisher(categorie, info)      mort spéciale (inchangé ; info["finisher"] = type → chute adaptée)
## Gore (option Sang / gore) : tout passe par Sang / Plaies, qui respectent Sang.niveau() (0 : ni sang ni plaie).
## Squelettes, mannequin (profil.sang faux) : éclats d'os / copeaux au lieu du sang.

## Durée maximale d'un finisher tenu : au-delà, l'ennemi meurt quand même (le joueur a été interrompu).
const DUREE_MAX := 3.0

## Position monde d'un os du modèle (Vector3.INF s'il n'existe pas).
static func os_monde(modele: Node3D, nom: String) -> Vector3:
	if modele == null:
		return Vector3.INF
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return Vector3.INF
	var i := sq.find_bone(nom)
	if i < 0:
		return Vector3.INF
	return sq.global_transform * sq.get_bone_global_pose(i).origin

## Accroche (BoneAttachment3D préparé par Plaies) la plus proche d'un os nommé, sinon le modèle.
static func accroche(modele: Node3D, nom: String) -> Node3D:
	Plaies.preparer(modele)
	if modele != null and modele.has_meta("plaies_accroches"):
		for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
			if is_instance_valid(a) and a.bone_name == nom:
				return a
	return modele

## Jet pulsé qui sort de la plaie dans la direction monde `sens`, attaché à l'os (il suit le corps puis le ragdoll).
static func jet_plaie(modele: Node3D, os: String, point: Vector3, sens: Vector3, couleur: Color, duree: float) -> void:
	var a := accroche(modele, os)
	if a == null or not a.is_inside_tree():
		return
	var y := sens.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var b := Basis(x, y, x.cross(y)).orthonormalized()
	var inv := a.global_transform.affine_inverse()
	Sang.jet(a, Transform3D(inv.basis * b, inv * point), couleur, duree)

## Coup de pommeau au visage : la tête part en arrière, petite giclée (nez, bouche), son d'os.
static func pommeau(corps: Node3D, c: CombatEnnemi, modele: Node3D, info: Dictionary, joueur: Node) -> void:
	var tete := os_monde(modele, "Head")
	if tete == Vector3.INF:
		tete = corps.global_position + Vector3(0, c.hauteur * 0.9, 0)
	var dir: Vector3 = (tete - Vector3(info.get("origine", corps.global_position))).normalized()
	if c.profil.sang and Sang.actif():
		Sang.giclee(corps, tete, (dir + Vector3.UP * 0.4).normalized(), 0.9, c.profil.couleur_sang, false)
	else:
		Sang.eclats_matiere(corps, tete, dir, 0.8, c.profil.couleur_sang)
	RetourImpact.son(corps, "os", tete, 0.0, 0.9)
	RetourImpact.jouer(corps, ProfilImpact.de("moyen"), joueur)
	if c.reaction_os:
		c.reaction_os.frapper(dir, 0.75)

## La lame entre dans le torse et y reste : giclée vers le joueur, plaie d'entrée (et de sortie dans le dos), jet pulsé
## qui bat pendant toute la tenue, son de chair, cri, le buste se plie autour de la lame.
static func entree(corps: Node3D, c: CombatEnnemi, modele: Node3D, info: Dictionary, joueur: Node, tenue: float) -> void:
	var point: Vector3 = info.get("point", corps.global_position + Vector3(0, c.hauteur * 0.7, 0))
	var dir: Vector3 = Vector3(info.get("direction", -corps.global_transform.basis.z)).normalized()
	var os := String(info.get("os", "spine_03"))
	var vers_joueur := -dir
	# PAS vers la caméra (des gouttes à 30 cm de l'œil masqueraient tout) : de côté, en éventail, et vers le bas
	var cote := dir.cross(Vector3.UP)
	cote = cote.normalized() if cote.length() > 0.1 else Vector3.RIGHT
	if c.profil.sang and Sang.actif():
		Sang.giclee(corps, point, (cote + Vector3.UP * 0.35 + vers_joueur * 0.15).normalized(), 1.8, c.profil.couleur_sang)
		Sang.giclee(corps, point, (-cote + Vector3.DOWN * 0.2 + vers_joueur * 0.15).normalized(), 1.4, c.profil.couleur_sang, false)
		Sang.giclee(corps, point + dir * 0.3, (dir + Vector3.DOWN * 0.3).normalized(), 1.6, c.profil.couleur_sang)   # par le dos
		# jets pulsés : par la plaie d'entrée (de côté, le long du torse) et par la sortie dans le dos
		jet_plaie(modele, os, point, (cote * 0.8 + Vector3.UP * 0.25 + vers_joueur * 0.2).normalized(), c.profil.couleur_sang, tenue + 1.6)
		jet_plaie(modele, os, point, (-cote * 0.7 + Vector3.DOWN * 0.5).normalized(), c.profil.couleur_sang, tenue + 1.0)
		jet_plaie(modele, os, point + dir * 0.28, (dir + Vector3.DOWN * 0.4).normalized(), c.profil.couleur_sang, tenue + 0.8)
	else:
		Sang.eclats_matiere(corps, point, vers_joueur, 1.6, c.profil.couleur_sang if not c.profil.sang else Color(0.45, 0.42, 0.38))
	var haut := Vector3.UP.cross(dir).normalized() if absf(dir.y) < 0.9 else Vector3.RIGHT
	Plaies.ajouter(modele, point, vers_joueur, haut, 0.42, c.profil.couleur_sang, c.profil.matiere)
	Plaies.ajouter(modele, point + dir * 0.28, dir, haut, 0.36, c.profil.couleur_sang, c.profil.matiere)
	RetourImpact.son_impact(corps, c.profil.matiere, ProfilImpact.de("lourd"), point, false)
	RetourImpact.son(corps, "dechirure", point, -2.0)
	RetourImpact.cri(corps, "douleur", point, c.profil.matiere, c.profil.mort_vivant)
	RetourImpact.jouer(corps, ProfilImpact.de("critique"), joueur)
	if c.reaction_os:
		c.reaction_os.etourdi = false
		c.reaction_os.frapper(dir, 0.55)

## Retrait de la lame : giclée au retrait (le long de la lame, vers le joueur), flaque qui s'étale sous la plaie.
static func retrait(corps: Node3D, c: CombatEnnemi, modele: Node3D, info: Dictionary) -> void:
	var point: Vector3 = info.get("point", corps.global_position + Vector3(0, c.hauteur * 0.7, 0))
	var dir: Vector3 = Vector3(info.get("direction", -corps.global_transform.basis.z)).normalized()
	var cote := dir.cross(Vector3.UP)
	cote = cote.normalized() if cote.length() > 0.1 else Vector3.RIGHT
	if c.profil.sang and Sang.actif():
		# giclée au retrait : elle suit la lame qui sort (vers le joueur) mais part de côté et vers le bas
		Sang.giclee(corps, point, (-dir * 0.35 + cote * 0.7 + Vector3.UP * 0.1).normalized(), 3.0, c.profil.couleur_sang)
		Sang.giclee(corps, point, (-dir * 0.3 - cote * 0.5 + Vector3.DOWN * 0.6).normalized(), 2.2, c.profil.couleur_sang, false)
		var sol := Sang.sol_sous(corps, point)
		if not sol.is_empty():
			Sang.flaque(corps, sol["position"], c.profil.couleur_sang, 0.8, 2.5)
	else:
		Sang.eclats_matiere(corps, point, -dir, 1.2, c.profil.couleur_sang if not c.profil.sang else Color(0.45, 0.42, 0.38))
	RetourImpact.son(corps, "dechirure", point, 0.0, 0.85)
	if c.reaction_os:
		c.reaction_os.frapper(-dir, 0.35)

## Réglages de chute (ragdoll) d'un finisher selon son type : [force, montée, os touché]. Le corps se vide et s'effondre
## au retrait (faible impulsion, vers le bas), tombe en avant quand il est pris de dos.
static func chute(type: String, force_defaut: float) -> Array:
	match type:
		"plantee", "pommeau":
			return [35.0, -0.9, "spine_03", 1.0]    # vidé, il s'effondre sur place (genoux, puis à terre)
		"dos":
			return [110.0, -0.25, "spine_03", 1.0]   # en avant (loin du joueur)
		"plonge":
			return [40.0, -0.8, "spine_03", 1.0]
	return [force_defaut, 0.15, "spine_03", 1.0]
