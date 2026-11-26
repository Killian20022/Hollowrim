class_name GardesArmes
## GARDE / BLOCAGE de TOUTES les armes (branche combat/gardes_toutes_armes, 2026-11-26). Retour utilisateur : « en défense,
## l'avant-bras vertical et le poignet horizontal, ça fait un angle de 90 degrés, ça n'a aucun sens, la hache devrait être de
## biais pour bloquer un coup » ; « fais la même chose pour tout quand on se défend, même sur l'épée ».
## Les tenues de défense (noms LOGIQUES de mains.gd / GestesDefense : garde, encaisse, parade) sont remplacées, par famille, par
## les clips de bras_gardes.tres (sources_blender/scripts/gestes_gardes.py) : captures Mixamo de blocage (« great sword
## blocking (2) » tenu, « great sword impact » pour le coup bloqué, « great sword blocking » pour la parade) retargetées comme
## les coups v6, POIGNET NEUTRE verrouillé, arme de BIAIS (40-50° de la verticale) par rotation rigide du bras entier.
##   g1 : épées, sabres, dagues, épées longues ; gl : haches, masses, marteaux à une main ; g2 : toute arme à deux mains
##   (claymore, hybrides : la main gauche reste en IK sur le manche, mains._poser_deux_mains) ; gg : grand marteau (bras plus loin,
##   manche plus couché : sa tête restait hors cadre).
## Garde brisée et bouclier (GestesBouclier, bras gauche) : inchangés. mains._installer_arme fusionne ces tenues par-dessus celles
## du profil (ProfilsAnimation / GestesLourds « tenues »).

## --gardes-anciennes : les anciennes tenues (poses écrites à une main, garde_2m) pour comparer.
static var anciennes := "--gardes-anciennes" in OS.get_cmdline_user_args()

const FAMILLES := {
	"g1": {"garde": "g1_garde", "encaisse": "g1_encaisse", "parade": "g1_parade"},
	"gl": {"garde": "gl_garde", "encaisse": "gl_encaisse", "parade": "gl_parade"},
	"g2": {"garde": "g2_garde", "encaisse": "g2_encaisse", "parade": "g2_parade"},
	"gg": {"garde": "gg_garde", "encaisse": "gg_encaisse", "parade": "gg_parade"},
}

## Famille de garde de l'arme (« » : pas d'arme tenue à la main droite — main vide, sort, bouclier — : tenues inchangées).
static func famille(arme: DonneesArme) -> String:
	if arme == null or anciennes or arme.modele == "" or arme.famille == "bouclier":
		return ""
	if arme.deux_mains:
		return "gg" if arme.profil == "grand_marteau" else "g2"
	if GestesLourds.est_lourd(arme.profil):
		return "gl"
	return "g1"

## Tenues du profil + celles de la garde de l'arme.
static func tenues(base: Dictionary, arme: DonneesArme) -> Dictionary:
	var f := famille(arme)
	if f == "":
		return base
	var t := base.duplicate()
	t.merge(FAMILLES[f], true)
	return t
