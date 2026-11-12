# LAMES HD v2 « FIDÈLES » (branche armes/lames_hd, retour utilisateur du 2026-11-12 sur la v1 : « c'est super stylé, elles sont
# beaucoup plus réelles [...] si elles pouvaient garder leur forme originelle ce serait bien, notamment la dague »).
# Même matière et même niveau de détail que la v1 (lames_hd.py : pans, fil, biseau, gouttière, cuir enroulé en volume, bagues,
# rivets), mais la SILHOUETTE est celle du modèle Quaternius CC0 d'origine, MESURÉE (mesure_quaternius.py) :
#   lame    : coupes à chaque hauteur de sommet de l'original + tous les 1,5 cm -> bords gauche / droit exacts (ébréchures, dents,
#             encoche du dos, courbure, forme et position de la pointe) ; sections HD posées entre ces bords ;
#   garde   : coupes le long de X -> hauteur (z min / max) et épaisseur à chaque station -> barre HD à 10 pans sur ce gabarit
#             (cornes, quillons tombants, bouts évasés compris) ;
#   fusée   : coupes le long de Z -> rayon et excentrement (lissés) -> cuir enroulé HD de mêmes proportions ;
#   pommeau : coupes le long de Z -> anneaux elliptiques à 12 pans de la même forme.
# Matériaux (EpeesLongues) : lame / lame_or (épée dorée), fer, or (garde et pommeau de l'épée dorée), cuir.
#   blender.exe -b --python sources_blender/lames_hd/lames_hd_v2.py -- [epee_soldat sabre_pillard epee_doree dague_acier]
# Sortie : assets/modeles/armes/lames_hd/v2/<id>.glb (la v1 reste dans assets/modeles/armes/lames_hd/<id>.glb).
import bpy, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
_v1 = open(os.path.join(ICI, "lames_hd.py"), encoding="utf-8").read().split('ARMES = {"epee_soldat"')[0]
exec(_v1)                                    # outils de forme de la v1 (tube, revol, bague, helice, octaedre, Maille...)
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import mesure_quaternius as mq
DEPOT = os.path.dirname(os.path.dirname(ICI))
SOURCE = os.path.join(DEPOT, "assets", "modeles", "armes", "cc0_essai")
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "lames_hd", "v2")

# id : glb d'origine, échelle / décalage du montage d'origine (.tscn), matière de la lame, des ferrures, lame à un tranchant,
#      repères d'origine (garde, pointe x, pointe y), demi-épaisseur de lame (talon, pointe)
CONFIG = {
    "epee_soldat": ("01_sword", 1.0, 0.0, "lame", "fer", False, 0.175, 0.0, 0.928, (0.0076, 0.0040)),
    "sabre_pillard": ("02_sword_2", 1.0, 0.0, "lame", "fer", True, 0.164, 0.02, 0.928, (0.0070, 0.0040)),
    "epee_doree": ("03_sword_golden", 1.0, 0.0, "lame_or", "or", False, 0.172, 0.0, 0.921, (0.0072, 0.0038)),
    "dague_acier": ("04_dagger", 1.3, -0.009, "lame", "fer", True, 0.1041, 0.013, 0.4473, (0.0060, 0.0032)),
}


def lisse(vals, zs, demi, mode="moy"):
    out = []
    for i, z in enumerate(zs):
        fen = [vals[j] for j in range(len(zs)) if abs(zs[j] - z) <= demi]
        out.append(min(fen) if mode == "min" else (max(fen) if mode == "max" else sum(fen) / len(fen)))
    return out


def coupes_lame(tris):
    z0, z1 = mq.etendue(tris, 2)
    zs = set(round(z, 5) for z in mq.sommets_z(tris, z0 + 1e-4, z1 - 1e-4))
    n = int((z1 - z0) / 0.015)
    zs |= set(round(z0 + (z1 - z0) * k / n, 5) for k in range(1, n))
    zs.add(round(z0 + 1e-4, 5))
    zs = sorted(z for z in zs if z < z1 - 0.004)
    st = []
    for z, r in mq.profil(tris, 2, zs):
        if r is not None and r[0][1] - r[0][0] > 0.002:
            st.append((z, r[0][0], r[0][1]))
    # pointe : sommet le plus haut
    pts = [p for t in tris for p in t]
    haut = max(pts, key=lambda p: p[2])
    return st, (haut[0], haut[2])


def lame_fidele(m, tris, mat, simple, ep):
    st, (xt, zt) = coupes_lame(tris)
    z0 = st[0][0]
    L = zt - z0
    zs = [s[0] for s in st]
    xl = [s[1] for s in st]
    xr = [s[2] for s in st]
    anneaux = []
    infos = []
    if simple:
        dos_l = lisse(xl, zs, 0.035, "max")         # dos lissé (sans l'encoche) : place de la gouttière
        larg_l = lisse([b - a for a, b in zip(xl, xr)], zs, 0.035, "min")
    else:
        cc = lisse([(a + b) * 0.5 for a, b in zip(xl, xr)], zs, 0.05)
        wc = lisse([(b - a) * 0.5 for a, b in zip(xl, xr)], zs, 0.045, "min")
    for i, (z, a, b) in enumerate(st):
        f = (z - z0) / L
        t = ep[0] + (ep[1] - ep[0]) * f
        g = min(1.0, f / 0.03) if f < 0.62 else max(0.0, 1.0 - (f - 0.62) / 0.13)
        d = t * (1.0 - 0.48 * g)
        if simple:
            s, e = a, b
            W = e - s
            bv = min(0.40 * W, 0.016)
            ch = min(0.004, 0.15 * W)
            fs = max(dos_l[i] + 0.10 * larg_l[i], s + ch + 0.0012)
            fe = min(dos_l[i] + 0.32 * larg_l[i], e - bv - 0.0012)
            if fe - fs < 0.004:
                fe, d = fs + 0.004, t
            fe = min(fe, e - bv * 0.6)
            q = 0.15 * (fe - fs)
            haut = [(s, 0.55 * t), (s + ch, t), (fs, t), (fs + q, d), (fe - q, d), (fe, t), (e - bv, 0.86 * t), (e - 0.35 * bv, 0.36 * t),
                    (e, 0.0)]
            bas = [(x, -y) for x, y in reversed(haut[:-1])]
            infos.append(("s", s, W))
        else:
            c, w = cc[i], wc[i]
            bv = min(0.42 * w, 0.013)
            gw = 0.25 * w
            fl = gw * 1.45
            br = max(cc[i] + fl + 0.0008, b - bv)
            bl = min(cc[i] - fl - 0.0008, a + bv)
            haut = [(b, 0.0), (b - 0.4 * (b - br), 0.40 * t), (br, t), (c + fl, t), (c + gw, d), (c - gw, d), (c - fl, t), (bl, t),
                    (a + 0.4 * (bl - a), 0.40 * t), (a, 0.0)]
            bas = [(x, -y) for x, y in reversed(haut[1:-1])]
            infos.append(("d", c, max(b - c, c - a)))
        anneaux.append([(x, y, z) for x, y in haut + bas])

    def uv(p, k, i, mat_=None):
        k = min(k, len(infos) - 1)
        typ, c, w = infos[k]
        u = 0.5 + 0.5 * min(1.0, max(0.0, (p[0] - c) / w)) if typ == "s" else 0.5 + 0.5 * (p[0] - c) / w
        return (u, max(0.0, (p[2] - z0) / L))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (xt, 0.0, zt), lambda i: mat, uv, (1.0 if simple else 0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, uv)
    return z0, (xt, zt)


def gabarit(m, tris, axe, n, mat, cotes=10, min_r=0.0012, marge=0.0015):
    """Volume suivant un gabarit mesuré le long de `axe` (0 = X pour une garde, 2 = Z pour un pommeau) : à chaque station, section
    elliptique à `cotes` pans inscrite dans les étendues mesurées des deux autres axes."""
    a0, a1 = mq.etendue(tris, axe)
    vals = [a0 + marge + (a1 - a0 - 2 * marge) * k / (n - 1) for k in range(n)]
    st = [(v, r) for v, r in mq.profil(tris, axe, vals) if r is not None]
    anneaux = []
    for v, ((b0, b1), (c0, c1)) in st:
        cb, cc_ = (b0 + b1) * 0.5, (c0 + c1) * 0.5
        rb, rc = max(min_r, (b1 - b0) * 0.5), max(min_r, (c1 - c0) * 0.5)
        a = []
        for j in range(cotes):
            f = TAU * j / cotes + math.pi / cotes
            # section octogonale « à pans » : légère sur-épaisseur des pans (pas un tube rond)
            k = 1.0 / max(abs(math.cos(f)), abs(math.sin(f)), 0.80) * 0.94
            pb, pc = cb + rb * k * math.cos(f), cc_ + rc * k * math.sin(f)
            if axe == 0:
                a.append((v, pb, pc))          # (x, y, z)
            else:
                a.append((pb, pc, v))          # (x, y, z)
        anneaux.append(a)

    def uv(p, k, i, mat_=None):
        return (i / cotes * 2.0, k / max(1, len(anneaux) - 1) * 2.0)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    capuchon(m, ids[0], anneaux[0], mat, uv)
    m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return st


def fusee_fidele(m, tris, mat="cuir", cotes=16, n=30, tours=6.0, relief=0.10):
    """Cuir enroulé HD sur le gabarit de la fusée d'origine (rayon et excentrement lissés, ellipse x / y)."""
    z0, z1 = mq.etendue(tris, 2)
    zs = [z0 + 0.004 + (z1 - z0 - 0.008) * k / 24 for k in range(25)]
    pr = [(z, r) for z, r in mq.profil(tris, 2, zs) if r is not None]
    zz = [p[0] for p in pr]
    cx = lisse([(r[0][0] + r[0][1]) * 0.5 for z, r in pr], zz, 0.02)
    rx = lisse([(r[0][1] - r[0][0]) * 0.5 for z, r in pr], zz, 0.02)
    ry = lisse([(r[1][1] - r[1][0]) * 0.5 for z, r in pr], zz, 0.02)

    def at(z, arr):
        if z <= zz[0]:
            return arr[0]
        for i in range(len(zz) - 1):
            if zz[i] <= z <= zz[i + 1]:
                u = (z - zz[i]) / (zz[i + 1] - zz[i])
                return arr[i] + (arr[i + 1] - arr[i]) * u
        return arr[-1]
    anneaux = []
    for k in range(n + 1):
        u = k / n
        z = z0 + (z1 - z0) * u
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            ph = (f / TAU - tours * u) % 1.0
            dent = ph / 0.86 if ph < 0.86 else (1.0 - ph) / 0.14
            s = 1.0 + relief * (dent - 0.5)
            a.append((at(z, cx) + at(z, rx) * 0.94 * s * math.cos(f), at(z, ry) * 0.94 * s * math.sin(f), z))
        anneaux.append(a)
    relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes * 2.0, k / n * 2.0))
    return z0, z1, (at(z0, cx), at(z0, rx), at(z0, ry)), (at(z1, cx), at(z1, rx), at(z1, ry))


def bague_ell(m, z0, z1, c, rx, ry, mat, cotes=16):
    prof = [(z0, 1.0), (z0 + 0.0025, 1.14), (z1 - 0.0025, 1.14), (z1, 1.02)]
    anneaux = [[(c + rx * s * math.cos(TAU * j / cotes), ry * s * math.sin(TAU * j / cotes), z) for j in range(cotes)] for z, s in prof]
    relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes, k / 3))


def construire(nom):
    src, ech, dz, mat_lame, mat_fer, simple, zg, px, pz, ep = CONFIG[nom]
    T = mq.triangles(os.path.join(SOURCE, src + ".glb"), ech, dz)
    lame_tris = T.get("lame", []) + T.get("or", [])
    fer = T.get("fer", [])
    cuir = T.get("cuir", [])
    c0, c1 = mq.etendue(cuir, 2)
    vider()
    for n_ in MATS:
        bpy.data.materials.new(n_)
    M = Maille("lame")
    lame_fidele(M, lame_tris, mat_lame, simple, ep)
    M.creer()
    G = Maille("croisee")
    garde = mq.filtrer(fer, zmin=c1 - 0.02)
    gabarit(G, garde, 0, 30, mat_fer, cotes=10)
    gx = mq.etendue(garde, 2)
    for s in (1, -1):   # rivets du bloc central (deux faces)
        y = max(abs(v) for v in mq.etendue(mq.filtrer(garde, zmin=gx[0], zmax=gx[1]), 1))
        if nom == "epee_doree":   # pierre sertie au bloc central, griffes
            zc = (gx[0] + gx[1]) * 0.5 + 0.004
            octaedre(G, (0.0, s * (y + 0.0010), zc), 0.0066, 0.0032, 0.0072, 0.0072, "gemme")
            for dx, dz in ((0.0, 0.0085), (0.0, -0.0085), (0.0068, 0.0), (-0.0068, 0.0)):
                octaedre(G, (dx, s * (y + 0.0004), zc + dz), 0.0016, 0.0012, 0.0016, 0.0016, "or")
        else:
            octaedre(G, (0.0, s * (y + 0.0006), (gx[0] + gx[1]) * 0.5), 0.0032, 0.0016, 0.0034, 0.0034, mat_fer)
    G.creer()
    F = Maille("fusee")
    f0, f1, bas, haut = fusee_fidele(F, cuir, "cuir")
    bague_ell(F, f0 - 0.002, f0 + 0.009, bas[0], bas[1] * 1.02, bas[2] * 1.02, mat_fer)
    bague_ell(F, f1 - 0.009, f1 + 0.002, haut[0], haut[1] * 1.02, haut[2] * 1.02, mat_fer)
    rm = (bas[1] + haut[1]) * 0.5
    ec = ((bas[2] + haut[2]) * 0.5) / rm
    if nom == "epee_doree":       # filetage de deux fils d'or croisés (comme la v1)
        helice(F, f0 + 0.010, f1 - 0.010, rm * 0.98, 7.0, "or", ep=0.0012, ecrase=ec, renfle=0.0, seg=10, cotes=4)
        helice(F, f0 + 0.010, f1 - 0.010, rm * 0.98, -7.0, "or", ep=0.0010, ecrase=ec, renfle=0.0, seg=10, cotes=4)
    elif nom == "sabre_pillard":  # lacet de cuir grossier croisé (comme la v1)
        helice(F, f0 + 0.012, f1 - 0.012, rm, 3.0, "cuir", ep=0.0024, ecrase=ec, renfle=0.0, seg=10, cotes=5)
        helice(F, f0 + 0.012, f1 - 0.012, rm, -3.0, "cuir", ep=0.0022, ecrase=ec, renfle=0.0, seg=10, cotes=5)
    F.creer()
    P = Maille("pommeau")
    pom = mq.filtrer(fer, zmax=c0 + 0.005)
    st = gabarit(P, pom, 2, 16, mat_fer, cotes=12, marge=0.0008)
    pz0 = mq.etendue(pom, 2)[0]
    cxp = (st[0][1][0][0] + st[0][1][0][1]) * 0.5
    if nom == "epee_doree":   # gemmes serties sur les deux faces du pommeau
        zm = sum(v for v, r in st) / len(st)
        ym = max(r[1][1] for v, r in st)
        for s_ in (1, -1):
            octaedre(P, (cxp, s_ * (ym + 0.0004), zm), 0.0062, 0.0030, 0.0062, 0.0062, "gemme")
    revol(P, [(pz0 - 0.0035, 0.0030), (pz0 - 0.0010, 0.0050), (pz0 + 0.0015, 0.0048)], mat_fer, cotes=8, fond=True, haut=False, cx=cxp)
    P.creer()
    vide("prise", Z_PRISE)
    vide("garde", zg)
    p = vide("pointe", pz)
    p.location.x = px
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris, zmin, zmax, par = 0, 9.0, -9.0, {}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            t = sum(len(q.vertices) - 2 for q in o.data.polygons)
            par[o.name] = t
            tris += t
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
    print("LAME_HD_V2 %s tris=%d longueur=%.3f (%.3f -> %.3f) pieces=%s" % (nom, tris, zmax - zmin, zmin, zmax, par))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, nom + "_v2.blend"))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nom in (args or list(CONFIG)):
    construire(nom)
