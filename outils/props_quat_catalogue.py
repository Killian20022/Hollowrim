# Catalogue data/props_quaternius.json des props TEXTURÉS (pq_*) du Fantasy Props MegaKit : sortie de props_quaternius.py
# (data/props_quaternius_brut.json) + pour chaque prop les props ACTUELS du jeu qu'il peut remplacer et où le code les crée.
#   python3 -I outils/props_quat_catalogue.py
# Sources des correspondances : sources_blender/scripts/props_quaternius_liste.json (« ancien » = q_* du .dat des lots 2-3, déjà
# posé), docs/PROPS_REMPLACEMENT.md (tables « prop maison -> q_* »), recherche des q_* dans scripts/ et data/, table AUTRES ci-dessous.
import json, os, re, glob
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
brut = json.load(open(os.path.join(BASE, "data/props_quaternius_brut.json"), encoding="utf8"))
liste = {e["id"]: e for e in json.load(open(os.path.join(BASE, "sources_blender/scripts/props_quaternius_liste.json"), encoding="utf8"))}

# 1) tables du doc de remplacement : q_id -> [(section, prop maison, où)]
doc = open(os.path.join(BASE, "docs/PROPS_REMPLACEMENT.md"), encoding="utf8").read().splitlines()
lignes_doc = {}
section = ""
for l in doc:
    if l.startswith("#"):
        section = l.strip("# ").strip()
    if l.startswith("|") and "q_" in l:
        cel = [c.strip() for c in l.strip("|").split("|")]
        for q in set(re.findall(r"q_[a-z0-9_]+", " ".join(cel[1:3]))):
            lignes_doc.setdefault(q, []).append({"section": section.split(":")[0], "prop_maison": cel[0].replace("`", ""),
                                                  "ou": cel[3] if len(cel) > 3 else ""})

# 2) usages des q_* dans le code
code = {}
for f in sorted(glob.glob(os.path.join(BASE, "scripts", "*.gd"))):
    rel = os.path.relpath(f, BASE).replace("\\", "/")
    for i, l in enumerate(open(f, encoding="utf8"), 1):
        for q in re.findall(r'"(q_[a-z0-9_]+)"', l):
            code.setdefault(q, []).append("%s:%d" % (rel, i))

# 3) props actuels SANS équivalent q_* (objets du jeu, luminaires gardés…) : (description, chemin du code)
AUTRES = {
 "pq_torche_murale": [("torche murale du village (gardée au lot 3 : luminaire)", "scripts/village.gd:937 _torche_murale")],
 "pq_lanterne_murale": [("lanterne de halle / lanternes d'intérieur (gardées)", "scripts/interieur_halle.gd:288 _lanterne ; scripts/batiments_ouverts.gd:1006 _lanterne"),
                         ("lanternes d'étai de la grotte", "scripts/grotte_decor.gd:2032 _lanterne_etai")],
 "pq_chandelier_pied": [("candélabres de la crypte (luminaires L8, gardés)", "scripts/crypte_donjon.gd:40 « candelabres » ; scripts/crypte_v2.gd:275")],
 "pq_lustre": [("lustres de la crypte (luminaires L8, gardés)", "scripts/crypte_v2.gd (luminaires) / CrypteDecor")],
 "pq_bougeoir_triple": [("candélabres de table de la crypte (gardés)", "scripts/crypte_v2.gd:275")],
 "pq_cage": [("cages de la crypte (luminaires L8, gardées)", "scripts/crypte_v2.gd / CrypteDecor")],
 "pq_potion_1": [("modèle au sol de potion_soin / potion_mana", "data/objets/consommables.json « modele » (res://assets/modeles/objets/potion_*.glb)")],
 "pq_potion_2": [("modèle au sol de potion_soin_forte", "data/objets/consommables.json « modele »")],
 "pq_potion_4": [("modèle au sol de potion_endurance", "data/objets/consommables.json « modele »")],
 "pq_livre_5": [("modèle au sol des tomes de sort", "data/objets/consommables.json tome_* « modele »")],
 "pq_livre_7": [("modèle au sol des tomes de sort", "data/objets/consommables.json tome_* « modele »")],
 "pq_cle_fer": [("clé de quête cle_archives (modèle au sol)", "data/objets/quete.json cle_archives « modele »")],
 "pq_piece": [("pièces d'or au sol / butin", "scripts/objets_vivants.gd (petits objets vivants)")],
 "pq_chope": [("vaisselle vivante des tables (chopes)", "scripts/objets_vivants.gd ; scripts/interieurs.gd (helper chope)")],
 "pq_assiette": [("vaisselle vivante des tables", "scripts/objets_vivants.gd ; scripts/interieurs.gd (helper assiette)")],
 "pq_enclume": [("enclume de la forge (posée sur billot)", "scripts/interieurs.gd (forge : enclume + billot)")],
}
HORS_THEME = {"pq_hache_outil": "source en bronze : tête repeinte en fer", "pq_pioche": "source en bronze : fer repeint",
              "pq_epee_mur": "source en bronze : lame repeinte en fer ; garde dorée simple, à éviter en arme tenue (décor mural seulement)",
              "pq_cle_or": "or terni (rampe Or de la bible) : clé de coffre/trésor, pas d'or brillant",
              "pq_lustre": "lustre à bougies de fer : convient à la halle/crypte, trop riche pour une maison paysanne",
              "pq_chandelier_pied": "candélabre sur pied de fer : temple, halle, crypte (pas une ferme)",
              "pq_etal": "auvent de toile rayée : la toile est accrochée à la laine rouge/écru ; garder pour le marché",
              "pq_charrette_etal": "idem étal : auvent recoloré", "pq_potion_4": "liquide violet accroché sur la laine (pas de violet dans la bible)",
              "pq_banniere": "emblème générique du pack (pas un emblème nordique) : à couvrir d'un motif du jeu si on le veut",
              "pq_banniere_2": "idem bannière", "pq_banniere_toile": "idem bannière", "pq_banniere_2_toile": "idem bannière"}

out = []
for r in brut:
    e = liste.get(r["id"], {})
    rem = []
    q = e.get("ancien")
    if q:
        rem.append({"prop_actuel": q, "type": "prop Quaternius du .dat (lots 2-3, couleurs de face, sans texture)",
                    "api": "PropsQuaternius (scripts/props_quaternius.gd, assets/crypte/modules/props_quaternius.dat)",
                    "code": code.get(q, [])[:8], "nb_appels_code": len(code.get(q, [])),
                    "remplacait": lignes_doc.get(q, [])})
    for desc, chemin in AUTRES.get(r["id"], []):
        rem.append({"prop_actuel": desc, "type": "fait maison / objet du jeu", "code": [chemin]})
    x = dict(r)
    x["remplace"] = rem
    if r["id"] in HORS_THEME:
        x["theme"] = HORS_THEME[r["id"]]
    out.append(x)

doc_cat = {
 "_doc": "Props TEXTURÉS du Fantasy Props MegaKit (Quaternius, CC0, version Standard gratuite, License_Standard.txt) convertis par "
         "sources_blender/scripts/props_quaternius.py (props/quaternius, 2026-11-10). Chargement : scripts/props_quat.gd (PropsQuat.instancier / "
         "maillage / corps / materiau). Repère Godot : origine au pied au centre de l'emprise, dimensions_m = [X largeur, Y hauteur, Z profondeur]. "
         "collision : boite (taille XYZ, centre_y) / cylindre (rayon, hauteur) / aucune (petits objets). atlas = matériaux partagés "
         "(assets/modeles/props_quat/textures/pq_*.png : 128 px, tissu 256, page 32 ; filtre plus proche). texels_m = densité réelle par atlas. "
         "remplace : prop(s) actuel(s) du jeu que ce prop peut remplacer, avec les lignes de code qui les posent ; « prop_actuel » q_* = la "
         "version .dat à couleurs de face DÉJÀ posée par les lots 2-3 (même modèle source, sans texture).",
 "categories": sorted({r["categorie"] for r in out}),
 "atlas": json.load(open(os.path.join(BASE, "assets/modeles/props_quat/textures/atlas.json"))),
 "props": out,
}
json.dump(doc_cat, open(os.path.join(BASE, "data/props_quaternius.json"), "w", encoding="utf8"), indent=1, ensure_ascii=False)
print("catalogue :", len(out), "props ;", sum(1 for x in out if x["remplace"]), "avec remplacement ;",
      sum(r["tris"] for r in out), "tris ;", sum(r["octets"] for r in out), "octets")
