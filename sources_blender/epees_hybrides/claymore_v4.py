# CLAYMORE v4 (branche combat/claymore_v4, retour utilisateur du 2026-11-11 : « il faudrait revoir un peu son style, la faire plus
# détaillée, augmenter les triangles »). Grande épée écossaise / nordique, lame de rubis (même matériau et même reflet que la
# claymore longue : ClaymoreMateriaux), ~2,5x les triangles de l'ancienne (n°05 Quaternius, 1 033 tris).
#   blender.exe -b --python sources_blender/epees_hybrides/claymore_v4.py
# Sortie : assets/modeles/armes/deux_mains/claymore_v4.glb (les anciennes claymore.glb / claymore_longue.glb restent).
# Repère commun (epees_longues.py) : lame +Z Blender (+Y glTF), X = tranchant / quillons, Y = épaisseur ; centre du poing droit à
# z = 0,03 (nœud « prise »), nœuds « garde » et « pointe ». Même poignée que la claymore longue (haut de fusée 0,084, fusée 0,32 m) :
# la prise des deux mains (ecart_mains 0,11, fusee_bas -0,23) et l'IK de la main gauche sont inchangées.
# Pièces :
#   lame      : rubis, section à 18 sommets (fil, biseau secondaire, méplat, gouttière à flancs nets qui s'efface aux 3/4),
#               15 stations (moins de déformation affine du shader ps1 sur la longueur), pointe en ogive ;
#   ricasso   : talon de fer à pans coupés, deux crochets de parade, bague de fer à la jonction avec le rubis ;
#   garde     : croisée en fer à quillons INCLINÉS vers la lame, balustres, terminaisons en QUATREFEUILLES (4 anneaux ajourés),
#               écusson (langue) en losange dessus / dessous, rivet ;
#   fusée     : cuir (tressage dans la texture) FILETÉ d'un fil de fer en hélice, bagues haute et basse ;
#   pommeau   : ROUE à rebord biseauté et moyeu bombé, rubis serti au centre (deux faces), bouton de rivure ;
#   gravure   : runes d'or discrètes en filets dans la gouttière (deux faces), près du talon.
import bpy, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
_lib = os.path.join(os.path.dirname(ICI), "epees_longues", "epees_longues.py")
exec(open(_lib, encoding="utf-8").read().split("# ================================================================== variantes")[0])
ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "deux_mains")

Z_HAUT = 0.084        # haut de la fusée (comme claymore_longue)
LP = 0.32             # longueur de la fusée
Z_GARDE = 0.094       # axe de la croisée
Z_RIC0 = 0.104        # le talon sort de la garde
Z_RIC1 = 0.212        # fin du talon de fer, début du rubis
Z_POINTE = 1.255
ZB = Z_HAUT - LP      # bas de la fusée


def _n(v):
    l = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / l for c in v)


def _x(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _d(a, b):
    return sum(x * y for x, y in zip(a, b))


def tube(m, pts, rayons, mat, cotes=8, bouts=True, normale=(0.0, 1.0, 0.0), uv_l=2.0):
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
        anneaux.append([tuple(p[k] + nn[k] * ra * math.cos(2 * math.pi * j / cotes) + bb[k] * rb * math.sin(2 * math.pi * j / cotes)
                              for k in range(3)) for j in range(cotes)])
    L = longs[-1] or 1.0

    def uv(p, k, i, mat_=None):
        return (longs[min(k, len(longs) - 1)] / L * uv_l, i / cotes)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    if bouts:
        capuchon(m, ids[0], anneaux[0], mat, uv)
        m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return anneaux


def anneau(m, c, R, r, mat, axe_a=(1, 0, 0), axe_b=(0, 0, 1), n_grand=8, n_petit=4, ecrase=1.0):
    """Tore dans le plan (axe_a, axe_b) ; section ronde de rayon r (aplatie de `ecrase` hors du plan)."""
    ax = _x(axe_a, axe_b)
    anneaux = []
    for i in range(n_grand + 1):
        f = 2 * math.pi * i / n_grand
        rad = tuple(axe_a[k] * math.cos(f) + axe_b[k] * math.sin(f) for k in range(3))
        anneaux.append([tuple(c[k] + rad[k] * (R + r * math.cos(2 * math.pi * j / n_petit)) + ax[k] * r * ecrase *
                              math.sin(2 * math.pi * j / n_petit) for k in range(3)) for j in range(n_petit)])

    def uv(p, k, i, mat_=None):
        return (k / n_grand * 2.0, i / n_petit)
    relier(m, anneaux, lambda k, i: mat, uv)


def roue(m, c, profil, mat, segs=16, mat_de=None):
    """Volume de révolution autour de l'axe Y (épaisseur de la lame) : profil (rayon, y) du moyeu vers l'extérieur puis retour."""
    anneaux = []
    for rho, y in profil:
        anneaux.append([(c[0] + rho * math.cos(2 * math.pi * j / segs), c[1] + y, c[2] + rho * math.sin(2 * math.pi * j / segs))
                        for j in range(segs)])

    def uv(p, k, i, mat_=None):
        return (i / segs * 2.0, k / (len(profil) - 1))
    ids = relier(m, anneaux, mat_de or (lambda k, i: mat), uv)
    return ids, anneaux


# ------------------------------------------------------------------ lame (rubis)
# stations (f = 0 talon -> 1 pointe ; demi-largeur, demi-épaisseur, gouttière 0..1)
P_LAME = [(0.000, 0.0300, 0.0074, 1.0), (0.020, 0.0297, 0.0074, 1.0), (0.080, 0.0290, 0.0072, 1.0), (0.160, 0.0284, 0.0070, 1.0),
          (0.250, 0.0278, 0.0067, 1.0), (0.350, 0.0271, 0.0064, 1.0), (0.450, 0.0263, 0.0061, 1.0), (0.550, 0.0253, 0.0058, 0.85),
          (0.640, 0.0241, 0.0055, 0.55), (0.720, 0.0226, 0.0051, 0.22), (0.780, 0.0209, 0.0048, 0.0), (0.840, 0.0187, 0.0044, 0.0),
          (0.890, 0.0161, 0.0040, 0.0), (0.930, 0.0129, 0.0035, 0.0), (0.965, 0.0086, 0.0028, 0.0)]
W_REF = 0.0300


def section_lame(w, t, g, z):
    d = t * (1.0 - 0.48 * g)          # fond de la gouttière
    gw = 0.22 * w if g > 0.01 else 0.05 * w
    haut = [(w, 0.0), (0.88 * w, 0.42 * t), (0.62 * w, t), (0.36 * w, t), (gw, d), (-gw, d), (-0.36 * w, t), (-0.62 * w, t),
            (-0.88 * w, 0.42 * t), (-w, 0.0)]
    bas = [(x, -y) for x, y in reversed(haut[1:-1])]
    return [(x, y, z) for x, y in haut + bas]


def construire():
    vider()
    for n in MATS:
        bpy.data.materials.new(n)
    L = Z_POINTE - Z_RIC1
    # ---- lame
    M = Maille("lame")
    anneaux = [section_lame(w, t, g, Z_RIC1 + f * L) for f, w, t, g in P_LAME]

    def uv_l(p, k, i, mat=None):
        return ((p[0] + W_REF) / (2 * W_REF), max(0.0, (p[2] - Z_RIC1) / L))
    ids = relier(M, anneaux, lambda k, i: "rubis", uv_l)
    pointe_sur(M, ids[-1], anneaux[-1], (0, 0, Z_POINTE), lambda i: "rubis", uv_l, (0.5, 1.0))
    capuchon(M, ids[0], anneaux[0], "rubis", uv_l)
    M.creer()
    # ---- gravure : runes d'or en filets dans la gouttière (les deux faces), discrètes, près du talon
    R = Maille("gravure")
    w0 = P_LAME[0][1]
    fond = P_LAME[0][2] * (1.0 - 0.48) + 0.0005
    runes = [  # traits (x0, z0, x1, z1) en unités de demi-gouttière / cm le long de la lame
        [(0, 0, 0, 3.2), (0, 3.2, 0.9, 2.2)], [(0, 0, 0, 3.2), (-0.9, 1.0, 0.9, 2.2)], [(-0.8, 0, 0, 3.2), (0, 3.2, 0.8, 0)],
        [(0, 0, 0, 3.2), (0, 2.2, 0.9, 3.2), (0, 1.2, 0.9, 2.2)], [(-0.8, 0.4, 0.8, 2.8), (0.8, 0.4, -0.8, 2.8)],
        [(0, 0, 0, 3.2), (0, 3.2, -0.9, 2.2)]]
    z = Z_RIC1 + 0.035
    for r in runes:
        for s in (1, -1):
            for x0, z0, x1, z1 in r:
                a = (x0 * 0.18 * w0, s * fond, z + z0 * 0.01)
                b = (x1 * 0.18 * w0, s * fond, z + z1 * 0.01)
                dz, dx = b[2] - a[2], b[0] - a[0]
                ln = math.hypot(dx, dz) or 1.0
                ex, ez = -dz / ln * 0.0008, dx / ln * 0.0008      # demi-largeur du filet (gravure discrète)
                q = [R.sommet((a[0] - ex, a[1], a[2] - ez)), R.sommet((a[0] + ex, a[1], a[2] + ez)),
                     R.sommet((b[0] + ex, b[1], b[2] + ez)), R.sommet((b[0] - ex, b[1], b[2] - ez))]
                R.face(q if s > 0 else list(reversed(q)), "or", [(0, 0), (1, 0), (1, 1), (0, 1)])
        z += 0.045
    R.creer()
    # ---- talon de fer (ricasso) à pans coupés + bague de jonction + crochets de parade
    T = Maille("ricasso")
    ric = []
    for k in range(6):
        zz = Z_RIC0 + (Z_RIC1 - Z_RIC0) * k / 5
        w, t = 0.0205 - 0.0008 * k / 5, 0.0080
        c = 0.0035
        ric.append([(w, t - c, zz), (w - c, t, zz), (-w + c, t, zz), (-w, t - c, zz), (-w, -t + c, zz), (-w + c, -t, zz),
                    (w - c, -t, zz), (w, -t + c, zz)])

    def uv_r(p, k, i, mat=None):
        return (i / 8 * 2.0, k / 5)
    relier(T, ric, lambda k, i: "fer", uv_r)
    tour(T, [(Z_RIC1 - 0.007, 0.0255), (Z_RIC1 - 0.002, 0.0330), (Z_RIC1 + 0.004, 0.0335), (Z_RIC1 + 0.009, 0.0300)], "fer",
         cotes=12, ecrase_y=0.36, uv_tours=1.0)
    for s in (-1, 1):   # crochets de parade : petites cornes qui partent du talon, recourbées vers la pointe
        tube(T, [(s * 0.019, 0, Z_RIC1 - 0.020), (s * 0.030, 0, Z_RIC1 - 0.018), (s * 0.040, 0, Z_RIC1 - 0.010),
                 (s * 0.045, 0, Z_RIC1 + 0.002), (s * 0.046, 0, Z_RIC1 + 0.010)],
             [(0.0050, 0.0062), (0.0046, 0.0055), (0.0040, 0.0045), (0.0030, 0.0034), (0.0014, 0.0016)], "fer", cotes=6)
    T.creer()
    # ---- garde : croisée, quillons inclinés vers la lame, balustres, quatrefeuilles, écusson
    G = Maille("croisee")
    for s in (-1, 1):
        chemin = []
        rayons = []
        for k in range(9):
            u = k / 8
            x = s * (0.012 + 0.150 * u)
            zz = Z_GARDE + 0.085 * (u ** 1.35)                       # monte vers la lame, de plus en plus
            bal = 1.0 + 0.30 * math.exp(-((u - 0.30) / 0.07) ** 2) + 0.22 * math.exp(-((u - 0.70) / 0.06) ** 2)
            rr = (0.0095 - 0.0030 * u) * bal
            chemin.append((x, 0.0, zz))
            rayons.append((rr * 0.95, rr * 1.05))
        if s < 0:
            chemin.reverse()
            rayons.reverse()
        tube(G, chemin, rayons, "fer", cotes=8, bouts=True)
        # quatrefeuille au bout du quillon : 4 anneaux dans le plan de la garde (face visible quand on voit le plat de la lame)
        bout = (s * 0.162, 0.0, Z_GARDE + 0.085)
        dirq = _n((s * 0.150, 0.0, 0.085 * 1.35))
        perp = (-dirq[2], 0.0, dirq[0])
        rq = 0.0118
        cq = tuple(bout[k] + dirq[k] * 0.014 for k in range(3))
        for v in (dirq, perp, tuple(-c for c in dirq), tuple(-c for c in perp)):
            anneau(G, tuple(cq[k] + v[k] * rq for k in range(3)), rq * 0.82, 0.0036, "fer", n_grand=8, n_petit=4, ecrase=1.3)
        octaedre(G, cq, 0.0055, 0.0055, 0.0055, 0.0055, "fer")         # bouton au coeur du quatrefeuille
    # bloc central de la croisée + écusson (langue) en losange sur la lame et sur la fusée
    tour(G, [(Z_GARDE - 0.012, 0.0160), (Z_GARDE - 0.008, 0.0215), (Z_GARDE + 0.008, 0.0215), (Z_GARDE + 0.012, 0.0170)], "fer",
         cotes=8, ecrase_y=0.62, uv_tours=1.0, rot=math.pi / 8)
    for s in (1, -1):
        octaedre(G, (0, s * 0.0118, Z_GARDE), 0.0150, 0.0026, 0.042, 0.030, "fer")
        octaedre(G, (0, s * 0.0148, Z_GARDE + 0.004), 0.0040, 0.0018, 0.0045, 0.0045, "or")   # rivet
    G.creer()
    # ---- fusée : cuir, bagues, fil de fer en hélice
    F = Maille("fusee")
    n = 12
    tour(F, [(ZB + LP * k / n, 0.0165 * (1.0 + 0.07 * math.sin(math.pi * k / n))) for k in range(n + 1)], "cuir", cotes=12,
         ecrase_y=0.86, uv_tours=2.0)
    for z0, z1 in ((ZB - 0.004, ZB + 0.016), (Z_HAUT - 0.016, Z_HAUT + 0.004)):
        tour(F, [(z0, 0.0168), (z0 + 0.004, 0.0205), (z1 - 0.004, 0.0205), (z1, 0.0175)], "fer", cotes=12, ecrase_y=0.86, uv_tours=1.0)
    tours_fil = 7.0
    pts, rays = [], []
    nseg = int(tours_fil * 9)
    for k in range(nseg + 1):
        u = k / nseg
        zz = ZB + 0.020 + (LP - 0.040) * u
        a = 2 * math.pi * tours_fil * u
        rr = 0.0165 * (1.0 + 0.07 * math.sin(math.pi * (zz - ZB) / LP)) + 0.0012
        pts.append((rr * math.cos(a), rr * 0.86 * math.sin(a), zz))
        rays.append((0.0016, 0.0016))
    tube(F, pts, rays, "fer", cotes=3, bouts=False, normale=(0.0, 0.0, 1.0), uv_l=14.0)
    F.creer()
    # ---- pommeau en roue : moyeu bombé, rebord biseauté, rubis serti (deux faces), col et bouton de rivure
    P = Maille("pommeau")
    cz = ZB - 0.040
    prof = [(0.0080, 0.0130), (0.0120, 0.0118), (0.0175, 0.0098), (0.0255, 0.0100), (0.0315, 0.0082), (0.0350, 0.0045),
            (0.0350, -0.0045), (0.0315, -0.0082), (0.0255, -0.0100), (0.0175, -0.0098), (0.0120, -0.0118), (0.0080, -0.0130)]
    ids, ann = roue(P, (0.0, 0.0, cz), prof, "fer", segs=16)
    capuchon(P, ids[0], ann[0], "fer", lambda p, k, i, m_=None: (0.5, 0.5))
    P.face(ids[-1], "fer", [(0.5, 0.5)] * len(ids[-1]))
    tour(P, [(cz + 0.030, 0.0105), (cz + 0.034, 0.0135), (ZB - 0.002, 0.0150), (ZB + 0.002, 0.0160)], "fer", cotes=12, ecrase_y=0.86,
         uv_tours=1.0)
    tour(P, [(cz - 0.042, 0.0050), (cz - 0.036, 0.0085)], "fer", cotes=8, bas=cz - 0.046, uv_tours=1.0)   # bouton de rivure
    tour(P, [(cz - 0.036, 0.0085), (cz - 0.033, 0.0060)], "fer", cotes=8, uv_tours=1.0)
    for s in (1, -1):
        octaedre(P, (0.0, s * 0.0128, cz), 0.0085, 0.0045, 0.0085, 0.0085, "rubis")
    P.creer()
    vide("prise", Z_PRISE)
    vide("garde", Z_RIC0 + 0.006)
    vide("pointe", Z_POINTE)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, "claymore_v4.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = 0
    zmin, zmax = 9.0, -9.0
    par = {}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            t = sum(len(p.vertices) - 2 for p in o.data.polygons)
            par[o.name] = t
            tris += t
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
    print("CLAYMORE_V4 tris=%d longueur=%.3f (%.3f -> %.3f) pieces=%s -> %s" % (tris, zmax - zmin, zmin, zmax, par, glb))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, "claymore_v4.blend"))


construire()
