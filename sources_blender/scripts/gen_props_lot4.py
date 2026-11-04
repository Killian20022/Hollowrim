# Lot 4 (props/lot4, 2026-11-04) : pièces GARDÉES par le tri thème (references/TRI_THEME_2026-11-04.md) des trois packs Quaternius
# enfin téléchargés (Medieval Dungeon, Survival, Ultimate Food ; FBX, CC0). Usage : python3 -I gen_props_lot4.py <props.json>. Idempotent.
# Puis : blender -b --python importer_quaternius.py -- liste=<props.json> seulement=<noms lot4> apercu=<dossier> planches=<dossier>
# Échelle : les FBX de ces packs sont en unités arbitraires (tente 25 m, pomme 0,8 m) -> « ech » réglé par pièce sur une taille réelle.
# Couleurs : « mats » force la matière de la bible par nom de matériau Quaternius (sous-chaîne, clés longues d'abord) pour garder le
# virage nordique froid (poisson gris-fer et non saumon, assiettes et cuillères de bois, tente en toile de jute, cuir du manche en laine).
import json, sys
R = "C:/Users/lopezk19/Jeux/references/quaternius_props/"
MD = R + "medieval_dungeon/FBX/%s.fbx"
SV = R + "survival/FBX/%s.fbx"
UF = R + "ultimate_food/FBX/%s.fbx"
OS = {"Bones": "os"}
ROC = {"Rock": "pierre"}
VERRE = {"Liquid": "laine", "Glass": "fer", "Cork": "bois", "Gold": "or", "Blue": "toile", "Ice": "toile", "Grey": "fer", "Yellow": "or"}
LIVRE = {"Cover": "laine", "Paper": "lin", "Ink": "noir"}
OUTIL = {"DarkWood": "bois", "LightGrey": "fer", "Grey": "fer", "Black": "noir", "Red": "laine", "Yellow": "bois"}
# (nom, source, ech, budget, catégorie, mats)
L4 = [
 # Medieval Dungeon : crypte
 ("q_os_tas", MD % "Bones", 0.2, 500, "crypte_l4", OS), ("q_os_tas_2", MD % "Bones2", 0.2, 400, "crypte_l4", OS),
 ("q_roc_1", MD % "Rock1", 0.5, 60, "crypte_l4", ROC), ("q_roc_2", MD % "Rock2", 0.5, 60, "crypte_l4", ROC),
 ("q_roc_3", MD % "Rock3", 0.5, 60, "crypte_l4", ROC), ("q_roc_4", MD % "Rock4", 0.5, 60, "crypte_l4", ROC),
 ("q_roc_5", MD % "Rock5", 0.5, 60, "crypte_l4", ROC),
 ("q_colonne_brisee", MD % "Column_Broken", 0.45, 200, "crypte_l4", ROC), ("q_colonne_brisee_2", MD % "Column_Broken2", 0.45, 200, "crypte_l4", ROC),
 ("q_fiole_1", MD % "Potion", 0.15, 160, "crypte_l4", VERRE), ("q_fiole_2", MD % "Potion2", 0.15, 160, "crypte_l4", VERRE),
 ("q_fiole_3", MD % "Potion3", 0.15, 160, "crypte_l4", VERRE), ("q_fiole_4", MD % "Potion4", 0.15, 120, "crypte_l4", VERRE),
 ("q_fiole_5", MD % "Potion5", 0.15, 120, "crypte_l4", VERRE), ("q_fiole_6", MD % "Potion6", 0.15, 160, "crypte_l4", VERRE),
 ("q_livre_d1", MD % "Book2", 0.2, 200, "crypte_l4", LIVRE), ("q_livre_d2", MD % "Book3", 0.2, 200, "crypte_l4", LIVRE),
 ("q_livre_ouvert", MD % "Book_Open", 0.2, 200, "crypte_l4", LIVRE),
 ("q_tapis", MD % "Carpet", 0.6, 160, "crypte_l4", {"Red": "laine", "Gold": "or"}),
 ("q_coffre_d", MD % "Chest", 0.6, 340, "crypte_l4", {"DarkSteel": "noir", "Steel": "fer", "Wood": "bois"}),
 ("q_coffre_or", MD % "Chest_gold", 0.6, 440, "crypte_l4", {"DarkSteel": "noir", "Steel": "fer", "Gold": "or", "Wood": "bois"}),
 ("q_candelabre_d", MD % "Candelabrum_tall", 0.9, 600, "crypte_l4", {"Black": "noir", "Candle": "os", "Gold": "fer"}),
 ("q_bougie_d", MD % "Candle", 0.35, 200, "crypte_l4", {"Black": "noir", "Candle": "os", "Gold": "fer"}),
 # Survival : grotte, camps
 ("q_tente", SV % "Tent", 0.2, 700, "camp_l4", {"DarkWood": "bois", "LightGreen": "jute", "Green": "jute", "Black": "noir"}),
 ("q_feu_bois", SV % "Bonfire", 0.45, 450, "camp_l4", {"LightWood": "bois", "Wood": "bois"}),
 ("q_piege_ours", SV % "BearTrap_Open", 0.13, 350, "camp_l4", {"Grey": "fer"}),
 ("q_piege_ours_ferme", SV % "BearTrap_Closed", 0.13, 350, "camp_l4", {"Grey": "fer"}),
 ("q_marmite_camp", SV % "Pot", 0.22, 260, "camp_l4", {"Black": "noir", "Grey": "fer"}),
 ("q_marmite_camp_petite", SV % "Pot_Small", 0.22, 260, "camp_l4", {"Black": "noir", "Grey": "fer"}),
 ("q_poele", SV % "Pan", 0.16, 200, "camp_l4", OUTIL), ("q_poele_petite", SV % "Pan_Small", 0.16, 200, "camp_l4", OUTIL),
 ("q_hache_camp", SV % "Axe", 0.25, 200, "camp_l4", dict(OUTIL, Red="fer")), ("q_hachette", SV % "Axe_Small", 0.22, 160, "camp_l4", OUTIL),
 ("q_pelle", SV % "Shovel", 0.28, 220, "camp_l4", dict(OUTIL, Red="fer")),
 ("q_couteau_camp", SV % "Knife", 0.16, 160, "camp_l4", OUTIL),
 ("q_rondin", SV % "WoodLog", 0.37, 200, "camp_l4", {"LightWood": "bois", "Wood": "bois"}),
 # Ultimate Food : intérieurs, étals
 ("q_pomme", UF % "Apple", 0.1, 90, "nourriture_l4", {"DarkRed": "laine", "DarkBrown": "bois", "DarkGreen": "herbe"}),
 ("q_pomme_verte", UF % "Apple_Green", 0.1, 90, "nourriture_l4", {"PaleGreen": "herbe", "DarkBrown": "bois", "DarkGreen": "herbe"}),
 ("q_pain", UF % "Bread", 0.25, 160, "nourriture_l4", {"Brown": "bois", "Light": "jute"}),
 ("q_tranche_pain", UF % "Bread_Slice", 0.25, 120, "nourriture_l4", {"Brown": "bois", "Light": "jute"}),
 ("q_carotte_f", UF % "Carrot", 0.072, 160, "nourriture_l4", {"Orange": "argile", "DarkGreen": "herbe"}),
 ("q_cuisse", UF % "ChickenLeg", 0.13, 140, "nourriture_l4", {"Beige": "os", "DarkBrown": "argile"}),
 ("q_marmite_soupe", UF % "CookingPot_Soup", 0.21, 220, "nourriture_l4", {"Brown": "argile", "Grey": "fer"}),
 ("q_marmite_soupe_2", UF % "CookingPot2_Soup", 0.21, 220, "nourriture_l4", {"Brown": "argile", "Grey": "fer"}),
 ("q_oeuf", UF % "Egg_Whole", 0.13, 60, "nourriture_l4", {"LightYellow": "lin"}),
 ("q_oeuf_blanc", UF % "Egg_Whole_White", 0.13, 60, "nourriture_l4", {"White": "lin"}),
 ("q_poisson", UF % "Fish", 0.125, 200, "nourriture_l4", {"Bottom": "lin", "Fins": "jute", "Top": "fer"}),
 ("q_aretes", UF % "FishBone", 0.13, 200, "nourriture_l4", {"Beige": "os"}),
 ("q_jarre", UF % "Jar_Large", 0.47, 160, "nourriture_l4", {"LightYellow": "argile", "PaleRed": "laine", "White": "lin"}),
 ("q_champignon", UF % "Mushroom", 0.15, 60, "nourriture_l4", {"LightBrown": "jute"}),
 ("q_citrouille", UF % "Pumpkin", 0.23, 200, "nourriture_l4", {"Orange": "argile", "Brown": "bois"}),
 ("q_saucisse", UF % "Sausage_Cooked", 0.11, 60, "nourriture_l4", {"DarkBrown": "argile"}),
 ("q_saucisse_crue", UF % "Sausage_Raw", 0.11, 60, "nourriture_l4", {"Hotdog": "laine"}),
 ("q_viande", UF % "Steak", 0.115, 160, "nourriture_l4", {"DarkRed": "laine", "White": "lin"}),
 ("q_navet", UF % "Turnip", 0.09, 180, "nourriture_l4", {"PalePink2": "laine", "White": "lin", "DarkGreen": "herbe"}),
 ("q_chou", UF % "Lettuce_Whole", 0.12, 200, "nourriture_l4", {"PaleGreen": "herbe"}),
 ("q_lard", UF % "Bacon_Uncooked", 0.17, 120, "nourriture_l4", {"LightYellow": "lin", "Meat": "laine"}),
 ("q_bouteille_1", UF % "Bottle1", 0.19, 120, "nourriture_l4", {"BottleCap": "bois", "DarkGreen": "herbe", "LightBrown": "lin"}),
 ("q_bouteille_2", UF % "Bottle2", 0.19, 120, "nourriture_l4", {"BottleCap": "bois", "DarkGrey": "noir", "DarkRed": "laine", "LightBrown": "lin"}),
 ("q_ecuelle", UF % "Plate", 0.13, 100, "nourriture_l4", {"White": "bois"}),
 ("q_ecuelle_2", UF % "Plate2", 0.135, 100, "nourriture_l4", {"White": "argile"}),
 ("q_cuillere_bois", UF % "Spoon", 0.095, 60, "nourriture_l4", {"Metal": "bois"}),
 ("q_fourchette_f", UF % "Fork", 0.09, 60, "nourriture_l4", {"Metal": "fer"}),
 ("q_couteau_f", UF % "Knife", 0.1, 40, "nourriture_l4", {"Metal": "fer"}),
]
# couleurs d'origine trop vives (orange de la courge, de l'argile cuite) : sommets assombris (consigne : pas de nourriture fluo)
SOMBRE = {"q_citrouille": 0.72, "q_ecuelle_2": 0.78, "q_saucisse": 0.85, "q_carotte_f": 0.85, "q_jarre": 0.85, "q_cuisse": 0.88,
          "q_pomme": 0.85, "q_saucisse_crue": 0.8, "q_tapis": 0.85}
NOMS = [x[0] for x in L4]
if __name__ == "__main__":
    p = sys.argv[1]
    d = [x for x in json.load(open(p, encoding="utf8")) if not x.get("lot4")]
    for nom, src, ech, bud, cat, mats in L4:
        d.append({"nom": nom, "src": src, "ech": ech, "budget": bud, "role": cat, "categorie": cat, "lot4": True, "par_mat": True, "mats": mats,
                  "famille": sorted(set(mats.values()))})
        if nom in SOMBRE:
            d[-1]["eclairer"] = SOMBRE[nom]
    json.dump(d, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=0)
    print(len(d), "props ;", ",".join(NOMS))
