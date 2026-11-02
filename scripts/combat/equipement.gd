class_name Equipement
extends RefCounted
## Équipement des deux mains, séparément. Aujourd'hui : épée longue (main droite) + torche (main gauche, T pour la
## ranger). Prévu par la structure : épée + bouclier, épée + sort, épée seule, deux armes, arme à deux mains (libère
## la main gauche), main vide — il suffit d'une DonneesArme de la bonne catégorie.

signal change(main: String)

const EPEE_METAL := preload("res://data/armes/epee_metal.tres")
const EPEE_SKARNHOLT := preload("res://data/armes/epee_skarnholt.tres")
const TORCHE := preload("res://data/armes/torche.tres")
const MAIN_VIDE := preload("res://data/armes/main_vide.tres")

var main_droite: DonneesArme = EPEE_METAL
var main_gauche: DonneesArme = TORCHE
## Objet de la main gauche quand elle est « sortie » (T) : la torche aujourd'hui, un bouclier demain.
var gauche_rangee: DonneesArme = TORCHE

func equiper(main: String, donnees: DonneesArme) -> void:
	if donnees == null:
		donnees = MAIN_VIDE
	if main == "droite":
		if main_droite == donnees:
			return
		main_droite = donnees
		change.emit("droite")
		if donnees.deux_mains and main_gauche != MAIN_VIDE:
			main_gauche = MAIN_VIDE
			change.emit("gauche")
	else:
		if main_gauche == donnees or (main_droite.deux_mains and donnees != MAIN_VIDE):
			return
		main_gauche = donnees
		if donnees != MAIN_VIDE:
			gauche_rangee = donnees
		change.emit("gauche")

## Arme de la main droite selon l'inventaire : l'épée de Skarnholt (quête) remplace l'épée de métal. La hache de
## Kolbeinn se tient (inventaire, data/armes/hache_kolbeinn.tres) : elle ne renforce plus les autres armes.
func choisir_selon_inventaire(inventaire: Inventaire) -> void:
	if main_droite != EPEE_METAL and main_droite != EPEE_SKARNHOLT:
		return   # sort, main vide ou autre arme choisis par le joueur (magie : EquipementMains) : on n'y touche pas
	equiper("droite", EPEE_SKARNHOLT if inventaire.a("epee_skarnholt") else EPEE_METAL)

## Multiplicateur d'équipement des coups d'arme (nom historique : ancien bonus des trophées). Lot A RPG : la hache de
## Kolbeinn se TIENT (data/armes/hache_kolbeinn.tres, son ×1,25 est dans ses propres dégâts, comme Skarnholt) : plus de
## bonus « dans le sac ». Reste le bonus des objets portés (EquipementCorps → Progression.bonus) : degats_deux_mains si
## l'arme de droite est à deux mains, sinon degats_une_main. Signature inchangée (mains.gd l'appelle).
func bonus_trophee(_inventaire: Inventaire) -> float:
	var p := Progression.courante()
	if p == null:
		return 1.0
	return 1.0 + maxf(p.bonus("degats_deux_mains" if main_droite.deux_mains else "degats_une_main"), 0.0)

func gauche_sortie() -> bool:
	return main_gauche != MAIN_VIDE

## T : sortir / ranger l'objet de la main gauche (impossible avec une arme à deux mains).
func basculer_gauche() -> void:
	equiper("gauche", MAIN_VIDE if gauche_sortie() else gauche_rangee)
