# Génère le lot 2 de props.json (usage : python3 -I gen_props_lot2.py <props.json>) : ajoute les props restants du Fantasy Props
# et du Medieval Village MegaKit, avec catégorie, budget, hauteur réelle (m) ou échelle native (None). Idempotent.
import json, sys
F = "C:/Users/lopezk19/Jeux/references/quaternius_props/fantasy_props_megakit/Exports/glTF/%s.gltf"
V = "C:/Users/lopezk19/Jeux/references/quaternius_props/medieval_village_megakit/Medieval Village MegaKit[Standard]/glTF/%s.gltf"
# (nom, source, budget, catégorie, hauteur ou None)
FANT = [
 ("q_billot_enclume", "Anvil_Log", 900, "forge", 0.85), ("q_etabli_tiroirs", "Workbench_Drawers", 300, "forge", 0.9),
 ("q_mannequin", "Dummy", 900, "forge", 1.7), ("q_rack_armes", "WeaponStand", 800, "forge", 1.5),
 ("q_tonneau", "Barrel", 500, "marche", 0.95), ("q_lit_2", "Bed_Twin2", 800, "interieur", 0.75),
 ("q_livres_moyens_1", "BookGroup_Medium_1", 300, "alchimie", 0.3), ("q_livres_moyens_2", "BookGroup_Medium_2", 300, "alchimie", 0.3),
 ("q_livres_moyens_3", "BookGroup_Medium_3", 300, "alchimie", 0.3), ("q_livres_petits_1", "BookGroup_Small_1", 104, "alchimie", None),
 ("q_livres_petits_2", "BookGroup_Small_2", 104, "alchimie", None), ("q_livres_petits_3", "BookGroup_Small_3", 130, "alchimie", None),
 ("q_livre_5", "Book_5", 96, "alchimie", None), ("q_livre_7", "Book_7", 300, "alchimie", None),
 ("q_livre_simple", "Book_Simplified_Single", 52, "alchimie", None), ("q_pile_livres_2", "Book_Stack_2", 300, "alchimie", None),
 ("q_bibliotheque", "Bookcase_2", 900, "interieur", 2.0), ("q_bouteille", "Bottle_1", 200, "alchimie", 0.3),
 ("q_bougie_1", "Candle_1", 120, "interieur", 0.15), ("q_bougie_2", "Candle_2", 120, "interieur", 0.12),
 ("q_carotte", "Carrot", 150, "marche", 0.3), ("q_pieces", "Coin", 150, "crypte", None),
 ("q_tas_pieces", "Coin_Pile", 400, "crypte", None), ("q_tas_pieces_2", "Coin_Pile_2", 400, "crypte", None),
 ("q_caisse_fer", "Crate_Metal", 700, "forge", 0.7), ("q_cageot_carottes", "FarmCrate_Carrot", 900, "marche", None),
 ("q_cageot_vide", "FarmCrate_Empty", 700, "marche", None), ("q_cle_or", "Key_Gold", 300, "crypte", None),
 ("q_cle_fer", "Key_Metal", 300, "crypte", None), ("q_lanterne_murale", "Lantern_Wall", 700, "crypte", 0.5),
 ("q_chevet_etagere", "Nightstand_Shelf", 262, "interieur", 0.65), ("q_porte_manteau", "Peg_Rack", 300, "interieur", None),
 ("q_couvercle_marmite", "Pot_1_Lid", 300, "forge", None), ("q_potion_1", "Potion_1", 250, "alchimie", 0.18),
 ("q_potion_2", "Potion_2", 250, "alchimie", 0.18), ("q_potion_4", "Potion_4", 250, "alchimie", 0.18),
 ("q_bourse", "Pouch_Large", 300, "marche", 0.3), ("q_corde_1", "Rope_1", 400, "marche", None),
 ("q_corde_2", "Rope_2", 400, "marche", None), ("q_corde_3", "Rope_3", 400, "marche", None),
 ("q_parchemin_2", "Scroll_2", 200, "alchimie", None), ("q_etagere_arche", "Shelf_Arch", 700, "interieur", None),
 ("q_etagere_simple", "Shelf_Simple", 480, "interieur", None), ("q_petite_fiole", "SmallBottle", 130, "alchimie", None),
 ("q_fioles_1", "SmallBottles_1", 300, "alchimie", None), ("q_fourchette", "Table_Fork", 108, "interieur", None),
 ("q_couteau_table", "Table_Knife", 54, "interieur", None), ("q_assiette", "Table_Plate", 172, "interieur", None),
 ("q_cuillere", "Table_Spoon", 164, "interieur", None), ("q_vase_2", "Vase_2", 400, "crypte", 0.5),
 ("q_vase_4", "Vase_4", 400, "crypte", 0.5), ("q_urne_brisee", "Vase_Rubble_Medium", 600, "crypte", 0.25),
 ("q_banniere_2", "Banner_2", 500, "village", None),
]
VILL = [("q_caisse_village", "Prop_Crate", 400, "village", 0.8), ("q_chariot", "Prop_Wagon", 1000, "village", 1.2),
 ("q_cheminee_1", "Prop_Chimney", 400, "village", None), ("q_cheminee_2", "Prop_Chimney2", 400, "village", None),
 ("q_support_bois", "Prop_Support", 300, "village", None), ("q_grille_fer_ornee", "Prop_MetalFence_Ornament", 700, "village", 1.8),
 ("q_grille_fer", "Prop_MetalFence_Simple", 500, "village", 1.8), ("q_barriere_bois", "Prop_WoodenFence_Single", 300, "village", None),
 ("q_barriere_ext_1", "Prop_WoodenFence_Extension1", 300, "village", None), ("q_barriere_ext_2", "Prop_WoodenFence_Extension2", 300, "village", None),
 ("q_brique_1", "Prop_Brick1", 150, "village", None), ("q_brique_2", "Prop_Brick2", 150, "village", None),
 ("q_brique_3", "Prop_Brick3", 150, "village", None), ("q_brique_4", "Prop_Brick4", 150, "village", None)]
for n in (1, 2, 4, 8):
    for f in ("Flat", "Round"):
        VILL.append(("q_porte_%d_%s" % (n, "plate" if f == "Flat" else "ronde"), "Door_%d_%s" % (n, f), 500, "village", 2.2))
for w in ("Thin", "Wide"):
    for f in ("Flat", "Round"):
        for o in ("Closed", "Open"):
            VILL.append(("q_volets_%s_%s_%s" % (w.lower(), f.lower(), o.lower()), "WindowShutters_%s_%s_%s" % (w, f, o), 300, "village", None))
for w in ("Thin_Flat1", "Thin_Round1", "Wide_Flat1", "Wide_Round1"):
    VILL.append(("q_fenetre_" + w.lower(), "Window_" + w, 300, "village", None))
CAT = {"forge": "forge", "auberge": "interieur", "maison": "interieur", "alchimie": "alchimie", "marche": "marche", "crypte": "crypte", "village": "village"}
p = sys.argv[1]
d = [x for x in json.load(open(p, encoding="utf8")) if not x.get("lot2")]
for x in d:
    x["categorie"] = CAT[x["role"]]
for liste, tpl in ((FANT, F), (VILL, V)):
    for nom, src, bud, cat, h in liste:
        e = {"nom": nom, "src": tpl % src, "budget": bud, "role": cat, "categorie": cat, "lot2": True}
        if h:
            e["hauteur"] = h
        d.append(e)
json.dump(d, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=0)
print(len(d), "props")
