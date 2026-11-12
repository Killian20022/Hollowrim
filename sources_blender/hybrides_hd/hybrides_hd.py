# ÉPÉES HYBRIDES HD (branche armes/hybrides_hd, demande du 2026-11-12 : refaire les armes qui font encore jouet « au niveau des
# lames HD », EN GARDANT LEUR FORME D'ORIGINE ; « raffine les lignes, fais ressortir les éléments, la brillance du shader »).
# Méthode des lames HD v2 (sources_blender/lames_hd/lames_hd_v2.py + mesure_quaternius.py), appliquée aux huit hybrides
# assets/modeles/armes/hybrides/h1..h8 (gardés tels quels : ils restent la référence « avant » et le retour arrière) :
#   on MESURE chaque pièce du glb d'origine (coupes par plans) et on reconstruit la pièce en HD sur ces mesures :
#   lame    : coupes à chaque hauteur de sommet + tous les 1 cm -> bords exacts (crans, talon, pointe) et épaisseur mesurée ;
#             section HD : fil, biseau secondaire, méplat, gouttière à flancs nets (obsidienne : veine de braise au fond) ;
#   garde   : coupes le long de X -> barre HD à 12 pans sur le gabarit (cornes, quillons, bouts évasés) + rivets bombés ;
#   fusée   : coupes le long de Z -> cuir enroulé (ou tressé : h6) en volume, mêmes rayon / excentrement, fil métallique
#             en hélice pour les armes précieuses ;
#   bagues  : chaque bague d'origine (groupée par hauteur) -> virole à bourrelets ;
#   pommeau : coupes le long de Z -> anneaux à 16 pans de la même forme + bouton de rivure ;
#   gemmes  : chaque octaèdre d'origine (même boîte, même centre) -> pierre taillée à facettes (rondiste, couronne, pavillon)
#             sertie d'un chaton et de griffes là où elle sort de la garde ; cristal du pommeau : bipyramide taillée + collet.
# Matériaux par nom (EpeesLongues, inchangés) ; repères prise / garde / pointe recopiés du glb d'origine.
#   blender.exe -b --python sources_blender/hybrides_hd/hybrides_hd.py -- [h1_garde_du_guet ...]
# Sortie : assets/modeles/armes/hybrides/hd/<id>.glb + hybrides_hd_info.json (ici).
import bpy, bmesh, json, math, os, sys

MOI = os.path.abspath(__file__)
ICI = os.path.dirname(MOI)
V2 = os.path.join(os.path.dirname(ICI), "lames_hd", "lames_hd_v2.py")
__file__ = V2
exec(open(V2, encoding="utf-8").read().split("args = sys.argv")[0])   # outils v1 + v2 (lame_fidele, gabarit, fusee_fidele...)
__file__ = MOI
ICI = os.path.dirname(MOI)
DEPOT = os.path.dirname(os.path.dirname(ICI))
SOURCE = os.path.join(DEPOT, "assets", "modeles", "armes", "hybrides")
SORTIE = os.path.join(SOURCE, "hd")
MATS = MATS + ("saphir",)
METAUX = ("fer", "or", "obsidienne")
LAMES = ("lame", "lame_or", "rubis", "saphir", "verre", "obsidienne", "veine")

# id : métal de la monture, fil sur la fusée (matériau ou None), fusée tressée, épaisseur mini relative de lame, détail propre
FICHES = {
    "h1_garde_du_guet": dict(fil=None, marque="fer"),
    "h2_dent_d_or": dict(fil="or", marque="or"),
    "h3_veilleuse": dict(fil=None, marque="fer"),
    "h4_crocs_de_cendre": dict(fil=None, veine=True),
    "h5_larme_de_givre": dict(fil="fer"),
    "h6_coeur_de_braise": dict(fil=None, tresse=True),
    "h7_sang_du_roi": dict(fil="or"),
    "h8_croc_de_givre": dict(fil="fer"),
}


# ------------------------------------------------------------------ lecture du glb d'origine
def lire(chemin):
    """{(objet, matériau): [triangles]}, {objet: [composantes (liste de sommets)]} par matériau, repères."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=chemin)
    tris, comps, reperes = {}, {}, {}
    for o in bpy.data.objects:
        if o.type != 'MESH':
            reperes[o.name] = tuple(o.matrix_world.translation)
            continue
        me, M = o.data, o.matrix_world
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            mat = me.materials[t.material_index].name.split(".")[0]
            tris.setdefault((o.name, mat), []).append([tuple(M @ me.vertices[v].co) for v in t.vertices])
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)   # le glTF sépare les sommets des faces plates
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        vu = set()
        for v in bm.verts:
            if v.index in vu:
                continue
            pile, comp = [v], []
            vu.add(v.index)
            while pile:
                a = pile.pop()
                comp.append(a)
                for e in a.link_edges:
                    b = e.other_vert(a)
                    if b.index not in vu:
                        vu.add(b.index)
                        pile.append(b)
            mats = set(me.materials[f.material_index].name.split(".")[0] for a in comp for f in a.link_faces)
            comps.setdefault(o.name, []).append((mats, [tuple(M @ a.co) for a in comp]))
        bm.free()
    return tris, comps, reperes


def ext(pts, k):
    v = [p[k] for p in pts]
    return min(v), max(v)


# ------------------------------------------------------------------ lame (lame_fidele de la v2 + épaisseur mesurée)
def lame_hd(m, tris, mat, veine=False, pas=0.014):
    z0, z1 = mq.etendue(tris, 2)
    zs = set(round(z, 5) for z in mq.sommets_z(tris, z0 + 1e-4, z1 - 1e-4))
    n = int((z1 - z0) / pas)
    vz = sorted(zs)
    for k in range(1, n):     # stations régulières seulement loin des hauteurs de sommets (pas de doublons serrés)
        z = round(z0 + (z1 - z0) * k / n, 5)
        if all(abs(z - w) > 0.006 for w in vz):
            zs.add(z)
    zs.add(round(z0 + 1e-4, 5))
    zs = sorted(z for z in zs if z < z1 - 0.004)
    st = []
    for z, r in mq.profil(tris, 2, zs):
        if r is not None and r[0][1] - r[0][0] > 0.002:
            st.append((z, r[0][0], r[0][1], max(abs(r[1][0]), abs(r[1][1]))))
    pts = [p for t in tris for p in t]
    haut_ = max(pts, key=lambda p: p[2])
    xt, zt = haut_[0], haut_[2]
    z0 = st[0][0]
    L = zt - z0
    zz = [s[0] for s in st]
    xl, xr = [s[1] for s in st], [s[2] for s in st]
    cc = lisse([(a + b) * 0.5 for a, b in zip(xl, xr)], zz, 0.05)
    wc = lisse([(b - a) * 0.5 for a, b in zip(xl, xr)], zz, 0.045, "min")
    tl = lisse([s[3] for s in st], zz, 0.03)
    anneaux, infos = [], []
    for i, (z, a, b, _) in enumerate(st):
        f = (z - z0) / L
        t = max(tl[i] * 1.08, 0.0034 - 0.0016 * f)            # épaisseur mesurée (un peu renforcée : lisible de tranche)
        g = min(1.0, f / 0.03) if f < 0.70 else max(0.0, 1.0 - (f - 0.70) / 0.14)
        d = t * (1.0 - 0.50 * g)
        c, w = cc[i], wc[i]
        bv = min(0.40 * w, 0.013)
        gw = 0.22 * w
        fl = gw * 1.55
        br = max(c + fl + 0.0008, b - bv)
        bl = min(c - fl - 0.0008, a + bv)
        hb = [(b, 0.0), (b - 0.35 * (b - br), 0.34 * t), (br - 0.0006, 0.92 * t), (br - 0.25 * (br - c - fl), t), (c + fl, t),
              (c + gw, d), (c, d * 0.96), (c - gw, d), (c - fl, t), (bl + 0.25 * (c - fl - bl), t), (bl + 0.0006, 0.92 * t),
              (a + 0.35 * (bl - a), 0.34 * t), (a, 0.0)]
        bas = [(x, -y) for x, y in reversed(hb[1:-1])]
        anneaux.append([(x, y, z) for x, y in hb + bas])
        infos.append((c, max(b - c, c - a)))
    N = len(anneaux[0])

    def uv(p, k, i, mat_=None):
        k = min(k, len(infos) - 1)
        c, w = infos[k]
        return (0.5 + 0.5 * (p[0] - c) / w, max(0.0, (p[2] - z0) / L))
    # fond de gouttière : quads 5-6 et 6-7 (face +y), 16-17 et 17-18 (face -y)
    fond = {5, 6, N - 8, N - 7}
    md = (lambda k, i: "veine" if (i in fond and (z0 + (k / len(anneaux)) * L) < zt - 0.06) else mat) if veine else (lambda k, i: mat)
    ids = relier(m, anneaux, md, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (xt, 0.0, zt), lambda i: mat, uv, (0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, uv)
    return z0, zt, st


# ------------------------------------------------------------------ garde à arêtes (gabarit mesuré, section en losange adouci)
def garde_hd(m, tris, n, mat, cotes=12, marge=0.0012, min_r=0.0012):
    """Comme gabarit() de la v2 le long de X, mais section « losange adouci » : arête médiane sur les deux faces (y extrême),
    fil net en haut et en bas (z extrême) ; les extrêmes mesurés (silhouette de face et de profil) sont conservés."""
    a0, a1 = mq.etendue(tris, 0)
    vals = [a0 + marge + (a1 - a0 - 2 * marge) * k / (n - 1) for k in range(n)]
    st = [(v, r) for v, r in mq.profil(tris, 0, vals) if r is not None]
    anneaux = []
    for v, ((b0, b1), (c0, c1)) in st:
        cb, cc_ = (b0 + b1) * 0.5, (c0 + c1) * 0.5
        rb, rc = max(min_r, (b1 - b0) * 0.5), max(min_r, (c1 - c0) * 0.5)
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            q = abs(math.cos(f)) + abs(math.sin(f))
            k = 0.40 / q + 0.60
            a.append((v, cb + rb * k * math.cos(f), cc_ + rc * k * math.sin(f)))
        anneaux.append(a)

    def uv(p, k, i, mat_=None):
        return (i / cotes * 2.0, k / max(1, len(anneaux) - 1) * 2.0)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    capuchon(m, ids[0], anneaux[0], mat, uv)
    m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return st


def fil_rainure(m, a, b, f0, f1, sec, tours, mat, ep=0.0010, relief=0.11, seg=8):
    """Fil métallique couché DANS la rainure du cuir enroulé (même pas que la lanière de fusee_hd)."""
    pts, rays = [], []
    ns = max(8, int(tours * (b - a) / (f1 - f0) * seg))
    for k in range(ns + 1):
        z = a + (b - a) * k / ns
        u = (z - f0) / (f1 - f0)
        ang = TAU * (tours * u + 0.93)
        c, rx, ry = sec(z)
        s = (1.0 - relief * 0.42) * 0.95
        pts.append((c + (rx * s + ep * 0.7) * math.cos(ang), (ry * s + ep * 0.7) * math.sin(ang), z))
        rays.append((ep, ep))
    tube(m, pts, rays, mat, cotes=4, bouts=False, normale=(0.0, 0.0, 1.0), uv_l=12.0)


# ------------------------------------------------------------------ pierres taillées
def gemme_hd(m, c, rx, ry, rzh, rzb, mat, cotes=12):
    """Bipyramide taillée dans la boîte de l'octaèdre d'origine : rondiste (bande), couronne et pavillon à facettes alternées,
    table plate au sommet si la pierre est trapue (pierre de garde), pointe sinon (cristal)."""
    cx, cy, cz = c
    long_ = (rzh + rzb) > 2.4 * max(rx, ry)
    if long_:
        prof = [(cz + rzh, 0.0), (cz + 0.55 * rzh, 0.62), (cz + 0.12 * rzh, 0.97), (cz, 1.0), (cz - 0.10 * rzb, 0.97),
                (cz - 0.42 * rzb, 0.70), (cz - 0.75 * rzb, 0.34), (cz - rzb, 0.0)]
    else:
        prof = [(cz + rzh * 0.96, 0.30), (cz + rzh * 0.62, 0.66), (cz + rzh * 0.14, 0.96), (cz + rzh * 0.05, 1.0),
                (cz - rzb * 0.05, 1.0), (cz - rzb * 0.16, 0.95), (cz - rzb * 0.55, 0.55), (cz - rzb, 0.0)]
    anneaux = []
    for k, (z, s) in enumerate(prof):
        rot = (math.pi / cotes) * (k % 2)
        a = []
        for j in range(cotes):
            f = TAU * j / cotes + rot
            # section en losange arrondi (l'octaèdre d'origine a une ceinture en losange) : facettes visibles, mêmes extrêmes
            q = abs(math.cos(f)) + abs(math.sin(f))
            k_ = (1.0 / q) * 0.55 + 0.45
            a.append((cx + rx * s * k_ * math.cos(f), cy + ry * s * k_ * math.sin(f), z))
        anneaux.append(a)

    def uv(p, k, i, mat_=None):
        return (0.5 + 0.5 * (p[0] - cx) / max(rx, 1e-4), 0.5 + 0.5 * (p[2] - cz) / max(rzh, 1e-4))
    ids = relier(m, [an for an, (z, s) in zip(anneaux, prof) if s > 0.0], lambda k, i: mat, uv)
    pleins = [k for k, (z, s) in enumerate(prof) if s > 0.0]
    if prof[0][1] == 0.0:
        pointe_sur(m, list(reversed(ids[0])), list(reversed(anneaux[pleins[0]])), (cx, cy, prof[0][0]), lambda i: mat, uv, (0.5, 1.0))
    else:
        m.face(list(reversed(ids[0])), mat, [uv(p, 0, 0) for p in reversed(anneaux[pleins[0]])])
    pointe_sur(m, ids[-1], anneaux[pleins[-1]], (cx, cy, prof[-1][0]), lambda i: mat, uv, (0.5, 0.0))


def chaton_y(m, c, rx, rzh, rzb, y0, sens, mat, ep=0.0016, larg=0.0024, cotes=16):
    """Chaton (cadre de sertissage) posé sur la face y = y0 de la garde autour d'une pierre (losange arrondi), + 4 griffes."""
    cx, cy, cz = c
    def anneau(s, y, dl=0.0):
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            q = abs(math.cos(f)) + abs(math.sin(f))
            k_ = (1.0 / q) * 0.55 + 0.45
            rz = rzh if math.sin(f) > 0 else rzb
            a.append((cx + (rx * s * k_ + dl) * math.cos(f), y, cz + (rz * s * k_ + dl) * math.sin(f)))
        return a
    yi, ye = y0 - sens * 0.0006, y0 + sens * ep
    an = [anneau(1.0, yi, 0.0008), anneau(1.0, ye, 0.0004), anneau(1.0, ye, larg * 0.6), anneau(1.0, yi, larg)]
    relier(m, an, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes, k / 3))
    for f in (math.pi / 2, -math.pi / 2, 0.0, math.pi):
        rz = rzh if math.sin(f) > 0 else rzb
        px, pz = cx + rx * 0.98 * math.cos(f), cz + rz * 0.98 * math.sin(f)
        octaedre(m, (px, y0 + sens * ep * 1.4, pz), 0.0014, 0.0016, 0.0016, 0.0012, mat)


def rivet_y(m, x, z, y0, sens, r, mat):
    """Rivet à tête bombée sur une face y = y0 (sens +1 / -1)."""
    anneaux = []
    for yy, s in ((-0.0006, 1.05), (0.0, 1.0), (0.38 * r, 0.86), (0.66 * r, 0.52)):
        anneaux.append([(x + r * s * math.cos(TAU * j / 8), y0 + sens * yy, z + r * s * math.sin(TAU * j / 8)) for j in range(8)])
    ids = relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / 8, k / 3))
    pointe_sur(m, ids[-1], anneaux[-1], (x, y0 + sens * 0.80 * r, z), lambda i: mat, lambda p, k, i, m_=None: (0.5, 0.5), (0.5, 0.5))


# ------------------------------------------------------------------ fusée (cuir enroulé ou tressé, mesuré)
def fusee_hd(m, tris, tresse=False, cotes=18, n=38, tours=7.0, relief=0.11):
    z0, z1 = mq.etendue(tris, 2)
    zs = [z0 + 0.003 + (z1 - z0 - 0.006) * k / 30 for k in range(31)]
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
            if tresse:   # deux lanières croisées : losanges en relief
                p1 = (f / TAU - tours * 0.5 * u) % 1.0
                p2 = (f / TAU + tours * 0.5 * u) % 1.0
                tri = lambda p: 1.0 - abs(2.0 * p - 1.0)
                s = 1.0 + relief * (0.5 * (tri(p1) + tri(p2)) - 0.5) * 1.3
            else:
                ph = (f / TAU - tours * u) % 1.0
                dent = ph / 0.86 if ph < 0.86 else (1.0 - ph) / 0.14
                s = 1.0 + relief * (dent - 0.5)
            a.append((at(z, cx) + at(z, rx) * 0.95 * s * math.cos(f), at(z, ry) * 0.95 * s * math.sin(f), z))
        anneaux.append(a)
    relier(m, anneaux, lambda k, i: "cuir", lambda p, k, i, m_=None: (i / cotes * 2.0, k / n * 3.0))
    return z0, z1, (lambda z: (at(z, cx), at(z, rx), at(z, ry)))


def bague_hd(m, z0, z1, c, rx, ry, mat, cotes=16):
    h = z1 - z0
    e = min(0.0022, h * 0.22)
    prof = [(z0, 0.96), (z0 + e * 0.5, 1.06), (z0 + e, 1.10), (z0 + 1.6 * e, 1.04), (z1 - 1.6 * e, 1.04), (z1 - e, 1.10),
            (z1 - e * 0.5, 1.06), (z1, 0.96)]
    an = [[(c + rx * s * math.cos(TAU * j / cotes), ry * s * math.sin(TAU * j / cotes), z) for j in range(cotes)] for z, s in prof]
    relier(m, an, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes, k / 7))


def bandes(tris):
    """Regroupe des triangles en bandes de hauteur disjointes (bagues)."""
    b = []
    for t in sorted(tris, key=lambda t: min(p[2] for p in t)):
        lo, hi = min(p[2] for p in t), max(p[2] for p in t)
        if b and lo <= b[-1][1] + 0.0005:
            b[-1][1] = max(b[-1][1], hi)
            b[-1][2].append(t)
        else:
            b.append([lo, hi, [t]])
    return b


# ------------------------------------------------------------------ assemblage
def construire(ident):
    F = FICHES[ident]
    T, C, R = lire(os.path.join(SOURCE, ident + ".glb"))
    lame_tris, mat_lame = [], None
    for (o, mat), ts in T.items():
        if o == "lame" or (o == "monture" and mat in LAMES and mat not in METAUX):
            lame_tris += ts
            if mat != "veine":
                mat_lame = mat
    cuir = [t for (o, mat), ts in T.items() if mat == "cuir" for t in ts]
    metal_mat = next(mat for (o, mat) in T if o == "monture" and mat in METAUX)
    monture = [t for (o, mat), ts in T.items() if o in ("monture", "pommeau", "fusee") and mat == metal_mat for t in ts]
    if ident == "h4_crocs_de_cendre":          # lame et monture en obsidienne : la lame est l'objet « lame »
        monture = T[("monture", "obsidienne")]
    if ident == "h6_coeur_de_braise":
        monture = T[("monture", "fer")] + T[("pommeau", "fer")] + T[("fusee", "fer")]
    c0, c1 = mq.etendue(cuir, 2)
    cz = lambda t: (t[0][2] + t[1][2] + t[2][2]) / 3
    garde = [t for t in monture if cz(t) > c1 - 0.004]
    pom = [t for t in monture if cz(t) < c0 + 0.004]
    bag = [t for t in monture if c0 + 0.004 <= cz(t) <= c1 - 0.004]
    vider()
    for n_ in MATS:
        bpy.data.materials.new(n_)
    # ---- lame
    L = Maille("lame")
    z0, zt, st = lame_hd(L, lame_tris, mat_lame, veine=F.get("veine", False))
    if F.get("marque"):     # marque de forge incrustée au talon (deux faces) : rune « tiwaz » en filets
        w = min(s[2] - s[1] for s in st[:6]) * 0.5
        tb = max(s[3] for s in st[:6]) * 1.08
        zb = z0 + 0.030
        for sy in (1, -1):
            y = sy * (tb * 0.50 + 0.0002)
            filet(L, (0.0, zb), (0.0, zb + 0.026), y, F["marque"], 0.0006)
            filet(L, (0.0, zb + 0.026), (0.0075, zb + 0.016), y, F["marque"], 0.0006)
            filet(L, (0.0, zb + 0.026), (-0.0075, zb + 0.016), y, F["marque"], 0.0006)
    L.creer()
    # ---- garde (gabarit mesuré le long de X, 12 pans) + rivets
    G = Maille("croisee")
    stg = gabarit(G, garde, 0, 52, metal_mat, cotes=12, marge=0.0012)   # garde_hd (losange) essayée : trop molle, rejetée

    def y_garde(x):
        best = min(stg, key=lambda s: abs(s[0] - x))
        return max(abs(best[1][0][0]), abs(best[1][0][1]))
    gz = mq.etendue(garde, 2)
    gx = mq.etendue(garde, 0)
    # ---- gemmes et cristaux (chaque octaèdre d'origine)
    J = Maille("pierres")
    gem_centre = None
    for mats, pts in C.get("ornements", []):
        mat = sorted(mats)[0]
        xs, ys, zs_ = ext(pts, 0), ext(pts, 1), ext(pts, 2)
        eq = [p for p in pts if abs(p[2] - zs_[0]) > 1e-5 and abs(p[2] - zs_[1]) > 1e-5]
        czg = sum(p[2] for p in eq) / max(1, len(eq))
        cxg, cyg = (xs[0] + xs[1]) * 0.5, (ys[0] + ys[1]) * 0.5
        rx, ry = (xs[1] - xs[0]) * 0.5, (ys[1] - ys[0]) * 0.5
        rzh, rzb = zs_[1] - czg, czg - zs_[0]
        gemme_hd(J, (cxg, cyg, czg), rx, ry, rzh, rzb, mat)
        if gz[0] - 0.005 < czg < gz[1] + 0.005 and abs(cxg) < gx[1]:   # pierre de la garde : chaton là où elle sort
            y0 = y_garde(cxg)
            if abs(cxg) < 0.005 and czg > z0 + 0.004:   # pierre sertie dans le talon de la LAME (au-dessus de la garde)
                y0 = 1.08 * min(st, key=lambda e: abs(e[0] - czg))[3]
            if ry > y0 + 0.0008:
                s = 1.0 - y0 / ry
                for sy in (1, -1):
                    chaton_y(G, (cxg, 0.0, czg), rx * s, rzh * s, rzb * s, sy * y0, sy, metal_mat)
            if abs(cxg) < 0.005:
                gem_centre = (rx, czg)
        elif czg < c0:          # cristal du pommeau : collet de métal à la jonction
            zc = zs_[1] - 0.15 * rzh
            bague_hd(G, zc - 0.004, zc + 0.003, cxg, rx * 0.62 + 0.0015, ry * 0.62 + 0.0015, metal_mat, cotes=16)
    # rivets de la garde : de part et d'autre de la pierre centrale (ou au centre)
    def st_x(x):
        return min(stg, key=lambda e: abs(e[0] - x))
    xr = 0.022 if gem_centre is None or gem_centre[1] > gz[1] - 0.004 else gem_centre[0] + 0.0085
    for x in (-xr, xr):
        e = st_x(x)
        zr = (e[1][1][0] + e[1][1][1]) * 0.5
        for sy in (1, -1):
            rivet_y(G, x, zr, sy * max(abs(e[1][0][0]), abs(e[1][0][1])) * 0.97, sy, 0.0030, metal_mat)
    G.creer()
    # ---- fusée, bagues, fil
    Fz = Maille("fusee")
    f0, f1, sec = fusee_hd(Fz, cuir, tresse=F.get("tresse", False))
    for lo, hi, ts in bandes(bag):
        pts = [p for t in ts for p in t]
        xb, yb = ext(pts, 0), ext(pts, 1)
        bague_hd(Fz, lo, hi, (xb[0] + xb[1]) * 0.5, (xb[1] - xb[0]) * 0.5, (yb[1] - yb[0]) * 0.5, metal_mat)
    hauts = [b[1] for b in bandes(bag)] + [f0]
    if not bandes(bag):   # viroles aux deux bouts du cuir (comme la v2)
        cb, rxb, ryb = sec(f0 + 0.004)
        ch, rxh, ryh = sec(f1 - 0.004)
        bague_hd(Fz, f0 - 0.002, f0 + 0.009, cb, rxb * 1.05, ryb * 1.05, metal_mat)
        bague_hd(Fz, f1 - 0.009, f1 + 0.002, ch, rxh * 1.05, ryh * 1.05, metal_mat)
    if F.get("fil"):
        _, rxm, rym = sec((f0 + f1) * 0.5)
        bs = sorted([(lo, hi) for lo, hi, ts in bandes(bag)])
        trous = []
        a = f0 + 0.010
        for lo, hi in bs + [(f1 - 0.010, f1)]:
            if lo - a > 0.03:
                trous.append((a, lo - 0.002))
            a = hi + 0.002
        for a, b in trous:
            fil_rainure(Fz, a, b, f0, f1, sec, 7.0, F["fil"])
    Fz.creer()
    # ---- pommeau (gabarit le long de Z, 16 pans) + bouton de rivure
    P = Maille("pommeau")
    if pom:
        stp = gabarit(P, pom, 2, 26, metal_mat, cotes=16, marge=0.0008)
        pz0 = mq.etendue(pom, 2)[0]
        cxp = (stp[0][1][0][0] + stp[0][1][0][1]) * 0.5
        a_cristal = any(min(ext(pts, 2)) < pz0 + 0.002 for mats, pts in C.get("ornements", []))
        if not a_cristal:
            revol(P, [(pz0 - 0.0032, 0.0026), (pz0 - 0.0012, 0.0046), (pz0 + 0.0015, 0.0046)], metal_mat, cotes=12, fond=True,
                  haut=False, cx=cxp)
        P.creer()
    if J.f:
        J.creer()
    for nom_r in ("prise", "garde", "pointe"):
        p = R.get(nom_r, (0, 0, Z_PRISE))
        o = vide(nom_r, p[2])
        o.location.x = p[0]
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, ident + ".glb")
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
    print("HYBRIDE_HD %s tris=%d longueur=%.3f (%.3f -> %.3f) pieces=%s" % (ident, tris, zmax - zmin, zmin, zmax, par))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, ident + ".blend"))
    return {"triangles": tris, "longueur": round(zmax - zmin, 3), "pieces": par}


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
choix = [a for a in args if a in FICHES] or list(FICHES)
chemin_info = os.path.join(ICI, "hybrides_hd_info.json")
infos = json.load(open(chemin_info, encoding="utf-8")) if os.path.exists(chemin_info) else {}
for ident in choix:
    infos[ident] = construire(ident)
json.dump(infos, open(chemin_info, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
