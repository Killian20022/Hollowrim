# GESTES LOURDS du viewmodel FPS (branche combat/gestes_lourds) — HACHES, MASSES / MARTEAUX à une main, GRAND MARTEAU à
# deux mains : clips du BRAS DROIT à images clés, bibliothèque À PART des coups d'épée (rien n'y change).
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/gestes_lourds.py -- --godot \
#       [--clips=h_a,m_c] [--mesurer]
#
# Même solveur, même repère caméra, même prise que l'épée (anim_bras_epee.py lu tel quel SANS le modifier, comme
# gestes_2mains.py). Sortie : assets/animations/bras_lourds.tres (AnimationLibrary, préfixe « lourd/ » dans le jeu,
# AnimateurBras.LOURDS) ; les tables de gestes par famille sont dans scripts/combat/gestes_lourds.gd (GestesLourds).
# Le grand marteau est tenu à deux mains : sa main gauche est posée par IK sur le manche (mains._poser_deux_mains,
# combat/claymore_2mains), ici seul le bras droit est animé ; poing gardé dans le tiers bas-central pour que la gauche suive.
#
# Poses écrites à la main en ESPACE ÉCRAN (le retarget des captures, buste qui tourne, ne se lit pas depuis une caméra fixe).
# RYTHME mesuré sur les captures Mixamo (references/mixamo, vitesse du poignet droit, 30 i/s) :
#   « Standing Melee Attack Downward » (écrasement) : armé 0,70 s (1,5 → 3 m/s), CHUTE 0,20 s (jusqu'à 9,3 m/s), arrêt mort
#     en une image (7 → 2,8 m/s), retour 1,3 s → masses, marteaux, grand marteau ;
#   « Standing Melee Attack Backhand » (crochet) : armé 0,63 s, frappe 0,43 s (pic 11 m/s) → crochets de la masse ;
#   haches : la même chute, raccourcie (taille courte et cassante : armé ~0,2 s, frappe ~0,1 s, arrêt net + recul).
# ARCS : entre deux clés Blender interpole les rotations des articulations (Bézier) : la tête de l'arme décrit un arc
# autour de l'épaule ; les clés intermédiaires (« passe ») sont posées SUR cet arc (poing qui tourne autour de l'épaule,
# manche qui pivote régulièrement), l'impact est une clé « lin » (arrêt net : la vitesse ne retombe pas avant le contact)
# suivie d'un petit recul amorti.
#
# Clés en plus de gestes_bras_epee.py (lues par le coût ci-dessous, ajouté au solveur) :
#   fil=(x, y, z)   direction voulue du TRANCHANT (+X du modèle : fil de la hache, face du marteau) pour une pose tenue ;
#   mouvement=...   comme pour l'épée, mais le tranchant MÈNE (pas le dos : un coût si +X part en arrière du mouvement).
import os, sys, math

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
_src = open(os.path.join(ICI, "anim_bras_epee.py"), encoding="utf-8").read()
_src = _src[: _src.rstrip().rfind("main()")]          # le fichier finit par « main() » : on garde tout le reste
NS = {"__file__": os.path.join(ICI, "anim_bras_epee.py"), "__name__": "anim_bras_epee"}
exec(compile(_src, "anim_bras_epee.py", "exec"), NS)

import gestes_bras_epee as G  # noqa: E402
from mathutils import Vector  # noqa: E402

E = G.E
cle = G.cle

_cout_epee = NS["_cout"]


def _cout_lourd(W, c, kfr):
    """Coût de l'épée + orientation du TRANCHANT : il mène le mouvement (frappes), ou suit « fil » (poses tenues)."""
    v = _cout_epee(W, dict(c, poids_roulis=0.0) if ("fil" in c and "mouvement" not in c and "roulis" not in c) else c, kfr)
    x = W.col[0].to_3d().normalized()
    y = W.col[1].to_3d().normalized()
    if "mouvement" in c and c.get("mene", False):
        mv = Vector(c["mouvement"])
        mv = (mv - y * mv.dot(y))
        if mv.length > 1e-4:
            v += POIDS_MENE * math.degrees(x.angle(mv.normalized() * SENS_MENE))
    elif "fil" in c:
        f = Vector(c["fil"])
        f = f - y * f.dot(y)
        if f.length > 1e-4:
            v += c.get("poids_fil", 0.35) * math.degrees(x.angle(f.normalized()))
    return v


NS["_cout"] = _cout_lourd
POIDS_MENE = float(NS["ARGS"].get("poids_mene", "0.25"))
SENS_MENE = float(NS["ARGS"].get("sens_mene", "1"))

# --- torsion de l'avant-bras BORNÉE par clé (« tb » : centre, ± TB_DEMI°) : la torsion progresse régulièrement d'une clé à
# l'autre (jamais de retournement +90 → -90 en un coup, ce qui donnait des coups saccadés) ; le solveur cherche ensuite le
# poignet et le coude qui donnent la direction de manche voulue ---------------------------------------------------------
TB_DEMI = 10
_poser_epee = NS["poser"]


def _poser_borne(c, cote="r"):
    if "tb" not in c:
        return _poser_epee(c, cote)
    garde = NS["LIM_TORSION_L"], NS["LIM_TORSION"]
    b = (int(c["tb"]) - TB_DEMI, int(c["tb"]) + TB_DEMI)
    NS["LIM_TORSION_L"] = NS["LIM_TORSION"] = b
    try:
        return _poser_epee(dict(c, torsion=c["tb"]), cote)
    finally:
        NS["LIM_TORSION_L"], NS["LIM_TORSION"] = garde


def _poser_diag(c, cote="r"):
    r = _poser_borne(c, cote)
    if "diag" in NS["ARGS"]:
        p, t, x = tete_ecran()
        print("CLE %-12s poing (%.2f,%.2f) tete (%.2f,%.2f) fil (%.2f,%.2f,%.2f)" % (c.get("nom", "?"), p[0], p[1], t[0], t[1], x.x, x.y, x.z))
    return r


NS["poser"] = _poser_diag


def tete_ecran(longueur=0.62):
    """Position écran (x, y) du poing et de la tête de l'arme (à `longueur` m le long du manche) pour la pose courante."""
    W = NS["CAM_DE_B"] @ NS["A"].pose.bones["hand_r"].matrix @ NS["PRISE_D"]
    p = W @ Vector((0, NS["MILIEU_POIGNEE"], 0))
    t = W @ Vector((0, NS["MILIEU_POIGNEE"] + longueur, 0))
    e = lambda v: (v.x / max(-v.z, 1e-3) / (G.TAN_V * 16 / 9), v.y / max(-v.z, 1e-3) / G.TAN_V)
    return e(p), e(t), W.col[0].to_3d().normalized()


def trajets(actions, freq=60):
    """Trajet de la tête à l'écran pendant chaque frappe (arme → suivi) : points et cassures (angle entre deux pas)."""
    for nom, (act, longueur) in actions.items():
        mq = MARQUEURS.get(nom, {})
        if "frappe" not in mq:
            continue
        NS["A"].animation_data.action = act
        pts = []
        t = mq["arme"]
        while t <= mq["suivi"] + 1e-6:
            f = t * NS["FPS"]
            NS["scene"].frame_set(int(math.floor(f)), subframe=f - math.floor(f))
            pts.append(tete_ecran()[1])
            t += 1.0 / freq
        cass = []
        for i in range(1, len(pts) - 1):
            a = Vector((pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
            b = Vector((pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]))
            if a.length > 0.004 and b.length > 0.004:
                cass.append(round(math.degrees(a.angle(b)), 0))
            else:
                cass.append(0)
        print("TRAJET", nom, " ".join("(%.2f,%.2f)" % p for p in pts))
        print("CASSURES", nom, cass)


PT = 0.08
L = dict(large=True, poids_torsion=PT)


def pose(base, nom, **k):
    """Copie d'une pose clé (épée validée, claymore) renommée, avec retouches."""
    d = dict(base)
    d.update(k)
    d["nom"] = nom
    return d


def decale(base, nom, dx=0.0, dy=0.0, dz=0.0, **k):
    """Même poignet (k, f, r, phi figés s'il y en a), poing décalé à l'écran (dx, dy) et en profondeur (dz) : recul, tenue."""
    x, y, z = base["poing"]
    zz = -z
    ex = x / (G.TAN_V * 16 / 9 * zz) + dx
    ey = y / (G.TAN_V * zz) + dy
    return pose(base, nom, poing=E(ex, ey, zz + dz), **k)


# Bases : trajectoires DÉJÀ VALIDÉES du bras (épée : gestes_bras_epee.py, poignet qui fouette D4 / P4 aux poignets figés ;
# vertical V2 / V3 ; revers R ; deux mains : gestes_2mains.py de combat/claymore_2mains). Elles sont continues (la torsion
# de l'avant-bras progresse d'une clé à l'autre, pas de retournement) ; les gestes lourds en changent le RYTHME (armé
# lent, chute rapide), l'IMPACT (clé « lin » : arrêt net de la tête, puis recul amorti, tenue lourde), l'amplitude
# (haches : coupées à l'impact, pas de long suivi) et les tenues de repos.

# =====================================================================================================================
# HACHES (une main)
# =====================================================================================================================
# repos : manche tenu bas (le poing descend au bout du manche, PRISE de GestesLourds), tête lourde penchée vers l'avant
REPOS_H = dict(nom="repos_h", poing=E(0.50, -0.72, 0.53), lame=(-0.20, 0.80, -0.56), roulis=55, coude=(1, -0.8, 0.2), torsion=40, **L)
# --- 1 : diagonale haut-droite -> bas-gauche : le poignet armé (tête à droite, en arrière) claque, la tête devance le poing
# et MORD au centre-bas (D4 de l'épée, coupée à l'impact) ---
H1_ARME = pose(G.D4_ARME, "H1_arme")
H1_TENSION = pose(G.D4_TENSION, "H1_tension")
H1_ENTREE = pose(G.D4_ENTREE, "H1_entree")
H1_MILIEU = pose(G.D4_MILIEU, "H1_milieu")
H1_IMPACT = pose(G.D4_FIN, "H1_impact", interp="lin")
H1_RECUL = decale(G.D4_FIN, "H1_recul", dx=0.03, dy=0.05, dz=-0.03)          # la tête rebondit un peu en arrière
H1_TIENT = decale(G.D4_FIN, "H1_tient", dx=0.02, dy=0.03, dz=-0.02)
# --- 2 : revers haut-gauche -> bas-droite (armé au-dessus de l'épaule gauche ; revers R de l'épée, coupé à l'impact) ---
H2_ARME = pose(G.R_ARME, "H2_arme", poing=E(-0.22, 0.04, 0.50), **L)
H2_TENSION = pose(G.R_TENSION, "H2_tension", poing=E(-0.27, 0.08, 0.49), **L)
H2_MILIEU = pose(G.R_MILIEU, "H2_milieu", **L)
H2_IMPACT = pose(G.R_FIN, "H2_impact", poing=E(0.40, -0.44, 0.56), interp="lin", **L)
H2_RECUL = pose(H2_IMPACT, "H2_recul", poing=E(0.37, -0.38, 0.54), lame=(0.82, 0.12, -0.56), interp="amorti")
H2_TIENT = pose(H2_RECUL, "H2_tient", poing=E(0.38, -0.40, 0.54))
# --- 3 : taille verticale (V3 de l'épée : armé court au coin haut droit, la tête tombe dans un plan vertical, le poignet
# casse à l'impact) ---
H3_ARME = pose(G.V3_ARME, "H3_arme")
H3_TENSION = pose(G.V3_TENSION, "H3_tension")
H3_ENTREE = pose(G.V3_ENTREE, "H3_entree")
H3_MILIEU = pose(G.V3_MILIEU, "H3_milieu")
H3_IMPACT = pose(G.V3_FIN, "H3_impact", interp="lin")
H3_RECUL = pose(G.V3_FIN, "H3_recul", poing=E(0.36, -0.08, 0.58), lame=(-0.45, -0.55, -0.70))
H3_TIENT = pose(G.V3_SUIVI, "H3_tient")
# --- puissante : levée au-dessus de la tête (V2), tenue pendant la charge, chute verticale ---
HP_CHARGE = pose(G.V2_TENSION, "HP_charge")
HP_ARME = pose(G.V2_TENSION, "HP_arme", poing=E(0.32, 0.45, 0.57), lame=(-0.03, 0.66, 0.75))
HP_ENTREE = pose(G.V2_ENTREE, "HP_entree")
HP_MILIEU = pose(G.V2_MILIEU, "HP_milieu")
HP_IMPACT = pose(G.V2_FIN, "HP_impact", interp="lin")
HP_RECUL = pose(G.V2_FIN, "HP_recul", poing=E(0.08, -0.44, 0.61), lame=(-0.08, -0.62, -0.78))

# =====================================================================================================================
# MASSE / MARTEAU (une main) : poids en tête — armé lent, chute rapide, arrêt sourd
# =====================================================================================================================
# repos : manche tenu bas, tête lourde qui retombe vers l'avant (manche très penché vers l'avant)
REPOS_M = dict(nom="repos_m", poing=E(0.52, -0.76, 0.51), lame=(-0.12, 0.62, -0.78), roulis=45, coude=(1, -0.8, 0.2), torsion=40, **L)
# --- 1 : crochet droite -> gauche (P4 de l'épée : poignet armé à droite, la tête fouette vers la gauche) ---
M1_ARME = pose(G.P4_ARME, "M1_arme")
M1_TENSION = pose(G.P4_TENSION, "M1_tension")
M1_ENTREE = pose(G.P4_ENTREE, "M1_entree")
M1_MILIEU = pose(G.P4_MILIEU, "M1_milieu")
M1_IMPACT = pose(G.P4_FIN, "M1_impact", interp="lin")
M1_RECUL = decale(G.P4_FIN, "M1_recul", dx=0.04, dy=0.02, dz=-0.02)
M1_TIENT = decale(G.P4_FIN, "M1_tient", dx=0.02, dy=-0.03, dz=-0.02)
# --- 2 : revers gauche -> droite (HG4 de l'épée, tête à plat qui revient en crochet) ---
M2_ARME = pose(G.HG4_ARME, "M2_arme")
M2_TENSION = pose(G.HG4_TENSION, "M2_tension")
M2_ENTREE = pose(G.HG4_ENTREE, "M2_entree")
M2_MILIEU = pose(G.HG4_MILIEU, "M2_milieu")
M2_IMPACT = pose(G.HG4_FIN, "M2_impact", interp="lin")
M2_RECUL = pose(G.HG4_FIN, "M2_recul", poing=E(0.25, -0.22, 0.56), lame=(-0.26, 0.05, -0.96), interp="amorti")
M2_TIENT = pose(G.HG4_FIN, "M2_tient", poing=E(0.27, -0.26, 0.56), lame=(-0.20, -0.04, -0.98), interp="amorti")
# --- 3 : écrasement du haut vers le bas (V2 de l'épée : tête levée au-dessus de la tête, tombe de tout son poids) ---
M3_ARME = pose(G.V2_ARME, "M3_arme")
M3_TENSION = pose(G.V2_TENSION, "M3_tension")
M3_ENTREE = pose(G.V2_ENTREE, "M3_entree")
M3_MILIEU = pose(G.V2_MILIEU, "M3_milieu")
M3_IMPACT = pose(G.V2_FIN, "M3_impact", interp="lin")
M3_RECUL = pose(G.V2_FIN, "M3_recul", poing=E(0.08, -0.44, 0.61), lame=(-0.08, -0.62, -0.78))
M3_TIENT = pose(G.V2_FIN, "M3_tient", poing=E(0.07, -0.52, 0.61), lame=(-0.08, -0.74, -0.67))
MP_CHARGE = pose(G.V2_TENSION, "MP_charge", poing=E(0.32, 0.46, 0.57), lame=(-0.03, 0.66, 0.75))
MP_ARME = pose(G.V2_TENSION, "MP_arme", poing=E(0.32, 0.48, 0.56), lame=(-0.02, 0.62, 0.78))

# =====================================================================================================================
# GRAND MARTEAU (deux mains) : poses des coups à deux mains de combat/claymore_2mains (gestes_2mains.py, 6e9ab10), plus
# lentes ; la main gauche tient le bas du manche par IK (mains._poser_deux_mains)
# =====================================================================================================================
REPOS_GM = dict(nom="repos_gm", poing=E(0.27, -0.40, 0.55), lame=(-0.60, 0.62, -0.50), roulis=60, coude=(1, -0.8, 0.2), clav=(6, 0),
                epaule=(-0.02, 0.0, -0.02), torsion=20, **L)
# vertical tête -> sol (C2 de la claymore, prolongé plus bas)
G1_ARME = dict(nom="G1_arme", poing=E(0.24, 0.08, 0.50), lame=(-0.20, 0.72, 0.66), roulis=G.TRANCHE, coude=(1, -0.5, 0.0), clav=(-4, 16),
               epaule=(0.0, 0.06, 0.0), torsion=20, **L)
G1_TENSION = pose(G1_ARME, "G1_tension", poing=E(0.24, 0.12, 0.49), lame=(-0.18, 0.66, 0.73))
G1_ENTREE = dict(nom="G1_entree", poing=E(0.30, 0.06, 0.56), lame=(-0.35, 0.88, -0.32), mouvement=(0, -1, -0.3), coude=(0.8, -1, 0.0),
                 clav=(8, 14), epaule=(-0.03, 0.04, -0.04), interp="passe", torsion=0, **L)
G1_MILIEU = dict(nom="G1_milieu", poing=E(0.30, -0.15, 0.60), lame=(-0.55, 0.30, -0.78), mouvement=(0, -1, 0), coude=(0.6, -1, 0.0),
                 clav=(18, 8), epaule=(-0.05, 0.02, -0.08), interp="passe", torsion=-20, **L)
G1_IMPACT = dict(nom="G1_impact", poing=E(0.18, -0.50, 0.58), lame=(-0.45, -0.55, -0.70), mouvement=(0, -0.8, 0.4), coude=(0.4, -1, 0.0),
                 clav=(24, 0), epaule=(-0.08, 0.0, -0.10), interp="lin", torsion=-40, **L)
G1_RECUL = pose(G1_IMPACT, "G1_recul", poing=E(0.19, -0.45, 0.58), lame=(-0.45, -0.46, -0.77), interp="amorti")
G1_POSE = pose(G1_IMPACT, "G1_pose", poing=E(0.17, -0.52, 0.58), lame=(-0.44, -0.58, -0.68), interp="amorti")
# diagonale haut-droite -> bas-gauche jusqu'au sol (A2 de la claymore)
G2_ARME = dict(nom="G2_arme", poing=E(0.52, 0.06, 0.58), lame=(0.30, 0.90, 0.30), roulis=G.TRANCHE, coude=(1, -0.4, 0.3), clav=(-6, 12),
               epaule=(0.02, 0.04, 0.02), torsion=40, **L)
G2_TENSION = pose(G2_ARME, "G2_tension", poing=E(0.57, 0.12, 0.57), lame=(0.36, 0.86, 0.36))
G2_ENTREE = dict(nom="G2_entree", poing=E(0.42, 0.0, 0.54), lame=(-0.25, 0.92, -0.30), mouvement=(-0.6, -0.8, 0), coude=(1, -0.6, 0.2),
                 clav=(8, 8), epaule=(-0.02, 0.02, -0.03), interp="passe", torsion=10, **L)
G2_MILIEU = dict(nom="G2_milieu", poing=E(0.16, -0.25, 0.58), lame=(-0.88, 0.30, -0.36), mouvement=(-0.5, -0.85, 0), coude=(0.6, -1, 0.0),
                 clav=(20, 4), epaule=(-0.06, 0.0, -0.07), interp="passe", torsion=-35, **L)
G2_IMPACT = dict(nom="G2_impact", poing=E(-0.04, -0.48, 0.56), lame=(-0.74, -0.56, -0.36), mouvement=(-0.6, -0.7, 0.2), coude=(0.3, -1, -0.2),
                 clav=(30, 0), epaule=(-0.11, 0.02, -0.11), interp="lin", torsion=-65, **L)
G2_RECUL = pose(G2_IMPACT, "G2_recul", poing=E(-0.01, -0.43, 0.56), lame=(-0.74, -0.46, -0.48), interp="amorti")
G2_POSE = pose(G2_IMPACT, "G2_pose", poing=E(-0.05, -0.50, 0.56), lame=(-0.72, -0.60, -0.35), interp="amorti")
GP_CHARGE = pose(G1_TENSION, "GP_charge", poing=E(0.25, 0.14, 0.48), lame=(-0.18, 0.60, 0.78))
GP_ARME = pose(GP_CHARGE, "GP_arme", poing=E(0.25, 0.17, 0.47), lame=(-0.17, 0.55, 0.82))

CLIPS = {
    # tenues
    "repos_h": [cle(REPOS_H, 0.0), cle(REPOS_H, 0.5)],
    "repos_m": [cle(REPOS_M, 0.0), cle(REPOS_M, 0.5)],
    "repos_gm": [cle(REPOS_GM, 0.0), cle(REPOS_GM, 0.5)],
    # haches : armé court, frappe très courte, arrêt net, recul, retour
    "h_a": [cle(REPOS_H, 0.0), cle(H1_ARME, 0.15), cle(H1_TENSION, 0.20), cle(H1_ENTREE, 0.235), cle(H1_MILIEU, 0.265),
            cle(H1_IMPACT, 0.30), cle(H1_RECUL, 0.35), cle(H1_TIENT, 0.42), cle(REPOS_H, 0.68)],
    "h_b": [cle(REPOS_H, 0.0), cle(H2_ARME, 0.17), cle(H2_TENSION, 0.22), cle(H2_MILIEU, 0.275),
            cle(H2_IMPACT, 0.32), cle(H2_RECUL, 0.37), cle(H2_TIENT, 0.44), cle(REPOS_H, 0.70)],
    "h_c": [cle(REPOS_H, 0.0), cle(H3_ARME, 0.17), cle(H3_TENSION, 0.22), cle(H3_ENTREE, 0.255), cle(H3_MILIEU, 0.285),
            cle(H3_IMPACT, 0.32), cle(H3_RECUL, 0.37), cle(H3_TIENT, 0.45), cle(REPOS_H, 0.72)],
    "charge_h": [cle(REPOS_H, 0.0), cle(G.V2_ARME, 0.30), cle(HP_CHARGE, 0.60)],
    "lourd_h": [cle(HP_CHARGE, 0.0), cle(HP_ARME, 0.08), cle(HP_ENTREE, 0.15), cle(HP_MILIEU, 0.19), cle(HP_IMPACT, 0.24),
                cle(HP_RECUL, 0.30), cle(REPOS_H, 0.82)],
    # masses / marteaux : armé lent (0,4-0,5 s), chute 0,14 s, arrêt sourd, tenue au contact, retour lourd
    "m_a": [cle(REPOS_M, 0.0), cle(M1_ARME, 0.40), cle(M1_TENSION, 0.48), cle(M1_ENTREE, 0.54), cle(M1_MILIEU, 0.585),
            cle(M1_IMPACT, 0.63), cle(M1_RECUL, 0.70), cle(M1_TIENT, 0.82), cle(REPOS_M, 1.20)],
    "m_b": [cle(REPOS_M, 0.0), cle(M2_ARME, 0.40), cle(M2_TENSION, 0.48), cle(M2_ENTREE, 0.53), cle(M2_MILIEU, 0.575),
            cle(M2_IMPACT, 0.62), cle(M2_RECUL, 0.69), cle(M2_TIENT, 0.80), cle(REPOS_M, 1.18)],
    "m_c": [cle(REPOS_M, 0.0), cle(M3_ARME, 0.46), cle(M3_TENSION, 0.55), cle(M3_ENTREE, 0.61), cle(M3_MILIEU, 0.655),
            cle(M3_IMPACT, 0.70), cle(M3_RECUL, 0.77), cle(M3_TIENT, 0.90), cle(REPOS_M, 1.30)],
    "charge_m": [cle(REPOS_M, 0.0), cle(M3_ARME, 0.40), cle(MP_CHARGE, 0.75)],
    "lourd_m": [cle(MP_CHARGE, 0.0), cle(MP_ARME, 0.10), cle(M3_ENTREE, 0.17), cle(M3_MILIEU, 0.215), cle(M3_IMPACT, 0.26),
                cle(M3_RECUL, 0.34), cle(M3_TIENT, 0.48), cle(REPOS_M, 1.05)],
    # grand marteau : armé très lent (0,45 s de clip, ~0,8 s en jeu), chute, la tête reste au sol, relevée lente
    "gm_a": [cle(REPOS_GM, 0.0), cle(G1_ARME, 0.45), cle(G1_TENSION, 0.55), cle(G1_ENTREE, 0.60), cle(G1_MILIEU, 0.645),
             cle(G1_IMPACT, 0.70), cle(G1_RECUL, 0.78), cle(G1_POSE, 0.95), cle(REPOS_GM, 1.40)],
    "gm_b": [cle(REPOS_GM, 0.0), cle(G2_ARME, 0.42), cle(G2_TENSION, 0.52), cle(G2_ENTREE, 0.57), cle(G2_MILIEU, 0.615),
             cle(G2_IMPACT, 0.67), cle(G2_RECUL, 0.75), cle(G2_POSE, 0.92), cle(REPOS_GM, 1.38)],
    "charge_gm": [cle(REPOS_GM, 0.0), cle(G1_ARME, 0.45), cle(GP_CHARGE, 0.85)],
    "lourd_gm": [cle(GP_CHARGE, 0.0), cle(GP_ARME, 0.12), cle(G1_ENTREE, 0.19), cle(G1_MILIEU, 0.245), cle(G1_IMPACT, 0.31),
                 cle(G1_RECUL, 0.40), cle(G1_POSE, 0.62), cle(REPOS_GM, 1.35)],
}

MARQUEURS = {
    "h_a": {"arme": 0.15, "frappe": 0.20, "fin_frappe": 0.30, "suivi": 0.35, "fin": 0.68},
    "h_b": {"arme": 0.17, "frappe": 0.22, "fin_frappe": 0.32, "suivi": 0.37, "fin": 0.70},
    "h_c": {"arme": 0.17, "frappe": 0.22, "fin_frappe": 0.32, "suivi": 0.37, "fin": 0.72},
    "charge_h": {"arme": 0.30, "fin": 0.60},
    "lourd_h": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.24, "suivi": 0.30, "fin": 0.82},
    "m_a": {"arme": 0.40, "frappe": 0.48, "fin_frappe": 0.63, "suivi": 0.70, "fin": 1.20},
    "m_b": {"arme": 0.40, "frappe": 0.48, "fin_frappe": 0.62, "suivi": 0.69, "fin": 1.18},
    "m_c": {"arme": 0.46, "frappe": 0.55, "fin_frappe": 0.70, "suivi": 0.77, "fin": 1.30},
    "charge_m": {"arme": 0.40, "fin": 0.75},
    "lourd_m": {"arme": 0.10, "frappe": 0.10, "fin_frappe": 0.26, "suivi": 0.34, "fin": 1.05},
    "gm_a": {"arme": 0.45, "frappe": 0.55, "fin_frappe": 0.70, "suivi": 0.78, "fin": 1.40},
    "gm_b": {"arme": 0.42, "frappe": 0.52, "fin_frappe": 0.67, "suivi": 0.75, "fin": 1.38},
    "charge_gm": {"arme": 0.45, "fin": 0.85},
    "lourd_gm": {"arme": 0.12, "frappe": 0.12, "fin_frappe": 0.31, "suivi": 0.40, "fin": 1.35},
}


def explorer_poignet():
    """--explorer_poignet : direction du manche et du tranchant pour des poignets imposés (k, f, r) en quelques poings."""
    NS["poings"]()
    for poing in [(0.60, 0.10, 0.50), (0.30, -0.18, 0.60), (0.15, -0.33, 0.60)]:
        for k in (-80, -40, 0, 40, 80):
            for f, r in ((0, 25), (0, -35), (40, -35), (-40, -35), (40, 25), (-40, 25)):
                NS["PREC"][0] = None
                c = dict(nom="x", poing=E(*poing), lame=(0, 1, 0), k=k, f=f, r=r, phi=0, coude=(1, -0.6, 0.2), large=True)
                _poser_epee(c)
                W = NS["CAM_DE_B"] @ NS["A"].pose.bones["hand_r"].matrix @ NS["PRISE_D"]
                y = W.col[1].to_3d().normalized()
                x = W.col[0].to_3d().normalized()
                print("EXPL poing=%s k=%d f=%d r=%d  manche=(%.2f,%.2f,%.2f) fil=(%.2f,%.2f,%.2f)" % (poing, k, f, r, y.x, y.y, y.z, x.x, x.y, x.z))


def explorer_tb():
    """--explorer_tb=k : pour une torsion bornée autour de k, erreur de manche pour des poings / manches candidats."""
    NS["poings"]()
    k = int(NS["ARGS"]["explorer_tb"])
    for poing in [(0.15, -0.20, 0.70), (0.15, -0.30, 0.66), (0.20, -0.10, 0.70), (0.10, -0.40, 0.62), (0.25, 0.10, 0.62)]:
        for lame in [(0, -0.3, -0.95), (0, 0.2, -0.98), (-0.3, -0.3, -0.9), (-0.5, 0.0, -0.87), (0, 0.6, -0.8), (-0.4, -0.5, -0.77)]:
            for coude in [(1, -1, 0.2), (0.6, -1, 0.6)]:
                NS["PREC"][0] = None
                NS["RAPPORT"].clear()
                _poser_borne(dict(nom="x", poing=E(*poing), lame=lame, tb=k, coude=coude, large=True, poids_torsion=PT))
                r = NS["RAPPORT"][-1]
                p_, t_, x = tete_ecran()
                print("TB k=%d poing=%s lame=%s coude=%s -> allonge %.2f kfr %s %s %s err %.1f tete (%.2f,%.2f) fil (%.2f,%.2f,%.2f)" % (k, poing, lame, coude, r[1], r[2], r[3], r[4], r[5], t_[0], t_[1], x.x, x.y, x.z))


def main():
    ARGS = NS["ARGS"]
    if "explorer_tb" in ARGS:
        explorer_tb()
        return
    if "explorer_poignet" in ARGS:
        explorer_poignet()
        return
    NS["poings"]()
    NS["poser_torche"]()
    noms = [c for c in ARGS.get("clips", "").split(",") if c] or list(CLIPS)
    actions = {}
    for nom in noms:
        cles = CLIPS[nom]
        act = NS["creer_action"](nom, cles)
        actions[nom] = (act, cles[-1]["t"])
    print("POIGNET  (clé, allonge, torsion avant-bras° (+ supination), flexion°, inclinaison° (+ radiale), erreur lame°, coût)")
    for r in NS["RAPPORT"]:
        print("POIGNET ", r)
    if "trajet" in ARGS:
        trajets(actions)
    if "mesurer" in ARGS:
        NS["mesurer_clips"](actions)
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS          # ecrire_godot lit les marqueurs de l'espace de noms
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_lourds.tres"), actions)
    print("FIN OK")


main()
