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
    lats_t = st.get("lats", [0.0, 0.16, 0.34, 0.52, 0.70, 0.86, 1.0])
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
    t.zone(R_MAILLE, st.get("peinture_maille", C.maille(st.get("pal_maille", C.FER), g, base=st.get("base_maille", 0.36))))
    t.zone(R_PLAQ, st.get("peinture_plaques", C.metal(pal, g + 1, base=st.get("base", 0.55), contraste=0.3, rayures=0.7, oxyde=st.get("oxyde", 0.0),
                           crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7), martele=st.get("martele", 0.0) * 0.6)))
    t.zone(R_CEINT, C.cuir(st.get("pal_cuir", C.CUIR), g + 2, base=0.45))
    t.zone(R_EPAUL, st.get("peinture_plaques", C.metal(pal, g + 3, base=st.get("base", 0.55) + 0.03, contraste=0.3, rayures=0.7, oxyde=st.get("oxyde", 0.0),
                            crasse=st.get("crasse", 0.25), poli=st.get("poli", 0.7), martele=st.get("martele", 0.0))))
    t.zone(R_FOUR, C.fourrure(st.get("pal_fourrure", C.FOURRURE_LOUP), g + 4, base=st.get("base_fourrure", 0.4)))
    axeA, axeB = Vector((0, -0.005, 0.70)), Vector((0, -0.005, 1.60))
    H = axeB.z - axeA.z
    def tz(z):
        return (z - axeA.z) / H
    n = st.get("n", 16)
    arbre = C.bvh(r, ["tunique", "peau"], TORSE_OS, 0.5)
    arbre_jambes = C.bvh(r, ["pantalon"], {"pelvis", "thigh_l", "thigh_r", "spine_01"}, 0.3)
    # --- cotte : jupe (enveloppe des cuisses + évasement), taille, puis haut (col) ; les plaques couvrent le milieu
    zo = st.get("z_ourlet", 0.74)
    z_jupe = [zo, (zo + 0.94) / 2, 0.94, 1.02] if not st.get("fourrure") else [zo, (zo + 1.02) / 2, 1.02]
    zp0, zp1 = st.get("z_plaques", (1.04, 1.40))
    z_haut = [zp1 - 0.02, 1.46, 1.505, 1.535, 1.562]
    def dec_maille(j, i, a):
        # col montant : serré devant (pas de trou noir sous la barbe), plus large sur la nuque (les mèches basses y passent)
        return 0.012 if j < 4 else 0.009 + 0.014 * max(0.0, -math.cos(a)) ** 1.5
    # jupe : mesurée sur le pantalon (pas sur les pans de la tunique), évasée vers le bas
    Pj, Rj, _ = C.tube(arbre_jambes, axeA, axeB, [tz(z) for z in z_jupe], n,
                       lambda j, i, a: st.get("jupe_ev", (0.03, 0.05))[0] + st.get("jupe_ev", (0.03, 0.05))[1] * (1.0 - j / (len(z_jupe) - 1.0)) ** 1.3 + (0.012 if math.cos(a) < 0 else 0.0), r_loin=0.6, dilate=2, lisse=3)
    ids_j = P.grille(Pj, MM, C.rect_uv((0, 0, 128, 22)), inverser=True)
    Ph, Rh, _ = C.tube(arbre, axeA, axeB, [tz(z) for z in z_haut], n, dec_maille, r_loin=0.6, dilate=1, lisse=2)
    # nuque : haut du col abaissé derrière (les cheveux de la nuque, que la tête entraîne, restent au-dessus)
    angs_h = [math.pi + TAU * i / n for i in range(n)]
    Ph[-1] = [p - Vector((0, 0, 0.03 * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Ph[-1], angs_h)]
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
            # flancs minces : les bras qui pendent le long du corps ne rentrent pas dans les plaques
            flanc = 0.3 + 0.7 * abs(math.cos(a)) ** 0.8
            ep0 = st["ep_lames"][k] if st.get("ep_lames") else 0.024 + 0.005 * (lames - k)
            return (ep0 + (0.006 if j == 0 else 0.0)) * flanc + bomb * avant * math.sin(math.pi * (k + 0.5) / lames)
        Pl, Rl, _ = C.tube(arbre, axeA, axeB, [tz(zb), tz(za + 0.01), tz(za)], n, dec_lame, r_loin=0.6, dilate=2, lisse=3)
        v0 = 40 + int(48 * k / lames); v1 = 40 + int(48 * (k + 1) / lames)
        ids = P.grille(Pl[:2], st["mat"], C.rect_uv((0, v0, 128, v1)), inverser=False)
        # lèvre basse (épaisseur) : du bas de la lame vers le corps
        P.grille([Pl[2], Pl[1]], st["mat"], C.rect_uv((0, v0, 128, v0 + 2)), inverser=False)
        for i in ids[0]:
            P.ao[i] = 0.72
        for x in range(0, 128):
            p_ = t.get(x, v1 - 1)
            t.set(x, v1 - 1, tuple(min(1.0, c_ * 1.6 + 0.05) for c_ in p_[:3]), 1.0)   # arête haute polie
            t.mul(x, v0, 0.4, -0.5)            # bas de lame sombre (ombre sur la suivante)
            t.mul(x, v0 + 1, 0.7, -0.3)
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
        B = Vector((st.get("x_manche", 0.435) * s, la.y, la.z))     # ArmureVisible garde la manche de la cotte au-delà de |x| = 0,42
        Pm, Rm, _ = C.tube(bras, A, B, [0.0, 0.5, 1.0], 8, lambda j, i, a: 0.013 + 0.034 * (j / 2) ** 2, r_loin=0.3, dilate=1, lisse=2)
        idm = P.grille(Pm, MM, C.rect_uv((0, 0, 64, 20)), inverser=s > 0)
        bm = [p + (A.lerp(B, 1.0) - p).normalized() * 0.01 for p in Pm[-1]]
        P.grille([Pm[-1], bm], MM, C.rect_uv((0, 0, 64, 2)), inverser=s > 0)
        # épaulières : lames sur le dessus de l'épaule (arc haut), de l'épaule vers le coude, chaque lame par-dessus la suivante
        nl = st.get("lames_epaule", 3)
        epaule = C.bvh(r, ["tunique", "peau"], {"upperarm_" + cote, "clavicle_" + cote, "spine_03"}, 0.5)
        E0 = Vector((0.12 * s, -0.005, 1.47))
        E1 = Vector((0.36 * s, 0.02, 1.455))
        arc = [math.radians(x) for x in (range(140, 410, 30) if not st.get("bord_roule") else range(142, 409, 38))]   # derrière -> dessus (270°) -> devant
        for k in range(nl):
            ta = k / nl * 0.95
            tb = (k + 1) / nl * 0.95 + 0.06
            def dec_e(j, i, a, k=k):
                dessus = max(0.0, -math.sin(a))        # w = bas : -sin = haut
                ee = st.get("ep_epaule", (0.03, 0.012, 0.025))
                return ee[0] + ee[1] * (nl - k) + ee[2] * dessus ** 0.5 + (0.005 if j == 1 else 0.0)
            Pe, Re, rep = C.tube(epaule, E0, E1, [ta, tb], 0, dec_e, r_loin=0.4, dilate=0, lisse=1, angles=arc)
            if s < 0:
                Pe = [list(reversed(row)) for row in Pe]
            u0 = int(80 * k / nl); u1 = int(80 * (k + 1) / nl)
            ide = P.grille(Pe, st["mat"], C.rect_uv((u0, 96, u1, 128)), fermer=False, inverser=s < 0)
            # tranche (bord extérieur vers le bras)
            if st.get("bord_roule"):
                # bord repoussé : bourrelet épais retourné vers le bras (tranche de 2 cm, plus large que la lame simple du fer)
                tr = [p + (E0.lerp(E1, tb) - p).normalized() * 0.02 for p in Pe[1]]
            else:
                tr = [p + (E0.lerp(E1, tb) - p).normalized() * 0.012 for p in Pe[1]]
            P.grille([Pe[1], tr], st["mat"], C.rect_uv((u0, 96, u1, 98)), fermer=False, inverser=s < 0)
            for i in ide[0]:
                P.ao[i] = 0.65
        for k in range(nl):
            u0 = int(80 * k / nl)
            u1 = int(80 * (k + 1) / nl)
            C.ligne_v(t, u1 - 1, 96, 128, 0.5)
            for y in range(96, 128):           # bord bas poli (seule partie brillante de la lame)
                p_ = t.get(u1 - 2, y)
                t.set(u1 - 2, y, tuple(min(1.0, c_ * 1.6 + 0.05) for c_ in p_[:3]), 1.0)
            if st.get("bord_roule") and cote == "l":
                for y in range(97, 127):       # gravure (bande d'entrelacs le long du bord)
                    for ph in (0.0, math.pi):
                        xx = u1 - 7 + int(round(2.2 * math.sin((y - 96) * TAU / 10 + ph)))
                        t.mul(xx, y, 0.7, -0.3); t.mul(xx + 1, y, 1.12, 0.15)
            if st.get("rivets", True):
                C.rivets(t, [(u1 - 4, y) for y in range(100, 128, 7)], pal)
    # --- col de fourrure (acier nordique, gardiens) : boudin autour des épaules et de la nuque
    if st.get("fourrure"):
        def dec_f(j, i, a):
            dos = 0.5 * (1.0 - math.cos(a))          # 0 devant, 1 derrière : col épais sur la nuque et les épaules
            return ((0.025, 0.045, 0.02)[j] + (0.03, 0.045, 0.025)[j] * dos ** 0.7) + 0.012 * (_h_ang(i, 7) - 0.5)
        # ouvert devant (la barbe retombe sur la poitrine) : des épaules à la nuque seulement
        arc_f = [math.radians(x) for x in range(55, 306, 25)]
        Pf, Rf, _ = C.tube(arbre, axeA, axeB, [tz(1.45), tz(1.51), tz(1.575)], 0, dec_f, r_loin=0.6, dilate=0, lisse=1, angles=arc_f)
        P.grille(Pf, "fourrure", C.rect_uv(R_FOUR), fermer=False, inverser=True)
        # bouts du col (épaisseur sur les clavicules)
        for bout in (0, -1):
            col_b = [row[bout] for row in Pf]
            dedans = [p + (Vector((0, 0, p.z)) - p).normalized() * 0.025 for p in col_b]
            P.grille([col_b, dedans] if bout == 0 else [dedans, col_b], "fourrure", C.rect_uv((80, 96, 90, 128)), fermer=False, inverser=True)
        # mèches qui pendent (dents) sur le bas du col
        nf = len(arc_f)
        for i in range(0, nf - 1):
            a, b = Pf[0][i], Pf[0][i + 1]
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
    # manches de mailles : MÊMES poids que la manche de la cotte du héros juste dessous (transfert sans lissage, côté strict)
    Wm = C.poids_transferes(ob, r, ["tunique"], os_permis={"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "clavicle_l", "clavicle_r"}, lisser=0)
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        if abs(p.x) > 0.30 and p.z > 1.28:
            cote = "l" if p.x > 0 else "r"
            d = {k: w for k, w in Wm[v.index].items() if k.endswith("_" + cote)}
            tot = sum(d.values())
            if tot <= 0:
                d, tot = {"upperarm_" + cote: 1.0}, 1.0
            for g in list(ob.vertex_groups):
                g.remove([v.index])
            for k, w in d.items():
                if k not in ob.vertex_groups:
                    ob.vertex_groups.new(name=k)
                ob.vertex_groups[k].add([v.index], w / tot, "REPLACE")
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
    C.peau_transfert(ob, r, ["accessoires", "brassards", "peau"], lisser=1, cote_strict=True,
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
    t.zone((0, 0, 128, 64), st.get("peinture_botte", C.cuir(st.get("pal_cuir", C.CUIR), g, base=0.36)))
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
                              lambda j, i, a: ((0.016, 0.026, 0.012)[j] + 0.006 * (C._h(i, j, 5) - 0.5)) * (0.55 if abs(math.sin(a) + (1 if cote == "l" else -1)) < 0.6 else 1.0),
                              r_loin=0.4, dilate=0, lisse=1)
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
    C.peau_transfert(ob, r, ["bottes", "pantalon"], lisser=1, cote_strict=True,
                     os_permis={b.name for b in r.arm.data.bones if any(k in b.name for k in ("calf", "foot", "ball", "thigh"))})
    C.lier(ob, r)
    return ob

# =============================================================================================================== CAPUCHE
def capuche(r, st):
    """Capuche du thaumaturge v3 : la capuche v3 des mages (persos/capuche_v3, validée) TELLE QUELLE (variante « visage » : volume de
    laine autour du crâne, pointe molle vers l'arrière, bord roulé épais qui encadre le visage jusqu'au menton), seule la pèlerine
    est retirée (rangs du bas, coupe le long des UV « du bord à l'ourlet » et non à une hauteur : le tour du visage reste entier) ;
    ses propres UV + sa cuisson d'occlusion, laine bleu nuit, runes d'argent discrètes derrière le bord, aucune bande claire."""
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
    me = ob.data
    for ca in list(me.color_attributes):
        me.color_attributes.remove(ca)
    # normales personnalisées du glTF retirées : sinon, une fois les sommets écartés et les colonnes dissoutes, elles gardent
    # l'ancienne direction (plaques claires et sombres sur le crâne)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    if me.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    # col court : on retire les rangs de la pèlerine (v Blender petit = ourlet ; v = 1 : bord du visage)
    v_coupe = st.get("v_coupe", 0.15)
    bm = bmesh.new(); bm.from_mesh(me)
    uvl = bm.loops.layers.uv.verify()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if min(lp[uvl].uv[1] for lp in f.loops) < v_coupe], context="FACES")   # rang entier : ourlet net
    # rang suivant gardé seulement sur la nuque (il couvre le cou derrière), retiré au-dessus des épaules (col de fourrure)
    v_nuque, x_nuque = st.get("v_nuque", 0.15), st.get("x_nuque", 0.10)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if min(lp[uvl].uv[1] for lp in f.loops) < v_nuque
                               and abs(f.calc_center_median().x) > x_nuque], context="FACES")
    # pans libres du devant (ils pendaient sous les oreilles) : retirés sous la mâchoire
    z_pans = st.get("z_pans", 1.545)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < 0.02 and min(v.co.z for v in f.verts) < z_pans],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me); bm.free()
    # budget d'un casque (<= 600) : la capuche v3 est une grille régulière (28 colonnes le long du bord x 19 rangs du bord à l'ourlet) ;
    # une colonne sur deux est dissoute (les rangs, donc le profil du volume, du bourrelet et de la doublure, restent tous ; les UV
    # restent exactes, rien ne passe à travers)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    budget = st.get("budget", 600)
    print("CAPUCHE apres coupe", C.compter_tris(ob), "tris")
    bm = bmesh.new(); bm.from_mesh(me)
    uvl = bm.loops.layers.uv.verify()
    u_de, v_de = {}, {}
    for f in bm.faces:
        for lp in f.loops:
            u_de[lp.vert] = round(lp[uvl].uv[0], 3)
            v_de[lp.vert] = round(lp[uvl].uv[1], 3)
    us = sorted(set(u_de.values())); vs = sorted(set(v_de.values()))
    col = {v: us.index(u) for v, u in u_de.items()}
    rang = {v: vs.index(x) for v, x in v_de.items()}
    # triangles réunis en quadrilatères de la grille (diagonales seulement)
    diag = [e for e in bm.edges if not e.is_boundary and col[e.verts[0]] != col[e.verts[1]] and rang[e.verts[0]] != rang[e.verts[1]]]
    if st.get("reduire", True):
        bmesh.ops.dissolve_edges(bm, edges=diag, use_verts=False)
        impairs = [e for e in bm.edges if col[e.verts[0]] == col[e.verts[1]] and col[e.verts[0]] % 2 == 1]
        bmesh.ops.dissolve_edges(bm, edges=impairs, use_verts=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # sens des faces : le glb du mage a un enroulement incohérent (ses normales personnalisées le cachaient) ; le jeu élimine les
    # faces de dos -> trous à la nuque, plaques grises sur le crâne. Dessus et bord roulé tournés vers l'extérieur, doublure (rangs
    # v > 0,955) vers la tête
    centre_t = Vector((0.0, 0.01, 1.68))
    a_retourner = []
    for f in bm.faces:
        dedans = min(lp[uvl].uv[1] for lp in f.loops) > st.get("v_doublure", 0.955)
        dehors = f.normal.dot(f.calc_center_median() - centre_t) > 0.0
        if dehors == dedans:
            a_retourner.append(f)
    bmesh.ops.reverse_faces(bm, faces=a_retourner)
    print("CAPUCHE faces retournées", len(a_retourner), "sur", len(bm.faces))
    bm.to_mesh(me); bm.free()
    print("CAPUCHE apres reduction (%d colonnes)" % len(us), C.compter_tris(ob), "tris")
    if C.compter_tris(ob) > budget:
        md = ob.modifiers.new("dec", "DECIMATE")
        md.ratio = budget / C.compter_tris(ob)
        md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=md.name)
    # texture : portage de MageTextures.capuche_v3 (cuisson Blender R = occlusion, B = crêtes des plis), 128 x 64, palette bleu nuit
    W, H = 128, 64
    bake = bpy.data.images.load(os.path.join(C.ICI, "bake_capuche_v3.png"))
    bp = list(bake.pixels)                           # Blender : ligne 0 en bas, comme Toile et nos UV
    bw = bake.size[0]
    t = C.Toile(st["id"], W, H)
    g = st.get("graine", 61)
    pal = BLEU_NUIT
    for y in range(H):
        vg = 1.0 - (y + 0.5) / H                     # v « Godot » de la cuisson : 0 = bord du visage, 1 = ourlet
        for x in range(W):
            s = min(max(((x + 0.5) / W - 0.01) / 0.98, 0.0), 1.0)
            i = (y * bw + x) * 4
            ao, pt = (bp[i], bp[i + 2]) if bp[i + 3] > 0.5 else (0.8, 0.5)     # texels hors cuisson : valeurs neutres
            l = 0.56 + (C.bruit(x, y, 10, g, W, H) - 0.5) * 0.10 + (C.bruit(x, y, 4, g + 1, W, H) - 0.5) * 0.08
            if vg < 0.045:
                l = 0.14 + (l - 0.5) * 0.5          # doublure
                l = l + (0.40 - l) * _lisse(0.50, 0.70, abs(s - 0.5) / 0.5)
            elif vg < 0.08:
                l = 0.70 + (l - 0.5) * 0.6 + (C.bruit(x, 0, 6, g + 6, W, 1) - 0.5) * 0.18      # tranche du bord roulé
            else:
                rang = (vg - 0.08) / 0.91
                l += (ao - 0.85) * 0.55 + (pt - 0.5) * 0.40
                l += (C.bruit(x, 0, 9, g + 7, W, 1) - 0.5) * 0.20 * (1.0 - rang * 0.6)
                if rang < 0.035:
                    l += 0.08 + (C.bruit(x, y, 5, g + 8, W, H) - 0.5) * 0.2
                elif rang < 0.065:
                    l -= 0.13 if C._h(x, y, g + 3) > 0.3 else 0.05
                if rang > 0.93:
                    l -= 0.10
                dx = abs(s - 0.5) * W
                if 0.06 < rang < 0.85:
                    if dx < 0.6:
                        l -= 0.14
                    elif dx < 1.6:
                        l += 0.05
            l += (C._h(x, y, g + 9) - 0.5) * 0.05     # duvet (bruit blanc léger, aucune trame)
            if vg >= 0.045:
                l = max(l, 0.34)                        # le dessus reste de la laine bleu nuit, jamais un trou noir
            t.set(x, y, C.rampe(pal, l), 0.04)
    bpy.data.images.remove(bake)
    # runes d'argent discrètes, brodées juste derrière le bourrelet, sur le front et les tempes seulement (pas de bande pleine)
    rang0, rang1 = st.get("runes_rang", (0.10, 0.15))
    y1 = int(round((1.0 - (0.08 + rang0 * 0.91)) * H)); y0 = int(round((1.0 - (0.08 + rang1 * 0.91)) * H))
    i = 0
    x = 28
    while x < 100:
        if abs(x - 64) > 3 and C._h(i, 1, g + 11) > 0.25:
            motif = int(C._h(i, 0, g + 12) * 4)
            k = 0.34 + 0.08 * C._h(i, 2, g + 13)
            for yy in range(y0, y1):
                t.set(x, yy, C.rampe(C.ARGENT, k), 0.5)
            mid = (y0 + y1) // 2
            if motif == 0:
                t.set(x + 1, mid + 1, C.rampe(C.ARGENT, k * 0.9), 0.5)
            elif motif == 1:
                t.set(x + 1, mid - 1, C.rampe(C.ARGENT, k * 0.9), 0.5)
            elif motif == 2:
                t.set(x - 1, mid, C.rampe(C.ARGENT, k * 0.9), 0.5); t.set(x + 1, mid, C.rampe(C.ARGENT, k * 0.9), 0.5)
        x += 6
        i += 1
    for p in me.polygons:
        p.use_smooth = True
    img = t.image()
    me.materials.clear()
    me.materials.append(C.materiau("fourrure.laine", img))
    for p in me.polygons:
        p.material_index = 0
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    col = me.color_attributes["Col"]
    for d in col.data:
        d.color = (1.0, 1.0, 1.0, 1.0)
    # écartée de la peau et de la barbe (le crâne du héros est plus gros que celui du mage, le bord du visage frôle les favoris) ;
    # la doublure poussée entraîne le dessus (chaque sommet suit le plus grand déplacement de ses voisins à moins de 3 cm) : les deux
    # épaisseurs de laine bougent ensemble, la doublure ne ressort jamais à travers
    from mathutils import kdtree
    avant_deg = [v.co.copy() for v in me.vertices]
    C.degager(ob, r, ["peau", "Hair_Beard"], st.get("marge_tete", 0.022))
    # angle de la mâchoire : plus de jeu (la tête tourne entre le col qui suit les clavicules et la barbe qui suit la tête)
    C.degager(ob, r, ["peau", "Hair_Beard"], st.get("marge_machoire", 0.035), filtre=lambda p: abs(p.x) > 0.06 and p.z < 1.70)
    dep = [v.co - avant_deg[i] for i, v in enumerate(me.vertices)]
    kd = kdtree.KDTree(len(avant_deg))
    for i, p in enumerate(avant_deg):
        kd.insert(p, i)
    kd.balance()
    rayon = st.get("rayon_epaisseur", 0.03)
    for i, v in enumerate(me.vertices):
        meilleur = dep[i]
        for (_, j, d) in kd.find_range(avant_deg[i], rayon):
            dj = dep[j] * (1.0 - d / rayon)
            if dj.length > meilleur.length:
                meilleur = dj
        dep[i] = meilleur
    # pousser le long de la normale du point de barbe le plus proche froissait les parois des joues (mèches = normales en tous
    # sens -> pointes noires devant l'oreille) : on garde l'AMPLEUR (lissée sur les voisins) et on pousse en rayon horizontal depuis
    # l'axe de la tête (dessus : vers le haut), les deux épaisseurs dans la même direction
    amp = [d.length for d in dep]
    voisins = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        voisins[a].append(b); voisins[b].append(a)
    for _ in range(st.get("lisse_ampleur", 3)):
        amp = [max(amp[i], sum(amp[j] for j in voisins[i]) / max(1, len(voisins[i]))) if voisins[i] else amp[i] for i in range(len(amp))]
    for i, v in enumerate(me.vertices):
        p0 = avant_deg[i]
        rad = Vector((p0.x, p0.y - 0.01, max(0.0, p0.z - 1.70) * 1.5))
        rad = rad.normalized() if rad.length > 1e-6 else Vector((0, 0, 1))
        v.co = p0 + rad * amp[i]
    C.degager(ob, r, ["peau", "Hair_Beard"], st.get("marge_fin", 0.010))
    # col : écarté de la cotte et du col de fourrure
    avant_col = [v.co.copy() for v in me.vertices]
    C.degager(ob, r, ["mante", "tunique"], st.get("marge", 0.015), filtre=lambda p: p.z < 1.62)
    C.degager(ob, r, ["mante"], 0.045, filtre=lambda p: p.z < 1.65)
    C.degager(ob, r, ["accessoires"], 0.012, filtre=lambda p: p.z < 1.60, os_noms={"spine_03", "spine_02", "clavicle_l", "clavicle_r"})
    # même froissement contre les mèches du col de fourrure : ampleur gardée, poussée en rayon horizontal
    amp = [(v.co - avant_col[i]).length for i, v in enumerate(me.vertices)]
    for _ in range(st.get("lisse_ampleur", 3)):
        amp = [max(amp[i], sum(amp[j] for j in voisins[i]) / max(1, len(voisins[i]))) if voisins[i] else amp[i] for i in range(len(amp))]
    for i, v in enumerate(me.vertices):
        p0 = avant_col[i]
        rad = Vector((p0.x, p0.y - 0.01, 0.0))
        rad = rad.normalized() if rad.length > 1e-6 else Vector((0, 1, 0))
        v.co = p0 + rad * amp[i]
    # rabats des côtés (sous l'angle de la mâchoire, une fois écartés de la barbe) : posés sur le col de fourrure que l'épaule
    # soulève dans les coups à deux mains -> retirés ; la capuche s'arrête là en col court
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.calc_center_median().x) > st.get("x_rabat", 0.135)
                               and f.calc_center_median().y < 0.06 and f.calc_center_median().z < st.get("z_rabat", 1.63)], context="FACES")
    # dessus des épaules, derrière aussi : la clavicule soulève le col de fourrure dans les parades à deux mains
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.calc_center_median().x) > st.get("x_epaule", 0.15)
                               and f.calc_center_median().z < st.get("z_rabat", 1.63)], context="FACES")
    # îlots laissés par les coupes (bouts de pans flottant sous les oreilles) : seule la pièce principale reste
    reste, ilots = set(bm.faces), []
    while reste:
        pile = [reste.pop()]; ilot = set(pile)
        while pile:
            f = pile.pop()
            for e in f.edges:
                for g in e.link_faces:
                    if g in reste:
                        reste.discard(g); ilot.add(g); pile.append(g)
        ilots.append(ilot)
    ilots.sort(key=len)
    print("CAPUCHE ilots retires", [len(i) for i in ilots[:-1]])
    bmesh.ops.delete(bm, geom=[f for i in ilots[:-1] for f in i], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # arêtes vives au pli du bord roulé (dessus <-> doublure, sommets partagés) : sans elles la normale lissée y moyenne deux faces
    # opposées -> plaques claires et noires sur le front et le crâne en jeu
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(st.get("angle_vif", 70)))
    bm.to_mesh(me); bm.free()
    # en jeu, le ciel et le soleil éclairent fort le dessus (le bleu nuit y virait au gris pâle, faces par faces) : ombre cuite dans
    # la couleur de sommet (RVB seulement, alpha 1 = pas de neige), plus sombre vers le haut, comme la capuche du mage
    me.update()
    for ca in [a for a in me.color_attributes if a.name != "Col"]:
        me.color_attributes.remove(ca)
    col = me.color_attributes["Col"]
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    for lp in me.loops:
        nz = me.vertices[lp.vertex_index].normal.z
        k = 1.0 - st.get("ombre_dessus", 0.75) * _lisse(0.1, 0.8, nz)
        col.data[lp.index].color = (k * (1.0 - 0.2 * (1.0 - k)), k * (1.0 - 0.1 * (1.0 - k)), k, 1.0)   # l'ombre reste bleutée
    # poids (comme CapucheMage) : haut = tête, bas = col de fourrure / cotte ; le fondu descend sous le menton (le cadre du
    # visage suit la mâchoire) et reste haut sur les côtés et la nuque (le col suit les clavicules)
    W_haut = C.poids_transferes(ob, r, ["peau"], os_permis={"Head", "neck_01"}, lisser=2)
    W_bas = C.poids_transferes(ob, r, ["mante", "tunique"], os_permis={"neck_01", "spine_03", "spine_02", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"}, lisser=0)
    (fa0, fa1), (fd0, fd1) = st.get("fondu_avant", (1.50, 1.58)), st.get("fondu_dos", (1.60, 1.66))
    fc0, fc1 = st.get("fondu_cote", (1.56, 1.62))
    ob.vertex_groups.clear()
    for v in me.vertices:
        p = v.co
        # trois fondus : sous le menton (bas), sur les côtés du visage (moyen : la joue tourne contre la paroi), sur la nuque (haut)
        ks = _lisse(0.06, 0.10, abs(p.x)); kd = _lisse(0.02, 0.08, p.y)
        z0 = fa0 + (fc0 - fa0) * ks; z1 = fa1 + (fc1 - fa1) * ks
        z0 += (fd0 - z0) * kd; z1 += (fd1 - z1) * kd
        t = _lisse(z0, z1, p.z)
        d = {}
        for n, w in W_bas[v.index].items():
            d[n] = d.get(n, 0.0) + w * (1 - t)
        for n, w in W_haut[v.index].items():
            d[n] = d.get(n, 0.0) + w * t
        it = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in it) or 1.0
        for n, w in it:
            if w > 0:
                if n not in ob.vertex_groups:
                    ob.vertex_groups.new(name=n)
                ob.vertex_groups[n].add([v.index], w / tot, "REPLACE")
    C.lier(ob, r)
    return ob


def _lisse(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


BLEU_NUIT = ["#05070c", "#0a0e18", "#101626", "#171f36", "#1e2945", "#273454", "#324063", "#3f4e74"]


def deco_runes_bottes(P, t, r, st, cote, s, jambe, A, B):
    """Runes de course brodées (fil bleu-gris) en bandes sur la fourrure blanche de la botte."""
    if cote != "l":
        return
    for y0 in (14, 34):
        C.runes(t, (0, y0, 128, y0 + 7), ["#1c2a3c", "#2c4058", "#3e5674", "#56708e"], 93 + y0, k=0.75)
