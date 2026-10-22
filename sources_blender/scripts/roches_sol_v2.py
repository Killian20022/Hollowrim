# Extérieurs v2 : rochers organiques de la portion témoin du chemin (docs/DIAGNOSTIC_SOL.md).
#   blender.exe -b --python roches_sol_v2.py
# Sortie : assets/modeles/roches_sol_v2.glb (+ .dat relu par SolV2, format de grotte_roches_v2.py) et sources_blender/roches_sol_v2.blend
# Chaque rocher : enveloppe convexe de points tirés au hasard (grandes facettes), sous-divisée une fois puis déplacée par un bruit
# (arêtes irrégulières, crevasses), pied enfoncé de 6 cm, ORIGINE AU PIED. Couleurs de sommets : rgb = occlusion (pied sombre, creux
# sombres), a = masque de neige (0 = neige sur les faces tournées vers le ciel, corniches et replats, poussées de 2-3 cm vers l'extérieur).
# Le matériau du jeu est TexturesBati.m_roche() (triplanaire en mètres) : aucune UV nécessaire.
import bpy, bmesh, math, os, random, struct
from mathutils import Vector, noise

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(BASE, "assets", "modeles", "roches_sol_v2.glb")
DAT = os.path.join(BASE, "assets", "modeles", "roches_sol_v2.dat")
BLEND = os.path.join(BASE, "sources_blender", "roches_sol_v2.blend")
DONNEES = {}


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def rocher(nom, graine, taille, npts=34, aplat_bas=0.5, plat_haut=0.0, neige=1.0, strates=0.0):
    rg = random.Random(graine)
    pts = []
    for _ in range(npts):
        v = Vector((rg.gauss(0, 1), rg.gauss(0, 1), rg.gauss(0, 1)))
        v.normalize()
        v *= rg.uniform(0.7, 1.25)
        if v.z < -aplat_bas:
            v.z = -aplat_bas
        if plat_haut > 0 and v.z > plat_haut:
            v.z = plat_haut + (v.z - plat_haut) * 0.25
        pts.append(Vector((v.x * taille[0], v.y * taille[1], v.z * taille[2])))
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    perdus = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if perdus:
        bmesh.ops.delete(bm, geom=list(set(perdus)), context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # sous-division + bruit : arêtes irrégulières, bosses, crevasses de strate
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    off = Vector((graine * 0.37, graine * 0.11, graine * 0.23))
    for v in bm.verts:
        n = v.normal
        d = noise.fractal(v.co * 2.2 + off, 0.5, 2.0, 3) * 0.10 * max(taille)
        if strates > 0:
            d += math.sin((v.co.z + off.x) * 9.0 + noise.noise(v.co * 1.5 + off) * 2.0) * strates * 0.03 * max(taille)
        v.co += n * d
    zmin = min(v.co.z for v in bm.verts)
    zmax = max(v.co.z for v in bm.verts)
    bm.normal_update()
    # neige : seuil de pente bruité, poussée vers l'extérieur
    for v in bm.verts:
        nz = v.normal.z
        seuil = 0.50 + 0.30 * noise.noise(v.co * 3.1 + off)
        if neige > 0 and nz > seuil and v.co.z > zmin + 0.3 * (zmax - zmin):
            v.co += v.normal * 0.025 * neige
    bm.normal_update()
    # pied enfoncé de 6 cm, origine au pied
    zmin = min(v.co.z for v in bm.verts)
    dec = -(zmin + 0.06)
    for v in bm.verts:
        v.co.z += dec
    zmax = max(v.co.z for v in bm.verts)
    tris = []
    for f in bm.faces:
        for lo in f.loops:
            v = lo.vert
            nz = v.normal.z
            seuil = 0.50 + 0.30 * noise.noise(Vector(v.co.x, v.co.y, v.co.z - dec) * 3.1 + off) if False else 0.50 + 0.30 * noise.noise((v.co - Vector((0, 0, dec))) * 3.1 + off)
            neige_v = neige > 0 and nz > seuil and (v.co.z - dec) > zmin + 0.3 * (zmax - dec - zmin)
            h = (v.co.z + 0.06) / max(zmax + 0.06, 0.01)
            ao = 0.60 + 0.40 * smooth(0.0, 0.7, h)
            ao *= 0.88 + 0.12 * noise.noise(v.co * 4.0 + off)
            tris.append((v.co.copy(), (ao, ao, ao, 0.0 if neige_v else 1.0)))
    bm.free()
    DONNEES[nom] = [((p.x, p.z, -p.y), c) for p, c in tris]   # repère Godot (y haut)
    me = bpy.data.meshes.new(nom)
    vs = [p for p, _ in tris]
    fs = [(i, i + 1, i + 2) for i in range(0, len(vs), 3)]
    me.from_pydata([tuple(v) for v in vs], [], fs)
    me.update()
    ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:
            ca.data[li].color = tris[li][1]
    me.color_attributes.active_color = ca
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = [
        rocher("roche_A", 11, (0.75, 0.62, 0.55), 30, 0.45, 0.0, 1.0, 1.0),     # gros bloc arrondi
        rocher("roche_B", 23, (0.46, 0.38, 0.30), 24, 0.5, 0.0, 1.0, 0.0),      # bloc moyen
        rocher("roche_C", 37, (0.95, 0.60, 0.24), 28, 0.4, 0.15, 1.2, 1.0),     # dalle plate, replat enneigé
        rocher("roche_D", 41, (0.22, 0.18, 0.15), 16, 0.5, 0.0, 0.8, 0.0),      # caillou
        rocher("roche_E", 53, (0.50, 0.42, 0.70), 26, 0.3, 0.0, 0.9, 1.0),      # pointe / affleurement
        rocher("roche_F", 67, (0.30, 0.26, 0.20), 18, 0.5, 0.0, 1.0, 0.0),      # pierre moyenne
    ]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_apply=False,
                              export_normals=True, export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True,
                              export_materials='NONE', export_yup=True)
    with open(DAT, "wb") as f:   # [u32 nb][u8 longueur][nom][u32 nb sommets][x y z r g b a float32] x sommets (3 par triangle), repère Godot
        f.write(struct.pack("<I", len(DONNEES)))
        for nom, verts in DONNEES.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(verts)))
            for p, c in verts:
                f.write(struct.pack("<7f", p[0], p[1], p[2], c[0], c[1], c[2], c[3]))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("roches sol v2 :", {k: len(v) // 3 for k, v in DONNEES.items()})


main()
