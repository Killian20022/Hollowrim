class_name Prechargement
## Préchargement en tâche de fond des gros modèles (corps humains ~16 Mo et cheveux, ~0,5 s chacun à décoder) : les fils
## du moteur les lisent PENDANT que le thread principal génère le terrain, les arbres et le sol. Quand `Humain.creer`
## appelle `load()`, la ressource est déjà prête (sinon `load` attend la fin de la lecture en cours : jamais plus lent).
## Aucun effet sur le rendu : mêmes fichiers, même importeur. Lancé par l'autoload Fenetre (avant même la compilation de
## la scène) et par Monde (tests et captures, qui n'ont pas l'autoload actif) ; idempotent.
## personnages de base unifiés (kits de ~100 Ko) : préchargés seulement avec --persos-kit (voir Personnage.kit_actif)
const CHEMINS_KIT := ["res://assets/modeles/persos/kit_homme.glb", "res://assets/modeles/persos/kit_femme.glb"]
const CHEMINS := [
	"res://assets/modeles/humains/homme_vetu.glb",
	"res://assets/modeles/humains/cheveux/Hair_SimpleParted.gltf",
	"res://assets/modeles/humains/cheveux/Hair_Beard.gltf",
	"res://assets/modeles/humains/femme_vetue.glb",
	"res://assets/modeles/humains/cheveux/Hair_Long.gltf",
	"res://assets/modeles/humains/cheveux/Hair_Buns.gltf",
	"res://assets/modeles/humains/cheveux/Hair_Buzzed.gltf",
]
static var _lance := false

## `--sans-prechargement` : désactivé (comparaisons de mesure avant/après).
static func lancer() -> void:
	if _lance or OS.get_cmdline_user_args().has("--sans-prechargement"):
		return
	_lance = true
	for chemin: String in (CHEMINS_KIT + CHEMINS if Personnage.kit_actif() else CHEMINS):
		if ResourceLoader.exists(chemin):
			ResourceLoader.load_threaded_request(chemin)
