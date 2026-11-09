# ARC DE CHASSEUR du joueur (fait main, d'après Desktop/photos_tripo/arc/arc_trois_vues.png) + FLÈCHE (d'après arc_presentation.png).
#   blender.exe -b --python arc_chasseur.py
# Exporte (assets/modeles/armes/) :
#   arc_chasseur.glb   arc recourbé, bois brun sombre, poignée de cuir enroulé + anneaux de cordelette, ligatures aux quarts et sous
#                      les pointes, runes gravées sur chaque branche, pointes de corne claire recourbées vers l'avant.
#                      CLÉ DE FORME « bande » = l'arc à pleine allonge (branches pliées vers l'archer). La corde n'est PAS dans le
#                      modèle : ArcModele (Godot) la tend entre les deux attaches et le point d'encoche tenu par la main droite.
#   fleche_chasseur.glb fût de bois, ligatures, empennage de trois plumes barrées, encoche, pointe de fer large à barbillons.
#   arc_chasseur.png   atlas peint 128 x 128 (bois runique, cuir, cordelette, corne, corde, fût, fer, plumes), commun aux deux.
#   arc_chasseur.json  repères pour Godot (attaches de la corde au repos / bandé, demi-longueur de corde, allonge, flèche).
#
# REPÈRE (glTF / Godot) : arc debout le long de +Y, centre de la poignée à l'origine, la corde du côté +Z (l'archer), la flèche part
# vers -Z. Flèche : encoche à l'origine, pointe vers -Z. Blender : (x, y, z)_blender = (x, -z, y)_godot (export Y-up).
import bpy, bmesh, math, os, json, random

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes")
TEX = 128

# ------------------------------------------------------------------------------------------------ atlas (coordonnées image)
# régions (x0, y0, x1, y1) en pixels, y vers le bas
R_BRANCHE = (0, 0, 32, 128)     # bois des branches, runes gravées (v : de la poignée vers la corne)
R_CUIR = (32, 0, 48, 64)        # cuir enroulé de la poignée
R_CORDELETTE = (32, 64, 48, 128)  # ligatures de cordelette
R_CORNE = (48, 0, 64, 64)       # pointes de corne (v : base -> pointe)
R_CORDE = (48, 64, 64, 128)     # corde (ArcModele.gd)
R_FUT = (64, 0, 72, 128)        # fût de la flèche
R_FER = (72, 0, 104, 32)        # pointe de fer (plan de la lame)
R_FIL = (104, 0, 112, 32)       # ligatures de la flèche
R_ENCOCHE = (112, 0, 120, 16)   # encoche de corne
R_PLUME = (72, 32, 128, 80)     # plumes (u : arrière -> avant, v : du fût vers le bord)

random.seed(7)
PIX = [[(0.5, 0.5, 0.5)] * TEX for _ in range(TEX)]


def mix(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def peindre(reg, f):
    x0, y0, x1, y1 = reg
    for y in range(y0, y1):
        for x in range(x0, x1):
            u = (x - x0 + 0.5) / (x1 - x0)
            v = (y - y0 + 0.5) / (y1 - y0)
            PIX[y][x] = f(u, v, x - x0, y - y0)


def bruit(a=0.06):
    return (random.random() - 0.5) * 2.0 * a


BOIS = [hexc(c) for c in ("#2a2119", "#3b3025", "#4d3f31", "#5f4f3e", "#6f5e4a")]   # brun sombre désaturé (arc_trois_vues)


def bois(u, v, x, y, base=0.5, fibre=1.0):
    # fibres longitudinales (le long de v) + noeuds discrets
    f = math.sin(x * 2.1 + math.sin(y * 0.19 + x) * 1.7) * 0.5 + 0.5
    t = base + (f - 0.5) * 0.3 * fibre + bruit(0.035)
    i = max(0.0, min(3.999, t * 4.0))
    return mix(BOIS[int(i)], BOIS[int(i) + 1], i - int(i))


# runes (grille 5 x 9) : traits gravés, futhark ancien simplifié
RUNES = {
    "fehu": ["X....", "X..X.", "X.X..", "XX..X", "X.XX.", "XX...", "X....", "X....", "X...."],
    "ansuz": ["X....", "XX...", "X.X..", "XX...", "X.X..", "X....", "X....", "X....", "X...."],
    "othala": ["..X..", ".X.X.", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X", "....."],
    "algiz": ["X.X.X", "X.X.X", ".XXX.", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
    "gebo": ["X...X", ".X.X.", "..X..", ".X.X.", "X...X", ".....", ".....", ".....", "....."],
    "tiwaz": ["..X..", ".XXX.", "X.X.X", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
}
ORDRE = ["fehu", "ansuz", "othala", "algiz", "tiwaz", "gebo"]


def peindre_branche():
    peindre(R_BRANCHE, lambda u, v, x, y: bois(u, v, x, y, 0.42 + 0.1 * math.sin(v * 9.0)))
    # deux GRANDES runes gravées par branche (gebo « X » et raido « R », comme sur arc_trois_vues), tracées en traits de ~3 px ;
    # chaque face de la branche reçoit toute la largeur de la bande (u 0..1 par face) : ~13 cm de haut, lisibles à 480x270
    x0, y0, _, _ = R_BRANCHE
    TRAITS = {"gebo": [((0.0, 0.0), (1.0, 1.0)), ((1.0, 0.0), (0.0, 1.0))],
              "raido": [((0.15, 0.0), (0.15, 1.0)), ((0.15, 0.0), (0.85, 0.24)), ((0.85, 0.24), (0.15, 0.5)), ((0.15, 0.5), (0.9, 1.0))]}
    def graver(nom, bx, by, lw, lh):
        creux = set()
        for (ax, ay), (bx2, by2) in TRAITS[nom]:
            n = int(max(abs(bx2 - ax) * lw, abs(by2 - ay) * lh) * 2) + 2
            for i in range(n + 1):
                t = i / n
                cxp, cyp = bx + (ax + (bx2 - ax) * t) * lw, by + (ay + (by2 - ay) * t) * lh
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if dx * dx + dy * dy <= 1:
                            creux.add((int(round(cxp)) + dx, int(round(cyp)) + dy))
        for (px, py) in creux:
            PIX[py][px] = mix(hexc("#0e0805"), hexc("#1a110b"), random.random())
        for (px, py) in creux:   # lèvres claires (lumière rasante d'en haut à droite)
            for q in ((px + 1, py), (px, py - 1)):
                if q not in creux and x0 <= q[0] < x0 + 32 and 0 <= q[1] < 128:
                    PIX[q[1]][q[0]] = mix(PIX[q[1]][q[0]], hexc("#b49a78"), 0.65)
    graver("gebo", x0 + 7, y0 + 10, 18, 30)
    graver("raido", x0 + 7, y0 + 52, 18, 32)
    for _ in range(5):
        x = random.randrange(x0, x0 + 32)
        y = random.randrange(96, 124)
        for d in range(random.randrange(2, 5)):
            if 0 <= y + d < 128:
                PIX[y + d][x] = mix(PIX[y + d][x], hexc("#1a100a"), 0.6)


def peindre_cuir():
    C = [hexc(c) for c in ("#24120d", "#3a1f16", "#50291d", "#653628")]

    def f(u, v, x, y):
        # lanières enroulées en diagonale, bord sombre, milieu clair
        d = (y + x * 0.55) % 7.0
        t = 0.15 if d < 1.0 else (0.75 - abs(d - 4.0) * 0.13)
        t += bruit(0.07)
        i = max(0.0, min(2.999, t * 3.0))
        return mix(C[int(i)], C[int(i) + 1], i - int(i))
    peindre(R_CUIR, f)


def peindre_cordelette():
    C = [hexc(c) for c in ("#251c14", "#43352a", "#5e4c3c", "#76644f")]

    def f(u, v, x, y):
        d = y % 4
        t = [0.1, 0.65, 0.9, 0.55][d] + bruit(0.08) - 0.12 * ((x + y // 4) % 3 == 0)
        i = max(0.0, min(2.999, t * 3.0))
        return mix(C[int(i)], C[int(i) + 1], i - int(i))
    peindre(R_CORDELETTE, f)


def peindre_corne():
    def f(u, v, x, y):
        base = mix(hexc("#a89c86"), hexc("#ece6d6"), min(1.0, v * 1.4))
        stries = 0.08 * math.sin(y * 1.3 + x * 0.4)
        c = mix(base, hexc("#5e4a34"), max(0.0, stries + bruit(0.05)))
        if v > 0.85:
            c = mix(c, hexc("#f6f2e8"), 0.4)
        return c
    peindre(R_CORNE, f)


def peindre_corde():
    def f(u, v, x, y):
        t = 0.5 + 0.3 * math.sin((x + y) * 1.6) + bruit(0.05)
        return mix(hexc("#1c140e"), hexc("#4a3826"), max(0.0, min(1.0, t)))
    peindre(R_CORDE, f)


def peindre_fleche():
    peindre(R_FUT, lambda u, v, x, y: mix(hexc("#6a4c30"), hexc("#a07c54"), 0.5 + 0.35 * math.sin(x * 1.9 + y * 0.07) + bruit(0.08)))

    def fer(u, v, x, y):
        # u : le long de la lame (talon -> pointe), v : travers ; arête centrale sombre, tranchants clairs
        e = abs(v - 0.5) * 2.0
        c = mix(hexc("#2c3036"), hexc("#7a8088"), e)
        if e > 0.82:
            c = hexc("#c8ccd0")
        return mix(c, hexc("#4a3020"), 0.18 if random.random() < 0.06 else 0.0)
    peindre(R_FER, fer)
    peindre(R_FIL, lambda u, v, x, y: mix(hexc("#1e140c"), hexc("#5a4630"), [0.2, 0.9, 0.6][y % 3] + bruit(0.06)))
    peindre(R_ENCOCHE, lambda u, v, x, y: mix(hexc("#2a2018"), hexc("#d8cbb0"), 0.35 + bruit(0.08)))

    def plume(u, v, x, y):
        # barbes obliques, bandes brunes, tuyau sombre au ras du fût (v ~ 0)
        c = mix(hexc("#ece6d8"), hexc("#c8bca4"), 0.5 + 0.5 * math.sin((x * 0.9 - y * 1.6)))
        bande = math.sin(u * 22.0 + v * 3.0)
        if bande > 0.55:
            c = mix(c, hexc("#5a3e26"), 0.85)
        elif bande > 0.3:
            c = mix(c, hexc("#8a6a48"), 0.5)
        if v < 0.1:
            c = hexc("#3a2c20")
        return mix(c, (0, 0, 0), max(0.0, bruit(0.06)))
    peindre(R_PLUME, plume)


def sauver_atlas(chemin):
    img = bpy.data.images.new("arc_chasseur", TEX, TEX, alpha=True)
    flat = []
    for row in range(TEX):
        y = TEX - 1 - row   # Blender : première ligne en bas
        for x in range(TEX):
            r, g, b = PIX[y][x]
            flat += [max(0.0, min(1.0, r)), max(0.0, min(1.0, g)), max(0.0, min(1.0, b)), 1.0]
    img.pixels = flat
    img.filepath_raw = chemin
    img.file_format = "PNG"
    img.save()
    return img


# ------------------------------------------------------------------------------------------------ géométrie
def uvr(reg, u, v):
    """UV d'atlas (u, v dans la région, v image vers le bas) -> UV Blender (v vers le haut)."""
    x0, y0, x1, y1 = reg
    return ((x0 + u * (x1 - x0)) / TEX, 1.0 - (y0 + v * (y1 - y0)) / TEX)


class Maille:
    def __init__(self):
        self.v = []   # positions Godot
        self.f = []   # (indices, uvs)

    def s(self, p):
        self.v.append(tuple(p))
        return len(self.v) - 1

    def face(self, idx, uvs):
        self.f.append((list(idx), list(uvs)))


def catmull(pts, n):
    """Polyligne lissée (Catmull-Rom) de `n` points par segment."""
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(pts[-1])
    return out


# demi-arc (y, z) en m : poignée en retrait, branche qui avance puis revient vers l'archer, corne recourbée vers l'avant
PROFIL = [(0.0, 0.0), (0.05, 0.0), (0.085, -0.006), (0.13, -0.022), (0.19, -0.036), (0.25, -0.04), (0.31, -0.032),
          (0.37, -0.012), (0.43, 0.018), (0.48, 0.05), (0.52, 0.082), (0.55, 0.105), (0.575, 0.122), (0.60, 0.133),
          (0.625, 0.139), (0.648, 0.148), (0.665, 0.162), (0.678, 0.182)]
FINE = catmull(PROFIL, 8)
LONG = [0.0]
for a, b in zip(FINE[:-1], FINE[1:]):
    LONG.append(LONG[-1] + math.dist(a, b))
L_DEMI = LONG[-1]


def sur_courbe(a):
    """Point et tangente (y, z) du profil à l'abscisse curviligne a."""
    a = max(0.0, min(L_DEMI, a))
    for i in range(len(LONG) - 1):
        if LONG[i + 1] >= a:
            t = (a - LONG[i]) / max(1e-9, LONG[i + 1] - LONG[i])
            p = (FINE[i][0] + (FINE[i + 1][0] - FINE[i][0]) * t, FINE[i][1] + (FINE[i + 1][1] - FINE[i][1]) * t)
            d = (FINE[i + 1][0] - FINE[i][0], FINE[i + 1][1] - FINE[i][1])
            n = math.hypot(*d)
            return p, (d[0] / n, d[1] / n)
    return FINE[-1], (0.0, 1.0)


# anneaux du demi-arc : (abscisse, demi-largeur x, demi-épaisseur, région, v dans la région)
A_CORNE = L_DEMI - 0.11      # début de la corne (fin de la ligature de pointe)
A_LIG_P = A_CORNE - 0.03      # ligature de pointe (la corde s'y attache)
A_LIG_Q = 0.30                # ligature du quart


def anneaux():
    r = []
    # poignée de cuir (0 -> 0,075), anneaux de cordelette (0,075 -> 0,095)
    r.append(("cuir", [(0.0, 0.034, 0.05, 0.5), (0.04, 0.035, 0.051, 0.75), (0.075, 0.034, 0.05, 1.0)]))
    r.append(("corde", [(0.075, 0.037, 0.053, 0.0), (0.084, 0.038, 0.054, 0.5), (0.095, 0.031, 0.047, 1.0)]))
    lim = lambda a: (0.029 - 0.01 * (a - 0.095) / (A_LIG_P - 0.095), 0.045 - 0.019 * (a - 0.095) / (A_LIG_P - 0.095))
    vb = lambda a: (a - 0.095) / (A_LIG_P - 0.095)
    seg1 = [0.095, 0.135, 0.175, 0.215, 0.255, A_LIG_Q]
    r.append(("branche", [(a, *lim(a), vb(a)) for a in seg1]))
    w, t = lim(A_LIG_Q)
    r.append(("corde", [(A_LIG_Q, w + 0.003, t + 0.003, 0.0), (A_LIG_Q + 0.009, w + 0.0035, t + 0.0035, 0.5), (A_LIG_Q + 0.018, w + 0.003, t + 0.003, 1.0)]))
    seg2 = [A_LIG_Q + 0.018, 0.36, 0.40, 0.44, 0.48, 0.52, A_LIG_P]
    r.append(("branche", [(a, *lim(a), vb(a)) for a in seg2]))
    w, t = lim(A_LIG_P)
    r.append(("corde", [(A_LIG_P, w + 0.0028, t + 0.0028, 0.0), (A_LIG_P + 0.015, w + 0.0034, t + 0.0034, 0.5), (A_CORNE, w + 0.0026, t + 0.0026, 1.0)]))
    r.append(("corne", [(A_CORNE, w, t, 0.0), (A_CORNE + 0.035, 0.0155, 0.019, 0.35), (A_CORNE + 0.075, 0.0105, 0.012, 0.7), (L_DEMI - 0.004, 0.0035, 0.004, 0.97)]))
    return r


REGION = {"cuir": R_CUIR, "corde": R_CORDELETTE, "branche": R_BRANCHE, "corne": R_CORNE}
COTES = 6


def flexion(a):
    """Part de la flexion totale accumulée à l'abscisse a (0 sur la poignée, ~1 au bout ; la corne, raide, n'ajoute presque rien)."""
    def souple(x):
        if x < 0.09:
            return 0.0
        if x < A_CORNE:
            return 1.0 - 0.35 * abs((x - 0.09) / (A_CORNE - 0.09) - 0.45)
        return 0.12
    # intégrale numérique normalisée
    n = 80
    tot = sum(souple(L_DEMI * (i + 0.5) / n) for i in range(n)) * L_DEMI / n
    acc = sum(souple(min(a, L_DEMI) * (i + 0.5) / n) for i in range(n)) * min(a, L_DEMI) / n
    return acc / tot


def courbe_pliee(A):
    """Profil plié (flexion totale A rad au bout) : chaque petit segment tourne de A·flexion(a) vers l'archer (+z)."""
    pts = [(0.0, 0.0)]
    angles = [0.0]
    for i in range(len(FINE) - 1):
        a_mil = (LONG[i] + LONG[i + 1]) * 0.5
        phi = A * flexion(a_mil)
        dy, dz = FINE[i + 1][0] - FINE[i][0], FINE[i + 1][1] - FINE[i][1]
        # rotation autour de +x : (y, z) -> (y cos - z sin, y sin + z cos)
        ry, rz = dy * math.cos(phi) - dz * math.sin(phi), dy * math.sin(phi) + dz * math.cos(phi)
        pts.append((pts[-1][0] + ry, pts[-1][1] + rz))
        angles.append(phi)
    return pts, angles


def sur_pliee(a, pts, angles):
    a = max(0.0, min(L_DEMI, a))
    for i in range(len(LONG) - 1):
        if LONG[i + 1] >= a:
            t = (a - LONG[i]) / max(1e-9, LONG[i + 1] - LONG[i])
            p = (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t)
            return p, angles[i + 1]
    return pts[-1], angles[-1]


def point_arc(a, signe, pliage):
    """Point du centre et repère (tangente, normale) dans le plan yz, demi-arc haut (signe +1) ou bas (-1)."""
    (y, z), (ty, tz) = sur_courbe(a)
    if pliage is not None:
        pts, angles = pliage
        (y, z), phi = sur_pliee(a, pts, angles)
        ty, tz = ty * math.cos(phi) - tz * math.sin(phi), ty * math.sin(phi) + tz * math.cos(phi)
    # normale (vers l'archer quand la tangente monte)
    ny, nz = -tz, ty
    return (signe * y, z), (signe * ty, tz), (signe * ny, nz)


def construire_arc(M, A):
    pliage = courbe_pliee(A) if A != 0.0 else None
    for signe in (1, -1):
        for nom, ann in anneaux():
            reg = REGION[nom]
            prec = None
            for (a, w, t, v) in ann:
                (cy, cz), _, (ny, nz) = point_arc(a, signe, pliage)
                ring = []
                # section : deux flancs plats (±x, là où sont gravées les runes, vus de profil), dos et ventre en toit
                for ox, on in ((w, -0.62 * t), (w, 0.62 * t), (0.0, t), (-w, 0.62 * t), (-w, -0.62 * t), (0.0, -t)):
                    ring.append((ox, cy + ny * on, cz + nz * on))
                vv = (0.5 + 0.5 * (a / 0.075) * signe) if nom == "cuir" else v
                if prec is not None:
                    pr, pv = prec
                    for k in range(COTES):
                        j = (k + 1) % COTES
                        u0, u1 = ((0.0, 1.0) if nom == "branche" else ((k % 3) / 3.0, (k % 3 + 1) / 3.0))
                        q = [pr[k], pr[j], ring[j], ring[k]]
                        uvs = [uvr(reg, u0, pv), uvr(reg, u1, pv), uvr(reg, u1, vv), uvr(reg, u0, vv)]
                        idx = [M.s(p) for p in q]
                        # sens : normale vers l'extérieur de la branche (centre des deux anneaux)
                        c = [sum(pp[i] for pp in q) / 4.0 for i in range(3)]
                        cen = [0.0, (pcy + cy) * 0.5, (pcz + cz) * 0.5]
                        dehors = [c[i] - cen[i] for i in range(3)]
                        a_ = [q[1][i] - q[0][i] for i in range(3)]
                        b_ = [q[2][i] - q[0][i] for i in range(3)]
                        n_ = (a_[1] * b_[2] - a_[2] * b_[1], a_[2] * b_[0] - a_[0] * b_[2], a_[0] * b_[1] - a_[1] * b_[0])
                        if sum(n_[i] * dehors[i] for i in range(3)) < 0.0:
                            idx.reverse()
                            uvs.reverse()
                        M.face(idx, uvs)
                prec = (ring, vv)
                pcy, pcz = cy, cz
            if nom == "corne":
                # bout de la corne : petit cône fermé
                (cy, cz), (ty, tz), _ = point_arc(L_DEMI, signe, pliage)
                bout = (0.0, cy + ty * 0.012, cz + tz * 0.012)
                pr, pv = prec
                for k in range(COTES):
                    j = (k + 1) % COTES
                    idx = [M.s(pr[k]), M.s(pr[j]), M.s(bout)]
                    uvs = [uvr(R_CORNE, (k % 3) / 3.0, pv), uvr(R_CORNE, (k % 3 + 1) / 3.0, pv), uvr(R_CORNE, 0.5, 1.0)]
                    q = [pr[k], pr[j], bout]
                    c = [sum(pp[i] for pp in q) / 3.0 for i in range(3)]
                    dehors = [c[0], c[1] - pcy, c[2] - pcz]
                    a_ = [q[1][i] - q[0][i] for i in range(3)]
                    b_ = [q[2][i] - q[0][i] for i in range(3)]
                    n_ = (a_[1] * b_[2] - a_[2] * b_[1], a_[2] * b_[0] - a_[0] * b_[2], a_[0] * b_[1] - a_[1] * b_[0])
                    if sum(n_[i] * dehors[i] for i in range(3)) < 0.0:
                        idx.reverse()
                        uvs.reverse()
                    M.face(idx, uvs)


def attache(A, signe=1):
    """Point d'attache de la corde (sur la ligature de pointe, côté archer)."""
    pliage = courbe_pliee(A) if A != 0.0 else None
    a = A_LIG_P + 0.012
    (cy, cz), _, (ny, nz) = point_arc(a, signe, pliage)
    e = 0.033
    return (0.0, cy + ny * e, cz + nz * e)


# ------------------------------------------------------------------------------------------------ flèche
L_FLECHE = 0.72


def construire_fleche(M):
    def tube(z0, z1, r0, r1, reg, v0=0.0, v1=1.0, n=6):
        a = [(r0 * math.cos(2 * math.pi * k / n), r0 * math.sin(2 * math.pi * k / n), z0) for k in range(n)]
        b = [(r1 * math.cos(2 * math.pi * k / n), r1 * math.sin(2 * math.pi * k / n), z1) for k in range(n)]
        for k in range(n):
            j = (k + 1) % n
            idx = [M.s(b[k]), M.s(b[j]), M.s(a[j]), M.s(a[k])]
            M.face(idx, [uvr(reg, k / n, v1), uvr(reg, (k + 1) / n, v1), uvr(reg, (k + 1) / n, v0), uvr(reg, k / n, v0)])
        return a, b
    rf = 0.0042
    # encoche (corne) puis fût en deux tronçons
    a, _ = tube(0.004, -0.014, 0.0052, 0.0052, R_ENCOCHE)
    c = M.s((0.0, 0.0, 0.006))
    for k in range(6):
        j = (k + 1) % 6
        M.face([M.s(a[k]), M.s(a[j]), c], [uvr(R_ENCOCHE, 0.0, 0.0), uvr(R_ENCOCHE, 1.0, 0.0), uvr(R_ENCOCHE, 0.5, 0.5)])
    tube(-0.014, -0.36, rf, rf, R_FUT, 0.0, 0.5)
    tube(-0.36, -0.676, rf, rf * 0.95, R_FUT, 0.5, 1.0)
    # ligatures (avant de l'empennage, derrière la pointe)
    tube(-0.155, -0.172, rf * 1.35, rf * 1.35, R_FIL)
    tube(-0.66, -0.676, rf * 1.4, rf * 1.4, R_FIL)
    # douille de fer
    tube(-0.676, -0.705, rf * 1.25, rf * 1.05, R_FER, 0.4, 0.6)
    # lame large à barbillons (plan xz), arête centrale saillante (y = ±e)
    z0 = -0.70
    T = (0.0, 0.0, -(L_FLECHE + 0.08))
    S1, S2 = (0.022, 0.0, z0 - 0.04), (-0.022, 0.0, z0 - 0.04)
    B1, B2 = (0.017, 0.0, z0 + 0.008), (-0.017, 0.0, z0 + 0.008)
    N1, N2 = (0.0055, 0.0, z0 - 0.012), (-0.0055, 0.0, z0 - 0.012)
    contour = [T, S1, B1, N1, N2, B2, S2]
    zmin, zmax = T[2], B1[2]
    uvb = lambda p: uvr(R_FER, (p[2] - zmax) / (zmin - zmax), 0.5 + p[0] / 0.05)
    for e in (0.0042, -0.0042):
        R = (0.0, e, z0 - 0.045)
        for i in range(len(contour)):
            p, q = contour[i], contour[(i + 1) % len(contour)]
            idx = [M.s(R), M.s(p), M.s(q)]
            uvs = [uvb(R), uvb(p), uvb(q)]
            if e > 0:
                idx.reverse()
                uvs.reverse()
            M.face(idx, uvs)
    # empennage : trois plumes (simple face, matériau double face dans Godot), tuyau le long du fût
    for k in range(3):
        ang = math.pi * 0.5 + k * 2 * math.pi / 3
        d = (math.cos(ang), math.sin(ang))
        prof = [(-0.022, rf), (-0.032, 0.0155), (-0.09, 0.0165), (-0.15, rf)]
        prof_bas = [(-0.022, rf), (-0.06, rf), (-0.105, rf), (-0.15, rf)]
        mid = [(-0.06, 0.0165), (-0.105, 0.0125)]
        haut = [(-0.022, rf), (-0.034, 0.016), (-0.06, 0.0172), (-0.105, 0.0128), (-0.15, rf)]
        bas = [(-0.022, rf), (-0.034, rf), (-0.06, rf), (-0.105, rf), (-0.15, rf)]
        for i in range(len(haut) - 1):
            pts = [bas[i], bas[i + 1], haut[i + 1], haut[i]]
            P = [(d[0] * r, d[1] * r, z) for (z, r) in pts]
            uvs = [uvr(R_PLUME, (-z - 0.022) / 0.128, (r - rf) / 0.014) for (z, r) in pts]
            if i == 0:
                M.face([M.s(P[0]), M.s(P[2]), M.s(P[3])], [uvs[0], uvs[2], uvs[3]])
            elif i == len(haut) - 2:
                M.face([M.s(P[0]), M.s(P[1]), M.s(P[3])], [uvs[0], uvs[1], uvs[3]])
            else:
                M.face([M.s(p) for p in P], uvs)


# ------------------------------------------------------------------------------------------------ Blender
def vers_blender(p):
    return (p[0], -p[2], p[1])


def creer_objet(nom, M, mat, cles=None):
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bv = [bm.verts.new(vers_blender(p)) for p in M.v]
    uvl = bm.loops.layers.uv.new("UVMap")
    for idx, uvs in M.f:
        bf = bm.faces.new([bv[i] for i in idx])
        bf.smooth = False
        for lo, uv in zip(bf.loops, uvs):
            lo[uvl].uv = uv
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    if cles:
        o.shape_key_add(name="Basis")
        for nom_cle, pts in cles.items():
            k = o.shape_key_add(name=nom_cle)
            for i, p in enumerate(pts):
                k.data[i].co = vers_blender(p)
    return o


def exporter(o, chemin):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", use_selection=True, export_apply=False,
                              export_materials="EXPORT", export_image_format="NONE", export_yup=True,
                              export_morph=True, export_morph_normal=True)


def construire():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(SORTIE, exist_ok=True)
    peindre_branche()
    peindre_cuir()
    peindre_cordelette()
    peindre_corne()
    peindre_corde()
    peindre_fleche()
    png = os.path.join(SORTIE, "arc_chasseur.png")
    img = sauver_atlas(png)
    mat = bpy.data.materials.new("arc_chasseur")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tn.image = img
    mat.node_tree.links.new(tn.outputs[0], bsdf.inputs[0])

    # allonge : demi-corde conservée, encoche à Z_PLEIN à pleine tension
    att0 = attache(0.0)
    demi = att0[1]                 # au repos la corde est droite : demi-longueur = hauteur de l'attache
    z_repos = att0[2]
    Z_PLEIN = z_repos + 0.40       # recul de l'encoche à pleine allonge (m)

    def longueur(A):
        p = attache(A)
        return math.hypot(p[1], Z_PLEIN - p[2])
    lo, hi = 0.0, 1.2
    for _ in range(50):
        mid = (lo + hi) * 0.5
        if longueur(mid) > demi:
            lo = mid
        else:
            hi = mid
    A = (lo + hi) * 0.5

    Ma = Maille()
    construire_arc(Ma, 0.0)
    Mb = Maille()
    construire_arc(Mb, A)
    assert len(Ma.v) == len(Mb.v)
    arc = creer_objet("arc_chasseur", Ma, mat, {"bande": Mb.v})
    exporter(arc, os.path.join(SORTIE, "arc_chasseur.glb"))

    Mf = Maille()
    construire_fleche(Mf)
    fl = creer_objet("fleche_chasseur", Mf, mat)
    exporter(fl, os.path.join(SORTIE, "fleche_chasseur.glb"))

    att1 = attache(A)
    infos = {
        "_doc": "Repères de arc_chasseur.glb (sources_blender/scripts/arc_chasseur.py) : repère Godot, arc debout le long de +Y, "
                "corde côté +Z. attache_* = attache haute de la corde (la basse est symétrique en y). Clé de forme « bande » = pleine allonge.",
        "attache_repos": list(att0), "attache_bande": list(att1), "demi_corde": demi,
        "encoche_repos_z": z_repos, "encoche_pleine_z": Z_PLEIN, "flexion_rad": A,
        "longueur_fleche": L_FLECHE, "pointe_fleche_z": -(L_FLECHE + 0.08),
        "uv_corde": [R_CORDE[0] / TEX, R_CORDE[1] / TEX, R_CORDE[2] / TEX, R_CORDE[3] / TEX],
        "hauteur_arc": 2 * max(p[1] for p in Ma.v),
        "tris_arc": sum(len(i) - 2 for i, _ in Ma.f), "tris_fleche": sum(len(i) - 2 for i, _ in Mf.f),
    }
    with open(os.path.join(SORTIE, "arc_chasseur.json"), "w", encoding="utf-8") as f:
        json.dump(infos, f, ensure_ascii=False, indent=1)
    print("ARC tris=%d fleche tris=%d flexion=%.1f deg hauteur=%.2f demi_corde=%.3f encoche %.3f -> %.3f" % (
        infos["tris_arc"], infos["tris_fleche"], math.degrees(A), infos["hauteur_arc"], demi, z_repos, Z_PLEIN))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEPOT, "sources_blender", "arc_chasseur.blend"))


construire()
