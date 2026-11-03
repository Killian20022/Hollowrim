# Armures UNIQUES HD (charte CHARTE_ARMURES_HD.md) : heaume_jarl, cuirasse_gardiens, gantelets_hrafn, bottes_rodeur,
# capuche_thaumaturge, brigandine_braise. Génère les glb portés (assets/modeles/armures/porte/<id>.glb) et au sol (sol/<id>.glb).
#   blender.exe -b --python sources_blender/armures/uniques/generer_uniques.py -- [ids...] [--apercu DOSSIER] [--pas-sol] [--pas-export]
# Sans id : les 6 pièces. Chausses des uniques : chausses_uniques.py.
import bpy, sys, os, math, importlib
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(1, os.path.join(ICI, "..", "lourdes"))
sys.path.insert(2, os.path.join(ICI, "..", "fer_acier"))
import commun as C
import hd as H
import pieces_hd as PH
import decor_uniques as DU
importlib.reload(C); importlib.reload(H); importlib.reload(PH); importlib.reload(DU)
from mathutils import Vector, Matrix
from decor_uniques import ligne_runes, rune, cercle, trait, poly

# ------------------------------------------------------------------------------------------------ styles
import numpy as np
RP = PH  # rectangles d'atlas de la cuirasse
ACIER = dict(pal=H.ACIER, mat="acier", mat_rebord="acier", mat_main="cuir", mat_doigts="cuir", mat_genou="acier", base=0.44, contraste=0.26,
             martele=0.22, cellule=3.0, oxyde=0.0, crasse=0.4, poli=0.5, patine=0.18, rouille=0.08, sale=0.65, poli_arete=1.0,
             rayures=1.0, r_rivet=0.72, k_rivet=0.66, graine=23, pal_cuir=H.CUIR, base_cuir=0.44, pal_maille=H.FER, base_maille=0.55,
             oxyde_maille=0.1, mat_maille="acier.maille")


def _s(b0, **kw):
    d = dict(b0); d.update(kw)
    d["peintures"] = list(kw.get("peintures", []))
    return d


# ---------------------------------------------------------------------------------------------- cuirasse des gardiens
def hook_gardiens(T, st, g):
    v_l = st["_v_l"]
    top = (0, v_l[-2], 128, v_l[-1])
    # sceau du serment sur le plastron (axe u = 64 : le devant) : cercle double, rune centrale, éclats autour ; bleu glace
    cx, cy = 64, (top[1] + top[3]) / 2 - 0.6
    cercle(T, cx, cy, 6.2, larg=0.30, pal=DU.ARGENT, k=0.85, bri=0.8, creux=0.08)
    cercle(T, cx, cy, 4.6, larg=0.22, pal=DU.ARGENT, k=0.7, bri=0.7, creux=0.06)
    for i in range(8):
        a = math.tau * i / 8
        trait(T, (cx + 6.6 * math.cos(a), cy + 6.6 * math.sin(a)), (cx + 8.4 * math.cos(a), cy + 8.4 * math.sin(a)), larg=0.25, pal=DU.ARGENT, k=0.8, bri=0.8, creux=0.05)
    rune(T, cx - 1.5, cy - 2.6, 5.2, "othala", larg=0.30, pal=DU.ARGENT, k=0.9, bri=0.9, creux=0.05)
    # runes sur les lames inférieures
    for k in range(len(v_l) - 2):
        h = v_l[k + 1] - v_l[k]
        if h > 5:
            ligne_y = v_l[k] + h * 0.42
            DU.ligne_runes(T, 36, 92, ligne_y, min(3.4, h * 0.34), g + k, larg=0.2, pal=DU.ARGENT, k=0.7, bri=0.6, creux=0.05)
    # col de fourrure : mèches en couches blanc-gris, racines dans l'ombre ; petites mèches 3D dégradées
    T.zone(PH.R_FOUR, DU.fourrure_meches(DU.BLANCHE, g + 300, lw=2.5, rh=2.1), sale=0.2, relief=0.9)
    T.zone((92, 92, 128, 100), DU.fourrure_touffe(DU.BLANCHE, g + 301, 92, 100), sale=0.15)
    DU.givre(T, [(0, v_l[0], 128, v_l[-1]), PH.R_TASS, PH.R_EPAUL], g + 200, force=0.30)
    DU.givre(T, [PH.R_JUPE, PH.R_HAUT], g + 210, force=0.18)


# ---------------------------------------------------------------------------------------------- gantelets de Hrafn
def hook_hrafn(T, st, g):
    R = st["_R"]
    P = DU.CUIR_ROUGE
    # manchette : cuir rouge sombre bouilli, lanières noires, clous d'acier ; bord supérieur biseauté
    T.zone(R["manch"], H.cuir(P, g + 60, base=0.50, use=0.55), sale=0.7)
    x0, y0, x1, y1 = R["manch"]
    T.biseau(R["manch"], larg=2.0, haut=0.45, cotes="bh", poli=0.25)
    for yy in (y0 + 6.5, y1 - 7.5):
        T.zone((x0, yy - 1.4, x1, yy + 1.4), H.cuir(DU.CUIR_NOIR, g + 61, base=0.5), sale=0.55)
        T.biseau((x0, yy - 1.4, x1, yy + 1.4), larg=0.5, haut=0.25, cotes="bh", poli=0.4)
        T.couture((x0 + 1, yy - 0.9), (x1 - 1, yy - 0.9), pas=0.9)
        T.couture((x0 + 1, yy + 0.9), (x1 - 1, yy + 0.9), pas=0.9)
    T.rivets([(x0 + 128 / 14 * (k + 0.5), (y0 + y1) / 2 - 1.5) for k in range(14)], r=0.85, pal=H.ACIER_SOMBRE, k=0.5)
    T.rivets([(x0 + 128 / 14 * (k + 0.5), (y0 + y1) / 2 + 3.5) for k in range(14)], r=0.85, pal=H.ACIER_SOMBRE, k=0.5)
    DU.ligne_runes(T, 8, 120, (y0 + y1) / 2 + 7.5, 4.2, g, pas=5.4, larg=0.22, pal=DU.CUIR_NOIR, k=0.35, bri=0.05, creux=0.12)
    # dos de la main : cuir rouge, nervures, couture
    T.zone(R["main"], H.cuir(P, g + 62, base=0.55, use=0.5), sale=0.6)
    T.biseau(R["main"], larg=1.0, haut=0.3, cotes="bh", poli=0.2)
    for x in (22, 44, 66, 88, 110):
        T.ligne_v(x, R["main"][1] + 2, R["main"][3] - 2, larg=0.5, prof=0.18)
        T.couture((x + 1.4, R["main"][1] + 2), (x + 1.4, R["main"][3] - 2), pas=1.0)
    # lames de cuir du dos de la main, bord d'acier
    nl = st.get("lames_main", 2)
    hy = (R["lames"][3] - R["lames"][1]) / nl
    for k in range(nl):
        rl = (R["lames"][0], R["lames"][1] + hy * k, R["lames"][2], R["lames"][1] + hy * (k + 1))
        T.zone(rl, H.cuir(P, g + 63 + k, base=0.52, use=0.6), sale=0.65)
        T.biseau(rl, larg=1.4, haut=0.4, cotes="h", poli=0.2)
        T.zone((rl[0], rl[3] - 2.2, rl[2], rl[3]), H.metal(H.ACIER_SOMBRE, g + 70 + k, base=0.38, contraste=0.25, crasse=0.4, poli=0.7), sale=0.4, poli=0.5)
        T.biseau((rl[0], rl[3] - 2.2, rl[2], rl[3]), larg=0.7, haut=0.35, cotes="bh", poli=1.0)
        T.rivets([(128 / 12 * (q + 0.5), rl[3] - 1.1) for q in range(12)], r=0.55, pal=H.ACIER_SOMBRE, k=0.55)
    # doigts : cuir rouge, plis, clous aux articulations
    T.zone(R["doigts"], H.cuir(P, g + 66, base=0.48, use=0.7), sale=0.65)
    dy0, dy1 = R["doigts"][1], R["doigts"][3]
    for di in range(5):
        x = di * 25.6
        T.couture((x + 2, dy0 + 3), (x + 2, dy1 - 3), pas=1.1)
        T.couture((x + 23.6, dy0 + 3), (x + 23.6, dy1 - 3), pas=1.1)
        for f in (0.33, 0.66):
            T.ligne_h(dy0 + (dy1 - dy0) * f, x + 3, x + 22.6, larg=0.4, prof=0.2)
        T.rivets([(x + 12.8, dy0 + (dy1 - dy0) * f) for f in (0.2, 0.5, 0.8)], r=0.8, pal=H.ACIER_SOMBRE, k=0.5)
    # griffes : acier sombre poli, rainure centrale, pointe claire
    g0, g1 = R["griffe"][1], R["griffe"][3]
    T.zone(R["griffe"], H.metal(H.ACIER_SOMBRE, g + 80, base=0.55, contraste=0.25, crasse=0.15, poli=0.85, patine=0.1), sale=0.2, poli=0.8)
    T.biseau(R["griffe"], larg=0.6, haut=0.35, cotes="bh", poli=1.0)
    # le cuir ne brille pas : brillance et arêtes polies plafonnées partout sauf sur les griffes d'acier
    gx0, gy0, gx1, gy1 = T._px(R["griffe"])
    pol = T.poli.copy(); bri = T.bri.copy()
    T.poli[:] = np.minimum(T.poli, 0.22); T.bri[:] = np.minimum(T.bri, 0.30)
    T.poli[gy0:gy1, gx0:gx1] = pol[gy0:gy1, gx0:gx1]; T.bri[gy0:gy1, gx0:gx1] = bri[gy0:gy1, gx0:gx1]


# ---------------------------------------------------------------------------------------------- bottes du rôdeur
def hook_rodeur(T, st, g):
    R = st["_R"]
    GLACE = ("#12304c", "#2d6a9a", "#6cb6e4", "#bfe9ff", "#f0fbff")
    # tige : peau en mèches blanc-gris (racines sombres, pointes claires) ; panneau de cuir clair lacé en croix sur le devant ;
    # runes de course bleu glace de chaque côté (matériau « fourrure.runes » : légère lueur)
    T.zone(R["botte"], DU.fourrure_meches(DU.BLANCHE, g + 10, lw=3.0, rh=2.6), sale=0.25, relief=0.9)
    x0, y0, x1, y1 = R["botte"]
    for xf in (x0 + 64,):
        pan = (xf - 10, y0 + 4, xf + 10, y1 - 3)
        T.zone(pan, H.cuir(DU.CUIR_PALE, g + 11, base=0.62, use=0.4), sale=0.5)
        T.biseau(pan, larg=1.2, haut=0.45, cotes="bhgd", poli=0.15)
        T.couture((pan[0] + 1.6, pan[1] + 2), (pan[0] + 1.6, pan[3] - 2), pas=0.8)
        T.couture((pan[2] - 1.6, pan[1] + 2), (pan[2] - 1.6, pan[3] - 2), pas=0.8)
        for yy in range(int(pan[1] + 5), int(pan[3] - 8), 8):
            trait(T, (xf - 7.2, yy), (xf + 7.2, yy + 8), larg=0.95, pal=DU.CUIR_NOIR, k=0.62, bri=0.05, saillie=0.30)
            trait(T, (xf + 7.2, yy), (xf - 7.2, yy + 8), larg=0.95, pal=DU.CUIR_NOIR, k=0.62, bri=0.05, saillie=0.34)
            T.rivets([(xf - 8.0, yy), (xf + 8.0, yy), (xf - 8.0, yy + 8), (xf + 8.0, yy + 8)], r=0.75, pal=H.LAITON, k=0.55)
        # sangle de cheville et de mollet : bande de cuir clair par-dessus la lacée
        for yy in (y0 + 11, y0 + 38):
            T.zone((xf - 12, yy - 1.5, xf + 12, yy + 1.5), H.cuir(DU.CUIR_PALE, g + 12, base=0.5), sale=0.5)
            T.biseau((xf - 12, yy - 1.5, xf + 12, yy + 1.5), larg=0.5, haut=0.3, cotes="bhgd", poli=0.2)
            T.rivets([(xf, yy)], r=1.0, pal=H.LAITON, k=0.6)
    # runes de course : deux bandes (côté extérieur et intérieur de la jambe), traits brodés en relief, très lumineux
    for xr0, xr1 in ((x0 + 14, x0 + 50), (x0 + 78, x0 + 114)):
        for yy in (y0 + 21.0, y0 + 44.0):
            DU.ligne_runes(T, xr0, xr1, yy, 7.0, g + int(xr0 + yy), pas=6.2, larg=0.42, pal=GLACE, k=0.9, bri=0.8, saillie=0.20)
            for ly in (yy - 1.7, yy + 8.6):
                trait(T, (xr0, ly), (xr1, ly), larg=0.32, pal=GLACE, k=0.75, bri=0.7, saillie=0.14)
    # revers : fourrure plus longue ; petites mèches 3D dégradées
    T.zone(R["fourb"], DU.fourrure_meches(DU.BLANCHE, g + 13, lw=2.8, rh=2.5), sale=0.2, relief=0.9)
    T.zone((0, 60, 64, 72), DU.fourrure_touffe(DU.BLANCHE, g + 14, 60, 72), sale=0.15)
    # semelle et ourlet : cuir brun, passepoil
    T.zone(R["sem"], H.cuir(DU.CUIR_PALE, g + 15, base=0.42), sale=0.6)
    T.couture((R["sem"][0] + 1, R["sem"][1] + 2), (R["sem"][2] - 1, R["sem"][1] + 2), pas=0.8)
    T.zone(R["sol"], H.cuir(DU.CUIR_NOIR, g + 16, base=0.3), sale=0.9)
    T.zone(R["sang"], H.cuir(DU.CUIR_PALE, g + 17, base=0.45), sale=0.6)
    T.biseau(R["sang"], larg=1.0, haut=0.25, cotes="bh", poli=0.2)
    # genouillère : cuir clair matelassé bordé de couture, rune de course
    xk0, yk0, xk1, yk1 = R["genou"]
    hk = (yk1 - yk0) / 2
    rk = (xk0, yk0, xk1, yk0 + hk)
    T.zone(rk, H.cuir(DU.CUIR_PALE, g + 18, base=0.5, use=0.5), sale=0.5)
    T.biseau(rk, larg=2.0, haut=0.5, cotes="bhgd", poli=0.3)
    T.couture((xk0 + 3, yk0 + 3), (xk1 - 3, yk0 + 3), pas=0.9)
    T.couture((xk0 + 3, yk0 + hk - 3), (xk1 - 3, yk0 + hk - 3), pas=0.9)
    rune(T, (xk0 + xk1) / 2 - 3, yk0 + hk / 2 - 4.5, 9, "raido", larg=0.45, pal=GLACE, k=0.9, bri=0.8, saillie=0.2)
    T.zone((xk0, yk0 + hk, xk1, yk1), H.cuir(DU.CUIR_PALE, g + 19, base=0.5), sale=0.5)
    # le cuir ne luit pas : arêtes polies plafonnées partout sauf sur les runes
    T.poli[:] = np.minimum(T.poli, 0.25)


# ---------------------------------------------------------------------------------------------- brigandine de braise
def plaque_poitrine(T, st, g):
    """Plaque de poitrine : plastron de fer noir riveté au centre de la brigandine, fentes de braise en chevrons et noyau incandescent."""
    v_l = st["_v_l"]
    y0, y1 = v_l[-2] + 0.4, v_l[-1] - 0.4
    x0, x1 = 64 - 17, 64 + 17
    rect = (x0, y0, x1, y1)
    T.zone(rect, H.metal(H.FER, g + 90, base=0.34, contraste=0.30, martele=0.5, cellule=2.4, crasse=0.5, poli=0.45, patine=0.2), sale=0.6, poli=0.3)
    T.biseau(rect, larg=1.6, haut=0.55, cotes="bhgd", poli=0.9)
    cx, cy = 64.0, (y0 + y1) / 2
    hh = (y1 - y0)
    T.rivets([(x0 + 2.0, y0 + 2.0 + q * (hh - 4.0) / 5) for q in range(6)] + [(x1 - 2.0, y0 + 2.0 + q * (hh - 4.0) / 5) for q in range(6)], r=0.7, pal=H.FER, k=0.62)
    fl = DU.BRAISE
    # chevrons de braise descendant vers le noyau, fentes étroites
    for k in range(3):
        d = hh * (0.14 + 0.13 * k)
        DU.poly(T, [(cx - 11 + k * 1.4, cy + hh * 0.30 - d * 0.15), (cx, cy + hh * 0.30 - d), (cx + 11 - k * 1.4, cy + hh * 0.30 - d * 0.15)],
                larg=0.42, pal=fl, k=0.72 - 0.06 * k, bri=0.0, creux=0.22)
    DU.trait(T, (cx, y0 + 2.0), (cx, cy + hh * 0.28), larg=0.38, pal=fl, k=0.66, bri=0.0, creux=0.2)
    # noyau : losange incandescent serti dans un cadre de fer
    r_ = 4.4
    DU.poly(T, [(cx, cy - r_), (cx + r_ * 0.75, cy), (cx, cy + r_), (cx - r_ * 0.75, cy)], fermer=True, larg=0.9, pal=("#3a2a22", "#6b5648", "#9b8575"), k=0.55, bri=0.7, saillie=0.35)
    DU.cercle(T, cx, cy, 1.5, larg=1.3, pal=fl, k=0.95, bri=0.0)
    DU.cercle(T, cx, cy, 2.8, larg=0.55, pal=fl, k=0.78, bri=0.0)


def hook_braise(T, st, g):
    v_l = st["_v_l"]
    E = DU.ecailles
    T.zone(PH.R_JUPE, E(DU.CENDRE, g + 20, tip=3.2, base=0.58, braise=1.6), sale=0.4, relief=1.0)
    T.zone(PH.R_HAUT, E(DU.CENDRE, g + 21, tip=2.4, base=0.55, braise=1.0), sale=0.4)
    for k in range(len(v_l) - 1):
        rect = (0, v_l[k], 128, v_l[k + 1])
        T.zone(rect, E(DU.CENDRE, g + 22 + k, tip=4.0, base=0.60, braise=2.0, brillant=0.28), sale=0.35)
        T.biseau(rect, larg=min(1.4, (v_l[k + 1] - v_l[k]) * 0.14), haut=0.4, cotes="b", poli=0.5)
        # liseré de braise le long de l'ourlet de chaque lame (fil incandescent localisé)
        for x0 in range(0, 128, 16):
            if H._hash(x0, k, g + 5) > 0.45:
                trait(T, (x0 + 1, rect[1] + 0.7), (x0 + 11 + 5 * H._hash(x0, k, g + 6), rect[1] + 0.7), larg=0.3, pal=DU.BRAISE, k=0.55, bri=0.0, creux=0.0, saillie=0.0)
    # rivets de fer noir le long des lames et des épaulières
    nl = st.get("lames_epaule", 2)
    T.zone(PH.R_EPAUL, E(DU.CENDRE, g + 40, tip=4.2, base=0.6, braise=1.4, brillant=0.28), sale=0.35)
    T.biseau(PH.R_EPAUL, larg=1.2, haut=0.35, cotes="gd", poli=0.4)
    # manches : cuir cendré matelassé
    T.zone(PH.R_MANCHE, H.cuir(DU.CENDRE, g + 41, base=0.5, use=0.6), sale=0.6)
    for x in (2, 42, 82):
        T.couture((x, 112.5), (x, 127.5), pas=0.9)
    # ceinture, sangles, sacoche : cuir noir cendré, boucles d'acier noirci
    for rect in (PH.R_CEINT, PH.R_SANGLE, PH.R_SACOCHE):
        T.zone(rect, H.cuir(DU.CUIR_NOIR, g + 42, base=0.5, use=0.5), sale=0.55)
        T.biseau(rect, larg=0.6, haut=0.22, cotes="bh", poli=0.3)
    T.couture((1, 81.2), (99, 81.2), pas=0.9); T.couture((1, 86.8), (99, 86.8), pas=0.9)
    T.zone(PH.R_BOUCLE, H.metal(H.FER, g + 43, base=0.45, contraste=0.25, crasse=0.3, poli=0.6), sale=0.5, poli=0.6)
    T.biseau(PH.R_BOUCLE, larg=0.5, haut=0.35, cotes="bhgd", poli=1.0)
    T.rivets([(128 / 16 * (q + 0.5), v_l[0] + 1.4) for q in range(16)], r=0.6, pal=H.FER, k=0.6)
    T.zone(PH.R_TASS, E(DU.CENDRE, g + 44, tip=3.4, base=0.5, braise=0.7), sale=0.4)
    plaque_poitrine(T, st, g)


def capuche_thaumaturge(r):
    import pieces as PC       # lourdes/pieces.py : forme v3 des mages (validée), seule la peinture est refaite en HD
    ob = PC.capuche(r, dict(id="capuche_thaumaturge"))
    DU.capuche_hd(ob, os.path.join(ICI, "..", "lourdes", "bake_capuche_v3.png"))
    return ob


PIECES = {
    "capuche_thaumaturge": capuche_thaumaturge,
    # --- Heaume du Jarl : couronne de fer noir à neuf pointes sur un heaume à nasal
    "heaume_jarl": lambda r: PH.casque(r, _s(ACIER, id="heaume_jarl", pal=DU.FER_NOIR, mat="fer.noir", mat_rebord="fer.noir", base=0.5,
                                            contraste=0.28, martele=0.3, cellule=2.6, oxyde=0.0, crasse=0.35, poli=0.65, patine=0.2, bombe=0.008,
                                            rivets_rebord=18, larg_bande=0.012, haut_bande=0.0045, rayures=0.8, graine=71,
                                            bandes=[0.0, math.pi / 2, math.pi, 3 * math.pi / 2],
                                            decor=[PH.deco_nasal, DU.deco_couronne], mat_couronne="fer")),
    # --- Cuirasse des gardiens du serment : acier ancien bleuté pris par le givre, col de fourrure blanche, sceau gravé
    "cuirasse_gardiens": lambda r: PH.cuirasse(r, _s(ACIER, id="cuirasse_gardiens", mat="acier.givre", pal=DU.ACIER_GIVRE, pal_cuir=DU.CUIR_NOIR,
                                                     pal_maille=DU.ACIER_GIVRE, base_maille=0.42, base_cuir=0.5, base=0.40, graine=37,
                                                     n=20, z_lames=[1.04, 1.11, 1.18, 1.43], bombe=0.025, tablier=28, fentes=(-100, 100, 180),
                                                     rivets_lame=16, rivets_milieu=True, tassettes=(58, 100),
                                                     sangles=[((40, 1.43), (-30, 1.04)), ((-40, 1.43), (30, 1.04))], disque=(-33, 1.365),
                                                     lames_epaule=3, rivets_epaule=7, bord_roule=True, mat_maille="acier.maille",
                                                     fourrure=dict(gonfle=0.9, meches=0.06, cote=0.2, r_max=0.17, r_max_cote=0.08, phis_cote=(-6, 0, 10, 24, 38, 52), touffes=2, long_touffes=0.055),
                                                     pal_fourrure=DU.BLANCHE, base_fourrure=0.7, peintures=[hook_gardiens])),
    # --- Gantelets de Hrafn : cuir rouge sombre, clous et lames d'acier, griffes d'acier aux doigts
    "gantelets_hrafn": lambda r: PH.gantelets(r, _s(ACIER, id="gantelets_hrafn", pal=H.ACIER, mat="cuir", mat_rebord="cuir", mat_main="cuir",
                                                    mat_doigts="cuir", mat_griffes="acier", griffes=0.034, main_cuir=True, lames_main=2,
                                                    evasement=0.02, jointures=False, debut_manchette=0.5, graine=81, peintures=[hook_hrafn])),
    # --- Bottes du rôdeur des neiges : fourrure blanche, lanières de cuir clair, runes de course
    "bottes_rodeur": lambda r: PH.bottes(r, _s(ACIER, id="bottes_rodeur", pal=H.ACIER, mat="fourrure", mat_botte="fourrure.runes", mat_genou="cuir", touffes_tige=True, long_touffes=0.042,
                                               greve=False, revers_fourrure=True, ep_revers=1.0, sangles=(0.10, 0.26), ailette=0.0, graine=91,
                                               pal_fourrure=DU.BLANCHE, base_fourrure=0.62, peintures=[hook_rodeur])),
    # --- Brigandine de braise : écailles de cuir cendré, jours de braise, ceinture de cuir noir
    "brigandine_braise": lambda r: PH.cuirasse(r, _s(ACIER, id="brigandine_braise", mat="cuir.braise", mat_maille="cuir.braise", pal=DU.CENDRE,
                                                     pal_cuir=DU.CUIR_NOIR, graine=101, base=0.5, n=22, z_lames=[1.04, 1.12, 1.20, 1.43], bombe=0.02,
                                                     tablier=30, fentes=(-100, 100, 180), dechire=0.02, rivets_lame=0, tassettes=(58, 100),
                                                     sangles=[((40, 1.43), (-30, 1.04))], sacoche=-38, lames_epaule=2, rivets_epaule=0,
                                                     z_ourlet=0.72, peintures=[hook_braise])),
}

MASQUE = {"tete": {"Hair_Long"}, "torse": {"tunique", "mante", "accessoires", "pantalon"}, "mains": set(), "pieds": {"bottes"}}


def _famille(pid):
    if "casque" in pid or "heaume" in pid or "capuche" in pid:
        return "tete"
    if "cuirasse" in pid or "brigandine" in pid:
        return "torse"
    if "gant" in pid:
        return "mains"
    return "pieds"


VUE = {"tete": ((0, 0, 1.66), 0.55), "torse": ((0, 0, 1.12), 1.3), "mains": ((0.6, 0, 1.45), 0.75), "pieds": ((0, 0, 0.3), 0.8)}


def apercu(r, dossier, pid, vues=("face", "34", "profil", "dos"), corps=True):
    import apercu as AP
    importlib.reload(AP)
    cache = MASQUE.get(_famille(pid), set())
    for n, o in r.corps.items():
        o.hide_render = (not corps) or n in cache
    cible, ortho = VUE[_famille(pid)]
    AP.rendre(os.path.join(dossier, pid), cible=cible, ortho=ortho, dist=3.0, vues=vues, taille=(480, 640))


def version_sol(r, ob, pid):
    """Pièce posée : copie sans peau d'os ni corps ; cuirasse couchée sur le dos (manches rabattues), casque sur le côté avec
    doublure, gantelets à plat côte à côte, bottes debout ; pivot au sol."""
    import bmesh
    c = ob.copy(); c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.parent = None
    c.modifiers.clear()
    c.vertex_groups.clear()
    c.matrix_world = Matrix.Identity(4)
    me = c.data
    if "cuirasse" in pid or "brigandine" in pid:
        for v in me.vertices:
            p = v.co
            if abs(p.x) > 0.2 and 1.3 < p.z < 1.54:
                s = 1 if p.x > 0 else -1
                o = Vector((0.2 * s, p.y, 1.45))
                d = p - o
                a = math.radians(70) * s
                v.co = o + Vector((d.x * math.cos(a) + d.z * math.sin(a), d.y, -d.x * math.sin(a) + d.z * math.cos(a)))
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    elif "casque" in pid or "heaume" in pid:
        bm = bmesh.new(); bm.from_mesh(me)
        col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        faces = list(bm.faces)
        ret = bmesh.ops.duplicate(bm, geom=faces)
        nf = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        bm.normal_update()
        for v in nv:
            v.co = v.co - v.normal * 0.005
        bmesh.ops.reverse_faces(bm, faces=nf)
        for f in nf:
            for lp in f.loops:
                lp[col] = (0.2, 0.18, 0.16, 1.0)
        bm.to_mesh(me); bm.free()
        me.transform(Matrix.Rotation(math.radians(-80), 4, "Y") @ Matrix.Rotation(math.radians(12), 4, "X"))
    elif "gant" in pid:
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.52
    elif "botte" in pid:
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.05
    # NEIGE : le shader ps1 fait tenir la neige du monde sur les faces tournées vers le haut des objets dont la couleur de sommet a
    # alpha >= 0,5 (blocs blancs / noirs lus dans la texture à des cases du monde). Pièce posée à plat = faces vers le haut : alpha 0.
    ca = me.color_attributes.get("Col")
    if ca is not None:
        for d in ca.data:
            d.color = (d.color[0], d.color[1], d.color[2], 0.0)
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = list(me.color_attributes).index(ca)
    zmin = min(v.co.z for v in me.vertices)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    me.transform(Matrix.Translation((-cx, -cy, -zmin)))
    chemin = os.path.join(C.SOL, pid + ".glb")
    os.makedirs(C.SOL, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.context.view_layer.objects.active = c
    kw = dict(filepath=chemin, export_format="GLB", use_selection=True, export_skins=False, export_animations=False,
              export_yup=True, export_materials="EXPORT")
    if "export_vertex_color" in bpy.ops.export_scene.gltf.get_rna_type().properties:
        kw["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORT SOL", chemin)
    bpy.data.objects.remove(c, do_unlink=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    dossier = None
    if "--apercu" in argv:
        k = argv.index("--apercu"); dossier = argv[k + 1]; del argv[k:k + 2]
    sol = "--pas-sol" not in argv
    exporter = "--pas-export" not in argv
    argv = [a for a in argv if not a.startswith("--")]
    ids = argv or list(PIECES)
    for pid in ids:
        r = C.charger_reference()
        ob = PIECES[pid](r)
        print("PIECE", pid, C.compter_tris(ob), "tris", "groupes", len(ob.vertex_groups),
              "texture", next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image.size[:])
        if exporter:
            C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
        if sol and exporter:
            version_sol(r, ob, pid)
        if dossier:
            os.makedirs(dossier, exist_ok=True)
            apercu(r, dossier, pid)
            for o in r.corps.values():
                o.hide_render = True
            import apercu as AP
            cible, ortho = VUE[_famille(pid)]
            AP.rendre(os.path.join(dossier, pid + "_seul"), cible=cible, ortho=ortho, dist=3.0, vues=("face", "34", "dos"), taille=(480, 640))


main()
