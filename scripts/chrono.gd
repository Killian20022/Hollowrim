class_name Chrono
## Chronomètre de chargement, actif seulement avec `--chrono` (outils/mesure_chargement.sh) : `Chrono.marque("étape")`
## affiche le temps écoulé depuis la marque précédente. Sans `--chrono`, ne fait rien.
static var actif := false
static var _t := 0
static var _debut := 0

static func demarre() -> void:
	actif = OS.get_cmdline_user_args().has("--chrono")
	_t = Time.get_ticks_usec()
	_debut = _t
	if actif:
		print("CHRONO %-26s %7.1f ms" % ["moteur + scene (avant _ready)", _t / 1000.0])

## Total depuis le début de `_ready` du monde.
static func total() -> void:
	if actif:
		print("CHRONO %-26s %7.1f ms" % ["TOTAL _ready", (Time.get_ticks_usec() - _debut) / 1000.0])

static func marque(etape: String) -> void:
	if not actif:
		return
	var t := Time.get_ticks_usec()
	print("CHRONO %-26s %7.1f ms" % [etape, (t - _t) / 1000.0])
	_t = Time.get_ticks_usec()
