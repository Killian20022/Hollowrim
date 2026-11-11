# CUISSON « haute déf -> basse déf » des armures (recette des jeux pros, tout en Blender -b scripté) — essai sur l'ACIER NORDIQUE.
#   blender.exe -b --python sources_blender/armures/cuisson/cuire.py -- [ids...] [--px 1024] [--debug DOSSIER] [--pas-export]
#              [--apercu DOSSIER] [--niveau-hd 3]
# Pour chaque pièce :
#   1. BASSE DÉF du jeu : exactement celle de la passe 2 (fer_acier/generer_hd.construire : mêmes triangles, mêmes poids, mêmes
#      noms de matériaux) ;
#   2. UV UNIQUES (« cuisson ») : la passe 2 partageait l'atlas (gauche/droite, lames répétées) -> dépliage smart project + empaquetage
#      sans recouvrement, atlas px² (1024 par défaut) ; la peinture de la passe 2 est reprise texel par texel (raster.py) ;
#   3. HAUTE DÉF : copie subdivisée (Catmull-Clark, niveau 3) + relief moyen sculpté (details.relief_mid : martelage, coups, arête et
#      cannelures du plastron) porté par les sommets ;
#   4. CUISSON Cycles haute -> basse (sélection vers actif) : normales (espace objet) et occlusion ambiante (pièce seule) ;
#   5. relief FIN dans l'espace de la texture (details.relief_fin : entrelacs gravés, piqûres, grain du cuir) -> normale finale ;
#      COURBURE = divergence de la normale finale (arêtes claires / creux sombres) ;
#   6. ALBÉDO final : peinture de la passe 2 x occlusion x éclairage cuit léger (le shader ps1 n'a pas de normal map : tout le relief
#      va dans l'albédo), arêtes usées polies, rayures claires, crasse et patine dans les creux ; alpha = brillance (lue par le
#      shader « matière ») renforcée sur les arêtes, éteinte dans les creux ;
#   7. export : glb porté (assets/modeles/armures/porte/<id>.glb, armature + pièce, mêmes noms) et au sol (alpha de couleur de sommet 0).
import bpy, sys, os, math, importlib, time
import numpy as np
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(1, os.path.join(ICI, "..", "fer_acier"))
sys.path.insert(2, os.path.join(ICI, "..", "lourdes"))
_argv = sys.argv
sys.argv = [sys.argv[0], "--"]          # generer_hd lit sys.argv (options) : on ne lui passe rien
import generer_hd as G
sys.argv = _argv
import commun as C
import raster as RS
import details as D
importlib.reload(RS); importlib.reload(D)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TEXTURES = os.path.join(ICI, "textures")


def _opt(nom, defaut):
    if nom in ARGS:
        return ARGS[ARGS.index(nom) + 1]
    return defaut


def _png(chemin, arr):
    """arr (H, W, 3|4) 0..1, ligne 0 = bas -> PNG (via une image Blender)."""
    H, W = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((H, W, 1))], -1)
    img = bpy.data.images.new("tmp_png", W, H, alpha=True)
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = chemin
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def _image_np(img):
    W, H = img.size
    a = np.zeros(W * H * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(H, W, 4).astype(np.float64)


def _image_piece(ob):
    for m in ob.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                return n.image


# ------------------------------------------------------------------------------------------------------------ 2. UV uniques
def deplier(ob, px):
    me = ob.data
    ancien = me.uv_layers[0].name
    uv = me.uv_layers.new(name="cuisson")
    me.uv_layers.active = uv
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    try:
        bpy.ops.uv.pack_islands(margin=4.0 / px * 1.5, rotate=True, shape_method="CONCAVE")
    except TypeError:
        bpy.ops.uv.pack_islands(margin=4.0 / px * 1.5, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ancien


# ------------------------------------------------------------------------------------------------------------ 3. haute déf
def haute_def(ob, pid, niveau):
    hd = ob.copy(); hd.data = ob.data.copy()
    hd.name = ob.name + "_HD"
    bpy.context.scene.collection.objects.link(hd)
    mw = ob.matrix_world.copy()
    hd.parent = None
    hd.matrix_world = mw
    hd.modifiers.clear()
    hd.vertex_groups.clear()
    sub = hd.modifiers.new("subdiv", "SUBSURF")
    sub.levels = sub.render_levels = niveau
    sub.uv_smooth = "NONE"          # UV interpolées linéairement : le texel (u, v) de la haute déf = celui de la basse déf
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(hd.evaluated_get(dg))
    hd.modifiers.clear()
    vieux = hd.data
    hd.data = me
    bpy.data.meshes.remove(vieux)
    for p in me.polygons:
        p.use_smooth = True
    # relief moyen sculpté le long de la normale (sommets d'acier seulement)
    M = np.array(hd.matrix_world)
    co = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    nv = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get("normal", nv); nv = nv.reshape(-1, 3)
    pw = co @ M[:3, :3].T + M[:3, 3]
    acier_m = np.array([_est_acier(m.name) for m in me.materials])
    pm = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", pm)
    av = np.zeros(len(me.vertices), bool)
    for poly, mi in zip(me.polygons, pm):
        if acier_m[mi]:
            av[list(poly.vertices)] = True
    h = D.relief_mid(pid, pw, av)
    co = co + nv * h[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    print("HD", pid, len(me.polygons), "faces", "relief", round(float(h.min()) * 1000, 2), round(float(h.max()) * 1000, 2), "mm")
    return hd


def _est_acier(nom):
    return nom.split(".")[0] in ("acier", "fer") and "maille" not in nom


def _est_maille(nom):
    return "maille" in nom


def _est_cuir(nom):
    return nom.split(".")[0] == "cuir"


# ------------------------------------------------------------------------------------------------------------ 4. cuisson Cycles
def cuire_cycles(ob, hd, px, uv_nom):
    """Cuisson sur la HAUTE DÉF elle-même, dans ses UV (= UV « cuisson » de la basse déf, subdivisées linéairement) : chaque texel
    reçoit la normale et l'occlusion du point sculpté correspondant (projection par les UV : ni cage, ni rayons perdus entre des
    lames superposées). Occlusion : la pièce haute déf seule."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("monde")
    sc.world.light_settings.distance = 0.07
    for o in bpy.data.objects:
        o.hide_render = o is not hd
    hd.data.uv_layers.active = hd.data.uv_layers[uv_nom]
    hd.data.uv_layers[uv_nom].active_render = True
    # matériau de cuisson neutre (les matériaux du jeu portent la brillance dans l'alpha : Cycles la prendrait pour de la transparence)
    mb = bpy.data.materials.new("cuisson_neutre")
    mb.use_nodes = True
    hd.data.materials.clear()
    hd.data.materials.append(mb)
    cartes = {}
    for typ, kw, ech in (("NORMAL", dict(normal_space="OBJECT"), 4), ("AO", {}, 64)):
        img = bpy.data.images.new("cuisson_" + typ, px, px, alpha=False, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        noeuds = []
        for m in hd.data.materials:
            n = m.node_tree.nodes.new("ShaderNodeTexImage")
            n.image = img
            m.node_tree.nodes.active = n
            noeuds.append((m, n))
        sc.cycles.samples = ech
        bk = sc.render.bake
        bk.use_selected_to_active = False
        bk.margin = 6
        bk.target = "IMAGE_TEXTURES"
        bpy.ops.object.select_all(action="DESELECT")
        hd.select_set(True)
        bpy.context.view_layer.objects.active = hd
        t0 = time.time()
        bpy.ops.object.bake(type=typ, use_selected_to_active=False, **kw)
        print("CUISSON", typ, round(time.time() - t0, 1), "s")
        cartes[typ] = _image_np(img)[..., :3]
        for m, n in noeuds:
            m.node_tree.nodes.remove(n)
        bpy.data.images.remove(img)
    for o in bpy.data.objects:
        o.hide_render = False
    return cartes


# ------------------------------------------------------------------------------------------------------------ 5a. bordures
def bordures(ob, K, acier):
    """Relief de BORDURE de chaque plaque d'acier (le « sculpté » des armures Tripo : bande en relief le long du bord, gorge
    gravée, panneau ; rivets bombés sur la bande). Distance 3D de chaque texel au bord libre de SA plaque (composante connexe
    d'acier de la basse déf ; les petites composantes — rivets, boucles — n'en ont pas). Retourne (hauteur m, masque gorge, rivets)."""
    import bmesh
    from mathutils import Vector
    from mathutils.kdtree import KDTree
    N = K.N
    me = ob.data
    M = ob.matrix_world
    bm = bmesh.new(); bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    noms = [m.name for m in me.materials]
    est = [_est_acier(n) for n in noms]
    comp = [-1] * len(bm.faces)
    nc = 0
    for f in bm.faces:
        if comp[f.index] >= 0 or not est[f.material_index]:
            continue
        pile = [f]; comp[f.index] = nc
        while pile:
            g = pile.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if comp[h.index] < 0 and est[h.material_index]:
                        comp[h.index] = nc; pile.append(h)
        nc += 1
    aire = np.zeros(nc)
    for f in bm.faces:
        if comp[f.index] >= 0:
            aire[comp[f.index]] += f.calc_area()
    # bords libres : arêtes d'acier avec une seule face d'acier de la même plaque
    ech = {c: [] for c in range(nc)}
    riv = {c: [] for c in range(nc)}
    for e in bm.edges:
        fs = [f for f in e.link_faces if comp[f.index] >= 0]
        if len(fs) != 1:
            continue
        c = comp[fs[0].index]
        if aire[c] < 0.004:
            continue
        a, b = M @ e.verts[0].co, M @ e.verts[1].co
        L = (b - a).length
        n = max(1, int(L / 0.002))
        for k in range(n + 1):
            ech[c].append(a.lerp(b, k / n))
        # direction vers l'intérieur de la plaque (pour poser les rivets sur la bande)
        f = fs[0]
        ctr = M @ f.calc_center_median()
        mil = (a + b) / 2
        t = (b - a).normalized()
        nn = (M.to_3x3() @ f.normal).normalized()
        dedans = t.cross(nn)
        if dedans.dot(ctr - mil) < 0:
            dedans = -dedans
        for k in range(n + 1):
            riv[c].append((a.lerp(b, k / n), dedans))
    bm.free()
    me.calc_loop_triangles()
    lt_poly = np.zeros(len(me.loop_triangles), np.int64); me.loop_triangles.foreach_get("polygon_index", lt_poly)
    comp_np = np.array(comp)
    ctex = np.where(K.masque, comp_np[lt_poly[np.where(K.masque, K.tri, 0)]], -1)
    dist = np.full((N, N), 9.0)
    RIV = np.zeros((N, N))
    for c in range(nc):
        if not ech[c]:
            continue
        kd = KDTree(len(ech[c]))
        for i, p in enumerate(ech[c]):
            kd.insert(p, i)
        kd.balance()
        # rivets : un point du bord tous les ~55 mm, rentré de 5,5 mm sur la plaque
        pts = []
        for p, d in riv[c]:
            q = p + d * 0.0055
            if all((q - r).length > 0.055 for r in pts):
                pts.append(q)
        kdr = KDTree(max(1, len(pts)))
        for i, q in enumerate(pts):
            kdr.insert(q, i)
        kdr.balance()
        sel = np.nonzero((ctex == c) & acier)
        P = K.pos[sel]
        dd = np.empty(len(P)); rr = np.empty(len(P))
        for i in range(len(P)):
            v = Vector(P[i])
            dd[i] = kd.find(v)[2]
            rr[i] = kdr.find(v)[2] if pts else 9.0
        dist[sel] = dd
        RIV[sel] = np.clip(1 - (rr / 0.0032) ** 2, 0, 1)
    dmm = dist * 1000.0
    bande = D.lisse(1.0, 2.2, dmm) * (1 - D.lisse(7.8, 9.0, dmm))
    gorge = np.exp(-((dmm - 10.2) / 1.0) ** 2)
    h = 0.00055 * bande - 0.00045 * gorge + 0.0011 * np.sqrt(RIV)
    h = np.where(acier, h, 0.0)
    print("BORDURES", nc, "plaques", int((aire >= 0.004).sum()), "avec bordure")
    return h, np.where(acier, gorge, 0.0), np.where(acier, RIV, 0.0)


def _gradient_texture(h, K, m):
    """Gradient de surface (m/m, vecteur 3D tangent) d'une hauteur définie par texel : différences centrées dans l'atlas, ramenées
    sur la surface par le repère tangent (dP/dx, dP/dy)."""
    hd = RS.dilater(h[..., None], m, passes=3)[..., 0]
    hx = (np.roll(hd, -1, 1) - np.roll(hd, 1, 1)) / 2
    hy = (np.roll(hd, -1, 0) - np.roll(hd, 1, 0)) / 2
    Tx, Ty = K.tx, K.ty
    a11 = (Tx * Tx).sum(-1); a12 = (Tx * Ty).sum(-1); a22 = (Ty * Ty).sum(-1)
    det = a11 * a22 - a12 * a12
    det = np.where(np.abs(det) < 1e-16, 1e-16, det)
    ca = (a22 * hx - a12 * hy) / det
    cb = (a11 * hy - a12 * hx) / det
    g = Tx * ca[..., None] + Ty * cb[..., None]
    return np.where(m[..., None], g, 0.0)


# ------------------------------------------------------------------------------------------------------------ 5-6. composition
LUM = np.array([-0.42, -0.55, 0.72]); LUM /= np.linalg.norm(LUM)       # lumière cuite : haut, devant, gauche (Blender : -Y devant)
VUE = np.array([0.0, -1.0, 0.25]); VUE /= np.linalg.norm(VUE)
DEMI = LUM + VUE; DEMI /= np.linalg.norm(DEMI)


# forces de la composition (réglées sur les captures Godot, shader ps1, 480 x 270)
FORCE = dict(eclair0=0.50, eclair=0.72, spec_exp=9, spec=0.32, ao_exp=1.7, occ_acier=0.88, occ_autre=0.7, crasse_acier=0.7,
             use=0.85, acier_nu=(0.60, 0.61, 0.62), marbre=0.16)


def _tangentes(n):
    a = np.where(np.abs(n[..., 2:3]) < 0.9, np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0]))
    t1 = np.cross(n, a); t1 /= np.maximum(np.linalg.norm(t1, axis=-1, keepdims=True), 1e-9)
    t2 = np.cross(n, t1)
    return t1, t2


def composer(pid, ob, K, base, cartes, dbg=None):
    N = K.N
    m = K.masque
    noms = [mm.name for mm in ob.data.materials]
    acier = np.isin(K.mat, [i for i, nn in enumerate(noms) if _est_acier(nn)]) & m
    maille = np.isin(K.mat, [i for i, nn in enumerate(noms) if _est_maille(nn)]) & m
    cuir = np.isin(K.mat, [i for i, nn in enumerate(noms) if _est_cuir(nn)]) & m
    R3 = np.array(ob.matrix_world)[:3, :3]      # haute déf : même matrice monde que la basse déf
    nb = cartes["NORMAL"] * 2 - 1
    nb = nb @ R3.T
    nb /= np.maximum(np.linalg.norm(nb, axis=-1, keepdims=True), 1e-9)
    # texels non atteints par la cuisson (rayons perdus) : normale de la basse déf
    perdu = (np.abs(cartes["NORMAL"] - 0.5).sum(-1) < 1e-3) | ~np.isfinite(nb).all(-1)
    nb = np.where(perdu[..., None], K.nrm, nb)
    nb = np.where(m[..., None], nb, K.nrm)
    ao = np.clip(cartes["AO"][..., 0], 0, 1)
    # --- relief fin (espace texture, fonction de la position 3D) -> normale finale
    P = K.pos[m]; Nn = nb[m]
    hf, grav = D.relief_fin(pid, P, acier[m], cuir[m])
    t1, t2 = _tangentes(Nn)
    eps = 0.0005
    g1 = (D.relief_fin(pid, P + t1 * eps, acier[m], cuir[m])[0] - D.relief_fin(pid, P - t1 * eps, acier[m], cuir[m])[0]) / (2 * eps)
    g2 = (D.relief_fin(pid, P + t2 * eps, acier[m], cuir[m])[0] - D.relief_fin(pid, P - t2 * eps, acier[m], cuir[m])[0]) / (2 * eps)
    nf_m = Nn - t1 * g1[:, None] - t2 * g2[:, None]
    nf_m /= np.linalg.norm(nf_m, axis=-1, keepdims=True)
    nf = K.nrm.copy(); nf[m] = nf_m
    # bordures en relief des plaques (texture) : gradient ramené sur la surface
    hb, GORGE, RIVT = bordures(ob, K, acier)
    gb = _gradient_texture(hb, K, m)
    gb = np.clip(gb, -1.5, 1.5)
    nf = nf - (gb - (gb * nf).sum(-1, keepdims=True) * nf)
    nf /= np.maximum(np.linalg.norm(nf, axis=-1, keepdims=True), 1e-9)
    GRAV = np.zeros((N, N)); GRAV[m] = grav
    GRAV = np.maximum(GRAV, GORGE * 0.9)
    RAY = np.zeros((N, N)); RAY[acier] = D.rayures(K.pos[acier])
    # --- courbure : divergence de la normale (différences centrées, voisins 3D seulement : pas à travers les coutures)
    pos = K.pos
    def voisin(a, dy, dx):
        return np.roll(np.roll(a, -dy, 0), -dx, 1)
    div = np.zeros((N, N))
    for (dy, dx) in ((0, 1), (1, 0)):
        pa, pb = voisin(pos, dy, dx), voisin(pos, -dy, -dx)
        na, nb2 = voisin(nf, dy, dx), voisin(nf, -dy, -dx)
        ma, mb = voisin(m, dy, dx), voisin(m, -dy, -dx)
        dp = pa - pb
        l2 = (dp * dp).sum(-1)
        tex = np.sqrt(np.maximum((K.tx * K.tx).sum(-1) if dx else (K.ty * K.ty).sum(-1), 1e-14))
        ok = ma & mb & m & (l2 < (4.0 * tex) ** 2) & (l2 > 1e-14)
        div += np.where(ok, ((na - nb2) * dp).sum(-1) / np.maximum(l2, 1e-14), 0.0)
    cv = np.clip(div * 0.0045, -1, 1)
    def flou(a, passes):
        for _ in range(passes):
            acc = np.zeros((N, N)); cnt = np.zeros((N, N))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    mm = voisin(m, dy, dx)
                    acc += voisin(a, dy, dx) * mm; cnt += mm
            a = np.where(m, acc / np.maximum(cnt, 1), 0.0)
        return a
    # courbure à deux échelles : fine (arêtes vives, gravures) et LARGE (bords de plaques, gorges entre lames : ce qui survit aux
    # mipmaps en 480 x 270)
    cv = flou(cv, 1)
    cvl = np.clip(flou(cv, 5) * 2.2, -1, 1)
    convexe = np.clip(cv, 0, 1); creux = np.clip(-cv, 0, 1)
    convexe_l = np.clip(cvl, 0, 1); creux_l = np.clip(-cvl, 0, 1)
    F = FORCE
    # --- éclairage cuit (le jeu éclaire aussi ; la part cuite donne le modelé « sculpté » des plaques)
    lam = np.clip((nf * LUM).sum(-1), 0, 1)
    ciel = 0.5 + 0.5 * nf[..., 2]
    eclair = F["eclair0"] + F["eclair"] * (0.65 * lam + 0.35 * ciel)
    spec = np.clip((nf * DEMI).sum(-1), 0, 1) ** F["spec_exp"]
    # --- couleur
    rgb = base[..., :3].copy(); bri = base[..., 3].copy()
    bruit_u = np.zeros((N, N)); bruit_u[m] = D.fbm3(K.pos[m], 77, oct=((0.03, 0.6), (0.008, 0.4)))
    marbre = np.zeros((N, N)); marbre[m] = D.fbm3(K.pos[m], 91, oct=((0.07, 0.6), (0.025, 0.4)))
    occl = ao ** F["ao_exp"]
    # nuances par plaque (patine inégale, comme une tôle réelle)
    rgb = rgb * np.where(acier, 1.0 + F["marbre"] * (marbre - 0.5) * 2, 1.0)[..., None]
    # crasse / patine sombre (creux, gravures, occlusion), un peu brune : acier nordique patiné, pas de plastique
    crasse = np.clip((1 - ao) * 1.6 + creux * 0.7 + creux_l * 1.2 + GRAV * 0.9, 0, 1) * (0.6 + 0.6 * bruit_u)
    CRASSE = np.array([0.035, 0.030, 0.026])
    k_occ = np.where(acier | maille, F["occ_acier"], F["occ_autre"])
    rgb = rgb * (1 - k_occ[..., None] * (1 - occl[..., None]))
    rgb = rgb * eclair[..., None]
    kc = np.where(acier, F["crasse_acier"], np.where(cuir, 0.45, 0.3)) * crasse
    rgb = rgb * (1 - kc[..., None]) + CRASSE * kc[..., None]
    # arêtes usées : acier mis à nu, clair et poli (usure plus forte là où le bruit le veut, jamais un liseré uniforme)
    use = np.clip(convexe * 1.3 + convexe_l * 1.6 - 0.06, 0, 1) * (0.5 + 0.8 * bruit_u) * np.clip(occl * 1.3, 0, 1)
    ACIER_NU = np.array(F["acier_nu"])
    ku = np.where(acier, F["use"], 0.0) * np.clip(use, 0, 1)
    rgb = rgb * (1 - ku[..., None]) + ACIER_NU * ku[..., None]
    # cuir : arêtes éclaircies par le frottement
    kcu = np.where(cuir, 0.4, 0.0) * np.clip(use * 1.2, 0, 1)
    rgb = rgb * (1 + kcu[..., None] * 0.8)
    # rayures : traits clairs (métal frais)
    kr = np.where(acier, 0.6, 0.0) * RAY * occl
    rgb = rgb * (1 - kr[..., None]) + np.array([0.56, 0.57, 0.58]) * kr[..., None]
    # reflet cuit : traînée claire sur les bombés (le « sculpté » Tripo)
    ks = np.where(acier, F["spec"], np.where(maille, F["spec"] * 0.5, np.where(cuir, 0.05, 0.0))) * spec * occl
    rgb = rgb + ks[..., None] * np.array([0.85, 0.88, 0.92])
    # brillance (alpha) : arêtes polies et rayures brillent, creux éteints
    bri = np.where(acier, np.clip(bri * (0.45 + 0.55 * occl) + 0.5 * use + 0.3 * RAY - 0.4 * crasse, 0, 1), np.clip(bri * (0.6 + 0.4 * occl), 0, 1))
    out = np.concatenate([np.clip(rgb, 0, 1), bri[..., None]], -1)
    out = RS.dilater(out, m, passes=10)
    if dbg:
        os.makedirs(dbg, exist_ok=True)
        _png(os.path.join(dbg, pid + "_ao.png"), ao)
        _png(os.path.join(dbg, pid + "_courbure.png"), np.stack([0.5 + 0.5 * cv, 0.5 + 0.5 * cvl, 0.5 + 0.5 * cvl], -1))
        _png(os.path.join(dbg, pid + "_normale.png"), nf * 0.5 + 0.5)
        _png(os.path.join(dbg, pid + "_base.png"), base[..., :3])
        _png(os.path.join(dbg, pid + "_albedo.png"), out[..., :3])
        _png(os.path.join(dbg, pid + "_brillance.png"), out[..., 3])
        _png(os.path.join(dbg, pid + "_gravure_rayures.png"), np.stack([GRAV, RAY, np.zeros_like(RAY)], -1))
    return out


# ------------------------------------------------------------------------------------------------------------ pièce
def cuire(pid, px, niveau, dbg, exporter, apercu):
    t0 = time.time()
    r, ob = G.construire(pid)
    tris0 = C.compter_tris(ob)
    img0 = _image_piece(ob)
    base_src = _image_np(img0)
    ancien = deplier(ob, px)
    K = RS.rasteriser(ob, "cuisson", ancien, px)
    print("RASTER", pid, round(float(K.masque.mean()), 3), "de l'atlas couvert")
    base = RS.echantillonner(base_src, K.uv_src)
    hd = haute_def(ob, pid, niveau)
    cartes = cuire_cycles(ob, hd, px, "cuisson")
    out = composer(pid, ob, K, base, cartes, dbg)
    bpy.data.objects.remove(hd, do_unlink=True)
    # image finale (8 bits, empaquetée), UV « cuisson » seules, couleur de sommet neutre (l'occlusion est dans la texture)
    img = bpy.data.images.new(pid, px, px, alpha=True)
    img.pixels.foreach_set(out.astype(np.float32).ravel())
    os.makedirs(TEXTURES, exist_ok=True)
    img.filepath_raw = os.path.join(TEXTURES, pid + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    for mt in ob.data.materials:
        for n in mt.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = img
    me = ob.data
    me.uv_layers.remove(me.uv_layers[ancien])
    me.uv_layers["cuisson"].name = "UVMap"
    me.uv_layers.active = me.uv_layers[0]
    for ca in me.color_attributes:
        for d in ca.data:
            d.color = (1.0, 1.0, 1.0, d.color[3])
    print("PIECE", pid, tris0, "->", C.compter_tris(ob), "tris", "atlas", px, "groupes", len(ob.vertex_groups), "matieres",
          [mm.name for mm in ob.data.materials], round(time.time() - t0, 1), "s")
    if exporter:
        C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
        G.version_sol(r, ob, pid)
    if apercu:
        G.apercu(r, apercu, pid)


def main():
    px = int(_opt("--px", 1024))
    niveau = int(_opt("--niveau-hd", 3))
    dbg = _opt("--debug", None)
    apercu = _opt("--apercu", None)
    ids = [a for i, a in enumerate(ARGS) if not a.startswith("--") and (i == 0 or ARGS[i - 1] not in ("--px", "--debug", "--apercu", "--niveau-hd"))]
    ids = ids or ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"]
    for pid in ids:
        cuire(pid, px, niveau, dbg, "--pas-export" not in ARGS, apercu)


main()
