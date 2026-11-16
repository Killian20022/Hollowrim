class_name ProtoMonde
extends Node
## Lot 1 (prototype) : un objet ramassable (premier arrivé) et une porte, synchronisés. L'HÔTE arbitre : l'invité DEMANDE
## (événements « ramasser_demande », « porte_demande »), l'hôte DÉCIDE et diffuse (« ramasser_ok », « porte_etat »).

const OBJET_ID := "potion_soin"
const POS_OBJET := Vector3(0.0, 0.25, 6.0)
const POS_PORTE := Vector3(-0.6, 0.0, 9.0)   # charnière ; le battant fait 1,2 m

var joueur: CharacterBody3D   # joueur local
var objet: Node3D             # null une fois pris
var objet_pris_par := 0       # peer_id du gagnant (0 = personne)
var porte_pivot: Node3D
var porte_corps: CollisionShape3D
var porte_ouverte := false
var _pris := false            # hôte : l'objet est déjà attribué

func _ready() -> void:
	name = "ProtoMonde"
	_creer_objet()
	_creer_porte()
	Reseau.abonner("ramasser_demande", _sur_ramasser_demande)
	Reseau.abonner("ramasser_ok", _sur_ramasser_ok)
	Reseau.abonner("porte_demande", _sur_porte_demande)
	Reseau.abonner("porte_etat", _sur_porte_etat)

func _boite(taille: Vector3, couleur: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	m.material_override = mat
	return m

func _creer_objet() -> void:
	objet = _boite(Vector3(0.25, 0.4, 0.25), Color(0.8, 0.15, 0.2))
	objet.name = "ObjetRamassable"
	objet.position = POS_OBJET
	add_child(objet)

func _creer_porte() -> void:
	porte_pivot = Node3D.new()
	porte_pivot.name = "Porte"
	porte_pivot.position = POS_PORTE
	add_child(porte_pivot)
	var corps := StaticBody3D.new()
	corps.position = Vector3(0.6, 1.1, 0.0)
	porte_pivot.add_child(corps)
	porte_corps = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 2.2, 0.15)
	porte_corps.shape = bs
	corps.add_child(porte_corps)
	corps.add_child(_boite(bs.size, Color(0.42, 0.28, 0.16)))

func _physics_process(_dt: float) -> void:
	if joueur == null or not joueur.est_local or not Input.is_action_just_pressed("interagir"):
		return
	var p := joueur.global_position
	if objet != null and p.distance_to(objet.global_position) < 2.0:
		demander_ramasser()
	elif p.distance_to(porte_pivot.global_position + Vector3(0.6, 0, 0)) < 2.5:
		demander_porte()

# --- objet ---------------------------------------------------------------------------------------------
func demander_ramasser() -> void:
	if Reseau.est_hote():
		_arbitrer_ramasser(Reseau.mon_id())
	else:
		Reseau.emettre("ramasser_demande", OBJET_ID, null, 1)

func _sur_ramasser_demande(expediteur: int, _id: Variant, _d: Variant) -> void:
	if Reseau.est_hote():
		_arbitrer_ramasser(expediteur)

func _arbitrer_ramasser(qui: int) -> void:
	if _pris:
		return   # déjà attribué : le second arrivé n'a rien
	_pris = true
	Reseau.emettre("ramasser_ok", OBJET_ID, qui)
	_sur_ramasser_ok(1, OBJET_ID, qui)   # l'évènement ne revient pas à l'émetteur : l'hôte l'applique aussi

func _sur_ramasser_ok(expediteur: int, id: Variant, qui: Variant) -> void:
	if expediteur != 1:
		return
	objet_pris_par = int(qui)
	if is_instance_valid(objet):
		objet.queue_free()
	objet = null
	if int(qui) == Reseau.mon_id() and joueur != null:
		joueur.inventaire.ajouter(String(id), 1)

func nb_objets_locaux() -> int:
	return 1 if (joueur != null and joueur.inventaire.a(OBJET_ID)) else 0

# --- porte ---------------------------------------------------------------------------------------------
func demander_porte() -> void:
	if Reseau.est_hote():
		_diffuser_porte(not porte_ouverte)
	else:
		Reseau.emettre("porte_demande", "porte", null, 1)

func _sur_porte_demande(_exp: int, _id: Variant, _d: Variant) -> void:
	if Reseau.est_hote():
		_diffuser_porte(not porte_ouverte)

func _diffuser_porte(ouverte: bool) -> void:
	Reseau.emettre("porte_etat", "porte", ouverte)
	_sur_porte_etat(1, "porte", ouverte)

func _sur_porte_etat(expediteur: int, _id: Variant, ouverte: Variant) -> void:
	if expediteur != 1:
		return
	porte_ouverte = bool(ouverte)
	porte_corps.set_deferred("disabled", porte_ouverte)
	create_tween().tween_property(porte_pivot, "rotation:y", -PI * 0.5 if porte_ouverte else 0.0, 0.4)
