"""Bake du relief (AO + cavité + arêtes) des persos Gardien et Troll — passe Blender, sans fenêtre.
   blender -b --python bake_persos.py -- <gardien|troll> <export.json> <dossier_sortie> [reglages.json]
Entrée : JSON écrit par outils/_bake_export.gd (maillages au repos, UV Godot, nom de texture).
Sortie (par texture cible) : bake_<tex>.png = masque de niveaux en 8 bits (0 neutre / 64 ombre / 128 creux / 192 arête claire),
        _dbg_<tex>_{ao,cav,arete}.png = cartes continues (contrôle), _occlusion_<tex>.png = couverture unique (1) ou partagée (0).
Le masque est ensuite QUANTIFIÉ dans la palette de la texture par scripts/bake_relief.gd (aplats, jamais de normal map ni de Bayer).
Repère : Godot (x, y, z) -> Blender (x, -z, y) ; UV : v -> 1 - v ; ordre des indices inversé (Godot = sens horaire)."""
import bpy, bmesh, json, sys, os
import numpy as np

arg = sys.argv[sys.argv.index("--") + 1:]
QUI, SRC, OUT = arg[0], arg[1], arg[2]
os.makedirs(OUT, exist_ok=True)

# réglages par perso : distances en m (repère du modèle final), seuils sur L = mélange AO large / petite
REG = {
    "gardien": {"cibles": {"accessoires": 2, "decoupes": 2}, "d_large": 0.18, "d_petit": 0.03, "d_arete": 0.012,
                "excl": ["Hair_Long", "Hair_Beard"], "t_arete_cible": {"decoupes": 0.525}, "t_creux": 0.40, "t_ombre": 0.70, "t_arete": 0.58, "t_arete_l": 0.80},
    "troll": {"cibles": {"peau": 1}, "d_large": 0.30, "d_petit": 0.05, "d_arete": 0.020,
              "excl": [], "t_creux": 0.40, "t_ombre": 0.70, "t_arete": 0.58, "t_arete_l": 0.80},
}[QUI]
if len(arg) > 3 and os.path.exists(arg[3]):
    REG.update(json.load(open(arg[3])))
SUPER = REG.get("super", 2)           # suréchantillonnage de la cuisson (moyenné ensuite à la résolution de la texture)
ECH = {"samples": 48}

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = ECH["samples"]
sc.cycles.use_denoising = False
sc.render.bake.margin = 6
sc.render.bake.margin_type = "EXTEND"
sc.view_settings.view_transform = "Standard"

data = json.load(open(SRC))
objs = []
for k, o in enumerate(data):
    if o["mesh"] in REG["excl"] or o["tex"] in ("yeux", "meches") or (QUI == "troll" and o["tex"] == "accessoires"):
        continue
    v = np.array(o["v"], dtype=np.float64).reshape(-1, 3)
    vb = np.stack([v[:, 0], -v[:, 2], v[:, 1]], 1)
    idx = np.array(o["i"], dtype=np.int64).reshape(-1, 3)[:, ::-1]
    n_g = np.array(o["n"], dtype=np.float64).reshape(-1, 3) if o["n"] else None
    if n_g is not None and o["tex"] == "decoupes":
        # cartes de tissu à double face : normales orientées hors du corps (axe vertical du perso), sinon l'AO se mesure côté intérieur
        rad = np.stack([v[:, 0], np.zeros(len(v)), v[:, 2]], 1)
        flip = (rad * n_g).sum(1) < 0
        n_g[flip] *= -1
    if n_g is not None:
        # sens des triangles aligné sur les normales (face visible = côté de la normale)
        e1 = v[idx[:, 1]] - v[idx[:, 0]]; e2 = v[idx[:, 2]] - v[idx[:, 0]]
        fn = np.cross(e1, e2)                       # dans le repère Godot ; les indices sont déjà inversés
        nm = n_g[idx].sum(1)
        bad = (fn * nm).sum(1) < 0                  # CCW vu de l'extérieur -> fn sort avec la normale
        idx[bad] = idx[bad][:, ::-1]
    uv = np.array(o["uv"], dtype=np.float64).reshape(-1, 2) if o["uv"] else np.zeros((len(v), 2))
    me = bpy.data.meshes.new(f"{o['mesh']}_{o['surf']}")
    me.from_pydata(vb.tolist(), [], idx.tolist())
    me.update()
    uvl = me.uv_layers.new(name="UV")
    loops_v = np.array([l.vertex_index for l in me.loops])
    uvb = uv[loops_v].copy()
    uvb[:, 1] = 1.0 - uvb[:, 1]
    uvl.data.foreach_set("uv", uvb.ravel())
    if o["n"]:
        n = n_g
        nb = np.stack([n[:, 0], -n[:, 2], n[:, 1]], 1)
        try:
            me.normals_split_custom_set_from_vertices(nb.tolist())
        except Exception as e:
            print("normales perso : ", e)
    ob = bpy.data.objects.new(me.name, me)
    sc.collection.objects.link(ob)
    ob["tex"], ob["tw"], ob["th"], ob["uvs"] = o["tex"], o["tw"], o["th"], uvb.tolist()
    ob["mesh"], ob["surf"] = o["mesh"], o["surf"]
    objs.append((ob, o, idx, uv))
print("objets :", [(ob.name, ob["tex"]) for ob, *_ in objs])

# --- couverture unique : îlots (composantes connexes par sommets) ; texel couvert par 2 îlots -> partagé -> neutre
def ilots(idx, nv):
    p = list(range(nv))
    def f(a):
        while p[a] != a:
            p[a] = p[p[a]]; a = p[a]
        return a
    for a, b, c in idx:
        ra, rb, rc = f(a), f(b), f(c)
        p[rb] = ra; p[rc] = ra
    return np.array([f(int(i[0])) for i in idx])

def couverture(idx, uv, W, H):
    il = ilots(idx, len(uv))
    own = np.full((H, W), -1, dtype=np.int64)
    multi = np.zeros((H, W), dtype=bool)
    for t, (a, b, c) in enumerate(idx):
        pa, pb, pc = uv[a] * [W, H], uv[b] * [W, H], uv[c] * [W, H]
        x0 = max(int(np.floor(min(pa[0], pb[0], pc[0]) - 1)), 0); x1 = min(int(np.ceil(max(pa[0], pb[0], pc[0]) + 1)), W - 1)
        y0 = max(int(np.floor(min(pa[1], pb[1], pc[1]) - 1)), 0); y1 = min(int(np.ceil(max(pa[1], pb[1], pc[1]) + 1)), H - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (pb[1] - pc[1]) * (pa[0] - pc[0]) + (pc[0] - pb[0]) * (pa[1] - pc[1])
        if abs(d) < 1e-9:
            continue
        w0 = ((pb[1] - pc[1]) * (xs - pc[0]) + (pc[0] - pb[0]) * (ys - pc[1])) / d
        w1 = ((pc[1] - pa[1]) * (xs - pc[0]) + (pa[0] - pc[0]) * (ys - pc[1])) / d
        w2 = 1 - w0 - w1
        ins = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not ins.any():
            continue
        sub = own[y0:y1 + 1, x0:x1 + 1]
        msub = multi[y0:y1 + 1, x0:x1 + 1]
        autre = ins & (sub >= 0) & (sub != il[t])
        msub |= autre
        sub[ins & (sub < 0)] = il[t]
    return own >= 0, multi

def mat_emission(ob, img, mode, dist):
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if mode == "arete":
        # courbure : Pointiness de Cycles (0,5 = plat, > 0,5 convexe = arête claire, < 0,5 concave)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        nt.links.new(geo.outputs["Pointiness"], em.inputs["Color"])
    else:
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = dist
        ao.samples = 16
        nt.links.new(ao.outputs["AO"], em.inputs["Color"])
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    nt.nodes.active = tx
    ob.data.materials.clear()
    ob.data.materials.append(mat)

def soudee(ob):
    me = ob.data.copy()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me); bm.free()
    cp = bpy.data.objects.new(ob.name + "_soudee", me)
    sc.collection.objects.link(cp)
    return cp

def cuire(ob, W, H, mode, dist):
    if mode == "arete":
        cp = soudee(ob)
        ob.hide_render = True
        try:
            return cuire_brut(cp, W, H, mode, dist)
        finally:
            ob.hide_render = False
            bpy.data.objects.remove(cp)
    return cuire_brut(ob, W, H, mode, dist)

def cuire_brut(ob, W, H, mode, dist):
    img = bpy.data.images.new(f"b_{ob.name}_{mode}", W, H, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    mat_emission(ob, img, mode, dist)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="EMIT")
    px = np.empty(W * H * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(H, W, 4)[:, :, 0][::-1].copy()      # ligne 0 = haut de l'image (comme Godot)

def reduire(a, k):
    if k == 1:
        return a
    h, w = a.shape
    return a.reshape(h // k, k, w // k, k).mean((1, 3))

def sauver_png(nom, arr):
    h, w = arr.shape
    img = bpy.data.images.new(nom, w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((h, w, 4), dtype=np.float32)
    g = np.clip(arr, 0, 1)[::-1]
    rgba[:, :, 0] = g; rgba[:, :, 1] = g; rgba[:, :, 2] = g
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(OUT, nom + ".png")
    img.file_format = "PNG"
    img.save()

cibles = [t for t in objs if t[1]["tex"] in REG["cibles"]]
for ob, o, idx, uv in cibles:
    nom = o["tex"]
    W, H = o["tw"], o["th"]
    cov, multi = couverture(idx, uv, W, H)
    unique = cov & ~multi
    print(f"[{nom}] {W}x{H} couvert {cov.mean():.2%} partagé {multi.mean():.2%}")
    k = SUPER
    ao_l = reduire(cuire(ob, W * k, H * k, "ao", REG["d_large"]), k)
    ao_p = reduire(cuire(ob, W * k, H * k, "ao", REG["d_petit"]), k)
    ed = reduire(cuire(ob, W * k, H * k, "arete", REG["d_arete"]), k)
    L = 0.5 * ao_l + 0.5 * ao_p
    niv = np.zeros((H, W), dtype=np.uint8)
    niv[unique & (L < REG["t_ombre"])] = 1
    niv[unique & (L < REG["t_creux"])] = 2
    print(f"[{nom}] pointiness percentiles 5/25/50/75/95 :", np.percentile(ed[unique], [5, 25, 50, 75, 95]).round(3))
    niv[unique & (ed > REG.get("t_arete_cible", {}).get(nom, REG["t_arete"])) & (ao_p > 0.9) & (L > REG["t_arete_l"])] = 3
    n = max(int(unique.sum()), 1)
    print(f"[{nom}] niveaux : ombre {np.mean(niv[unique]==1):.1%} creux {np.mean(niv[unique]==2):.1%} arête {np.mean(niv[unique]==3):.1%}  L moy {L[unique].mean():.2f}  arête moy {ed[unique].mean():.2f}")
    sauver_png(f"_dbg_{nom}_ao", ao_l * unique)
    sauver_png(f"_dbg_{nom}_cav", ao_p * unique)
    sauver_png(f"_dbg_{nom}_arete", ed * unique)
    sauver_png(f"_occlusion_{nom}", unique.astype(np.float32))
    sauver_png(f"bake_{nom}", niv.astype(np.float32) * (64.0 / 255.0))
print("FINI")
