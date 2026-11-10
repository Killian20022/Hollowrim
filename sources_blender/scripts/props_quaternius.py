# CHAÎNE PS1 « TEXTURÉE » DU FANTASY PROPS MEGAKIT (Quaternius, CC0) -> glb du jeu  (props/quaternius, 2026-11-10)
#   blender.exe -b --python props_quaternius.py -- [src=<dossier glTF>] [seulement=Barrel,Chair_1] [sans_atlas=1]
# Les fichiers Quaternius sont des DONNÉES : on les importe, on n'exécute rien d'eux.
# Différence avec importer_quaternius.py (lots 2-4, .dat à couleurs de face sans texture) : ici les « trims » 2048 px du pack sont
# GARDÉS mais réduits à la densité PS1 (atlas 128 / 256 px partagés par tous les props, filtre plus proche dans le jeu), accrochés
# aux rampes de la bible et vieillis ; la couleur de sommet porte la teinte des matériaux « _Vertex » (accrochée à la palette),
# l'occlusion cuite et le pied sombre.
# Étapes :
#   1. ATLAS (une fois) : chaque trim -> moyenne par blocs (2048 -> 128/256), virage nordique (désaturé, assombri, pointe froide),
#      bruit léger en amas de 2 px (JAMAIS de Bayer), accroche OKLab sur les rampes de la bible permises pour la matière,
#      filtre « mode » contre les pixels isolés. Variantes « _v » (multipliées par la couleur de sommet) : luminance seule, en paliers.
#      -> assets/modeles/props_quat/textures/pq_<atlas>.png
#   2. PROP : import, fusion, transformations appliquées, une seule carte UV, matériaux -> pq_<atlas> (un matériau par atlas) ;
#      échelle réelle (hauteur cible en m ou facteur), origine au pied au centre de l'emprise ;
#      soudure des sommets ; réduction ADAPTATIVE seulement au-dessus du budget (dissolution plane puis « collapse » par paliers,
#      refusée si elle ouvre des trous : arêtes de bord comptées avant / après) ; lissage par angle (35°) ;
#      couleur de sommet (coin) = teinte accrochée (matériaux _v) x occlusion cuite x pied sombre ; alpha 1 (pas de neige) ;
#   3. export glb SANS image (matériaux nommés pq_<atlas> : le jeu pose le shader ps1 + l'atlas partagé, scripts/props_quat.gd) ;
#   4. data/props_quaternius_brut.json : dimensions, triangles, collision, densité de texels (le catalogue final est complété par
#      outils/props_quat_catalogue.py : remplacements dans le code).
import bpy, bmesh, math, os, sys, json, random, colorsys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
SRC_DEF = "C:/Users/lopezk19/Jeux/sources_quaternius/fantasy_props_megakit"
SORTIE = os.path.join(BASE, "assets", "modeles", "props_quat")
TEX = os.path.join(SORTIE, "textures")
BRUT = os.path.join(BASE, "data", "props_quaternius_brut.json")


def H(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# Rampes de la bible (docs/BIBLE_VISUELLE.md §2 ; ombre commune de DIRECTION_ARTISTIQUE §2)
RAMPES = {
    "bois": "#2b1a1e #472a21 #6a4229 #92613a #bb8a53",
    "bois_mort": "#3d3c4a #5b5a66 #7f7d82 #a7a19b",
    "ecorce": "#241a22 #3a2a2a #54402f #735b43 #947c5e",
    "cuir": "#1f1418 #3a261b #5b3d27 #86603a",
    "tourbe": "#211e1c #3b3322 #5c4e2d #82723f #b39d5d",
    "fer": "#20252f #3a4256 #5b6680 #8a96ae #bcc6d8",
    "or": "#4a3419 #7b5a26 #a98638 #d3b25c",
    "pierre": "#262a3b #3a4057 #565b72 #787d8e #a0a2ab",
    "laine_rouge": "#351520 #5c1f2b #8a2f35 #b9504a",
    "laine_bleue": "#1b2a52 #2a4382 #4468ac #7b9ad0",
    "ecru": "#8e8688 #b9ae9f #dbd0b6 #efe7d0",
    "fourrure": "#25262f #3d3e4a #5c5d68 #85848c #b3b0b4",
    "pin": "#3b1f24 #6a3524 #9c5129 #cf7b3c #ecaa62",
    "aiguilles": "#08161a #10272a #1a3d32 #2c5a41 #5b866f",
    "braise": "#5a1a1c #b3341f #ec6a1f #fcb53a",
    "ombre": "#090808 #0f0b08 #14161a",
}
RAMPES = {k: [H(c) for c in v.split()] for k, v in RAMPES.items()}
FROID = H("#4a557f")

# Atlas : source, taille, rampes permises, virage (saturation, valeur, froid), variante luminance
ATLAS = {
    "bois": ("T_Trim_Furniture_BaseColor.png", 128, ("bois", "ecorce", "cuir", "tourbe", "bois_mort", "fer", "ombre"), (0.72, 0.80, 0.07), False),
    "fer": ("T_Trim_Metal_BaseColor.png", 128, ("fer", "pierre", "or", "cuir", "ombre"), (0.5, 0.64, 0.08), False),   # fer SOMBRE (planche v1 : gris lilas trop clair)
    "fer_v": ("T_Trim_Metal_BaseColor.png", 128, None, None, True),
    "tissu": ("T_Trim_Cloth_BaseColor.png", 256, ("ecru", "laine_bleue", "laine_rouge", "tourbe", "cuir", "fourrure", "bois", "ombre"), (0.70, 0.82, 0.06), False),
    "tissu_v": ("T_Trim_Cloth_BaseColor.png", 256, None, None, True),
    "props": ("T_Trim_Props_BaseColor.png", 128, ("ecru", "tourbe", "bois", "cuir", "fer", "laine_bleue", "laine_rouge", "ombre"), (0.5, 0.8, 0.06), False),   # cire des bougies : écru (v1 : jaune or)
    "props_v": ("T_Trim_Props_BaseColor.png", 128, None, None, True),
    "page": ("T_Page_Noise.png", 32, ("ecru", "tourbe"), (0.6, 0.85, 0.04), False),
}
MAT_ATLAS = {"MI_Trim_Furniture": "bois", "MI_Trim_Metal_Vertex": "fer_v", "MI_Trim_Metal": "fer", "MI_Trim_Cloth": "tissu",
             "MI_Banner": "tissu_v", "MI_Trim_Props_Vertex": "props_v", "MI_Trim_Props": "props", "MI_Page_Empty": "page"}
# Couleurs de sommet des matériaux « _v » : rampes candidates (pas de neige, glace, peau, runes : rien de cela dans un prop)
CAND_V = ("bois", "ecorce", "cuir", "tourbe", "fer", "or", "pierre", "laine_rouge", "laine_bleue", "ecru", "fourrure", "pin",
          "aiguilles", "bois_mort")


# ------------------------------------------------------------------ couleur
def oklab_np(c):
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    lms = np.cbrt(np.maximum(c @ M1.T, 0))
    return lms @ M2.T


def lin(x):
    x = float(min(1.0, max(0.0, x)))
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


def palette(noms):
    cs = [c for n in noms for c in RAMPES[n]]
    return np.array(cs), oklab_np(np.array(cs))


def accrocher_np(px, pal, pal_lab, poids_l=1.4):
    """px (N,3) sRGB -> couleur de palette la plus proche en OKLab (luminance pondérée)."""
    lab = oklab_np(np.clip(px, 0, 1))
    d = (poids_l * (lab[:, None, 0] - pal_lab[None, :, 0]) ** 2 + (lab[:, None, 1] - pal_lab[None, :, 1]) ** 2
         + (lab[:, None, 2] - pal_lab[None, :, 2]) ** 2)
    return pal[np.argmin(d, axis=1)]


def virage_np(px, sat, val, froid):
    L = (px @ np.array([0.299, 0.587, 0.114]))[:, None]
    c = L + (px - L) * sat
    c = c * val
    return c * (1 - froid) + np.array(FROID)[None, :] * froid * (L * val + 0.25)


def bruit_amas(h, w, graine, amplitude):
    """Bruit blanc tiré à mi-résolution puis agrandi au plus proche : amas de 2x2 px, jamais de motif ordonné (pas de Bayer)."""
    rg = np.random.default_rng(graine)
    b = rg.normal(0, amplitude, ((h + 1) // 2, (w + 1) // 2))
    return np.repeat(np.repeat(b, 2, axis=0), 2, axis=1)[:h, :w]


def filtre_mode(idx):
    """Pixel sans voisin (4-connexe) de même valeur -> valeur la plus fréquente de ses 8 voisins (bible §4.2, bouclage du trim)."""
    h, w = idx.shape
    out = idx.copy()
    for y in range(h):
        for x in range(w):
            v = idx[y, x]
            n4 = (idx[(y - 1) % h, x], idx[(y + 1) % h, x], idx[y, (x - 1) % w], idx[y, (x + 1) % w])
            if v in n4:
                continue
            n8 = list(n4) + [idx[(y - 1) % h, (x - 1) % w], idx[(y - 1) % h, (x + 1) % w], idx[(y + 1) % h, (x - 1) % w],
                             idx[(y + 1) % h, (x + 1) % w]]
            out[y, x] = max(set(n8), key=n8.count)
    return out


def lire_image(chemin):
    im = bpy.data.images.load(chemin)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[:, :, :3]       # bas -> haut (convention Blender) ; sRGB pour un PNG 8 bits


def ecrire_image(px, chemin):
    h, w = px.shape[:2]
    im = bpy.data.images.new("atlas", w, h, alpha=False)
    a = np.concatenate([px, np.ones((h, w, 1))], axis=2).astype(np.float32).ravel()
    im.pixels.foreach_set(a)
    im.filepath_raw = chemin
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)


def faire_atlas(src_tex):
    os.makedirs(TEX, exist_ok=True)
    infos = {}
    for k, (f, n, rampes, vir, lumi) in ATLAS.items():
        px = lire_image(os.path.join(src_tex, f))
        h, w = px.shape[:2]
        b = h // n
        px = px[:n * b, :n * b].reshape(n, b, n, b, 3).mean(axis=(1, 3))      # moyenne par blocs (aucun lissage ensuite)
        if lumi:
            L = px @ np.array([0.299, 0.587, 0.114])
            med = np.median(L)
            m = np.clip(L / max(med, 1e-3) * 0.86 + bruit_amas(n, n, 11, 0.025), 0.5, 1.0)
            niveaux = np.array([0.5, 0.6, 0.7, 0.78, 0.86, 0.93, 1.0])
            idx = np.abs(m[:, :, None] - niveaux[None, None, :]).argmin(axis=2)
            idx = filtre_mode(idx)
            g = niveaux[idx]
            out = np.stack([g * 1.0, g * 0.985, g * 0.965], axis=2)     # gris à peine chaud (multiplicateur, pas une couleur posée)
        else:
            pal, pal_lab = palette(rampes)
            c = virage_np(px.reshape(-1, 3), *vir).reshape(n, n, 3)
            c = c * (1.0 + bruit_amas(n, n, 7, 0.035))[:, :, None]
            s = accrocher_np(c.reshape(-1, 3), pal, pal_lab)
            # indices de palette -> filtre mode -> couleurs
            idx = np.array([np.argmin(np.abs(pal - q).sum(axis=1)) for q in s]).reshape(n, n)
            idx = filtre_mode(idx)
            out = pal[idx]
        ecrire_image(out, os.path.join(TEX, "pq_%s.png" % k))
        infos[k] = {"taille": n, "source": f, "facteur": b}
        print("ATLAS", k, n, "px (1/%d)" % b)
    return infos


# ------------------------------------------------------------------ prop
def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def materiau_atlas(k):
    m = bpy.data.materials.get("pq_" + k)
    if m is None:
        m = bpy.data.materials.new("pq_" + k)
        m.use_backface_culling = False
    return m


def importer_fusionner(chemin):
    bpy.ops.import_scene.gltf(filepath=chemin)
    for x in [x for x in bpy.context.scene.objects if x.type == 'MESH' and x.name.startswith("Icosphere")]:
        bpy.data.objects.remove(x, do_unlink=True)          # forme d'os créée par l'importeur (coffre à squelette), pas du contenu
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    dg = bpy.context.evaluated_depsgraph_get()
    for o in obs:                                           # modificateurs (squelette du coffre) appliqués en pose de repos
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        mw = o.matrix_world.copy()
        o.modifiers.clear()
        o.parent = None
        o.data = me
        o.matrix_world = mw
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for x in [x for x in bpy.context.scene.objects if x != o]:
        bpy.data.objects.remove(x, do_unlink=True)
    return o


def preparer(o, e):
    me = o.data
    # une seule carte UV (la 1re : celle des trims)
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    # couleur de sommet source (coin) -> lue avant le remappage des matériaux
    src_col = me.color_attributes[0].name if len(me.color_attributes) else None
    # matériaux -> atlas
    slots = []
    for s in o.material_slots:
        nm = s.material.name if s.material else "?"
        k = next((v for kk, v in MAT_ATLAS.items() if nm.startswith(kk)), "bois")
        slots.append(k)
    atl = sorted(set(slots)) or ["bois"]
    idx = [atl.index(slots[p.material_index]) if slots else 0 for p in me.polygons]
    me.materials.clear()                    # (remet les indices à 0 : on les repose après)
    for k in atl:
        me.materials.append(materiau_atlas(k))
    for p, i in zip(me.polygons, idx):
        p.material_index = i
    # échelle réelle, origine au pied
    vs = [v.co for v in me.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    if "hauteur" in e:
        f = e["hauteur"] / max(hi.z - lo.z, 1e-6)
    elif "longueur" in e:
        f = e["longueur"] / max(hi.x - lo.x, hi.y - lo.y, 1e-6)
    else:
        f = e.get("ech", 1.0)
    c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in me.vertices:
        v.co = (v.co - c) * f
    me.update()
    return src_col, atl, f


def compter(bm):
    return sum(len(f.verts) - 2 for f in bm.faces), sum(1 for ed in bm.edges if ed.is_boundary)


def reduire(o, budget):
    """Soudure puis réduction ADAPTATIVE (seulement au-dessus du budget), par paliers, sans ouvrir de trou."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    taille = max(o.dimensions)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(1e-5, taille * 2e-4))
    t0, b0 = compter(bm)
    bm.to_mesh(me)
    bm.free()
    info = {"tris_source": t0, "palier": None}
    if t0 <= budget * 1.1:
        return info
    # 1) dissolution plane (faces coplanaires, coutures UV et matériaux gardées) : sans perte de silhouette
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.5), verts=bm.verts, edges=bm.edges,
                             delimit={'UV', 'MATERIAL', 'NORMAL'})
    bmesh.ops.triangulate(bm, faces=bm.faces)
    t1, b1 = compter(bm)
    if b1 <= b0 * 1.02 + 2:
        bm.to_mesh(me)
    bm.free()
    if t1 <= budget * 1.1:
        info["palier"] = "plan"
        return info
    # 2) collapse par paliers : ratio visé, plancher 0,3 (la silhouette d'abord), refusé s'il ouvre des trous
    cible = budget / max(t1, 1)
    for r in sorted({max(0.3, cible), max(0.3, cible * 1.3), max(0.3, cible * 1.7), 0.6, 0.8}):
        if r >= 0.98:
            continue
        cp = me.copy()
        bm = bmesh.new()
        bm.from_mesh(cp)
        _, bb = compter(bm)
        bm.free()
        tmp = bpy.data.objects.new("tmp", cp)
        bpy.context.scene.collection.objects.link(tmp)
        md = tmp.modifiers.new("dec", 'DECIMATE')
        md.decimate_type = 'COLLAPSE'
        md.ratio = r
        md.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        ev = tmp.evaluated_get(dg).to_mesh()
        bm = bmesh.new()
        bm.from_mesh(ev)
        t2, b2 = compter(bm)
        ok = b2 <= bb * 1.03 + 4
        if ok:
            bm.to_mesh(me)
        bm.free()
        tmp.evaluated_get(dg).to_mesh_clear()
        bpy.data.objects.remove(tmp, do_unlink=True)
        bpy.data.meshes.remove(cp)
        if ok:
            info["palier"] = "collapse %.2f" % r
            return info
    info["palier"] = "refus (trous)"
    return info


def couleurs(o, src_col, atl, e):
    """Couleur de sommet (coin) : teinte des matériaux _v accrochée, x occlusion cuite x pied sombre ; alpha 1."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    lay_src = None
    if src_col:
        lay_src = bm.loops.layers.float_color.get(src_col) or bm.loops.layers.color.get(src_col)
    # occlusion par sommet (rayons dans l'hémisphère de la normale)
    tris = [[l.vert.co.copy() for l in f.loops] for f in bm.faces]
    pts, polys = [], []
    for t in tris:
        polys.append(tuple(range(len(pts), len(pts) + len(t))))
        pts.extend(t)
    arbre = BVHTree.FromPolygons([tuple(p) for p in pts], polys, epsilon=1e-6)
    taille = max(o.dimensions)
    portee = min(0.3, max(0.04, taille * 0.25))
    rg = random.Random(5)
    dirs = []
    for _ in range(14):
        u, v = rg.random(), rg.random()
        r = math.sqrt(u)
        th = 2 * math.pi * v
        dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0, 1 - u))))
    ao = {}
    for vt in bm.verts:
        n = vt.normal.copy()
        if n.length < 1e-6:
            ao[vt.index] = 1.0
            continue
        tg = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        bt = n.cross(tg)
        occ = 0.0
        org = vt.co + n * portee * 0.02
        for dx, dy, dz in dirs:
            d = (tg * dx + bt * dy + n * dz).normalized()
            h = arbre.ray_cast(org, d, portee)
            if h[0] is not None:
                occ += 1.0 - h[3] / portee
        ao[vt.index] = max(0.5, 1.0 - 0.75 * occ / len(dirs) * 1.6)
    sol = e.get("sol", True)
    pied_h = min(0.2, max(0.03, o.dimensions.z * 0.25))
    pal, pal_lab = palette(e.get("rampes_v", CAND_V))
    fer, fer_lab = palette(("fer",))
    lay = bm.loops.layers.float_color.new("Col")
    for f in bm.faces:
        k = atl[f.material_index] if f.material_index < len(atl) else "bois"
        teinte = np.array([1.0, 1.0, 1.0])
        if k.endswith("_v"):
            c = np.array([0.85, 0.82, 0.78])
            if lay_src:
                c = np.mean([list(l[lay_src])[:3] for l in f.loops], axis=0)
                if bm.loops.layers.color.get(src_col or "") is not None:   # octets : déjà sRGB
                    pass
                else:                                                        # flottants : linéaire -> sRGB
                    c = np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)
            c = virage_np(c[None, :], 0.78, 0.86, 0.06)
            hh, ss, vv = colorsys.rgb_to_hsv(*np.clip(c[0], 0, 1))
            if e.get("bronze_fer") and 0.04 < hh < 0.16 and ss > 0.35 and vv > 0.35:   # bronze -> fer (thème nordique)
                teinte = accrocher_np(np.array([[vv * 0.8] * 3]), fer, fer_lab)[0]
            else:
                teinte = accrocher_np(c, pal, pal_lab)[0]
        for l in f.loops:
            a = ao[l.vert.index]
            z = l.vert.co.z
            p = (0.72 + 0.28 * min(1.0, max(0.0, z / pied_h))) if sol else 1.0
            k2 = a * p
            l[lay] = (lin(teinte[0] * k2), lin(teinte[1] * k2), lin(teinte[2] * k2), 1.0)     # COLOR_0 linéaire (comme pq_convertir)
    bm.to_mesh(me)
    bm.free()
    for ca in list(me.color_attributes):
        if ca.name != "Col":
            me.color_attributes.remove(ca)
    me.color_attributes.active_color = me.color_attributes["Col"]
    try:
        me.color_attributes.render_color_index = 0
    except Exception:
        pass


def collision(o):
    me = o.data
    d = o.dimensions
    if max(d) < 0.25:
        return {"type": "aucune"}
    xy = [(v.co.x, v.co.y) for v in me.vertices]
    # aire de l'enveloppe convexe (projection au sol) / aire de la boîte
    pts = sorted(set((round(x, 4), round(y, 4)) for x, y in xy))
    def croix(o_, a, b):
        return (a[0] - o_[0]) * (b[1] - o_[1]) - (a[1] - o_[1]) * (b[0] - o_[0])
    bas, haut = [], []
    for p in pts:
        while len(bas) >= 2 and croix(bas[-2], bas[-1], p) <= 0:
            bas.pop()
        bas.append(p)
    for p in reversed(pts):
        while len(haut) >= 2 and croix(haut[-2], haut[-1], p) <= 0:
            haut.pop()
        haut.append(p)
    hull = bas[:-1] + haut[:-1]
    aire = abs(sum(hull[i][0] * hull[(i + 1) % len(hull)][1] - hull[(i + 1) % len(hull)][0] * hull[i][1] for i in range(len(hull)))) / 2
    ratio = aire / max(d.x * d.y, 1e-9)
    if ratio < 0.88 and abs(d.x - d.y) / max(d.x, d.y) < 0.15:
        return {"type": "cylindre", "rayon": round(max(d.x, d.y) / 2, 3), "hauteur": round(d.z, 3)}
    # repère Godot : X largeur, Y hauteur, Z profondeur (Blender -Y -> Godot +Z)
    return {"type": "boite", "taille": [round(d.x, 3), round(d.z, 3), round(d.y, 3)], "centre_y": round(d.z / 2, 3)}


def densite(o, atl, infos):
    """Texels par mètre réellement vus (moyenne pondérée par l'aire, par atlas)."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    r = {}
    for f in bm.faces:
        k = atl[f.material_index]
        a = f.calc_area()
        uv = [l[uvl].uv for l in f.loops]
        s = 0.0
        for i in range(1, len(uv) - 1):
            s += abs((uv[i].x - uv[0].x) * (uv[i + 1].y - uv[0].y) - (uv[i + 1].x - uv[0].x) * (uv[i].y - uv[0].y)) / 2
        x = r.setdefault(k, [0.0, 0.0])
        x[0] += a
        x[1] += s
    bm.free()
    return {k: round(math.sqrt(v[1] / v[0]) * infos[k]["taille"], 1) for k, v in r.items() if v[0] > 0}


def exporter(o, chemin):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    kw = dict(filepath=chemin, export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
              export_texcoords=True, export_normals=True, export_materials='EXPORT', export_animations=False,
              export_image_format='NONE')
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = 'ACTIVE'
    elif "export_colors" in props:
        kw["export_colors"] = True
    if "export_all_vertex_colors" in props:
        kw["export_all_vertex_colors"] = False
    if "export_active_vertex_color_when_no_material" in props:
        kw["export_active_vertex_color_when_no_material"] = True
    bpy.ops.export_scene.gltf(**kw)


def convertir(e, src, infos):
    vider()
    o = importer_fusionner(os.path.join(src, "Exports", "glTF", e["src"] + ".gltf"))
    src_col, atl, f = preparer(o, e)
    bpy.context.view_layer.update()
    d = max(o.dimensions)
    budget = e.get("budget", int(min(1500, max(300, 300 + 1000 * d))))
    red = reduire(o, budget)
    o.data.update()
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception:
        bpy.ops.object.shade_smooth()
    couleurs(o, src_col, atl, e)
    bpy.context.view_layer.update()
    me = o.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    chemin = os.path.join(SORTIE, e["categorie"], e["id"] + ".glb")
    exporter(o, chemin)
    dd = o.dimensions
    r = {"id": e["id"], "source": e["src"], "categorie": e["categorie"],
         "fichier": "res://assets/modeles/props_quat/%s/%s.glb" % (e["categorie"], e["id"]),
         "dimensions_m": [round(dd.x, 3), round(dd.z, 3), round(dd.y, 3)],
         "tris": tris, "tris_source": red["tris_source"], "reduction": red["palier"], "budget": budget,
         "echelle": round(f, 4), "atlas": ["pq_" + k for k in atl], "texels_m": densite(o, atl, infos),
         "collision": collision(o), "octets": os.path.getsize(chemin)}
    print("PROP %-24s %5d -> %5d tris  %s  %s" % (e["id"], red["tris_source"], tris, r["dimensions_m"], red["palier"]))
    return r


def main():
    args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
    src = args.get("src", SRC_DEF)
    liste = json.load(open(os.path.join(ICI, "props_quaternius_liste.json"), encoding="utf8"))
    seul = set(args["seulement"].split(",")) if "seulement" in args else None
    infos_chemin = os.path.join(TEX, "atlas.json")
    if args.get("sans_atlas") == "1" and os.path.exists(infos_chemin):
        infos = json.load(open(infos_chemin))
    else:
        infos = faire_atlas(os.path.join(src, "Textures"))
        json.dump(infos, open(infos_chemin, "w"), indent=1)
    anciens = {}
    if os.path.exists(BRUT):
        anciens = {r["id"]: r for r in json.load(open(BRUT, encoding="utf8"))}
    for e in liste:
        if e.get("ecarte"):
            continue
        if seul and e["src"] not in seul and e["id"] not in seul:
            continue
        try:
            r = convertir(e, src, infos)
            r.update({k: e[k] for k in ("note", "ancien") if k in e})
            anciens[e["id"]] = r
        except Exception as er:
            import traceback
            traceback.print_exc()
            print("ECHEC", e["id"], er)
    ordre = [e["id"] for e in liste]
    res = sorted(anciens.values(), key=lambda r: ordre.index(r["id"]) if r["id"] in ordre else 999)
    json.dump(res, open(BRUT, "w", encoding="utf8"), indent=1, ensure_ascii=False)
    print("FINI", len(res), "props ;", sum(r["tris"] for r in res), "tris ;", sum(r["octets"] for r in res), "octets")


main()
