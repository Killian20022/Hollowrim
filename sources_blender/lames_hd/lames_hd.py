# LAMES HD (branche armes/lames_hd, demande du 2026-11-12 : « les épées [...] de Quaternius, est-ce que tu peux les retravailler en
# augmentant leur détail et leurs triangles, que ça fasse encore moins jouet et vraie épée, comme la claymore qui est magnifique »).
# Remplace les quatre lames Quaternius CC0 du catalogue (assets/modeles/armes/cc0_essai/0[1-4]_*.glb, gardés) par des armes
# modelées ici, au niveau de la claymore v4 (sources_blender/epees_hybrides/claymore_v4.py) :
#   epee_soldat   : épée nordique sobre (type viking tardif) : lame droite à large gouttière, croisée droite à pans, fusée de
#                   cuir enroulé à bagues, garde haute + pommeau « noix » à pans, deux petites ébréchures ;
#   sabre_pillard : fauchon / messer des bandits : un seul tranchant au ventre élargi, dos courbe et pointe coupée, gouttière
#                   le long du dos, tranchant ÉBRÉCHÉ, croisée en S avec clou (nagel), fusée de cuir lacée, pommeau-crochet ;
#   epee_doree    : épée d'apparat d'officier : lame plaquée d'or gravée (lame_or) à profil de feuille, quillons à VOLUTES,
#                   écusson serti, fusée filetée d'or, pommeau en poire à pans sertie, bouton de rivure ;
#   dague_acier   : dague droite à deux tranchants, arête médiane et courte gouttière, quillons recourbés à boules, fusée de
#                   cuir à bagues, pommeau à pans.
#   blender.exe -b --python sources_blender/lames_hd/lames_hd.py -- [epee_soldat sabre_pillard epee_doree dague_acier]
# Sortie : assets/modeles/armes/lames_hd/<id>.glb (+ lames_hd.blend ici). Les .tscn de assets/modeles/armes/integrees/ y pointent.
# Repère commun (epees_longues.py) : lame +Z Blender (+Y glTF), X = tranchant / quillons, Y = épaisseur ; centre du poing à
# z = 0,03 (« prise ») ; « garde » et « pointe » aux MÊMES hauteurs que les anciens .tscn (tracé de lame et tenue inchangés).
# Matériaux (EpeesLongues) : lame (acier : UV u en travers RELATIF à la largeur locale, v du talon à la pointe : la gouttière et le
# fil de la texture suivent la géométrie), lame_or, fer, or, cuir, gemme.
import bpy, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
_lib = os.path.join(os.path.dirname(ICI), "epees_longues", "epees_longues.py")
exec(open(_lib, encoding="utf-8").read().split("# ================================================================== variantes")[0])
ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "lames_hd")
TAU = 2 * math.pi


def _n(v):
    l = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / l for c in v)


def _x(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _d(a, b):
    return sum(x * y for x, y in zip(a, b))


def lisser(t):
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ outils de forme (comme claymore_v4.py)
def tube(m, pts, rayons, mat, cotes=8, bouts=True, normale=(0.0, 1.0, 0.0), uv_l=2.0, rot=0.0):
    """Tube le long d'un chemin : section elliptique (ra le long de `normale` projetée, rb sur la binormale)."""
    anneaux = []
    longs = [0.0]
    for i in range(1, len(pts)):
        longs.append(longs[-1] + math.dist(pts[i], pts[i - 1]))
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = _n(tuple(b[k] - a[k] for k in range(3)))
        nn = _n(tuple(normale[k] - t[k] * _d(normale, t) for k in range(3)))
        bb = _x(t, nn)
        ra, rb = rayons[i]
        anneaux.append([tuple(p[k] + nn[k] * ra * math.cos(rot + TAU * j / cotes) + bb[k] * rb * math.sin(rot + TAU * j / cotes)
                              for k in range(3)) for j in range(cotes)])
    L = longs[-1] or 1.0

    def uv(p, k, i, mat_=None):
        return (longs[min(k, len(longs) - 1)] / L * uv_l, i / cotes)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    if bouts:
        capuchon(m, ids[0], anneaux[0], mat, uv)
        m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return anneaux


def revol(m, profil, mat, cotes=8, rx=1.0, ry=1.0, rot=0.0, mod=None, fond=True, haut=True, cx=0.0, uv_tours=1.0):
    """Volume de révolution autour de Z : profil (z, r) du bas vers le haut, section (rx, ry) ; mod(k, j) multiplie le rayon
    (lobes, pans). fond / haut : ferme par un éventail plat."""
    anneaux = []
    for k, (z, r) in enumerate(profil):
        a = []
        for j in range(cotes):
            f = rot + TAU * j / cotes
            rr = r * (mod(k, j) if mod else 1.0)
            a.append((cx + rr * rx * math.cos(f), rr * ry * math.sin(f), z))
        anneaux.append(a)
    z0, z1 = profil[0][0], profil[-1][0]

    def uv(p, k, i, mat_=None):
        return (i / cotes * uv_tours, (p[2] - z0) / max(1e-6, z1 - z0))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    if fond:
        capuchon(m, ids[0], anneaux[0], mat, uv)
    if haut:
        m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return ids, anneaux


def fusee_enroulee(m, zb, zh, r, mat="cuir", cotes=16, n=28, tours=5.0, relief=0.10, ecrase=0.86, renfle=0.06, bandes=1):
    """Fusée de cuir ENROULÉ en volume : lanière(s) en hélice qui se CHEVAUCHENT (profil en dents de scie : chaque tour remonte
    puis retombe d'un coup sur le suivant), léger renflement au milieu de la fusée."""
    L = zh - zb
    anneaux = []
    for k in range(n + 1):
        u = k / n
        z = zb + L * u
        base = r * (1.0 + renfle * math.sin(math.pi * u))
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            ph = (bandes * (f / TAU - tours * u)) % 1.0
            dent = ph / 0.86 if ph < 0.86 else (1.0 - ph) / 0.14     # monte lentement, retombe vite (bord de la lanière)
            rr = base * (1.0 + relief * (dent - 0.5))
            a.append((rr * math.cos(f), rr * ecrase * math.sin(f), z))
        anneaux.append(a)

    def uv(p, k, i, mat_=None):
        return (i / cotes * 2.0, k / n * 2.0)
    relier(m, anneaux, lambda k, i: mat, uv)


def helice(m, zb, zh, r, tours, mat, ep=0.0015, ecrase=0.86, renfle=0.06, seg=9, cotes=3):
    """Fil (ou lacet) en hélice autour de la fusée."""
    L = zh - zb
    pts, rays = [], []
    ns = int(abs(tours) * seg)
    for k in range(ns + 1):
        u = k / ns
        z = zb + L * u
        a = TAU * tours * u
        rr = r * (1.0 + renfle * math.sin(math.pi * u)) + ep * 0.8
        pts.append((rr * math.cos(a), rr * ecrase * math.sin(a), z))
        rays.append((ep, ep))
    tube(m, pts, rays, mat, cotes=cotes, bouts=False, normale=(0.0, 0.0, 1.0), uv_l=12.0)


def bague(m, z0, z1, r, mat="fer", cotes=12, ecrase=0.86, bourrelet=0.15):
    """Virole / bague à bourrelet."""
    revol(m, [(z0, r), (z0 + 0.0025, r * (1 + bourrelet)), (z1 - 0.0025, r * (1 + bourrelet)), (z1, r * 1.02)], mat, cotes=cotes,
          ry=ecrase, fond=False, haut=False)


# ------------------------------------------------------------------ lames
def section_double(w, t, g, z, fl=0.40, fond=0.26):
    """Lame à deux tranchants (claymore v4) : fil, biseau secondaire, méplat, gouttière à flancs nets (g = 0 : arête plate)."""
    d = t * (1.0 - 0.50 * g)          # g -> 0 : le fond remonte au méplat, la gouttière s'efface sans saut
    gw = fond * w
    haut = [(w, 0.0), (0.86 * w, 0.40 * t), (0.62 * w, t), (fl * w, t), (gw, d), (-gw, d), (-fl * w, t), (-0.62 * w, t),
            (-0.86 * w, 0.40 * t), (-w, 0.0)]
    bas = [(x, -y) for x, y in reversed(haut[1:-1])]
    return [(x, y, z) for x, y in haut + bas]


def lame_double(m, z0, z1, stations, mat="lame", fl=0.40, fond=0.26, cx=None):
    """stations : (f, demi-largeur, demi-épaisseur, gouttière 0..1). UV : u relatif à la largeur locale, v = f."""
    L = z1 - z0
    anneaux = []
    for f, w, t, g in stations:
        sec = section_double(w, t, g, z0 + f * L, fl, fond)
        dx = cx(f) if cx else 0.0
        anneaux.append([(x + dx, y, z) for x, y, z in sec])
    largeurs = [st[1] for st in stations]

    def uv(p, k, i, mat_=None):
        k = min(k, len(stations) - 1)
        dx = cx(stations[k][0]) if cx else 0.0
        return (0.5 + 0.5 * (p[0] - dx) / largeurs[k], max(0.0, (p[2] - z0) / L))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    pointe_sur(m, ids[-1], anneaux[-1], ((cx(1.0) if cx else 0.0), 0, z1), lambda i: mat, uv, (0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, uv)
    return anneaux


def lame_simple(m, z0, z1, stations, pointe_x, mat="lame"):
    """Lame à UN tranchant : stations (f, x_dos, x_fil, demi-épaisseur du dos, gouttière 0..1). Le dos (méplat chanfreiné) côté
    x_dos, la gouttière le long du dos, le biseau vers le fil côté x_fil. UV : u = 0,5 (dos) -> 1 (fil), v = f."""
    L = z1 - z0
    anneaux = []
    infos = []
    for f, s, e, t, g in stations:
        W = e - s
        d = t * (1.0 - 0.45 * g)
        z = z0 + f * L
        haut = [(s, 0.55 * t), (s + 0.035 * W, t), (s + 0.12 * W, t), (s + 0.15 * W, d), (s + 0.31 * W, d), (s + 0.34 * W, t),
                (s + 0.58 * W, 0.86 * t), (s + 0.86 * W, 0.36 * t), (e, 0.0)]
        bas = [(x, -y) for x, y in reversed(haut[:-1])]
        anneaux.append([(x, y, z) for x, y in haut + bas])
        infos.append((s, W))

    def uv(p, k, i, mat_=None):
        k = min(k, len(infos) - 1)
        s, W = infos[k]
        return (0.5 + 0.5 * min(1.0, max(0.0, (p[0] - s) / W)), max(0.0, (p[2] - z0) / L))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (pointe_x, 0, z1), lambda i: mat, uv, (1.0, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, uv)
    return anneaux


# ================================================================== armes
def anneau_tube(m, c, R, r, mat, axe_a=(1.0, 0.0, 0.0), axe_b=(0.0, 0.0, 1.0), n=12, cotes=6):
    """Anneau (tore) de rayon R dans le plan (axe_a, axe_b), section ronde r."""
    pts = [tuple(c[k] + R * (axe_a[k] * math.cos(TAU * i / n) + axe_b[k] * math.sin(TAU * i / n)) for k in range(3)) for i in range(n + 1)]
    ax = _x(axe_a, axe_b)
    tube(m, pts, [(r, r)] * len(pts), mat, cotes=cotes, bouts=False, normale=ax)


def stations(fs, w, t, g):
    return [(f, w(f), t(f), g(f)) for f in fs]


def lame_double_breches(m, z0, z1, sts, breches, mat="lame", fl=0.40, fond=0.26):
    """Comme lame_double, avec ébréchures (f, demi-étendue, profondeur, côté +1/-1) : stations ajoutées et fil retiré."""
    fs = sorted(set([s_[0] for s_ in sts] + [x for f0, d, pr, c in breches for x in (f0 - d, f0, f0 + d)]))

    def interp(f):
        for a_, b_ in zip(sts, sts[1:]):
            if a_[0] <= f <= b_[0]:
                u = (f - a_[0]) / (b_[0] - a_[0])
                return tuple(a_[i] + (b_[i] - a_[i]) * u for i in range(4))
        return sts[-1]
    L = z1 - z0
    tout = [interp(f) for f in fs]
    secs = []
    for f, w, t, g in tout:
        sec = section_double(w, t, g, z0 + f * L, fl, fond)
        for f0, d, pr, c in breches:
            if abs(f - f0) < 1e-6:
                sec = [((x - c * pr if (x * c) > 0.80 * w else x), y, z) for x, y, z in sec]
        secs.append(sec)

    def uv(p, k, i, mat_=None):
        k = min(k, len(tout) - 1)
        return (0.5 + 0.5 * p[0] / tout[k][1], max(0.0, (p[2] - z0) / L))
    ids = relier(m, secs, lambda k, i: mat, uv)
    pointe_sur(m, ids[-1], secs[-1], (0, 0, z1), lambda i: mat, uv, (0.5, 1.0))
    capuchon(m, ids[0], secs[0], mat, uv)


def filet(m, a, b, y, mat, demi=0.0007):
    """Filet incrusté (marque de forge, gravure) posé à plat à l'épaisseur y (signe = face)."""
    dz, dx = b[1] - a[1], b[0] - a[0]
    ln = math.hypot(dx, dz) or 1.0
    ex, ez = -dz / ln * demi, dx / ln * demi
    q = [m.sommet((a[0] - ex, y, a[1] - ez)), m.sommet((a[0] + ex, y, a[1] + ez)), m.sommet((b[0] + ex, y, b[1] + ez)),
         m.sommet((b[0] - ex, y, b[1] - ez))]
    m.face(q if y > 0 else list(reversed(q)), mat, [(0, 0), (1, 0), (1, 1), (0, 1)])


def epee_soldat():
    """Épée de soldat : ~1,06 m (pommeau -0,13 -> pointe 0,928), garde 0,175."""
    Z_G, Z_P = 0.175, 0.928
    L = Z_P - Z_G
    fs = [0.0, 0.008, 0.02] + [0.04 + 0.93 * (k / 30) ** 0.95 for k in range(31)]

    def w(f):
        w80 = 0.0300 - 0.0085 * 0.80 ** 1.5
        if f <= 0.80:
            return 0.0300 - 0.0085 * f ** 1.5
        return w80 * max(0.05, (1.0 - ((f - 0.80) / 0.20) ** 1.8)) ** 0.62

    def t(f):
        return 0.0076 - 0.0038 * f

    def g(f):
        return min(1.0, f / 0.025) if f < 0.66 else max(0.0, 1.0 - (f - 0.66) / 0.13)
    M = Maille("lame")
    lame_double_breches(M, Z_G, Z_P, stations(fs, w, t, g), [(0.335, 0.010, 0.0022, 1), (0.585, 0.009, 0.0016, -1),
                                                             (0.71, 0.007, 0.0012, 1)], "lame", fl=0.42, fond=0.27)
    # marque de forge incrustée de fer au fond de la gouttière (croix, deux traits, croix) : seule « fioriture » permise
    yf = t(0.06) * 0.5 + 0.0004   # fond de la gouttière (d = t x 0,5)
    zc = Z_G + 0.050
    for sgn in (1, -1):
        for a_, b_ in [((0, 0.000), (0, 0.016)), ((-0.0045, 0.008), (0.0045, 0.008)), ((-0.0035, 0.024), (0.0035, 0.040)),
                       ((0.0035, 0.024), (-0.0035, 0.040)), ((0, 0.048), (0, 0.064)), ((-0.0045, 0.056), (0.0045, 0.056))]:
            filet(M, (a_[0], zc + a_[1]), (b_[0], zc + b_[1]), sgn * yf, "fer", 0.0008)
    M.creer()
    # ---- croisée : barre droite à 12 pans, gorges limées et bouts en olive à pans, bloc central chanfreiné, languettes
    G = Maille("croisee")
    zg = 0.157
    for s in (-1, 1):
        pts, ray = [], []
        n = 18
        for k in range(n + 1):
            u = k / n
            x = s * (0.011 + 0.090 * u)
            prof = 1.0 + 0.36 * math.exp(-((u - 0.94) / 0.055) ** 2) - 0.16 * math.exp(-((u - 0.83) / 0.025) ** 2) \
                - 0.10 * math.exp(-((u - 0.20) / 0.025) ** 2)
            pts.append((x, 0.0, zg + 0.005 * u * u))
            ray.append(((0.0090 - 0.0016 * u) * prof, (0.0125 - 0.0026 * u) * prof))
        if s < 0:
            pts.reverse()
            ray.reverse()
        tube(G, pts, ray, "fer", cotes=12, bouts=True, normale=(0.0, 0.0, 1.0), rot=math.pi / 12)
    revol(G, [(zg - 0.012, 0.0160), (zg - 0.009, 0.0215), (zg + 0.008, 0.0215), (zg + 0.012, 0.0185), (Z_G - 0.002, 0.0160),
              (Z_G + 0.001, 0.0132)], "fer", cotes=12, rx=1.0, ry=0.62, rot=math.pi / 12)
    for s in (1, -1):   # languettes en losange sur la lame et sur la fusée, rivets
        octaedre(G, (0, s * 0.0096, zg + 0.002), 0.0125, 0.0024, 0.036, 0.026, "fer")
        octaedre(G, (0, s * 0.0118, zg), 0.0032, 0.0016, 0.0035, 0.0035, "fer")
    G.creer()
    # ---- fusée : cuir enroulé en volume, bagues à bourrelet
    F = Maille("fusee")
    zb, zh = -0.062, 0.144
    fusee_enroulee(F, zb, zh, 0.0150, "cuir", cotes=16, n=32, tours=7.0, relief=0.11)
    bague(F, zb - 0.003, zb + 0.010, 0.0155, "fer", cotes=16)
    bague(F, zh - 0.010, zh + 0.003, 0.0155, "fer", cotes=16)
    F.creer()
    # ---- garde haute + pommeau à CINQ lobes (type viking tardif) allongé le long de la croisée, bouton de rivure
    P = Maille("pommeau")
    zp = zb - 0.003
    revol(P, [(zp - 0.011, 0.0240), (zp - 0.0085, 0.0315), (zp - 0.0025, 0.0315), (zp, 0.0205)], "fer", cotes=12, rx=1.0, ry=0.52,
          rot=math.pi / 12)   # garde haute (barre plate)
    zn = zp - 0.011
    prof = [(zn - 0.040, 0.0050), (zn - 0.037, 0.0120), (zn - 0.031, 0.0205), (zn - 0.022, 0.0270), (zn - 0.013, 0.0290),
            (zn - 0.006, 0.0285), (zn - 0.0015, 0.0260), (zn, 0.0245)]

    def lobes(k, j):   # cinq lobes séparés par des sillons, plus marqués en haut du pommeau
        f = TAU * j / 20
        x = math.cos(f)
        creux = (0.5 + 0.5 * math.cos(5 * math.acos(max(-1.0, min(1.0, x))))) ** 4
        return 1.0 - (0.11 if k <= 4 else 0.04) * creux
    revol(P, prof, "fer", cotes=20, rx=1.0, ry=0.52, mod=lobes, fond=True, haut=False)
    revol(P, [(zn - 0.047, 0.0040), (zn - 0.043, 0.0066), (zn - 0.039, 0.0062)], "fer", cotes=10, fond=True, haut=False)
    P.creer()
    return {"garde": Z_G, "pointe": (0.0, Z_P)}


def sabre_pillard():
    """Sabre de pillard (fauchon) : ~1,05 m (-0,12 -> 0,928), garde 0,164, pointe décalée (x 0,02) vers le fil."""
    Z_G, Z_P, PX = 0.164, 0.928, 0.020
    L = Z_P - Z_G

    def dos(f):   # dos droit puis qui plonge en courbe vers la pointe (pointe coupée du fauchon)
        return -0.0180 + (0.0380 * ((f - 0.36) / 0.64) ** 1.9 if f > 0.36 else 0.0)

    def fil(f):   # ventre qui s'élargit nettement (fauchon) puis remonte en arrondi vers la pointe
        if f <= 0.80:
            return 0.0250 + 0.0420 * (f / 0.80) ** 1.6
        u = (f - 0.80) / 0.20
        return PX + (0.0670 - PX) * max(0.0, 1.0 - u ** 2.0) ** 0.55

    def ep(f):
        return 0.0070 - 0.0030 * f

    def gouttiere(f):
        return min(1.0, f / 0.03) if f < 0.60 else max(0.0, 1.0 - (f - 0.60) / 0.12)
    base = [0.0, 0.01, 0.025] + [0.045 + 0.945 * (k / 36) ** 0.9 for k in range(37)]
    breches = [(0.22, 0.010, 0.0038), (0.31, 0.006, 0.0018), (0.41, 0.008, 0.0028), (0.505, 0.013, 0.0046), (0.585, 0.006, 0.0020),
               (0.665, 0.009, 0.0032), (0.74, 0.007, 0.0024)]
    fs = sorted(set([round(f, 5) for f in base] + [round(x, 5) for f0, d, p in breches for x in (f0 - d, f0)]))
    sts = []
    for f in fs:
        retrait = sum(p for f0, d, p in breches if abs(f - f0) < 1e-6)
        sts.append((f, dos(f), fil(f) - retrait, ep(f), gouttiere(f)))
    M = Maille("lame")
    lame_simple(M, Z_G, Z_P, sts, PX, "lame")
    M.creer()
    # ---- croisée en S, section à 8 pans, bouts renflés, clou (nagel) sur la face, bloc central
    G = Maille("croisee")
    zg = 0.150
    pts, ray = [], []
    n = 24
    for k in range(n + 1):
        u = k / n * 2 - 1      # -1 (côté dos) -> +1 (côté fil)
        x = 0.064 * u
        z = zg + 0.017 * math.sin(u * math.pi * 0.5) * abs(u) ** 0.7   # S : côté fil vers la lame, côté dos vers le pommeau
        r = 0.0078 - 0.0018 * abs(u) + 0.0024 * math.exp(-((abs(u) - 0.96) / 0.05) ** 2) - 0.0010 * math.exp(-((abs(u) - 0.82) / 0.03) ** 2)
        pts.append((x, 0.0, z))
        ray.append((r * 0.95, r * 1.18))
    tube(G, pts, ray, "fer", cotes=8, bouts=True, normale=(0.0, 0.0, 1.0), rot=math.pi / 8)
    revol(G, [(zg - 0.012, 0.0155), (zg - 0.007, 0.0195), (zg + 0.007, 0.0195), (zg + 0.012, 0.0160), (Z_G + 0.001, 0.0125)], "fer",
          cotes=8, ry=0.64, rot=math.pi / 8)
    tube(G, [(0.0, 0.0105, zg), (0.0, 0.0150, zg + 0.0005), (0.0, 0.0190, zg + 0.0015), (0.0, 0.0215, zg + 0.003)],
         [(0.0036, 0.0036), (0.0033, 0.0033), (0.0028, 0.0028), (0.0018, 0.0018)], "fer", cotes=8, normale=(0.0, 0.0, 1.0))  # nagel
    octaedre(G, (0.0, -0.0122, zg), 0.0048, 0.0018, 0.0052, 0.0052, "fer")    # rivet du nagel, autre face
    G.creer()
    # ---- fusée : cuir enroulé en volume + lacet de cuir grossier croisé, virole
    F = Maille("fusee")
    zb, zh = -0.066, 0.138
    fusee_enroulee(F, zb, zh, 0.0155, "cuir", cotes=14, n=26, tours=5.0, relief=0.09)
    helice(F, zb + 0.012, zh - 0.014, 0.0155 * 1.05, 3.0, "cuir", ep=0.0024, seg=10, cotes=5)
    helice(F, zb + 0.012, zh - 0.014, 0.0155 * 1.05, -3.0, "cuir", ep=0.0022, seg=10, cotes=5)
    bague(F, zh - 0.011, zh + 0.002, 0.0160, "fer", cotes=14)
    F.creer()
    # ---- pommeau-crochet : calotte de fer repliée vers le fil, bord ourlé, rivet traversant
    P = Maille("pommeau")
    pts, ray = [], []
    n = 14
    for k in range(n + 1):
        u = k / n
        a = u * 1.2
        pts.append((0.021 * (1 - math.cos(a)) * 1.6, 0.0, zb + 0.003 - 0.047 * math.sin(a)))
        r = 0.0168 + 0.0046 * math.sin(math.pi * u * 0.9) + 0.0012 * math.exp(-((u - 0.06) / 0.04) ** 2)
        ray.append((r * 0.80, r))
    tube(P, pts, ray, "fer", cotes=14, bouts=True, normale=(0.0, 1.0, 0.0))
    P.creer()
    # rivets du pommeau : petites têtes bombées sur les deux faces
    R = Maille("rivets")
    for s in (1, -1):
        cxr, cyr, czr = 0.011, s * 0.0138, zb - 0.026
        prof = [(0.0, 0.0050), (0.0012, 0.0042), (0.0022, 0.0020)]
        anneaux = [[(cxr + r_ * math.cos(TAU * j / 8), cyr + s * dz, czr + r_ * math.sin(TAU * j / 8)) for j in range(8)] for dz, r_ in prof]
        ids = relier(R, anneaux, lambda k, i: "fer", lambda p, k, i, m_=None: (i / 8, k / 2))
        t_ = R.sommet((cxr, cyr + s * 0.0026, czr))
        for j in range(8):
            R.face([ids[-1][j], ids[-1][(j + 1) % 8], t_], "fer", [(0, 0), (1, 0), (0.5, 1)])
    R.creer()
    return {"garde": Z_G, "pointe": (PX, Z_P)}


def epee_doree():
    """Épée d'apparat : ~1,0 m (-0,085 -> 0,921), garde 0,172."""
    Z_G, Z_P = 0.172, 0.921
    w0 = 0.0300
    fs = [0.0, 0.008, 0.02] + [0.04 + 0.935 * (k / 28) ** 0.95 for k in range(29)]

    def w(f):
        feuille = 0.0030 * math.exp(-((f - 0.60) / 0.16) ** 2) - 0.0022 * math.exp(-((f - 0.28) / 0.12) ** 2)
        b = w0 - 0.0040 * f + feuille
        if f < 0.74:
            return b
        return b * max(0.05, 1.0 - ((f - 0.74) / 0.26) ** 1.6) ** 0.55

    def t(f):
        return 0.0072 - 0.0034 * f

    def g(f):
        return min(1.0, f / 0.025) if f < 0.66 else max(0.0, 1.0 - (f - 0.66) / 0.12)
    M = Maille("lame")
    lame_double(M, Z_G, Z_P, stations(fs, w, t, g), "lame_or", fl=0.40, fond=0.24)
    M.creer()
    G = Maille("croisee")
    zg = 0.152
    for s in (-1, 1):
        # quillon : sort du bloc, balustre, s'incline vers la lame, se termine en VOLUTE enroulée
        pts, ray = [], []
        n1 = 13
        for k in range(n1):
            u = k / (n1 - 1)
            pts.append((s * (0.012 + 0.070 * u), 0.0, zg + 0.010 * u ** 1.5))
            bal = 1.0 + 0.30 * math.exp(-((u - 0.30) / 0.07) ** 2) + 0.18 * math.exp(-((u - 0.62) / 0.05) ** 2) \
                - 0.10 * math.exp(-((u - 0.46) / 0.04) ** 2)
            ray.append(((0.0060 - 0.0008 * u) * bal, (0.0070 - 0.0010 * u) * bal))
        cx, cz = s * 0.090, zg + 0.002
        R0 = 0.0128
        a0 = math.atan2(pts[-1][2] - cz, abs(pts[-1][0]) - abs(cx))
        n2 = 24
        for k in range(1, n2 + 1):
            u = k / n2
            a = a0 - u * TAU * 1.05
            R = R0 * (1.0 - 0.72 * u)
            pts.append((cx + s * R * math.cos(a), 0.0, cz + R * math.sin(a)))
            rr = 0.0052 * (1.0 - 0.52 * u)
            ray.append((rr, rr * 1.1))
        if s < 0:
            pts.reverse()
            ray.reverse()
        tube(G, pts, ray, "or", cotes=10, bouts=True, normale=(0.0, 1.0, 0.0))
        octaedre(G, (cx, 0.0, cz), 0.0040, 0.0062, 0.0040, 0.0040, "or")     # bouton au coeur de la volute
    # anneaux de garde (pas d'âne) de part et d'autre de la lame, dans le plan de la croisée
    for s in (1, -1):
        anneau_tube(G, (0.0, s * 0.017, zg + 0.002), 0.0115, 0.0024, "or", axe_a=(1.0, 0.0, 0.0), axe_b=(0.0, s * 0.55, -0.83), n=14,
                    cotes=6)
    revol(G, [(zg - 0.014, 0.0150), (zg - 0.010, 0.0220), (zg + 0.008, 0.0220), (zg + 0.013, 0.0180), (Z_G - 0.003, 0.0165),
              (Z_G + 0.001, 0.0142)], "or", cotes=12, ry=0.62, rot=math.pi / 12)
    for s in (1, -1):
        octaedre(G, (0, s * 0.0120, zg + 0.004), 0.0152, 0.0026, 0.042, 0.027, "or")      # écusson en losange
        octaedre(G, (0, s * 0.0150, zg + 0.002), 0.0066, 0.0032, 0.0072, 0.0072, "gemme")  # pierre sertie
        for dx, dz in ((0.0, 0.0105), (0.0, -0.0065), (0.0062, 0.002), (-0.0062, 0.002)):
            octaedre(G, (dx, s * 0.0138, zg + dz), 0.0016, 0.0012, 0.0016, 0.0016, "or")  # griffes du chaton
    G.creer()
    # ---- chape dorée au talon de la lame
    C = Maille("chape")
    revol(C, [(Z_G - 0.001, 0.0128), (Z_G + 0.003, 0.0150), (Z_G + 0.011, 0.0150), (Z_G + 0.014, 0.0120)], "or", cotes=12, ry=0.30,
          fond=False, haut=False)
    C.creer()
    # ---- fusée : cuir fileté de deux fils d'or croisés, bagues torsadées
    F = Maille("fusee")
    zb, zh = -0.030, 0.136
    fusee_enroulee(F, zb, zh, 0.0140, "cuir", cotes=16, n=24, tours=3.0, relief=0.04, renfle=0.08)
    helice(F, zb + 0.008, zh - 0.008, 0.0140, 8.0, "or", ep=0.0012, renfle=0.08, seg=10, cotes=4)
    helice(F, zb + 0.008, zh - 0.008, 0.0140, -8.0, "or", ep=0.0010, renfle=0.08, seg=10, cotes=4)
    for z0, z1 in ((zb - 0.004, zb + 0.008), (zh - 0.008, zh + 0.004)):
        bague(F, z0, z1, 0.0146, "or", cotes=16)
        helice(F, z0 + 0.003, z1 - 0.003, 0.0146 * 1.16, 4.0, "or", ep=0.0010, renfle=0.0, seg=12, cotes=4)   # torsade
    F.creer()
    # ---- pommeau en poire à 12 pans, collet, gemmes serties sur les deux faces, bouton de rivure
    P = Maille("pommeau")
    zp = zb - 0.004
    prof = [(zp - 0.045, 0.0060), (zp - 0.041, 0.0140), (zp - 0.034, 0.0205), (zp - 0.025, 0.0228), (zp - 0.016, 0.0205),
            (zp - 0.009, 0.0150), (zp - 0.005, 0.0105), (zp - 0.003, 0.0125), (zp - 0.001, 0.0125), (zp + 0.002, 0.0135)]
    revol(P, prof, "or", cotes=12, ry=0.74, rot=math.pi / 12, fond=True, haut=True)
    for s in (1, -1):
        octaedre(P, (0.0, s * 0.0166, zp - 0.025), 0.0070, 0.0032, 0.0070, 0.0070, "gemme")
        for dx, dz in ((0.0062, 0.0), (-0.0062, 0.0), (0.0, 0.0062), (0.0, -0.0062)):
            octaedre(P, (dx, s * 0.0158, zp - 0.025 + dz), 0.0015, 0.0011, 0.0015, 0.0015, "or")
    revol(P, [(zp - 0.052, 0.0036), (zp - 0.049, 0.0060), (zp - 0.045, 0.0052)], "or", cotes=10, fond=True, haut=False)
    P.creer()
    return {"garde": Z_G, "pointe": (0.0, Z_P)}


def dague_acier():
    """Dague : ~0,52 m (-0,072 -> 0,447), garde 0,104."""
    Z_G, Z_P = 0.104, 0.447
    fs = [0.0, 0.012, 0.03] + [0.055 + 0.915 * (k / 20) ** 0.95 for k in range(21)]

    def w(f):
        b = 0.0190 - 0.0066 * f
        return b if f < 0.70 else b * max(0.06, 1.0 - ((f - 0.70) / 0.30) ** 1.5) ** 0.6

    def t(f):
        return 0.0064 - 0.0034 * f

    def g(f):
        return min(1.0, f / 0.03) if f < 0.60 else max(0.0, 1.0 - (f - 0.60) / 0.14)
    M = Maille("lame")
    lame_double(M, Z_G, Z_P, stations(fs, w, t, g), "lame", fl=0.34, fond=0.18)
    M.creer()
    # ---- quillons recourbés vers la lame, boules à pans aux bouts, bloc et languettes
    G = Maille("croisee")
    zg = 0.094
    for s in (-1, 1):
        pts, ray = [], []
        for k in range(13):
            u = k / 12
            pts.append((s * (0.008 + 0.040 * u), 0.0, zg + 0.016 * u ** 2))
            bal = 1.0 + 0.22 * math.exp(-((u - 0.28) / 0.07) ** 2)
            ray.append(((0.0046 - 0.0012 * u) * bal, (0.0056 - 0.0014 * u) * bal))
        if s < 0:
            pts.reverse()
            ray.reverse()
        tube(G, pts, ray, "fer", cotes=10, bouts=True, normale=(0.0, 0.0, 1.0), rot=math.pi / 10)
        bx, bz = s * 0.0495, zg + 0.0172
        revol(G, [(bz - 0.0066, 0.0016), (bz - 0.0052, 0.0044), (bz - 0.0020, 0.0064), (bz + 0.0020, 0.0064), (bz + 0.0052, 0.0044),
                  (bz + 0.0066, 0.0016)], "fer", cotes=10, cx=bx)
    revol(G, [(zg - 0.008, 0.0105), (zg - 0.005, 0.0140), (zg + 0.005, 0.0140), (zg + 0.008, 0.0115), (Z_G + 0.001, 0.0092)], "fer",
          cotes=10, ry=0.64, rot=math.pi / 10)
    for s in (1, -1):
        octaedre(G, (0, s * 0.0082, zg + 0.002), 0.0080, 0.0018, 0.019, 0.012, "fer")
    G.creer()
    # ---- fusée
    F = Maille("fusee")
    zb, zh = -0.024, 0.086
    fusee_enroulee(F, zb, zh, 0.0128, "cuir", cotes=14, n=22, tours=4.5, relief=0.10)
    bague(F, zb - 0.002, zb + 0.008, 0.0132, "fer", cotes=14)
    bague(F, zh - 0.008, zh + 0.002, 0.0132, "fer", cotes=14)
    F.creer()
    # ---- pommeau à pans (disque bombé à 12 pans, gorge), bouton
    P = Maille("pommeau")
    zp = zb - 0.002
    revol(P, [(zp - 0.038, 0.0060), (zp - 0.035, 0.0145), (zp - 0.029, 0.0200), (zp - 0.023, 0.0205), (zp - 0.020, 0.0185),
              (zp - 0.017, 0.0205), (zp - 0.011, 0.0190), (zp - 0.005, 0.0130), (zp - 0.001, 0.0105), (zp + 0.001, 0.0112)],
          "fer", cotes=12, ry=0.62, rot=math.pi / 12, fond=True, haut=True)
    revol(P, [(zp - 0.044, 0.0030), (zp - 0.041, 0.0052), (zp - 0.038, 0.0048)], "fer", cotes=8, fond=True, haut=False)
    P.creer()
    return {"garde": Z_G, "pointe": (0.0, Z_P)}


ARMES = {"epee_soldat": epee_soldat, "sabre_pillard": sabre_pillard, "epee_doree": epee_doree, "dague_acier": dague_acier}


def exporter(nom, fn):
    vider()
    for n in MATS:
        bpy.data.materials.new(n)
    rep = fn()
    vide("prise", Z_PRISE)
    vide("garde", rep["garde"])
    p = vide("pointe", rep["pointe"][1])
    p.location.x = rep["pointe"][0]
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = 0
    zmin, zmax, xmax = 9.0, -9.0, 0.0
    par = {}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            t = sum(len(q.vertices) - 2 for q in o.data.polygons)
            par[o.name] = t
            tris += t
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
            xmax = max(xmax, max(abs(v.co.x) for v in o.data.vertices))
    print("LAME_HD %s tris=%d longueur=%.3f (%.3f -> %.3f) demi-largeur=%.3f pieces=%s -> %s" % (nom, tris, zmax - zmin, zmin, zmax, xmax,
                                                                                             par, glb))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, nom + ".blend"))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nom in (args or list(ARMES)):
    exporter(nom, ARMES[nom])
