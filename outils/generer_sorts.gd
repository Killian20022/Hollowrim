extends SceneTree
## Écrit data/sorts/<id>.tres depuis la table ci-dessous (valeurs de départ, docs/MAGIE.md). Les .tres sont ensuite la
## source : relancer ce script ÉCRASE les réglages faits à la main.
##   godot --headless --path . --script res://outils/generer_sorts.gd

const T := DonneesSort.Type
const P := DonneesSort.Portee

func _init() -> void:
	var sorts := [
		# --- FEU : destruction, chaleur, chaos
		{"id": "jet_flammes", "nom": "Jet de flammes", "ecole": "feu", "type": T.CANALISE, "portee_mode": P.JET, "cout_par_seconde": 13.0,
			"degats": 20.0, "type_degats": "feu", "statut": "brulure", "duree_statut": 3.0, "puissance_statut": 4.0, "stagger": 7.0,
			"portee": 5.5, "largeur": 0.9, "seuil_interruption": 10.0, "traverse": 3, "description": "Flammes continues à courte portée ; enflamme.",
			"double": {"degats": 2.0, "cout": 2.2, "largeur": 1.8, "portee": 1.25, "puissance_statut": 1.5, "duree_statut": 1.3, "stagger": 1.6}},
		{"id": "boule_feu", "nom": "Boule de feu", "ecole": "feu", "type": T.CHARGE, "portee_mode": P.PROJECTILE, "cout": 24.0, "temps_charge": 0.8,
			"recuperation": 0.35, "recharge": 0.5, "degats": 34.0, "degats_charge_min": 0.55, "type_degats": "feu", "statut": "brulure",
			"duree_statut": 3.0, "puissance_statut": 4.0, "stagger": 22.0, "rayon": 2.2, "vitesse": 24.0, "forme": "boule", "profil": "poing",
			"description": "Maintenir pour charger ; explose à l'impact.",
			"double": {"degats": 2.2, "cout": 2.4, "rayon": 1.6, "stagger": 1.8, "vitesse": 1.1, "duree_statut": 1.4}},
		{"id": "explosion_incendiaire", "nom": "Explosion incendiaire", "ecole": "feu", "type": T.ZONE, "portee_mode": P.ZONE_VISEE, "cout": 42.0,
			"cout_charge_min": 1.0, "incantation": 0.2, "temps_charge": 1.0, "recuperation": 0.5, "recharge": 4.0, "degats": 38.0,
			"type_degats": "feu", "statut": "brulure", "duree_statut": 4.0, "puissance_statut": 6.0, "stagger": 30.0, "portee": 14.0, "rayon": 3.0,
			"profil": "levee", "description": "Embrase le sol au point visé (charger pour plus de force).",
			"double": {"degats": 2.0, "cout": 2.3, "rayon": 1.5, "duree_statut": 1.5, "stagger": 1.5}},
		# --- GLACE : contrôle, lenteur, protection
		{"id": "eclat_glace", "nom": "Éclat de glace", "ecole": "glace", "type": T.RAPIDE, "portee_mode": P.PROJECTILE, "cout": 8.0,
			"recuperation": 0.22, "recharge": 0.3, "degats": 8.0, "type_degats": "glace", "statut": "gel", "duree_statut": 2.5,
			"puissance_statut": 0.25, "stagger": 5.0, "vitesse": 34.0, "forme": "eclat", "nombre": 3, "ecart": 4.0,
			"description": "Trois éclats rapides ; ralentit.",
			"double": {"degats": 1.6, "cout": 2.2, "nombre_plus": 3, "puissance_statut": 1.6, "duree_statut": 1.4, "stagger": 1.5}},
		{"id": "lance_givre", "nom": "Lance de givre", "ecole": "glace", "type": T.CHARGE, "portee_mode": P.PROJECTILE, "cout": 26.0, "temps_charge": 0.9,
			"recuperation": 0.4, "recharge": 0.8, "degats": 40.0, "type_degats": "glace", "statut": "gel", "duree_statut": 3.0,
			"puissance_statut": 0.45, "stagger": 26.0, "vitesse": 30.0, "forme": "lance", "traverse": 1, "profil": "poing",
			"description": "Maintenir pour charger ; transperce une cible.",
			"double": {"degats": 2.1, "cout": 2.4, "traverse_plus": 2, "nombre_plus": 2, "ecart": 1.0, "puissance_statut": 1.5, "duree_statut": 1.4, "stagger": 1.6}},
		{"id": "souffle_givre", "nom": "Souffle de givre", "ecole": "glace", "type": T.CANALISE, "portee_mode": P.JET, "cout_par_seconde": 12.0,
			"degats": 16.0, "type_degats": "glace", "statut": "gel", "duree_statut": 2.0, "puissance_statut": 0.35, "stagger": 6.0,
			"portee": 8.0, "largeur": 0.9, "seuil_interruption": 10.0, "traverse": 3, "description": "Souffle glacé continu ; ralentit la cible.",
			"double": {"degats": 2.0, "cout": 2.2, "largeur": 1.6, "portee": 1.2, "puissance_statut": 1.4, "duree_statut": 1.3, "stagger": 1.6}},
		{"id": "nova_gelee", "nom": "Nova gelée", "ecole": "glace", "type": T.ZONE, "portee_mode": P.ZONE_SOI, "cout": 40.0, "incantation": 0.25,
			"recuperation": 0.5, "recharge": 5.0, "degats": 20.0, "type_degats": "glace", "statut": "gel", "duree_statut": 4.0,
			"puissance_statut": 0.55, "stagger": 18.0, "rayon": 4.5, "profil": "levee", "description": "Onde de glace autour de soi ; fige presque.",
			"double": {"degats": 1.9, "cout": 2.2, "rayon": 1.5, "puissance_statut": 1.4, "duree_statut": 1.5}},
		# --- ÉLECTRICITÉ : vitesse, précision, puissance
		{"id": "arc_electrique", "nom": "Arc électrique", "ecole": "electricite", "type": T.CANALISE, "portee_mode": P.JET, "cout_par_seconde": 14.0,
			"degats": 24.0, "type_degats": "electricite", "statut": "choc", "duree_statut": 0.5, "puissance_statut": 0.45, "stagger": 9.0,
			"portee": 9.0, "largeur": 0.5, "rebonds": 0, "distance_rebond": 4.0, "attenuation_rebond": 0.6, "seuil_interruption": 10.0,
			"description": "Arc continu précis ; secoue la cible.",
			"double": {"degats": 2.0, "cout": 2.2, "portee": 1.3, "rebonds_plus": 2, "stagger": 1.6}},
		{"id": "chaine_eclairs", "nom": "Chaîne d'éclairs", "ecole": "electricite", "type": T.RAPIDE, "portee_mode": P.CHAINE, "cout": 22.0,
			"incantation": 0.18, "recuperation": 0.35, "recharge": 1.0, "degats": 24.0, "type_degats": "electricite", "statut": "choc",
			"duree_statut": 0.5, "puissance_statut": 0.4, "stagger": 14.0, "portee": 20.0, "rebonds": 3, "distance_rebond": 6.5,
			"attenuation_rebond": 0.75, "description": "Éclair instantané qui saute de cible en cible.",
			"double": {"degats": 1.9, "cout": 2.2, "rebonds_plus": 3, "portee": 1.2, "stagger": 1.5}},
		{"id": "tempete_statique", "nom": "Tempête statique", "ecole": "electricite", "type": T.ZONE, "portee_mode": P.ZONE_VISEE, "cout": 52.0,
			"cout_charge_min": 1.0, "incantation": 0.3, "temps_charge": 0.6, "recuperation": 0.5, "recharge": 9.0, "degats": 9.0,
			"degats_charge_min": 0.8, "type_degats": "electricite", "statut": "choc", "duree_statut": 0.4, "puissance_statut": 0.3, "stagger": 6.0,
			"portee": 16.0, "rayon": 4.0, "duree_zone": 5.0, "intervalle_zone": 0.5, "profil": "levee",
			"description": "Champ d'éclairs persistant au point visé.",
			"double": {"degats": 1.8, "cout": 2.2, "rayon": 1.4, "duree_zone": 1.3}},
		# --- TÉNÈBRES : vie, corruption, manipulation
		{"id": "trait_ombre", "nom": "Trait d'ombre", "ecole": "tenebres", "type": T.RAPIDE, "portee_mode": P.PROJECTILE, "cout": 10.0,
			"recuperation": 0.25, "recharge": 0.35, "degats": 15.0, "type_degats": "tenebres", "statut": "corruption", "duree_statut": 5.0,
			"puissance_statut": 0.15, "stagger": 8.0, "vitesse": 30.0, "forme": "trait", "description": "Trait rapide qui corrompt.",
			"double": {"degats": 2.1, "cout": 2.3, "duree_statut": 1.6, "puissance_statut": 1.5, "stagger": 1.5}},
		{"id": "drain_vie", "nom": "Drain de vie", "ecole": "tenebres", "type": T.CANALISE, "portee_mode": P.JET, "cout_par_seconde": 11.0,
			"degats": 13.0, "type_degats": "tenebres", "statut": "corruption", "duree_statut": 3.0, "puissance_statut": 0.1, "drain": 0.6,
			"stagger": 4.0, "portee": 8.0, "largeur": 0.6, "distance_rebond": 4.0, "attenuation_rebond": 0.7, "seuil_interruption": 10.0,
			"description": "Aspire la vie de la cible et vous soigne.",
			"double": {"degats": 1.9, "drain": 1.3, "cout": 2.2, "duree_statut": 1.6, "rebonds_plus": 1, "portee": 1.2}},
		{"id": "explosion_obscure", "nom": "Explosion obscure", "ecole": "tenebres", "type": T.ZONE, "portee_mode": P.ZONE_VISEE, "cout": 48.0,
			"cout_charge_min": 1.0, "incantation": 0.2, "temps_charge": 1.0, "recuperation": 0.5, "recharge": 6.0, "degats": 34.0,
			"type_degats": "tenebres", "statut": "corruption", "duree_statut": 6.0, "puissance_statut": 0.2, "stagger": 24.0, "portee": 14.0,
			"rayon": 3.5, "attraction": 3.5, "profil": "levee", "description": "Vortex obscur qui attire puis éclate.",
			"double": {"degats": 2.0, "cout": 2.3, "rayon": 1.5, "duree_statut": 1.6, "attraction": 1.5}},
		# --- full mage : soin et protection
		{"id": "soin", "nom": "Soin", "ecole": "soin", "type": T.CANALISE, "portee_mode": P.SOI, "cout_par_seconde": 12.0, "incantation": 0.2,
			"degats": 0.0, "soin": 16.0, "profil": "soi", "description": "Soigne tant que la main est tenue.",
			"double": {"soin": 1.9, "cout": 2.0}},
		{"id": "protection", "nom": "Protection", "ecole": "protection", "type": T.CANALISE, "portee_mode": P.SOI, "cout_par_seconde": 5.0,
			"incantation": 0.16, "degats": 0.0, "reduction_physique": 0.6, "reduction_magique": 0.85, "mana_par_absorbe": 0.4, "cone": 120.0,
			"profil": "soi", "seuil_interruption": 9999.0, "description": "Barrière de face : absorbe coups et sorts contre du mana.",
			"double": {"reduction": 1.25, "cout": 1.8}},
	]
	# --- enchantements temporaires de la lame (phase 5)
	var enchants := {"feu": ["brulure", 3.0, 4.0], "glace": ["gel", 2.5, 0.35], "electricite": ["choc", 0.4, 0.35], "tenebres": ["corruption", 4.0, 0.15]}
	var noms := {"feu": "Lame ardente", "glace": "Lame de givre", "electricite": "Lame d'orage", "tenebres": "Lame des ténèbres"}
	for e in enchants:
		sorts.append({"id": "enchant_" + e, "nom": noms[e], "ecole": e, "type": T.ENCHANT, "portee_mode": P.SOI, "cout": 35.0,
			"incantation": 0.5, "recuperation": 0.4, "recharge": 2.0, "duree_enchant": 30.0, "degats_enchant": 7.0, "degats": 0.0,
			"type_degats": e, "statut": enchants[e][0], "duree_statut": enchants[e][1], "puissance_statut": enchants[e][2], "profil": "lame",
			"description": "Enchante l'arme de l'autre main 30 s.", "double": {}})
	for d in sorts:
		var s := DonneesSort.new()
		for k in d:
			s.set(k, d[k])
		var err := ResourceSaver.save(s, "res://data/sorts/%s.tres" % d["id"])
		print("sort ", d["id"], " -> ", err)
	quit(0)
