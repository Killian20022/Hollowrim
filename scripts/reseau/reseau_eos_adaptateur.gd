extends RefCounted
## ADAPTATEUR EOS : le SEUL fichier qui nomme directement l'API du plugin EOSG (HCredentials, HPlatform, HAuth, HLobbies, EOS).
## Chargé dynamiquement par ReseauTransportEOS uniquement quand le plugin est présent : sans plugin, ce script n'est jamais lu.
## Pas de class_name volontairement. Vérifié contre la source du plugin EOSG 2.3.1 (noms de classes, signatures, champs de
## CreateLobbyOptions, recherche par attributs) et chargé en Godot 4.7.2 (outils/test_eos_plugin.gd : faux identifiants = échec propre).
## Non exécuté de bout en bout : il faut un vrai compte Epic (voir docs/EOS_PAS_A_PAS.md).
## Chaque méthode renvoie "" si tout va bien, sinon un message d'erreur lisible.

const BUCKET := "hollowrim"
const CLE_CODE := "CODE"
const ESSAIS_RECHERCHE := 8      # recherches successives (indexation Epic différée)
const PAUSE_RECHERCHE := 1.5     # secondes entre deux recherches

var _salon = null   # HLobby

func preparer(cfg: Dictionary) -> String:
	var creds := HCredentials.new()
	creds.product_name = str(cfg.get("product_name", ""))
	creds.product_version = str(cfg.get("product_version", "1.0"))
	creds.product_id = str(cfg.get("product_id", ""))
	creds.sandbox_id = str(cfg.get("sandbox_id", ""))
	creds.deployment_id = str(cfg.get("deployment_id", ""))
	creds.client_id = str(cfg.get("client_id", ""))
	creds.client_secret = str(cfg.get("client_secret", ""))
	creds.encryption_key = str(cfg.get("encryption_key", ""))
	if not await HPlatform.setup_eos_async(creds):
		return "EOS : initialisation refusée (vérifier ProductId/SandboxId/DeploymentId/ClientId/ClientSecret dans eos.cfg)."
	var nom := str(cfg.get("nom_joueur", "")).strip_edges()
	if nom == "":
		nom = "Joueur"
	if not await HAuth.login_anonymous_async(nom):
		return "EOS : connexion anonyme (Device ID) refusée (vérifier l'accès réseau et que « Device ID » est autorisé dans le portail développeur, voir docs/EOS_PAS_A_PAS.md)."
	return ""

func creer_salon(code: String, max_joueurs: int) -> String:
	var o := EOS.Lobby.CreateLobbyOptions.new()
	o.bucket_id = BUCKET
	o.max_lobby_members = max_joueurs
	o.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	o.presence_enabled = false
	o.allow_invites = false
	var salon = await HLobbies.create_lobby_async(o)
	if salon == null:
		return "EOS : création du salon refusée."
	salon.add_attribute(CLE_CODE, code)
	salon.add_attribute("HOTE", HAuth.product_user_id)
	if not await salon.update_async():
		return "EOS : publication du code de salon refusée."
	_salon = salon
	return ""

## Renvoie {erreur: String, hote: String (ProductUserId du propriétaire)}.
## Le service de recherche d'Epic indexe un salon avec un léger retard (constaté en réel : 0 résultat dans la première
## seconde, puis trouvé) : on réessaie quelques fois avant de conclure que le code n'existe pas.
func trouver_salon(code: String) -> Dictionary:
	var trouves = null
	for essai in ESSAIS_RECHERCHE:
		trouves = await HLobbies.search_by_attribute_async([
			{"key": EOS.Lobby.SEARCH_BUCKET_ID, "value": BUCKET},
			{"key": CLE_CODE, "value": code}])
		if trouves == null:
			return {"erreur": "EOS : recherche du salon impossible (réseau ?)."}
		if not (trouves as Array).is_empty():
			break
		if essai < ESSAIS_RECHERCHE - 1:
			await Engine.get_main_loop().create_timer(PAUSE_RECHERCHE).timeout
	if (trouves as Array).is_empty():
		return {"erreur": "Aucun salon avec le code %s (vérifier le code, l'hôte doit avoir ouvert son salon)." % code}
	var s = trouves[0]
	if s.available_slots <= 0:
		return {"erreur": "Le salon %s est complet (4 joueurs maximum)." % code}
	var rejoint = await HLobbies.join_async(s)
	if rejoint == null:
		return {"erreur": "EOS : impossible de rejoindre le salon %s." % code}
	_salon = rejoint   # c'est CE salon-là qu'il faudra quitter (celui de la recherche n'est pas « rejoint »)
	return {"erreur": "", "hote": s.owner_product_user_id}

func quitter_salon() -> void:
	if _salon == null:
		return
	if _salon.is_owner():
		await _salon.destroy_async()
	else:
		await _salon.leave_async()
	_salon = null
