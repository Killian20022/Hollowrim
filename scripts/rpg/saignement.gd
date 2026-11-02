class_name Saignement
extends Node
## Saignement posé par les perks (Progression.coup_porte : « saignement_une_main », « saignement_deux_mains ») : un nœud
## enfant « Saignement » de la cible inflige `reste` dégâts répartis sur la durée, par tics de TIC s, via
## Statuts.infliger (résistances et corruption appliquées, pas d'arrêt sur image ; le dernier point de vie passe par
## recevoir_coup). Un nouveau coup ajoute ses dégâts et rafraîchit la durée. Pas de saignement sur un profil sans sang
## (ProfilCible.sang) ni sur les squelettes (matière « os »).

const NOM := "Saignement"
const TIC := 0.5
const TYPE := "saignement"

var cible: Node3D
var reste := 0.0       ## dégâts encore à infliger
var duree := 0.0       ## s restantes
var source: Node = null
var total_inflige := 0.0
var _tic := 0.0

## Pose (ou renforce) un saignement de `total` dégâts sur `duree` s. Renvoie le nœud, ou null si la cible ne saigne pas.
static func poser(c: Node, total: float, d := 3.0, src: Node = null) -> Saignement:
	if total <= 0.0 or not c is Node3D or not is_instance_valid(c) or not saigne(c):
		return null
	var s := c.get_node_or_null(NOM) as Saignement
	if s == null:
		s = Saignement.new()
		s.name = NOM
		s.cible = c
		c.add_child(s)
	s.reste += total
	s.duree = maxf(s.duree, d)
	s.source = src
	return s

## Une cible saigne si elle n'est pas faite d'os (ProfilCible.matiere de son CombatEnnemi).
static func saigne(c: Node) -> bool:
	var combat = c.get("combat")
	if combat is CombatEnnemi and (combat as CombatEnnemi).profil != null:
		var pr: ProfilCible = (combat as CombatEnnemi).profil
		return pr.sang and pr.matiere != "os"
	return true

func _process(dt: float) -> void:
	if cible == null or not is_instance_valid(cible) or reste <= 0.0 or duree <= 0.0 or not _vivante():
		queue_free()
		return
	_tic += dt
	if _tic < TIC:
		return
	_tic -= TIC
	var part := clampf(TIC / maxf(duree, TIC), 0.0, 1.0)
	var q := reste * part
	reste -= q
	duree -= TIC
	var st := Statuts.de(cible)
	if st != null:
		total_inflige += st.infliger(q, TYPE, source)

func _vivante() -> bool:
	if cible.has_method("vivant"):
		return bool(cible.vivant())
	return cible.get("est_mort") != true
