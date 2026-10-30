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
## Arme à deux mains : la main gauche est libérée de tout autre objet (Equipement.equiper) et vient tenir la poignée sous la
## main droite (mains._poser_deux_mains, IK) ; profil d'animation « deux_mains » (famille générique, clips bras_2mains.tres).
@export var deux_mains := false
## Deux mains : distance (m, le long de la fusée) du centre du poing droit au centre du poing gauche, vers le pommeau
## (largeur d'un poing ≈ 9 cm + un peu de jeu). Le poing gauche ne descend pas sous `fusee_bas` (bas de la fusée, repère du modèle).
@export var ecart_mains := 0.095
@export var fusee_bas := -0.2
## Deux mains : rotation de la main gauche autour de la fusée (degrés) et pôle de son coude (repère caméra).
@export var rotation_main_gauche := 0.0
@export var coude_gauche_2m := Vector3(-0.35, -1.0, 0.15)

@export_group("Modèle")
## Chemin du modèle (.glb ou .tscn). Vide : pas de modèle (main vide) ou objet construit par le code (torche).
@export_file("*.glb", "*.tscn") var modele := ""
## Point du modèle (le long de +Y) qui doit être au centre du poing fermé.
@export var milieu_poignee := 0.03
## Matériaux PS1 posés sur le modèle, par nom de matériau Blender : « joueur » (mains._habiller, épée nordique)
## ou « epees_longues » (EpeesLongues.habiller : les 5 épées longues de la planche).
@export var habillage := "joueur"
## Nom du matériau de la lame (teinte, lueur de charge) ; la lame du joueur en reçoit une copie à lui.
@export var materiau_lame := "lame"
## Teinte et lueur de la lame : Skarnholt dorée, lames enchantées plus tard. Teinte d'alpha nul = celle du modèle.
@export var teinte := Color(0, 0, 0, 0)
@export var emission := Color(0, 0, 0)
## Lire `garde`, `pointe` (et `prise`, centre du poing droit → milieu_poignee) dans les nœuds vides du modèle quand il en a
## (épées longues, hybrides) : le tracé et la prise suivent le modèle.
@export var reperes_du_modele := true

@export_group("Pose FPS de repos")
## Repère caméra (+X droite, +Y haut, -Z devant) : position de la poignée, direction de la lame, côté du tranchant.
## Main gauche : le côté X est mis en miroir automatiquement.
@export var repos_poignee := Vector3(0.27, -0.24, -0.34)
@export var repos_lame := Vector3(-0.3, 0.7, -0.65)
@export var repos_fil := Vector3(-0.9, 0.0, -0.6)
## Pôle du coude (IK, repère caméra) : écarté, haut et en arrière, l'avant-bras reste presque horizontal et le poignet
## peut incliner la lame vers l'avant-gauche.
@export var repos_coude := Vector3(0.7, 0.1, 0.4)
## Déviation latérale maximale du poignet (degrés, orientation_main.gd) : 40° laissent la lame partir à ~35° de la
## verticale à l'écran, comme sur la planche.
@export var deviation_poignet := 40.0
## Profil d'animation (ProfilsAnimation) : gestes d'attaque, de garde, de sprint.
@export var profil := "epee_longue"

@export_group("Dégâts")
@export var degats_leger := 14.0
@export var degats_lourd := 34.0
## Multiplicateur des dégâts lourds à pleine charge (plafond : pas de dégâts infinis).
@export var bonus_charge_max := 1.3
## Nombre maximal de cibles touchées par un même coup (les suivantes sont traversées sans dégâts).
@export var multi_cibles := 2
## Part des dégâts absorbée en garde (0,85 = 15 % passent).
@export var reduction_garde := 0.85
## Type de dégâts transmis aux cibles (info["type"]) : « tranchant » ; plus tard contondant, feu, glace, magique.
@export var type_degats := "tranchant"
## Force de déséquilibre (stagger) transmise aux cibles (info["stagger"]), coup léger / lourd (×(1 + charge×0,5)).
@export var desequilibre_leger := 0.3
@export var desequilibre_lourd := 0.7
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

@export_group("Garde")
## Cône couvert par la garde levée (degrés, devant le joueur) : 120 à l'épée, plus large au bouclier.
@export var angle_garde := 120.0
## Recul du joueur quand un coup est bloqué (m/s, poussé à l'opposé de l'attaquant) : 0 = aucun.
@export var recul_garde := 0.0
## Part de la posture de l'attaquant retirée par une PARADE PARFAITE (CombatEnnemi.subir_parade) : 0,45 à l'épée ;
## le coup de bouclier déséquilibre davantage.
@export var posture_parade := 0.45
## Sons d'un coup bloqué / paré (catégories de RetourImpact.BANQUE) : vide = « metal_blocage » / « parade_parfaite ».
## Bouclier : « bois » (planches) ; le fer de l'umbo sonne en dessous.
@export var son_garde := ""

@export_group("Profil de jeu")
## Profil de gameplay (docs/COMBAT.md, « Profils des 5 épées ») : le MATÉRIAU ne fixe rien tout seul, chaque valeur se
## règle ici. Une ligne de description pour l'équilibrage et le HUD.
@export_multiline var description := ""
## Multiplicateur de la durée de préparation (armé + tension tenue) des coups, en plus de `vitesse` : < 1 part plus vite.
@export var preparation := 1.0
## Multiplicateur de la récupération (suivi + retour en garde) : > 1 laisse le joueur plus longtemps ouvert.
@export var recuperation := 1.0
## Effet élémentaire de la lame (sans sort) : statut posé à la cible quand le coup porte (« brulure », « gel », « choc »,
## « corruption », voir Statuts) et dégâts de l'élément ajoutés (× résistance de la cible au type `element_type` :
## « feu », « glace », « electricite », « tenebres »). Vide : aucun. Une lame enchantée (magie) remplace ce statut.
@export var element := ""
@export var element_type := ""
@export var element_degats := 0.0
@export var element_duree := 3.0
@export var element_puissance := 1.0
## L'effet élémentaire seulement sur les coups lourds (et la contre-attaque).
@export var element_lourd_seulement := false
## Sons des fouettés (catégories de RetourImpact.BANQUE ; vide = « fouette_leger » / « fouette_lourd ») et hauteur (1 = normale).
@export var son_fouette := ""
@export var son_fouette_lourd := ""
@export var hauteur_son := 1.0

@export_group("Tracé de lame")
## Segment tranchant dans le repère de l'objet : de la garde à la pointe.
@export var garde := Vector3(0, 0.10, 0)
@export var pointe := Vector3(0, 0.84, 0)
## Allonge de jeu au-delà de la pointe visible (m) : la portée effective égale celle des ennemis (draugr : 1,9 m).
@export var allonge := 0.45
## Points échantillonnés le long du segment (garde → pointe + allonge).
@export var points_trace := 5
## Portée de jeu depuis l'œil (m) : les coups sont dessinés EN ESPACE ÉCRAN (la lame balaie l'écran en travers, à
## 0,5-1 m de la caméra) ; le tracé projette chaque point de la lame vu à l'écran le long de son rayon de visée, de
## `portee_garde` (garde) à `portee` (pointe) : ce que la lame couvre à l'écran, dans la portée, est touché.
@export var portee := 2.0
@export var portee_garde := 0.6

@export_group("Traînée de lame")
## Couleur de la traînée pixel (ruban garde → pointe pendant la frappe) ; `couleur_trainee_coeur` : le bord vif côté
## pointe. Blanc acier, or, rubis, verre, obsidienne.
@export var couleur_trainee := Color(0.5, 0.64, 0.9)
@export var couleur_trainee_coeur := Color(0.94, 0.97, 1.0)

@export_group("Catalogue")
## Famille de l'arme (CatalogueArmes.FAMILLES) : une_main, epee_longue, deux_mains, dague, masse, marteau, bouclier ; vide =
## objet qui n'est pas une arme (torche, main vide, main qui incante). Stats de base de chaque famille et variations par
## matériau : data/armes/catalogue_armes.json. Tenue à deux mains : `deux_mains` (famille deux_mains, grand marteau).
@export var famille := ""
## Matériau (acier, fer, or, verre, rubis, saphir, obsidienne, bois) : multiplicateurs du catalogue, élément de la lame.
@export var materiau := ""

func est_arme() -> bool:
	return categorie == Categorie.EPEE

## Points du tracé dans le repère de l'objet, de la garde à la pointe prolongée de l'allonge. `g` / `p` remplacent
## garde / pointe (repères lus dans le modèle).
func points_lame(g := Vector3.INF, p := Vector3.INF) -> PackedVector3Array:
	var a := garde if g == Vector3.INF else g
	var b := pointe if p == Vector3.INF else p
	var res := PackedVector3Array()
	var n := maxi(points_trace, 2)
	var bout := b + (b - a).normalized() * allonge
	for i in n:
		res.append(a.lerp(bout, float(i) / float(n - 1)))
	return res
