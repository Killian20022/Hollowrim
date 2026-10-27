# Avant-bras du bras FPS façon héros de Skarnholt (référence references/combat_epee/tenue_epee_droite_1100.jpg) : sur la
# manche et le petit brassard du lot 6, un VRAI brassard d'avant-bras en cuir sombre (coque à facettes, bourrelets aux deux
# bouts), trois lames de fer articulées sur le dessus (canon d'avant-bras) fixées par des rivets, deux sangles de cuir
# avec boucle de fer, un revers de fourrure sombre côté coude ; la manchette de fourrure du poignet est retirée (elle
# cachait le poing).
#   blender.exe -b --python brassards_skarnholt.py      (ré-exporte assets/modeles/joueur/bras_fps.glb ; état d'avant :
#   sources_blender/bras_fps_lot6.glb, gardé la première fois)
# Matières (habillées par mains.gd, _materiaux_equipement) : brassard_cuir, sangle, fer, fourrure_sombre.
import bpy, bmesh, math, os, shutil
from mathutils import Vector

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_lot6.glb")
if not os.path.exists(SAUVE):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.name == "Icosphere":
        bpy.data.objects.remove(o)
obj = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}

U0, U1 = 0.50, 0.700          # brassard : du tiers du coude au poignet (|x| le long du bras)
SEG = 16                      # facettes de la coque (rendu PS1 : arêtes nettes)


def h(i, j):
    x = (i * 73856093) ^ (j * 19349663)
    x = (x ^ (x >> 13)) * 1274126177
    return ((x ^ (x >> 16)) & 0xffff) / 65535.0


def axe(c):
    """Axe de l'avant-bras (os lowerarm) : centre (y, z) en fonction de u = |x|."""
    b = arm.data.bones["lowerarm_" + c]
    a, t = b.head_local, b.tail_local
    def centre(u):
        k = (u - abs(a.x)) / (abs(t.x) - abs(a.x))
        return a.y + (t.y - a.y) * k, a.z + (t.z - a.z) * k
    return centre


def profil(c, centre):
    """Rayon extérieur des habits existants (manche, brassard, peau) par tranche de 1 cm le long de l'avant-bras."""
    s = 1 if c == "l" else -1
    pts = []
    for nom in ("manches", "brassards", "peau_bras"):
        o = obj.get(nom)
        if o is None:
            continue
        for v in o.data.vertices:
            if v.co.x * s > 0:
                pts.append(v.co.copy())
    def rayon(u):
        cy, cz = centre(u)
        rs = [math.hypot(p.y - cy, p.z - cz) for p in pts if abs(abs(p.x) - u) < 0.012]
        return max(rs) if rs else 0.045
    return rayon


def materiau(nom):
    return bpy.data.materials.get(nom) or bpy.data.materials.new(nom)


def creer(nom, mat, verts, faces, uvs, poids, lisse=False):
    """Maillage pondéré : poids(v) -> [(os, w)]."""
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bv = [bm.verts.new(v) for v in verts]
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in faces:
        try:
            bf = bm.faces.new([bv[i] for i in f])
        except ValueError:
            continue
        bf.smooth = lisse
        for lo, i in zip(bf.loops, f):
            lo[uvl].uv = uvs[i]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(materiau(mat))
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = arm
    for v in me.vertices:
        for g, w in poids(v.co):
            vg = o.vertex_groups.get(g) or o.vertex_groups.new(name=g)
            vg.add([v.index], w, 'REPLACE')
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    return o


def anneau(stations, centre, s, seg, a0=0.0, a1=2 * math.pi, ferme=True, bruit=None):
    """Tube le long de l'avant-bras : stations = [(u, rayon)], secteur angulaire [a0, a1]. Renvoie verts, faces, uvs."""
    verts, uvs, faces = [], [], []
    n = seg if ferme else seg + 1
    for k, (u, r) in enumerate(stations):
        cy, cz = centre(u)
        for i in range(n):
            a = a0 + (a1 - a0) * i / seg
            rr = r + (bruit(i, k) if bruit else 0.0)
            verts.append((s * u, cy + rr * math.sin(a), cz + rr * math.cos(a)))
            uvs.append((i / seg * (a1 - a0) / math.pi, k / max(len(stations) - 1, 1)))
    for k in range(len(stations) - 1):
        for i in range(seg if ferme else seg):
            j = (i + 1) % n if ferme else i + 1
            f = [k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i]
            faces.append(f if s > 0 else f[::-1])
    return verts, faces, uvs


def boite(c0, ax, ay, az, dx, dy, dz):
    """Pavé centré en c0 d'axes ax, ay, az (unitaires) et de demi-côtés dx, dy, dz."""
    vs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                vs.append(tuple(c0[i] + ax[i] * dx * sx + ay[i] * dy * sy + az[i] * dz * sz for i in range(3)))
    fs = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return vs, fs, [(0.5, 0.5)] * 8


for c in ("l", "r"):
    s = 1 if c == "l" else -1
    centre = axe(c)
    rayon = profil(c, centre)

    def poids_avant_bras(co):
        u = abs(co.x)
        k = min(max((u - 0.675) / 0.03, 0.0), 1.0) * 0.35   # le bout du poignet suit un peu la main
        return [("lowerarm_" + c, 1.0 - k), ("hand_" + c, k)] if k > 0 else [("lowerarm_" + c, 1.0)]

    # --- 1. coque de cuir à facettes, évasée vers le coude, bourrelets aux deux bouts
    us = [U0, U0 + 0.006, U0 + 0.016, 0.56, 0.60, 0.64, U1 - 0.016, U1 - 0.006, U1]
    ep = [0.007, 0.012, 0.009, 0.008, 0.008, 0.007, 0.007, 0.010, 0.006]
    st = [(u, rayon(u) + e) for u, e in zip(us, ep)]
    v, f, uv = anneau(st, centre, s, SEG)
    creer("brassard_" + c, "brassard_cuir", v, f, uv, poids_avant_bras)

    # --- 2. canon d'avant-bras : trois lames de fer articulées sur le dessus (secteur de 150°, côté dos de la main)
    dos = 0.0                 # +z = dos de l'avant-bras (paume vers le bas dans la pose de repos du squelette)
    lames = [(0.525, 0.575), (0.580, 0.630), (0.635, 0.680)]
    for n, (ua, ub) in enumerate(lames):
        st = []
        for u in (ua, ua + 0.004, ub - 0.004, ub):
            bord = 0.0 if u in (ua, ub) else 0.003
            st.append((u, rayon(u) + 0.011 + bord))
        v, f, uv = anneau(st, centre, s, 6, dos - math.radians(75), dos + math.radians(75), ferme=False)
        creer("canon_%s_%d" % (c, n), "fer", v, f, uv, poids_avant_bras)
        # rivets aux deux coins de chaque lame
        rv, rf, ru = [], [], []
        for a in (dos - math.radians(62), dos + math.radians(62)):
            u = (ua + ub) * 0.5
            cy, cz = centre(u)
            r = rayon(u) + 0.0155
            nrm = Vector((0.0, math.sin(a), math.cos(a)))
            t1 = Vector((1.0, 0.0, 0.0))
            t2 = Vector((0.0, math.cos(a), -math.sin(a)))
            ctr = Vector((s * u, cy + r * nrm.y, cz + r * nrm.z))
            b0 = len(rv)
            rv.append(tuple(ctr + nrm * 0.003)); ru.append((0.5, 0.5))
            for q in range(6):
                b = 2 * math.pi * q / 6
                rv.append(tuple(ctr + (t1 * math.cos(b) + t2 * math.sin(b)) * 0.0045)); ru.append((0.5, 0.5))
            for q in range(6):
                tri = [b0, b0 + 1 + q, b0 + 1 + (q + 1) % 6]
                rf.append(tri if s > 0 else tri[::-1])
        creer("rivets_canon_%s_%d" % (c, n), "fer", rv, rf, ru, poids_avant_bras)

    # --- 3. deux sangles de cuir (sous le canon, visibles sur les côtés) et leur boucle de fer
    for n, u in enumerate((0.545, 0.655)):
        st = [(u - 0.007, rayon(u) + 0.012), (u - 0.005, rayon(u) + 0.0145), (u + 0.005, rayon(u) + 0.0145),
              (u + 0.007, rayon(u) + 0.012)]
        v, f, uv = anneau(st, centre, s, SEG)
        creer("sangle_%s_%d" % (c, n), "sangle", v, f, uv, poids_avant_bras)
        a = math.radians(105) * s * -1   # boucle sur le côté du pouce
        cy, cz = centre(u)
        r = rayon(u) + 0.0175
        nrm = Vector((0.0, math.sin(a), math.cos(a)))
        t2 = Vector((0.0, math.cos(a), -math.sin(a)))
        ctr = Vector((s * u, cy + r * nrm.y, cz + r * nrm.z))
        v, f, uv = boite(ctr, (1, 0, 0), tuple(t2), tuple(nrm), 0.009, 0.011, 0.003)
        creer("boucle_%s_%d" % (c, n), "fer", v, f, uv, poids_avant_bras)

    # --- 4. revers de fourrure sombre côté coude (anneau hirsute qui déborde du brassard)
    us = [U0 - 0.035, U0 - 0.022, U0 - 0.008, U0 + 0.004, U0 + 0.012]
    dr = [0.004, 0.016, 0.022, 0.018, 0.006]
    st = [(u, rayon(u) + d) for u, d in zip(us, dr)]
    def bruit(i, k, c=c):
        return (h(i * 5 + k, 23 if c == "l" else 41) - 0.5) * 0.012 + (0.005 if (i + k) % 2 == 0 else 0.0)
    v, f, uv = anneau(st, centre, s, 20, bruit=bruit)
    def poids_coude(co, c=c):
        return [("lowerarm_" + c, 0.75), ("upperarm_" + c, 0.25)]
    creer("revers_" + c, "fourrure_sombre", v, f, uv, poids_coude, lisse=True)

# manchette de fourrure du poignet retirée : vue de derrière l'avant-bras, elle cachait le poing (la référence montre
# le gant entier sur la poignée, la fourrure est au coude)
for c in ("l", "r"):
    o = obj.get("fourrure_" + c)
    if o is not None:
        bpy.data.objects.remove(o)

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=False, export_apply=False)
print("EXPORT OK", glb)
