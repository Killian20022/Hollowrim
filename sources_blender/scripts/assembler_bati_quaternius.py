# ESSAI BÂTI QUATERNIUS (essai/bati_quaternius, 2026-11-03) : assemble des bâtiments du village à partir des pièces MODULAIRES du
# Medieval Village MegaKit (CC0), puis les passe dans la chaîne existante importer_quaternius.py (palette bible, ton x occlusion,
# arêtes) vers assets/modeles/bati_quaternius.dat.
#   blender.exe -b --python assembler_bati_quaternius.py -- liste=<bati.json> [sortie=<.dat>] [apercu=<dossier>]
# bati.json : [{"nom": "b_h1", "recette": "h1", "mats": {...}, "budget": 20000}, ...] ; la recette (RECETTES ci-dessous) donne
# l'emprise (L x W en mètres, repère du village : x = longueur, +Z = façade), les modules de chaque côté et le toit.
# Repère Blender de l'assemblage : z en haut, façade = -Y (devient +Z Godot), longueur sur X, centré sur (0, 0).
# Les pièces sont étirées EN LONGUEUR seulement (sx = L / (2 n) : modules de 2 m) pour tomber pile sur l'emprise du bâtiment
# d'origine ; la hauteur est réduite (SZ) pour garder des portes de 1,9 m (les modules font 3 m, le jeu a des murs de 2,3-2,5 m).
import bpy, math, os, sys, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importer_quaternius as iq

VILLAGE = "C:/Users/lopezk19/Jeux/references/quaternius_props/medieval_village_megakit/Medieval Village MegaKit[Standard]/glTF/%s.gltf"
SZ = 0.8            # échelle verticale (module 3,12 m -> 2,5 m ; porte ronde 2,35 -> 1,88 m)
SY = 0.8            # épaisseur des murs
EXT = 0.2           # face extérieure du mur = demi-emprise + EXT (la collision d'origine fait demi-emprise + 0,225)

MURS = {"S": "Straight", "D": "Door_Round", "Df": "Door_Flat", "W": "Window_Wide_Round", "Wf": "Window_Wide_Flat", "T": "Window_Thin_Round"}
# fenêtres : volets fermés posés devant le trou (le trou donne sur l'intérieur vide de la façade)
VOLETS = {"W": "WindowShutters_Wide_Round_Open", "Wf": "WindowShutters_Wide_Flat_Open", "T": "WindowShutters_Thin_Round_Open"}
LARG_VITRE = {"W": 1.15, "Wf": 1.15, "T": 0.6}      # vitrage plaqué dans l'ouverture (m, avant échelle), lueur la nuit (village._vitre)
PANS = []          # [x, y0, z (repère Godot, nu extérieur du pan), larg, haut, lacet rad] : pans pleins à colombage en croix
VOLETS_P = []      # [prop, x, y, z (repère Godot), lacet rad, sx, sy, sz] : volets des props validés posés par le jeu
PORTES = []        # [x, y, z (repère Godot, milieu du seuil), larg, haut, lacet rad, cintrée] : vantaux posés par le jeu
PIGNON_X = [0.0]   # x du nu extérieur du pignon +X (repère Godot = Blender en x)
FENETRES = []      # [x, y (milieu de l'ouverture), z (repère Godot, nu extérieur), larg, haut (de l'ouverture), lacet rad] : fenêtres posées par le jeu
VITRES = []        # [x, y, z (repère Godot, centre du vitrage), larg, haut, lacet rad] de l'assemblage en cours

# côté : angle autour de Z (façade = -Y : +Z Godot ; +X Godot = +X ; -Z Godot = +Y ; -X Godot = -X)
COTES = {"+Z": 0, "+X": 90, "-Z": 180, "-X": 270}

RECETTES = {
    # H1 : maison de rondins au bord de la place (7 x 5), porte au nord (+Z local), pignons à dragons -> ici : murs plâtre/colombage
    "h1": {"L": 7.0, "W": 5.0, "mur": "Plaster", "niveaux": [2.5],
           "cotes": {"+Z": ["W", "D", "W"], "-Z": ["Wf", "S", "Wf"], "+X": ["S", "T", "S"], "-X": ["S", "Wf", "S"]},
           "toit": ("Roof_RoundTiles_6x8", 7.0), "pignon": "Roof_Front_Brick6", "cheminee": ("Prop_Chimney2", 1.2)},
    # H2 : rez de pierre, étage à colombages en encorbellement (6 x 4,5)
    "h2": {"L": 6.0, "W": 4.5, "mur": "UnevenBrick", "niveaux": [2.5, 1.9], "etage_mur": "Plaster", "encorbellement": 0.25,
           "cotes": {"+Z": ["Wf", "Df", "Wf"], "-Z": ["Wf", "S", "Wf"], "+X": ["S", "Wf"], "-X": ["S", "Wf"]},
           "toit_dz": 0.55, "cotes_etage": {"+Z": ["S", "Wf", "S"], "-Z": ["S", "Wf", "S"], "+X": ["S", "Wf"], "-X": ["S", "Wf"]}, "croix": "etage",
           "toit": ("Roof_RoundTiles_6x8", 6.0), "pignon": "Roof_Front_Brick6", "cheminee": ("Prop_Chimney", -1.6)},
    # H4 : petite maison de pierre de la haute rue (6 x 5), porte à l'ouest (-X)
    "h4": {"L": 6.0, "W": 5.0, "mur": "UnevenBrick", "niveaux": [2.5],
           "cotes": {"+Z": ["Wf", "S", "Wf"], "-Z": ["S", "Wf", "S"], "+X": ["S", "T", "S"], "-X": ["S", "D", "S"]},
           "toit": ("Roof_RoundTiles_6x8", 6.0), "pignon": "Roof_Front_Brick6", "cheminee": ("Prop_Chimney2", 2.2)},
    # --- généralisation (bati/hybride, 2026-11-04) ---
    # H3 : maison de planches de la haute rue (6 x 5), porte sur le pignon est (+X) vers l'escalier -> plâtre (le WoodGrid, essayé, fait une grille trop chargée en PS1)
    "h3": {"L": 6.0, "W": 5.0, "mur": "Plaster", "niveaux": [2.5],
           "cotes": {"+Z": ["S", "Wf", "S"], "-Z": ["Wf", "S", "Wf"], "+X": ["S", "Df", "S"], "-X": ["S", "S", "S"]},
           "toit": ("Roof_RoundTiles_6x8", 6.0), "pignon": "Roof_Front_Brick6"},
    # maison du moulin à eau (6 x 6), pierre, porte +Z ; mur -X plein (berge : l'arbre de la roue y entre)
    "moulin": {"L": 6.0, "W": 6.0, "mur": "UnevenBrick", "niveaux": [2.5],
           "cotes": {"+Z": ["S", "D", "Wf"], "-Z": ["S", "Wf", "S"], "+X": ["S", "Wf", "S"], "-X": ["S", "S", "S"]},
           "toit": ("Roof_RoundTiles_6x8", 6.0), "pignon": "Roof_Front_Brick6", "cheminee": ("Prop_Chimney", 1.8)},
    # ferme B (8 x 5) : pierre, porte à l'ouest (-X), étable sur la terrasse du chemin de la grotte
    "ferme_b": {"L": 8.0, "W": 5.0, "mur": "UnevenBrick", "niveaux": [2.5],
           "cotes": {"+Z": ["S", "Wf", "Wf", "S"], "-Z": ["S", "S", "Wf", "S"], "+X": ["S", "T", "S"], "-X": ["S", "Df", "S"]},
           "toit": ("Roof_RoundTiles_6x8", 8.0), "pignon": "Roof_Front_Brick6", "cheminee": ("Prop_Chimney2", 2.6)},
    # pièces isolées posées sur les maisons de rondins (hybride : la maison reste en rondins, ces détails sont Quaternius)
    "cheminee_1": {"piece": "Prop_Chimney"},
    "cheminee_2": {"piece": "Prop_Chimney2"},
    "cadre_porte": {"piece": "DoorFrame_Flat_WoodDark"},
    "cadre_porte_rond": {"piece": "DoorFrame_Round_WoodDark"},
    "balcon": {"piece": "Balcony_Simple_Straight"},
    "escalier": {"piece": "Stairs_Exterior_Straight"},
}

_cache = {}
META = {}      # recette -> dimensions utiles au jeu (relues par scripts/village_bati_q.gd via bati_quaternius.json)
Z_FAITE = {"Roof_RoundTiles_4x8": (3.71, -0.52), "Roof_RoundTiles_6x8": (4.89, -0.78), "Roof_RoundTiles_8x8": (6.00, -0.78)}


def charger(nom):
    """Importe une pièce du kit (une fois par assemblage) -> liste de (objet source, matrice monde)."""
    if nom not in _cache:
        avant = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=VILLAGE % nom)
        neufs = [o for o in bpy.context.scene.objects if o not in avant]
        ms = [o for o in neufs if o.type == 'MESH']
        _cache[nom] = [(o.data, o.matrix_world.copy(), [s.material for s in o.material_slots]) for o in ms]
        for o in neufs:
            bpy.data.objects.remove(o, do_unlink=True)
    return _cache[nom]


def poser(nom, pos, lacet=0.0, ech=(1, 1, 1), budget=None, objets=None):
    """Instancie la pièce `nom` : translation `pos` (Blender), rotation `lacet`° autour de Z, échelle `ech`. Retourne les objets."""
    sc = bpy.context.scene
    M = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(lacet), 4, 'Z') @ Matrix.Diagonal(Vector((ech[0], ech[1], ech[2], 1)))
    res = []
    for data, mw, mats in charger(nom):
        d = data.copy()
        o = bpy.data.objects.new(nom, d)
        sc.collection.objects.link(o)
        o.matrix_world = M @ mw
        res.append(o)
        if budget:
            n = sum(len(p.vertices) - 2 for p in d.polygons)
            if n > budget:
                md = o.modifiers.new("reduc", 'DECIMATE')
                md.ratio = budget / n
                md.use_collapse_triangulate = True
    return res


def origine_prop(nom, pos, lacet, ech):
    """Point où le jeu doit poser le prop converti de la pièce `nom` (importer_quaternius : origine = milieu de l'emprise, au sol)
    pour qu'il tombe exactement sur la pièce posée par poser(nom, pos, lacet, ech)."""
    pts = [mw @ v.co for data, mw, _ in charger(nom) for v in data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    loc = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    M = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(lacet), 4, 'Z') @ Matrix.Diagonal(Vector((ech[0], ech[1], ech[2], 1)))
    return M @ loc


def mur_cote(rec, cote, modules, z0, sz, L, W, decal=0.0, mur=None):
    """Une rangée de murs sur un côté. L, W : emprise ; decal : encorbellement (mur reculé vers l'extérieur)."""
    ang = COTES[cote]
    long_cote = L if cote in ("+Z", "-Z") else W        # longueur du mur
    n = len(modules)
    sx = long_cote / (2.0 * n)
    ds = (W if cote in ("+Z", "-Z") else L) * 0.5 + EXT + decal    # distance centre -> face extérieure
    objs = []
    for i, m in enumerate(modules):
        t = -long_cote * 0.5 + (i + 0.5) * long_cote / n          # abscisse le long du mur (repère du mur)
        # repère du mur : x le long, -y vers l'extérieur ; face extérieure de la pièce à y = -0.09 * SY
        loc = Vector((t, -ds + 0.09 * SY, z0))
        R = Matrix.Rotation(math.radians(ang), 3, 'Z')
        pos = R @ loc
        nom = "Wall_%s_%s" % (mur or rec["mur"], MURS[m])
        if m == "S" and rec.get("plein") and not mur:          # pans pleins d'un autre modèle (plâtre à pans de bois)
            nom = rec["plein"]
        if m == "S" and rec.get("croix") and (mur is not None) == (rec["croix"] == "etage"):   # colombage en croix gardé (posé par le jeu)
            q = R @ Vector((t, -ds, 0))
            PANS.append([round(q.x, 3), round(z0, 3), round(-q.y, 3), round(long_cote / n, 3), round(3.12 * sz, 3), round(math.radians(ang), 4)])
        objs += poser(nom, pos, ang, (sx, SY, sz))
        if m in ("D", "Df"):                  # vantail : PAS celui du kit (il sortait en trou noir) ; le jeu pose dans l'ouverture le
            pc = R @ Vector((t - 0.03 * sx, -ds + 0.09 * SY + 0.1, z0))      # vantail de planches des props validés (q_porte_*)
            PORTES.append([round(pc.x, 3), round(pc.z, 3), round(-pc.y, 3), round(1.1 * sx, 3), round(2.13 * sz, 3), round(math.radians(ang), 4), m == "D"])
        if m in VOLETS:
            pg = R @ Vector((t, -ds + 0.09 * SY + 0.12, z0 + 1.9 * sz))
            # vitrage en carreaux de la taille de ceux du village (0,7 x 0,55 m) : la croix du vitrage garde la même échelle que
            # sur les maisons de rondins (un seul grand vitrage étiré faisait un gros cadre orange)
            lv, hv = LARG_VITRE[m] * sx, 1.35 * sz
            qf = R @ Vector((t, -ds, 0))
            FENETRES.append([round(qf.x, 3), round(z0 + 1.9 * sz, 3), round(-qf.y, 3), round(lv, 3), round(hv, 3), round(math.radians(ang), 4)])
            nx, ny = max(1, round(lv / 0.68)), max(1, round(hv / 0.56))
            for ix in range(nx):
                for iy in range(ny):
                    q = R @ Vector((t - lv * 0.5 + (ix + 0.5) * lv / nx, -ds + 0.09 * SY + 0.12, 0))
                    VITRES.append([round(q.x, 3), round(z0 + 1.9 * sz - hv * 0.5 + (iy + 0.5) * hv / ny, 3), round(-q.y, 3), round(lv / nx, 3), round(hv / ny, 3), round(math.radians(ang), 4)])
            # volets : PAS ceux du kit (fondus dans le bois sombre du bâti, ils sortaient en plaques noires) ; le jeu pose les volets
            # des props validés (q_volets_*, mêmes pièces, mêmes matières que les maisons d'avant) à la même place
            pv = R @ Vector((t, -ds - 0.02, z0))
            o = origine_prop(VOLETS[m], pv, ang, (sx, SY, sz))
            VOLETS_P.append(["q_volets_" + VOLETS[m][len("WindowShutters_"):].lower(), round(o.x, 3), round(o.z, 3), round(-o.y, 3),
                             round(math.radians(ang), 4), round(sx, 3), round(sz, 3), SY])
    return objs


def assembler(nom_recette):
    rec = RECETTES[nom_recette]
    if "piece" in rec:                                  # pièce isolée : posée telle quelle (le jeu l'échelonne)
        objs = poser(rec["piece"], (0, 0, 0))
        META[nom_recette] = {"piece": rec["piece"]}
        return objs, 0.0
    L, W = rec["L"], rec["W"]
    VITRES.clear()
    FENETRES.clear()
    PORTES.clear()
    VOLETS_P.clear()
    PANS.clear()
    objs = []
    z = 0.0
    for k, hh in enumerate(rec["niveaux"]):
        sz = hh / 3.0 if k else SZ
        sz = SZ if k == 0 else max(0.5, hh / 3.12)
        if k == 0:
            for cote, mods in rec["cotes"].items():
                objs += mur_cote(rec, cote, mods, z, sz, L, W)
        else:
            dec = rec.get("encorbellement", 0.0)
            Le, We = L + 2 * dec, W + 2 * dec
            for cote, mods in rec["cotes_etage"].items():
                objs += mur_cote(rec, cote, mods, z, sz, Le, We, decal=dec, mur=rec.get("etage_mur"))
            # sablière de l'encorbellement : lisse de bois sur le pourtour (Wall_BottomCover, 2 m x 0,25)
            for cote in COTES:
                long_c = Le if cote in ("+Z", "-Z") else We
                R = Matrix.Rotation(math.radians(COTES[cote]), 3, 'Z')
                nb = max(1, round(long_c / 2.0))
                for i in range(nb):
                    t = -long_c * 0.5 + (i + 0.5) * long_c / nb
                    d = (W if cote in ("+Z", "-Z") else L) * 0.5 + EXT + dec
                    objs += poser("Wall_BottomCover", R @ Vector((t, -d + 0.1, z)), COTES[cote], (long_c / nb / 2.0, 1.0, 1.0))
        z += 3.0 * sz
    ztop = z
    zt = ztop + rec.get("toit_dz", 0.0)     # toit (et pignons) relevé : H2, l'égout du kit couvrait le haut de l'étage à colombage
    # poteaux d'angle
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            objs += poser("Corner_Exterior_Wood", (sx_ * (L * 0.5 + EXT), sy_ * (W * 0.5 + EXT), 0), 0, (1.0, 1.0, ztop / 3.0))
    # toit : pièce du kit étirée à l'emprise (faîtage selon X)
    nom_toit, _ = rec["toit"]
    Wt = W + (2 * rec.get("encorbellement", 0.0))
    b = [o for o in objs]          # (les murs ne sont pas réduits)
    larg_pc = {"Roof_RoundTiles_4x8": 5.52, "Roof_RoundTiles_6x8": 8.24, "Roof_RoundTiles_8x8": 9.96}[nom_toit]
    long_pc = {"Roof_RoundTiles_4x8": 9.68, "Roof_RoundTiles_6x8": 9.68, "Roof_RoundTiles_8x8": 10.33}[nom_toit]
    span = Wt + 2 * EXT + 1.5                       # largeur de toit voulue (avec les avancées)
    s_larg = span / larg_pc
    s_long = (L + 2 * EXT + 1.5) / long_pc
    # la pièce a son faîtage sur Y : on la tourne de 90° autour de Z (faîtage sur X) -> x_piece = largeur => y monde ; y_piece = longueur => x monde
    objs += poser(nom_toit, (0, 0, zt), 90, (s_larg, s_long, s_larg), budget=900)
    # pignons plâtrés sous le toit (Roof_Front_Brick6 : 6,7 m de large sur 4,4 de haut)
    if rec.get("pignon"):
        for sg in (-1, 1):
            ang = 90 if sg > 0 else 270          # la face -Y de la pièce regarde vers l'extérieur
            sx_g = (Wt + 2 * EXT - 0.1) / 6.7
            pg = poser(rec["pignon"], (sg * (L * 0.5 + EXT - 0.1), 0, zt), ang, (sx_g * 1.04, SY, s_larg * 1.07))   # un peu plus grand : pas de jour (fil de ciel) sous les rives
            objs += pg
            if sg > 0:      # nu extérieur du pignon (le jeu y pose un colombage de bois sombre)
                PIGNON_X[0] = max((o.matrix_world @ v.co).x for o in pg for v in o.data.vertices)
    zf, ze = Z_FAITE[nom_toit]
    META[nom_recette] = {"L": L, "W": W, "ztop": ztop, "faite": zt + zf * s_larg, "egout": zt + ze * s_larg, "toit_dz": zt - ztop, "demi_toit": span * 0.5,
                         "long_toit": long_pc * s_long, "vitres": VITRES[:], "portes": PORTES[:], "volets": VOLETS_P[:], "pans": PANS[:],
                         "fenetres": FENETRES[:], "pignon_ext": PIGNON_X[0], "larg_pignon": Wt + 2 * EXT}
    if rec.get("cheminee"):
        nom_c, xc = rec["cheminee"]
        objs += poser(nom_c, (xc, 0.7, zt + 1.6), 0, (1.0, 1.0, 1.35))
        META[nom_recette]["cheminee"] = [xc, zt + 1.6 + {"Prop_Chimney": 3.18, "Prop_Chimney2": 3.0}[nom_c] * 1.35, -0.7]   # repère Godot (x, y, z)
    return objs, ztop


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    A = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in args if "=" in a}
    liste = json.load(open(A["liste"], encoding="utf8"))
    dat = A.get("sortie", os.path.join(iq.BASE, "assets", "modeles", "bati_quaternius.dat"))
    dossier = A.get("apercu")
    donnees = {k: v for k, v in iq._lire_dat(dat).items() if k.split("__")[0] not in [e["nom"] for e in liste]}
    bilan = []

    def importer_assemble(src):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _cache.clear()
        objs, _ = assembler(src)
        return [o for o in objs if o.type == 'MESH']
    iq.importer = importer_assemble                    # la « source » d'une entrée est le nom d'une recette
    for e in liste:
        e = dict(e)
        e["src"] = e["recette"]
        e.setdefault("origine", [0.0, 0.0])
        e.setdefault("bandes", "aucune")
        e.setdefault("par_face", True)
        e.setdefault("budget", 40000)
        P, objs = iq.adapter(e)
        res = iq.aretes.appliquer(P.finir(), bandes=P.bandes)
        for mat, faces in res.items():
            donnees["%s__%s" % (P.nom, mat)] = faces
        pts = [q for (_, p, _) in P.tris for q in p]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        ligne = "%-10s src %5d -> %5d tris apres aretes  x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f] m  %s" % (
            P.nom, P.total_src, sum(len(f) for f in res.values()), lo[0], hi[0], lo[1], hi[1], lo[2], hi[2],
            " ".join("%s:%d" % kv for kv in sorted(P.stat.items(), key=lambda kv: -kv[1])))
        print("  " + ligne)
        bilan.append(ligne)
        if dossier:
            os.makedirs(dossier, exist_ok=True)
            iq.apercu_adapte(P, res, os.path.join(dossier, e["nom"] + "_adapte.png"))
    import struct
    os.makedirs(os.path.dirname(dat), exist_ok=True)
    with open(dat, "wb") as f:
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    jf = os.path.splitext(dat)[0] + ".json"
    ancien = json.load(open(jf, encoding="utf8")) if os.path.exists(jf) else {}
    for e in liste:
        ancien[e["nom"]] = META[e["recette"]]
    json.dump(ancien, open(jf, "w", encoding="utf8"), indent=1)
    print("bati quaternius : %d entrees -> %s" % (len(donnees), dat))
    if dossier:
        open(os.path.join(dossier, "bilan.txt"), "w", encoding="utf8").write("\n".join(bilan) + "\n")


if __name__ == "__main__":
    main()
