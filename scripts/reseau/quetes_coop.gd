class_name QuetesCoop
extends Node
## LOT 5a — quêtes PARTAGÉES en réseau (enfant de Quetes ; inerte hors ligne). Décision : progression d'équipe, état par l'hôte, récompense à
## chacun, une quête acceptée par un joueur l'est pour tous.
##  - L'invité ne modifie JAMAIS son état de quêtes : signaler / avancer_index / echouer sont routés à l'hôte (évènement `quete_op`, avec le
##    contenu du sac de l'invité pour les conditions « objet:… »). L'hôte applique, puis diffuse l'état complet (`quete_etat`, coalescé à
##    l'image suivante) : index, évènements vus, dates du journal, échecs.
##  - L'invité qui reçoit l'état montre les annonces des étapes franchies et reçoit la récompense de fin de quête dans SON sac
##    (Quetes.appliquer_partage). Instantané de connexion : contributeur « quetes » de Rejoindre (sans récompense rejouée).
## Limite connue : une réplique de quête dite par un invité lit l'état avant le retour de l'hôte (la ligne « pendant » suit au dialogue suivant).

var quetes: Node
var _sale := false
var _vu_etat := 0

static func installer(q: Node) -> QuetesCoop:
	var n := QuetesCoop.new()
	n.name = "QuetesCoop"
	n.quetes = q
	q.add_child(n)
	return n

func _r() -> Node:
	return PauseCoop.R()

## Invité en ligne (l'hôte détient l'état).
func invite() -> bool:
	var r := _r()
	return r != null and r.est_en_ligne() and not r.est_hote()

func _ready() -> void:
	var r := _r()
	if r == null:
		return
	r.abonner("quete_op", Callable(self, "_sur_op"))
	r.abonner("quete_etat", Callable(self, "_sur_etat"))
	r.joueur_connecte.connect(func(id: int) -> void:
		if r.est_hote() and id != 1:
			_sale = true)
	var rj := get_node_or_null("/root/Rejoindre")
	if rj != null:
		rj.contributeur("quetes", Callable(quetes, "exporter_partage"), Callable(self, "_importer_instantane"))

func _exit_tree() -> void:
	var r := _r()
	if r != null:
		r.desabonner("quete_op", Callable(self, "_sur_op"))
		r.desabonner("quete_etat", Callable(self, "_sur_etat"))

## Invité : envoie l'opération à l'hôte (vrai = routée, l'appelant ne fait rien). Hôte / solo : faux, l'appelant applique.
func router(op: String, args: Array) -> bool:
	if not invite():
		return false
	var inv: Dictionary = quetes.joueur.inventaire.objets.duplicate() if quetes.joueur != null else {}
	_r().envoyer_evenement("quete_op", 0, {"op": op, "args": args, "inv": inv})
	return true

## Hôte : l'état a changé, à diffuser (à l'image suivante : plusieurs changements = un seul envoi).
func marquer() -> void:
	var r := _r()
	if r != null and r.est_en_ligne() and r.est_hote():
		_sale = true

func _process(_dt: float) -> void:
	if not _sale:
		return
	_sale = false
	var r := _r()
	if r != null and r.est_en_ligne() and r.est_hote() and r.joueurs().size() > 1:
		_vu_etat += 1
		r.envoyer_evenement("quete_etat", _vu_etat, quetes.exporter_partage())

## Hôte : une opération d'un invité (signaler, avancer, echouer) ; les conditions d'objet se jugent sur SON sac.
func _sur_op(_exp: int, _id: Variant, d: Variant) -> void:
	var r := _r()
	if r == null or not r.est_hote() or not (d is Dictionary):
		return
	quetes._objets_test = (d.get("inv", {}) as Dictionary) if d.get("inv") is Dictionary else {}
	var a: Array = d.get("args", [])
	match String(d.get("op", "")):
		"signaler":
			quetes.signaler(String(a[0]))
		"avancer":
			quetes.avancer_index(String(a[0]), int(a[1]))
		"echouer":
			quetes.echouer(String(a[0]))
	quetes._objets_test = {}

## Invité : état de l'hôte en direct.
func _sur_etat(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or not invite() or not (d is Dictionary):
		return
	quetes.appliquer_partage(d, true)

func _importer_instantane(d: Dictionary) -> void:
	var r := _r()
	if r != null and r.est_hote():
		return
	quetes.appliquer_partage(d, false)
