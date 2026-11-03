# Armures HD uniques : palettes, outils de peinture (traits colorés, runes, écailles, givre) et décors de géométrie (couronne du
# Jarl). Complète fer_acier/hd.py (Toile, metal, cuir, fourrure, rampe...) sans le modifier.
import math
import numpy as np
from mathutils import Vector
import commun as C
import hd as H
import pieces_hd as PH

TAU = math.tau

# ------------------------------------------------------------------------------------------------------------ palettes
FER_NOIR = ["#040405", "#08090b", "#0e1013", "#15181d", "#1d2128", "#272c35", "#333a45", "#424a58", "#555f70", "#6d7889"]
ARGENT_ANCIEN = ["#1d1f22", "#35383d", "#54585f", "#7a7f87", "#9da3ac", "#bcc2ca", "#d8dde3", "#eef1f4"]
ARGENT = ["#2a2c31", "#444850", "#656a74", "#8a909a", "#adb3bc", "#cdd2d9", "#e6e9ed"]
ACIER_GIVRE = ["#080c11", "#0e141b", "#161f29", "#1f2b38", "#2a3a4a", "#384b5e", "#496074", "#5d768b", "#748ea3", "#8fa8bb", "#adc3d3"]
BLANCHE = ["#3a3e44", "#50555c", "#686d75", "#82878f", "#9da2a9", "#b7bcc2", "#cfd3d7", "#e1e4e7", "#eff1f3"]
CUIR_ROUGE = ["#0d0405", "#170608", "#240a0d", "#350e12", "#491319", "#5e1920", "#762129", "#8e2c34", "#a53a40"]
CUIR_PALE = ["#2a2218", "#3a2f22", "#4d3f2d", "#625140", "#7a6651", "#917c63", "#a89378", "#bfaa8e"]
CUIR_NOIR = ["#070605", "#0d0b09", "#15120f", "#1e1a15", "#29231c", "#352d24", "#43392d"]
CENDRE = ["#080706", "#100e0d", "#191614", "#231f1c", "#2f2a26", "#3d3731", "#4d453d", "#605649", "#756a5b"]
BRAISE = ["#2a0a03", "#5a1505", "#962a08", "#cf4c0e", "#f97a1a", "#ffb248", "#ffe39a"]
LAINE_BLEUE = ["#070b18", "#0c1226", "#121a38", "#1a254d", "#243263", "#304179", "#3f528f"]


# ------------------------------------------------------------------------------------------------------------ traits
def trait(T, p0, p1, larg=0.35, pal=ARGENT, k=0.7, bri=0.6, creux=0.0, saillie=0.0, bruit=0.1):
    """Trait coloré (fil brodé, gravure incrustée, filet d'argent) de p0 à p1 (unités) : couleur, brillance, relief
    (saillie > 0 : en relief ; creux > 0 : gravé)."""
    (ax, ay), (bx, by) = p0, p1
    m = larg + 0.6
    rect = (min(ax, bx) - m, min(ay, by) - m, max(ax, bx) + m, max(ay, by) + m)

    def fn(t, sl, X, Y, U, V):
        vx, vy = bx - ax, by - ay
        L2 = max(vx * vx + vy * vy, 1e-9)
        s = np.clip(((X - ax) * vx + (Y - ay) * vy) / L2, 0, 1)
        d = np.hypot(X - (ax + s * vx), Y - (ay + s * vy))
        w = np.clip(1 - d / larg, 0, 1)
        m_ = w > 0
        n = (H._hash(np.floor(X * 9), np.floor(Y * 9), 31) - 0.5) * bruit
        col = H.rampe(pal, np.clip(k + n + 0.2 * (w - 0.5), 0, 1))
        t.rgb[sl] = np.where(m_[..., None], col, t.rgb[sl])
        t.bri[sl] = np.where(m_, np.maximum(t.bri[sl], bri), t.bri[sl])
        t.h[sl] = t.h[sl] + np.where(m_, saillie * np.sqrt(np.clip(w, 0, 1)) - creux * np.sqrt(np.clip(w, 0, 1)), 0.0)
    T.appliquer(rect, fn)


def poly(T, pts, fermer=False, **kw):
    for a, b in zip(pts[:-1], pts[1:]):
        trait(T, a, b, **kw)
    if fermer:
        trait(T, pts[-1], pts[0], **kw)


# glyphes runiques (vieux futhark stylisé) sur une grille [0,1] x [0,1] (x droite, y haut) : listes de segments
RUNES = {
    "fehu": [((0.2, 0), (0.2, 1)), ((0.2, 0.7), (0.85, 1.0)), ((0.2, 0.4), (0.85, 0.7))],
    "uruz": [((0.2, 0), (0.2, 1)), ((0.2, 1), (0.8, 0.75)), ((0.8, 0.75), (0.8, 0))],
    "thurs": [((0.2, 0), (0.2, 1)), ((0.2, 0.75), (0.8, 0.5)), ((0.8, 0.5), (0.2, 0.25))],
    "ansuz": [((0.2, 0), (0.2, 1)), ((0.2, 1), (0.8, 0.8)), ((0.2, 0.7), (0.8, 0.5))],
    "raido": [((0.2, 0), (0.2, 1)), ((0.2, 1), (0.8, 0.75)), ((0.8, 0.75), (0.2, 0.5)), ((0.2, 0.5), (0.8, 0))],
    "kenaz": [((0.8, 1), (0.2, 0.5)), ((0.2, 0.5), (0.8, 0))],
    "gebo": [((0.1, 0), (0.9, 1)), ((0.1, 1), (0.9, 0))],
    "wunjo": [((0.2, 0), (0.2, 1)), ((0.2, 1), (0.8, 0.75)), ((0.8, 0.75), (0.2, 0.5))],
    "hagalaz": [((0.2, 0), (0.2, 1)), ((0.8, 0), (0.8, 1)), ((0.2, 0.7), (0.8, 0.3))],
    "nauthiz": [((0.5, 0), (0.5, 1)), ((0.15, 0.35), (0.85, 0.7))],
    "isa": [((0.5, 0), (0.5, 1))],
    "jera": [((0.2, 0.75), (0.5, 1)), ((0.5, 1), (0.5, 0.45)), ((0.5, 0.55), (0.8, 0.3)), ((0.5, 0.3), (0.8, 0.0))],
    "sowilo": [((0.7, 1), (0.3, 0.65)), ((0.3, 0.65), (0.7, 0.35)), ((0.7, 0.35), (0.3, 0))],
    "tiwaz": [((0.5, 0), (0.5, 1)), ((0.15, 0.7), (0.5, 1)), ((0.5, 1), (0.85, 0.7))],
    "berkana": [((0.2, 0), (0.2, 1)), ((0.2, 1), (0.75, 0.75)), ((0.75, 0.75), (0.2, 0.5)), ((0.2, 0.5), (0.75, 0.25)), ((0.75, 0.25), (0.2, 0))],
    "othala": [((0.5, 1), (0.15, 0.65)), ((0.5, 1), (0.85, 0.65)), ((0.15, 0.2), (0.85, 0.2)), ((0.15, 0.65), (0.85, 0.2)), ((0.85, 0.65), (0.15, 0.2))],
}
NOMS_RUNES = list(RUNES)


def rune(T, x, y, h, nom, **kw):
    larg = h * 0.55
    for (a, b), (c, d) in RUNES[nom]:
        trait(T, (x + a * larg, y + b * h), (x + c * larg, y + d * h), **kw)


def ligne_runes(T, x0, x1, y, h, g, pas=None, **kw):
    pas = pas or h * 0.95
    n = int((x1 - x0) / pas)
    for i in range(n):
        nom = NOMS_RUNES[int(H._hash(i, 3, g) * len(NOMS_RUNES)) % len(NOMS_RUNES)]
        rune(T, x0 + i * pas, y, h, nom, **kw)


def cercle(T, cx, cy, r, larg=0.35, **kw):
    n = max(16, int(r * 8))
    pts = [(cx + r * math.cos(TAU * i / n), cy + r * math.sin(TAU * i / n)) for i in range(n)]
    poly(T, pts, fermer=True, larg=larg, **kw)


# ------------------------------------------------------------------------------------------------------------ givre
def givre(T, rects, g, force=0.8, pal=("#8fa6b8", "#b4c8d6", "#d5e3ec", "#eef5f9")):
    """Givre : se dépose dans les creux et sur les arêtes hautes (hauteur déjà peinte), par plaques de bruit, cristaux fins ;
    mat (pas de brillance)."""
    for rect in rects:
        def fn(t, sl, X, Y, U, V):
            h = t.h[sl]
            moy = H.flou(h, 1.4 * t.S)
            creux = np.clip((moy - h) * 3.0, 0, 1)
            n = H.fbm(X, Y, g, oct=((12, 0.5), (4, 0.3), (1.3, 0.2)))
            fin = H.fbm(X, Y, g + 5, oct=((1.2, 0.6), (0.45, 0.4)))
            seuil = 0.62 - 0.22 * force - 0.25 * creux
            k = H.lisse(seuil, seuil + 0.10, n + 0.12 * (fin - 0.5)) * force
            cristal = H.cellules(X, Y, 0.9, g + 9, jitter=1.0)
            fac = np.clip(1 - (cristal[1] - cristal[0]) / 0.18, 0, 1)
            col = H.rampe(list(pal), np.clip(0.3 + 0.5 * n + 0.2 * fac, 0, 1))
            t.rgb[sl] = t.rgb[sl] * (1 - k[..., None]) + col * k[..., None]
            t.bri[sl] = t.bri[sl] * (1 - 0.85 * k) + 0.08 * k
            t.h[sl] = h + k * (0.10 + 0.07 * fac)
        T.appliquer(rect, fn)


# ------------------------------------------------------------------------------------------------------------ écailles
def ecailles(pal, g, tip=2.8, base=0.5, braise=0.0, brillant=0.2, pal_braise=BRAISE):
    """Écailles de cuir cendré en rangs imbriqués (pointe vers le bas de la pièce) : chaque écaille bombée, biseau clair en
    haut, bord sombre, pointe arrondie, légère teinte propre ; dessous brasillant (liserés de braise) dans les jours."""
    rh = tip * 0.52

    def fn(X, Y, U, V):
        k0 = np.floor(Y / rh)
        res_rgb = np.zeros(X.shape + (3,)); res_h = np.full(X.shape, -0.3); res_bri = np.zeros(X.shape)
        couvert = np.zeros(X.shape, dtype=bool)
        rimm = np.zeros(X.shape)
        for dk in (0, -1, -2):
            k = k0 + dk
            dec = 0.5 * np.mod(k, 2)
            c = np.floor(X / tip - dec)
            cx = (c + 0.5 + dec) * tip + (H._hash(c, k, g) - 0.5) * 0.18 * tip
            lx = (X - cx) / (tip / 2)
            yl = Y - k * rh
            yl = yl + (H._hash(c, k, g + 1) - 0.5) * 0.1
            r = tip / 2
            hw = np.where(yl < r, np.sqrt(np.clip(1 - ((r - yl) / r) ** 2, 0, 1)), 1.0)
            cov = (np.abs(lx) < hw) & (yl > 0) & (yl < rh * 3.4) & ~couvert
            if not cov.any():
                continue
            e = np.clip(1 - np.abs(lx) / np.maximum(hw, 1e-3), 0, 1)
            bord = np.clip(np.minimum(e / 0.22, (yl / r) / 0.55 if True else 1), 0, 1)
            bord = np.clip(np.minimum(e / 0.20, np.clip(yl / (r * 0.6), 0, 1)), 0, 1)
            dome = np.sqrt(np.clip(bord, 0, 1))
            ide = H._hash(c, k, g + 2)
            n = H.fbm(X, Y, g + 7, oct=((4, 0.5), (1.4, 0.3), (0.5, 0.2)))
            ombre = np.clip(1 - (rh * 1.6 - yl) / (rh * 1.6), 0, 1)       # haut de l'écaille couvert par la rangée supérieure
            t = base + (ide - 0.5) * 0.14 + (n - 0.5) * 0.30 + 0.20 * (dome - 0.5) - 0.10 * np.exp(-((e) / 0.07) ** 2)
            t = t + 0.10 * np.exp(-(np.abs(lx) / 0.08) ** 2) * np.clip(yl / rh, 0, 1)         # arête centrale
            col = H.rampe(pal, np.clip(t, 0, 1))
            res_rgb = np.where(cov[..., None], col, res_rgb)
            res_h = np.where(cov, 0.34 * dome + 0.05 * dk, res_h)
            res_bri = np.where(cov, brillant * (0.6 + 0.8 * dome), res_bri)
            rimm = np.where(cov, np.clip(1 - np.minimum(e / 0.30, np.clip(yl / (r * 0.50), 0, 4)), 0, 1) * (yl < r * 1.1), rimm)
            couvert |= cov
        jours = ~couvert
        n2 = H.fbm(X, Y, g + 11, oct=((5, 0.6), (1.6, 0.4)))
        fond = H.rampe(pal, 0.04 + 0.05 * n2)
        res_rgb = np.where(jours[..., None], fond, res_rgb)
        if braise > 0:
            # braise : fentes entre les écailles (jours) et liseré incandescent sous la pointe des écailles, par plaques de bruit
            plaque = H.lisse(0.28, 0.48, H.fbm(X, Y, g + 21, oct=((14, 0.6), (5, 0.4)))) * min(1.0, braise)
            chaud = np.clip(0.38 + 0.45 * n2 + 0.25 * H.bruit(X, Y, 0.8, g + 23), 0, 1)
            glow = np.clip(jours * plaque * 1.3 + rimm * plaque * 1.1, 0, 1)
            cb = H.rampe(pal_braise, chaud)
            res_rgb = res_rgb * (1 - glow[..., None]) + cb * glow[..., None]
            res_bri = res_bri * (1 - glow)
        return res_rgb, res_bri, res_h
    return fn


# ------------------------------------------------------------------------------------------------------------ couronne
def deco_couronne(P, T, r, centre, Pts, point, st, R=(56, 82, 128, 128), pointes=9, haut=0.135, j_ring=2):
    """Couronne de fer noir du Jarl : diadème épais (bord roulé) autour du heaume, neuf pointes taillées à facettes (la pointe
    de devant, la plus haute, entre les deux autres), filets d'argent incrustés."""
    mat = st.get("mat_couronne", st["mat"])
    R_BAND = (R[0], R[1], R[2], R[1] + 14)
    R_SP = (R[0], R[1] + 14, R[2], R[3])
    n = len(Pts[0])
    ring = []
    for lo_i in range(n):
        lo = TAU * lo_i / n
        ring.append(lo)
    def rangee(out, dz):
        return [point(j_ring, lo, out) + Vector((0, 0, dz)) for lo in ring]
    rows = [rangee(0.003, 0.0), rangee(0.010, 0.002), rangee(0.011, 0.026), rangee(0.005, 0.030)]
    ids = P.grille_v(rows, mat, R_BAND, vs=[0.0, 0.1, 0.9, 1.0])
    for i in ids[0]:
        P.ao[i] = 0.7
    # dessous du diadème vers le heaume
    P.grille_v([rangee(-0.002, 0.0), rows[0]], mat, (R[0], R[1], R[2], R[1] + 1))
    P.grille_v([rows[-1], rangee(-0.002, 0.030)], mat, (R[0], R[1] + 13, R[2], R[1] + 14))
    for k in range(pointes):
        lo = TAU * k / pointes
        ci = point(j_ring, lo, 0.0)
        out = Vector((math.sin(lo), -math.cos(lo), 0.0))
        tan = Vector((math.cos(lo), math.sin(lo), 0.0))
        h = haut * (1.0 if k == 0 else 0.62 + 0.24 * (k % 2))
        w = 0.030 if k == 0 else 0.023
        base = ci + Vector((0, 0, 0.030)) + out * 0.0075
        # trois étages : base large, taille, pointe
        etages = []
        for f, ww, ee, dx in ((0.0, w, 0.0065, 0.0), (0.5, w * 0.70, 0.0055, 0.002), (0.88, w * 0.28, 0.0030, 0.005)):
            c = base + Vector((0, 0, h * f)) + out * dx
            etages.append([c - tan * ww, c + out * ee, c + tan * ww, c - out * ee])
        sid = P.grille_v(etages, mat, R_SP, fermer=True, us=None,
                         vs=[0.0, 0.5, 0.85])
        apex = P.sommet(base + Vector((0, 0, h)) + out * 0.0055)
        u0, v0, u1, v1 = C.rect_uv(R_SP)
        for i in range(4):
            P.face([sid[-1][i], sid[-1][(i + 1) % 4], apex], mat, [(u0 + (u1 - u0) * i / 4, v1 * 0.99), (u0 + (u1 - u0) * (i + 1) / 4, v1 * 0.99), (u0 + (u1 - u0) * (i + 0.5) / 4, v1)])

    def peint(T, st, g):
        # coque : fer noir ; bandes de renfort : filets d'argent larges
        for kb in range(4):
            bx0 = 40 * kb / 4; bx1 = 40 * (kb + 1) / 4
            for dx in (-1.4, 1.4):
                trait(T, ((bx0 + bx1) / 2 + dx, 83), ((bx0 + bx1) / 2 + dx, 127), larg=0.5, pal=ARGENT, k=0.62, bri=0.7, saillie=0.06)
        # nasal : liserés d'argent sur les deux arêtes
        for x in (41.2, 54.8):
            trait(T, (x, 84), (x, 127), larg=0.5, pal=ARGENT, k=0.62, bri=0.7, saillie=0.05)
        # rebord : deux gros filets d'argent et rangée de runes
        for yy in (71.4, 80.6):
            trait(T, (1, yy), (127, yy), larg=0.55, pal=ARGENT, k=0.62, bri=0.7, saillie=0.06)
        ligne_runes(T, 3, 125, 73.4, 5.2, g + 3, pas=4.6, larg=0.28, pal=ARGENT, k=0.7, bri=0.7, saillie=0.08)
        # couronne : argent ancien patiné (sombre dans les creux), biseaux vifs
        for rect in (R_BAND, R_SP):
            T.zone(rect, H.metal(ARGENT_ANCIEN, g + 50, base=0.37, contraste=0.30, martele=0.30, cellule=2.4, crasse=0.35, poli=0.85, patine=0.25),
                   sale=0.55, poli=0.6)
        T.biseau(R_BAND, larg=1.8, haut=0.4, cotes="bh", poli=1.0)
        T.biseau(R_SP, larg=1.2, haut=0.4, cotes="bh", poli=1.0)
        trait(T, (R[0] + 1, R[1] + 3.6), (R[2] - 1, R[1] + 3.6), larg=0.30, pal=("#2a2418", "#4a4030"), k=0.4, bri=0.1, creux=0.12)
        trait(T, (R[0] + 1, R[1] + 10.4), (R[2] - 1, R[1] + 10.4), larg=0.30, pal=("#2a2418", "#4a4030"), k=0.4, bri=0.1, creux=0.12)
        T.entrelacs((R[0] + 1, R[1] + 4.6, R[2] - 1, R[1] + 9.4), brins=2, larg_ruban=1.0, pas=4.6, prof=0.2)
        for k in range(pointes):
            x = R_SP[0] + (R_SP[2] - R_SP[0]) * (k + 0.5) / pointes
        trait(T, (R[0] + 1, R[1] + 1.8), (R[2] - 1, R[1] + 1.8), larg=0.4, pal=ARGENT, k=0.85, bri=0.8, creux=0.1)
    st.setdefault("peintures", []).append(peint)


# ------------------------------------------------------------------------------------------------------------ capuche HD
def _bilin(a, fx, fy):
    """a (H, W, c) ; fx, fy : tableaux de coordonnées flottantes en pixels de a (centres de pixels), bords répétés."""
    h, w = a.shape[:2]
    fx = np.clip(fx, 0, w - 1); fy = np.clip(fy, 0, h - 1)
    x0 = np.floor(fx).astype(int); y0 = np.floor(fy).astype(int)
    x1 = np.minimum(x0 + 1, w - 1); y1 = np.minimum(y0 + 1, h - 1)
    tx = (fx - x0)[..., None]; ty = (fy - y0)[..., None]
    return (a[y0, x0] * (1 - tx) + a[y0, x1] * tx) * (1 - ty) + (a[y1, x0] * (1 - tx) + a[y1, x1] * tx) * ty


def _trait_px(rgb, bri, p0, p1, larg, col, b=0.5, relief=None):
    (ax, ay), (bx, by) = p0, p1
    m = int(larg + 3)
    x0, x1 = int(max(0, min(ax, bx) - m)), int(min(rgb.shape[1], max(ax, bx) + m + 1))
    y0, y1 = int(max(0, min(ay, by) - m)), int(min(rgb.shape[0], max(ay, by) + m + 1))
    if x1 <= x0 or y1 <= y0:
        return
    Y, X = np.mgrid[y0:y1, x0:x1] + 0.5
    vx, vy = bx - ax, by - ay
    s = np.clip(((X - ax) * vx + (Y - ay) * vy) / max(vx * vx + vy * vy, 1e-9), 0, 1)
    d = np.hypot(X - (ax + s * vx), Y - (ay + s * vy))
    w = np.clip(1 - (d - larg * 0.35) / (larg * 0.65), 0, 1)
    c = np.array(col)[None, None, :] * (0.78 + 0.22 * np.sqrt(w))[..., None]
    sub = rgb[y0:y1, x0:x1]
    rgb[y0:y1, x0:x1] = sub * (1 - w[..., None]) + c * w[..., None]
    bri[y0:y1, x0:x1] = np.maximum(bri[y0:y1, x0:x1], w * b)


def capuche_hd(ob, bake_png, graine=61, W=512, Hh=256):
    """Repeint la capuche du thaumaturge en 512x256 : mêmes UV et même cuisson d'occlusion (bake_capuche_v3.png : R = occlusion,
    B = crêtes des plis) que la v3 validée ; laine tricotée (mailles en V, duvet), doublure, bord roulé, runes d'argent brodées."""
    import bpy
    bake = bpy.data.images.load(bake_png)
    bw, bh = bake.size
    bp = np.array(bake.pixels[:], dtype=np.float32).reshape(bh, bw, 4)
    bpy.data.images.remove(bake)
    ys, xs = np.mgrid[0:Hh, 0:W]
    fx = (xs + 0.5) / W * bw - 0.5
    fy = (ys + 0.5) / Hh * bh - 0.5
    b = _bilin(bp, fx, fy)
    ok = (_bilin(bp[..., 3:4], fx, fy)[..., 0] > 0.5)
    ao = np.where(ok, b[..., 0], 0.8); pt = np.where(ok, b[..., 2], 0.5)
    vg = 1.0 - (ys + 0.5) / Hh
    s = np.clip(((xs + 0.5) / W - 0.01) / 0.98, 0, 1)
    X = (xs + 0.5) / 4.0; Y = (ys + 0.5) / 4.0
    # tricot : mailles en V (colonnes de 5 px, rangs de 5 px), chacune un peu différente, duvet
    cu, cv = np.floor(xs / 5.0), np.floor(ys / 5.0)
    lu = (xs / 5.0 - cu) * 2 - 1
    lv = ys / 5.0 - cv
    v_arete = np.abs(np.abs(lu) - lv * 0.9)               # branches du V
    maille = np.clip(1 - v_arete / 0.42, 0, 1)
    ind = H._hash(cu, cv, graine)
    nuance = H.fbm(X, Y, graine, oct=((14, 0.5), (4, 0.3), (1.2, 0.2)))
    duvet = (H._hash(xs, ys, graine + 4) - 0.5)
    l = 0.52 + (nuance - 0.5) * 0.18 + (ind - 0.5) * 0.06 + (maille - 0.5) * 0.17 + duvet * 0.07
    # zones du bord vers l'ourlet
    rang = (vg - 0.08) / 0.91
    doubl = vg < 0.045
    tranche = (vg >= 0.045) & (vg < 0.08)
    corps = vg >= 0.08
    l = np.where(doubl, 0.12 + (l - 0.5) * 0.4 + 0.30 * H.lisse(0.5, 0.7, np.abs(s - 0.5) * 2), l)
    l = np.where(tranche, 0.70 + (l - 0.5) * 0.5 + (H.bruit(xs / 4.0, ys * 0 + 1, 1.5, graine + 6) - 0.5) * 0.18, l)
    l = np.where(corps, l + (ao - 0.85) * 0.55 + (pt - 0.5) * 0.40 + (H.bruit(xs / 4.0, ys * 0, 2.2, graine + 7) - 0.5) * 0.20 * (1 - np.clip(rang, 0, 1) * 0.6), l)
    l = np.where(corps & (rang < 0.035), l + 0.08, l)
    l = np.where(corps & (rang >= 0.035) & (rang < 0.065), l - 0.09, l)
    l = np.where(corps & (rang > 0.93), l - 0.10, l)
    dx = np.abs(s - 0.5) * W / 4.0
    couture = corps & (rang > 0.06) & (rang < 0.85)
    l = np.where(couture & (dx < 0.6), l - 0.14, l)
    l = np.where(couture & (dx >= 0.6) & (dx < 1.6), l + 0.05, l)
    l = np.where(vg >= 0.045, np.maximum(l, 0.30), l)
    rgb = H.rampe(LAINE_BLEUE, np.clip(l, 0, 1))
    bri = np.full((Hh, W), 0.04)
    # runes d'argent brodées derrière le bord roulé, au front et aux tempes (pas de bande pleine)
    y_run = (1.0 - (0.08 + 0.125 * 0.91)) * Hh
    hr = 0.036 * Hh
    argent = [H.hexa("#9aa6b6"), H.hexa("#7b8798")]
    pas = 5.0 * 4
    i = 0
    x = 27 * 4.0
    while x < 101 * 4.0:
        if abs(x - 64 * 4) > 12 and H._hash(i, 1, graine + 11) > 0.2:
            nom = NOMS_RUNES[int(H._hash(i, 0, graine + 12) * len(NOMS_RUNES)) % len(NOMS_RUNES)]
            for (a, bb), (c, d) in RUNES[nom]:
                _trait_px(rgb, bri, (x + a * hr * 0.55, y_run + hr - bb * hr), (x + c * hr * 0.55, y_run + hr - d * hr), 0.9, argent[int(H._hash(i, 5, graine) * 2)], b=0.4)
        x += pas
        i += 1
    # mailles du bord : finition (le bord roulé garde un fil d'argent très fin)
    rgb = np.clip(rgb * (0.94 + 0.12 * ao[..., None]), 0, 1)
    img = bpy.data.images.new("capuche_thaumaturge_hd", W, Hh, alpha=True)
    arr = np.concatenate([rgb, bri[..., None]], axis=2).astype(np.float32)   # ligne 0 = bas (comme Toile)
    img.pixels.foreach_set(arr.reshape(-1))
    img.pack()
    for m in ob.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = img
    return img


# ------------------------------------------------------------------------------------------------------------ fourrure
def fourrure_meches(pal, g, lw=3.4, rh=2.6, contraste=1.0):
    """Peau en MÈCHES pointues en rangs imbriqués (pointes vers le bas de la pièce) : chaque mèche part d'une racine sombre (ombre
    de la rangée du dessus) vers une pointe claire, poils fins en filets, bord de mèche plus sombre ; jours très sombres."""
    def fn(X, Y, U, V):
        k0 = np.floor(Y / rh)
        rgb = np.zeros(X.shape + (3,)); h = np.full(X.shape, -0.35); bri = np.zeros(X.shape)
        couvert = np.zeros(X.shape, dtype=bool)
        for dk in (0, -1, -2):
            k = k0 + dk
            dec = 0.5 * np.mod(k, 2)
            c = np.floor(X / lw - dec)
            cx = (c + 0.5 + dec) * lw + (H._hash(c, k, g) - 0.5) * 0.25 * lw
            lx = (X - cx) / (lw / 2)
            yl = Y - k * rh + (H._hash(c, k, g + 1) - 0.5) * 0.35 * rh
            longueur = rh * (2.0 + 0.8 * H._hash(c, k, g + 3))
            hw = np.clip(yl / (longueur * 0.9), 0, 1) ** 0.65
            cov = (np.abs(lx) < hw) & (yl > 0) & (yl < longueur) & ~couvert
            if not cov.any():
                continue
            tt = np.clip(yl / longueur, 0, 1)                   # 0 pointe, 1 racine
            ide = H._hash(c, k, g + 2)
            fil = H.bruit(X * 13.0, Y * 0.6, 1.0, g + 6) - 0.5 + 0.5 * (H.bruit(X * 31.0, Y * 1.1, 1.0, g + 8) - 0.5)
            bord = np.clip(np.abs(lx) / np.maximum(hw, 1e-3), 0, 1) ** 3
            v = (0.84 - 0.60 * tt ** 0.85) * contraste + (ide - 0.5) * 0.12 + fil * 0.34 - 0.14 * bord
            col = H.rampe(pal, np.clip(v, 0, 0.999))
            rgb = np.where(cov[..., None], col, rgb)
            h = np.where(cov, 0.30 * (1 - tt) + 0.05 * dk - 0.10 * bord, h)
            bri = np.where(cov, 0.04, bri)
            couvert |= cov
        fond = H.rampe(pal, 0.05 + 0.05 * H.fbm(X, Y, g + 9, oct=((3, 0.6), (1, 0.4))))
        rgb = np.where(couvert[..., None], rgb, fond)
        return rgb, bri, h
    return fn


def fourrure_touffe(pal, g, y_pointe, y_racine):
    """Bande des petites mèches 3D (apex en haut de la bande, racine en bas) : dégradé blanc-gris à la pointe -> ombre à la base,
    filets de poils dans le sens de la mèche."""
    def fn(X, Y, U, V):
        t = np.clip((Y - y_pointe) / (y_racine - y_pointe), 0, 1)          # 0 pointe, 1 racine
        fil = H.bruit(X * 7.0, Y * 0.5, 1.0, g) - 0.5
        fin = H.bruit(X * 17.0, Y * 1.0, 1.0, g + 3) - 0.5
        v = 0.90 - 0.78 * t ** 0.8 + fil * 0.28 + fin * 0.14
        rgb = H.rampe(pal, np.clip(v, 0, 0.999))
        return rgb, np.full(X.shape, 0.04), 0.35 * (1 - t) + fil * 0.2
    return fn
