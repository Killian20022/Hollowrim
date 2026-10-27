class_name ProfilImpact
extends Resource
## Sensation d'un coup qui porte : arrêt sur image, secousse, éclat rouge à l'écran, ralenti, quantité de sang, volume.
## Cinq profils : leger, moyen, lourd, critique, finisher (ProfilImpact.de(nom)) ; surcharge possible par data/combat/impact_<nom>.tres.

@export var nom := "leger"
## Arrêt sur image (s, temps réel).
@export var arret := 0.05
## Secousse de caméra du joueur (joueur.secousse, 0..1).
@export var secousse := 0.22
## Voile rouge plein écran (0..1) : réservé aux gros coups, morts brutales et finishers.
@export var eclat_rouge := 0.0
## Ralenti après l'arrêt (s) et son échelle de temps.
@export var ralenti := 0.0
@export var ralenti_echelle := 0.35
## Multiplicateur des giclées de sang / éclats.
@export var sang := 1.0
## Volume des sons d'impact (dB).
@export var volume_db := 0.0
## Éclair de l'ennemi touché (instance « eclair » des shaders de personnages).
@export var eclair := 0.9

const DOSSIER := "res://data/combat/impact_%s.tres"
const NOMS := ["leger", "moyen", "lourd", "critique", "finisher"]
static var _table := {}

static func de(nom_profil: String) -> ProfilImpact:
	if not _table.has(nom_profil):
		var chemin := DOSSIER % nom_profil
		var p: ProfilImpact = load(chemin) as ProfilImpact if ResourceLoader.exists(chemin) else null
		_table[nom_profil] = p if p != null else _defaut(nom_profil)
	return _table[nom_profil]

static func _defaut(n: String) -> ProfilImpact:
	var p := ProfilImpact.new()
	p.nom = n
	match n:
		"moyen":
			p.arret = 0.07
			p.secousse = 0.32
			p.sang = 1.4
			p.volume_db = 1.0
		"lourd":
			p.arret = 0.11
			p.secousse = 0.5
			p.sang = 2.2
			p.volume_db = 3.0
			p.eclair = 1.0
		"critique":
			p.arret = 0.14
			p.secousse = 0.62
			p.eclat_rouge = 0.16
			p.sang = 3.0
			p.volume_db = 4.0
			p.eclair = 1.0
		"finisher":
			p.arret = 0.2
			p.secousse = 0.85
			p.eclat_rouge = 0.32
			p.ralenti = 0.45
			p.ralenti_echelle = 0.3
			p.sang = 4.5
			p.volume_db = 5.0
			p.eclair = 1.0
	return p
