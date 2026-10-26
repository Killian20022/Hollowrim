extends Node
## Autoload « Lancement » : au démarrage du jeu, migration des sauvegardes de l'ancien nom, options du joueur
## (volumes par bus, sensibilité, champ de vision) et routage des sons vers les bus « Musique » / « Effets ».
## En mode outil (tests, captures : voir Jeu.mode_outil) rien n'est migré ni appliqué : sons et images restent comparables.

const MUSIQUE := preload("res://scripts/musique.gd")

func _init() -> void:
	if Jeu.mode_outil():
		return
	var copies := Jeu.migrer(Jeu.dossier_ancien(), OS.get_user_data_dir())
	if not copies.is_empty():
		print("%s : sauvegarde reprise de l'ancien dossier (%s)" % [Jeu.nom(), ", ".join(copies)])
	Jeu.charger_options()

func _ready() -> void:
	if Jeu.mode_outil():
		return
	Jeu.creer_bus()
	Jeu.appliquer_son()
	get_tree().node_added.connect(_noeud_ajoute)

## Chaque lecteur audio qui entre dans l'arbre : musique (lecteurs du nœud Musique) → bus Musique ; le reste → Effets.
func _noeud_ajoute(n: Node) -> void:
	if not (n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D):
		return
	if n.get("bus") != &"Master":
		return
	var p := n.get_parent()
	n.set("bus", &"Musique" if p != null and p.get_script() == MUSIQUE else &"Effets")
