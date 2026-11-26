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
	return racine

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
