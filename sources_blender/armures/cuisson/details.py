# Cuisson des armures : DÉTAILS SCULPTÉS procéduraux, fonctions de la POSITION 3D (monde, m) — donc continus à travers les coutures
# d'UV, identiques sur la haute déf (déplacement des sommets) et dans l'atlas (relief fin, masques).
#   mid  : relief moyen porté par la GÉOMÉTRIE haute déf (martelage, coups, arête médiane et cannelures du plastron) ;
#   fin  : relief fin cuit seulement dans la texture (entrelacs gravés en creux, piqûres) ;
#   masques : rayures (métal mis à nu), gravure (creux à salir), coups.
# Pas de bruit uniforme : chaque détail a une forme et un emplacement dessinés ; l'aléa ne fait que les répartir.
import math
import numpy as np


# ------------------------------------------------------------------------------------------------------------ bruit 3D
def _hash3(ix, iy, iz, g):
    n = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (int(g) * 2654435761)
    n = n & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def bruit3(p, ech, g):
    f = p / ech
    i = np.floor(f)
    t = f - i
    t = t * t * (3 - 2 * t)
    ix, iy, iz = i[..., 0], i[..., 1], i[..., 2]
    tx, ty, tz = t[..., 0], t[..., 1], t[..., 2]
    def h(a, b, c):
        return _hash3(ix + a, iy + b, iz + c, g)
    x00 = h(0, 0, 0) * (1 - tx) + h(1, 0, 0) * tx
    x10 = h(0, 1, 0) * (1 - tx) + h(1, 1, 0) * tx
    x01 = h(0, 0, 1) * (1 - tx) + h(1, 0, 1) * tx
    x11 = h(0, 1, 1) * (1 - tx) + h(1, 1, 1) * tx
    y0 = x00 * (1 - ty) + x10 * ty
    y1 = x01 * (1 - ty) + x11 * ty
    return y0 * (1 - tz) + y1 * tz


def fbm3(p, g, oct=((0.04, 0.5), (0.015, 0.3), (0.006, 0.2))):
    s = 0.0; w = 0.0
    for k, (e, a) in enumerate(oct):
        s = s + bruit3(p, e, g + 31 * k) * a; w += a
    return s / w


def voronoi3(p, ech, g, jitter=0.85):
    f = p / ech
    i = np.floor(f)
    d1 = np.full(p.shape[:-1], 9.0); d2 = np.full(p.shape[:-1], 9.0)
    for a in (-1, 0, 1):
        for b in (-1, 0, 1):
            for c in (-1, 0, 1):
                cx, cy, cz = i[..., 0] + a, i[..., 1] + b, i[..., 2] + c
                gx = cx + 0.5 + (_hash3(cx, cy, cz, g) - 0.5) * jitter
                gy = cy + 0.5 + (_hash3(cx, cy, cz, g + 1) - 0.5) * jitter
                gz = cz + 0.5 + (_hash3(cx, cy, cz, g + 2) - 0.5) * jitter
                d = np.sqrt((f[..., 0] - gx) ** 2 + (f[..., 1] - gy) ** 2 + (f[..., 2] - gz) ** 2)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    return d1, d2


def lisse(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------------------------------------------ détails
def martelage(p, cell=0.022, prof=0.00018, g=5):
    """Coups de marteau du forgeron : cuvettes de Voronoï (tôle martelée à la main), facettes entre elles."""
    d1, d2 = voronoi3(p, cell, g)
    cuv = np.clip(1 - d1 / 0.62, 0, 1) ** 1.6
    return -prof * cuv


def coups(p, cell=0.11, proba=0.38, g=9):
    """Bosses de combat : enfoncements ronds épars (rayon 1,2-2,6 cm, 0,7-1,8 mm), un au plus par cellule de 11 cm."""
    f = p / cell
    i = np.floor(f)
    h = np.zeros(p.shape[:-1])
    for a in (-1, 0, 1):
        for b in (-1, 0, 1):
            for c in (-1, 0, 1):
                cx, cy, cz = i[..., 0] + a, i[..., 1] + b, i[..., 2] + c
                on = _hash3(cx, cy, cz, g + 3) < proba
                ctr = np.stack([cx + _hash3(cx, cy, cz, g), cy + _hash3(cx, cy, cz, g + 1), cz + _hash3(cx, cy, cz, g + 2)], -1) * cell
                rr = 0.012 + 0.014 * _hash3(cx, cy, cz, g + 4)
                pr = 0.0007 + 0.0011 * _hash3(cx, cy, cz, g + 5)
                d2 = ((p - ctr) ** 2).sum(-1) / (rr * rr)
                # cuvette au bourrelet léger (le métal repoussé autour)
                h = h + np.where(on, -pr * np.exp(-2.2 * d2) + pr * 0.18 * np.exp(-0.9 * (np.sqrt(d2) - 1.15) ** 2 * 6), 0.0)
    return h


def rayures(p, cell=0.075, n_par=2, g=13, larg=0.00055):
    """Rayures de lame (métal mis à nu) : segments droits de 2 à 7 cm, orientation aléatoire ; masque 0..1."""
    f = p / cell
    i = np.floor(f)
    m = np.zeros(p.shape[:-1])
    for a in (-1, 0, 1):
        for b in (-1, 0, 1):
            for c in (-1, 0, 1):
                cx, cy, cz = i[..., 0] + a, i[..., 1] + b, i[..., 2] + c
                for q in range(n_par):
                    gq = g + 17 * q
                    ctr = np.stack([cx + _hash3(cx, cy, cz, gq), cy + _hash3(cx, cy, cz, gq + 1), cz + _hash3(cx, cy, cz, gq + 2)], -1) * cell
                    th = _hash3(cx, cy, cz, gq + 3) * math.tau
                    ph = (_hash3(cx, cy, cz, gq + 4) - 0.5) * 2.4
                    dvec = np.stack([np.cos(th) * np.cos(ph), np.sin(th) * np.cos(ph), np.sin(ph)], -1)
                    L = 0.01 + 0.025 * _hash3(cx, cy, cz, gq + 5)
                    v = p - ctr
                    s = np.clip((v * dvec).sum(-1), -L, L)
                    d = np.linalg.norm(v - dvec * s[..., None], axis=-1)
                    k = 0.55 + 0.45 * _hash3(cx, cy, cz, gq + 6)
                    m = np.maximum(m, k * np.exp(-(d / larg) ** 2))
    return m


def entrelacs(s, t, hw, lam=0.05, larg_brin=0.24, trait=0.11):
    """Tresse nordique à deux brins (entrelacs gravé) dans une bande : s le long (m), t en travers (m), hw = demi-largeur (m).
    Retourne (sillon 0..1 : traits gravés en creux, brin 0..1 : intérieur des brins, un peu plus haut que le fond)."""
    u = t / hw
    ph = math.tau * s / lam
    amp = 0.58
    y1 = amp * np.sin(ph)
    pente = amp * math.tau / lam * hw * np.cos(ph)
    nrm = np.sqrt(1 + pente * pente)
    d1 = np.abs(u - y1) / nrm
    d2 = np.abs(u + y1) / nrm
    g1 = np.exp(-((d1 - larg_brin) / trait) ** 2)
    g2 = np.exp(-((d2 - larg_brin) / trait) ** 2)
    in1 = d1 < larg_brin + trait * 0.6
    in2 = d2 < larg_brin + trait * 0.6
    dessus1 = (np.floor(2 * s / lam + 0.5) % 2) == 0          # alternance dessus / dessous à chaque croisement
    sillon = np.where(dessus1, np.maximum(g1, g2 * ~in1), np.maximum(g2, g1 * ~in2))
    bord = np.exp(-((np.abs(u) - 0.93) / trait) ** 2)
    sillon = np.maximum(sillon, bord) * (np.abs(u) < 1.05)
    brin = (np.minimum(d1, d2) < larg_brin).astype(np.float64) * (np.abs(u) < 0.9)
    return sillon, brin


# ------------------------------------------------------------------------------------------------------------ par pièce
def _bande_cylindre(p, ctr_xy, z_c, hw, rayon):
    """Coordonnées (s, t) d'une bande horizontale autour d'un axe vertical (casque, gorgerin)."""
    az = np.arctan2(p[..., 0] - ctr_xy[0], -(p[..., 1] - ctr_xy[1]))
    return az * rayon, p[..., 2] - z_c


def relief_mid(pid, p, acier):
    """Relief moyen (m) porté par la haute déf ; acier : masque des sommets d'acier."""
    h = martelage(p) + coups(p)
    if "cuirasse" in pid:
        x, y, z = p[..., 0], p[..., 1], p[..., 2]
        # plastron : arête médiane vive et trois cannelures de chaque côté, en éventail vers le bas
        av = lisse(-0.02, -0.07, y)
        fz = lisse(1.205, 1.245, z) * (1 - lisse(1.395, 1.43, z))
        ax = np.abs(x)
        arete = 0.0032 * (1 - lisse(0.0, 0.022, ax)) ** 1.4
        can = np.zeros_like(x)
        for k in (1, 2, 3):
            xk = 0.040 * k * (1 + 0.30 * np.clip((1.42 - z) / 0.2, 0, 1))
            can = can - 0.0014 * (1 - 0.22 * (k - 1)) * np.exp(-((ax - xk) / 0.0058) ** 2)
        h = h + (arete + can) * av * fz * (ax < 0.17)
    return np.where(acier, h, 0.0)


def relief_fin(pid, p, acier, cuir):
    """Relief fin (m) cuit dans la texture + masque de gravure (creux à salir)."""
    h = np.zeros(p.shape[:-1]); grav = np.zeros(p.shape[:-1])
    # piqûres fines de la tôle
    h = h + (bruit3(p, 0.004, 71) - 0.5) * 0.000015
    bandes = []
    if "casque" in pid:
        bandes.append(((0.0, 0.015), 1.712, 0.011, 0.105, 0.0))        # bandeau du casque au-dessus du bord (entrelacs)
    if "cuirasse" in pid:
        bandes.append(((0.0, 0.012), 1.476, 0.0105, 0.150, 0.035))     # lame basse du gorgerin
    for ctr, zc, hw, rayon, dip in bandes:
        az = np.arctan2(p[..., 0] - ctr[0], -(p[..., 1] - ctr[1]))
        w = np.maximum(0.0, np.cos(az)) ** 1.5
        s, t = az * rayon, p[..., 2] - (zc - dip * w)
        sil, brin = entrelacs(s, t, hw)
        dans = np.abs(t) < hw * 1.1
        h = h + np.where(dans, -0.00035 * sil + 0.00008 * brin, 0.0)
        grav = np.maximum(grav, np.where(dans, sil, 0.0))
    # cuir : grain
    hc = (bruit3(p, 0.0018, 81) - 0.5) * 0.00012 + (bruit3(p, 0.008, 82) - 0.5) * 0.00015
    return np.where(acier, h, np.where(cuir, hc, 0.0)), np.where(acier, grav, 0.0)
