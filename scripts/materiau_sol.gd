class_name MateriauSol
## Matériau du sol sous les pieds du joueur (neige, terre, pierre, bois, eau) et sons de pas correspondants.
## Aucune physique : on lit les systèmes qui connaissent déjà le sol.
##   - sous terre : crypte (tertre.dedans) et grotte (grotte_acces.dedans) → pierre ;
##   - intérieurs du village (Interieur.dedans) et quai sur pieux → bois ; rues pavées et pont → pierre ;
##   - eau peu profonde (nœuds du groupe « eaux ») → eau ;
##   - dehors, carte de matières de Sol : neige / croûte / piétinée → neige ; terre, aiguilles, mousse → terre ;
##     roche et glace → pierre ; hors de la zone cartographiée → neige (forêt enneigée).

const NEIGE := "neige"
const TERRE := "terre"
const PIERRE := "pierre"
const BOIS := "bois"
const EAU := "eau"
const TOUS := [NEIGE, TERRE, PIERRE, BOIS, EAU]

## Sons de pas (assets/sons) : le nom sans extension. La neige garde ses cinq enregistrements d'origine.
const PAS := {
	NEIGE: ["footstep_snow_000", "footstep_snow_001", "footstep_snow_002", "footstep_snow_003", "footstep_snow_004"],
	TERRE: ["pas_terre_00", "pas_terre_01", "pas_terre_02", "pas_terre_03", "pas_terre_04", "pas_terre_05", "pas_terre_06", "pas_terre_07"],
	PIERRE: ["pas_pierre_00", "pas_pierre_01", "pas_pierre_02", "pas_pierre_03", "pas_pierre_04"],
	BOIS: ["pas_bois_00", "pas_bois_01", "pas_bois_02", "pas_bois_03", "pas_bois_04"],
	EAU: ["pas_eau_00", "pas_eau_01", "pas_eau_02", "pas_eau_03"],
}
## Volume (dB) d'un pas de marche, par matériau (la neige sert de référence : -12).
const VOLUME := {NEIGE: -12.0, TERRE: -11.0, PIERRE: -11.0, BOIS: -10.0, EAU: -9.0}
const SAUT := ["saut_00", "saut_01", "saut_02"]

const QUAI_X := Vector2(29.0, 38.0)      # emprise du quai sur pieux (EauVillage.QUAI : 9 m × 2,25 m)
const QUAI_Z := Vector2(57.2, 59.5)
const QUAI_Y := 3.35

## Matériau du sol au point `pos` (monde). `monde` peut être null (hors de la scène de jeu : neige).
static func en(monde: Node, pos: Vector3) -> String:
	if monde != null:
		if _vrai(monde.get("tertre"), "dedans") or _vrai(monde.get("grotte_acces"), "dedans"):
			return PIERRE
		var village = monde.get("village")
		if village != null and village.get("interieurs") != null:
			for ip: Interieur in village.interieurs:
				if is_instance_valid(ip) and ip.is_inside_tree() and ip.dedans(ip.to_local(pos), 0.0) \
						and absf(pos.y - ip.global_position.y) < 3.0:
					return BOIS
	if _dans_eau(monde, pos):
		return EAU
	if pos.x > QUAI_X.x and pos.x < QUAI_X.y and pos.z > QUAI_Z.x and pos.z < QUAI_Z.y and absf(pos.y - QUAI_Y) < 1.2:
		return BOIS
	if RuesVillage.profondeur_pave(Vector2(pos.x, pos.z)) > -0.3:
		return PIERRE
	match Sol.matiere_en(pos.x, pos.z):
		Sol.TERRE, Sol.AIGUILLES, Sol.MOUSSE:
			return TERRE
		Sol.ROCHE, Sol.GLACE:
			return PIERRE
	return NEIGE

static func _vrai(n: Variant, prop: String) -> bool:
	return n != null and is_instance_valid(n) and bool(n.get(prop))

## Dans une mare ou une rivière peu profonde (le joueur ne nage pas : l'eau est toujours un gué).
static func _dans_eau(monde: Node, pos: Vector3) -> bool:
	if monde == null or not monde.is_inside_tree():
		return false
	for w in monde.get_tree().get_nodes_in_group("eaux"):
		if is_instance_valid(w) and w.has_method("contient") and w.contient(pos.x, pos.z):
			return true
	return false

## Un pas du joueur (marche ou course) sur le matériau `mat`.
static func pas(parent: Node, mat: String, court: bool) -> void:
	var v: float = VOLUME.get(mat, -12.0) + (4.0 if court else 0.0)
	Sons.jouer(parent, PAS[mat], v, 0.1, Mixage.EFFETS)

## Départ d'un saut : effort de botte, très discret.
static func saut(parent: Node) -> void:
	Sons.jouer(parent, SAUT, -16.0, 0.08, Mixage.EFFETS)

## Réception : le pas du matériau, plus grave et plus fort selon la vitesse de chute (m/s).
static func atterrissage(parent: Node, mat: String, vitesse: float) -> void:
	var force := clampf((vitesse - 3.0) / 9.0, 0.0, 1.0)
	Sons.jouer(parent, PAS[mat], VOLUME.get(mat, -12.0) + 2.0 + 6.0 * force, 0.05, Mixage.EFFETS, 0.82 - 0.12 * force)
