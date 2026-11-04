# Lot 3 (props/remplacement, 2026-11-03) : ajoute à props.json les pièces écartées au lot 2 + deux pièces de KITBASH
# (usage : python3 -I gen_props_lot3.py <props.json>). Idempotent.
# Servent au remplacement des props maison : coffres décor, outils, boucliers/épées murales, chaîne, tissus ; kitbash : bûche et poutre
# ronde (OBJ simples de quaternius/kitbash/, recolorés par la chaîne comme les pièces Quaternius), bordures, marches, planches.
import json, sys
F = "C:/Users/lopezk19/Jeux/references/quaternius_props/fantasy_props_megakit/Exports/glTF/%s.gltf"
V = "C:/Users/lopezk19/Jeux/references/quaternius_props/medieval_village_megakit/Medieval Village MegaKit[Standard]/glTF/%s.gltf"
K = "C:/Users/lopezk19/Jeux/nordique_props_v2/sources_blender/quaternius/kitbash/%s.obj"
BF = ["bois", "fer"]
# (nom, source, budget, catégorie, hauteur, famille)
L3 = [
 ("q_coffre", F % "Chest_Wood", 900, "interieur", 0.55, BF), ("q_hache_outil", F % "Axe_Bronze", 500, "forge", None, BF),
 ("q_pioche", F % "Pickaxe_Bronze", 500, "forge", None, BF), ("q_bouclier_bois", F % "Shield_Wooden", 600, "interieur", None, BF),
 ("q_epee_mur", F % "Sword_Bronze", 600, "interieur", None, BF), ("q_chandelier_table", F % "CandleStick", 450, "interieur", None, None),
 ("q_chaine", F % "Chain_Coil", 1400, "forge", None, None),
 ("q_bordure_1", V % "Prop_ExteriorBorder_Straight1", 300, "village", None, None),
 ("q_bordure_2", V % "Prop_ExteriorBorder_Straight2", 300, "village", None, None),
 ("q_bordure_angle", V % "Prop_ExteriorBorder_Corner", 300, "village", None, None),
 ("q_marches_ext", V % "Stairs_Exterior_Straight", 500, "village", None, None), ("q_planches_sol", V % "Floor_WoodDark_Half1", 300, "village", None, ["bois"]),
 ("q_banniere_toile", F % "Banner_1_Cloth", 200, "village", None, ["laine", "toile"]),
 ("q_banniere_2_toile", F % "Banner_2_Cloth", 200, "village", None, ["laine", "toile"]),
 ("q_buche", K % "buche", 200, "village", None, ["bois"]), ("q_poutre_ronde", K % "poutre_ronde", 200, "village", None, ["bois"]),
]
# Packs « LowPoly » de Quaternius (CC0, itch.io) récupérés le 2026-11-03 quand les dossiers Drive (Survival, Food, Home Interior,
# Medieval Dungeon) sont restés en « Quota exceeded » : Modular Dungeon (May 2019) et Ultimate Nature (bûches, souches).
D = "C:/Users/lopezk19/Jeux/references/quaternius_props/lowpoly_modular_dungeon_itch/Updated_Modular_Dungeon_May2019/FBX/%s.fbx"
N = "C:/Users/lopezk19/Jeux/references/quaternius_props/ultimate_nature_itch/FBX/%s.fbx"
L3 += [
 ("q_sac_pieces", D % "Bag_Coins", 400, "crypte", None, None), ("q_sac_debout", D % "Bag_Standing", 400, "crypte", None, None),
 ("q_banniere_mur", D % "Banner_wall", 300, "crypte", None, None), ("q_tonneau_2", D % "Barrel2", 500, "crypte", None, ["bois", "fer"]),
 ("q_seau_2", D % "Bucket", 300, "crypte", None, ["bois", "fer"]), ("q_chaise_2", D % "Chair", 300, "crypte", None, ["bois"]),
 ("q_coffre_2", D % "Chest", 500, "crypte", None, ["bois", "fer"]), ("q_toile_araignee_1", D % "Cobweb", 200, "crypte", None, None),
 ("q_toile_araignee_2", D % "Cobweb2", 200, "crypte", None, None), ("q_colonne_1", D % "Column", 500, "crypte", None, ["pierre"]),
 ("q_colonne_2", D % "Column2", 500, "crypte", None, ["pierre"]), ("q_caisse_2", D % "Crate", 300, "crypte", None, ["bois", "fer"]),
 ("q_palissade", D % "Fence_Straight_Modular", 300, "crypte", None, None), ("q_palissade_bout", D % "Fence_End_Modular", 300, "crypte", None, None),
 ("q_palissade_angle", D % "Fence_90_Modular", 300, "crypte", None, None), ("q_piedestal_1", D % "Pedestal", 400, "crypte", None, ["pierre"]),
 ("q_piedestal_2", D % "Pedestal2", 400, "crypte", None, ["pierre"]), ("q_crane", D % "Skull", 400, "crypte", None, ["os"]),
 ("q_pieux", D % "Spikes", 300, "crypte", None, None), ("q_epee_support", D % "Sword_WallMount", 500, "crypte", None, None),
 ("q_table_grande_2", D % "Table_Big", 400, "crypte", None, ["bois"]), ("q_table_petite_2", D % "Table_Small", 300, "crypte", None, ["bois"]),
 ("q_piege_pieux", D % "Trap_spikes", 400, "crypte", None, None), ("q_vase_5", D % "Vase", 300, "crypte", None, None),
 ("q_bucher", D % "Woodfire", 400, "crypte", None, ["bois", "noir"]),
 ("q_tronc", N % "WoodLog", 300, "village", None, ["bois"]), ("q_souche", N % "TreeStump", 300, "village", None, ["bois"]),
]
p = sys.argv[1]
d = [x for x in json.load(open(p, encoding="utf8")) if not x.get("lot3")]
for nom, src, bud, cat, h, fam in L3:
    e = {"nom": nom, "src": src, "budget": bud, "role": cat, "categorie": cat, "lot3": True}
    if h:
        e["hauteur"] = h
    if fam:
        e["famille"] = fam
    if nom in ("q_buche", "q_poutre_ronde"):
        e["eclairer"] = 2.2      # pièces basses : sortaient presque noires (pied sombre sur toute la hauteur)
    d.append(e)
json.dump(d, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=0)
print(len(d), "props")
