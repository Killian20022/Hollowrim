# CLAYMORE LONGUE (branche combat/claymore_2mains, retour utilisateur du 2026-10-30 : « une lame beaucoup plus détaillée et plus
# longue », dans l'esprit rubis de la n°05). Même chaîne que epees_longues.py / epees_hybrides.py (repère, matériaux, habillage PS1
# EpeesLongues.habiller) : lame +Z Blender (+Y glTF), centre du poing droit à z = 0,03 (nœud « prise »), nœuds garde / pointe.
#   blender.exe -b --python sources_blender/epees_hybrides/claymore_longue.py
# Sortie : assets/modeles/armes/deux_mains/claymore_longue.glb (l'ancienne n°05 reste : deux_mains/claymore.glb).
# Lame 1,30 m (total ~1,72 m) : cristal rubis à section « gorge » (gouttière profonde, biseaux), talon (ricasso) gainé de cuir avec
# deux crochets de parade, crans et renflement façon n°05, runes d'or serties dans la gouttière, garde fine en fer sombre à
# quillons relevés, rubis serti au centre et cristal au pommeau ; fusée tressée de 32 cm à bagues.
import bpy, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
_lib = os.path.join(os.path.dirname(ICI), "epees_longues", "epees_longues.py")
exec(open(_lib, encoding="utf-8").read().split("# ================================================================== variantes")[0])
ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "deux_mains")

Z_HAUT = 0.084      # haut de la fusée
LP = 0.32           # longueur de la fusée
Z_GARDE = 0.100     # la lame (talon) sort de la garde
L_LAME = 1.30
Z_RICASSO = 0.250   # fin du talon gainé (crochets de parade juste au-dessus)

# lame (stations relatives f = 0 garde -> 1 pointe ; demi-largeur, demi-épaisseur avant ELARGIR / LARGE / EPAIS)
P_LONGUE = [(0.0, 0.0150, 0.0060), (0.112, 0.0150, 0.0060),            # talon étroit (sous le cuir)
            (0.118, 0.0262, 0.0064), (0.17, 0.0268, 0.0063),             # épaulement après les crochets
            (0.172, 0.0205, 0.0062), (0.19, 0.0258, 0.0062),             # 1er cran
            (0.34, 0.0246, 0.0060), (0.342, 0.0195, 0.0058), (0.36, 0.0240, 0.0058),   # 2e cran
            (0.52, 0.0226, 0.0055), (0.62, 0.0234, 0.0053),             # renflement au tiers supérieur
            (0.64, 0.0188, 0.0050), (0.66, 0.0222, 0.0049),             # 3e cran
            (0.80, 0.0180, 0.0045), (0.90, 0.0122, 0.0039), (0.96, 0.0060, 0.0030)]


def construire():
    vider()
    for n in MATS:
        bpy.data.materials.new(n)
    zt = Z_GARDE + L_LAME
    # ---- lame : rubis, gouttière (section « gorge ») ; la gouttière s'arrête au 3/4 (elle s'efface vers la pointe)
    L = Maille("lame")
    lame(L, [(Z_GARDE + st[0] * L_LAME,) + st[1:] for st in P_LONGUE], Z_GARDE, zt, "gorge", lambda k, i: "rubis", 0.026,
         elargir=(1.75, 1.28))
    L.creer()
    # ---- talon gainé de cuir (ricasso) + crochets de parade
    R = Maille("ricasso")
    zs = [Z_GARDE + 0.004 + (Z_RICASSO - Z_GARDE - 0.008) * k / 5 for k in range(6)]
    tour(R, [(z, 0.0215 * (1.0 + 0.05 * math.sin(k * 1.7))) for k, z in enumerate(zs)], "cuir", cotes=8, ecrase_y=0.55, uv_tours=2.0)
    for z in (Z_GARDE + 0.006, Z_RICASSO - 0.004):      # liens de fer aux deux bouts du gainage
        tour(R, [(z - 0.004, 0.0225), (z, 0.0245), (z + 0.004, 0.0225)], "fer", cotes=8, ecrase_y=0.55, uv_tours=1.0)
    R.creer()
    C = Maille("crochets")
    zc = Z_RICASSO + 0.012
    for s in (-1, 1):   # crochets de parade : petites cornes recourbées vers la pointe
        barre(C, [(s * 0.020, 0.0050, 0.0040, 0.0), (s * 0.034, 0.0042, 0.0036, 0.002), (s * 0.044, 0.0030, 0.0030, 0.010),
                  (s * 0.047, 0.0012, 0.0016, 0.020)][:: s], "fer", zc, cotes=4, uv_l=1.0)
    C.creer()
    # ---- garde fine en fer sombre, quillons relevés vers la lame, plaque en losange
    G = Maille("croisee")
    barre(G, [(-0.150, 0.0016, 0.0022, 0.026), (-0.138, 0.0045, 0.0042, 0.014), (-0.100, 0.0050, 0.0048, 0.003),
              (-0.040, 0.0068, 0.0060, 0.0), (0.040, 0.0068, 0.0060, 0.0), (0.100, 0.0050, 0.0048, 0.003),
              (0.138, 0.0045, 0.0042, 0.014), (0.150, 0.0016, 0.0022, 0.026)], "fer", Z_HAUT + 0.008)
    plaque(G, (0, 0, Z_HAUT + 0.010), 0.016, 0.0095, 0.030, 0.018, "fer")
    G.creer()
    # ---- fusée tressée + bagues, pommeau à six pans + cristal
    zb = Z_HAUT - LP
    P = Maille("fusee")
    n = 7
    tour(P, [(zb + LP * k / n, 0.0170 * (1.0 + 0.06 * math.sin(k * 1.3))) for k in range(n + 1)], "cuir", cotes=10, ecrase_y=0.9,
         uv_tours=2.0)
    for z in (zb + 0.008, zb + LP * 0.5, Z_HAUT - 0.006):
        tour(P, [(z - 0.006, 0.0180), (z - 0.002, 0.0205), (z + 0.002, 0.0205), (z + 0.006, 0.0180)], "fer", cotes=10, ecrase_y=0.9,
             uv_tours=1.0)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(zb - 0.034, 0.0150), (zb - 0.024, 0.0230), (zb - 0.010, 0.0210), (zb, 0.0165)], "fer", cotes=6, ecrase_y=0.8, uv_tours=1.0)
    M.creer()
    J = Maille("gemmes")
    octaedre(J, (0, 0, Z_HAUT + 0.012), 0.0130, 0.0125, 0.0170, 0.0130, "rubis")        # rubis serti au centre de la garde
    octaedre(J, (0, 0, zb - 0.044), 0.0170, 0.0130, 0.0110, 0.0260, "rubis")             # cristal du pommeau
    # runes d'or serties dans la gouttière (les deux faces), du talon au milieu de la lame
    for k, f in enumerate((0.20, 0.25, 0.30, 0.40, 0.45, 0.50)):
        z = Z_GARDE + f * L_LAME
        rx, rz = (0.0045, 0.010) if k % 2 == 0 else (0.0060, 0.006)
        for s in (-1, 1):
            octaedre(J, (0, s * 0.0062, z), rx, 0.0016, rz, rz, "or")
    J.creer()
    vide("prise", Z_PRISE)
    vide("garde", Z_GARDE + 0.010)
    vide("pointe", zt)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, "claymore_longue.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = 0
    zmin, zmax = 9.0, -9.0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
    print("CLAYMORE_LONGUE tris=%d longueur=%.3f lame=%.3f fusee=%.2f -> %s" % (tris, zmax - zmin, L_LAME, LP, glb))


construire()
