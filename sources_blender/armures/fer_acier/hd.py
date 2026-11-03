# Armures HD fer / acier nordique (charte CHARTE_ARMURES_HD.md, 2026-11-02) : peinture des textures 512²–1024² en numpy.
# Toile en « unités » : la texture entière fait BASE = 128 unités (mêmes rectangles d'atlas que les générateurs de l'agent Y,
# commun.rect_uv), peinte à S = px / 128 pixels par unité. Chaque zone fournit couleur + brillance + HAUTEUR ; finir() éclaire la
# hauteur (lumière du haut, relief cuit dans la couleur : rivets bombés, mailles en anneaux, coups de marteau, gravures creusées),
# assombrit et salit les creux (rouille pour le fer, patine sombre pour l'acier), polit les arêtes (brillance). Bruit seulement :
# aucune trame ordonnée, aucun aplat « camouflage ».
import math
import numpy as np

BASE = 128
TAU = math.tau


# ------------------------------------------------------------------------------------------------------------ outils
def hexa(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16) / 255.0, int(s[2:4], 16) / 255.0, int(s[4:6], 16) / 255.0)


def rampe(pal, t):
    """pal : liste de '#rrggbb' ; t : tableau 0..1 -> (..., 3), interpolé."""
    cols = np.array([hexa(c) if isinstance(c, str) else c for c in pal])
    t = np.clip(np.asarray(t, dtype=np.float64), 0.0, 0.9999) * (len(cols) - 1)
    i = np.floor(t).astype(np.int64)
    f = (t - i)[..., None]
    return cols[i] * (1 - f) + cols[np.minimum(i + 1, len(cols) - 1)] * f


def lisse(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _hash(ix, iy, g):
    ix = np.asarray(ix, dtype=np.int64); iy = np.asarray(iy, dtype=np.int64)
    n = (ix * 374761393 + iy * 668265263 + int(g) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def bruit(x, y, ech, g):
    """Bruit de valeur lissé (x, y en unités, ech = taille de la cellule en unités)."""
    fx, fy = x / ech, y / ech
    x0, y0 = np.floor(fx), np.floor(fy)
    tx, ty = fx - x0, fy - y0
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
    a = _hash(x0, y0, g); b = _hash(x0 + 1, y0, g); c = _hash(x0, y0 + 1, g); d = _hash(x0 + 1, y0 + 1, g)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(x, y, g, oct=((16, 0.5), (6, 0.3), (2, 0.2))):
    s = 0.0; t = 0.0
    for k, (e, a) in enumerate(oct):
        s = s + bruit(x, y, e, g + 17 * k) * a
        t += a
    return s / t


def cellules(x, y, ech, g, jitter=0.8):
    """Voronoï : (d1, d2, id) en unités / ech (distance au germe le plus proche, au 2e, identifiant du plus proche)."""
    fx, fy = x / ech, y / ech
    cx, cy = np.floor(fx), np.floor(fy)
    d1 = np.full(fx.shape, 9.0); d2 = np.full(fx.shape, 9.0); ide = np.zeros(fx.shape)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx, gy = cx + dx, cy + dy
            px = gx + 0.5 + (_hash(gx, gy, g) - 0.5) * jitter
            py = gy + 0.5 + (_hash(gx, gy, g + 1) - 0.5) * jitter
            d = np.hypot(fx - px, fy - py)
            plus_pres = d < d1
            d2 = np.where(plus_pres, d1, np.minimum(d2, d))
            ide = np.where(plus_pres, _hash(gx, gy, g + 2), ide)
            d1 = np.where(plus_pres, d, d1)
    return d1, d2, ide


def flou(a, r):
    """Flou boîte séparable, 2 passes (~gaussien), rayon r px, bords répétés."""
    r = int(max(1, round(r)))
    for _ in range(2):
        for ax in (0, 1):
            p = np.pad(a, [(r + 1, r)] if a.ndim == 1 else ([(r + 1, r), (0, 0)] if ax == 0 else [(0, 0), (r + 1, r)]), mode="edge")
            c = np.cumsum(p, axis=ax)
            if ax == 0:
                a = (c[2 * r + 1:, :] - c[:-2 * r - 1, :]) / (2 * r + 1)
            else:
                a = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return a


# ------------------------------------------------------------------------------------------------------------ toile
class Toile:
    """rgb (H, W, 3), bri (brillance = alpha), h (hauteur en unités), creux_fer (rouille admise dans les creux 0..1),
    creux_sale (crasse admise), poli (arêtes polies admises). Ligne 0 = bas (v = 0), comme les UV Blender."""

    def __init__(self, nom, px=512):
        self.nom, self.N, self.S = nom, px, px / BASE
        self.rgb = np.zeros((px, px, 3))
        self.bri = np.zeros((px, px))
        self.h = np.zeros((px, px))
        self.rouille = np.zeros((px, px))
        self.sale = np.full((px, px), 0.5)
        self.poli = np.zeros((px, px))
        self.relief = np.ones((px, px))
        # compatibilité avec les générateurs de l'agent Y (t.__dict__.get("pal"))
        self.pal = None

    def _px(self, rect):
        x0, y0, x1, y1 = rect
        S = self.S
        return (max(0, int(round(x0 * S))), max(0, int(round(y0 * S))), min(self.N, int(round(x1 * S))), min(self.N, int(round(y1 * S))))

    def coords(self, rect):
        X0, Y0, X1, Y1 = self._px(rect)
        xs = (np.arange(X0, X1) + 0.5) / self.S
        ys = (np.arange(Y0, Y1) + 0.5) / self.S
        X, Y = np.meshgrid(xs, ys)
        x0, y0, x1, y1 = rect
        U = (X - x0) / max(1e-6, x1 - x0)
        V = (Y - y0) / max(1e-6, y1 - y0)
        return (slice(Y0, Y1), slice(X0, X1)), X, Y, U, V

    def zone(self, rect, fn, rouille=0.0, sale=0.5, poli=0.0, relief=1.0):
        """fn(X, Y, U, V) -> (rgb, bri, h) ; remplace la zone."""
        sl, X, Y, U, V = self.coords(rect)
        if X.size == 0:
            return
        rgb, bri, h = fn(X, Y, U, V)
        self.rgb[sl] = rgb
        self.bri[sl] = bri
        self.h[sl] = h if h is not None else 0.0
        self.rouille[sl] = rouille
        self.sale[sl] = sale
        self.poli[sl] = poli
        self.relief[sl] = relief

    def appliquer(self, rect, fn):
        """fn(self, sl, X, Y, U, V) : retouche libre d'une zone (accès direct aux tableaux)."""
        sl, X, Y, U, V = self.coords(rect)
        if X.size:
            fn(self, sl, X, Y, U, V)

    # --------------------------------------------------------------------------------------------- reliefs
    def biseau(self, rect, larg=1.2, haut=0.35, cotes="bhgd", poli=1.0, arrondi=True):
        """Plaque en relief : la surface est haute, les bords descendent en biseau sur `larg` unités (arête polie au sommet du
        biseau). cotes : b(as) h(aut) g(auche) d(roite)."""
        def fn(t, sl, X, Y, U, V):
            x0, y0, x1, y1 = rect
            d = np.full(X.shape, 99.0)
            if "b" in cotes: d = np.minimum(d, Y - y0)
            if "h" in cotes: d = np.minimum(d, y1 - Y)
            if "g" in cotes: d = np.minimum(d, X - x0)
            if "d" in cotes: d = np.minimum(d, x1 - X)
            k = np.clip(d / larg, 0, 1)
            prof = np.sqrt(1 - (1 - k) ** 2) if arrondi else k
            t.h[sl] += haut * (prof - 1.0)
            arete = np.exp(-((d - larg * 0.55) / (larg * 0.35)) ** 2)
            t.poli[sl] = np.maximum(t.poli[sl], poli * arete)
        self.appliquer(rect, fn)

    def rainure(self, p0, p1, larg=0.35, prof=0.25, clair=0.0):
        """Rainure (gravure / jointure) le long du segment p0 -> p1 (unités), profil arrondi."""
        (ax, ay), (bx, by) = p0, p1
        m = larg + 0.5
        rect = (min(ax, bx) - m, min(ay, by) - m, max(ax, bx) + m, max(ay, by) + m)
        def fn(t, sl, X, Y, U, V):
            vx, vy = bx - ax, by - ay
            L2 = max(vx * vx + vy * vy, 1e-9)
            s = np.clip(((X - ax) * vx + (Y - ay) * vy) / L2, 0, 1)
            d = np.hypot(X - (ax + s * vx), Y - (ay + s * vy))
            k = np.clip(1 - d / larg, 0, 1)
            t.h[sl] -= prof * np.sqrt(k * (2 - k)) * (k > 0)
        self.appliquer(rect, fn)

    def ligne_h(self, y, x0, x1, larg=0.35, prof=0.25):
        self.rainure((x0, y), (x1, y), larg, prof)

    def ligne_v(self, x, y0, y1, larg=0.35, prof=0.25):
        self.rainure((x, y0), (x, y1), larg, prof)

    def rivets(self, pts, r=0.75, pal=None, haut=0.45, k=0.62, rouille=None):
        """Rivets bombés (calotte), tête un peu plus claire et polie, collerette sombre (le creux autour la salit)."""
        for (cx, cy) in pts:
            rect = (cx - r - 0.6, cy - r - 0.6, cx + r + 0.6, cy + r + 0.6)
            def fn(t, sl, X, Y, U, V, cx=cx, cy=cy):
                d = np.hypot(X - cx, Y - cy) / r
                dome = np.sqrt(np.clip(1 - d * d, 0, 1))
                m = d < 1
                t.h[sl] = np.where(m, np.maximum(t.h[sl], t.h[sl] * 0.3 + haut * dome + 0.05), t.h[sl] - 0.08 * np.exp(-((d - 1.15) / 0.18) ** 2))
                if pal is not None:
                    n = _hash(np.floor(X * 7), np.floor(Y * 7), 5) * 0.06
                    c = rampe(pal, np.full(X.shape, k) + n)
                    t.rgb[sl] = np.where(m[..., None], c, t.rgb[sl])
                t.bri[sl] = np.where(m, np.maximum(t.bri[sl], 0.75), t.bri[sl])
                t.poli[sl] = np.where(m, np.maximum(t.poli[sl], 0.6 * dome), t.poli[sl])
                if rouille is not None:
                    t.rouille[sl] = np.where(m, rouille, t.rouille[sl])
            self.appliquer(rect, fn)

    def couture(self, p0, p1, pas=1.1, pal=("#2a2118", "#4a3b2a", "#6d5a43", "#8a7559"), larg=0.22):
        """Points de couture (fil clair en relief) le long d'un segment, trous sombres entre les points."""
        (ax, ay), (bx, by) = p0, p1
        L = math.hypot(bx - ax, by - ay)
        n = max(1, int(L / pas))
        for i in range(n):
            s0 = (i + 0.15) / n; s1 = (i + 0.7) / n
            a = (ax + (bx - ax) * s0, ay + (by - ay) * s0); b = (ax + (bx - ax) * s1, ay + (by - ay) * s1)
            rect = (min(a[0], b[0]) - 0.6, min(a[1], b[1]) - 0.6, max(a[0], b[0]) + 0.6, max(a[1], b[1]) + 0.6)
            def fn(t, sl, X, Y, U, V, a=a, b=b):
                vx, vy = b[0] - a[0], b[1] - a[1]
                L2 = max(vx * vx + vy * vy, 1e-9)
                s = np.clip(((X - a[0]) * vx + (Y - a[1]) * vy) / L2, 0, 1)
                d = np.hypot(X - (a[0] + s * vx), Y - (a[1] + s * vy))
                m = d < larg
                t.h[sl] = np.where(m, t.h[sl] + 0.12 * np.sqrt(np.clip(1 - (d / larg) ** 2, 0, 1)), t.h[sl])
                t.rgb[sl] = np.where(m[..., None], rampe(list(pal), 0.55 + 0.3 * (1 - d / larg)), t.rgb[sl])
            self.appliquer(rect, fn)

    def rayures(self, rect, n, g, longueur=(2.0, 7.0), clair=0.10):
        """Rayures fines (métal frotté) : traits clairs et polis, très légère rainure."""
        x0, y0, x1, y1 = rect
        for i in range(n):
            cx = x0 + (x1 - x0) * float(_hash(i, 1, g)); cy = y0 + (y1 - y0) * float(_hash(i, 2, g))
            a = float(_hash(i, 3, g)) * math.pi
            L = longueur[0] + (longueur[1] - longueur[0]) * float(_hash(i, 4, g))
            p0 = (cx - math.cos(a) * L / 2, cy - math.sin(a) * L / 2); p1 = (cx + math.cos(a) * L / 2, cy + math.sin(a) * L / 2)
            r = (max(x0, min(p0[0], p1[0]) - 0.4), max(y0, min(p0[1], p1[1]) - 0.4), min(x1, max(p0[0], p1[0]) + 0.4), min(y1, max(p0[1], p1[1]) + 0.4))
            if r[2] <= r[0] or r[3] <= r[1]:
                continue
            def fn(t, sl, X, Y, U, V, p0=p0, p1=p1):
                vx, vy = p1[0] - p0[0], p1[1] - p0[1]
                L2 = max(vx * vx + vy * vy, 1e-9)
                s = np.clip(((X - p0[0]) * vx + (Y - p0[1]) * vy) / L2, 0, 1)
                d = np.hypot(X - (p0[0] + s * vx), Y - (p0[1] + s * vy))
                m = (d < 0.14) & (s > 0) & (s < 1)
                fade = np.sin(np.clip(s, 0, 1) * math.pi)
                t.rgb[sl] = np.where(m[..., None], t.rgb[sl] * (1 + clair * 4 * fade[..., None]) + clair * 0.3 * fade[..., None], t.rgb[sl])
                t.bri[sl] = np.where(m, np.minimum(1.0, t.bri[sl] + 0.3 * fade), t.bri[sl])
            self.appliquer(r, fn)

    def entrelacs(self, rect, larg_ruban=None, prof=0.22, filets=True, poli=0.8, brins=2, pas=None):
        """Bande d'entrelacs nordiques GRAVÉS : `brins` rubans sinusoïdaux qui se croisent dessus / dessous en alternance (le ruban
        du dessous s'interrompt de part et d'autre du croisement), contour des rubans creusé, dessus des rubans poli ; filets
        bordant la bande en haut et en bas."""
        x0, y0, x1, y1 = rect
        H = y1 - y0
        w = larg_ruban or H * 0.22
        lam = pas or H * 2.2
        A = H / 2 - w * 0.75 - (0.5 if filets else 0.1)
        yc = (y0 + y1) / 2
        def fn(t, sl, X, Y, U, V):
            ph = [TAU * k / brins for k in range(brins)]
            ds, sig = [], []
            for p in ph:
                arg = (X - x0) * TAU / lam + p
                f = yc + A * np.sin(arg)
                fp = A * TAU / lam * np.cos(arg)
                ds.append(np.abs(Y - f) / np.sqrt(1 + fp * fp))
                sig.append(np.cos(arg))
            sillon = np.zeros(X.shape)
            dessus = np.zeros(X.shape)
            for i in range(brins):
                d = ds[i]
                contour = np.exp(-((d - w / 2) / 0.16) ** 2)
                dedans = d < w / 2
                # dessus / dessous : alternance à chaque croisement (signe de la dérivée et numéro du demi-pas)
                masque = np.ones(X.shape, dtype=bool)
                for j in range(brins):
                    if j == i:
                        continue
                    k = np.floor((X - x0) / (lam / 2))
                    au_dessus = ((k + i + j) % 2 == 0)
                    pres = ds[j] < w / 2 + 0.35
                    masque &= ~(pres & ~au_dessus)
                sillon = np.maximum(sillon, contour * masque)
                dessus = np.maximum(dessus, (dedans & masque) * 1.0)
                # filet central du ruban (ruban double, très fin)
                sillon = np.maximum(sillon, 0.5 * np.exp(-(d / 0.11) ** 2) * masque)
            if filets:
                for yy in (y0 + 0.35, y1 - 0.35):
                    sillon = np.maximum(sillon, np.exp(-((Y - yy) / 0.15) ** 2))
            t.h[sl] -= prof * sillon
            t.rgb[sl] *= (1 - 0.35 * sillon)[..., None]
            t.poli[sl] = np.maximum(t.poli[sl], poli * dessus * 0.55)
            t.bri[sl] = np.where(dessus > 0, np.minimum(1, t.bri[sl] + 0.12), t.bri[sl] * (1 - 0.5 * sillon))
        self.appliquer(rect, fn)

    # --------------------------------------------------------------------------------------------- finition
    def finir(self, lum=(-0.30, 0.80, 0.52), force=1.0, rouille_pal=None, crasse_pal=None, g=0):
        S = self.S
        h = self.h
        gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * S / 2.0
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * S / 2.0
        gx[:, 0] = gx[:, -1] = 0; gy[0, :] = gy[-1, :] = 0
        gx *= self.relief; gy *= self.relief
        L = np.array(lum, dtype=np.float64); L /= np.linalg.norm(L)
        nz = 1.0 / np.sqrt(1 + gx * gx + gy * gy)
        nx, ny = -gx * nz, -gy * nz
        dif = nx * L[0] + ny * L[1] + nz * L[2]
        k = np.clip(dif / L[2], 0.25, 1.7)
        k = 1.0 + (k - 1.0) * force
        rgb = self.rgb * k[..., None]
        # creux (occlusion) : hauteur sous la moyenne locale
        moy = flou(h, 1.0 * S)
        creux = np.clip((moy - h) * 2.2, 0, 1)
        large = np.clip((flou(h, 3.0 * S) - h) * 1.2, 0, 1)
        ao = 1.0 - 0.55 * np.clip(creux + 0.5 * large, 0, 1)
        rgb *= ao[..., None]
        X, Y = np.meshgrid((np.arange(self.N) + 0.5) / S, (np.arange(self.N) + 0.5) / S)
        n = fbm(X, Y, g + 900, oct=((5, 0.5), (1.6, 0.3), (0.5, 0.2)))
        dep = np.clip(creux * 1.6 + large * 0.8, 0, 1) * (0.55 + 0.9 * n)
        if rouille_pal is None:
            rouille_pal = ["#2a1409", "#43200d", "#5e2e12", "#7a3d18", "#96521f", "#a8662c"]
        if crasse_pal is None:
            crasse_pal = ["#0b0907", "#15110c", "#211a12", "#2c2318"]
        kr = np.clip(dep * self.rouille, 0, 1)
        rc = rampe(rouille_pal, 0.25 + 0.6 * n)
        rgb = rgb * (1 - kr[..., None]) + rc * kr[..., None]
        ks = np.clip(dep * self.sale * 0.8, 0, 1)
        cc = rampe(crasse_pal, 0.3 + 0.5 * n)
        rgb = rgb * (1 - ks[..., None]) + cc * ks[..., None]
        bri = self.bri * (1 - 0.8 * np.clip(kr + ks, 0, 1))
        # arêtes polies : bosses locales (au-dessus de la moyenne) dans les zones qui l'admettent
        bosse = np.clip((h - moy) * 3.0, 0, 1)
        kp = np.clip(self.poli * (0.5 + bosse), 0, 1)
        rgb = rgb * (1 + 0.55 * kp[..., None]) + 0.05 * kp[..., None]
        bri = np.maximum(bri, kp)
        self.rgb_fini = np.clip(rgb, 0, 1)
        self.bri_fini = np.clip(bri, 0, 1)
        return self

    def tableau(self):
        if not hasattr(self, "rgb_fini"):
            self.finir()
        return np.concatenate([self.rgb_fini, self.bri_fini[..., None]], axis=2)

    def image(self, chemin_png=None):
        import bpy
        a = self.tableau()
        img = bpy.data.images.new(self.nom, self.N, self.N, alpha=True)
        img.pixels.foreach_set(a.astype(np.float32).reshape(-1))
        if chemin_png:
            img.filepath_raw = chemin_png
            img.file_format = "PNG"
            img.save()
        img.pack()
        return img


# ------------------------------------------------------------------------------------------------------------ matières
def metal(pal, g, base=0.5, contraste=0.3, martele=0.0, cellule=2.4, oxyde=0.0, crasse=0.0, poli=0.5, patine=0.15, grain=0.04):
    """Métal : nuances lentes (patine), grain fin, coups de marteau (cuvettes de Voronoï, hauteur), plaques de rouille / crasse."""
    def fn(X, Y, U, V):
        n = fbm(X, Y, g, oct=((14, 0.45), (5, 0.3), (1.8, 0.25)))
        lent = fbm(X, Y, g + 5, oct=((40, 0.7), (18, 0.3)))
        t = base + (n - 0.5) * contraste - (lent - 0.5) * patine * 2
        t = t + (_hash(np.floor(X * 8), np.floor(Y * 8), g + 9) - 0.5) * grain
        h = (n - 0.5) * 0.04
        if martele > 0:
            d1, d2, ide = cellules(X, Y, cellule, g + 61)
            cuv = np.clip(1 - d1 / 0.75, 0, 1) ** 1.6
            h = h - martele * 0.30 * cuv
            t = t + (ide - 0.5) * 0.06 * martele
            # facettes : arête entre cuvettes légèrement plus claire (le marteau tend le métal)
            t = t + martele * 0.05 * np.clip(1 - (d2 - d1) / 0.12, 0, 1)
        rgb = rampe(pal, t)
        bri = np.clip(poli * (0.45 + 0.6 * n), 0, 1)
        if oxyde > 0:
            o = fbm(X, Y, g + 41, oct=((9, 0.5), (3, 0.3), (1, 0.2)))
            seuil = 1.0 - oxyde * 0.45
            k = lisse(seuil, seuil + 0.12, o)
            rc = rampe(["#2b1509", "#46220e", "#623013", "#7d4019", "#985423", "#a96a33"], 0.2 + 0.7 * fbm(X, Y, g + 43, oct=((2, 0.6), (0.7, 0.4))))
            rgb = rgb * (1 - k[..., None]) + rc * k[..., None]
            bri = bri * (1 - 0.85 * k)
            h = h + k * (fbm(X, Y, g + 44, oct=((0.8, 0.6), (0.3, 0.4))) - 0.3) * 0.12
        if crasse > 0:
            o = fbm(X, Y, g + 77, oct=((16, 0.6), (5, 0.4)))
            seuil = 1.0 - crasse * 0.45
            k = lisse(seuil, seuil + 0.2, o) * 0.75
            rgb = rgb * (1 - k[..., None]) + rampe(["#0d0a07", "#18130d", "#251d14"], 0.5 * o)[...] * k[..., None]
            bri = bri * (1 - 0.7 * k)
        return rgb, bri, h
    return fn


def maille(pal, g, pu=1.15, pv=0.85, base=0.5, rouille=0.0, contraste=0.25):
    """Cotte de mailles RÉELLE : anneaux en rangs décalés (4 dans 1), inclinés en alternance d'un rang à l'autre, relief torique
    (hauteur), jours sombres ; teinte et position des anneaux légèrement aléatoires (pas de trame régulière visible)."""
    def fn(X, Y, U, V):
        r0 = np.floor(Y / pv)
        H = np.full(X.shape, -0.3); T = np.zeros(X.shape); ID = np.zeros(X.shape)
        for dr in (-1, 0, 1):
            rr = r0 + dr
            off = 0.5 * np.mod(rr, 2)
            c0 = np.floor(X / pu - off)
            sens = np.where(np.mod(rr, 2) == 0, 1.0, -1.0)
            for dc in (-1, 0, 1):
                cc = c0 + dc
                jx = (_hash(cc, rr, g) - 0.5) * 0.08 * pu
                jy = (_hash(cc, rr, g + 1) - 0.5) * 0.08 * pv
                xc = (cc + 0.5 + off) * pu + jx
                yc = (rr + 0.5) * pv + jy
                dx = X - xc; dy = Y - yc
                dxp = dx + 0.35 * dy * sens
                e = np.sqrt((dxp / (0.66 * pu)) ** 2 + (dy / (0.92 * pv)) ** 2)
                q = 1 - ((e - 0.74) / 0.24) ** 2
                anneau = np.sqrt(np.clip(q, 0, 1))
                # le haut de chaque anneau passe sur le rang du dessous (recouvrement des rangs suspendus)
                hh = np.where(q > 0, 0.30 * anneau + 0.06 * np.clip(dy / pv + 0.5, 0, 1), -0.3)
                plus = hh > H
                H = np.where(plus, hh, H)
                T = np.where(plus, anneau, T)
                ID = np.where(plus, _hash(cc, rr, g + 2), ID)
        sur = H > -0.2
        n = fbm(X, Y, g + 7, oct=((12, 0.6), (4, 0.4)))
        t = np.where(sur, base + 0.28 * (T - 0.5) + (ID - 0.5) * contraste * 0.6 + (n - 0.5) * 0.25, 0.04 + 0.04 * n)
        rgb = rampe(pal, t)
        bri = np.where(sur, 0.35 + 0.55 * T, 0.0)
        if rouille > 0:
            o = fbm(X, Y, g + 11, oct=((8, 0.6), (2.5, 0.4)))
            k = lisse(1 - rouille * 0.5, 1.12 - rouille * 0.5, o) * sur
            rgb = rgb * (1 - 0.8 * k[..., None]) + rampe(["#3a1c0b", "#5a2b12", "#7a3e1a", "#93552a"], ID)[...] * 0.8 * k[..., None]
            bri = bri * (1 - 0.7 * k)
        Hn = np.where(sur, H, -0.25)
        return rgb, bri, Hn
    return fn


def cuir(pal, g, base=0.45, use=0.5, grain_ech=0.38):
    """Cuir : grain en petites cellules (relief), nuances, zones élimées plus claires et mates, éraflures."""
    def fn(X, Y, U, V):
        n = fbm(X, Y, g, oct=((10, 0.45), (3.5, 0.35), (1.2, 0.2)))
        d1, d2, ide = cellules(X, Y, grain_ech, g + 3, jitter=0.9)
        pli = np.clip(1 - (d2 - d1) / 0.10, 0, 1)
        t = base + (n - 0.5) * 0.45 + (ide - 0.5) * 0.05 - 0.06 * pli
        o = fbm(X, Y, g + 31, oct=((12, 0.6), (4, 0.4)))
        k = lisse(0.62, 0.8, o) * use
        t = t + 0.22 * k
        rgb = rampe(pal, t)
        bri = (0.10 + 0.20 * n) * (1 - 0.6 * k)
        h = -0.05 * pli + (n - 0.5) * 0.08
        return rgb, bri, h
    return fn


def fourrure(pal, g, base=0.5, meches=0.55, longueur=3.0):
    """Fourrure : mèches allongées dans le sens de V (pointes en bas de zone claires, racines sombres), relief en brins."""
    def fn(X, Y, U, V):
        b1 = bruit(X * 3.2, Y / longueur * 1.0, 1.0, g)
        b2 = bruit(X * 7.0, Y / longueur * 2.2, 1.0, g + 5)
        b3 = bruit(X * 16.0, Y / longueur * 4.0, 1.0, g + 9)
        m = b1 * 0.5 + b2 * 0.32 + b3 * 0.18
        touffe = fbm(X, Y, g + 13, oct=((6, 0.7), (2, 0.3)))
        t = base + (m - 0.5) * meches * 1.6 + (touffe - 0.5) * 0.35 + (0.5 - V) * 0.10
        rgb = rampe(pal, t)
        bri = 0.05 + 0.18 * m
        h = (m - 0.5) * 0.5 + (touffe - 0.5) * 0.4
        return rgb, bri, h
    return fn


def melange(fn_a, fn_b, masque):
    """masque(X, Y, U, V) -> 0..1 : fn_b là où 1."""
    def fn(X, Y, U, V):
        a = fn_a(X, Y, U, V); b = fn_b(X, Y, U, V); k = masque(X, Y, U, V)
        ha = a[2] if a[2] is not None else 0.0
        hb = b[2] if b[2] is not None else 0.0
        return a[0] * (1 - k[..., None]) + b[0] * k[..., None], a[1] * (1 - k) + b[1] * k, ha * (1 - k) + hb * k
    return fn


# palettes : acier sombre patiné (v2 validée) et fer forgé brun-gris, cuirs, fourrure de loup
ACIER = ["#0b0c0e", "#15171a", "#202328", "#2d3137", "#3c4148", "#4e545b", "#62686f", "#797f85", "#93989d", "#b0b4b7", "#d0d3d4"]
ACIER_SOMBRE = ["#08090b", "#101216", "#181b20", "#22262c", "#2e3339", "#3c4249", "#4d535a", "#62686f", "#7c8288", "#a0a5aa", "#c8cbcd"]
FER = ["#0d0d0e", "#151618", "#1e2023", "#282a2e", "#33363a", "#404347", "#4f5256", "#616468", "#777a7c", "#929496"]
LAITON = ["#1a1308", "#2c210f", "#433217", "#5c4620", "#775c2b", "#917339", "#a98a4b", "#c0a263"]
CUIR = ["#0f0905", "#190f09", "#25160d", "#321e12", "#402717", "#4f301d", "#603b24", "#72472c", "#86553a"]
CUIR_NOIR = ["#080605", "#0f0c0a", "#18130f", "#211a15", "#2b231c", "#372d24", "#45382d", "#544537"]
FOURRURE_BRUNE = ["#120d09", "#1d150f", "#2a1f16", "#3a2b1f", "#4b3929", "#5e4833", "#72583f", "#86694c", "#9a7b5b"]
FOURRURE_LOUP = ["#0f0e0d", "#1a1817", "#282523", "#373330", "#48433e", "#5b554e", "#706960", "#867e73", "#9d9487", "#b5ac9e", "#cbc3b5"]
CORNE = ["#15110c", "#251e15", "#382e21", "#4e412f", "#665640", "#7f6d53", "#998668", "#b29f80", "#c9b89a"]
FOURRURE_BEIGE = ["#2a231b", "#3b3227", "#4f4436", "#655746", "#7b6b57", "#918069", "#a7957c", "#bba98f", "#cdbca2", "#dccdb5"]
FOURRURE_BRUNE_CLAIRE = ["#1c150e", "#2a2016", "#3a2d1f", "#4c3c2a", "#5f4c36", "#735d43", "#876f52", "#9a8162", "#ab9374"]
