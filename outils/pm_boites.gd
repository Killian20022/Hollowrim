extends SceneTree
## props/maximum : boîtes (dimensions) de props q_* / pq_* (repérage des compositions).
func _init() -> void:
	for n in ["q_chariot","q_bucher","q_buche","q_rondin","q_tronc","q_souche","q_tente","q_feu_bois","q_hache_camp","q_couteau_camp","q_marmite_camp","q_viande","q_poisson","q_piege_ours","q_poutre_ronde","q_sac_debout","q_chou","q_navet","q_jarre","q_cuisse","q_lard","q_crane","q_pain","q_pomme","q_tapis","q_banniere_toile","q_hachette","q_planches_sol","q_champignon","q_oeuf","q_saucisse"]:
		var b := PropsQuaternius.boite(n)
		var mats := []
		for m in PropsQuaternius.morceaux(n, {}, false): mats.append(m[0])
		print("BOITE %s pos=%s taille=%s pq=%s mats=%s" % [n, b.position, b.size, PropsQuaternius.pq_de(n), mats])
	quit()
