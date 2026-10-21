extends Node
## Plein écran : F11 ou Alt+Entrée bascule entre fenêtre et plein écran.
## Le rendu interne (480x270 ou 640x360) est agrandi d'un facteur entier (×4 / ×3 en 1920×1080 : pixels nets) ;
## l'interface suit avec EchelleUi.
## Le choix est retenu dans user://fenetre.cfg et rétabli au lancement.

const FICHIER := "user://fenetre.cfg"

func _init() -> void:
	# lecture en tâche de fond des modèles d'humains pendant que la scène se compile (voir Prechargement)
	if not OS.get_cmdline_args().has("--script") and not OS.get_cmdline_args().has("-s"):
		Prechargement.lancer()

func _ready() -> void:
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
