extends Node
## Plein écran : F11 ou Alt+Entrée bascule entre fenêtre et plein écran.
## Le rendu interne (480x270 ou 640x360) est agrandi d'un facteur entier (×4 / ×3 en 1920×1080 : pixels nets) ;
## l'interface suit avec EchelleUi.
## Le choix est retenu dans user://fenetre.cfg et rétabli au lancement.

const FICHIER := "user://fenetre.cfg"
const HORS_ECRAN := Vector2i(-32000, -32000)

func _init() -> void:
	# --hors-ecran (ajouté par godot_slot.sh aux lancements des agents) : la fenêtre rend
	# normalement mais hors de l'écran, pour ne jamais rester figée devant l'utilisateur
	if OS.get_cmdline_user_args().has("--hors-ecran") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_position(HORS_ECRAN)
	# lecture en tâche de fond des modèles d'humains pendant que la scène se compile (voir Prechargement)
	if not OS.get_cmdline_args().has("--script") and not OS.get_cmdline_args().has("-s"):
		Prechargement.lancer()

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--hors-ecran") and DisplayServer.get_name() != "headless":
		_tenir_hors_ecran()
	# ni en headless ni pendant les captures/tests (leurs images doivent rester comparables)
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().size() > 0:
		return
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) == OK and cfg.get_value("fenetre", "plein_ecran", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		basculer()
		get_viewport().set_input_as_handled()

func basculer() -> void:
	var plein := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if plein else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("fenetre", "plein_ecran", plein)
	cfg.save(FICHIER)

## Godot recentre la fenêtre après les autoloads (taille imposée par window_*_override) :
## on la renvoie hors écran pendant les premières images.
func _tenir_hors_ecran() -> void:
	for i in 120:
		if DisplayServer.window_get_position() != HORS_ECRAN:
			DisplayServer.window_set_position(HORS_ECRAN)
		await get_tree().process_frame
