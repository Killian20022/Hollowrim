class_name JoueurBase
## MODÈLES DU JOUEUR (chantier joueur_base, 2026-11-26) : l'homme et la femme « de base » choisis au début d'une nouvelle partie
## (modèles fournis par l'utilisateur, Jeux/references/joueur_base/). Chaîne Blender : sources_blender/scripts/joueur_base.py
## (copie de face de la planche Tripo, décimation 11 k tris, atlas 256 px cuit, squelette des humains ajusté au corps, pose A -> T).
## Même squelette que les humains (65 os de homme_vetu.glb) : mêmes clips (Humain.bibliotheque()), PiedsAuSol, Ragdoll, coups 3e
## personne (CorpsCoupsTps), mains (CorpsMainsTps), armures portées (ArmureVisible : pièces nommées comme la tenue du héros, « peau »,
## « cheveux » (Hair_Long_*), « tunique », « pantalon », « bottes »).
##   JoueurBase.creer("homme" | "femme") -> Node3D     (contrat d'Humain.creer : Skeleton3D, « Animations », ragdoll)
## Ancien héros (HerosSkarnholt, garde amélioré) : --heros-ancien (corps_joueur.gd).

const SEXES := ["homme", "femme"]
const DEFAUT := "homme"
const MODELES := {
	"homme": "res://assets/modeles/joueur/joueur_homme.glb",
	"femme": "res://assets/modeles/joueur/joueur_femme.glb",
}
## Poings (passe 3) : centre et axes de la fusée tenue par chaque main, écrits par la chaîne Blender (repère du modèle au repos).
const POINGS := {
	"homme": "res://assets/modeles/joueur/joueur_homme_poings.gd",
	"femme": "res://assets/modeles/joueur/joueur_femme_poings.gd",
}
## Prise d'arme (corps_joueur.PRISE) : le poing serre l'arme à POING_ARME du repère le long de la lame (milieu de la poignée).
const POING_ARME := 0.04
## Hauteur du bassin des humains au repos (homme_vetu.glb) : les clips n'ont qu'une piste de POSITION, celle de « pelvis », animée
## pour ce corps-là ; Skeleton3D.motion_scale la ramène à la taille du modèle (sinon le corps flotte au-dessus de ses pieds).
const BASSIN_HUMAINS := 0.949
## Teinte de peau des bras à la 1re personne (moyenne de la peau de l'atlas, voir teinte_peau()).
static var _scenes := {}
## --posture-clip : sans la correction de posture des jambes (le clip tel quel, pour comparer)
static var sans_posture := OS.get_cmdline_user_args().has("--posture-clip")
static var _peau := {}

static func valide(sexe: String) -> String:
	return sexe if sexe in SEXES else DEFAUT

static func creer(sexe := DEFAUT) -> Node3D:
	sexe = valide(sexe)
	if not _scenes.has(sexe):
		_scenes[sexe] = load(MODELES[sexe])
	var racine: Node3D = (_scenes[sexe] as PackedScene).instantiate()
	racine.name = "Joueur" + sexe.capitalize()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var p := sq.find_bone("pelvis")
	sq.motion_scale = sq.get_bone_global_rest(p).origin.y / BASSIN_HUMAINS
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				mi.set_surface_override_material(s, GuerrierNordique.materiau(tex, false, false, true, "joueur_" + sexe))
		mi.extra_cull_margin = 0.5
		if String(mi.name) == "cheveux":
			mi.name = "Hair_Long_joueur"     # ArmureVisible : cheveux cachés sous un casque
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	if not sans_posture:
		PostureJoueur.equiper(sq, ap)     # repos accroupis des clips humains redressés (jambes seules), voir posture_joueur.gd
	racine.set_meta("apparence", sexe)
	sq.set_meta("apparence", sexe)
	for c: String in ["l", "r"]:
		var t := prise(sq, sexe, c)
		if t != Transform3D():
			# main droite : repère d'arme (PRISE) ; main gauche : centre du poing (torche, bouclier : corps_joueur._prise_gauche)
			sq.set_meta("prise_" + c, t * Transform3D(Basis(), Vector3(0, -POING_ARME, 0)) if c == "r" else t)
	if AJUSTEMENT_ARMURE.has(sexe) and not OS.get_cmdline_user_args().has("--armure-non-ajustee"):   # (comparaison avant / après)
		sq.set_meta("ajustement_armure", AJUSTEMENT_ARMURE[sexe])
	return racine

## ARMURES AJUSTÉES AU CORPS (passe 2) : les pièces portées (ArmureVisible) sont faites pour le corps d'homme (liaisons par nom d'os,
## taille du héros) ; sur la femme elles étaient trop massives. Par os, une mise à l'échelle autour de l'os, appliquée aux liaisons
## (bind poses) du skin de la pièce : « m » = axes du MODÈLE (x largeur, y hauteur, z profondeur ; os du tronc), « o » = axes de l'OS
## (y le long de l'os, x / z son épaisseur ; membres). Rapports mesurés femme / homme (outils/mesure_corps_joueur.gd : sections du tronc,
## rayons des membres, longueurs d'os), arrondis et lissés d'un os au voisin ; épaules et taille un peu plus fines encore (silhouette).
## L'homme : rien (référence d'ajustement des armures).
const AJUSTEMENT_ARMURE := {
	"femme": {
		"pelvis": ["m", Vector3(0.90, 0.94, 0.88)],
		"spine_01": ["m", Vector3(0.86, 0.94, 0.88)],
		"spine_02": ["m", Vector3(0.82, 0.94, 0.82)],
		"spine_03": ["m", Vector3(0.82, 0.94, 0.84)],
		"neck_01": ["m", Vector3(0.84, 0.94, 0.90)],
		"Head": ["m", Vector3(0.93, 0.93, 0.93)],
		"clavicle": ["o", Vector3(0.84, 0.90, 0.84)],
		"upperarm": ["o", Vector3(0.78, 0.94, 0.78)],
		"lowerarm": ["o", Vector3(0.74, 0.94, 0.74)],
		"hand": ["o", Vector3(0.76, 0.86, 0.76)],
		"thigh": ["o", Vector3(0.88, 0.94, 0.88)],
		"calf": ["o", Vector3(0.92, 0.94, 0.92)],
		"foot": ["o", Vector3(0.90, 0.94, 0.90)],
		"ball": ["o", Vector3(0.90, 0.94, 0.90)],
	},
}

## Repère de la fusée tenue par la main `cote` ("l" | "r") dans le repère de l'os hand_<cote> : origine au centre du poing fermé,
## Y le long de la fusée (du petit doigt vers le pouce : la lame d'une épée), Z vers les doigts (même convention que
## corps_joueur._prise_gauche). Transform3D() si le modèle n'a pas ses poings.
static func prise(sq: Skeleton3D, sexe: String, cote: String) -> Transform3D:
	var chemin: String = POINGS.get(sexe, "")
	if chemin == "" or not ResourceLoader.exists(chemin):
		return Transform3D()
	var d: Dictionary = (load(chemin) as GDScript).get_script_constant_map()["POINGS"].get(cote, {})
	var i := sq.find_bone("hand_" + cote)
	if d.is_empty() or i < 0:
		return Transform3D()
	var axe: Vector3 = (d["axe"] as Vector3).normalized()
	var z: Vector3 = d["doigts"]
	z = (z - axe * z.dot(axe)).normalized()
	var b := Basis(axe.cross(z), axe, z)
	return sq.get_bone_global_rest(i).affine_inverse() * Transform3D(b, d["centre"])

## Pièce d'armure portée (MeshInstance3D skinné, enfant du squelette) : liaisons recalculées pour le corps (voir AJUSTEMENT_ARMURE).
## Sans effet sur un squelette qui n'en demande pas (homme, ancien héros, PNJ).
static func ajuster_armure(mi: MeshInstance3D, sq: Skeleton3D) -> void:
	if mi == null or sq == null or mi.skin == null or not sq.has_meta("ajustement_armure"):
		return
	var aj: Dictionary = sq.get_meta("ajustement_armure")
	var skin := mi.skin.duplicate() as Skin
	for b in skin.get_bind_count():
		var nom := String(skin.get_bind_name(b))
		var i := sq.find_bone(nom) if nom != "" else skin.get_bind_bone(b)
		if i < 0:
			continue
		nom = sq.get_bone_name(i)
		var cle := nom.trim_suffix("_l").trim_suffix("_r")
		if not aj.has(cle):
			continue
		var mode: String = aj[cle][0]
		var d: Vector3 = aj[cle][1]
		var m := Basis.from_scale(d)
		if mode == "m":
			var r := sq.get_bone_global_rest(i).basis.orthonormalized()
			m = r.inverse() * m * r
		skin.set_bind_pose(b, Transform3D(m, Vector3.ZERO) * skin.get_bind_pose(b))
	mi.skin = skin

## Teinte moyenne de la peau du modèle (atlas, faces de la pièce « peau » sous le cou = mains) : pour accorder les bras 1re personne.
static func teinte_peau(sexe := DEFAUT) -> Color:
	sexe = valide(sexe)
	if _peau.has(sexe):
		return _peau[sexe]
	var c := Color(0.62, 0.45, 0.33)
	var m := creer(sexe)
	var mi := m.find_child("peau", true, false) as MeshInstance3D
	if mi != null:
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		var img := src.albedo_texture.get_image() if src != null and src.albedo_texture != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			var a := mi.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var somme := Color(0, 0, 0, 0)
			var n := 0
			for i in v.size():
				if v[i].y < 1.2 and absf(v[i].x) > 0.5:
					somme += img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
					n += 1
			if n > 0:
				c = somme / float(n)
	m.free()
	_peau[sexe] = c
	return c
