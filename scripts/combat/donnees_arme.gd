class_name DonneesArme
extends Resource
## « WeaponData » : tout ce qui distingue un objet tenu en main (épée, torche, plus tard bouclier, sort, arme à deux
## mains, main vide). Une ressource .tres par objet dans data/armes/ : changer d'épée = changer de ressource, sans
## toucher au code (modèle, prise, pose de repos, tracé de lame, dégâts, coûts, rythme).
## Repère de l'objet (celui du .glb) : +Y le long de la lame / du manche, +X vers le tranchant, origine au pommeau.
## Valeurs et règles d'équilibrage : docs/COMBAT.md.

enum Categorie { VIDE, EPEE, TORCHE, BOUCLIER, SORT }

@export var id := ""
@export var nom := ""
@export var categorie: Categorie = Categorie.EPEE
## Arme à deux mains : la main gauche est libérée de tout autre objet (Equipement.equiper).
@export var deux_mains := false

@export_group("Modèle")
## Chemin du modèle (.glb ou .tscn). Vide : pas de modèle (main vide) ou objet construit par le code (torche).
@export_file("*.glb", "*.tscn") var modele := ""
## Point du modèle (le long de +Y) qui doit être au centre du poing fermé.
@export var milieu_poignee := 0.03
## Teinte et lueur de la lame (matériau « lame » du modèle) : Skarnholt dorée, lames enchantées plus tard.
@export var teinte := Color(1.3, 1.3, 1.38)
@export var emission := Color(0, 0, 0)

@export_group("Pose FPS de repos")
## Repère caméra (+X droite, +Y haut, -Z devant) : position de la poignée, direction de la lame, côté du tranchant.
## Main gauche : le côté X est mis en miroir automatiquement.
@export var repos_poignee := Vector3(0.34, -0.30, -0.44)
@export var repos_lame := Vector3(-0.147, 0.913, -0.38)
@export var repos_fil := Vector3(-0.55, 0.0, -1.0)
## Profil d'animation (ProfilsAnimation) : gestes d'attaque, de garde, de sprint.
@export var profil := "epee_longue"

@export_group("Dégâts")
@export var degats_leger := 14.0
@export var degats_lourd := 34.0
## Multiplicateur des dégâts lourds à pleine charge (plafond : pas de dégâts infinis).
@export var bonus_charge_max := 1.3
## Nombre maximal de cibles touchées par un même coup (1 = la lame s'arrête au premier corps).
@export var multi_cibles := 2
## Part des dégâts absorbée en garde (0,85 = 15 % passent).
@export var reduction_garde := 0.85
## Bruit d'impact sur un mur (« metal », « bois ») : choix du son et des étincelles.
@export var materiau_impact := "metal"

@export_group("Rythme et poids")
## Multiplicateur de vitesse des gestes (1 = épée longue standard ; > 1 plus vive).
@export var vitesse := 1.0
## Poids (kg) : inertie des mouvements passifs et du retour en garde.
@export var poids := 1.6

@export_group("Endurance")
@export var cout_leger := 8.0
@export var cout_lourd := 26.0
## Multiplicateur de la vigueur dépensée par coup bloqué.
@export var cout_garde := 1.0

@export_group("Tracé de lame")
## Segment tranchant dans le repère de l'objet : de la garde à la pointe.
@export var garde := Vector3(0, 0.10, 0)
@export var pointe := Vector3(0, 0.84, 0)
## Allonge de jeu au-delà de la pointe visible (m) : la portée effective égale celle des ennemis (draugr : 1,9 m).
@export var allonge := 0.45
## Points échantillonnés le long du segment (garde → pointe + allonge).
@export var points_trace := 5

func est_arme() -> bool:
	return categorie == Categorie.EPEE

## Points du tracé dans le repère de l'objet, de la garde à la pointe prolongée de l'allonge.
func points_lame() -> PackedVector3Array:
	var res := PackedVector3Array()
	var n := maxi(points_trace, 2)
	var bout := pointe + (pointe - garde).normalized() * allonge
	for i in n:
		res.append(garde.lerp(bout, float(i) / float(n - 1)))
	return res
