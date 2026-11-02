# Peintres HD des ensembles OBSIDIENNE et OR (planche planche_armures_5.png, colonnes OBSIDIAN et GOLD) : fonctions numpy
# D -> RGBA (alpha = brillance, lue par shader_matiere). Positions en repère GODOT (x, y haut, z devant), en mètres.
# Palettes reprises des armes validées (scripts/objets/epees_longues.gd : OBSIDIENNE et VEINE de Crocs-de-Cendre, OR_PATINE de
# Dent-d'Or, RUBIS de Cœur-de-Braise).
import math
import numpy as np
import hd
from hd import bruit, fbm, voronoi, rampe, hexa, lisse

TAU = math.tau

OBSIDIENNE = hexa("#030305", "#07060a", "#0d0c11", "#151419", "#1e1c23", "#28262e", "#34313b", "#433f4b", "#57525f", "#726c7a", "#96909e")
VEINE = hexa("#2a0402", "#4e0904", "#7a1406", "#a8240a", "#d44412", "#f2782a", "#ffb35a", "#ffe0a0")
FER_NOIR = hexa("#060607", "#0b0b0d", "#111214", "#18191c", "#202226", "#2a2c31", "#36393f", "#454950", "#5a5f66", "#767b82")
CUIR_NOIR = hexa("#070504", "#0d0907", "#140e0a", "#1c140e", "#251a12", "#2f2217", "#3a2a1d", "#463324")
OXYDE = hexa("#1e1008", "#2e180c", "#442412", "#5a311a")
OR_PATINE = hexa("#120d07", "#1f170c", "#302312", "#45331a", "#5c4522", "#765a2c", "#907038", "#a98846", "#bf9f58", "#d3b673", "#e3cb93", "#efdfb8")
BLEU_NUIT = hexa("#03040b", "#060814", "#0a0e20", "#0f152d", "#151d3c", "#1c264b", "#25315b", "#2f3d6c")
ROUGE_SOMBRE = hexa("#0d0303", "#1a0505", "#280808", "#380c0b", "#48110f", "#591814", "#6b201a", "#7c2a22")
BEIGE = hexa("#5a4a38", "#76624a", "#94805f", "#b09c79")
RUBIS = hexa("#140103", "#2a0306", "#44050a", "#640a10", "#881218", "#b01e26", "#e05458", "#ffb0a8")
RUNE_OR = hexa("#5c4522", "#a98846", "#e3cb93", "#fff2c8")


def _rgba(c, b):
    return np.concatenate([c, np.broadcast_to(np.asarray(b, dtype=float), (len(c),)).reshape(-1, 1)], 1)


def ang_corps(P):
    return np.arctan2(P[:, 0], P[:, 2])


# ============================================================================================================== commun
def cuir(D, pal=CUIR_NOIR, base=0.45, g=0):
    P, bord = D["P"], D["bord"]
    n = fbm(P, 90.0, g)
    pores = bruit(P, 900.0, g + 3)
    use = fbm(P, 30.0, g + 5)
    t = base + (n - 0.5) * 0.35 - 0.08 * (pores > 0.78) + np.clip(use - 0.62, 0, 1) * 0.6
    b = 0.12 + 0.2 * n * (use < 0.62)
    s = np.mod((P[:, 0] * 0.8 + P[:, 1] + P[:, 2] * 0.6) / 0.0055, 1.0)
    pt = (bord > 0.0035) & (bord < 0.0058) & (s < 0.55)
    t = np.where(pt, t + 0.22, t)
    t = np.where(bord < 0.0018, t + 0.1, t)
    return _rgba(rampe(pal, t), b)


def maille(D, pal, base=0.42, g=0):
    """Mailles rivetées (anneaux de 9 mm) en rangs ; autour des bras en croix (pose en T)."""
    P = D["P"]
    bras = (np.abs(P[:, 0]) > 0.30) & (P[:, 1] > 1.2)
    rang = np.where(bras, np.abs(P[:, 0]), P[:, 1]) / 0.009
    autour = np.where(bras, np.arctan2(P[:, 1] - 1.45, P[:, 2]) * 0.05, ang_corps(P) * 0.17) / 0.009
    r = np.floor(rang)
    u = np.mod(autour + 0.5 * np.mod(r, 2), 1.0)
    w = np.mod(rang, 1.0)
    d = np.hypot(u - 0.5, (w - 0.5) * 1.15)
    anneau = np.abs(d - 0.32) < 0.15
    n = fbm(P, 40.0, g)
    t = base + (n - 0.5) * 0.2
    t = np.where(anneau, t + 0.18 * (1.0 - w) - 0.02, t - 0.24)
    b = np.where(anneau, 0.5 + 0.3 * (1.0 - w), 0.05)
    return _rgba(rampe(pal, t), b)


def rivets(D, t, b, cellule=0.032, bord_min=0.006, bord_max=0.013, rayon=0.0032, g=0):
    P, bord = D["P"], D["bord"]
    f1, f2, cid, d1 = voronoi(P, cellule, g)
    pres = (bord > bord_min) & (bord < bord_max)
    tete = pres & (f1 < rayon)
    k = np.clip(f1 / rayon, 0, 1)
    t = np.where(tete, 0.62 + 0.25 * (d1[:, 1] / rayon) - 0.25 * k ** 2, t)
    b = np.where(tete, 1.0, b)
    ombre = pres & (f1 >= rayon) & (f1 < rayon * 1.7) & (d1[:, 1] < 0)
    t = np.where(ombre, t - 0.12, t)
    return t, b


def fer_noir(D, base=0.34, g=11, rivet=True):
    """Fer noirci (sous-structure, doigts, bottes) : martelé, bords polis, rivets, oxyde chaud dans les creux."""
    P, bord, ao = D["P"], D["bord"], D["ao"]
    n = fbm(P, 60.0, g)
    f1, f2, cid, d1 = voronoi(P, 0.012, g + 5)
    t = base + (n - 0.5) * 0.22 + (cid - 0.5) * 0.06 + 0.05 * (1 - f1 / 0.008).clip(0, 1) - 0.05 * ((f2 - f1) < 0.0012)
    raye = bruit(P, np.array([300.0, 40.0, 300.0]), g + 9) > 0.86
    t = np.where(raye, t + 0.08, t)
    b = 0.4 + 0.3 * n
    t = np.where(bord < 0.003, t + 0.18, t)
    b = np.where(bord < 0.003, 1.0, b)
    if rivet:
        t, b = rivets(D, t, b, g=g + 17)
    c = rampe(FER_NOIR, t)
    ox = np.clip((0.55 - ao) * 2.2, 0, 1) * (fbm(P, 50.0, g + 21) > 0.45)
    c = c * (1 - 0.5 * ox[:, None]) + rampe(OXYDE, n) * (0.5 * ox[:, None])
    return _rgba(c, b * (1 - 0.6 * ox))


def runes(P, pas=0.026, h=0.032, g=71):
    """Frise de runes nordiques gravées (traits ~2,5 mm), rangées horizontales tous les 9 cm, sur toutes les faces."""
    ang = ang_corps(P)
    bras = (np.abs(P[:, 0]) > 0.3) & (P[:, 1] > 1.2)
    s = np.where(bras, np.abs(P[:, 0]), ang * 0.18)
    y = np.where(bras, np.arctan2(P[:, 1] - 1.45, P[:, 2]) * 0.06 + 1.0, P[:, 1])
    i = np.floor(s / pas)
    j = np.floor(y / 0.09)
    u = np.mod(s / pas, 1.0)
    v = np.mod(y / 0.09, 1.0)
    vb = h / 0.09
    dans = (v > 0.5 - vb / 2) & (v < 0.5 + vb / 2)
    vv = (v - (0.5 - vb / 2)) / vb
    m = (hd._hash(i.astype(np.int64), j.astype(np.int64), 1, g) * 6).astype(int)
    w = 0.11
    trait = np.abs(u - 0.3) < w
    diag1 = np.abs((u - 0.3) - vv * 0.45) < w * 0.9
    diag2 = np.abs((u - 0.3) - (1 - vv) * 0.45) < w * 0.9
    barre = (np.abs(vv - 0.5) < 0.1) & (u > 0.3) & (u < 0.75)
    r = trait | ((m == 0) & diag1) | ((m == 1) & diag2) | ((m == 2) & barre) | ((m == 3) & diag1 & (vv > 0.5)) | ((m == 4) & (diag1 | diag2) & (vv < 0.5))
    return dans & r & (hd._hash(i.astype(np.int64), j.astype(np.int64), 2, g + 1) > 0.25)


# ============================================================================================================== OBSIDIENNE
# Foyers de magma (repère Godot) : les fissures incandescentes restent LOCALISÉES (planche : poitrine, une épaule, un avant-bras,
# un flanc, les tibias), le reste est de la pierre de verre noire.
FOYERS = {
    "cuirasse": [((0.0, 1.36, 0.16), 0.13), ((0.22, 1.50, 0.02), 0.10), ((-0.26, 1.52, -0.02), 0.07), ((-0.09, 1.13, 0.15), 0.09),
                 ((0.13, 0.86, 0.13), 0.08), ((-0.02, 1.30, -0.19), 0.10)],
    "gantelets": [((0.50, 1.50, 0.0), 0.075), ((-0.52, 1.50, 0.0), 0.06)],
    "bottes": [((0.11, 0.26, 0.09), 0.10), ((-0.11, 0.18, 0.09), 0.08)],
    "casque": [((0.07, 1.74, 0.06), 0.05)],
}


def obsidienne(D, g=31, enchante=False):
    """Pierre de verre volcanique noire taillée : facettes anguleuses (Voronoï 3D, ton propre par facette), arêtes d'éclat
    gris clair, ondes conchoïdales, fil taillé des bords ; fissures de magma orange seulement dans les foyers ; visière : fente
    incandescente. Enchantée : runes taillées qui rougeoient sur toutes les plaques."""
    P, N, bord, ao = D["P"], D["N"], D["bord"], D["ao"]
    piece = D.get("piece", "")
    f1, f2, cid, d1 = voronoi(P, 0.026, g)
    arete = f2 - f1
    inclin = hd._hash((cid * 9973).astype(np.int64), 3, 5, g) - 0.5
    t = 0.36 + (cid - 0.5) * 0.16 + inclin * 0.14
    onde = np.sin(f1 / 0.0038 * TAU + cid * 20.0)
    t += 0.03 * onde * (f1 < 0.018)
    t += (fbm(P, 240.0, g + 2) - 0.5) * 0.07
    b = 0.62 + 0.25 * (inclin + 0.5)
    crete = arete < 0.0017
    t = np.where(crete, 0.66 + 0.12 * cid, t)
    b = np.where(crete, 1.0, b)
    t = np.where((arete >= 0.0017) & (arete < 0.0032), t - 0.08, t)
    t = np.where(bord < 0.0028, t + 0.26, t)                   # fil taillé des bords : gris clair (planche)
    b = np.where(bord < 0.0028, 1.0, b)
    c = rampe(OBSIDIENNE, t)
    # magma localisé
    w = np.zeros(len(P))
    for (cx, cy, cz), rr in FOYERS.get(piece, []):
        dd = np.sqrt((P[:, 0] - cx) ** 2 + (P[:, 1] - cy) ** 2 + (P[:, 2] - cz) ** 2)
        w = np.maximum(w, np.clip(1.0 - dd / rr, 0, 1) ** 1.2)
    F1, F2, CID, _ = voronoi(P, 0.045, g + 9)
    ar2 = F2 - F1
    fiss = (ar2 < 0.0012 + 0.0022 * w) & (w > 0.04)
    fiss |= (arete < 0.0009 + 0.0012 * w) & (w > 0.35)
    k = np.where(fiss, 0.45 + 0.55 * w, 0.0)
    chaleur = np.clip((0.0045 + 0.004 * w - ar2) / 0.004, 0, 1) * w * 0.35
    k = np.maximum(k, chaleur * (~fiss))
    if piece == "casque":
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        devant = (z > 0.07) & (y < 1.69)
        fente_h = devant & (np.abs(y - 1.637) < 0.0085) & (np.abs(x) < 0.058)
        fente_v = devant & (np.abs(x) < 0.0055) & (y > 1.565) & (y < 1.64)
        fente = fente_h | fente_v
        halo = devant & (np.abs(y - 1.637) < 0.016) & (np.abs(x) < 0.066) & ~fente
        k = np.where(fente, 1.0, np.maximum(k, halo * 0.35))
    if enchante:
        k = np.maximum(k, runes(P) * 0.85 * (bord > 0.006))
    m = k > 0.03
    cv = rampe(VEINE, 0.15 + 0.85 * k)
    c = np.where(m[:, None], c * (1 - k[:, None]) + cv * k[:, None], c)
    b = np.where(m, b * (1 - k), b)
    return _rgba(c, b)


def tissu_rouge(D, g=91):
    """Pan de laine rouge sombre usé, déchiré : trame, accrocs sombres, bas effiloché, rune délavée beige (planche)."""
    P, bord = D["P"], D["bord"]
    n = fbm(P, 45.0, g)
    trame = bruit(P, np.array([700.0, 120.0, 700.0]), g + 1) * 0.5 + bruit(P, np.array([120.0, 700.0, 120.0]), g + 2) * 0.5
    t = 0.48 + (n - 0.5) * 0.25 + (trame - 0.5) * 0.12
    t = np.where(fbm(P, 25.0, g + 4) > 0.68, t - 0.22, t)            # accrocs, taches
    t = np.where((bord < 0.012) & (P[:, 1] < 0.8), t - 0.15 * (1 - bord / 0.012), t)
    c = rampe(ROUGE_SOMBRE, t)
    x, y = P[:, 0], P[:, 1]
    yr = y - 0.80
    tige = (np.abs(x) < 0.0035) & (yr > -0.07) & (yr < 0.06)
    bras = (np.abs(np.abs(x) - (yr - 0.0) * 0.55) < 0.0035) & (yr > 0.0) & (yr < 0.055)
    pied = (np.abs(np.abs(x) - (-yr - 0.03) * 0.55) < 0.0035) & (yr < -0.03) & (yr > -0.07)
    rune = (tige | bras | pied) & (P[:, 2] > 0)
    delave = 0.55 + 0.25 * fbm(P, 80.0, g + 6)
    c = np.where(rune[:, None], c * (1 - delave[:, None]) + rampe(BEIGE, n)[:, :] * delave[:, None], c)
    return _rgba(c, 0.06)


def peindre_obsidienne(D, enchante=False):
    return _par_matiere(D, {
        "obsidienne": lambda d: obsidienne(d, enchante=enchante),
        "fer": lambda d: fer_noir(d),
        "chaine": lambda d: fer_noir(d, base=0.46, rivet=False),
        "maille": lambda d: maille(d, FER_NOIR, 0.40, 41),
        "cuir": lambda d: cuir(d, CUIR_NOIR, 0.42, 51),
        "tissu": lambda d: tissu_rouge(d),
    }, lumineux=True)


# ============================================================================================================== OR
def entrelacs(s, t, h, larg=0.0026, lam=None):
    """Entrelacs dans une bande (s le long, t en travers, 0..h) : deux rubans qui passent l'un sur l'autre à chaque croisement."""
    lam = lam or h * 1.6
    ph = s / lam * TAU
    a = h * 0.5 - larg * 1.6
    y1 = h * 0.5 + a * np.sin(ph)
    y2 = h * 0.5 - a * np.sin(ph)
    d1 = np.abs(t - y1); d2 = np.abs(t - y2)
    dessus1 = np.mod(np.floor(ph / math.pi + 0.5), 2) == 0
    r1 = d1 < larg; r2 = d2 < larg
    lis1 = (d1 >= larg) & (d1 < larg * 1.6); lis2 = (d2 >= larg) & (d2 < larg * 1.6)
    r1v = r1 & (dessus1 | ~(r2 | lis2))
    r2v = r2 & (~dessus1 | ~(r1 | lis1))
    ruban = r1v | r2v
    lisere = (lis1 | lis2 | (r1 & ~r1v) | (r2 & ~r2v)) & ~ruban
    filet = (t < larg * 0.9) | (t > h - larg * 0.9)
    return ruban, lisere, filet


def _bandes_or(D):
    """Bandes d'entrelacs gravés : (masque, s le long, t en travers, h)."""
    P, uv = D["P"], D["uv"]
    piece = D.get("piece", "")
    n = len(P)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    zone = np.zeros(n, dtype=bool); s = np.zeros(n); t = np.zeros(n); h = np.full(n, 0.03)
    if piece == "cuirasse":
        ang = ang_corps(P)
        bh = (y > 1.385) & (y < 1.417) & (np.abs(ang) < 1.15) & (z > 0)
        bv = (np.abs(x) < 0.017) & (z > 0.08) & (y > 1.16) & (y < 1.385)
        zone = bh | bv
        s = np.where(bh, ang * 0.17, y)
        t = np.where(bh, y - 1.385, x + 0.017)
        h = np.where(bh, 0.032, 0.034)
    elif piece == "gantelets":
        man = uv[:, 1] < 48 / 128
        bm = man & (np.abs(uv[:, 1] - 22 / 128) < 7 / 128)
        zone = bm
        s = uv[:, 0] * 0.24
        t = (uv[:, 1] - 15 / 128) * (0.03 / (14 / 128))
    elif piece == "bottes":
        gr = (uv[:, 1] >= 64 / 128) & (uv[:, 0] < 64 / 128)
        bg = gr & (np.abs(uv[:, 0] - 32 / 128) < 9 / 128)
        zone = bg
        s = y
        t = (uv[:, 0] - 23 / 128) * (0.03 / (18 / 128))
    elif piece == "casque":
        co = uv[:, 1] < 80 / 128
        bc = co & (uv[:, 1] > 4 / 128) & (uv[:, 1] < 17 / 128) & (D["mat"] == "or.patine")
        zone = bc
        s = uv[:, 0] * 0.66
        t = (uv[:, 1] - 4 / 128) * (0.03 / (13 / 128))
    return zone, s, t, h


def or_patine(D, g=61, lion=False):
    """Or patiné (planche GOLD, pas de plastique) : or pâle brossé, creux sombres (occlusion), bord repoussé clair et filet gravé
    sombre le long de chaque bord, poinçons épars, bandes d'entrelacs gravés (haut du plastron, bande centrale, manchettes,
    grèves, front du heaume) ; visière du heaume : fente en T noire. Lion : mèches de crinière gravées."""
    P, N, bord, ao, uv = D["P"], D["N"], D["bord"], D["ao"], D["uv"]
    piece = D.get("piece", "")
    n = fbm(P, 70.0, g)
    brosse = bruit(P, np.array([30.0, 500.0, 30.0]), g + 3)
    t = 0.66 + (n - 0.5) * 0.14 + (brosse - 0.5) * 0.06
    b = 0.55 + 0.2 * brosse
    tern = np.clip((0.72 - ao) * 1.6, 0, 1)
    t = t - 0.42 * tern
    b = b * (1 - 0.7 * tern)
    # bord repoussé : bourrelet clair puis filet gravé
    t = np.where(bord < 0.0035, t + 0.12 * (1 - bord / 0.0035), t)
    bande = (bord >= 0.0035) & (bord < 0.012)
    t = np.where(bande, t - 0.05, t)
    gr = (bord >= 0.012) & (bord < 0.0142)
    t = np.where(gr, t - 0.34, t)
    b = np.where(gr, 0.2, b)
    # poinçons épars (planche : petits motifs sombres sur les plaques)
    f1, f2, cid, d1 = voronoi(P, 0.022, g + 7)
    poincon = (f1 < 0.0016) & (bord > 0.016) & (cid > 0.35)
    t = np.where(poincon, t - 0.3, t)
    if not lion:
        zone, s, tt, h = _bandes_or(D)
        rub, lise, fil = entrelacs(s, tt, h)
        z = zone & (bord > 0.006)
        t = np.where(z & rub, t + 0.08, np.where(z & (lise | fil), t - 0.36, np.where(z, t - 0.12, t)))
        b = np.where(z & (lise | fil), 0.15, b)
    else:
        meche = bruit(P, 260.0, g + 9) > 0.62
        t = np.where(meche & (ao < 0.92), t - 0.18, t)
    if piece == "casque":
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        devant = (z > 0.07) & (y < 1.69)
        fente = devant & (((np.abs(y - 1.637) < 0.0085) & (np.abs(x) < 0.056)) | ((np.abs(x) < 0.0075) & (y > 1.565) & (y < 1.64)))
        t = np.where(fente, 0.02, t)
        b = np.where(fente, 0.0, b)
        bordf = devant & ~fente & (((np.abs(y - 1.637) < 0.012) & (np.abs(x) < 0.06)) | ((np.abs(x) < 0.011) & (y > 1.56) & (y < 1.645)))
        t = np.where(bordf, t + 0.1, t)
    return _rgba(rampe(OR_PATINE, t), b)


def noeud(u, v):
    """Nœud nordique (planche : broderie du tabard) dans [-1, 1]² : losange, quatre boucles, croix centrale entrelacés."""
    l = 0.1
    los = np.abs(np.abs(u) + np.abs(v) - 0.62) < l
    boucles = np.zeros(u.shape, bool)
    for (cu, cv) in ((0.55, 0.0), (-0.55, 0.0), (0.0, 0.55), (0.0, -0.55)):
        boucles |= np.abs(np.hypot(u - cu, v - cv) - 0.3) < l
    croix = ((np.abs(u) < l * 0.9) & (np.abs(v) < 0.34)) | ((np.abs(v) < l * 0.9) & (np.abs(u) < 0.34))
    m = los | boucles | croix
    dans = (np.abs(u) <= 1) & (np.abs(v) <= 1)
    return m & dans


def tissu_bleu(D, g=81, enchante=False):
    """Laine bleu nuit : trame fine ; manches et col en gambison piqué ; tabard : nœud nordique brodé d'or, filets d'or le long des
    bords, frange d'or en bas. Enchanté : frise de runes brodées d'or pâle (luisantes)."""
    P, bord = D["P"], D["bord"]
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = fbm(P, 40.0, g)
    trame = bruit(P, np.array([800.0, 150.0, 800.0]), g + 1) * 0.5 + bruit(P, np.array([150.0, 800.0, 150.0]), g + 2) * 0.5
    t = 0.5 + (n - 0.5) * 0.2 + (trame - 0.5) * 0.1
    tabard = (y < 0.985) & (np.abs(x) < 0.06)
    piq = ~tabard & (np.abs(np.mod(y / 0.022, 1.0) - 0.5) < 0.06)
    t = np.where(piq, t - 0.14, t)
    c = rampe(BLEU_NUIT, t)
    b = np.full(len(P), 0.12)
    fil = rampe(OR_PATINE, 0.66 + 0.12 * bruit(P, 900.0, g + 5))
    # filets d'or le long des bords du tabard, frange en bas
    filets = tabard & (((bord > 0.005) & (bord < 0.0075)) | ((bord > 0.0105) & (bord < 0.012)))
    frange = tabard & (bord < 0.016) & (np.mod(x / 0.0042, 1.0) < 0.55) & (y < 0.60)
    # nœud au milieu du tabard (devant et dos)
    yc = 0.70
    u = x / 0.034
    v = (y - yc) / 0.075
    knot = tabard & noeud(u, v)
    brode = filets | frange | knot
    if enchante:
        rn = runes(P, pas=0.02, h=0.022) & ~tabard
        rt = tabard & (np.abs(y - 0.88) < 0.012) & (np.abs(np.mod(x / 0.012, 1.0) - 0.5) < 0.18)
        brode |= rn | rt
        fil = np.where((rn | rt)[:, None], rampe(RUNE_OR, np.full(len(P), 0.8)), fil)
    c = np.where(brode[:, None], fil, c)
    b = np.where(brode, 0.5, b)
    return _rgba(c, b)


def gemme(D):
    P, N = D["P"], D["N"]
    l = np.clip(N @ np.array([-0.4, 0.7, 0.55]), 0, 1)
    f = np.floor((np.arctan2(N[:, 0], N[:, 2]) + math.pi) / (TAU / 8))
    t = 0.35 + 0.45 * l + 0.08 * (np.mod(f, 2) - 0.5)
    return _rgba(rampe(RUBIS, t), 1.0)


def peindre_or(D, enchante=False):
    return _par_matiere(D, {
        "or": lambda d: or_patine(d),
        "lion": lambda d: or_patine(d, lion=True),
        "tissu": lambda d: tissu_bleu(d, enchante=enchante),
        "maille": lambda d: tissu_bleu(d, enchante=enchante),
        "cuir": lambda d: cuir(d, CUIR_NOIR, 0.48, 93),
        "gemme": gemme,
    })


# ============================================================================================================== répartition
def _famille_mat(nom):
    if nom == "or.lion":
        return "lion"
    if "maille" in nom:
        return "maille"
    if "chaine" in nom:
        return "chaine"
    return nom.split(".")[0]


def _par_matiere(D, fns, lumineux=False):
    n = len(D["P"])
    out = np.zeros((n, 4))
    fam = np.array([_famille_mat(m) for m in D["mat"]])
    for f in np.unique(fam):
        m = fam == f
        sous = {k: (v[m] if isinstance(v, np.ndarray) and len(v) == n else v) for k, v in D.items()}
        fn = fns.get(f) or fns.get("fer") or fns.get("or")
        out[m] = fn(sous)
    ao = D["ao"]
    k = 0.55 + 0.45 * ao ** 1.3
    if lumineux:
        chaud = (out[:, 0] - out[:, 2]) > 0.25
        k = np.where(chaud, 1.0, k)
    out[:, :3] *= k[:, None]
    out[:, 3] *= 0.45 + 0.55 * ao
    return out
