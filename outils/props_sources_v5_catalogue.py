# Fusionne data/props_sources_v5_brut.json (sortie de sources_blender/scripts/props_sources_v5.py) dans le catalogue des props
# texturés data/props_quaternius.json (props/sources_v5, 2026-11-19). Idempotent : les entrées « lot v5 » sont remplacées.
#   python3 -I outils/props_sources_v5_catalogue.py
# Champs ajoutés par rapport aux pq_* du MegaKit : lot = "v5", pack, nom (FR), matiere, usage (prop maison qu'il peut remplacer),
# equivalent_q (q_* des lots 2-4 issu du MÊME modèle à la MÊME échelle). « ancien » n'est PAS posé : PropsQuaternius ne remplace donc
# rien tout seul ; pour activer le remplacement automatique d'un q_*, copier equivalent_q dans « ancien » puis relancer
# outils/export_props_quat_dat.gd.
import json, os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(BASE, "data/props_quaternius.json")
brut = json.load(open(os.path.join(BASE, "data/props_sources_v5_brut.json"), encoding="utf8"))
cat = json.load(open(CAT, encoding="utf8"))
ids = {r["id"] for r in brut}
props = [p for p in cat["props"] if p.get("lot") != "v5" and p["id"] not in ids]
for r in brut:
    x = dict(r)
    x["lot"] = "v5"
    x["remplace"] = []
    if r.get("equivalent_q"):
        x["remplace"].append({"prop_actuel": r["equivalent_q"], "type": "prop Quaternius du .dat (lots 2-4, couleurs de face, même modèle)",
                              "api": "PropsQuaternius (scripts/props_quaternius.gd)", "auto": False})
    if r.get("usage"):
        x["remplace"].append({"prop_actuel": r["usage"], "type": "usage conseillé (docs/PROPS_SOURCES_V5.md)"})
    props.append(x)
cat["props"] = props
cat["categories"] = sorted({p["categorie"] for p in props})
if "v5" not in cat["_doc"]:
    cat["_doc"] += (" | Lot v5 (props/sources_v5, 2026-11-19, champ lot = \"v5\") : packs Quaternius à couleurs unies (Ultimate Home "
                    "Interior, Medieval Dungeon, Modular Dungeon, Survival, Ultimate Food) et Medieval Village, RE-PROJETÉS sur les "
                    "mêmes atlas (sources_blender/scripts/props_sources_v5.py) ; champs nom, matiere, usage, equivalent_q ; liste et "
                    "rejets : docs/PROPS_SOURCES_V5.md.")
json.dump(cat, open(CAT, "w", encoding="utf8"), indent=1, ensure_ascii=False)
print("catalogue :", len(props), "props dont", len(brut), "v5 ;", sum(r["tris"] for r in brut), "tris v5")
