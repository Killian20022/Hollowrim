extends SceneTree
## Test du compteur d'IPS (option « Afficher les IPS ») : autoload présent, caché par défaut, visible et rempli une fois l'option active.
func _initialize() -> void:
	await process_frame
	var c := root.get_node_or_null("CompteurIps")
	var ok := c != null
	print("TEST ", "OK" if ok else "ECHEC", "  autoload CompteurIps présent")
	if ok:
		Jeu.regler("affichage", "afficher_ips", false, false)
		for i in 40: await process_frame
		var cache_ok: bool = not c.visible
		print("TEST ", "OK" if cache_ok else "ECHEC", "  caché quand l'option est coupée")
		Jeu.regler("affichage", "afficher_ips", true, false)
		await create_timer(0.8).timeout
		var lab: Label = c.get_node("Ips")
		var vis_ok: bool = c.visible and lab.text.ends_with("IPS")
		print("TEST ", "OK" if vis_ok else "ECHEC", "  visible avec l'option : « ", lab.text, " »")
		Jeu.regler("affichage", "afficher_ips", false, false)
		ok = cache_ok and vis_ok
	print("TEST COMPTEUR IPS : ", "OK" if ok else "ECHEC")
	quit(0 if ok else 1)
