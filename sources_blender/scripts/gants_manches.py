# Lot 6 (graphisme) : gants, brassards et manches du bras FPS. (1) UV cylindriques autour de l'axe du bras (au lieu de l'atlas
# du personnage, inexploitable) : u = tour du bras (raccord sous le bras), v = le long du bras, cuff/poignet en bas pour les
# manches et brassards, poignet en haut pour le gant ; (2) manchette de fourrure au poignet (anneau hirsute, pondéré entre
# l'avant-bras et la main : suit la torsion sans fissure) ; (3) rivets de fer sur les brassards.
#   blender.exe -b --python gants_manches.py     (ré-exporte assets/modeles/joueur/bras_fps.glb ; état d'avant : bras_fps_lot1.glb)
import bpy, bmesh, math, os, shutil
base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # racine du worktree
glb = os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_lot1.glb")
if not os.path.exists(SAUVE):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.name == "Icosphere":
        bpy.data.objects.remove(o)
obj = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
YC, ZC = 0.065, 1.456            # axe du bras (os lowerarm / hand)

def theta(y, z):
    return math.atan2(y - YC, z - ZC)

# ---------------------------------------------------------------- 0. fente du dessous (lot 6bis)
# Les manches et brassards d'origine sont des tubes OUVERTS : une fente d'un à deux centimètres court sous le bras (z < axe, y ~ axe),
# là où passe le raccord des UV ; elle laissait voir la sous-couche sombre (« trait noir » au dos / dessous des manches, pli du coude en
# frappe). On soude les sommets de bord des deux lèvres puis on rebouche ce qui reste.
def souder_fente(o, dist=0.03):
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    def fente(v):
        return (v.co.z < ZC - 0.065 and abs(v.co.y - YC) < 0.045 and 0.19 < abs(v.co.x) < 0.62
                and any(e.is_boundary for e in v.link_edges))
    av = len([e for e in bm.edges if e.is_boundary])
    vs = [v for v in bm.verts if fente(v)]
    bmesh.ops.remove_doubles(bm, verts=vs, dist=dist)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges[:])
    bm.verts.ensure_lookup_table()
    reste = [e for e in bm.edges if e.is_boundary and all(fente(v) for v in e.verts)]
    if reste:
        bmesh.ops.holes_fill(bm, edges=reste, sides=6)
    ap = len([e for e in bm.edges if e.is_boundary])
    bm.to_mesh(me); bm.free()
    print("fente", o.name, "arêtes de bord", av, "->", ap)

souder_fente(obj["manches"])
souder_fente(obj["brassards"])

# ---------------------------------------------------------------- 1. UV cylindriques
def uv_cyl(o, v_wrist_bottom):
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    for s in (1, -1):
        vs = [v for v in bm.verts if (v.co.x > 0) == (s > 0)]
        xs = [abs(v.co.x) for v in vs]
        xmin, xmax = min(xs), max(xs)
        L = max(xmax - xmin, 1e-6)
        for f in bm.faces:
            if (f.calc_center_median().x > 0) != (s > 0):
                continue
            u0 = None
            for lo in f.loops:
                u = theta(lo.vert.co.y, lo.vert.co.z) / (2 * math.pi) + 0.5
                if u0 is None:
                    u0 = u
                while u - u0 > 0.5: u -= 1.0
                while u - u0 < -0.5: u += 1.0
                t = (abs(lo.vert.co.x) - xmin) / L          # 0 = côté épaule/poignet intérieur, 1 = extrémité
                v = (1.0 - t) if v_wrist_bottom else t       # v Blender 0 = bas de l'image
                lo[layer].uv = (u, v)
    bm.to_mesh(me); bm.free()
    xs = [abs(v.co.x) for v in me.vertices]
    print(o.name, "x", round(min(xs), 3), round(max(xs), 3))

# manches et brassards : poignet (extrémité) en bas de l'image ; gant : poignet en haut
uv_cyl(obj["manches"], True)
uv_cyl(obj["brassards"], True)
uv_cyl(obj["gants"], False)

# rayon moyen du brassard près du poignet
br = obj["brassards"].data
proche = [v for v in br.vertices if 0.66 < abs(v.co.x) < 0.71]
R = sum(math.hypot(v.co.y - YC, v.co.z - ZC) for v in proche) / max(len(proche), 1)
xmin_br = min(abs(v.co.x) for v in br.vertices)
print("rayon brassard au poignet", round(R, 4), "brassard x min", round(xmin_br, 3))

# ---------------------------------------------------------------- 2. manchette de fourrure + 3. rivets
def h(i, j):
    x = (i * 73856093) ^ (j * 19349663)
    x = (x ^ (x >> 13)) * 1274126177
    return ((x ^ (x >> 16)) & 0xffff) / 65535.0

def materiau(nom):
    return bpy.data.materials.get(nom) or bpy.data.materials.new(nom)

def creer(nom, mat, verts, faces, uvs, groupes, cote):
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bv = [bm.verts.new(v) for v in verts]
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in faces:
        try:
            bf = bm.faces.new([bv[i] for i in f])
        except ValueError:
            continue
        bf.smooth = True
        for lo, i in zip(bf.loops, f):
            lo[uvl].uv = uvs[i]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    me.materials.append(materiau(mat))
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = arm
    for g, w in groupes:
        vg = o.vertex_groups.new(name=g)
    # poids : tous les sommets 100 % répartis selon `groupes` (liste de (os, poids))
    for v in me.vertices:
        for g, w in groupes:
            o.vertex_groups[g].add([v.index], w, 'REPLACE')
    mod = o.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
    return o

SEG = 22
for s, c in ((1, "l"), (-1, "r")):
    # --- manchette : 6 stations, rayon de la fourrure = brassard + 8 mm, hérissée (rayon et hauteur jitterés)
    xs = [0.668, 0.684, 0.702, 0.720, 0.736, 0.748]
    rad = [0.004, 0.011, 0.015, 0.014, 0.008, -0.004]
    verts, uvs, faces = [], [], []
    for k, (x, dr) in enumerate(zip(xs, rad)):
        for i in range(SEG):
            a = 2 * math.pi * i / SEG
            j = (h(i * 7 + k, 11 + (0 if c == "l" else 5)) - 0.5) * 0.010 + (0.004 if i % 2 == 0 else 0.0)
            r = R + 0.008 + dr + j
            dx = (h(i, k + 3) - 0.5) * 0.006
            verts.append((s * (x + dx), YC + r * math.sin(a), ZC + r * math.cos(a)))
            uvs.append((i / SEG * 2.0, 1.0 - k / (len(xs) - 1)))
    for k in range(len(xs) - 1):
        for i in range(SEG):
            j = (i + 1) % SEG
            f = [k * SEG + i, k * SEG + j, (k + 1) * SEG + j, (k + 1) * SEG + i]
            faces.append(f if s > 0 else f[::-1])
    creer("fourrure_" + c, "fourrure", verts, faces, uvs, [("lowerarm_" + c, 0.5), ("hand_" + c, 0.5)], c)
    # --- rivets : deux rangées de 8 sur le brassard
    rv, rf, ru = [], [], []
    for xr in (xmin_br + 0.025, xmin_br + 0.062):
        for i in range(8):
            a = 2 * math.pi * (i + (0.5 if xr > xmin_br + 0.04 else 0.0)) / 8
            cx = s * xr
            cy = YC + (R + 0.0015) * math.sin(a)
            cz = ZC + (R + 0.0015) * math.cos(a)
            base_i = len(rv)
            rr = 0.0042
            # petit dôme à 6 pans (pointe vers l'extérieur)
            nrm = (0.0, math.sin(a), math.cos(a))
            t1 = (1.0, 0.0, 0.0)
            t2 = (0.0, math.cos(a), -math.sin(a))
            rv.append((cx + nrm[0] * rr * 0.8, cy + nrm[1] * rr * 0.8, cz + nrm[2] * rr * 0.8)); ru.append((0.5, 0.5))
            for q in range(6):
                b = 2 * math.pi * q / 6
                rv.append((cx + (t1[0] * math.cos(b) + t2[0] * math.sin(b)) * rr,
                           cy + (t1[1] * math.cos(b) + t2[1] * math.sin(b)) * rr,
                           cz + (t1[2] * math.cos(b) + t2[2] * math.sin(b)) * rr))
                ru.append((0.5 + math.cos(b) * 0.1, 0.5 + math.sin(b) * 0.1))
            for q in range(6):
                tri = [base_i, base_i + 1 + q, base_i + 1 + (q + 1) % 6]
                rf.append(tri if s > 0 else tri[::-1])
    creer("rivets_" + c, "fer", rv, rf, ru, [("lowerarm_" + c, 1.0)], c)

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=False, export_apply=False)
print("EXPORT OK")
