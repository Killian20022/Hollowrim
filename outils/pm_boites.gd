extends SceneTree
## props/maximum : boîtes (dimensions) de props q_* / pq_* (repérage des compositions).
func _init() -> void:
	for n in ["q_bordure_1","q_bordure_2","q_tapis","pq_vase_4","pq_urne_brisee","pq_calice","pq_bougie_1","pq_bougie_2","q_pain","q_pomme","pq_tas_pieces","q_poutre_ronde","q_planches_sol","pq_lanterne_murale","q_chariot","q_tente","q_crane","pq_coffre","pq_urne","pq_vase_1","pq_vase_2","pq_vase_3","q_colonne_1","q_piedestal_1","q_piedestal_2","q_brique"]:
		var ok := PropsQuaternius.existe(n)
		print("BOITE %s existe=%s pos=%s taille=%s" % [n, ok, PropsQuaternius.boite(n).position if ok else Vector3.ZERO, PropsQuaternius.boite(n).size if ok else Vector3.ZERO])
	quit()
