# Armures lourdes portées (agent Y) : constructeurs de pièces (casque, cuirasse, gantelets, bottes) pour les styles
# « fer » (fer forgé brun-gris, plaques rivetées sur cotte de mailles, casque à nasal), « acier » (acier nordique : plaques bombées
# gravées d'entrelacs, col de fourrure, heaume à cornes courtes et joues) et les variantes des pièces uniques.
import math
from mathutils import Vector, Matrix
import commun as C

TAU = math.tau
COTES = (("l", 1.0), ("r", -1.0))

def _lerp(a, b, t):
    return a + (b - a) * t

def _smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)

def _dans_arc(a, a0, a1):
    a = a % TAU; a0 = a0 % TAU; a1 = a1 % TAU
    return a0 <= a <= a1 if a0 <= a1 else (a >= a0 or a <= a1)

# =============================================================================================================== CASQUE
def casque(r, st):
    """st : dict de style. Coque ajustée au crâne (peau de la tête), rebord, nasal / joues / cornes / couronne selon le style."""
    P = C.Piece(st["id"])
    t = C.Toile(st["id"])
    pal = st["pal"]
    g = st.get("graine", 3)
    # atlas : coque (0,0)-(128,80) ; rebord (0,80)-(128,92) ; nasal/joues (0,92)-(64,128) ; cornes/couronne (64,92)-(128,128)
    R_COQUE, R_REB, R_NAS, R_CORNE = (0, 0, 128, 80), (0, 80, 128, 92), (0, 92, 64, 128), (64, 92, 128, 128)
    t.zone(R_COQUE, C.metal(pal, g, base=st.get("base", 0.55), contraste=0.32, rayures=0.6, oxyde=st.get("oxyde", 0.0),
                            crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7)))
    t.zone(R_REB, C.metal(pal, g + 1, base=st.get("base", 0.55) - 0.08, contraste=0.25, crasse=0.4, poli=0.6))
    t.zone(R_NAS, C.metal(pal, g + 2, base=st.get("base", 0.55), contraste=0.3, crasse=0.3, poli=0.7))
    t.zone(R_CORNE, st.get("peinture_corne", C.metal(pal, g + 3, base=0.5, contraste=0.3, poli=0.6)))
    arbre = C.bvh(r, ["peau"], {"Head", "neck_01"}, 0.5)
    centre = Vector((0.0, 0.004, 1.685))
    n = st.get("n", 18)
    lats_t = [0.0, 0.16, 0.34, 0.52, 0.70, 0.86, 1.0]
    # bas de la coque selon la longitude (0 = devant) : front au-dessus des sourcils, tempes, nuque plus bas
    bas_front, bas_cote, bas_nuque = st.get("bas", (0.26, -0.12, -0.45))
    def bas(lo):
        c = math.cos(lo)           # 1 devant, -1 derrière
        s = abs(math.sin(lo))
        return (bas_front if c > 0 else bas_nuque) * abs(c) ** 1.5 + bas_cote * s ** 1.2
    devant = Vector((0, -1, 0)); haut = Vector((0, 0, 1)); gauche = Vector((1, 0, 0))
    dirs, R = [], []
    for jt in lats_t:
        drow, rrow = [], []
        for i in range(n):
            lo = TAU * i / n
            la = _lerp(bas(lo), math.radians(84), jt)
            d = (devant * math.cos(lo) + gauche * math.sin(lo)) * math.cos(la) + haut * math.sin(la)
            d.normalize()
            hit = arbre.ray_cast(centre + d * 0.5, -d, 0.5)
            rrow.append(0.5 - hit[3] if hit[0] is not None else None)
            drow.append(d)
        ok = [x for x in rrow if x]
        m = sum(ok) / len(ok)
        R.append([x if x else m for x in rrow]); dirs.append(drow)
    R = C.max_grille(R, 1)
    R = C.lisser_grille(R, 2, k=0.5)
    ep = st.get("ecart", 0.017)
    bombe = st.get("bombe", 0.0)        # sommet en pointe (spangenhelm) : rayon en plus vers le haut
    Pts = []
    for j, jt in enumerate(lats_t):
        row = []
        for i in range(n):
            lo = TAU * i / n
            extra = ep + bombe * max(0.0, jt - 0.55) ** 2 * 4.0
            row.append(centre + dirs[j][i] * (R[j][i] + extra))
        Pts.append(row)
    # pointe : dernier anneau resserré vers l'axe
    sommet = centre + haut * (max(R[-1]) + ep + bombe * 0.9)
    ids = P.grille(Pts, st["mat"], C.rect_uv(R_COQUE))
    s_id = P.sommet(sommet)
    nci = n
    for i in range(n):
        a, b = ids[-1][i], ids[-1][(i + 1) % n]
        P.face([a, b, s_id], st["mat"], [((i + 0.5) / n, 0.62), ((i + 1.5) / n, 0.62), ((i + 1) / n, 0.625)])
    # rebord : bandeau extérieur (débord) puis retour vers le crâne (épaisseur visible depuis dessous)
    bord = Pts[0]
    deb = st.get("rebord", 0.008)
    haut_band = [p + (p - centre).normalized() * deb + Vector((0, 0, 0.022)) for p in bord]
    bas_band = [p + (p - centre).normalized() * deb for p in bord]
    dedans = [p - (p - centre).normalized() * (ep * 0.9) for p in bord]
    P.grille([haut_band, bas_band], st["mat_rebord"], C.rect_uv((0, 80, 128, 86)), inverser=False)
    P.grille([bas_band, dedans], st["mat_rebord"], C.rect_uv((0, 86, 128, 92)))
    # ombre du rebord sur la coque (couleur de sommet)
    for i in ids[0]:
        P.ao[i] = 0.7
    for i in ids[1]:
        P.ao[i] = 0.9
    for dec in st.get("decor", []):
        dec(P, t, r, centre, Pts, R_NAS, R_CORNE)
    # bandes de renfort peintes (spangen) : verticales à 0°, 90°, 180°, 270° + rivets sur le rebord
    for k in range(st.get("bandes", 4)):
        x = int(round((k / st.get("bandes", 4)) * 128)) % 128
        for dx in (-2, -1, 0, 1, 2):
            for y in range(0, 80):
                p = t.get(x + dx, y)
                kk = 1.08 if abs(dx) < 2 else 0.6
                t.mul((x + dx) % 128, y, kk, 0.1 if abs(dx) < 2 else -0.3)
        C.rivets(t, [(x % 128, y) for y in range(8, 76, 11)], pal)
    C.rivets(t, [(x, 83) for x in range(4, 128, 9)], pal)
    if st.get("graver"):
        C.entrelacs(t, (0, 4, 128, 14), pal, g)
    img = t.image()
    ob = P.objet()
    C.orienter_dehors(ob, lambda c: centre if c.z > centre.z - 0.12 or abs(c.y + 0.09) > 0.05 else c + Vector((0, 0.05, 0)))
    C.appliquer_materiaux(ob, P, img)
    C.peau_rigide(ob, r, "Head")
    C.lier(ob, r)
    return ob

def deco_nasal(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="fer", long=0.065, larg=0.016):
    """Nasal forgé : bande épaisse du front au bout du nez (devant le visage)."""
    top = Pts[0][0] + Vector((0, 0, 0.02))
    y = top.y - 0.004
    pts = []
    for k, z in enumerate((top.z, top.z - long * 0.5, top.z - long)):
        w = larg * (1.0 if k < 2 else 0.8)
        dy = -0.004 * k
        pts.append([Vector((-w, y + dy, z)), Vector((w, y + dy, z)), Vector((w, y + dy + 0.008, z)), Vector((-w, y + dy + 0.008, z))])
    u = C.rect_uv((4, 96, 20, 126))
    for j in range(2):
        for (a, b) in ((0, 1), (1, 2), (3, 0)):
            q = [pts[j][a], pts[j][b], pts[j + 1][b], pts[j + 1][a]]
            ids = [P.sommet(p) for p in q]
            P.face(ids, mat, [(u[0], u[1] + (u[3] - u[1]) * j / 2), (u[2], u[1] + (u[3] - u[1]) * j / 2),
                                (u[2], u[1] + (u[3] - u[1]) * (j + 1) / 2), (u[0], u[1] + (u[3] - u[1]) * (j + 1) / 2)])
    bot = [P.sommet(p) for p in pts[2]]
    P.face([bot[3], bot[2], bot[1], bot[0]], mat, [(u[0], u[1])] * 4)
    t.zone((4, 96, 20, 126), C.metal(t.__dict__.get("pal", C.FER), 9, base=0.6, contraste=0.25, crasse=0.2, poli=0.75))
    C.ligne_v(t, 4, 96, 126, 0.5); C.ligne_v(t, 19, 96, 126, 0.5)
    C.rivets(t, [(11, 122), (11, 112)], C.FER)

def deco_joues(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="acier"):
    """Joues d'acier (paragnathides) : plaques bombées qui descendent des tempes le long des joues, sous la barbe en haut."""
    arbre = C.bvh(r, ["peau", "Hair_Beard"], {"Head"}, 0.5)
    for cote in (1.0, -1.0):
        grid = []
        for k, z in enumerate((1.665, 1.632, 1.60)):
            row = []
            for a in range(4):
                lo = math.radians(_lerp(38, 100, a / 3)) * cote
                d = Vector((math.sin(lo), -math.cos(lo), 0))
                c = Vector((0, 0.004, z))
                hit = arbre.ray_cast(c + d * 0.4, -d, 0.4)
                rr = (0.4 - hit[3]) if hit[0] is not None else 0.085
                row.append(c + d * (rr + 0.016 + 0.004 * k))
            grid.append(row if cote > 0 else list(reversed(row)))
        u = C.rect_uv((24, 96, 60, 126))
        P.grille(grid, mat, u, fermer=False, inverser=cote > 0)
        # épaisseur du bord bas
        bas = grid[-1]
        dedans = [p + (Vector((0, 0.004, p.z)) - p).normalized() * 0.01 for p in bas]
        P.grille([bas, dedans], mat, C.rect_uv((24, 92, 60, 96)), fermer=False, inverser=cote > 0)
    C.rivets(t, [(30, 120), (52, 120), (41, 104)], C.ACIER)

def deco_cornes(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="os.corne", longueur=0.11, base=0.024):
    """Cornes courtes recourbées (vers l'extérieur puis l'avant), base dans la coque aux tempes hautes."""
    for cote in (1.0, -1.0):
        racine = centre + Vector((0.085 * cote, 0.005, 0.07))
        axe = [racine]
        dirn = Vector((0.9 * cote, 0.05, 0.45)).normalized()
        p = racine
        for k in range(4):
            p = p + dirn * (longueur / 4)
            dirn = (dirn + Vector((0, -0.25, 0.32))).normalized()
            axe.append(p)
        anneaux = []
        for k, c in enumerate(axe):
            tg = (axe[min(k + 1, 4)] - axe[max(k - 1, 0)]).normalized()
            u, w = C.repere(tg)
            rr = base * (1.0 - k / 4.6)
            anneaux.append([c + (u * math.cos(TAU * i / 6) + w * math.sin(TAU * i / 6)) * rr for i in range(6)])
        ids = P.grille(anneaux, mat, C.rect_uv((64, 92, 128, 128)), inverser=cote < 0)
        pt = P.sommet(axe[-1] + (axe[-1] - axe[-2]).normalized() * 0.022)
        for i in range(6):
            P.face([ids[-1][i], ids[-1][(i + 1) % 6], pt] if cote > 0 else [ids[-1][(i + 1) % 6], ids[-1][i], pt], mat,
                   [(0.6, 0.98), (0.65, 0.98), (0.62, 0.99)])
        for i in ids[0]:
            P.ao[i] = 0.55

def deco_couronne(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="fer.noir", hauteur=0.07, pointes=8):
    """Couronne de fer noir : bandeau autour du casque, pointes en dents de scie dressées."""
    j = 2
    ring = Pts[j]
    n = len(ring)
    bas = [p + (p - centre).normalized() * 0.006 for p in ring]
    hautb = [p + Vector((0, 0, 0.02)) for p in bas]
    P.grille([bas, hautb], mat, C.rect_uv((64, 92, 128, 100)))
    for k in range(pointes):
        i0 = int(k * n / pointes)
        i1 = int((k + 1) * n / pointes) % n
        a, b = hautb[i0], hautb[i1]
        m = (a + b) / 2 + Vector((0, 0, hauteur if k % 2 == 0 else hauteur * 0.6)) + (a + b - 2 * centre).normalized() * 0.008
        ia, ib, im = P.sommet(a), P.sommet(b), P.sommet(m)
        P.face([ia, ib, im], mat, [(0.52, 0.8), (0.98, 0.8), (0.75, 0.98)])
        P.face([ib, ia, im], mat, [(0.98, 0.8), (0.52, 0.8), (0.75, 0.98)])

# =============================================================================================================== CUIRASSE
TORSE_OS = {"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"}

def cuirasse(r, st):
    """Cotte (mailles) des hanches au col, plaques (lames rivetées ou plastron bombé), épaulières de lames, manches de mailles,
    ceinture de cuir, col de fourrure (acier nordique)."""
    P = C.Piece(st["id"])
    t = C.Toile(st["id"])
    g = st.get("graine", 5)
    pal = st["pal"]
    # atlas : mailles (0,0)-(128,40) ; plaques (0,40)-(128,88) ; ceinture (0,88)-(128,96) ; épaulières (0,96)-(80,128) ; fourrure (80,96)-(128,128)
    R_MAILLE, R_PLAQ, R_CEINT, R_EPAUL, R_FOUR = (0, 0, 128, 40), (0, 40, 128, 88), (0, 88, 128, 96), (0, 96, 80, 128), (80, 96, 128, 128)
    MM = st.get("mat_maille", "fer.maille")
    t.zone(R_MAILLE, st.get("peinture_maille", C.maille(st.get("pal_maille", C.FER), g, base=0.5)))
    t.zone(R_PLAQ, st.get("peinture_plaques", C.metal(pal, g + 1, base=st.get("base", 0.55), contraste=0.3, rayures=0.7, oxyde=st.get("oxyde", 0.0),
                           crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7))))
    t.zone(R_CEINT, C.cuir(st.get("pal_cuir", C.CUIR), g + 2, base=0.45))
    t.zone(R_EPAUL, st.get("peinture_plaques", C.metal(pal, g + 3, base=st.get("base", 0.55) + 0.03, contraste=0.3, rayures=0.7, oxyde=st.get("oxyde", 0.0),
                            crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7))))
    t.zone(R_FOUR, C.fourrure(st.get("pal_fourrure", C.FOURRURE), g + 4))
    axeA, axeB = Vector((0, -0.005, 0.70)), Vector((0, -0.005, 1.60))
    H = axeB.z - axeA.z
    def tz(z):
        return (z - axeA.z) / H
    n = st.get("n", 16)
    arbre = C.bvh(r, ["tunique", "peau"], TORSE_OS, 0.5)
    arbre_jambes = C.bvh(r, ["pantalon"], {"pelvis", "thigh_l", "thigh_r", "spine_01"}, 0.3)
    # --- cotte : jupe (enveloppe des cuisses + évasement), taille, puis haut (col) ; les plaques couvrent le milieu
    z_jupe = [st.get("z_ourlet", 0.74), 0.84, 0.94, 1.02] if not st.get("fourrure") else [st.get("z_ourlet", 0.74), 0.88, 1.02]
    zp0, zp1 = st.get("z_plaques", (1.04, 1.40))
    z_haut = [zp1 - 0.02, 1.46, 1.505, 1.535]
    def dec_maille(j, i, a):
        return 0.012
    # jupe : mesurée sur le pantalon (pas sur les pans de la tunique), évasée vers le bas
    Pj, Rj, _ = C.tube(arbre_jambes, axeA, axeB, [tz(z) for z in z_jupe], n,
                       lambda j, i, a: 0.03 + 0.05 * (1.0 - j / (len(z_jupe) - 1.0)) ** 1.3 + (0.012 if math.cos(a) < 0 else 0.0), r_loin=0.6, dilate=2, lisse=3)
    ids_j = P.grille(Pj, MM, C.rect_uv((0, 0, 128, 22)), inverser=True)
    Ph, Rh, _ = C.tube(arbre, axeA, axeB, [tz(z) for z in z_haut], n, dec_maille, r_loin=0.6, dilate=1, lisse=2)
    # col : le dernier anneau resserré autour du cou
    ids_h = P.grille(Ph, MM, C.rect_uv((0, 22, 128, 40)), inverser=True)
    # ourlet : retour vers l'intérieur
    ourlet = [p + (Vector((0, -0.005, p.z)) - p).normalized() * 0.015 + Vector((0, 0, 0.012)) for p in Pj[0]]
    P.grille([ourlet, Pj[0]], MM, C.rect_uv((0, 0, 128, 3)), inverser=True)
    col_dedans = [p + (Vector((0, 0.0, p.z)) - p).normalized() * 0.014 - Vector((0, 0, 0.01)) for p in Ph[-1]]
    P.grille([Ph[-1], col_dedans], MM, C.rect_uv((0, 37, 128, 40)), inverser=True)
    for i in ids_j[0]:
        P.ao[i] = 0.8
    # --- plaques : lames horizontales qui se recouvrent (fer) ou plastron bombé + lames basses (acier)
    lames = st.get("lames", 4)
    zs = [zp0 + (zp1 - zp0) * k / lames for k in range(lames + 1)]
    for k in range(lames):
        za, zb = zs[k], zs[k + 1] + 0.02            # recouvrement : la lame du dessus descend sur celle du dessous
        bomb = st.get("bombe", 0.0)
        def dec_lame(j, i, a, k=k):
            avant = max(0.0, math.cos(a)) ** 2
            return 0.024 + 0.005 * (lames - k) + (0.006 if j == 0 else 0.0) + bomb * avant * math.sin(math.pi * (k + 0.5) / lames)
        Pl, Rl, _ = C.tube(arbre, axeA, axeB, [tz(zb), tz(za + 0.01), tz(za)], n, dec_lame, r_loin=0.6, dilate=2, lisse=3)
        v0 = 40 + int(48 * k / lames); v1 = 40 + int(48 * (k + 1) / lames)
        ids = P.grille(Pl[:2], st["mat"], C.rect_uv((0, v0, 128, v1)), inverser=False)
        # lèvre basse (épaisseur) : du bas de la lame vers le corps
        P.grille([Pl[2], Pl[1]], st["mat"], C.rect_uv((0, v0, 128, v0 + 2)), inverser=False)
        for i in ids[0]:
            P.ao[i] = 0.72
        for x in range(0, 128):
            t.mul(x, v1 - 1, 1.25, 0.25)       # arête haute claire
            t.mul(x, v0, 0.45, -0.4)           # bas de lame sombre (ombre sur la suivante)
        if st.get("rivets", True):
            C.rivets(t, [(x, v0 + 3) for x in range(3, 128, 8)], pal)
        if st.get("graver") and k == lames - 1:
            C.entrelacs(t, (0, v0 + 5, 128, v1 - 3), pal, g + k, k_creux=0.72)
    # --- ceinture
    zc = st.get("z_ceinture", 1.0)
    Pc, Rc, _ = C.tube(arbre_jambes if zc < 0.98 else arbre, axeA, axeB, [tz(zc - 0.03), tz(zc + 0.03)], n,
                       lambda j, i, a: 0.03 + 0.02, r_loin=0.6, dilate=2, lisse=3)
    Pc2, _, _ = C.tube(arbre, axeA, axeB, [tz(zc - 0.03), tz(zc + 0.03)], n, lambda j, i, a: 0.02, r_loin=0.6, dilate=2, lisse=3)
    # rayon de la ceinture = max(cotte, plaques) + 1 cm
    Pc = [[Pc[j][i] if (Pc[j][i] - Vector((0, 0, Pc[j][i].z))).length > (Pc2[j][i] - Vector((0, 0, Pc2[j][i].z))).length else Pc2[j][i]
           for i in range(n)] for j in range(2)]
    P.grille(Pc, "cuir", C.rect_uv(R_CEINT), inverser=True)
    bas_c = [p + (Vector((0, -0.005, p.z)) - p).normalized() * 0.012 for p in Pc[0]]
    P.grille([bas_c, Pc[0]], "cuir", C.rect_uv((0, 88, 128, 89)), inverser=True)
    # boucle : carré clair peint devant
    for x in range(58, 70):
        for y in range(89, 95):
            if x in (58, 59, 68, 69) or y in (89, 94):
                t.set(x, y, C.rampe(C.FER, 0.85), 0.9)
    # --- manches de mailles et épaulières
    for cote, s in COTES:
        ua, la, ha = r.os["upperarm_" + cote], r.os["lowerarm_" + cote], r.os["hand_" + cote]
        bras = C.bvh(r, ["tunique", "brassards", "peau"], {"upperarm_" + cote, "lowerarm_" + cote}, 0.5)
        A = ua + Vector((-0.03 * s, 0, 0))
        B = Vector((st.get("x_manche", 0.42) * s, la.y, la.z))     # ArmureVisible garde la manche de la cotte au-delà de |x| = 0,42
        Pm, Rm, _ = C.tube(bras, A, B, [0.0, 0.5, 1.0], 8, lambda j, i, a: 0.013 + 0.022 * (j / 2) ** 2, r_loin=0.3, dilate=1, lisse=2)
        idm = P.grille(Pm, MM, C.rect_uv((0, 0, 64, 20)), inverser=s > 0)
        bm = [p + (A.lerp(B, 1.0) - p).normalized() * 0.01 for p in Pm[-1]]
        P.grille([Pm[-1], bm], MM, C.rect_uv((0, 0, 64, 2)), inverser=s > 0)
        # épaulières : lames sur le dessus de l'épaule (arc haut), de l'épaule vers le coude, chaque lame par-dessus la suivante
        nl = st.get("lames_epaule", 3)
        epaule = C.bvh(r, ["tunique", "peau"], {"upperarm_" + cote, "clavicle_" + cote, "spine_03"}, 0.5)
        E0 = Vector((0.12 * s, -0.005, 1.47))
        E1 = Vector((0.36 * s, 0.02, 1.455))
        arc = [math.radians(x) for x in range(140, 410, 30)]        # derrière -> dessus (270°) -> devant
        for k in range(nl):
            ta = k / nl * 0.95
            tb = (k + 1) / nl * 0.95 + 0.06
            def dec_e(j, i, a, k=k):
                dessus = max(0.0, -math.sin(a))        # w = bas : -sin = haut
                return 0.03 + 0.012 * (nl - k) + 0.025 * dessus ** 0.5 + (0.005 if j == 1 else 0.0)
            Pe, Re, rep = C.tube(epaule, E0, E1, [ta, tb], 0, dec_e, r_loin=0.4, dilate=0, lisse=1, angles=arc)
            if s < 0:
                Pe = [list(reversed(row)) for row in Pe]
            u0 = int(80 * k / nl); u1 = int(80 * (k + 1) / nl)
            ide = P.grille(Pe, st["mat"], C.rect_uv((u0, 96, u1, 128)), fermer=False, inverser=s < 0)
            # tranche (bord extérieur vers le bras)
            tr = [p + (E0.lerp(E1, tb) - p).normalized() * 0.012 for p in Pe[1]]
            P.grille([Pe[1], tr], st["mat"], C.rect_uv((u0, 96, u1, 98)), fermer=False, inverser=s < 0)
            for i in ide[0]:
                P.ao[i] = 0.65
        for k in range(nl):
            u1 = int(80 * (k + 1) / nl)
            C.ligne_v(t, u1 - 1, 96, 128, 0.5)
            if st.get("rivets", True):
                C.rivets(t, [(u1 - 4, y) for y in range(100, 128, 7)], pal)
    # --- col de fourrure (acier nordique, gardiens) : boudin autour des épaules et de la nuque
    if st.get("fourrure"):
        Pf, Rf, _ = C.tube(arbre, axeA, axeB, [tz(1.44), tz(1.50), tz(1.555)], n,
                           lambda j, i, a: (0.03, 0.055, 0.03)[j] + 0.01 * (_h_ang(i, 7) - 0.5), r_loin=0.6, dilate=2, lisse=1)
        P.grille(Pf, "fourrure", C.rect_uv(R_FOUR), inverser=True)
        # mèches qui pendent (dents) sur le bas du col
        for i in range(0, n, 1 if n * 3 < 40 else 2):
            a, b = Pf[0][i], Pf[0][(i + 1) % n]
            m = (a + b) / 2 + Vector((0, 0, -0.035 - 0.015 * _h_ang(i, 3))) + ((a + b) / 2 - Vector((0, 0, a.z))).normalized() * 0.01
            ia, ib, im = P.sommet(a, 0.8), P.sommet(b, 0.8), P.sommet(m, 0.6)
            P.face([ib, ia, im], "fourrure", [(0.8, 0.8), (0.95, 0.8), (0.87, 0.76)])
    if st.get("givre"):
        givre(t, (0, 40, 128, 88), g + 50, st["givre"])
        givre(t, (0, 96, 80, 128), g + 51, st["givre"])
    for dec in st.get("decor", []):
        dec(P, t, r, st)
    img = t.image()
    ob = P.objet()
    C.orienter_dehors(ob, _centre_corps)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["tunique", "peau"], lisser=1)
    # manches de mailles : sur le bras seul (la manche de la cotte du héros, dessous, suit le haut du bras)
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        if abs(p.x) > 0.30 and p.z > 1.28:
            cote = "l" if p.x > 0 else "r"
            for g in list(ob.vertex_groups):
                g.remove([v.index])
            if "upperarm_" + cote not in ob.vertex_groups:
                ob.vertex_groups.new(name="upperarm_" + cote)
            ob.vertex_groups["upperarm_" + cote].add([v.index], 1.0, "REPLACE")
    C.lier(ob, r)
    return ob

def givre(t, rect, g, force=0.5):
    """Givre éternel : croûte blanc-bleu dans les creux et en plaques (bruit), cristaux clairs 1 px ; mate (brillance basse)."""
    x0, y0, x1, y1 = rect
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = C.fbm(x, y, g, oct=((14, 0.5), (6, 0.3), (2, 0.2)))
            if n > 1.0 - force * 0.6:
                k = min(1.0, (n - (1.0 - force * 0.6)) * 5.0)
                p = t.get(x, y)
                c = C.rampe(C.GIVRE, 0.35 + 0.6 * C._h(x, y, g + 1))
                t.set(x, y, tuple(p[i] * (1 - k) + c[i] * k for i in range(3)), p[3] * (1 - k) + 0.3 * k)

def _h_ang(i, g):
    return C._h(i, 0, g)

def _centre_corps(c):
    """Point « intérieur » le plus proche : axe du bras si la face est sur un bras, axe du torse sinon."""
    if abs(c.x) > 0.17 and c.z > 1.3:
        return Vector((c.x, 0.03, 1.455))
    if c.z < 1.0 and abs(c.x) > 0.04 and c.z < 0.9:
        return Vector((0.0, 0.0, c.z))
    return Vector((0.0, 0.0, c.z))

# =============================================================================================================== GANTELETS
DOIGTS = ("index", "middle", "ring", "pinky", "thumb")

def gantelets(r, st):
    """Manchette évasée sur l'avant-bras, dos de la main couvert de lames, doigts en tubes à phalanges (4 côtés)."""
    P = C.Piece(st["id"])
    t = C.Toile(st["id"])
    g = st.get("graine", 7)
    pal = st["pal"]
    # atlas : manchette (0,0)-(128,48) ; main (0,48)-(128,88) ; doigts (0,88)-(128,128)
    t.zone((0, 0, 128, 48), st.get("peinture_manchette", C.metal(pal, g, base=st.get("base", 0.55), contraste=0.3, rayures=0.6, oxyde=st.get("oxyde", 0.0),
                                    crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7))))
    t.zone((0, 48, 128, 88), st.get("peinture_main", C.metal(pal, g + 1, base=st.get("base", 0.55) - 0.03, contraste=0.3, crasse=0.3,
                                                              poli=st.get("poli", 0.7))))
    t.zone((0, 88, 128, 128), st.get("peinture_doigts", C.cuir(st.get("pal_cuir", C.CUIR), g + 2, base=0.4)))
    for y in (2, 3):
        C.ligne_h(t, y, 0, 128, 0.5)
    if st.get("rivets", True):
        C.rivets(t, [(x, 6) for x in range(4, 128, 10)], pal)
    if st.get("griffes"):
        t.zone((112, 120, 128, 128), C.metal(C.ACIER, g + 9, base=0.7, contraste=0.2, poli=0.9))
    if st.get("graver"):
        C.entrelacs(t, (0, 14, 128, 30), pal, g)
    for k in range(4 if st.get("lames_main", True) else 0):                              # lames du dos de la main
        y = 52 + k * 9
        C.ligne_h(t, y, 0, 128, 0.45)
        C.ligne_h(t, y + 1, 0, 128, 1.25, 0.2)
        C.rivets(t, [(x, y + 4) for x in range(6, 128, 16)], pal)
    for cote, s in COTES:
        la, ha = r.os["lowerarm_" + cote], r.os["hand_" + cote]
        avb = C.bvh(r, ["brassards", "tunique", "peau", "accessoires"], {"lowerarm_" + cote}, 0.5)
        A = la.lerp(ha, st.get("debut_manchette", 0.45))
        B = ha + (ha - la).normalized() * 0.01
        ev = st.get("evasement", 0.025)
        Pm, Rm, _ = C.tube(avb, A, B, [0.0, 0.5, 1.0], 10,
                           lambda j, i, a: (0.014 + ev, 0.014 + ev * 0.45, 0.012)[j], r_loin=0.3, dilate=1, lisse=2)
        P.grille(Pm, st["mat"], C.rect_uv((0, 0, 128, 48)), inverser=s > 0)
        lev = [p + (A - p).normalized() * 0.0 + ((A - p) - (A - p).project((B - A))).normalized() * 0.01 for p in Pm[0]]
        P.grille([lev, Pm[0]], st["mat"], C.rect_uv((0, 0, 128, 3)), inverser=s > 0)
        # main : du poignet aux jointures, enveloppe du gant (sans le pouce)
        main = C.bvh(r, ["accessoires", "peau"], {"hand_" + cote}, 0.6)
        jo = (r.os["index_01_" + cote] + r.os["pinky_01_" + cote]) / 2
        Am = ha - (jo - ha).normalized() * 0.01
        Bm = jo
        Ph, Rh, rep = C.tube(main, Am, Bm, [0.0, 0.35, 0.7, 0.97], 10,
                             lambda j, i, a: 0.008 + (0.004 if math.sin(a) < 0 else 0.0), r_loin=0.25, dilate=1, lisse=1)
        ids = P.grille(Ph, st["mat_main"], C.rect_uv((0, 48, 128, 88)), inverser=s > 0)
        # bout de la main fermé (sous les doigts)
        cbout = sum(Ph[-1], Vector()) / len(Ph[-1])
        ic = P.sommet(cbout)
        for i in range(10):
            a, b = ids[-1][i], ids[-1][(i + 1) % 10]
            P.face([a, b, ic] if s < 0 else [b, a, ic], st["mat_main"], [(0.1, 0.68), (0.2, 0.68), (0.15, 0.69)])
        # doigts : tubes carrés le long des phalanges
        for d in DOIGTS:
            chaine = [r.os["%s_0%d_%s" % (d, k, cote)] for k in (1, 2, 3)] + [r.os["%s_04_leaf_%s" % (d, cote)]]
            if d == "thumb":
                chaine[0] = chaine[0].lerp(chaine[1], 0.0)
            doigt = C.bvh(r, ["accessoires", "peau"], {"%s_0%d_%s" % (d, k, cote) for k in (1, 2, 3)}, 0.5)
            anneaux = []
            for k, c in enumerate(chaine):
                tg = (chaine[min(k + 1, 3)] - chaine[max(k - 1, 0)]).normalized()
                u, w = C.repere(tg)
                # centre du doigt : milieu des points touchés autour de l'os (les os sont sur le dessus du doigt)
                pts = []
                for ia in range(8):
                    dd = u * math.cos(TAU * ia / 8) + w * math.sin(TAU * ia / 8)
                    hit = doigt.ray_cast(c + dd * 0.05, -dd, 0.05)
                    if hit[0] is not None:
                        pts.append(hit[0])
                cc = sum(pts, Vector()) / len(pts) if len(pts) >= 3 else c
                rr = max(((p - cc) - (p - cc).project(tg)).length for p in pts) if len(pts) >= 3 else 0.009
                rr = min(max(rr, 0.007), 0.014) * 1.414 + 0.003
                if k == 3:
                    rr *= 0.8
                anneaux.append([cc + (u * math.cos(TAU * i / 4 + TAU / 8) + w * math.sin(TAU * i / 4 + TAU / 8)) * rr for i in range(4)])
            # bout prolongé
            idd = P.grille(anneaux, st["mat_doigts"], C.rect_uv((DOIGTS.index(d) * 25, 88, DOIGTS.index(d) * 25 + 24, 128)), inverser=s > 0)
            ct = sum(anneaux[-1], Vector()) / 4
            griffe = st.get("griffes", 0.0)
            tip = P.sommet(ct + (chaine[-1] - chaine[-2]).normalized() * (0.008 + griffe) + (Vector((0, 0, -griffe * 0.5)) if griffe else Vector()))
            for i in range(4):
                a, b = idd[-1][i], idd[-1][(i + 1) % 4]
                P.face([a, b, tip] if s < 0 else [b, a, tip], st.get("mat_griffes", st["mat_doigts"]) if griffe else st["mat_doigts"],
                       [(0.9, 0.95), (0.95, 0.95), (0.92, 0.99)] if griffe else [(0.1, 0.99), (0.15, 0.99), (0.12, 0.995)])
    for dec in st.get("decor", []):
        dec(P, t, r, st)
    img = t.image()
    ob = P.objet()
    def ctr(c):
        sx = 1.0 if c.x > 0 else -1.0
        cote = "l" if sx > 0 else "r"
        a, b = r.os["lowerarm_" + cote], r.os["middle_04_leaf_" + cote]
        ab = b - a
        tt = max(0.0, min(1.0, (c - a).dot(ab) / ab.length_squared))
        return a + ab * tt
    C.orienter_dehors(ob, ctr)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["accessoires", "brassards", "peau"], lisser=1,
                     os_permis={b.name for b in r.arm.data.bones if any(k in b.name for k in ("hand", "lowerarm", "index", "middle", "ring", "pinky", "thumb"))})
    C.lier(ob, r)
    return ob

# =============================================================================================================== BOTTES
def bottes(r, st):
    """Botte ajustée (anneaux horizontaux du sol au genou sur bottes + pantalon), semelle, grève devant le tibia, genouillère."""
    P = C.Piece(st["id"])
    t = C.Toile(st["id"])
    g = st.get("graine", 9)
    pal = st["pal"]
    # atlas : botte (0,0)-(128,64) ; grève (0,64)-(64,128) ; genouillère (64,64)-(128,104) ; semelle (64,104)-(128,128)
    t.zone((0, 0, 128, 64), st.get("peinture_botte", C.cuir(st.get("pal_cuir", C.CUIR), g, base=0.42)))
    t.zone((0, 64, 64, 128), st.get("peinture_greve") or C.metal(pal, g + 1, base=st.get("base", 0.55), contraste=0.3, rayures=0.6, oxyde=st.get("oxyde", 0.0),
                                     crasse=st.get("crasse", 0.35), poli=st.get("poli", 0.7)))
    t.zone((64, 64, 128, 104), C.metal(pal, g + 2, base=st.get("base", 0.55) + 0.04, contraste=0.3, crasse=0.25, poli=st.get("poli", 0.7)))
    t.zone((64, 104, 128, 128), st.get("peinture_revers", C.cuir(C.CUIR, g + 3, base=0.18)))
    C.rivets(t, [(4, y) for y in range(68, 128, 9)] + [(59, y) for y in range(68, 128, 9)], pal)
    C.ligne_v(t, 1, 64, 128, 0.5); C.ligne_v(t, 62, 64, 128, 0.5)
    if st.get("graver"):
        C.entrelacs(t, (10, 64, 54, 76), pal, g)
    for y in (range(4, 64, 12) if st.get("sangles", True) else ()):     # sangles de la botte
        C.ligne_h(t, y, 0, 128, 0.55, -0.1)
    for cote, s in COTES:
        th, ca, fo = r.os["thigh_" + cote], r.os["calf_" + cote], r.os["foot_" + cote]
        jambe = C.bvh(r, ["bottes", "pantalon"], {"calf_" + cote, "foot_" + cote, "ball_" + cote}, 0.5)
        A = Vector((ca.x, -0.015, -0.025))
        B = Vector((ca.x, ca.y, ca.z))
        zs = st.get("niveaux", [-0.02, 0.03, 0.09, 0.17, 0.30, 0.42, 0.50])
        zh = st.get("haut", 0.50)
        zs = [z for z in zs if z <= zh]
        n = 14
        def dec(j, i, a):
            return 0.012 + (0.004 if j >= len(zs) - 1 else 0.0)
        Pb, Rb, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in zs], n, dec, r_loin=0.4, dilate=1, lisse=2)
        # semelle plate un peu sous le sol
        Pb[0] = [Vector((p.x, p.y, -0.022)) for p in Pb[0]]
        # échancrure derrière le genou (le mollet replié ne heurte ni le jarret ni les pans de la tenue) : haut de la tige abaissé derrière
        angs = [math.pi + TAU * i / n for i in range(n)]
        for jj, kz in ((len(Pb) - 1, 0.10), (len(Pb) - 2, 0.04)):
            Pb[jj] = [p - Vector((0, 0, kz * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Pb[jj], angs)]
        MB = st.get("mat_botte", "cuir")
        ids = P.grille(Pb, MB, C.rect_uv((0, 0, 128, 64)), inverser=s < 0 and False)
        c0 = sum(Pb[0], Vector()) / n
        ic = P.sommet(c0)
        for i in range(n):
            a, b = ids[0][i], ids[0][(i + 1) % n]
            P.face([b, a, ic], "cuir", [(0.7, 0.85), (0.8, 0.85), (0.75, 0.95)])     # semelle
        # revers haut (épaisseur)
        rv = [p + (Vector((B.x, B.y if p.z > 0.2 else p.y, p.z)) - p).normalized() * 0.012 for p in Pb[-1]]
        P.grille([Pb[-1], rv], MB, C.rect_uv((0, 61, 128, 64)))
        for i in ids[0]:
            P.ao[i] = 0.6
        if st.get("revers"):
            # revers de fourrure : boudin hirsute au haut de la botte, mèches qui retombent
            zr = zs[-1]
            Pr, _, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in (zr - 0.07, zr - 0.02, zr + 0.01)], n,
                              lambda j, i, a: (0.03, 0.045, 0.02)[j] + 0.008 * (C._h(i, j, 5) - 0.5), r_loin=0.4, dilate=1, lisse=1)
            P.grille(Pr, "fourrure", C.rect_uv((64, 104, 128, 128)))
            for i in range(n):
                a, b = Pr[0][i], Pr[0][(i + 1) % n]
                m = (a + b) / 2 + Vector((0, 0, -0.03 - 0.02 * C._h(i, 1, 9))) + ((a + b) / 2 - Vector((B.x, B.y, a.z))).normalized() * 0.006
                ia, ib, im = P.sommet(a, 0.8), P.sommet(b, 0.8), P.sommet(m, 0.6)
                P.face([ia, ib, im], "fourrure", [(0.55, 0.85), (0.95, 0.85), (0.75, 0.82)])
        if st.get("greve") is False:
            for dec_f in st.get("decor", []):
                dec_f(P, t, r, st, cote, s, jambe, A, B)
            continue
        # grève : plaque devant le tibia (arc avant), de la cheville au genou
        arc = [math.radians(x) for x in range(-80, 81, 32)]
        z0, z1 = st.get("greve", (0.12, 0.47))
        Pg, Rg, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in (z0, (z0 + z1) / 2, z1)], 0,
                           lambda j, i, a: 0.024 + 0.006 * math.cos(a), r_loin=0.4, dilate=0, lisse=1, angles=arc)
        P.grille(Pg, st["mat"], C.rect_uv((0, 64, 64, 128)), fermer=False, inverser=True)
        for row in Pg:      # tranches latérales
            pass
        tr_g = [p + (Vector((ca.x, ca.y, p.z)) - p).normalized() * 0.012 for p in [row[0] for row in Pg]]
        P.grille([[row[0] for row in Pg], tr_g], st["mat"], C.rect_uv((0, 64, 4, 128)), fermer=False)
        tr_d = [p + (Vector((ca.x, ca.y, p.z)) - p).normalized() * 0.012 for p in [row[-1] for row in Pg]]
        P.grille([tr_d, [row[-1] for row in Pg]], st["mat"], C.rect_uv((60, 64, 64, 128)), fermer=False)
        # genouillère : coque bombée devant le genou
        genou = C.bvh(r, ["pantalon"], {"calf_" + cote, "thigh_" + cote}, 0.3)
        Kc = Vector((ca.x, ca.y, ca.z))
        Pk, Rk, _ = C.tube(genou, Kc + Vector((0, 0, -0.045)), Kc + Vector((0, 0, 0.06)), [0.0, 0.33, 0.66, 1.0], 0,
                           lambda j, i, a: 0.026 + 0.016 * math.sin(math.pi * j / 3) * max(0.0, math.cos(a)) ** 0.7, r_loin=0.4, dilate=1, lisse=1,
                           angles=[math.radians(x) for x in range(-70, 71, 28)])
        P.grille(Pk, st["mat_genou"], C.rect_uv((64, 64, 128, 104)), fermer=False, inverser=True)
        for dec_f in st.get("decor", []):
            dec_f(P, t, r, st, cote, s, jambe, A, B)
    img = t.image()
    ob = P.objet()
    def ctr(c):
        cote = "l" if c.x > 0 else "r"
        ca = r.os["calf_" + cote]
        if c.z < 0.12:
            return Vector((ca.x, -0.01, max(c.z, 0.04)))
        return Vector((ca.x, ca.y if c.z > 0.2 else 0.02, c.z))
    C.orienter_dehors(ob, ctr)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["bottes", "pantalon"], lisser=1,
                     os_permis={b.name for b in r.arm.data.bones if any(k in b.name for k in ("calf", "foot", "ball", "thigh"))})
    C.lier(ob, r)
    return ob

# =============================================================================================================== CAPUCHE
def capuche(r, st):
    """Capuche du thaumaturge : forme de la capuche v3 des mages (persos/capuche_v3, validée : épouse le crâne, bord roulé, plis du col),
    variante « visage », réduite au budget d'un casque (<= 600 triangles), re-texturée laine bleue + bordure et bandeau de runes
    d'argent, peau d'os transférée de la tête / du cou / de la pèlerine du héros."""
    import bpy, bmesh, os
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(C.ICI, "capuche_v3_mage.glb"))
    nouveaux = [o for o in bpy.data.objects if o not in avant]
    ob = next(o for o in nouveaux if o.name.startswith("capuche_visage"))
    for o in nouveaux:
        if o != ob:
            bpy.data.objects.remove(o, do_unlink=True)
    mw = ob.matrix_world.copy()
    ob.parent = None
    ob.data.transform(mw)
    ob.matrix_world = Matrix.Identity(4)
    ob.name = st["id"]
    # réduction au budget
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    tris = C.compter_tris(ob)
    md = ob.modifiers.new("dec", "DECIMATE")
    md.ratio = min(1.0, (st.get("budget", 590)) / max(1, tris))
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)
    # textures : laine (0,0)-(128,96), bordure de runes (0,96)-(128,112), bandeau (0,112)-(128,128)
    t = C.Toile(st["id"])
    g = st.get("graine", 61)
    t.zone((0, 0, 128, 96), C.laine(C.LAINE_BLEUE, g, base=0.55))
    t.zone((0, 96, 128, 128), C.laine(C.LAINE_BLEUE, g + 1, base=0.42))
    for y in (97, 110, 113, 126):
        C.ligne_h(t, y, 0, 128, 1.0)
        for x in range(128):
            t.set(x, y, C.rampe(C.ARGENT, 0.7 + 0.2 * C._h(x, y, g)), 0.8)
    C.runes(t, (0, 100, 128, 108), C.ARGENT, g + 3)
    C.runes(t, (0, 115, 128, 124), C.ARGENT, g + 4)
    # plis : ombres de couleur de sommet = occlusion (gardée), UV cylindriques autour de l'axe de la tête
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    uvl = bm.loops.layers.uv.verify()
    centre = Vector((0.0, 0.01, 0.0))
    zmin = min(v.co.z for v in bm.verts); zmax = max(v.co.z for v in bm.verts)
    # bord du visage : arêtes de bord dont le milieu est devant et haut (ouverture du visage)
    bord_vis = set()
    for e in bm.edges:
        if e.is_boundary:
            m = (e.verts[0].co + e.verts[1].co) / 2
            if m.y < -0.03 and m.z > 1.52:
                bord_vis.add(e.verts[0]); bord_vis.add(e.verts[1])
    z_bandeau = st.get("z_bandeau", 1.735)
    for f in bm.faces:
        us = []
        for lp in f.loops:
            p = lp.vert.co
            a = math.atan2(p.x - centre.x, p.y - centre.y)       # 0 = derrière (+Y), couture derrière
            us.append((a / TAU) % 1.0)
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        bordure = any(lp.vert in bord_vis for lp in f.loops)
        cz = sum(lp.vert.co.z for lp in f.loops) / len(f.loops)
        for lp, u in zip(f.loops, us):
            p = lp.vert.co
            if bordure:
                v = (97.5 + (0.0 if lp.vert in bord_vis else 11.0)) / 128.0
                lp[uvl].uv = (u * 3.0, v)
            elif abs(cz - z_bandeau) < 0.022 and p.y > -0.06:
                lp[uvl].uv = (u * 2.0, (113.5 + 12.0 * (p.z - (z_bandeau - 0.022)) / 0.044) / 128.0)
            else:
                lp[uvl].uv = (u * 2.0, (0.5 + 95.0 * (p.z - zmin) / (zmax - zmin)) / 128.0)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    img = t.image()
    me.materials.clear()
    me.materials.append(C.materiau("fourrure.laine", img))
    for p in me.polygons:
        p.material_index = 0
    # occlusion : couleur de sommet assombrie vers l'intérieur du capuchon (doublure) et au creux du col
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    col = me.color_attributes["Col"]
    for poly in me.polygons:
        nrm = poly.normal
        c = poly.center
        dedans = (c - Vector((0, 0.0, 1.68))).normalized().dot(nrm) < -0.2
        for li in poly.loop_indices:
            k = 0.55 if dedans else 1.0
            col.data[li].color = (k, k, k, 1.0)
    # le col de fourrure (mante) et la cotte du héros sont plus épais que la pèlerine du mage : bas de la capuche poussé au-dehors
    C.degager(ob, r, ["mante", "tunique", "peau", "Hair_Beard"], st.get("marge", 0.02), filtre=lambda p: p.z < 1.64)
    C.degager(ob, r, ["accessoires"], st.get("marge", 0.014), filtre=lambda p: p.z < 1.62,
              os_noms={"spine_03", "spine_02", "clavicle_l", "clavicle_r"})
    # poids (comme CapucheMage) : bas = pèlerine du héros (torse), haut = tête, fondu sur la hauteur du cou
    W_haut = C.poids_transferes(ob, r, ["peau"], os_permis={"Head", "neck_01"}, lisser=2)
    W_bas = C.poids_transferes(ob, r, ["tunique"], os_permis={"neck_01", "spine_03", "spine_02", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"}, lisser=2)
    C.poids_fondus(ob, W_haut, W_bas, st.get("fondu", (1.55, 1.665))[0], st.get("fondu", (1.55, 1.665))[1])
    C.lier(ob, r)
    return ob


def deco_runes_bottes(P, t, r, st, cote, s, jambe, A, B):
    """Runes de course brodées (fil bleu-gris) en bandes sur la fourrure blanche de la botte."""
    if cote != "l":
        return
    for y0 in (14, 34):
        C.runes(t, (0, y0, 128, y0 + 7), ["#1c2a3c", "#2c4058", "#3e5674", "#56708e"], 93 + y0, k=0.75)
