# Grotte v2 : MODULES ROCHEUX RÉUTILISABLES à silhouettes ANGULEUSES (enveloppes convexes de points tirés au hasard : grandes faces
# planes, arêtes vives, aucune bosse lisse), couleurs de sommets cuites (rgb = occlusion x palier de ton de la face, a = masque de givre).
#   blender.exe -b --python grotte_roches_v2.py
# Sortie : assets/grotte/modules/roches_v2.glb (un objet par gabarit : bloc_0..7, caillou_0..2, dalle_0..2, pan_0..3, roche_autel_0..1)
#          sources_blender/grotte_roches_v2.blend
# Repère des gabarits = celui de GrotteKit (Godot : y haut, +z hors du mur pour les pans, empreinte au sol de rayon 1, pied enfoncé de 6 cm).
# Le script calcule tout dans le repère Godot et convertit en Blender (x, -z, y) ; l'export glTF (Y haut) le remet à l'endroit.
# Rejouable : graines fixes. GrotteKit relit le .glb (sinon repli sur les gabarits générés par code).
import bpy, bmesh, math, os, random
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(BASE, "assets", "grotte", "modules", "roches_v2.glb")
BLEND = os.path.join(BASE, "sources_blender", "grotte_roches_v2.blend")
os.makedirs(os.path.dirname(SORTIE), exist_ok=True)

LUM = Vector((0.35, 0.8, 0.45)).normalized()
PALIER = [0.6, 0.8, 1.0]


def b_of_g(v):
    return Vector((v[0], -v[2], v[1]))


def coque_convexe(rg, n, taille, aplat_bas, aplat_haut, rot_y=0.0, bruit=(0.72, 1.28)):
    """Points tirés sur une sphère étirée (rayon 0,72 à 1,28), pied aplati : renvoie la liste des sommets (repère Godot)."""
    pts = []
    for _ in range(n):
        while True:
            v = Vector((rg.gauss(0, 1), rg.gauss(0, 1), rg.gauss(0, 1)))
            if v.length > 0.05:
                break
        v.normalize()
        v *= rg.uniform(*bruit)
        if v.y < -aplat_bas:
            v.y = -aplat_bas                       # pied plat : plusieurs points au même niveau -> grande face de base
        if v.y > aplat_haut:
            v.y = aplat_haut + (v.y - aplat_haut) * 0.4
        pts.append(Vector((v.x * taille[0], v.y * taille[1], v.z * taille[2])))
    c, s = math.cos(rot_y), math.sin(rot_y)
    return [Vector((p.x * c + p.z * s, p.y, -p.x * s + p.z * c)) for p in pts]


def hull_faces(pts):
    """Enveloppe convexe via bmesh : renvoie (sommets, triangles) dans le repère Godot."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(b_of_g(p))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    perdus = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if perdus:
        bmesh.ops.delete(bm, geom=list(set(perdus)), context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    verts = []
    idx = {}
    for v in bm.verts:
        idx[v.index] = len(verts)
        co = v.co
        verts.append(Vector((co.x, co.z, -co.y)))        # Blender -> Godot
    tris = [[idx[v.index] for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, tris


def normaliser_bloc(verts, enfoncement=0.06):
    """Empreinte au sol de rayon 1, pied à y = -enfoncement (comme GrotteKit._g_bloc)."""
    rmax = max(math.hypot(v.x, v.z) for v in verts)
    ymin = min(v.y for v in verts)
    return [Vector((v.x / rmax, (v.y - ymin) / rmax - enfoncement, v.z / rmax)) for v in verts]


def ajouter(objet_faces, verts, tris, graine, givre, centre, ymin, ymax, ao_bas=0.3):
    """Ajoute un îlot de faces PLATES avec ton par face (aplats) et givre sur les faces hautes."""
    rg = random.Random(graine + 91)
    for t in tris:
        a, b, c = (verts[i] for i in t)
        n = (b - a).cross(c - a)
        if n.length_squared < 1e-14:
            continue
        n.normalize()
        mid = (a + b + c) / 3.0
        if n.dot(mid - centre) < 0:
            n = -n
            t = [t[0], t[2], t[1]]
        lit = max(0.0, min(1.0, n.dot(LUM) * 0.5 + 0.5))
        pal = PALIER[max(0, min(2, int(lit * 3.0 + rg.uniform(-0.4, 0.4))))]
        # givre : seulement les faces tournées vers le haut
        fr = max(0.0, min(1.0, (n.y - 0.45) / 0.35)) * givre * rg.uniform(0.7, 1.15)
        al = (0.3 + fr * 0.95) if fr > 0.05 else 0.0
        tri = []
        for i in t:
            p = verts[i]
            h = (p.y - ymin) / max(ymax - ymin, 0.01)
            ao = (ao_bas + (1.0 - ao_bas) * (max(0.0, min(1.0, h)) ** 0.6)) * pal
            tri.append((p, (ao, ao * 0.99, ao * 1.02, al)))
        objet_faces.append((tri, n))


def creer_objet(nom, faces):
    """faces : [(([(Vector godot, rgba)] x3), normale)] -> objet Blender (sommets non partagés = ombrage plat)."""
    me = bpy.data.meshes.new(nom)
    vs, fs, cols = [], [], []
    for tri, n in faces:
        i0 = len(vs)
        for p, c in tri:
            vs.append(b_of_g(p))
            cols.append(c)
        fs.append((i0, i0 + 1, i0 + 2))
    me.from_pydata([tuple(v) for v in vs], [], fs)
    me.update()
    # sens des faces : la normale géométrique doit regarder vers l'extérieur (celle mémorisée, en repère Godot)
    for poly, (tri, n) in zip(me.polygons, faces):
        ng = Vector((n.x, -n.z, n.y))
        if poly.normal.dot(ng) < 0:
            poly.flip()
    me.update()
    ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            ca.data[li].color = cols[vi]
    me.color_attributes.active_color = ca
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bloc(graine, ecrase, etire, givre=1.0, aplat_haut=0.75, n=15):
    rg = random.Random(graine)
    pts = coque_convexe(rg, n, (etire, ecrase, 1.0), 0.3, aplat_haut, rg.random() * math.tau)
    verts, tris = hull_faces(pts)
    verts = normaliser_bloc(verts)
    ymin = min(v.y for v in verts)
    ymax = max(v.y for v in verts)
    centre = Vector((0, (ymax - ymin) * 0.4, 0))
    faces = []
    ajouter(faces, verts, tris, graine, givre, centre, ymin, ymax)
    return faces


def pan(graine):
    """3-4 dalles anguleuses empilées en gradins ; +z = hors du mur (même construction que GrotteKit._g_pan)."""
    rg = random.Random(graine)
    faces = []
    y = 0.0
    n = rg.randint(3, 4)
    for k in range(n):
        W = rg.uniform(0.6, 1.4) * (1.0 - 0.06 * k)
        Dp = rg.uniform(0.45, 0.95)
        H = rg.uniform(0.45, 1.1)
        pts = coque_convexe(rg, 13, (W, H * 0.6, Dp), 0.7, rg.uniform(0.35, 0.7), rg.uniform(-0.35, 0.35))
        verts, tris = hull_faces(pts)
        off = Vector((rg.uniform(-0.5, 0.5), y + H * 0.42, Dp * 0.2 + (n - k) * 0.1 * rg.uniform(0.3, 1.6)))
        verts = [v + off for v in verts]
        ys = [v.y for v in verts]
        ajouter(faces, verts, tris, graine + k, 1.0, off, min(ys), max(ys))
        y += H * rg.uniform(0.62, 0.8)
    return faces


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objets = []
    rg = random.Random(52031)
    for k in range(8):
        objets.append(creer_objet("bloc_%d" % k, bloc(7100 + k * 37, rg.uniform(0.55, 0.9), rg.uniform(1.0, 1.5))))
    for k in range(3):
        objets.append(creer_objet("caillou_%d" % k, bloc(7500 + k * 41, rg.uniform(0.5, 0.8), rg.uniform(1.0, 1.4), n=9)))
    for k in range(3):
        objets.append(creer_objet("dalle_%d" % k, bloc(7700 + k * 43, rg.uniform(0.26, 0.34), rg.uniform(1.2, 1.6), 1.7, 0.35, 12)))
    for k in range(4):
        objets.append(creer_objet("pan_%d" % k, pan(7900 + k * 53)))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objets:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_apply=False,
                              export_normals=True, export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True,
                              export_materials='NONE', export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("roches v2 :", len(objets), "objets ->", SORTIE)


main()
