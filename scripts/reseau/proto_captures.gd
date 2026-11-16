extends Node
## Lot 1 : scénario de CAPTURES du prototype coop (outils/captures_coop.sh). Lancé par « --coop-captures=<dossier> » (rendu réel, fenêtre hors écran).
## L'hôte déroule des moments clés (événement « cap_moment ») ; à chaque moment, CHAQUE instance place son joueur local (position imposée,
## regard vers la cible) puis enregistre <dossier>/<moment>_<hote|invite>.png après un temps de stabilisation (interpolation réseau comprise).
## Positions : hôte à x > 0, invité à x < 0 (côte à côte) ; l'objet est en (0, 0.25, 6), la porte en (-0.6, 0, 9).

# moment -> [attente avant capture (s), pos hôte, pos invité, cible regardée par les deux (null = l'autre joueur, "draugr" = le draugr), tangage (rad), action de l'hôte]
const MOMENTS := [
	["avatar", 2.0, Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), "autre", 0.0, ""],
	["draugr", 3.0, Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), "draugr", 0.0, ""],
	["objet_avant", 2.0, Vector3(0.7, 0, 3.4), Vector3(-0.7, 0, 3.4), "objet", -0.30, ""],
	["objet_apres", 2.0, Vector3(0.7, 0, 3.4), Vector3(-0.7, 0, 3.4), "objet", -0.30, "ramasser"],
	["porte_avant", 2.0, Vector3(0.9, 0, 6.8), Vector3(-1.9, 0, 6.8), "porte", 0.0, ""],
	["porte_apres", 2.0, Vector3(0.9, 0, 6.8), Vector3(-1.9, 0, 6.8), "porte", 0.0, "porte"],
]

var coop: ProtoCoop
var dossier := ""
var _t := 0.0
var _i := -1            # moment en cours
var _t_moment := 0.0
var _capture_faite := true
var _fini := false

func _ready() -> void:
	coop.joueur.vie = 1.0e6   # le draugr frappe : ne pas mourir pendant les captures
	coop.joueur.vie_max = 1.0e6
	DirAccess.make_dir_recursive_absolute(dossier)
	ReseauLieux.reseau().abonner("cap_moment", _sur_moment)
	ReseauLieux.reseau().abonner("cap_fin", func(e: int, _a: Variant, _b: Variant) -> void: if e == 1: _quitter())

func _physics_process(dt: float) -> void:
	if _fini:
		return
	_t += dt
	if _t > 90.0:
		print("CAPTURES ECHEC délai dépassé")
		_quitter()
		return
	if _i >= 0:
		_t_moment += dt
		_placer()
		if not _capture_faite and _t_moment >= float(MOMENTS[_i][1]):
			_capture_faite = true
			_capturer()
	if coop.est_hote:
		if _i < 0 and coop.avatars.size() >= 1 and _t > 4.0:
			_aller(0)
		elif _i >= 0 and _capture_faite and _t_moment > float(MOMENTS[_i][1]) + 1.2:
			if _i + 1 < MOMENTS.size():
				_aller(_i + 1)
			else:
				_fini = true
				ReseauLieux.reseau().emettre("cap_fin", 0, null)
				await get_tree().create_timer(1.0).timeout
				_quitter()

func _aller(n: int) -> void:
	ReseauLieux.reseau().emettre("cap_moment", n, null)
	_sur_moment(1, n, null)   # l'évènement ne revient pas à l'émetteur

func _sur_moment(expediteur: int, n: Variant, _d: Variant) -> void:
	if expediteur != 1:
		return
	_i = int(n)
	_t_moment = 0.0
	_capture_faite = false
	if coop.est_hote:
		match String(MOMENTS[_i][6]):
			"ramasser":
				coop.monde.demander_ramasser()
			"porte":
				coop.monde.demander_porte()

## Position imposée du joueur local, regard vers la cible du moment.
func _placer() -> void:
	var m: Array = MOMENTS[_i]
	var j := coop.joueur
	var moi: Vector3 = m[2] if coop.est_hote else m[3]
	var autre: Vector3 = m[3] if coop.est_hote else m[2]
	var cible: Vector3
	match String(m[4]):
		"autre":
			cible = autre
		"draugr":
			cible = coop.draugr.global_position if is_instance_valid(coop.draugr) else Vector3(3.2, 0, -3.6)
		"objet":
			cible = ProtoMonde.POS_OBJET
		_:
			cible = ProtoMonde.POS_PORTE + Vector3(0.6, 0, 0)
	var d := cible - moi
	j.global_position = moi
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = float(m[5])

func _capturer() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var f := "%s/%s_%s.png" % [dossier, String(MOMENTS[_i][0]), "hote" if coop.est_hote else "invite"]
	var err := img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size(), " ", error_string(err))

func _quitter() -> void:
	_fini = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
