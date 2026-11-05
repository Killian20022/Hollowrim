extends Node
## Autoload « Lancement » : au démarrage du jeu, migration des sauvegardes de l'ancien nom, options du joueur
## (volumes par bus, sensibilité, champ de vision) et routage des sons vers les bus « Musique » / « Effets ».
## En mode outil (tests, captures : voir Jeu.mode_outil) rien n'est migré ni appliqué : sons et images restent comparables.

func _init() -> void:
	if Jeu.mode_outil():
		return
	# test des menus (--test-titre=…) : aucune migration, les vrais fichiers du joueur ne sont jamais lus ni copiés
	if Jeu.test_titre() == "":
		var copies := Jeu.migrer(Jeu.dossier_ancien(), OS.get_user_data_dir())
		if not copies.is_empty():
			print("%s : sauvegarde reprise de l'ancien dossier (%s)" % [Jeu.nom(), ", ".join(copies)])
	Jeu.charger_options()
	Touches.charger()   # touches du joueur (Options > Touches) appliquées à l'InputMap

func _ready() -> void:
	if Jeu.mode_outil():
		return
	if Jeu.sortie_directe():
		get_tree().auto_accept_quit = false   # croix de la fenêtre / Alt+F4 : sortie directe (voir Jeu.sortie_directe)
	Jeu.creer_bus()
	Jeu.appliquer_son()
	get_tree().node_added.connect(_noeud_ajoute)

## Chaque lecteur audio qui entre dans l'arbre (bus resté sur Master) : lecteurs du nœud Musique → Musique ; vent, feu et
## ambiances (générateurs, fichiers « ambiance_* ») → Ambiance ; sons d'interface (fichiers « ui_* ») → Interface ; le reste → Effets.
## Les sons qui choisissent déjà leur bus (combat, magie, pas) ne sont pas touchés.
func _noeud_ajoute(n: Node) -> void:
	if not (n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D):
		return
	if n.get("bus") != &"Master":
		return
	n.set("bus", Mixage.bus_de(n))

## Fermeture de la fenêtre (jeu exporté) : la notification atteint aussi le monde, qui sauvegarde ; on sort ensuite.
func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST and Jeu.sortie_directe() and not get_tree().auto_accept_quit:
		_sortir.call_deferred()

func _sortir() -> void:
	Jeu.quitter()
