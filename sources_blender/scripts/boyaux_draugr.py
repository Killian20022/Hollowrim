# Boyaux procéduraux basse résolution (gore, étape 2 : coupe en deux) — Blender en ligne de commande :
#   C:\Users\lopezk19\Outils\blender\blender.exe -b --python sources_blender/scripts/boyaux_draugr.py
# Deux objets dans assets/modeles/gore/boyaux.glb :
#   - BoyauxPendants : 3 anses qui pendent sous le moignon (origine = la coupe, elles descendent le long de -Y Godot) ;
#   - BoyauxTas : un tas enroulé posé au sol (origine au sol, ~45 cm de large, 7 cm de haut).
# Tubes à 6 pans, bosselés (anneaux), COULEURS DE SOMMET en palette (chair desséchée brun-rose du draugr, sillons sombres,
# reflets clairs) ; la teinte du bandit (plus rouge) est donnée en jeu par le matériau. Pas de texture.
import bpy, bmesh, math, os, random

DEPOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "gore", "boyaux.glb")
PANS = 6
PALETTE = [(0.478, 0.290, 0.243), (0.361, 0.188, 0.157), (0.561, 0.369, 0.290), (0.420, 0.235, 0.200)]
SILLON = (0.227, 0.110, 0.086)
REFLET = (0.690, 0.478, 0.400)


def srgb_lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def tube(bm, col, points, rayon, rng):
    """Tube à PANS pans le long de `points` ; rayon bosselé (anneaux) ; couleurs par anneau."""
    anneaux = []
    n = len(points)
    for i, p in enumerate(points):
        a = points[min(i + 1, n - 1)]
        b = points[max(i - 1, 0)]
        t = [a[k] - b[k] for k in range(3)]
        lt = math.sqrt(sum(x * x for x in t)) or 1.0
        t = [x / lt for x in t]
        ref = (0, 0, 1) if abs(t[2]) < 0.9 else (1, 0, 0)
        u = [t[1] * ref[2] - t[2] * ref[1], t[2] * ref[0] - t[0] * ref[2], t[0] * ref[1] - t[1] * ref[0]]
        lu = math.sqrt(sum(x * x for x in u)) or 1.0
        u = [x / lu for x in u]
        v = [t[1] * u[2] - t[2] * u[1], t[2] * u[0] - t[0] * u[2], t[0] * u[1] - t[1] * u[0]]
        r = rayon * (1.0 + 0.28 * math.sin(i * 2.1)) * (0.6 if i in (0, n - 1) else 1.0)
        bord = i % 3 == 0
        c = SILLON if bord else rng.choice(PALETTE)
        anneau = []
        for k in range(PANS):
            ang = 2 * math.pi * k / PANS
            q = [p[j] + (u[j] * math.cos(ang) + v[j] * math.sin(ang)) * r for j in range(3)]
            vert = bm.verts.new(q)
            anneau.append((vert, REFLET if (k == 1 and not bord) else c))
        anneaux.append(anneau)
    for i in range(n - 1):
        for k in range(PANS):
            a0, ca0 = anneaux[i][k]
            a1, ca1 = anneaux[i][(k + 1) % PANS]
            b1, cb1 = anneaux[i + 1][(k + 1) % PANS]
            b0, cb0 = anneaux[i + 1][k]
            f = bm.faces.new((a0, a1, b1, b0))
            for loop, c in zip(f.loops, (ca0, ca1, cb1, cb0)):
                loop[col] = (*srgb_lin(c), 1.0)
    # bouts fermés
    for anneau in (anneaux[0], anneaux[-1]):
        f = bm.faces.new([a for a, _ in anneau])
        for loop in f.loops:
            loop[col] = (*srgb_lin(SILLON), 1.0)


def objet(nom, construire):
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    construire(bm, col)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def pendants(bm, col):
    rng = random.Random(7)
    for s, (longueur, phase, boucle) in enumerate([(0.42, 0.0, True), (0.30, 2.1, False), (0.36, 4.0, True)]):
        pts = []
        n = 16
        for i in range(n):
            t = i / (n - 1)
            if boucle:
                # anse : descend puis remonte un peu (U), pendue sous la coupe
                z = -longueur * math.sin(t * math.pi * 0.85)
                x = 0.09 * (t - 0.5) * 2 + 0.03 * math.sin(t * 7 + phase)
            else:
                z = -longueur * t
                x = 0.035 * math.sin(t * 6 + phase)
            y = 0.04 * math.cos(t * 5 + phase) + (s - 1) * 0.035
            pts.append((x + (s - 1) * 0.03, y, z))
        tube(bm, col, pts, 0.022, rng)


def tas(bm, col):
    rng = random.Random(11)
    for s in range(3):
        pts = []
        n = 26
        r0 = 0.06 + s * 0.035
        for i in range(n):
            t = i / (n - 1)
            ang = t * math.pi * 2.6 + s * 1.7
            r = r0 + 0.11 * t
            pts.append((math.cos(ang) * r, math.sin(ang) * r, 0.022 + 0.03 * math.sin(t * 9 + s) * (1 - t) + s * 0.012))
        tube(bm, col, pts, 0.024, rng)


def construire():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    a = objet("BoyauxPendants", pendants)
    b = objet("BoyauxTas", tas)
    b.location = (0.0, 0.0, 0.0)
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    opts = dict(filepath=SORTIE, export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True, use_selection=False)
    try:
        bpy.ops.export_scene.gltf(**opts, export_vertex_color='ACTIVE')
    except TypeError:
        bpy.ops.export_scene.gltf(**opts, export_colors=True)
    tris = sum(len(p.vertices) - 2 for o in (a, b) for p in o.data.polygons)
    print("BOYAUX tris=%d -> %s" % (tris, SORTIE))


construire()
