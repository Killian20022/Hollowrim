# Look-dev « Guerrier nordique », échantillon C (essai de faisabilité, PAS l'intégration).
# Fourrure d'épaule en MÈCHES géométriques (lames en V effilées, 3 rangs) + bouclier rond modelé
# (5 planches séparées par des joints réels, une planche cassée, cerclage de fer, umbo).
# Repère Blender : Z haut, avant = -Y. Origine de la cape de fourrure = base du cou ; origine du bouclier = son centre.
# Usage : blender -b --python sources_blender/scripts/lookdev_guerrier_c.py
# Sortie : assets/modeles/lookdev/guerrier_c.glb (objets « fourrure_c », « bouclier_c »).
import bpy, bmesh, math, random, os
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.normpath(os.path.join(ICI, "..", "..", "assets", "modeles", "lookdev", "guerrier_c.glb"))

bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(7)


def materiau(nom):
    m = bpy.data.materials.get(nom) or bpy.data.materials.new(nom)
    return m


def objet(nom, bm, mats):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(materiau(m))
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ fourrure en mèches
RX, RY = 0.27, 0.175   # demi-axes de l'ellipse des épaules


def ell(a, s):
    return Vector((math.sin(a) * RX * s, -math.cos(a) * RY * s, 0.0))


def fourrure():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")

    def face(vs, uvs, cs, mat):
        f = bm.faces.new([bm.verts.new(v) for v in vs])
        f.material_index = mat
        for l, u, c in zip(f.loops, uvs, cs):
            l[uv].uv = u
            l[col] = (c, c, c, 1.0)
        return f

    # coque de dessous (fourrure sombre, cache les jours entre mèches) : 3 anneaux × 12 côtés
    anneaux = [(0.42, 0.03), (0.92, -0.06), (1.03, -0.15)]
    n = 12
    for k in range(len(anneaux) - 1):
        (s0, z0), (s1, z1) = anneaux[k], anneaux[k + 1]
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = 2 * math.pi * (i + 1) / n
            p = [ell(a0, s0) + Vector((0, 0, z0)), ell(a1, s0) + Vector((0, 0, z0)),
                 ell(a1, s1) + Vector((0, 0, z1)), ell(a0, s1) + Vector((0, 0, z1))]
            u = [((a0 / (2 * math.pi)) * 2.0, k * 0.15), ((a1 / (2 * math.pi)) * 2.0, k * 0.15),
                 ((a1 / (2 * math.pi)) * 2.0, (k + 1) * 0.15), ((a0 / (2 * math.pi)) * 2.0, (k + 1) * 0.15)]
            face(p, u, [0.55, 0.55, 0.45, 0.45], 1)

    # rangs de mèches : (échelle racine, z racine, échelle pointe, z pointe, nombre, largeur, teinte)
    rangs = [
        (0.95, -0.08, 1.11, -0.23, 24, 0.075, 0.80),
        (0.72, -0.03, 1.04, -0.15, 22, 0.080, 0.90),
        (0.46, 0.035, 0.84, -0.09, 18, 0.085, 1.00),
    ]
    tris = 0
    for (sr, zr, sp, zp, nb, w, t) in rangs:
        for i in range(nb):
            a = 2 * math.pi * (i + rng.uniform(-0.2, 0.2) + (0.5 if nb % 2 else 0.0) * 0) / nb
            longueur = rng.uniform(0.85, 1.2)
            p0 = ell(a, sr) + Vector((0, 0, zr))
            p2 = ell(a, sr + (sp - sr) * longueur) + Vector((0, 0, zr + (zp - zr) * longueur))
            p2 += Vector((rng.uniform(-0.015, 0.015), rng.uniform(-0.015, 0.015), 0))
            radial = Vector((math.sin(a) / RX, -math.cos(a) / RY, 0)).normalized()
            d = (p2 - p0)
            tang = Vector((-radial.y, radial.x, 0))
            nrm = tang.cross(d).normalized()
            if nrm.dot(radial) < 0:
                nrm = -nrm
            p1 = p0 + d * 0.55 + nrm * 0.03
            ww = w * rng.uniform(0.85, 1.15)
            def sec(p, wd, h):
                return [p - tang * wd / 2, p + nrm * wd * h, p + tang * wd / 2]
            s0 = sec(p0, ww, 0.3)
            s1 = sec(p1, ww * 0.75, 0.35)
            c = t * rng.uniform(0.9, 1.08)
            for j in range(2):
                face([s0[j], s0[j + 1], s1[j + 1], s1[j]],
                     [(j * 0.5, 0.0), ((j + 1) * 0.5, 0.0), ((j + 1) * 0.5, 0.55), (j * 0.5, 0.55)],
                     [c * 0.55, c * 0.62, c * 0.9, c * 0.85], 0)
                face([s1[j], s1[j + 1], p2],
                     [(j * 0.5, 0.55), ((j + 1) * 0.5, 0.55), (0.5, 1.0)],
                     [c * 0.85, c * 0.9, c * 1.0], 0)
                tris += 3
    print("MECHES", sum(r[4] for r in rangs), "triangles", tris)
    return objet("fourrure_c", bm, ["fourrure_meche", "fourrure_base"])


# ------------------------------------------------------------------ bouclier
R = 0.38
EP = 0.016


def bouclier():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")

    def face(vs, mat, uvs=None, c=1.0):
        f = bm.faces.new([bm.verts.new(v) for v in vs])
        f.material_index = mat
        for k, l in enumerate(f.loops):
            v = vs[k]
            l[uv].uv = uvs[k] if uvs else (v.x / (2 * R) + 0.5, 0.5 - v.z / (2 * R))
            l[col] = (c, c, c, 1.0)
        return f

    def dome(x, z):
        r2 = (x * x + z * z) / (R * R)
        return -EP - 0.022 * (1.0 - min(r2, 1.0))

    bords = [-R, -0.23, -0.075, 0.075, 0.23, R]
    jeu = 0.004
    for k in range(5):
        x0, x1 = bords[k] + jeu, bords[k + 1] - jeu
        # contour : arc haut de x0 à x1, arc bas de x1 à x0 (cercle de rayon R - 0.012, sous le cerclage)
        rr = R - 0.012
        pts = []
        N = 6
        for i in range(N + 1):
            x = x0 + (x1 - x0) * i / N
            x = max(-rr + 1e-4, min(rr - 1e-4, x))
            pts.append((x, math.sqrt(rr * rr - x * x)))
        bas = []
        for i in range(N + 1):
            x = x1 - (x1 - x0) * i / N
            x = max(-rr + 1e-4, min(rr - 1e-4, x))
            zb = -math.sqrt(rr * rr - x * x)
            if k == 3:   # planche cassée : un éclat manque en bas
                zb = max(zb, -rr * 0.78 + (x - x0) * 0.9)
            bas.append((x, zb))
        contour = pts + bas
        # dédoublonner
        propre = []
        for p in contour:
            if not propre or (abs(p[0] - propre[-1][0]) + abs(p[1] - propre[-1][1])) > 1e-4:
                propre.append(p)
        avant = [Vector((x, dome(x, z), z)) for (x, z) in propre]
        arriere = [Vector((x, 0.0, z)) for (x, z) in propre]
        face(avant, 0)
        face(list(reversed(arriere)), 0, None, 0.5)
        m = len(propre)
        for i in range(m):
            j = (i + 1) % m
            face([avant[j], avant[i], arriere[i], arriere[j]], 0, None, 0.45)

    # cerclage de fer : 16 segments, section rectangulaire qui pince le bord
    n = 16
    sec = [(R - 0.024, -EP - 0.012), (R + 0.006, -EP - 0.008), (R + 0.006, 0.006), (R - 0.02, 0.006)]
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        for s in range(4):
            (r0, y0), (r1, y1) = sec[s], sec[(s + 1) % 4]
            p = [Vector((math.cos(a0) * r0, y0, math.sin(a0) * r0)), Vector((math.cos(a1) * r0, y0, math.sin(a1) * r0)),
                 Vector((math.cos(a1) * r1, y1, math.sin(a1) * r1)), Vector((math.cos(a0) * r1, y1, math.sin(a0) * r1))]
            L = 2 * math.pi * R / n
            u = [(i * L * 4, s * 0.25), ((i + 1) * L * 4, s * 0.25), ((i + 1) * L * 4, (s + 1) * 0.25), (i * L * 4, (s + 1) * 0.25)]
            face(list(reversed(p)), 1, list(reversed(u)), 1.0 if s == 0 else 0.7)

    # umbo : calotte à 8 côtés + collerette
    n = 8
    anneaux = [(0.095, -0.040), (0.085, -0.055), (0.06, -0.085), (0.0, -0.10)]
    for k in range(len(anneaux) - 1):
        (r0, y0), (r1, y1) = anneaux[k], anneaux[k + 1]
        for i in range(n):
            a0 = 2 * math.pi * (i + 0.5) / n
            a1 = 2 * math.pi * (i + 1.5) / n
            p = [Vector((math.cos(a0) * r0, y0, math.sin(a0) * r0)), Vector((math.cos(a1) * r0, y0, math.sin(a1) * r0)),
                 Vector((math.cos(a1) * r1, y1, math.sin(a1) * r1)), Vector((math.cos(a0) * r1, y1, math.sin(a0) * r1))]
            u = [(0.2 + 0.6 * i / n, 0.1 + k * 0.25), (0.2 + 0.6 * (i + 1) / n, 0.1 + k * 0.25),
                 (0.2 + 0.6 * (i + 1) / n, 0.1 + (k + 1) * 0.25), (0.2 + 0.6 * i / n, 0.1 + (k + 1) * 0.25)]
            if r1 == 0.0:
                face([p[0], p[1], p[2]], 2, u[:3], 1.0)
            else:
                face(p, 2, u, 1.0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    print("BOUCLIER triangles", len(bm.faces))
    return objet("bouclier_c", bm, ["bois", "fer", "fer_umbo"])


f = fourrure()
b = bouclier()
b.location = (0.6, 0, 0)
os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=SORTIE, export_format="GLB", export_apply=True, export_yup=True,
                          export_vertex_color="ACTIVE", export_all_vertex_colors=True)
print("EXPORT", SORTIE)
