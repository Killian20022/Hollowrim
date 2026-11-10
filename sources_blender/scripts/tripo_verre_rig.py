# Garde en ARMURE DE VERRE Tripo : un seul corps en T-pose (planche Tripo : figure de face à gauche, la même de dos à droite) -> garde animé
# sur le squelette nordique (65 os de homme_vetu.glb) + tabard à chaînes d'os, comme les gardes Tripo (tripo_rig.py).
#   blender.exe -b --python tripo_verre_rig.py -- [--source=<glb Tripo>] [--cache=<blend>] [--refaire] [--debug=<dossier>] [--blend=<ctl.blend>]
# Étapes : 0. figure de gauche seule (composantes), centrée, pieds à z=0, face -Y, échelle S (yeux du heaume à 1,70 m comme les humains) ;
#   1. bras allongés jusqu'aux articulations du squelette (les bras Tripo sont courts) : décalage le long du bras porté par les parties MOLLES
#      (manche noire, jointure des bracelets) ; épaulière, bracelets et gantelet gardent leur forme ; gantelet à 1,1x la main nue ;
#   2. soudure des sommets puis allègement ADAPTATIF (quadrique, symétrie X, mains protégées) ; UV neuves, atlas 512 recuit de la 4K
#      (couleur x relief de la carte normale) ;
#   3. squelette en T (celui des humains), jambes décalées en x sur les jambières (translation seule, clips inchangés) ; poids auto ;
#      tabard sur deux chaînes de 3 os (tab_f_*, tab_b_* : SpringBoneSimulator3D de GardeTripo) ; doigts pondérés à moitié sur les phalanges.
# Sortie : assets/pnj/tripo_garde_verre_rig.glb (texture empaquetée), lue par GardeTripo.creer("tripo_garde_verre").
# Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, kdtree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = arg("source", r"C:\Users\lopezk19\Downloads\fantasy armor 3d model (1).glb")
CACHE = arg("cache", os.path.join(os.environ.get("TEMP", "C:\\Temp"), "tripo_verre_bas.blend"))
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "pnj", "tripo_garde_verre_rig.glb"))
DEBUG = arg("debug", "")
S = float(arg("echelle", "3.09"))          # yeux du heaume (z source 0,55) à 1,70 m ; épaules à 1,46 (os des bras : 1,456)
TRIS = int(arg("tris", "7000"))
TEXN = int(arg("tex", "512"))
# décalage le long du bras (u = |x| à l'échelle, m) : nœuds (u source, décalage) ; pente forte = partie molle étirée
# v2 : l'épaulière est poussée un peu plus vers l'extérieur (épaules +2,5 cm de chaque côté), la manche noire sous elle s'allonge moins
NOEUDS = [(0.10, 0.0), (0.193, 0.045), (0.328, 0.07), (0.400, 0.12), (0.458, 0.12), (0.477, 0.165), (9.0, 0.165)]
PIVOT_MAIN, K_MAIN = 0.50, float(arg("k_main", "1.15"))   # gantelet agrandi autour de ce point de l'avant-bras (main nue +10 %)
J = [1.10, 0.86, 0.68, 0.50]                              # articulations du tabard (3 os) ; le bas est recalé sur le bord du tissu

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)
def pts(o):
    P = np.empty(len(o.data.vertices) * 3); o.data.vertices.foreach_get("co", P); return P.reshape(-1, 3)
def set_pts(o, P):
    o.data.vertices.foreach_set("co", P.astype(np.float32).ravel()); o.data.update()

# ================================================================ A. maillage préparé (lourd : mis en cache)
def preparer():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    src = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.ops.object.select_all(action="DESELECT"); src.select_set(True); bpy.context.view_layer.objects.active = src
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = src.data
    # --- 0. figure de gauche (x < 0) : composantes connexes par leur centre
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    lab = np.full(len(bm.verts), -1); k = 0; cx = []
    for v0 in bm.verts:
        if lab[v0.index] >= 0:
            continue
        st = [v0]; lab[v0.index] = k; s = 0.0; n = 0
        while st:
            v = st.pop(); s += v.co.x; n += 1
            for e in v.link_edges:
                w = e.other_vert(v)
                if lab[w.index] < 0:
                    lab[w.index] = k; st.append(w)
        cx.append(s / n); k += 1
    cx = np.array(cx)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if cx[lab[v.index]] >= 0], context="VERTS")
    bm.to_mesh(me); bm.free()
    P = pts(src)
    P -= np.array([(P[:, 0].min() + P[:, 0].max()) / 2, 0.0, P[:, 2].min()])
    P *= S
    # --- 1. bras allongés
    u = np.abs(P[:, 0]); sg = np.sign(P[:, 0])
    m_z = sstep(1.15, 1.25, P[:, 2])                      # seulement le haut du corps (la ceinture et les jambes ne bougent pas)
    nu = np.array([a for a, _ in NOEUDS]); no = np.array([b for _, b in NOEUDS])
    off = np.interp(u, nu, no) * m_z
    # axe du bras (y, z) mesuré sur les bracelets ; le gantelet est agrandi autour de cet axe
    for s_ in (1, -1):
        a = (sg == s_) & (u > 0.40) & (u < 0.52) & (P[:, 2] > 1.3)
        yc, zc = float(np.median(P[a, 1])), float(np.median(P[a, 2]))
        print("BRAS %+d : axe y %.3f z %.3f" % (s_, yc, zc))
        g = (sg == s_) & (u > PIVOT_MAIN) & (m_z > 0.5)
        P[g, 0] = s_ * (PIVOT_MAIN + (u[g] - PIVOT_MAIN) * K_MAIN)
        P[g, 1] = yc + (P[g, 1] - yc) * K_MAIN
        P[g, 2] = zc + (P[g, 2] - zc) * K_MAIN
    P[:, 0] += sg * off
    set_pts(src, P)
    src.name = "hd"; me.name = "hd"
    # --- 2. copie soudée et allégée
    bas = src.copy(); bas.data = me.copy(); bas.name = "verre"; bas.data.name = "verre"
    bpy.context.collection.objects.link(bas)
    bm = bmesh.new(); bm.from_mesh(bas.data)
    n0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(arg("soudure", "0.0015")))
    print("SOUDURE %d -> %d sommets ; arêtes de bord %d" % (n0, len(bm.verts), sum(1 for e in bm.edges if e.is_boundary)))
    bm.to_mesh(bas.data); bm.free()
    Pb = pts(bas)
    vg = bas.vertex_groups.new(name="protege")
    w = np.clip((np.abs(Pb[:, 0]) - 0.66) / 0.05, 0, 1) * (Pb[:, 2] > 1.2) * float(arg("p_main", "0.5"))     # mains (doigts)
    w = np.maximum(w, sstep(1.64, 1.70, Pb[:, 2]) * (np.abs(Pb[:, 0]) < 0.15) * 0.3)  # fente du heaume
    vg.add(list(range(len(Pb))), 0.0, "REPLACE")
    for i in np.nonzero(w > 0.01)[0]:
        vg.add([int(i)], float(w[i]), "REPLACE")
    avant = len(bas.data.polygons)
    md = bas.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = TRIS / avant
    md.use_collapse_triangulate = True; md.use_symmetry = True; md.symmetry_axis = "X"
    md.vertex_group = "protege"; md.invert_vertex_group = True; md.vertex_group_factor = float(arg("protege", "4.0"))   # inversé : poids 1 = protégé
    bpy.context.view_layer.objects.active = bas
    bpy.ops.object.modifier_apply(modifier=md.name)
    bas.vertex_groups.remove(bas.vertex_groups["protege"])
    bm = bmesh.new(); bm.from_mesh(bas.data)
    print("ALLEGE %d -> %d tris ; arêtes de bord %d ; non-variétés %d" % (avant, len(bas.data.polygons),
          sum(1 for e in bm.edges if e.is_boundary), sum(1 for e in bm.edges if not e.is_manifold)))
    bm.free()
    # --- UV neuves + atlas recuit
    while bas.data.uv_layers:
        bas.data.uv_layers.remove(bas.data.uv_layers[0])
    bas.data.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT"); bas.select_set(True); bpy.context.view_layer.objects.active = bas
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.006)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    mats = [m for m in me.materials if m]
    def image_src(cle):
        return next(nd.image for m in mats for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and cle in nd.image.name)
    img_src, img_nor = image_src("basecolor"), image_src("normal")
    img_nor.colorspace_settings.name = "Non-Color"
    uv_src = me.uv_layers[0].name
    mhd = bpy.data.materials.new("hd_cuisson"); mhd.use_nodes = True
    nt = mhd.node_tree; nt.nodes.clear()
    uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = uv_src
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img_src
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img_nor
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = uv_src
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    lv = nt.nodes.new("ShaderNodeVectorMath"); lv.operation = "ADD"; lv.inputs[1].default_value = (0, 0, float(arg("haut", "0.8")))
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "NORMALIZE"
    nt.links.new(geo.outputs["Normal"], lv.inputs[0]); nt.links.new(lv.outputs[0], ln.inputs[0])
    dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"; nt.links.new(ln.outputs[0], dp.inputs[1])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = -0.3; mr.inputs[2].default_value = 1.0
    mr.inputs[3].default_value = float(arg("ombre", "0.55")); mr.inputs[4].default_value = float(arg("lumiere", "1.3"))
    mu = nt.nodes.new("ShaderNodeMix"); mu.data_type = "RGBA"; mu.blend_type = "MULTIPLY"; mu.inputs[0].default_value = 1.0
    em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    for a, b in ((uvn.outputs["UV"], ti.inputs["Vector"]), (uvn.outputs["UV"], tn.inputs["Vector"]), (tn.outputs["Color"], nm.inputs["Color"]),
                 (nm.outputs["Normal"], dp.inputs[0]), (dp.outputs["Value"], mr.inputs[0]), (ti.outputs["Color"], mu.inputs[6]),
                 (mr.outputs[0], mu.inputs[7]), (mu.outputs[2], em.inputs["Color"]), (em.outputs[0], out.inputs[0])):
        nt.links.new(a, b)
    me.materials.clear(); me.materials.append(mhd)
    CUIT = bpy.data.images.new("verre_cuit", TEXN * 2, TEXN * 2)
    mat = bpy.data.materials.new("verre"); mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    cible = nt.nodes.new("ShaderNodeTexImage"); cible.image = CUIT; nt.nodes.active = cible
    em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], out.inputs[0])
    bas.data.materials.clear(); bas.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
    sc.render.bake.margin = 6; sc.render.bake.use_clear = True
    sc.render.bake.use_selected_to_active = True; sc.render.bake.cage_extrusion = 0.03; sc.render.bake.max_ray_distance = 0.08
    for o in bpy.data.objects:
        o.select_set(o in (bas, src))
    bpy.context.view_layer.objects.active = bas
    bpy.ops.object.bake(type="EMIT")
    CUIT.scale(TEXN, TEXN)
    CUIT.pack()
    nt.nodes.clear()
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = CUIT; ti.interpolation = "Closest"
    nt.links.new(ti.outputs["Color"], bs.inputs["Base Color"]); nt.links.new(bs.outputs[0], out.inputs[0])
    bs.inputs["Roughness"].default_value = 0.8
    bpy.data.objects.remove(src)
    for im in list(bpy.data.images):
        if im != CUIT:
            bpy.data.images.remove(im)
    bpy.ops.wm.save_as_mainfile(filepath=CACHE)
    print("CACHE", CACHE)

if "--refaire" in ARGS or not os.path.exists(CACHE):
    preparer()
bpy.ops.wm.open_mainfile(filepath=CACHE)
garde = bpy.data.objects["verre"]
me = garde.data
# verre émeraude DÉSATURÉ (palette nordique de la référence, pas fluo) : saturation x SAT, verts un peu assombris ; métal gris inchangé
CUIT = bpy.data.images["verre_cuit"]
px = np.array(CUIT.pixels[:]).reshape(-1, 4)
lum = px[:, :3] @ np.array([0.3, 0.59, 0.11])
SAT = float(arg("sat", "0.6"))
rgb = lum[:, None] + (px[:, :3] - lum[:, None]) * SAT
vert = np.clip((px[:, 1] - np.maximum(px[:, 0], px[:, 2])) * 4, 0, 1)
rgb *= (1 - (1 - float(arg("vert_k", "0.9"))) * vert)[:, None]
px[:, :3] = np.clip(rgb, 0, 1)
CUIT.pixels[:] = px.ravel(); CUIT.update(); CUIT.pack()
nv = len(me.vertices)
P = pts(garde)
x, y, z = P[:, 0], P[:, 1], P[:, 2]
print("maillage :", nv, "sommets,", len(me.polygons), "tris")

# ================================================================ B. squelette (T des humains), jambes recalées
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
corps = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("SuperHero"))
CP = np.array([corps.matrix_world @ v.co for v in corps.data.vertices])
B0 = {b.name: (np.array((arm.matrix_world @ b.head_local)[:]), np.array((arm.matrix_world @ b.tail_local)[:])) for b in arm.data.bones}

# ---------------------------------------------------------------- gantelets : la main nue du squelette (doigts séparés, pouce, poids faits pour
# les clips : elle se referme en poing) habillée en gantelet : épaissie autour de ses os (x GANT_R), un peu allongée au bout des doigts,
# texture propre 128 px (phalanges en plaques d'acier noirci à liseré gris, dos de main en verre émeraude, paume en cuir sombre)
DOIGTS_N = ("index", "middle", "ring", "pinky", "thumb")
def gantelets():
    src = corps
    gn_ = {g.index: g.name for g in src.vertex_groups}
    bm = bmesh.new(); bm.from_mesh(src.data); bm.verts.ensure_lookup_table()
    dl = bm.verts.layers.deform.verify()
    def dom(v):
        d = v[dl]
        return gn_[max(d.items(), key=lambda kv: kv[1])[0]] if d else ""
    garder = set()
    for v in bm.verts:
        n = dom(v)
        if abs(v.co.x) > float(arg("gant_x0", "0.69")) and v.co.z > 1.3 and (n.startswith(("hand_", "lowerarm_")) or n.startswith(DOIGTS_N)):
            garder.add(v.index)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in garder], context="VERTS")
    me_g = bpy.data.meshes.new("gantelets"); bm.to_mesh(me_g); bm.free()
    g = bpy.data.objects.new("gantelets", me_g); bpy.context.collection.objects.link(g)
    for vg in src.vertex_groups:
        g.vertex_groups.new(name=vg.name)
    # (to_mesh garde les poids : couche deform recopiée)
    G = np.array([v.co[:] for v in me_g.vertices])
    gnm = {vg.index: vg.name for vg in g.vertex_groups}
    W = [{gnm[e.group]: e.weight for e in v.groups if e.weight > 1e-4} for v in me_g.vertices]
    R = float(arg("gant_r", "1.25")); L = float(arg("gant_l", "1.06"))
    G2 = G.copy(); seg = []
    for i, w in enumerate(W):
        q = np.zeros(3); tot = 0.0; best = ("", 0.0, 0.0)
        for n, wt in w.items():
            if n not in B0:
                continue
            a, b = B0[n]; ab = b - a; t = float(np.clip((G[i] - a) @ ab / (ab @ ab), 0, 1))
            q += (a + t * ab) * wt; tot += wt
            if wt > best[1]:
                best = (n, wt, t)
        if tot <= 0:
            seg.append(best); continue
        q /= tot
        r = R
        if best[0].startswith(("hand_", "lowerarm_")):
            r = 1.0 + (R - 1.0) * 0.8
            # manchette évasée qui remonte dans le canon d'avant-bras : pas de jour au poignet quand la main plie
            hx = abs(float(B0["hand_" + ("l" if G[i][0] > 0 else "r")][0][0])); x0 = float(arg("gant_x0", "0.69"))
            r += float(arg("manchette", "0.25")) * float(np.clip((hx - abs(G[i][0])) / max(hx - x0, 1e-3), 0, 1))
        d = G[i] - q
        G2[i] = q + d * r
        # bout des doigts un peu allongé (gantelet)
        if best[0].endswith(("_03_l", "_03_r")):
            a, b = B0[best[0]]
            G2[i] += (b - a) * (L - 1.0) * best[2] * 2.0
        seg.append(best)
    me_g.vertices.foreach_set("co", G2.astype(np.float32).ravel()); me_g.update()
    # UV et texture
    TG = 128
    img = bpy.data.images.new("gantelet", TG, TG)
    pxg = np.zeros((TG, TG, 4)); pxg[..., 3] = 1
    rng = np.random.default_rng(3)
    acier, acier_c, liseré, joint = np.array([0.36, 0.38, 0.38]), np.array([0.58, 0.61, 0.60]), np.array([0.80, 0.82, 0.80]), np.array([0.02, 0.02, 0.02])
    vert_f, vert_c = np.array([0.07, 0.20, 0.12]), np.array([0.22, 0.42, 0.30])
    for yy in range(TG):
        for xx in range(TG):
            u, v = (xx + 0.5) / TG, (yy + 0.5) / TG
            if u < 0.5:            # doigts : 3 plaques le long du doigt (joints noirs entre elles) ; dos (u<0,25) acier clair bombé, paume cuir
                f = (v * 3) % 1.0
                dos = u < 0.25
                lat = abs((u % 0.25) / 0.25 - 0.5) * 2          # 0 au milieu du doigt, 1 sur les flancs
                if dos:
                    c = acier + (acier_c - acier) * (1 - abs(f - 0.45) * 2) * (1 - 0.6 * lat)
                    if f < 0.12 or f > 0.90:
                        c = joint
                    elif f < 0.22:
                        c = liseré
                else:
                    c = (np.array([0.20, 0.15, 0.11]) if 0.12 < f < 0.90 else joint)
            elif u < 0.78:         # dos de la main : plaque de verre à facettes, liseré gris
                uu, vv = (u - 0.5) / 0.28, v
                fac = (abs(((uu * 3 + vv * 2) % 1.0) - 0.5) < 0.06) or (abs(((uu * 3 - vv * 2) % 1.0) - 0.5) < 0.06)
                c = vert_f + (vert_c - vert_f) * (0.6 if fac else 0.0) + (vert_c - vert_f) * 0.25 * vv
                if uu < 0.08 or uu > 0.92 or vv < 0.06 or vv > 0.94:
                    c = liseré
                if uu < 0.03 or uu > 0.97 or vv < 0.02 or vv > 0.98:
                    c = joint
            else:                  # paume : cuir sombre
                c = np.array([0.14, 0.12, 0.10])
            pxg[yy, xx, :3] = np.clip(c * (0.92 + 0.16 * rng.random()), 0, 1)
    img.pixels[:] = pxg.ravel(); img.pack()
    while me_g.uv_layers:                 # les UV du corps (copiées avec la main) passeraient avant les nôtres
        me_g.uv_layers.remove(me_g.uv_layers[0])
    uvl = me_g.uv_layers.new(name="UVMap")
    me_g.uv_layers.active = uvl; uvl.active_render = True
    me_g.calc_loop_triangles()
    ordre_d = {n: k for k, n in enumerate(DOIGTS_N)}
    # classe GÉOMÉTRIQUE de chaque sommet (les poids du corps donnent la base des doigts à la main) : au-delà des jointures (ou près du
    # pouce) -> phalange la plus proche ; sinon dos / paume de la main
    cls = []
    for i in range(len(G)):
        c_ = G[i]; s_ = "l" if c_[0] > 0 else "r"
        jx = abs(float(B0["index_01_" + s_][0][0]))
        best = (None, 9.0, 0.0)
        for f in DOIGTS_N:
            for k in (1, 2, 3):
                n = "%s_0%d_%s" % (f, k, s_)
                a_, b_ = B0[n]; ab = b_ - a_; t = float(np.clip((c_ - a_) @ ab / (ab @ ab), 0, 1))
                d = float(np.linalg.norm(c_ - (a_ + t * ab)))
                if d < best[1]:
                    best = (n, d, t)
        pouce = best[0].startswith("thumb") and best[1] < 0.022
        if (abs(c_[0]) > jx - 0.004 and best[1] < 0.03) or pouce:
            cls.append(best)
        else:
            cls.append((None, 0.0, 0.0))
    for poly in me_g.polygons:
        n_up = poly.normal.z > 0.0
        fs = [cls[me_g.loops[li].vertex_index][0] for li in poly.loop_indices]
        doigt = next((f for f in fs if f is not None), None)
        tout_doigt = all(f is not None for f in fs)
        for li in poly.loop_indices:
            vi = me_g.loops[li].vertex_index
            n, d, t = cls[vi]
            if doigt is not None and (tout_doigt or n is not None):
                n = n or doigt
                k = int(n.split("_")[1]) - 1                 # 01, 02, 03 -> 0, 1, 2
                fd = ordre_d[n.split("_")[0]]
                a_, b_ = B0[n]; ab = b_ - a_
                pr = a_ + float(np.clip((G[vi] - a_) @ ab / (ab @ ab), 0, 1)) * ab
                lat = float(np.clip((G[vi][1] - pr[1]) / 0.011, -1, 1))   # travers du doigt (y en T-pose)
                u0 = 0.0 if n_up else 0.25
                uvl.data[li].uv = (u0 + 0.125 + 0.11 * lat, (k + float(np.clip(t, 0.0, 1.0))) / 3.0)
            else:                                             # main : projection plane (le long de la main, en travers)
                sg_ = 1 if G[vi][0] > 0 else -1
                a = B0["hand_" + ("l" if sg_ > 0 else "r")][0]
                ux = np.clip((abs(G[vi][0]) - abs(a[0]) + 0.02) / 0.13, 0, 1)
                uy = np.clip((G[vi][1] - a[1] + 0.06) / 0.12, 0, 1)
                uvl.data[li].uv = ((0.51 + 0.26 * uy) if n_up else (0.80 + 0.18 * uy), 0.04 + 0.92 * ux)
    mt = bpy.data.materials.new("gantelet"); mt.use_nodes = True
    nt = mt.node_tree; bs = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img; ti.interpolation = "Closest"
    nt.links.new(ti.outputs["Color"], bs.inputs["Base Color"])
    me_g.materials.append(mt)
    print("GANTELETS : %d sommets, %d tris (main nue x%.2f en épaisseur, bouts x%.2f)" % (len(me_g.vertices), len(me_g.loop_triangles), R, L))
    return g
# profondeur : le torse de l'armure centré sur celui du corps (z 1,15..1,40)
def centre_y(Q):
    s = (Q[:, 2] > 1.15) & (Q[:, 2] < 1.40) & (np.abs(Q[:, 0]) < 0.12)
    return (Q[s, 1].min() + Q[s, 1].max()) / 2
dy = centre_y(CP) - centre_y(P)
P[:, 1] += dy
print("PROFONDEUR : armure décalée de %.3f en y" % dy)
# bras : axe du bras Tripo (bracelets) recalé en profondeur sur les os du bras (sinon le gantelet du squelette sort du canon) ;
# fondu de l'épaule (u 0,15 -> 0,30) : l'épaulière suit, le torse reste en place
for s_, sg in (("l", 1), ("r", -1)):
    a = (sg * P[:, 0] > 0.50) & (sg * P[:, 0] < 0.68) & (P[:, 2] > 1.3)
    ya = float(np.median(P[a, 1]))
    yo = float((B0["lowerarm_" + s_][0][1] + B0["hand_" + s_][0][1]) / 2)
    k = sstep(0.15, 0.30, sg * P[:, 0]) * sstep(1.15, 1.25, P[:, 2])
    P[:, 1] += (yo - ya) * k
    print("BRAS %s : axe en y %.3f -> os %.3f" % (s_, ya, yo))
# main Tripo (bloc décimé, doigts soudés, hors des os des doigts) retirée au-delà du poignet ; remplacée plus bas par le gantelet
GANT_X = float(arg("gant_x", "0.716"))
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
for i, v in enumerate(bm.verts):
    v.co = Vector(P[i])
bmesh.ops.delete(bm, geom=[v for v in bm.verts if abs(v.co.x) > GANT_X and v.co.z > 1.3], context="VERTS")
bm.to_mesh(me); bm.free(); me.update()
nv = len(me.vertices); P = pts(garde); x, y, z = P[:, 0], P[:, 1], P[:, 2]
print("MAIN TRIPO retirée : reste %d sommets, %d tris" % (nv, len(me.polygons)))
gant = gantelets()
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in (garde, gant, corps):
        bpy.data.objects.remove(o)
def jambe_x(sg):
    cuisse = P[(z > 0.55) & (z < 0.75) & (sg * x > 0.03) & (np.abs(x) < 0.30)]
    botte = P[(z > 0.04) & (z < 0.30) & (sg * x > 0.03) & (np.abs(x) < 0.32)]
    return (abs(float(np.median(cuisse[:, 0]))) + abs(float(np.median(botte[:, 0])))) / 2.0
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for s, sg in (("l", 1), ("r", -1)):
    d = jambe_x(sg) - 0.114
    print("jambe", s, "décalage x : %.3f" % d)
    for nom in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        eb = arm.data.edit_bones[nom + "_" + s]
        eb.head.x += sg * d; eb.tail.x += sg * d
bpy.ops.object.mode_set(mode="OBJECT")
DOIGTS = ("index_", "middle_", "pinky_", "ring_", "thumb_")
for b in arm.data.bones:
    n = b.name
    b.use_deform = not (n == "root" or n.endswith("_leaf_l") or n.endswith("_leaf_r"))
B = {b.name: (np.array((arm.matrix_world @ b.head_local)[:]), np.array((arm.matrix_world @ b.tail_local)[:])) for b in arm.data.bones}

# ================================================================ C. poids du corps : transférés du CORPS HUMAIN du squelette (homme_vetu, poids faits
# pour les clips) : 12 plus proches sommets du corps, pondérés en 1/d². (La chaleur directe échoue sur les plaques Tripo à une face, et
# celle d'un double voxel n'est pas fiable.) Jambes et mains sont reprises plus bas par zones.
cnoms = [g.name for g in corps.vertex_groups]
CW = np.zeros((len(corps.data.vertices), len(cnoms)))
for v in corps.data.vertices:
    for e in v.groups:
        CW[v.index, e.group] = e.weight
kdc = kdtree.KDTree(len(CP))
for i, p in enumerate(CP):
    kdc.insert(Vector(p), i)
kdc.balance()
body = []
for i in range(nv):
    acc = np.zeros(len(cnoms))
    for co, j, d in kdc.find_n(Vector(P[i]), 12):
        acc += CW[j] / (d + 0.01) ** 2
    if z[i] < 1.0:
        autre = "_r" if x[i] > 0 else "_l"
        acc *= np.array([0.0 if (n.endswith(autre) and n.startswith(("thigh", "calf", "foot", "ball"))) else 1.0 for n in cnoms])
    t_ = acc.sum() or 1.0
    body.append({cnoms[j]: acc[j] / t_ for j in np.nonzero(acc / t_ > 1e-3)[0]})
bpy.data.objects.remove(corps)
garde.parent = arm
garde.matrix_parent_inverse = Matrix.Identity(4)
for md in list(garde.modifiers):
    garde.modifiers.remove(md)
md = garde.modifiers.new("Armature", "ARMATURE"); md.object = arm
garde.parent = arm
garde.matrix_parent_inverse = Matrix.Identity(4)
for md in list(garde.modifiers):
    garde.modifiers.remove(md)
md = garde.modifiers.new("Armature", "ARMATURE"); md.object = arm

def dseg(Q, a, b):
    ab = b - a; t = np.clip(((Q - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(Q - (a + t[:, None] * ab), axis=1)
# mains : poids géométriques (la chaleur mélange les doigts ouverts) ; paume -> hand ; doigts -> phalanges à K_PH (le reste hand) ;
# avant-bras -> lowerarm ; fondu court au poignet
K_PH = float(arg("phalanges", "0.7"))
for s_, sg in (("l", 1), ("r", -1)):
    wr = B["hand_" + s_][0]
    wx = abs(float(wr[0]))
    main = (sg * x > wx - 0.03) & (z > 1.25)
    idx = np.nonzero(main)[0]
    Q = P[idx]
    t = sstep(wx - 0.03, wx + 0.01, sg * Q[:, 0])                 # 0 avant-bras, 1 main
    noms = [f + "_0%d_%s" % (k, s_) for f in ("index", "middle", "ring", "pinky", "thumb") for k in (1, 2, 3)]
    D = np.stack([dseg(Q, B[n][0], B[n][1]) for n in noms] + [dseg(Q, B["hand_" + s_][0], B["hand_" + s_][1])], 1)
    W_ = 1.0 / (D + 0.006) ** 4; W_ /= W_.sum(1, keepdims=True)
    for k, i in enumerate(idx):
        w = {}
        if t[k] < 0.999:
            w["lowerarm_" + s_] = 1 - t[k]
        ph = W_[k, :-1] * K_PH
        w["hand_" + s_] = t[k] * (W_[k, -1] + (1 - K_PH) * W_[k, :-1].sum())
        for j, n in enumerate(noms):
            if ph[j] * t[k] > 0.02:
                w[n] = ph[j] * t[k]
        body[i] = w
print("MAINS : poids géométriques posés")

# jambes : poids par zones, nets et par côté (la chaleur du double étirait la pointe des bottes et une ailette du genou) :
# tassettes -> bassin + cuisse ; cuisse -> genou (fondu court) -> mollet -> cheville -> pied -> orteils (ball)
for s_, sg in (("l", 1), ("r", -1)):
    idx = np.nonzero((sg * x > 0) & (z < 1.05))[0]
    Q = P[idx]
    genou = B["calf_" + s_][0][2]; chev = float(arg("cheville_z", "0.13")); bally = B["ball_" + s_][0][1]
    w_cuisse = sstep(genou - 0.04, genou + 0.05, Q[:, 2])
    w_pied = 1 - sstep(chev - 0.03, chev + 0.03, Q[:, 2])
    w_ball = sstep(bally + 0.02, bally - 0.02, Q[:, 1]) * w_pied
    w_bassin = sstep(0.86, 1.0, Q[:, 2]) * (0.4 + 0.3 * sstep(0.09, 0.16, sg * Q[:, 0]))
    for k, i in enumerate(idx):
        w = {}
        wc = w_cuisse[k]; wp = w_pied[k]
        w["pelvis"] = w_bassin[k]
        w["thigh_" + s_] = wc * (1 - w_bassin[k])
        w["calf_" + s_] = (1 - wc) * (1 - wp)
        w["foot_" + s_] = (1 - wc) * (wp - w_ball[k])
        w["ball_" + s_] = (1 - wc) * w_ball[k]
        w = {n_: v_ for n_, v_ in w.items() if v_ > 1e-4}
        t_ = sum(w.values()) or 1.0
        body[i] = {n_: v_ / t_ for n_, v_ in w.items()}
print("JAMBES : poids par zones")

# ================================================================ D. tabard (devant / derrière) : deux chaînes de 3 os
c = ((np.abs(x) < float(arg("tab_l", "0.085"))) & (z < 1.12) & (z > 0.40)).astype(float)
# seulement les pans (en avant / en arrière des cuisses) : pas l'entrejambe
yt = centre_y(P)
c *= sstep(0.03, 0.07, np.abs(y - yt))
c *= np.clip((1.12 - z) / 0.06, 0, 1)
sel = c > 0.5
J[-1] = max(float(z[sel].min()) + 0.03, 0.30) if sel.any() else J[-1]
J = [J[0]] + [J[0] + (J[-1] - J[0]) * k / 3.0 for k in (1, 2, 3)]
print("tabard : %d sommets ; articulations %s" % (int(sel.sum()), [round(v, 2) for v in J]))
def y_pan(zz, face):
    s = (c > 0.5) & (np.abs(z - zz) < 0.08) & ((y < yt) if face else (y > yt))
    if not s.any():
        return yt - 0.15 if face else yt + 0.15
    return float(y[s].min()) + 0.03 if face else float(y[s].max()) - 0.03
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for tag, face in (("f", True), ("b", False)):
    parent = arm.data.edit_bones["pelvis"]
    for k in range(3):
        eb = arm.data.edit_bones.new("tab_%s_%d" % (tag, k + 1))
        eb.head = Vector((0.0, y_pan(J[k], face), J[k])); eb.tail = Vector((0.0, y_pan(J[k + 1], face), J[k + 1]))
        eb.parent = parent; eb.use_connect = False; eb.use_deform = True
        parent = eb
bpy.ops.object.mode_set(mode="OBJECT")
zc_ = [(J[k] + J[k + 1]) / 2 for k in range(3)]
def poids_tabard(i):
    zi = z[i]; vz = [0.0] * 3
    if zi >= zc_[0]:
        vz[0] = 1.0
    elif zi <= zc_[2]:
        vz[2] = 1.0
    else:
        for k in range(2):
            if zc_[k + 1] <= zi <= zc_[k]:
                t = (zi - zc_[k + 1]) / (zc_[k] - zc_[k + 1]); vz[k], vz[k + 1] = t, 1 - t; break
    dos = float(y[i] > yt)
    w = {}
    for k in range(3):
        if vz[k] > 1e-4:
            w[("tab_b_%d" if dos else "tab_f_%d") % (k + 1)] = vz[k]
    return w

final = []
for i in range(nv):
    ci = float(c[i]); w = {}
    if ci < 0.999:
        for n_, v_ in body[i].items():
            w[n_] = w.get(n_, 0.0) + v_ * (1 - ci)
    if ci > 0.001:
        for n_, v_ in poids_tabard(i).items():
            w[n_] = w.get(n_, 0.0) + v_ * ci
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(v for _, v in top) or 1.0
    final.append([(n_, v / tot) for n_, v in top if v / tot > 0.015])
for g in list(garde.vertex_groups):
    garde.vertex_groups.remove(g)
groupes = {}
for i, lst in enumerate(final):
    for n_, v_ in lst:
        if n_ not in groupes:
            groupes[n_] = garde.vertex_groups.new(name=n_)
        groupes[n_].add([i], v_, "REPLACE")
print("groupes :", len(groupes))

if DEBUG:
    os.makedirs(DEBUG, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "verre_rig.blend"), copy=True)
garde.name = "tripo_garde_verre"; arm.name = "Armature"
if arg("blend"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("blend"), copy=True)
for o in bpy.context.selected_objects:
    o.select_set(False)
gant.parent = arm; gant.matrix_parent_inverse = Matrix.Identity(4)
mg = gant.modifiers.new("Armature", "ARMATURE"); mg.object = arm
arm.select_set(True); garde.select_set(True); gant.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_skins=True, export_animations=False, export_apply=False)
print("EXPORT OK", OUT_GLB, "tris", len(me.polygons), "os", len(arm.data.bones))
