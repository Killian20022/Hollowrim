extends Node
## Autoload « Rejoindre » : instantané du monde pour un invité qui se connecte (lot 2a). Voir docs/reseau_lot2.md.
## Les systèmes branchent leurs exporter()/importer() via contributeur(). Hors ligne : inerte.

signal instantane_applique(noms: Array)

var _contrib := {}      # nom -> {exp: Callable, imp: Callable}
var _attente := {}      # nom -> données reçues avant l'enregistrement du contributeur

func _ready() -> void:
	Reseau.abonner("rejoindre_demande", _sur_demande)
	Reseau.abonner("rejoindre_instantane", _sur_instantane)
	Reseau.connexion_reussie.connect(demander)

func contributeur(nom: String, exporter: Callable, importer: Callable) -> void:
	_contrib[nom] = {"exp": exporter, "imp": importer}
	if _attente.has(nom):
		var d: Dictionary = _attente[nom]
		_attente.erase(nom)
		importer.call(d)
		instantane_applique.emit([nom])

func retirer_contributeur(nom: String) -> void:
	_contrib.erase(nom)
	_attente.erase(nom)

## Hôte : {nom: exporter()} de tous les contributeurs.
func instantane() -> Dictionary:
	var r := {}
	for nom in _contrib:
		var c: Callable = _contrib[nom]["exp"]
		if c.is_valid():
			r[nom] = c.call()
	return r

## Invité : (re)demande l'instantané à l'hôte (appelé automatiquement à la connexion).
func demander() -> void:
	if Reseau.est_en_ligne() and not Reseau.est_hote():
		Reseau.envoyer_evenement("rejoindre_demande", 0, null)

func appliquer(snap: Dictionary) -> void:
	var noms: Array = []
	for nom in snap:
		if _contrib.has(nom):
			var c: Callable = _contrib[nom]["imp"]
			if c.is_valid():
				c.call(snap[nom])
				noms.append(nom)
		else:
			_attente[nom] = snap[nom]
	if not noms.is_empty():
		instantane_applique.emit(noms)

func _sur_demande(expediteur: int, _id: Variant, _d: Variant) -> void:
	if not Reseau.est_hote():
		return
	var brut := var_to_bytes(instantane())
	Reseau.envoyer_evenement("rejoindre_instantane", brut.size(), brut.compress(FileAccess.COMPRESSION_ZSTD), expediteur)

func _sur_instantane(expediteur: int, taille: Variant, donnees: Variant) -> void:
	if expediteur != Reseau.ID_HOTE:
		return
	var brut: PackedByteArray = (donnees as PackedByteArray).decompress(int(taille), FileAccess.COMPRESSION_ZSTD)
	var snap: Variant = bytes_to_var(brut)
	if snap is Dictionary:
		appliquer(snap)
